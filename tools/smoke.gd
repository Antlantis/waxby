# The smoke bot (workstreams.md §3, "every merge"): every level with every
# calling, the --autoplay bot (autoplay_bot.gd) at the controls, headless, on
# a fixed 1/120 tick. The hero comes in at the level's entry level (W1-W2's
# first-run pacing, as test_integration.gd). One line a run: the bell rung,
# the boss woken, the furthest x, snuffs, script errors; then a summary. A
# shaped level (the bot goes by route: a tower's goal is overhead, a mirrored
# level's behind) reports its route progress too: the fewest moves from the
# goal it got to, of the start's (route_field.gd), as x means nothing there.
#   godot --headless --path game --script res://../tools/smoke.gd -- [levels|all] [callings|all] [seconds]
#   e.g. -- all all 150          -- 2-4 knight,witch 90
# Exits non-zero when any run logs a script error. A run the bot can't finish
# in time (it is a debug bot: see autoplay_bot.gd) is reported, not failed.
extends SceneTree

const DT := 1.0 / 120.0
const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
# The hero's level coming into each level on a first Dusk run (W2's pacing;
# test_integration.gd's table). Levels not listed come in at level 1.
const ENTRY := {"1-1": 1, "1-2": 3, "1-3": 5, "1-4": 7, "2-1": 8, "2-2": 10, "2-3": 11, "2-4": 12,
		"3-1": 13, "3-2": 14, "3-3": 15, "3-4": 17, "4-1": 18, "4-2": 19, "4-3": 20, "4-4": 21,   # W3-W4: PR's XP walk
		"5-1": 23, "5-2": 23, "5-3": 24, "5-4": 26, "6-1": 27, "6-2": 28, "6-3": 29, "6-4": 30,
		# the secret levels at their world's boss arrival (their areas are the boss's)
		"1-S": 7, "2-S": 13, "3-S": 17, "4-S": 22, "5-S": 26, "6-S": 30}


class Catch extends Logger:
	var errors: Array = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, bts: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := "%s:%d %s %s %s" % [file, line, function, code, rationale]
		for bt in bts:
			if bt != null and not bt.is_empty():
				var frames := []
				for i in mini(bt.get_frame_count(), 4):
					frames.append("%s:%d %s" % [bt.get_frame_file(i), bt.get_frame_line(i), bt.get_frame_function(i)])
				text += "  <- " + " <- ".join(frames)
				break
		_lock.lock()
		errors.append(text)
		_lock.unlock()

	func count() -> int:
		_lock.lock()
		var n := errors.size()
		_lock.unlock()
		return n


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var game: Node = root.get_node("Game")
	game.save_path = "user://smoke_save.json"
	var Progression = load("res://scripts/progression.gd")
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	var levels: Array = []
	if args.size() > 0 and args[0] != "all":
		levels = Array(args[0].split(","))
	else:
		for info in game.LEVELS:
			levels.append(str(info["id"]))
		# The secret levels too (workstreams §4.2: W1-W6 and secrets).
		for info in (game.get_script() as Script).get_script_constant_map().get("SECRET_LEVELS", []):
			levels.append(str(info["id"]))
	var callings: Array = CALLINGS if args.size() < 2 or args[1] == "all" else Array(args[1].split(","))
	var secs := float(args[2]) if args.size() > 2 else 150.0
	var catch := Catch.new()
	OS.add_logger(catch)
	var rows: Array = []
	for cls in callings:
		for id in levels:
			var path := "res://levels/%s.txt" % id
			if not FileAccess.file_exists(path):
				continue
			game.reset()
			for s in ["intro", "oath"]:
				game.mark_seen(s)
			game.new_hero(cls)
			var want: int = int(ENTRY.get(id, 1))
			var target: int = Progression.total_to(want + 1) - 3
			if int(game.hero()["xp"]) < target:
				game.add_xp(target - int(game.hero()["xp"]))
			var lv = LevelData.load_file(path)
			for k in ["start", "boss"]:
				var sid := str(lv.story.get(k, ""))
				if sid != "":
					game.mark_seen(sid)
			var e0 := catch.count()
			var w: Node2D = World.new()
			w.setup(lv, true)
			w.autoplay = true
			root.add_child(w)
			w.set_physics_process(false)
			await process_frame
			var far := 0.0
			var route := Vector2i(-1, -1)   # by route: (the start's moves from the goal, the fewest it got to)
			var woke := false
			var t := 0.0
			var ticks := int(secs / DT)
			for i in ticks:
				if w.get("_bot") == null:
					break
				w.test_pad = w._bot.pad(DT)
				w._read_pad()
				w.tick(DT)
				far = maxf(far, w.player.position.x)
				var fl = null
				if w._bot.get("by_route"):
					# (the level's goal's field, not a room's other deck's while it fights there)
					fl = w._bot.get("_level_field") if w._bot.goal.get("room", false) else w._bot.get("field")
				if fl != null:
					var d: int = fl.at(w.player.position)
					route = Vector2i(d if route.x < 0 else route.x, d if route.y < 0 else mini(route.y, d))
				if w.boss != null and is_instance_valid(w.boss) and str(w.boss.get("state")) not in ["sleep", ""]:
					woke = true
				if i % 600 == 0:
					await process_frame   # deferred calls run
				t = (i + 1) * DT
				if w.state == "clear":
					break
			var errs: Array = catch.errors.slice(e0)
			var r := {"cls": cls, "id": id, "bell": w.state == "clear", "t": t, "far": far / 32.0, "snuffs": int(w.snuffs),
					"boss": w.boss != null, "woke": woke, "errors": errs}
			rows.append(r)
			print("[smoke] %-7s %-5s %s in %5.1f s, x %5.1f tiles%s, snuffs %d%s%s" % [cls, id,
					"BELL" if r["bell"] else "----", t, r["far"],
					(", route %d of %d moves left" % [route.y, route.x]) if route.x >= 0 else "", r["snuffs"],
					(", boss woke" if woke else ", boss asleep") if r["boss"] else "",
					(", %d SCRIPT ERRORS: %s" % [errs.size(), errs[0]]) if not errs.is_empty() else ""])
			w.queue_free()
			await process_frame
	var bells := rows.filter(func(r): return r["bell"]).size()
	var errd := rows.filter(func(r): return not (r["errors"] as Array).is_empty()).size()
	print("[smoke] %d runs: %d rang the bell, %d with script errors" % [rows.size(), bells, errd])
	OS.remove_logger(catch)
	quit(1 if errd > 0 else 0)
