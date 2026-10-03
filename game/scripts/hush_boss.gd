extends "res://scripts/elites.gd"
## The Hush, the Hungry Quiet (World 6, the last boss, `boss: hush`; spec
## §5.5, decisions "The Hush" and "The ending"). The quiet at the bottom of
## the world, which never had a light or a sound of its own: the fight shows
## it becoming real as Waxby makes it heard, then seen, then faced. One long
## bar in three segments ("THE HUSH"). The arena is the Still Water (spec
## §3.7.4): five stone islets over deep black water, perches and two tall
## stones, and four sunken bells (the anchors).
##
## The sunken bells: any hit on one (a swing, a shot, a wave, a Peal) rings
## it: a pale gold peal ring runs out at 420 px/s to r 300 and the bell
## lights (r 120, 3 s). Whatever of the Hush the ring passes is Heard for
## 3 s (gold-rimmed, solid). A rung bell is smothered for 8 s.
##
## P1 "The Quiet" (100-65%): two Hands and a lidded Eye under the lake.
##   Grasp        0.65 s (0.45; 0.55 while the Eye is up): the water beside
##                him goes still, pale fingertips ring the surface, a cold
##                glint; a hand closes upward in a 40 x 64 column at the islet
##                edge nearest him and stays 0.8 s (Heard: hit it, 50%): 23
##                and hushed (unblockable: from below). P1: stood still 2 s
##                out of every edge's reach, it comes up through the stone at
##                his feet instead (the same tell; a ruling asked): P1 isn't a
##                safe loop beside a bell
##   Swallow the Light  1.0 s of black gathering at the far end, then a wall
##                rolling across at 160 px/s: where it passes him his light is
##                forced to 56 px for 4 s (scripted) and rung bells go dark;
##                a peal that reaches it breaks it and brings the Eye up there
##   The window: after any peal the Eye swims (260 px/s) to the rung bell
##                and surfaces beside it, on the islet at his height, Heard,
##                for 2.6 s (full damage, a stomp 3x); then it smothers it
## P2 "The Mouth" (65-30%): the roar raises the shadow Waxby at the back:
##   his own rig at 3x in black with a silver rim (drawn the Unwick's way:
##   the black body behind the tiles and him, hiding the nave behind it; the
##   rim alone over the dark), standing in the lake behind the middle islet,
##   its dark flame the Maw, six stolen flames round its helm; the Inhale
##   and the choke bow it low over that islet.
## Drawing: the black parts (Hands, Eyes, palm, core) are drawn in the World
##   under the dark and under him, so none of it ever hides him; over the
##   dark go their fingertips, glints, rims and every tell.
##   Snuff        1.2 s (0.8): all sound cuts 0.3 s before it lands; a pale
##                palm outline grows over his islet; the hand slams its top
##                (6 tiles x 3 rows) and stays 1.0 s (Heard if a bell rang in
##                the last 3 s: 50%): 28 and hushed
##   Inhale       0.8 s, then 2.5 s of pull toward the Maw at 110 px/s (a
##                push; it waits while he's airborne over the lake), his light
##                x0.6 meanwhile; the shadow bows its Maw to his head over the
##                middle islet (maw_over, whatever rig it wears), and touching
##                it: 31 and knocked out
##   Silence Bolts  0.6 s (the crown's flames darken, its rim flashes and the
##                three orbs gather where they'll fly from): 3 dark orbs at 200 px/s,
##                homing 1.0 rad/s, 2.5 s (kind "silence": a Perfect Guard
##                throws one back); a peal dispels those inside it: 18, hushed
##   Drowned Choir  at 55% and 40%: 3 Hushlings rise onto the islets
##   Grasp        as P1, 0.55 s
##   The window: ring a bell during an Inhale and the Maw chokes on the
##                sound, sticking open low over the middle islet with its
##                crown dipped: 2.4 s; strike its core. Each stolen flame may
##                be struck free once: it flies to him, heals 6%, +20% light
##                for 6 s (latch_light(): the dispatcher's light_mult)
## P3 "The Eye" (30-0%): the shape collapses, every bell sinks, the great
##   Eye opens. It is solid only where its hurt rect meets a circle of radius
##   max(his light, 96 px) round him (or a Beacon's light); it hovers at the
##   edge of a healthy light.
##   Gaze         a pale cone narrows onto him 1.2 s (0.8), locks 0.50 s
##                (0.40), a 12 px beam of silence for 0.4 s: 24 and hushed;
##                a Candleknight's Perfect Guard sends it back (150% basic and
##                an instant Blink)
##   Blink        after every Gaze (the window): it closes and drifts to his
##                height, its near edge within 40 px, and holds there (a still
##                target: struck, or stomped from a jump), for 1.4 s
##   The Deep Quiet  1.6 s (1.2): the lake stills, sound stops, a pale line
##                shows the new water level; the black water stands a row over
##                the islet tops for 2.0 s: on a perch or a tall stone (one
##                within 5 tiles of every islet), else drowned (the pit rule)
##                and back on the nearest perch
##   Grasp        0.50 s (0.45), from the lake's edges
##   Echoes of Light  at 20%: 2 Unwicks. "hush_last" at 15%. Mercy: a stub.
## Windows never scale with difficulty; outside them it takes nothing (only
## a Heard hand, 50%); inside, a stomp onto the struck part lands 3x (its
## hurt_rect is that part). HEARD!: 30% inside one window, once a phase of
## each try (+10%).
## Checkpoints (checkpoint() / reset_fight(keep_phase)): Dusk keeps P2 and
## P3, Nightfall P3 (Combat.checkpoint_allowed; never in a mode); the freed
## flames stay freed; what lies below the kept life comes again (the Choirs,
## the choir stem's fade, the Echoes, hush_last); "hush_remembers" on the
## way back in.
## bot_pad(player): a pad that plays the fight (the --autoplay bot's, W0
## asked; the tests' real-pad runs).
## Music: the hush_final stems (A6): the drums go at 65%, the choir at 47%,
## the bells at 30%; P3's wick stem follows his flame; stem_levels() for a
## checkpoint's return.
## At 0 HP: the finale (hush_finale.gd), in the level; a mode's Hush (the
## Waxworks, the Descent) closes its eye instead ("it sleeps").

signal woke

const BossMods := preload("res://scripts/boss_mods.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const HK := preload("res://scripts/hush_kind.gd")
const UW := preload("res://scripts/unwick.gd")
const RigScript := preload("res://scripts/wick_rig.gd")
const FINALE := "res://scripts/hush_finale.gd"
const POINTS := "res://art/enemies/points_hush.json"
const PHASES := [0.65, 0.30]
# The windows test sets it (test_bosses4: the reference knight needs 8 (9)
# windows and at least 3 / 3 / 2 a phase).
const BASE_HP := 800.0
const TOUCH := 21.0
# Its blows at area 1, Dusk (spec §5.5 after the x0.6 scale): the share-cap scan.
const MOVES := {"grasp": 23.0, "snuff": 28.0, "inhale": 31.0, "bolt": 18.0, "gaze": 24.0}
const WINDOW := [2.6, 2.4, 1.4]
const HEARD_SHARE := 0.5
const STAGGER := 0.30
const STAGGER_BONUS := 0.10
const STAGGER_ROOM := 0.05      # the stagger's bonus stops this far above the phase's line (boss_rig's rule)
const STOMP_MULT := 3.0
const STOMPS_FULL := 1          # stomps a window pays STOMP_MULT for (the bounces after it take nothing)
const CHOIRS := [0.55, 0.40]
const ECHOES_AT := 0.20
const LAST_AT := 0.15
const CHOIR_STEM_AT := 0.47
const LIGHT_MIN := 56.0
const TUNE := {
	"peal_speed": 420.0, "peal_r": 300.0, "bell_light": 120.0, "bell_lit": 3.0, "smother": 8.0, "heard": 3.0,
	"grasp_tell": 0.65, "grasp_tell_up": 0.55, "grasp_tell_p3": 0.50, "grasp_floor": 0.45, "grasp_up": 0.8,
	"grasp_w": 40.0, "grasp_h": 64.0,
	# P1: he's stood this long (s) out of every edge's reach: the Grasp rises
	# through the stone at his feet instead (0 turns it off; a ruling asked).
	"grasp_still": 2.0, "still_r": 36.0,
	"grasp_every": [2.4, 3.4, 3.0],
	"swallow_tell": 1.0, "swallow_floor": 0.6, "swallow_speed": 160.0, "swallow_dark": 4.0, "swallow_every": 14.0,
	"eye_swim": 260.0,
	"snuff_tell": 1.2, "snuff_floor": 0.8, "snuff_up": 1.0, "snuff_w": 6, "snuff_h": 3,
	"inhale_tell": 0.8, "inhale_floor": 0.5, "inhale_pull": 2.5, "inhale_speed": 110.0, "inhale_dim": 0.6,
	"maw_over": 48.0,        # px the bowed Maw hangs over the islet top (its core 8 px lower: his swing's height)
	"bolt_tell": 0.6, "bolt_floor": 0.45, "bolt_speed": 200.0, "bolt_turn": 1.0, "bolt_life": 2.5,
	"flame_heal": 0.06, "flame_light": 1.2, "flame_light_t": 6.0,
	"gaze_tell": 1.2, "gaze_floor": 0.8, "gaze_lock": 0.50, "gaze_lock_floor": 0.40, "gaze_fire": 0.4, "gaze_w": 12.0,
	"blink_edge": 30.0, "hover_edge": 170.0, "gaze_edge": 120.0,
	"quiet_tell": 1.6, "quiet_floor": 1.2, "quiet_up": 2.0,
	"eye_r": 96.0,
	"gap": [1.0, 1.2, 1.0],
	# P2's moves in turn: every Inhale is a window's chance (a bell rung in it
	# chokes the Maw), so their share sets P2's pace (provisional, W5-W6).
	"p2_loop": ["inhale", "snuff", "inhale", "bolts", "inhale", "snuff"],
	"roar": 2.0,
	# A checkpoint's return (spec §5.1: fighting resumes within 5 s of a
	# snuff): the phase's roar is short, the shadow risen (or sunk) in it.
	"roar_resumed": 0.6,
}
const RIM := Color("c8c8f0")
const PALE := Color("d8d4f0")
const GOLD := Color("f2d27a")
const VIOLET := Color("b49cff")
const INK := Color(0.05, 0.04, 0.09)
const FLAME_PAL := {"out": Color(0.62, 0.58, 0.95, 0.9), "mid": Color(0.82, 0.8, 1.0), "core": Color(1, 1, 1), "halo": Color(0.6, 0.55, 1.0)}
const ART := ["hush_eye_small", "hush_eye_open", "hush_eye_half", "hush_eye_shut", "hush_eye_wince", "hush_pupil",
		"hush_hand_rise", "hush_hand_grasp", "hush_hand_splay", "hush_hand_sink", "hush_core", "stolen_flame",
		"sunken_bell", "sunken_bell_smothered", "ring_ledge"]
# The shadow Waxby: his rig at 3x, drawn alone on a small SubViewport (the
# Unwick's way), rimmed by its shader on the glow layer.
const SHADOW_SCALE := 3.0
const SHADOW_VIEW := Vector2(112, 128)
const SHADOW_FOOT := 20.0
static var _points := {}

var boss_id := "hush"
var boss_name := "The Hush"
var boss_title := "The Hungry Quiet"
var state := "sleep"            # sleep, wake, roar, fight, finale, closing, dead
var timer := 0.0
var phase := 1
var act := ""                   # the move playing: grasp swallow inhale snuff bolts choir gaze deep_quiet echoes
var act_t := 0.0
var act_len := 0.0
var move_id := ""
var arena_left := 0.0
var arena_right := 0.0
var arena_top := 64.0
var block_x0 := 0               # the arena block's first column (the spec's column 0)
var door: Array[Vector2i] = []
var home := Vector2.ZERO
var islets: Array = []          # [{x0, x1, top}]
var gaps: Array = []            # [{x0, x1}]
var perches: Array = []         # [{x0, x1, top}] (ledges and tall stones: the Deep Quiet's high ground)
var islet_top := 352.0
var water_y := 384.0
var mid_x := 0.0                # the middle islet's middle
var bells: Array = []           # [{p, rect, light, lit, smother, sunk, sink, last_swing}]
var peals: Array = []           # [{p, r, prev}]
var hands: Array = []           # [{state, t, len, x, heard, hit, rest_x}]
var eye := {}                   # P1: {p, state: lurk|swim|rise|surface|dive, t, bell, side}
var swallow := {}               # P1: {state: gather|roll, x, dir, t, len}
var flames: Array = []          # the six stolen flames: [{freed, a}]
var snuff := {}                 # P2: {state: tell|slam, t, len, rect, islet, heard}
var bolts: Array = []           # P2: [{p, v, life}]
var maw := {"state": "idle", "t": 0.0}   # P2: idle, inhale_tell, inhale, choked, rise
var eye3 := {}                  # P3: {p, state: hover|gaze_tell|gaze_lock|gaze_fire|blink|open, t, len, a, b, side}
var flood := {}                 # P3: {state: tell|up|down, t, len, y}
var heard_t := 0.0              # a bell rang in the last 3 s
var shadow_k := 0.0             # the shadow's rise (0 under the lake, 1 risen)
var shadow_dip := 0.0           # px its head comes down (the Inhale, the choke)
var used := {}                  # move -> times (tests)
var windows_opened := 0
var rings_rung := 0
var defeated := false           # world.boss_defeated was called (the finale's end)
var finale: RefCounted = null   # hush_finale.gd once at 0 HP
var _dark_t := 0.0              # Swallow the Light: s his light stays forced to 56 px
var _bright_t := 0.0            # a freed flame's +20% light
var _grasp_t := 1.2
var _still_x := 0.0             # P1: where he's been standing...
var _still_t := 0.0             # ...and for how long (the Grasp's reach)
var _swallow_t := 6.0
var _move_n := -1
var _act_timer := 1.5
var _part := ""                 # what of it a blow can meet this tick
var _part_rect := NOWHERE
var _force_eye := false         # a reflected Gaze: the Eye is there to meet it
var _window_dmg := 0.0
var window_stomps := 0          # stomps on the window's target since it opened
var _stagger_phase := 0
var _choirs_done: Array = []
var _echoes := false
var _last_said := false
var _mercy := false
var _stem_frac := 1.0
var _stem_t := 0.0
var _choir_stem := false
var _adds: Array = []
var _inhale_hit := false
var _gaze_hit := false
var _gaze_hz := {}
var _resumed := false           # this wake is a checkpoint's return
var _roar_len := 2.0            # the roar playing (TUNE roar, or roar_resumed on a checkpoint's return)
var _opts := {}
var rush := false               # a mode's rush boss (BossMods.configure sets it)
var no_back := true             # Combat.is_back_hit: an Eye, a Maw's core: nothing of it has a back
var _art := {}
var _tb := TriBatch.new()
var _shadow_spr: Sprite2D = null     # the shadow's black body, behind the tiles and him (under the dark)
var _shadow_rim: Sprite2D = null     # its silver rim alone, on the glow layer (over the dark, cut at the lake)
var _shadow_vp: SubViewport = null
var _shadow_rig: Node2D = null
var _puppet: Node2D = null
var _sh_k := 1.5
var _close_t := 0.0
var _base := Vector2.ZERO        # the _draw transform's offset (world space in the boss's canvas)


func _init() -> void:
	kind = "boss"
	xp_kind = "hush"
	size = Vector2(40, 40)
	base_hp = BASE_HP
	base_dmg = TOUCH
	embers = 120
	item_chance = 0.0
	relic_chance = 0.0
	stompable = true
	ordinary = false
	flier = true
	belt_carry = false
	set("echo_by_body", false)
	set("lit_alpha_own", true)


func _ready() -> void:
	super()
	for n in ART:
		var p := "res://art/enemies/%s.svg" % n
		if ResourceLoader.exists(p):
			_art[n] = load(p)
	home = position
	_scan_arena()
	flames.clear()
	for i in 6:
		flames.append({"freed": false, "a": TAU * i / 6.0, "p": Vector2.ZERO})
	hands = [_new_hand(0), _new_hand(1)]
	_reset_eye()


func configure(opts: Dictionary) -> void:
	## A mode's boss ({rush, mods, hp_mult, area}): before _ready. BR's
	## boss_mods.gd (wired at the track B merge): rush set, the life x its rush
	## normalisation (BossMods.RUSH_HP, with rush) x the mode's hp_mult, and
	## Warded / Echoing Wax as a runtime (BossMods.of) this script steps.
	_opts = opts.duplicate()
	BossMods.configure(self, opts)


func _exit_tree() -> void:
	if _shadow_spr != null and is_instance_valid(_shadow_spr):
		_shadow_spr.queue_free()
	if _shadow_rim != null and is_instance_valid(_shadow_rim):
		_shadow_rim.queue_free()
	if _shadow_vp != null and is_instance_valid(_shadow_vp):
		_shadow_vp.queue_free()
	if world != null and state == "fight" and _dark_t > 0.0 and world.has_method("light_override"):
		world.light_override(-1.0)


static func points() -> Dictionary:
	if _points.is_empty():
		var text := FileAccess.get_file_as_string(POINTS) if FileAccess.file_exists(POINTS) else ""
		var d = JSON.parse_string(text) if text != "" else null
		_points = d if d is Dictionary else {"_missing": true}
	return _points


func in_mode() -> bool:
	## A mode's Hush (the Waxworks, a Descent depth): no stair, no hold, and
	## never a checkpoint.
	return bool(_opts.get("rush", false)) or (world != null and world.get("mode") != null)


# ---------------------------------------------------------------- the arena

func _scan_arena() -> void:
	## The islets (the floor at its own feet's row, split by the water), the
	## gaps, the high ground (ledges and stone tops over the islets: the Deep
	## Quiet's), the four sunken bells (the anchors), the door.
	var a := Arena.find(level, position)
	arena_left = a["left"]
	arena_right = a["right"]
	door.assign(_find_door(a["door"]))
	block_x0 = floori(arena_left / TILE) - 2
	var c0 := floori(arena_left / TILE)
	var c1 := floori(arena_right / TILE) - 1
	var mid_c := (c0 + c1) / 2
	for y in range(0, level.height):
		if not LevelData.is_solid(level.tile(mid_c, y)):
			arena_top = y * TILE
			break
	var fy := floori((position.y + 1.0) / TILE)
	islet_top = fy * TILE
	islets.clear()
	gaps.clear()
	var x := c0 - 2
	while x <= c1 + 1:
		if LevelData.is_solid(level.tile(x, fy)) and not LevelData.is_solid(level.tile(x, fy - 1)) or \
				(LevelData.is_solid(level.tile(x, fy)) and x < c0):
			var x1 := x
			while x1 + 1 <= c1 + 1 and LevelData.is_solid(level.tile(x1 + 1, fy)):
				x1 += 1
			islets.append({"x0": maxf(x * TILE, arena_left - 2.0 * TILE), "x1": (x1 + 1) * TILE, "top": islet_top})
			x = x1 + 1
		else:
			x += 1
	for i in range(islets.size() - 1):
		gaps.append({"x0": islets[i]["x1"], "x1": islets[i + 1]["x0"]})
	water_y = islet_top + TILE
	for g in gaps:
		var gx := floori((float(g["x0"]) + 2.0) / TILE)
		for yy in range(fy, level.height):
			if level.tile(gx, yy) == LevelData.WATER:
				water_y = yy * TILE
				break
		break
	# The middle islet: the one under its feet.
	mid_x = position.x
	for il in islets:
		if position.x >= float(il["x0"]) and position.x <= float(il["x1"]):
			mid_x = (float(il["x0"]) + float(il["x1"])) * 0.5
	perches.clear()
	for yy in range(floori(arena_top / TILE) + 1, fy):
		var xx := c0
		while xx <= c1:
			var t: int = level.tile(xx, yy)
			var up: int = level.tile(xx, yy - 1)
			var standable := (LevelData.is_solid(t) or LevelData.is_ledge(t)) and not LevelData.is_solid(up) and not LevelData.is_ledge(up)
			if not standable:
				xx += 1
				continue
			var x1 := xx
			while x1 + 1 <= c1 and (LevelData.is_solid(level.tile(x1 + 1, yy)) or LevelData.is_ledge(level.tile(x1 + 1, yy))) \
					and not LevelData.is_solid(level.tile(x1 + 1, yy - 1)):
				x1 += 1
			perches.append({"x0": xx * TILE, "x1": (x1 + 1) * TILE, "top": yy * TILE})
			xx = x1 + 1
	var anchors: Array = []
	for e in level.entities:
		if str(e["kind"]) == "anchor":
			var cell: Vector2i = e["cell"]
			if cell.x >= c0 - 1 and cell.x <= c1 + 1:
				anchors.append(cell)
	anchors.sort_custom(func(p, q): return p.x < q.x or (p.x == q.x and p.y < q.y))
	bells.clear()
	for cell in anchors.slice(0, 4):
		var fp := LevelData.cell_floor(cell)
		bells.append({"p": fp, "rect": Rect2(fp.x - 13.0, fp.y - 44.0, 26.0, 44.0), "light": -1, "lit": 0.0, "smother": 0.0,
				"sunk": false, "sink": 0.0, "last_swing": -1, "flash": 0.0})


func _find_door(fallback: Array) -> Array:
	var c := floori(arena_left / TILE) - 1
	var y: int = level.height - 1
	while y >= 1:
		if level.tile(c, y) == LevelData.AIR and LevelData.is_solid(level.tile(c, y + 1)):
			var run: Array = []
			var yy := y
			while yy >= 1 and level.tile(c, yy) == LevelData.AIR:
				run.append(yy)
				yy -= 1
			if run.size() >= 2 and run.size() <= 5:
				var out: Array = []
				for x in [c, c - 1]:
					for ry in run:
						if level.tile(x, ry) == LevelData.AIR:
							out.append(Vector2i(x, ry))
				return out
			y = yy
		y -= 1
	return fallback


func islet_at(x: float) -> int:
	for i in islets.size():
		if x >= float(islets[i]["x0"]) and x <= float(islets[i]["x1"]):
			return i
	return -1


func nearest_islet(x: float) -> int:
	var best := 0
	var bd := INF
	for i in islets.size():
		var il: Dictionary = islets[i]
		var d := 0.0 if x >= float(il["x0"]) and x <= float(il["x1"]) else minf(absf(x - float(il["x0"])), absf(x - float(il["x1"])))
		if d < bd:
			bd = d
			best = i
	return best


func nearest_edge(x: float) -> float:
	## The islet edge nearest x (a Grasp's column goes there).
	var best := x
	var bd := INF
	for il in islets:
		for ex in [float(il["x0"]), float(il["x1"])]:
			if ex <= arena_left + 4.0 or ex >= arena_right - 4.0:
				continue   # (the walls' ends are no edge)
			var d := absf(x - ex)
			if d < bd:
				bd = d
				best = ex
	return best


func perch_near(x: float) -> Dictionary:
	## The high ground nearest x (where the Deep Quiet leaves him).
	var best := {}
	var bd := INF
	for p in perches:
		var cx := clampf(x, float(p["x0"]) + 10.0, float(p["x1"]) - 10.0)
		var d := absf(cx - x)
		if d < bd:
			bd = d
			best = p
	return best


# ---------------------------------------------------------------- the boss interface

func boss_info() -> Dictionary:
	return {"id": boss_id, "name": boss_name, "title": boss_title, "frac": hp / maxf(max_hp, 1.0),
			"phases": PHASES, "segments": PHASES, "awake": state in ["wake", "roar", "fight"] and alive}


func is_open() -> bool:
	## Only inside a window: the Eye surfaced (P1), the Maw choked (P2), the
	## Blink (P3).
	if not alive or state != "fight":
		return false
	match phase:
		1:
			return str(eye.get("state", "")) == "surface"
		2:
			return str(maw.get("state", "")) == "choked"
	return str(eye3.get("state", "")) == "blink"


func window_bonus() -> float:
	if world == null or world.get("player") == null or not (world.player.stats is Dictionary):
		return 0.0
	var flags = world.player.stats.get("flags", {})
	return float(flags.get("tollbreaker_window", 0.0)) if flags is Dictionary else 0.0


func window_len(p := -1) -> float:
	return float(WINDOW[clampi((phase if p < 0 else p) - 1, 0, 2)]) + window_bonus()


func checkpoint() -> Dictionary:
	## Where it was hurt: its phase, its life, the flames he freed.
	var freed := []
	for f in flames:
		freed.append(bool(f["freed"]))
	return {"phase": phase, "hp_frac": hp / maxf(max_hp, 1.0), "state": {"freed": freed}}


func stem_levels() -> Dictionary:
	## The hush_final stems for the phase it wakes in (world.gd passes them to
	## Sfx.play_stems): the drums gone from 65%, the choir from 47%, the bells
	## from 30%; P3's wick at his flame.
	var out := {}
	var f := hp / maxf(max_hp, 1.0)
	if phase >= 2:
		out["hush_final_drums"] = -80.0
	if phase >= 3 or f <= CHOIR_STEM_AT:
		out["hush_final_choir"] = -80.0
	if phase >= 3:
		out["hush_final_bells"] = -80.0
		out["hush_final_wick"] = _wick_db()
	return out


func _wick_db() -> float:
	var lf := 1.0
	if world != null and world.get("player") != null:
		lf = float(world.player.life_frac())
	return -18.0 + 18.0 * lf


func reset_fight(keep_phase := false) -> void:
	## Wick was snuffed. keep_phase (Dusk P2-P3, Nightfall P3; the World asks
	## Combat): it goes back to the start of its phase (65% or 30%) and the
	## flames he freed stay freed; else the whole fight from the start. The
	## arena resets either way and the door opens.
	if not alive or state in ["finale", "closing"]:
		return
	Arena.unseal(world, level, door)
	if keep_phase and phase >= 2:
		hp = max_hp * float(PHASES[phase - 2])
		_resumed = true
		# What happens below that life happens again (spec §5.5.5: "from
		# the start of that phase"): the Choirs, the choir stem's fade, the
		# Echoes, "hush_last".
		var f := float(PHASES[phase - 2])
		_choirs_done = _choirs_done.filter(func(c): return float(c) > f + 0.001)
		if CHOIR_STEM_AT < f - 0.001:
			_choir_stem = false
		if ECHOES_AT < f - 0.001:
			_echoes = false
		if LAST_AT < f - 0.001:
			_last_said = false
	else:
		hp = max_hp
		phase = 1
		_resumed = false
		for f in flames:
			f["freed"] = false
		_choirs_done.clear()
		_echoes = false
		_last_said = false
		_choir_stem = false
	state = "sleep"
	timer = 0.0
	act = ""
	move_id = ""
	position = home
	_move_n = -1
	_act_timer = 1.5
	_grasp_t = 1.2
	_still_t = 0.0
	_swallow_t = 6.0
	_window_dmg = 0.0
	_stagger_phase = 0   # (HEARD! is once a phase, a phase of each try)
	_mercy = false
	heard_t = 0.0
	peals.clear()
	bolts.clear()
	snuff = {}
	swallow = {}
	flood = {}
	maw = {"state": "idle", "t": 0.0}
	eye3 = {}
	_gaze_hz = {}
	shadow_k = 0.0
	shadow_dip = 0.0
	if _dark_t > 0.0 and world != null:
		world.light_override(-1.0)
	_dark_t = 0.0
	for b in bells:
		if int(b["light"]) >= 0 and world != null:
			world.remove_light(int(b["light"]))
		b["light"] = -1
		b["lit"] = 0.0
		b["smother"] = 0.0
		b["sunk"] = false
		b["sink"] = 0.0
	hands = [_new_hand(0), _new_hand(1)]
	_reset_eye()
	_clear_adds()


func touch_damage() -> bool:
	## Only the great Eye itself, hovering (a Blink is the window: strike,
	## don't flinch); every other harm is a move of its own.
	return alive and state == "fight" and phase >= 3 and str(eye3.get("state", "")) in ["hover", "open"]


func hurt_rect() -> Rect2:
	## The great Eye's touch; in a window (no touch then) the struck part
	## itself, so a stomp onto the Eye, the core or the Blink lands (the
	## World's stomp asks hurt_rect first).
	if touch_damage():
		return eye3_rect().grow(-18.0)
	if is_open() and _part in ["eye", "core", "eye3"]:
		return _part_rect
	return NOWHERE


func dmg(what := "touch") -> float:
	if MOVES.has(what):
		return float(MOVES[what]) * dmg_mult
	return TOUCH * dmg_mult


func moves() -> Dictionary:
	var out := MOVES.duplicate()
	out["touch"] = TOUCH
	return out


func latch_light() -> float:
	## (level_features.light_mult asks every monster) a freed stolen flame:
	## +20% light for 6 s.
	return float(TUNE["flame_light"]) if _bright_t > 0.0 else 1.0


func _stunned(_dt: float) -> void:
	pass   # a stun holds nothing of the Hush


func _new_hand(i: int) -> Dictionary:
	return {"i": i, "state": "rest", "t": 0.0, "len": 0.0, "x": position.x + (i * 2 - 1) * 90.0, "heard": 0.0, "hit": false}


func _reset_eye() -> void:
	eye = {"p": Vector2(position.x, water_y + 12.0), "state": "lurk", "t": 0.0, "bell": -1, "side": 1, "heard": 0.0}


# ---------------------------------------------------------------- what can be struck

func eye1_rect() -> Rect2:
	var p: Vector2 = eye["p"]
	return Rect2(p.x - 22.0, p.y - 13.0, 44.0, 26.0)


func eye3_rect() -> Rect2:
	## P3's Eye: its white almond (224 x 79 px at 1:1).
	var p: Vector2 = eye3.get("p", position)
	return Rect2(p.x - 112.0, p.y - 40.0, 224.0, 79.0)


func pupil() -> Vector2:
	## Its pupil, turned toward him (within the travel).
	var p: Vector2 = eye3.get("p", position)
	if world == null or world.get("player") == null:
		return p
	var d: Vector2 = (world.player.center() as Vector2) - p
	return p + d.limit_length(18.0) * Vector2(1.0, 0.6)


func hand_rect(h: Dictionary) -> Rect2:
	## The 40 x 64 column a hand closes in, rising from its base: the lake's
	## line, or (the stood-still Grasp) the stone he stands on.
	var w := float(TUNE["grasp_w"])
	var ht := float(TUNE["grasp_h"])
	var rise := 1.0
	match str(h["state"]):
		"tell", "rest":
			rise = 0.0
		"sink":
			rise = clampf(float(h["t"]) / 0.3, 0.0, 1.0)
	var by := float(h.get("base", water_y))
	return Rect2(float(h["x"]) - w * 0.5, by - ht * rise, w, ht * rise)


func floor_under(player: Node2D) -> float:
	## The top he stands on (or is over): the nearest perch under his feet,
	## else his islet's; -1 over the open water.
	var feet: float = player.position.y
	var best := -1.0
	for p in perches:
		if player.position.x >= float(p["x0"]) and player.position.x <= float(p["x1"]) and float(p["top"]) >= feet - 8.0:
			if best < 0.0 or float(p["top"]) < best:
				best = float(p["top"])
	if best < 0.0 and islet_at(player.position.x) >= 0:
		best = islet_top
	return best


func maw_p() -> Vector2:
	## The shadow's dark flame: where its rig's flame is (the fallback: over
	## the middle islet).
	var foot := shadow_foot()
	if _shadow_rig != null and is_instance_valid(_shadow_rig) and _shadow_rig.is_inside_tree() and _shadow_rig.has_method("flame_point"):
		var fp: Vector2 = _shadow_rig.flame_point()
		return foot + (fp - _shadow_foot_tex()) / _sh_k + Vector2(0, -8.0)
	return foot + Vector2(0, -170.0)


func core_rect() -> Rect2:
	var c := maw_p() + Vector2(0, 8.0)
	return Rect2(c.x - 20.0, c.y - 20.0, 40.0, 40.0)


func maw_rect() -> Rect2:
	var c := maw_p()
	return Rect2(c.x - 28.0, c.y - 30.0, 56.0, 50.0)


func shadow_foot() -> Vector2:
	## Its feet in the lake behind the middle islet (it stands up out of it,
	## the whole of it over the islets; the Inhale and the choke bow it low).
	return Vector2(mid_x, islet_top + 16.0 + shadow_dip + (1.0 - shadow_k) * 300.0)


func crown() -> Vector2:
	return maw_p() + Vector2(0, 50.0)


func flame_p(i: int) -> Vector2:
	## Where each stolen flame is: round the shadow's helm (P2), round the Eye
	## (P3), or back at home in the lake.
	var f: Dictionary = flames[i]
	var a := float(f["a"])
	if phase >= 3 and not eye3.is_empty():
		return (eye3["p"] as Vector2) + Vector2(cos(a) * 150.0, sin(a) * 62.0)
	var c := crown()
	return c + Vector2(cos(a) * 64.0, sin(a) * 16.0)


func flame_rect(i: int) -> Rect2:
	var p := flame_p(i)
	return Rect2(p.x - 10.0, p.y - 20.0, 20.0, 26.0)


func flames_strikable() -> bool:
	## During a P2 window (the crown dipped), and any time in P3.
	return state == "fight" and ((phase == 2 and str(maw.get("state", "")) == "choked") or phase >= 3)


func _update_part(player: Node2D) -> void:
	## What a blow can meet now: the one nearest his swing of the parts that
	## are there to be struck (a window's target, a Heard hand or palm).
	_part = ""
	_part_rect = NOWHERE
	if state != "fight" or player == null:
		return
	var cands: Array = []
	match phase:
		1:
			if str(eye["state"]) in ["surface", "rise"]:
				cands.append(["eye", eye1_rect()])
		2:
			if str(maw["state"]) == "choked":
				cands.append(["core", core_rect()])
			if not snuff.is_empty() and str(snuff["state"]) == "slam" and bool(snuff.get("heard", false)):
				cands.append(["snuff", snuff["rect"]])
		_:
			if not eye3.is_empty() and eye3_solid(player):
				cands.append(["eye3", eye3_rect()])
	for h in hands:
		if str(h["state"]) in ["up", "sink"] and float(h["heard"]) > 0.0:
			cands.append(["hand", hand_rect(h)])
	var at: Vector2 = player.center() + Vector2(player.facing * 22.0, 0.0)
	var bd := INF
	for c in cands:
		var r: Rect2 = c[1]
		var d := r.get_center().distance_to(at)
		if d < bd:
			bd = d
			_part = str(c[0])
			_part_rect = r


func eye3_solid(player: Node2D) -> bool:
	## P3: solid only where its hurt rect meets a circle of radius max(his
	## light, 96 px) round him, or a Beacon's light.
	if eye3.is_empty() or player == null or world == null:
		return false
	var r := eye3_rect()
	var rad := maxf(float(world.hero_light_radius()), float(TUNE["eye_r"]))
	if _circle_meets(player.center() + Vector2(0, -8), rad, r):
		return true
	for l in world.lights_tagged("beacon"):
		if _circle_meets(l["p"], float(l["r"]), r):
			return true
	return false


static func _circle_meets(c: Vector2, r: float, rect: Rect2) -> bool:
	var q := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return q.distance_to(c) <= r


func rect() -> Rect2:
	if _force_eye and not eye3.is_empty():
		return eye3_rect()
	return _part_rect


func center() -> Vector2:
	if _part_rect != NOWHERE:
		return _part_rect.get_center()
	match phase:
		1:
			return eye["p"]
		2:
			return maw_p()
	return eye3.get("p", position)


# ---------------------------------------------------------------- being hit

func hit(h: Dictionary) -> bool:
	if not alive or state != "fight":
		return false
	var how: String = str(h.get("how", "slash"))
	if how == "bump":
		return false
	var bm = BossMods.of(self)
	if bm != null and bm.blocks(h):
		return false   # a Warded Wax mote took it
	var part := "eye3" if _force_eye else _part
	var amount := float(h.get("amount", 0.0))
	var open := is_open()
	match part:
		"eye", "core", "eye3":
			if not open:
				return false   # (outside a window it takes nothing)
			# boss_rig's two rules (the int2 review's, for every v3 boss): only
			# the window's first stomp pays 3x (the World bounces Wick straight
			# back onto the target, so the bounces after it, and what a bounce
			# throws off, take nothing: the Hush has no chip), and until the
			# phase's stagger a window's blows stop at STAGGER of its life.
			if how == "stomp":
				window_stomps += 1
				if window_stomps > STOMPS_FULL:
					return false
				amount *= STOMP_MULT
			elif bool(h.get("stomp_born", false)) and window_stomps > STOMPS_FULL:
				return false
			if _stagger_phase < phase:
				amount = minf(amount, maxf(STAGGER * max_hp - _window_dmg, 0.0))
		"hand", "snuff":
			amount *= HEARD_SHARE
			h["chip"] = true
			open = false
		_:
			return false
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
		_window_dmg += amount
	sfx("hush_wince", "boss_hit")
	if world:
		world.shake = maxf(world.shake, 4.0)
	if hp <= 0.0:
		_zero()
		return true
	var frac := hp / maxf(max_hp, 1.0)
	_after_blow(frac)
	if clamped:
		phase += 1
		_enter_phase()
		return true
	if open and _stagger_phase < phase and _window_dmg >= STAGGER * max_hp - 0.5:
		_stagger_phase = phase
		# The bonus never takes it closer than STAGGER_ROOM to the phase's
		# line (a stagger left 1 HP over it, and the next blow ended the phase).
		var bonus := maxf(minf(STAGGER_BONUS * max_hp, hp - floor_hp - STAGGER_ROOM * max_hp), 0.0)
		hp -= bonus
		if world:
			world.banner("HEARD!")
			if bonus > 0.0:
				world.number(center() + Vector2(0, -40), bonus, "crit", get_instance_id())
		_end_window()
	return true


func _after_blow(frac: float) -> void:
	for c in CHOIRS:
		if phase == 2 and frac <= float(c) + 0.001 and not _choirs_done.has(c):
			_choirs_done.append(c)
			_choir(3, "hushling")
	if not _choir_stem and frac <= CHOIR_STEM_AT:
		_choir_stem = true
		_stem("choir", -80.0, 2.0)
	if phase >= 3 and not _echoes and frac <= ECHOES_AT:
		_echoes = true
		_choir(2, "unwick")
		_used("echoes")
	if phase >= 3 and not _last_said and frac <= LAST_AT:
		_last_said = true
		if world:
			world.bark("hush_last")


func on_reflected(beam: Dictionary) -> void:
	## A Perfect Guard sent the Gaze back: an instant Blink, and the Eye is
	## there for the reflect to meet (knight.gd deals it along the way back).
	if beam.get("source") != self or phase < 3 or eye3.is_empty():
		return
	_start_blink()
	_force_eye = true


func _end_window() -> void:
	_window_dmg = 0.0
	match phase:
		1:
			if str(eye["state"]) == "surface":
				eye["state"] = "dive"
				eye["t"] = 0.35
		2:
			if str(maw["state"]) == "choked":
				maw["state"] = "rise"
				maw["t"] = 1.0
		_:
			if str(eye3.get("state", "")) == "blink":
				eye3["state"] = "open"
				eye3["t"] = 0.5


func _zero() -> void:
	## 0 HP: the fight is over. In the level, the finale (it keeps its life at
	## 0 and stays "alive" so it's drawn and stepped until it ends it); a
	## mode's Hush closes its eye and sleeps.
	hp = 0.0
	_clear_adds()
	bolts.clear()
	peals.clear()
	snuff = {}
	flood = {}
	swallow = {}
	for h in hands:
		h["state"] = "rest"
	if world != null:
		world.hazards = world.hazards.filter(func(hz): return hz.get("owner", "enemy") != "enemy")
		world.shots = world.shots.filter(func(s): return s.get("owner", "enemy") != "enemy")
		if _dark_t > 0.0:
			world.light_override(-1.0)
		_dark_t = 0.0
	move_id = ""
	if in_mode() or not ResourceLoader.exists(FINALE):
		state = "closing"
		_close_t = 0.0
		if not eye3.is_empty():
			eye3["state"] = "blink"   # (its eye closes: it sleeps)
		sfx("hush_blink", "")
		return
	state = "finale"
	finale = load(FINALE).new()
	finale.setup(self, world)
	finale.start()


func finish(at: Vector2) -> void:
	## The finale's end (hush_finale.gd): the XP and the fall (the World's
	## died), the prize and the drops (boss_defeated), and the bell under him.
	defeated = true
	var h := {"how": "skill", "from_x": at.x}
	super._kill(h)
	if world != null:
		world.boss_defeated(self, at)
		world.add_bell(at)


# ---------------------------------------------------------------- the fight

func think(dt: float, player: Node2D) -> void:
	if BossMods.of(self) != null:
		BossMods.of(self).step(dt, player)
	timer -= dt
	_force_eye = false
	heard_t = maxf(heard_t - dt, 0.0)
	for f in flames:
		f["a"] = float(f["a"]) + dt * (0.9 if phase == 2 else 0.5)   # the crown turns
	_bright_t = maxf(_bright_t - dt, 0.0)
	_step_bells(dt)
	if state == "fight":
		_check_rings(player)
		_step_peals(dt)
		_step_hands(dt, player)
		_step_bolts(dt, player)
		_check_flames(player)
		if _dark_t > 0.0:
			_dark_t -= dt
			if _dark_t <= 0.0 and world != null:
				world.light_override(-1.0)
	match state:
		"sleep":
			shadow_k = move_toward(shadow_k, 0.0, dt)
			if player != null and player.alive and player.position.x > arena_left + 48.0 and absf(player.position.x - position.x) < 1100.0:
				state = "wake"
				timer = 1.2 if not _resumed else 0.4
				Arena.seal(world, level, door)
				woke.emit()
				sfx("hush_scream_silent", "boss_roar")
				if _resumed and world:
					world.bark("hush_remembers")
		"wake":
			if timer <= 0.0:
				if phase >= 2:
					_enter_phase(true)
				else:
					state = "fight"
					_act_timer = 1.0
		"roar":
			_roar_step(dt)
			if timer <= 0.0:
				state = "fight"
				_act_timer = 0.8
		"fight":
			match phase:
				1:
					_fight1(dt, player)
				2:
					_fight2(dt, player)
				_:
					_fight3(dt, player)
			_mercy_check(player)
		"finale":
			if finale != null:
				finale.step(dt)
		"closing":
			_close_t += dt
			if _close_t > 2.0 and not defeated:
				var at := Vector2(mid_x, islet_top)
				defeated = true
				super._kill({"how": "skill", "from_x": mid_x})
				if world != null:
					world.boss_defeated(self, at + Vector2(0, -40))
					world.add_bell(at)
	shadow_dip = move_toward(shadow_dip, _dip_goal(), 220.0 * dt)
	_update_part(player)
	_step_stems(dt)
	_update_shadow(dt, player)


func _dip_goal() -> float:
	## The Inhale and the choke bow it low over the middle islet: its Maw at
	## a standing Wick's head (the bite reaches him; choked, the core is at
	## his swing's height), whatever calling's rig it wears.
	match str(maw.get("state", "")):
		"inhale_tell", "inhale", "choked":
			var rel := maw_p() - shadow_foot()
			return maxf(-float(TUNE["maw_over"]) - 16.0 - rel.y, 0.0)
	return 0.0


func _used(mv: String) -> void:
	used[mv] = int(used.get(mv, 0)) + 1


func _gap() -> float:
	return cd(float(TUNE["gap"][clampi(phase - 1, 0, 2)]))


func _mercy_check(player: Node2D) -> void:
	if phase >= 3 and not _mercy and player != null and player.alive and player.life_frac() < 0.25 and world:
		_mercy = true
		var il := islet_at(player.position.x)
		var x := player.position.x if il >= 0 else mid_x
		var p: Dictionary = world._add_pickup("wax", Vector2(x, islet_top - 90.0))
		p["loose"] = true
		p["vel"] = Vector2.ZERO


# ---------------------------------------------------------------- bells and peals

func _step_bells(dt: float) -> void:
	for b in bells:
		b["lit"] = maxf(float(b["lit"]) - dt, 0.0)
		b["smother"] = maxf(float(b["smother"]) - dt, 0.0)
		b["flash"] = maxf(float(b["flash"]) - dt, 0.0)
		if b["sunk"]:
			b["sink"] = minf(float(b["sink"]) + dt, 1.0)
		if float(b["lit"]) <= 0.0 and int(b["light"]) >= 0 and world != null:
			world.remove_light(int(b["light"]))
			b["light"] = -1


func bell_ready(i: int) -> bool:
	return i >= 0 and i < bells.size() and not bells[i]["sunk"] and float(bells[i]["smother"]) <= 0.0


func _check_rings(player: Node2D) -> void:
	## Any hit on a sunken bell rings it: his swing, his shots, his waves.
	if player == null or world == null or phase >= 3:
		return
	for i in bells.size():
		var b: Dictionary = bells[i]
		if b["sunk"]:
			continue
		var r: Rect2 = b["rect"]
		var struck := false
		if player.attack_time >= 0.0 and player.attack_time <= player.ATTACK_ACTIVE and int(player.attack_id) != int(b["last_swing"]):
			if (player.attack_rect() as Rect2).intersects(r):
				b["last_swing"] = int(player.attack_id)
				struck = true
		for s in world.shots:
			if str(s.get("owner", "")) == "player" and float(s["life"]) > 0.0 and r.grow(4.0).has_point(s["pos"]):
				s["life"] = 0.0   # (it meets the bell)
				struck = true
		for hz in world.hazards:
			if str(hz.get("owner", "")) != "player" or not (hz.get("rect") is Rect2) or float(hz.get("delay", 0.0)) > 0.0:
				continue
			var rung: Array = hz.get("rung_bells", [])
			if not rung.has(i) and (hz["rect"] as Rect2).intersects(r):
				rung.append(i)
				hz["rung_bells"] = rung
				struck = true
		# The Bellfounder's slams and her Great Bell (their rings: the kit's
		# _slam_fx, each read once) count as ringing it.
		var fx = world.kit.get("_slam_fx") if world.get("kit") != null else null
		if fx is Array:
			for sf in fx:
				if sf is Dictionary and not sf.has("hush_rang") and float(sf.get("t", 1.0)) <= 0.05:
					var c: Vector2 = sf.get("p", Vector2.INF)
					if c != Vector2.INF and c.distance_to(r.get_center()) <= float(sf.get("r", 0.0)) + 14.0:
						struck = true
		if struck:
			ring_bell(i)
	var fx2 = world.kit.get("_slam_fx") if world.get("kit") != null else null
	if fx2 is Array:
		for sf in fx2:
			if sf is Dictionary:
				sf["hush_rang"] = true


func ring_bell(i: int) -> bool:
	## A peal (if the bell isn't smothered): the ring, the bell's light, a
	## choke (an Inhale on), the Eye coming to hush it (P1).
	if not bell_ready(i):
		if i >= 0 and i < bells.size() and not bells[i]["sunk"]:
			bells[i]["flash"] = 0.2
			sfx("clang", "clang", 0.6)
		return false
	var b: Dictionary = bells[i]
	b["lit"] = float(TUNE["bell_lit"])
	b["smother"] = float(TUNE["smother"])
	b["flash"] = 0.4
	if world != null:
		if int(b["light"]) >= 0:
			world.remove_light(int(b["light"]))
		b["light"] = world.add_light((b["p"] as Vector2) + Vector2(0, -26), float(TUNE["bell_light"]), 0.85, float(TUNE["bell_lit"]), "toll,hush_bell")
		world.shake = maxf(world.shake, 2.5)
		if world.glow:
			world.glow.burst((b["p"] as Vector2) + Vector2(0, -24), 14, GOLD, 150.0, 0.5, 0.0, 2.2)
	peals.append({"p": (b["p"] as Vector2) + Vector2(0, -24), "r": 0.0, "prev": 0.0, "bell": i})
	heard_t = float(TUNE["heard"])
	rings_rung += 1
	sfx("bell_peal_sunken", "peal")
	if state != "fight":
		return true
	match phase:
		1:
			var st := str(eye["state"])
			if st in ["lurk", "swim", "dive"]:
				eye["state"] = "swim"
				eye["bell"] = i
		2:
			if str(maw["state"]) in ["inhale_tell", "inhale"]:
				_choke()
	return true


func _step_peals(dt: float) -> void:
	## Each ring runs out; what of the Hush it passes is Heard (a Swallow
	## wall breaks; a Silence Bolt inside it goes).
	var speed := float(TUNE["peal_speed"])
	var maxr := float(TUNE["peal_r"])
	for pe in peals:
		pe["prev"] = pe["r"]
		pe["r"] = minf(float(pe["r"]) + speed * dt, maxr)
		var c: Vector2 = pe["p"]
		var r := float(pe["r"])
		for h in hands:
			if Vector2(float(h["x"]), water_y - 20.0).distance_to(c) <= r:
				h["heard"] = float(TUNE["heard"])
		if phase == 1 and (eye["p"] as Vector2).distance_to(c) <= r:
			eye["heard"] = float(TUNE["heard"])
		if not swallow.is_empty() and str(swallow["state"]) == "roll" and absf(float(swallow["x"]) - c.x) <= r:
			_break_swallow()
		if not snuff.is_empty() and (snuff["rect"] as Rect2).get_center().distance_to(c) <= r:
			snuff["heard"] = true
		for bo in bolts:
			if (bo["p"] as Vector2).distance_to(c) <= r:
				bo["life"] = 0.0
				if world and world.glow:
					world.glow.burst(bo["p"], 8, PALE, 90.0, 0.3, 0.0, 2.0)
	peals = peals.filter(func(pe): return float(pe["r"]) < maxr)


# ---------------------------------------------------------------- the Hands (every phase)

func _step_hands(dt: float, player: Node2D) -> void:
	if player != null:
		if absf(player.position.x - _still_x) > float(TUNE["still_r"]):
			_still_x = player.position.x
			_still_t = 0.0
		else:
			_still_t += dt
	for h in hands:
		h["heard"] = maxf(float(h["heard"]) - dt, 0.0)
		h["t"] = float(h["t"]) - dt
		match str(h["state"]):
			"rest":
				# Lurking under the water near him.
				if player != null:
					var want := nearest_edge(player.position.x) + (float(h["i"]) * 2.0 - 1.0) * 24.0
					h["x"] = move_toward(float(h["x"]), want, 120.0 * dt)
			"tell":
				if float(h["t"]) <= 0.0:
					h["state"] = "up"
					h["t"] = float(TUNE["grasp_up"])
					h["hit"] = false
					sfx("grasp_rise", "waxfall")
			"up":
				if not h["hit"] and player != null and player.alive and world != null and hand_rect(h).intersects((player.rect() as Rect2).grow(-2.0)):
					h["hit"] = true
					if world.hurt_player(dmg("grasp"), float(h["x"]), "grasp", self, {"move": "hush:grasp"}):
						HK.hush_player(world)
				if float(h["t"]) <= 0.0:
					h["state"] = "sink"
					h["t"] = 0.3
			"sink":
				if float(h["t"]) <= 0.0:
					h["state"] = "rest"
	if phase >= 1 and state == "fight" and (flood.is_empty()):
		_grasp_t -= dt
		if _grasp_t <= 0.0 and player != null and player.alive:
			var free := -1
			for h in hands:
				if str(h["state"]) == "rest":
					free = int(h["i"])
					break
			if free >= 0 and not (phase == 2 and str(maw["state"]) == "choked"):
				_grasp(free, player)
			_grasp_t = cd(float(TUNE["grasp_every"][clampi(phase - 1, 0, 2)]))


func grasp_tell() -> float:
	var base := float(TUNE["grasp_tell"])
	if phase == 2 or (phase == 1 and str(eye["state"]) in ["surface", "rise"]):
		base = float(TUNE["grasp_tell_up"])
	elif phase >= 3:
		base = float(TUNE["grasp_tell_p3"])
	return tell(base, float(TUNE["grasp_floor"]))


func _grasp(i: int, player: Node2D) -> void:
	## At the islet edge nearest him: the still water, the fingertips' ring
	## and a cold glint first (the tell), then the hand closes upward.
	var h: Dictionary = hands[i]
	h["x"] = nearest_edge(player.position.x)
	h["base"] = water_y
	# P1: stood still out of every edge's reach, it comes up through the
	# stone at his feet (the same column and tell: keep moving, islet to
	# islet). A perch is no hiding place either (the rev5 review: the three
	# inner perches in P1 and the entry perch in P2 took nothing): stood still
	# on one in P1 or P2, the hand comes up through it.
	var still := float(TUNE["grasp_still"])
	if phase <= 2 and still > 0.0 and _still_t >= still:
		var fy := floor_under(player)
		var on_perch := fy >= 0.0 and fy < islet_top - 1.0
		var on_islet := fy >= 0.0 and not on_perch
		if on_perch or (phase == 1 and on_islet and absf(float(h["x"]) - player.position.x) > float(TUNE["grasp_w"]) * 0.5 + 10.0):
			h["x"] = player.position.x
			h["base"] = fy
			_used("grasp_still")
	h["state"] = "tell"
	h["len"] = grasp_tell()
	h["t"] = h["len"]
	_used("grasp")
	tell_sfx("hush_still", float(h["len"]), "curdle")
	var s = world.get_node_or_null("/root/Sfx") if world != null and world.has_method("_has_sfx") and world._has_sfx() else null
	if s != null and s.has_method("hush_pulse"):
		s.hush_pulse(float(h["len"]), 0.6)


# ---------------------------------------------------------------- P1: the Quiet

func _fight1(dt: float, player: Node2D) -> void:
	_step_eye1(dt, player)
	_step_swallow(dt, player)
	_swallow_t -= dt
	if _swallow_t <= 0.0 and swallow.is_empty() and str(eye["state"]) in ["lurk", "swim"] and player != null:
		_swallow_t = cd(float(TUNE["swallow_every"]))
		var mid := (arena_left + arena_right) * 0.5
		var from_left := player.position.x > mid   # it gathers at the far end and rolls toward him
		swallow = {"state": "gather", "x": arena_left + 8.0 if from_left else arena_right - 8.0, "dir": 1.0 if from_left else -1.0,
				"t": tell(float(TUNE["swallow_tell"]), float(TUNE["swallow_floor"])), "passed": false}
		swallow["len"] = swallow["t"]
		move_id = "hush:swallow"
		_used("swallow")
		tell_sfx("hush_still", float(swallow["t"]), "curdle")


func _step_eye1(dt: float, player: Node2D) -> void:
	## The Eye under the lake: it lurks by him; a peal sends it to the bell
	## (260 px/s) to hush it; beside the bell it surfaces on the islet at his
	## height (the window), then dives and smothers it.
	eye["t"] = float(eye["t"]) - dt
	eye["heard"] = maxf(float(eye.get("heard", 0.0)) - dt, 0.0)
	var under := water_y + 14.0
	var p: Vector2 = eye["p"]
	match str(eye["state"]):
		"lurk":
			if player != null:
				var want := nearest_edge(player.position.x) + 40.0
				p = p.move_toward(Vector2(want, under), 90.0 * dt)
		"swim":
			var bi := int(eye["bell"])
			if bi < 0 or bi >= bells.size():
				eye["state"] = "lurk"
			else:
				var b: Vector2 = bells[bi]["p"]
				var side := 1.0 if player == null or player.position.x >= b.x else -1.0
				var room := islet_at(b.x + side * 36.0)
				if room < 0:
					side = -side
				eye["side"] = side
				var to := Vector2(b.x + side * 36.0, under)
				p = p.move_toward(to, spd(float(TUNE["eye_swim"])) * dt)
				if p.distance_to(to) < 3.0:
					eye["state"] = "rise"
					eye["t"] = 0.3
					sfx("hush_eye_open", "")
		"rise":
			var to2 := Vector2(p.x, islet_top - 26.0)
			p = p.move_toward(to2, 360.0 * dt)
			if float(eye["t"]) <= 0.0:
				p = to2
				_open_window1()
		"surface":
			if float(eye["t"]) <= 0.0:
				_end_window()
		"dive":
			p = p.move_toward(Vector2(p.x, under), 300.0 * dt)
			if float(eye["t"]) <= 0.0:
				var bi2 := int(eye["bell"])
				if bi2 >= 0 and bi2 < bells.size():
					bells[bi2]["lit"] = 0.0   # smothered: its light goes out
				eye["state"] = "lurk"
				eye["bell"] = -1
	eye["p"] = p


func _open_window1() -> void:
	eye["state"] = "surface"
	eye["t"] = window_len(1)
	eye["heard"] = float(TUNE["heard"])
	_window_dmg = 0.0
	windows_opened += 1
	window_stomps = 0
	_used("window")


func _step_swallow(dt: float, player: Node2D) -> void:
	if swallow.is_empty():
		return
	match str(swallow["state"]):
		"gather":
			swallow["t"] = float(swallow["t"]) - dt
			if float(swallow["t"]) <= 0.0:
				swallow["state"] = "roll"
		"roll":
			var was := float(swallow["x"])
			var nx := was + float(swallow["dir"]) * float(TUNE["swallow_speed"]) * dt
			swallow["x"] = nx
			if player != null and player.alive and signf(player.position.x - was) != signf(player.position.x - nx):
				# It passes him: his light is forced to the floor (scripted).
				_dark_t = float(TUNE["swallow_dark"])
				if world != null:
					world.light_override(LIGHT_MIN)
			for b in bells:
				var bx: float = (b["p"] as Vector2).x
				if signf(bx - was) != signf(bx - nx) and float(b["lit"]) > 0.0:
					b["lit"] = 0.0
			if nx < arena_left - 20.0 or nx > arena_right + 20.0:
				swallow = {}
				move_id = ""


func _break_swallow() -> void:
	## A peal reached the wall: the Quiet flinches and the Eye is there, Heard.
	var x := float(swallow["x"])
	swallow = {}
	move_id = ""
	if world and world.glow:
		world.glow.burst(Vector2(x, islet_top - 60.0), 26, PALE, 220.0, 0.6, 0.0, 2.6)
	if str(eye["state"]) != "surface":
		var il := nearest_islet(x)
		var cx := clampf(x, float(islets[il]["x0"]) + 20.0, float(islets[il]["x1"]) - 20.0)
		eye["p"] = Vector2(cx, water_y + 14.0)
		eye["state"] = "rise"
		eye["t"] = 0.3
		eye["bell"] = -1
	_used("swallow_broken")


# ---------------------------------------------------------------- P2: the Mouth

func _fight2(dt: float, player: Node2D) -> void:
	_step_maw(dt, player)
	_step_snuff(dt, player)
	if act == "bolts":
		act_t -= dt
		if act_t <= 0.0:
			_fire_bolts(player)
			act = ""
			_act_timer = _gap()
	if act == "" and str(maw["state"]) in ["idle"] and snuff.is_empty():
		_act_timer -= dt
		if _act_timer <= 0.0 and player != null:
			_move_n += 1
			var loop: Array = TUNE["p2_loop"]
			var mv: String = loop[_move_n % loop.size()]
			match mv:
				"inhale":
					maw["state"] = "inhale_tell"
					maw["t"] = tell(float(TUNE["inhale_tell"]), float(TUNE["inhale_floor"]))
					move_id = "hush:inhale"
					_inhale_hit = false
					tell_sfx("inhale_roar", float(maw["t"]), "whoosh")
				"snuff":
					_start_snuff(player)
				"bolts":
					# The tell: the crown's flames darken and three dark orbs
					# gather where they'll leave from (drawn in _glow_bolt_tell).
					act = "bolts"
					act_len = tell(float(TUNE["bolt_tell"]), float(TUNE["bolt_floor"]))
					act_t = act_len
					move_id = "hush:bolt"
					tell_sfx("echo_whisper", act_len, "snuffer_whisper")
			_used(mv)


func _step_maw(dt: float, player: Node2D) -> void:
	maw["t"] = float(maw["t"]) - dt
	match str(maw["state"]):
		"inhale_tell":
			if float(maw["t"]) <= 0.0:
				maw["state"] = "inhale"
				maw["t"] = float(TUNE["inhale_pull"])
		"inhale":
			if player != null and player.alive and world != null:
				if not HK.over_pit(world, player):
					var dir := signf(maw_p().x - player.position.x)
					world.push_player(Vector2(dir * float(TUNE["inhale_speed"]), 0.0), 0.12, "hush_inhale")
				world.dim("hush_inhale", float(TUNE["inhale_dim"]), 0.15)
				if not _inhale_hit and maw_rect().intersects(player.rect()):
					_inhale_hit = true
					world.hurt_player(dmg("inhale"), maw_p().x, "hit", self, {"move": "hush:inhale"})
			if float(maw["t"]) <= 0.0:
				maw["state"] = "idle"
				move_id = ""
				_act_timer = _gap()
		"choked":
			if float(maw["t"]) <= 0.0:
				_end_window()
		"rise":
			if float(maw["t"]) <= 0.0:
				maw["state"] = "idle"
				_act_timer = _gap()


func _choke() -> void:
	## The Maw swallows the peal and chokes on it: open, low, its crown
	## dipped (the window).
	maw["state"] = "choked"
	maw["t"] = window_len(2)
	_window_dmg = 0.0
	windows_opened += 1
	window_stomps = 0
	move_id = ""
	_used("window")
	sfx("choke", "boss_hit")
	if world:
		world.shake = maxf(world.shake, 6.0)
		if world.glow:
			world.glow.burst(maw_p(), 24, PALE, 200.0, 0.5, 0.0, 2.4)


func _start_snuff(player: Node2D) -> void:
	var il := nearest_islet(player.position.x)
	var isl: Dictionary = islets[il]
	var w := float(TUNE["snuff_w"]) * TILE
	var cx := clampf(player.position.x, float(isl["x0"]) + w * 0.5, float(isl["x1"]) - w * 0.5)
	if float(isl["x1"]) - float(isl["x0"]) < w:
		cx = (float(isl["x0"]) + float(isl["x1"])) * 0.5
	var h := float(TUNE["snuff_h"]) * TILE
	var t0 := tell(float(TUNE["snuff_tell"]), float(TUNE["snuff_floor"]))
	snuff = {"state": "tell", "t": t0, "len": t0, "rect": Rect2(cx - w * 0.5, islet_top - h, w, h), "islet": il, "heard": false, "hit": false}
	move_id = "hush:snuff"
	tell_sfx("hush_silence", t0, "snuffer_whisper")


func _step_snuff(dt: float, player: Node2D) -> void:
	if snuff.is_empty():
		return
	snuff["t"] = float(snuff["t"]) - dt
	match str(snuff["state"]):
		"tell":
			if float(snuff["t"]) <= 0.0:
				snuff["state"] = "slam"
				snuff["t"] = float(TUNE["snuff_up"])
				snuff["heard"] = heard_t > 0.0
				sfx("snuff_slam", "snuffer_slam")
				if world:
					world.shake = maxf(world.shake, 7.0)
					world._haptic(40)
		"slam":
			if not snuff["hit"] and player != null and player.alive and world != null and (snuff["rect"] as Rect2).intersects((player.rect() as Rect2).grow(-3.0)):
				snuff["hit"] = true
				if world.hurt_player(dmg("snuff"), (snuff["rect"] as Rect2).get_center().x, "snuff", self, {"move": "hush:snuff"}):
					HK.hush_player(world)
			if float(snuff["t"]) <= 0.0:
				snuff = {}
				move_id = ""
				_act_timer = _gap()


func bolt_from(k: int) -> Vector2:
	## Where Silence Bolt k leaves the crown (and gathers in the tell).
	return crown() + Vector2((k - 1) * 40.0, -6.0)


func flame_dim() -> float:
	## The stolen flames' brightness: the Silence Bolts' tell darkens them.
	if act != "bolts" or act_len <= 0.0:
		return 1.0
	return lerpf(1.0, 0.2, 1.0 - clampf(act_t / act_len, 0.0, 1.0))


func _fire_bolts(player: Node2D) -> void:
	if player == null:
		return
	for k in 3:
		var at := bolt_from(k)
		var d := ((player.center() as Vector2) - at).normalized().rotated((k - 1) * 0.28)
		bolts.append({"p": at, "v": d * float(TUNE["bolt_speed"]), "life": float(TUNE["bolt_life"])})
	sfx("stitch_snap", "")


func _step_bolts(dt: float, player: Node2D) -> void:
	for bo in bolts:
		bo["life"] = float(bo["life"]) - dt
		var v: Vector2 = bo["v"]
		if player != null and player.alive:
			var want := ((player.center() as Vector2) - (bo["p"] as Vector2)).angle()
			var turn := clampf(angle_difference(v.angle(), want), -float(TUNE["bolt_turn"]) * dt, float(TUNE["bolt_turn"]) * dt)
			v = v.rotated(turn)
			bo["v"] = v
		var nx: Vector2 = (bo["p"] as Vector2) + v * dt
		if solid_at(nx):
			bo["life"] = 0.0
		bo["p"] = nx
		if float(bo["life"]) > 0.0 and player != null and player.alive and world != null and (player.rect() as Rect2).grow(-2.0).has_point(nx):
			bo["life"] = 0.0
			if world.hurt_player(dmg("bolt"), nx.x - signf(v.x) * 20.0, "silence", null, {"shot": true, "vel": v, "pos": nx, "move": "hush:bolt"}):
				HK.hush_player(world)
	bolts = bolts.filter(func(bo): return float(bo["life"]) > 0.0)


func _check_flames(player: Node2D) -> void:
	## A stolen flame struck free (a swing or a shot on it): it flies to him,
	## heals 6% and his light is +20% for 6 s. Once each.
	if player == null or world == null or not flames_strikable():
		return
	var ar: Rect2 = player.attack_rect() if player.attack_time >= 0.0 and player.attack_time <= player.ATTACK_ACTIVE else Rect2()
	for i in flames.size():
		if flames[i]["freed"]:
			continue
		var fr := flame_rect(i)
		var struck := ar.size.x > 0.0 and ar.intersects(fr)
		if not struck:
			for s in world.shots:
				if str(s.get("owner", "")) == "player" and float(s["life"]) > 0.0 and fr.grow(4.0).has_point(s["pos"]):
					s["life"] = 0.0
					struck = true
					break
		if struck:
			free_flame(i)


func free_flame(i: int) -> void:
	if i < 0 or i >= flames.size() or flames[i]["freed"]:
		return
	flames[i]["freed"] = true
	_bright_t = float(TUNE["flame_light_t"])
	sfx("flame_freed", "relight")
	_used("flame")
	if world != null and world.get("player") != null:
		var pl = world.player
		pl.heal_pct(float(TUNE["flame_heal"]))
		world.number(pl.center() + Vector2(0, -30), float(TUNE["flame_heal"]) * float(pl.max_hp), "heal")
		if world.glow:
			world.glow.burst(flame_p(i), 16, Color(0.95, 0.9, 1.0), 180.0, 0.5, -60.0, 2.4)
			world.glow.burst(pl.center(), 12, Color(1.0, 0.85, 0.5), 120.0, 0.5, -60.0, 2.2)


# ---------------------------------------------------------------- P3: the Eye

func _fight3(dt: float, player: Node2D) -> void:
	if eye3.is_empty():
		eye3 = {"p": Vector2(mid_x, arena_top + 120.0), "state": "hover", "t": 0.0, "len": 0.0, "side": 1.0}
	_step_flood(dt, player)
	var st := str(eye3["state"])
	eye3["t"] = float(eye3["t"]) - dt
	var p: Vector2 = eye3["p"]
	if player != null:
		var edge := float(TUNE["hover_edge"])
		if st == "gaze_tell" or st == "gaze_lock" or st == "gaze_fire":
			edge = float(TUNE["gaze_edge"])
		var side := float(eye3["side"])
		var room_r := arena_right - 120.0 - player.position.x
		var room_l := player.position.x - (arena_left + 120.0)
		if st == "hover" and (side > 0.0 and room_r < edge + 112.0 or side < 0.0 and room_l < edge + 112.0):
			side = -side if (side > 0.0 and room_l > room_r) or (side < 0.0 and room_r > room_l) else side
			eye3["side"] = side
		var want := Vector2(player.center().x + side * (edge + 112.0), player.center().y - 80.0)
		var speed := 160.0
		if st == "blink":
			# It drifts to his height beside him and holds there, shut (a
			# still target: struck, or stomped from a jump).
			want = Vector2(player.center().x + side * (float(TUNE["blink_edge"]) + 112.0), player.center().y - 4.0)
			speed = 0.0 if bool(eye3.get("held", false)) else 700.0
		elif st in ["gaze_lock", "gaze_fire"]:
			speed = 0.0
		want.x = clampf(want.x, arena_left + 120.0, arena_right - 120.0)
		want.y = clampf(want.y, arena_top + 48.0, islet_top - 30.0)
		p = p.move_toward(want, spd(speed) * dt) if speed > 0.0 else p
		if st == "blink" and not bool(eye3.get("held", false)) and p.distance_to(want) < 3.0:
			eye3["held"] = true
	eye3["p"] = p
	match st:
		"gaze_tell":
			if float(eye3["t"]) <= 0.0:
				eye3["state"] = "gaze_lock"
				eye3["len"] = tell(float(TUNE["gaze_lock"]), float(TUNE["gaze_lock_floor"]))
				eye3["t"] = eye3["len"]
				eye3["a"] = pupil()
				eye3["b"] = player.center() if player != null else pupil() + Vector2(0, 100)
				sfx("gaze_lock", "knell")
		"gaze_lock":
			if float(eye3["t"]) <= 0.0:
				_fire_gaze()
		"gaze_fire":
			_gaze_check(player)
			if float(eye3["t"]) <= 0.0 and str(eye3["state"]) == "gaze_fire":
				_start_blink()
		"blink":
			if float(eye3["t"]) <= 0.0:
				_end_window()
		"open":
			if float(eye3["t"]) <= 0.0:
				eye3["state"] = "hover"
				_act_timer = _gap()
		"hover":
			if flood.is_empty():
				_act_timer -= dt
				if _act_timer <= 0.0 and player != null:
					_move_n += 1
					var loop := ["gaze", "gaze", "deep_quiet", "gaze", "gaze"]
					var mv: String = loop[_move_n % loop.size()]
					_used(mv)
					if mv == "gaze":
						eye3["state"] = "gaze_tell"
						eye3["len"] = tell(float(TUNE["gaze_tell"]), float(TUNE["gaze_floor"]))
						eye3["t"] = eye3["len"]
						move_id = "hush:gaze"
					else:
						var t0 := tell(float(TUNE["quiet_tell"]), float(TUNE["quiet_floor"]))
						flood = {"state": "tell", "t": t0, "len": t0, "y": islet_top - TILE}
						move_id = "hush:deep_quiet"
						tell_sfx("deep_quiet", t0, "snuffer_whisper")
						_act_timer = t0 + float(TUNE["quiet_up"]) + 1.2


func _fire_gaze() -> void:
	## A beam of silence along the locked line (world's beam hazard: the
	## knight's guard meets it by its line; a Perfect Guard sends it back).
	var a: Vector2 = eye3["a"]
	var b: Vector2 = eye3["b"]
	var dir := (b - a).normalized()
	var p := a
	for i in 500:
		var q := p + dir * 4.0
		if solid_at(q) or q.y > level.height * TILE + 32.0:
			break
		p = q
	eye3["state"] = "gaze_fire"
	eye3["t"] = float(TUNE["gaze_fire"])
	eye3["end"] = p
	_gaze_hit = false
	if world != null:
		_gaze_hz = world.add_hazard({"kind": "beam", "seg": [a, p], "width": float(TUNE["gaze_w"]), "life": float(TUNE["gaze_fire"]),
				"dmg": dmg("gaze"), "owner": "enemy", "reflect": true, "source": self, "move": "hush:gaze", "shot": false})


func _gaze_check(player: Node2D) -> void:
	## A Gaze that hurt him hushes him too (once).
	if _gaze_hit or player == null or _gaze_hz.is_empty():
		return
	var seg: Array = _gaze_hz.get("seg", [])
	if seg.size() == 2 and float(player.hurt_time) <= 0.02 and not bool(_gaze_hz.get("reflected", false)):
		if _seg_hits(seg[0], seg[1], float(TUNE["gaze_w"]), player.rect()):
			_gaze_hit = true
			HK.hush_player(world)


static func _seg_hits(a: Vector2, b: Vector2, width: float, r: Rect2) -> bool:
	var g := r.grow(width * 0.5)
	if g.has_point(a) or g.has_point(b):
		return true
	var c := [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


func _start_blink() -> void:
	## The window: it closes and drifts to his height, its near edge within 40 px.
	if not _gaze_hz.is_empty():
		_gaze_hz["life"] = 0.0
	eye3["state"] = "blink"
	eye3["held"] = false
	eye3["t"] = window_len(3)
	_window_dmg = 0.0
	windows_opened += 1
	window_stomps = 0
	move_id = ""
	_used("window")
	sfx("hush_blink", "")


func _step_flood(dt: float, player: Node2D) -> void:
	## The Deep Quiet: the still lake, a pale line where the water will stand,
	## then a row of black water over the islet tops for 2.0 s.
	if flood.is_empty():
		return
	flood["t"] = float(flood["t"]) - dt
	match str(flood["state"]):
		"tell":
			if float(flood["t"]) <= 0.0:
				flood["state"] = "up"
				flood["t"] = float(TUNE["quiet_up"])
		"up":
			if player != null and player.alive and world != null and float(player.center().y) > float(flood["y"]) \
					and player.position.x > arena_left and player.position.x < arena_right:
				var pc := perch_near(player.position.x)
				if not pc.is_empty():
					var x := clampf(player.position.x, float(pc["x0"]) + 12.0, float(pc["x1"]) - 12.0)
					player.last_safe = Vector2(x, float(pc["top"]))
				world.fell("water")
			if float(flood["t"]) <= 0.0:
				flood["state"] = "down"
				flood["t"] = 0.6
		"down":
			if float(flood["t"]) <= 0.0:
				flood = {}
				move_id = ""


# ---------------------------------------------------------------- phases

func _enter_phase(resumed := false) -> void:
	## A blow reached the line (or a checkpoint's return): the roar (2.0 s).
	## P2: the lake heaves and the shadow rises; P3: it collapses, the bells
	## sink, the Eye opens.
	_clear_adds()
	bolts.clear()
	snuff = {}
	swallow = {}
	flood = {}
	act = ""
	move_id = ""
	_move_n = -1
	_window_dmg = 0.0
	if _dark_t > 0.0 and world != null:
		world.light_override(-1.0)
	_dark_t = 0.0
	eye["state"] = "lurk" if phase == 1 else "gone"
	maw = {"state": "idle", "t": 0.0}
	for h in hands:
		h["state"] = "rest"
	state = "roar"
	timer = float(TUNE["roar_resumed"] if resumed else TUNE["roar"])
	_roar_len = timer
	if world:
		world.shake = 8.0
		if not resumed:
			world.boss_phase(self, phase)
		else:
			world.phase_reached = maxi(int(world.phase_reached), phase)
	if phase == 2:
		sfx("hush_scream_silent", "boss_roar")
		_stem("drums", -80.0, 2.0)
	elif phase >= 3:
		sfx("hush_eye_open", "boss_roar")
		_stem("drums", -80.0, 2.0)
		_stem("choir", -80.0, 2.0)
		_stem("bells", -80.0, 2.0)
		for b in bells:
			b["sunk"] = true
		eye3 = {"p": Vector2(mid_x, arena_top + 120.0), "state": "open", "t": _roar_len, "len": 0.0, "side": 1.0}
	_used("roar")


func _roar_step(dt: float) -> void:
	match phase:
		2:
			shadow_k = move_toward(shadow_k, 1.0, dt / maxf(_roar_len, 0.1))
		3:
			shadow_k = move_toward(shadow_k, 0.0, dt / (maxf(_roar_len, 0.1) * 0.6))


func _choir(n: int, kind_id: String) -> void:
	## The Drowned Choir (Hushlings) or the Echoes of Light (Unwicks): up
	## onto islets that aren't his, one each.
	if world == null or islets.is_empty():
		return
	var mine := islet_at(world.player.position.x) if world.get("player") != null else -1
	var order: Array = []
	for i in islets.size():
		if i != mine:
			order.append(i)
	order.sort_custom(func(a, b): return absf(float(islets[a]["x0"]) - world.player.position.x) < absf(float(islets[b]["x0"]) - world.player.position.x))
	for k in mini(n, order.size()):
		var il: Dictionary = islets[order[k]]
		var at := Vector2((float(il["x0"]) + float(il["x1"])) * 0.5 + (k - 1) * 20.0, float(il["top"]))
		var e: Node2D = world.spawn_enemy(kind_id, at, {"respawned": true, "facing": -1 if at.x > world.player.position.x else 1})
		if e:
			e.active = true
			if e.has_method("as_add"):
				e.as_add()
			_adds.append(e)
			if world.glow:
				world.glow.burst(at + Vector2(0, -16), 12, PALE, 120.0, 0.5, -60.0, 2.4)
	_used("choir" if kind_id == "hushling" else "echoes")


func _clear_adds() -> void:
	for e in _adds:
		if is_instance_valid(e) and e.alive:
			e.alive = false
			e.gone = true
	_adds.clear()


func _stem(name: String, db: float, sec: float) -> void:
	if world == null or not world.has_method("_has_sfx") or not world._has_sfx():
		return
	var s = world.get_node_or_null("/root/Sfx")
	if s != null and s.has_method("set_stem"):
		s.set_stem("hush_final_" + name, db, sec)


func _step_stems(dt: float) -> void:
	## P3: the wick stem follows his flame.
	if phase < 3 or state != "fight":
		return
	_stem_t -= dt
	if _stem_t <= 0.0:
		_stem_t = 0.25
		var lf := _wick_db()
		if absf(lf - _stem_frac) > 0.5:
			_stem_frac = lf
			_stem("wick", lf, 0.2)


# ---------------------------------------------------------------- the shadow Waxby

const SHADOW_SHADER := """shader_type canvas_item;
render_mode unshaded;
uniform vec4 body : source_color = vec4(0.03, 0.025, 0.06, 1.0);
uniform vec4 rim : source_color = vec4(0.784, 0.784, 0.941, 1.0);
uniform float px = 2.0;
uniform float alpha = 1.0;
uniform float body_a = 1.0;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 d = TEXTURE_PIXEL_SIZE * px;
	float o = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		o = max(o, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * d).a);
	}
	float edge = clamp(o - a, 0.0, 1.0);
	vec4 c = vec4(body.rgb, a * body_a) * (1.0 - edge) + vec4(rim.rgb, 1.0) * edge;
	c.a = max(a * body_a, edge) * alpha;
	COLOR = c;
}
"""
static var _shadow_shader: Shader = null


func _shadow_foot_tex() -> Vector2:
	return Vector2(SHADOW_VIEW.x * 0.5, SHADOW_VIEW.y - SHADOW_FOOT) * SHADOW_SCALE * _sh_k


func _make_shadow() -> void:
	## His rig at 3x, alone on a small SubViewport (the Unwick's way), shown
	## twice: its black body behind the tiles (under the dark, so it hides
	## the nave behind it and never covers him), and its silver rim over the
	## dark on the glow layer, cut off at the lake.
	if _shadow_spr != null or world == null or world.get("glow") == null:
		return
	var layer: Node = (world.glow as Node).get_parent()
	if layer == null:
		return
	var cls := "knight"
	if world.get("kit") != null and world.kit.get("cls") != null:
		cls = str(world.kit.cls)
	_sh_k = 1.5
	var vp := SubViewport.new()
	vp.name = "HushShadowView"
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.size = Vector2i(ceili(SHADOW_VIEW.x * SHADOW_SCALE * _sh_k), ceili(SHADOW_VIEW.y * SHADOW_SCALE * _sh_k))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(vp)
	_shadow_vp = vp
	_puppet = UW.Puppet.new()
	_puppet.visible = false
	vp.add_child(_puppet)
	var holder := Node2D.new()
	holder.position = _shadow_foot_tex()
	holder.scale = Vector2(SHADOW_SCALE * _sh_k, SHADOW_SCALE * _sh_k)
	vp.add_child(holder)
	var rig: Node2D = RigScript.new()
	rig.set("cls", cls)
	rig.set("player", _puppet)
	rig.set("kit", null)
	holder.add_child(rig)
	_shadow_rig = rig
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = SHADOW_SHADER
	var pair := []
	for rim_only in [false, true]:
		var mat := ShaderMaterial.new()
		mat.shader = _shadow_shader
		mat.set_shader_parameter("rim", HK.RIM if rim_only else Color(0.03, 0.025, 0.06))
		mat.set_shader_parameter("body", Color(0.03, 0.025, 0.06))
		mat.set_shader_parameter("px", 2.5 * _sh_k)
		mat.set_shader_parameter("body_a", 0.0 if rim_only else 1.0)
		var spr := Sprite2D.new()
		spr.name = "HushShadowRim" if rim_only else "HushShadow"
		spr.centered = false
		spr.texture = vp.get_texture()
		spr.scale = Vector2.ONE / _sh_k
		spr.material = mat
		spr.region_enabled = true
		if rim_only:
			spr.z_index = -2
			layer.add_child(spr)
		else:
			spr.z_index = -5   # (the backdrop is at -10, the tiles at 0)
			world.add_child(spr)
		pair.append(spr)
	_shadow_spr = pair[0]
	_shadow_rim = pair[1]


func _update_shadow(_dt: float, player: Node2D) -> void:
	## Risen in P2 (and while it sinks in P3's roar): standing in the lake
	## behind the middle islet, facing him.
	var show := shadow_k > 0.01 and alive and state in ["roar", "fight", "wake"]
	if not show:
		if _shadow_spr != null:
			_shadow_spr.visible = false
			_shadow_rim.visible = false
			if _shadow_vp != null and _shadow_vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
				_shadow_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED   # (no render while it's gone)
		return
	_make_shadow()
	if _shadow_spr == null:
		return
	if _shadow_vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_shadow_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var foot := shadow_foot()
	var pos := foot - _shadow_foot_tex() / _sh_k
	var tex_w := float(_shadow_vp.size.x)
	var tex_h := float(_shadow_vp.size.y)
	var a := clampf(shadow_k * 1.2, 0.0, 1.0)
	for spr in [_shadow_spr, _shadow_rim]:
		spr.visible = true
		spr.position = pos
		var cut := tex_h if spr == _shadow_spr else clampf((islet_top - pos.y) * _sh_k, 0.0, tex_h)
		spr.region_rect = Rect2(0, 0, tex_w, cut)
		var mat := spr.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("alpha", a)
	if _puppet != null and player != null:
		_puppet.set("facing", 1 if player.position.x >= foot.x else -1)
		_puppet.set("velocity", Vector2.ZERO)
		_puppet.set("on_floor", true)


# ---------------------------------------------------------------- the bot's thumbs

var _bot := {"jump": 0, "rest": 0, "atk": false, "runs": [], "runs_t": -1.0, "land": {}}


func bot_pad(pl: Node2D) -> Dictionary:
	## A pad that fights it (the --autoplay bot's, through world.boss's
	## bot_pad: W0 asked; the tests' real-pad runs): P1, to a ready bell and
	## ring it, then strike the Eye that comes up beside it; P2, beside a
	## ready bell until an Inhale, ring it, then to the choked core; P3,
	## off a locked Gaze, onto high ground before the Deep Quiet, the Blink
	## struck; off any Grasp or Snuff that would close on him; the stair,
	## the finale's own. Nothing else dodged.
	if pl == null or not pl.alive or world == null or not alive:
		return {}
	if state == "finale" and finale != null:
		return finale.bot_pad(pl)
	var pad := {}
	var want := Vector2.INF
	var foe_x := INF
	var dodge := {}
	match state:
		"sleep", "wake", "roar":
			if pl.position.x < arena_left + 120.0:
				want = Vector2(arena_left + 160.0, islet_top)
		"fight":
			match phase:
				1:
					if str(eye["state"]) in ["rise", "surface"]:
						var er := eye1_rect()
						want = _bot_beside(pl, er.get_center().x, 34.0)
						foe_x = er.get_center().x if absf(pl.position.x - er.get_center().x) < 60.0 else INF
					elif str(eye["state"]) == "swim" and int(eye["bell"]) >= 0:
						# (it's coming to hush the bell he rang: wait beside it)
						want = _bot_beside(pl, (bells[int(eye["bell"])]["p"] as Vector2).x, 60.0)
					else:
						var bi := _bot_bell(pl, pl.position.x)
						if bi >= 0:
							var bx: float = (bells[bi]["p"] as Vector2).x
							want = _bot_beside(pl, bx, 24.0)
							if absf(pl.position.x - want.x) < 8.0 and absf(pl.position.y - want.y) < 3.0:
								foe_x = bx
				2:
					if str(maw["state"]) == "choked":
						var cr := core_rect()
						want = _bot_beside(pl, cr.get_center().x, 30.0)
						foe_x = cr.get_center().x if absf(pl.position.x - cr.get_center().x) < 60.0 else INF
					else:
						var bi2 := _bot_bell(pl, mid_x)
						if bi2 >= 0:
							var bx2: float = (bells[bi2]["p"] as Vector2).x
							want = _bot_beside(pl, bx2, 24.0, mid_x)
							if str(maw["state"]) in ["inhale_tell", "inhale"] and absf(pl.position.x - bx2) < 44.0:
								foe_x = bx2
				_:
					var st3 := str(eye3.get("state", ""))
					if not flood.is_empty():
						want = _bot_high_ground(pl)
					elif st3 == "blink":
						var r3 := eye3_rect()
						var ex := r3.position.x if pl.position.x < r3.get_center().x else r3.end.x
						want = Vector2(pl.position.x, pl.position.y) if pl.on_floor else Vector2.INF
						foe_x = ex
					elif st3 == "gaze_lock" and eye3.has("a"):
						dodge = {"a": eye3["a"], "b": eye3["b"], "t": float(eye3["t"])}
	# Off a hand, a palm or a flood about to close on him (first).
	var threat := _bot_threat(pl)
	if threat != INF:
		want = Vector2(threat, _bot_floor_y(pl, threat))
		foe_x = INF
	if want != Vector2.INF:
		pad = _bot_nav(pl, want)
	if not dodge.is_empty():
		pad = _bot_dodge(pl, dodge)
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


func _bot_bell(pl: Node2D, near_x: float) -> int:
	## The ready bell nearest near_x (every bell's smothered: the one ready soonest).
	var best := -1
	var bd := INF
	for i in bells.size():
		if bells[i]["sunk"]:
			continue
		var d := absf((bells[i]["p"] as Vector2).x - near_x) + float(bells[i]["smother"]) * 400.0
		if d < bd:
			bd = d
			best = i
	return best


func _bot_floor_y(pl: Node2D, x: float) -> float:
	for r in _bot_runs():
		if x >= float(r["x0"]) and x <= float(r["x1"]) and absf(float(r["y"]) - pl.position.y) < 3.0:
			return float(r["y"])
	return islet_top


func _bot_beside(pl: Node2D, x: float, gap: float, toward := INF) -> Vector2:
	## gap px beside x on its islet, on his side (or toward's), the other
	## side when the islet ends there.
	var il := islet_at(x)
	var side := 1.0 if (toward if toward != INF else pl.position.x) >= x else -1.0
	if il < 0:
		return Vector2(x + side * gap, islet_top)
	var lo := float(islets[il]["x0"]) + 14.0
	var hi := float(islets[il]["x1"]) - 14.0
	var bx := x + side * gap
	if bx < lo or bx > hi or _bot_blocked(bx):
		bx = x - side * gap
	return Vector2(clampf(bx, lo, hi), islet_top)


func _bot_blocked(x: float) -> bool:
	## A tall stone stands there (its top isn't the islet's).
	var c := floori(x / TILE)
	return LevelData.is_solid(level.tile(c, floori(islet_top / TILE) - 1))


func _bot_threat(pl: Node2D) -> float:
	## Where to step to get out of a Grasp's column or the Snuff's palm that
	## is about to close where he stands (INF: nothing coming).
	var r := (pl.rect() as Rect2).grow(6.0)
	var cols: Array = []
	for h in hands:
		if str(h["state"]) in ["tell", "up"]:
			var hb := float(h.get("base", water_y))
			cols.append(Rect2(float(h["x"]) - float(TUNE["grasp_w"]) * 0.5, hb - float(TUNE["grasp_h"]) - 8.0, float(TUNE["grasp_w"]), float(TUNE["grasp_h"]) + 8.0))
	if not snuff.is_empty():
		cols.append((snuff["rect"] as Rect2).grow_individual(0, 60.0, 0, 0))
	for c in cols:
		var cr: Rect2 = c
		if not cr.intersects(r):
			continue
		# The nearer side out of it, on the footing he's on (or the next islet over).
		var outs := [cr.position.x - 16.0, cr.end.x + 16.0]
		var best := INF
		for ox in outs:
			if islet_at(ox) >= 0 and not _bot_blocked(ox) and absf(ox - pl.position.x) < absf(best - pl.position.x):
				var clear := true
				for c2 in cols:
					if (c2 as Rect2).grow(10.0).has_point(Vector2(ox, (c2 as Rect2).get_center().y)):
						clear = false
				if clear:
					best = ox
		if best == INF:
			# (nowhere on this islet: the next one over)
			var il := islet_at(pl.position.x)
			if il >= 0:
				var dir := -1.0 if pl.position.x - float(islets[il]["x0"]) < float(islets[il]["x1"]) - pl.position.x else 1.0
				var nb := il + int(dir)
				if nb >= 0 and nb < islets.size():
					best = (float(islets[nb]["x0"]) + float(islets[nb]["x1"])) * 0.5
		return best
	return INF


func _bot_high_ground(pl: Node2D) -> Vector2:
	## The Deep Quiet: the nearest perch or tall stone.
	var p := perch_near(pl.position.x)
	if p.is_empty():
		return Vector2.INF
	var x := clampf(pl.position.x, float(p["x0"]) + 14.0, float(p["x1"]) - 14.0)
	return Vector2(x, float(p["top"]))


func _bot_runs() -> Array:
	## Every top he can stand on in the arena (the islets split by the tall
	## stones, the stones' tops, the perches), cached a second.
	if float(_bot["runs_t"]) >= 0.0 and t - float(_bot["runs_t"]) < 1.0:
		return _bot["runs"]
	var out: Array = []
	var c0 := floori(arena_left / TILE) - 2
	var c1 := floori(arena_right / TILE)
	for yy in range(floori(arena_top / TILE) + 1, floori(islet_top / TILE) + 1):
		var x := c0
		while x < c1:
			if _bot_top(x, yy):
				var x1 := x
				while x1 + 1 < c1 and _bot_top(x1 + 1, yy):
					x1 += 1
				out.append({"x0": float(x * TILE), "x1": float((x1 + 1) * TILE), "y": float(yy * TILE)})
				x = x1 + 1
			else:
				x += 1
	_bot["runs"] = out
	_bot["runs_t"] = t
	return out


func _bot_top(x: int, y: int) -> bool:
	var tl: int = level.tile(x, y)
	var up: int = level.tile(x, y - 1)
	return (LevelData.is_solid(tl) or LevelData.is_ledge(tl)) and not LevelData.is_solid(up) and not LevelData.is_ledge(up)


func _bot_run_at(p: Vector2) -> Dictionary:
	for r in _bot_runs():
		if absf(p.y - float(r["y"])) < 3.0 and p.x >= float(r["x0"]) - 8.0 and p.x <= float(r["x1"]) + 8.0:
			return r
	return {}


func _bot_link(a: Dictionary, b: Dictionary) -> String:
	## How he gets from run a to run b in one go: "jump" (a gap, or up onto
	## what's over him), "drop" (off a's end down onto b), or "" (not at once).
	var gap := maxf(float(b["x0"]) - float(a["x1"]), float(a["x0"]) - float(b["x1"]))
	var up := float(a["y"]) - float(b["y"])   # > 0: b is higher
	if up > 100.0 or gap > 80.0:
		return ""
	if gap > 0.0:
		return "jump"
	if up > 0.0:
		return "jump"
	return "drop" if up < 0.0 else ""


func _bot_next(cur: Dictionary, goal: Dictionary) -> Dictionary:
	## The next run on the cheapest way (walking along the islets before
	## climbing onto perches: a jump up costs more than one across).
	var runs := _bot_runs()
	var gi := runs.find(goal)
	var ci := runs.find(cur)
	if gi < 0 or ci < 0:
		return {}
	var cost := {ci: 0.0}
	var prev := {ci: -1}
	var open := [ci]
	while not open.is_empty():
		var bi := 0
		for k in open.size():
			if float(cost[open[k]]) < float(cost[open[bi]]):
				bi = k
		var i: int = open[bi]
		open.remove_at(bi)
		if i == gi:
			break
		for j in runs.size():
			var how := _bot_link(runs[i], runs[j])
			if how == "" or j == i:
				continue
			var a: Dictionary = runs[i]
			var b: Dictionary = runs[j]
			var c := float(cost[i]) + absf((float(a["x0"]) + float(a["x1"])) * 0.5 - (float(b["x0"]) + float(b["x1"])) * 0.5) \
					+ (120.0 if float(b["y"]) < float(a["y"]) - 1.0 else (40.0 if how == "jump" else 20.0))
			if not cost.has(j) or c < float(cost[j]):
				cost[j] = c
				prev[j] = i
				if not open.has(j):
					open.append(j)
	if not prev.has(gi):
		return {}
	var k2 := gi
	while int(prev[k2]) != ci and int(prev[k2]) >= 0:
		k2 = int(prev[k2])
	return runs[k2]


func _bot_nav(pl: Node2D, to: Vector2) -> Dictionary:
	## To x on the run at y: along it, or run by run (jumping gaps and up
	## onto perches and stones, dropping off their ends), steering in the air
	## onto the run he jumped for.
	var pad := {}
	var cur := _bot_run_at(pl.position) if pl.on_floor else {}
	if cur.is_empty():
		var land: Dictionary = _bot.get("land", {})
		var ax := to.x
		if not land.is_empty() and float(land["y"]) >= pl.position.y - 110.0:
			ax = clampf(to.x if _bot_run_at(to) == land else (float(land["x0"]) + float(land["x1"])) * 0.5, float(land["x0"]) + 14.0, float(land["x1"]) - 14.0)
		if absf(ax - pl.position.x) > 4.0:
			pad["left" if ax < pl.position.x else "right"] = true
		return pad
	_bot["land"] = {}
	var goal := _bot_run_at(to)
	if goal.is_empty() or goal == cur:
		if absf(to.x - pl.position.x) > 5.0:
			pad["left" if to.x < pl.position.x else "right"] = true
		return pad
	var next := _bot_next(cur, goal)
	if next.is_empty():
		next = goal
	var how := _bot_link(cur, next)
	var lo := maxf(float(cur["x0"]), float(next["x0"]))
	var hi := minf(float(cur["x1"]), float(next["x1"]))
	if how == "jump" and lo < hi:
		# Up onto what's over him: under it, then straight up.
		var ux := clampf(pl.position.x, lo + 14.0, hi - 14.0)
		if absf(ux - pl.position.x) > 6.0:
			pad["left" if ux < pl.position.x else "right"] = true
		else:
			_bot_start_jump()
			_bot["land"] = next
		return pad
	var dir := 1.0 if float(next["x0"]) >= float(cur["x1"]) - 1.0 or (lo >= hi and float(next["x0"]) > float(cur["x0"])) else -1.0
	if how == "drop":
		# Off the end of this run that's over the next one (the nearer, or
		# the one toward where he's going).
		var e0 := float(cur["x0"]) - 12.0
		var e1 := float(cur["x1"]) + 12.0
		var ok0 := e0 >= float(next["x0"]) and e0 <= float(next["x1"])
		var ok1 := e1 >= float(next["x0"]) and e1 <= float(next["x1"])
		if ok0 and ok1:
			dir = -1.0 if to.x < pl.position.x else 1.0
		elif ok0:
			dir = -1.0
		elif ok1:
			dir = 1.0
		else:
			dir = 1.0 if (float(next["x0"]) + float(next["x1"])) * 0.5 > pl.position.x else -1.0
	pad["left" if dir < 0.0 else "right"] = true
	var edge := float(cur["x1"]) if dir > 0.0 else float(cur["x0"])
	if how == "jump" and absf(edge - pl.position.x) < 16.0:
		_bot_start_jump()
		_bot["land"] = next
	elif how == "drop":
		_bot["land"] = next
	return pad


func _bot_dodge(pl: Node2D, d: Dictionary) -> Dictionary:
	## Off a locked Gaze: sideways along his footing where his body clears
	## the line, else up over it as it fires.
	var pad := {}
	var a: Vector2 = d["a"]
	var b: Vector2 = d["b"]
	var cur := _bot_run_at(pl.position)
	var best := INF
	if not cur.is_empty() and pl.on_floor:
		var reach := 205.0 * maxf(float(d["t"]) - 0.04, 0.0) + 2.0
		var x := float(cur["x0"]) + 12.0
		while x <= float(cur["x1"]) - 12.0:
			if absf(x - pl.position.x) <= reach and absf(x - pl.position.x) < absf(best - pl.position.x):
				var body := Rect2(x - 10.0, float(cur["y"]) - 38.0, 20.0, 38.0)
				if not _seg_hits(a, a + (b - a).normalized() * 1200.0, float(TUNE["gaze_w"]) + 8.0, body):
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
	if int(_bot["jump"]) > 0:
		_bot["jump"] = int(_bot["jump"]) - 1
		pad["jump"] = true
		if int(_bot["jump"]) == 0:
			_bot["rest"] = 3
	elif int(_bot["rest"]) > 0:
		_bot["rest"] = int(_bot["rest"]) - 1


# ---------------------------------------------------------------- the look

func lights() -> Array:
	## At most 22 in the fight, at most 6 Hush lights (spec §5.5.7).
	var out: Array = []
	if not alive:
		return out
	if state == "finale" and finale != null:
		return finale.lights()
	if phase == 1 and state in ["fight", "wake", "roar"]:
		out.append({"p": eye["p"], "r": 30.0 if str(eye["state"]) != "surface" else 60.0, "s": 0.45, "tint": Color(0.7, 0.6, 1.0, 0.3)})
	for h in hands:
		match str(h["state"]):
			"tell":
				out.append({"p": Vector2(float(h["x"]), water_y - 4.0), "r": 24.0, "s": 0.55})
			"up":
				out.append({"p": Vector2(float(h["x"]), water_y - 32.0), "r": 70.0, "s": -0.5})
	if phase == 2 and shadow_k > 0.3:
		out.append({"p": maw_p(), "r": 140.0, "s": -0.55})
		if not snuff.is_empty() and str(snuff["state"]) == "slam":
			out.append({"p": (snuff["rect"] as Rect2).get_center(), "r": 120.0, "s": -0.5})
	if phase >= 3 and not eye3.is_empty():
		out.append({"p": pupil(), "r": 100.0, "s": -0.45})
		out.append({"p": eye3["p"], "r": 48.0, "s": 0.35, "tint": Color(0.7, 0.6, 1.0, 0.3)})
	if (phase == 2 and shadow_k > 0.3) or phase >= 3:
		for i in flames.size():
			if not flames[i]["freed"]:
				out.append({"p": flame_p(i), "r": 26.0, "s": 0.55})
	var n := 0
	for bo in bolts:
		if n >= 3:
			break
		out.append({"p": bo["p"], "r": 22.0, "s": 0.3})
		n += 1
	return out


func eye_points() -> Array:
	return []


func _dying(_dt: float) -> void:
	## (after finish(): nothing falls; the Hush is simply gone.) After the
	## gift his flame stays given through the bell and the level's end (a
	## level-up there would put the cosmetic flame back).
	fade = clampf(1.0 - death_time, 0.0, 1.0)
	if finale != null and world != null and bool(finale.get("gave")):
		finale.flame_given()
		world.light_override(0.0)
	if death_time > 4.0:
		gone = true


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if BossMods.of(self) != null and state != "finale":
		BossMods.of(self).draw_glow(glow)
	var tb := _tb
	if state == "finale" and finale != null:
		finale.draw_glow(glow, tb)
		tb.flush(glow)
		return
	# The sunken bells' rims (always, so they're found in the dark), gold while lit.
	for b in bells:
		var r: Rect2 = b["rect"]
		var sink := float(b["sink"])
		if sink >= 1.0:
			continue
		var a := (1.0 - sink)
		var lit := float(b["lit"]) > 0.0
		var col := GOLD if lit else (Color(0.55, 0.55, 0.62) if float(b["smother"]) > 0.0 else Color(0.85, 0.8, 0.6))
		var rr := Rect2(r.position + Vector2(0, sink * 30.0), r.size)
		tb.ring(rr.get_center() + Vector2(0, -6), 14.0, 1.6, Color(col, (0.75 if lit else 0.35) * a), 18, PI, TAU)
		tb.line(rr.position + Vector2(2, rr.size.y - 10), rr.position + Vector2(rr.size.x - 2, rr.size.y - 10), 1.6, Color(col, (0.75 if lit else 0.35) * a))
		tb.line(rr.position + Vector2(3, 8), rr.position + Vector2(2, rr.size.y - 10), 1.4, Color(col, 0.3 * a))
		tb.line(rr.position + Vector2(rr.size.x - 3, 8), rr.position + Vector2(rr.size.x - 2, rr.size.y - 10), 1.4, Color(col, 0.3 * a))
		if float(b["flash"]) > 0.0:
			tb.circle(rr.get_center(), 18.0, Color(1, 0.95, 0.8, float(b["flash"])), 14)
		if float(b["smother"]) > 0.0 and not lit and not b["sunk"]:
			# Black ooze over it: a dark drip line.
			tb.rect(Rect2(rr.position.x + 4, rr.position.y + 4, rr.size.x - 8, 6), Color(0.02, 0.02, 0.04, 0.8))
	# The peals.
	for pe in peals:
		var k := float(pe["r"]) / float(TUNE["peal_r"])
		tb.ring(pe["p"], float(pe["r"]), 3.0, Color(GOLD, 0.8 * (1.0 - k)), 48)
		tb.ring(pe["p"], float(pe["r"]) * 0.92, 1.4, Color(1, 0.95, 0.8, 0.5 * (1.0 - k)), 40)
	# The Hands: pale fingertips always, the tell's ring and glint, a gold rim Heard.
	for h in hands:
		_glow_hand(tb, h)
	match phase:
		1:
			_glow_eye1(tb)
			_glow_swallow(tb)
		2:
			_glow_mouth(tb, glow)
		_:
			_glow_eye3(tb)
			_glow_flood(tb)
	if phase >= 2 or (phase == 3 and not eye3.is_empty()):
		_glow_flames(glow)
	if act == "bolts" and phase == 2:
		_glow_bolt_tell(tb)
	for bo in bolts:
		var p: Vector2 = bo["p"]
		tb.circle(p, 9.0, Color(RIM, 0.25), 12)
		tb.circle(p, 6.5, Color(0.03, 0.02, 0.06, 0.95), 12)
		tb.ring(p, 6.5, 1.6, Color(RIM, 0.95), 12)
	tb.flush(glow)


func _glow_bolt_tell(tb: RefCounted) -> void:
	## The Silence Bolts' 0.6 s: the crown's rim flashes pale and the three
	## orbs gather, dark with pale rims growing, where they'll fly from.
	var k := 1.0 - clampf(act_t / maxf(act_len, 0.01), 0.0, 1.0)
	var c := crown()
	tb.ring(c, 66.0 - 10.0 * k, 1.6 + 1.2 * k, Color(PALE, 0.25 + 0.6 * k), 32)
	for j in 3:
		var p := bolt_from(j)
		var r := 2.0 + 4.5 * k
		tb.circle(p, r + 3.0, Color(RIM, 0.2 * k), 12)
		tb.circle(p, r, Color(0.03, 0.02, 0.06, 0.95), 12)
		tb.ring(p, r, 1.4, Color(RIM, 0.5 + 0.45 * k), 12)
		# the pale threads drawn into each (the "stitch" of silence)
		for q in 3:
			var a := TAU * q / 3.0 + t * 3.0 + j
			var d := Vector2(cos(a), sin(a))
			tb.line(p + d * (r + 14.0 * (1.0 - k)), p + d * (r + 4.0 + 14.0 * (1.0 - k)), 1.2, Color(PALE, 0.6 * k))


func _glow_hand(tb: RefCounted, h: Dictionary) -> void:
	var x := float(h["x"])
	var st := str(h["state"])
	if st == "tell":
		# The water goes still round his feet (or the stone goes black under
		# them); the fingertips ring the surface.
		var k := 1.0 - clampf(float(h["t"]) / maxf(float(h["len"]), 0.01), 0.0, 1.0)
		var by := float(h.get("base", water_y))
		tb.rect(Rect2(x - 30.0, by - 1.0, 60.0, 2.0), Color(0.85, 0.85, 1.0, 0.3 + 0.3 * k))
		for j in 5:
			var a := PI + PI * (j + 0.5) / 5.0
			var fp := Vector2(x + cos(a) * 16.0, by + sin(a) * 6.0 * k - 2.0 * k)
			tb.circle(fp, 2.4 + k, Color(PALE, 0.7 + 0.3 * k), 8)
		tb.circle(Vector2(x, by - 6.0 * k), 3.0 + 3.0 * k, Color(0.8, 0.9, 1.0, 0.5 + 0.5 * k), 10)
		# The column it will close in, faint (what you see is what hurts).
		var r := Rect2(x - float(TUNE["grasp_w"]) * 0.5, by - float(TUNE["grasp_h"]), float(TUNE["grasp_w"]), float(TUNE["grasp_h"]))
		tb.rect(Rect2(r.position, Vector2(r.size.x, 1.5)), Color(PALE, 0.25 * k))
		tb.rect(Rect2(r.position, Vector2(1.5, r.size.y)), Color(PALE, 0.2 * k))
		tb.rect(Rect2(r.position + Vector2(r.size.x - 1.5, 0), Vector2(1.5, r.size.y)), Color(PALE, 0.2 * k))
	elif st in ["up", "sink"]:
		var r2 := hand_rect(h)
		if float(h["heard"]) > 0.0:
			tb.rect(Rect2(r2.position - Vector2(2, 2), Vector2(r2.size.x + 4, 2)), Color(GOLD, 0.9))
			tb.rect(Rect2(r2.position - Vector2(2, 2), Vector2(2, r2.size.y + 2)), Color(GOLD, 0.9))
			tb.rect(Rect2(r2.position + Vector2(r2.size.x, -2), Vector2(2, r2.size.y + 2)), Color(GOLD, 0.9))
		for j in 4:
			tb.circle(Vector2(r2.position.x + 6.0 + j * 9.5, r2.position.y + 4.0), 2.6, Color(PALE, 0.95), 8)
	else:
		# Resting under the lake: only the tips, faint, as it lurks.
		for j in 3:
			tb.circle(Vector2(x - 8.0 + j * 8.0, water_y + 6.0 + sin(t * 2.0 + j) * 1.5), 1.6, Color(PALE, 0.35), 6)


func _glow_eye1(tb: RefCounted) -> void:
	var p: Vector2 = eye["p"]
	var st := str(eye["state"])
	if st == "gone":
		return
	if st in ["lurk", "swim", "dive"]:
		# A pale shape under the water, its iris a violet glint.
		tb.ellipse(p, 18.0, 7.0, Color(PALE, 0.18), 14)
		tb.circle(p, 3.2, Color(VIOLET, 0.9), 10)
	else:
		var heard := float(eye.get("heard", 0.0)) > 0.0 or st == "surface"
		if heard:
			tb.ring(p, 24.0, 2.0, Color(GOLD, 0.85), 20)
		tb.circle(p + _look(p) * 3.0, 3.4, Color(1, 1, 1, 0.95), 10)
		if st == "surface":
			var f := clampf(float(eye["t"]) / maxf(window_len(1), 0.01), 0.0, 1.0)
			tb.ring(p, 30.0, 1.6, Color(1.0, 0.92, 0.7, 0.7), 24, -PI * 0.5, -PI * 0.5 + TAU * f)


func _look(p: Vector2) -> Vector2:
	if world == null or world.get("player") == null:
		return Vector2.ZERO
	return ((world.player.center() as Vector2) - p).normalized()


func _glow_swallow(tb: RefCounted) -> void:
	if swallow.is_empty():
		return
	var x := float(swallow["x"])
	var dir := float(swallow["dir"])
	var top := arena_top
	var bot := water_y + 40.0
	if str(swallow["state"]) == "gather":
		var k := 1.0 - clampf(float(swallow["t"]) / maxf(float(swallow["len"]), 0.01), 0.0, 1.0)
		var w := 20.0 + 40.0 * k
		for i in 10:
			var y := top + (bot - top) * (i + 0.5) / 10.0
			var jag := sin(t * 9.0 + i * 1.7) * 6.0
			tb.line(Vector2(x, y), Vector2(x + dir * (w + jag), y), 2.0, Color(PALE, 0.25 + 0.5 * k))
		return
	# The ragged pale edge of the wall (the black itself is on the parts layer).
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var y := top + (bot - top) * float(i) / n
		pts.append(Vector2(x + sin(t * 7.0 + i * 1.9) * 7.0 + (5.0 if i % 2 == 0 else -3.0) * dir, y))
	tb.polyline(pts, 2.4, Color(PALE, 0.85))


func _glow_mouth(tb: RefCounted, glow: Node2D) -> void:
	if shadow_k <= 0.05:
		return
	var m := maw_p()
	var st := str(maw["state"])
	# The Maw: its throat's cold dead star, always.
	var k := 1.0
	if st == "inhale_tell":
		k = 1.0 - clampf(float(maw["t"]) / maxf(tell(float(TUNE["inhale_tell"]), float(TUNE["inhale_floor"])), 0.01), 0.0, 1.0)
	var core := m + Vector2(0, 8.0)
	tb.circle(core, 6.0 + 2.0 * sin(t * 5.0), Color(0.75, 0.8, 1.0, 0.25 * shadow_k), 12)
	tb.circle(core, 2.6, Color(0.85, 0.9, 1.0, 0.9 * shadow_k), 8)
	if st in ["inhale_tell", "inhale"]:
		# Particles streaming into it.
		for i in 14:
			var a := TAU * i / 14.0 + t * 0.7
			var d := 40.0 + fmod(t * 180.0 + i * 37.0, 150.0) * (1.0 if st == "inhale" else k)
			var q := m + Vector2(cos(a), sin(a)) * d
			tb.line(q, q + (m - q).normalized() * 9.0, 1.4, Color(PALE, 0.55 * (1.0 - d / 200.0)))
	if st == "choked":
		var f := clampf(float(maw["t"]) / maxf(window_len(2), 0.01), 0.0, 1.0)
		tb.ring(core, 26.0, 2.2, Color(GOLD, 0.9), 26)
		tb.ring(core, 32.0, 1.6, Color(1.0, 0.92, 0.7, 0.75), 26, -PI * 0.5, -PI * 0.5 + TAU * f)
	# The Snuff's palm: its outline growing over the islet (the tell), the
	# slam's box after.
	if not snuff.is_empty():
		var r: Rect2 = snuff["rect"]
		if str(snuff["state"]) == "tell":
			var sk := 1.0 - clampf(float(snuff["t"]) / maxf(float(snuff["len"]), 0.01), 0.0, 1.0)
			_palm_outline(tb, r, 0.55 + 0.45 * sk, Color(PALE, 0.35 + 0.6 * sk))
			tb.rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), Color(PALE, 0.3 + 0.5 * sk))
		elif bool(snuff.get("heard", false)):
			_palm_outline(tb, r, 1.0, Color(GOLD, 0.9))


func _palm_outline(tb: RefCounted, r: Rect2, grow: float, col: Color) -> void:
	## The open hand's silhouette (points_hush.json _splay_outline), turned
	## wrist up so its fingers come down onto the islet: the fingertips on the
	## slam's floor line, the palm over its box, at the splay's own scale
	## (x1.65 of the 256-unit frame, spec: over a 6-tile islet).
	var pts: Array = points().get("_splay_outline", [])
	if pts.is_empty():
		tb.polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), 2.0, col, true)
		return
	var sc := 0.5 * 1.65 * grow
	var c := Vector2(r.get_center().x, r.end.y)
	var out := PackedVector2Array()
	for q in pts:
		out.append(c + Vector2((float(q[0]) - 122.0) * sc, -(244.0 - float(q[1])) * sc + (1.0 - grow) * -30.0))
	# (the outline's y runs from the fingertips (26) to the wrist (244): flip it)
	var flipped := PackedVector2Array()
	var y_tip := INF
	for p in out:
		y_tip = minf(y_tip, p.y)
	for p in out:
		flipped.append(Vector2(p.x, c.y - (p.y - y_tip)))
	tb.polyline(flipped, 2.2, col, true)


func _glow_eye3(tb: RefCounted) -> void:
	if eye3.is_empty():
		return
	var st := str(eye3["state"])
	var p: Vector2 = eye3["p"]
	var r := eye3_rect()
	var pl = world.player if world != null else null
	var solid: bool = pl != null and eye3_solid(pl)
	# The iris and pupil glint always; the almond's edge where it's solid.
	if st != "blink":
		tb.circle(pupil(), 5.0, Color(1, 1, 1, 0.9), 12)
		tb.ring(p, 28.0, 1.4, Color(VIOLET, 0.5), 24)
	if solid:
		# Where it's solid (in his light): its lids' edge catches the light.
		var lid := PackedVector2Array()
		for i in 25:
			var a := PI + PI * i / 24.0
			lid.append(p + Vector2(cos(a) * 112.0, sin(a) * 38.0))
		tb.polyline(lid, 1.6, Color(RIM, 0.55))
		var low := PackedVector2Array()
		for i in 25:
			var a2 := PI * i / 24.0
			low.append(p + Vector2(cos(a2) * 112.0, sin(a2) * 36.0))
		tb.polyline(low, 1.2, Color(RIM, 0.35))
	match st:
		"gaze_tell":
			# A pale cone narrowing onto him.
			var k := 1.0 - clampf(float(eye3["t"]) / maxf(float(eye3["len"]), 0.01), 0.0, 1.0)
			if pl != null:
				var a := pupil()
				var b: Vector2 = pl.center()
				var d := (b - a).normalized()
				var n := d.orthogonal()
				var w := lerpf(70.0, 10.0, k)
				tb.tri(a, b + n * w, b - n * w, Color(PALE, 0.08 + 0.12 * k))
				tb.line(a, b + n * w, 1.2, Color(PALE, 0.35 + 0.4 * k))
				tb.line(a, b - n * w, 1.2, Color(PALE, 0.35 + 0.4 * k))
		"gaze_lock":
			var k2 := 1.0 - clampf(float(eye3["t"]) / maxf(float(eye3["len"]), 0.01), 0.0, 1.0)
			var a2: Vector2 = eye3["a"]
			var b2: Vector2 = eye3["b"]
			var end := a2 + (b2 - a2).normalized() * 900.0
			tb.line(a2, end, 5.0 + 2.0 * k2, Color(PALE, 0.15 + 0.1 * k2))
			tb.line(a2, end, 2.0 + k2, Color(1, 1, 1, 0.8 + 0.2 * sin(t * 40.0)))
		"gaze_fire":
			if eye3.has("end"):
				var a3: Vector2 = eye3["a"]
				var e3: Vector2 = eye3["end"]
				var cut := e3
				if not _gaze_hz.is_empty() and bool(_gaze_hz.get("reflected", false)):
					var sg: Array = _gaze_hz.get("seg", [])
					if sg.size() == 2:
						cut = sg[1]
				tb.line(a3, cut, float(TUNE["gaze_w"]) + 6.0, Color(0.05, 0.04, 0.1, 0.8))
				tb.line(a3, cut, float(TUNE["gaze_w"]), Color(PALE, 0.55))
				tb.line(a3, cut, 3.0, Color(1, 1, 1, 0.95))
		"blink":
			var f := clampf(float(eye3["t"]) / maxf(window_len(3), 0.01), 0.0, 1.0)
			tb.rect(Rect2(r.position.x, p.y - 1.0, r.size.x, 2.0), Color(RIM, 0.9))
			tb.ring(p, 48.0, 2.0, Color(1.0, 0.92, 0.7, 0.8), 30, -PI * 0.5, -PI * 0.5 + TAU * f)


func _glow_flood(tb: RefCounted) -> void:
	if flood.is_empty():
		return
	var y := float(flood["y"])
	match str(flood["state"]):
		"tell":
			var k := 1.0 - clampf(float(flood["t"]) / maxf(float(flood["len"]), 0.01), 0.0, 1.0)
			# The pale line where the water will stand, and the lake gone flat.
			var x := arena_left
			while x < arena_right:
				tb.rect(Rect2(x, y - 1.0, 14.0, 2.0), Color(PALE, 0.4 + 0.5 * k))
				x += 22.0
			for g in gaps:
				tb.rect(Rect2(float(g["x0"]), water_y - 1.0, float(g["x1"]) - float(g["x0"]), 2.0), Color(PALE, 0.5))
		"up", "down":
			var k2 := 1.0 if str(flood["state"]) == "up" else clampf(float(flood["t"]) / 0.6, 0.0, 1.0)
			var yy := lerpf(water_y, y, k2)
			tb.rect(Rect2(arena_left, yy, arena_right - arena_left, 2.0), Color(PALE, 0.8))


func _glow_flames(glow: Node2D) -> void:
	## The six stolen flames: cold violet-white, gold-ringed when they can be
	## struck free.
	if phase == 2 and shadow_k < 0.3:
		return
	var strik := flames_strikable()
	var dimk := flame_dim()
	var pal := FLAME_PAL
	if dimk < 1.0:
		pal = FLAME_PAL.duplicate()
		pal["alpha"] = dimk
	for i in flames.size():
		if flames[i]["freed"]:
			continue
		var p := flame_p(i)
		if glow.has_method("flame"):
			glow.flame(p + Vector2(0, 6), 11.0 * lerpf(0.7, 1.0, dimk), float(i) * 1.7, false, false, pal)
		if strik:
			_tb.ring(p + Vector2(0, -2), 12.0, 1.4, Color(GOLD, 0.8), 14)


func _draw_parts(ci: CanvasItem) -> void:
	## The black parts of the Hush, drawn in the World under the dark and
	## under him (so none of it ever hides him; in his light they show as
	## what they are, and over the dark their rims, tips and glints do).
	if state == "finale" and finale != null:
		finale.draw_parts(ci)
		return
	if not alive:
		return
	# The Deep Quiet's black water a row over the islets.
	if not flood.is_empty() and str(flood["state"]) in ["up", "down"]:
		var k2 := 1.0 if str(flood["state"]) == "up" else clampf(float(flood["t"]) / 0.6, 0.0, 1.0)
		var wy := lerpf(water_y, float(flood["y"]), k2)
		ci.draw_rect(Rect2(arena_left - 64.0, wy, arena_right - arena_left + 128.0, water_y + 40.0 - wy), Color(0.02, 0.02, 0.05, 0.88))
	# The Swallow's wall of black.
	if not swallow.is_empty() and str(swallow["state"]) == "roll":
		var x := float(swallow["x"])
		var dir := float(swallow["dir"])
		var x0 := arena_left - 40.0 if dir > 0.0 else x
		var x1 := x if dir > 0.0 else arena_right + 40.0
		ci.draw_rect(Rect2(x0, arena_top, x1 - x0, water_y + 60.0 - arena_top), Color(0.01, 0.01, 0.02, 0.82))
	# The Hands.
	for h in hands:
		var st := str(h["state"])
		if st == "tell" and float(h.get("base", water_y)) < water_y - 1.0:
			# Through the stone: it goes black under his feet first.
			var kk := 1.0 - clampf(float(h["t"]) / maxf(float(h["len"]), 0.01), 0.0, 1.0)
			ci.draw_rect(Rect2(float(h["x"]) - 24.0, float(h["base"]) - 1.0, 48.0, 3.0 + 3.0 * kk), Color(INK, 0.5 + 0.45 * kk))
		if st in ["up", "sink"]:
			var tex: Texture2D = _art.get("hush_hand_grasp" if st == "up" and float(h["t"]) < float(TUNE["grasp_up"]) - 0.12 else ("hush_hand_sink" if st == "sink" else "hush_hand_rise"))
			var r := hand_rect(h)
			if tex != null:
				# Its grasp_column (88..168 x 116..244 units) is the 40 x 64 box.
				ci.draw_texture_rect_region(tex, Rect2(r.position.x, r.position.y, r.size.x, r.size.y), Rect2(176, 232 + (1.0 - r.size.y / 64.0) * 0.0, 160, 256.0 * r.size.y / 64.0))
			else:
				ci.draw_rect(r, INK)
	match phase:
		1:
			var st1 := str(eye["state"])
			if st1 in ["rise", "surface"]:
				var tex1: Texture2D = _art.get("hush_eye_small")
				var p: Vector2 = eye["p"]
				if tex1 != null:
					ci.draw_texture_rect(tex1, Rect2(p - Vector2(24, 12), Vector2(48, 24)), false)
				else:
					ci.draw_rect(Rect2(p - Vector2(20, 9), Vector2(40, 18)), INK)
		2:
			if not snuff.is_empty() and str(snuff["state"]) == "slam":
				var r2: Rect2 = snuff["rect"]
				var tex2: Texture2D = _art.get("hush_hand_splay")
				if tex2 != null:
					var sz := Vector2(128, 128) * 1.65
					var c := Vector2(r2.get_center().x, r2.end.y - sz.y * 0.55)
					ci.draw_set_transform(c + _base, PI, Vector2.ONE)
					ci.draw_texture_rect(tex2, Rect2(-sz * 0.5, sz), false)
					ci.draw_set_transform(_base, 0.0, Vector2.ONE)
				else:
					ci.draw_rect(r2, INK)
			if shadow_k > 0.3:
				var tex3: Texture2D = _art.get("hush_core")
				var cc := maw_p() + Vector2(0, 8.0)
				if tex3 != null and str(maw["state"]) == "choked":
					ci.draw_texture_rect(tex3, Rect2(cc - Vector2(22, 22), Vector2(44, 44)), false)
		_:
			if not eye3.is_empty():
				var st3 := str(eye3["state"])
				var name := "hush_eye_open"
				if st3 == "blink":
					name = "hush_eye_shut"
				elif st3 == "open" and state == "roar":
					name = "hush_eye_half"
				elif _hurt_flash():
					name = "hush_eye_wince"
				var tex4: Texture2D = _art.get(name)
				var p3: Vector2 = eye3["p"]
				var grow := 1.0
				if state == "roar":
					grow = lerpf(0.6, 1.0, 1.0 - clampf(timer / maxf(_roar_len, 0.1), 0.0, 1.0))
				if tex4 != null:
					var sz4 := Vector2(256, 128) * grow
					ci.draw_texture_rect(tex4, Rect2(p3 - sz4 * 0.5, sz4), false)
					if name in ["hush_eye_open", "hush_eye_half"]:
						var tp: Texture2D = _art.get("hush_pupil")
						if tp != null:
							var pp := pupil()
							ci.draw_texture_rect(tp, Rect2(pp - Vector2(16, 16), Vector2(32, 32)), false)
				else:
					ci.draw_rect(eye3_rect(), INK)


func _hurt_flash() -> bool:
	return flash > 0.5


func _draw() -> void:
	## Under the dark: the sunken bells on their islets (lit by their own
	## light when rung; P3 sinks them), then the black parts (world space).
	_base = -position
	draw_set_transform(_base, 0.0, Vector2.ONE)
	_draw_parts(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in bells:
		var sink := float(b["sink"])
		if sink >= 1.0:
			continue
		var tex: Texture2D = _art.get("sunken_bell_smothered" if float(b["smother"]) > 0.0 and float(b["lit"]) <= 0.0 else "sunken_bell")
		var fp: Vector2 = (b["p"] as Vector2) - position + Vector2(0, sink * 34.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(fp - Vector2(16, 44), Vector2(32, 48)), false, Color(1, 1, 1, 1.0 - sink))
		else:
			draw_rect(Rect2(fp - Vector2(12, 40), Vector2(24, 40)), Color(0.5, 0.45, 0.3, 1.0 - sink))
