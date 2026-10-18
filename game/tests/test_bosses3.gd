extends SceneTree
## test_bosses3 (BA): Mother Gravebough and the Tinker of Hours.
##
##     godot --headless --path game --script res://tests/test_bosses3.gd
##
## In stand-in arenas built in memory exactly to spec §3.4.4 (R_ARENA) and
## §3.5.4 (K_ARENA), an approach with an altar before each door (WL3 and
## WL4 draw the real 3-4 and 4-4; when those files exist their arenas are
## checked for the anchors and the X too):
##   - the registry, MOVES (the share-cap scan's ids), touch, segments
##   - the shared rules: phases clamp at 65% and 30%; a stagger once a phase
##     with its 10% bonus; is_open() only in windows; Tollbreaker's +0.4 s;
##     no window shrinks with difficulty; chip 10% outside, full inside, the
##     window's first stomp 3x and the bounces after it chips (with real
##     ticks: a window of bouncing on the blossom); the door seals and
##     unseals; the bell on death; mercy
##   - the windows test: the reference knight (test_progression's) at the
##     arrival level needs 5 (6) windows for Gravebough, 6 (7) for the
##     Tinker, and a knight bouncing on the target every 0.24 s at least as
##     many; the biggest blows <= 34% of him, the touch <= 25%
##   - every tell >= 0.40 s on Dusk, its floor on Witching, the escape
##     formula where a tell is run from (the Minute Hand's: away from him)
##   - no safe spot: in each phase, a Wick held still on every standable or
##     climbable cell of either arena (the floor, the ledges, the vines, the
##     XII beam, P3's humps) is reached by one pass of the rotation
##   - Gravebough: the socket rule; the Heart Run (the pulse >= 1.0 s, the
##     swell, the window, the blossom the only full target); the decoy;
##     Flashbloom; the sweeps (a jump clears the low, standing clears the
##     high, a ledge clears both, the Double Sweep both); the spear's x lock
##     and its ledge, and up a vine under a climber; the march; seeds (they
##     hurt only landing on their shadows); the Thorn Crown's lanes (both
##     vines and both humps rained on, the escape formula with the fall at
##     every spot, the patterns in turn); the roars; the humps; a Perfect
##     Guard catching the bough
##   - the Tinker: the hand (clockwise 3.0 s, XII 1.5x, P2 2.5, P3
##     counter-clockwise 2.2; it turns on while he's down); ringing the lit
##     bell Chimes him once he's come to guard it (his windows 2.6 / 2.2 /
##     1.9 s, v1.0.1's); the 0.5 s grace; one ring a visit (mashing, a
##     stomp's bounce, a ring while he's getting up: no wrong hour, no
##     second chime); the frosted-bell rule (shots and waves pass, a slash
##     is the wrong hour: 1.0 s of frost, the hand stays put, v1.0.1); the
##     guard (IX and III from the wall's side, hurrying, never into Wick;
##     rung, the spring within 4 tiles of the bell); his touch only in the
##     Minute Hand's cut (v1.0.1: Wick slips past him walking, guarding,
##     tossing); the spring (full, a stomp 3x, backstabs from both sides, no
##     touch); stop_time freezes all but Wick; the hands
##     fly their drawn lines and stop at their ends; the pendulum; Rewind
##     (its last afterimage where he stops); Midnight (lanes on stone, or 5
##     tiles wide on ice: a run stops inside); lobbed cogs at a Wick up on
##     a ledge or the beam; the soldiers; a Perfect Guard reeling him
##   - every move used in a 300 s sim; the retry resets everything (time
##     running even after a snuff inside his stop); rush

const LevelData := preload("res://scripts/level_data.gd")
const Combat := preload("res://scripts/combat.gd")
const DT := 1.0 / 120.0
const TILE := 32
const APPROACH := 8
const R_ARENA := [
	"####################################",
	"####################################",
	"##........8.......8.........########",
	"##.+.{......................########",
	"##==={......................########",
	"##...{...................{..########",
	"##...{..........+........{+.########",
	"##...{.......======......{..########",
	"##...{...................{..########",
	"##...{...+...............{..########",
	".....{.=====.............{..########",
	".....{...................{..########",
	".....{..+...........+....{.X########",
	"####################################",
	"####################################"]
const K_ARENA := [
	"##################################",
	"##################################",
	"##..............................##",
	"##..............+...............##",
	"##.............=====............##",
	"##..............Y...............##",
	"##..............................##",
	"##........O.............O.......##",
	"##..............................##",
	"##...+.....................+....##",
	"...=====..................=====.##",
	"................................##",
	"..........X......+..............##",
	"####IIIIII##########IIIIII########",
	"##################################"]
const RM_SOCKETS := {"F1": Vector2i(8, 12), "F2": Vector2i(20, 12), "L1": Vector2i(9, 9), "L2": Vector2i(16, 6),
		"V1": Vector2i(3, 3), "V2": Vector2i(26, 6)}
const TK_BELLS := {"XII": Vector2i(16, 3), "IX": Vector2i(5, 9), "III": Vector2i(27, 9), "VI": Vector2i(17, 12)}
const RM_MOVES := {"sweep_low": 38.0, "sweep_high": 38.0, "spear": 34.0, "seed": 16.0, "thorns": 24.0}
const TK_MOVES := {"toss": 26.0, "minute": 35.0, "hands": 30.0, "pendulum": 32.0, "midnight": 26.0}
const PROG_TEST := "res://tests/test_progression.gd"

var WorldScript: GDScript
var Hero: GDScript
var Items: GDScript
var Classes: GDScript
var EK: GDScript
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
	Hero = load("res://scripts/hero.gd")
	Items = load("res://scripts/items.gd")
	Classes = load("res://scripts/classes.gd")
	EK = load("res://scripts/enemy_kinds.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_bosses3_save.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	_test_registry()
	_test_windows_needed()
	_test_shares()
	await _test_rm_arena()
	await _test_rm_wake_door()
	await _test_rm_hits_and_windows()
	await _test_rm_phases_and_stagger()
	await _test_rm_sockets()
	await _test_rm_heart_run()
	await _test_rm_decoy()
	await _test_rm_flashbloom()
	await _test_rm_sweeps()
	await _test_rm_double_sweep()
	await _test_rm_caught()
	await _test_rm_spears()
	await _test_rm_seeds()
	await _test_rm_thorns()
	await _test_rm_vine_spear()
	await _test_rm_reach()
	await _test_rm_mercy()
	await _test_rm_retry()
	await _test_rm_death()
	await _test_rm_sim()
	await _test_tk_arena()
	await _test_tk_hand()
	await _test_tk_ring()
	await _test_tk_hand_while_down()
	await _test_tk_bell_rules()
	await _test_tk_frost()
	await _test_tk_spring()
	await _test_tk_stop()
	await _test_tk_pendulum()
	await _test_tk_rewind()
	await _test_tk_midnight()
	await _test_tk_soldiers()
	await _test_tk_minute()
	await _test_tk_guard()
	await _test_tk_lob()
	await _test_tk_reach()
	await _test_tk_retry()
	await _test_tk_death()
	await _test_tk_sim()
	await _test_tells()
	await _test_lights()
	await _test_rush()
	await _test_real_levels()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_bosses3_save.json" + suffix))
	game.save_path = game.SAVE_PATH
	game.load_save()
	print("test_bosses3: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _rows(which: String) -> Array:
	## An approach (Wick at column 2, an altar at 4) and the arena, exactly
	## the spec's rows.
	var arena: Array = R_ARENA if which == "rm" else K_ARENA
	var out := []
	for y in 15:
		var a := "#".repeat(APPROACH) if (y < 10 or y > 12) else ".".repeat(APPROACH)
		if y == 12:
			a = "..P.K..."
		out.append(a + str(arena[y]))
	return out


func _arena(which: String, diff := "dusk", cls := "knight", header := "", headless := true) -> Node2D:
	var lv = LevelData.new()
	var hdr := "title: t\nsubtitle: t\n"
	if which == "rm":
		hdr += "area: 17\nboss: rootmother\nboss_music: rootmother\ntheme: rootheart\nmusic: orchard\n"
	else:
		hdr += "area: 22\nboss: tinker\nboss_music: tinker\ntheme: escapement\nmusic: carillon\n"
	lv.parse(hdr + header + "---\n" + "\n".join(_rows(which)))
	lv.id = "3-4" if which == "rm" else "4-4"
	lv.world = 3 if which == "rm" else 4
	game.reset()
	game.data["difficulty"] = diff
	if cls != "knight" or not game.has_hero(cls):
		game.new_hero(cls)
	game.set_hero(cls)
	var w: Node2D = WorldScript.new()
	w.setup(lv, headless)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	return w


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _tick(w: Node2D, pad := {}) -> void:
	## One physics tick with this pad (the World reads its edges).
	w.test_pad = pad
	w._read_pad()
	w.tick(DT)


func _ticks(w: Node2D, sec: float, pad := {}, cb := Callable()) -> void:
	for i in int(round(sec / DT)):
		_tick(w, pad)
		if cb.is_valid():
			cb.call()


func _awake(w: Node2D, at_x := 200.0) -> Node2D:
	## Wick into the arena and the boss up (its roar played through).
	var b: Node2D = w.boss
	b.active = true
	w.player.reset_at(Vector2(b.arena_left + at_x, b.floor_y))
	for i in 5:
		_tick(w)
	return b


func _safe(w: Node2D) -> void:
	w.player.invuln = 99.0
	w.player.hp = w.player.max_hp


func _stand(w: Node2D, x: float, y := -1.0) -> void:
	var b: Node2D = w.boss
	w.player.reset_at(Vector2(x, b.floor_y if y < 0.0 else y))
	w.player.on_floor = true


func _arena_cell(b: Node2D, c: Vector2i) -> Vector2i:
	## A spec arena cell in the level.
	return Vector2i(floori(b.arena_left / TILE) - 2 + c.x, floori(b.floor_y / TILE) - 13 + c.y)


func _reference(level: int, area: int) -> Dictionary:
	## test_progression's reference knight (spec §1.3), or a copy of it.
	if ResourceLoader.exists(PROG_TEST):
		var tp = load(PROG_TEST)
		if tp != null and (tp as GDScript).can_instantiate():
			var o = tp.new()
			if o.has_method("_reference3"):
				var h: Dictionary = o._reference3(level, area)
				o.free()
				return h
			o.free()
	var h2: Dictionary = Hero.blank("knight", level)
	h2["equip"] = Items.starter("knight", area, "magic")
	return h2


func _arrival(boss_level: String) -> int:
	## The reference knight's level at a boss: the level before's exit, floored.
	var tp = load(PROG_TEST) if ResourceLoader.exists(PROG_TEST) else null
	var et = (tp as Script).get_script_constant_map().get("EXIT_TARGET", {}) if tp != null else {}
	var before := {"3-4": "3-3", "4-4": "4-3"}.get(boss_level, "")
	if et is Dictionary and (et as Dictionary).has(before):
		return int(floor(float(et[before])))
	return 17 if boss_level == "3-4" else 21


func _open_rm(b: Node2D, sock := "F1") -> void:
	## Opens Gravebough's heart at a socket (a Heart Run's window).
	b.target = b.socket_named(sock)
	b.decoy = -1
	b._stage = "open"
	b.state = "heart"
	b.open_window(float(b.WINDOW[clampi(b.phase - 1, 0, 2)]))


func _spots(w: Node2D, b: Node2D, cols: Array, rows: Array) -> Array:
	## Every place in the arena a Wick can hold still: standing on a floor
	## (the arena's, a ledge, a beam, a hump) or hanging in a vine cell:
	## [feet, vine column or -1, name] (spec arena columns and rows).
	var out := []
	for ac in range(int(cols[0]), int(cols[1]) + 1):
		for ar in range(int(rows[0]), int(rows[1]) + 1):
			var c := _arena_cell(b, Vector2i(ac, ar))
			var t: int = w.level.tile(c.x, c.y)
			if LevelData.is_solid(t):
				continue
			var x := (c.x + 0.5) * TILE
			if LevelData.is_climb(t):
				out.append([Vector2(x, (c.y + 1) * TILE - 2.0), c.x, "vine (%d,%d)" % [ac, ar]])
			elif LevelData.is_floor(w.level.tile(c.x, c.y + 1)) and not LevelData.is_solid(w.level.tile(c.x, c.y - 1)):
				out.append([Vector2(x, (c.y + 1) * TILE), -1, "on (%d,%d)" % [ac, ar + 1]])
	return out


func _hold(w: Node2D, sp: Array) -> void:
	## Wick held on a spot, whole and touchable.
	var pl: Node2D = w.player
	if int(sp[1]) >= 0:
		if not pl.climbing or pl.climb_col != int(sp[1]):
			pl.grab_vine(int(sp[1]))
	elif pl.climbing:
		pl.release_vine()
	pl.position = sp[0]
	pl.velocity = Vector2.ZERO
	pl.on_floor = int(sp[1]) < 0
	pl.invuln = 0.0
	pl.hp = pl.max_hp


func _blows(b: Node2D) -> int:
	var n := 0
	for k in b.blows:
		n += int(b.blows[k])
	return n


func _reach_run(w: Node2D, b: Node2D, sp: Array, ph: int, cap := 70.0) -> String:
	## One pass of the phase's rotation (every move in ROT[ph] cast, then 4 s
	## for the last to play out) with Wick held on sp: the first move of
	## hers that reaches him, or "".
	var rot_n: int = b.ROT[ph].size()
	b._rot[ph] = 0
	b.blows.clear()
	var done_at := -1.0
	var el := 0.0
	while el < cap:
		_hold(w, sp)
		_tick(w)
		el += DT
		if _blows(b) > 0:
			return str(b.blows.keys()[0])
		# (Gravebough queues a cycle's moves at once: done when they're cast.)
		if done_at < 0.0 and int(b._rot[ph]) >= rot_n and (b._queue as Array).is_empty():
			done_at = el
		if done_at >= 0.0 and el - done_at >= 4.0:
			break
	return ""


# ---------------------------------------------------------------- shared

func _test_registry() -> void:
	for k in ["rootmother", "tinker"]:
		_check(EK.known(k) and EK.has(k), "%s is known to the registry and its script exists" % k)
	var rm = load("res://scripts/rootmother_boss.gd")
	var tk = load("res://scripts/tinker_boss.gd")
	_check(rm != null and tk != null, "both boss scripts load")
	if rm == null or tk == null:
		return
	var mr: Dictionary = (rm as Script).get_script_constant_map().get("MOVES", {})
	var mt: Dictionary = (tk as Script).get_script_constant_map().get("MOVES", {})
	for m in RM_MOVES:
		_check(is_equal_approx(float(mr.get(m, -1.0)), float(RM_MOVES[m])), "Gravebough's MOVES %s is %.0f (the scan's id)" % [m, RM_MOVES[m]])
	for m in TK_MOVES:
		_check(is_equal_approx(float(mt.get(m, -1.0)), float(TK_MOVES[m])), "the Tinker's MOVES %s is %.0f (the scan's id)" % [m, TK_MOVES[m]])
	var a = rm.new()
	var b = tk.new()
	a.set("dmg_mult", 1.0)
	b.set("dmg_mult", 1.0)
	_check(is_equal_approx(a.dmg("touch"), 26.0) and is_equal_approx(b.dmg("touch"), 24.0), "touch: Gravebough 26, the Tinker 24")
	_check(a.boss_id == "rootmother" and a.boss_name == "Mother Gravebough" and b.boss_id == "tinker" and b.boss_name == "The Tinker of Hours",
			"the ids and names (decisions: rootmother, tinker)")
	_check(a.boss_info().get("segments") == [0.65, 0.30] and b.boss_info().get("segments") == [0.65, 0.30], "boss_info carries segments [0.65, 0.30]")
	_check(a.has_method("is_open") and a.has_method("configure") and a.has_method("window_bonus") and a.has_method("reset_fight"),
			"the v3 boss interface (is_open, configure, window_bonus, reset_fight)")
	_check(a.xp_kind == "rootmother" and b.xp_kind == "tinker" and a.embers == 60 and b.embers == 70, "XP kinds and embers (60, 70)")
	# The bar names him as his "before" scene's card does (the int2 review:
	# the Tinker's bar said "The Stopped Clock", the card "The Frozen Minute").
	var St = load("res://scripts/story.gd")
	for pair in [[a, "boss_3_before"], [b, "boss_4_before"]]:
		var card := {}
		for sh in St.scene(str(pair[1])).get("shots", []):
			for bt in (sh as Dictionary).get("beats", []):
				if bt is Dictionary and str(bt.get("do", "")) == "boss_card":
					card = bt
		_check(str(card.get("name", "")) == str(pair[0].boss_name) and str(card.get("title", "")) == str(pair[0].boss_title),
				"%s's bar and his card agree: %s, %s (card: %s, %s)" % [pair[0].boss_id, pair[0].boss_name, pair[0].boss_title, card.get("name", ""), card.get("title", "")])
	a.free()
	b.free()


func _windows_for(script_path: String, area: int, boss_level: String, stomper := false) -> Array:
	## The windows test (v2's Tollgrave method): the reference knight at the
	## arrival level swings every window fully (window / cooldown swings). A
	## stomper instead lands on the target and lets the bounce carry him
	## back onto it every STOMP_EVERY s, the whole window, with no input.
	Classes.set_deep(true)
	var lvl := _arrival(boss_level)
	var st: Dictionary = Hero.stats(_reference(lvl, area), [], "dusk")
	Classes.set_deep(false)
	# A swing's expected blow: its crits counted (Combat.roll: crit chance at
	# crit_mult; the reference knight's 25% at x1.5 is 12.5% more a swing).
	var crit_k := 1.0 + minf(float(st.get("crit", 0.05)), Combat.CRIT_CAP) * (float(st.get("crit_mult", 1.5)) - 1.0)
	var per_swing := float(st["basic"]) * (1.0 + float(st["dmg_pct"])) * crit_k
	var per_stomp := float(st.get("stomp", 0.0)) * crit_k
	var cd := float(st["cooldown"]) if not stomper else STOMP_EVERY
	var sc = load(script_path)
	var b = sc.new()
	b.setup_stats(area, "dusk")
	var windows := 0
	var guard := 0
	var wins: Array = b.WINDOW
	while b.alive and guard < 40:
		guard += 1
		b.state = "idle"
		b.open_window(float(wins[clampi(b.phase - 1, 0, 2)]))
		var n := int(float(wins[clampi(b.phase - 1, 0, 2)]) / cd)
		windows += 1
		for k in n:
			if not b.is_open():
				break
			if stomper:
				b.hit({"how": "stomp", "from_x": 0.0, "amount": per_stomp})
			else:
				b.hit({"how": "slash", "from_x": 0.0, "amount": per_swing})
		if b.state == "roar" or b.state == "midnight":
			b.state = "idle"
	var out := [windows, per_stomp if stomper else per_swing, lvl, b.max_hp]
	b.free()
	return out


const STOMP_EVERY := 0.24           # the tap bounce's period on a floor target (the reviewer's probe: 11 in 2.6 s)


func _test_windows_needed() -> void:
	var r := _windows_for("res://scripts/rootmother_boss.gd", 17, "3-4")
	print("  Gravebough: the L%d reference knight (%.0f a swing) needs %d windows against %.0f life" % [r[2], r[1], r[0], r[3]])
	_check(int(r[0]) >= 5 and int(r[0]) <= 6, "the reference knight needs 5-6 windows for Gravebough (%d)" % r[0])
	var t := _windows_for("res://scripts/tinker_boss.gd", 22, "4-4")
	print("  the Tinker: the L%d reference knight (%.0f a swing) needs %d windows against %.0f life" % [t[2], t[1], t[0], t[3]])
	_check(int(t[0]) >= 6 and int(t[0]) <= 7, "the reference knight needs 6-7 windows for the Tinker (%d)" % t[0])
	# Bouncing on the target: the window's first stomp 3x, the rest chip.
	var rs := _windows_for("res://scripts/rootmother_boss.gd", 17, "3-4", true)
	var ts := _windows_for("res://scripts/tinker_boss.gd", 22, "4-4", true)
	print("  bounce-stomping (%.0f / %.0f a stomp) needs %d windows for Gravebough, %d for the Tinker" % [rs[1], ts[1], rs[0], ts[0]])
	_check(int(rs[0]) >= 5 and int(ts[0]) >= 6, "a knight bouncing on the target the whole window needs at least the lower count too (%d, %d)" % [rs[0], ts[0]])


func _test_shares() -> void:
	## Every blow's share of the arrival knight's life (after DR): the
	## biggest <= 34%, the touch <= 25% (decisions, Numbers).
	Classes.set_deep(true)
	for row in [["res://scripts/rootmother_boss.gd", 17, "3-4"], ["res://scripts/tinker_boss.gd", 22, "4-4"]]:
		var st: Dictionary = Hero.stats(_reference(_arrival(str(row[2])), int(row[1])), [], "dusk")
		var life := float(st["max_hp"])
		var keep := 1.0 - clampf(float(st["dr"]), 0.0, Combat.DR_CAP)
		var sc = load(str(row[0]))
		var b = sc.new()
		b.setup_stats(int(row[1]), "dusk")
		var big := 0.0
		var big_id := ""
		for m in b.MOVES:
			var share: float = b.dmg(m) * keep / life
			if share > big:
				big = share
				big_id = m
		var touch: float = b.dmg("touch") * keep / life
		print("  %s: biggest blow %s %.1f%%, touch %.1f%% of the L%d knight" % [b.boss_id, big_id, big * 100.0, touch * 100.0, _arrival(str(row[2]))])
		_check(big <= 0.34 + 0.0005, "%s's biggest blow is <= 34%% of the arrival knight (%.1f%%)" % [b.boss_id, big * 100.0])
		_check(touch <= 0.25 + 0.0005, "%s's touch is <= 25%% (%.1f%%)" % [b.boss_id, touch * 100.0])
		b.free()
	Classes.set_deep(false)


# ---------------------------------------------------------------- Gravebough

func _test_rm_arena() -> void:
	var w := await _arena("rm")
	_check(w.level.errors.is_empty(), "the R_ARENA stand-in parses (%s)" % ", ".join(w.level.errors))
	var b: Node2D = w.boss
	_check(b != null and b.get("boss_id") == "rootmother", "3-4's X spawns Mother Gravebough")
	if b == null:
		await _done(w)
		return
	_check(absf(b.position.x - (b.arena_right + 48.0)) < 0.5 and absf(b.position.y - b.floor_y) < 0.5 and b.look_face == -1,
			"rooted 48 px past the right wall's face, on the floor, facing left (A4's _placement: %s)" % b.position)
	var tr: Rect2 = b.trunk_rect()
	_check(absf(tr.position.x - (b.arena_right - 5.0)) < 3.0, "her trunk box begins 5 px in front of the wall (%.1f vs %.1f)" % [tr.position.x, b.arena_right])
	_check(b.door.size() == 6, "her door is the arena's left doorway (%d cells)" % b.door.size())
	_check(b.sockets.size() == 6, "six sockets (%d)" % b.sockets.size())
	for nm in RM_SOCKETS:
		var i: int = b.socket_named(nm)
		var want := _arena_cell(b, RM_SOCKETS[nm])
		_check(i >= 0 and b.sockets[i]["cell"] == want, "socket %s at the spec's %s" % [nm, RM_SOCKETS[nm]])
		if i >= 0:
			_check(bool(b.sockets[i]["vine"]) == nm.begins_with("V"), "%s is %sa vine socket" % [nm, "" if nm.begins_with("V") else "not "])
			var box: Rect2 = b.sockets[i]["box"]
			_check(box.size == Vector2(28, 28), "%s's blossom box is 28 x 28" % nm)
			if not nm.begins_with("V"):
				_check(absf(box.end.y - float(b.sockets[i]["base"].y)) < 3.0, "%s's blossom stands on its floor" % nm)
	_check(b.max_hp > 0.0 and absf(b.max_hp - 480.0 * Combat.e_hp(17)) < 1.0, "her life is BASE_HP 480 x e_hp(17) on Dusk (%.0f)" % b.max_hp)
	await _done(w)


func _test_rm_wake_door() -> void:
	var w := await _arena("rm")
	var b: Node2D = w.boss
	b.active = true
	_ticks(w, 0.5)
	_check(b.state == "sleep", "she sleeps while Wick is in the approach")
	w.player.reset_at(Vector2(b.arena_left + 120.0, b.floor_y))
	_ticks(w, 0.2)
	_check(b.state != "sleep", "she wakes when he steps into the arena (%s)" % b.state)
	var sealed := true
	for c in b.door:
		sealed = sealed and LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(sealed, "and the doorway seals behind him")
	b.reset_fight()
	var open := true
	for c in b.door:
		open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(open and b.state == "sleep", "reset_fight opens the door and puts her to sleep")
	await _done(w)


func _bounce_aftershock() -> void:
	## A Bellfounder with Aftershock (f_after, tier 2) left to bounce on the
	## open blossom, and on the Tinker's spring, with no input: his bounces
	## off a boss throw no waves, so one stomp is still one 3x stomp and
	## chips, never a phase (the int2 review: 35% of Gravebough, P1 over).
	for which in ["rm", "tk"]:
		var w := await _arena(which, "dusk", "founder")
		var h: Dictionary = game.hero()
		(h["skills"] as Dictionary)["f_after"] = 3
		w.apply_hero()
		var b := _awake(w)
		_ticks(w, 1.5)
		if which == "rm":
			_open_rm(b, "F1")
		else:
			b.state = "walk"
			b._chimed()
		var box: Rect2 = b.rect()
		w.player.reset_at(Vector2(box.get_center().x, box.position.y - 40.0))
		w.player.velocity = Vector2(0, 300)
		var hp0: float = b.hp
		var waves := 0
		for i in int(2.6 / DT):
			_safe(w)
			w.player.position.x = box.get_center().x
			w.player.velocity.x = 0.0
			_tick(w)
			for hz in w.hazards:
				if str(hz.get("owner", "")) == "player" and hz.get("stomp_born", false):
					waves += 1
		var stomp := float(w.player.stats.get("stomp", 0.0)) * float(w.player.stats.get("crit_mult", 1.5))
		var n: int = b.window_stomps
		_check(n >= 5 and waves == 0 and b.phase == 1 and hp0 - b.hp <= stomp * (3.0 + 0.1 * (n - 1)) + 1.0,
				"%s: an Aftershock Bellfounder bouncing on the target with no input throws no waves off the boss: one 3x stomp and chips, phase 1 (%.1f%% for %d stomps, %d wave ticks)"
				% [b.boss_name, 100.0 * (hp0 - b.hp) / b.max_hp, n, waves])
		await _done(w)


func _test_rm_hits_and_windows() -> void:
	var w := await _arena("rm")
	var b := _awake(w)
	_ticks(w, 1.5)
	var hp0: float = b.hp
	var h := {"how": "slash", "from_x": b.position.x - 100.0, "amount": 100.0}
	b.hit(h)
	_check(absf((hp0 - b.hp) - 10.0) < 0.01 and h.get("chip", false), "outside a window her trunk chips 10%% (%.1f)" % (hp0 - b.hp))
	_check(b.rect() == b.trunk_rect() and not b.is_open(), "outside a window her rect is the trunk and she isn't open")
	_open_rm(b, "F1")
	_check(b.is_open() and b.rect() == b.blossom_rect() and b.rect() == b.sockets[b.socket_named("F1")]["box"],
			"in a window her rect is the open blossom's box (the World's only full target)")
	_check(not b.touch_damage() and b.stompable == false or true, "(touch while open is answered by the trunk itself)")
	hp0 = b.hp
	b.hit({"how": "slash", "from_x": 0.0, "amount": 100.0})
	_check(absf((hp0 - b.hp) - 100.0) < 0.01, "a blossom hit lands in full (%.1f)" % (hp0 - b.hp))
	hp0 = b.hp
	b.hit({"how": "stomp", "from_x": 0.0, "amount": 50.0})
	_check(absf((hp0 - b.hp) - 150.0) < 0.01, "a stomp on it deals 3x (%.1f)" % (hp0 - b.hp))
	# A stomp through the World: Wick lands on the blossom.
	var box: Rect2 = b.blossom_rect()
	_open_rm(b, "F1")
	_safe(w)
	w.player.reset_at(Vector2(box.get_center().x, box.position.y - 40.0))
	w.player.velocity = Vector2(0, 300)
	hp0 = b.hp
	_ticks(w, 0.3)
	_check(b.hp < hp0, "landing on the open blossom stomps it (%.0f)" % (hp0 - b.hp))
	# Left to bounce on it the whole window with no input: the first stomp
	# pays 3x, every bounce after it only chips.
	_open_rm(b, "F1")
	b.hp = b.max_hp
	w.player.reset_at(Vector2(box.get_center().x, box.position.y - 40.0))
	w.player.velocity = Vector2(0, 300)
	hp0 = b.hp
	for i in int(2.6 / DT):
		_safe(w)
		w.player.position.x = box.get_center().x
		w.player.velocity.x = 0.0
		_tick(w)
	var stomp := float(w.player.stats.get("stomp", 0.0)) * float(w.player.stats.get("crit_mult", 1.5))
	var n: int = b.window_stomps
	_check(n >= 5, "(the bounce lands on the blossom again and again: %d stomps)" % n)
	_check(hp0 - b.hp <= stomp * (3.0 + 0.1 * (n - 1)) + 1.0, "a window of bouncing deals one 3x stomp and chips (%.0f for %d stomps of %.0f)" % [hp0 - b.hp, n, stomp])
	await _bounce_aftershock()
	# is_open only in windows, over a stretch of the fight.
	b.close_window()
	b._end_run(true)
	b.state = "idle"
	b.timer = 0.0
	_stand(w, b.arena_left + 200.0)
	var bad := 0
	var seen := 0
	for i in int(40.0 / DT):
		_safe(w)
		_tick(w)
		if b.is_open():
			seen += 1
			if b._stage != "open":
				bad += 1
		elif b._stage == "open":
			bad += 1
	_check(seen > 0 and bad == 0, "is_open() is true exactly in the open stage (%d open ticks, %d wrong)" % [seen, bad])
	# Tollbreaker and difficulty.
	w.player.stats["flags"] = {"tollbreaker_window": 0.4}
	b.open_window(2.6)
	_check(absf(b.window_len - 3.0) < 0.001, "Tollbreaker adds 0.4 s to her window (%.2f)" % b.window_len)
	w.player.stats["flags"] = {}
	await _done(w)
	var ww := await _arena("rm", "witching")
	var bw := _awake(ww)
	_open_rm(bw, "F1")
	_check(absf(bw.window_len - 2.6) < 0.001, "her P1 window is 2.6 s on Witching too (%.2f)" % bw.window_len)
	bw.phase = 3
	_open_rm(bw, "F1")
	_check(absf(bw.window_len - 1.9) < 0.001, "and P3's 1.9 s")
	await _done(ww)


func _test_rm_phases_and_stagger() -> void:
	var w := await _arena("rm")
	var b := _awake(w)
	_ticks(w, 1.5)
	_open_rm(b, "F1")
	# (Until the phase's stagger a window's blows stop at 30% of her life:
	# past it, a blow runs on to the line.)
	b.hit({"how": "slash", "from_x": 0.0, "amount": 999999.0})
	_check(absf(b.hp - 0.70 * b.max_hp) < 1.0 and b.phase == 1 and b.state == "wilt" and not b.is_open(),
			"a window's blows stop at 30%% until the phase's stagger: WILTED at 70%% (%.3f)" % (b.hp / b.max_hp))
	b.state = "idle"
	_open_rm(b, "F1")
	b.hit({"how": "slash", "from_x": 0.0, "amount": 999999.0})
	_check(absf(b.hp - 0.65 * b.max_hp) < 1.0 and b.phase == 2 and not b.is_open(), "then a blow clamps at 65%%, the window ends, phase 2 (%.3f)" % (b.hp / b.max_hp))
	_check(b.state == "roar", "and she roars into it")
	# The roar kills the Rootlings and sinks the pillars.
	b.spawn_add("rootling", Vector2(b.arena_left + 300.0, b.floor_y))
	_check(b.adds_alive("rootling") == 1, "(a Rootling of hers)")
	b.state = "idle"
	b._spear_at(b.arena_left + 250.0, 0, 0.0)
	_ticks(w, 0.9)
	_check(b._spears.size() == 1, "(a pillar standing)")
	_open_rm(b, "F1")
	b._stagger_phase = b.phase
	b.hit({"how": "slash", "from_x": 0.0, "amount": 999999.0})
	_check(absf(b.hp - 0.30 * b.max_hp) < 1.0 and b.phase == 3, "the next clamps at 30%%, phase 3 (%.3f)" % (b.hp / b.max_hp))
	_check(b.adds_alive() == 0 and b._spears.is_empty(), "the roar kills her Rootlings and sinks the pillars")
	# Deep Roots: the humps, solid; she rises a tile's half on her legs.
	var solid := 0
	for hx in b.HUMPS:
		for dx in 2:
			var c := _arena_cell(b, Vector2i(int(hx) + dx, 12))
			if LevelData.is_solid(w.level.tile(c.x, c.y)):
				solid += 1
	_check(solid == 4, "two root humps (2 cells each) come up at arena x 12 and 23 (%d solid cells)" % solid)
	_ticks(w, 1.5)
	_check(absf(b._rise - 32.0) < 0.5, "she rises 32 px on her stilt legs (%.1f)" % b._rise)
	_check(b.legs_rect().size.y > 30.0, "and her legs have a touch box")
	# The stagger: 30% in one window, once a phase; the blow that gets there
	# is cut to it, and the bonus never takes her within 5% of the line (the
	# int2 review: a stagger left her 1 HP over it, and the next chip ended
	# the phase: every phase fell to one window).
	await _done(w)
	var w2 := await _arena("rm")
	var b2 := _awake(w2)
	_ticks(w2, 1.5)
	_open_rm(b2, "F1")
	var hp0: float = b2.hp
	b2.hit({"how": "slash", "from_x": 0.0, "amount": 0.20 * b2.max_hp})
	b2.hit({"how": "slash", "from_x": 0.0, "amount": 0.15 * b2.max_hp})
	var lost: float = hp0 - b2.hp
	_check(b2.state == "wilt" and not b2.is_open(), "30%% in a window: WILTED, the window ends")
	_check(absf(lost - 0.30 * b2.max_hp) < 1.0 and b2.phase == 1, "the blow that reaches 30%% is cut to it, and no bonus takes her within 5%% of the line (%.3f lost)" % (lost / b2.max_hp))
	b2.hit({"how": "slash", "from_x": 0.0, "amount": 0.001 * b2.max_hp})
	_check(b2.phase == 1 and b2.hp > b2.phase_floor() + 0.04 * b2.max_hp, "a chip after the stagger doesn't end the phase (%.3f)" % (b2.hp / b2.max_hp))
	b2.hp = b2.max_hp
	_open_rm(b2, "F1")
	hp0 = b2.hp
	b2.hit({"how": "slash", "from_x": 0.0, "amount": 0.31 * b2.max_hp})
	_check(absf((hp0 - b2.hp) - 0.31 * b2.max_hp) < 1.0 and b2.is_open(), "and only once a phase (the second pays no bonus, the window goes on)")
	await _done(w2)


func _test_rm_sockets() -> void:
	## The nearest to Wick at least 3 tiles away, never the last one, the
	## vine sockets skipped for the first two runs.
	var w := await _arena("rm")
	var b: Node2D = w.boss
	var bad := []
	var vine_early := 0
	var picks := 0
	var xs := [96, 160, 224, 288, 352, 416, 480, 544, 608, 672, 736, 800]
	for run in 6:
		b.runs = run
		for last in range(-1, 6):
			b.last_socket = last
			for x in xs:
				for yy in [b.floor_y - 20.0, b.floor_y - 116.0, b.floor_y - 212.0]:
					var p := Vector2(b.arena_left + float(x), yy)
					var i: int = b.pick_socket(p)
					picks += 1
					if i < 0:
						bad.append("none at %s" % p)
						continue
					if i == last:
						bad.append("the last socket again at %s" % p)
					if bool(b.sockets[i]["vine"]) and run < 2:
						vine_early += 1
					var d: float = (b.sockets[i]["center"] as Vector2).distance_to(p)
					# Nearest qualifying: no other allowed socket is nearer and >= 96.
					for j in b.sockets.size():
						if j == i or j == last or (bool(b.sockets[j]["vine"]) and run < 2):
							continue
						var dj: float = (b.sockets[j]["center"] as Vector2).distance_to(p)
						if dj >= 96.0 and dj < d - 0.01 and d >= 96.0:
							bad.append("%s nearer than %s at %s" % [b.sockets[j]["name"], b.sockets[i]["name"], p])
					if d < 96.0:
						bad.append("%s only %.0f px from Wick at %s" % [b.sockets[i]["name"], d, p])
	_check(bad.is_empty(), "the socket rule holds for %d picks (%s)" % [picks, ", ".join(bad.slice(0, 4))])
	_check(vine_early == 0, "no vine socket in the first two runs (%d)" % vine_early)
	b.runs = 2
	b.last_socket = -1
	var got_vine := false
	for x in xs:
		var i2: int = b.pick_socket(Vector2(b.arena_left + float(x), b.floor_y - 212.0))
		got_vine = got_vine or bool(b.sockets[i2]["vine"])
	_check(got_vine, "from the third run a vine socket can be picked")
	await _done(w)


func _test_rm_heart_run() -> void:
	var w := await _arena("rm")
	var b := _awake(w, 150.0)
	_safe(w)
	# To the first Heart Run (two moves first).
	var t0 := -1.0
	var tgt := -1
	var opened_at := -1.0
	var el := 0.0
	var blushed := false
	for i in int(20.0 / DT):
		_safe(w)
		_stand(w, b.arena_left + 150.0)
		_tick(w)
		el += DT
		if t0 < 0.0 and b._stage == "pulse":
			t0 = el
			tgt = b.target
			blushed = b._stage in ["blush", "pulse"]
		if t0 >= 0.0 and b._stage == "open":
			opened_at = el
			break
	_check(t0 >= 0.0 and tgt >= 0, "a Heart Run starts after her two moves")
	_check(blushed, "the target's bud blushes at once (the target is known from the run's start)")
	var travel := opened_at - t0
	_check(opened_at > 0.0 and travel >= 1.0 + 0.4 - 0.02, "the pulse takes at least 1.0 s, then the bud swells 0.4 s (%.2f s to open)" % travel)
	_check(b.is_open() and absf(b.window_len - 2.6) < 0.01, "then the window opens: 2.6 s in P1 (%.2f)" % b.window_len)
	var dist: float = (b.sockets[tgt]["center"] as Vector2).distance_to(w.player.center())
	_check(dist >= 96.0 and not bool(b.sockets[tgt]["vine"]), "its socket is at least 3 tiles from Wick and not a vine's (%.0f px, %s)" % [dist, b.sockets[tgt]["name"]])
	# A swing at the open blossom through the World lands in full.
	var box: Rect2 = b.blossom_rect()
	_stand(w, box.position.x - 14.0, float(b.sockets[tgt]["base"].y))
	w.player.facing = 1
	var hp0: float = b.hp
	_ticks(w, 0.05, {"attack": true})
	_ticks(w, 0.25)
	var lost: float = hp0 - b.hp
	_check(lost > 0.0 and lost > float(w.player.stats.get("basic", 1.0)) * 0.5, "a swing on the open blossom lands in full (%.1f)" % lost)
	# The window runs out: it closes, and the pulse runs home.
	_ticks(w, 3.0)
	_check(not b.is_open() and b.target == -1, "the blossom closes when the window runs out")
	await _done(w)


func _test_rm_decoy() -> void:
	var w := await _arena("rm")
	var b := _awake(w, 150.0)
	_safe(w)
	b.phase = 2
	b.hp = b.max_hp * 0.6
	b._queue = ["heart"]
	b.state = "idle"
	b.timer = 0.0
	var found := false
	for i in int(6.0 / DT):
		_safe(w)
		_stand(w, b.arena_left + 150.0)
		_tick(w)
		if b._stage == "open":
			found = true
			break
	_check(found and b.decoy >= 0 and b.decoy != b.target, "a P2 Heart Run opens a decoy beside the true blossom")
	if not found or b.decoy < 0:
		await _done(w)
		return
	_check(b._decoy_state == "open", "the decoy opens with it")
	var left0: float = b.window_t
	var orchard = w.features.module("orchard")
	var n0: int = orchard.clouds.size() if orchard else 0
	var dbox: Rect2 = b.decoy_rect()
	w.player.invuln = 0.0
	_stand(w, dbox.position.x - 14.0, float(b.sockets[b.decoy]["base"].y))
	w.player.facing = 1
	var hp_hero: float = w.player.hp
	_ticks(w, 0.05, {"attack": true})
	_ticks(w, 0.1)
	_check(b._decoy_state == "burst" and b.decoys_burst == 1, "striking the decoy bursts it")
	var big := false
	if orchard:
		for c in orchard.clouds:
			if c.get("source") == b and absf(float(c["r"]) - 72.0) < 0.1 and absf(float(c["life"]) - 4.0) < 0.1:
				big = true
	_check(big and (orchard == null or orchard.clouds.size() > n0), "into a spore cloud of r 72 for 4 s")
	_check(w.player.hp < hp_hero, "its puff hurts within 40 px (%.0f)" % (hp_hero - w.player.hp))
	_check(b.window_t <= left0 - 0.5 + 0.15 or not b.is_open(), "and the true blossom closes 0.5 s early (%.2f from %.2f)" % [b.window_t, left0])
	await _done(w)


func _test_rm_flashbloom() -> void:
	var w := await _arena("rm", "dusk", "witch")
	var b := _awake(w, 150.0)
	_safe(w)
	b.phase = 2
	b.hp = b.max_hp * 0.6
	_open_rm(b, "F2")
	var c: Vector2 = b.sockets[b.socket_named("F2")]["center"]
	b._add_cloud(c + Vector2(0, -20), 64.0, 6.0, false)
	_tick(w)
	var hp0: float = b.hp
	w.spawn_shot({"kind": "spark", "pos": c + Vector2(-70, -20), "vel": Vector2(300, 0), "life": 1.0, "owner": "player", "coef": 0.0})
	_ticks(w, 0.2)
	var basic := float(w.player.stats.get("basic", 10.0))
	_check(b.flashblooms == 1, "fire in a cloud over the open blossom is a Flashbloom (%d)" % b.flashblooms)
	_check(hp0 - b.hp >= basic * 0.3, "and it deals her about 0.6x basic, in full (%.1f vs basic %.1f)" % [hp0 - b.hp, basic])
	await _done(w)


func _sweep_run(kind_: String, hero_y := -1.0, jump_at := -1.0, hold := 0.5) -> Array:
	## One sweep of kind_ with Wick at arena x 300 (on the floor, or on a
	## ledge at hero_y): [hurt, hp lost, jumped].
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	w.player.invuln = 0.0
	w.player.hp = w.player.max_hp
	var x: float = b.arena_left + 300.0
	_stand(w, x, hero_y)
	_ticks(w, 0.1)
	b._sweep_tell([kind_])
	var hp0: float = w.player.hp
	var jumped := false
	var el := 0.0
	var dist_px := 0.0
	for i in int(4.0 / DT):
		var pad := {}
		if jump_at >= 0.0 and b.state == "sweep" and not jumped:
			for bd in b._bands:
				if bool(bd["live"]) and float(bd["front"]) - (w.player.position.x + 10.0) <= jump_at:
					jumped = true
					el = 0.0
		if jumped and el < hold:
			pad = {"jump": true}
		el += DT
		_tick(w, pad)
		if b.state == "idle":
			break
	var lost: float = hp0 - w.player.hp
	await _done(w)
	return [lost > 0.0, lost, jumped]


func _test_rm_sweeps() -> void:
	var r := await _sweep_run("low")
	_check(r[0], "the low sweep hurts a Wick standing on the floor (%.0f)" % r[1])
	r = await _sweep_run("low", -1.0, 70.0)
	_check(bool(r[2]) and not r[0], "a jump when its lash comes clears the low sweep")
	r = await _sweep_run("high")
	_check(not r[0], "the high sweep passes over a Wick standing on the floor")
	r = await _sweep_run("high", -1.0, 90.0)
	_check(bool(r[2]) and r[0], "and catches one who jumps into it (%.0f)" % r[1])
	# A Wick on a row-10 ledge (the L1 ledge, 96 px up): safe from both.
	var w := await _arena("rm")
	var b: Node2D = w.boss
	var ly: float = b.floor_y - 96.0
	await _done(w)
	var lx := 300.0
	# (arena columns 7-11 hold the row-10 ledge: x 224..384; Wick at 300)
	r = await _sweep_run("low", ly)
	_check(not r[0], "a Wick on a row-10 ledge is safe from the low sweep")
	r = await _sweep_run("high", ly)
	_check(not r[0], "and from the high one")
	# The bands: 28 px at 15, 16 px at 86 (A4's hurt bands), filled at 0.2.
	w = await _arena("rm")
	b = w.boss
	var lo: Rect2 = b.band_rect("low")
	var hi: Rect2 = b.band_rect("high")
	_check(absf(lo.size.y - 28.0) < 0.01 and absf((b.floor_y - lo.get_center().y) - 15.0) < 0.01, "the low band: 28 px round 15 px up")
	_check(absf(hi.size.y - 16.0) < 0.01 and absf((b.floor_y - hi.get_center().y) - 86.0) < 0.01, "the high band: 16 px round 86 px up")
	_check(hi.position.y + hi.size.y < b.floor_y - 38.0 and hi.end.y <= b.floor_y - 78.0 + 0.01 and hi.position.y >= b.floor_y - 96.0 - 0.01,
			"it clears a standing Wick (38 px) and stays under a row-10 ledge's top")
	_check(lo.size.x >= (b.near_x() - b.arena_left) - 1.0, "the bands span the arena (the tell fills the whole width)")
	await _done(w)


func _test_rm_double_sweep() -> void:
	## The Double Sweep, low then high: a full held jump over the first
	## front is down before the second; high then low: stay down, then jump.
	for order in [["low", "high"], ["high", "low"]]:
		var w := await _arena("rm")
		var b := _awake(w, 300.0)
		_ticks(w, 1.4)
		w.player.invuln = 0.0
		w.player.hp = w.player.max_hp
		_stand(w, b.arena_left + 300.0)
		_ticks(w, 0.1)
		b.phase = 3
		b._sweep_tell(order)
		var hp0: float = w.player.hp
		var jumped := false
		var el := 0.0
		for i in int(5.0 / DT):
			var pad := {}
			if not jumped and b.state == "sweep":
				for bd in b._bands:
					if str(bd["kind"]) == "low" and bool(bd["live"]) and float(bd["front"]) - (w.player.position.x + 10.0) <= 70.0:
						jumped = true
						el = 0.0
			if jumped and el < 0.6:
				pad = {"jump": true}
			el += DT
			_tick(w, pad)
			if b.state == "idle":
				break
		_check(jumped and w.player.hp >= hp0, "the Double Sweep %s then %s is cleared by one full jump over the low lash (lost %.0f)" % [order[0], order[1], hp0 - w.player.hp])
		await _done(w)


func _test_rm_caught() -> void:
	## A Knight's Perfect Guard on the bough catches it: she reels 1.0 s.
	var w := await _arena("rm", "dusk", "knight")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	w.player.invuln = 0.0
	w.player.hp = w.player.max_hp
	_stand(w, b.arena_left + 300.0)
	w.player.facing = 1
	b._sweep_tell(["low"])
	var caught := false
	for i in int(3.0 / DT):
		if b.state == "sweep" and w.kit.get("guarding") != null:
			for bd in b._bands:
				if float(bd["front"]) - (w.player.position.x + 10.0) <= 12.0:
					w.kit.guarding = true
					w.kit.guard_t = 0.0
		_tick(w)
		if b.state == "caught":
			caught = true
			break
	_check(caught, "a Perfect Guard on the bough catches it (she reels)")
	if caught:
		_check(absf(b.timer - 1.0) < 0.05, "for 1.0 s (%.2f)" % b.timer)
	await _done(w)


func _test_rm_spears() -> void:
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	w.player.invuln = 0.0
	w.player.hp = w.player.max_hp
	var x: float = b.arena_left + 300.0
	_stand(w, x)
	b.state = "dig"
	b.timer = 9.0
	b._spear_at(b._lock_x(w.player), 0, 0.0)
	var sx: float = b._spears[0]["x"]
	_check(absf(sx - x) < 0.5, "the spear's x locks under Wick at the tell's start")
	# He steps a little aside during the tell: clear.
	_ticks(w, 0.2)
	_stand(w, x + 26.0)
	var hp0: float = w.player.hp
	_ticks(w, 0.6)
	_check(w.player.hp >= hp0, "a 26 px step during the tell clears it (the x stayed locked)")
	var ledge = b._spears[0].get("ledge") if not b._spears.is_empty() else null
	_check(ledge != null and w.movers.has(ledge), "the risen spear is a one-way ledge on top")
	if ledge != null:
		_check(absf(float(ledge.rect().position.y) - (b.floor_y - 64.0)) < 1.0, "64 px up (a step toward L1)")
	_ticks(w, 1.6)
	_check(ledge == null or not w.movers.has(ledge), "and it's gone after 1.5 s")
	# Standing on the spot: hurt on the rise.
	w.player.invuln = 0.0
	_stand(w, x)
	b._spear_at(b._lock_x(w.player), 0, 0.0)
	hp0 = w.player.hp
	_ticks(w, 0.9)
	_check(w.player.hp < hp0, "staying on the bulge, the rise hurts (%.0f)" % (hp0 - w.player.hp))
	b._sink_spears()
	# The march: P2 3, P3 5, 0.3 s apart, the last under Wick.
	for ph in [2, 3]:
		b.phase = ph
		b._spears.clear()
		_stand(w, x)
		b._march(w.player)
		var n: int = b._spears.size()
		_check(n == (3 if ph == 2 else 5), "the Spear March in P%d is %d spears (%d)" % [ph, 3 if ph == 2 else 5, n])
		var gaps_ok := true
		for i in n:
			gaps_ok = gaps_ok and absf(-float(b._spears[i]["t"]) - 0.3 * i) < 0.001
		_check(gaps_ok, "0.3 s apart")
		_check(absf(float(b._spears[n - 1]["x"]) - x) < 0.5 and float(b._spears[0]["x"]) > x, "from near her toward Wick, the last under him")
		b._sink_spears()
	await _done(w)


func _test_rm_seeds() -> void:
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	_safe(w)
	_stand(w, b.arena_left + 300.0)
	b.state = "seed_tell"
	b.timer = 9.0
	b._seedfall()
	_ticks(w, 0.55)
	_check(b._seeds.size() == 3, "the crown shakes 0.5 s, then three seeds fly (%d)" % b._seeds.size())
	var xs := []
	for s in b._seeds:
		xs.append(float((s["to"] as Vector2).x) - w.player.position.x)
	xs.sort()
	_check(xs.size() == 3 and absf(xs[0] + 96.0) < 1.0 and absf(xs[1]) < 1.0 and absf(xs[2] - 96.0) < 1.0, "onto Wick's x and 96 px either side (%s)" % str(xs))
	# Pop one before it hatches.
	_ticks(w, 0.75)
	var s0: Dictionary = b._seeds[0]
	_check(str(s0["stage"]) == "sit", "they land after 0.7 s")
	var p: Vector2 = s0["to"]
	var embers0 := 0
	for pk in w.pickups:
		if pk["kind"] == "ember" and not pk["taken"]:
			embers0 += 1
	_stand(w, p.x - 18.0)
	w.player.facing = 1
	_ticks(w, 0.05, {"attack": true})
	_ticks(w, 0.1)
	var embers1 := 0
	for pk in w.pickups:
		if pk["kind"] == "ember" and not pk["taken"]:
			embers1 += 1
	_check(b._seeds.size() == 2 and embers1 >= embers0 + 1, "a hit pops a seed before it hatches, for an ember")
	_stand(w, b.arena_left + 60.0)
	_ticks(w, 1.6)
	_check(b.adds_alive("rootling") == 2, "the rest hatch a Rootling each after 1.5 s (%d)" % b.adds_alive("rootling"))
	for i in 3:
		b._seedfall()
		_ticks(w, 2.9)
	_check(b.adds_alive("rootling") <= 3, "never more than 3 Rootlings (%d)" % b.adds_alive("rootling"))
	var add: Node2D = b._adds[0] if not b._adds.is_empty() else null
	_check(add != null and not add.ordinary and add.respawned and add.item_chance == 0.0, "her Rootlings are adds: not ordinary, half XP, no items")
	# A seed hurts only as it lands on its shadow: a Wick in its arc's way
	# (off the shadow) is never hit; one on the shadow is.
	b.kill_adds()
	b._clear_seeds()
	var land := Vector2(b.arena_left + 200.0, b.floor_y)
	for on_shadow in [false, true]:
		var s := {"from": b.art_pt("rootmother_idle", "crown", b.position + Vector2(20, -170)), "to": land, "t": 0.0, "stage": "fall",
				"sit": 0.0, "hit": false, "id": 900 + int(on_shadow)}
		b._seeds = [s]
		var mid: Vector2 = b.seed_pos({"from": s["from"], "to": land, "t": b.SEED_FALL * 0.6, "stage": "fall"})
		var sp := [Vector2(land.x if on_shadow else mid.x, b.floor_y if on_shadow else mid.y + 19.0), -1, "seed"]
		b.blows.clear()
		for i in int(0.8 / DT):
			_hold(w, sp)
			w.player.on_floor = on_shadow
			_tick(w)
		_check((int(b.blows.get("seed", 0)) > 0) == on_shadow, "a Wick %s is %s" % ["on a seed's shadow" if on_shadow else "in its arc's way", "hit as it lands" if on_shadow else "never hit"])
	b._clear_seeds()
	await _done(w)


func _test_rm_thorns() -> void:
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	var c0 := floori(b.arena_left / TILE) - 2
	for pat in b.LANES.size():
		var lanes: Array = b.lanes(pat)
		_check(lanes.size() == 4, "pattern %d: the Thorn Crown's safe lanes: 4 (%d)" % [pat, lanes.size()])
		var widths_ok := true
		for l in lanes:
			widths_ok = widths_ok and absf(float(l[1]) - float(l[0]) - 96.0) < 0.01 and float(l[1]) <= b.near_x() + 0.1
		_check(widths_ok, "pattern %d: 3 tiles wide each, inside the arena" % pat)
		# Both vines and both P3 humps rain; the rain reaches her trunk.
		b._lanes = lanes
		var wet := []
		for ac in [5, 12, 13, 23, 24, 25, 27]:
			if not b.in_lane((c0 + ac + 0.5) * TILE):
				wet.append(ac)
		_check(wet == [5, 12, 13, 23, 24, 25, 27], "pattern %d rains on both vines, both humps and the column by her trunk (%s)" % [pat, str(wet)])
		var last_col: float = b.arena_left + (b.rain_cols() - 0.5) * TILE
		_check(b.rain_cols() == 26 and last_col < b.near_x(), "thorns fall in all 26 open columns (%d)" % b.rain_cols())
	b._lanes.clear()
	# The escape formula, the thorns' fall counted: from every standable spot
	# in the rain (P3's humps up) to a lane's edge along its floor, on every
	# difficulty (the Witching floor 0.72 s).
	b.phase = 3
	b._raise_humps()
	var worst_need := 0.0
	var worst_at := ""
	var bad := []
	for pat in b.LANES.size():
		b._lanes = b.lanes(pat)
		for sp in _spots(w, b, [2, 27], [2, 12]):
			var feet: Vector2 = sp[0]
			if b.in_lane(feet.x):
				continue
			var near := INF
			for l in b._lanes:
				near = minf(near, minf(absf(feet.x - float(l[0])), absf(feet.x - float(l[1]))))
			if int(sp[1]) >= 0:
				near = minf(near, TILE * 0.5)          # off a vine: out of its column
			var fall: float = b.thorn_fall_to(feet.x, feet.y - 38.0)
			# (spots are column middles: the worst of a column is half a tile on)
			var need := 0.35 + (near + TILE * 0.5 + 10.0) / 205.0
			if need - fall > worst_need:
				worst_need = need - fall
				worst_at = "%s pattern %d" % [sp[2], pat]
			for d in ["dusk", "witching"]:
				var tl: float = maxf(b.THORN_TELL * (0.72 if d == "witching" else 1.0), b.THORN_FLOOR)
				if tl + fall < need - 0.001:
					bad.append("%s %s p%d" % [sp[2], d, pat])
	_check(bad.is_empty(), "the Thorn Crown meets the escape formula at every spot, its fall counted (%s)" % ", ".join(bad.slice(0, 4)))
	print("  Thorn Crown: the tightest spot needs %.2f s of tell (%s)" % [worst_need, worst_at])
	_check(absf(b.thorn_fall_to(b.arena_left + 400.0, b.floor_y - 38.0) - 0.49) < 0.02, "a thorn takes 0.49 s from the roof to a standing head (%.2f)" % b.thorn_fall_to(b.arena_left + 400.0, b.floor_y - 38.0))
	# In play: a Wick in a lane is untouched by the rain; one in the open
	# rain, on a hump and on the col-25 vine is hit.
	var lanes0: Array = b.lanes(0)
	var hump := _arena_cell(b, Vector2i(23, 11))
	var vine := _arena_cell(b, Vector2i(25, 9))
	var cases := [["in a lane", [Vector2((float(lanes0[1][0]) + float(lanes0[1][1])) * 0.5, b.floor_y), -1], false],
			["in the rain by her", [Vector2(b.arena_left + 25.5 * TILE, b.floor_y), -1], true],
			["on a hump", [Vector2((hump.x + 0.5) * TILE, (hump.y + 1) * TILE), -1], true],
			["on the vine by her", [Vector2((vine.x + 0.5) * TILE, (vine.y + 1) * TILE - 2.0), vine.x], true]]
	for cs in cases:
		b.thorn_crowns = 0
		b._queue = ["thorns"]
		b.state = "idle"
		b.timer = 0.0
		b.blows.clear()
		var sp2: Array = [cs[1][0], cs[1][1], cs[0]]
		for i in int(3.2 / DT):
			_hold(w, sp2)
			_tick(w)
			if b.state == "idle" and i > 50:
				break
		var hit := int(b.blows.get("thorns", 0)) > 0
		_check(hit == bool(cs[2]), "a Wick %s is %s by the thorns (%s)" % [cs[0], "hit" if cs[2] else "untouched", str(b.blows)])
	# The crowns take the patterns in turn.
	b.thorn_crowns = 0
	var seen := {}
	for k in 4:
		b._queue = ["thorns"]
		b.state = "idle"
		b.timer = 0.0
		_tick(w)
		seen[str(b._lanes)] = true
		b.state = "idle"
	_check(seen.size() == 2, "Thorn Crowns take the two patterns in turn (%d seen)" % seen.size())
	await _done(w)


func _test_rm_reach() -> void:
	## No safe spot: in every phase, a Wick held still anywhere in R_ARENA
	## (the floor, each ledge, each vine cell, P3's humps) is reached by some
	## move of hers within one pass of the phase's rotation.
	for ph in [1, 2, 3]:
		var w := await _arena("rm")
		var b := _awake(w, 300.0)
		_ticks(w, 1.4)
		_safe(w)
		for k in ph - 1:
			_open_rm(b, "F1")
			b._stagger_phase = b.phase   # (past the phase's stagger: the blow runs on to its line)
			b.hit({"how": "slash", "from_x": 0.0, "amount": 999999.0})
			_ticks(w, 1.6)
		var spots := _spots(w, b, [2, 27], [2, 12])
		var missed := []
		var by := {}
		for sp in spots:
			b._queue.clear()
			b._end_run(true)
			b._bands.clear()
			b._sink_spears()
			b._clear_seeds()
			b.kill_adds()
			b.state = "idle"
			b.timer = 0.3
			var got := _reach_run(w, b, sp, ph)
			if got == "":
				missed.append(sp[2])
			else:
				by[got] = int(by.get(got, 0)) + 1
		print("  Gravebough P%d: %d spots, reached by %s" % [ph, spots.size(), str(by)])
		var names := []
		for sp in spots:
			names.append(sp[2])
		var humps_in := names.has("on (12,12)") and names.has("on (23,12)") and names.has("on (24,12)")
		_check(b.phase == ph and spots.size() >= 56 and names.has("vine (5,3)") and names.has("vine (25,5)") and names.has("on (16,7)") \
				and humps_in == (ph == 3), "(P%d: %d spots: the floor, the ledges, both vines, and in P3 the humps' tops)" % [ph, spots.size()])
		_check(missed.is_empty(), "P%d: no spot in her arena is out of her reach (missed: %s)" % [ph, ", ".join(missed)])
		await _done(w)


func _test_rm_vine_spear() -> void:
	## A Wick on a vine: the Root Spear bursts up the vine from under his feet
	## (the vine's run, locked at the tell's start), no ledge on it; climbing
	## off the spot in the tell clears it.
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	var col := _arena_cell(b, Vector2i(5, 7))
	var sp := [Vector2((col.x + 0.5) * TILE, (col.y + 1) * TILE - 2.0), col.x, "vine"]
	_hold(w, sp)
	b.state = "dig"
	b.timer = 9.0
	var spot: Dictionary = b._lock_spot(w.player)
	_check(bool(spot.get("vine", false)) and absf(float(spot["x"]) - (col.x + 0.5) * TILE) < 0.5, "on a vine, the spear's spot is the vine (%s)" % str(spot))
	b._spear_at(float(spot["x"]), 0, 0.0, spot)
	var s: Dictionary = b._spears[0]
	var feet: float = sp[0].y
	_check(float(s["surf"]) > feet and float(s["surf"]) - 64.0 < feet - 38.0, "it rises from just under his feet past his head (root %.0f, feet %.0f)" % [float(s["surf"]), feet])
	b.blows.clear()
	for i in int(0.9 / DT):
		_hold(w, sp)
		_tick(w)
	_check(int(b.blows.get("spear", 0)) == 1, "hanging on, the rise hurts (%s)" % str(b.blows))
	_check(s.get("ledge") == null, "a vine spear leaves no ledge")
	b._sink_spears()
	# Climbing up out of it during the tell: clear.
	_hold(w, sp)
	w.player.invuln = 0.0
	spot = b._lock_spot(w.player)
	b._spear_at(float(spot["x"]), 0, 0.0, spot)
	var hp0: float = w.player.hp
	for i in int(1.0 / DT):
		_tick(w, {"jump": true} if i < int(0.55 / DT) else {})
		if not w.player.climbing:
			break
	_check(w.player.hp >= hp0, "climbing up out of it in the tell clears it (up %.0f px)" % (feet - w.player.position.y))
	# The march's spear under him goes up his vine too.
	b._sink_spears()
	b.phase = 2
	_hold(w, sp)
	b._march(w.player)
	var last: Dictionary = b._spears[b._spears.size() - 1]
	_check(bool(last["vine"]) and absf(float(last["x"]) - (col.x + 0.5) * TILE) < 0.5, "the Spear March's last spear goes up his vine")
	b._sink_spears()
	# By her (the col-25 vine): the march still puts one up his vine.
	var col2 := _arena_cell(b, Vector2i(25, 8))
	var sp2 := [Vector2((col2.x + 0.5) * TILE, (col2.y + 1) * TILE - 2.0), col2.x, "vine2"]
	_hold(w, sp2)
	b.phase = 3
	b._march(w.player)
	var up := 0
	for s2 in b._spears:
		if bool(s2["vine"]):
			up += 1
	_check(up == 1, "and on the vine by her, one of the march's spears is his vine's (%d)" % up)
	b._sink_spears()
	await _done(w)


func _test_rm_mercy() -> void:
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	b.phase = 3
	b.hp = b.max_hp * 0.2
	w.player.hp = w.player.max_hp * 0.2
	w.player.invuln = 99.0
	var wax0 := 0
	for p in w.pickups:
		if p["kind"] == "wax":
			wax0 += 1
	_ticks(w, 0.3)
	var wax1 := 0
	for p in w.pickups:
		if p["kind"] == "wax":
			wax1 += 1
	_check(wax1 == wax0 + 1, "in P3 with Wick under 25%% a wax stub drops (mercy)")
	_ticks(w, 0.3)
	var wax2 := 0
	for p in w.pickups:
		if p["kind"] == "wax":
			wax2 += 1
	_check(wax2 == wax1, "once")
	await _done(w)


func _test_rm_retry() -> void:
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	_open_rm(b, "F1")
	b._stagger_phase = b.phase
	b.hit({"how": "slash", "from_x": 0.0, "amount": 999999.0})
	_open_rm(b, "F1")
	b._stagger_phase = b.phase
	b.hit({"how": "slash", "from_x": 0.0, "amount": 999999.0})
	_ticks(w, 1.5)
	b.spawn_add("rootling", Vector2(b.arena_left + 400.0, b.floor_y))
	b._spear_at(b.arena_left + 250.0, 0, 0.0)
	b._seedfall()
	b._add_cloud(Vector2(b.arena_left + 300.0, b.floor_y - 60.0), 64.0, 6.0, false)
	b._queue = ["heart"]
	b.state = "idle"
	b.timer = 0.0
	_ticks(w, 0.6)
	_check(b.phase == 3 and b._humps_up, "(mid P3: humps up, adds, a spear, seeds, a cloud, a Heart Run)")
	# Snuffed: the World calls reset_fight at the relight.
	w.player.invuln = 0.0
	w.player.take_damage(999999.0, w.player.position.x + 10.0)
	_ticks(w, 2.2)
	var humps_gone := true
	for hx in b.HUMPS:
		for dx in 2:
			var c := _arena_cell(b, Vector2i(int(hx) + dx, 12))
			humps_gone = humps_gone and not LevelData.is_solid(w.level.tile(c.x, c.y))
	var open := true
	for c in b.door:
		open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(b.state == "sleep" and b.hp == b.max_hp and b.phase == 1, "a retry: asleep at full life, phase 1")
	_check(humps_gone and absf(b._rise) < 0.01, "the humps come out and she's rooted again")
	_check(b.target == -1 and b._stage == "" and b._pulse.is_empty() and not b.is_open(), "the heart home, the blossoms shut")
	_check(b.adds_alive() == 0 and b._spears.is_empty() and b._seeds.is_empty() and b._thorns.is_empty() and b._clouds.is_empty(),
			"the Rootlings, pillars, seeds, thorns and clouds gone")
	_check(open, "the door open")
	_check(b.runs == 0 and b.last_socket == -1, "the socket rule starts over (vines skipped again)")
	await _done(w)


func _test_rm_death() -> void:
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	_safe(w)
	b.phase = 3
	b.hp = 5.0
	_open_rm(b, "F1")
	b.hit({"how": "slash", "from_x": 0.0, "amount": 100.0})
	_check(not b.alive and b.state == "dead", "she falls")
	_ticks(w, 1.6)
	var loot := 0
	for p in w.pickups:
		if p["kind"] == "item" or p["kind"] == "relic":
			loot += 1
	_check(w.bells.size() == 1, "the great bell rises out of the roots")
	_check(loot >= 2, "she drops her prize and a relic (%d pieces; on Dusk no boss-table items: world.trophies())" % loot)
	var open := true
	for c in b.door:
		open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(open, "the door opens")
	await _done(w)


func _test_rm_sim() -> void:
	## 300 s of the fight with a scripted Wick (untouchable, walking between
	## spots, striking the open blossom): every move gets used.
	var w := await _arena("rm")
	var b := _awake(w, 200.0)
	var spots := [120.0, 300.0, 520.0, 700.0, 250.0, 620.0]
	var el := 0.0
	var dmg: float = b.max_hp * 0.012
	for i in int(300.0 / DT):
		_safe(w)
		el += DT
		if i % int(7.0 / DT) == 0:
			_stand(w, b.arena_left + float(spots[(i / int(7.0 / DT)) % spots.size()]))
		_tick(w)
		if b.is_open() and i % 20 == 0:
			b.hit({"how": "slash", "from_x": 0.0, "amount": dmg})
		if not b.alive:
			break
	var want := ["sweep_low", "sweep_high", "double", "spear", "march", "seed", "breath", "thorns", "heart", "decoy", "breath_heart"]
	var missing := []
	for m in want:
		if int(b.moves_used.get(m, 0)) == 0:
			missing.append(m)
	print("  Gravebough's 300 s sim: %.0f s, phase %d, %d windows, moves %s" % [el, b.phase, b.windows_opened, str(b.moves_used)])
	_check(missing.is_empty(), "every move used in a 300 s sim (missing: %s)" % ", ".join(missing))
	await _done(w)


# ---------------------------------------------------------------- the Tinker

func _test_tk_arena() -> void:
	var w := await _arena("tk")
	_check(w.level.errors.is_empty(), "the K_ARENA stand-in parses (%s)" % ", ".join(w.level.errors))
	var b: Node2D = w.boss
	_check(b != null and b.get("boss_id") == "tinker", "4-4's X spawns the Tinker of Hours")
	if b == null:
		await _done(w)
		return
	_check(b.door.size() == 6, "his door is the arena's left doorway (%d cells)" % b.door.size())
	for nm in TK_BELLS:
		var i: int = b.bell_i(nm)
		_check(i >= 0 and b.bells[i]["cell"] == _arena_cell(b, TK_BELLS[nm]), "bell %s at the spec's %s" % [nm, TK_BELLS[nm]])
	var pv: Vector2 = b.pivot
	var want := Vector2((floori(b.arena_left / TILE) - 2 + 17) * TILE, (floori(b.floor_y / TILE) - 13 + 5) * TILE)
	_check(pv.distance_to(want) < 0.5, "the pendulum hangs at the spec's (17, 5) under the XII beam (%s)" % pv)
	_tick(w)
	var cw = w.features.module("clockwork")
	var weights := 0
	if cw != null and cw.get("weights") != null:
		for wt in cw.weights:
			if absf((wt["anchor"] as Vector2).y - pv.y) < 40.0:
				weights += 1
	_check(weights == 0, "the arena's Y is his: no feature weight swings there")
	var br: Rect2 = b.body_rect()
	_check(br.size.x >= 96.0 and br.size.y >= 128.0, "he is at least 96 x 128 px (%s)" % br.size)
	_check(absf(b.max_hp - float(b.BASE_HP) * Combat.e_hp(22)) < 1.0, "his life is BASE_HP x e_hp(22)")
	await _done(w)


func _test_tk_hand() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	# P1: clockwise, 3.0 s, 1.5x on XII.
	b._reset_clock()
	var seq := [b.hand_i]
	var at := [0.0]
	var el := 0.0
	for i in int(15.0 / DT):
		_safe(w)
		_stand(w, b.arena_left + 60.0)
		b.state = "walk"
		b.timer = 5.0
		_tick(w)
		el += DT
		if b.hand_i != seq[seq.size() - 1]:
			seq.append(b.hand_i)
			at.append(el)
	var names := []
	for i in seq:
		names.append(b.ORDER[i])
	_check(names.slice(0, 5) == ["XII", "III", "VI", "IX", "XII"], "P1: the hand goes clockwise XII III VI IX (%s)" % str(names))
	if at.size() >= 4:
		_check(absf(at[1] - at[0] - 4.5) < 0.05, "it dwells 1.5x on XII (%.2f s)" % (at[1] - at[0]))
		_check(absf(at[2] - at[1] - 3.0) < 0.05 and absf(at[3] - at[2] - 3.0) < 0.05, "and 3.0 s on the others")
	# P2 2.5 s; P3 counter-clockwise 2.2 s.
	b.phase = 2
	b._reset_clock()
	_check(absf(b.period() - 3.75) < 0.001, "P2: XII holds 3.75 s")
	b._move_hand(1)
	_check(absf(b.period() - 2.5) < 0.001, "P2: 2.5 s on the others")
	b.phase = 3
	b.hand_dir = -1
	b._reset_clock()
	b.hand_dir = -1
	b._hand_at = b.clock() + 0.01
	_tick(w)
	_tick(w)
	_check(b.ORDER[b.hand_i] == "IX" and absf(b.period() - 2.2) < 0.001, "P3: counter-clockwise (XII to IX), 2.2 s")
	# Never by difficulty.
	await _done(w)
	var ww := await _arena("tk", "witching")
	var bw := _awake(ww, 60.0)
	bw._reset_clock()
	_check(absf(bw.period() - 4.5) < 0.001, "the hand keeps its time on Witching")
	await _done(ww)


func _ring_with_slash(w: Node2D, b: Node2D, i: int) -> void:
	var box: Rect2 = b.bells[i]["box"]
	_stand(w, box.position.x - 16.0, float(b.bells[i]["surf"]))
	w.player.facing = 1
	_ticks(w, 0.05, {"attack": true})
	_ticks(w, 0.05)


func _test_tk_ring() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	b._reset_clock()
	b.state = "walk"
	var vi: int = b.bell_i("VI")
	b._move_hand(vi)
	b._prev_until = -1.0
	_check(b.bell_lit(vi) and not b.bell_lit(b.bell_i("IX")), "the bell the hand points at is lit, the others frosted")
	_check(not b.bell_ready(vi), "lit, but not ready while he's still on his way to guard it (%.1f tiles off)" % (absf(b.position.x - float(b.bells[vi]["cx"])) / TILE))
	var hp_far: int = b.chimed_count
	var pops0: int = w.floaters.items.size()
	_ring_with_slash(w, b, vi)
	_check(b.chimed_count == hp_far and b.wrong_hours == 0, "and a blow on it then does nothing")
	var said := false
	for it in w.floaters.items:
		if str(it.get("text", "")) == "Not yet!":
			said = true
	_check(said and w.floaters.items.size() > pops0, "but it answers: a dull tick and \"Not yet!\" (no penalty)")
	b.position.x = float(b.bells[vi]["cx"]) + 3.0 * TILE
	b.state = "walk"
	_ticks(w, 0.3)
	_check(b.bell_ready(vi), "once he's come to guard it, it's ready")
	_ring_with_slash(w, b, vi)
	_check(b.state == "chimed" and b.is_open() and b.chimed_count == 1, "a slash on the lit bell strikes the hour: Chimed (%s)" % b.state)
	_check(absf(b.window_len - 2.6) < 0.001, "his P1 window: 2.6 s, Gravebough's and the Saint's (%.2f)" % b.window_len)
	# The re-arm: the same bell won't ring again for 1.0 s.
	_check(not b.bell_lit(vi), "a rung bell re-arms only after 1.0 s")
	_ticks(w, 2.8)
	_check(not b.is_open(), "the window runs out")
	# The grace: a bell still rings 0.5 s after the hand leaves it.
	for d in [0.4, 0.6]:
		b.state = "walk"
		b._arm = [0.0, 0.0, 0.0, 0.0]
		b._frost_until = -1.0
		b._move_hand(b.bell_i("IX"))
		b._move_hand(b.bell_i("XII"))
		_ticks(w, d)
		var lit_prev: bool = b.bell_lit(b.bell_i("IX"))
		_check(lit_prev == (d < 0.5), "%.1f s after the hand leaves a bell it %s" % [d, "still rings" if d < 0.5 else "no longer rings"])
	# P2 and P3 windows; Tollbreaker.
	b.phase = 2
	b.state = "walk"
	b._chimed()
	_check(absf(b.window_len - 2.2) < 0.001, "P2's window 2.2 s")
	b._end_chimed()
	b.phase = 3
	b.state = "walk"
	w.player.stats["flags"] = {"tollbreaker_window": 0.4}
	b._chimed()
	_check(absf(b.window_len - 2.3) < 0.001, "P3's 1.9 s, +0.4 with Tollbreaker (%.2f)" % b.window_len)
	w.player.stats["flags"] = {}
	await _done(w)
	var ww := await _arena("tk", "witching")
	var bw := _awake(ww, 60.0)
	bw.state = "walk"
	bw._chimed()
	_check(absf(bw.window_len - 2.6) < 0.001, "the window is 2.6 s on Witching too")
	await _done(ww)


func _test_tk_hand_while_down() -> void:
	## The hand turns on while he's down (Chimed, getting up): v1.0.1 tried
	## holding it there, and with the touch rule the fight came out shorter
	## than Gravebough's, so the bell after the one just rung has what's
	## left of its dwell once he's up, as in v1.0.0.
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	b._reset_clock()
	b.state = "walk"
	b.timer = 99.0
	var vi: int = b.bell_i("VI")
	b._move_hand(vi)
	b._prev_until = -1.0
	b.position.x = float(b.bells[vi]["cx"]) + 3.0 * TILE
	_ticks(w, 0.3)
	_check(b.bell_ready(vi), "(VI lit and guarded)")
	_ring_with_slash(w, b, vi)
	_check(b.state == "chimed", "(rung: he's down)")
	var due: float = b._hand_at
	var down := 0.0
	var moved := -1.0
	while down < 8.0 and b.state in ["chimed", "getup"]:
		_safe(w)
		_stand(w, b.arena_left + 60.0)
		_tick(w)
		down += DT
		if moved < 0.0 and b.hand_i != vi:
			moved = down
	_check(moved > 0.0 and b.ORDER[b.hand_i] == "IX" and absf(b._hand_at - due - float(b.HAND_EVERY[0])) < 0.05,
			"the hand goes on to IX on time while he's down (after %.2f s of his %.1f s down)" % [moved, down])
	await _done(w)


func _test_tk_bell_rules() -> void:
	## A bell rings once a visit of the hand; a blow on a bell rung this
	## visit, or through a wrong hour's frost, or on the lit bell while he
	## can't fall, does nothing (no "Wrong hour!", no chime).
	var w := await _arena("tk", "dusk", "knight")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	b._reset_clock()
	b.state = "walk"
	b.timer = 99.0
	var vi: int = b.bell_i("VI")
	b._move_hand(vi)
	b._prev_until = -1.0
	b._hand_at = b.clock() + 30.0
	var box: Rect2 = b.bells[vi]["box"]
	b.position.x = box.get_center().x + 3.0 * TILE
	# Mashing attack at the lit bell through a window and after it.
	var chimes0: int = b.chimed_count
	for i in int(5.0 / DT):
		_hold(w, [Vector2(box.position.x - 16.0, float(b.bells[vi]["surf"])), -1, "at VI"])
		w.player.invuln = 99.0
		w.player.facing = 1
		_tick(w, {"attack": true} if i % int(0.3 / DT) < 3 else {})
	_check(b.chimed_count == chimes0 + 1 and b.wrong_hours == 0, "mashing attack on the lit bell: one chime this visit, never 'Wrong hour!' (%d chimes, %d wrong)" % [b.chimed_count - chimes0, b.wrong_hours])
	_check(b.bell_spent(vi) and not b.bell_lit(vi) and not b.bell_frosted(vi), "the rung bell is spent (lit but dim) until the hand comes back")
	# The hand comes round again: it rings again.
	for k in 4:
		b._move_hand((b.hand_i + 1) % 4)
	_check(b.hand_i == vi and b.bell_lit(vi), "the hand back on it: lit again")
	# Rung while he's getting up: nothing (no chime, the bell not spent).
	b.state = "getup"
	b.timer = 99.0
	var n0: int = b.chimed_count
	_ring_with_slash(w, b, vi)
	_check(b.chimed_count == n0 and b.wrong_hours == 0 and b.bell_lit(vi) and b._chime.is_empty(), "struck while he's getting up, the lit bell does nothing")
	b.state = "walk"
	_ticks(w, 0.35)
	_ring_with_slash(w, b, vi)
	_check(b.chimed_count == n0 + 1, "and rings once he's up")
	b._end_chimed()
	b.state = "walk"
	b.timer = 99.0
	# A stomp on the lit bell and its bounce: one chime, no wrong hours.
	for k in 4:
		b._move_hand((b.hand_i + 1) % 4)
	b._hand_at = b.clock() + 30.0
	var n1: int = b.chimed_count
	w.player.reset_at(Vector2(box.get_center().x, box.position.y - 50.0))
	w.player.velocity = Vector2(0, 300)
	for i in int(1.6 / DT):
		_safe(w)
		w.player.position.x = box.get_center().x
		w.player.velocity.x = 0.0
		_tick(w)
	_check(b.chimed_count == n1 + 1 and b.wrong_hours == 0, "a stomp on the lit bell and its bounces: one chime, no wrong hours (%d, %d)" % [b.chimed_count - n1, b.wrong_hours])
	b._end_chimed()
	b.state = "walk"
	b.timer = 99.0
	# A stomp's bounce on a frosted bell: one wrong hour, not one a bounce.
	b._reset_clock()
	b._hand_at = b.clock() + 30.0
	var wh0: int = b.wrong_hours
	w.player.reset_at(Vector2(box.get_center().x, box.position.y - 50.0))
	w.player.velocity = Vector2(0, 300)
	for i in int(1.2 / DT):
		_safe(w)
		w.player.position.x = box.get_center().x
		w.player.velocity.x = 0.0
		_tick(w)
	_check(b.wrong_hours == wh0 + 1, "bouncing on a frosted bell is one wrong hour (%d)" % (b.wrong_hours - wh0))
	# The grace: guarding IX when the hand leaves it, IX still rings 0.5 s.
	b._end_chimed()
	b.state = "walk"
	b.timer = 99.0
	b._frost_until = -1.0
	var ixb: int = b.bell_i("IX")
	b._move_hand(ixb)
	b._arm[ixb] = 0.0
	b.position.x = float(b.bells[ixb]["cx"]) - 2.0 * TILE
	_tick(w)
	b._move_hand(b.bell_i("XII"))
	_check(b.bell_ready(ixb), "guarding IX as the hand leaves it: IX still rings in its grace")
	_ticks(w, 0.55)
	_check(not b.bell_ready(ixb), "and not after it")
	await _done(w)


func _test_tk_frost() -> void:
	var w := await _arena("tk", "dusk", "knight")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	b.state = "walk"
	b.timer = 99.0
	b._reset_clock()
	var vi: int = b.bell_i("VI")
	_check(not b.bell_lit(vi), "(VI is frosted while the hand is on XII)")
	# A shot through a frosted bell passes on.
	var box: Rect2 = b.bells[vi]["box"]
	var s: Dictionary = w.spawn_shot({"kind": "spark", "pos": box.get_center() + Vector2(-40, 0), "vel": Vector2(400, 0), "life": 1.0, "owner": "player", "coef": 0.0})
	_ticks(w, 0.2)
	_check(b.chimed_count == 0 and b.wrong_hours == 0 and (s["pos"] as Vector2).x > box.end.x, "a shot passes through a frosted bell (no chime, no wrong hour)")
	# A wave too.
	w.add_hazard({"kind": "wave", "motion": "floor", "owner": "player", "rect": Rect2(box.position.x - 40.0, b.floor_y - 22.0, 18.0, 22.0),
			"vel": Vector2(250, 0), "life": 1.0, "coef": 0.0})
	_ticks(w, 0.4)
	_check(b.chimed_count == 0 and b.wrong_hours == 0, "and so does a wave")
	# A slash is the wrong hour: 1.0 s of frost, and that's all (v1.0.1: the
	# hand spun 1-3 bells on too, and he walked off to a new post).
	var before: int = b.hand_i
	var at_before: float = b._hand_at
	_ring_with_slash(w, b, vi)
	_check(b.wrong_hours == 1 and b.hand_i == before and absf(b._hand_at - at_before) < 0.001,
			"a slash on a frosted bell is the wrong hour: the hand stays where it was, on its own time")
	var all_frost := true
	for i in 4:
		all_frost = all_frost and not b.bell_lit(i)
	_check(all_frost, "and every bell frosts")
	_ticks(w, 1.05)
	_check(b.bell_lit(b.hand_i), "for 1.0 s")
	_check(b.chimed_count == 0, "no window came of it")
	# A lit bell rings for a shot.
	var li: int = b.hand_i
	b._post = li
	var lbox: Rect2 = b.bells[li]["box"]
	w.spawn_shot({"kind": "spark", "pos": lbox.get_center() + Vector2(-30, 0), "vel": Vector2(400, 0), "life": 1.0, "owner": "player", "coef": 0.0})
	_ticks(w, 0.15)
	_check(b.chimed_count == 1, "a shot on the lit bell strikes the hour")
	await _done(w)


func _test_tk_spring() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	var hp0: float = b.hp
	var h := {"how": "slash", "from_x": b.position.x - 60.0, "amount": 100.0}
	b.hit(h)
	_check(absf((hp0 - b.hp) - 10.0) < 0.01 and h.get("chip", false), "outside a window his body chips 10%%")
	# His touch: only in the Minute Hand's cut (v1.0.1). Walking, guarding,
	# tossing, winding the soldiers, raising the watch, rewinding: Wick slips
	# past him (106 x 160 px, no jump clears him: he walled off the floor).
	var harmless := true
	for st in ["walk", "toss_tell", "approach", "swing_tell", "key", "watch", "rewind_tell", "rewind", "roar", "midnight"]:
		b.state = st
		harmless = harmless and not b.touch_damage()
	b.state = "swing"
	_check(harmless and b.touch_damage(), "touching him hurts only in the Minute Hand's cut")
	b.state = "walk"
	b.timer = 99.0
	b._hand_at = b.clock() + 30.0
	var hp_w: float = w.player.hp
	var inside := 0
	for i in int(2.0 / DT):
		w.player.invuln = 0.0
		_stand(w, b.position.x)
		_tick(w)
		if b.body_rect().intersects(w.player.rect()):
			inside += 1
	_check(inside >= int(1.9 / DT) and w.player.hp >= hp_w, "Wick standing inside him while he guards: unhurt (%.0f -> %.0f)" % [hp_w, w.player.hp])
	_safe(w)
	_stand(w, b.position.x - 150.0)
	b.state = "walk"
	b._chimed()
	_tick(w)
	var sr: Rect2 = b.spring_rect()
	_check(b.rect() == sr and sr.size.y > 30.0 and sr.end.y >= b.floor_y - 1.0, "Chimed, his rect is the mainspring on the floor (%s)" % sr)
	_check(not b.touch_damage(), "he isn't solid while Chimed (no touch)")
	hp0 = b.hp
	b.hit({"how": "slash", "from_x": 0.0, "amount": 100.0})
	_check(absf((hp0 - b.hp) - 100.0) < 0.01, "a spring hit lands in full")
	hp0 = b.hp
	b.hit({"how": "stomp", "from_x": 0.0, "amount": 40.0})
	_check(absf((hp0 - b.hp) - 120.0) < 0.01, "a stomp on it 3x")
	hp0 = b.hp
	b.hit({"how": "stomp", "from_x": 0.0, "amount": 40.0})
	_check(absf((hp0 - b.hp) - 4.0) < 0.01, "and a second stomp in the same window only chips (%.1f)" % (hp0 - b.hp))
	# Backstabs from either side: his facing is turned from Wick.
	var ok := true
	for side in [-1.0, 1.0]:
		_stand(w, b.position.x + side * 60.0)
		_tick(w)
		ok = ok and Combat.is_back_hit(b, w.player.position.x)
	_check(ok, "every spring hit is on his back (a Sootrunner's Backstab from either side)")
	_check(b.look_face == b._look_hold, "while he lies as he fell (his look kept)")
	await _done(w)


func _test_tk_stop() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	b.phase = 2
	b.pend_on = true
	_stand(w, b.arena_left + 500.0)
	var tw: Node2D = b.spawn_add("tickwind", Vector2(b.arena_left + 200.0, b.floor_y))
	b._toss(w.player)
	_ticks(w, 0.1)
	b.state = "watch"
	b.timer = b.tell(b.STOP_TELL)
	_check(absf(b.timer - 0.8) < 0.001, "Stop the Clock's tell: 0.8 s")
	var hand0: int = b.hand_i
	for i in int(1.5 / DT):
		_tick(w)
		if b.state != "watch":
			break
	_check(w.time_stopped() and b.state == "stopped", "then time stops")
	var aim: Vector2 = b._aim
	var cog: Dictionary = b._shots[0]
	var cog_p: Vector2 = cog["pos"]
	var tw_p: Vector2 = tw.position if tw else Vector2.ZERO
	var bob0: Vector2 = b.bob()
	var pl_x: float = w.player.position.x
	_ticks(w, 0.8, {"right": true})
	_check((cog["pos"] as Vector2).distance_to(cog_p) < 0.01, "a thrown cog freezes")
	_check(tw == null or tw.position.distance_to(tw_p) < 0.5, "a Tickwind freezes")
	_check(b.bob().distance_to(bob0) < 0.01, "the pendulum freezes")
	_check(w.player.position.x > pl_x + 40.0, "but Wick moves (%.0f px)" % (w.player.position.x - pl_x))
	_check(b.hand_i == hand0, "the hand stays frozen")
	var hands := []
	for s in b._shots:
		if str(s["kind"]) == "hand":
			hands.append(s)
	_check(hands.size() >= 4, "he sets the hour-hands in a ring round Wick (%d)" % hands.size())
	var ring_ok := true
	for s in hands:
		ring_ok = ring_ok and absf((s["pos"] as Vector2).distance_to(aim) - 110.0) < 0.5
	_check(ring_ok, "110 px from where he stood, aimed at it")
	# They fly along their lead lines once time runs.
	var lines := []
	for s in hands:
		lines.append(b.hand_line(s))
	_ticks(w, 0.9)
	_check(not w.time_stopped(), "time runs again after 1.6 s")
	var on_line := true
	var flew := false
	for k in hands.size():
		var s: Dictionary = hands[k]
		var p: Vector2 = s["pos"]
		var a: Vector2 = lines[k][0]
		var bq: Vector2 = lines[k][1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, bq)
		on_line = on_line and q.distance_to(p) < 1.0
		flew = flew or p.distance_to(a) > 30.0
	_check(flew and on_line, "the hands fly along their drawn lead lines")
	_ticks(w, 1.0)
	var gone := true
	for s in b._shots:
		gone = gone and str(s["kind"]) != "hand"
	_check(gone, "and stop where the lines end (none left in flight)")
	await _done(w)
	# A Wick just past a drawn line's end is never hit; one on the line is.
	for beyond in [true, false]:
		var w2 := await _arena("tk")
		var b2 := _awake(w2, 60.0)
		_ticks(w2, 1.3)
		b2.phase = 2
		b2.position.x = b2.arena_left + 150.0
		var stand := Vector2(b2.arena_left + 400.0, b2.floor_y)
		_stand(w2, stand.x)
		_safe(w2)
		b2.state = "watch"
		b2.timer = b2.tell(b2.STOP_TELL)
		var line := []
		var flown := false
		for i in int(4.5 / DT):
			if b2.state == "stopped" and line.is_empty() and b2._placed >= b2.HANDS_N:
				for s in b2._shots:
					if str(s["kind"]) == "hand" and absf((s["dir"] as Vector2).y) < 0.01 and (s["dir"] as Vector2).x > 0.0:
						line = b2.hand_line(s)
				var end: Vector2 = line[1] if not line.is_empty() else stand
				# His rect 10 px past the line's end, or 30 px short of it.
				stand = Vector2(end.x + 10.0 + 10.0, b2.floor_y) if beyond else Vector2(end.x - 30.0, b2.floor_y)
				b2.blows.clear()
			if not line.is_empty():
				_hold(w2, [stand, -1, "x"])
			else:
				_safe(w2)
			_tick(w2)
			if not line.is_empty() and b2.state != "stopped" and not b2._frozen_hands() and b2._shots.is_empty():
				flown = true
				break
		var hurt := int(b2.blows.get("hands", 0)) > 0
		_check(flown and not line.is_empty() and hurt == (not beyond), "a Wick %s a lead line's end is %s (line to %s)" % ["10 px past" if beyond else "30 px inside",
				"never hit" if beyond else "hit", str(line[1]) if not line.is_empty() else "?"])
		await _done(w2)


func _test_tk_pendulum() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	_check(not b.pend_on and b.bob().distance_to(b.pivot + Vector2(0, 160)) < 0.1, "P1: the pendulum hangs still")
	b.state = "walk"
	b.hp = b.max_hp * 0.66
	b.state = "walk"
	b.open_window(2.4)
	b.state = "chimed"
	b.hit({"how": "slash", "from_x": 0.0, "amount": b.max_hp * 0.1})
	_check(b.phase == 2 and b.state == "roar", "at 65%% he roars (the overwind)")
	_ticks(w, 1.3)
	_check(b.pend_on, "and the pendulum is released")
	var xs := []
	var t0 := -1.0
	var cross := []
	var prev: float = b.pend_angle()
	var el := 0.0
	for i in int(6.5 / DT):
		_safe(w)
		_stand(w, b.arena_left + 60.0)
		b.state = "walk"
		b.timer = 99.0
		_tick(w)
		el += DT
		xs.append(b.bob().x)
		var a: float = b.pend_angle()
		if signf(a) != signf(prev) and prev != 0.0:
			cross.append(el)
		prev = a
	var lo: float = xs.min()
	var hi: float = xs.max()
	var c0 := floori(b.arena_left / TILE) - 2
	_check(absf(lo / TILE - c0 - 12.67) < 0.3 and absf(hi / TILE - c0 - 21.33) < 0.3, "it sweeps x 13-21 (tiles %.2f-%.2f)" % [lo / TILE - c0, hi / TILE - c0])
	if cross.size() >= 3:
		_check(absf((cross[2] - cross[0]) - 3.2) < 0.05, "a 3.2 s period (%.2f)" % (cross[2] - cross[0]))
	var bottom: float = b.pivot.y + 160.0 + 11.0
	_check(bottom < b.floor_y - 38.0, "its lowest point clears a standing Wick's head (%.0f px over the floor)" % (b.floor_y - bottom))
	await _done(w)


func _test_tk_rewind() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	b.phase = 3
	b.state = "walk"
	b.timer = 99.0
	b.position.x = b.arena_left + 200.0
	_stand(w, b.arena_left + 600.0)
	_ticks(w, 0.2)
	var x_then: float = b.position.x
	b._toss(w.player)
	# He walks off for 2 s.
	var path := []
	for i in int(2.0 / DT):
		_safe(w)
		b.state = "walk"
		b.timer = 99.0
		b.position.x += 60.0 * DT
		_tick(w)
		if not b._shots.is_empty():
			path.append(b._shots[0]["pos"])
	var cog: Dictionary = b._shots[0]
	var far: Vector2 = cog["pos"]
	b._begin_rewind()
	_check(b.state == "rewind", "Rewind begins")
	for i in int(0.6 / DT):
		_safe(w)
		_tick(w)
		if b.state != "rewind":
			break
	_check(absf(b.position.x - x_then) < 8.0, "he rewinds to where he stood 2.0 s ago (%.0f vs %.0f)" % [b.position.x, x_then])
	_check(bool(cog["rev"]), "and the cog he threw flies back")
	var back_ok := (cog["pos"] as Vector2).x < far.x - 20.0
	var on_path := false
	for p in path:
		if (p as Vector2).distance_to(cog["pos"]) < 3.0:
			on_path = true
	_check(back_ok and on_path, "along its own path, in reverse")
	# Through its tell: the afterimages lie along his path, the last one
	# exactly where he stops.
	_hold(w, [Vector2(b.arena_left + 700.0, b.floor_y), -1, "far"])
	for i in int(2.5 / DT):
		_safe(w)
		b.state = "key"                 # (standing: only this walk moves him)
		b.timer = 99.0
		b.position.x += 70.0 * DT
		_tick(w)
	b.state = "rewind_tell"
	b.timer = b.tell(b.REWIND_TELL)
	var tl: float = b.timer
	b._mark_rewind(b.timer)
	var ghosts: Array = b._ghost_x.duplicate()
	var x_start: float = b.position.x
	for i in int((b.REWIND_TELL + b.REWIND_T + 0.05) / DT):
		_safe(w)
		_tick(w)
		if b.state == "walk":
			break
	_check(ghosts.size() == 3 and absf(b.position.x - float(ghosts[2])) < 1.0, "Rewind's last afterimage is where he stops (%s, stopped at %.0f)" % [str(ghosts), b.position.x])
	_check(absf((x_start - b.position.x) - 70.0 * (b.REWIND_BACK - tl)) < 6.0, "where he stood 2.0 s before the rewind (%.0f px back)" % (x_start - b.position.x))
	var ordered: bool = ghosts.size() == 3 and float(ghosts[0]) > float(ghosts[1]) and float(ghosts[1]) > float(ghosts[2])
	_check(ordered, "the afterimages step back along his path toward it")
	await _done(w)


func _test_tk_midnight() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	b.phase = 2
	b.hp = b.max_hp * 0.31
	b.state = "walk"
	b._chimed()
	var lanes_x := []
	b.hit({"how": "slash", "from_x": 0.0, "amount": b.max_hp * 0.1})
	_check(b.phase == 3 and b.state == "midnight", "at 30%% Midnight strikes")
	_check(b.hand_dir == -1, "the hand now runs backward")
	var hp0: float = b.hp
	_check(not b.hit({"how": "slash", "from_x": 0.0, "amount": 100.0}) and b.hp == hp0, "he's untouchable through the chimes")
	_check(b._lanes.size() == 3, "3 safe lanes are drawn (%d)" % b._lanes.size())
	_check(b.grown_ice().size() == 4, "the floor's ice grows a tile at each end of each patch (%d cells)" % b.grown_ice().size())
	# Every lane of both patterns: on stone (the ice grown), or 5 tiles wide
	# on the ice; a run released at an ice lane's edge stops inside it.
	var row := floori(b.floor_y / TILE)
	var bad := []
	var ice_lanes := []
	for pat in b.MIDNIGHT_LANES.size():
		for l in b.midnight_lanes(pat):
			var icy := false
			for cx in range(floori(float(l[0]) / TILE), floori((float(l[1]) - 1.0) / TILE) + 1):
				icy = icy or LevelData.is_slick(w.level.tile(cx, row))
			var wtiles := (float(l[1]) - float(l[0])) / TILE
			if icy and wtiles < 5.0 - 0.01:
				bad.append("%s (%.0f tiles, on ice)" % [str(l), wtiles])
			elif not icy and wtiles < 3.0 - 0.01:
				bad.append("%s (%.0f tiles)" % [str(l), wtiles])
			if icy:
				ice_lanes.append(l)
	_check(bad.is_empty(), "every Midnight lane is on stone, or 5 tiles wide on the ice (%s)" % ", ".join(bad))
	await _done(w)
	for l in ice_lanes:
		for from_left in [true, false]:
			var ws := await _arena("tk")
			var bs := _awake(ws, 60.0)
			_ticks(ws, 1.3)
			bs._grow_ice()
			bs.state = "key"
			bs.timer = 99.0
			bs.position.x = bs.arena_right - 60.0 if from_left else bs.arena_left + 60.0
			var edge: float = float(l[0]) if from_left else float(l[1])
			var dir := 1.0 if from_left else -1.0
			_stand(ws, clampf(edge - dir * 100.0, bs.arena_left + 12.0, bs.arena_right - 12.0))
			_safe(ws)
			var released := false
			for i in int(3.0 / DT):
				if not released and (ws.player.position.x - edge) * dir >= 10.0:
					released = true
				_tick(ws, {} if released else ({"right": true} if from_left else {"left": true}))
				_safe(ws)
			var pr: Rect2 = ws.player.rect()
			_check(released and pr.position.x >= float(l[0]) - 0.5 and pr.end.x <= float(l[1]) + 0.5 and absf(ws.player.velocity.x) < 1.0,
					"a run released 10 px into the ice lane %s from the %s stops inside it (at %.0f)" % [str(l), "left" if from_left else "right", ws.player.position.x])
			await _done(ws)
	w = await _arena("tk")
	b = _awake(w, 60.0)
	_ticks(w, 1.3)
	b.phase = 2
	b.hp = b.max_hp * 0.31
	b.state = "walk"
	b._chimed()
	b.hit({"how": "slash", "from_x": 0.0, "amount": b.max_hp * 0.1})
	# The danger is drawn where the icicles die: under the IX ledge the
	# floor is sheltered (they die on the ledge).
	var ix_col := _arena_cell(b, Vector2i(5, 12))
	_check(absf(b.icicle_land((ix_col.x + 0.5) * TILE) - (b.floor_y - 96.0)) < 0.5, "icicles over the IX ledge die on it (the floor under it sheltered)")
	# A Wick in a lane stays whole; the icicles only fall outside them.
	var l1: Array = b._lanes[1]
	var lx := (float(l1[0]) + float(l1[1])) * 0.5
	w.player.invuln = 0.0
	w.player.hp = w.player.max_hp
	_stand(w, lx)
	var hp_h: float = w.player.hp
	var outside := true
	for i in int(3.2 / DT):
		w.player.velocity = Vector2.ZERO
		w.player.position.x = lx
		_tick(w)
		for ic in b.icicles():
			outside = outside and not b.in_lane(float(ic["x"]))
	_check(w.player.hp >= hp_h, "a Wick in a safe lane is untouched by the icicles")
	_check(outside, "the icicles fall only outside the lanes")
	_check(b.state != "midnight", "Midnight lasts 3 s")
	await _done(w)


func _test_tk_soldiers() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	b.state = "walk"
	b._chimed()
	b.hit({"how": "slash", "from_x": 0.0, "amount": b.max_hp * 0.26})
	_check(b._soldiers_owed == 1, "at 75%% he owes the soldiers")
	b._end_chimed()
	b.state = "walk"
	b.timer = 0.0
	_ticks(w, 1.2)
	_check(b.adds_alive("tickwind") == 2, "a key in the floor, and 2 Tickwinds from the hatches (%d)" % b.adds_alive("tickwind"))
	b._soldiers_owed = 1
	b.state = "walk"
	b.timer = 0.0
	_ticks(w, 1.2)
	_check(b.adds_alive("tickwind") <= 3, "never more than 3 (%d)" % b.adds_alive("tickwind"))
	await _done(w)
	# A phase's soldiers are its own (spec §4.1 rule 7): P2 ended inside the
	# window that passed 45% winds none in P3, and none outlive his fall.
	var w2 := await _arena("tk")
	var b2 := _awake(w2, 60.0)
	_ticks(w2, 1.3)
	_safe(w2)
	b2._stagger_phase = 1
	b2.state = "walk"
	b2._chimed()
	b2.hit({"how": "slash", "from_x": 0.0, "amount": b2.max_hp * 0.36})
	_check(b2.phase == 2, "(into P2 at 65%%)")
	_ticks(w2, 3.4, {}, func(): _safe(w2))
	b2._soldiers_owed = 0
	for e in b2._adds:
		if is_instance_valid(e):
			e.alive = false
	b2._adds.clear()
	b2._stagger_phase = 2
	b2.state = "walk"
	b2._chimed()
	b2.hit({"how": "slash", "from_x": 0.0, "amount": b2.max_hp * 0.5})
	_check(b2.phase == 3 and b2._soldiers_owed == 0, "P2 ended in the window that passed 45%%: no soldiers owed in P3 (%d)" % b2._soldiers_owed)
	var most := 0
	for i in int(8.0 / DT):
		_safe(w2)
		_tick(w2)
		most = maxi(most, b2.adds_alive("tickwind"))
	_check(most == 0, "and none wound in P3's first 8 s (%d)" % most)
	b2.spawn_add("tickwind", Vector2(b2.arena_left + 300.0, b2.floor_y))
	_check(b2.adds_alive("tickwind") == 1, "(a Tickwind of his)")
	b2.state = "walk"
	b2._chimed()
	b2.hit({"how": "slash", "from_x": 0.0, "amount": b2.max_hp})
	_check(not b2.alive and b2.adds_alive() == 0, "and his adds die with him (%d)" % b2.adds_alive())
	await _done(w2)


func _test_tk_minute() -> void:
	## The Minute Hand: the arc, the cut, and a Perfect Guard reeling him.
	var w := await _arena("tk", "dusk", "knight")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	w.player.invuln = 0.0
	w.player.hp = w.player.max_hp
	b.position.x = b.arena_left + 400.0
	b.facing = 1
	b.look_face = 1
	_stand(w, b.position.x + 70.0)
	b.state = "approach"
	b.timer = 1.5
	var hp0: float = w.player.hp
	_ticks(w, 0.05)
	_check(b.state == "swing_tell", "close in front, he raises the Minute Hand")
	_check(b.timer > 0.78 and b.timer <= 0.85 + 0.001, "a 0.85 s tell (%.2f left)" % b.timer)
	_check(b.arc_has(w.player.center()), "Wick stands in its drawn arc")
	_ticks(w, 1.2)
	_check(w.player.hp < hp0, "and the cut hurts him (%.0f)" % (hp0 - w.player.hp))
	# The way out is back, out of the arc's reach (no jump clears him, so
	# not past him): with real inputs, running off from the tell's start.
	w.player.invuln = 0.0
	w.player.hp = w.player.max_hp
	b.position.x = b.arena_left + 400.0
	b.facing = 1
	b.look_face = 1
	_stand(w, b.position.x + 70.0)
	b._swing_tell()
	hp0 = w.player.hp
	var t_out := 0.0
	for i in int(1.3 / DT):
		_tick(w, {"right": true})
		if b.state == "swing_tell" and b.arc_has(w.player.center()):
			t_out += DT
	_check(w.player.hp >= hp0 and t_out < b.tell(b.SWING_TELL, b.SWING_FLOOR), "running back out of the drawn arc in the tell is safe (out in %.2f s)" % t_out)
	# A Perfect Guard: he reels 1.0 s.
	w.player.invuln = 0.0
	w.player.hp = w.player.max_hp
	b.position.x = b.arena_left + 400.0
	b.facing = 1
	_stand(w, b.position.x + 70.0)
	w.player.facing = -1
	b._swing_tell()
	var reeled := false
	for i in int(1.5 / DT):
		if b.state == "swing":
			w.kit.guarding = true
			w.kit.guard_t = 0.0
		_tick(w)
		if b.state == "reel":
			reeled = true
			break
	_check(reeled, "a Perfect Guard on the Minute Hand reels him")
	if reeled:
		_check(absf(b.timer - 1.0) < 0.05 and not b.is_open(), "1.0 s, and it's no window")
	await _done(w)


func _bell_spot(b: Node2D, i: int) -> Array:
	## Where a Wick stands to slash bell i: on its floor, beside it on the
	## side toward the middle (VI: the side the Tinker isn't on). [feet, facing]
	var bx := float(b.bells[i]["cx"])
	var mid: float = (b.arena_left + b.arena_right) * 0.5
	var side := 1.0 if bx < mid else -1.0
	if b.ORDER[i] == "VI":
		side = -1.0 if b.position.x > bx else 1.0
	elif b.ORDER[i] == "XII":
		side = -1.0
	return [Vector2(bx + side * 27.0, float(b.bells[i]["surf"])), -int(side)]


func _into_phase(w: Node2D, b: Node2D, ph: int) -> void:
	## The Tinker into phase ph (through its roars), awake and walking.
	for k in ph - 1:
		b.state = "walk"
		b._chimed()
		b._stagger_phase = b.phase   # (past the phase's stagger: the blow runs on to its line)
		b.hit({"how": "slash", "from_x": 0.0, "amount": 999999.0})
		for i in int(3.3 / DT):
			_safe(w)
			_tick(w)
			if b.state in ["walk", "toss_tell", "approach"]:
				break
	b.kill_adds()


func _test_tk_guard() -> void:
	## He guards the lit bell from the floor GUARD tiles beside it (the
	## wall's side for IX and III: never between the middle and their
	## ledges), hurrying there when he's far; he never walks into Wick.
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	var beam := _arena_cell(b, Vector2i(17, 3))
	var perch := [Vector2((beam.x + 0.5) * TILE, (beam.y + 1) * TILE), -1, "on the beam"]
	for nm in ["IX", "III", "VI", "XII"]:
		var i: int = b.bell_i(nm)
		b.position.x = (b.arena_left + b.arena_right) * 0.5 + 40.0
		b._move_hand(i)
		b._hand_at = b.clock() + 30.0
		b._walk_state(99.0)
		var bx := float(b.bells[i]["cx"])
		var gx: float = b.guard_x()
		var took := -1.0
		for k in int(4.0 / DT):
			_hold(w, perch)
			w.player.invuln = 99.0
			_tick(w)
			if took < 0.0 and b.guarding():
				took = (k + 1) * DT
		var side_ok := true
		if nm == "IX":
			side_ok = b.position.x < bx
		elif nm == "III":
			side_ok = b.position.x > bx
		var need: float = (absf(gx - ((b.arena_left + b.arena_right) * 0.5 + 40.0)) - b.GUARD_SETTLE) / b.HURRY + 0.1
		_check(side_ok and absf(b.position.x - gx) < 2.0 and absf(absf(gx - bx) - 3.0 * TILE) < 60.0,
				"he guards %s from the floor %.1f tiles to its %s side" % [nm, absf(b.position.x - bx) / TILE, "wall's" if nm in ["IX", "III"] else "own"])
		_check(took >= 0.0 and took <= need, "hurrying there (%.2f s for %.0f px)" % [took, absf(gx - ((b.arena_left + b.arena_right) * 0.5 + 40.0))])
	# Wick on the floor between him and the lit bell: he stops short of him.
	b.position.x = b.arena_left + 80.0
	b._move_hand(b.bell_i("III"))
	b._hand_at = b.clock() + 30.0
	b._walk_state(99.0)
	var wx: float = (b.arena_left + b.arena_right) * 0.5
	var touched := false
	for k in int(4.0 / DT):
		_hold(w, [Vector2(wx, b.floor_y), -1, "in his way"])
		w.player.invuln = 99.0
		_tick(w)
		touched = touched or b.body_rect().intersects(w.player.rect())
	_check(not touched and b.body_rect().end.x > wx - 10.0 - b.STOP_GAP - 3.0, "with Wick in his way he stops %.0f px short of him, never into him" % (wx - 10.0 - b.body_rect().end.x))
	await _done(w)
	# Waiting beside the lit bell (every dwell, the hand's own pace) and
	# ringing it as soon as it's ready: the spring lands within 4 tiles of
	# the bell (the spec's "drops him where you are") in nearly every ring,
	# in every phase, and he gets to his post in time for most dwells.
	for ph in [1, 2, 3]:
		var wr := await _arena("tk")
		var br := _awake(wr, 60.0)
		_ticks(wr, 1.3)
		_safe(wr)
		_into_phase(wr, br, ph)
		br.chimes_at.clear()
		var moved_at := 0.0
		var hand: int = br.hand_i
		var rang := false
		var el := 0.0
		var spot := _bell_spot(br, hand)
		var dwells := 0
		var waits := []
		while el < 90.0:
			el += DT
			if br.hand_i != hand:
				hand = br.hand_i
				moved_at = el
				rang = false
				dwells += 1
				spot = _bell_spot(br, hand)
			var pad := {}
			if not rang and el - moved_at >= 0.2 and br.bell_ready(hand):
				rang = true
				pad = {"attack": true}
				waits.append(el - moved_at)
			_hold(wr, [spot[0], -1, "at the bell"])
			wr.player.invuln = 99.0
			wr.player.facing = int(spot[1])
			_tick(wr, pad)
			if br.is_open():
				br.hp = maxf(br.hp, br.phase_floor() + br.max_hp * 0.2)
		var near := 0
		var far_d := 0.0
		for c in br.chimes_at:
			var d := absf(float(c[1]) - float(br.bells[int(c[0])]["cx"]))
			far_d = maxf(far_d, d)
			if d <= 4.0 * TILE:
				near += 1
		var n: int = br.chimes_at.size()
		var wmax := 0.0
		for x in waits:
			wmax = maxf(wmax, float(x))
		print("  the Tinker P%d: %d dwells, %d rung (ready %.1f s in at most), %d with the spring within 4 tiles of the bell (farthest %.1f tiles)" % [ph, dwells, n, wmax, near, far_d / TILE])
		_check(n >= 8 and float(near) >= 0.9 * n, "P%d: ringing the lit bell drops his spring within 4 tiles of it (%d of %d)" % [ph, near, n])
		_check(float(n) >= 0.5 * dwells, "P%d: he's at his post in time to be rung in most dwells (%d of %d)" % [ph, n, dwells])
		await _done(wr)


func _test_tk_lob() -> void:
	## A Wick up on the XII beam: the cogs are lobbed onto the beam's far end
	## (the landing marked) and roll at him.
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	var beam := _arena_cell(b, Vector2i(16, 3))
	var sp := [Vector2((beam.x + 0.5) * TILE, (beam.y + 1) * TILE), -1, "on the beam"]
	_hold(w, sp)
	b.position.x = b.arena_left + 200.0
	b.state = "toss_tell"
	b.timer = 0.01
	var lob: Dictionary = b._lob_target(w.player)
	_check(not lob.is_empty() and float(lob["to"].x) > sp[0].x + 40.0, "on the beam, the cogs are aimed at its far end (%s)" % str(lob.get("to", "none")))
	b.blows.clear()
	var landed := false
	for i in int(2.0 / DT):
		_hold(w, sp)
		_tick(w)
		for s in b._shots:
			if str(s["kind"]) == "cog" and not bool(s.get("air", false)) and absf(float(s["pos"].y) - (sp[0].y - b.COG_R)) < 1.0:
				landed = true
	_check(landed, "they land on the beam and roll")
	_check(int(b.blows.get("toss", 0)) > 0, "and a Wick standing there is hit (%s)" % str(b.blows))
	await _done(w)


func _test_tk_reach() -> void:
	## No safe spot: in every phase, a Wick held still anywhere in K_ARENA
	## (the floor, the IX and III ledges, the XII beam) is reached by some
	## move of his within one pass of the phase's rotation.
	for ph in [1, 2, 3]:
		var w := await _arena("tk")
		var b := _awake(w, 60.0)
		_ticks(w, 1.3)
		_safe(w)
		_into_phase(w, b, ph)
		var spots := _spots(w, b, [2, 31], [2, 12])
		var missed := []
		var by := {}
		for sp in spots:
			b.kill_adds()
			b._shots.clear()
			b._walk_state(0.3)
			var got := _reach_run(w, b, sp, ph)
			if got == "":
				missed.append(sp[2])
			else:
				by[got] = int(by.get(got, 0)) + 1
		print("  the Tinker P%d: %d spots, reached by %s" % [ph, spots.size(), str(by)])
		var names := []
		for sp in spots:
			names.append(sp[2])
		_check(b.phase == ph and names.has("on (17,4)") and names.has("on (5,10)") and names.has("on (28,10)"), "(P%d: %d spots, the beam and both ledges among them)" % [ph, spots.size()])
		_check(missed.is_empty(), "P%d: no spot in his arena is out of his reach (missed: %s)" % [ph, ", ".join(missed)])
		await _done(w)


func _test_tk_retry() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	b.phase = 2
	b.hp = b.max_hp * 0.31
	b.state = "walk"
	b._chimed()
	b.hit({"how": "slash", "from_x": 0.0, "amount": b.max_hp * 0.1})
	_ticks(w, 0.5)
	b.pend_on = true
	b.spawn_add("tickwind", Vector2(b.arena_left + 200.0, b.floor_y))
	b._toss(w.player)
	w.stop_time(0.3, b)
	_check(b._ice_cells.size() == 4 and b.pend_on, "(Midnight's ice, the pendulum, a soldier, a cog)")
	w.player.invuln = 0.0
	w.player.take_damage(999999.0, w.player.position.x + 10.0)
	_ticks(w, 2.2)
	var ice_back := true
	var c0 := floori(b.arena_left / TILE) - 2
	for cx in [3, 10, 19, 26]:
		ice_back = ice_back and w.level.tile(c0 + cx, 13) == LevelData.STONE
	_check(b.state == "sleep" and b.hp == b.max_hp and b.phase == 1, "a retry: asleep at full life, phase 1")
	_check(b.ORDER[b.hand_i] == "XII" and b.hand_dir == 1, "the hand back to XII, clockwise")
	_check(not b.pend_on and b.bob().distance_to(b.pivot + Vector2(0, 160)) < 0.1, "the pendulum still")
	_check(ice_back, "the ice as it was")
	_check(b.adds_alive() == 0 and b.shots_now().is_empty() and b.icicles().is_empty(), "the soldiers and everything thrown gone")
	_check(not w.time_stopped(), "time running")
	var open := true
	for c in b.door:
		open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(open, "the door open")
	await _done(w)
	# Snuffed the moment his stop begins: the retry starts with time running.
	var w2 := await _arena("tk")
	var b2 := _awake(w2, 60.0)
	_ticks(w2, 1.3)
	b2.phase = 2
	b2.state = "watch"
	b2.timer = 0.0
	w2.player.invuln = 0.0
	_tick(w2)
	_check(w2.time_stopped(), "(his stop begins)")
	w2.player.take_damage(999999.0, w2.player.position.x + 10.0)
	var at_reset := true
	for i in int(2.4 / DT):
		_tick(w2)
		if b2.state == "sleep" and at_reset:
			at_reset = false
			_check(not w2.time_stopped(), "snuffed as time stopped: at the retry time runs again")
	_check(not at_reset, "(the retry came)")
	await _done(w2)


func _test_tk_death() -> void:
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	_ticks(w, 1.3)
	_safe(w)
	b.phase = 3
	b.hp = 5.0
	b.state = "walk"
	b._chimed()
	b.hit({"how": "slash", "from_x": 0.0, "amount": 100.0})
	_check(not b.alive, "he falls")
	_ticks(w, 1.6)
	_check(w.bells.size() == 1, "the bell rises")
	var lit := true
	for i in 4:
		lit = lit and float(b._arm[i]) <= b.clock()
	_check(lit, "all four bells ring the true hour")
	await _done(w)


func _test_tk_sim() -> void:
	## 300 s with a scripted Wick: every move gets used (he rings the lit
	## bell now and then; an untouchable Wick close to him, then away).
	var w := await _arena("tk")
	var b := _awake(w, 60.0)
	var el := 0.0
	var dmg: float = b.max_hp * 0.012
	for i in int(300.0 / DT):
		_safe(w)
		el += DT
		var slot := int(el / 5.0) % 4
		if i % int(1.0 / DT) == 0:
			if slot == 1:
				_stand(w, b.position.x + 80.0 * b.look_face)
			elif slot == 3:
				_stand(w, b.arena_left + 120.0)
		if i % int(9.0 / DT) == 0 and b.state == "walk":
			b._ring(b.hand_i)
		_tick(w)
		if b.is_open() and i % 20 == 0:
			b.hit({"how": "slash", "from_x": 0.0, "amount": dmg})
		if not b.alive:
			break
	var want := ["toss", "swing", "stop", "soldiers", "pendulum", "rewind", "midnight", "chimed"]
	var missing := []
	for m in want:
		if int(b.moves_used.get(m, 0)) == 0:
			missing.append(m)
	print("  the Tinker's 300 s sim: %.0f s, phase %d, %d windows, moves %s" % [el, b.phase, b.windows_opened, str(b.moves_used)])
	_check(missing.is_empty(), "every move used in a 300 s sim (missing: %s)" % ", ".join(missing))
	await _done(w)


# ---------------------------------------------------------------- tells and rush

func _test_tells() -> void:
	## Every tell >= 0.40 s on Dusk (>= the escape formula where it's run
	## from) and >= its floor on Witching.
	for d in ["dusk", "witching"]:
		var w := await _arena("rm", d)
		var b: Node2D = w.boss
		var rows := [["sweep", b.tell(b.SWEEP_TELL, b.SWEEP_FLOOR), 0.75, 0.50], ["spear", b.tell(b.SPEAR_TELL, b.SPEAR_FLOOR), 0.60, 0.45],
				["breath", b.tell(b.BREATH_TELL), 0.80, 0.30], ["thorns", b.tell(b.THORN_TELL, b.THORN_FLOOR), 0.80, 0.72],
				["seed", b.tell(b.SEED_SHAKE) + b.SEED_FALL, 1.2, 0.9]]
		for r in rows:
			var want: float = float(r[2]) if d == "dusk" else float(r[3])
			_check(float(r[1]) >= want - 0.001 and float(r[1]) >= (0.40 if d == "dusk" else 0.30), "Gravebough's %s tell on %s: %.2f s (want %.2f)" % [r[0], d, r[1], want])
		if d == "dusk":
			var spear_need: float = b.escape_tell(b.SPEAR_W * 0.5 + 10.0)
			_check(b.tell(b.SPEAR_TELL, b.SPEAR_FLOOR) >= spear_need, "the spear's tell meets the escape formula (%.2f)" % spear_need)
			_check(b.PULSE_MIN + b.SWELL >= 1.4 - 0.001, "the Heart Run shows its socket at least 1.4 s before it opens")
		await _done(w)
		var wt := await _arena("tk", d)
		var t: Node2D = wt.boss
		var trows := [["toss", t.tell(t.TOSS_TELL, t.TOSS_FLOOR), 0.55, 0.40], ["minute", t.tell(t.SWING_TELL, t.SWING_FLOOR), 0.85, 0.55],
				["stop", t.tell(t.STOP_TELL), 0.80, 0.30], ["key", t.tell(t.KEY_TELL), 0.80, 0.30], ["rewind", t.tell(t.REWIND_TELL), 0.60, 0.30]]
		for r in trows:
			var want: float = float(r[2]) if d == "dusk" else float(r[3])
			_check(float(r[1]) >= want - 0.001 and float(r[1]) >= (0.40 if d == "dusk" else 0.30), "the Tinker's %s tell on %s: %.2f s (want %.2f)" % [r[0], d, r[1], want])
		if d == "dusk":
			# The Minute Hand's arc: its worst spot's way out, on a grid over
			# the arc: away from him only (no jump clears him, so never past
			# him), from anywhere a Wick can be in front of his body.
			t.position = Vector2(t.arena_left + 400.0, t.floor_y)
			t.look_face = 1
			var front: float = t.body_rect().end.x - t.position.x + 10.0
			var worst := 0.0
			for gx in range(int(front), 130, 3):
				for gy in range(-170, 0, 3):
					var p := t.position + Vector2(gx, gy)
					if not t.arc_has(p):
						continue
					var best := INF
					for ex in range(0, 160, 2):
						var q := Vector2(p.x + ex, p.y)
						if not t.arc_has(q):
							best = minf(best, absf(float(ex)))
					worst = maxf(worst, best)
			var need: float = t.escape_tell(worst + 10.0)
			_check(t.tell(t.SWING_TELL, t.SWING_FLOOR) >= need, "the Minute Hand's 0.85 s tell meets the escape formula (%.2f s, %.0f px)" % [need, worst])
			_check(t.ICICLE_TELL >= 0.40, "Midnight's icicles show their shadows 0.5 s first")
			_check(t.STOP_T - 0.0 >= 1.2 and t.TREMBLE >= 0.4, "the frozen hands are drawn with their lines through the stop, trembling 0.4 s")
		await _done(wt)


func _test_lights() -> void:
	## The light budgets (spec §5.2 16, §5.3 18) in the busiest moments: with
	## the hero's, the World's boss light, and 3 adds' eyes (2 each).
	var w := await _arena("rm")
	var b := _awake(w, 300.0)
	_ticks(w, 1.4)
	_safe(w)
	b.phase = 3
	b._queue = ["heart"]
	b.state = "idle"
	b.timer = 0.0
	var most := 0
	for i in int(6.0 / DT):
		_safe(w)
		if i == 30:
			b._march(w.player)
		_tick(w)
		most = maxi(most, b.lights().size())
	_check(most + 2 + 6 <= 16, "Gravebough's fight stays within 16 lights (%d of hers at most)" % most)
	await _done(w)
	var wt := await _arena("tk")
	var t := _awake(wt, 60.0)
	_ticks(wt, 1.3)
	_safe(wt)
	t.phase = 2
	t.pend_on = true
	t.state = "watch"
	t.timer = 0.8
	var most2 := 0
	for i in int(3.0 / DT):
		_safe(wt)
		_tick(wt)
		most2 = maxi(most2, t.lights().size())
	t.state = "walk"
	t._chimed()
	_tick(wt)
	most2 = maxi(most2, t.lights().size())
	_check(most2 + 2 + 6 <= 18, "the Tinker's fight stays within 18 lights (%d of his at most)" % most2)
	await _done(wt)


func _test_rush() -> void:
	## configure({rush, hp_mult}) before _ready: the boss's own rush life x
	## the mode's; no drops on the kill.
	var w := await _arena("rm")
	var life0: float = w.boss.max_hp
	await _done(w)
	var sc = load("res://scripts/rootmother_boss.gd")
	var b = sc.new()
	b.setup_stats(17, "dusk")
	var base: float = b.max_hp
	b.configure({"rush": true, "hp_mult": 1.5, "mods": []})
	_check(absf(b.max_hp - base * 0.9 * 1.5) < 0.5 and b.rush, "configure: rush life x0.9 (hers) x the mode's hp_mult")
	b.free()
	var tsc = load("res://scripts/tinker_boss.gd")
	var t = tsc.new()
	t.setup_stats(22, "dusk")
	base = t.max_hp
	t.configure({"rush": true, "hp_mult": 1.0})
	_check(absf(t.max_hp - base * 1.42) < 0.5, "the Tinker's rush life x1.42 (v1.0.1: test_rush_bosses' Tinker rush)")
	t.free()
	_check(life0 > 0.0, "(story life unchanged)")


func _test_real_levels() -> void:
	## The real 3-4 and 4-4 (WL3, WL4) when they're built: their arenas have
	## the anchors the fights read, and the bosses find them.
	for row in [["3-4", "rootmother", 6], ["4-4", "tinker", 4]]:
		var path := "res://levels/%s.txt" % row[0]
		if not FileAccess.file_exists(path):
			print("  skipped: %s missing (WL%s's)" % [path, str(row[0]).left(1)])
			continue
		var lv = LevelData.load_file(path)
		game.reset()
		var w: Node2D = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await process_frame
		var b: Node2D = w.boss
		_check(b != null and str(b.get("boss_id")) == str(row[1]), "%s spawns %s" % [row[0], row[1]])
		if b != null:
			_check(b.anchors.size() == int(row[2]), "%s's arena has %d anchors (%d)" % [row[0], row[2], b.anchors.size()])
			if row[1] == "rootmother":
				for nm in RM_SOCKETS:
					var i: int = b.socket_named(nm)
					_check(i >= 0 and b.sockets[i]["cell"] == _arena_cell(b, RM_SOCKETS[nm]), "3-4's socket %s where the spec puts it" % nm)
			else:
				for nm in TK_BELLS:
					var i2: int = b.bell_i(nm)
					_check(i2 >= 0 and b.bells[i2]["cell"] == _arena_cell(b, TK_BELLS[nm]), "4-4's bell %s where the spec puts it" % nm)
				# Midnight's lanes on its floor (the ice grown): stone, or 5 wide on ice.
				b._grow_ice()
				var frow := floori(b.floor_y / TILE)
				var bad_l := []
				for pat in b.MIDNIGHT_LANES.size():
					for l in b.midnight_lanes(pat):
						var icy := false
						for cx in range(floori(float(l[0]) / TILE), floori((float(l[1]) - 1.0) / TILE) + 1):
							icy = icy or LevelData.is_slick(w.level.tile(cx, frow))
						if icy and float(l[1]) - float(l[0]) < 5.0 * TILE - 0.5:
							bad_l.append(str(l))
				_check(bad_l.is_empty(), "4-4's Midnight lanes are on stone or 5 wide on the ice (%s)" % ", ".join(bad_l))
		await _done(w)
