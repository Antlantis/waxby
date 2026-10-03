extends SceneTree
# Story screenshots: plays scenes with taps and saves a PNG at each key moment
# (a shot settled before anyone speaks, each line fully typed, the chooser and
# a card open in it, world and boss cards, the credits, the iris).
#   godot --path game --resolution 1266x585 --script res://../tools/shot_story.gd -- \
#       <out_dir> <scene,scene,...|all> [cls] [notch,keeper]
# "notch" pretends to be the iPhone in landscape (a 62-px inset left and right).
# Overlay beats play over a real level (1-4 for World 1's, 2-4 for World 2's).

const DT := 1.0 / 60.0
const NOTCH := Rect2(62, 10, 720, 362)
var Cutscene
var Story
var UIs
var game
var out := "/tmp"
var n := 0
var tag := ""
var keeper := false      # "keeper": the oath hosts the Keeper screen (not its own chooser on the plinths)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp"
	var list: String = args[1] if args.size() > 1 else "intro,oath,boss_1_before"
	var cls: String = args[2] if args.size() > 2 else "knight"
	var opts: String = args[3] if args.size() > 3 else ""
	var notch: bool = opts.contains("notch")
	keeper = opts.contains("keeper")
	DirAccess.make_dir_recursive_absolute(out)
	# The game's own clear colour (main.gd), so a hole in a picture looks as it does in play.
	RenderingServer.set_default_clear_color(Color("0e0a14"))
	await process_frame
	Cutscene = load("res://scripts/cutscene.gd")
	Story = load("res://scripts/story.gd")
	UIs = load("res://scripts/ui.gd")
	if notch:
		UIs.safe_override = NOTCH
		tag = "n_"
	game = root.get_node("Game")
	game.save_path = "user://shot_story_save.json"
	game.reset()
	game.new_hero(cls)
	var ids: Array = []
	if list == "all":
		# Every scene story.gd has, in its order (v2's retired ending and
		# post_credits are gone; the_pull, W3-W6, homecoming and lullaby came).
		ids = Story.scenes().keys()
	else:
		ids = Array(list.split(","))
	for id in ids:
		await _shoot(str(id), cls)
	game.reset()
	quit()


func _snap(what: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s%02d_%s.png" % [out, tag, n, what]
	n += 1
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _run_frames(cs, k: int) -> void:
	for i in k:
		cs.advance(DT)
		if cs._keeper != null:
			cs._keeper._process(DT)


func _shoot(id: String, cls: String) -> void:
	var sc: Dictionary = Story.scene(id)
	var ov := bool(sc.get("overlay", false))
	var host: Node = root
	var w = null
	if ov:
		# A level under the overlay, as in play.
		var World = load("res://scripts/world.gd")
		var LevelData = load("res://scripts/level_data.gd")
		w = World.new()
		var lv := "res://levels/2-4.txt" if id.ends_with("_2_before") or id.begins_with("beat_2") else "res://levels/1-4.txt"
		w.setup(LevelData.load_file(lv))
		w.autoplay = true    # its own beat stays out of the way
		root.add_child(w)
		for i in 4:
			await process_frame
		w.autoplay = false
		host = w
	var cs = Cutscene.new()
	cs.setup(id, func(): pass, ov, w)
	cs.manual = true
	cs.follow_next = false
	if keeper:
		cs.host_keeper = true
	host.add_child(cs)
	await process_frame
	var last_line := ""
	var card_shot := false
	var boss_shot := false
	var chooser := 0
	var credit_shots := [2.5, 6.0, 9.6]
	var iris_shot := false
	var moved := {}
	var shot_i := -2
	for i in 8000:
		if cs.finished:
			break
		cs.advance(DT)
		# A new shot, settled: the picture before anyone speaks.
		if cs._shot_i != shot_i and cs.waiting != "fade_out" and cs.waiting != "fade_in" and cs._fade < 0.01:
			shot_i = cs._shot_i
			if cs._panel_id != "":
				await _snap("%s_shot%d" % [id, shot_i])
		if cs.waiting == "class":
			if cs._keeper != null:
				if chooser == 0:
					_run_frames(cs, 40)
					await _snap("%s_keeper" % id)
					cs._keeper.open_card(cls)
					chooser = 1
				elif chooser == 1:
					_run_frames(cs, 40)
					await _snap("%s_keeper_card_%s" % [id, cls])
					cs._keeper.choose(cls)
					chooser = 2
			else:
				if chooser == 0 and cs._chooser.get("t", 0.0) > 0.5:
					await _snap("%s_chooser" % id)
					cs._hover(cls)
					chooser = 1
				elif chooser == 1:
					_run_frames(cs, 40)
					await _snap("%s_chooser_%s" % [id, cls])
					chooser = 2
					cs.pick(cls)
			continue
		if not cs._boss.is_empty() and cs._boss["t"] > 0.8 and not boss_shot:
			await _snap("%s_bosscard" % id)
			boss_shot = true
		if not cs._card.is_empty() and cs._card["t"] > 1.2 and not card_shot:
			await _snap("%s_card" % id)
			card_shot = true
		if not cs._credits.is_empty() and not credit_shots.is_empty() and cs._credits["t"] > credit_shots[0]:
			await _snap("%s_credits_%.0f" % [id, credit_shots[0]])
			credit_shots.pop_front()
		# A figure moving or fading off (the Snuffer out of the window), half
		# way, and just after it's gone (nothing of it should be left).
		for a in cs._figs:
			var f: Dictionary = cs._figs[a]
			var tw: Dictionary = f["tw"]
			if tw.has("alpha") and float(tw["dur"]) > 0.0 and float(tw["t"]) >= float(tw["dur"]) * 0.45 and not moved.has(a):
				moved[a] = 1
				await _snap("%s_%s_leaving" % [id, a])
			elif moved.get(a, 0) == 1 and tw.is_empty() and float(f["alpha"]) < 0.01:
				moved[a] = 2
				_run_frames(cs, 6)
				await _snap("%s_%s_gone" % [id, a])
		if not cs._iris.is_empty() and cs._iris["t"] > 1.2 and not iris_shot:
			await _snap("%s_iris" % id)
			iris_shot = true
		if cs.waiting == "line" and cs._line["done"]:
			var key: String = cs._line["text"]
			if key != last_line and cs._line["t"] > 0.4:
				last_line = key
				_run_frames(cs, 12)
				await _snap("%s_%s" % [id, str(cs._line["who"])])
				cs.tap()
	if ov:
		w.queue_free()
	else:
		cs.queue_free()
	for i in 3:
		await process_frame
