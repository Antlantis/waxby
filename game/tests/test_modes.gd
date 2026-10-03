extends SceneTree
## The modes (MO; spec §7, workstreams.md §2.4, p_modes §13 with the v3
## numbers): the mode seam and the save's block, the cosmetics (the warm-
## flame rule), the Descent's rooms (every room proven by the reachability
## bot seam to seam, both ways when it mirrors), stitched depths, the ramp,
## the run rules, the Waxworks (its arenas, every Tweak's number, the drips
## and seals), the Trials (every room, its loadout legal, the bot through it
## with its assist ledges, the kits' own quirks across their gaps, medals
## from the timing bot), the screens at the phone's two sizes, and the
## debug routes the phone gates run (descent:16, descent:30, rush:snuffer,
## trial:w1).
##
##     godot --headless --path game --script res://tests/test_modes.gd
##     WAXBY_FAST=1   fewer bot runs (no mirrored rooms, one depth a biome)
##     WAXBY_SLOW=1   the nightly: 60 stitched depths a biome
##     WAXBY_TIMING=1 print the timing bot's base times for trial_data.gd

const LevelData := preload("res://scripts/level_data.gd")
const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
const Combat := preload("res://scripts/combat.gd")
const Classes := preload("res://scripts/classes.gd")
const Progression := preload("res://scripts/progression.gd")
const Hero := preload("res://scripts/hero.gd")
const UI := preload("res://scripts/ui.gd")
const ModesSave := preload("res://scripts/modes/modes_save.gd")
const Cosmetics := preload("res://scripts/modes/cosmetics.gd")
const Rooms := preload("res://scripts/modes/rooms.gd")
const Data := preload("res://scripts/modes/descent_data.gd")
const TrialData := preload("res://scripts/modes/trial_data.gd")
const TILE := 32
const DT := 1.0 / 120.0
const BIOMES := ["cathedral", "tallow"]

var WorldScript: GDScript
var Descent: GDScript
var Waxworks: GDScript
var Trials: GDScript
var Mode: GDScript
var game: Node
var _passed := 0
var _failed := 0
var _fast := OS.get_environment("WAXBY_FAST") != ""
var _slow := OS.get_environment("WAXBY_SLOW") != ""


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	Descent = load("res://scripts/modes/descent.gd")
	Waxworks = load("res://scripts/modes/waxworks.gd")
	Trials = load("res://scripts/modes/trials.gd")
	Mode = load("res://scripts/modes/mode.gd")
	game = root.get_node_or_null("Game")
	print("  autoloads: Game %s, Sfx %s" % [game != null, root.get_node_or_null("Sfx") != null])
	if game == null:
		print("test_modes: 0 passed, 1 failed")
		quit(1)
		return
	game.save_path = "user://test_modes_save.json"
	game.slot_base = "user://test_modes_save"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	var t0 := Time.get_ticks_msec()
	_test_save()
	_test_cosmetics()
	_test_rooms()
	_test_rooms_overlay()
	_test_room_reach()
	_test_stitching()
	_test_ramp()
	await _test_descent_world()
	await _test_descent_rules()
	await _test_glimmers()
	await _test_landing_once()
	await _test_pause_fallback()
	await _test_rush_files()
	await _test_waxworks()
	_test_trials_data()
	_test_trial_reach()
	await _test_kit_timing()
	await _test_trials_world()
	await _test_quirks()
	await _test_screens()
	_test_hub_lines()
	_test_build_counts()
	await _test_autoplay_routes()
	_test_xp_rate()
	ModesSave.force_open = false
	print("  (%d ms)" % (Time.get_ticks_msec() - t0))
	print("test_modes: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _fresh() -> void:
	game.reset()
	ModesSave.force_open = false
	if game.heroes().is_empty():
		game.new_hero("knight")


# ---------------------------------------------------------------- the save

func _test_save() -> void:
	var d := ModesSave.defaults()
	_check(d.has("descent") and d.has("waxworks") and d.has("trials") and d.has("cosmetics") and d.has("seen"), "ModesSave.defaults() has every part")
	_check((d["cosmetics"]["owned"] as Array).has("flame:tallow") and (d["cosmetics"]["owned"] as Array).has("color:calling"), "the free cosmetics are owned from the start")
	# clean() fixes junk.
	var junk := {"seen": ["door:descent", 7, "door:descent"],
		"descent": {"best": {"knight": {"dusk": {"depth": 14.0, "time": "1904.2", "level": 33.0}, "moon": {"depth": 3}},
				"wizard": {"dusk": {"depth": 99}}},
			"cleared": {"dusk": 14.0, "nightfall": -3}, "milestones": {"dusk": [5.0, 10.0, 5], "bogus": [1]},
			"runs": {"knight": {"diff": "dusk", "seed": 1928374.0, "depth": 7.0, "spare": 1.0, "hp": 0.82,
					"glimmers": {"g_edge": 2.0}, "hushings": {}, "history": ["6:nave_spikes"]},
				"witch": {"diff": "moon", "seed": 1, "depth": 3}, "runner": "junk"}, "runs_total": 9.0},
		"waxworks": {"bosses": {"tollgrave": {"dusk": {"drips": 8.0, "time": 71.3, "paid": ["clear", "bronze"]}}, "nobody": {}},
			"gauntlet": {"dusk": {"cleared": true, "time": 1011.6, "drips": 6.0}}, "tweaks": ["hotter", "quick"]},
		"trials": {"k1": {"best": 21.84, "medal": 9.0, "paid": 3.0, "tries": 17.0}, "zz": {"medal": 2}},
		"cosmetics": {"owned": ["flame:emberheart", "flame:bluefire", "trim:band"], "new": ["flame:emberheart", "glow:nope"]}}
	var c := ModesSave.clean(junk)
	_check(c["seen"] == ["door:descent"], "clean: seen keeps strings once (%s)" % [c["seen"]])
	_check(int(c["descent"]["best"]["knight"]["dusk"]["depth"]) == 14 and typeof(c["descent"]["best"]["knight"]["dusk"]["depth"]) == TYPE_INT, "clean: JSON floats come back as ints")
	_check(not (c["descent"]["best"]["knight"] as Dictionary).has("moon") and not (c["descent"]["best"] as Dictionary).has("wizard"), "clean: unknown difficulties and callings dropped")
	_check(int(c["descent"]["cleared"]["nightfall"]) == 0 and c["descent"]["milestones"]["dusk"] == [5, 10], "clean: depths clamped, milestones cast and de-duplicated")
	var runs: Dictionary = c["descent"]["runs"]
	_check(runs.has("knight") and not runs.has("witch") and not runs.has("runner"), "clean: a suspended run of the wrong shape is dropped (%s)" % [runs.keys()])
	_check(int(runs["knight"]["depth"]) == 7 and int(runs["knight"]["glimmers"]["g_edge"]) == 2, "clean: a good run is kept, cast")
	# A run's seed comes back exactly (above 2^31 too), and a fresh run's
	# "not yet" resource and flask (-1) stay -1.
	for sd in [3000000000, 4294967295, 2147483648, 99, 0]:
		var back := ModesSave.clean_run(JSON.parse_string(JSON.stringify({"diff": "dusk", "seed": sd, "depth": 3})))
		_check(int(back.get("seed", -9)) == sd and typeof(back["seed"]) == TYPE_INT, "clean_run keeps the seed %d exactly (%s)" % [sd, back.get("seed")])
	var fresh_ok := true
	for i in 50:
		var fr: Dictionary = load("res://scripts/modes/descent.gd").new_run("knight", "dusk")
		fresh_ok = fresh_ok and int(fr["seed"]) >= 0 and int(fr["seed"]) <= 0x7fffffff and int(ModesSave.clean_run(fr)["seed"]) == int(fr["seed"])
	_check(fresh_ok, "a fresh run's seed fits 31 bits and survives clean_run")
	var nr := ModesSave.clean_run(JSON.parse_string(JSON.stringify(load("res://scripts/modes/descent.gd").new_run("knight", "dusk", "normal", 1, 5))))
	_check(float(nr["res"]) == -1.0 and int(nr["flask"]) == -1 and int(nr["offered"]) == 0 and int(nr["cache"]) == 0, "clean_run keeps a fresh run's res / flask -1 and its landing marks (%s, %s)" % [nr["res"], nr["flask"]])
	_check(ModesSave.clean_run({"diff": "dusk", "seed": 1.5, "depth": 2}).is_empty() and ModesSave.clean_run({"diff": "dusk", "seed": NAN, "depth": 2}).is_empty(), "clean_run drops a run whose seed isn't a whole number")
	_check(not (c["waxworks"]["bosses"] as Dictionary).has("nobody") and int(c["waxworks"]["bosses"]["tollgrave"]["dusk"]["drips"]) == 8, "clean: Waxworks records kept, unknown bosses dropped")
	_check(int(c["trials"]["k1"]["medal"]) == 4 and not (c["trials"] as Dictionary).has("zz"), "clean: medals clamped 0-4, unknown trials dropped")
	var owned: Array = c["cosmetics"]["owned"]
	_check(owned.has("flame:emberheart") and not owned.has("flame:bluefire") and owned.has("flame:tallow") and owned.has("color:calling"), "clean: unknown cosmetics dropped, the free ones always owned (%s)" % [owned])
	_check(c["cosmetics"]["new"] == ["flame:emberheart"], "clean: new keeps known ids")
	# The block survives a save and a load (Game's _sanitize runs clean()).
	_fresh()
	var m: Dictionary = game.modes()
	m["trials"]["w1"] = {"best": 30.5, "medal": 2, "paid": 2, "tries": 3}
	m["descent"]["cleared"]["dusk"] = 12
	game.grant_cosmetic("flame:marigold")
	game.save()
	game.load_save()
	_check(float(game.modes()["trials"]["w1"]["best"]) == 30.5 and int(game.modes()["descent"]["cleared"]["dusk"]) == 12, "the modes block survives a save and a load")
	_check(game.has_cosmetic("flame:marigold"), "a granted cosmetic survives the load")
	# A save without the block loads with defaults.
	var raw := JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	if raw is Dictionary:
		(raw as Dictionary).erase("modes")
		var f := FileAccess.open(game.save_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(raw))
		f.close()
		game.load_save()
		_check((game.modes() as Dictionary).has("descent") and (game.modes()["cosmetics"]["owned"] as Array).has("flame:tallow"), "a save with no modes block loads with the defaults")
	# Unlocks.
	_fresh()
	_check(not ModesSave.hub_open(game) and not ModesSave.waxworks_open(game) and not ModesSave.descent_open(game), "a new save: the Challenges are shut")
	game.level_record("1-2", "dusk")["cleared"] = true
	_check(ModesSave.hub_open(game) and ModesSave.trial_open(game, 1) and not ModesSave.trial_open(game, 2), "1-2 cleared opens the hub and trial 1 of every calling")
	game.level_record("1-4", "nightfall")["cleared"] = true
	_check(ModesSave.waxworks_open(game) and ModesSave.trial_open(game, 2) and ModesSave.open_casts(game) == ["tollgrave"], "Tollgrave beaten (any difficulty) opens the Waxworks with his cast, and trial 2")
	_check(not ModesSave.descent_open(game), "the Descent waits for the Hush and homecoming")
	_check(ModesSave.has_news(game), "something new: the Challenges button's '!'")
	for k in ModesSave.news_keys(game):
		ModesSave.mark_seen(game, k, false)
	_check(not ModesSave.has_news(game), "every door and trial looked at: no '!'")


# ---------------------------------------------------------------- cosmetics

func _test_cosmetics() -> void:
	_check(Cosmetics.FLAME_ORDER.size() == 15 and Cosmetics.FLAMES.size() == 15, "15 flames")
	var ids := Cosmetics.all_ids()
	_check(ids.size() == 15 + 5 + 9 + 7, "36 cosmetics in all (%d)" % ids.size())
	for nid in ids:
		var src := Cosmetics.source_of(nid)
		_check(src != "" and Cosmetics.SRC_TEXT.has(src), "%s has one source, and a line for it (%s)" % [nid, src])
	# Every earned cosmetic has its own source (only the free ones share "default").
	var seen := {}
	for nid in ids:
		var src := Cosmetics.source_of(nid)
		if src == "default":
			continue
		seen[src] = int(seen.get(src, 0)) + 1
	for src in seen:
		_check(int(seen[src]) == 1, "the source %s pays one cosmetic (%d)" % [src, seen[src]])
	for id in Cosmetics.FLAMES:
		var f: Dictionary = Cosmetics.FLAMES[id]
		for k in ["out", "mid", "core"]:
			_check(Color.html_is_valid(str(f[k])), "flame %s: %s is a hex colour" % [id, k])
		_check(Cosmetics.flame_warm(id), "flame %s stays warm: its middle's hue in [330, 60], s >= 0.4, v >= 0.7 over its whole cycle" % id)
	_check(not Cosmetics.warm_ok(Color("7aa8ff")) and not Cosmetics.warm_ok(Color("b48aff")) and not Cosmetics.warm_ok(Color("7ef0c8")), "the hue test refuses blue, violet and teal")
	_check(Cosmetics.palette("tallow").is_empty(), "Tallow is the candle's own colours (an empty palette)")
	_check(float(Cosmetics.FLAMES["prismfire"]["cycle"]["mid_add"]) == 20.0, "Prismfire's middle is its outer hue +20 degrees")
	var la := float(Cosmetics.palette("lullflame", 0.0).get("alpha", 1.0))
	var lb := float(Cosmetics.palette("lullflame", 2.25).get("alpha", 1.0))
	_check(Cosmetics.animated("lullflame") and la > lb + 0.2, "Lullflame breathes slowly (alpha %.2f -> %.2f)" % [la, lb])
	_check((Cosmetics.palette("smokewick")["halo"] as Color).v < 0.3, "Smokewick has its soot rim (a dark halo)")
	var p := Cosmetics.palette("emberheart")
	_check(p.get("mid") == Color("f0502a") and p.get("out") == Color("b8200e"), "a flame's palette is its colours")
	var owned := func(n): return n == "flame:emberheart"
	var lk := Cosmetics.look_of({"look": {"flame": "coalheart", "trim": "band", "trim_color": "gold", "glow": "hush"}}, owned)
	_check(lk["flame"] == "tallow" and lk["trim"] == "" and lk["trim_color"] == "calling" and lk["glow"] == "", "look_of drops what isn't owned")
	lk = Cosmetics.look_of({"look": {"flame": "emberheart"}}, owned)
	_check(lk["flame"] == "emberheart", "look_of keeps what is")
	for c in Cosmetics.COLORS:
		var hx := str(Cosmetics.COLORS[c]["hex"])
		_check(hx == "" or Color.html_is_valid(hx), "trim colour %s is a hex colour" % c)
	for g in Cosmetics.GLOWS:
		_check(Color.html_is_valid(str(Cosmetics.GLOWS[g]["col"])) and Color.html_is_valid(str(Cosmetics.GLOWS[g]["core"])), "glow %s's colours" % g)


# ---------------------------------------------------------------- rooms

func _test_rooms() -> void:
	for b in BIOMES:
		var rooms := Rooms.load_bundle(b)
		_check(rooms.size() == 14, "%s: 14 rooms (%d)" % [b, rooms.size()])
		var kinds := {}
		var lifted := 0
		for rm in rooms:
			var k: String = rm["kind"] if rm["kind"] != "challenge" else "t%d" % int(rm["tier"])
			kinds[k] = int(kinds.get(k, 0)) + 1
			if str(rm["src"]) != "":
				lifted += 1
		_check(kinds.get("landing", 0) == 1 and kinds.get("rest", 0) == 1 and kinds.get("bell", 0) == 1 and kinds.get("warden", 0) == 1, "%s: a landing, a rest, a bell room and a warden room" % b)
		_check(kinds.get("t1", 0) == 4 and kinds.get("t2", 0) == 3 and kinds.get("t3", 0) == 3, "%s: 4 / 3 / 3 challenge rooms by tier (%s)" % [b, kinds])
		_check(lifted >= 8, "%s: at least 8 rooms lifted from the story's sections (%d)" % [b, lifted])
		for rm in rooms:
			_check_room(b, rm)


func _check_room(b: String, rm: Dictionary) -> void:
	var name := "%s/%s" % [b, rm["name"]]
	var rows: Array = rm["rows"]
	_check(rows.size() == 15, "%s: 15 rows" % name)
	var w := int(rm["width"])
	var ok := true
	for r in rows:
		ok = ok and (r as String).length() == w
	_check(ok, "%s: every row %d wide" % [name, w])
	# The legend: every glyph a tile, a mover or an entity.
	var bad := ""
	for y in rows.size():
		for ch in (rows[y] as String):
			if ch != "." and not LevelData.GLYPH_TILES.has(ch) and not LevelData.ENTITY_GLYPHS.has(ch) and ch != "-" and ch != "|" and not LevelData.RUN_GLYPHS.has(ch):
				bad += ch
	_check(bad == "", "%s: only the shared legend (%s)" % [name, bad])
	# The seam: T_OPEN on both ends (a landing needs only its right, a bell room its left).
	var seam := ["##", "##", "..", "..", "..", "..", "..", "..", "..", "..", "..", "..", "..", "##", "##"]
	var left_ok := true
	var right_ok := true
	for i in 15:
		left_ok = left_ok and (rows[i] as String).substr(0, 2) == seam[i]
		right_ok = right_ok and (rows[i] as String).substr(w - 2, 2) == seam[i]
	if rm["kind"] != "landing":
		_check(left_ok, "%s: its left seam is T_OPEN" % name)
	if rm["kind"] != "bell":
		_check(right_ok, "%s: its right seam is T_OPEN" % name)
	# Story things only where they belong.
	var allowed: String = {"landing": "PK@", "rest": "K", "bell": "E@", "warden": "D", "challenge": ""}[rm["kind"]]
	var stray := ""
	for r in rows:
		for ch in (r as String):
			if "123@PKEXD".contains(ch) and not allowed.contains(ch):
				stray += ch
	_check(stray == "", "%s: no story things out of place (%s)" % [name, stray])
	# Lights and monsters.
	var lights := 0
	var monsters := 0
	for r in rows:
		for ch in (r as String):
			if "cLN".contains(ch):
				lights += 1
			if "sbtahgkfM".contains(ch):
				monsters += 1
	_check(lights <= 5, "%s: at most 5 static lights (%d)" % [name, lights])
	_check(monsters <= 7 and monsters + (rm["deep"]["cells"] as Array).size() <= 10, "%s: at most 7 monsters, 10 with the deep overlay" % name)
	for c in rm["deep"]["cells"]:
		var x := int(c["x"])
		var y := int(c["y"])
		_check(y >= 0 and y < 15 and x >= 0 and x < w and (rows[y] as String)[x] == ".", "%s: its deep %s at %d,%d lands on air" % [name, c["g"], x, y])
	if rm["kind"] == "warden":
		_check((rm["seal"] as Array).size() == 6, "%s: six door cells (both doors)" % name)
		for c in rm["seal"]:
			_check((rows[(c as Vector2i).y] as String)[(c as Vector2i).x] == ".", "%s: door cell %s is air" % [name, c])
	# The mirror: exactly < > O Q swap, nothing else.
	var mr := Rooms.mirrored(rm)
	var same := true
	for y in 15:
		var a: String = rows[y]
		var m: String = mr["rows"][y]
		for x in w:
			var ch := a[w - 1 - x]
			var want: String = {"<": ">", ">": "<", "O": "Q", "Q": "O"}.get(ch, ch)
			same = same and m[x] == want
	_check(same, "%s: its mirror swaps exactly < > and O Q" % name)


func _room_level(rm: Dictionary, start: Vector2i) -> RefCounted:
	## A room as a level the bot can walk (a start put in; bell rooms keep their bell).
	var rows: Array = (rm["rows"] as Array).duplicate()
	var r: String = rows[start.y]
	if rm["kind"] != "landing":
		rows[start.y] = r.substr(0, start.x) + "P" + r.substr(start.x + 1)
	var text := "title: room\n---\n" + "\n".join(PackedStringArray(rows)) + "\n"
	var lv = LevelData.new()
	lv.id = "room-" + str(rm["name"])
	lv.parse(text)
	return lv


func _room_goals(lv: RefCounted, rm: Dictionary) -> Array:
	var goals: Array = []
	var w := int(rm["width"])
	if rm["kind"] == "bell":
		goals = Reach.goals_of(lv).filter(func(g): return g["what"] == "bell")
	else:
		goals.append({"what": "right seam", "p": Vector2((w - 1) * TILE, 12 * TILE), "rope": true, "rect": Rect2((w - 2) * TILE, 9 * TILE, 2 * TILE, 4 * TILE)})
	for y in lv.height:
		for x in lv.width:
			var t: int = lv.tile(x, y)
			if t == LevelData.BLOCK:
				goals.append({"what": "reliquary %d,%d" % [x, y], "p": Vector2(x * TILE + 16, (y + 1) * TILE + 4), "rope": false})
	for e in lv.entities:
		if e["kind"] == "lidlurk":
			goals.append({"what": "lidlurk %s" % e["cell"], "p": LevelData.cell_center(e["cell"]), "rope": false})
	return goals


func _prove_room(tag: String, rm: Dictionary) -> Dictionary:
	var start := Vector2i(1, 12)
	var lv := _room_level(rm, start)
	var copy = Reach.static_copy(lv)
	var s = ReachSearch.new()
	s.setup(copy, LevelData.cell_floor(lv.start), {"goals": _room_goals(lv, rm)})
	s.run()
	s.free_player()
	_check(not s.capped, "%s: the bot finishes under the cap" % tag)
	for g in s.goals:
		_check(s.found.has(g["what"]), "%s: the bot reaches the %s" % [tag, g["what"]])
	return {"states": s.seen.size()}


func _test_room_reach() -> void:
	## Every room seam to seam (a landing from its start; a bell room to its
	## bell), both ways when it mirrors (its mirror walked left to right).
	var t0 := Time.get_ticks_msec()
	var n := 0
	for b in BIOMES:
		for rm in Rooms.load_bundle(b):
			_prove_room("%s/%s" % [b, rm["name"]], rm)
			n += 1
			if bool(rm["mirror"]) and not _fast:
				_prove_room("%s/%s mirrored" % [b, rm["name"]], Rooms.mirrored(rm))
				n += 1
	print("  rooms proven: %d walks, %d ms" % [n, Time.get_ticks_msec() - t0])


# ---------------------------------------------------------------- stitching

func _descent(cls := "knight", d := "dusk", depth := 1, seed_v := 4242) -> Object:
	var m = Descent.new()
	m.cls = cls
	m.headless = true
	m.setup(Descent.new_run(cls, d, "normal", depth, seed_v))
	return m


func _test_stitching() -> void:
	_fresh()
	var avail: Array = Descent.available()
	_check(avail == ["cathedral", "tallow"], "the Descent runs with the biomes built (%s)" % [avail])
	# Depths across every kind and both biomes, first pass and Deepened.
	var per := 60 if _slow else (1 if _fast else 3)
	var depths_by_biome := {}
	for d in range(1, 61):
		var bi: Dictionary = _descent().biome_at(d)
		if not depths_by_biome.has(bi["biome"]):
			depths_by_biome[bi["biome"]] = []
		(depths_by_biome[bi["biome"]] as Array).append(d)
	for b in depths_by_biome:
		var ds: Array = depths_by_biome[b]
		var pick: Array = []
		if per >= ds.size():
			pick = ds
		else:
			# Always one warden and one echo depth among them.
			for want in ["warden", "echo", "plain"]:
				for d in ds:
					if pick.size() < per and Data.kind_at(int(d)) == want and not pick.has(d):
						pick.append(d)
						break
		for d in pick:
			_check_depth(int(d), not _fast or d == pick[0])
	# Determinism: the same seed and depth, the same text; a resume rebuilds it.
	var a = _descent()
	var b2 = _descent()
	a.run["depth"] = 13
	b2.run["depth"] = 13
	_check(a.build_depth(13)["text"] == b2.build_depth(13)["text"], "build_depth(seed, d) twice gives the same text")
	var other = _descent("knight", "dusk", 1, 777)
	_check(other.build_depth(13)["text"] != a.build_depth(13)["text"], "another seed, another depth")
	# A run saved at a landing and resumed rebuilds the same depth.
	_fresh()
	var m = _descent("knight", "dusk", 7, 99)
	var first: String = m.build_depth(7)["text"]
	var snap := ModesSave.clean_run(JSON.parse_string(JSON.stringify(m.run)))
	var r = Descent.new()
	r.cls = "knight"
	r.headless = true
	r.setup(snap)
	_check(r.build_depth(7)["text"] == first, "a run saved at its landing and resumed rebuilds the same depth")
	for sd in [3000000000, -1]:
		var mm = _descent("knight", "dusk", 7, sd)
		var txt: String = mm.build_depth(7)["text"]
		var rr = Descent.new()
		rr.cls = "knight"
		rr.headless = true
		rr.setup(ModesSave.clean_run(JSON.parse_string(JSON.stringify(mm.run))))
		_check(int(rr.run["seed"]) == int(mm.run["seed"]) and rr.build_depth(7)["text"] == txt, "seed %s: saved, loaded and resumed, the same depth (%d)" % [sd, int(mm.run["seed"])])
	# No room repeats within a depth; the history keeps the last two depths' out.
	var hm = _descent("knight", "dusk", 1, 31)
	var ok := true
	for d in range(1, 25):
		hm.run["depth"] = d
		var bd: Dictionary = hm.build_depth(d)
		var names: Array = []
		for nm in bd["rooms"]:
			names.append(str(nm).get_slice(":", 1).trim_suffix("~"))
		var uniq := {}
		for nm in names:
			uniq[nm] = true
		ok = ok and uniq.size() == names.size()
		var hist: Array = []
		for h in hm.run["history"]:
			if int(str(h).get_slice(":", 0)) >= d - 1:
				hist.append(h)
		hist.append_array(bd["rooms"])
		hm.run["history"] = hist
	_check(ok, "no room twice in one depth")
	# Every depth's length in the band (spec: 170-265 tiles), over seeds,
	# kinds and both biomes, first pass and Deepened.
	var widths := []
	var band_ok := true
	for sd in [3, 17, 29, 41, 58, 77]:
		var bm = _descent("knight", "dusk", 1, sd)
		for d in range(1, 41):
			bm.run["depth"] = d
			var bd: Dictionary = bm.build_depth(d)
			var w := (Rooms.rows_of_level(bd["text"])[0] as String).length()
			widths.append(w)
			if w < Data.DEPTH_MIN or w > Data.DEPTH_MAX:
				band_ok = false
				print("  depth %d seed %d (%s): %d tiles" % [d, sd, bd["kind"], w])
	widths.sort()
	print("  stitched depths: %d-%d tiles (median %d)" % [widths[0], widths[widths.size() - 1], widths[widths.size() / 2]])
	_check(band_ok, "240 stitched depths are all %d-%d tiles (%d-%d)" % [Data.DEPTH_MIN, Data.DEPTH_MAX, widths[0], widths[widths.size() - 1]])


func _check_depth(d: int, prove: bool) -> void:
	var m = _descent("knight", "dusk", d, 1000 + d)
	m.run["depth"] = d
	var bd: Dictionary = m.build_depth(d)
	var lv = Mode.parse_level(bd["text"], "descent-%d" % d, int(bd["world"]))
	var tag := "depth %d (%s, %s)" % [d, bd["biome"], bd["kind"]]
	_check(lv.errors.is_empty(), "%s parses (%s)" % [tag, lv.errors])
	_check(lv.width >= Data.DEPTH_MIN and lv.width <= Data.DEPTH_MAX, "%s: %d-%d tiles, 1.5-3 minutes (%d)" % [tag, Data.DEPTH_MIN, Data.DEPTH_MAX, lv.width])
	_check(int(lv.area_abs) == Data.area_at(d, Combat.area_level(31, "dusk")), "%s: area_abs is the ramp's (%d)" % [tag, lv.area_abs])
	var signs: int = lv.count("sign")
	_check(lv.hints.size() == signs and not lv.hints.has(""), "%s: every sign has its hint (%d signs)" % [tag, signs])
	if bd["kind"] == "warden":
		_check(not lv.dread.is_empty() and (bd["seal"] as Array).size() == 6, "%s: a Deepwarden (dread:) and its six door cells" % tag)
		for sc in bd["seal"]:
			var c := Vector2i(int(str(sc).get_slice(",", 0)), int(str(sc).get_slice(",", 1)))
			_check(lv.tile(c.x, c.y) == LevelData.AIR, "%s: door cell %s is air" % [tag, c])
		var want := Data.WARDEN_OMENS + (1 if d >= Data.OMEN_FROM else 0)
		_check((lv.dread.get("omens", []) as Array).size() == want, "%s: the Deepwarden has %d Omens on Dusk (2, 3 from depth 21)" % [tag, want])
	if bd["kind"] == "echo":
		_check(lv.boss != "" and lv.count("boss") == 1, "%s: the biome boss's arena" % tag)
	if prove:
		var copy = Reach.static_copy(lv)
		var s = ReachSearch.new()
		var goals := Reach.goals_of(lv).filter(func(g): return g["what"] in ["bell", "boss arena"])
		s.setup(copy, LevelData.cell_floor(lv.start), {"goals": goals})
		s.run()
		s.free_player()
		_check(not s.capped, "%s: the bot finishes under the cap (%d states)" % [tag, s.seen.size()])
		for g in goals:
			_check(s.found.has(g["what"]), "%s: the bot reaches the %s" % [tag, g["what"]])


# ---------------------------------------------------------------- the ramp

func _test_ramp() -> void:
	var a := Combat.area_level(31, "dusk")
	var table := {1: 27, 5: 31, 10: 36, 15: 38, 20: 41, 30: 46, 40: 51, 50: 56, 58: 60, 70: 60}
	for d in table:
		_check(Data.area_at(int(d), a) == int(table[d]), "the ramp on Dusk: depth %d is area %d (%d)" % [d, table[d], Data.area_at(int(d), a)])
	_check(Data.area_at(1, Combat.area_level(31, "nightfall")) == 36 and Data.area_at(1, Combat.area_level(31, "witching")) == 41, "depth 1 is area 36 on Nightfall, 41 on Witching")
	_check(int(Mode.a_end("dusk")) == 31 and int(Mode.a_end("nightfall")) == 40 and int(Mode.a_end("witching")) == 45, "A_END is read at run time: 31 / 40 / 45")
	_check(Data.rooms_at(1) == 3 and Data.rooms_at(6) == 4 and Data.rooms_at(16) == 5, "3 / 4 / 5 challenge rooms")
	_check(Data.kind_at(3) == "warden" and Data.kind_at(5) == "echo" and Data.kind_at(7) == "plain", "d mod 5: 3 warden, 0 echo")
	# Elites.
	for df in ["dusk", "nightfall", "witching"]:
		var base: Dictionary = Combat.elite_rules(df, 1)
		var r1 := Data.elite_rules(base, 1)
		var r20 := Data.elite_rules(base, 20)
		var r40 := Data.elite_rules(base, 40)
		_check(absf(float(r1["anoint"]) - minf(float(base["anoint"]) + 0.006, 0.30)) < 1e-6 and float(r40["anoint"]) <= 0.30 + 1e-6, "%s: Anointed +0.6%% a depth, at most 30%%" % df)
		_check(int(r20["max_anoint"]) == int(base["max_anoint"]) + 2 and int(r40["max_anoint"]) <= 6, "%s: one more Anointed each 8 depths, at most 6" % df)
		_check(int(r20["omens"]) == int(base["omens"]) and int(r40["omens"]) == mini(int(base["omens"]) + 1, 3), "%s: +1 Omen from depth 21, at most 3" % df)
	# The dark.
	_check(Data.dark_at(10) == 1.0 and absf(Data.dark_at(20) - 0.96) < 1e-6 and absf(Data.dark_at(48) - 0.85) < 1e-6 and Data.dark_at(80) == 0.85, "the deepening dark: 1.0 to depth 10, its floor 0.85 at depth 48")
	# Tiers.
	_check(Data.tier_weights(3, 0) == [70, 30, 0] and Data.tier_weights(25, 0) == [0, 30, 70] and Data.tier_weights(3, 1) == [0, 20, 80], "the tier weights")
	# Loot.
	var l := Data.loot_at(30, 2, 1)
	_check(absf(float(l["drop"]) - 1.6) < 1e-6 and absf(float(l["legend"]) - 1.9 * 1.5625) < 1e-4 and absf(float(l["rare"]) - 1.3225) < 1e-4, "loot(): drops x(1 + 0.02 d), Legendaries x(1 + 0.03 d) x1.25 a Moth-luck")
	# Hushings: all eight before any repeats.
	var m := _descent("knight", "dusk", 1, 5)
	for i in 8:
		m._add_hushing(11 + 5 * i)
	var hs: Dictionary = m.run["hushings"]
	_check(hs.size() == 8 and hs.values().all(func(v): return int(v) == 1), "eight Hushings before any repeats")
	m._add_hushing(51)
	_check(m._hush_total() == 9 and hs.size() == 8, "the ninth deepens one")
	var m2 := _descent("knight", "dusk", 26, 5)
	m2._roll_hushings_to(26)
	_check(m2._hush_total() == 4, "a start at depth 26 carries the four Hushings due (11, 16, 21, 26): %d" % m2._hush_total())
	_check(Data.hush_due(11) and Data.hush_due(16) and not Data.hush_due(12) and not Data.hush_due(10), "a Hushing at 11, 16, 21...")


# ---------------------------------------------------------------- the Descent in a World

func _mode_world(mode: Object, lv: RefCounted) -> Node2D:
	## A mode's World, headless, wired as main.play_custom wires it.
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.mode = mode
	mode.world = w
	w.finished.connect(func(res): mode.finished(res))
	root.add_child(w)
	return w


func _ticks(w: Node2D, n: int, pad := {}) -> void:
	w.test_pad = pad
	for i in n:
		w._read_pad()
		w.tick(DT)


func _test_descent_world() -> void:
	_fresh()
	var m = _descent("knight", "dusk", 3, 77)
	var lv: RefCounted = m.level_data()
	var w := _mode_world(m, lv)
	await process_frame
	_check(w.diff == "dusk" and w.area == 29, "a Descent depth plays on the run's difficulty at its area (%d)" % w.area)
	_check(int(w.world_n) == 1, "its rooms' world (%d)" % w.world_n)
	_check((w.dims() as Dictionary).has("descent:dark"), "the deepening dark goes through world.dim")
	_check(not w.allows("record") and w.allows("xp") and w.allows("loot"), "no records; XP and loot as a level")
	# The landing's altar offers two Glimmers.
	var landing_altar: Dictionary = {}
	for a in w.altars:
		if a["cell"].x <= int(m.built["landing_x1"]):
			landing_altar = a
	_check(not landing_altar.is_empty(), "the landing has its altar")
	var p: Node2D = w.player
	p.reset_at(landing_altar["pos"])
	_ticks(w, 4)
	_check(m.offers.size() == 2, "the landing's first lighting offers two Glimmers (%s)" % [m.offers])
	var gid: String = m.offers[0]
	m.choose_glimmer(0)
	_check(m.glimmer(gid) == 1 and m.offers.is_empty(), "a Glimmer taken lasts the run")
	var snap: Dictionary = game.modes()["descent"]["runs"]["knight"]
	_check(int(snap["depth"]) == 3 and int((snap["glimmers"] as Dictionary).get(gid, 0)) == 1, "the landing saves the run (an app kill resumes here)")
	# Glimmers through stats_filter.
	var mhp: float = p.max_hp
	m.run["glimmers"]["g_wax"] = 2
	w.apply_hero()
	_check(absf(p.max_hp - mhp * 1.16 / (1.08 if gid == "g_wax" else 1.0)) < 1.0 or p.max_hp > mhp, "Thick Wax x2: +16%% life (%.0f -> %.0f)" % [mhp, p.max_hp])
	# The warden room seals, and opens when its warden is out.
	var sp: Dictionary = m.built["warden_span"]
	var dr: Node2D = m._dread(w)
	_check(dr != null and dr.tier == "dread", "the Deepwarden is the depth's Dread")
	p.reset_at(LevelData.cell_floor(Vector2i(int(sp["x0"]) + 8, 12)))
	_ticks(w, 2)
	var door: Vector2i = m._seal_cells()[0]
	_check(m._sealed and w.level.tile(door.x, door.y) == LevelData.STONE, "into the warden room: both doors seal")
	# A snuff unseals them and puts the warden back at full life.
	dr.hp = dr.max_hp * 0.3
	var spare0 := int(m.run["spare"])
	p.invuln = 0.0
	p.take_damage(99999.0, p.position.x + 5.0)
	_check(int(m.run["spare"]) == spare0 - 1, "a snuff spends a Spare Wick (%d -> %d)" % [spare0, m.run["spare"]])
	_ticks(w, int(2.0 / DT))
	_check(w.state == "play" and not m._sealed and w.level.tile(door.x, door.y) == LevelData.AIR, "the relight opens the warden room")
	_check(absf(dr.hp - dr.max_hp) < 0.01, "and the Deepwarden is back at full life")
	p.reset_at(LevelData.cell_floor(Vector2i(int(sp["x0"]) + 8, 12)))
	_ticks(w, 2)
	_check(m._sealed, "sealed again on the way back in")
	dr.hp = 0.0
	dr.alive = false
	_ticks(w, 2)
	_check(not m._sealed and w.level.tile(door.x, door.y) == LevelData.AIR, "the Deepwarden put out: the doors open")
	# The bell: the depth is cleared, the record kept, the next depth follows.
	var xp0: int = int(game.hero()["xp"])
	w._ring(w.bells[0])
	_ticks(w, int(2.2 / DT))
	_check(int(ModesSave.descent_best(game, "knight", "dusk").get("depth", 0)) == 3, "the bell: depth 3 is the knight's best on Dusk")
	_check(int(game.hero()["xp"]) - xp0 >= Progression.event_xp("depth", w.area), "a cleared depth pays its depth XP, 30 x E(A) (%d)" % (int(game.hero()["xp"]) - xp0))
	_check(int(m.run["depth"]) == 4 and m.next_level != null, "and the next depth is built")
	_check((m.run["history"] as Array).size() > 0, "the rooms go into the history")
	w.queue_free()
	await process_frame
	# The echo depth: its boss at x0.8 of its rush life, the usual drops, no level record.
	_fresh()
	var e = _descent("knight", "dusk", 5, 8)
	var elv: RefCounted = e.level_data()
	var ew := _mode_world(e, elv)
	await process_frame
	var boss: Node2D = ew.boss
	_check(boss != null and str(boss.boss_id) == "tollgrave", "depth 5: Old Tollgrave's dream")
	var ref: float = _boss_life("tollgrave", ew.area)
	if boss != null and not boss.has_method("configure"):
		_check(absf(boss.max_hp - ref * float(Mode.RUSH_HP["tollgrave"]) * Data.ECHO_HP) < 1.0, "the echo's life is x0.8 of its rush life (%.0f vs %.0f)" % [boss.max_hp, ref * 1.5 * 0.8])
	var n0: int = ew.pickups.size()
	boss.hp = 0.0
	boss.alive = false
	_ticks(ew, 2)
	_check(ew.pickups.filter(func(pk): return pk["kind"] == "item").size() >= 3, "the echo pays the usual boss drops")
	ew.boss_defeated(boss, boss.position)
	_check(not (game.data["levels"]["dusk"] as Dictionary).has("descent-5"), "and makes no level record in the save")
	ew.queue_free()
	await process_frame


func _boss_life(kind: String, area: int) -> float:
	## A boss's own life at an area on Dusk (no mode).
	var ek = load("res://scripts/enemy_kinds.gd")
	var b: Node2D = ek.make(kind)
	b.setup_stats(area, "dusk", "normal", 1)
	var hp: float = b.max_hp
	b.free()
	return hp


func _test_descent_rules() -> void:
	# Spare Wicks at the start.
	_check(int(Descent.new_run("knight", "dusk")["spare"]) == 2 and int(Descent.new_run("knight", "nightfall")["spare"]) == 1 and int(Descent.new_run("knight", "witching")["spare"]) == 0, "Spare Wicks 2 / 1 / 0")
	# The last snuff ends the run: XP, items and banked embers kept, carried gone.
	_fresh()
	var m = _descent("knight", "dusk", 2, 13)
	m.run["spare"] = 0
	var w := _mode_world(m, m.level_data())
	await process_frame
	game.add_embers(100)
	var purse: int = game.embers()
	w.embers_carried = 40
	var xp0: int = int(game.hero()["xp"])
	w.gain_xp(50, w.player.position)
	var p: Node2D = w.player
	p.invuln = 0.0
	p.take_damage(99999.0, p.position.x + 5.0)
	_check(m.ended == "snuffed", "with no Spare Wick the snuff ends the run")
	var fin := [null]
	w.finished.connect(func(r): fin[0] = r)
	_ticks(w, int(2.0 / DT))
	_check(fin[0] != null and not fin[0]["cleared"], "the World finishes, not cleared")
	_check(int(game.hero()["xp"]) - xp0 == 50 and game.embers() == purse, "XP and banked embers are kept; carried embers are lost (%d)" % game.embers())
	_check(not (game.modes()["descent"]["runs"] as Dictionary).has("knight"), "the run is let go")
	_check(int(m.results.get("depth", -1)) == 1, "the results: depth 1 cleared")
	w.queue_free()
	await process_frame
	# Rest here (in the landing) is free; Leave (past it) costs a Spare Wick.
	_fresh()
	m = _descent("knight", "dusk", 4, 14)
	w = _mode_world(m, m.level_data())
	await process_frame
	var items: Array = m.pause_items()
	_check(items.size() == 2 and str(items[0]["label"]) == "Rest here" and bool(items[1]["confirm"]), "the landing's pause: Rest here, End run (two taps)")
	m.rest_here()
	var run: Dictionary = game.modes()["descent"]["runs"]["knight"]
	_check(int(run["spare"]) == 2 and int(run["depth"]) == 4 and m.ended == "suspended", "Rest here suspends at the landing, free")
	w.queue_free()
	await process_frame
	var r = Descent.resume(null, "knight")
	_check(r != null and int(r.run["depth"]) == 4 and r.next_level != null, "a suspended run resumes at its landing")
	var w2 := _mode_world(r, r.level_data())
	await process_frame
	w2.player.reset_at(LevelData.cell_floor(Vector2i(int(r.built["landing_x1"]) + 6, 12)))
	_ticks(w2, 2)
	items = r.pause_items()
	_check(items.size() == 1 and str(items[0]["label"]).contains("Spare Wick") and bool(items[0]["confirm"]), "past the landing: Leave the Descent (costs a Spare Wick)")
	r.leave()
	run = game.modes()["descent"]["runs"]["knight"]
	_check(int(run["spare"]) == 1 and int(run["depth"]) == 4, "Leave spends a Spare Wick and suspends at this depth's landing")
	w2.queue_free()
	await process_frame
	# Milestones pay once per difficulty, the cosmetic once in all.
	_fresh()
	m = _descent("knight", "dusk", 5, 15)
	var e0: int = game.embers()
	m._pay_milestone(game, 5)
	_check(game.embers() - e0 == 150 and game.has_cosmetic("flame:emberheart"), "depth 5 on Dusk: 150 embers and Emberheart")
	m._pay_milestone(game, 5)
	_check(game.embers() - e0 == 150, "paid once per difficulty")
	var n2 = _descent("witch", "nightfall", 5, 15)
	n2._pay_milestone(game, 5)
	_check(game.embers() - e0 == 150 + 300 and (game.modes()["cosmetics"]["owned"] as Array).count("flame:emberheart") == 1, "again on Nightfall (x2 embers), the flame not twice")
	var sat0: int = (game.hero()["satchel"] as Array).size()
	m._pay_milestone(game, 10)
	_check((game.hero()["satchel"] as Array).size() == sat0 + 1 and ((game.hero()["satchel"] as Array)[-1] as Dictionary).get("rarity", "") == "legendary", "depth 10: a Legendary into the satchel")
	# The tell floor: Quickened x2 on Witching, still 0.30 s at the least.
	_fresh()
	m = _descent("knight", "witching", 21, 16)
	m.run["hushings"] = {"quick": 2}
	w = _mode_world(m, m.level_data())
	await process_frame
	_check(absf(w.tells_mult() - float(Combat.diff("witching")["tells"]) * 0.93 * 0.93) < 1e-6, "Quickened x2: tells x0.93 twice, over Witching's")
	var el = null
	for en in w.enemies:
		if en.has_method("tell"):
			el = en
			break
	if el != null:
		_check(float(el.tell(0.35)) >= 0.30 - 1e-6, "the 0.30 s tell floor holds (%.3f)" % float(el.tell(0.35)))
	w.queue_free()
	await process_frame


# ---------------------------------------------------------------- Glimmers, landings, the pause fallback

func _test_glimmers() -> void:
	## Every stat Glimmer changes the number the fight actually reads.
	_fresh()
	var m = _descent("knight", "dusk", 2, 21)
	var w := _mode_world(m, m.level_data())
	await process_frame
	var p: Node2D = w.player
	m.run["glimmers"] = {}
	w.apply_hero()
	var b: Dictionary = p.stats.duplicate(true)
	var near := func(a: float, x: float, tol: float) -> bool: return absf(a - x) <= tol * maxf(absf(x), 1e-6)
	for gid in ["g_wax", "g_edge", "g_eye", "g_bright", "g_ward", "g_heels", "g_well"]:
		m.run["glimmers"] = {gid: 1}
		w.apply_hero()
		var st: Dictionary = p.stats
		var ok := false
		var said := ""
		match gid:
			"g_wax":
				ok = near.call(float(st["max_hp"]), float(b["max_hp"]) * 1.08, 0.02)
				said = "max life %.0f -> %.0f" % [b["max_hp"], st["max_hp"]]
			"g_edge":
				var r1 := RandomNumberGenerator.new()
				r1.seed = 5
				var r2 := RandomNumberGenerator.new()
				r2.seed = 5
				var a0: float = Combat.roll(b, 50.0, r1)["amount"]
				var a1: float = Combat.roll(st, 50.0, r2)["amount"]
				ok = near.call(a1 / a0, (1.0 + float(b["dmg_pct"]) + 0.08) / (1.0 + float(b["dmg_pct"])), 0.02)
				said = "a hit %.0f -> %.0f" % [a0, a1]
			"g_eye":
				ok = near.call(float(st["crit"]), float(b["crit"]) + 0.03, 0.001) and float(b["crit"]) + 0.03 <= Combat.CRIT_CAP
				said = "crit %.2f -> %.2f" % [b["crit"], st["crit"]]
			"g_bright":
				var l0 := Combat.light_radius(0.5, b, "dusk")
				var l1 := Combat.light_radius(0.5, st, "dusk")
				ok = l1 > l0 or l0 >= Combat.LIGHT_MAX
				said = "light %.0f -> %.0f" % [l0, l1]
			"g_ward":
				ok = near.call(float(st["dr"]), minf(float(b["dr"]) + 0.03, Combat.DR_CAP), 0.001)
				said = "DR %.2f -> %.2f" % [b["dr"], st["dr"]]
			"g_heels":
				var r1 := RandomNumberGenerator.new()
				r1.seed = 9
				var r2 := RandomNumberGenerator.new()
				r2.seed = 9
				var s0: float = Combat.stomp_damage(b, r1)["amount"]
				var s1: float = Combat.stomp_damage(st, r2)["amount"]
				ok = near.call(s1 / s0, (1.0 + float(b["stomp_pct"]) + 0.3) / (1.0 + float(b["stomp_pct"])), 0.05)
				said = "a stomp %.0f -> %.0f" % [s0, s1]
			"g_well":
				ok = near.call(float(st["res_regen"]), float(b["res_regen"]) * 1.15, 0.02) or float(b["res_regen"]) == 0.0
				said = "regen %.2f -> %.2f" % [b["res_regen"], st["res_regen"]]
		_check(ok, "%s (%s): what the fight reads changes (%s)" % [gid, Data.GLIMMERS[gid]["name"], said])
	# Moth-luck and Ember-sense through loot(); Deep Flask and the hero's own flask.
	m.run["glimmers"] = {"g_luck": 1, "g_embers": 1}
	_check(absf(float(m.loot()["legend"]) / float(Data.loot_at(2)["legend"]) - 1.25) < 1e-4 and absf(float(m.loot()["embers"]) / float(Data.loot_at(2)["embers"]) - 1.25) < 1e-4, "Moth-luck and Ember-sense reach the World's loot()")
	w.queue_free()
	await process_frame
	_fresh()
	game.grant_draught("second")
	game.grant_draught("rich")
	m = _descent("knight", "dusk", 2, 22)
	w = _mode_world(m, m.level_data())
	await process_frame
	p = w.player
	_check(int(w.flask_charges) == int(game.flask_charges("dusk")) and int(w.flask_charges) == 2, "the Descent's flask is the hero's own: the Second Draught counts (%d)" % int(w.flask_charges))
	m.run["glimmers"] = {"g_flask": 1}
	w.flask_charges = m._flask_cap()
	p.invuln = 0.0
	p.take_damage(99999.0, p.position.x + 5.0)
	_ticks(w, int(2.0 / DT))
	_check(w.state == "play" and int(w.flask_charges) == 3, "a Spare Wick's relight keeps Deep Flask: 3 charges (%d)" % int(w.flask_charges))
	# The Rich Draught's heal (50% on Dusk against DIFF's 40%).
	p.hp = p.max_hp * 0.2
	p.invuln = 99.0
	_ticks(w, 1, {"flask": true})
	_ticks(w, int(0.7 / DT))
	_check(absf(p.life_frac() - (0.2 + float(game.flask_heal("dusk")))) < 0.03, "a drink pours the hero's own draught (the Rich Draught: %.2f life)" % p.life_frac())
	# Charges never pass 3: no Deep Flask on offer at the cap.
	var pool_has := false
	for d in range(2, 40):
		if m.glimmer_offers(d).has("g_flask"):
			pool_has = true
	m.run["glimmers"] = {}
	var offered_before := false
	for d in range(2, 40):
		if m.glimmer_offers(d).has("g_flask"):
			offered_before = true
	_check(not pool_has and offered_before, "Deep Flask is offered below the cap, never at it")
	w.queue_free()
	await process_frame


func _landing_altar(m: Object, w: Node) -> Dictionary:
	for a in w.altars:
		if a["cell"].x <= int(m.built["landing_x1"]):
			return a
	return {}


func _landing_relic(m: Object, w: Node) -> Vector2i:
	for cell in w.blocks:
		if (cell as Vector2i).x <= int(m.built["landing_x1"]) and str(w.blocks[cell]["contents"]) == "relic":
			return cell
	return Vector2i(-1, -1)


func _test_landing_once() -> void:
	## A landing's Glimmers, Walk on and gold reliquary pay once a depth,
	## however its landing is rebuilt (Rest here and Resume, an app kill's
	## resume, a restart there).
	_fresh()
	var m = _descent("knight", "dusk", 2, 23)
	var w := _mode_world(m, m.level_data())
	await process_frame
	var p: Node2D = w.player
	p.reset_at(_landing_altar(m, w)["pos"])
	_ticks(w, 4)
	_check(m.offers.size() == 2, "the landing offers its Glimmers")
	var e0: int = game.embers()
	m.choose_glimmer(-1)
	_check(game.embers() - e0 == 20 and int(m.run["offered"]) == 2, "Walk on pays 20 embers, once (%d)" % (game.embers() - e0))
	var cell := _landing_relic(m, w)
	_check(cell.x >= 0, "depth 2's landing has its gold reliquary")
	if cell.x >= 0:
		w._open_block(cell)
		_ticks(w, 2)
	_check(int(m.run["cache"]) == 2, "opening it is kept in the run")
	m.rest_here()
	w.queue_free()
	await process_frame
	var e1: int = game.embers()
	for loop in 2:
		var r = Descent.resume(null, "knight")
		var w2 := _mode_world(r, r.level_data())
		await process_frame
		_check(_landing_relic(r, w2).x < 0, "resumed (%d): the landing's reliquary stands spent" % loop)
		w2.player.reset_at(_landing_altar(r, w2)["pos"])
		_ticks(w2, 4)
		_check(r.offers.is_empty(), "resumed (%d): the altar offers no Glimmers again" % loop)
		# A restart at the landing (free) rebuilds it the same way.
		r.restart()
		var w3 := _mode_world(r, r.next_level)
		await process_frame
		w3.player.reset_at(_landing_altar(r, w3)["pos"])
		_ticks(w3, 4)
		_check(r.offers.is_empty() and _landing_relic(r, w3).x < 0, "restarted at the landing (%d): no second offer, no second reliquary" % loop)
		r.rest_here()
		w2.queue_free()
		w3.queue_free()
		await process_frame
	_check(game.embers() == e1, "no embers from the loops (%d)" % (game.embers() - e1))
	# A Glimmer taken is kept: a resume doesn't offer another at the same landing.
	_fresh()
	m = _descent("knight", "dusk", 3, 24)
	w = _mode_world(m, m.level_data())
	await process_frame
	w.player.reset_at(_landing_altar(m, w)["pos"])
	_ticks(w, 4)
	var gid: String = m.offers[0]
	m.choose_glimmer(0)
	m.rest_here()
	w.queue_free()
	await process_frame
	var r2 = Descent.resume(null, "knight")
	var w4 := _mode_world(r2, r2.level_data())
	await process_frame
	w4.player.reset_at(_landing_altar(r2, w4)["pos"])
	_ticks(w4, 4)
	_check(r2.offers.is_empty() and r2.glimmer(gid) == 1, "a Glimmer taken, Rest here, Resume: still one, and no new offer")
	w4.queue_free()
	await process_frame


func _test_pause_fallback() -> void:
	## Until the pause menu shows pause_items, its own Restart and Leave call
	## the mode: past the landing what costs a Spare Wick or the run asks
	## twice, and a restart with no Spare Wick is refused.
	_fresh()
	var m = _descent("knight", "dusk", 4, 14)
	var w := _mode_world(m, m.level_data())
	await process_frame
	w.player.reset_at(LevelData.cell_floor(Vector2i(int(m.built["landing_x1"]) + 6, 12)))
	_ticks(w, 2)
	var sp0 := int(m.run["spare"])
	w.paused = true
	m.restart()
	_check(int(m.run["spare"]) == sp0 and m.ended == "" and not w.paused, "Restart past the landing, once: nothing spent, back to the level")
	m.restart()
	_check(int(m.run["spare"]) == sp0 - 1 and int(m.run["depth"]) == 4, "twice: a Spare Wick for this depth again from its landing")
	m._in_rooms = true
	m.run["spare"] = 0
	m.restart()
	m.restart()
	_check(m.ended == "" and int(m.run["spare"]) == 0, "with no Spare Wick, no restart (and the run goes on)")
	m.quit()
	_check(m.ended == "", "Leave with no Spare Wick, once: the run goes on")
	m.quit()
	_check(m.ended == "ended", "twice: the run ends")
	w.queue_free()
	await process_frame
	# The Gauntlet: no free restart; leaving asks twice.
	_fresh()
	var gm = Waxworks.new()
	gm.headless = true
	gm.setup("", "dusk", [])
	gm.gauntlet = true
	gm.order = ["tollgrave", "snuffer"]
	gm.boss = "tollgrave"
	gm.spare = 1
	var gw := _mode_world(gm, gm.level_data())
	await process_frame
	gm.index = 1
	gm.boss = "snuffer"
	gw.player.hp = gw.player.max_hp * 0.4
	gm.restart()
	_check(gm.index == 1 and gm.over == "" and gm.spare == 1, "the Gauntlet's Restart is refused (no free retry)")
	gm.quit()
	_check(gm.over == "", "Leave the Gauntlet, once: it goes on")
	gm.quit()
	_check(gm.over == "left", "twice: it's left")
	gw.queue_free()
	await process_frame


func _test_rooms_overlay() -> void:
	## A later world's bundle stitches whole: a room's Z| row (gusts and
	## Hush columns) and its cog / weight phases move with it, mirror with it
	## (( ) and [ ] swap) and become the depth's headers.
	var text := """=== lab_gusts
kind: challenge
tier: 1
tags: platform
mirror: yes
width: 12
cog_phase: 3=0.25
weight_phase: 8=0.5
---
############
############
............
............
............
............
............
............
............
............
............
............
............
############
############
Z|..((]]..;;.
"""
	var rooms := Rooms.parse_bundle(text)
	_check(rooms.size() == 1 and str(rooms[0]["overlay"]) == "..((]]..;;..", "a bundle room keeps its overlay row (%s)" % [rooms[0].get("overlay")])
	var rm: Dictionary = rooms[0]
	_check((rm["cog_phase"] as Dictionary).get(3) == 0.25 and (rm["weight_phase"] as Dictionary).get(8) == 0.5, "and its cog and weight phases")
	var mr := Rooms.mirrored(rm)
	_check(str(mr["overlay"]) == "..;;..[[))..", "mirrored: the overlay reversed, ( ) and [ ] swapped (%s)" % mr["overlay"])
	_check((mr["cog_phase"] as Dictionary).get(8) == 0.25 and (mr["weight_phase"] as Dictionary).get(3) == 0.5, "mirrored: the phases move with their hubs")
	var plain: Dictionary = rm.duplicate(true)
	plain["overlay"] = ""
	plain["cog_phase"] = {}
	plain["weight_phase"] = {}
	var j := Rooms.join([plain, rm, mr])
	var ov: String = j["overlay"]
	_check(ov.length() == 36 and Rooms.gusts_header(ov) == "14-15:L:A, 16-17:R:B, 30-31:L:B, 32-33:R:A" and Rooms.hush_header(ov) == "20-21, 26-27", "joined: gusts and Hush columns at their absolute x (%s | %s)" % [Rooms.gusts_header(ov), Rooms.hush_header(ov)])
	_check(Rooms.phases_header(j["cog_phase"]) == "15=0.25, 32=0.25" and Rooms.phases_header(j["weight_phase"]) == "20=0.5, 27=0.5", "joined: the phases at their absolute x (%s | %s)" % [Rooms.phases_header(j["cog_phase"]), Rooms.phases_header(j["weight_phase"])])
	var lt := Rooms.level_text([["title", "Lab"], ["gusts", Rooms.gusts_header(ov)], ["hush", Rooms.hush_header(ov)],
			["cog_phase", Rooms.phases_header(j["cog_phase"])]], j["rows"])
	var lv = Mode.parse_level(lt, "descent-lab", 5)
	_check(lv.gusts.size() == 4 and int(lv.gusts[0]["x0"]) == 14 and int(lv.gusts[0]["dir"]) == -1 and str(lv.gusts[1]["phase"]) == "B" and lv.hush_cols.size() == 2 and float(lv.cog_phase.get(32, 0.0)) == 0.25, "LevelData reads the stitched headers")


# ---------------------------------------------------------------- the Waxworks

func _test_rush_files() -> void:
	# v2's two casts always; the new bosses' once their level and arena are
	# built (the wave-2 merge: Gravebough's and the Tinker's from 3-4 / 4-4).
	var casts := ["tollgrave", "snuffer"]
	for b in ModesSave.built_casts():
		if not casts.has(b):
			casts.append(b)
	for b in casts:
		var p := "res://levels/rush/%s.txt" % b
		_check(FileAccess.file_exists(p), "rush/%s.txt is built" % b)
		if not FileAccess.file_exists(p):
			continue
		var text := FileAccess.get_file_as_string(p)
		var lv = Mode.parse_level(text, "rush-" + b, 1)
		_check(lv.errors.is_empty() and lv.boss == b and bool(lv.rush), "rush/%s parses, its boss and rush: 1" % b)
		_check(int(Mode.header_value(text, "cut")) == 12 and Mode.header_value(text, "src") != "" and int(Mode.header_value(text, "clock")) > 0, "rush/%s: cut, src and clock" % b)
		_check(lv.count("sigil") == 0 and lv.count("sign") == 1, "rush/%s: no sigils, one sign (the cellar's)" % b)
		var copy = Reach.static_copy(lv)
		var s = ReachSearch.new()
		s.setup(copy, LevelData.cell_floor(lv.start), {"goals": Reach.goals_of(lv)})
		s.run()
		s.free_player()
		_check(s.found.has("boss arena"), "rush/%s: the bot reaches the arena from the cellar" % b)
	# Every boss level in the build has its arena.
	for info in game.LEVELS:
		var lv = LevelData.load_file(str(info["path"]))
		if lv.boss != "":
			_check(FileAccess.file_exists("res://levels/rush/%s.txt" % lv.boss), "%s's boss has a Waxworks arena" % info["id"])
	# The new casts fight in the Waxworks: the boss configured for the rush
	# (its RUSH_K on its life), awake once Waxby is in, and it takes a blow.
	for b in ["rootmother", "tinker", "saint", "hush"]:
		if not ModesSave.cast_built(b):
			continue
		_fresh()
		var m = Waxworks.new()
		m.headless = true
		m.setup(b, "dusk", [])
		var w := _mode_world(m, m.level_data())
		await process_frame
		var bo: Node2D = w.boss
		_check(bo != null and str(bo.get("boss_id")) == b and bool(bo.get("rush")), "the %s cast: its boss, configured for the rush" % b)
		if bo != null:
			# (A floor under him: the Saint's nave is platforms over the void.)
			var sx := float(bo.arena_left) + 150.0
			var sy: float = float(bo.get("floor_y")) if bo.get("floor_y") != null else -1.0
			if sy < 0.0:
				for ty in range(2, w.level.height):
					if LevelData.is_solid(w.level.tile(floori(sx / TILE), ty)):
						sy = ty * TILE
						break
			w.player.reset_at(Vector2(sx, sy))
			for i in 240:
				w.player.invuln = 5.0
				_ticks(w, 1)
			_check(str(bo.get("state")) != "sleep", "the %s cast wakes as Waxby comes in" % b)
			if b in ["saint", "hush"]:
				# (Blows land on these two only in their windows, test_bosses4's;
				# here, the rush's life: her own x BR's RUSH_HP, the mode's x1.)
				var want := _boss_life(b, w.area) * float(load("res://scripts/boss_mods.gd").RUSH_HP[b])
				_check(absf(float(bo.max_hp) - want) < 1.0 and bool(bo.get("rush")), "the %s cast: its rush life (%.0f, want %.0f)" % [b, bo.max_hp, want])
			else:
				var hp0: float = bo.hp
				bo.hit({"how": "slash", "from_x": w.player.position.x, "amount": 100.0})
				_check(bo.hp < hp0, "and takes a blow (%.0f -> %.0f)" % [hp0, bo.hp])
		w.queue_free()
		await process_frame


func _test_waxworks() -> void:
	_check(Waxworks.drips_of(["hotter", "thicker", "quick", "dim", "dry", "unlit", "clock", "glass"]) == 20, "the eight open Tweaks add to 20 drips")
	var all10: int = 0
	for t in Waxworks.TWEAK_ORDER:
		all10 += int(Waxworks.TWEAKS[t]["drips"])
	_check(all10 == 25, "the ten Tweaks are 25 drips in all")
	_check(Waxworks.drips_of(["hotter"], "fierce") == 4 and Waxworks.drips_of(["hotter"], "gentle") == 0 and Waxworks.drips_of([], "gentle") == 0, "Candle strength: Fierce +2, Gentle -2, never below 0")
	_check(Waxworks.seal_of(3) == 0 and Waxworks.seal_of(4) == 1 and Waxworks.seal_of(8) == 2 and Waxworks.seal_of(12) == 3, "seals at 4 / 8 / 12 drips")
	_check(Waxworks.tweak_open("warded") == ResourceLoader.exists("res://scripts/boss_mods.gd"), "Warded and Echoing Wax wait for boss_mods.gd")
	# Echoing Wax only on the casts whose blows it echoes (the rev5 review:
	# on Gravebough and the Tinker it echoed nothing, on the Hush only its P3
	# Gaze: three free drips toward a seal).
	for b in ["rootmother", "tinker", "hush"]:
		_check(not Waxworks.tweak_open("echoing", b) and Waxworks.drips_of(["echoing", "hotter"], "normal", b) == 2,
				"Echoing Wax is shut on %s until its blows are recorded (and pays no drips)" % b)
	for b in Waxworks.ECHOES:
		_check(Waxworks.tweak_open("echoing", str(b)) == ResourceLoader.exists("res://scripts/boss_mods.gd"), "Echoing Wax opens on %s" % b)
	_check(not Waxworks.tweak_open("echoing", "gauntlet"), "and not in the Gauntlet while any cast lacks it")
	# The rematch area: max(area_level(boss area, diff), hero level - 1).
	_check(Waxworks.rematch_area("tollgrave", "dusk", 1) == 6 and Waxworks.rematch_area("tollgrave", "dusk", 20) == 19 and Waxworks.rematch_area("snuffer", "nightfall", 1) == 33, "a rematch is at max(its area, your level - 1)")
	# Each Tweak's number in a World.
	_fresh()
	game.level_record("1-4", "dusk")["cleared"] = true
	var base := await _wax_world([])
	var ref_hp: float = base["hp"]
	var ref_dmg: float = base["dmg"]
	var ref_tells: float = base["tells"]
	var t := await _wax_world(["thicker"])
	_check(absf(float(t["hp"]) / ref_hp - 1.5) < 0.01, "Thicker Wax: boss life x1.5 (%.2f)" % (float(t["hp"]) / ref_hp))
	t = await _wax_world(["hotter"])
	_check(absf(float(t["dmg"]) / ref_dmg - 1.4) < 0.01, "Hotter Wax: boss damage x1.4")
	t = await _wax_world(["quick"])
	_check(absf(float(t["tells"]) / ref_tells - 0.85) < 1e-4, "Quick Wick: tells x0.85")
	t = await _wax_world(["dim"])
	_check(float(t["dim"]) > 0.0 and absf(float(t["dim"]) - 0.75) < 1e-4, "Dim Cellar: your light x0.75 through the dim pipeline")
	t = await _wax_world(["dry"])
	_check(int(t["flask"]) == 0 and not bool(t["flask_ok"]), "Dry Flask: no flask charges")
	t = await _wax_world(["unlit"])
	_check(not bool(t["special"]), "Unlit Hands: the Special is refused")
	t = await _wax_world(["glass"], "glass")
	_check(bool(t["snuffed"]), "Glass Candle: a 1-point hit snuffs you")
	t = await _wax_world(["clock"], "clock")
	_check(bool(t["snuffed"]), "Waxley's Clock: snuffed when it runs out (90 s for Tollgrave)")
	_check(not bool(base["xp_ok"]) and not bool(base["loot_ok"]), "no XP or drops from the fight itself (x0.25 at the bell; the seals pay)")
	# The hero's own flask, and the cast in cream wax at 30%.
	_fresh()
	game.level_record("1-4", "dusk")["cleared"] = true
	game.grant_draught("second")
	var fm = Waxworks.new()
	fm.headless = true
	fm.setup("tollgrave", "dusk", [])
	var fw := _mode_world(fm, fm.level_data())
	await process_frame
	_check(int(fw.flask_charges) == 2, "a rematch's flask is the hero's own: the Second Draught counts (%d)" % int(fw.flask_charges))
	_check(fw.boss != null and (fw.boss.tint as Color).is_equal_approx(Color.WHITE.lerp(Mode.WAX_TINT, 0.3)), "the cast is cream wax at 30%%, not a full multiply")
	fw.queue_free()
	await process_frame
	# The win: records, rewards once.
	_fresh()
	game.level_record("1-4", "dusk")["cleared"] = true
	var m = Waxworks.new()
	m.headless = true
	m.setup("tollgrave", "dusk", ["hotter", "thicker", "quick", "dim", "glass"])
	var w := _mode_world(m, m.level_data())
	await process_frame
	m._on_woke()
	m.fight_t = 70.0
	var e0: int = game.embers()
	var sat0: int = (game.hero()["satchel"] as Array).size()
	w._ring(w.bells[0] if not w.bells.is_empty() else w.add_bell(w.player.position))
	_ticks(w, 3)
	var rec: Dictionary = ModesSave.boss_rec(game, "tollgrave", "dusk")
	_check(int(rec["drips"]) == 14 and (rec["paid"] as Array).has("gold"), "14 drips: a Gold seal, and the record (%s)" % [rec])
	_check((game.hero()["satchel"] as Array).size() - sat0 == 3 and game.has_cosmetic("flame:bellbronze"), "Bronze a Rare, Silver a Rare and Bell-bronze, Gold a Legendary")
	_check(game.embers() - e0 >= 60, "a clear pays 60 embers once")
	w.queue_free()
	await process_frame
	sat0 = (game.hero()["satchel"] as Array).size()
	m = Waxworks.new()
	m.headless = true
	m.setup("tollgrave", "dusk", ["hotter", "thicker", "quick", "dim", "glass"])
	w = _mode_world(m, m.level_data())
	await process_frame
	w._ring(w.add_bell(w.player.position))
	_ticks(w, 3)
	_check((game.hero()["satchel"] as Array).size() == sat0, "the seals pay once per boss per difficulty")
	w.queue_free()
	await process_frame
	# The Gauntlet carries life and restarts only the current boss.
	_fresh()
	var gm = Waxworks.new()
	gm.headless = true
	gm.setup("", "dusk", [])
	gm.gauntlet = true
	gm.order = ["tollgrave", "snuffer"]
	gm.boss = "tollgrave"
	gm.spare = 2
	var gw := _mode_world(gm, gm.level_data())
	await process_frame
	gw.player.hp = gw.player.max_hp * 0.6
	gw.player.invuln = 0.0
	gw.player.take_damage(99999.0, gw.player.position.x + 5.0)
	_check(gm.spare == 1 and gm.boss == "tollgrave", "a Gauntlet snuff spends a Spare Wick and keeps the same boss")
	_ticks(gw, int(2.0 / DT))
	gw.player.hp = gw.player.max_hp * 0.6
	gw._ring(gw.add_bell(gw.player.position))
	_ticks(gw, int(2.2 / DT))
	_check(gm.index == 1 and gm.boss == "snuffer" and absf(float(gm.carry.get("hp", 0.0)) - 0.6) < 0.02, "the next boss, life carried (%.2f)" % float(gm.carry.get("hp", 0.0)))
	# A cleared Gauntlet counts its casts right (the rev5 review: "7 of 6").
	gm.index = gm.order.size()   # (as _after_win leaves it past the last cast)
	gm._gauntlet_over(true)
	_check(int(gm.outcome.get("reached", -1)) == int(gm.outcome.get("of", -2)) and int(gm.outcome["of"]) == gm.order.size(),
			"a cleared Gauntlet reports every cast reached, no more (%s of %s)" % [gm.outcome.get("reached"), gm.outcome.get("of")])
	gw.queue_free()
	await process_frame


func _wax_world(tw: Array, poke := "") -> Dictionary:
	var m = Waxworks.new()
	m.headless = true
	m.setup("tollgrave", "dusk", tw)
	var w := _mode_world(m, m.level_data())
	await process_frame
	var b: Node2D = w.boss
	var out := {"hp": float(b.max_hp), "dmg": float(b.dmg_mult), "tells": w.tells_mult(), "flask": int(w.flask_charges),
			"flask_ok": w.allows("flask"), "special": w.allows("special"), "xp_ok": w.allows("xp"), "loot_ok": w.allows("loot"),
			"dim": float((w.dims() as Dictionary).get("waxworks:dim", {}).get("mult", 0.0)), "snuffed": false}
	var p: Node2D = w.player
	if poke == "glass":
		_ticks(w, 2)
		p.hp -= 1.0
		_ticks(w, 2)
		out["snuffed"] = not p.alive or w.state == "dead"
	elif poke == "clock":
		m._on_woke()
		m.fight_t = 89.0
		_ticks(w, int(0.5 / DT))
		out["alive_before"] = p.alive
		m.fight_t = 90.5
		_ticks(w, 2)
		out["snuffed"] = not p.alive or w.state == "dead"
	w.queue_free()
	await process_frame
	return out


# ---------------------------------------------------------------- the Trials

func _built_trials() -> Array:
	return TrialData.ORDER.filter(func(id): return TrialData.built(id))


func _test_trials_data() -> void:
	var built := _built_trials()
	_check(built.size() >= 10, "trials 1 and 2 of every calling are built (%d)" % built.size())
	for cls in TrialData.BY_CLS:
		for id in (TrialData.BY_CLS[cls] as Array).slice(0, 2):
			_check(TrialData.built(id), "%s is built" % id)
	for id in TrialData.ORDER:
		var t: Dictionary = TrialData.TRIALS[id]
		# The loadout is legal: each rank passes can_buy in order, one capstone.
		var cls := str(t["cls"])
		var lvl := int(t["level"])
		var ranks := {}
		var points := lvl - 1
		var ok := true
		var why := ""
		for pair in t["ranks"]:
			var nid := str(pair[0])
			var node := Classes.find_node(cls, nid)
			var have := int(ranks.get(nid, 1 if int(node.get("branch", 0)) == -1 else 0))
			while have < int(pair[1]):
				var r := Classes.can_buy(cls, nid, ranks, lvl, points)
				if r != "":
					ok = false
					why = "%s rank %d: %s" % [nid, have + 1, r]
					break
				have += 1
				ranks[nid] = have
				points -= 1
			if not ok:
				break
		_check(ok, "%s's loadout is legal at L%d (%s)" % [id, lvl, why])
		var caps := 0
		for n in Classes.tree(cls):
			if int(n["tier"]) == 3 and int(ranks.get(n["id"], 0)) > 0:
				caps += 1
		_check(caps <= 1 and (caps == 1) == bool(t.get("master", false)), "%s: a capstone only in its Master (%d)" % [id, caps])
		_check(TrialData.points_used(id) <= lvl - 1, "%s: its ranks fit L%d's points" % [id, lvl])
		if not TrialData.built(id):
			continue
		var lv = LevelData.load_file(TrialData.path(id))
		_check(lv.errors.is_empty(), "trials/%s parses (%s)" % [id, lv.errors])
		_check(int(lv.area_abs) == lvl and str(lv.headers.get("cls", "")) == cls and str(lv.headers.get("trial", "")) == id, "%s: area_abs is its level, its calling and id" % id)
		_check(lv.hints.size() >= 1 and lv.hints[0] == str(t["lesson"]), "%s: the lesson is the first sign" % id)
		# Medals in order, and none impossible.
		var b := TrialData.base_time(id)
		_check(b > 0.0, "%s has a base time" % id)
		_check(TrialData.target(id, 4) < TrialData.target(id, 3) and TrialData.target(id, 3) < TrialData.target(id, 2), "%s: Dawn < Gold < Silver" % id)
		_check(TrialData.medal_for(id, b * 1.1) == 4 and TrialData.medal_for(id, b * 1.4) == 3 and TrialData.medal_for(id, b * 1.9) == 2 and TrialData.medal_for(id, b * 9.0) == 1, "%s: the medal for a time" % id)
	# A borrowed hero is never saved and gains no XP.
	_fresh()
	var real: Dictionary = game.hero()
	var xp0 := int(real["xp"])
	game.borrow_hero(Trials.loadout("w2"))
	_check(str(game.hero_id()) == "witch" and int(game.hero()["level"]) == 12, "the Trials lend a hero: the Taperwitch at L12")
	_check(game.add_xp(500) == 0 and str(game.add_item({"rarity": "rare", "slot": "coat"})) == "full", "a borrowed hero takes no XP and no items")
	game.save()
	game.return_hero()
	_check(int(game.hero()["xp"]) == xp0 and str(game.hero_id()) == "knight", "and none of it is saved")
	var st := Hero.stats(Trials.loadout("k1"), [], "dusk")
	_check(int((st["ranks"] as Dictionary).get("k_mirror", 0)) == 3, "the loadout's ranks reach the numbers (Mirrored Glass 3)")


func _trial_copy(lv: RefCounted) -> RefCounted:
	## The bot's copy of a trial room: the static copy and its assist ledges.
	var copy = Reach.static_copy(lv)
	for c in Trials.assist_cells(lv):
		copy.set_tile(c.x, c.y, LevelData.LEDGE)
	return copy


func _marks(lv: RefCounted) -> Array:
	var out: Array = []
	for part in str(lv.headers.get("marks", "")).split(";", false):
		var bits := part.split(",")
		out.append({"cell": Vector2i(int(bits[0]), int(bits[1])), "kind": bits[2]})
	return out


func _candle_goal(m: Dictionary) -> Dictionary:
	var half := float(Trials.BOX.get(m["kind"], 14.0))
	var p := LevelData.cell_center(m["cell"])
	return {"what": "candle %s %s" % [m["kind"], m["cell"]], "p": p, "rope": true, "rect": Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0)}


func _line_clear(lv: RefCounted, a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 8.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if LevelData.is_solid(lv.tile(floori(p.x / TILE), floori(p.y / TILE))):
			return false
	return true


func _shot_spot(s: RefCounted, lv: RefCounted, m: Dictionary) -> int:
	## A standing spot the bot reached with a clear shot at the candle: from
	## his middle, or from a jump's top (3 tiles up), within 330 px.
	var p := LevelData.cell_center(m["cell"])
	var best := -1
	var bd := 1.0e9
	for i in s.nodes.size():
		var nd: Dictionary = s.nodes[i]
		if nd["climb"]:
			continue
		var mid: Vector2 = nd["pos"] + Vector2(0, -20)
		for from in [mid, mid + Vector2(0, -96)]:
			var d: float = (from as Vector2).distance_to(p)
			if d <= 330.0 and d < bd and _line_clear(lv, from, p):
				bd = d
				best = i
	return best


func _test_trial_reach() -> void:
	## The bot, with the assist ledges, reaches every touch candle and the
	## bell, and a spot with a clear shot at every shot candle; then the
	## timing bot walks it (Dijkstra) for the base time B.
	var timing := OS.get_environment("WAXBY_TIMING") != ""
	for id in _built_trials():
		var lv = LevelData.load_file(TrialData.path(id))
		var copy := _trial_copy(lv)
		var marks := _marks(lv)
		var goals := Reach.goals_of(lv).filter(func(g): return g["what"] == "bell")
		for m in marks:
			if m["kind"] in ["t", "*"]:
				goals.append(_candle_goal(m))
		var s = ReachSearch.new()
		s.setup(copy, LevelData.cell_floor(lv.start), {"goals": goals})
		s.run()
		_check(not s.capped, "trial %s: the bot finishes under the cap" % id)
		_check(s.found.has("bell"), "trial %s: the bot reaches the bell" % id)
		var waypoints: Array = []
		var shots := 0
		var kills := 0
		for m in marks:
			var g := _candle_goal(m)
			match m["kind"]:
				"t":
					_check(s.found.has(g["what"]), "trial %s: the bot touches the %s" % [id, g["what"]])
					waypoints.append(g)
				"*":
					if s.found.has(g["what"]):
						waypoints.append(g)
					else:
						var i := _shot_spot(s, copy, m)
						_check(i >= 0, "trial %s: the bot reaches a spot with a clear shot at the %s" % [id, g["what"]])
						if i >= 0:
							waypoints.append(_spot_goal(s.nodes[i]["pos"], g["what"]))
						shots += 1
				"s", "w":
					var i := _shot_spot(s, copy, m)
					_check(i >= 0, "trial %s: the bot reaches a spot with a clear shot at the %s" % [id, g["what"]])
					if i >= 0:
						waypoints.append(_spot_goal(s.nodes[i]["pos"], g["what"]))
					shots += 1
				"k":
					var foe := false
					for e in lv.entities:
						if e["cell"] == m["cell"] and "skeleton bat thornback bonebow hollow_helm gutterwing dripkin brinejaw lidlurk".contains(str(e["kind"])):
							foe = true
					_check(foe, "trial %s: a foe stands under the %s" % [id, g["what"]])
					kills += 1
		s.free_player()
		# The timing bot: every waypoint by x, then the bell.
		waypoints.sort_custom(func(a, b): return (a["p"] as Vector2).x < (b["p"] as Vector2).x)
		waypoints.append(goals[0])
		var route := _timing_route(copy, LevelData.cell_floor(lv.start), waypoints)
		var bot_b := float(route["time"]) + TrialData.KILL_SECONDS * kills + TrialData.SHOT_SECONDS * shots
		var base := TrialData.base_time(id)
		if timing:
			print("  timing %s: route %.2f s (%s legs), kills %d, shots %d -> B %.2f (trial_data %.2f)" % [id, route["time"], route["legs"], kills, shots, bot_b, base])
		_check(bool(route["ok"]), "trial %s: the timing bot walks the whole route" % id)
		if TrialData.KIT_TIMED.has(id):
			continue   # B from the real kit's run (_test_kit_timing): the quirk outruns the bot's walk
		_check(base >= bot_b - 0.01, "trial %s: B %.1f s is no less than the timing bot's %.1f s (Dawn is never out of reach)" % [id, base, bot_b])
		_check(base <= bot_b * 1.6 + 6.0, "trial %s: B %.1f s isn't far past the bot's %.1f s" % [id, base, bot_b])


func _test_kit_timing() -> void:
	## A trial whose quirk outruns a walk (TrialData.KIT_TIMED: Stampede's
	## 250 px/s, the Smoke Step) takes B from the real kit: run with the kit
	## (hold right, swing, Step at a foe close ahead), it's Dawn, so Dawn is
	## in reach; and B is that run's, not the walking bot's, so a run that
	## breaks stride (a half-second stop every three) isn't: the ladder isn't
	## given away on the first try (the review's f1 / r1 finding).
	for id in TrialData.KIT_TIMED:
		if not TrialData.built(id):
			continue
		var base := TrialData.base_time(id)
		var keep := await _kit_run(id, false)
		var halt := await _kit_run(id, true)
		_check(keep >= 0.0 and TrialData.medal_for(id, keep) == 4, "trial %s: the kit's run finishes in %.2f s, a Dawn at B %.1f" % [id, keep, base])
		_check(keep < 0.0 or base <= keep * 1.05 + 0.5, "trial %s: B %.1f s is the kit's line (%.2f s), not the bot's walk" % [id, base, keep])
		_check(halt >= 0.0 and TrialData.medal_for(id, halt) in [2, 3], "trial %s: a run that breaks stride (%.2f s) takes Silver or Gold, not Dawn (medal %d)" % [id, halt,
				TrialData.medal_for(id, halt) if halt >= 0.0 else -1])


func _kit_run(id: String, halting: bool) -> float:
	## The trial played through its World with the kit; the clock at the bell, or -1.
	_fresh()
	var mw := _trial_world(id)
	var m = mw[0]
	var w: Node2D = mw[1]
	var ended := [false]
	w.finished.connect(func(_r): ended[0] = true)
	await process_frame
	var p: Node2D = w.player
	var f := 0
	var t := 0.0
	while t < 60.0 and not bool(m.done) and not ended[0]:
		f += 1
		var pd := {"right": not (halting and f % 180 >= 150), "attack": f % 16 < 8}
		if str(game.hero_id()) == "runner":
			for e in w.enemies:
				if e.alive and e.position.x > p.position.x and e.position.x - p.position.x < 80.0 and absf(e.position.y - p.position.y) < 40.0 and f % 30 < 2:
					pd["special"] = true
		w.test_pad = pd
		w._read_pad()
		w.tick(DT)
		t += DT
	var out: float = float(m.clock) if bool(m.done) else -1.0
	game.return_hero()
	w.queue_free()
	await process_frame
	return out


func _spot_goal(pos: Vector2, what: String) -> Dictionary:
	return {"what": "spot for " + what, "p": pos + Vector2(0, -19), "rope": true, "rect": Rect2(pos + Vector2(-12, -38), Vector2(24, 38))}


func _timing_route(copy: RefCounted, start: Vector2, waypoints: Array) -> Dictionary:
	## Dijkstra over the bot's sims, leg by leg: the least time from where the
	## last leg ended to each waypoint in turn.
	var total := 0.0
	var at := start
	var at_climb := false
	var legs: Array = []
	for i in waypoints.size():
		var g: Dictionary = waypoints[i]
		var leg := _dijkstra(copy, at, at_climb, g, i == waypoints.size() - 1)
		if not bool(leg["ok"]):
			return {"ok": false, "time": total, "legs": legs}
		total += float(leg["time"])
		legs.append(snappedf(float(leg["time"]), 0.01))
		at = leg["pos"]
		at_climb = bool(leg["climb"])
	return {"ok": true, "time": total, "legs": legs}


func _dijkstra(copy: RefCounted, start: Vector2, climb: bool, goal: Dictionary, last := false) -> Dictionary:
	var s = ReachSearch.new()
	s.setup(copy, start, {"goals": [goal], "start_climb": climb})
	var nodes: Array = [{"pos": start, "climb": climb, "col": floori(start.x / TILE), "parent": -1, "action": {}, "carry": {}, "dmax": {}}]
	var cost := {Reach.key_of(start, climb): 0.0}
	var heap: Array = [[0.0, 0]]
	var best := {"ok": false}
	var pops := 0
	while not heap.is_empty() and pops < 6000:
		heap.sort_custom(func(a, b): return a[0] < b[0])
		var top: Array = heap.pop_front()
		pops += 1
		var t: float = top[0]
		var nd: Dictionary = nodes[int(top[1])]
		if not best.is_empty() and bool(best.get("ok", false)) and t >= float(best["time"]):
			break
		var acts: Array = Reach.vine_actions() if nd["climb"] else Reach.floor_actions()
		for a in acts:
			var r: Dictionary = s.simulate(nd, a, true)
			var dt := (r["pads"] as Array).size() * DT
			if r["found"].has(goal["what"]) and (last or r["ok"]):
				var arrive := t + dt
				if not bool(best.get("ok", false)) or arrive < float(best["time"]):
					best = {"ok": true, "time": arrive, "pos": r["pos"], "climb": r["climb"]}
			if not r["ok"]:
				continue
			var k := Reach.key_of(r["pos"], r["climb"])
			var nt := t + dt
			if cost.has(k) and float(cost[k]) <= nt:
				continue
			cost[k] = nt
			nodes.append({"pos": r["pos"], "climb": r["climb"], "col": r["col"], "parent": -1, "action": a, "carry": {}, "dmax": {}})
			heap.append([nt, nodes.size() - 1])
	s.free_player()
	return best


func _trial_world(id: String) -> Array:
	## [mode, world] for a trial, headless, its hero borrowed.
	var m = Trials.new()
	m.headless = true
	m.setup(id)
	game.borrow_hero(Trials.loadout(id))
	var lv: RefCounted = m.level_data()
	var w := _mode_world(m, lv)
	return [m, w]


func _test_trials_world() -> void:
	_fresh()
	var mw := _trial_world("w2")
	var m = mw[0]
	var w: Node2D = mw[1]
	await process_frame
	_check(w.diff == "dusk" and w.area == 12 and str(game.hero_id()) == "witch", "a trial: Dusk, its level's area, its calling")
	_check(not w.allows("xp") and not w.allows("loot") and not w.allows("embers") and not w.allows("record"), "no XP, loot, embers or records from a trial")
	_check(m.marks.size() == 5 and not m.bell_up and not (w.bells[0]["sprite"] as Node2D).visible, "the bell waits for the candles")
	# The clock starts on the first press after the title card.
	_ticks(w, int(0.5 / DT), {"right": true})
	_check(not m.started and m.clock == 0.0, "not before the title card (0.8 s)")
	_ticks(w, int(0.1 / DT), {})
	_ticks(w, int(0.3 / DT), {})
	_check(not m.started, "nor with nothing pressed")
	_ticks(w, 12, {"right": true})
	_check(m.started and m.clock > 0.0, "the first press starts it")
	# A touch lights a touch candle; the last one raises the bell.
	for mk in m.marks:
		w.player.reset_at(mk["p"] + Vector2(0, 19))
		_ticks(w, 1, {})
	_check(m.lit_count() == 5 and m.bell_up and (w.bells[0]["sprite"] as Node2D).visible, "every candle lit: the bell rises")
	_check(m.lights().size() == 5, "lit candles give light (%d)" % m.lights().size())
	var t_ring: float = m.clock
	w._ring(w.bells[0])
	_ticks(w, 30, {})
	_check(m.done and absf(m.clock - t_ring) < 0.02, "the clock stops at the bell")
	var rec := ModesSave.trial_rec(game, "w2")
	_check(float(rec["best"]) > 0.0 and int(rec["medal"]) >= 1 and int(rec["tries"]) >= 1, "the finish records the best time and a medal (%s)" % [rec])
	_check(int(m.finish.get("medal", 0)) >= 1 and str(m.finish.get("line", "")) != "", "the finish card has its medal and Taper's line")
	# Tries: each run counted once (a Retry after a finish isn't a try of its own; a death is).
	var tries0 := int(rec["tries"])
	m.restart()
	m._finish(w)
	_check(int(ModesSave.trial_rec(game, "w2")["tries"]) == tries0 + 1, "a Retry from the finish card, finished: one more try (%d -> %d)" % [tries0, int(ModesSave.trial_rec(game, "w2")["tries"])])
	m.done = true
	m.restart()
	m.restart()
	m._finish(w)
	_check(int(ModesSave.trial_rec(game, "w2")["tries"]) == tries0 + 3, "a death, then a finish: two more (%d)" % int(ModesSave.trial_rec(game, "w2")["tries"]))
	game.return_hero()
	w.queue_free()
	await process_frame
	# Death is an instant restart.
	mw = _trial_world("w2")
	m = mw[0]
	w = mw[1]
	await process_frame
	var restarts := [0]
	w.restart.connect(func(): restarts[0] += 1)
	w.player.invuln = 0.0
	w.player.take_damage(99999.0, w.player.position.x + 5.0)
	_ticks(w, int(0.7 / DT))
	_check(restarts[0] == 1, "a snuff in a trial restarts it after 0.6 s")
	game.return_hero()
	w.queue_free()
	await process_frame
	# No Anointed in a trial: the same room every time.
	mw = _trial_world("r1")
	m = mw[0]
	w = mw[1]
	await process_frame
	_check(w.enemies.size() > 0 and w.enemies.all(func(e): return str(e.tier) == ""), "no elites in a trial (%d foes)" % w.enemies.size())
	game.return_hero()
	w.queue_free()
	await process_frame
	# Kill and shot candles.
	mw = _trial_world("f2")
	m = mw[0]
	w = mw[1]
	await process_frame
	var km: Dictionary = m.marks[0]
	_check(km["foe"] != null, "a kill candle knows its foe")
	(km["foe"] as Node2D).alive = false
	_ticks(w, 1)
	_check(bool(km["lit"]), "its foe put out: the kill candle burns")
	game.return_hero()
	w.queue_free()
	await process_frame
	mw = _trial_world("k1")
	m = mw[0]
	w = mw[1]
	await process_frame
	var sm: Dictionary = m.marks[0]
	w.player.reset_at(sm["p"] + Vector2(0, 19))
	_ticks(w, 1)
	_check(not bool(sm["lit"]), "a shot candle isn't lit by a touch")
	w.spawn_shot({"kind": "arrow", "owner": "enemy", "pos": sm["p"], "vel": Vector2.ZERO, "life": 1.0})
	_ticks(w, 1)
	_check(not bool(sm["lit"]), "nor by the enemy's arrow")
	_ticks(w, 30)
	w.spawn_shot({"kind": "arrow", "owner": "player", "pos": sm["p"] + Vector2(-2, 0), "vel": Vector2(1, 0), "life": 1.0})
	_ticks(w, 20)
	_check(bool(sm["lit"]), "an arrow sent back lights it")
	game.return_hero()
	w.queue_free()
	await process_frame
	await _k1_through_the_kit()


func _k1_through_the_kit() -> void:
	## Ping! as it teaches: stood on the walkway facing the bows, the shield
	## raised just as each real Bonebow arrow lands (a Perfect Guard, Mirrored
	## Glass 3): each goes home along its line, and all three shot candles
	## on the posts light, so the bell rises.
	var mw := _trial_world("k1")
	var m = mw[0]
	var w: Node2D = mw[1]
	await process_frame
	var p: Node2D = w.player
	p.reset_at(LevelData.cell_floor(Vector2i(23, 12)))
	p.facing = 1
	var guard := 0
	var t := 0.0
	var pg0: int = int(w.kit.perfect_guards)
	while t < 40.0 and not bool(m.bell_up):
		var eta := INF
		var pc: Vector2 = p.center()
		for s2 in w.shots:
			if str(s2.get("owner", "")) == "player":
				continue
			var v: Vector2 = s2.get("vel", Vector2.ZERO)
			var d: Vector2 = pc - (s2["pos"] as Vector2)
			if v.length() > 1.0 and d.dot(v) > 0.0:
				eta = minf(eta, d.length() / v.length())
		if eta < 0.10 and guard <= 0:
			guard = 14
		var pad := {}
		if guard > 0:
			guard -= 1
			pad["special"] = true
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)
		t += DT
	var lit := 0
	for mk in m.marks:
		lit += 1 if bool(mk["lit"]) else 0
	_check(int(w.kit.perfect_guards) > pg0, "k1: the kit's Perfect Guards met the arrows (%d)" % (int(w.kit.perfect_guards) - pg0))
	_check(lit == m.marks.size() and bool(m.bell_up), "k1 as taught: Perfect Guards on the walkway light all %d candles and raise the bell (%d lit in %.1f s)" % [m.marks.size(), lit, t])
	game.return_hero()
	w.queue_free()
	await process_frame


# ---------------------------------------------------------------- the kits' quirks across their gaps

func _test_quirks() -> void:
	## Each quirk trial's gap, crossed with the real kit (and not without the
	## quirk): a Drift across w2's first gap, a Grave Step over x1's, a cling
	## and kick up r2's first chimney, a Ledge Grab saving k2's first gap, a
	## Stampede bowling a Rattle in f1.
	_fresh()
	# w2: a Drift carries her over the first 7-tile gap (x 14-20).
	var r := await _quirk_run("w2", 11, 2.6, func(t, p, st):
		var pd := {"right": true}
		if t >= 0.25 and t < 0.75:
			pd["jump"] = true
		elif t >= 0.8:
			pd["jump"] = true   # the second press, held: she floats
		return pd)
	_check(float(r["x"]) > 21.0 * TILE and bool(r["alive"]) and not bool(r["hurt"]), "w2: a Drift carries her over the first gap (to %.1f tiles)" % (float(r["x"]) / TILE))
	var plain := await _quirk_run("w2", 11, 2.0, func(t, p, st):
		var pd := {"right": true}
		if t >= 0.25 and t < 0.75:
			pd["jump"] = true
		return pd)
	_check(bool(plain["hurt"]) or float(plain["x"]) < 21.0 * TILE, "w2: a plain jump doesn't (to %.1f)" % (float(plain["x"]) / TILE))
	# x1: a Grave Step over the first 6-tile gap (x 13-18).
	r = await _quirk_run("x1", 10, 2.2, func(t, p, st):
		var pd := {"right": true}
		if t >= 0.25 and t < 0.6:
			pd["jump"] = true
		elif t >= 0.68 and t < 1.1:
			pd["jump"] = true
		return pd)
	_check(float(r["x"]) > 19.0 * TILE and not bool(r["hurt"]), "x1: a Grave Step carries him over the first gap (to %.1f tiles)" % (float(r["x"]) / TILE))
	plain = await _quirk_run("x1", 10, 2.0, func(t, p, st):
		var pd := {"right": true}
		if t >= 0.25 and t < 0.6:
			pd["jump"] = true
		return pd)
	_check(bool(plain["hurt"]) or float(plain["x"]) < 19.0 * TILE, "x1: a plain jump doesn't (to %.1f)" % (float(plain["x"]) / TILE))
	# r2: cling and kick up the first chimney (its walls at x 12 and 16, the shelf's top at row 6).
	r = await _quirk_run("r2", 9, 5.0, func(t, p, st):
		var pd := {}
		if p.position.x < 13 * TILE + 16 and not st.has("in"):
			pd["right"] = true
			return pd
		st["in"] = true
		if p.clinging != 0 and float(st.get("kick_t", -9.0)) < t - 0.25:
			st["kick_t"] = t
			st["dir"] = -p.clinging
		if t - float(st.get("kick_t", -9.0)) < 0.2:
			pd["jump"] = true
		elif not st.has("kick_t") and p.on_floor:
			pd["jump"] = true
		var dir := int(st.get("dir", 1))
		pd["left" if dir < 0 else "right"] = true
		return pd)
	_check(float(r["top"]) <= 6.0 * TILE, "r2: cling and kick climb the chimney (feet up to row %.1f)" % (float(r["top"]) / TILE))
	# f1: flat out for 0.8 s, she stampedes, and a Rattle goes down in her way.
	r = await _quirk_run("f1", 2, 3.0, func(t, p, st):
		return {"right": true})
	_check(bool(r["stampeded"]), "f1: flat out, she hits her stride (Stampede)")
	_check(int(r["kills"]) >= 1 or int(r["bowled"]) >= 1, "f1: and a Rattle goes down in her way (%d)" % maxi(int(r["kills"]), int(r["bowled"])))
	# k2: over its first gap (five tiles to a step one up), more take-offs
	# land with Ledge Grab than without: the jumps a hair late meet the far
	# wall's face and are hauled up.
	var lv = LevelData.load_file(TrialData.path("k2"))
	var plain_n := _k2_landings(lv, "")
	var grab_n := _k2_landings(lv, "ledge_grab")
	_check(grab_n > plain_n and plain_n > 0, "k2: Ledge Grab saves jumps a plain one misses at the first gap (%d take-offs with it, %d without)" % [grab_n, plain_n])


func _k2_landings(lv: RefCounted, quirk: String) -> int:
	## Running right from x 6, a held jump pressed at each 1/120 s step of the
	## run-up: how many land on the far step (x 17 on, one up).
	var n := 0
	var copy = Reach.static_copy(lv)
	for i in 80:
		var bw = Reach.BotWorld.new()
		bw.level = copy
		var p = load("res://scripts/player.gd").new()
		p.level = copy
		p.world = bw
		p.quirk = quirk
		p.reset_at(LevelData.cell_floor(Vector2i(6, 12)))
		p.on_floor = true
		var press := 0.55 + i * DT
		var t := 0.0
		var prevj := false
		while t < 2.5:
			var j := t >= press and t < press + 0.6
			p.pad = {"right": true, "jump": j, "jump_pressed": j and not prevj}
			prevj = j
			p.step(DT)
			t += DT
			if p.position.x >= 17 * TILE and p.on_floor and p.position.y <= 12 * TILE + 0.5:
				n += 1
				break
			if p.position.y > 13 * TILE + 8 or (p.on_floor and p.position.x < 12 * TILE and t > press + 0.2):
				break
		p.free()
	return n


func _quirk_run(id: String, from_x: int, dur: float, script: Callable) -> Dictionary:
	var mw := _trial_world(id)
	var w: Node2D = mw[1]
	await process_frame
	var p: Node2D = w.player
	p.reset_at(LevelData.cell_floor(Vector2i(from_x, 12)))
	var st := {}
	var out := {"x": 0.0, "alive": true, "hurt": false, "top": 9999.0, "stampeded": false, "kills": 0, "bowled": 0, "grabbed": false}
	var hp0: float = p.hp
	var kills := [0]
	w.enemy_killed.connect(func(_e, _h): kills[0] += 1)
	var t := 0.0
	while t < dur:
		var pd: Dictionary = script.call(t, p, st)
		w.test_pad = pd
		w._read_pad()
		w.tick(DT)
		t += DT
		out["top"] = minf(float(out["top"]), p.position.y)
		if p.stampeding:
			out["stampeded"] = true
		if p.ledge_t >= 0.0:
			out["grabbed"] = true
		if p.hp < hp0 - 0.01:
			out["hurt"] = true
	for e in w.enemies:
		if is_instance_valid(e) and (e.status.has("flipped") or e.status.has("stun") or e.status.has("bowled")):
			out["bowled"] = int(out["bowled"]) + 1
	out["x"] = p.position.x
	out["alive"] = p.alive
	out["kills"] = kills[0]
	game.return_hero()
	w.queue_free()
	await process_frame
	return out


# ---------------------------------------------------------------- the screens

func _test_screens() -> void:
	_fresh()
	ModesSave.force_open = true
	game.level_record("1-2", "dusk")["cleared"] = true
	game.level_record("1-4", "dusk")["cleared"] = true
	var paths := {"hub": "res://scripts/modes/modes_screen.gd", "descent": "res://scripts/modes/descent_screen.gd",
			"waxworks": "res://scripts/modes/waxworks_screen.gd", "trials": "res://scripts/modes/trials_screen.gd",
			"results": "res://scripts/modes/mode_results.gd"}
	for size in [Vector2(844, 390), Vector2(847, 390)]:
		root.size = Vector2i(size)
		UI.safe_override = UI.phone_safe(size)
		var safe: Rect2 = UI.safe_override
		for k in paths:
			var sc: Control = load(paths[k]).new()
			if k == "results":
				sc.set("results", {"cls": "knight", "diff": "dusk", "depth": 7, "best": 9, "time": 612.0, "kills": 88, "xp": 1234, "milestones": [{"depth": 5, "cosmetic": "flame:emberheart"}]})
			root.add_child(sc)
			await process_frame
			await process_frame
			var bad := _buttons_ok(sc, safe)
			_check(bad == "", "%s at %dx%d: every button at least 40 px and inside the safe area (%s)" % [k, size.x, size.y, bad])
			if k == "hub":
				var rs: Array = sc.door_rects()
				var clear := true
				for i in rs.size():
					for j in range(i + 1, rs.size()):
						clear = clear and not (rs[i] as Rect2).intersects(rs[j])
					clear = clear and safe.encloses(rs[i])
				_check(clear, "the hub's doors at %dx%d don't overlap and sit in the safe area" % [size.x, size.y])
				sc.open("trials")
				await process_frame
				_check(sc.sub != null and sc.sub.has_signal("back"), "the hub opens a door's screen")
				bad = _buttons_ok(sc.sub, safe)
				_check(bad == "", "the trials screen inside the hub: buttons ok (%s)" % bad)
			if k == "waxworks":
				var cr: Array = sc.chip_rects()
				var ok := true
				for r in cr:
					ok = ok and safe.encloses(r) and (r as Rect2).size.y >= 40.0
				_check(ok, "the Tweak chips at %dx%d sit in the safe area, 40 px tall" % [size.x, size.y])
			sc.queue_free()
			await process_frame
		# The Look tab in the Sheet.
		var hs: Control = load("res://scripts/hero_screen.gd").new()
		root.add_child(hs)
		await process_frame
		var lp: Control = load("res://scripts/modes/look_panel.gd").new()
		lp.set("host", hs)
		hs.add_child(lp)
		var cr2: Rect2 = hs.content_rect()
		lp.position = cr2.position
		lp.size = cr2.size
		await process_frame
		var rects: Array = lp.swatch_rects()
		var inside := true
		for r in rects:
			inside = inside and Rect2(Vector2.ZERO, lp.size).encloses(r)
		_check(rects.size() == 15 and inside, "the Look tab's 15 flame swatches fit at %dx%d" % [size.x, size.y])
		hs.queue_free()
		await process_frame
	UI.safe_override = Rect2()
	# Wearing a flame: owned only; the World's hero flame follows the look.
	_fresh()
	var lp2: Control = load("res://scripts/modes/look_panel.gd").new()
	root.add_child(lp2)
	lp2.size = Vector2(560, 300)
	await process_frame
	lp2.tap(Cosmetics.FLAME_ORDER.find("marigold"))
	_check(str(game.look()["flame"]) == "tallow", "a locked flame can't be worn")
	game.grant_cosmetic("flame:marigold")
	lp2.tap(Cosmetics.FLAME_ORDER.find("marigold"))
	_check(str(game.look()["flame"]) == "marigold", "an owned one is worn at a tap")
	lp2.queue_free()
	await process_frame
	var m = _descent("knight", "dusk", 1, 1)
	var w := _mode_world(m, m.level_data())
	await process_frame
	_check((w.hero_flame as Dictionary).get("mid") == Color("ffb030"), "a mode's World wears the hero's flame (hero_flame)")
	w.queue_free()
	await process_frame
	ModesSave.force_open = false


func _buttons_ok(n: Node, safe: Rect2) -> String:
	var bad := ""
	for c in n.find_children("*", "Button", true, false):
		var b := c as Button
		if not b.is_visible_in_tree():
			continue
		var r := b.get_global_rect()
		if r.size.y < 40.0 - 0.5 or not safe.grow(1.0).encloses(r):
			bad += "%s %s; " % [b.text, r]
	return bad


func _test_hub_lines() -> void:
	## Each hub line has its own seen key: Waxley's is said once the Waxworks
	## opens, even when Taper's was said long before.
	_fresh()
	var hub = load("res://scripts/modes/modes_screen.gd")
	game.level_record("1-2", "dusk")["cleared"] = true
	var l1: Array = hub.intro_lines(game)
	_check(l1.size() == 1 and str(l1[0]["key"]) == "hub:taper", "the first visit (after 1-2): Taper's line")
	ModesSave.mark_seen(game, "hub:taper", false)
	_check((hub.intro_lines(game) as Array).is_empty(), "said once")
	game.level_record("1-4", "dusk")["cleared"] = true
	var l2: Array = hub.intro_lines(game)
	_check(l2.size() == 1 and str(l2[0]["key"]) == "hub:waxley", "Tollgrave beaten later: Waxley's line on the next visit (%s)" % [l2])
	ModesSave.force_open = true
	var l3: Array = hub.intro_lines(game)
	_check(l3.size() == 2 and str(l3[1]["key"]) == "hub:descent", "and the Descent's once it's open")
	ModesSave.force_open = false


func _test_build_counts() -> void:
	## What the screens say of content this build hasn't got: the Look tab's
	## locked swatches never name a boss, the ending or a Descent depth out
	## of reach ("Deeper down"), and the Challenges count the casts and trials
	## built, as the map counts levels.
	_fresh()
	var casts: Array = ModesSave.built_casts()
	var trials: Array = ModesSave.built_trials()
	var all_casts: bool = casts.size() == ModesSave.BOSSES.size()
	for b in ModesSave.BOSSES:
		_check(ModesSave.source_reachable("waxworks:" + b, game) == casts.has(b), "the %s cast's flame %s" % [b, "is named" if casts.has(b) else "says Deeper down (not built)"])
	_check(ModesSave.source_reachable("gauntlet:any", game) == all_casts and ModesSave.source_reachable("waxworks:bronze6", game) == all_casts,
			"the Gauntlet's and the six seals' only with all six casts built")
	_check(ModesSave.source_reachable("story:homecoming", game) == FileAccess.file_exists("res://levels/6-4.txt"), "homecoming's only with 6-4 built")
	_check(not ModesSave.source_reachable("descent:5", game), "a Descent depth's not while its door is sealed")
	ModesSave.force_open = true
	_check(ModesSave.source_reachable("descent:5", game), "(and once it's open, it is)")
	ModesSave.force_open = false
	_check(ModesSave.source_reachable("trials:golds10", game) == (trials.size() >= 10) and ModesSave.source_reachable("trials:dawns20", game) == (trials.size() >= 20),
			"a Trials count only as far as the trials built (%d)" % trials.size())
	_check(ModesSave.source_reachable("trials:gold4:knight", game) == TrialData.BY_CLS["knight"].all(func(id): return TrialData.built(id))
			and ModesSave.source_reachable("trials:master:knight", game) == TrialData.built("k4"), "a calling's four Golds and its Master only once built")
	var LookS: GDScript = load("res://scripts/modes/look_panel.gd")
	if game.heroes().is_empty():
		game.new_hero("knight")
	var lp: Control = LookS.new()
	root.add_child(lp)
	var line: String = lp.source_line("flame:lullflame")
	_check(line == (Cosmetics.source_text("flame:lullflame") if casts.has("hush") else Cosmetics.DEEPER), "Lullflame's swatch: \"%s\"" % line)
	_check(lp.source_line("flame:bellbronze") == Cosmetics.source_text("flame:bellbronze"), "Bell-bronze (Tollgrave's cast) names what earns it")
	lp.free()
	var hub = load("res://scripts/modes/modes_screen.gd")
	var hs: Control = hub.new()
	root.add_child(hs)
	game.level_record("1-2", "dusk")["cleared"] = true
	game.level_record("1-4", "dusk")["cleared"] = true
	var wl := str(hs.door_status("waxworks"))
	var tl := str(hs.door_status("trials"))
	_check(wl.begins_with("1 of %d cast" % casts.size()), "the Waxworks door counts the casts built: \"%s\"" % wl)
	_check(tl.contains(" of %d open" % trials.size()), "the Trials door counts the trials built: \"%s\"" % tl)
	hs.free()


# ---------------------------------------------------------------- the debug routes (the phone gates)

func _test_autoplay_routes() -> void:
	## main.gd's --autoplay=descent:16 | descent:30 | rush:snuffer | trial:w1
	## start their mode with the bot (the phone's perf gates run these).
	_fresh()
	var main_script = load("res://scripts/main.gd")
	for route in ["descent:16", "descent:30", "rush:snuffer", "trial:w1"]:
		var mn: Node = main_script.new()
		mn.set("_autoplay", route)
		root.add_child(mn)
		await process_frame
		mn.autoplay_route(route)
		await process_frame
		var cur = mn.get("current")
		var ok: bool = cur != null and cur.get("mode") != null and bool(cur.get("autoplay"))
		_check(ok, "--autoplay=%s starts its mode with the bot" % route)
		if ok:
			for i in 60:
				await physics_frame
			_check(is_instance_valid(cur) and cur.get("player") != null, "--autoplay=%s runs" % route)
			if route.begins_with("descent") and is_instance_valid(cur):
				# The bot walks into the landing's altar first, as a player
				# would (its Glimmers, its relight), not over it.
				var lit := false
				for i in 600:
					if not is_instance_valid(cur):
						break
					cur.player.invuln = 1.0
					for a in cur.altars:
						lit = lit or bool(a["lit"])
					if lit:
						break
					await physics_frame
				_check(lit, "--autoplay=%s: the bot lights the landing's altar" % route)
		game.return_hero()
		mn.queue_free()
		await process_frame
	ModesSave.force_open = false


# ---------------------------------------------------------------- XP per minute

func _test_xp_rate() -> void:
	## The Descent pays at least as much XP a minute as a Nightfall replay at
	## L34-40, and not more than 1.5x (decisions.md). A model on the real
	## files, both on Nightfall, both at the hero's own area (gap_mult 1),
	## over a whole stratum (depths 1-5 on Nightfall are areas 36-40: two
	## plain depths, a warden's, a plain one, an echo): every monster placed
	## is put out (each kind's own XP, a Dread's and a boss's too); a replay
	## is World 2's levels (their monsters a tile, over a 350-tile level)
	## plus a clear; a depth is its stitched rooms (the deep overlays as
	## they'd be) plus 20 x E(A); both walked at 70 tiles a minute (v2's
	## pace), a boss fight a minute more.
	var pace := 70.0
	# The replay: the Nightfall levels a hero replays at L34-40 (World 5-6)
	# once their files land; until then World 2's, which are sparser, so the
	# bound is provisional and is re-checked at integration.
	var replay: Array = ["6-1", "6-2", "6-3", "5-1", "5-2", "5-3"].filter(func(id): return FileAccess.file_exists("res://levels/%s.txt" % id))
	var provisional := replay.size() < 3
	if provisional:
		replay = ["2-1", "2-2", "2-3"]
		print("  XP a minute: PROVISIONAL, against World 2's levels (5-x / 6-x aren't built yet): re-check at integration")
	for sd in [3, 8, 13]:
		var dxp := 0.0
		var rxp := 0.0
		var mins := 0.0
		for d in range(1, 6):
			var a := Data.area_at(d, Combat.area_level(31, "nightfall"))
			var m = _descent("knight", "nightfall", d, sd)
			var bd: Dictionary = m.build_depth(d)
			var lv = Mode.parse_level(bd["text"], "descent-%d" % d, int(bd["world"]))
			var dm: float = lv.width / pace + (1.0 if lv.boss != "" else 0.0)
			dxp += _level_xp(lv, a) + Progression.event_xp("depth", a)
			mins += dm
			var r := 0.0
			var rtiles := 0
			for id in replay:
				var rl = LevelData.load_file("res://levels/%s.txt" % id)
				r += _level_xp(rl, a)
				rtiles += rl.width
			var replay_rate := (r / rtiles * 350.0 + Progression.event_xp("clear", a)) / (350.0 / pace)
			rxp += replay_rate * dm
		var ratio := dxp / rxp
		print("  XP a minute, seed %d: the Descent %.0f, a replay %.0f (%.2fx)" % [sd, dxp / mins, rxp / mins, ratio])
		_check(ratio >= 1.0 and ratio <= 1.5, "L36-40 (a run's depths 1-5 on Nightfall, seed %d): the Descent pays %.0f XP a minute against a replay's %.0f (%.2fx, against %s%s)" % [sd, dxp / mins, rxp / mins, ratio, ",".join(replay), ", provisional" if provisional else ""])
	# A Waxworks rematch pays no more a minute than a replay (the rev5 review:
	# the Hush's Nightfall rematch paid up to 16,000 XP a minute to an L34
	# hero). At the reference wins' pace (the Hush 88 s, the Saint 94 s at
	# L34 on Nightfall) and a quick one's (45 s), L34 and L40.
	for lvl in [34, 40]:
		for row in [["hush", 88.0], ["saint", 94.0], ["hush", 45.0]]:
			var a := int(Waxworks.rematch_area(str(row[0]), "nightfall", lvl))
			var r := 0.0
			var rtiles := 0
			for id in replay:
				var rl = LevelData.load_file("res://levels/%s.txt" % id)
				r += _level_xp(rl, a)
				rtiles += rl.width
			var replay_rate := (r / rtiles * 350.0 + Progression.event_xp("clear", a)) / (350.0 / pace)
			var win := int(Waxworks.rematch_xp(str(row[0]), a, "nightfall", float(row[1])))
			var rate := win / (float(row[1]) / 60.0)
			print("  XP a minute, the %s's Nightfall rematch at L%d (area %d, %.0f s): %.0f a minute (a win %d), a replay %.0f" % [row[0], lvl, a, row[1], rate, win, replay_rate])
			_check(rate <= replay_rate * 1.05, "the %s's Nightfall rematch at L%d pays %.0f XP a minute, no more than a replay's %.0f" % [row[0], lvl, rate, replay_rate])


func _level_xp(lv: RefCounted, a: int) -> float:
	## Every monster of a level put out at area a by a hero of level a, on Nightfall.
	var x := 0.0
	for e in lv.entities:
		var k := str(e["kind"])
		if k == "dread":
			var dk := str(lv.dread.get("kind", "skeleton"))
			x += Progression.kill_xp(dk, a, a, "nightfall", "dread")
		elif k == "boss":
			x += Progression.kill_xp(lv.boss, a, a, "nightfall")
		elif Progression.BASE_XP.has(k):
			x += Progression.kill_xp(k, a, a, "nightfall")
	return x


func _monsters(lv: RefCounted) -> int:
	var k := 0
	for e in lv.entities:
		if ["skeleton", "bat", "thornback", "bonebow", "hollow_helm", "gutterwing", "dripkin", "brinejaw", "lidlurk", "dread"].has(str(e["kind"])):
			k += 1
	return k
