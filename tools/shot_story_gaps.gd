extends SceneTree
# Holes in the picture: plays every scene with the clear colour set to magenta
# and, every few frames, looks for it between the letterbox bars. A layer that
# stops short of the next one (the belfry's far wall and its floor, when the
# camera looks up at a zoom) leaves a strip of it. Prints each shot's worst
# frame and saves it; "0 holes" for every shot is the pass.
#   godot --path game --resolution 844x390 --script res://../tools/shot_story_gaps.gd -- <out_dir> [scene,...|all] [cls]

const DT := 1.0 / 60.0
const EVERY := 6            # frames between looks
const HOLE := Color(1, 0, 1)
# "all" is every scene story.gd has, in its order (Story.scenes()).
var out := "/tmp"
var bad := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp"
	var list: String = args[1] if args.size() > 1 else "all"
	var cls: String = args[2] if args.size() > 2 else "knight"
	DirAccess.make_dir_recursive_absolute(out)
	RenderingServer.set_default_clear_color(HOLE)
	await process_frame
	var game = root.get_node("Game")
	game.save_path = "user://shot_gaps_save.json"
	game.reset()
	game.new_hero(cls)
	var ids: Array = load("res://scripts/story.gd").scenes().keys() if list == "all" else Array(list.split(","))
	for id in ids:
		await _probe(str(id), cls)
	print("GAPS: %d shot(s) with holes" % bad)
	game.reset()
	quit()


func _holes(img: Image, top: int, bot: int) -> Array:
	## Magenta pixels between the bars, on a 3x1 grid: [count, rect].
	var k := 0
	var box := Rect2i()
	var w := img.get_width()
	for y in range(top, bot):
		for x in range(0, w, 3):
			var c := img.get_pixel(x, y)
			if c.r > 0.8 and c.b > 0.8 and c.g < 0.3:
				box = Rect2i(x, y, 1, 1) if k == 0 else box.expand(Vector2i(x, y))
				k += 1
	return [k, box]


func _probe(id: String, cls: String) -> void:
	var cs = load("res://scripts/cutscene.gd").new()
	cs.setup(id, func(): pass, false, null)
	cs.manual = true
	cs.auto = true
	cs.follow_next = false
	root.add_child(cs)
	await process_frame
	var worst := {}      # shot -> [holes, time, image]
	var clock := 0.0
	for i in 12000:
		if cs.finished:
			break
		if cs.waiting == "class":
			cs.pick(cls)
		cs.advance(DT)
		clock += DT
		if i % EVERY != 0 or cs._panel_id == "" or cs._fade > 0.2:
			continue
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var vs: Vector2 = cs._vs()
		var sy: float = float(img.get_height()) / vs.y
		var lb: float = cs.LETTERBOX * (1.0 - pow(1.0 - cs._lb, 3.0))
		var top := int(ceil((lb + 1.0) * sy))
		var bot := int(floor((vs.y - lb - cs._lift * minf(cs._lb * 2.0, 1.0) - 1.0) * sy))
		var hr := _holes(img, top, bot)
		var h: int = hr[0]
		var key := "%d_%s" % [cs._shot_i, cs._panel_id]
		if not worst.has(key) or h > int(worst[key][0]):
			worst[key] = [h, clock, img if h > 0 else null, [cs._cam.x, cs._cam.y, cs._cam.z], cs._lift, hr[1]]
	for key in worst:
		var wv: Array = worst[key]
		print("%s shot %s: %d holes (worst at %.1f s, cam [%.3f, %.3f, %.3f], lift %.0f, in %s)" % [id, key, wv[0], wv[1],
			wv[3][0], wv[3][1], wv[3][2], wv[4], str(wv[5]) if int(wv[0]) > 0 else "-"])
		if int(wv[0]) > 0:
			bad += 1
			(wv[2] as Image).save_png("%s/gap_%s_%s.png" % [out, id, key])
	cs.queue_free()
	for i in 3:
		await process_frame
