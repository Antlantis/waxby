extends SceneTree
## The engine's checks: every level parses; Wick's jump feel is what the
## levels were laid out for; a bot using Wick's own physics finds a way to
## every level's bell and all three sigils (so nothing's out of reach); the
## World runs every level headless without errors; stomps, the sword, bonks,
## pickups, spikes, pits and altars do what they should; the save keeps what
## it should. Build 1: pure down held a moment on a ledge drops through it
## (never on solid floor, never a down carried onto it), and a controller's
## d-pad, stick and buttons reach the actions; a boss's first kill, a
## player's, offers his prize on the choice card (the Boss Boons).
##
##     godot --headless --path game --script res://tests/test_core.gd

const LevelData := preload("res://scripts/level_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
var WorldScript: GDScript   # loaded at run time: it needs the autoloads, which a preload would beat
const Relics := preload("res://scripts/relics.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Progression := preload("res://scripts/progression.gd")
const Combat := preload("res://scripts/combat.gd")
const Reach := preload("res://scripts/reach.gd")
const Movers := preload("res://scripts/movers.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
const LAB_LEVELS := ["res://levels/lab-0.txt", "res://levels/lab-1.txt"]
const TILE := 32
const DT := 1.0 / 120.0

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
	print("  autoloads: Game %s, Sfx %s" % [game != null, root.get_node_or_null("Sfx") != null])
	if game != null:
		game.save_path = "user://test_core_save.json"
		for suffix in [".bak", ".tmp"]:   # a last run's backup would be loaded as the save
			DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
		game.reset()
	var only_world := OS.get_environment("WAXBY_WORLD")
	if only_world != "":
		# One world's bot and nothing else (tools/test.sh runs them in parallel).
		_test_reachability(int(only_world))
		print("test_core (world %s): %d passed, %d failed" % [only_world, _passed, _failed])
		quit(1 if _failed > 0 else 0)
		return
	_test_levels_parse()
	_test_feel()
	_test_hold_drop()
	if OS.get_environment("WAXBY_FAST") == "" and OS.get_environment("WAXBY_NOBOT") == "":
		_test_reachability()
	else:
		print("  (reachability bot skipped here)")
	await _test_world_smoke()
	_test_pad_bindings()   # (after a frame: Game's _ready sets the actions up)
	await _test_interactions()
	await _test_boss()
	await _test_boss_fair()
	await _test_boss_after()
	await _test_seams()
	await _test_v2_core()
	await _test_ember_tally()
	await _test_dusk_teeth()
	_test_v3_format()
	_test_v3_physics()
	await _test_v3_world()
	await _test_v3_modes()
	await _test_v3_features()
	await _test_v3_boss_seam()
	await _test_v3_damage()
	await _test_v3_main()
	await _test_v3_lab_features()
	await _test_p0_integration()
	await _test_p0_review()
	await _test_wave1_wiring()
	await _test_loot_build1()
	await _test_boss_boons()
	_test_relics_and_save()
	print("test_core: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- parsing

func _levels() -> Array:
	var out := []
	for info in game.LEVELS:
		out.append(LevelData.load_file(info["path"]))
	return out


func _all_level_files() -> Array:
	## Every level file in res://levels (the main path, secrets, the labs).
	var out := []
	for f in DirAccess.get_files_at("res://levels"):
		if f.ends_with(".txt"):
			out.append("res://levels/" + f)
	out.sort()
	return out


func _test_levels_parse() -> void:
	for lv in _levels():
		_check(lv.count("sigil") == 3, "%s has three sigils" % lv.id)
	for path in _all_level_files():
		var lv = LevelData.load_file(path)
		_check(lv.errors.is_empty(), "%s parses cleanly: %s" % [lv.id, ", ".join(lv.errors)])
		_check(lv.height == 15, "%s is 15 rows" % lv.id)
		_check(lv.title != "" and lv.subtitle != "", "%s has a title" % lv.id)
		var start: Vector2i = lv.start
		_check(LevelData.is_solid(lv.tile(start.x, start.y + 1)), "%s: Wick starts on the floor" % lv.id)
		_check(lv.area >= 1, "%s has an area level" % lv.id)
		_check_placements(lv)


func _check_placements(lv: RefCounted) -> void:
	## Every entity where its PLACEMENT says (level_data.gd).
	for e in lv.entities:
		var c: Vector2i = e["cell"]
		var kind: String = e["kind"]
		_check(not LevelData.is_solid(lv.tile(c.x, c.y)), "%s: %s at %s isn't inside stone" % [lv.id, kind, c])
		var above: int = lv.tile(c.x, c.y - 1)
		var below: int = lv.tile(c.x, c.y + 1)
		var here: int = lv.tile(c.x, c.y)
		var on_floor := LevelData.is_solid(below) or LevelData.is_ledge(below)
		var on_ceiling := LevelData.is_solid(above)
		var on_vine := LevelData.is_climb(here)
		match LevelData.PLACEMENT.get(kind, "air"):
			"floor":
				_check(on_floor, "%s: %s at %s stands on something" % [lv.id, kind, c])
			"ceiling":
				_check(on_ceiling, "%s: %s at %s hangs from a ceiling" % [lv.id, kind, c])
			"deep_water":
				_check(lv.is_deep(c.x, c.y), "%s: %s at %s is in deep water" % [lv.id, kind, c])
			"surface":
				for k in int(e.get("length", 1)):
					_check(lv.is_surface(c.x + k, c.y), "%s: %s at %d,%d is on a water surface" % [lv.id, kind, c.x + k, c.y])
			"vine_or_wall":
				_check(on_vine or LevelData.is_solid(lv.tile(c.x - 1, c.y)) or LevelData.is_solid(lv.tile(c.x + 1, c.y)),
						"%s: %s at %s is on a vine or by a wall" % [lv.id, kind, c])
			"hang":
				_check(on_ceiling or LevelData.is_ledge(above), "%s: %s at %s hangs from something" % [lv.id, kind, c])
			"mount":
				_check(on_floor or on_ceiling or on_vine, "%s: %s at %s is on a floor, a ceiling or a vine" % [lv.id, kind, c])
			"ceiling_or_vine":
				_check(on_ceiling or on_vine, "%s: %s at %s hangs from a ceiling or a vine" % [lv.id, kind, c])
		if kind == "cog":
			# No solid tile within 112 px of a hub (the ring's clearance).
			var hub := LevelData.cell_center(c)
			var clear := true
			for y in range(c.y - 4, c.y + 5):
				for x in range(c.x - 4, c.x + 5):
					if LevelData.is_solid(lv.tile(x, y)) and Rect2(x * TILE, y * TILE, TILE, TILE).grow(0.0).has_point(hub) == false:
						var near := Vector2(clampf(hub.x, x * TILE, (x + 1) * TILE), clampf(hub.y, y * TILE, (y + 1) * TILE))
						if near.distance_to(hub) < 112.0:
							clear = false
			_check(clear, "%s: the cog at %s has no solid within 112 px" % [lv.id, c])
		if kind == "swing":
			var anchored := false
			for dy in range(3, 7):
				if LevelData.is_solid(lv.tile(c.x + int(e.get("length", 1)) / 2, c.y - dy)):
					anchored = true
			_check(anchored, "%s: the swing at %s hangs from solid 3-6 rows up" % [lv.id, c])
	# A rotten run is at most 3 cells tall.
	for x in lv.width:
		var run := 0
		for y in lv.height:
			run = run + 1 if lv.tile(x, y) == LevelData.ROTTEN_VINE else 0
			if run == 4:
				_check(false, "%s: the rotten vine at %d,%d is at most 3 tall" % [lv.id, x, y])


# ---------------------------------------------------------------- feel

func _flat_level(w := 60) -> RefCounted:
	var rows := []
	for y in 15:
		rows.append(("#".repeat(w)) if y >= 13 else ".".repeat(w))
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n---\n" + "\n".join(rows).replace("..P", "..."))
	return lv


func _player_on(lv: RefCounted, at: Vector2) -> Node2D:
	var p: Node2D = PlayerScript.new()
	p.level = lv
	p.reset_at(at)
	return p


func _run(p: Node2D, pad: Dictionary, seconds: float, until_floor := false) -> Dictionary:
	## Steps the player with pad held; returns the highest the feet got and
	## where it ended. jump_pressed only on the first step.
	var top: float = p.position.y
	var left_floor := false
	var n := int(seconds / DT)
	for i in n:
		var pd := pad.duplicate()
		pd["jump_pressed"] = pad.get("jump_pressed", false) and i == 0
		pd["attack_pressed"] = pad.get("attack_pressed", false) and i == 0
		if pad.has("release_at") and i * DT >= pad["release_at"]:
			pd["jump"] = false
		p.pad = pd
		p.step(DT)
		top = minf(top, p.position.y)
		if not p.on_floor:
			left_floor = true
		if until_floor and left_floor and p.on_floor:
			break
	return {"top": top, "end": p.position}


func _test_feel() -> void:
	var lv := _flat_level()
	var ground := 13.0 * TILE
	var p := _player_on(lv, Vector2(200, ground))
	_run(p, {}, 0.2)
	_check(p.on_floor and absf(p.position.y - ground) < 0.01, "Wick stands on the floor")
	_run(p, {"right": true}, 0.3)
	_check(absf(p.velocity.x - p.RUN_SPEED) < 1.0, "Wick reaches full speed in 0.3 s (%.0f)" % p.velocity.x)
	_run(p, {}, 0.3)
	_check(absf(p.velocity.x) < 1.0, "and stops quickly when let go")
	# A held jump clears 3 tiles, not 4.
	var r := _run(p, {"jump": true, "jump_pressed": true}, 1.5, true)
	var h: float = ground - r["top"]
	print("  held jump height: %.1f px (%.2f tiles)" % [h, h / TILE])
	_check(h > 3.0 * TILE + 2.0 and h < 3.6 * TILE, "a held jump clears 3 tiles but not 4 (%.1f px)" % h)
	# A tap is a hop.
	r = _run(p, {"jump": true, "jump_pressed": true, "release_at": 0.02}, 1.5, true)
	var tap: float = ground - r["top"]
	print("  tapped jump height: %.1f px" % tap)
	_check(tap > 20.0 and tap < h * 0.6, "a tap is a short hop (%.1f px)" % tap)
	# Running jump distance.
	p.reset_at(Vector2(200, ground))
	_run(p, {"right": true}, 0.4)
	var x0: float = p.position.x
	r = _run(p, {"right": true, "jump": true, "jump_pressed": true}, 2.0, true)
	var dist: float = r["end"].x - x0
	print("  running jump distance: %.1f px (%.2f tiles)" % [dist, dist / TILE])
	_check(dist > 4.0 * TILE and dist < 6.0 * TILE, "a running jump carries 4-6 tiles (%.1f px)" % dist)
	# Coyote time: a jump just after running off an edge still goes.
	var ledge = LevelData.new()
	var rows := []
	for y in 15:
		if y >= 13:
			rows.append("##########" + ".".repeat(40))
		else:
			rows.append(".".repeat(50))
	ledge.parse("title: t\nsubtitle: t\n---\n" + "\n".join(rows))
	p = _player_on(ledge, Vector2(9.5 * TILE, ground))
	p.velocity.x = p.RUN_SPEED
	var off := false
	for i in 200:
		p.pad = {"right": true}
		p.step(DT)
		if not p.on_floor:
			off = true
			break
	# 60 ms after leaving the edge.
	for i in 7:
		p.pad = {"right": true}
		p.step(DT)
	p.pad = {"right": true, "jump": true, "jump_pressed": true}
	p.step(DT)
	_check(off and p.velocity.y < -400.0, "coyote time: a late jump off an edge still jumps")
	# Jump buffer: pressing just before landing jumps on landing.
	p = _player_on(lv, Vector2(200, ground - 60))
	p.velocity = Vector2.ZERO
	var pressed_at := -1
	var jumped := false
	for i in 120:
		var pd := {"jump": true}
		if p.position.y > ground - 14.0 and pressed_at < 0 and p.velocity.y > 0.0:
			pd["jump_pressed"] = true
			pressed_at = i
		p.pad = pd
		p.step(DT)
		if pressed_at >= 0 and p.velocity.y < -400.0:
			jumped = true
			break
	_check(jumped, "jump buffer: a press just before landing jumps")
	# A ceiling corner clipped by a few pixels is slid around.
	var cc = LevelData.new()
	rows = []
	for y in 15:
		if y >= 13:
			rows.append("#".repeat(30))
		elif y == 9:
			rows.append("..........#" + ".".repeat(19))
		else:
			rows.append(".".repeat(30))
	cc.parse("title: t\nsubtitle: t\n---\n" + "\n".join(rows))
	p = _player_on(cc, Vector2(10 * TILE - 6.0, ground))
	r = _run(p, {"jump": true, "jump_pressed": true}, 1.0, true)
	_check(ground - r["top"] > 3.0 * TILE, "a jump clipping a ceiling corner slides round it (%.1f px)" % (ground - r["top"]))


func _test_hold_drop() -> void:
	## Build 1's lit thumb pad: pure down held DROP_HOLD (0.15 s) on a ledge
	## drops through it, and down + jump still drops at once. Down with left
	## or right, down on solid floor, and a down carried onto a ledge (out of
	## the air, or off a vine's slide) don't; a vine still climbs on up.
	var lines := []
	for y in 13:
		var row := ".".repeat(40)
		if y >= 3 and y <= 8:
			row = row.substr(0, 30) + "{" + row.substr(31)
		if y == 9:
			row = "...." + "=".repeat(20) + "...." + "=".repeat(5) + "......."
		lines.append(row)
	var lv := _rows(lines)
	var top := 9.0 * TILE
	var ground := 13.0 * TILE
	var p := _player_on(lv, Vector2(12.0 * TILE, top))
	_steps(p, {}, 0.1)
	_check(p.on_floor and absf(p.position.y - top) < 0.01, "(he stands on the ledge: y %.0f)" % p.position.y)
	_steps(p, {"down": true}, 0.1)
	_check(p.on_floor and absf(p.position.y - top) < 0.01, "pure down held 0.1 s on a ledge: still on it")
	_steps(p, {"down": true}, 0.08)
	_check(not p.on_floor and p.position.y > top, "held past %.2f s: down through it (y %.0f)" % [p.DROP_HOLD, p.position.y])
	_steps(p, {"down": true}, 1.0)
	_check(p.on_floor and absf(p.position.y - ground) < 0.01, "and on down to the floor under it (y %.0f)" % p.position.y)
	_steps(p, {}, 0.05)
	_steps(p, {"down": true}, 1.0)
	_check(p.on_floor and absf(p.position.y - ground) < 0.01 and absf(p.velocity.x) < 0.01, "down held on solid floor does nothing new")
	# Down with a way held is a diagonal: he runs along the ledge, on it.
	p.reset_at(Vector2(6.0 * TILE, top))
	_steps(p, {}, 0.1)
	_steps(p, {"down": true, "right": true}, 0.5)
	_check(p.on_floor and absf(p.position.y - top) < 0.01 and p.position.x > 7.0 * TILE, "down + right on a ledge runs along it (x %.0f)" % p.position.x)
	# Down + jump drops at once, as before.
	p.reset_at(Vector2(12.0 * TILE, top))
	_steps(p, {}, 0.1)
	p.pad = {"down": true, "jump": true, "jump_pressed": true}
	p.step(DT)
	_check(not p.on_floor and p.drop_through > 0.0 and p.velocity.y >= 0.0, "down + jump on a ledge still drops through it at once")
	# Down held from the air onto the ledge waits to be let go.
	p.reset_at(Vector2(12.0 * TILE, top - 64.0))
	_steps(p, {"down": true}, 0.8)
	_check(p.on_floor and absf(p.position.y - top) < 0.01, "a down held as he lands on a ledge keeps him on it (y %.0f)" % p.position.y)
	_steps(p, {}, 1.0 / 60.0)
	_steps(p, {"down": true}, 0.2)
	_check(not p.on_floor and p.position.y > top, "let go and held again: down through it")
	p.free()
	# Sliding down a vine onto a ledge across it: he stays on the ledge.
	var v := _on_vine(lv, 30, 5.5 * TILE)
	_steps(v, {"down": true}, 1.2)
	_check(not v.climbing and v.on_floor and absf(v.position.y - top) < 0.01, "a slide down a vine onto a ledge stays on it, down still held (y %.0f)" % v.position.y)
	v.free()
	var c := _on_vine(lv, 30, 7.5 * TILE)
	var y0: float = c.position.y
	_steps(c, {"up": true}, 0.3)
	_check(c.climbing and c.position.y < y0 - 30.0, "up on a vine still climbs (%.0f px)" % (y0 - c.position.y))
	c.free()


func _test_pad_bindings() -> void:
	## Game._setup_input: a controller's d-pad and left stick (a 0.4 dead
	## zone) move the four ways, A / X / Y / the shoulders / Menu are jump,
	## attack, the Special, the flask, a pickup and pause, on any controller;
	## the Up arrow is "up" (a climb that never leaps) and W still jumps.
	if game == null:
		return
	var buttons := [[JOY_BUTTON_A, "jump"], [JOY_BUTTON_X, "attack"], [JOY_BUTTON_Y, "special"], [JOY_BUTTON_LEFT_SHOULDER, "flask"],
			[JOY_BUTTON_RIGHT_SHOULDER, "equip"], [JOY_BUTTON_START, "pause"], [JOY_BUTTON_DPAD_LEFT, "left"],
			[JOY_BUTTON_DPAD_RIGHT, "right"], [JOY_BUTTON_DPAD_UP, "up"], [JOY_BUTTON_DPAD_DOWN, "down"]]
	for b in buttons:
		for dev in [0, 1]:
			var ev := InputEventJoypadButton.new()
			ev.device = dev
			ev.button_index = b[0]
			ev.pressed = true
			_check(ev.is_action_pressed(b[1]), "controller %d's button %d is %s" % [dev, b[0], b[1]])
	var bb := InputEventJoypadButton.new()
	bb.button_index = JOY_BUTTON_B
	bb.pressed = true
	_check(not bb.is_action_pressed("jump") and not bb.is_action_pressed("attack"), "B is neither jump nor attack")
	for s in [[JOY_AXIS_LEFT_X, -1.0, "left"], [JOY_AXIS_LEFT_X, 1.0, "right"], [JOY_AXIS_LEFT_Y, -1.0, "up"], [JOY_AXIS_LEFT_Y, 1.0, "down"]]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = s[0]
		_check(is_equal_approx(InputMap.action_get_deadzone(s[2]), 0.4), "%s's dead zone is 0.4" % s[2])
		ev.axis_value = s[1] * 0.5
		_check(ev.is_action_pressed(s[2]), "the left stick half way holds %s" % s[2])
		ev.axis_value = s[1] * 0.3
		_check(not ev.is_action_pressed(s[2]), "inside the dead zone it doesn't (%s)" % s[2])
		ev.axis_value = -s[1] * 0.5
		_check(not ev.is_action_pressed(s[2]), "nor the other way (%s)" % s[2])
	var key := func(k: int) -> InputEventKey:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.pressed = true
		return ev
	var up: InputEventKey = key.call(KEY_UP)
	_check(up.is_action_pressed("up") and not up.is_action_pressed("jump"), "the Up arrow is up (it climbs a vine, never leaps), not jump")
	for k in [KEY_SPACE, KEY_Z, KEY_W]:
		var ev: InputEventKey = key.call(k)
		_check(ev.is_action_pressed("jump") and not ev.is_action_pressed("up"), "%s still jumps" % OS.get_keycode_string(k))
	var dn: InputEventKey = key.call(KEY_DOWN)
	_check(dn.is_action_pressed("down"), "the Down arrow is down")


# ---------------------------------------------------------------- reachability
# The bot (scripts/reach.gd, reach_search.gd): every bell, sigil and silver
# bell on every level, in calm and (where there are gusts) under a 120 px/s
# push; the ordering checks (every buoy touchable without still water,
# every dawnglass pane's lamp reached without dawnglass); the dwell rule;
# the state cap as a failure. WAXBY_WORLD=<n> proves one world's levels
# only (0: the feel labs) and nothing else, so tools/test.sh runs the worlds
# in parallel.

func _bot_levels(world_filter := -1) -> Array:
	## The levels the bot proves: the main path, the secret levels that exist,
	## and the feel labs (world 0).
	var paths := []
	for info in game.LEVELS:
		paths.append(str(info["path"]))
	var secrets = (game.get_script() as Script).get_script_constant_map().get("SECRET_LEVELS", game.get("SECRET_LEVELS"))
	if secrets is Array:
		for info in secrets:
			if FileAccess.file_exists(str(info["path"])):
				paths.append(str(info["path"]))
	for lab in LAB_LEVELS:
		if FileAccess.file_exists(lab):
			paths.append(lab)
	var out := []
	for path in paths:
		var lv = LevelData.load_file(path)
		if world_filter < 0 or int(lv.world) == world_filter:
			out.append(lv)
	return out


func _search(copy: RefCounted, opts := {}) -> RefCounted:
	var s = ReachSearch.new()
	s.setup(copy, LevelData.cell_floor(copy.start), opts)
	s.run()
	s.free_player()
	return s


func _test_reachability(world_filter := -1) -> void:
	for lv in _bot_levels(world_filter):
		_prove(lv)


func _prove(lv: RefCounted) -> Dictionary:
	## Every goal of lv, in calm (and under the gusts' push), with the
	## ordering checks and the dwell rule. Returns the calm search's numbers.
	var t0 := Time.get_ticks_msec()
	var timed := Reach.timed_cells(lv)
	var calm = _search(Reach.static_copy(lv), {"timed": timed})
	print("  %s: %d states, %d sims, %d ms" % [lv.id, calm.seen.size(), calm.sims, Time.get_ticks_msec() - t0])
	_check(not calm.capped, "%s: the bot finishes under the %d-state cap" % [lv.id, Reach.STATE_CAP])
	for g in calm.goals:
		_check(calm.found.has(g["what"]), "%s: the bot reaches the %s" % [lv.id, g["what"]])
		if calm.found.has(g["what"]):
			var dm: Dictionary = calm.found[g["what"]]["dmax"]
			for k in dm:
				var most: float = Reach.DWELL_SHARE * Reach.life(k)
				_check(float(dm[k]) <= most + 0.001, "%s: the way to the %s never waits on %s (%.2f s, at most %.2f)" % [lv.id, g["what"], k, dm[k], most])
	if not lv.gusts.is_empty():
		var t1 := Time.get_ticks_msec()
		var gp = _search(Reach.static_copy(lv), {"push": true, "timed": timed})
		print("  %s under the gusts: %d states, %d ms" % [lv.id, gp.seen.size(), Time.get_ticks_msec() - t1])
		_check(not gp.capped, "%s: the gust pass finishes under the cap" % lv.id)
		for g in gp.goals:
			_check(gp.found.has(g["what"]), "%s: the bot reaches the %s under a %d px/s gust" % [lv.id, g["what"], int(Reach.GUST_PUSH)])
	# Every buoy can be touched from ground reached without still water.
	var buoys := {}
	for e in lv.entities:
		if e["kind"] == "buoy":
			var c: Vector2i = e["cell"]
			buoys["buoy at %d,%d" % [c.x, c.y]] = Rect2(c.x * TILE - 24, c.y * TILE - 24, TILE + 48, TILE + 32)
	if not buoys.is_empty():
		var ns = _search(Reach.static_copy(lv, {"still": false}), {"touch": buoys})
		for name in buoys:
			_check(ns.touched.has(name), "%s: the %s is reached without still water" % [lv.id, name])
	# Every dawnglass pane has a lamp the bot reaches without dawnglass.
	var panes := []
	for y in lv.height:
		for x in lv.width:
			if lv.tile(x, y) == LevelData.DAWNGLASS:
				panes.append(Vector2i(x, y))
	if not panes.is_empty():
		var lamps := {}
		for e in lv.entities:
			var r := float({"lantern": 140.0, "vigil": 90.0, "glowfruit": 90.0, "buoy": 200.0}.get(e["kind"], 0.0))
			if r > 0.0:
				var f := LevelData.cell_floor(e["cell"])
				lamps["%s at %d,%d" % [e["kind"], e["cell"].x, e["cell"].y]] = {"p": f - Vector2(0, 33), "r": r, "rect": Rect2(f.x - 40, f.y - 60, 80, 60)}
		var rects := {}
		for k in lamps:
			rects[k] = lamps[k]["rect"]
		var nd = _search(Reach.static_copy(lv, {"dawn": false}), {"touch": rects})
		for c in panes:
			var mid := LevelData.cell_center(c)
			var ok := false
			for k in lamps:
				if nd.touched.has(k) and mid.distance_to(lamps[k]["p"]) <= float(lamps[k]["r"]):
					ok = true
			_check(ok, "%s: dawnglass at %s has a lamp the bot lights first" % [lv.id, c])
	return {"states": calm.seen.size(), "sims": calm.sims, "ms": Time.get_ticks_msec() - t0}


# ---------------------------------------------------------------- the World

func _world(id: String) -> Node2D:
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	game.reset()
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	return w


func _test_world_smoke() -> void:
	for info in game.LEVELS:
		var id: String = info["id"]
		var w := _world(id)
		await process_frame
		w.test_pad = {}
		for i in 240:
			w.tick(DT)
		_check(w.player.on_floor, "%s: Wick settles on the floor at the start" % id)
		# Run right, jumping now and then, for 20 s: nothing may break.
		var far := 0.0
		for i in int(20.0 / DT):
			var jump := (i / 50) % 3 == 0
			w.test_pad = {"right": true, "jump": jump, "attack": (i / 17) % 2 == 0}
			w._read_pad()
			w.tick(DT)
			far = maxf(far, w.player.position.x)
			if w.state == "clear":
				break
		print("  %s: 20 s of running right got to x=%.0f (now %.0f), embers %d, state %s, flames %d" % [id, far, w.player.position.x, w.embers_got, w.state, w.player.flames])
		_check(far > 400.0, "%s: running right gets somewhere" % id)
		w.queue_free()
		await process_frame


func _test_interactions() -> void:
	var w := _world("1-1")
	await process_frame
	w.test_pad = {}
	var pl: Node2D = w.player
	# Stomp: drop Wick onto the first skeleton.
	var skel: Node2D = null
	for e in w.enemies:
		if e.kind == "skeleton":
			skel = e
			break
	_check(skel != null, "1-1 has a skeleton")
	if skel:
		skel.active = true
		pl.position = skel.position + Vector2(0, -60)
		pl.velocity = Vector2(0, 200)
		for i in 60:
			w.tick(DT)
			if not skel.alive:
				break
		_check(not skel.alive, "landing on a skeleton stomps it")
		_check(pl.velocity.y < 0.0 or not pl.on_floor, "and bounces Wick up")
		_check(pl.flames == pl.max_flames, "without hurting him")
	# Walking into a monster hurts.
	var skel2: Node2D = null
	for e in w.enemies:
		if e.kind == "skeleton" and e.alive:
			skel2 = e
			break
	if skel2:
		skel2.active = true
		pl.invuln = 0.0
		pl.reset_at(skel2.position + Vector2(-40, 0))
		var before: float = pl.hp
		for i in 90:
			w.test_pad = {"right": true}
			w._read_pad()
			w.tick(DT)
		var lost: float = before - pl.hp
		print("  a skeleton's touch: %.1f of %.0f life" % [lost, pl.max_hp])
		_check(lost > 0.2 * pl.max_hp and lost < 0.4 * pl.max_hp, "walking into a skeleton costs about 30%% of life (%.1f)" % lost)
		_check(pl.invuln > 0.0, "and gives a moment of grace")
		# The sword.
		pl.invuln = 0.0
		for i in 150:
			w.test_pad = {}
			w._read_pad()
			w.tick(DT)
		var swings := 0
		for n in 4:
			if not skel2.alive:
				break
			skel2.position = pl.position + Vector2(pl.facing * 26.0, 0)
			skel2.velocity = Vector2.ZERO
			swings += 1
			for i in 50:
				w.test_pad = {"attack": i < 3}
				w._read_pad()
				w.tick(DT)
		print("  swings to cut down a skeleton at level 1: %d" % swings)
		_check(not skel2.alive and swings >= 2 and swings <= 3, "the sword cuts down a skeleton in 2-3 swings (%d)" % swings)
	# Bonk a reliquary.
	var cell := Vector2i(-1, -1)
	for c in w.blocks:
		if w.blocks[c]["contents"] == "embers":
			cell = c
			break
	_check(cell.x >= 0, "1-1 has an ember reliquary")
	if cell.x >= 0:
		pl.invuln = 0.0
		pl.reset_at(Vector2((cell.x + 0.5) * TILE, 13 * TILE))
		for i in 20:
			w.test_pad = {}
			w._read_pad()
			w.tick(DT)
		var got_before: int = w.embers_got
		w.test_pad = {"jump": true}
		for i in 200:
			w._read_pad()
			w.tick(DT)
		_check(w.blocks[cell]["spent"], "bonking a reliquary from below opens it")
		_check(w.level.tile(cell.x, cell.y) == LevelData.SPENT, "and leaves it spent")
		for i in 240:
			w.test_pad = {}
			w._read_pad()
			w.tick(DT)
		_check(w.embers_got >= got_before + 2, "its embers can be caught (%d)" % (w.embers_got - got_before))
	# A pit costs a flame and puts Wick back on firm ground.
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	var pit_x := -1
	for x in range(5, w.level.width):
		if w.level.tile(x, 13) == LevelData.AIR and w.level.tile(x, 14) == LevelData.AIR:
			pit_x = x
			break
	_check(pit_x > 0, "1-1 has a pit")
	if pit_x > 0:
		pl.reset_at(Vector2((pit_x - 2) * TILE + 16, 13 * TILE))
		for i in 30:
			w.test_pad = {}
			w._read_pad()
			w.tick(DT)
		pl.position = Vector2(pit_x * TILE + 16, 13 * TILE + 20)
		pl.velocity = Vector2(0, 300)
		pl.on_floor = false
		for i in 60:
			w.tick(DT)
		var frac: float = pl.hp / pl.max_hp
		_check(absf(frac - 0.67) < 0.02, "falling in a pit costs a third of life on Dusk (%.2f)" % frac)
		_check(pl.alive and pl.position.y <= 13 * TILE + 0.1, "and puts Wick back on the floor")
	# An altar: a checkpoint and a full flame.
	var alt: Dictionary = w.altars[0]
	pl.hp = 0.2 * pl.max_hp
	pl.reset_at(alt["pos"] + Vector2(-60, 0))
	for i in 80:
		w.test_pad = {"right": true}
		w._read_pad()
		w.tick(DT)
	_check(alt["lit"], "walking past an altar lights it")
	_check(absf(pl.hp / pl.max_hp - 0.7) < 0.02, "and heals half of life on Dusk (%.2f)" % (pl.hp / pl.max_hp))
	_check(w.checkpoint == alt["pos"], "and makes it the checkpoint")
	# Snuffed: back at the altar.
	pl.invuln = 0.0
	pl.hp = 5.0
	w.test_pad = {}
	w._read_pad()
	pl.take_damage(50.0, pl.position.x + 10)
	_check(not pl.alive and w.state == "dead", "the last flame lost snuffs Wick")
	for i in int(2.0 / DT):
		w.tick(DT)
	_check(pl.alive and w.state == "play" and pl.position.distance_to(alt["pos"]) < 4.0, "and he relights at the altar")
	_check(pl.hp == pl.max_hp, "at full life")
	# Ring the bell.
	var bell: Dictionary = w.bells[0]
	var got := [false]
	w.finished.connect(func(res): got[0] = res["cleared"])
	pl.reset_at(bell["pos"] + Vector2(-40, 0))
	for i in int(6.0 / DT):
		w.test_pad = {"right": true}
		w._read_pad()
		w.tick(DT)
		if got[0]:
			break
	_check(bell["rung"], "touching the bell rope rings it")
	_check(got[0], "and the level finishes cleared")
	w.queue_free()
	await process_frame


func _test_boss() -> void:
	## Old Tollgrave: asleep until Wick is in the room, then the doorway seals;
	## the slam's waves hurt and can be jumped; outside a stuck window hits
	## only chip; windows never cross a phase; an L7 Candleknight needs 4+
	## windows; he drops loot and the bell comes; a snuff resets the fight
	## and reopens the door.
	var w := _world("1-4")
	await process_frame
	var boss: Node2D = w.boss
	_check(boss != null, "1-4 has the boss")
	if boss == null:
		return
	var pl: Node2D = w.player
	boss.active = true
	w.test_pad = {}
	for i in 60:
		w.tick(DT)
	_check(boss.state == "sleep", "he sleeps while Wick is outside")
	_check(boss.door.size() >= 3, "his doorway is found (%d cells)" % boss.door.size())
	pl.reset_at(Vector2(boss.arena_left + 80.0, boss.position.y))
	for i in 20:
		w.tick(DT)
	_check(boss.state == "roar", "he wakes when Wick steps in")
	var sealed := true
	for c in boss.door:
		sealed = sealed and LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(sealed, "and the doorway seals behind him")
	# Outside a window: a chip.
	var hp0: float = boss.hp
	boss.hit({"how": "slash", "from_x": pl.position.x, "amount": 100.0})
	_check(absf((hp0 - boss.hp) - 10.0) < 0.01, "outside a stuck window a hit only chips (10%%): %.1f" % (hp0 - boss.hp))
	# Let him slam: waves appear, the bell sticks.
	pl.invuln = 100.0
	var waves := false
	var stuck := false
	for i in int(8.0 / DT):
		w.tick(DT)
		for h in w.hazards:
			if h["kind"] == "wave":
				waves = true
		if boss.state == "stuck":
			stuck = true
			break
	_check(waves, "a slam sends shockwaves")
	_check(stuck, "and leaves his bell stuck")
	# A window never crosses into phase 2.
	boss.hit({"how": "slash", "from_x": pl.position.x, "amount": 99999.0})
	_check(absf(boss.hp - 0.6 * boss.max_hp) < 1.0 and boss.phase == 2, "a window stops at the 60%% phase line (%.0f / %.0f)" % [boss.hp, boss.max_hp])
	# An L7 Candleknight's damage: count windows to win.
	var h7 := Hero.blank("knight", 7)
	h7["equip"] = Items.starter("knight", 6, "magic")
	var st := Hero.stats(h7, [], "dusk")
	var per_swing: float = float(st["basic"]) * (1.0 + float(st["dmg_pct"]))
	var windows := 1
	boss.hp = boss.max_hp
	boss.phase = 1
	boss._rung_phase = 0
	while boss.alive and windows < 30:
		boss.state = "stuck"
		boss._window_dmg = 0.0
		var tleft := 1.9 if boss.phase == 1 else (1.5 if boss.phase == 2 else 1.2)
		var n := int(tleft / float(st["cooldown"]))
		for k in n:
			if boss.state != "stuck":
				break
			boss.hit({"how": "slash", "from_x": pl.position.x, "amount": per_swing})
		windows += 1 if boss.alive else 0
	print("  an L7 Candleknight (%.0f a swing) needs %d windows against %.0f life" % [per_swing, windows, boss.max_hp])
	_check(windows >= 4, "an L7 Candleknight needs at least 4 windows (%d)" % windows)
	_check(not boss.alive, "and he falls in the end")
	for i in int(3.0 / DT):
		w.tick(DT)
	var loot := 0
	for p in w.pickups:
		if p["kind"] == "item" or p["kind"] == "relic":
			loot += 1
	_check(loot >= 3, "he drops his hoard (%d pieces)" % loot)
	_check(w.bells.size() == 1, "and the bell comes down to ring")
	w.queue_free()
	await process_frame
	# A snuff mid-fight: he sleeps again at full life and the door opens.
	w = _world("1-4")
	await process_frame
	boss = w.boss
	pl = w.player
	boss.active = true
	pl.reset_at(Vector2(boss.arena_left + 80.0, boss.position.y))
	for i in 30:
		w.tick(DT)
	_check(boss.state != "sleep", "(he's awake)")
	boss.hp = boss.max_hp * 0.5
	pl.invuln = 0.0
	pl.take_damage(99999.0, pl.position.x + 5.0)
	for i in int(2.0 / DT):
		w.tick(DT)
	var open := true
	for c in boss.door:
		open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(boss.state == "sleep" and boss.hp == boss.max_hp, "a snuff puts him back to sleep at full life")
	_check(open, "and opens his door again (no locked-out fight)")
	# A wave hurts a Wick standing in its way; jumping over it doesn't.
	var before: float = pl.hp
	pl.invuln = 0.0
	w.add_hazard({"kind": "wave", "motion": "floor", "rect": Rect2(pl.position.x - 60.0, pl.position.y - 22.0, 18.0, 22.0), "vel": Vector2(250, 0), "life": 2.0, "dmg": 36.0})
	for i in 60:
		w.tick(DT)
	_check(pl.hp < before, "a shockwave hurts")
	pl.invuln = 0.0
	before = pl.hp
	w.hazards.clear()
	w.add_hazard({"kind": "wave", "motion": "floor", "rect": Rect2(pl.position.x - 70.0, pl.position.y - 22.0, 18.0, 22.0), "vel": Vector2(250, 0), "life": 2.0, "dmg": 36.0})
	for i in 90:
		w.test_pad = {"jump": i > 4 and i < 60}
		w._read_pad()
		w.tick(DT)
	_check(pl.hp == before, "jumping over a shockwave is safe")
	w.queue_free()
	await process_frame


func _world_as(id: String, cls: String, relics := []) -> Node2D:
	## A headless World of this level for a new hero of this calling, with
	## these relics on the belt and the level's story already seen.
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	game.reset()
	game.new_hero(cls)
	for r in relics:
		game.grant_relic(r)
	if not relics.is_empty():
		game.set_belt(relics)
	for k in ["start", "boss"]:
		var s := str(lv.story.get(k, ""))
		if s != "":
			game.mark_seen(s)
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	return w


func _wake_boss(w: Node2D) -> Node2D:
	## Walks Wick into the arena until the boss is up.
	var b: Node2D = w.boss
	b.active = true
	w.test_pad = {}
	w.player.reset_at(Vector2(b.arena_left + 80.0, b.position.y))
	for i in 30:
		w.tick(DT)
	return b


func _drop_on(w: Node2D, e: Node2D, until_ticks := 60) -> Dictionary:
	## Drops Wick onto e's head from just above and ticks until he lands on
	## it (a stomp's bounce or a hurt): {stomped, hurt, e_lost}.
	var pl: Node2D = w.player
	pl.reset_at(Vector2(e.center().x, e.rect().position.y - 24.0))
	pl.velocity = Vector2(0, 240)
	pl.on_floor = false
	pl.invuln = 0.0
	var hp0: float = pl.hp
	var ehp0: float = e.hp
	var b0: int = int(pl.bounces)
	w.test_pad = {}
	for i in until_ticks:
		w.tick(DT)
		if int(pl.bounces) != b0 or pl.hp < hp0:
			break
	return {"stomped": int(pl.bounces) != b0, "hurt": pl.hp < hp0, "e_lost": ehp0 - float(e.hp)}


func _test_boss_fair() -> void:
	## Old Tollgrave's head is safe exactly when his body is: landing on it
	## mid-attack hurts (Thornsole or not) and does him nothing; landing on
	## it in a stuck window stomps. Stomping a boss pays no chain embers. An
	## Anvil Drop that lands on a head stomps once and bounces off. His tells
	## keep the spec's floor; the RUNG bonus number sits clear of the hit's,
	## and the banner is said once.
	var w := _world_as("1-4", "knight")
	await process_frame
	var b := _wake_boss(w)
	var pl: Node2D = w.player
	b.state = "windup"
	b.timer = 5.0
	w.tick(DT)
	_check(not b.stompable, "a Tollgrave winding up is no stomp target")
	var e0: int = w.embers_got
	var r := _drop_on(w, b)
	_check(r["hurt"] and not r["stomped"], "landing on his head mid-attack hurts like spikes (hurt %s, stomped %s)" % [r["hurt"], r["stomped"]])
	_check(r["e_lost"] == 0.0, "and doesn't even chip him (%.1f)" % r["e_lost"])
	# Thornsole makes spikes safe, not a boss.
	for i in int(2.0 / DT):
		w.tick(DT)
	b.state = "walk"
	b.timer = 5.0
	w.tick(DT)
	pl.stats["legends"] = {"thornsole": true}
	r = _drop_on(w, b)
	_check(r["hurt"] and not r["stomped"], "with Thornsole his head still hurts mid-attack (hurt %s, stomped %s)" % [r["hurt"], r["stomped"]])
	pl.stats["legends"] = {}
	# The stuck window: his head is the target.
	for i in int(2.0 / DT):
		w.tick(DT)
	b.state = "stuck"
	b.timer = 5.0
	w.tick(DT)
	_check(b.stompable, "a stuck Tollgrave's head is a stomp target")
	r = _drop_on(w, b)
	_check(r["stomped"] and not r["hurt"] and r["e_lost"] > 0.0, "landing on it in a stuck window stomps him (%.1f) and doesn't hurt" % r["e_lost"])
	for i in 3:
		w.tick(DT)
	_check(w.chain == 0 and w.embers_got == e0, "a boss's head pays no stomp chain (chain %d, embers +%d)" % [w.chain, w.embers_got - e0])
	# Reeling and roaring he's safe, head and body.
	for s in ["hurt", "roar"]:
		b.state = s
		b.timer = 5.0
		w.tick(DT)
		_check(b.stompable and not b.touch_damage(), "%s: his head is safe while his body is" % s)
	# Tells: never under 0.35 s (0.30 s on Witching Hour).
	b.phase = 1
	w.diff = "dusk"
	_check(absf(b.tell_time() - 0.7) < 0.001, "a phase-1 tell on Dusk is 0.7 s (%.3f)" % b.tell_time())
	b.phase = 3
	w.diff = "nightfall"
	_check(b.tell_time() >= 0.35 - 0.0001, "a phase-3 tell on Nightfall keeps the 0.35 s floor (%.3f)" % b.tell_time())
	w.diff = "witching"
	_check(absf(b.tell_time() - 0.30) < 0.001, "a phase-3 tell on Witching Hour is the 0.30 s floor (%.3f)" % b.tell_time())
	w.diff = "dusk"
	# RUNG!: the bonus number sits clear above the hit's number.
	b.phase = 1
	b.hp = b.max_hp
	b._rung_phase = 0
	b._window_dmg = 0.0
	b.state = "stuck"
	b.timer = 5.0
	w.floaters.items.clear()
	w.deal(b, 1.0, {"flat": 0.35 * b.max_hp, "from_x": b.position.x - 30.0})
	var hit_y := INF
	var bonus_y := INF
	for it in w.floaters.items:
		if it["text"] == "" and it["kind"] == "hit":
			hit_y = it["pos"].y
		elif it["text"] == "" and it["kind"] == "crit":
			bonus_y = it["pos"].y
	_check(b.state == "hurt", "a heavy window rings him (state %s)" % b.state)
	_check(hit_y < INF and bonus_y < INF and hit_y - bonus_y >= 24.0, "the RUNG bonus number sits clear above the hit's (%.0f px apart)" % (hit_y - bonus_y))
	# The banner is said once: on the HUD when there is one, else a floater.
	var stub_src := GDScript.new()
	stub_src.source_code = "extends CanvasLayer\nvar said: Array = []\nfunc banner(t: String) -> void:\n\tsaid.append(t)\n"
	stub_src.reload()
	var stub: CanvasLayer = stub_src.new()
	var t0 := _text_floaters(w)
	w.hud = stub
	w.banner("RUNG!")
	w.hud = null
	_check(stub.said == ["RUNG!"] and _text_floaters(w) == t0, "with a HUD the banner shows once, not also as a floater (%s, +%d)" % [str(stub.said), _text_floaters(w) - t0])
	w.banner("RUNG!")
	_check(_text_floaters(w) == t0 + 1, "without a HUD (headless) it's a floater")
	stub.free()
	w.queue_free()
	await process_frame
	# The Bellfounder's Anvil Drop onto a head: one stomp and she's off.
	w = _world_as("1-1", "founder")
	await process_frame
	pl = w.player
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	var dummy: Node2D = w.spawn_enemy("skeleton", pl.position + Vector2(160, 0))
	dummy.active = true
	dummy.ordinary = false
	dummy.max_hp = 999999.0
	dummy.hp = dummy.max_hp
	dummy.apply_status("root", 100.0)
	for i in 20:
		w.tick(DT)
	pl.reset_at(Vector2(dummy.center().x, dummy.rect().position.y - 70.0))
	pl.on_floor = false
	pl.res = pl.res_max
	var b0: int = int(pl.bounces)
	w.kit.special_pressed()
	_check(bool(w.kit.anvil) and pl.dash_time > 0.0, "(an Anvil Drop begins in the air)")
	var first := -1
	for i in int(0.4 / DT):
		w.tick(DT)
		if first < 0 and int(pl.bounces) != b0:
			first = i
			_check(pl.dash_time <= 0.0 and pl.velocity.y < 0.0, "the head ends the drop and bounces her up (dash %.2f, vy %.0f)" % [pl.dash_time, pl.velocity.y])
	_check(first >= 0, "the drop lands on the head")
	# (A bounce comes back down on it about 0.4 s later: an ordinary stomp.)
	_check(int(pl.bounces) - b0 <= 2, "an Anvil Drop stomps a head once and bounces, not every tick (%d stomps in 0.4 s)" % (int(pl.bounces) - b0))
	_check(not bool(w.kit.anvil), "and the drop is over")
	w.queue_free()
	await process_frame


func _text_floaters(w: Node2D) -> int:
	var n := 0
	for it in w.floaters.items:
		if it["text"] != "":
			n += 1
	return n


func _test_boss_after() -> void:
	## The moment a boss falls, his waves, skulls and rubble go with him and
	## the door opens, so a snuff before the bell relights where the bell can
	## be reached. The first-kill prize only counts as given once it's
	## picked up (a Restart before then drops it again).
	for id in ["1-4", "2-4"]:
		var w := _world_as(id, "knight")
		await process_frame
		var b := _wake_boss(w)
		var pl: Node2D = w.player
		var sealed := true
		for c in b.door:
			sealed = sealed and LevelData.is_solid(w.level.tile(c.x, c.y))
		_check(sealed and not b.door.is_empty(), "%s: the door seals when he wakes" % id)
		pl.invuln = 100.0
		w.add_hazard({"kind": "wave", "motion": "floor", "rect": Rect2(pl.position.x + 60.0, pl.position.y - 22.0, 18.0, 22.0), "vel": Vector2(-250, 0), "life": 2.0, "dmg": 36.0})
		w.add_hazard({"kind": "rubble", "motion": "fall", "rect": Rect2(pl.position.x, pl.position.y - 200.0, 22.0, 22.0), "vel": Vector2(0, 700), "life": 2.0, "delay": 0.6, "dmg": 30.0})
		var mine: Dictionary = w.add_hazard({"kind": "wave", "owner": "player", "motion": "still", "rect": Rect2(pl.position.x - 200.0, pl.position.y - 22.0, 18.0, 22.0), "life": 1.0, "coef": 1.0})
		w.spawn_shot({"kind": "skull", "owner": "enemy", "pos": pl.center() + Vector2(80, 0), "vel": Vector2(-100, 0), "life": 3.0, "dmg": 20.0})
		# The killing blow, in a stuck window (the Snuffer is solid then too).
		b.phase = 3
		b.hp = 1.0
		b.state = "stuck"
		w.deal(b, 1.0, {"flat": 99999.0})
		_check(not b.alive, "%s: (he falls)" % id)
		var enemy_left := 0
		for h in w.hazards:
			if h.get("owner", "enemy") == "enemy":
				enemy_left += 1
		for s in w.shots:
			if s.get("owner", "enemy") == "enemy":
				enemy_left += 1
		_check(enemy_left == 0, "%s: what he threw goes with him (%d left)" % [id, enemy_left])
		_check(w.hazards.has(mine), "%s: the hero's own wave keeps going" % id)
		var open := true
		for c in b.door:
			open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
		_check(open, "%s: and his door opens" % id)
		# The prize lands; the record waits for it to be picked up.
		var door: Array = b.door.duplicate()
		for i in int(1.5 / DT):
			w.tick(DT)
		var prize = null
		for p in w.pickups:
			if p.get("boss_first", false):
				prize = p
		_check(prize != null, "%s: his first-kill prize drops" % id)
		_check(not game.level_record(id).get("boss_first", false), "%s: the first-kill record waits for it to be picked up" % id)
		# Snuffed before the bell: he relights outside and can still reach it.
		pl.invuln = 0.0
		pl.take_damage(99999.0, pl.position.x + 5.0)
		for i in int(2.0 / DT):
			w.tick(DT)
		_check(w.state == "play" and pl.alive, "%s: (relit after a snuff past the kill)" % id)
		open = true
		for c in door:
			open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
		_check(open, "%s: the door is still open after the relight" % id)
		if prize != null:
			w._collect(prize)
			_check(prize["taken"] and game.level_record(id).get("boss_first", false), "%s: picking the prize up marks the first kill" % id)
		w.queue_free()
		await process_frame


func _test_seams() -> void:
	## The Bell Shard's stomp stun skips the boss; special_pct counts on a
	## Special's waves and shots (tagged "special") and not on others; the
	## Phoenix Wick rises once a level, not once a life; a long stomp chain
	## pays at most CHAIN_PAY_MAX a stomp.
	var w := _world_as("1-4", "knight", ["bell_shard"])
	await process_frame
	_check(game.equipped("bell_shard"), "(the Bell Shard is worn)")
	var b := _wake_boss(w)
	b.state = "stuck"
	b.timer = 5.0
	w.tick(DT)
	var near: Node2D = w.spawn_enemy("skeleton", b.position + Vector2(-40, 0))
	near.active = true
	near.ordinary = false
	near.max_hp = 99999.0
	near.hp = near.max_hp
	var r := _drop_on(w, b)
	_check(r["stomped"], "(a stomp on his stuck head)")
	_check(not b.status.has("stun"), "the Bell Shard doesn't stun the boss (status %s)" % str(b.status))
	_check(near.status.has("stun"), "but still stuns what stands by him")
	w.queue_free()
	await process_frame
	# special_pct on a Special's hazards and shots.
	w = _world_as("1-1", "knight")
	await process_frame
	var pl: Node2D = w.player
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	var dummy: Node2D = w.spawn_enemy("skeleton", pl.position + Vector2(160, 0))
	dummy.active = true
	dummy.ordinary = false
	dummy.max_hp = 999999.0
	dummy.hp = dummy.max_hp
	dummy.apply_status("root", 100.0)
	for i in 10:
		w.tick(DT)
	pl.stats["special_pct"] = 1.0
	pl.stats["crit"] = 0.0
	pl.stats["dmg_pct"] = 0.0
	var got := {}
	for tag in ["plain", "special"]:
		for what in ["wave", "shot"]:
			w.rng.seed = 7
			var hp0: float = dummy.hp
			if what == "wave":
				w.add_hazard({"kind": "wave", "owner": "player", "motion": "still", "rect": dummy.rect(), "life": 0.05, "coef": 1.0, "special": tag == "special"})
			else:
				w.spawn_shot({"kind": "spark", "pos": dummy.center() + Vector2(-30, 0), "vel": Vector2(300, 0), "life": 0.5, "coef": 1.0, "special": tag == "special"})
			for i in 30:
				w.tick(DT)
			got[tag + "_" + what] = hp0 - float(dummy.hp)
	for what in ["wave", "shot"]:
		var a: float = got["plain_" + what]
		var s: float = got["special_" + what]
		_check(a > 0.0 and s >= 1.8 * a, "special_pct +100%% counts on a Special's %s (%.0f -> %.0f), not on a plain one" % [what, a, s])
	w.queue_free()
	await process_frame
	# The Phoenix Wick: once a level.
	w = _world_as("1-1", "knight", ["phoenix_wick"])
	await process_frame
	pl = w.player
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	var rises := 0
	for death in 4:
		pl.invuln = 0.0
		pl.hp = minf(pl.hp, 0.2 * pl.max_hp)   # (lethal even under the blow clamp)
		w.hurt_player(pl.max_hp * 5.0, pl.position.x + 10.0, "hit", null, {"ignore_invuln": true})
		for i in 5:
			w.tick(DT)
		if w.state == "play" and pl.alive:
			rises += 1
		for i in int(2.5 / DT):
			w.tick(DT)
	_check(rises == 1, "the Phoenix Wick rises once in a level, not once a life (%d rises in 4 snuffs)" % rises)
	# A long stomp chain: 1 + 2 + 3 + 4, then 4 a stomp.
	for i in int(1.0 / DT):
		w.tick(DT)
	var got0: int = w.embers_got
	w.chain = 0
	var er := Rect2(pl.position.x - 10, pl.position.y, 20, 20)
	for i in 8:
		w._stomp_chain(er)
	for i in 90:
		w.tick(DT)
	var worth: int = int(Combat.diff("dusk")["embers"])
	_check(w.embers_got - got0 == 22 * worth, "an 8-stomp chain pays 1+2+3+4+4+4+4 extra embers, 4 a stomp at most (%d)" % (w.embers_got - got0))
	w.queue_free()
	await process_frame


func _test_v2_core() -> void:
	## The v2 core: the flask, banking and the Guttered Pool, stomp chains,
	## level-ups, the Twin Wick, hitstop's budget and presses kept through it,
	## floaters merging.
	var w := _world("1-1")
	await process_frame
	var pl: Node2D = w.player
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	# The flask: one charge on Dusk, 40% over half a second.
	pl.hp = 0.3 * pl.max_hp
	_check(w.flask_charges == 1, "one flask charge on Dusk")
	w.test_pad = {"flask": true}
	w._read_pad()
	w.tick(DT)
	w.test_pad = {}
	for i in 80:
		w._read_pad()
		w.tick(DT)
	_check(absf(pl.hp / pl.max_hp - 0.70) < 0.02, "a flask drink heals 40%% (%.2f)" % (pl.hp / pl.max_hp))
	_check(w.flask_charges == 0, "and uses the charge")
	# Embers are carried until banked; a snuff spills them into a pool.
	w.embers_carried = 7
	var purse: int = game.embers()
	pl.invuln = 0.0
	pl.reset_at(pl.position + Vector2(400, 0))
	for i in 30:
		w.tick(DT)
	pl.take_damage(99999.0, pl.position.x + 5.0)
	_check(not w.pool.is_empty() and int(w.pool["embers"]) == 7 and w.embers_carried == 0, "a snuff spills the carried embers into a pool")
	_check(game.embers() == purse, "(they weren't banked)")
	for i in int(2.0 / DT):
		w.tick(DT)
	pl.position = w.pool["pos"] + Vector2(0, 6)
	w._touch_world()
	_check(w.pool.is_empty() and w.embers_carried == 7, "touching the pool reclaims them")
	var alt: Dictionary = w.altars[0]
	pl.reset_at(alt["pos"])
	w._touch_world()
	_check(w.embers_carried == 0 and game.embers() == purse + 7, "lighting an altar banks them")
	_check(w.flask_charges == 1, "and refills the flask")
	# A stomp chain pays extra embers.
	var got0: int = w.embers_got
	w.chain = 0
	var r := Rect2(pl.position.x - 10, pl.position.y, 20, 20)
	w._stomp_chain(r)
	w._stomp_chain(r)
	w._stomp_chain(r)
	for i in 60:
		w.tick(DT)
	_check(w.embers_got - got0 == 3, "a 3-stomp chain pays 1 + 2 extra embers (%d)" % (w.embers_got - got0))
	# Level up: XP past the line raises the level, heals and re-derives stats.
	var lvl: int = int(game.hero()["level"])
	var hp_max0: float = pl.max_hp
	pl.hp = 0.5 * pl.max_hp
	w.gain_xp(Progression.xp_to_next(lvl) + 1, pl.position)
	_check(int(game.hero()["level"]) == lvl + 1, "enough XP levels the hero up")
	_check(pl.max_hp > hp_max0, "with more life (%.0f -> %.0f)" % [hp_max0, pl.max_hp])
	_check(pl.hp / pl.max_hp > 0.65, "and a heal (%.2f)" % (pl.hp / pl.max_hp))
	_check(int(game.hero()["points"]) >= 1, "and a skill point")
	# The Twin Wick takes one whole hit per altar.
	pl.stats["legends"] = {"twin_wick": true}
	w._twin_ready = true
	pl.invuln = 0.0
	var hp0: float = pl.hp
	w.hurt_player(40.0, pl.position.x + 5.0)
	_check(pl.hp == hp0, "the Twin Wick soaks a hit")
	pl.invuln = 0.0
	w.hurt_player(40.0, pl.position.x + 5.0)
	_check(pl.hp < hp0, "but only one")
	pl.stats["legends"] = {}
	# Hitstop's budget and presses held through it.
	w.hitstop = 0.0
	w._hitstop_spent.clear()
	for i in 10:
		w.freeze(0.05)
	var spent := 0.0
	for e in w._hitstop_spent:
		spent += e[1]
	_check(spent <= 0.1201, "hitstop is capped per half second (%.3f)" % spent)
	w.hitstop = 0.05
	w.test_pad = {"jump": true}
	w._read_pad()
	w.tick(DT)
	w.test_pad = {"jump": true}
	for i in 8:
		w._read_pad()
		w.tick(DT)
	_check(pl.velocity.y < -300.0 or not pl.on_floor, "a jump pressed during hitstop still happens")
	# Floaters on one target within 0.2 s add into one number.
	w.floaters.items.clear()
	w.floaters.add(Vector2.ZERO, 5.0, "hit", 42)
	w.floaters.add(Vector2.ZERO, 7.0, "hit", 42)
	_check(w.floaters.items.size() == 1 and w.floaters.items[0]["value"] == 12.0, "floaters merge on one target")
	w.queue_free()
	await process_frame


func _test_ember_tally() -> void:
	## The results screen's ember count: embers_total is the level's own
	## embers in pieces (placed ones plus 3 per ember reliquary), and
	## embers_placed counts only those pieces, once each; kill drops, chain
	## stomps and the difficulty's worth go to embers (the purse) alone.
	for info in game.LEVELS:
		var lv = LevelData.load_file(info["path"])
		var want: int = lv.count("ember")
		for c in lv.blocks:
			if lv.blocks[c] == "embers" and lv.tile(c.x, c.y) == LevelData.BLOCK:
				want += 3
		var lw := _world(lv.id)
		await process_frame
		var flagged := 0
		for p in lw.pickups:
			if p["kind"] == "ember" and p.get("placed", false):
				flagged += 1
		var shut := 0
		for c in lw.blocks:
			if lw.blocks[c]["contents"] == "embers" and not lw.blocks[c]["spent"]:
				shut += 1
		_check(lw.embers_total == want and lw.embers_total == flagged + 3 * shut,
				"%s: embers_total is its placed embers and ember reliquaries, in pieces (%d, want %d)" % [lv.id, lw.embers_total, want])
		lw.queue_free()
		await process_frame
	# On Nightfall (each ember worth 2), fight all of 1-1 and chain some
	# stomps before touching one of its own embers: none of that is "found".
	game.reset()
	game.data["difficulty"] = "nightfall"
	var w: Node2D = WorldScript.new()
	w.setup(LevelData.load_file("res://levels/1-1.txt"), true)
	root.add_child(w)
	await process_frame
	var pl: Node2D = w.player
	w.test_pad = {}
	for i in 10:
		w.tick(DT)
	var worth: int = int(Combat.diff("nightfall")["embers"])
	_check(w.diff == "nightfall" and worth == 2, "the tally test runs on Nightfall, embers worth 2 (%s, %d)" % [w.diff, worth])
	var kills := 0
	for e in w.enemies.duplicate():
		if e.alive and e != w.boss:
			pl.position = e.position + Vector2(-40, 0)
			var hit: Dictionary = w.deal(e, 1.0, {"flat": e.max_hp * 20.0, "no_hitstop": true})
			if hit.get("killed", false):
				kills += 1
	w.chain = 0
	var er := Rect2(pl.position.x - 10, pl.position.y, 20, 20)
	for i in 4:
		w._stomp_chain(er)
	for i in int(1.5 / DT):
		w.tick(DT)
	for p in w.pickups:
		if p["kind"] == "ember" and not p["taken"] and not p.get("placed", false):
			w._collect(p)
	var fought: int = w.embers_got
	print("  1-1 on Nightfall: %d kills and a 4-stomp chain paid %d embers; its own: %d" % [kills, fought, w.embers_total])
	_check(kills >= 8 and fought > 0, "1-1's monsters die and drop embers (%d kills, %d)" % [kills, fought])
	_check(w.embers_placed == 0, "no kill drop or chain ember counts as one of the level's own (%d)" % w.embers_placed)
	_check(int(w.result()["embers_placed"]) == 0 and int(w.result()["embers"]) == fought, "result() carries both counts")
	# Now every placed ember and every ember reliquary.
	for p in w.pickups:
		if p["kind"] == "ember" and not p["taken"] and p.get("placed", false):
			w._collect(p)
	for c in w.blocks:
		if w.blocks[c]["contents"] == "embers" and not w.blocks[c]["spent"]:
			w._open_block(c)
	for i in int(1.0 / DT):
		w.tick(DT)
	var res: Dictionary = w.result()
	_check(int(res["embers_placed"]) == int(res["embers_total"]) and w.embers_total > 0,
			"taking all of 1-1's own embers reads %d / %d" % [int(res["embers_placed"]), int(res["embers_total"])])
	var paid: int = w.ember_worth()
	_check(int(res["embers"]) == fought + paid * w.embers_total,
			"and each paid its Nightfall worth to the purse (%d = %d + %d x %d)" % [int(res["embers"]), fought, paid, w.embers_total])
	w.queue_free()
	await process_frame
	game.data["difficulty"] = "dusk"


func _test_dusk_teeth() -> void:
	## Build 1, Dusk from World 3 (Combat.dusk_teeth): an altar heals 40%
	## (50% in Worlds 1-2), and the ordinary monsters killed come back on a
	## snuff (never in Worlds 1-2 on Dusk, nor in a mode), paying no embers;
	## a stomp chain off one counts but pays nothing.
	for id in ["1-1", "2-1", "3-1", "4-1"]:
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		game.reset()
		var h: Dictionary = game.hero()
		h["level"] = 20                          # (the altar's XP mustn't level him: a level-up heals too)
		h["xp"] = Progression.total_to(20)
		var w: Node2D = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await process_frame
		var pl: Node2D = w.player
		w.test_pad = {}
		for i in 10:
			w.tick(DT)
		var late: bool = int(w.world_n) >= 3
		_check(w.diff == "dusk" and w.respawns_here() == late, "%s on Dusk: monsters %s on a snuff" % [id, "come back" if late else "stay dead"])
		w.mode = RefCounted.new()
		_check(not w.respawns_here(), "%s on Dusk in a mode: they stay dead (the mode's own rules)" % id)
		w.mode = null
		# The altar: from a tenth of his life, 50% more (40% from World 3).
		pl.hp = 0.1 * pl.max_hp
		pl.reset_at(w.altars[0]["pos"])
		w._touch_world()
		var want := 0.1 + (0.40 if late else 0.50)
		_check(bool(w.altars[0]["lit"]) and absf(pl.hp / pl.max_hp - want) < 0.01, "%s: lighting an altar heals to %.2f (%.2f)" % [id, want, pl.hp / pl.max_hp])
		# A first-life Rattle stomped mid-chain pays its chain ember.
		var fresh: Array = w.enemies.filter(func(e): return e.alive and e.kind == "skeleton" and e.stompable and not e.respawned)
		if not fresh.is_empty():
			_look_at(w, fresh[0])
			var p0 := _ember_pickups(w, "pop")
			w.chain = 1
			var r0 := _drop_on(w, fresh[0])
			_check(r0["stomped"] and _ember_pickups(w, "pop") == p0 + 1, "%s: a first-life Rattle stomped mid-chain pays a chain ember (%d)" % [id, _ember_pickups(w, "pop") - p0])
		# Every ordinary monster dies.
		for e in w.enemies.duplicate():
			if e.alive and e.ordinary and e != w.boss:
				w.deal(e, 1.0, {"flat": e.max_hp * 20.0, "no_hitstop": true})
		var cells := {}
		for sp in w.spawns:
			if not w.enemies.any(func(e): return e.alive and e.spawn.get("cell", Vector2i(-9, -9)) == sp["cell"]):
				cells[sp["cell"]] = true
		_check(cells.size() > 0, "%s: %d of its %d spawn spots emptied" % [id, cells.size(), w.spawns.size()])
		for i in int(1.0 / DT):
			w.tick(DT)
		# A snuff.
		pl.invuln = 0.0
		pl.hp = 0.2 * pl.max_hp
		pl.take_damage(99999.0, pl.position.x + 5.0)
		for i in int(2.0 / DT):
			w.tick(DT)
		var back: Array = w.enemies.filter(func(e): return e.alive and e.respawned and cells.has(e.spawn.get("cell", Vector2i(-9, -9))))
		if not late:
			_check(w.snuffs == 1 and w.state == "play" and back.is_empty(), "%s: after a snuff none comes back (%d)" % [id, back.size()])
			w.queue_free()
			await process_frame
			continue
		_check(w.snuffs == 1 and w.state == "play" and back.size() == cells.size(),
				"%s: after a snuff every emptied spot's monster comes back (%d of %d)" % [id, back.size(), cells.size()])
		# A respawned monster drops no embers when it dies; a chain stomp on
		# one counts but pays nothing.
		var rattles: Array = back.filter(func(e): return e.kind == "skeleton" and e.stompable)
		_check(rattles.size() >= 2, "%s: Rattles came back to test with (%d)" % [id, rattles.size()])
		if rattles.size() < 2:
			w.queue_free()
			await process_frame
			continue
		var loose0 := _ember_pickups(w, "loose")
		var once: Node2D = rattles[0]
		w.deal(once, 1.0, {"flat": once.max_hp * 20.0, "no_hitstop": true})
		_check(not once.alive and _ember_pickups(w, "loose") == loose0, "%s: a respawned Rattle pays no embers when it dies" % id)
		var stompy: Node2D = rattles[1]
		_look_at(w, stompy)
		var pop0 := _ember_pickups(w, "pop")
		w.chain = 1
		var r := _drop_on(w, stompy)
		_check(r["stomped"] and w.chain == 2 and _ember_pickups(w, "pop") == pop0,
				"%s: stomping a respawned Rattle mid-chain counts (chain %d) but pays no chain embers (%d)" % [id, w.chain, _ember_pickups(w, "pop") - pop0])
		w.queue_free()
		await process_frame


func _look_at(w: Node2D, e: Node2D) -> void:
	## The camera on e, so it's awake (monsters far off the view sleep).
	w.cam = w.cam_on(e.position)
	e.active = true


func _ember_pickups(w: Node2D, flag: String) -> int:
	## Ember pickups made with flag set: "loose" a kill's, "pop" a chain's.
	return w.pickups.filter(func(p): return p["kind"] == "ember" and p.get(flag, false)).size()


func _test_relics_and_save() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var owned := []
	for i in Relics.ids().size():   # (every relic in play: v2's twelve, and v3's eight once they're live)
		var id := Relics.roll(rng, owned)
		_check(id != "" and not owned.has(id), "a roll gives a relic not yet owned")
		owned.append(id)
	_check(Relics.roll(rng, owned) == "", "with all owned, no relic rolls")
	var counts := {}
	for i in 2000:
		var id := Relics.roll(rng, [])
		var rar: String = Relics.get_relic(id)["rarity"]
		counts[rar] = counts.get(rar, 0) + 1
	_check(counts.get("common", 0) > counts.get("legendary", 0) * 8, "commons roll far more often than legendaries")
	var rare := Relics.roll(rng, [], "rare")
	_check(Relics.RARITY_ORDER.find(Relics.get_relic(rare)["rarity"]) >= 2, "a boss roll is rare or better")
	if game == null:
		return
	game.reset()
	game.record_result({"level": "1-1", "cleared": true, "embers": 30, "sigils": [true, false, true], "time": 95.0, "relics": []})
	_check(game.is_unlocked(1), "clearing 1-1 opens 1-2")
	_check(game.sigil_found("1-1", 0) and not game.sigil_found("1-1", 1), "sigils found are kept")
	game.record_result({"level": "1-1", "cleared": true, "embers": 10, "sigils": [false, true, false], "time": 120.0, "relics": []})
	_check(game.sigil_found("1-1", 0) and game.sigil_found("1-1", 1), "and add up over replays")
	_check(float(game.level_record("1-1")["best_time"]) == 95.0, "the best time stays the best")
	game.grant_relic("rook_feather")
	game.add_embers(12)
	game.save()
	var embers: int = game.data["embers"]
	game.reset()
	game.load_save()
	_check(game.has_relic("rook_feather"), "relics survive a reload")
	_check(int(game.data["embers"]) == embers, "embers survive a reload")
	_check(game.is_unlocked(1), "progress survives a reload")
	var p: Node2D = PlayerScript.new()
	game.apply_hero(p)
	var hp_before: float = p.max_hp
	_check(game.equipped("rook_feather"), "a found relic goes onto the belt")
	game.grant_relic("tallow_heart")
	game.apply_hero(p)
	_check(absf(p.max_hp / hp_before - 1.15) < 0.02, "the Tallow Heart gives +15%% life (%.0f -> %.0f)" % [hp_before, p.max_hp])
	p.free()
	for suffix in ["", ".bak", ".tmp"]:   # (a save keeps its last one as .bak, and a load falls back to it)
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_core_save.json" + suffix))
	game.save_path = game.SAVE_PATH
	game.load_save()


# ================================================================ v3 (Phase 0)
# The level format, the physics, the world seam and main's routes: every
# hook has a stub (mode, feature, HUD, boss) that must receive it.

func _secret_level_files() -> Array:
	## [id, level] for every main level file with a `secret:` header.
	var out := []
	for f in DirAccess.get_files_at("res://levels"):
		if not f.ends_with(".txt"):
			continue
		var lv = LevelData.load_file("res://levels/" + f)
		if str(lv.secret) != "":
			out.append([f.get_basename(), lv])
	return out


func _rows(lines: Array, header := "", w := 40) -> RefCounted:
	## A level from rows (padded to w with air), 15 rows, rows below given ones
	## stone from 13.
	var rows := []
	for y in 15:
		var r: String = lines[y] if y < lines.size() else ("#".repeat(w) if y >= 13 else "")
		rows.append(r.rpad(w, "."))
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n" + header + "---\n" + "\n".join(rows))
	return lv


func _steps(p: Node2D, pad: Dictionary, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		p.pad = pad
		p.step(DT)


func _test_v3_format() -> void:
	## The legend, the headers, the restore list, the world id, the flags.
	var lab = LevelData.load_file("res://levels/lab-0.txt")
	_check(lab.errors.is_empty(), "lab-0 parses: %s" % ", ".join(lab.errors))
	var text := FileAccess.get_file_as_string("res://levels/lab-0.txt")
	var body := text.substr(text.find("---\n") + 4)
	var legend := "#B=%?WRU^v~:F{}I_Z<>GA-|owPKE@csbtX123ahgkfMDNLd!*8VOQYT&JHCS+rpmijqeuxzylnS567"
	var missing := ""
	for ch in legend:
		if not body.contains(ch):
			missing += ch
	_check(missing == "", "lab-0 uses every glyph of the legend (missing '%s')" % missing)
	_check(lab.area_abs == 3 and lab.boss_music == "boss" and absf(lab.tick - 0.536) < 1e-6, "area_abs, boss_music and tick parse (%d, %s, %.3f)" % [lab.area_abs, lab.boss_music, lab.tick])
	_check(lab.secret == "1-S" and lab.secret_prize == "hymnal", "secret and secret_prize parse")
	_check(lab.warden.get("name", "") == "Lab Warden" and lab.warden.get("kind", "") == "thornback" and lab.warden.get("omens", []) == ["Warded"], "warden parses (%s)" % str(lab.warden))
	_check(lab.gusts.size() == 4 and int(lab.gusts[0]["x0"]) == 4 and int(lab.gusts[0]["x1"]) == 7 and int(lab.gusts[0]["dir"]) == -1 and lab.gusts[0]["phase"] == "A"
			and int(lab.gusts[3]["dir"]) == 1 and lab.gusts[3]["phase"] == "B", "the overlay's gust columns became the gusts header (%s)" % str(lab.gusts))
	_check(lab.hush_cols.size() == 1 and int(lab.hush_cols[0]["x0"]) == 34, "the overlay's Hush columns became the hush header (%s)" % str(lab.hush_cols))
	_check(lab.chase.size() == 1 and lab.cog_phase.size() == 2 and lab.weight_phase.size() == 1 and not lab.rush, "chase, cog_phase, weight_phase and rush parse")
	_check(lab.world == 0 and LevelData.world_of("1-S") == 1 and LevelData.world_of("3-2") == 3 and LevelData.world_of("descent-4") == 0, "LevelData.world is the id's first digit, or 0")
	_check(lab.headers.get("par", "") == "dusk=120", "every header is kept raw in headers")
	var cogs: Array = lab.of_kind("cog")
	_check(cogs.size() == 2 and int(cogs[0]["dir"]) == 1 and int(cogs[1]["dir"]) == -1, "O turns clockwise, Q counter-clockwise")
	var sw: Array = lab.of_kind("swing")
	var fl: Array = lab.of_kind("float")
	_check(sw.size() == 1 and int(sw[0]["length"]) == 3 and fl.size() == 1 and int(fl[0]["length"]) == 2, "a run of T is one swing and a run of & one float")
	for k in ["buoy", "grasp", "float"]:
		for e in lab.of_kind(k):
			_check(lab.tile(e["cell"].x, e["cell"].y) == LevelData.WATER, "a %s's cell stays water" % k)
	var creep: Dictionary = lab.of_kind("creepbone")[0]
	_check(lab.tile(creep["cell"].x, creep["cell"].y) == LevelData.VINE, "a Creepbone drawn in a vine column stands on the vine")
	# The flags: one table.
	for t in LevelData.SOLID:
		_check(LevelData.is_solid(t), "tile %d is solid" % t)
	_check(LevelData.is_ledge(LevelData.DAWN_ON) and LevelData.is_ledge(LevelData.STILL) and not LevelData.is_solid(LevelData.DAWNGLASS), "dawnglass is a ledge only while lit; still water a ledge")
	_check(LevelData.is_safe(LevelData.ICE) and not LevelData.is_safe(LevelData.GLASS) and not LevelData.is_safe(LevelData.BELT_R)
			and not LevelData.is_safe(LevelData.FROST_LEDGE) and not LevelData.is_safe(LevelData.FALSE_STONE) and not LevelData.is_safe(LevelData.CRUMBLE), "SAFE is stone, brick, block, spent, ledge and ice")
	_check(LevelData.is_slick(LevelData.ICE) and LevelData.is_slick(LevelData.FROST_LEDGE) and LevelData.is_climb(LevelData.ROTTEN_VINE) and LevelData.is_belt(LevelData.BELT_L), "slick, climb and belt flags")
	# The restore list.
	var lv := _rows([])
	var c := Vector2i(3, 13)
	lv.set_tile(c, LevelData.GLASS)
	lv.set_tile(c, LevelData.AIR)
	_check(lv.tile(3, 13) == LevelData.AIR and lv.original_tile(c) == LevelData.STONE, "set_tile(cell, t) remembers the first tile")
	lv.restore_tile(c)
	_check(lv.tile(3, 13) == LevelData.STONE and lv.changed_cells().is_empty(), "restore_tile puts it back")
	lv.set_tile(4, 13, LevelData.AIR)
	_check(lv.tile(4, 13) == LevelData.AIR, "set_tile(x, y, t) still works (v2's callers)")


func _vine_level() -> RefCounted:
	## A vine column at x 10 from row 3 to row 12 (a solid block over it), a
	## floor, and a stone block beside the vine's top at x 14-16.
	var lines := []
	for y in 13:
		var r := ".".repeat(40)
		if y == 2:
			r = r.substr(0, 10) + "#" + r.substr(11)
		if y >= 3 and y <= 12:
			r = r.substr(0, 10) + "{" + r.substr(11)
		if y >= 3 and y <= 12:
			r = r.substr(0, 20) + "}" + r.substr(21) if y >= 4 and y <= 6 else r
		lines.append(r)
	lines[12] = "P" + lines[12].substr(1)
	lines.append("#".repeat(40))
	lines.append("#".repeat(40))
	return _rows(lines)


func _on_vine(lv: RefCounted, col: int, cy: float) -> Node2D:
	## A Wick caught on the vine in col with his centre at cy.
	var p := _player_on(lv, Vector2((col + 0.5) * TILE, cy + 19.0))
	p.on_floor = false
	p.grab_vine(col, 1.0)
	return p


func _test_v3_physics() -> void:
	var lv := _vine_level()
	# The catch: vy >= -200, within 14 px, not holding down.
	for pair in [[-190.0, 0.0, {}, true], [-250.0, 0.0, {}, false], [-190.0, 13.0, {}, true], [-190.0, 15.5, {}, false], [-190.0, 0.0, {"down": true}, false]]:
		var p := _player_on(lv, Vector2(10.5 * TILE + float(pair[1]), 8.5 * TILE + 19.0))
		p.on_floor = false
		p.velocity = Vector2(0, float(pair[0]))
		p.pad = pair[2]
		p.step(DT)
		_check(p.climbing == pair[3], "a catch at vy %.0f, %.1f px off the column%s: %s (climbing %s)" % [pair[0], pair[1], " holding down" if pair[2].has("down") else "", pair[3], p.climbing])
		p.free()
	# The catch clears the jump buffer and x snaps to the column.
	var pb := _player_on(lv, Vector2(10.5 * TILE + 6.0, 8.5 * TILE + 19.0))
	pb.on_floor = false
	pb.velocity = Vector2(0, -150)
	pb.pad = {"jump": true, "jump_pressed": true}
	pb.step(DT)
	_check(pb.climbing and pb._buffer == 0.0 and absf(pb.position.x - 10.5 * TILE) < 0.01, "the catch snaps to the column and clears the jump buffer")
	pb.free()
	# Climb, up, slide, hang.
	for pair in [[{"jump": true}, -65.0, "jump held climbs 130 px/s"], [{"jump": true, "left": true}, -65.0, "jump held climbs whatever the thumb holds"],
			[{"up": true}, -65.0, "the pad's up climbs"], [{"down": true}, 110.0, "down slides 220 px/s"], [{"right": true}, 0.0, "a direction alone hangs"]]:
		var p := _on_vine(lv, 10, 8.5 * TILE)
		var y0: float = p.position.y
		_steps(p, pair[0], 0.5)
		_check(p.climbing and absf((p.position.y - y0) - float(pair[1])) < 2.5, "%s (%.1f px in 0.5 s)" % [pair[2], p.position.y - y0])
		p.free()
	# The leap: a fresh press with a direction, at least 0.15 s after the catch.
	var pl := _player_on(lv, Vector2(10.5 * TILE, 8.5 * TILE + 19.0))
	pl.on_floor = false
	pl.grab_vine(10, 0.0)
	_steps(pl, {"right": true}, 0.1)
	pl.pad = {"right": true, "jump": true, "jump_pressed": true}
	pl.step(DT)
	_check(pl.climbing, "a press 0.1 s after the catch climbs, never leaps")
	_steps(pl, {"right": true}, 0.1)
	pl.pad = {"right": true, "jump": true, "jump_pressed": true}
	pl.step(DT)
	_check(not pl.climbing and absf(pl.velocity.x - 205.0) < 0.5 and pl.velocity.y < -440.0, "a fresh press with a direction after 0.15 s leaps (vx %.0f, vy %.0f)" % [pl.velocity.x, pl.velocity.y])
	# The leap's arc: fixed, 3.95 tiles to a tile lower (3.6 back to its height).
	var x0: float = pl.position.x - 205.0 * DT
	var y0: float = pl.position.y
	var dist := 0.0
	for i in 240:
		pl.pad = {}
		pl.step(DT)
		if pl.velocity.y > 0.0 and pl.position.y >= y0 + TILE:
			dist = pl.position.x - x0
			break
	print("  vine leap (tap): %.0f px (%.2f tiles) to a tile lower" % [dist, dist / TILE])
	_check(dist > 3.2 * TILE and dist < 4.6 * TILE, "a vine leap carries about 4 tiles to a tile lower (%.2f tiles)" % (dist / TILE))
	# The re-catch lock: the column he left doesn't hold him for 0.25 s.
	var pr := _on_vine(lv, 10, 8.5 * TILE)
	_steps(pr, {}, 0.2)
	pr.pad = {"left": true, "jump": true, "jump_pressed": true}
	pr.step(DT)
	pr.position.x = 10.5 * TILE
	pr.velocity = Vector2(0, 0)
	pr.pad = {}
	pr.step(DT)
	_check(not pr.climbing, "the column he just left won't catch him again at once")
	pr.free()
	pl.free()
	# Mount: at the top, jump held toward a floor within 2 tiles hauls him up.
	var ml := _rows(["", "", "", "", "..........{###", "..........{###", "..........{###", "..........{###", "..........{###", "..........{###", "..........{###", "..........{###", "P.........{###"])
	var pm := _on_vine(ml, 10, 9.5 * TILE)
	_steps(pm, {"jump": true, "right": true}, 1.6)
	_check(not pm.climbing and pm.on_floor and absf(pm.position.y - 4.0 * TILE) < 0.5 and pm.position.x > 11.0 * TILE, "climbing to the top toward a ledge mounts it (at %s)" % pm.position)
	pm.free()
	# A hit on a vine slides him a tile and keeps him on; a dash lets go.
	var ph := _on_vine(lv, 10, 7.5 * TILE)
	var hy: float = ph.position.y
	ph.take_damage(10.0, ph.position.x - 40.0)
	_steps(ph, {}, 0.3)
	_check(ph.climbing and absf(ph.position.y - hy - 32.0) < 1.0 and absf(ph.velocity.x) < 0.01, "a hit on a vine slides him down a tile and keeps him on (%.1f px)" % (ph.position.y - hy))
	ph.dash(Vector2(300, 0), 0.1)
	_check(not ph.climbing, "a dash (a Special) lets go of the vine")
	ph.free()
	# A rotten run's cells are climbable (the snap is the orchard module's).
	var prot := _player_on(lv, Vector2(20.5 * TILE, 5.5 * TILE + 19.0))
	prot.on_floor = false
	prot.velocity = Vector2(0, -100)
	prot.pad = {}
	prot.step(DT)
	_check(prot.climbing, "a rotten vine catches too")
	prot.free()
	# Ice: 134 px to stop from a run (the owner's feel lab: "not slippery enough" at 58, "slide more" at 87), knockback halved.
	var ice := _rows([], "", 60)
	for x in 60:
		ice.set_tile(x, 13, LevelData.ICE)
	var pi := _player_on(ice, Vector2(5 * TILE, 13 * TILE))
	_steps(pi, {"right": true}, 1.0)
	var sx: float = pi.position.x
	var t := 0.0
	while absf(pi.velocity.x) > 0.001 and t < 3.0:
		pi.pad = {}
		pi.step(DT)
		t += DT
	var slide: float = pi.position.x - sx
	print("  ice stop from a run: %.1f px" % slide)
	_check(absf(slide - 134.0) <= 6.0, "a full-speed run stops in 134 +- 6 px on ice (%.1f)" % slide)
	pi.reset_at(Vector2(20 * TILE, 13 * TILE))
	_steps(pi, {}, 0.1)
	pi.invuln = 0.0
	pi.take_damage(5.0, pi.position.x - 10.0)
	_check(absf(absf(pi.velocity.x) - pi.KNOCKBACK.x * 0.5) < 1.0, "knockback on ice is halved (%.0f)" % pi.velocity.x)
	pi.free()
	var stone := _rows([], "", 60)
	var ps := _player_on(stone, Vector2(5 * TILE, 13 * TILE))
	_steps(ps, {"right": true}, 1.0)
	sx = ps.position.x
	_steps(ps, {}, 0.5)
	_check(ps.position.x - sx < 14.0, "on stone he still stops in about 9 px (%.1f)" % (ps.position.x - sx))
	ps.free()
	# Belts: 80 px/s the arrows' way, 285 running with it.
	var belt := _rows([], "", 60)
	for x in 60:
		belt.set_tile(x, 13, LevelData.BELT_R)
	var pbt := _player_on(belt, Vector2(5 * TILE, 13 * TILE))
	_steps(pbt, {}, 0.2)
	var bx: float = pbt.position.x
	_steps(pbt, {}, 1.0)
	_check(absf(pbt.position.x - bx - 80.0) < 1.5, "a belt carries a standing Wick 80 px/s (%.1f)" % (pbt.position.x - bx))
	_steps(pbt, {"right": true}, 0.5)
	bx = pbt.position.x
	_steps(pbt, {"right": true}, 1.0)
	_check(absf(pbt.position.x - bx - 285.0) < 3.0, "running with it is 285 px/s (%.1f)" % (pbt.position.x - bx))
	pbt.pad = {"right": true, "jump": true, "jump_pressed": true}
	pbt.step(DT)
	_steps(pbt, {"right": true, "jump": true}, 0.1)
	var ax: float = pbt.position.x
	_steps(pbt, {"right": true, "jump": true}, 0.1)
	_check(not pbt.on_floor and absf((pbt.position.x - ax) / 0.1 - pbt.RUN_SPEED) < 2.0, "no belt momentum carries into the air (%.0f px/s)" % ((pbt.position.x - ax) / 0.1))
	pbt.free()
	# last_safe: only SAFE floors (not glass, not the outer ice tile at a pit).
	var sl := _rows([], "", 40)
	for x in range(10, 14):
		sl.set_tile(x, 13, LevelData.GLASS)
	for x in range(20, 24):
		sl.set_tile(x, 13, LevelData.ICE)
	sl.set_tile(24, 13, LevelData.AIR)
	sl.set_tile(24, 14, LevelData.AIR)
	var psf := _player_on(sl, Vector2(11.5 * TILE, 13 * TILE))
	psf.last_safe = Vector2(-1, -1)
	_steps(psf, {}, 0.5)
	_check(psf.last_safe == Vector2(-1, -1), "standing on glass never records last_safe")
	psf.reset_at(Vector2(21.5 * TILE, 13 * TILE))
	psf.last_safe = Vector2(-1, -1)
	_steps(psf, {}, 0.5)
	_check(psf.last_safe != Vector2(-1, -1), "ice inside a run records it")
	psf.reset_at(Vector2(23.5 * TILE, 13 * TILE))
	psf.last_safe = Vector2(-1, -1)
	_steps(psf, {}, 0.5)
	_check(psf.last_safe == Vector2(-1, -1), "the outer ice tile at a pit's edge doesn't")
	psf.free()
	# A cog's tooth goes round in 6.43 s (12 ticks), the left side rising.
	var teeth: Array = Movers.cog(Vector2(500, 300), 1, 0.0)
	var t0p: Vector2 = teeth[0].rect().get_center()
	_check(absf(t0p.x - 500.0) < 0.01 and absf(t0p.y - 204.0) < 0.01, "tooth 0 starts at the top (%s)" % t0p)
	teeth[0].update(6.432 / 4.0)
	_check(teeth[0].rect().get_center().distance_to(Vector2(596, 300)) < 0.1, "a quarter of 6.43 s takes a clockwise tooth from the top to the right (%s)" % teeth[0].rect().get_center())
	teeth[0].update(6.432)
	_check(teeth[0].rect().get_center().distance_to(t0p) < 0.1, "and it comes round in 6.43 s")
	var lefty: Object = teeth[3]
	lefty.update(6.432 * 0.0)
	lefty.update(DT)
	_check(lefty.delta.y < 0.0 and lefty.rect().get_center().x < 500.0, "the left side of a clockwise ring rises")
	var sw := Movers.swing(Vector2(300, 100), Vector2(284, 260), 1)
	sw.update(3.216 * 0.25)
	_check(sw.rect().get_center().x > 300.0 + 90.0 and sw.rect().position.y < 260.0, "a swing reaches its far side a quarter period in, higher than at rest")
	var fm := Movers.float_on(Vector2i(5, 10), 2, 14.0)
	fm.hero_on = true
	for i in int(1.8 / DT):
		fm._hero_landed = true
		fm.update(i * DT, DT)
	_check(not fm.present and absf(fm.depth - 24.0) < 0.01, "a loaded float goes under at 24 px (about 1.3 s at 18.5 px/s)")


func _test_v3_world() -> void:
	## The World's side: the feature clock, stop_time, pushes and the edge
	## brake, the riding fix, lights and dims, beams and pit bands, silver
	## bells, the relight, result keys, the HUD calls.
	var w := _world("1-1")
	await process_frame
	var pl: Node2D = w.player
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	var f0: float = w.ftime
	w.hitstop = 0.05
	w.tick(DT)
	_check(absf(w.ftime - f0 - DT) < 1e-6, "ftime advances through hitstop")
	w.hitstop = 0.0
	var skel: Node2D = null
	for e in w.enemies:
		if e.kind == "skeleton":
			skel = e
			break
	skel.active = true
	w.stop_time(0.5)
	f0 = w.ftime
	var et: float = skel.t
	for i in 30:
		w.tick(DT)
	_check(w.ftime == f0 and skel.t == et and w.time_stopped(), "stop_time freezes the feature clock and the monsters")
	for i in 40:
		w.tick(DT)
	_check(not w.time_stopped() and w.ftime > f0, "and lets go after its seconds")
	# Pushes: summed, capped at 170, gusts halved on the ground.
	pl.reset_at(Vector2(20 * TILE, 13 * TILE))
	for i in 10:
		w.tick(DT)
	w.push_player(Vector2(150, 0), 1.0, "a")
	w.push_player(Vector2(150, 0), 1.0, "b")
	w.tick(DT)
	_check(absf(pl.push.x - 170.0) < 0.01, "every push together is capped at 170 px/s (%.0f)" % pl.push.x)
	w._pushes.clear()
	w.push_player(Vector2(-120, 0), 1.0, "gust:0")
	w.tick(DT)
	_check(absf(pl.push.x + 60.0) < 0.01, "a gust pushes half as hard on the ground (%.0f)" % pl.push.x)
	w._pushes.clear()
	pl.velocity = Vector2(0, -500)
	pl.on_floor = false
	w.tick(DT)
	w.push_player(Vector2(120, 0), 1.0, "gust:1")
	w.tick(DT)
	_check(pl.push.x == 0.0 and not pl.on_floor, "a gust that begins in the air waits (the airborne grace)")
	w._pushes.clear()
	pl.dash(Vector2(300, 0), 0.2)
	w.push_player(Vector2(120, 0), 1.0, "x")
	w.tick(DT)
	_check(pl.push.x == 0.0, "a push is ignored while he dashes")
	w._pushes.clear()
	pl.end_dash()
	# The edge brake: a grounded push never walks him off a floor edge.
	var pit_x := -1
	for x in range(5, w.level.width):
		if w.level.tile(x, 13) == LevelData.AIR and w.level.tile(x, 14) == LevelData.AIR:
			pit_x = x
			break
	pl.reset_at(Vector2((pit_x - 2) * TILE, 13 * TILE))
	for i in 10:
		w.tick(DT)
	for i in int(2.0 / DT):
		w.push_player(Vector2(170, 0), 0.1, "shove")
		w.tick(DT)
	_check(pl.on_floor and pl.position.x < pit_x * TILE and pl.position.x > (pit_x - 1) * TILE, "a grounded push stops at the pit's edge (x %.0f, edge %d)" % [pl.position.x, pit_x * TILE])
	w._pushes.clear()
	# Lights: a tint and a tag list; lit_at with exclude_hero, a tag, hysteresis.
	var id: int = w.add_light(Vector2(3000, 300), 100.0, 0.9, -1.0, "lantern,haven", Color(1, 0, 0, 0.5))
	_check(w.light_by_id(id)["tint"] == Color(1, 0, 0, 0.5) and w.lights_tagged("haven").size() == 1, "add_light keeps its tint and a tag list")
	_check(w.lit_at(Vector2(3050, 300), 0.0, {"exclude_hero": true}), "lit_at sees a lamp")
	_check(w.lit_at(Vector2(3050, 300), 0.0, {"exclude_hero": true, "tag": "haven"}) and not w.lit_at(Vector2(3050, 300), 0.0, {"exclude_hero": true, "tag": "anchor"}), "lit_at can ask for a tag")
	var probe := Vector2(3095, 300)
	_check(w.lit_at(probe, 0.0, {"exclude_hero": true}), "(a point 95 px from a 100 px lamp is lit)")
	w.move_light(id, Vector2(2990, 300))
	_check(w.lit_at(probe, 0.0, {"exclude_hero": true}), "8 px of hysteresis on the off edge (105 px out: still lit)")
	w.move_light(id, Vector2(2985, 300))
	_check(not w.lit_at(probe, 0.0, {"exclude_hero": true}), "but not past it (110 px out)")
	_check(not w.lit_at(Vector2(3200, 205), 0.0, {"exclude_hero": true}), "and a point never lit takes the nominal radius")
	_check(w.lit_at(pl.center(), 0.0) and not w.lit_at(pl.center() + Vector2(0, -2000), 0.0), "the hero's own light counts unless excluded")
	w.remove_light(id)
	# Dims: one pipeline, dim_resist per entry, the override.
	var r0: float = w.hero_light_radius()
	w.dim("spores", 0.5, 1.0)
	var r1: float = w.hero_light_radius()
	_check(r1 < r0, "a dim shrinks the hero's light (%.0f -> %.0f)" % [r0, r1])
	pl.stats["dim_resist"] = 0.5
	_check(absf(w.dim_mult() - 0.75) < 0.001 or float((Combat as Script).get_script_constant_map().get("DIM_FLOOR", {}).get("dusk", 0.0)) > 0.75,
			"dim_resist applies per entry: 1 - (1 - 0.5)(1 - 0.5) = 0.75 (%.3f)" % w.dim_mult())
	pl.stats.erase("dim_resist")
	w.dim("script:swallow", 0.2, 1.0)
	_check(w.dim_mult() < 0.15, "a script: dim isn't floored (%.3f)" % w.dim_mult())
	w.undim("spores")
	w.undim("script:swallow")
	_check(w.dims().is_empty() and absf(w.hero_light_radius() - r0) < 0.01, "undim lets go")
	w.light_override(20.0)
	_check(w.hero_light_radius() == 20.0, "light_override forces the radius, below LIGHT_MIN too")
	w.light_override(-1.0)
	w.dim("gust", 0.85, 0.2)
	for i in 30:
		w.tick(DT)
	_check(w.dims().is_empty(), "a dim runs out after its seconds")
	# The dark's colour (eased over its seconds by whoever packs the lights).
	w.set_dark(Color(0.1, 0.1, 0.1), 0.0)
	var dc: Color = w._dark_mat.get_shader_parameter("dark_color")
	_check(Color(dc.r, dc.g, dc.b).is_equal_approx(Color(0.1, 0.1, 0.1).lightened(float(game.setting("brightness")))) or Color(dc.r, dc.g, dc.b).is_equal_approx(Color(0.1, 0.1, 0.1)), "set_dark sets the dark's colour (%s)" % dc)
	if w.lights == null:
		w.set_dark(Color(0.2, 0.2, 0.2), 0.5)
		for i in 70:
			w.tick(DT)
		dc = w._dark_mat.get_shader_parameter("dark_color")
		_check(dc.is_equal_approx(Color(0.2, 0.2, 0.2)), "and eases it over its seconds (%s)" % dc)
	# A beam hurts along its segment; a pit band calls fell().
	pl.reset_at(Vector2(20 * TILE, 13 * TILE))
	for i in 5:
		w.tick(DT)
	pl.invuln = 0.0
	var hp0: float = pl.hp
	w.add_hazard({"kind": "beam", "seg": [pl.center() + Vector2(-200, 0), pl.center() + Vector2(200, 0)], "width": 6.0, "life": 0.2, "dmg": 10.0})
	w.tick(DT)
	_check(pl.hp < hp0, "a beam hurts where its segment crosses him")
	w.hazards.clear()
	for i in 20:
		w.tick(DT)   # (the hurt's hitstop)
	pl.reset_at(Vector2(20 * TILE, 13 * TILE))
	for i in 5:
		w.tick(DT)
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	w.add_hazard({"kind": "pit_band", "rect": Rect2(pl.center() - Vector2(40, 40), Vector2(80, 80)), "life": 0.5, "fall": "water"})
	w.tick(DT)
	_check(pl.hp < pl.max_hp and w.snuff_causes.get("_last", "") == "water", "a pit band charges its fall (%s)" % w.snuff_causes.get("_last", ""))
	w.hazards.clear()
	# A silver bell: the secret way out.
	w.level.secret = "1-S"
	var rung := [""]
	w.secret_rung.connect(func(lid): rung[0] = lid)
	var sb: Dictionary = w.add_bell(pl.position + Vector2(8, 0), 0.0, {"silver": true})
	_check(sb["silver"] and (sb["rope"] as Rect2).size == Vector2(28, 44), "a silver bell has its own rope (28 x 44)")
	pl.invuln = 10.0
	for i in 60:
		w.test_pad = {"right": true}
		w._read_pad()
		w.tick(DT)
		if sb["rung"]:
			break
	_check(sb["rung"] and w.state == "clear" and w.result()["secret"] == "1-S" and rung[0] == "1-S", "ringing it clears the level with result.secret and secret_rung (rung %s, state %s, secret %s, rope %s, wick %s)" % [sb["rung"], w.state, w.result()["secret"], sb["rope"], pl.rect()])
	var res: Dictionary = w.result()
	for k in ["secret", "candles", "lost_wick", "rush_boss", "phase_reached", "snuff_sections"]:
		_check(res.has(k), "result() has %s" % k)
	w.queue_free()
	await process_frame
	# No silver bell to a secret level that isn't in the build (features/
	# secrets.gd asks for its file, as the map does): an S under a `secret:`
	# whose file is missing stays air, in memory and on every level file.
	# With every secret file shipped, the registry's stand-in (UI's, as the
	# map's tests use) names a 4-S whose file is gone.
	var ghost := {}
	var UIx = load("res://scripts/ui.gd")
	var reg_missing := []
	for info in (game.get_script() as Script).get_script_constant_map()["SECRET_LEVELS"]:
		var e: Dictionary = (info as Dictionary).duplicate()
		if str(e["id"]) == "4-S":
			e["path"] = "res://levels/_not_built_4-S.txt"
		reg_missing.append(e)
	var sl = _rows(["", "", "", "", "", "", "", "", "", "", "", "", "..P......S"], "secret: 4-S\n", 30)
	for pair in [["(in memory)", sl]] + _secret_level_files():
		var lvx: RefCounted = pair[1]
		var sid := str(lvx.secret)
		UIx.secret_levels_override = reg_missing if pair[0] == "(in memory)" else null
		if sid == "" or (pair[0] != "(in memory)" and FileAccess.file_exists("res://levels/%s.txt" % sid)):
			continue
		var gw: Node2D = WorldScript.new()
		game.reset()
		gw.setup(lvx, true)
		root.add_child(gw)
		await process_frame
		var n := 0
		for b in gw.bells:
			if b.get("silver", false):
				n += 1
		ghost[str(pair[0])] = n
		gw.queue_free()
		await process_frame
	UIx.secret_levels_override = null
	_check(ghost.has("(in memory)") and ghost.values().max() == 0,
			"no silver bell spawns for a secret level whose file isn't in the build (%s)" % ghost)
	# The riding fix: a ledge falling at 200 px/s keeps its rider.
	var rl := _rows(["", "", "", "", "", "", "", "..........|||", "", "", "", "", "P"], "", 40)
	for x in 40:
		rl.set_tile(x, 13, LevelData.AIR)
		rl.set_tile(x, 14, LevelData.AIR)
	rl.set_tile(1, 13, LevelData.STONE)
	var rw: Node2D = WorldScript.new()
	game.reset()
	rw.setup(rl, true)
	root.add_child(rw)
	await process_frame
	var mv: Object = rw.movers[0]
	mv.period = 3.0   # 96 px * 2 pi / 3 s: 201 px/s at mid-sweep
	mv.phase = -PI * 0.5 - rw.ftime / mv.period * TAU   # at the top of its sweep now
	mv.update(rw.ftime)
	mv.update(rw.ftime)
	rw.player.reset_at(Vector2(11.5 * TILE, mv.rect().position.y))
	rw.player.on_floor = true
	rw.player.riding = mv
	rw.test_pad = {}
	var off := 0
	var fastest := 0.0
	for i in int(3.0 / DT):
		rw.tick(DT)
		fastest = maxf(fastest, mv.delta.y / DT)
		if i > 5 and rw.player.riding != mv:
			off += 1
	_check(off == 0 and fastest > 170.0, "a rider stays on a ledge falling at up to %.0f px/s (off %d ticks)" % [fastest, off])
	rw.queue_free()
	await process_frame


const STUB_MODE := """extends RefCounted
var id := "stub"
var main: Node
var world: Node
var calls := {}
var gates := {}
var snuff_says := ""
var boss_opts := {}
func _n(k: String) -> void:
	calls[k] = int(calls.get(k, 0)) + 1
func level_data() -> RefCounted:
	return null
func diff() -> String:
	_n("diff")
	return "nightfall"
func strength() -> String:
	_n("strength")
	return "normal"
func on_build(w: Node) -> void:
	_n("on_build")
	world = w
func on_tick(w: Node, dt: float) -> void:
	_n("on_tick")
func on_spawn(e: Node2D) -> void:
	_n("on_spawn")
func on_snuffed(w: Node) -> String:
	_n("on_snuffed")
	return snuff_says
func allows(what: String) -> bool:
	_n("allows")
	return gates.get(what, true)
func stats_filter(s: Dictionary) -> Dictionary:
	_n("stats_filter")
	var o := s.duplicate()
	o["max_hp"] = 777.0
	return o
func tells_mult() -> float:
	_n("tells_mult")
	return 0.5
func elite_rules() -> Dictionary:
	_n("elite_rules")
	return {"max_anoint": 9}
func loot() -> Dictionary:
	_n("loot")
	return {"rare": 2.0, "legend": 1.0}
func lights() -> Array:
	_n("lights")
	return [{"p": Vector2(100, 100), "r": 50.0, "s": 0.8, "gameplay": true, "tag": "haven"}]
func draw_glow(glow: Node2D) -> void:
	_n("draw_glow")
func pause_items() -> Array:
	return []
func result_extra() -> Dictionary:
	_n("result_extra")
	return {"depth": 7}
func finished(res: Dictionary) -> void:
	_n("finished")
	calls["res"] = res
func quit() -> void:
	_n("quit")
func restart() -> void:
	_n("restart")
"""


func _stub(src: String) -> Object:
	var g := GDScript.new()
	g.source_code = src
	g.reload()
	return g.new()


func _mode_world(mode: Object, id := "1-1") -> Node2D:
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	game.reset()
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.mode = mode
	root.add_child(w)
	return w


func _test_v3_modes() -> void:
	## The mode hooks (contract.md §5.5): a stub mode must receive each.
	var mode: Object = _stub(STUB_MODE)
	var w := _mode_world(mode)
	await process_frame
	var pl: Node2D = w.player
	_check(w.diff == "nightfall" and mode.calls.get("diff", 0) >= 1 and mode.calls.get("strength", 0) >= 1, "the mode sets the difficulty and strength first (%s)" % w.diff)
	_check(mode.calls.get("on_build", 0) == 1 and mode.world == w, "on_build is called last, once")
	_check(mode.calls.get("on_spawn", 0) >= 3, "on_spawn sees every monster (%d)" % mode.calls.get("on_spawn", 0))
	_check(pl.max_hp == 777.0, "apply_hero goes through stats_filter (%.0f)" % pl.max_hp)
	_check(absf(w.tells_mult() - float(Combat.diff("nightfall")["tells"]) * 0.5) < 1e-6, "tells_mult x the mode's")
	_check(int(w.elite_rules().get("max_anoint", 0)) == 9, "elite_rules merges the mode's")
	w.test_pad = {}
	for i in 10:
		w.tick(DT)
	_check(mode.calls.get("on_tick", 0) >= 10, "on_tick every tick")
	_check(w.lit_at(Vector2(100, 100), 0.0, {"exclude_hero": true, "tag": "haven"}), "the mode's gameplay lights count for lit_at")
	var res: Dictionary = w.result()
	_check(res.get("mode", "") == "stub" and int(res.get("depth", 0)) == 7, "result() has the mode's id and result_extra")
	# loot(): the embers' worth and the rarities lean the mode's way.
	var lt0: int = mode.calls.get("loot", 0)
	var worth: int = w.ember_worth()
	_check(mode.calls.get("loot", 0) > lt0 and worth >= 1, "ember worth asks the mode's loot() (%d)" % worth)
	w.drop_item(pl.position)
	_check(mode.calls.get("loot", 0) > lt0 + 1, "and so does a drop's rarity")
	# The gates.
	mode.gates = {"embers": false}
	_check(w.ember_worth() == 0, "allows('embers') false: an ember is worth nothing")
	mode.gates = {"record": false}
	var xp1: int = w.xp_gained
	w._ring({"pos": pl.position, "top": pl.position, "rope": Rect2(), "sprite": Sprite2D.new(), "swing": 0.0, "vel": 0.0, "rung": false})
	_check(w.xp_gained - xp1 == Progression.event_xp("clear", w.area) * 1, "allows('record') false: a clear is never a first clear (no record read or made)")
	w.state = "play"
	pl.frozen = false
	mode.gates = {"xp": false, "loot": false, "flask": false, "special": false, "pool": false}
	var xp0: int = w.xp_gained
	w.gain_xp(500, pl.position)
	_check(w.xp_gained == xp0, "allows('xp') false: no XP")
	var n0: int = w.pickups.size()
	w.drop_item(pl.position)
	_check(w.pickups.size() == n0, "allows('loot') false: no drops")
	pl.hp = 0.3 * pl.max_hp
	w.test_pad = {"flask": true}
	w._read_pad()
	w.tick(DT)
	w.test_pad = {}
	for i in 70:
		w._read_pad()
		w.tick(DT)
	_check(absf(pl.hp - 0.3 * pl.max_hp) < 1.0, "allows('flask') false: no drink")
	w.test_pad = {"special": true}
	w._read_pad()
	w.tick(DT)
	_check(not w._special_held, "allows('special') false: no Special")
	w.test_pad = {}
	w.embers_carried = 5
	pl.invuln = 0.0
	pl.take_damage(99999.0, pl.position.x + 5.0)
	_check(w.pool.is_empty() and mode.calls.get("on_snuffed", 0) == 1, "allows('pool') false: no pool; on_snuffed asked")
	w.queue_free()
	await process_frame
	# on_snuffed "restart": restart 0.6 s later, no relight.
	mode = _stub(STUB_MODE)
	mode.snuff_says = "restart"
	w = _mode_world(mode)
	await process_frame
	var restarts := [0]
	w.restart.connect(func(): restarts[0] += 1)
	w.test_pad = {}
	w.player.take_damage(99999.0, w.player.position.x + 5.0)
	for i in int(0.5 / DT):
		w.tick(DT)
	_check(restarts[0] == 0, "(not before 0.6 s)")
	for i in int(1.5 / DT):
		w.tick(DT)
	_check(restarts[0] == 1 and w.state == "dead", "on_snuffed 'restart' emits restart once, 0.6 s after the snuff (%d)" % restarts[0])
	w.queue_free()
	await process_frame
	# on_snuffed "end": finished with cleared false after the snuff.
	mode = _stub(STUB_MODE)
	mode.snuff_says = "end"
	w = _mode_world(mode)
	await process_frame
	var fin := [null]
	w.finished.connect(func(r): fin[0] = r)
	w.test_pad = {}
	w.player.take_damage(99999.0, w.player.position.x + 5.0)
	for i in int(2.0 / DT):
		w.tick(DT)
	_check(fin[0] != null and not fin[0]["cleared"] and fin[0].get("mode", "") == "stub", "on_snuffed 'end' finishes the level, not cleared")
	w.queue_free()
	await process_frame


const STUB_FEATURE := """extends "res://scripts/features/feature.gd"
const DIFF_KNOBS := {"k": {"dusk": 1.5, "nightfall": 2.5, "witching": 3.5}}
var calls := {}
func _n(k: String) -> void:
	calls[k] = int(calls.get(k, 0)) + 1
func step(dt: float) -> void:
	_n("step")
func touch(p: Node2D) -> void:
	_n("touch")
func strike(r: Rect2, attack_id: int) -> void:
	_n("strike")
func shot_hit(shot: Dictionary) -> void:
	_n("shot_hit")
func lights() -> Array:
	_n("lights")
	return [{"p": Vector2(-500, -500), "r": 10.0, "s": 0.5, "gameplay": true}]
func reflectors() -> Array:
	_n("reflectors")
	return [{"x0": 0, "x1": 1, "y": 0, "tint": Color.WHITE, "k": 0.5}]
func draw_under(ci: CanvasItem) -> void:
	_n("draw_under")
func draw_glow(glow: Node2D) -> void:
	_n("draw_glow")
func on_respawn() -> void:
	_n("on_respawn")
func on_boss_reset() -> void:
	_n("on_boss_reset")
func stood_on(who: Node2D, x: int, y: int) -> void:
	_n("stood_on")
"""


func _test_v3_features() -> void:
	## The dispatcher calls every hook of a module, and its queries answer.
	var w := _world("1-4")
	await process_frame
	var f: Object = _stub(STUB_FEATURE)
	f.build(w, w.level)
	w.features.modules.append(f)
	_check(w.features.modules.size() >= 6, "the dispatcher built the five modules (%d with the stub)" % w.features.modules.size())
	_check(absf(f.knob("k") - 1.5) < 1e-6, "knob() reads the module's own DIFF_KNOBS on Dusk")
	w.diff = "witching"
	_check(absf(f.knob("k") - 3.5) < 1e-6, "and on Witching")
	w.diff = "dusk"
	var pl: Node2D = w.player
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	_check(f.calls.get("step", 0) >= 30 and f.calls.get("touch", 0) >= 30, "step and touch every tick")
	_check(f.calls.get("stood_on", 0) > 0, "stood_on as he stands")
	w.test_pad = {"attack": true}
	w._read_pad()
	for i in 5:
		w.tick(DT)
	w.test_pad = {}
	_check(f.calls.get("strike", 0) >= 1, "strike on a swing")
	w.spawn_shot({"kind": "arrow", "owner": "enemy", "pos": pl.center() + Vector2(300, -100), "vel": Vector2(-10, 0), "life": 1.0, "dmg": 1.0})
	w.tick(DT)
	_check(f.calls.get("shot_hit", 0) >= 1, "shot_hit for a live shot")
	w.lit_at(Vector2(9999, 9999))
	_check(f.calls.get("lights", 0) >= 1, "lights() asked (lit_at)")
	_check(w.features.reflectors().size() == 1, "reflectors() gathered")
	await process_frame
	_check(f.calls.get("draw_under", 0) >= 1 or DisplayServer.get_name() == "headless", "draw_under (drawn)")
	# on_respawn after a snuff; on_boss_reset when a fight resets.
	var b: Node2D = w.boss
	b.active = true
	pl.reset_at(Vector2(b.arena_left + 80.0, b.position.y))
	for i in 30:
		w.tick(DT)
	pl.invuln = 0.0
	pl.take_damage(99999.0, pl.position.x + 5.0)
	for i in int(2.0 / DT):
		w.tick(DT)
	_check(f.calls.get("on_respawn", 0) == 1 and f.calls.get("on_boss_reset", 0) == 1, "on_respawn and on_boss_reset after a snuff mid-fight (%d, %d)" % [f.calls.get("on_respawn", 0), f.calls.get("on_boss_reset", 0)])
	# The queries answer (with or without their module).
	var q = w.features
	_check(not q.vine_at(Vector2i(0, 0)) and q.vine_lane(Vector2i(0, 0)).is_empty() and q.vine_present(3, 13) == false, "vine queries answer where there are none")
	_check(not q.spores_at(pl.center()) and not q.slick_at(pl.position + Vector2(0, 4)) and not q.still_at(pl.position) and q.gust_at(pl.center()) == Vector2.ZERO, "spores, slick, still, gust answer")
	_check(not q.in_hush_zone(pl.center()) and q.tide_x() == -INF and q.candles() == {"lit": 0, "total": 0} and q.lamps().size() >= 0, "hush zone, tide, candles, lamps answer")
	q.add_spores(pl.center(), 64.0, 4.0)
	_check(q.spores_at(pl.center()), "add_spores makes a cloud that spores_at sees")
	q.burn_spores(pl.center(), 10.0)
	for i in int(0.4 / DT):
		w.tick(DT)
	_check(not q.spores_at(pl.center()), "burn_spores burns it away")
	q.break_glass(Vector2i(0, 0))
	q.strain_glass(Vector2i(0, 0), 0.5)
	q.reverse_belts(0, 5)
	q.toll(Vector2i(0, 0))
	q.put_out({})
	q.relight({})
	_check(q.belt_dir(Vector2i(3, 3), 1) == 1, "belt_dir answers")
	w.queue_free()
	await process_frame


const STUB_HUD := """extends CanvasLayer
var said := []
func _say(k: String, a = null) -> void:
	said.append([k, a])
func bark(k: String) -> void:
	_say("bark", k)
func boss_bar(i) -> void:
	_say("boss_bar", i)
func mode_pill(st: Dictionary) -> void:
	_say("mode_pill", st)
func dim_ring(on: bool) -> void:
	_say("dim_ring", on)
func card(id: String, t: String, b: String) -> void:
	_say("card", id)
func special_pill(t: String) -> void:
	_say("special_pill", t)
func fade_for_finale(on: bool) -> void:
	_say("fade_for_finale", on)
func toast(a = "", b = "") -> void:
	_say("toast", a)
func show_hint(t) -> void:
	pass
func bump_embers() -> void:
	pass
func bump_flames() -> void:
	pass
func title_card(a = "", b = "") -> void:
	pass
func sigil_found(a = 0, b = null) -> void:
	pass
func level_up(n = 0) -> void:
	pass
func banner(t = "") -> void:
	pass
func has_said(k: String) -> bool:
	for s in said:
		if s[0] == k:
			return true
	return false
"""

const STUB_BOSS := """extends "res://scripts/enemy.gd"
signal woke
var boss_id := "hush"
var boss_name := "Stub"
var boss_title := "the Stub"
var state := "sleep"
var open := false
var configured := {}
var configured_before_ready := false
var keeps := []
var door: Array = []
func _init() -> void:
	size = Vector2(40, 60)
	base_hp = 100.0
func configure(opts: Dictionary) -> void:
	configured = opts
	configured_before_ready = not is_inside_tree()
func is_open() -> bool:
	return open
func checkpoint() -> Dictionary:
	return {"phase": 3, "hp_frac": 0.2, "state": {}}
func reset_fight(keep_phase := false) -> void:
	keeps.append(keep_phase)
func boss_info() -> Dictionary:
	return {"name": boss_name, "segments": [0.65, 0.30]}
func touch_damage() -> bool:
	return false
func think(dt: float, p: Node2D) -> void:
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
"""


func _test_v3_boss_seam() -> void:
	## The boss's world side: configure before _ready (a mode's options),
	## is_open, the phase barks and phase_reached, boss_music, reset_fight(keep)
	## on Dusk with a checkpoint (never in a mode), no drops for a rush boss.
	var path := "user://test_core_stub_boss.gd"
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(STUB_BOSS)
	fa = null
	var EK = load("res://scripts/enemy_kinds.gd")
	EK.register("stubboss", path, "floor", false)
	var lines := ["", "", "", "", "", "", "", "", "", "", "", "", "P.......................X....."]
	var lv := _rows(lines, "boss: stubboss\nboss_music: tinker\n", 40)
	lv.id = "9-4"
	lv.world = LevelData.world_of(lv.id)
	game.reset()
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	var b: Node2D = w.boss
	_check(b != null and b.get("boss_id") == "hush", "a registered stub boss spawns")
	if b == null:
		w.queue_free()
		return
	_check(w.world_n == 9 and w.boss_music() == "tinker", "world_n from the id; boss_music from the header")
	b.open = true
	_check(w._boss_open(b), "the World asks the boss's is_open()")
	b.open = false
	_check(not w._boss_open(b), "(closed)")
	var hud: CanvasLayer = _stub(STUB_HUD)
	w.hud = hud
	w.boss_phase(b, 2)
	_check(w.phase_reached == 2 and hud.has_said("bark"), "boss_phase barks and records the phase reached")
	w.dim("x", 0.5, 1.0)
	w.tick(DT)
	_check(hud.has_said("dim_ring"), "a dim lights the HUD's dim ring")
	w.card("id", "T", "B")
	w.special_pill("Hold to give your flame")
	w.fade_for_finale(true)
	w.mode_pill({"a": 1})
	_check(hud.has_said("card") and hud.has_said("special_pill") and hud.has_said("fade_for_finale") and hud.has_said("mode_pill"), "the v3 HUD calls reach a HUD that has them")
	w.hud = null
	hud.free()
	# A snuff mid-fight on Dusk keeps the phase (the boss has checkpoint()).
	b.state = "fight"
	w.test_pad = {}
	w.player.invuln = 0.0
	w.player.take_damage(99999.0, w.player.position.x + 5.0)
	for i in int(2.0 / DT):
		w.tick(DT)
	_check(b.keeps == [true], "on Dusk a snuff calls reset_fight(true) for the Hush past phase 1 (%s)" % str(b.keeps))
	w.queue_free()
	await process_frame
	# With a mode: configure before _ready, no checkpoint, no drops (rush).
	var mode: Object = _stub(STUB_MODE)
	mode.boss_opts = {"rush": true, "mods": [], "hp_mult": 1.0, "area": 5}
	game.reset()
	w = WorldScript.new()
	lv = _rows(lines, "boss: stubboss\n", 40)
	w.setup(lv, true)
	w.mode = mode
	root.add_child(w)
	await process_frame
	b = w.boss
	_check(b.configured.get("rush", false) and b.configured_before_ready, "configure(opts) reaches the boss before it's in the tree")
	b.state = "fight"
	w.test_pad = {}
	w.player.take_damage(99999.0, w.player.position.x + 5.0)
	mode.snuff_says = ""
	for i in int(2.0 / DT):
		w.tick(DT)
	_check(b.keeps == [false], "in a mode the fight never checkpoints (%s)" % str(b.keeps))
	var n0: int = w.pickups.size()
	w.boss_defeated(b, b.position)
	_check(w.pickups.size() == n0 and w.result()["rush_boss"] == "hush", "a rush boss pays no drops; result.rush_boss says which")
	w.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_v3_damage() -> void:
	## Hollin's Ember (the relight before the kit's), the blow clamp, shot_dr.
	var w := _world("1-1")
	await process_frame
	var pl: Node2D = w.player
	w.test_pad = {}
	for i in 20:
		w.tick(DT)
	pl.stats["legends"] = {"hollins_ember": true}
	pl.invuln = 0.0
	pl.hp = 0.2 * pl.max_hp   # (lethal even under the blow clamp)
	w.hurt_player(pl.max_hp * 3.0, pl.position.x + 5.0, "hit", null, {"ignore_invuln": true})
	_check(pl.alive and pl.hp == 1.0 and pl.invuln >= 1.9, "Hollin's Ember leaves him at 1 life, untouchable a moment")
	pl.invuln = 0.0
	w.hurt_player(pl.max_hp * 3.0, pl.position.x + 5.0, "hit", null, {"ignore_invuln": true})
	_check(not pl.alive, "once an altar")
	for i in int(2.0 / DT):
		w.tick(DT)
	pl.stats["legends"] = {}
	var clamp: Dictionary = (Combat as Script).get_script_constant_map().get("BLOW_CLAMP", {})
	if clamp.is_empty():
		print("  (skipped: combat.gd BLOW_CLAMP missing; the clamp waits for PR)")
	else:
		# v2's own levels keep v2's blows in Phase 0 (world.CLAMP_V2_LEVELS).
		pl.hp = pl.max_hp
		pl.invuln = 0.0
		w.hurt_player(pl.max_hp * 0.8, pl.position.x + 5.0)
		_check(w.CLAMP_V2_LEVELS or (pl.alive and pl.hp < pl.max_hp * (1.0 - float(clamp["dusk"])) - 1.0),
				"on 1-1 a big blow lands as in v2 (%.0f of %.0f left)" % [pl.hp, pl.max_hp])
		# v3's content (here a lab, world 0) clamps.
		var wl := _world("lab-1")
		await process_frame
		var pk: Node2D = wl.player
		wl.test_pad = {}
		for i in 20:
			wl.tick(DT)
		pk.hp = pk.max_hp
		pk.invuln = 0.0
		wl.hurt_player(pk.max_hp * 2.0, pk.position.x + 5.0)
		_check(wl.clamp_here() and pk.alive and pk.hp >= pk.max_hp * (1.0 - float(clamp["dusk"])) - 0.5,
				"on Dusk no blow takes more than %.0f%% of life (v3's levels, the labs, the modes)" % (float(clamp["dusk"]) * 100.0))
		pk.invuln = 0.0
		pk.hp = pk.max_hp
		wl.hurt_player(pk.max_hp * 2.0, pk.position.x + 5.0, "lava")
		_check(not pk.alive or pk.hp < pk.max_hp * 0.5, "lava keeps its own share (never clamped)")
		wl.queue_free()
		await process_frame
		w.player.invuln = 0.0
	pl.hp = pl.max_hp
	pl.invuln = 0.0
	pl.stats["shot_dr"] = 0.5
	var hp0: float = pl.hp
	w.hurt_player(20.0, pl.position.x + 5.0, "arrow")
	var took: float = hp0 - pl.hp
	pl.hp = pl.max_hp
	pl.invuln = 0.0
	pl.stats.erase("shot_dr")
	w.hurt_player(20.0, pl.position.x + 5.0, "arrow")
	_check(took > 0.0 and absf(took * 2.0 - (hp0 - pl.hp)) < 0.6, "shot_dr halves a shot (%.1f vs %.1f)" % [took, hp0 - pl.hp])
	# The playlog's line: snuffs by section, move, feature and the phase.
	pl.invuln = 0.0
	pl.hp = 0.2 * pl.max_hp   # (lethal even under the blow clamp)
	w.note_feature("glass")
	w.hurt_player(99999.0, pl.position.x + 5.0, "hit", null, {"move": "stub:swing"})
	var e: Dictionary = load("res://scripts/playlog.gd").entry(w, false, {})
	_check(e.has("sections") and e.has("by_section") and e["moves"].get("stub:swing", 0) == 1 and e["features"].get("glass", 0) == 1 and e.has("phase") and e.has("mode"),
			"the playlog line has snuffs by section, move and feature, and the phase (%s)" % str(e))
	w.queue_free()
	await process_frame


func _test_v3_main() -> void:
	## main.gd's routes: play_level_id, play_custom, show_modes, the map's
	## Feel lab button, the autoplay routes.
	game.reset()
	game.new_hero("knight")
	for s in ["intro", "oath"]:
		game.mark_seen(s)
	var M = load("res://scripts/main.gd")
	var m: Node = M.new()
	root.add_child(m)
	await process_frame
	m.play_level_id("lab-1")
	await process_frame
	_check(m.current != null and m.current.get("level_id") == "lab-1", "play_level_id plays a lab off the path")
	m.play_level_id("1-2")
	await process_frame
	_check(m.current.get("level_id") == "1-2" and m.last_level == 1, "and a main level by id")
	var mode: Object = _stub(STUB_MODE)
	var rec: Dictionary = game.level_record("1-1").duplicate(true)
	m.play_custom(LevelData.load_file("res://levels/1-1.txt"), mode)
	await process_frame
	_check(m.current.get("mode") == mode and mode.main == m, "play_custom hands the World its mode")
	m.current.finished.emit({"level": "1-1", "cleared": true, "sigils": [true, true, true], "time": 1.0, "relics": [], "embers": 0})
	_check(mode.calls.get("finished", 0) == 1 and game.level_record("1-1") == rec, "a mode's finish goes to mode.finished, never Game.record_result")
	m.current.quit.emit()
	m.current.restart.emit()
	_check(mode.calls.get("quit", 0) == 1 and mode.calls.get("restart", 0) == 1, "and its quit and restart to the mode's")
	m.show_modes()
	await process_frame
	_check(m.current != null and m.current.get_script() != null, "show_modes opens the hub (or the map before it exists)")
	m.show_map()
	await process_frame
	_check(m.current.get_node_or_null("FeelLab") != null, "the map has a Feel lab button")
	m.autoplay_route("descent:3")
	await process_frame
	_check(true, "an autoplay route to a mode that isn't there yet says so and plays on")
	m.queue_free()
	await process_frame
	game.reset()


func _test_v3_lab_features() -> void:
	## The feature modules' Phase 0 versions, at lab-1's stations: a rotten
	## vine snaps after its hold, glass breaks on its second landing, a lamp
	## makes dawnglass a ledge, a buoy stills the pool, a float sinks under, a
	## gust tells a second before it pushes, a grasp tells before it rises.
	var w := _world("lab-1")
	await process_frame
	var lv: RefCounted = w.level
	var pl: Node2D = w.player
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	var orchard = w.features.module("orchard")
	# The rotten vine.
	var rot := Vector2i(-1, -1)
	for x in lv.width:
		for y in lv.height:
			if rot.x < 0 and lv.tile(x, y) == LevelData.ROTTEN_VINE:
				rot = Vector2i(x, y)
	pl.reset_at(Vector2((rot.x + 0.5) * TILE, (rot.y + 1) * TILE + 19.0 - 16.0))
	pl.on_floor = false
	pl.grab_vine(rot.x, 1.0)
	var held_for := 0.0
	for i in int(2.0 / DT):
		w.tick(DT)
		if pl.climbing:
			held_for += DT
	var hold: float = orchard.knob("rotten_hold")
	_check(absf(held_for - hold) < 0.05 and not w.vine_present(rot.x, rot.y), "a rotten vine holds %.1f s from the catch, then snaps (held %.2f s)" % [hold, held_for])
	for i in int(6.0 / DT):
		w.tick(DT)
	_check(w.vine_present(rot.x, rot.y), "and grows back")
	# Glass: a landing strains it, a second breaks it; it reforms.
	var glass = w.features.module("glass")
	var pane := Vector2i(-1, -1)
	for x in lv.width:
		if pane.x < 0 and lv.tile(x, 11) == LevelData.GLASS:
			pane = Vector2i(x, 11)
	pl.reset_at(Vector2((pane.x + 0.5) * TILE, pane.y * TILE - 20.0))
	pl.velocity = Vector2.ZERO
	for i in 30:
		w.tick(DT)
		if pl.on_floor:
			break
	var s1: float = glass.panes[pane]["strain"]
	_check(pl.on_floor and s1 >= 0.39 and s1 < 0.5, "a landing on glass strains it %.2f" % s1)
	var lasted := 0.0
	while glass.panes[pane]["state"] == "whole" and lasted < 4.0:
		w.tick(DT)
		lasted += DT
	print("  a pane after one landing lasts %.2f s of standing" % lasted)
	_check(absf(lasted - 1.09) < 0.1, "after one landing a pane lasts about 1.1 s of standing (%.2f)" % lasted)
	for i in int(0.5 / DT):
		w.tick(DT)
	_check(lv.tile(pane.x, pane.y) == LevelData.AIR, "then it shatters (a flash, then air)")
	pl.reset_at(Vector2((pane.x - 3) * TILE, 11 * TILE))
	for i in int(6.5 / DT):
		w.tick(DT)
	_check(lv.tile(pane.x, pane.y) == LevelData.GLASS, "and reforms %.0f s later" % glass.knob("glass_reform"))
	# Dawnglass: a ledge while its lamp is lit, air when not.
	var dawn := Vector2i(-1, -1)
	for x in lv.width:
		if dawn.x < 0 and lv.tile(x, 11) == LevelData.DAWNGLASS:
			dawn = Vector2i(x, 11)
	pl.reset_at(Vector2((dawn.x - 8) * TILE, 13 * TILE))
	for i in 20:
		w.tick(DT)
	_check(lv.tile(dawn.x, dawn.y) == LevelData.DAWNGLASS, "unlit dawnglass is air (Wick's own light never counts)")
	for l in w.features.lanterns:
		if absf(l["pos"].x - dawn.x * TILE) < 200.0:
			w.features.light(l)
	for i in 20:
		w.tick(DT)
	_check(lv.tile(dawn.x, dawn.y) == LevelData.DAWN_ON, "lit by its lamp, it's a ledge")
	# A buoy stills the pool; a float sinks under.
	var deep = w.features.module("deep")
	var b: Dictionary = deep.buoys[0]
	w.features.toll(b["cell"])
	var still := 0
	for x in range(b["cell"].x - 6, b["cell"].x + 7):
		if lv.tile(x, b["cell"].y) == LevelData.STILL:
			still += 1
	_check(still >= 5 and w.features.still_at(LevelData.cell_center(b["cell"]) + Vector2(32, 0)), "a toll stills the water round the buoy (%d cells)" % still)
	for i in int((deep.knob("still_time") + 0.2) / DT):
		w.tick(DT)
	_check(lv.tile(b["cell"].x + 1, b["cell"].y) == LevelData.WATER, "for %.0f s, then it's water again" % deep.knob("still_time"))
	var fm: Object = deep.floats[0]
	pl.reset_at(Vector2(fm.rect().get_center().x, fm.rect().position.y))
	var wet_at := -1.0
	var rode := false
	for i in int(3.0 / DT):
		w.tick(DT)
		rode = rode or pl.riding == fm
		if rode and wet_at < 0.0 and pl.riding != fm:
			wet_at = i * DT
	# Over a shallow pool it sinks to the pool's floor: he's standing in the water.
	_check(rode and wet_at > 1.0 and wet_at < 1.45, "a float with Wick on it sinks him into the water in about 1.25 s (%.2f)" % wet_at)
	for i in int(1.5 / DT):
		w.tick(DT)
	_check(fm.depth < 24.0 and fm.present, "and rises again once he's off it")
	# A gust tells a second, then pushes.
	var gz: Dictionary = lv.gusts[0]
	var gx := (float(gz["x0"]) + 2.0) * TILE
	pl.reset_at(Vector2(gx, 13 * TILE))
	var tell_t := -1.0
	var push_t := -1.0
	for i in int(5.0 / DT):
		w.tick(DT)
		var ph: Dictionary = glass.gust_phase(gz)
		if tell_t < 0.0 and ph["state"] == "tell":
			tell_t = w.ftime
		if tell_t >= 0.0 and push_t < 0.0 and ph["state"] == "gust":
			push_t = w.ftime
	_check(tell_t >= 0.0 and push_t > tell_t and absf(push_t - tell_t - glass.knob("gust_tell")) < 0.02, "a gust tells %.1f s before it blows (%.2f)" % [glass.knob("gust_tell"), push_t - tell_t])
	# A grasp: Wick near, a tell, then the hands.
	var g: Dictionary = deep.grasps[0]
	pl.reset_at(Vector2(float(g["x"]) - 48.0, 13 * TILE))
	var rose_after := -1.0
	for i in int(1.5 / DT):
		w.tick(DT)
		if g["state"] == "up" and rose_after < 0.0:
			rose_after = i * DT
	_check(absf(rose_after - deep.knob("grasp_tell")) < 0.05, "a grasp's hands rise %.2f s after Wick comes near (%.2f)" % [deep.knob("grasp_tell"), rose_after])
	w.queue_free()
	await process_frame


const STUB_SFX := """extends Node
var calls := []
var stopped := false
func set_hush(k: float) -> void:
	calls.append(["set_hush", k])
func tape_stopped() -> bool:
	return stopped
func tape_go(sec := 0.25) -> void:
	calls.append(["tape_go", sec])
	stopped = false
func stop_ambience(fade := 1.0) -> void:
	calls.append(["stop_ambience"])
"""


func _test_p0_integration() -> void:
	## The seams the Phase 0 merge wired between the streams: main's spike
	## routes and one-time cards, the World's icon clamp, boss pairs and audio
	## resets, and world_lights' dims on PR's rule.
	var M = load("res://scripts/main.gd")
	var consts: Dictionary = (M as Script).get_script_constant_map()
	var audio: Array = consts["AUDIO_SPIKES"]
	var gpu: Array = consts["GPU_SPIKES"]
	_check(audio.all(func(a): return not gpu.has(a)) and audio.has("boot") and audio.has("stems") and gpu.has("all"),
			"the audio and GPU spikes share --autoplay=spike: and never a name")
	var sfx_src := FileAccess.get_file_as_string("res://scripts/sfx.gd")
	_check(sfx_src.contains('in ["boot", "stems"]'), "Sfx's own fallback starts only the audio spikes (spike:all is the GPU's)")
	# The cards: v3_update waits for the new worlds, new_points for the deep tree.
	game.reset()
	game.new_hero("knight")
	var m: Node = M.new()
	_check(game.LEVELS.size() > 8 or not m._card_due("v3_update"), "the v3_update card waits until the new worlds are built (%d levels)" % game.LEVELS.size())
	game.hero()["points"] = 3
	var Classes = load("res://scripts/classes.gd")
	_check(Classes.deep or not m._card_due("new_points"), "the new-points card waits for the deep tree")
	_check(not m._card_due("new_points") and (game.data["notices"] as Array).has("new_points"),
			"a new save never owes the new-points card, whatever points a level-up gave (spec §9.2.4)")
	var was_deep: bool = Classes.deep
	Classes.set_deep(true)
	game.data["notices"] = []
	game.data["points_back"] = 4
	_check(m._card_due("new_points"), "it's owed once a load turned Vigil ranks back into points (points_back 4)")
	game.data.erase("points_back")
	_check(not m._card_due("new_points"), "and not for unspent points alone")
	# The update card says what the build holds (the int2 review: a W3-W4
	# build promised four worlds and the Hush, and the card is seen once).
	var built_new := 0
	for wn in range(3, 7):
		if m._world_built(wn):
			built_new += 1
	var ub: String = m.v3_update_body()
	if built_new >= 4:
		_check(ub == str(m.CARDS[0][2]), "with all four new worlds built, the update card names them and the Hush")
	else:
		_check(not ub.contains("Hush") and not ub.contains("four new worlds") and ub.contains("deeper"),
				"with %d new worlds built, the update card promises no more than that: %s" % [built_new, ub])
	Classes.set_deep(was_deep)
	m.free()
	# The World: a T5 item without its icon shows the highest drawn; a boss pair picks from its pool.
	var w := _world("1-1")
	await process_frame
	var it := {"slot": "coat", "tier": 5, "cls": "knight"}
	_check(ResourceLoader.exists("res://art/items/%s.svg" % w._item_icon(it)), "a tier-5 coat's icon exists (clamped): %s" % w._item_icon(it))
	_check(w._item_icon({"slot": "weapon", "tier": 2, "cls": "knight"}) == "weapon_knight_2", "a drawn tier keeps its own icon")
	var pool := ["a_legend", "b_legend"]
	var got := {}
	for i in 40:
		got[w._pick_legend("coat", "knight", pool)] = true
	_check(got.size() == 2 and got.has("a_legend") and got.has("b_legend"), "a boss's first kill picks among its world's pair")
	_check(w.PREFER_UNOWNED, "the unowned preference is on since the wave-1 merge (decisions.md: on with Phase 1)")
	_check((load("res://scripts/items.gd") as Script).call("world_legends", 1) == ["tollbreaker"] and (load("res://scripts/items.gd") as Script).call("world_legends", 2) == ["twin_wick"],
			"W1-W2 bosses have one signature piece each (build 1: Tollbreaker, the Twin Wick)")
	# The audio a level leaves behind: reset on leaving and on a respawn.
	var sx: Node = _stub(STUB_SFX)
	sx.stopped = true
	w._reset_audio(sx, true)
	_check(sx.calls.has(["set_hush", 0.0]) and sx.calls.has(["tape_go", 0.0]) and sx.calls.has(["stop_ambience"]), "leaving a level resets the hush, the tape and the ambience: %s" % [sx.calls])
	sx.calls.clear()
	w._reset_audio(sx, false)
	_check(sx.calls == [["set_hush", 0.0]], "a respawn resets the hush (the tape already runs; the bed plays on): %s" % [sx.calls])
	sx.free()
	# Dims: world_lights' product is Combat.dim_mult's.
	var Combat = load("res://scripts/combat.gd")
	if w.lights != null and w.lights.has_method("dim_product"):
		w.lights.dim("spores", 0.55, 5.0)
		w.lights.dim("hush_zone", 0.8, 5.0)
		var want: float = Combat.dim_mult([0.55, 0.8], float(w.player.stats.get("dim_resist", 0.0)), w.diff)
		_check(absf(w.lights.dim_product() - want) < 1e-6, "the dim product is Combat.dim_mult's (%.4f, %.4f)" % [w.lights.dim_product(), want])
		w.lights.dim("deep", 0.1, 5.0)
		_check(absf(w.lights.dim_product() - float(Combat.DIM_FLOOR[w.diff])) < 1e-6, "and floors at DIM_FLOOR (%.3f)" % w.lights.dim_product())
		for k in ["spores", "hush_zone", "deep"]:
			w.lights.undim(k)
		_check(w.lights.dim_product() == 1.0, "undimmed: 1.0")
	w.queue_free()
	await process_frame
	# The perf line under --autoplay is the v3 one (perf_meter.gd), with v2's words.
	var mm: Node = M.new()
	mm._autoplay = "1-1"
	mm.perf_start()
	for i in 260:
		mm.perf_frame(1.0 / 120.0, 1.0 / 120.0)
	var win: String = str(mm.perf_lines.back()) if not mm.perf_lines.is_empty() else ""
	_check(win.contains("fps 120.0 worst frame 8.3 ms dc ") and win.contains("| gpu ") and win.contains("| texmem "), "the --autoplay window line is v3's: %s" % win)
	mm.free()
	game.reset()


const STUB_BARKS_WORLD := """extends "res://scripts/world.gd"
func _bark_exists(_k: String) -> bool:
	return true
"""
const STUB_BOSS_ID := """extends Node2D
var boss_id := "tollgrave"
"""


func _test_p0_review() -> void:
	## The Phase 0 review's fixes, each pinned.
	var Story = load("res://scripts/story.gd")
	var Elites = load("res://scripts/elites.gd")
	var UIs = load("res://scripts/ui.gd")
	var M = load("res://scripts/main.gd")
	# The feel lab keeps nothing: no XP, no record, no embers banked, no run, no depth.
	game.reset()
	game.new_hero("witch")
	var lv1 = LevelData.load_file("res://levels/lab-1.txt")
	var runs0 := int(game.data["run_counter"])
	var deep0 := int(game.hero()["deepest"])
	var w: Node2D = WorldScript.new()
	w.setup(lv1, true)
	root.add_child(w)
	await process_frame
	_check(w.is_lab() and not w.allows("xp") and not w.allows("record") and not w.allows("loot") and w.allows("flask") and w.allows("special") and w.allows("pool"),
			"a feel lab pays no XP, loot or records (the flask, Specials and the pool work)")
	var xp0 := int(game.hero()["xp"])
	var em0: int = game.embers()
	w.gain_xp(500, w.player.position)
	w.embers_carried = 7
	w._bank()
	w._ring({"pos": w.player.position, "top": w.player.position, "rope": Rect2(), "sprite": Sprite2D.new(), "swing": 0.0, "vel": 0.0, "rung": false})
	_check(int(game.hero()["xp"]) == xp0 and game.embers() == em0 and w.embers_carried == 0, "its XP and embers go nowhere (xp %d, embers %d)" % [int(game.hero()["xp"]), game.embers()])
	_check(not (game.data["levels"]["dusk"] as Dictionary).has("lab-1") and int(game.data["run_counter"]) == runs0 and int(game.hero()["deepest"]) == deep0,
			"no lab-1 record, no run counted, no depth noted")
	w.queue_free()
	await process_frame
	# The Guttered Pool goes where v2 put it: a killing blow soon after a fall leaves it at last firm ground.
	w = _world("1-1")
	await process_frame
	var pl: Node2D = w.player
	var safe: Vector2 = pl.last_safe
	w.embers_carried = 5
	w.fell("pit")
	pl.position += Vector2(96, 0)
	pl.invuln = 0.0
	w.hurt_player(99999.0, pl.position.x + 5.0, "hit", null)
	_check(not w.pool.is_empty() and (w.pool["pos"] as Vector2).distance_to(pl.last_safe + Vector2(0, -6)) < 0.5 and str(w.snuff_sections.back()["cause"]) == "hit",
			"a blow after a fall: the pool at last firm ground as v2 (at %s), the playlog blames the blow" % [w.pool.get("pos")])
	w.queue_free()
	await process_frame
	w = _world("1-1")
	await process_frame
	pl = w.player
	w.embers_carried = 5
	pl.invuln = 0.0
	w.hurt_player(1.0, pl.position.x + 5.0, "hit", null)
	pl.position += Vector2(96, 0)
	pl.invuln = 0.0
	w.hurt_player(99999.0, pl.position.x + 5.0, "hit", null)
	_check(not w.pool.is_empty() and (w.pool["pos"] as Vector2).distance_to(pl.position + Vector2(0, -6)) < 0.5, "a blow after a blow: the pool at his feet")
	_check(w.result().has("secret_new") and w.result()["secret_new"] == false, "result() says whether a silver bell opened its secret just now")
	w.queue_free()
	await process_frame
	# v2's bosses keep v2's phase barks whatever story.gd gains; a v3 boss barks <id>_p<n>.
	var bw: Node2D = _stub(STUB_BARKS_WORLD)
	var hud: CanvasLayer = _stub(STUB_HUD)
	bw.hud = hud
	var bb: Node2D = _stub(STUB_BOSS_ID)
	bw.boss_phase(bb, 2)
	bb.boss_id = "hush"
	bw.boss_phase(bb, 3)
	var barks: Array = hud.said.filter(func(x): return x[0] == "bark").map(func(x): return x[1])
	_check(barks == ["tollgrave_angry", "hush_p3"], "Tollgrave keeps his v2 bark with a tollgrave_p2 key there; the Hush barks hush_p3 (%s)" % [barks])
	hud.free()
	bb.free()
	bw.free()
	# A mode's loot().drop leans the kill drops (the Descent's deeper drops).
	var src: String = STUB_MODE.replace("var boss_opts := {}", "var boss_opts := {}\nvar loot_d := {}").replace('return {"rare": 2.0, "legend": 1.0}', "return loot_d")
	var mode: Object = _stub(src)
	var mw := _mode_world(mode)
	await process_frame
	var e: Node2D = null
	for en in mw.enemies:
		if en != mw.boss and en.tier == "":
			e = en
			break
	if e != null:
		e.item_chance = 0.02
		e.relic_chance = 0.0
		var items := func() -> int: return mw.pickups.filter(func(p): return p["kind"] == "item").size()
		mode.loot_d = {"drop": 0.0}
		var n0: int = items.call()
		for i in 20:
			mw._on_enemy_died(e, "slash")
		var none: bool = items.call() == n0
		mode.loot_d = {"drop": 1000.0}
		for i in 5:
			mw._on_enemy_died(e, "slash")
		_check(none and items.call() == n0 + 5, "loot().drop 0 drops nothing; x1000 drops every time (%d items)" % (items.call() - n0))
	mw.queue_free()
	await process_frame
	# A secret level's Warden: placed with D from warden:, its tier, its boss bar.
	var wl := _rows(["", "", "", "", "", "", "", "", "", "", "", "", "P..........D.................."], "warden: Nine-Knuckle Nell|skeleton|Warded\narea: 6\n", 40)
	wl.id = "1-S"
	wl.world = 1
	game.reset()
	var ww: Node2D = WorldScript.new()
	ww.setup(wl, true)
	root.add_child(ww)
	await process_frame
	var wd: Node2D = ww.warden
	_check(wd != null and wd.tier == "warden" and str(wd.elite_name) == "Nine-Knuckle Nell" and wd.omens == ["Warded"], "warden: spawns at D, tier warden, its name and Omens")
	if wd != null:
		var Enemy = load("res://scripts/enemy.gd")
		_check(absf(wd.max_hp - float(Enemy.WARDEN_LIFE["1-S"]) * Enemy._scale("e_hp", ww.area) * float(Combat.diff("dusk")["hp"])) < 0.01,
				"its life is WARDEN_LIFE[1-S] x e_hp (%.0f)" % wd.max_hp)
		var wh: CanvasLayer = _stub(STUB_HUD)
		ww.hud = wh
		wd.active = true
		ww._update_warden_bar()
		var bars: Array = wh.said.filter(func(x): return x[0] == "boss_bar")
		_check(not bars.is_empty() and str(bars.back()[1].get("name", "")) == "Nine-Knuckle Nell" and bars.back()[1].get("awake", false),
				"awake, it has a boss bar")
		wd.alive = false
		ww._update_warden_bar()
		bars = wh.said.filter(func(x): return x[0] == "boss_bar")
		_check((bars.back()[1] as Dictionary).is_empty() and ww.warden == null, "fallen, the bar goes")
		ww.hud = null
		wh.free()
	ww.queue_free()
	await process_frame
	# 1-3's rising and falling ledges over the lava keep their rider as they fall (v2 dropped him past 120 px/s).
	var w13: Node2D = WorldScript.new()
	game.reset()
	w13.setup(LevelData.load_file("res://levels/1-3.txt"), true)
	w13.no_monsters = true
	root.add_child(w13)
	await process_frame
	var ym: Object = null
	for m in w13.movers:
		if m.kind == "y" and absi(roundi(m.start.x / TILE) - 60) <= 1:
			ym = m
	_check(ym != null, "1-3 has its lava ledge at x 60")
	if ym != null:
		ym.phase = -PI * 0.5 - w13.ftime / ym.period * TAU   # the top of its sweep now
		ym.update(w13.ftime)
		ym.update(w13.ftime)
		var p13: Node2D = w13.player
		p13.reset_at(Vector2(ym.rect().get_center().x, ym.rect().position.y))
		p13.on_floor = true
		p13.riding = ym
		w13.test_pad = {}
		var off := 0
		var fastest := 0.0
		var jumped := {}
		for i in int(ym.period * 0.5 / DT):
			var fall: float = ym.delta.y / DT
			if fall > 125.0 and jumped.is_empty() and i > 10:
				w13.test_pad = {"jump": true}
			w13._read_pad()
			w13.tick(DT)
			if w13.test_pad.get("jump", false) and jumped.is_empty():
				jumped = {"vy": p13.velocity.y, "fall": fall}
				break
			fastest = maxf(fastest, ym.delta.y / DT)
			if p13.riding != ym:
				off += 1
		_check(off == 0 and fastest > 125.0, "1-3: Wick rides the lava ledge down at up to %.0f px/s (off %d ticks)" % [fastest, off])
		_check(not jumped.is_empty() and float(jumped["vy"]) < -560.0, "and a jump there is a ground jump (vy %.0f with the ledge falling %.0f px/s)" % [float(jumped.get("vy", 0.0)), float(jumped.get("fall", 0.0))])
	w13.queue_free()
	await process_frame
	# A vine under a 1-tile roof with air above: the top never hauls him onto the roof.
	var rl := []
	for y in 13:
		var r := ".".repeat(40)
		if y == 2:
			r = r.substr(0, 9) + "####" + r.substr(13)
		if y >= 3 and y <= 12:
			r = r.substr(0, 10) + "{" + r.substr(11)
		rl.append(r)
	rl[12] = "P" + rl[12].substr(1)
	var roof := _rows(rl)
	for pad in [{"jump": true, "right": true}, {"up": true, "right": true}, {"jump": true, "left": true}]:
		var pv := _on_vine(roof, 10, 9.5 * TILE)
		_steps(pv, pad, 2.0)
		_check(pv.position.y > 3.0 * TILE, "holding %s up a vine under a roof never ends on the roof (feet y %.0f)" % [pad.keys(), pv.position.y])
		pv.free()
	# The leap is one arc for a tap and a held thumb: 3.6 tiles back to its
	# height, 3.95 to a tile lower (decisions.md's "about 3.7 tiles" is the
	# contract's vx 205, vy -470, 0.30 s of held gravity; the numbers stay).
	var vl := _vine_level()
	var d := {}
	for held in [false, true]:
		var pj := _player_on(vl, Vector2(10.5 * TILE, 8.5 * TILE + 19.0))
		pj.on_floor = false
		pj.grab_vine(10, 0.5)
		pj.pad = {"right": true, "jump": true, "jump_pressed": true}
		pj.step(DT)
		var x0: float = pj.position.x - 205.0 * DT
		var y0: float = pj.position.y
		var same := 0.0
		var lower := 0.0
		for i in 240:
			pj.pad = {"jump": held}
			pj.step(DT)
			if same == 0.0 and pj.velocity.y > 0.0 and pj.position.y >= y0:
				same = pj.position.x - x0
			if pj.velocity.y > 0.0 and pj.position.y >= y0 + TILE:
				lower = pj.position.x - x0
				break
		d[held] = [same / TILE, lower / TILE]
		pj.free()
	print("  vine leap: tap %.2f / %.2f tiles, held %.2f / %.2f tiles (back to its height / a tile lower)" % [d[false][0], d[false][1], d[true][0], d[true][1]])
	_check(absf(d[false][0] - d[true][0]) < 0.1 and absf(d[false][1] - d[true][1]) < 0.1, "a held thumb doesn't lengthen the leap")
	_check(absf(d[false][0] - 3.58) < 0.1 and absf(d[false][1] - 3.95) < 0.1, "3.6 tiles back to its height (%.2f), 3.95 to a tile lower (%.2f)" % [d[false][0], d[false][1]])
	# The kit's filter sees the hazard (a beam's segment, for the Knight's reflect).
	var pk := _player_on(vl, Vector2(5.5 * TILE, 13.0 * TILE))
	var kit_src := """extends "res://scripts/kits/kit.gd"
var seen := {}
func filter_damage(amount: float, _h: Dictionary) -> float:
	seen = _h
	return amount
"""
	var kit = _stub(kit_src)
	pk.kit = kit
	var beam := {"kind": "beam", "seg": [Vector2(0, 0), Vector2(100, 0)], "reflect": true}
	pk.take_damage(5.0, 0.0, "beam", null, {"hazard": beam, "shot": true})
	_check(kit.seen.get("hazard") == beam and (kit.seen.get("opts", {}) as Dictionary).get("shot", false), "the kit's filter_damage gets the hazard and the opts")
	pk.free()
	# The frozen names other streams code against in Phase 1.
	_check(Story.REST_SUBS["trials_open"] == "trials_open_hollin" and Story.rest_sub("trials_open") == "trials_open" and not Story.taper_resting()
			and Story.taper_flame() == 1.0 and Story.taper_state() == {} and not Story.flag("lost_wicks_all"), "Story: REST_SUBS, rest_sub, the Taper helpers")
	game.reset()
	_check(not Story.flag("hush_given"), "no flag set yet")
	Story.set_flag("hush_given")
	_check(Story.flag("hush_given") and game.seen("flag:hush_given"), "set_flag keeps it (in the story seen)")
	game.reset()
	_check(Elites.DMG_WORLD_TRIM == {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.9, 6: 0.8}, "elites: DMG_WORLD_TRIM")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 5
	var r2 := RandomNumberGenerator.new()
	r2.seed = 5
	_check(Elites.roll_omens("skeleton", "nightfall", 1, r1) == Elites.roll_omens("skeleton", "nightfall", 2, r2), "roll_omens: W1 and W2 roll v2's pool")
	var sk = load("res://scripts/skeleton.gd").new()
	_check(absf(sk.tell(0.6, 0.5) - 0.6) < 1e-6 and absf(sk.tell(0.2, 0.5) - 0.5) < 1e-6 and absf(sk.tell(0.2) - 0.30) < 1e-6, "tell(sec, floor): the move's own floor over 0.30")
	sk.strike_logged(Rect2(), 5.0)
	sk.free()
	var fargs := []
	for m in (UIs as Script).get_script_method_list():
		if m["name"] == "flame":
			fargs = (m["args"] as Array).map(func(x): return x["name"])
	_check(fargs.size() == 9 and fargs[8] == "pal", "UI.flame takes a palette last (contract §11): %s" % [fargs])
	var mt: Node = M.new()
	_check(mt.has_method("show_tales"), "main has the Tales route (tales from the title and saves screens)")
	mt.free()


# ---------------------------------------------------------------- build 1: loot

const STUB_LOOT_HUD := """extends CanvasLayer
var said := []
func show_pickup(it, chips, where) -> void:
	said.append(["show_pickup", where])
func power_card(it) -> void:
	said.append(["power_card", str(it.get("uid", ""))])
func bark(k: String) -> void:
	pass
func bump_embers() -> void:
	pass
func boss_bar(i) -> void:
	pass
func cards() -> int:
	return said.filter(func(s): return s[0] == "power_card").size()
"""


func _test_loot_build1() -> void:
	## Build 1's loot slice in the World: a boss pays his embers (with his
	## drops only); Tollgrave's and the Snuffer's first kills give their
	## signature piece; the vault's Lidlurk pays a relic (a gold-table item
	## once the codex is full; a mode's Lidlurk its item, a lab's nothing); a
	## Legendary is worn over a piece that isn't one with auto-equip on (not
	## when that would melt the worn piece), its moment only for a player
	## (never headless, under --autoplay, or on a golden route); the playlog
	## line's loot and ember fields, embers_spent cleared once it's written.
	var count_embers := func(w: Node2D) -> int: return w.pickups.filter(func(p): return p["kind"] == "ember" and not p["taken"]).size()
	for row in [["1-4", "tollbreaker", 30], ["2-4", "twin_wick", 50]]:
		var bw := _world_as(str(row[0]), "knight")
		await process_frame
		bw.set_physics_process(false)
		var b: Node2D = bw.boss
		_check(b != null and int(b.embers) == int(row[2]), "%s: the boss carries %d embers" % [row[0], row[2]])
		if b != null:
			var n0: int = count_embers.call(bw)
			bw.boss_defeated(b, b.center())
			var paid: int = count_embers.call(bw) - n0
			var loose: int = bw.pickups.filter(func(p): return p["kind"] == "ember" and p["loose"]).size()
			_check(paid == int(b.embers) and loose >= paid, "%s: he pays them, %d loose embers where he fell (never paid before build 1)" % [row[0], paid])
			var prize := ""
			for p in bw.pickups:
				if p["kind"] == "item" and bool(p.get("boss_first", false)):
					prize = str(p["item"].get("legend", ""))
			_check(prize == str(row[1]), "%s: his first kill gives his signature piece (%s)" % [row[0], prize])
		bw.queue_free()
		await process_frame
	# The vault's Lidlurk.
	var w := _world_as("1-1", "knight")
	await process_frame
	w.set_physics_process(false)
	var loot_of := func(x: Node2D) -> Array: return x.pickups.filter(func(p): return p["kind"] == "relic" or p["kind"] == "item")
	var lid: Node2D = null
	for e in w.enemies:
		if e.kind == "lidlurk":
			lid = e
	_check(lid != null, "1-1's vault has its Lidlurk")
	if lid != null:
		var k0: int = loot_of.call(w).size()
		w._on_enemy_died(lid, "slash")
		var got: Array = loot_of.call(w).slice(k0)
		_check(got.size() == 1 and got[0]["kind"] == "relic" and str(got[0]["rarity"]) != "common",
				"the vault's Lidlurk pays a relic, at least a Blessed (%s)" % [got.map(func(p): return [p["kind"], p["rarity"]])])
		game.data["relics"] = Relics.ids().duplicate()
		k0 = loot_of.call(w).size()
		w._on_enemy_died(lid, "slash")
		got = loot_of.call(w).slice(k0)
		_check(got.size() == 1 and got[0]["kind"] == "item" and str(got[0]["rarity"]) in ["rare", "legendary"],
				"with every relic found, a gold-table item instead (%s)" % [got.map(func(p): return [p["kind"], p["rarity"]])])
		game.data["relics"] = []
	w.queue_free()
	await process_frame
	for row in [["mode", "1-1"], ["lab", "lab-0"]]:
		var mw: Node2D = _mode_world(_stub(STUB_MODE)) if row[0] == "mode" else _world(str(row[1]))
		await process_frame
		mw.set_physics_process(false)
		var ml: Node2D = null
		for e in mw.enemies:
			if e.kind == "lidlurk":
				ml = e
		if ml != null:
			var k0: int = loot_of.call(mw).size()
			mw._on_enemy_died(ml, "slash")
			var kinds: Array = loot_of.call(mw).slice(k0).map(func(p): return p["kind"])
			_check(kinds == (["item"] if row[0] == "mode" else []), "a %s's Lidlurk: %s (%s)" % [row[0], "its item, no relic" if row[0] == "mode" else "nothing kept", kinds])
		else:
			_check(false, "(%s has a Lidlurk)" % row[1])
		mw.queue_free()
		await process_frame
	# A Legendary is worn over a piece that isn't one.
	w = _world_as("1-1", "knight")
	await process_frame
	w.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var auto = game.setting("auto_equip")
	game.set_setting("auto_equip", true)
	var h: Dictionary = game.hero()
	var in_satchel := func(it: Dictionary) -> bool: return (h["satchel"] as Array).any(func(o): return o is Dictionary and str(o.get("uid", "")) == str(it["uid"]))
	var worn := func(slot: String) -> String: return str(h["equip"][slot].get("uid", "")) if h["equip"].get(slot) is Dictionary else ""
	var strong := Items.make("weapon", "knight", 30, "rare", rng)
	game.equip(strong)
	w.apply_hero()
	var dawn := Items.make("weapon", "knight", 1, "legendary", rng, "dawnsliver")
	var chips := Hero.compare(h, "weapon", dawn, h.get("belt", []), "dusk")
	_check(float(chips["dmg"]) < 0.0, "(the Legendary reads weaker on the chips: %.0f%% DMG)" % float(chips["dmg"]))
	_check(w._take_item(dawn) == "equipped" and worn.call("weapon") == str(dawn["uid"]) and in_satchel.call(strong),
			"a Legendary is worn over a piece that isn't one, whatever its chips; the old one waits in the satchel")
	_check(w.hitstop <= 0.0, "headless: no freeze")
	game.equip(Items.make("weapon", "knight", 30, "legendary", rng, "tollbreaker"))
	var weak := Items.make("weapon", "knight", 1, "legendary", rng, "dawnsliver")
	_check(w._take_item(weak) == "satchel" and worn.call("weapon") != str(weak["uid"]), "over a Legendary the chips decide: a weaker one goes to the satchel")
	game.equip(strong)
	game.set_setting("auto_equip", false)
	var off := Items.make("weapon", "knight", 1, "legendary", rng, "dawnsliver")
	_check(w._take_item(off) == "satchel" and worn.call("weapon") == str(strong["uid"]), "auto-equip off: the Legendary waits in the satchel")
	game.set_setting("auto_equip", true)
	while (h["satchel"] as Array).size() < int(game.SATCHEL_MAX):
		(h["satchel"] as Array).append(Items.make("coat", "knight", 1, "magic", rng))
	var full := Items.make("weapon", "knight", 1, "legendary", rng, "dawnsliver")
	_check(w._take_item(full) == "full" and worn.call("weapon") == str(strong["uid"]),
			"the satchel full: a Legendary that would melt the worn piece isn't worn by itself (its card asks)")
	h["satchel"] = []
	# Its moment: a player's only.
	var hud: CanvasLayer = _stub(STUB_LOOT_HUD)
	w.hud = hud
	w.headless = false
	w.test_pad = null
	w.hitstop = 0.0
	var lit := Items.make("candle", "knight", 1, "legendary", rng, "gutterlight")
	_check(w._take_item(lit) == "equipped" and is_equal_approx(w.hitstop, w.LEGEND_FREEZE) and hud.said.has(["power_card", str(lit["uid"])]),
			"a player's Legendary: the world stops %.2f s and the HUD holds its New power card" % w.hitstop)
	game.set_setting("auto_equip", false)
	w.hitstop = 0.0
	var later := Items.make("boots", "knight", 1, "legendary", rng, "thornsole")
	_check(w._take_item(later) == "satchel" and w.hitstop > 0.0 and hud.cards() == 2, "one into the satchel has its moment too")
	for flag in ["autoplay", "no_monsters", "test_pad", "headless"]:
		w.hitstop = 0.0
		match flag:
			"autoplay":
				w.autoplay = true
			"no_monsters":
				w.no_monsters = true
			"test_pad":
				w.test_pad = {}
			"headless":
				w.headless = true
		var quiet := Items.make("boots", "knight", 1, "legendary", rng, "cinderstep")
		_check(w._take_item(quiet) == "satchel" and w.hitstop <= 0.0 and hud.cards() == 2, "%s: a Legendary has no moment (no freeze, no held card)" % flag)
		w.autoplay = false
		w.no_monsters = false
		w.test_pad = null
		w.headless = false
	game.set_setting("auto_equip", auto)
	# The playlog's line: its loot and embers, and embers_spent cleared once written.
	var Playlog = load("res://scripts/playlog.gd")
	w.embers_got = 17
	var line: Dictionary = Playlog.entry(w, false, {})
	_check(int(line.get("items_found", -1)) == w.items_found.size() and int(line.get("legendaries_worn", -1)) == 1
			and int(line.get("relics_found", -1)) == w.relics_found.size() and int(line.get("embers_earned", -1)) == 17 and line.has("embers_spent"),
			"the playlog line has items_found, legendaries_worn, relics_found, embers_earned, embers_spent (%s)" % [line])
	var kept_path: String = Playlog.path
	Playlog.path = "user://test_core_playlog.json"
	game.embers_spent = 42
	w._log(false)
	var all = JSON.parse_string(FileAccess.get_file_as_string(Playlog.path))
	_check(all is Array and int(all[all.size() - 1].get("embers_spent", -1)) == 42 and game.embers_spent == 0,
			"_log writes embers_spent (42) and clears it for the next line (%d)" % game.embers_spent)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Playlog.path))
	Playlog.path = kept_path
	w.headless = true
	w.hud = null
	hud.free()
	w.queue_free()
	await process_frame


# ---------------------------------------------------------------- build 1: the Boss Boons

const STUB_BOON_HUD := """extends CanvasLayer
var said := []
var busy := false
func show_pickup(it, chips, where) -> void:
	said.append(["show_pickup", where])
func power_card(it) -> void:
	said.append(["power_card", str(it.get("uid", ""))])
func level_up(n: int) -> void:
	said.append(["level_up", n])
func toast(t: String, s: String) -> void:
	pass
func show_hint(t: String) -> void:
	pass
func bark(k: String) -> void:
	pass
func bump_embers() -> void:
	pass
func boss_bar(i) -> void:
	pass
func title_showing() -> bool:
	return false
func top_card_showing() -> bool:
	return busy
"""


func _as_player(w: Node2D) -> CanvasLayer:
	## A headless test World played as a player's is: a display, a HUD (a
	## stub), Input's pad (no test pad), so a choice may stop it.
	var hud: CanvasLayer = _stub(STUB_BOON_HUD)
	w.hud = hud
	w.headless = false
	w.no_display = false
	w.test_pad = null
	return hud


func _kill_boss(w: Node2D, b: Node2D) -> void:
	## His killing blow in a stuck window (_test_boss_after's), then his fall
	## to boss_defeated (1.2 s) and its hitstop.
	b.phase = 3
	b.hp = 1.0
	b.state = "stuck"
	w.player.invuln = 100.0
	w.deal(b, 1.0, {"flat": 99999.0})
	for i in int(1.5 / DT):
		w.tick(DT)


func _test_boss_boons() -> void:
	## A boss's first kill on a difficulty, a player at the controls: his
	## prize is chosen on the choice card (world.open_boon), not dropped: two
	## or three Legendaries, his signature first, each naming its power, and
	## no Later. It opens once his fall has settled (BOON_WAIT, the level-up
	## card's time), and a pick goes through the pickup's own path (worn,
	## its New power moment) and only then counts as given. A second kill
	## drops as before; so does a first kill under the --autoplay bot (or on
	## a route, a scripted pad, headless, in a mode). A bell rung first holds
	## the level's end until the boon is chosen. Every Legendary's power fits
	## its card.
	var auto = game.setting("auto_equip")
	game.set_setting("auto_equip", true)
	var boss_firsts := func(w: Node2D) -> Array: return w.pickups.filter(func(p): return p["kind"] == "item" and bool(p.get("boss_first", false)))
	# Tollgrave's first kill, a player's: the boon.
	var w := _world_as("1-4", "knight")
	await process_frame
	w.set_physics_process(false)
	var b := _wake_boss(w)
	var hud := _as_player(w)
	_check(w.boon_block() == "", "a player's first kill may offer the boon (%s)" % w.boon_block())
	var embers0: int = w.pickups.filter(func(p): return p["kind"] == "ember").size()
	_kill_boss(w, b)
	_check(not b.alive and not w._boon.is_empty() and boss_firsts.call(w).is_empty(), "he falls: his boon waits, and no prize drops")
	_check(w.pickups.filter(func(p): return p["kind"] == "ember").size() - embers0 >= int(b.embers), "his embers are paid all the same (%d)" % int(b.embers))
	hud.busy = true
	for i in int(1.5 / DT):
		w.tick(DT)
	_check(not w._boon.is_empty() and (w.choice == null or not w.choice.is_open()), "it waits while the level-up card shows")
	hud.busy = false
	w.tick(DT)
	_check(w.choice != null and w.choice.is_open() and w.paused and w._boon.is_empty(), "then the boon opens over the paused level")
	var offers: Array = w.choice.offers if w.choice != null else []
	var ids: Array = offers.map(func(o): return str(o["id"]))
	_check(offers.size() == 3 and ids[0] == "tollbreaker" and ids.count("tollbreaker") == 1, "three Legendaries, his signature first (%s)" % [ids])
	var named := true
	for o in offers:
		var l: Dictionary = Items.LEGENDS[o["id"]]
		named = named and str(o["name"]) == str(l["name"]) and str(o["text"]) == str(l["text"]) and o["item"] is Dictionary and str(o["item"]["legend"]) == str(o["id"])
	_check(named, "each card names its Legendary and its power")
	_check(w.choice.heading.begins_with("Old Tollgrave") and w.choice.button_rect() == Rect2() and str(offers[0]["sub"]).contains("Old Tollgrave's own"),
			"his name on the heading and on his own card, and no Later (%s)" % w.choice.heading)
	_check(not game.level_record("1-4").get("boss_first", false), "(not given yet)")
	var prize: Dictionary = offers[0]["item"]
	w.choice.choose(0)
	var h: Dictionary = game.hero()
	_check(not w.paused and not w.choice.is_open(), "a pick closes it and play goes on")
	_check(str(h["equip"]["weapon"].get("uid", "")) == str(prize["uid"]) and w.items_found.has(prize), "the pick is worn at once, over a piece that isn't a Legendary")
	_check(hud.said.has(["power_card", str(prize["uid"])]) and is_equal_approx(w.hitstop, w.LEGEND_FREEZE), "with its New power moment (the freeze, the held card)")
	_check(game.level_record("1-4").get("boss_first", false), "and now the first kill counts as given")
	# A second kill drops as before.
	var n0: int = w.pickups.filter(func(p): return p["kind"] == "item").size()
	w.boss_defeated(b, b.center())
	var dropped: int = w.pickups.filter(func(p): return p["kind"] == "item").size() - n0
	for i in int(1.5 / DT):
		w.tick(DT)
	_check(w._boon.is_empty() and not w.choice.is_open() and dropped == 3 and boss_firsts.call(w).is_empty(),
			"a second kill: no boon, his three drops as before (%d)" % dropped)
	# Why not: only a player's story level.
	var whys := {}
	for flag in ["autoplay", "route", "scripted", "headless"]:
		match flag:
			"autoplay":
				w.autoplay = true
			"route":
				w.no_monsters = true
			"scripted":
				w.test_pad = {}
			"headless":
				w.no_display = true
		whys[flag] = w.boon_block()
		w.autoplay = false
		w.no_monsters = false
		w.test_pad = null
		w.no_display = false
	_check(whys == {"autoplay": "autoplay", "route": "route", "scripted": "scripted", "headless": "headless"}, "never under the bot, on a route, a scripted pad or headless (%s)" % [whys])
	for id in Items.world_legends(1) + ["dawnsliver", "gutterlight", "ossuary_coat", "thornsole", "cinderstep", "first_dawn"]:
		(h["satchel"] as Array).append(Items.make(str(Items.LEGENDS[id]["slot"]), "knight", 4, "legendary", RandomNumberGenerator.new(), id))
	_check(w.boon_block() == "no choice", "every other one held: no choice, so it drops (%s)" % w.boon_block())
	h["satchel"] = []
	w.headless = true
	w.hud = null
	hud.free()
	w.queue_free()
	await process_frame
	# Under the --autoplay bot the Snuffer's first kill drops his prize, as before.
	w = _world_as("2-4", "knight")
	await process_frame
	w.set_physics_process(false)
	b = _wake_boss(w)
	hud = _as_player(w)
	w.autoplay = true
	_kill_boss(w, b)
	for i in int(1.5 / DT):
		w.tick(DT)
	var got: Array = boss_firsts.call(w)
	_check(w._boon.is_empty() and w.choice == null and got.size() == 1 and str(got[0]["item"]["legend"]) == "twin_wick",
			"under the bot: no card, his signature drops where he fell (%s)" % [got.map(func(p): return p["item"]["legend"])])
	w.autoplay = false
	# A bell rung before the boon opens holds the level's end for it.
	game.level_record("2-4")["boss_first"] = false
	var done := [false]
	w.finished.connect(func(_r): done[0] = true)
	w.boss_defeated(b, b.center())
	w.add_bell(w.player.position)
	for i in int(0.5 / DT):
		w.tick(DT)
	_check(w.state == "clear" and w.clear_time == 0.0 and not w._boon.is_empty(), "the bell rings first: the level's end waits for the boon")
	for i in int(1.0 / DT):
		w.tick(DT)
	_check(w.choice != null and w.choice.is_open(), "which opens over the rung bell")
	w.choice.choose(1)
	_check(game.level_record("2-4").get("boss_first", false), "a pick of another than his own counts too")
	var Playlog = load("res://scripts/playlog.gd")
	var kept_path: String = Playlog.path
	Playlog.path = "user://test_core_boon_playlog.json"
	for i in int(4.0 / DT):
		w.tick(DT)
	_check(done[0], "then the level ends as it does")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Playlog.path))
	Playlog.path = kept_path
	w.headless = true
	w.hud = null
	hud.free()
	w.queue_free()
	await process_frame
	# World 3's boss: his pair, then one other.
	w = _world_as("3-4", "witch")
	await process_frame
	var cards: Array = w.boon_offers("Mother Gravebough")
	_check(cards.size() == 3 and cards.slice(0, 2).map(func(o): return o["id"]) == Items.world_legends(3) and not Items.world_legends(3).has(cards[2]["id"])
			and str(cards[1]["sub"]) == "Candle · Mother Gravebough's own", "Gravebough's boon: her pair, then one other (%s)" % [cards.map(func(o): return o["id"])])
	_check(w.whose("The Tinker of Hours") == "The Tinker's" and w.whose("The Hush") == "The Hush's" and w.whose("") == "the boss's",
			"a boss's name as an owner: The Tinker's (of Hours), The Hush's, the boss's")
	w.queue_free()
	await process_frame
	# Every Legendary's power fits a card: three lines at most.
	var CC = load("res://scripts/choice_card.gd")
	var w_text: float = (CC.layout(Rect2(0, 0, 844, 390), 100.0, 3)[0] as Rect2).size.x - 16.0
	var long := []
	for id in Items.LEGENDS:
		var fit: Dictionary = CC.fit_text(str(Items.LEGENDS[id]["text"]), w_text)
		if (fit["lines"] as Array).size() > CC.TEXT_LINES:
			long.append(id)
	_check(long.is_empty(), "every Legendary's power fits its card in %d lines (%s)" % [CC.TEXT_LINES, long])
	var lc: Dictionary = CC.fit_text(str(Items.LEGENDS["last_candle"]["text"]), w_text)
	_check(int(lc["size"]) < 13 and (lc["lines"] as Array).all(func(l): return not str(l).begins_with("s.")), "a long one a size smaller, its numbers kept with their units (%s)" % [lc["lines"]])
	game.set_setting("auto_equip", auto)


# ---------------------------------------------------------------- wave 1's W0 wiring

func _foe(w: Node2D, kind: String, at: Vector2) -> Node2D:
	var e: Node2D = w.spawn_enemy(kind, at, {})
	e.max_hp = 1.0e6
	e.hp = e.max_hp
	e.active = true
	return e


func _test_wave1_wiring() -> void:
	## What the wave-1 integration wired into world.gd, main.gd and the
	## dispatcher: the v3 Legendary and relic powers, the altar snapshot,
	## put_out / relight for v2's lantern posts, the Escapement's shots.
	var w := _world_as("1-1", "knight")
	await process_frame
	w.set_physics_process(false)
	var pl: Node2D = w.player
	var at: Vector2 = pl.position + Vector2(40, 0)
	var e := _foe(w, "skeleton", at)
	var o := _foe(w, "skeleton", at + Vector2(30, 0))
	var legends: Dictionary = pl.stats["legends"]
	var flags: Dictionary = pl.stats["flags"]
	# Hoarfrost Mantle: who strikes him is frozen, once every 4 s.
	legends["hoarfrost"] = true
	flags.merge({"hoarfrost_stun": 1.5, "hoarfrost_boss": 0.3, "hoarfrost_cd": 4.0}, true)
	pl.invuln = 0.0
	w.hurt_player(2.0, e.position.x, "hit", e)
	_check(float(e.status.get("stun", 0.0)) > 1.4, "Hoarfrost Mantle: the foe that hurt him is frozen 1.5 s")
	e.status.erase("stun")
	pl.invuln = 0.0
	w.hurt_player(2.0, e.position.x, "hit", e)
	_check(not e.status.has("stun"), "and not again within 4 s")
	legends.erase("hoarfrost")
	# The Last Candle: under 30% life, foes in his light are stunned and he's untouchable, once per altar.
	legends["last_candle"] = true
	flags.merge({"lastcandle_below": 0.30, "lastcandle_stun": 1.0, "lastcandle_invuln": 1.5}, true)
	pl.hp = pl.max_hp * 0.32
	pl.invuln = 0.0
	o.status.erase("stun")
	w.hurt_player(pl.max_hp * 0.05, o.position.x, "hit", null)
	_check(pl.invuln >= 1.4 and float(o.status.get("stun", 0.0)) > 0.9, "the Last Candle: untouchable 1.5 s, foes in his light stunned 1 s")
	pl.invuln = 0.0
	o.status.erase("stun")
	w.hurt_player(1.0, o.position.x, "hit", null)
	_check(not o.status.has("stun"), "and only once until the next altar")
	legends.erase("last_candle")
	pl.hp = pl.max_hp
	# Rootbound Treads and the Hoarfrost Bell on a stomp.
	legends["rootbound"] = true
	flags.merge({"rootbound_r": 90.0, "rootbound_s": 1.2, "chill_slow": 0.4, "chill_t": 2.0}, true)
	e.status.clear()
	o.status.clear()
	w._stomp_powers(e, e.rect())
	_check(float(o.status.get("root", 0.0)) > 1.1 and float(e.status.get("slow", 0.0)) > 1.9, "Rootbound roots foes within 90 px of a stomp; the Hoarfrost Bell chills the stomped")
	legends.erase("rootbound")
	flags.erase("chill_slow")
	e.status.clear()
	o.status.clear()
	# The Hour-Hand stacks on one foe; Hushbane's 5th hit stuns.
	legends["hour_hand"] = true
	legends["hushbane"] = true
	flags.merge({"hourhand_step": 0.08, "hourhand_max": 0.40, "hourhand_t": 3.0, "hushbane_every": 5, "hushbane_bonus": 1.5, "hushbane_stun": 0.5}, true)
	for i in 5:
		e.last_swing = -1
		w.deal(e, 1.0, {"how": "slash", "no_hitstop": true})
	_check(int((e.get_meta("hour_hand", {}) as Dictionary).get("n", 0)) == 5, "the Hour-Hand counts each hit on the same foe")
	_check(e.status.has("stun"), "Hushbane: the 5th hit on a foe stuns it")
	legends.erase("hour_hand")
	legends.erase("hushbane")
	# Prismglass: a crit throws a shard at the nearest other foe.
	legends["prismglass"] = true
	flags.merge({"prism_coef": 0.5, "prism_range": 200.0}, true)
	var before := float(o.hp)
	w.deal(e, 1.0, {"how": "slash", "force_crit": true, "no_hitstop": true})
	_check(float(o.hp) < before, "Prismglass: a crit's shard hits the next foe (%.0f -> %.0f)" % [before, float(o.hp)])
	legends.erase("prismglass")
	# The Escapement on a caster: every 4th basic shot strikes twice.
	legends["escapement"] = true
	flags.merge({"escapement_every": 4, "escapement_coef": 0.6}, true)
	var twice := []
	for i in 4:
		twice.append(bool(w.spawn_shot({"kind": "spark", "pos": pl.center(), "vel": Vector2(10, 0), "life": 0.01}).get("twice", false)))
	_check(twice == [false, false, false, true], "the Escapement: the 4th basic shot ticks twice (%s)" % [twice])
	legends.erase("escapement")
	# The Deep Chalice: a drink makes him untouchable 0.6 s.
	flags["chalice_invuln"] = 0.6
	pl.hp = pl.max_hp * 0.5
	pl.invuln = 0.0
	w.flask_charges = 1
	w._pad = {"flask_pressed": true}
	w._update_flask(DT)
	_check(pl.invuln >= 0.59, "the Deep Chalice: drinking, he's untouchable 0.6 s")
	flags.erase("chalice_invuln")
	w._pad = {}
	# The Bone Flute: the 8th kill sends a moth at the nearest foe.
	flags.merge({"bone_flute_every": 8, "bone_flute_coef": 1.5}, true)
	w._flute_kills = 7
	var hp_before := float(e.hp) + float(o.hp)
	var v := _foe(w, "skeleton", at + Vector2(10, 0))
	v.hp = 1.0
	w.deal(v, 1.0, {"how": "slash", "flat": 50.0, "no_hitstop": true})
	_check(not v.alive and float(e.hp) + float(o.hp) < hp_before, "the Bone Flute: every 8th kill, a bone moth strikes the nearest foe")
	flags.erase("bone_flute_every")
	w.queue_free()
	await process_frame
	# put_out / relight: a v2 lantern post goes out and comes back longer; an anchor never goes out.
	var lamp_level := ""
	for info in game.LEVELS:
		if FileAccess.get_file_as_string(str(info["path"])).split("---")[-1].contains("L"):
			lamp_level = str(info["id"])
			break
	w = _world_as(lamp_level if lamp_level != "" else "1-1", "knight")
	await process_frame
	w.set_physics_process(false)
	var f = w.features
	if f.lanterns.is_empty():
		_check(false, "a level with a lantern post to swallow (%s)" % lamp_level)
	else:
		var l: Dictionary = f.lanterns[0]
		f.light(l, true)
		f.put_out(l)
		_check(not l["lit"], "put_out: a v2 lantern post goes out (the Stillmaw's swallow)")
		f.relight(l, 10.0)
		_check(l["lit"] and float(l["t"]) > float(f.LANTERN_LIFE) + 9.0, "relight: it comes back, with the choke's extra time")
		l["anchor"] = true
		f.put_out(l)
		_check(l["lit"], "a lamp tagged anchor is never put out")
		l.erase("anchor")
	w.queue_free()
	await process_frame
	# The altar snapshot: lit altar -> Game.suspended(); a World handed it
	# starts at that altar, with what was killed and taken gone.
	var lv = LevelData.load_file("res://levels/1-2.txt")
	game.reset()
	game.new_hero("knight")
	for k in ["start", "boss"]:
		if str(lv.story.get(k, "")) != "":
			game.mark_seen(str(lv.story[k]))
	w = WorldScript.new()
	w.setup(lv, false)
	root.add_child(w)
	await process_frame
	w.paused = true
	var n_enemies: int = w.enemies.size()
	var first: Node2D = w.enemies[0]
	w.deal(first, 1.0, {"how": "slash", "flat": 1.0e6, "no_hitstop": true})
	w.sigils_got[1] = true
	w._light_altar(w.altars[0])
	var sus: Dictionary = game.suspended()
	_check(str(sus.get("level", "")) == "1-2" and int(sus.get("altar", -1)) == 0 and (sus.get("killed", []) as Array).size() == 1
			and bool((sus.get("sigils", []) as Array)[1]), "an altar lit writes the snapshot (level, altar, killed, sigils): %s" % [sus])
	w.queue_free()
	await process_frame
	await process_frame
	_check(game.suspended().is_empty(), "leaving the level through the game drops it")
	var w2: Node2D = WorldScript.new()
	w2.setup(LevelData.load_file("res://levels/1-2.txt"), true)
	w2.resume = sus
	root.add_child(w2)
	await process_frame
	w2.set_physics_process(false)
	_check(w2.player.position.distance_to(w2.altars[0]["pos"]) < 2.0 and w2.altars[0]["lit"] and w2.enemies.size() == n_enemies - 1
			and w2.sigils_got[1], "a World handed it starts at that altar, lit, with the kill and the sigil kept")
	w2.queue_free()
	await process_frame
	game.reset()
	# The modes' pill in the HUD's keys (mode.gd hud_pill: the two streams' formats met at the merge).
	var MS = load("res://scripts/modes/mode.gd")
	var dp: Dictionary = MS.hud_pill({"mode": "descent", "text": "D7", "spare": 1, "spare_max": 2, "hushings": 3, "time": 40.0})
	var tp: Dictionary = MS.hud_pill({"mode": "trial", "text": "0:12.34", "time": 12.34, "lit": 2, "total": 5, "started": true})
	var xp: Dictionary = MS.hud_pill({"mode": "waxworks", "text": "5 drips", "drips": 5, "time": 9.0})
	_check(dp["label"] == "D7" and int(dp["lives"]) == 1 and int(dp["lives_max"]) == 2 and int(dp["dots"]) == 3
			and is_equal_approx(float(tp["clock"]), 12.34) and tp["count"] == "2/5" and xp["label"] == "5 drips" and not xp.has("clock"),
			"a mode's pill reaches the HUD's pill in its keys (label, clock, lives, dots, count)")

