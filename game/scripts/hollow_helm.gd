extends "res://scripts/elites.gd"
## Hollow Helm: a suit of empty wax armour behind a church-door shield. It
## paces at 40 px/s and comes at Wick within 220 px. Its front can't be
## hurt: a frontal hit returns false (clang, "Blocked") and shoves him back
## at 140 px/s, and frontal shots are stopped too. Hits from behind or from
## above land in full, and a stomp knocks the shield down for 1.2 s. It
## turns slowly (0.55 s, a puzzled swivel), which is the way round it. Its
## bash: it plants for 0.4 s with the shield's rim flashing, lunges 80 px,
## then stands 0.7 s with the shield low (open from the front too).
## The Bellfounder's maul shakes 30% through the shield.

const PACE := 40.0
const ADVANCE := 56.0
const SEE := 220.0
const TURN := 0.55
const PLANT := 0.4
const LUNGE_DIST := 80.0
const LUNGE_SPEED := 320.0
const RECOVER := 0.7
const NOSHIELD := 1.2
const PUSH := 140.0
const BASH_RANGE := 100.0
const BASH_AGAIN := 1.4
# W6b's art (frame units, facing right): the glints in the visor per frame,
# and the door shield's front rim in the bash frame (arch top, top corner,
# foot), where the tell flashes.
const EYES := {
	"helm_walk1": [Vector2(63.6, 75.7), Vector2(72.4, 75.7)],
	"helm_walk2": [Vector2(63.6, 76.7), Vector2(72.4, 76.7)],
	"helm_block": [Vector2(64.6, 80.6), Vector2(73.4, 81.5)],
	"helm_bash": [Vector2(73.3, 76.7), Vector2(81.9, 78.2)],
	"helm_noshield": [Vector2(63.6, 73.5), Vector2(72.4, 72.9)],
	"helm_hit": [Vector2(60.4, 67.0), Vector2(68.9, 64.6)],
}
const BASH_RIM := [Vector2(100.5, 75.2), Vector2(110.6, 89.2), Vector2(106.2, 120.5)]

var state := "pace"             # pace, advance, turn, plant, lunge, recover, noshield
var timer := 0.0
var _lunge_left := 0.0
var _walk := 0.0
var _blocked_t := 0.0           # the shield frame just after a block
var _bash_cd := 0.0


func _init() -> void:
	kind = "hollow_helm"
	size = Vector2(26, 32)
	base_hp = 50.0
	base_dmg = 24.0
	poise = 0.40
	embers = 6
	item_chance = 0.14
	relic_chance = 0.04
	echo_by_body = false


func _ready() -> void:
	super()
	load_frames(["helm_walk1", "helm_walk2", "helm_block", "helm_bash", "helm_noshield", "helm_hit"])
	show_frame("helm_walk1")


func dmg(what := "touch") -> float:
	if what == "bash" or (what == "touch" and state == "lunge"):
		return 36.0 * dmg_mult
	return base_dmg * dmg_mult


func shielded() -> bool:
	return alive and not (state in ["recover", "noshield"])


func frontal(h: Dictionary) -> bool:
	## Does this hit come at the shield? Not a stomp or a bonk, not from
	## above, and from the side it faces.
	var how: String = h.get("how", "slash")
	if how == "stomp" or how == "bump" or h.get("from_above", false):
		return false
	var src = h.get("source")
	if how in ["slash", "skill"] and src != null and src is Node2D and src.get("velocity") != null:
		# An attacker with its feet over the helm's top is hitting from above.
		if (src as Node2D).position.y <= rect().position.y + 4.0:
			return false
	var from_x: float = float(h.get("from_x", position.x))
	return (from_x - position.x) * facing > 0.5


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	var how: String = h.get("how", "slash")
	if shielded() and frontal(h):
		var maul: bool = world != null and world.kit != null and world.kit.cls == "founder" and how == "slash"
		if maul:
			# The maul rings the whole suit: 30% gets through.
			h["amount"] = float(h.get("amount", max_hp)) * 0.3
			h["chip"] = true
			_blocked_t = 0.2
			return super(h)
		_blocked_t = 0.25
		flash = 0.25
		sfx("shield_clang", "clang")
		if world:
			if how != "slash":
				world.number(center() + Vector2(facing * 10.0, -size.y * 0.4), 0.0, "blocked", 0)
			var pl: Node2D = world.player
			if h.get("source") == pl and how in ["slash", "skill"] and pl.alive:
				var away := 1.0 if pl.position.x > position.x else -1.0
				pl.dash(Vector2(away * PUSH, pl.velocity.y), 0.12, {"stop_at_wall": true})
			if world.glow:
				world.glow.burst(center() + Vector2(facing * 14.0, -4.0), 6, Color("ffe8b0"), 120.0, 0.2, 0.0, 1.8)
		return false
	if how == "stomp":
		# Knocked flat: the shield clatters down.
		state = "noshield"
		timer = NOSHIELD
		velocity.x = 0.0
		sfx("shield_clang", "clang", 0.8)
	return super(h)


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_blocked_t = maxf(_blocked_t - dt, 0.0)
	_bash_cd = maxf(_bash_cd - dt, 0.0)
	var dx: float = player.position.x - position.x
	var dy: float = player.position.y - position.y
	var near: bool = player.alive and absf(dx) < SEE and absf(dy) < 56.0
	var behind: bool = dx * facing < 0.0 and absf(dx) > 4.0
	match state:
		"pace":
			walk(dt, spd(PACE))
			_walk += dt
			_frame_walk()
			if near:
				if behind:
					_turn()
				else:
					state = "advance"
		"advance":
			if not near:
				state = "pace"
			elif behind:
				_turn()
			elif absf(dx) < BASH_RANGE and _bash_cd <= 0.0:
				state = "plant"
				timer = tell(PLANT)
				velocity.x = 0.0
				sfx("bash", "", 0.7)
			else:
				if ground_ahead(facing) and not wall_ahead(facing):
					velocity.x = facing * spd(ADVANCE)
					_walk += dt * 1.3
				else:
					velocity.x = 0.0
				_fall(dt)
				_frame_walk()
		"turn":
			velocity.x = 0.0
			_fall(dt)
			show_frame("helm_block")
			if timer <= 0.0:
				facing = -facing
				state = "advance"
		"plant":
			velocity.x = 0.0
			_fall(dt)
			show_frame("helm_bash")
			if sprite:
				sprite.position.x = sin(t * 70.0) * 1.2
			if timer <= 0.0:
				state = "lunge"
				# On ice the lunge slides half as far again (features.slick_at).
				_lunge_left = LUNGE_DIST * (1.5 if slick_under() else 1.0)
				sfx("bash", "boss_slam", 1.6)
				var x0 := position.x if facing > 0 else position.x - _lunge_left
				strike_logged({"rect": Rect2(x0 - size.x * 0.5, position.y - size.y, _lunge_left + size.x, size.y),
						"life": _lunge_left / LUNGE_SPEED}, dmg("bash"))
		"lunge":
			show_frame("helm_bash")
			if sprite:
				sprite.position.x = 0.0
			var step := LUNGE_SPEED * dt
			if _lunge_left > 0.0 and ground_ahead(facing) and not wall_ahead(facing):
				velocity.x = facing * LUNGE_SPEED
				_lunge_left -= step
				_fall(dt)
			else:
				velocity.x = 0.0
				state = "recover"
				timer = RECOVER
				_bash_cd = cd(BASH_AGAIN)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * dt)
			_fall(dt)
			show_frame("helm_noshield")
			if timer <= 0.0:
				state = "advance" if near else "pace"
		"noshield":
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * dt)
			_fall(dt)
			show_frame("helm_noshield")
			if timer <= 0.0:
				state = "advance" if near else "pace"
	if _blocked_t > 0.0 and shielded():
		show_frame("helm_block")


func turn_time() -> float:
	## Its slow swivel (the Empty Abbot, a Warden, turns in 0.4 s).
	return 0.4 if tier == "warden" else TURN


func _turn() -> void:
	state = "turn"
	timer = cd(turn_time())
	velocity.x = 0.0


func _fall(dt: float) -> void:
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)


func _frame_walk() -> void:
	show_frame("helm_walk1" if fmod(_walk, 0.6) < 0.3 else "helm_walk2")
	if sprite:
		sprite.position.y = -absf(sin(_walk * TAU / 0.6)) * 1.0


func _hurt(h: Dictionary) -> void:
	# Heavy armour: it barely rocks.
	velocity.x = 60.0 * (1.0 if position.x > float(h.get("from_x", position.x)) else -1.0)
	if state != "noshield":
		show_frame("helm_hit")


func _dying(dt: float) -> void:
	show_frame("helm_hit")
	# It falls apart where it stands: the helm rolls off, the rest sinks.
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * dt)
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
	fade = clampf(1.5 - death_time * 1.2, 0.0, 1.0)
	if death_time > 1.3:
		gone = true


func eye_points() -> Array:
	var v := center() + Vector2(facing * 4.0, -9.0)
	return art_eyes(EYES, [v + Vector2(-2.5, 0), v + Vector2(3.0, 0)])


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	# Teal glints in the empty visor.
	for p in eye_points():
		glow.draw_circle(p, 2.6, Color(0.5, 0.94, 0.85, 0.25))
		glow.draw_circle(p, 1.2, Color("c8fff0"))
	if state == "plant":
		# The shield's rim flashes: the bash is coming.
		var k := 1.0 - clampf(timer / maxf(tell(PLANT), 0.01), 0.0, 1.0)
		var col := Color(1.0, 0.85, 0.5, 0.5 + 0.5 * absf(sin(t * 28.0)))
		if frames.has("helm_bash"):
			var rim := PackedVector2Array()
			for q in BASH_RIM:
				rim.append(frame_point(q))
			glow.draw_polyline(rim, col, 2.0 + 2.0 * k)
		else:
			var sx := position.x + facing * 13.0
			glow.draw_line(Vector2(sx, position.y - 30.0), Vector2(sx, position.y - 3.0), col, 2.0 + 2.0 * k)
			glow.draw_arc(Vector2(sx - facing * 4.0, position.y - 26.0), 5.0, PI, TAU, 8, col, 2.0)
	elif state == "turn":
		# "Huh?"
		var p := center() + Vector2(0, -30.0 - sin(t * 8.0) * 2.0)
		glow.draw_arc(p + Vector2(0, -4), 4.0, PI * 1.1, PI * 2.4, 10, Color(1, 1, 1, 0.85), 2.0)
		glow.draw_line(p + Vector2(1.5, 0), p + Vector2(0, 3), Color(1, 1, 1, 0.85), 2.0)
		glow.draw_circle(p + Vector2(0, 7), 1.4, Color(1, 1, 1, 0.85))


func _draw() -> void:
	if not frames.is_empty():
		return
	var f := facing
	var wax := Color("efe6cc")
	var wax2 := Color("cdbf9c")
	var wood := Color("7a5236")
	var iron := Color("4a4458")
	var dead := not alive
	var sink := clampf(death_time * 10.0, 0.0, 10.0) if dead else 0.0
	var shield_state := "front"
	if state in ["recover"]:
		shield_state = "low"
	elif state == "noshield":
		shield_state = "down"
	# Legs.
	o_poly(PackedVector2Array([Vector2(-8, -10), Vector2(-2, -10), Vector2(-2, 0), Vector2(-9, 0)]), wax2, 1.5)
	o_poly(PackedVector2Array([Vector2(2, -10), Vector2(8, -10), Vector2(9, 0), Vector2(2, 0)]), wax2, 1.5)
	# Body: a round breastplate.
	o_poly(ellipse(Vector2(0, -16 + sink * 0.3), 10, 8), wax, 2.0)
	draw_rect(Rect2(-9, -14 + sink * 0.3, 18, 3), pc(wax2))
	# The helm (it rolls off when it falls apart).
	var hp_ := Vector2(f * 1.0, -27.0)
	if dead:
		hp_ = Vector2(f * death_time * 18.0, -8.0 - maxf(0.0, 12.0 - death_time * 40.0))
	o_poly(PackedVector2Array([hp_ + Vector2(-8, 5), hp_ + Vector2(-8, -3), hp_ + Vector2(-4, -8), hp_ + Vector2(4, -8),
			hp_ + Vector2(8, -3), hp_ + Vector2(8, 5)]), wax, 2.0)
	draw_rect(Rect2(hp_ + Vector2(f * 1.0 - 5.0, -1.0), Vector2(10, 2.5)), pc(Color("1c1830")))
	draw_line(hp_ + Vector2(-2, -8), hp_ + Vector2(0, -12), pc(Color("b8324e")), 3.0)
	# The shield: a church door, iron bands.
	var sx := f * 12.0
	match shield_state:
		"front":
			# A church door: planks under an arched top, two iron straps.
			var x0 := sx - 3.0 * f
			var x1 := sx + 9.0 * f
			var door := PackedVector2Array([Vector2(x0, -2), Vector2(x0, -24), Vector2(lerpf(x0, x1, 0.5), -31), Vector2(x1, -24), Vector2(x1, -2)])
			o_poly(door, wood, 2.0)
			draw_line(Vector2(lerpf(x0, x1, 0.5), -29), Vector2(lerpf(x0, x1, 0.5), -3), pc(wood.darkened(0.3)), 1.2)
			for y in [-8.0, -19.0]:
				draw_line(Vector2(x0, y), Vector2(x1, y), pc(iron), 2.5)
				draw_circle(Vector2(lerpf(x0, x1, 0.2), y), 1.1, pc(Color("8a8498")))
				draw_circle(Vector2(lerpf(x0, x1, 0.8), y), 1.1, pc(Color("8a8498")))
		"low":
			var door2 := PackedVector2Array([Vector2(sx - 2, 0), Vector2(sx + 14 * f, -3), Vector2(sx + 16 * f, -7), Vector2(sx + 2 * f, -5)])
			o_poly(door2, wood, 2.0)
		"down":
			o_poly(PackedVector2Array([Vector2(sx + 2 * f, 0), Vector2(sx + 26 * f, 0), Vector2(sx + 26 * f, -5), Vector2(sx + 2 * f, -5)]), wood, 1.5)
			draw_line(Vector2(sx + 9 * f, 0), Vector2(sx + 9 * f, -5), pc(iron), 2.0)
			draw_line(Vector2(sx + 19 * f, 0), Vector2(sx + 19 * f, -5), pc(iron), 2.0)
