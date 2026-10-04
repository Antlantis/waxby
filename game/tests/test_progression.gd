extends SceneTree
## XP, items, hero stats, relics and the save (workstream W2):
##   - the curve: level_of(total_to(L)) == L at every level;
##   - the XP budget: a modelled first Dusk run of every level file comes out
##     within 0.7 of spec §1.1's exit levels;
##   - the balance bands, with a reference Candleknight (Blessed gear at
##     ilvl = area with median rolls, half his points in stat nodes);
##   - 10,000 seeded item rolls: affixes in range, no repeats, at most two
##     prefixes and two suffixes, rarities at their weights;
##   - the caps, the Legendary powers, the new-calling start;
##   - v1 -> v3 migration from a fixture save, a lossless round trip;
##   - respec, belt slots, skill gates, the Chandler (logic and screen,
##     two taps to buy), the full satchel, the settings cache;
##   - none of these files touch a movement constant.
## v3 (Phase 0, contract §7-§8): combat's areas, knee, Depth, clamp, dim
## floor, elites, embers and checkpoints; the curve to L40 and Candlemarks;
## every kind's XP; the deep tree (off, then on); the new stat keys; items'
## five tiers, the Lantern, live slots and pick_legend; relic worlds; the
## level registry; the v2 -> v3 migration (a fixture and the owner's own
## saves, copies only) and every new Game API. Build 1's loot: no Dusk
## Commons, half the kill drops, the boss signature pieces, one relic of each
## rarity on the shelf, embers_spent and legendaries_worn for the playlog; the
## Boss Boons' offer (his signature, then others the hero doesn't hold).
##
##     godot --headless --path game --script res://tests/test_progression.gd

const Progression := preload("res://scripts/progression.gd")
const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const Relics := preload("res://scripts/relics.gd")
const Classes := preload("res://scripts/classes.gd")
const Combat := preload("res://scripts/combat.gd")
const LevelData := preload("res://scripts/level_data.gd")
const Rules := preload("res://tests/level_rules.gd")
const SettingsLib := preload("res://scripts/settings.gd")

const SAVE := "user://test_progression_save.json"
const SETTINGS := "user://test_progression_settings.json"
const V1_FIXTURE := "res://tests/fixtures/v1_save.json"
const V2_FIXTURE := "res://tests/fixtures/v2_save.json"
const OWNER_1 := "res://tests/fixtures/owner_v2_save.json"     # a copy of the owner's slot 1 (2026-09-26)
const OWNER_2 := "res://tests/fixtures/owner_v2_save_2.json"   # and his fresh slot 2
const OWNER_DIR := "/Users/antmacpro/Developer/waxby-snapshots/phone-saves/20260926-0512/"   # the originals: read, never written

# The hero's level leaving each level on a first Dusk run: spec §1.5's,
# reset from Build 2's re-cut files (the walk's exits, cut to a tenth, so
# each floor is the level he really meets the next one at). The bosses are
# met where today's cut met them: 1-4 at L6, 2-4 at L12, 3-4 at L17 (§1.5's
# 17.2; today's cut met him at L16), 4-4 at L21, 5-4 at L25 (§1.5's 26.0:
# 25.68, as today's 25.69; test_bosses4 still fights the Saint at L26) and
# 6-4 at L30.
const EXIT_TARGET := {"1-1": 3.0, "1-2": 4.9, "1-3": 6.9, "1-4": 8.1, "2-1": 9.3, "2-2": 10.6, "2-3": 12.0, "2-4": 13.5,
	"3-1": 14.5, "3-2": 15.6, "3-3": 17.0, "3-4": 18.3, "4-1": 19.1, "4-2": 20.2, "4-3": 21.5, "4-4": 23.0,
	"5-1": 23.7, "5-2": 24.5, "5-3": 25.6, "5-4": 27.2, "6-1": 28.0, "6-2": 29.1, "6-3": 30.1, "6-4": 32.0}
const EXIT_SLACK := 0.7        # worlds 1-2 (v2)
const EXIT_SLACK_DEEP := 1.0   # worlds 3-6: built to a model; tighten after the first playtest
# Each level's Dread when its file doesn't name one yet (spec §5).
const DREAD_FALLBACK := {"1-1": "skeleton", "1-2": "bat", "1-3": "thornback", "2-1": "dripkin", "2-2": "bonebow", "2-3": "gutterwing"}
const FODDER := ["skeleton", "bat", "bonebow", "gutterwing", "dripkin", "brinejaw",
		"rootling", "creepbone", "tickwind", "glassmite", "gustling", "hushling"]   # (v3's never appear in W1-W2)
# The spec's model of W3-W6 and the secrets (placements, kinds' moves, Dreads,
# Wardens, bosses, altars): it stands in for a level file, a kind's script
# or a boss's script until that lands (tools: PR's scratch generator).
const V3_FIXTURE := "res://tests/fixtures/v3_balance.json"
# Build 2's toolkit fixture (tools/levels/toolkit.py): a made-up World 6 level
# with three forced Anointed (anoint:), on ground pick_elites would refuse.
const TOOLKIT_FIXTURE := "res://tests/fixtures/toolkit-cast.txt"
const BOSS_SCRIPTS := {"rootmother": "res://scripts/rootmother_boss.gd", "tinker": "res://scripts/tinker_boss.gd",
		"saint": "res://scripts/saint_boss.gd", "hush": "res://scripts/hush_boss.gd"}
const DESCENT := "res://scripts/modes/descent.gd"

var _passed := 0
var _failed := 0
var game: Node
var _fx := {}


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = root.get_node_or_null("Game")
	_check(game != null, "the Game autoload is there")
	if game == null:
		print("test_progression: %d passed, %d failed" % [_passed, _failed])
		quit(1)
		return
	var kept_save: String = game.save_path
	var kept_settings: String = game.settings_path
	game.save_path = SAVE
	game.settings_path = SETTINGS
	_wipe()
	game.reset()
	_test_curve()
	_test_xp_budget()
	_test_balance_bands()
	_test_bands_v3()
	_test_defence_guards()
	_test_share_caps()
	_test_forced_anointed()
	_test_road_xp()
	_test_combat_v3()
	_test_xp_v3()
	_test_item_rolls()
	_test_items_misc()
	_test_items_v3()
	_test_relics_v3()
	_test_hero_caps()
	_test_hero_v3()
	_test_legends()
	_test_items_p1()
	_test_legends_p1()
	_test_relics_p1()
	_test_loot_build1()
	_test_boss_boons()
	_test_deep_tree()
	_test_registry()
	_test_migration()
	_test_migration_v2()
	_test_owner_saves()
	_test_round_trip()
	_test_game_api_v3()
	_test_respec_and_vigil()
	_test_belt()
	_test_skill_gates()
	_test_altar_rites()
	_test_new_calling()
	_test_satchel_full()
	_test_salvage_weaker()
	_test_equip_full()
	_test_settings_cache()
	_test_chandler_logic()
	_test_chandler_depth()
	_test_reserve()
	_test_draughts()
	_test_rekindle()
	_test_gifts_and_cards()
	_test_secret_prize()
	_test_milestones_reached()
	await _test_dims_reach_douse()
	_test_descent_xp()
	await _test_chandler_screen()
	await _test_chandler_screen_v3()
	await _test_chandler_names()
	_test_no_movement()
	_wipe()
	game.save_path = kept_save
	game.settings_path = kept_settings
	game.load_save()
	print("test_progression: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _wipe() -> void:
	for p in [SAVE, SETTINGS, SAVE + ".tmp", SAVE + ".bad", SAVE + ".bak", SAVE + ".v1", SAVE + ".v2", SETTINGS + ".tmp", SETTINGS + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _fresh() -> void:
	## An empty save with a Candleknight made.
	_wipe()
	game.reset()
	game.new_hero("knight")


# ---------------------------------------------------------------- the curve

func _test_curve() -> void:
	var ok := true
	for l in range(1, Progression.CAP + 1):
		if Progression.level_of(Progression.total_to(l)) != l:
			ok = false
			print("  level_of(total_to(%d)) = %d" % [l, Progression.level_of(Progression.total_to(l))])
		if l > 1 and Progression.level_of(Progression.total_to(l) - 1) != l - 1:
			ok = false
	_check(ok, "level_of(total_to(L)) == L, and one XP short is L-1, for L 1..%d" % Progression.CAP)
	_check(Progression.CAP == 40 and Combat.LEVEL_CAP == 40, "the cap is L40 (progression and combat agree)")
	_check(Progression.total_to(1) == 0 and Progression.xp_to_next(1) == 80, "L1 starts at 0 XP and needs 80")
	_check(Progression.xp_to_next(Progression.CAP) == 0, "no XP past the cap")
	_check(Progression.level_of(10000000) == Progression.CAP, "XP past the top stays at L40")
	# Spec §1.5: v2's curve exactly to L32, then x1.30 a level.
	var v2 := true
	for l in range(1, 33):
		v2 = v2 and Progression.xp_to_next(l) == roundi(80.0 * pow(1.12, l - 1) * (1.0 + 0.19 * (l - 1)))
	_check(v2, "levels 1-32 cost exactly v2's curve")
	var late := true
	for l in range(33, Progression.CAP):
		var base := 80.0 * pow(1.12, l - 1) * (1.0 + 0.19 * (l - 1))
		late = late and Progression.xp_to_next(l) == roundi(base * pow(1.30, l - 32))
	_check(late, "each level from 33 costs another x1.30")
	var table := {13: [1022, 4429], 16: [1686, 8093], 18: [2323, 11760], 20: [3176, 16802], 24: [5822, 33009],
			26: [7820, 45582], 30: [13931, 84984], 32: [18496, 114974], 33: [27672, 133470], 35: [61812, 202514],
			38: [205368, 494328]}
	var rows := true
	for l in table:
		rows = rows and Progression.xp_to_next(l) == int(table[l][0]) and Progression.total_to(l) == int(table[l][1])
	_check(rows and Progression.total_to(40) == 1005787, "the spec's table: to next and totals (L40 at 1,005,787)")
	var rising := true
	for l in range(1, Progression.CAP - 1):
		rising = rising and Progression.xp_to_next(l + 1) > Progression.xp_to_next(l)
	_check(rising, "every level needs more than the last")
	_check(absf(Progression.level_frac(Progression.total_to(4) + Progression.xp_to_next(4) / 2) - 4.5) < 0.01, "level_frac: halfway to L5 is 4.5")
	# The gap rule: over-leveled earns less, under-leveled more.
	_check(Progression.gap_mult(5, 5) == 1.0 and Progression.gap_mult(8, 5) == 1.0, "no gap penalty within 3 levels")
	_check(Progression.gap_mult(10, 5) < 1.0 and Progression.gap_mult(30, 1) == 0.1, "over-leveled XP shrinks to a floor of 10%")
	_check(Progression.gap_mult(1, 5) == 2.0, "under-leveled XP doubles at most")
	_check(Progression.kill_xp("skeleton", 1, 1, "dusk") == 5 and Progression.kill_xp("skeleton", 1, 1, "dusk", "", true) == 3, "a Rattle is worth 5 XP at A1, half when respawned")
	_check(Progression.kill_xp("skeleton", 1, 1, "dusk", "dread") == 30, "a Dread is worth 6x")
	_check(Progression.kill_xp("thornback", 11, 11, "nightfall") > Progression.kill_xp("thornback", 11, 11, "dusk"), "Nightfall pays more XP")


# ---------------------------------------------------------------- XP budget

func _first_run_events(lv: RefCounted, road := -1) -> Array:
	## Everything that pays XP on a first Dusk clear, as [x, what, kind, share]
	## in the order a hero running right meets it: every monster, the Dread,
	## half an Anointed (none in 1-1), every forced Anointed (its anoint:
	## cell, Build 2) in full, 2 of the 3 sigils, altars, reliquaries, and the
	## first-clear bell. In a level taller than a strip x is how far along
	## its route on foot (the order he meets it); with roads (two ways
	## through: Rules.road_of) road picks one: what's on the other road alone
	## isn't on his way (-1: everything, as v2's walk).
	var ev := []
	var sigils := []
	var dread_x := -1
	var kinds := {}
	var forced := Rules.forced_cells(lv)
	var along := _along(lv, road)
	for e in lv.entities:
		var k: String = e["kind"]
		if road >= 0 and not Rules.road_of(lv, e["cell"]).has(road):
			continue
		var x: int = along.call(e["cell"])
		if k == "boss":
			ev.append([x, "kill", lv.boss if lv.boss != "" else "tollgrave", 1.0])
		elif Progression.BASE_XP.has(k):
			ev.append([x, "kill", k, 1.0])
			if forced.has(e["cell"]):
				ev.append([x, "anointed", k, 1.0])
			if FODDER.has(k):
				kinds[k] = int(kinds.get(k, 0)) + 1
		elif k == "dread":
			dread_x = x
		elif k == "sigil":
			sigils.append(x)
		elif k == "altar":
			ev.append([x, "altar", "", 1.0])
	for cell in lv.blocks:
		if road < 0 or Rules.road_of(lv, cell).has(road):
			ev.append([along.call(cell), "reliquary", "", 1.0])
	sigils.sort()
	for i in mini(2, sigils.size()):
		ev.append([sigils[i], "sigil", "", 1.0])
	var dread_kind: String = str(lv.dread.get("kind", DREAD_FALLBACK.get(lv.id, "")))
	if dread_kind != "":
		ev.append([dread_x if dread_x >= 0 else lv.width / 2, "dread", dread_kind, 1.0])
	if lv.id != "1-1" and not kinds.is_empty():
		var common := ""
		for k in kinds:
			if common == "" or int(kinds[k]) > int(kinds[common]):
				common = k
		ev.append([lv.width / 2, "anointed", common, 0.5])
	ev.sort_custom(func(a, b): return a[0] < b[0])
	ev.append([lv.width, "first_clear", "", 1.0])
	return ev


func _along(lv: RefCounted, road := -1) -> Callable:
	## A cell's place in the walk's order: its x in a strip; in a taller
	## level its distance on foot along the route (road's, with roads: the
	## nearest state of WalkMap.roads()'s path; common.road_gaps measures so).
	if lv.height <= LevelData.STRIP_ROWS:
		return func(c: Vector2i) -> int: return c.x
	var m = load("res://scripts/walk_map.gd").of(lv)
	var path: Array = m.roads()[maxi(road, 0)]["path"]
	if path.is_empty():
		return func(c: Vector2i) -> int: return c.x
	var run: Array = m.run_lengths(path)
	return func(c: Vector2i) -> int: return int(run[Rules._nearest(m, path, c)])


func road_xp(lv: RefCounted, xp: int) -> Array:
	## [the XP after a first clear by each road] (one entry: no roads).
	var n: int = load("res://scripts/walk_map.gd").of(lv).roads().size() if lv.height > LevelData.STRIP_ROWS else 1
	if n < 2:
		return [_play(lv, xp)]
	var out := []
	for r in n:
		out.append(_play(lv, xp, r))
	return out


func _play(lv: RefCounted, xp: int, road := -1) -> int:
	## The hero's XP after a first clear of lv, leveling as it arrives (road:
	## by that road only; _first_run_events).
	var a: int = Combat.area_level(lv.area, "dusk")
	for e in _first_run_events(lv, road):
		var lvl := Progression.level_of(xp)
		var what: String = e[1]
		var kind: String = e[2]
		var n := 0.0
		match what:
			"kill":
				n = Progression.kill_xp(kind, a, lvl, "dusk")
			"dread":
				n = Progression.kill_xp(kind, a, lvl, "dusk", "dread")
			"anointed":
				# An Anointed is a promoted monster: it pays the difference.
				n = Progression.kill_xp(kind, a, lvl, "dusk", "anointed") - Progression.kill_xp(kind, a, lvl, "dusk")
			_:
				n = Progression.event_xp(what, a)
		xp += roundi(n * float(e[3]))
	return xp


func _test_xp_budget() -> void:
	## The first-Dusk-run walk over every main level file (secrets skipped),
	## against EXIT_TARGET: v2's slack in Worlds 1-2, EXIT_SLACK_DEEP in 3-6.
	## PENDING until the W3-W6 files exist: each missing level is played from
	## the spec's model (v3_balance.json: §3.10's monsters, §3.1's altars,
	## §4.6's Dreads) so the chain carries on; the model's rows are checked
	## (within the same slack) only while no W3-W6 file is built at all, and
	## each real file is checked as soon as it lands. Tune the new kinds'
	## BASE_XP, never the curve.
	var fx := _fixture()
	var xp := 0
	var rows := []
	var model_rows := []
	var missing := []
	var pure_model: bool = not game.ALL_LEVELS.any(func(l): return int(l["world"]) >= 3 and FileAccess.file_exists(l["path"]))
	var model_off := []
	for info in game.ALL_LEVELS:
		var id := str(info["id"])
		var want: float = EXIT_TARGET.get(id, -1.0)
		var slack := EXIT_SLACK if int(info["world"]) <= 2 else EXIT_SLACK_DEEP
		if FileAccess.file_exists(info["path"]):
			var lv: RefCounted = LevelData.load_file(info["path"])
			# Two roads: the poorer road's XP is what a run is sure of (and
			# the gap between them is reported: their XP parity).
			var by: Array = road_xp(lv, xp)
			xp = by.min()
			var got := Progression.level_frac(xp)
			rows.append("%s %.2f (target %.1f)%s" % [id, got, want, "" if by.size() < 2 else " roads %s" % [by.map(func(v): return "%.2f" % Progression.level_frac(v))]])
			if want > 0.0:
				_check(absf(got - want) <= slack, "XP budget: leaving %s at L%.2f, the target %.1f (+-%.1f)" % [id, got, want, slack])
		elif int(info["world"]) >= 3 and (fx.get("placements", {}) as Dictionary).has(id):
			missing.append(id)
			xp = _play_model(id, xp, fx)
			var got := Progression.level_frac(xp)
			model_rows.append("%s %.2f (spec %.1f)" % [id, got, want])
			if absf(got - want) > slack:
				model_off.append("%s %.2f vs %.1f" % [id, got, want])
	print("  first Dusk run exit levels: ", ", ".join(rows))
	if not missing.is_empty():
		print("  PENDING: the XP-budget walk over the real files waits for %s (%d levels); the spec's model plays them: %s"
				% [", ".join(missing), missing.size(), ", ".join(model_rows)])
		if pure_model:
			_check(model_off.is_empty(), "the spec's model of W3-W6 (§3.10's monsters, today's BASE_XP) lands every exit within +-%.1f (%s)" % [EXIT_SLACK_DEEP, model_off])


func _test_road_xp() -> void:
	## The XP walk in a level with two roads (the shape labs' split roads,
	## tools/levels/lab_shaped.py): each road's walk pays its own monsters
	## and sigil and the ones they share, never the other road's; the level's
	## budget is the poorer road's; a strip's walk is unchanged.
	var lv: RefCounted = LevelData.load_file("res://levels/lab-shape-roads.txt")
	var kills := func(r: int) -> Array:
		return _first_run_events(lv, r).filter(func(e): return e[1] == "kill").map(func(e): return e[2])
	var all_k: Array = _first_run_events(lv).filter(func(e): return e[1] == "kill")
	var hi: Array = kills.call(0)
	var lo: Array = kills.call(1)
	_check(all_k.size() == 4 and hi.size() == 2 and lo.size() == 2 and hi.count("skeleton") == 2 and lo.has("bat"),
			"two roads: the high road's walk pays its two Rattles, the low road's its Rattle and bat, never both (%s, %s)" % [hi, lo])
	var sig := func(r: int) -> int: return _first_run_events(lv, r).filter(func(e): return e[1] == "sigil").size()
	_check(sig.call(0) == 2 and sig.call(1) == 2, "each road's walk takes 2 of its 3 sigils on its way (%d, %d)" % [sig.call(0), sig.call(1)])
	var by: Array = road_xp(lv, 0)
	_check(by.size() == 2 and by.min() < _play(lv, 0), "the budget is the poorer road's (%s; both counted: %d)" % [by, _play(lv, 0)])
	var strip: RefCounted = LevelData.load_file("res://levels/1-1.txt")   # (1-2 is a stair since Build 2; 1-1 stays a strip)
	_check(road_xp(strip, 0) == [_play(strip, 0)], "a strip's walk is as it was")


func _test_forced_anointed() -> void:
	## Build 2's forced Anointed (anoint: cells) in the two level walks, on
	## the toolkit's fixture: the XP walk pays each in full (on top of the
	## random half an Anointed), and the share-cap scan judges each as
	## Anointed whatever its ground (its Bonebow on a one-tile post and its
	## Stillmaw over the open floor, where safe_for says no).
	if not FileAccess.file_exists(TOOLKIT_FIXTURE):
		_check(false, "the toolkit fixture %s is written (tools/levels/toolkit.py)" % TOOLKIT_FIXTURE)
		return
	var lv: RefCounted = LevelData.load_file(TOOLKIT_FIXTURE)
	var bare: RefCounted = LevelData.load_file(TOOLKIT_FIXTURE)
	bare.headers.erase("anoint")
	var forced := []
	for e in _first_run_events(lv):
		if e[1] == "anointed" and float(e[3]) == 1.0:
			forced.append("%s@%d" % [e[2], e[0]])
	forced.sort()
	_check(forced == ["bonebow@33", "stillmaw@72", "thornback@37"], "the XP walk pays each forced Anointed in full (%s)" % [forced])
	var halves := _first_run_events(bare).filter(func(e): return e[1] == "anointed")
	_check(halves.size() == 1 and float(halves[0][3]) == 0.5, "and still half a random one, as a level with none forced (%s)" % [halves])
	_check(_play(lv, 0) > _play(bare, 0), "so a level's forced Anointed raise its first-run XP (%d > %d)" % [_play(lv, 0), _play(bare, 0)])
	var el = load("res://scripts/elites.gd")
	var cast := _level_cast({"id": "toolkit-cast", "path": TOOLKIT_FIXTURE}, _fixture())
	_check(not bool(el.safe_for(lv, Vector2i(33, 9), "bonebow", false)) and not bool(el.safe_for(lv, Vector2i(72, 5), "stillmaw", true)),
			"(the fixture's Bonebow and Stillmaw stand where pick_elites would never anoint them)")
	_check((cast["safe"] as Dictionary).has("bonebow") and (cast["safe"] as Dictionary).has("stillmaw"),
			"the share-cap scan judges forced Anointed as Anointed whatever their ground (%s)" % [cast["safe"].keys()])


func _fixture() -> Dictionary:
	## tests/fixtures/v3_balance.json, read once ({} without it).
	if _fx.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(V3_FIXTURE))
		_fx = j if j is Dictionary else {}
	return _fx


func _play_model(id: String, xp: int, fx: Dictionary) -> int:
	## A first Dusk clear of a level that isn't built, from the spec's model:
	## every monster placed, the Dread, half an Anointed of the commonest
	## fodder, 2 of 3 sigils, its altars and reliquaries, the boss, the bell.
	var a: int = Combat.area_level(int(game.AREAS.get(id, 1)), "dusk")
	var w := int(id.left(1))
	var boss: bool = game.is_boss_level(id)
	var ev := []
	var kinds := {}
	var place: Dictionary = fx["placements"].get(id, {})
	for k in place:
		for i in int(place[k]):
			ev.append(["kill", str(k), 1.0])
		if FODDER.has(str(k)):
			kinds[str(k)] = int(kinds.get(str(k), 0)) + int(place[k])
	var alt: Dictionary = fx.get("altars", {})
	for i in int(alt.get("boss", 2) if boss else alt.get(str(w), 3)):
		ev.append(["altar", "", 1.0])
	for i in int(fx.get("reliquaries", 3)):
		ev.append(["reliquary", "", 1.0])
	for i in 2:
		ev.append(["sigil", "", 1.0])
	if (fx.get("dreads", {}) as Dictionary).has(id):
		ev.append(["dread", str(fx["dreads"][id]), 1.0])
	if not kinds.is_empty():
		var common := ""
		for k in kinds:
			if common == "" or int(kinds[k]) > int(kinds[common]):
				common = k
		ev.append(["anointed", common, 0.5])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in range(ev.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = ev[i]
		ev[i] = ev[j]
		ev[j] = t
	if boss:
		for b in fx.get("bosses", {}):
			if str(fx["bosses"][b]["level"]) == id:
				ev.append(["kill", str(b), 1.0])
	ev.append(["first_clear", "", 1.0])
	for e in ev:
		var lvl := Progression.level_of(xp)
		var n := 0.0
		match str(e[0]):
			"kill":
				n = Progression.kill_xp(e[1], a, lvl, "dusk")
			"dread":
				n = Progression.kill_xp(e[1], a, lvl, "dusk", "dread")
			"anointed":
				n = Progression.kill_xp(e[1], a, lvl, "dusk", "anointed") - Progression.kill_xp(e[1], a, lvl, "dusk")
			_:
				n = Progression.event_xp(str(e[0]), a)
		xp += roundi(n * float(e[2]))
	return xp


# ---------------------------------------------------------------- balance

func _reference(level: int, area: int) -> Dictionary:
	## The balance test's Candleknight: Blessed gear at ilvl = area with
	## median rolls (a Keen weapon, a Waxen candle, a Warded coat), and half
	## his points in stat nodes, taken in turn: Honed Blade, Tempered Steel,
	## Keen Edge. No relics.
	var h := Hero.blank("knight", level)
	h["equip"] = Items.starter("knight", area, "magic")
	var stat_points := (level - 1) / 2
	var order := ["k_honed", "k_tempered", "k_keen"]
	var i := 0
	while stat_points > 0 and i < 30:
		var id: String = order[i % order.size()]
		i += 1
		if int(h["skills"].get(id, 0)) < 2:
			h["skills"][id] = int(h["skills"].get(id, 0)) + 1
			stat_points -= 1
	return h


func _enemy_base(path: String, fallback: Dictionary) -> Dictionary:
	var sc = load(path)
	if sc == null:
		return fallback
	var e = sc.new()
	var out := {"hp": float(e.base_hp), "dmg": float(e.base_dmg)}
	e.free()
	return out


func _test_balance_bands() -> void:
	var rattle := _enemy_base("res://scripts/skeleton.gd", {"hp": 18.0, "dmg": 30.0})
	var thorn := _enemy_base("res://scripts/thornback.gd", {"hp": 42.0, "dmg": 34.0})
	var entry := 1
	var rows := []
	for info in game.LEVELS:
		if info["world"] != 1:
			continue
		var lv: RefCounted = LevelData.load_file(info["path"])
		var a: int = Combat.area_level(lv.area, "dusk")
		var exit_l := int(floor(float(EXIT_TARGET.get(lv.id, entry))))
		# (A boss level's exit comes with the boss's fall, its XP most of the
		# level's: he never plays it at that level. 1-4 leaves at L8.)
		var last := exit_l - 1 if lv.entities.any(func(e): return e["kind"] == "boss") else exit_l
		for l in range(entry, maxi(last, entry) + 1):
			var s := Hero.stats(_reference(l, a), [], "dusk")
			var hit: float = float(s["basic"]) * (1.0 + float(s["dmg_pct"]))
			var e := Combat.e_scale(a)
			var k_rattle := ceili(rattle["hp"] * e / hit)
			var k_thorn := ceili(thorn["hp"] * e / hit)
			var blow := Combat.mitigate(Combat.enemy_hit(rattle["dmg"], a, "dusk"), float(s["dr"]))
			var snuff := ceili(float(s["max_hp"]) / blow)
			rows.append("%s L%d: %d/%d swings, %d hits" % [lv.id, l, k_rattle, k_thorn, snuff])
			_check(k_rattle >= 1 and k_rattle <= 3, "%s at L%d: a Rattle takes %d swings (want 1-3)" % [lv.id, l, k_rattle])
			_check(k_thorn >= 3 and k_thorn <= 5, "%s at L%d: a Thornback takes %d swings (want 3-5)" % [lv.id, l, k_thorn])
			_check(snuff >= 3 and snuff <= 5, "%s at L%d: %d Rattle hits snuff him (want 3-5)" % [lv.id, l, snuff])
		entry = maxi(exit_l, 1)
	print("  reference knight: ", "; ".join(rows))
	# A max-defence build at the end of World 1 (the cap's job): everything
	# on life, the Tallow Heart, all Tempered Steel. Still at most 7 hits.
	var h := _reference(7, 6)
	h["skills"] = {"k_tempered": 2}
	for slot in ["candle", "coat"]:
		h["equip"][slot]["affixes"] = [{"id": "waxen", "t": 1, "v": 8.0}]
	var s := Hero.stats(h, ["tallow_heart"], "dusk")
	var blow := Combat.mitigate(Combat.enemy_hit(rattle["dmg"], 6, "dusk"), float(s["dr"]))
	var n := ceili(float(s["max_hp"]) / blow)
	print("  max-life knight at 1-4, L7: %d life, %d Rattle hits" % [int(s["max_hp"]), n])
	_check(n <= 7, "even a max-life L7 knight at 1-4 falls to 7 Rattle hits or fewer (%d)" % n)


func _reference3(level: int, area: int, marks := 0) -> Dictionary:
	## spec §1.3's reference Candleknight for v3 (the deep tree on): Blessed
	## gear at ilvl = area, each piece's signature affix at a median roll (a
	## Keen weapon, a Waxen candle, a Warded coat; Warded boots from area 13
	## and a Keen charm from 18), half his points in stat nodes in turn (Honed
	## Blade, Tempered Steel, Keen Edge, and Vigilant Edge from L16), Vigil
	## ranks past a full tree, Candlemarks when asked (L40), no relics.
	var h := Hero.blank("knight", level)
	h["equip"] = Items.starter("knight", area, "magic")
	for slot in ["boots", "charm"]:
		if area < (13 if slot == "boots" else 18):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(slot + str(area))
		var it := Items.make(slot, "knight", area, "common", rng)
		var sig: String = Items.SIGNATURE[slot]
		it["rarity"] = "magic"
		it["affixes"] = [{"id": sig, "t": int(it["tier"]), "v": Items.median(sig, int(it["tier"]))}]
		h["equip"][slot] = it
	var stat_points := (level - 1) / 2
	var order := ["k_honed", "k_tempered", "k_keen", "k_vigilant"]
	var most := {"k_honed": 2, "k_tempered": 2, "k_keen": 2, "k_vigilant": 3}
	var i := 0
	while stat_points > 0 and i < 80:
		var id: String = order[i % order.size()]
		i += 1
		if id == "k_vigilant" and level < 16:
			continue
		if int(h["skills"].get(id, 0)) < int(most[id]):
			h["skills"][id] = int(h["skills"].get(id, 0)) + 1
			stat_points -= 1
	h["vigil"] = maxi(0, level - 1 - 32)
	h["xp"] = Progression.total_to(level) + (marks * Progression.MARK_XP if level >= Progression.CAP else 0)
	return h


func _arrival(id: String) -> int:
	## The reference knight's level where a level is met: the level before's
	## exit (floored); a secret level is met at its world's boss (its area).
	if game.is_secret(id):
		return _arrival("%s-4" % id.left(1))
	for i in game.ALL_LEVELS.size():
		if str(game.ALL_LEVELS[i]["id"]) == id:
			return 1 if i == 0 else int(floor(float(EXIT_TARGET[str(game.ALL_LEVELS[i - 1]["id"])])))
	return 1


func _test_bands_v3() -> void:
	## spec §1.3 / p_progression §16.3's bands for the new worlds, with the
	## reference knight (deep tree) at the level each level is entered at
	## (a boss level's entry is the boss's arrival; the exit level is
	## printed): Rattle-class fodder (18 life, 30 blow) and Thornback-class
	## heavies (42 life), their life on e_hp (Depth) and blows on e_dmg, no
	## world trim (the spec's table is untrimmed; the share-cap scan below
	## has the trim). Then Nightfall and Witching at p_progression §6.2's rows.
	var rattle := _enemy_base("res://scripts/skeleton.gd", {"hp": 18.0, "dmg": 30.0})
	var thorn := _enemy_base("res://scripts/thornback.gd", {"hp": 42.0, "dmg": 34.0})
	var bands := {3: [1, 3, 3, 5, 3, 6], 4: [1, 3, 3, 5, 3, 5], 5: [1, 3, 3, 5, 3, 5], 6: [2, 3, 3, 5, 3, 4]}
	Classes.set_deep(true)
	var rows := []
	for info in game.ALL_LEVELS:
		var w := int(info["world"])
		if w < 3:
			continue
		var id := str(info["id"])
		var a: int = Combat.area_level(int(game.area_of(id)), "dusk")
		var b: Array = bands[w]
		var entry := _arrival(id)
		var exit_l := maxi(int(floor(float(EXIT_TARGET[id]))), entry)
		var seen := []
		for l in range(entry, exit_l + 1):
			var r := _band_row(l, a, "dusk", rattle, thorn)
			seen.append("L%d %d/%d/%d" % [l, r[0], r[1], r[2]])
			if l != entry:
				continue
			_check(r[0] >= b[0] and r[0] <= b[1] and r[1] >= b[2] and r[1] <= b[3] and r[2] >= b[4] and r[2] <= b[5],
					"%s (area %d) entered at L%d: fodder %d swings, heavy %d, %d fodder hits snuff him (want %d-%d, %d-%d, %d-%d)"
					% [id, a, l, r[0], r[1], r[2], b[0], b[1], b[2], b[3], b[4], b[5]])
		rows.append("%s %s" % [id, " ".join(seen)])
	print("  v3 reference knight (fodder swings / heavy swings / hits to snuff): ", "; ".join(rows))
	# Nightfall and Witching (p_progression §6.2: the whole game at W6-Dusk
	# pressure or more; Witching with 10 Candlemarks at L40).
	var late := {"nightfall": [[30, 32], [33, 34], [35, 35], [37, 36], [38, 37], [40, 38]],
			"witching": [[40, 38], [41, 39], [42, 40], [43, 40], [44, 40], [45, 40]]}
	var lb := {"nightfall": [2, 3, 3, 5, 3, 4], "witching": [2, 4, 4, 8, 2, 3]}
	var out := []
	for dd in late:
		for row in late[dd]:
			var r := _band_row(int(row[1]), int(row[0]), dd, rattle, thorn, 10 if dd == "witching" else 0)
			var b: Array = lb[dd]
			out.append("%s A%d L%d %d/%d/%d" % [dd, row[0], row[1], r[0], r[1], r[2]])
			_check(r[0] >= b[0] and r[0] <= b[1] and r[1] >= b[2] and r[1] <= b[3] and r[2] >= b[4] and r[2] <= b[5],
					"%s area %d at L%d: fodder %d swings, heavy %d, %d hits to snuff (want %d-%d, %d-%d, %d-%d)"
					% [dd, row[0], row[1], r[0], r[1], r[2], b[0], b[1], b[2], b[3], b[4], b[5]])
	print("  late difficulties: ", "; ".join(out))
	Classes.set_deep(false)


func _band_row(level: int, area: int, dd: String, rattle: Dictionary, thorn: Dictionary, marks := 0) -> Array:
	## [fodder swings, heavy swings, fodder hits to snuff] for the reference.
	var s := Hero.stats(_reference3(level, area, marks), [], dd)
	var hit: float = float(s["basic"]) * (1.0 + float(s["dmg_pct"]))
	var life_k := Combat.e_hp(area) * float(Combat.diff(dd)["hp"])
	var blow := Combat.mitigate(Combat.enemy_hit(rattle["dmg"], area, dd), float(s["dr"]))
	return [ceili(rattle["hp"] * life_k / hit), ceili(thorn["hp"] * life_k / hit), ceili(float(s["max_hp"]) / blow)]


func _test_defence_guards() -> void:
	## p_progression §16.4: no defence build makes a hero unkillable. A
	## capped-life (+60%), capped-DR (35%) L32 knight at 6-4 (area 31) falls
	## to 5 Rattle-class hits or fewer; an L40 one with 25 Candlemarks and 7
	## Vigil ranks at Witching 6-4 (area 45) to 4 or fewer. The Rattle-class
	## blow as the bands take it (untrimmed); W6's trim is printed beside.
	Classes.set_deep(true)
	var rattle := _enemy_base("res://scripts/skeleton.gd", {"hp": 18.0, "dmg": 30.0})
	var trim := _trim(6)
	for row in [[32, 31, "dusk", 0, 5], [40, 45, "witching", 25, 4]]:
		var h := _reference3(int(row[0]), int(row[1]), int(row[3]))
		var s := Hero.stats(h, [], str(row[2]))
		# Cap it: everything on life and armour.
		var life := float(s["max_hp"]) / (1.0 + minf(_hp_pct_of(h), Combat.HP_PCT_CAP)) * (1.0 + Combat.HP_PCT_CAP)
		var blow := Combat.enemy_hit(rattle["dmg"], int(row[1]), str(row[2])) * (1.0 - Combat.DR_CAP)
		var n := ceili(life / blow)
		print("  max-defence L%d at %s area %d: %d life, %d Rattle hits (%d with W6's trim x%.2f)" % [row[0], row[2], row[1], int(life), n, ceili(life / (blow * trim)), trim])
		_check(n <= int(row[4]), "a capped-life, capped-DR L%d knight at %s area %d falls to %d Rattle hits or fewer (%d)" % [row[0], row[2], row[1], row[4], n])
	Classes.set_deep(false)


func _hp_pct_of(h: Dictionary) -> float:
	## The +life% the reference has from gear and nodes (before the cap).
	var s := Hero.stats(h, [], "dusk")
	var h0 := h.duplicate(true)
	h0["equip"] = {"weapon": null, "candle": null, "coat": null, "boots": null, "charm": null}
	h0["skills"] = {}
	var s0 := Hero.stats(h0, [], "dusk")
	return float(s["max_hp"]) / float(s0["max_hp"]) - 1.0


func _trim(world: int) -> float:
	## elites.gd DMG_WORLD_TRIM (the kinds' damage by the level's world).
	var sc = load("res://scripts/elites.gd")
	var t = (sc as Script).get_script_constant_map().get("DMG_WORLD_TRIM", {}) if sc != null else {}
	return float(t.get(world, 1.0)) if t is Dictionary else 1.0


func _kind_moves(kind: String, fx: Dictionary) -> Dictionary:
	## {role, moves {id: base damage at area 1}, real}: from the kind's script
	## when it's built (its MOVES const when it declares one, else dmg(id)
	## for each of the spec's move ids it knows, and its base_dmg as touch),
	## else the spec's numbers (v3_balance.json).
	var spec: Dictionary = (fx.get("kinds", {}) as Dictionary).get(kind, {"role": "fodder", "touch": 26.0, "moves": {}})
	var out := {"role": str(spec.get("role", "fodder")), "moves": {"touch": float(spec.get("touch", 26.0))}, "real": false}
	for m in spec.get("moves", {}):
		out["moves"][m] = float(spec["moves"][m])
	var path := "res://scripts/%s.gd" % kind
	if not ResourceLoader.exists(path):
		return out
	var sc = load(path)
	if not (sc is GDScript) or not (sc as GDScript).can_instantiate():
		return out
	var e = (sc as GDScript).new()
	if e.get("base_dmg") == null:
		if e is Node:
			e.free()
		return out
	e.set("dmg_mult", 1.0)
	var base := float(e.base_dmg)
	var moves := {"touch": base}
	var consts: Dictionary = (sc as Script).get_script_constant_map()
	if consts.get("MOVES") is Dictionary:
		for m in consts["MOVES"]:
			moves[m] = float(consts["MOVES"][m])
	elif e.has_method("dmg"):
		for m in spec.get("moves", {}):
			var v := float(e.dmg(m))
			moves[m] = v if not is_equal_approx(v, base) else float(spec["moves"][m])
	if e is Node:
		e.free()
	out["moves"] = moves
	out["real"] = true
	return out


func _level_cast(info: Dictionary, fx: Dictionary) -> Dictionary:
	## Who a level holds: {kinds {kind: n}, dread, warden, boss, real (the
	## file's)}, from its file when it's built, else the spec's model.
	var id := str(info["id"])
	var out := {"kinds": {}, "dread": "", "warden": "", "boss": "", "real": false, "safe": {}}
	if FileAccess.file_exists(info["path"]):
		var lv: RefCounted = LevelData.load_file(info["path"])
		out["real"] = true
		var el = load("res://scripts/elites.gd")
		var ek = load("res://scripts/enemy_kinds.gd")
		var forced := Rules.forced_cells(lv)
		for e in lv.entities:
			var k := str(e["kind"])
			if k == "boss":
				out["boss"] = str(lv.boss)
			elif (fx["kinds"] as Dictionary).has(k) or (Progression.BASE_XP.has(k) and not BOSS_SCRIPTS.has(k)):
				out["kinds"][k] = int(out["kinds"].get(k, 0)) + 1
				# Could this one be anointed where it stands (elites.gd
				# pick_elites' own test: safe_for)? PR's placement-aware row.
				# A forced one (its anoint: cell, Build 2) is, whatever its
				# ground.
				var flier: bool = str((ek.info(k) as Dictionary).get("spawn", "floor")) == "center"
				if forced.has(e["cell"]) or (el != null and bool(el.safe_for(lv, e["cell"], k, flier))):
					out["safe"][k] = true
		out["dread"] = str(lv.dread.get("kind", "")) if lv.dread is Dictionary else ""
		var wd = lv.get("warden")
		out["warden"] = str(wd.get("kind", "")) if wd is Dictionary else ""
		return out
	out["kinds"] = (fx["placements"].get(id, {}) as Dictionary).duplicate()
	out["dread"] = str(fx["dreads"].get(id, ""))
	out["warden"] = str(fx["wardens"].get(id, ""))
	for b in fx["bosses"]:
		if str(fx["bosses"][b]["level"]) == id:
			out["boss"] = str(b)
	return out


func _boss_moves(boss: String, fx: Dictionary) -> Dictionary:
	## {moves, real}, as _kind_moves, for a boss.
	var spec: Dictionary = (fx.get("bosses", {}) as Dictionary).get(boss, {"touch": 24.0, "moves": {}})
	var out := {"moves": {"touch": float(spec.get("touch", 24.0))}, "real": false}
	for m in spec.get("moves", {}):
		out["moves"][m] = float(spec["moves"][m])
	var path: String = BOSS_SCRIPTS.get(boss, "")
	if path == "" or not ResourceLoader.exists(path):
		return out
	var sc = load(path)
	if not (sc is GDScript) or not (sc as GDScript).can_instantiate():
		return out
	var consts: Dictionary = (sc as Script).get_script_constant_map()
	var e = (sc as GDScript).new()
	e.set("dmg_mult", 1.0)
	var base := float(e.get("base_dmg")) if e.get("base_dmg") != null else float(spec.get("touch", 24.0))
	var moves := {"touch": float(e.dmg("touch")) if e.has_method("dmg") else base}
	if consts.get("MOVES") is Dictionary:
		for m in consts["MOVES"]:
			moves[m] = float(consts["MOVES"][m])
	elif e.has_method("dmg"):
		for m in spec.get("moves", {}):
			var v := float(e.dmg(m))
			moves[m] = v if not is_equal_approx(v, base) else float(spec["moves"][m])
	if e is Node:
		e.free()
	out["moves"] = moves
	out["real"] = true
	return out


func _test_share_caps() -> void:
	## spec §1.4's table scan: every move of every kind at every level it
	## appears in (Worlds 3-6 and the secret levels, Dusk), after Depth, the
	## world trim, the elite multipliers and DR, as a share of the reference
	## knight's life where it's met (_arrival): fodder <= 30%, heavies and
	## brutes <= 36%, Anointed (x1.2: where the game could anoint one, and
	## every forced anoint: cell whatever its ground) <= 40%, Dreads (x1.4) and Wardens
	## (x1.25) <= 45%, a boss's biggest blow <= 34% and its touch <= 25%.
	## A failure only where both the level's file and the kind's (or boss's)
	## script are built: the game as it is. Where either is still the spec's
	## model, a breach is printed as a model conflict for its owners.
	var fx := _fixture()
	var caps := Combat.SHARE_CAPS
	var eligible: Array = (fx.get("anoint", []) as Array).duplicate()
	var el = load("res://scripts/elites.gd")
	if el != null:
		for k in (el as Script).get_script_constant_map().get("ELIGIBLE", []):
			if not eligible.has(k):
				eligible.append(k)
	var en = load("res://scripts/enemy.gd")
	var warden_k := float((en as Script).get_script_constant_map().get("WARDEN_DMG", 1.25)) if en != null else 1.25
	Classes.set_deep(true)
	var conflicts := []
	var worst := {}
	var checked := 0
	var moves_of := {}
	for info in game.ALL_LEVELS + game.SECRET_LEVELS:
		if int(info["world"]) < 3:
			continue
		var id := str(info["id"])
		var a: int = Combat.area_level(int(game.area_of(id)), "dusk")
		var trim := _trim(int(info["world"]))
		var s := Hero.stats(_reference3(_arrival(id), a), [], "dusk")
		var life := float(s["max_hp"])
		var keep := 1.0 - clampf(float(s["dr"]), 0.0, Combat.DR_CAP)
		var cast := _level_cast(info, fx)
		var jobs := []   # [kind, tier multiplier, cap key, label]
		for k in cast["kinds"]:
			jobs.append([k, 1.0, "", ""])
			# Anointed only where the game could anoint one (a built level:
			# some placement safe_for; the spec's model: everywhere).
			if eligible.has(k) and (not bool(cast["real"]) or (cast["safe"] as Dictionary).has(k)):
				jobs.append([k, 1.2, "anointed", "Anointed "])
		if str(cast["dread"]) != "":
			jobs.append([cast["dread"], 1.4, "dread", "Dread "])
		if str(cast["warden"]) != "":
			jobs.append([cast["warden"], warden_k, "warden", "Warden "])
		for j in jobs:
			var k: String = j[0]
			if not moves_of.has(k):
				moves_of[k] = _kind_moves(k, fx)
			var km: Dictionary = moves_of[k]
			if km["role"] == "drain":
				continue
			var cap_key: String = j[2] if str(j[2]) != "" else ("fodder" if km["role"] == "fodder" else "heavy")
			for m in km["moves"]:
				var share: float = float(km["moves"][m]) * Combat.e_dmg(a) * trim * float(j[1]) * keep / life
				var tag := "%s%s %s" % [j[3], k, m]
				worst[tag] = maxf(float(worst.get(tag, 0.0)), share)
				checked += 1
				var what := "%s: %s%s's %s is %.0f%% of the L%d knight (cap %.0f%%)" % [id, j[3], k, m, share * 100.0, _arrival(id), float(caps[cap_key]) * 100.0]
				_share_check(share <= float(caps[cap_key]) + 0.0005, bool(cast["real"]) and bool(km["real"]), what, conflicts)
		if str(cast["boss"]) != "":
			var bm := _boss_moves(str(cast["boss"]), fx)
			for m in bm["moves"]:
				var share: float = float(bm["moves"][m]) * Combat.e_dmg(a) * keep / life
				var cap_key := "boss_touch" if m == "touch" else "boss_big"
				checked += 1
				worst["%s %s" % [cast["boss"], m]] = share
				var what := "%s: %s's %s is %.0f%% of the arrival knight, L%d (cap %.0f%%)" % [id, cast["boss"], m, share * 100.0, _arrival(id), float(caps[cap_key]) * 100.0]
				_share_check(share <= float(caps[cap_key]) + 0.0005, bool(cast["real"]) and bool(bm["real"]), what, conflicts)
	Classes.set_deep(false)
	var top := worst.keys()
	top.sort_custom(func(x, y): return float(worst[x]) > float(worst[y]))
	var shown := []
	for t in top.slice(0, 12):
		shown.append("%s %.0f%%" % [t, float(worst[t]) * 100.0])
	print("  share-cap scan: %d blows over W3-W6 and the secrets; the biggest: %s" % [checked, ", ".join(shown)])
	for c in conflicts:
		print("  MODEL CONFLICT (not failing until both the level and the kind are built): ", c)
	_check(checked > 300, "the share-cap scan walked every kind's every move where it appears (%d)" % checked)


func _share_check(ok: bool, real: bool, what: String, conflicts: Array) -> void:
	if real:
		_check(ok, "share cap: " + what)
	elif not ok:
		conflicts.append(what)


# ---------------------------------------------------------------- items

func _test_item_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260925
	var weights: Dictionary = {"common": 60.0, "magic": 32.0, "rare": 7.5, "legendary": 0.5}
	var counts := {}
	var bad := {}
	var clss: Array = Classes.ids()
	var n := 10000
	for i in n:
		var rarity := Items.pick_rarity(weights, rng)
		counts[rarity] = int(counts.get(rarity, 0)) + 1
		var slot: String = Items.SLOTS[rng.randi() % Items.SLOTS.size()]
		var cls: String = clss[rng.randi() % clss.size()]
		var ilvl := rng.randi_range(1, 30)
		var it := Items.make(slot, cls, ilvl, rarity, rng)
		var why := _item_problem(it, slot, cls, ilvl)
		if why != "":
			bad[why] = int(bad.get(why, 0)) + 1
	for why in bad:
		print("  bad roll x%d: %s" % [bad[why], why])
	_check(bad.is_empty(), "10,000 seeded rolls: every item is well formed (affixes in range, no repeats, <= 2 prefixes and suffixes)")
	var total := 0.0
	for r in weights:
		total += float(weights[r])
	for r in weights:
		var got := float(counts.get(r, 0)) / n
		var want := float(weights[r]) / total
		_check(absf(got - want) <= 0.02, "rarity %s rolls %.1f%% of the time (weight %.1f%%)" % [r, got * 100.0, want * 100.0])
	# Every slot can carry a full Rare.
	for slot in Items.SLOTS:
		var most := 0
		for i in 200:
			most = maxi(most, (Items.make(slot, "knight", 12, "rare", rng)["affixes"] as Array).size())
		_check(most == 4, "a Rare %s can roll four affixes" % slot)


func _item_problem(it: Dictionary, slot: String, cls: String, ilvl: int) -> String:
	## "" for a well-formed item, else what's wrong with it.
	var tier := Items.tier_of(ilvl)
	if it["slot"] != slot or int(it["ilvl"]) != ilvl or int(it["tier"]) != tier:
		return "slot, ilvl or tier wrong"
	if str(it["name"]) == "" or str(it["uid"]) == "":
		return "no name or uid"
	if slot != "charm" and not (it["implicit"] as Dictionary).has("id"):
		return "no implicit"
	if slot == "weapon" and it["cls"] != cls:
		return "a weapon for the wrong calling"
	if slot == "weapon" and not (Items.BASES["weapon"][cls] as Array).has(it["base"]):
		return "a weapon base from another calling"
	var seen := {}
	var kinds := {"prefix": 0, "suffix": 0}
	for a in it["affixes"]:
		var id: String = a["id"]
		if not Items.AFFIXES.has(id):
			return "unknown affix " + id
		var d: Dictionary = Items.AFFIXES[id]
		if seen.has(id):
			return "affix twice: " + id
		seen[id] = true
		kinds[d["kind"]] += 1
		if not (d["slots"] as Array).has(slot):
			return "%s can't roll on %s" % [id, slot]
		if int(a["t"]) != tier:
			return "affix tier isn't the item's"
		var rg: Array = d["t"][tier - 1]
		if float(a["v"]) < float(rg[0]) or float(a["v"]) > float(rg[1]):
			return "%s value %s outside %s" % [id, a["v"], rg]
		if id == "keeper" and (tier < 2 or Items.RARITIES.find(it["rarity"]) < 2):
			return "of the Keeper below T2 Rare"
	if kinds["prefix"] > 2 or kinds["suffix"] > 2:
		return "more than 2 prefixes or suffixes"
	var c: Array = Items.AFFIX_COUNT[it["rarity"]]
	var lo: int = c[0] + (1 if slot == "charm" else 0)
	var hi: int = mini(c[1] + (1 if slot == "charm" else 0), 4)
	var got: int = (it["affixes"] as Array).size()
	if got < lo or got > hi:
		return "%s %s has %d affixes" % [it["rarity"], slot, got]
	if it["rarity"] == "legendary":
		var leg: Dictionary = Items.LEGENDS.get(it["legend"], {})
		if leg.is_empty() or leg["slot"] != slot or (leg.has("cls") and leg["cls"] != cls):
			return "a Legendary with the wrong power"
	elif str(it["legend"]) != "":
		return "a legend on a non-Legendary"
	return ""


func _test_items_misc() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Weapon drops are the calling's own.
	for cls in Classes.ids():
		var w := Items.make("weapon", cls, 4, "magic", rng)
		_check(w["cls"] == cls and (Items.BASES["weapon"][cls] as Array).has(w["base"]), "a %s weapon roll is a %s weapon (%s)" % [cls, cls, w["base"]])
	_check(Items.base_name("weapon", "witch", 3) == "Chandelier Staff" and Items.base_name("coat", "", 2) == "Chain Coat", "bases go up a name each tier")
	# Names by rarity.
	var m := Items.make("candle", "knight", 3, "magic", rng)
	_check(str(m["name"]).find(m["base"]) >= 0, "a Blessed item is named around its base (%s)" % m["name"])
	var r := Items.make("coat", "knight", 3, "rare", rng)
	var words: PackedStringArray = str(r["name"]).split(" ")
	_check(words.size() == 2 and Items.RARE_FIRST.has(words[0]) and (Items.RARE_SECOND["coat"] as Array).has(words[1]), "a Rare gets a two-word name (%s)" % r["name"])
	var leg := Items.make("weapon", "knight", 8, "legendary", rng, "dawnsliver")
	_check(leg["name"] == "Dawnsliver" and Items.key_line(leg) == Items.LEGENDS["dawnsliver"]["text"], "a Legendary is named and keyed by its power")
	var no_legend := Items.make("coat", "knight", 8, "legendary", rng, "")
	_check(Items.LEGENDS.has(no_legend["legend"]) and Items.LEGENDS[no_legend["legend"]]["slot"] == "coat"
			and not Items.LEGENDS[no_legend["legend"]].get("secret", false), "a Legendary asked for with no power picks one for its slot (%s)" % no_legend["legend"])
	var charm := Items.make("charm", "witch", 8, "legendary", rng)
	_check(charm["legend"] == "everburning" and charm["cls"] == "witch", "a class charm only rolls for its calling")
	# Starter kits.
	var kit := Items.starter("runner")
	_check(kit["weapon"]["rarity"] == "common" and kit["weapon"]["base"] == "Wick Knife" and kit["boots"] == null, "a first hero's kit is Common, ilvl 1, three pieces")
	var bk := Items.starter("witch", 8, "magic")
	var sig_ok := true
	for slot in ["weapon", "candle", "coat"]:
		var it: Dictionary = bk[slot]
		sig_ok = sig_ok and it["rarity"] == "magic" and int(it["ilvl"]) == 8 and it["affixes"].size() == 1 and it["affixes"][0]["id"] == Items.SIGNATURE[slot]
	_check(sig_ok, "a Blessed kit carries each slot's signature affix at its level")
	_check(bk["weapon"]["name"] == "Keen Taper Staff", "and is named for it (%s)" % bk["weapon"]["name"])
	# Numbers.
	var sword := Items.make("weapon", "knight", 6, "common", rng)
	_check(float(sword["implicit"]["v"]) == 19.0, "a weapon's implicit is 10 + 1.5*ilvl (%s at ilvl 6)" % sword["implicit"]["v"])
	var coat := Items.make("coat", "knight", 30, "common", rng)
	_check(float(coat["implicit"]["v"]) <= Items.COAT_DR_MAX, "a coat's own damage reduction stops at %d%%" % int(Items.COAT_DR_MAX))
	var mods := Items.mods(Items.make("candle", "knight", 10, "common", rng))
	_check(absf(float(mods["max_hp_pct"]) - 0.11) < 0.001 and absf(float(mods["light_pct"]) - 0.07) < 0.001, "a candle gives life and light (T2 ilvl 10: +11%, +7%)")
	_check(Items.price(Items.make("coat", "knight", 5, "magic", rng)) == 70 and Items.price(Items.make("coat", "knight", 5, "rare", rng)) == 190, "Chandler prices: Blessed 30 + 8*ilvl, Rare 90 + 20*ilvl")
	_check(Items.salvage_value(Items.make("coat", "knight", 10, "rare", rng)) == 30, "salvage: Rare 15 x (1 + ilvl/10)")
	var p0 := Items.power(Items.make("coat", "knight", 5, "common", rng))
	var p1 := Items.power(Items.make("coat", "knight", 25, "common", rng))
	_check(p1 > p0 and Items.power(leg) > Items.power(Items.make("weapon", "knight", 8, "common", rng)), "Power grows with ilvl and with a legend")
	_check(Items.describe("keen", 12.0) == "+12% damage" and Items.describe("moth", 1.5) == "Kills heal 1.5% life", "affix lines read cleanly")
	# (a coat of ilvl 30 is T4: its own icon once A8 has drawn it, else T3's)
	var coat_icon := "res://art/items/coat_%d.svg" % (Items.tier_of(30) if ResourceLoader.exists("res://art/items/coat_%d.svg" % Items.tier_of(30)) else 3)
	_check(Items.icon(sword) == "res://art/items/weapon_knight_1.svg" and Items.icon(coat) == coat_icon, "item icons follow the art contract (%s)" % Items.icon(coat))
	_check((Items.lines(r) as Array).size() == 1 + (r["affixes"] as Array).size(), "an item's detail lines: the implicit and each affix")
	# The slot pick: weapons are 35%.
	var w := 0
	for i in 4000:
		if Items.pick_slot(rng) == "weapon":
			w += 1
	_check(absf(w / 4000.0 - 0.35) < 0.03, "weapons are about 35%% of drops (%.1f%%)" % (w / 40.0))
	_test_every_slot_drops()


func _test_every_slot_drops() -> void:
	## Boots and charms drop and are sold like the rest (P1 shipped with
	## World 2): every source picks from LIVE_SLOTS, so every slot and all
	## twelve Legendaries can turn up for their calling.
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	_check(Items.LIVE_SLOTS == Items.SLOTS, "all five slots are live (%s)" % [Items.LIVE_SLOTS])
	var n := {}
	for i in 20000:
		var s := Items.pick_slot(rng)
		n[s] = int(n.get(s, 0)) + 1
	var ok := true
	for s in ["candle", "coat", "boots", "charm"]:
		ok = ok and absf(float(n.get(s, 0)) / 20000.0 - 0.1625) < 0.015
	_check(ok, "boots and charms drop as often as candles and coats, about 16%% each (%s)" % [n])
	# Every Legendary is reachable the way world.gd rolls a boss prize: a
	# live slot, then a power for that slot and calling.
	# (v3: a secret prize only once it's been found; a world's pair only at its depth.)
	var seen := {}
	var secrets: Array = Items.SECRET_PRIZES.values()
	var early := {}
	for cls in Classes.ALL:
		for i in 3000:
			var slot := Items.pick_slot(rng)
			var lg := Items.pick_legend(slot, cls, rng, 99, secrets)
			if lg != "":
				seen[lg] = true
			var lg12 := Items.pick_legend(slot, cls, rng, 12, [])
			if lg12 != "":
				early[lg12] = true
	var never: Array = []
	for id in Items.LEGENDS:
		if not seen.has(id):
			never.append(id)
	_check(never.is_empty(), "every one of the %d Legendaries can drop (never: %s)" % [Items.LEGENDS.size(), never])
	var v3_early: Array = early.keys().filter(func(id): return Items.legend_world(id) >= 2 or Items.LEGENDS[id].has("min_area"))
	_check(v3_early.is_empty() and early.size() == 12, "in Worlds 1-2 (area 12, nothing found) only v2's twelve drop (%d; %s)" % [early.size(), v3_early])
	# Boots and charms roll whole items: a boots implicit, a charm's extra affix.
	var boots := Items.make("boots", "knight", 6, "magic", rng)
	var charm := Items.make("charm", "witch", 6, "common", rng)
	_check(str(boots["implicit"].get("id", "")) == "stomp_pct" and (charm["affixes"] as Array).size() == 1 and Items.key_line(charm) != "",
			"a boots piece has its stomp implicit; a Common charm its one affix")
	_check(ResourceLoader.exists(Items.icon(boots)) and ResourceLoader.exists(Items.icon(charm)), "and both have their icons")


# ---------------------------------------------------------------- hero stats

func _test_hero_caps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Scaling split: life 1.10^(L-1), damage 1.09^(L-1).
	var h := Hero.blank("knight", 10)
	var s := Hero.stats(h)
	_check(absf(float(s["max_hp"]) - roundf(100.0 * pow(1.10, 9))) < 0.5, "L10 life is 100 x 1.10^9 (%s)" % s["max_hp"])
	_check(absf(float(s["basic"]) - 10.0 * pow(1.09, 9)) < 0.01, "L10 damage is 10 x 1.09^9 (%.2f)" % s["basic"])
	_check(absf(float(s["stomp"]) - Combat.STOMP_BASE * pow(1.09, 9)) < 0.01, "stomps scale with damage")
	# Stack everything.
	h = Hero.blank("knight", 12)
	h["skills"] = {"k_tempered": 2, "k_keen": 2, "k_honed": 2}
	var big := {"weapon": [["keen", 30.0], ["precision", 8.0], ["moth", 2.5], ["swift", 15.0]],
			"candle": [["waxen", 22.0], ["bright", 18.0], ["moth", 2.5], ["precision", 8.0]],
			"coat": [["waxen", 22.0], ["warded", 5.0], ["bright", 18.0], ["moth", 2.5]],
			"boots": [["warded", 5.0], ["waxen", 22.0], ["moth", 2.5]],
			"charm": [["waxen", 22.0], ["swift", 15.0], ["precision", 8.0], ["moth", 2.5]]}
	for slot in big:
		var it := Items.make(slot, "knight", 30, "common", rng)
		for a in big[slot]:
			it["affixes"].append({"id": a[0], "t": 3, "v": a[1]})
		h["equip"][slot] = it
	s = Hero.stats(h, ["tallow_heart", "choir_bone"])
	_check(float(s["dr"]) <= Combat.DR_CAP + 1e-6, "damage reduction stops at 35%% (%.3f)" % s["dr"])
	_check(absf(float(s["max_hp"]) - roundf(100.0 * pow(1.10, 11) * 1.6)) < 0.5, "max life stops at +60%% (%s)" % s["max_hp"])
	_check(absf(float(s["on_kill_heal"]) - 0.03) < 1e-6, "on-kill healing stops at 3%% (%.3f)" % s["on_kill_heal"])
	_check(absf(float(s["light_pct"]) - Hero.GEAR_LIGHT_CAP) < 1e-6, "gear light stops at +40%% (%.2f)" % s["light_pct"])
	_check(float(s["crit"]) <= Combat.CRIT_CAP and float(s["attack_speed"]) <= 1.3 + 1e-6, "crit chance and attack speed are capped")
	s = Hero.stats(h, ["bellows"])
	_check(absf(float(s["light_pct"]) - 0.70) < 1e-6, "the Great Bellows adds its 30%% on top of capped gear light (%.2f)" % s["light_pct"])
	var r := Combat.light_radius(1.0, s, "dusk")
	_check(r <= Combat.LIGHT_MAX, "and the light radius still stops at %d px" % int(Combat.LIGHT_MAX))
	# Relic numbers.
	var plain := Hero.stats(Hero.blank("knight", 3))
	var long := Hero.stats(Hero.blank("knight", 3), ["longsword"])
	_check(absf((long["reach"] as Vector2).x / (plain["reach"] as Vector2).x - 1.4) < 0.001 and absf(float(long["flags"]["range_mult"]) - 1.3) < 0.001, "the Longsword: reach x1.4, shots x1.3")
	var heart := Hero.stats(Hero.blank("knight", 3), ["tallow_heart"])
	_check(absf(float(heart["max_hp"]) / float(plain["max_hp"]) - 1.15) < 0.01, "the Tallow Heart: +15% life")
	# Chips: a better sword shows DMG up; an "of the Bell" sword still counts.
	var hero := Hero.blank("knight", 5)
	hero["equip"] = Items.starter("knight", 5)
	var better := Items.make("weapon", "knight", 9, "common", rng)
	var c := Hero.compare(hero, "weapon", better)
	_check(float(c["dmg"]) > 0.0 and float(c["life"]) == 0.0 and Hero.is_upgrade(c), "a stronger sword: DMG up, LIFE even, an upgrade (%s)" % c)
	var bell: Dictionary = (hero["equip"]["weapon"] as Dictionary).duplicate(true)
	bell["affixes"] = [{"id": "bell", "t": 1, "v": 12.0}]
	_check(float(Hero.compare(hero, "weapon", bell)["dmg"]) > 0.0, "the DMG chip counts Special damage too")
	# A Sootrunner's Special hurts only through Thousand Cuts: without it,
	# "of the Bell" adds nothing to her DMG chip (and doesn't auto-equip).
	var runner := Hero.blank("runner", 5)
	runner["equip"] = Items.starter("runner", 5)
	var rbell: Dictionary = (runner["equip"]["weapon"] as Dictionary).duplicate(true)
	rbell["affixes"] = [{"id": "bell", "t": 1, "v": 12.0}]
	var rc := Hero.compare(runner, "weapon", rbell)
	_check(float(rc["dmg"]) == 0.0 and not Hero.is_upgrade(rc), "a Sootrunner without Thousand Cuts: 'of the Bell' is DMG +0 (%s)" % rc)
	runner["skills"]["r_cuts"] = 1
	_check(float(Hero.compare(runner, "weapon", rbell)["dmg"]) > 0.0, "with Thousand Cuts it counts")
	var worse := Hero.compare(hero, "coat", null)
	_check(float(worse["life"]) < 0.0 and not Hero.is_upgrade(worse), "taking the coat off: LIFE down")


func _test_legends() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for id in Items.LEGENDS:
		var leg: Dictionary = Items.LEGENDS[id]
		var cls: String = leg.get("cls", "knight")
		var h := Hero.blank(cls, 8)
		var it := Items.make(leg["slot"], cls, 8, "legendary", rng, id)
		h["equip"][leg["slot"]] = it
		var s := Hero.stats(h)
		var ok: bool = s["legends"].get(id, false) == true
		for k in leg.get("fx", {}):
			ok = ok and s["flags"].has(k) and s["flags"][k] == leg["fx"][k]
		_check(ok, "%s: stats.legends has it and stats.flags carries its numbers" % leg["name"])
	var h := Hero.blank("knight", 8)
	var base := float(Hero.stats(h)["stomp"])
	h["equip"]["boots"] = Items.make("boots", "knight", 8, "legendary", rng, "thornsole")
	var boots_pct := float(Items.mods(h["equip"]["boots"]).get("stomp_pct", 0.0))
	var ts := Hero.stats(h)
	_check(absf(float(ts["stomp"]) - base * (1.0 + boots_pct)) < 0.01 and float(ts["flags"].get("thornsole_stomp", 0.0)) == 2.0,
			"Thornsole Greaves: stats.stomp has only the boots' own bonus; the x2 is a flag the world applies once")
	var doubled := Items.LEGENDS.keys().filter(func(id): return (Items.LEGENDS[id].get("stats", {}) as Dictionary).has("stomp_pct"))
	_check(doubled.is_empty(), "no Legendary adds a stomp bonus on top of the world's (%s)" % [doubled])
	var runner := Hero.blank("runner", 8)
	runner["equip"]["charm"] = Items.make("charm", "runner", 8, "legendary", rng, "moth_queen")
	_check(float(Hero.stats(runner)["res_max"]) == 4.0, "Moth-Queen's Scale: four Smoke pips")
	var knight := Hero.blank("knight", 8)
	knight["equip"]["charm"] = runner["equip"]["charm"]
	_check(not Hero.stats(knight)["legends"].has("moth_queen"), "another calling's charm gives no power")


# ---------------------------------------------------------------- v3: combat

func _test_combat_v3() -> void:
	## contract §7 / spec §1: areas, the knee, Depth, the clamp, the dim floor,
	## elites by world, ember worth, the Hush's checkpoints.
	_check(not Combat.DIFF["dusk"].has("offset") and int(Combat.DIFF["nightfall"]["area0"]) == 30 and int(Combat.DIFF["witching"]["per"]) == 6,
			"DIFF: offset is replaced by area0 and per")
	var heads := [1, 3, 6, 8, 12, 13, 17, 18, 22, 23, 27, 28, 31]
	var nf := [30, 30, 31, 32, 33, 34, 35, 35, 37, 37, 38, 39, 40]
	var wh := [40, 40, 40, 41, 41, 42, 42, 42, 43, 43, 44, 44, 45]
	var ok := true
	for i in heads.size():
		ok = ok and Combat.area_level(heads[i], "dusk") == heads[i] and Combat.area_level(heads[i], "nightfall") == nf[i] \
				and Combat.area_level(heads[i], "witching") == wh[i]
	_check(ok, "areas: Dusk is the header; Nightfall 30-40 and Witching 40-45 (spec §1.1's table)")
	_check(Combat.area_level(0, "dusk") == 1 and Combat.area_level(-4, "nightfall") == 30, "a header below 1 reads as 1")
	# Areas 1-12: exactly v2's 1.12^(A-1), for life, damage and XP alike.
	var same := true
	for a in range(1, 13):
		var v2 := pow(1.12, a - 1)
		same = same and is_equal_approx(Combat.e_scale(a), v2) and is_equal_approx(Combat.e_hp(a), v2) and is_equal_approx(Combat.e_dmg(a), v2)
		same = same and is_equal_approx(Combat.enemy_hit(30.0, a, "dusk"), 30.0 * v2) \
				and is_equal_approx(Combat.enemy_hit(30.0, a, "dusk", "gentle"), 30.0 * v2 * 0.75)
	_check(same, "areas 1-12 scale exactly as v2 (e_scale = e_hp = e_dmg = 1.12^(A-1); enemy_hit too)")
	_check(is_equal_approx(Combat.depth(13, Combat.DEPTH_HP), 1.01) and is_equal_approx(Combat.depth(32, Combat.DEPTH_HP), 1.20)
			and is_equal_approx(Combat.depth(45, Combat.DEPTH_DMG), 1.30) and is_equal_approx(Combat.depth(12, Combat.DEPTH_DMG), 1.0),
			"Depth: +1% life / +1.5% blows an area over 13-32, at most +20% / +30%")
	_check(is_equal_approx(Combat.e_scale(33), pow(1.12, 31) * 1.09) and is_equal_approx(Combat.e_scale(40), pow(1.12, 31) * pow(1.09, 8)),
			"past the knee (32) enemies grow x1.09 an area")
	_check(is_equal_approx(Combat.e_hp(17), pow(1.12, 16) * 1.05) and is_equal_approx(Combat.e_dmg(31), pow(1.12, 30) * 1.285),
			"e_hp and e_dmg are e_scale times Depth")
	var rising := true
	for a in range(1, 60):
		rising = rising and Combat.e_hp(a + 1) > Combat.e_hp(a) and Combat.e_dmg(a + 1) > Combat.e_dmg(a)
	_check(rising, "enemy life and blows rise every area to 60")
	# area_abs overrides; a level without the v3 fields still works.
	var lv := LevelData.new()
	lv.area = 8
	_check(Combat.level_area(lv, "dusk") == 8 and Combat.level_area(lv, "nightfall") == 32, "level_area: the header's area_level when area_abs is unset")
	if "area_abs" in lv:
		lv.set("area_abs", 36)
		_check(Combat.level_area(lv, "witching") == 36, "and area_abs when it's set (the modes)")
		lv.set("area_abs", -1)
		_check(Combat.level_area(lv, "dusk") == 8, "(-1 is unset)")
	_check(Combat.level_area(null, "nightfall") == 30, "and a missing level reads as area 1")
	var stand_in := GDScript.new()   # a v3 level (W0 adds area_abs to LevelData)
	stand_in.source_code = "extends RefCounted\nvar area := 8\nvar area_abs := 36\n"
	stand_in.reload()
	var v3lv: RefCounted = stand_in.new()
	_check(Combat.level_area(v3lv, "dusk") == 36 and Combat.level_area(v3lv, "witching") == 36, "area_abs, when set, is the area on every difficulty")
	v3lv.set("area_abs", -1)
	_check(Combat.level_area(v3lv, "nightfall") == 32, "and -1 means unset")
	# The clamp and the dim floor (world.gd applies them).
	_check(Combat.BLOW_CLAMP == {"dusk": 0.45, "nightfall": 0.60, "witching": 0.0} and is_equal_approx(Combat.blow_cap("dusk", 200.0), 90.0)
			and Combat.blow_cap("witching", 200.0) == INF, "the single-blow clamp: 45% / 60% of max life, none on Witching")
	_check(Combat.DIM_FLOOR == {"dusk": 0.50, "nightfall": 0.40, "witching": 0.30} and is_equal_approx(Combat.DIM_RESIST_CAP, 0.50), "the dim floor and the dim_resist cap")
	_check(is_equal_approx(Combat.dim_mult([0.55, 0.7, 0.75, 0.85], 0.0, "dusk"), 0.50) and is_equal_approx(Combat.dim_mult([0.55], 0.0, "dusk"), 0.55)
			and is_equal_approx(Combat.dim_mult([0.5], 0.5, "dusk"), 0.75) and is_equal_approx(Combat.dim_mult([0.5], 0.9, "dusk"), 0.75)
			and is_equal_approx(Combat.dim_mult([0.2, 0.2], 0.0, "witching"), 0.30),
			"dims multiply, dim_resist eases each (capped at 50%), the product floors per difficulty")
	_check(Combat.SHARE_CAPS["fodder"] == 0.30 and Combat.SHARE_CAPS["heavy"] == 0.36 and Combat.SHARE_CAPS["boss_big"] == 0.34, "the share caps")
	# Elites by world (spec §1.6), Nightfall and Witching as DIFF.
	var er := Combat.elite_rules("dusk", 1)
	var w5 := Combat.elite_rules("dusk", 5)
	_check(is_equal_approx(float(er["anoint"]), float(Combat.DIFF["dusk"]["anoint"])) and int(er["max_anoint"]) == 2 and int(er["omens"]) == 1
			and float(er["second_omen"]) == 0.0 and Combat.elite_rules("dusk", 2) == er, "Dusk Worlds 1-2's elites are v2's DIFF")
	# Build 1: Dusk pushes back from World 3 (about twice v3's chance).
	var rows := {3: [0.12, 3, 0.2], 4: [0.14, 3, 0.3], 5: [0.16, 3, 0.5], 6: [0.18, 4, 0.6]}
	var rows_ok := true
	for wn in rows:
		var r := Combat.elite_rules("dusk", wn)
		var want: Array = rows[wn]
		rows_ok = rows_ok and (is_equal_approx(float(r["anoint"]), float(want[0])) and int(r["max_anoint"]) == int(want[1])
				and int(r["omens"]) == 1 and is_equal_approx(float(r["second_omen"]), float(want[2])))
	_check(rows_ok and is_equal_approx(float(w5["second_omen"]), 0.5),
			"Dusk by world: 12 / 14 / 16 / 18%, max 3 (4 in W6), a second Omen at 20 / 30 / 50 / 60% from W3")
	var more := true
	for wn in range(3, 7):
		more = more and float(Combat.elite_rules("dusk", wn)["anoint"]) > float(Combat.elite_rules("dusk", wn - 1)["anoint"])
	_check(more and float(Combat.elite_rules("dusk", 3)["anoint"]) >= 2.0 * float(er["anoint"]), "and each world from W3 more than the last, twice W1-W2's at least")
	# Dusk with teeth: from World 3 altars heal 40% and ordinary monsters
	# come back on a snuff; Worlds 1-2 (and world 0, a mode or a lab) keep
	# the row's 50% and no respawn. Nightfall and Witching are their rows.
	_check(is_equal_approx(float(Combat.DIFF["dusk"]["altar"]), 0.50) and not bool(Combat.DIFF["dusk"]["respawn"]), "the Dusk row itself is v2's (altars 50%, no respawn)")
	var teeth := true
	for wn in range(0, 7):
		var late := wn >= 3
		teeth = teeth and (Combat.dusk_teeth("dusk", wn) == late and Combat.respawns("dusk", wn) == late
				and is_equal_approx(Combat.altar_heal("dusk", wn), 0.40 if late else 0.50))
	_check(teeth, "Dusk from World 3: altars heal 40% and monsters respawn; Worlds 1-2 and modes heal 50%, none respawn")
	_check(not Combat.dusk_teeth("nightfall", 5) and Combat.respawns("nightfall", 1) and Combat.respawns("witching", 6)
			and is_equal_approx(Combat.altar_heal("nightfall", 5), 0.35) and is_equal_approx(Combat.altar_heal("witching", 1), 0.20),
			"Nightfall and Witching keep their rows (35% / 20%, respawn everywhere)")
	var n := Combat.elite_rules("nightfall", 6)
	_check(is_equal_approx(float(n["anoint"]), 0.12) and int(n["max_anoint"]) == 3 and int(n["omens"]) == 2 and int(Combat.elite_rules("witching", 1)["max_anoint"]) == 4,
			"Nightfall 12% / 3 / 2 Omens, Witching up to 4, in every world")
	# Ember worth: v2's in Worlds 1-2; from W3 DIFF.embers x (1 + (A-1)/6).
	var ew := true
	for a in range(1, 13):
		ew = ew and Combat.ember_worth(a, "dusk") == 1
	_check(ew, "an ember is worth 1 in Worlds 1-2 on Dusk, as in v2")
	_check(Combat.ember_worth(13, "dusk") == 3 and Combat.ember_worth(22, "dusk") == 4 and Combat.ember_worth(27, "dusk") == 5
			and Combat.ember_worth(31, "dusk") == 6 and Combat.ember_worth(30, "nightfall") == 10, "then 3-4 in W3-W4, 4-5 in W5, 5-6 in W6 (spec §8.2)")
	# The Hush's checkpoints only.
	_check(Combat.checkpoint_allowed("dusk", "hush", 2) and Combat.checkpoint_allowed("dusk", "hush", 3) and not Combat.checkpoint_allowed("dusk", "hush", 1)
			and Combat.checkpoint_allowed("nightfall", "hush", 3) and not Combat.checkpoint_allowed("nightfall", "hush", 2)
			and not Combat.checkpoint_allowed("witching", "hush", 3) and not Combat.checkpoint_allowed("dusk", "tinker", 3),
			"checkpoints: Dusk keeps P2 and P3, Nightfall P3, Witching none; only the Hush")


# ---------------------------------------------------------------- v3: XP

func _test_xp_v3() -> void:
	## Every kind of contract §6.3 pays XP (spec §4.2's start values), the
	## bosses progression's, the new events; Candlemarks past L40.
	var kinds := ["rootling", "weepcap", "rattlehound", "creepbone", "tickwind", "spurwheel", "frostbuckle", "hoarowl",
			"glassmite", "gustling", "refractor", "paneguard", "hushling", "stillmaw", "unwick", "lurecoil"]
	var missing := kinds.filter(func(k): return not Progression.BASE_XP.has(k))
	_check(missing.is_empty(), "every new kind has a BASE_XP (missing %s)" % [missing])
	_check(Progression.BASE_XP["rootmother"] == 300 and Progression.BASE_XP["tinker"] == 350 and Progression.BASE_XP["saint"] == 400
			and Progression.BASE_XP["hush"] == 600 and Progression.BASE_XP["tollgrave"] == 150 and Progression.BASE_XP["snuffer"] == 250,
			"boss XP: 300 / 350 / 400 / 600 (Tollgrave and the Snuffer unchanged)")
	var bands := true
	for k in ["rootling", "creepbone", "tickwind", "glassmite", "gustling", "hushling"]:
		bands = bands and int(Progression.BASE_XP[k]) >= 5 and int(Progression.BASE_XP[k]) <= 8
	for k in ["frostbuckle", "lurecoil"]:
		bands = bands and int(Progression.BASE_XP[k]) >= 20 and int(Progression.BASE_XP[k]) <= 24
	_check(bands, "fodder 5-8 and brutes 20-24, inside progression's bands")
	_check(Progression.event_xp("secret_clear", 1) == 45 and Progression.event_xp("candle", 1) == 2 and Progression.event_xp("depth", 1) == 30
			and Progression.event_xp("secret_clear", 13) == roundi(45.0 * Combat.e_scale(13)), "new events: a secret clear 45, a candle 2, a depth 30 (x E(A); 20 until the track B merge's Descent bound)")
	_check(Progression.kill_xp("hollow_helm", 1, 1, "dusk", "warden") == 14 * 8, "a Warden pays x8")
	_check(Progression.event_xp("sigil", 20) == roundi(15.0 * Combat.e_scale(20)), "XP uses plain e_scale (no Depth)")
	# Candlemarks.
	var top := Progression.total_to(40)
	_check(Progression.marks_of(0) == 0 and Progression.marks_of(top) == 0 and Progression.marks_of(top + 149999) == 0
			and Progression.marks_of(top + 150000) == 1 and Progression.marks_of(top + 150000 * 3 + 7) == 3
			and Progression.marks_of(top + 150000 * 40) == 25, "a Candlemark every 150,000 XP past L40, up to 25")
	_check(is_equal_approx(Progression.mark_frac(top + 75000), 0.5) and Progression.mark_frac(top - 1) == 0.0
			and Progression.mark_frac(top + 150000 * 25) == 1.0, "mark_frac: the way to the next")
	# The belt: v2's four until the screens draw a fifth.
	_check(Progression.belt_slots(24) == (5 if Progression.FIFTH_BELT_AT > 0 else 4) and Progression.belt_next(10) == Progression.FIFTH_BELT_AT
			and Progression.belt_levels().slice(0, 3) == [1, 5, 10], "belt slots at L1 / 5 / 10 (and the fifth at L24 once it's on)")


# ---------------------------------------------------------------- v3: items and relics

func _test_items_v3() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	# On (Phase 1): every icon user clamps to the art drawn, so T4 and T5 roll.
	_check(Items.MAX_TIER == 5 and Items.max_tier == 5 and Items.tier_of(29) == 3 and Items.tier_of(35) == 4 and Items.tier_of(50) == 5,
			"tier_of rolls all five tiers (T4 and T5 on: the icons clamp to the art drawn)")
	# (max_tier stays a knob: 3 is v2's.)
	var kept := Items.max_tier
	Items.max_tier = 3
	_check(Items.tier_of(35) == 3 and Items.tier_of(50) == 3, "max_tier 3 would stop them at T3 (v2)")
	Items.max_tier = 5
	_check(Items.tier_of(9) == 1 and Items.tier_of(10) == 2 and Items.tier_of(20) == 3 and Items.tier_of(30) == 4 and Items.tier_of(39) == 4
			and Items.tier_of(40) == 5 and Items.tier_of(50) == 5, "five tiers: 1-9, 10-19, 20-29, 30-39, 40+")
	_check(Items.TIER_MULT.size() == 5 and is_equal_approx(Items.TIER_MULT[3], 1.36) and is_equal_approx(Items.TIER_MULT[4], 1.46), "TIER_MULT 1.36 / 1.46")
	var bases_ok := true
	for slot in Items.BASES:
		var b = Items.BASES[slot]
		if b is Dictionary:
			for cls in b:
				bases_ok = bases_ok and (b[cls] as Array).size() == 5
		else:
			bases_ok = bases_ok and (b as Array).size() == 5
	_check(bases_ok and Items.base_name("weapon", "knight", 4) == "Carillon Blade" and Items.base_name("charm", "", 5) == "Halo", "five base names in every slot")
	var ranges_ok := true
	for id in Items.AFFIXES:
		var t: Array = Items.AFFIXES[id]["t"]
		ranges_ok = ranges_ok and t.size() == 5
		for i in 5:
			ranges_ok = ranges_ok and float(t[i][0]) <= float(t[i][1])
	_check(ranges_ok, "every affix has five tier ranges")
	var imp := Items.implicit("weapon", 30, 4)
	_check(float(imp["v"]) == roundf((10.0 + 45.0) * 1.36) and float(Items.implicit("coat", 45, 5)["v"]) == Items.COAT_DR_MAX,
			"implicits keep their formulas (a T4 weapon at ilvl 30: +%s%%; the coat's DR still caps)" % imp["v"])
	var bad := 0
	for i in 3000:
		var ilvl := rng.randi_range(28, 60)
		var slot: String = Items.SLOTS[rng.randi() % Items.SLOTS.size()]
		var it := Items.make(slot, "witch", ilvl, ["magic", "rare"][i % 2], rng)
		if _item_problem(it, slot, "witch", mini(ilvl, Items.ILVL_CAP)) != "":
			bad += 1
	_check(bad == 0, "3,000 rolls at item level 28-60: well formed, item level capped at %d (%d bad)" % [Items.ILVL_CAP, bad])
	var deep_rare := Items.make("coat", "knight", 34, "rare", rng)
	var first := str(deep_rare["name"]).split(" ")[0]
	_check(int(deep_rare["tier"]) == 4 and (Items.RARE_FIRST + Items.RARE_FIRST_DEEP).has(first), "a T4 Rare may take a new world's word (%s)" % deep_rare["name"])
	var t4 := Items.make("weapon", "knight", 30, "common", rng)
	_check(Items.icon(t4) == "res://art/items/weapon_knight_4.svg" if ResourceLoader.exists("res://art/items/weapon_knight_4.svg") else Items.icon(t4) == "res://art/items/weapon_knight_3.svg",
			"a T4 icon falls back to T3 until it's drawn (%s)" % Items.icon(t4))
	Items.max_tier = kept
	# The Lantern: in the tables; it rolls in a build with a world whose dims
	# go through world.dim (World 3+), never in a W1-W2 build, where douse and
	# the latch bypass dim_resist (_test_dims_reach_douse).
	_check(Items.AFFIXES.has("lantern") and Items.AFFIXES["lantern"]["stat"] == "dim_resist" and int(Items.AFFIXES["lantern"]["min_tier"]) == 3
			and Items.describe("lantern", 12.0) == "Dimming is 12% weaker", "of the Lantern: dim_resist, T3+, candle / coat / charm")
	var kept_lantern: bool = Items.lantern_live
	var dim_world: bool = game.LEVELS.any(func(l): return int(l["world"]) >= int(game.LANTERN_FROM_WORLD))
	game._refresh_levels()
	_check(Items.LANTERN_LIVE and Items.lantern_live == dim_world and int(game.LANTERN_FROM_WORLD) == 1,
			"and it rolls exactly when World %d+ is built (%s): in a W1-W2 build it would do nothing" % [game.LANTERN_FROM_WORLD, dim_world])
	Items.lantern_live = true
	_check(Items.affix_pool("candle", 3, "rare").has("lantern") and not Items.affix_pool("candle", 2, "rare").has("lantern")
			and not Items.affix_pool("weapon", 3, "rare").has("lantern"), "on: T3+ candles, coats and charms roll it")
	var lantern_mods := Items.mods({"slot": "candle", "implicit": {}, "affixes": [{"id": "lantern", "t": 3, "v": 12.0}]})
	_check(is_equal_approx(float(lantern_mods.get("dim_resist", 0.0)), 0.12), "and it reaches the stats as dim_resist")
	Items.lantern_live = false
	_check(not Items.affix_pool("candle", 3, "rare").has("lantern"), "(lantern_live off keeps it out)")
	Items.lantern_live = kept_lantern
	# Live slots: all five (v2), unless slots_by_area.
	_check(Items.live_slots(1) == Items.LIVE_SLOTS and Items.live_slots(12) == Items.LIVE_SLOTS, "live slots: all five everywhere (v2 drops them from 1-1)")
	Items.slots_by_area = true
	_check(not Items.live_slots(12).has("boots") and Items.live_slots(13).has("boots") and not Items.live_slots(13).has("charm")
			and Items.live_slots(18).size() == 5 and Items.live_slots(30).size() == 5, "slots_by_area: boots from 13, charms from 18 (the spec's rule)")
	Items.slots_by_area = false
	# pick_legend: v2's pick in Worlds 1-2 (area 12, nothing found, nothing
	# owned: v2's twelve, one randi); the area, secret and owned rules.
	var same := true
	for i in 200:
		var r1 := RandomNumberGenerator.new()
		r1.seed = 1000 + i
		var r2 := RandomNumberGenerator.new()
		r2.seed = 1000 + i
		var slot: String = Items.SLOTS[i % 5]
		var pool := []
		for id in Items.LEGENDS:
			var l: Dictionary = Items.LEGENDS[id]
			if l["slot"] == slot and (not l.has("cls") or l["cls"] == "knight") and not l.has("min_area"):
				pool.append(id)
		var want: String = pool[r2.randi() % pool.size()] if not pool.is_empty() else ""
		same = same and Items.pick_legend(slot, "knight", r1, 12, []) == want and r1.state == r2.state
	_check(same, "pick_legend at area 12 picks as v2 did (v2's twelve, same result, same rng use)")
	var owned_pick := {}
	for i in 3000:
		var p := Items.pick_legend("candle", "knight", rng, 99, [], ["gutterlight"])
		owned_pick[p] = int(owned_pick.get(p, 0)) + 1
	var candles := Items.legal_legends("knight", 99, [], ["candle"])
	var share := float(owned_pick.get("gutterlight", 0)) / 3000.0
	var want_share := 1.0 / (1.0 + 3.0 * (candles.size() - 1))
	_check(absf(share - want_share) < 0.03, "one the hero owns is a third as likely (%.2f of %d candles, want %.2f)" % [share, candles.size(), want_share])
	_check(Items.world_legends(3) == [] or Items.world_legends(3) == ["rootbound", "marrow_lantern"], "world_legends: the boss pair, those in LEGENDS")
	_check(Items.SECRET_PRIZES.size() == 6 and Items.SECRET_PRIZES["1-S"] == "hymnal" and Items.WORLD_LEGENDS.size() == 6, "the prizes and pairs are named")
	_check(Items.world_legends(1) == ["tollbreaker"] and Items.world_legends(2) == ["twin_wick"],
			"build 1: Tollgrave's signature prize is Tollbreaker, the Snuffer's the Twin Wick")


func _test_relics_v3() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var all_w := true
	for r in Relics.ALL:
		all_w = all_w and int(r.get("world", 0)) >= 1
	_check(all_w and Relics.world_of("tallow_heart") == 1, "every relic has its world")
	var same := true
	for i in 100:
		var a := RandomNumberGenerator.new()
		a.seed = i
		var b := RandomNumberGenerator.new()
		b.seed = i
		same = same and Relics.roll(a, ["tallow_heart"], "magic", 2) == Relics.roll(b, ["tallow_heart"], "magic", 1)
	_check(same and Relics.for_sale([], 3, 2) == Relics.for_sale([], 3, 1), "v2's relics are World 1's: max_world 1 or 2 is v2's roll")
	_check(Relics.roll(rng, [], "common", 0) == "" and Relics.for_sale([], 3, 0).is_empty(), "and none come from before World 1")


# ---------------------------------------------------------------- v3: hero stats

func _test_hero_v3() -> void:
	var h := Hero.blank("witch", 12)
	var s := Hero.stats(h)
	var keys := ["dim_resist", "shot_dr", "xp_pct", "ember_pct", "flask_pct", "flask_add", "marks", "light_relic"]
	var has_all := true
	for k in keys:
		has_all = has_all and s.has(k)
	_check(has_all and float(s["dim_resist"]) == 0.0 and int(s["flask_add"]) == 0 and int(s["marks"]) == 0, "stats() has the v3 keys, all 0 for a plain hero")
	_check(int(h["deepest"]) == 0 and h["look"] == Hero.LOOK_DEFAULT and h["look"] != null, "a blank hero has deepest 0 and the default look")
	# Caps.
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var c := Items.make("candle", "witch", 40, "rare", rng)
	c["affixes"] = [{"id": "lantern", "t": 5, "v": 30.0}]
	var co := Items.make("coat", "witch", 40, "rare", rng)
	co["affixes"] = [{"id": "lantern", "t": 5, "v": 30.0}]
	h["equip"]["candle"] = c
	h["equip"]["coat"] = co
	_check(is_equal_approx(float(Hero.stats(h)["dim_resist"]), Combat.DIM_RESIST_CAP), "dim_resist stops at 50% (60 worn)")
	# Candlemarks: +1% damage and life each, the life outside the +60% cap.
	var k := Hero.blank("knight", 40)
	k["xp"] = Progression.total_to(40)
	var s0 := Hero.stats(k)
	k["xp"] = Progression.total_to(40) + 3 * Progression.MARK_XP
	var s3 := Hero.stats(k)
	_check(int(s3["marks"]) == 3 and is_equal_approx(float(s3["dmg_pct"]) - float(s0["dmg_pct"]), 0.03)
			and absf(float(s3["max_hp"]) - roundf(float(s0["max_hp"]) * 1.03)) <= 1.0, "3 Candlemarks: +3% damage, x1.03 life")
	k["skills"] = {"k_tempered": 2}
	k["equip"]["candle"] = Items.make("candle", "knight", 30, "common", rng)
	k["equip"]["candle"]["affixes"] = [{"id": "waxen", "t": 3, "v": 22.0}, {"id": "waxen", "t": 3, "v": 22.0}]
	var capped := Hero.stats(k)
	k["xp"] = Progression.total_to(40)
	var capped0 := Hero.stats(k)
	_check(absf(float(capped["max_hp"]) / float(capped0["max_hp"]) - 1.03) < 0.005, "and still x1.03 on top of a capped +60%% (%s vs %s)" % [capped["max_hp"], capped0["max_hp"]])
	# Vigil life: inside the cap with v2's tree (as v2), outside with the deep one.
	var v := Hero.blank("knight", 30)
	v["skills"] = {"k_tempered": 2}
	v["equip"]["coat"] = Items.make("coat", "knight", 20, "common", rng)
	v["equip"]["coat"]["affixes"] = [{"id": "waxen", "t": 3, "v": 22.0}, {"id": "waxen", "t": 3, "v": 22.0}]
	v["vigil"] = 5
	var in_cap := Hero.stats(v)
	v["vigil"] = 0
	var none := Hero.stats(v)
	_check(float(in_cap["max_hp"]) == float(none["max_hp"]), "v2's tree: Vigil life sits inside the capped +60%, as v2 (no gain when capped)")
	Classes.set_deep(true)
	v["vigil"] = 5
	var out_cap := Hero.stats(v)
	Classes.set_deep(false)
	_check(absf(float(out_cap["max_hp"]) / float(none["max_hp"]) - 1.10) < 0.005, "the deep tree: 5 Vigil ranks are x1.10 life outside the cap")


# ---------------------------------------------------------------- Phase 1: items, Legendaries, relics

func _test_items_p1() -> void:
	## p_progression §16.6: 10,000 seeded rolls at each of item levels 5, 15,
	## 25, 35 and 45 (every tier), well formed; the Lantern at T3+ only;
	## medians rise with the tier; the item level cap; Dusk's kill weights.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7117
	var clss: Array = Classes.ids()
	for ilvl in [5, 15, 25, 35, 45]:
		var bad := 0
		var lantern_low := 0
		var tier_ok := true
		for i in 10000:
			var slot: String = Items.SLOTS[i % Items.SLOTS.size()]
			var cls: String = clss[(i / 5) % clss.size()]
			var it := Items.make(slot, cls, ilvl, ["common", "magic", "rare", "legendary"][i % 4], rng)
			if _item_problem(it, slot, cls, ilvl) != "":
				bad += 1
			tier_ok = tier_ok and int(it["tier"]) == Items.tier_of(ilvl)
			for a in it["affixes"]:
				if a["id"] == "lantern" and int(it["tier"]) < 3:
					lantern_low += 1
		_check(bad == 0 and tier_ok, "10,000 rolls at item level %d (T%d): well formed (%d bad)" % [ilvl, Items.tier_of(ilvl), bad])
		_check(lantern_low == 0, "no Lantern below T3 at item level %d" % ilvl)
	var rising := true
	for id in Items.AFFIXES:
		for t in range(2, Items.TIERS + 1):
			if id != "lantern" or t > 3:
				rising = rising and Items.median(id, t) >= Items.median(id, t - 1)
	_check(rising, "every affix's median is at least the tier below's")
	_check(int(Items.make("coat", "knight", 80, "rare", rng)["ilvl"]) == Items.ILVL_CAP and Items.tier_of(Items.ILVL_CAP) == 5, "item level stops at %d (T5)" % Items.ILVL_CAP)
	# Dusk kills get richer with depth (spec §8.1) and, since build 1, roll no
	# Commons (v2's Blessed / Rare / Legendary proportions kept); Nightfall and
	# Witching as v2.
	var w12 := {"common": 0.0, "magic": 80.0, "rare": 19.0, "legendary": 1.0}
	_check(Items.kill_weights(1, "dusk") == w12 and Items.kill_weights(12, "dusk") == w12, "Dusk kills to area 12: 80/19/1, no Commons")
	_check(Items.kill_weights(13, "dusk") == {"common": 0.0, "magic": 76.0, "rare": 22.0, "legendary": 2.0}
			and Items.kill_weights(22, "dusk") == Items.kill_weights(13, "dusk")
			and Items.kill_weights(23, "dusk") == {"common": 0.0, "magic": 70.0, "rare": 27.0, "legendary": 3.0}
			and Items.kill_weights(31, "dusk") == Items.kill_weights(23, "dusk"), "areas 13-22: 76/22/2, 23 on: 70/27/3")
	_check(Items.kill_weights(40, "nightfall")["legendary"] == 2.0 and Items.kill_weights(45, "witching")["rare"] == 21.0
			and Items.kill_weights(40, "nightfall")["common"] == 45.0 and Items.kill_weights(45, "witching")["common"] == 30.0, "Nightfall and Witching kills keep v2's")


func _test_legends_p1() -> void:
	## spec §8.4: 14 new Legendaries (26 in all): the world pairs drop only at
	## their depth, the secret prizes only once found; their powers reach the
	## stats; a boss's world pair.
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	var new_ids := ["rootbound", "marrow_lantern", "escapement", "hoarfrost", "prismglass", "leadlight", "hushbane", "last_candle",
			"hymnal", "deep_chalice", "gravebloom", "hour_hand", "saints_lens", "hollins_ember"]
	var have := new_ids.filter(func(id): return Items.LEGENDS.has(id))
	_check(Items.LEGENDS.size() == 26 and have.size() == 14, "26 Legendaries, the 14 new ones among them (%d)" % have.size())
	_check(Items.LEGENDS["hymnal"]["name"] == "Tessel's Hymnal" and Items.LEGENDS["hoarfrost"]["name"] == "Hoarfrost Mantle", "the approved names")
	var pairs_ok := true
	for w in [3, 4, 5, 6]:
		var pair := Items.world_legends(w)
		pairs_ok = pairs_ok and pair.size() == 2
		for id in pair:
			pairs_ok = pairs_ok and int(Items.LEGENDS[id]["min_area"]) == [13, 18, 23, 28][w - 3] and not Items.LEGENDS[id].get("secret", false)
	var sig_ok := true
	for w in [1, 2]:
		var one := Items.world_legends(w)
		sig_ok = sig_ok and one.size() == 1 and not Items.LEGENDS[one[0]].has("min_area") and not Items.LEGENDS[one[0]].has("cls")
	_check(pairs_ok and Items.world_legends(3) == ["rootbound", "marrow_lantern"] and sig_ok and Items.world_legends(1) == ["tollbreaker"],
			"each new world's boss pair (min_area 13 / 18 / 23 / 28); Worlds 1-2 one signature piece each, v2's, any calling's")
	var secret_ok := true
	for sid in Items.SECRET_PRIZES:
		var lid: String = Items.SECRET_PRIZES[sid]
		secret_ok = secret_ok and Items.LEGENDS[lid].get("secret", false) == true and Items.legend_world(lid) == int(str(sid).left(1))
	_check(secret_ok, "the six prizes are secret, each of its secret level's world")
	# Depth and secrecy in the rolls.
	var early := 0
	var secret_seen := 0
	var deep_seen := {}
	for i in 4000:
		var slot: String = Items.SLOTS[i % 5]
		var lg := Items.pick_legend(slot, "witch", rng, 5, [])
		if Items.LEGENDS.get(lg, {}).has("min_area"):
			early += 1
		var dl := Items.pick_legend(slot, "witch", rng, 30, [])
		if Items.LEGENDS.get(dl, {}).get("secret", false):
			secret_seen += 1
		deep_seen[dl] = true
	_check(early == 0, "at area 5 no v3 Legendary rolls (%d)" % early)
	_check(secret_seen == 0 and deep_seen.has("hushbane") and deep_seen.has("rootbound"), "at area 30 the world pairs roll, the secret prizes don't until found")
	var found_seen := false
	for i in 3000:
		if Items.pick_legend("charm", "knight", rng, 30, ["hymnal"]) == "hymnal":
			found_seen = true
	_check(found_seen, "a found prize rolls again (Tessel's Hymnal, once found)")
	_check(not Items.legal_legends("knight", 17, [], ["weapon"]).has("escapement") and Items.legal_legends("knight", 18, [], ["weapon"]).has("escapement")
			and not Items.legal_legends("knight", 99, [], ["charm"]).has("hymnal") and Items.legal_legends("knight", 99, ["hymnal"], ["charm"]).has("hymnal")
			and not Items.legal_legends("knight", 99, [], ["charm"]).has("moth_queen"), "legal_legends: slot, calling, depth, secrecy")
	# Their powers reach the stats (fx into flags: _test_legends covers every id).
	var h := Hero.blank("knight", 20)
	var base := Hero.stats(h)
	h["equip"]["candle"] = Items.make("candle", "knight", 20, "legendary", rng, "marrow_lantern")
	var ml := Hero.stats(h)
	_check(is_equal_approx(float(ml["dim_resist"]), 0.5) and float(ml["on_kill_heal"]) >= 0.01, "Marrow Lantern: dimming halved (dim_resist 50%), kills heal 1%")
	h["equip"]["candle"] = null
	h["equip"]["charm"] = Items.make("charm", "knight", 20, "legendary", rng, "hymnal")
	var hy := Hero.stats(h)
	_check(is_equal_approx(float(hy["xp_pct"]), 0.15) and is_equal_approx(float(hy["ember_pct"]), 0.25), "Tessel's Hymnal: +15% XP, +25% embers")
	h["equip"]["charm"] = null
	h["equip"]["coat"] = Items.make("coat", "knight", 20, "legendary", rng, "leadlight")
	_check(is_equal_approx(float(Hero.stats(h)["shot_dr"]), 0.40), "Leadlight Hauberk: shots 40% less")
	h["equip"]["coat"] = null
	h["equip"]["candle"] = Items.make("candle", "knight", 20, "legendary", rng, "saints_lens")
	var sl := Hero.stats(h)
	_check(is_equal_approx(float(sl["light_relic"]), 0.15) and float(sl["flags"].get("lens_bonus", 0.0)) == 0.15, "the Saint's Lens: +15% light outside the gear cap; its bonus a flag")
	h["equip"]["candle"] = Items.make("candle", "knight", 20, "legendary", rng, "deep_chalice")
	_check(is_equal_approx(float(Hero.stats(h)["flask_pct"]), 0.25) and float(base["flask_pct"]) == 0.0, "the Deep Chalice: the flask heals 25% more")
	_fresh()
	game.equip(Items.make("candle", "knight", 5, "legendary", rng, "deep_chalice"))
	_check(is_equal_approx(game.flask_heal("dusk"), 0.40 * 1.25) and game.legends_found().has("deep_chalice"), "and Game.flask_heal has it (0.40 x 1.25)")


func _test_relics_p1() -> void:
	## spec §8.3: 8 new relics, each of its world; rolled and sold only from
	## worlds reached; a favored world twice as likely; their numbers.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	_check(Relics.DEEP_LIVE and Relics.ids().size() == 20 and Relics.ALL.size() == 12, "v3's relics are live (DEEP_LIVE, since belt_panel's grid landed): 20 in the codex, v2's 12 in ALL")
	_check(Relics.DEEP.size() == 8 and Relics.known("clockheart") and Relics.get_relic("taper_match")["name"] == "Mother Taper's Match"
			and Relics.world_of("hush_pearl") == 6 and not Relics.known("mainspring"), "the eight, by world (Clockheart, not Mainspring)")
	Relics.deep_live = true
	_check(Relics.ids().size() == 20, "live: twenty in the codex")
	var leaked := 0
	var w3 := 0
	var w3_fav := 0
	for i in 3000:
		var id := Relics.roll(rng, [], "common", 2)
		if Relics.world_of(id) > 2:
			leaked += 1
		if Relics.world_of(Relics.roll(rng, [], "magic", 3)) == 3:
			w3 += 1
		if Relics.world_of(Relics.roll(rng, [], "magic", 3, 3)) == 3:
			w3_fav += 1
	_check(leaked == 0 and Relics.for_sale([], 20, 2).size() == 12, "worlds not reached never roll or sell (%d)" % leaked)
	_check(w3_fav > w3 * 1.4, "a favored world's relics roll about twice as often (%d vs %d of 3000)" % [w3_fav, w3])
	var deep_shelf: Array = Relics.for_sale(Relics.ids().slice(0, 12), 3, 6).map(func(r): return r["id"])
	_check(deep_shelf == ["sporeward", "bone_flute", "taper_match"],
			"the shelf offers the new worlds' once they're reached, one of each rarity, cheapest first (%s)" % [deep_shelf])
	# Their numbers (hero.gd RELIC_MODS and RELIC_FLAGS).
	var h := Hero.blank("witch", 25)
	var s0 := Hero.stats(h, [])
	var s := Hero.stats(h, ["clockheart", "leaded_pane", "sanctum_glass", "hush_pearl", "taper_match"])
	_check(float(s["attack_speed"]) > float(s0["attack_speed"]) and float(s["res_regen"]) > float(s0["res_regen"]) and is_equal_approx(float(s["shot_dr"]), 0.20)
			and is_equal_approx(float(s["elite_pct"]) - float(s0["elite_pct"]), 0.20) and is_equal_approx(float(s["dim_resist"]), 0.5)
			and is_equal_approx(float(s["light_relic"]), 0.10) and int(s["flask_add"]) == 1, "Clockheart, Leaded Pane, Sanctum Glass, Hush Pearl and the Match change their numbers")
	var capped := Hero.stats(h, ["hush_pearl"])
	h["equip"]["candle"] = Items.make("candle", "witch", 25, "legendary", rng, "marrow_lantern")
	_check(is_equal_approx(float(Hero.stats(h, ["hush_pearl"])["dim_resist"]), Combat.DIM_RESIST_CAP) and float(capped["dim_resist"]) <= 0.5, "dim_resist stops at 50% with the Pearl and the Lantern")
	var f := Hero.stats(h, ["sporeward", "bone_flute", "hoarfrost_bell"])
	_check(float(f["flags"].get("spore_resist", 0.0)) == 0.5 and int(f["flags"].get("bone_flute_every", 0)) == 8 and float(f["flags"].get("chill_slow", 0.0)) == 0.4,
			"Sporeward, the Bone Flute and the Hoarfrost Bell put their numbers in stats.flags")
	var cap_speed := Hero.stats(h, ["clockheart"])
	_check(float(cap_speed["attack_speed"]) <= 1.0 + 0.30 + 0.0001, "Clockheart stays under the +30% attack-speed cap")
	# The Match through the flask (at most 3 charges).
	_fresh()
	game.data["relics"].append("taper_match")
	game.hero()["belt"] = ["taper_match"]
	_check(game.flask_charges("dusk") == 2 and game.flask_charges("nightfall") == 3, "Mother Taper's Match: +1 charge (Dusk 2, Nightfall 3)")
	game.grant_draught("second")
	_check(game.flask_charges("nightfall") == 3 and game.flask_charges("dusk") == 3, "and never more than 3")
	Relics.deep_live = Relics.DEEP_LIVE
	# The Game rolls and sells from the worlds reached (v2's in a W1-W2 build).
	_fresh()
	var same := true
	for i in 50:
		var a := RandomNumberGenerator.new()
		a.seed = 300 + i
		var b := RandomNumberGenerator.new()
		b.seed = 300 + i
		same = same and game.roll_relic(a, "magic") == Relics.roll(b, game.data["relics"], "magic", 2)
	_check(same and game.relic_offers().size() == 3, "in Worlds 1-2 the relic rolls and the shelf are v2's")
	# A save keeps a v3 relic it holds, live or not.
	game.data["relics"].append("hush_pearl")
	game.save()
	game.load_save()
	_check(game.has_relic("hush_pearl"), "a save keeps a v3 relic it holds (Relics.known)")


# ---------------------------------------------------------------- Phase 1: the Chandler by depth

func _set_depth(level: int, deepest: int) -> Dictionary:
	## The hero at this level and deepest area, the stock to be made afresh.
	var h: Dictionary = game.hero()
	h["level"] = level
	h["xp"] = Progression.total_to(level)
	h["deepest"] = deepest
	h["wares_seed"] = -1
	game._settle_points(h)
	return h


func _v2_stock(h: Dictionary) -> Array:
	## v2's _restock, word for word (four wares at the hero's level).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|%d" % [h["cls"], game.bells(), int(h["level"]), int(game.data["run_counter"])])
	var lvl := int(h["level"])
	var slots: Array = Items.LIVE_SLOTS.duplicate()
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = slots[i]
		slots[i] = slots[j]
		slots[j] = t
	var stock := [Items.make(slots[0], h["cls"], lvl, "magic", rng), Items.make(slots[1], h["cls"], lvl, "magic", rng),
			Items.make(slots[2], h["cls"], lvl, "rare", rng)]
	var weak: String = game.weakest_slot(h)
	var best = null
	var best_score := -INF
	for i in 6:
		var it := Items.make(weak, h["cls"], lvl, "magic", rng)
		var chips := Hero.compare(h, weak, it, h.get("belt", []), game.diff())
		var score := float(chips["dmg"]) + float(chips["life"])
		if score > best_score:
			best_score = score
			best = it
	stock.append(best)
	return stock


func _test_chandler_depth() -> void:
	## spec §8.2: the stock by shop depth (max(deepest, level - 1)), the relic
	## shelf, and v2's shop exactly below depth 13.
	_fresh()
	var h := _set_depth(6, 5)
	var v2 := JSON.stringify(_v2_stock(h))
	_check(JSON.stringify(game.wares()) == v2 and game.ware_count() == 4, "below depth 13 the Chandler's stock is v2's, item for item")
	h = _set_depth(12, 12)
	v2 = JSON.stringify(_v2_stock(h))
	_check(JSON.stringify(game.wares()) == v2, "(at level 12 too)")
	var cases := [[14, 13, ["magic", "magic", "rare", "rare", "magic"], 3], [19, 18, ["magic", "magic", "rare", "rare", "rare"], 3],
			[20, 23, ["magic", "magic", "rare", "rare", "rare"], 4], [29, 28, ["magic", "rare", "rare", "rare", "rare", "rare"], 4],
			[35, 12, ["magic", "rare", "rare", "rare", "rare", "rare"], 4]]
	for c in cases:
		h = _set_depth(int(c[0]), int(c[1]))
		var stock: Array = game.wares()
		var rar: Array = stock.map(func(it): return it["rarity"])
		var slots: Array = stock.slice(0, stock.size() - 1).map(func(it): return it["slot"])
		var distinct := {}
		for sl in slots:
			distinct[sl] = true
		var lvl_ok := stock.all(func(it): return int(it["ilvl"]) == int(c[0]))
		_check(rar == c[2] and game.ware_count() == stock.size() and lvl_ok and distinct.size() == slots.size(),
				"shop depth %d (L%d, deepest %d): %s, one slot each, at the hero's level" % [game.shop_depth(), c[0], c[1], rar])
		_check(str(stock[stock.size() - 1]["slot"]) == game.weakest_slot(h), "the last is for the weakest slot (%s)" % stock[stock.size() - 1]["slot"])
		_check(game.relic_offers().size() == int(c[3]), "the relic shelf: %d at depth %d" % [c[3], game.shop_depth()])
	_check(game.shop_depth() == 34, "shop depth = max(deepest, level - 1)")
	# Going deeper mid-bell (a new row): a new stock, never the old one again.
	h = _set_depth(13, 11)
	var before: Array = game.wares().map(func(it): return it["uid"])
	h["deepest"] = 13
	var after: Array = game.wares().map(func(it): return it["uid"])
	_check(after.size() == 5 and not after.any(func(u): return before.has(u)), "reaching depth 13 mid-bell restocks five new wares (no ware twice)")
	h["deepest"] = 18
	var deeper: Array = game.wares().map(func(it): return it["uid"])
	_check(deeper.size() == 5 and not deeper.any(func(u): return after.has(u)) and game.wares()[4]["rarity"] == "rare",
			"and depth 18 (the same count, the weakest slot's a Rare now) restocks too")
	# A bought ware stays gone; the next bell restocks the new count.
	h = _set_depth(20, 23)
	game.add_embers(5000)
	var w: String = game.buy_ware(0)
	_check((w == "equipped" or w == "satchel") and game.wares()[0] == null and game.wares().size() == 5, "a sale at depth 23 leaves its place empty (%s)" % w)
	game.record_result({"level": "1-1", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(game.wares()[0] != null and game.wares().size() == 5, "and a bell restocks all five")


func _test_reserve() -> void:
	## Waxley's Reserve (spec §8.2): a Legendary legal for the depth from 23,
	## at 300 + 40 x ilvl, restocked when a boss falls.
	_fresh()
	_set_depth(20, 20)
	_check(game.reserve().is_empty() and game.reserve_verdict() == "none", "no Reserve below depth 23")
	var h := _set_depth(24, 23)
	var r: Dictionary = game.reserve()
	var it = r.get("item")
	_check(it is Dictionary and it["rarity"] == "legendary" and int(it["ilvl"]) == 24 and int(r["price"]) == 300 + 40 * 24 and bool(r["new"]),
			"depth 23: a Legendary at the hero's level for 300 + 40 x ilvl (%s, %s)" % [it.get("legend", "") if it is Dictionary else "-", r.get("price")])
	var lg: Dictionary = Items.LEGENDS[str(it["legend"])] if it is Dictionary else {}
	_check(int(lg.get("min_area", 1)) <= 23 and not lg.get("secret", false), "legal for the depth, never a secret prize not yet found")
	_check(game.reserve()["item"]["uid"] == it["uid"], "it holds until a boss falls")
	game.reserve_seen()
	_check(not bool(game.reserve()["new"]), "reserve_seen: Waxley has shown it")
	game.data["embers"] = 0
	_check(game.reserve_verdict() == "poor" and game.buy_reserve() == "poor", "no sale without the embers")
	game.add_embers(3000)
	var where: String = game.buy_reserve()
	_check((where == "equipped" or where == "satchel") and game.reserve()["item"] == null and game.embers() == 3000 - int(r["price"])
			and game.legends_found().has(str(it["legend"])), "bought: worn or carried, noted, the Reserve empty (%s)" % where)
	_check(game.reserve_verdict() == "sold", "sold until a boss falls")
	for shallow in ["1-4", "3-4", "4-4"]:
		game.record_result({"level": shallow, "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(int(game.data["bosses"]) == 0 and game.reserve_verdict() == "sold",
			"a boss shallower than the Reserve's depth (1-4, 3-4, 4-4 replayed at depth 23) doesn't restock it: no farming Tollgrave")
	game.record_result({"level": "5-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	var r2: Dictionary = game.reserve()
	_check(int(game.data["bosses"]) == 1 and r2.get("item") is Dictionary and bool(r2["new"]), "a boss at the hero's depth falls (5-4, area 27): it restocks")
	game.record_result({"level": "5-3", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(int(game.data["bosses"]) == 1 and game.reserve()["item"]["uid"] == r2["item"]["uid"], "a level without a boss doesn't")
	_set_depth(40, 40)
	game.record_result({"level": "6-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(int(game.data["bosses"]) == 1, "and for a depth-40 hero the Dusk Hush (area 31) is too shallow to count")
	game.data["difficulty"] = "nightfall"
	game.record_result({"level": "6-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(int(game.data["bosses"]) == 2, "the Nightfall Hush (area 40) does")
	game.data["difficulty"] = "dusk"
	_set_depth(24, 23)
	# Many restocks: never a secret prize not found, prefers ones not held.
	var bad := 0
	for i in 40:
		game.data["bosses"] = 10 + i
		var ri = game.reserve().get("item")
		if ri is Dictionary and Items.LEGENDS[str(ri["legend"])].get("secret", false):
			bad += 1
	_check(bad == 0, "forty restocks: no secret prize before it's found")
	game.save()
	game.load_save()
	_check(game.reserve().get("item") is Dictionary and game.hero().has("reserve_seed"), "the Reserve saves with the hero")


func _test_draughts() -> void:
	## The Draughts tab (spec §8.2): the Second Draught a gift (never sold),
	## the Rich Draught after the Tinker for 1,600 embers.
	_fresh()
	_check(not game.draughts_open(), "Worlds 1-2 (this build) see no Draughts tab")
	var d: Array = game.draughts()
	_check(d.size() == 2 and d[0]["id"] == "second" and d[0]["state"] == "locked" and d[1]["id"] == "rich" and d[1]["state"] == "locked"
			and int(d[1]["price"]) == 1600, "the Second Draught to come, the Rich Draught locked (%s)" % [d.map(func(x): return x["state"])])
	_check(game.draught_verdict("rich") == "locked" and game.buy_draught("rich") == "locked" and game.buy_draught("second") == "locked"
			and game.buy_draught("x") == "unknown", "nothing to buy yet")
	game.record_result({"level": "3-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(game.draughts()[0]["state"] == "owned" and game.draughts_open() and game.buy_draught("second") == "owned", "Mother Gravebough falls: the Second Draught is had (a gift) and the tab shows")
	game.level_record("4-4", "nightfall")["cleared"] = true
	_check(game.draughts()[1]["state"] == "buy", "the Tinker falls (any difficulty): the Rich Draught is for sale")
	game.data["embers"] = 1599
	_check(game.buy_draught("rich") == "poor" and not game.data["flask"]["rich"], "1,599 embers: too poor")
	game.add_embers(1)
	var heal0: float = game.flask_heal("dusk")
	_check(game.buy_draught("rich") == "bought" and game.embers() == 0 and bool(game.data["flask"]["rich"]) and is_equal_approx(game.flask_heal("dusk"), heal0 + 0.10),
			"bought: 1,600 embers, every draught heals 10 points more")
	_check(game.draughts()[1]["state"] == "owned" and game.buy_draught("rich") == "owned", "once")


func _test_rekindle() -> void:
	## Rekindle (spec §8.2): from World 5, a Legendary re-made at the hero's
	## level for 200 + 30 x ilvl, only if that's higher.
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	_set_depth(26, 25)
	game.set_setting("auto_salvage", false)
	var old := Items.make("candle", "knight", 14, "legendary", rng, "marrow_lantern")
	game.hero()["satchel"].append(old)
	_check(not game.rekindle_open() and game.rekindle_verdict(old) == "locked" and not game.rekindle(old), "before World 5: locked")
	var kept_levels: Array = game.LEVELS
	game.LEVELS = game.ALL_LEVELS.slice(0, 20)   # a build with World 5 in it
	game.data["unlocked"]["dusk"] = 17
	_check(game.rekindle_open() and game.world_reached() == 5, "World 5 reached: it opens")
	game.data["embers"] = 0
	_check(game.rekindle_verdict(old) == "poor" and game.rekindle_price(old) == 200 + 30 * 26, "200 + 30 x the new item level (%d)" % game.rekindle_price(old))
	game.add_embers(2000)
	var uid: String = old["uid"]
	_check(game.rekindle(old), "rekindled")
	var now: Dictionary = game.hero()["satchel"][game.hero()["satchel"].size() - 1]
	_check(now["uid"] == uid and now["legend"] == "marrow_lantern" and int(now["ilvl"]) == 26 and int(now["tier"]) == 3
			and now["rarity"] == "legendary" and game.embers() == 2000 - 980, "the same power at item level 26 (T3), where it was, the same uid")
	_check(game.rekindle_verdict(now) == "lower" and not game.rekindle(now), "at the hero's level it refuses")
	var worn := Items.make("weapon", "knight", 10, "legendary", rng, "dawnsliver")
	game.hero()["equip"]["weapon"] = worn
	_check(game.rekindle(worn) and int(game.hero()["equip"]["weapon"]["ilvl"]) == 26 and game.hero()["equip"]["weapon"]["legend"] == "dawnsliver",
			"a worn one is re-made in its slot")
	_check(game.rekindle_verdict(Items.make("coat", "knight", 3, "rare", rng)) == "none" and game.rekindle_verdict(Items.make("coat", "knight", 3, "legendary", rng, "ossuary_coat")) == "none",
			"not a Legendary, or not one the hero holds: nothing to rekindle")
	var rows: Array = game.rekindle_list()
	_check(rows.size() == 2 and rows[0]["worn"] == true, "rekindle_list: worn first, then the satchel's")
	game.LEVELS = kept_levels
	game.set_setting("auto_salvage", true)


func _test_gifts_and_cards() -> void:
	## The first boots and charm (spec §8.1): gift_slot for the first Dread of
	## World 3 / 4 while the hero has none; the Nightfall warning card (§1.6).
	_fresh()
	var h: Dictionary = game.hero()
	_check(h["equip"]["boots"] == null and game.gift_slot(3) == "boots" and game.gift_slot(4) == "charm" and game.gift_slot(2) == "" and game.gift_slot(5) == "",
			"World 3's first Dread gives boots, World 4's a charm, to a hero without")
	var rng := RandomNumberGenerator.new()
	h["satchel"].append(Items.make("boots", "knight", 13, "magic", rng))
	_check(game.gift_slot(3) == "", "boots carried: no gift")
	h["satchel"].clear()
	h["equip"]["charm"] = Items.make("charm", "knight", 18, "magic", rng)
	_check(game.gift_slot(4) == "" and game.gift_slot(3) == "boots", "a charm worn: no charm gift")
	game.borrow_hero(Hero.blank("witch", 20))
	_check(game.gift_slot(3) == "", "never to a borrowed hero")
	game.return_hero()
	# The warning.
	_set_depth(10, 10)
	var card: Dictionary = game.deep_warning(30, "nightfall")
	_check(card.get("id") == game.NOTICE_DEEP and str(card["body"]).contains("level 30") and game.deep_warning(30, "dusk").is_empty()
			and str(game.deep_warning(40, "witching")["body"]).contains("level 40"), "a hero 5+ levels under a Nightfall level gets the card: %s" % card.get("body", ""))
	_set_depth(25, 25)
	_check(game.deep_warning(30, "nightfall").is_empty() and not game.deep_warning(31, "nightfall").is_empty(), "within 5 levels, no card")
	game.notice(game.NOTICE_DEEP)
	_check(game.deep_warning(40, "nightfall").is_empty(), "once shown, never again")


func _test_secret_prize() -> void:
	## A secret level's prize (spec §3.9, §8.4): its named Legendary at the
	## level's area + 2, on each difficulty until it's taken (worn or carried,
	## as a boss's first prize), then found for good. A clear alone never pays
	## it; a pickup pays it at once, bell or no bell.
	_fresh()
	var p1: Dictionary = game.secret_prize("1-S")
	var p3: Dictionary = game.secret_prize("3-S", "nightfall")
	_check(p1.get("legend") == "hymnal" and int(p1["ilvl"]) == 6 + 2 and p1["rarity"] == "legendary" and p1["slot"] == "charm",
			"1-S: Tessel's Hymnal at item level 8 (%s)" % [p1.get("ilvl")])
	_check(p3.get("legend") == "gravebloom" and int(p3["ilvl"]) == Combat.area_level(17, "nightfall") + 2, "3-S on Nightfall: Gravebloom Treads at its area + 2 (%d)" % int(p3.get("ilvl", 0)))
	_check(game.secret_prize("1-3").is_empty() and game.secret_prize("1-s").is_empty(), "only a secret level has one (ids exact)")
	var line: Dictionary = {"level": "1-S", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []}
	var out: Dictionary = game.record_result(line)
	_check(not out.has("prize") and not game.secret_record("1-S")["prize"] and not game.secret_prize("1-S").is_empty(),
			"the bell rung past it, never taken: not paid, it's on the shrine again next time")
	var h: Dictionary = game.hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	while (h["satchel"] as Array).size() < game.SATCHEL_MAX:
		h["satchel"].append(Items.make("coat", "knight", 5, "magic", rng))
	var left: Dictionary = game.secret_prize("1-S")
	_check(game.add_item(left) == "full" and not game.secret_record("1-S")["prize"], "a full satchel leaves it on the ground: still owed")
	h["satchel"].clear()
	var taken: Dictionary = game.secret_prize("1-S")
	_check(game.add_item(taken) == "satchel" and game.secret_record("1-S")["prize"] and game.secret_prize("1-S").is_empty()
			and not game.secret_prize("1-S", "nightfall").is_empty(), "picked up: paid on Dusk at once, still owed on Nightfall")
	line["cleared"] = false
	out = game.record_result(line)
	_check(out.get("prize", false) == true and game.secret_prize("1-S").is_empty() and game.hero()["satchel"].has(taken),
			"a run that ends without the bell (snuffed, quit) keeps it and reports it: it never drops twice")
	_check(not game.record_result(line).has("prize"), "reported once")
	var worn: Dictionary = game.secret_prize("1-S", "nightfall")
	game.equip(worn)
	_check(game.secret_record("1-S", "nightfall")["prize"] and not game.secret_record("1-S", "witching")["prize"], "worn from the ground: paid on its difficulty (Nightfall)")
	out = game.record_result({"level": "2-S", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": [], "prize_taken": true})
	_check(out.get("prize", false) == true and game.secret_record("2-S")["prize"] and game.secret_prize("2-S").is_empty(), "res.prize_taken pays it too")
	game.save()
	game.load_save()
	_check(game.secret_record("1-S")["prize"] and game.secret_record("1-S", "nightfall")["prize"] and not game.secret_record("3-S")["prize"], "the save keeps what's paid")
	_check(Items.LEGENDS.has(game._header("1-S", "secret_prize")) or game._header("1-S", "secret_prize") == "", "the level's secret_prize: header names it once the file's there")
	game.note_legend(str(p1["legend"]))
	var seen := false
	for i in 2000:
		if Items.pick_legend("charm", "knight", rng, 5, game.legends_found()) == "hymnal":
			seen = true
	_check(seen, "once found it rolls in its world and deeper (area 5)")


func _test_milestones_reached() -> void:
	## Sigil milestones past #4 pay from the worlds reached only: on the
	## owner's own save (his Taperwitch L18, 34 sigils, two from #6) in a
	## W1-W2 build, #6 is one of v2's twelve Legendaries over 300 seeds, never
	## a v3 one without its runtime; it prefers one he doesn't hold (spec
	## §8.4, x3). The Reserve likewise. An even milestone (v3's rule) is a
	## relic from the deepest world reached only, else embers.
	var text := FileAccess.get_file_as_string(OWNER_1)
	_check(text != "", "the owner's slot 1 copy is there")
	if text == "":
		return
	_wipe()
	game.reset()
	_write(SAVE, text)
	game.load_save()
	var kept_levels: Array = game.LEVELS
	game.LEVELS = game.ALL_LEVELS.filter(func(l): return int(l["world"]) <= 2)
	var h: Dictionary = game.hero()
	_check(h["cls"] == "witch" and int(h["level"]) == 18 and int(game.data["sigil_rewards"]) == 5 and game.sigil_count("all") == 34
			and game.world_reached() == 2 and not game.milestones_alternate(), "the owner's witch: L18, 34 sigils, milestone #5 paid, World 2 reached")
	game.data["levels"]["dusk"]["pr_m"] = {"cleared": true, "sigils": [true, true, false], "best_time": 1.0, "best_embers": 0, "boss_first": false, "dread": false}
	var found0: Array = (game.data["legends_found"] as Array).duplicate()
	var held: Array = []
	game._legends_held(h, held)
	var line := {"level": "1-1", "cleared": false, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []}
	var got := {}
	var deep := 0
	var candles := 0
	var fresh_candles := 0
	for i in 300:
		game.data["sigil_rewards"] = 5
		game._rng.seed = 9000 + i
		var out: Dictionary = game.record_result(line)
		var it: Dictionary = out["rewards"][0].get("item", {}) if not (out["rewards"] as Array).is_empty() else {}
		var lg := str(it.get("legend", ""))
		got[lg] = int(got.get(lg, 0)) + 1
		if Items.LEGENDS.get(lg, {}).has("min_area") or Items.legend_world(lg) > 2 or lg == "":
			deep += 1
		if str(it.get("slot", "")) == "candle":
			candles += 1
			if not held.has(lg):
				fresh_candles += 1
		(h["satchel"] as Array).erase(it)
		game.data["legends_found"] = found0.duplicate()
	_check(deep == 0 and int(game.data["sigil_rewards"]) == 6, "a W1-W2 build: milestone #6 is one of v2's Legendaries, every time of 300 (%d v3 or none; %s)" % [deep, got])
	_check(candles > 30 and fresh_candles > candles * 0.62, "and a candle is the one he lacks (Gutterlight, not his Twin Wick) about 3 times in 4 (%d of %d)" % [fresh_candles, candles])
	# The Reserve in a W1-W2 build (a hero of L24+): v2's Legendaries only.
	_set_depth(26, 17)
	var bad := 0
	for i in 30:
		game.data["bosses"] = 100 + i
		var ri = game.reserve().get("item")
		if not (ri is Dictionary) or Items.legend_world(str(ri["legend"])) > 2 or Items.LEGENDS[str(ri["legend"])].has("min_area"):
			bad += 1
	_check(bad == 0, "a W1-W2 build's Reserve (shop depth 25) holds only v2's Legendaries (%d bad of 30)" % bad)
	# The worlds reached, in the pick itself.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var over := 0
	for i in 2000:
		var lg := Items.pick_legend(Items.SLOTS[i % 5], "knight", rng, 40, [], [], 3)
		if Items.legend_world(lg) > 3:
			over += 1
	_check(over == 0 and Items.pick_legend("weapon", "knight", rng, 40, [], [], 4) != "" and Items.legal_legends("knight", 40, [], Items.LIVE_SLOTS, 3).has("rootbound")
			and not Items.legal_legends("knight", 40, [], Items.LIVE_SLOTS, 3).has("escapement"), "pick_legend and legal_legends stop at max_world")
	# Items.make's own pick (a Legendary asked for with no power) keeps to its item level.
	var early := 0
	for i in 400:
		var it := Items.make(Items.SLOTS[i % 5], "knight", 8, "legendary", rng)
		if Items.LEGENDS.get(str(it.get("legend", "")), {}).has("min_area") and int(Items.LEGENDS[it["legend"]]["min_area"]) > 8:
			early += 1
	_check(early == 0, "Items.make's fallback pick at item level 8 is never a deeper Legendary (%d)" % early)
	game.LEVELS = kept_levels
	# v3's rule: an even milestone is a relic from the deepest world reached.
	_fresh()
	Relics.deep_live = true
	game.milestone_alternate = true
	game.LEVELS = game.ALL_LEVELS.slice(0, 12)   # a build with World 3
	game.data["unlocked"]["dusk"] = 10
	var worlds := {}
	for i in 60:
		game.data["relics"] = []
		game.data["sigil_rewards"] = 5
		for k in 12:
			game.data["levels"]["dusk"]["m%d" % k] = {"cleared": true, "sigils": [true, true, true], "best_time": 1.0, "best_embers": 0, "boss_first": false, "dread": false}
		game._rng.seed = 400 + i
		var out: Dictionary = game.record_result({"level": "1-1", "cleared": false, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
		if (out["rewards"] as Array).size() > 0 and out["rewards"][0]["kind"] == "relic":
			worlds[Relics.world_of(str(out["rewards"][0]["id"]))] = true
		game.hero()["satchel"].clear()
	_check(worlds.keys() == [3], "milestone #6 with World 3 the deepest reached: always one of World 3's relics (%s)" % [worlds.keys()])
	game.data["relics"] = ["sporeward", "bone_flute"]
	game.data["sigil_rewards"] = 5
	var out2: Dictionary = game.record_result({"level": "1-1", "cleared": false, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(out2["rewards"][0]["kind"] == "embers", "World 3's pool found out: embers, though World 1's relics remain (%s)" % [out2["rewards"][0]])
	game.LEVELS = kept_levels
	game.milestone_alternate = game.MILESTONE_ALTERNATE
	Relics.deep_live = Relics.DEEP_LIVE
	_fresh()


func _test_dims_reach_douse() -> void:
	## Spec §1.7, one dimming pipeline: dim_resist (the Lantern, Marrow Lantern,
	## the Hush Pearl) softens a world.dim entry, and should soften douse and
	## the Gutterwing's latch the same way. world_lights.gd (W0-render) still
	## multiplies those two in raw: PENDING until it moves them onto dim(),
	## and until then Game keeps the Lantern to builds with World 3+
	## (LANTERN_FROM_WORLD).
	var path := "res://levels/2-1.txt"
	if not FileAccess.file_exists(path):
		return
	_fresh()
	var lv = LevelData.load_file(path)
	for k in ["start", "boss"]:
		var st := str(lv.story.get(k, ""))
		if st != "":
			game.mark_seen(st)
	var w: Node2D = load("res://scripts/world.gd").new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.set_physics_process(false)
	var pl = w.player
	var radius := func(resist: float) -> float:
		pl.stats["dim_resist"] = resist
		return float(w.hero_light_radius())
	w.dim("pr_probe", 0.5, 30.0)
	var d0: float = radius.call(0.0)
	var d5: float = radius.call(0.5)
	w.undim("pr_probe")
	_check(d5 > d0 + 1.0, "a world.dim entry is softened by dim_resist (%.1f -> %.1f)" % [d0, d5])
	var softened := []
	for st in ["douse", "latch"]:
		pl.status = {}
		pl.apply_status(st, 30.0)
		var a: float = radius.call(0.0)
		var b: float = radius.call(0.5)
		if b > a + 1.0:
			softened.append(st)
	pl.status = {}
	if softened.size() == 2:
		_check(true, "douse and the latch go through dim_resist")
		if int(game.LANTERN_FROM_WORLD) > 1:
			print("  NOTE: douse and latch are in the dim pipeline now: game_state.LANTERN_FROM_WORLD can be 1 (the Lantern then rolls in W1-W2)")
	else:
		print("  PENDING (W0-render): dim_resist doesn't soften %s yet (world_lights.gd hero_radius multiplies them in raw); the Lantern rolls from World %d" % [
				["douse", "latch"].filter(func(x): return not softened.has(x)), game.LANTERN_FROM_WORLD])
	w.queue_free()


# ---------------------------------------------------------------- the Descent's XP (with MO)

func _test_descent_xp() -> void:
	## decisions.md: the Descent pays at least a Nightfall replay's XP per
	## minute at L34-40, and not more than 1.5x. At each hero level it
	## compares the depth a hero that level plays (its area nearest his level)
	## with a replay of the Nightfall level nearest that area. It needs the
	## modes stream's scripts/modes/descent.gd: its static
	## depth_area(depth, diff) -> int (the depth's area), and optionally
	## xp_per_minute(depth, diff, hero_level) -> float (else PR's model: a
	## depth's tiles from spec §7.2, the story levels' monster density and
	## pace, kills x1.0, 20 x E(A) a depth). Until then it's pending, and the
	## model's own numbers (with a stand-in ramp, A_END - 4 + depth) print.
	var fx := _fixture()
	var a_end: int = Combat.area_level(int(game.area_of(game.FINALE)), "nightfall")
	var sc = load(DESCENT) if ResourceLoader.exists(DESCENT) else null
	var names: Array = (sc as Script).get_script_method_list().map(func(m): return m["name"]) if sc is Script else []
	var live: bool = names.has("depth_area")
	var rows := []
	for l in range(34, 41):
		var best_d := 1
		var gap := 999
		for d in range(1, 61):
			var a: int = int(sc.call("depth_area", d, "nightfall")) if live else mini(a_end - 4 + d, 60)
			if absi(a - l) < gap:
				gap = absi(a - l)
				best_d = d
		var area: int = int(sc.call("depth_area", best_d, "nightfall")) if live else mini(a_end - 4 + best_d, 60)
		var rate := float(sc.call("xp_per_minute", best_d, "nightfall", l)) if live and names.has("xp_per_minute") else _descent_rate(area, best_d, l, fx)
		var k := rate / maxf(_replay_rate(l, area, fx), 1.0)
		rows.append("L%d depth %d (area %d) %.2fx" % [l, best_d, area, k])
		if live:
			_check(k >= 1.0 and k <= 1.5, "L%d: the Descent (depth %d) pays %.2fx a Nightfall replay's XP a minute (want 1-1.5x)" % [l, best_d, k])
	if not live:
		print("  skipped: the Descent XP-per-minute bound waits for scripts/modes/descent.gd's depth_area(depth, diff) (MO); PR's model: ", ", ".join(rows))
	else:
		print("  the Descent against a Nightfall replay: ", ", ".join(rows))


func _pace() -> Dictionary:
	## The story levels' monsters per tile and tiles a minute (spec §3.1:
	## a W3-W6 regular level of ~350 tiles in ~5 minutes, ~27 monsters).
	return {"density": 27.0 / 350.0, "tiles_min": 70.0, "xp_avg": 7.5}


func _replay_rate(hero_level: int, area: int, fx: Dictionary) -> float:
	## XP a minute replaying the Nightfall level whose area is nearest the
	## depth's (the same fights), at the hero's level.
	var best_id := "1-1"
	var gap := 99
	for info in game.ALL_LEVELS:
		var a: int = Combat.area_level(int(game.area_of(str(info["id"]))), "nightfall")
		if absi(a - area) < gap:
			gap = absi(a - area)
			best_id = str(info["id"])
	var a: int = Combat.area_level(int(game.area_of(best_id)), "nightfall")
	var p := _pace()
	var tiles := 350.0
	var xp: float = float(p["density"]) * tiles * float(Progression.kill_xp("skeleton", a, hero_level, "nightfall")) * float(p["xp_avg"]) / 5.0
	xp += Progression.event_xp("clear", a) + 3 * Progression.event_xp("altar", a)
	return xp / (tiles / float(p["tiles_min"]))


func _descent_rate(area: int, depth: int, hero_level: int, fx: Dictionary) -> float:
	var p := _pace()
	var tiles := minf(170.0 + 6.0 * (depth - 1), 265.0)
	var xp: float = float(p["density"]) * tiles * float(Progression.kill_xp("skeleton", area, hero_level, "nightfall")) * float(p["xp_avg"]) / 5.0
	xp += Progression.event_xp("depth", area) + Progression.event_xp("altar", area)
	return xp / (tiles / float(p["tiles_min"]))


# ---------------------------------------------------------------- build 1: loot

func _test_loot_build1() -> void:
	## Build 1's loot slice: Dusk kills roll no Commons and half as often, so a
	## kill gives a Legendary as often as before and the Blessed / Rare mix
	## stays as it was (nothing up-tiered); the Chandler's shelf holds one
	## relic of each rarity; what's paid there is counted for the playlog
	## (Game.embers_spent, never saved); the playlog's legendaries_worn.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1001
	var drop := float(Combat.diff("dusk")["drop"])
	_check(drop == 0.5 and float(Combat.diff("nightfall")["drop"]) == 1.2 and float(Combat.diff("witching")["drop"]) == 1.4,
			"Dusk kills drop half as often (0.5); Nightfall and Witching as before")
	var v2 := {1: {"common": 60.0, "magic": 32.0, "rare": 7.5, "legendary": 0.5}, 13: {"common": 55.0, "magic": 34.0, "rare": 10.0, "legendary": 1.0},
			23: {"common": 50.0, "magic": 35.0, "rare": 13.5, "legendary": 1.5}}
	for a in v2:
		var old: Dictionary = v2[a]
		var now := Items.kill_weights(a, "dusk")
		var tot := 0.0
		var old_tot := 0.0
		for r in Items.RARITIES:
			tot += float(now.get(r, 0.0))
			old_tot += float(old[r])
		var leg_now := drop * float(now["legendary"]) / tot
		var leg_old := float(old["legendary"]) / old_tot
		_check(absf(leg_now - leg_old) < 1e-6, "area %d: a Dusk kill drops a Legendary as often as before (%.4f vs %.4f)" % [a, leg_now, leg_old])
		var mix_now := float(now["rare"]) / (float(now["magic"]) + float(now["rare"]))
		var mix_old := float(old["rare"]) / (float(old["magic"]) + float(old["rare"]))
		_check(absf(mix_now - mix_old) < 0.01, "area %d: the Blessed / Rare mix is v2's (%.3f Rare vs %.3f): nothing up-tiered" % [a, mix_now, mix_old])
	var commons := 0
	for i in 4000:
		if Items.pick_rarity(Items.kill_weights(1 + i % 31, "dusk"), rng) == "common":
			commons += 1
	_check(commons == 0, "4,000 Dusk kill rolls over areas 1-31: no Commons (%d)" % commons)
	# The shelf: one of each rarity, the cheapest rarities first.
	var ids := func(rs: Array) -> Array: return rs.map(func(r): return r["id"])
	_check(ids.call(Relics.for_sale([], 3, 1)) == ["tallow_heart", "rook_feather", "saints_knuckle"],
			"World 1's shelf: Tallow Heart, Rook Feather, Saint's Knuckle (%s)" % [ids.call(Relics.for_sale([], 3, 1))])
	_check(ids.call(Relics.for_sale([], 4, 1)) == ["tallow_heart", "rook_feather", "saints_knuckle", "phoenix_wick"],
			"a shelf of four (shop depth 23): one of every rarity")
	var w1 := Relics.every().filter(func(r): return int(r.get("world", 1)) == 1)
	var commons_owned: Array = ids.call(w1.filter(func(r): return r["rarity"] == "common"))
	_check(ids.call(Relics.for_sale(commons_owned, 3, 1)) == ["rook_feather", "saints_knuckle", "phoenix_wick"],
			"every Common found: a Blessed, a Rare and the Legendary")
	var but_magic: Array = ids.call(w1.filter(func(r): return r["rarity"] != "magic"))
	_check(ids.call(Relics.for_sale(but_magic, 3, 1)) == ["rook_feather", "iron_boots", "bellows"],
			"only Blessed ones left: the cheapest of them fill the shelf")
	_check(Relics.for_sale([], 0, 1).is_empty() and Relics.for_sale(ids.call(w1), 3, 1).is_empty(), "no places or nothing left: a bare shelf")
	_fresh()
	_check(ids.call(game.relic_offers()) == ["tallow_heart", "rook_feather", "saints_knuckle"], "a new game's Chandler sells Rook Feather in World 1")
	# What's paid at the Chandler, counted for the playlog.
	game.add_xp(Progression.total_to(6))
	game.add_embers(5000)
	game.embers_spent = 0
	var rid: String = game.relic_offers()[1]["id"]
	game.buy_relic(rid)
	_check(game.embers_spent == Relics.price(rid), "a relic bought counts its price (%d)" % game.embers_spent)
	var paid: int = game.embers_spent
	var stock: Array = game.wares()
	var wp: int = game.ware_price(stock[0])
	var sold: String = game.buy_ware(0)
	_check((sold == "equipped" or sold == "satchel") and game.embers_spent == paid + wp, "a ware too (%d)" % wp)
	_check(not game.spend_embers(999999) and game.embers_spent == paid + wp, "a spend refused counts nothing")
	_check(not JSON.stringify(game.data).contains("embers_spent"), "and the count is never saved")
	game.embers_spent = 0
	# The playlog's legendaries_worn: the Legendaries found that he wears.
	var Playlog = load("res://scripts/playlog.gd")
	var h: Dictionary = game.hero()
	var worn := Items.make("weapon", "knight", 6, "legendary", rng, "dawnsliver")
	var carried := Items.make("candle", "knight", 6, "legendary", rng, "twin_wick")
	var plain := Items.make("coat", "knight", 6, "rare", rng)
	game.equip(worn)
	game.equip(plain)
	(h["satchel"] as Array).append(carried)
	_check(Playlog.legends_worn([worn, carried, plain], h) == 1 and Playlog.legends_worn([], h) == 0,
			"legendaries_worn: of the items found, the Legendaries worn (1)")


func _test_boss_boons() -> void:
	## A boss's boon (Items.boon_legends, world.gd open_boon): at most three
	## Legendaries, his signature first (W1-W2's one, W3-W6's pair), then
	## others the hero doesn't hold that may roll at his area (a calling's
	## charm only its own, a secret one once found), never another boss's
	## signature, none twice. With every other one held, his signature alone
	## (no choice: the World drops his prize as before).
	var signed := {}
	for w in Items.WORLD_LEGENDS:
		for id in Items.WORLD_LEGENDS[w]:
			signed[id] = true
	var ok := true
	var bad := []
	for w in range(1, 7):
		var area := int(game.AREAS["%d-4" % w])
		var sig := Items.world_legends(w)
		for cls in ["knight", "witch", "runner", "founder", "sexton"]:
			for s in 20:
				var rng := RandomNumberGenerator.new()
				rng.seed = 7000 + s
				var ids := Items.boon_legends(w, cls, area, [], [], rng)
				var legal := Items.legal_legends(cls, area, [], Items.live_slots(area))
				var good: bool = ids.size() == Items.BOON_MAX and ids.slice(0, sig.size()) == sig
				for id in ids.slice(sig.size()):
					var l: Dictionary = Items.LEGENDS[id]
					good = good and legal.has(id) and not signed.has(id) and ids.count(id) == 1 and (not l.has("cls") or l["cls"] == cls) and not l.get("secret", false)
				if not good:
					ok = false
					bad.append([w, cls, ids])
	_check(ok and Items.BOON_MAX == 3, "every boss, every calling: his signature first, then others legal at his area, none another's, three in all (%s)" % [bad.slice(0, 3)])
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var first := Items.boon_legends(1, "knight", 6, [], [], r)
	var held: Array = first.slice(1)
	r.seed = 5
	var again := Items.boon_legends(1, "knight", 6, held, [], r)
	_check(again[0] == "tollbreaker" and not again.slice(1).any(func(id): return held.has(id)), "the others are ones he doesn't hold (%s, then %s)" % [first, again])
	var all_others: Array = Items.legal_legends("knight", 6, [], Items.live_slots(6)).filter(func(id): return not signed.has(id))
	_check(Items.boon_legends(1, "knight", 6, all_others, [], r) == ["tollbreaker"] and Items.boon_legends(3, "knight", 17, Items.legal_legends("knight", 17), [], r) == Items.world_legends(3),
			"every other one held: his signature alone (Tollbreaker: no choice; World 3's pair still is one)")
	var hymnal_seen := false
	var hymnal_hidden := true
	for s in 200:
		r.seed = 9000 + s
		hymnal_seen = hymnal_seen or Items.boon_legends(1, "knight", 6, [], ["hymnal"], r).has("hymnal")
		r.seed = 9000 + s
		hymnal_hidden = hymnal_hidden and not Items.boon_legends(1, "knight", 6, [], [], r).has("hymnal")
	_check(hymnal_seen and hymnal_hidden, "a secret prize is offered only once found")
	_check(Items.boon_legends(4, "witch", 22, [], [], r, 2) == Items.world_legends(4), "n caps it (two: the pair)")


# ---------------------------------------------------------------- v3: the tree

func _test_deep_tree() -> void:
	## Off: v2's tree, byte for byte. On: 32 points, the gates, no dead levels.
	_check(Classes.DEEP_TREE == true, "the deep tree is on in this build (skills_panel draws Tiers 4 and 5)")
	Classes.set_deep(false)
	for cls in Classes.ids():
		_check(Classes.tree(cls).size() == 9 and Classes.tree_points(cls) == 19 and Classes.root_max() == 5, "%s: v2's tree, 9 nodes, 19 points" % cls)
	_check(Classes.ROOT_GATE == [0, 3, 6, 9, 12, 18, 26] and Classes.SECOND_CAPSTONE == 30 and int(Classes.GATES[4]["level"]) == 16
			and int(Classes.GATES[5]["branch"]) == 10, "ROOT_GATE, GATES and SECOND_CAPSTONE (contract §7)")
	Classes.set_deep(true)
	var ids := {"knight": ["k_bastion", "k_sanctuary", "k_vigilant", "k_judgment"], "witch": ["w_pyre", "w_wildfire", "w_molten", "w_candlemold"],
			"runner": ["r_nightstalk", "r_phantom", "r_whetted", "r_fan"], "founder": ["f_temper", "f_moltencore", "f_resonance", "f_carillon"],
			"sexton": ["x_host", "x_requiem", "x_warden", "x_barrow"]}
	for cls in Classes.ids():
		var tree := Classes.tree(cls)
		var have := true
		for id in ids[cls]:
			var n := Classes.find_node(cls, id)
			have = have and not n.is_empty() and int(n["tier"]) >= 4 and (n["per"] as Array).size() == int(n["max"])
		var root: Dictionary = tree[0]
		_check(have and tree.size() == 13 and Classes.tree_points(cls) == 32 and int(root["max"]) == 7 and (root["per"] as Array).size() == 8,
				"%s: the deep tree: 13 nodes, 32 points, a 7-rank root with 8 numbers" % cls)
	_check(Classes.find_node("knight", "k_vigilant")["stat"] == "dmg_pct" and Classes.find_node("witch", "w_molten")["stat"] == "res_regen_pct"
			and Classes.find_node("runner", "r_nightstalk")["stat"] == "crit" and Classes.find_node("founder", "f_carillon")["stat"] == "",
			"T4 stat nodes feed hero.gd; T5 nodes are the kits'")
	_check(Classes.find_node("runner", "r_step")["per"].slice(4) == [144, 144, 144, 144] and Classes.find_node("sexton", "x_knell")["per"][6] == 93,
			"the dash stays at 144 px past rank 5")
	_check(Classes.node_text(Classes.find_node("knight", "k_aegis"), 6) == "Rush 2.2x basic. Guard blocks cost 27% of the hit.", "root rank 6's card: %s" % Classes.node_text(Classes.find_node("knight", "k_aegis"), 6))
	# Gates.
	var r := {"k_aegis": 5}
	_check(Classes.can_buy("knight", "k_aegis", r, 17, 5) == "level 18" and Classes.can_buy("knight", "k_aegis", r, 18, 5) == "", "root rank 6 at L18")
	r["k_aegis"] = 6
	_check(Classes.can_buy("knight", "k_aegis", r, 25, 5) == "level 26" and Classes.can_buy("knight", "k_aegis", r, 26, 5) == "", "rank 7 at L26")
	r["k_aegis"] = 7
	_check(Classes.can_buy("knight", "k_aegis", r, 40, 5) == "maxed", "and 7 is the most")
	var g := {"k_tempered": 2, "k_devout": 2, "k_mirror": 2}
	_check(Classes.can_buy("knight", "k_bastion", g, 15, 5) == "level 16" and Classes.can_buy("knight", "k_bastion", g, 16, 5) == "7 points in branch", "T4: L16, then 7 points in the branch")
	g["k_mirror"] = 3
	_check(Classes.can_buy("knight", "k_bastion", g, 16, 5) == "", "T4 opens at L16 with 7 in the branch")
	g["k_bastion"] = 2
	_check(Classes.can_buy("knight", "k_sanctuary", g, 23, 5) == "level 24" and Classes.can_buy("knight", "k_sanctuary", g, 24, 5) == "10 points in branch", "T5: L24, then 10 points")
	g["k_unbroken"] = 1
	_check(Classes.can_buy("knight", "k_sanctuary", g, 24, 5) == "", "T5 opens at L24 with 10 in the branch")
	var two := {"k_tempered": 2, "k_devout": 2, "k_mirror": 1, "k_unbroken": 1, "k_keen": 2, "k_honed": 2, "k_crescent": 1}
	_check(Classes.can_buy("knight", "k_dawn", two, 29, 5) == "level 30" and Classes.can_buy("knight", "k_dawn", two, 30, 5) == "", "the other capstone opens at L30")
	# No dead levels (spec §2.1): a hero who always buys, in any order the
	# tree lists, spends every point as it comes, until the tree is full at
	# L33 (then L34-40 are 7 Vigil ranks).
	var idle := []
	for cls in Classes.ids():
		var ranks := {}
		for lvl in range(2, 41):
			var pts := lvl - 1 - Hero.spent({"cls": cls, "skills": ranks})
			var bought := true
			while pts > 0 and bought:
				bought = false
				for n in Classes.tree(cls):
					if Classes.can_buy(cls, n["id"], ranks, lvl, pts) == "":
						ranks[n["id"]] = int(ranks.get(n["id"], 1 if n["branch"] == -1 else 0)) + 1
						pts -= 1
						bought = true
						break
			if lvl <= 33 and pts > 0:
				idle.append("%s L%d: %d" % [cls, lvl, pts])
			if lvl == 40 and pts != 7:
				idle.append("%s L40: %d past the tree, want 7" % [cls, pts])
		_check(Hero.spent({"cls": cls, "skills": ranks}) == 32, "%s: a hero who always buys fills all 32 by L33" % cls)
	_check(idle.is_empty(), "and never holds a point with nothing to spend it on (%s)" % [idle])
	# Stat nodes reach the stats.
	var kh := Hero.blank("knight", 20)
	var base_dmg := float(Hero.stats(kh)["dmg_pct"])
	kh["skills"] = {"k_vigilant": 3}
	_check(is_equal_approx(float(Hero.stats(kh)["dmg_pct"]) - base_dmg, 0.24) and int(Hero.stats(kh)["ranks"]["k_bastion"]) == 0, "Vigilant Edge 3: +24% damage; a T5 node's rank is in stats.ranks")
	Classes.set_deep(false)
	_check(Classes.tree("knight").size() == 9 and Classes.tree_points("knight") == 19, "and off again: v2's tree")


# ---------------------------------------------------------------- v3: the level registry

func _test_registry() -> void:
	var ids: Array = game.ALL_LEVELS.map(func(l): return str(l["id"]))
	var want := []
	for w in range(1, 7):
		for n in range(1, 5):
			want.append("%d-%d" % [w, n])
	_check(ids == want and game.ALL_LEVELS.size() == 24, "ALL_LEVELS: the 24 main levels in order (1-1 ... 6-4)")
	var paths := true
	for l in game.ALL_LEVELS:
		paths = paths and str(l["path"]) == "res://levels/%s.txt" % l["id"] and int(l["world"]) == int(str(l["id"]).left(1))
	_check(paths, "each at res://levels/<id>.txt, in its world")
	var sec: Array = game.SECRET_LEVELS.map(func(l): return "%s<%s" % [l["id"], l["from"]])
	_check(sec == ["1-S<1-3", "2-S<2-2", "3-S<3-3", "4-S<4-2", "5-S<5-3", "6-S<6-2"], "SECRET_LEVELS: six, each from its bell's level (%s)" % [sec])
	_check(game.FINALE == "6-4" and game.WORLD_NAMES.size() == 6 and game.WORLD_NAMES[4] == "The Frozen Carillon" and game.WORLD_NAMES[6] == "The Hushdeep", "FINALE and WORLD_NAMES")
	_check(game.LEVELS.size() >= 8 and game.index_of("1-S") == -1 and game.index_of("2-4") == 7, "LEVELS holds what's built; secret levels aren't in the linear order")
	var areas := true
	for l in game.ALL_LEVELS + game.SECRET_LEVELS:
		if FileAccess.file_exists(l["path"]):
			var lv: RefCounted = LevelData.load_file(l["path"])
			areas = areas and int(lv.area) == int(game.AREAS[l["id"]]) and game.area_of(l["id"]) == int(lv.area)
			if not areas:
				print("  %s: header area %d, table %d" % [l["id"], lv.area, game.AREAS[l["id"]]])
	_check(areas and game.area_of("3-2") == 14 and game.area_of("nope") == 0, "AREAS agrees with every built level's area header")
	var li: Dictionary = game.level_info("4-S")
	_check(li.get("secret") == true and li.get("from") == "4-2" and int(li.get("world", 0)) == 4 and game.level_info("4-s").is_empty()
			and game.level_info("2-3").get("secret") == false, "level_info: by exact id (4-S, never 4-s)")
	_check(game.is_secret("6-S") and not game.is_secret("6-4") and not game.is_secret("6-s"), "is_secret")


# ---------------------------------------------------------------- the save

func _test_migration() -> void:
	_wipe()
	game.reset()
	var v1 := FileAccess.get_file_as_string(V1_FIXTURE)
	_check(v1 != "", "the v1 fixture save is there")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(v1)
	f.close()
	game.set_setting("haptics", true)
	game.load_save()
	_check(int(game.data["version"]) == 3, "a v1 save loads as v3 (v1 -> v2 -> v3)")
	_check(FileAccess.get_file_as_string(SAVE + ".v1") == v1, "the v1 file is kept beside it as .v1, byte for byte")
	_check(game.unlocked_count("dusk") == 5 and game.is_unlocked(3), "unlocks carry over, one past the last cleared (5 open)")
	_check(game.unlocked_count("nightfall") == 0, "Nightfall stays shut until v2's Tollgrave falls")
	_check(game.has_relic("rook_feather") and game.has_relic("tallow_heart") and game.has_relic("bellows") and game.has_relic("saints_knuckle"), "the relic codex is kept")
	_check(not (game.data["relics"] as Array).has("cursed_idol"), "an unknown relic id is dropped")
	_check(game.veteran() == 4, "veteran = the 4 levels cleared")
	_check(game.embers() == 212 + 150, "embers kept, +150 for a veteran (%d)" % game.embers())
	_check(game.setting("haptics") == false, "haptics moved into settings")
	_check((game.data["v1_levels"] as Dictionary).size() == 4 and game.sigil_count("all") == 0, "v1 records kept aside; v2's sigils start fresh")
	_check(game.heroes().is_empty() and not game.seen("intro"), "no heroes and no story seen: the intro and oath will play")
	var h: Dictionary = game.new_hero("knight")
	_check(int(h["level"]) == 1 and h["equip"]["weapon"]["rarity"] == "common", "the veteran's first hero starts at L1 in Common gear")
	_check((h["belt"] as Array).size() == 2 and game.equipped("rook_feather"), "and wears the first two codex relics")
	var disk = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	_check(disk is Dictionary and int(disk["version"]) == 3, "the migrated save is written back as v3")
	_check(game.data["notices"] == [] and game.data["relocked"].is_empty() and game.diff() == "dusk", "a v1 veteran: the v3 cards owed, nothing to lock again")
	game.record_result({"level": "1-1", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(game.unlocked_count("dusk") == 5, "a migrated veteran with 5 open still has 5 after clearing 1-1 (%d)" % game.unlocked_count("dusk"))
	# Clearing the last level built leaves the next one planned open, so a
	# World 1 build's 1-4 opens 2-1 for when World 2 ships.
	_fresh()
	game.record_result({"level": "1-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(game.unlocked_count("dusk") == 5 and game.is_unlocked(3) and game.is_unlocked(4) == (game.LEVELS.size() > 4),
			"clearing 1-4 opens 2-1 (5 open), shown once it exists")
	# A v1 save that never cleared a level: no veteran bonus.
	var fresh_v1 := {"version": 1, "unlocked": 1, "levels": {"1-1": {"cleared": false, "sigils": [true, false, false], "best_time": 0.0, "best_embers": 0}}, "relics": [], "embers": 9, "haptics": true}
	var out: Dictionary = game.migrate(fresh_v1)
	_check(int(out["embers"]) == 9 and int(out["veteran"]) == 0 and int(out["unlocked"]["dusk"]) == 1, "a v1 save with no clears gets no veteran bonus")
	# Junk doesn't crash the load; an unreadable file is kept aside.
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	game.load_save()
	_check(game.embers() == 0 and FileAccess.file_exists(SAVE + ".bad"), "an unreadable save starts fresh and is kept as save.json.bad")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "embers": "lots", "unlocked": {"dusk": 99.0}, "heroes": {"knight": {"level": 7.0, "xp": 3.0, "skills": {"k_keen": 9.0, "nope": 1}, "equip": {"weapon": {"slot": "coat"}}, "satchel": [5, {"slot": "candle", "ilvl": 4.0, "affixes": [{"id": "gilded", "v": 3}]}]}, "wizard": {}}, "hero": "knight"}))
	f.close()
	game.load_save()
	var k: Dictionary = game.hero()
	_check(game.embers() == 0 and game.unlocked_count("dusk") == game.ALL_LEVELS.size(), "junk numbers are fixed, not trusted")
	_check(int(k["level"]) == 7 and int(k["xp"]) == Progression.total_to(7) and int(k["skills"]["k_keen"]) == 2 and not k["skills"].has("nope"), "a hero's level, XP and ranks are made sane")
	_check(k["equip"]["weapon"] == null and (k["satchel"] as Array).size() == 1 and (k["satchel"][0]["affixes"] as Array).is_empty(), "items in the wrong slot, non-items and cut affixes are dropped")
	_check(int(k["points"]) + Hero.spent(k) + int(k["vigil"]) == 6 and not game.heroes().has("wizard"), "points add up to the level; unknown callings are dropped")


func _rich_state() -> void:
	## A save with a bit of everything in it.
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	game.add_xp(Progression.total_to(9))
	game.buy_skill("k_tempered")
	game.buy_skill("k_tempered")
	game.buy_skill("k_devout")
	game.buy_skill("k_aegis")
	game.grant_relic("rook_feather")
	game.grant_relic("tallow_heart")
	game.grant_relic("bellows")
	game.add_embers(321)
	game.equip(Items.make("weapon", "knight", 9, "legendary", rng, "dawnsliver"))
	game.set_setting("auto_salvage", false)
	game.add_item(Items.make("candle", "knight", 8, "rare", rng))
	game.add_item(Items.make("coat", "knight", 12, "magic", rng))
	game.set_setting("auto_salvage", true)
	game.record_result({"level": "1-1", "cleared": true, "embers": 40, "sigils": [true, false, true], "time": 71.23456789, "relics": [], "dread": true})
	game.wares()
	game.mark_seen("intro")
	game.mark_seen("bark:first_altar")
	game.next_run()
	game.new_hero("witch")
	game.set_hero("knight")


func _test_round_trip() -> void:
	_rich_state()
	game.save()
	var before: Dictionary = game.data.duplicate(true)
	var text1 := FileAccess.get_file_as_string(SAVE)
	game.reset()
	game.load_save()
	_check(_deep_eq(before, game.data), "v2 round trip: the loaded save equals what was saved")
	game.save()
	var text2 := FileAccess.get_file_as_string(SAVE)
	_check(text1 == text2 and text1.length() > 500, "and saving it again writes the very same file")
	_check(float(game.level_record("1-1")["best_time"]) == 71.23456789, "floats keep full precision")
	_check(game.hero()["cls"] == "knight" and int(game.hero()["level"]) == 9 and int(game.heroes()["witch"]["level"]) == 7, "both heroes come back")
	_check(game.hero()["equip"]["weapon"]["legend"] == "dawnsliver" and game.hero_stats()["legends"].has("dawnsliver"), "gear comes back live")
	_check(not FileAccess.file_exists(SAVE + ".tmp"), "no side file is left behind")


func _deep_eq(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _deep_eq(a[k], b[k]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _deep_eq(a[i], b[i]):
				return false
		return true
	return a == b


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _records_kept(src: Dictionary, what: String) -> void:
	## Every level record of every difficulty, as the old save had it.
	var ok := true
	var n := 0
	for dd in Combat.DIFFS:
		var recs: Dictionary = (src.get("levels", {}) as Dictionary).get(dd, {})
		for id in recs:
			n += 1
			var now: Dictionary = (game.data["levels"][dd] as Dictionary).get(id, {})
			if not _deep_eq(recs[id], now):
				ok = false
				print("  %s %s: was %s, now %s" % [dd, id, recs[id], now])
	_check(ok and n > 0, "%s: all %d level records kept, every difficulty (clears, sigils, times, embers)" % [what, n])


func _hero_kept(was: Dictionary, now: Dictionary, what: String) -> void:
	var same := int(was["level"]) == int(now["level"]) and int(was["xp"]) == int(now["xp"]) and _deep_eq(was["skills"], now["skills"]) \
			and _deep_eq(was["belt"], now["belt"]) and int(was.get("wares_seed", 0)) == int(now["wares_seed"])
	var gear := true
	for slot in Items.SLOTS:
		var a = (was["equip"] as Dictionary).get(slot)
		var b = (now["equip"] as Dictionary).get(slot)
		gear = gear and ((a == null and b == null) or (a is Dictionary and b is Dictionary and _deep_eq(a, b)))
	var bag := (was["satchel"] as Array).size() == (now["satchel"] as Array).size()
	if bag:
		for i in (was["satchel"] as Array).size():
			bag = bag and _deep_eq(was["satchel"][i], now["satchel"][i])
	var shop := (was.get("wares", []) as Array).size() == (now["wares"] as Array).size()
	_check(same and gear and bag and shop, "%s: level %d, XP, skills, belt, every item worn and carried, the Chandler's stock: kept" % [what, int(now["level"])])


func _test_migration_v2() -> void:
	## spec §9.2 / contract §8.2 on a v2 fixture: everything kept; unlocks
	## recounted (2-4 cleared: 9 on Dusk); Dusk chosen; Nightfall locked again
	## until the Hush with its unlocks and records kept (the owner's answer);
	## points settled; legends_found seeded; deepest and look; version 3; the
	## v2 file kept as .v2 and .bak; a second load changes nothing.
	_wipe()
	game.reset()
	var v2 := FileAccess.get_file_as_string(V2_FIXTURE)
	_check(v2 != "", "the v2 fixture save is there")
	if v2 == "":
		return
	var was: Dictionary = JSON.parse_string(v2)
	_write(SAVE, v2)
	game.load_save()
	var d: Dictionary = game.data
	_check(int(d["version"]) == 3 and int(JSON.parse_string(FileAccess.get_file_as_string(SAVE))["version"]) == 3, "a v2 save loads as v3 and is written back as v3")
	_check(FileAccess.get_file_as_string(SAVE + ".v2") == v2 and FileAccess.get_file_as_string(SAVE + ".bak") == v2, "the v2 file is kept as .v2 (and, till the next save, .bak)")
	_check(game.unlocked_count("dusk") == 9 and game.is_unlocked(8) == (game.LEVELS.size() > 8),
			"unlocks recounted past v2's clamp: 2-4 cleared opens 3-1 (9), shown once it's built (%s)" % ("built" if game.LEVELS.size() > 8 else "not yet"))
	_check(game.diff() == "dusk", "the save opens on Dusk (it was on Nightfall)")
	_check(game.unlocked_count("nightfall") == 0 and not game.diff_open("nightfall") and game.diff_waits("nightfall")
			and int(d["relocked"]["nightfall"]) == 3, "Nightfall is locked again until the Hush, its 3 unlocks kept aside")
	_check(game.unlocked_count("witching") == 0 and not (d["relocked"] as Dictionary).has("witching") and not game.diff_waits("witching"), "Witching wasn't open: nothing kept for it")
	_records_kept(was, "v2 fixture")
	var was_sig := 0
	for dd in was["levels"]:
		for id in was["levels"][dd]:
			for s in was["levels"][dd][id]["sigils"]:
				was_sig += 1 if s else 0
	_check(game.sigil_found("1-1", 0, "nightfall") and game.sigil_count("all") == was_sig and was_sig == 20, "Nightfall's sigils still count (%d of %d)" % [game.sigil_count("all"), was_sig])
	_check(game.embers() == 1234 and game.bells() == 31 and int(d["run_counter"]) == 40 and int(d["sigil_rewards"]) == 3 and game.veteran() == 1,
			"embers, bells, runs, milestones and the veteran count kept")
	_check(_deep_eq(d["relics"], was["relics"]) and _deep_eq(d["seen"], was["seen"]) and _deep_eq(d["v1_levels"], was["v1_levels"]),
			"the codex, the story seen (boss_2_after, ending, post_credits: the_pull is owed) and the v1 records kept")
	var k: Dictionary = game.heroes()["knight"]
	var r: Dictionary = game.heroes()["runner"]
	_hero_kept(was["heroes"]["knight"], k, "the knight")
	_check(int(k["points"]) == 0 and int(k["vigil"]) == 5 and not k.has("respecs"), "v2's tree: his 5 Vigil ranks stay Vigil ranks")
	_check(int(r["level"]) == 31 and int(r["xp"]) == int(was["heroes"]["runner"]["xp"]) and int(r["vigil"]) == 11,
			"a v2 L30 runner whose last gain went past the cap gets the level it's worth (L31, XP kept)")
	_check(int(k["deepest"]) == 24 and int(r["deepest"]) == 30, "deepest: the deepest Dusk area cleared (12), at least level - 1 (%d, %d)" % [k["deepest"], r["deepest"]])
	_check(k["look"] == Hero.LOOK_DEFAULT and r["look"] == Hero.LOOK_DEFAULT, "and the default look")
	var lf: Array = game.legends_found()
	_check(lf.size() == 3 and lf.has("dawnsliver") and lf.has("first_dawn") and lf.has("cinderstep"), "legends_found: every Legendary worn or carried (%s)" % [lf])
	_check(d["notices"] == [] and not game.relock_card().is_empty() and str(game.relock_card()["body"]).begins_with("Nightfall now waits beneath the Hush"),
			"the v3 cards are owed, the Nightfall one among them")
	_check(d["secrets"]["dusk"].is_empty() and int(d["flask"]["draughts"]) == 0 and d["flask"]["rich"] == false and d["modes"] is Dictionary and d["suspend"].is_empty(),
			"secrets, flask, modes and suspend start empty")
	# A second load: the same save, and nothing written.
	var text1 := FileAccess.get_file_as_string(SAVE)
	var before: Dictionary = game.data.duplicate(true)
	game.reset()
	game.load_save()
	_check(_deep_eq(before, game.data) and FileAccess.get_file_as_string(SAVE) == text1, "a migrated save loads again unchanged, and isn't written")
	game.save()
	_check(FileAccess.get_file_as_string(SAVE) == text1.replace('"saved_at": %d' % int(before["saved_at"]), '"saved_at": %d' % int(game.data["saved_at"])),
			"and saving it again writes the same save")
	_check(FileAccess.get_file_as_string(SAVE + ".v2") == v2, "the .v2 file is never written again")
	# The deep tree: the Vigil ranks come back as points (and go back again).
	Classes.set_deep(true)
	_write(SAVE, v2)
	game.load_save()
	_check(int(game.heroes()["knight"]["points"]) == 5 and int(game.heroes()["knight"]["vigil"]) == 0
			and int(game.heroes()["runner"]["points"]) == 11 and int(game.heroes()["runner"]["vigil"]) == 0,
			"the deep tree: a v2 L25 knight's 5 Vigil ranks are 5 points to spend (the runner's 11)")
	_check(game.points_back() == 16 and not (game.data["notices"] as Array).has("new_points"),
			"the migration records the 16 points given back, for the map's \"New skills: 16 points to spend\" (%d)" % game.points_back())
	var M = load("res://scripts/main.gd")
	var mm: Node = M.new()
	_check(mm._card_due("new_points"), "and the map owes that card")
	mm.free()
	Classes.set_deep(false)
	game.load_save()
	_check(int(game.heroes()["knight"]["points"]) == 0 and int(game.heroes()["knight"]["vigil"]) == 5, "and back to v2's tree, they're Vigil again: nothing lost either way")
	# Clearing the last level built doesn't open a Nightfall that waits for the Hush...
	game.record_result({"level": "2-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(game.unlocked_count("nightfall") == 0 and game.diff_waits("nightfall"), "clearing 2-4 again leaves the Nightfall that waits locked")
	# ...the Hush does, with its unlocks and clears.
	var kept_levels: Array = game.LEVELS
	game.LEVELS = kept_levels + [{"id": "6-4", "path": "res://levels/6-4.txt", "world": 6}]
	var out: Dictionary = game.record_result({"level": "6-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	game.LEVELS = kept_levels
	_check(game.unlocked_count("nightfall") == 3 and game.diff_open("nightfall") and not game.diff_waits("nightfall") and game.relock_card().is_empty(),
			"the Hush on Dusk opens Nightfall again with its 3 unlocks")
	_check((out["rewards"] as Array).any(func(x): return x.get("kind") == "difficulty" and x.get("id") == "nightfall"), "and says so")
	_check(game.level_record("1-2", "nightfall")["cleared"] == true and game.sigil_found("1-2", 1, "nightfall"), "its clears and sigils are there")
	# A new save waits for the Hush too, like everyone (the owner's answer):
	# clearing the last level built opens no Nightfall, in any build.
	_fresh()
	game.record_result({"level": "2-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(game.unlocked_count("nightfall") == 0 and not game.diff_open("nightfall"), "a new save's 2-4 opens no Nightfall (it waits for the Hush)")
	_check(game.data["notices"] == ["v3_update", "new_points"] and game.relock_card().is_empty(), "and a new save owes no update card (nor the new-points one)")
	game.LEVELS = kept_levels + [{"id": "6-4", "path": "res://levels/6-4.txt", "world": 6}]
	out = game.record_result({"level": "6-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	game.LEVELS = kept_levels
	_check(game.unlocked_count("nightfall") == 1 and game.diff_open("nightfall") and (out["rewards"] as Array).any(func(x): return x.get("kind") == "difficulty" and x.get("id") == "nightfall"),
			"its Hush opens Nightfall at 1-1")


func _test_owner_saves() -> void:
	## The owner's own saves, from copies (tests/fixtures; the originals are
	## only read, to check the copies are his): slot 1 holds a Taperwitch L18
	## and a Sootrunner L15, 2,204 embers, all 8 Dusk levels and 5 Nightfall
	## ones cleared, on Nightfall; slot 2 is a fresh v2 game.
	for pair in [[OWNER_1, "save.json"], [OWNER_2, "save_2.json"]]:
		if FileAccess.file_exists(OWNER_DIR + pair[1]):
			_check(FileAccess.get_md5(OWNER_DIR + pair[1]) == FileAccess.get_md5(pair[0]), "the fixture %s is the owner's %s, byte for byte" % [pair[0].get_file(), pair[1]])
	var text := FileAccess.get_file_as_string(OWNER_1)
	_check(text != "", "the owner's slot 1 copy is there")
	if text == "":
		return
	var was: Dictionary = JSON.parse_string(text)
	_wipe()
	game.reset()
	_write(SAVE, text)
	game.load_save()
	var d: Dictionary = game.data
	_check(int(d["version"]) == 3 and FileAccess.get_file_as_string(SAVE + ".v2") == text, "the owner's slot 1: v3, his v2 file kept beside it")
	_records_kept(was, "the owner's slot 1")
	_check(game.embers() == 2204 and game.bells() == 15 and int(d["run_counter"]) == 23 and int(d["sigil_rewards"]) == 5 and game.veteran() == 3,
			"2,204 embers, 15 bells, 23 runs, 5 milestones, veteran 3: kept")
	_check(_deep_eq(d["relics"], was["relics"]) and (d["relics"] as Array).size() == 12 and _deep_eq(d["seen"], was["seen"]) and _deep_eq(d["v1_levels"], was["v1_levels"]),
			"all 12 relics, the %d scenes and barks seen, the v1 records: kept" % (was["seen"] as Array).size())
	var sig := 0
	for dd in was["levels"]:
		for id in was["levels"][dd]:
			for s in was["levels"][dd][id]["sigils"]:
				if s:
					sig += 1
	_check(game.sigil_count("all") == sig, "every sigil counts (%d)" % sig)
	_check(game.unlocked_count("dusk") == 9 and game.diff() == "dusk" and game.hero_id() == "witch", "Dusk, 3-1 open for when it ships, the Taperwitch still his hero")
	_check(game.unlocked_count("nightfall") == 0 and int(d["relocked"]["nightfall"]) == 6 and (d["levels"]["nightfall"] as Dictionary).size() == 5,
			"his Nightfall is locked until the Hush, its 6 unlocks and 5 clears kept")
	for cls in ["witch", "runner"]:
		_hero_kept(was["heroes"][cls], game.heroes()[cls], "his " + str(Classes.info(cls)["name"]))
	var w: Dictionary = game.heroes()["witch"]
	_check(int(w["points"]) == 0 and int(w["vigil"]) == 0 and int(game.heroes()["runner"]["points"]) == 0, "his points are all spent, as they were")
	_check(int(w["deepest"]) == 17 and int(game.heroes()["runner"]["deepest"]) == 14,
			"deepest from Dusk only (2-4, area 12), at least level - 1: 17 and 14 (his relocked Nightfall doesn't count until it reopens)")
	var lf: Array = game.legends_found()
	_check(lf.size() == 3 and lf.has("ossuary_coat") and lf.has("gutterlight") and lf.has("twin_wick"), "legends_found: the three Legendaries he carries (%s)" % [lf])
	var card: Dictionary = game.relock_card()
	_check(str(card.get("body", "")) == "Nightfall now waits beneath the Hush. Your Nightfall clears are kept.", "the card: \"%s\"" % card.get("body", ""))
	_check(game.notice(str(card["id"])) and game.relock_card().is_empty() and not game.notice(str(card["id"])), "shown once")
	var after := FileAccess.get_file_as_string(SAVE)
	game.reset()
	game.load_save()
	_check(FileAccess.get_file_as_string(SAVE) == after and int(game.data["relocked"]["nightfall"]) == 6 and game.embers() == 2204, "and it loads again as it was")
	Classes.set_deep(true)
	game.load_save()
	_check(int(game.heroes()["witch"]["points"]) == 0 and int(game.heroes()["witch"]["level"]) == 18, "the deep tree gives him nothing he hasn't earned (no Vigil ranks to turn)")
	Classes.set_deep(false)
	game.load_save()
	# Slot 2: his fresh game.
	var t2 := FileAccess.get_file_as_string(OWNER_2)
	_wipe()
	game.reset()
	_write(SAVE, t2)
	game.load_save()
	_check(int(game.data["version"]) == 3 and game.heroes().is_empty() and game.embers() == 0 and game.unlocked_count("dusk") == 1
			and not game.diff_open("nightfall") and game.data["relocked"].is_empty(), "his fresh slot 2 migrates to a fresh v3 game")
	_check(FileAccess.get_file_as_string(SAVE + ".v2") == t2, "(its v2 file kept too)")
	_check(int(game.data["saved_at"]) == 1790394965 and int(JSON.parse_string(FileAccess.get_file_as_string(SAVE))["saved_at"]) == 1790394965,
			"the migration's write keeps his last-played time (25 Sep, 20:56), on disk too")


func _test_game_api_v3() -> void:
	## contract §8.3, each one.
	_fresh()
	# Secrets.
	var out: Dictionary = game.record_result({"level": "1-3", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": [], "secret": "1-S"})
	_check(str(out.get("secret", "")) == "1-S" and game.secret_open("1-S") and game.secret_open("1-S", "dusk") and not game.secret_open("1-S", "nightfall")
			and not game.secret_open("2-S"), "a rung silver bell opens its secret level, on that difficulty")
	_check(not game.record_result({"level": "1-3", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": [], "secret": "1-S"}).has("secret"),
			"once")
	_check(not game.find_secret("1-s") and not game.secret_open("1-s"), "ids are exact: 1-s is nothing")
	# The World opens it as the bell rings (find_secret), then the level's
	# result comes in with secret_new: still reported, once.
	var fresh_open: bool = game.find_secret("2-S")
	out = game.record_result({"level": "2-2", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": [], "secret": "2-S", "secret_new": fresh_open})
	_check(fresh_open and str(out.get("secret", "")) == "2-S" and (out["rewards"] as Array).any(func(x): return x.get("kind") == "secret" and x.get("id") == "2-S"),
			"opened as the silver bell rang, then the result: record_result still reports it (secret_new)")
	out = game.record_result({"level": "2-2", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": [], "secret": "2-S", "secret_new": game.find_secret("2-S")})
	_check(not out.has("secret"), "and a second ring reports nothing")
	var sc: Dictionary = game.record_result({"level": "1-S", "cleared": true, "embers": 0, "sigils": [true, false, false], "time": 60.0, "relics": []})
	_check(str(sc.get("secret_cleared", "")) == "1-S" and not sc.has("prize") and game.secret_record("1-S")["cleared"] == true
			and game.secret_record("1-S")["prize"] == false, "its first clear: cleared (the prize is paid only as it's taken: _test_secret_prize)")
	var open_before: int = game.unlocked_count("dusk")
	sc = game.record_result({"level": "1-S", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(not sc.has("prize") and game.unlocked_count("dusk") == open_before and game.level_record("1-S")["cleared"] == true
			and game.unlocked_count("nightfall") == 0, "the prize once per difficulty; a secret clear opens no level and no difficulty")
	_check(game.secret_record("3-S", "witching") == {"found": false, "cleared": false, "prize": false} and game.secrets_built().size() == game.SECRET_LEVELS.filter(func(l): return FileAccess.file_exists(l["path"])).size(),
			"secret_record defaults; secrets_built")
	# The Second Draught and the flask.
	_check(game.flask_charges("dusk") == 1 and game.flask_charges("nightfall") == 2 and is_equal_approx(game.flask_heal("dusk"), 0.40), "the flask: v2's charges and heal")
	out = game.record_result({"level": "3-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(str(out.get("draught", "")) == "second" and game.flask_charges("dusk") == 2 and game.flask_charges("witching") == 3, "Mother Gravebough's first defeat: the Second Draught, +1 charge everywhere")
	_check(not game.record_result({"level": "3-4", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []}).has("draught"), "once")
	game.grant_draught("rich")
	_check(is_equal_approx(game.flask_heal("dusk"), 0.50) and is_equal_approx(game.flask_heal("witching"), 0.40), "the Rich Draught: 10 points more")
	game.grant_draught("nonsense")
	_check(int(game.data["flask"]["draughts"]) == 1, "an unknown draught is nothing")
	# Notices, suspend, the Chandler's stubs, modes.
	_check(game.notice("candle_strength") and not game.notice("candle_strength") and not game.notice(""), "notice: true the first time only")
	game.set_suspend({"level": "1-2", "altar": 1})
	_check(game.suspended()["level"] == "1-2", "set_suspend / suspended")
	game.clear_suspend()
	_check(game.suspended().is_empty() and game.ware_count() == 4 and game.reserve().is_empty() and not game.rekindle({}), "clear_suspend; four wares, no Reserve, no Rekindle yet")
	_check(game.modes() is Dictionary and game.has_cosmetic("flame:tallow") and not game.has_cosmetic("flame:marigold"), "modes(); the free cosmetics")
	_check(game.grant_cosmetic("flame:marigold") and not game.grant_cosmetic("flame:marigold") and game.has_cosmetic("flame:marigold")
			and (game.modes()["cosmetics"]["new"] as Array).has("flame:marigold"), "grant_cosmetic: true when new")
	_check(game.look() == Hero.LOOK_DEFAULT, "look(): the default")
	game.set_look("flame", "flame:marigold")
	game.set_look("cape", "red")
	_check(game.look()["flame"] == "flame:marigold" and not game.look().has("cape") and game.look("witch") == Hero.LOOK_DEFAULT, "set_look: known keys only, the hero played")
	# Legendaries, depth.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	game.set_setting("auto_salvage", false)
	game.add_item(Items.make("coat", "knight", 5, "legendary", rng, "ossuary_coat"))
	game.equip(Items.make("boots", "knight", 5, "legendary", rng, "thornsole"))
	game.set_setting("auto_salvage", true)
	_check(game.legends_found().has("ossuary_coat") and game.legends_found().has("thornsole"), "picking up or wearing a Legendary notes it")
	game.note_area(9)
	game.note_area(4)
	_check(int(game.hero()["deepest"]) == 9, "note_area keeps the deepest")
	# Borrowing.
	var lent := Hero.blank("sexton", 12)
	lent["belt"] = ["bellows"]
	var xp0 := int(game.hero()["xp"])
	game.borrow_hero(lent)
	_check(game.borrowing() and game.hero_id() == "sexton" and int(game.hero_stats()["level"]) == 12 and game.equipped("bellows") and game.belt() == ["bellows"],
			"a borrowed hero answers hero(), hero_id(), hero_stats(), equipped(), belt()")
	_check(game.add_xp(5000) == 0 and int(lent["xp"]) == 0 and game.add_item(Items.make("coat", "sexton", 5, "magic", rng)) == "full"
			and game.equip(Items.make("coat", "sexton", 5, "magic", rng)) == null and lent["equip"]["coat"] == null, "and earns nothing, takes nothing, wears nothing")
	_check(game.look()["flame"] == "flame:marigold", "the look stays the player's own")
	game.save()
	var disk = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	_check(not (disk["heroes"] as Dictionary).has("sexton"), "nothing of it is saved")
	game.return_hero()
	_check(not game.borrowing() and game.hero_id() == "knight" and int(game.hero()["xp"]) == xp0, "return_hero: the real hero, untouched")
	# XP at the cap: Candlemarks.
	var got := [0]
	var cb := func(n): got[0] = n
	game.marked.connect(cb)
	game.add_xp(Progression.total_to(40) - int(game.hero()["xp"]))
	_check(int(game.hero()["level"]) == 40 and int(game.xp_progress()["marks"]) == 0, "L40")
	game.add_xp(Progression.MARK_XP * 2 + 10)
	_check(int(game.xp_progress()["marks"]) == 2 and got[0] == 2 and int(game.hero_stats()["marks"]) == 2, "XP keeps counting at the cap: 2 Candlemarks, marked(2)")
	game.add_xp(Progression.MARK_XP * 100)
	_check(int(game.xp_progress()["marks"]) == 25 and int(game.hero()["xp"]) == Progression.total_to(40) + 25 * Progression.MARK_XP, "up to 25 (XP stops at the last one's worth)")
	game.marked.disconnect(cb)
	game.reset()
	game.load_save()
	_check(int(game.hero()["level"]) == 40 and int(game.xp_progress()["marks"]) == 25, "and it saves (a mark saves at once)")
	# Milestones past #4. A build of Worlds 1-2 only: a Legendary every time,
	# as v2; with World 3 in the build, v3's rule (below).
	_fresh()
	var w3_built: bool = game.LEVELS.any(func(l): return int(l["world"]) >= 3)
	_check(game.MILESTONE_ALTERNATE == false and game.milestone_alternate == false and game.milestones_alternate() == w3_built,
			"milestones past #4 alternate exactly when World 3 is built (%s)" % w3_built)
	game.data["sigil_rewards"] = 5
	for i in 14:   # 42 sigils: milestones #6 and #7
		game.data["levels"]["dusk"]["m%d" % i] = {"cleared": true, "sigils": [true, true, true], "best_time": 1.0, "best_embers": 0, "boss_first": false, "dread": false}
	var only_v2: Array = game.LEVELS.duplicate()
	game.LEVELS = game.LEVELS.filter(func(l): return int(l["world"]) <= 2)
	out = game.record_result({"level": "1-1", "cleared": false, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	game.LEVELS = only_v2
	var kinds: Array = (out["rewards"] as Array).map(func(x): return x.get("kind"))
	_check(kinds == ["item", "item"] and str(out["rewards"][0]["item"]["rarity"]) == "legendary" and str(out["rewards"][1]["item"]["rarity"]) == "legendary",
			"a W1-W2 build: milestones #6 and #7 a Legendary each, as v2 (%s)" % [kinds])
	# With it on (v3, from World 3): odd a Legendary, even a relic (or embers).
	_fresh()
	game.milestone_alternate = true
	game.data["sigil_rewards"] = 5
	for i in 14:
		game.data["levels"]["dusk"]["m%d" % i] = {"cleared": true, "sigils": [true, true, true], "best_time": 1.0, "best_embers": 0, "boss_first": false, "dread": false}
	out = game.record_result({"level": "1-1", "cleared": false, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	kinds = (out["rewards"] as Array).map(func(x): return x.get("kind"))
	_check(kinds == ["relic", "item"] and int(game.data["sigil_rewards"]) == 7, "milestones #6 and #7: a relic, then a Legendary (%s)" % [kinds])
	_check(str(out["rewards"][1]["item"]["rarity"]) == "legendary" and game.legends_found().has(str(out["rewards"][1]["item"]["legend"])), "the Legendary is noted")
	for id in Relics.ids():
		game.grant_relic(id)
	game.data["sigil_rewards"] = 7
	for i in 12:
		game.data["levels"]["dusk"]["n%d" % i] = {"cleared": true, "sigils": [true, true, true], "best_time": 1.0, "best_embers": 0, "boss_first": false, "dread": false}
	out = game.record_result({"level": "1-1", "cleared": false, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(out["rewards"].size() >= 1 and out["rewards"][0]["kind"] == "embers" and int(out["rewards"][0]["n"]) == 100, "#8 with the codex full: 100 embers' worth")
	_check(game.world_reached() == 1 and game.level_title("9-S") == "" and game.level_title("1-1") != "", "world_reached; level titles for any id")
	game.milestone_alternate = game.MILESTONE_ALTERNATE
	_fresh()


# ---------------------------------------------------------------- skills

func _test_respec_and_vigil() -> void:
	_fresh()
	game.add_xp(Progression.total_to(10))
	var h: Dictionary = game.hero()
	_check(int(h["level"]) == 10 and int(h["points"]) == 9, "L10 has 9 points")
	var embers_before: int = game.embers()
	for id in ["k_tempered", "k_tempered", "k_devout", "k_mirror", "k_aegis", "k_keen", "k_honed"]:
		game.buy_skill(id)
	_check(game.points_spent() == 7 and int(h["points"]) == 2, "7 points bought, 2 left")
	var back: int = game.respec()
	_check(back == 7 and int(h["points"]) == 9 and game.points_spent() == 0 and (h["skills"] as Dictionary).is_empty(), "Unmaking refunds every point (%d back)" % back)
	_check(game.embers() == embers_before, "and it's free")
	_check(int(game.hero_stats()["ranks"]["k_aegis"]) == 1, "the root keeps its free first rank")
	# Past a full tree, points become Vigil ranks.
	game.add_xp(Progression.total_to(30))
	var tree := Classes.tree_points("knight")
	_check(int(h["level"]) == 30 and int(h["points"]) == tree and int(h["vigil"]) == 29 - tree, "at L30: %d points fill the tree, %d Vigil ranks" % [tree, 29 - tree])
	var s: Dictionary = game.hero_stats()
	var bare := Hero.blank("knight", 30)
	bare["equip"] = h["equip"]
	var s0 := Hero.stats(bare, h["belt"])
	_check(absf(float(s["dmg_pct"]) - float(s0["dmg_pct"]) - 0.02 * int(h["vigil"])) < 1e-6, "each Vigil rank is +2% damage")
	game.respec()
	_check(int(h["vigil"]) == 29 - tree and int(h["points"]) == tree, "a respec leaves the Vigil ranks be")


func _test_skill_gates() -> void:
	_fresh()
	game.add_xp(Progression.total_to(4))   # L4, 3 points
	_check(not game.buy_skill("k_mirror"), "Tier 2 needs 3 points in its branch (none)")
	game.buy_skill("k_tempered")
	game.buy_skill("k_tempered")
	_check(not game.buy_skill("k_tempered"), "a Tier-1 node stops at 2 ranks")
	_check(not game.buy_skill("k_mirror"), "Tier 2 needs 3 points in its branch (2)")
	game.buy_skill("k_devout")
	game.add_xp(Progression.total_to(5) - int(game.hero()["xp"]))
	_check(game.buy_skill("k_mirror"), "Tier 2 opens with 3 points in the branch")
	_fresh()
	game.add_xp(Progression.total_to(2))
	_check(not game.buy_skill("k_aegis"), "root rank 2 is shut at L2")
	game.add_xp(Progression.total_to(3) - int(game.hero()["xp"]))
	_check(game.buy_skill("k_aegis"), "and opens at L3")
	# Capstones: L8 and 5 points in the branch, and only one.
	_fresh()
	game.add_xp(Progression.total_to(7))   # L7, 6 points
	for id in ["k_tempered", "k_tempered", "k_devout", "k_devout", "k_mirror"]:
		game.buy_skill(id)
	_check(game.points_spent() == 5, "5 points in branch 0")
	_check(not game.buy_skill("k_unbroken"), "a capstone is shut at L7")
	game.add_xp(Progression.total_to(8) - int(game.hero()["xp"]))
	_check(game.buy_skill("k_unbroken"), "a capstone opens at L8 with 5 points in the branch")
	game.add_xp(Progression.total_to(15) - int(game.hero()["xp"]))
	for id in ["k_keen", "k_keen", "k_honed", "k_honed", "k_crescent"]:
		game.buy_skill(id)
	_check(not game.buy_skill("k_dawn"), "only one capstone per hero")
	game.respec()
	for id in ["k_keen", "k_keen", "k_honed", "k_honed"]:
		game.buy_skill(id)
	_check(not game.buy_skill("k_dawn"), "a capstone needs 5 points in its branch (4)")
	game.buy_skill("k_crescent")
	_check(game.buy_skill("k_dawn"), "after an Unmaking the other capstone can be picked")
	_check(game.hero_stats()["flags"].get("dawn", false) and not game.hero_stats()["flags"].has("unbroken"), "the capstone's flag reaches the stats")


func _test_altar_rites() -> void:
	## The Altar Rites' offer (rites.gd): only nodes Classes.can_buy allows
	## now, three at most, at most one plain +x% card, a tier just opened
	## first (NEW), a behaviour before a number; nothing with no point
	## waiting. And the flame grows 8% for each big tier owned (a capstone,
	## a Deep node, a Mastery node: +24% at most), its look and nothing else.
	var Rites = load("res://scripts/rites.gd")
	var was_deep: bool = Classes.deep
	Classes.set_deep(true)   # (the game's tree; a test above may have left v2's)
	_fresh()
	_check(Rites.picks(game.hero()).is_empty() and Rites.offers(game.hero()).is_empty(), "no point waiting: nothing offered")
	game.add_xp(Progression.total_to(2))   # L2, 1 point
	var first: Array = Rites.picks(game.hero())
	_check(first.size() == 2 and first[0] == "k_devout" and str(Classes.find_node("knight", first[1])["stat"]) != "",
			"L2: the behaviour (Devout Guard) first, then one +x%% card, and no second (%s)" % [first])
	# Every calling at every level, its points unspent or spent down one
	# branch: every card legal, three at most, one +x% at most.
	var bad := []
	for cls in Classes.ids():
		for lvl in range(2, 31):
			for spent in [false, true]:
				var h := Hero.blank(cls, lvl)
				h["points"] = lvl - 1
				if spent:
					for n in Classes.tree(cls):
						if int(n["branch"]) == 0:
							for i in int(n["max"]):
								if Classes.can_buy(cls, n["id"], h["skills"], lvl, int(h["points"])) == "":
									h["skills"][n["id"]] = int(h["skills"].get(n["id"], 0)) + 1
									h["points"] = int(h["points"]) - 1
				var ids: Array = Rites.picks(h)
				var stats := 0
				for id in ids:
					var n := Classes.find_node(cls, id)
					if Classes.can_buy(cls, id, h["skills"], lvl, int(h["points"])) != "":
						bad.append("%s L%d %s: not buyable" % [cls, lvl, id])
					if str(n["stat"]) != "":
						stats += 1
				if ids.size() > 3 or stats > 1 or (not spent and ids.is_empty()):
					bad.append("%s L%d %s: %s" % [cls, lvl, "spent" if spent else "fresh", ids])
	_check(bad.is_empty(), "every offer legal, at most 3, at most one +x%%, never none with points unspent (%s)" % [bad.slice(0, 4)])
	# L8 with five points in a branch: the capstone first, marked NEW.
	var k := Hero.blank("knight", 8)
	k["skills"] = {"k_tempered": 2, "k_devout": 2, "k_mirror": 1}
	k["points"] = 2
	var cards: Array = Rites.offers(k)
	_check(not cards.is_empty() and cards[0]["id"] == "k_unbroken" and bool(cards[0]["new"]) and cards[0]["glyph"] == "sun"
			and str(cards[0]["sub"]) == "Capstone · rank 1 of 1", "L8: the capstone that just opened comes first, NEW (%s)" % [cards[0] if not cards.is_empty() else {}])
	_check(str(cards[0]["text"]) == Classes.node_text(Classes.find_node("knight", "k_unbroken"), 1), "its card says what it does")
	# L16, the capstone owned: the Deep node that just opened.
	k["level"] = 16
	k["skills"] = {"k_tempered": 2, "k_devout": 2, "k_mirror": 3, "k_unbroken": 1}
	_check(Rites.picks(k)[0] == "k_bastion", "L16: the Deep node first (%s)" % [Rites.picks(k)])
	# The flame: x1.08 a big tier owned, never more than x1.24; light untouched.
	var base := Hero.blank("knight", 30)
	var f0: float = Hero.stats(base)["flame_scale"]
	var s1 := base.duplicate(true)
	s1["skills"] = {"k_tempered": 2, "k_devout": 2, "k_mirror": 1, "k_unbroken": 1}
	var s0 := base.duplicate(true)
	s0["skills"] = {"k_tempered": 2, "k_devout": 2, "k_mirror": 1}
	var s3 := base.duplicate(true)
	s3["skills"] = {"k_tempered": 2, "k_devout": 2, "k_mirror": 3, "k_unbroken": 1, "k_bastion": 3, "k_sanctuary": 1, "k_keen": 2, "k_honed": 2, "k_crescent": 1, "k_dawn": 1}
	var st0: Dictionary = Hero.stats(s0)
	var st1: Dictionary = Hero.stats(s1)
	_check(is_equal_approx(f0, 1.0) and is_equal_approx(float(st0["flame_scale"]), 1.0), "no big tier: the calling's own flame (%.2f)" % f0)
	_check(is_equal_approx(float(st1["flame_scale"]), 1.08), "a capstone: x1.08 (%.2f)" % st1["flame_scale"])
	_check(is_equal_approx(float(Hero.stats(s3)["flame_scale"]), 1.24), "a capstone (two), a Deep and a Mastery node: x1.24, no more (%.2f)" % Hero.stats(s3)["flame_scale"])
	var fs := Hero.blank("founder", 30)
	fs["skills"] = {"f_bellows": 2, "f_stoked": 2, "f_slag": 1, "f_crucible": 1}
	_check(is_equal_approx(float(Hero.stats(fs)["flame_scale"]), 1.25 * 1.08), "on the calling's own size (the Bellfounder's 1.25 x 1.08)")
	_check(is_equal_approx(Combat.light_radius(1.0, st1, "dusk"), Combat.light_radius(1.0, st0, "dusk")) and float(st1["max_hp"]) == float(st0["max_hp"])
			and is_equal_approx(float(st1["basic"]), float(st0["basic"])), "the light, life and damage don't move with it")
	Classes.set_deep(was_deep)


# ---------------------------------------------------------------- belt

func _test_belt() -> void:
	_check(Progression.belt_slots(1) == 2 and Progression.belt_slots(4) == 2 and Progression.belt_slots(5) == 3 and Progression.belt_slots(9) == 3 and Progression.belt_slots(10) == 4
			and Progression.belt_slots(23) == 4 and Progression.belt_slots(24) == 5 and Progression.belt_slots(40) == 5, "belt slots: 2 / 3 / 4 / 5 at L1 / L5 / L10 / L24")
	_fresh()
	_check(game.grant_relic("tallow_heart") and game.grant_relic("rook_feather"), "the first two relics go onto the belt")
	_check(not game.grant_relic("bellows") and game.has_relic("bellows") and not game.equipped("bellows"), "a third is stowed in the codex (2 slots at L1)")
	game.set_belt(["bellows", "tallow_heart", "rook_feather"])
	_check(game.belt() == ["bellows", "tallow_heart"], "the belt holds only what its slots allow")
	game.set_belt(["phoenix_wick", "tallow_heart", "tallow_heart"])
	_check(game.belt() == ["tallow_heart"], "unfound and doubled relics stay off the belt")
	_check(not game.grant_relic("not_a_relic") and not game.has_relic("not_a_relic"), "unknown relics aren't granted")
	game.add_xp(Progression.total_to(5))
	_check(game.belt_slots() == 3 and game.belt().size() == 3, "reaching L5 opens a third slot and fills it from the codex")
	game.add_xp(Progression.total_to(10))
	game.grant_relic("moth_charm")
	_check(game.belt_slots() == 4 and game.belt().size() == 4 and game.equipped("moth_charm"), "L10 opens the fourth")


# ---------------------------------------------------------------- callings

func _test_new_calling() -> void:
	_wipe()
	game.reset()
	var k: Dictionary = game.new_hero("knight")
	_check(int(k["level"]) == 1 and int(k["points"]) == 0, "the first calling starts at L1")
	game.add_xp(Progression.total_to(10))
	game.grant_relic("tallow_heart")
	var w: Dictionary = game.new_hero("witch")
	_check(game.hero_id() == "witch" and int(w["level"]) == 8, "a later calling starts at best - 2 (L8)")
	_check(int(w["xp"]) == Progression.total_to(8) and int(w["points"]) == 7 and (w["skills"] as Dictionary).is_empty(), "with its XP at that level and 7 points unspent")
	var ok := true
	for slot in ["weapon", "candle", "coat"]:
		ok = ok and w["equip"][slot]["rarity"] == "magic" and int(w["equip"][slot]["ilvl"]) == 8
	_check(ok and w["equip"]["weapon"]["cls"] == "witch", "and a Blessed witch's kit at ilvl 8")
	_check(game.equipped("tallow_heart"), "and the codex relics on its belt")
	_check(game.new_hero("knight")["level"] == 10 and game.hero_id() == "knight", "asking for a calling that exists just plays it")
	game.set_hero("witch")
	game.add_xp(Progression.total_to(30))
	var r: Dictionary = game.new_hero("runner")
	_check(int(r["level"]) == 28 and int(r["points"]) == Classes.tree_points("runner") and int(r["vigil"]) == 27 - Classes.tree_points("runner"), "a calling started past a full tree banks the rest as Vigil ranks")
	_wipe()
	game.reset()
	game.new_hero("knight")
	game.add_xp(Progression.total_to(3))
	_check(int(game.new_hero("runner")["level"]) == 1, "a later calling never starts below L1")


# ---------------------------------------------------------------- the satchel

func _test_salvage_weaker() -> void:
	## Salvage weaker (the Sheet's Gear tab and the Chandler) melts what
	## weaker_items() lists: no better than what's worn in its slot, never a
	## Legendary (like a full satchel), never for an empty slot; and it pays
	## exactly weaker_value().
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var h: Dictionary = game.hero()
	var worn: Dictionary = h["equip"]["coat"]
	var weak: Dictionary = worn.duplicate(true)
	weak["uid"] = "weak-coat"
	weak["implicit"]["v"] = 0.0
	var leg := Items.make("coat", "knight", 1, "legendary", rng, "ossuary_coat")
	leg["implicit"]["v"] = 0.0
	leg["affixes"] = []
	var strong := Items.make("coat", "knight", 20, "rare", rng)
	var charm := Items.make("charm", "knight", 1, "magic", rng)   # nothing worn there
	h["satchel"] = [weak, leg, strong, charm]
	_check(float(Hero.compare(h, "coat", leg)["life"]) <= 0.0, "the Legendary is no better than the worn coat")
	var list: Array = game.weaker_items()
	_check(list.size() == 1 and str(list[0]["uid"]) == "weak-coat", "only the weaker Common counts (%d)" % list.size())
	var e0: int = game.embers()
	var want: int = game.weaker_value()
	_check(want == Items.salvage_value(weak), "weaker_value is what it pays")
	_check(game.salvage_weaker() == want and game.embers() == e0 + want, "salvage_weaker pays it")
	var left: Array = (h["satchel"] as Array).map(func(x): return str(x["uid"]))
	_check(left.size() == 3 and not left.has("weak-coat") and left.has(str(leg["uid"])), "the Legendary, the better coat and the charm stay")
	_check(game.salvage_weaker() == 0 and (h["satchel"] as Array).size() == 3, "again: nothing more to melt")
	h["satchel"] = []
	for i in game.SATCHEL_MAX:
		h["satchel"].append(Items.make("candle", "knight", 1, "magic", rng))
	_check(game.satchel_full(), "satchel_full at %d" % game.SATCHEL_MAX)


func _test_satchel_full() -> void:
	## Spec 4.4: with the satchel full, anything weaker than what's worn melts
	## into embers; anything else stays on the ground ("full").
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var h: Dictionary = game.hero()
	var worn: Dictionary = h["equip"]["coat"]
	var weak: Dictionary = worn.duplicate(true)
	weak["uid"] = "weak-coat"
	weak["rarity"] = "magic"
	weak["implicit"]["v"] = 1.0
	weak["affixes"] = [{"id": "bell", "t": 1, "v": 0.0}]
	_check(game.add_item(weak.duplicate(true)) == "satchel", "with room, even a weaker item goes to the satchel")
	h["satchel"] = []
	for i in game.SATCHEL_MAX:
		h["satchel"].append(Items.make("candle", "knight", 1, "magic", rng))
	var e0: int = game.embers()
	_check(game.add_item(weak) == "salvaged" and game.embers() == e0 + Items.salvage_value(weak), "full: a weaker Blessed coat melts into embers (+%d)" % Items.salvage_value(weak))
	var strong := Items.make("weapon", "knight", 20, "rare", rng)
	_check(game.add_item(strong) == "full" and game.embers() == e0 + Items.salvage_value(weak), "full: a better Rare stays on the ground")
	var leg := Items.make("coat", "knight", 1, "legendary", rng, "ossuary_coat")
	leg["implicit"]["v"] = 0.0
	leg["affixes"] = []
	_check(float(Hero.compare(h, "coat", leg)["life"]) < 0.0 and game.add_item(leg) == "full", "full: a Legendary is never melted, even a weaker one")
	h["equip"]["candle"] = null
	_check(game.add_item(Items.make("candle", "knight", 1, "magic", rng)) == "full", "full: an item for an empty slot stays on the ground")
	_check((h["satchel"] as Array).size() == game.SATCHEL_MAX, "and the satchel never goes past %d" % game.SATCHEL_MAX)
	game.set_setting("auto_salvage", false)
	var plain: Dictionary = worn.duplicate(true)
	plain["uid"] = "plain-coat"
	plain["implicit"]["v"] = 1.0
	_check(game.add_item(plain) == "salvaged", "full: a weaker Common melts even with auto-salvage off")
	game.set_setting("auto_salvage", true)


func _test_equip_full() -> void:
	## Wearing a new item with the satchel full has no room for the one it
	## replaces: that one melts into embers (it's weaker by then), and the
	## satchel stays at SATCHEL_MAX. A Legendary is never melted: the
	## satchel's weakest non-Legendary goes instead. Swapping with an item
	## out of the satchel melts nothing, and with room nothing melts.
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var h: Dictionary = game.hero()
	var coat: Dictionary = h["equip"]["coat"]
	var new_coat := Items.make("coat", "knight", 6, "rare", rng)
	_check(game.melt_on_equip(new_coat).is_empty(), "with room, wearing melts nothing")
	game.equip(new_coat)
	_check(game.last_melt.is_empty() and (h["satchel"] as Array).size() == 1, "the old coat goes to the satchel")
	h["satchel"] = []
	for i in game.SATCHEL_MAX:
		h["satchel"].append(Items.make(["boots", "charm"][i % 2], "knight", 1 + i % 3, "magic", rng))
	var sword: Dictionary = h["equip"]["weapon"]
	var blade := Items.make("weapon", "knight", 8, "rare", rng)
	_check(str(game.melt_on_equip(blade).get("uid", "")) == str(sword["uid"]), "full: wearing a new blade would melt the worn sword")
	var e0: int = game.embers()
	_check(str(game.equip(blade).get("uid", "")) == str(sword["uid"]), "equip still returns what it replaced")
	_check((h["satchel"] as Array).size() == game.SATCHEL_MAX, "the satchel stays at %d" % game.SATCHEL_MAX)
	_check(game.embers() == e0 + Items.salvage_value(sword), "the sword melted for its embers (+%d)" % Items.salvage_value(sword))
	_check(str(game.last_melt.get("for", "")) == str(blade["uid"]) and bool(game.last_melt.get("old", false)), "last_melt says so, for the blade")
	h["satchel"][0] = Items.make("coat", "knight", 2, "magic", rng)
	var from_bag: Dictionary = h["satchel"][0]
	var worn_then = h["equip"][from_bag["slot"]]
	game.equip(from_bag)
	_check(game.last_melt.is_empty() and (h["satchel"] as Array).size() == game.SATCHEL_MAX, "a swap out of the satchel melts nothing")
	if worn_then is Dictionary:
		var still := false
		for o in h["satchel"]:
			still = still or str(o.get("uid", "")) == str(worn_then["uid"])
		_check(still, "what it replaced is in the satchel")
	# A Legendary worn: the weakest non-Legendary in the satchel goes instead.
	var leg := Items.make("candle", "knight", 3, "legendary", rng, Items.pick_legend("candle", "knight", rng))
	h["equip"]["candle"] = leg
	var weakest: Dictionary = {}
	for o in h["satchel"]:
		if weakest.is_empty() or Items.power(o) < Items.power(weakest):
			weakest = o
	var candle := Items.make("candle", "knight", 20, "rare", rng)
	e0 = game.embers()
	game.equip(candle)
	var uids: Array = (h["satchel"] as Array).map(func(x): return str(x["uid"]))
	_check(uids.has(str(leg["uid"])), "the worn Legendary goes to the satchel, not the fire")
	_check(not uids.has(str(weakest["uid"])) and game.embers() == e0 + Items.salvage_value(weakest), "the weakest there melted instead")
	_check(uids.size() == game.SATCHEL_MAX and not bool(game.last_melt.get("old", true)), "the satchel stays at %d" % game.SATCHEL_MAX)
	# Nothing but Legendaries in there: nothing melts, it holds one more.
	h["satchel"] = []
	for i in game.SATCHEL_MAX:
		h["satchel"].append(Items.make("charm", "knight", 2, "legendary", rng, Items.pick_legend("charm", "knight", rng)))
	var leg2 := Items.make("weapon", "knight", 4, "legendary", rng, Items.pick_legend("weapon", "knight", rng))
	h["equip"]["weapon"] = leg2
	game.equip(Items.make("weapon", "knight", 20, "rare", rng))
	_check(game.last_melt.is_empty() and (h["satchel"] as Array).size() == game.SATCHEL_MAX + 1, "all Legendaries: none melts, the satchel holds one more")


# ---------------------------------------------------------------- settings

func _test_settings_cache() -> void:
	## Game keeps the settings in memory: the world asks for "shake" every
	## physics tick, so the file is read once, not 120 times a second.
	_wipe()
	game.reset()
	SettingsLib.write({"muted": true}, SETTINGS)   # a key Sfx keeps in the same file
	game.reload_settings()
	_check(float(game.setting("shake")) == 1.0 and game.setting("numbers") == "on", "missing keys fall back to their defaults")
	game.set_setting("shake", 0.5)
	var disk: Dictionary = SettingsLib.read(SETTINGS)
	_check(float(game.setting("shake")) == 0.5 and float(disk.get("shake", 0.0)) == 0.5 and disk.get("muted") == true, "set_setting writes through and keeps the other keys in the file")
	SettingsLib.write({"shake": 0.25}, SETTINGS)
	_check(float(game.setting("shake")) == 0.5, "reads come from memory, not the file")
	game.reload_settings()
	_check(float(game.setting("shake")) == 0.25, "reload_settings reads the file again")
	game.haptics = false
	_check(game.haptics == false and SettingsLib.read(SETTINGS).get("haptics") == false, "Game.haptics reads and writes through the same cache")
	game.settings_path = SETTINGS + ".other"
	_check(float(game.setting("shake")) == 1.0, "a new settings_path is read afresh")
	game.settings_path = SETTINGS
	_check(float(game.setting("shake")) == 0.25, "and switching back reads the first file again")
	if FileAccess.file_exists(SETTINGS + ".other"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS + ".other"))
	_wipe()
	game.reset()
	_check(float(game.setting("shake")) == 1.0 and game.haptics == true, "reset() re-reads: a deleted file means defaults")


# ---------------------------------------------------------------- the Chandler

func _test_chandler_logic() -> void:
	_fresh()
	game.add_xp(Progression.total_to(6))
	var stock: Array = game.wares()
	_check(stock.size() == 4, "Waxley stocks 4 wares")
	var rar := []
	var ok := true
	for it in stock:
		rar.append(it["rarity"])
		ok = ok and int(it["ilvl"]) == 6 and Items.LIVE_SLOTS.has(it["slot"])
		if it["slot"] == "weapon":
			ok = ok and it["cls"] == "knight"
	_check(rar == ["magic", "magic", "rare", "magic"], "2 Blessed, a Rare and one more Blessed (%s)" % [rar])
	_check(ok, "all at the hero's level, live slots, knight weapons")
	_check(stock[3]["slot"] == game.weakest_slot(), "the fourth is for the weakest slot (%s)" % stock[3]["slot"])
	_check(stock[0]["slot"] != stock[1]["slot"] and stock[1]["slot"] != stock[2]["slot"] and stock[0]["slot"] != stock[2]["slot"], "the first three are three different slots")
	_check(game.ware_price(stock[0]) == 30 + 8 * 6 and game.ware_price(stock[2]) == 90 + 20 * 6, "priced 30 + 8*ilvl and 90 + 20*ilvl")
	var uids: Array = stock.map(func(it): return it["uid"])
	_check(game.wares().map(func(it): return it["uid"]) == uids, "the stock holds until a bell rings")
	# Too poor, then rich.
	_check(game.ware_verdict(0) == "poor" and game.buy_ware(0) == "poor" and game.wares()[0] != null, "no sale without the embers")
	game.add_embers(1000)
	var told: String = game.ware_verdict(3)
	_check((told == "equipped" or told == "satchel") and game.embers() == 1000 and game.wares()[3] != null, "ware_verdict says what a sale would do without making it (%s)" % told)
	var price: int = game.ware_price(stock[3])
	var where: String = game.buy_ware(3)
	_check(where == "equipped" or where == "satchel", "a sale equips or goes to the satchel (%s)" % where)
	_check(game.embers() == 1000 - price and game.wares()[3] == null, "it costs its price and leaves the shelf")
	_check(game.buy_ware(3) == "sold", "a sold ware can't be bought twice")
	# Ringing a bell restocks.
	game.record_result({"level": "1-1", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	var fresh_uids: Array = game.wares().map(func(it): return it["uid"] if it != null else "")
	_check(fresh_uids != uids and not fresh_uids.has(""), "a rung bell restocks the shelf")
	game.record_result({"level": "1-1", "cleared": false, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	_check(game.wares().map(func(it): return it["uid"] if it != null else "") == fresh_uids, "a level left unfinished doesn't")
	# An upgrade is worn at once.
	var h: Dictionary = game.hero()
	h["equip"]["coat"] = null
	h["wares"][1] = Items.make("coat", "knight", 6, "magic", RandomNumberGenerator.new())
	_check(game.buy_ware(1) == "equipped" and h["equip"]["coat"] != null, "a ware for an empty slot is worn at once")
	# Relics.
	var offers: Array = game.relic_offers()
	_check(offers.map(func(r): return r["rarity"]) == ["common", "magic", "rare"], "three relics on the shelf, one of each rarity, cheapest first")
	var e0: int = game.embers()
	_check(game.relic_verdict(offers[0]["id"]) == "belt" and game.embers() == e0 and not game.has_relic(offers[0]["id"]), "relic_verdict tells without buying")
	_check(game.buy_relic(offers[0]["id"]) == "belt" and game.embers() == e0 - Relics.PRICE["common"], "buying a relic puts it on the belt and costs its price")
	_check(game.buy_relic(offers[0]["id"]) == "owned", "a relic already found isn't sold again")
	while game.belt().size() < game.belt_slots():
		game.buy_relic(game.relic_offers()[0]["id"])
	var extra: String = game.relic_offers()[0]["id"]
	_check(game.buy_relic(extra) == "stowed" and game.has_relic(extra) and not game.equipped(extra), "with the belt full it goes to the codex")
	var spend_all: int = game.embers()
	game.spend_embers(spend_all)
	_check(game.buy_relic(game.relic_offers()[0]["id"]) == "poor", "no relic without the embers")
	# The satchel full: a sidegrade can't be bought.
	game.add_embers(5000)
	game.record_result({"level": "1-1", "cleared": true, "embers": 0, "sigils": [false, false, false], "time": 60.0, "relics": []})
	game.wares()   # the restock happens here, before the shelf is rigged
	h["satchel"] = []
	for i in game.SATCHEL_MAX:
		h["satchel"].append(Items.make("candle", "knight", 1, "magic", RandomNumberGenerator.new()))
	var weak := Items.make("candle", "knight", 1, "common", RandomNumberGenerator.new())
	h["wares"][0] = weak
	var e1: int = game.embers()
	_check(game.ware_verdict(0) == "full" and game.buy_ware(0) == "full" and game.embers() == e1, "with the satchel full, a ware that isn't worn isn't sold")


func _test_chandler_screen() -> void:
	_fresh()
	game.add_xp(Progression.total_to(6))
	game.add_embers(400)
	game.grant_relic("tallow_heart")
	game.mark_seen("meet_waxley")   # the story beat is W4's to test
	var sc = load("res://scripts/chandler_screen.gd")
	_check(sc != null, "chandler_screen.gd loads")
	if sc == null:
		return
	var scr: Control = sc.new()
	root.add_child(scr)
	for i in 3:
		await process_frame
	var vs: Vector2 = scr.get_size()
	_check(vs.x >= 800.0 and vs.y >= 380.0, "the Chandler fills the screen (%s)" % vs)
	var safe: Rect2 = scr.call("_safe")
	var buttons := _buttons(scr)
	var ok := true
	for b in buttons:
		if not b.visible:
			continue
		var r := Rect2(b.global_position, b.size)
		if r.size.y < 44.0 or r.size.x < 44.0 or not safe.grow(1.0).encloses(r):
			ok = false
			print("  button '%s' at %s (safe %s)" % [b.text, r, safe])
	_check(ok and buttons.size() >= 5, "every button is touch-sized and inside the safe area (%d)" % buttons.size())
	# Every tab, on this screen and inside an iPhone 17 Pro Max's safe area
	# (847 x 390 with the island and home bar cut out).
	for promax in [false, true]:
		if promax:
			scr.set("safe_override", Rect2(55, 10, vs.x - 110, vs.y - 28))
			safe = scr.call("_safe")
		for tab in ["relics", "wares", "unmake"]:
			scr.call("show_tab", tab)
			await process_frame
			var shown := _buttons(scr).filter(func(b): return b.visible)
			var inside := not shown.is_empty()
			for b in shown:
				var r := Rect2(b.global_position, b.size)
				inside = inside and safe.grow(1.0).encloses(r) and r.size.y >= 44.0 and r.size.x >= 44.0
			_check(inside, "the %s tab lays out inside the %s safe area" % [tab, "Pro Max" if promax else "screen's"])
		scr.call("show_tab", "wares")
		await process_frame
		var cards: Array = scr.call("_cards")
		var apart := true
		for i in cards.size() - 1:
			apart = apart and cards[i].end.x < cards[i + 1].position.x
		_check(apart and safe.grow(1.0).encloses(cards[0]) and safe.grow(1.0).encloses(cards[cards.size() - 1]), "the cards sit side by side inside it")
	# Buy a ware through its button.
	scr.call("show_tab", "wares")
	await process_frame
	var e0: int = game.embers()
	var price: int = game.ware_price(game.wares()[0])
	var buy: Button = scr.get("_buy_btns")[0]
	buy.pressed.emit()
	await process_frame
	_check(game.embers() == e0 and game.wares()[0] != null and int(scr.get("_sale")) == 0, "one tap on a price only asks \"Buy?\": nothing spent")
	buy.pressed.emit()
	await process_frame
	_check(game.embers() == e0 - price, "the second tap buys: it spends the ware's price (%d)" % price)
	_check(game.wares()[0] == null and int(scr.get("_sale")) == -1, "and the ware leaves the shelf")
	# The question lapses, moves to another price, or goes with the tab.
	var b1: Button = scr.get("_buy_btns")[1]
	var b2: Button = scr.get("_buy_btns")[2]
	b1.pressed.emit()
	scr.call("_process", float(sc.CONFIRM_TIME) + 0.1)
	_check(int(scr.get("_sale")) == -1, "after %d s the question lapses" % int(sc.CONFIRM_TIME))
	b1.pressed.emit()
	_check(game.wares()[1] != null and int(scr.get("_sale")) == 1, "and the next tap asks again rather than buying")
	b2.pressed.emit()
	b1.pressed.emit()
	_check(game.wares()[1] != null and game.wares()[2] != null and int(scr.get("_sale")) == 1, "tapping another price asks about that one instead: nothing bought")
	var kept: int = game.embers()
	game.spend_embers(kept)
	b2.pressed.emit()
	_check(int(scr.get("_sale")) == -1 and float(scr.get("_deny")) > 0.0 and game.wares()[2] != null, "too dear: refused on the first tap, no question asked")
	game.add_embers(kept)
	scr.call("show_tab", "relics")
	await process_frame
	var offer: String = game.relic_offers()[0]["id"]
	var rb: Button = scr.get("_buy_btns")[0]
	rb.pressed.emit()
	_check(not game.has_relic(offer) and int(scr.get("_sale")) == 0, "a relic asks first too")
	scr.call("show_tab", "wares")
	_check(int(scr.get("_sale")) == -1, "changing tab clears the question")
	scr.call("show_tab", "relics")
	await process_frame
	rb = scr.get("_buy_btns")[0]
	rb.pressed.emit()
	rb.pressed.emit()
	await process_frame
	_check(game.has_relic(offer) and game.embers() == kept - Relics.price(offer), "and two taps buy it")
	# Unmake through its button.
	game.buy_skill("k_tempered")
	scr.call("show_tab", "unmake")
	await process_frame
	var um: Button = scr.get("_unmake_btn")
	um.pressed.emit()
	await process_frame
	um.pressed.emit()   # the second tap confirms
	await process_frame
	_check(game.points_spent() == 0, "Unmake (two taps) refunds the points")
	var went := [false]
	scr.connect("back", func(): went[0] = true)
	scr.get("_back_btn").pressed.emit()
	await process_frame
	_check(went[0], "the back button signals back")
	scr.queue_free()
	await process_frame


func _test_chandler_screen_v3() -> void:
	## The Chandler by depth on screen: five and six wares in two rows of three,
	## the Reserve's tall card, the Draughts tab (four tabs beside the title),
	## every button thumb-sized inside the safe area, nothing overlapping, on
	## this screen and the Pro Max's; two taps buy the Reserve, a draught and
	## a Rekindle.
	var sc = load("res://scripts/chandler_screen.gd")
	var kept_levels: Array = game.LEVELS
	for promax in [false, true]:
		for depth in [[15, 14], [25, 24], [31, 30]]:
			_fresh()
			_set_depth(int(depth[0]), int(depth[1]))
			game.add_embers(4000)
			game.mark_seen("meet_waxley")
			var scr: Control = sc.new()
			root.add_child(scr)
			await process_frame
			if promax:
				scr.set("safe_override", Rect2(55, 10, scr.get_size().x - 110, scr.get_size().y - 28))
				scr.call("_layout")
			await process_frame
			var tag := "depth %d%s" % [depth[1], " (Pro Max)" if promax else ""]
			_screen_fits(scr, tag)
			var cards: Array = scr.call("_cards")
			var rr: Rect2 = scr.call("reserve_rect")
			var n: int = game.ware_count()
			_check(bool(scr.call("grid")) and cards.size() == n and (rr.has_area() == (int(depth[1]) >= 23)), "%s: %d wares in the grid, the Reserve %s" % [tag, n, "beside them" if rr.has_area() else "not yet"])
			if rr.has_area():
				_check(str(scr.get("_line")) == str(scr.call("reserve_line")) and str(scr.call("reserve_line")) != "" and bool(scr.get("line_fits")),
						"%s: a fresh Reserve: Waxley says the reserve_stocked bark, and it fits (\"%s\")" % [tag, scr.call("reserve_line")])
			await _sheet_ok(scr, tag)
			if rr.has_area():
				var ri: int = (scr.get("_acts") as Array).size() - 1
				var e0: int = game.embers()
				var price := int(game.reserve()["price"])
				var rb: Button = scr.get("_buy_btns")[ri]
				rb.pressed.emit()
				_check(game.embers() == e0 and game.reserve()["item"] != null, "%s: one tap on the Reserve only asks" % tag)
				rb.pressed.emit()
				await process_frame
				_check(game.embers() == e0 - price and game.reserve()["item"] == null, "%s: the second buys it (%d)" % [tag, price])
			scr.queue_free()
			await process_frame
		# The Draughts tab in World 3: the flask as it is, Rekindle's padlock strip.
		_fresh()
		_set_depth(16, 15)
		game.LEVELS = game.ALL_LEVELS.slice(0, 12)
		game.data["unlocked"]["dusk"] = 9
		game.mark_seen("meet_waxley")
		var d3: Control = sc.new()
		root.add_child(d3)
		await process_frame
		if promax:
			d3.set("safe_override", Rect2(55, 10, d3.get_size().x - 110, d3.get_size().y - 28))
		d3.call("show_tab", "draughts")
		await process_frame
		var tag3 := "the Draughts tab in World 3%s" % (" (Pro Max)" if promax else "")
		var fr: Rect2 = d3.call("flask_rect")
		var kr3: Rect2 = d3.call("rekindle_rect")
		_check(not game.rekindle_open() and fr.has_area() and is_equal_approx(kr3.size.y, float(d3.get("LOCK_H"))) and fr.end.y < kr3.position.y
				and is_equal_approx(fr.position.x, kr3.position.x), "%s: the flask above a padlock strip for Rekindle, not an empty box" % tag3)
		_screen_fits(d3, tag3, 4)
		d3.queue_free()
		await process_frame
		game.LEVELS = kept_levels
		# The Draughts tab, World 5 reached: the Rich Draught and Rekindle for sale.
		_fresh()
		_set_depth(26, 25)
		game.LEVELS = game.ALL_LEVELS.slice(0, 20)
		game.data["unlocked"]["dusk"] = 17
		game.data["flask"]["draughts"] = 1
		game.level_record("4-4", "dusk")["cleared"] = true
		game.add_embers(4000)
		game.mark_seen("meet_waxley")
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		game.hero()["satchel"].append(Items.make("candle", "knight", 14, "legendary", rng, "marrow_lantern"))
		var ds: Control = sc.new()
		root.add_child(ds)
		await process_frame
		if promax:
			ds.set("safe_override", Rect2(55, 10, ds.get_size().x - 110, ds.get_size().y - 28))
		ds.call("show_tab", "draughts")
		await process_frame
		var tag := "the Draughts tab%s" % (" (Pro Max)" if promax else "")
		_check((ds.call("tabs_shown") as Array).size() == 4 and str(ds.get("tab")) == "draughts", "%s: four tabs, Draughts on show" % tag)
		_screen_fits(ds, tag)
		var safe: Rect2 = ds.call("_safe")
		var title_end: float = safe.position.x + 96.0 + ds.UI.text_width("The Chandler", 26, "title", 700)
		var first_tab: Button = ds.get("_tab_btns")["relics"]
		_check(first_tab.global_position.x >= title_end, "%s: the tabs clear the title (%.0f >= %.0f)" % [tag, first_tab.global_position.x, title_end])
		var acts: Array = ds.get("_acts")
		var di := -1
		var ki := -1
		for i in acts.size():
			if acts[i]["kind"] == "draught":
				di = i
			if acts[i]["kind"] == "rekindle" and ki < 0:
				ki = i
		_check(di >= 0 and ki >= 0, "%s: a price for the Rich Draught and one for Rekindle" % tag)
		if di >= 0:
			var b: Button = ds.get("_buy_btns")[di]
			b.pressed.emit()
			_check(not bool(game.data["flask"]["rich"]), "%s: one tap asks" % tag)
			b.pressed.emit()
			await process_frame
			_check(bool(game.data["flask"]["rich"]) and game.embers() == 4000 - 1600, "%s: two taps buy the Rich Draught" % tag)
			acts = ds.get("_acts")
			ki = -1
			for i in acts.size():
				if acts[i]["kind"] == "rekindle" and ki < 0:
					ki = i
		if ki >= 0:
			var kb: Button = ds.get("_buy_btns")[ki]
			var e1: int = game.embers()
			kb.pressed.emit()
			kb.pressed.emit()
			await process_frame
			_check(game.embers() == e1 - (200 + 30 * 26), "%s: two taps rekindle" % tag)
		ds.queue_free()
		await process_frame
		game.LEVELS = kept_levels
	game.LEVELS = kept_levels


func _screen_fits(scr: Control, tag: String, min_buttons := 5) -> void:
	## Every visible button a thumb (44 x 44) inside the safe area, no two
	## overlapping; every card inside it and apart.
	var safe: Rect2 = scr.call("_safe")
	var shown := _buttons(scr).filter(func(b): return b.visible)
	var bad := []
	for i in shown.size():
		var r := Rect2(shown[i].global_position, shown[i].size)
		if r.size.y < 44.0 or r.size.x < 44.0 or not safe.grow(1.0).encloses(r):
			bad.append("'%s' %s" % [shown[i].text, r])
		for j in range(i + 1, shown.size()):
			var r2 := Rect2(shown[j].global_position, shown[j].size)
			if r.grow(-1.0).intersects(r2.grow(-1.0)):
				bad.append("'%s' on '%s'" % [shown[i].text, shown[j].text])
	_check(bad.is_empty() and shown.size() >= min_buttons, "%s: every button a thumb inside the safe area, none overlapping (%s)" % [tag, bad])
	var cards: Array = scr.call("_cards")
	var rr: Rect2 = scr.call("reserve_rect")
	if rr.has_area():
		cards.append(rr)
	for c in scr.call("draught_cards"):
		cards.append(c)
	var kr: Rect2 = scr.call("rekindle_rect")
	if kr.has_area():
		cards.append(kr)
	var fr: Rect2 = scr.call("flask_rect")
	if fr.has_area():
		cards.append(fr)
	var ok := true
	for i in cards.size():
		ok = ok and safe.grow(1.0).encloses(cards[i])
		for j in range(i + 1, cards.size()):
			ok = ok and not (cards[i] as Rect2).intersects(cards[j])
	_check(ok and not cards.is_empty(), "%s: the cards sit apart inside the safe area (%d)" % [tag, cards.size()])


func _sheet_ok(scr: Control, tag: String) -> void:
	## The detail sheet (a tap on a compact card or the Reserve's): inside the
	## safe area over the cards, every button a thumb, none overlapping; its
	## price button and Close inside it; every line of the item there, each
	## fitting its row and clear of the others and of the band; two taps in it
	## buy; a tap outside shuts it; a sold card says so.
	var cards: Array = scr.call("_cards")
	var safe: Rect2 = scr.call("_safe")
	var targets: Array = []
	for k in cards.size():
		targets.append([k, (cards[k] as Rect2).get_center()])
	var rr: Rect2 = scr.call("reserve_rect")
	if rr.has_area() and game.reserve().get("item") is Dictionary:
		targets.append([scr.call("_act_index", "reserve"), rr.get_center()])
	for t in targets:
		scr.call("tap_at", t[1])
		await process_frame
		var i: int = scr.call("detail_shown")
		var it = scr.call("detail_item")
		var d: Rect2 = scr.call("detail_rect")
		var band: Rect2 = scr.call("detail_band")
		var sub := "%s, sheet %d" % [tag, int(t[0])]
		_check(i == int(t[0]) and it is Dictionary and safe.grow(1.0).encloses(d), "%s: the tap opens it, inside the safe area" % sub)
		_screen_fits(scr, sub)
		var pb: Button = scr.get("_buy_btns")[i]
		var cb: Button = scr.get("_close_btn")
		_check(pb.visible and cb.visible and d.encloses(Rect2(pb.position, pb.size)) and d.encloses(Rect2(cb.position, cb.size))
				and (scr.get("_buy_btns") as Array).filter(func(b): return b.visible).size() == 1, "%s: its price and Close in it, the other prices hidden" % sub)
		var rows: Array = scr.call("detail_rows")
		var bad := []
		for r in rows:
			var pos: Vector2 = r["pos"]
			var wd: float = scr.UI.text_width(str(r["text"]), int(r["size"]), str(r["kind"]), int(r["weight"]))
			if wd > float(r["w"]) + 0.5 or pos.x < d.position.x or pos.x + wd > d.end.x - 8.0 or pos.y - int(r["size"]) < d.position.y or pos.y > band.position.y - 2.0 or int(r["size"]) < 10:
				bad.append(str(r["text"]))
		for a in rows.size():
			for b in range(a + 1, rows.size()):
				var pa: Vector2 = rows[a]["pos"]
				var pb2: Vector2 = rows[b]["pos"]
				var wa: float = scr.UI.text_width(str(rows[a]["text"]), int(rows[a]["size"]), str(rows[a]["kind"]), int(rows[a]["weight"]))
				var wb: float = scr.UI.text_width(str(rows[b]["text"]), int(rows[b]["size"]), str(rows[b]["kind"]), int(rows[b]["weight"]))
				var apart_x: bool = pa.x + wa <= pb2.x or pb2.x + wb <= pa.x
				var apart_y: bool = absf(pa.y - pb2.y) >= float(mini(int(rows[a]["size"]), int(rows[b]["size"])))
				if not apart_x and not apart_y:
					bad.append("'%s' on '%s'" % [rows[a]["text"], rows[b]["text"]])
		var texts: Array = rows.map(func(r): return str(r["text"]))
		var missing := []
		for ln in Items.lines(it):
			if ln["kind"] != "legend" and not texts.has(str(ln["text"])):
				missing.append(ln["text"])
		var power := str(Items.LEGENDS.get(str(it.get("legend", "")), {}).get("text", ""))
		var shown_power := " ".join(PackedStringArray(rows.filter(func(r): return r["col"] == Color("ffc080")).map(func(r): return str(r["text"]))))
		_check(bad.is_empty() and missing.is_empty() and shown_power == power and texts.has(str(it["name"])),
				"%s: every line of %s shows, whole, each in its room (%s %s)" % [sub, it["name"], bad, missing])
		scr.call("tap_at", Vector2(safe.position.x + 2.0, safe.end.y - 2.0) if not d.has_point(Vector2(safe.position.x + 2.0, safe.end.y - 2.0)) else Vector2(1, 1))
		_check(int(scr.call("detail_shown")) == -1 and not cb.visible and (scr.get("_buy_btns") as Array).filter(func(b): return b.visible).size() >= 2,
				"%s: a tap outside shuts it, the prices back" % sub)
	# Two taps in the sheet buy the first ware; its card then says so, and a
	# tap on it says it's sold.
	var e0: int = game.embers()
	var price: int = game.ware_price(game.wares()[0])
	scr.call("tap_at", (cards[0] as Rect2).get_center())
	var btn: Button = scr.get("_buy_btns")[0]
	btn.pressed.emit()
	_check(game.embers() == e0 and int(scr.call("detail_shown")) == 0, "%s: one tap in the sheet only asks" % tag)
	btn.pressed.emit()
	await process_frame
	_check(game.embers() == e0 - price and game.wares()[0] == null and int(scr.call("detail_shown")) == -1, "%s: the second buys it (%d) and the sheet shuts" % [tag, price])
	scr.call("tap_at", (cards[0] as Rect2).get_center())
	_check(int(scr.call("detail_shown")) == -1 and (scr.get("LINES")["sold"] as Array).has(str(scr.get("_line"))), "%s: a tap on the sold card says so" % tag)


func _test_chandler_names() -> void:
	## Every ware name reads whole on its compact card: one line, else two
	## broken at a space, at 10 px or more, inside its room, on both safe
	## rects, for every calling at depths 13-40 over many stocks (spec §8.2's
	## grid). The Reserve's name takes two lines at most.
	var sc = load("res://scripts/chandler_screen.gd")
	var bad := []
	var names := 0
	var two := 0
	for promax in [false, true]:
		for cls in Classes.ids():
			_wipe()
			game.reset()
			game.new_hero(cls)
			game.mark_seen("meet_waxley")
			var scr: Control = sc.new()
			root.add_child(scr)
			await process_frame
			if promax:
				scr.set("safe_override", Rect2(55, 10, scr.get_size().x - 110, scr.get_size().y - 28))
			for depth in [13, 15, 18, 20, 23, 25, 28, 31, 35, 39]:
				for k in 4:
					_set_depth(depth + 1, depth)
					game.data["run_counter"] = k
					scr.call("_refresh")
					var cards: Array = scr.call("_cards")
					var stock: Array = scr.get("_stock")
					for i in stock.size():
						var nm := str(stock[i]["name"])
						var nw: float = scr.call("compact_name_w", cards[i])
						var cn: Dictionary = sc.compact_name(nm, nw)
						var lines: Array = cn["lines"]
						names += 1
						if lines.size() == 2:
							two += 1
						var ok: bool = lines.size() <= 2 and int(cn["size"]) >= 10 and " ".join(PackedStringArray(lines.map(func(l): return str(l)))) == nm
						for l in lines:
							ok = ok and scr.UI.text_width(str(l), int(cn["size"]), "title", 700) <= nw + 0.5
						if not ok:
							bad.append("%s (%d px: %s)" % [nm, int(nw), lines])
					var rr: Rect2 = scr.call("reserve_rect")
					var ri = game.reserve().get("item")
					if rr.has_area() and ri is Dictionary:
						var rl: Array = scr.UI.wrap(str(ri["name"]), rr.size.x - 20.0, 13, "title", 700)
						if rl.size() > 2:
							bad.append("Reserve: " + str(ri["name"]))
			scr.queue_free()
			await process_frame
	_check(bad.is_empty() and names > 1500, "every ware name reads whole on its card, never cut mid-word (%d names, %d on two lines; %s)" % [names, two, bad.slice(0, 6)])
	_fresh()


func _buttons(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


# ---------------------------------------------------------------- movement

func _test_no_movement() -> void:
	## Stats never reach the hero's movement: none of these files name a
	## movement constant or the player's velocity.
	var words := ["RUN_SPEED", "JUMP_SPEED", "DOUBLE_JUMP", "GRAVITY", "APEX", "MAX_FALL", "COYOTE", "BUFFER",
			"ACCEL", "DECEL", "move_mult", "velocity"]
	for path in ["res://scripts/hero.gd", "res://scripts/items.gd", "res://scripts/progression.gd", "res://scripts/relics.gd"]:
		var text := FileAccess.get_file_as_string(path)
		var hits := []
		for w in words:
			if text.find(w) >= 0:
				hits.append(w)
		_check(text != "" and hits.is_empty(), "%s never touches movement %s" % [path.get_file(), hits])
	for path in ["res://scripts/combat.gd", "res://scripts/classes.gd"]:
		var text := FileAccess.get_file_as_string(path)
		var hits := []
		for w in words:
			if text.find(w) >= 0:
				hits.append(w)
		_check(text != "" and hits.is_empty(), "%s never touches movement %s" % [path.get_file(), hits])
	# v3's powers (spec §2.3, §8.3, §8.4): no node, Legendary or relic names
	# a movement stat, and the dash stays 144 px at every root rank.
	var keys := []
	for id in Items.LEGENDS:
		keys.append_array((Items.LEGENDS[id].get("fx", {}) as Dictionary).keys())
		keys.append_array((Items.LEGENDS[id].get("stats", {}) as Dictionary).keys())
	for id in Hero.RELIC_MODS:
		keys.append_array((Hero.RELIC_MODS[id] as Dictionary).keys())
	for id in Hero.RELIC_FLAGS:
		keys.append_array((Hero.RELIC_FLAGS[id] as Dictionary).keys())
	var moving := keys.filter(func(k): return ["speed", "jump", "gravity", "fall", "accel", "dash", "move", "run_"].any(func(w): return str(k).to_lower().contains(w) and not ["attack_speed_pct", "gutterlight_speed"].has(str(k))))   # (both attack speed)
	_check(moving.is_empty(), "no Legendary or relic power names a movement stat (%s)" % [moving])
	Classes.set_deep(true)
	var node_stats := []
	for cls in Classes.ids():
		for n in Classes.tree(cls):
			if str(n["stat"]) != "":
				node_stats.append(n["stat"])
	var step: Array = Classes.find_node("runner", "r_step")["per"]
	Classes.set_deep(false)
	_check(not node_stats.any(func(st): return ["speed", "jump", "move", "dash"].any(func(w): return str(st).contains(w))), "no tree node feeds a movement stat")
	_check(int(step.max()) == 144 and int(step[step.size() - 1]) == 144, "the Smoke Step's table tops out at 144 px (%s)" % [step])
