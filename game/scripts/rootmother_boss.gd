extends "res://scripts/boss_rig.gd"
## Mother Gravebough, the Bone Gardener (World 3's boss, `boss: rootmother`;
## spec §5.2, decisions "Gravebough", A4's points_rootmother.json).
##
## A colossal hunched mother-tree rooted into the right quarter of her arena
## (R_ARENA), at 1:1, her anchor 48 px past the right wall's face, facing
## left. The rule: follow the heart. Each cycle her heart runs out along her
## roots and blooms at a socket, the only place she can be hurt in full.
##
##   Heart Run   her chest goes dark (rootmother_hollow), a heartbeat; the
##               target socket's bud blushes amber at once; a pulse (a light,
##               r 40) races along the root-veins under the floor, up to a
##               ledge or up a vine, at PULSE_SPEED (at least PULSE_MIN s);
##               the bud swells SWELL s, then opens: the window, WINDOW by
##               phase (Tollbreaker +0.4); the blossom box 28 x 28 is her
##               rect() then (the window's first stomp 3x, boss_rig's rule);
##               it closes CLOSE s, the pulse runs
##               home in HOME s while she fights on. The socket: the nearest
##               to Wick at least 3 tiles from him, never the last, the vine
##               sockets skipped for her first two runs.
##   P2+ decoy   a second blossom, pale violet, unlit, breathing: struck, it
##               bursts into spores (r 72, 4 s) with a puff (20 within 40 px)
##               and the true one closes 0.5 s early.
##   P3          before the run she breathes spores over the target (the
##               true blossom is a light, r 70, so it still shows).
##   In a window P1 nothing; P2 one Seedfall; P3 one Root Spear under Wick.
##
## Moves (tells Dusk, floor): Bough Sweep low (0.75, 0.50: the arm from her
## hip; the band at the floor filled at 0.2 with a dashed edge; the lash
## runs to the far wall at 560 px/s: jump it), high (P2+, the arm overhead;
## the band over a standing Wick: stay down), Double Sweep (P3, both bands,
## the first numbered 1), Root Spear (0.60, 0.45: x locked at the tell's
## start; a 26 x 64 pillar that hurts on its 0.15 s rise and stands 1.5 s
## with a one-way ledge on top; under a Wick on a vine it bursts up the vine
## from just under his feet, features.vine_lane's run, with no ledge), Spear
## March (P2 3, P3 5, 0.3 s apart, from her toward Wick, the last under him
## as a Root Spear is), Seedfall (P1-P2: the crown shakes 0.5 s, 3 seeds arc
## down over 0.7 s onto their shadows and hurt only as they land there;
## each hatches a Rootling after 1.5 s unless hit; at most 3 Rootlings),
## Spore Breath (P2+: 0.8 s, 3 clouds; fire clears them and a whoomph that
## reaches the open blossom is a Flashbloom, 0.6x basic in full), Thorn
## Crown (P3: 0.8 s, 4 safe lanes 3 tiles wide, two patterns in turn; thorns
## rain 1.2 s on every other column, both vines and both humps among them,
## and die on the first floor they meet: the danger is drawn there), and
## her trunk's touch. The humps are cover from the Bough Sweeps (the bands
## keep to the floor, as the ledges are safe) and from nothing else.
## Pacing: P1 two moves then a Heart Run; P2 two then a run with a decoy;
## P3 three then a run with spores first. The roars: P2 kills the Rootlings
## and sinks the pillars; P3 tears her roots out (she rises 32 px on
## rootmother_legs) and two root humps come up at x 12 and 23 (solid).
## A Knight's Perfect Guard on the bough catches it: she reels 1.0 s.
## Retry: the heart home, blossoms shut, Rootlings, pillars, seeds, thorns
## and clouds gone, the humps out, rooted again, the door open.
##
## Numbers (spec §5.1): BASE_HP 480 (the reference knight needs 5-6
## windows: tests/test_bosses3.gd), the sweep 38 (27% of the arrival
## knight), touch 26. Sounds through tell_sfx at each tell's start (A7).

const FRAME_FEET := Vector2(192, 368)
const POINTS_PATH := "res://art/enemies/points_rootmother.json"
const FRAMES := ["rootmother_idle", "rootmother_dig", "rootmother_sweep_high", "rootmother_sweep_low",
		"rootmother_breath", "rootmother_hollow", "rootmother_hurt", "rootmother_wilt", "rootmother_bare", "rootmother_die"]
const MOVES := {"sweep_low": 38.0, "sweep_high": 38.0, "spear": 34.0, "seed": 16.0, "thorns": 24.0, "puff": 20.0}
const TOUCH := 26.0
const BASE_HP := 480.0
const RUSH_K := 0.9
const WINDOW := [2.6, 2.2, 1.9]
const WALL_GAP := 48.0              # her anchor past the right wall's face (A4's _placement)
const SWEEP_TELL := 0.75
const SWEEP_FLOOR := 0.50
const SWEEP_SPEED := 560.0
const RETRACT_SPEED := 1400.0
const FRONT_W := 64.0               # the lash's hurting head
const BAND := {"low": [15.0, 28.0], "high": [86.0, 16.0]}   # centre px over the floor, height (A4)
# The Double Sweep's second lash, 0.7 s after the first either way round
# (tests: one full held jump over the low lash is down before the high one).
const DOUBLE_GAP := 0.7
const SPEAR_TELL := 0.60
const SPEAR_FLOOR := 0.45
const SPEAR_RISE := 0.15
const SPEAR_STAND := 1.5
const SPEAR_SINK := 0.25
const SPEAR_W := 26.0
const SPEAR_H := 64.0
const VINE_SPEAR_BELOW := 8.0       # a vine spear's root, this far under a climbing Wick's feet
const MARCH_GAP := 0.3
const MARCH_N := [3, 3, 5]
const MARCH_STEP := 72.0            # px between the march's spears at least
const SEED_SHAKE := 0.5
const SEED_FALL := 0.7
const SEED_HATCH := 1.5
const SEED_SPREAD := 96.0
const SEED_R := 9.0
const SEED_LAND := Vector2(26, 22)  # where a seed hurts: its shadow's width, a seed's height over it
const ROOTLINGS_MAX := 3
const BREATH_TELL := 0.8
const CLOUD_R := 64.0
const CLOUD_LIFE := 6.0
const DECOY_R := 72.0
const DECOY_LIFE := 4.0
const PUFF_R := 40.0
const PUFF_T := 0.2
const DECOY_CUT := 0.5
const THORN_TELL := 0.8
# Its escape formula (spec §4.1), counting the thorns' fall: they start
# under the roof at 240 px/s, gaining 1600 px/s2, so none reaches a standing
# head on R_ARENA's floor until THORN_FALL s after the tell. The worst spot
# is the trunk end of the 5-tile gap by her (Wick at the wall, 150 px from a
# lane's edge): 0.35 + 160 / 205 = 1.13 s <= tell + 0.49. The floor keeps
# that on Witching (0.72 x 0.8 = 0.58 alone would give 1.07); tests check
# every standable spot of the arena, ledges and humps too.
const THORN_FLOOR := 0.72
const THORN_RAIN := 1.2
const THORN_EVERY := 0.3
const THORN_V0 := 240.0
const THORN_G := 1600.0
const LANE_TILES := 3
# The 4 safe lanes' left columns (R_ARENA's; each 3 wide), taken in turn by
# Thorn Crown: every gap between them rains on both vines (cols 5 and 25)
# and both P3 humps (12-13, 23-24); the gaps run 0 | 2-4 | 2-4 | 2-4 | 5.
const LANES := [[2, 7, 14, 20], [2, 9, 15, 20]]
const PULSE_SPEED := 320.0
const PULSE_MIN := 1.0
const SWELL := 0.4
const CLOSE := 0.3
const HOME := 1.0
const SOCKET_MIN := 96.0            # 3 tiles
const VINE_AFTER := 2               # vine sockets only from the third Heart Run
const RISE_P3 := 32.0
const HUMPS := [12, 23]             # arena columns (2 cells each)
const FLASH_COEF := 0.6
const FIRE_REACH := 24.0
const MOVE_GAP := 0.9
const REEL := 1.0                   # a Perfect Guard on the bough, and the WILTED stagger
const BEAT := 0.5                   # the heartbeat while the heart is out
const ROT := {1: ["sweep_low", "spear", "seed"],
		2: ["sweep_high", "march", "seed", "sweep_low", "breath", "march"],
		3: ["double", "march", "thorns", "sweep_low", "spear", "sweep_high"]}
const PER_CYCLE := {1: 2, 2: 2, 3: 3}
# The spec's sockets (R_ARENA columns and rows), used when the arena has no
# six anchors: F1, F2 on the floor, L1, L2 on ledges, V1, V2 by the vines.
const SPEC_SOCKETS := [[8, 12, "F1"], [20, 12, "F2"], [9, 9, "L1"], [16, 6, "L2"], [3, 3, "V1"], [26, 6, "V2"]]
const AMBER := Color(1.0, 0.72, 0.42)
const DECOY_TINT := Color(0.82, 0.74, 1.0)
const HEART := Color("a8d0ff")
const EYE := Color("d8f0c0")
const VEIN := Color(1.0, 0.78, 0.45)
static var _points := {}

var sockets: Array = []             # {cell, name, vine, center, box, base, lane_x}
var runs := 0                       # Heart Runs begun
var last_socket := -1
var target := -1                    # the true socket of this run (-1: none)
var decoy := -1
var _stage := ""                    # the run: "" | blush | pulse | swell | open | close
var _stage_t := 0.0
var _decoy_state := ""              # "" | swell | open | burst
var _decoy_t := 0.0
var _queue: Array = []              # this cycle's moves, then "heart"
var _rot := {1: 0, 2: 0, 3: 0}
var _pulse := {}                    # {path, lens, len, s, speed, out, t}
var _bands: Array = []              # {kind, n, wait, front, x0, dir, done, hit, retract}
var _spears: Array = []             # {x, surf, t, tell, stage, ledge, n}
var _seeds: Array = []              # {from, to, t, stage, spr}
var _seed_shake := 0.0
var _seed_owed := false
var _seed_n := 0
var _thorns: Array = []             # {x, y, vy}
var _lanes: Array = []              # [x0, x1] px, the safe lanes
var _thorn_t := -1.0                # seconds into the rain (-1: none)
var _thorn_n := 0
var thorn_crowns := 0               # Thorn Crowns cast (the lanes' pattern turns with it)
var _clouds: Array = []             # {p, r, t, life, burnt, decoy}
var _puff := {}                     # {p, t, hit}
var _humps_up := false
var _hump_cells: Array[Vector2i] = []
var _hump_at: Array[Vector2i] = []     # each hump's left cell
var _rise := 0.0
var _beat_t := 0.0
var _reel_t := 0.0
var _cast := 0                      # moves cast (patterns turn with it)
var _crown_jit := 0.0
var _flashbloom := false            # a Flashbloom is landing (hit() takes it in full)
var flashblooms := 0                # (tests)
var decoys_burst := 0               # (tests)
var _bough: Array[Sprite2D] = []
var _legs: Sprite2D = null
var _bud_spr: Array[Sprite2D] = []
var _spear_spr: Array[Sprite2D] = []
var _hump_spr: Array[Sprite2D] = []
var _seed_spr: Array[Sprite2D] = []
var _thorn_spr: Array[Sprite2D] = []
var _tex := {}


func _init() -> void:
	super()
	boss_id = "rootmother"
	boss_name = "Mother Gravebough"
	boss_title = "The Bone Gardener"
	xp_kind = "rootmother"
	size = Vector2(100, 160)
	base_hp = BASE_HP
	base_dmg = TOUCH
	embers = 60
	anchor = FRAME_FEET


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("rootmother_idle")
	# Rooted past the wall's face (A4's _placement: 48 px), facing left.
	if arena_right > arena_left:
		position.x = arena_right + WALL_GAP
		home = position
	facing = -1
	look_face = -1
	for n in ["bloom_bud", "bloom_open", "bloom_decoy", "root_spear", "root_hump", "skull_seed", "thorn"]:
		var p := "res://art/enemies/%s.svg" % n
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	_legs = add_part("rootmother_legs", Vector2(192, 112), true)
	_build_sockets()
	for i in 16:
		var part := 1 if i == 0 else (3 if i == 15 else 2)
		_bough.append(add_part("rootmother_bough%d" % part, Vector2(40, 48)))
	for s in sockets:
		var b := add_part("bloom_bud", Vector2(32, 62))
		_bud_spr.append(b)
	for i in 5:
		_spear_spr.append(add_part("root_spear", Vector2(32, 128)))
	for i in 2:
		_hump_spr.append(add_part("root_hump", Vector2(64, 64)))
	for i in 3:
		_seed_spr.append(add_part("skull_seed", Vector2(32, 38)))
	for i in 28:
		_thorn_spr.append(add_part("thorn", Vector2(32, 30)))
	_show_buds()


static func points() -> Dictionary:
	if _points.is_empty():
		var text := FileAccess.get_file_as_string(POINTS_PATH) if FileAccess.file_exists(POINTS_PATH) else ""
		var d = JSON.parse_string(text) if text != "" else null
		_points = d if d is Dictionary else {"_missing": true}
	return _points


func art_pt(frame: String, key: String, fallback: Vector2) -> Vector2:
	## A point of the frame (A4's points) in the world, or fallback.
	var f = points().get(frame, {})
	if frames.is_empty() or not (f is Dictionary) or not (f as Dictionary).has(key):
		return fallback
	var q: Array = f[key]
	return frame_point(Vector2(float(q[0]), float(q[1])))


# ---------------------------------------------------------------- the sockets

func _build_sockets() -> void:
	## The six bloom sockets: the arena's anchors (sorted by x, y), else the
	## spec's places. A socket by a vine (a vine cell within 2 columns on its
	## row or the next) is a vine socket, V1 and V2 left to right; one over
	## the arena's floor row is F1, F2; the rest (on ledges) L1, L2.
	sockets.clear()
	var cells: Array = anchors.duplicate()
	if cells.size() != 6 and level != null:
		cells.clear()
		var c0 := floori(arena_left / TILE) - 2
		var r0 := floori(floor_y / TILE) - 13
		for s in SPEC_SOCKETS:
			cells.append(Vector2i(c0 + int(s[0]), r0 + int(s[1])))
	var floor_row := floori(floor_y / TILE) - 1
	var nv := 0
	var nf := 0
	var nl := 0
	var lst := []
	for c in cells:
		var lane := _vine_by(c)
		var vine := lane >= 0
		var nm := ""
		if vine:
			nv += 1
			nm = "V%d" % nv
		elif (c as Vector2i).y == floor_row:
			nf += 1
			nm = "F%d" % nf
		else:
			nl += 1
			nm = "L%d" % nl
		var s := {"cell": c, "name": nm, "vine": vine, "lane_x": lane}
		if vine:
			var ctr := cell_px(c)
			s["center"] = ctr
			s["base"] = ctr + Vector2(0, 15.5)
		else:
			var base := Vector2((c.x + 0.5) * TILE, surface_below((c.x + 0.5) * TILE, c.y * TILE + 1.0))
			s["base"] = base
			s["center"] = base + Vector2(0, -15.5)
		s["box"] = Rect2((s["center"] as Vector2) - Vector2(14, 14), Vector2(28, 28))
		lst.append(s)
	sockets = lst


func _vine_by(c: Vector2i) -> int:
	## The column of a vine within 2 of the cell (its row or the next), or -1.
	if level == null:
		return -1
	for dx in [0, 1, -1, 2, -2]:
		for dy in [0, 1]:
			if LevelData.is_climb(level.tile(c.x + dx, c.y + dy)):
				return c.x + dx
	return -1


func socket_named(nm: String) -> int:
	for i in sockets.size():
		if str(sockets[i]["name"]) == nm:
			return i
	return -1


func pick_socket(from: Vector2, exclude := -1) -> int:
	## The Heart Run's socket: the nearest to Wick at least 3 tiles from him,
	## never the last one (nor exclude), vine sockets only from the third run.
	var best := -1
	var bd := INF
	var far := -1
	var fd := -1.0
	for i in sockets.size():
		if i == last_socket or i == exclude:
			continue
		if bool(sockets[i]["vine"]) and runs < VINE_AFTER and not rush:
			continue
		var d := (sockets[i]["center"] as Vector2).distance_to(from)
		if d >= SOCKET_MIN and d < bd:
			bd = d
			best = i
		if d > fd:
			fd = d
			far = i
	return best if best >= 0 else far


func blossom_rect() -> Rect2:
	if target < 0:
		return NOWHERE
	return sockets[target]["box"]


func decoy_rect() -> Rect2:
	if decoy < 0:
		return NOWHERE
	return sockets[decoy]["box"]


# ---------------------------------------------------------------- her body

func trunk_rect() -> Rect2:
	## Her trunk (A4's trunk box on the frame on show; chip hits and touch).
	var fr := frame_name if frame_name != "" else "rootmother_idle"
	var f = points().get(fr, {})
	if not frames.is_empty() and f is Dictionary and (f as Dictionary).has("trunk"):
		var q: Array = f["trunk"]
		var a := frame_point(Vector2(float(q[0]), float(q[1])))
		var b := frame_point(Vector2(float(q[0]) + float(q[2]), float(q[1]) + float(q[3])))
		return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
	return Rect2(position.x - 52.0, position.y - 160.0 - _rise, 100.0, 160.0)


func legs_rect() -> Rect2:
	## P3: the stilt legs under her (A4's legs_box), else nothing.
	if _rise < 4.0:
		return NOWHERE
	var lb := [40.0, 20.0, 330.0, 92.0]
	var p3 = points().get("_p3", {})
	if p3 is Dictionary and (p3 as Dictionary).has("legs_box"):
		lb = p3["legs_box"]
	var k := _rise / RISE_P3
	var x0 := position.x + (float(lb[0]) - 192.0) * 0.5 * look_face
	var x1 := position.x + (float(lb[0]) + float(lb[2]) - 192.0) * 0.5 * look_face
	var h := float(lb[3]) * 0.5 * k
	return Rect2(minf(x0, x1), floor_y - h, absf(x1 - x0), h)


func near_x() -> float:
	## Her near side: where the arena's open floor ends at her.
	return minf(trunk_rect().position.x, arena_right)


func rect() -> Rect2:
	if not alive:
		return NOWHERE
	if is_open() and target >= 0:
		return blossom_rect()
	return trunk_rect()


func hurt_rect() -> Rect2:
	if not alive or state == "sleep":
		return NOWHERE
	if is_open() and target >= 0:
		return blossom_rect().grow(2.0)
	return trunk_rect().grow(-4.0)


func center() -> Vector2:
	var r := rect()
	if r == NOWHERE:
		return position + Vector2(0, -90)
	return r.get_center()


func touch_damage() -> bool:
	## Her trunk hurts, but not asleep, dead, or while the heart is open (the
	## blossom is the World's target then; she answers the trunk herself).
	return alive and state != "sleep" and not is_open()


func can_hurt(_h: Dictionary) -> bool:
	return state != "roar"


# ---------------------------------------------------------------- being hit

func on_hurt(h: Dictionary, _amount: float, open: bool, _frac: float) -> void:
	if open and target >= 0 and world != null and world.get("glow") != null:
		world.glow.burst(sockets[target]["center"], 8, AMBER, 120.0, 0.3, 0.0, 2.0)
	if not open:
		flash = 0.6


func on_phase(p: int) -> void:
	## The roar: P2 kills the Rootlings and sinks the pillars; P3 tears her
	## roots out and raises the humps.
	_end_run(true)
	_bands.clear()
	_sink_spears()
	_clear_seeds()
	_thorn_t = -1.0
	_thorns.clear()
	state = "roar"
	timer = ROAR
	_queue.clear()
	sfx("rootmother_roar", "boss_roar")
	if p >= 3:
		_raise_humps()


func on_stagger() -> void:
	## WILTED: the window ends with a bonus; she sags a moment.
	_end_run(false)
	state = "wilt"
	timer = REEL
	sfx("rootmother_wilt", "boss_roar")
	if world != null:
		world.banner("WILTED!")


func on_death() -> void:
	_end_run(true)
	_bands.clear()
	_sink_spears()
	_clear_seeds()
	_thorns.clear()
	_thorn_t = -1.0
	for c in _clouds:
		c["burnt"] = true
	sfx("rootmother_die", "boss_die")


func _window_over() -> void:
	if _stage == "open":
		_stage = "close"
		_stage_t = CLOSE
		sfx("bloom_close", "")


# ---------------------------------------------------------------- the step

func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	# The window's target takes a stomp (the window's first 3x); anything
	# else of hers is spikes to land on.
	stompable = is_open()
	if not alive:
		return
	# What she has set going runs on whatever she's doing (a stun only holds
	# her own moves).
	_step_run(dt, player)
	_step_bands(dt, player)
	_step_spears(dt, player)
	_step_seeds(dt, player)
	_step_thorns(dt, player)
	_step_clouds(dt)
	_step_puff(dt, player)
	_rise_step(dt)
	if state != "sleep" and is_open():
		# The trunk still hurts while the World's target is the blossom.
		strike("touch", trunk_rect().grow(-4.0), position.x, "hit")
	if _rise > 4.0 and state != "sleep":
		strike("touch", legs_rect(), position.x, "hit")
	_pose_bough()
	_place_props()


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_crown_jit = maxf(_crown_jit - dt, 0.0)
	match state:
		"sleep":
			_frame("rootmother_idle")
			if wake_check(player):
				state = "roar"
				timer = ROAR + 0.1
				sfx("rootmother_roar", "boss_roar")
				if world != null:
					world.shake = 5.0
		"roar":
			_frame("rootmother_bare" if phase >= 3 else "rootmother_hurt")
			if timer <= 0.0:
				_next(player)
		"idle":
			_frame("rootmother_hollow" if _heart_away() else "rootmother_idle")
			if timer <= 0.0:
				_next(player)
		"sweep_tell":
			_frame("rootmother_sweep_high" if _first_band_kind() == "high" else "rootmother_sweep_low")
			if timer <= 0.0:
				_lash()
		"sweep":
			_frame("rootmother_sweep_high" if _live_band_kind() == "high" else "rootmother_sweep_low")
			if _bands.is_empty():
				_idle(MOVE_GAP)
		"dig", "march":
			_frame("rootmother_dig")
			if timer <= 0.0:
				_idle(MOVE_GAP)
		"seed_tell":
			_frame("rootmother_idle")
			if timer <= 0.0:
				_idle(MOVE_GAP)
		"breath_tell":
			_frame("rootmother_breath")
			if timer <= 0.0:
				_breathe(false)
				_idle(MOVE_GAP)
		"heart_breath":
			_frame("rootmother_breath")
			if timer <= 0.0:
				_breathe(true)
				_start_pulse()
				state = "heart"
		"thorn_tell":
			_frame("rootmother_bare")
			_crown_jit = 0.1
			if timer <= 0.0:
				_thorn_t = 0.0
				_thorn_n = 0
				state = "thorns"
				timer = THORN_RAIN
		"thorns":
			_frame("rootmother_bare")
			if timer <= 0.0:
				_idle(MOVE_GAP)
		"heart":
			_frame("rootmother_hollow")
			if _stage == "":
				_idle(MOVE_GAP * 0.6)
		"wilt":
			_frame("rootmother_wilt")
			if timer <= 0.0:
				_idle(MOVE_GAP)
		"caught":
			_frame("rootmother_hurt")
			if timer <= 0.0:
				_idle(MOVE_GAP)
	mercy_check(player)


func _frame(n: String) -> void:
	show_frame(n)
	if sprite:
		sprite.position = Vector2((sin(t * 60.0) * 1.5 if _crown_jit > 0.0 else 0.0), -_rise)


func _idle(gap: float) -> void:
	state = "idle"
	timer = cd(gap)


func _heart_away() -> bool:
	return _stage != "" or (not _pulse.is_empty())


func _next(player: Node2D) -> void:
	## The next of this cycle's moves, or the Heart Run that ends it.
	if _queue.is_empty():
		var rot: Array = ROT[phase]
		for i in int(PER_CYCLE[phase]):
			_queue.append(rot[int(_rot[phase]) % rot.size()])
			_rot[phase] = int(_rot[phase]) + 1
		_queue.append("heart")
	var mv: String = _queue.pop_front()
	_cast += 1
	match mv:
		"sweep_low", "sweep_high":
			_sweep_tell([mv.substr(6)])
		"double":
			_sweep_tell(["low", "high"] if _cast % 2 == 0 else ["high", "low"])
			used("double")
		"spear":
			var spot := _lock_spot(player)
			_spear_at(float(spot["x"]), 0, 0.0, spot)
			state = "dig"
			timer = tell(SPEAR_TELL, SPEAR_FLOOR) + SPEAR_RISE
			used("spear")
		"march":
			_march(player)
		"seed":
			_seedfall()
			state = "seed_tell"
			timer = _seed_shake
		"breath":
			state = "breath_tell"
			timer = tell(BREATH_TELL)
			tell_sfx("rootmother_breath", timer)
			used("breath")
		"thorns":
			state = "thorn_tell"
			timer = tell(THORN_TELL, THORN_FLOOR)
			_lanes = lanes(thorn_crowns)
			thorn_crowns += 1
			tell_sfx("thorn_crown", timer)
			used("thorns")
		"heart":
			_heart_run(player)


# ---------------------------------------------------------------- the Heart Run

func _heart_run(player: Node2D) -> void:
	used("heart")
	var from: Vector2 = player.center() if player != null else position
	target = pick_socket(from)
	decoy = pick_socket(from, target) if phase >= 2 and sockets.size() > 2 else -1
	if decoy == target:
		decoy = -1
	last_socket = target
	runs += 1
	_stage = "blush"
	_decoy_state = "swell" if decoy >= 0 else ""
	_decoy_t = 0.0
	_beat_t = 0.0
	sfx("heartbeat", "")
	if decoy >= 0:
		used("decoy")
	state = "heart"
	if phase >= 3 and target >= 0:
		# Deep Roots: she breathes spores over the target first.
		state = "heart_breath"
		timer = tell(BREATH_TELL)
		tell_sfx("rootmother_breath", timer)
		used("breath_heart")
	else:
		_start_pulse()


func _start_pulse() -> void:
	var path := pulse_path(target)
	var lens := PackedFloat32Array([0.0])
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
		lens.append(total)
	var speed := minf(PULSE_SPEED, total / PULSE_MIN) if total > 0.0 else PULSE_SPEED
	_pulse = {"path": path, "lens": lens, "len": total, "s": 0.0, "speed": speed, "out": true}
	_stage = "pulse"


func pulse_path(i: int) -> PackedVector2Array:
	## Her heart -> down her trunk to the root line -> along the floor ->
	## up to the socket: a ledge's by a riser, a vine's up the vine.
	var pts := PackedVector2Array()
	var heart := art_pt("rootmother_hollow", "heart", position + Vector2(-20 * look_face, -40 - _rise))
	var root := Vector2(minf(near_x() + 6.0, position.x), floor_y - 3.0)
	pts.append(heart)
	pts.append(Vector2(heart.x, root.y))
	pts.append(root)
	if i < 0 or i >= sockets.size():
		return pts
	var s: Dictionary = sockets[i]
	var goal: Vector2 = s["center"]
	if bool(s["vine"]) and int(s["lane_x"]) >= 0:
		var vx := (int(s["lane_x"]) + 0.5) * TILE
		pts.append(Vector2(vx, root.y))
		pts.append(Vector2(vx, goal.y))
		pts.append(goal)
	else:
		var base: Vector2 = s["base"]
		pts.append(Vector2(base.x, root.y))
		if absf(base.y - root.y) > 4.0:
			pts.append(Vector2(base.x, base.y - 2.0))
		pts.append(goal)
	return pts


func pulse_pos() -> Vector2:
	if _pulse.is_empty():
		return Vector2.INF
	return _along(_pulse["path"], _pulse["lens"], float(_pulse["s"]))


static func _along(path: PackedVector2Array, lens: PackedFloat32Array, s: float) -> Vector2:
	if path.size() == 0:
		return Vector2.ZERO
	for i in range(1, path.size()):
		if s <= lens[i]:
			var seg := lens[i] - lens[i - 1]
			var k := (s - lens[i - 1]) / seg if seg > 0.0 else 1.0
			return path[i - 1].lerp(path[i], k)
	return path[path.size() - 1]


func _step_run(dt: float, player: Node2D) -> void:
	if not _pulse.is_empty():
		var sp := float(_pulse["speed"]) if bool(_pulse["out"]) else float(_pulse["len"]) / HOME
		_pulse["s"] = float(_pulse["s"]) + (sp * dt if bool(_pulse["out"]) else -sp * dt)
		if bool(_pulse["out"]) and float(_pulse["s"]) >= float(_pulse["len"]):
			_pulse["s"] = _pulse["len"]
			if _stage == "pulse":
				_stage = "swell"
				_stage_t = SWELL
		elif not bool(_pulse["out"]) and float(_pulse["s"]) <= 0.0:
			_pulse = {}
	if _stage in ["blush", "pulse", "swell", "open"]:
		_beat_t -= dt
		if _beat_t <= 0.0:
			_beat_t = BEAT
			sfx("heartbeat", "")
	match _stage:
		"swell":
			_stage_t -= dt
			if _stage_t <= 0.0:
				_stage = "open"
				open_window(float(WINDOW[clampi(phase - 1, 0, 2)]))
				if decoy >= 0 and _decoy_state == "swell":
					_decoy_state = "open"
				sfx("bloom_open", "")
				# In the window: P2 one Seedfall, P3 one Root Spear under Wick.
				if phase == 2:
					_seedfall()
				elif phase >= 3 and player != null:
					var spot := _lock_spot(player)
					_spear_at(float(spot["x"]), 0, 0.0, spot)
		"open":
			if decoy >= 0 and _decoy_state == "open":
				var how := struck(decoy_rect(), "decoy")
				if how != "":
					_burst_decoy()
		"close":
			_stage_t -= dt
			if _stage_t <= 0.0:
				_end_run(false)


func _burst_decoy() -> void:
	## The decoy struck: a spore cloud (r 72, 4 s), a puff, and the true
	## blossom closes 0.5 s early.
	_decoy_state = "burst"
	decoys_burst += 1
	var c: Vector2 = sockets[decoy]["center"]
	_add_cloud(c, DECOY_R, DECOY_LIFE, true)
	_puff = {"p": c, "t": PUFF_T, "hit": false}
	sfx("bloom_decoy_puff", "")
	if world != null and world.get("glow") != null:
		world.glow.burst(c, 22, Color(0.8, 0.75, 1.0, 0.9), 130.0, 0.6, -30.0, 3.0)
	if window_t > 0.0:
		window_t = maxf(window_t - DECOY_CUT, 0.01)


func _end_run(at_once: bool) -> void:
	## The blossoms shut; the heart runs home (at once on a roar or a retry).
	close_window()
	_stage = ""
	target = -1
	decoy = -1
	_decoy_state = ""
	if _pulse.is_empty() or at_once:
		_pulse = {}
	else:
		_pulse["out"] = false


func _step_puff(dt: float, _player: Node2D) -> void:
	if _puff.is_empty():
		return
	_puff["t"] = float(_puff["t"]) - dt
	if not bool(_puff["hit"]):
		var c: Vector2 = _puff["p"]
		var r := Rect2(c - Vector2(PUFF_R, PUFF_R), Vector2(PUFF_R, PUFF_R) * 2.0)
		if world != null and world.player != null and (world.player.center() as Vector2).distance_to(c) <= PUFF_R + 10.0:
			if strike("puff", r, c.x, "hit") > 0:
				_puff["hit"] = true
	if float(_puff["t"]) <= 0.0:
		_puff = {}


# ---------------------------------------------------------------- the sweeps

func _sweep_tell(kinds: Array) -> void:
	_bands.clear()
	var tl := tell(SWEEP_TELL, SWEEP_FLOOR)
	for i in kinds.size():
		var k: String = kinds[i]
		var wait := 0.0
		if i > 0:
			wait = DOUBLE_GAP
		_bands.append({"kind": k, "n": i + 1 if kinds.size() > 1 else 0, "wait": wait, "front": 0.0, "live": false,
				"done": false, "retract": false, "hit": false, "caught": false})
		if kinds.size() == 1:
			used("sweep_" + k)
	state = "sweep_tell"
	timer = tl
	move_id = "sweep_" + str(kinds[0])
	tell_sfx("root_creak", tl)


func _first_band_kind() -> String:
	return str(_bands[0]["kind"]) if not _bands.is_empty() else "low"


func _live_band_kind() -> String:
	for b in _bands:
		if bool(b["live"]) and not bool(b["retract"]):
			return str(b["kind"])
	return _first_band_kind()


func band_rect(kind_: String) -> Rect2:
	## The whole band the lash runs along (the tell's fill).
	var bd: Array = BAND[kind_]
	var h := float(bd[1])
	var cy := floor_y - float(bd[0])
	return Rect2(arena_left, cy - h * 0.5, near_x() - arena_left, h)


func front_rect(b: Dictionary) -> Rect2:
	## The lash's head: FRONT_W px of it at the band's height.
	var r := band_rect(str(b["kind"]))
	return Rect2(float(b["front"]), r.position.y, FRONT_W, r.size.y)


func _lash() -> void:
	## The tell's over: the first band lashes out (the second waits its gap).
	state = "sweep"
	sfx("bough_sweep", "")
	for b in _bands:
		b["front"] = _sweep_start()
		if float(b["wait"]) <= 0.0:
			b["live"] = true


func _sweep_start() -> float:
	return near_x() - FRONT_W * 0.5


func _step_bands(dt: float, _player: Node2D) -> void:
	if state == "sweep_tell" or _bands.is_empty():
		return
	for b in _bands:
		if bool(b["done"]):
			continue
		if not bool(b["live"]):
			b["wait"] = float(b["wait"]) - dt
			if float(b["wait"]) <= 0.0:
				b["live"] = true
				sfx("bough_sweep", "")
			continue
		if bool(b["retract"]):
			b["front"] = float(b["front"]) + RETRACT_SPEED * dt
			if float(b["front"]) >= _sweep_start():
				b["done"] = true
			continue
		b["front"] = float(b["front"]) - SWEEP_SPEED * dt
		if not bool(b["hit"]):
			var res := strike("sweep_" + str(b["kind"]), front_rect(b), near_x(), "hit")
			if res == 3:
				# A Perfect Guard on the bough: caught. She reels.
				b["caught"] = true
				b["retract"] = true
				for o in _bands:
					o["retract"] = true
					o["live"] = true
				state = "caught"
				timer = REEL
				used("caught")
				sfx("rootmother_wilt", "clang")
				return
			if res > 0:
				b["hit"] = true
		if float(b["front"]) <= arena_left:
			b["front"] = arena_left
			b["retract"] = true
	_bands = _bands.filter(func(x): return not bool(x["done"]))


# ---------------------------------------------------------------- the spears

func _lock_x(player: Node2D) -> float:
	## Where a spear goes: under Wick, locked now (inside the arena's floor).
	var x: float = player.position.x if player != null else (arena_left + near_x()) * 0.5
	return clampf(x, arena_left + SPEAR_W, near_x() - SPEAR_W)


func _lock_spot(player: Node2D) -> Dictionary:
	## Where a Root Spear goes, locked now: {x, vine, surf}. Under Wick on
	## whatever floor he's over; on a vine, up the vine from just under his
	## feet (the run's own cells, never past its ends: its root at surf).
	var x := _lock_x(player)
	if player != null and bool(player.get("climbing")) and level != null:
		var run := _vine_run(Vector2i(floori(float(player.position.x) / TILE), floori((float(player.position.y) - 1.0) / TILE)))
		if not run.is_empty():
			var top := float(int(run["y0"]) * TILE)
			var bottom := float((int(run["y1"]) + 1) * TILE)
			var surf := clampf(float(player.position.y) + VINE_SPEAR_BELOW, minf(top + SPEAR_H, bottom), bottom)
			return {"x": (int(run["x"]) + 0.5) * TILE, "vine": true, "surf": surf}
	return {"x": x, "vine": false}


func _vine_run(cell: Vector2i) -> Dictionary:
	## The vine run through cell ({x, y0, y1}, tiles), the orchard's (a
	## snapped rotten run reads as none), or {}.
	if world != null and world.get("features") != null and world.features.has_method("vine_lane"):
		return world.features.vine_lane(cell)
	if level == null or not LevelData.is_climb(level.tile(cell.x, cell.y)):
		return {}
	var y0 := cell.y
	var y1 := cell.y
	while LevelData.is_climb(level.tile(cell.x, y0 - 1)):
		y0 -= 1
	while LevelData.is_climb(level.tile(cell.x, y1 + 1)):
		y1 += 1
	return {"x": cell.x, "y0": y0, "y1": y1}


func _spear_at(x: float, n: int, delay: float, spot := {}) -> void:
	var vine := bool(spot.get("vine", false))
	var surf := float(spot.get("surf", 0.0))
	if not vine:
		var from_y := floor_y - 2.0
		if world != null and world.player != null:
			from_y = minf(float(world.player.position.y) - 2.0, floor_y - 2.0)
		surf = surface_below(x, from_y)
	var tl := tell(SPEAR_TELL, SPEAR_FLOOR)
	_spears.append({"x": x, "surf": surf, "t": -delay, "tell": tl, "stage": "wait" if delay > 0.0 else "tell", "ledge": null,
			"n": n, "hit": false, "said": false, "vine": vine})
	if delay <= 0.0:
		_spear_said(_spears[_spears.size() - 1])


func _spear_said(s: Dictionary) -> void:
	s["said"] = true
	tell_sfx("rootmother_dig", float(s["tell"]))
	if world != null and world.has_method("_haptic"):
		world._haptic(10)


func _march(player: Node2D) -> void:
	## Spear March: 3 (P2) or 5 (P3) from near her toward Wick, 0.3 s apart,
	## the last under where he stood.
	var n := int(MARCH_N[clampi(phase - 1, 0, 2)])
	var spot := _lock_spot(player)
	var goal := float(spot["x"])
	var start := near_x() - SPEAR_W * 2.0
	# From near her toward him, the last under where he stood; with him close
	# to her the line runs on past him at MARCH_STEP, set so one spear is
	# still under him. That one goes up his vine if he's on one.
	var far := start - goal >= MARCH_STEP * float(n - 1)
	var j := roundi(maxf(start - goal, 0.0) / MARCH_STEP)
	var off := maxf(start - goal, 0.0) - MARCH_STEP * float(j)
	for i in n:
		var x := lerpf(start, goal, float(i) / maxf(float(n - 1), 1.0)) if far else start - off - MARCH_STEP * float(i)
		var under := (i == n - 1) if far else (i == j)
		if under:
			_spear_at(goal, i, MARCH_GAP * i, spot)
		else:
			_spear_at(clampf(x, arena_left + SPEAR_W, near_x() - SPEAR_W), i, MARCH_GAP * i)
	state = "march"
	timer = MARCH_GAP * (n - 1) + tell(SPEAR_TELL, SPEAR_FLOOR) + SPEAR_RISE
	used("march")


func spear_rect(s: Dictionary) -> Rect2:
	var h := 0.0
	match str(s["stage"]):
		"rise":
			h = SPEAR_H * clampf((float(s["t"]) - float(s["tell"])) / SPEAR_RISE, 0.0, 1.0)
		"stand":
			h = SPEAR_H
		"sink":
			h = SPEAR_H * clampf(1.0 - float(s["sink"]) / SPEAR_SINK, 0.0, 1.0)
	return Rect2(float(s["x"]) - SPEAR_W * 0.5, float(s["surf"]) - h, SPEAR_W, h)


func _step_spears(dt: float, _player: Node2D) -> void:
	for s in _spears:
		s["t"] = float(s["t"]) + dt
		var tt := float(s["t"])
		match str(s["stage"]):
			"wait":
				if tt >= 0.0:
					s["stage"] = "tell"
					_spear_said(s)
			"tell":
				if tt >= float(s["tell"]):
					s["stage"] = "rise"
					sfx("root_burst", "boss_slam")
					if world != null:
						world.shake = maxf(float(world.shake), 3.0)
						world.dust_at(Vector2(float(s["x"]), float(s["surf"])))
			"rise":
				if not bool(s["hit"]):
					if strike("spear", spear_rect(s), float(s["x"]), "hit") > 0:
						s["hit"] = true
				if tt >= float(s["tell"]) + SPEAR_RISE:
					s["stage"] = "stand"
					s["stand"] = 0.0
					if not bool(s.get("vine", false)) and world != null and world.has_method("add_temp_ledge"):
						s["ledge"] = world.add_temp_ledge(Rect2(float(s["x"]) - SPEAR_W * 0.5, float(s["surf"]) - SPEAR_H, SPEAR_W, 6.0), SPEAR_STAND)
			"stand":
				s["stand"] = float(s.get("stand", 0.0)) + dt
				if float(s["stand"]) >= SPEAR_STAND:
					s["stage"] = "sink"
					s["sink"] = 0.0
			"sink":
				s["sink"] = float(s["sink"]) + dt
				if float(s["sink"]) >= SPEAR_SINK:
					s["stage"] = "gone"
	_spears = _spears.filter(func(s): return str(s["stage"]) != "gone")


func _sink_spears() -> void:
	for s in _spears:
		var mv = s.get("ledge")
		if mv != null and is_instance_valid(mv):
			mv.life = 0.0
	_spears.clear()


# ---------------------------------------------------------------- the seeds

func _seedfall() -> void:
	## The crown shakes 0.5 s, then three skull-seeds arc down onto their
	## shadows over 0.7 s: at Wick's x and 96 px either side.
	_seed_shake = tell(SEED_SHAKE)
	_seed_owed = true
	_crown_jit = _seed_shake
	sfx("seed_spit", "")
	used("seed")


func _drop_seeds() -> void:
	var pl: Node2D = world.player if world != null else null
	var cx: float = pl.position.x if pl != null else (arena_left + near_x()) * 0.5
	# They land on the floor he's on (the first floor at his feet or under
	# them), never on a ledge over his head.
	var from_y: float = minf(float(pl.position.y), floor_y) - 6.0 if pl != null else floor_y - 6.0
	var crown := art_pt(frame_name if frame_name != "" else "rootmother_idle", "crown", position + Vector2(-20 * look_face, -170 - _rise))
	var xs := [cx, cx - SEED_SPREAD, cx + SEED_SPREAD]
	for i in 3:
		var x := clampf(float(xs[i]), arena_left + 16.0, near_x() - 16.0)
		var land := Vector2(x, surface_below(x, from_y))
		_seed_n += 1
		_seeds.append({"from": crown, "to": land, "t": 0.0, "stage": "fall", "sit": 0.0, "hit": false, "id": _seed_n})
		sfx("seed_spit", "")


func seed_land_rect(s: Dictionary) -> Rect2:
	## Where a landing seed hurts: over its shadow, a seed high.
	var to: Vector2 = s["to"]
	return Rect2(to.x - SEED_LAND.x * 0.5, to.y - SEED_LAND.y, SEED_LAND.x, SEED_LAND.y)


func seed_pos(s: Dictionary) -> Vector2:
	if str(s["stage"]) != "fall":
		return (s["to"] as Vector2) + Vector2(0, -SEED_R)
	var k := clampf(float(s["t"]) / SEED_FALL, 0.0, 1.0)
	var a: Vector2 = s["from"]
	var b: Vector2 = (s["to"] as Vector2) + Vector2(0, -SEED_R)
	var arc := -120.0 * 4.0 * k * (1.0 - k)
	return a.lerp(b, k) + Vector2(0, arc)


func _step_seeds(dt: float, _player: Node2D) -> void:
	if _seed_owed:
		_seed_shake -= dt
		if _seed_shake <= 0.0:
			_seed_owed = false
			_drop_seeds()
	for s in _seeds:
		s["t"] = float(s["t"]) + dt
		var p := seed_pos(s)
		var box := Rect2(p - Vector2(SEED_R, SEED_R), Vector2(SEED_R, SEED_R) * 2.0)
		match str(s["stage"]):
			"fall":
				if float(s["t"]) >= SEED_FALL:
					# It hurts only as it lands, on its shadow (the spec's "if
					# one lands on you"): its arc through the air is harmless.
					if not bool(s["hit"]) and strike("seed", seed_land_rect(s), (s["to"] as Vector2).x, "hit") > 0:
						s["hit"] = true
					s["stage"] = "sit"
					sfx("seed_splat", "")
					if world != null and world.get("glow") != null:
						world.glow.burst(s["to"], 8, Color(0.9, 0.85, 0.7, 0.8), 90.0, 0.3, 200.0, 2.0)
			"sit":
				s["sit"] = float(s["sit"]) + dt
				if struck(box, "seed_%d" % int(s["id"])) != "":
					# Popped before it hatches: one ember.
					s["stage"] = "gone"
					if world != null:
						var e: Dictionary = world._add_pickup("ember", p)
						e["loose"] = true
						e["vel"] = Vector2(0, -300)
						if world.get("glow") != null:
							world.glow.burst(p, 10, Color(0.95, 0.9, 0.75), 120.0, 0.35, 200.0, 2.0)
					sfx("seed_splat", "")
				elif float(s["sit"]) >= SEED_HATCH:
					s["stage"] = "gone"
					if adds_alive("rootling") < ROOTLINGS_MAX:
						spawn_add("rootling", s["to"], {"facing": 1 if (world != null and world.player != null and world.player.position.x > (s["to"] as Vector2).x) else -1})
	_seeds = _seeds.filter(func(s): return str(s["stage"]) != "gone")


func _clear_seeds() -> void:
	_seeds.clear()
	_seed_owed = false


# ---------------------------------------------------------------- the spores

func _breathe(over_target: bool) -> void:
	## Spore Breath: 3 clouds over the arena, or (P3's run) one over the target.
	var mouth := art_pt("rootmother_breath", "mouth", position + Vector2(30 * look_face, -100 - _rise))
	if world != null and world.get("glow") != null:
		world.glow.burst(mouth, 18, Color(0.75, 0.85, 0.4, 0.8), 160.0, 0.6, -40.0, 3.0)
	sfx("spore_puff", "")
	if over_target and target >= 0:
		_add_cloud(sockets[target]["center"], CLOUD_R, CLOUD_LIFE, false)
		return
	var w := near_x() - arena_left
	var off := float(_cast % 3) * 0.06
	for k in [0.18, 0.5, 0.82]:
		var x := arena_left + w * (float(k) + off - 0.06)
		_add_cloud(Vector2(x, floor_y - 70.0), CLOUD_R, CLOUD_LIFE, false)


func _add_cloud(p: Vector2, r: float, life: float, is_decoy: bool) -> void:
	_clouds.append({"p": p, "r": r, "t": 0.0, "life": life, "burnt": false, "decoy": is_decoy})
	if world != null and world.get("features") != null and world.features.has_method("add_spores"):
		world.features.add_spores(p, r, life, self)


func clouds() -> Array:
	return _clouds.filter(func(c): return not bool(c["burnt"]) and float(c["t"]) < float(c["life"]))


func _step_clouds(dt: float) -> void:
	## Her clouds drift as the orchard's do; fire near one burns it (the
	## orchard's burn_spores), and a whoomph that reaches the open blossom is
	## a Flashbloom.
	var mine = _orchard_clouds()
	for c in _clouds:
		if bool(c["burnt"]):
			continue
		c["t"] = float(c["t"]) + dt
		if float(c["t"]) >= float(c["life"]):
			c["burnt"] = true
			continue
		if mine != null:
			var best = null
			var bd := float(c["r"]) + 40.0
			for oc in mine:
				var d := (oc["p"] as Vector2).distance_to(c["p"])
				if d < bd:
					bd = d
					best = oc
			if best != null:
				c["p"] = best["p"]
				if float(best.get("burn", -1.0)) >= 0.0:
					_whoomph(c)
					continue
		else:
			c["p"] = (c["p"] as Vector2) + Vector2(0, -8.0 * dt)
		if _fire_near(c["p"], float(c["r"]) + FIRE_REACH):
			if world != null and world.get("features") != null and world.features.has_method("burn_spores"):
				world.features.burn_spores(c["p"], FIRE_REACH)
			_whoomph(c)
	_clouds = _clouds.filter(func(c): return not bool(c["burnt"]))


func _whoomph(c: Dictionary) -> void:
	c["burnt"] = true
	sfx("spore_burn", "whoosh")
	if world != null and world.get("glow") != null:
		world.glow.burst(c["p"], 22, Color(1.0, 0.6, 0.25, 0.95), 180.0, 0.4, -60.0, 3.0)
	if is_open() and target >= 0 and (sockets[target]["center"] as Vector2).distance_to(c["p"]) <= float(c["r"]) + 14.0:
		# Flashbloom: the fire reaches the open heart.
		flashblooms += 1
		used("flashbloom")
		if world != null and world.has_method("deal"):
			_flashbloom = true
			world.deal(self, FLASH_COEF, {"how": "burn", "no_hitstop": true, "from_x": (c["p"] as Vector2).x})
			_flashbloom = false


func _orchard_clouds():
	if world == null or world.get("features") == null or not world.features.has_method("module"):
		return null
	var m = world.features.module("orchard")
	if m == null or m.get("clouds") == null:
		return null
	return (m.clouds as Array).filter(func(c): return c.get("source") == self)


func _fire_near(p: Vector2, r: float) -> bool:
	if world == null:
		return false
	for s in world.shots:
		if str(s.get("owner", "")) == "player" and str(s.get("kind", "")) in ["spark", "flare"] and (s["pos"] as Vector2).distance_to(p) <= r:
			return true
	for h in world.hazards:
		if str(h.get("kind", "")) == "fire" and str(h.get("owner", "")) == "player" and float(h.get("delay", 0.0)) <= 0.0:
			var hr: Rect2 = h["rect"]
			var q := Vector2(clampf(p.x, hr.position.x, hr.end.x), clampf(p.y, hr.position.y, hr.end.y))
			if q.distance_to(p) <= r:
				return true
	return false


# ---------------------------------------------------------------- the Thorn Crown

func lanes(n: int) -> Array:
	## The 4 safe lanes, 3 tiles wide, over the arena's open floor (the
	## thorns fall in the gaps; pattern n of LANES, R_ARENA's columns).
	var pat: Array = LANES[n % LANES.size()]
	var c0 := floori(arena_left / TILE) - 2
	var out := []
	for c in pat:
		var x := float((c0 + int(c)) * TILE)
		out.append([x, minf(x + LANE_TILES * TILE, near_x())])
	return out


func rain_cols() -> int:
	## The columns the thorns can fall in: every one whose middle is on the
	## open floor (the last is the one against her trunk).
	return ceili((near_x() - arena_left) / TILE - 0.5)


func thorn_land(x: float) -> float:
	## Where a thorn falling at x dies: the first floor under the roof (a
	## ledge, a hump, else the floor). Its danger is drawn there.
	return surface_below(x, ceiling_at(x, floor_y - 8.0) + 6.0)


func thorn_fall_to(x: float, head_y: float) -> float:
	## Seconds from a thorn's spawn at x to its tip reaching head_y.
	var d := maxf(head_y - (ceiling_at(x, floor_y - 8.0) + 4.0), 0.0)
	return (-THORN_V0 + sqrt(THORN_V0 * THORN_V0 + 2.0 * THORN_G * d)) / THORN_G


func in_lane(x: float) -> bool:
	for l in _lanes:
		if x >= float(l[0]) and x <= float(l[1]):
			return true
	return false


func _step_thorns(dt: float, _player: Node2D) -> void:
	if _thorn_t >= 0.0:
		var before := _thorn_t
		_thorn_t += dt
		# Each open column drops a thorn every THORN_EVERY s through the rain.
		for c in rain_cols():
			var x := arena_left + (c + 0.5) * TILE
			if in_lane(x):
				continue
			var off := float(c % 3) * 0.1
			var k := floorf((before - off) / THORN_EVERY)
			var k2 := floorf((_thorn_t - off) / THORN_EVERY)
			if k2 > k and _thorn_t - off <= THORN_RAIN and _thorn_t - off >= 0.0:
				var top := ceiling_at(x, floor_y - 8.0) + 4.0
				_thorns.append({"x": x + sin(float(c) * 7.1 + k2) * 5.0, "y": top, "vy": THORN_V0, "hit": false})
				_thorn_n += 1
		if _thorn_t > THORN_RAIN + 1.0:
			_thorn_t = -1.0
	for th in _thorns:
		th["vy"] = minf(float(th["vy"]) + THORN_G * dt, 900.0)
		th["y"] = float(th["y"]) + float(th["vy"]) * dt
		var box := Rect2(float(th["x"]) - 5.0, float(th["y"]) - 16.0, 10.0, 16.0)
		if not bool(th["hit"]) and strike("thorns", box, float(th["x"]), "hit") > 0:
			th["hit"] = true
		var ty := floori(float(th["y"]) / TILE)
		var tx := floori(float(th["x"]) / TILE)
		if level != null and LevelData.is_floor(level.tile(tx, ty)) and float(th["y"]) - ty * TILE < 14.0:
			th["dead"] = true
			if world != null and world.get("glow") != null:
				world.glow.burst(Vector2(float(th["x"]), ty * TILE), 3, Color(0.85, 0.8, 0.65, 0.8), 70.0, 0.2, 200.0, 1.6)
		elif float(th["y"]) > floor_y + 40.0:
			th["dead"] = true
	_thorns = _thorns.filter(func(th): return not th.get("dead", false))
	if _thorn_t < 0.0 and _thorns.is_empty() and state != "thorn_tell" and state != "thorns":
		_lanes.clear()


# ---------------------------------------------------------------- Deep Roots

func _raise_humps() -> void:
	## P3's roar: two root humps (2 cells, one tile tall) come up at arena
	## columns 12 and 23, never on a body (a body there is lifted onto it).
	if level == null or _humps_up:
		return
	_humps_up = true
	var c0 := floori(arena_left / TILE) - 2
	var row := floori(floor_y / TILE) - 1
	_hump_cells.clear()
	_hump_at.clear()
	for hx in HUMPS:
		_hump_at.append(Vector2i(c0 + int(hx), row))
		for dx in 2:
			var c := Vector2i(c0 + int(hx) + dx, row)
			if level.tile(c.x, c.y) != LevelData.AIR:
				continue
			level.set_tile(c, LevelData.STONE)
			_hump_cells.append(c)
			if world != null:
				world._redraw_at(c.x)
	_lift_bodies()
	sfx("root_burst", "boss_slam")


func _lift_bodies() -> void:
	## Nothing is left inside a hump: Wick and the monsters go up onto it.
	if world == null:
		return
	var bodies: Array = [world.player] + world.enemies
	for b in bodies:
		if b == null or not is_instance_valid(b) or b == self or not b.alive:
			continue
		for c in _hump_cells:
			var cr := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
			if (b.rect() as Rect2).intersects(cr.grow(-1.0)):
				b.position.y = c.y * TILE
				b.velocity.y = minf(float(b.velocity.y), 0.0)


func humps() -> Array:
	return _hump_cells.duplicate()


func _rise_step(dt: float) -> void:
	var want := RISE_P3 if phase >= 3 and alive else 0.0
	if state == "roar" and phase >= 3:
		want = RISE_P3 * clampf(1.0 - timer / ROAR, 0.0, 1.0)
	_rise = move_toward(_rise, want, RISE_P3 / 0.6 * dt)
	if _legs:
		_legs.visible = _rise > 1.0 and not frames.is_empty()
		if _legs.visible:
			place_part(_legs, Vector2(position.x, floor_y), 0.0, look_face)


# ---------------------------------------------------------------- the retry

func _reset_arena(_keep: bool) -> void:
	_end_run(true)
	_bands.clear()
	_sink_spears()
	_clear_seeds()
	_thorns.clear()
	_thorn_t = -1.0
	_lanes.clear()
	thorn_crowns = 0
	for c in _clouds:
		c["burnt"] = true
	_clouds.clear()
	_puff = {}
	_queue.clear()
	_rot = {1: 0, 2: 0, 3: 0}
	runs = 0
	last_socket = -1
	_rise = 0.0
	_reel_t = 0.0
	if _humps_up and level != null:
		for c in _hump_cells:
			level.restore_tile(c)
			if world != null:
				world._redraw_at(c.x)
	_humps_up = false
	_hump_cells.clear()
	_hump_at.clear()
	facing = -1
	look_face = -1
	show_frame("rootmother_idle")
	if sprite:
		sprite.position = Vector2.ZERO
	_pose_bough()
	_place_props()


# ---------------------------------------------------------------- dying

func _kill(h: Dictionary) -> void:
	super(h)


func _dying(dt: float) -> void:
	## The heart blooms in her crown; she sighs and settles still; the great
	## bell rises out of the roots.
	show_frame("rootmother_die")
	if sprite:
		sprite.position = Vector2(0, -_rise)
	_rise = move_toward(_rise, 0.0, 30.0 * dt)
	_pose_bough()
	_place_props()
	if world != null and world.get("glow") != null and fmod(death_time, 0.15) < dt and death_time < 1.6:
		var crown := art_pt("rootmother_die", "heart", position + Vector2(-20 * look_face, -160))
		world.glow.burst(crown, 6, Color(1.0, 0.8, 0.5, 0.9), 70.0, 0.8, -60.0, 2.6)
	if death_time > 1.2 and death_time - dt <= 1.2 and world != null:
		world.boss_defeated(self, Vector2((arena_left + near_x()) * 0.5, floor_y - 40.0))
		world.add_bell(Vector2(floorf((arena_left + near_x()) * 0.5 / TILE) * TILE + TILE * 0.5, floor_y))
		sfx("root_burst", "boss_slam")


# ---------------------------------------------------------------- the look

func _pose_bough() -> void:
	## The bough in its 3 parts (A4's poses): the tell pose while she rears,
	## the strike pose laid along the band out to the lash's head.
	for s in _bough:
		s.visible = false
	if frames.is_empty() or not alive:
		return
	var bdoc = points().get("_bough", {})
	if not (bdoc is Dictionary) or not (bdoc as Dictionary).has("poses"):
		return
	var poses: Dictionary = bdoc["poses"]
	var length := float(bdoc.get("length", 144.0))
	var p3 := "_p3" if phase >= 3 and _rise > 4.0 else ""
	var fr := frame_name
	if not (fr in ["rootmother_sweep_low", "rootmother_sweep_high"]):
		return
	var kind_ := "high" if fr == "rootmother_sweep_high" else "low"
	var start := art_pt(fr, "bough", position)
	var b := {}
	for x in _bands:
		if str(x["kind"]) == kind_ and bool(x["live"]):
			b = x
			break
	if state == "sweep_tell" or b.is_empty():
		var pose: Dictionary = poses.get("sweep_%s_tell%s" % [kind_, p3], poses.get("sweep_%s_tell" % kind_, {}))
		if pose.is_empty():
			return
		var th := float(pose.get("thick", 1.0))
		var ch := chain(start, pose["chain"], look_face, length)
		for i in mini(ch.size() - 1, 3):
			var idx := 0 if i == 0 else (15 if i == ch.size() - 2 else 1)
			place_part(_bough[idx], ch[i][1], float(ch[i][2]), look_face, th)
		return
	# The strike: the head of the pose (to its first level link), level
	# copies behind the hand, the hand's tip on the lash's head.
	var spose: Dictionary = poses.get("sweep_%s_strike%s" % [kind_, p3], poses.get("sweep_%s_strike" % kind_, {}))
	if spose.is_empty():
		return
	var thick := float(spose.get("thick", 1.0))
	var links: Array = spose["chain"]
	var head := []
	for l in links:
		if int(l[0]) == 2 and absf(float(l[1])) < 0.01:
			break
		head.append(l)
	var ch2 := chain(start, head, look_face, length)
	var used_i := 0
	for i in head.size():
		var idx := 0 if int(head[i][0]) == 1 else 1 + used_i
		if int(head[i][0]) != 1:
			used_i += 1
		place_part(_bough[idx], ch2[i][1], float(ch2[i][2]), look_face, thick)
	var head_end: Vector2 = ch2[ch2.size() - 1][1]
	var seg := length * 0.5
	var tip_x := float(b["front"])
	var hand_pivot := Vector2(tip_x + seg if look_face < 0 else tip_x - seg, head_end.y)
	if (look_face < 0 and hand_pivot.x > head_end.x) or (look_face > 0 and hand_pivot.x < head_end.x):
		hand_pivot.x = head_end.x
	place_part(_bough[15], hand_pivot, 0.0, look_face, thick)
	var k := 1
	var slot := 1 + used_i
	while slot < 15:
		var px := hand_pivot.x - seg * k * look_face
		var past := (look_face < 0 and px - seg >= head_end.x) or (look_face > 0 and px + seg <= head_end.x)
		if past:
			break
		if (look_face < 0 and px > head_end.x) or (look_face > 0 and px < head_end.x):
			px = head_end.x
		place_part(_bough[slot], Vector2(px, head_end.y), 0.0, look_face, thick)
		slot += 1
		k += 1
		if px == head_end.x:
			break


func _show_buds() -> void:
	for i in _bud_spr.size():
		var s: Sprite2D = _bud_spr[i]
		if not _tex.has("bloom_bud"):
			s.visible = false
			continue
		s.texture = _tex["bloom_bud"]
		place_part(s, sockets[i]["base"], 0.0, 1)
		s.modulate = Color(0.78, 0.78, 0.74)


func _place_props() -> void:
	## The buds and blossoms, the spears, the humps, the seeds, the thorns.
	for i in _bud_spr.size():
		var s: Sprite2D = _bud_spr[i]
		if not _tex.has("bloom_bud"):
			s.visible = false
			continue
		var base: Vector2 = sockets[i]["base"]
		if not alive:
			s.texture = _tex["bloom_bud"]
			s.modulate = Color(0.78, 0.78, 0.74)
			place_part(s, base, 0.0, 1)
			continue
		var tex_name := "bloom_bud"
		var col := Color(0.78, 0.78, 0.74)
		var sc := 1.0
		if i == target and _stage != "":
			match _stage:
				"blush", "pulse":
					col = AMBER
				"swell":
					col = AMBER.lightened(0.15)
					sc = 1.0 + 0.25 * (1.0 - _stage_t / SWELL)
				"open":
					tex_name = "bloom_open"
					col = Color(1.0, 0.92, 0.8)
					sc = 1.0 + 0.06 * sin(t * TAU / BEAT)
				"close":
					col = AMBER
					sc = 0.9
		elif i == decoy:
			match _decoy_state:
				"swell":
					col = DECOY_TINT
					sc = 1.0 + 0.2 * clampf(float(_pulse.get("s", 0.0)) / maxf(float(_pulse.get("len", 1.0)), 1.0), 0.0, 1.0)
				"open":
					tex_name = "bloom_decoy"
					col = Color(1, 1, 1)
					sc = 1.0 + 0.08 * sin(t * 2.4)
				"burst":
					s.visible = false
					continue
		if _tex.has(tex_name):
			s.texture = _tex[tex_name]
		s.modulate = col
		place_part(s, base, 0.0, 1, 1.0, sc)
	for i in _spear_spr.size():
		var sp: Sprite2D = _spear_spr[i]
		sp.visible = false
		if i < _spears.size() and alive:
			var sd: Dictionary = _spears[i]
			var r := spear_rect(sd)
			if r.size.y > 0.5 and _tex.has("root_spear"):
				# It grows from its base (the frame's bottom middle).
				place_part(sp, Vector2(float(sd["x"]), float(sd["surf"])), 0.0, 1, r.size.y / SPEAR_H)
	for i in _hump_spr.size():
		var hs: Sprite2D = _hump_spr[i]
		hs.visible = _humps_up and _tex.has("root_hump") and i < _hump_at.size()
		if hs.visible:
			var c: Vector2i = _hump_at[i]
			place_part(hs, Vector2((c.x + 1) * TILE, (c.y + 1) * TILE), 0.0, 1, 1.0, 1.1)
	for i in _seed_spr.size():
		var ss: Sprite2D = _seed_spr[i]
		ss.visible = false
		if i < _seeds.size() and _tex.has("skull_seed"):
			place_part(ss, seed_pos(_seeds[i]), sin(t * 9.0 + i) * 20.0 if str(_seeds[i]["stage"]) == "fall" else 0.0, 1)
	for i in _thorn_spr.size():
		var ts: Sprite2D = _thorn_spr[i]
		ts.visible = false
		if i < _thorns.size() and _tex.has("thorn"):
			place_part(ts, Vector2(float(_thorns[i]["x"]), float(_thorns[i]["y"]) - 8.0), 0.0, 1)


func eye_points() -> Array:
	if not alive or state == "sleep":
		return []
	var fr := frame_name if frame_name != "" else "rootmother_idle"
	return [art_pt(fr, "eye_l", position + Vector2(-10, -130 - _rise)), art_pt(fr, "eye_r", position + Vector2(-34, -128 - _rise))]


func lights() -> Array:
	## At most 16 in her fight (spec §5.2): the true blossom (r 40, 70 open
	## or from P2), the pulse (r 40), the spear glints (r 22, 5 at most), her
	## face's fill (r 140, s 0.35: A4's), her heart home (r 30).
	var out := []
	if not alive:
		return out
	var fr := frame_name if frame_name != "" else "rootmother_idle"
	out.append(glow_light(art_pt(fr, "face", position + Vector2(-20, -120 - _rise)), 140.0, 0.35, "boss"))
	if not _heart_away():
		out.append(glow_light(art_pt(fr, "heart", position + Vector2(-20, -60 - _rise)), 30.0, 0.7, "boss", Color(HEART, 0.6)))
	# (her eyes glow in the glow layer, not as lights: the budget is the
	# spec's 16 with 3 Rootlings' eyes, the hero's and the World's boss light)
	if target >= 0 and _stage != "":
		var r := 70.0 if (_stage == "open" or phase >= 2) else 40.0
		out.append(glow_light(sockets[target]["center"], r, 0.8, "tell", Color(AMBER, 0.35)))
	var pp := pulse_pos()
	if pp != Vector2.INF:
		out.append(glow_light(pp, 40.0, 0.9, "tell", Color(AMBER, 0.4)))
	var ng := 0
	for s in _spears:
		if str(s["stage"]) == "tell" and ng < 5:
			out.append(glow_light(Vector2(float(s["x"]), float(s["surf"]) - 6.0), 22.0, 0.7, "tell", Color(0.6, 1.0, 0.5, 0.4)))
			ng += 1
	return out


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive or world == null:
		return
	var tb := gtb()
	# The bands' tells: filled at 0.2 across the arena, dashed edges (the
	# first of a Double Sweep bright and numbered, the second dimmer).
	if state == "sweep_tell" or state == "sweep":
		for b in _bands:
			if bool(b["retract"]) or (state == "sweep" and bool(b["live"])):
				continue
			var r := band_rect(str(b["kind"]))
			var low := str(b["kind"]) == "low"
			var col := Color(1.0, 0.72, 0.42) if low else Color(0.78, 1.0, 0.7)
			var strong := int(b["n"]) <= 1
			var k := 1.0 - clampf(timer / maxf(tell(SWEEP_TELL, SWEEP_FLOOR), 0.01), 0.0, 1.0) if state == "sweep_tell" else 1.0
			band_fill(tb, r, Color(col, 0.20 if strong else 0.12), Color(col, (0.55 + 0.4 * k) if strong else 0.45))
			if int(b["n"]) > 0:
				# Numbered all along it, so the numeral is on screen wherever he is.
				var dx := r.position.x + 24.0
				while dx < r.end.x - 20.0:
					_digit(tb, int(b["n"]), Vector2(dx, r.position.y - 18.0 if low else r.end.y + 4.0), Color(col, 0.95 if strong else 0.6))
					dx += 180.0
	for b in _bands:
		if not bool(b["live"]) or bool(b["retract"]):
			continue
		var fr := front_rect(b)
		var col2 := Color(1.0, 0.85, 0.55) if str(b["kind"]) == "low" else Color(0.85, 1.0, 0.8)
		tb.rect(Rect2(fr.position.x - 2.0, fr.position.y - 2.0, 6.0, fr.size.y + 4.0), Color(col2, 0.95))
		tb.rect(Rect2(fr.position.x, fr.position.y, FRONT_W, fr.size.y), Color(col2, 0.22))
		for i in 3:
			var q := Vector2(fr.position.x + 10.0 + i * 14.0, fr.position.y + fr.size.y * (0.2 + 0.3 * i) + sin(t * 30.0 + i) * 3.0)
			tb.rect(Rect2(q, Vector2(5, 2)), Color(1, 1, 1, 0.6))
	# The spears' tells: a dirt ring closing on the spot, a bulge, a glint.
	for s in _spears:
		if str(s["stage"]) != "tell":
			continue
		var k2 := clampf(float(s["t"]) / maxf(float(s["tell"]), 0.01), 0.0, 1.0)
		var at := Vector2(float(s["x"]), float(s["surf"]) - 1.0)
		if bool(s.get("vine", false)):
			# Up a vine: the stretch it will burst along bristles, edged
			# bright both sides, thorns pricking out as the tell runs.
			var top := at.y - SPEAR_H
			var vc := Color(0.7, 1.0, 0.55, 0.35 + 0.55 * k2)
			for side in [-1.0, 1.0]:
				tb.rect(Rect2(at.x + side * 9.0 - 1.0, top, 2.0, SPEAR_H), vc)
				for j in 4:
					var ty := top + 8.0 + 16.0 * j
					tb.line(Vector2(at.x + side * 9.0, ty), Vector2(at.x + side * (9.0 + 6.0 * k2), ty - 4.0), 1.5, vc)
		tb.ring(at, 30.0 - 16.0 * k2, 2.0 + k2, Color(0.85, 0.7, 0.45, 0.45 + 0.5 * k2), 18)
		tb.ellipse(at + Vector2(0, -2.0 * k2), 10.0 + 4.0 * k2, 2.0 + 5.0 * k2, Color(0.35, 0.25, 0.15, 0.7), 12)
		tb.rect(Rect2(at + Vector2(-1, -10.0 - 6.0 * k2), Vector2(2, 8.0 + 6.0 * k2)), Color(0.7, 1.0, 0.55, 0.9))
		tb.rect(Rect2(at + Vector2(-5.0 - 3.0 * k2, -7.0), Vector2(10.0 + 6.0 * k2, 2)), Color(0.7, 1.0, 0.55, 0.9))
	# The seeds' shadows, swelling where they'll land.
	for s in _seeds:
		var land: Vector2 = s["to"]
		if str(s["stage"]) == "fall":
			var k3 := clampf(float(s["t"]) / SEED_FALL, 0.0, 1.0)
			tb.ellipse(land + Vector2(0, -2), 6.0 + 7.0 * k3, 2.0 + 1.5 * k3, Color(0, 0, 0, 0.45 + 0.3 * k3), 12)
			tb.ring(land + Vector2(0, -2), 26.0 - 12.0 * k3, 1.5 + k3, Color(0.98, 0.9, 0.72, 0.3 + 0.6 * k3), 16)
		else:
			var left := 1.0 - clampf(float(s["sit"]) / SEED_HATCH, 0.0, 1.0)
			tb.ring(seed_pos(s), SEED_R + 5.0, 2.0, Color(0.9, 0.95, 0.6, 0.35 + 0.4 * (1.0 - left)), 16, -PI * 0.5, -PI * 0.5 + TAU * left)
	# The Thorn Crown: the safe lanes glow on the floor; every other column
	# reddens where its thorns will die (a ledge's top, a hump's, else the
	# floor: the floor under a ledge is sheltered and stays unmarked);
	# glints at the roof over every open column.
	if not _lanes.is_empty():
		var k4 := 1.0 if state != "thorn_tell" else 1.0 - clampf(timer / maxf(tell(THORN_TELL, THORN_FLOOR), 0.01), 0.0, 1.0)
		for c in rain_cols():
			var cx := arena_left + (c + 0.5) * TILE
			if in_lane(cx):
				continue
			var x0 := arena_left + c * TILE
			var land := thorn_land(cx)
			tb.rect(Rect2(x0, land - 5.0, minf(TILE, near_x() - x0), 5.0), Color(1.0, 0.32, 0.26, 0.40 + 0.35 * k4))
		for l in _lanes:
			var lr := Rect2(float(l[0]), floor_y - 6.0, float(l[1]) - float(l[0]), 6.0)
			tb.rect(lr, Color(0.8, 1.0, 0.75, 0.65 + 0.35 * k4))
			tb.rect(Rect2(lr.position.x, floor_y - 72.0, lr.size.x, 66.0), Color(0.8, 1.0, 0.75, 0.10 + 0.10 * k4))
			tb.rect(Rect2(lr.position.x, floor_y - 72.0, 3.0, 72.0), Color(0.8, 1.0, 0.75, 0.30 + 0.45 * k4))
			tb.rect(Rect2(lr.end.x - 3.0, floor_y - 72.0, 3.0, 72.0), Color(0.8, 1.0, 0.75, 0.30 + 0.45 * k4))
		if state == "thorn_tell":
			for c in rain_cols():
				var x := arena_left + (c + 0.5) * TILE
				if in_lane(x):
					continue
				var top := maxf(ceiling_at(x, floor_y - 8.0), world.view_rect().position.y) + 4.0
				tb.rect(Rect2(x - 1.5, top, 3.0, 6.0 + 4.0 * k4), Color(1.0, 0.85, 0.7, 0.5 + 0.4 * k4))
	# The thorns themselves: a pale glint on each, so they read in the dark.
	for th in _thorns:
		var tp := Vector2(float(th["x"]), float(th["y"]))
		tb.rect(Rect2(tp + Vector2(-1.0, -15.0), Vector2(2.0, 12.0)), Color(1.0, 0.92, 0.8, 0.75))
	# The pulse: the root-vein it has run along glows (floor cracks), its head bright.
	if not _pulse.is_empty():
		var path: PackedVector2Array = _pulse["path"]
		var lens: PackedFloat32Array = _pulse["lens"]
		var s_now := float(_pulse["s"])
		var d := 0.0
		while d < s_now:
			var a := _along(path, lens, d)
			var bq := _along(path, lens, minf(d + 12.0, s_now))
			var jit := Vector2(0, sin(d * 0.21) * 1.5)
			tb.line(a + jit, bq + jit, 2.5, Color(VEIN, 0.55 if bool(_pulse["out"]) else 0.3))
			d += 12.0
		var head := pulse_pos()
		tb.circle(head, 7.0, Color(VEIN, 0.35), 12)
		tb.circle(head, 3.5, Color(1.0, 0.95, 0.8, 0.95), 10)
	# The blossoms: the true one's ring beats with her heart; its window
	# drains round it. (The decoy is unlit and makes no glow.)
	if target >= 0 and _stage != "":
		var c: Vector2 = sockets[target]["center"]
		var beat := 0.5 + 0.5 * sin(t * TAU / BEAT)
		var ring_a := 0.35 + 0.35 * beat if _stage != "open" else 0.6 + 0.3 * beat
		tb.ring(c, 18.0 + 3.0 * beat, 2.0, Color(AMBER, ring_a), 20)
		if _stage == "open" and window_len > 0.0:
			var left2 := window_t / window_len
			tb.ring(c, 24.0, 2.5, Color(1.0, 0.95, 0.75, 0.8), 24, -PI * 0.5, -PI * 0.5 + TAU * left2)
	# A target out of the camera's reach (a high socket): a marker at the edge.
	if target >= 0 and _stage in ["blush", "pulse", "swell", "open"]:
		edge_marker(tb, sockets[target]["center"], AMBER)
	# The decoy's puff.
	if not _puff.is_empty():
		var kk := 1.0 - float(_puff["t"]) / PUFF_T
		tb.ring(_puff["p"], PUFF_R * (0.4 + 0.6 * kk), 3.0, Color(0.8, 0.75, 1.0, 0.7 * (1.0 - kk)), 20)
	# Her eyes, always (rule 4).
	glow_eyes(tb, eye_points(), EYE, 3.0)
	tb.flush(glow)


static func _digit(tb: RefCounted, n: int, at: Vector2, col: Color) -> void:
	## A small numeral in rects (1 or 2) for the Double Sweep's bands.
	if n == 1:
		tb.rect(Rect2(at + Vector2(4, 0), Vector2(3, 14)), col)
		tb.rect(Rect2(at + Vector2(1, 2), Vector2(3, 3)), col)
		tb.rect(Rect2(at + Vector2(1, 12), Vector2(9, 2)), col)
	else:
		tb.rect(Rect2(at, Vector2(10, 2)), col)
		tb.rect(Rect2(at + Vector2(8, 0), Vector2(2, 7)), col)
		tb.rect(Rect2(at + Vector2(0, 6), Vector2(10, 2)), col)
		tb.rect(Rect2(at + Vector2(0, 6), Vector2(2, 8)), col)
		tb.rect(Rect2(at + Vector2(0, 12), Vector2(10, 2)), col)


func _draw() -> void:
	## The stand-in (no frames): a hunched grey-bark mother, a caged heart.
	if not frames.is_empty():
		return
	var tb := btb()
	var r := trunk_rect()
	r.position -= position
	cel_poly(tb, PackedVector2Array([r.position + Vector2(10, 20), Vector2(r.end.x, r.position.y + 10), r.end, Vector2(r.position.x, r.end.y)]), Color("b8b0a0"))
	cel_circle(tb, Vector2(r.get_center().x, r.position.y + 30), 34.0, Color("c8c0b0"))
	cel_eyes(tb, [Vector2(r.get_center().x - 12, r.position.y + 28), Vector2(r.get_center().x + 8, r.position.y + 28)], 3.0, EYE)
	if not _heart_away():
		cel_circle(tb, Vector2(r.get_center().x, r.position.y + 90), 9.0, HEART)
	tb.flush(self)
