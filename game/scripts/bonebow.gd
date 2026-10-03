extends "res://scripts/elites.gd"
## Bonebow: a skeleton archer standing on a post. It wakes only when it is
## wholly on screen and in plain sight (not behind a thumb button or the
## HUD's corners), within 320 px of Wick and can see him. Then it draws
## for 0.65 s (an arrowhead glint that grows, a faint aim line), the aim
## locks 0.2 s before it looses (the line goes white and stops following),
## and a bone arrow flies at 280 px/s toward his middle, clamped to +-35 deg.
## A swing sends the arrow back (world: deflect) and it can kill the archer.
## Cooldown 1.8 s; after two shots it steps back a tile. A hit while it
## draws spoils the shot. It only ever looses while fully in view.

const RANGE := 320.0
const DRAW := 0.65
const LOCK := 0.2
const COOLDOWN := 1.8
const ARROW_SPEED := 280.0
const ARROW_LIFE := 1.6
const MAX_ANGLE := 0.611        # 35 degrees
const STEP_SPEED := 70.0
# W6b's art (frame units, facing right): the eyes per frame, and the drawn
# arrow on the string (points_monsters.json bonebow_draw).
const EYES := {
	"bonebow_idle": [Vector2(60.4, 80.6), Vector2(77.6, 80.2)],
	"bonebow_draw": [Vector2(58.3, 82.3), Vector2(75.4, 80.2)],
	"bonebow_loose": [Vector2(60.2, 80.4), Vector2(77.4, 80.9)],
	"bonebow_hit": [Vector2(54.2, 81.7), Vector2(71.2, 77.7)],
}
const NOCK := Vector2(72.6, 91.4)
const ARROW_TIP := Vector2(110.4, 91.4)

var state := "idle"             # idle, draw, cool, step
var timer := 0.0
var shots := 0
var aim := Vector2.RIGHT
var locked := false
var _step_left := 0.0
var _loose_t := 0.0             # the bow still thrumming after a shot


func _init() -> void:
	kind = "bonebow"
	size = Vector2(22, 28)
	base_hp = 14.0
	base_dmg = 16.0
	embers = 3
	item_chance = 0.08
	relic_chance = 0.03
	echo_by_body = false


func _ready() -> void:
	super()
	load_frames(["bonebow_idle", "bonebow_draw", "bonebow_loose", "bonebow_hit", "bonebow_bones"])
	show_frame("bonebow_idle")


func dmg(what := "touch") -> float:
	return (22.0 if what == "arrow" else base_dmg) * dmg_mult


func bow_point() -> Vector2:
	## The nocked arrow's tail, where it aims from.
	if frames.is_empty():
		return center() + Vector2(facing * 9.0, -3.0)
	return frame_point(NOCK)


func wants(player: Node2D) -> bool:
	## Awake: wholly in view, in range, and it can see him.
	if not player.alive:
		return false
	var to: Vector2 = player.center()
	return in_view() and to.distance_to(center()) < RANGE and sees(to, bow_point())


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_loose_t = maxf(_loose_t - dt, 0.0)
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	if state != "step":
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * dt)
	var dx: float = player.position.x - position.x
	match state:
		"idle":
			show_frame("bonebow_idle")
			if wants(player):
				facing = 1 if dx > 0.0 else -1
				_start_draw()
		"draw":
			show_frame("bonebow_draw")
			if not locked:
				facing = 1 if dx > 0.0 else -1
				aim = _aim_at(player.center())
				if timer <= LOCK:
					locked = true
					sfx("arrow_draw", "", 1.4)
				elif not wants(player):
					# Lost him before the aim locked: lower the bow.
					state = "cool"
					timer = 0.5
			if timer <= 0.0:
				if in_view():
					_loose()
				else:
					state = "cool"
					timer = 0.4
		"cool":
			show_frame("bonebow_loose" if _loose_t > 0.0 else "bonebow_idle")
			if player.alive and absf(dx) > 2.0:
				facing = 1 if dx > 0.0 else -1
			if timer <= 0.0:
				if shots >= 2:
					shots = 0
					_start_step()
				elif wants(player):
					_start_draw()
				else:
					state = "idle"
		"step":
			show_frame("bonebow_idle")
			# A tile back, away from him, if there's floor there.
			var away := -1 if dx > 0.0 else 1
			if _step_left > 0.0 and ground_ahead(away) and not wall_ahead(away):
				velocity.x = away * STEP_SPEED
				_step_left -= STEP_SPEED * dt
			else:
				_step_left = 0.0
				velocity.x = 0.0
				state = "cool"
				timer = 0.25
			facing = 1 if dx > 0.0 else -1
	move(dt)


func _start_draw() -> void:
	state = "draw"
	timer = tell(DRAW)
	locked = false


func _start_step() -> void:
	state = "step"
	_step_left = 32.0


func _aim_at(target: Vector2) -> Vector2:
	var d := target - bow_point()
	var ang := clampf(atan2(d.y, absf(d.x)), -MAX_ANGLE, MAX_ANGLE)
	return Vector2(cos(ang) * facing, sin(ang))


func _loose() -> void:
	var from := _tip()
	if world:
		var s: Dictionary = world.spawn_shot({"kind": "arrow", "owner": "enemy", "pos": from, "vel": aim * ARROW_SPEED, "life": ARROW_LIFE,
				"dmg": dmg("arrow"), "deflect": true, "radius": 6.0, "how": "shot", "breaks": false})
		strike_logged(s, dmg("arrow"))   # the Echoing Omen looses it again
	sfx("arrow_fly", "slash", 1.5)
	shots += 1
	_loose_t = 0.25
	state = "cool"
	timer = cd(COOLDOWN)


func _hurt(h: Dictionary) -> void:
	super(h)
	# A hit spoils the shot.
	if state == "draw":
		state = "cool"
		timer = 0.6
	show_frame("bonebow_hit")


func _kill(h: Dictionary) -> void:
	super(h)
	if h.get("how", "") == "stomp":
		velocity = Vector2.ZERO
	show_frame("bonebow_bones")


func _dying(dt: float) -> void:
	if velocity == Vector2.ZERO:
		show_frame("bonebow_bones")
		fade = clampf(1.8 - death_time * 1.6, 0.0, 1.0)
		if death_time > 1.1:
			gone = true
	else:
		show_frame("bonebow_hit")
		super(dt)


func eye_points() -> Array:
	if state == "idle" and not active:
		return []
	var h := center() + Vector2(facing * 2.0, -9.0)
	return art_eyes(EYES, [h + Vector2(facing * 2.0 - 3.0, 0), h + Vector2(facing * 2.0 + 3.5, 0)])


func lights() -> Array:
	var out := super()
	if state == "draw" and alive:
		var k := 1.0 - clampf(timer / maxf(tell(DRAW), 0.01), 0.0, 1.0)
		out.append({"p": _tip(), "r": 10.0 + 16.0 * k, "s": 0.8})
	return out


func _tip() -> Vector2:
	## The arrowhead: on the drawn arrow, swung round the nock to the aim.
	if frames.is_empty():
		return bow_point() + aim * 10.0
	return bow_point() + aim * (ARROW_TIP.x - NOCK.x) * 0.5 * scale_mult


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if state != "draw" or not alive:
		return
	var k := 1.0 - clampf(timer / maxf(tell(DRAW), 0.01), 0.0, 1.0)
	var tip := _tip()
	# The aim: a faint dashed line that goes white and still when it locks.
	var col := Color(1, 1, 1, 0.75) if locked else Color(1.0, 0.9, 0.75, 0.18 + 0.2 * k)
	for i in 5:
		var a := tip + aim * (8.0 + i * 14.0)
		glow.draw_line(a, a + aim * 7.0, col, 1.5 if locked else 1.0)
	# The glint on the arrowhead.
	var g := 2.0 + 6.0 * k + (3.0 if locked else 0.0)
	var gc := Color(1, 1, 1, 0.95) if locked else Color(1.0, 0.92, 0.7, 0.8)
	glow.draw_circle(tip, g * 0.6, Color(gc, 0.3))
	glow.draw_line(tip + Vector2(-g, 0), tip + Vector2(g, 0), gc, 1.4)
	glow.draw_line(tip + Vector2(0, -g), tip + Vector2(0, g), gc, 1.4)


func _draw() -> void:
	if not frames.is_empty():
		return
	var f := facing
	if not alive and velocity == Vector2.ZERO:
		_draw_bones()
		return
	var bone := Color("efe6d2")
	var shade := Color("c8bea8")
	# Legs and a little pelvis.
	o_line(Vector2(-4, -9), Vector2(-5, -1), 2.5, shade)
	o_line(Vector2(4, -9), Vector2(5, -1), 2.5, shade)
	o_poly(ellipse(Vector2(0, -10), 6, 3), bone, 1.5)
	# Ribs.
	o_poly(ellipse(Vector2(0, -15), 5.5, 5), bone, 1.5)
	draw_line(Vector2(-4, -15), Vector2(4, -15), pc(Color("2a2030")), 1.2)
	draw_line(Vector2(-3, -12.5), Vector2(3, -12.5), pc(Color("2a2030")), 1.2)
	skull(Vector2(f * 1.0, -24), 7.5, f)
	# The bow: an arc on the front, the string pulled back while drawing.
	var bx := f * 9.0
	var pull := 0.0
	if state == "draw":
		pull = 1.0 - clampf(timer / maxf(tell(DRAW), 0.01), 0.0, 1.0)
	var top := Vector2(bx, -26)
	var bot := Vector2(bx, -4)
	var pts := PackedVector2Array()
	for i in 9:
		var s := float(i) / 8.0
		pts.append(top.lerp(bot, s) + Vector2(f * sin(s * PI) * 6.0, 0))
	draw_polyline(pts, pc(OUTLINE), 5.0)
	draw_polyline(pts, pc(Color("b89a6a")), 2.5)
	var nock := Vector2(bx - f * pull * 8.0, -15)
	draw_line(top, nock, pc(Color("e8e0d0")), 1.0)
	draw_line(nock, bot, pc(Color("e8e0d0")), 1.0)
	# The drawing arm, and the arrow on the string.
	o_line(Vector2(f * 3, -16), nock, 2.0, shade)
	if state == "draw":
		draw_line(nock, nock + aim * 16.0, pc(OUTLINE), 3.0)
		draw_line(nock, nock + aim * 16.0, pc(bone), 1.5)


func _draw_bones() -> void:
	var a := clampf(1.8 - death_time * 1.6, 0.0, 1.0)
	var bone := Color(0.94, 0.9, 0.82, a)
	draw_line(Vector2(-9, -2), Vector2(4, -3), Color(0.1, 0.08, 0.14, a), 4.0)
	draw_line(Vector2(-9, -2), Vector2(4, -3), bone, 2.0)
	draw_line(Vector2(-2, -1), Vector2(9, -4), Color(0.1, 0.08, 0.14, a), 4.0)
	draw_line(Vector2(-2, -1), Vector2(9, -4), bone, 2.0)
	draw_circle(Vector2(facing * 5.0, -5), 5.5, Color(0.1, 0.08, 0.14, a))
	draw_circle(Vector2(facing * 5.0, -5), 4.5, bone)
