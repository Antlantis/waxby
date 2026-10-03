# Screenshots of a level being played, for checking the look by eye.
#   godot --path game --resolution 1266x585 --script res://../tools/shot.gd -- <level> <out_dir> [x1,x2,...]
# Puts Wick at each tile column in turn, lets him run right for a moment and
# saves <out_dir>/<level>_<x>.png. Also shots of the title and the map when
# <level> is "screens" (v3's with stand-ins for "screens3": tools/shot_screens_v3.gd),
# the story's scenes for "story" (tools/shot_story.gd;
# the third argument is its scene list, default all), and "identity": a
# fixed set of W1-W2 shots taken the
# same way every time (with --fixed-fps 120 two runs are identical to the
# pixel), for comparing a build against a snapshot (workstreams.md 4.2:
# W1-W2 screenshots against v3-base, <= 1/255):
#   godot --path game --resolution 1266x585 --fixed-fps 120 --script res://../tools/shot.gd -- identity <out_dir>
extends SceneTree

var _out := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level_id: String = args[0] if args.size() > 0 else "1-1"
	_out = args[1] if args.size() > 1 else "/tmp"
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	if level_id == "screens":
		await _screens()
		quit()
		return
	if level_id == "actions":
		await _actions()
		quit()
		return
	if level_id == "identity":
		await _identity()
		quit()
		return
	if level_id == "screens3":
		# SC's v3 screens with stand-in W3-W6 and secret headers:
		# tools/shot_screens_v3.gd, as its own process; the third argument
		# picks a set (all | map | hud | sheet | results | pause | title).
		var what: String = args[2] if args.size() > 2 else "all"
		var said3 := []
		var code3 := OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--resolution", "1266x585",
				"--script", "res://../tools/shot_screens_v3.gd", "--", _out, what], said3, true)
		print("".join(said3))
		quit(code3)
		return
	if level_id == "story":
		# The story's scenes: tools/shot_story.gd, run as its own process
		# (contract §0's `shot.gd -- story <out_dir> [scenes|all]`).
		var scenes: String = args[2] if args.size() > 2 else "all"
		var said := []
		var code := OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--resolution", "1266x585",
				"--script", "res://../tools/shot_story.gd", "--", _out, scenes], said, true)
		print("".join(said))
		quit(code)
		return
	var xs: Array = []
	if args.size() > 2:
		for s in args[2].split(","):
			xs.append(int(s))
	else:
		xs = [3]
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	for x in xs:
		var lv = LevelData.load_file("res://levels/%s.txt" % level_id)
		var w = World.new()
		w.setup(lv)
		root.add_child(w)
		await process_frame
		w.test_pad = {}
		var start: Vector2 = w.player.position
		w.player.reset_at(Vector2(x * 32 + 16, start.y))
		if x != 3:
			# Stand him on the lowest floor in that column.
			for y in range(lv.height - 1, 0, -1):
				if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
					w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
					break
		w.cam = w._clamp_cam(w.player.position)
		for i in 50:
			w.test_pad = {"right": i > 10 and i < 40}
			await physics_frame
		for i in 12:
			await process_frame
		var img := root.get_texture().get_image()
		var path := "%s/%s_%03d.png" % [_out, level_id, x]
		img.save_png(path)
		print("saved ", path)
		w.queue_free()
		await process_frame
	quit()


const IDENTITY := {"1-1": [3, 40, 90, 150, 200, 250], "1-2": [3, 50, 110, 170], "1-3": [3, 45, 100, 150, 190],
		"1-4": [3, 40, 70], "2-1": [3, 60, 120, 180, 240], "2-2": [3, 50, 110, 170, 230, 290],
		"2-3": [3, 70, 140, 210, 290], "2-4": [3, 40, 80, 100]}
const SEEN := ["beat_1_1", "beat_1_2", "beat_1_3", "beat_1_4", "beat_2_1", "beat_2_2", "beat_2_3", "beat_2_4",
		"boss_1_before", "boss_2_before", "intro", "oath"]


func _identity() -> void:
	## The same frames every run: the global RNG seeded, a fresh save with the
	## levels' scenes seen, 90 physics ticks of play (run with --fixed-fps 120).
	var game = root.get_node("Game")
	game.save_path = "user://shot_identity.json"
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	for id in IDENTITY:
		if not FileAccess.file_exists("res://levels/%s.txt" % id):
			continue
		for x in IDENTITY[id]:
			seed(7)
			game.reset()
			for k in SEEN:
				game.mark_seen(k)
			var lv = LevelData.load_file("res://levels/%s.txt" % id)
			var w = World.new()
			w.setup(lv)
			root.add_child(w)
			await process_frame
			w.test_pad = {}
			for y in range(lv.height - 1, 0, -1):
				if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
					w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
					break
			w.cam = w._clamp_cam(w.player.position)
			for i in 90:
				w.test_pad = {"right": i > 10 and i < 40}
				await physics_frame
			for i in 6:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s_%03d.png" % [_out, id, x])
			w.queue_free()
			await process_frame
	print("saved the identity set in ", _out)


func _screens() -> void:
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/title.png")
	main.show_map()
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/map.png")
	main._on_finished({"level": "1-1", "cleared": true, "embers": 41, "embers_total": 58, "sigils": [true, false, true], "time": 131.4, "relics": ["rook_feather", "phoenix_wick"]})
	for i in 150:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/results.png")
	var game = root.get_node("Game")
	var kept: Array = game.data["relics"].duplicate()
	game.data["relics"] = ["tallow_heart", "rook_feather", "bellows", "moth_charm", "saints_knuckle", "phoenix_wick"]
	main.play_level(0)
	for i in 30:
		await process_frame
	main.current.open_pause()
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/pause.png")
	main.show_map()
	main.current._shelf = true
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/shelf.png")
	game.data["relics"] = ["tallow_heart"]
	game.data["embers"] = 150
	main.show_chandler()
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/shop.png")
	game.data["relics"] = kept
	print("saved title, map, results, pause, shelf")


func _actions() -> void:
	## Wick running, mid-swing, at a jump's top and landing on a skeleton.
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var w = World.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	w.hud.visible = false
	var shots := [
		["run", {"right": true}, 40],
		["swing", {"right": true, "attack": true}, 5],
		["jump", {"right": true, "jump": true}, 40],
	]
	w.player.reset_at(Vector2(20 * 32, 13 * 32))
	for i in 30:
		w.test_pad = {}
		await physics_frame
	for sdef in shots:
		for i in sdef[2]:
			w.test_pad = sdef[1]
			await physics_frame
		await process_frame
		root.get_texture().get_image().save_png("%s/act_%s.png" % [_out, sdef[0]])
		for i in 60:
			w.test_pad = {}
			await physics_frame
	# The stomp: drop onto the first skeleton.
	for e in w.enemies:
		if e.kind == "skeleton":
			e.active = true
			w.player.reset_at(e.position + Vector2(0, -70))
			w.player.velocity = Vector2(0, 100)
			for i in 200:
				w.test_pad = {}
				await physics_frame
				if not e.alive:
					break
			for i in 3:
				await physics_frame
			await process_frame
			root.get_texture().get_image().save_png("%s/act_stomp.png" % _out)
			break
	print("saved actions")
