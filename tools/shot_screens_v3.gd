extends SceneTree
## SC's v3 screens, shot with stand-ins: header-only W3-W6 levels and secret
## levels written to user:// (nothing outside the project is needed), so it
## runs before the level and secret streams land. A window is needed:
##   cd game && $G --path . --resolution 1266x585 --script res://../tools/shot_screens_v3.gd -- <out_dir> [all|map|hud|sheet|results|pause|title]
## (or from anywhere: --script <absolute path to this file>). Every shot is
## also taken at the phone's safe area (UI.phone_safe).

const STANDINS := "user://sc_shot_standins"
const NAMES := {"3-1": "The Bramble Gate", "3-2": "The Hanging Ossuary", "3-3": "The Sporewood", "3-4": "The Heartwood",
		"4-1": "The Rime Stair", "4-2": "The Escapement", "4-3": "The Hall of Weights", "4-4": "The Hour Chamber",
		"5-1": "The Floating Aisle", "5-2": "The Gale Gallery", "5-3": "The Dawnglass Bridges", "5-4": "The Lightwell",
		"6-1": "The Black Shore", "6-2": "The Drowned Bells", "6-3": "The Long Quiet", "6-4": "The Heart of the Hush",
		"1-S": "The Roof of Evenbell", "2-S": "The Chandlers' Vault", "3-S": "The Rootcrown", "4-S": "The Mainspring",
		"5-S": "The Rose Window", "6-S": "The Lightless Mile"}
var OUT := ""
var UI
var game: Node
var Progression
var Classes


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	OUT = args[0] if args.size() > 0 else "user://sc_shots"
	var what: String = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	UI = load("res://scripts/ui.gd")
	Progression = load("res://scripts/progression.gd")
	Classes = load("res://scripts/classes.gd")
	game = root.get_node("Game")
	game.save_path = "user://shots_save.json"
	game.settings_path = "user://shots_settings.json"
	await process_frame
	game.reset()
	var vs := Vector2(root.get_visible_rect().size)
	UI.safe_override = UI.phone_safe(vs)
	_standins()
	if what in ["all", "map"]:
		await _map()
	if what in ["all", "hud"]:
		await _hud()
	if what in ["all", "sheet"]:
		await _sheet()
	if what in ["all", "results"]:
		await _results()
	if what in ["all", "pause"]:
		await _pause()
	if what in ["all", "title"]:
		await _title()
	print("shots done")
	quit()


func _standin(path: String, id: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("title: %s\nsubtitle: %s\narea: %d\n%s---\n" % [NAMES.get(id, id), id, int(game.AREAS.get(id, 1)),
			"boss: rootmother\n" if id.ends_with("-4") else ""])
	f.close()


func _standins() -> void:
	## The build's levels, stand-ins for the rest; the six secret levels.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STANDINS))
	var lv: Array = []
	for l in game.ALL_LEVELS:
		var p: String = l["path"]
		if not FileAccess.file_exists(p):
			p = "%s/%s.txt" % [STANDINS, l["id"]]
			_standin(p, str(l["id"]))
		lv.append({"id": l["id"], "path": p, "world": l["world"]})
	game.LEVELS = lv
	var sec: Array = []
	for s in game.SECRET_LEVELS:
		var p := "%s/%s.txt" % [STANDINS, s["id"]]
		if not FileAccess.file_exists(str(s["path"])):
			_standin(p, str(s["id"]))
		else:
			p = str(s["path"])
		sec.append({"id": s["id"], "path": p, "world": s["world"], "from": s["from"]})
	UI.secret_levels_override = sec


func _shot(name: String, frames := 6) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])


func _hero(level: int, cls := "knight") -> void:
	game.reset()
	game.new_hero(cls)
	if level > 1:
		game.add_xp(Progression.total_to(level))
	game.hero()["points"] = 0


func _clear(ids: Array, d := "dusk") -> void:
	var keep: String = game.data["difficulty"]
	game.data["difficulty"] = d
	for id in ids:
		game.record_result({"level": id, "cleared": true, "time": 100.0, "sigils": [true, false, true], "embers": 0})
	game.data["difficulty"] = keep


func _map() -> void:
	var Map = load("res://scripts/map_screen.gd")
	# World 1, 1-3 cleared: the spark and "1 secret".
	_hero(6)
	_clear(["1-1", "1-2", "1-3"])
	var m = Map.new()
	m.focus = 2
	root.add_child(m)
	await _shot("map_w1_spark")
	m.queue_free()
	# Its bell rung: the silver medallion, picked.
	game.find_secret("1-S", "dusk", false)
	m = Map.new()
	m.focus = 2
	root.add_child(m)
	await _shot("map_w1_found", 3)
	m.focus_secret = "1-S"
	await _shot("map_w1_secret")
	m.queue_free()
	# Deep in: World 3 open, a hero of 15, the Challenges (stood in).
	_hero(15)
	_clear(["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4", "3-1", "3-2", "3-3"])
	game.find_secret("3-S", "dusk", false)
	Map.modes_screen = "res://scripts/ui.gd"
	m = Map.new()
	m.focus = game.index_of("3-4")
	root.add_child(m)
	await _shot("map_w3")
	m.card("v3_update", "The bells below have woken", "Below the Tallow Deep lie four new worlds, and the Hush at the bottom. Your hero, gear and records came with you.")
	await _shot("map_card", 60)
	m.close_card()
	m.queue_free()
	# Every world open, on World 6, Nightfall open with its chips.
	_hero(24)
	var all: Array = []
	for l in game.LEVELS:
		all.append(l["id"])
	_clear(all)
	game.data["unlocked"]["nightfall"] = 1
	m = Map.new()
	m.focus = game.index_of("6-2")
	root.add_child(m)
	await _shot("map_w6")
	game.set_diff("nightfall")
	m.queue_free()
	m = Map.new()
	m.focus = 0
	root.add_child(m)
	await _shot("map_nightfall")
	m._go(0)
	await _shot("map_warning", 60)
	m.queue_free()
	Map.modes_screen = Map.MODES_SCREEN
	game.set_diff("dusk")
	# A locked bell's note, then a locked world's tab's, over the name line.
	_hero(15)
	_clear(["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4", "3-1"])
	m = Map.new()
	m.focus = game.index_of("3-2")
	root.add_child(m)
	await _shot("map_w3_plain", 4)
	m.set_difficulty("witching")
	await _shot("map_note_bell", 12)
	m._note_t = 0.0
	var T: Dictionary = m.tabs_by_world()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = (T[4] as Rect2).get_center()
	m._gui_input(e)
	await _shot("map_note_tab", 12)
	m.queue_free()
	await process_frame


func _world(lid := "1-1") -> Node:
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	var w = World.new()
	w.setup(LevelData.load_file("res://levels/%s.txt" % lid))
	root.add_child(w)
	return w


func _hud() -> void:
	_hero(40)
	game.add_xp(int(Progression.MARK_XP * 3.4))
	var w := _world()
	await _shot("hud_base", 30)
	var hud = w.hud
	hud._title = {}
	hud.dim_ring(true)
	hud.boss_bar({"id": "rootmother", "name": "Mother Gravebough", "title": "Heart of the Bone Orchard", "frac": 0.52, "segments": [0.65, 0.30], "awake": true})
	await _shot("hud_dim_boss", 40)
	hud.boss_bar({})
	hud.dim_ring(false)
	hud.mode_pill({"label": "D7", "clock": 132.47, "lives": 1, "lives_max": 2, "dots": 3})
	hud.card("depth", "DEPTH 8", "The Tallow Deep")
	await _shot("hud_pill_card", 40)
	# A level-up a second into a card: the card makes way, then comes back.
	hud._title = {}
	hud._cardq.clear()
	hud.card("depth9", "DEPTH 9", "The Tallow Deep")
	await _shot("hud_card", 60)
	hud.level_up(int(game.hero()["level"]))
	await _shot("hud_card_levelup_a", 4)
	await _shot("hud_card_levelup_b", 40)
	await _shot("hud_card_levelup_c", 150)
	hud._title = {}
	hud._lvl = {}
	hud._cardq.clear()
	# The Waxworks: a pill and the Tinker's bar in three, narrowed beside it.
	hud.mode_pill({"label": "Rematch", "clock": 61.2, "count": "3/5"})
	hud.boss_bar({"id": "tinker", "name": "The Tinker of Hours", "title": "Keeper of the Carillon", "frac": 0.48, "segments": [0.65, 0.30], "awake": true})
	await _shot("hud_pill_boss", 40)
	hud.mode_pill({})
	hud.boss_bar({"id": "saint", "name": "The Prism Saint", "title": "Light of the Shattered Sanctum", "frac": 0.2, "segments": [0.65, 0.30], "awake": true})
	await _shot("hud_boss_p3", 40)
	hud.boss_bar({})
	hud.fade_for_finale(true)
	hud.special_pill("Hold to give your flame")
	w.special_override = {"hold_ring": 0.45}
	await _shot("hud_finale_quiet", 120)
	hud.bark("snuffer_dark")
	await _shot("hud_finale", 30)
	w.queue_free()
	await process_frame


func _sheet() -> void:
	var Sheet = load("res://scripts/hero_screen.gd")
	var Belt = load("res://scripts/belt_panel.gd")
	var Items = load("res://scripts/items.gd")
	Classes.set_deep(true)
	_hero(27, "witch")
	game.hero()["points"] = 6
	game.hero()["skills"] = {"w_flare": 6, "w_hotter": 2, "w_twin": 2, "w_kindle": 3, "w_sunburst": 1, "w_pyre": 2, "w_waxskin": 1}
	var h = Sheet.new()
	h.tab = "skills"
	root.add_child(h)
	await _shot("sheet_skills")
	h.panel.select("w_wildfire")
	await _shot("sheet_skills_t5")
	h.panel.select("w_seal")
	await _shot("sheet_skills_cap2")
	h.open_tab("stats")
	await _shot("sheet_stats")
	h.queue_free()
	# Level 30 with one capstone: the second_capstone bark over the Sheet.
	_hero(30, "witch")
	game.hero()["points"] = 3
	game.hero()["skills"] = {"w_flare": 6, "w_hotter": 2, "w_twin": 2, "w_kindle": 3, "w_sunburst": 1, "w_pyre": 2, "w_waxskin": 1}
	h = Sheet.new()
	h.tab = "skills"
	root.add_child(h)
	await _shot("sheet_bark", 30)
	h.queue_free()
	# A late hero's full list: every v3 row (18).
	_hero(40)
	var sub := GDScript.new()
	sub.source_code = "extends \"res://scripts/stats_panel.gd\"\nfunc _stats() -> Dictionary:\n\tvar s: Dictionary = super()\n\ts.merge({\"dim_resist\": 0.3, \"shot_dr\": 0.15, \"xp_pct\": 0.1, \"ember_pct\": 0.1, \"on_kill_heal\": 0.02, \"vigil\": 7, \"marks\": 12}, true)\n\treturn s\n"
	sub.reload()
	h = Sheet.new()
	h.tab = "stats"
	root.add_child(h)
	await process_frame
	var p2 = sub.new()
	p2.host = h
	h.panel.queue_free()
	h.panel = p2
	h.add_child(p2)
	h.move_child(p2, 0)
	h._layout()
	await _shot("sheet_stats_full", 6)
	h.queue_free()
	Classes.set_deep(false)
	Items.slots_by_area = true
	_hero(9)
	game.hero()["deepest"] = 9
	game.hero()["equip"].erase("boots")
	game.hero()["equip"].erase("charm")
	h = Sheet.new()
	h.tab = "gear"
	root.add_child(h)
	await _shot("sheet_gear", 4)
	h.panel.select_slot("boots")
	await _shot("sheet_gear_boots")
	h.queue_free()
	Items.slots_by_area = false
	Belt.slots_shown = 5
	_hero(27)
	game.data["relics"] = ["tallow_heart", "rook_feather", "bellows", "moth_charm", "saints_knuckle", "phoenix_wick", "choir_bone"]
	h = Sheet.new()
	h.tab = "belt"
	root.add_child(h)
	await _shot("sheet_belt")
	h.queue_free()
	Belt.slots_shown = 0
	await process_frame


func _results() -> void:
	var R = load("res://scripts/results_screen.gd")
	_hero(9)
	var r = R.new()
	r.result = {"level": "1-3", "cleared": true, "embers": 44, "embers_total": 60, "embers_placed": 51, "sigils": [true, true, false],
			"time": 244.2, "relics": [], "items": [], "xp": 210, "levels": 0, "diff": "dusk", "secret": "1-S", "secret_new": true}
	r.rewards = [{"kind": "secret", "id": "1-S"}]
	r.first_clear = true
	root.add_child(r)
	r._t = 10.0
	await _shot("results_secret")
	r.queue_free()
	r = R.new()
	r.result = {"level": "1-3", "cleared": true, "embers": 50, "embers_total": 60, "embers_placed": 51, "sigils": [true, true, true],
			"time": 201.7, "relics": [], "items": [], "xp": 120, "levels": 0, "diff": "dusk", "secret": "1-S", "secret_new": false}
	r.rewards = []
	root.add_child(r)
	r._t = 10.0
	await _shot("results_secret_again")
	r.queue_free()
	_hero(29)
	r = R.new()
	r.result = {"level": "6-2", "cleared": true, "embers": 88, "embers_total": 90, "embers_placed": 80, "sigils": [true, true, true],
			"time": 402.0, "relics": [], "items": [], "xp": 900, "levels": 0, "diff": "dusk", "candles": {"lit": 7, "total": 9}}
	r.rewards = [{"kind": "draught", "id": "second"}]
	root.add_child(r)
	r._t = 10.0
	await _shot("results_candles")
	r.queue_free()
	_hero(40)
	game.add_xp(int(Progression.MARK_XP * 2.95))
	r = R.new()
	r.result = {"level": "1-S", "cleared": true, "embers": 30, "embers_total": 40, "embers_placed": 38, "sigils": [true, false, true],
			"time": 300.0, "relics": ["bellows"], "items": [], "xp": int(Progression.MARK_XP * 0.1), "levels": 0, "diff": "dusk", "lost_wick": 1}
	r.first_clear = true
	root.add_child(r)
	r._t = 10.0
	await _shot("results_lost_wick")
	r.queue_free()
	# The spark: 1-3 cleared, its secret not found.
	_hero(8)
	r = R.new()
	r.result = {"level": "1-3", "cleared": true, "embers": 40, "embers_total": 60, "sigils": [true, false, false], "time": 200.0,
			"relics": [], "items": [], "xp": 100, "levels": 0, "diff": "dusk"}
	r.first_clear = true
	root.add_child(r)
	r._t = 10.0
	await _shot("results_spark")
	r.queue_free()
	await process_frame


class StubMode:
	extends RefCounted
	var id := "descent"
	func pause_items() -> Array:
		return [{"label": "Rest here", "cb": func(): pass, "confirm": false},
				{"label": "Leave the Descent (costs a Spare Wick)", "cb": func(): pass, "confirm": true}]


func _pause() -> void:
	_hero(27)
	game.data["relics"] = ["tallow_heart", "rook_feather", "bellows", "moth_charm", "saints_knuckle"]
	game.hero()["belt"] = ["tallow_heart", "rook_feather", "bellows", "moth_charm"]
	var w := _world()
	await _shot("pause_base", 10)
	w.open_pause()
	await _shot("pause_belt", 6)
	w.pause_menu.close()
	w.mode = StubMode.new()
	w.open_pause()
	await _shot("pause_mode", 6)
	w.pause_menu._mode_item(1)
	await _shot("pause_mode_armed", 4)
	w.mode = null
	w.queue_free()
	await process_frame


func _title() -> void:
	var T = load("res://scripts/title_screen.gd")
	var Sv = load("res://scripts/saves_screen.gd")
	T.tales_path = "res://scripts/ui.gd"
	Sv.tales_path = "res://scripts/ui.gd"
	_hero(15)
	var t = T.new()
	root.add_child(t)
	await _shot("title", 30)
	t.queue_free()
	game.slot_base = "user://shots_save"
	game.save_path = game.slot_path(1)
	_hero(15)
	_clear(["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4", "3-1"])
	game.save()
	var sv = Sv.new()
	root.add_child(sv)
	await _shot("saves", 30)
	sv.queue_free()
	T.tales_path = T.TALES_SCREEN
	Sv.tales_path = Sv.TALES_SCREEN
	await process_frame
