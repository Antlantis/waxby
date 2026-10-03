extends "res://scripts/boss_rig.gd"
## The Tinker of Hours (World 4's boss, `boss: tinker`; spec §5.3,
## decisions "The Tinker", A4's points_tinker.json).
##
## A walking clockwork bell-body of brass and frosted wax; on its back, in a
## frosted case, Master Tickwell, frozen: its prisoner, not its pilot. The
## rule: ring the hour the clock shows.
##   The clock   the back wall's frozen clock face (clock_face, behind the
##               tiles) with one hand, drawn in the glow layer. Four hour
##               bells round the arena (the arena's `+` anchors: XII, IX,
##               III, VI). The hand points at one and that bell glows gold (a
##               ring, a light r 60); the others are frosted grey and ignore
##               shots and waves.
##   The hand    P1 clockwise every 3.0 s, P2 every 2.5 s, P3 counter-clockwise
##               every 2.2 s (never by difficulty), each a "tock", a jump and a
##               glow shift; it dwells 1.5x on XII, and a bell still rings up to
##               RING_GRACE s after the hand leaves it. A bell rings once a
##               visit of the hand: rung, it stays dead (lit but dim, no ring)
##               until the hand comes back to it, and at least REARM s.
##   Chimed      ring the lit bell (a slash, a shot, a wave, a stomp) and the
##               hour strikes: a gold ring sweeps the arena and he falls on his
##               face, the case open on the mainspring: the window, WINDOW by
##               phase (Tollbreaker +0.4). The spring box is his rect() then
##               (full damage, the window's first stomp 3x); he isn't solid;
##               his facing is turned from Wick so every spring hit is on his
##               back (a Sootrunner's Backstab from either side), his look kept.
##               The hour strikes only the hour he guards: a lit bell glows
##               dim, and a blow on it does nothing (no chime, nothing spent),
##               until he has come within POST tiles of it since the hand
##               moved there or he last fell, and while he can't fall (down
##               already, getting up, UNWOUND, a roar). So ringing it drops
##               him beside it, and he can't be kept down bell after bell.
##   Wrong hour  a slash or a stomp on a frosted bell: "Wrong hour!", the hand
##               spins to another bell and every bell frosts WRONG_FROST s;
##               through that frost, and on a bell already rung, a blow does
##               nothing (no second wrong hour off a stomp's bounce).
##   The guard   he goes to the floor under the lit bell, GUARD tiles to one
##               side of it: the wall's side for a bell by a wall (IX, III on
##               their ledges: never between the middle and the ledge), else
##               the side he's on. He hurries there (HURRY) when he's far, and
##               starts his next move only once he's there (or GUARD_WAIT s);
##               he never walks into Wick (he stops STOP_GAP px short).
## Moves (after the x0.875 scale): Gear Toss (0.55 s, floor 0.40: 2 cogs, 3
## from P2, rolling at 230 / 260 / 290 px/s, rebounding once: 26; at a Wick
## standing more than LOB_ABOVE px up, the XII beam, they're lobbed onto the
## far end of his floor, the landing marked, and roll at him), the Minute
## Hand (0.85 s, floor 0.55: a pale arc of 100 px and 150 degrees in front,
## then the cut: 35, knockback), Wind the Soldiers (at 75% and 45%: a key in
## the floor 0.8 s, 2 Tickwinds from the hatches, at most 3), Stop the Clock
## (P2+: 0.8 s, the watch up, a pale vignette, the hand frozen; then
## world.stop_time 1.6 s: everything but Wick and him freezes; 5 frozen hands
## in a 110 px ring round Wick, each drawn with its lead line through where he
## stood to where it will stop, tremble 0.4 s before time resumes and fly
## along their lines at 420 px/s, stopping at the line's end: 30), the
## Pendulum (P2+: released at the P2 roar; its own, pivot under the XII beam,
## 5 tiles, bob 22 px, 3.2 s, +-60 deg, a moving light r 90: 32), Rewind (P3:
## 0.6 s of afterimages along his path, the last where he'll stop, then back
## to where he stood 2.0 s before, and every cog and hand he threw in that
## time flies back along its path), Midnight (the P3 roar: twelve chimes over
## 3 s, untouchable, icicles in lanes with 3 safe lanes drawn: 26; every lane
## on stone or, on the grown ice, 5 tiles wide for the 134 px slide; the
## icicles die on the first floor they meet, where their danger is drawn;
## the floor's ice grows a tile each side; the hand runs backward), and his
## touch (24, never while Chimed).
## A Knight's Perfect Guard on the Minute Hand reels him 1.0 s (chip time, not
## a window). UNWOUND! spins him dizzily 1.0 s.
## Retry: the hand to XII, the pendulum still, the ice back, the soldiers and
## everything thrown gone, time running.
##
## Numbers (spec §5.1): BASE_HP 590 (the reference knight needs 6-7 windows:
## tests/test_bosses3.gd), the Minute Hand 35 (30% of the arrival knight),
## touch 24. Sounds through tell_sfx at each tell's start (A7); the Minute
## Hand's tell is gear_catch's grind until A7 gives it its own.

const FRAME_FEET := Vector2(192, 368)
const POINTS_PATH := "res://art/enemies/points_tinker.json"
const FRAMES := ["tinker_idle", "tinker_walk1", "tinker_walk2", "tinker_toss", "tinker_swing", "tinker_watch",
		"tinker_chimed", "tinker_rewind", "tinker_overwind", "tinker_die"]
const MOVES := {"toss": 26.0, "minute": 35.0, "hands": 30.0, "pendulum": 32.0, "midnight": 26.0}
const TOUCH := 24.0
# The windows test's knob, at the spec's start: the reference knight needs 6
# windows (phases 2 and 3 fit two each with 2% to spare; a retune that costs
# him 2% makes it 7, still allowed).
const BASE_HP := 590.0
const RUSH_K := 0.85
const WINDOW := [2.4, 2.0, 1.7]
const ORDER := ["XII", "III", "VI", "IX"]    # clockwise
const HAND_EVERY := [3.0, 2.5, 2.2]
const XII_DWELL := 1.5
const RING_GRACE := 0.5
const REARM := 1.0
const WRONG_FROST := 1.0
const WALK := 70.0
const HURRY := 200.0                # px/s to a new guard spot when he's far from it (a clockwork scuttle)
const POST := 3.5                   # tiles from the lit bell (along the floor) where he counts as guarding it
const HURRY_FAR := 40.0             # px from the guard spot beyond which he hurries
const GUARD := 3.0                  # tiles from the lit bell he stands (2-4)
const GUARD_SETTLE := 40.0          # px from the guard spot that count as there (the next move may start)
const GUARD_WAIT := 2.4             # s he waits to get there before moving on anyway
const STOP_GAP := 6.0               # px he stops short of Wick
const LOB_ABOVE := 64.0             # px: a Wick standing higher than this (a ledge, the beam) gets lobbed cogs
const LOB_T := 0.7                  # s a lobbed cog flies
const COG_G := 1400.0               # a cog's fall (px/s2)
const TOSS_TELL := 0.55
const TOSS_FLOOR := 0.40
const COG_SPEED := [230.0, 260.0, 290.0]
const COG_R := 13.5
const COG_LIFE := 4.0
const SWING_TELL := 0.85
const SWING_FLOOR := 0.55
const ARC_R := 100.0
const ARC_FROM := -90.0             # degrees, facing right, y down: straight up...
const ARC_TO := 60.0                # ...to down in front (150 degrees)
const ARC_PIVOT := Vector2(20, -64)  # from his feet, facing right
const SWING_CUT := 0.18
const SWING_REACH := 96.0           # he steps in to this before the tell
const APPROACH := 1.5
const STOP_TELL := 0.8
const STOP_T := 1.6
const HANDS_N := 5
const HAND_RING := 110.0
const HAND_SPEED := 420.0
const TREMBLE := 0.4
const HAND_SIZE := Vector2(36, 6)
const HAND_ANGLES := [180.0, 225.0, 270.0, 315.0, 0.0]
const KEY_TELL := 0.8
const SOLDIERS_AT := [0.75, 0.45]
const NOT_YET_EVERY := 0.6          # s between two "Not yet!"s on a bell that isn't ready
const SOLDIERS_MAX := 3
const PEND_ROD := 160.0
const PEND_BOB := 11.0
const PEND_PERIOD := 3.2
const PEND_AMP := 60.0
const PEND_LIGHT := 90.0
const REWIND_TELL := 0.6
const REWIND_BACK := 2.0
const REWIND_T := 0.5
const MIDNIGHT_T := 3.0
# The 3 safe lanes, [left column, tiles] in K_ARENA's columns, two patterns:
# each on stone once the ice has grown (cols 3-10 and 19-26 are ice then), or
# 5 tiles wide on the ice, so a run released at its edge stops inside it
# (134 px, the feel lab's round 2).
const MIDNIGHT_LANES := [[[11, 3], [16, 3], [28, 3]], [[4, 5], [12, 3], [21, 5]]]
const ICE_LANE_TILES := 5
const CHORD := [0, 2, 3, 5]         # the four hour bells as one chord at his death (Sfx.note degrees)
const VOLLEYS := [0.75, 1.5, 2.25]
const ICICLE_TELL := 0.5
const REEL := 1.0
const UNWOUND := 1.0
const GETUP := 0.5
const MOVE_GAP := 1.1
const ROT := {1: ["toss", "swing", "toss", "swing"],
		2: ["toss", "stop", "swing", "toss", "swing"],
		3: ["toss", "rewind", "stop", "swing", "toss", "swing"]}
# The spec's K_ARENA cells (arena columns and rows) when the arena has no
# four anchors, and the pendulum's pivot (the underside of the XII beam).
const SPEC_BELLS := {"XII": [16, 3], "IX": [5, 9], "III": [27, 9], "VI": [17, 12]}
const SPEC_PIVOT := [17, 5]
const HAND_LEN := 112.0
const GOLD := Color(1.0, 0.82, 0.38)
const FROST := Color(0.78, 0.86, 0.95)
const LENS := Color("8ae0ff")
const BRASS := Color("b89a4a")
static var _points := {}

var bells: Array = []               # {name, cell, cx, surf, mouth, box}
var hand_i := 0                     # the bell the hand points at (ORDER index)
var hand_dir := 1                   # +1 clockwise, -1 counter-clockwise
var _hand_at := 0.0                 # clock() when the hand moves on
var _prev_i := -1                   # the bell it just left...
var _prev_until := -1.0             # ...rings until then
var _arm: Array = [0.0, 0.0, 0.0, 0.0]   # clock() each bell re-arms at
var _rung: Array = [false, false, false, false]   # rung this visit of the hand (dead till it comes back)
var _post := -1                     # the bell he has come to guard (within POST tiles) this visit of the hand
var _post_prev := -1                # ...and the one the hand just left (its RING_GRACE)
var _frost_until := -1.0            # every bell frosted until then (a wrong hour)
var _wrong_n := 0
var _hand_anim := 0.0               # the tock's jump (seconds left)
var _hand_from := 0.0
var hub := Vector2.ZERO
var pivot := Vector2.ZERO
var pend_on := false
var _pend_t := 0.0
var _pend_prev := 0.0
var _shots: Array = []              # his cogs and hands: {kind, pos, vel, t, life, path, rev, hit, rebounds, thrown, frozen, dir}
var _hist: Array = []               # [clock, x] where he stood
var _queue: Array = []
var _rot := {1: 0, 2: 0, 3: 0}
var _soldiers_owed := 0
var _not_yet_until := -1.0          # the "Not yet!" answer's own cool-down (a stomp's bounce, mashing)
var _soldiers_done: Array = []
var _hatches: Array = []            # floor points at the arena's ends
var _aim := Vector2.ZERO
var _placed := 0
var _taped := false                 # the music's tape stopped (Stop the Clock), to start again
var _claimed := false               # the arena's feature weight taken out (once the features exist)
var _swing_t := 0.0
var _swing_hit := false
var _rew_from := 0.0
var _rew_to := 0.0
var _ghost_x: Array = []            # Rewind's afterimages (world x), fixed at its tell: the last is _rew_to
var _walk_t := 0.0                  # seconds in the walk (the guard) since his last move
var chimes_at: Array = []           # (tests) [bell, spring x] at each chime
var _icicles: Array = []            # {x, y, vy, t, hit, top}
var _lanes: Array = []
var _volley := 0
var _ice_cells: Array[Vector2i] = []
var _chime := {}                    # {p, t}: the hour's gold ring sweeping out
var _chimes_rung := 0
var _look_hold := -1
var _tick_t := 0.0
var _step_t := 0.0
var chimed_count := 0               # (tests)
var wrong_hours := 0                # (tests)
var _clock_spr: Sprite2D = null
var _hand_node: Node2D = null       # the clock's hand, on the face behind the tiles
var _htb: RefCounted = null
var _bell_spr: Array[Sprite2D] = []
var _cog_spr: Array[Sprite2D] = []
var _hand_spr: Array[Sprite2D] = []
var _hatch_spr: Array[Sprite2D] = []
var _ghost_spr: Array[Sprite2D] = []
var _tex := {}


func _init() -> void:
	super()
	boss_id = "tinker"
	boss_name = "The Tinker of Hours"
	boss_title = "The Frozen Minute"
	xp_kind = "tinker"
	size = Vector2(100, 160)
	base_hp = BASE_HP
	base_dmg = TOUCH
	embers = 70
	anchor = FRAME_FEET


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("tinker_idle")
	facing = 1
	look_face = 1
	for n in ["clock_face", "hour_bell_frozen", "hour_bell_lit", "gear_saw", "hour_hand", "soldier_hatch"]:
		var p := "res://art/enemies/%s.svg" % n
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	_build_bells()
	_find_pivot()
	_hatches = [Vector2(arena_left + 40.0, floor_y), Vector2(arena_right - 40.0, floor_y)]
	if _tex.has("clock_face"):
		_clock_spr = add_part("clock_face", Vector2(288, 288))
		_clock_spr.texture = _tex["clock_face"]
		_clock_spr.z_index = -5
		_clock_spr.modulate = Color(0.62, 0.66, 0.76)
	_hand_node = Node2D.new()
	_hand_node.z_index = -4
	add_child(_hand_node)
	_hand_node.draw.connect(_draw_hand)
	for b in bells:
		_bell_spr.append(add_part("hour_bell_frozen", Vector2(32, 81)))
	for i in 8:
		_cog_spr.append(add_part("gear_saw", Vector2(32, 32)))
	for i in HANDS_N * 2:
		_hand_spr.append(add_part("hour_hand", Vector2(14, 16)))
	for h in _hatches:
		var s := add_part("soldier_hatch", Vector2(32, 16))
		_hatch_spr.append(s)
	for i in 3:
		var g := Sprite2D.new()
		g.centered = false
		g.offset = -FRAME_FEET * 2.0
		g.visible = false
		add_child(g)
		move_child(g, 0)
		_ghost_spr.append(g)
	_reset_clock()
	_place_props()


static func points() -> Dictionary:
	if _points.is_empty():
		var text := FileAccess.get_file_as_string(POINTS_PATH) if FileAccess.file_exists(POINTS_PATH) else ""
		var d = JSON.parse_string(text) if text != "" else null
		_points = d if d is Dictionary else {"_missing": true}
	return _points


func art_pt(frame: String, key: String, fallback: Vector2) -> Vector2:
	var f = points().get(frame, {})
	if frames.is_empty() or not (f is Dictionary) or not (f as Dictionary).has(key):
		return fallback
	var q: Array = f[key]
	return frame_point(Vector2(float(q[0]), float(q[1])))


func art_box(frame: String, key: String, fallback: Rect2) -> Rect2:
	var f = points().get(frame, {})
	if frames.is_empty() or not (f is Dictionary) or not (f as Dictionary).has(key):
		return fallback
	var q: Array = f[key]
	var a := frame_point(Vector2(float(q[0]), float(q[1])))
	var b := frame_point(Vector2(float(q[0]) + float(q[2]), float(q[1]) + float(q[3])))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


# ---------------------------------------------------------------- the clock

func _build_bells() -> void:
	## The four hour bells: the arena's anchors (the topmost XII, the lowest
	## VI, then IX left and III right), else the spec's cells.
	bells.clear()
	var cells: Array = anchors.duplicate()
	var named := {}
	if cells.size() == 4:
		var by_y := cells.duplicate()
		by_y.sort_custom(func(p, q): return p.y < q.y)
		named["XII"] = by_y[0]
		named["VI"] = by_y[3]
		var mid := [by_y[1], by_y[2]]
		mid.sort_custom(func(p, q): return p.x < q.x)
		named["IX"] = mid[0]
		named["III"] = mid[1]
	else:
		var c0 := floori(arena_left / TILE) - 2
		var r0 := floori(floor_y / TILE) - 13
		for nm in SPEC_BELLS:
			named[nm] = Vector2i(c0 + int(SPEC_BELLS[nm][0]), r0 + int(SPEC_BELLS[nm][1]))
	for nm in ORDER:
		var c: Vector2i = named[nm]
		var cx := (c.x + 0.5) * TILE
		var surf := surface_below(cx, c.y * TILE + 1.0)
		var mouth := Vector2(cx, surf - 4.0)
		bells.append({"name": nm, "cell": c, "cx": cx, "surf": surf, "mouth": mouth,
				"box": Rect2(mouth.x - 11.0, mouth.y - 30.5, 22.0, 32.0)})
	var ix: Vector2 = (bells[3]["box"] as Rect2).get_center()
	var iii: Vector2 = (bells[1]["box"] as Rect2).get_center()
	var xii: Vector2 = (bells[0]["box"] as Rect2).get_center()
	var vi: Vector2 = (bells[2]["box"] as Rect2).get_center()
	hub = Vector2((ix.x + iii.x) * 0.5, (xii.y + vi.y) * 0.5)


func _find_pivot() -> void:
	## The pendulum hangs under the XII beam: its `Y` cell's right edge (the
	## spec's (17, 5) for K_ARENA's Y at (16, 5)), else the spec's point.
	pivot = Vector2.ZERO
	if level != null:
		for e in level.entities:
			if str(e.get("kind", "")) == "weight":
				var c: Vector2i = e["cell"]
				var x := (c.x + 1) * TILE
				if x > arena_left and x < arena_right:
					pivot = Vector2(x, c.y * TILE)
					break
	if pivot == Vector2.ZERO:
		var c0 := floori(arena_left / TILE) - 2
		var r0 := floori(floor_y / TILE) - 13
		pivot = Vector2((c0 + int(SPEC_PIVOT[0])) * TILE, (r0 + int(SPEC_PIVOT[1])) * TILE)


func _claim_pendulum() -> void:
	## The arena's Y is his own (spec §3.5.4): a feature weight built on it
	## (features/clockwork.gd) is taken out, with its light, until WL4 skips
	## it in the Tinker's arena.
	if world == null or world.get("features") == null or not world.features.has_method("module"):
		return
	_claimed = true
	var m = world.features.module("clockwork")
	if m == null or m.get("weights") == null:
		return
	var keep := []
	for wt in m.weights:
		var a = wt.get("anchor")
		if a is Vector2 and (a as Vector2).x > arena_left and (a as Vector2).x < arena_right and absf((a as Vector2).y - pivot.y) < 40.0:
			var lid := int(wt.get("light", -1))
			if lid >= 0 and world.has_method("remove_light"):
				world.remove_light(lid)
			continue
		keep.append(wt)
	m.weights = keep


func bell_i(nm: String) -> int:
	return ORDER.find(nm)


func period() -> float:
	## How long the hand stays on its bell (never by difficulty).
	var p := float(HAND_EVERY[clampi(phase - 1, 0, 2)])
	return p * XII_DWELL if hand_i == 0 else p


func _pointed(i: int) -> bool:
	## The hand is on bell i, or left it under RING_GRACE s ago.
	return i == hand_i or (i == _prev_i and clock() < _prev_until)


func bell_lit(i: int) -> bool:
	## Would ringing bell i strike the hour now (when he can fall)?
	var now := clock()
	if state == "sleep" or now < _frost_until or now < float(_arm[i]) or bool(_rung[i]):
		return false
	return _pointed(i)


func bell_spent(i: int) -> bool:
	## The hand's bell (or the one it just left), already rung this visit:
	## lit but dim, and dead to every blow.
	return state != "sleep" and _pointed(i) and (bool(_rung[i]) or clock() < float(_arm[i])) and clock() >= _frost_until


func bell_frosted(i: int) -> bool:
	return not bell_lit(i) and not bell_spent(i)


func can_chime() -> bool:
	## Can the hour knock him flat now? (Not while he's down, getting up,
	## UNWOUND, roaring, asleep or dead.)
	return alive and not (state in ["sleep", "wake", "chimed", "unwound", "midnight", "roar", "dead", "getup"])


func bell_ready(i: int) -> bool:
	## Would a blow on bell i Chime him now: it's lit, he can fall, and he
	## has come to guard it (the hour strikes only the hour he guards, so
	## ringing it drops him beside it; up from a fall he must get back to
	## his post first). Lit but not ready, it glows dim and does nothing.
	return bell_lit(i) and can_chime() and (_post == i or (i == _prev_i and _post_prev == i))


func _reset_clock() -> void:
	hand_i = 0
	hand_dir = 1
	_prev_i = -1
	_prev_until = -1.0
	_frost_until = -1.0
	_arm = [0.0, 0.0, 0.0, 0.0]
	_rung = [false, false, false, false]
	_post = -1
	_post_prev = -1
	_hand_at = clock() + period()
	_hand_anim = 0.0


func _step_hand(dt: float) -> void:
	## The hand moves on at its period (by the feature clock, which stops
	## with time; it holds while he raises the watch).
	if state == "sleep" or state == "dead":
		_hand_at = clock() + period()
		return
	if state == "watch" or (world != null and world.has_method("time_stopped") and world.time_stopped()):
		_hand_at += dt if state == "watch" else 0.0
		return
	_hand_anim = maxf(_hand_anim - dt, 0.0)
	if clock() >= _hand_at:
		_move_hand((hand_i + hand_dir + ORDER.size()) % ORDER.size())


func _move_hand(to: int) -> void:
	_hand_from = hand_angle(hand_i)
	_prev_i = hand_i
	_prev_until = clock() + RING_GRACE
	hand_i = to
	_rung[to] = false                   # a new visit: it may ring again
	_post_prev = _post                  # (the bell left keeps its grace if he was guarding it)
	_post = -1
	_hand_at = clock() + period()
	_hand_anim = 0.14
	sfx("clock_tock", "clink")


static func hand_angle(i: int) -> float:
	## The hand's angle on the clock face (screen radians): XII up, III right.
	return -PI * 0.5 + i * PI * 0.5


func hand_now() -> float:
	## The drawn hand: a quick jump with an overshoot on each tock.
	var to := hand_angle(hand_i)
	if _hand_anim <= 0.0:
		return to
	var d := wrapf(to - _hand_from, -PI, PI)
	var k := 1.0 - _hand_anim / 0.14
	return _hand_from + d * (k + sin(k * PI) * 0.18)


func _check_bells() -> void:
	## A slash, shot, wave or stomp on a bell: the lit one strikes the hour;
	## a slash or a stomp on a frosted one is the wrong hour (shots and waves
	## pass through a frosted bell).
	if state == "sleep" or state == "dead":
		return
	# A wrong hour's frost is the whole penalty: through it no bell does
	# anything (a stomp's bounce can't pile wrong hours up).
	var frost := clock() < _frost_until
	for i in bells.size():
		var lit := bell_lit(i)
		# Dead to every blow: a bell rung this visit, or the lit one while he
		# can't fall or isn't guarding it yet. Shots and waves pass through
		# those as through frost.
		var quiet := frost or bell_spent(i) or (lit and not bell_ready(i))
		var how := struck(bells[i]["box"], "bell%d" % i, quiet or not lit, quiet or not lit)
		if how == "":
			continue
		if quiet:
			# The right hour, too soon (he hasn't come to guard it, or he's
			# down): a dull tick and "Not yet!", and nothing else happens.
			if lit and not frost and not bell_spent(i) and (how == "slash" or how == "stomp"):
				_not_yet(i)
			continue
		if lit:
			_ring(i)
		elif how == "slash" or how == "stomp":
			_wrong_hour(i)


func _not_yet(i: int) -> void:
	## A blow on the lit bell before it's ready: no penalty, just the answer.
	if clock() < _not_yet_until:
		return
	_not_yet_until = clock() + NOT_YET_EVERY
	sfx("gear_tick", "clink", 1.0, 0.7)
	var c := (bells[i]["box"] as Rect2).get_center()
	pop_word("Not yet!", c + Vector2(0, -30))
	if world != null and world.get("glow") != null:
		world.glow.burst(c, 5, Color(FROST, 0.8), 60.0, 0.3, 0.0, 1.8)


func _ring(i: int) -> void:
	## The lit bell rings: the hour strikes and he falls (only called when
	## he can: can_chime()). It's dead till the hand next comes back to it.
	_rung[i] = true
	_arm[i] = clock() + REARM
	_chime = {"p": (bells[i]["box"] as Rect2).get_center(), "t": 0.0}
	sfx("chime_hour", "bell")
	if world != null and world.get("glow") != null:
		world.glow.burst(_chime["p"], 18, GOLD, 170.0, 0.5, 0.0, 2.6)
	if can_chime():
		_chimed()
		chimes_at.append([i, spring_rect().get_center().x])


func _wrong_hour(i: int) -> void:
	wrong_hours += 1
	_wrong_n += 1
	pop_word("Wrong hour!", (bells[i]["box"] as Rect2).get_center() + Vector2(0, -30))
	sfx("wrong_hour", "clang")
	_frost_until = clock() + WRONG_FROST
	var to := (hand_i + 1 + _wrong_n % 3) % ORDER.size()
	_move_hand(to)
	_prev_until = -1.0
	used("wrong_hour")


func _chimed() -> void:
	## The hour strikes: he falls on his face, the case open on the spring.
	chimed_count += 1
	used("chimed")
	_cancel_move()
	_post = -1                          # up again, he must get back to his post first
	_post_prev = -1
	state = "chimed"
	open_window(float(WINDOW[clampi(phase - 1, 0, 2)]))
	_look_hold = look_face
	look_locked = true
	sfx("tinker_open", "")
	if world != null:
		world.shake = maxf(float(world.shake), 4.0)


func _cancel_move() -> void:
	_swing_t = 0.0
	_placed = HANDS_N
	_ghost_x.clear()


# ---------------------------------------------------------------- his body

func body_rect() -> Rect2:
	var fr := frame_name if frame_name != "" else "tinker_idle"
	return art_box(fr, "body", Rect2(position.x - 50.0, position.y - 160.0, 100.0, 160.0))


func spring_rect() -> Rect2:
	## The window's target: the mainspring on the floor (tinker_chimed).
	return art_box("tinker_chimed", "spring_box", Rect2(position.x + 11.0 * look_face - 19.0, floor_y - 39.0, 38.0, 39.0))


func rect() -> Rect2:
	if not alive:
		return NOWHERE
	if is_open():
		return spring_rect()
	return body_rect()


func hurt_rect() -> Rect2:
	if not alive or state == "sleep":
		return NOWHERE
	if is_open():
		return spring_rect().grow(2.0)
	return body_rect().grow(-4.0)


func center() -> Vector2:
	var r := rect()
	if r == NOWHERE:
		return position + Vector2(0, -80)
	return r.get_center()


func touch_damage() -> bool:
	return alive and not (state in ["sleep", "chimed", "unwound", "getup", "reel", "dead"])


func can_hurt(_h: Dictionary) -> bool:
	return not (state in ["midnight", "roar"])


# ---------------------------------------------------------------- being hit

func on_hurt(_h: Dictionary, _amount: float, _open: bool, frac: float) -> void:
	for k in SOLDIERS_AT:
		if frac <= float(k) + 0.0001 and not _soldiers_done.has(k):
			_soldiers_done.append(k)
			_soldiers_owed += 1


func on_phase(p: int) -> void:
	_cancel_move()
	_end_chimed()
	_queue.clear()
	# A phase's soldiers are its own (spec §4.1 rule 7: adds die at the
	# roar): one owed from the phase just ended (it ended inside a window)
	# is never wound in the next.
	_soldiers_owed = 0
	for k in SOLDIERS_AT:
		if float(k) >= float(PHASES[p - 2]) - 0.0001 and not _soldiers_done.has(k):
			_soldiers_done.append(k)
	if p == 2:
		# The overwind: the pendulum's chain creaks loose.
		state = "roar"
		timer = ROAR
		sfx("tinker_overwind", "boss_roar")
	else:
		_midnight()


func on_stagger() -> void:
	## UNWOUND: he spins dizzily a moment.
	_end_chimed()
	state = "unwound"
	timer = UNWOUND
	if world != null:
		world.banner("UNWOUND!")
	sfx("tinker_overwind", "boss_roar")


func on_death() -> void:
	_end_chimed()
	_shots.clear()
	_icicles.clear()
	_lanes.clear()
	sfx("tinker_die", "boss_die")


func _window_over() -> void:
	if state == "chimed":
		_end_chimed()
		state = "getup"
		timer = GETUP


func _end_chimed() -> void:
	close_window()
	look_locked = false
	if _look_hold != -1:
		facing = _look_hold
	_look_hold = -1


# ---------------------------------------------------------------- the step

func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	# The window's target takes a stomp (the window's first 3x); anything
	# else of his is spikes to land on.
	stompable = is_open()
	if not alive:
		return
	if not _claimed:
		_claim_pendulum()
	var stopped_now: bool = world != null and world.has_method("time_stopped") and world.time_stopped()
	if not stopped_now and state != "stopped" and _frozen_hands():
		_release_hands()   # (Chimed through the stop: the hands still fly)
	# The clock, the pendulum and what he threw run whatever he's doing.
	_step_hand(dt)
	if can_chime() and _post != hand_i and absf(position.x - float(bells[hand_i]["cx"])) <= POST * TILE:
		_post = hand_i
		if bell_lit(hand_i):
			# He's come to guard it: the bell brightens with a small chime (now!).
			if world != null and world.get("glow") != null:
				world.glow.burst((bells[hand_i]["box"] as Rect2).get_center(), 10, GOLD, 110.0, 0.35, 0.0, 2.2)
			sfx("gear_tick", "", 1.0, 0.8)
	_check_bells()
	_step_pendulum(dt)
	_step_shots(dt)
	_step_icicles(dt)
	if not _chime.is_empty():
		_chime["t"] = float(_chime["t"]) + dt
		if float(_chime["t"]) > 0.9:
			_chime = {}
	if state == "chimed" and player != null:
		# Every spring hit is on his back: his facing turned from Wick, his
		# look kept (he lies as he fell).
		facing = -1 if player.position.x > position.x else 1
		look_face = _look_hold if _look_hold != -1 else look_face
	_record(dt)
	_place_props()
	if _hand_node:
		_hand_node.queue_redraw()


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	var dx: float = player.position.x - position.x if player != null else 0.0
	match state:
		"sleep":
			show_frame("tinker_idle")
			if wake_check(player):
				state = "wake"
				timer = ROAR
				sfx("tinker_windup", "boss_roar")
		"wake", "roar":
			show_frame("tinker_overwind")
			if timer <= 0.0:
				if state == "roar" and phase >= 2 and not pend_on:
					_release_pendulum()
				_walk_state()
		"walk":
			_guard(dt)
			_walk_t += dt
			if timer <= 0.0 and (guarding() or _walk_t >= GUARD_WAIT):
				_next(player)
		"toss_tell":
			show_frame("tinker_toss")
			_face(dx)
			if timer <= 0.0:
				_toss(player)
				_walk_state(MOVE_GAP)
		"approach":
			_face(dx)
			var want := player.position.x - look_face * SWING_REACH * 0.8 if player != null else position.x
			_walk_to(want, dt)
			var close := player != null and absf(dx) <= SWING_REACH and absf(player.position.y - floor_y) < 140.0
			if close or timer <= 0.0:
				if close:
					_swing_tell()
				else:
					_walk_state(0.3)
		"swing_tell":
			show_frame("tinker_swing")
			if timer <= 0.0:
				state = "swing"
				_swing_t = SWING_CUT
				_swing_hit = false
				sfx("tinker_throw", "slash")
		"swing":
			show_frame("tinker_swing")
			_swing_t -= dt
			if not _swing_hit:
				var res := strike_arc()
				if res == 3:
					state = "reel"
					timer = REEL
					used("reeled")
					_swing_t = 0.0
				elif res > 0:
					_swing_hit = true
			if state == "swing" and _swing_t <= 0.0:
				_walk_state(MOVE_GAP)
		"watch":
			show_frame("tinker_watch")
			if timer <= 0.0:
				_stop_clock(player)
		"stopped":
			show_frame("tinker_watch")
			_place_hands(dt)
			var stopped: bool = world != null and world.has_method("time_stopped") and world.time_stopped()
			if not stopped or timer <= -0.5:
				_resume()
		"key":
			show_frame("tinker_overwind")
			if timer <= 0.0:
				_soldiers()
				_walk_state(MOVE_GAP)
		"rewind_tell":
			show_frame("tinker_rewind")
			if timer <= 0.0:
				_begin_rewind()
		"rewind":
			show_frame("tinker_rewind")
			var k := clampf(1.0 - timer / REWIND_T, 0.0, 1.0)
			position.x = lerpf(_rew_from, _rew_to, k)
			if timer <= 0.0:
				position.x = _rew_to
				_ghost_x.clear()
				_walk_state(MOVE_GAP)
		"midnight":
			show_frame("tinker_overwind")
			_step_midnight(dt)
			if timer <= 0.0:
				_lanes.clear()
				_walk_state(0.6)
		"chimed":
			show_frame("tinker_chimed")
		"getup", "reel":
			show_frame("tinker_idle")
			if timer <= 0.0:
				_walk_state(0.5)
		"unwound":
			show_frame("tinker_idle")
			if sprite:
				sprite.rotation = sin(t * 18.0) * 0.12
			if timer <= 0.0:
				if sprite:
					sprite.rotation = 0.0
				state = "getup"
				timer = GETUP
	position.x = clampf(position.x, arena_left + 50.0, arena_right - 50.0)
	position.y = floor_y
	mercy_check(player)


func _face(dx: float) -> void:
	if absf(dx) > 6.0:
		facing = 1 if dx > 0.0 else -1


func _walk_state(gap := MOVE_GAP) -> void:
	state = "walk"
	timer = cd(gap)
	_walk_t = 0.0


func _walk_to(x: float, dt: float, speed := WALK) -> void:
	## A step toward x at speed (never into Wick: he stops STOP_GAP px short).
	var before := position.x
	var goal := _short_of_wick(before, clampf(x, arena_left + 50.0, arena_right - 50.0))
	position.x = move_toward(position.x, goal, spd(speed) * dt)
	var moving := absf(position.x - before) > 0.01
	if moving:
		_step_t += dt * speed / WALK    # a hurry is a quicker gait
		show_frame("tinker_walk1" if fmod(_step_t, 0.5) < 0.25 else "tinker_walk2")
		if fmod(_step_t, 0.5) < dt * speed / WALK:
			sfx("tinker_step", "step")
	else:
		show_frame("tinker_idle")


func _short_of_wick(from: float, to: float) -> float:
	## to, cut short where his body would meet Wick's (a Wick his body's
	## height would touch, ahead of him on the way).
	if world == null or world.player == null or not world.player.alive:
		return to
	var pr: Rect2 = world.player.rect()
	var br := body_rect()
	if pr.end.y <= br.position.y or pr.position.y >= br.end.y:
		return to
	var lo := br.position.x - position.x
	var hi := br.end.x - position.x
	if to > from and pr.position.x >= from + hi - 1.0:
		return minf(to, maxf(pr.position.x - STOP_GAP - hi, from))
	if to < from and pr.end.x <= from + lo + 1.0:
		return maxf(to, minf(pr.end.x + STOP_GAP - lo, from))
	return to


func guard_x() -> float:
	## He guards the hour: on the floor under the lit bell, GUARD tiles to one
	## side of it: the wall's side for a bell by a wall (IX and III on their
	## ledges: he'd block the way up from the middle), else the side he's on.
	var b: Dictionary = bells[hand_i]
	var bx := float(b["cx"])
	var side := 1.0 if position.x >= bx else -1.0
	var mid := (arena_left + arena_right) * 0.5
	if absf(bx - mid) > (arena_right - arena_left) * 0.3:
		side = -1.0 if bx < mid else 1.0
	return clampf(bx + side * GUARD * TILE, arena_left + 50.0, arena_right - 50.0)


func _guard(dt: float) -> void:
	## To the guard spot, hurrying while he's far from it, facing his way;
	## there, facing Wick.
	var gx := guard_x()
	var far := absf(position.x - gx) > HURRY_FAR
	_walk_to(gx, dt, HURRY if far else WALK)
	if far and absf(gx - position.x) > 1.0:
		_face(gx - position.x)
	elif world != null and world.player != null:
		_face(world.player.position.x - position.x)


func guarding() -> bool:
	## At his guard spot (or near enough to start a move).
	return absf(position.x - guard_x()) <= GUARD_SETTLE


func _next(player: Node2D) -> void:
	if _soldiers_owed > 0 and adds_alive("tickwind") < SOLDIERS_MAX:
		_soldiers_owed -= 1
		state = "key"
		timer = tell(KEY_TELL)
		sfx("tinker_windup", "")
		used("soldiers")
		return
	var rot: Array = ROT[phase]
	var mv: String = rot[int(_rot[phase]) % rot.size()]
	_rot[phase] = int(_rot[phase]) + 1
	match mv:
		"toss":
			state = "toss_tell"
			timer = tell(TOSS_TELL, TOSS_FLOOR)
			tell_sfx("tinker_windup", timer)
		"swing":
			state = "approach"
			timer = APPROACH
		"stop":
			state = "watch"
			timer = tell(STOP_TELL)
			tell_sfx("tinker_stop", timer)
			used("stop")
		"rewind":
			if _rewind_targets().is_empty() and _hist_x(REWIND_BACK) == INF:
				state = "toss_tell"
				timer = tell(TOSS_TELL, TOSS_FLOOR)
				tell_sfx("tinker_windup", timer)
			else:
				state = "rewind_tell"
				timer = tell(REWIND_TELL)
				# (its reversed tick is A7's to give: clock_tock till then)
				if _has_sound("tinker_rewind"):
					tell_sfx("tinker_rewind", timer)
				else:
					sfx("clock_tock", "clink")
				_mark_rewind(timer)


# ---------------------------------------------------------------- Gear Toss

func _toss(player: Node2D) -> void:
	## 2 cogs (3 from P2) roll along the floor toward Wick, 230 / 260 / 290
	## px/s, each rebounding once.
	var dir := 1.0 if player == null or player.position.x >= position.x else -1.0
	var n := 2 if phase < 2 else 3
	var from_x := position.x + dir * 30.0
	var lob := _lob_target(player)
	for k in n:
		var c := {"kind": "cog", "pos": Vector2(from_x, floor_y - COG_R), "vel": Vector2(dir * float(COG_SPEED[k]), 0.0),
				"t": 0.0, "life": COG_LIFE, "path": [], "rev": false, "hit": false, "rebounds": 1, "thrown": clock(), "spin": 0.0,
				"air": false, "speed": float(COG_SPEED[k])}
		if not lob.is_empty():
			# Lobbed: from his hand onto the far end of Wick's floor, landing
			# LOB_T s later (the spot marked), then rolling at him.
			var from := art_pt("tinker_toss", "hand_l", position + Vector2(-20 * look_face, -110))
			var to: Vector2 = lob["to"]
			var tt := LOB_T + 0.04 * k
			c["pos"] = from
			c["vel"] = Vector2((to.x - from.x) / tt, ((to.y - from.y) - 0.5 * COG_G * tt * tt) / tt)
			c["air"] = true
			c["lob"] = to
			c["roll_dir"] = float(lob["dir"])
			c["life"] = COG_LIFE + tt
		_shots.append(c)
	sfx("tinker_throw", "")
	sfx("gear_roll", "")
	used("toss")
	if not lob.is_empty():
		used("lob")


func _lob_target(player: Node2D) -> Dictionary:
	## A Wick standing on a floor more than LOB_ABOVE px up (the XII beam):
	## {to: where the cogs land (the end of his floor away from him), dir:
	## the way they then roll (at him)}; else {} (they roll on the floor).
	if player == null or level == null or not bool(player.get("on_floor")) or floor_y - float(player.position.y) <= LOB_ABOVE:
		return {}
	var row := floori((float(player.position.y) + 1.0) / TILE)
	var tx := floori(float(player.position.x) / TILE)
	if not LevelData.is_floor(level.tile(tx, row)):
		return {}
	var l := tx
	var r := tx
	while LevelData.is_floor(level.tile(l - 1, row)) and (l - 1) * TILE >= arena_left:
		l -= 1
	while LevelData.is_floor(level.tile(r + 1, row)) and (r + 2) * TILE <= arena_right:
		r += 1
	var x0 := l * TILE + COG_R + 2.0
	var x1 := (r + 1) * TILE - COG_R - 2.0
	var px := float(player.position.x)
	var land_x := x0 if px - x0 >= x1 - px else x1
	return {"to": Vector2(land_x, row * TILE - COG_R), "dir": 1.0 if px >= land_x else -1.0}


# ---------------------------------------------------------------- the Minute Hand

func _swing_tell() -> void:
	state = "swing_tell"
	timer = tell(SWING_TELL, SWING_FLOOR)
	# (Its own sound is A7's to give: gear_catch's brass grind till then,
	# never the Gear Toss's windup.)
	tell_sfx("tinker_minute" if _has_sound("tinker_minute") else "gear_catch", timer)
	used("swing")


func _has_sound(nm: String) -> bool:
	if world == null or not world.has_method("_has_sfx") or not world._has_sfx():
		return false
	var s = world.get_node_or_null("/root/Sfx")
	return s != null and s.get("NAMES") is Array and (s.get("NAMES") as Array).has(nm)


func _chime_note(deg: int) -> void:
	## One hour bell of the death chord: chime_hour at Sfx.note(deg) (A7:
	## chime_hour may play per bell at a note of the key).
	if has_omen("hushed") or not _has_sound("chime_hour"):
		sfx("chime_hour", "bell")
		return
	var s = world.get_node_or_null("/root/Sfx")
	world._sfx("chime_hour", float(s.note(deg)) if s.has_method("note") else 1.0)


func arc_pivot() -> Vector2:
	return position + Vector2(ARC_PIVOT.x * look_face, ARC_PIVOT.y)


func arc_has(p: Vector2) -> bool:
	## Is p inside the Minute Hand's arc (100 px, 150 degrees in front)?
	var c := arc_pivot()
	var d := p - c
	if d.length() > ARC_R:
		return false
	if look_face < 0:
		d.x = -d.x
	var a := rad_to_deg(atan2(d.y, d.x))
	return a >= ARC_FROM and a <= ARC_TO


func blade_angle() -> float:
	## Where the cut's blade is now (degrees, facing right).
	var k := clampf(1.0 - _swing_t / SWING_CUT, 0.0, 1.0)
	return lerpf(ARC_FROM, ARC_TO, k)


func strike_arc() -> int:
	## The cut: the blade from the pivot at its angle now, and everything it
	## has swept since the cut began, against Wick.
	if world == null or world.player == null:
		return 0
	var pr: Rect2 = world.player.rect()
	var hit_it := false
	for q in [pr.position, pr.end, Vector2(pr.position.x, pr.end.y), Vector2(pr.end.x, pr.position.y), pr.get_center()]:
		if arc_has(q):
			var d := (q as Vector2) - arc_pivot()
			if look_face < 0:
				d.x = -d.x
			if rad_to_deg(atan2(d.y, d.x)) <= blade_angle() + 1.0:
				hit_it = true
	if not hit_it:
		return 0
	return strike("minute", pr, position.x, "hit")


# ---------------------------------------------------------------- Stop the Clock

func _stop_clock(player: Node2D) -> void:
	var s = world.get_node_or_null("/root/Sfx") if world != null and world.has_method("_has_sfx") and world._has_sfx() else null
	if s != null and s.has_method("tape_stop"):
		s.tape_stop()
	_taped = true
	_aim = player.center() if player != null else position + Vector2(-100, -30)
	if world != null and world.has_method("stop_time"):
		world.stop_time(STOP_T, self)
	state = "stopped"
	timer = STOP_T
	_placed = 0


func hand_spot(k: int) -> Vector2:
	var a := deg_to_rad(float(HAND_ANGLES[k]))
	return _aim + Vector2(cos(a), sin(a)) * HAND_RING


func _place_hands(_dt: float) -> void:
	## He sets them one by one through the first half of the stop.
	while _placed < HANDS_N and STOP_T - timer >= 0.12 + 0.14 * _placed:
		var p := hand_spot(_placed)
		_placed += 1
		if level != null and LevelData.is_solid(level.tile(floori(p.x / TILE), floori(p.y / TILE))):
			continue
		var d := (_aim - p).normalized()
		_shots.append({"kind": "hand", "pos": p, "vel": Vector2.ZERO, "dir": d, "t": 0.0, "life": 99.0, "path": [], "rev": false,
				"hit": false, "rebounds": 0, "thrown": clock(), "frozen": true, "from": p, "spin": 0.0})
		sfx("clock_tock", "clink")


func _resume() -> void:
	_release_hands()
	_walk_state(MOVE_GAP)


func _release_hands() -> void:
	## Time runs again: the hands fly along their lines.
	var any := false
	for s in _shots:
		if str(s["kind"]) == "hand" and bool(s.get("frozen", false)):
			# It flies its drawn line and stops where the line ends (its tip
			# there): nothing past the line is ever in its way.
			var ln := hand_line(s)
			var reach := maxf((ln[1] as Vector2).distance_to(ln[0]) - HAND_SIZE.x * 0.5, 0.0)
			s["frozen"] = false
			s["vel"] = (s["dir"] as Vector2) * HAND_SPEED
			s["life"] = maxf(reach / HAND_SPEED, 0.02)
			s["thrown"] = clock()
			any = true
	if not any and not _taped:
		return
	_taped = false
	var sx = world.get_node_or_null("/root/Sfx") if world != null and world.has_method("_has_sfx") and world._has_sfx() else null
	if sx != null and sx.has_method("tape_go"):
		sx.tape_go()
	sfx("tinker_go", "")


func _frozen_hands() -> bool:
	for s in _shots:
		if str(s["kind"]) == "hand" and bool(s.get("frozen", false)):
			return true
	return false


func hand_line(s: Dictionary) -> Array:
	## A frozen hand's lead line: from its middle through where Wick stood,
	## on 200 px or to the first stone: its tip stops at the line's end.
	var a: Vector2 = s["pos"]
	var d: Vector2 = s["dir"]
	var n := HAND_RING + 200.0
	if level != null:
		var k := HAND_RING * 0.5
		while k < n:
			var q := a + d * k
			if LevelData.is_solid(level.tile(floori(q.x / TILE), floori(q.y / TILE))):
				n = k
				break
			k += 4.0
	return [a, a + d * n]


func hand_seg(s: Dictionary) -> Array:
	## A hand's blade: HAND_SIZE.x long along its line, centred on it.
	var p: Vector2 = s["pos"]
	var d: Vector2 = s["dir"]
	return [p - d * HAND_SIZE.x * 0.5, p + d * HAND_SIZE.x * 0.5]


func hand_hits(s: Dictionary, r: Rect2) -> bool:
	var sg := hand_seg(s)
	return seg_hits_rect(sg[0], sg[1], HAND_SIZE.y, r)


# ---------------------------------------------------------------- his shots

func _step_shots(dt: float) -> void:
	var stopped: bool = world != null and world.has_method("time_stopped") and world.time_stopped()
	for s in _shots:
		var moving := not stopped and not bool(s.get("frozen", false))
		if moving:
			s["t"] = float(s["t"]) + dt
			if bool(s["rev"]):
				var path: Array = s["path"]
				if path.is_empty():
					s["life"] = 0.0
					continue
				s["pos"] = path.pop_back()
			else:
				(s["path"] as Array).append(s["pos"])
				if (s["path"] as Array).size() > 480:
					(s["path"] as Array).pop_front()
				if str(s["kind"]) == "cog":
					_cog_move(s, dt)
				else:
					s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * dt
				s["life"] = float(s["life"]) - dt
				_bounds(s)
			s["spin"] = float(s["spin"]) + (s["vel"] as Vector2).x * dt / COG_R
		# Frozen or not, it hurts where it is.
		if not bool(s["hit"]) and float(s["life"]) > 0.0:
			var res := 0
			var p: Vector2 = s["pos"]
			var fx := p.x - signf((s["vel"] as Vector2).x if (s["vel"] as Vector2).x != 0.0 else 1.0) * 20.0
			if str(s["kind"]) == "cog":
				# (a lobbed cog is harmless in its arc: it hurts once it's down
				# on its marked spot and rolling, as a seed of hers does)
				if not s.has("lob"):
					res = strike_circle("toss", p, COG_R, fx, {"shot": true, "vel": s["vel"], "pos": p})
			elif world != null and world.player != null and hand_hits(s, world.player.rect()):
				res = strike("hands", world.player.rect(), fx, "hit", {"shot": true, "vel": s["vel"], "pos": p})
			if res > 0:
				s["hit"] = true
	_shots = _shots.filter(func(s): return float(s["life"]) > 0.0)


func _cog_move(s: Dictionary, dt: float) -> void:
	## A cog rolls along its floor and falls off the end of it; one in the
	## air (lobbed, or off a ledge) falls until a floor catches it coming
	## down (one-way ledges too), then rolls on (a lobbed one at Wick).
	var p: Vector2 = s["pos"]
	var v: Vector2 = s["vel"]
	if bool(s.get("air", false)):
		v.y += COG_G * dt
		var np := p + v * dt
		if v.y > 0.0 and level != null:
			var surf := surface_below(np.x, p.y + COG_R - 1.0)
			if np.y + COG_R >= surf:
				np.y = surf - COG_R
				s["air"] = false
				var d := float(s.get("roll_dir", signf(v.x) if v.x != 0.0 else 1.0))
				v = Vector2(d * float(s.get("speed", absf(v.x))), 0.0)
				s.erase("lob")
				s.erase("roll_dir")
				sfx("gear_clunk", "clink")
		s["pos"] = np
		s["vel"] = v
		return
	var nr := p + v * dt
	if level != null and not LevelData.is_floor(level.tile(floori(nr.x / TILE), floori((nr.y + COG_R + 1.0) / TILE))):
		s["air"] = true
	s["pos"] = nr


func _bounds(s: Dictionary) -> void:
	var p: Vector2 = s["pos"]
	var v: Vector2 = s["vel"]
	if str(s["kind"]) == "cog":
		if (v.x < 0.0 and p.x - COG_R <= arena_left) or (v.x > 0.0 and p.x + COG_R >= arena_right):
			if int(s["rebounds"]) > 0:
				s["rebounds"] = int(s["rebounds"]) - 1
				s["vel"] = Vector2(-v.x, v.y)
				sfx("gear_catch", "clink")
			else:
				s["life"] = 0.0
		return
	if p.x < arena_left - 20.0 or p.x > arena_right + 20.0 or p.y < floor_y - 480.0 or p.y > floor_y + 20.0:
		s["life"] = 0.0
	elif level != null and float(s["t"]) > 0.3 and LevelData.is_solid(level.tile(floori(p.x / TILE), floori(p.y / TILE))):
		s["life"] = 0.0


func shots_now() -> Array:
	return _shots


# ---------------------------------------------------------------- Rewind

func _record(dt: float) -> void:
	var stopped: bool = world != null and world.has_method("time_stopped") and world.time_stopped()
	if stopped or state == "rewind":
		return
	_hist.append([clock(), position.x])
	while _hist.size() > 2 and float(_hist[0][0]) < clock() - REWIND_BACK - 1.0:
		_hist.pop_front()
	_tick_t += dt


func _hist_x(back: float) -> float:
	## Where he stood `back` seconds ago (INF if he's no record that old).
	var at := clock() - back
	if _hist.is_empty() or float(_hist[0][0]) > at + 0.05:
		return INF
	for i in range(_hist.size() - 1, -1, -1):
		if float(_hist[i][0]) <= at:
			return float(_hist[i][1])
	return float(_hist[0][1])


func _rewind_targets() -> Array:
	return _shots.filter(func(s): return not bool(s["rev"]) and not bool(s.get("frozen", false)) and clock() - float(s["thrown"]) <= REWIND_BACK + 0.01)


func _mark_rewind(tell_s: float) -> void:
	## At the tell's start: where he'll rewind to (where he stood REWIND_BACK
	## s before the rewind begins; he stands still through the tell), and
	## the afterimages along the way, the last one there.
	var back := maxf(REWIND_BACK - tell_s, 0.0)
	var hx := _hist_x(back)
	_rew_to = hx if hx != INF else position.x
	_ghost_x.clear()
	for k in _ghost_spr.size():
		var gx := _hist_x(back * float(k + 1) / float(_ghost_spr.size()))
		_ghost_x.append(gx if gx != INF else _rew_to)
	if not _ghost_x.is_empty():
		_ghost_x[_ghost_x.size() - 1] = _rew_to


func _begin_rewind() -> void:
	## Back to where he stood 2.0 s ago (marked at the tell); what he threw
	## since flies back.
	used("rewind")
	_rew_from = position.x
	if _ghost_x.is_empty():
		var hx := _hist_x(REWIND_BACK)
		_rew_to = hx if hx != INF else position.x
	for s in _rewind_targets():
		s["rev"] = true
		s["hit"] = false
		s["life"] = 99.0
	state = "rewind"
	timer = REWIND_T
	sfx("clock_tock", "clink")


# ---------------------------------------------------------------- the soldiers

func _soldiers() -> void:
	## Wind the Soldiers: 2 Tickwinds from the hatches (at most 3 alive).
	for i in _hatches.size():
		if adds_alive("tickwind") >= SOLDIERS_MAX:
			break
		var h: Vector2 = _hatches[i]
		spawn_add("tickwind", h, {"facing": 1 if i == 0 else -1})
	sfx("spring_boing", "")


# ---------------------------------------------------------------- the pendulum

func _release_pendulum() -> void:
	pend_on = true
	_pend_t = 0.0
	sfx("pendulum_swing", "")
	used("pendulum")


func pend_angle() -> float:
	if not pend_on:
		return 0.0
	return deg_to_rad(PEND_AMP) * sin(TAU * _pend_t / PEND_PERIOD)


func bob() -> Vector2:
	var a := pend_angle()
	return pivot + Vector2(sin(a), cos(a)) * PEND_ROD


func _step_pendulum(dt: float) -> void:
	if not pend_on:
		return
	var stopped: bool = world != null and world.has_method("time_stopped") and world.time_stopped()
	if stopped:
		strike_circle("pendulum", bob(), PEND_BOB, bob().x, {"feature": "pendulum"})
		return
	var before := pend_angle()
	var p0 := bob()
	_pend_t += dt
	var now := pend_angle()
	if signf(before) != signf(now):
		sfx("pendulum_swing", "")
	var dir := signf(bob().x - p0.x)
	strike_circle("pendulum", bob(), PEND_BOB, bob().x - dir * 20.0, {"feature": "pendulum"})


# ---------------------------------------------------------------- Midnight

func _midnight() -> void:
	## The P3 roar: twelve chimes over 3 s, untouchable; icicles in lanes (3
	## safe lanes drawn); the floor's ice grows; the hand runs backward.
	state = "midnight"
	timer = MIDNIGHT_T
	hand_dir = -1
	_volley = 0
	_chimes_rung = 0
	_lanes = midnight_lanes(_wrong_n + chimed_count)
	sfx("midnight_chimes", "bell")
	used("midnight")
	_grow_ice()


func midnight_lanes(n: int) -> Array:
	## Pattern n's 3 safe lanes, [x0, x1] px (K_ARENA's columns).
	var pat: Array = MIDNIGHT_LANES[n % MIDNIGHT_LANES.size()]
	var c0 := floori(arena_left / TILE) - 2
	var out := []
	for l in pat:
		var x := float((c0 + int(l[0])) * TILE)
		out.append([maxf(x, arena_left), minf(x + int(l[1]) * TILE, arena_right)])
	return out


func icicle_land(x: float) -> float:
	## Where an icicle falling at x dies: the first floor under the roof (a
	## ledge's top, the beam's, else the floor). Its danger is drawn there.
	return surface_below(x, ceiling_at(x, floor_y - 8.0) + 4.0)


func in_lane(x: float) -> bool:
	for l in _lanes:
		if x >= float(l[0]) and x <= float(l[1]):
			return true
	return false


func _step_midnight(_dt: float) -> void:
	var el := MIDNIGHT_T - timer
	while _chimes_rung < 12 and el >= _chimes_rung * (MIDNIGHT_T / 12.0):
		_chimes_rung += 1
		if world != null and world.get("glow") != null:
			world.glow.burst(hub, 6, Color(0.85, 0.92, 1.0, 0.8), 120.0, 0.4, 0.0, 2.0)
	while _volley < VOLLEYS.size() and el >= float(VOLLEYS[_volley]):
		_volley += 1
		var cols := floori((arena_right - arena_left) / TILE)
		for c in cols:
			var x := arena_left + (c + 0.5) * TILE
			if in_lane(x):
				continue
			var top := ceiling_at(x, floor_y - 8.0) + 2.0
			_icicles.append({"x": x + sin(float(c) * 3.7 + _volley) * 4.0, "y": top, "top": top, "vy": 0.0, "t": 0.0,
					"hit": false, "land": icicle_land(x)})
		sfx("icicle_tell", "")


func _step_icicles(dt: float) -> void:
	var stopped: bool = world != null and world.has_method("time_stopped") and world.time_stopped()
	for ic in _icicles:
		if stopped:
			continue
		ic["t"] = float(ic["t"]) + dt
		if float(ic["t"]) < ICICLE_TELL:
			continue
		if float(ic["vy"]) == 0.0:
			sfx("icicle_fall", "")
		ic["vy"] = minf(float(ic["vy"]) + 1800.0 * dt, 1000.0) + (0.001 if float(ic["vy"]) == 0.0 else 0.0)
		ic["y"] = float(ic["y"]) + float(ic["vy"]) * dt
		var box := Rect2(float(ic["x"]) - 5.0, float(ic["y"]) - 18.0, 10.0, 18.0)
		if not bool(ic["hit"]) and strike("midnight", box, float(ic["x"]), "icicle") > 0:
			ic["hit"] = true
		if float(ic["y"]) >= float(ic["land"]):
			ic["dead"] = true
			if world != null and world.get("glow") != null:
				world.glow.burst(Vector2(float(ic["x"]), float(ic["land"])), 5, Color(0.85, 0.95, 1.0, 0.9), 110.0, 0.25, 300.0, 1.8)
	_icicles = _icicles.filter(func(ic): return not ic.get("dead", false))


func icicles() -> Array:
	return _icicles


func _grow_ice() -> void:
	## Each run of floor ice grows a tile at each end (restored on a retry).
	if level == null:
		return
	var row := floori(floor_y / TILE)
	var c0 := floori(arena_left / TILE)
	var c1 := floori((arena_right - 1.0) / TILE)
	var grow := []
	for x in range(c0, c1 + 1):
		if level.tile(x, row) != LevelData.ICE:
			continue
		for dx in [-1, 1]:
			var nx: int = x + dx
			if nx >= c0 and nx <= c1 and level.tile(nx, row) == LevelData.STONE and not grow.has(nx):
				grow.append(nx)
	for nx in grow:
		var c := Vector2i(nx, row)
		level.set_tile(c, LevelData.ICE)
		_ice_cells.append(c)
		if world != null:
			world._redraw_at(nx)


func grown_ice() -> Array:
	return _ice_cells.duplicate()


# ---------------------------------------------------------------- the retry

func _reset_arena(_keep: bool) -> void:
	_end_chimed()
	_shots.clear()
	_icicles.clear()
	_lanes.clear()
	_hist.clear()
	_queue.clear()
	_rot = {1: 0, 2: 0, 3: 0}
	_soldiers_owed = 0
	_soldiers_done.clear()
	_chime = {}
	pend_on = false
	_pend_t = 0.0
	_placed = HANDS_N
	_swing_t = 0.0
	_ghost_x.clear()
	_walk_t = 0.0
	# Time running again: a snuff inside his stop would carry up to 0.1 s of
	# it into the retry. world.stop_time(0, self) cuts his own stop short.
	if world != null and world.has_method("stop_time"):
		world.stop_time(0.0, self)
	if level != null:
		for c in _ice_cells:
			level.restore_tile(c)
			if world != null:
				world._redraw_at(c.x)
	_ice_cells.clear()
	_reset_clock()
	facing = 1
	look_face = 1
	if sprite:
		sprite.rotation = 0.0
	var sx = world.get_node_or_null("/root/Sfx") if world != null and world.has_method("_has_sfx") and world._has_sfx() else null
	if sx != null and sx.has_method("tape_go"):
		sx.tape_go(0.0)
	show_frame("tinker_idle")
	_place_props()


# ---------------------------------------------------------------- dying

func _dying(dt: float) -> void:
	## The frost cracks off the clock and the true hour strikes: all four
	## bells in a chord; the case opens and a tiny old man is left; the bell.
	show_frame("tinker_die")
	if sprite:
		sprite.rotation = 0.0
	_place_props()
	if death_time - dt <= 0.0:
		for i in bells.size():
			_arm[i] = 0.0
	if world != null and world.get("glow") != null and fmod(death_time, 0.2) < dt and death_time < 1.2:
		for b in bells:
			world.glow.burst((b["box"] as Rect2).get_center(), 5, GOLD, 90.0, 0.5, 0.0, 2.2)
	# All four bells in a chord, strummed.
	for k in CHORD.size():
		var at := 0.3 + 0.05 * k
		if death_time > at and death_time - dt <= at:
			_chime_note(int(CHORD[k]))
	if death_time > 1.2 and death_time - dt <= 1.2 and world != null:
		world.boss_defeated(self, Vector2(position.x, floor_y - 40.0))
		var mid := floorf((arena_left + arena_right) * 0.5 / TILE) * TILE + TILE * 0.5
		world.add_bell(Vector2(mid, floor_y))


# ---------------------------------------------------------------- the look

func _place_props() -> void:
	if _clock_spr:
		place_part(_clock_spr, hub, 0.0, 1)
	for i in _bell_spr.size():
		var s: Sprite2D = _bell_spr[i]
		var lit := bell_lit(i) or not alive
		var spent := alive and bell_spent(i)
		var tn := "hour_bell_lit" if lit or spent else "hour_bell_frozen"
		if _tex.has(tn):
			s.texture = _tex[tn]
		# A bell rung this visit: lit, but dim (it won't ring again yet); lit
		# and waiting for him to come and guard it: a little dim.
		s.modulate = Color(0.55, 0.52, 0.48) if spent else (Color(0.66, 0.74, 0.84) if lit and alive and not bell_ready(i) else Color(1, 1, 1))
		var sw := 0.0
		if not _chime.is_empty() and (bells[i]["box"] as Rect2).get_center().distance_to(_chime["p"]) < 2.0:
			sw = sin(float(_chime["t"]) * 30.0) * 12.0 * (1.0 - float(_chime["t"]) / 0.9)
		place_part(s, bells[i]["mouth"], sw, 1)
		s.visible = s.texture != null
	var frozen: bool = world != null and world.has_method("time_stopped") and world.time_stopped()
	var ci := 0
	var hi := 0
	for sh in _shots:
		if str(sh["kind"]) == "cog" and ci < _cog_spr.size():
			var s: Sprite2D = _cog_spr[ci]
			ci += 1
			place_part(s, sh["pos"], rad_to_deg(float(sh["spin"])), 1)
			s.modulate = Color(0.7, 0.72, 0.78) if frozen else Color(1, 1, 1)
		elif str(sh["kind"]) == "hand" and hi < _hand_spr.size():
			var s2: Sprite2D = _hand_spr[hi]
			hi += 1
			var d: Vector2 = sh["dir"]
			var p: Vector2 = sh["pos"]
			if bool(sh.get("frozen", false)) and state == "stopped" and timer <= TREMBLE:
				p += Vector2(sin(t * 70.0 + hi), cos(t * 63.0 + hi)) * 1.5
			# The sprite's hub at the hand's back, its tip ahead along the line.
			place_part(s2, p - d * HAND_SIZE.x * 0.5, rad_to_deg(d.angle()), 1)
			s2.modulate = Color(0.75, 0.78, 0.85) if frozen else Color(1, 1, 1)
	for k in range(ci, _cog_spr.size()):
		_cog_spr[k].visible = false
	for k in range(hi, _hand_spr.size()):
		_hand_spr[k].visible = false
	for i in _hatch_spr.size():
		place_part(_hatch_spr[i], _hatches[i], 0.0, 1)
		_hatch_spr[i].visible = _hatch_spr[i].texture != null
	# Rewind's afterimages along the path he'll run back, the last (the
	# boldest) where he'll stop.
	for i in _ghost_spr.size():
		var g: Sprite2D = _ghost_spr[i]
		g.visible = state in ["rewind_tell", "rewind"] and sprite != null and sprite.texture != null and i < _ghost_x.size()
		if g.visible:
			var hx := float(_ghost_x[i])
			if state == "rewind" and absf(hx - _rew_from) > 1.0 and absf(position.x - _rew_from) >= absf(hx - _rew_from):
				g.visible = false               # he has run back past it
				continue
			g.texture = sprite.texture
			g.position = Vector2(hx - position.x, 0.0)
			g.scale = Vector2(TEX_SCALE * (1.0 if look_face > 0 else -1.0), TEX_SCALE)
			g.modulate = Color(0.7, 0.85, 1.0, 0.2 + 0.1 * i)


func eye_points() -> Array:
	if not alive or state == "sleep":
		return []
	var fr := frame_name if frame_name != "" else "tinker_idle"
	return [art_pt(fr, "eye_l", position + Vector2(3 * look_face, -144)), art_pt(fr, "eye_r", position + Vector2(16 * look_face, -144))]


func lights() -> Array:
	## At most 18 (spec §5.3): the lit bell (r 60), the pendulum (r 90), the
	## spring while Chimed (r 50), the frozen hands (r 16), his lenses (r 12).
	var out := []
	if not alive:
		return out
	for i in bells.size():
		if bell_lit(i):
			var ready := bell_ready(i)
			out.append(glow_light((bells[i]["box"] as Rect2).get_center(), 60.0 if ready else 40.0, 0.8 if ready else 0.45, "tell", Color(GOLD, 0.45)))
	if pend_on:
		out.append(glow_light(bob(), PEND_LIGHT, 0.7, "tell", Color(FROST, 0.3)))
	if is_open():
		out.append(glow_light(spring_rect().get_center(), 50.0, 0.9, "tell", Color(GOLD, 0.5)))
	var nh := 0
	for s in _shots:
		if str(s["kind"]) == "hand" and nh < HANDS_N:
			out.append(glow_light(s["pos"], 16.0, 0.6, "tell"))
			nh += 1
	for p in eye_points():
		out.append(glow_light(p, 12.0, 0.4, "eye", Color(LENS, 0.5)))
	return out


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive or world == null:
		return
	var tb := gtb()
	# The clock's hand is drawn on the face (behind the tiles: _draw_hand);
	# above the dark only its tip glints, so it reads without covering him.
	var ang := hand_now()
	var dirv := Vector2(cos(ang), sin(ang))
	tb.circle(hub + dirv * HAND_LEN, 5.0, Color(GOLD, 0.35), 12)
	tb.circle(hub + dirv * HAND_LEN, 2.5, Color(1.0, 0.95, 0.8, 0.95), 10)
	# The lit bell out of the camera's reach (XII, from the floor): a marker.
	if alive and state != "sleep" and bell_lit(hand_i):
		edge_marker(tb, (bells[hand_i]["box"] as Rect2).get_center(), GOLD)
	# The bells: the lit one's gold ring (pulsing on the hand's clock); the
	# frosted ones a cold rim.
	for i in bells.size():
		var r: Rect2 = bells[i]["box"]
		var c := r.get_center()
		if bell_lit(i):
			# (fainter till he's come to guard it, and while he's down or
			# getting up: ringing it then does nothing)
			var ready := bell_ready(i)
			var ka := 1.0 if ready else 0.4
			var left := clampf((_hand_at - clock()) / maxf(period(), 0.01), 0.0, 1.0) if i == hand_i else 0.0
			if ready:
				tb.ring(c, 20.0 + 2.0 * sin(t * 6.0), 2.5, Color(GOLD, 0.85 * ka), 22)
			else:
				# Not yet (he hasn't come to guard it, or he's down): a still,
				# thin gold ring inside a frost rim, no pulse.
				tb.ring(c, 18.0, 1.5, Color(GOLD, 0.45), 22)
				tb.ring(c, 23.0, 2.0, Color(FROST, 0.55), 24)
			if i == hand_i:
				tb.ring(c, 26.0 if ready else 28.0, 2.0, Color(1.0, 0.95, 0.75, 0.55 * ka), 24, -PI * 0.5, -PI * 0.5 + TAU * left)
		elif bell_spent(i):
			tb.ring(c, 17.0, 1.5, Color(GOLD, 0.22), 18)
		else:
			tb.ring(c, 17.0, 1.5, Color(FROST, 0.35), 18)
	# The hour's gold ring sweeping the arena.
	if not _chime.is_empty():
		var k := float(_chime["t"]) / 0.9
		tb.ring(_chime["p"], 20.0 + 520.0 * k, 4.0, Color(GOLD, 0.7 * (1.0 - k)), 48)
	# The pendulum: its arc dashed at 0.20 (readability), the bob's glint.
	var b := bob()
	if pend_on or state in ["roar"]:
		for k in 15:
			var a := lerpf(-deg_to_rad(PEND_AMP), deg_to_rad(PEND_AMP), k / 14.0)
			var q := pivot + Vector2(sin(a), cos(a)) * PEND_ROD
			var tang := Vector2(cos(a), -sin(a)) * 3.5   # frost dashes along the arc (World 4's weights draw theirs so)
			tb.line(q - tang, q + tang, 2.0, Color(FROST, 0.20))
	tb.circle(b, 3.0, Color(0.85, 0.95, 1.0, 0.9 if pend_on else 0.5), 10)
	# Gear Toss: the cogs glint at his hand.
	if state == "toss_tell":
		var hp := art_pt("tinker_toss", "hand_l", position + Vector2(-20 * look_face, -110))
		var kk := 1.0 - clampf(timer / maxf(tell(TOSS_TELL, TOSS_FLOOR), 0.01), 0.0, 1.0)
		tb.rect(Rect2(hp + Vector2(-5 - 5 * kk, -1), Vector2(10 + 10 * kk, 2)), Color(1, 1, 0.9, 0.9))
		tb.rect(Rect2(hp + Vector2(-1, -5 - 5 * kk), Vector2(2, 10 + 10 * kk)), Color(1, 1, 0.9, 0.9))
		tb.ring(hp, 8.0 + 4.0 * kk, 1.5, Color(GOLD, 0.6), 14)
		var lt := _lob_target(world.player)
		if not lt.is_empty():
			_lob_mark(tb, lt["to"], kk)
	# A lobbed cog's landing, marked on the floor it's coming down onto.
	for s in _shots:
		if str(s["kind"]) == "cog" and s.has("lob"):
			_lob_mark(tb, s["lob"], 1.0)
	# The Minute Hand's pale arc, drawn in front through its tell.
	if state == "swing_tell" or state == "swing":
		var c2 := arc_pivot()
		var k2 := 1.0 - clampf(timer / maxf(tell(SWING_TELL, SWING_FLOOR), 0.01), 0.0, 1.0) if state == "swing_tell" else 1.0
		var a0 := deg_to_rad(ARC_FROM)
		var a1 := deg_to_rad(ARC_TO)
		var pts := PackedVector2Array()
		var n := 18
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			pts.append(c2 + Vector2(cos(a) * look_face, sin(a)) * ARC_R)
		tb.fan(c2, pts, Color(0.92, 0.95, 1.0, 0.10 + 0.08 * k2), false)
		tb.polyline(pts, 2.5, Color(0.92, 0.95, 1.0, 0.45 + 0.45 * k2))
		tb.line(c2, pts[0], 1.5, Color(0.92, 0.95, 1.0, 0.35))
		tb.line(c2, pts[n], 1.5, Color(0.92, 0.95, 1.0, 0.35))
		if state == "swing":
			var ba := deg_to_rad(blade_angle())
			tb.line(c2, c2 + Vector2(cos(ba) * look_face, sin(ba)) * ARC_R, 5.0, Color(1, 1, 1, 0.9))
	# Stop the Clock: a pale vignette closing from the view's edges; each
	# frozen hand's lead line, trembling before time runs.
	var vig := 0.0
	if state == "watch":
		vig = 1.0 - clampf(timer / maxf(tell(STOP_TELL), 0.01), 0.0, 1.0)
	elif state == "stopped":
		vig = 1.0
	if vig > 0.0:
		var v: Rect2 = world.view_rect()
		var w := 40.0 * vig
		var col := Color(0.85, 0.9, 1.0, 0.16 * vig)
		tb.rect(Rect2(v.position, Vector2(v.size.x, w)), col)
		tb.rect(Rect2(Vector2(v.position.x, v.end.y - w), Vector2(v.size.x, w)), col)
		tb.rect(Rect2(v.position + Vector2(0, w), Vector2(w, v.size.y - 2.0 * w)), col)
		tb.rect(Rect2(Vector2(v.end.x - w, v.position.y + w), Vector2(w, v.size.y - 2.0 * w)), col)
		tb.rect(Rect2(v.position, Vector2(v.size.x, 3)), Color(0.9, 0.95, 1.0, 0.4 * vig))
		tb.rect(Rect2(Vector2(v.position.x, v.end.y - 3), Vector2(v.size.x, 3)), Color(0.9, 0.95, 1.0, 0.4 * vig))
	for s in _shots:
		if str(s["kind"]) == "hand" and bool(s.get("frozen", false)):
			# From the blade's tip to where the tip will stop, with a stop mark.
			var ln := hand_line(s)
			var tr := timer <= TREMBLE and state == "stopped"
			var dv: Vector2 = s["dir"]
			var a2: Vector2 = (ln[0] as Vector2) + dv * HAND_SIZE.x * 0.5
			var lc := Color(1.0, 0.9, 0.7, 0.8 if tr else 0.5)
			dash_line(tb, a2, ln[1], 1.5, lc, 8.0, 6.0)
			var o := dv.orthogonal()
			tb.line((ln[1] as Vector2) - o * 5.0, (ln[1] as Vector2) + o * 5.0, 2.0, lc)
	# The soldiers' key set in the floor.
	if state == "key":
		var kp := Vector2(position.x + 34.0 * look_face, floor_y)
		tb.rect(Rect2(kp + Vector2(-2, -28), Vector2(4, 28)), Color(GOLD, 0.9))
		tb.ring(kp + Vector2(0, -34), 7.0, 2.5, Color(GOLD, 0.9), 14, 0.0, TAU)
		for h in _hatches:
			tb.rect(Rect2((h as Vector2) + Vector2(-16, -3), Vector2(32, 3)), Color(1.0, 0.75, 0.4, 0.5 + 0.4 * sin(t * 12.0)))
	# Midnight: the safe lanes; frost creeping over every other column where
	# its icicles will die (a ledge's top, the beam's, else the floor: the
	# floor under a ledge is sheltered and stays unmarked); each icicle's
	# shadow.
	if not _lanes.is_empty():
		var cols := floori((arena_right - arena_left) / TILE)
		for c in cols:
			var cx := arena_left + (c + 0.5) * TILE
			if in_lane(cx):
				continue
			tb.rect(Rect2(arena_left + c * TILE, icicle_land(cx) - 4.0, TILE, 4.0), Color(0.8, 0.93, 1.0, 0.7))
		for l in _lanes:
			var lr := Rect2(float(l[0]), floor_y - 5.0, float(l[1]) - float(l[0]), 5.0)
			tb.rect(lr, Color(1.0, 0.95, 0.7, 0.85))
			tb.rect(Rect2(lr.position.x, floor_y - 70.0, lr.size.x, 65.0), Color(1.0, 0.95, 0.7, 0.10))
			tb.rect(Rect2(lr.position.x, floor_y - 70.0, 2.0, 70.0), Color(1.0, 0.95, 0.7, 0.4))
			tb.rect(Rect2(lr.end.x - 2.0, floor_y - 70.0, 2.0, 70.0), Color(1.0, 0.95, 0.7, 0.4))
	for ic in _icicles:
		var land := Vector2(float(ic["x"]), float(ic["land"]))
		var k3 := clampf(float(ic["t"]) / ICICLE_TELL, 0.0, 1.0)
		if float(ic["t"]) < ICICLE_TELL + 0.4:
			tb.ellipse(land + Vector2(0, -2), 5.0 + 6.0 * k3, 2.0 + 1.5 * k3, Color(0, 0, 0, 0.4 + 0.3 * k3), 12)
			tb.ring(land + Vector2(0, -2), 18.0 - 8.0 * k3, 1.5, Color(0.85, 0.95, 1.0, 0.3 + 0.6 * k3), 14)
		if float(ic["t"]) < ICICLE_TELL:
			var tp := Vector2(float(ic["x"]), float(ic["top"]))
			tb.rect(Rect2(tp + Vector2(-1.5, 0), Vector2(3, 5 + 8 * k3)), Color(0.9, 0.97, 1.0, 0.6 + 0.4 * k3))
	# UNWOUND's dizzy stars.
	if state == "unwound":
		var top := position + Vector2(0, -170)
		for i in 3:
			var a := t * 6.0 + i * TAU / 3.0
			var q := top + Vector2(cos(a) * 20.0, sin(a) * 6.0)
			tb.rect(Rect2(q - Vector2(3, 1), Vector2(6, 2)), Color(1, 0.95, 0.6, 0.95))
			tb.rect(Rect2(q - Vector2(1, 3), Vector2(2, 6)), Color(1, 0.95, 0.6, 0.95))
	# The spring's gold while he's open.
	if is_open():
		var sr := spring_rect()
		tb.ring(sr.get_center(), 16.0 + 2.0 * sin(t * 12.0), 2.0, Color(GOLD, 0.8), 18)
		if window_len > 0.0:
			tb.ring(sr.get_center(), 23.0, 2.5, Color(1.0, 0.95, 0.75, 0.8), 24, -PI * 0.5, -PI * 0.5 + TAU * window_t / window_len)
	glow_eyes(tb, eye_points(), LENS, 3.0)
	tb.flush(glow)


func _lob_mark(tb: RefCounted, to: Vector2, k: float) -> void:
	## Where a lobbed cog lands: a gold ring closing on the floor, a glint.
	var at := to + Vector2(0, COG_R)
	tb.ring(at + Vector2(0, -2), 22.0 - 8.0 * k, 2.0, Color(GOLD, 0.45 + 0.45 * k), 16)
	tb.ellipse(at + Vector2(0, -2), 9.0 + 4.0 * k, 2.5, Color(0, 0, 0, 0.45), 12)
	tb.rect(Rect2(at + Vector2(-1, -12), Vector2(2, 8)), Color(1.0, 0.95, 0.75, 0.9))


func _draw_hand() -> void:
	## The clock's one hand on its face (behind the tiles), from the hub to
	## the hour; the tock's jump.
	if _htb == null:
		_htb = ELITE_TB.new()
	var h := hub - position
	var ang := hand_now()
	var d := Vector2(cos(ang), sin(ang))
	var o := d.orthogonal()
	_htb.convex(PackedVector2Array([h - d * 14.0 + o * 5.0, h + d * (HAND_LEN - 12.0) + o * 3.0, h + d * HAND_LEN,
			h + d * (HAND_LEN - 12.0) - o * 3.0, h - d * 14.0 - o * 5.0]), Color("2a2430"))
	_htb.convex(PackedVector2Array([h - d * 12.0 + o * 3.0, h + d * (HAND_LEN - 14.0) + o * 1.6, h + d * (HAND_LEN - 3.0),
			h + d * (HAND_LEN - 14.0) - o * 1.6, h - d * 12.0 - o * 3.0]), Color(0.93, 0.86, 0.66))
	_htb.circle(h, 8.0, Color("2a2430"), 14)
	_htb.circle(h, 5.5, BRASS.lightened(0.2), 12)
	_htb.flush(_hand_node)


func _draw() -> void:
	## The pendulum (his own: rod and bob) and the icicles, in his canvas
	## item (TriBatch); the stand-in body when there are no frames.
	var tb := btb()
	var b := bob() - position
	var pv := pivot - position
	tb.line(pv, b, 3.0, Color("3a3f4c"))
	tb.line(pv, b, 1.5, Color("8a8f9c"))
	tb.rect(Rect2(pv - Vector2(6, 2), Vector2(12, 5)), Color("4a4e5c"))
	tb.circle(b, PEND_BOB + 2.0, Color("1c1830"), 16)
	tb.circle(b, PEND_BOB, BRASS, 16)
	tb.circle(b + Vector2(-3, -3), PEND_BOB * 0.4, BRASS.lightened(0.4), 10)
	for ic in _icicles:
		var p := Vector2(float(ic["x"]), float(ic["y"])) - position
		tb.tri(p + Vector2(-5, -18), p + Vector2(5, -18), p, Color(0.85, 0.95, 1.0, 0.95))
		tb.tri(p + Vector2(-2, -18), p + Vector2(1, -18), p + Vector2(-0.5, -4), Color(1, 1, 1, 0.9))
	if frames.is_empty():
		var r := body_rect()
		r.position -= position
		cel_poly(tb, PackedVector2Array([r.position + Vector2(8, 0), Vector2(r.end.x - 8, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), BRASS)
		cel_circle(tb, r.get_center() + Vector2(0, -10), 26.0, Color("dfe8f0"))
		cel_eyes(tb, [r.position + Vector2(r.size.x * 0.4, 18), r.position + Vector2(r.size.x * 0.6, 18)], 3.0, LENS)
	tb.flush(self)
