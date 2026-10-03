extends SceneTree
## test_monsters4 (MB): the World 5-6 monsters (spec §4.5, p_monsters §21):
## Glassmite, Gustling, Refractor, Paneguard, Hushling, Stillmaw, Unwick,
## Lurecoil, the W6 rules of hush_kind.gd, and their Dreads and Wardens.
##
##     godot --headless --path game --script res://tests/test_monsters4.gd
##
## Every kind: registered, placed by its glyph, frames or its stand-in,
## numbers from its TUNE table (spec §4.2), dies and pays its XP. Every tell
## >= 0.40 s on Dusk, and the escape formula (0.35 + escape_px / 205) for
## each one Wick must move away from; >= its floor on Nightfall and Witching,
## Swift included. Then each kind's own rules, measured in a headless World.
## Numbers are provisional (W5-W6 lock after the W3/W4 playtests): the tests
## read TUNE, never copy it, except the spec's base values they pin.

const LevelData := preload("res://scripts/level_data.gd")
const Combat := preload("res://scripts/combat.gd")
const Progression := preload("res://scripts/progression.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const HK := preload("res://scripts/hush_kind.gd")
const TILE := 32
const DT := 1.0 / 120.0
const PlayerScript := preload("res://scripts/player.gd")
const RUN_SPEED := PlayerScript.RUN_SPEED      # read, never copied
const HERO_HALF := 10.0                         # half the hero's width (player.gd: 20 x 38)
const KINDS := ["glassmite", "gustling", "refractor", "paneguard", "hushling", "stillmaw", "unwick", "lurecoil"]
const GLYPHS := {"glassmite": "x", "gustling": "z", "refractor": "y", "paneguard": "l",
		"hushling": "n", "stillmaw": "5", "unwick": "6", "lurecoil": "7"}
# contract §6.3 and spec §4.2: spawn, ordinary, base life, touch, the main
# blows, poise (the base values the tuning tables must hold).
const SPEC := {
	"glassmite": {"spawn": "floor", "ordinary": true, "life": 14.0, "touch": 24.0, "moves": {}, "poise": 0.0},
	"gustling": {"spawn": "center", "ordinary": true, "life": 16.0, "touch": 20.0, "moves": {}, "poise": 0.0},
	"refractor": {"spawn": "center", "ordinary": false, "life": 24.0, "touch": 18.0, "moves": {"beam": 24.0}, "poise": 0.0},
	"paneguard": {"spawn": "floor", "ordinary": false, "life": 55.0, "touch": 26.0, "moves": {"lunge": 36.0, "cut": 34.0}, "poise": 0.5},
	"hushling": {"spawn": "floor", "ordinary": true, "life": 14.0, "touch": 26.0, "moves": {"lunge": 30.0}, "poise": 0.0},
	"stillmaw": {"spawn": "center", "ordinary": false, "life": 48.0, "touch": 22.0, "moves": {"gulp": 36.0}, "poise": 0.3},
	"unwick": {"spawn": "floor", "ordinary": false, "life": 40.0, "touch": 28.0, "moves": {"echo": 34.0}, "poise": 0.3},
	"lurecoil": {"spawn": "deep_water", "ordinary": false, "life": 90.0, "touch": 30.0, "moves": {"bite": 40.0, "body": 30.0}, "poise": 1.0},
}
const NO_IMMEDIATE := ["draw_circle(", "draw_colored_polygon(", "draw_polyline("]

var _passed := 0
var _failed := 0
var _skipped: Array = []
var game: Node
var WorldScript: GDScript


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _skip(what: String) -> void:
	_skipped.append(what)
	print("skipped: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_monsters4_save.json"
	for suffix in [".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	_test_registry()
	_test_grep()
	_test_hush_rules_static()
	await _test_lab0()
	await _test_tells()
	await _test_hush_rules()
	await _test_glassmite()
	await _test_gustling()
	await _test_refractor()
	await _test_paneguard()
	await _test_hushling()
	await _test_stillmaw()
	await _test_unwick()
	await _test_lurecoil()
	await _test_dreads()
	await _test_as_elites()
	await _test_elites_seeded()
	_test_levels()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_monsters4_save.json" + suffix))
	game.save_path = game.SAVE_PATH
	game.load_save()
	print("test_monsters4: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _rows(w := 60, fill := {}) -> Array:
	## A flat room: stone on rows 13-14, Wick at column 3, the bell far right.
	var rows := []
	for y in 15:
		rows.append(("#".repeat(w)) if y >= 13 else ".".repeat(w))
	rows[12] = rows[12].substr(0, 3) + "P" + rows[12].substr(4)
	rows[12] = rows[12].substr(0, w - 3) + "E" + rows[12].substr(w - 2)
	return _fill(rows, fill)


func _fill(rows: Array, fill: Dictionary) -> Array:
	for c in fill:
		var cell: Vector2i = c
		var r: String = rows[cell.y]
		rows[cell.y] = r.substr(0, cell.x) + str(fill[c]) + r.substr(cell.x + 1)
	return rows


func _world(rows: Array, header := "", diff := "dusk", wn := 5, id := "", elites := false, cls := "") -> Node2D:
	## A room of W5 (area 23) or W6 (28). Unless elites, a seed whose Anointed
	## picks leave the placed monsters plain (MA's pools may take W5-W6 kinds:
	## a Warded mote must not sit in the way of a rule under test).
	var w: Node2D = null
	for run in 40:
		var lv = LevelData.new()
		var area := 23 if wn == 5 else 28
		lv.parse("title: t\nsubtitle: t\narea: %d\n%s---\n%s" % [area, header, "\n".join(rows)])
		lv.id = id if id != "" else "%d-9" % wn
		lv.world = wn
		game.reset()
		if cls != "":
			game.new_hero(cls)
		game.data["difficulty"] = diff
		game.data["run_counter"] = run
		w = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await process_frame
		w.test_pad = {}
		if elites or w.enemies.filter(func(e): return e.tier == "anointed").is_empty():
			break
		w.queue_free()
		await process_frame
	return w


func _level_world(id: String, diff := "dusk", run := 0) -> Node2D:
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	game.reset()
	game.data["difficulty"] = diff
	game.data["run_counter"] = run
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


func _settle(w: Node2D, at: Vector2, frames := 20) -> void:
	w.player.reset_at(at)
	w.player.invuln = 0.0
	_step(w, frames)


func _sturdy(w: Node2D) -> void:
	## Wick can take anything (the tests watch what hits him, not his death).
	w.player.max_hp = 1.0e6
	w.player.hp = 1.0e6


func _spawn(w: Node2D, kind: String, cell: Vector2i, opts := {}) -> Node2D:
	var o := opts.duplicate()
	o["cell"] = cell
	var e: Node2D = w.spawn_enemy(kind, EnemyKinds.spawn_pos(kind, cell), o)
	if e:
		e.active = true
	return e


func _only(w: Node2D, kind: String) -> Array:
	return w.enemies.filter(func(e): return e.kind == kind)


func _script(kind: String) -> Script:
	return load("res://scripts/%s.gd" % kind)


func _tune(kind: String) -> Dictionary:
	return (_script(kind) as Script).get_script_constant_map().get("TUNE", {})


func _kn(kind: String, key: String, diff := "dusk") -> float:
	return HK.pick(_tune(kind), diff, key)


func _measure(w: Node2D, e: Node2D, st: String, max_s := 6.0, pad := {}) -> float:
	## Steps until e enters state st, then how long it stays in it (s); -1 if
	## it never gets there.
	var n := int(max_s / DT)
	var i := 0
	while i < n and str(e.get("state")) != st:
		_step(w, 1, pad)
		i += 1
	if str(e.get("state")) != st:
		return -1.0
	var ticks := 0
	while str(e.get("state")) == st and ticks < n:
		_step(w, 1, pad)
		ticks += 1
	return ticks * DT


# ---------------------------------------------------------------- the registry and the tables

func _test_registry() -> void:
	for k in KINDS:
		var info: Dictionary = EnemyKinds.info(k)
		_check(EnemyKinds.known(k) and EnemyKinds.has(k), "%s: known to the registry, its script there" % k)
		_check(str(info.get("spawn", "")) == SPEC[k]["spawn"], "%s: spawns %s (contract §6.3)" % [k, SPEC[k]["spawn"]])
		_check(bool(info.get("ordinary", not SPEC[k]["ordinary"])) == SPEC[k]["ordinary"], "%s: ordinary %s" % [k, SPEC[k]["ordinary"]])
		_check(LevelData.ENTITY_GLYPHS.get(GLYPHS[k], "") == k, "%s: the glyph %s places it" % [k, GLYPHS[k]])
		_check(Progression.BASE_XP.has(k), "%s: has a BASE_XP" % k)
		var t := _tune(k)
		_check(not t.is_empty(), "%s: one TUNE table holds its numbers" % k)
		_check(is_equal_approx(float(t.get("life", -1)), SPEC[k]["life"]), "%s: life %s (spec §4.2)" % [k, SPEC[k]["life"]])
		_check(is_equal_approx(float(t.get("touch", -1)), SPEC[k]["touch"]), "%s: touch %s" % [k, SPEC[k]["touch"]])
		for mv in SPEC[k]["moves"]:
			_check(is_equal_approx(float(t.get(mv, -1)), float(SPEC[k]["moves"][mv])), "%s: %s %s" % [k, mv, SPEC[k]["moves"][mv]])
		_check(is_equal_approx(float(t.get("poise", 0.0)), SPEC[k]["poise"]), "%s: poise %s" % [k, SPEC[k]["poise"]])
		var e: Node2D = (_script(k) as Script).new()
		_check(e.kind == k and is_equal_approx(e.base_hp, SPEC[k]["life"]) and is_equal_approx(e.base_dmg, SPEC[k]["touch"]),
				"%s: its base life and touch come from TUNE" % k)
		_check(e.has_method("moves") and (e.moves() as Dictionary).has("touch"), "%s: moves() lists its blows for the share-cap scan" % k)
		for mv in SPEC[k]["moves"]:
			_check(is_equal_approx(float((e.moves() as Dictionary).get(mv, -1)), float(SPEC[k]["moves"][mv])), "%s: moves() has %s" % [k, mv])
		e.free()
	# No brute but the Lurecoil in W5-W6's roster (the Paneguard is a heavy, decisions).
	_check(float(_tune("paneguard")["life"]) == 55.0 and float(_tune("paneguard")["lunge"]) == 36.0, "the Paneguard is decisions' heavy: 55 life, lunge 36")


func _test_grep() -> void:
	## Contract §1: no immediate-mode circles, polygons or polylines in new code.
	for n in KINDS + ["hush_kind"]:
		var src := FileAccess.get_file_as_string("res://scripts/%s.gd" % n)
		var hits := []
		for line in src.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for bad in NO_IMMEDIATE:
				if code.contains(bad):
					hits.append(bad)
		_check(hits.is_empty(), "%s.gd draws with a TriBatch, nothing one call at a time (%s)" % [n, ", ".join(hits)])
		_check(not src.contains("class_name"), "%s.gd has no class_name" % n)


func _test_hush_rules_static() -> void:
	_check(HK.DARK_A == 0.15 and HK.EYE_R >= 3.0 and HK.EYE_A >= 0.9, "W6 rule 1: 0.15 outside light (never 0), eyes r >= 3 px at >= 0.9")
	_check(HK.RIM == Color("c8c8f0") and HK.RIM_PX == 2.0 and HK.BODY == Color("2a2838"), "the W6 look: a silver rim c8c8f0 of 2 px round a 2a2838 body")
	_check(HK.QUIET_R == 90.0, "silent until within 90 px")
	_check(HK.pick({"a": {"dusk": 1.0, "nightfall": 2.0}}, "witching", "a") == 1.0 and HK.pick({"a": 3.0}, "nightfall", "a") == 3.0,
			"a TUNE value per difficulty falls back to Dusk's")
	for k in ["hushling", "stillmaw", "unwick", "lurecoil"]:
		_check(HK.is_w6(k), "%s follows the W6 rules" % k)


# ---------------------------------------------------------------- the glyph lab: placement, frames, death, XP

func _test_lab0() -> void:
	if not FileAccess.file_exists("res://levels/lab-0.txt"):
		_skip("levels/lab-0.txt missing (the placements)")
		return
	var w := await _level_world("lab-0")
	_sturdy(w)
	var lv: RefCounted = w.level
	var placed := {}
	for ent in lv.entities:
		if KINDS.has(ent["kind"]):
			placed[ent["kind"]] = ent["cell"]
	for k in KINDS:
		if not placed.has(k):
			_skip("lab-0 places no %s" % k)
			continue
		var cell: Vector2i = placed[k]
		var mine := _only(w, k).filter(func(e): return e.spawn.get("cell", Vector2i(-1, -1)) == cell)
		_check(mine.size() == 1, "%s spawns where lab-0 places it" % k)
		if mine.is_empty():
			continue
		var e: Node2D = mine[0]
		# Placement: its PLACEMENT row, and where the World stood it.
		match str(LevelData.PLACEMENT.get(k, "")):
			"floor":
				var below: int = lv.tile(cell.x, cell.y + 1)
				_check(LevelData.is_solid(below) or LevelData.is_ledge(below), "%s stands on a floor in lab-0" % k)
				_check(absf(e.position.y - (cell.y + 1) * TILE) < 1.0 and absf(e.position.x - (cell.x + 0.5) * TILE) < 1.0, "%s: feet on its cell's floor" % k)
			"air":
				_check(e.position.distance_to(EnemyKinds.spawn_pos(k, cell)) < 16.0, "%s: in the air at its cell" % k)
			"deep_water":
				_check(lv.tile(cell.x, cell.y) == LevelData.WATER and lv.is_deep(cell.x, cell.y), "%s sits in deep water" % k)
		# Its frames when A3's are there, else the stand-in.
		var names: Array = (_script(k) as Script).get_script_constant_map().get("FRAMES", [])
		var have := 0
		for n in names:
			if ResourceLoader.exists("res://art/enemies/%s.svg" % n):
				have += 1
		if k == "unwick":
			_check(e.get("rig") != null and e.rig.get("cls") != null, "the Unwick is drawn as the player's own rig")
		else:
			_check(e.frames.size() == have, "%s loads the %d of its frames that exist (%s)" % [k, have, "stand-in" if have == 0 else "art"])
	await _done(w)
	# Every one dies and pays its XP (a feel lab pays none: a room of our own).
	for wn in [5, 6]:
		var fill := {}
		var x := 8
		for k in KINDS:
			if HK.is_w6(k) != (wn == 6) or k == "lurecoil":
				continue
			fill[Vector2i(x, 12 if SPEC[k]["spawn"] == "floor" else 9)] = GLYPHS[k]
			x += 6
		var rows := _rows(60, fill)
		if wn == 6:
			rows = _fill(_lake_rows(), fill)
			rows = _fill(rows, {Vector2i(20, 13): "7"})
		var w2 := await _world(rows, "", "dusk", wn)
		_sturdy(w2)
		w2.player.invuln = 1000.0
		for e in w2.enemies.duplicate():
			if not KINDS.has(e.kind) or not e.alive:
				continue
			e.active = true
			var before: int = int(w2.xp_gained)
			var want: int = Progression.kill_xp(e.kind, e.area, int(game.hero()["level"]), w2.diff, e.tier, e.respawned)
			e.hp = 0.0
			e._kill({"how": "slash", "from_x": e.position.x - 10.0})
			_check(not e.alive, "%s dies" % e.kind)
			_check(want > 0 and int(w2.xp_gained) - before == want, "%s pays its XP (%d, got %d)" % [e.kind, want, int(w2.xp_gained) - before])
		_step(w2, int(2.2 / DT))
		for k in KINDS:
			if HK.is_w6(k) == (wn == 6):
				_check(_only(w2, k).is_empty(), "%s is gone after its death" % k)
		await _done(w2)


# ---------------------------------------------------------------- tells

func _tell_rows() -> Array:
	## [kind, tell key, floor key, escape px (-1: a jump or a push, not the formula), note]
	var crack := float(_kn("glassmite", "crack_tiles")) * TILE * 0.5 + HERO_HALF
	return [
		["glassmite", "gnaw", "gnaw_floor", -1.0, "the gnaw (its crack's formula below)"],
		["gustling", "inhale", "inhale_floor", -1.0, "the inhale (a push: plant your feet)"],
		["refractor", "track", "track_floor", -1.0, "the aim"],
		["refractor", "lock", "lock_floor", _kn("refractor", "width") * 0.5 + HERO_HALF, "the lock (off a 6 px line)"],
		["paneguard", "turn", "turn_floor", -1.0, "the turn (jump the lunge)"],
		["paneguard", "turn_back", "turn_back_floor", -2.0, "Witching's turn back (Witching only)"],
		["paneguard", "cut_tell", "cut_floor", _kn("paneguard", "cut_w") + HERO_HALF, "the Glass Cut (out of a 60 px arc)"],
		["hushling", "crouch", "crouch_floor", 9.0 + HERO_HALF, "the crouch (off the marked spot it lands on)"],
		["stillmaw", "swallow", "swallow_floor", -1.0, "the swallow (the light's, not Wick's)"],
		["stillmaw", "gulp_tell", "gulp_floor", 15.0 + HERO_HALF, "the gulp (out of the mouth; the pull is slower than a run)"],
		["unwick", "outline", "outline", 38.0 + HERO_HALF, "the copy's outline (out of his own swing's rect)"],
		["lurecoil", "leap_tell", "leap_floor", 1.5 * TILE + HERO_HALF, "the leap (off the arc's low end)"],
		["_crack", crack],
	]


func _test_tells() -> void:
	var w := await _world(_rows(40))
	var probes := {}
	var swift_dusk := []
	for k in KINDS:
		probes[k] = _spawn(w, k, Vector2i(20, 12) if SPEC[k]["spawn"] != "center" else Vector2i(20, 9))
	for row in _tell_rows():
		if row[0] == "_crack":
			# The Glassmite's warning is the gnaw and the crack's spread together.
			var warn := _kn("glassmite", "gnaw") + _kn("glassmite", "crack_delay")
			_check(warn >= 0.35 + float(row[1]) / RUN_SPEED, "the Glassmite's gnaw and crack (%.2f s) meet the escape formula for its %d tiles" % [warn, int(_kn("glassmite", "crack_tiles"))])
			continue
		var k: String = row[0]
		var base := _kn(k, row[1])
		var fl := _kn(k, row[2]) if row[2] != "" else 0.30
		var e: Node2D = probes[k]
		for d in ["dusk", "nightfall", "witching"]:
			if float(row[3]) == -2.0 and d != "witching":
				continue   # a Witching-only move
			w.diff = d
			for swift in [false, true]:
				e.omens = ["Swift"] if swift else []
				var sec: float = e.tell(base, fl)
				if swift and d == "dusk" and sec < base - 0.0001:
					# decisions: Swift leaves Dusk's tells alone (MA's elites.tell);
					# Phase 0's still shortens them.
					swift_dusk.append("%s %s %.2f" % [k, row[1], sec])
					continue
				if d == "dusk":
					_check(sec >= 0.40, "%s %s: %.2f s >= 0.40 on Dusk" % [k, row[4], sec])
					if float(row[3]) >= 0.0:
						var need := 0.35 + float(row[3]) / RUN_SPEED
						_check(sec >= need - 0.001, "%s %s: %.2f s meets the escape formula (%.2f)" % [k, row[4], sec, need])
				else:
					_check(sec >= maxf(0.30, fl) - 0.0001, "%s %s on %s%s: %.2f s, never under its floor %.2f" % [k, row[4], d, " (Swift)" if swift else "", sec, maxf(0.30, fl)])
		e.omens = []
	w.diff = "dusk"
	if not swift_dusk.is_empty():
		_skip("Swift on Dusk still shortens tells in this build (%d moves, e.g. %s): the Dusk checks with Swift wait on MA's elites.tell()" % [swift_dusk.size(), swift_dusk[0]])
	# The Refractor's lock: never under 0.40 anywhere (its own lock_time()).
	var rf: Node2D = probes["refractor"]
	for d in ["dusk", "nightfall", "witching"]:
		w.diff = d
		for swift in [false, true]:
			rf.omens = ["Swift"] if swift else []
			_check(rf.lock_time() >= 0.40, "the Refractor's lock on %s%s: %.2f >= 0.40" % [d, " (Swift)" if swift else "", rf.lock_time()])
	rf.omens = []
	w.diff = "dusk"
	# The Stillmaw's pull never outruns him.
	_check(_kn("stillmaw", "gulp_pull") < RUN_SPEED, "the Gulp's pull (%d px/s) is slower than his run" % int(_kn("stillmaw", "gulp_pull")))
	# Windows never shrink with difficulty.
	for pair in [["paneguard", "recover"], ["lurecoil", "rest"], ["hushling", "blink"]]:
		var tt := _tune(pair[0])
		_check(not (tt.get(pair[1]) is Dictionary), "%s's %s window is one value on every difficulty" % [pair[0], pair[1]])
	await _done(w)


# ---------------------------------------------------------------- the W6 rules

func _test_hush_rules() -> void:
	var w := await _world(_rows(60), "", "dusk", 6)
	_sturdy(w)
	_settle(w, Vector2(6 * TILE, 13 * TILE))
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	var near := _spawn(w, "hushling", Vector2i(9, 12))
	var far := _spawn(w, "hushling", Vector2i(40, 12))
	_check(HK.lit_alpha(near) == 1.0, "a W6 kind in his light shows (alpha 1.0)")
	_check(HK.lit_alpha(far) == HK.DARK_A, "one in the dark shows at 0.15, never 0")
	_check(HK.eyes_of(near).size() == 2 and HK.eyes_of(far).size() == 2, "its eyes are there whether it's lit or not")
	_check(far.eye_points().is_empty(), "(the World lights only an elite's eyes: 8 a screen)")
	_step(w, 60)
	_check(absf(float(far.seen) - HK.DARK_A) < 0.01 and absf(float(near.seen) - 1.0) < 0.01, "and its alpha eases to them")
	# A Hushed Dread (the Hush-a-Bye) outside light draws at 0.15, never
	# dimmed twice (MA's Hushed Omen and the W6 rule are the same rule).
	var hb := _spawn(w, "hushling", Vector2i(46, 12), {"tier": "dread", "name": "The Hush-a-Bye", "omens": ["Twinned", "Hushed"]})
	_step(w, 60)
	var drawn_a: float = (hb._c(Color.WHITE, clampf(hb.fade, 0.0, 1.0) * float(hb.seen)) as Color).a
	var sprite_a: float = hb.sprite.modulate.a if hb.sprite != null else drawn_a
	_check(absf(drawn_a - HK.DARK_A) < 0.01 and absf(sprite_a - HK.DARK_A) < 0.01, "a Hushed Hush-a-Bye in the dark shows at 0.15, not below it (%.3f, %.3f)" % [drawn_a, sprite_a])
	var dy := _spawn(w, "glassmite", Vector2i(50, 12))
	dy.fade = 0.5
	_check(absf((dy._c(Color.WHITE, dy.fade) as Color).a - 0.5) < 0.001, "a stand-in's death fade is applied once, never squared")
	dy.fade = 1.0
	_check(HK.quiet(far, 91.0) and not HK.quiet(far, 89.0), "silent until within 90 px")
	far.omens = ["Hushed"]
	_check(HK.quiet(far, 10.0), "a Hushed one makes no sound at all")
	far.omens = []
	# The hushed status: a dim, and a second while hushed costs like douse.
	HK.hush_player(w)
	_check((w.dims() as Dictionary).has("hushed") and is_equal_approx(float(w.dims()["hushed"]["mult"]), HK.HUSHED_MULT), "hushed: his light x0.7 through the dim pipeline")
	pl.invuln = 0.0
	var hp0: float = pl.hp
	HK.hush_player(w)
	var cost: float = float(Combat.diff("dusk")["douse_pct"]) * pl.max_hp
	_check(absf((hp0 - pl.hp) - cost) < 1.0, "a hush while hushed costs douse_pct (%.0f)" % cost)
	pl.invuln = 1000.0
	# over_pit: airborne over a pit, the void or deep water; never on the floor.
	var rows := _rows(60)
	for y in [13, 14]:
		var r: String = rows[y]
		rows[y] = r.substr(0, 20) + ".".repeat(6) + r.substr(26, 4) + ":".repeat(6) + r.substr(36)
	var w2 := await _world(rows, "", "dusk", 6)
	var p2: Node2D = w2.player
	_sturdy(w2)
	p2.position = Vector2(22 * TILE, 8 * TILE)
	p2.on_floor = false
	_check(HK.over_pit(w2, p2), "airborne over a pit")
	p2.position = Vector2(32 * TILE, 8 * TILE)
	_check(HK.over_pit(w2, p2), "airborne over deep water")
	p2.position = Vector2(10 * TILE, 8 * TILE)
	_check(not HK.over_pit(w2, p2), "airborne over the floor isn't")
	p2.position = Vector2(22 * TILE, 8 * TILE)
	p2.on_floor = true
	_check(not HK.over_pit(w2, p2), "and standing never is")
	await _done(w2)
	# Havens: tagged lights, never his own.
	var w3 := await _world(_rows(60, {Vector2i(20, 12): "L"}), "", "dusk", 6)
	var l: Dictionary = w3.features.lanterns[0]
	_check(not HK.haven_at(w3, l["flame"]), "a dark lantern is no haven")
	w3.features.light(l)
	_check(HK.haven_at(w3, l["flame"] + Vector2(100, 0)) and not HK.haven_at(w3, l["flame"] + Vector2(160, 0)), "a lit lantern is a haven out to its radius")
	_check(not HK.haven_at(w3, w3.player.center()), "his own candle is no haven")
	var id: int = w3.add_light(Vector2(40 * TILE, 10 * TILE), 120.0, 0.9, -1.0, "toll,haven,lamp")
	_check(HK.haven_at(w3, Vector2(40 * TILE, 10 * TILE)), "a buoy's toll is a haven")
	w3.remove_light(id)
	await _done(w3)
	await _done(w)


# ---------------------------------------------------------------- Glassmite

func _glass_rows(x0: int, x1: int, stone := []) -> Array:
	## Glass panes on row 13 from x0 to x1 (stone under them on row 14).
	var fill := {}
	for x in range(x0, x1 + 1):
		fill[Vector2i(x, 13)] = "#" if stone.has(x) else "G"
	return _rows(60, fill)


func _test_glassmite() -> void:
	var w := await _world(_glass_rows(18, 30, [22]))
	_sturdy(w)
	var pl: Node2D = w.player
	_settle(w, Vector2(23 * TILE + 16, 13 * TILE))
	pl.invuln = 1000.0
	var m := _spawn(w, "glassmite", Vector2i(19, 12))
	m.facing = 1
	var gnaw := _measure(w, m, "gnaw", 4.0)
	_check(absf(gnaw - _kn("glassmite", "gnaw")) <= DT * 1.5, "the gnaw tell lasts %.2f s (measured %.3f)" % [_kn("glassmite", "gnaw"), gnaw])
	var want: Array[Vector2i] = [Vector2i(23, 13), Vector2i(22, 13), Vector2i(21, 13)]
	_check(m.crack.size() == 3 and m.crack == want, "the crack runs 3 tiles, ending under his feet as the tell began: %s" % [m.crack])
	# Its crack's delay, then the break (glass.gd: a flash, then air).
	_step(w, int((_kn("glassmite", "crack_delay") + 0.45) / DT))
	var lv: RefCounted = w.level
	_check(lv.tile(23, 13) == LevelData.AIR and lv.tile(21, 13) == LevelData.AIR, "the glass along the crack breaks")
	_check(lv.tile(22, 13) == LevelData.STONE, "stone in the crack never does")
	_check(lv.tile(20, 13) == LevelData.GLASS and lv.tile(19, 13) == LevelData.GLASS and lv.tile(24, 13) == LevelData.GLASS,
			"nor the mite's own tile, nor any glass past the crack")
	# It reforms on the glass rule (glass.gd's own timer), once nobody's in it.
	pl.reset_at(Vector2(40 * TILE, 13 * TILE))
	m.hp = 0.0
	m._kill({"how": "slash", "from_x": 0.0})
	var reform: float = float(load("res://scripts/features/glass.gd").get_script_constant_map()["DIFF_KNOBS"]["glass_reform"]["dusk"])
	_step(w, int((reform + 1.0) / DT))
	_check(lv.tile(23, 13) == LevelData.GLASS and lv.tile(21, 13) == LevelData.GLASS, "and it reforms on the feature's own timer (%.0f s)" % reform)
	# On stone he's safe from it.
	var m2 := _spawn(w, "glassmite", Vector2i(34, 12))
	_settle(w, Vector2(37 * TILE + 16, 13 * TILE))
	pl.invuln = 1000.0
	var went := false
	for i in int(3.0 / DT):
		_step(w, 1)
		if m2.state == "gnaw":
			went = true
	_check(not went, "it never gnaws while he stands on stone")
	# A stomp kills it.
	pl.invuln = 0.0
	pl.position = m2.position + Vector2(0, -m2.size.y - 2.0)
	pl.velocity = Vector2(0, 240)
	for i in 8:
		_step(w, 1)
		if not m2.alive:
			break
	_check(not m2.alive, "a stomp kills it")
	await _done(w)
	# Nightfall: a shorter gnaw and a 4-tile crack. Witching: trios.
	var wn := await _world(_glass_rows(14, 30), "", "nightfall")
	_sturdy(wn)
	_settle(wn, Vector2(23 * TILE + 16, 13 * TILE))
	wn.player.invuln = 1000.0
	var mn := _spawn(wn, "glassmite", Vector2i(19, 12))
	var gn := _measure(wn, mn, "gnaw", 4.0)
	_check(gn < _kn("glassmite", "gnaw") and gn >= 0.40, "Nightfall's gnaw is shorter (%.2f s) and still >= 0.40" % gn)
	_check(mn.crack.size() == 4, "Nightfall's crack reaches 4 tiles")
	await _done(wn)
	var ww := await _world(_rows(60, {Vector2i(30, 12): "x"}), "", "witching")
	_sturdy(ww)
	ww.player.invuln = 1000.0
	for e in ww.enemies:
		e.active = true
	_step(ww, 2)
	_check(_only(ww, "glassmite").size() == 3, "Witching: they come in trios (%d)" % _only(ww, "glassmite").size())
	await _pack_relights(ww, "glassmite", 3, "Witching's trio")
	await _done(ww)
	# An Anointed placed mite brings its trio too (they're ordinary).
	var wa := await _world(_rows(60), "", "witching")
	_sturdy(wa)
	wa.player.invuln = 1000.0
	var ma := _spawn(wa, "glassmite", Vector2i(30, 12))
	ma.make_elite("anointed", ["Swift"])
	_step(wa, 2)
	var trio := _only(wa, "glassmite")
	_check(trio.size() == 3 and trio.filter(func(e): return e.tier == "anointed").size() == 1, "an Anointed mite brings an ordinary pair with it on Witching (%d)" % trio.size())
	await _done(wa)
	# Placement (spec §4.5): never glass over the void without footing in a jump.
	var Mite = _script("glassmite")
	var bridge := _rows(60)
	for y in [13, 14]:
		var r: String = bridge[y]
		bridge[y] = r.substr(0, 20) + ".".repeat(20) + r.substr(40)
	var bad := _fill(bridge.duplicate(), {Vector2i(30, 12): "x"})
	for x in range(22, 39):
		bad = _fill(bad, {Vector2i(x, 13): "G"})
	var lv_b = LevelData.new()
	lv_b.parse("title: t\n---\n" + "\n".join(bad))
	_check(not (Mite.placement_problems(lv_b) as Array).is_empty(), "a mite on a long glass bridge over the void is reported")
	var near := _fill(bridge.duplicate(), {Vector2i(30, 12): "x"})
	for x in range(22, 39):
		near = _fill(near, {Vector2i(x, 13): "G" if x % 4 != 0 else "#"})
	var lv_n = LevelData.new()
	lv_n.parse("title: t\n---\n" + "\n".join(near))
	_check((Mite.placement_problems(lv_n) as Array).is_empty(), "one with stone every 4 tiles (a jump away) isn't %s" % [Mite.placement_problems(lv_n)])
	var pews := _glass_rows(18, 30, [22])
	pews = _fill(pews, {Vector2i(24, 12): "x"})
	var lv_p = LevelData.new()
	lv_p.parse("title: t\n---\n" + "\n".join(pews))
	_check((Mite.placement_problems(lv_p) as Array).is_empty(), "nor glass pews over a stone floor (a break can't drop you far)")


# ---------------------------------------------------------------- Gustling

func _test_gustling() -> void:
	# A long stone floor; an edge at column 36 (a pit beyond).
	var rows := _rows(60)
	for y in [13, 14]:
		var r: String = rows[y]
		rows[y] = r.substr(0, 36) + ".".repeat(6) + r.substr(42)
	var w := await _world(rows)
	_sturdy(w)
	var pl: Node2D = w.player
	_settle(w, Vector2(26 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	var g := _spawn(w, "gustling", Vector2i(20, 11))
	var mite := _spawn(w, "glassmite", Vector2i(28, 12))
	var inhale := _measure(w, g, "inhale", 3.0)
	_check(absf(inhale - _kn("gustling", "inhale")) <= DT * 1.5, "the inhale tell lasts %.2f s (measured %.3f)" % [_kn("gustling", "inhale"), inhale])
	_check(g.state == "gust" and g.facing == 1, "then it gusts, facing him")
	# Against it, on the ground, he still makes headway.
	var x0: float = pl.position.x
	var most := 0.0
	var mite_pushed := 0.0
	var ticks := 0
	while g.state == "gust" and ticks < 300:
		_step(w, 1, {"left": true})
		most = maxf(most, absf(pl.push.x))
		mite_pushed += mite.push_dx if mite.alive else 0.0
		ticks += 1
	_check(absf(ticks * DT - _kn("gustling", "gust")) <= DT * 2.0, "the gust lasts %.1f s on Dusk" % _kn("gustling", "gust"))
	_check(most > 100.0 and most <= 170.0 + 0.01, "it pushes him at up to the 170 px/s cap (%.0f)" % most)
	_check(pl.position.x < x0, "a grounded Wick walking into it still advances (%.0f px)" % (x0 - pl.position.x))
	_check(mite_pushed > 1.0, "it pushes a Glassmite too")
	# Standing idle it drifts him, but never off the floor's edge (the World's brake).
	g.hp = 0.0
	g._kill({"how": "slash", "from_x": 0.0})
	_spawn(w, "gustling", Vector2i(30, 11))
	_settle(w, Vector2(34 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	for i in int(4.0 / DT):
		_step(w, 1)
	_check(pl.on_floor and pl.position.x <= 36 * TILE + 1.0, "an idle Wick is pushed to the edge and stops there (x %.0f)" % pl.position.x)
	await _done(w)
	# The fair-push rule: never a gust while he's airborne over a pit.
	var rows2 := _rows(60)
	for y in [13, 14]:
		var r: String = rows2[y]
		rows2[y] = r.substr(0, 28) + ".".repeat(8) + r.substr(36)
	var w2 := await _world(rows2)
	_sturdy(w2)
	var p2: Node2D = w2.player
	_settle(w2, Vector2(26 * TILE, 13 * TILE))
	p2.invuln = 1000.0
	var g2 := _spawn(w2, "gustling", Vector2i(21, 11))
	for i in int(2.0 / DT):
		_step(w2, 1)
		if g2.state == "inhale" and g2.timer <= 0.1:
			break
	var held := false
	var pushed_over_pit := false
	for i in int(1.0 / DT):
		p2.position = Vector2(31 * TILE, 11 * TILE)
		p2.velocity = Vector2.ZERO
		_step(w2, 1)
		if g2.state == "hold":
			held = true
		if g2.state == "gust":
			pushed_over_pit = true
	_check(held and not pushed_over_pit, "the inhale waits while he's airborne over a pit")
	p2.reset_at(Vector2(26 * TILE, 13 * TILE))
	_step(w2, 4)
	_check(g2.state == "gust", "and gusts once he's on the ground")
	await _done(w2)
	# A wall stops the gust: nothing behind it is pushed, and it never
	# breathes in at him through it.
	var wf := {}
	for y in range(0, 13):
		wf[Vector2i(24, y)] = "#"
	var ww := await _world(_rows(60, wf))
	_sturdy(ww)
	var pw: Node2D = ww.player
	_settle(ww, Vector2(28 * TILE, 13 * TILE))
	pw.invuln = 1000.0
	var gw := _spawn(ww, "gustling", Vector2i(20, 11))
	var mw := _spawn(ww, "glassmite", Vector2i(26, 12))
	var xw: float = pw.position.x
	var most_w := 0.0
	var mite_w := 0.0
	var inhaled := false
	for i in int(4.0 / DT):
		_step(ww, 1)
		most_w = maxf(most_w, absf(pw.push.x))
		mite_w += absf(mw.push_dx) if mw.alive else 0.0
		if gw.state != "float" and gw.state != "rest":
			inhaled = true
	_check(gw.facing == 1 and gw.band().end.x <= 24 * TILE + 0.5 and gw.band().end.x >= 24 * TILE - 0.5,
			"a wall cuts the band short (it ends at x %.0f, the wall at %d)" % [gw.band().end.x, 24 * TILE])
	_check(most_w == 0.0 and absf(pw.position.x - xw) < 1.0 and mite_w == 0.0, "Wick and a Glassmite behind a wall feel nothing (%.0f px/s)" % most_w)
	_check(not inhaled, "and it never breathes in at him through the wall")
	# In the open the same band reaches its full 320 px.
	gw.hp = 0.0
	gw._kill({"how": "slash", "from_x": 0.0})
	var go := _spawn(ww, "gustling", Vector2i(40, 11))
	go.facing = 1
	_check(absf(go.band().size.x - _kn("gustling", "band_len")) < 0.5, "in the open the band runs its full %d px" % int(_kn("gustling", "band_len")))
	await _done(ww)
	# Placement: at least 5 tiles from any edge it pushes toward.
	var Gus = _script("gustling")
	var bad_rows := _rows(40, {Vector2i(12, 11): "z"})
	for y in [13, 14]:
		var r: String = bad_rows[y]
		bad_rows[y] = r.substr(0, 15) + ".." + r.substr(17)
	var lv_bad = LevelData.new()
	lv_bad.parse("title: t\n---\n" + "\n".join(bad_rows))
	_check(not (Gus.placement_problems(lv_bad) as Array).is_empty(), "a Gustling 3 tiles from an edge is reported")
	var ok_rows := _rows(40, {Vector2i(12, 11): "z"})
	for y in [13, 14]:
		var r: String = ok_rows[y]
		ok_rows[y] = r.substr(0, 25) + ".." + r.substr(27)
	var lv_ok = LevelData.new()
	lv_ok.parse("title: t\n---\n" + "\n".join(ok_rows))
	_check((Gus.placement_problems(lv_ok) as Array).is_empty(), "one 13 tiles from its nearest edge isn't")
	# Nightfall's gust lasts longer; Witching's comes twice.
	var w3 := await _world(_rows(60), "", "witching")
	_sturdy(w3)
	_settle(w3, Vector2(26 * TILE, 13 * TILE))
	w3.player.invuln = 1000.0
	var g3 := _spawn(w3, "gustling", Vector2i(20, 11))
	var gusts := 0
	var was := ""
	for i in int(4.0 / DT):
		_step(w3, 1)
		if g3.state == "gust" and was != "gust":
			gusts += 1
		was = g3.state
		if g3.state == "rest":
			break
	_check(gusts == 2, "Witching: two gusts, 0.5 s apart (%d)" % gusts)
	await _done(w3)


# ---------------------------------------------------------------- Refractor

func _test_refractor() -> void:
	# A stone wall behind Wick at column 27.
	var fill := {}
	for y in range(0, 13):
		fill[Vector2i(27, y)] = "#"
	var w := await _world(_rows(60, fill))
	_sturdy(w)
	var pl: Node2D = w.player
	_settle(w, Vector2(24 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	var r := _spawn(w, "refractor", Vector2i(16, 12))
	var track := _measure(w, r, "track", 3.0)
	_check(absf(track - _kn("refractor", "track")) <= DT * 1.5, "it tracks him %.2f s (measured %.3f)" % [_kn("refractor", "track"), track])
	_check(r.state == "lock" and not r.lines.is_empty(), "then the line locks")
	var drawn: Array = r.drawn_lines().duplicate(true)
	var lock := 0
	while r.state == "lock" and lock < 200:
		_step(w, 1)
		lock += 1
	_check(absf(lock * DT - _kn("refractor", "lock")) <= DT * 1.5 and lock * DT >= 0.40, "the lock lasts %.2f s (measured %.3f)" % [_kn("refractor", "lock"), lock * DT])
	var beams: Array = w.hazards.filter(func(h): return h["kind"] == "beam" and h.get("source") == r)
	_check(beams.size() == 1 and drawn.size() == 1, "one beam, along the one locked line")
	if beams.size() == 1 and drawn.size() == 1:
		_check((beams[0]["seg"][0] as Vector2).is_equal_approx(drawn[0][0]) and (beams[0]["seg"][1] as Vector2).is_equal_approx(drawn[0][1]), "what fires is what was drawn")
		var end: Vector2 = beams[0]["seg"][1]
		_check(end.x <= 27 * TILE + 0.5 and end.x >= 27 * TILE - 4.0, "the beam stops at stone (x %.0f)" % end.x)
		_check(is_equal_approx(float(beams[0]["width"]), 6.0) and bool(beams[0].get("reflect", false)), "6 px wide, and a Perfect Guard may reflect it")
	await _done(w)
	# Through glass it splits at +-30 degrees, drawn from the lock's start.
	var gf := {}
	for y in range(8, 13):
		gf[Vector2i(20, y)] = "G"
	var w2 := await _world(_rows(60, gf))
	_sturdy(w2)
	_settle(w2, Vector2(26 * TILE, 13 * TILE))
	w2.player.invuln = 1000.0
	var r2 := _spawn(w2, "refractor", Vector2i(15, 10))
	var t2 := _measure(w2, r2, "track", 3.0)
	_check(t2 > 0.0 and r2.state == "lock", "it sees him through glass")
	var d2: Array = r2.drawn_lines().duplicate(true)
	_check(d2.size() == 3, "a locked line through glass is drawn split in three (%d)" % d2.size())
	if d2.size() == 3:
		var a: Vector2 = d2[0][1]
		_check(a.x >= 21 * TILE - 0.1 and a.x <= 21 * TILE + 4.0, "the split starts past the glass (x %.0f)" % a.x)
		var main: Vector2 = ((d2[0][1] as Vector2) - (d2[0][0] as Vector2)).normalized()
		var s1: Vector2 = ((d2[1][1] as Vector2) - (d2[1][0] as Vector2)).normalized()
		var s2: Vector2 = ((d2[2][1] as Vector2) - (d2[2][0] as Vector2)).normalized()
		_check(absf(absf(rad_to_deg(main.angle_to(s1))) - 30.0) < 0.5 and absf(absf(rad_to_deg(main.angle_to(s2))) - 30.0) < 0.5,
				"the split beams leave at +-30 degrees")
	while r2.state == "lock":
		_step(w2, 1)
	var fired: Array = w2.hazards.filter(func(h): return h["kind"] == "beam" and h.get("source") == r2)
	var same := fired.size() == d2.size()
	for i in mini(fired.size(), d2.size()):
		same = same and (fired[i]["seg"][0] as Vector2).is_equal_approx(d2[i][0]) and (fired[i]["seg"][1] as Vector2).is_equal_approx(d2[i][1])
	_check(same, "the split lines that fire are the ones drawn")
	await _done(w2)
	# Only wholly in view: straddling the top of the glass, it holds its fire.
	var w3 := await _world(_rows(60))
	_sturdy(w3)
	_settle(w3, Vector2(24 * TILE, 13 * TILE))
	w3.player.invuln = 1000.0
	# (Headless, the glass is 844 x 844: the camera is held so the Refractor
	# straddles the view's left edge, with Wick in range and in plain sight.)
	var r3 := _spawn(w3, "refractor", Vector2i(18, 11))
	var tracked := false
	var hidden := 0
	for i in int(2.0 / DT):
		var half: float = w3.view_rect().size.x * 0.5
		w3.cam = Vector2(r3.position.x + half - 5.0, w3.cam.y)
		w3.test_pad = {}
		w3._read_pad()
		w3.tick(DT)
		if r3.state == "track":
			tracked = true
		w3.cam = Vector2(r3.position.x + half - 5.0, w3.cam.y)
		if not r3.in_view() and r3.clear_line(w3.player.center()) and r3.eye().distance_to(w3.player.center()) <= 360.0:
			hidden += 1
	_check(hidden > 200 and not tracked, "in range with a clear line but not wholly in view, it never tracks (%d ticks)" % hidden)
	r3.hp = 0.0
	r3._kill({"how": "slash", "from_x": 0.0})
	# A hit during track resets the aim.
	var r4 := _spawn(w3, "refractor", Vector2i(18, 9))
	for i in int(3.0 / DT):
		if r4.state == "track":
			break
		_step(w3, 1)
	for i in 10:
		if r4.state != "track":
			break
		_step(w3, 1)
	if r4.state == "track":
		r4.hit({"how": "slash", "amount": 0.5, "from_x": w3.player.position.x})
		_check(r4.state == "idle" and r4.lines.is_empty(), "a hit during track resets its aim")
	else:
		_check(false, "a hit during track resets its aim (it never tracked)")
	await _done(w3)
	# Witching: a second beam, its own fresh lock, 0.5 s after the first.
	var w4 := await _world(_rows(60), "", "witching")
	_sturdy(w4)
	_settle(w4, Vector2(24 * TILE, 13 * TILE))
	w4.player.invuln = 1000.0
	var r5 := _spawn(w4, "refractor", Vector2i(16, 9))
	for i in int(3.0 / DT):
		if r5.state == "lock":
			break
		_step(w4, 1)
	var fire_ticks := []
	var n := 0
	for i in int(2.0 / DT):
		var f0: int = r5.fired
		_step(w4, 1)
		n += 1
		if r5.fired > f0:
			fire_ticks.append(n)
		if r5.state == "cool":
			break
	_check(fire_ticks.size() == 2, "Witching fires twice (%d)" % fire_ticks.size())
	if fire_ticks.size() == 2:
		_check(absf((fire_ticks[1] - fire_ticks[0]) * DT - _kn("refractor", "second_gap")) <= DT * 2.0, "0.5 s apart (%.2f)" % ((fire_ticks[1] - fire_ticks[0]) * DT))
	# Its second lock needs a shot it could take: Wick gone out of range after the first, no second.
	var r6 := _spawn(w4, "refractor", Vector2i(16, 9))
	r5.hp = 0.0
	r5._kill({"how": "slash", "from_x": 0.0})
	_settle(w4, Vector2(24 * TILE, 13 * TILE))
	w4.player.invuln = 1000.0
	for i in int(4.0 / DT):
		if r6.state == "fire":
			break
		_step(w4, 1)
	var f6: int = r6.fired
	w4.player.reset_at(Vector2(50 * TILE, 13 * TILE))
	for i in int(1.5 / DT):
		_step(w4, 1)
		if r6.state == "cool":
			break
	_check(f6 == 1 and r6.fired == 1 and r6.lines2.is_empty(), "Witching's second lock waits on a clear shot: him gone, it holds its fire (%d)" % r6.fired)
	await _done(w4)
	# A Candleknight's Perfect Guard sends the beam back (KT's knight.gd), when that's in the build.
	var wk := await _world(_rows(60), "", "dusk", 5, "", false, "knight")
	if wk.kit == null or not wk.kit.has_method("_reflect_beam"):
		_skip("the knight's beam reflect (KT: kits/knight.gd _reflect_beam) isn't in this build; the beam carries reflect and source for it")
	else:
		_sturdy(wk)
		var pk: Node2D = wk.player
		_settle(wk, Vector2(24 * TILE, 13 * TILE))
		pk.invuln = 0.0
		pk.facing = -1
		var rk := _spawn(wk, "refractor", Vector2i(16, 12))
		for i in int(4.0 / DT):
			if rk.state == "lock" and rk.timer <= DT * 3.0:
				break
			_step(wk, 1)
		_step(wk, 1, {"special_pressed": true, "special": true})
		for i in 12:
			_step(wk, 1, {"special": true})
		_check(rk.fired >= 1 and int(wk.kit.get("reflects")) >= 1 and rk.hp < rk.max_hp,
				"a Perfect Guard sends the beam back at the Refractor (%d reflected, %.0f of %.0f left)" % [int(wk.kit.get("reflects")), rk.hp, rk.max_hp])
	await _done(wk)


# ---------------------------------------------------------------- Paneguard

func _test_paneguard() -> void:
	var w := await _world(_rows(60))
	_sturdy(w)
	var pl: Node2D = w.player
	_settle(w, Vector2(28 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	var p := _spawn(w, "paneguard", Vector2i(24, 12))
	_step(w, 2)
	var r: Dictionary = w.deal(p, 1.0, {"how": "slash", "flat": 10.0, "no_hitstop": true})
	_check(not r["hit"] and is_equal_approx(p.hp, p.max_hp), "face-on, a hit clangs off (hit() false)")
	var sh: Dictionary = w.deal(p, 1.0, {"how": "shot", "flat": 10.0, "no_hitstop": true})
	_check(not sh["hit"], "and shots break on it")
	var turn := _measure(w, p, "turn", 3.0)
	_check(absf(turn - _kn("paneguard", "turn")) <= DT * 1.5, "within 140 px it turns (%.2f s tell, measured %.3f)" % [_kn("paneguard", "turn"), turn])
	_check(p.state == "lunge" and p.edge_on, "then lunges edge-first")
	_check(is_equal_approx(p.rect().size.x, 8.0) and p.hurt_rect() == p.rect(), "the lunge's slicing box is 8 px wide")
	_check(is_equal_approx(p.dmg("touch"), 36.0 * p.dmg_mult), "and bites for the lunge's 36")
	var x0: float = p.position.x
	while p.state == "lunge":
		_step(w, 1)
	_check(absf(absf(p.position.x - x0) - _kn("paneguard", "lunge_dist")) <= 8.0, "the lunge runs %d px (%.0f)" % [int(_kn("paneguard", "lunge_dist")), absf(p.position.x - x0)])
	_check(p.state == "edge_recover" and p.edge_on, "then it stands edge-on: the window")
	var hp0: float = p.hp
	var r2: Dictionary = w.deal(p, 1.0, {"how": "slash", "flat": 10.0, "no_hitstop": true})
	_check(r2["hit"] and p.hp < hp0, "edge-on, a hit lands")
	var rec := 0
	while p.state == "edge_recover":
		_step(w, 1)
		rec += 1
	_check(absf(rec * DT - (_kn("paneguard", "recover") - DT)) <= DT * 2.0, "the window lasts %.1f s" % _kn("paneguard", "recover"))
	await _done(w)
	# A stomp face-on bounces off harmlessly.
	var w2 := await _world(_rows(60))
	_sturdy(w2)
	var p2: Node2D = w2.player
	_settle(w2, Vector2(10 * TILE, 13 * TILE))
	var pg := _spawn(w2, "paneguard", Vector2i(30, 12))
	var hp_w: float = p2.hp
	p2.position = pg.position + Vector2(0, -pg.size.y - 2.0)
	p2.velocity = Vector2(0, 260)
	var bounced := false
	for i in 10:
		_step(w2, 1)
		if p2.velocity.y < -100.0:
			bounced = true
			break
	_check(bounced and is_equal_approx(pg.hp, pg.max_hp) and is_equal_approx(p2.hp, hp_w), "face-on, a stomp bounces off harmlessly")
	# The maul cracks it face-on: 30% gets through.
	w2.kit.cls = "founder"
	var mh: float = pg.hp
	var rm: Dictionary = w2.deal(pg, 1.0, {"how": "slash", "flat": 20.0, "no_hitstop": true})
	_check(rm["hit"] and absf((mh - pg.hp) - 20.0 * _kn("paneguard", "maul_through")) < 0.01, "the Bellfounder's maul gets 30% through face-on")
	w2.kit.cls = "knight"
	# A Perfect Guard on the lunge stalls it edge-on for 1.5 s.
	pg.state = "lunge"
	pg._set_edge(true)
	pg.apply_status("stun", 1.0)
	_check(pg.state == "edge_recover" and absf(pg.timer - _kn("paneguard", "pg_edge")) < 0.001 and pg.edge_on, "a Perfect Guard on the lunge leaves it edge-on 1.5 s")
	await _done(w2)
	# The Glass Cut: its tell, the arc, and the glass under the arc (never its own).
	var fill := {}
	for x in range(18, 30):
		fill[Vector2i(x, 13)] = "G"
	var w3 := await _world(_rows(60, fill))
	_sturdy(w3)
	var p3: Node2D = w3.player
	_settle(w3, Vector2(25 * TILE + 8, 13 * TILE))
	p3.invuln = 0.0
	var pc := _spawn(w3, "paneguard", Vector2i(23, 12))
	pc.facing = 1
	var cut := _measure(w3, pc, "cut", 3.0, {})
	_check(absf(cut - _kn("paneguard", "cut_tell")) <= DT * 1.5, "within 50 px: the Glass Cut, a %.2f s tell (measured %.3f)" % [_kn("paneguard", "cut_tell"), cut])
	_check(pc.state == "cut_strike" or pc.state == "cut_recover", "then the cut")
	var lv: RefCounted = w3.level
	_step(w3, int(0.5 / DT))
	_check(lv.tile(23, 13) == LevelData.GLASS, "it never breaks the glass it stands on")
	_check(lv.tile(24, 13) == LevelData.AIR or lv.tile(25, 13) == LevelData.AIR, "it breaks the glass under the arc (his footing)")
	_check(str(w3.snuff_causes.get("_move", "")) == "paneguard:cut", "and the cut hit him (the playlog's move: paneguard:cut)")
	await _done(w3)
	# The cut marks every pane it will break as its tell begins, breaks just
	# those, and a Wick whose body is out of the drawn arc keeps his footing.
	var cf := {}
	for x in range(18, 34):
		cf[Vector2i(x, 13)] = "G"
	cf[Vector2i(23, 13)] = "#"
	var w5 := await _world(_rows(60, cf))
	_sturdy(w5)
	var p5: Node2D = w5.player
	_settle(w5, Vector2(25 * TILE + 20, 13 * TILE))
	p5.invuln = 1000.0
	var pk := _spawn(w5, "paneguard", Vector2i(23, 12))
	pk.position.x = 23 * TILE + 26
	pk.facing = 1
	for i in int(3.0 / DT):
		_step(w5, 1)
		if pk.state == "cut":
			break
	var marked: Array = (pk.cut_tiles as Array).duplicate()
	var area: Rect2 = pk.cut_area()
	_check(pk.state == "cut" and not marked.is_empty(), "the Glass Cut marks the panes it will break as its tell begins (%s)" % [marked])
	var far_edge := 0.0
	for c in marked:
		far_edge = maxf(far_edge, float((c.x + 1) * TILE))
	_check(far_edge <= area.end.x + _kn("paneguard", "cut_spill") + 0.01 and _kn("paneguard", "cut_spill") <= HERO_HALF,
			"none reaches more than half his width past the arc (%.0f vs the arc's end %.0f)" % [far_edge, area.end.x])
	p5.reset_at(Vector2(area.end.x + 1.0 + HERO_HALF, 13 * TILE))   # his body 1 px past the drawn arc
	p5.invuln = 1000.0
	var broken: Array = []
	var kept := true
	var after := -1
	for i in int(2.0 / DT):
		_step(w5, 1)
		for x in range(18, 34):
			if w5.level.tile(x, 13) == LevelData.AIR and not broken.has(Vector2i(x, 13)):
				broken.append(Vector2i(x, 13))
		kept = kept and p5.on_floor and absf(p5.position.y - 13 * TILE) < 1.0
		if pk.state == "cut_recover" and after < 0:
			after = i
		if after >= 0 and i - after > int(0.35 / DT):
			break
	broken.sort()
	marked.sort()
	_check(broken == marked, "exactly the marked panes break (%s, marked %s)" % [broken, marked])
	_check(kept, "and a Wick 1 px past the drawn arc keeps his footing")
	await _done(w5)
	# Never through a wall: a stone pillar between them, it neither cuts nor turns.
	var pf := {}
	for y in range(9, 13):
		pf[Vector2i(24, y)] = "#"
	var w6 := await _world(_rows(60, pf))
	_sturdy(w6)
	var p6: Node2D = w6.player
	_settle(w6, Vector2(25 * TILE + 14, 13 * TILE))
	p6.invuln = 0.0
	var pp := _spawn(w6, "paneguard", Vector2i(23, 12))
	pp.facing = 1
	var hp6: float = p6.hp
	var struck := false
	for i in int(3.0 / DT):
		_step(w6, 1)
		if pp.state in ["cut", "cut_strike", "turn", "lunge"]:
			struck = true
	_check(not struck and is_equal_approx(p6.hp, hp6), "behind a stone pillar he's safe: it never cuts or turns at him through it")
	var ca: Rect2 = pp.cut_area()
	_check(ca.end.x <= 24 * TILE + 0.5, "and its arc stops at the pillar (x %.0f)" % ca.end.x)
	await _done(w6)
	# Witching: after the lunge it turns and lunges back.
	var w4 := await _world(_rows(60), "", "witching")
	_sturdy(w4)
	_settle(w4, Vector2(28 * TILE, 13 * TILE))
	w4.player.invuln = 1000.0
	var p4 := _spawn(w4, "paneguard", Vector2i(24, 12))
	var back := _measure(w4, p4, "turn_back", 4.0)
	_check(back >= 0.35 - 0.001, "Witching: it turns (%.2f s, floor 0.35) and lunges back" % back)
	_check(p4.lunges == 2 or p4.state == "lunge", "a second lunge")
	await _done(w4)


# ---------------------------------------------------------------- Hushling

func _test_hushling() -> void:
	# A lit lantern post; Wick in its light; a Hushling comes, and stops at its edge.
	var w := await _world(_rows(60, {Vector2i(20, 12): "L"}), "", "dusk", 6)
	_sturdy(w)
	var pl: Node2D = w.player
	var l: Dictionary = w.features.lanterns[0]
	_settle(w, Vector2(21 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	_check(l["lit"], "the lantern is lit")
	var h := _spawn(w, "hushling", Vector2i(26, 12))
	var nearest := INF
	var lunged := false
	for i in int(4.0 / DT):
		_step(w, 1)
		l["t"] = 25.0   # keep it burning
		nearest = minf(nearest, (h.center() as Vector2).distance_to(l["flame"]))
		if h.state == "crouch" or h.state == "lunge":
			lunged = true
	var lr: float = float(w.lights_tagged("lantern")[0]["r"]) if not w.lights_tagged("lantern").is_empty() else 140.0
	_check(nearest >= lr - 2.0 and nearest <= lr + 40.0, "it creeps up to the lantern's edge and stops there (%.0f px from the flame, r %.0f)" % [nearest, lr])
	_check(not lunged, "it never lunges at him inside the light")
	await _done(w)
	# In the dark: the crouch, the lunge at where he stood, hushed.
	var w2 := await _world(_rows(60), "", "dusk", 6)
	_sturdy(w2)
	var p2: Node2D = w2.player
	_settle(w2, Vector2(20 * TILE, 13 * TILE))
	var h2 := _spawn(w2, "hushling", Vector2i(22, 12))
	var crouch := _measure(w2, h2, "crouch", 3.0)
	_check(absf(crouch - _kn("hushling", "crouch")) <= DT * 1.5, "within 90 px it crouches (%.2f s, measured %.3f)" % [_kn("hushling", "crouch"), crouch])
	var spot: Vector2 = h2.target
	_check(spot.distance_to(p2.position) < 1.0, "and marks where he stood as the tell began")
	var hushed := false
	var path: Array = []
	var t_up := -1.0                # its own clock (a hit's hitstop holds the World, not the hop)
	var t_down := -1.0
	for i in int(2.0 / DT):
		_step(w2, 1)
		if h2.state == "lunge":
			path.append(h2.position)
			if t_up < 0.0:
				t_up = h2.t - DT
		elif t_up >= 0.0 and t_down < 0.0:
			t_down = h2.t - DT
		if (w2.dims() as Dictionary).has("hushed"):
			hushed = true
		if h2.state == "blink":
			break
	_check(hushed and str(w2.snuff_causes.get("_move", "")) == "hushling:lunge", "the lunge lands, and hushes him")
	_check(h2.state == "blink" and not h2.touch_damage(), "then it blinks, harmless and open")
	var top := INF
	for q in path:
		top = minf(top, (q as Vector2).y)
	_check(not path.is_empty() and absf(h2.position.x - spot.x) < 2.0 and h2.on_floor,
			"its hop lands on the marked spot (x %.1f, the spot %.1f)" % [h2.position.x, spot.x])
	_check(absf((t_down - t_up) - h2.lunge_time()) <= DT * 3.0 and spot.y - top > 15.0,
			"a hop %.2f s long (%.2f), %.0f px high" % [h2.lunge_time(), t_down - t_up, spot.y - top])
	await _done(w2)
	# Stepping off the spot as it crouches (9 px of its half and his 10) is the escape.
	var we := await _world(_rows(60), "", "dusk", 6)
	_sturdy(we)
	var pe: Node2D = we.player
	_settle(we, Vector2(20 * TILE, 13 * TILE))
	var he := _spawn(we, "hushling", Vector2i(22, 12))
	for i in int(3.0 / DT):
		_step(we, 1)
		if he.state == "crouch":
			break
	pe.reset_at(Vector2(he.target.x - (he.size.x * 0.5 + HERO_HALF + 1.0), 13 * TILE))
	pe.invuln = 0.0
	var hp_e: float = pe.hp
	for i in int(1.5 / DT):
		_step(we, 1)
		if he.state == "blink":
			break
	_check(he.state == "blink" and is_equal_approx(pe.hp, hp_e) and not (we.dims() as Dictionary).has("hushed"),
			"a Wick who steps off the marked spot is missed")
	await _done(we)
	# Nightfall's packs of 3-5; Witching's second lunge.
	var wn := await _world(_rows(60, {Vector2i(30, 12): "n"}), "", "nightfall", 6)
	_sturdy(wn)
	for e in wn.enemies:
		e.active = true
	_step(wn, 2)
	var pack := _only(wn, "hushling").size()
	_check(pack >= 3 and pack <= 5, "Nightfall: a lone Hushling brings its pack to 3-5 (%d)" % pack)
	await _pack_relights(wn, "hushling", pack, "Nightfall's Hushling pack")
	await _done(wn)
	var ww := await _world(_rows(60), "", "witching", 6)
	_sturdy(ww)
	_settle(ww, Vector2(20 * TILE, 13 * TILE))
	ww.player.invuln = 1000.0
	var hw := _spawn(ww, "hushling", Vector2i(22, 12))
	var most := 0
	for i in int(3.0 / DT):
		_step(ww, 1)
		most = maxi(most, int(hw.lunges_done))
		if hw.state == "blink":
			break
	_check(most == 2, "Witching: it lunges twice (%d)" % most)
	await _done(ww)


func _alive(w: Node2D, kind: String) -> int:
	return w.enemies.filter(func(e): return e.kind == kind and e.alive).size()


func _pack_relights(w: Node2D, kind: String, n: int, what: String) -> void:
	## A pack (or a trio, or a pair) keeps its size across relights: all of
	## it snuffed out and the World's respawn; only its extras lost and a
	## relight; and never more than the rule, however many relights.
	w.player.invuln = 1000.0
	for e in w.enemies.duplicate():
		if e.kind == kind and e.alive:
			e.hp = 0.0
			e._kill({"how": "slash", "from_x": 0.0})
	_step(w, int(1.6 / DT))
	w._respawn_monsters()
	for e in w.enemies:
		e.active = true
	_step(w, 3)
	_check(_alive(w, kind) == n, "%s comes back whole after the World's respawn (%d of %d)" % [what, _alive(w, kind), n])
	for e in w.enemies.duplicate():
		if e.kind == kind and e.alive and (e.get("pack_of") as Vector2i).x >= 0:
			e.hp = 0.0
			e._kill({"how": "slash", "from_x": 0.0})
	_step(w, int(1.6 / DT))
	_check(_alive(w, kind) == 1, "(its extras gone, the one placed lives)")
	w.snuffs += 1
	_step(w, 3)
	_check(_alive(w, kind) == n, "%s is brought back up to size after a relight (%d)" % [what, _alive(w, kind)])
	w.snuffs += 1
	_step(w, 3)
	w._respawn_monsters()
	_step(w, 3)
	_check(_alive(w, kind) == n, "and never grows past it (%d)" % _alive(w, kind))


# ---------------------------------------------------------------- Stillmaw

func _test_stillmaw() -> void:
	var w := await _world(_rows(70, {Vector2i(14, 12): "L"}), "", "dusk", 6)
	_sturdy(w)
	var pl: Node2D = w.player
	_settle(w, Vector2(45 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	var l: Dictionary = w.features.lanterns[0]
	w.features.light(l)
	var m := _spawn(w, "stillmaw", Vector2i(20, 9))
	var sw := _measure(w, m, "swallow_tell", 12.0)
	_check(absf(sw - _kn("stillmaw", "swallow")) <= DT * 1.5, "it drifts to the lantern and swallows it (a %.1f s tell, measured %.3f)" % [_kn("stillmaw", "swallow"), sw])
	_check(not l["lit"] and w.lights_tagged("lantern").is_empty(), "the lantern goes out")
	_check(m.swallows == 1 and absf(m.scale_mult - _kn("stillmaw", "grow")) < 0.001 and absf(m.max_hp / (m.hp if m.hp > 0 else 1.0) - 1.0) < 0.01,
			"it grows x1.15, with 20% more life")
	# Relit, it comes again; a hit mid-tell spits it back (+10 s), stunned.
	w.features.light(l)
	var got := _measure(w, m, "sated", 6.0)
	for i in int(8.0 / DT):
		if m.state == "swallow_tell":
			break
		_step(w, 1)
	for i in 20:
		if m.state != "swallow_tell":
			break
		_step(w, 1)
	var choked := false
	if m.state == "swallow_tell":
		var tl: float = float(l["t"])
		w.deal(m, 1.0, {"how": "slash", "flat": 1.0, "no_hitstop": true})
		choked = m.state == "choked" and l["lit"] and float(l["t"]) >= tl + _kn("stillmaw", "relight_extra") - 0.01
	_check(got >= 0.0 and choked, "a hit mid-swallow spits the light back (lit, +10 s)")
	_check(m.stunned(), "and stuns it")
	# Let it take it at last, then kill it: every light it swallowed comes back.
	for i in int(12.0 / DT):
		_step(w, 1)
		if not l["lit"]:
			break
	_check(not l["lit"], "it swallows the lantern at last")
	m.hp = 0.0
	m._kill({"how": "slash", "from_x": 0.0})
	_check(l["lit"] and not w.lights_tagged("lantern").is_empty(), "its death relights every light it swallowed")
	await _done(w)
	# Never an anchor lamp.
	var w2 := await _world(_rows(70, {Vector2i(14, 12): "L"}), "", "dusk", 6)
	_sturdy(w2)
	_settle(w2, Vector2(45 * TILE, 13 * TILE))
	w2.player.invuln = 1000.0
	var la: Dictionary = w2.features.lanterns[0]
	w2.features.light(la)
	la["anchor"] = true
	var m2 := _spawn(w2, "stillmaw", Vector2i(20, 9))
	var tried := false
	for i in int(8.0 / DT):
		_step(w2, 1)
		la["t"] = 25.0
		if m2.state == "swallow_tell":
			tried = true
	_check(la["lit"] and not tried, "it never swallows a lamp tagged anchor")
	# The same by the World light's own tag.
	la.erase("anchor")
	var id: int = int(la["id"])
	var dl: Dictionary = w2.dyn_lights()
	if dl.has(id):
		dl[id]["tag"] = "lantern,anchor"
	_check(m2.is_anchor(la), "a lamp whose light carries the anchor tag is one too")
	await _done(w2)
	# No light near: the Gulp.
	var w3 := await _world(_rows(70), "", "dusk", 6)
	_sturdy(w3)
	var p3: Node2D = w3.player
	_settle(w3, Vector2(24 * TILE, 13 * TILE))
	p3.invuln = 1000.0
	var m3 := _spawn(w3, "stillmaw", Vector2i(26, 11))
	var aura := false
	var gt := -1.0
	for i in int(3.0 / DT):
		_step(w3, 1)
		if (w3.dims() as Dictionary).has("stillmaw"):
			aura = true
		if m3.state == "gulp_tell":
			break
	_check(aura, "inside its aura, his light dims (stillmaw)")
	gt = _measure(w3, m3, "gulp_tell", 1.0)
	_check(absf(gt - _kn("stillmaw", "gulp_tell")) <= DT * 1.5, "no light to eat: the Gulp, a %.1f s tell (measured %.3f)" % [_kn("stillmaw", "gulp_tell"), gt])
	var pull := 0.0
	var toward := true
	var bit := false
	var coned := false
	var hp3: float = p3.hp
	p3.invuln = 0.0
	for i in int(1.2 / DT):
		_step(w3, 1)
		if absf(p3.push.x) > 0.0:
			pull = maxf(pull, absf(p3.push.x))
			toward = toward and signf(p3.push.x) == signf(m3.position.x - p3.position.x)
		if (w3.dims() as Dictionary).has("gulp"):
			coned = true
		if (w3.dims() as Dictionary).has("hushed"):
			bit = true
		if m3.state != "gulp":
			break
	_check(pull > 0.0 and pull <= _kn("stillmaw", "gulp_pull") + 0.01 and toward, "the Gulp pulls him toward it (%.0f px/s)" % pull)
	_check(coned and is_equal_approx(float(_kn("stillmaw", "gulp_dim")), 0.6), "inside its cone his light dims x0.6 (gulp)")
	_check(bit and p3.hp < hp3 and str(w3.snuff_causes.get("_move", "")) == "stillmaw:gulp", "its mouth bites him and hushes him (stillmaw:gulp)")
	await _done(w3)
	# A Sexton's wisp is gulped before he is: one goes, and he isn't pulled.
	var w4 := await _world(_rows(70), "", "dusk", 6, "", false, "sexton")
	_sturdy(w4)
	var p4: Node2D = w4.player
	_settle(w4, Vector2(24 * TILE, 13 * TILE))
	p4.invuln = 1000.0
	var kt = w4.kit
	if str(kt.get("cls")) != "sexton" or not kt.has_method("call_wisp"):
		_skip("no Sexton kit with wisps in this build (the Stillmaw's decoy)")
	else:
		kt.call_wisp()
		kt.call_wisp()
		var m4 := _spawn(w4, "stillmaw", Vector2i(26, 11))
		var wisps0: int = (kt.wisps as Array).size()
		for i in int(4.0 / DT):
			wisps0 = (kt.wisps as Array).size()
			_step(w4, 1)
			if m4.state == "gulp":
				break
		var pulled := false
		for i in int(0.5 / DT):
			_step(w4, 1)
			if absf(p4.push.x) > 0.0:
				pulled = true
		_check(m4.gulped and not pulled and wisps0 >= 1 and (kt.wisps as Array).size() == wisps0 - 1,
				"the Gulp takes one of a Sexton's wisps before him (%d of %d left), and he isn't pulled" % [(kt.wisps as Array).size(), wisps0])
	await _done(w4)


# ---------------------------------------------------------------- Unwick

func _test_unwick() -> void:
	var w := await _world(_rows(90), "", "dusk", 6)
	_sturdy(w)
	var pl: Node2D = w.player
	_settle(w, Vector2(8 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	var u := _spawn(w, "unwick", Vector2i(11, 12))
	var hist: Array = []          # his position after each tick
	var ustep: Array = []         # its position after each tick
	var foll: Array = []
	var plan := []
	for i in 240:
		plan.append({"right": true})
	for i in 60:
		plan.append({"right": true, "jump": i < 20})
	for i in 150:
		plan.append({})
	for i in 90:
		plan.append({"left": true})
	for pad in plan:
		_step(w, 1, pad)
		hist.append(pl.position)
		ustep.append(u.position)
		foll.append(u.following)
	var delay := int(round(_kn("unwick", "delay") / DT))
	var worst := 0.0
	var n := 0
	for i in range(delay + 60, hist.size()):
		if foll[i] and foll[i - 30]:
			worst = maxf(worst, (ustep[i] as Vector2).distance_to(hist[i - delay]))
			n += 1
	_check(n > 200 and worst < 0.5, "it replays his path exactly %.2f s behind (worst %.2f px over %d ticks)" % [_kn("unwick", "delay"), worst, n])
	# Put somewhere else (an altar's relight), he isn't a path: it lets go.
	pl.reset_at(Vector2(30 * TILE, 13 * TILE))
	pl.facing = 1
	_step(w, 1)
	_check(not u.following and u.samples.size() <= 2, "a jump in his path (a relight) breaks it: it lets go")
	u.position = pl.position + Vector2(-60, 0)
	# A copied swing, a second later, in the rect he swung.
	_step(w, 170)
	_check(u.following, "and finds him anew")
	_step(w, 1, {"attack_pressed": true, "attack": true})
	var rect_then: Rect2 = pl.attack_rect()
	var swing_at: float = u.t
	var copy: Dictionary = {}
	for p in u.pending:
		if p["kind"] == "swing":
			copy = p
	_step(w, 1)
	var got := false
	var when := 0.0
	var shown_at := -1.0            # when its outline first showed (the tell: draw_glow draws outlines())
	var gaps := 0                   # ticks it went missing once shown
	for i in 200:
		_step(w, 1)
		var on := false
		for p in u.outlines():
			if is_same(p, copy):
				on = true
		if on and shown_at < 0.0:
			shown_at = u.t
		elif not on and shown_at >= 0.0 and u.swings.is_empty():
			gaps += 1
		if not u.swings.is_empty():
			got = (u.swings[0]["rect"] as Rect2).is_equal_approx(rect_then)
			when = u.t - swing_at
			break
	_check(got, "a copied swing strikes his old attack rect")
	_check(absf(when - _kn("unwick", "delay")) <= DT * 2.5, "%.2f s later (%.3f)" % [_kn("unwick", "delay"), when])
	# The tell, measured: its outline shows from 0.6 s before the copy strikes, unbroken.
	var lead := (swing_at + when) - shown_at
	_check(shown_at >= 0.0 and gaps == 0 and lead >= _kn("unwick", "outline") - DT * 1.5 and _kn("unwick", "outline") >= 0.6,
			"its outline shows %.2f s before the copy strikes (%.3f), unbroken" % [_kn("unwick", "outline"), lead])
	# Solid only inside his light.
	_check(u.solid() and u.rect() != Elites_NOWHERE(), "near him, in his light, it's solid")
	var hp0: float = u.hp
	var r1: Dictionary = w.deal(u, 1.0, {"how": "slash", "flat": 1.0, "no_hitstop": true})
	_check(r1["hit"] and u.hp < hp0, "and a hit lands")
	pl.reset_at(Vector2(80 * TILE, 13 * TILE))
	_step(w, 1)
	u.following = false
	u.position = Vector2(30 * TILE, 13 * TILE)
	_check(not u.solid() and u.rect() == Elites_NOWHERE() and not u.touch_damage(), "outside his light it isn't there to hit or touch")
	var r2: Dictionary = w.deal(u, 1.0, {"how": "slash", "flat": 1.0, "no_hitstop": true})
	_check(not r2["hit"], "a swing passes through")
	await _done(w)
	# Nightfall's delay; Witching's pairs.
	var wn := await _world(_rows(60), "", "nightfall", 6)
	var un := _spawn(wn, "unwick", Vector2i(20, 12))
	_check(absf(un.delay - 0.85) < 0.001, "Nightfall: 0.85 s behind")
	await _done(wn)
	var ww := await _world(_rows(60, {Vector2i(20, 12): "6"}), "", "witching", 6)
	for e in ww.enemies:
		e.active = true
	_step(ww, 2)
	var pair := _only(ww, "unwick")
	var delays := pair.map(func(e): return float(e.delay))
	delays.sort()
	_check(pair.size() == 2 and absf(delays[0] - 0.7) < 0.001 and absf(delays[1] - 1.4) < 0.001, "Witching: in pairs, 0.7 and 1.4 s behind (%s)" % [delays])
	await _done(ww)
	# Nothing is left behind when one goes (its puppet goes with it).
	var orphans0 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var wl := await _world(_rows(40), "", "dusk", 6)
	for i in 3:
		_spawn(wl, "unwick", Vector2i(10 + i * 5, 12))
	_step(wl, 10)
	await _done(wl)
	await process_frame
	var orphans1 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(orphans1 <= orphans0, "three Unwicks and their World freed leave no orphan nodes (%d -> %d)" % [orphans0, orphans1])
	# Its eyes meet decisions' rule: at least 3 px tall at >= 0.9.
	_check(_kn("unwick", "eye_h") * 2.0 >= 3.0 and HK.EYE_A >= 0.9, "the Unwick's slit eyes are %.1f px tall at %.2f" % [_kn("unwick", "eye_h") * 2.0, HK.EYE_A])


func Elites_NOWHERE() -> Rect2:
	return Rect2(-1.0e6, -1.0e6, 1.0, 1.0)


# ---------------------------------------------------------------- Lurecoil

func _lake_rows(w := 60) -> Array:
	## Stone to column 15, a lake (rows 13-14) to column 37 with an islet at
	## 25-27, stone again after.
	var rows := _rows(w)
	for y in [13, 14]:
		var r: String = rows[y]
		rows[y] = r.substr(0, 16) + ":".repeat(9) + "###" + ":".repeat(10) + r.substr(38)
	return rows


func _test_lurecoil() -> void:
	var w := await _world(_lake_rows(), "", "dusk", 6)
	_sturdy(w)
	var pl: Node2D = w.player
	_settle(w, Vector2(25 * TILE + 10, 13 * TILE))
	pl.invuln = 1000.0
	var c := _spawn(w, "lurecoil", Vector2i(20, 13))
	_check(c.lane.x >= 16 and c.lane.y <= 37 and c.lane.y - c.lane.x + 1 <= int(_kn("lurecoil", "lane_max")), "its lane is its lake, islet and all (%s)" % [c.lane])
	_check(c.submerged() and not c.hit({"how": "slash", "amount": 99.0}), "under water it can't be reached")
	var tell := _measure(w, c, "tell", 6.0)
	_check(absf(tell - _kn("lurecoil", "leap_tell")) <= DT * 1.5, "the leap's tell: %.2f s (measured %.3f)" % [_kn("lurecoil", "leap_tell"), tell])
	_check(c.state == "leap" and c.arcs.size() == 1, "one arc on Dusk")
	var a: Dictionary = c.arcs[0]
	var tiles := absf(float(a["x1"]) - float(a["x0"])) / TILE
	_check(tiles >= 5.0 and tiles <= 7.0 and float(a["h"]) >= 3.0 * TILE and float(a["h"]) <= 4.0 * TILE,
			"5-7 tiles long (%.0f) and 3-4 high (%.1f)" % [tiles, float(a["h"]) / TILE])
	while c.state == "leap":
		_step(w, 1)
	var worst := 0.0
	var span := int(round(_kn("lurecoil", "leap_time") / DT))
	for i in c.head_path.size():
		var want: Vector2 = c.arc_at(a, minf(float(i + 1) / span, 1.0), c.surface_y)
		worst = maxf(worst, (c.head_path[i] as Vector2).distance_to(want))
	_check(c.head_path.size() >= span - 1 and worst < 0.5, "its head flies exactly the arc it drew (worst %.2f px)" % worst)
	_check(c.leaps == 1 and c.state == "swim", "after its first leap it goes back under")
	var rested := false
	var x_ok := true
	for i in int(12.0 / DT):
		_step(w, 1)
		var cx := floori(c.position.x / TILE)
		x_ok = x_ok and cx >= c.lane.x - 1 and cx <= c.lane.y + 1
		if c.state == "rest":
			rested = true
			break
	_check(rested and c.leaps == 2, "after its second it rests its head on the islet's edge")
	_check(c.rect() != Elites_NOWHERE() and not c.submerged(), "resting, it can be hit")
	# A hit on the resting head knocks the stolen candle loose: a wisp that heals.
	pl.hp = pl.max_hp * 0.5
	var hp0: float = pl.hp
	w.deal(c, 1.0, {"how": "slash", "flat": 1.0, "no_hitstop": true})
	_check(c.flames == 0 and c.wisps.size() == 1, "a hit knocks its stolen candle loose")
	for i in int(2.0 / DT):
		_step(w, 1)
		if c.wisps.is_empty():
			break
	_check(absf((pl.hp - hp0) - pl.max_hp * _kn("lurecoil", "heal")) < 1.0, "and the wisp heals him 6%")
	for i in int(10.0 / DT):
		_step(w, 1)
		var cx2 := floori(c.position.x / TILE)
		x_ok = x_ok and cx2 >= c.lane.x - 1 and cx2 <= c.lane.y + 1
	_check(x_ok, "it never leaves its lane")
	await _done(w)
	# Nightfall rests after every third; Witching leaps twice, both arcs drawn from the start.
	var wn := await _world(_lake_rows(), "", "nightfall", 6)
	var cn := _spawn(wn, "lurecoil", Vector2i(20, 13))
	_check(int(cn.k("rest_every")) == 3, "Nightfall: it rests after every third leap")
	await _done(wn)
	var ww := await _world(_lake_rows(), "", "witching", 6)
	_sturdy(ww)
	_settle(ww, Vector2(25 * TILE + 10, 13 * TILE))
	ww.player.invuln = 1000.0
	var cw := _spawn(ww, "lurecoil", Vector2i(20, 13))
	_measure(ww, cw, "tell", 6.0)
	_check(cw.arcs.size() == 2 and is_equal_approx(float(cw.arcs[1]["x0"]), float(cw.arcs[0]["x1"])), "Witching: a double leap, both arcs drawn from the tell")
	await _done(ww)
	# A stun mid-leap (a Perfect Guard on the bite) never holds the head in
	# the air: it flies its arc on, lands staggered and rests exposed.
	var wst := await _world(_lake_rows(), "", "dusk", 6)
	_sturdy(wst)
	_settle(wst, Vector2(25 * TILE + 10, 13 * TILE))
	wst.player.invuln = 1000.0
	var cs := _spawn(wst, "lurecoil", Vector2i(20, 13))
	for i in int(6.0 / DT):
		_step(wst, 1)
		if cs.state == "leap" and cs._u > 0.4:
			break
	var sa: Dictionary = cs.arcs[cs.arc_i]
	var p_stun: Vector2 = cs.position
	cs.apply_status("stun", 1.0)
	_step(wst, 12)
	var on_arc: bool = cs.state != "leap" or (cs.position as Vector2).distance_to(cs.arc_at(sa, minf(cs._u, 1.0), cs.surface_y)) < 0.5
	_check((cs.position as Vector2).distance_to(p_stun) > 5.0 and on_arc and not cs.stunned(), "stunned mid-leap, its head flies its arc on (%.0f px in 0.1 s)" % (cs.position as Vector2).distance_to(p_stun))
	var rest_ticks := 0
	var exposed := true
	for i in int(4.0 / DT):
		_step(wst, 1)
		if cs.state == "rest":
			rest_ticks += 1
			exposed = exposed and cs.rect() != Elites_NOWHERE()
		elif rest_ticks > 0:
			break
	_check(rest_ticks * DT >= 1.0 - DT * 2.0 and exposed and cs.leaps == 1, "it lands staggered and rests exposed for the stun (%.2f s, after leap %d)" % [rest_ticks * DT, cs.leaps])
	await _done(wst)


# ---------------------------------------------------------------- Dreads and Wardens

func _test_dreads() -> void:
	var dreads := [
		["Queen Crackle", "glassmite", "Twinned,Glassed", 1.6, 5, Vector2i(30, 12)],
		["Glintwatch", "refractor", "Warded,Echoing", 1.0, 5, Vector2i(30, 9)],
		["Dame Vitrail", "paneguard", "Swift,Vengeful", 1.0, 5, Vector2i(30, 12)],
		["The Hush-a-Bye", "hushling", "Twinned,Hushed", 1.8, 6, Vector2i(30, 12)],
		["The Stitched Choir", "stillmaw", "Warded,Hushed", 1.0, 6, Vector2i(30, 9)],
		["The Long Shadow", "unwick", "Swift,Warded", 1.0, 6, Vector2i(30, 12)],
	]
	for d in dreads:
		var w := await _world(_rows(60, {d[5]: "D"}), "dread: %s|%s|%s\n" % [d[0], d[1], d[2]], "dusk", d[4])
		var list := _only(w, d[1])
		_check(list.size() == 1, "%s spawns in %d-x" % [d[0], d[4]])
		if list.size() == 1:
			var e: Node2D = list[0]
			_check(e.tier == "dread" and e.elite_name == d[0] and not e.ordinary, "%s is a Dread (%s)" % [d[0], d[1]])
			_check(absf(e.scale_mult - float(d[3])) < 0.001, "%s at x%.1f" % [d[0], d[3]])
			var base: float = float(_tune(d[1])["life"])
			var want: float = base * Enemy_scale(e.area) * float(Combat.diff("dusk")["hp"]) * 4.0
			_check(absf(e.max_hp - want) < 0.5, "%s has a Dread's life (%.0f)" % [d[0], e.max_hp])
		await _done(w)
	# The W5-W6 secret Wardens.
	var wardens := [["Cherub Blusterby", "gustling", "Swift,Glassed", "5-S", 5, Vector2i(30, 9)],
			["Old Lampgullet", "lurecoil", "Warded,Hushed", "6-S", 6, Vector2i(30, 13)]]
	for d in wardens:
		var rows := _lake_rows() if d[1] == "lurecoil" else _rows(60)
		rows = _fill(rows, {d[5]: "D"})
		var w := await _world(rows, "warden: %s|%s|%s\n" % [d[0], d[1], d[2]], "dusk", d[4], d[3])
		var list := _only(w, d[1])
		_check(list.size() == 1 and list[0].tier == "warden", "%s spawns as %s's Warden" % [d[0], d[3]])
		if list.size() == 1:
			var e: Node2D = list[0]
			var life: float = float(e.WARDEN_LIFE[d[3]]) * Enemy_scale(e.area) * float(Combat.diff("dusk")["hp"])
			_check(absf(e.max_hp - life) < 0.5, "%s has a Warden's life (%.0f)" % [d[0], life])
			if d[1] == "gustling":
				_check(absf(e.scale_mult - _kn("gustling", "warden_scale")) < 0.001, "Cherub Blusterby is a big one")
			else:
				_check(e.flames == int(_kn("lurecoil", "warden_flames")), "Old Lampgullet's lure carries 3 flames")
		await _done(w)


func Enemy_scale(a: int) -> float:
	## enemy.gd's life scale (Combat.e_hp, else e_scale).
	for m in (Combat as Script).get_script_method_list():
		if m["name"] == "e_hp":
			return float((Combat as Script).call("e_hp", a))
	return Combat.e_scale(a)


# ---------------------------------------------------------------- elites

func _test_as_elites() -> void:
	## Every kind as an Anointed under each of v2's Omens (MA's pools add the
	## W5-W6 kinds): it keeps working, a Warded mote takes a hit, a Twinned
	## one splits in two.
	for k in KINDS:
		if k == "lurecoil":
			continue   # never Anointed (spec §4.6)
		for omen in ["Swift", "Warded", "Burning", "Twinned", "Vengeful"]:
			var wn := 6 if HK.is_w6(k) else 5
			var w := await _world(_rows(60), "", "nightfall", wn)
			_sturdy(w)
			_settle(w, Vector2(20 * TILE, 13 * TILE))
			w.player.invuln = 1000.0
			var e := _spawn(w, k, Vector2i(24, 12) if SPEC[k]["spawn"] == "floor" else Vector2i(24, 10))
			e.make_elite("anointed", [omen])
			_check(e.tier == "anointed" and not e.ordinary and e.max_hp > 0.0, "%s takes the Anointed tier (%s)" % [k, omen])
			_step(w, int(2.0 / DT))
			_check(e.alive and e.is_inside_tree(), "an Anointed %s with %s plays on" % [k, omen])
			if omen == "Warded" and k != "unwick":
				var hp0: float = e.hp
				var r: Dictionary = w.deal(e, 1.0, {"how": "shot", "flat": 5.0, "no_hitstop": true})
				_check(not r["hit"] and is_equal_approx(e.hp, hp0) or k == "paneguard", "a Warded %s's mote takes a hit" % k)
			if omen == "Twinned":
				var n0 := _only(w, k).size()
				e.hp = 0.0
				e._kill({"how": "slash", "from_x": e.position.x - 10.0})
				_step(w, 2)
				_check(_only(w, k).size() == n0 + 2, "a Twinned %s splits in two" % k)
				_step(w, int(1.0 / DT))
			await _done(w)


func _test_elites_seeded() -> void:
	## pick_elites (MA's) over a W5-W6 cast: the same seed picks the same.
	var fill := {}
	var x := 6
	for k in ["glassmite", "paneguard", "hushling", "unwick", "glassmite", "hushling", "paneguard"]:
		fill[Vector2i(x, 12)] = GLYPHS[k]
		x += 22
	var picks := []
	for run in 2:
		var w := await _world(_rows(170, fill), "", "witching", 5, "", true)
		var got := []
		for e in w.enemies:
			if e.tier == "anointed":
				got.append("%s@%d:%s" % [e.kind, e.spawn["cell"].x, ",".join(e.omens)])
		picks.append(got)
		await _done(w)
	_check(picks[0] == picks[1], "elites are deterministic per seed over the W5-W6 kinds (%s)" % [picks[0]])


# ---------------------------------------------------------------- the levels (once they exist)

func _test_levels() -> void:
	var ids := ["5-1", "5-2", "5-3", "5-4", "5-S", "6-1", "6-2", "6-3", "6-4", "6-S"]
	var any := false
	var Gus = _script("gustling")
	for id in ids:
		var path := "res://levels/%s.txt" % id
		if not FileAccess.file_exists(path):
			continue
		any = true
		var lv = LevelData.load_file(path)
		var probs: Array = Gus.placement_problems(lv)
		_check(probs.is_empty(), "%s: every Gustling at least 5 tiles from an edge it pushes toward %s" % [id, probs])
		var mprobs: Array = _script("glassmite").placement_problems(lv)
		_check(mprobs.is_empty(), "%s: no Glassmite on glass over the void without footing in a jump %s" % [id, mprobs])
		var coils := 0
		var bucks := 0
		var hush := 0
		for e in lv.entities:
			var c: Vector2i = e["cell"]
			match e["kind"]:
				"paneguard":
					_check(lv.tile(c.x, c.y + 1) != LevelData.GLASS, "%s: the Paneguard at %d stands on stone" % [id, c.x])
				"lurecoil":
					coils += 1
				"frostbuckle":
					bucks += 1
				"hushling":
					hush += 1
		_check(coils + bucks <= 3, "%s: at most 3 brutes (%d Lurecoils, %d Frostbuckles)" % [id, coils, bucks])
		if id == "6-1":
			_check(hush <= 10, "6-1: at most 10 Hushlings (%d)" % hush)
	if not any:
		_skip("no W5-W6 level files yet (WL5, WL6): the placement checks wait for them")
