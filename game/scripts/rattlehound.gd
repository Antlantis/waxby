extends "res://scripts/elites.gd"
## Rattlehound (m, World 3 heavy): a lean skeletal hound, low and long, with
## a big round skull and a green lantern-glint in one socket. It prowls at
## PROWL px/s; when it sees Wick within SEE px (line of sight) it howls
## (HOWL s, the eye flares), then chases at CHASE px/s (faster than his
## 205), turning in TURN s with a skid. Within CROUCH_X on the same floor it
## crouches (the tell, CROUCH s: haunches down, the teeth glint, and its
## arc and landing mark show on the glow layer), then pounces at his x at
## the crouch's start (spec §4.3): vy POUNCE_VY, g POUNCE_G (49 px high,
## FLIGHT s in the air) and the vx that lands it there, at most POUNCE_VX
## (about 150 px long), never retargeting in the air. Standing still, he is
## bitten as it comes down on him; a step away, or a jump pressed in the
## crouch or as it leaps, and it lands on empty floor (a jump comes down on
## its back: a stomp). It lands open (LAND s, skidding); after TIRE_AFTER
## pounces it pants PANT s (+25% damage). Counter: turn and face it, jump the
## pounce, hit the landing.
##
## A stomp stuns it STOMP_STUN s; a Perfect Guard bops its nose (the knight's
## 1.0 s stagger); the Bellfounder's maul from above pins it PIN s; after an
## overshoot its back faces a Sootrunner (a Backstab). Nightfall: a second
## pounce SECOND_AFTER s after landing (crouch 0.40); an Anointed or a Dread
## on Dusk from World 3 too (behave_diff). Witching: chase 270, tires after 4.

const MOVES := {"pounce": 34.0, "touch": 24.0}
const ARCHETYPE := "heavy"
const TELLS := {"crouch": {"sec": 0.45, "floor": 0.40, "jump": true}, "crouch2": {"sec": 0.40, "floor": 0.40, "jump": true},
		"howl": {"sec": 0.55, "floor": 0.40}}
const FRAMES := ["hound_prowl1", "hound_prowl2", "hound_howl", "hound_run1", "hound_run2", "hound_crouch", "hound_pounce",
		"hound_land", "hound_pant", "hound_hit"]
const PROWL := 50.0
const SEE := 280.0
const HOWL := 0.55
const CHASE := 250.0
const CHASE_WITCHING := 270.0
const TURN := 0.25
const CROUCH_X := 90.0
const CROUCH := 0.45
const CROUCH2 := 0.40
const POUNCE_VX := 330.0
const POUNCE_VY := -420.0
const POUNCE_G := 1800.0
const FLIGHT := -2.0 * POUNCE_VY / POUNCE_G   # 0.467 s from leap to landing on level ground
const LAND := 0.7
const LAND_BRAKE := 2000.0         # its skid on landing: about 9 px from a 190 px/s leap
const TIRE_AFTER := 3
const TIRE_WITCHING := 4
const PANT := 1.5
const PANT_BONUS := 1.25
const SECOND_AFTER := 0.35
const STOMP_STUN := 0.6
const PIN := 1.2
const LOSE := 420.0              # it gives up the chase past this
const BONE := Color("efe6d2")
const BONE_SHADE := Color("b8ab92")
const DARK := Color("2a2030")
const GLINT := Color("7ef0a0")

var state := "prowl"             # prowl, howl, chase, turn, crouch, pounce, land, pant
var timer := 0.0
var tell_len := 0.0
var move_id := "touch"
var pounces := 0
var pounce_dir := 1
var aim_x := 0.0                 # his x at the crouch's start: where it means to land
var pounce_to := 0.0             # where it will land (aim_x, or as far as POUNCE_VX reaches)
var pounce_vx := POUNCE_VX       # the leap's speed that lands it there (at most POUNCE_VX)
var _second := false             # Nightfall's second pounce is owed
var _in_pair := false            # the pounce in the air is the first of Nightfall's pair
var _walk := 0.0
var _prowl_t := 0.0
var _hit_this_pounce := false


func _init() -> void:
	kind = "rattlehound"
	size = Vector2(34, 22)
	base_hp = 36.0
	base_dmg = MOVES["touch"]
	poise = 0.25
	embers = 5
	item_chance = 0.12
	relic_chance = 0.03
	echo_by_body = false


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("hound_prowl1")


func dmg(what := "touch") -> float:
	if what == "touch" and state == "pounce":
		what = "pounce"
	return float(MOVES.get(what, base_dmg)) * dmg_mult


func tires_after() -> int:
	return TIRE_WITCHING if difficulty() == "witching" else TIRE_AFTER


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	var dx: float = player.position.x - position.x
	match state:
		"prowl":
			move_id = "touch"
			_prowl_t += dt
			if _prowl_t > 2.2:
				# Sniffing back and forth (walk() turns it at walls and edges).
				_prowl_t = 0.0
				facing = -facing
			walk(dt, spd(PROWL))
			_walk += dt
			show_frame("hound_prowl1" if fmod(_walk, 0.5) < 0.25 else "hound_prowl2")
			if player.alive and absf(dx) < SEE and absf(player.position.y - position.y) < 96.0 and sees(player.center()):
				state = "howl"
				facing = 1 if dx > 0.0 else -1
				timer = tell(HOWL)
				tell_len = timer
				velocity.x = 0.0
				tell_sfx("hound_howl", timer, "boss_roar")
		"howl":
			_brake(dt, 2000.0)
			show_frame("hound_howl")
			if timer <= 0.0:
				state = "chase"
		"chase":
			if not player.alive or absf(dx) > LOSE:
				state = "prowl"
				return
			var want := 1 if dx > 0.0 else -1
			if want != facing and absf(dx) > 12.0:
				state = "turn"
				timer = TURN
				return
			if absf(dx) < CROUCH_X and near_floor(player) and on_floor:
				_crouch(player, tell(CROUCH, TELLS["crouch"]["floor"]))
				return
			var v := spd(CHASE_WITCHING if difficulty() == "witching" else CHASE)
			velocity.x = move_toward(velocity.x, facing * v, 2400.0 * dt)
			if on_floor and not ground_ahead(facing):
				# It won't run off an edge after him: it waits there, growling.
				velocity.x = 0.0
			velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
			move(dt)
			_walk += dt * 2.0
			show_frame("hound_run1" if fmod(_walk, 0.3) < 0.15 else "hound_run2")
		"turn":
			# A skid: it slides to a stop and swings round.
			_brake(dt, 1400.0)
			show_frame("hound_land")
			if timer <= 0.0:
				facing = 1 if dx > 0.0 else -1
				state = "chase"
		"crouch":
			_brake(dt, 3000.0)
			_aim()
			show_frame("hound_crouch")
			if timer <= 0.0:
				_pounce()
		"pounce":
			velocity.y = minf(velocity.y + POUNCE_G * dt, 900.0)
			var was := on_floor
			move(dt)
			show_frame("hound_pounce")
			if not _hit_this_pounce and player.alive and hurt_rect().intersects(player.rect()):
				_hit_this_pounce = true
			if on_floor and not was and velocity.y >= 0.0:
				_land()
		"land":
			_brake(dt, LAND_BRAKE)
			show_frame("hound_land")
			if timer <= 0.0:
				if _second:
					_second = false
					facing = 1 if dx > 0.0 else -1
					_crouch(player, tell(CROUCH2, TELLS["crouch2"]["floor"]))
				elif pounces >= tires_after():
					state = "pant"
					timer = PANT
					pounces = 0
					sfx("hound_pant", "talk_breath")
				else:
					state = "chase"
		"pant":
			_brake(dt, 2000.0)
			show_frame("hound_pant")
			if timer <= 0.0:
				state = "chase"


func _brake(dt: float, rate: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, rate * dt)
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)


func _crouch(player: Node2D, sec: float) -> void:
	## The tell: its haunches go down; the pounce's way is fixed now.
	state = "crouch"
	timer = sec
	tell_len = sec
	pounce_dir = 1 if player.position.x > position.x else -1
	facing = pounce_dir
	# Aimed at where he stands now (never retargeted): the landing x.
	aim_x = player.position.x
	_aim()
	tell_sfx("hound_growl", sec, "mimic_snore")


func _aim() -> void:
	## The leap from where it is to aim_x (at most POUNCE_VX, never back the
	## other way): its vx and its landing x. Kept up through the crouch (it
	## skids a little as it drops), so the tell's arc is the leap's.
	pounce_vx = clampf((aim_x - position.x) * pounce_dir / FLIGHT, 0.0, POUNCE_VX)
	pounce_to = position.x + pounce_dir * pounce_vx * FLIGHT


func _pounce() -> void:
	state = "pounce"
	move_id = "pounce"
	pounces += 1
	_hit_this_pounce = false
	_aim()
	velocity = Vector2(pounce_dir * pounce_vx, POUNCE_VY)
	on_floor = false
	sfx("hound_bite", "mimic_chomp")
	# The Echoing Omen repeats the bite where it comes down (the landing mark).
	strike_logged({"rect": landing_rect(), "life": 0.3}, dmg("pounce"))


func landing_rect() -> Rect2:
	## Where the pounce comes down: its body at the landing x (world space).
	return Rect2(pounce_to - size.x * 0.5, position.y - size.y - 6.0, size.x, size.y + 6.0)


func arc_point(tt: float) -> Vector2:
	## The pounce's feet tt s after the leap (the arc the tell draws; on
	## level ground it lands at tt = FLIGHT).
	return position + Vector2(pounce_dir * pounce_vx * tt, POUNCE_VY * tt + 0.5 * POUNCE_G * tt * tt)


func _land() -> void:
	## Open: LAND s of skid (Nightfall: a second pounce SECOND_AFTER s after
	## the first lands, then the full landing after the second).
	state = "land"
	move_id = "touch"
	if behave_diff() != "dusk" and not _in_pair and pounces < tires_after():
		_in_pair = true
		_second = true
		timer = SECOND_AFTER
	else:
		_in_pair = false
		_second = false
		timer = LAND
	if world != null and world.has_method("dust_at"):
		world.dust_at(position)
	sfx("bone_rattle", "bones", 1.1)


func panting() -> bool:
	return state == "pant"


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	var how := str(h.get("how", "slash"))
	if panting() and h.has("amount"):
		h["amount"] = float(h["amount"]) * PANT_BONUS
	var pinned := false
	if is_maul(h) and world != null and world.player != null:
		var pl: Node2D = world.player
		# The maul from above pins it (flipped-style).
		pinned = not pl.on_floor and pl.position.y < center().y
	var ok := super(h)
	if ok and alive:
		if how == "stomp":
			apply_status("stun", STOMP_STUN)
			_calm()
		elif pinned:
			apply_status("flipped", PIN)
			_calm()
	return ok


func _calm() -> void:
	## A stun, a pin or a bop cuts its move short; it chases again after.
	if state in ["crouch", "pounce", "howl"]:
		state = "chase"
		move_id = "touch"


func apply_status(name: String, seconds: float, data := {}) -> void:
	super(name, seconds, data)
	if name in ["stun", "root", "flipped"]:
		_calm()


func _dying(dt: float) -> void:
	show_frame("hound_hit")
	super(dt)


func lights() -> Array:
	var out := super()
	if alive and state in ["howl", "crouch"]:
		out.append({"p": _eye_world(), "r": 30.0, "s": 0.6})
	return out


func _eye_world() -> Vector2:
	var h := size.y
	var head := Vector2(facing * (size.x * 0.5 - 2.0), -h * 0.75)
	if state == "crouch":
		head.y += 5.0
	return position + head + Vector2(facing * 2.0, 0.0)


func eye_points() -> Array:
	if tier == "" or has_omen("hushed"):
		return []
	return [_eye_world()]


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := gtb()
	# The green lantern-glint in its socket is always there (the dark).
	var eye := _eye_world()
	var hot := state in ["howl", "crouch"]
	glow_eyes(tb, art_points(POINTS3, "eyes", [eye]), GLINT, 3.0 if not hot else 4.5)
	if state == "crouch":
		# The tell: the teeth glint, and the arc it will fly (the very
		# numbers of the leap) ends on a landing mark where he stands.
		var k := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
		var jaw := position + Vector2(facing * (size.x * 0.5 + 3.0), -6.0)
		tb.line(jaw + Vector2(-3, 0), jaw + Vector2(3, 0), 1.6, Color(1.0, 1.0, 0.9, 0.6 + 0.4 * k))
		tb.line(jaw + Vector2(0, -3), jaw + Vector2(0, 3), 1.6, Color(1.0, 1.0, 0.9, 0.6 + 0.4 * k))
		var pts := PackedVector2Array()
		for i in 9:
			pts.append(arc_point(FLIGHT * i / 8.0) + Vector2(0, -size.y * 0.5))
		tb.polyline(pts, 2.0, Color(GLINT, 0.35 + 0.45 * k))
		var mark := Vector2(pounce_to, position.y - 1.0)
		tb.ellipse(mark, size.x * 0.55, 3.5, Color(GLINT, 0.25 + 0.35 * k), 16)
		tb.ring(mark, size.x * 0.5 * (1.5 - 0.5 * k), 1.8, Color(GLINT, 0.45 + 0.45 * k), 18, PI, TAU)
	elif state == "howl":
		var k2 := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
		for i in 3:
			var rr := 8.0 + (k2 * 3.0 + i) * 6.0
			tb.ring(eye, rr, 1.4, Color(GLINT, maxf(0.0, 0.5 - i * 0.15)), 16, -PI * 0.9, -PI * 0.1)
	elif state == "pant":
		var c := Vector2(position.x, rect().position.y - 6.0)
		for i in 2:
			var k3 := fmod(t * 1.5 + i * 0.5, 1.0)
			tb.circle(c + Vector2(facing * 8.0, -k3 * 10.0), 2.0 + k3 * 2.0, Color(0.9, 0.9, 1.0, 0.6 * (1.0 - k3)), 8)
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var tb := btb()
	var f := float(facing)
	var sm := scale_mult
	var h := size.y
	var low := 5.0 if state == "crouch" else (-3.0 if state == "howl" else 0.0)
	var gait := sin(_walk * TAU / (0.3 if state == "chase" else 0.5))
	# The legs (four bones), then the tail, the ribcage body and the skull.
	var body_y := -h * 0.55 + low * 0.5
	for i in 4:
		var hx := (-11.0 + i * 7.0) * sm
		var sw := gait * 3.0 * (1.0 if i % 2 == 0 else -1.0)
		if state in ["pounce"]:
			sw = (-5.0 if i < 2 else 5.0) * f
		cel_line(tb, Vector2(hx * f, body_y + 3.0), Vector2(hx * f + sw, -1.0), 2.4 * sm, BONE_SHADE, 1.2)
	var wag := sin(t * 14.0) * 4.0
	cel_line(tb, Vector2(-f * 15.0 * sm, body_y - 2.0), Vector2(-f * 22.0 * sm, body_y - 8.0 + wag), 2.2 * sm, BONE, 1.2)
	cel_ellipse(tb, Vector2(0, body_y), 14.0 * sm, 6.5 * sm, BONE, 2.0)
	for i in 4:
		var rx := (-8.0 + i * 5.0) * sm
		tb.line(Vector2(rx * f, body_y - 5.0 * sm), Vector2(rx * f + f * 1.5, body_y + 5.0 * sm), 1.6 * sm, pc(DARK))
	var head := Vector2(f * (size.x * 0.5 - 2.0), -h * 0.75 + low)
	cel_circle(tb, head, 8.0 * sm, BONE, 2.0)
	cel_poly(tb, PackedVector2Array([head + Vector2(f * 2.0, 3.0) * sm, head + Vector2(f * 11.0, 3.0) * sm,
			head + Vector2(f * 10.0, 7.5) * sm, head + Vector2(f * 1.0, 7.5) * sm]), BONE, 1.5)
	tb.circle(head + Vector2(-f * 2.5, -0.5) * sm, 2.2 * sm, pc(DARK), 8)
	tb.circle(head + Vector2(f * 2.0, -0.5) * sm, 2.4 * sm, pc(DARK), 8)
	if state == "pant":
		cel_line(tb, head + Vector2(f * 8.0, 7.0) * sm, head + Vector2(f * 9.0, 12.0) * sm, 2.0 * sm, Color("e07a8a"), 1.0)
	tb.flush(self)
