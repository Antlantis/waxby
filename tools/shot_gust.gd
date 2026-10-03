# Screenshots of a gust zone at its tell and at full push, for judging the look.
#   godot --path game --resolution 1266x585 --script res://../tools/shot_gust.gd -- <level> <out_dir> <column>
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level_id: String = args[0] if args.size() > 0 else "lab-1"
	var out: String = args[1] if args.size() > 1 else "/tmp"
	var x := int(args[2]) if args.size() > 2 else 240
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	var lv = LevelData.load_file("res://levels/%s.txt" % level_id)
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
	var glass = null
	for m in w.features.modules if w.features.get("modules") != null else []:
		if m.get("zones") != null:
			glass = m
	if glass == null:
		print("no gust module")
		quit()
		return
	var z: Dictionary = {}
	for zz in glass.zones:
		if x >= int(zz["x0"]) and x <= int(zz["x1"]):
			z = zz
	var took := {}
	for i in 1200:
		await physics_frame
		var ph: Dictionary = glass.gust_phase(z)
		var key := ""
		if ph["state"] == "tell" and float(ph["k"]) > 0.6:
			key = "tell"
		elif ph["state"] == "gust" and float(ph["k"]) > 0.95:
			key = "gust"
		if key != "" and not took.has(key):
			await process_frame
			root.get_texture().get_image().save_png("%s/%s_%s_%d.png" % [out, level_id, key, x])
			print("saved ", key)
			took[key] = true
		if took.size() == 2:
			break
	quit()
