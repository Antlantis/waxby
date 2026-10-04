extends SceneTree
## World 3, the Bone Orchard (WL3): the orchard's feature numbers
## (features/orchard.gd, spec §3.2), the four levels' layout rules (spec
## §3.1, §3.4), the star routes of 3-1 ... 3-3, and 3-4's approach replayed.
## Since Build 2 the regular levels are held to what their own headers
## declare (tests/level_rules.gd: their roster:, their threat: and its ramp,
## 3-5 altars at most 90 tiles apart), not to fixed counts and widths; 3-4
## keeps its pins. World 3 reads strip, tower, bowl (_test_shapes): 3-1 a
## strip, 3-2 a tower 36 rows tall, 3-3 a bowl 24 rows deep, each with its
## twist and set pieces in play.
##
##     godot --headless --path game --script res://tests/test_w3.gd
##
## The numbers are read from the module's DIFF_KNOBS and constants (the
## owner signed them off in the feel lab: decisions.md), and each is checked
## against the World's behaviour, not copied. The reachability bot and the
## dwell rule for these levels run in tests/test_core.gd (WAXBY_WORLD=3); the
## star routes, the secret attic and the stone rule along the bot's own path
## here use the same engine (scripts/reach.gd). Until reach.gd climbs a vine
## (its climb actions press jump with a way held, which the player reads as a
## leap: a W0 request), the bot checks that need a climb report "skipped"
## instead of failing.

const LevelData := preload("res://scripts/level_data.gd")
const Rules := preload("res://tests/level_rules.gd")
const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
const Route := preload("res://scripts/route.gd")
const Orchard := preload("res://scripts/features/orchard.gd")
const TILE := 32
const DT := 1.0 / 120.0
const LEVEL_IDS := ["3-1", "3-2", "3-3", "3-4"]
const MAX_GAP := 90                  # checkpoints (spec §3.1, World 3)
const STONE_EVERY := 14
const KNOT_EVERY := 4                # vines between root knots over a pit
const HANG_ROWS := 7                 # a ceiling pod over its floor
const THREAT_TARGET := 10.0          # per 100 tiles, 3-4's approach (the others declare theirs: threat:)
const THREAT_SLACK := 0.15
# The threat cost table (spec §4.2; v2's kinds p_monsters §4.1).
const COST := {"skeleton": 1.0, "bat": 1.0, "bonebow": 1.5, "dripkin": 1.0, "gutterwing": 1.0, "brinejaw": 1.0,
	"thornback": 2.5, "hollow_helm": 3.0, "lidlurk": 3.0, "rootling": 1.0, "weepcap": 2.0, "rattlehound": 3.0,
	"creepbone": 1.5, "nest": 1.0}
# Where each World 3 thing is taught (spec §3.4.2; Build 2's 3-1 teaches
# the world's three new monsters one at a time, the Creepbone moved there
# from 3-3): nothing of its kind appears earlier on the main path.
const TAUGHT := {"rootling": ["3-1", "BG_MOUNDS", 104], "weepcap": ["3-1", "BG_WEEP", 175],
	"rattlehound": ["3-2", "HO_HOUND", 78], "creepbone": ["3-1", "BG_LADDER", 134],
	"rotten": ["3-2", "HO_ROTTEN_K", 245], "pod": ["3-2", "HO_SPORES", 118], "vine": ["3-1", "BG_START", 0]}
# 3-4's monsters on the approach (spec §3.4.3; the regular levels declare
# their cast: roster:, a nest counted as its Gutterwing).
const MONSTERS := {"3-4": 11}
# Each regular level's star sigil (sigil 3: by 3-1's bell, at the top of
# 3-2's Rotten Spur over the wall's first catch floor, at the end of 3-3's
# knots over the Clearing's thorny roof), the landings its route takes
# (tight: a lone one-tile stone, a crumble, a rotten run of 3 or fewer, a
# one-tile root knot), and where the bot starts.
const STAR_ROUTES := {
	"3-1": {"sigil": 3, "route": [Vector2i(313, 7), Vector2i(316, 5)], "from": Vector2i(304, 12),
			"what": "a short vine, then two lone stones"},
	"3-2": {"sigil": 3, "route": [Vector2i(268, 18), Vector2i(264, 17)], "from": Vector2i(262, 21),
			"what": "two rotten runs up the far wall from the catch floor"},
	"3-3": {"sigil": 3, "route": [Vector2i(83, 11), Vector2i(87, 11), Vector2i(91, 11), Vector2i(95, 11), Vector2i(99, 11),
			Vector2i(103, 11), Vector2i(107, 11), Vector2i(111, 11), Vector2i(115, 11)], "from": Vector2i(76, 12),
			"what": "root knots from the lip of Tatterjaw's run over the Clearing's thorny roof"},
}
# 3-4's approach (no bell rings there with no monsters, so test_routes can't
# replay it): recorded by the autoplay bot, replayed here to the arena door.
const APPROACH := "res://tests/routes/3-4_approach.json"
# 3-3's secret attic: where its silver bell hangs (SW_UPDRAFT, x 256 + 8, row
# 2: the bowl's far rim, back at the wood's height), written only once
# 3-S.txt is in the build (w3.py SECRET_3S).
const ATTIC := Vector2i(264, 2)
const SECRET := "res://levels/3-S.txt"
# 3-3's keeper nook (SW_BRAMBLE2, x 140, placed 6 rows down in the bowl): the
# Candleknight's Ledge Grab only. He jumps from the branch ledge (row 16) in
# the slot column, bonks the root lip (row 11) and grabs the hollow's floor
# (row 13, columns 142-143). The bot comes at it from the trunk's far side.
const NOOK_X0 := 140
const NOOK_LEDGE := Vector2i(141, 16)
const NOOK_LIP := 11
const NOOK_FLOOR := 13
const NOOK_FROM := Vector2i(138, 21)
# SW_CANOPY's last vine (x 184 + 25, its top row 2 + 3) by sigil 1's ledge.
const CANOPY_VINE := Vector2i(209, 5)

var WorldScript: GDScript
var game: Node
var _passed := 0
var _failed := 0
var _skipped := []


func _check(ok: bool, what: String) -> void:
	if OS.get_environment("W3_VERBOSE") == "1":
		print("  ok " if ok else "  NO ", what)
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _skip(what: String) -> void:
	_skipped.append(what)
	print("  skipped: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_w3_save.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	_test_knobs()
	await _test_vines()
	await _test_rotten()
	await _test_spores()
	await _test_fire()
	await _test_pods()
	await _test_outrun()
	await _test_glowfruit()
	await _test_arena_fruit()
	await _test_barks()
	var levels := {}
	for id in LEVEL_IDS:
		var path := "res://levels/%s.txt" % id
		if FileAccess.file_exists(path):
			levels[id] = LevelData.load_file(path)
		else:
			_skip("%s missing" % path.get_file())
	if levels.size() == LEVEL_IDS.size():
		_test_headers(levels)
		_test_layout(levels)
		_test_threat(levels)
		_test_teaching(levels)
		_test_screens(levels)
		_test_arena(levels["3-4"])
		_test_secret_exit(levels["3-3"])
		_test_star_routes(levels)
		_test_bot_stone(levels)
		_test_first_vine(levels["3-1"])
		_test_nook(levels["3-3"])
		await _test_lanterns(levels)
		await _test_smoke(levels)
		await _test_approach()
		await _test_leap_bands(levels)
		await _test_canopy_mount(levels["3-3"])
		await _test_shapes(levels)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	if not _skipped.is_empty():
		print("  (%d skipped)" % _skipped.size())
	print("test_w3: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _level(lines: Array, header := "", w := 40) -> RefCounted:
	## A level from rows (padded with air to w), 15 rows, stone from row 13
	## where no row is given.
	var rows := []
	for y in 15:
		var r: String = lines[y] if y < lines.size() else ("#".repeat(w) if y >= 13 else "")
		rows.append(r.rpad(w, "."))
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n" + header + "---\n" + "\n".join(rows))
	lv.id = "t3"
	return lv


func _world(lv: RefCounted, diff := "dusk") -> Node2D:
	game.reset()
	game.data["difficulty"] = diff
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = true
	w.paused = true            # the test drives every tick itself
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	return w


func _tick(w: Node2D, seconds: float, pad := {}) -> void:
	for i in int(round(seconds / DT)):
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _put(w: Node2D, feet: Vector2) -> void:
	var p: Node2D = w.player
	p.reset_at(feet)
	p.velocity = Vector2.ZERO
	p.on_floor = true


func _orchard(w: Node2D):
	return w.features.module("orchard")


# ---------------------------------------------------------------- the numbers

func _test_knobs() -> void:
	## The signed-off numbers (decisions.md, feel lab round 2; spec §3.2's
	## knob table), read from the module.
	var k: Dictionary = (Orchard as Script).get_script_constant_map()["DIFF_KNOBS"]
	_check(k["rotten_hold"] == {"dusk": 1.4, "nightfall": 1.2, "witching": 1.0}, "a rotten vine holds 1.4 / 1.2 / 1.0 s")
	_check(k["pod_tell"] == {"dusk": 0.40, "nightfall": 0.34, "witching": 0.30}, "a pod swells 0.40 / 0.34 / 0.30 s")
	_check(k["spore_dim"] == {"dusk": 0.55, "nightfall": 0.50, "witching": 0.45}, "spores dim x0.55 / 0.50 / 0.45")
	for d in ["dusk", "nightfall", "witching"]:
		_check(float(k["pod_tell"][d]) >= 0.30, "the pod's tell is 0.30 s or more on %s (spec §3.1: tells after the multiplier)" % d)
	_check(Orchard.FRAY == 0.5 and Orchard.GONE == 5.0 and Orchard.REGROW == 0.6, "a rotten run frays from 0.5 s, is gone 5 s, regrows over 0.6 s")
	_check(Orchard.POD_REACH == 48.0 and Orchard.POD_CLOUD_R == 64.0 and Orchard.POD_CLOUD_LIFE == 4.0 and Orchard.POD_REGROW == 8.0
			and Orchard.POD_AWAY == 200.0, "a pod: 48 px, a 64 px cloud for 4 s, regrowing 8 s later once 200 px off")
	_check(Orchard.SPORE_AFTER == 2.0 and Orchard.BURN_TIME == 0.3 and Orchard.BURN_FLASH_R == 120.0, "the dim lingers 2 s; fire burns a cloud in 0.3 s (flash r 120)")
	_check(Orchard.FRUIT_HANG_R == 90.0 and Orchard.FRUIT_LIT_R == 120.0 and Orchard.FRUIT_LIFE == 30.0 and Orchard.FRUIT_GUTTER == 3.0
			and Orchard.FRUIT_EMBER_R == 40.0 and Orchard.FRUIT_G == 1400.0 and Orchard.FRUIT_BOUNCE == 0.3 and Orchard.ARENA_REGROW == 12.0,
			"glowfruit: r 90 hanging, r 120 for 30 s lying (3 s gutter, r 40 after), g 1400, one bounce x0.3, 12 s in an arena")
	_check(is_equal_approx(Orchard.CLOUD_SHADER_K, 0.58), "a cloud's shader radius is its rule radius / 0.58")
	# The module draws nothing the grep forbids (test_render checks features/*
	# too; this names the file).
	var src := FileAccess.get_file_as_string("res://scripts/features/orchard.gd")
	_check(not src.contains("draw_circle(") and not src.contains("draw_colored_polygon(") and not src.contains("draw_polyline("),
			"orchard.gd draws in rects and a TriBatch only")


# A vine column at x 10 (rows 3-12), a rotten run at x 20 (rows 5-7) with a
# pod on the floor at x 30 and a glowfruit over a floor at x 34.
func _feature_level() -> RefCounted:
	var lines := []
	for y in 13:
		var r := ".".repeat(40)
		lines.append(r)
	for y in range(3, 13):
		lines[y] = lines[y].substr(0, 10) + "{" + lines[y].substr(11)
	for y in range(5, 8):
		lines[y] = lines[y].substr(0, 20) + "}" + lines[y].substr(21)
	lines[2] = "#".repeat(40)
	lines[3] = lines[3].substr(0, 34) + "8" + lines[3].substr(35)
	lines[12] = "..P" + lines[12].substr(3, 27) + "*" + lines[12].substr(31)
	lines.append("#".repeat(40))
	lines.append("#".repeat(40))
	return _level(lines)


func _test_vines() -> void:
	var w := await _world(_feature_level())
	var o = _orchard(w)
	_check(o != null and o.get_script() == Orchard, "the World builds the orchard module")
	_check(o.vine_at(Vector2i(10, 6)) and w.vine_present(10, 6) and not o.vine_at(Vector2i(11, 6)), "vine_at / vine_present answer for a vine cell")
	_check(o.vine_lane(Vector2i(10, 8)) == {"x": 10, "y0": 3, "y1": 12}, "vine_lane gives the whole run (%s)" % [o.vine_lane(Vector2i(10, 8))])
	_check(o.vine_lane(Vector2i(20, 6)) == {"x": 20, "y0": 5, "y1": 7} and o.vine_lane(Vector2i(12, 6)).is_empty(), "a rotten run is its own lane; air has none")
	_check(w.features.vine_lane(Vector2i(10, 4)) == o.vine_lane(Vector2i(10, 4)), "the dispatcher forwards vine_lane")
	await _done(w)


func _test_rotten() -> void:
	for d in ["dusk", "nightfall", "witching"]:
		var w := await _world(_feature_level(), d)
		var o = _orchard(w)
		var pl: Node2D = w.player
		var hold: float = o.knob("rotten_hold")
		pl.reset_at(Vector2(20.5 * TILE, 6 * TILE + 19.0 + 16.0))
		pl.on_floor = false
		pl.grab_vine(20, 0.0)
		var held := 0.0
		var frayed_at := -1.0
		var snapped_at := -1.0
		var t := 0.0
		var r: Dictionary = o.runs[0]
		while t < 2.0:
			w.test_pad = {}
			w._read_pad()
			w.tick(DT)
			t += DT
			if pl.climbing:
				held += DT
			if frayed_at < 0.0 and o.fray(r) > 0.0:
				frayed_at = t
			if snapped_at < 0.0 and not w.vine_present(20, 6):
				snapped_at = t
		_check(absf(snapped_at - hold) <= 2.0 * DT and absf(held - hold) <= 2.0 * DT,
				"%s: a rotten vine snaps %.1f s after the catch (snapped %.3f, held %.3f)" % [d, hold, snapped_at, held])
		_check(absf(frayed_at - Orchard.FRAY) <= 2.0 * DT, "%s: it frays from %.1f s (%.3f)" % [d, Orchard.FRAY, frayed_at])
		_check(o.vine_lane(Vector2i(20, 6)).is_empty() and not o.vine_at(Vector2i(20, 5)), "%s: a snapped run reads absent (its lane too)" % d)
		_tick(w, Orchard.GONE - (2.0 - hold) + 0.1)
		_check(not w.vine_present(20, 6) and r["state"] == "regrow", "%s: after %.0f s it shows its regrow tell, not yet climbable" % [d, Orchard.GONE])
		_tick(w, Orchard.REGROW)
		_check(w.vine_present(20, 6) and r["state"] == "idle", "%s: and after %.1f s more it is back" % [d, Orchard.REGROW])
		if d == "dusk":
			# A snuff grows every run back.
			pl.reset_at(Vector2(20.5 * TILE, 6 * TILE + 35.0))
			pl.on_floor = false
			pl.grab_vine(20, 0.0)
			_tick(w, hold + 0.1)
			_check(r["state"] == "snapped", "a caught run snaps again")
			# ...and a fallen glowfruit (not a boss arena's) hangs again.
			var fr: Dictionary = o.fruit[0]
			o.drop_fruit(fr)
			_tick(w, 1.5)
			_check(fr["state"] == "lit" and not fr["arena"], "(a glowfruit knocked down lies lit)")
			o.on_respawn()
			_check(r["state"] == "idle" and w.vine_present(20, 6), "a snuff (respawn) grows it back")
			_check(fr["state"] == "hang" and fr["pos"] == fr["home"], "and hangs every fallen glowfruit again (a retry of a dark grove has its light)")
			# The playlog hears it (world.note_feature).
			pl.reset_at(Vector2(20.5 * TILE, 6 * TILE + 35.0))
			pl.on_floor = false
			pl.grab_vine(20, 0.0)
			_tick(w, hold + 0.05)
			var fn = w.get("_feature_note")
			_check(fn is Dictionary and str(fn.get("name", "")) == "vine_snap", "a snap is noted for the playlog (%s)" % [fn])
		await _done(w)


func _test_spores() -> void:
	var w := await _world(_feature_level())
	var o = _orchard(w)
	var pl: Node2D = w.player
	_put(w, Vector2(5.5 * TILE, 13 * TILE))
	_tick(w, 0.3)
	var base: float = w.hero_light_radius()
	o.add_spores(pl.center(), 64.0, 4.0, null)
	_check(o.spores_at(pl.center()) and not o.spores_at(pl.center() + Vector2(70, 0)), "spores_at: inside the rule radius only")
	_tick(w, 0.2)
	var keys: Array = w.dims().keys().filter(func(k): return str(k).begins_with("spore"))
	_check(keys.size() == 1, "a cloud dims him through the World's pipeline, keyed 'spore...' for Sporeward (%s)" % [w.dims().keys()])
	var mult: float = float(w.dims()[keys[0]]["mult"]) if keys.size() == 1 else 0.0
	_check(is_equal_approx(mult, o.knob("spore_dim")), "the dim is x%.2f (%.2f)" % [o.knob("spore_dim"), mult])
	var r: float = w.hero_light_radius()
	_check(absf(r / base - o.knob("spore_dim")) < 0.02, "his light is x%.2f in a cloud (%.0f of %.0f px)" % [o.knob("spore_dim"), r, base])
	_check(w.dim_mult() >= 0.5 - 0.001, "and the Dusk floor holds (x%.2f)" % w.dim_mult())
	# Out of the cloud, the dim lingers 2 s.
	o.clouds.clear()
	_tick(w, Orchard.SPORE_AFTER - 0.15)
	_check(not w.dims().is_empty(), "out of the cloud, the dim lingers (1.85 s on)")
	_tick(w, 0.4)
	var left: Array = w.dims().keys().filter(func(k): return str(k).begins_with("spore"))
	_check(left.is_empty(), "and is gone after %.0f s" % Orchard.SPORE_AFTER)
	# A cloud drifts up and lasts its life.
	o.add_spores(Vector2(30 * TILE, 10 * TILE), 64.0, 4.0, null)
	var c: Dictionary = o.clouds[o.clouds.size() - 1]
	var y0: float = (c["p"] as Vector2).y
	_tick(w, 1.0)
	_check(absf(y0 - (c["p"] as Vector2).y - Orchard.CLOUD_RISE) < 0.5, "a cloud drifts up %.0f px/s" % Orchard.CLOUD_RISE)
	_tick(w, 3.1)
	_check(o.clouds.is_empty(), "and is gone after its life")
	# Its light: a Hush light of the rule radius / 0.58, carrying the rule radius.
	o.add_spores(pl.center() + Vector2(300, 0), 64.0, 4.0, null)
	_tick(w, 0.5)
	var hush: Array = o.lights().filter(func(l): return float(l["s"]) < 0.0)
	_check(hush.size() == 1 and absf(float(hush[0]["r"]) - 64.0 / 0.58) < 0.1 and float(hush[0]["rule_r"]) == 64.0,
			"a cloud is a Hush light of r 64 / 0.58 (%s)" % [hush])
	await _done(w)


func _test_fire() -> void:
	## Fire burns a cloud in 0.3 s: a Flare, a spark, a fire patch, a lit lantern.
	var w := await _world(_feature_level())
	var o = _orchard(w)
	var at := Vector2(20 * TILE, 11 * TILE)
	# A Flare shot inside it.
	o.add_spores(at, 64.0, 4.0, null)
	w.spawn_shot({"kind": "flare", "pos": at + Vector2(20, 0), "vel": Vector2.ZERO, "life": 1.0, "owner": "player"})
	_tick(w, DT)
	_check(not o.spores_at(at), "a Flare in a cloud burns it at once")
	_tick(w, Orchard.BURN_TIME)
	_check(o.clouds.is_empty(), "and it is gone within %.1f s" % Orchard.BURN_TIME)
	w.shots.clear()
	# An arrow is no fire.
	o.add_spores(at, 64.0, 4.0, null)
	w.spawn_shot({"kind": "arrow", "pos": at, "vel": Vector2.ZERO, "life": 1.0, "owner": "enemy"})
	_tick(w, 0.1)
	_check(o.spores_at(at), "an arrow doesn't burn it")
	w.shots.clear()
	# A fire patch (a Special's burning floor, the Burning Omen) touching it.
	w.add_hazard({"kind": "fire", "motion": "still", "owner": "enemy", "rect": Rect2(at + Vector2(50, -8), Vector2(16, 16)), "life": 1.0})
	_tick(w, DT * 2)
	_check(not o.spores_at(at), "a fire patch at its edge burns it")
	w.hazards.clear()
	_tick(w, 0.5)
	# burn_spores (the Weepcap's call).
	o.add_spores(at, 64.0, 4.0, null)
	o.burn_spores(at + Vector2(90, 0), 30.0)
	_check(not o.spores_at(at), "burn_spores reaches a cloud its circle touches")
	var flash: Array = o.lights().filter(func(l): return float(l["r"]) == Orchard.BURN_FLASH_R)
	_check(flash.size() == 1, "a burn flashes a light of r %.0f" % Orchard.BURN_FLASH_R)
	await _done(w)
	# A lit lantern (a W3 skull lantern) burns a cloud that reaches its flame.
	var lines := []
	for y in 13:
		lines.append("")
	lines[12] = "..P.......L"
	var w2 := await _world(_level(lines))
	var o2 = _orchard(w2)
	var lan: Dictionary = w2.features.lanterns[0]
	o2.add_spores(lan["flame"] + Vector2(70, 0), 64.0, 4.0, null)
	_tick(w2, 0.1)
	_check(o2.spores_at(lan["flame"] + Vector2(70, 0)), "an unlit lantern doesn't burn it")
	w2.features.light(lan)
	_tick(w2, 0.1)
	_check(not o2.spores_at(lan["flame"] + Vector2(70, 0)), "a lit one does")
	await _done(w2)


func _test_pods() -> void:
	var w := await _world(_feature_level())
	var o = _orchard(w)
	var pl: Node2D = w.player
	var pod: Dictionary = o.pods[0]
	_check(pod["mount"] == "floor", "a floor pod stands on the floor")
	var pp: Vector2 = pod["pos"]
	_put(w, Vector2(pp.x - 70.0, 13 * TILE))
	_tick(w, 0.2)
	_check(pod["state"] == "closed", "a pod 70 px off stays shut")
	var lit: Array = o.lights().filter(func(l): return (l["p"] as Vector2) == pp)
	_check(lit.size() == 1 and float(lit[0]["r"]) == Orchard.POD_GLOW_R and float(lit[0]["s"]) == Orchard.POD_GLOW_S, "a shut pod glows dimly (r 24, s 0.3)")
	_put(w, Vector2(pp.x - 40.0, 13 * TILE))
	_tick(w, DT)
	_check(pod["state"] == "swell", "within 48 px of his centre it swells")
	var tell: float = o.knob("pod_tell")
	var swelled := 0.0
	while pod["state"] == "swell" and swelled < 2.0:
		_tick(w, DT)
		swelled += DT
	_check(absf(swelled - tell) <= 2.0 * DT, "it bursts %.2f s later (%.3f)" % [tell, swelled])
	_check(o.clouds.size() == 1 and float(o.clouds[0]["r"]) == Orchard.POD_CLOUD_R and float(o.clouds[0]["life"]) == Orchard.POD_CLOUD_LIFE,
			"into a cloud of r %.0f for %.0f s" % [Orchard.POD_CLOUD_R, Orchard.POD_CLOUD_LIFE])
	# It regrows only once he's far off.
	_tick(w, Orchard.POD_REGROW + 0.5)
	_check(pod["state"] == "burst", "it doesn't regrow with him beside it")
	_put(w, Vector2(pp.x - 260.0, 13 * TILE))
	_tick(w, 0.1)
	_check(pod["state"] == "closed", "it regrows %.0f s on, once he is %.0f px off" % [Orchard.POD_REGROW, Orchard.POD_AWAY])
	# A slash sets it off from beside it (a strike rect), a shot from afar.
	o.strike(Rect2(pp - Vector2(20, 10), Vector2(16, 20)), 1)
	_check(pod["state"] == "swell", "a slash that reaches it sets it off")
	_tick(w, 5.0 + Orchard.POD_REGROW)
	_check(pod["state"] == "closed", "(it regrows)")
	o.shot_hit({"pos": pp + Vector2(10, 0), "radius": 6.0, "owner": "player"})
	_check(pod["state"] == "swell", "a shot that reaches it sets it off")
	# No damage, and monsters don't care: his life is untouched in a cloud.
	var hp: float = pl.hp
	_put(w, pp - Vector2(0, 0))
	_tick(w, 1.0)
	_check(pl.hp == hp and pl.alive, "a cloud does no damage")
	await _done(w)


func _test_outrun() -> void:
	## Spec §3.2: "A running Wick outruns a burst (the lesson is: keep
	## moving)". Flat out past a floor pod he is never inside its cloud, on
	## every difficulty (it billows out over POD_GROW s, its edge slower than
	## a run); one who stops beside it is caught; a pod on a vine catches a
	## climber ("the cloud rises with you").
	var lines := []
	for y in 13:
		lines.append("")
	lines[12] = "..P.................*"
	for y in range(3, 13):
		lines[y] = lines[y].rpad(30, ".").substr(0, 30) + "{"
	lines[6] = lines[6].substr(0, 30) + "*"
	var lv := _level(lines, "", 44)
	for d in ["dusk", "nightfall", "witching"]:
		var w := await _world(lv, d)
		var o = _orchard(w)
		var pl: Node2D = w.player
		var floor_pod: Dictionary = o.pods.filter(func(p): return p["mount"] == "floor")[0]
		var inside := 0.0
		var dimmed := 0.0
		var t := 0.0
		while t < 6.0:
			_tick(w, DT, {"right": true})
			t += DT
			if o.spores_at(pl.center()):
				inside += DT
			if not w.dims().keys().filter(func(k): return str(k).begins_with("spore")).is_empty():
				dimmed += DT
			if pl.position.x > 28.0 * TILE:
				break
		_check(floor_pod["state"] == "burst" and inside == 0.0 and dimmed == 0.0,
				"%s: running flat out past a pod, he outruns its burst (it %s; %.2f s inside, %.2f s dimmed)" % [d, floor_pod["state"], inside, dimmed])
		# Stopping beside it, the cloud has him.
		o.on_respawn()
		_put(w, (floor_pod["pos"] as Vector2) + Vector2(-30.0, 11.0))
		_tick(w, o.knob("pod_tell") + Orchard.POD_GROW + 0.1)
		_check(o.spores_at(pl.center()), "%s: one who stops beside it is caught" % d)
		# Climbing past a pod on a vine, the cloud rises with him.
		o.on_respawn()
		_tick(w, 2.5)
		var vine_pod: Dictionary = o.pods.filter(func(p): return p["mount"] == "vine")[0]
		pl.reset_at(Vector2(30.5 * TILE, 11 * TILE + 19.0 + 16.0))
		pl.on_floor = false
		pl.grab_vine(30, 1.0)
		var caught := false
		t = 0.0
		while t < 2.0 and not caught:
			_tick(w, DT, {"up": true})
			t += DT
			caught = o.spores_at(pl.center())
		_check(vine_pod["state"] == "burst" and caught, "%s: climbing past a pod on a vine, its cloud catches him" % d)
		await _done(w)


func _test_glowfruit() -> void:
	var w := await _world(_feature_level())
	var o = _orchard(w)
	var f: Dictionary = o.fruit[0]
	var home: Vector2 = f["home"]
	_check(f["state"] == "hang", "a glowfruit hangs")
	var lt: Array = o.lights().filter(func(l): return (l["p"] as Vector2) == home)
	_check(lt.size() == 1 and float(lt[0]["r"]) == Orchard.FRUIT_HANG_R and lt[0]["gameplay"], "lit r %.0f hanging, as lamplight" % Orchard.FRUIT_HANG_R)
	_check(w.lit_at(home + Vector2(0, 80), 0.0, {"exclude_hero": true}), "lit_at counts it (lamplight)")
	# A touch knocks it down: it falls, bounces once, lies lit.
	var pl: Node2D = w.player
	pl.reset_at(home + Vector2(0, 30))
	pl.on_floor = false
	_tick(w, DT)
	_check(f["state"] == "fall", "a touch knocks it down")
	var bounced_up := false
	var t := 0.0
	while f["state"] == "fall" and t < 3.0:
		_tick(w, DT)
		t += DT
		if (f["vel"] as Vector2).y < 0.0:
			bounced_up = true
	_check(bounced_up and f["state"] == "lit", "it bounces once, then lies (%.2f s)" % t)
	_check(absf((f["pos"] as Vector2).y + Orchard.FRUIT_HALF.y - 13 * TILE) < 1.0, "on the floor")
	var fell := 13 * TILE - Orchard.FRUIT_HALF.y - home.y
	var t_fall := sqrt(2.0 * fell / Orchard.FRUIT_G)
	_check(t > t_fall and t < t_fall + 0.5, "falling at g %.0f (%.2f s for %.0f px, then the bounce)" % [Orchard.FRUIT_G, t, fell])
	var lp: Vector2 = f["pos"]
	var lying: Array = o.lights().filter(func(l): return (l["p"] as Vector2) == lp and l.get("gameplay", false))
	_check(lying.size() == 1 and float(lying[0]["rule_r"]) == Orchard.FRUIT_LIT_R, "it lies lit at r %.0f" % Orchard.FRUIT_LIT_R)
	pl.reset_at(Vector2(2.5 * TILE, 13 * TILE))
	_tick(w, Orchard.FRUIT_LIFE - 0.6)
	_check(f["state"] == "lit" and w.lit_at(lp + Vector2(100, 0), 0.0, {"exclude_hero": true}), "it is still lit %.0f s later" % (Orchard.FRUIT_LIFE - 0.5))
	_tick(w, 0.8)
	_check(f["state"] == "ember" and not w.lit_at(lp + Vector2(100, 0), 0.0, {"exclude_hero": true}), "and after %.0f s it keeps only a faint glow" % Orchard.FRUIT_LIFE)
	var em: Array = o.lights().filter(func(l): return (l["p"] as Vector2) == lp)
	_check(em.size() == 1 and float(em[0]["r"]) == Orchard.FRUIT_EMBER_R and not em[0].get("gameplay", false), "r %.0f, for good" % Orchard.FRUIT_EMBER_R)
	await _done(w)
	# Dropped on a pod: the pod bursts and its cloud burns at once.
	var lines := []
	for y in 13:
		lines.append("")
	lines[5] = "#".repeat(40)
	lines[6] = "..........8"
	lines[12] = "..P.......*"
	var w2 := await _world(_level(lines))
	var o2 = _orchard(w2)
	o2.drop_fruit(o2.fruit[0])
	var burnt := false
	for i in 90:
		_tick(w2, DT)
		if not o2.flashes.is_empty():
			burnt = true
	_check(o2.pods[0]["state"] == "burst" and burnt and o2.live_clouds() == 0, "a glowfruit dropped on a pod bursts it and burns the cloud at once")
	# A falling fruit burns a cloud it falls through.
	o2.fruit[0]["state"] = "hang"
	o2.fruit[0]["pos"] = o2.fruit[0]["home"]
	o2.add_spores(Vector2(10.5 * TILE, 9 * TILE), 40.0, 4.0, null)
	o2.drop_fruit(o2.fruit[0])
	_tick(w2, 0.4)
	_check(o2.live_clouds() == 0, "and one it falls through")
	await _done(w2)


func _test_arena_fruit() -> void:
	## In a boss arena a fallen glowfruit grows back 12 s later, and at once
	## on a retry (on_boss_reset).
	var lines := []
	for y in 13:
		lines.append("")
	lines[0] = "#".repeat(40)
	lines[1] = "#".repeat(40)
	lines[2] = "##..........8.......................##"
	for y in range(3, 12):
		lines[y] = "##" + ".".repeat(34) + "##"
	lines[12] = "..P...............................X.##"
	var w := await _world(_level(lines, "boss: rootmother\n"))
	var o = _orchard(w)
	var f: Dictionary = o.fruit[0]
	_check(f["arena"], "a glowfruit inside the boss's arena knows it")
	o.drop_fruit(f)
	_tick(w, 3.0)
	_check(f["state"] == "lit", "it falls and lies lit")
	_tick(w, Orchard.ARENA_REGROW - 3.2)
	_check(f["state"] == "lit", "until %.0f s after it fell" % Orchard.ARENA_REGROW)
	_tick(w, 0.4)
	_check(f["state"] == "hang", "then it hangs again")
	o.drop_fruit(f)
	_tick(w, 1.0)
	o.on_boss_reset()
	_check(f["state"] == "hang", "and a retry hangs it again at once")
	await _done(w)


func _test_barks() -> void:
	## first_vine as he stands by his first vine; first_spore at his next
	## stone landing after a cloud dims him. Each once.
	var w := await _world(_feature_level())
	var o = _orchard(w)
	_tick(w, 0.3)
	_check(not o._barked.has("first_vine"), "no vine bark far from a vine")
	_put(w, Vector2(9.5 * TILE, 13 * TILE))
	_tick(w, 0.1)
	_check(o._barked.has("first_vine"), "first_vine by the first vine (on stone)")
	o.add_spores(w.player.center(), 64.0, 1.0, null)
	w.player.on_floor = false
	w.player.velocity = Vector2(0, -300)
	w.player.position.y -= 40.0
	o.step(DT)
	_check(o._pending == "first_spore" and not o._barked.has("first_spore"), "first_spore waits while he's in the air")
	_tick(w, 1.0)
	_check(o._barked.has("first_spore") and o._pending == "", "and fires once he lands on stone")
	await _done(w)


# ---------------------------------------------------------------- the levels

func _test_headers(levels: Dictionary) -> void:
	var names := {"3-1": "The Bramble Gate", "3-2": "The Hanging Ossuary", "3-3": "The Sporewood", "3-4": "The Heartwood"}
	var areas := {"3-1": 13, "3-2": 14, "3-3": 16, "3-4": 17}
	var themes := {"3-1": "orchard", "3-2": "rootvault", "3-3": "sporewood", "3-4": "rootheart"}
	var dreads := {"3-1": "Mister Mandrake|rootling|Twinned,Sporebound", "3-2": "The Widow Cap|weepcap|Warded,Sporebound",
		"3-3": "Old Tatterjaw|rattlehound|Swift,Burning"}
	var widths := {"3-4": 172}     # (the regular levels' widths are their own since Build 2)
	var Story = load("res://scripts/story.gd")
	for id in levels:
		var lv = levels[id]
		_check(lv.errors.is_empty(), "%s parses cleanly %s" % [id, lv.errors])
		_check(lv.title == names[id] and lv.area == areas[id] and lv.theme == themes[id] and lv.world == 3, "%s: its name, area, theme and world" % id)
		_check(lv.width == int(widths.get(id, lv.width)) and Rules.height_ok(lv), "%s is %d wide, %d-%d rows (%d)" % [id, widths.get(id, lv.width), Rules.HEIGHT_MIN, Rules.HEIGHT_MAX, lv.height])
		_check(str(lv.headers.get("music", "")) == "orchard", "%s plays the orchard" % id)
		_check(str(lv.story.get("start", "")) == "beat_3_%s" % id.right(1), "%s opens on beat_3_%s" % [id, id.right(1)])
		if dreads.has(id):
			_check(str(lv.headers.get("dread", "")) == dreads[id] and lv.count("dread") == 1, "%s: its Dread (%s)" % [id, dreads[id]])
		_check(lv.count("sigil") == 3, "%s has three sigils" % id)
		# Its gravestone (story.gd's one inscription since the sign cut) on a sign.
		var ins: Array = Story.INSCRIPTIONS.get(id, [])
		var texts := []
		for e in lv.entities:
			if e["kind"] == "sign":
				texts.append(str(e["text"]))
		_check(ins.size() == 1 and texts.has(ins[0]), "%s carries its inscription (%s)" % [id, ins])
	var b = levels["3-4"]
	_check(b.boss == "rootmother" and str(b.headers.get("boss_music", "")) == "rootmother"
			and str(b.story.get("boss", "")) == "boss_3_before" and str(b.story.get("end", "")) == "boss_3_after",
			"3-4: Mother Gravebough, her music and her scenes")
	# 3-3's silver bell opens 3-S, once 3-S is in the build (w3.py SECRET_3S):
	# before that no bell hangs in the attic to a level that isn't there.
	var sb: int = levels["3-3"].count("silver_bell")
	if FileAccess.file_exists(SECRET):
		_check(str(levels["3-3"].secret) == "3-S" and sb == 1, "3-3's silver bell opens 3-S")
	else:
		_check(str(levels["3-3"].secret) == "" and sb == 0,
				"3-3: with no 3-S.txt in the build, no silver bell and no secret: header (%d, '%s')" % [sb, levels["3-3"].secret])


func _cols_of(lv: RefCounted) -> Dictionary:
	## Per column: pit (no floor in the level's bottom two rows: air or deep
	## water), safe (a SAFE top with room), vine (any climbable cell), foot
	## (anything to land on over the pit: stone, a ledge, a crumble).
	var out := {}
	var b0: int = lv.height - 2
	for x in lv.width:
		var pit: bool = not LevelData.is_solid(lv.tile(x, b0)) and not LevelData.is_solid(lv.tile(x, b0 + 1)) \
				and lv.tile(x, b0) != LevelData.SPIKES_UP
		var safe := false
		for y in range(1, lv.height):
			if LevelData.is_safe(lv.tile(x, y)) and not LevelData.is_solid(lv.tile(x, y - 1)) and not LevelData.is_floor(lv.tile(x, y - 1)):
				safe = true
		var vine := false
		var foot := false
		for y in lv.height:
			if LevelData.is_climb(lv.tile(x, y)):
				vine = true
			if y < b0 and LevelData.is_floor(lv.tile(x, y)) and not LevelData.is_solid(lv.tile(x, y - 1)):
				foot = true
		out[x] = {"pit": pit, "safe": safe, "vine": vine, "foot": foot}
	return out


func _test_layout(levels: Dictionary) -> void:
	for id in levels:
		var lv = levels[id]
		# Checkpoints: start, altars, bell (or the boss) at most 90 apart
		# along the route (x in a strip: Rules.checkpoint_gaps).
		var cg := Rules.checkpoint_gaps(lv)
		_check(int(cg["worst"]) <= MAX_GAP, "%s: checkpoints %d tiles apart at most (%s)" % [id, cg["worst"], cg["marks"]])
		if lv.boss != "":
			_check(lv.count("altar") == 2, "%s has 2 altars" % id)
		else:
			var cp := Rules.checkpoint_problems(lv, MAX_GAP)
			_check(cp.is_empty(), "%s: 3-5 altars, an altar by every sealed door %s" % [id, cp])
		# Over a pit: stone every 14 tiles, a root knot after 4 vines at most.
		var cols := _cols_of(lv)
		var last_safe := -1
		var vines := 0
		var worst_stone := 0
		var worst_vines := 0
		for x in lv.width:
			var c: Dictionary = cols[x]
			if c["safe"] and not c["pit"]:
				last_safe = x
				vines = 0
				continue
			if c["safe"]:
				worst_stone = maxi(worst_stone, x - last_safe)
				last_safe = x
				vines = 0
			if c["pit"]:
				worst_stone = maxi(worst_stone, x + 1 - last_safe)
				if c["vine"]:
					vines += 1
					worst_vines = maxi(worst_vines, vines)
		_check(worst_stone <= STONE_EVERY, "%s: stone every %d tiles or less over a pit (worst %d)" % [id, STONE_EVERY, worst_stone])
		_check(worst_vines <= KNOT_EVERY, "%s: a root knot after %d vines at most over a pit (worst %d)" % [id, KNOT_EVERY, worst_vines])
		# Vine columns over a pit stand 3-5 apart (or a foothold between).
		var bad_gap := []
		var prev := -1
		for x in lv.width:
			if not cols[x]["pit"]:
				prev = -1
				continue
			if cols[x]["vine"] or cols[x]["foot"]:
				if prev >= 0 and x - prev > 5:
					bad_gap.append("%d-%d" % [prev, x])
				prev = x
		_check(bad_gap.is_empty(), "%s: footholds over a pit 5 tiles apart at most %s" % [id, bad_gap])
		# Rotten runs are 3 cells or fewer; a ceiling pod hangs 7 rows or less.
		var long_rot := []
		for x in lv.width:
			var run := 0
			for y in lv.height:
				run = run + 1 if lv.tile(x, y) == LevelData.ROTTEN_VINE else 0
				if run == 4:
					long_rot.append(Vector2i(x, y))
		_check(long_rot.is_empty(), "%s: rotten runs of 3 or fewer %s" % [id, long_rot])
		var high := []
		for e in lv.entities:
			if e["kind"] != "pod":
				continue
			var c: Vector2i = e["cell"]
			if LevelData.is_climb(lv.tile(c.x, c.y)) or LevelData.is_floor(lv.tile(c.x, c.y + 1)):
				continue
			var y := c.y + 1
			while y < lv.height and not LevelData.is_floor(lv.tile(c.x, y)):
				y += 1
			if y - c.y > HANG_ROWS:
				high.append(c)
		_check(high.is_empty(), "%s: every ceiling pod hangs %d rows or less over its floor %s" % [id, HANG_ROWS, high])
		# The cast: a regular level's is what its roster: declares (Build 2),
		# 3-4's the spec's count (§3.4.3).
		if MONSTERS.has(id):
			var n := 0
			for e in lv.entities:
				if COST.has(str(e["kind"])):
					n += 1
			_check(n == int(MONSTERS[id]), "%s holds the spec's %d monsters (%d)" % [id, MONSTERS[id], n])
		else:
			var rp := Rules.roster_problems(lv)
			_check(not Rules.roster_of(lv).is_empty() and rp.is_empty(), "%s holds the cast its roster: declares %s" % [id, rp])
		# A Creepbone never rides a rotten run: its lane is fixed when it
		# spawns, and the run would snap from under it.
		var on_rot := []
		for e in lv.entities:
			if e["kind"] == "creepbone" or (e["kind"] == "dread" and str(lv.dread.get("kind", "")) == "creepbone"):
				var c: Vector2i = e["cell"]
				for dy in [-1, 0, 1]:
					if lv.tile(c.x, c.y + dy) == LevelData.ROTTEN_VINE and not on_rot.has(c):
						on_rot.append(c)
		_check(on_rot.is_empty(), "%s: no Creepbone on a rotten vine %s" % [id, on_rot])
		# No lone one-cell sound vine (a stub where a run was meant).
		var stubs := []
		for x in lv.width:
			for y in lv.height:
				if lv.tile(x, y) == LevelData.VINE and not LevelData.is_climb(lv.tile(x, y - 1)) and not LevelData.is_climb(lv.tile(x, y + 1)):
					stubs.append(Vector2i(x, y))
		_check(stubs.is_empty(), "%s: no one-cell vine stubs %s" % [id, stubs])


func _test_threat(levels: Dictionary) -> void:
	## Each regular level's threat within 10% of what its threat: header
	## declares, 3-1 to 3-3 ramping (tests/level_rules.gd); 3-4's approach
	## within 15% of World 3's 10 (the arena's threat is the boss).
	var regular := []
	for id in levels:
		if levels[id].boss == "":
			regular.append(levels[id])
			_check(Rules.declared_threat(levels[id]) > 0.0, "%s declares its threat" % id)
	# The world's rules across its regular levels (tests/level_rules.gd
	# world_problems): each threat as declared, ramping (flat today, +1 a
	# step once re-cut); once re-cut, roles on every level, no two with the
	# same landmarks or altars, fodder falling, the X-3 mixing, no crowding.
	var tp := Rules.world_problems(regular)
	_check(tp.is_empty(), "3-1 to 3-3: the world's rules (threat, ramp, roles, variety) %s" % [tp])
	for id in levels:
		var lv = levels[id]
		if lv.boss == "":
			continue
		var cost := 0.0
		var bx := 0
		for e in lv.entities:
			cost += float(COST.get(str(e["kind"]), 0.0))
			if e["kind"] == "boss":
				bx = e["cell"].x
		var a = preload("res://scripts/boss_arena.gd").find(lv, LevelData.cell_floor(Vector2i(bx, 12)))
		var per := cost * 100.0 / float(int(a["left"]) / TILE - 2)
		_check(absf(per - THREAT_TARGET) <= THREAT_TARGET * THREAT_SLACK, "%s: threat %.1f per 100 tiles on the approach (%.0f +-15%%)" % [id, per, THREAT_TARGET])


func _test_teaching(levels: Dictionary) -> void:
	## Nothing of a World 3 kind appears before the section that teaches it,
	## along the main path (3-1 ... 3-4).
	var first := {}
	for id in LEVEL_IDS:
		var lv = levels[id]
		var seen := {}
		for e in lv.entities:
			var k := str(e["kind"])
			if k == "dread":
				k = str(lv.dread.get("kind", ""))
			var x: int = e["cell"].x
			if not seen.has(k) or x < int(seen[k]):
				seen[k] = x
		for x in lv.width:
			for y in lv.height:
				var t: int = lv.tile(x, y)
				var k2 := "rotten" if t == LevelData.ROTTEN_VINE else ("vine" if t == LevelData.VINE else "")
				if k2 != "" and (not seen.has(k2) or x < int(seen[k2])):
					seen[k2] = x
		for k in seen:
			if not first.has(k):
				first[k] = [id, int(seen[k])]
	for k in TAUGHT:
		var want: Array = TAUGHT[k]
		_check(first.has(k), "%s appears in World 3" % k)
		if first.has(k):
			var got: Array = first[k]
			_check(got[0] == want[0] and int(got[1]) >= int(want[2]),
					"%s first appears in %s %s (x %d), where it's taught (%s x %d)" % [k, want[0], want[1], want[2], got[0], got[1]])


func _test_screens(levels: Dictionary) -> void:
	## Per 27-tile window (spec §3.1; a taller level's the views over the
	## rows he stands on in it: Rules.screen_rows): pods <= 8, glowfruit <= 6, feature lights <= 14
	## (glowfruit and lanterns, and each pod's dim glow counted too), placed
	## monsters <= 12. The live-cloud cap (5) is counted in play (_test_smoke).
	for id in levels:
		var lv = levels[id]
		var worst := {"pod": 0, "glowfruit": 0, "lights": 0, "monsters": 0}
		for win in _windows(lv):
			var x0: int = win.x
			var n := {"pod": 0, "glowfruit": 0, "lights": 0, "monsters": 0}
			for e in lv.entities:
				var x: int = e["cell"].x
				if x < x0 or x >= x0 + 27 or not Rules.in_rows(e["cell"], Vector2i(win.y, win.z)):
					continue
				var k := str(e["kind"])
				if k == "pod" or k == "glowfruit":
					n[k] += 1
				if k in ["glowfruit", "lantern", "pod"]:
					n["lights"] += 1
				if COST.has(k) or k == "dread":
					n["monsters"] += 1
			for k in n:
				worst[k] = maxi(int(worst[k]), int(n[k]))
		_check(worst["pod"] <= 8 and worst["glowfruit"] <= 6 and worst["lights"] <= 14 and worst["monsters"] <= 12,
				"%s: per screen at most 8 pods, 6 glowfruit, 14 feature lights, 12 monsters (%s)" % [id, worst])


func _windows(lv: RefCounted) -> Array:
	## [Vector3i(x0, y0, y1)]: every 27-tile window, each of its screen_rows.
	var out := []
	for x0 in range(0, maxi(lv.width - 26, 1)):
		for ys in Rules.screen_rows(lv, x0, 27):
			out.append(Vector3i(x0, ys.x, ys.y))
	return out


func _test_arena(lv: RefCounted) -> void:
	## R_ARENA (spec §3.4.4): the six bloom sockets, her placement, the two
	## glowfruit under the roof, the vines up to her sockets, sigil 3 by the
	## top of the left vine, the altar at the door.
	var x0: int = lv.width - 36
	var anchors := []
	for e in lv.entities:
		if e["kind"] == "anchor":
			anchors.append(e["cell"] - Vector2i(x0, 0))
	anchors.sort()
	var want := [Vector2i(3, 3), Vector2i(8, 12), Vector2i(9, 9), Vector2i(16, 6), Vector2i(20, 12), Vector2i(26, 6)]
	_check(anchors == want, "3-4: the six bloom sockets F1 F2 L1 L2 V1 V2 (%s)" % [anchors])
	var boss := Vector2i(-1, -1)
	for e in lv.entities:
		if e["kind"] == "boss":
			boss = e["cell"] - Vector2i(x0, 0)
	_check(boss == Vector2i(27, 12), "3-4: her X at arena column 27 (her trunk 28-35)")
	var trunk := true
	for y in range(2, 13):
		for x in range(28, 36):
			trunk = trunk and LevelData.is_solid(lv.tile(x0 + x, y))
	_check(trunk, "3-4: her trunk fills columns 28-35")
	var fruit: Array = lv.entities.filter(func(e): return e["kind"] == "glowfruit" and e["cell"].x >= x0)
	_check(fruit.size() == 2, "3-4: two glowfruit under her roof")
	_check(lv.tile(x0 + 5, 3) == LevelData.VINE and lv.tile(x0 + 5, 12) == LevelData.VINE and lv.tile(x0 + 25, 5) == LevelData.VINE,
			"3-4: her arena's vines (the left from the floor, the right to V2)")
	var s3: Array = lv.entities.filter(func(e): return e["kind"] == "sigil" and int(e["index"]) == 2)
	_check(s3.size() == 1 and s3[0]["cell"] == Vector2i(x0 + 5, 2), "3-4: sigil 3 hangs over the top of the left vine")


func _test_secret_exit(lv: RefCounted) -> void:
	## SW_UPDRAFT: the silver bell's attic, whose only way in is the false
	## stone under it (the static bot opens it; with it shut, no way). With
	## 3-S not yet built the attic stays, empty, and the proof stands in a
	## bell at its place.
	var bell: Array = lv.entities.filter(func(e): return e["kind"] == "silver_bell")
	var built := FileAccess.file_exists(SECRET)
	_check(bell.size() == (1 if built else 0), "3-3 has %s silver bell (3-S %s)" % ["one" if built else "no", "built" if built else "not built yet"])
	var rise_sign := false
	for e in lv.entities:
		if e["kind"] == "sign" and str(e["text"]) == "These spores rise. Where to?":
			rise_sign = true
	if not built:
		# The set piece waits for 3-S (w3.py SECRET_3S): the attic and its
		# crack are stone, and no sign points at rising spores.
		var sealed := true
		for dx in range(-4, 5):
			for dy in [0, 1]:
				if not LevelData.is_solid(lv.tile(ATTIC.x + dx, ATTIC.y + dy)) or lv.tile(ATTIC.x + dx, ATTIC.y + dy) == LevelData.FALSE_STONE:
					sealed = false
		_check(sealed and not rise_sign, "3-3 without 3-S: the attic and its crack are plain stone, and no sign speaks of rising spores")
		return
	# No sign points at it since the sign cut: secret_hint_3 says it, near the sight.
	_check(not rise_sign, "with 3-S built, no sign asks where the spores go (the bark does)")
	var c: Vector2i = bell[0]["cell"] if bell.size() == 1 else ATTIC
	_check(c == ATTIC and lv.tile(c.x, c.y) == LevelData.AIR, "the attic is at %s" % [c])
	var crack := 0
	for dx in range(-3, 4):
		if lv.tile(c.x + dx, c.y + 1) == LevelData.FALSE_STONE:
			crack += 1
	_check(crack >= 1 and LevelData.is_solid(lv.tile(c.x, c.y + 1)), "its attic floor is cracked false stone")
	if not _bot_climbs():
		_skip("3-3's silver bell behind its crack: the bot can't climb yet (reach.gd, W0)")
		return
	var goal := {"what": "silver bell", "p": LevelData.cell_floor(c), "rope": true,
			"rect": Rect2(LevelData.cell_floor(c) - Vector2(14, 44), Vector2(28, 44))}
	var open = Reach.static_copy(lv)
	var s1 = ReachSearch.new()
	s1.setup(open, LevelData.cell_floor(lv.start), {"goals": [goal]})
	s1.run()
	s1.free_player()
	_check(s1.found.has("silver bell"), "with the crack open, the bot reaches the attic")
	var shut = Reach.static_copy(lv, {"open_breakables": false})
	var s = ReachSearch.new()
	s.setup(shut, LevelData.cell_floor(lv.start), {"goals": [goal]})
	s.run()
	s.free_player()
	_check(not s.found.has("silver bell"), "with the crack whole, the attic can't be reached")


func _bot_climbs() -> bool:
	## Does the reachability engine climb? (A vine and a shelf at its top: a
	## climb action with a way held must mount it, not leap off at once.)
	var lines := []
	for y in 13:
		lines.append("")
	for y in range(5, 13):
		lines[y] = "....{"
	lines[5] = "....{####"
	lines[12] = "..P.{"
	var lv := _level(lines, "", 20)
	var s = ReachSearch.new()
	s.setup(lv, Vector2(4.5 * TILE, 11 * TILE + 16.0 + 19.0), {"start_climb": true, "goals": []})
	var r: Dictionary = s.simulate(s.nodes[0], {"vine": true, "mode": "climb", "t": 1.5, "dir": 1})
	s.free_player()
	return r["ok"] and not r["climb"] and absf((r["pos"] as Vector2).y - 5 * TILE) < 1.0


func _test_bot_stone(levels: Dictionary) -> void:
	## Spec §3.1 rule 3 along the bot's own winning path to the bell (3-4: to
	## the arena). _test_layout's column rule counts any SAFE top over a pit,
	## a sigil's high shelf too; this one counts only the tops along the
	## path: in a column the path crosses, within 2 rows over its feet (a
	## jump takes it) to 4 rows under them (a drop lands on it). Over a pit
	## those are at most 14 tiles apart.
	if not _bot_climbs():
		_skip("the stone rule along the bot's path: the bot can't climb yet (reach.gd, W0)")
		return
	for id in LEVEL_IDS:
		var lv = levels[id]
		var want := "boss arena" if lv.boss != "" else "bell"
		var s = ReachSearch.new()
		s.setup(Reach.static_copy(lv), LevelData.cell_floor(lv.start),
				{"timed": Reach.timed_cells(lv), "goals": Reach.goals_of(lv).filter(func(g): return g["what"] == want)})
		s.run()
		s.free_player()
		_check(s.found.has(want), "%s: the bot reaches the %s" % [id, want])
		if not s.found.has(want):
			continue
		# The band of rows the path's feet cross in each column.
		var lo := {}
		var hi := {}
		var prev := Vector2(-1, -1)
		for ni in s.path_to(int(s.found[want]["node"])):
			var q: Vector2 = (s.nodes[ni]["pos"] as Vector2) / TILE
			var a0: Vector2 = q if prev.x < 0.0 else prev
			for cx in range(floori(minf(a0.x, q.x)), floori(maxf(a0.x, q.x)) + 1):
				lo[cx] = minf(float(lo.get(cx, INF)), minf(a0.y, q.y))
				hi[cx] = maxf(float(hi.get(cx, -INF)), maxf(a0.y, q.y))
			prev = q
		var cols := _cols_of(lv)
		var last := -1
		var worst := 0
		var at := ""
		for x in lv.width:
			if not lo.has(x):
				continue
			var safe := false
			for y in range(1, lv.height):
				if LevelData.is_safe(lv.tile(x, y)) and not LevelData.is_solid(lv.tile(x, y - 1)) and not LevelData.is_floor(lv.tile(x, y - 1)) \
						and float(y) >= float(lo[x]) - 2.0 and float(y) <= float(hi[x]) + 4.0:
					safe = true
			if safe:
				last = x
			elif bool(cols[x]["pit"]) and last >= 0 and x + 1 - last > worst:
				worst = x + 1 - last
				at = "x %d-%d" % [last, x]
		_check(worst <= STONE_EVERY, "%s: along the bot's path over a pit, stone every %d tiles or less (worst %d, %s)" % [id, STONE_EVERY, worst, at])


func _test_first_vine(lv: RefCounted) -> void:
	## BG_START (spec §3.4.3): the gate's wall is too tall to jump, so climb.
	## The vine is as tall as the wall: climbing it (jump or up held, toward
	## the wall) hauls him onto the wall; with no vine no jump gets there.
	var vx := -1
	for x in 22:
		if lv.tile(x, 12) == LevelData.VINE:
			vx = x
	_check(vx >= 0, "BG_START has its vine")
	if vx < 0:
		return
	var top := 12
	while LevelData.is_climb(lv.tile(vx, top - 1)):
		top -= 1
	var wall := vx + 1
	while wall < 22 and not LevelData.is_solid(lv.tile(wall, 12)):
		wall += 1
	var wtop := 12
	while LevelData.is_solid(lv.tile(wall, wtop - 1)):
		wtop -= 1
	_check(top == wtop and 13 - wtop >= 4, "its top (row %d) is the wall's (row %d), %d tiles up" % [top, wtop, 13 - wtop])
	for how in [{"jump": true, "right": true}, {"up": true, "right": true}]:
		var p = _sim(lv, "", Vector2((vx + 0.5) * TILE, 13 * TILE - 2.0))
		p.grab_vine(vx, 0.0)
		var on_wall := false
		var prev := false
		for i in 360:
			var pd: Dictionary = how.duplicate()
			pd["jump_pressed"] = pd.get("jump", false) and not prev
			prev = pd.get("jump", false)
			p.pad = pd
			p.step(DT)
			p.world.ftime += DT
			if p.on_floor and absf(p.position.y - wtop * TILE) < 0.5 and p.position.x > wall * TILE:
				on_wall = true
				break
		_check(on_wall, "climbing it with %s held hauls him onto the wall" % ["jump" if how.has("jump") else "up"])
		p.free()
	# Without the vine, no running jump from the floor reaches the wall's top.
	var bare = _crop(lv, 0, 40, lv.start)
	for y in lv.height:
		if LevelData.is_climb(bare.tile(vx, y)):
			bare.set_tile(vx, y, LevelData.AIR)
	var got := false
	for sx in range(2, wall):
		for k in range(0, 60, 2):
			if got:
				break
			var p = _sim(bare, "", Vector2((sx + 0.5) * TILE, 13 * TILE))
			var prev2 := false
			for i in 200:
				var held := i >= k
				p.pad = {"right": true, "jump": held, "jump_pressed": held and not prev2}
				prev2 = held
				p.step(DT)
				if p.on_floor and absf(p.position.y - wtop * TILE) < 0.5:
					got = true
					break
			p.free()
	_check(not got, "with no vine, no running jump gets onto the %d-high wall" % (13 - wtop))


func _sim(lv: RefCounted, quirk: String, feet: Vector2):
	## A lone hero in lv (the bot's stand-in World: vines, rotten runs).
	var bw = Reach.BotWorld.new()
	bw.level = lv
	var p = load("res://scripts/player.gd").new()
	p.level = lv
	p.world = bw
	p.quirk = quirk
	p.reset_at(feet)
	p.on_floor = true
	return p


func _in_nook(p) -> bool:
	return p.on_floor and absf(p.position.y - NOOK_FLOOR * TILE) < 0.5 and p.position.x > (NOOK_X0 + 2) * TILE \
			and p.position.x < (NOOK_X0 + 4) * TILE


func _nook_try(lv: RefCounted, quirk: String, feet: Vector2, pre: int, dir: int, k: int, hold: int) -> bool:
	var p = _sim(lv, quirk, feet)
	var prev := false
	var inside := false
	for i in 220:
		var held := i >= k and i < k + hold
		var d := pre if i < k else dir
		p.pad = {"right": d > 0, "left": d < 0, "jump": held, "jump_pressed": held and not prev}
		prev = held
		p.step(DT)
		p.world.ftime += DT
		if _in_nook(p):
			inside = true
			break
	p.free()
	return inside


func _ground(lv: RefCounted, x: int, from_y: int) -> int:
	## The first solid row at or under from_y in column x (his feet's row
	## standing there).
	var y := from_y
	while y < lv.height and not LevelData.is_solid(lv.tile(x, y)):
		y += 1
	return y


func _test_nook(lv: RefCounted) -> void:
	## 3-3's keeper nook (spec §3.1: one optional spot only a quirk reaches,
	## an ember cache; §3.4.3: the Candleknight's Ledge Grab, "a root lip 12
	## px short of a shelf"): the lip over the slot stops a jump's feet 6 px
	## under the hollow's floor, which the grab (LEDGE_REACH 12) takes and no
	## one else can stand on.
	var embers := []
	for e in lv.entities:
		var ec: Vector2i = e["cell"]
		if e["kind"] == "ember" and ec.x >= NOOK_X0 + 2 and ec.x <= NOOK_X0 + 3 and ec.y < NOOK_FLOOR:
			embers.append(e)
	_check(embers.size() == 3, "3-3: the nook holds an ember cache (%d embers), no sigil" % embers.size())
	_check(lv.entities.filter(func(e): return e["kind"] == "sigil" and absi(int(e["cell"].x) - NOOK_X0 - 2) <= 2).is_empty(),
			"3-3: and no sigil")
	var ledge := Vector2((NOOK_LEDGE.x + 0.5) * TILE, NOOK_LEDGE.y * TILE)
	_check(LevelData.is_ledge(lv.tile(NOOK_LEDGE.x, NOOK_LEDGE.y)) and LevelData.is_solid(lv.tile(NOOK_LEDGE.x, NOOK_LIP))
			and LevelData.is_solid(lv.tile(NOOK_X0 + 2, NOOK_FLOOR)), "3-3: the branch ledge, the root lip over the slot and the hollow's floor")
	_check(_nook_try(lv, "ledge_grab", ledge, 1, 1, 5, 60), "3-3: the Candleknight jumps from the ledge into the lip and grabs his way in")
	# No other way in: every start near it, every way held, every jump timing.
	var starts := [ledge, Vector2((NOOK_X0 + 0.5) * TILE, NOOK_LEDGE.y * TILE)]
	for sx in range(NOOK_X0 - 3, NOOK_X0 + 6):
		starts.append(Vector2((sx + 0.5) * TILE, _ground(lv, sx, NOOK_LEDGE.y + 1) * TILE))
	for q in ["", "cling", "stampede"]:
		var got := 0
		var n := 0
		for st in starts:
			for pre in [-1, 1]:
				for dir in [-1, 0, 1]:
					for k in range(0, 48, 4):
						for hold in [10, 40, 90]:
							n += 1
							if _nook_try(lv, q, st, pre, dir, k, hold):
								got += 1
		_check(got == 0, "3-3: with %s, none of %d jumps near it gets in (%d did)" % ["no quirk" if q == "" else q, n, got])
	# The bot (no quirk, its whole action set, vines too once it climbs).
	var goal := {"what": "nook", "p": LevelData.cell_center(embers[0]["cell"]) if not embers.is_empty() else Vector2.ZERO, "rope": false}
	var crop = _crop(Reach.static_copy(lv), NOOK_X0 - 12, NOOK_X0 + 30, NOOK_FROM)
	goal["p"] = (goal["p"] as Vector2) - Vector2((NOOK_X0 - 12) * TILE, 0)
	var s = ReachSearch.new()
	s.setup(crop, LevelData.cell_floor(crop.start), {"goals": [goal]})
	s.run()
	s.free_player()
	_check(not s.found.has("nook"), "3-3: the reachability bot never gets into the nook (%d states)" % s.seen.size())


func _test_lanterns(levels: Dictionary) -> void:
	## Spec §3.4.3: 3-1 BG_BELL's Weepcap is taught "by a brazier" (a skull
	## lantern: "Fire burns them away"), and 3-2's Widow Cap has "one brazier
	## to light (fire clears her clouds)". Lit, each lantern's flame burns the
	## real puffs she sends at Wick standing just past it; unlit, none burn.
	for id in ["3-1", "3-2"]:
		var lv = levels[id]
		var cap := Vector2i(-1, -1)
		for e in lv.entities:
			if e["kind"] == "weepcap" or (e["kind"] == "dread" and str(lv.dread.get("kind", "")) == "weepcap"):
				if id == "3-1" and e["kind"] == "weepcap" and cap.x < 0:
					cap = e["cell"]
				elif id == "3-2" and e["kind"] == "dread":
					cap = e["cell"]
		var lan := Vector2i(-1, -1)
		for e in lv.entities:
			if e["kind"] == "lantern" and (lan.x < 0 or absi(e["cell"].x - cap.x) < absi(lan.x - cap.x)):
				lan = e["cell"]
		_check(cap.x >= 0 and lan.x >= 0 and absi(lan.x - cap.x) <= 3, "%s: the lantern stands %d tiles from her" % [id, absi(lan.x - cap.x)])
		var side := signi(lan.x - cap.x)
		var feet := LevelData.cell_floor(Vector2i(lan.x + side, lan.y))
		for lit in [true, false]:
			game.reset()
			game.new_hero("knight")
			game.data["difficulty"] = "dusk"
			var w: Node2D = WorldScript.new()
			w.setup(lv, true)
			w.paused = true
			root.add_child(w)
			await process_frame
			var o = _orchard(w)
			var l: Dictionary = w.features.lanterns.filter(func(x): return x["cell"] == lan)[0]
			if lit:
				w.features.light(l)
			w.player.reset_at(feet)
			var puffs := 0
			var burnt := 0
			for i in int(6.0 / DT):
				w.test_pad = {}
				w._read_pad()
				w.player.invuln = 99.0
				w.player.hp = w.player.max_hp
				w.tick(DT)
				for c in o.clouds:
					if c["source"] == null or c["source"] == o:
						continue
					if not c.has("_counted"):
						c["_counted"] = true
						puffs += 1
					if float(c["burn"]) >= 0.0 and not c.has("_burnt"):
						c["_burnt"] = true
						burnt += 1
			if lit:
				_check(puffs > 0 and burnt > 0, "%s: lit, the lantern's fire burns her puffs (%d puffed, %d burnt)" % [id, puffs, burnt])
			else:
				_check(puffs > 0 and burnt == 0, "%s: unlit, none burn (%d puffed, %d burnt)" % [id, puffs, burnt])
			w.queue_free()
			await process_frame


func _crop(lv: RefCounted, x0: int, x1: int, from: Vector2i) -> RefCounted:
	var c = LevelData.new()
	c.id = lv.id
	c.width = x1 - x0
	c.height = lv.height
	c.tiles = PackedByteArray()
	c.tiles.resize(c.width * c.height)
	for y in c.height:
		for x in c.width:
			c.tiles[y * c.width + x] = lv.tile(x0 + x, y)
	c.entities = []
	for e in lv.entities:
		if e["kind"] == "sigil" and e["cell"].x >= x0 and e["cell"].x < x1:
			var m: Dictionary = e.duplicate()
			m["cell"] = Vector2i(e["cell"].x - x0, e["cell"].y)
			c.entities.append(m)
	c.start = Vector2i(from.x - x0, from.y)
	return c


func _reach_goal(lv: RefCounted, goal: String) -> bool:
	var s = ReachSearch.new()
	s.setup(lv, LevelData.cell_floor(lv.start), {"goals": Reach.goals_of(lv).filter(func(g): return g["what"] == goal)})
	s.run()
	s.free_player()
	return s.found.has(goal)


func _tight(lv: RefCounted, c: Vector2i) -> bool:
	## World 3's tight landings: a lone one-tile stone (a root knot), a
	## crumble, or a rotten run of 3 or fewer.
	var t: int = lv.tile(c.x, c.y)
	if t == LevelData.CRUMBLE:
		return true
	if t == LevelData.ROTTEN_VINE:
		var y0 := c.y
		var y1 := c.y
		while lv.tile(c.x, y0 - 1) == LevelData.ROTTEN_VINE:
			y0 -= 1
		while lv.tile(c.x, y1 + 1) == LevelData.ROTTEN_VINE:
			y1 += 1
		return y1 - y0 + 1 <= 3
	return LevelData.is_solid(t) and not LevelData.is_solid(lv.tile(c.x - 1, c.y)) and not LevelData.is_solid(lv.tile(c.x + 1, c.y)) \
			and not LevelData.is_solid(lv.tile(c.x, c.y - 1))


func _test_star_routes(levels: Dictionary) -> void:
	## test_content's STAR_ROUTES, World 3: every landing tight; the bot reaches
	## the star sigil; with the route's landings gone it can't.
	var climbs := _bot_climbs()
	for id in STAR_ROUTES:
		var sr: Dictionary = STAR_ROUTES[id]
		var lv = levels[id]
		var tight := true
		for c in sr["route"]:
			tight = tight and _tight(lv, c)
		_check(tight, "%s: the star route's landings are tight (%s)" % [id, sr["what"]])
		var goal := "sigil %d" % int(sr["sigil"])
		var sig: Array = lv.entities.filter(func(e): return e["kind"] == "sigil" and int(e["index"]) + 1 == int(sr["sigil"]))
		_check(sig.size() == 1, "%s: its star is sigil %d" % [id, sr["sigil"]])
		if not climbs:
			_skip("%s's star route: the bot can't climb yet (reach.gd, W0)" % id)
			continue
		var from: Vector2i = sr["from"]
		var x0 := from.x
		var x1 := from.x
		for c in sr["route"]:
			x0 = mini(x0, c.x)
			x1 = maxi(x1, c.x)
		x0 = mini(x0, sig[0]["cell"].x)
		x1 = maxi(x1, sig[0]["cell"].x)
		var open = _crop(Reach.static_copy(lv), maxi(x0 - 2, 0), mini(x1 + 12, lv.width), from)
		for i in open.tiles.size():
			if LevelData.is_breakable(open.tiles[i]):
				open.tiles[i] = LevelData.AIR
		_check(_reach_goal(open, goal), "%s: the bot reaches the star %s" % [id, goal])
		var base := maxi(x0 - 2, 0)
		for c in sr["route"]:
			open.set_tile(c.x - base, c.y, LevelData.AIR)
			# A rotten landing goes with its whole run.
			if lv.tile(c.x, c.y) == LevelData.ROTTEN_VINE:
				for y in lv.height:
					if lv.tile(c.x, y) == LevelData.ROTTEN_VINE:
						open.set_tile(c.x - base, y, LevelData.AIR)
		_check(not _reach_goal(open, goal), "%s: and without its route it can't" % id)


func _test_smoke(levels: Dictionary) -> void:
	## Each level plays its golden route's inputs with its monsters and every
	## feature on (the hero kept from harm: the route was recorded with none;
	## past the first altar at least, a monster in the way may put him off
	## it later): pods burst, Weepcaps puff, clouds rise and burn, fruit
	## falls, with no error, every feature list sane, and never more than 5
	## live clouds in a screen (spec §3.1's cap).
	var routes := {"3-1": "res://tests/routes/3-1.json", "3-2": "res://tests/routes/3-2.json",
		"3-3": "res://tests/routes/3-3.json", "3-4": APPROACH}
	for id in LEVEL_IDS:
		if not FileAccess.file_exists(routes[id]):
			_skip("%s's smoke run: no route" % id)
			continue
		var lv = levels[id]
		var route := Route.read(routes[id])
		Route.prepare(game, route, lv)
		var altar: int = lv.width
		for e in lv.entities:
			if e["kind"] == "altar":
				altar = mini(altar, int(e["cell"].x))
		var w: Node2D = WorldScript.new()
		w.setup(lv, true)
		w.paused = true
		root.add_child(w)
		await process_frame
		var o = _orchard(w)
		_check(o != null and o.pods.size() == lv.count("pod") and o.fruit.size() == lv.count("glowfruit"),
				"%s: the orchard holds its %d pods and %d glowfruit" % [id, lv.count("pod"), lv.count("glowfruit")])
		var masks := Route.decode(route["runs"])
		var pl: Node2D = w.player
		var most := 0
		var burst := 0
		var fell := 0
		var passed := -1
		var far := 0.0
		for i in masks.size():
			w.test_pad = Route.pad_of(int(masks[i]))
			w._read_pad()
			pl.invuln = 99.0
			pl.hp = pl.max_hp
			w.tick(DT)
			var n := 0
			for c in o.clouds:
				if float(c["burn"]) < 0.0 and absf((c["p"] as Vector2).x - pl.position.x) < 13.5 * TILE:
					n += 1
			most = maxi(most, n)
			burst = maxi(burst, o.pods.filter(func(p): return p["state"] != "closed").size())
			fell = maxi(fell, o.fruit.filter(func(f): return f["state"] != "hang").size())
			if passed < 0 and pl.position.x > (altar + 1) * TILE:
				passed = i
			far = maxf(far, pl.position.x / TILE)
			if w.state != "play" and w.state != "respawn":
				break
		var sane := true
		for c in o.clouds:
			sane = sane and float(c["t"]) <= float(c["life"]) and float(c["burn"]) <= Orchard.BURN_TIME
		_check(passed >= 0, "%s: its route, monsters on, gets past the first altar (x %d; on to x %.0f of %d, %s)" % [id, altar + 1, far, lv.width, w.state])
		var pods_before: int = lv.entities.filter(func(e): return e["kind"] == "pod" and int(e["cell"].x) < altar).size()
		_check(sane and (burst > 0 or pods_before == 0), "%s: the %d pods on the way went off (%d at once), fruit fell (%d), the lists sane" % [id, pods_before, burst, fell])
		_check(most <= 5, "%s: at most 5 live clouds in a screen (%d)" % [id, most])
		w.queue_free()
		await process_frame


func _test_leap_bands(levels: Dictionary) -> void:
	## The int2 review: from every cell of every vine over a pit or a thorn
	## bed, a tapped leap along the level (with its way held, as a thumb
	## does) catches the next vine or lands; one from a vine's lowest cells may
	## fall short (climb between leaps), but none bonks the roof into a fall
	## (a vine's top keeps 2 rows of air under its roof), and every vine gives
	## a band of at least LEAP_BAND rows that doesn't fall (the whole vine,
	## less a tile, when it's shorter): HW_CLIMB's rotten x49 to its knot was
	## 0.7 rows before the knot went two wide and a tile left under a raised
	## roof.
	for id in LEVEL_IDS:
		var lv: RefCounted = levels[id]
		var w: Node2D = await _world(lv)
		var pl: Node2D = w.player
		var bad := []
		var bands := []
		for x in lv.width:
			var y := 0
			while y < lv.height:
				if not LevelData.is_climb(lv.tile(x, y)):
					y += 1
					continue
				var y0 := y
				while y < lv.height and LevelData.is_climb(lv.tile(x, y)):
					y += 1
				var y1 := y          # the run is rows y0 .. y1 - 1
				var under := y1
				while under < lv.height and not LevelData.is_solid(lv.tile(x, under)) and lv.tile(x, under) != LevelData.SPIKES_UP:
					under += 1
				var hurts: bool = under >= lv.height or lv.tile(x, under) == LevelData.SPIKES_UP
				if not hurts:
					continue
				var ok_rows := 0.0
				var cy := float(y0)
				while cy < float(y1):
					var r := _leap_from(w, x, cy)
					if r == "bonk-fell":
						bad.append("x%d from row %.2f" % [x, cy])
					if r != "fell" and r != "bonk-fell":
						ok_rows += 0.125
					cy += 0.125
				var need := minf(LEAP_BAND, float(y1 - y0) - 1.0)
				bands.append("x%d %.1f/%d" % [x, ok_rows, y1 - y0])
				if ok_rows + 0.001 < need:
					bad.append("x%d rows %d-%d: only %.2f rows land or catch (%.1f wanted)" % [x, y0, y1 - 1, ok_rows, need])
		_check(bad.is_empty(), "%s: every leap from a vine over a pit or thorns catches or lands (no bonk into a fall, a band of %.0f rows each): %s" % [id, LEAP_BAND, bad])
		print("  %s leap bands (rows that land or catch / the vine's rows): %s" % [id, ", ".join(bands)])
		await _done(w)


const LEAP_BAND := 2.0


func _leap_from(w: Node2D, col: int, cy: float) -> String:
	## A tapped leap to the right from vine col, his centre at row cy:
	## "caught", "landed", "fell" or "bonk-fell" (his head met the roof on
	## the way up, and then he fell).
	var pl: Node2D = w.player
	for k in 400:
		if w.state == "play" and pl.alive and w.hitstop <= 0.0 and k > 2:
			break
		w.test_pad = {}
		w._read_pad()
		w.tick(DT)
	w.features.on_respawn()
	for cell in w.crumbles:
		w.crumbles[cell] = {"state": "idle", "timer": 0.0}   # (each leap on a fresh crumble)
	pl.reset_at(Vector2((col + 0.5) * TILE, cy * TILE + 19.0))
	pl.hp = pl.max_hp
	pl.hurt_time = 10.0
	pl.grab_vine(col, 0.3)
	var bonk := false
	for i in 300:
		var p := {"right": true}
		if i == 1:
			p["jump"] = true
		w.test_pad = p
		var vy0: float = pl.velocity.y
		w._read_pad()
		w.tick(DT)
		if i > 1 and vy0 < -150.0 and pl.velocity.y >= 0.0 and not pl.climbing and not pl.on_floor:
			bonk = true
		if i > 3 and pl.climbing:
			return "caught"
		if i > 3 and pl.on_floor:
			return "landed"
		if pl.hp < pl.max_hp:
			return "bonk-fell" if bonk else "fell"
	return "fell"


func _test_canopy_mount(lv: RefCounted) -> void:
	## SW_CANOPY's sigil 1 ledge: from the top of the vine beside it
	## (CANOPY_VINE), jump held toward it hauls him up (the roof cell over the
	## vine is open, as over the ledge: player._clear_above refused the haul
	## under it).
	var w: Node2D = await _world(lv)
	var pl: Node2D = w.player
	var col := CANOPY_VINE.x
	pl.reset_at(Vector2((col + 0.5) * TILE, (CANOPY_VINE.y + 4.5) * TILE + 19.0))
	pl.grab_vine(col, 0.3)
	var on := false
	for i in int(4.0 / DT):
		# (jump pressed on its own climbs; held on, a way held too mounts)
		w.test_pad = {} if i < 3 else ({"jump": true} if i < 6 else {"jump": true, "right": true})
		w._read_pad()
		w.tick(DT)
		if pl.on_floor and not pl.climbing and absf(pl.position.y - (CANOPY_VINE.y + 1.0) * TILE) < 2.0 and pl.position.x > (col + 1.0) * TILE:
			on = true
			break
	_check(on, "3-3: climbing x %d with jump held toward sigil 1's ledge hauls him onto it (at %s)" % [col, pl.position / TILE])
	await _done(w)


func _ui_world(lv: RefCounted, monsters := false) -> Node2D:
	## A Dusk World on lv with its HUD and touch controls (what the HUD's top
	## band is measured against), ticked half a second.
	game.reset()
	game.new_hero("knight")
	game.data["difficulty"] = "dusk"
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = not monsters
	w.paused = true
	root.add_child(w)
	await process_frame
	var hud = load("res://scripts/hud.gd").new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	var touch = load("res://scripts/touch_controls.gd").new()
	w.touch = touch
	touch.hud = hud
	w.add_child(touch)
	await process_frame
	touch.apply_settings()
	_tick(w, 0.5)
	return w


func _test_shapes(levels: Dictionary) -> void:
	## World 3 reads strip, tower, bowl (Build 2's shapes): 3-1 a strip; 3-2
	## the 36-row tower, its start on the gallery along its bottom and its
	## bell on the wall's top storey, in the wall's middle third and 3 rows or
	## more under its roof; 3-3 the 24-row bowl, its start and bell at the
	## wood's height and altar 1 at the Clearing's door on the bowl's floor.
	## With the camera settled on him at each goal, none is behind the HUD's
	## top band (tall_cam.goal_hits). And each one's twist and set pieces in
	## play: 3-1's lesson card and no rule; 3-2's Restless and Brother
	## Clatter; 3-3's Omens, Sister Thistle, and the Clearing's ambush, shut
	## once he's in and open again once its five (the Mourner's halves too)
	## are down.
	var l1 = levels["3-1"]
	var l2 = levels["3-2"]
	var l3 = levels["3-3"]
	_check(l1.height == LevelData.STRIP_ROWS and l2.height == 36 and l3.height == 24,
			"3-1 a strip, 3-2 a tower 36 rows tall, 3-3 a bowl 24 rows deep (%d, %d, %d)" % [l1.height, l2.height, l3.height])
	var bell2: Vector2i = l2.entities.filter(func(e): return e["kind"] == "bell")[0]["cell"]
	var wall0: int = l2.width - 40
	_check(l2.start.y == 33 and bell2.y >= 3 and bell2.y <= 9 and bell2.x >= wall0 + 13 and bell2.x <= wall0 + 26,
			"3-2: the start on the gallery's floor (row %d), the bell on the wall's top storey in its middle third (%s)" % [l2.start.y, bell2])
	var bell3: Vector2i = l3.entities.filter(func(e): return e["kind"] == "bell")[0]["cell"]
	var alts: Array = l3.entities.filter(func(e): return e["kind"] == "altar").map(func(e): return e["cell"])
	alts.sort()
	_check(l3.start.y == 12 and bell3.y == 12 and not alts.is_empty() and alts[0].y == 21,
			"3-3: the start and the bell at the wood's height (row 12), altar 1 on the bowl's floor (row 21) (%s, %s, %s)" % [l3.start, bell3, alts])
	for id in ["3-2", "3-3"]:
		var w := await _ui_world(levels[id])
		var hits: Array = w.tall_cam.goal_hits() if w.tall_cam != null else ["no tall camera"]
		_check(hits.is_empty(), "%s: every goal shows clear of the HUD's top band (%s)" % [id, hits])
		await _done(w)
	var Twists = load("res://scripts/twists.gd")
	_check(Twists.lesson_in(l1) == ["Into the Orchard", "Roots follow your steps. Keep moving."] and Twists.id_in(l1) == "",
			"3-1: the lesson card \"Into the Orchard\", no rule")
	var w2 := await _ui_world(l2, true)
	var clatter: Array = w2.enemies.filter(func(e): return e.elite_name == "Brother Clatter")
	_check(w2.twist("restless") and clatter.size() == 1 and clatter[0].kind == "rattlehound" and clatter[0].tier == "anointed"
			and (clatter[0].omens as Array).has("Sporebound"), "3-2: Restless, and Brother Clatter a Sporebound Anointed Rattlehound")
	await _done(w2)
	var w3 := await _ui_world(l3, true)
	var thistle: Array = w3.enemies.filter(func(e): return e.elite_name == "Sister Thistle")
	_check(w3.twist("omens") and thistle.size() == 1 and thistle[0].kind == "thornback" and thistle[0].tier == "anointed"
			and (thistle[0].omens as Array).has("Swift"), "3-3: Omens, and Sister Thistle a Swift Anointed Thornback")
	var m = w3.features.module("sealed")
	var r: Dictionary = m.rooms[0] if m != null and m.rooms.size() == 1 else {}
	var specs: Array = r.get("specs", [])
	_check(str(r.get("kind", "")) == "ambush" and specs.size() == 5
			and specs.any(func(sp): return sp["name"] == "The Mourner" and sp["tier"] == "anointed" and sp["kind"] == "weepcap"),
			"3-3: the Clearing an ambush of five, the Mourner a Twinned Anointed Weepcap among them (%d)" % specs.size())
	if not r.is_empty():
		var pl: Node2D = w3.player
		pl.invuln = 1000.0
		pl.reset_at(LevelData.cell_floor(Vector2i(int(r["x0"]) + 4, 21)))
		for i in int(1.5 / DT):
			if r["phase"] == "fight":
				break
			_tick(w3, DT)
		_check(r["phase"] == "fight", "3-3: in the Clearing, its doors shut (%s)" % r["phase"])
		for i in int(15.0 / DT):
			if r["phase"] == "won":
				break
			pl.invuln = 1000.0
			pl.hp = pl.max_hp
			# Down with every foe that can be hit; walk at the rest (a buried
			# Rootling follows him and comes up only near him).
			var pad := {}
			if (r["drops"] as Array).is_empty():
				for e in m.counted(r):
					if e.alive:
						w3.deal(e, 1.0, {"flat": e.max_hp * 20.0, "no_hitstop": true})
				var left: Array = m.counted(r).filter(func(e): return e.alive)
				if not left.is_empty() and absf(left[0].position.x - pl.position.x) > 3.0 * TILE:
					pad = {"right": true} if left[0].position.x > pl.position.x else {"left": true}
			_tick(w3, DT, pad)
		if r["phase"] != "won":
			print("  (left: %s, dropping %d)" % [m.counted(r).map(func(e): return "%s %s" % [e.kind, e.position / TILE]), (r["drops"] as Array).size()])
		_check(r["phase"] == "won" and (r["door"] as Array).all(func(c): return w3.level.tile(c.x, c.y) == LevelData.AIR),
				"3-3: and its doors open once its five and the Mourner's halves are down (%s)" % r["phase"])
	await _done(w3)


func _test_approach() -> void:
	## HW_CLIMB's timed crossing (rotten vines over the pit): the recorded
	## approach replays, with no snuff, to the arena door.
	if not FileAccess.file_exists(APPROACH):
		_skip("%s not recorded yet" % APPROACH.get_file())
		return
	var route := Route.read(APPROACH)
	var lv = LevelData.load_file("res://levels/3-4.txt")
	Route.prepare(game, route, lv)
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = true
	w.paused = true
	root.add_child(w)
	await process_frame
	var masks := Route.decode(route["runs"])
	var until := float(route.get("until_x", 0.0))
	var got := -1
	for i in masks.size():
		w.test_pad = Route.pad_of(int(masks[i]))
		w._read_pad()
		w.tick(DT)
		if got < 0 and w.player.position.x >= until:
			got = i
	_check(got >= 0, "3-4's approach replays to the arena door (x %.0f, wanted %.0f)" % [w.player.position.x, until])
	_check(w.snuffs == 0, "with no snuff (%d)" % w.snuffs)
	w.queue_free()
	await process_frame
