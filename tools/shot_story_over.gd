extends SceneTree
# Overlay beats over what they really play on, as main.gd opens them, with the
# phone's own safe area (the island's inset on both sides): Waxley's first
# meeting on the Chandler, a new calling's word on the map, and the level
# beats over their levels (1-2's panel, 1-3's and 2-1's lines, the Snuffer's
# boss beat over 2-4). Each is shot at its first line, fully typed, with a
# guide of the letterbox bars and the Skip pill drawn on top when "guides" is
# given. Uses its own save.
#   godot --path game --resolution 1266x585 --script res://../tools/shot_story_over.gd -- <out_dir> [guides]

const DT := 1.0 / 60.0
var out := "/tmp"
var n := 0
var main: Node
var game: Node
var UI
var guides := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp"
	guides = args.size() > 1 and args[1].contains("guides")
	DirAccess.make_dir_recursive_absolute(out)
	RenderingServer.set_default_clear_color(Color("0e0a14"))
	await process_frame
	UI = load("res://scripts/ui.gd")
	UI.safe_override = UI.phone_safe(root.get_visible_rect().size)
	game = root.get_node("Game")
	game.save_path = "user://shot_over_save.json"
	game.settings_path = "user://shot_over_settings.json"
	game.reset()
	game.new_hero("knight")
	for id in ["intro", "oath", "world_1", "world_2", "beat_1_1"]:
		game.mark_seen(id)
	game.data["embers"] = 640
	main = load("res://scripts/main.gd").new()
	root.add_child(main)
	await _frames(5)
	# The Chandler, the first time in.
	main.show_chandler()
	await _frames(20)
	await _first_line(_overlay(main.current), "chandler_meet_waxley")
	# A second calling made: Taper's word on the map.
	main.show_map(0)
	await _frames(10)
	main._on_calling_picked("witch", ["knight"])
	await _frames(10)
	await _first_line(_overlay(main.current), "map_new_calling")
	# Again with World 2 open: the map's world tabs sit just under its top row.
	for id in ["1-1", "1-2", "1-3", "1-4"]:
		game.record_result({"level": id, "cleared": true, "embers": 1, "embers_total": 2, "sigils": [false, false, false],
			"time": 90.0, "relics": [], "items": [], "xp": 0, "levels": 0, "level_start": 1, "level_now": 1, "snuffs": 0,
			"diff": "dusk", "dread": false, "story_end": ""})
	main.show_map(0)
	await _frames(10)
	main._on_calling_picked("runner", ["knight", "witch"])
	await _frames(10)
	await _first_line(_overlay(main.current), "map_world_2_new_calling")
	# The level beats, over their levels.
	for id in ["1-2", "1-3", "2-1"]:
		main.play_level(game.index_of(id))
		await _frames(10)
		await _first_line(_overlay(main.current), "level_%s" % id)
	# The Snuffer's beat, as he wakes (2-4's own opening beat seen before).
	game.mark_seen("beat_2_4")
	main.play_level(game.index_of("2-4"))
	await _frames(10)
	var w = main.current
	if w.boss != null:
		w._on_boss_woke()
		await _frames(2)
		await _first_line(_overlay(w), "level_2-4_boss_2_before")
	UI.safe_override = Rect2()
	game.reset()
	game.save()
	quit()


func _overlay(host: Node) -> Node:
	for c in host.get_children():
		if c.get_script() == load("res://scripts/cutscene.gd") and not c.is_queued_for_deletion():
			return c
	return null


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _first_line(cs, tag: String) -> void:
	if cs == null:
		print("no overlay for ", tag)
		return
	cs.manual = true
	for i in 900:
		cs.advance(DT)
		if cs.waiting == "line" and cs._line["done"] and cs._line["t"] > 0.4 and cs._fade < 0.01:
			break
	var dbg: Control = null
	if guides:
		var layer := CanvasLayer.new()
		layer.layer = 30
		dbg = Control.new()
		dbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(dbg)
		root.add_child(layer)
		dbg.draw.connect(func():
			dbg.draw_rect(cs._pill_rect(), Color(1, 0.2, 0.2, 0.9), false, 1.0)
			dbg.draw_rect(UI.safe_override, Color(0.2, 1, 0.4, 0.6), false, 1.0))
	await _snap(tag)
	var hud = cs.world.get("hud") if cs.world != null else null
	print("  %s: top bar %.1f, pill %s, hud visible %s" % [tag, cs.top_bar_h() if cs.has_method("top_bar_h") else -1.0,
			cs._pill_rect(), str(hud.visible) if hud != null else "-"])
	if dbg != null:
		dbg.get_parent().queue_free()
	# Play it out, so the next stop starts clean.
	for i in 8000:
		if cs.finished:
			break
		if cs.waiting == "line" and cs._line["done"] and cs._line["t"] > 0.3:
			cs.tap()
		cs.advance(DT)
	await _frames(2)
	if hud != null and is_instance_valid(hud):
		print("  %s after: hud visible %s" % [tag, str(hud.visible)])


func _snap(tag: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%02d_%s.png" % [out, n, tag]
	n += 1
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
