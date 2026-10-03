# Compares two folders of PNGs pixel for pixel (the render identity gate).
#   godot --headless --path game --script res://../tools/perf/img_diff.gd -- <dir_a> <dir_b> [tol] [diff_dir]
# For each PNG in dir_a with a twin in dir_b: the largest channel difference
# (in 1/255 steps) and how many pixels differ by more than tol (default 1).
# A pair over tol gets an amplified difference image in diff_dir. Exits 1 if
# any pair is over tol or missing, 0 otherwise.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var a: String = args[0] if args.size() > 0 else ""
	var b: String = args[1] if args.size() > 1 else ""
	var tol: int = int(args[2]) if args.size() > 2 else 1
	var out: String = args[3] if args.size() > 3 else ""
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	var files := DirAccess.get_files_at(a)
	var bad := 0
	var n := 0
	var worst_all := 0
	for f in files:
		if not f.ends_with(".png"):
			continue
		n += 1
		var ia := Image.load_from_file(a.path_join(f))
		if not FileAccess.file_exists(b.path_join(f)):
			print("[diff] %-28s MISSING in %s" % [f, b])
			bad += 1
			continue
		var ib := Image.load_from_file(b.path_join(f))
		if ia.get_size() != ib.get_size():
			print("[diff] %-28s SIZE %s vs %s" % [f, ia.get_size(), ib.get_size()])
			bad += 1
			continue
		ia.convert(Image.FORMAT_RGBA8)
		ib.convert(Image.FORMAT_RGBA8)
		var da := ia.get_data()
		var db := ib.get_data()
		var worst := 0
		var over := 0
		var diff: Image = null
		var w := ia.get_width()
		for i in range(0, da.size(), 4):
			var d := maxi(maxi(absi(da[i] - db[i]), absi(da[i + 1] - db[i + 1])), absi(da[i + 2] - db[i + 2]))
			if d > worst:
				worst = d
			if d > tol:
				over += 1
				if out != "":
					if diff == null:
						diff = Image.create(w, ia.get_height(), false, Image.FORMAT_RGBA8)
						diff.fill(Color(0, 0, 0, 1))
					var px := (i / 4) % w
					var py := (i / 4) / w
					diff.set_pixel(px, py, Color(minf(d * 16.0 / 255.0, 1.0), 0.2, 0.2, 1.0))
		worst_all = maxi(worst_all, worst)
		var ok := over == 0
		if not ok:
			bad += 1
			if diff != null:
				diff.save_png(out.path_join(f.get_basename() + "_diff.png"))
		print("[diff] %-28s max %3d/255  over %d: %6d px  %s" % [f, worst, tol, over, "ok" if ok else "DIFFERENT"])
	print("[diff] %d images, %d over tolerance %d/255, worst %d/255" % [n, bad, tol, worst_all])
	quit(1 if bad > 0 or n == 0 else 0)
