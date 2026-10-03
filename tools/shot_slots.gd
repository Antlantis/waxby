# Screenshots of the saves screen, for checking by eye.
#   godot --path game --resolution 1266x585 --audio-driver Dummy \
#       --script res://../tools/shot_slots.gd -- <out_dir> [left|right|both|none]
# The safe area puts the phone's island inset on that side ("left" or
# "right"; "both" as iOS reports it, "none" plain margins). Files are
# <out_dir>/<W>x<H>_<safe>_<name>.png: empty (no saves yet), migrated (only
# slot 1, a v1 save migrated), three (three saves, slot 3's hero named
# Bartholomew), bad (a slot that can't be read), menu (a card's "..." menu),
# hold (the hold-to-confirm half held), undo (the Undo in the card just
# erased), hold_start_over (Start over asked while that Undo waits: the
# warning), title (the title after a save).
# The shots keep their own saves and settings (user://shot_slots/), so no
# real save is ever read or touched.
extends SceneTree

const DIR := "user://shot_slots"

var UI
var Progression
var SavesScript
var game: Node
var _out := "/tmp"
var _safe := "left"
var _tag := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	_safe = args[1] if args.size() > 1 else "left"
	DirAccess.make_dir_recursive_absolute(_out)
	UI = load("res://scripts/ui.gd")
	Progression = load("res://scripts/progression.gd")
	SavesScript = load("res://scripts/saves_screen.gd")
	await process_frame
	game = root.get_node("Game")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	game.settings_path = DIR + "/settings.json"
	game.slot_base = DIR + "/save"
	_wipe()
	game.save_path = game.slot_path(1)
	game.reset()
	await process_frame
	var vs: Vector2 = root.get_visible_rect().size
	UI.safe_override = _safe_rect(vs)
	var win := DisplayServer.window_get_size()
	_tag = "%dx%d_%s" % [win.x, win.y, _safe]
	print("view ", vs, " window ", win, " safe ", UI.safe_override)
	await _set_empty()
	await _set_migrated()
	await _set_three()
	await _set_bad()
	await _set_title()
	UI.safe_override = Rect2()
	_wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	print("done ", _tag)
	quit()


func _safe_rect(vs: Vector2) -> Rect2:
	var side := 55.0 * vs.y / 390.0
	match _safe:
		"left":
			return Rect2(side, 10.0, vs.x - side - 14.0, vs.y - 10.0 - 17.7)
		"right":
			return Rect2(14.0, 10.0, vs.x - side - 14.0, vs.y - 10.0 - 17.7)
		"none":
			return Rect2(14.0, 10.0, vs.x - 28.0, vs.y - 18.0)
	return UI.phone_safe(vs)


func _wipe() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)


# ---------------------------------------------------------------- helpers

func _wait(sec: float) -> void:
	await create_timer(sec).timeout
	await process_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var path := "%s/%s_%s.png" % [_out, _tag, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _clear() -> void:
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx":
			c.queue_free()
	await process_frame
	await process_frame


func _open() -> Control:
	var s: Control = SavesScript.new()
	root.add_child(s)
	await _wait(0.5)
	return s


func _played(n: int, ago_sec: int) -> void:
	## Sets when slot n was last played (its file says), as if ago_sec back.
	var p: String = game.slot_path(n)
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	d["saved_at"] = int(Time.get_unix_time_from_system()) - ago_sec
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()


func _clear_to(id: String, d := "dusk") -> void:
	## Every level up to and including id cleared on d, some sigils found.
	var kept: String = game.diff()
	game.data["difficulty"] = d
	for info in game.LEVELS:
		var i: int = game.index_of(str(info["id"]))
		game.record_result({"level": str(info["id"]), "cleared": true, "embers": 30, "time": 120.0 + i,
				"sigils": [true, i % 2 == 0, i % 3 == 0], "diff": d, "dread": false})
		if str(info["id"]) == id:
			break
	game.data["difficulty"] = kept if game.diff_open(kept) else "dusk"


func _slot(n: int, cls: String, level: int, upto: String, embers: int, more: Array = [], night := "") -> void:
	## A save in slot n: this calling at this level, every level up to upto
	## cleared (and on Nightfall up to night), more callings made too.
	game.new_game(n)
	for id in ["intro", "oath"]:
		game.mark_seen(id)
	for c in more:
		game.new_hero(c)
	game.new_hero(cls)
	if level > 1:
		game.add_xp(Progression.total_to(level) - int(game.hero()["xp"]))
	if upto != "":
		_clear_to(upto)
	if night != "":
		_clear_to(night, "nightfall")
	game.data["embers"] = embers
	game.save()


# ---------------------------------------------------------------- the sets

func _set_empty() -> void:
	await _clear()
	_wipe()
	game.save_path = game.slot_path(1)
	game.reset()
	await _open()
	await _shot("empty")


func _set_migrated() -> void:
	## The owner's case: only slot 1, the v1 save migrated at launch.
	await _clear()
	_wipe()
	var f := FileAccess.open(game.slot_path(1), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/v1_save.json"))
	f.close()
	game.save_path = game.slot_path(1)
	game.load_save()
	await _open()
	await _shot("migrated")
	# ... once the oath is sworn and a little played.
	await _clear()
	game.mark_seen("intro")
	game.mark_seen("oath")
	game.new_hero("knight")
	game.add_xp(Progression.total_to(3) - int(game.hero()["xp"]))
	_clear_to("1-2")
	_played(1, 40 * 60)
	game.load_save()
	await _open()
	await _shot("migrated_played")


func _set_three() -> void:
	await _clear()
	_wipe()
	_slot(1, "knight", 9, "2-2", 412, [])
	_played(1, 26 * 3600)
	_slot(3, "runner", 14, "2-4", 1375, ["knight", "witch"], "1-2")
	game.set_hero_name("Bartholomew")   # (a name as long as most get)
	_played(3, 5 * 86400)
	_slot(2, "witch", 4, "1-2", 96, [])
	_played(2, 12 * 60)
	game.load_save()
	var s: Control = await _open()
	await _shot("three")
	# The "..." menu of Save 2.
	s.open_menu(2)
	await _wait(0.2)
	await _shot("menu")
	# Erase: the hold, half held.
	s.ask("erase")
	await _wait(0.1)
	s._hold.held = true
	await _wait(0.55)
	s._hold.held = false
	s._hold.set_process(false)
	await _shot("hold")
	s._hold.set_process(true)
	s._hold.held = true
	await _wait(0.9)
	s._hold.held = false
	await _wait(1.2)
	await _shot("undo")
	# Start over asks the same way.
	s.open_menu(1)
	s.ask("start_over")
	await _wait(0.1)
	s._hold.held = true
	await _wait(0.4)
	s._hold.held = false
	s._hold.set_process(false)
	await _shot("hold_start_over")
	s._hold.set_process(true)
	s.close_menu()


func _set_bad() -> void:
	await _clear()
	_wipe()
	_slot(1, "founder", 6, "1-3", 230, [])
	_played(1, 3 * 3600)
	var f := FileAccess.open(game.slot_path(2), FileAccess.WRITE)
	f.store_string("{\"version\": 2, \"embers\": 12, \"heroes\": {\"kni")
	f.close()
	_slot(3, "sexton", 2, "", 18, [])
	game.use_slot(1)
	await _open()
	await _shot("bad")


func _set_title() -> void:
	## The title after a save was played: its hero, and which save.
	await _clear()
	_wipe()
	_slot(2, "witch", 7, "1-4", 300, [])
	game.use_slot(2)
	var t = load("res://scripts/title_screen.gd").new()
	root.add_child(t)
	await _wait(0.9)
	await _shot("title")
