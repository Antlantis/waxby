extends SceneTree
# The game's way through, as main.gd plays it, one screenshot per stop: the
# title, the intro, the oath's chooser, the map after it, 1-1, Tollgrave's
# beat, 1-4's first clear (the belfry, the results), World 2's opening scene,
# 2-1, the Snuffer's first clear, its finale (the_pull: v3 retired v2's ending
# and post_credits) and the map after;
# then a v1 veteran's first and second launch. Uses its own save.
#   godot --path game --resolution 1266x585 --script res://../tools/shot_story_flow.gd -- <out_dir> [cls] [notch]

const DT := 1.0 / 60.0
var out := "/tmp"
var n := 0
var main: Node
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp"
	var cls: String = args[1] if args.size() > 1 else "knight"
	if args.size() > 2 and args[2] == "notch":
		load("res://scripts/ui.gd").safe_override = Rect2(62, 10, 720, 362)
	DirAccess.make_dir_recursive_absolute(out)
	# The game's own clear colour (main.gd), so a hole in a picture looks as it does in play.
	RenderingServer.set_default_clear_color(Color("0e0a14"))
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shot_flow_save.json"
	game.reset()
	main = load("res://scripts/main.gd").new()
	root.add_child(main)
	await _frames(30)
	await _snap("title")
	main._after_title()
	await _scene_until_line("intro")
	await _play_out(main.current, cls)
	await _scene_until_class()
	await _play_out(main.current, cls)
	await _frames(20)
	await _snap("map_after_oath")
	main.current.play.emit(0)
	await _frames(90)
	await _snap("level_1_1")
	# World 1 cleared up to its boss.
	for id in ["1-1", "1-2", "1-3"]:
		game.record_result(_result(id, ""))
	for id in ["beat_1_2", "beat_1_3", "beat_1_4"]:
		game.mark_seen(id)
	main.play_level(game.index_of("1-4"))
	await _frames(10)
	var w = main.current
	if w.boss != null:
		w._on_boss_woke()
		var bb := _overlay(w)
		if bb != null:
			bb.manual = true
			for i in 200:
				bb.advance(DT)
				if bb.waiting == "line" and bb._line["done"] and bb._line["t"] > 0.4:
					break
			await _snap("boss_1_before")
			await _play_out(bb, cls)
	await _frames(40)
	await _snap("fight_1")
	main.last_level = game.index_of("1-4")
	main._on_finished(_result("1-4", "boss_1_after"))
	await _play_out(main.current, cls)
	await _frames(100)
	await _snap("results_1_4")
	main.current.next.emit()
	await _frames(40)
	await _snap("world_2_scene")
	await _play_out(main.current, cls)
	await _frames(90)
	await _snap("level_2_1")
	# World 2 cleared up to the Snuffer, then his fall.
	for id in ["2-1", "2-2", "2-3"]:
		game.record_result(_result(id, ""))
	main.last_level = game.index_of("2-4")
	main._on_finished(_result("2-4", "boss_2_after"))
	await _play_out(main.current, cls)
	await _frames(100)
	await _snap("results_2_4")
	main.current.to_map.emit()
	await _frames(30)
	await _snap("the_pull")
	var end = main.current
	end.manual = true
	var credits := false
	for i in 8000:
		if end.finished:
			break
		if end.waiting == "credits" and not credits and end._credits.get("t", 0.0) > 9.0:
			credits = true
			await _snap("credits")
		elif end.waiting == "line" and end._line["done"] and end._line["t"] > 0.3:
			end.tap()
		end.advance(DT)
	await _frames(30)
	await _snap("map_after_pull")
	# A v1 veteran, first launch and second.
	var f := FileAccess.open(game.save_path, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/v1_save.json"))
	f.close()
	game.load_save()
	main.show_title()
	await _frames(10)
	main._after_title()
	await _scene_until_line("intro")
	await _play_out(main.current, cls)
	await _play_out(main.current, cls)
	await _frames(30)
	await _snap("veteran_map_first")
	game.load_save()
	main.show_title()
	main._after_title()
	await _frames(30)
	await _snap("veteran_map_second")
	game.reset()
	game.save()
	quit()


func _result(id: String, story_end: String) -> Dictionary:
	return {"level": id, "cleared": true, "embers": 31, "embers_total": 40, "sigils": [true, false, false],
		"time": 118.0, "relics": [], "items": [], "xp": 120, "levels": 0, "level_start": 1, "level_now": 1, "snuffs": 1,
		"diff": "dusk", "dread": false, "story_end": story_end}


func _overlay(w: Node) -> Node:
	for c in w.get_children():
		if c.get_script() == load("res://scripts/cutscene.gd") and not c.is_queued_for_deletion():
			return c
	return null


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _snap(tag: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%02d_%s.png" % [out, n, tag]
	n += 1
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  (", main.current.get_script().resource_path.get_file(), ")")


func _scene_until_line(id: String) -> void:
	var cs = main.current
	cs.manual = true
	for i in 600:
		cs.advance(DT)
		if cs.waiting == "line" and cs._line["done"] and cs._line["t"] > 0.4:
			break
	await _snap(id)


func _scene_until_class() -> void:
	var cs = main.current
	cs.manual = true
	for i in 600:
		cs.advance(DT)
		if cs.waiting == "class" and cs._chooser.get("t", 0.0) > 0.6:
			break
	await _snap("oath_chooser")


func _play_out(cs: Node, cls: String) -> void:
	if cs == null or cs.get_script() != load("res://scripts/cutscene.gd"):
		return
	cs.manual = true
	for i in 8000:
		if cs.finished:
			break
		if cs.waiting == "class":
			cs.pick(cls)
		elif cs.waiting == "line" and cs._line["done"] and cs._line["t"] > 0.3:
			cs.tap()
		cs.advance(DT)
	await process_frame
