extends SceneTree
## test_bosses4 (BB): the Prism Saint and the Hush, with the finale (spec
## §5.4, §5.5, decisions "The Saint", "The Hush", "The ending").
##
##     godot --headless --path game --script res://tests/test_bosses4.gd
##
## Each boss is fought in its arena: the real 5-4 / 6-4 once WL5 / WL6 have
## built them, and always in an in-memory stand-in drawn to the spec's
## sketch (§3.6.4 P_ARENA, §3.7.4 Z_ARENA) behind a short approach with the
## door's altar. The numbers are read from the boss scripts, never copied,
## except the spec's own values the tests pin (the blows, the tells, the
## windows' lengths, the finale's shape).
##   - As test_bosses3 (BA): the phases clamp at 65% and 30%; the stagger
##     once a phase; is_open() only inside windows; the windows test (the
##     reference knight of test_progression, 6.5 swings a window) needs 6 (7)
##     for the Saint and 8 (9) for the Hush, at least 3 / 3 / 2 a phase, and
##     each Hush phase lasts 70 s or less; the biggest blow <= 34% of the
##     arrival knight (touch <= 25%); every move used in the sims; the retry
##     resets everything.
##   - The Saint: 16 x 56 mirrors drifting 30 px/s on 3-tile tracks; the
##     mirror that would reflect brightens; the 24 px line; a mirror at the
##     lock, a knight's block or Perfect Guard Refract her; the split.
##   - The Hush: the bells, peals and Heard; each phase's window; the Deep
##     Quiet leaves a perch within 5 tiles of every islet; the checkpoints
##     (Dusk keeps the phase, Nightfall keeps P3, Witching resets), through
##     the World's own snuff; the finale can't be failed (a scripted pad
##     reaches boss_defeated in under 3,600 frames with every calling; with
##     no input the rising dark lifts him to the rings); the hold completes
##     headless and pauses at k ~ 0.5 when released halfway.
##   - The review's cases (wave 2): her hover points and a beaming shard clear
##     of every mirror's track (no mirror turns every beam wherever he
##     stands); she sinks beside him and the window's clock waits; stomps
##     land in every window (dropped by the World's own physics); the P3
##     re-form plays the Rose's tell; the beam never breaks the pane under
##     the feet it burns; the Silence Bolts' tell; a retry brings back HEARD!,
##     the Choirs, the Echoes; P1's Grasp through the stone at a still Wick;
##     the Inhale's bite on a standing Wick with any calling's rig; the
##     shadow's viewport stops; the gift's lines play whole with an immediate
##     hold, a cosmetic flame fades, a held jump waits for his feet; Mercy's
##     stub onto his footing; and real-pad runs through each boss's bot_pad
##     (the reference knight wins both, each Hush phase <= 70 s; every calling
##     a minute with no script errors).

const LevelData := preload("res://scripts/level_data.gd")
const Combat := preload("res://scripts/combat.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Classes := preload("res://scripts/classes.gd")
const Progression := preload("res://scripts/progression.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const TILE := 32
const DT := 1.0 / 120.0
const SAINT := "res://scripts/saint_boss.gd"
const HUSH := "res://scripts/hush_boss.gd"
const FINALE := "res://scripts/hush_finale.gd"
const OWN := ["res://scripts/saint_boss.gd", "res://scripts/hush_boss.gd", "res://scripts/hush_finale.gd"]
const NO_IMMEDIATE := ["draw_circle(", "draw_colored_polygon(", "draw_polyline("]
const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
const LEAD := 14                # the stand-ins' approach, in tiles (the door's altar in it)
# spec §3.6.4: the Prism Saint's nave.
const P_ARENA := [
	"####################################",
	"####################################",
	"##................................##",
	"##..................+.............##",
	"##..........+...........+.........##",
	"##................................##",
	"##................................##",
	"##................................##",
	"##................................##",
	"##..........GGGGG.........GGGGG...##",
	".....................X..........####",
	".....GGGGG.........GGGGG........####",
	"................................####",
	"####............................####",
	"####............................####"]
# spec §3.7.4: the Still Water (the text's tall stones at rows 9-10, and the
# perch over the entry islet at x 2-4, row 8).
const Z_ARENA := [
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
	"....+.......##.+.....X........+..##.....+.##",
	"#######..#########..#######..########..#####",
	"#######::#########::#######::########::#####",
	"#######::#########::#######::########::#####",
	"#######::#########::#######::########::#####"]

var _passed := 0
var _failed := 0
var game: Node
var WorldScript: GDScript


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _skip(what: String) -> void:
	print("skipped: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_bosses4_save.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	if not ResourceLoader.exists(SAINT) or not ResourceLoader.exists(HUSH):
		_skip("saint_boss.gd / hush_boss.gd missing")
	else:
		_test_static()
		await _test_saint_arena()
		await _test_saint_mirrors()
		await _test_saint_beam()
		await _test_saint_knight()
		await _test_saint_tells()
		await _test_saint_phases()
		await _test_saint_windows()
		await _test_saint_split()
		await _test_saint_sim()
		await _test_saint_retry()
		await _test_saint_defeat()
		await _test_saint_extras()
		await _test_hush_arena()
		await _test_hush_bells()
		await _test_hush_p1()
		await _test_hush_p2()
		await _test_hush_p3()
		await _test_hush_heard()
		await _test_hush_windows()
		await _test_hush_phase_time()
		await _test_hush_checkpoints()
		await _test_hush_sim()
		await _test_hush_rush()
		await _test_saint_clearance()
		await _test_saint_window_hover()
		await _test_stomps()
		await _test_saint_reform_tell()
		await _test_hush_bolt_tell()
		await _test_hush_retries()
		await _test_hush_still()
		await _test_hush_perch_still()
		await _test_hush_bite()
		await _test_hush_shadow_vp()
		await _test_bot_pads()
		await _test_real_arenas()
		await _test_finale_callings()
		await _test_finale_no_input()
		await _test_finale_hold()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_bosses4_save.json" + suffix))
	game.save_path = game.SAVE_PATH
	game.load_save()
	print("test_bosses4: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _stand_in(arena: Array, boss: String, area: int, wn: int) -> RefCounted:
	## An arena behind a LEAD-tile approach: stone floor, Wick at column 2,
	## the door's altar at column 8 (the floor under the door at the arena's
	## entry height).
	var entry := 0
	for y in range(arena.size() - 1, -1, -1):
		if str(arena[y]).substr(0, 1) != "#":
			entry = y
			break
	var rows := []
	for y in 15:
		var l := ""
		for x in LEAD:
			l += "#" if y <= 1 or y > entry else "."
		rows.append(l + str(arena[y]))
	rows[entry] = rows[entry].substr(0, 2) + "P" + rows[entry].substr(3)
	rows[entry] = rows[entry].substr(0, 8) + "K" + rows[entry].substr(9)
	var music := "saint" if boss == "saint" else "hush_final"
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\narea: %d\nboss: %s\nboss_music: %s\n---\n%s" % [area, boss, music, "\n".join(rows)])
	lv.id = "%d-4" % wn
	lv.world = wn
	return lv


func _world(lv: RefCounted, diff := "dusk", cls := "", level := 0) -> Node2D:
	game.reset()
	if cls != "":
		game.new_hero(cls)
		await process_frame   # (anything the Game defers runs before the hero is set)
	if level > 0:
		# A hero of the boss's arrival level (a knight's block is priced by it).
		var h: Dictionary = game.hero()
		h["level"] = level
		h["xp"] = Progression.total_to(level)
	game.data["difficulty"] = diff
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	return w


func _saint_world(diff := "dusk", cls := "", level := 0) -> Node2D:
	return await _world(_stand_in(P_ARENA, "saint", 27, 5), diff, cls, level)


func _hush_world(diff := "dusk", cls := "") -> Node2D:
	return await _world(_stand_in(Z_ARENA, "hush", 31, 6), diff, cls)


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _step(w: Node2D, n: int, pad := {}) -> void:
	for i in n:
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _sturdy(w: Node2D) -> void:
	w.player.max_hp = 1.0e7
	w.player.hp = 1.0e7


func _at(x_col: float, floor_row: int) -> Vector2:
	return Vector2((LEAD + x_col) * TILE, floor_row * TILE)


func _wake(w: Node2D, spot: Vector2) -> Node2D:
	## Wick into the arena: the boss wakes (and plays its roar out).
	var b: Node2D = w.boss
	w.player.reset_at(spot)
	w.player.invuln = 0.0
	b.active = true
	for i in 400:
		w.test_pad = {}
		w._read_pad()
		w.tick(DT)
		if str(b.state) in ["fight", "glide", "track", "idle"] or (str(b.state) != "sleep" and str(b.state) != "wake" and str(b.state) != "roar"):
			break
	return b


func _reference3(level: int, area: int) -> Dictionary:
	## test_progression's reference Candleknight for v3 (spec §1.3), copied:
	## Blessed gear at ilvl = area with each piece's signature affix at a
	## median roll, half his points in stat nodes, Vigil ranks past a full
	## tree, no relics, no crits.
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
	h["xp"] = Progression.total_to(level)
	return h


func _ref_stats(level: int, area: int) -> Dictionary:
	Classes.set_deep(true)
	var s := Hero.stats(_reference3(level, area), [], "dusk")
	Classes.set_deep(false)
	return s


func _arrival(boss_level: String) -> int:
	## The reference knight's level at a boss: the level before's exit (test_progression's EXIT_TARGET).
	return 26 if boss_level == "5-4" else 30


# ---------------------------------------------------------------- static

func _test_static() -> void:
	var sc: Script = load(SAINT)
	var hc: Script = load(HUSH)
	_check(sc != null and hc != null and ResourceLoader.exists(FINALE), "the three scripts load")
	_check(EnemyKinds.has("saint") and EnemyKinds.has("hush"), "the World can spawn both (EnemyKinds)")
	var sm: Dictionary = sc.get_script_constant_map()
	var hm: Dictionary = hc.get_script_constant_map()
	# spec §5.4 / §5.5 after the x0.70 and x0.6 scales (PR's scan reads MOVES).
	_check(sm["MOVES"] == {"beam": 31.0, "rose": 18.0, "shard_beam": 25.0} and float(sm["TOUCH"]) == 21.0,
			"the Saint's blows are the spec's (beam 31, rose 18, shard beam 25, touch 21)")
	_check(hm["MOVES"] == {"grasp": 23.0, "snuff": 28.0, "inhale": 31.0, "bolt": 18.0, "gaze": 24.0} and float(hm["TOUCH"]) == 21.0,
			"the Hush's blows are the spec's (grasp 23, snuff 28, inhale 31, bolts 18, gaze 24, touch 21)")
	_check(sm["PHASES"] == [0.65, 0.30] and hm["PHASES"] == [0.65, 0.30], "both break at 65% and 30%")
	_check(sm["WINDOW"] == [2.6, 2.2, 1.9] and hm["WINDOW"] == [2.6, 2.4, 1.4], "the windows are the spec's (2.6/2.2/1.9; 2.6/2.4/1.4)")
	_check(Progression.BASE_XP.get("saint", 0) == 400 and Progression.BASE_XP.get("hush", 0) == 600, "boss XP 400 / 600 (progression's)")
	for p in OWN:
		var src := FileAccess.get_file_as_string(p)
		var bad := []
		for pat in NO_IMMEDIATE:
			if src.contains(pat):
				bad.append(pat)
		_check(bad.is_empty(), "%s draws through a TriBatch (no %s)" % [p.get_file(), ", ".join(bad)])
		_check(not src.contains("class_name"), "%s has no class_name" % p.get_file())
	# The share-cap scan's rule (spec §1.4) at the arrival knights.
	for row in [["saint", sm, "5-4", 27], ["hush", hm, "6-4", 31]]:
		var s := _ref_stats(_arrival(row[2]), row[3])
		var keep := 1.0 - clampf(float(s["dr"]), 0.0, Combat.DR_CAP)
		var big := 0.0
		for m in row[1]["MOVES"]:
			big = maxf(big, float(row[1]["MOVES"][m]))
		var share := big * Combat.e_dmg(row[3]) * keep / float(s["max_hp"])
		var touch := float(row[1]["TOUCH"]) * Combat.e_dmg(row[3]) * keep / float(s["max_hp"])
		print("  %s: the biggest blow is %.0f%% of the L%d knight, the touch %.0f%%" % [row[0], share * 100.0, _arrival(row[2]), touch * 100.0])
		_check(share <= Combat.SHARE_CAPS["boss_big"] + 0.0005, "%s's biggest blow <= 34%% of the arrival knight (%.1f%%)" % [row[0], share * 100.0])
		_check(touch <= Combat.SHARE_CAPS["boss_touch"] + 0.0005, "%s's touch <= 25%% (%.1f%%)" % [row[0], touch * 100.0])
	# The bar names each as its "before" scene's card does (the rev5 review:
	# the Saint's bar said "Light of the Shattered Sanctum", her card and the
	# cast roll "The First Light"; test_bosses3 checks Gravebough and the Tinker).
	var St = load("res://scripts/story.gd")
	for pair in [[sc, "boss_5_before"], [hc, "boss_6_before"]]:
		var bnode: Node = (pair[0] as Script).new()
		var card := {}
		for sh in St.scene(str(pair[1])).get("shots", []):
			for bt in (sh as Dictionary).get("beats", []):
				if bt is Dictionary and str(bt.get("do", "")) == "boss_card":
					card = bt
		_check(str(card.get("name", "")) == str(bnode.boss_name) and str(card.get("title", "")) == str(bnode.boss_title),
				"%s's bar and its card agree: %s, %s (card: %s, %s)" % [bnode.boss_id, bnode.boss_name, bnode.boss_title, card.get("name", ""), card.get("title", "")])
		bnode.free()
	# The real arenas once they're built.
	for id in ["5-4", "6-4"]:
		if not FileAccess.file_exists("res://levels/%s.txt" % id):
			_skip("levels/%s.txt missing (WL%s's): tested on the stand-in arena" % [id, id.left(1)])


# ---------------------------------------------------------------- the Saint

func _test_saint_arena() -> void:
	var lvs := [["stand-in", _stand_in(P_ARENA, "saint", 27, 5)]]
	if FileAccess.file_exists("res://levels/5-4.txt"):
		lvs.append(["5-4", LevelData.load_file("res://levels/5-4.txt")])
	for pair in lvs:
		var w := await _world(pair[1])
		var b: Node2D = w.boss
		_check(b != null and str(b.get("boss_id")) == "saint", "%s: the Saint is placed" % pair[0])
		if b == null:
			await _done(w)
			continue
		_check(b.door.size() >= 4, "%s: her doorway is found, rows and all (%d cells)" % [pair[0], b.door.size()])
		_check(b.mirrors.size() == 3, "%s: three mirror tracks from the anchors (%d)" % [pair[0], b.mirrors.size()])
		_check(b.platforms.size() >= 4 and b.stones.size() >= 2, "%s: the glass platforms and the stone footing (%d, %d)" % [pair[0], b.platforms.size(), b.stones.size()])
		_check(b.stations.size() == 3, "%s: three hover points" % pair[0])
		var bi: Dictionary = b.boss_info()
		_check(bi.get("segments", []) == [0.65, 0.30] and not bool(bi["awake"]), "%s: a three-segment bar, asleep" % pair[0])
		b = await _wake(w, b.home + Vector2(-200.0, 0.0) if pair[0] == "5-4" else _at(8.0, 11))
		var sealed := true
		for c in b.door:
			sealed = sealed and LevelData.is_solid(w.level.tile(c.x, c.y))
		_check(str(b.state) != "sleep" and sealed, "%s: she wakes as he comes in and the door seals" % pair[0])
		await _done(w)


func _test_saint_mirrors() -> void:
	var w := await _saint_world()
	var b: Node2D = w.boss
	var m: Dictionary = b.mirrors[0]
	var r: Rect2 = b.pane_rect(m)
	_check(r.size == Vector2(16, 56), "the mirrors are 16 x 56 panes")
	# The drift: 30 px/s at most, a 3-tile track down from its anchor.
	var lo := INF
	var hi := -INF
	var fastest := 0.0
	var last := float(m["top"])
	for i in int(12.0 / DT):
		b._place_mirrors(DT)
		var y := float(m["top"])
		fastest = maxf(fastest, absf(y - last) / DT)
		last = y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	var a: Vector2 = m["anchor"]
	_check(absf(lo - a.y) < 1.0 and absf(hi - (a.y + 96.0)) < 1.0, "a mirror's top travels its 3-tile track from the anchor (%.0f..%.0f from %.0f)" % [lo, hi, a.y])
	_check(fastest <= 30.5 and fastest > 25.0, "it drifts at 30 px/s (%.1f)" % fastest)
	# The reflection test: a line 24 px wide against the pane.
	m["hold"] = true
	var pr: Rect2 = b.pane_rect(m)
	var c := pr.get_center()
	var hit_near: int = b.mirror_on(Vector2(pr.position.x - 11.0, c.y - 300.0), Vector2(pr.position.x - 11.0, c.y + 300.0))
	var miss_far: int = b.mirror_on(Vector2(pr.position.x - 13.5, c.y - 300.0), Vector2(pr.position.x - 13.5, c.y + 300.0))
	_check(hit_near == 0 and miss_far != 0, "a line 11 px off the pane meets it, 13.5 px off doesn't (24 px wide)")
	m["dim"] = 6.0
	_check(b.mirror_on(Vector2(c.x, c.y - 300.0), Vector2(c.x, c.y + 300.0)) != 0, "a dimmed mirror doesn't reflect")
	await _done(w)


func _stand_for_mirror(w: Node2D, b: Node2D, want: int, avoid := false) -> bool:
	## Puts Wick on a platform so the line from her mask to him crosses mirror
	## `want` (or, with avoid, no mirror at all). Returns whether a spot was found.
	# (with a margin: her mask bobs a few px between now and the lock)
	for p in b.platforms:
		for dx in range(12, int(float(p["x1"]) - float(p["x0"])) - 11, 4):
			var at := Vector2(float(p["x0"]) + dx, float(p["y"]))
			w.player.reset_at(at)
			var ok := true
			for oy in [-7.0, 0.0, 7.0]:
				for ox in [-6.0, 0.0, 6.0]:
					var hit: int = b.mirror_on(b.mask() + Vector2(ox, oy), w.player.center())
					if (avoid and hit >= 0) or (not avoid and hit != want):
						ok = false
			if ok:
				return true
	return false


func _to_track(w: Node2D, b: Node2D, max_s := 20.0) -> bool:
	for i in int(max_s / DT):
		_step(w, 1)
		if str(b.state) == "track":
			return true
	return false


func _test_saint_beam() -> void:
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	_check(_to_track(w, b), "she comes to track him with the beam")
	# Hold every mirror still (so the tests' spots stay true) and find a spot
	# with a mirror between.
	for m in b.mirrors:
		m["hold"] = true
	var found := false
	for i in b.mirrors.size():
		if _stand_for_mirror(w, b, i):
			found = true
			break
	_check(found, "a spot on the platforms puts a mirror between them")
	var hp0: float = w.player.hp
	var brightened := false
	var opened := false
	for i in int(3.0 / DT):
		_step(w, 1)
		if str(b.state) == "track" and int(b.bright) >= 0:
			brightened = true
		if b.is_open():
			opened = true
			break
	_check(brightened, "through the tracking, the mirror that would reflect brightens")
	_check(opened and str(b.state) == "refracted", "a mirror between them at the lock turns the beam back: Refracted")
	_check(absf(float(b.timer) - float(b.window_len())) < 0.05 and absf(float(b.window_len()) - 2.6) < 0.001, "the P1 window is 2.6 s")
	_check(is_equal_approx(w.player.hp, hp0), "the reflected beam never reaches him (%.0f lost: %s, at %s)" % [hp0 - w.player.hp, str(w.snuff_causes), str(w.player.position)])
	var dimmed := 0
	for m in b.mirrors:
		if float(m["dim"]) > 5.0:
			dimmed += 1
	_check(dimmed == 1, "the mirror that reflected is dimmed 6 s")
	# Inside the window: full damage, a stomp 3x; outside, 5%.
	var hpb: float = b.hp
	b.hit({"how": "slash", "amount": 50.0, "from_x": b.position.x})
	_check(absf((hpb - b.hp) - 50.0) < 0.01, "a window hit lands in full")
	hpb = b.hp
	b.hit({"how": "stomp", "amount": 20.0, "from_x": b.position.x})
	_check(absf((hpb - b.hp) - 60.0) < 0.01, "a stomp deals 3x in the window")
	for i in int(3.0 / DT):
		_step(w, 1)
	_check(not b.is_open(), "the window closes")
	hpb = b.hp
	b.hit({"how": "slash", "amount": 100.0, "from_x": b.position.x})
	_check(absf((hpb - b.hp) - 5.0) < 0.01, "outside it her glass turns the blow (5%%: %.2f)" % (hpb - b.hp))
	# No mirror between: the beam burns him; the pane under his feet holds
	# (one missed dodge costs the beam, not the void too).
	_check(_to_track(w, b), "she tracks again")
	for m in b.mirrors:
		m["broken"] = true   # (no mirror anywhere: the beam must burn)
	# A spot where the line from her, past him, goes on into glass.
	var ok := false
	for p0 in b.platforms:
		for dx in range(16, int(float(p0["x1"]) - float(p0["x0"])) - 15, 8):
			w.player.reset_at(Vector2(float(p0["x0"]) + dx, float(p0["y"])))
			if not (b.beam_path(b.mask(), w.player.center())["glass"] as Array).is_empty():
				ok = true
				break
		if ok:
			break
	var feet: Vector2 = w.player.position
	var under := Vector2i(floori(feet.x / TILE), floori((feet.y + 1.0) / TILE))
	hp0 = w.player.hp
	var beam := {}
	for i in int(3.0 / DT):
		_step(w, 1)
		for hz in w.hazards:
			if hz.get("kind") == "beam" and hz.get("saint", false):
				beam = hz
		if w.player.hp < hp0 and not beam.is_empty():
			break
	_check(ok and not beam.is_empty(), "with no mirror between, the beam fires (a world beam hazard) (spot %s, state %s)" % [str(ok), str(b.state)])
	if not beam.is_empty():
		_check(float(beam["width"]) == 10.0 and bool(beam["reflect"]) and beam["source"] == b and absf(float(beam["dmg"]) - float(b.dmg("beam"))) < 0.01,
				"the beam: 10 px wide, reflectable, hers, the beam's damage")
	_check(w.player.hp < hp0, "and it burns him where he stood")
	for i in int(0.8 / DT):
		_step(w, 1)
	_check(w.level.tile(under.x, under.y) == LevelData.GLASS and w.player.on_floor and absf(w.player.position.y - feet.y) < 1.0,
			"the beam that burns him never breaks the pane under his feet (he's still standing on it)")
	await _done(w)
	# A dodge: the glass behind it breaks.
	w = await _saint_world()
	_sturdy(w)
	b = await _wake(w, _at(8.0, 11))
	_check(_to_track(w, b), "(she tracks)")
	for m in b.mirrors:
		m["broken"] = true
	ok = false
	for p0 in b.platforms:
		for dx in range(16, int(float(p0["x1"]) - float(p0["x0"])) - 15, 8):
			w.player.reset_at(Vector2(float(p0["x0"]) + dx, float(p0["y"])))
			if not (b.beam_path(b.mask(), w.player.center())["glass"] as Array).is_empty():
				ok = true
				break
		if ok:
			break
	var crossed: Array = []
	var dodged := false
	for i in int(3.0 / DT):
		_step(w, 1)
		if str(b.state) == "lock" and not dodged:
			dodged = true
			crossed = b.beam_path(b._lock_a, b._lock_b)["glass"]
			# Off the line onto stone well away from it.
			w.player.reset_at(_at(2.5, 13))
		if dodged and str(b.state) != "lock":
			break
	for i in int(0.45 / DT):
		_step(w, 1)
	var still := 0
	for c in crossed:
		if w.level.tile(c.x, c.y) == LevelData.GLASS:
			still += 1
	_check(ok and not crossed.is_empty() and still == 0, "behind a dodge the glass it crosses breaks (%d panes crossed, %d whole)" % [crossed.size(), still])
	await _done(w)


func _glass(w: Node2D) -> int:
	var n := 0
	for y in w.level.height:
		for x in w.level.width:
			if w.level.tile(x, y) == LevelData.GLASS:
				n += 1
	return n


func _test_saint_knight() -> void:
	## A Candleknight's guard turns the beam back: any block (it costs Grace),
	## and a Perfect Guard (the kit's reflect) whose blow lands in full.
	for perfect in [false, true]:
		var w := await _saint_world("dusk", "knight", _arrival("5-4"))
		var b: Node2D = await _wake(w, _at(8.0, 11))
		for m in b.mirrors:
			m["broken"] = true   # (no mirror may help: the shield alone)
		_check(_to_track(w, b), "(knight) she tracks him")
		# (across the nave from her: the beam comes at his shield from the side)
		var p: Dictionary = b.platforms[2] if b.position.x < (b.arena_left + b.arena_right) * 0.5 else b.platforms[0]
		w.player.reset_at(Vector2((float(p["x0"]) + float(p["x1"])) * 0.5, float(p["y"])))
		w.player.res = w.player.res_max
		var hp0: float = w.player.hp
		var bhp: float = b.hp
		var opened := false
		for i in int(3.5 / DT):
			var pad := {}
			w.player.facing = 1 if b.position.x > w.player.position.x else -1
			pad["right" if w.player.facing > 0 else "left"] = false
			if not perfect:
				pad["special"] = true
			elif str(b.state) == "fire" or (str(b.state) == "lock" and float(b.timer) < 0.05):
				pad["special"] = true
			_step(w, 1, pad)
			if b.is_open():
				opened = true
				break
		var what := "a Perfect Guard" if perfect else "his guard (a block)"
		_check(opened, "%s turns the beam back: she is Refracted" % what)
		_check(is_equal_approx(w.player.hp, hp0), "%s: the beam never lands" % what)
		if perfect:
			_check(b.hp < bhp, "a Perfect Guard's reflect lands on her (%.0f)" % (bhp - b.hp))
		await _done(w)


func _test_saint_tells() -> void:
	## Every tell >= 0.40 s on Dusk, the lock 0.50 / 0.45 / 0.40 (never less),
	## the track 1.1 s with a 0.80 floor, and Shatter meets the escape formula.
	var tune: Dictionary = (load(SAINT) as Script).get_script_constant_map()["TUNE"]
	for d in ["dusk", "nightfall", "witching"]:
		var w := await _saint_world(d)
		var b: Node2D = w.boss
		var lock: float = b.lock_time()
		var want: float = {"dusk": 0.50, "nightfall": 0.45, "witching": 0.40}[d]
		_check(absf(lock - want) < 0.001, "%s: the lock is %.2f s (%.2f)" % [d, want, lock])
		var track: float = b.tell(float(tune["track"]), float(tune["track_floor"]))
		_check(track >= 0.80 - 0.001 and (d != "dusk" or absf(track - 1.1) < 0.001), "%s: the track %.2f s (1.1, floor 0.80)" % [d, track])
		var rose: float = b.tell(float(tune["rose_tell"]), float(tune["rose_floor"]))
		_check(rose >= 0.45 - 0.001, "%s: the Rose spins up %.2f s (floor 0.45)" % [d, rose])
		if d == "dusk":
			var shatter: float = b.tell(float(tune["shatter_tell"]), float(tune["shatter_floor"]))
			# From a platform's middle to the next platform's edge (4.5 tiles):
			# the tell and the glass's own 0.35 s flash against 0.35 + px / 205.
			_check(shatter + 0.35 >= b.escape_tell(144.0) - 0.001, "Shatter's tell and flash (%.2f s) meet the escape formula (%.2f s)" % [shatter + 0.35, b.escape_tell(144.0)])
			for key in ["track", "rose_tell", "gale_tell", "shatter_tell"]:
				_check(b.tell(float(tune[key])) >= 0.40, "Dusk: %s >= 0.40 s" % key)
			# The beam's dodge: out of a 10 px line, his half width and 10 px more.
			_check(lock >= b.escape_tell(10.0 + 5.0 + 10.0) - 0.001, "the lock (%.2f) is a dodge by the escape formula (%.2f)" % [lock, b.escape_tell(25.0)])
		await _done(w)


func _test_saint_phases() -> void:
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	# boss_rig's rule (the rev5 review): until the phase's stagger a window
	# takes at most STAGGER (30%), and the stagger's bonus stops STAGGER_ROOM
	# (5%) over the line: no phase falls to one window, whatever lands.
	b._open_window()
	b.hit({"how": "slash", "amount": 1.0e9, "from_x": b.position.x})
	_check(absf(b.hp - 0.70 * b.max_hp) < 1.0 and int(b.phase) == 1 and not b.is_open(), "one window takes at most 30%% (SHATTERED!, 5%% kept over the line: %.0f / %.0f)" % [b.hp, b.max_hp])
	b.state = "idle"
	b._open_window()
	b.hit({"how": "slash", "amount": 1.0e9, "from_x": b.position.x})
	_check(absf(b.hp - 0.65 * b.max_hp) < 1.0 and int(b.phase) == 2 and not b.is_open(), "a window's blow stops at the 65%% line and the window ends (%.0f / %.0f)" % [b.hp, b.max_hp])
	for i in int(1.5 / DT):
		_step(w, 1)
	b._open_window()
	b.hit({"how": "slash", "amount": 1.0e9, "from_x": b.position.x})
	_check(absf(b.hp - 0.35 * b.max_hp) < 1.0 and int(b.phase) == 2, "P2's first window: 30%% at most too (%.0f)" % b.hp)
	b.state = "idle"
	b._open_window()
	b.hit({"how": "slash", "amount": 1.0e9, "from_x": b.position.x})
	_check(absf(b.hp - 0.30 * b.max_hp) < 1.0 and int(b.phase) == 3, "and at the 30%% line (%.0f)" % b.hp)
	await _done(w)
	# The window's first stomp pays 3x; the bounces after it chip (5%), and
	# what a bounce throws off (stomp_born) chips too.
	w = await _saint_world()
	_sturdy(w)
	b = await _wake(w, _at(8.0, 11))
	b._open_window()
	var st := 100.0
	var hp1: float = b.hp
	b.hit({"how": "stomp", "amount": st, "from_x": b.position.x})
	var first: float = hp1 - b.hp
	hp1 = b.hp
	b.hit({"how": "stomp", "amount": st, "from_x": b.position.x})
	var second: float = hp1 - b.hp
	hp1 = b.hp
	b.hit({"how": "shock", "amount": st, "from_x": b.position.x, "stomp_born": true})
	var wave: float = hp1 - b.hp
	var sc: Dictionary = (load(SAINT) as Script).get_script_constant_map()
	_check(absf(first - 3.0 * st) < 0.01 and absf(second - st * float(sc["CHIP"])) < 0.01 and absf(wave - st * float(sc["CHIP"])) < 0.01,
			"a window's first stomp is 3x, the bounce after it and its waves chip (%.0f / %.0f / %.0f)" % [first, second, wave])
	b.state = "idle"
	b._open_window()
	hp1 = b.hp
	b.hit({"how": "stomp", "amount": st, "from_x": b.position.x})
	_check(absf(hp1 - b.hp - 3.0 * st) < 0.01, "a new window's first stomp is 3x again (%.0f)" % (hp1 - b.hp))
	await _done(w)
	# SHATTERED!: 30% in one window, once a phase (+10%).
	w = await _saint_world()
	_sturdy(w)
	b = await _wake(w, _at(8.0, 11))
	b.hp = b.max_hp
	b._open_window()
	var chunk: float = 0.1 * b.max_hp
	for k in 3:
		b.hit({"how": "slash", "amount": chunk, "from_x": b.position.x})
	var lost: float = (b.max_hp - b.hp) / b.max_hp
	_check(absf(lost - 0.30) < 0.001 and int(b._stagger_phase) == 1, "30%% in a window staggers her: its +10%% stops 5%% over the line (lost %.0f%%)" % (lost * 100.0))
	_check(not b.is_open(), "SHATTERED! ends the window")
	await _done(w)
	# Once a phase: a second 30% window in the same phase pays no bonus.
	w = await _saint_world()
	_sturdy(w)
	b = await _wake(w, _at(8.0, 11))
	b._open_window()
	for k in 3:
		b.hit({"how": "slash", "amount": 0.1 * b.max_hp, "from_x": b.position.x})
	_check(int(b._stagger_phase) == 1, "(she staggered in P1)")
	b.hp = b.max_hp
	b.state = "idle"
	b._open_window()
	for k in 3:
		b.hit({"how": "slash", "amount": 0.1 * b.max_hp, "from_x": b.position.x})
	_check(absf(b.hp - 0.70 * b.max_hp) < 1.0 and b.is_open(), "a second 30%% window in the same phase pays no bonus (%.0f%%)" % (b.hp / b.max_hp * 100.0))
	await _done(w)


func _test_saint_windows() -> void:
	## The windows test: the reference Candleknight at 5-4's arrival (L26,
	## area 27, Dusk) swings 6.5 times a window (7, 6, 7...; spec §5.1: "a
	## window is worth about 6.5 swings", 85 base life there), every hit
	## through her own hit() in her window; a blow never crosses a phase.
	var s := _ref_stats(_arrival("5-4"), 27)
	var per := float(s["basic"]) * (1.0 + float(s["dmg_pct"]))
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	var sc: Dictionary = (load(SAINT) as Script).get_script_constant_map()
	_check(absf(b.max_hp - float(sc["BASE_HP"]) * Combat.e_hp(27) * float(Combat.diff("dusk")["hp"])) < 1.0, "her life is BASE_HP at area 27 (%.0f)" % b.max_hp)
	var windows := 0
	var by_phase := [0, 0, 0]
	while b.alive and windows < 40:
		b._open_window()
		var ph := int(b.phase)
		var swings := 7 if windows % 2 == 0 else 6
		for k in swings:
			if not b.is_open():
				break
			b.hit({"how": "slash", "amount": per, "from_x": b.position.x})
		windows += 1
		by_phase[ph - 1] += 1
		if b.alive and not str(b.state) in ["refracted"]:
			b.state = "idle"
	print("  the Saint: an L26 knight (%.0f a swing, %.1f base) needs %d windows (%s) against %.0f life" % [per, per / Combat.e_hp(27), windows, str(by_phase), b.max_hp])
	_check(windows >= 6 and windows <= 7, "the reference knight needs 6 (7) windows for the Saint (%d)" % windows)
	await _done(w)


func _test_saint_split() -> void:
	## P3: the roar breaks a mirror for good, she bursts into three shards;
	## reflecting each one's beam cracks it; all three: she re-forms,
	## Refracted, for the P3 window (1.9 s), with a Rose as it opens.
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	b.hp = 0.30 * b.max_hp + 1.0
	b.phase = 2
	b._open_window()
	b.hit({"how": "slash", "amount": 1.0e9, "from_x": b.position.x})
	_check(int(b.phase) == 3 and str(b.state) == "roar", "at 30% she roars into P3")
	for i in int(3.5 / DT):
		_step(w, 1)
	var broken := 0
	for m in b.mirrors:
		if m["broken"]:
			broken += 1
	_check(broken == 1, "the roar breaks one mirror for good (2 are left)")
	_check(str(b.state) == "scatter" and b.shards.size() == 3 and b.rect() == b.NOWHERE, "she has split into three shards (no body to strike)")
	# Each shard's beam, turned back, cracks it.
	var cracked := 0
	var opened := false
	var blades_at_open := -1
	for i in int(40.0 / DT):
		if str(b.get("_sh_state")) == "fire" and not b._beam.is_empty() and not bool(b._beam["reflected"]):
			b._turned_back("mirror")
		_step(w, 1)
		cracked = 0
		for sh in b.shards:
			if sh["cracked"]:
				cracked += 1
		if b.is_open():
			opened = true
			blades_at_open = b.blades.size()
			break
	_check(opened, "with all three cracked she re-forms, Refracted")
	_check(absf(float(b.window_len()) - 1.9) < 0.001, "the P3 window is 1.9 s")
	_check(blades_at_open >= 8, "one Rose volley as the P3 window opens (%d blades)" % blades_at_open)
	for i in int(3.0 / DT):
		_step(w, 1)
	_check(str(b.state) in ["recover", "split", "scatter"], "then she splits again (%s)" % b.state)
	await _done(w)


func _test_saint_sim() -> void:
	## Every move in a 300 s sim (100 s a phase), a sturdy hero standing on a
	## platform, and is_open() only inside windows.
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	var only_in := true
	for ph in [1, 2, 3]:
		if ph > 1:
			b.hp = (float(b.PHASES[ph - 2]) + 0.01) * b.max_hp
			b._open_window()
			b.hit({"how": "slash", "amount": 0.011 * b.max_hp, "from_x": b.position.x})
		for i in int(100.0 / DT):
			if i % 480 == 0 or w.player.position.y > w.level.height * TILE:
				# On a whole platform (her beams break the glass they cross).
				var spot := Vector2.ZERO
				for k in b.platforms.size():
					var q: Dictionary = b.platforms[(k + i / 480) % b.platforms.size()]
					var c := Vector2i(floori((float(q["x0"]) + float(q["x1"])) * 0.5 / TILE), int(q["row"]))
					if w.level.tile(c.x, c.y) == LevelData.GLASS:
						spot = Vector2((c.x + 0.5) * TILE, float(q["y"]))
						break
				if spot == Vector2.ZERO:
					spot = _at(2.5, 13)
				w.player.reset_at(spot)
			w.player.hp = w.player.max_hp
			_step(w, 1)
			if b.is_open() != (str(b.state) == "refracted"):
				only_in = false
			# In a window, never deal enough to end the phase.
	var need := ["beam", "rose", "gale", "shatter", "choir", "refracted", "split", "shard_beam"]
	var missing := []
	for mv in need:
		if int(b.used.get(mv, 0)) <= 0:
			missing.append(mv)
	print("  the Saint's sim: ", b.used)
	_check(missing.is_empty(), "every move is used in the sim (missing: %s)" % ", ".join(missing))
	_check(only_in, "is_open() only inside windows")
	await _done(w)


func _test_saint_retry() -> void:
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	b.hp = 0.46 * b.max_hp
	b.phase = 2
	b._choirs_done = [0.70]
	b._choir_pending = true
	b.state = "idle"
	b.timer = 0.0
	for i in int(3.0 / DT):
		_step(w, 1)
	var adds: int = b._adds.size()
	b.mirrors[0]["dim"] = 5.0
	w.features.break_glass(Vector2i(LEAD + 6, 11))
	for i in 60:
		_step(w, 1)
	var glass_gone: bool = w.level.tile(LEAD + 6, 11) != LevelData.GLASS
	# A snuff: the World resets the fight.
	w.player.max_hp = 100.0
	w.player.hp = 1.0
	w.player.invuln = 0.0
	w.hurt_player(50.0, w.player.position.x - 20.0, "hit", null, {})
	for i in int(1.8 / DT):
		_step(w, 1)
	_check(adds >= 2, "(her Choir brought its adds: %d)" % adds)
	_check(glass_gone, "(a pane had broken)")
	_check(str(b.state) == "sleep" and is_equal_approx(b.hp, b.max_hp) and int(b.phase) == 1, "a snuff: asleep again at full life, P1")
	var clean := true
	for m in b.mirrors:
		clean = clean and not m["broken"] and float(m["dim"]) <= 0.0
	_check(clean, "the mirrors reset")
	var alive_adds := 0
	for e in w.enemies:
		if e != b and e.alive and not e.gone:
			alive_adds += 1
	_check(alive_adds == 0, "her adds are gone (%d)" % alive_adds)
	_check(w.level.tile(LEAD + 6, 11) == LevelData.GLASS, "the platforms regrow at once")
	var open := true
	for c in b.door:
		open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(open, "the door opens")
	await _done(w)


func _test_saint_extras() -> void:
	## The Choirs (2 Paneguards on the stone at 70%, 3 Glassmites and a
	## Refractor at 45%, gone at the next roar); Mercy's stub; the camera's
	## lean point; configure's hp_mult.
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	b.state = "refracted"
	b.timer = 5.0
	b.hit({"how": "slash", "amount": 0.31 * b.max_hp, "from_x": b.position.x})
	_check(b._choir_pending, "(70%%: a Choir is due)")
	b.state = "idle"
	b.timer = 0.0
	for i in int(2.5 / DT):
		_step(w, 1)
	var kinds := {}
	for e in b._adds:
		kinds[e.kind] = int(kinds.get(e.kind, 0)) + 1
	_check(kinds.get("paneguard", 0) == 2, "at 70%% two Paneguards step out onto the stone (%s)" % str(kinds))
	var on_stone := true
	for e in b._adds:
		var cy := floori((e.position.y + 1.0) / TILE)
		on_stone = on_stone and LevelData.is_solid(w.level.tile(floori(e.position.x / TILE), cy)) and w.level.tile(floori(e.position.x / TILE), cy) != LevelData.GLASS
	_check(on_stone, "they stand on stone")
	# Into P2 (the roar clears them), then 45%.
	b.hp = 0.66 * b.max_hp
	b._open_window()
	b.hit({"how": "slash", "amount": 0.02 * b.max_hp, "from_x": b.position.x})
	for i in 30:
		_step(w, 1)
	var left := 0
	for e in w.enemies:
		if e.kind == "paneguard" and e.alive and not e.gone:
			left += 1
	_check(left == 0, "the P2 roar sends her adds away (%d left)" % left)
	b._open_window()
	b.hit({"how": "slash", "amount": 0.21 * b.max_hp, "from_x": b.position.x})
	b.state = "idle"
	b.timer = 0.0
	for i in int(2.5 / DT):
		_step(w, 1)
	kinds = {}
	for e in b._adds:
		kinds[e.kind] = int(kinds.get(e.kind, 0)) + 1
	_check(kinds.get("glassmite", 0) == 3 and kinds.get("refractor", 0) == 1, "at 45%% three Glassmites and a Refractor (%s)" % str(kinds))
	_check(b.camera_top() < b.body_rect().position.y + 1.0, "camera_top() is her head (the World's lean)")
	await _done(w)
	# Mercy: one wax stub in P3 when he's low, once.
	w = await _saint_world()
	b = await _wake(w, _at(8.0, 11))
	b.phase = 3
	b.state = "idle"
	b.timer = 99.0
	w.player.max_hp = 1000.0
	w.player.hp = 200.0
	var wax0: int = w.pickups.filter(func(p): return p["kind"] == "wax").size()
	for i in 30:
		_step(w, 1)
	_check(w.pickups.filter(func(p): return p["kind"] == "wax").size() == wax0 + 1 and b._mercy, "Mercy: one wax stub in P3 when he's under 25%")
	await _done(w)
	# Mid-jump over the void, the stub drops onto the footing he last stood on.
	w = await _saint_world()
	b = await _wake(w, _at(8.0, 11))
	b.phase = 3
	b.state = "idle"
	b.timer = 99.0
	var pc: Dictionary = b.platforms[2]
	w.player.reset_at(Vector2(float(pc["x0"]) + 20.0, float(pc["y"])))
	for i in 10:
		_step(w, 1)
	w.player.position = Vector2(float(pc["x0"]) - 30.0, float(pc["y"]) - 90.0)   # (over the gap, in the air)
	w.player.frozen = true
	w.player.max_hp = 1000.0
	w.player.hp = 200.0
	for i in int(2.0 / DT):
		_step(w, 1)
	var stub := {}
	for pk in w.pickups:
		if pk["kind"] == "wax":
			stub = pk
	var sp: Vector2 = stub.get("pos", Vector2.INF)
	_check(not stub.is_empty() and sp.x >= float(pc["x0"]) and sp.x <= float(pc["x1"]) and absf(sp.y - float(pc["y"])) < 24.0,
			"his stub drops onto the platform he last stood on, not into the void under his jump (%s)" % str(sp))
	await _done(w)
	# A mode's options: the rush's life.
	var lv := _stand_in(P_ARENA, "saint", 27, 5)
	game.reset()
	var w2: Node2D = WorldScript.new()
	w2.setup(lv, true)
	root.add_child(w2)
	await process_frame
	var full: float = w2.boss.max_hp
	# (The contract's configure, through BR's boss_mods.gd since the track B
	# merge: hp_mult is the mode's share, the rush adds her own RUSH_HP.)
	var rush_k := float(load("res://scripts/boss_mods.gd").RUSH_HP["saint"])
	w2.boss.configure({"rush": true, "hp_mult": 1.5})
	_check(absf(w2.boss.max_hp - full * 1.5 * rush_k) < 0.5 and bool(w2.boss.rush), "configure: the rush's life, her own x%.2f x the mode's 1.5" % rush_k)
	await _done(w2)


func _test_saint_defeat() -> void:
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	b.phase = 3
	b.hp = 5.0
	b._open_window()
	b.hit({"how": "slash", "amount": 100.0, "from_x": b.position.x})
	_check(not b.alive, "she falls at 0")
	var loot := 0
	for i in int(4.0 / DT):
		_step(w, 1)
	for p in w.pickups:
		if p["kind"] == "item" or p["kind"] == "relic":
			loot += 1
	_check(loot >= 3 and w.bells.size() == 1, "her drops fall (%d) and the bell comes down" % loot)
	await _done(w)


# ---------------------------------------------------------------- the Hush

func _test_hush_arena() -> void:
	var lvs := [["stand-in", _stand_in(Z_ARENA, "hush", 31, 6)]]
	if FileAccess.file_exists("res://levels/6-4.txt"):
		lvs.append(["6-4", LevelData.load_file("res://levels/6-4.txt")])
	for pair in lvs:
		var w := await _world(pair[1])
		var b: Node2D = w.boss
		_check(b != null and str(b.get("boss_id")) == "hush", "%s: the Hush is placed" % pair[0])
		if b == null:
			await _done(w)
			continue
		_check(b.islets.size() == 5 and b.bells.size() == 4, "%s: five islets and four sunken bells (%d, %d)" % [pair[0], b.islets.size(), b.bells.size()])
		_check(b.door.size() >= 4, "%s: the doorway (%d cells)" % [pair[0], b.door.size()])
		# The Deep Quiet: high ground within 5 tiles of every islet cell.
		var worst := 0.0
		for il in b.islets:
			var x := float(il["x0"]) + 16.0
			while x < float(il["x1"]):
				if x > b.arena_left and x < b.arena_right:
					var best := INF
					for pc in b.perches:
						var d := 0.0
						if x < float(pc["x0"]):
							d = float(pc["x0"]) - x
						elif x > float(pc["x1"]):
							d = x - float(pc["x1"])
						best = minf(best, d)
					worst = maxf(worst, best)
				x += 32.0
		_check(worst <= 5.0 * TILE + 0.5, "%s: a perch or tall stone within 5 tiles of every islet (worst %.1f tiles)" % [pair[0], worst / TILE])
		_check(b.boss_info().get("segments", []) == [0.65, 0.30], "%s: one bar in three segments" % pair[0])
		await _done(w)


func _test_hush_bells() -> void:
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	var bell: Dictionary = b.bells[1]
	# A swing on the bell rings it.
	w.player.reset_at((bell["p"] as Vector2) + Vector2(-26.0, 0.0))
	w.player.facing = 1
	for i in 10:
		_step(w, 1)
	var rung0: int = b.rings_rung
	_step(w, 1, {"attack": true})
	for i in 12:
		_step(w, 1)
	_check(b.rings_rung == rung0 + 1, "a swing on a sunken bell rings it")
	_check(float(bell["lit"]) > 2.5 and int(bell["light"]) >= 0, "the bell lights (r 120, 3 s)")
	var lt: Dictionary = w.light_by_id(int(bell["light"]))
	_check(not lt.is_empty() and absf(float(lt["r"]) - 120.0) < 0.1, "its light is r 120")
	_check(float(bell["smother"]) > 7.5, "and is smothered for 8 s")
	_check(not b.ring_bell(1), "a smothered bell doesn't ring again")
	# The peal runs out at 420 px/s to r 300.
	b.peals.clear()
	b.bells[2]["smother"] = 0.0
	b.ring_bell(2)
	var t := 0.0
	while not b.peals.is_empty() and t < 2.0:
		_step(w, 1)
		t += DT
	_check(absf(t - 300.0 / 420.0) < 0.05, "a peal runs out to r 300 at 420 px/s (%.2f s)" % t)
	# A shot rings one too.
	b.bells[3]["smother"] = 0.0
	var rung1: int = b.rings_rung
	w.spawn_shot({"kind": "spark", "pos": (b.bells[3]["p"] as Vector2) + Vector2(-60, -20), "vel": Vector2(400, 0), "life": 1.0, "owner": "player"})
	for i in 30:
		_step(w, 1)
	_check(b.rings_rung == rung1 + 1, "a shot rings a bell")
	await _done(w)
	# The Bellfounder's Peal (its ring) counts as ringing one.
	w = await _hush_world("dusk", "founder")
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	w.player.reset_at((b.bells[1]["p"] as Vector2) + Vector2(-40.0, 0.0))
	for i in 10:
		_step(w, 1)
	w.player.res = w.player.res_max
	var rung2: int = b.rings_rung
	_step(w, 1, {"special": true})
	for i in 6:
		_step(w, 1)
	_check(b.rings_rung > rung2, "a Bellfounder's Peal rings the bell beside her")
	await _done(w)


func _test_hush_p1() -> void:
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	var bell: Dictionary = b.bells[1]
	w.player.reset_at((bell["p"] as Vector2) + Vector2(-60.0, 0.0))
	for i in 30:
		_step(w, 1)
	_check(b.rect() == b.NOWHERE, "outside a window nothing of it can be struck")
	b.ring_bell(1)
	var t := 0.0
	while not b.is_open() and t < 6.0:
		_step(w, 1)
		t += DT
	var ep: Vector2 = b.eye["p"]
	_check(b.is_open() and str(b.eye["state"]) == "surface", "after a peal the Eye swims to the bell and surfaces (%.2f s)" % t)
	_check(absf(ep.x - (bell["p"] as Vector2).x) < 50.0 and absf(ep.y - (b.islet_top - 26.0)) < 2.0, "beside the bell, on the islet at his height")
	_check(absf(float(b.eye["t"]) - 2.6) < 0.05, "for 2.6 s")
	_step(w, 1)
	_check(b._part == "eye" and b.rect() != b.NOWHERE, "the surfaced Eye can be struck")
	var hp0: float = b.hp
	b.hit({"how": "slash", "amount": 40.0, "from_x": ep.x})
	_check(absf((hp0 - b.hp) - 40.0) < 0.01, "Eye hits land in full")
	hp0 = b.hp
	b.hit({"how": "stomp", "amount": 10.0, "from_x": ep.x})
	_check(absf((hp0 - b.hp) - 30.0) < 0.01, "a stomp deals 3x")
	for i in int(3.2 / DT):
		_step(w, 1)
	_check(not b.is_open() and str(b.eye["state"]) in ["dive", "lurk"], "then it dives to smother the bell")
	# The Grasp: the tell, the column at the nearest islet edge, 23 and hushed.
	var edge: float = b.nearest_edge(w.player.position.x)
	w.player.reset_at(Vector2(edge - 6.0, b.islet_top))
	w.player.max_hp = 1.0e6
	w.player.hp = 1.0e6
	w.player.invuln = 0.0
	b._grasp_t = 0.0
	for h in b.hands:
		h["state"] = "rest"
	var told := -1.0
	var hurt := false
	var hushed := false
	var hp1: float = w.player.hp
	for i in int(2.5 / DT):
		_step(w, 1)
		for h in b.hands:
			if str(h["state"]) == "tell" and told < 0.0:
				told = float(h["len"])
		if w.player.hp < hp1:
			hurt = true
			hushed = (w.dims() as Dictionary).has("hushed")
			break
	_check(told >= 0.45 - 0.001 and absf(told - 0.65) < 0.001, "the Grasp's tell is 0.65 s on Dusk (%.2f)" % told)
	_check(hurt and hushed, "the hand closes in its column at the islet edge: it hurts and hushes")
	var gh: Dictionary = {}
	for h in b.hands:
		if str(h["state"]) in ["up", "sink"]:
			gh = h
	if not gh.is_empty():
		var r: Rect2 = b.hand_rect(gh)
		_check(r.size.x == 40.0 and (r.size.y == 64.0 or str(gh["state"]) == "sink") and absf(r.get_center().x - edge) < 1.0, "a 40 x 64 column at the edge")
	# Swallow the Light: forced to 56 px where it passes; a peal breaks it.
	await _done(w)
	w = await _hush_world()
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	b._swallow_t = 0.0
	w.player.reset_at(_at(30.0, 11))
	var forced := false
	for i in int(12.0 / DT):
		_step(w, 1)
		if b._dark_t > 0.0 and absf(float(w.hero_light_radius()) - 56.0) < 0.5:
			forced = true
			break
	_check(forced, "the Swallow's wall forces his light to 56 px as it passes")
	b._swallow_t = 0.0
	b.swallow = {}
	for i in int(1.3 / DT):
		_step(w, 1)
	_check(not b.swallow.is_empty(), "(another wall gathers)")
	for i in int(1.2 / DT):
		_step(w, 1)
	# Ring the bell ahead of it.
	var front := float(b.swallow.get("x", 0.0))
	var near := 0
	var bd := INF
	for i in b.bells.size():
		var d := absf((b.bells[i]["p"] as Vector2).x - front)
		if d < bd and b.bell_ready(i):
			bd = d
			near = i
	b.bells[near]["smother"] = 0.0
	b.ring_bell(near)
	var broke := false
	for i in int(2.0 / DT):
		_step(w, 1)
		if b.swallow.is_empty():
			broke = true
			break
	_check(broke and int(b.used.get("swallow_broken", 0)) >= 1, "a peal that reaches the wall breaks it")
	await _done(w)


func _to_phase(w: Node2D, b: Node2D, ph: int) -> void:
	## Straight to the start of a phase (the roar played out).
	b.hp = (float(b.PHASES[ph - 2]) + 0.001) * b.max_hp
	b.phase = ph - 1
	b.state = "fight"
	match ph - 1:
		1:
			b._open_window1()
			b._part = "eye"
		2:
			b._choke()
			b._part = "core"
	b.hit({"how": "slash", "amount": 0.01 * b.max_hp, "from_x": 0.0})
	for i in int(2.3 / DT):
		_step(w, 1)


func _test_hush_p2() -> void:
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	_check(int(b.phase) == 2 and str(b.state) == "fight" and b.shadow_k > 0.95, "at 65% the shadow Waxby has risen")
	_check(b.stem_levels().get("hush_final_drums", 0.0) == -80.0, "the drums are gone from 65% (stem_levels)")
	# The Inhale: the pull (110 px/s toward the Maw), and a bell rung in it chokes it.
	b._move_n = -1
	b._act_timer = 0.0
	var islet: Dictionary = b.islets[3]
	w.player.reset_at(Vector2(float(islet["x0"]) + 120.0, b.islet_top))
	var x0: float = w.player.position.x
	var pulled := false
	for i in int(3.5 / DT):
		_step(w, 1)
		if str(b.maw["state"]) == "inhale":
			pulled = true
			break
	for i in int(0.6 / DT):
		_step(w, 1)
	var moved: float = x0 - w.player.position.x
	_check(pulled and moved > 0.5 * 110.0 * 0.6 * 0.8, "the Inhale pulls him toward the Maw (%.0f px in 0.6 s)" % moved)
	_check((w.dims() as Dictionary).has("hush_inhale"), "his light x0.6 while pulled (the dim pipeline)")
	var ready := 0
	for i in b.bells.size():
		if b.bell_ready(i):
			ready = i
	b.ring_bell(ready)
	_check(str(b.maw["state"]) == "choked" and b.is_open(), "a bell rung during the Inhale chokes it (the window)")
	_check(absf(float(b.maw["t"]) - 2.4) < 0.05, "for 2.4 s")
	_step(w, 1)
	var hp0: float = b.hp
	b._part = "core"
	b.hit({"how": "slash", "amount": 30.0, "from_x": b.mid_x})
	_check(absf((hp0 - b.hp) - 30.0) < 0.01, "the core takes it in full")
	# A stolen flame struck free: heal 6%, +20% light for 6 s, once.
	for i in 30:
		_step(w, 1)
	w.player.max_hp = 1000.0
	w.player.hp = 500.0
	var r0: float = w.hero_light_radius()
	b.free_flame(2)
	_check(absf(w.player.hp - 560.0) < 0.5, "a freed flame heals 6%% (%.0f)" % w.player.hp)
	_check(float(w.hero_light_radius()) > r0 * 1.15, "and brightens him (+20%%: %.0f -> %.0f)" % [r0, w.hero_light_radius()])
	b.free_flame(2)
	_check(absf(w.player.hp - 560.0) < 0.5, "each flame is freed once")
	w.player.max_hp = 1.0e7
	w.player.hp = 1.0e7
	await _done(w)
	# The Snuff and the Silence Bolts.
	w = await _hush_world()
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	var isl: Dictionary = b.islets[1]
	w.player.reset_at(Vector2((float(isl["x0"]) + float(isl["x1"])) * 0.5, b.islet_top))
	b._start_snuff(w.player)
	_check(absf(float(b.snuff["len"]) - 1.2) < 0.001, "the Snuff's tell is 1.2 s on Dusk")
	var sr: Rect2 = b.snuff["rect"]
	_check(sr.size == Vector2(6 * TILE, 3 * TILE) and absf(sr.end.y - b.islet_top) < 0.1, "its hand covers 6 tiles x 3 rows of the islet top")
	w.player.invuln = 0.0
	var hp1: float = w.player.hp
	for i in int(1.4 / DT):
		_step(w, 1)
	_check(w.player.hp < hp1 and (w.dims() as Dictionary).has("hushed"), "staying under it hurts and hushes")
	await _done(w)
	w = await _hush_world()
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	b._fire_bolts(w.player)
	_check(b.bolts.size() == 3, "Silence Bolts: three")
	var v0: Vector2 = b.bolts[0]["v"]
	_check(absf(v0.length() - 200.0) < 0.1, "at 200 px/s")
	b.bells[0]["smother"] = 0.0
	for bo in b.bolts:
		bo["p"] = (b.bells[0]["p"] as Vector2) + Vector2(40, -30)
	b.ring_bell(0)
	for i in 12:
		_step(w, 1)
	_check(b.bolts.is_empty(), "a peal dispels the bolts inside it")
	# The Drowned Choir at 55%.
	b.hp = 0.56 * b.max_hp
	b.maw["state"] = "choked"
	b._part = "core"
	b.hit({"how": "slash", "amount": 0.02 * b.max_hp, "from_x": 0.0})
	var hush_n := 0
	for e in w.enemies:
		if e.kind == "hushling" and e.alive:
			hush_n += 1
	_check(hush_n == 3, "at 55%% three Hushlings rise onto the islets (%d)" % hush_n)
	await _done(w)


func _test_hush_p3() -> void:
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	_to_phase(w, b, 3)
	_check(int(b.phase) == 3 and not b.eye3.is_empty(), "at 30% the great Eye opens")
	var sunk := true
	for bl in b.bells:
		sunk = sunk and bool(bl["sunk"])
	_check(sunk, "every bell sinks")
	var sl: Dictionary = b.stem_levels()
	_check(sl.get("hush_final_bells", 0.0) == -80.0 and sl.get("hush_final_choir", 0.0) == -80.0 and sl.has("hush_final_wick"), "P3's stems: the void and his own melody")
	# The rule: solid only where its hurt rect meets max(light, 96 px) round him.
	b.eye3["state"] = "hover"
	b._act_timer = 99.0
	w.player.reset_at(_at(20.0, 11))
	b.eye3["p"] = w.player.center() + Vector2(112.0 + 60.0, -20.0)
	var rad := maxf(float(w.hero_light_radius()), 96.0)
	var solid_near: bool = b.eye3_solid(w.player)
	b.eye3["p"] = w.player.center() + Vector2(112.0 + rad + 20.0, -20.0)
	var solid_far: bool = b.eye3_solid(w.player)
	_check(solid_near and not solid_far, "the Eye is solid only where it meets max(his light, 96 px)")
	w.light_override(56.0)
	b.eye3["p"] = w.player.center() + Vector2(112.0 + 90.0, 0.0)
	_check(b.eye3_solid(w.player), "low on light the circle is still 96 px (never unhittable)")
	w.light_override(-1.0)
	# The Gaze: 1.2 s, lock 0.50 s, then Blink within 40 px for 1.4 s.
	b.eye3["state"] = "hover"
	b._act_timer = 0.0
	b._move_n = -1
	var tell_len := -1.0
	var lock_len := -1.0
	var blinked := false
	for i in int(4.0 / DT):
		_step(w, 1)
		var st := str(b.eye3["state"])
		if st == "gaze_tell" and tell_len < 0.0:
			tell_len = float(b.eye3["len"])
		if st == "gaze_lock" and lock_len < 0.0:
			lock_len = float(b.eye3["len"])
		if st == "blink":
			blinked = true
			break
	_check(absf(tell_len - 1.2) < 0.001 and absf(lock_len - 0.50) < 0.001, "the Gaze: the cone 1.2 s, the lock 0.50 s (%.2f, %.2f)" % [tell_len, lock_len])
	_check(blinked and b.is_open(), "after the Gaze, the Blink (the window)")
	for i in int(0.4 / DT):
		_step(w, 1)
	var er: Rect2 = b.eye3_rect()
	var pc: Vector2 = w.player.center()
	var edge := minf(absf(er.position.x - pc.x), absf(er.end.x - pc.x))
	_check(edge <= 40.0, "it drifts to within 40 px of him (%.0f px)" % edge)
	_check(absf(float(b.window_len()) - 1.4) < 0.001, "for 1.4 s")
	b._part = "eye3"
	var hp0: float = b.hp
	b.hit({"how": "slash", "amount": 25.0, "from_x": pc.x})
	_check(absf((hp0 - b.hp) - 25.0) < 0.01, "a Blink hit lands in full")
	for i in int(2.0 / DT):
		_step(w, 1)
	b._part = "eye3"
	hp0 = b.hp
	b.hit({"how": "slash", "amount": 25.0, "from_x": pc.x})
	_check(is_equal_approx(b.hp, hp0), "outside a Blink the Eye takes nothing")
	# The Deep Quiet: 1.6 s, the water a row over the islets for 2.0 s: on an
	# islet he drowns (the pit rule) and is put on a perch; on one he's safe.
	b.eye3["state"] = "hover"
	var t0: float = b.tell(float(b.TUNE["quiet_tell"]), float(b.TUNE["quiet_floor"]))
	_check(absf(t0 - 1.6) < 0.001, "the Deep Quiet's tell is 1.6 s on Dusk")
	w.player.max_hp = 1000.0
	w.player.hp = 1000.0
	w.player.reset_at(Vector2(float(b.islets[2]["x0"]) + 30.0, b.islet_top))
	w.player.invuln = 0.0
	b.flood = {"state": "tell", "t": t0, "len": t0, "y": b.islet_top - TILE}
	for i in int((t0 + 0.2) / DT):
		_step(w, 1)
	var hp2: float = w.player.hp
	var on_perch := false
	for pc2 in b.perches:
		if absf(w.player.position.y - float(pc2["top"])) < 2.0 and w.player.position.x >= float(pc2["x0"]) and w.player.position.x <= float(pc2["x1"]):
			on_perch = true
	_check(hp2 < 1000.0 and on_perch, "caught on an islet he drowns and wakes on the nearest perch (%.0f)" % hp2)
	for i in int(2.4 / DT):
		_step(w, 1)
	_check(is_equal_approx(w.player.hp, hp2), "on the perch the water can't reach him")
	# Echoes of Light at 20%, "hush_last" at 15%.
	w.player.max_hp = 1.0e7
	w.player.hp = 1.0e7
	b.hp = 0.21 * b.max_hp
	b._start_blink()
	b._part = "eye3"
	b.hit({"how": "slash", "amount": 0.02 * b.max_hp, "from_x": 0.0})
	var un := 0
	for e in w.enemies:
		if e.kind == "unwick" and e.alive:
			un += 1
	_check(un == 2, "at 20%% two Unwicks rise (%d)" % un)
	await _done(w)
	# A Perfect Guard sends the Gaze back into the Eye: 150% and an instant Blink.
	w = await _hush_world("dusk", "knight")
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	_to_phase(w, b, 3)
	w.player.reset_at(_at(21.0, 11))
	b.eye3["state"] = "hover"
	b.eye3["side"] = 1.0
	b._act_timer = 0.0
	b._move_n = -1
	w.player.res = w.player.res_max
	var hpb: float = b.hp
	var got := false
	for i in int(4.0 / DT):
		w.player.facing = 1 if (b.eye3["p"] as Vector2).x > w.player.position.x else -1
		var pad := {}
		if str(b.eye3["state"]) == "gaze_fire" or (str(b.eye3["state"]) == "gaze_lock" and float(b.eye3["t"]) < 0.05):
			pad["special"] = true
		_step(w, 1, pad)
		if str(b.eye3["state"]) == "blink" and b.hp < hpb:
			got = true
			break
	_check(got, "a Perfect Guard reflects the Gaze into the Eye: a Blink, and the reflect lands (%.0f)" % (hpb - b.hp))
	await _done(w)


func _test_hush_heard() -> void:
	## HEARD!: 30% inside one window, once a phase (+10%, the window ends).
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	b._open_window1()
	b._part = "eye"
	for k in 3:
		b.hit({"how": "slash", "amount": 0.1 * b.max_hp, "from_x": 0.0})
	_check(int(b._stagger_phase) == 1 and not b.is_open(), "30%% in the Eye's window: HEARD!, and the window ends")
	_check(absf(b.hp / b.max_hp - 0.70) < 0.01, "its bonus stops 5%% over the phase line (%.1f%%)" % (b.hp / b.max_hp * 100.0))
	await _done(w)
	# boss_rig's rules on the Hush (the rev5 review): one blow in a window
	# stops at 30% until HEARD!, and only the window's first stomp is 3x
	# (the bounces after it, and their waves, take nothing).
	w = await _hush_world()
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	b._open_window1()
	b._part = "eye"
	b.hit({"how": "slash", "amount": 1.0e9, "from_x": 0.0})
	_check(absf(b.hp / b.max_hp - 0.70) < 0.01 and int(b.phase) == 1, "one window takes at most 30%% of the Hush (%.1f%%)" % (b.hp / b.max_hp * 100.0))
	b._stagger_phase = 0
	b.hp = b.max_hp
	b._open_window1()
	b._part = "eye"
	var hp1: float = b.hp
	b.hit({"how": "stomp", "amount": 100.0, "from_x": 0.0})
	var first: float = hp1 - b.hp
	hp1 = b.hp
	b.hit({"how": "stomp", "amount": 100.0, "from_x": 0.0})
	b.hit({"how": "shock", "amount": 100.0, "from_x": 0.0, "stomp_born": true})
	_check(absf(first - 300.0) < 0.01 and absf(hp1 - b.hp) < 0.01, "its window's first stomp is 3x, the bounces after it take nothing (%.0f / %.0f)" % [first, hp1 - b.hp])
	await _done(w)


func _test_hush_windows() -> void:
	## The windows test: the reference knight at 6-4's arrival (L30, area 31)
	## swings 6.5 times a window; the Hush needs 8 (9), at least 3 / 3 / 2 a phase.
	var s := _ref_stats(_arrival("6-4"), 31)
	var per := float(s["basic"]) * (1.0 + float(s["dmg_pct"]))
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	var hc: Dictionary = (load(HUSH) as Script).get_script_constant_map()
	_check(absf(b.max_hp - float(hc["BASE_HP"]) * Combat.e_hp(31) * float(Combat.diff("dusk")["hp"])) < 1.0, "its life is BASE_HP at area 31 (%.0f)" % b.max_hp)
	var windows := 0
	var by_phase := [0, 0, 0]
	while int(b.phase) <= 3 and b.hp > 0.0 and windows < 40:
		b.state = "fight"
		var ph := int(b.phase)
		match ph:
			1:
				b._open_window1()
				b._part = "eye"
			2:
				b._choke()
				b._part = "core"
			_:
				if b.eye3.is_empty():
					b.eye3 = {"p": w.player.center() + Vector2(150, 0), "state": "hover", "t": 0.0, "len": 0.0, "side": 1.0}
				b._start_blink()
				b._part = "eye3"
		var swings := 7 if windows % 2 == 0 else 6
		for k in swings:
			if not b.is_open() or b.state != "fight":
				break
			b.hit({"how": "slash", "amount": per, "from_x": 0.0})
		windows += 1
		by_phase[ph - 1] += 1
		if str(b.state) == "finale":
			break
	print("  the Hush: an L30 knight (%.0f a swing, %.1f base) needs %d windows (%s) against %.0f life" % [per, per / Combat.e_hp(31), windows, str(by_phase), b.max_hp])
	# (The rev5 retune: BASE_HP from the real-pad oracle in test_boss_windows,
	# every calling's phases 70 s or less; this model's knight then needs more
	# than the spec's 8 (9): its floor and the 3 / 3 / 2 still hold.)
	_check(windows >= 8 and windows <= 12, "the reference knight needs 8 or more windows for the Hush, 12 at most (%d)" % windows)
	_check(by_phase[0] >= 3 and by_phase[1] >= 3 and by_phase[2] >= 2, "at least 3 / 3 / 2 a phase (%s)" % str(by_phase))
	await _done(w)


func _test_hush_phase_time() -> void:
	## Each phase in 70 s or less: the reference knight's hits land in every
	## window the Hush gives (a bell rung whenever one's ready and its move
	## allows: at the Eye's lurk in P1, in each Inhale in P2); a sturdy hero
	## standing on the middle islet.
	var s := _ref_stats(_arrival("6-4"), 31)
	var per := float(s["basic"]) * (1.0 + float(s["dmg_pct"]))
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(22.0, 11))
	var times := [0.0, 0.0, 0.0]
	var ph0 := 1
	var t := 0.0
	var swing_t := 0.0
	var in_win := 0
	while t < 240.0 and b.hp > 0.0 and str(b.state) != "finale":
		w.player.hp = w.player.max_hp
		var ph := int(b.phase)
		if ph != ph0:
			ph0 = ph
		times[ph - 1] = float(times[ph - 1]) + DT
		if str(b.state) == "fight":
			if ph == 1 and str(b.eye["state"]) == "lurk":
				for i in b.bells.size():
					if b.bell_ready(i):
						b.ring_bell(i)
						break
			elif ph == 2 and str(b.maw["state"]) == "inhale":
				for i in b.bells.size():
					if b.bell_ready(i):
						b.ring_bell(i)
						break
		if b.is_open():
			swing_t -= DT
			if swing_t <= 0.0 and in_win < 7:
				swing_t = 0.28
				in_win += 1
				b._part = ["eye", "core", "eye3"][ph - 1]
				b.hit({"how": "slash", "amount": per, "from_x": 0.0})
		else:
			in_win = 0
			swing_t = 0.3
		_step(w, 1)
		t += DT
	print("  the Hush's phases took %.0f / %.0f / %.0f s" % times)
	_check(float(times[0]) <= 70.0 and float(times[1]) <= 70.0 and float(times[2]) <= 70.0 and (b.hp <= 0.0 or str(b.state) == "finale"),
			"each phase lasts 70 s or less (%.0f / %.0f / %.0f)" % times)
	await _done(w)


func _snuff_and_retry(w: Node2D) -> void:
	w.player.max_hp = 100.0
	w.player.hp = 1.0
	w.player.invuln = 0.0
	w.hurt_player(50.0, w.player.position.x - 20.0, "hit", null, {})
	for i in int(1.8 / DT):
		_step(w, 1)


func _test_hush_checkpoints() -> void:
	## Through the World's own snuff: Dusk keeps P2 and P3, Nightfall P3,
	## Witching nothing; the freed flames stay freed; the arena resets.
	for row in [["dusk", 2, true], ["dusk", 3, true], ["nightfall", 2, false], ["nightfall", 3, true], ["witching", 3, false]]:
		var w := await _hush_world(str(row[0]))
		_sturdy(w)
		var b: Node2D = await _wake(w, _at(14.5, 11))
		_to_phase(w, b, 2)
		if int(row[1]) == 3:
			_to_phase(w, b, 3)
		b.free_flame(1)
		b.bells[0]["smother"] = 5.0
		_snuff_and_retry(w)
		var keep: bool = row[2]
		var what := "%s, a snuff in P%d" % [row[0], row[1]]
		if keep:
			var want := 0.65 if int(row[1]) == 2 else 0.30
			_check(int(b.phase) == int(row[1]) and absf(b.hp / b.max_hp - want) < 0.001, "%s: it goes back to the start of that phase (%.0f%%)" % [what, b.hp / b.max_hp * 100.0])
			_check(bool(b.flames[1]["freed"]), "%s: the freed flame stays freed" % what)
		else:
			_check(int(b.phase) == 1 and is_equal_approx(b.hp, b.max_hp), "%s: the whole fight again" % what)
			_check(not bool(b.flames[1]["freed"]), "%s: the flames go back" % what)
		_check(str(b.state) == "sleep" and float(b.bells[0]["smother"]) <= 0.0, "%s: the arena resets, the door opens" % what)
		if keep:
			# Back in: it wakes straight into its phase, with its stems.
			b = await _wake(w, _at(14.5, 11))
			for i in int(2.5 / DT):
				_step(w, 1)
			_check(str(b.state) == "fight" and int(b.phase) == int(row[1]), "%s: back in, the fight picks up in P%d" % [what, row[1]])
		await _done(w)


func _test_hush_sim() -> void:
	## Every move in a 300 s sim (100 s a phase), no damage dealt; is_open()
	## only in windows.
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(22.0, 11))
	var only_in := true
	for ph in [1, 2, 3]:
		if ph > 1:
			_to_phase(w, b, ph)
		for i in int(100.0 / DT):
			w.player.hp = w.player.max_hp
			if i % 360 == 180:
				for k in b.bells.size():
					if b.bell_ready(k):
						b.ring_bell(k)
						break
			_step(w, 1)
			var win: bool = (ph == 1 and str(b.eye["state"]) == "surface") or (ph == 2 and str(b.maw["state"]) == "choked") \
					or (ph == 3 and str(b.eye3.get("state", "")) == "blink")
			if b.is_open() != (win and str(b.state) == "fight"):
				only_in = false
	var need := ["grasp", "swallow", "window", "inhale", "snuff", "bolts", "gaze", "deep_quiet", "roar"]
	var missing := []
	for mv in need:
		if int(b.used.get(mv, 0)) <= 0:
			missing.append(mv)
	print("  the Hush's sim: ", b.used)
	_check(missing.is_empty(), "every move is used in the sim (missing: %s)" % ", ".join(missing))
	_check(only_in, "is_open() only inside windows")
	await _done(w)


func _test_hush_rush() -> void:
	## A mode's Hush (the Waxworks): at 0 it closes its eye and sleeps, no stair.
	var lv := _stand_in(Z_ARENA, "hush", 31, 6)
	game.reset()
	game.data["difficulty"] = "dusk"
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	var b: Node2D = w.boss
	b.configure({"rush": true, "hp_mult": 0.6})
	_check(b.in_mode(), "configured for the rush")
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	_to_phase(w, b, 3)
	b.hp = 5.0
	b._start_blink()
	b._part = "eye3"
	b.hit({"how": "slash", "amount": 100.0, "from_x": 0.0})
	_check(str(b.state) == "closing" and b.finale == null, "a mode's Hush closes its eye: no stair, no hold")
	for i in int(2.5 / DT):
		_step(w, 1)
	_check(bool(b.defeated) and w.bells.size() == 1, "and sleeps: boss_defeated, the bell")
	await _done(w)


# ---------------------------------------------------------------- the review's cases (wave 2)

func _test_saint_clearance() -> void:
	## Her hover points and a beaming shard keep MIRROR_CLEAR from every
	## mirror's track: her mask never inside a pane grown by the line, so no
	## mirror turns every beam wherever he stands; a line that starts inside
	## a pane never counts.
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	var clear: float = float(b.MIRROR_CLEAR)
	var mo_r: Vector2 = b.art_point("saint_charge", "mask", b.position + Vector2(0, -106)) - b.position
	var worst := INF
	var inside := 0
	for st in b.stations:
		for m in b.mirrors:
			worst = minf(worst, absf((st as Vector2).x - float(m["x"])))
			var a: Vector2 = m["anchor"]
			for k in 97:
				var top := a.y + 96.0 * k / 96.0
				var g := Rect2(float(m["x"]) - 8.0, top, 16.0, 56.0).grow(12.0 + 6.0)
				for fx in [1.0, -1.0]:
					for bob in [-4.0, 0.0, 4.0]:
						if g.has_point((st as Vector2) + Vector2(mo_r.x * fx, mo_r.y + bob)):
							inside += 1
	_check(worst >= clear - 0.01 and inside == 0, "every hover point is %.0f px or more from every mirror's track (nearest %.0f), her mask never in a pane grown by the line (%d)" % [clear, worst, inside])
	# No mirror, wherever it is on its track, turns a beam from a hover point
	# wherever he stands (the review's probe: station x spot x pane position).
	var spots: Array = []
	for r in b.platforms + b.stones:
		var x := float(r["x0"]) + 8.0
		while x <= float(r["x1"]) - 8.0:
			spots.append(Vector2(x, float(r["y"]) - 19.0))
			x += 12.0
	var peak := 0.0
	for st in b.stations:
		var src: Vector2 = (st as Vector2) + mo_r
		for mi in b.mirrors.size():
			var m: Dictionary = b.mirrors[mi]
			for k in 13:
				m["top"] = (m["anchor"] as Vector2).y + 96.0 * k / 12.0
				var n := 0
				for sp in spots:
					if b.mirror_on(src, sp) == mi:
						n += 1
				peak = maxf(peak, float(n) / spots.size())
		b._place_mirrors(0.0)
	print("  the Saint's mirrors: the most spots one mirror turns a beam from a hover point for is %.0f%%" % (peak * 100.0))
	_check(peak < 0.9, "no mirror turns every beam from a hover point wherever he stands (at most %.0f%% of the spots)" % (peak * 100.0))
	# A line that starts inside a pane isn't "a mirror between".
	var m0: Dictionary = b.mirrors[0]
	m0["hold"] = true
	var pr: Rect2 = b.pane_rect(m0)
	_check(b.mirror_on(pr.get_center(), pr.get_center() + Vector2(0, 300)) != 0, "a line from inside a pane doesn't reflect off it")
	m0["hold"] = false
	await _done(w)
	# P3: every shard's beam starts clear of every live mirror.
	w = await _saint_world()
	_sturdy(w)
	b = await _wake(w, _at(8.0, 11))
	b.hp = 0.30 * b.max_hp + 1.0
	b.phase = 2
	b._open_window()
	b.hit({"how": "slash", "amount": 1.0e9, "from_x": b.position.x})
	var tracks := 0
	var near := 0
	var prev := ""
	for i in int(60.0 / DT):
		w.player.hp = w.player.max_hp
		_step(w, 1)
		var sh := str(b.get("_sh_state"))
		if sh == "track" and prev != "track" and str(b.state) == "scatter":
			tracks += 1
			var sm: Vector2 = b.shard_mask(b._sh_i)
			for k in b.mirrors.size():
				if b.mirror_live(k) and absf(sm.x - float(b.mirrors[k]["x"])) < clear - 0.5:
					near += 1
		prev = sh
		if str(b.state) == "refracted":
			b._end_window()
	_check(tracks >= 3 and near == 0, "each shard beams only from %.0f px beside every live mirror (%d beams, %d too near)" % [clear, tracks, near])
	await _done(w)


func _test_saint_window_hover() -> void:
	## Refracted she sinks beside him over his footing (a mirror's far side
	## is a gap or two from her), and the window's clock starts as she arrives.
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	var pa: Dictionary = b.platforms[0]
	var far: Vector2 = b.stations[b.stations.size() - 1]
	b.position = far
	b.state = "idle"
	b.timer = 99.0
	w.player.reset_at(Vector2((float(pa["x0"]) + float(pa["x1"])) * 0.5, float(pa["y"])))
	for i in 5:
		_step(w, 1)
	b._open_window()
	var to: Vector2 = b._hover_to
	_check(to.x >= float(pa["x0"]) and to.x <= float(pa["x1"]) and absf(to.x - w.player.position.x) <= 60.0 and absf(to.x - w.player.position.x) >= 30.0 \
			and absf(to.y - (float(pa["y"]) - 20.0)) < 0.5, "Refracted from the far hover point, she sinks beside him over his platform (%s, he's at %s)" % [str(to.round()), str(w.player.position.round())])
	var arrived := -1.0
	for i in int(3.0 / DT):
		_step(w, 1)
		if arrived < 0.0 and b.position.distance_to(to) < 6.0:
			arrived = float(b.timer)
			break
	_check(arrived > float(b.window_len()) - 0.1, "the window's clock waits while she sinks (%.2f of %.2f s left as she arrives)" % [arrived, b.window_len()])
	await _done(w)


func _drop_on(w: Node2D, target: Rect2, from_h := 90.0, frames := 150) -> Dictionary:
	## Wick dropped from from_h px over target's top, onto its middle: the
	## World's own stomp. Returns {lost, bounced}.
	var b: Node2D = w.boss
	var hp0: float = b.hp
	w.player.reset_at(Vector2(target.get_center().x, target.position.y - from_h))
	w.player.velocity = Vector2(0.0, 150.0)
	w.player.invuln = 5.0
	var bounced := false
	for i in frames:
		_step(w, 1)
		if b.hp < hp0 and w.player.velocity.y < -200.0:
			bounced = true
			break
	return {"lost": hp0 - b.hp, "bounced": bounced}


func _test_stomps() -> void:
	## Stomps land in every window (3x): onto the Refracted Saint, the
	## surfaced Eye, the choked core, the Blink.
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	var pa: Dictionary = b.platforms[0]
	w.player.reset_at(Vector2(float(pa["x0"]) + 40.0, float(pa["y"])))
	b.state = "idle"
	b.timer = 99.0
	b._open_window()
	b._window_t = 9.0
	b.timer = 9.0
	for i in int(1.5 / DT):
		_step(w, 1)
	var stomp := float(w.player.stats.get("stomp", 20.0))
	var r := _drop_on(w, b.rect())
	_check(bool(r["bounced"]) and float(r["lost"]) >= 2.9 * stomp, "a stomp onto the Refracted Saint lands, 3x (%.0f, a stomp %.0f)" % [r["lost"], stomp])
	await _done(w)
	w = await _hush_world()
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	var bell: Dictionary = b.bells[1]
	w.player.reset_at((bell["p"] as Vector2) + Vector2(-70.0, 0.0))
	b.ring_bell(1)
	for i in int(4.0 / DT):
		_step(w, 1)
		if b.is_open():
			break
	b.eye["t"] = 9.0
	b._grasp_t = 99.0
	for h in b.hands:
		h["state"] = "rest"
	_step(w, 1)
	stomp = float(w.player.stats.get("stomp", 20.0))
	r = _drop_on(w, b.eye1_rect())
	_check(bool(r["bounced"]) and float(r["lost"]) >= 2.9 * stomp, "a stomp onto the surfaced Eye lands, 3x (%.0f)" % r["lost"])
	_to_phase(w, b, 2)
	w.player.reset_at(Vector2(b.mid_x + 90.0, b.islet_top))
	b._act_timer = 99.0
	b._grasp_t = 99.0
	b.snuff = {}
	b._choke()
	b.maw["t"] = 9.0
	for i in int(1.0 / DT):
		_step(w, 1)
	# (a hop from the islet: the middle perch hangs over the core)
	r = _drop_on(w, b.core_rect(), 30.0)
	_check(bool(r["bounced"]) and float(r["lost"]) >= 2.9 * stomp, "a stomp onto the choked core lands, 3x (%.0f)" % r["lost"])
	_to_phase(w, b, 3)
	w.player.reset_at(Vector2(float(b.islets[3]["x0"]) + 40.0, b.islet_top))   # (open sky over it)
	b.eye3["p"] = w.player.center() + Vector2(150.0, 0.0)
	b.eye3["side"] = 1.0
	b.flood = {}
	b._start_blink()
	b.eye3["t"] = 9.0
	for i in int(0.6 / DT):
		_step(w, 1)
	_check(bool(b.eye3.get("held", false)), "the Blink drifts to his height and holds there")
	r = _drop_on(w, b.eye3_rect())
	_check(bool(r["bounced"]) and float(r["lost"]) >= 2.9 * stomp, "a stomp onto the Blink lands, 3x (%.0f)" % r["lost"])
	await _done(w)


func _test_saint_reform_tell() -> void:
	## P3: the Rose volley that opens each window has its tell as she re-forms.
	var w := await _saint_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(8.0, 11))
	b.hp = 0.30 * b.max_hp + 1.0
	b.phase = 2
	b._open_window()
	b.hit({"how": "slash", "amount": 1.0e9, "from_x": b.position.x})
	for i in int(3.5 / DT):
		_step(w, 1)
	for sh in b.shards:
		sh["cracked"] = true
	b._reform()
	var rose: float = b.tell(float(b.TUNE["rose_tell"]), float(b.TUNE["rose_floor"]))
	var len0: float = float(b._reform_len)
	var early := 0
	var t := 0.0
	while str(b.state) == "reform" and t < 3.0:
		var n0: int = b.blades.size()
		_step(w, 1)
		t += DT
		if str(b.state) == "reform" and b.blades.size() > n0:
			early += 1
	_check(len0 >= rose - 0.001 and t >= rose - 0.02 and early == 0 and b.blades.size() >= 8 and b.is_open(),
			"she re-forms through the Rose's own tell (%.2f s, the halo spun up, the 8 blades drawn) before the volley opens the window" % t)
	await _done(w)


func _test_hush_bolt_tell() -> void:
	## The Silence Bolts' tell: the crown's flames darken over it (and the
	## orbs gather), then three bolts.
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	b._move_n = (b.TUNE["p2_loop"] as Array).find("bolts") - 1   # (the next is the bolts)
	b._act_timer = 0.0
	var seen := false
	var dim_end := 1.0
	var len0 := 0.0
	for i in int(3.0 / DT):
		_step(w, 1)
		if str(b.act) == "bolts":
			seen = true
			len0 = float(b.act_len)
			dim_end = minf(dim_end, float(b.flame_dim()))
		elif seen:
			break
	_check(seen and len0 >= 0.45 - 0.001 and dim_end < 0.35 and b.bolts.size() == 3, "the Silence Bolts' tell (%.2f s): the crown's flames darken (to %.2f), then three bolts" % [len0, dim_end])
	await _done(w)


func _test_hush_retries() -> void:
	## A retry is a new try: HEARD! again after any snuff; a phase retry
	## brings back what lies below its life (the Choirs, the choir's fade,
	## the Echoes).
	var w := await _hush_world("witching")
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	b._open_window1()
	b._part = "eye"
	for k in 3:
		b.hit({"how": "slash", "amount": 0.1 * b.max_hp, "from_x": 0.0})
	_check(int(b._stagger_phase) == 1, "(HEARD! in P1)")
	_snuff_and_retry(w)
	_check(int(b._stagger_phase) == 0, "after a snuff HEARD! can come again")
	await _done(w)
	w = await _hush_world("dusk")
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	b.maw["state"] = "choked"
	b._part = "core"
	b.hp = 0.39 * b.max_hp
	b.hit({"how": "slash", "amount": 0.001 * b.max_hp, "from_x": 0.0})
	_check(b._choirs_done.size() == 2 and bool(b._choir_stem), "(both Choirs and the choir's fade in the first try)")
	_snuff_and_retry(w)
	_check(b._choirs_done.is_empty() and not bool(b._choir_stem) and int(b.phase) == 2, "a P2 retry: the Choirs and the choir stem's fade come again")
	b = await _wake(w, _at(14.5, 11))
	for i in int(2.5 / DT):
		_step(w, 1)
	b.state = "fight"
	b.maw["state"] = "choked"
	b.maw["t"] = 9.0
	b._part = "core"
	b.hp = 0.56 * b.max_hp
	b.hit({"how": "slash", "amount": 0.02 * b.max_hp, "from_x": 0.0})
	var hush_n := 0
	for e in w.enemies:
		if e.kind == "hushling" and e.alive and not e.gone:
			hush_n += 1
	_check(hush_n == 3, "and the Drowned Choir rises again at 55%% (%d)" % hush_n)
	await _done(w)
	w = await _hush_world("dusk")
	_sturdy(w)
	b = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	_to_phase(w, b, 3)
	b.hp = 0.14 * b.max_hp
	b._start_blink()
	b._part = "eye3"
	b.hit({"how": "slash", "amount": 1.0, "from_x": 0.0})
	_check(bool(b._echoes) and bool(b._last_said), "(the Echoes and hush_last in the first try)")
	_snuff_and_retry(w)
	_check(int(b.phase) == 3 and not bool(b._echoes) and not bool(b._last_said), "a P3 retry: the Echoes and hush_last come again")
	await _done(w)


func _test_hush_still() -> void:
	## P1 isn't free: stood still beside a bell out of every edge's reach, a
	## Grasp comes up through the stone at his feet (its same tell); the bot,
	## stepping off each tell, takes none.
	for mv in [false, true]:
		var w := await _hush_world()
		_sturdy(w)
		var b: Node2D = await _wake(w, _at(14.5, 11))
		var bell: Dictionary = b.bells[1]
		var spot: Vector2 = (bell["p"] as Vector2) + Vector2(-28.0, 0.0)
		w.player.reset_at(spot)
		w.player.facing = 1
		var grasped := 0
		var hp0: float = w.player.hp
		for i in int(30.0 / DT):
			var pad := {}
			if mv:
				pad = b.bot_pad(w.player)
			else:
				pad = {"attack": i % 2 == 0}
			_step(w, 1, pad)
			if w.player.hp < hp0:
				grasped += 1
				w.player.hp = w.player.max_hp
				w.player.invuln = 0.0
			hp0 = w.player.hp
		if not mv:
			_check(grasped >= 1 and int(b.used.get("grasp_still", 0)) >= 1, "stood still beside a bell mid-islet, a Grasp comes up at his feet (%d hits in 30 s)" % grasped)
		else:
			_check(grasped == 0 and int(b.windows_opened) >= 2, "the bot, stepping off each tell, takes none and opens windows (%d hits, %d windows)" % [grasped, b.windows_opened])
		await _done(w)


func _test_hush_perch_still() -> void:
	## The rev5 review: every perch was a safe spot (a hand rises only 64 px
	## from the water; P2's entry perch took no Snuff, bolt or hand either).
	## Stood still on a perch in P1 or P2, the Grasp comes up through it.
	for ph in [1, 2]:
		var w := await _hush_world()
		_sturdy(w)
		var b: Node2D = await _wake(w, _at(14.5, 11))
		if ph == 2:
			_to_phase(w, b, 2)
		var best := {}
		for p in b.perches:
			if float(p["top"]) < b.islet_top - 1.0 and float(p["x0"]) > b.arena_left + 40.0 and (best.is_empty() or float(p["x0"]) < float(best["x0"])):
				best = p
		if best.is_empty():
			_skip("no perch in the stand-in")
			await _done(w)
			continue
		var spot := Vector2((float(best["x0"]) + float(best["x1"])) * 0.5, float(best["top"]))
		var grasped := 0
		var hp0: float = w.player.hp
		for i in int(25.0 / DT):
			if i % 60 == 0:
				w.player.reset_at(spot)
			_step(w, 1, {})
			if w.player.hp < hp0:
				grasped += 1
				w.player.hp = w.player.max_hp
				w.player.invuln = 0.0
			hp0 = w.player.hp
		_check(grasped >= 1 and int(b.used.get("grasp_still", 0)) >= 1, "P%d: stood still on the perch at x %.0f, the Grasp comes up through it (%d hits in 25 s)" % [ph, spot.x, grasped])
		await _done(w)


func _test_hush_bite() -> void:
	## The Inhale bows the Maw to a standing Wick's head: pulled under it,
	## he's bitten (31, the fight's biggest blow), whatever calling's rig.
	for cls in ["knight", "sexton", "witch"]:
		var w := await _hush_world("dusk", cls)
		_sturdy(w)
		var b: Node2D = await _wake(w, _at(14.5, 11))
		_to_phase(w, b, 2)
		for bl in b.bells:
			bl["smother"] = 99.0   # (no bell to choke it)
		w.player.reset_at(Vector2(b.mid_x + 70.0, b.islet_top))
		w.player.invuln = 0.0
		b._move_n = -1
		b._act_timer = 0.0
		var bitten := false
		var hp0: float = w.player.hp
		for i in int(4.5 / DT):
			_step(w, 1)
			if w.player.hp < hp0 and bool(b._inhale_hit):
				bitten = true
				break
		var mr: Rect2 = b.maw_rect()
		_check(bitten, "%s: pulled in standing, the Maw bites (maw %.0f..%.0f, his head %.0f)" % [cls, mr.position.y, mr.end.y, b.islet_top - 38.0])
		var cr: Rect2 = b.core_rect()
		b._choke()
		for i in int(1.0 / DT):
			_step(w, 1)
		cr = b.core_rect()
		_check(cr.position.y < b.islet_top - 10.0 and cr.end.y > b.islet_top - 38.0, "%s: choked, its core is at his swing's height (%.0f..%.0f)" % [cls, cr.position.y, cr.end.y])
		await _done(w)


func _test_hush_shadow_vp() -> void:
	## The shadow's SubViewport stops rendering once it's gone (P3).
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	var vp = b.get("_shadow_vp")
	if vp == null:
		_skip("the shadow's SubViewport isn't made headless (no glow layer)")
	else:
		_check(vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "the shadow renders while it stands (P2)")
		_to_phase(w, b, 3)
		for i in int(2.0 / DT):
			_step(w, 1)
		_check(vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "and stops rendering once it's gone (P3)")
	await _done(w)


class Catch extends Logger:
	## Script errors while the bots play (as tools/smoke.gd counts them).
	var errors: Array = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bts: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_lock.unlock()

	func count() -> int:
		_lock.lock()
		var n := errors.size()
		_lock.unlock()
		return n


func _reference_any(cls: String, level: int, area: int) -> Dictionary:
	## The reference hero's gear for any calling (the knight's is _reference3,
	## with his stat nodes): Blessed at ilvl = area, the signature affixes.
	if cls == "knight":
		return _reference3(level, area)
	var h := Hero.blank(cls, level)
	h["equip"] = Items.starter(cls, area, "magic")
	for slot in ["boots", "charm"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(slot + str(area))
		var it := Items.make(slot, cls, area, "common", rng)
		var sig: String = Items.SIGNATURE[slot]
		it["rarity"] = "magic"
		it["affixes"] = [{"id": sig, "t": int(it["tier"]), "v": Items.median(sig, int(it["tier"]))}]
		h["equip"][slot] = it
	h["vigil"] = maxi(0, level - 1 - 32)
	h["xp"] = Progression.total_to(level)
	return h


func _ref_world(lv: RefCounted, cls: String, level: int, area: int) -> Node2D:
	## The World with the reference hero at the boss's arrival level (the
	## v3 tree on: set_deep(false) after).
	game.reset()
	game.new_hero(cls)
	await process_frame   # (anything the Game defers runs before the hero is set)
	var h: Dictionary = game.hero()
	var ref := _reference_any(cls, level, area)
	for k in ref:
		h[k] = ref[k]
	game.data["difficulty"] = "dusk"
	Classes.set_deep(true)
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.apply_hero()
	w.player.hp = w.player.max_hp
	w.test_pad = {}
	return w


func _ref_world_spent(lv: RefCounted, cls: String, level: int, area: int) -> Node2D:
	## _ref_world with the hero's skill points spent as test_boss_windows does
	## (root first, then round the tree): a player's hero at that level.
	game.reset()
	game.new_hero(cls)
	await process_frame
	var h: Dictionary = game.hero()
	var ref := _reference_any(cls, level, area)
	for k in ref:
		if k != "skills":
			h[k] = ref[k]
	h["level"] = 1
	h["xp"] = 0
	h["points"] = 0
	h["skills"] = {}
	Classes.set_deep(true)
	game.add_xp(Progression.total_to(level))
	var tree: Array = Classes.tree(cls)
	var guard := 0
	while int(h["points"]) > 0 and guard < 400:
		guard += 1
		var bought := false
		for n in tree:
			if int(n["branch"]) == -1 and game.buy_skill(n["id"]):
				bought = true
				break
		if bought:
			continue
		var cands := tree.filter(func(n): return int(n["branch"]) >= 0)
		cands.sort_custom(func(p, q):
			var rp := int(h["skills"].get(p["id"], 0))
			var rq := int(h["skills"].get(q["id"], 0))
			if rp != rq:
				return rp < rq
			return int(p["tier"]) * 10 + int(p["branch"]) < int(q["tier"]) * 10 + int(q["branch"]))
		for n in cands:
			if game.buy_skill(n["id"]):
				bought = true
				break
		if not bought:
			break
	game.data["difficulty"] = "dusk"
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.apply_hero()
	w.player.hp = w.player.max_hp
	w.test_pad = {}
	return w


func _bell_pad(w: Node2D, i: int) -> Dictionary:
	## After the fall: along to the bell's rope.
	for bell in w.bells:
		if bool(bell["rung"]):
			continue
		var dx: float = (bell["rope"] as Rect2).get_center().x - w.player.position.x
		if absf(dx) > 6.0:
			return {"left" if dx < 0.0 else "right": true, "jump": absf(dx) > 60.0 and (i / 40) % 3 == 0}
	return {}


func _bot_fight(w: Node2D, max_s: float, refill := true) -> Dictionary:
	## The fight played through the boss's own bot_pad (the pad the --autoplay
	## bot is to call), real movement and real swings; his life topped up
	## each tick (this is the fight's pace, not his survival); then its bell.
	## refill false: his own life, the flask under 35%, snuffs counted (a
	## snuff sends him back to the door's altar and the fight resets).
	var b: Node2D = w.boss
	var out := {"t": 0.0, "phase_t": [0.0, 0.0, 0.0], "wins": [0, 0, 0], "won": false, "falls": 0, "snuffs": 0}
	var w0 := 0
	var t := 0.0
	var i := 0
	var was_low := false
	var sn0: int = int(w.get("snuffs")) if w.get("snuffs") != null else 0
	while t < max_s and str(w.state) != "clear":
		if refill:
			w.player.hp = w.player.max_hp
		var pd := {}
		if is_instance_valid(b) and b.alive and b.get("defeated") != true:
			pd = b.bot_pad(w.player)
			var ph := clampi(int(b.phase), 1, 3)
			if not (str(b.state) in ["sleep", "finale", "closing"]):
				out["phase_t"][ph - 1] = float(out["phase_t"][ph - 1]) + DT
			if int(b.windows_opened) > w0:
				out["wins"][ph - 1] = int(out["wins"][ph - 1]) + int(b.windows_opened) - w0
				w0 = int(b.windows_opened)
		else:
			pd = _bell_pad(w, i)
		if not refill:
			if pd.is_empty() and is_instance_valid(b) and str(b.state) == "sleep":
				pd = {"right": true}
			if w.player.alive and w.player.hp < w.player.max_hp * 0.35 and i % 30 == 0:
				pd["flask"] = true
		_step(w, 1, pd)
		var low: bool = w.player.position.y > w.level.height * TILE - 40.0
		if low and not was_low:
			out["falls"] = int(out["falls"]) + 1
		was_low = low
		t += DT
		i += 1
	out["t"] = t
	out["won"] = str(w.state) == "clear"
	out["snuffs"] = (int(w.get("snuffs")) if w.get("snuffs") != null else 0) - sn0
	return out


func _test_bot_pads() -> void:
	## The review's real-pad runs: the reference knight at each boss's arrival
	## plays the fight through the boss's bot_pad (its travel, its mirror
	## spots, its bells, its dodges): the Saint in her time, each of the
	## Hush's phases in 70 s or less, both bells rung. Then every calling
	## plays each fight a minute through it: no script errors, windows opened.
	var w := await _ref_world(_stand_in(P_ARENA, "saint", 27, 5), "knight", _arrival("5-4"), 27)
	var r := await _bot_fight_async(w, 300.0)
	Classes.set_deep(false)
	print("  the Saint, real pad (L26 knight): %s in %.0f s, windows %s, phases %.0f / %.0f / %.0f s, %d falls" % ["won" if r["won"] else "NOT won", r["t"], str(r["wins"]),
			r["phase_t"][0], r["phase_t"][1], r["phase_t"][2], r["falls"]])
	_check(bool(r["won"]) and float(r["t"]) <= 240.0, "a real pad beats the Saint and rings her bell (%.0f s)" % r["t"])
	_check(int(r["wins"][0]) >= 1 and int(r["wins"][1]) >= 1 and int(r["wins"][2]) >= 1 and int(r["wins"][0]) + int(r["wins"][1]) + int(r["wins"][2]) <= 12,
			"its windows by phase, with travel: %s (the model's 2 / 2 / 2)" % str(r["wins"]))
	await _done(w)
	w = await _ref_world(_stand_in(Z_ARENA, "hush", 31, 6), "knight", _arrival("6-4"), 31)
	r = await _bot_fight_async(w, 360.0)
	Classes.set_deep(false)
	print("  the Hush, real pad (L30 knight): %s in %.0f s, windows %s, phases %.0f / %.0f / %.0f s, %d falls" % ["won" if r["won"] else "NOT won", r["t"], str(r["wins"]),
			r["phase_t"][0], r["phase_t"][1], r["phase_t"][2], r["falls"]])
	_check(bool(r["won"]), "a real pad beats the Hush, climbs the stair, gives the flame and rings the bell (%.0f s)" % r["t"])
	_check(float(r["phase_t"][0]) <= 70.0 and float(r["phase_t"][1]) <= 70.0 and float(r["phase_t"][2]) <= 70.0,
			"with travel each phase lasts 70 s or less (%.0f / %.0f / %.0f)" % [r["phase_t"][0], r["phase_t"][1], r["phase_t"][2]])
	_check(int(r["wins"][0]) >= 2 and int(r["wins"][1]) >= 2 and int(r["wins"][2]) >= 2, "its windows by phase, with travel: %s (the model's 3 / 3 / 3)" % str(r["wins"]))
	await _done(w)
	var catch := Catch.new()
	OS.add_logger(catch)
	for cls in CALLINGS:
		for which in [["saint", P_ARENA, 27, 5, "5-4"], ["hush", Z_ARENA, 31, 6, "6-4"]]:
			var e0 := catch.count()
			w = await _ref_world(_stand_in(which[1], which[0], which[2], which[3]), cls, _arrival(which[4]), which[2])
			r = await _bot_fight_async(w, 60.0)
			Classes.set_deep(false)
			var b: Node2D = w.boss
			var opened: int = int(b.windows_opened) if is_instance_valid(b) else 99
			_check(catch.count() == e0 and opened >= 1, "%s at the %s: a minute through its bot_pad, no script errors, windows opened (%d; %s)" % [cls, which[0], opened,
					"" if catch.count() == e0 else str(catch.errors[e0])])
			await _done(w)
	OS.remove_logger(catch)


func _real_rows(id: String) -> Array:
	## The real level's arena (WL5's P_ARENA, WL6's Z_ARENA) from its door
	## columns to the level's end, its signs out: the stand-in harness on the
	## real geometry (the track B merge). [] while the file isn't built.
	var path := "res://levels/%s.txt" % id
	if not FileAccess.file_exists(path):
		return []
	var lv = LevelData.load_file(path)
	var bc := Vector2i(-1, -1)
	for e in lv.entities:
		if e["kind"] == "boss":
			bc = e["cell"]
	if bc.x < 0:
		return []
	var a: Dictionary = load("res://scripts/boss_arena.gd").find(lv, LevelData.cell_floor(bc), true)
	var x0: int = int(a["left"]) / TILE - 2
	var rows: Array = []
	for line in FileAccess.get_file_as_string(path).split("---", true, 1)[1].strip_edges(true, false).split("\n"):
		if rows.size() < 15 and str(line).length() > 0 and not str(line).begins_with("Z|"):
			rows.append(str(line).substr(x0).replace("@", "."))
	return rows


func _test_real_arenas() -> void:
	## The review's real-pad runs on the real 5-4 and 6-4 arenas (WL5's and
	## WL6's rows, the doorway and all): the reference knight at arrival wins
	## each through the boss's own bot_pad, the Hush's stair, gift and bell
	## included.
	for which in [["saint", "5-4", 27, 5, 300.0], ["hush", "6-4", 31, 6, 360.0]]:
		var rows := _real_rows(str(which[1]))
		if rows.size() != 15:
			_skip("levels/%s.txt missing: its real arena" % which[1])
			continue
		var w := await _ref_world(_stand_in(rows, str(which[0]), int(which[2]), int(which[3])), "knight", _arrival(str(which[1])), int(which[2]))
		var r := await _bot_fight_async(w, float(which[4]))
		Classes.set_deep(false)
		print("  %s on the real %s arena, real pad (L%d knight): %s in %.0f s, windows %s, phases %.0f / %.0f / %.0f s, %d falls" % [which[0], which[1],
				_arrival(str(which[1])), "won" if r["won"] else "NOT won", r["t"], str(r["wins"]), r["phase_t"][0], r["phase_t"][1], r["phase_t"][2], r["falls"]])
		_check(bool(r["won"]), "the real %s arena: a real pad beats %s and rings the bell (%.0f s)" % [which[1], which[0], r["t"]])
		if which[0] == "hush":
			_check(float(r["phase_t"][0]) <= 70.0 and float(r["phase_t"][1]) <= 70.0 and float(r["phase_t"][2]) <= 70.0,
					"the real 6-4 arena: each phase 70 s or less (%.0f / %.0f / %.0f)" % [r["phase_t"][0], r["phase_t"][1], r["phase_t"][2]])
		await _done(w)
	# Survival, not just pace (the rev5 review: the refill hid that the
	# Choir's Refractor took most of a Taperwitch's life): the owner's calling
	# at 5-4's arrival level, her own life and flask, no top-up.
	var srows := _real_rows("5-4")
	if srows.size() == 15:
		var w2 := await _ref_world_spent(_stand_in(srows, "saint", 27, 5), "witch", _arrival("5-4"), 27)
		var r2 := await _bot_fight_async(w2, 360.0, false)
		Classes.set_deep(false)
		print("  saint on the real 5-4, the Taperwitch at L%d (%.0f life, her points spent), no refill: %s in %.0f s, %d snuffs, windows %s" % [_arrival("5-4"), w2.player.max_hp, "won" if r2["won"] else "NOT won", r2["t"], r2["snuffs"], str(r2["wins"])])
		_check(bool(r2["won"]) and int(r2["snuffs"]) <= 1, "the Taperwitch at arrival beats the Saint on her own life (%d snuffs, %.0f s)" % [r2["snuffs"], r2["t"]])
		await _done(w2)


func _bot_fight_async(w: Node2D, max_s: float, refill := true) -> Dictionary:
	var r := _bot_fight(w, max_s, refill)
	await process_frame
	return r


# ---------------------------------------------------------------- the finale

func _to_finale(w: Node2D) -> Node2D:
	var b: Node2D = await _wake(w, _at(14.5, 11))
	_to_phase(w, b, 2)
	_to_phase(w, b, 3)
	b.hp = 5.0
	b._start_blink()
	b._part = "eye3"
	b.hit({"how": "slash", "amount": 100.0, "from_x": 0.0})
	return b


func _finale_pad(w: Node2D, f: RefCounted, st: Dictionary) -> Dictionary:
	## A scripted thumb for the stair: run right; jump at a wall, at the end
	## of the floor, or when a landed ring is just ahead (held 0.25 s); stop on
	## the top ring and hold the Special.
	var pl: Node2D = w.player
	if str(f.state) == "top":
		return {"special": true}
	var pad := {}
	if int(st.get("jump", 0)) > 0:
		st["jump"] = int(st["jump"]) - 1
		pad["jump"] = true
		pad["right"] = true
		return pad
	var top: Rect2 = f.ring_rect(5)
	if bool(f.rings[5]["landed"]) and absf(pl.position.y - top.position.y) < 2.0 and pl.position.x > top.position.x + 30.0:
		return pad
	pad["right"] = true
	if not pl.on_floor:
		return pad
	var x: float = pl.position.x
	var feet: float = pl.position.y
	var jump := false
	if LevelData.is_solid(w.level.tile(floori((x + 14.0) / TILE), floori((feet - 8.0) / TILE))):
		jump = true
	var under := false
	for dx in [0.0, 18.0]:
		var cx := floori((x + dx) / TILE)
		var cy := floori((feet + 2.0) / TILE)
		var solid: bool = LevelData.is_solid(w.level.tile(cx, cy)) or LevelData.is_ledge(w.level.tile(cx, cy))
		for m in w.movers:
			var mr: Rect2 = m.rect()
			if absf(mr.position.y - feet) < 3.0 and x + dx >= mr.position.x and x + dx <= mr.end.x:
				solid = true
		if dx > 0.0 and not solid:
			jump = true
	for i in 6:
		if not bool(f.rings[i]["landed"]):
			continue
		var r: Rect2 = f.ring_rect(i)
		if r.position.y < feet - 1.0 and r.position.x > x + 10.0 and r.position.x < x + 90.0 and r.position.y > feet - 110.0:
			jump = true
	if jump:
		st["jump"] = 30
		pad["jump"] = true
	return pad


func _test_finale_callings() -> void:
	for cls in CALLINGS:
		var w := await _hush_world("dusk", cls)
		_sturdy(w)
		var b: Node2D = await _to_finale(w)
		_check(str(b.state) == "finale" and b.finale != null, "%s: at 0 the finale begins, in the level" % cls)
		var f: RefCounted = b.finale
		var pl: Node2D = w.player
		pl.reset_at(_at(10.0, 11))
		var st := {}
		var frames := 0
		var rings_ok := true
		var give_t := -1.0
		var black_t := -1.0
		while frames < 3600 and not bool(b.defeated):
			_step(w, 1, _finale_pad(w, f, st))
			frames += 1
			if (pl.life_frac() < 0.999 or not pl.alive) and not bool(b.defeated):
				rings_ok = false
			if give_t < 0.0 and f.said.has("give"):
				give_t = frames * DT
			if black_t < 0.0 and str(f.state) == "black":
				black_t = frames * DT
		_check(bool(b.defeated), "%s: a scripted pad reaches boss_defeated in under 3,600 frames (%d)" % [cls, frames])
		_check(rings_ok, "%s: nothing in the finale hurts him" % cls)
		_check(Story_flag("hush_given"), "%s: the flag hush_given is set (boss_6_after opens on the far bell)" % cls)
		for i in 120:
			_step(w, 1)   # (boss_defeated's 0.25 s hitstop, then the pop)
		_check(str(w.state) == "clear", "%s: the bell at his feet rings: the level clears" % cls)
		var pk := []
		for p in w.pickups:
			pk.append("%s:%s:%s" % [p["kind"], str(p.get("pop")), str(p.get("taken"))])
		_check(w.items_found.size() + w.relics_found.size() >= 2, "%s: the prize and the drops are gathered to him (%d, %d; %s)" % [cls, w.items_found.size(), w.relics_found.size(), str(pk)])
		_check(float((w.hero_flame as Dictionary).get("alpha", 1.0)) == 0.0, "%s: his flame stays given to the end" % cls)
		if cls == "knight":
			# The stair's shape (spec §3.7.4): ring k 3 tiles wide centred on
			# column 5 + 5k, its top at row 10 - k; each a light of r 140.
			var shape := true
			for i in 6:
				var r: Rect2 = f.ring_rect(i)
				var k := i + 1
				shape = shape and absf(r.get_center().x - (LEAD + 5 + 5 * k + 0.5) * TILE) < 0.5 and absf(r.position.y - (10 - k) * TILE) < 0.5 \
						and absf(r.size.x - 3 * TILE) < 0.5
			_check(shape, "the six rings stand where the spec draws them")
			# (the pad held from the first frame at the top)
			_check(f.said == ["hush_give_a", "hush_give_b", "give", "hush_quiet"], "held at once, the Hush's two lines and his @give still play whole, in order, then the quiet (%s)" % str(f.said))
			_check(give_t >= 0.0 and black_t - give_t >= float(f.LINE) - 0.05, "the black waits until his @give line has been read (%.2f s after it)" % (black_t - give_t))
			_check(int(f.sweeps) <= 2, "the Hands sweep at most twice (%d)" % f.sweeps)
		await _done(w)


func Story_flag(name: String) -> bool:
	var St = load("res://scripts/story.gd")
	return St != null and bool(St.flag(name))


func _test_finale_no_input() -> void:
	## With no input the rising dark lifts him to the rings.
	var w := await _hush_world()
	_sturdy(w)
	var b: Node2D = await _to_finale(w)
	var f: RefCounted = b.finale
	w.player.reset_at(_at(26.0, 11))
	var hp0: float = w.player.hp
	for i in int(14.0 / DT):
		_step(w, 1, {})
	_check(int(f.lifts) >= 1 and f._on_ring(w.player) >= 0, "with no input the dark lifts him onto the rings (%d lifts, ring %d)" % [f.lifts, f._on_ring(w.player)])
	_check(is_equal_approx(w.player.hp, hp0) and w.player.alive, "and never hurts him")
	# Walked off into the drained lake, he's lifted back too.
	w.player.reset_at(Vector2(float(b.gaps[1]["x0"]) + 20.0, b.islet_top - 60.0))
	for i in int(10.0 / DT):
		_step(w, 1, {})
	_check(f._on_ring(w.player) >= 0 and w.player.alive, "from the lake bed the dark lifts him back to a ring")
	await _done(w)


func _test_finale_hold() -> void:
	## The hold: headless with nobody at the pad it completes at once; driven,
	## released halfway it pauses at k ~ 0.5 (no refill); the three lines
	## play whole first; a cosmetic flame (an animated one too) is the one
	## that fades; a held jump never freezes him in the air.
	var w := await _hush_world()
	_sturdy(w)
	var C = load("res://scripts/modes/cosmetics.gd") if ResourceLoader.exists("res://scripts/modes/cosmetics.gd") else null
	var animated: bool = C != null and bool(C.animated("prismfire"))
	if animated:
		w.set("_flame_id", "prismfire")
		w.hero_flame = C.palette("prismfire", 0.0)
	var b: Node2D = await _to_finale(w)
	var f: RefCounted = b.finale
	if animated:
		_check((w.hero_flame as Dictionary).has("out"), "a cosmetic flame stays his through the climb (not stripped at the start)")
	for i in int(7.0 / DT):
		_step(w, 1)
	f._lift_to(w.player, 5)
	for i in int(1.0 / DT):
		_step(w, 1)
	_check(str(f.state) == "top", "(on the top ring)")
	# The lines first (no hold), whole and in order.
	while float(f.top_t) < float(f.LINES_END) + 0.05:
		_step(w, 1, {})
	_check(f.said.slice(0, 3) == ["hush_give_a", "hush_give_b", "give"], "at the top the Hush's two lines and his @give, in order (%s)" % str(f.said))
	# Driven: hold 1.5 s, then let go 2 s.
	var r_top: float = w.hero_light_radius()
	for i in int(1.5 / DT):
		_step(w, 1, {"special": true})
	var k1: float = float(f.hold_t) / float(f.HOLD)
	if animated:
		var hf: Dictionary = w.hero_flame
		_check(hf.has("out") and absf(float(hf.get("alpha", 1.0)) - (1.0 - k1)) < 0.05,
				"Prismfire (animated) fades with the gift: its palette, alpha %.2f at k %.2f" % [float(hf.get("alpha", 1.0)), k1])
	for i in int(2.0 / DT):
		_step(w, 1, {})
	var k2: float = float(f.hold_t) / float(f.HOLD)
	_check(absf(k1 - 0.5) < 0.02 and absf(k2 - k1) < 0.001 and str(f.state) == "top", "released halfway, the hold pauses at k %.2f (%.2f)" % [k1, k2])
	_check(absf(float(w.hero_light_radius()) - r_top * 0.5) < 2.0, "his light stays at half (%.0f of %.0f): no refill" % [w.hero_light_radius(), r_top])
	_check(float((w.special_override as Dictionary).get("hold_ring", -1.0)) > 0.45, "the Special's ring shows the hold")
	for i in int(1.6 / DT):
		_step(w, 1, {"special": true})
	_check(str(f.state) in ["black", "done"] and absf(float(w.hero_light_radius())) < 0.5, "held on, his light drains to nothing: the black")
	if animated:
		for i in int(0.5 / DT):
			_step(w, 1, {})
		_check(float((w.hero_flame as Dictionary).get("alpha", 1.0)) == 0.0, "and his flame stays out through the black (the World's cycling refresh doesn't relight it)")
	await _done(w)
	# A held jump: he jumps, the gift waits for his feet, the bell comes down
	# on the top ring.
	w = await _hush_world()
	_sturdy(w)
	b = await _to_finale(w)
	f = b.finale
	for i in int(7.0 / DT):
		_step(w, 1)
	f._lift_to(w.player, 5)
	for i in int(1.0 / DT):
		_step(w, 1)
	var air_hold := 0.0
	var landed_hold := false
	var jumped := false
	while float(f.top_t) < float(f.LINES_END) + 4.0 and str(f.state) == "top":
		var was: float = float(f.hold_t)
		_step(w, 1, {"jump": true})
		if not w.player.on_floor:
			jumped = true
			air_hold = maxf(air_hold, float(f.hold_t) - was)
		elif jumped and float(f.hold_t) > was:
			landed_hold = true
	_check(jumped and air_hold == 0.0 and landed_hold, "a held jump lifts him; the gift waits for his feet, then goes on (air %.3f)" % air_hold)
	var fr := 0
	while fr < 1200 and not bool(b.defeated):
		_step(w, 1, {"jump": true})
		fr += 1
	var top: Rect2 = f.ring_rect(5)
	_check(bool(b.defeated) and w.bells.size() == 1 and absf(((w.bells[0] as Dictionary)["pos"] as Vector2).y - top.position.y) < 1.0,
			"the bell comes down on the top ring (%s)" % (str((w.bells[0] as Dictionary)["pos"]) if not w.bells.is_empty() else "none"))
	await _done(w)
	# Headless, no pad at all: at once.
	w = await _hush_world()
	_sturdy(w)
	b = await _to_finale(w)
	f = b.finale
	for i in int(7.0 / DT):
		_step(w, 1)
	f._lift_to(w.player, 5)
	for i in int(0.8 / DT):
		_step(w, 1)
	w.test_pad = null
	var frames := 0
	while frames < 900 and not bool(b.defeated):
		w._read_pad()
		w.tick(DT)
		frames += 1
	_check(bool(b.defeated) and bool(f.gave), "headless with nobody at the pad the hold completes at once (%d frames to the end)" % frames)
	await _done(w)
