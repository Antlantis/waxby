# Renders a few SVGs side by side, big, on the dark background, for a close look.
# godot --headless --path game --script res://../tools/art/peek.gd -- /abs/out.png <scale> art/a.svg art/b.svg ...
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var scale := float(args[1])
	var imgs := []
	var w := 8
	var h := 0
	for i in range(2, args.size()):
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://" + args[i]), scale)
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
		w += img.get_width() + 8
		h = maxi(h, img.get_height())
	var sheet := Image.create_empty(w, h + 16, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1d1526"))
	var x := 8
	for img in imgs:
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 8))
		x += img.get_width() + 8
	sheet.save_png(out)
	quit()
