extends SceneTree
## PROTOTYPE (proto-tall): a contact sheet of PNGs (no PIL here): each image
## scaled by <scale>, laid out <cols> to a row, in the order given.
##   godot --headless --script res://../tools/proto_sheet.gd -- <out.png> <scale> <cols> a.png b.png ...


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var k := float(args[1])
	var cols := int(args[2])
	var imgs: Array[Image] = []
	for i in range(3, args.size()):
		var im := Image.load_from_file(args[i])
		if im == null:
			continue
		im.resize(int(im.get_width() * k), int(im.get_height() * k), Image.INTERPOLATE_BILINEAR)
		imgs.append(im)
	if imgs.is_empty():
		quit(1)
		return
	var cw := imgs[0].get_width()
	var ch := imgs[0].get_height()
	var gap := 4
	var rows := ceili(float(imgs.size()) / cols)
	var sheet := Image.create(cols * (cw + gap) - gap, rows * (ch + gap) - gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 1, 1, 1))
	for i in imgs.size():
		var im := imgs[i]
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i((i % cols) * (cw + gap), (i / cols) * (ch + gap)))
	sheet.save_png(out)
	print("saved ", out)
	quit()
