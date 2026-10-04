# PROTOTYPE (proto-tall): the reachability bot (scripts/reach.gd, reach_search.gd,
# as tests/test_core.gd _prove runs it) on the tall labs, lab-2 and lab-3.
#   godot --headless --path game --script res://../tools/proto_reach.gd -- [lab-2,lab-3]
extends SceneTree

const LevelData := preload("res://scripts/level_data.gd")
const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")

var fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = (args[0] if args.size() > 0 else "lab-2,lab-3").split(",")
	# drops=0: the bot as the tests run it (no drop-through); default on (see reach.gd DROPS)
	Reach.DROPS = not (args.size() > 1 and args[1] == "drops=0")
	print("drop-through: ", Reach.DROPS)
	for id in ids:
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		print("%s: %d x %d, world %d, errors %s" % [id, lv.width, lv.height, lv.world, lv.errors])
		var t0 := Time.get_ticks_msec()
		var timed := Reach.timed_cells(lv)
		var s = ReachSearch.new()
		s.setup(Reach.static_copy(lv), LevelData.cell_floor(lv.start), {"timed": timed})
		s.run()
		s.free_player()
		print("  %d states, %d sims, %d ms, capped %s" % [s.seen.size(), s.sims, Time.get_ticks_msec() - t0, s.capped])
		for g in s.goals:
			var ok: bool = s.found.has(g["what"])
			if not ok:
				fails += 1
			print("  %s %s" % ["ok  " if ok else "MISS", g["what"]])
		# Where the bot got to (the highest and lowest standing rows it found).
		var ys := {}
		for n in s.nodes:
			ys[int((n["pos"] as Vector2).y / 32.0)] = true
		var rows := ys.keys()
		rows.sort()
		print("  rows stood on: ", rows)
	quit(1 if fails > 0 else 0)
