extends SceneTree
## The tall-level camera (scripts/tall_cam.gd) on the shape labs, shot as
## shot_floor.gd shoots a strip's, on the phone's safe area (a 1266x585
## window is the 844x390 view): a long fall down lab-shape-tower's shaft
## (its lookout ledge to the ground), riding its lift up and down, a look
## down from its catch floor, its top at the bell; the fall and the lift
## again with the strip camera ("_old": world.tall_cam off) to compare.
## Prints where his feet sit on the glass, how many rows show under him, the
## Special's top and whether the bell is behind the HUD's top band; saves
## each frame and one contact sheet (<tag>_sheet.png, half size).
##   godot --path game --resolution 1266x585 --script res://../tools/shot_tall.gd -- <out_dir> [tag]

var UI
var game: Node
var _out := "/tmp"
var _tag := "tall"
var _lines: Array = []
var _frames: Array = []          # [name, Image] for the sheet


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	_tag = args[1] if args.size() > 1 else "tall"
	DirAccess.make_dir_recursive_absolute(_out)
	UI = load("res://scripts/ui.gd")
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shot_tall_save.json"
	game.settings_path = "user://shot_tall_settings.json"
	game.reset()
	UI.safe_override = UI.phone_safe(root.get_visible_rect().size)
	for old in [false, true]:
		await _fall(old)
		await _lift(old)
	await _look_down()
	await _top()
	_sheet()
	var f := FileAccess.open("%s/%s_tall.txt" % [_out, _tag], FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	quit()


func _say(s: String) -> void:
	print(s)
	_lines.append(s)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [_out, _tag, name])
	_frames.append([name, img])


func _clear() -> void:
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx":
			c.queue_free()
	for i in 2:
		await process_frame


func _world(old: bool) -> Node:
	await _clear()
	game.reset()
	game.new_hero("knight")
	var lv = load("res://scripts/level_data.gd").load_file("res://levels/lab-shape-tower.txt")
	var w = load("res://scripts/world.gd").new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	if old:
		w.tall_cam = null
	w.test_pad = {}
	if w.hud != null:
		w.hud._title = {}
	return w


func _put(w: Node, x: int, row: int) -> void:
	w.player.reset_at(Vector2(x * 32 + 16, (row + 1) * 32))
	w.player.velocity = Vector2.ZERO
	w.cam = w.cam_on(w.player.position)
	for i in 60:
		await physics_frame


func _numbers(w: Node, what: String) -> void:
	var v: Vector2 = w._view_size()
	var feet: float = w.player.position.y - w.cam.y + v.y * 0.5
	var L: Dictionary = w.touch.layout()
	var top := float(L["special"].y) - float(L["r_special"])
	_say("%s: feet at view y %.1f (%.1f px over the Special's top %.1f), %.1f rows show under him" % [what, feet, top - feet, top, (v.y - feet) / 32.0])


func _fall(old: bool) -> void:
	## Off the lookout ledge at the top of the shaft (column 27) to the ground.
	var tag := "_old" if old else ""
	var w = await _world(old)
	await _put(w, 25, 3)
	w.test_pad = {"right": true}
	var lowest := 0.0
	var shot := false
	for i in 200:
		await physics_frame
		if not w.player.on_floor:
			w.test_pad = {}
		var v: Vector2 = w._view_size()
		var feet: float = w.player.position.y - w.cam.y + v.y * 0.5
		if w.player.velocity.y > 300.0:
			lowest = maxf(lowest, feet)
		if not shot and w.player.position.y > 20 * 32:
			shot = true
			w.set_physics_process(false)
			_numbers(w, "falling down the shaft%s, 20 rows down" % tag)
			await _shot("fall%s" % tag)
			w.set_physics_process(true)
	_say("   the fall%s: his feet at most %.1f down the glass" % [tag, lowest])


func _lift(old: bool) -> void:
	## On the lift at its lowest, a whole sweep up and down.
	var tag := "_old" if old else ""
	var w = await _world(old)
	var lift = null
	for m in w.movers:
		if str(m.kind) == "y":
			lift = m
	for i in 1000:
		if float(lift.delta.y) < 0.0 and float(lift.pos.y) > float(lift.start.y) + 80.0:
			break
		await physics_frame
	w.player.reset_at(Vector2(float(lift.pos.x) + 48.0, float(lift.pos.y)))
	w.cam = w.cam_on(w.player.position)
	var lowest := 0.0
	var shot := false
	for i in int(float(lift.period) * 1.2 * Engine.physics_ticks_per_second):
		await physics_frame
		var v: Vector2 = w._view_size()
		lowest = maxf(lowest, w.player.position.y - w.cam.y + v.y * 0.5)
		if not shot and float(lift.delta.y) > 1.0:
			shot = true
			w.set_physics_process(false)
			_numbers(w, "riding the lift down%s" % tag)
			await _shot("lift%s" % tag)
			w.set_physics_process(true)
	_say("   the lift%s, a whole sweep: his feet at most %.1f down the glass" % [tag, lowest])


func _look_down() -> void:
	var w = await _world(false)
	await _put(w, 18, 21)
	_numbers(w, "standing on the catch floor's edge")
	await _shot("stand")
	w.test_pad = {"down": true}
	for i in 90:
		await physics_frame
	w.set_physics_process(false)
	_numbers(w, "down held (%s)" % w.tall_cam.looking)
	await _shot("down")


func _top() -> void:
	var w = await _world(false)
	await _put(w, 6, 5)
	w.set_physics_process(false)
	_numbers(w, "at the top, by the bell")
	_say("   the HUD rule (goal_hits): %s" % ("clear" if w.tall_cam.goal_hits().is_empty() else str(w.tall_cam.goal_hits())))
	await _shot("top")


func _sheet() -> void:
	## Every frame at half size, two to a row.
	if _frames.is_empty():
		return
	var fw: int = (_frames[0][1] as Image).get_width() / 2
	var fh: int = (_frames[0][1] as Image).get_height() / 2
	var rows := ceili(_frames.size() / 2.0)
	var sheet := Image.create(fw * 2, fh * rows, false, Image.FORMAT_RGBA8)
	for i in _frames.size():
		var img: Image = (_frames[i][1] as Image).duplicate()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(fw, fh, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, fw, fh), Vector2i((i % 2) * fw, (i / 2) * fh))
	sheet.save_png("%s/%s_sheet.png" % [_out, _tag])
