extends "res://scripts/elites.gd"
## Gutterwing: a pale moth that drinks candlelight. It drifts toward Wick's
## flame at 55 px/s (90 when he's under a third of his life), bobbing, and
## passes through walls. It has no bite and can't be stomped: it latches on
## the flame instead. Latched, his light sinks to x0.55 over a second, and
## from 2.5 s on it drains 12% of his life every 2.5 s. Any attack or
## Special pops it off ("Snatched back!", light x1.3 for 3 s); it tumbles
## away stunned, one swing from dead. A Beacon lures a free one away from
## him (it's a moth). Nests (N, level_features) breed them; kits can also
## call unlatch(). Latched, it's drawn above the dark and over the flame:
## its wing_latch frame (on a child of the glow layer, which draws after
## the hero's flame) if the art has one, stand-in wings if not.

const DRIFT := 55.0
const DRIFT_LOW := 90.0
const LATCH_R := 10.0
const RAMP := 1.0
const DRAIN_AFTER := 2.5
const DRAIN_EVERY := 2.5
const DRAIN := 0.12
const SIP_R := 100.0
const LURE_R := 260.0
const POP_TIME := 1.0
# W6b's art (frame units, facing right, anchor (64,64)): its eyes per frame.
const EYES := {
	"wing_fly1": [Vector2(61.6, 63.4), Vector2(70.6, 63.0)],
	"wing_fly2": [Vector2(61.6, 64.8), Vector2(70.6, 64.4)],
	"wing_latch": [Vector2(61.6, 33.4), Vector2(70.6, 33.0)],
	"wing_pop": [Vector2(61.5, 64.1), Vector2(70.1, 61.2)],
}

var state := "drift"            # drift, latch, popped
var latch_t := 0.0
var _drain_t := 0.0
var _seen_attack := -1
var _pop_t := 0.0
var _sip_t := 0.0
var _flap := 0.0
var _base := Vector2.ZERO
var _over: Node2D = null        # latched: a child of the glow layer, drawn over his flame


func _init() -> void:
	kind = "gutterwing"
	size = Vector2(26, 22)
	base_hp = 10.0
	base_dmg = 0.0
	embers = 2
	item_chance = 0.06
	relic_chance = 0.02
	anchor = Vector2(64, 64)
	flier = true
	stompable = false


func _ready() -> void:
	super()
	load_frames(["wing_fly1", "wing_fly2", "wing_latch", "wing_pop"])
	show_frame("wing_fly1")
	_base = position


func rect() -> Rect2:
	return Rect2(position - size * 0.5, size)


func center() -> Vector2:
	return position


func hurt_rect() -> Rect2:
	## No bite, and nothing to land on: touching it does nothing.
	return NOWHERE


func dmg(_what := "touch") -> float:
	return 0.0


func flame_point() -> Vector2:
	if world and world.rig and world.rig.has_method("flame_point"):
		return world.rig.flame_point()
	if world and world.player:
		return world.player.center() + Vector2(0, -26)
	return position


func latch_light() -> float:
	## Its share of the hero's light while it settles on (world's "latch"
	## status takes over after the first second).
	if state == "latch" and latch_t < RAMP:
		return lerpf(1.0, 0.55, latch_t / RAMP)
	return 1.0


func think(dt: float, player: Node2D) -> void:
	_flap += dt * (22.0 if state != "latch" else 8.0)
	if sprite:
		# Latched, the glow layer draws its frame over the flame instead.
		sprite.visible = not (state == "latch" and frames.has("wing_latch"))
	if _over and is_instance_valid(_over):
		_over.queue_redraw()
	_sip_t -= dt
	match state:
		"drift":
			show_frame("wing_fly1" if sin(_flap) > 0.0 else "wing_fly2")
			var goal := flame_point()
			var lured := false
			if world:
				var best := LURE_R
				for b in world.lights_tagged("beacon"):
					var d: float = (b["p"] as Vector2).distance_to(position)
					if d < best and d < goal.distance_to(position):
						best = d
						goal = (b["p"] as Vector2) + Vector2(cos(t * 2.0) * 26.0, sin(t * 2.0) * 12.0)
						lured = true
			var sp: float = spd(DRIFT_LOW if player.life_frac() < 0.34 else DRIFT)
			var to := goal - _base
			if to.length() > 1.0:
				_base += to.normalized() * minf(sp * dt, to.length())
				facing = 1 if to.x > 0.0 else -1
			position = _base + Vector2(0, sin(t * 1.4 * TAU) * 5.0)
			if player.alive and not lured and position.distance_to(goal) < LATCH_R:
				_latch(player)
			elif player.alive and position.distance_to(player.center()) < SIP_R and _sip_t <= 0.0:
				_sip_t = 0.9
				sfx("wing_sip", "", 1.0 + randf() * 0.1)
		"latch":
			show_frame("wing_latch")
			if not player.alive or (world and world.state != "play"):
				_fly_off(false)
				return
			latch_t += dt
			position = flame_point() + Vector2(sin(t * 9.0) * 1.5, 3.0 + sin(t * 5.0))
			_base = position
			if latch_t >= RAMP:
				player.apply_status("latch", 0.2)
			if _popped_by(player):
				unlatch()
				return
			if latch_t >= DRAIN_AFTER:
				_drain_t -= dt
				if _drain_t <= 0.0:
					_drain_t = DRAIN_EVERY
					if world:
						world.hurt_player(DRAIN, position.x, "latch", self, {"pct": true, "no_knock": true, "ignore_invuln": true})
					sfx("wing_sip", "", 0.7)
		"popped":
			show_frame("wing_pop")
			_pop_t -= dt
			velocity = velocity.move_toward(Vector2.ZERO, 260.0 * dt)
			_base += velocity * dt
			position = _base
			if _pop_t <= 0.0:
				state = "drift"


func _popped_by(player: Node2D) -> bool:
	## Any attack press (the swing or a kit's basic) or a Special.
	if int(player.get("attack_id")) != _seen_attack:
		return true
	if world and world.get("_pad") is Dictionary and (world._pad as Dictionary).get("special_pressed", false):
		return true
	return false


func _latch(player: Node2D) -> void:
	state = "latch"
	latch_t = 0.0
	_drain_t = 0.0
	_seen_attack = int(player.get("attack_id"))
	sfx("wing_sip", "", 1.2)
	if world and world.glow:
		world.glow.burst(flame_point(), 6, Color("d8e8c8"), 50.0, 0.3, 0.0, 1.8)


func unlatch() -> void:
	## Popped off the flame: a kit may call this too.
	if state != "latch":
		return
	_fly_off(true)


func _fly_off(snatched: bool) -> void:
	state = "popped"
	_pop_t = POP_TIME
	if sprite:
		sprite.visible = true
	var away := float(world.player.facing) if world and world.player else float(-facing)
	velocity = Vector2(away * 170.0, -110.0)
	if world and world.player:
		(world.player.status as Dictionary).erase("latch")
	if snatched and world:
		world.floaters.add(position + Vector2(0, -14), 0.0, "text", 0, "Snatched back!")
		if world.features and world.features.has_method("boost"):
			world.features.boost(1.3, 3.0)
		if world.glow:
			world.glow.burst(position, 12, Color("fff4cf"), 140.0, 0.4, 0.0, 2.2)
		sfx("wing_pop", "bat")


func _hurt(h: Dictionary) -> void:
	# Any blow knocks a latched one off the flame.
	if state == "latch":
		unlatch()
		return
	super(h)


func _kill(h: Dictionary) -> void:
	if state == "latch" and world and world.player:
		(world.player.status as Dictionary).erase("latch")
	state = "dead"
	if sprite:
		sprite.visible = true
	super(h)


func _dying(dt: float) -> void:
	show_frame("wing_pop")
	# A puff of scales, then it flutters down.
	velocity.y = minf(velocity.y + 500.0 * dt, 160.0)
	velocity.x = move_toward(velocity.x, 0.0, 200.0 * dt)
	position += velocity * dt
	rotation += dt * 4.0 * facing
	fade = clampf(1.2 - death_time, 0.0, 1.0)
	if _over and is_instance_valid(_over):
		_over.queue_redraw()
	if death_time > 1.2:
		gone = true


func eye_points() -> Array:
	return art_eyes(EYES, [position + Vector2(facing * 3.0, -1.0), position + Vector2(facing * 6.0, -1.0)])


func _exit_tree() -> void:
	if _over and is_instance_valid(_over):
		_over.queue_free()


func _draw_over() -> void:
	## The latched frame, over the hero's flame (this layer draws after it).
	if not is_instance_valid(_over) or not alive or state != "latch" or not frames.has("wing_latch"):
		return
	var sm := TEX_SCALE * scale_mult
	_over.draw_set_transform(position, 0.0, Vector2(sm * (1.0 if facing > 0 else -1.0), sm))
	_over.draw_texture(frames["wing_latch"], -anchor * 2.0, tint)
	_over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in eye_points():
		_over.draw_circle(p, 1.0, Color("f4ffe8"))


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	# Faint in the dark (it comes through walls, so it must be seen coming).
	var p := position
	glow.draw_circle(p, 12.0, Color(0.85, 0.95, 0.8, 0.07))
	if state != "latch" or not frames.has("wing_latch"):
		for e in eye_points():
			glow.draw_circle(e, 1.1, Color("f4ffe8"))
	if state == "latch" and frames.has("wing_latch"):
		# The real latch frame goes on a layer drawn after his flame (the
		# flame would cover it here; think() hides the sprite meanwhile).
		if _over == null or not is_instance_valid(_over):
			_over = Node2D.new()
			_over.draw.connect(_draw_over)
			glow.add_child.call_deferred(_over)
	elif state == "latch":
		# Its wings wrapped round the flame (drawn up here, or the flame
		# would hide it), beating slowly.
		var fp := flame_point() + Vector2(0, -6)
		var beat := sin(t * 7.0) * 0.25
		for side in [-1, 1]:
			var wing := PackedVector2Array([fp + Vector2(side * 3, 2), fp + Vector2(side * (13 + beat * 4), -9 - beat * 6),
					fp + Vector2(side * (15 + beat * 3), 1), fp + Vector2(side * 7, 7)])
			glow.draw_colored_polygon(wing, Color(0.85, 0.92, 0.8, 0.92))
			glow.draw_polyline(PackedVector2Array([wing[0], wing[1], wing[2], wing[3], wing[0]]), Color(0.2, 0.22, 0.2, 0.9), 1.2)
			glow.draw_circle(fp + Vector2(side * 10, -2), 1.6, Color("3a3440"))
	if state == "latch":
		# Drinking: a violet ring round the flame, tightening.
		var k := clampf(latch_t / RAMP, 0.0, 1.0)
		var r := 16.0 - 4.0 * k + sin(t * 10.0) * 1.5
		glow.draw_arc(flame_point() + Vector2(0, -4), r, 0.0, TAU, 20, Color(0.75, 0.55, 1.0, 0.35 + 0.35 * k), 2.0)
		if latch_t >= DRAIN_AFTER - 0.6:
			# The next sip is coming.
			var n := fmod(latch_t - DRAIN_AFTER, DRAIN_EVERY)
			var w := clampf((n + 0.6 - DRAIN_EVERY) / 0.6, 0.0, 1.0) if latch_t >= DRAIN_AFTER else clampf((latch_t - (DRAIN_AFTER - 0.6)) / 0.6, 0.0, 1.0)
			glow.draw_circle(flame_point() + Vector2(0, -4), 3.0 + 5.0 * w, Color(0.8, 0.6, 1.0, 0.4 * w))


func _draw() -> void:
	if not frames.is_empty():
		return
	var f := facing
	var wing := Color("d8e8c8")
	var wing2 := Color("b4c8a4")
	var body := Color("c8b89a")
	var flap := sin(_flap)
	var spread := 1.0 if state != "latch" else 0.35
	if state == "popped" or not alive:
		spread = 0.6 + 0.4 * sin(_flap * 2.0)
	# Wings: an upper and a lower pair, beating.
	for side in [-1, 1]:
		var up := PackedVector2Array([Vector2(side * 2, -2), Vector2(side * (4 + 8 * spread), -8 - 5 * flap * spread),
				Vector2(side * (11 * spread + 3), -1 - 3 * flap * spread), Vector2(side * 4, 1)])
		o_poly(up, wing, 1.5)
		var lo := PackedVector2Array([Vector2(side * 2, 1), Vector2(side * (9 * spread + 2), 3 + 2 * flap * spread),
				Vector2(side * (6 * spread + 2), 8), Vector2(side * 1, 4)])
		o_poly(lo, wing2, 1.5)
		# The dark eye-spot on each upper wing.
		draw_circle(Vector2(side * (3 + 6 * spread), -4 - 2.5 * flap * spread), 1.6, pc(Color("3a3440")))
	# A fuzzy body and head.
	o_poly(ellipse(Vector2(0, 1), 3.2, 6.0, 12), body, 1.5)
	o_circle(Vector2(f * 2.0, -5), 3.2, wing)
	draw_circle(Vector2(f * 3.2, -5.5), 0.9, pc(Color("1c1830")))
	# Feathery antennae.
	draw_line(Vector2(f * 1.5, -8), Vector2(f * 5, -13), pc(Color("8a7a60")), 1.0)
	draw_line(Vector2(f * 3.0, -8), Vector2(f * 8, -12), pc(Color("8a7a60")), 1.0)
