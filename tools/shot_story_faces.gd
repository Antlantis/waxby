extends SceneTree
# The hero's dialogue-box portrait for every calling and mood, cut out of the
# real cutscene and laid out on one sheet (rows: callings; columns: normal,
# happy, fierce, hurt), plus every story speaker's portrait on a second sheet.
# Checks by eye that each candle flame sits on its wick inside the disc.
#   godot --path game --resolution 1266x585 --script res://../tools/shot_story_faces.gd -- <out_dir>

const DT := 1.0 / 60.0
const CELL := 200          # px per cell (cut at 1.5x: the 46-px portrait, its rings and its flame)


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	# The game's own clear colour (main.gd), so a hole in a picture looks as it does in play.
	RenderingServer.set_default_clear_color(Color("0e0a14"))
	await process_frame
	var C = load("res://scripts/cutscene.gd")
	var Story = load("res://scripts/story.gd")
	var game = root.get_node("Game")
	game.save_path = "user://shot_faces_save.json"
	var moods := ["normal", "happy", "fierce", "hurt"]
	var callings := ["knight", "witch", "runner", "founder", "sexton"]
	var sheet := Image.create(CELL * moods.size(), CELL * callings.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.04, 0.07))
	var others := [["taper", "warm"], ["taper", "worried"], ["taper", "stern"], ["taper", "sad"], ["taper", "proud"],
		["waxley", "grin"], ["waxley", "shifty"], ["waxley", "shock"], ["tollgrave", "hushed"], ["tollgrave", "kind"],
		["snuffer", "cold"], ["snuffer", "wrath"], ["hollin", "lost"], ["hollin", "relit"]]
	var sheet2 := Image.create(CELL * 5, CELL * 3, false, Image.FORMAT_RGBA8)
	sheet2.fill(Color(0.05, 0.04, 0.07))
	for ci in callings.size():
		var cls: String = callings[ci]
		game.reset()
		game.new_hero(cls)
		var cs = C.new()
		cs.setup("boss_1_before", func(): pass, false, null)
		cs.manual = true
		root.add_child(cs)
		await process_frame
		for i in 3000:
			cs.advance(DT)
			if cs.waiting == "line" and cs._line["done"]:
				if cs._line["who"] == "wick":
					break
				if cs._line["t"] > 0.3:
					cs.tap()
		for mi in moods.size():
			cs._line["mood"] = moods[mi]
			cs._preload_portrait("wick", moods[mi])
			for k in 20:
				cs.advance(DT)
			await _cut(sheet, cs, true, Vector2i(mi * CELL, ci * CELL))
		if ci == 0:
			# Everyone else, in the same box (on the right).
			for oi in others.size():
				var who: String = others[oi][0]
				cs._line["who"] = who
				cs._line["mood"] = others[oi][1]
				cs._line["sp"] = Story.speaker(who, cls)
				cs._preload_portrait(who, others[oi][1])
				for k in 20:
					cs.advance(DT)
				await _cut(sheet2, cs, false, Vector2i((oi % 5) * CELL, (oi / 5) * CELL))
		cs.queue_free()
		await process_frame
	sheet.save_png(out + "/faces_hero.png")
	sheet2.save_png(out + "/faces_cast.png")
	print("saved ", out + "/faces_hero.png ", out + "/faces_cast.png")
	game.reset()
	quit()


func _cut(sheet: Image, cs, left: bool, at: Vector2i) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var vs: Vector2 = cs._vs()
	var k: float = float(img.get_width()) / vs.x
	var safe: Rect2 = cs._safe()
	var r := Rect2(safe.position.x + 12.0, safe.end.y - 6.0 - 96.0, safe.size.x - 24.0, 96.0)
	var pc := Vector2(r.position.x + 58.0, r.position.y + 4.0) if left else Vector2(r.end.x - 58.0, r.position.y + 4.0)
	var half := CELL / 2
	var src := Rect2i(Vector2i(pc * k) - Vector2i(half, half), Vector2i(CELL, CELL))
	sheet.blit_rect(img, src, at)
