extends "res://scripts/elites.gd"
## The Prism Saint, The First Light (World 5, `boss: saint`;
## spec §5.4, decisions "The Saint"). A tall floating saint of stained glass,
## eyes closed, a prism cupped in her hands and a rose-window halo behind her;
## in her heart pane a small girl with a candle on her head (Tessel).
##
## The rule: turn her light back on her. Her glass turns every blow (5%
## chip, a glassy tink). Her Judgement Beam tracks Wick (the aim line runs
## from her mask to him), then locks white; a mirror shard between them when
## it locks, or a Candleknight's guard (any block; a Perfect Guard through
## the kit's reflect), sends it straight back: she is Refracted, cracks and
## sinks to a low hover over the nearest platform: the window, 2.6 / 2.2 /
## 1.9 s by phase (Tollbreaker +0.4), full damage, a stomp 3x.
## Refracted she sinks beside Wick over the footing he's on (a mirror's far
## side is a gap or two from her hover point), and the window's clock starts
## as she arrives (it waits up to SINK_MAX s); all of her is there to stomp.
##   - The tell shows success: through the tracking, the mirror that would
##     reflect from where Wick stands brightens and the reflection back to
##     her is drawn too, with a glint. The mirror is a retro-reflector (no
##     angles); the test is the line from her mask to his middle, 24 px
##     wide, against the 16 x 56 pane. The mirror that will reflect holds
##     still from the lock to the beam (what was shown is what happens). A
##     line that starts inside a pane never counts, and her hover points and
##     a beaming shard keep MIRROR_CLEAR px from every track.
##   - Mirror shards: 3 (2 in P3), 16 x 56, drifting down and up 3-tile
##     tracks from the anchors at 30 px/s. One that reflects is dimmed 6 s.
##     They are not platforms.
## Moves (after the x0.70 scale; MOVES for the share-cap scan):
##   Judgement Beam  all: track 1.1 s (the tell multiplier; floor 0.80), lock
##                   0.50 / 0.45 / 0.40 s (never less), a 10 px beam for
##                   0.4 s along the locked line; it breaks the glass it
##                   crosses (the arena's reforms in 4 s), but where it
##                   meets him it ends: never the pane under his feet: 31
##   Rose of Blades  all: the halo spins up 0.6 s (0.45), 8 blades out
##                   radially at 170 px/s, 45 deg apart (P2 turns 22.5 deg a
##                   volley), 2.2 s or until stone: 18
##   Gale Hymn       P2+: 0.9 s of wind gathering on Wick's side, then a
##                   2.0 s gust at 150 px/s toward the far side (a "gust"
##                   push: half on the ground, a jump's grace, the edge
##                   brake); stone footing is out of it; it never starts
##                   while he's airborne over the void
##   Stained Choir   at 70% and 45%: she sings 0.8 s; 2 Paneguards out of the
##                   pillar (70%; never the entry stone, where a fall puts him
##                   back), 3 Glassmites and a Refractor (45%)
##   Shatter         P2+: the platform under Wick glows along its cracks
##                   0.75 s (0.5; spec 0.6, lengthened to the escape formula:
##                   from its middle to the next platform's edge, 0.35 +
##                   144/205 = 1.05 s against the tell and the glass's own
##                   0.35 s flash), then it shatters
##   Scattered Dawn  P3: the roar breaks one mirror for good and she bursts
##                   into three prism shards (red, gold, blue) that orbit;
##                   each in turn tracks and locks a beam of its own (25),
##                   with a Rose volley before it; reflecting one cracks it,
##                   and with all three cracked she re-forms, Refracted, for
##                   the P3 window (one Rose volley as it opens, its tell
##                   played as she re-forms), then splits again
##   Touch 21 (not while Refracted: strike, don't flinch)
## P1 beam and Rose in turn (a reflect chance about every 7 s); P2 two moves
## between beams, a beam may follow a Gale. SHATTERED! (30% inside one
## window, once a phase: +10%, the window ends). Mercy: one wax stub in P3.
## Where she hangs: three hover points, over A (40% in), over the B|C gap
## and over the stone pillar, each MIRROR_CLEAR px from every mirror's track
## (never in front of a pane, her mask never inside one), her gown's point
## 206 px under the roof: the spec's "rows 2-5" brought down to the camera
## (from the low platforms the view's top is 205 px over his feet, and her
## mask, where the aim line starts, is in it); camera_top() is her head, for
## the World's lean (requested). Her beams come from each in turn (left,
## right, middle). Her touch never reaches a Wick in the air over the void
## (the gaps he jumps run under her).
## bot_pad(player): a pad that plays the fight (the --autoplay bot's, W0
## asked; the tests' real-pad runs).
## Retry: platforms regrow (glass.gd on_boss_reset), mirrors reset, the
## shards re-form, the door opens. Defeat: her pieces fly back into a whole
## rose window high above, dawn pours through for 2 s, the bell comes down
## on a beam.
## Art (A4): 256-unit frames drawn at DRAW_SCALE 1.15 (points_saint.json's
## _draw_scale: every offset scales with it), anchor (128, 244) the gown's
## point, `mask` where the beam and the aim line start, `body` her box per
## frame; the halo behind her at halo_center; the shards and mirrors props.
## Without art a code-drawn stand-in (TriBatch).

signal woke

const BossMods := preload("res://scripts/boss_mods.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const HK := preload("res://scripts/hush_kind.gd")
const POINTS := "res://art/enemies/points_saint.json"
const FRAME_FEET := Vector2(128, 244)
const DRAW_SCALE := 1.15
const PHASES := [0.65, 0.30]
const CHOIRS := [0.70, 0.45]
# The windows test sets it (test_bosses4: the reference knight needs 6 (7)
# windows; with a blow never crossing a phase line, 510 needs 8: 480 needs 6).
const BASE_HP := 480.0
const TOUCH := 21.0
# Its blows at area 1, Dusk (spec §5.4 after the x0.70 scale): the share-cap scan.
const MOVES := {"beam": 31.0, "rose": 18.0, "shard_beam": 25.0}
const WINDOW := [2.6, 2.2, 1.9]
const CHIP := 0.05
const STAGGER := 0.30
const STAGGER_BONUS := 0.10
const STAGGER_ROOM := 0.05      # the stagger's bonus stops this far above the phase's line (boss_rig's rule)
const STOMP_MULT := 3.0
const STOMPS_FULL := 1          # stomps a window pays STOMP_MULT for (the bounces after it chip)
const TUNE := {
	"track": 1.1, "track_floor": 0.80,
	"lock": {"dusk": 0.50, "nightfall": 0.45, "witching": 0.40}, "lock_floor": 0.40,
	"fire": 0.4, "beam_w": 10.0, "reflect_w": 24.0,
	"rose_tell": 0.6, "rose_floor": 0.45, "blades": 8, "blade_speed": 170.0, "blade_life": 2.2,
	"gale_tell": 0.9, "gale_floor": 0.60, "gale_time": 2.0, "gale_push": 150.0,
	"shatter_tell": 0.75, "shatter_floor": 0.50,
	"choir": 0.8,
	"glide": 190.0, "sink": 600.0,
	"mirror_speed": 30.0, "mirror_track": 96.0, "mirror_dim": 6.0,
	"refract_hover": 20.0,
	"orbit_period": 14.0,
	"split": 0.8, "reform": 0.6, "shard_gap": 0.7,
	"gap": 0.55,                 # s between moves (the cooldown multiplier)
}
const PANE := Vector2(16, 56)
# A hover point (and a P3 shard that beams) keeps this far from every mirror's
# track: her body's half width (36) and the pane's (8). Her mask is then at
# least 14 px outside the pane grown by the 24 px line.
const MIRROR_CLEAR := 44.0
# Refracted, she sinks beside Wick (this far to his side) over his footing,
# and the window's clock waits while she sinks (up to SINK_MAX s).
const BESIDE := 52.0
const BEAM_ORDER := [0, 2, 1]
const SINK_MAX := 1.4
const HUD_ROW := 40.0           # px of the view's top the HUD's life bar, sigils and pause cover (camera_top keeps her under them)
const PRISM := Color("f8f0ff")
const LILAC := Color("d8c8ff")
const PANE_COLS := [Color("ff8a8a"), Color("ffd870"), Color("8ad0ff")]
const FRAMES := ["saint_idle", "saint_charge", "saint_beam", "saint_rose", "saint_sing", "saint_refracted", "saint_hurt",
		"saint_split", "saint_die"]
const PARTS := ["saint_halo", "halo_shard", "saint_shard_red", "saint_shard_gold", "saint_shard_blue", "mirror_shard",
		"mirror_shard_dim"]
static var _points := {}

var boss_id := "saint"
var boss_name := "The Prism Saint"
var boss_title := "The First Light"   # as her card and the cast roll say (story.gd)
var state := "sleep"
var timer := 0.0
var phase := 1
var move_id := ""
var arena_left := 0.0
var arena_right := 0.0
var arena_top := 64.0
var door: Array[Vector2i] = []
var home := Vector2.ZERO
var stations: Array = []        # [Vector2] her hover points (anchor positions)
var platforms: Array = []       # [{y, x0, x1, cells}] the glass runs
var stones: Array = []          # [{y, x0, x1}] stone footing runs (the entry, the pillar)
var mirrors: Array = []         # [{anchor, x, top, t, ph, dim, broken, hold}]
var shards: Array = []          # P3: [{p, ang, cracked, col}]
var blades: Array = []          # [{p, v, life, col}]
var used := {}                  # move -> times (tests: every move in a sim)
var windows_opened := 0         # tests
var reflects := 0               # beams turned back (tests)
var bright := -1                # the mirror that would reflect from where Wick stands now
var _station := 0
var _beams := 0                 # beams begun (her hover point for each: BEAM_ORDER)
var _move_n := -1
var _loop: Array = []
var _next := ""                 # the move the glide is heading to
var _choirs_done: Array = []
var _choir_pending := false
var _adds: Array = []
var _mercy := false
var _stagger_phase := 0
var _window_dmg := 0.0
var window_stomps := 0          # stomps on her in the open window
var _window_t := 0.0            # the window's length (for the look)
var _hover_to := Vector2.ZERO   # where the window's low hover is
var _sink_t := 0.0              # s she has sunk toward it (the clock waits, up to SINK_MAX)
var _reform_len := 0.6          # the P3 re-forming (its Rose tell)
var _aim := Vector2.RIGHT
var _rest := Vector2.ZERO       # where she hangs while a move plays (her bob is round it)
var _lock_a := Vector2.ZERO
var _lock_b := Vector2.ZERO
var _lock_mirror := -1
var _lock_len := 0.5
var _track_len := 1.1
var _beam := {}                 # the beam burning: {a, b, hazard, reflected, mirror, shard, cut}
var _beam_t := 0.0
var _kit_marks := [0, 0]        # the knight kit's blocks and perfect guards as the beam began
var _rose_turn := 0.0
var _gale_dir := 1
var _gale_side := 1
var _shatter := {}              # the platform glowing under Wick
var _sh_i := 0                  # P3: the shard acting next
var _sh_state := ""
var _hurt_t := 0.0
var _crack := 0.0               # the Refracted crack's flash
var _spin := 0.0                # the halo's turn
var _spin_v := 0.4
var _dawn := {}                 # the defeat: {t, window, bell}
var _opts := {}
var rush := false               # a mode's rush boss (BossMods.configure sets it)
var no_back := true             # Combat.is_back_hit: a saint of glass has no back to strike
var _tb := TriBatch.new()
var _halo_tex: Texture2D = null
var _parts := {}


func _init() -> void:
	kind = "boss"
	xp_kind = "saint"
	size = Vector2(70, 120)
	base_hp = BASE_HP
	base_dmg = TOUCH
	embers = 80
	item_chance = 0.0
	relic_chance = 0.0
	stompable = true
	ordinary = false
	anchor = FRAME_FEET
	flier = true
	scale_mult = DRAW_SCALE
	belt_carry = false
	set("echo_by_body", false)


func _ready() -> void:
	super()
	size = Vector2(70, 120)
	load_frames(FRAMES)
	for n in PARTS:
		var p := "res://art/enemies/%s.svg" % n
		if ResourceLoader.exists(p):
			_parts[n] = load(p)
	_halo_tex = _parts.get("saint_halo")
	show_frame("saint_idle")
	_scan_arena()
	home = position + Vector2(0, -float(TUNE["refract_hover"]))   # asleep she floats low over her platform
	position = home
	_rest = home


func configure(opts: Dictionary) -> void:
	## A mode's boss ({rush, mods, hp_mult, area}): before _ready. BR's
	## boss_mods.gd (wired at the track B merge): rush set, the life x its rush
	## normalisation (BossMods.RUSH_HP, with rush) x the mode's hp_mult, and
	## Warded / Echoing Wax as a runtime (BossMods.of) this script steps.
	_opts = opts.duplicate()
	BossMods.configure(self, opts)


static func points() -> Dictionary:
	if _points.is_empty():
		var text := FileAccess.get_file_as_string(POINTS) if FileAccess.file_exists(POINTS) else ""
		var d = JSON.parse_string(text) if text != "" else null
		_points = d if d is Dictionary else {"_missing": true}
	return _points


func art_point(frame: String, key: String, fallback: Vector2) -> Vector2:
	## A point of the frame (frame units) where it is in the world now.
	if frames.is_empty():
		return fallback
	var f = points().get(frame, {})
	if not (f is Dictionary) or not (f as Dictionary).has(key):
		return fallback
	var q: Array = f[key]
	return frame_point(Vector2(float(q[0]), float(q[1])))


# ---------------------------------------------------------------- the arena

func _scan_arena() -> void:
	## Her room: the walls (boss_arena.gd), the door (the air in the two
	## columns left of the left wall, over its floor: for a boss that floats
	## over the void Arena.find's rows over her feet miss a low doorway), the
	## glass platforms, the stone footing, her hover points and the mirrors'
	## tracks (the anchors, sorted by x then y: the first three).
	var a := Arena.find(level, position)
	arena_left = a["left"]
	arena_right = a["right"]
	door.assign(_find_door(a["door"]))
	var c0 := floori(arena_left / TILE)
	var c1 := floori(arena_right / TILE) - 1
	arena_top = 64.0
	for y in range(0, level.height):
		if not LevelData.is_solid(level.tile((c0 + c1) / 2, y)):
			arena_top = y * TILE
			break
	platforms.clear()
	stones.clear()
	for y in range(1, level.height):
		var x := c0
		while x <= c1:
			var t: int = level.tile(x, y)
			var above: int = level.tile(x, y - 1)
			var top := LevelData.is_solid(t) and not LevelData.is_solid(above)
			if not top or y * TILE < arena_top + TILE:
				x += 1
				continue
			var glass := t == LevelData.GLASS
			var x1 := x
			while x1 + 1 <= c1 and LevelData.is_solid(level.tile(x1 + 1, y)) and not LevelData.is_solid(level.tile(x1 + 1, y - 1)) \
					and (level.tile(x1 + 1, y) == LevelData.GLASS) == glass:
				x1 += 1
			var run := {"y": y * TILE, "x0": x * TILE, "x1": (x1 + 1) * TILE, "row": y}
			if glass:
				var cells: Array = []
				for cx in range(x, x1 + 1):
					cells.append(Vector2i(cx, y))
				run["cells"] = cells
				platforms.append(run)
			else:
				stones.append(run)
			x = x1 + 1
	platforms.sort_custom(func(p, q): return float(p["x0"]) < float(q["x0"]))
	stones.sort_custom(func(p, q): return float(p["x0"]) < float(q["x0"]))
	var anchors: Array = []
	for e in level.entities:
		if str(e["kind"]) == "anchor":
			var cell: Vector2i = e["cell"]
			if cell.x >= c0 - 1 and cell.x <= c1 + 1:
				anchors.append(cell)
	anchors.sort_custom(func(p, q): return p.x < q.x or (p.x == q.x and p.y < q.y))
	mirrors.clear()
	for i in mini(anchors.size(), 3):
		var cell: Vector2i = anchors[i]
		mirrors.append({"anchor": Vector2((cell.x + 0.5) * TILE, cell.y * TILE), "t": 0.0, "ph": float(i) * 2.1,
				"dim": 0.0, "broken": false, "hold": false, "flash": 0.0})
	_place_mirrors(0.0)
	# Her three hover points, her gown's point 206 px under the roof (spec
	# "rows 2-5", brought down to the camera: from the low platforms the
	# view's top is 205 px over his feet, and her mask, where the aim line
	# starts, must be in it; camera_top() asks the World to lean up for the
	# rest of her).
	var sy := arena_top + 206.0
	var xs := []
	if platforms.size() >= 4:
		# Left: over the first platform, 40% in; the middle: the gap between
		# the second and third; right: over the stone pillar past the last
		# platform (else the last platform's far part). Chosen so that, her
		# beams coming from each in turn, no footing is across a mirror from
		# all of them (standing still, about half her beams turn: the review's
		# stand-still probe; the old gap midpoints left the middle platforms
		# behind a mirror from both ends).
		var pa: Dictionary = platforms[0]
		var pz: Dictionary = platforms[platforms.size() - 1]
		xs.append(float(pa["x0"]) + (float(pa["x1"]) - float(pa["x0"])) * 0.4)
		xs.append((float(platforms[1]["x1"]) + float(platforms[2]["x0"])) * 0.5)
		var right := float(pz["x0"]) + (float(pz["x1"]) - float(pz["x0"])) * 0.75
		for st in stones:
			if float(st["x0"]) >= float(pz["x1"]):
				right = float(st["x0"]) + 16.0
		xs.append(right)
	else:
		var w := arena_right - arena_left
		xs = [arena_left + w * 0.3, arena_left + w * 0.5, arena_left + w * 0.72]
	stations.clear()
	for x in xs:
		stations.append(Vector2(_clear_x(float(x)), sy))


func _clear_x(x: float) -> float:
	## A hover point's x kept MIRROR_CLEAR px from every mirror's track: her
	## body never floats in front of a pane, and her mask (where the line
	## starts) is never inside one, where every line would meet it and a
	## beam from there would reflect wherever he stood. The nearest clear x
	## (on the side away from the track), inside the room.
	var lo := arena_left + 60.0
	var hi := arena_right - 60.0
	var best := clampf(x, lo, hi)
	for pass_i in 4:
		var bad := -1.0
		for m in mirrors:
			if absf(best - float(m["x"])) < MIRROR_CLEAR - 0.01:
				bad = float(m["x"])
				break
		if bad < 0.0:
			return best
		var right := bad + MIRROR_CLEAR
		var left := bad - MIRROR_CLEAR
		var pick := right if absf(right - x) <= absf(left - x) else left
		if pick > hi or pick < lo:
			pick = left if pick == right else right
		best = clampf(pick, lo, hi)
	return best


func _find_door(fallback: Array) -> Array:
	## The doorway: the air cells in the two columns left of the arena's left
	## wall, in the run that stands on a floor (the lowest).
	var c := floori(arena_left / TILE) - 1
	var best: Array = []
	var y: int = level.height - 1
	while y >= 1:
		if level.tile(c, y) == LevelData.AIR and LevelData.is_solid(level.tile(c, y + 1)):
			var run: Array = []
			var yy := y
			while yy >= 1 and level.tile(c, yy) == LevelData.AIR:
				run.append(yy)
				yy -= 1
			if run.size() >= 2 and run.size() <= 5:
				best = run
				break
			y = yy
		y -= 1
	if best.is_empty():
		return fallback
	var out: Array = []
	for x in [c, c - 1]:
		for ry in best:
			if level.tile(x, ry) == LevelData.AIR:
				out.append(Vector2i(x, ry))
	return out


func _place_mirrors(dt: float) -> void:
	## Each pane drifts down its track and back at mirror_speed (held still
	## while it's the one a locked beam will bounce off).
	var travel := float(TUNE["mirror_track"])
	var w := float(TUNE["mirror_speed"]) / (travel * 0.5)
	for m in mirrors:
		if not m["hold"]:
			m["t"] = float(m["t"]) + dt
		var a: Vector2 = m["anchor"]
		m["x"] = a.x
		m["top"] = a.y + travel * 0.5 - travel * 0.5 * cos(float(m["t"]) * w + float(m["ph"]))
		m["dim"] = maxf(float(m["dim"]) - dt, 0.0)
		m["flash"] = maxf(float(m["flash"]) - dt, 0.0)


func pane_rect(m: Dictionary) -> Rect2:
	return Rect2(float(m["x"]) - PANE.x * 0.5, float(m["top"]), PANE.x, PANE.y)


func mirror_live(i: int) -> bool:
	return i >= 0 and i < mirrors.size() and not mirrors[i]["broken"] and float(mirrors[i]["dim"]) <= 0.0


func mirror_on(a: Vector2, b: Vector2) -> int:
	## The live mirror a beam from a toward b meets first (the line 24 px
	## wide against its pane), or -1.
	var best := -1
	var bd := INF
	var w := float(TUNE["reflect_w"])
	for i in mirrors.size():
		if not mirror_live(i):
			continue
		var r := pane_rect(mirrors[i])
		if r.grow(w * 0.5).has_point(a):
			continue   # (a line that starts inside a pane isn't "a mirror between")
		if seg_hits(a, b, w, r):
			var d := a.distance_to(r.get_center())
			if d < bd:
				bd = d
				best = i
	return best


static func seg_hits(a: Vector2, b: Vector2, width: float, r: Rect2) -> bool:
	## A segment of this width touching r.
	var g := r.grow(width * 0.5)
	if g.has_point(a) or g.has_point(b):
		return true
	var c := [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


func platform_of(pl: Node2D) -> int:
	## The glass platform Wick stands on, or -1.
	if pl == null or not pl.on_floor:
		return -1
	var cy := floori((pl.position.y + 1.0) / TILE)
	for i in platforms.size():
		var p: Dictionary = platforms[i]
		if int(p["row"]) == cy and pl.position.x >= float(p["x0"]) - 6.0 and pl.position.x <= float(p["x1"]) + 6.0:
			return i
	return -1


func on_stone(pl: Node2D) -> bool:
	if pl == null:
		return false
	var cy := floori((pl.position.y + 1.0) / TILE)
	for s in stones:
		if int(s["row"]) == cy and pl.position.x >= float(s["x0"]) - 4.0 and pl.position.x <= float(s["x1"]) + 4.0:
			return pl.on_floor
	return false


func footing_near(x: float, whole := false) -> Dictionary:
	## The run (a glass platform or the stone) nearest x (0 inside it); with
	## whole, only one whose glass under that point is still there.
	var best := {}
	var bd := INF
	for p in platforms + stones:
		var x0 := float(p["x0"])
		var x1 := float(p["x1"])
		var d := 0.0 if x >= x0 and x <= x1 else minf(absf(x - x0), absf(x - x1))
		if whole and p.has("cells"):
			var cx := floori(clampf(x, x0 + 12.0, x1 - 12.0) / TILE)
			if level.tile(cx, int(p["row"])) != LevelData.GLASS:
				continue
		if d < bd:
			bd = d
			best = p
	return best


func _hover_beside(px: float) -> Vector2:
	## The window's low hover: over the footing nearest Wick, BESIDE px to
	## his side (toward where she comes from, else the other), never over his
	## head; refract_hover over its top.
	var f := footing_near(px)
	if f.is_empty():
		return Vector2(position.x, position.y + 60.0)
	var lo := float(f["x0"]) + 24.0
	var hi := float(f["x1"]) - 24.0
	var hx := (lo + hi) * 0.5
	if hi > lo:
		var side := 1.0 if position.x >= px else -1.0
		hx = px + side * BESIDE
		if hx < lo or hx > hi:
			hx = px - side * BESIDE
		hx = clampf(hx, lo, hi)
	return Vector2(hx, float(f["y"]) - float(TUNE["refract_hover"]))


func _nearest_platform(x: float) -> Dictionary:
	var best := {}
	var bd := INF
	for p in platforms:
		var d := absf((float(p["x0"]) + float(p["x1"])) * 0.5 - x)
		if d < bd:
			bd = d
			best = p
	if best.is_empty() and not stones.is_empty():
		best = stones[0]
	return best


# ---------------------------------------------------------------- the boss interface

func boss_info() -> Dictionary:
	return {"id": boss_id, "name": boss_name, "title": boss_title, "frac": hp / maxf(max_hp, 1.0),
			"phases": PHASES, "segments": PHASES, "awake": state != "sleep" and alive}


func is_open() -> bool:
	## Only in the window: Refracted, low over a platform.
	return alive and state == "refracted"


func window_bonus() -> float:
	## Tollbreaker: +0.4 s on her window.
	if world == null or world.get("player") == null or not (world.player.stats is Dictionary):
		return 0.0
	var flags = world.player.stats.get("flags", {})
	return float(flags.get("tollbreaker_window", 0.0)) if flags is Dictionary else 0.0


func window_len(p := -1) -> float:
	return float(WINDOW[clampi((phase if p < 0 else p) - 1, 0, 2)]) + window_bonus()


func reset_fight(keep_phase := false) -> void:
	## Wick was snuffed: asleep again at full life (she never checkpoints),
	## the mirrors and shards as they were, her adds gone, the door open (the
	## World has glass.gd reform the platforms at once).
	if not alive:
		return
	if BossMods.of(self) != null:
		BossMods.of(self).reset()
	Arena.unseal(world, level, door)
	hp = max_hp
	phase = 1
	state = "sleep"
	timer = 0.0
	move_id = ""
	position = home
	fade = 1.0
	_move_n = -1
	_beams = 0
	_choirs_done.clear()
	_choir_pending = false
	_mercy = false
	_stagger_phase = 0
	_window_dmg = 0.0
	_beam = {}
	_shatter = {}
	_lock_mirror = -1
	bright = -1
	blades.clear()
	shards.clear()
	_sh_state = ""
	_rose_turn = 0.0
	for m in mirrors:
		m["broken"] = false
		m["dim"] = 0.0
		m["hold"] = false
		m["t"] = 0.0
	_place_mirrors(0.0)
	_clear_adds()
	show_frame("saint_idle")


func touch_damage() -> bool:
	## Her glass edge hurts, but not asleep, roaring, split or Refracted, and
	## never a Wick in the air over the void: her hover points hang over the
	## gaps he jumps, and a touch's knock there is the pit's share on top.
	if not alive or state in ["sleep", "roar", "split", "scatter", "reform", "refracted", "dead"]:
		return false
	if world != null and world.get("player") != null and not world.player.on_floor and HK.over_pit(world, world.player):
		return false
	return true


func dmg(what := "touch") -> float:
	if MOVES.has(what):
		return float(MOVES[what]) * dmg_mult
	return TOUCH * dmg_mult


func moves() -> Dictionary:
	var out := MOVES.duplicate()
	out["touch"] = TOUCH
	return out


# ---------------------------------------------------------------- her body

func _body_fallback() -> Rect2:
	return Rect2(position.x - 36.0, position.y - 132.0, 72.0, 132.0)


func body_rect() -> Rect2:
	## Her box on the frame on show (points_saint.json "body", scaled).
	if state in ["split", "scatter"] or not alive and state != "dead":
		return NOWHERE
	if frames.is_empty() or frame_name == "":
		return _body_fallback()
	var f = points().get(frame_name, {})
	if not (f is Dictionary) or not (f as Dictionary).has("body"):
		return _body_fallback()
	var b: Array = f["body"]
	var p0 := frame_point(Vector2(float(b[0]), float(b[1])))
	var p1 := frame_point(Vector2(float(b[0]) + float(b[2]), float(b[1]) + float(b[3])))
	return Rect2(minf(p0.x, p1.x), minf(p0.y, p1.y), absf(p1.x - p0.x), absf(p1.y - p0.y))


func rect() -> Rect2:
	if state in ["sleep", "split", "scatter", "reform", "dead"] or not alive:
		return NOWHERE
	return body_rect()


func hurt_rect() -> Rect2:
	## Her touch: the solid glass of her middle (her box's middle 40 px, from
	## under the halo to above the gown's point), not the sleeves' and hem's
	## air round it: standing on a platform beside her hover is safe.
	var r := rect()
	if r == NOWHERE:
		return NOWHERE
	if is_open():
		return r   # (Refracted her touch is off: all of her is there to be stomped)
	return Rect2(r.get_center().x - 20.0, r.position.y + 24.0, 40.0, maxf(r.size.y - 64.0, 10.0))


func center() -> Vector2:
	if state in ["split", "scatter"]:
		return Vector2((arena_left + arena_right) * 0.5, arena_top + 96.0)
	var r := body_rect()
	if r == NOWHERE:
		return position + Vector2(0, -66)
	return r.get_center()


func mask() -> Vector2:
	## Her face: where the aim line and the beam start.
	return art_point(frame_name, "mask", position + Vector2(0, -106))


func halo_center() -> Vector2:
	return art_point(frame_name, "halo_center", position + Vector2(0, -107))


func heart() -> Vector2:
	return art_point(frame_name, "heart", position + Vector2(0, -76))


func _stunned(dt: float) -> void:
	## A stun holds her where she floats (nothing more).
	pass


func camera_top() -> float:
	## (W0's look_up, requested) the world y the camera should lean up to
	## show while she's awake: her head, or the highest shard.
	if not alive or state == "sleep":
		return INF
	if state in ["split", "scatter"]:
		var top := INF
		for sh in shards:
			top = minf(top, (sh["p"] as Vector2).y - 34.0)
		return top
	var r := body_rect()
	if r == NOWHERE:
		return INF
	# Her halo's top too, and the HUD's top row over it (the rev5 review: from
	# the side hover points her halo and head sat under the life bar and the
	# sigils): the World's lean puts this line at the view's top edge.
	var halo_top := halo_center().y - 64.0 * DRAW_SCALE
	return minf(r.position.y, halo_top) - HUD_ROW


# ---------------------------------------------------------------- being hit

func hit(h: Dictionary) -> bool:
	if not alive or state in ["sleep", "split", "scatter", "reform", "dead"]:
		return false
	var how: String = str(h.get("how", "slash"))
	if how == "bump":
		return false
	var bm = BossMods.of(self)
	if bm != null and bm.blocks(h):
		return false   # a Warded Wax mote took it
	var amount := float(h.get("amount", 0.0))
	var open := is_open()
	# boss_rig's two rules (the int2 review's, for every v3 boss): only the
	# window's first stomp pays 3x (the World bounces Wick straight back onto
	# her, so the bounces after it, and what a bounce throws off, chip), and
	# until the phase's stagger a window's blows stop at STAGGER of her life.
	if open and how == "stomp":
		window_stomps += 1
		if window_stomps <= STOMPS_FULL:
			amount *= STOMP_MULT
		else:
			open = false
	elif open and bool(h.get("stomp_born", false)) and window_stomps > STOMPS_FULL:
		open = false
	if not open:
		amount *= CHIP
		h["chip"] = true
		sfx("glass_tink", "clang", 1.5)
	elif _stagger_phase < phase:
		amount = minf(amount, maxf(STAGGER * max_hp - _window_dmg, 0.0))
	var floor_hp := 0.0
	if phase <= PHASES.size():
		floor_hp = max_hp * float(PHASES[phase - 1])
	var clamped := false
	if phase <= PHASES.size() and hp - amount <= floor_hp:
		amount = maxf(hp - floor_hp, 0.0)
		clamped = true
	hp = maxf(hp - amount, 0.0)
	last_damage = amount
	flash = 1.0
	hp_bar = 2.5
	if open:
		_hurt_t = 0.25
		_window_dmg += amount
	if world:
		world._sfx("boss_hit")
		world.shake = maxf(world.shake, 4.0 if open else 2.0)
	if hp <= 0.0:
		_kill(h)
		state = "dead"
		timer = 0.0
		sfx("saint_die", "boss_die")
		return true
	var frac := hp / maxf(max_hp, 1.0)
	for c in CHOIRS:
		if frac <= float(c) + 0.001 and not _choirs_done.has(c):
			_choirs_done.append(c)
			_choir_pending = true
	if clamped:
		phase += 1
		_enter_phase()
		return true
	# SHATTERED!: 30% inside one window, once a phase.
	if open and _stagger_phase < phase and _window_dmg >= STAGGER * max_hp - 0.5:
		_stagger_phase = phase
		# The bonus never takes her closer than STAGGER_ROOM to the phase's
		# line (a stagger left 1 HP over it, and the next chip ended the phase).
		var bonus := maxf(minf(STAGGER_BONUS * max_hp, hp - floor_hp - STAGGER_ROOM * max_hp), 0.0)
		hp -= bonus
		if world:
			world.banner("SHATTERED!")
			if bonus > 0.0:
				world.number(center() + Vector2(0, -60), bonus, "crit", get_instance_id())
			if world.glow:
				world.glow.burst(center(), 30, PRISM, 260.0, 0.6, 0.0, 2.6)
		_end_window()
	return true


func on_reflected(beam: Dictionary) -> void:
	## A Candleknight's Perfect Guard sent a beam back (knight.gd: it then
	## deals its reflect to what the way back touches: she is Refracted first,
	## so that lands in full). A shard's cracks it.
	if _beam.is_empty() or beam.get("source") != self:
		return
	_turned_back("perfect")


func _kill(h: Dictionary) -> void:
	super(h)
	if BossMods.of(self) != null:
		BossMods.of(self).clear()
	_clear_adds()
	blades.clear()
	_beam = {}
	for m in mirrors:
		m["hold"] = false


# ---------------------------------------------------------------- the fight

func think(dt: float, player: Node2D) -> void:
	if BossMods.of(self) != null:
		BossMods.of(self).step(dt, player)
	timer -= dt
	_hurt_t = maxf(_hurt_t - dt, 0.0)
	_crack = maxf(_crack - dt, 0.0)
	_spin_v = move_toward(_spin_v, 3.6 if state in ["rose_tell", "reform"] or _sh_state == "rose_tell" else 0.4, dt * 6.0)
	_spin += _spin_v * dt
	_place_mirrors(dt)
	_step_blades(dt, player)
	_step_beam(dt, player)
	_orbit_shards(dt)
	# She turns to him while Refracted too (she sinks beside him, on either
	# side): her glass has no back, so no blow is a Backstab (no_back).
	if player != null and player.alive and absf(player.position.x - position.x) > 8.0 and state in ["glide", "track", "idle", "refracted"]:
		facing = 1 if player.position.x > position.x else -1
	bright = -1
	match state:
		"sleep":
			_bob(home, dt)
			show_frame("saint_idle")
			if player != null and player.alive and player.position.x > arena_left + 48.0 and absf(player.position.x - position.x) < 900.0:
				state = "wake"
				timer = 1.4
				Arena.seal(world, level, door)
				woke.emit()
				sfx("saint_choir", "boss_roar")
				if world:
					world.shake = 4.0
		"wake":
			show_frame("saint_sing")
			_glide_to(stations[1] if stations.size() > 1 else home, dt, 120.0)
			if timer <= 0.0:
				_pick(player)
		"roar":
			show_frame("saint_sing" if phase < 3 else "saint_hurt")
			_bob(_rest, dt)
			if phase >= 3 and timer <= 1.0 and timer + dt > 1.0:
				_break_mirror_for_good()
			if timer <= 0.0:
				if phase >= 3:
					_start_split()
				else:
					_pick(player)
		"glide":
			show_frame("saint_idle")
			var to: Vector2 = stations[_station]
			_glide_to(to, dt, float(TUNE["glide"]))
			if position.distance_to(to) < 4.0 or timer <= -3.0:
				_start(_next, player)
		"idle":
			show_frame("saint_idle")
			_bob(stations[_station], dt)
			if timer <= 0.0:
				_pick(player)
		"track":
			show_frame("saint_charge")
			_bob(_rest, dt)
			if player != null and player.alive:
				_aim = player.center()
			bright = mirror_on(mask(), _aim)
			if timer <= 0.0:
				_lock(mask(), _aim, -1)
		"lock":
			show_frame("saint_charge")
			_bob(_rest, dt)
			if timer <= 0.0:
				_fire(dmg("beam"), "saint:beam", -1)
				if state == "lock":   # (a mirror's reflect has Refracted her already)
					state = "fire"
					timer = float(TUNE["fire"])
		"fire":
			show_frame("saint_beam")
			if timer <= 0.0:
				_after_beam(player)
		"rose_tell":
			show_frame("saint_rose")
			_bob(_rest, dt)
			if timer <= 0.0:
				_rose(halo_center())
				state = "idle"
				timer = cd(float(TUNE["gap"]) + 0.3)
				move_id = ""
		"gale_tell":
			show_frame("saint_sing")
			_bob(_rest, dt)
			if timer <= 0.0 and _gale_may_start(player):
				state = "gale"
				timer = float(TUNE["gale_time"])
				move_id = "saint:gale"
			elif timer <= -2.0:
				_next_after(player)   # (he stayed up over the void: let it go)
		"gale":
			show_frame("saint_sing")
			_bob(_rest, dt)
			_gale_push(player)
			if timer <= 0.0:
				_next_after(player)
		"shatter_tell":
			show_frame("saint_charge")
			_bob(_rest, dt)
			if timer <= 0.0:
				_shatter_now()
				_next_after(player)
		"choir":
			show_frame("saint_sing")
			_bob(_rest, dt)
			if timer <= 0.0:
				_choir()
				state = "idle"
				timer = cd(0.9)
		"refracted":
			show_frame("saint_refracted" if _hurt_t <= 0.0 else "saint_hurt")
			_glide_to(_hover_to, dt, float(TUNE["sink"]))
			if position.distance_to(_hover_to) > 6.0 and _sink_t < SINK_MAX:
				_sink_t += dt
				timer = minf(timer + dt, _window_t)   # (the window's clock waits while she sinks)
			if timer <= 0.0:
				_end_window()
		"recover":
			show_frame("saint_idle")
			_glide_to(stations[_station], dt, float(TUNE["glide"]))
			if position.distance_to(stations[_station]) < 4.0 or timer <= 0.0:
				if phase >= 3:
					_start_split()
				else:
					_pick(player)
		"split":
			show_frame("saint_split")
			fade = clampf(timer / float(TUNE["split"]), 0.0, 1.0)
			if timer <= 0.0:
				state = "scatter"
				fade = 0.0
				_sh_state = "gap"
				timer = 0.6
		"scatter":
			fade = 0.0
			_scatter(dt, player)
		"reform":
			# Re-forming, her halo spins up and the 8 blades gather on it (the
			# Rose's own tell): the one volley that opens each P3 window.
			show_frame("saint_rose")
			fade = 1.0 - clampf((timer - (_reform_len - float(TUNE["reform"]))) / float(TUNE["reform"]), 0.0, 1.0)
			_glide_to(_hover_to, dt, float(TUNE["sink"]))
			if timer <= 0.0:
				fade = 1.0
				_open_window(true)
				_rose(halo_center())
	position.x = clampf(position.x, arena_left + 30.0, arena_right - 30.0)
	# Mercy: one wax stub in the last phase when Wick is nearly out, dropped
	# onto the footing he last stood on (never into the void under a jump).
	if phase >= 3 and not _mercy and player != null and player.alive and player.life_frac() < 0.25 and world:
		_mercy = true
		var sx: float = player.last_safe.x if player.get("last_safe") is Vector2 else player.position.x
		var f := footing_near(sx, true)
		if not f.is_empty():
			sx = clampf(sx, float(f["x0"]) + 14.0, float(f["x1"]) - 14.0)
		var p: Dictionary = world._add_pickup("wax", Vector2(sx, arena_top + 20.0))
		p["loose"] = true
		p["vel"] = Vector2.ZERO


func _bob(at: Vector2, dt: float) -> void:
	## A slow float round `at` (never a drift: the target is fixed).
	position = position.move_toward(Vector2(at.x, at.y + sin(t * 1.7) * 3.0), 40.0 * dt)


func _glide_to(to: Vector2, dt: float, speed: float) -> void:
	position = position.move_toward(to, spd(speed) * dt)


func _pick(player: Node2D) -> void:
	## The next move, by phase (a Choir first when one is due).
	if phase >= 3:
		_start_split()
		return
	if _choir_pending:
		_choir_pending = false
		state = "choir"
		timer = float(TUNE["choir"])
		move_id = "saint:choir"
		sfx("saint_choir", "boss_roar")
		_used("choir")
		return
	_move_n += 1
	var loop := ["beam", "rose"] if phase == 1 else ["beam", "rose", "gale", "beam", "shatter", "rose"]
	var mv: String = loop[_move_n % loop.size()]
	if mv == "shatter" and not _may_shatter(platform_of(player)):
		mv = "rose"
	# Between moves she drifts to her next hover point (spec: after each
	# attack). Her beams come from each hover point in turn (left, right,
	# middle): no footing is across a mirror from every beam, so standing
	# still never makes her windows (the review's stand-still probe).
	if stations.size() >= 3:
		if mv == "beam":
			_station = BEAM_ORDER[_beams % BEAM_ORDER.size()]
			_beams += 1
		else:
			# (a move of another kind: the hover point next to this one toward the next beam's)
			var nb: int = BEAM_ORDER[_beams % BEAM_ORDER.size()]
			_station = _station + signi(nb - _station) if nb != _station else (1 if _station != 1 else 0)
	else:
		_station = 0
	_next = mv
	state = "glide"
	timer = 0.0


func _start(mv: String, player: Node2D) -> void:
	_used(mv)
	_rest = position
	match mv:
		"beam":
			state = "track"
			_track_len = tell(float(TUNE["track"]), float(TUNE["track_floor"]))
			timer = _track_len
			move_id = "saint:beam"
			if player != null:
				_aim = player.center()
			tell_sfx("saint_charge", _track_len, "flare_charge")
		"rose":
			state = "rose_tell"
			timer = tell(float(TUNE["rose_tell"]), float(TUNE["rose_floor"]))
			move_id = "saint:rose"
			tell_sfx("saint_rose", timer, "relic_rare")
		"gale":
			state = "gale_tell"
			timer = tell(float(TUNE["gale_tell"]), float(TUNE["gale_floor"]))
			move_id = "saint:gale"
			# The wind gathers on his side and blows toward the far one.
			var mid := (arena_left + arena_right) * 0.5
			_gale_side = -1 if player == null or player.position.x < mid else 1
			_gale_dir = -_gale_side
			tell_sfx("gale", timer, "whoosh")
		"shatter":
			var i := platform_of(player)
			if not _may_shatter(i):
				_start("rose", player)
				return
			state = "shatter_tell"
			timer = tell(float(TUNE["shatter_tell"]), float(TUNE["shatter_floor"]))
			_shatter = {"i": i, "t": timer, "len": timer}
			move_id = "saint:shatter"
			tell_sfx("glass_crack", timer, "clang")
		_:
			state = "idle"
			timer = 0.3


func _used(mv: String) -> void:
	used[mv] = int(used.get(mv, 0)) + 1


func _next_after(player: Node2D) -> void:
	state = "idle"
	timer = cd(float(TUNE["gap"]))
	move_id = ""


func lock_time() -> float:
	## The lock: 0.50 / 0.45 / 0.40 s by difficulty (and a mode's tells), never
	## under 0.40.
	var m := 1.0
	var md = world.get("mode") if world != null else null
	if md != null and md.has_method("tells_mult"):
		m = float(md.tells_mult())   # (the difficulty's own is in the table)
	return maxf(float(by_diff(TUNE["lock"]["dusk"], TUNE["lock"]["nightfall"], TUNE["lock"]["witching"])) * m,
			float(TUNE["lock_floor"]))


# ---------------------------------------------------------------- the beam

func _lock(a: Vector2, b: Vector2, shard: int) -> void:
	## The aim line stops and turns white. The mirror it will bounce off (if
	## any) is chosen now and held still until the beam has burned.
	_lock_a = a
	_lock_b = b
	_lock_mirror = mirror_on(a, b)
	if _lock_mirror >= 0:
		mirrors[_lock_mirror]["hold"] = true
	_lock_len = lock_time()
	if shard < 0:
		state = "lock"
		timer = _lock_len
	sfx("beam_lock", "knell")


func beam_path(a: Vector2, b: Vector2, stop := Rect2()) -> Dictionary:
	## Where a beam locked from a through b goes: {end, glass, hit}: on past b
	## to the first stone (glass it crosses, it breaks) or out of the room;
	## with stop (Wick, where the beam meets him), it ends in him: the glass
	## behind a dodge breaks, never the pane under the feet it burned.
	var dir := (b - a).normalized()
	var stopping := stop.size.x > 0.0
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var p := a
	var glass: Array = []
	var went := 0.0
	var bottom: float = level.height * TILE + 32.0
	while went < 2000.0:
		var q := p + dir * 4.0
		if stopping and stop.has_point(q):
			return {"end": q + dir * 8.0, "glass": glass, "hit": true}
		var c := Vector2i(floori(q.x / TILE), floori(q.y / TILE))
		var t: int = level.tile(c.x, c.y)
		if t == LevelData.GLASS:
			if not glass.has(c):
				glass.append(c)
		elif LevelData.is_solid(t):
			break
		p = q
		went += 4.0
		if p.y > bottom or p.x < arena_left - 64.0 or p.x > arena_right + 64.0:
			break
	return {"end": p, "glass": glass, "hit": false}


func _fire(amount: float, move: String, shard: int) -> void:
	## The beam burns for fire s along the locked line. A mirror chosen at the
	## lock turns it back at its pane: she (or the shard) is Refracted.
	var a := _lock_a
	var b := _lock_b
	_beam = {"a": a, "b": b, "reflected": false, "mirror": -1, "shard": shard, "cut": Vector2.INF, "hazard": {}}
	_beam_t = float(TUNE["fire"])
	sfx("beam_fire", "spark", 0.8)
	if _lock_mirror >= 0 and not mirrors[_lock_mirror]["broken"]:
		var r := pane_rect(mirrors[_lock_mirror])
		_beam["b"] = _clip_to(a, b, r)
		_beam["mirror"] = _lock_mirror
		mirrors[_lock_mirror]["hold"] = false
		mirrors[_lock_mirror]["dim"] = float(TUNE["mirror_dim"])
		mirrors[_lock_mirror]["flash"] = 0.6
		_lock_mirror = -1
		_turned_back("mirror")
		return
	_lock_mirror = -1
	var stop := Rect2()
	if world != null and world.get("player") != null and world.player.alive:
		stop = (world.player.rect() as Rect2).grow(float(TUNE["beam_w"]) * 0.5)
	var path := beam_path(a, b, stop)
	_beam["b"] = path["end"]
	if world != null and world.get("features") != null:
		for c in path["glass"]:
			world.features.break_glass(c)
	if world == null:
		return
	if world.get("kit") != null:
		var kt = world.kit
		_kit_marks = [int(kt.get("blocks")) if kt.get("blocks") != null else 0,
				int(kt.get("perfect_guards")) if kt.get("perfect_guards") != null else 0]
	_beam["hazard"] = world.add_hazard({"kind": "beam", "seg": [a, path["end"]], "width": float(TUNE["beam_w"]),
			"life": float(TUNE["fire"]), "dmg": amount, "owner": "enemy", "reflect": true, "source": self, "move": move,
			"shot": true, "saint": true})
	strike_logged(_beam["hazard"], amount)


func _clip_to(a: Vector2, b: Vector2, r: Rect2) -> Vector2:
	## Where the line from a toward b first meets the rect r.
	var dir := (b - a).normalized()
	var p := a
	for i in 600:
		if r.grow(2.0).has_point(p):
			return p
		p += dir * 3.0
	return r.get_center()


func _step_beam(dt: float, player: Node2D) -> void:
	if _beam.is_empty():
		return
	_beam_t -= dt
	# A Candleknight's block (any guard, not only a Perfect one) turns it back
	# too (spec: his showcase): his kit counts the blocks.
	if not bool(_beam["reflected"]) and player != null and world != null and world.get("kit") != null:
		var kt = world.kit
		if str(kt.get("cls")) == "knight" and kt.get("blocks") != null:
			var hz: Dictionary = _beam["hazard"]
			var seg: Array = hz.get("seg", [])
			var touched: bool = seg.size() == 2 and seg_hits(seg[0], seg[1], float(TUNE["beam_w"]), player.rect())
			if touched and (int(kt.blocks) > int(_kit_marks[0]) or int(kt.perfect_guards) > int(_kit_marks[1]) or bool(hz.get("reflected", false))):
				_beam["cut"] = player.center() + Vector2(player.facing * 12.0, -2.0)
				_turned_back("guard")
	if _beam_t <= 0.0:
		_beam = {}


func _turned_back(how: String) -> void:
	## The beam went back to where it came from: Refracted (or a shard cracks).
	if _beam.is_empty() or bool(_beam["reflected"]):
		return
	_beam["reflected"] = true
	reflects += 1
	var hz = _beam.get("hazard", {})
	if hz is Dictionary and not (hz as Dictionary).is_empty():
		hz["life"] = 0.0   # (the rest of it is spent on the mirror or the shield)
	if how != "perfect":
		sfx("beam_reflect", "parry")   # (a Perfect Guard's the knight kit plays itself)
	var shard := int(_beam["shard"])
	if shard >= 0:
		_crack_shard(shard)
		return
	_refract()


func _refract() -> void:
	## Refracted: she cracks and sinks low over the nearest platform. The window.
	sfx("saint_refract", "glass_break")
	_crack = 0.6
	if world:
		world.shake = maxf(world.shake, 6.0)
		if world.glow:
			world.glow.burst(center(), 24, PRISM, 240.0, 0.5, 0.0, 2.4)
	_open_window()


func _open_window(keep_hover := false) -> void:
	## The window: she sinks low beside him over his footing (the platform
	## nearest him, not her: reflecting puts him on a mirror's far side, a gap
	## or two from her), and its clock starts as she arrives.
	if not keep_hover:
		var px: float = world.player.position.x if world != null and world.get("player") != null else position.x
		_hover_to = _hover_beside(px)
	_sink_t = 0.0
	state = "refracted"
	_window_t = window_len()
	timer = _window_t
	_window_dmg = 0.0
	window_stomps = 0
	windows_opened += 1
	move_id = ""
	_used("refracted")


func _end_window() -> void:
	state = "recover"
	timer = 2.0
	_window_dmg = 0.0
	move_id = ""


func _after_beam(player: Node2D) -> void:
	if state == "refracted":
		return
	_next_after(player)


# ---------------------------------------------------------------- the Rose, the Gale, Shatter, the Choir

func _rose(at: Vector2) -> void:
	## 8 blades out from the halo, 45 deg apart (P2 turns 22.5 deg a volley).
	var n := int(TUNE["blades"])
	var off := _rose_turn
	if phase >= 2:
		_rose_turn = fposmod(_rose_turn + PI / 8.0, TAU)
	for i in n:
		var a := off + TAU * i / float(n) - PI * 0.5
		blades.append({"p": at, "v": Vector2(cos(a), sin(a)) * float(TUNE["blade_speed"]), "life": float(TUNE["blade_life"]),
				"col": PANE_COLS[i % 3]})
	sfx("glass_shing", "slash")


func _step_blades(dt: float, player: Node2D) -> void:
	## The blades fly until stone (any solid: glass stops them too) or their
	## life; one that meets Wick hurts (kind "blade": any Perfect Guard throws
	## it back, knight.gd).
	for b in blades:
		b["life"] = float(b["life"]) - dt
		var nx: Vector2 = (b["p"] as Vector2) + (b["v"] as Vector2) * dt
		if solid_at(nx):
			b["life"] = 0.0
		b["p"] = nx
		if float(b["life"]) > 0.0 and player != null and player.alive and world != null and (player.rect() as Rect2).grow(-2.0).has_point(nx):
			b["life"] = 0.0
			var v: Vector2 = b["v"]
			world.hurt_player(dmg("rose"), nx.x - signf(v.x) * 20.0, "blade", null, {"shot": true, "vel": v, "pos": nx, "move": "saint:rose"})
	blades = blades.filter(func(b): return float(b["life"]) > 0.0)


func _may_shatter(i: int) -> bool:
	## Never a platform with no other footing within a jump (3 tiles across,
	## 3 rows up or down).
	if i < 0 or i >= platforms.size():
		return false
	var p: Dictionary = platforms[i]
	for q in platforms + stones:
		if q == p:
			continue
		var gap := maxf(float(q["x0"]) - float(p["x1"]), float(p["x0"]) - float(q["x1"]))
		if gap <= 3.0 * TILE and absf(float(q["y"]) - float(p["y"])) <= 3.0 * TILE:
			return true
	return false


func _gale_may_start(player: Node2D) -> bool:
	## Never while he's airborne over the void: it waits.
	return player == null or not HK.over_pit(world, player)


func _gale_push(player: Node2D) -> void:
	if player == null or not player.alive or world == null:
		return
	if on_stone(player):
		return   # stone footing is out of the wind (the pillar blocks it)
	world.push_player(Vector2(_gale_dir * float(TUNE["gale_push"]), 0.0), 0.12, "gust_saint")


func _shatter_now() -> void:
	if _shatter.is_empty():
		return
	var i := int(_shatter["i"])
	if i >= 0 and i < platforms.size() and world != null and world.get("features") != null:
		for c in platforms[i]["cells"]:
			world.features.break_glass(c)
	sfx("glass_shatter", "glass_break")
	if world and world.glow and i >= 0 and i < platforms.size():
		var p: Dictionary = platforms[i]
		world.glow.burst(Vector2((float(p["x0"]) + float(p["x1"])) * 0.5, float(p["y"])), 22, Color(0.85, 0.95, 1.0), 200.0, 0.5, 600.0, 2.2)
	_shatter = {}


func _choir() -> void:
	## The Stained Choir: 2 Paneguards out of the pillar (her first), then 3
	## Glassmites on the platforms and a Refractor (the second). Adds: no
	## loot, half XP, gone when she roars into the next phase.
	if world == null:
		return
	var second := _choirs_done.size() >= 2
	var spots: Array = []
	if not second:
		# Out of the pillar (the stone footing furthest from the door): never
		# onto the entry stone, where a fall into the void puts him back.
		var pil: Dictionary = stones.back() if not stones.is_empty() else {}
		if stones.size() >= 2:
			var far := -INF
			for st in stones:
				if float(st["x0"]) > far:
					far = float(st["x0"])
					pil = st
		if not pil.is_empty():
			var w := float(pil["x1"]) - float(pil["x0"])
			for k in 2:
				var sx := clampf(float(pil["x0"]) + w * (0.3 + 0.4 * k), arena_left + 20.0, arena_right - 20.0)
				spots.append(["paneguard", Vector2(sx, float(pil["y"]))])
	else:
		var pi := platform_of(world.player)
		var n := 0
		for k in platforms.size():
			if k == pi or n >= 3:
				continue   # (never onto his own platform)
			n += 1
			spots.append(["glassmite", Vector2((float(platforms[k]["x0"]) + float(platforms[k]["x1"])) * 0.5, float(platforms[k]["y"]))])
		spots.append(["refractor", Vector2((arena_left + arena_right) * 0.5, arena_top + 200.0)])
	for sp in spots:
		var e: Node2D = world.spawn_enemy(str(sp[0]), sp[1], {"respawned": true})
		if e:
			e.active = true
			if e.has_method("as_add"):
				e.as_add()
			_adds.append(e)
			if world.glow:
				world.glow.burst(e.center(), 14, PANE_COLS[_adds.size() % 3], 150.0, 0.5, 0.0, 2.4)


func _clear_adds() -> void:
	for e in _adds:
		if is_instance_valid(e) and e.alive:
			e.alive = false
			e.gone = true
	_adds.clear()


func _enter_phase() -> void:
	## A blow reached the line: the window ends, she roars into the next.
	_beam = {}
	_shatter = {}
	_lock_mirror = -1
	for m in mirrors:
		m["hold"] = false
	_clear_adds()
	_move_n = -1
	_window_dmg = 0.0
	move_id = ""
	fade = 1.0
	_rest = position
	state = "roar"
	timer = 1.2 if phase < 3 else 2.0
	sfx("saint_crack", "boss_roar")
	if world:
		world.shake = 8.0
		world.boss_phase(self, phase)
		if world.glow:
			world.glow.burst(center(), 30, PRISM, 260.0, 0.7, 0.0, 2.6)


func _break_mirror_for_good() -> void:
	## P3's roar: the mirror nearest the room's middle breaks (2 are left).
	var mid := (arena_left + arena_right) * 0.5
	var best := -1
	var bd := INF
	for i in mirrors.size():
		if mirrors[i]["broken"]:
			continue
		var d := absf(float(mirrors[i]["x"]) - mid)
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		mirrors[best]["broken"] = true
		sfx("glass_shatter", "glass_break")
		if world and world.glow:
			world.glow.burst(pane_rect(mirrors[best]).get_center(), 24, Color(0.9, 0.95, 1.0), 220.0, 0.6, 500.0, 2.4)


# ---------------------------------------------------------------- Scattered Dawn (P3)

func _start_split() -> void:
	## She bursts into three prism shards that orbit the room.
	state = "split"
	timer = float(TUNE["split"])
	move_id = ""
	sfx("saint_split", "glass_break")
	_used("split")
	shards.clear()
	var c := center()
	for i in 3:
		shards.append({"p": c, "ang": TAU * i / 3.0 - PI * 0.5, "cracked": false, "col": PANE_COLS[i], "hold": false, "crack_t": 0.0})
	_sh_i = 0
	if world and world.glow:
		for i in 3:
			world.glow.burst(c, 14, PANE_COLS[i], 240.0, 0.5, 0.0, 2.6)


func _orbit_center() -> Vector2:
	## (low enough that from the low platforms the shards stay in view)
	return Vector2((arena_left + arena_right) * 0.5, arena_top + 150.0)


func shard_home(i: int) -> Vector2:
	var s: Dictionary = shards[i]
	var rx := (arena_right - arena_left) * 0.36
	return _orbit_center() + Vector2(cos(float(s["ang"])) * rx, sin(float(s["ang"])) * 48.0)


func _orbit_shards(dt: float) -> void:
	if shards.is_empty():
		return
	var w := TAU / float(TUNE["orbit_period"])
	for i in shards.size():
		var s: Dictionary = shards[i]
		s["crack_t"] = maxf(float(s["crack_t"]) - dt, 0.0)
		if not s["hold"]:
			s["ang"] = float(s["ang"]) + w * dt
		var to := shard_home(i) if state in ["split", "scatter"] else center()
		s["p"] = (s["p"] as Vector2).move_toward(to, (420.0 if state != "scatter" else 160.0) * dt)


func shard_mask(i: int) -> Vector2:
	return (shards[i]["p"] as Vector2) + Vector2(0, -4) * DRAW_SCALE


func _scatter(dt: float, player: Node2D) -> void:
	## The P3 loop: a Rose from the shard to act, its beam (track, lock,
	## fire); a reflect cracks it; all three cracked: she re-forms, Refracted.
	match _sh_state:
		"gap":
			if timer <= 0.0:
				_sh_i = _next_uncracked(_sh_i)
				if _sh_i < 0:
					_reform()
					return
				_sh_state = "rose_tell"
				timer = tell(float(TUNE["rose_tell"]), float(TUNE["rose_floor"]))
				move_id = "saint:rose"
				tell_sfx("saint_rose", timer, "relic_rare")
				_used("rose")
		"rose_tell":
			if timer <= 0.0:
				_rose(shards[_sh_i]["p"])
				_sh_state = "wait"
				timer = 0.6
		"wait":
			if timer <= 0.0 and not shard_clear(_sh_i) and timer > -3.0:
				return   # (it orbits on until it's clear of every mirror)
			if timer <= 0.0:
				_sh_state = "track"
				shards[_sh_i]["hold"] = true
				_track_len = tell(float(TUNE["track"]), float(TUNE["track_floor"]))
				timer = _track_len
				move_id = "saint:shard_beam"
				_used("shard_beam")
				if player != null:
					_aim = player.center()
				tell_sfx("saint_charge", _track_len, "flare_charge")
		"track":
			if player != null and player.alive:
				_aim = player.center()
			bright = mirror_on(shard_mask(_sh_i), _aim)
			if timer <= 0.0:
				_lock(shard_mask(_sh_i), _aim, _sh_i)
				_sh_state = "lock"
				timer = _lock_len
		"lock":
			if timer <= 0.0:
				_fire(dmg("shard_beam"), "saint:shard_beam", _sh_i)
				_sh_state = "fire"
				timer = float(TUNE["fire"])
		"fire":
			if timer <= 0.0:
				if _sh_i >= 0 and _sh_i < shards.size():
					shards[_sh_i]["hold"] = false
				if state != "scatter":
					return
				_sh_state = "gap"
				timer = cd(float(TUNE["shard_gap"]))
				_sh_i = (_sh_i + 1) % 3
				move_id = ""


func shard_clear(i: int) -> bool:
	## A shard beams only from MIRROR_CLEAR px beside every live mirror's
	## track (as her hover points): a shard held next to a pane would have
	## every line start inside it and crack for nothing.
	if i < 0 or i >= shards.size():
		return true
	var pts := [shard_mask(i), shard_home(i) + Vector2(0, -4) * DRAW_SCALE]
	var w := float(TUNE["reflect_w"]) * 0.5
	for k in mirrors.size():
		if not mirror_live(k):
			continue
		var m: Dictionary = mirrors[k]
		var a: Vector2 = m["anchor"]
		var y0 := a.y - w
		var y1 := a.y + float(TUNE["mirror_track"]) + PANE.y + w
		for q in pts:
			if (q as Vector2).y >= y0 and (q as Vector2).y <= y1 and absf((q as Vector2).x - float(m["x"])) < MIRROR_CLEAR:
				return false
	return true


func _next_uncracked(from: int) -> int:
	for k in 3:
		var i := (from + k) % 3
		if i < shards.size() and not shards[i]["cracked"]:
			return i
	return -1


func _crack_shard(i: int) -> void:
	if i < 0 or i >= shards.size():
		return
	shards[i]["cracked"] = true
	shards[i]["crack_t"] = 0.6
	shards[i]["hold"] = false
	sfx("saint_crack", "glass_break")
	if world and world.glow:
		world.glow.burst(shards[i]["p"], 18, shards[i]["col"], 200.0, 0.5, 0.0, 2.4)
	if _next_uncracked(0) < 0:
		# All three: she re-forms, Refracted (the P3 window).
		_sh_state = ""
		_reform()


func _reform() -> void:
	## All three cracked: she re-forms over his footing, beside him, and the
	## Rose's tell plays as she does (the volley opens the window).
	state = "reform"
	_reform_len = maxf(float(TUNE["reform"]), tell(float(TUNE["rose_tell"]), float(TUNE["rose_floor"])))
	timer = _reform_len
	_beam = {}
	var px: float = world.player.position.x if world != null and world.get("player") != null else position.x
	_hover_to = _hover_beside(px)
	position = _hover_to + Vector2(0, -160.0)
	sfx("saint_refract", "glass_break")
	tell_sfx("saint_rose", _reform_len, "relic_rare")


# ---------------------------------------------------------------- defeat

func _dying(dt: float) -> void:
	## Her pieces fly back into a whole rose window high above; dawn pours
	## through it for 2 s; the bell comes down on a beam.
	if _dawn.is_empty():
		var win := Vector2(position.x, arena_top + 130.0)
		_dawn = {"t": 0.0, "window": win, "from": center(), "bell": {}}
		shards.clear()
		blades.clear()
		if world:
			world.shake = 8.0
	_dawn["t"] = float(_dawn["t"]) + dt
	var k := float(_dawn["t"])
	show_frame("saint_die")
	fade = clampf(1.0 - k * 1.6, 0.0, 1.0)
	queue_redraw()
	if k >= 1.2 and k - dt < 1.2 and world:
		world.add_light(_dawn["window"], 380.0, 0.95, 2.2, "deco", Color(1.0, 0.82, 0.55, 0.45))
		if world.glow:
			world.glow.burst(_dawn["window"], 40, Color(1.0, 0.88, 0.6), 280.0, 1.0, 120.0, 3.0)
		sfx("saint_die", "boss_die")
	if k >= 1.6 and k - dt < 1.6 and world:
		# The bell comes down on a beam onto the platform he's nearest.
		var wx: float = world.player.position.x if world.get("player") != null else position.x
		var p := footing_near(wx, true)
		var at := Vector2(wx, position.y)
		if not p.is_empty():
			at = Vector2((float(p["x0"]) + float(p["x1"])) * 0.5, float(p["y"]))
		world.add_light(at + Vector2(0, -120.0), 110.0, 0.8, 2.4, "deco", Color(1.0, 0.85, 0.55, 0.35))
		world.boss_defeated(self, at + Vector2(0, -40))
		var b: Dictionary = world.add_bell(at)
		_dawn["bell"] = b
		if b.has("sprite") and is_instance_valid(b["sprite"]):
			_dawn["bell_y"] = (b["sprite"] as Node2D).position.y
			(b["sprite"] as Node2D).position.y -= 220.0
	var bell: Dictionary = _dawn.get("bell", {})
	if not bell.is_empty() and bell.has("sprite") and is_instance_valid(bell["sprite"]):
		var s: Node2D = bell["sprite"]
		s.position.y = move_toward(s.position.y, float(_dawn["bell_y"]), 260.0 * dt)
	if k > 3.6:
		gone = true


# ---------------------------------------------------------------- the bot's thumbs

var _bot := {"jump": 0, "rest": 0, "atk": false, "spot": Vector2.INF, "src": Vector2.INF}


func bot_pad(pl: Node2D) -> Dictionary:
	## A pad that fights her (the --autoplay bot's, through world.boss's
	## bot_pad: W0 asked; the tests' real-pad runs): into the room; through a
	## beam's tracking onto the spot where a live mirror will stand between
	## them at the lock (what the brightening mirror tells a player); off a
	## locked line that won't reflect; off a platform about to shatter; in a
	## window beside her, striking. It dodges nothing else. {} once she's
	## down (the bell is the World's bot's).
	if pl == null or not pl.alive or world == null or not alive:
		return {}
	var pad := {}
	var want := Vector2.INF
	var strike := false
	var dodge := {}
	match state:
		"refracted":
			want = _bot_beside(pl, _hover_to)
			strike = absf(pl.position.x - position.x) < 70.0 and absf(pl.position.y - (_hover_to.y + float(TUNE["refract_hover"]))) < 8.0
		"reform":
			want = _bot_beside(pl, _hover_to)
		"track":
			want = _bot_mirror_spot(pl, mask(), timer)
		"lock", "fire":
			if _lock_mirror < 0 and state == "lock":
				dodge = {"a": _lock_a, "b": _lock_b, "t": timer}
		"shatter_tell":
			var i := int(_shatter.get("i", -1))
			if i >= 0 and platform_of(pl) == i:
				want = _bot_off_platform(pl, i)
		"scatter":
			match _sh_state:
				"track":
					want = _bot_mirror_spot(pl, shard_mask(_sh_i), timer)
				"lock":
					if _lock_mirror < 0:
						dodge = {"a": _lock_a, "b": _lock_b, "t": timer}
		"sleep", "wake":
			if not platforms.is_empty():
				want = Vector2((float(platforms[0]["x0"]) + float(platforms[0]["x1"])) * 0.5, float(platforms[0]["y"]))
	if want == Vector2.INF and dodge.is_empty() and not (state in ["lock", "fire"]) and not (state == "scatter" and _sh_state in ["lock", "fire"]):
		# Between moves: where the next beam will come from (her next hover
		# point, the next shard's place on its orbit), onto its mirror's spot early.
		var nx := _bot_next_src()
		if not nx.is_empty():
			want = _bot_mirror_spot(pl, nx["src"], float(nx["ahead"]))
	if want == Vector2.INF and dodge.is_empty():
		# Else the spot kept.
		var sp: Vector2 = _bot["spot"]
		if sp != Vector2.INF and _bot_spot_whole(sp):
			want = sp
	if pl.on_floor and pl.riding == null and not (_bot_spot_whole(pl.position + Vector2(-8.0, 0.0)) and _bot_spot_whole(pl.position + Vector2(8.0, 0.0))):
		# The glass under him is breaking: off it first.
		var safe := _bot_safe_spot(pl)
		if safe != Vector2.INF:
			want = safe
			dodge = {}
	var refr_t := INF
	if dodge.is_empty() and state != "refracted":
		# Her Choir's Refractor locking its beam on him: off its line too, or
		# over it (the rev5 review: its locked line took most of a
		# Taperwitch's life). Its line is aimed at him, so along his footing
		# there's often no way off it: then a jump timed to be high as it fires.
		for e in _adds:
			if is_instance_valid(e) and e.alive and not e.gone and str(e.get("state")) == "lock" and e.get("lines") is Array and not (e.get("lines") as Array).is_empty():
				var ln: Array = (e.get("lines") as Array)[0]
				if ln.size() >= 2 and seg_hits(ln[0], ln[0] + ((ln[1] as Vector2) - (ln[0] as Vector2)).normalized() * 2000.0, 18.0, (pl.rect() as Rect2).grow(4.0)):
					dodge = {"a": ln[0], "b": ln[1], "t": float(e.get("timer"))}
					refr_t = float(e.get("timer"))
					break
	if want != Vector2.INF:
		_bot["spot"] = want
		pad = _bot_nav(pl, want)
	if not dodge.is_empty():
		pad = _bot_dodge(pl, dodge)
		if refr_t < INF and not pad.has("left") and not pad.has("right") and pl.on_floor and refr_t <= 0.32:
			pad["jump"] = true
	var foe_x := position.x if strike else INF
	if not strike and dodge.is_empty():
		# Her Choir's adds that come at him: struck back.
		for e in _adds:
			if is_instance_valid(e) and e.alive and not e.gone and absf(e.position.x - pl.position.x) < 56.0 and absf(e.position.y - pl.position.y) < 40.0:
				foe_x = e.position.x
				break
	if foe_x != INF:
		var dir := signf(foe_x - pl.position.x)
		if dir != 0.0 and int(pl.facing) != int(dir):
			pad.erase("left")
			pad.erase("right")
			pad["left" if dir < 0.0 else "right"] = true
		_bot["atk"] = not bool(_bot["atk"])
		pad["attack"] = _bot["atk"]
	_bot_jump(pad)
	return pad


func _bot_beside(pl: Node2D, hover: Vector2) -> Vector2:
	## Where to stand to strike her low hover: 38 px to his side of her on
	## that footing (the other side when the footing ends), never on her.
	var f := footing_near(hover.x)
	var y := hover.y + float(TUNE["refract_hover"])
	if f.is_empty():
		return Vector2(hover.x, y)
	var lo := float(f["x0"]) + 10.0
	var hi := float(f["x1"]) - 10.0
	var side := 1.0 if pl.position.x >= hover.x else -1.0
	var x := hover.x + side * 38.0
	if x < lo or x > hi:
		x = hover.x - side * 38.0
	return Vector2(clampf(x, lo, hi), float(f["y"]))


func _bot_next_src() -> Dictionary:
	## The next beam's source and how long until its lock: her mask at the
	## hover point she's gliding to (a beam next), or the next shard's mask
	## where its orbit will hold it.
	var mo := mask() - position
	var track := tell(float(TUNE["track"]), float(TUNE["track_floor"]))
	if state == "glide" and _next == "beam" and _station < stations.size():
		var to: Vector2 = stations[_station]
		return {"src": to + mo, "ahead": position.distance_to(to) / maxf(spd(float(TUNE["glide"])), 1.0) + track}
	if state == "scatter" and _sh_state in ["gap", "rose_tell", "wait"] and not shards.is_empty():
		var i := _sh_i
		var eta := 0.0
		var rose := tell(float(TUNE["rose_tell"]), float(TUNE["rose_floor"]))
		match _sh_state:
			"gap":
				i = _next_uncracked(_sh_i)
				eta = maxf(timer, 0.0) + rose + 0.6
			"rose_tell":
				eta = maxf(timer, 0.0) + 0.6
			"wait":
				eta = maxf(timer, 0.0)
		if i < 0 or i >= shards.size():
			return {}
		var a := float(shards[i]["ang"]) + (0.0 if shards[i]["hold"] else TAU / float(TUNE["orbit_period"]) * eta)
		var rx := (arena_right - arena_left) * 0.36
		var home := _orbit_center() + Vector2(cos(a) * rx, sin(a) * 48.0)
		return {"src": home + Vector2(0, -4) * DRAW_SCALE, "ahead": eta + track}
	return {}


func _bot_spots() -> Array:
	## Where he can stand now: every 8 px of whole footing.
	var out: Array = []
	for r in platforms + stones:
		var m := 20.0 if float(r["x1"]) - float(r["x0"]) > 80.0 else 12.0   # (off the edges: a knock there is the void)
		var x := float(r["x0"]) + m
		while x <= float(r["x1"]) - m:
			if _bot_spot_whole(Vector2(x, float(r["y"]))):
				out.append(Vector2(x, float(r["y"])))
			x += 8.0
	return out


func _bot_spot_whole(p: Vector2, landing := false) -> bool:
	## Footing under p that holds: stone, or whole glass (with landing, one a
	## landing won't break: the arena's glass cracks a step at each landing).
	var c := Vector2i(floori(p.x / TILE), floori((p.y + 1.0) / TILE))
	if not LevelData.is_solid(level.tile(c.x, c.y)):
		return false
	if level.tile(c.x, c.y) != LevelData.GLASS or world == null or world.get("features") == null:
		return true
	var g = world.features.module("glass") if world.features.has_method("module") else null
	if g == null or not (g.get("panes") is Dictionary):
		return true
	var pn: Dictionary = (g.panes as Dictionary).get(c, {})
	if pn.is_empty():
		return true
	return str(pn["state"]) == "whole" and (not landing or float(pn["strain"]) <= 0.55)


func _pane_ahead(m: Dictionary, ahead: float) -> Rect2:
	if m["hold"]:
		return pane_rect(m)
	var travel := float(TUNE["mirror_track"])
	var w := float(TUNE["mirror_speed"]) / (travel * 0.5)
	var a: Vector2 = m["anchor"]
	var top := a.y + travel * 0.5 - travel * 0.5 * cos((float(m["t"]) + ahead) * w + float(m["ph"]))
	return Rect2(float(m["x"]) - PANE.x * 0.5, top, PANE.x, PANE.y)


func _bot_reflects(src: Vector2, feet: Vector2, ahead: float) -> bool:
	## A mirror will stand between src and him at feet at the lock (a line
	## narrower than the real test: the bot wants the middle of the shadow).
	var c := feet + Vector2(0, -19.0)
	for i in mirrors.size():
		var m: Dictionary = mirrors[i]
		if m["broken"] or float(m["dim"]) - ahead > 0.0:
			continue
		var r := _pane_ahead(m, ahead)
		if r.grow(float(TUNE["reflect_w"]) * 0.5).has_point(src):
			continue
		if seg_hits(src, c, 8.0, r) and seg_hits(src, c, 8.0, _pane_ahead(m, ahead + 0.15)) and seg_hits(src, c, 8.0, _pane_ahead(m, maxf(ahead - 0.15, 0.0))):
			return true
	return false


func _bot_eta(pl: Node2D, to: Vector2) -> float:
	var hops := 0 if absf(to.y - pl.position.y) < 2.0 and _bot_same_run(pl.position, to) else 1 + int(absf(to.x - pl.position.x) / 224.0)
	return absf(to.x - pl.position.x) / 205.0 + 0.3 * hops


func _bot_same_run(a: Vector2, b: Vector2) -> bool:
	for r in platforms + stones:
		var y := float(r["y"])
		if absf(a.y - y) < 3.0 and absf(b.y - y) < 3.0 and a.x >= float(r["x0"]) - 8.0 and a.x <= float(r["x1"]) + 8.0 \
				and b.x >= float(r["x0"]) - 8.0 and b.x <= float(r["x1"]) + 8.0:
			return true
	return false


func _bot_mirror_spot(pl: Node2D, src: Vector2, left: float) -> Vector2:
	## The nearest spot a mirror will turn the beam from, reachable before
	## the lock; the one kept while it still works.
	var keep: Vector2 = _bot["spot"]
	if keep != Vector2.INF and (_bot["src"] as Vector2).distance_to(src) < 12.0 and _bot_spot_whole(keep) and _bot_reflects(src, keep, left):
		return keep
	var best := Vector2.INF
	var bt := INF
	for sp in _bot_spots():
		var eta := _bot_eta(pl, sp)
		if eta > left - 0.08 or eta >= bt:
			continue
		if not _bot_same_run(pl.position, sp) and not _bot_spot_whole(sp, true):
			continue
		if _bot_reflects(src, sp, left):
			bt = eta
			best = sp
	_bot["src"] = src
	if best == Vector2.INF:
		return Vector2(pl.position.x, pl.position.y) if pl.on_floor else Vector2.INF
	return best


func _bot_off_platform(pl: Node2D, i: int) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for sp in _bot_spots():
		if platform_of_x(sp) == i:
			continue
		var d := absf(sp.x - pl.position.x) + absf(sp.y - pl.position.y) * 0.5
		if d < bd:
			bd = d
			best = sp
	return best


func platform_of_x(p: Vector2) -> int:
	for i in platforms.size():
		var q: Dictionary = platforms[i]
		if absf(float(q["y"]) - p.y) < 2.0 and p.x >= float(q["x0"]) - 6.0 and p.x <= float(q["x1"]) + 6.0:
			return i
	return -1


func _bot_runs() -> Array:
	## The footing as it is now: each platform split where its glass is
	## gone or breaking (a hole is a gap to jump), and the stone.
	var out: Array = []
	for r in platforms + stones:
		if not r.has("cells"):
			out.append({"x0": float(r["x0"]), "x1": float(r["x1"]), "y": float(r["y"])})
			continue
		var x0 := -1.0
		for c in r["cells"]:
			var cx := float((c as Vector2i).x * TILE)
			var ok := _bot_spot_whole(Vector2(cx + 16.0, float(r["y"])))
			if ok and x0 < 0.0:
				x0 = cx
			elif not ok and x0 >= 0.0:
				out.append({"x0": x0, "x1": cx, "y": float(r["y"])})
				x0 = -1.0
		if x0 >= 0.0:
			out.append({"x0": x0, "x1": float(r["x1"]), "y": float(r["y"])})
	return out


func _bot_run_at(p: Vector2) -> Dictionary:
	for r in _bot_runs():
		if absf(p.y - float(r["y"])) < 3.0 and p.x >= float(r["x0"]) - 8.0 and p.x <= float(r["x1"]) + 8.0:
			return r
	return {}


func _bot_nav(pl: Node2D, to: Vector2) -> Dictionary:
	## Walk to x on the run at y, a gap at a time: at the edge toward it he
	## jumps (held), and in the air steers onto the run he jumped for (every
	## gap in the nave is 2 tiles, every step 2 rows).
	var pad := {}
	var cur := _bot_run_at(pl.position) if pl.on_floor else {}
	if cur.is_empty():
		var land: Dictionary = _bot.get("land", {})
		if land.is_empty() or float(land["y"]) < pl.position.y - 2.0:
			# (no run chosen, or he's already under it: the nearest run below)
			land = {}
			var bd := INF
			for r in _bot_runs():
				if float(r["y"]) < pl.position.y - 2.0:
					continue
				var d := 0.0 if pl.position.x >= float(r["x0"]) and pl.position.x <= float(r["x1"]) else minf(absf(pl.position.x - float(r["x0"])), absf(pl.position.x - float(r["x1"])))
				if d < bd:
					bd = d
					land = r
		if land.is_empty():
			return pad
		var ax := clampf(to.x if _bot_run_at(to) == land else pl.position.x, float(land["x0"]) + 16.0, float(land["x1"]) - 16.0)
		# (onto glass that will hold him)
		var bx := ax
		var bd2 := INF
		var x := float(land["x0"]) + 12.0
		while x <= float(land["x1"]) - 12.0:
			if _bot_spot_whole(Vector2(x, float(land["y"])), true) and absf(x - ax) < bd2:
				bd2 = absf(x - ax)
				bx = x
			x += 8.0
		ax = bx
		if absf(ax - pl.position.x) > 4.0:
			pad["left" if ax < pl.position.x else "right"] = true
		return pad
	_bot["land"] = {}
	var tr := _bot_run_at(to)
	var dx := to.x - pl.position.x
	if tr == cur or tr.is_empty():
		if absf(dx) > 5.0:
			pad["left" if dx < 0.0 else "right"] = true
		return pad
	var dir := 1.0 if float(tr["x0"]) > float(cur["x0"]) else -1.0
	var next := {}
	var nd := INF
	for r in _bot_runs():
		var gap := float(r["x0"]) - float(cur["x1"]) if dir > 0.0 else float(cur["x0"]) - float(r["x1"])
		if gap >= -1.0 and gap < nd:
			nd = gap
			next = r
	var edge := float(cur["x1"]) if dir > 0.0 else float(cur["x0"])
	if next.is_empty() or not _bot_can_land(next, dir):
		# (nothing there that would hold him yet: wait at the edge)
		if absf(edge - pl.position.x) > 30.0:
			pad["left" if dir < 0.0 else "right"] = true
		return pad
	pad["left" if dir < 0.0 else "right"] = true
	if absf(edge - pl.position.x) < 16.0:
		_bot_start_jump()
		_bot["land"] = next
	return pad


func _bot_safe_spot(pl: Node2D) -> Vector2:
	## The nearest footing that holds: along his own run first.
	var best := Vector2.INF
	var bd := INF
	for sp in _bot_spots():
		if not (_bot_spot_whole(sp + Vector2(-8.0, 0.0)) and _bot_spot_whole(sp + Vector2(8.0, 0.0))):
			continue
		var d := absf(sp.x - pl.position.x) + (0.0 if absf(sp.y - pl.position.y) < 2.0 else 120.0)
		if d < bd:
			bd = d
			best = sp
	return best


func _bot_can_land(r: Dictionary, dir: float) -> bool:
	## Glass that would hold a landing within a jump of its near edge.
	var near := float(r["x0"]) if dir > 0.0 else float(r["x1"])
	for k in 12:
		var x := near + dir * (12.0 + k * 8.0)
		if x < float(r["x0"]) or x > float(r["x1"]):
			break
		if _bot_spot_whole(Vector2(x, float(r["y"])), true):
			return true
	return false


func _bot_dodge(pl: Node2D, d: Dictionary) -> Dictionary:
	## Off a locked line that won't reflect: along his footing to the nearest
	## spot whose body clears the line and whose glass it won't break; up over
	## it as it fires when there's none.
	var pad := {}
	var a: Vector2 = d["a"]
	var b: Vector2 = d["b"]
	var cut: Array = beam_path(a, b)["glass"]
	var cur := footing_near(pl.position.x)
	var best := INF
	if not cur.is_empty() and pl.on_floor:
		var reach := 205.0 * maxf(float(d["t"]) - 0.04, 0.0) + 2.0
		var x := float(cur["x0"]) + 12.0
		while x <= float(cur["x1"]) - 12.0:
			if absf(x - pl.position.x) <= reach and absf(x - pl.position.x) < absf(best - pl.position.x) and _bot_spot_whole(Vector2(x, float(cur["y"]))):
				var body := Rect2(x - 10.0, float(cur["y"]) - 38.0, 20.0, 38.0)
				var row := floori((float(cur["y"]) + 1.0) / TILE)
				var safe := not seg_hits(a, a + (b - a).normalized() * 2000.0, float(TUNE["beam_w"]) + 8.0, body)
				for cx in [floori((x - 9.0) / TILE), floori((x + 9.0) / TILE)]:
					if cut.has(Vector2i(cx, row)):
						safe = false
				if safe:
					best = x
			x += 4.0
	if best != INF:
		if absf(best - pl.position.x) > 2.0:
			pad["left" if best < pl.position.x else "right"] = true
		return pad
	if float(d["t"]) <= 0.06:
		_bot_start_jump()
	return pad


func _bot_start_jump() -> void:
	if int(_bot["jump"]) <= 0 and int(_bot["rest"]) <= 0:
		_bot["jump"] = 36


func _bot_jump(pad: Dictionary) -> void:
	## A jump: pressed, held 0.3 s for its height, then let go a moment.
	if int(_bot["jump"]) > 0:
		_bot["jump"] = int(_bot["jump"]) - 1
		pad["jump"] = true
		if int(_bot["jump"]) == 0:
			_bot["rest"] = 3
	elif int(_bot["rest"]) > 0:
		_bot["rest"] = int(_bot["rest"]) - 1


# ---------------------------------------------------------------- the look

func lights() -> Array:
	## At most 20 in the fight (spec): the halo, the beam, the mirrors, up to
	## four blades, the shards.
	var out: Array = []
	if not alive:
		return out
	if state != "sleep" and not (state in ["split", "scatter"]):
		var charging := state in ["track", "lock", "rose_tell"]
		out.append({"p": halo_center(), "r": 150.0 if charging else 110.0, "s": 0.75, "tint": Color(0.9, 0.85, 1.0, 0.25)})
	elif state == "sleep":
		out.append({"p": halo_center(), "r": 90.0, "s": 0.6})
	for i in mirrors.size():
		var m: Dictionary = mirrors[i]
		if m["broken"]:
			continue
		var lit := i == bright or i == _lock_mirror
		out.append({"p": pane_rect(m).get_center(), "r": 60.0 if lit else 34.0, "s": 0.7 if lit else 0.35})
	if not _beam.is_empty():
		out.append({"p": ((_beam["a"] as Vector2) + (_beam["b"] as Vector2)) * 0.5, "r": 110.0, "s": 0.8})
	var n := 0
	for b in blades:
		if n >= 4:
			break
		out.append({"p": b["p"], "r": 26.0, "s": 0.5})
		n += 1
	for s in shards:
		out.append({"p": s["p"], "r": 56.0, "s": 0.6 if not s["cracked"] else 0.3})
	return out


func eye_points() -> Array:
	return []   # her eyes are closed


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if BossMods.of(self) != null:
		BossMods.of(self).draw_glow(glow)
	var tb := _tb
	# The mirrors' bright rims, always (they read in the dark), brighter on
	# the one that would reflect from where he stands; a dimmed one is cracked.
	for i in mirrors.size():
		var m: Dictionary = mirrors[i]
		if m["broken"]:
			continue
		var r := pane_rect(m)
		var lit := i == bright or i == _lock_mirror
		var dim := float(m["dim"]) > 0.0
		var a := 0.95 if lit else (0.25 if dim else 0.5)
		var col := Color(1, 1, 1) if lit else Color(0.82, 0.9, 1.0)
		if lit:
			tb.rect(r.grow(4.0), Color(1, 1, 1, 0.12 + 0.06 * sin(t * 18.0)))
		_rim(tb, r, 1.6 if not lit else 2.4, Color(col, a))
		if dim:
			tb.line(r.position + Vector2(3, 10), r.position + Vector2(13, 30), 1.2, Color(1, 1, 1, 0.4))
			tb.line(r.position + Vector2(12, 26), r.position + Vector2(4, 44), 1.2, Color(1, 1, 1, 0.4))
		if float(m["flash"]) > 0.0:
			tb.rect(r.grow(3.0), Color(1, 1, 1, float(m["flash"])))
	# The tells.
	match state:
		"track":
			_draw_aim(tb, mask(), _aim, 1.0 - clampf(timer / maxf(_track_len, 0.01), 0.0, 1.0))
		"lock":
			_draw_locked(tb, 1.0 - clampf(timer / maxf(_lock_len, 0.01), 0.0, 1.0))
		"rose_tell":
			_draw_rose_tell(tb, halo_center())
		"gale_tell", "gale":
			_draw_gale(tb)
		"shatter_tell":
			_draw_shatter(tb)
		"choir":
			tb.ring(heart(), 18.0 + 40.0 * (1.0 - clampf(timer / float(TUNE["choir"]), 0.0, 1.0)), 3.0, Color(LILAC, 0.6), 24)
		"refracted":
			_draw_cracks(tb)
		"reform":
			_draw_cracks(tb)
			_draw_rose_tell(tb, halo_center(), _reform_len)
	if state == "scatter":
		match _sh_state:
			"track":
				_draw_aim(tb, shard_mask(_sh_i), _aim, 1.0 - clampf(timer / maxf(_track_len, 0.01), 0.0, 1.0))
			"lock":
				_draw_locked(tb, 1.0 - clampf(timer / maxf(_lock_len, 0.01), 0.0, 1.0))
			"rose_tell":
				if _sh_i >= 0 and _sh_i < shards.size():
					_draw_rose_tell(tb, shards[_sh_i]["p"])
	for i in shards.size():
		var s: Dictionary = shards[i]
		var p: Vector2 = s["p"]
		tb.ring(p, 22.0, 1.5, Color(s["col"], 0.55 if not s["cracked"] else 0.25), 18)
		if s["cracked"]:
			tb.line(p + Vector2(-8, -14), p + Vector2(4, 2), 1.6, Color(1, 1, 1, 0.8))
			tb.line(p + Vector2(4, 2), p + Vector2(-2, 16), 1.6, Color(1, 1, 1, 0.8))
		if float(s["crack_t"]) > 0.0:
			tb.circle(p, 26.0 * (1.2 - float(s["crack_t"])), Color(1, 1, 1, float(s["crack_t"])), 16)
		if i == _sh_i and _sh_state in ["track", "lock", "fire"]:
			tb.circle(shard_mask(i), 4.0, Color(1, 1, 1, 0.95), 10)
	# The beam.
	if not _beam.is_empty():
		var a: Vector2 = _beam["a"]
		var b: Vector2 = _beam["b"]
		if (_beam["cut"] as Vector2) != Vector2.INF:
			b = _beam["cut"]
		var w := float(TUNE["beam_w"])
		var o := (b - a).normalized().orthogonal()
		for i in 3:
			tb.line(a + o * (i - 1) * w * 0.8, b + o * (i - 1) * w * 0.8, w * 0.6, Color(PANE_COLS[i], 0.45))
		tb.line(a, b, w, Color(1, 1, 1, 0.55))
		tb.line(a, b, w * 0.45, Color(1, 1, 1, 1.0))
		tb.circle(b, w, Color(1, 1, 1, 0.7), 12)
		if bool(_beam["reflected"]):
			# Straight back to her, a hair beside the way it came.
			tb.line(b + o * 5.0, a + o * 5.0, 4.0, Color(1.0, 0.95, 0.8, 0.9))
			tb.circle(a, 14.0, Color(1, 1, 1, 0.5), 14)
	# The blades: glass slivers point first, a dark edge round a bright pane,
	# a short trail behind (so their line reads in flight, in the dark).
	for bl in blades:
		var p: Vector2 = bl["p"]
		var d := (bl["v"] as Vector2).normalized()
		var n := d.orthogonal()
		var bc: Color = bl["col"]
		tb.line(p - d * 26.0, p - d * 6.0, 2.0, Color(bc, 0.28))
		tb.circle(p, 10.0, Color(bc, 0.2), 12)
		tb.convex(PackedVector2Array([p + d * 13.0, p + n * 4.5, p - d * 8.0, p - n * 4.5]), Color(0.08, 0.06, 0.14, 0.95))
		tb.convex(PackedVector2Array([p + d * 11.0, p + n * 2.8, p - d * 6.0, p - n * 2.8]), Color(bc.lerp(Color.WHITE, 0.55), 1.0))
	# Asleep or awake: the heart pane's small candle glows (Tessel).
	if alive and not (state in ["split", "scatter"]):
		var hc := heart()
		tb.circle(hc + Vector2(0, -6), 3.0, Color(1.0, 0.85, 0.5, 0.85), 8)
		tb.circle(hc + Vector2(0, -6), 7.0, Color(1.0, 0.8, 0.45, 0.2), 10)
	tb.flush(glow)


func _draw_dawn(tb: RefCounted) -> void:
	## The defeat: twelve panes fly from where she fell up into a whole rose
	## window high above, which then glows with the dawn.
	var k := clampf(float(_dawn["t"]) / 1.2, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var win: Vector2 = (_dawn["window"] as Vector2) - position
	var from: Vector2 = (_dawn["from"] as Vector2) - position
	var glow_a := clampf((float(_dawn["t"]) - 1.0) * 2.0, 0.0, 1.0) * clampf((3.6 - float(_dawn["t"])) * 1.5, 0.0, 1.0)
	for i in 12:
		var a0 := TAU * i / 12.0
		var a1 := TAU * (i + 1) / 12.0
		var spread := from + Vector2(cos(a0 * 3.0 + 1.0), sin(a0 * 2.0)) * 60.0 * (1.0 - e)
		var c: Vector2 = spread.lerp(win, e)
		var r := 16.0 + 30.0 * e
		var col: Color = (PANE_COLS[i % 3] as Color).lerp(Color(1.0, 0.95, 0.85), 0.25 + 0.5 * glow_a)
		tb.convex(PackedVector2Array([c.lerp(win, e * 0.7), c + Vector2(cos(a0), sin(a0)) * r * (1.0 - e * 0.5),
				c + Vector2(cos(a1), sin(a1)) * r * (1.0 - e * 0.5)]), Color(col, 0.9))
	if e >= 1.0:
		tb.ring(win, 46.0, 5.0, Color(0.2, 0.16, 0.24, 0.95), 36)
		tb.circle(win, 12.0, Color(1.0, 0.95, 0.8, 0.6 + 0.4 * glow_a), 18)
		for i in 12:
			var a := TAU * i / 12.0
			tb.line(win + Vector2(cos(a), sin(a)) * 12.0, win + Vector2(cos(a), sin(a)) * 44.0, 2.0, Color(0.2, 0.16, 0.24, 0.9))


func _rim(tb: RefCounted, r: Rect2, w: float, col: Color) -> void:
	tb.rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	tb.rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), col)
	tb.rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	tb.rect(Rect2(r.position + Vector2(r.size.x - w, 0), Vector2(w, r.size.y)), col)


func _draw_aim(tb: RefCounted, a: Vector2, b: Vector2, k: float) -> void:
	## The aim line from her mask to Wick (a thin rainbow over a dark edge,
	## so it reads on glass and in the dark); with a mirror in the way, the
	## reflection back to her is drawn too, gold, with a glint on the pane,
	## and past the mirror the line to him goes faint (it won't get there).
	var i := mirror_on(a, b)
	var end := b
	if i >= 0:
		end = _clip_to(a, b, pane_rect(mirrors[i]))
	var o := (b - a).normalized().orthogonal()
	tb.line(a, end, 4.0, Color(0.05, 0.03, 0.1, 0.35 + 0.2 * k))
	for j in 3:
		tb.line(a + o * (j - 1) * 1.6, end + o * (j - 1) * 1.6, 1.4, Color(PANE_COLS[j], 0.5 + 0.4 * k))
	tb.line(a, end, 1.0, Color(1, 1, 1, 0.5 + 0.4 * k))
	if i >= 0:
		_dash_line(tb, end, b, 1.2, Color(1, 1, 1, 0.22 + 0.15 * k))
		tb.line(end + o * 5.0, a + o * 5.0, 2.4, Color(1.0, 0.9, 0.55, 0.65 + 0.35 * k))
		var g := 6.0 + 5.0 * sin(t * 14.0)
		tb.circle(end, 5.0, Color(1, 1, 1, 0.5), 10)
		tb.line(end + Vector2(-g, 0), end + Vector2(g, 0), 1.8, Color(1, 1, 1, 0.95))
		tb.line(end + Vector2(0, -g), end + Vector2(0, g), 1.8, Color(1, 1, 1, 0.95))
	else:
		tb.ring(b, 13.0 - 4.0 * k, 1.6, Color(1, 1, 1, 0.4 + 0.45 * k), 16)


func _dash_line(tb: RefCounted, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := b - a
	var n := int(d.length() / 12.0)
	for i in n:
		tb.line(a + d * (float(i) / maxf(n, 1)), a + d * ((i + 0.5) / maxf(n, 1)), w, col)


func _draw_locked(tb: RefCounted, k: float) -> void:
	var a := _lock_a
	var b := _lock_b
	var reflect := _lock_mirror >= 0
	var end: Vector2 = _clip_to(a, b, pane_rect(mirrors[_lock_mirror])) if reflect else beam_path(a, b)["end"]
	var pulse := 0.8 + 0.2 * sin(t * 40.0)
	tb.line(a, end, 7.0 + k * 2.0, Color(0.05, 0.03, 0.1, 0.4))
	tb.line(a, end, 6.0 + k * 2.0, Color(1, 1, 1, 0.16 + 0.14 * k))
	tb.line(a, end, 2.4 + k * 1.4, Color(1, 1, 1, (0.8 + 0.2 * k) * pulse))
	if reflect:
		var o := (end - a).normalized().orthogonal()
		_dash_line(tb, end, b, 1.2, Color(1, 1, 1, 0.25))
		tb.line(end + o * 5.0, a + o * 5.0, 2.6, Color(1.0, 0.9, 0.55, 0.9 * pulse))
		tb.circle(end, 6.0 + 4.0 * k, Color(1, 1, 1, 0.8), 12)


func _draw_rose_tell(tb: RefCounted, c: Vector2, len_s := -1.0) -> void:
	## The halo spins up and 8 blades gather glowing on its rim, pointing out
	## the way they'll fly.
	if len_s <= 0.0:
		len_s = tell(float(TUNE["rose_tell"]), float(TUNE["rose_floor"]))
	var k := 1.0 - clampf(timer / maxf(len_s, 0.01), 0.0, 1.0)
	var n := int(TUNE["blades"])
	for i in n:
		var a := _rose_turn + TAU * i / float(n) - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		var p := c + d * (40.0 + 10.0 * k)
		tb.line(p, p + d * (6.0 + 16.0 * k), 2.0, Color((PANE_COLS[i % 3] as Color).lerp(Color.WHITE, 0.5), 0.5 + 0.5 * k))
	tb.ring(c, 44.0, 2.0, Color(1, 1, 1, 0.25 + 0.5 * k), 28)


func _draw_gale(tb: RefCounted) -> void:
	## The Gale Hymn's wind: while she sings (the tell) faint wisps and glass
	## glints gather on his side of the room; then soft tapered ribbons, a
	## prism's colours on their heads, curl across the air with specks of
	## glass carried along, only above the floors (never over the HUD's band
	## or into the stone).
	var v: Rect2 = world.view_rect() if world != null else Rect2(arena_left, arena_top, arena_right - arena_left, 380)
	var telling := state == "gale_tell"
	var k := 1.0 - clampf(timer / maxf(tell(float(TUNE["gale_tell"]), float(TUNE["gale_floor"])), 0.01), 0.0, 1.0) if telling else 1.0
	var top := maxf(arena_top + 30.0, v.position.y + 60.0)
	var bot := 0.0
	for p in platforms:
		bot = maxf(bot, float(p["y"]))
	bot = minf(bot - 6.0, v.end.y - 20.0)
	var band := bot - top
	if band <= 10.0:
		return
	var dir := float(_gale_dir)
	var x0 := arena_left
	var x1 := arena_right
	var span := x1 - x0
	var upwind := x0 if dir > 0.0 else x1
	var a := (0.16 + 0.30 * k) if telling else 0.42
	var lanes := 5 if telling else 10
	for i in lanes:
		var r1 := fposmod(sin(i * 12.9898 + 3.1) * 43758.5453, 1.0)
		var r2 := fposmod(sin(i * 78.233 + 1.7) * 12543.917, 1.0)
		var y := top + band * (i + 0.5) / float(lanes) + sin(t * 1.6 + i * 2.1) * 6.0
		var length := (14.0 + 14.0 * r1) * (0.5 + k) if telling else (44.0 + 60.0 * r1)
		var speed := (60.0 + 40.0 * r2) if telling else (260.0 + 110.0 * r2)
		var room := span * (0.22 + 0.12 * k) if telling else span
		var head := fposmod(t * speed + i * 131.0 + r2 * span, room)
		var hx := (upwind + head) if dir > 0.0 else (upwind - head)
		if hx < v.position.x - 80.0 or hx > v.end.x + 80.0:
			continue
		var col: Color = (PANE_COLS[i % 3] as Color).lerp(Color(0.9, 0.95, 1.0), 0.6)
		for sgm in 5:
			var f := float(sgm) / 5.0
			var sx := hx - dir * length * (1.0 - f)
			var ex := sx + dir * length / 5.0
			if minf(sx, ex) < x0 or maxf(sx, ex) > x1:
				continue
			var curl := sin((sx / 60.0) + t * 2.4 + i) * 3.0
			var curl2 := sin((ex / 60.0) + t * 2.4 + i) * 3.0
			tb.line(Vector2(sx, y + curl), Vector2(ex, y + curl2), 0.8 + 1.6 * f, Color(col, a * (0.25 + 0.75 * f)))
	# Glass glints tumbling along (a few, slow, while it gathers).
	var specks := 6 if telling else 16
	for j in specks:
		var q1 := fposmod(sin(j * 3.7 + 0.9) * 9731.1, 1.0)
		var q2 := fposmod(sin(j * 9.1 + 2.3) * 5113.7, 1.0)
		var sp := (40.0 + 30.0 * q2) if telling else (280.0 + 130.0 * q2)
		var room2 := span * 0.3 if telling else span
		var d := fposmod(t * sp + q1 * span, room2)
		var px := (upwind + d) if dir > 0.0 else (upwind - d)
		var py := top + band * q1 + sin(t * 3.1 + j) * 8.0
		if px < v.position.x - 10.0 or px > v.end.x + 10.0:
			continue
		var r := 1.6 + 1.4 * q2
		var spin := t * (4.0 + 3.0 * q1) + j
		var e1 := Vector2(cos(spin), sin(spin)) * r
		var e2 := Vector2(-sin(spin), cos(spin)) * r * 0.5
		tb.convex(PackedVector2Array([Vector2(px, py) + e1, Vector2(px, py) + e2, Vector2(px, py) - e1, Vector2(px, py) - e2]),
				Color(1.0, 0.98, 0.92, minf(a * 1.8, 0.95)))


func _draw_shatter(tb: RefCounted) -> void:
	## The platform under him glows along its cracks, brighter to the break.
	if _shatter.is_empty():
		return
	var i := int(_shatter["i"])
	if i < 0 or i >= platforms.size():
		return
	var p: Dictionary = platforms[i]
	var k := 1.0 - clampf(timer / maxf(float(_shatter["len"]), 0.01), 0.0, 1.0)
	var y := float(p["y"])
	var x0 := float(p["x0"])
	var x1 := float(p["x1"])
	var col := Color(1.0, 0.95, 0.85, 0.35 + 0.6 * k)
	tb.rect(Rect2(x0, y - 2.0, x1 - x0, 3.0), col)
	var x := x0 + 10.0
	var j := 0
	while x < x1 - 6.0:
		var dy := 8.0 + 12.0 * k
		tb.line(Vector2(x, y), Vector2(x + 7.0, y + dy), 1.4 + k, col)
		tb.line(Vector2(x + 7.0, y + dy), Vector2(x + (3.0 if j % 2 == 0 else 12.0), y + dy + 8.0), 1.2, col)
		x += 22.0
		j += 1


func _draw_cracks(tb: RefCounted) -> void:
	## Refracted: bright cracks across her glass, and the window's time as a
	## thin ring shrinking round her heart.
	var hc := heart()
	var a := 0.6 + 0.4 * clampf(_crack * 2.0, 0.0, 1.0)
	var pts := [Vector2(-18, -30), Vector2(-4, -6), Vector2(10, -24), Vector2(2, 8), Vector2(16, 20), Vector2(-10, 26)]
	for i in pts.size() - 1:
		tb.line(hc + pts[i] * DRAW_SCALE, hc + pts[i + 1] * DRAW_SCALE, 1.8, Color(1, 1, 1, a))
	if state == "refracted" and _window_t > 0.0:
		var f := clampf(timer / _window_t, 0.0, 1.0)
		tb.ring(hc, 30.0, 2.0, Color(1.0, 0.92, 0.7, 0.75), 28, -PI * 0.5, -PI * 0.5 + TAU * f)


func _draw() -> void:
	## Under the dark (lit by her halo's light): the mirrors on their tracks,
	## the halo behind her, and in P3 the three shards. Her body is the
	## sprite; with no frames, a stand-in in glass.
	var tb := btb()
	for m in mirrors:
		if m["broken"]:
			continue
		var r := pane_rect(m)
		var tex: Texture2D = _parts.get("mirror_shard_dim" if float(m["dim"]) > 0.0 else "mirror_shard")
		if tex != null:
			draw_texture_rect(tex, Rect2(r.position - Vector2(8, 4) - position, Vector2(32, 64)), false)
		else:
			tb.rect(Rect2(r.position - position, r.size), Color(0.75, 0.85, 0.95, 0.7))
			tb.rect(Rect2(r.position - position + Vector2(2, 2), r.size - Vector2(4, 4)), Color(0.9, 0.95, 1.0, 0.5))
	if alive and not (state in ["split", "scatter"]) and fade > 0.01:
		var hc := halo_center() - position
		if _halo_tex != null:
			var sz := Vector2(128, 128) * DRAW_SCALE
			draw_set_transform(hc, _spin, Vector2.ONE)
			draw_texture_rect(_halo_tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, fade))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			tb.ring(hc, 52.0, 6.0, Color(0.85, 0.8, 1.0, 0.6 * fade), 28)
			for i in 12:
				var a := _spin + TAU * i / 12.0
				tb.line(hc + Vector2(cos(a), sin(a)) * 30.0, hc + Vector2(cos(a), sin(a)) * 66.0, 2.0, Color(0.9, 0.85, 1.0, 0.4 * fade))
	for i in shards.size():
		var s: Dictionary = shards[i]
		var names := ["saint_shard_red", "saint_shard_gold", "saint_shard_blue"]
		var tex: Texture2D = _parts.get(names[i])
		var p: Vector2 = (s["p"] as Vector2) - position
		if tex != null:
			var sz := Vector2(64, 64) * DRAW_SCALE
			draw_texture_rect(tex, Rect2(p - sz * 0.5, sz), false, Color(1, 1, 1, 0.55) if s["cracked"] else Color(1, 1, 1))
		else:
			var col: Color = s["col"]
			tb.convex(PackedVector2Array([p + Vector2(0, -26), p + Vector2(12, 0), p + Vector2(0, 26), p + Vector2(-12, 0)]), Color(col, 0.8))
	if not _dawn.is_empty():
		_draw_dawn(tb)
	if frames.is_empty() and alive and not (state in ["split", "scatter"]):
		# A stand-in: a tall glass gown, a pale mask, the prism in her hands.
		var f := fade
		var h := 132.0
		tb.convex(PackedVector2Array([Vector2(0, -h), Vector2(20, -h + 30), Vector2(28, -20), Vector2(0, 0), Vector2(-28, -20), Vector2(-20, -h + 30)]),
				pc(Color(0.72, 0.7, 0.9, 0.9 * f)))
		tb.ellipse(Vector2(0, -h + 20), 10.0, 13.0, pc(Color(0.95, 0.93, 1.0, f)), 14)
		tb.convex(PackedVector2Array([Vector2(0, -58), Vector2(8, -48), Vector2(0, -38), Vector2(-8, -48)]), pc(Color(1, 1, 1, f)))
	tb.flush(self)
