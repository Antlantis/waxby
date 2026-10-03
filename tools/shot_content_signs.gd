# 1-1's teaching signs as a new player meets them, for checking by eye: the
# Special's sign ({special_tip}, each calling's own line) for every calling,
# the flask's sign with Waxby hurt, and a Bellfounder pressing Peal cold
# (with story.gd's special_empty_founder bark, when there is one).
#   godot --path game --resolution 1266x585 --audio-driver Dummy \
#       --script res://../tools/shot_content_signs.gd -- <out_dir>
# Files are <out_dir>/signs_<name>.png, on the phone's safe area. The shots
# keep their own save (user://shot_signs.json).
extends SceneTree

const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
var UI
var LevelData
var World
var Story
var game: Node
var _out := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(_out)
	UI = load("res://scripts/ui.gd")
	LevelData = load("res://scripts/level_data.gd")
	World = load("res://scripts/world.gd")
	Story = load("res://scripts/story.gd")
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shot_signs.json"
	game.settings_path = "user://shot_signs_settings.json"
	UI.safe_override = UI.phone_safe(root.get_visible_rect().size)
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var special_x := -1
	var flask_x := -1
	for e in lv.entities:
		if e["kind"] == "sign":
			if str(e["text"]).contains("{special_tip}"):
				special_x = e["cell"].x
			elif str(e["text"]).contains("flask"):
				flask_x = e["cell"].x
	for cls in CALLINGS:
		var w = await _world(cls, special_x)
		print(cls, ": ", _hint(w))
		await _shot("special_%s" % cls)
		await _clear()
	var wf = await _world("knight", flask_x)
	wf.player.hp = wf.player.max_hp * 0.45
	await _wait(0.4)
	print("flask: ", _hint(wf))
	await _shot("flask")
	await _clear()
	# A Bellfounder with no Heat presses Peal by the first skeleton.
	var wb = await _world("founder", special_x + 9, false)
	wb.player.res = 0.0
	wb.test_pad = {"special": true}
	await physics_frame
	await physics_frame
	wb.test_pad = {}
	await _wait(0.6)
	print("founder cold: heard=", game.seen("bark:special_empty_founder"), " msg=", wb.hud._msg.get("text", ""))
	await _shot("founder_cold")
	await _clear()
	UI.safe_override = Rect2()
	quit()


func _hint(w: Node) -> String:
	return str(w.hud._hint)


func _world(cls: String, x: int, quiet_all := true) -> Node:
	## A fresh save with a new level-1 hero of this calling, in 1-1 at column
	## x, every story scene and bark already seen (so nothing takes the slot;
	## quiet_all false keeps the Special's barks unheard).
	for p in [game.save_path, game.settings_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	game.reset()
	game.new_hero(cls)
	for id in Story.scenes().keys():
		game.mark_seen(id)
	for k in Story.BARKS.keys():
		if quiet_all or not str(k).begins_with("special_"):
			game.mark_seen("bark:" + k)
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var w = World.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	for y in range(lv.height - 1, 0, -1):
		if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
			w.player.reset_at(Vector2(x * 32 + 16 - 20, (y + 1) * 32))
			break
	w.cam = w._clamp_cam(w.player.position)
	for i in 30:
		await physics_frame
	w.hud._title = {}
	w.hud._msg = {}
	w.hud._msgs.clear()
	await _wait(0.5)
	return w


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
	await process_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var path := "%s/signs_%s.png" % [_out, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _clear() -> void:
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx" and c.name != "Overlay":
			c.queue_free()
	for i in 2:
		await process_frame
