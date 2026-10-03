extends "res://scripts/elites.gd"
## Brinejaw: a bony fish in deep water; only its lure shows (a light, r 20).
## When Wick comes within 96 px across, it gives itself away for 0.4 s
## (ripples, the lure flares, bubbles) and leaps: vy -620, g 1500, drifting
## toward him at 60 px/s (never out over dry land). A bite costs 30 and
## douses; its splash back in douses anyone within 24 px. Near the top of
## the leap (vy > -150) it can be stomped. Cooldown 1.6 s. Under water it
## can't be reached at all.

const SENSE_X := 96.0
const SENSE_UP := 220.0
const TELL_T := 0.4
const LEAP_VY := -620.0
const GRAV := 1500.0
const DRIFT := 60.0
const COOLDOWN := 1.6
const SPLASH_R := 24.0
const APEX_VY := -150.0
const DEPTH := 11.0             # hiding: its middle this far under the water line
# W6b's art (frame units, facing right, middle (64,64)): the eye and the
# lure's false flame per frame (points_monsters.json).
const EYES := {
	"jaw_hide": [Vector2(73.6, 61.0)],
	"jaw_leap": [Vector2(67.5, 54.6)],
	"jaw_fall": [Vector2(71.6, 70.6)],
}
const LURE := {
	"jaw_hide": Vector2(87.4, 45.6),
	"jaw_leap": Vector2(42.1, 59.6),
	"jaw_fall": Vector2(75.7, 44.9),
}

var state := "hide"             # hide, tell, leap, cool
var timer := 0.0
var home := Vector2.ZERO
var surface_y := 0.0
var pool_l := 0.0
var pool_r := 0.0
var _bit := false


func _init() -> void:
	kind = "brinejaw"
	size = Vector2(22, 18)
	base_hp = 16.0
	base_dmg = 30.0
	embers = 3
	item_chance = 0.08
	relic_chance = 0.03
	anchor = Vector2(64, 64)
	flier = true
	stompable = false


func _ready() -> void:
	super()
	load_frames(["jaw_hide", "jaw_leap", "jaw_fall"])
	show_frame("jaw_hide")
	_find_pool()


func _find_pool() -> void:
	## The water line above its cell and how far the pool runs along it.
	if level == null:
		home = position
		surface_y = position.y
		pool_l = position.x - 64.0
		pool_r = position.x + 64.0
		return
	var cx := floori(position.x / TILE)
	var cy := floori(position.y / TILE)
	while cy > 0 and level.tile(cx, cy - 1) == LevelData.WATER:
		cy -= 1
	surface_y = cy * TILE + 8.0
	var l := cx
	while l > 0 and level.tile(l - 1, cy) == LevelData.WATER:
		l -= 1
	var r := cx
	while r < level.width - 1 and level.tile(r + 1, cy) == LevelData.WATER:
		r += 1
	pool_l = l * TILE + size.x * 0.5
	pool_r = (r + 1) * TILE - size.x * 0.5
	# Deep enough to be a shape under the water, with the lure at the line.
	home = Vector2(position.x, surface_y + DEPTH)
	position = home


func submerged() -> bool:
	return state == "hide" or state == "tell" or state == "cool"


func rect() -> Rect2:
	if submerged() and alive:
		return NOWHERE
	return Rect2(position - size * 0.5, size)


func center() -> Vector2:
	return position


func hurt_rect() -> Rect2:
	if submerged():
		return NOWHERE
	return rect().grow(-3.0)


func hit(h: Dictionary) -> bool:
	if submerged():
		return false
	return super(h)


func touch_damage() -> bool:
	## The World is about to bite Wick with it: the bite douses too.
	_bit = true
	return true


func lure() -> Vector2:
	## The false flame on its stalk: the one bit of it that shows.
	if LURE.has(frame_name) and not frames.is_empty():
		var p := frame_point(LURE[frame_name])
		if submerged():
			# It bobs on the water line, whatever the fish below is doing.
			p.y = minf(p.y, surface_y - 1.0 + sin(t * 2.3) * 1.5)
		return p
	if submerged():
		return Vector2(position.x + facing * 7.0, surface_y - 5.0 + sin(t * 2.3) * 1.5)
	return position + Vector2(facing * 9.0, -13.0)


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	if _bit:
		_bit = false
		if player.get("hurt_time") != null and float(player.hurt_time) < 0.1 and world:
			world.douse_player()
	var dx: float = player.position.x - position.x
	tint.a = 0.3 if submerged() else 1.0
	match state:
		"hide":
			show_frame("jaw_hide")
			position = home + Vector2(sin(t * 0.9) * 6.0, sin(t * 1.7) * 2.0)
			if absf(dx) > 3.0:
				facing = 1 if dx > 0.0 else -1
			if player.alive and absf(dx) < SENSE_X and player.position.y < surface_y + 4.0 and surface_y - player.position.y < SENSE_UP:
				state = "tell"
				timer = tell(TELL_T)
				sfx("splash", "", 1.6)
		"tell":
			position = home + Vector2(sin(t * 30.0) * 1.5, -4.0)
			if timer <= 0.0:
				_leap(player)
		"leap":
			show_frame("jaw_leap" if velocity.y < 0.0 else "jaw_fall")
			velocity.y += GRAV * dt
			var want := signf(dx) * spd(DRIFT) if absf(dx) > 4.0 else 0.0
			velocity.x = move_toward(velocity.x, want, 400.0 * dt)
			position += velocity * dt
			position.x = clampf(position.x, pool_l, pool_r)
			stompable = velocity.y > APEX_VY
			if velocity.y > 0.0 and position.y >= surface_y + 6.0:
				_reenter(player)
		"cool":
			show_frame("jaw_hide")
			var back := home - position
			position += back.limit_length(80.0 * dt)
			if timer <= 0.0:
				state = "hide"


func _leap(player: Node2D) -> void:
	state = "leap"
	position = Vector2(position.x, surface_y)
	var dx: float = player.position.x - position.x
	velocity = Vector2(signf(dx) * spd(DRIFT) if absf(dx) > 4.0 else 0.0, LEAP_VY)
	facing = 1 if dx >= 0.0 else -1
	_splash_fx(position.x)
	sfx("splash", "bat", 1.0)


func _reenter(player: Node2D) -> void:
	state = "cool"
	timer = cd(COOLDOWN)
	stompable = false
	velocity = Vector2.ZERO
	home.x = position.x
	_splash_fx(position.x)
	sfx("splash", "", 0.85)
	var at := Vector2(position.x, surface_y)
	if player.alive and world and (player.rect() as Rect2).grow(SPLASH_R).has_point(at):
		world.douse_player()


func _splash_fx(x: float) -> void:
	if world and world.glow:
		world.glow.burst(Vector2(x, surface_y), 14, Color(0.8, 0.92, 1.0, 0.9), 150.0, 0.45, 700.0, 2.2, 120.0)


func _dying(dt: float) -> void:
	show_frame("jaw_fall")
	velocity.y = minf(velocity.y + 1200.0 * dt, 500.0)
	position += velocity * dt
	rotation += dt * 5.0 * facing
	fade = clampf(1.4 - death_time, 0.0, 1.0)
	if death_time > 1.4:
		gone = true


func eye_points() -> Array:
	if submerged():
		return []
	return art_eyes(EYES, [position + Vector2(facing * 4.0, -3.0)])


func lights() -> Array:
	var out := super()
	if alive:
		out.append({"p": lure(), "r": 34.0 if state == "tell" else 20.0, "s": 0.8})
	return out


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var l := lure()
	var bright := 1.0 if state == "tell" else 0.6 + 0.2 * sin(t * 3.0)
	glow.draw_circle(l, 7.0 * bright, Color(0.6, 1.0, 0.85, 0.2))
	glow.draw_circle(l, 2.6 + bright, Color(0.85, 1.0, 0.9, 0.95))
	if state == "tell":
		# Ripples ring out from where it'll come up.
		var k := 1.0 - clampf(timer / maxf(tell(TELL_T), 0.01), 0.0, 1.0)
		for i in 2:
			var r := 6.0 + (k + i * 0.5) * 16.0
			var pts := PackedVector2Array()
			for j in 13:
				var a := PI + PI * j / 12.0
				pts.append(Vector2(position.x, surface_y) + Vector2(cos(a) * r, sin(a) * r * 0.25))
			glow.draw_polyline(pts, Color(0.8, 0.95, 1.0, 0.7 * (1.0 - k * 0.5)), 1.5)
		for i in 3:
			var b := fmod(t * 2.5 + i * 0.33, 1.0)
			glow.draw_circle(Vector2(position.x + (i - 1) * 6.0, surface_y + 8.0 - b * 10.0), 1.5 + b, Color(0.85, 0.95, 1.0, 0.6))


func _draw() -> void:
	if not frames.is_empty():
		return
	var f := facing
	if submerged():
		# A shape under the water.
		o_poly(ellipse(Vector2(0, 0), 12, 6, 12), Color(0.2, 0.25, 0.3, 0.45), 0.0)
		return
	var bone := Color("e8e0cc")
	var shade := Color("b8ae98")
	var dark := Color("2a2030")
	var up := velocity.y < 0.0
	var tilt := 0.35 if up else -0.3
	draw_set_transform(Vector2.ZERO, tilt * -f, Vector2.ONE)
	# The body: a bony fish, all head and jaw.
	var body := PackedVector2Array([Vector2(-f * 12, 0), Vector2(-f * 6, -7), Vector2(f * 6, -8), Vector2(f * 12, -3),
			Vector2(f * 12, 3), Vector2(f * 5, 7), Vector2(-f * 6, 6)])
	o_poly(body, bone, 2.0)
	# The tail.
	o_poly(PackedVector2Array([Vector2(-f * 11, 0), Vector2(-f * 18, -7), Vector2(-f * 16, 0), Vector2(-f * 18, 7)]), shade, 1.5)
	# Ribs, the eye and the gaping jaw with teeth.
	for i in 3:
		draw_line(Vector2(-f * (4 - i * 4), -5), Vector2(-f * (4 - i * 4), 4), pc(shade), 1.5)
	draw_circle(Vector2(f * 4, -3), 2.6, pc(dark))
	draw_colored_polygon(PackedVector2Array([Vector2(f * 12, 0), Vector2(f * 6, 1), Vector2(f * 12, 5)]), pc(dark))
	for i in 3:
		var x := f * (7 + i * 2)
		draw_colored_polygon(PackedVector2Array([Vector2(x, -0.5), Vector2(x + f * 1.2, -0.5), Vector2(x + f * 0.6, 2)]), pc(Color("ffffff")))
	# The lure on its stalk.
	draw_line(Vector2(f * 2, -8), Vector2(f * 9, -13), pc(dark), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
