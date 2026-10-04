extends SceneTree
## test_w5 (WL5): World 5, the Shattered Sanctum: features/glass.gd and the
## levels 5-1 to 5-4 (spec §3.2, §3.6; decisions.md "Feel and terrain").
##
##   the feature numbers, read from glass.gd's DIFF_KNOBS (never copied):
##     glass: a landing strains glass_land, a second landing adds another
##     (and breaks it where 2 x land >= 1), one landing lasts (1 - land) /
##     stand s of standing (1.09 s on Dusk), hero attacks never strain it, an
##     enemy shot does, a break flashes then is air, it reforms glass_reform
##     later (never into a body), a snuff puts every pane back, the arena rule
##     (no standing strain; walking pane to pane never strains it, only a real
##     landing; ARENA_REFORM, at once on a retry), the other difficulties;
##     gusts: the tell lasts gust_tell, the push is gust_push in the air and
##     half on the ground, phase B blows CYCLE / 2 later, a gust begun in the
##     air waits for the landing, the stone brake (a gust never pushes him
##     off stone onto glass), his light dims, a lamp in the wind loses
##     gust_lamp s a gust, shots drift, the ambient's wind is set;
##     dawnglass: a ledge within a lamp's reach while it burns (Wick's own
##     light never counts), its clock fades over the lamp's last DAWN_FADE s
##     (a lamp in wind: counting the gusts it will lose, lit at any phase),
##     then it flickers DAWN_FLICKER and is air; its lamp is an anchor with
##     its nominal radius; the first-time barks wait for a stone landing;
##   the levels: 5-4's width and altars, checkpoint gaps (<= 72), 3-5 altars
##   in 5-1 to 5-3, headers, the cast (each regular level's roster: header,
##   since Build 2; the 5-3 share-cap ruling), the threat within 10% of what
##   each one's threat: header declares, ramping (tests/level_rules.gd),
##   the signs and inscriptions, an 11-wide stone island, the per-screen
##   caps, the Glassmite and Gustling placement checks, the arena; Build
##   2's personalities (5-1's lesson and lone first Gustling, 5-2's packs
##   and its named Anointed on stone, 5-3's omens, roads, upper-deck wind and
##   its hold room: _test_build2); no air
##   under glass cut off from the level; every stone stretch in a gust zone
##   waits out a whole gust from its downwind end; a running jump held
##   through a full tailwind lands with room to stop; no monster an elite
##   could be is judged on glass;
##   the bot (unless WAXBY_FAST): every goal in calm and under a constant
##   120 px/s push, stone every 14 tiles along its winning way over the void,
##   no wait on any pane (60% of its life, per pane) or on a lamp's dawnglass
##   (60% of its lamp's life: in wind, its in-wind life), the headwind and
##   tailwind rules along the bot's way, every lamp reached before its
##   dawnglass is needed (lamps lit in turn);
##   the routes: 5-1..5-3 (routes/*.json) and 5-4's approach, replayed with
##   no fall and no snuff (5-4's to the arena door: a boss level's bell needs
##   the boss, so test_routes can't hold it yet).
##
##     godot --headless --path game --script res://tests/test_w5.gd

const LevelData := preload("res://scripts/level_data.gd")
const Rules := preload("res://tests/level_rules.gd")
const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const Route := preload("res://scripts/route.gd")
const GLASS := "res://scripts/features/glass.gd"
const TILE := 32
const DT := 1.0 / 120.0
const IDS := ["5-1", "5-2", "5-3", "5-4"]
# spec §3.3 / §3.6.3 (5-4's width, altars' cells and monsters; since Build 2
# the regular levels' widths, altars, bell and cast are their own, held to
# the rules and their roster: and threat: headers: tests/level_rules.gd)
const SPEC := {
	"5-1": {"name": "The Floating Aisle", "area": 23, "theme": "choirglass", "dread": "Queen Crackle|glassmite|Twinned,Glassed"},
	"5-2": {"name": "The Gale Gallery", "area": 24, "theme": "rosewind", "dread": "Glintwatch|refractor|Warded,Echoing"},
	"5-3": {"name": "The Dawnglass Bridges", "area": 26, "theme": "voidnave"},
	"5-4": {"name": "The Lightwell", "area": 27, "theme": "prismheart", "width": 160, "altars": [63, 118], "monsters": 8},   # (altar 2 at the door: 118, test_content's rule; spec x 111)
}
const MAX_GAP := 72              # tiles between checkpoints in World 5 (spec §3.1)
const STONE_EVERY := 14
const COST := {"skeleton": 1.0, "bat": 1.0, "bonebow": 1.5, "dripkin": 1.0, "gutterwing": 1.0, "brinejaw": 1.0,
		"thornback": 2.5, "hollow_helm": 3.0, "lidlurk": 3.0, "rootling": 1.0, "weepcap": 2.0, "rattlehound": 3.0,
		"creepbone": 1.5, "tickwind": 1.5, "spurwheel": 2.5, "frostbuckle": 4.0, "hoarowl": 2.0, "glassmite": 1.0,
		"gustling": 1.5, "refractor": 2.0, "paneguard": 4.0, "hushling": 0.75, "stillmaw": 3.0, "unwick": 3.5, "lurecoil": 6.0}
const DWELL_SHARE := 0.6         # the dwell rule: at most 60% of a timed surface's Dusk life
const DAWN_LIFE := 25.0          # a lamp's burn (level_features.gd LANTERN_LIFE)
const LAMP_R := 140.0            # a lamp's nominal light
const ALTAR_R := 150.0
const SLASH := Vector2(38, 4)    # a slash's reach past his body (player.gd's reach 38 x 34)

var WorldScript: GDScript
var game: Node
var _passed := 0
var _failed := 0
var _knobs := {}
var _levels := {}


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_w5_save.json"
	for suffix in [".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	_knobs = (load(GLASS) as Script).get_script_constant_map()["DIFF_KNOBS"]
	await _test_glass()
	await _test_glass_arena()
	await _test_gusts()
	await _test_stone_brake()
	await _test_dawnglass()
	await _test_wind_clock()
	await _test_barks()
	await _test_knock_and_void()
	_test_look_hooks()
	var have := true
	for id in IDS:
		var path := "res://levels/%s.txt" % id
		if FileAccess.file_exists(path):
			_levels[id] = LevelData.load_file(path)
		else:
			have = false
			print("  skipped: %s missing" % path)
	if have:
		_test_headers()
		_test_cast()
		_test_signs()
		_test_layout()
		_test_arena()
		_test_teaching()
		_test_build2()
		for id in IDS:
			_test_pockets(id)
			await _test_posts(id)
			await _test_tail_jumps(id)
			await _test_elite_ground(id)
		if OS.get_environment("WAXBY_FAST") == "":
			for id in IDS:
				_test_bot(id)
		else:
			print("  (the W5 bot passes skipped: WAXBY_FAST)")
		await _test_approach_route()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	print("test_w5: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _knob(name: String, d := "dusk") -> float:
	return float(_knobs[name][d])


func _mk(lines: Array, header := "", w := 48) -> RefCounted:
	## A 15-row level from rows (padded with air to w; missing floor rows stone).
	var rows := []
	for y in 15:
		var r: String = lines[y] if y < lines.size() else ("#".repeat(w) if y >= 13 else "")
		rows.append(r.rpad(w, "."))
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n" + header + "---\n" + "\n".join(rows))
	return lv


func _world_of(lv: RefCounted, diff := "dusk", monsters := false) -> Node2D:
	game.reset()
	game.new_hero("knight")
	game.data["difficulty"] = diff
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = not monsters
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	for i in 3:
		w.tick(DT)
	return w


func _free(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _ticks(w: Node2D, seconds: float, pad := {}) -> void:
	for i in int(round(seconds / DT)):
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _drop_on(w: Node2D, cell: Vector2i) -> void:
	## Wick dropped onto a cell's top from a little above it (a landing).
	var pl: Node2D = w.player
	pl.reset_at(Vector2((cell.x + 0.5) * TILE, cell.y * TILE - 20.0))
	pl.velocity = Vector2.ZERO
	pl.on_floor = false
	for i in 40:
		w.test_pad = {}
		w._read_pad()
		w.tick(DT)
		if pl.on_floor:
			break


func _draw_with(cb: Callable) -> bool:
	## Runs cb(node) inside a Node2D's _draw; true once it has run.
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar cb: Callable\nvar ran := false\nfunc _draw() -> void:\n\tcb.call(self)\n\tran = true\n"
	s.reload()
	var n: Node2D = s.new()
	n.cb = cb
	root.add_child(n)
	n.queue_redraw()
	for i in 3:
		await process_frame
		if n.ran:
			break
	var ok: bool = n.ran
	n.queue_free()
	await process_frame
	return ok


func _stub_hud() -> Node:
	var s := GDScript.new()
	s.source_code = "extends CanvasLayer\nvar said: Array = []\nfunc bark(k: String) -> void:\n\tsaid.append(k)\n" \
			+ "func show_hint(_t = null) -> void:\n\tpass\nfunc toast(_a = \"\", _b = \"\") -> void:\n\tpass\n" \
			+ "func bump_embers() -> void:\n\tpass\nfunc bump_flames() -> void:\n\tpass\nfunc title_card(_a = \"\", _b = \"\") -> void:\n\tpass\n" \
			+ "func sigil_found(_a = 0, _b = null) -> void:\n\tpass\nfunc level_up(_n = 0) -> void:\n\tpass\nfunc banner(_t = \"\") -> void:\n\tpass\n" \
			+ "func boss_bar(_i = null) -> void:\n\tpass\nfunc dim_ring(_on = false) -> void:\n\tpass\n"
	s.reload()
	return s.new()


# ---------------------------------------------------------------- glass

func _test_glass() -> void:
	## Strain per pane: a landing, standing, a second landing; shots; breaks;
	## the reform; a snuff; every difficulty.
	var rows := ["", "", "", "", "", "", "", "", "", "", "", "",
			"............................................",
			"########GGGGGG####...G......................"]
	for d in ["dusk", "nightfall", "witching"]:
		var lv := _mk(rows, "", 48)
		var w := await _world_of(lv, d)
		var glass = w.features.module("glass")
		_check(glass != null, "%s: the glass module is built" % d)
		var pane := Vector2i(10, 13)
		_drop_on(w, pane)
		var land := _knob("glass_land", d)
		var stand := _knob("glass_stand", d)
		var s1: float = glass.panes[pane]["strain"]
		_check(w.player.on_floor and absf(s1 - land) < 0.03, "%s: a landing strains a pane %.2f (glass_land %.2f)" % [d, s1, land])
		var lasted := 0.0
		while glass.panes[pane]["state"] == "whole" and lasted < 4.0:
			_ticks(w, DT)
			lasted += DT
		var want := (1.0 - land) / stand
		_check(absf(lasted - want) < 0.05, "%s: after one landing a pane lasts %.2f s of standing (want (1 - land) / stand = %.2f)" % [d, lasted, want])
		if d == "dusk":
			_check(absf(want - 1.09) < 0.02, "Dusk: one landing, then about 1.1 s (the owner's feel lab)")
		# The flash: still solid for FLASH, then air.
		var flash: float = (load(GLASS) as Script).get_script_constant_map()["FLASH"]
		_check(lv.tile(pane.x, pane.y) == LevelData.GLASS, "%s: a pane at full strain flashes first (still glass)" % d)
		_ticks(w, flash + 0.05)
		_check(lv.tile(pane.x, pane.y) == LevelData.AIR and glass.pane_state(pane) == "gone", "%s: then it's air" % d)
		# A second landing breaks a pane landed on once (after a step off it).
		var p2 := Vector2i(12, 13)
		_drop_on(w, p2)
		w.player.reset_at(Vector2(6 * TILE, 13 * TILE))
		_ticks(w, 0.2)
		_drop_on(w, p2)
		_ticks(w, 0.02)
		var two := minf(1.0, 2.0 * land)
		var got2: float = 1.0 if glass.pane_state(p2) != "whole" else float(glass.panes[p2]["strain"])
		_check(got2 >= two - 0.01 and (two < 1.0 or glass.pane_state(p2) != "whole"),
				"%s: a second landing adds another glass_land (strain %.2f, want %.2f%s)" % [d, got2, two, ": it breaks" if two >= 1.0 else ""])
		# The reform, glass_reform later, never into a body.
		var reform := _knob("glass_reform", d)
		w.player.reset_at(Vector2((pane.x + 0.5) * TILE, 11 * TILE))   # standing in the hole's air (a body in it)
		w.player.velocity = Vector2.ZERO
		for i in int((reform + 1.0) / DT):
			w.player.reset_at(Vector2((pane.x + 0.5) * TILE, pane.y * TILE + 30.0))
			w.player.velocity = Vector2.ZERO
			w.test_pad = {}
			w._read_pad()
			w.tick(DT)
		_check(lv.tile(pane.x, pane.y) == LevelData.AIR, "%s: a pane never reforms into a body" % d)
		w.player.reset_at(Vector2(4 * TILE, 13 * TILE))
		_ticks(w, 1.0)
		_check(lv.tile(pane.x, pane.y) == LevelData.GLASS and glass.pane_state(pane) == "whole" and float(glass.panes[pane]["strain"]) == 0.0,
				"%s: and reforms once it's clear, strain gone" % d)
		await _free(w)
	# Hero attacks never strain it; an enemy shot does; break_glass flashes it.
	var lv2 := _mk(rows, "", 48)
	var w2 := await _world_of(lv2)
	var g2 = w2.features.module("glass")
	var p := Vector2i(11, 13)
	w2.player.reset_at(Vector2(9 * TILE, 13 * TILE))
	w2.features.strike(Rect2(p.x * TILE - 8, p.y * TILE - 8, 48, 48), 1)
	w2.spawn_shot({"kind": "knife", "owner": "player", "pos": Vector2((p.x + 0.5) * TILE, p.y * TILE + 8), "vel": Vector2(0, 50), "life": 0.5, "coef": 1.0})
	_ticks(w2, 0.1)
	_check(float(g2.panes[p]["strain"]) == 0.0, "hero attacks and shots never strain glass")
	var shot_strain: float = (load(GLASS) as Script).get_script_constant_map()["SHOT_STRAIN"]
	var q := Vector2i(13, 13)
	w2.spawn_shot({"kind": "arrow", "owner": "enemy", "pos": Vector2((q.x + 0.5) * TILE, q.y * TILE - 20), "vel": Vector2(0, 400), "life": 1.0, "dmg": 10.0})
	_ticks(w2, 0.2)
	_check(absf(float(g2.panes[q]["strain"]) - shot_strain) < 0.01, "an enemy shot strains a pane %.1f (%.2f)" % [shot_strain, float(g2.panes[q]["strain"])])
	w2.features.break_glass(Vector2i(8, 13))
	_check(g2.pane_state(Vector2i(8, 13)) == "flash", "break_glass (a Glassmite, the Saint's Shatter) flashes a pane at once")
	_ticks(w2, 0.5)
	_check(lv2.tile(8, 13) == LevelData.AIR, "and then it's air")
	# A snuff puts every pane back (a retry sees the same level).
	g2.strain_glass(Vector2i(9, 13), 0.6)
	w2.features.on_respawn()
	_check(lv2.tile(8, 13) == LevelData.GLASS and float(g2.panes[Vector2i(9, 13)]["strain"]) == 0.0 and float(g2.panes[q]["strain"]) == 0.0,
			"a snuff's relight puts every pane back whole")
	# The stages show and sound: cracks at 0.4 and 0.8.
	g2.strain_glass(Vector2i(9, 13), 0.45)
	var st1 := int(g2.panes[Vector2i(9, 13)]["stage"])
	g2.strain_glass(Vector2i(9, 13), 0.4)
	_check(st1 == 1 and int(g2.panes[Vector2i(9, 13)]["stage"]) == 2, "a pane cracks at 0.4 and again at 0.8")
	# The stand-in drawing runs inside a real _draw (rects and a TriBatch only).
	var drew := await _draw_with(func(ci: Node2D) -> void:
		g2.draw_under(ci)
		g2.draw_glow(ci))
	_check(drew, "the glass stand-ins draw inside _draw")
	await _free(w2)


func _test_glass_arena() -> void:
	## In the Saint's nave (5-4's P_ARENA): no standing strain, a landing and
	## a break still count, ARENA_REFORM, and at once on a retry. The glass of
	## the approach is ordinary glass.
	var path := "res://levels/5-4.txt"
	if not FileAccess.file_exists(path):
		print("  skipped: 5-4.txt missing (the arena rule)")
		return
	var lv = LevelData.load_file(path)
	var w := await _world_of(lv)
	var glass = w.features.module("glass")
	var arena_panes := 0
	var outside := 0
	for c in glass.panes:
		if glass.panes[c]["arena"]:
			arena_panes += 1
		else:
			outside += 1
	_check(glass.arena and arena_panes == 20, "the nave's four platforms are arena glass (%d panes)" % arena_panes)
	_check(outside > 0, "the approach's glass is not (%d panes)" % outside)
	var a := Vector2i(-1, -1)
	for c in glass.panes:
		if glass.panes[c]["arena"] and (a.x < 0 or c.x < a.x):
			a = c
	_drop_on(w, a)
	var s1: float = glass.panes[a]["strain"]
	_ticks(w, 2.0)
	_check(w.player.on_floor and absf(float(glass.panes[a]["strain"]) - s1) < 0.001 and s1 > 0.3,
			"arena glass takes a landing (%.2f) but no standing strain (%.2f after 2 s)" % [s1, float(glass.panes[a]["strain"])])
	var arena_reform: float = (load(GLASS) as Script).get_script_constant_map()["ARENA_REFORM"]
	var b := a + Vector2i(3, 0)
	w.features.break_glass(b)
	_ticks(w, 0.5)
	_check(lv.tile(b.x, b.y) == LevelData.AIR, "a break still breaks it")
	var cm: Dictionary = (load(GLASS) as Script).get_script_constant_map()
	_ticks(w, float(cm["FLASH"]) + arena_reform + float(cm["SHIMMER"]) + 0.1 - 0.5)
	_check(lv.tile(b.x, b.y) == LevelData.GLASS, "and it reforms in %.0f s (after its flash, before its shimmer)" % arena_reform)
	w.features.break_glass(b)
	_ticks(w, 0.5)
	w.features.on_boss_reset()
	_check(lv.tile(b.x, b.y) == LevelData.GLASS and glass.pane_state(b) == "whole", "at once on a retry")
	# Walking from pane to pane never strains it (only a real landing does):
	# six passes end to end of platform A, and every pane is as it was.
	var x1 := a.x
	while glass.panes.has(Vector2i(x1 + 1, a.y)) and bool(glass.panes[Vector2i(x1 + 1, a.y)]["arena"]):
		x1 += 1
	_drop_on(w, a + Vector2i(2, 0))
	_ticks(w, 0.1)
	var before := {}
	for x in range(a.x, x1 + 1):
		before[x] = float(glass.panes[Vector2i(x, a.y)]["strain"])
	var lo := a.x * TILE + 20.0
	var hi := (x1 + 1) * TILE - 20.0
	var right := true
	var passes := 0
	for i in int(20.0 / DT):
		var px: float = w.player.position.x
		if right and px >= hi:
			right = false
			passes += 1
		elif not right and px <= lo:
			right = true
			passes += 1
		if passes >= 6:
			break
		_ticks(w, DT, {"right": right, "left": not right})
	var same := true
	for x in range(a.x, x1 + 1):
		var c := Vector2i(x, a.y)
		same = same and glass.pane_state(c) == "whole" and absf(float(glass.panes[c]["strain"]) - float(before[x])) < 0.001
	_check(passes >= 6 and same and w.player.on_floor, "six walks end to end of platform A (x %d-%d) and every pane is whole, unstrained (%d passes)" % [a.x, x1, passes])
	# A real landing still counts.
	_drop_on(w, a + Vector2i(1, 0))
	_check(float(glass.panes[a + Vector2i(1, 0)]["strain"]) >= float(before[a.x + 1]) + _knob("glass_land") - 0.01, "and a landing on it still strains it")
	await _free(w)


# ---------------------------------------------------------------- gusts

func _test_gusts() -> void:
	var rows := ["", "", "", "", "", "", "", "", "", "", "", "",
			"......L.........................................",
			"################################################"]
	var lv := _mk(rows, "gusts: 4-19:L:A, 24-39:R:B\n", 48)
	var w := await _world_of(lv)
	var glass = w.features.module("glass")
	var pl: Node2D = w.player
	var za: Dictionary = glass.zones[0]
	var zb: Dictionary = glass.zones[1]
	_check(glass.zones.size() == 2 and int(za["dir"]) == -1 and str(zb["phase"]) == "B", "the header's zones: %s" % [glass.zones])
	# The tell, then the push.
	var tell_t := -1.0
	var gust_t := -1.0
	var gust_b := -1.0
	for i in int(6.0 / DT):
		_ticks(w, DT)
		var ph: Dictionary = glass.gust_phase(za)
		if tell_t < 0.0 and ph["state"] == "tell":
			tell_t = w.ftime
		if tell_t >= 0.0 and gust_t < 0.0 and ph["state"] == "gust":
			gust_t = w.ftime
		if gust_t >= 0.0 and gust_b < 0.0 and glass.gust_phase(zb)["state"] == "gust":
			gust_b = w.ftime
	var cm: Dictionary = (load(GLASS) as Script).get_script_constant_map()
	_check(tell_t >= 0.0 and absf(gust_t - tell_t - _knob("gust_tell")) < 0.02, "a gust tells %.2f s before it blows (%.2f)" % [_knob("gust_tell"), gust_t - tell_t])
	# phase B's gust begins CYCLE / 2 after phase A's (it may have come first)
	var gap := fposmod(gust_b - gust_t, float(cm["CYCLE"]))
	_check(gust_b >= 0.0 and absf(gap - float(cm["CYCLE"]) * 0.5) < 0.02, "phase B blows %.1f s after phase A (%.2f)" % [float(cm["CYCLE"]) * 0.5, gap])
	for d in ["nightfall", "witching"]:
		w.diff = d
		while glass.gust_phase(za)["state"] != "calm":
			_ticks(w, DT)
		var t := -1.0
		var g := -1.0
		for i in int(6.0 / DT):
			_ticks(w, DT)
			var ph: Dictionary = glass.gust_phase(za)
			if t < 0.0 and ph["state"] == "tell":
				t = w.ftime
			if t >= 0.0 and g < 0.0 and ph["state"] == "gust":
				g = w.ftime
		_check(absf(g - t - _knob("gust_tell", d)) < 0.02, "%s: the tell is %.2f s (%.2f)" % [d, _knob("gust_tell", d), g - t])
	w.diff = "dusk"
	# The push, on the ground and in the air, at full blow.
	pl.reset_at(Vector2(12 * TILE, 13 * TILE))
	_ticks(w, 0.1)
	var full := false
	for i in int(6.0 / DT):
		_ticks(w, DT)
		var ph: Dictionary = glass.gust_phase(za)
		if ph["state"] == "gust" and float(ph["k"]) >= 1.0:
			full = true
			break
	_ticks(w, DT)
	var push := _knob("gust_push")
	_check(full and pl.on_floor and absf(pl.push.x + push * 0.5) < 0.5, "grounded, a gust pushes half: %.0f px/s (want %.0f)" % [pl.push.x, -push * 0.5])
	_check(w.dims().has("gust") and absf(float(w.dims()["gust"]["mult"]) - _knob("gust_dim")) < 0.001, "and dims his light x%.2f" % _knob("gust_dim"))
	var amb = w.get("ambient")
	if amb != null and "wind_k" in amb:
		_check(float(amb.wind_k) > 0.9 and float(amb.wind_dir) == -1.0, "and the ambient's wind blows with it (k %.2f)" % float(amb.wind_k))
	pl.velocity = Vector2(0, -400)
	pl.on_floor = false
	pl.position.y -= 4.0
	_ticks(w, 3 * DT)
	_check(not pl.on_floor and absf(pl.push.x + push) < 0.5, "in the air, the whole push: %.0f px/s" % pl.push.x)
	# The airborne grace: a gust that begins while he's airborne waits.
	var zb_x := (float(zb["x0"]) + 4.0) * TILE
	pl.reset_at(Vector2(zb_x, 13 * TILE))
	_ticks(w, 0.05)
	while glass.next_gust(zb) > 0.05 or glass.next_gust(zb) == 0.0:
		_ticks(w, DT)
		pl.reset_at(Vector2(zb_x, 13 * TILE))
	pl.velocity = Vector2(0, -560)
	pl.on_floor = false
	pl.position.y -= 4.0
	var pushed_air := false
	for i in int(0.5 / DT):
		_ticks(w, DT)
		if not pl.on_floor and absf(pl.push.x) > 0.5:
			pushed_air = true
	_check(not pushed_air, "a gust that begins while he's airborne waits for him to land")
	# A lamp standing in the wind loses gust_lamp s as each gust begins.
	var lamp: Dictionary = w.features.lanterns[0]
	w.features.light(lamp)
	_ticks(w, DT)
	var t0: float = lamp["t"]
	var t1 := t0
	for i in int(5.0 / DT):
		_ticks(w, DT)
		if float(lamp["t"]) < t1 - 1.0:
			t1 = lamp["t"]
			break
		t1 = lamp["t"]
	var drained := t0 - t1
	_check(drained >= _knob("gust_lamp") and drained < _knob("gust_lamp") + 5.0, "a lamp in the wind loses %.0f s as a gust begins (lost %.1f)" % [_knob("gust_lamp"), drained])
	# Shots drift at half the push.
	while not (glass.gust_phase(za)["state"] == "gust" and float(glass.gust_phase(za)["k"]) >= 1.0):
		_ticks(w, DT)
	var sh: Dictionary = w.spawn_shot({"kind": "arrow", "owner": "enemy", "pos": Vector2(10 * TILE, 8 * TILE), "vel": Vector2(0, 0), "life": 1.0, "dmg": 1.0})
	var x0: float = (sh["pos"] as Vector2).x
	_ticks(w, 0.1)
	var drift: float = ((sh["pos"] as Vector2).x - x0) / 0.1
	_check(absf(drift + push * float(cm["SHOT_DRIFT"])) < 8.0, "a shot drifts at %.0f%% of the push (%.0f px/s)" % [float(cm["SHOT_DRIFT"]) * 100.0, drift])
	await _free(w)


func _test_stone_brake() -> void:
	## A gust never pushes him off stone onto glass: stopped on a 2-wide post
	## at its downwind edge, no input through a whole gust, he's still on the
	## post and the glass beside it untouched; on the glass itself it pushes.
	for dir in [-1, 1]:
		var rows := ["", "", "", "", "", "", "", "", "", "", "", "", "",
				"##########GGG##GGG##############################",
				"##########...##...##############################"]
		var lv := _mk(rows, "gusts: 6-26:%s:A\n" % ("L" if dir < 0 else "R"), 48)
		var w := await _world_of(lv)
		var glass = w.features.module("glass")
		var pl: Node2D = w.player
		var z: Dictionary = glass.zones[0]
		var post := Vector2i(13, 14)   # x 13-14
		var at := Vector2(post.x * TILE + 11.0 if dir < 0 else (post.y + 1) * TILE - 11.0, 13 * TILE)
		_to_gust(w, glass, z, 0.25)
		pl.reset_at(at)
		_ticks(w, 0.1)
		var start := float(glass.next_gust(z))
		var pushed := 0.0
		for i in int((0.2 + float(_cm()["GUST_ON"]) + 0.3) / DT):
			_ticks(w, DT)
			pushed = maxf(pushed, absf(float(glass.gust_at(pl.center()).x)))
		var on_post: bool = pl.on_floor and pl.position.x > post.x * TILE and pl.position.x < (post.y + 1) * TILE
		var side := Vector2i(post.x - 1, 13) if dir < 0 else Vector2i(post.y + 1, 13)
		_check(start < 0.3 and pushed >= _knob("gust_push") * 0.99 and on_post and float(glass.panes[side]["strain"]) == 0.0,
				"a %s gust never pushes him off a 2-wide post onto its glass (x %.0f, the pane's strain %.2f)" % ["left" if dir < 0 else "right", pl.position.x, float(glass.panes[side]["strain"])])
		# On the glass, it pushes (half, grounded).
		_to_gust(w, glass, z, -0.6)
		pl.reset_at(Vector2(16.5 * TILE, 13 * TILE))
		_ticks(w, 0.05)
		_check(pl.on_floor and absf(pl.push.x - dir * _knob("gust_push") * 0.5) < 0.5, "while on the glass itself it pushes (%.0f px/s)" % pl.push.x)
		await _free(w)


func _to_gust(w: Node2D, glass, z: Dictionary, before: float) -> void:
	## Moves the feature clock on (never back) to `before` s ahead of zone z's
	## next gust start (negative: that far into a gust).
	var cm := _cm()
	var off := 0.0 if str(z.get("phase", "A")) == "A" else float(cm["CYCLE"]) * 0.5
	var want := fposmod(float(cm["CYCLE"]) - float(cm["GUST_ON"]) - before, float(cm["CYCLE"]))
	var now := fposmod(float(w.ftime) - off, float(cm["CYCLE"]))
	w.ftime = float(w.ftime) + fposmod(want - now, float(cm["CYCLE"])) + float(cm["CYCLE"])


func _cm() -> Dictionary:
	return (load(GLASS) as Script).get_script_constant_map()


func _test_wind_clock() -> void:
	## Dawnglass lit by a lamp in wind shows its own clock: the gusts it will
	## lose count, so it fades (k under 0.5) at least 1 s before it's air,
	## whenever it was lit; and it fades, never drops.
	var rows := ["", "", "", "", "", "", "", "", "", "", "", "",
			"......L.........................................",
			"#######AAAA#####################################"]
	for lead in [0.05, -0.05, 2.0]:
		var lv := _mk(rows, "gusts: 2-20:L:A\n", 48)
		var w := await _world_of(lv)
		var glass = w.features.module("glass")
		var z: Dictionary = glass.zones[0]
		var pl: Node2D = w.player
		pl.reset_at(Vector2(30 * TILE, 13 * TILE))
		# (The clock moved on, then a few ticks so the zone's state has
		# caught up before the lamp is lit: a gust already blowing has taken
		# its toll.)
		_to_gust(w, glass, z, lead + 0.05)
		_ticks(w, 0.05)
		var lamp: Dictionary = w.features.lanterns[0]
		w.features.light(lamp)
		var pane := Vector2i(8, 13)
		var last_bright := -1.0
		var air_at := -1.0
		var lit_at := float(w.ftime)
		var k_prev := 1.0
		var worst_drop := 0.0
		var lit_seen := false
		for i in int(30.0 / DT):
			_ticks(w, DT)
			var k: float = glass.dawn_k(pane)
			if k >= 0.0:
				lit_seen = true
				if k >= 0.5:
					last_bright = float(w.ftime)
				worst_drop = maxf(worst_drop, k_prev - k)
				k_prev = k
			elif lit_seen:
				air_at = float(w.ftime)
				break
		_check(lit_seen and air_at > 0.0 and air_at - last_bright >= 1.0,
				"a lamp in wind lit %.2f s before a gust: its pane fades under half %.2f s before it's air (it burned %.1f s)" % [lead, air_at - last_bright, air_at - lit_at])
		_check(worst_drop <= 0.1, "and it fades, never drops (the biggest step %.2f)" % worst_drop)
		await _free(w)


# ---------------------------------------------------------------- dawnglass

func _test_dawnglass() -> void:
	var rows := ["", "", "", "", "", "", "", "", "", "", "", "",
			"....L.......................",
			"#####AAAAAA##.......AAAA#####"]
	var lv := _mk(rows, "", 32)
	var w := await _world_of(lv)
	var glass = w.features.module("glass")
	var pl: Node2D = w.player
	pl.reset_at(Vector2(15 * TILE, 13 * TILE))
	_ticks(w, 0.3)
	# His own light never counts.
	pl.reset_at(Vector2(20.5 * TILE, 12 * TILE))
	_ticks(w, 0.3)
	_check(lv.tile(20, 13) == LevelData.DAWNGLASS and lv.tile(5, 13) == LevelData.DAWNGLASS, "unlit, dawnglass is air (Wick's own light never counts)")
	var lamp: Dictionary = w.features.lanterns[0]
	w.features.light(lamp)
	_ticks(w, 0.2)
	var near := []
	var far := []
	for x in range(5, 11):
		var d := LevelData.cell_center(Vector2i(x, 13)).distance_to(lamp["flame"])
		if d <= LAMP_R:
			near.append(x)
		elif d > LAMP_R + 8.0:
			far.append(x)
	var ok_near := true
	for x in near:
		ok_near = ok_near and lv.tile(x, 13) == LevelData.DAWN_ON
	var ok_far := true
	for x in far:
		ok_far = ok_far and lv.tile(x, 13) == LevelData.DAWNGLASS
	_check(near.size() == 4 and ok_near, "a lamp lights the four panes past it (%s)" % [near])
	_check(far.size() >= 1 and ok_far, "and not the ones out of its reach (%s)" % [far])
	_check(bool(lamp.get("anchor", false)), "a lamp that lights dawnglass is an anchor (the Stillmaw never swallows it)")
	var wl: Dictionary = w.light_by_id(int(lamp["id"]))
	_check(float(wl.get("rule_r", -1.0)) == LAMP_R, "and lit_at reads its nominal radius (rule_r %s)" % wl.get("rule_r", "none"))
	# Its clock: bright, then fading over the lamp's last DAWN_FADE s.
	var cm: Dictionary = (load(GLASS) as Script).get_script_constant_map()
	var fade: float = cm["DAWN_FADE"]
	var flick: float = cm["DAWN_FLICKER"]
	_check(glass.dawn_k(Vector2i(5, 13)) >= 1.0, "lit with time to spare, a pane is bright (k %.2f)" % glass.dawn_k(Vector2i(5, 13)))
	lamp["t"] = fade * 0.5
	_ticks(w, 0.15)
	var k := float(glass.dawn_k(Vector2i(5, 13)))
	_check(k > 0.3 and k < 0.6, "over its lamp's last %.0f s it fades (k %.2f at half)" % [fade, k])
	# Standing on it as the lamp goes: a flicker, then air, and he falls.
	pl.reset_at(Vector2(7.5 * TILE, 13 * TILE))
	_ticks(w, 0.1)
	_check(pl.on_floor, "a lit pane is a floor")
	lamp["t"] = 0.05
	var out_at := -1.0
	var air_at := -1.0
	for i in int(1.5 / DT):
		_ticks(w, DT)
		if out_at < 0.0 and not bool(lamp["lit"]):
			out_at = w.ftime
		if out_at >= 0.0 and air_at < 0.0 and lv.tile(7, 13) == LevelData.DAWNGLASS:
			air_at = w.ftime
	_check(out_at >= 0.0 and air_at >= 0.0 and air_at - out_at >= flick - 0.01 and air_at - out_at <= flick + 0.2,
			"its lamp out, it flickers %.2f s, then it's air (%.2f)" % [flick, air_at - out_at])
	_check(not pl.on_floor or pl.position.y > 13 * TILE, "and whoever stood on it falls")
	await _free(w)


func _test_barks() -> void:
	## first_glass waits for his next landing on stone, never mid-jump.
	var rows := ["", "", "", "", "", "", "", "", "", "", "", "",
			"........................................",
			"##########GGGG##########################"]
	var lv := _mk(rows, "", 40)
	var w := await _world_of(lv)
	var hud := _stub_hud()
	w.hud = hud
	_drop_on(w, Vector2i(11, 13))
	_ticks(w, 0.1)
	_check(not hud.said.has("first_glass"), "a first glass landing says nothing on the glass")
	w.player.reset_at(Vector2(18 * TILE, 12 * TILE - 20))
	w.player.on_floor = false
	_ticks(w, 0.6)
	_check(hud.said.has("first_glass"), "first_glass comes at the next stone landing")
	w.hud = null
	hud.free()
	await _free(w)


func _test_look_hooks() -> void:
	## A2's hooks: the theme's gust painter replaces the stand-in.
	var painter := "user://test_w5_gust_painter.gd"
	var f := FileAccess.open(painter, FileAccess.WRITE)
	f.store_string("extends RefCounted\nstatic var calls := 0\nstatic func draw_gust(_glow: CanvasItem, _tb, g: Dictionary) -> void:\n\tcalls += 1\n")
	f.close()
	var sc = load(painter)
	var g = load(GLASS).new()
	g._gust_painter = sc
	var lv := _mk([], "gusts: 2-20:L:A\n", 30)
	var stub := Node2D.new()
	stub.set_script(_world_stub())
	root.add_child(stub)
	stub.set("level", lv)
	g.build(stub, lv)
	g._gust_painter = sc
	stub.set("ftime", 3.5)   # inside phase A's gust
	var cv := Node2D.new()
	root.add_child(cv)
	g.draw_glow(cv)
	_check(int(sc.get("calls")) >= 1, "a theme's gust_painter draws the wind instead of the stand-in")
	cv.queue_free()
	stub.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(painter))


func _test_knock_and_void() -> void:
	## The rev5 review's two W5 falls: a contact knock never carries Wick off
	## a floor edge into the void (spec §4.1 rule 3: from World 5 on it loses
	## its sideways part; mid-air over the void it keeps his own drift), and
	## the void takes its own knob, void_pct (glass.gd), W1-W4's pits Combat's.
	if not FileAccess.file_exists("res://levels/5-1.txt"):
		return
	var lv = LevelData.load_file("res://levels/5-1.txt")
	var w := await _world_of(lv)
	var pl: Node2D = w.player
	# The 2-wide capital at 237-238 (FA_ARCHES), the void either side.
	pl.reset_at(Vector2(237.9 * TILE, 9 * TILE))
	for i in 3:
		w.tick(DT)
	pl.invuln = 0.0
	_check(pl.on_floor, "(he stands on the capital at 237-238)")
	pl.take_damage(10.0, pl.position.x + 20.0, "hit")
	_check(absf(pl.velocity.x) < 60.0 and pl.velocity.y < 0.0, "a touch on a 2-wide glass capital knocks him up, braked short of the void (vx %.0f)" % pl.velocity.x)
	for i in int(0.8 / DT):
		w.tick(DT)
	_check(pl.on_floor and w.snuffs == 0 and pl.position.x > 237.0 * TILE and pl.position.x < 239.0 * TILE, "and he lands on the capital (x %.1f)" % (pl.position.x / TILE))
	pl.reset_at(Vector2(239.5 * TILE, 6 * TILE))   # (over the gap 239-240: the void under him)
	pl.on_floor = false
	pl.velocity = Vector2(150.0, 0.0)
	pl.invuln = 0.0
	pl.take_damage(10.0, pl.position.x + 20.0, "hit")
	_check(absf(pl.velocity.x - 150.0) < 0.01, "a hit mid-hop over the void keeps his own drift (vx %.0f)" % pl.velocity.x)
	# The void's own share.
	pl.reset_at(Vector2(237.9 * TILE, 9 * TILE))
	for i in 3:
		w.tick(DT)
	pl.hp = pl.max_hp
	w.fell("pit")
	var took: float = 1.0 - pl.hp / pl.max_hp
	_check(absf(took - float(_knobs["void_pct"]["dusk"])) < 0.001, "the W5 void takes void_pct (%.2f, the knob %.2f)" % [took, _knobs["void_pct"]["dusk"]])
	await _free(w)
	# W1-W4 keep theirs: a knock on 1-1's floor is v2's 210 px/s.
	var lv1 = LevelData.load_file("res://levels/1-1.txt")
	var w1 := await _world_of(lv1)
	var p1: Node2D = w1.player
	for i in 3:
		w1.tick(DT)
	p1.invuln = 0.0
	p1.take_damage(1.0, p1.position.x + 20.0, "hit")
	_check(absf(absf(p1.velocity.x) - 210.0) < 0.5, "W1's knock is v2's (vx %.0f)" % p1.velocity.x)
	await _free(w1)


func _world_stub() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar ftime := 0.0\nvar diff := \"dusk\"\nvar level: RefCounted\nvar player = null\nvar enemies: Array = []\nvar features = null\nfunc view_rect() -> Rect2:\n\treturn Rect2(0, 0, 844, 480)\n"
	s.reload()
	return s


# ---------------------------------------------------------------- the levels

func _entities(lv: RefCounted, kind: String) -> Array:
	return lv.entities.filter(func(e): return e["kind"] == kind)


func _test_headers() -> void:
	for id in IDS:
		var lv: RefCounted = _levels[id]
		var sp: Dictionary = SPEC[id]
		_check(lv.errors.is_empty() and Rules.height_ok(lv), "%s parses, %d-%d rows (%d)" % [id, Rules.HEIGHT_MIN, Rules.HEIGHT_MAX, lv.height])
		_check(lv.title == sp["name"] and lv.area == int(sp["area"]) and lv.theme == sp["theme"] and lv.music == "sanctum",
				"%s: %s, area %d, theme %s, music sanctum (%s, %d, %s, %s)" % [id, sp["name"], sp["area"], sp["theme"], lv.title, lv.area, lv.theme, lv.music])
		if sp.has("width"):
			_check(lv.width == int(sp["width"]), "%s is %d tiles (%d)" % [id, sp["width"], lv.width])
		_check(str(lv.story.get("start", "")) == "beat_%s" % id.replace("-", "_"), "%s opens with beat_%s" % [id, id.replace("-", "_")])
		var xs := []
		for a in _entities(lv, "altar"):
			xs.append(int(a["cell"].x))
		xs.sort()
		if sp.has("altars"):
			_check(xs == sp["altars"], "%s: altars at %s (%s)" % [id, sp["altars"], xs])
		var marks: Array = [lv.start.x] + xs
		var bells := _entities(lv, "bell")
		if not bells.is_empty():
			_check(bells.size() == 1, "%s: one bell (%d)" % [id, bells.size()])
			marks.append(int(bells[0]["cell"].x))
			var cp := Rules.checkpoint_problems(lv, MAX_GAP)
			_check(cp.is_empty(), "%s: 3-5 altars, an altar by every sealed door %s" % [id, cp])
		else:
			var boss := _entities(lv, "boss")
			if not boss.is_empty():
				marks.append(int(boss[0]["cell"].x))
		# (Along the route: x in a strip, Rules.checkpoint_gaps.)
		var worst: int = Rules.checkpoint_gaps(lv)["worst"]
		_check(worst <= MAX_GAP, "%s: at most %d tiles between checkpoints (%d)" % [id, MAX_GAP, worst])
		_check(lv.count("sigil") == 3, "%s has three sigils" % id)
	var l3: RefCounted = _levels["5-3"]
	_check(l3.secret == "5-S" and not _entities(l3, "silver_bell").is_empty(), "5-3's silver bell opens 5-S")
	var l4: RefCounted = _levels["5-4"]
	_check(l4.boss == "saint" and l4.boss_music == "saint" and str(l4.story.get("boss", "")) == "boss_5_before" and str(l4.story.get("end", "")) == "boss_5_after",
			"5-4: the Prism Saint, her music, boss_5_before and boss_5_after")
	for id in ["5-1", "5-2"]:
		var lv: RefCounted = _levels[id]
		var want: PackedStringArray = str(SPEC[id]["dread"]).split("|")
		_check(str(lv.dread.get("name", "")) == want[0] and str(lv.dread.get("kind", "")) == want[1], "%s's Dread is %s (%s)" % [id, want[0], lv.dread])
	# The ruling (decisions.md, wave 1): 5-3's Dread is no Paneguard.
	_check(not l3.dread.is_empty() and str(l3.dread["kind"]) != "paneguard", "5-3's Dread, %s, is no Paneguard (the share caps)" % l3.dread)


func _test_cast() -> void:
	var regular := []
	for id in IDS:
		var lv: RefCounted = _levels[id]
		var n := 0
		var threat := 0.0
		var brutes := 0
		for e in lv.entities:
			var k: String = e["kind"]
			if COST.has(k):
				n += 1
				threat += float(COST[k])
				if k == "frostbuckle" or k == "lurecoil":
					brutes += 1
			if k == "paneguard" or k == "hollow_helm" or k == "frostbuckle":
				var below: int = lv.tile(e["cell"].x, e["cell"].y + 1)
				_check(below != LevelData.GLASS and LevelData.is_safe(below), "%s: the %s at %s stands on stone (fights on stone)" % [id, k, e["cell"]])
		var per := threat * 100.0 / float(lv.width)
		print("  %s: %d monsters, threat %.1f (%.1f per 100 tiles)" % [id, n, threat, per])
		if id != "5-4":
			regular.append(lv)
			var rp := Rules.roster_problems(lv)
			_check(not Rules.roster_of(lv).is_empty() and rp.is_empty(), "%s holds the cast its roster: declares %s" % [id, rp])
			_check(Rules.declared_threat(lv) > 0.0, "%s declares its threat" % id)
		else:
			_check(n == int(SPEC[id]["monsters"]), "5-4: %d monsters on the approach (%d)" % [SPEC[id]["monsters"], n])
		_check(brutes <= 3, "%s: at most 3 brutes" % id)
	# The world's rules across its regular levels (tests/level_rules.gd
	# world_problems): each threat as declared, ramping (flat today, +1 a
	# step once re-cut); once re-cut, roles on every level, no two with the
	# same landmarks or altars, fodder falling, the X-3 mixing, no crowding.
	var tp := Rules.world_problems(regular)
	_check(tp.is_empty(), "5-1 to 5-3: the world's rules (threat, ramp, roles, variety) %s" % [tp])
	# The ruling for 5-3: no Frostbuckle, no Tickwind, no Hollow Helm (an
	# Anointed one breaks the cap); its Paneguards stand where none can be
	# anointed (the scan knows placement since the track B merge: w5.py
	# PANEGUARDS_5_3), and _test_elite_ground holds that.
	var l3: RefCounted = _levels["5-3"]
	for k in ["frostbuckle", "tickwind", "hollow_helm"]:
		_check(_entities(l3, k).is_empty(), "5-3 holds no %s (the share-cap ruling)" % k)
	# The W5 monsters, each first where the spec teaches it.
	_check(not _entities(_levels["5-1"], "glassmite").is_empty() and not _entities(_levels["5-1"], "gustling").is_empty(), "5-1 teaches the Glassmite and the Gustling")
	_check(not _entities(_levels["5-2"], "refractor").is_empty() and not _entities(_levels["5-2"], "paneguard").is_empty(), "5-2 teaches the Refractor and the Paneguard")
	# MB's placement checks.
	var gus = load("res://scripts/gustling.gd")
	var mite = load("res://scripts/glassmite.gd")
	for id in IDS:
		var lv: RefCounted = _levels[id]
		if gus != null and gus.has_method("placement_problems"):
			var gp: Array = gus.placement_problems(lv)
			_check(gp.is_empty(), "%s: every Gustling 5 tiles or more from an edge it pushes toward %s" % [id, gp])
		if mite != null and mite.has_method("placement_problems"):
			var mp: Array = mite.placement_problems(lv)
			_check(mp.is_empty(), "%s: no Glassmite on glass over the void without footing in a jump %s" % [id, mp])


func _test_signs() -> void:
	var story = load("res://scripts/story.gd")
	var ins: Dictionary = (story as Script).get_script_constant_map().get("INSCRIPTIONS", {}) if story != null else {}
	# Since the sign cut the glass, the wind and the dawnglass teach
	# themselves (glass.gd's first-time barks); a sign stays for what no bark
	# says: the glass knights' guard, and the Saint's rule at her door.
	var teach := {"5-1": [], "5-2": ["Glass knights block face-on. Strike after they lunge"], "5-3": [],
			"5-4": ["When her light locks, get behind a mirror"]}
	for id in IDS:
		var lv: RefCounted = _levels[id]
		var signs := _entities(lv, "sign")
		signs.sort_custom(func(a, b): return a["cell"].x < b["cell"].x)
		var texts := []
		for s in signs:
			texts.append(str(s.get("text", "")))
		for t in texts:
			_check(t.length() <= 56, "%s: a sign fits the hint slot (%d): %s" % [id, t.length(), t])
		for t in teach[id]:
			_check(texts.has(t), "%s signs: %s" % [id, t])
		var mine: Array = ins.get(id, [])
		_check(mine.size() == 1 and texts.has(mine[0]), "%s carries its window's inscription (%s)" % [id, mine])
		_check(texts.size() == teach[id].size() + mine.size(), "%s: no other signs (%s)" % [id, texts])


func _test_layout() -> void:
	## Static rules: an 11-wide stone island, the per-screen caps, glass in
	## the wind with stone every 4, and no dawnglass an altar would light.
	for id in IDS:
		var lv: RefCounted = _levels[id]
		# An island 11 wide of stone (so an elite can stand there).
		var wide := false
		for y in range(1, lv.height):
			var run := 0
			for x in lv.width:
				var t: int = lv.tile(x, y)
				if LevelData.is_safe(t) and LevelData.is_solid(t) and not LevelData.is_solid(lv.tile(x, y - 1)):
					run += 1
					wide = wide or run >= 11
				else:
					run = 0
		_check(wide or id == "5-4", "%s has a stone island 11 wide" % id)
		# Per 27-tile screen (a taller level's the views over the rows he
		# stands on in it: Rules.screen_rows; a gust zone is whole columns, or
		# a taller level's its rows): glass 60, dawnglass 40, gust columns 24,
		# lamps 14, monsters 12.
		var worst := {"glass": 0, "dawn": 0, "gust": 0, "lamp": 0, "monster": 0}
		for x0 in range(0, maxi(1, lv.width - 26)):
			for ys in Rules.screen_rows(lv, x0, 27):
				var n := {"glass": 0, "dawn": 0, "gust": 0, "lamp": 0, "monster": 0}
				for x in range(x0, x0 + 27):
					for y in range(ys.x, ys.y + 1):
						var t: int = lv.tile(x, y)
						if t == LevelData.GLASS:
							n["glass"] += 1
						elif t == LevelData.DAWNGLASS:
							n["dawn"] += 1
					for z in lv.gusts:
						if x >= int(z["x0"]) and x <= int(z["x1"]) and int(z.get("y0", 0)) <= ys.y and int(z.get("y1", lv.height - 1)) >= ys.x:
							n["gust"] += 1
				for e in lv.entities:
					if int(e["cell"].x) >= x0 and int(e["cell"].x) < x0 + 27 and Rules.in_rows(e["cell"], ys):
						if e["kind"] == "lantern":
							n["lamp"] += 1
						elif COST.has(e["kind"]) or e["kind"] == "dread":
							n["monster"] += 1
				for k in n:
					worst[k] = maxi(int(worst[k]), int(n[k]))
		_check(int(worst["glass"]) <= 60 and int(worst["dawn"]) <= 40 and int(worst["gust"]) <= 24 and int(worst["lamp"]) <= 14 and int(worst["monster"]) <= 12,
				"%s: per screen at most 60 glass, 40 dawnglass, 24 gust columns, 14 lamps, 12 monsters (%s)" % [id, worst])
		# Glass in the wind (its rows, a taller level's zone): no run of more
		# than 4 panes without stone.
		for z in lv.gusts:
			for y in range(int(z.get("y0", 0)), int(z.get("y1", lv.height - 1)) + 1):
				var run := 0
				for x in range(int(z["x0"]), int(z["x1"]) + 1):
					run = run + 1 if lv.tile(x, y) == LevelData.GLASS else 0
					if run == 5:
						_check(false, "%s: glass in the wind at %d,%d has a stone post every 4 tiles" % [id, x, y])
		# No dawnglass within an altar's light (it would never go out).
		for a in _entities(lv, "altar"):
			var f := LevelData.cell_floor(a["cell"]) - Vector2(0, 30)
			for y in lv.height:
				for x in range(int(a["cell"].x) - 6, int(a["cell"].x) + 7):
					if lv.tile(x, y) == LevelData.DAWNGLASS:
						_check(LevelData.cell_center(Vector2i(x, y)).distance_to(f) > ALTAR_R + 8.0, "%s: no dawnglass in the altar's light at %d,%d" % [id, x, y])
		# Every pane of dawnglass within a lamp's reach.
		var lamps := _entities(lv, "lantern")
		for y in lv.height:
			for x in lv.width:
				if lv.tile(x, y) != LevelData.DAWNGLASS:
					continue
				var lit := false
				for l in lamps:
					var fl := LevelData.cell_floor(l["cell"]) - Vector2(0, 33)
					lit = lit or LevelData.cell_center(Vector2i(x, y)).distance_to(fl) <= LAMP_R
				_check(lit, "%s: the dawnglass at %d,%d is within a lamp's reach" % [id, x, y])


func _test_arena() -> void:
	## The Prism Saint's nave (spec §3.6.4): anchors, platforms, the void, the
	## pillar, and a doorway boss_arena.gd seals whole.
	var lv: RefCounted = _levels["5-4"]
	var boss := _entities(lv, "boss")
	_check(boss.size() == 1, "5-4 has its boss mark")
	if boss.is_empty():
		return
	var x0 := 124
	# (Her mark X is mid-nave since the track B merge: the doorway is the one
	# over the entry stone's floor, Arena.find's door_on_floor, as she seals it.)
	var box: Dictionary = Arena.find(lv, LevelData.cell_floor(boss[0]["cell"]), true)
	_check(int(box["left"]) == (x0 + 2) * TILE and int(box["right"]) == (x0 + 34) * TILE, "the nave runs wall to wall, x %d-%d (%s)" % [x0 + 2, x0 + 33, box])
	var door: Array = box["door"]
	var rows := {}
	for c in door:
		rows[c.y] = true
	_check(door.size() == 6 and rows.keys().size() == 3, "its doorway is three rows of two cells, all sealed on waking (%s)" % [door])
	var sealed_all := true
	for y in range(9, 12):
		for x in [x0, x0 + 1]:
			sealed_all = sealed_all and door.has(Vector2i(x, y))
	_check(sealed_all, "the seal covers the whole opening (rows 9-11)")
	var anchors := []
	for e in _entities(lv, "anchor"):
		anchors.append(Vector2i(e["cell"].x - x0, e["cell"].y))
	anchors.sort()
	_check(anchors == [Vector2i(12, 4), Vector2i(20, 3), Vector2i(24, 4)], "the mirror tracks' anchors at (12,4), (20,3), (24,4) (%s)" % [anchors])
	var plats := {"A": [5, 9, 11], "B": [12, 16, 9], "C": [19, 23, 11], "D": [26, 30, 9]}
	for k in plats:
		var p: Array = plats[k]
		var ok := true
		for x in range(p[0], p[1] + 1):
			ok = ok and lv.tile(x0 + x, p[2]) == LevelData.GLASS
		_check(ok, "platform %s is glass at x %d-%d, row %d" % [k, p[0], p[1], p[2]])
	var void_ok := true
	for x in range(4, 32):
		for y in range(12, 15):
			void_ok = void_ok and lv.tile(x0 + x, y) == LevelData.AIR
	_check(void_ok, "the void, rows 12-14 from x 4 to 31")
	var stone := true
	for x in range(0, 4):
		stone = stone and LevelData.is_safe(lv.tile(x0 + x, 12)) and lv.tile(x0 + x, 11) == LevelData.AIR
	for x in range(32, 36):
		stone = stone and LevelData.is_safe(lv.tile(x0 + x, 10))
	stone = stone and lv.tile(x0 + 32, 9) == LevelData.AIR and lv.tile(x0 + 33, 9) == LevelData.AIR
	_check(stone, "stone at the entry (x 0-3, its top row 12) and on the pillar (x 32-35, its top row 10)")
	var s3 := false
	for e in _entities(lv, "sigil"):
		s3 = s3 or (int(e["index"]) == 2 and e["cell"].x - x0 >= 12 and e["cell"].x - x0 <= 16 and e["cell"].y < 9)
	_check(s3, "sigil 3 above platform B")


func _test_teaching() -> void:
	## Safe first (spec §0.3 rule 3): each verb's first appearance is over
	## ground that can't cost a fall. (Since the sign cut glass.gd's
	## first-time barks teach them, not signs.)
	var l1: RefCounted = _levels["5-1"]
	var first := _first_tile(l1, LevelData.GLASS)
	_check(first.x >= 0 and _floor_below(l1, first, 4), "5-1: the first glass has stone under it (a safe dip) %s" % first)
	var l2: RefCounted = _levels["5-2"]
	var z0: Dictionary = l2.gusts[0]
	var solid := true
	for x in range(int(z0["x0"]), int(z0["x1"]) + 1):
		# (The first floor down each column of it: a taller level's islands
		# stand at their own heights.)
		var fy := maxi(int(z0.get("y0", 0)), 1)
		while fy < l2.height and not LevelData.is_solid(l2.tile(x, fy)):
			fy += 1
		solid = solid and fy < l2.height and LevelData.is_safe(l2.tile(x, fy))
	_check(solid, "5-2: the first gust zone blows over solid stone")
	var d2 := _first_tile(l2, LevelData.DAWNGLASS)
	_check(d2.x >= 0 and _floor_below(l2, d2, 4), "5-2: its one dawnglass step (a first look at 5-3) is over a safe drop %s" % d2)
	var l3: RefCounted = _levels["5-3"]
	var d3 := _first_tile(l3, LevelData.DAWNGLASS)
	_check(d3.x >= 0 and _floor_below(l3, d3, 4), "5-3: dawnglass taught over a safe dip %s" % d3)
	# The first Glassmite stands on glass over stone.
	var mites := _entities(l1, "glassmite")
	mites.sort_custom(func(a, b): return a["cell"].x < b["cell"].x)
	var m0: Vector2i = mites[0]["cell"]
	_check(l1.tile(m0.x, m0.y + 1) == LevelData.GLASS and _floor_below(l1, m0 + Vector2i(0, 1), 4),
			"5-1: the first Glassmite, on glass pews over stone %s" % m0)


func _kind_at(lv: RefCounted, c: Vector2i) -> String:
	for e in lv.entities:
		if e["cell"] == c:
			return str(e["kind"])
	return ""


func _floor_under(lv: RefCounted, c: Vector2i) -> int:
	## The first solid row under a cell (a flier's floor), or -1.
	for y in range(c.y + 1, lv.height):
		if LevelData.is_solid(lv.tile(c.x, y)):
			return y
	return -1


func _test_build2() -> void:
	## Build 2's personalities (the spec's 5-1 to 5-3, the shape plan): 5-1 a
	## strip with a lesson card and no rule, its first Gustling alone over
	## stone right after altar 1; 5-2 islands with the packs twist and the
	## landing rule, its named Anointed Sister Splinter (a Glassmite on a
	## proud stone post, glass a row under her either side) and Brother
	## Bellows (a Gustling over stone); 5-3 the double deck with the omens
	## twist, two roads, the wind on the upper deck's rows only, and Hold the
	## Glass: one hold room of 15 s (the retune's) as tall as both decks, Sister Ember (a
	## Refractor) over its stone and Gleam (a Rattlehound) on the loft's stone.
	var Twists = load("res://scripts/twists.gd")
	var Sealed = load("res://scripts/features/sealed.gd")
	var l1: RefCounted = _levels["5-1"]
	var l2: RefCounted = _levels["5-2"]
	var l3: RefCounted = _levels["5-3"]
	_check(l1.height == LevelData.STRIP_ROWS and Twists.id_in(l1) == "" and Twists.lesson_in(l1) == ["Over Nothing", "Glass holds you once. The void never does."],
			"5-1: a strip, no rule, its lesson card 'Over Nothing' (%s)" % [Twists.lesson_in(l1)])
	_check(Rules.anoint_of(l1).is_empty(), "5-1: no forced Anointed (an X-1)")
	var altars := _entities(l1, "altar").map(func(e): return int(e["cell"].x))
	altars.sort()
	var gus := _entities(l1, "gustling")
	gus.sort_custom(func(a, b): return a["cell"].x < b["cell"].x)
	var g0: Vector2i = gus[0]["cell"]
	var fy := _floor_under(l1, g0)
	var alone := true
	for e in l1.entities:
		if COST.has(e["kind"]) and e["cell"] != g0 and absi(int(e["cell"].x) - g0.x) <= 8:
			alone = false
	var stone := fy > 0
	for dx in range(-5, 6):
		stone = stone and LevelData.is_safe(l1.tile(g0.x + dx, fy)) and l1.tile(g0.x + dx, fy) != LevelData.GLASS
	_check(g0.x > int(altars[0]) and g0.x < int(altars[1]) and alone and stone,
			"5-1: the first Gustling, right after altar 1, alone over stone %s (altars %s)" % [g0, altars])
	# 5-2: islands in the wind, Glassmites in threes.
	_check(l2.height > LevelData.STRIP_ROWS and Twists.id_in(l2) == "packs" and str(l2.headers.get("landing", "")) == "6/2",
			"5-2: islands %d rows tall, the packs twist, landing: 6/2" % l2.height)
	var named := {}
	for a in Rules.anoint_of(l2) + Rules.anoint_of(l3):
		named[str(a["name"])] = a
	var want := {"Sister Splinter": ["glassmite", "Glassed", l2], "Brother Bellows": ["gustling", "Warded", l2],
			"Gleam": ["rattlehound", "Twinned", l3], "Sister Ember": ["refractor", "Burning", l3]}
	for nm in want:
		var w: Array = want[nm]
		var lv: RefCounted = w[2]
		var a: Dictionary = named.get(nm, {})
		var c: Vector2i = a.get("cell", Vector2i(-1, -1))
		var k := _kind_at(lv, c)
		var under := _floor_under(lv, c) if k in ["gustling", "refractor"] else c.y + 1
		_check(k == w[0] and (a.get("omens", []) as Array) == [w[1]] and under > 0 and LevelData.is_safe(lv.tile(c.x, under)) and lv.tile(c.x, under) != LevelData.GLASS,
				"%s: %s, a %s (%s), over stone (%s at %s)" % [lv.id, nm, w[0], w[1], k, c])
	var sp: Vector2i = (named.get("Sister Splinter", {}) as Dictionary).get("cell", Vector2i(-1, -1))
	var glass_by := false
	for dx in range(-4, 5):
		glass_by = glass_by or l2.tile(sp.x + dx, sp.y + 2) == LevelData.GLASS
	_check(glass_by and not LevelData.is_solid(l2.tile(sp.x - 2, sp.y + 1)) and not LevelData.is_solid(l2.tile(sp.x + 2, sp.y + 1)),
			"5-2: Sister Splinter's post stands a row proud, glass under it either side")
	# 5-3: the double deck.
	var rooms: Array = Sealed.parse(str(l3.headers.get("room", "")))
	_check(l3.height > LevelData.STRIP_ROWS and Twists.id_in(l3) == "omens" and str(l3.headers.get("roads", "")).split(";", false).size() == 2,
			"5-3: the double deck, %d rows, the omens twist, two roads (%s)" % [l3.height, l3.headers.get("roads", "")])
	_check(rooms.size() == 1 and str(rooms[0]["kind"]) == "hold" and absf(float(rooms[0]["secs"]) - 15.0) < 0.01,
			"5-3: one sealed room, Hold the Glass, 15 s (%s)" % [rooms])
	if rooms.size() == 1:
		var r: Dictionary = rooms[0]
		var em: Vector2i = (named.get("Sister Ember", {}) as Dictionary).get("cell", Vector2i(-1, -1))
		var opens := []
		for x in [int(r["x0"]), int(r["x1"])]:
			for y in l3.height - 1:
				if not LevelData.is_solid(l3.tile(x, y)):
					opens.append(y)
		opens.sort()
		_check(em.x > int(r["x0"]) and em.x < int(r["x1"]) and _entities(l3, "paneguard").all(func(e): return int(e["cell"].x) > int(r["x0"]) and int(e["cell"].x) < int(r["x1"])),
				"5-3: Sister Ember and the three Paneguards hold the room")
		_check(not opens.is_empty() and opens[-1] - opens[0] >= 3 and int((r["rows"] as Array).size()) == 0,
				"5-3: the room is as tall as the level, in by one doorway and out by another lower (doorway rows %s)" % [opens])
	var low := 999
	for e in _entities(l3, "gutterwing") + _entities(l3, "bonebow"):
		low = mini(low, int(e["cell"].y))
	for z in l3.gusts:
		_check(int(z.get("y1", l3.height - 1)) < low, "5-3: the headwind %d-%d blows on the upper deck's rows only (to row %d; the lower deck's monsters from %d)" % [z["x0"], z["x1"], int(z.get("y1", l3.height - 1)), low])


func _test_pockets(id: String) -> void:
	## No air under glass cut off from the level: flood the air (every pane
	## whole; dawnglass, one-way stone and false stone open) from the start
	## and the void's bottom row, and any pocket it misses must touch no glass
	## (a break would drop him into a box the glass closes over again).
	var lv: RefCounted = _levels[id]
	var open := func(x: int, y: int) -> bool:
		var t: int = lv.tile(x, y)
		return not LevelData.is_solid(t) or LevelData.is_ledge(t) or t == LevelData.DAWNGLASS or t == LevelData.DAWN_ON or t == LevelData.FALSE_STONE
	# The void's bottom row counts as open to the level (a fall there is a
	# pit, never a place to stand).
	var seen := {}
	var todo: Array = [lv.start]
	seen[lv.start] = true
	for x in lv.width:
		var b := Vector2i(x, lv.height - 1)
		if open.call(b.x, b.y) and not seen.has(b):
			seen[b] = true
			todo.append(b)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= lv.width or n.y >= lv.height or seen.has(n) or not open.call(n.x, n.y):
				continue
			seen[n] = true
			todo.append(n)
	var shut := []
	for y in lv.height:
		for x in lv.width:
			if seen.has(Vector2i(x, y)) or not open.call(x, y):
				continue
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				if lv.tile(x + d.x, y + d.y) == LevelData.GLASS:
					shut.append(Vector2i(x, y))
					break
	_check(shut.is_empty(), "%s: no air under glass is cut off from the level (%s)" % [id, shut])


func _stone_top(lv: RefCounted, x: int, y: int) -> bool:
	var t: int = lv.tile(x, y)
	return LevelData.is_safe(t) and LevelData.is_solid(t) and not LevelData.is_solid(lv.tile(x, y - 1))


func _test_posts(id: String) -> void:
	## Every stretch of stone floor in a gust zone is somewhere to wait out a
	## gust: stopped at its downwind end, no input through a whole gust, he's
	## still on it (the edge brake at the void, glass.gd's stone brake at
	## glass) and no pane has taken strain.
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	if lv.gusts.is_empty():
		return
	var w := await _world_of(lv)
	var glass = w.features.module("glass")
	var pl: Node2D = w.player
	var n := 0
	var bad := []
	for z in glass.zones:
		var dir := int(z["dir"])
		for y in range(maxi(int(z.get("y0", 0)), 2), int(z.get("y1", lv.height - 1)) + 1):
			var x := int(z["x0"])
			while x <= int(z["x1"]):
				if not _stone_top(lv, x, y):
					x += 1
					continue
				var a := x
				while x <= int(z["x1"]) and _stone_top(lv, x, y):
					x += 1
				var b := x - 1
				var at := Vector2((b + 1) * TILE - 11.0 if dir > 0 else a * TILE + 11.0, y * TILE)
				w.features.on_respawn()
				_to_gust(w, glass, z, 0.25)
				pl.reset_at(at)
				pl.hp = pl.max_hp
				_ticks(w, 0.1)
				var strained := false
				for i in int((0.2 + float(_cm()["GUST_ON"]) + 0.3) / DT):
					_ticks(w, DT)
				for c in glass.panes:
					strained = strained or float(glass.panes[c]["strain"]) > 0.0 or glass.pane_state(c) != "whole"
				var ok: bool = pl.alive and pl.on_floor and floori((pl.position.y + 1.0) / TILE) == y \
						and pl.position.x > a * TILE - 10.0 and pl.position.x < (b + 1) * TILE + 10.0 and not strained
				n += 1
				if not ok:
					bad.append("x %d-%d row %d (ended at %.0f, %.0f%s)" % [a, b, y, pl.position.x, pl.position.y, ", a pane strained" if strained else ""])
	_check(n > 0 and bad.is_empty(), "%s: every stone stretch in a gust zone waits out a whole gust from its downwind end (%d stretches) %s" % [id, n, bad])
	await _free(w)


func _test_tail_jumps(id: String) -> void:
	## A running jump off any stone edge with a tailwind behind it, held
	## through a full gust, lands on the next floor with room to stop (spec:
	## a tailwind's landing 3 wide or backed by a wall; the owner's thumbs
	## hold right).
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	if lv.gusts.is_empty():
		return
	var w := await _world_of(lv)
	var glass = w.features.module("glass")
	var pl: Node2D = w.player
	var n := 0
	var bad := []
	for z in glass.zones:
		if int(z["dir"]) != 1:
			continue
		for y in range(2, lv.height):
			for x in range(int(z["x0"]), int(z["x1"]) + 1):
				if not (_stone_top(lv, x, y) and _stone_top(lv, x - 1, y) and not LevelData.is_solid(lv.tile(x + 1, y))):
					continue
				var far := -1
				for dx in range(2, 8):
					if LevelData.is_solid(lv.tile(x + dx, y)) and not LevelData.is_solid(lv.tile(x + dx, y - 1)):
						far = x + dx
						break
				if far < 0:
					continue
				var edge := (x + 1) * TILE
				w.features.on_respawn()
				_to_gust(w, glass, z, -0.3)      # full push from here, 1.2 s of it
				pl.reset_at(Vector2(edge - 2.2 * TILE, y * TILE))
				pl.hp = pl.max_hp
				_ticks(w, DT)
				var jumped := false
				var landed := false
				for i in int(2.0 / DT):
					if not jumped and pl.position.x >= edge - 3.0:
						jumped = true
					_ticks(w, DT, {"right": true, "jump": jumped})
					if jumped and pl.on_floor and pl.position.x > edge:
						landed = true
						break
					if pl.position.y > (y + 2) * TILE:
						break
				_ticks(w, 0.6)
				var ok: bool = landed and pl.on_floor and floori((pl.position.y + 1.0) / TILE) == y and pl.hp >= pl.max_hp - 0.5
				n += 1
				if not ok:
					bad.append("off x %d row %d (at %.0f, %.0f)" % [x, y, pl.position.x, pl.position.y])
	_check(bad.is_empty(), "%s: a running jump held through a full tailwind lands with room to stop (%d edges) %s" % [id, n, bad])
	await _free(w)


func _test_elite_ground(id: String) -> void:
	## Fights on stone: no monster the game could anoint (Elites.safe_for, its
	## kind's way) is judged on floor that holds glass or dawnglass (MA's
	## request would have safe_cell refuse it; until then, the levels).
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	var El = load("res://scripts/elites.gd")
	var w := await _world_of(lv, "dusk", true)
	var bad := []
	for en in w.enemies:
		var cell: Vector2i = en.spawn.get("cell", Vector2i(-1, -1))
		if cell.x < 0 or str(en.tier) == "dread" or en.get("copy") or en.get("boss_id") != null:
			continue
		var fl := bool(en.get("flier"))
		if not El.safe_for(lv, cell, str(en.kind), fl):
			continue
		var fy := cell.y + 1
		if fl or str(en.kind) == "bat" or str(en.kind) == "creepbone":
			for y in range(cell.y + 1, mini(cell.y + 7, lv.height)):
				if LevelData.is_solid(lv.tile(cell.x, y)):
					fy = y
					break
		for dx in range(-5, 6):
			var t: int = lv.tile(cell.x + dx, fy)
			if t == LevelData.GLASS or t == LevelData.DAWNGLASS or t == LevelData.DAWN_ON:
				bad.append("%s at %s" % [en.kind, cell])
				break
	_check(bad.is_empty(), "%s: no monster an elite could be stands judged on glass %s" % [id, bad])
	await _free(w)


func _first_tile(lv: RefCounted, t: int) -> Vector2i:
	for x in lv.width:
		for y in lv.height:
			if lv.tile(x, y) == t:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _floor_below(lv: RefCounted, c: Vector2i, rows: int) -> bool:
	for y in range(c.y + 1, mini(c.y + 1 + rows, lv.height)):
		if LevelData.is_safe(lv.tile(c.x, y)):
			return true
	return false


# ---------------------------------------------------------------- the bot

func _search(copy: RefCounted, opts := {}, keep := false) -> RefCounted:
	var s = ReachSearch.new()
	s.setup(copy, LevelData.cell_floor(copy.start), opts)
	s.run()
	if not keep:
		s.free_player()
	return s


func _stood_on_way(s, lv: RefCounted, way: Array) -> Array:
	## Where the bot's feet pass along its way: every tick of every step (each
	## step re-run from its node), as cells.
	var xs := []
	for i in range(1, way.size()):
		var a: Dictionary = s.nodes[way[i - 1]]
		var r: Dictionary = s.simulate(a, s.nodes[way[i]]["action"], true)
		var pl: Node2D = s.p
		pl.reset_at(a["pos"])
		s.bw.reset()
		if a["climb"]:
			pl.grab_vine(int(a["col"]), 1.0)
		else:
			pl.on_floor = true
		var prev := {}
		for held in r["pads"]:
			var pd: Dictionary = held.duplicate()
			for k in ["jump", "attack"]:
				var now: bool = held.get(k, false)
				pd[k + "_pressed"] = now and not prev.get(k, false)
				prev[k] = now
			pl.pad = pd
			pl.step(DT)
			s.bw.ftime += DT
			xs.append(Vector2i(floori(pl.position.x / TILE), floori((pl.position.y - 1.0) / TILE)))
	return xs


func _test_bot(id: String) -> void:
	var lv: RefCounted = _levels[id]
	var t0 := Time.get_ticks_msec()
	var life := (1.0 - _knob("glass_land")) / _knob("glass_stand")
	# Every pane its own surface, so a stay is judged pane by pane (the strain is per pane).
	# Every pane its own surface (the strain is per pane), and dawnglass keyed
	# by the lamp that lights it: a lamp in wind burns only its in-wind life.
	var timed := {}
	var lifes := {}
	var base: Dictionary = Reach.timed_cells(lv)
	var lamps := _entities(lv, "lantern")
	for c in base:
		if base[c] == "glass":
			timed[c] = "glass@%d,%d" % [c.x, c.y]
			lifes[timed[c]] = life
		elif base[c] == "dawn":
			var best := -1
			var bd := INF
			for i in lamps.size():
				var d := LevelData.cell_center(c).distance_to(LevelData.cell_floor(lamps[i]["cell"]) - Vector2(0, 33))
				if d < bd:
					bd = d
					best = i
			var lc: Vector2i = lamps[best]["cell"] if best >= 0 else Vector2i(-1, -1)
			var windy := false
			for z in lv.gusts:
				windy = windy or (lc.x >= int(z["x0"]) and lc.x <= int(z["x1"]))
			timed[c] = "dawn@%d,%d%s" % [lc.x, lc.y, " (in wind)" if windy else ""]
			lifes[timed[c]] = _wind_life() if windy else DAWN_LIFE
		else:
			timed[c] = base[c]
	var calm = _search(Reach.static_copy(lv), {"timed": timed}, true)
	_check(not calm.capped, "%s: the bot finishes under the cap (%d states)" % [id, calm.seen.size()])
	for g in calm.goals:
		_check(calm.found.has(g["what"]), "%s: the bot reaches the %s" % [id, g["what"]])
		if not calm.found.has(g["what"]):
			continue
		var dm: Dictionary = calm.found[g["what"]]["dmax"]
		for k in dm:
			var most := DWELL_SHARE * float(lifes.get(k, 999.0))
			_check(float(dm[k]) <= most + 0.001, "%s: the way to the %s never waits on %s (%.2f s, at most %.2f)" % [id, g["what"], k, dm[k], most])
	# Under a constant 120 px/s push in every zone.
	if not lv.gusts.is_empty():
		var gp = _search(Reach.static_copy(lv), {"push": true, "timed": timed})
		for g in gp.goals:
			_check(gp.found.has(g["what"]), "%s: the bot reaches the %s under a %d px/s gust" % [id, g["what"], int(Reach.GUST_PUSH)])
	# Stone every 14 tiles along the way over the void (spec §3.1 rule 3):
	# along the bot's winning path to the bell (or the arena), a column has
	# stone on the way if a stone top (the level's SAFE floor: never glass,
	# dawnglass or a mover) is within a hop up (3 rows) or a drop (6 rows) of
	# where its feet pass; a stretch longer than 14 without one fails if
	# anything under it is the void (glass pews over a stone floor are no
	# pit).
	var goal0 := "bell" if calm.found.has("bell") else "boss arena"
	var way: Array = calm.path_to(int(calm.found[goal0]["node"])) if calm.found.has(goal0) else []
	_check(not way.is_empty(), "%s: the bot's way to the %s" % [id, goal0])
	var feet := _stood_on_way(calm, lv, way)
	calm.free_player()
	var rows_at := {}              # column -> the rows his feet pass through there
	for c in feet:
		if not rows_at.has(c.x):
			rows_at[c.x] = {}
		rows_at[c.x][c.y] = true
	var low := {}                  # a column with stone on the way -> that stone's row
	for x in rows_at:
		for r in rows_at[x]:
			for y in range(maxi(int(r) - 2, 1), mini(int(r) + 8, lv.height)):
				if _stone_top(lv, x, y):
					low[x] = mini(int(low.get(x, 99)), y)
	var safe_x: Array = low.keys()
	safe_x.sort()
	var end_x: int = lv.width - 1
	for e in lv.entities:
		if e["kind"] == "bell" or e["kind"] == "boss":
			end_x = int(e["cell"].x)
	var worst := 0
	var at := 0
	for i in range(1, safe_x.size()):
		if int(safe_x[i]) > end_x:
			break
		var x0: int = safe_x[i - 1]
		var x1: int = safe_x[i]
		var gap := x1 - x0
		if gap <= worst:
			continue
		var r0 := mini(int(low[x0]), int(low[x1]))
		var over_void := false
		for x in range(x0 + 1, x1):
			var ground := false
			for y in range(r0, lv.height):
				var t: int = lv.tile(x, y)
				ground = ground or (LevelData.is_safe(t) and LevelData.is_solid(t))
			over_void = over_void or not ground
		if over_void or gap <= STONE_EVERY:
			worst = gap
			at = x0
	_check(worst <= STONE_EVERY, "%s: stone every %d tiles on the way over the void (the widest %d, from x %d)" % [id, STONE_EVERY, worst, at])
	# The wind along the bot's way to the bell: into a headwind no gap over 2
	# tiles, with 2 tiles of stone to wait on before a gap of 2; a tailwind's
	# landing 3 tiles wide or walled.
	var goal := "bell" if calm.found.has("bell") else "boss arena"
	if calm.found.has(goal):
		var path: Array = calm.path_to(int(calm.found[goal]["node"]))
		for i in range(1, path.size()):
			var a: Dictionary = calm.nodes[path[i - 1]]
			var b: Dictionary = calm.nodes[path[i]]
			if a["climb"] or b["climb"]:
				continue
			_wind_step(id, lv, a["pos"], b["pos"])
	# Every lamp reached before its dawnglass is needed: lamps reached with no
	# dawnglass light theirs; then search again with those lit (a chain).
	_lamp_order(id, lv)
	print("  %s: the W5 bot passes in %d ms" % [id, Time.get_ticks_msec() - t0])


func _wind_life() -> float:
	## A lamp in wind, lit at the worst moment of its zone's cycle: how long
	## it burns (DAWN_LIFE less gust_lamp for each gust before it's out).
	var cm := _cm()
	var cyc: float = cm["CYCLE"]
	var worst := DAWN_LIFE
	for step in 48:
		var n := cyc * (step + 1) / 48.0     # the first gust starts n s after the lighting
		var t := DAWN_LIFE
		var clock := 0.0
		while true:
			if t <= n:
				clock += t
				break
			t -= n
			clock += n
			t -= _knob("gust_lamp")
			if t <= 0.0:
				break
			n = cyc
		worst = minf(worst, clock)
	return worst


func _wind_step(id: String, lv: RefCounted, a: Vector2, b: Vector2) -> void:
	var ra := floori((a.y + 1.0) / TILE)
	var rb := floori((b.y + 1.0) / TILE)
	# The floor cells under him (standing at an edge, his middle can be past it).
	var xa := _floor_cell(lv, a.x, ra)
	var xb := _floor_cell(lv, b.x, rb)
	if ra != rb or xa < 0 or xb < 0 or absi(xb - xa) < 2:
		return
	var dir := 1 if xb > xa else -1
	# The void cells crossed on that row.
	var gap := 0
	var first := -1
	var x := xa + dir
	while x != xb:
		var t: int = lv.tile(x, ra)
		if not (LevelData.is_solid(t) or LevelData.is_ledge(t) or t == LevelData.DAWNGLASS):
			gap += 1
			if first < 0:
				first = x
		x += dir
	if gap == 0:
		return
	for z in lv.gusts:
		var inside := false
		for gx in [first, first + dir * (gap - 1)]:
			inside = inside or (gx >= int(z["x0"]) and gx <= int(z["x1"]))
		if not inside:
			continue
		if int(z["dir"]) == -dir:
			_check(gap <= 2, "%s: into the headwind at x %d, a gap of %d tiles (at most 2)" % [id, first, gap])
			if gap == 2:
				var wait_ok := LevelData.is_safe(lv.tile(first - dir, ra)) and LevelData.is_safe(lv.tile(first - 2 * dir, ra))
				_check(wait_ok, "%s: 2 tiles of stone to wait on before the 2-tile headwind gap at x %d" % [id, first])
		else:
			# The landing past the gap: 3 wide, or a wall at its far end.
			var lx := first + dir * gap
			var w := 0
			var walled := false
			while w < 6:
				var t2: int = lv.tile(lx + dir * w, ra)
				if not (LevelData.is_solid(t2) or LevelData.is_ledge(t2) or t2 == LevelData.DAWNGLASS):
					break
				if LevelData.is_solid(lv.tile(lx + dir * w, ra - 1)):
					walled = true
					break
				w += 1
			_check(w >= 3 or walled, "%s: the tailwind's landing at x %d is 3 tiles wide or walled (%d)" % [id, lx, w])


func _floor_cell(lv: RefCounted, x: float, row: int) -> int:
	## The floor tile under a body standing at x (its rect is 20 wide), or -1.
	for dx in [0.0, -9.0, 9.0]:
		var cx := floori((x + dx) / TILE)
		var t: int = lv.tile(cx, row)
		if LevelData.is_solid(t) or LevelData.is_ledge(t) or t == LevelData.DAWNGLASS:
			return cx
	return -1


func _lamp_order(id: String, lv: RefCounted) -> void:
	var panes := []
	for y in lv.height:
		for x in lv.width:
			if lv.tile(x, y) == LevelData.DAWNGLASS:
				panes.append(Vector2i(x, y))
	if panes.is_empty():
		return
	var lamps := {}
	for e in _entities(lv, "lantern"):
		var f := LevelData.cell_floor(e["cell"])
		# The post's own rect (level_features: 22 x LANTERN_H), grown by a
		# slash's reach (the sword lights it too).
		lamps["lamp %d,%d" % [e["cell"].x, e["cell"].y]] = {"p": f - Vector2(0, 33), "rect": Rect2(f.x - 11, f.y - 48, 22, 48).grow_individual(SLASH.x, SLASH.y, SLASH.x, 0)}
	var lit_panes := {}
	for round_i in 8:
		var copy = Reach.static_copy(lv, {"dawn": false})
		for c in lit_panes:
			copy.set_tile(c.x, c.y, LevelData.DAWN_ON)
		var rects := {}
		for k in lamps:
			rects[k] = lamps[k]["rect"]
		var s = _search(copy, {"touch": rects})
		var grew := false
		for c in panes:
			if lit_panes.has(c):
				continue
			for k in lamps:
				if s.touched.has(k) and LevelData.cell_center(c).distance_to(lamps[k]["p"]) <= LAMP_R:
					lit_panes[c] = true
					grew = true
					break
		if not grew:
			break
	var dark := panes.filter(func(c): return not lit_panes.has(c))
	_check(dark.is_empty(), "%s: every dawnglass pane's lamp is reached before the pane is needed (dark: %s)" % [id, dark])


# ---------------------------------------------------------------- 5-4's approach

# 5-4's golden route to the arena door (recorded 2026-09-26: the autoplay bot,
# no monsters, lamp by lamp, waiting out each gust on stone; no fall):
# [held mask, ticks], as routes/*.json keep them.
const ROUTE_54 := {"level": "5-4", "calling": "knight", "diff": "dusk", "ticks": 3700, "end_x": 4136,
	"runs": [
		[0, 1], [2, 36], [18, 73], [2, 20], [0, 11], [2, 36], [18, 73], [2, 20], [0, 11], [2, 10], [0, 285], [2, 36], [18, 73],
		[2, 20], [0, 11], [2, 36], [18, 73], [2, 20], [0, 11], [2, 36], [18, 8], [0, 47], [2, 1], [0, 1], [18, 72], [2, 53],
		[0, 18], [2, 36], [18, 73], [2, 26], [0, 11], [2, 36], [18, 73], [2, 20], [0, 11], [2, 36], [18, 73], [2, 20],
		[0, 11], [2, 36], [18, 15], [2, 47], [0, 9], [2, 36], [18, 73], [2, 20], [0, 11], [2, 36], [18, 15], [2, 124],
		[0, 185], [2, 1], [0, 1], [2, 2], [0, 1], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2],
		[0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2],
		[0, 2], [2, 2], [0, 1], [2, 2], [0, 2], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2], [0, 1], [2, 1],
		[0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2],
		[0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2],
		[0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2], [0, 2], [2, 3], [0, 2], [2, 2], [0, 2], [2, 3],
		[0, 2], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1],
		[0, 1], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2], [0, 1], [2, 1],
		[0, 1], [2, 2], [0, 2], [2, 2], [0, 1], [2, 1], [0, 1], [2, 1], [0, 1], [2, 2], [0, 2], [2, 2], [0, 2], [2, 2],
		[0, 2], [2, 2], [0, 2], [2, 1], [0, 1], [2, 1], [0, 1], [2, 1], [0, 2], [2, 1], [0, 4], [2, 22], [0, 18], [2, 114],
		[0, 18], [2, 36], [18, 73], [2, 20], [0, 275], [2, 36], [18, 73], [2, 20], [0, 11], [2, 36], [18, 73], [2, 20],
		[0, 11], [2, 36], [18, 73], [2, 20], [0, 7], [2, 27], [0, 11], [2, 36], [18, 73], [2, 20], [0, 11], [2, 36], [18, 73],
		[2, 14], [0, 11], [2, 36], [18, 15], [2, 40]]}


func _test_approach_route() -> void:
	## The golden routes, replayed as test_routes replays a whole level: no
	## monsters, the World's loop off, every tick driven here. 5-1..5-3
	## (routes/*.json) ring the bell, and 5-4's (ROUTE_54) reaches the nave,
	## all with no snuff and no fall: every timed crossing on the way made
	## clean. (5-4's is kept here, not in routes/*.json: test_routes asks
	## every route there for the bell, and a boss level's bell needs its boss.
	## W0's request: door-ending routes.)
	for id in IDS:
		# (5-4's lives in routes/5-4.json since the track B merge, with an
		# until goal test_routes replays too; ROUTE_54 is its copy.)
		var route: Dictionary = Route.read("res://tests/routes/%s.json" % id) if id != "5-4" or FileAccess.file_exists("res://tests/routes/5-4.json") else ROUTE_54
		_check(not route.is_empty(), "%s: its golden route is there" % id)
		if route.is_empty():
			continue
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		Route.prepare(game, route, lv)
		var w: Node2D = WorldScript.new()
		w.setup(lv, true)
		w.no_monsters = true
		w.paused = true
		root.add_child(w)
		await process_frame
		var masks := Route.decode(route["runs"])
		var falls := 0
		var fell_at := []
		var hp: float = w.player.hp
		for i in masks.size():
			w.test_pad = Route.pad_of(int(masks[i]))
			w._read_pad()
			w.tick(DT)
			if w.player.hp < hp - 0.5:
				falls += 1
				fell_at.append(floori(w.player.position.x / TILE))
			hp = w.player.hp
		var end_x := float(route["end_x"]) if route.has("end_x") else float((route.get("end", {}) as Dictionary).get("x", -1))
		if id == "5-4":
			var box: Dictionary = Arena.find(lv, LevelData.cell_floor(_entities(lv, "boss")[0]["cell"]))
			_check(w.player.position.x > float(box["left"]), "5-4's approach reaches the Saint's nave (x %.0f)" % w.player.position.x)
		else:
			_check(w.state == "clear", "%s: its route rings the bell" % id)
		_check(w.snuffs == 0 and w.player.alive and falls == 0, "%s: with no snuff (%d) and no fall (%d, at x %s)" % [id, w.snuffs, falls, fell_at])
		_check(masks.size() == int(route["ticks"]) and absf(w.player.position.x - end_x) <= 1.0,
				"%s: exactly where it was recorded (x %.0f, recorded %d)" % [id, w.player.position.x, int(end_x)])
		w.queue_free()
		await process_frame
