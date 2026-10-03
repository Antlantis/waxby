extends "res://scripts/elites.gd"
## Lidlurk: a mimic that looks like a "?" reliquary sitting on the floor.
## Asleep, every 5 s it gives itself away: the "?" dims, the lid lifts a
## pixel and it snores (within 3 tiles). Touching it, hitting it or bonking
## it from below wakes it with a 0.5 s tongue-out surprise (harmless); then
## it hops at Wick every 0.8 s (vy -420, vx +-150) and bites (34). A stomp
## hurts it and stuns it for 0.6 s. It always drops an item (world: kind
## "lidlurk") and 12 embers, and never comes back (ordinary = false).

const SNORE_EVERY := 5.0
const SNORE_LEN := 0.6
const SURPRISE := 0.5
const HOP_EVERY := 0.8
const HOP_VY := -420.0
const HOP_VX := 150.0
const STOMP_STUN := 0.6
const GRAV := 1500.0
# W6b's art (frame units, facing right, feet (64,122)): its eyes in the gap
# under the lid, per frame.
const EYES := {
	"lurk_open": [Vector2(58.0, 64.6), Vector2(70.4, 58.8)],
	"lurk_hop": [Vector2(62.0, 57.8), Vector2(73.0, 54.8)],
	"lurk_hit": [Vector2(66.6, 73.8), Vector2(81.1, 72.0)],
}

var state := "sleep"            # sleep, surprise, hop
var timer := 0.0
var _snore := 0.0
var _closed: Sprite2D           # the reliquary it pretends to be
var _qmark := 1.0


func _init() -> void:
	kind = "lidlurk"
	size = Vector2(30, 30)
	base_hp = 60.0
	base_dmg = 34.0
	poise = 0.5
	embers = 12
	item_chance = 0.0
	relic_chance = 0.0


func _ready() -> void:
	super()
	load_frames(["lurk_open", "lurk_hop", "lurk_hit"])
	_closed = Sprite2D.new()
	_closed.centered = false
	_closed.scale = Vector2(0.25, 0.25)
	_closed.position = Vector2(-16, -32)
	var p := "res://art/props/reliquary.svg"
	if ResourceLoader.exists(p):
		_closed.texture = load(p)
	add_child(_closed)
	_snore = fmod(position.x * 0.13, SNORE_EVERY)
	_look()


func asleep() -> bool:
	return state == "sleep"


func touch_damage() -> bool:
	return state == "hop"


func wake() -> void:
	if state != "sleep":
		return
	state = "surprise"
	timer = SURPRISE
	velocity.y = -160.0
	sfx("mimic_chomp", "bat", 0.7)
	if world and world.glow:
		world.glow.burst(center() + Vector2(0, -10), 10, Color("ffd07a"), 120.0, 0.4, 300.0, 2.2)
	_look()


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	var was_asleep := asleep()
	wake()
	var ok := super(h)
	if ok and alive and h.get("how", "") == "stomp":
		apply_status("stun", STOMP_STUN)
	if was_asleep and alive:
		state = "surprise"
		timer = SURPRISE
	return ok


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	velocity.y = minf(velocity.y + GRAV * dt, 700.0)
	match state:
		"sleep":
			velocity.x = 0.0
			_snore -= dt
			if _snore <= 0.0:
				_snore = SNORE_EVERY
				if player.alive and (player.position as Vector2).distance_to(position) < 96.0:
					sfx("mimic_snore", "", 1.0)
			# The give-away: the "?" dims and the lid lifts a pixel.
			var snoring := _snore > SNORE_EVERY - SNORE_LEN
			_qmark = 0.45 if snoring else 1.0
			if _closed:
				_closed.position.y = -33.0 if snoring else -32.0
				_closed.modulate = Color(_qmark, _qmark, _qmark * 0.95)
			if player.alive and (player.rect() as Rect2).intersects(rect().grow(2.0)):
				wake()
		"surprise":
			velocity.x = 0.0
			show_frame("lurk_open")
			if timer <= 0.0:
				state = "hop"
				timer = 0.2
		"hop":
			facing = 1 if player.position.x > position.x else -1
			if on_floor:
				velocity.x = move_toward(velocity.x, 0.0, 1400.0 * dt)
				show_frame("lurk_open")
				if timer <= 0.0 and player.alive:
					velocity = Vector2(facing * spd(HOP_VX), HOP_VY)
					on_floor = false
					timer = cd(HOP_EVERY)
					sfx("mimic_chomp", "bump", 1.2)
			else:
				show_frame("lurk_hop")
	move(dt)
	_look()


func _look() -> void:
	if _closed:
		_closed.visible = asleep() and alive
	if sprite:
		sprite.visible = not asleep()


func _hurt(h: Dictionary) -> void:
	super(h)
	show_frame("lurk_hit")


func _dying(dt: float) -> void:
	show_frame("lurk_hit")
	_look()
	super(dt)


func eye_points() -> Array:
	if asleep():
		return []
	var c := center() + Vector2(facing * 4.0, -6.0)
	return art_eyes(EYES, [c + Vector2(-4, 0), c + Vector2(4, 0)])


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive or asleep():
		return
	for p in eye_points():
		glow.draw_circle(p, 3.4, Color(1.0, 0.75, 0.3, 0.25))
		glow.draw_circle(p, 1.6, Color("ffe6a0"))


func _draw() -> void:
	if asleep() and alive:
		if _closed and _closed.texture == null:
			# No reliquary art: a plain box with a "?".
			o_poly(PackedVector2Array([Vector2(-15, 0), Vector2(-15, -30), Vector2(15, -30), Vector2(15, 0)]), Color("7a5236"), 2.0)
			draw_rect(Rect2(-12, -20, 24, 3), pc(Color("d8a830")))
		return
	if not frames.is_empty():
		return
	var f := facing
	var wood := Color("7a5236")
	var gold := Color("d8a830")
	var mouth := Color("5a1420")
	var open := 1.0 if state == "surprise" else (0.6 + 0.4 * absf(sin(t * 7.0)) if state == "hop" else 0.8)
	# The box.
	o_poly(PackedVector2Array([Vector2(-15, 0), Vector2(-15, -18), Vector2(15, -18), Vector2(15, 0)]), wood, 2.0)
	draw_rect(Rect2(-15, -7, 30, 3), pc(gold))
	# The mouth, teeth, and (surprised) the tongue.
	var lip := -18.0
	var lid := lip - 4.0 - 10.0 * open
	o_poly(PackedVector2Array([Vector2(-13, lip), Vector2(13, lip), Vector2(13, lid + 3), Vector2(-13, lid + 3)]), mouth, 1.0)
	for i in 5:
		var x := -11.0 + i * 5.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, lip), Vector2(x + 3, lip), Vector2(x + 1.5, lip - 3.5)]), pc(Color("fff4e0")))
		draw_colored_polygon(PackedVector2Array([Vector2(x, lid + 3), Vector2(x + 3, lid + 3), Vector2(x + 1.5, lid + 6.5)]), pc(Color("fff4e0")))
	if state == "surprise":
		o_poly(PackedVector2Array([Vector2(f * 2, lip - 2), Vector2(f * 16, lip + 2), Vector2(f * 18, lip + 7), Vector2(f * 12, lip + 6), Vector2(f * 3, lip + 1)]), Color("e0607a"), 1.5)
	# The lid, tipped up, with its gold "?" plate.
	o_poly(PackedVector2Array([Vector2(-16, lid + 3), Vector2(16, lid + 3), Vector2(15, lid - 6), Vector2(-15, lid - 6)]), wood, 2.0)
	draw_rect(Rect2(-16, lid, 32, 3), pc(gold))
