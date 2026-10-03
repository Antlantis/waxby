extends SceneTree
## test_kits3: the five kits in v3 (KT). The root tables to rank 7 and the
## 8th for of the Keeper (spec §2.2), matching the cards; the dash stays
## 144 px and the wisps 3 at every rank; every calling with quirk "" (a
## level 40 hero with the whole deep tree) still runs and jumps as v1 Wick;
## no node names a movement constant (grep); each Special lets go of a vine,
## and a held one ends at a catch; the kit-read Deep and Mastery nodes
## (Bastion, Sanctuary, Judgment, Wildfire, Candlemold, Phantom Step, Fan of
## Knives, Molten Core, Carillon, Requiem, Barrow Bind); the new UNBLOCKABLE
## and BOWLED kinds; the knight's beam guard and its Perfect Guard reflect;
## the Sexton's wisp given to a Stillmaw's Gulp; Stampede on ice; and the
## rig: T4 and T5 candles, weapon_visible(), the cape trim and set_look().
##
##     godot --headless --path game --script res://tests/test_kits3.gd

const LevelData := preload("res://scripts/level_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Hero := preload("res://scripts/hero.gd")
const Classes := preload("res://scripts/classes.gd")
var WorldScript: GDScript   # loaded at run time: it needs the autoloads
const TILE := 32
const DT := 1.0 / 120.0
const GROUND := 13 * 32
const VINE_COL := 20

var _passed := 0
var _failed := 0
var game: Node


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	if game == null:
		print("test_kits3: no Game autoload")
		quit(1)
		return
	game.save_path = "user://test_kits3_save.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	await process_frame   # the autoloads' _ready (Game loads its save there) before any hero is made
	game.reset()
	var deep_was: bool = Classes.deep
	Classes.set_deep(true)   # the v3 tree (the game turns it on once the Sheet draws Tiers 4-5)
	_test_tables()
	_test_parity()
	_test_movement_grep()
	await _test_dash_and_wisps()
	await _test_vine_release()
	await _test_held_into_catch()
	await _test_hold_on_vine()
	await _test_knight()
	await _test_beams()
	await _test_witch()
	await _test_runner()
	await _test_founder()
	await _test_sexton()
	await _test_stampede_ice()
	await _test_rig()
	Classes.set_deep(deep_was)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_kits3_save.json" + suffix))
	game.save_path = game.SAVE_PATH
	game.load_save()
	print("test_kits3: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _level(rows: Array) -> RefCounted:
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n---\n" + "\n".join(rows))
	return lv


func _flat(w := 60, floor_glyph := "#") -> RefCounted:
	var rows := []
	for y in 15:
		rows.append(floor_glyph.repeat(w) if y == 13 else ("#".repeat(w) if y > 13 else ".".repeat(w)))
	rows[12] = "..P" + ".".repeat(w - 3)
	return _level(rows)


func _vine_level() -> RefCounted:
	## Floor at row 13; a vine hanging in column VINE_COL from a stone at row 2 down to row 11.
	var rows := []
	for y in 15:
		rows.append("#".repeat(60) if y >= 13 else ".".repeat(60))
	rows[2] = rows[2].substr(0, VINE_COL) + "#" + rows[2].substr(VINE_COL + 1)
	for y in range(3, 12):
		rows[y] = rows[y].substr(0, VINE_COL) + "{" + rows[y].substr(VINE_COL + 1)
	rows[12] = "..P" + ".".repeat(57)
	return _level(rows)


func _bare(lv: RefCounted, at: Vector2, cls := "", quirk := "", hero := {}) -> Node2D:
	## A player on its own (no World): a calling's stats and kit if cls is set.
	var p: Node2D = PlayerScript.new()
	p.level = lv
	p.reset_at(at)
	p.hurt_time = 10.0
	if cls != "":
		p.set_stats(Hero.stats(hero if not hero.is_empty() else Hero.blank(cls)))
		var kit: Object = load(Classes.info(cls)["kit"]).new()
		kit.cls = cls
		kit.setup(p, null)
		p.kit = kit
	p.quirk = quirk
	return p


func _deep_hero(cls: String, level := 40) -> Dictionary:
	## A hero with every node of the deep tree at its max (both capstones:
	## more than play allows, so every branch runs).
	var h: Dictionary = Hero.blank(cls)
	h["level"] = level
	for n in Classes.tree(cls):
		h["skills"][n["id"]] = int(n["max"])
	return h


func _world(cls: String, lv: RefCounted, skills := {}, level := 10) -> Node2D:
	game.reset()
	var h: Dictionary = game.new_hero(cls)
	h["level"] = level
	for id in skills:
		h["skills"][id] = int(skills[id])
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	w.apply_hero()
	for i in 30:
		w.tick(DT)
	w.player.hp = w.player.max_hp
	w.player.res = w.player.res_max
	return w


func _tick(w: Node2D, pad: Dictionary, n := 1) -> void:
	for i in n:
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _enemy(w: Node2D, kind: String, at: Vector2, rooted := true) -> Node2D:
	var e: Node2D = w.spawn_enemy(kind, at, {})
	e.active = true
	if rooted:
		e.apply_status("root", 999.0)
	return e


func _standin(w: Node2D, src: String, at: Vector2) -> Node2D:
	## A monster from a script written here (a stand-in for a kind that
	## hasn't landed, or one with a hook to watch), placed as spawn_enemy does.
	var gs := GDScript.new()
	gs.source_code = src
	gs.reload()
	var e: Node2D = gs.new()
	e.level = w.level
	e.world = w
	e.position = at
	e.facing = -1
	e.spawn = {"kind": "skeleton", "cell": Vector2i(-1, -1)}
	e.setup_stats(int(w.area), w.diff, w.strength, int(w.world_n))
	e.died.connect(w._on_enemy_died)
	w.get_node("Monsters").add_child(e)
	w.enemies.append(e)
	e.active = true
	e.apply_status("root", 999.0)
	return e


func _settle(rig: Node2D, n := 12) -> void:
	for i in n:
		rig._process(1.0 / 60.0)


func _free(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _on_vine(w: Node2D, row := 8) -> void:
	## Puts the hero on the test vine, hanging at a row, well after the catch.
	var pl: Node2D = w.player
	pl.position = Vector2((VINE_COL + 0.5) * TILE, row * TILE + 19.0)
	pl.velocity = Vector2.ZERO
	pl.on_floor = false
	pl.grab_vine(VINE_COL, 1.0)


# ---------------------------------------------------------------- the root tables

func _kit_for(cls: String, root_rank: int, hero := {}) -> Node2D:
	var p := _bare(_flat(), Vector2(100, GROUND), cls, "", hero)
	var root_id: String = Classes.tree(cls)[0]["id"]
	var r := mini(root_rank, 7)
	p.stats["ranks"][root_id] = r
	p.stats["root_rank"] = root_rank - r   # past 7: of the Keeper, on a weapon and a charm
	return p


func _test_tables() -> void:
	## Spec §2.2, ranks 6 and 7 and the 8th (of the Keeper over a full root).
	var want := {
		"knight": {"_rush_coef": [2.2, 2.4, 2.5], "_rush_cost": [17.0, 16.0, 16.0], "_block_share": [0.27, 0.25, 0.25]},
		"witch": {"_full_coef": [6.0, 6.4, 6.6]},
		"runner": {"_pip_time": [1.7, 1.6, 1.6], "_step_dist": [144.0, 144.0, 144.0], "_soot_bonus": [0.40, 0.43, 0.43]},
		"founder": {"_cost": [27.0, 26.0, 26.0], "_wave_coef": [1.95, 2.1, 2.1], "_wave_range": [220.0, 230.0, 230.0]},
		"sexton": {"_call_cost": [19.0, 18.0, 18.0], "_mote_coef": [0.85, 0.93, 0.93]},
	}
	for cls in want:
		for fn in want[cls]:
			var got := []
			var ok := true
			for i in 3:
				var p := _kit_for(cls, 6 + i)
				var v: float = float(p.kit.call(fn))
				got.append(snappedf(v, 0.001))
				ok = ok and is_equal_approx(v, float(want[cls][fn][i]))
				p.free()
			_check(ok, "%s: %s at ranks 6, 7, 8 is spec §2.2's %s (%s)" % [cls, fn, str(want[cls][fn]), str(got)])
	# The kits and the cards (classes.gd DEEP_ROOT_PER) agree at every rank.
	var card := {"knight": "_rush_coef", "witch": "_full_coef", "runner": "_step_dist", "founder": "_wave_coef", "sexton": "_mote_coef"}
	for cls in card:
		var root_id: String = Classes.tree(cls)[0]["id"]
		var table: Array = Classes.DEEP_ROOT_PER[root_id]
		var ok := true
		for r in range(1, 9):
			var p := _kit_for(cls, r)
			var v: float = float(p.kit.call(card[cls]))
			var c := float(table[r - 1]) / (100.0 if cls == "sexton" else 1.0)
			ok = ok and is_equal_approx(v, c)
			p.free()
		_check(ok, "%s: the kit's %s matches the card at ranks 1-8" % [cls, card[cls]])
	# Past the 8th (a full root and two Keepers) the coefficients still grow; the rest hold.
	var k9 := _kit_for("knight", 9)
	var w9 := _kit_for("witch", 9)
	_check(k9.kit._rush_coef() > 2.5 and w9.kit._full_coef() > 6.6 and is_equal_approx(k9.kit._rush_cost(), 16.0),
			"rank 9: the rush (%.2f) and the flare (%.2f) still grow, the rush's cost holds (%.0f)" % [k9.kit._rush_coef(), w9.kit._full_coef(), k9.kit._rush_cost()])
	k9.free()
	w9.free()
	# The deep tree's shape: 7 root ranks and Tiers 4 and 5 in both branches.
	for cls in Classes.ORDER:
		var t := Classes.tree(cls)
		var tiers := {}
		for n in t:
			tiers[int(n["tier"])] = int(tiers.get(int(n["tier"]), 0)) + 1
		_check(int(t[0]["max"]) == 7 and int(tiers.get(4, 0)) == 2 and int(tiers.get(5, 0)) == 2,
				"%s: the deep tree has a 7-rank root and two T4 and two T5 nodes" % cls)


# ---------------------------------------------------------------- movement

func _trace(p: Node2D) -> Array:
	var out := []
	var seq := [[{}, 24], [{"right": true}, 48], [{"right": true, "jump": true, "jump_pressed": true}, 1],
			[{"right": true, "jump": true}, 70], [{}, 60], [{"left": true, "jump": true, "jump_pressed": true}, 1],
			[{"left": true, "jump": true}, 3], [{"left": true}, 90], [{"jump": true, "jump_pressed": true}, 1], [{"jump": true}, 120]]
	for s in seq:
		for i in s[1]:
			p.pad = s[0]
			p.step(DT)
			out.append([p.position, p.velocity])
	return out


func _test_parity() -> void:
	## Every calling with quirk "", a level 40 hero holding the whole deep
	## tree, moves exactly as v1 Wick; with the quirk on, the plain run and
	## the held jump are still v1's.
	var lv := _flat()
	var ref := _bare(lv, Vector2(200, GROUND))
	var want := _trace(ref)
	ref.free()
	for cls in Classes.ORDER:
		var h := _deep_hero(cls)
		var p := _bare(lv, Vector2(200, GROUND), cls, "", h)
		var got := _trace(p)
		var same := got.size() == want.size()
		for i in mini(got.size(), want.size()):
			if got[i][0] != want[i][0] or got[i][1] != want[i][1]:
				same = false
				print("  %s parts from v1 at step %d: %s vs %s" % [cls, i, got[i], want[i]])
				break
		_check(same, "%s at L40 with every deep node and quirk \"\" moves exactly like v1 Wick" % cls)
		p.free()
		var q := _bare(lv, Vector2(200, GROUND), cls, Classes.info(cls)["quirk_id"], h)
		var r0 := _bare(lv, Vector2(200, GROUND))
		for i in 20:
			q.pad = {}
			r0.pad = {}
			q.step(DT)
			r0.step(DT)
		for i in 36:
			q.pad = {"right": true}
			r0.pad = {"right": true}
			q.step(DT)
			r0.step(DT)
		_check(q.velocity.x == PlayerScript.RUN_SPEED and r0.velocity.x == PlayerScript.RUN_SPEED,
				"%s at L40 with its quirk runs at 205 (%.1f)" % [cls, q.velocity.x])
		var top_q: float = q.position.y
		var top_r: float = r0.position.y
		for i in 150:
			var pd := {"jump": true, "jump_pressed": i == 0}
			q.pad = pd
			r0.pad = pd
			q.step(DT)
			r0.step(DT)
			top_q = minf(top_q, q.position.y)
			top_r = minf(top_r, r0.position.y)
		_check(is_equal_approx(top_q, top_r), "%s at L40: the held jump's height is v1's (%.1f vs %.1f)" % [cls, GROUND - top_q, GROUND - top_r])
		q.free()
		r0.free()
	# The constants themselves (contract §1: exact).
	var c := {"RUN_SPEED": 205.0, "JUMP_SPEED": 585.0, "DOUBLE_JUMP_SPEED": 470.0, "GRAVITY_UP": 1500.0, "GRAVITY_CUT": 3300.0,
			"GRAVITY_DOWN": 2150.0, "APEX_SPEED": 70.0, "APEX_GRAVITY": 0.55, "MAX_FALL": 640.0, "COYOTE": 0.12, "BUFFER": 0.15}
	var scr: Script = PlayerScript
	var consts: Dictionary = scr.get_script_constant_map()
	var ok := true
	for k in c:
		ok = ok and is_equal_approx(float(consts.get(k, -1.0)), float(c[k]))
	_check(ok, "player.gd's movement constants are v2's exactly")


const MOVE_CONSTS := ["RUN_SPEED", "JUMP_SPEED", "DOUBLE_JUMP_SPEED", "GRAVITY_UP", "GRAVITY_CUT", "GRAVITY_DOWN",
		"APEX_SPEED", "APEX_GRAVITY", "MAX_FALL", "COYOTE", "BUFFER", "GROUND_ACCEL", "GROUND_DECEL", "TURN_ACCEL",
		"AIR_ACCEL", "AIR_DECEL"]
# The only lines in the kits that read a movement constant (never write one):
# the Step ending at a run, and Grave Step's jump at 90% of a jump.
const MOVE_READS := ["player.velocity.x = _step_dir * player.RUN_SPEED", "player.air_leap(player.JUMP_SPEED * STEP_JUMP)"]


func _test_movement_grep() -> void:
	## No node names a movement constant: no node's stat or text is about
	## moving, and the kits read the constants only on the known lines.
	var words := ["speed", "jump", "gravity", "coyote", "accel", "movement", "move "]
	var bad := []
	for cls in Classes.ORDER:
		for n in Classes.tree(cls):
			var s := (str(n["stat"]) + " " + str(n["flag"]) + " " + str(n["id"])).to_lower()
			for m in MOVE_CONSTS:
				if s.find(m.to_lower()) >= 0 or str(n["text"]).find(m) >= 0:
					bad.append(n["id"])
			if int(n["tier"]) >= 4:
				var t := str(n["text"]).to_lower()
				for wd in words:
					if t.find(wd) >= 0 or str(n["stat"]).to_lower().find(wd) >= 0:
						bad.append("%s (%s)" % [n["id"], wd])
	_check(bad.is_empty(), "no tree node names a movement constant or moves him (%s)" % str(bad))
	var stray := []
	var d := DirAccess.open("res://scripts/kits")
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string("res://scripts/kits/" + f).split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("#"):
				continue
			for m in MOVE_CONSTS:
				if line.find(m) >= 0 and not (line in MOVE_READS):
					stray.append("%s:%d %s" % [f, i + 1, line])
	_check(stray.is_empty(), "the kits touch no movement constant but the two known reads (%s)" % str(stray))


func _test_dash_and_wisps() -> void:
	## The Step's dash stays 144 px, and the root's wisps 3, at every rank
	## (1-9: seven root ranks and two Keepers); a real Step at rank 9 goes 144 px.
	var ok_d := true
	var ok_w := true
	var dists := []
	var counts := []
	for r in range(1, 10):
		var p := _kit_for("runner", r)
		var dist: float = p.kit._step_dist()
		dists.append(dist)
		ok_d = ok_d and dist <= 144.0 and (r < 5 or is_equal_approx(dist, 144.0))
		p.free()
		var x := _kit_for("sexton", r)
		var n: int = x.kit.max_wisps()
		counts.append(n)
		ok_w = ok_w and n <= 3 and (r < 3 or n == 3)
		x.free()
	_check(ok_d, "the Step's dash is 144 px from rank 5 on, never more (%s)" % str(dists))
	_check(ok_w, "the root's wisps are 3 from rank 3 on, never more (%s)" % str(counts))
	var w := await _world("runner", _flat(), {"r_step": 7})
	var pl: Node2D = w.player
	pl.stats["root_rank"] = 2
	pl.reset_at(Vector2(300, GROUND))
	_tick(w, {}, 10)
	var x0: float = pl.position.x
	pl.res = 3.0
	_tick(w, {"right": true, "special": true}, 1)
	_tick(w, {"special": true}, 17)
	var moved: float = pl.position.x - x0
	_check(absf(moved - 144.0) < 8.0, "a rank 9 Step goes 144 px (%.1f, with the run after it)" % moved)
	await _free(w)
	w = await _world("sexton", _flat(), {"x_knell": 7})
	pl = w.player
	pl.stats["root_rank"] = 2
	for i in 6:
		pl.res = pl.res_max
		_tick(w, {"special": true}, 1)
		_tick(w, {}, 8)
	_check(w.kit.wisps.size() == 3, "a rank 9 Knell calls three wisps, no more (%d)" % w.kit.wisps.size())
	await _free(w)


# ---------------------------------------------------------------- vines

func _test_vine_release() -> void:
	## Each calling's Special lets go of the vine (world.gd lets go first,
	## then the kit plays it as in the air).
	for cls in Classes.ORDER:
		var w := await _world(cls, _vine_level())
		var pl: Node2D = w.player
		_on_vine(w)
		_tick(w, {}, 3)
		var on: bool = pl.climbing
		pl.res = pl.res_max
		_tick(w, {"special": true}, 1)
		_check(on and not pl.climbing, "%s: the Special lets go of the vine (on %s, after %s)" % [cls, on, pl.climbing])
		_tick(w, {}, 60)
		# The basic still works on the vine, facing out.
		_on_vine(w)
		_tick(w, {}, 3)
		var id0: int = pl.attack_id
		_tick(w, {"left": true, "attack": true, "attack_pressed": true}, 1)
		_check(pl.climbing and pl.attack_id == id0 + 1 and pl.facing == -1, "%s: the basic attack works on a vine, facing out" % cls)
		await _free(w)


func _tall_vine_level() -> RefCounted:
	## A long vine: column VINE_COL from a stone at row 2 down to row 40, the floor at row 43.
	var rows := []
	for y in 45:
		rows.append("#".repeat(60) if y >= 43 else ".".repeat(60))
	rows[2] = rows[2].substr(0, VINE_COL) + "#" + rows[2].substr(VINE_COL + 1)
	for y in range(3, 41):
		rows[y] = rows[y].substr(0, VINE_COL) + "{" + rows[y].substr(VINE_COL + 1)
	rows[42] = "..P" + ".".repeat(57)
	return _level(rows)


func _test_hold_on_vine() -> void:
	## A Special pressed on a vine lets go, then plays as in the air while
	## it's held (spec §2.4): no re-catch meanwhile. Held 1 s on a long
	## vine, the knight still guards, the witch's charge fills and her
	## release throws a full flare; let go, and each catches the vine again.
	for cls in ["knight", "witch"]:
		var w := await _world(cls, _tall_vine_level())
		var pl: Node2D = w.player
		var kit: Object = w.kit
		_on_vine(w, 5)
		_tick(w, {}, 3)
		pl.res = pl.res_max
		var caught := false
		_tick(w, {"special": true}, 1)
		for i in 120:
			_tick(w, {"special": true})
			caught = caught or pl.climbing
		var holding: bool = kit.guarding if cls == "knight" else (kit.charging and is_equal_approx(kit.charge, 1.0))
		_check(not caught and holding and kit.holding_special(),
				"%s: a Special held 1 s after letting go of a vine plays on in the air (re-caught %s, still held %s)" % [cls, caught, holding])
		var bursts0: int = kit.bursts if cls == "witch" else 0
		_tick(w, {}, 1)
		var full := false
		if cls == "witch":
			for sh in w.shots:
				full = full or (sh["kind"] == "flare" and is_equal_approx(float(sh.get("frac", 0.0)), 1.0))
		var back := false
		for i in 12:
			_tick(w, {})
			back = back or pl.climbing
		_check(back, "%s: let go of the Special, and he catches the vine again" % cls)
		if cls == "witch":
			for i in 200:
				if kit.bursts > bursts0:
					break
				_tick(w, {})
			_check(full and kit.bursts == bursts0 + 1, "witch: the release throws a full flare (full %s, bursts %d)" % [full, kit.bursts - bursts0])
		await _free(w)


func _test_held_into_catch() -> void:
	## A held Special falling past a vine catches none (it plays as in the
	## air): the knight's guard stays up, the witch's charge keeps filling;
	## let go, and the vine holds them. A vine is footing: the runner's air
	## Step and Grave Step come back.
	for cls in ["knight", "witch"]:
		var w := await _world(cls, _vine_level())
		var pl: Node2D = w.player
		var kit: Object = w.kit
		pl.position = Vector2((VINE_COL + 0.5) * TILE, 5 * TILE)
		pl.velocity = Vector2(0, 100)
		pl.on_floor = false
		pl.res = pl.res_max
		_tick(w, {"special": true}, 1)
		var caught := false
		for i in 20:
			_tick(w, {"special": true})
			caught = caught or pl.climbing
		var held: bool = kit.guarding if cls == "knight" else kit.charging
		var shots0: int = w.shots.size()
		_tick(w, {}, 1)
		var thrown: bool = cls != "witch" or w.shots.size() > shots0
		var back := false
		for i in 10:
			_tick(w, {})
			back = back or pl.climbing
		_check(not caught and held and thrown and back,
				"%s: a Special held past a vine catches none (caught %s, held %s); let go, it plays out (%s) and he catches (%s)" % [cls, caught, held, thrown, back])
		await _free(w)
	var w := await _world("runner", _vine_level())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.position = Vector2((VINE_COL - 4.5) * TILE, 6 * TILE)
	pl.velocity = Vector2.ZERO
	pl.on_floor = false
	pl.res = 3.0
	_tick(w, {"right": true, "special": true}, 1)
	var used: bool = kit._air_used
	_tick(w, {}, 16)
	_on_vine(w)
	_tick(w, {}, 2)
	_check(used and not kit._air_used, "runner: catching a vine gives the air Step back")
	await _free(w)
	w = await _world("sexton", _vine_level())
	pl = w.player
	kit = w.kit
	kit._step_used = true
	_on_vine(w)
	_tick(w, {}, 2)
	_check(not kit._step_used, "sexton: catching a vine gives Grave Step back")
	# A Toll-able press held past a vine catches none until the Toll rings; then the vine holds him.
	for i in 2:
		pl.res = pl.res_max
		kit.call_wisp()
	pl.res = pl.res_max
	pl.release_vine()
	pl.position = Vector2((VINE_COL + 0.5) * TILE, 5 * TILE)
	pl.velocity = Vector2(0, 100)
	pl.on_floor = false
	kit._step_used = false
	_tick(w, {}, 32)   # (past the RECATCH lock of the column he just left)
	pl.position = Vector2((VINE_COL + 0.5) * TILE, 5 * TILE)
	pl.velocity = Vector2(0, 100)
	pl.climbing = false
	_tick(w, {"special": true}, 1)
	var tolled := false
	var caught := false
	var after := false
	for i in 60:
		var n0: int = kit.wisps.size()
		_tick(w, {"special": true})
		if n0 > 0 and kit.wisps.is_empty():
			tolled = true   # (it rang this tick: the catch may come in the same one)
		if tolled:
			after = after or pl.climbing
		else:
			caught = caught or pl.climbing
		if after:
			break
	_check(tolled and not caught and after, "sexton: a press held into a Toll catches no vine until it rings, then the vine holds him (tolled %s, caught before %s, after %s)" % [tolled, caught, after])
	await _free(w)


# ---------------------------------------------------------------- the knight

func _test_knight() -> void:
	var w := await _world("knight", _flat(), {"k_bastion": 3, "k_sanctuary": 2, "k_judgment": 2})
	var pl: Node2D = w.player
	var kit: Object = w.kit
	# Bastion: blocks cost 35% less.
	var plain: float = 30.0 * 0.5 * kit.DUSK_BLOCK / Combat_p_hp(10)
	_check(is_equal_approx(kit.block_cost(30.0), maxf(kit.BLOCK_MIN, plain * 0.65)), "Bastion 3: a block costs 35%% less (%.2f of %.2f)" % [kit.block_cost(30.0), plain])
	# The new unblockable kinds pass a raised shield.
	pl.reset_at(Vector2(300, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	_tick(w, {"special": true}, 1)
	var through := []
	for kind in ["grasp", "snuff", "pop", "icicle", "spike_line", "deep_quiet"]:
		if is_equal_approx(kit.filter_damage(20.0, {"kind": kind, "from_x": pl.position.x + 30.0}), 20.0):
			through.append(kind)
	_check(through.size() == 6, "grasp, snuff, pop, icicle, spike_line and the Deep Quiet pass the shield (%s)" % str(through))
	_check(kit.filter_damage(20.0, {"kind": "hit", "from_x": pl.position.x + 30.0}) == 0.0, "(a plain frontal blow in the window is still guarded)")
	_tick(w, {}, 30)
	# Sanctuary: a Perfect Guard stuns every foe within 90 px (not one further off).
	var near := _enemy(w, "skeleton", pl.position + Vector2(-70, 0), false)
	var far := _enemy(w, "skeleton", pl.position + Vector2(160, 0), false)
	near.status.erase("stun")
	far.status.erase("stun")
	_tick(w, {"special": true}, 1)
	kit.filter_damage(20.0, {"kind": "arrow", "from_x": pl.position.x + 40.0})
	_check(float(near.status.get("stun", 0.0)) >= 0.95 and not far.status.has("stun"),
			"Sanctuary 2: a Perfect Guard stuns a foe 70 px off for 1 s, not one 160 px off (%.2f, %s)" % [float(near.status.get("stun", 0.0)), far.status.has("stun")])
	_tick(w, {}, 60)
	# Any Perfect Guard throws a Silence Bolt back (spec §5.5.7), Mirrored Glass or not.
	var mine := func() -> int:
		var n := 0
		for sh in w.shots:
			if sh["owner"] == "player":
				n += 1
		return n
	near.alive = false
	far.position = pl.position + Vector2(160, 0)
	far.apply_status("root", 999.0)
	far.max_hp = 9999.0
	far.hp = 9999.0   # (it takes the bolts sent back)
	var pg0: int = kit.perfect_guards
	var m0: int = mine.call()
	_tick(w, {"special": true}, 1)
	pl.invuln = 0.0
	kit.filter_damage(20.0, {"kind": "silence", "from_x": pl.position.x + 40.0, "source": far, "opts": {"shot": true}})
	_check(int(mine.call()) == m0 + 1, "a perfectly guarded Silence Bolt goes back without Mirrored Glass")
	_tick(w, {}, 160)   # (past the free-block time)
	m0 = mine.call()
	_tick(w, {"special": true}, 1)
	pl.invuln = 0.0
	kit.filter_damage(20.0, {"kind": "blade", "from_x": pl.position.x + 40.0, "source": far, "opts": {"shot": true}})
	_check(int(mine.call()) == m0 + 1 and kit.perfect_guards == pg0 + 2, "so does a blade of the Saint's Rose of Blades (spec §5.4), Mirrored Glass or not")
	_tick(w, {}, 60)
	# An arrow from a known source: without Mirrored Glass it's only blocked.
	_tick(w, {}, 160)   # (the archer's free-block time after the last Perfect Guard runs out, and its hitstops)
	m0 = mine.call()
	_tick(w, {"special": true}, 1)
	pl.invuln = 0.0
	kit.filter_damage(20.0, {"kind": "arrow", "from_x": pl.position.x + 40.0, "source": far, "opts": {"shot": true}})
	_check(int(mine.call()) == m0 and kit.perfect_guards == pg0 + 3, "a perfectly guarded arrow needs Mirrored Glass to go back")
	pl.stats["ranks"]["k_mirror"] = 1
	_tick(w, {}, 160)   # (the archer's free-block time after the last Perfect Guard runs out, and its hitstops)
	m0 = mine.call()
	_tick(w, {"special": true}, 1)
	pl.invuln = 0.0
	kit.filter_damage(20.0, {"kind": "arrow", "from_x": pl.position.x + 40.0, "source": far, "opts": {"shot": true}})
	_check(int(mine.call()) == m0 + 1 and kit.perfect_guards == pg0 + 4, "with it, even an arrow whose archer is known goes back (a shot, not a touch)")
	_tick(w, {}, 160)   # (past the free-block time, and the hitstops inside it)
	m0 = mine.call()
	_tick(w, {"special": true}, 1)
	pl.invuln = 0.0
	kit.filter_damage(20.0, {"kind": "hit", "from_x": pl.position.x + 40.0, "source": far})
	_check(int(mine.call()) == m0 and kit.perfect_guards == pg0 + 5, "(a foe's own touch is never thrown back)")
	pl.stats["ranks"]["k_mirror"] = 0
	_tick(w, {}, 60)
	for sh in w.shots:
		sh["life"] = 0.0
	near.alive = false
	far.alive = false
	_tick(w, {}, 5)
	# Judgment: a Finisher deals 60% more and always crits (the fallback: a crit top-up).
	pl.stats["crit"] = 0.0
	var e := _enemy(w, "thornback", pl.position + Vector2(34, 0))
	e.max_hp = 99999.0
	e.hp = 99999.0
	var cuts := []
	for i in 2:
		var h0: float = e.hp
		_tick(w, {"attack": true, "attack_pressed": true}, 1)
		_tick(w, {}, 40)
		cuts.append(h0 - e.hp)
	var one: float = float(pl.stats["basic"]) * (1.0 + float(pl.stats["dmg_pct"]))
	_check(cuts[0] > 0.0 and cuts[0] < one * 1.12 and cuts[1] < one * 1.12, "the first two cuts are plain (no crit forced: %s of %.1f)" % [str(cuts), one])
	var hp0: float = e.hp
	_tick(w, {"attack": true, "attack_pressed": true}, 1)
	_check(pl.attack_id == kit._finisher_id and is_equal_approx(kit.melee_coef(), 1.6 * 1.6), "Judgment 2: the Finisher is 1.6 x 1.6 basic (%.2f)" % kit.melee_coef())
	_tick(w, {}, 30)
	var dealt: float = hp0 - e.hp
	var base: float = float(pl.stats["basic"]) * (1.0 + float(pl.stats["dmg_pct"])) * 1.6 * 1.6
	var cm: float = float(pl.stats["crit_mult"])
	_check(dealt > base * cm * 0.88 and dealt < base * cm * 1.12, "and it crits, crit chance 0 or not (%.0f dealt, a crit ~%.0f)" % [dealt, base * cm])
	var nums := []
	var crit_sum := 0.0
	for it in w.floaters.items:
		if it["key"] == e.get_instance_id() and float(it["t"]) < 0.4:
			nums.append("%s %.0f" % [it["kind"], float(it["value"])])
			crit_sum += float(it["value"]) if it["kind"] == "crit" else 0.0
	_check(nums.size() == 1 and str(nums[0]).begins_with("crit") and absf(crit_sum - dealt) < 1.5,
			"and it shows as one crit number, the whole Finisher (%s, %.0f dealt)" % [str(nums), dealt])
	# With the World taking melee_opts (KT's request), the swing carries the crit itself: no top-up.
	_tick(w, {}, 60)
	for i in 2:
		_tick(w, {"attack": true, "attack_pressed": true}, 1)
		_tick(w, {}, 40)
	_tick(w, {"attack": true, "attack_pressed": true}, 1)
	var opts: Dictionary = kit.melee_opts(e)
	var hp1: float = e.hp
	var res: Dictionary = w.deal(e, kit.melee_coef(), {"how": "slash", "attack_id": pl.attack_id, "force_crit": opts.get("force_crit", false)})
	_check(opts.get("force_crit", false) and res["crit"] and absf((hp1 - e.hp) - float(res["amount"])) < 0.01,
			"with melee_opts wired the Finisher's own blow crits, and nothing is added after (%.0f)" % (hp1 - e.hp))
	await _free(w)


func Combat_p_hp(level: int) -> float:
	return pow(1.10, level - 1)


const REFLECT_WATCH := "extends \"res://scripts/skeleton.gd\"\nvar reflected := 0\nfunc on_reflected(_b) -> void:\n\treflected += 1\n"


func _beam(w: Node2D, a: Vector2, b: Vector2, src: Object, reflect := true, dmg := 24.0) -> Dictionary:
	return w.add_hazard({"kind": "beam", "seg": [a, b], "width": 6.0, "life": 0.25, "dmg": dmg, "owner": "enemy",
			"reflect": reflect, "source": src})


func _test_beams() -> void:
	## The knight guards a beam by its line (shape "segment"): from the front
	## it's blocked (Grace pays), a Perfect Guard sends it back along its line
	## (the source hurt and told), from behind or from straight overhead it
	## gets through, and a source whose body hovers over his head still meets
	## the shield when its beam comes in low.
	var w := await _world("knight", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(400, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	var src := _standin(w, REFLECT_WATCH, pl.position + Vector2(200, -60))
	src.max_hp = 9999.0
	src.hp = 9999.0
	var c: Vector2 = pl.center()
	# A Perfect Guard: the beam goes back.
	_tick(w, {"special": true}, 1)
	var hz := _beam(w, src.center(), c + Vector2(-60, 12), src)
	var hp0: float = pl.hp
	_tick(w, {"special": true}, 4)
	_check(pl.hp == hp0 and kit.perfect_guards == 1 and kit.reflects == 1, "a beam met in the Perfect Guard window is reflected (pg %d, reflects %d)" % [kit.perfect_guards, kit.reflects])
	_check(src.hp < 9999.0 and src.reflected == 1, "the way back hurts its source and tells it (%.0f, told %d)" % [9999.0 - src.hp, src.reflected])
	_check(not src.status.has("stun") or float(src.status.get("stun", 0.0)) < 0.5, "(and doesn't shove a source across the room)")
	_check(((hz["seg"] as Array)[1] as Vector2).distance_to(pl.center()) < 30.0, "and the beam ends at the shield")
	_tick(w, {"special": true}, 40)
	_check(pl.hp == hp0 and kit.reflects == 1, "a beam is reflected once, and the rest of it is guarded")
	_tick(w, {}, 60)
	w.hazards.clear()
	# Sent back, the rest of a beam is spent: letting go of the guard at once costs nothing.
	src.hp = 9999.0
	_tick(w, {"special": true}, 1)
	_beam(w, src.center(), c + Vector2(-60, 12), src)
	_tick(w, {"special": true}, 2)
	_tick(w, {}, 40)
	_check(pl.hp == hp0 and kit.reflects == 2, "a reflected beam never hurts him after, guard or no guard")
	_tick(w, {}, 60)
	w.hazards.clear()
	# A later beam in the same guard: an ordinary block, Grace pays.
	pl.res = 60.0
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, 40)
	var hz2 := _beam(w, src.center(), c + Vector2(-60, 12), src, false)
	_tick(w, {"special": true}, 30)
	_check(pl.hp == hp0 and kit.blocks >= 1 and pl.res < 60.0, "a beam after the window is blocked for Grace (%.1f)" % pl.res)
	_check(((hz2["seg"] as Array)[1] as Vector2).x < c.x - 50.0, "(and it isn't reflected)")
	_tick(w, {}, 60)
	w.hazards.clear()
	# From behind: no help.
	pl.invuln = 0.0
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, 30)
	_beam(w, c + Vector2(-220, -40), c + Vector2(60, 10), src)
	_tick(w, {"special": true}, 10)
	_check(pl.hp < hp0, "a beam from behind gets through the guard")
	_tick(w, {}, 150)
	w.hazards.clear()
	# From straight overhead: past the shield.
	pl.hp = pl.max_hp
	pl.invuln = 0.0
	hp0 = pl.hp
	_tick(w, {"special": true}, 1)
	_beam(w, c + Vector2(6, -300), c + Vector2(0, 40), src)
	_tick(w, {"special": true}, 10)
	_check(pl.hp < hp0, "a beam from straight overhead gets past the shield")
	_tick(w, {}, 150)
	w.hazards.clear()
	# Unbroken Vigil turns the shield to every side, never up: overhead is still past it.
	if not pl.stats.has("flags") or not (pl.stats["flags"] is Dictionary):
		pl.stats["flags"] = {}
	pl.stats["flags"]["unbroken"] = true
	pl.reset_at(Vector2(400, GROUND))   # (the last beam knocked him back)
	pl.facing = 1
	_tick(w, {}, 5)
	c = pl.center()
	pl.hp = pl.max_hp
	pl.invuln = 0.0
	hp0 = pl.hp
	_tick(w, {"special": true}, 1)
	_beam(w, c + Vector2(6, -300), c + Vector2(0, 40), src)
	_tick(w, {"special": true}, 10)
	var through: bool = pl.hp < hp0
	_tick(w, {}, 150)
	w.hazards.clear()
	pl.hp = pl.max_hp
	pl.invuln = 0.0
	hp0 = pl.hp
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, 30)
	_beam(w, c + Vector2(-220, -40), c + Vector2(60, 10), src, false)
	_tick(w, {"special": true}, 10)
	var behind: bool = pl.hp == hp0
	pl.stats["flags"].erase("unbroken")
	_check(through and behind, "with Unbroken Vigil a beam from behind is guarded (%s), one from straight overhead still gets past (%s)" % [behind, through])
	_tick(w, {}, 150)
	w.hazards.clear()
	# A source hovering over his head whose beam comes in low from the front: guarded.
	pl.hp = pl.max_hp
	pl.invuln = 0.0
	hp0 = pl.hp
	src.position = pl.position + Vector2(10, -120)
	_tick(w, {"special": true}, 1)
	_beam(w, c + Vector2(240, -50), c + Vector2(-40, 8), src)
	_tick(w, {"special": true}, 10)
	_check(pl.hp == hp0, "a beam coming in low from the front is guarded, wherever its source's body hangs")
	await _free(w)


# ---------------------------------------------------------------- the witch

func _test_witch() -> void:
	var w := await _world("witch", _flat(), {"w_wildfire": 2, "w_candlemold": 2})
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	# Candlemold: +25% on a waxed foe, through the kit's own blows.
	var e := _enemy(w, "thornback", pl.position + Vector2(120, 0))
	e.max_hp = 9999.0
	e.hp = 9999.0
	_check(kit.bonus_vs(e) == 0.0, "Candlemold: nothing on a foe that isn't waxed")
	e.apply_status("waxed", 5.0)
	_check(is_equal_approx(kit.bonus_vs(e), 0.25), "Candlemold 2: a waxed foe takes 25%% more (%.2f)" % kit.bonus_vs(e))
	var hp0: float = e.hp
	var dmg: float = float(pl.stats.get("dmg_pct", 0.0))
	pl.stats["dmg_pct"] = 0.5   # (a flat blow pays the bonus as if rolled: 40 x (1 + 0.25 / 1.5))
	kit.deal_as("dot", e, 1.0, {"how": "burn", "flat": 40.0, "no_hitstop": true})
	pl.stats["dmg_pct"] = dmg
	_check(absf((hp0 - e.hp) - 40.0 * (1.0 + 0.25 / 1.5)) < 0.51, "a burn tick of 40 on a waxed foe pays +25%% as rolled blows do: %.1f (dmg_pct 50%%)" % (hp0 - e.hp))
	# A spark on its way to a waxed foe carries the bonus.
	e.position = pl.position + Vector2(60, 0)
	_tick(w, {"attack": true, "attack_pressed": true}, 1)
	var spark_extra := 0.0
	for i in 8:
		_tick(w, {})
		for s in kit._sparks:
			spark_extra = maxf(spark_extra, float(s.get("extra_pct", 0.0)))
	_check(is_equal_approx(spark_extra, 0.25), "a spark about to meet a waxed foe carries +25%% (%.2f)" % spark_extra)
	e.alive = false
	_tick(w, {}, 60)
	# A boss-sized waxed body (96x128) gets it too, from a spark and from a flare's direct hit.
	pl.stats["crit"] = 0.0
	var big := _enemy(w, "skeleton", pl.position + Vector2(110, 0))
	big.size = Vector2(96, 128)
	big.max_hp = 99999.0
	big.hp = 99999.0
	big.apply_status("waxed", 30.0)
	var unit: float = float(pl.stats["basic"]) * (1.0 + float(pl.stats.get("dmg_pct", 0.0)))
	var h0: float = big.hp
	_tick(w, {"attack": true, "attack_pressed": true}, 1)
	var sp: Dictionary = kit._sparks[0] if kit._sparks.size() > 0 else {}
	for i in 30:
		_tick(w, {})
		if big.hp < h0:
			break
	var ratio: float = (h0 - big.hp) / unit / (1.0 + 0.25 / (1.0 + float(pl.stats.get("dmg_pct", 0.0))))
	_check(not sp.is_empty() and is_equal_approx(float(sp.get("extra_pct", 0.0)), 0.25) and ratio > 0.89 and ratio < 1.11,
			"a spark into a 96x128 waxed foe gets Candlemold, measured from its edge (%.2f, x%.2f basic)" % [float(sp.get("extra_pct", 0.0)), ratio])
	_tick(w, {}, 60)
	pl.res = pl.res_max
	h0 = big.hp
	var fl: Dictionary = kit.throw_flare(1.0)
	var direct := {"amt": -1.0}
	var burst_on: Callable = fl["on_hit"]
	fl["on_hit"] = func(sh, e2, res):
		direct["amt"] = float(res.get("amount", 0.0))   # the World's own shot deal (the fire floor's ticks aside)
		burst_on.call(sh, e2, res)
	for i in 60:
		_tick(w, {})
		if fl.get("burst", false):
			break
	var sp_pct: float = float(pl.stats.get("special_pct", 0.0))
	var want: float = unit * float(fl["coef"]) * (1.0 + 0.25 / (1.0 + float(pl.stats.get("dmg_pct", 0.0)))) \
			* (1.0 + sp_pct / (1.0 + float(pl.stats.get("dmg_pct", 0.0)) + 0.25))
	var got: float = float(direct["amt"])
	_check(fl.get("burst", false) and big.hp < h0 and is_equal_approx(float(fl.get("extra_pct", 0.0)), 0.25) and got > want * 0.89 and got < want * 1.11,
			"a flare's direct hit on a waxed boss-sized foe gets Candlemold too (+%.2f, %.0f dealt, ~%.0f)" % [float(fl.get("extra_pct", 0.0)), got, want])
	big.alive = false
	_tick(w, {}, 150)
	# Wildfire: a burning foe that dies bursts into 3 sparks (no light), at the foes near.
	var a := _enemy(w, "skeleton", pl.position + Vector2(100, 0))
	var b := _enemy(w, "skeleton", pl.position + Vector2(180, 0))
	var shots0: int = w.shots.size()
	kit.add_dot(a, 0.1, 3.0, "kindle")
	a.hp = 1.0
	kit.deal_as("stab", a, 1.0, {"flat": 50.0})
	var wild := []
	for s in w.shots:
		if s.get("wildfire", false):
			wild.append(s)
	_check(kit.wildfires == 1 and wild.size() == 3, "Wildfire: a burning foe that dies bursts into 3 sparks (%d)" % wild.size())
	var dark := true
	var coefs := true
	for s in wild:
		dark = dark and float(s.get("light", 0.0)) == 0.0
		coefs = coefs and is_equal_approx(float(s["coef"]), 1.0)
	_check(dark and coefs, "the sparks are 100% basic and light nothing (no new light source)")
	_check(wild.size() > 0 and ((wild[0]["vel"] as Vector2).normalized()).dot((b.center() - a.center()).normalized()) > 0.95, "the first flies at the nearest foe")
	var c := _enemy(w, "skeleton", pl.position + Vector2(60, 0))
	c.hp = 1.0
	kit.deal_as("stab", c, 1.0, {"flat": 50.0})
	_check(kit.wildfires == 1, "a foe that dies not burning bursts into nothing")
	_check(kit._sparks.is_empty() and kit._wild.size() == 3 and w.shots.size() >= shots0 + 3, "Wildfire's sparks don't take her three")
	await _free(w)


# ---------------------------------------------------------------- the runner

func _test_runner() -> void:
	var w := await _world("runner", _flat(), {"r_phantom": 2, "r_fan": 2})
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	# Phantom Step: through a foe, half a pip back, once a Step (two foes: one refund).
	_enemy(w, "skeleton", pl.position + Vector2(50, 0))
	_enemy(w, "skeleton", pl.position + Vector2(80, 0))
	pl.res = 2.0
	_tick(w, {"right": true, "special": true}, 1)
	var after_press: float = pl.res
	_tick(w, {}, 20)
	_check(kit.phantoms == 1, "Phantom Step 2: a Step through two foes refunds once (%d)" % kit.phantoms)
	_check(pl.res > after_press + 0.49, "and gives back half a pip (%.2f -> %.2f)" % [after_press, pl.res])
	for e in w.enemies:
		e.alive = false
	_tick(w, {}, 30)
	# Fan of Knives: every 6th throw fans out 3 extra (rank 2: 3), and she can still throw.
	var fans_seen := 0
	for n in 6:
		if n > 0:
			_tick(w, {}, 70)
		_tick(w, {"attack": true, "attack_pressed": true}, 1)
		var fan := 0
		for s in w.shots:
			if s.get("fan", false):
				fan += 1
		fans_seen = maxi(fans_seen, fan)
	_check(kit.throws == 6 and kit.fans == 1 and fans_seen == 3, "Fan of Knives 2: the 6th throw fans out 3 more knives (%d throws, %d fans, %d)" % [kit.throws, kit.fans, fans_seen])
	# Straight after the fan (its 3 knives still flying, one plain one), she
	# throws two more plain knives, and only a 4th plain one is refused.
	var count := func(fan: bool) -> int:
		var n := 0
		for s in kit._knives:
			if s["life"] > 0.0 and bool(s.get("fan", false)) == fan:
				n += 1
		return n
	var plain_after := []
	for n in 3:
		_tick(w, {}, 1)
		pl._cooldown = 0.0   # (the throws come as fast as the test likes; the cap is what's tested)
		_tick(w, {"attack": true, "attack_pressed": true}, 1)
		plain_after.append(count.call(false))
	var fan_live: int = count.call(true)
	_check(fan_live == 3 and plain_after == [2, 3, 3] and kit.throws == 8,
			"and the fan never counts against her three (fan knives %d alive; plain %s; %d throws)" % [fan_live, str(plain_after), kit.throws])
	await _free(w)


# ---------------------------------------------------------------- the founder

func _test_founder() -> void:
	var w := await _world("founder", _flat(), {"f_moltencore": 2, "f_carillon": 2})
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(400, GROUND))
	_tick(w, {}, 10)
	# Molten Core: white-hot, harm is cut 25%.
	pl.res = 50.0
	var cool: float = kit.filter_damage(40.0, {"kind": "hit", "from_x": pl.position.x + 20.0})
	pl.res = pl.res_max
	var hot: float = kit.filter_damage(40.0, {"kind": "hit", "from_x": pl.position.x + 20.0})
	_check(is_equal_approx(cool, 40.0) and is_equal_approx(hot, 30.0), "Molten Core 2: white-hot, a blow of 40 is 30 (%.1f; %.1f cool)" % [hot, cool])
	# Carillon: the waves run 35% further.
	_check(is_equal_approx(kit._wave_range(), 150.0 * 1.35), "Carillon 2: the waves run 35%% further (%.1f)" % kit._wave_range())
	pl.res = 50.0
	w.hazards.clear()
	_tick(w, {"special": true}, 1)
	var life := 0.0
	for h in w.hazards:
		if h["kind"] == "wave" and h["owner"] == "player":
			life = maxf(life, float(h["life"]))
	_check(absf(life - 150.0 * 1.35 / kit.WAVE_SPEED) < 0.02, "a Peal's wave runs for its longer range (%.3f s)" % life)
	_tick(w, {}, 120)
	# BOWLED: a Tickwind and a Glassmite are bowled over; a Rootling only once it's up.
	_check("tickwind" in kit.BOWLED and "glassmite" in kit.BOWLED and "rootling" in kit.BOWLED, "BOWLED gains tickwind, glassmite and rootling")
	var up := _standin(w, "extends \"res://scripts/skeleton.gd\"\nvar state := \"walk\"\n", pl.position + Vector2(300, 0))
	up.kind = "rootling"
	var down := _standin(w, "extends \"res://scripts/skeleton.gd\"\nvar state := \"buried\"\n", pl.position + Vector2(340, 0))
	down.kind = "rootling"
	var says := _standin(w, "extends \"res://scripts/skeleton.gd\"\nfunc bowlable() -> bool:\n\treturn false\n", pl.position + Vector2(380, 0))
	says.kind = "tickwind"
	var tick := _enemy(w, "skeleton", pl.position + Vector2(420, 0))
	tick.kind = "tickwind"
	_check(kit.bowlable(up) and not kit.bowlable(down) and not kit.bowlable(says) and kit.bowlable(tick),
			"a walking Rootling and a Tickwind are bowled; a buried Rootling isn't, nor a kind that says no")
	# In play: a Stampede into a Tickwind bowls it and costs her nothing.
	for e in w.enemies:
		e.alive = false
	_tick(w, {}, 5)
	pl.reset_at(Vector2(200, GROUND))
	_tick(w, {}, 5)
	var tw := _enemy(w, "skeleton", Vector2(560, GROUND), false)
	tw.kind = "tickwind"
	tw.facing = -1
	tw.max_hp = 9999.0
	tw.hp = 9999.0
	pl.hp = pl.max_hp
	var bowled := false
	for i in 200:
		_tick(w, {"right": true})
		bowled = bowled or (tw.status.has("stun") and pl.stampeding)
		if tw.position.x < pl.position.x - 40.0 or not tw.alive:
			break
	_check(bowled and pl.hp == pl.max_hp, "a Stampede bowls a Tickwind over, unhurt (%.0f / %.0f)" % [pl.hp, pl.max_hp])
	await _free(w)


# ---------------------------------------------------------------- the sexton

func _test_sexton() -> void:
	var w := await _world("sexton", _flat(), {"x_requiem": 2, "x_barrow": 2})
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	# Requiem: the firing window lasts 60% longer.
	pl.res = pl.res_max
	_tick(w, {"special": true}, 1)
	_check(is_equal_approx(kit.fire_time(), 0.8 * 1.6) and kit.fire_window > 1.2, "Requiem 2: the wisps fire for 1.28 s after a Knell (%.2f)" % kit.fire_window)
	_tick(w, {}, 200)
	# Barrow Bind: a rooted foe takes 35% more (the fallback tops the spade up).
	var e := _enemy(w, "thornback", pl.position + Vector2(34, 0))
	e.max_hp = 99999.0
	e.hp = 99999.0
	for wsp in kit.wisps.size():
		kit.wisps.pop_back()
	var swing := func() -> float:
		var before: float = e.hp
		e.position = pl.position + Vector2(34, 0)
		_tick(w, {"attack": true, "attack_pressed": true}, 1)
		_tick(w, {}, 50)
		return before - e.hp
	pl.stats["crit"] = 0.0
	var rooted := 0.0
	for i in 4:
		rooted += float(swing.call())
	pl.stats["ranks"]["x_barrow"] = 0
	var plain := 0.0
	for i in 4:
		plain += float(swing.call())
	pl.stats["ranks"]["x_barrow"] = 2
	_check(is_equal_approx(kit.bonus_vs(e), 0.35) and rooted > plain * 1.2 and rooted < plain * 1.5,
			"Barrow Bind 2: the spade on a rooted foe hits about 35%% harder (%.0f vs %.0f)" % [rooted, plain])
	var opts: Dictionary = kit.melee_opts(e)
	_check(is_equal_approx(float(opts.get("extra_pct", 0.0)), 0.35), "and melee_opts hands the World the bonus to fold in")
	e.alive = false
	_tick(w, {}, 10)
	# Barrow Bind on the motes, into a boss-sized rooted body (96x128): measured from its edge.
	var big := _enemy(w, "skeleton", pl.position + Vector2(130, 0))
	big.size = Vector2(96, 128)
	big.max_hp = 99999.0
	big.hp = 99999.0
	for i in 2:
		pl.res = pl.res_max
		kit.call_wisp()
	kit.fire_window = 2.0
	var landed := []
	for i in 120:
		_tick(w, {})
		for m in kit._motes:
			if (m["hit_ids"] as Array).has(big.get_instance_id()) and not landed.has(m):
				landed.append(m)
		if landed.size() >= 2:
			break
	var all_bonus := landed.size() >= 1
	for m in landed:
		all_bonus = all_bonus and is_equal_approx(float(m.get("extra_pct", 0.0)), 0.35)
	_check(all_bonus, "Barrow Bind 2: a mote into a 96x128 rooted foe carries +35%% (%d landed)" % landed.size())
	big.alive = false
	kit.wisps.clear()
	_tick(w, {}, 60)
	# The decoy: a Stillmaw's Gulp takes a wisp instead of him.
	for i in 2:
		pl.res = pl.res_max
		_tick(w, {"special": true}, 1)
		_tick(w, {}, 8)
	var n0: int = kit.wisps.size()
	var mouth: Vector2 = pl.center() + Vector2(80, -20)
	var got: Dictionary = kit.decoy("gulp", mouth)
	_check(n0 == 2 and not got.is_empty() and got.get("kind", "") == "wisp" and kit.wisps.size() == 1 and kit.gulped == 1,
			"a Gulp takes a wisp before him (%d -> %d wisps, %s)" % [n0, kit.wisps.size(), str(got)])
	_check(kit.decoy("hit", mouth).is_empty() and kit.decoy("swallow", mouth).is_empty(), "only a Gulp takes one")
	kit.decoy("gulp", mouth)
	_check(kit.decoy("gulp", mouth).is_empty() and kit.wisps.is_empty(), "with no wisp left, the Gulp takes him")
	_tick(w, {}, 60)
	var base_kit: Object = load("res://scripts/kits/kit.gd").new()
	_check(base_kit.decoy("gulp", mouth).is_empty() and base_kit.bonus_vs(null) == 0.0, "the other kits give nothing (the base hooks)")
	await _free(w)


func _test_stampede_ice() -> void:
	## Stampede keeps its speed on ice (it's a quirk, not a constant).
	var lv := _flat(80, "I")
	var p := _bare(lv, Vector2(100, GROUND), "founder", "stampede")
	var top := 0.0
	var held := true
	for i in 360:
		p.pad = {"right": true}
		p.step(DT)
		if i > 240:
			top = maxf(top, p.velocity.x)
			held = held and p.stampeding and p.on_ice
	_check(held and is_equal_approx(top, p.STAMPEDE_SPEED), "a Stampede on ice reaches and holds 250 (%.1f)" % top)
	p.free()


# ---------------------------------------------------------------- the rig

func _test_rig() -> void:
	var w := await _world("witch", _flat())
	var rig: Node2D = w.rig
	var candle: Node2D = rig._joints["candle"]
	var seat_of := func() -> Vector2: return candle.to_global((rig._candle_base - rig.PIVOTS["candle"]) * 0.5)
	rig.gear_auto = false
	rig.set_gear({})
	var seat0: Vector2 = seat_of.call()
	var flame3 := 0.0
	rig.set_gear({"candle_tier": 3})
	flame3 = rig.flame_point().y
	rig.set_gear({"candle_tier": 4})
	_check(is_equal_approx(candle.scale.x, 1.20) and seat_of.call().distance_to(seat0) < 0.01, "a T4 candle is 1.20x, still seated")
	var flame4: float = rig.flame_point().y
	rig.set_gear({"candle_tier": 5})
	_check(is_equal_approx(candle.scale.x, 1.25) and seat_of.call().distance_to(seat0) < 0.01, "a T5 candle is 1.25x")
	_check(rig.flame_point().y < flame4 and flame4 < flame3, "and the flame rides higher each tier")
	rig.set_gear({"candle_tier": 9})
	_check(is_equal_approx(candle.scale.x, 1.25), "(a tier past 5 is shown as 5)")
	# weapon_visible: shown at rest; hidden when snuffed.
	await process_frame
	_check(rig.weapon_visible(), "the weapon shows at rest")
	w.player.alive = false
	_check(not rig.weapon_visible(), "and not while he's snuffed")
	w.player.alive = true
	await _free(w)
	w = await _world("runner", _flat())
	rig = w.rig
	_tick(w, {"attack": true, "attack_pressed": true}, 1)
	_settle(rig, 1)
	_check(not rig.weapon_visible(), "nor while a pose hides it (the runner's thrown knife)")
	await _free(w)
	# The cape trim: no pattern or no art, none; a pattern with art rides the
	# cape's joint in its colour, and the coat's tint never reaches it.
	w = await _world("knight", _flat())
	rig = w.rig
	rig.gear_auto = false
	rig.set_look({"trim": "band", "trim_color": "ember"})
	var art: bool = ResourceLoader.exists("res://art/heroes/knight/cape_trim_band.svg")
	_check(rig.trim_visible() == art, "a pattern shows only once its art exists (art %s)" % art)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	rig.set_look({"trim": "band", "trim_color": "ember"}, tex)
	var trim: Sprite2D = rig._trim
	_check(rig.trim_visible() and trim.get_parent() == rig._joints["cape"] and trim.modulate == Color("f07a2a"),
			"a trim with art rides the cape's joint in its colour (%s)" % trim.modulate)
	rig.set_gear({"coat_rarity": "rare"})
	_check(rig._sprites["cape"].modulate != Color.WHITE and trim.modulate == Color("f07a2a"), "the coat's tint stays off the trim")
	rig.set_look({"trim": "trim:band", "trim_color": "calling"}, tex)
	_check(trim.modulate == Color(str(Classes.info("knight")["color"])), "the calling's own colour by default (and ids may be namespaced)")
	_tick(w, {"right": true, "jump": true, "jump_pressed": true}, 1)
	_tick(w, {"right": true, "jump": true}, 20)
	_settle(rig, 12)
	var cape_j: Node2D = rig._joints["cape"]
	_check(absf(cape_j.rotation) > 0.05 and trim.global_rotation == cape_j.global_rotation, "and swings with the cape")
	rig.set_look({})
	_check(not rig.trim_visible(), "no pattern, no trim")
	# From the save: the rig reads the hero's look (the art for it pending: none shown).
	rig.gear_auto = true
	game.hero()["look"] = {"flame": "tallow", "trim": "scallop", "trim_color": "bone", "glow": ""}
	_settle(rig, 40)
	_check(str(rig.look.get("trim", "")) == "scallop", "the look is read from the hero (%s)" % str(rig.look))
	await _free(w)
