# Rasterizes game/icon.svg to the iOS app icon PNG: 1024 x 1024, opaque (Apple
# rejects icons with alpha). Output defaults to game/icons/.
# godot --headless --path game --script res://../tools/art/render_icon.gd [-- <out_dir>]
extends SceneTree

const SIZES := [1024]   # Godot scales the rest at export


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "res://icons"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	for s in SIZES:
		var img := Image.new()
		var err := img.load_svg_from_string(svg, s / 1024.0)
		if err != OK:
			push_error("could not rasterize icon.svg")
			quit(1)
			return
		img.convert(Image.FORMAT_RGB8)
		img.save_png("%s/icon_%d.png" % [out_dir, s])
	print("wrote ", SIZES.size(), " icon(s) to ", out_dir)
	quit()
