extends SceneTree
## Screenshots of the tall render labs (game/levels/tall, tools/levels/
## lab_tall.py: today's levels stacked to 24 and 36 rows) in every theme the
## 18 regular levels use, and the trial hall's: the camera at the level's
## top, its middle and its bottom, the dark and the HUD off (the backdrop and
## the tiles as they are drawn), each frame saved at half size. Needs a
## window (not --headless).
##   godot --path game --resolution 1266x585 --script res://../tools/shot_tall.gd -- frames <out_dir> [lab@theme,...]
##   godot --path game --resolution 1266x585 --script res://../tools/shot_tall.gd -- sheet <before_dir> <after_dir> <out_dir>
## frames: <out_dir>/<lab>@<theme>_<top|upper|lower|bottom>.png, and the
## camera's place in each to shot_tall.txt. sheet: one picture a lab and
## theme from two frames runs (a tree before a change and after it): the four
## places down, before | after across, at a third of the window's size.
## A lab is drawn in another theme of its world (its painter is the world's),
## as test_world_art.gd's "<level>@<theme>" does.

const PAIRS := {
	"lab-tall-1-2": ["nave", "crypt", "choir"],
	"lab-tall-2-1": ["waxfall", "chandlery", "garden"],
	"lab-tall-3-1": ["orchard", "sporewood"],
	"lab-tall-3-2": ["rootvault"],
	"lab-tall-4-1": ["clockface", "gearworks", "icebells"],
	"lab-tall-5-3": ["choirglass", "rosewind", "voidnave", "trialhall"],
	"lab-tall-6-1": ["stillshore", "drownbell", "hushquiet"],
}
const ROWS := [24, 36]
const PLACES := ["top", "upper", "lower", "bottom"]
const AT_X := 0.4                # the camera's column, a fraction of the level's width

var _lines: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "frames"
	await process_frame
	if mode == "sheet" and args.size() >= 4:
		_sheets(args[1], args[2], args[3])
		quit()
		return
	var out: String = args[1] if args.size() > 1 else "/tmp/shot_tall"
	DirAccess.make_dir_recursive_absolute(out)
	var want: Array = []
	if args.size() > 2:
		want = Array(str(args[2]).split(","))
	var game = root.get_node_or_null("Game")
	if game != null:
		game.settings_path = "user://shot_tall_settings.json"
		game.save_path = "user://shot_tall_save.json"
		game.reset()
	for lab in PAIRS:
		for rows in ROWS:
			for th in PAIRS[lab]:
				var id := "%s-%d@%s" % [lab, rows, th]
				if want.is_empty() or want.has(id):
					await _frames(out, "%s-%d" % [lab, rows], th)
	var f := FileAccess.open(out.path_join("shot_tall.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	quit()


func _frames(out: String, lab: String, theme: String) -> void:
	var LevelData = load("res://scripts/level_data.gd")
	var lv = LevelData.load_file("res://levels/tall/%s.txt" % lab)
	if not lv.errors.is_empty():
		print("[shot_tall] %s: %s" % [lab, lv.errors])
		return
	lv.theme = theme
	var w: Node = load("res://scripts/world.gd").new()
	w.setup(lv)
	root.add_child(w)
	for i in 8:
		await process_frame
	w.paused = true
	w.hud.visible = false
	if w.get("touch") != null:
		w.touch.visible = false
	if w.get("_darkness") != null:
		w._darkness.visible = false
	var view: Vector2 = w._view_size()
	var x := _open_x(lv, int(view.x / 32.0))
	var lo: Vector2 = w._clamp_cam(Vector2(x * 32.0, -100000.0))
	var hi: Vector2 = w._clamp_cam(Vector2(x * 32.0, 100000.0))
	for k in PLACES.size():
		var c := lo.lerp(hi, float(k) / (PLACES.size() - 1))
		w.cam = c
		w.camera.position = c.round()
		for i in 4:
			await process_frame
		var im := root.get_texture().get_image()
		im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		var path := out.path_join("%s@%s_%s.png" % [lab, theme, PLACES[k]])
		im.save_png(path)
		var line := "%s@%s %s: view y %.0f-%.0f of %d (+%d under), %d backdrop slices" % [lab, theme, PLACES[k], c.y - view.y * 0.5,
				c.y + view.y * 0.5, lv.height * 32, 160, w.backdrop.slice_count()]
		print(line)
		_lines.append(line)
	w.queue_free()
	for i in 2:
		await process_frame


func _open_x(lv: RefCounted, cols: int) -> int:
	## The camera's column: the view-wide stretch from AT_X on with the most
	## air down the whole height (the most backdrop to see).
	var air := []
	for x in lv.width:
		var n := 0
		for y in lv.height:
			n += 1 if lv.tile(x, y) == 0 else 0
		air.append(n)
	var best := -1
	var at := int(lv.width * AT_X)
	for x in range(int(lv.width * AT_X), lv.width - cols):
		var s := 0
		for k in cols:
			s += int(air[x + k])
		if s > best:
			best = s
			at = x + cols / 2
	return at


func _sheets(before: String, after: String, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var names := {}
	for f in DirAccess.get_files_at(after):
		if f.ends_with("_top.png"):
			names[f.trim_suffix("_top.png")] = true
	for n in names:
		var cells := []
		for p in PLACES:
			for d in [before, after]:
				var path: String = d.path_join("%s_%s.png" % [n, p])
				cells.append(Image.load_from_file(path) if FileAccess.file_exists(path) else null)
		var cw := 422
		var chh := 195
		for im in cells:
			if im != null:
				chh = int(round(float(im.get_height()) * cw / im.get_width()))
				break
		var sheet := Image.create_empty(cw * 2 + 6, chh * PLACES.size() + 4 * (PLACES.size() - 1), false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.85, 0.85, 0.85))
		for k in cells.size():
			var im: Image = cells[k]
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			im.resize(cw, chh, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(im, Rect2i(0, 0, cw, chh), Vector2i((k % 2) * (cw + 6), (k / 2) * (chh + 4)))
		var path := out.path_join("sheet_%s.png" % n)
		sheet.save_png(path)
		print("saved ", path)
