extends "res://scripts/elites.gd"
## Tickwind (j, World 4 fodder): a chibi wind-up toy soldier of brass and
## frosted wax: a drum body, a tall shako with an icicle plume, rosy cheeks
## and a big key in its back. It marches at MARCH px/s, a step on each of the
## level's ticks (level.tick, 0.536 s, read from world.ftime). When it sees
## Wick ahead of it within SEE px on its floor (+-1 tile, line of sight) it
## winds (the tell, WIND s: the key spins, a ratchet rises, steam puffs, the
## key glints), then charges straight at CHARGE px/s for up to CHARGE_MAX s,
## unable to turn. On ice it slides until it hits a wall; at an edge it
## tumbles off (a pit kills it, how "pit"). A wall leaves it dizzy DIZZY s
## (+50%); stopping without one, run down RUNDOWN s.
##
## A hit on its back (Combat.is_back_hit) while it marches or winds stops it
## cold: "Unwound!", run down UNWOUND s. A Knight's Perfect Guard on its
## charge sends it back x1.25 as a bowling ball (1.0x basic to every monster
## in its path); a stomp kills it (fodder). Nightfall (and an elite on Dusk
## from World 3, behave_diff): charge 330. Witching:
## wind 0.45 (floor 0.40), and Tickwinds within FILE_X wind with it and
## charge as a file (the file, at its own wind, under a level's packs twist).

const Twists := preload("res://scripts/twists.gd")
const MOVES := {"charge": 32.0, "touch": 26.0}
const ARCHETYPE := "fodder"
const TELLS := {"wind": {"sec": 0.55, "floor": 0.40, "jump": true}}
const FRAMES := ["tick_march1", "tick_march2", "tick_wind", "tick_charge", "tick_dizzy", "tick_hit"]
const MARCH := 55.0
const SEE := 240.0
const WIND := 0.55
const WIND_WITCHING := 0.45
const CHARGE := 300.0
const CHARGE_NF := 330.0
const CHARGE_MAX := 1.6
const DIZZY := 1.2
const RUNDOWN := 0.8
const UNWOUND := 1.5
const BOWL_MULT := 1.25
const FILE_X := 64.0
const PG_STUN_MIN := 0.9          # a stun this long on a charge is a Perfect Guard's (knight.gd PG_STUN 1.0)
const BRASS := Color("c8a24a")
const BRASS_DARK := Color("8a6a2a")
const COAT := Color("b83a3a")
const SHAKO := Color("2a3a6a")
const ICE := Color("bfe8ff")
const WAX := Color("f0e6d6")
const CHEEK := Color("f08a8a")

var state := "march"             # march, wind, charge, bowled, rundown
var timer := 0.0
var tell_len := 0.0
var move_id := "touch"
var charge_dir := 1
var _charge_t := 0.0
var _tick_i := -1
var _bowled_ids: Array = []
var _key_spin := 0.0
var _steam_t := 0.0


func _init() -> void:
	kind = "tickwind"
	size = Vector2(20, 28)
	base_hp = 20.0
	base_dmg = MOVES["touch"]
	poise = 0.0
	embers = 3
	item_chance = 0.08


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("tick_march1")


func dmg(what := "touch") -> float:
	if what == "touch" and state in ["charge", "bowled"]:
		what = "charge"
	return float(MOVES.get(what, base_dmg)) * dmg_mult


func touch_damage() -> bool:
	## Bowled back by a Perfect Guard, it's his missile, not a threat to him.
	return state != "bowled"


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_key_spin += dt * (18.0 if state == "wind" else (0.0 if state == "rundown" else 3.0))
	if lost_in_pit():
		_kill({"how": "pit", "from_x": position.x})
		return
	match state:
		"march":
			move_id = "touch"
			# A step on each tick: it strides in the first half of the beat.
			var beat := fmod(clock(), tick_len()) / tick_len()
			var i := floori(clock() / tick_len())
			if i != _tick_i:
				_tick_i = i
				if absf(player.position.x - position.x) < 260.0:
					sfx("tick_step", "step", 1.3)
			walk(dt, spd(MARCH) * (1.6 if beat < 0.5 else 0.4))
			show_frame("tick_march1" if beat < 0.5 else "tick_march2")
			if _sees_ahead(player):
				start_wind(player)
		"wind":
			velocity.x = 0.0
			_fall(dt)
			show_frame("tick_wind")
			_steam_t -= dt
			if _steam_t <= 0.0 and world != null and world.get("glow") != null:
				_steam_t = 0.12
				world.glow.burst(position + Vector2(-facing * 2.0, -size.y - 4.0), 2, Color(0.9, 0.92, 1.0, 0.7), 40.0, 0.5, -60.0, 2.4, 40.0)
			if timer <= 0.0:
				_charge()
		"charge", "bowled":
			var v := spd(CHARGE_NF if behave_diff() != "dusk" else CHARGE)
			if state == "bowled":
				v = CHARGE * BOWL_MULT
				_bowl_others()
			velocity.x = charge_dir * v
			_charge_t += dt
			_fall(dt)
			show_frame("tick_charge")
			if on_wall != 0:
				_stop(true)
			elif _charge_t >= CHARGE_MAX and on_floor and not slick_under():
				_stop(false)
		"rundown":
			velocity.x = move_toward(velocity.x, 0.0, (300.0 if slick_under() else 1600.0) * dt)
			_fall(dt)
			show_frame("tick_wind")
			if timer <= 0.0:
				state = "march"


func _fall(dt: float) -> void:
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)


func _sees_ahead(player: Node2D) -> bool:
	if not player.alive:
		return false
	var dx: float = player.position.x - position.x
	return dx * facing > 0.0 and absf(dx) < SEE and absf(player.position.y - position.y) <= TILE + 1.0 \
			and on_floor and sees(player.center())


func start_wind(player: Node2D) -> void:
	## The tell (and, on Witching, the file's: those within FILE_X wind with it).
	if state != "march":
		return
	state = "wind"
	var sec := tell(WIND_WITCHING, TELLS["wind"]["floor"]) if difficulty() == "witching" else tell(WIND, TELLS["wind"]["floor"])
	timer = sec
	tell_len = sec
	charge_dir = facing
	velocity.x = 0.0
	tell_sfx("wind_up", sec, "arrow_draw")
	# (A level's packs twist marches them as Witching's file, at this difficulty's wind.)
	if (difficulty() == "witching" or Twists.on(self, "packs")) and world != null:
		for e in world.enemies:
			if e != self and e.alive and e.get("kind") == "tickwind" and e.get("state") == "march" \
					and absf(e.position.x - position.x) <= FILE_X and absf(e.position.y - position.y) < 8.0:
				e.facing = facing
				e.start_wind(player)
				e.timer = timer


func _charge() -> void:
	state = "charge"
	move_id = "charge"
	_charge_t = 0.0
	facing = charge_dir
	sfx("spring_boing", "chain_step", 1.1)


func _stop(wall: bool) -> void:
	move_id = "touch"
	if wall:
		# Into a wall: dizzy (+50%).
		state = "rundown"
		timer = 0.2
		velocity.x = 0.0
		apply_status("dazed", DIZZY)
		sfx("clank", "clang", 0.9)
		if world != null and world.has_method("dust_at"):
			world.dust_at(position + Vector2(charge_dir * size.x * 0.5, -size.y * 0.5))
	else:
		state = "rundown"
		timer = RUNDOWN


func _bowl_others() -> void:
	## Bowled back: it knocks over every monster in its path (the hero's blow).
	if world == null:
		return
	for e in world.enemies:
		if e == self or not e.alive or not e.active or e == world.get("boss") or _bowled_ids.has(e.get_instance_id()):
			continue
		if rect().intersects(e.rect()):
			_bowled_ids.append(e.get_instance_id())
			world.deal(e, 1.0, {"how": "skill", "from_x": position.x - charge_dir * 10.0, "heavy": true})


func apply_status(name: String, seconds: float, data := {}) -> void:
	if name == "stun" and (perfect_guarded() or seconds >= PG_STUN_MIN) and state == "charge":
		# A Perfect Guard (or a Peal's long stun: spec §4.4, the Peal bowls
		# it too): sent back the way it came, a bowling ball.
		state = "bowled"
		charge_dir = -charge_dir
		facing = charge_dir
		_charge_t = 0.0
		_bowled_ids.clear()
		sfx("spring_boing", "chain_step", 0.8)
		return
	if name in ["stun", "root", "flipped"] and state in ["wind", "charge"]:
		state = "rundown"
		timer = 0.1
		move_id = "touch"
	super(name, seconds, data)


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	var how := str(h.get("how", "slash"))
	var ok := super(h)
	if ok and alive and state in ["march", "wind"] and how != "stomp" and Combat.is_back_hit(self, float(h.get("from_x", position.x))):
		# Struck on its key: unwound.
		state = "rundown"
		timer = UNWOUND
		velocity.x = 0.0
		move_id = "touch"
		pop_word("Unwound!")
		sfx("clank", "clang", 1.3)
	return ok


func _kill(h: Dictionary) -> void:
	super(h)
	if str(h.get("how", "")) == "pit":
		velocity = Vector2(0.0, 60.0)
		sfx("clank", "clang", 0.6)


func _dying(dt: float) -> void:
	show_frame("tick_hit")
	super(dt)


func key_point() -> Vector2:
	## The key in its back (world space).
	return position + Vector2(-facing * (size.x * 0.5 + 3.0), -size.y * 0.55)


func lights() -> Array:
	var out := super()
	if alive and state == "wind":
		out.append({"p": key_point(), "r": 20.0, "s": 0.6})
	return out


func eye_points() -> Array:
	if tier == "" or has_omen("hushed"):
		return []
	return [position + Vector2(facing * 4.0, -size.y * 0.62)]


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := gtb()
	glow_eyes(tb, art_points(POINTS3, "eyes", [position + Vector2(facing * 4.0, -size.y * 0.62)]), Color(0.95, 0.9, 0.7), 1.5)
	if state == "wind":
		var k := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
		var kp := key_point()
		# The key glints, a ratchet rises round it, and the floor ahead streaks
		# the way it will run.
		tb.circle(kp, 3.0 + 2.5 * k, Color(1.0, 0.9, 0.55, 0.8 + 0.2 * k), 12)
		var teeth := int(3 + 6 * k)
		for i in teeth:
			var a := -PI * 0.5 + (i - teeth * 0.5) * 0.35
			var p := kp + Vector2(cos(a), sin(a)) * 9.0
			tb.line(p, p + Vector2(cos(a), sin(a)) * 3.0, 1.4, Color(1.0, 0.85, 0.5, 0.75))
		var y := position.y - 2.0
		var x0 := position.x + charge_dir * (size.x * 0.5 + 4.0)
		for i in 4:
			var xa := x0 + charge_dir * (i * 18.0)
			tb.line(Vector2(xa, y), Vector2(xa + charge_dir * 10.0, y), 1.6, Color(1.0, 0.85, 0.5, (0.2 + 0.5 * k) * (1.0 - i * 0.2)))
	elif state == "charge" or state == "bowled":
		for i in 3:
			var p2 := position + Vector2(-charge_dir * (size.x * 0.5 + 6.0 + i * 7.0), -6.0 - i * 5.0)
			tb.line(p2, p2 + Vector2(-charge_dir * 8.0, 0.0), 1.4, Color(1.0, 0.95, 0.8, 0.5 - i * 0.12))
	if status.has("dazed"):
		var c := Vector2(position.x, rect().position.y - 6.0)
		for i in 3:
			var a2 := t * 5.0 + TAU * i / 3.0
			tb.circle(c + Vector2(cos(a2) * 9.0, sin(a2) * 3.0), 2.0, Color(1.0, 0.95, 0.6, 0.9), 8)
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var tb := btb()
	var f := float(facing)
	var sm := scale_mult
	var h := size.y
	var lean := 3.0 if state in ["charge", "bowled"] else 0.0
	var bob := -1.5 if state == "march" and fmod(clock(), tick_len()) / tick_len() < 0.5 else 0.0
	# Legs.
	cel_line(tb, Vector2(-3.0 * sm, -8.0 * sm + bob), Vector2(-3.5 * sm + (f * 2.0 if bob < 0.0 else 0.0), 0.0), 3.0 * sm, WAX, 1.2)
	cel_line(tb, Vector2(3.0 * sm, -8.0 * sm + bob), Vector2(3.5 * sm - (f * 2.0 if bob < 0.0 else 0.0), 0.0), 3.0 * sm, WAX, 1.2)
	# The key, in its back, turning.
	var kp := Vector2(-f * (size.x * 0.5 + 3.0), -h * 0.55 + bob)
	var ka := _key_spin
	cel_line(tb, kp + Vector2(f * 4.0, 0.0), kp, 2.2 * sm, BRASS_DARK, 1.0)
	cel_ellipse(tb, kp + Vector2(0.0, -4.0 * absf(cos(ka))) * sm, 2.0 * sm, 4.0 * absf(cos(ka)) * sm + 1.0, BRASS, 1.2, 10)
	cel_ellipse(tb, kp + Vector2(0.0, 4.0 * absf(cos(ka))) * sm, 2.0 * sm, 4.0 * absf(cos(ka)) * sm + 1.0, BRASS, 1.2, 10)
	# The drum body.
	var bc := Vector2(f * lean, -h * 0.45 + bob)
	cel_poly(tb, PackedVector2Array([bc + Vector2(-8.0, -7.0) * sm, bc + Vector2(8.0, -7.0) * sm, bc + Vector2(8.0, 7.0) * sm,
			bc + Vector2(-8.0, 7.0) * sm]), COAT, 2.0)
	tb.rect(Rect2(bc + Vector2(-8.0, -7.0) * sm, Vector2(16.0, 2.5) * sm), pc(BRASS))
	tb.rect(Rect2(bc + Vector2(-8.0, 4.5) * sm, Vector2(16.0, 2.5) * sm), pc(BRASS))
	tb.line(bc + Vector2(-6.0, -4.0) * sm, bc + Vector2(6.0, 4.0) * sm, 1.2 * sm, pc(Color("f0d8a0")))
	tb.line(bc + Vector2(6.0, -4.0) * sm, bc + Vector2(-6.0, 4.0) * sm, 1.2 * sm, pc(Color("f0d8a0")))
	# The head: a wax face with rosy cheeks, under a tall shako and its icicle plume.
	var hc := Vector2(f * (lean + 1.0), -h * 0.72 + bob)
	cel_circle(tb, hc, 5.5 * sm, WAX, 1.8)
	tb.circle(hc + Vector2(f * 2.5, 2.0) * sm, 1.4 * sm, pc(CHEEK), 8)
	tb.circle(hc + Vector2(f * 3.5, -0.5) * sm, 1.1 * sm, pc(Color("2a2030")), 8)
	cel_poly(tb, PackedVector2Array([hc + Vector2(-5.0, -3.0) * sm, hc + Vector2(5.0, -3.0) * sm, hc + Vector2(4.0, -12.0) * sm,
			hc + Vector2(-4.0, -12.0) * sm]), SHAKO, 1.8)
	tb.rect(Rect2(hc + Vector2(-5.0, -4.5) * sm, Vector2(10.0, 2.0) * sm), pc(BRASS))
	cel_poly(tb, PackedVector2Array([hc + Vector2(-1.5, -12.0) * sm, hc + Vector2(1.5, -12.0) * sm, hc + Vector2(0.0, -18.0) * sm]), ICE, 1.2)
	tb.flush(self)
