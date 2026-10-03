# The real game under --autoplay (main.gd's own route and bot, its [perf]
# lines), with a screenshot the first time Wick reaches each given column.
#   godot --path game --resolution 1266x585 --script res://../tools/autoplay_shots.gd -- <route> <out_dir> <col,col,...> [seconds]
#   e.g. -- lab-1 <out_dir> 35,48,67,106,128,155,186,206,237,265,286,311,347,376,397 220   (lab-1's stations)
# Ends when the level's results are up, or after [seconds] (default 240).
extends SceneTree

var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var route: String = args[0] if args.size() > 0 else "lab-1"
	var out: String = args[1] if args.size() > 1 else "/tmp"
	var cols: Array = []
	if args.size() > 2:
		for s in args[2].split(","):
			cols.append(int(s))
	var secs := float(args[3]) if args.size() > 3 else 240.0
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	main.set("_autoplay", route)   # main._ready reads --autoplay itself; this is the same
	root.add_child(main)
	var t0 := Time.get_ticks_msec()
	var taken := {}
	var cleared := false
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await process_frame
		var w = main.current
		if w == null or w.get("player") == null:
			if taken.size() > 0 and w != null:
				print("[shots] left the level for %s" % (w.get_script() as Script).resource_path.get_file())
				cleared = true
				await process_frame
				root.get_texture().get_image().save_png("%s/%s_results.png" % [out, route])
				break
			continue
		var x: float = float(w.player.position.x) / 32.0
		for c in cols:
			if not taken.has(c) and x >= float(c) - 1.0:
				taken[c] = true
				for i in 4:
					await process_frame
				root.get_texture().get_image().save_png("%s/%s_at_%03d.png" % [out, route, c])
				print("[shots] %s x %d at %.1f s (snuffs %d)" % [route, c, (Time.get_ticks_msec() - t0) / 1000.0, int(w.get("snuffs"))])
		if str(w.get("state")) == "clear" and not taken.has("clear"):
			taken["clear"] = true
			print("[shots] %s: the bell at %.1f s, snuffs %d" % [route, (Time.get_ticks_msec() - t0) / 1000.0, int(w.get("snuffs"))])
	print("[shots] done: %d shots%s" % [taken.size(), ", level left" if cleared else ""])
	quit()
