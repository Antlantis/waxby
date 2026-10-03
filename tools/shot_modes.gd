# Screenshots of the modes, for checking by eye (workstreams.md 4.2): the
# Challenges hub (its first visit and after), the Descent, Waxworks and
# Trials screens, the Look tab, the Descent's results, and in a level: a
# depth's landing with its Glimmer cards, a depth under way (the mode pill),
# a trial's room with its candles, a trial's finish card, a Waxworks
# rematch and its result card, "The Deep keeps you".
#   godot --path game --resolution 1266x585 --audio-driver Dummy \
#       --script res://../tools/shot_modes.gd -- <out_dir> [safe] [sets]
# safe: "both" (the phone's island inset on both sides), "none" (plain margins).
# sets: a comma list of hub, descent, waxworks, trials, look, results, level,
#       depths (stitched depths walked along, for the seams), rooms (every
#       trial room walked along) (default: all but depths and rooms). Files are <out_dir>/<W>x<H>_<safe>_<name>.png; the
#       shots keep their own save (user://shots_modes_save.json).
extends SceneTree

var UI
var ModesSave
var Descent
var Waxworks
var Trials
var game: Node
var main: Node
var _out := "/tmp"
var _safe := "both"
var _tag := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	_safe = args[1] if args.size() > 1 else "both"
	var sets: Array = Array(args[2].split(",")) if args.size() > 2 else ["all"]
	DirAccess.make_dir_recursive_absolute(_out)
	UI = load("res://scripts/ui.gd")
	ModesSave = load("res://scripts/modes/modes_save.gd")
	Descent = load("res://scripts/modes/descent.gd")
	Waxworks = load("res://scripts/modes/waxworks.gd")
	Trials = load("res://scripts/modes/trials.gd")
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shots_modes_save.json"
	game.slot_base = "user://shots_modes_save"
	game.settings_path = "user://shots_modes_settings.json"
	for p in [game.save_path, game.save_path + ".bak", game.settings_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	game.reset()
	game.new_hero("knight")
	_story_so_far()
	var vs: Vector2 = root.get_visible_rect().size
	UI.safe_override = UI.phone_safe(vs) if _safe == "both" else Rect2(14.0, 10.0, vs.x - 28.0, vs.y - 18.0)
	var win := DisplayServer.window_get_size()
	_tag = "%dx%d_%s" % [win.x, win.y, _safe]
	main = load("res://scripts/main.gd").new()
	root.add_child(main)
	await _frames(4)
	var all := sets.has("all")
	for s in ["hub", "descent", "waxworks", "trials", "look", "results", "level", "depths", "rooms"]:
		if not (all and not ["depths", "rooms"].has(s) or sets.has(s)):
			continue
		match s:
			"hub": await _set_hub()
			"descent": await _set_descent()
			"waxworks": await _set_waxworks()
			"trials": await _set_trials()
			"look": await _set_look()
			"results": await _set_results()
			"level": await _set_level()
			"depths": await _set_depths()
			"rooms": await _set_rooms()
	UI.safe_override = Rect2()
	print("saved the modes' shots in ", _out)
	quit()


func _story_so_far() -> void:
	## A slot some way in: 1-1 to 2-4 cleared on Dusk, a hero at L22.
	for id in ["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4"]:
		game.level_record(id, "dusk")["cleared"] = true
	var h: Dictionary = game.hero()
	h["level"] = 22
	game.add_embers(1840)
	for k in ["intro", "oath", "meet_waxley"]:
		game.mark_seen(k)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _snap(name: String) -> void:
	await _frames(3)
	var path := "%s/%s_%s.png" % [_out, _tag, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _set_hub() -> void:
	main.show_modes()
	await _wait(0.4)
	await _snap("hub_first")
	var hub = main.get("current")
	hub.lines = []
	for k in ["hub:taper", "hub:waxley", "hub:descent"]:
		ModesSave.mark_seen(game, k)
	await _snap("hub")


func _set_descent() -> void:
	ModesSave.force_open = true
	var d: Dictionary = game.modes()["descent"]
	d["best"] = {"knight": {"dusk": {"depth": 14, "time": 1904.2, "level": 33, "strength": "normal"}},
			"runner": {"dusk": {"depth": 9, "time": 1210.0, "level": 30, "strength": "gentle"},
					"nightfall": {"depth": 4, "time": 640.0, "level": 34, "strength": "fierce"}},
			"witch": {"dusk": {"depth": 6, "time": 900.0, "level": 28, "strength": "normal"}}}
	main.show_modes("descent")
	await _wait(0.3)
	await _snap("descent")
	var run: Dictionary = Descent.new_run("knight", "dusk", "normal", 7, 99)
	run["glimmers"] = {"g_edge": 2, "g_wax": 1}
	run["spare"] = 1
	d["runs"]["knight"] = run
	main.show_modes("descent")
	await _wait(0.3)
	await _snap("descent_resume")
	d["runs"].erase("knight")


func _set_waxworks() -> void:
	ModesSave.force_open = false
	var wb: Dictionary = game.modes()["waxworks"]
	wb["bosses"] = {"tollgrave": {"dusk": {"drips": 9, "time": 74.2, "time_at_best": 81.0, "paid": ["clear", "bronze", "silver"]}}}
	wb["tweaks"] = ["hotter", "quick", "dim", "clock"]
	main.show_modes("waxworks")
	await _wait(0.3)
	# Waxley's Clock tapped last: its effect under the chips.
	var hub = main.get("current")
	if hub != null and hub.get("sub") != null:
		hub.sub.set("tip", "clock")
	await _wait(0.1)
	await _snap("waxworks")


func _set_trials() -> void:
	game.modes()["trials"] = {"k1": {"best": 15.2, "medal": 4, "paid": 4, "tries": 12}, "k2": {"best": 31.0, "medal": 2, "paid": 2, "tries": 3}}
	main.show_modes("trials")
	await _wait(0.3)
	await _snap("trials")
	var sc = main.get("current")
	if sc != null and sc.get("sub") != null:
		sc.sub.set_cls("witch")
	await _wait(0.2)
	await _snap("trials_witch")


func _set_look() -> void:
	for nid in ["flame:emberheart", "flame:marigold", "flame:bellbronze", "flame:prismfire"]:
		game.grant_cosmetic(nid)
	game.set_look("flame", "marigold")
	var hs: Control = load("res://scripts/hero_screen.gd").new()
	var tabs: Array = hs.TABS
	main._swap(hs)
	await _frames(2)
	if tabs.has("look"):
		hs.open_tab("look")
	else:
		# Until SC adds the tab: the panel where the tab would put it.
		if hs.panel:
			hs.panel.queue_free()
		var lp: Control = load("res://scripts/modes/look_panel.gd").new()
		lp.set("host", hs)
		hs.add_child(lp)
		hs.move_child(lp, 0)
		var r: Rect2 = hs.content_rect()
		lp.position = r.position
		lp.size = r.size
		hs.panel = lp
	await _wait(0.4)
	await _snap("look")


func _set_results() -> void:
	var r: Control = load("res://scripts/modes/mode_results.gd").new()
	r.set("results", {"cls": "knight", "diff": "dusk", "depth": 11, "reached": 12, "start": 1, "time": 1532.0, "kills": 214,
			"elites": 6, "items": 9, "xp": 48210, "milestones": [{"depth": 5, "cosmetic": "flame:emberheart"}, {"depth": 10, "legend": 1, "cosmetic": "flame:coalheart"}],
			"ended": "snuffed", "best": 11, "new_best": true, "spare_used": 2})
	r.set("main", main)
	main._swap(r)
	await _wait(0.3)
	await _snap("descent_results")


func _set_level() -> void:
	# A Descent depth's landing, its Glimmers on offer.
	ModesSave.force_open = true
	var m = Descent.start(main, "knight", "dusk", "normal", 7, 4242)
	await _wait(1.6)
	var w = main.get("current")
	for a in w.altars:
		if a["cell"].x <= int(m.built["landing_x1"]):
			w.player.reset_at(a["pos"])
	await _wait(0.5)
	await _snap("level_glimmers")
	m.choose_glimmer(0)
	# Under way: into the first room.
	w.player.reset_at(Vector2((int(m.built["landing_x1"]) + 8) * 32 + 16, 13 * 32))
	await _wait(0.8)
	await _snap("level_descent")
	# The Deep keeps you.
	if m.hud != null:
		m.hud.deep_keeps(func(): pass)
	await _wait(0.7)
	await _snap("level_deep_keeps")
	if m.hud != null:
		m.hud.close_card()
	# A trial's room: Ping!, its three candles in front of the bows.
	var t = Trials.play_trial(main, "k1")
	await _wait(1.2)
	var tw = main.get("current")
	tw.player.reset_at(Vector2(22 * 32 + 16, 13 * 32))
	await _wait(1.0)
	await _snap("level_trial_k1")
	# Its finish card.
	for mk in t.marks:
		mk["lit"] = true
	t.clock = 15.84
	t.started = true
	if not tw.bells.is_empty():
		tw._ring(tw.bells[0])
	await _wait(1.2)
	await _snap("level_trial_finish")
	game.return_hero()
	# Lanterns of Wax in the dark.
	Trials.play_trial(main, "w1")
	await _wait(1.2)
	var tw2 = main.get("current")
	tw2.player.reset_at(Vector2(15 * 32 + 16, 13 * 32))
	await _wait(0.6)
	await _snap("level_trial_w1")
	game.return_hero()
	# A Waxworks rematch, and its result card.
	var wx = Waxworks.rematch(main, "snuffer", "dusk", ["hotter", "quick"])
	await _wait(1.2)
	var ww = main.get("current")
	var b = ww.get("boss")
	if b != null:
		ww.player.reset_at(b.position + Vector2(-160, 0))
	await _wait(1.2)
	await _snap("level_rematch")
	wx.fight_t = 83.4
	ww._ring(ww.add_bell(ww.player.position + Vector2(40, 0)))
	await _wait(1.8)
	await _snap("level_rematch_card")
	ModesSave.force_open = false


func _walk_shots(name: String, w: Node, xs: Array) -> void:
	for x in xs:
		var lv = w.level
		for y in range(lv.height - 1, 0, -1):
			if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
				w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
				break
		w.player.invuln = 99.0
		w.cam = w._clamp_cam(w.player.position)
		await _wait(0.35)
		await _snap("%s_%03d" % [name, x])


func _set_depths() -> void:
	ModesSave.force_open = true
	for d in [3, 5, 8]:
		var m = Descent.start(main, "knight", "dusk", "normal", d, 4242)
		await _wait(0.8)
		var w = main.get("current")
		var xs: Array = []
		for sp in m.built["spans"]:
			xs.append(int(sp["x0"]) + 1)
			xs.append((int(sp["x0"]) + int(sp["x1"])) / 2)
		await _walk_shots("depth%d" % d, w, xs)
	ModesSave.force_open = false


func _set_rooms() -> void:
	for id in ["k1", "k2", "w1", "w2", "r1", "r2", "f1", "f2", "x1", "x2"]:
		Trials.play_trial(main, id)
		await _wait(0.8)
		var w = main.get("current")
		var xs: Array = []
		var x := 3
		while x < int(w.level.width):
			xs.append(x)
			x += 24
		await _walk_shots("room_" + id, w, xs)
		game.return_hero()
