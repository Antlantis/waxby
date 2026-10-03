extends "res://scripts/elites.gd"
## The Snuffer, the Hollow Wick: a tall hooded Wick whose flame went out,
## carrying a great candle-snuffer on a pole. He is HOLLOW: blows pass
## through him (a whiff, a "0") unless his middle is within 110 px of a lit
## brazier (world.lights_tagged("brazier")) or a Taperwitch's Beacon
## ("beacon"), or for 1.0 s after he leaves one; while his pole is stuck in
## the floor he is solid anyway. His touch hurts either way. In phase 3,
## "Lights Out", every brazier goes out for good and he is solid only
## inside Wick's own light (world.hero_light_radius()): stay healthy.
##
## Phases 100-60% / 60-25% / under 25% (a blow never crosses a line: it
## stops there and he screams into the next). Moves (spec §8.4):
##   Snuffer Slam   all: tracks over Wick 1.2 s, raises the pole 0.7/0.6/0.55 s
##                  (the cone's rim glows, a ring closes on the floor), 56 px
##                  zone 65 px ahead: 36 and a douse; the pole sticks
##                  1.4/1.1/0.9 s (+0.4 with Tollbreaker): solid
##   Snuff the Light 1-2: turns to the lit brazier nearest Wick ("shhh", 1.0 s),
##                  glides there at 180 px/s and caps it after 0.6 s; he is in
##                  its light the whole way, and a blow interrupts him
##   Smoke Tide     2+: sinks 0.8 s, a 2-tile smoke wave sweeps the floor at
##                  220 px/s (32); jump it or stand on a ledge; he rises at the far end
##   Drip Choir     2+: 6 ceiling drips swell 0.8 s and fall (douse), 4 clear
##                  tiles between; they swell in view (at the roof, or the
##                  view's top), each with a lane line and a ring on the floor
##   Gutter Call    at 60% and 45%: 2 Gutterwings; killing one relights the
##                  nearest dark brazier
##   Lunge          3: a 0.5 s draw-back with a glowing trail, then 300 px/s at
##                  head height (34): jump it
##   Mercy          3: one wax stub drops if Wick is under 25% (once)
## Witching: he slams twice in a row. Retry: reset_fight() puts the braziers
## back as the fight began (floor ones lit, ledge ones dark), reopens the
## door (boss_arena.gd) and puts him back to sleep.
## The rush, "Hollow Again" (spec §5.6; BR): only a mode's configure({rush:
## true}) turns any of this on, so the story's fight is v2's to the tick.
##   Smother      P1+, every fourth move: he rises over Wick (0.6 s) and a
##                cone-shadow ring follows Wick at 60 px/s for 1.6 s on what
##                he stands on (the floor, or a ledge he's up on), its sweep
##                filling like a clock hand; 0.5 s before it locks it flashes
##                and warms; then it locks 0.45 s (floor 0.40) while the cone
##                lowers, and drops: 40 and a douse in the 64 px column over
##                the ring (a jump doesn't clear it). The cone sticks 1.0 s
##                (+Tollbreaker) where it fell and he is solid while it's
##                stuck (the Slam's rule, Lights Out too).
##   Gutter Call  3 Gutterwings.
##   Lights Out   the Lunge comes twice (a second 0.5 s draw-back at Wick).
## His life and the Warded and Echoing Wax mods are boss_mods.gd's.
## Frames: art/enemies/snuffer_<frame>.svg, a 384 frame, feet (192,368).
## The tells drawn in the glow layer go where the frames put things: W6b's
## points_snuffer.json (the bell's mouth, the face, the lunge's cone tip; a
## frame point p is (p - (192,368)) / 2 px from his feet), and the eyes
## below. Without art they fall back to the stand-in drawing's places.

signal woke

const Arena := preload("res://scripts/boss_arena.gd")
const BossMods := preload("res://scripts/boss_mods.gd")
const FRAME_FEET := Vector2(192, 368)
const PHASES := [0.60, 0.25]
const CALLS := [0.60, 0.45]
const SOLID_R := 110.0
const AFTERGLOW := 1.0
const DRIFT := 140.0
const TRACK := 1.2
# The slam's tell by phase. Standing on the ring, a thumb needs about 0.25 s
# to run clear of it after reacting; 0.55/0.45 left a 0.3 s reaction short.
const RAISE := [0.7, 0.6, 0.55]
const STUCK := [1.4, 1.1, 0.9]
const REACH := 65.0             # the pole lands this far in front (the art's slam_centre)
const SLAM_W := 56.0
const SNUFF_TELL := 1.0
const SNUFF_GLIDE := 180.0
const SNUFF_CAP := 0.6
const TIDE_SINK := 0.8
const TIDE_SPEED := 220.0
const TIDE_H := 64.0
const CHOIR_SWELL := 0.8
const LUNGE_DRAW := 0.5
const LUNGE_SPEED := 300.0
const LUNGE_RUN := 420.0
const HOVER := 6.0
const BODY := Vector2(60, 110)
const LIFT_SPEED := 160.0       # px/s he floats up to a ledge brazier and back down
const CAP_OVER := 12.0          # capping: the bell's mouth this far over the flame
const POINTS_PATH := "res://art/enemies/points_snuffer.json"
# The rush (configure only).
const SMOTHER_EVERY := 4        # every fourth move
const SMOTHER_RISE := 0.6       # up over Wick
const SMOTHER_TRACK := 1.6      # the ring follows him this long...
const SMOTHER_TRACK_FLOOR := 1.2
const SMOTHER_FOLLOW := 60.0    # ...at this many px/s
const SMOTHER_LOCK := 0.45      # then holds still while the cone comes down
const SMOTHER_LOCK_FLOOR := 0.40
const SMOTHER_W := 64.0         # the cone's mouth on the floor
const SMOTHER_LIFT := 96.0      # how high he hangs over Wick
const SMOTHER_STUCK := 1.0      # the cone stuck in the floor: solid
const SMOTHER_STATES := ["smother_rise", "smother_track", "smother_lock"]
const SMOTHER_WARN := 0.5       # the ring flashes and warms this long before it locks
const SMOTHER_COLUMN := 128.0   # the cone comes down through this much air over the ring
const SMOTHER_ROOM := 6.0       # his hood keeps this far under the ceiling as he hangs
# His eyes per frame (frame units): the pinprick irises of the cone head,
# placed and turned as boss2.py places the head (the face point plus the
# eyes' offsets from it, turned with the head).
const EYES := {
	"snuffer_idle": [Vector2(200.9, 200.8), Vector2(228.8, 198.7)],
	"snuffer_raise": [Vector2(181.8, 200.2), Vector2(209.2, 194.2)],
	"snuffer_slam": [Vector2(235.3, 211.4), Vector2(262.9, 216.1)],
	"snuffer_stuck": [Vector2(264.0, 251.2), Vector2(289.2, 263.4)],
	"snuffer_glide": [Vector2(241.9, 196.2), Vector2(269.7, 199.9)],
	"snuffer_snuff": [Vector2(215.2, 201.3), Vector2(243.2, 201.2)],
	"snuffer_lunge": [Vector2(233.5, 266.5), Vector2(245.9, 291.6)],
	"snuffer_curdled": [Vector2(191.1, 194.3), Vector2(218.6, 189.2)],
	"snuffer_die": [Vector2(157.4, 196.2), Vector2(182.1, 182.9)],
}
# How far each frame's body leans forward of his feet (px), so blows find
# the drawn body (the head leads when he glides, slams or snuffs).
const LEAN := {"snuffer_glide": 12.0, "snuffer_slam": 10.0, "snuffer_snuff": 6.0, "snuffer_raise": -4.0}
static var _points := {}

var state := "sleep"
var timer := 0.0
var phase := 1
var arena_left := 0.0
var arena_right := 0.0
var door: Array[Vector2i] = []
var home := Vector2.ZERO
var floor_y := 0.0
var boss_id := "snuffer"
var boss_name := "The Snuffer"
var boss_title := "The Hollow Wick"
var solid_t := 0.0              # afterglow: seconds he stays solid after leaving light
var _was_solid := false
var _curdle := 0.0
var _move_n := 0
var _target := {}               # the brazier he means to cap
var _slam_x := 0.0
var _calls_done: Array = []
var _call_pending := false
var _wings: Array = []
var _mercy := false
var _whiff_id := -1
var _whiffs: Array = []         # {p, t}: ghost sparks where blows passed through
var _lunge_dir := 1
var _lunge_left := 0.0
var _double := false
var _tide: Dictionary = {}
var _tide_to := 0.0
var _lift := 0.0                # px above his hover (floating up to cap a ledge brazier)
var _lift_to := 0.0
# The rush's state (all idle in the story).
var rush := false               # set by configure({rush: true}) (BossMods.configure)
var _bm: RefCounted = null      # boss_mods.gd's runtime (Warded, Echoing), or null
var _ring_x := 0.0              # the Smother's cone-shadow ring...
var _ring_y := 0.0              # ...on what Wick stands on (the floor, a ledge)
var _stand_y := 0.0             # Wick's feet when last on the ground
var _stuck_y := 0.0             # the surface the pole or cone stuck on (the rush; the story's is floor_y)
var _second_lunge := false      # Lights Out: the second Lunge of the pair is on
var smothers := 0               # Smothers dropped (tests)
var barks_skipped := 0          # story lines the rush left out (tests)


func _init() -> void:
	kind = "boss"
	xp_kind = "snuffer"
	size = BODY
	base_hp = 300.0
	base_dmg = 26.0
	embers = 50
	item_chance = 0.0
	relic_chance = 0.0
	stompable = true
	ordinary = false
	anchor = FRAME_FEET
	flier = true


func _ready() -> void:
	super()
	load_frames(["snuffer_idle", "snuffer_raise", "snuffer_slam", "snuffer_stuck", "snuffer_glide",
			"snuffer_snuff", "snuffer_lunge", "snuffer_curdled", "snuffer_die"])
	show_frame("snuffer_idle")
	home = position
	floor_y = position.y
	var a := Arena.find(level, position)
	arena_left = a["left"]
	arena_right = a["right"]
	door.assign(a["door"])


# ---------------------------------------------------------------- the boss interface

func configure(opts: Dictionary) -> void:
	## A mode's boss (the Waxworks, a Descent echo depth), before _ready:
	## {rush, mods, hp_mult, area, echo}. rush turns on the rush's moves;
	## its life and mods are BossMods'. (area is the World's area_abs already.)
	BossMods.configure(self, opts)
	_bm = BossMods.of(self)


func boss_info() -> Dictionary:
	var info := {"id": boss_id, "name": boss_name, "title": boss_title, "frac": hp / maxf(max_hp, 1.0),
			"phases": PHASES, "awake": state != "sleep" and alive}
	if rush:
		info["segments"] = PHASES   # the rush's three-part bar (the story's stays v2's)
	return info


func is_open() -> bool:
	## A window: the pole (or the Smother's cone) stuck, or the recoil from a
	## blow that stopped Snuff the Light (v2's Tollbreaker rule).
	return state in ["stuck", "hurt", "recoil"]


func reset_fight(_keep_phase := false) -> void:
	## Wick was snuffed: asleep again at full life, braziers relit, door open.
	if not alive:
		return
	Arena.unseal(world, level, door)
	hp = max_hp
	phase = 1
	state = "sleep"
	timer = 0.0
	position = home
	velocity = Vector2.ZERO
	solid_t = 0.0
	_move_n = 0
	_calls_done.clear()
	_call_pending = false
	_mercy = false
	_double = false
	_tide = {}
	_target = {}
	_lift = 0.0
	_lift_to = 0.0
	fade = 1.0
	_second_lunge = false
	if _bm:
		_bm.reset()
	for w in _wings:
		if is_instance_valid(w):
			w.alive = false
			w.gone = true
	_wings.clear()
	var f = _features()
	if f:
		f.reset_braziers()
	if world:
		world.hazards.clear()


func touch_damage() -> bool:
	## His touch hurts, hollow or not (not while asleep, screaming or smoke).
	## While the pole is stuck he's hunched over it: strike, don't flinch.
	## Reeling from a blow (recoil) he's no threat either: a hit that stops
	## Snuff the Light mustn't cost the hit back.
	## (The rush's Smother: all his menace is in the cone. He glides fast to
	## hang over Wick, and over a ledge he hangs at Wick's height beside him.)
	return not (state in ["sleep", "dead", "roar", "lights_out", "under", "sink", "rise", "stuck", "recoil"] or state in SMOTHER_STATES)


func dmg(what := "touch") -> float:
	# The slam is 36 (Tollgrave's wave): at 2-4's area on Dusk an on-level
	# (L13) Candleknight loses 28-32% of his life to it, a Taperwitch 37-43%.
	var base = {"touch": 26.0, "slam": 36.0, "lunge": 34.0, "tide": 32.0, "drip": 16.0, "smother": 40.0}.get(what, base_dmg)
	if what == "touch" and state == "lunge":
		base = 34.0
	return float(base) * dmg_mult


func _features() -> Object:
	if world and world.features and world.features.has_method("reset_braziers"):
		return world.features
	return null


static func points() -> Dictionary:
	## W6b's points_snuffer.json (read once): per frame, the face ("head"),
	## the bell's mouth, the slam's centre and the lunge's cone tip.
	if _points.is_empty():
		var text := FileAccess.get_file_as_string(POINTS_PATH) if FileAccess.file_exists(POINTS_PATH) else ""
		var d = JSON.parse_string(text) if text != "" else null
		_points = d if d is Dictionary else {"_missing": true}
	return _points


func art_point(frame: String, key: String) -> Vector2:
	## A point of the art in the world (on this frame as drawn now), or INF
	## without art or without that point.
	if frames.is_empty():
		return Vector2.INF
	var f = points().get(frame, {})
	if not (f is Dictionary) or not f.has(key):
		return Vector2.INF
	var q: Array = f[key]
	return frame_point(Vector2(float(q[0]), float(q[1])))


func window_bonus() -> float:
	## Tollbreaker: his openings (stuck, staggered) last this much longer.
	if world == null or world.player == null or not (world.player.stats is Dictionary):
		return 0.0
	var flags = world.player.stats.get("flags", {})
	return float(flags.get("tollbreaker_window", 0.0)) if flags is Dictionary else 0.0


# ---------------------------------------------------------------- hollow or solid

func body_rect() -> Rect2:
	## Where he is, solid or not (his touch uses this): the drawn body.
	match state:
		"stuck":
			# Hunched forward over the stuck pole, his head out in front.
			var fx := position.x + facing * 52.0
			var bx := position.x - facing * 28.0
			return Rect2(minf(fx, bx), position.y - 84.0, 80.0, 84.0)
		"lunge", "lunge_draw":
			# Laid out flat at head height (W6b's _lunge_box).
			return Rect2(position.x - 50.0, floor_y - 80.0, 100.0, 52.0)
		"under":
			return NOWHERE
	var lean: float = float(LEAN.get(frame_name, 0.0)) * facing if not frames.is_empty() else 0.0
	return Rect2(position.x + lean - BODY.x * 0.5, position.y - BODY.y, BODY.x, BODY.y)


func rect() -> Rect2:
	## Blows only find him while he is solid.
	return body_rect() if solid() else NOWHERE


func hurt_rect() -> Rect2:
	if state in ["sleep", "under"]:
		return NOWHERE
	return body_rect().grow(-6.0)


func center() -> Vector2:
	var r := body_rect()
	if r == NOWHERE:
		return position + Vector2(0, -BODY.y * 0.5)
	return r.get_center()


func lit_here() -> bool:
	## Is he in light right now (by this phase's rule)?
	if world == null:
		return false
	var c := center()
	if phase >= 3:
		var pl: Node2D = world.player
		return pl != null and pl.alive and c.distance_to(pl.center() + Vector2(0, -8)) < world.hero_light_radius()
	for l in world.lights_tagged("brazier") + world.lights_tagged("beacon"):
		if c.distance_to(l["p"]) < SOLID_R:
			return true
	return false


func solid() -> bool:
	# Screaming into a new phase or calling the moths, he goes to smoke.
	if not alive or state in ["sleep", "under", "sink", "roar", "call", "lights_out"]:
		return false
	return state == "stuck" or solid_t > 0.0


func _update_solid(dt: float) -> void:
	if lit_here() and phase < 3:
		solid_t = AFTERGLOW
	elif phase >= 3:
		solid_t = 0.05 if lit_here() else 0.0
	else:
		solid_t = maxf(solid_t - dt, 0.0)
	var now := solid()
	if now and not _was_solid:
		# Curdling: a white flash and a hiss.
		flash = 1.0
		_curdle = 0.25
		sfx("curdle", "lava", 1.4)
		if world and world.glow:
			world.glow.burst(center(), 14, Color("f4f0ff"), 140.0, 0.35, 0.0, 2.2)
	_was_solid = now
	tint.a = 1.0 if now else 0.62


func hit(h: Dictionary) -> bool:
	if not alive or state == "sleep":
		return false
	if not solid():
		_whiff(Vector2(float(h.get("from_x", position.x)), center().y))
		return false
	var how: String = h.get("how", "slash")
	if how == "shock" or how == "bump":
		return false
	if _bm and _bm.blocks(h):
		return false   # Warded Wax: a mote took it (only a blow that would land)
	var amount: float = float(h.get("amount", 0.0))
	if how == "stomp" and state == "stuck":
		amount *= 2.0
	var floor_hp := 0.0
	if phase <= PHASES.size():
		floor_hp = max_hp * PHASES[phase - 1]
	var clamped := false
	if hp - amount <= floor_hp and phase <= PHASES.size():
		amount = hp - floor_hp
		clamped = true
	hp = maxf(hp - amount, 0.0)
	last_damage = amount
	flash = 1.0
	hp_bar = 2.5
	if world:
		world._sfx("boss_hit")
		world.shake = maxf(world.shake, 5.0)
	if hp <= 0.0:
		_kill(h)
		state = "dead"
		timer = 0.0
		if world:
			world._sfx("boss_die")
		return true
	# Calls come at 60% and 45%.
	var frac := hp / maxf(max_hp, 1.0)
	for c in CALLS:
		if frac <= c + 0.001 and not _calls_done.has(c):
			_calls_done.append(c)
			_call_pending = true
	if clamped:
		phase += 1
		_enter_phase()
		return true
	# A blow stops Snuff the Light (a stagger: Tollbreaker holds it open).
	if state in ["snuff_tell", "glide", "cap"]:
		state = "recoil"
		timer = 0.5 + window_bonus()
		velocity = Vector2.ZERO
		_lift_to = 0.0
	return true


func _whiff(p: Vector2) -> void:
	_whiffs.append({"p": p, "t": 0.0})
	if _whiffs.size() > 6:
		_whiffs.pop_front()
	if world:
		world.number(p + Vector2(0, -20), 0.0, "chip", 0)
	sfx("whoosh", "slash", 0.7)


func _enter_phase() -> void:
	velocity = Vector2.ZERO
	fade = 1.0
	_tide = {}
	_move_n = -1
	if world:
		world.shake = 8.0
		world.boss_phase(self, phase)
	if phase >= 3:
		state = "lights_out"
		timer = 1.3
		sfx("snuffer_scream", "boss_roar", 0.8)
	else:
		state = "roar"
		timer = 1.2
		sfx("snuffer_scream", "boss_roar", 1.1)


# ---------------------------------------------------------------- the fight

func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_curdle = maxf(_curdle - dt, 0.0)
	for w in _whiffs:
		w["t"] += dt
	_whiffs = _whiffs.filter(func(w): return w["t"] < 0.5)
	_update_solid(dt)
	_check_passes(player)
	if not (state in ["snuff_tell", "glide", "cap"] or state in SMOTHER_STATES):
		_lift_to = 0.0
	_lift = move_toward(_lift, _lift_to, LIFT_SPEED * dt)
	if rush:
		if state in SMOTHER_STATES:
			_lift = move_toward(_lift, _lift_to, LIFT_SPEED * dt)   # (twice as quick: up over a ledge in the rise)
		elif state == "stuck":
			_lift = maxf(floor_y - _stuck_y, 0.0)   # stuck on a ledge he's up there; he floats down after
	var dx: float = player.position.x - position.x
	var raise_t: float = tell(RAISE[clampi(phase - 1, 0, 2)])
	match state:
		"sleep":
			_hover(dt)
			show_frame("snuffer_idle")
			if player.alive and player.position.x > arena_left + 48.0 and absf(dx) < 560.0:
				state = "roar"
				timer = 1.3
				Arena.seal(world, level, door)
				woke.emit()
				sfx("snuffer_scream", "boss_roar", 1.2)
				if world:
					world.shake = 5.0
		"roar":
			_hover(dt)
			show_frame("snuffer_curdled")
			if timer <= 0.0:
				_next(player)
		"lights_out":
			_hover(dt)
			show_frame("snuffer_curdled")
			if timer <= 0.9 and timer + dt > 0.9:
				var f = _features()
				if f:
					f.lights_out()
				if world:
					world.shake = 9.0
					# Taper's warning: only his light is left. (world.boss_phase
					# barks snuffer_angry at every phase; the HUD drops repeats.)
					_story_bark("snuffer_dark")
			if timer <= 0.0:
				_next(player)
		"drift":
			_face(dx)
			var want := player.position.x - signf(dx) * 150.0
			_glide_to(want, spd(DRIFT) * 0.7, dt)
			show_frame("snuffer_glide" if absf(want - position.x) > 20.0 else "snuffer_idle")
			if timer <= 0.0:
				_next(player)
		"track":
			_face(dx)
			_glide_to(player.position.x - facing * REACH, spd(DRIFT), dt)
			show_frame("snuffer_glide")
			if timer <= 0.0:
				state = "raise"
				timer = raise_t
				_slam_x = clampf(position.x + facing * REACH, arena_left + 20.0, arena_right - 20.0)
				sfx("arrow_draw", "", 0.5)
		"raise":
			_hover(dt)
			show_frame("snuffer_raise")
			if timer <= 0.0:
				_slam(player)
		"stuck":
			position.y = _stuck_floor()
			fade = 1.0
			show_frame("snuffer_stuck")
			if timer <= 0.0:
				state = "drift"
				timer = cd(0.5)
		"snuff_tell":
			_hover(dt)
			show_frame("snuffer_snuff")
			if _target.is_empty() or not _target["lit"]:
				_next(player)
			else:
				_face(_target["pos"].x - position.x)
				if timer <= 0.0:
					state = "glide"
		"glide":
			if _target.is_empty() or not _target["lit"]:
				_next(player)
			else:
				# To where the snuff pose holds his bell over its flame (a ledge
				# brazier: he floats up to it). With a wall in the way he comes
				# at it from its other side; he's smoke, he can pass through.
				var lo := arena_left + BODY.x * 0.5
				var hi := arena_right - BODY.x * 0.5
				var tx: float = _target["pos"].x - facing * _cap_reach()
				if tx < lo or tx > hi:
					facing = -facing
					tx = _target["pos"].x - facing * _cap_reach()
				tx = clampf(tx, lo, hi)
				_lift_to = _cap_lift()
				_glide_to(tx, spd(SNUFF_GLIDE), dt)
				show_frame("snuffer_glide")
				# (timer counts on below zero here: a glide never outlasts 4 s)
				if (absf(tx - position.x) < 6.0 and absf(_lift - _lift_to) < 4.0) or timer < -4.0:
					state = "cap"
					timer = SNUFF_CAP
		"cap":
			_hover(dt)
			show_frame("snuffer_snuff")
			if timer <= 0.0:
				var f = _features()
				if f and not _target.is_empty():
					f.snuff_brazier(_target)
				_target = {}
				state = "drift"
				timer = cd(0.6)
		"recoil":
			_hover(dt)
			show_frame("snuffer_curdled")
			if timer <= 0.0:
				_target = {}
				state = "drift"
				timer = cd(0.4)
		"sink":
			show_frame("snuffer_idle")
			var k := 1.0 - clampf(timer / maxf(tell(TIDE_SINK), 0.01), 0.0, 1.0)
			position.y = floor_y + k * 40.0
			# He sinks into smoke, not into the stone: he fades as he goes.
			fade = 1.0 - k
			if timer <= 0.0:
				_start_tide()
		"under":
			fade = 0.0
			if _tide.is_empty() or _tide.get("life", 0.0) <= 0.0 or timer <= 0.0:
				state = "rise"
				timer = 0.4
				position.x = _tide_to
				_face(dx)
		"rise":
			var k2 := clampf(timer / 0.4, 0.0, 1.0)
			position.y = floor_y + k2 * 40.0
			fade = 1.0 - k2
			show_frame("snuffer_idle")
			if timer <= 0.0:
				position.y = floor_y
				fade = 1.0
				state = "drift"
				timer = cd(0.8)
		"choir":
			_hover(dt)
			show_frame("snuffer_raise")
			if timer <= 0.0:
				state = "drift"
				timer = cd(0.9)
		"call":
			_hover(dt)
			show_frame("snuffer_curdled")
			if timer <= 0.0:
				_summon()
				state = "drift"
				timer = cd(1.0)
		"lunge_draw":
			show_frame("snuffer_lunge")
			position.x -= _lunge_dir * 60.0 * dt
			position.y = floor_y - HOVER
			if timer <= 0.0:
				state = "lunge"
				_lunge_left = LUNGE_RUN
				sfx("rush", "boss_slam", 0.7)
		"lunge":
			show_frame("snuffer_lunge")
			var step := LUNGE_SPEED * dt
			position.x += _lunge_dir * step
			_lunge_left -= step
			var at_wall := (_lunge_dir < 0 and position.x <= arena_left + 50.0) or (_lunge_dir > 0 and position.x >= arena_right - 50.0)
			if _bm:
				_bm.follow("lunge", body_rect(), dmg("lunge"))
			if _lunge_left <= 0.0 or at_wall:
				if _bm:
					_bm.end("lunge")
				if rush and not _second_lunge:
					# Lights Out, "Hollow Again": straight into a second Lunge at him.
					_second_lunge = true
					_lunge_dir = 1 if player.position.x > position.x else -1
					facing = _lunge_dir
					state = "lunge_draw"
					timer = tell(LUNGE_DRAW)
				else:
					state = "drift"
					timer = cd(0.7)
		# ---- the rush's Smother (never reached in the story)
		"smother_rise":
			# Up over Wick, the cone held high.
			_track_ring(player)
			_lift_to = _smother_lift(1.0)
			_over_ring(dt, spd(SNUFF_GLIDE) * 2.0)
			show_frame("snuffer_snuff")
			if timer <= 0.0:
				state = "smother_track"
				timer = tell(SMOTHER_TRACK, SMOTHER_TRACK_FLOOR)
		"smother_track":
			# The ring follows him along the floor, slower than he can run.
			_ring_x = move_toward(_ring_x, _ring_clamp(player.position.x), SMOTHER_FOLLOW * dt)
			_track_ring(player)
			_lift_to = _smother_lift(1.0)
			_over_ring(dt, spd(SNUFF_GLIDE) * 2.0)
			show_frame("snuffer_snuff")
			if timer <= SMOTHER_WARN and timer + dt > SMOTHER_WARN:
				# The warning: it's about to lock (the whisper builds to the drop).
				tell_sfx("snuffer_whisper", timer + smother_lock_time())
			if timer <= 0.0:
				state = "smother_lock"
				timer = smother_lock_time()
		"smother_lock":
			# The ring holds; the great cone comes down slowly.
			_lift_to = _smother_lift(0.55)
			_over_ring(dt, spd(SNUFF_GLIDE) * 2.0)
			show_frame("snuffer_snuff")
			if timer <= 0.0:
				_smother_drop(player)
	position.x = clampf(position.x, arena_left + BODY.x * 0.5, arena_right - BODY.x * 0.5)
	# Mercy: one wax stub when Wick is nearly out (Lights Out only).
	if phase >= 3 and not _mercy and player.alive and player.life_frac() < 0.25 and world:
		_mercy = true
		var p: Dictionary = world._add_pickup("wax", Vector2(player.position.x, _ceiling_at(player.position.x) + 18.0))
		p["loose"] = true
		p["vel"] = Vector2.ZERO


func _hover(_dt: float) -> void:
	position.y = floor_y - HOVER - _lift + sin(t * 2.2) * 3.0


func _cap_reach() -> float:
	## How far in front of him the snuff pose holds the bell's mouth.
	var f = points().get("snuffer_snuff", {})
	if frames.is_empty() or not (f is Dictionary) or not f.has("bell_mouth"):
		return 26.0
	return (float(f["bell_mouth"][0]) - FRAME_FEET.x) * 0.5


func _cap_lift() -> float:
	## How high he floats so the bell's mouth sits just over the target's
	## flame (0 for a floor brazier; a ledge one lifts him to it).
	if _target.is_empty():
		return 0.0
	var f = points().get("snuffer_snuff", {})
	var up := 40.0
	if f is Dictionary and f.has("bell_mouth"):
		up = (FRAME_FEET.y - float(f["bell_mouth"][1])) * 0.5
	var feet: float = (_target["flame"] as Vector2).y - CAP_OVER + up
	return maxf(0.0, (floor_y - HOVER) - feet)


func _face(dx: float) -> void:
	if absf(dx) > 6.0:
		facing = 1 if dx > 0.0 else -1


func _glide_to(x: float, speed: float, dt: float) -> void:
	position.x = move_toward(position.x, x, speed * dt)
	_hover(dt)


func _next(player: Node2D) -> void:
	## The next move, by phase.
	if _call_pending and phase < 3:
		_call_pending = false
		state = "call"
		timer = tell(0.9)
		sfx("wisp_call", "bat", 0.6)
		return
	_move_n += 1
	_double = false
	fade = 1.0
	if rush and _move_n % SMOTHER_EVERY == SMOTHER_EVERY - 1:
		_start_smother(player)
		return
	var f = _features()
	var lit: Array = f.lit_braziers() if f else []
	var pick := "track"
	match phase:
		1:
			pick = "snuff" if _move_n % 2 == 0 and not lit.is_empty() else "track"
		2:
			var loop := ["tide", "track", "choir", "track", "snuff", "track"]
			pick = loop[_move_n % loop.size()]
			if pick == "snuff" and lit.is_empty():
				pick = "choir"
		_:
			pick = "lunge" if _move_n % 2 == 1 else "track"
	match pick:
		"track":
			state = "track"
			timer = cd(TRACK) if phase < 3 else cd(TRACK * 0.8)
		"snuff":
			# The lit brazier nearest Wick: the one he'd most like to have.
			var best: Dictionary = {}
			var bd := INF
			for l in lit:
				var d: float = (l["pos"] as Vector2).distance_to(player.position)
				if d < bd:
					bd = d
					best = l
			_target = best
			state = "snuff_tell"
			timer = tell(SNUFF_TELL)
			sfx("snuffer_whisper", "", 1.0)
		"tide":
			state = "sink"
			timer = tell(TIDE_SINK)
		"choir":
			state = "choir"
			timer = CHOIR_SWELL
			_choir()
		"lunge":
			_lunge_dir = 1 if player.position.x > position.x else -1
			facing = _lunge_dir
			_second_lunge = false
			state = "lunge_draw"
			timer = tell(LUNGE_DRAW)


func _slam(player: Node2D) -> void:
	var zone := Rect2(_slam_x - SLAM_W * 0.5, floor_y - 64.0, SLAM_W, 64.0)
	if _bm:
		_bm.strike(zone, dmg("slam"))
	if world:
		if player.alive and zone.intersects(player.rect()):
			if world.hurt_player(dmg("slam"), _slam_x, "hit", self):
				world.douse_player()
		world.shake = maxf(world.shake, 7.0)
		world.dust_at(Vector2(_slam_x, floor_y))
		world._haptic(40)
		if world.glow:
			world.glow.burst(Vector2(_slam_x, floor_y - 4.0), 16, Color("c8c0d8"), 170.0, 0.4, 400.0, 2.4)
	sfx("snuffer_slam", "boss_slam", 1.0)
	_stuck_y = floor_y
	if world and world.diff == "witching" and not _double:
		# Witching Hour: straight into a second slam.
		_double = true
		state = "track"
		timer = 0.35
		return
	state = "stuck"
	timer = STUCK[clampi(phase - 1, 0, 2)] + window_bonus()
	position.y = floor_y


func _start_tide() -> void:
	## A wall of smoke from his end of the room to the other.
	var from_left := position.x < (arena_left + arena_right) * 0.5
	var x0 := arena_left + 2.0 if from_left else arena_right - 46.0
	var dir := 1.0 if from_left else -1.0
	var life := (arena_right - arena_left - 44.0) / TIDE_SPEED
	_tide_to = arena_right - 70.0 if from_left else arena_left + 70.0
	state = "under"
	timer = life + 0.2
	if world:
		_tide = world.add_hazard({"kind": "smoke", "motion": "tide", "rect": Rect2(x0, floor_y - TIDE_H, 44.0, TIDE_H),
				"vel": Vector2(dir * TIDE_SPEED, 0.0), "life": life, "dmg": dmg("tide"), "owner": "enemy"})
		if _bm:
			_bm.watch(_tide)
	sfx("snuffer_whisper", "", 0.6)


func _choir() -> void:
	## Six drips in a row with 4-tile gaps between, from a random start. They
	## swell where Wick can see them: at the roof, or at the top of the view
	## if the roof is higher than that; each marks its lane on the floor.
	if world == null:
		return
	var cols := int((arena_right - arena_left) / TILE)
	var off := randi_range(0, 4)
	var n := 0
	var c := off
	var view_top: float = world.view_rect().position.y
	while c < cols and n < 6:
		var x := arena_left + (c + 0.5) * TILE
		var top := maxf(_ceiling_at(x) + 2.0, view_top + 6.0)
		var hd: Dictionary = world.add_hazard({"kind": "drip", "motion": "fall", "rect": Rect2(x - 6.0, top, 12.0, 16.0),
				"vel": Vector2.ZERO, "g": 1400.0, "delay": CHOIR_SWELL, "shadow": true, "douse": true,
				"life": 3.0, "dmg": dmg("drip"), "owner": "enemy", "choir": true, "top": top})
		if _bm:
			_bm.watch(hd)
		n += 1
		c += 5
	sfx("drip", "", 0.8)


func _draw_choir(glow: Node2D) -> void:
	## The Drip Choir's tell: each drip swells at the roof while a lane of
	## light runs down to a ring closing on the floor where it will land.
	## The ring stays lit until the drip has fallen.
	for h in world.hazards:
		if not h.get("choir", false) or float(h.get("life", 0.0)) <= 0.0:
			continue
		var r: Rect2 = h["rect"]
		var x := r.get_center().x
		var delay := float(h.get("delay", 0.0))
		var s := 1.0 - clampf(delay / CHOIR_SWELL, 0.0, 1.0)
		var top := float(h.get("top", r.position.y))
		var cold := Color(0.78, 0.92, 1.0)
		if delay > 0.0:
			# The drop swelling on the roof, with a glint that sharpens.
			var d := Vector2(x, top + 4.0 + 5.0 * s)
			var rr := 2.5 + 3.5 * s
			glow.draw_circle(d, rr + 5.0, Color(cold, 0.18 + 0.2 * s))
			glow.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -rr * 1.7), d + Vector2(rr, 0), d + Vector2(0, rr),
					d + Vector2(-rr, 0)]), Color(cold, 0.75 + 0.25 * s))
			var g := 3.0 + 5.0 * s
			glow.draw_line(d + Vector2(-g, -2), d + Vector2(g, -2), Color(1, 1, 1, 0.5 + 0.5 * s), 1.2)
			glow.draw_line(d + Vector2(0, -2 - g), d + Vector2(0, -2 + g), Color(1, 1, 1, 0.5 + 0.5 * s), 1.2)
			# The lane: a faint fall line from the drop to the floor.
			var y := d.y + rr + 4.0
			while y < floor_y - 6.0:
				glow.draw_line(Vector2(x, y), Vector2(x, minf(y + 7.0, floor_y - 6.0)), Color(cold, 0.10 + 0.22 * s), 2.0)
				y += 14.0
		# On the floor: a ring closing in, and a lit splash mark inside it.
		var k := s if delay > 0.0 else 1.0
		var rx := 9.0 + (1.0 - k) * 22.0
		var ring := ellipse(Vector2(x, floor_y - 1.0), rx, 3.0 + (1.0 - k) * 2.0, 20)
		ring.append(ring[0])
		glow.draw_polyline(ring, Color(cold, 0.35 + 0.55 * k), 2.0)
		glow.draw_colored_polygon(ellipse(Vector2(x, floor_y - 1.0), 9.0 * k + 1.0, 2.5 * k + 0.5, 14), Color(cold, 0.25 + 0.35 * k))


func _ceiling_at(x: float) -> float:
	var ty := floori((floor_y - 8.0) / TILE)
	var tx := floori(x / TILE)
	while ty > 0 and not LevelData.is_solid(level.tile(tx, ty - 1)):
		ty -= 1
	return ty * TILE


func _summon() -> void:
	## Gutter Call: two moths (three in the rush); killing one relights the
	## nearest dark brazier.
	if world == null:
		return
	if world.glow:
		world.glow.burst(center(), 24, Color("b890ff"), 200.0, 0.6, 0.0, 2.6)
	for side in ([-1, 0, 1] if rush else [-1, 1]):
		var w: Node2D = world.spawn_enemy("gutterwing", center() + Vector2(side * 44.0, -30.0 - (40.0 if side == 0 else 0.0)), {})
		if w:
			_wings.append(w)
			w.died.connect(_on_wing_died)


func _on_wing_died(e: Node2D, _how: String) -> void:
	var f = _features()
	if f and alive and not f.braziers_locked:
		f.relight_nearest(e.center())


func _check_passes(player: Node2D) -> void:
	## Blows passing through him while hollow: a whiff and a ghost spark
	## (the World never sees them, since rect() is nowhere).
	if solid() or state in ["sleep", "under"] or world == null:
		return
	var body := body_rect()
	if player.attack_time >= 0.0 and player.attack_time <= player.ATTACK_ACTIVE and player.attack_id != _whiff_id:
		if (player.attack_rect() as Rect2).intersects(body):
			_whiff_id = player.attack_id
			_whiff(Vector2(clampf(player.position.x + player.facing * 20.0, body.position.x, body.end.x), player.center().y))
	for s in world.shots:
		if s["owner"] == "player" and not s.get("whiffed", false) and body.has_point(s["pos"]):
			s["whiffed"] = true
			_whiffs.append({"p": s["pos"], "t": 0.0})


func _kill(h: Dictionary) -> void:
	super(h)
	if _bm:
		_bm.clear()
	for w in _wings:
		if is_instance_valid(w) and w.alive:
			w.alive = false
			w.gone = true
	_wings.clear()


func _dying(dt: float) -> void:
	## He comes apart into smoke; the braziers catch again; the bell rises.
	show_frame("snuffer_die")
	tint.a = 1.0
	fade = clampf(1.0 - (death_time - 0.8) * 1.2, 0.0, 1.0)
	if sprite:
		sprite.position = Vector2(sin(death_time * 40.0) * 3.0 * clampf(1.2 - death_time, 0.0, 1.0), -death_time * 10.0)
	if world and world.glow and fmod(death_time, 0.12) < dt and death_time < 1.4:
		world.glow.burst(center() + Vector2(randf_range(-26, 26), randf_range(-50, 30)), 8, Color(0.55, 0.52, 0.64, 0.8), 90.0, 0.9, -80.0, 4.0)
	if death_time > 1.2 and death_time - dt <= 1.2 and world:
		var f = _features()
		if f:
			f.reset_braziers(true)
		world.boss_defeated(self, center())
		world.add_bell(Vector2((arena_left + arena_right) * 0.5, floor_y))
	if death_time > 2.0:
		gone = true


# ---------------------------------------------------------------- the look

func eye_points() -> Array:
	if state in ["under", "sink"]:
		return []
	var head := position + Vector2(facing * 4.0, -BODY.y + 24.0)
	return art_eyes(EYES, [head + Vector2(-5, 0), head + Vector2(5, 0)])


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if world:
		_draw_choir(glow)
	if state in SMOTHER_STATES:
		_draw_smother(glow)
	if _bm:
		_bm.draw_glow(glow)
	if not alive:
		return
	# Cold eyes in the hollow face.
	var ea := 0.95 if solid() else 0.6
	for p in eye_points():
		glow.draw_circle(p, 4.0, Color(0.7, 0.85, 1.0, 0.25 * ea))
		glow.draw_circle(p, 1.5, Color(0.85, 0.95, 1.0, ea))
	# Hollow: only a smoky edge of him shows in the dark, and smoke leaks off.
	# The edge traces the stand-in drawing, so it's drawn only with no frames
	# (real art shows hollowness through the sprite's alpha) and never while
	# the lunge tips him over.
	if frames.is_empty() and not solid() and state not in ["under", "sleep", "lunge_draw", "lunge"]:
		var edge := PackedVector2Array()
		for q in _robe():
			edge.append(position + q)
		edge.append(edge[0])
		glow.draw_polyline(edge, Color(0.78, 0.74, 0.95, 0.30 + 0.08 * sin(t * 4.0)), 2.0)
	if not solid() and state != "under":
		for i in 4:
			var k := fmod(t * 0.7 + i * 0.25, 1.0)
			var p := position + Vector2(sin(t * 1.3 + i * 2.0) * 16.0, -20.0 - k * 90.0)
			glow.draw_circle(p, 5.0 + k * 7.0, Color(0.55, 0.52, 0.66, 0.16 * (1.0 - k)))
	for w in _whiffs:
		var k: float = w["t"] / 0.5
		glow.draw_line(w["p"] + Vector2(-10 - k * 14, 0), w["p"] + Vector2(10 + k * 14, 0), Color(0.8, 0.8, 0.95, 0.6 * (1.0 - k)), 1.5)
		glow.draw_circle(w["p"], 3.0 + k * 8.0, Color(0.7, 0.7, 0.9, 0.3 * (1.0 - k)))
	match state:
		"raise":
			# The cone's rim glows and a ring closes on where it will land.
			var k := 1.0 - clampf(timer / maxf(tell(RAISE[clampi(phase - 1, 0, 2)]), 0.01), 0.0, 1.0)
			var rim := _cone_mouth()
			glow.draw_arc(rim, 12.0, 0.0, PI, 12, Color(1.0, 0.8, 0.45, 0.4 + 0.6 * k), 3.0)
			var fx := _slam_x
			var rx := SLAM_W * 0.5 + (1.0 - k) * 30.0
			var ring := ellipse(Vector2(fx, floor_y - 1.0), rx, 5.0, 24)
			ring.append(ring[0])
			glow.draw_polyline(ring, Color(1.0, 0.75, 0.4, 0.35 + 0.55 * k), 2.0)
			glow.draw_colored_polygon(ellipse(Vector2(fx, floor_y - 1.0), SLAM_W * 0.5 * k, 4.0 * k + 0.5, 16), Color(0.1, 0.05, 0.1, 0.5 * k))
		"stuck":
			var rim2 := Vector2(_slam_x, _stuck_floor() - 10.0)
			glow.draw_arc(rim2, 13.0, PI, TAU, 12, Color(1.0, 0.85, 0.6, 0.35), 2.0)
		"snuff_tell", "glide", "cap":
			if not _target.is_empty():
				# "Shhh": a dotted thread from his face to the brazier he wants.
				var a := _face_point()
				var b: Vector2 = _target["flame"]
				var n := int(a.distance_to(b) / 14.0)
				for i in n:
					var q := a.lerp(b, (i + fmod(t * 2.0, 1.0)) / maxf(n, 1))
					glow.draw_circle(q, 1.6, Color(0.8, 0.8, 1.0, 0.5))
			if state == "cap":
				var k2 := 1.0 - clampf(timer / SNUFF_CAP, 0.0, 1.0)
				glow.draw_arc(_target.get("flame", center()), 16.0 - k2 * 8.0, 0.0, TAU, 16, Color(0.7, 0.7, 1.0, 0.8), 2.0)
		"lunge_draw", "lunge":
			if state == "lunge_draw":
				# The cone's tip, the point he'll come at you with, glints.
				var tip := art_point("snuffer_lunge", "cone_tip")
				if tip != Vector2.INF:
					var kk := 1.0 - clampf(timer / maxf(tell(LUNGE_DRAW), 0.01), 0.0, 1.0)
					glow.draw_circle(tip, 3.0 + 5.0 * kk, Color(0.8, 0.85, 1.0, 0.25 + 0.3 * kk))
					glow.draw_line(tip + Vector2(-4.0 - 6.0 * kk, 0), tip + Vector2(4.0 + 6.0 * kk, 0), Color(1, 1, 1, 0.9), 1.4)
					glow.draw_line(tip + Vector2(0, -4.0 - 6.0 * kk), tip + Vector2(0, 4.0 + 6.0 * kk), Color(1, 1, 1, 0.9), 1.4)
			# The glowing trail.
			var r := body_rect()
			for i in 5:
				var y := r.position.y + 6.0 + i * 7.0
				var len := 30.0 + i * 8.0 if state == "lunge" else 12.0 + (1.0 - timer / maxf(tell(LUNGE_DRAW), 0.01)) * 30.0
				var x0 := r.get_center().x - _lunge_dir * r.size.x * 0.5
				glow.draw_line(Vector2(x0, y), Vector2(x0 - _lunge_dir * len, y), Color(0.75, 0.8, 1.0, 0.5 - i * 0.06), 2.0)
		"call":
			var k3 := 1.0 - clampf(timer / maxf(tell(0.9), 0.01), 0.0, 1.0)
			glow.draw_arc(center(), 20.0 + 50.0 * k3, 0.0, TAU, 28, Color(0.7, 0.5, 1.0, 0.7 * (1.0 - k3)), 3.0)
		"sink", "under", "rise":
			pass
	# The smoke tide, over the World's simple puffs.
	if not _tide.is_empty() and _tide.get("life", 0.0) > 0.0:
		var tr: Rect2 = _tide["rect"]
		for i in 6:
			var k4 := float(i) / 5.0
			var p := Vector2(tr.position.x + tr.size.x * (0.5 + sin(t * 3.0 + i) * 0.4), tr.end.y - k4 * tr.size.y)
			glow.draw_circle(p, 16.0 - k4 * 4.0, Color(0.32, 0.28, 0.4, 0.7))
			glow.draw_circle(p + Vector2(-3, -3), 9.0 - k4 * 3.0, Color(0.55, 0.5, 0.66, 0.55))
		var front := tr.end.x if float((_tide["vel"] as Vector2).x) > 0.0 else tr.position.x
		glow.draw_line(Vector2(front, tr.position.y), Vector2(front, tr.end.y), Color(0.8, 0.75, 0.95, 0.4), 2.0)


func _cone_mouth() -> Vector2:
	## Where the snuffer bell's mouth is: on the frame on show (the art's
	## bell_mouth), else the stand-in drawing's pose.
	if state in ["stuck", "slam"]:
		return Vector2(_slam_x, _stuck_floor() - 10.0)
	var p := art_point(frame_name, "bell_mouth")
	if p != Vector2.INF:
		return p
	match state:
		"raise":
			return position + Vector2(-facing * 18.0, -BODY.y - 34.0)
	return position + Vector2(facing * 26.0, -BODY.y - 16.0)


func _face_point() -> Vector2:
	## His face (the art's "head" point), where a whisper or a scream starts.
	var p := art_point(frame_name, "head")
	if p != Vector2.INF:
		return p
	return center() + Vector2(0, -30)


func _robe() -> PackedVector2Array:
	## His silhouette (local, feet at the origin): hood, shoulders, a hem
	## that frays into smoke.
	var h := BODY.y
	var pts := PackedVector2Array([Vector2(-19, -h + 36), Vector2(-15, -h + 9), Vector2(-6, -h - 1), Vector2(6, -h - 1),
			Vector2(15, -h + 9), Vector2(19, -h + 36), Vector2(24, -h + 60)])
	for i in 9:
		var x := 27.0 - i * 6.75
		pts.append(Vector2(x, -3.0 - (7.0 if i % 2 == 0 else 0.0) - sin(t * 3.0 + i) * 2.0))
	pts.append(Vector2(-24, -h + 60))
	return pts


func _draw() -> void:
	if not frames.is_empty():
		return
	if state == "under":
		return
	var f := facing
	var cloak := Color("2c2440")
	var cloak2 := Color("3e3458")
	var rim := Color("6e6290")
	var wax := Color("ece0c4")
	var wax2 := Color("c8b890")
	var iron := Color("4a4458")
	var brass := Color("c8962e")
	var h := BODY.y
	var lunge := state in ["lunge_draw", "lunge"]
	if lunge:
		draw_set_transform(Vector2(0, -34.0), -f * 1.2, Vector2(0.85, 0.85))
	var robe := _robe()
	o_poly(robe, cloak, 2.5)
	# A lit edge down his near side, and the fold of the cloak.
	draw_polyline(PackedVector2Array([robe[1], robe[0], robe[6]]), pc(rim), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(f * 3, -h + 38), Vector2(f * 15, -h + 38), Vector2(f * 23, -14), Vector2(f * 8, -12)]), pc(cloak2))
	# The hood's dark opening, and in it his face: a burnt-out candle.
	o_poly(PackedVector2Array([Vector2(-12, -h + 34), Vector2(-11, -h + 12), Vector2(0, -h + 5), Vector2(11, -h + 12), Vector2(12, -h + 34)]), Color("120e1c"), 1.0)
	o_poly(PackedVector2Array([Vector2(-8, -h + 33), Vector2(-8, -h + 15), Vector2(8, -h + 15), Vector2(8, -h + 33)]), wax, 1.5)
	draw_rect(Rect2(-8, -h + 29, 16, 4), pc(wax2))
	draw_rect(Rect2(-6 + f * 1.0, -h + 21, 12, 6), pc(Color("141020")))
	for dx in [-5, 2, 6]:
		draw_rect(Rect2(dx - 1, -h + 32, 2.5, 4 + absf(dx) * 0.6), pc(wax))
	# The dead wick, bent, a thread of smoke off it.
	draw_line(Vector2(0, -h + 15), Vector2(f * 3.0, -h + 8), pc(Color("141020")), 2.5)
	# The pole and its snuffer cone.
	var hand := Vector2(f * 17.0, -h + 52.0)
	var cone := _cone_mouth() - position
	if lunge:
		cone = Vector2(f * 62.0, -h + 52.0)
	o_line(hand, cone + Vector2(0, -16), 3.0, iron)
	var tip := cone + Vector2(0, -24)
	o_poly(PackedVector2Array([cone + Vector2(-13, 0), cone + Vector2(13, 0), tip + Vector2(3, 0), tip + Vector2(-3, 0)]), brass, 2.0)
	draw_line(cone + Vector2(-9, -3), tip + Vector2(-1.5, 2), pc(Color("f0c86a")), 2.0)
	draw_line(cone + Vector2(-13, -1), cone + Vector2(13, -1), pc(Color("f0c860")), 2.0)
	o_circle(hand, 5.0, cloak2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the rush ("Hollow Again")

func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	if _bm:
		_bm.step(dt, player)


func lights() -> Array:
	## The Warded motes' lights (none in the story: elites.gd's are the Omen's).
	var out: Array = super()
	if _bm:
		out.append_array(_bm.lights())
	return out


func _story_bark(key: String) -> void:
	## One of Mother Taper's lines. The rush skips every story beat (spec
	## §5.6: music and bar only).
	if rush:
		barks_skipped += 1
	elif world:
		world.bark(key)


func _ring_clamp(x: float) -> float:
	return clampf(x, arena_left + SMOTHER_W * 0.5, arena_right - SMOTHER_W * 0.5)


func _stuck_floor() -> float:
	## Where the pole (or the Smother's cone) is stuck: the floor, or in the
	## rush the ledge the Smother came down on.
	return _stuck_y if rush and _stuck_y > 0.0 else floor_y


func smother_track_time() -> float:
	return tell(SMOTHER_TRACK, SMOTHER_TRACK_FLOOR)


func smother_lock_time() -> float:
	return tell(SMOTHER_LOCK, SMOTHER_LOCK_FLOOR)


func _start_smother(player: Node2D) -> void:
	## Smother: up over Wick, the cone held high, the ring under him.
	_ring_x = _ring_clamp(player.position.x)
	_stand_y = player.position.y
	_ring_y = _surface_at(_ring_x, _stand_y)
	_face(player.position.x - position.x)
	state = "smother_rise"
	timer = SMOTHER_RISE
	smothers += 1
	sfx("snuffer_whisper", "", 0.8)


func _surface_at(x: float, from_y: float) -> float:
	## The top of the first thing to stand on at x, from from_y down (a
	## ledge's top, the floor): the floor when nothing's nearer.
	var tx := floori(x / TILE)
	var ty := floori((from_y - 4.0) / TILE)
	for k in 16:
		var tl: int = level.tile(tx, ty + k)
		if LevelData.is_solid(tl) or (LevelData.is_ledge(tl) and (world == null or not world.has_method("ledge_present") or world.ledge_present(tx, ty + k))):
			return minf(float((ty + k) * TILE), floor_y)
	return floor_y


func _track_ring(player: Node2D) -> void:
	## The ring sits on what Wick stands on: the ground under it no higher
	## than his feet (a ledge he's up on, else the floor). In the air it
	## never rises (a jump doesn't lift it), but it follows him down.
	if bool(player.get("on_floor")):
		_stand_y = player.position.y
	else:
		_stand_y = maxf(_stand_y, player.position.y)
	_ring_y = _surface_at(_ring_x, _stand_y)


func _smother_lift(share: float) -> float:
	## His lift (over his hover) so he hangs over the ring's surface: up to
	## SMOTHER_LIFT over it (x share as the cone comes down), as much as the
	## ceiling leaves room for over a ledge.
	var over := maxf(floor_y - _ring_y, 0.0)
	var room := (_ring_y - HOVER) - (_ceiling_at(position.x) + BODY.y + SMOTHER_ROOM)
	return over + minf(SMOTHER_LIFT, maxf(room, 0.0)) * share


func _over_ring(dt: float, speed: float) -> void:
	## He hangs where the snuffer bell's mouth (held out in front, as when he
	## caps a brazier: _cap_reach()) is over the ring; against a wall he turns
	## round to keep it there.
	var lo := arena_left + BODY.x * 0.5
	var hi := arena_right - BODY.x * 0.5
	var tx := _ring_x - facing * _cap_reach()
	if tx < lo or tx > hi:
		facing = -facing
		tx = _ring_x - facing * _cap_reach()
	_glide_to(clampf(tx, lo, hi), speed, dt)


func smother_zone() -> Rect2:
	## Where the cone comes down: the column over the ring, from its surface
	## (the floor, or the ledge Wick's on) up through the air over it.
	return Rect2(_ring_x - SMOTHER_W * 0.5, _ring_y - SMOTHER_COLUMN, SMOTHER_W, SMOTHER_COLUMN)


func smother_countdown() -> Dictionary:
	## The ring's tell as drawn (the tests read it): sweep 0..1 through the
	## track (a clock hand filling round the ring), warn 0..1 through its last
	## SMOTHER_WARN s (it flashes and warms), lock 0..1 through the lock.
	var out := {"sweep": 0.0, "warn": 0.0, "lock": 0.0}
	match state:
		"smother_track":
			out["sweep"] = 1.0 - clampf(timer / maxf(smother_track_time(), 0.01), 0.0, 1.0)
			out["warn"] = 1.0 - clampf(timer / SMOTHER_WARN, 0.0, 1.0)
		"smother_lock":
			out["sweep"] = 1.0
			out["warn"] = 1.0
			out["lock"] = 1.0 - clampf(timer / maxf(smother_lock_time(), 0.01), 0.0, 1.0)
	return out


func _smother_drop(player: Node2D) -> void:
	## The cone drops: 40 and a douse under it; it sticks 1.0 s where it fell
	## (the ledge it came down on, too) and he's solid.
	var zone := smother_zone()
	if _bm:
		_bm.strike(zone, dmg("smother"))
	if world:
		if player.alive and zone.intersects(player.rect()):
			if world.hurt_player(dmg("smother"), _ring_x, "hit", self, {"move": "smother"}):
				world.douse_player()
		world.shake = maxf(world.shake, 8.0)
		world.dust_at(Vector2(_ring_x, _ring_y))
		world._haptic(45)
		if world.glow:
			world.glow.burst(Vector2(_ring_x, _ring_y - 4.0), 20, Color("c8c0d8"), 190.0, 0.45, 400.0, 2.6)
	sfx("snuffer_slam", "boss_slam", 0.85)
	_slam_x = _ring_x
	_stuck_y = _ring_y
	_lift = maxf(floor_y - _ring_y, 0.0)
	_lift_to = 0.0
	position.y = _ring_y
	show_frame("snuffer_slam")
	state = "stuck"
	timer = SMOTHER_STUCK + window_bonus()


func _ellipse_arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw_smother(glow: Node2D) -> void:
	## The Smother's tell above the dark: a cone-shadow under the ring on
	## what Wick stands on, a pale ring that follows him, a cone of light
	## from the snuffer's mouth down to it. Its countdown reads ahead: a
	## bright sweep fills round the ring through the track like a clock hand;
	## in its last 0.5 s the ring flashes, tightens and warms; at the lock it
	## turns warm orange and closes in as the cone comes down.
	var tb := gtb()
	var y := _ring_y - 1.0
	var half := SMOTHER_W * 0.5
	var k := 0.0            # 0..1 through the rise, 1 after
	match state:
		"smother_rise":
			k = 1.0 - clampf(timer / SMOTHER_RISE, 0.0, 1.0)
		"smother_track", "smother_lock":
			k = 1.0
	var cd := smother_countdown()
	var sweep: float = cd["sweep"]
	var warn: float = cd["warn"]
	var lock: float = cd["lock"]
	var cold := Color(0.80, 0.76, 1.0)
	var warm := Color(1.0, 0.72, 0.4)
	# (the warning is a step, not a fade: the ring turns amber the moment it
	# starts, so it reads as a change even at a glance)
	var col := cold.lerp(warm, maxf(lock, (0.45 + 0.3 * warn) if warn > 0.0 else 0.0))
	# The shadow on the floor, darker as the cone comes down, and a pale
	# wash inside the ring so the spot reads on a dark floor.
	var rx := half + 14.0 * (1.0 - lock) - 5.0 * warn * (1.0 - lock)
	var ry := 6.0 + 2.0 * (1.0 - lock)
	tb.ellipse(Vector2(_ring_x, y), rx, ry, Color(0.04, 0.02, 0.07, (0.35 + 0.4 * lock) * k), 20)
	tb.ellipse(Vector2(_ring_x, y), rx - 3.0, ry - 1.5, Color(col, (0.14 + 0.08 * warn + 0.12 * lock) * k), 20)
	# The cone of light from the snuffer's mouth down to the ring.
	var mouth := _cone_mouth()
	tb.quad(mouth + Vector2(-9, 4), mouth + Vector2(9, 4), Vector2(_ring_x + rx * 0.8, y - 2.0), Vector2(_ring_x - rx * 0.8, y - 2.0),
			Color(col, (0.07 + 0.05 * warn + 0.10 * lock) * k))
	# The ring itself: bright, flashing in the warning, closing in at the lock.
	var ring := _ellipse_arc(Vector2(_ring_x, y), rx, ry, 0.0, TAU, 24)
	var pulse := 0.5 + 0.5 * sin(t * (9.0 if lock > 0.0 else (14.0 if warn > 0.0 else 4.0)))
	var flash_a := maxf(lock, maxf(0.25 * pulse, warn * (0.55 + 0.45 * pulse)))
	tb.polyline(ring, 3.0 + 1.0 * maxf(lock, warn), Color(col, (0.65 + 0.35 * flash_a) * k), true)
	# The countdown: a white-hot sweep round the ring (from its far side,
	# clockwise), full as it locks, with a bead at its head.
	if sweep > 0.0 and lock <= 0.0:
		var a0 := -PI * 0.5
		var a1 := a0 + TAU * sweep
		var arc := _ellipse_arc(Vector2(_ring_x, y), rx + 2.5, ry + 1.5, a0, a1, maxi(3, int(24.0 * sweep)))
		var hot := Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.85, 0.55), 1.0 if warn > 0.0 else 0.0)
		tb.polyline(arc, 3.5 + 1.5 * warn, Color(hot, 0.9 * k), false)
		tb.circle(arc[arc.size() - 1], 3.5 + 1.5 * warn, Color(hot.lightened(0.3), k), 8)
	# A dotted drop line from the mouth to the ring's middle.
	var yy := mouth.y + 8.0
	while yy < y - 8.0:
		tb.line(Vector2(_ring_x, yy), Vector2(_ring_x, minf(yy + 6.0, y - 8.0)), 2.0, Color(col, (0.25 + 0.2 * warn + 0.35 * lock) * k))
		yy += 14.0
	tb.flush(glow)
