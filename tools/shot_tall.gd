extends SceneTree
## PROTOTYPE (proto-tall): screenshots of the tall labs (lab-2 the Bone Tower,
## a climb; lab-3 the Clock Shaft, a descent) on the phone's view and safe
## area, with Waxby at the bottom, the middle and the top, climbing and
## sliding a vine, riding the lift and falling; then the same falls with the
## camera as it was (world.gd proto_look_down off: "_old" in the name), and a
## camera sweep from the bottom to the top with nobody moving, with the
## backdrop's storeys (backdrop.gd PROTO_STOREYS) and without ("_old").
## Prints where his feet sit on the glass and where the camera is.
##   godot --path game --resolution 1266x585 --script res://../tools/shot_tall.gd -- <out_dir> [lab-2|lab-3|all]

var UI
var Story
var Backdrop
var game: Node
var _out := "/tmp"
var _lines: Array = []
var _id := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	var which: String = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(_out)
	UI = load("res://scripts/ui.gd")
	Story = load("res://scripts/story.gd")
	Backdrop = load("res://scripts/backdrop.gd")
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shot_tall_save.json"
	game.settings_path = "user://shot_tall_settings.json"
	game.reset()
	UI.safe_override = UI.phone_safe(root.get_visible_rect().size)
	_say("view %s safe %s" % [root.get_visible_rect().size, UI.safe_override])
	if which in ["all", "lab-2"]:
		await _tower()
	if which in ["all", "lab-3"]:
		await _shaft()
	var f := FileAccess.open("%s/shot_tall.txt" % _out, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	quit()


func _say(s: String) -> void:
	print(s)
	_lines.append(s)


func _clear() -> void:
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx":
			c.queue_free()
	for i in 2:
		await process_frame


func _world(level_id: String, proto := true) -> Node:
	await _clear()
	_id = level_id
	Backdrop.PROTO_STOREYS = proto
	game.reset()
	for id in Story.scenes().keys():
		game.mark_seen(id)
	for k in Story.BARKS.keys():
		game.mark_seen("bark:" + k)
	game.new_hero("knight")
	game.add_xp(load("res://scripts/progression.gd").total_to(12) - int(game.hero()["xp"]))
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	var lv = LevelData.load_file("res://levels/%s.txt" % level_id)
	var w = World.new()
	w.setup(lv)
	w.proto_look_down = proto
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	for i in 30:
		await physics_frame
	w.hud._title = {}
	_say("%s built (proto camera + storeys: %s), %d backdrop slices" % [level_id, proto, w.backdrop.slice_count()])
	return w


func _put(w: Node, cell: Vector2i) -> void:
	## Feet on the floor under cell (cell is the standing row), the camera settled there.
	w.player.reset_at(Vector2(cell.x * 32 + 16, (cell.y + 1) * 32))
	w.cam = w.cam_on(w.player.position)
	w._cam_y_target = w.cam.y


func _hold(w: Node, pad: Dictionary, frames: int, safe := true) -> void:
	for i in frames:
		w.test_pad = pad
		if safe:
			w.player.invuln = maxf(w.player.invuln, 0.5)   # (the shots aren't about being hit)
			w.player.hp = w.player.max_hp
		await physics_frame


func _walk_off(w: Node, pad: Dictionary, most := 240) -> int:
	## Hold pad until he leaves the floor (walks off an edge); frames held.
	for i in most:
		await _hold(w, pad, 1)
		if not w.player.on_floor and not w.player.climbing:
			return i
	return most


func _shot(w: Node, name: String) -> void:
	await process_frame
	await process_frame
	var path := "%s/%s_%s.png" % [_out, _id, name]
	root.get_texture().get_image().save_png(path)
	var xf: Transform2D = w.get_viewport().get_canvas_transform()
	var feet: Vector2 = xf * w.player.global_position
	var view: Rect2 = w.view_rect()
	var L: Dictionary = w.touch.layout() if w.touch != null else {}
	var sp_top := float(L["special"].y - L["r_special"]) if not L.is_empty() else -1.0
	# How many tile rows under his feet are on the glass (and over the buttons' tops).
	var below := (390.0 - feet.y) / 32.0
	var below_clear := (sp_top - feet.y) / 32.0
	_say("%s %s: cell (%d,%d) feet at view y %.0f (feet_line %.0f, Special top %.0f): %.1f rows below him on the glass, %.1f over the buttons; view y %.0f-%.0f of %d; climbing %s, floor %s, vy %.0f" % [
			_id, name, floori(w.player.position.x / 32.0), floori(w.player.position.y / 32.0) - 1, feet.y, w.feet_line(), sp_top,
			below, below_clear, view.position.y, view.end.y, w.level.height * 32, w.player.climbing, w.player.on_floor, w.player.velocity.y])


func _lift(w: Node) -> Variant:
	for m in w.movers:
		if m.kind == "y":
			return m
	return null


# ---------------------------------------------------------------- lab-2: the tower

func _tower() -> void:
	var w := await _world("lab-2")
	# The bottom: the start, and a jump there (his flame under the HUD's corner).
	_put(w, Vector2i(3, 43))
	await _hold(w, {}, 60)
	await _shot(w, "01_bottom_start")
	await _hold(w, {"jump": true}, 22)
	await _shot(w, "02_bottom_jump_top")
	# Up the ledges.
	_put(w, Vector2i(15, 37))
	await _hold(w, {}, 50)
	await _shot(w, "03_ledge2")
	_put(w, Vector2i(21, 34))
	await _hold(w, {}, 40)
	await _shot(w, "04_ledge3_weepcap")
	# The vine: walk off the third ledge's end into it, climb (shots while climbing), mount.
	_put(w, Vector2i(22, 34))
	await _hold(w, {}, 20)
	for i in 120:
		await _hold(w, {"right": true}, 1)
		if w.player.climbing:
			break
	await _hold(w, {}, 20)
	await _shot(w, "05_vine_caught")
	await _hold(w, {"up": true}, 50)
	await _shot(w, "06_vine_climbing")
	await _hold(w, {"up": true}, 50)
	await _shot(w, "07_vine_climbing_high")
	# The Creepbone coming down the vine stops the climb: strike it, then on up.
	await _hold(w, {"up": true}, 40)
	await _shot(w, "07b_vine_creepbone_overhead")
	for i in 90:
		await _hold(w, {"up": true, "attack": (i % 12) < 3}, 1)
	for i in 240:
		await _hold(w, {"up": true, "left": true}, 1)
		if w.player.on_floor:
			break
	await _hold(w, {}, 40)
	await _shot(w, "08_vine_top_mounted")
	# The middle: the altar shelf.
	_put(w, Vector2i(16, 21))
	await _hold(w, {}, 60)
	await _shot(w, "09_middle_altar")
	# The lift: stand on it and ride it.
	var lift = _lift(w)
	if lift != null:
		w.player.reset_at(lift.pos + Vector2(48, -1))
		await _hold(w, {}, 2)
		for i in 600:
			await _hold(w, {}, 1)
			if i == 200:
				await _shot(w, "10_lift_riding")
		_say("lab-2 lift: hero riding %s" % [w.player.riding != null])
		await _shot(w, "11_lift_later")
	# The upper climb and the top.
	_put(w, Vector2i(5, 11))
	await _hold(w, {}, 50)
	await _shot(w, "12_upper_ledge")
	# Under the belfry: the bell and its Bonebow up in the HUD's top band.
	_put(w, Vector2i(13, 8))
	await _hold(w, {}, 50)
	await _shot(w, "12b_bell_in_hud_band")
	_put(w, Vector2i(23, 5))
	await _hold(w, {}, 60)
	await _shot(w, "13_top_bell")
	# A fall from the upper ledge down the open middle (drop through it).
	await _tower_fall(w, "")
	await _sweep(w, "")
	# The camera and the backdrop as they were.
	w = await _world("lab-2", false)
	_put(w, Vector2i(3, 43))
	await _hold(w, {}, 60)
	await _shot(w, "01_bottom_start_old")
	await _tower_fall(w, "_old")
	await _sweep(w, "_old")


func _tower_fall(w: Node, tag: String) -> void:
	_put(w, Vector2i(12, 8))
	await _hold(w, {}, 40)
	await _shot(w, "14_fall_from_ledge_start" + tag)
	for i in 60:
		await _hold(w, {"down": true}, 1)
		if not w.player.on_floor:
			break
	await _hold(w, {}, 24)
	await _shot(w, "15_fall_a" + tag)
	await _hold(w, {}, 18)
	await _shot(w, "16_fall_b" + tag)
	for i in 120:
		await _hold(w, {}, 1)
	await _shot(w, "17_fall_c_low" + tag)
	for i in 400:
		await _hold(w, {}, 1)
		if w.player.on_floor:
			break
	await _hold(w, {}, 3)
	await _shot(w, "18_fall_landed" + tag)


# ---------------------------------------------------------------- lab-3: the shaft

func _shaft() -> void:
	var w := await _world("lab-3")
	await _shaft_top(w, "")
	# The frosted ledge and its Tickwind.
	_put(w, Vector2i(22, 11))
	await _hold(w, {}, 50)
	await _shot(w, "05_frosted_ledge")
	# Leap from its left end onto the vine, slide down.
	_put(w, Vector2i(21, 11))
	await _hold(w, {}, 20)
	for i in 80:
		await _hold(w, {"left": true, "jump": i < 30}, 1)
		if w.player.climbing:
			break
	await _hold(w, {}, 30)
	await _shot(w, "06_vine_caught")
	await _hold(w, {"down": true}, 24)
	await _shot(w, "07_vine_sliding")
	for i in 200:
		await _hold(w, {"down": true}, 1)
		if w.player.on_floor:
			break
	await _hold(w, {}, 40)
	await _shot(w, "08_vine_bottom_landing")
	# The middle: the altar landing.
	_put(w, Vector2i(6, 26))
	await _hold(w, {}, 60)
	await _shot(w, "09_middle_altar")
	# The lift down through the hole: on it at the top of its sweep, ride down.
	var lift = _lift(w)
	if lift != null:
		_put(w, Vector2i(16, 26))
		for i in 900:
			await _hold(w, {}, 1)
			if lift.pos.y <= 27 * 32 + 2 and lift.delta.y >= 0.0:
				break
		w.player.reset_at(lift.pos + Vector2(48, -1))
		await _hold(w, {}, 2)
		await _hold(w, {}, 80)
		await _shot(w, "10_lift_going_down")
		for i in 600:
			await _hold(w, {}, 1)
			if lift.pos.y >= 33 * 32 - 2:
				break
		await _shot(w, "11_lift_bottom")
		_say("lab-3 lift: hero riding %s, lift top %.0f" % [w.player.riding != null, lift.pos.y])
	await _shaft_drop(w, "")
	# The bottom: the bell.
	_put(w, Vector2i(10, 43))
	await _hold(w, {}, 60)
	await _shot(w, "16_bottom_bell")
	await _sweep(w, "")
	# The camera and the backdrop as they were.
	w = await _world("lab-3", false)
	await _shaft_top(w, "_old")
	await _shaft_drop(w, "_old")
	await _sweep(w, "_old")


func _shaft_top(w: Node, tag: String) -> void:
	_put(w, Vector2i(3, 3))
	await _hold(w, {}, 60)
	await _shot(w, "01_top_start" + tag)
	# Walk off the shelf: the drop to the first ledge.
	_put(w, Vector2i(8, 3))
	await _hold(w, {}, 20)
	await _walk_off(w, {"right": true})
	await _hold(w, {"right": true}, 6)
	await _shot(w, "02_drop_a" + tag)
	await _hold(w, {"right": true}, 8)
	await _shot(w, "03_drop_b" + tag)
	for i in 120:
		await _hold(w, {"right": true} if w.player.position.x < 15 * 32 else {}, 1)
		if w.player.on_floor:
			break
	await _hold(w, {}, 50)
	await _shot(w, "04_first_ledge" + tag)


func _shaft_drop(w: Node, tag: String) -> void:
	## The blind drop: from the ledge below the landing, walk off its right end
	## over the spike bed (hurt allowed: it's the point).
	_put(w, Vector2i(13, 34))
	await _hold(w, {}, 50)
	await _shot(w, "12_ledge_over_drop" + tag)
	await _walk_off(w, {"right": true})
	await _hold(w, {"right": true}, 8)
	await _shot(w, "13_blind_drop_a" + tag)
	await _hold(w, {}, 14)
	await _shot(w, "14_blind_drop_b" + tag)
	var hp0: float = w.player.hp
	w.player.invuln = 0.0
	for i in 120:
		await _hold(w, {}, 1, false)
		if w.player.on_floor or w.player.hp < hp0:
			break
	await _hold(w, {}, 2, false)
	await _shot(w, "15_blind_drop_lands" + tag)
	_say("%s blind drop%s: hp %.0f -> %.0f" % [_id, tag, hp0, w.player.hp])


func _sweep(w: Node, tag: String) -> void:
	## The camera from the level's bottom to its top in steps of half a view,
	## Waxby parked at the start (the backdrop, dark and props over the full
	## height). The camera is set by hand (the World's step is stopped), so
	## this is what the level holds, not what the follow logic would show.
	var lv = w.level
	var v: Vector2 = w._view_size()
	var top_c := v.y * 0.5
	var bottom_c: float = lv.height * 32 + w.BELOW - v.y * 0.5
	var y := bottom_c
	var k := 0
	w.set_physics_process(false)   # (the follow camera would pull it back to him)
	while true:
		w.cam = Vector2(lv.width * 16.0, y)
		w._cam_y_target = y
		w.camera.position = w.cam
		w.backdrop.follow(w.view_rect().position)
		await process_frame
		await process_frame
		var path := "%s/%s_sweep%s_%02d.png" % [_out, _id, tag, k]
		root.get_texture().get_image().save_png(path)
		k += 1
		if y <= top_c + 0.5:
			break
		y = maxf(y - v.y * 0.5, top_c)
	_say("%s sweep%s: %d frames, camera y %.0f..%.0f" % [_id, tag, k, bottom_c, top_c])
	w.set_physics_process(true)
