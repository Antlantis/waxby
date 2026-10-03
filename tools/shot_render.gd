# Deterministic screenshots for the render identity gate (and a look by eye).
#   godot --path <tree>/game --resolution 1266x585 --fixed-fps 60 \
#         --script <this file> -- --out <dir> [--levels 1-1,2-4] [--xs 0.1,0.5] \
#         [--seam] [--field full|quarter] [--stub] [--story] [--actions]
# Same seed, same fixed frame step and a fresh default save every shot, so two
# trees rendering the same shots can be compared pixel for pixel
# (tools/perf/shot_diff.py runs it in both and compares). It runs from any
# tree: every res:// path resolves in the tree it runs in.
#   --seam     use tools/perf/world_seam.gd (this copy's v3 light seam) in
#              place of world.gd, when the tree has it
#   --field    the light field plan for --seam (Plan A "full", Plan B "quarter")
#   --stub     also render the stub-theme test level (theme "stub": the plain
#              painter and style, every v3 tile), needs --seam's tree
#   --story    two story scenes (the cutscene's lit layers)
#   --actions  Wick running, mid-swing, mid-jump
# Level shots: Wick stood on the lowest floor at each x (fractions of the
# level's width, or tile columns if > 1), runs right for 30 ticks, then 12
# frames settle; saved as <out>/<level>_<xxx>.png.
extends SceneTree

const DEFAULT_XS := [3.0, 0.14, 0.3, 0.46, 0.62, 0.78, 0.94]
const LEVELS := ["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4"]
const SEED := 20260926

var _out := "/tmp/shot_render"
var _seam := false
var _field := ""
var _world_script: Script


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var levels: Array = LEVELS.duplicate()
	var xs: Array = DEFAULT_XS.duplicate()
	var stub := false
	var story := false
	var actions := false
	var i := 0
	while i < args.size():
		var a: String = args[i]
		var v: String = args[i + 1] if i + 1 < args.size() else ""
		match a:
			"--out":
				_out = v
				i += 1
			"--levels":
				levels = Array(v.split(",", false))
				i += 1
			"--xs":
				xs = []
				for s in v.split(",", false):
					xs.append(float(s))
				i += 1
			"--seam":
				_seam = true
			"--field":
				_field = v
				i += 1
			"--stub":
				stub = true
			"--story":
				story = true
			"--actions":
				actions = true
		i += 1
	DirAccess.make_dir_recursive_absolute(_out)
	var seam_path := "res://../tools/perf/world_seam.gd"
	_world_script = load("res://scripts/world.gd")
	var native := false
	for m in _world_script.get_script_method_list():
		if str(m["name"]) == "lit_at":
			native = true
	if native:
		_seam = true           # world.gd has the v3 light seam itself
	elif _seam and ResourceLoader.exists(seam_path):
		_world_script = load(seam_path)
	else:
		_seam = false
	_fresh_save()
	# Let the SFX cache and the first frames settle before anything is timed.
	for k in 20:
		await process_frame
	for id in levels:
		await _level_shots(str(id), xs)
	if actions:
		await _actions()
	if story:
		await _story()
	if stub:
		await _stub()
	print("[shot_render] done (%s)" % ("seam" if _seam else "world.gd"))
	quit()


func _fresh_save() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	# Default settings (brightness tints the dark) and a fresh game, in both trees.
	var sp := "user://shot_render_settings.json"
	if FileAccess.file_exists(sp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	game.settings_path = sp
	game.save_path = "user://shot_render_save.json"
	if game.has_method("reset"):
		game.reset()


func _make_world(lv: RefCounted) -> Node:
	# Its story beats count as seen, so none plays over the shot.
	var game = root.get_node_or_null("Game")
	if game != null and game.get("data") is Dictionary and game.data.get("seen") is Array:
		for sid in (lv.story as Dictionary).values():
			if not (game.data["seen"] as Array).has(str(sid)):
				(game.data["seen"] as Array).append(str(sid))
	var w: Node = _world_script.new()
	if _seam and _field != "":
		w.set("light_field_mode", _field)
	w.setup(lv)
	return w


func _level_shots(id: String, xs: Array) -> void:
	var LevelData = load("res://scripts/level_data.gd")
	for xf in xs:
		seed(SEED)
		_fresh_save()
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		var x: int = int(xf) if float(xf) > 1.0 else clampi(int(float(xf) * lv.width), 2, lv.width - 3)
		var w := _make_world(lv)
		root.add_child(w)
		await process_frame
		w.test_pad = {}
		var start: Vector2 = w.player.position
		w.player.reset_at(Vector2(x * 32 + 16, start.y))
		if x != 3:
			for y in range(lv.height - 1, 0, -1):
				if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
					w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
					break
		w.cam = w._clamp_cam(w.player.position)
		for k in 50:
			w.test_pad = {"right": k > 10 and k < 40}
			await physics_frame
		for k in 12:
			await process_frame
		var path := "%s/%s_%03d.png" % [_out, id, x]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
		w.queue_free()
		await process_frame


func _actions() -> void:
	seed(SEED)
	_fresh_save()
	var LevelData = load("res://scripts/level_data.gd")
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var w := _make_world(lv)
	root.add_child(w)
	await process_frame
	w.hud.visible = false
	var shots := [["run", {"right": true}, 40], ["swing", {"right": true, "attack": true}, 5], ["jump", {"right": true, "jump": true}, 40]]
	w.player.reset_at(Vector2(20 * 32, 13 * 32))
	for k in 30:
		w.test_pad = {}
		await physics_frame
	for sdef in shots:
		for k in sdef[2]:
			w.test_pad = sdef[1]
			await physics_frame
		await process_frame
		root.get_texture().get_image().save_png("%s/act_%s.png" % [_out, sdef[0]])
		for k in 60:
			w.test_pad = {}
			await physics_frame
	w.queue_free()
	await process_frame
	print("saved actions")


func _story() -> void:
	## Two scenes' first shots (the cutscene's lit layers over the dark).
	var Cut = load("res://scripts/cutscene.gd")
	RenderingServer.set_default_clear_color(Color("0e0a14"))
	for sid in ["intro", "boss_1_after"]:
		seed(SEED)
		_fresh_save()
		var c = Cut.new()
		c.setup(sid, func(): pass, false, null)
		c.manual = true
		c.follow_next = false
		root.add_child(c)
		await process_frame
		for k in 150:
			c.advance(1.0 / 60.0)
		for k in 3:
			await process_frame
		root.get_texture().get_image().save_png("%s/story_%s.png" % [_out, sid])
		print("saved story ", sid)
		c.queue_free()
		await process_frame


func _stub() -> void:
	## The stub theme on a small test level holding every v3 tile: the
	## plain painter, the plain backdrop style, the edge lines and motes.
	var Themes = load("res://scripts/themes/loader.gd")
	var fx_path := "res://tests/render/theme_stub.gd"
	if Themes == null or not ResourceLoader.exists(fx_path):
		return
	Themes.register(fx_path)
	var lv = stub_level()
	for xs in [3, 24, 44]:
		seed(SEED)
		_fresh_save()
		var w := _make_world(lv)
		root.add_child(w)
		await process_frame
		w.test_pad = {}
		w.player.reset_at(Vector2(xs * 32 + 16, 13 * 32))
		w.cam = w._clamp_cam(w.player.position)
		for k in 40:
			w.test_pad = {}
			await physics_frame
		for k in 12:
			await process_frame
		root.get_texture().get_image().save_png("%s/stub_%03d.png" % [_out, xs])
		print("saved stub ", xs)
		w.queue_free()
		await process_frame
	Themes.unregister(fx_path)


static func stub_level() -> RefCounted:
	var fx: Script = load("res://tests/render/theme_stub.gd")
	return fx.call("stub_level")
