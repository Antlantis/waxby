# PROTOTYPE (proto-tall): the --autoplay bot (autoplay_bot.gd) on the tall labs,
# headless, as tools/smoke.gd runs it, but reporting what a vertical level
# needs: the lowest and highest rows reached (smoke.gd reports only the
# furthest x), the row every 10 s, the bot's state and plans, and the snuffs.
#   godot --headless --path game --script res://../tools/proto_bot.gd -- <levels> <callings> <seconds> [drops]
extends SceneTree

const DT := 1.0 / 120.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var levels: Array = Array((args[0] if args.size() > 0 else "lab-2,lab-3").split(","))
	var callings: Array = Array((args[1] if args.size() > 1 else "knight").split(","))
	var secs := float(args[2]) if args.size() > 2 else 150.0
	var Reach = load("res://scripts/reach.gd")
	Reach.DROPS = args.size() > 3 and args[3] == "drops"
	var game: Node = root.get_node("Game")
	game.save_path = "user://proto_bot_save.json"
	var Progression = load("res://scripts/progression.gd")
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	print("drop-through in the bot's plans: ", Reach.DROPS)
	for cls in callings:
		for id in levels:
			game.reset()
			for s in ["intro", "oath"]:
				game.mark_seen(s)
			game.new_hero(cls)
			game.add_xp(Progression.total_to(16) - int(game.hero()["xp"]))
			var lv = LevelData.load_file("res://levels/%s.txt" % id)
			var w: Node2D = World.new()
			w.setup(lv, true)
			w.autoplay = true
			root.add_child(w)
			w.set_physics_process(false)
			await process_frame
			var top := 999
			var bottom := -1
			var trail := []
			var t := 0.0
			for i in int(secs / DT):
				if w.get("_bot") == null:
					break
				w.test_pad = w._bot.pad(DT)
				w._read_pad()
				w.tick(DT)
				var row := floori(w.player.position.y / 32.0) - 1
				top = mini(top, row)
				bottom = maxi(bottom, row)
				if i % 1200 == 0:
					trail.append("%d,%d" % [floori(w.player.position.x / 32.0), row])
					await process_frame
				t = (i + 1) * DT
				if w.state == "clear":
					break
			print("[bot] %-7s %s %s in %5.1f s; rows %d..%d (start row %d, goal %s); snuffs %d; plans %d; state %s; every 10 s: %s" % [cls, id,
					"BELL" if w.state == "clear" else "----", t, top, bottom, lv.start.y, str(w._bot.goal.get("what", "?")) if w.get("_bot") != null else "-",
					int(w.snuffs), int(w._bot.plans) if w.get("_bot") != null else -1, str(w._bot.state) if w.get("_bot") != null else "-", " ".join(trail)])
			w.queue_free()
			await process_frame
	quit()
