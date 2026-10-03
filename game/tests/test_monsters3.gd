extends SceneTree
## test_monsters3 (MA): the World 3 and 4 monsters and the elites of v3.
##
##     godot --headless --path game --script res://tests/test_monsters3.gd
##
## In stand-in rooms built in memory (the 3-* and 4-* levels come later):
##   - the registry: the 8 kinds in KINDS with the contract's spawn and
##     ordinary; MB's 8 and the 4 bosses known; the 16 names; MOVES tables
##   - every kind spawns at its placement (its glyph in a room), loads its
##     frames or its stand-in, dies and pays its XP
##   - every tell >= 0.40 s on Dusk, >= the escape formula where it names an
##     escape (the Hoarowl's 0.60 s meter, the Shield Slam's 0.70 s among
##     them), >= its floor on Witching, measured from the kinds' own clocks
##   - the Swift rule (Dusk tells x1.0), alerted, dazed
##   - the per-kind behaviours of p_monsters.md §21 (the spec's numbers),
##     and the counters a human uses, played out: the hound's pounce lands
##     where he stood (standing he's bitten; a jump or a run clears it), a
##     0.35 s reaction clears the Shield Slam and the icicles, two reference
##     hits break an owl; a Spurwheel stays in the level (a floor between
##     pits, the level's edge, a wall to its top); a Twinned Frostbuckle's
##     rime; a Perfect Guard told from a Peal
##   - elites deterministic per seed, the Omen pools by world, NEVER_ON, the
##     second Omen of W3-W6 Dusk (Build 1's rows), W1-W2's picks unchanged
##   - the four new Omens (every echo drawn while it waits), the Warden
##     tier, the W3-W4 Dreads; eyes drawn at r >= 3 in the glow layer

const LevelData := preload("res://scripts/level_data.gd")
const Combat := preload("res://scripts/combat.gd")
const TILE := 32
const DT := 1.0 / 120.0
const FLOOR_Y := 416.0            # row 13's top: a room's floor
const MINE := ["rootling", "weepcap", "rattlehound", "creepbone", "tickwind", "spurwheel", "frostbuckle", "hoarowl"]
const GLYPHS := {"rootling": "r", "weepcap": "p", "rattlehound": "m", "creepbone": "i", "tickwind": "j", "spurwheel": "q",
		"frostbuckle": "e", "hoarowl": "u"}
const SPAWN := {"rootling": "floor", "weepcap": "floor", "rattlehound": "floor", "creepbone": "vine", "tickwind": "floor",
		"spurwheel": "floor", "frostbuckle": "floor", "hoarowl": "floor"}
const ORDINARY := {"rootling": true, "weepcap": false, "rattlehound": false, "creepbone": true, "tickwind": true,
		"spurwheel": false, "frostbuckle": false, "hoarowl": false}
const LIFE := {"rootling": 16.0, "weepcap": 44.0, "rattlehound": 36.0, "creepbone": 22.0, "tickwind": 20.0, "spurwheel": 30.0,
		"frostbuckle": 70.0, "hoarowl": 20.0}
const MAIN_BLOW := {"rootling": ["pop", 32.0], "weepcap": ["burst", 18.0], "rattlehound": ["pounce", 34.0], "creepbone": ["lunge", 32.0],
		"tickwind": ["charge", 32.0], "spurwheel": ["touch", 32.0], "frostbuckle": ["slam", 36.0], "hoarowl": ["icicle", 24.0]}
# (the Frostbuckle's slam 36, from spec §4.2's 40: the wave-1 integration's
# share-cap ruling, decisions.md "Integration notes", so an Anointed one stays
# under 40% of the arrival knight at 4-3, 4-S and 6-3)
const THEIRS := ["glassmite", "gustling", "refractor", "paneguard", "hushling", "stillmaw", "unwick", "lurecoil",
		"rootmother", "tinker", "saint", "hush"]

var WorldScript: GDScript
var Elites: GDScript
var EK: GDScript
var Progression: GDScript
var game: Node
var _passed := 0
var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	Elites = load("res://scripts/elites.gd")
	EK = load("res://scripts/enemy_kinds.gd")
	Progression = load("res://scripts/progression.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_monsters3_save.json"
	for suffix in [".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	_test_registry()
	await _test_spawn_and_die()
	_test_tell_tables()
	await _test_tells_measured()
	await _test_swift_and_statuses()
	await _test_rootling()
	await _test_weepcap()
	await _test_rattlehound()
	await _test_creepbone()
	await _test_tickwind()
	await _test_spurwheel()
	await _test_frostbuckle()
	await _test_hoarowl()
	_test_omen_pools()
	await _test_elite_picks()
	await _test_new_omens()
	await _test_wardens()
	await _test_dreads()
	await _test_stand_in_draws()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_monsters3_save.json" + suffix))
	game.save_path = game.SAVE_PATH
	game.load_save()
	print("test_monsters3: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _rows(w := 60, fill := {}) -> Array:
	## A flat room: floor on row 13, Wick at column 3, the bell far right.
	var rows := []
	for y in 15:
		rows.append(("#".repeat(w)) if y >= 13 else ".".repeat(w))
	rows[12] = rows[12].substr(0, 3) + "P" + rows[12].substr(4)
	rows[12] = rows[12].substr(0, w - 3) + "E" + rows[12].substr(w - 2)
	for c in fill:
		_put(rows, (c as Vector2i).x, (c as Vector2i).y, str(fill[c]))
	return rows


func _put(rows: Array, x: int, y: int, ch: String) -> void:
	var r: String = rows[y]
	rows[y] = r.substr(0, x) + ch + r.substr(x + 1)


func _world(rows: Array, id := "3-9", diff := "dusk", header := "") -> Node2D:
	var lv = LevelData.new()
	var area := "" if header.contains("area:") else "area: 13\n"
	lv.parse("title: t\nsubtitle: t\n" + area + header + "---\n" + "\n".join(rows))
	lv.id = id
	lv.world = LevelData.world_of(id)
	game.reset()
	game.data["difficulty"] = diff
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	return w


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _step(w: Node2D, n: int, pad := {}) -> void:
	for i in n:
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _until(w: Node2D, done: Callable, seconds: float, pad := {}) -> float:
	## Steps until done() (or the time runs out); the seconds it took (-1: never).
	for i in int(seconds / DT):
		if done.call():
			return i * DT
		_step(w, 1, pad)
	return -1.0 if not done.call() else seconds


func _spawn(w: Node2D, kind: String, cell: Vector2i, opts := {}) -> Node2D:
	var o := opts.duplicate()
	o["cell"] = cell
	var e: Node2D = w.spawn_enemy(kind, EK.spawn_pos(kind, cell), o)
	if e != null:
		e.active = true
	return e


func _park(w: Node2D, at: Vector2) -> void:
	## Wick stood somewhere, safe for a while.
	w.player.reset_at(at)
	w.player.invuln = 0.0
	_step(w, 4)


func _place(w: Node2D, at: Vector2) -> void:
	## Wick put somewhere with no time passing (a tell measured from its start).
	w.player.reset_at(at)
	w.player.invuln = 100.0


func _safe(w: Node2D) -> void:
	w.player.invuln = 100.0


func _hurt_count(w: Node2D) -> float:
	return float(w.player.hp)


# ---------------------------------------------------------------- the registry

func _test_registry() -> void:
	for k in MINE:
		var i: Dictionary = EK.KINDS.get(k, {})
		_check(not i.is_empty() and ResourceLoader.exists(str(i.get("script", ""))), "%s is in KINDS with its script" % k)
		_check(str(i.get("spawn", "")) == SPAWN[k] and bool(i.get("ordinary", false)) == ORDINARY[k],
				"%s: spawn %s, ordinary %s (contract §6.3)" % [k, i.get("spawn"), i.get("ordinary")])
		_check(EK.has(k) and EK.known(k), "%s spawns" % k)
		_check(str(Elites.NAMES.get(k, "")) != "", "%s has a name (%s)" % [k, Elites.NAMES.get(k, "")])
		var sc: GDScript = load(str(i["script"]))
		var consts: Dictionary = sc.get_script_constant_map()
		var moves: Dictionary = consts.get("MOVES", {})
		_check(moves.has(MAIN_BLOW[k][0]) and absf(float(moves[MAIN_BLOW[k][0]]) - float(MAIN_BLOW[k][1])) < 0.01 and moves.has("touch"),
				"%s: its MOVES name its main blow %s at %s base (spec §4.2) and its touch" % [k, MAIN_BLOW[k][0], MAIN_BLOW[k][1]])
		_check(str(consts.get("ARCHETYPE", "")) in ["fodder", "heavy", "brute", "sentinel"], "%s names its archetype" % k)
		var e: Node2D = sc.new()
		_check(absf(float(e.base_hp) - LIFE[k]) < 0.01 and e.kind == k, "%s: base life %s (spec §4.2)" % [k, LIFE[k]])
		e.free()
	for k in THEIRS:
		_check(EK.known(k), "%s is known to the registry (PLANNED until its script lands)" % k)
	for k in ["glassmite", "gustling", "refractor", "paneguard", "hushling", "stillmaw", "unwick", "lurecoil"]:
		_check(str(Elites.NAMES.get(k, "")) != "", "%s has a name" % k)
	_check(Elites.DMG_WORLD_TRIM == {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.9, 6: 0.8}, "DMG_WORLD_TRIM (contract §6.2)")
	# The threat costs (spec §4.2) and roles, for the levels' density tests and the Descent.
	var costs := {"rootling": 1.0, "weepcap": 2.0, "rattlehound": 3.0, "creepbone": 1.5, "tickwind": 1.5, "spurwheel": 2.5,
			"frostbuckle": 4.0, "hoarowl": 2.0, "glassmite": 1.0, "gustling": 1.5, "refractor": 2.0, "paneguard": 4.0,
			"hushling": 0.75, "stillmaw": 3.0, "unwick": 3.5, "lurecoil": 6.0, "skeleton": 1.0}
	var cost_ok := true
	for k in costs:
		cost_ok = cost_ok and is_equal_approx(EK.cost(k), costs[k])
	_check(cost_ok and is_equal_approx(EK.cost("rattlehound", "anointed"), 7.5) and is_equal_approx(EK.cost("skeleton", "dread"), 5.0)
			and is_equal_approx(EK.cost("creepbone", "warden"), 12.0), "threat costs (a Rattle 1; Anointed x2.5, Dread x5, Warden x8)")
	for k in MINE:
		var arch: String = (load(str(EK.KINDS[k]["script"])) as GDScript).get_script_constant_map()["ARCHETYPE"]
		_check(str(EK.ROLE.get(k, "")) == arch and EK.share_cap_key(k) == ("fodder" if ORDINARY[k] else "heavy"),
				"%s's role (%s) matches its script and its share cap" % [k, arch])
	# New code draws through a TriBatch (contract §1): none of the three
	# one-call-each helpers in the v3 kinds.
	var rx := RegEx.create_from_string("\\b(draw_circle|draw_colored_polygon|draw_polyline)\\s*\\(")
	for k in MINE:
		var src := FileAccess.get_file_as_string(str(EK.KINDS[k]["script"]))
		_check(rx.search(src) == null, "%s draws no draw_circle / draw_colored_polygon / draw_polyline" % k)
	_check(not Elites.ELIGIBLE.has("spurwheel") and not Elites.ELIGIBLE.has("lurecoil"), "Spurwheels and Lurecoils are never Anointed")
	for k in ["rootling", "weepcap", "rattlehound", "creepbone", "tickwind", "frostbuckle", "hoarowl", "glassmite", "gustling",
			"refractor", "paneguard", "hushling", "stillmaw", "unwick"]:
		_check(Elites.ELIGIBLE.has(k), "%s may be Anointed" % k)
	_check(Elites.OMENS == ["Swift", "Warded", "Burning", "Twinned", "Vengeful", "Sporebound", "Echoing", "Glassed", "Hushed"], "the nine Omens")


# ---------------------------------------------------------------- spawning, dying, XP

func _test_spawn_and_die() -> void:
	for k in MINE:
		var rows := _rows(40)
		var cell := Vector2i(20, 12)
		if k == "creepbone":
			for y in range(7, 13):
				_put(rows, 20, y, "{")
			cell = Vector2i(20, 10)
		_put(rows, cell.x, cell.y, GLYPHS[k])
		var w := await _world(rows)
		var e: Node2D = null
		for en in w.enemies:
			if en.kind == k:
				e = en
		_check(e != null, "%s spawns from its glyph '%s'" % [k, GLYPHS[k]])
		if e == null:
			await _done(w)
			continue
		var want: Vector2 = EK.spawn_pos(k, cell)
		if k == "creepbone":
			_check(absf(e.position.x - (cell.x + 0.5) * TILE) < 0.5 and e.position.y <= FLOOR_Y + 0.1 and e.on_lane()
					and float(e.lane["top"]) == 7.0 * TILE and float(e.lane["bottom"]) == 13.0 * TILE,
					"a Creepbone takes its vine as its lane (%s, %s)" % [e.position, e.lane])
		else:
			_check(absf(e.position.x - want.x) < 8.0 and absf(e.position.y - FLOOR_Y) < 0.5, "%s stands on its floor (%s)" % [k, e.position])
		# Its frames, or its stand-in: every frame it asks for is loaded when
		# the file is there, and none is when it isn't.
		var names: Array = (load(str(EK.KINDS[k]["script"])) as GDScript).get_script_constant_map().get("FRAMES", [])
		var ok := names.size() > 0 and names.size() <= 10
		for n in names:
			var there := ResourceLoader.exists("res://art/enemies/%s.svg" % n)
			ok = ok and there == e.frames.has(n)
		_check(ok, "%s loads its frames (%d named, %d there) or draws its stand-in" % [k, names.size(), e.frames.size()])
		# It dies and pays its XP.
		_park(w, Vector2(8 * TILE, FLOOR_Y))
		e.active = true
		var xp0: int = w.xp_gained
		var want_xp: int = Progression.kill_xp(k, e.area, int(game.hero()["level"]), "dusk", "", false)
		var res: Dictionary = w.deal(e, 1.0, {"how": "stomp" if k == "spurwheel" else "skill", "flat": 99999.0})
		if k == "spurwheel" and not res["hit"]:
			e.force_catch()
			res = w.deal(e, 1.0, {"how": "slash", "flat": 99999.0})
		_check(res["killed"] and not e.alive, "%s dies" % k)
		_check(w.xp_gained - xp0 == want_xp and want_xp >= 1, "%s pays its XP (%d, want %d)" % [k, w.xp_gained - xp0, want_xp])
		var t := _until(w, func(): return not w.enemies.has(e), 4.0)
		_check(t >= 0.0, "%s is gone after its death plays out" % k)
		await _done(w)


# ---------------------------------------------------------------- tells

func _test_tell_tables() -> void:
	## Every tell's table: >= 0.40 s on Dusk; a move-away tell >= the escape
	## formula (0.35 + escape_px / 205); every floor >= 0.30 s.
	for k in MINE:
		var consts: Dictionary = (load(str(EK.KINDS[k]["script"])) as GDScript).get_script_constant_map()
		var tells: Dictionary = consts.get("TELLS", {})
		_check(not tells.is_empty(), "%s lists its tells" % k)
		for id in tells:
			var d: Dictionary = tells[id]
			var sec := float(d["sec"])
			var fl := float(d.get("floor", 0.30))
			_check(sec >= 0.40 - 0.0001, "%s %s: %.2f s on Dusk (>= 0.40)" % [k, id, sec])
			_check(fl >= 0.30 - 0.0001, "%s %s: its floor %.2f (>= 0.30)" % [k, id, fl])
			if d.has("escape_px"):
				# (after: what comes between the tell's end and the blow, at the
				# least: an icicle's fall to his head.)
				var need := 0.35 + float(d["escape_px"]) / 205.0
				var got := sec + float(d.get("after", 0.0))
				_check(got >= need - 0.0001, "%s %s: %.2f s meets the escape formula (%.2f for %d px)" % [k, id, got, need, int(d["escape_px"])])
	# The six fixed to the formula (decisions): the Hoarowl's meter 0.60
	# (floor 0.40), the Shield Slam 0.70 (floor 0.50).
	var owl: Dictionary = (load("res://scripts/hoarowl.gd") as GDScript).get_script_constant_map()["TELLS"]
	var buckle: Dictionary = (load("res://scripts/frostbuckle.gd") as GDScript).get_script_constant_map()["TELLS"]
	_check(is_equal_approx(float(owl["meter"]["sec"]), 0.60) and is_equal_approx(float(owl["meter"]["floor"]), 0.40), "the Hoarowl's meter is 0.60 s (floor 0.40)")
	_check(is_equal_approx(float(buckle["slam"]["sec"]), 0.70) and is_equal_approx(float(buckle["slam"]["floor"]), 0.50), "the Shield Slam is 0.70 s (floor 0.50)")


func _tell_rootling(diff: String) -> float:
	var w := await _world(_rows(40), "3-9", diff)
	var e := _spawn(w, "rootling", Vector2i(20, 12))
	_place(w, Vector2(20 * TILE + 16, FLOOR_Y))
	var start := _until(w, func(): return e.state == "swell", 3.0)
	var len := _until(w, func(): return e.state == "pop", 2.0)
	await _done(w)
	return len if start >= 0.0 else -1.0


func _tell_weepcap(diff: String) -> float:
	var w := await _world(_rows(40), "3-9", diff)
	var e := _spawn(w, "weepcap", Vector2i(12, 12))
	_place(w, Vector2(9 * TILE, FLOOR_Y))
	var start := _until(w, func(): return e.state == "inhale", 3.0)
	var len := _until(w, func(): return e.state == "puff", 2.0)
	await _done(w)
	return len if start >= 0.0 else -1.0


func _tell_hound(diff: String) -> float:
	var w := await _world(_rows(40), "3-9", diff)
	var e := _spawn(w, "rattlehound", Vector2i(14, 12))
	_place(w, Vector2(9 * TILE, FLOOR_Y))
	var start := _until(w, func(): return e.state == "crouch", 4.0)
	var len := _until(w, func(): return e.state == "pounce", 2.0)
	await _done(w)
	return len if start >= 0.0 else -1.0


func _tell_creep(diff: String) -> float:
	var rows := _rows(40)
	for y in range(5, 13):
		_put(rows, 20, y, "{")
	var w := await _world(rows, "3-9", diff)
	var e := _spawn(w, "creepbone", Vector2i(20, 12))
	_place(w, Vector2(19 * TILE, FLOOR_Y))
	var start := _until(w, func(): return e.state == "coil", 3.0)
	var len := _until(w, func(): return e.state == "lunge", 2.0)
	await _done(w)
	return len if start >= 0.0 else -1.0


func _tell_tick(diff: String) -> float:
	var w := await _world(_rows(40), "4-9", diff)
	var e := _spawn(w, "tickwind", Vector2i(18, 12), {"facing": -1})
	_place(w, Vector2(12 * TILE, FLOOR_Y))
	var start := _until(w, func(): return e.state == "wind", 3.0)
	var len := _until(w, func(): return e.state == "charge", 2.0)
	await _done(w)
	return len if start >= 0.0 else -1.0


func _tell_spur(diff: String) -> Dictionary:
	var w := await _world(_rows(40), "4-9", diff)
	var e := _spawn(w, "spurwheel", Vector2i(18, 12), {"facing": 1})
	_place(w, Vector2(4 * TILE, FLOOR_Y))
	_until(w, func(): return e.state == "respin", 6.0)
	var len := _until(w, func(): return e.state in ["roll", "pivot"], 2.0)
	await _done(w)
	return {"respin": len}


func _tell_buckle(diff: String) -> Dictionary:
	var out := {}
	var w := await _world(_rows(40), "4-9", diff)
	var e := _spawn(w, "frostbuckle", Vector2i(16, 12), {"facing": -1})
	_place(w, Vector2(11 * TILE, FLOOR_Y))
	var s := _until(w, func(): return e.state == "stomp", 3.0)
	out["stomp"] = _until(w, func(): return e.state != "stomp", 2.0) if s >= 0.0 else -1.0
	await _done(w)
	w = await _world(_rows(40), "4-9", diff)
	e = _spawn(w, "frostbuckle", Vector2i(16, 12), {"facing": -1})
	_place(w, Vector2(16 * TILE - 40, FLOOR_Y))
	s = _until(w, func(): return e.state == "slam", 3.0)
	out["slam"] = _until(w, func(): return e.state == "strike", 2.0) if s >= 0.0 else -1.0
	await _done(w)
	return out


func _tell_owl(diff: String) -> float:
	## The meter's fill with Wick held in the cone (looked at straight down).
	var w := await _world(_owl_rows(), "4-9", diff)
	var e := _spawn(w, "hoarowl", Vector2i(20, 8))
	_place(w, Vector2(22 * TILE + 16, FLOOR_Y))
	_step(w, 1)
	var look := rad_to_deg((w.player.center() - e.eye_world()).angle())
	var filled := -1.0
	for i in int(3.0 / DT):
		e.look_hold = look
		w.test_pad = {}
		w._read_pad()
		w.tick(DT)
		e.look_hold = look
		if e.meter >= 1.0 or e.state == "screech":
			filled = (i + 1) * DT
			break
	await _done(w)
	return filled


func _owl_rows() -> Array:
	## A one-stone perch for an owl at (20, 8), in the open.
	var rows := _rows(40)
	_put(rows, 20, 9, "#")
	return rows


func _test_tells_measured() -> void:
	for diff in ["dusk", "witching"]:
		var lo := 0.40 if diff == "dusk" else 0.30
		var r := await _tell_rootling(diff)
		_check(r >= lo - 0.01 and (diff != "dusk" or absf(r - 0.50) < 0.03), "%s: the Rootling's swell lasts %.2f s" % [diff, r])
		var p := await _tell_weepcap(diff)
		_check(p >= lo - 0.01 and (diff != "dusk" or absf(p - 0.70) < 0.03), "%s: the Weepcap's inhale lasts %.2f s" % [diff, p])
		var m := await _tell_hound(diff)
		_check(m >= 0.40 - 0.01 and (diff != "dusk" or absf(m - 0.45) < 0.03), "%s: the Rattlehound's crouch lasts %.2f s (floor 0.40)" % [diff, m])
		var c := await _tell_creep(diff)
		_check(c >= 0.40 - 0.01 and (diff != "dusk" or absf(c - 0.50) < 0.03), "%s: the Creepbone's coil lasts %.2f s" % [diff, c])
		var tk := await _tell_tick(diff)
		_check(tk >= 0.40 - 0.01 and (diff != "dusk" or absf(tk - 0.55) < 0.03), "%s: the Tickwind's wind lasts %.2f s (Witching 0.45, floor 0.40)" % [diff, tk])
		var sp := await _tell_spur(diff)
		_check(float(sp["respin"]) >= 0.40 - 0.01 and (diff != "dusk" or absf(float(sp["respin"]) - 0.50) < 0.03),
				"%s: the Spurwheel's re-spin lasts %.2f s" % [diff, float(sp["respin"])])
		var fb := await _tell_buckle(diff)
		_check(float(fb["stomp"]) >= 0.40 - 0.01 and (diff != "dusk" or absf(float(fb["stomp"]) - 0.70) < 0.03),
				"%s: the Frost Stomp's crack runs %.2f s" % [diff, float(fb["stomp"])])
		_check(float(fb["slam"]) >= 0.50 - 0.01 and (diff != "dusk" or absf(float(fb["slam"]) - 0.70) < 0.03),
				"%s: the Shield Slam's tell lasts %.2f s (floor 0.50)" % [diff, float(fb["slam"])])
		var ow := await _tell_owl(diff)
		_check(ow >= 0.40 - 0.01 and (diff != "dusk" or absf(ow - 0.60) < 0.03), "%s: the Hoarowl's meter fills in %.2f s (floor 0.40)" % [diff, ow])


# ---------------------------------------------------------------- Swift, alerted, dazed

func _test_swift_and_statuses() -> void:
	for diff in ["dusk", "nightfall"]:
		var w := await _world(_rows(40), "4-9", diff)
		var e := _spawn(w, "tickwind", Vector2i(20, 12), {"tier": "anointed", "omens": ["Swift"]})
		var m := float(Combat.diff(diff)["tells"])
		if diff == "dusk":
			_check(absf(e.tell(0.55) - 0.55) < 0.001, "Dusk: a Swift elite's tells stay x1.0 (%.3f)" % e.tell(0.55))
		else:
			_check(absf(e.tell(0.55) - maxf(0.55 * m * 0.75, 0.30)) < 0.001, "Nightfall: Swift's tells x0.75 (%.3f)" % e.tell(0.55))
		_check(absf(e.cd(1.0) - m * 0.75) < 0.001, "%s: Swift's cooldowns x0.75 on every difficulty" % diff)
		_check(absf(e.spd(100.0) - 100.0 * 1.15 * 1.4) < 0.01, "%s: Swift +40%% speed" % diff)
		_check(absf(e.tell(0.10, 0.40) - 0.40) < 0.001 and absf(e.tell(0.10) - 0.30) < 0.001, "tell() keeps its floors (the move's, then 0.30)")
		await _done(w)
	var w2 := await _world(_rows(40), "4-9")
	var t := _spawn(w2, "tickwind", Vector2i(20, 12))
	var s0: float = t.spd(100.0)
	t.active = false
	t.alert(4.0)
	_check(t.active and absf(t.spd(100.0) - s0 * 1.3) < 0.01, "alerted: x1.3 speed, and awake")
	_step(w2, int(4.1 / DT))
	_check(not t.status.has("alerted"), "alerted wears off after 4 s")
	var r := _spawn(w2, "rattlehound", Vector2i(30, 12))
	r.apply_status("dazed", 1.0)
	var hp0: float = r.hp
	w2.deal(r, 1.0, {"how": "skill", "flat": 10.0})
	_check(r.stunned() and absf(hp0 - r.hp - 15.0) < 0.01, "dazed: it can't act and takes +50%% (%.1f)" % (hp0 - r.hp))
	await _done(w2)


# ---------------------------------------------------------------- Rootling

func _test_rootling() -> void:
	var w := await _world(_rows(40))
	var e := _spawn(w, "rootling", Vector2i(24, 12))
	_park(w, Vector2(6 * TILE, FLOOR_Y))
	_safe(w)
	_check(e.buried() and e.size.y <= 10.0, "a Rootling waits buried (a low mound)")
	_check(not w.deal(e, 1.0, {"how": "slash", "flat": 5.0})["hit"] and not w.deal(e, 1.0, {"how": "shot", "flat": 5.0})["hit"],
			"buried, a slash or a shot passes over it")
	_check(not e.touch_damage(), "walking over the mound doesn't hurt")
	# It follows along its strip within 200 px, at 90 px/s.
	_park(w, Vector2(19 * TILE, FLOOR_Y))
	_safe(w)
	var x0: float = e.position.x
	_step(w, 60)
	var v := (x0 - e.position.x) / 0.5
	_check(v > 80.0 and v < 95.0, "buried, it follows at 90 px/s (%.0f)" % v)
	# The swell locks the column at his x; a step of 24 px during the tell
	# gets him clear (the escape formula: half the column plus half Wick).
	_until(w, func(): return e.state == "swell", 3.0)
	_check(e.state == "swell", "within 24 px it swells (the tell)")
	var locked: float = e.pop_x
	_check(absf(locked - w.player.position.x) < 0.5, "the pop column locks at his x (%.1f vs %.1f)" % [locked, w.player.position.x])
	w.player.invuln = 0.0
	var hp0 := _hurt_count(w)
	var side := 1.0 if w.player.position.x >= locked else -1.0
	w.player.reset_at(Vector2(locked + side * 24.0, FLOOR_Y))
	w.player.invuln = 0.0
	_until(w, func(): return e.state != "swell" and e.state != "pop", 1.5)
	_check(_hurt_count(w) == hp0, "a 24 px step during the tell clears the pop")
	_check(e.status.has("dazed") and not e.buried(), "after the pop it is dazed above ground")
	await _done(w)
	# Wick 20 px off the mound: the column locks at his x, not the mound's,
	# and stays there when he moves in the tell.
	w = await _world(_rows(40))
	e = _spawn(w, "rootling", Vector2i(20, 12))
	var mound_x: float = e.position.x
	_park(w, Vector2(mound_x - 20.0, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "swell", 1.0)
	var at_x: float = w.player.position.x
	var lock1: float = e.pop_x
	w.player.reset_at(Vector2(at_x - 40.0, FLOOR_Y))
	_safe(w)
	_step(w, 20)
	_check(e.state == "swell" and absf(lock1 - at_x) < 0.5 and absf(lock1 - mound_x) > 15.0 and e.pop_x == lock1,
			"20 px off the mound the column locks at his x (%.0f; mound %.0f), and holds as he moves" % [lock1, mound_x])
	_until(w, func(): return e.state == "pop", 1.0)
	_check(absf(e.pop_rect().get_center().x - lock1) < 0.5, "the pop rises there")
	await _done(w)
	# Standing still, the pop hits him.
	w = await _world(_rows(40))
	e = _spawn(w, "rootling", Vector2i(20, 12))
	_park(w, Vector2(20 * TILE + 16, FLOOR_Y))
	hp0 = _hurt_count(w)
	_until(w, func(): return e.state == "walk" or e.status.has("dazed"), 2.0)
	_check(_hurt_count(w) < hp0, "standing still, the pop hits him")
	await _done(w)
	# A stomp on the mound kills it.
	w = await _world(_rows(40))
	e = _spawn(w, "rootling", Vector2i(20, 12))
	_park(w, Vector2(10 * TILE, FLOOR_Y))
	_safe(w)
	w.player.reset_at(Vector2(e.position.x, FLOOR_Y - 60.0))
	w.player.velocity = Vector2(0, 300)
	_until(w, func(): return not e.alive, 1.0)
	_check(not e.alive, "a stomp on the mound kills it")
	await _done(w)
	# A Peal wave (how "wave") or the Sexton's spade digs it out, dazed.
	w = await _world(_rows(40))
	e = _spawn(w, "rootling", Vector2i(20, 12), {"tier": "anointed"})
	_park(w, Vector2(6 * TILE, FLOOR_Y))
	_safe(w)
	var ok: bool = w.deal(e, 1.0, {"how": "wave", "flat": 1.0})["hit"]
	_check(ok and not e.buried() and e.status.has("dazed"), "a Peal wave unearths it, dazed")
	await _done(w)
	game.reset()
	w = await _world(_rows(40))
	e = _spawn(w, "rootling", Vector2i(20, 12), {"tier": "anointed"})
	var cls = w.kit.cls
	w.kit.cls = "sexton"
	ok = w.deal(e, 1.0, {"how": "slash", "flat": 1.0})["hit"]
	w.kit.cls = cls
	_check(ok and not e.buried(), "the Sexton's spade digs it out")
	await _done(w)


# ---------------------------------------------------------------- Weepcap

func _test_weepcap() -> void:
	var w := await _world(_rows(40))
	var e := _spawn(w, "weepcap", Vector2i(14, 12))
	var rat := _spawn(w, "rattlehound", Vector2i(12, 12), {"tier": "anointed"})
	rat.active = false
	_park(w, Vector2(10 * TILE, FLOOR_Y))
	_safe(w)
	var r0: float = w.hero_light_radius()
	_until(w, func(): return e.state == "puff", 3.0)
	_check(e.clouds.size() == 1 and w.features.spores_at(e.clouds[0]["p"]), "a puff makes a spore cloud (the one cloud rule)")
	var cp: Vector2 = e.clouds[0]["p"]
	_check(absf(cp.x - (e.cap_center().x - 48.0)) < 1.0, "centred 48 px toward him")
	w.player.reset_at(Vector2(cp.x - 40.0, FLOOR_Y))
	_safe(w)
	_step(w, 6)
	var r1: float = w.hero_light_radius()
	_check(r1 < r0 * 0.9 and r1 >= 56.0, "inside, his light is dimmed (%.0f -> %.0f, never under 56)" % [r0, r1])
	# A spark through the cloud burns it: the whoomph hurts monsters in it, not Wick.
	rat.position = Vector2(cp.x + 30.0, FLOOR_Y)
	var hp_r: float = rat.hp
	var hp_w: float = w.player.hp
	w.player.invuln = 0.0
	w.spawn_shot({"kind": "spark", "pos": cp + Vector2(-30, 0), "vel": Vector2(300, 0), "life": 0.5, "owner": "player", "coef": 0.01})
	_step(w, 20)
	_check(e.clouds.is_empty() or e.clouds.all(func(c): return c["burnt"]), "fire clears the cloud")
	_check(rat.hp < hp_r, "the whoomph burns the monsters inside (%.1f -> %.1f)" % [hp_r, rat.hp])
	_check(w.player.hp >= hp_w, "and never Wick")
	await _done(w)
	# The burst punishes hugging it; a stomp deals 1.5x and cancels the inhale.
	w = await _world(_rows(40))
	e = _spawn(w, "weepcap", Vector2i(14, 12))
	_park(w, Vector2(14 * TILE + 16 + 24, FLOOR_Y))
	var hp0 := _hurt_count(w)
	_until(w, func(): return e.state == "idle" and e.clouds.size() > 0, 3.0)
	_check(_hurt_count(w) < hp0, "the burst hurts him hugging the cap")
	await _done(w)
	w = await _world(_rows(40))
	e = _spawn(w, "weepcap", Vector2i(14, 12))
	_park(w, Vector2(11 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "inhale", 3.0)
	var h0: float = e.hp
	w.deal(e, 1.0, {"how": "stomp", "flat": 4.0})
	_check(e.state == "idle" and absf(h0 - e.hp - 6.0) < 0.01, "a stomp deals 1.5x and cancels the inhale")
	await _done(w)
	# Nightfall's clouds are bigger and longer; at most two of its own.
	w = await _world(_rows(40), "3-9", "nightfall")
	e = _spawn(w, "weepcap", Vector2i(14, 12))
	_park(w, Vector2(11 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.clouds.size() > 0, 3.0)
	_check(e.clouds.size() > 0 and float(e.clouds[0]["r"]) == 72.0 and float(e.clouds[0]["life"]) == 6.0, "Nightfall: clouds r 72 for 6 s")
	_step(w, int(9.0 / DT))
	_check(e.live_clouds() <= 2, "never more than two of its clouds (%d)" % e.live_clouds())
	await _done(w)


# ---------------------------------------------------------------- Rattlehound

func _test_rattlehound() -> void:
	var PS: GDScript = load("res://scripts/player.gd")
	_check(250.0 > float(PS.RUN_SPEED), "a Rattlehound's chase (250) outruns Wick (%s)" % PS.RUN_SPEED)
	var w := await _world(_rows(80))
	var e := _spawn(w, "rattlehound", Vector2i(60, 12))
	_park(w, Vector2(53 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "howl", 2.0)
	_check(e.state == "howl", "it howls when it sees him")
	w.player.reset_at(Vector2(e.position.x - 400.0, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "chase", 1.0)
	_step(w, 24)
	var x0: float = e.position.x
	_step(w, 24)
	_check(absf(e.position.x - x0) / 0.2 > 205.0, "it chases faster than he runs (%.0f px/s)" % (absf(e.position.x - x0) / 0.2))
	_until(w, func(): return e.state == "crouch", 3.0)
	var dir: int = e.pounce_dir
	var aim: float = w.player.position.x
	_check(absf(e.pounce_to - aim) < 0.5, "the pounce is aimed at his x at the crouch's start (%.0f, he's at %.0f)" % [e.pounce_to, aim])
	# He steps well away: it never retargets.
	_park(w, Vector2(e.position.x + dir * 200.0, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "pounce", 1.0)
	var y0: float = e.position.y
	var top := y0
	var sx: float = e.position.x
	var air := 0.0
	while e.state == "pounce":
		_step(w, 1)
		air += DT
		top = minf(top, e.position.y)
	var height := y0 - top
	_check(height > 44.0 and height < 54.0, "the pounce is a low arc (%.0f px high, spec 49)" % height)
	_check(absf(e.position.x - aim) < 6.0, "it comes down where he stood (%.0f, aimed %.0f), never retargeting" % [e.position.x, aim])
	_check(absf(air - 2.0 * 420.0 / 1800.0) < 0.03, "in the air %.2f s (vy -420, g 1800)" % air)
	var jump_apex: float = pow(float(PS.JUMP_SPEED), 2.0) / (2.0 * float(PS.GRAVITY_UP))
	_check(jump_apex > height * 2.0, "his jump (%.0f px) clears it easily" % jump_apex)
	_check(signf(e.position.x - sx) == float(dir), "the pounce keeps the way it was aimed")
	_check(e.state == "land", "it lands")
	var open := _until(w, func(): return e.state != "land", 2.0)
	_check(absf(open - 0.7) < 0.03, "the landing window is 0.7 s (%.2f)" % open)
	await _done(w)
	# Its longest pounce: vx 330, about 150 px (a target beyond reach).
	w = await _world(_rows(60))
	e = _spawn(w, "rattlehound", Vector2i(30, 12), {"facing": -1})
	_park(w, Vector2(e.position.x - 300.0, FLOOR_Y))
	_safe(w)
	e.state = "chase"
	e._crouch(w.player, 0.45)
	_until(w, func(): return e.state == "pounce", 1.0)
	sx = e.position.x
	_until(w, func(): return e.state != "pounce", 1.0)
	var length := absf(e.position.x - sx)
	_check(is_equal_approx(e.pounce_vx, 330.0) and length > 140.0 and length < 165.0, "at most vx 330, about 150 px long (%.0f)" % length)
	await _done(w)
	# A human against it on Dusk: standing still he is bitten; a jump pressed
	# 0.2-0.3 s into the crouch (or as it leaps) clears it and comes down on
	# its back; running away from a 0.35 s reaction isn't bitten.
	var stood := await _hound_try("stand", 0.0)
	_check(stood["crouched"] and stood["hits"] >= 1, "standing still %.0f px off, the pounce bites him (%d)" % [stood["dist"], stood["hits"]])
	for at in [0.2, 0.25, 0.3, 0.45]:
		var j := await _hound_try("jump", at)
		_check(j["crouched"] and j["hits"] == 0, "a jump %.2f s into the crouch clears the pounce (%d bites)" % [at, j["hits"]])
		_check(j["stomped"], "and comes down on its back: a stomp (%.2f s)" % at)
	var ran := await _hound_try("run", 0.35)
	_check(ran["crouched"] and ran["hits"] == 0, "running away from a 0.35 s reaction, the pounce misses (%d)" % ran["hits"])
	# After 3 pounces it pants (+25% damage).
	w = await _world(_rows(60))
	e = _spawn(w, "rattlehound", Vector2i(30, 12))
	_park(w, Vector2(26 * TILE, FLOOR_Y))
	_safe(w)
	var pounces := 0
	for i in int(12.0 / DT):
		var was: String = e.state
		_step(w, 1)
		if was != "pounce" and e.state == "pounce":
			pounces += 1
		if e.state == "pant":
			break
		w.player.reset_at(Vector2(e.position.x + (-1.0 if e.facing > 0 else 1.0) * 0.0 + 70.0 * (1 if i % 2 == 0 else -1) * 0.0 + (70.0 if e.position.x < 30 * TILE else -70.0), FLOOR_Y))
		_safe(w)
	_check(e.state == "pant" and pounces == 3, "after 3 pounces it pants (%d)" % pounces)
	var h0: float = e.hp
	w.deal(e, 1.0, {"how": "skill", "flat": 8.0})
	_check(absf(h0 - e.hp - 10.0) < 0.01, "panting it takes +25%%")
	await _done(w)
	# A stomp stuns it 0.6 s.
	w = await _world(_rows(60))
	e = _spawn(w, "rattlehound", Vector2i(30, 12))
	_park(w, Vector2(10 * TILE, FLOOR_Y))
	_safe(w)
	w.deal(e, 1.0, {"how": "stomp", "flat": 2.0})
	_check(e.status.has("stun") and absf(float(e.status["stun"]) - 0.6) < 0.02, "a stomp stuns it 0.6 s")
	await _done(w)
	# Nightfall: a second pounce 0.35 s after the first lands.
	w = await _world(_rows(60), "3-9", "nightfall")
	e = _spawn(w, "rattlehound", Vector2i(30, 12))
	_park(w, Vector2(27 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "land", 4.0)
	var gap := _until(w, func(): return e.state == "crouch", 1.0)
	_check(absf(gap - 0.35) < 0.03, "Nightfall: a second pounce 0.35 s after landing (%.2f)" % gap)
	await _done(w)


func _hound_try(plan: String, at: float) -> Dictionary:
	## Dusk: Wick stands in a hound's path; when it crouches he does `plan`
	## ("stand"; "jump" pressed `at` s into the crouch and held 0.4 s; "run"
	## away from `at` s on). Bites are counted from the crouch to the end of
	## its landing; stomped: it was stunned (he came down on it).
	var w := await _world(_rows(60), "3-9", "dusk")
	var e := _spawn(w, "rattlehound", Vector2i(30, 12), {"facing": -1})
	_park(w, Vector2(22 * TILE, FLOOR_Y))
	var crouch_t := -1.0
	var t := 0.0
	var hits := 0
	var last: float = w.player.hp
	var stomped := false
	var dist := 0.0
	var away := ""
	while t < 6.0:
		var pad := {}
		if crouch_t >= 0.0:
			var since := t - crouch_t
			if plan == "jump" and since >= at and since < at + 0.4:
				pad["jump"] = true
			elif plan == "run" and since >= at:
				pad[away] = true
		_step(w, 1, pad)
		t += DT
		if crouch_t < 0.0 and e.state == "crouch":
			crouch_t = t
			dist = absf(e.position.x - w.player.position.x)
			away = "left" if e.position.x > w.player.position.x else "right"
		if w.player.hp < last:
			hits += 1
			w.player.invuln = 0.0   # (every bite counts)
		last = w.player.hp
		if crouch_t >= 0.0 and e.status.has("stun"):
			stomped = true
		if crouch_t >= 0.0 and not (e.state in ["crouch", "pounce", "land"]):
			break
	await _done(w)
	return {"hits": hits, "stomped": stomped, "dist": dist, "crouched": crouch_t >= 0.0}


# ---------------------------------------------------------------- Creepbone

func _creep_room() -> Array:
	var rows := _rows(40)
	for y in range(4, 13):
		_put(rows, 20, y, "{")
	return rows


func _test_creepbone() -> void:
	var w := await _world(_creep_room())
	var e := _spawn(w, "creepbone", Vector2i(20, 10))
	_park(w, Vector2(8 * TILE, FLOOR_Y))
	_safe(w)
	var x0: float = e.position.x
	var ys := []
	for i in 240:
		_step(w, 1)
		ys.append(e.position.y)
	var moved: float = ys.max() - ys.min()
	_check(absf(e.position.x - x0) < 0.01 and moved > 20.0, "it crawls its lane (%.0f px), keeping to it" % moved)
	_check(e.position.y >= e.lane_min() - 0.1 and e.position.y <= float(e.lane["bottom"]) + 0.1, "within the lane's ends")
	# He climbs its lane below it: it coils, then lunges along the lane only.
	e.position.y = 10.0 * TILE
	e.dir = -1
	_park(w, Vector2(20 * TILE + 16, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "coil", 2.0)
	_check(e.state == "coil" and e._lunge_dir == 1, "on its lane within 128 px, it coils toward him")
	var ly: float = e.position.y
	_until(w, func(): return e.state == "stretched", 1.0)
	_check(absf(e.position.x - x0) < 0.01 and e.position.y - ly > 60.0, "it lunges along its lane (%.0f px), never off it" % (e.position.y - ly))
	_until(w, func(): return e.state == "crawl", 2.0)
	# A hit knocks it off; it lies dazed, then crawls back and climbs on.
	_park(w, Vector2(10 * TILE, FLOOR_Y))
	_safe(w)
	e.tier = "anointed"
	e.max_hp = 999.0
	e.hp = 999.0
	w.deal(e, 1.0, {"how": "shot", "flat": 1.0, "from_x": e.position.x - 30.0})
	_check(not e.on_lane() and e.status.has("dazed"), "a hit knocks it off its lane, dazed")
	var back := _until(w, func(): return e.on_lane(), 8.0)
	_check(back > 1.2 and e.on_lane() and absf(e.position.x - x0) < 0.5, "it crawls back and climbs on again (%.1f s)" % back)
	await _done(w)
	# A stomp kills it.
	w = await _world(_creep_room())
	e = _spawn(w, "creepbone", Vector2i(20, 12))
	_park(w, Vector2(8 * TILE, FLOOR_Y))
	_safe(w)
	var res: Dictionary = w.deal(e, 1.0, {"how": "stomp", "flat": 999.0})
	_check(res["killed"], "a stomp kills it (fodder)")
	await _done(w)
	# On a wall face, beside a solid wall (placement vine_or_wall).
	var rows := _rows(40)
	for y in range(5, 13):
		_put(rows, 21, y, "#")
	w = await _world(rows)
	e = _spawn(w, "creepbone", Vector2i(20, 12))
	_check(e.on_lane() and not e.lane["vine"] and absf(e.position.x - (21 * TILE - 8)) < 0.5, "beside a wall it takes the wall face (%s)" % e.lane)
	await _done(w)
	# Witching: two share a lane.
	w = await _world(_creep_room(), "3-9", "witching")
	e = _spawn(w, "creepbone", Vector2i(20, 10))
	_step(w, 3)
	var n := 0
	for en in w.enemies:
		if en.kind == "creepbone" and en.alive:
			n += 1
	_check(n == 2, "Witching: two Creepbones share a lane (%d)" % n)
	await _done(w)


# ---------------------------------------------------------------- Tickwind

func _test_tickwind() -> void:
	var w := await _world(_rows(40), "4-9")
	var e := _spawn(w, "tickwind", Vector2i(20, 12), {"facing": -1})
	_park(w, Vector2(30 * TILE, FLOOR_Y))
	_safe(w)
	_step(w, 60)
	_check(e.state == "march", "it marches while he's behind it")
	# A hit on its back unwinds it.
	var res: Dictionary = w.deal(e, 1.0, {"how": "slash", "flat": 1.0, "from_x": e.position.x + 20.0})
	e.hp = e.max_hp
	_check(res["hit"] and e.state == "rundown" and absf(e.timer - 1.5) < 0.02, "a hit on its key unwinds it (run down 1.5 s)")
	await _done(w)
	# It charges; a wall leaves it dizzy.
	var rows := _rows(40)
	for y in range(8, 13):
		_put(rows, 8, y, "#")
	w = await _world(rows, "4-9")
	e = _spawn(w, "tickwind", Vector2i(20, 12), {"facing": -1})
	_park(w, Vector2(14 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "charge", 2.0)
	_park(w, Vector2(14 * TILE, FLOOR_Y - 200.0))
	w.player.velocity = Vector2.ZERO
	_safe(w)
	var x0: float = e.position.x
	_step(w, 12)
	_check(absf(x0 - e.position.x) / 0.1 > 280.0, "it charges at 300 px/s (%.0f)" % (absf(x0 - e.position.x) / 0.1))
	_until(w, func(): return e.state != "charge", 2.0)
	_check(e.status.has("dazed"), "into a wall: dizzy (+50%%)")
	await _done(w)
	# On ice it slides off an edge into a pit, and dies with how "pit".
	rows = _rows(40)
	for x in range(10, 26):
		_put(rows, x, 13, "I")
	for x in range(6, 10):
		for y in range(13, 15):
			_put(rows, x, y, ".")
	w = await _world(rows, "4-9")
	e = _spawn(w, "tickwind", Vector2i(24, 12), {"facing": -1})
	var how := [""]
	e.died.connect(func(_e, h): how[0] = h)
	_park(w, Vector2(15 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "charge", 2.0)
	w.player.reset_at(Vector2(3 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return not e.alive, 4.0)
	_check(not e.alive and how[0] == "pit", "on ice it slides off an edge and a pit takes it (how %s)" % how[0])
	await _done(w)
	# Off ice it stops after 1.6 s (run down).
	w = await _world(_rows(60), "4-9")
	e = _spawn(w, "tickwind", Vector2i(40, 12), {"facing": -1})
	_park(w, Vector2(34 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "charge", 2.0)
	w.player.reset_at(Vector2(34 * TILE, FLOOR_Y - 250.0))
	_safe(w)
	var run := _until(w, func(): return e.state != "charge", 3.0)
	_check(absf(run - 1.6) < 0.05 and e.state == "rundown", "on stone it charges 1.6 s, then runs down (%.2f)" % run)
	await _done(w)
	# A Perfect Guard (the knight's 1.0 s stagger) sends it back as a bowling ball.
	w = await _world(_rows(60), "4-9")
	e = _spawn(w, "tickwind", Vector2i(30, 12), {"facing": -1})
	var pin := _spawn(w, "skeleton", Vector2i(38, 12))
	_park(w, Vector2(24 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "charge", 2.0)
	e.apply_status("stun", 1.0)
	_check(e.state == "bowled" and e.charge_dir == 1, "a Perfect Guard sends it back")
	var sk_hp: float = pin.hp
	_until(w, func(): return e.state != "bowled", 3.0)
	_check(pin.hp < sk_hp or not pin.alive, "bowling over the monsters in its path")
	await _done(w)


# ---------------------------------------------------------------- Spurwheel

func _test_spurwheel() -> void:
	# Round a 3x3 block standing alone in the air: it goes all the way round
	# and comes back to where it started, catching at the outer corners.
	var rows := _rows(40)
	for y in range(5, 8):
		for x in range(18, 21):
			_put(rows, x, y, "#")
	var w := await _world(rows, "4-9")
	var e := _spawn(w, "spurwheel", Vector2i(19, 4), {"facing": 1})
	_park(w, Vector2(4 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "roll", 1.0)
	var start: Vector2 = e.hub()
	var catches := 0
	var corners := 0
	var far := 0.0
	var back := false
	for i in int(20.0 / DT):
		var was: String = e.state
		_step(w, 1)
		if was != "caught" and e.state == "caught":
			catches += 1
			if e._corner:
				corners += 1
		far = maxf(far, e.hub().distance_to(start))
		if far > 60.0 and e.hub().distance_to(start) < 3.0:
			back = true
			break
	_check(back, "a Spurwheel goes round a 3x3 block and comes back to its start (%.0f px out)" % far)
	_check(corners == 4, "it catches at every outer corner (%d of 4)" % corners)
	await _done(w)
	# In a World, the upright face overlay sits on the cog's hub (both facings,
	# Twinned too), and its eye glints on the face.
	w = await _world(_rows(40), "4-9")
	for f in [1, -1]:
		for sm in [1.0, 0.6]:
			var sp := _spawn(w, "spurwheel", Vector2i(12 if f > 0 else 28, 12), {"facing": f})
			sp.scale_mult = sm
			_step(w, 2)
			if sp.face == null:
				_check(sp.frames.is_empty(), "a Spurwheel with its art has its face overlay")
				continue
			sp._draw()   # (with its frames the draw only places the sprites)
			var fc: Vector2 = sp.transform * (sp.face.transform * sp.face.get_rect().get_center())
			var cc: Vector2 = sp.transform * (sp.sprite.transform * sp.sprite.get_rect().get_center())
			_check(fc.distance_to(sp.hub()) < 1.0 and cc.distance_to(sp.hub()) < 1.0,
					"the face's centre is the hub (facing %d, x%.1f): face %s, cog %s, hub %s" % [f, sm, fc, cc, sp.hub()])
			var fr: Rect2 = sp.face.get_rect()
			var inv: Transform2D = (sp.transform * sp.face.transform).affine_inverse()
			var on := true
			for eye in sp._face_eyes():
				on = on and fr.has_point(inv * (eye as Vector2))
			_check(on, "its eye glints are on the face (facing %d, x%.1f)" % [f, sm])
	await _done(w)
	# On a long floor: a catch every 2.5 s of rolling; rolling, hits clang.
	w = await _world(_rows(80), "4-9")
	e = _spawn(w, "spurwheel", Vector2i(10, 12), {"facing": 1})
	_park(w, Vector2(60 * TILE, FLOOR_Y - 200.0))
	_safe(w)
	_until(w, func(): return e.state == "roll", 1.0)
	var rolled := _until(w, func(): return e.state == "jam", 4.0)
	_check(absf(rolled - 2.5) < 0.05, "it jams after 2.5 s of rolling (%.2f)" % rolled)
	var hp0: float = e.hp
	_check(not w.deal(e, 1.0, {"how": "slash", "flat": 5.0})["hit"] and e.hp == hp0, "jammed (not yet caught), a hit clangs")
	_until(w, func(): return e.state == "caught", 1.0)
	_check(w.deal(e, 1.0, {"how": "slash", "flat": 5.0})["hit"] and e.hp < hp0, "caught, it takes the hit in full")
	var hold: float = e.timer
	w.deal(e, 1.0, {"how": "stomp", "flat": 1.0})
	_check(e.timer > hold + 0.45, "a stomp while caught holds the catch 0.5 s more")
	_until(w, func(): return e.state == "roll", 3.0)
	hp0 = e.hp
	_check(not w.deal(e, 1.0, {"how": "slash", "flat": 5.0})["hit"] and e.hp == hp0, "rolling, hit() is false (a clang)")
	_check(not e.stompable, "rolling, a stomp hurts him (spikes on top)")
	# The Bellfounder's maul forces a catch.
	var cls = w.kit.cls
	w.kit.cls = "founder"
	w.deal(e, 1.0, {"how": "slash", "flat": 5.0})
	w.kit.cls = cls
	_check(e.state == "caught", "the maul on a rolling Spurwheel forces a catch")
	# Grave Chill's root counts as one.
	_until(w, func(): return e.state == "roll", 3.0)
	e.apply_status("root", 1.2)
	_check(e.state == "caught", "a root is a catch")
	await _done(w)
	# The frost trail shows its route 3 tiles ahead.
	w = await _world(_rows(40), "4-9")
	e = _spawn(w, "spurwheel", Vector2i(10, 12), {"facing": 1})
	_until(w, func(): return e.state == "roll", 1.0)
	var route: PackedVector2Array = e.route_ahead()
	var len := 0.0
	for i in range(1, route.size()):
		len += route[i - 1].distance_to(route[i])
	_check(route.size() >= 2 and absf(len - 96.0) < 2.0 and route[route.size() - 1].x > route[0].x, "its frost trail runs 96 px ahead (%.0f)" % len)
	await _done(w)
	# On a floor between two pits (their walls run down to the level's open
	# bottom), and on one that runs to the level's edge: it keeps to the
	# floor's top, catches at each end and rolls back, and comes back to its
	# start. It never leaves the level.
	rows = _rows(60)
	for y in [13, 14]:
		for x in [8, 9, 30, 31, 32, 33]:
			_put(rows, x, y, ".")
	w = await _world(rows, "4-9")
	e = _spawn(w, "spurwheel", Vector2i(20, 12), {"facing": 1})
	var edge := _spawn(w, "spurwheel", Vector2i(4, 12), {"facing": -1})
	_park(w, Vector2(45 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "roll" and edge.state == "roll", 1.0)
	var starts := [e.hub(), edge.hub()]
	var box := Rect2(Vector2.ZERO, w.level.pixel_size())
	var inside := true
	var on_top := true
	var ends := [0, 0]
	var home := [false, false]
	var out := [0.0, 0.0]
	var xs := [[INF, -INF], [INF, -INF]]
	for i in int(24.0 / DT):
		var was := [e.state, edge.state]
		_step(w, 1)
		for j in 2:
			var s2: Node2D = [e, edge][j]
			var hb: Vector2 = s2.hub()
			inside = inside and s2.alive and box.has_point(hb) and hb.x >= 14.0 - 0.5
			on_top = on_top and absf(hb.y - (FLOOR_Y - 14.0)) < 0.5
			xs[j][0] = minf(xs[j][0], hb.x)
			xs[j][1] = maxf(xs[j][1], hb.x)
			if was[j] != "caught" and s2.state == "caught" and s2._reverse:
				ends[j] += 1
			out[j] = maxf(out[j], hb.distance_to(starts[j]))
			if out[j] > 120.0 and hb.distance_to(starts[j]) < 3.0:
				home[j] = true
	_check(inside, "the wheels never leave the level (a pit's wall, the level's edge)")
	_check(on_top, "they keep to the floor's top")
	_check(ends[0] >= 2 and home[0] and absf(xs[0][0] - 10.0 * TILE) < 1.0 and absf(xs[0][1] - 30.0 * TILE) < 1.0,
			"between two pits it catches at each lip and patrols back (%d ends, x %.0f to %.0f)" % [ends[0], xs[0][0], xs[0][1]])
	_check(ends[1] >= 2 and home[1] and absf(xs[1][0] - 14.0) < 1.0, "at the level's edge it catches and rolls back (%d ends, from x %.0f)" % [ends[1], xs[1][0]])
	await _done(w)
	# A wall that climbs out of the top of the level is an end too.
	rows = _rows(40)
	for y in range(0, 13):
		_put(rows, 30, y, "#")
	w = await _world(rows, "4-9")
	e = _spawn(w, "spurwheel", Vector2i(26, 12), {"facing": 1})
	_park(w, Vector2(4 * TILE, FLOOR_Y))
	_safe(w)
	var top_y := INF
	for i in int(4.0 / DT):
		_step(w, 1)
		top_y = minf(top_y, e.hub().y)
	_check(e.alive and absf(top_y - (FLOOR_Y - 14.0)) < 0.5 and e.facing == -1, "a wall to the level's top turns it back, never up it")
	await _done(w)
	# The knight's Perfect Guard catches a rolling wheel; a Peal's long stun doesn't.
	w = await _world(_rows(40), "4-9")
	e = _spawn(w, "spurwheel", Vector2i(10, 12), {"facing": 1})
	_park(w, Vector2(30 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "roll", 1.0)
	_step(w, 2)
	e.apply_status("stun", 1.2)
	_check(e.state == "roll", "a Peal's 1.2 s stun doesn't stop its teeth")
	if str(w.kit.cls) == "knight":
		w.kit._perfect({"source": e, "kind": "hit"}, "test")
		_check(e.state == "caught", "a Perfect Guard on it is a catch")
	await _done(w)


# ---------------------------------------------------------------- Frostbuckle

func _test_frostbuckle() -> void:
	var w := await _world(_rows(40), "4-9")
	var e := _spawn(w, "frostbuckle", Vector2i(20, 12), {"facing": -1})
	_park(w, Vector2(4 * TILE, FLOOR_Y))
	_safe(w)
	_check(absf(e.rime - 0.4 * e.max_hp) < 0.01, "its rime is 40%% of its life")
	# The rime takes the first 40%: no flinch until it breaks.
	var hp0: float = e.hp
	w.deal(e, 1.0, {"how": "shot", "flat": e.max_hp * 0.2})
	_check(absf(e.rime - 0.2 * e.max_hp) < 0.01 and absf(hp0 - e.hp - 0.2 * e.max_hp) < 0.01, "a blow takes the rime first")
	e.apply_status("stun", 0.5)
	_check(not e.status.has("stun"), "rimed, it doesn't stun")
	e.apply_status("root", 1.0)
	_check(not e.status.has("root"), "rimed, Grave Chill doesn't root it")
	# Fire x2.5 to the rime (a burn tick is fire).
	var r0: float = e.rime
	w.deal(e, 1.0, {"how": "burn", "flat": 2.0})
	_check(absf(r0 - e.rime - 5.0) < 0.01, "fire deals x2.5 to the rime (%.1f)" % (r0 - e.rime))
	# The maul and a stomp x2 to it, a Finisher x1.5.
	r0 = e.rime
	w.deal(e, 1.0, {"how": "stomp", "flat": 2.0})
	_check(absf(r0 - e.rime - 4.0) < 0.01, "a stomp deals x2 to the rime")
	r0 = e.rime
	var cls = w.kit.cls
	w.kit.cls = "founder"
	w.deal(e, 1.0, {"how": "slash", "flat": 2.0})
	w.kit.cls = cls
	_check(absf(r0 - e.rime - 4.0) < 0.01, "the maul deals x2 to the rime")
	# Breaking it shatters: a 1.2 s stun, poise 0.3.
	w.deal(e, 1.0, {"how": "shot", "flat": e.rime + 0.1})
	_check(e.rime <= 0.0 and e.status.has("stun") and absf(float(e.status["stun"]) - 1.2) < 0.02 and is_equal_approx(e.poise, 0.3),
			"breaking the rime shatters it: stunned 1.2 s, poise 0.3")
	# Warded (Sir Hoarfrost): a mote takes the blow, and the rime is untouched.
	var sir := _spawn(w, "frostbuckle", Vector2i(30, 12), {"tier": "dread", "omens": ["Warded", "Echoing"]})
	var sr0: float = sir.rime
	_check(not w.deal(sir, 1.0, {"how": "shot", "flat": 5.0})["hit"] and sir.rime == sr0 and sir.motes_up() == 2,
			"Warded: a mote takes the blow and the rime is untouched")
	sir.gone = true
	# It regrows after 8 s unhit, over the life it has: no healing.
	var hp1: float = e.hp
	_step(w, int(8.2 / DT))
	_check(e.rimed() and is_equal_approx(e.hp, hp1) and is_equal_approx(e.rime, minf(e.rime_max, e.hp)),
			"the rime regrows after 8 s unhit, over its life (%.1f of %.1f), with no heal" % [e.rime, e.hp])
	await _done(w)
	# The Frost Stomp: the spikes rise exactly on the tiles its crack showed,
	# and the line stops at a wall.
	var rows := _rows(40)
	for y in range(10, 13):
		_put(rows, 13, y, "#")
	w = await _world(rows, "4-9")
	e = _spawn(w, "frostbuckle", Vector2i(20, 12), {"facing": -1})
	_park(w, Vector2(16 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "stomp", 3.0)
	var cracks: Array = e.lines[0]["cells"].duplicate() if e.lines.size() > 0 else []
	_check(cracks.size() > 0 and cracks.size() <= 7 and cracks.min() > 13, "the crack runs toward him and stops at the wall (%s)" % [cracks])
	var spiked := {}
	var hurt_at := []
	for i in int(1.6 / DT):
		_step(w, 1)
		for ln in e.lines:
			for j in (ln["cells"] as Array).size():
				if e.spike_up(ln, j):
					spiked[int(ln["cells"][j])] = true
	var sk: Array = spiked.keys()
	sk.sort()
	var cs := cracks.duplicate()
	cs.sort()
	_check(sk == cs, "the spikes rise on exactly the cracked tiles (%s)" % [sk])
	await _done(w)
	# Standing on the line hurts; the Shield Slam hurts in front.
	w = await _world(_rows(40), "4-9")
	e = _spawn(w, "frostbuckle", Vector2i(20, 12), {"facing": -1})
	_park(w, Vector2(16 * TILE + 16, FLOOR_Y))
	hp0 = _hurt_count(w)
	_until(w, func(): return e.state == "recover", 3.0)
	_step(w, int(0.8 / DT))
	_check(_hurt_count(w) < hp0, "standing on the line, the spikes hurt him")
	await _done(w)
	w = await _world(_rows(40), "4-9")
	e = _spawn(w, "frostbuckle", Vector2i(20, 12), {"facing": -1})
	_park(w, Vector2(20 * TILE - 30, FLOOR_Y))
	hp0 = _hurt_count(w)
	_until(w, func(): return e.state == "recover", 3.0)
	_check(e.last_move == "slam", "close in front, it makes the Shield Slam")
	_check(_hurt_count(w) < hp0, "the Shield Slam hurts in front of it")
	await _done(w)
	# A Twinned half's rime is 40% of its own life (sized after the split).
	w = await _world(_rows(40), "4-9")
	_park(w, Vector2(4 * TILE, FLOOR_Y))
	_safe(w)
	e = _spawn(w, "frostbuckle", Vector2i(20, 12), {"tier": "anointed", "omens": ["Twinned"]})
	w.deal(e, 1.0, {"how": "skill", "flat": 1.0e6})
	_step(w, 2)
	var halves: Array = w.enemies.filter(func(o): return o.kind == "frostbuckle" and o.alive and o.get("copy"))
	_check(halves.size() == 2 and halves.all(func(o): return absf(o.rime - 0.4 * o.max_hp) < 0.01 and o.rime <= o.hp),
			"a Twinned half's rime is 40%% of its own life (%s)" % [halves.map(func(o): return "%.0f/%.0f" % [o.rime, o.max_hp])])
	await _done(w)
	# Rimed, a Perfect Guard on the slam staggers it; a Peal's stun doesn't.
	w = await _world(_rows(40), "4-9")
	e = _spawn(w, "frostbuckle", Vector2i(20, 12), {"facing": -1})
	_park(w, Vector2(20 * TILE - 30, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "slam", 3.0)
	e.apply_status("stun", 1.2)
	_check(e.state == "slam" and not e.status.has("stun"), "rimed, a Peal's 1.2 s stun doesn't stagger its slam")
	if str(w.kit.cls) == "knight":
		w.kit._perfect({"source": e, "kind": "hit"}, "test")
		_check(e.rimed() and e.status.has("stun") and e.state == "stand", "a Perfect Guard on the slam staggers it, rimed or not")
	await _done(w)
	# The Shield Slam's escape: Wick right in front reacts after 0.35 s and
	# runs; the 0.70 s tell gets him out of the 60 px slam.
	w = await _world(_rows(40), "4-9")
	e = _spawn(w, "frostbuckle", Vector2i(20, 12), {"facing": -1})
	w.player.reset_at(Vector2(e.position.x - 28.0, FLOOR_Y))
	w.player.invuln = 0.0
	var slam_t := _until(w, func(): return e.state == "slam", 3.0)
	var hp_s := _hurt_count(w)
	_step(w, int(0.35 / DT))
	_until(w, func(): return e.state == "recover", 1.5, {"left": true})
	_check(slam_t >= 0.0 and e.last_move == "slam" and not e._slam_hit and _hurt_count(w) == hp_s,
			"a 0.35 s reaction and a run clears the Shield Slam (%.0f px off at the strike)" % absf(w.player.position.x - e.position.x))
	await _done(w)
	# Nightfall: the line runs 9 tiles; Witching: a second line.
	w = await _world(_rows(40), "4-9", "nightfall")
	e = _spawn(w, "frostbuckle", Vector2i(30, 12), {"facing": -1})
	_park(w, Vector2(25 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "stomp", 3.0)
	_check(e.lines.size() == 1 and (e.lines[0]["cells"] as Array).size() == 9, "Nightfall: the line runs 9 tiles")
	await _done(w)
	w = await _world(_rows(40), "4-9", "witching")
	e = _spawn(w, "frostbuckle", Vector2i(30, 12), {"facing": -1})
	_park(w, Vector2(25 * TILE, FLOOR_Y))
	_safe(w)
	_until(w, func(): return e.state == "stomp", 3.0)
	_check(e.lines.size() == 2, "Witching: a second line, drawn from the start")
	await _done(w)


# ---------------------------------------------------------------- Hoarowl

func _test_hoarowl() -> void:
	# A stone pillar between them hides him.
	var rows := _owl_rows()
	for y in range(10, 13):
		_put(rows, 22, y, "#")
	var w := await _world(rows, "4-9")
	var e := _spawn(w, "hoarowl", Vector2i(20, 8))
	_park(w, Vector2(23 * TILE + 16, FLOOR_Y))
	_safe(w)
	var look := rad_to_deg((w.player.center() - e.eye_world()).angle())
	for i in int(1.0 / DT):
		e.look_hold = look
		_step(w, 1)
		e.look_hold = look
	_check(e.meter <= 0.0 and not e.spotted(w.player), "stone between them hides him")
	await _done(w)
	rows = _owl_rows()
	w = await _world(rows, "4-9")
	e = _spawn(w, "hoarowl", Vector2i(20, 8))
	_park(w, Vector2(22 * TILE + 16, FLOOR_Y))
	_safe(w)
	look = rad_to_deg((w.player.center() - e.eye_world()).angle())
	var t_fill := -1.0
	for i in int(2.0 / DT):
		e.look_hold = look
		_step(w, 1)
		e.look_hold = look
		if e.state == "screech":
			t_fill = (i + 1) * DT
			break
	_check(absf(t_fill - 0.60) < 0.03, "in the cone the meter fills in 0.60 s (%.2f)" % t_fill)
	var drops := []
	for h in w.hazards:
		if h.get("icicle", false):
			drops.append(h)
	_check(drops.size() == 3 and drops.all(func(h): return h["shadow"] and float(h["delay"]) >= 0.59),
			"the alarm drops 3 icicles, each with a floor shadow (%d)" % drops.size())
	if drops.size() == 3:
		var xs := drops.map(func(h): return (h["rect"] as Rect2).get_center().x)
		xs.sort()
		_check(absf(xs[1] - xs[0] - 40.0) < 0.1 and absf(xs[2] - xs[1] - 40.0) < 0.1, "40 px apart over where he is")
	# Leaving the cone drains it over 0.5 s.
	await _done(w)
	w = await _world(rows, "4-9")
	e = _spawn(w, "hoarowl", Vector2i(20, 8))
	var near := _spawn(w, "skeleton", Vector2i(26, 12))
	_park(w, Vector2(22 * TILE + 16, FLOOR_Y))
	_safe(w)
	look = rad_to_deg((w.player.center() - e.eye_world()).angle())
	for i in int(0.3 / DT):
		e.look_hold = look
		_step(w, 1)
	var m: float = e.meter
	for i in int(0.3 / DT):
		e.look_hold = 0.0
		_step(w, 1)
		e.look_hold = 0.0
	_check(m > 0.4 and absf(e.meter - maxf(0.0, m - 0.3 / 0.5)) < 0.05, "out of the cone the meter drains over 0.5 s")
	for i in int(1.0 / DT):
		e.look_hold = look
		_step(w, 1)
		e.look_hold = look
	_check(near.status.has("alerted"), "the alarm alerts the monsters near")
	await _done(w)
	# Two hits break it: the reference knight's (test_progression's) as he
	# enters 4-2 (L19, the XP budget), at its area (19).
	w = await _world(rows, "4-9", "dusk", "area: 19\n")
	e = _spawn(w, "hoarowl", Vector2i(20, 8))
	_park(w, Vector2(4 * TILE, FLOOR_Y))
	_safe(w)
	var hit := _ref_hit(19, 19)
	w.deal(e, 1.0, {"how": "slash", "flat": hit})
	var one: bool = e.alive
	w.deal(e, 1.0, {"how": "slash", "flat": hit})
	_check(one and not e.alive, "two of the reference knight's hits break it, one doesn't (%.0f a hit, %.0f life)" % [hit, e.max_hp])
	await _done(w)
	w = await _world(rows, "4-9")
	e = _spawn(w, "hoarowl", Vector2i(20, 8))
	# The sweep: 3.0 s across, a 0.8 s pause at each end, on the feature clock.
	var angles := []
	for i in int(7.6 / DT):
		_step(w, 1)
		angles.append(e.look)
	_check(absf(angles.max() - 160.0) < 0.5 and absf(angles.min() - 20.0) < 0.5, "it sweeps from left to right and back")
	await _done(w)
	# The icicles' escape: in the lowest space he can stand in (2 tiles),
	# a 0.35 s reaction and a run gets him out past the outer drop.
	rows = _rows(40)
	for x in range(0, 40):
		_put(rows, x, 10, "#")
	w = await _world(rows, "4-9")
	e = _spawn(w, "hoarowl", Vector2i(30, 9))
	_park(w, Vector2(15 * TILE, FLOOR_Y))
	var hp_i := _hurt_count(w)
	e._alarm(w.player)
	_step(w, int(0.35 / DT))
	_step(w, int(1.2 / DT), {"left": true})
	_check(_hurt_count(w) == hp_i, "under a low ceiling, a 0.35 s reaction and a run clears the icicles")
	await _done(w)
	w = await _world(rows, "4-9")
	e = _spawn(w, "hoarowl", Vector2i(30, 9))
	_park(w, Vector2(15 * TILE, FLOOR_Y))
	hp_i = _hurt_count(w)
	e._alarm(w.player)
	_step(w, int(1.2 / DT))
	_check(_hurt_count(w) < hp_i, "standing still under them, an icicle hits him")
	await _done(w)
	# An owl on a one-stone bracket is judged by the floor under its perch
	# (so it can be Anointed); over a pit it can't.
	rows = _owl_rows()
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\narea: 18\n---\n" + "\n".join(rows))
	_check(Elites.safe_for(lv, Vector2i(20, 8), "hoarowl") and not Elites.safe_cell(lv, Vector2i(20, 8)),
			"a Hoarowl on its bracket is judged by the floor under its perch")
	for x in range(16, 25):
		for y in [13, 14]:
			_put(rows, x, y, ".")
	lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\narea: 18\n---\n" + "\n".join(rows))
	_check(not Elites.safe_for(lv, Vector2i(20, 8), "hoarowl"), "over a pit it isn't safe ground")
	# Witching: every owl sweeps in step.
	w = await _world(_rows(60), "4-9", "witching")
	var a := _spawn(w, "hoarowl", Vector2i(10, 12))
	var b := _spawn(w, "hoarowl", Vector2i(37, 12))
	_step(w, 100)
	_check(absf(a.look - b.look) < 0.01, "Witching: owls sweep in step")
	await _done(w)


func _ref_hit(level: int, area: int) -> float:
	## test_progression's reference Candleknight's plain hit: Blessed gear at
	## ilvl = area, half his points in Honed Blade, Tempered Steel, Keen Edge.
	var Hero: GDScript = load("res://scripts/hero.gd")
	var Items: GDScript = load("res://scripts/items.gd")
	var h: Dictionary = Hero.blank("knight", level)
	h["equip"] = Items.starter("knight", area, "magic")
	var points: int = (level - 1) / 2
	var order := ["k_honed", "k_tempered", "k_keen"]
	var i := 0
	while points > 0 and i < 30:
		var id: String = order[i % order.size()]
		i += 1
		if int(h["skills"].get(id, 0)) < 2:
			h["skills"][id] = int(h["skills"].get(id, 0)) + 1
			points -= 1
	var st: Dictionary = Hero.stats(h, [], "dusk")
	return float(st["basic"]) * (1.0 + float(st["dmg_pct"]))


# ---------------------------------------------------------------- elites and Omen pools

static func _v2_roll(k: String, diff_id: String, r: RandomNumberGenerator, span: Vector2i) -> Array:
	## v2's roll_omens, for the identity check (W1-W2 pick the same Omens).
	var n := span.x if span.x == span.y else r.randi_range(span.x, span.y)
	var pool := []
	for o in ["Swift", "Warded", "Burning", "Twinned", "Vengeful"]:
		if {"Swift": ["lidlurk"], "Burning": ["brinejaw"]}.get(o, []).has(k):
			continue
		if diff_id == "dusk" and o == "Vengeful":
			continue
		pool.append(o)
	var out := []
	while out.size() < n and pool.size() > 0:
		var i := r.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


func _test_omen_pools() -> void:
	var r := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	var same := true
	for d in Combat.DIFFS:
		for wn in [0, 1, 2]:
			for k in ["skeleton", "bat", "thornback", "bonebow", "hollow_helm", "lidlurk", "brinejaw"]:
				for i in 60:
					r.seed = i * 7 + 3
					r2.seed = i * 7 + 3
					var rules := {"omens": int(Combat.diff(d)["omens"])}
					var a: Array = Elites.roll_omens(k, d, wn, r, rules)
					var b: Array = _v2_roll(k, d, r2, Elites.omen_span(d))
					if a != b or r.state != r2.state:
						same = false
	_check(same, "W1-W2 (and world 0) roll exactly v2's Omens from the same seed, drawing the same numbers")
	# The pools by world (spec §4.6).
	var pools := {}
	for wn in range(1, 7):
		for d in Combat.DIFFS:
			var seen := {}
			for i in 400:
				r.seed = i
				for o in Elites.roll_omens("tickwind", d, wn, r):
					seen[o] = true
			pools["%d%s" % [wn, d]] = seen
	for d in Combat.DIFFS:
		for wn in [1, 2]:
			_check(not (pools["%d%s" % [wn, d]] as Dictionary).keys().any(func(o): return Elites.V3_OMENS.has(o)), "W%d %s: no v3 Omen" % [wn, d])
	_check(pools["3dusk"].has("Sporebound") and not pools["3dusk"].has("Echoing") and not pools["3witching"].has("Glassed"), "W3: + Sporebound")
	_check(pools["4dusk"].has("Sporebound") and not pools["4dusk"].has("Echoing") and pools["4nightfall"].has("Echoing"),
			"W4: + Sporebound, and Echoing from Nightfall")
	_check(pools["5dusk"].has("Echoing") and pools["5dusk"].has("Glassed") and not pools["5witching"].has("Hushed"), "W5: + Echoing and Glassed")
	_check(pools["6dusk"].has("Hushed") and pools["6dusk"].has("Vengeful") and pools["6nightfall"].size() == 9, "W6: all nine (Vengeful on Dusk too)")
	_check(not pools["5dusk"].has("Vengeful"), "Vengeful stays off Dusk before W6")
	# NEVER_ON.
	var never_ok := true
	for o in Elites.NEVER_ON:
		for k in Elites.NEVER_ON[o]:
			for i in 200:
				r.seed = i
				if Elites.roll_omens(k, "witching", 6, r).has(o):
					never_ok = false
	_check(never_ok, "NEVER_ON holds (%s)" % [Elites.NEVER_ON.keys()])
	# Counts: Dusk (Build 1) a second Omen about 20% of the time in W3, 30%
	# in W4, 50% in W5, 60% in W6; never more than 3.
	for wn in [3, 4, 5, 6]:
		var twos := 0
		for i in 1000:
			r.seed = i
			var o: Array = Elites.roll_omens("skeleton", "dusk", wn, r, Combat.elite_rules("dusk", wn))
			if o.size() == 2:
				twos += 1
		var want: float = {3: 0.20, 4: 0.30, 5: 0.50, 6: 0.60}[wn]
		_check(absf(twos / 1000.0 - want) < 0.05, "Dusk W%d: a second Omen %.0f%% of the time (want %.0f%%)" % [wn, twos / 10.0, want * 100.0])
	var most := 0
	for i in 300:
		r.seed = i
		most = maxi(most, Elites.roll_omens("skeleton", "witching", 6, r, {"omens": 5}).size())
	_check(most <= 3, "never more than 3 Omens (%d)" % most)
	# Deterministic per seed.
	r.seed = 77
	var one: Array = Elites.roll_omens("frostbuckle", "nightfall", 4, r)
	r.seed = 77
	_check(Elites.roll_omens("frostbuckle", "nightfall", 4, r) == one, "the same seed rolls the same Omens")


func _test_elite_picks() -> void:
	## A W3 room full of eligible kinds on Witching: the same seed picks the
	## same elites; a Spurwheel is never picked.
	var rows := _rows(160)
	for x in range(20, 150, 8):
		_put(rows, x, 12, ["r", "m", "j", "q", "e", "p"][(x / 8) % 6])
	var picks := []
	for run in 2:
		var lv = LevelData.new()
		lv.parse("title: t\nsubtitle: t\narea: 14\n---\n" + "\n".join(rows))
		lv.id = "3-9"
		lv.world = 3
		game.reset()
		game.data["difficulty"] = "witching"
		game.data["run_counter"] = 5
		var w: Node2D = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await process_frame
		var cells := []
		for e in w.enemies:
			if e.tier == "anointed":
				cells.append([e.spawn["cell"], e.kind, e.omens.duplicate()])
		cells.sort()
		picks.append(cells)
		var bad := false
		for c in cells:
			if c[1] == "spurwheel":
				bad = true
		_check(not bad, "a Spurwheel is never Anointed")
		await _done(w)
	_check(picks[0] == picks[1] and not picks[0].is_empty(), "the same seed picks the same elites (%s)" % [picks[0]])


# ---------------------------------------------------------------- the new Omens

func _test_new_omens() -> void:
	var w := await _world(_rows(60), "4-9")
	_park(w, Vector2(5 * TILE, FLOOR_Y))
	_safe(w)
	# Sporebound: a spore cloud where it dies.
	var sp := _spawn(w, "skeleton", Vector2i(30, 12), {"tier": "anointed", "omens": ["Sporebound"]})
	var at: Vector2 = sp.center()
	w.deal(sp, 1.0, {"how": "skill", "flat": 9999.0})
	_check(w.features.spores_at(at), "Sporebound: it dies into a spore cloud")
	# Glassed: a 30% shell; heavy hits x2 to it, basic shots x0.5; no flinch;
	# breaking it stuns 1.0 s.
	var gl := _spawn(w, "rattlehound", Vector2i(40, 12), {"tier": "anointed", "omens": ["Glassed"]})
	_check(absf(gl._om_glass - 0.3 * gl.max_hp) < 0.01, "Glassed: a shell worth 30%% of its life")
	var hp0: float = gl.hp
	var g0: float = gl._om_glass
	w.deal(gl, 1.0, {"how": "shot", "flat": 4.0})
	_check(absf(g0 - gl._om_glass - 2.0) < 0.01 and gl.hp == hp0, "basic shots deal 50%% to the shell, and its life is untouched")
	g0 = gl._om_glass
	w.deal(gl, 1.0, {"how": "stomp", "flat": 3.0})
	_check(absf(g0 - gl._om_glass - 6.0) < 0.01, "a heavy hit (a stomp) deals x2 to it")
	w.deal(gl, 1.0, {"how": "skill", "flat": gl._om_glass})
	_check(gl._om_glass <= 0.0 and gl.status.has("stun") and absf(float(gl.status["stun"]) - 1.0) < 0.02, "breaking it stuns 1.0 s")
	await _done(w)
	# Echoing: a strike repeats 0.8 s later at the same place, at 60%.
	w = await _world(_rows(40), "4-9", "dusk", "area: 1\n")
	var ec := _spawn(w, "rootling", Vector2i(20, 12), {"tier": "anointed", "omens": ["Echoing"]})
	_park(w, Vector2(20 * TILE + 16, FLOOR_Y))
	_safe(w)
	_until(w, func(): return ec.state == "pop", 3.0)
	_check(ec._om_echoes.size() == 1, "Echoing: the pop is logged to repeat")
	var fired := _until(w, func(): return ec._om_echoes.size() > 0 and float(ec._om_echoes[0]["fired"]) >= 0.0, 1.5)
	_check(absf(fired - 0.8) < 0.03, "the echo strikes 0.8 s later (%.2f)" % fired)
	await _done(w)
	w = await _world(_rows(40), "4-9", "dusk", "area: 1\n")
	ec = _spawn(w, "rootling", Vector2i(20, 12), {"tier": "anointed", "omens": ["Echoing"]})
	_park(w, Vector2(20 * TILE + 16, FLOOR_Y))
	_safe(w)
	_until(w, func(): return ec.state == "pop", 3.0)
	var er0: Rect2 = ec._om_echoes[0]["rect"] if ec._om_echoes.size() > 0 else Rect2()
	_until(w, func(): return ec._om_echoes.size() > 0 and float(ec._om_echoes[0]["t"]) < 0.05, 1.5)
	ec.position.x += 120.0   # (out of the way: only the echo may touch him)
	w.player.reset_at(Vector2(er0.get_center().x, FLOOR_Y))
	w.player.invuln = 0.0
	var hp_a := _hurt_count(w)
	_step(w, 12)
	var took := hp_a - _hurt_count(w)
	var full: float = ec.dmg("pop") * (1.0 - float(w.player.stats.get("dr", 0.0)))
	_check(took > 0.0 and absf(took - full * 0.6) < 1.0, "at the same place, at 60%% of the blow (%.1f of %.1f)" % [took, full])
	await _done(w)
	# A shooter's echo copies the shot's vector; a beam's, its segment.
	w = await _world(_rows(40), "4-9")
	var sh := _spawn(w, "skeleton", Vector2i(20, 12), {"tier": "anointed", "omens": ["Echoing"]})
	_park(w, Vector2(5 * TILE, FLOOR_Y))
	_safe(w)
	sh.strike_logged({"kind": "arrow", "pos": Vector2(600, 380), "vel": Vector2(-300, 0), "owner": "enemy", "dmg": 10.0, "life": 1.0}, 10.0)
	sh.strike_logged({"kind": "beam", "seg": [Vector2(500, 300), Vector2(700, 300)], "width": 6.0, "life": 0.25, "dmg": 10.0,
			"owner": "enemy"}, 10.0)
	sh.strike_logged({"rect": Rect2(560, 380, 30, 36), "life": 0.2}, 10.0)
	# Every echo is drawn while it waits: the box, the shot's line, the beam's.
	_step(w, int(0.3 / DT))
	w.glow.queue_redraw()
	await process_frame
	await process_frame
	_check(sh._om_echoes.size() == 3 and sh.echo_marks == 3 and sh.echo_lines(sh._om_echoes[0]).size() == 1 and sh.echo_lines(sh._om_echoes[1]).size() == 1,
			"each waiting echo is drawn: a box, a shot's line, a beam's segment (%d of %d)" % [sh.echo_marks, sh._om_echoes.size()])
	_step(w, int(0.55 / DT))
	var arrows: Array = w.shots.filter(func(s2): return s2.get("echo", false))
	var beams: Array = w.hazards.filter(func(h): return h.get("echo", false) and h["kind"] == "beam")
	_check(arrows.size() == 1 and absf(float(arrows[0]["dmg"]) - 6.0) < 0.01 and (arrows[0]["vel"] as Vector2).x < 0.0,
			"Echoing: a shot is loosed again with its vector, at 60%")
	_check(not sh.echo_by_body and sh.echo_body_rect().size.x == 0.0, "a kind that logs its strikes leaves no body echo too")
	_check(beams.size() == 1 and absf(float(beams[0]["dmg"]) - 6.0) < 0.01, "and a beam is laid again along its segment")
	await _done(w)
	# A body echo: a touch-only kind leaves a pale echo of itself 0.8 s behind.
	w = await _world(_rows(40), "4-9")
	var bo := _spawn(w, "skeleton", Vector2i(20, 12), {"tier": "anointed", "omens": ["Echoing"]})
	_park(w, Vector2(5 * TILE, FLOOR_Y))
	_safe(w)
	var p0: Rect2 = bo.hurt_rect()
	_step(w, int(0.85 / DT))
	var er: Rect2 = bo.echo_body_rect()
	_check(er.size.x > 0.0 and absf(er.get_center().x - p0.get_center().x) < 4.0, "Echoing (by body): its echo walks 0.8 s behind it")
	await _done(w)
	# Hushed: silent, dark eyes, 0.15 outside light; its aura dims him x0.7.
	w = await _world(_rows(40), "6-9")
	var hu := _spawn(w, "skeleton", Vector2i(30, 12), {"tier": "anointed", "omens": ["Hushed"]})
	_park(w, Vector2(5 * TILE, FLOOR_Y))
	_safe(w)
	_step(w, 4)
	_check(absf(hu._om_alpha - 0.15) < 0.001, "Hushed: seen at 0.15 outside any light")
	_check(hu.eye_points().is_empty(), "its eyes go dark")
	_park(w, Vector2(29 * TILE, FLOOR_Y))
	_safe(w)
	_step(w, 4)
	_check(absf(hu._om_alpha - 1.0) < 0.001, "and whole inside his light")
	var dims: Dictionary = w.dims()
	_check(dims.has("hushed_omen") and absf(float((dims["hushed_omen"] as Dictionary).get("mult", (dims["hushed_omen"] as Dictionary).get("m", 0.0))) - 0.7) < 0.001,
			"its aura dims him x0.7 through the pipeline (%s)" % [dims.get("hushed_omen")])
	await _done(w)


# ---------------------------------------------------------------- Wardens and Dreads

func _test_wardens() -> void:
	# A Warden: WARDEN_LIFE of its secret level (x e_hp), damage x1.25, two Omens.
	var rows := _rows(40)
	for y in range(5, 13):
		_put(rows, 20, y, "{")
	_put(rows, 20, 10, "D")
	var w := await _world(rows, "3-S", "dusk", "warden: Nine-Knuckle Nell|creepbone|Warded,Vengeful\n")
	var nell: Node2D = w.warden
	_check(nell != null and nell.kind == "creepbone" and nell.tier == "warden" and nell.omens == ["Warded", "Vengeful"],
			"3-S's Warden spawns: a creepbone, tier warden, its Omens")
	if nell != null:
		var plain := _spawn(w, "creepbone", Vector2i(30, 12))
		_check(absf(nell.max_hp - 198.0 * Combat.e_hp(nell.area)) < 0.5, "its life is WARDEN_LIFE[3-S] (198) x e_hp (%.0f)" % nell.max_hp)
		_check(absf(nell.dmg("touch") / plain.dmg("touch") - 1.25) < 0.001, "its blows are x1.25 its kind's")
		_check(not nell.ordinary and nell.on_lane(), "not fodder, and on its lane")
	await _done(w)
	# Great-Aunt Hoot calls two Tickwinds instead of icicles.
	rows = _owl_rows()
	_put(rows, 20, 8, "D")
	w = await _world(rows, "4-S", "dusk", "warden: Great-Aunt Hoot|hoarowl|Warded,Echoing\n")
	var hoot: Node2D = w.warden
	_check(hoot != null and hoot.kind == "hoarowl" and hoot.tier == "warden", "4-S's Warden is Great-Aunt Hoot")
	if hoot != null:
		_park(w, Vector2(22 * TILE + 16, FLOOR_Y))
		_safe(w)
		var look := rad_to_deg((w.player.center() - hoot.eye_world()).angle())
		for i in int(1.0 / DT):
			hoot.look_hold = look
			_step(w, 1)
			hoot.look_hold = look
		var ticks := 0
		for e in w.enemies:
			if e.kind == "tickwind" and e.alive:
				ticks += 1
		var icicles: Array = w.hazards.filter(func(h): return h.get("icicle", false))
		_check(ticks == 2 and icicles.is_empty(), "her alarm calls 2 Tickwinds instead of icicles (%d)" % ticks)
	await _done(w)
	# Deacon Thistle (a Thornback Warden) charges twice.
	w = await _world(_rows(40), "1-S", "dusk")
	var th := _spawn(w, "thornback", Vector2i(20, 12), {"tier": "warden", "omens": ["Warded", "Burning"]})
	_park(w, Vector2(17 * TILE, FLOOR_Y))
	_safe(w)
	var braces := 0
	for i in int(3.0 / DT):
		var was: float = th.brace
		_step(w, 1)
		if was <= 0.0 and th.brace > 0.0:
			braces += 1
	_check(braces >= 2 and th.get("charges_left") != null, "Deacon Thistle charges twice (%d braces)" % braces)
	await _done(w)
	# The Empty Abbot (a Hollow Helm Warden) turns in 0.4 s.
	w = await _world(_rows(40), "2-S", "dusk")
	var ab := _spawn(w, "hollow_helm", Vector2i(20, 12), {"tier": "warden", "omens": ["Swift", "Vengeful"]})
	_check(absf(float(ab.turn_time()) - 0.4) < 0.001, "the Empty Abbot turns in 0.4 s (%.2f)" % float(ab.turn_time()))
	var helm := _spawn(w, "hollow_helm", Vector2i(30, 12))
	_check(absf(float(helm.turn_time()) - 0.55) < 0.001, "an ordinary Hollow Helm still turns in 0.55 s")
	await _done(w)


func _test_dreads() -> void:
	## The W3-W4 Dreads spawn from their levels' headers with their names and
	## Omens (the unknown-until-P1 Omens now work).
	var dreads := {"Mister Mandrake": ["rootling", ["Twinned", "Sporebound"], "3-1"], "The Widow Cap": ["weepcap", ["Warded", "Sporebound"], "3-2"],
			"Old Tatterjaw": ["rattlehound", ["Swift", "Burning"], "3-3"], "Sergeant Sprocket": ["tickwind", ["Swift", "Twinned"], "4-1"],
			"Sir Hoarfrost": ["frostbuckle", ["Warded", "Echoing"], "4-2"], "The Grindstone": ["spurwheel", ["Burning", "Echoing"], "4-3"]}
	for nm in dreads:
		var d: Array = dreads[nm]
		var rows := _rows(40)
		_put(rows, 20, 12, "D")
		var w := await _world(rows, d[2], "dusk", "dread: %s|%s|%s\n" % [nm, d[0], ",".join(d[1])])
		var found: Node2D = null
		for e in w.enemies:
			if e.tier == "dread":
				found = e
		_check(found != null and found.kind == d[0] and found.elite_name == nm and found.omens == d[1] and not found.ordinary,
				"%s's Dread, %s (%s)" % [d[2], nm, d[0]])
		if found != null:
			_park(w, Vector2(15 * TILE, FLOOR_Y))
			_safe(w)
			_step(w, int(3.0 / DT), {"right": false})
			_check(found.alive, "%s lives and acts for 3 s" % nm)
			if nm == "Mister Mandrake":
				w.deal(found, 1.0, {"how": "skill", "flat": 99999.0})
				_step(w, 3)
				var halves: Array = w.enemies.filter(func(e): return e.kind == "rootling" and e.alive and e.get("copy"))
				_check(halves.size() == 2, "Mister Mandrake splits into two Rootlings")
				_step(w, int(4.0 / DT))
				var under: Array = halves.filter(func(e): return e.buried())
				_check(under.size() == 2, "and the twins burrow separately (%d under)" % under.size())
		await _done(w)


# ---------------------------------------------------------------- the stand-ins draw

func _test_stand_in_draws() -> void:
	## Headless the stand-ins still build and flush their batches (the
	## screenshots check the look): every state of every kind, drawn a frame.
	var w := await _world(_rows(40), "4-9")
	_park(w, Vector2(5 * TILE, FLOOR_Y))
	_safe(w)
	var n := 0
	for k in MINE:
		var e := _spawn(w, k, Vector2i(20, 12), {"tier": "anointed", "omens": ["Echoing", "Glassed", "Hushed", "Sporebound"]})
		for s in ["idle", "buried", "swell", "pop", "walk", "crouch", "pounce", "coil", "lunge", "stretched", "wind", "charge",
				"jam", "caught", "respin", "stomp", "slam", "strike", "watch", "screech", "fallen"]:
			e.set("state", s)
			e.queue_redraw()
			await process_frame
			n += 1
		e.gone = true
		_step(w, 1)
	_check(n == MINE.size() * 21, "every stand-in drew every state")
	await _done(w)
	# Eyes in the dark (rule 4): the glow layer draws each kind's at r >= 3.
	w = await _world(_rows(40), "4-9")
	_park(w, Vector2(5 * TILE, FLOOR_Y))
	_safe(w)
	var eyes := {}
	for k in MINE:
		var e := _spawn(w, k, Vector2i(12, 12), {"tier": "anointed", "omens": ["Warded"]})
		e.active = true
		if k == "rootling":
			e._set_up(true)   # (buried, only its mound shows: no eyes)
			e.state = "walk"
		w.glow.queue_redraw()
		await process_frame
		await process_frame
		eyes[k] = e.eye_r_drawn
		e.gone = true
		_step(w, 1)
	_check(eyes.values().all(func(r): return r >= 3.0), "the glow layer draws every kind's eyes at r >= 3 (%s)" % [eyes])
	await _done(w)
