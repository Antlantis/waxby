# The feel lab through the real menus, on the Mac, with real clicks: the
# title, the saves screen (slot 1), the map (its one-time card closed with
# its OK), the map's "Feel lab" button, then a few seconds of lab-1 under the
# thumbs. A screenshot at each step into <out_dir>; a line per step.
#   godot --path game --resolution 1266x585 --script res://../tools/menu_lab.gd -- <out_dir>
# It plays whatever saves the project's user dir holds (the integrator puts
# the owner's v2 slots there first, as on his phone).
extends SceneTree

var _out := "/tmp"
var main: Node
var _ok := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(_out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(90)
	_shot("1_title", "the title: %s" % _cur())
	await _click(Vector2(422, 195))   # a tap on the title
	await _frames(60)
	_shot("2_saves", "the saves screen: %s" % _cur())
	var saves: Control = main.current
	if saves == null or not saves.has_method("card_rects"):
		_fail("no saves screen after the title tap")
		quit(1)
		return
	var r0: Rect2 = saves.card_rects()[0]
	await _click(saves.get_global_transform_with_canvas() * r0.get_center())
	await _frames(90)
	_shot("3_map", "slot 1 opened: %s, save version %s, notices %s" % [_cur(), Game_().data.get("version"), Game_().data.get("notices")])
	var card: Node = main.current.find_child("Card", true, false) if main.current != null else null
	if card != null:
		var ok := _button(card, "OK")
		if ok != null:
			await _click_control(ok)
			await _frames(30)
		_shot("4_card_closed", "the one-time card closed: notices %s" % [Game_().data.get("notices")])
	var lab: Control = main.current.get_node_or_null("FeelLab") if main.current != null else null
	if lab == null:
		_fail("no Feel lab button on the map")
		quit(1)
		return
	_shot("5_map_lab_button", "the map's Feel lab button at %s" % lab.get_global_rect())
	await _click_control(lab)
	await _frames(120)
	var lid := str(main.current.get("level_id")) if main.current != null else ""
	_shot("6_lab1", "after the Feel lab button: %s (level %s)" % [_cur(), lid])
	if lid != "lab-1":
		_fail("the Feel lab button didn't open lab-1")
	Input.action_press("right")
	await _frames(240)
	Input.action_release("right")
	await _frames(10)
	_shot("7_lab1_walked", "two seconds of right: x %.0f" % float(main.current.player.position.x) if main.current != null and main.current.get("player") != null else "")
	print("[menu_lab] %s" % ("OK" if _ok else "FAILED"))
	quit(0 if _ok else 1)


func Game_() -> Node:
	return root.get_node("Game")


func _cur() -> String:
	if main.current == null:
		return "nothing"
	var sc: Script = main.current.get_script()
	return sc.resource_path.get_file() if sc != null else main.current.name


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _click(canvas_pos: Vector2) -> void:
	## A left click at a point of the base (844 x 390) canvas, as the window
	## sees it (the stretch applied).
	var at: Vector2 = root.get_final_transform() * canvas_pos
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)
		await _frames(3)


func _click_control(c: Control) -> void:
	await _click(c.get_global_transform_with_canvas() * (c.size * 0.5))


func _button(host: Node, text: String) -> Button:
	for n in host.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n
	return null


func _shot(name: String, line: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[menu_lab] %s: %s" % [name, line])


func _fail(why: String) -> void:
	_ok = false
	print("[menu_lab] FAIL: " + why)
