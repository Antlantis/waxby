extends SceneTree
## World 6, the Hushdeep (WL6): features/deep.gd and the levels 6-1 .. 6-4.
##
##     godot --headless --path game --script res://tests/test_w6.gd
##     WAXBY_FAST=1 ...        (skips the bot-path checks: stone every 14, the dwell rule)
##     WAXBY_RECORD=6-3:dusk,6-3:witching ...   records golden routes instead of testing
##                             (6-4: its approach, to the arena door: routes/6-4.json, with an until goal)
##     WAXBY_ONLY=chases ...   only the chase tests (laying out 6-3)
##
## The features, each in a World on a small level of its own: a float goes
## under float_sink's time (1.3 s on Dusk: the owner's feel lab) and never
## counts as firm ground; a toll stills the surface for still_time with its
## last still_tell cracking, holds a Brinejaw under it (quietly: no tell)
## and lengthens on a second toll; still water holds whoever is in it (a
## rider on a float who walks into a buoy, a wader in a shallow pool); a
## grasp tells grasp_tell before it rises, never from a stone spot outside
## its reach; a Hush zone dims him x hush_light and the dim floor holds with
## a Stillmaw's aura on top, and a lantern in it burns at half its radius; a
## Vigil candle relights for good as a lamp and a haven and pays its XP once
## (a swallowed one given back pays nothing and keeps its radius), a crown
## lights only with its ring, a candle that lights dawnglass is an anchor;
## the tide rises 10 tiles behind, rubber-bands, costs tide_touch with no
## shove and stalls, waits for a toll, ends at the end altar and resets on a
## snuff; the glow edges are at 0.30; outside W6 deep.gd plays no sound.
##
## The levels (each check skipped until its file exists): 6-4's width and
## altars, checkpoint gaps, 3-5 altars in a regular level; since Build 2 each
## regular level's cast (its roster: header) and threat (its threat:,
## ramping 6-1 to 6-3: tests/level_rules.gd) as declared, and 6-3's chases
## altar to altar; the headers; the teaching signs and the inscriptions; no
## wall sconces; the per-screen caps; 6-1's Hushlings; every grasp with a
## stone waiting spot just outside its reach; every buoy on the path reached
## from stone, a float or the still water of the buoy before; safe first;
## the star routes' one-tile floats; 6-4's Still Water as the spec draws it,
## with the finale stair's room clear. On the bot's winning path: stone
## every 14 tiles over deep water, and the dwell rule against the owner's
## numbers (a float's 1.3 s). With the bot: every sigil 1 needs its
## dawnglass, every sigil 3 its floats; 6-1's spur is the crown's alone;
## 6-2's secret room has a way out. 6-4's approach route reaches its door.
##
## The chases (6-3): every recorded route of 6-3 (one per difficulty) is
## replayed with the tide on and never touched; its run, turned into the
## spec's runners, beats the tide by 35% (the bot runner: +0.4 s a jump) and
## by 10% (the human runner: 0.85x speed, 0.9 s standing before each jump,
## 1 s at the first of each kind of obstacle new in the level) in both
## ranges. The margin is how much slower the runner's every second could be
## before the tide touched him. And the human runner, 10% slower still, is
## run against the terrain's own clocks (_terrain): no float he rides goes
## under, no still water or toll-lit pane opens under him, no grasp has its
## hands up where he is.

const LevelData := preload("res://scripts/level_data.gd")
const Rules := preload("res://tests/level_rules.gd")
const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
const Route := preload("res://scripts/route.gd")
const Movers := preload("res://scripts/movers.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Combat := preload("res://scripts/combat.gd")
const TILE := 32
const DT := 1.0 / 120.0
const DIFFS := ["dusk", "nightfall", "witching"]
const DEEP_PATH := "res://scripts/features/deep.gd"
const IDS := ["6-1", "6-2", "6-3", "6-4"]
# Spec §3.7.3 (6-4's width and altars; since Build 2 the regular levels'
# widths and altars are their own, held to the rules: tests/level_rules.gd;
# chases: how many tide runs, each altar to altar).
const SPEC := {
	"6-1": {"theme": "stillshore", "area": 28},
	"6-2": {"theme": "drownbell", "area": 29, "secret": "6-S"},
	"6-3": {"theme": "hushquiet", "area": 30, "chases": 2},
	"6-4": {"width": 196, "altars": [71, 147], "theme": "husheye", "area": 31, "boss": "hush"},   # (altars at 71 and 147: the door altar within 8 tiles of the arena, test_content, and W6 checkpoints 78 apart at most; spec x 63 and 139)
}
# The teaching signs left by the sign cut (the floats, buoys, grasps and
# candles teach themselves by deep.gd's first-time barks).
const SIGNS := {
	"6-1": ["Hushlings won't enter lantern light. Stay near one"],
	"6-2": ["Your shadow copies you a moment later. Keep moving"],
	"6-3": [],
	"6-4": ["Ring a sunken bell. Its peal lets you hit the Hush"],
}
const MAX_GAP := 78          # W6: tiles between checkpoints
const STONE_EVERY := 14
const DWELL := 0.6
# The runners of the chase test (spec §3.2, decisions.md).
const BOT_JUMP := 0.4
const BOT_NEEDS := 0.35
const HUMAN_SPEED := 0.85
const HUMAN_JUMP := 0.9
const HUMAN_NEW := 1.0
const HUMAN_NEEDS := 0.10
const ROUTE_DIR := "res://tests/routes"

var WorldScript: GDScript
var Deep: GDScript
var game: Node
var _passed := 0
var _failed := 0
var _skipped := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _skip(what: String) -> void:
	_skipped += 1
	print("  skipped: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_w6_save.json"
	game.reset()
	if not ResourceLoader.exists(DEEP_PATH):
		_skip("features/deep.gd missing")
		_finish()
		return
	Deep = load(DEEP_PATH)
	var rec := OS.get_environment("WAXBY_RECORD")
	if rec != "":
		await _record_all(rec)
		_finish()
		return
	if OS.get_environment("WAXBY_ONLY") == "chases":
		# While laying out 6-3: only the chase tests.
		await _test_chases()
		_finish()
		return
	_test_knobs()
	await _test_floats()
	await _test_still()
	await _test_lift()
	await _test_jaw_quiet()
	await _test_w2_quiet()
	await _test_grasp()
	await _test_hush()
	await _test_candles()
	await _test_candles2()
	await _test_candles_resume()
	await _test_tide()
	_test_edges()
	var regular := []
	for id in IDS:
		var path := "res://levels/%s.txt" % id
		if not FileAccess.file_exists(path):
			_skip("levels/%s.txt missing (WL6)" % id)
			continue
		var lv: RefCounted = LevelData.load_file(path)
		_test_layout(lv)
		if lv.boss == "":
			regular.append(lv)
	if regular.size() == 3:
		# Build 2: each regular level's threat within 10% of its threat:
		# header, 6-1 to 6-3 ramping (W6 had no threat check before).
		# The world's rules across its regular levels (tests/level_rules.gd
		# world_problems): each threat as declared, ramping (flat today, +1 a
		# step once re-cut); once re-cut, roles on every level, no two with the
		# same landmarks or altars, fodder falling, the X-3 mixing, no crowding.
		var tp := Rules.world_problems(regular)
		_check(tp.is_empty(), "6-1 to 6-3: the world's rules (threat, ramp, roles, variety) %s" % [tp])
	if FileAccess.file_exists("res://levels/6-4.txt"):
		_test_arena(LevelData.load_file("res://levels/6-4.txt"))
	if OS.get_environment("WAXBY_FAST") == "":
		for id in IDS:
			var path := "res://levels/%s.txt" % id
			if FileAccess.file_exists(path):
				_test_bot_path(LevelData.load_file(path))
				_test_gated(LevelData.load_file(path))
	else:
		print("  (the bot-path checks skipped here: WAXBY_FAST)")
	for id in IDS:
		if FileAccess.file_exists("res://levels/%s.txt" % id):
			await _test_monsters_settle(id)
	await _test_chases()
	await _test_routes_present()
	_finish()


func _test_candles_resume() -> void:
	## The rev5 review: "Continue from the altar" lost every Vigil candle (all
	## out again, each paying its XP a second time). The altar's snapshot
	## keeps the lit ones; resumed, they burn, paid, and the crown with them.
	if not FileAccess.file_exists("res://levels/6-1.txt"):
		return
	game.reset()
	game.new_hero("knight")
	game.data["difficulty"] = "dusk"
	var lv = LevelData.load_file("res://levels/6-1.txt")
	for k in ["start", "boss"]:
		if str(lv.story.get(k, "")) != "":
			game.mark_seen(str(lv.story[k]))
	var w: Node2D = WorldScript.new()
	w.setup(lv, false)
	w.no_monsters = true
	root.add_child(w)
	await process_frame
	w.paused = true
	var deep = w.features.module("deep")
	for c in deep.candles_list:
		if not c["crown"]:
			deep._light_candle(c)
	var before: Dictionary = deep.candles()
	w._light_altar(w.altars[1])
	var sus: Dictionary = game.suspended()
	w.queue_free()
	await process_frame
	var lv2 = LevelData.load_file("res://levels/6-1.txt")
	var w2: Node2D = WorldScript.new()
	w2.setup(lv2, true)
	w2.resume = sus
	w2.no_monsters = true
	root.add_child(w2)
	await process_frame
	w2.set_physics_process(false)
	var deep2 = w2.features.module("deep")
	var after: Dictionary = deep2.candles()
	var xp0 := int(game.hero()["xp"])
	for c in deep2.candles_list:
		deep2._light_candle(c)
	var crowned := false
	for c in deep2.candles_list:
		if c["crown"] and c["lit"]:
			crowned = true
	_check(int(before["lit"]) == int(before["total"]) and int(after["lit"]) == int(before["lit"]) and crowned,
			"6-1: continued from altar 2 its candles burn as they did, the crown too (%s -> %s)" % [before, after])
	_check(int(game.hero()["xp"]) == xp0, "and they pay nothing again (xp +%d)" % (int(game.hero()["xp"]) - xp0))
	w2.queue_free()
	await process_frame
	game.reset()


func _test_monsters_settle(id: String) -> void:
	## The level built with its monsters (Dusk): every one spawns and, after
	## a second, stands where it should: walkers on a floor (not sunk in the
	## lake), Brinejaws in a pool, a Lurecoil with a lake to swim, the
	## Stillmaws aloft; and the level's features built (floats, buoys,
	## grasps, candles, the tide's ranges).
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	var w := await _world(lv, "dusk", true)
	var placed := 0
	for e in lv.entities:
		if str(e["kind"]) in ["hushling", "stillmaw", "unwick", "lurecoil", "brinejaw", "skeleton", "hollow_helm", "bonebow",
				"lidlurk", "dripkin", "gutterwing", "creepbone", "rootling", "tickwind", "spurwheel", "glassmite", "gustling",
				"paneguard", "refractor", "rattlehound", "frostbuckle", "dread"]:
			placed += 1
		# The boss's X spawns its boss once its script is in (the Hush, BB's).
		if str(e["kind"]) == "boss" and w.boss != null:
			placed += 1
	_check(w.enemies.size() == placed, "%s: every placed monster spawns (%d of %d)" % [id, w.enemies.size(), placed])
	# Park Wick at the start so nothing is woken by him; wake them all.
	for e in w.enemies:
		e.active = true
	_run(w, 1.0)
	var sunk := []
	for e in w.enemies:
		var k := str(e.get("kind"))
		if not e.alive:
			continue
		if k in ["hushling", "unwick", "skeleton", "hollow_helm", "rootling", "tickwind", "spurwheel", "glassmite", "paneguard",
				"rattlehound", "frostbuckle", "lidlurk", "bonebow"]:
			var c := Vector2i(floori(e.position.x / TILE), floori((e.position.y + 1.0) / TILE))
			if not (LevelData.is_solid(lv.tile(c.x, c.y)) or LevelData.is_ledge(lv.tile(c.x, c.y))) or lv.is_deep(c.x, c.y - 1):
				sunk.append("%s at %s" % [k, c])
		elif k == "brinejaw":
			if not (float(e.get("pool_r")) > float(e.get("pool_l"))):
				sunk.append("brinejaw at %s has no pool" % e.position)
		elif k == "lurecoil":
			var water: Array = e.get("water")
			_check(water.size() >= 5, "%s: the Lurecoil has a lake to swim (%d deep columns)" % [id, water.size()])
	_check(sunk.is_empty(), "%s: every walker stands on a floor, every jaw in a pool %s" % [id, sunk])
	var deep = _deep(w)
	var want := {"float": 0, "buoy": 0, "grasp": 0, "vigil": 0}
	for e in lv.entities:
		if want.has(str(e["kind"])):
			want[str(e["kind"])] += 1
	_check(deep.floats.size() == want["float"] and deep.buoys.size() == want["buoy"] and deep.grasps.size() == want["grasp"]
			and deep.candles_list.size() == want["vigil"] and deep.chases.size() == lv.chase.size(),
			"%s: deep.gd built every float, buoy, grasp, candle and chase %s" % [id, want])
	await _free(w)


func _finish() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_w6_save.json" + suffix))
	print("test_w6: %d passed, %d failed%s" % [_passed, _failed, (", %d skipped" % _skipped) if _skipped > 0 else ""])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _mk(rows: Array, headers := "", id := "w6-test") -> RefCounted:
	## A small level (15 rows: short ones are padded with air above).
	var all: Array = rows.duplicate()
	while all.size() < 15:
		all.push_front("")
	var lv = LevelData.new()
	lv.id = id
	lv.world = 6
	lv.parse("title: test\ntheme: stillshore\narea: 28\n" + headers + "---\n" + "\n".join(all))
	return lv


func _world(lv: RefCounted, diff := "dusk", monsters := false) -> Node2D:
	game.reset()
	game.data["difficulty"] = diff
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = not monsters
	w.paused = true
	root.add_child(w)
	await process_frame
	return w


func _tick(w: Node2D, pad := {}) -> void:
	w.test_pad = pad
	w._read_pad()
	w.tick(DT)


func _run(w: Node2D, sec: float, pad := {}) -> void:
	for i in int(round(sec / DT)):
		_tick(w, pad)


func _free(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _deep(w: Node2D) -> Object:
	return w.features.module("deep")


func _knob(name: String, diff: String) -> float:
	var t: Dictionary = Deep.get_script_constant_map().get("DIFF_KNOBS", {})
	return float((t.get(name, {}) as Dictionary).get(diff, 0.0))


func _const(name: String):
	return Deep.get_script_constant_map().get(name)


# ---------------------------------------------------------------- the knobs

func _test_knobs() -> void:
	## The owner's feel lab (decisions.md): floats 1.3 s on Dusk; the spec's
	## knob table for the rest. Every knob has all three difficulties.
	var t: Dictionary = Deep.get_script_constant_map().get("DIFF_KNOBS", {})
	for k in ["float_sink", "still_time", "still_tell", "hush_light", "grasp_tell", "grasp_dmg", "tide_far", "tide_mid", "tide_near", "tide_touch"]:
		_check(t.has(k) and (t[k] as Dictionary).has_all(DIFFS), "deep.gd's knob %s has every difficulty" % k)
	var under: float = Movers.FLOAT_UNDER
	_check(absf(under / _knob("float_sink", "dusk") - 1.3) < 0.03, "a float goes under in about 1.3 s on Dusk (%.2f s)" % (under / _knob("float_sink", "dusk")))
	_check(_knob("float_sink", "nightfall") > _knob("float_sink", "dusk") and _knob("float_sink", "witching") > _knob("float_sink", "nightfall"), "floats sink faster on the harder difficulties")
	_check(_knob("still_time", "dusk") == 7.0 and _knob("still_time", "nightfall") == 6.0 and _knob("still_time", "witching") == 5.0, "still water holds 7 / 6 / 5 s")
	_check(_knob("still_tell", "dusk") == 1.5 and _knob("still_tell", "witching") == 1.5, "the last 1.5 s always cracks")
	_check(_knob("hush_light", "dusk") == 0.70 and _knob("hush_light", "nightfall") == 0.60 and _knob("hush_light", "witching") == 0.55, "Hush-zone light x0.70 / 0.60 / 0.55")
	_check(_knob("grasp_tell", "dusk") == 0.60 and _knob("grasp_tell", "nightfall") == 0.51 and _knob("grasp_tell", "witching") == 0.43, "grasp tells 0.60 / 0.51 / 0.43 s")
	_check(_knob("tide_mid", "dusk") == 140.0 and _knob("tide_mid", "nightfall") == 150.0 and _knob("tide_mid", "witching") == 160.0, "the tide's middle band 140 / 150 / 160")
	_check(_knob("tide_far", "dusk") == 200.0 and _knob("tide_near", "dusk") == 100.0, "the tide rubber-bands 200 / 140 / 100 on Dusk")
	_check(_knob("tide_touch", "dusk") == 0.20 and _knob("tide_touch", "witching") == 0.30, "a touch costs 20% on Dusk, 30% on Witching")
	for d in DIFFS:
		_check(_knob("tide_near", d) < 0.85 * PlayerScript.RUN_SPEED, "on %s a moving Wick (even at 0.85x) pulls away from a close tide" % d)
		# Every tell at least 0.35 s after the multiplier (0.30 on Witching).
		_check(_knob("grasp_tell", d) >= (0.30 if d == "witching" else 0.35), "the grasp tell on %s is long enough" % d)
	_check(float(_const("TOLL_R")) == 200.0 and float(_const("TOLL_LIGHT")) == 6.0 and float(_const("TOLL_COOL")) == 8.0, "a toll: light r 200 for 6 s, 8 s cooldown")
	_check(float(_const("TIDE_START")) == 10.0 and float(_const("TIDE_STALL")) == 2.0 and float(_const("TOLL_HOLD")) == 2.0, "the tide starts 10 tiles behind, stalls 2 s, a toll holds it 2 s")
	_check(Reach.STILL_REACH == 6, "the bot lays out the same 6 tiles of still water a toll makes")


# ---------------------------------------------------------------- floats

func _test_floats() -> void:
	## A float sinks under a rider and is under at 24 px; it rises unloaded;
	## it never counts as firm ground.
	for d in DIFFS:
		var lv := _mk([
			"....................",
			"..P.................",
			"########&&::########",
			"########::::########",
		])
		var w := await _world(lv, d)
		var deep = _deep(w)
		var m = deep.floats[0]
		var pl: Node2D = w.player
		_run(w, 0.3)
		var safe0: Vector2 = pl.last_safe
		pl.reset_at(Vector2(m.rect().get_center().x, m.rect().position.y))
		pl.last_safe = safe0
		_tick(w)
		var t := 0.0
		var kept := true
		# Under it goes; he's in the black water (it drowns) a breath before
		# the float's 24 px, when the water line reaches his middle.
		while m.present and pl.riding == m and t < 4.0:
			if pl.last_safe != safe0:
				kept = false
			_tick(w)
			t += DT
		var want: float = Movers.FLOAT_UNDER / _knob("float_sink", d)
		_check(t <= want + 0.03 and t >= want - 0.12, "%s: a loaded float takes him under in %.2f s (%.2f s)" % [d, want, t])
		_check(kept, "%s: a float is never firm ground (last_safe stays at the stone)" % d)
		await _free(w)
	# Unloaded, it comes back up.
	var lv2 := _mk(["....................", "..P.................", "########&&::########", "########::::########"])
	var w2 := await _world(lv2)
	var m2 = _deep(w2).floats[0]
	m2.depth = 20.0
	_run(w2, 0.5)
	_check(m2.depth <= 20.0 - 30.0 * 0.45 and m2.present, "an empty float rises at 30 px/s (depth %.1f after 0.5 s)" % m2.depth)
	await _free(w2)


# ---------------------------------------------------------------- still water

func _test_still() -> void:
	for d in DIFFS:
		var lv := _mk([
			"........................",
			"..P.....................",
			"#####J::::::::::#######",
			"#####:::f:::::::#######",
		])
		var w := await _world(lv, d, true)
		var deep = _deep(w)
		var pl: Node2D = w.player
		var b: Dictionary = deep.buoys[0]
		var cells: Array = Reach.still_cells(lv, b["cell"])
		# He walks into it from the lip: it tolls.
		var t := 0.0
		while float(b["rung"]) < 0.0 and t < 3.0:
			_tick(w, {"right": true})
			t += DT
		_check(float(b["rung"]) >= 0.0, "%s: walking into a buoy from its lip tolls it" % d)
		var all_still := true
		for c in cells:
			if lv.tile(c.x, c.y) != LevelData.STILL:
				all_still = false
		_check(all_still and cells.size() == 7, "%s: the toll stills the buoy's cell and 6 tiles on (%d cells)" % [d, cells.size()])
		_check(w.lit_at(LevelData.cell_center(b["cell"]) + Vector2(150, -20), 0.0, {"exclude_hero": true, "tag": "haven"}), "%s: the toll is a lamp and a haven out to its 200 px" % d)
		# Standing on still water over a Brinejaw: it doesn't leap.
		pl.reset_at(Vector2((b["cell"].x + 3.5) * TILE, b["cell"].y * TILE))
		var jaw: Node2D = null
		for e in w.enemies:
			if str(e.get("kind")) == "brinejaw":
				jaw = e
		var leapt := false
		for i in int(2.0 / DT):
			_tick(w)
			if jaw != null and jaw.get("state") == "leap":
				leapt = true
		_check(jaw != null and not leapt, "%s: a Brinejaw under still water doesn't leap at him" % d)
		# The crack tell in the last still_tell, then water again, and he falls in.
		var hold := _knob("still_time", d)
		var tell := _knob("still_tell", d)
		var c0: Vector2i = cells[3]
		while w.ftime < float(b["rung"]) + hold - tell - 0.05:
			_tick(w)
		_check(lv.tile(c0.x, c0.y) == LevelData.STILL and not deep._cracking.has(c0), "%s: still and quiet until its last %.1f s" % [d, tell])
		_run(w, 0.1)
		_check(deep._cracking.has(c0), "%s: then it cracks (the tell)" % d)
		var hp0: float = pl.hp
		while w.ftime < float(b["rung"]) + hold + 0.3:
			_tick(w)
		_check(lv.tile(c0.x, c0.y) == LevelData.WATER, "%s: after %.0f s it is water again" % [d, hold])
		_check(pl.hp < hp0 or not pl.alive or w.snuff_causes.has("water"), "%s: and whoever stood on it went in" % d)
		await _free(w)
	# A second toll (after its cooldown) on still water lengthens it; a
	# toll within the cooldown doesn't.
	var lv2 := _mk(["........................", "..P.....................", "#####J::::::::J:#######", "#####:::::::::::#######"])
	var w2 := await _world(lv2)
	var deep2 = _deep(w2)
	deep2._toll(deep2.buoys[0])
	_run(w2, 3.0)
	var c1 := Vector2i(12, 13)
	var until0: float = float(deep2.still.get(c1, 0.0))
	deep2._toll(deep2.buoys[1])
	_check(float(deep2.still.get(c1, 0.0)) > until0 + 2.5, "a toll over still water lengthens it (%.1f -> %.1f)" % [until0, float(deep2.still.get(c1, 0.0))])
	var r0: float = float(deep2.buoys[0]["rung"])
	deep2._toll(deep2.buoys[0])
	_check(float(deep2.buoys[0]["rung"]) == r0, "a buoy won't toll again inside its 8 s")
	await _free(w2)


# ---------------------------------------------------------------- still water holds him

func _test_lift() -> void:
	## Still water holds whoever is in it: a rider on a float that walks
	## into a buoy stands on the still water, not in it (and can stand there
	## or walk on); a wader in a shallow pool is lifted onto the sheet.
	for mode in ["walk on", "stand"]:
		var lv := _mk([
			"........................................",
			"..P.....................................",
			"##########::&&J::::::###################",
			"##########::::::::::::##################",
		])
		var w := await _world(lv)
		var deep = _deep(w)
		var pl: Node2D = w.player
		pl.reset_at(Vector2(9.5 * TILE, 13 * TILE))
		_run(w, 0.2)
		var hp0: float = pl.hp
		# Hop onto the float, then walk right into the buoy.
		pl.reset_at(Vector2(9.7 * TILE, 13 * TILE))
		var t := 0.0
		while float(deep.buoys[0]["rung"]) < 0.0 and t < 3.0:
			_tick(w, {"right": true, "jump": t < 0.25})
			t += DT
		var b: Dictionary = deep.buoys[0]
		_check(float(b["rung"]) >= 0.0, "%s: from a float he walks into the buoy (it tolls)" % mode)
		_tick(w, {"right": mode == "walk on"})
		var top := 13.0 * TILE
		_check(absf(pl.position.y - top) < 0.5 and pl.on_floor and pl.riding == null,
				"%s: the toll lifts him off the sinking float onto the still water (feet %.1f, the top %.0f)" % [mode, pl.position.y, top])
		if mode == "stand":
			_run(w, 1.5)
			_check(absf(pl.position.y - top) < 0.5 and pl.on_floor, "stand: he stands on the still water 1.5 s (feet %.1f)" % pl.position.y)
		t = 0.0
		while pl.position.x < 21.5 * TILE and t < 3.0:
			_tick(w, {"right": true})
			t += DT
		_check(pl.position.x >= 21.5 * TILE and pl.hp >= hp0 - 0.01 and not w.snuff_causes.has("water"),
				"%s: then he walks on to the stone, dry (x %.1f, hp %.0f of %.0f)" % [mode, pl.position.x / TILE, pl.hp, hp0])
		await _free(w)
	# A wader: a buoy in a shallow pool (water one row deep, stone under).
	var lv2 := _mk([
		"........................................",
		"..P...........J:::::::..................",
		"########################################",
		"########################################",
	])
	var w2 := await _world(lv2)
	var deep2 = _deep(w2)
	var pl2: Node2D = w2.player
	pl2.reset_at(Vector2(11.5 * TILE, 13 * TILE))
	_run(w2, 0.2)
	var on_top := 0
	var inside := 0
	var t2 := 0.0
	while pl2.position.x < 23.5 * TILE and t2 < 4.0:
		_tick(w2, {"right": true})
		t2 += DT
		var feet := Vector2i(floori(pl2.position.x / TILE), floori((pl2.position.y + 1.0) / TILE))
		if lv2.tile(feet.x, feet.y) == LevelData.STILL and pl2.on_floor:
			on_top += 1
		elif lv2.tile(feet.x, floori((pl2.position.y - 4.0) / TILE)) == LevelData.STILL:
			inside += 1
	_check(float(deep2.buoys[0]["rung"]) >= 0.0, "a wader tolls the buoy in a shallow pool")
	_check(on_top > 60 and inside <= int(0.12 / DT), "and walks on top of its still water, not through it (%d ticks on top, %d inside)" % [on_top, inside])
	await _free(w2)


func _test_jaw_quiet() -> void:
	## A Brinejaw under still water is held quietly: it never starts its tell
	## (whose splash would warn of a leap that can't come) while he stands
	## over it, and never leaps.
	var lv := _mk([
		"........................................",
		"..P.....................................",
		"##########J::::f::::::##################",
		"##########::::::::::::##################",
	])
	var w := await _world(lv, "dusk", true)
	var pl: Node2D = w.player
	pl.invuln = 999.0
	var jaw: Node2D = null
	for e in w.enemies:
		if str(e.get("kind")) == "brinejaw":
			jaw = e
	pl.reset_at(Vector2(9.5 * TILE, 13 * TILE))
	var tells := 0
	var leaps := 0
	var prev := ""
	for i in int(4.0 / DT):
		_tick(w, {"right": pl.position.x < 15.3 * TILE})
		var st := str(jaw.get("state")) if jaw != null else ""
		if st == "tell" and prev != "tell":
			tells += 1
		if st == "leap":
			leaps += 1
		prev = st
	_check(jaw != null and tells == 0 and leaps == 0, "a jaw under still water never tells or leaps while he stands over it (%d tells, %d leap ticks)" % [tells, leaps])
	await _free(w)


func _test_w2_quiet() -> void:
	## The dispatcher builds deep.gd for every level: outside the Hushdeep
	## it plays none of its sounds (its wading steps are W6's).
	var lv := _mk([
		"........................................",
		"..P.......:::::.........................",
		"########################################",
		"########################################",
	])
	lv.world = 2
	var w := await _world(lv)
	var deep = _deep(w)
	var pl: Node2D = w.player
	_run(w, 2.0, {"right": true})
	_check(not deep._w6 and not deep._stepped_hooked and not pl.stepped.is_connected(deep._on_step),
			"in a W2 level with shallow water, deep.gd hooks no wading steps (a W2 level plays no W6 sound)")
	await _free(w)
	var lv6 := _mk(["........................................", "..P.......:::::.........................",
			"########################################", "########################################"])
	var w6 := await _world(lv6)
	_run(w6, 1.0, {"right": true})
	_check(_deep(w6)._w6 and _deep(w6)._stepped_hooked, "in a W6 level it does")
	await _free(w6)


# ---------------------------------------------------------------- grasps

func _test_grasp() -> void:
	for d in DIFFS:
		var lv := _mk([
			"..............................",
			"..P...........................",
			"###########:H:################",
			"###########:::################",
		])
		var w := await _world(lv, d)
		var deep = _deep(w)
		var pl: Node2D = w.player
		var g: Dictionary = deep.grasps[0]
		# A stone spot 3 tiles short of it is outside its reach.
		pl.reset_at(Vector2((g["cell"].x - 3 + 0.5) * TILE, 13 * TILE))
		_run(w, 2.0)
		_check(g["state"] == "idle", "%s: a stone spot 3 tiles before a grasp never wakes it" % d)
		# Step in: the tell, then the hands.
		pl.reset_at(Vector2((g["cell"].x - 2 + 0.5) * TILE, 13 * TILE))
		_tick(w)
		_check(g["state"] == "tell", "%s: within 2 tiles across, it tells" % d)
		var t0: float = w.ftime
		pl.reset_at(Vector2((g["cell"].x - 4 + 0.5) * TILE, 13 * TILE))
		while g["state"] == "tell" and w.ftime - t0 < 2.0:
			_tick(w)
		_check(absf(w.ftime - t0 - _knob("grasp_tell", d)) <= DT * 1.5, "%s: the hands rise %.2f s after the ripples (%.2f)" % [d, _knob("grasp_tell", d), w.ftime - t0])
		_check(deep.grasp_rect(g).size == Vector2(28, 80), "%s: the hands are 28 x 80" % d)
		# Up: whoever is over it is hit and doused.
		pl.reset_at(Vector2(float(g["x"]), 13 * TILE))
		var hp0: float = pl.hp
		_tick(w)
		_check(pl.hp < hp0 and pl.has_status("douse"), "%s: the hands hit (and douse) whoever is over them" % d)
		_run(w, 1.2)
		_check(g["state"] == "cool", "%s: then they sink (%s)" % [d, g["state"]])
		await _free(w)


# ---------------------------------------------------------------- Hush zones

func _test_hush() -> void:
	var lv := _mk([
		"..............................",
		"..P...........L...............",
		"##############################",
		"##############################",
	], "hush: 8-20\n")
	var w := await _world(lv)
	var pl: Node2D = w.player
	var base: float = w.hero_light_radius()
	pl.reset_at(Vector2(12 * TILE, 13 * TILE))
	_run(w, 0.2)
	_check(w.features.in_hush_zone(pl.center()), "the header's columns are a Hush zone")
	var r: float = w.hero_light_radius()
	_check(absf(r - base * 0.70) <= 2.0, "in a Hush zone his light is x0.70 on Dusk (%.0f of %.0f)" % [r, base])
	# A Stillmaw's aura and a douse on top: the dim floor holds.
	for i in int(0.5 / DT):
		w.dim("stillmaw", 0.6, 0.2)
		w.dim("hushed", 0.7, 0.2)
		_tick(w)
	var floor_r: float = float(Combat.DIM_FLOOR["dusk"]) * base
	_check(w.hero_light_radius() >= floor_r - 2.0, "with a Stillmaw's aura on top the floor holds (%.0f >= %.0f)" % [w.hero_light_radius(), floor_r])
	# The lantern in the zone burns at half its radius; a toll wouldn't.
	var l: Dictionary = w.features.lanterns[0]
	w.features.light(l, true)
	_tick(w)
	var d = w.lights.dyn.get(int(l["id"])) if w.lights != null else null
	_check(d is Dictionary and float(d["r"]) <= 140.0 * 0.5 * 1.06, "a lantern inside a Hush zone burns at half its radius (%s)" % (d["r"] if d is Dictionary else "none"))
	pl.reset_at(Vector2(28 * TILE, 13 * TILE))
	_run(w, 0.3)
	_check(not w.features.in_hush_zone(pl.center()) and w.hero_light_radius() >= base - 2.0, "out of the zone his light comes back")
	await _free(w)
	# A lantern whose light reaches dawnglass is an anchor: the Stillmaw
	# never swallows it (the crossing it lights stays lit).
	var lv2 := _mk(["..............................", "..P.....L......................", "##########AAA##################", "##############################"])
	var w2 := await _world(lv2)
	var l2: Dictionary = w2.features.lanterns[0]
	_check(bool(l2.get("anchor", false)), "a lantern that lights dawnglass is an anchor")
	w2.features.light(l2, true)
	w2.features.put_out(l2)
	_check(bool(l2["lit"]), "and a Stillmaw's swallow leaves it lit")
	await _free(w2)


# ---------------------------------------------------------------- candles

func _test_candles() -> void:
	var lv := _mk([
		"..............................",
		"..P.....C.........C...........",
		"##############################",
		"##############################",
	], "", "6-1")
	var w := await _world(lv)
	var deep = _deep(w)
	var xp0 := int(game.hero().get("xp", 0))
	_check(deep.candles() == {"lit": 0, "total": 2}, "two Vigil candles, none lit")
	_run(w, 1.2, {"right": true})
	_check(deep.candles()["lit"] == 1, "walking past one relights it")
	var c: Dictionary = deep.candles_list[0]
	_check(w.lit_at((c["pos"] as Vector2) + Vector2(60, -30), 0.0, {"exclude_hero": true, "tag": "haven"}), "a relit candle is a haven out to 90 px")
	_check(w.lit_at((c["pos"] as Vector2) + Vector2(60, -30), 0.0, {"exclude_hero": true}), "and lamplight (it lights dawnglass)")
	_check(int(game.hero().get("xp", 0)) > xp0, "and pays a candle's XP")
	_check(w.result()["candles"] == {"lit": 1, "total": 2}, "the results count them (1/2)")
	_run(w, 3.0)
	_check(bool(c["lit"]), "it stays lit")
	await _free(w)


func _test_candles2() -> void:
	## A candle a Stillmaw swallowed and gave back (its choke: 10 s extra)
	## pays no XP again and keeps its radius; a crown candle takes no flame
	## of its own and lights (r CROWN_R) once its ring is lit, paying once;
	## a candle whose light reaches dawnglass is an anchor.
	var lv := _mk([
		"..............................",
		"..P.....C.........C.......C...",
		"##############################",
		"##############################",
	], "vigil_crown: 26:8,18\n", "6-1")
	var w := await _world(lv)
	var deep = _deep(w)
	var pl: Node2D = w.player
	var xp := func() -> int: return int(game.hero().get("xp", 0))
	var crown: Dictionary = deep.candles_list[2]
	_check(crown["crown"] and (crown["ring"] as Array).size() == 2, "the vigil_crown header makes the candle at 26 a crown over the two at 8 and 18")
	pl.reset_at(Vector2(26.5 * TILE, 13 * TILE))
	var x0: int = xp.call()
	_run(w, 0.3)
	_check(not crown["lit"] and xp.call() == x0, "a crown takes no flame of its own (touched, it stays out)")
	pl.reset_at(Vector2(8.5 * TILE, 13 * TILE))
	_run(w, 0.2)
	var c0: Dictionary = deep.candles_list[0]
	var x1: int = xp.call()
	_check(c0["lit"] and x1 > x0 and not crown["lit"], "the first of its ring lit, the crown waits")
	# Swallowed and given back: no XP again, the radius unchanged.
	var lamp: Dictionary = {}
	for l in w.features.lamps():
		if l["pos"] == c0["pos"]:
			lamp = l
	w.features.put_out(lamp)
	_check(not c0["lit"], "a Stillmaw swallows a candle")
	w.features.relight(lamp, 10.0)
	var r0 := float(w.lights.dyn[int(c0["light"])]["r"]) if w.lights != null and c0["light"] >= 0 else -1.0
	_check(c0["lit"] and xp.call() == x1 and absf(r0 - float(_const("CANDLE_R"))) < 0.01,
			"given back, it burns as before: no XP again, r %.0f (%.0f)" % [float(_const("CANDLE_R")), r0])
	w.features.put_out(lamp)
	pl.reset_at(Vector2(3.5 * TILE, 13 * TILE))
	_run(w, 0.1)
	pl.reset_at(Vector2(8.5 * TILE, 13 * TILE))
	_run(w, 0.2)
	_check(c0["lit"] and xp.call() == x1, "relit by hand after a swallow: no XP again")
	pl.reset_at(Vector2(18.5 * TILE, 13 * TILE))
	_run(w, 0.2)
	var x2: int = xp.call()
	_check(crown["lit"] and x2 > x1 + 1, "the whole ring lit, the crown lights (and pays, with the last of its ring)")
	var rc := float(w.lights.dyn[int(crown["light"])]["r"]) if w.lights != null and crown["light"] >= 0 else -1.0
	_check(absf(rc - float(_const("CROWN_R"))) < 0.01, "a crown burns at r %.0f (%.0f)" % [float(_const("CROWN_R")), rc])
	_check(deep.candles() == {"lit": 3, "total": 3}, "and the results count it (%s)" % deep.candles())
	await _free(w)
	# An anchor: a candle whose light is the dawnglass beside it.
	var lv2 := _mk(["..............................", "..P.....C......................", "#########AA####################",
			"##############################"], "", "6-4")
	var w2 := await _world(lv2)
	var ca: Dictionary = _deep(w2).candles_list[0]
	_check(ca["anchor"], "a candle whose light reaches dawnglass is an anchor")
	w2.player.reset_at(Vector2(8.5 * TILE, 13 * TILE))
	_run(w2, 0.2)
	var tagged := false
	for l in w2.features.lamps():
		if l["pos"] == ca["pos"]:
			tagged = str(l["tag"]).contains("anchor")
			w2.features.put_out(l)
	_check(tagged and ca["lit"], "its lamp is tagged anchor, and a Stillmaw's swallow leaves it lit")
	await _free(w2)


# ---------------------------------------------------------------- the tide

func _test_tide() -> void:
	for d in DIFFS:
		var lv := _mk([
			".".repeat(90),
			"..P..K" + ".".repeat(9) + "s" + ".".repeat(69) + "K" + ".".repeat(5),
			"#".repeat(90),
			"#".repeat(90),
		], "chase: 5-85\n", "6-3")
		var w := await _world(lv, d, true)
		var deep = _deep(w)
		var pl: Node2D = w.player
		_check(deep.tide_x() == -INF and w.features.tide_x() == -INF, "%s: no tide before he leaves the altar" % d)
		while deep.tide_x() == -INF and pl.position.x < 20 * TILE:
			_tick(w, {"right": true})
		var tx: float = deep.tide_x()
		_check(tx > -INF and absf(pl.position.x - tx - 10.0 * TILE) <= 8.0, "%s: leaving the altar, the tide rises 10 tiles behind (%.0f px)" % [d, pl.position.x - tx])
		var ch: Dictionary = deep.chases[0]
		# Rubber-banding: far, middle and near.
		for band in [[14.0, "tide_far"], [9.0, "tide_mid"], [3.0, "tide_near"]]:
			ch["x"] = pl.position.x - float(band[0]) * TILE
			ch["hold"] = -INF
			var x0: float = ch["x"]
			_tick(w)
			var v: float = (float(ch["x"]) - x0) / DT
			_check(absf(v - _knob(band[1], d)) < 1.0, "%s: %.0f tiles behind it comes at %.0f px/s (%.1f)" % [d, band[0], _knob(band[1], d), v])
		# It erases the Rattle it passes, for no XP.
		pl.reset_at(Vector2(30 * TILE + 16, 13 * TILE))
		ch["x"] = 17.0 * TILE
		var xp0 := int(game.hero().get("xp", 0))
		_tick(w)
		var rattle_gone := true
		for e in w.enemies:
			if str(e.get("kind")) == "skeleton" and e.alive:
				rattle_gone = false
		_check(rattle_gone and int(game.hero().get("xp", 0)) == xp0, "%s: the tide erases the monsters it reaches, for no XP" % d)
		# A touch: its share of life, no shove, 1 s untouchable, a 2 s stall.
		pl.invuln = 0.0
		pl.velocity = Vector2.ZERO
		var hp0: float = pl.hp
		ch["x"] = pl.rect().position.x + 4.0
		ch["hold"] = -INF
		_tick(w)
		_check(absf((hp0 - pl.hp) - _knob("tide_touch", d) * pl.max_hp) < 1.0, "%s: a touch costs %.0f%% of his life (%.1f)" % [d, _knob("tide_touch", d) * 100.0, hp0 - pl.hp])
		_check(absf(pl.velocity.x) < 1.0, "%s: with no shove" % d)
		_check(pl.invuln >= 0.99, "%s: then 1 s untouchable" % d)
		var xs: float = ch["x"]
		pl.position.x += 12.0 * TILE
		_run(w, 1.9)
		_check(absf(float(ch["x"]) - xs) < 0.01, "%s: and the tide stalls 2 s" % d)
		_run(w, 0.2)
		_check(float(ch["x"]) > xs, "%s: then comes on" % d)
		# A toll holds it 2 s.
		var b := {"cell": Vector2i(2, 13), "pos": LevelData.cell_center(Vector2i(2, 13)), "cool_until": -INF, "light": -1, "rung": -INF, "line": 13 * TILE + 8.0}
		deep.buoys.append(b)
		deep._toll(b)
		var xh: float = ch["x"]
		_run(w, 1.9)
		_check(absf(float(ch["x"]) - xh) < 0.01, "%s: a buoy's toll holds the tide 2 s" % d)
		deep.buoys.erase(b)
		# A snuff resets it; he leaves the altar again and it rises again.
		deep.on_respawn()
		_check(deep.tide_x() == -INF and ch["state"] == "idle", "%s: a snuff resets the tide" % d)
		# The end altar lit ends it.
		ch["state"] = "on"
		ch["x"] = pl.position.x - 12.0 * TILE
		pl.reset_at(Vector2(85 * TILE + 16, 13 * TILE))
		pl.invuln = 5.0
		_run(w, 0.3)
		var lit_end := false
		for a in w.altars:
			if (a["cell"] as Vector2i).x == 85:
				lit_end = bool(a["lit"])
		_check(ch["state"] == "done" and deep.tide_x() == -INF, "%s: lighting the end altar ends the chase (%s, altar lit %s, x %.0f, state %s)" % [d, ch["state"], lit_end, pl.position.x, w.state])
		await _free(w)


# ---------------------------------------------------------------- the glow edges

func _test_edges() -> void:
	## decisions.md: W6 floats, buoys and lips at alpha 0.30 on the glow layer.
	_check(is_equal_approx(float(_const("EDGE_A")), 0.30), "floats and buoys have glow edges at 0.30")
	var EL = load("res://scripts/edge_lines.gd")
	var Themes = load("res://scripts/themes/loader.gd")
	for id in SPEC:
		var th := str(SPEC[id]["theme"])
		var styles: Array = []
		if Themes.has_theme(th) and Themes.has_method("edges"):
			styles = Themes.edges(th)
		if styles.is_empty():
			styles = (EL.DEFAULTS as Dictionary).get(6, [])
		var lip := -1.0
		for s in styles:
			if str(s.get("what", "")) == "lip":
				lip = float(s.get("alpha", 0.0))
		_check(lip >= 0.30 - 1e-6, "%s (%s): every walkable lip has a glow edge at 0.30 or more (%.2f)" % [id, th, lip])


# ---------------------------------------------------------------- the levels

func _surface_safe(lv: RefCounted, x: int, y: int) -> bool:
	## A firm top at (x, y): last_safe records it and there's room above.
	return LevelData.is_safe(lv.tile(x, y)) and not LevelData.is_solid(lv.tile(x, y - 1))


func _test_layout(lv: RefCounted) -> void:
	var id: String = lv.id
	var sp: Dictionary = SPEC[id]
	_check(lv.errors.is_empty(), "%s parses (%s)" % [id, lv.errors])
	_check(Rules.height_ok(lv), "%s is %d-%d rows (%d)" % [id, Rules.HEIGHT_MIN, Rules.HEIGHT_MAX, lv.height])
	if sp.has("width"):
		_check(lv.width == int(sp["width"]), "%s is %d tiles (%d)" % [id, sp["width"], lv.width])
	_check(lv.world == 6 and lv.theme == sp["theme"] and lv.area == int(sp["area"]) and lv.music == "hushdeep", "%s: world 6, theme %s, area %d, music hushdeep" % [id, sp["theme"], sp["area"]])
	var altars := []
	var bell_x := -1
	for e in lv.entities:
		match e["kind"]:
			"altar":
				altars.append((e["cell"] as Vector2i).x)
			"bell":
				bell_x = (e["cell"] as Vector2i).x
	altars.sort()
	if sp.has("altars"):
		_check(altars == sp["altars"], "%s: altars at %s (%s)" % [id, sp["altars"], altars])
	else:
		var cp := Rules.checkpoint_problems(lv, MAX_GAP)
		_check(cp.is_empty(), "%s: 3-5 altars, an altar by every sealed door %s" % [id, cp])
		var rp := Rules.roster_problems(lv)
		_check(not Rules.roster_of(lv).is_empty() and rp.is_empty(), "%s holds the cast its roster: declares %s" % [id, rp])
		_check(Rules.declared_threat(lv) > 0.0, "%s declares its threat (%.1f per 100 tiles)" % [id, Rules.threat_of(lv)])
	# (Along the route: x in a strip, Rules.checkpoint_gaps.)
	var cg := Rules.checkpoint_gaps(lv)
	var marks: Array = cg["marks"]
	var worst: int = cg["worst"]
	_check(worst <= MAX_GAP, "%s: at most %d tiles between checkpoints (%s, worst %d)" % [id, MAX_GAP, marks, worst])
	# Headers.
	_check(str(lv.story.get("start", "")) == "beat_%s" % id.replace("-", "_"), "%s: its story beat" % id)
	if sp.has("boss"):
		_check(lv.boss == "hush" and lv.boss_music == "hush_final" and lv.story.get("boss", "") == "boss_6_before" and lv.story.get("end", "") == "boss_6_after",
				"6-4: boss hush, boss_music hush_final, boss_6_before / boss_6_after")
	else:
		_check(bell_x >= 0 and not lv.dread.is_empty(), "%s: a bell and a Dread" % id)
	_check(lv.secret == str(sp.get("secret", "")), "%s: secret header '%s'" % [id, sp.get("secret", "")])
	var chase: Array = []
	for r in lv.chase:
		chase.append([int(r["x0"]), int(r["x1"])])
	_check(chase.size() == int(sp.get("chases", 0)), "%s: %d chase ranges (%s)" % [id, sp.get("chases", 0), chase])
	for r in chase:
		_check(altars.has(r[0]) and altars.has(r[1]), "%s: each chase runs altar to altar (%s)" % [id, r])
	# Signs: the teaching signs and the inscription (the Hush's, lowercase),
	# and nothing else.
	var hints := Array(lv.hints)
	for s in SIGNS[id]:
		_check(hints.has(s), "%s has the sign '%s'" % [id, s])
	var Story = load("res://scripts/story.gd")
	var ins: Array = (Story.get_script_constant_map().get("INSCRIPTIONS", {}) as Dictionary).get(id, [])
	for s in ins:
		_check(hints.has(s), "%s carries its inscription '%s'" % [id, s])
	_check(ins.size() == 1 and hints.size() == SIGNS[id].size() + ins.size(), "%s: its signs and no others %s" % [id, hints])
	_check(lv.count("sconce") == 0, "%s: no wall sconces (in W6 `c` gives no light)" % id)
	_check(lv.count("sign") == hints.size(), "%s: a sign for every hint" % id)
	# Every Hollin how-to the level fires exists (the barks are story.gd's).
	# The caps per 27-tile window (a taller level's the views over the rows
	# he stands on in it: Rules.screen_rows).
	var windows := []
	for x0 in range(0, maxi(lv.width - 26, 1)):
		for ys in Rules.screen_rows(lv, x0, 27):
			windows.append(Vector3i(x0, ys.x, ys.y))
	for win in windows:
		var x0: int = win.x
		var n := {"float": 0, "buoy": 0, "grasp": 0, "light": 0, "awake": 0}
		for e in lv.entities:
			var ex: int = (e["cell"] as Vector2i).x
			if ex < x0 or ex >= x0 + 27 or not Rules.in_rows(e["cell"], Vector2i(win.y, win.z)):
				continue
			var k := str(e["kind"])
			if n.has(k):
				n[k] += 1
			if k in ["vigil", "lantern", "buoy"]:
				n["light"] += 1
			if k in ["skeleton", "bonebow", "hollow_helm", "gutterwing", "dripkin", "brinejaw", "lidlurk", "dread",
					"hushling", "stillmaw", "unwick", "lurecoil", "rootling", "creepbone", "tickwind", "spurwheel",
					"glassmite", "gustling", "paneguard", "refractor", "rattlehound", "frostbuckle"]:
				n["awake"] += 1
		if n["float"] > 8 or n["buoy"] > 3 or n["grasp"] > 4 or n["light"] > 14 or n["awake"] > 12:
			_check(false, "%s: the per-screen caps at x %d (%s)" % [id, x0, n])
			break
	# Hushlings (spec: at most 10 in 6-1, in packs of 3 or fewer on Dusk).
	var hush := []
	for e in lv.entities:
		if e["kind"] == "hushling":
			hush.append(e["cell"])
	if id == "6-1":
		_check(hush.size() <= 10, "6-1: at most 10 Hushlings (%d)" % hush.size())
	for c in hush:
		var pack := 0
		for c2 in hush:
			if c2.y == c.y and absi(c2.x - c.x) <= 4:
				pack += 1
		_check(pack <= 3, "%s: the Hushlings round %s are a pack of %d (at most 3)" % [id, c, pack])
	# Every grasp beside the path has a stone waiting spot outside its reach,
	# just before it (never a float): a place to stand on stone whose centre
	# is outside the trigger and within a step (40 px) of it, to watch the
	# hands' cycle from.
	var reach := float(_const("GRASP_REACH"))
	for e in lv.entities:
		if e["kind"] != "grasp":
			continue
		var g: Vector2i = e["cell"]
		var gx := (g.x + 0.5) * TILE
		var spot := false
		for sx in range(g.x - 6, g.x):
			if not _surface_safe(lv, sx, g.y):
				continue
			var lo := sx * TILE - 9.0
			var hi := (sx + 1) * TILE + 9.0
			if hi >= gx - reach - 40.0 and lo < gx - reach:
				spot = true
		_check(spot, "%s: the grasp at %s has a stone waiting spot just outside its reach (within 40 px of it)" % [id, g])
	# Every buoy is reached by walking: from stone, a float, or the still
	# water of a buoy before it (the route director and a human's thumbs).
	var still_of := {}
	for e in lv.entities:
		if e["kind"] == "buoy":
			for c in Reach.still_cells(lv, e["cell"]):
				if not still_of.has(c):
					still_of[c] = []
				(still_of[c] as Array).append(e["cell"])
	var float_cells := {}
	for e in lv.entities:
		if e["kind"] == "float":
			for k in int(e.get("length", 1)):
				float_cells[Vector2i((e["cell"] as Vector2i).x + k, (e["cell"] as Vector2i).y)] = true
	for e in lv.entities:
		if e["kind"] != "buoy":
			continue
		var b: Vector2i = e["cell"]
		var left := Vector2i(b.x - 1, b.y)
		var by_other := false
		for o in still_of.get(left, []):
			if o != b:
				by_other = true
		var ok: bool = _surface_safe(lv, left.x, left.y) or float_cells.has(left) or by_other or (not lv.is_deep(b.x, b.y))
		_check(ok, "%s: the buoy at %s is walked into (stone, a float or still water beside it)" % [id, b])
	# The star route: sigil 3 over one-tile floats (W6's "tight").
	if id != "6-4":
		var s3 := Vector2i(-1, -1)
		for e in lv.entities:
			if e["kind"] == "sigil" and int(e["index"]) == 2:
				s3 = e["cell"]
		var tight := false
		for e in lv.entities:
			if e["kind"] == "float" and int(e.get("length", 1)) == 1 and absi((e["cell"] as Vector2i).x - s3.x) <= 5:
				tight = true
		_check(s3.x >= 0 and tight, "%s: sigil 3 at the end of a star route of one-tile floats" % id)
	_check(lv.count("sigil") == 3, "%s: three sigils" % id)
	# Safe first (spec §0.3): the first float line over shallow water, the
	# first buoy in a shallow pool, each taught alone (by deep.gd's first-time
	# barks since the sign cut).
	if id == "6-1":
		var first_f := Vector2i(9999, 0)
		var first_b := Vector2i(9999, 0)
		for e in lv.entities:
			var c: Vector2i = e["cell"]
			if e["kind"] == "float" and c.x < first_f.x:
				first_f = c
			if e["kind"] == "buoy" and c.x < first_b.x:
				first_b = c
		_check(not lv.is_deep(first_f.x, first_f.y), "6-1: the first float is over shallow water")
		_check(not lv.is_deep(first_b.x, first_b.y), "6-1: the first buoy stands in a shallow pool")
		_check(_threat_free(lv, first_f.x, 8) and _threat_free(lv, first_b.x, 8), "6-1: no monster within 8 tiles of either")
		_check(int(lv.hush_cols.size()) >= 2, "6-1: two Hush zones (taught, then twisted)")
	if id == "6-2":
		var first_g := Vector2i(9999, 0)
		for e in lv.entities:
			if e["kind"] == "grasp" and (e["cell"] as Vector2i).x < first_g.x:
				first_g = e["cell"]
		_check(first_g.x < 9999 and _threat_free(lv, first_g.x, 8), "6-2: the first grasp is taught alone")


func _threat_free(lv: RefCounted, x: int, within: int) -> bool:
	for e in lv.entities:
		var c: Vector2i = e["cell"]
		if absi(c.x - x) <= within and str(e["kind"]) in ["skeleton", "bonebow", "hollow_helm", "gutterwing", "dripkin", "brinejaw",
				"lidlurk", "hushling", "stillmaw", "unwick", "lurecoil", "dread"]:
			return false
	return true


func _test_arena(lv: RefCounted) -> void:
	## 6-4's Still Water (spec §3.7.4), as drawn: five islets (tops at row 11)
	## with 2-tile gaps of deep water, perches at row 8 (one over the entry
	## islet), two tall stones at rows 9-10, the four sunken bells, the Hush;
	## and the finale's stair (ring k: 3 tiles centred on column 5 + 5k, top
	## at row 10 - k) and the Eye (columns 37-40, rows 2-4) with room kept.
	const DRAW := [
		"############################################",
		"############################################",
		"##........................................##",
		"##........................................##",
		"##........................................##",
		"##........................................##",
		"##........................................##",
		"##........................................##",
		"..===...====..........====..........====..##",
		"............##...................##.......##",
		"....+..........+.....X........+.........+.##",
		"#######..#########..#######..########..#####",
		"#######::#########::#######::########::#####",
		"#######::#########::#######::########::#####",
		"#######::#########::#######::########::#####",
	]
	var x0: int = int(lv.width) - 44
	_check(x0 == 152, "6-4: the Still Water starts at x 152 (%d)" % x0)
	var same := true
	for y in 15:
		for x in 44:
			var ch: String = DRAW[y][x]
			var t: int = lv.tile(x0 + x, y)
			var want := LevelData.AIR
			match ch:
				"#":
					want = LevelData.STONE
				"=":
					want = LevelData.LEDGE
				":":
					want = LevelData.WATER
			if t != want:
				same = false
				print("  arena (%d,%d): %d, not %d" % [x, y, t, want])
	_check(same, "6-4: the arena's tiles are the spec's drawing")
	var anchors := []
	var boss := Vector2i(-1, -1)
	for e in lv.entities:
		var c: Vector2i = e["cell"]
		if e["kind"] == "anchor":
			anchors.append(Vector2i(c.x - x0, c.y))
		elif e["kind"] == "boss":
			boss = Vector2i(c.x - x0, c.y)
	anchors.sort()
	_check(anchors == [Vector2i(4, 10), Vector2i(15, 10), Vector2i(30, 10), Vector2i(40, 10)], "6-4: the sunken bells at (4,10) (15,10) (30,10) (40,10) (%s)" % [anchors])
	_check(boss == Vector2i(21, 10), "6-4: the Hush at (21,10) (%s)" % boss)
	for k in range(1, 7):
		var cx := 5 + 5 * k
		var row := 10 - k
		var clear := true
		for x in range(cx - 1, cx + 2):
			if LevelData.is_solid(lv.tile(x0 + x, row)) or LevelData.is_solid(lv.tile(x0 + x, row - 1)):
				clear = false
		_check(clear, "6-4: finale ring %d (columns %d-%d, row %d) has its room" % [k, cx - 1, cx + 1, row])
	var eye := true
	for y in range(2, 5):
		for x in range(37, 41):
			if lv.tile(x0 + x, y) != LevelData.AIR:
				eye = false
	_check(eye, "6-4: the Eye's place (columns 37-40, rows 2-4) is open")
	# High ground within 5 tiles of every islet (the Deep Quiet).
	for islet in [[0, 6], [9, 17], [20, 26], [29, 36], [39, 43]]:
		var near := false
		for x in range(int(islet[0]) - 5, int(islet[1]) + 6):
			if x >= 0 and x < 44 and (lv.tile(x0 + x, 8) == LevelData.LEDGE or lv.tile(x0 + x, 9) == LevelData.STONE):
				near = true
		_check(near, "6-4: a perch within 5 tiles of the islet at %s" % [islet])
	# Sigil 3 on the middle perch, the arena's sign on the entry islet.
	var s3_ok := false
	for e in lv.entities:
		if e["kind"] == "sigil" and int(e["index"]) == 2:
			var c: Vector2i = e["cell"]
			s3_ok = c.x - x0 >= 22 and c.x - x0 <= 25 and c.y == 7
	_check(s3_ok, "6-4: sigil 3 on the middle perch")


func _test_bot_path(lv: RefCounted) -> void:
	## On the bot's winning path to the bell (or the arena): a firm stone
	## at least every 14 tiles over deep water, and the dwell rule against the
	## owner's numbers (a float 1.3 s, still water 7 s, glass 1.1 s).
	var t0 := Time.get_ticks_msec()
	var s = ReachSearch.new()
	var timed := Reach.timed_cells(lv)
	s.setup(Reach.static_copy(lv), LevelData.cell_floor(lv.start), {"timed": timed, "goals": _final_goal(lv)})
	s.run()
	var goal: Dictionary = _final_goal(lv)[0]
	_check(s.found.has(goal["what"]), "%s: the bot's path reaches the %s" % [lv.id, goal["what"]])
	if not s.found.has(goal["what"]):
		s.free_player()
		return
	var hit: Dictionary = s.found[goal["what"]]
	var path: Array = s.path_to(int(hit["node"]))
	# Firm stone (a tile last_safe records, with room over it) within reach of
	# the path (3 tiles across, 3 rows up or down) at least every 14 tiles:
	# the bot may leap past a root knot, a person may stop on it.
	var last_right := float(lv.start.x)
	var worst := 0.0
	var where := 0.0
	for idx in path:
		var n: Dictionary = s.nodes[idx]
		var p: Vector2 = n["pos"]
		var tx := floori(p.x / TILE)
		var ty := floori((p.y + 1.0) / TILE)
		var lo := INF
		var hi := -INF
		for cx in range(tx - 3, tx + 4):
			for cy in range(ty - 3, ty + 4):
				if _surface_safe(lv, cx, cy):
					lo = minf(lo, cx)
					hi = maxf(hi, cx)
		if hi > -INF:
			if lo - last_right > worst:
				worst = lo - last_right
				where = tx
			last_right = maxf(last_right, hi)
	_check(worst <= STONE_EVERY, "%s: stone within reach at least every %d tiles along the bot's path (worst %.0f, to x %.0f)" % [lv.id, STONE_EVERY, worst, where])
	var life := {"float": Movers.FLOAT_UNDER / _knob("float_sink", "dusk"), "still": _knob("still_time", "dusk"), "glass": 1.1,
			"rotten": 1.4, "dawn": 6.0}
	var dm: Dictionary = hit["dmax"]
	for k in dm:
		var most: float = DWELL * float(life.get(k, 999.0))
		_check(float(dm[k]) <= most + 0.001, "%s: the way never waits on %s (%.2f s, at most %.2f)" % [lv.id, k, dm[k], most])
	s.free_player()
	print("  %s: the bot's path (%d states, %d ms)" % [lv.id, s.seen.size(), Time.get_ticks_msec() - t0])


func _reaches(copy: RefCounted, start: Vector2, what: String) -> bool:
	## Does the bot reach the goal named what from start on this copy?
	var goals := []
	for g in Reach.goals_of(copy):
		if g["what"] == what:
			goals.append(g)
	var s = ReachSearch.new()
	s.setup(copy, start, {"goals": goals})
	s.run()
	var ok: bool = s.found.has(what)
	s.free_player()
	return ok


func _altar_before(lv: RefCounted, x: int) -> Vector2:
	## The floor of the last altar before column x (or the start).
	var best: Vector2i = lv.start
	for e in lv.entities:
		var c: Vector2i = e["cell"]
		if e["kind"] == "altar" and c.x < x and c.x > best.x:
			best = c
	return LevelData.cell_floor(best)


func _test_gated(lv: RefCounted) -> void:
	## The sigils that are someone's reward, proven gated with the bot: W6's
	## sigil 1 needs its dawnglass (6-1's crown spur, 6-2's toll-lit stair,
	## 6-3's buoy detour), sigil 3 its one-tile floats (the star routes:
	## never reached from stone or still water); 6-1's spur is the crown's
	## alone; 6-2's secret room has a way out without its still water.
	var id: String = lv.id
	if id == "6-4":
		return
	var sig := {}
	for e in lv.entities:
		if e["kind"] == "sigil":
			sig[int(e["index"])] = e["cell"]
	if sig.has(0):
		var from := _altar_before(lv, (sig[0] as Vector2i).x)
		_check(not _reaches(Reach.static_copy(lv, {"dawn": false}), from, "sigil 1"), "%s: sigil 1 needs its dawnglass (unreachable with every pane dark)" % id)
	if sig.has(2):
		var copy = Reach.static_copy(lv)
		for e in lv.entities:
			if e["kind"] == "float":
				for k in int(e.get("length", 1)):
					copy.set_tile((e["cell"] as Vector2i).x + k, (e["cell"] as Vector2i).y, LevelData.WATER)
		var from3 := _altar_before(lv, (sig[2] as Vector2i).x)
		_check(not _reaches(copy, from3, "sigil 3"), "%s: sigil 3 needs its floats (unreachable from stone or still water)" % id)
	if id == "6-1":
		# The crown: every pane of the spur is its light's alone.
		var hdr := str(lv.headers.get("vigil_crown", ""))
		var bits := hdr.split(":")
		_check(bits.size() == 2 and bits[1].split(",").size() == 5, "6-1: the crown waits for the five candles (%s)" % hdr)
		if bits.size() == 2:
			var crown_x := int(bits[0])
			var only := true
			var near := 0
			for y in lv.height:
				for x in lv.width:
					if lv.tile(x, y) != LevelData.DAWNGLASS or absi(x - crown_x) > 6:
						continue
					near += 1
					var pc := LevelData.cell_center(Vector2i(x, y))
					for e in lv.entities:
						if e["kind"] == "vigil" and (e["cell"] as Vector2i).x != crown_x:
							if pc.distance_to(LevelData.cell_floor(e["cell"]) - Vector2(0, 30)) <= float(_const("CANDLE_R")) + 8.0:
								only = false
			_check(near >= 2 and only, "6-1: the spur's %d panes are lit by the crown alone" % near)
	if id == "6-2":
		for e in lv.entities:
			if e["kind"] == "silver_bell":
				_check(_reaches(Reach.static_copy(lv, {"still": false}), LevelData.cell_floor(e["cell"]), "bell"),
						"6-2: the silver bell's room has a way out when its still water is gone")


func _final_goal(lv: RefCounted) -> Array:
	for g in Reach.goals_of(lv):
		if g["what"] == "bell" or g["what"] == "boss arena":
			return [g]
	return []


# ---------------------------------------------------------------- the chases

func _test_chases() -> void:
	if not FileAccess.file_exists("res://levels/6-3.txt"):
		_skip("levels/6-3.txt missing: the chase tests wait")
		return
	var lv0 = LevelData.load_file("res://levels/6-3.txt")
	for d in DIFFS:
		var path := _route_path("6-3", d)
		if not FileAccess.file_exists(path):
			_check(false, "6-3: a golden route on %s (%s)" % [d, path.get_file()])
			continue
		var route := Route.read(path)
		var tr: Dictionary = await _replay(lv0, route, true)
		_check(tr["clear"] and tr["snuffs"] == 0, "6-3 (%s): the route rings the bell with no snuff" % d)
		_check(tr["tide_hits"] == 0, "6-3 (%s): the tide never touches the route's run (%d)" % [d, tr["tide_hits"]])
		for ci in lv0.chase.size():
			var ev: Dictionary = _chase_events(tr, ci)
			if ev.is_empty():
				_check(false, "6-3 (%s): the route runs chase %d" % [d, ci + 1])
				continue
			if OS.get_environment("WAXBY_CHASE_DEBUG") != "":
				var xs2: PackedFloat32Array = ev["x"]
				var line := ""
				for i in range(0, xs2.size(), 30):
					line += "%.0f " % (xs2[i] / TILE)
				print("    chase %d x every 0.25 s: %s | jumps %s tolls %s kinds %s" % [ci + 1, line, ev["jumps"], ev["tolls"], ev["kinds"]])
			var bot := _margin(ev, d, false)
			var hum := _margin(ev, d, true)
			var terrain := _terrain(ev, d, 1.0 + HUMAN_NEEDS)
			print("  6-3 (%s) chase %d: %.1f s, %d jumps needed, meets %s (new in the level: %s), %d tolls; the bot runner by %.0f%%, the human runner by %.0f%%%s"
					% [d, ci + 1, (ev["x"] as PackedFloat32Array).size() * DT, (ev["jumps"] as Array).size(), ev["met"], (ev["kinds"] as Dictionary).keys(),
					(ev["tolls"] as Array).size(), bot * 100.0, hum * 100.0, "" if terrain == "" else " (" + terrain + ")"])
			_check(bot >= BOT_NEEDS, "6-3 (%s) chase %d: the bot runner beats the tide by %.0f%% (%.0f%%)" % [d, ci + 1, BOT_NEEDS * 100.0, bot * 100.0])
			_check(hum >= HUMAN_NEEDS, "6-3 (%s) chase %d: the human runner beats it by %.0f%% (%.0f%%)" % [d, ci + 1, HUMAN_NEEDS * 100.0, hum * 100.0])
			_check(terrain == "", "6-3 (%s) chase %d: the human runner, %.0f%% slower still, makes every float, still water, lit pane and grasp in time%s"
					% [d, ci + 1, HUMAN_NEEDS * 100.0, "" if terrain == "" else " (" + terrain + ")"])


func _route_path(id: String, d: String) -> String:
	return "%s/%s.json" % [ROUTE_DIR, id if d == "dusk" else "%s-%s" % [id, d]]


func _approach_path(id: String) -> String:
	## A boss level's approach, to its arena door: routes/<id>.json with an
	## "until" goal, which test_routes replays too (it was routes/6-4/
	## approach.json until test_routes took an until goal: the track B merge).
	return "%s/%s.json" % [ROUTE_DIR, id]


func _arena_door(lv: RefCounted) -> int:
	## A boss level's arena door column (the door gap before the arena), or 0.
	if lv.boss == "":
		return 0
	for e in lv.entities:
		if e["kind"] == "boss":
			var Arena = load("res://scripts/boss_arena.gd")
			var a = Arena.find(lv, LevelData.cell_floor(e["cell"]))
			if a is Dictionary and a.has("left"):
				return int(floorf(float(a["left"]) / TILE)) - 2
	return 0


func _replay(lv0: RefCounted, route: Dictionary, trace := false) -> Dictionary:
	## A route in a headless World (as test_routes plays it), with a trace
	## of where he was each tick and what happened.
	var lv = LevelData.load_file("res://levels/%s.txt" % lv0.id)
	Route.prepare(game, route, lv)
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = true
	w.paused = true
	root.add_child(w)
	await process_frame
	var deep = _deep(w)
	var masks := Route.decode(route["runs"])
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var jumps := []
	var tolls := []
	var kinds := {}          # kind -> first tick
	var chase_on := []       # [tick on, tick done] per range
	for c in deep.chases:
		chase_on.append([-1, -1])
	var rung := {}
	var hits := 0
	var hp_prev: float = w.player.hp
	var ride_f := PackedInt32Array()
	var depth := PackedFloat32Array()
	var firm := PackedInt32Array()
	var still_age := PackedFloat32Array()
	var dawn := PackedInt32Array()
	var prev_jump := false
	# The jumps the path needs: a jump whose flight crosses a column he
	# couldn't have walked (a gap, water not stilled, a float's edge) or that
	# lands him higher; a hop over flat floor a runner would just run.
	var needed := []
	var air := false
	var take_i := -1
	var take_y := 0.0
	var snap := {}
	var cols := {}
	for i in masks.size():
		var pad := Route.pad_of(int(masks[i]))
		var pl: Node2D = w.player
		var jump_now := bool(pad.get("jump", false))
		# Every press (one in coyote time, just after he walked off an
		# edge, jumps as well as one on the floor).
		if jump_now and not prev_jump:
			jumps.append(i)
		prev_jump = jump_now
		var was_ground: bool = pl.on_floor or pl.climbing
		var y_before: float = pl.position.y
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)
		if not pl.on_floor and not pl.climbing:
			if not air and was_ground:
				air = true
				take_i = i
				take_y = y_before
				snap.clear()
				cols.clear()
				var row := floori((take_y + 1.0) / TILE)
				var tx := floori(pl.position.x / TILE)
				for c in range(tx - 8, tx + 9):
					# Walkable: floor at his feet's row, or a firm floor he'd
					# walk off onto within 3 rows below (never water), or a
					# float riding just under his feet's height (he'd step
					# down onto it).
					var ok := false
					for r in range(row, row + 4):
						var t: int = w.level.tile(c, r)
						if LevelData.is_solid(t) or LevelData.is_ledge(t):
							ok = true
							break
						if t != LevelData.AIR:
							break
					for m in deep.floats:
						var mr: Rect2 = m.rect()
						if m.present and mr.position.x < (c + 1) * TILE and mr.end.x > c * TILE and absf(mr.position.y - take_y) <= 10.0:
							ok = true
					snap[c] = ok
			if air:
				cols[floori(pl.position.x / TILE)] = true
		elif air:
			air = false
			var need: bool = pl.position.y < take_y - 8.0
			for c in cols:
				if not bool(snap.get(c, false)):
					need = true
			var pressed := false
			for j in range(maxi(jumps.size() - 3, 0), jumps.size()):
				if int(jumps[j]) - take_i >= -2 and int(jumps[j]) - take_i <= int(ceil(PlayerScript.COYOTE / DT)) + 1:
					pressed = true
			if need and pressed:
				needed.append(take_i)
		xs.append(pl.position.x)
		ys.append(pl.position.y)
		if pl.hp < hp_prev - 0.01 and str(w.snuff_causes.get("_last", "")) == "tide":
			hits += 1
		hp_prev = pl.hp
		for bi in deep.buoys.size():
			var b: Dictionary = deep.buoys[bi]
			if float(b["rung"]) > float(rung.get(bi, -INF)):
				rung[bi] = float(b["rung"])
				tolls.append(i)
		for ci in deep.chases.size():
			var st: String = deep.chases[ci]["state"]
			if st == "on" and int(chase_on[ci][0]) < 0:
				chase_on[ci][0] = i
			if st == "done" and int(chase_on[ci][1]) < 0:
				chase_on[ci][1] = i
		if trace:
			for k in _kinds_at(w, deep, pl):
				if not kinds.has(k):
					kinds[k] = []
				(kinds[k] as Array).append(i)
			# His footing, for the human runner's terrain clocks (_terrain).
			var rf: int = deep.floats.find(pl.riding) if pl.riding != null else -1
			ride_f.append(rf)
			depth.append(float(deep.floats[rf].depth) if rf >= 0 else 0.0)
			firm.append(1 if (pl.on_floor and pl.riding == null) or pl.climbing else 0)
			var fc := Vector2i(floori(pl.position.x / TILE), floori((pl.position.y + 1.0) / TILE))
			var ft: int = w.level.tile(fc.x, fc.y)
			still_age.append(deep.knob("still_time") - (float(deep.still[fc]) - w.ftime) if pl.on_floor and ft == LevelData.STILL and deep.still.has(fc) else -1.0)
			dawn.append(1 if pl.on_floor and pl.riding == null and ft == LevelData.DAWN_ON else 0)
	var grasps := []
	for g in deep.grasps:
		grasps.append({"x": float(g["x"]), "y": float(g["y"])})
	var out := {"clear": w.state == "clear", "snuffs": int(w.snuffs), "tide_hits": hits, "xs": xs, "ys": ys, "jumps": needed, "presses": jumps,
			"tolls": tolls, "kinds": kinds, "chase": chase_on, "ranges": deep.chases.duplicate(true),
			"ride_f": ride_f, "depth": depth, "firm": firm, "still_age": still_age, "dawn": dawn, "grasps": grasps}
	await _free(w)
	return out


func _kinds_at(w: Node2D, deep: Object, pl: Node2D) -> Array:
	## The kinds of obstacle he meets this tick (a human's "new obstacle").
	var out := []
	var lv: RefCounted = w.level
	var feet := Vector2i(floori(pl.position.x / TILE), floori((pl.position.y + 1.0) / TILE))
	if pl.on_floor:
		if pl.riding != null and str(pl.riding.get("tag")) == "float":
			out.append("float")
		else:
			match lv.tile(feet.x, feet.y):
				LevelData.STILL:
					out.append("buoy")
				LevelData.DAWN_ON:
					out.append("dawnglass")
				LevelData.LEDGE:
					out.append("ledge")
				LevelData.GLASS:
					out.append("glass")
	for g in deep.grasps:
		if absf(pl.center().x - float(g["x"])) <= 96.0:
			out.append("grasp")
	# A jump over deep water.
	if not pl.on_floor and not pl.climbing and lv.is_deep(feet.x, feet.y + 1):
		out.append("gap")
	return out


func _chase_events(tr: Dictionary, ci: int) -> Dictionary:
	## One chase of a traced run as the model's events: the real x (and y)
	## each tick from the tide's rising to the end altar, the jumps, the
	## tolls, the first tick of each kind of obstacle that is new in the
	## level there (a kind met before the chase, in the level's run, is no
	## news: 6-3's floats and gaps are LQ_DARK's), and his footing.
	var on: int = int(tr["chase"][ci][0])
	var done: int = int(tr["chase"][ci][1])
	if on < 0 or done < 0:
		return {}
	var xs: PackedFloat32Array = tr["xs"]
	var jumps := []
	for j in tr["jumps"]:
		if int(j) >= on and int(j) <= done:
			jumps.append(int(j) - on)
	var tolls := []
	for t in tr["tolls"]:
		if int(t) >= on and int(t) <= done:
			tolls.append(int(t) - on)
	var kinds := {}
	var met := []
	for k in tr["kinds"]:
		var ticks: Array = tr["kinds"][k]
		var inside := false
		for t in ticks:
			if int(t) >= on and int(t) <= done:
				inside = true
				break
		if not inside:
			continue
		met.append(k)
		var first: int = int(ticks[0])
		if first >= on and first <= done:
			kinds[k] = first - on
	return {"x": xs.slice(on, done + 1), "y": (tr["ys"] as PackedFloat32Array).slice(on, done + 1), "jumps": jumps, "tolls": tolls,
			"kinds": kinds, "met": met, "x0": float(xs[on]),
			"ride_f": (tr["ride_f"] as PackedInt32Array).slice(on, done + 1), "depth": (tr["depth"] as PackedFloat32Array).slice(on, done + 1),
			"firm": (tr["firm"] as PackedInt32Array).slice(on, done + 1), "still_age": (tr["still_age"] as PackedFloat32Array).slice(on, done + 1),
			"dawn": (tr["dawn"] as PackedInt32Array).slice(on, done + 1), "grasps": tr["grasps"]}


func _timeline(ev: Dictionary, human: bool) -> Dictionary:
	## The runner's x over its own time: [t...] and [x...], and when it tolls;
	## and per tick of the run, when he arrives there (arr) and how long he
	## stands there first (stay). The bot runner: the real run plus BOT_JUMP
	## standing at each jump. The human: the real moves at HUMAN_SPEED,
	## HUMAN_JUMP standing before each jump (on the last firm footing before
	## it outside every grasp's reach: never on a float, never over the
	## hands) and HUMAN_NEW at the first of each kind new in the level.
	var xs: PackedFloat32Array = ev["x"]
	var stops := {}
	for j in ev["jumps"]:
		var at: int = _stop_at(ev, int(j)) if human else int(j)
		stops[at] = float(stops.get(at, 0.0)) + (HUMAN_JUMP if human else BOT_JUMP)
	if human:
		for k in ev["kinds"]:
			var at: int = int(ev["kinds"][k])
			stops[at] = float(stops.get(at, 0.0)) + HUMAN_NEW
	var ts := PackedFloat32Array()
	var px := PackedFloat32Array()
	var arr := PackedFloat32Array()
	var stay := PackedFloat32Array()
	var toll_t := []
	var t := 0.0
	for i in xs.size():
		arr.append(t)
		var s := float(stops.get(i, 0.0))
		stay.append(s)
		if s > 0.0:
			ts.append(t)
			px.append(xs[i])
			t += s
		if (ev["tolls"] as Array).has(i):
			toll_t.append(t)
		ts.append(t)
		px.append(xs[i])
		var moving: bool = i + 1 < xs.size() and absf(xs[i + 1] - xs[i]) > 0.01
		t += DT / (HUMAN_SPEED if human and moving else 1.0)
	return {"t": ts, "x": px, "tolls": toll_t, "arr": arr, "stay": stay}


func _stop_at(ev: Dictionary, j: int) -> int:
	## Where the human runner stands his HUMAN_JUMP before the jump at tick j.
	var firm: PackedInt32Array = ev["firm"]
	var xs: PackedFloat32Array = ev["x"]
	for i in range(j, maxi(j - 360, -1), -1):
		if firm[i] == 1 and _outside_grasps(ev, xs[i]):
			return i
	return j


func _outside_grasps(ev: Dictionary, x: float) -> bool:
	for g in ev["grasps"]:
		if absf(x - float(g["x"])) <= float(_const("GRASP_REACH")) + 2.0:
			return false
	return true


func _terrain(ev: Dictionary, d: String, k: float) -> String:
	## The human runner's run (every second of it x k, his stops where
	## _timeline puts them) against the terrain's own clocks, which don't
	## wait for him: a float he rides must not go under, still water must
	## hold while he's on it (from its toll on his clock), a toll-lit pane
	## while he's on it, and no grasp may have its hands up where he is.
	## "" when he makes all of it, or what went wrong.
	var tl := _timeline(ev, true)
	var arr: PackedFloat32Array = tl["arr"]
	var stay: PackedFloat32Array = tl["stay"]
	var n := arr.size()
	var xs: PackedFloat32Array = ev["x"]
	var ride: PackedInt32Array = ev["ride_f"]
	var depth: PackedFloat32Array = ev["depth"]
	var sink := _knob("float_sink", d)
	var under: float = Movers.FLOAT_UNDER
	var i := 0
	while i < n:
		if ride[i] < 0:
			i += 1
			continue
		var j := i
		while j + 1 < n and ride[j + 1] == ride[i]:
			j += 1
		var stood := k * (arr[j] + stay[j] - arr[i])
		var left := (under - depth[i]) / sink
		if stood >= left - DT:
			return "the float at x %.0f goes under %.2f s after he lands; he is on it %.2f s" % [xs[i] / TILE, left, stood]
		i = j + 1
	var still_t := _knob("still_time", d)
	var sa: PackedFloat32Array = ev["still_age"]
	var dawn: PackedInt32Array = ev["dawn"]
	for a in n:
		if sa[a] >= 0.0:
			var toll_i := maxi(a - int(round(sa[a] / DT)), 0)
			var held := k * (arr[a] + stay[a] - arr[toll_i])
			if held >= still_t - DT:
				return "the still water at x %.0f opens under him %.2f s after its toll (it holds %.1f s)" % [xs[a] / TILE, held, still_t]
		if dawn[a] == 1:
			var last := -1
			for tt in ev["tolls"]:
				if int(tt) <= a:
					last = int(tt)
			if last >= 0:
				var lit := k * (arr[a] + stay[a] - arr[last])
				if lit >= float(_const("TOLL_LIGHT")) - 0.35:
					return "the toll-lit pane at x %.0f goes dark under him %.2f s after the toll" % [xs[a] / TILE, lit]
	for g in ev["grasps"]:
		var why := _grasp_run(g, ev, tl, d, k)
		if why != "":
			return why
	return ""


func _grasp_run(g: Dictionary, ev: Dictionary, tl: Dictionary, d: String, k: float) -> String:
	## One grasp's clock (deep.gd's: idle, a tell once his centre is within
	## its reach, the hands up, the cooldown) run on the human runner's time.
	var gx := float(g["x"])
	var gw := float(_const("GRASP_W"))
	var gh := float(_const("GRASP_H"))
	var hands := Rect2(gx - gw * 0.5, float(g["y"]) - gh, gw, gh)
	var tell := _knob("grasp_tell", d)
	var up := float(_const("GRASP_UP"))
	var cool := float(_const("GRASP_COOL"))
	var reach := float(_const("GRASP_REACH"))
	var arr: PackedFloat32Array = tl["arr"]
	var stay: PackedFloat32Array = tl["stay"]
	var xs: PackedFloat32Array = ev["x"]
	var ys: PackedFloat32Array = ev["y"]
	var state := "idle"
	var since := 0.0
	for idx in xs.size():
		if absf(xs[idx] - gx) > 400.0 and state == "idle":
			continue
		var r := Rect2(xs[idx] - 10.0, ys[idx] - 38.0, 20.0, 38.0).grow(-2.0)
		var t0 := k * arr[idx]
		var s := k * stay[idx]
		var q := 0.0
		while true:
			var t := t0 + q
			var moved := true
			while moved:
				moved = false
				if state == "tell" and t - since >= tell:
					state = "up"
					since += tell
					moved = true
				elif state == "up" and t - since >= up:
					state = "cool"
					since += up
					moved = true
				elif state == "cool" and t - since >= cool:
					state = "idle"
					moved = true
			if state == "idle" and absf(xs[idx] - gx) <= reach:
				state = "tell"
				since = t
			if state == "up" and r.intersects(hands):
				return "the grasp at x %.0f has its hands up where he is (%.2f s into the chase on his clock)" % [gx / TILE, t]
			q += DT
			if q >= s:
				break
	return ""


func _caught(tl: Dictionary, d: String, k: float, x0: float) -> bool:
	## The tide against the runner's timeline with every second scaled by k:
	## does it touch him?
	var ts: PackedFloat32Array = tl["t"]
	var px: PackedFloat32Array = tl["x"]
	var far := _knob("tide_far", d)
	var mid := _knob("tide_mid", d)
	var near := _knob("tide_near", d)
	var tide := x0 - float(_const("TIDE_START")) * TILE
	var holds: Array = tl["tolls"]
	var i := 0
	var t := 0.0
	var end: float = ts[ts.size() - 1] * k
	var step := DT
	while t <= end:
		while i + 1 < ts.size() and ts[i + 1] * k <= t:
			i += 1
		var x: float = px[i]
		if i + 1 < ts.size() and ts[i + 1] > ts[i]:
			var u: float = clampf((t / k - ts[i]) / (ts[i + 1] - ts[i]), 0.0, 1.0)
			x = lerpf(px[i], px[i + 1], u)
		var held := false
		for h in holds:
			if t >= float(h) * k and t < float(h) * k + float(_const("TOLL_HOLD")):
				held = true
		if not held:
			var dtl: float = (x - tide) / TILE
			var v := far if dtl > float(_const("TIDE_FAR_AT")) else (mid if dtl >= float(_const("TIDE_NEAR_AT")) else near)
			tide += v * step
		if tide >= x - 8.0:
			return true
		t += step
	return false


func _margin(ev: Dictionary, d: String, human: bool) -> float:
	## How much slower (every second of the runner's, x k) he could be and
	## never be touched: k - 1 (0 when he's caught as he is).
	var tl := _timeline(ev, human)
	var x0: float = ev["x0"]
	if _caught(tl, d, 1.0, x0):
		return 0.0
	var lo := 1.0
	var hi := 3.0
	if not _caught(tl, d, hi, x0):
		return hi - 1.0
	for i in 14:
		var m := (lo + hi) * 0.5
		if _caught(tl, d, m, x0):
			hi = m
		else:
			lo = m
	return lo - 1.0


func _test_routes_present() -> void:
	## Golden routes for every level whose path has a float line or a timed
	## crossing. 6-4 ends in its boss (test_routes can't ring its bell with
	## no monsters), so its approach, to the arena door, is replayed here.
	for id in ["6-1", "6-2", "6-3"]:
		if FileAccess.file_exists("res://levels/%s.txt" % id):
			_check(FileAccess.file_exists(_route_path(id, "dusk")), "%s has a golden route (%s)" % [id, _route_path(id, "dusk").get_file()])
	if not FileAccess.file_exists("res://levels/6-4.txt"):
		return
	var path := _approach_path("6-4")
	_check(FileAccess.file_exists(path), "6-4 has a golden route to its arena door (%s)" % path)
	if not FileAccess.file_exists(path):
		return
	var route := Route.read(path)
	var lv = LevelData.load_file("res://levels/6-4.txt")
	Route.prepare(game, route, lv)
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = true
	w.paused = true
	root.add_child(w)
	await process_frame
	var masks := Route.decode(route["runs"])
	var hurt := 0
	var hp_prev: float = w.player.hp
	for i in masks.size():
		_tick(w, Route.pad_of(int(masks[i])))
		if w.player.hp < hp_prev - 0.01:
			hurt += 1
		hp_prev = w.player.hp
	var until := float((route.get("until", {}) as Dictionary).get("x", 0.0))
	print("  6-4 approach: %d ticks (%.1f s), at x %.0f (the door %.0f), %d snuffs, %d hurts" % [masks.size(), masks.size() * DT, w.player.position.x / TILE, until / TILE, w.snuffs, hurt])
	_check(until > 0.0 and w.player.position.x >= until and w.snuffs == 0 and hurt == 0,
			"6-4: the approach route reaches the arena door with no snuff and no hurt (the cog, the gusts over glass, the Deep's float line)")
	_check(absf(w.player.position.x - float(route["end"]["x"])) <= 1.0, "6-4: and ends where it was recorded")
	await _free(w)


# ---------------------------------------------------------------- the route director

func _record_all(spec: String) -> void:
	## WAXBY_RECORD=6-1:dusk,6-3:witching: play each level to its bell with
	## the director below (no monsters, as the routes are replayed) and write
	## routes/<id>[-<diff>].json when it rings the bell with no snuff. A boss
	## level (6-4) is played to its arena door instead and written to
	## routes/6-4.json with an until goal (test_routes and test_w6 replay it).
	for part in spec.split(","):
		var bits := part.strip_edges().split(":")
		var id := bits[0]
		var d := bits[1] if bits.size() > 1 else "dusk"
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		var route := {"calling": "knight", "diff": d}
		Route.prepare(game, route, lv)
		var w: Node2D = WorldScript.new()
		w.setup(lv, true)
		w.no_monsters = true
		w.paused = true
		root.add_child(w)
		await process_frame
		var dir := Director.new()
		dir.setup(w)
		var door := _arena_door(lv)
		if door > 0:
			dir.until_x = door * TILE
		var t0 := Time.get_ticks_msec()
		var ok := dir.run(int(900.0 / DT))
		var reached: bool = ok and (w.state == "clear" or (door > 0 and w.player.position.x >= door * TILE))
		print("  %s (%s): %s after %d ticks (%.1f s), %d plans, %d tolls, %d waits, %d ms"
				% [id, d, ("the arena door" if door > 0 else "the bell") if reached else "no %s (%s)" % ["door" if door > 0 else "bell", dir.why],
				dir.masks.size(), dir.masks.size() * DT, dir.plans, dir.tolls, dir.waits, Time.get_ticks_msec() - t0])
		if reached and w.snuffs == 0:
			var out := {"level": id, "calling": "knight", "diff": d, "hero_level": 1, "ticks": dir.masks.size(),
					"runs": Route.encode(dir.masks), "end": {"x": roundi(w.player.position.x), "state": w.state},
					"note": "recorded by test_w6.gd's director (WAXBY_RECORD): the reach bot's plan, tolling each buoy as it comes, waiting out grasps and weights, timing moving ledges"}
			if door > 0:
				out["until"] = {"x": door * TILE}
			var path := ProjectSettings.globalize_path(_approach_path(id) if door > 0 else _route_path(id, d))
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			_check(Route.save(path, out), "wrote %s" % path)
			print("  wrote ", path)
		else:
			_check(false, "%s (%s): the director rang the bell with no snuff (%s, %d snuffs)" % [id, d, dir.why, w.snuffs])
		dir.free_sims()
		await _free(w)


class Director:
	## Plays a level in a headless World (paused: it drives every tick) to
	## its bell: plans with the reachability engine (greedy toward the bell,
	## 24 tiles at a time, on the level as it is now, still water and lit
	## dawnglass where buoys and lamps will make them), and before each action
	## checks it on the level as it really is this tick with the real moving
	## ledges and floats (cloned): an action that needs still water first
	## walks into the buoy beside him; one that a grasp's hands or a weight
	## would meet waits (provoking an idle grasp first, from outside its
	## reach); one onto a moving ledge waits for it.
	extends RefCounted
	const Reach := preload("res://scripts/reach.gd")
	const ReachSearch := preload("res://scripts/reach_search.gd")
	const Route := preload("res://scripts/route.gd")
	const Movers := preload("res://scripts/movers.gd")
	const LevelData := preload("res://scripts/level_data.gd")
	const PlayerScript := preload("res://scripts/player.gd")
	const TILE := 32
	const DT := 1.0 / 120.0
	const HORIZON := 24.0 * TILE
	var w: Node2D
	var deep: Object
	var clock: Object
	var goal := {}
	var masks := []
	var plans := 0
	var tolls := 0
	var waits := 0
	var why := ""
	var _route := []
	var _step := 0
	var _prev := {}
	var _sim_p: Node2D
	var _sim_w
	var debug := OS.get_environment("WAXBY_DIRECTOR_DEBUG") != ""
	var until_x := 0.0             # > 0: done once he stands this far right (6-4's arena door)
	# WAXBY_DIRECTOR_X=240,250: print every tick while he's between those tiles.
	var _trace_x: Array = Array(OS.get_environment("WAXBY_DIRECTOR_X").split(",", false))
	var _nudges := 0
	var _pess := false
	var _last_why := ""

	func setup(world: Node2D) -> void:
		w = world
		deep = w.features.module("deep")
		clock = w.features.module("clockwork")
		for g in Reach.goals_of(w.level):
			if g["what"] == "bell" or (g["what"] == "boss arena" and goal.is_empty()):
				goal = g
		_sim_w = Reach.BotWorld.new()
		_sim_p = PlayerScript.new()
		_sim_p.world = _sim_w

	func free_sims() -> void:
		if _sim_p != null:
			_sim_p.free()
			_sim_p = null

	func _tick(pad: Dictionary) -> void:
		var held := pad.duplicate()
		for k in ["jump_pressed", "attack_pressed", "jump_released", "attack_released"]:
			held.erase(k)
		masks.append(Route.mask(held))
		w.test_pad = held
		w._read_pad()
		w.tick(DT)
		_prev = held
		if _trace_x.size() == 2:
			var pl: Node2D = w.player
			var tx: float = pl.position.x / TILE
			if tx >= float(_trace_x[0]) and tx <= float(_trace_x[1]):
				print("    t %d x %.2f y %.1f floor %s ride %s v %s pad %s hp %.0f" % [masks.size(), tx, pl.position.y, pl.on_floor,
						pl.riding != null, pl.velocity.round(), held.keys(), pl.hp])

	func run(max_ticks: int) -> bool:
		var pl: Node2D = w.player
		var stuck := 0.0
		var best_x: float = pl.position.x
		while w.state != "clear" and masks.size() < max_ticks:
			if w.state == "dead" or not pl.alive:
				why = "snuffed at x %.0f" % pl.position.x
				return false
			if until_x > 0.0 and pl.position.x >= until_x and pl.on_floor:
				return true
			if pl.position.x > best_x + 8.0:
				best_x = pl.position.x
				stuck = 0.0
			if stuck > 20.0:
				why = "stuck at x %.0f" % pl.position.x
				return false
			if not (pl.on_floor or pl.climbing):
				_tick({})
				stuck += DT
				continue
			if _toll_beside(pl):
				_route = []
				continue
			if _step >= _route.size():
				if not _plan(pl):
					why = "no plan from x %.0f" % pl.position.x
					return false
			var a: Dictionary = _route[_step]["action"]
			# Come to rest (every sim starts at rest), braking short of an
			# edge he landed at with his run still on him.
			var rest := 0
			while absf(pl.velocity.x) > 1.0 and rest < 48 and pl.on_floor:
				_tick(_brake(pl))
				rest += 1
			var verdict := _check_action(pl, a, _route[_step]["to"])
			if verdict == "replan":
				var fix := _repair(pl, _route[_step]["to"], a)
				if not fix.is_empty():
					a = fix
					_route[_step]["action"] = fix
					verdict = "go"
				elif not _pess:
					# The plan leant on still water that isn't there (the buoy is
					# out past a float): the float way to the buoy first.
					_pess = true
					_route = []
					continue
				elif _nudges < 6:
					# Off by a hair: shuffle a step back and plan from there.
					_nudges += 1
					for i in 3 + 3 * _nudges:
						_tick({"left": true})
					var m := 0
					while absf(pl.velocity.x) > 1.0 and m < 30:
						_tick({})
						m += 1
					_route = []
					continue
			if verdict == "go":
				_nudges = 0
				var t0 := masks.size()
				_do(pl, a)
				stuck += (masks.size() - t0) * DT
				var want = _route[_step]["to"]
				var got := Reach.key_of(pl.position, pl.climbing)
				_step += 1
				if want != null and (absi(got.x - want.x) > 1 or got.y != want.y or got.z != want.z):
					_route = []
			elif verdict == "provoke":
				_provoke(pl)
				_route = []
			elif verdict == "replan":
				if debug and plans % 20 == 0:
					print("    replan at %s: %s (%s)" % [pl.position, a, _last_why])
				_route = []
				_tick({})
				stuck += DT
			else:
				waits += 1
				_tick({})
				stuck += DT
		if w.state != "clear":
			why = "out of time"
		return w.state == "clear"

	func _plan(pl: Node2D) -> bool:
		var copy = Reach.static_copy(w.level, {"open_breakables": false, "still": not _pess})
		var s = ReachSearch.new()
		var dir := signf(goal["p"].x - pl.position.x)
		s.setup(copy, pl.position, {"mode": "greedy", "target": goal["p"], "stop_on": goal["what"], "goals": [goal],
				"cap": 6000, "start_climb": pl.climbing, "stop_x": pl.position.x + dir * HORIZON})
		if pl.climbing:
			s.nodes[0]["col"] = pl.climb_col
		s.run()
		plans += 1
		var end_node := -1
		var hit := {}
		if s.found.has(goal["what"]):
			hit = s.found[goal["what"]]
			end_node = int(hit["node"])
		elif s.best > 0:
			end_node = int(s.best)
		_route = []
		_step = 0
		if end_node < 0:
			s.free_player()
			return false
		var path: Array = s.path_to(end_node)
		for k in range(1, path.size()):
			var n: Dictionary = s.nodes[path[k]]
			_route.append({"action": n["action"], "to": Reach.key_of(n["pos"], n["climb"])})
		if not hit.is_empty():
			_route.append({"action": hit["action"], "to": null})
		s.free_player()
		return not _route.is_empty()

	func _brake(pl: Node2D) -> Dictionary:
		## No input, or the other way while he slides toward an edge.
		var vx: float = pl.velocity.x
		if absf(vx) > 20.0 and not pl.ground_ahead(1 if vx > 0.0 else -1):
			return {"left": vx > 0.0, "right": vx < 0.0}
		return {}

	func _toll_beside(pl: Node2D) -> bool:
		## A buoy ahead at his feet's height, ready to toll, with floor all
		## the way to it and no grasp between: walk into it (as a person
		## would, never a jump over its cell).
		if deep == null or not pl.on_floor:
			return false
		for b in deep.buoys:
			if w.ftime < float(b["cool_until"]):
				continue
			var bx: float = (b["pos"] as Vector2).x
			var gap: float = (bx - 16.0) - pl.rect().end.x
			var grasp_between := false
			for g in deep.grasps:
				if float(g["x"]) > pl.position.x - 8.0 and float(g["x"]) < bx + 64.0:
					grasp_between = true
			if gap > -8.0 and gap < 8.0 * TILE and not grasp_between and absf(pl.position.y - float(b["line"])) < 30.0 \
					and not _water_ahead_is_still(b) and _floor_to(pl, b["cell"]):
				var n := 0
				while float(b["rung"]) < w.ftime - 0.5 and n < 240:
					_tick({"right": true})
					n += 1
				tolls += 1
				_pess = false
				# Stop and plan again on the still water.
				var m := 0
				while absf(pl.velocity.x) > 1.0 and m < 30:
					_tick({})
					m += 1
				return true
		return false

	func _floor_to(pl: Node2D, cell: Vector2i) -> bool:
		## Floor all the way from his feet to the buoy's cell (stone, a
		## ledge, still water or a float), so walking gets him there.
		var lv: RefCounted = w.level
		var fy := floori((pl.position.y + 1.0) / TILE)
		for x in range(floori(pl.position.x / TILE), cell.x):
			var t: int = lv.tile(x, fy)
			if LevelData.is_solid(t) or LevelData.is_ledge(t):
				continue
			var on_float := false
			for m in w.movers:
				if str(m.tag) == "float" and m.present and x * TILE + 16 >= m.rect().position.x and x * TILE + 16 <= m.rect().end.x:
					on_float = true
			if not on_float:
				return false
		return true

	func _water_ahead_is_still(b: Dictionary) -> bool:
		var c: Vector2i = b["cell"]
		return w.level.tile(c.x + 1, c.y) == LevelData.STILL and float(deep.still.get(Vector2i(c.x + 1, c.y), 0.0)) - w.ftime > 3.5

	func _live_copy() -> RefCounted:
		var lv: RefCounted = w.level
		var c = LevelData.new()
		c.id = lv.id
		c.world = lv.world
		c.width = lv.width
		c.height = lv.height
		c.tiles = lv.tiles.duplicate()
		c.entities = []
		c.start = lv.start
		return c

	func _sim(pl: Node2D, a: Dictionary) -> Dictionary:
		## The action from here on the level as it is, with the real movers.
		var lv := _live_copy()
		_sim_p.level = lv
		_sim_w.level = lv
		_sim_w.reset()
		_sim_w.ftime = w.ftime
		_sim_w.movers = []
		for m in w.movers:
			_sim_w.movers.append(Movers.clone(m))
		_sim_p.reset_at(pl.position)
		var from_climb: bool = pl.climbing
		if from_climb:
			_sim_p.grab_vine(pl.climb_col, 1.0)
		else:
			_sim_p.on_floor = true
		var st := {}
		var prev := {}
		var t := 0.0
		var left := false
		var ok := true
		var traj := []
		var t_end := Reach.SIM_TIME + (float(a.get("t", 0.0)) if a.get("vine", false) else 0.0)
		while t < t_end:
			for m in _sim_w.movers:
				m.update(w.ftime + t + DT, DT)
			var held := Reach.action_pad(a, t, st)
			var pd := held.duplicate()
			for k in ["jump", "attack"]:
				var now: bool = held.get(k, false)
				pd[k + "_pressed"] = now and not prev.get(k, false)
				prev[k] = now
			_sim_p.pad = pd
			_sim_p.step(DT)
			_sim_w.ftime += DT
			t += DT
			traj.append(_sim_p.rect())
			var r: Rect2 = _sim_p.rect()
			if Reach.hurts(lv, r) or _sim_p.position.y > lv.height * TILE + 40:
				ok = false
				break
			if from_climb and not left and not _sim_p.climbing:
				left = true
			if _sim_p.climbing and (left or not from_climb):
				break
			if not _sim_p.on_floor and not _sim_p.climbing and _sim_p.ledge_t < 0.0:
				left = true
			elif _sim_p.on_floor and (left or (not from_climb and not a.get("jump", false) and t >= float(a.get("walk", 0.0)))):
				break
		# Standing where it lands for a moment (a float sinks, a grasp rises).
		var stand: Rect2 = _sim_p.rect()
		return {"ok": ok and (_sim_p.on_floor or _sim_p.climbing), "pos": _sim_p.position, "climb": _sim_p.climbing, "traj": traj, "stand": stand}

	func _check_action(pl: Node2D, a: Dictionary, want) -> String:
		## "go", "wait", "provoke" (an idle grasp would meet him) or "replan".
		var r := _sim(pl, a)
		_last_why = "sim ok %s lands %s" % [r["ok"], r["pos"]]
		if not r["ok"]:
			# A moving ledge not round yet, or still water gone: wait a
			# little for the first, plan again for the second.
			if _near_mover(pl):
				return "wait" if waits % 900 != 899 else "replan"
			return "replan"
		if want != null:
			var got := Reach.key_of(r["pos"], r["climb"])
			if absi(got.x - want.x) > 1 or got.y != want.y or got.z != want.z:
				if _near_mover(pl):
					return "wait" if waits % 900 != 899 else "replan"
				return "replan"
		var traj: Array = r["traj"]
		# Grasps.
		if deep != null:
			for g in deep.grasps:
				var gr: Rect2 = deep.grasp_rect(g).grow(3.0)
				var gx := float(g["x"])
				if absf(gx - pl.position.x) > 400.0:
					continue
				var tell: float = deep.knob("grasp_tell")
				var up0 := INF
				var up1 := -INF
				var age: float = w.ftime - float(g["t"])
				match g["state"]:
					"idle":
						for i in traj.size():
							if absf((traj[i] as Rect2).get_center().x - gx) <= 64.0:
								up0 = (i + 1) * DT + tell
								break
						if up0 == INF and absf(pl.center().x - gx) <= 64.0:
							up0 = tell
						up1 = up0 + 1.0
					"tell":
						up0 = tell - age
						up1 = up0 + 1.0
					"up":
						up0 = 0.0
						up1 = 1.0 - age
					"cool":
						up0 = INF
				var hit := false
				for i in traj.size():
					var ti := (i + 1) * DT
					if ti >= up0 - 0.05 and ti <= up1 + 0.05 and (traj[i] as Rect2).intersects(gr):
						hit = true
				# Standing where it lands while they're up.
				if not hit and up1 > traj.size() * DT and (r["stand"] as Rect2).intersects(gr):
					hit = true
				if hit:
					return "provoke" if g["state"] == "idle" else "wait"
		# Weights.
		if clock != null and "weights" in clock:
			for wt in clock.weights:
				for i in range(0, traj.size() + 36):
					var tt: float = float(w.ftime) + (i + 1) * DT
					var rr: Rect2 = traj[mini(i, traj.size() - 1)] if not traj.is_empty() else pl.rect()
					if _bob_at(wt, tt).distance_to(rr.get_center()) < 18.0 + 24.0:
						return "wait"
		return "go"

	func _repair(pl: Node2D, want, planned: Dictionary) -> Dictionary:
		## Another action from here that lands where the plan wanted (the real
		## floats ride 4 px under the plan's ledges, and he's never exactly on
		## the plan's spot): the planned kind of move with other run-ups and
		## holds, then every move the bot knows.
		var cands := []
		if pl.climbing:
			cands = Reach.vine_actions()
		else:
			var dir := int(planned.get("dir", 1))
			for run in [0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4]:
				for hold in [0.12, 0.2, 0.3, 0.45, 0.6]:
					cands.append({"walk": run, "dir": dir, "jump": true, "hold": hold})
			for walk in [0.05, 0.1, 0.15, 0.22, 0.3]:
				cands.append({"walk": walk, "dir": dir, "jump": false})
			cands.append_array(Reach.floor_actions())
		for c in cands:
			if _check_action(pl, c, want) == "go":
				return c
		return {}

	func _bob_at(wt: Dictionary, t: float) -> Vector2:
		var amp: float = float((clock.get_script() as Script).get_script_constant_map().get("WEIGHT_AMP", deg_to_rad(50.0)))
		var a := amp * sin(TAU * (t / clock.knob("weight_period") + float(wt["phase"])))
		return (wt["anchor"] as Vector2) + Vector2(sin(a), cos(a)) * float(wt["rod"])

	func _near_mover(pl: Node2D) -> bool:
		for m in w.movers:
			if m.kind in ["orbit", "arc", "x", "y"] and (m.rect() as Rect2).get_center().distance_to(pl.position) < 320.0:
				return true
		return false

	func _provoke(pl: Node2D) -> void:
		## Step toward the idle grasp ahead until it ripples, back off, and
		## wait on the stone until its hands have sunk.
		var g: Dictionary = {}
		for gg in deep.grasps:
			if gg["state"] == "idle" and absf(float(gg["x"]) - pl.position.x) < 400.0:
				if g.is_empty() or absf(float(gg["x"]) - pl.position.x) < absf(float(g["x"]) - pl.position.x):
					g = gg
		if g.is_empty():
			return
		var dir := 1.0 if float(g["x"]) > pl.position.x else -1.0
		var n := 0
		while g["state"] == "idle" and n < 240:
			_tick({"right": dir > 0.0, "left": dir < 0.0})
			n += 1
		n = 0
		while absf(pl.center().x - float(g["x"])) < 110.0 and n < 60 and pl.on_floor:
			_tick({"left": dir > 0.0, "right": dir < 0.0})
			n += 1
		n = 0
		while g["state"] != "cool" and n < 480:
			_tick({})
			n += 1

	func _do(pl: Node2D, a: Dictionary) -> void:
		## The action's pads until it lands (as the sims end).
		var st := {}
		var t := 0.0
		var left := false
		var from_climb: bool = pl.climbing
		var started_climb: bool = bool(a.get("vine", false))
		var t_end := Reach.SIM_TIME + (float(a.get("t", 0.0)) if started_climb else 0.0)
		var first := true
		while t < t_end + 0.5 and w.state == "play" and pl.alive:
			var held := Reach.action_pad(a, t, st)
			if first and held.get("jump", false) and _prev.get("jump", false):
				held["jump"] = false
				_tick(held)
				first = false
				continue
			first = false
			_tick(held)
			t += DT
			if from_climb and not left and not pl.climbing:
				left = true
			if pl.climbing and (left or not from_climb):
				break
			if not pl.on_floor and not pl.climbing and pl.ledge_t < 0.0:
				left = true
			elif pl.on_floor and (left or (not started_climb and not a.get("jump", false) and t >= float(a.get("walk", 0.0)))):
				break
			if w.state == "clear":
				break
