# The Tales screen's card pictures, baked ahead: each story panel's layers
# laid far to near into one small PNG at the phone's card size, so the screen
# only loads a small image where it used to read every layer back from the
# GPU and shrink it on the main thread (15-66 ms a layer on an M3 Pro).
#   godot --path game --resolution 1266x585 --script res://../tools/art/bake_tale_thumbs.gd
# (a window: the layers' textures must really be there to read back). Writes
# game/art/story/thumbs/<panel>.png and thumbs.json ({panel: {"src": the md5
# of its layer files, "size": [w, h]}}); run `--import` after it. Run it again
# whenever a story set changes: tests/test_story.gd fails on a picture older
# than its layers.
extends SceneTree

const OUT := "res://art/story/thumbs"
const INDEX := "res://art/story/thumbs/thumbs.json"


static func layers_md5(layers: Array) -> String:
	## What a baked picture was made from: its layers' files, in order
	## (tests/test_story.gd works it out the same way).
	var parts := PackedStringArray()
	for e in layers:
		var p := str(e[1])
		parts.append(p + ":" + (FileAccess.get_md5(p) if p != "" and FileAccess.file_exists(p) else ""))
	return "|".join(parts).md5_text()


func _initialize() -> void:
	await process_frame
	var UI = load("res://scripts/ui.gd")
	var Tales = load("res://scripts/tales_screen.gd")
	UI.safe_override = UI.phone_safe(Vector2(844, 390))
	root.content_scale_size = Vector2i(844, 390)
	var ts: Control = Tales.new()
	root.add_child(ts)
	await process_frame
	var frame := Vector2(Tales.THUMB_W, (ts.card_rects(1)[0] as Rect2).size.y - 16.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var index := {}
	var panels: Dictionary = Tales.manifest().get("panels", {})
	for pid in panels:
		var layers: Array = ts._layers_of(str(pid))
		if layers.is_empty() or str(layers[0][1]) == "":
			print("  %s: no art yet (the stand-in is drawn live)" % pid)
			continue
		var job: Dictionary = Tales.thumb_job(str(pid), layers, ts._psize(str(pid)), frame, Tales.THUMB_DENSITY)
		while not Tales.thumb_step(job):
			pass
		if not bool(job["any"]):
			print("  %s: nothing drawn" % pid)
			continue
		var img: Image = job["img"]
		var path := "%s/%s.png" % [OUT, pid]
		img.save_png(ProjectSettings.globalize_path(path))
		index[str(pid)] = {"src": layers_md5(layers), "size": [img.get_width(), img.get_height()]}
		print("  %s: %dx%d" % [pid, img.get_width(), img.get_height()])
	var f := FileAccess.open(ProjectSettings.globalize_path(INDEX), FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t", true))
	f.close()
	print("baked %d tale pictures into %s (frame %s at %.0f px a unit)" % [index.size(), OUT, frame, Tales.THUMB_DENSITY])
	UI.safe_override = Rect2()
	quit()
