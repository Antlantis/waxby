extends SceneTree
## Save slots: three saves, each a whole game of its own. Slot paths; the
## cards' summaries (empty, filled, a migrated v1 save, one that can't be
## read); a new game in slot 2 plays the intro and leaves slot 1 byte for
## byte; switching slots reads everything afresh (nothing leaks from the
## last one); erase and its undo; start over; the slot played last is
## remembered; the settings are shared; the saves screen (its layout on the
## phone either way round, the "..." menu, the hold-to-confirm, the Undo);
## the way through main (title, saves, back; a quick double tap on the
## title; the title after the slot being played is erased; a map only looked
## at); autoplay keeps its own save. Saves and settings are written whole or
## not at all, keep their last good file as .bak and fall back to it; the
## embers a level carries when the app is sent away are kept for the next
## load, per slot. Save v3: a v2 save migrates in any slot, each slot on its
## own (a v1 save only in slot 1), its v2 file kept as .v2; the owner's own
## slots (copies) come through whole. Every file lives in user://test_slots/:
## the real saves and settings are never read or written (checked byte for
## byte at the end).
##
##     godot --headless --path game --script res://tests/test_slots.gd

const DIR := "user://test_slots"
const FIXTURE := "res://tests/fixtures/v1_save.json"
const V2_FIXTURE := "res://tests/fixtures/v2_save.json"
const OWNER_1 := "res://tests/fixtures/owner_v2_save.json"     # copies of the owner's phone saves (2026-09-26)
const OWNER_2 := "res://tests/fixtures/owner_v2_save_2.json"
# His phone at 15:29 (backup 20260926-1529): slot 2 a Candleknight L7 with 6
# points unspent and a blank 2-4 record, slot 3 a Taperwitch L1 holding 24
# unbanked embers, each with its .bak; and after the feel lab (15:57) slots 1
# and 3 as the lab build wrote them, v3 already.
const OWNER_2_NOW := "res://tests/fixtures/owner_v2_save_2_1529.json"
const OWNER_3_NOW := "res://tests/fixtures/owner_v2_save_3_1529.json"
const OWNER_1_LAB := "res://tests/fixtures/owner_v3_lab_save.json"
const OWNER_3_LAB := "res://tests/fixtures/owner_v3_lab_save_3.json"
const DT := 1.0 / 60.0
# The player's own files: none of these may change.
const REAL := ["user://save.json", "user://save_2.json", "user://save_3.json", "user://settings.json",
		"user://autoplay_save.json", "user://autoplay_save_2.json", "user://autoplay_save_3.json", "user://playlog.json"]
const SUFFIXES := ["", ".erased", ".erased.bak", ".bad", ".tmp", ".bak", ".v1", ".v2"]

var UI
var Story
var Progression
var Cutscene: GDScript
var MainS: GDScript
var SavesS: GDScript
var TitleS: GDScript
var MapS: GDScript
var game: Node
var _passed := 0
var _failed := 0
var _real := {}                 # path -> its bytes, or null if it isn't there


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_snapshot_real()
	UI = load("res://scripts/ui.gd")
	Story = load("res://scripts/story.gd")
	Progression = load("res://scripts/progression.gd")
	Cutscene = load("res://scripts/cutscene.gd")
	MainS = load("res://scripts/main.gd")
	SavesS = load("res://scripts/saves_screen.gd")
	TitleS = load("res://scripts/title_screen.gd")
	MapS = load("res://scripts/map_screen.gd")
	game = root.get_node_or_null("Game")
	_check(game != null, "the Game autoload is there")
	if game == null:
		quit(1)
		return
	# Before Game's _ready: a save pointed elsewhere keeps its slots beside
	# it, so no real slot is ever opened.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_wipe()
	game.save_path = DIR + "/save.json"
	game.settings_path = DIR + "/settings.json"
	# The levels these flows play log their attempts here, not in the tuning playlog.
	var Playlog = load("res://scripts/playlog.gd")
	Playlog.path = DIR + "/playlog.json"
	await process_frame
	_check(game.slot_base == DIR + "/save", "a save pointed elsewhere at launch keeps its slots beside it (%s)" % game.slot_base)
	root.size = Vector2i(844, 390)
	root.content_scale_size = Vector2i(844, 390)
	UI.safe_override = UI.phone_safe(Vector2(844, 390))
	_test_paths()
	_test_empty_and_new()
	_test_filled_summary()
	_test_migrated()
	_test_migrate_v2_slots()
	_test_owner_slots()
	_test_owner_now()
	_test_switch_reloads()
	_test_v3_keys_per_slot()
	_test_unsaved_kept()
	_test_erase_undo()
	_test_start_over()
	_test_last_slot()
	_test_settings_shared()
	await _test_corrupt()
	_test_atomic()
	_test_backups()
	await _test_backup_only()
	_test_failed_write()
	await _test_unbanked()
	await _test_lab_writes_nothing()
	_test_texts()
	await _test_layout()
	await _test_screen()
	await _test_flow_new_game()
	await _test_flow_start_over()
	await _test_flow_corrupt()
	await _test_title_hero()
	await _test_double_tap()
	await _test_erase_current_back()
	await _test_look_only()
	_test_launch_purge()
	_test_autoplay()
	UI.safe_override = Rect2()
	_wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	load("res://scripts/playlog.gd").path = "user://playlog.json"
	_check_real()
	print("test_slots: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _snapshot_real() -> void:
	for p in REAL:
		for s in SUFFIXES:
			var path: String = p + s
			_real[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null


func _check_real() -> void:
	var changed: Array = []
	for path in _real:
		var now = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		if (now == null) != (_real[path] == null) or (now != null and now != _real[path]):
			changed.append(path)
	_check(changed.is_empty(), "no real save, slot or settings file was touched: %s" % [changed])


func _wipe() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		d.remove(sub)   # (the empty folders _test_failed_write puts where a side file goes)


func _fresh() -> void:
	## No slots at all, the settings empty, slot 1 open.
	_wipe()
	game.slot_base = DIR + "/save"
	game.settings_path = DIR + "/settings.json"
	game.save_path = game.slot_path(1)
	game.load_save()
	game.last_melt = {}
	SavesS._owed = 0


func _settle(s: Control) -> void:
	## Past the saves screen's opening guard and any calm after a hold, as a
	## moment's wait would be.
	s._t = maxf(s._t, 1.0)
	s._calm = 0.0
	s._lift = 0.0


func _key(code: Key) -> void:
	## A real key press and release.
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var u: InputEventKey = e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await process_frame
	await process_frame


func _bytes(n: int) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(game.slot_path(n)) if FileAccess.file_exists(game.slot_path(n)) else PackedByteArray()


func _exists(n: int, suffix := "") -> bool:
	return FileAccess.file_exists(game.slot_path(n) + suffix)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _on_disk(n: int) -> Dictionary:
	var p = JSON.parse_string(FileAccess.get_file_as_string(game.slot_path(n)))
	return p if p is Dictionary else {}


func _settings_file() -> Dictionary:
	var p = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path))
	return p if p is Dictionary else {}


func _result(id: String, sigils := [false, false, false]) -> Dictionary:
	return {"level": id, "cleared": true, "embers": 10, "embers_total": 20, "sigils": sigils,
		"time": 90.0, "relics": [], "items": [], "xp": 0, "levels": 0, "level_start": 1, "level_now": 1, "snuffs": 0,
		"diff": "dusk", "dread": false, "story_end": ""}


func _make(n: int, cls: String, level: int, upto: String, embers: int, more: Array = []) -> void:
	## A save in slot n, as if played: the story's opening seen, this calling
	## at this level (more callings made first), every level up to and
	## including upto cleared on Dusk, embers banked.
	game.new_game(n)
	game.mark_seen("intro")
	game.mark_seen("oath")
	for c in more:
		game.new_hero(c)
	game.new_hero(cls)
	if level > 1:
		game.add_xp(Progression.total_to(level) - int(game.hero()["xp"]))
	if upto != "":
		for info in game.LEVELS:
			var i: int = game.index_of(str(info["id"]))
			game.record_result(_result(str(info["id"]), [true, i % 2 == 0, false]))
			if str(info["id"]) == upto:
				break
	game.data["embers"] = embers
	game.save()


func _new_main() -> Node:
	var main: Node = MainS.new()
	root.add_child(main)
	await process_frame
	return main


func _is_scene(n: Node, id: String) -> bool:
	return n != null and n.get_script() == Cutscene and str(n.scene_id) == id


func _play_out(cs: Node, cls := "knight", steps := 4000) -> bool:
	## A scene played the way a player plays it: taps on the lines, and the
	## calling chosen by tapping its card twice (look, then choose).
	for i in steps:
		if not is_instance_valid(cs) or cs.finished:
			return true
		if cs.waiting == "class":
			if not cs._chooser.is_empty():
				for c in cs._chooser_cards():
					if c[0] == cls:
						cs._chooser_tap((c[1] as Rect2).get_center())
						if cs.waiting == "class":
							cs._chooser_tap((c[1] as Rect2).get_center())
			else:
				cs.pick(cls)
		elif i % 10 == 9:
			cs.tap()
		cs.advance(DT)
	return cs.finished


func _click(p: Vector2) -> void:
	## A real tap: a left press and release through Input, as the phone sends it.
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = p
	e.global_position = p
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var u: InputEventMouseButton = e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await process_frame
	await process_frame


func _press(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = p
	e.global_position = p
	e.pressed = down
	Input.parse_input_event(e)
	await process_frame


func _clear_root() -> void:
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx":
			c.queue_free()
	await process_frame
	await process_frame


func _inside(inner: Rect2, outer: Rect2, what: String, tol := 0.6) -> void:
	_check(inner.position.x >= outer.position.x - tol and inner.position.y >= outer.position.y - tol
			and inner.end.x <= outer.end.x + tol and inner.end.y <= outer.end.y + tol, "%s %s is inside %s" % [what, inner, outer])


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


# ---------------------------------------------------------------- paths

func _test_paths() -> void:
	_fresh()
	_check(game.slot_count() == 3, "three slots")
	_check(game.slot_path(1) == DIR + "/save.json" and game.slot_path(2) == DIR + "/save_2.json" and game.slot_path(3) == DIR + "/save_3.json",
			"slot n is <base>_n.json beside slot 1 (%s, %s, %s)" % [game.slot_path(1), game.slot_path(2), game.slot_path(3)])
	var kept: String = game.slot_base
	game.slot_base = "user://save"
	_check(game.slot_path(1) == game.SAVE_PATH, "slot 1 is the save there has always been, user://save.json")
	_check(game.slot_path(2) == "user://save_2.json" and game.slot_path(3) == "user://save_3.json", "slots 2 and 3 are user://save_2.json and save_3.json")
	game.slot_base = kept
	_check(game.current_slot() == 1, "slot 1 is being played")
	game.save_path = DIR + "/elsewhere.json"
	_check(game.current_slot() == 0, "a save somewhere else is no slot")
	game.save_path = game.slot_path(1)


# ---------------------------------------------------------------- summaries

func _test_empty_and_new() -> void:
	_fresh()
	for n in range(1, 4):
		_check(game.slot_summary(n).is_empty(), "slot %d is empty to begin with" % n)
		_check(not _exists(n), "and has no file")
	game.new_game(2)
	_check(_exists(2) and not _exists(1) and not _exists(3), "a new game in slot 2 makes save_2.json, and only that")
	_check(game.current_slot() == 2 and game.save_path == game.slot_path(2), "and plays slot 2")
	_check(int(_on_disk(2).get("version", 0)) == game.VERSION and int(_on_disk(2).get("veteran", -1)) == 0, "a fresh v%d save, no veteran" % game.VERSION)
	_check(not game.seen("intro") and game.heroes().is_empty() and game.embers() == 0, "nothing seen, no calling, no embers")
	var sm: Dictionary = game.slot_summary(2)
	_check(sm.get("slot") == 2 and sm.get("cls") == "" and sm.get("name") == "" and int(sm.get("callings", -1)) == 0,
			"its card: no calling yet (%s)" % [sm])
	_check(sm.get("furthest") == "1-1" and sm.get("furthest_title") == "The Nave", "the furthest open is 1-1 The Nave (%s %s)" % [sm.get("furthest"), sm.get("furthest_title")])
	_check(int(sm.get("bells", -1)) == 0 and int(sm.get("sigils", -1)) == 0 and int(sm.get("embers", -1)) == 0 and sm.get("diffs") == ["dusk"],
			"no bells, sigils or embers; Dusk open")
	_check(int(sm.get("played", 0)) > 0 and absi(int(sm["played"]) - int(Time.get_unix_time_from_system())) < 30, "played just now")
	_check(int(_settings_file().get("last_slot", 0)) == 2 and game.last_slot() == 2, "the settings remember slot 2 as the last played")


func _test_filled_summary() -> void:
	_fresh()
	_make(2, "knight", 9, "2-2", 412)
	_make(3, "runner", 5, "1-1", 30, ["knight", "witch"])
	var sm: Dictionary = game.slot_summary(2)
	_check(sm.get("cls") == "knight" and sm.get("name") == "Candleknight" and int(sm.get("level", 0)) == 9,
			"a filled card: Candleknight, level 9 (%s %s %s)" % [sm.get("cls"), sm.get("name"), sm.get("level")])
	_check(sm.get("furthest") == "2-3" and sm.get("furthest_title") == "The Moth Garden", "the furthest open: 2-3 The Moth Garden (%s %s)" % [sm.get("furthest"), sm.get("furthest_title")])
	_check(int(sm.get("bells", 0)) == 6, "six bells rung (%s)" % sm.get("bells"))
	_check(int(sm.get("sigils", 0)) == 9, "nine sigils (every level's first, every other's second): %s" % sm.get("sigils"))
	_check(int(sm.get("embers", 0)) == 412 and int(sm.get("callings", 0)) == 1, "412 embers, one calling")
	var s3: Dictionary = game.slot_summary(3)
	_check(s3.get("cls") == "runner" and int(s3.get("callings", 0)) == 3 and s3.get("furthest") == "1-2", "slot 3: a Sootrunner of three callings, 1-2 open (%s)" % [s3])
	_check(game.current_slot() == 3, "(slot 3 is the one being played)")
	# Read from the file, not memory: the same card.
	game.use_slot(1)
	var again: Dictionary = game.slot_summary(2)
	_check(again.get("cls") == "knight" and int(again.get("level", 0)) == 9 and again.get("furthest") == "2-3" and int(again.get("embers", 0)) == 412,
			"a slot not being played reads the same from its file")
	_check(game.slot_summary(1).is_empty(), "slot 1 is still empty (use_slot of an empty slot writes nothing)")
	_check(not _exists(1), "no file for it")
	# A Nightfall run opens a second difficulty on the card.
	game.use_slot(2)
	game.data["unlocked"]["nightfall"] = 2
	game.save()
	_check(game.slot_summary(2).get("diffs") == ["dusk", "nightfall"], "the difficulties open (%s)" % [game.slot_summary(2).get("diffs")])


func _test_migrated() -> void:
	## The owner's case: a v1 save.json in slot 1, only.
	_fresh()
	if not FileAccess.file_exists(FIXTURE):
		_check(false, "the v1 fixture is there")
		return
	var v1 := FileAccess.get_file_as_string(FIXTURE)
	_write(game.slot_path(1), v1)
	game.set_setting("haptics", true)
	game.save_path = game.slot_path(2)   # slot 1 not open yet: its card is read from the file
	game.load_save()
	var sm: Dictionary = game.slot_summary(1)
	_check(not sm.is_empty() and not sm.get("bad", false), "a v1 save in slot 1 is a save (%s)" % [sm])
	_check(int(sm.get("veteran", 0)) == 4 and int(sm.get("embers", 0)) == 212 + 150 and sm.get("cls") == "", "its card: a veteran, 362 embers, no calling yet (%s)" % [sm])
	_check(sm.get("furthest") == "2-1", "its v1 unlocks: 2-1 open (%s)" % sm.get("furthest"))
	_check(int(sm.get("played", 0)) > 0, "played: the file's time")
	_check(FileAccess.get_file_as_string(game.slot_path(1)) == v1, "reading the card writes nothing")
	var sv: Control = SavesS.new()
	root.add_child(sv)
	_check(sv.loss_line(1) == "Erases Save 1: veteran, no calling yet, 2-1, 362 embers", "what an erase of it takes names the veteran and embers: %s" % sv.loss_line(1))
	sv.free()
	_check(bool(game.setting("haptics")), "and leaves the settings alone (the v1 haptics move only when it's played)")
	for n in [2, 3]:
		_check(game.slot_summary(n).is_empty(), "slot %d is empty beside it" % n)
	game.use_slot(1)
	_check(game.veteran() == 4 and game.embers() == 362 and game.unlocked_count("dusk") == 5, "played, slot 1 migrates as before")
	_check(int(_on_disk(1).get("version", 0)) == game.VERSION, "and is written back as v%d (v1 -> v2 -> v3)" % game.VERSION)
	_check(FileAccess.get_file_as_string(game.slot_path(1) + ".v1") == v1, "its v1 file kept beside it as .v1")
	_check(not bool(game.setting("haptics")), "its haptics moved to the settings")
	game.set_setting("haptics", true)
	# A v1 file anywhere but slot 1 is never migrated.
	_write(game.slot_path(3), v1)
	var s3: Dictionary = game.slot_summary(3)
	_check(s3.get("bad", false), "a v1 save in slot 3 isn't read as one (%s)" % [s3])
	_check(_exists(3, ".bad"), "(a copy is kept aside, as for any save that can't be read)")
	game.use_slot(3)
	_check(game.veteran() == 0 and game.embers() == 0 and game.heroes().is_empty(), "played, slot 3 starts fresh: no veteran")
	_check(FileAccess.get_file_as_string(game.slot_path(3)) == v1, "and its file is left as it was until something saves")
	# A new game in slot 1 is a fresh save too.
	game.new_game(1)
	_check(game.veteran() == 0 and game.embers() == 0 and int(_on_disk(1).get("veteran", -1)) == 0, "a new game in slot 1 is fresh: veteran 0")


func _furthest_built(unlocked: int) -> Dictionary:
	## The level a card names as the furthest open with this many unlocked:
	## the last one built within them ({id, world}). 2-4 in a W1-W2 build,
	## 3-1 once it's there.
	var lv: Array = game.LEVELS
	var far := mini(unlocked, lv.size())
	return {"id": str(lv[far - 1]["id"]), "world": int(lv[far - 1]["world"])} if far > 0 else {"id": "", "world": 1}


func _test_migrate_v2_slots() -> void:
	## Save v3 (contract §8.2): a v2 save migrates in whichever slot it's in,
	## each slot on its own. Its card reads it without writing; played, it's
	## v3 with the v2 file kept as .v2 (and as .bak till the next save); the
	## other slots aren't touched; it loads again unchanged; erase and Undo
	## keep it whole; a v2 save with only its .bak, or junk with a v2 .bak,
	## migrates from the backup.
	var v2 := FileAccess.get_file_as_string(V2_FIXTURE)
	_check(v2 != "", "the v2 fixture is there")
	if v2 == "":
		return
	for n in [1, 2, 3]:
		_fresh()
		var other := 2 if n == 1 else 1
		_make(other, "knight", 3, "1-1", 44)
		var other_bytes := _bytes(other)
		_write(game.slot_path(n), v2)
		var sm: Dictionary = game.slot_summary(n)
		_check(not sm.is_empty() and not sm.get("bad", false) and sm.get("cls") == "knight" and int(sm.get("level", 0)) == 25 and int(sm.get("callings", 0)) == 2
				and int(sm.get("embers", 0)) == 1234, "slot %d: a v2 save is a save to its card (%s)" % [n, sm])
		var far := _furthest_built(9)
		_check(sm.get("furthest") == far["id"] and sm.get("diffs") == ["dusk"] and int(sm.get("world", 0)) == int(far["world"]),
				"slot %d: its card shows it as v3 will: %s (3-1 once it's built), Dusk (Nightfall waits)" % [n, far["id"]])
		_check(FileAccess.get_file_as_string(game.slot_path(n)) == v2 and not _exists(n, ".v2"), "slot %d: reading the card writes nothing" % n)
		game.use_slot(n)
		_check(int(_on_disk(n).get("version", 0)) == 3 and game.current_slot() == n, "slot %d: played, it's written back as v3" % n)
		_check(FileAccess.get_file_as_string(game.slot_path(n) + ".v2") == v2 and FileAccess.get_file_as_string(game.slot_path(n) + ".bak") == v2,
				"slot %d: the v2 file is kept as .v2, and as its .bak" % n)
		_check(game.unlocked_count("dusk") == 9 and game.diff() == "dusk" and game.unlocked_count("nightfall") == 0 and game.diff_waits("nightfall")
				and game.embers() == 1234 and game.has_hero("knight") and game.has_hero("runner"), "slot %d: migrated (9 open, Dusk, Nightfall waits, 1,234 embers, both callings)" % n)
		_check(_bytes(other) == other_bytes, "slot %d: the slot beside it isn't touched" % n)
		var third: int = 6 - int(n) - other
		_check(game.slot_summary(third).is_empty() and not _exists(third), "slot %d: the third stays empty" % n)
		var t1 := FileAccess.get_file_as_string(game.slot_path(n))
		game.use_slot(other)
		game.use_slot(n)
		_check(FileAccess.get_file_as_string(game.slot_path(n)) == t1 and game.embers() == 1234, "slot %d: it loads again unchanged (and isn't written)" % n)
		game.use_slot(other)
		_check(game.erase_slot(n) and game.slot_summary(n).is_empty() and game.restore_slot(n) and FileAccess.get_file_as_string(game.slot_path(n)) == t1,
				"slot %d: erased and undone, the migrated save comes back whole" % n)
		_check(FileAccess.get_file_as_string(game.slot_path(n) + ".v2") == v2, "slot %d: (the .v2 file stays as it was)" % n)
		game._purge_erased()
	# Only the backup left: it migrates from that.
	_fresh()
	_write(game.slot_path(2) + ".bak", v2)
	_check(game.slot_summary(2).get("cls") == "knight", "a v2 save with only its .bak left: its card reads the backup")
	game.use_slot(2)
	_check(game.embers() == 1234 and int(_on_disk(2).get("version", 0)) == 3 and FileAccess.get_file_as_string(game.slot_path(2) + ".v2") == v2,
			"played: the backup is the save again, migrated, and kept as .v2")
	# Junk over a v2 backup: the backup, migrated; the junk kept aside.
	_fresh()
	var junk := "{\"version\": 3, \"embers\": 5, \"her"
	_write(game.slot_path(3), junk)
	_write(game.slot_path(3) + ".bak", v2)
	game.use_slot(3)
	_check(game.embers() == 1234 and game.diff_waits("nightfall") and FileAccess.get_file_as_string(game.slot_path(3) + ".bad") == junk,
			"a save that can't be read over a v2 backup: the backup's game, migrated; the junk kept as .bad")
	_check(FileAccess.get_file_as_string(game.slot_path(3) + ".bak") == v2 and int(_on_disk(3).get("version", 0)) == 3, "and the good backup isn't written over with the junk")
	# Three v2 saves: each migrates when it's played, the others wait as they are.
	_fresh()
	for n in [1, 2, 3]:
		_write(game.slot_path(n), v2.replace("\"embers\": 1234", "\"embers\": %d" % (100 * n)))
	game.use_slot(1)
	_check(game.embers() == 100 and int(_on_disk(1).get("version", 0)) == 3 and int(_on_disk(2).get("version", 0)) == 2 and int(_on_disk(3).get("version", 0)) == 2,
			"three v2 slots: playing slot 1 migrates slot 1 only")
	_check(int(game.slot_summary(2).get("embers", 0)) == 200 and int(_on_disk(2).get("version", 0)) == 2, "slot 2's card reads its v2 save (200 embers) and leaves it v2")
	game.use_slot(2)
	game.use_slot(3)
	_check(game.embers() == 300 and int(_on_disk(2).get("version", 0)) == 3 and int(_on_disk(3).get("version", 0)) == 3
			and int(_on_disk(1).get("embers", 0)) == 100 and int(_on_disk(2).get("embers", 0)) == 200, "then each in turn, its own embers (100 / 200 / 300)")
	# A v1 save still migrates only in slot 1.
	var v1 := FileAccess.get_file_as_string(FIXTURE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.slot_path(2) + ".bak"))
	_write(game.slot_path(2), v1)
	_check(game.slot_summary(2).get("bad", false) and FileAccess.get_file_as_string(game.slot_path(2) + ".bad") == v1,
			"a v1 save in slot 2 still can't be read (only slot 1 had v1), and is kept as .bad")


func _test_owner_slots() -> void:
	## The owner's phone as it was on 2026-09-26 (copies): slot 1 his game (a
	## Taperwitch L18 and a Sootrunner L15, 2,204 embers, all 8 Dusk levels
	## and 5 Nightfall levels cleared, played on Nightfall), slot 2 a fresh
	## game, the settings on slot 2.
	var s1 := FileAccess.get_file_as_string(OWNER_1)
	var s2 := FileAccess.get_file_as_string(OWNER_2)
	_check(s1 != "" and s2 != "", "the copies of the owner's saves are there")
	if s1 == "" or s2 == "":
		return
	_fresh()
	_write(game.slot_path(1), s1)
	_write(game.slot_path(2), s2)
	game.set_setting("last_slot", 2)
	var c1: Dictionary = game.slot_summary(1)
	var c2: Dictionary = game.slot_summary(2)
	_check(c1.get("cls") == "witch" and int(c1.get("level", 0)) == 18 and int(c1.get("callings", 0)) == 2 and int(c1.get("embers", 0)) == 2204
			and int(c1.get("bells", 0)) == 15 and c1.get("furthest") == _furthest_built(9)["id"] and c1.get("diffs") == ["dusk"], "his slot 1's card: the Taperwitch L18, 2,204 embers (%s)" % [c1])
	_check(not c2.is_empty() and not c2.get("bad", false) and c2.get("cls") == "" and int(c2.get("callings", -1)) == 0, "his slot 2's card: a fresh game")
	_check(FileAccess.get_file_as_string(game.slot_path(1)) == s1 and FileAccess.get_file_as_string(game.slot_path(2)) == s2 and game.last_slot() == 2,
			"reading the cards writes nothing; slot 2 was played last")
	game.use_slot(2)
	_check(int(_on_disk(2).get("version", 0)) == 3 and game.heroes().is_empty() and FileAccess.get_file_as_string(game.slot_path(1)) == s1,
			"slot 2 opens as a fresh v3 game; slot 1 is still his v2 file")
	game.use_slot(1)
	_check(int(_on_disk(1).get("version", 0)) == 3 and FileAccess.get_file_as_string(game.slot_path(1) + ".v2") == s1, "slot 1 played: v3, his v2 file kept as .v2")
	_check(game.embers() == 2204 and game.hero_id() == "witch" and int(game.hero()["level"]) == 18 and int(game.heroes()["runner"]["level"]) == 15
			and (game.data["relics"] as Array).size() == 12 and game.bells() == 15, "his heroes, embers, relics and bells")
	var sig := 0
	var was: Dictionary = JSON.parse_string(s1)
	for dd in was["levels"]:
		for id in was["levels"][dd]:
			for s in was["levels"][dd][id]["sigils"]:
				sig += 1 if s else 0
	_check(game.sigil_count("all") == sig and (game.data["levels"]["nightfall"] as Dictionary).size() == 5 and (game.data["levels"]["dusk"] as Dictionary).size() == 8,
			"every record and sigil (%d)" % sig)
	_check(game.diff() == "dusk" and not game.diff_open("nightfall") and game.diff_waits("nightfall") and not game.relock_card().is_empty(),
			"Dusk; Nightfall waits beneath the Hush, and its card is owed")
	var t1 := FileAccess.get_file_as_string(game.slot_path(1))
	game.use_slot(2)
	game.use_slot(1)
	_check(FileAccess.get_file_as_string(game.slot_path(1)) == t1 and game.embers() == 2204, "back and forth: his game is as it was")


func _test_owner_now() -> void:
	## His phone as it is now (copies): the 15:29 slots 2 and 3 (v2), and the
	## slots 1 and 3 the feel-lab build wrote (v3). Each slot on its own: a v2
	## one migrates once (its v2 file kept as .v2, its .bak left as it was)
	## and reloads unchanged; slot 3's 24 unbanked embers join its purse once;
	## a v3 one loads as it is and isn't written. None owes the_pull (World 3
	## isn't built) or the new-points card (no Vigil ranks came back).
	var files := [[2, OWNER_2_NOW], [3, OWNER_3_NOW]]
	for f in files:
		if FileAccess.get_file_as_string(str(f[1])) == "":
			_check(false, "the copy %s is there" % str(f[1]).get_file())
			return
	_fresh()
	for f in files:
		_write(game.slot_path(int(f[0])), FileAccess.get_file_as_string(str(f[1])))
		_write(game.slot_path(int(f[0])) + ".bak", FileAccess.get_file_as_string(str(f[1]) + ".bak"))
	var s2 := FileAccess.get_file_as_string(OWNER_2_NOW)
	var s3 := FileAccess.get_file_as_string(OWNER_3_NOW)
	game.use_slot(2)
	var k: Dictionary = game.heroes().get("knight", {})
	_check(int(_on_disk(2).get("version", 0)) == 3 and FileAccess.get_file_as_string(game.slot_path(2) + ".v2") == s2
			and FileAccess.get_file_as_string(game.slot_path(3)) == s3, "slot 2 (15:29) migrates on its own, its v2 file kept as .v2; slot 3 untouched")
	_check(int(k.get("level", 0)) == 7 and int(k.get("points", -1)) == 6 and int(k.get("vigil", -1)) == 0 and game.embers() == 202,
			"his Candleknight L7 keeps its 6 unspent points and 202 embers")
	_check(game.points_back() == 0 and not game.seen("the_pull") and not bool(game.level_record("2-4", "dusk")["cleared"]),
			"no Vigil ranks came back (no new-points card); 2-4 not cleared, the_pull not owed")
	var t2 := FileAccess.get_file_as_string(game.slot_path(2))
	game.load_save()
	_check(FileAccess.get_file_as_string(game.slot_path(2)) == t2, "slot 2 reloads unchanged, and isn't written")
	game.use_slot(3)
	_check(int(_on_disk(3).get("version", 0)) == 3 and FileAccess.get_file_as_string(game.slot_path(3) + ".v2") == s3, "slot 3 (15:29) migrates on its own")
	_check(game.embers() == 24 and game.unbanked() == 0 and int(_on_disk(3).get("unbanked", -1)) == 0 and int(_on_disk(3).get("embers", 0)) == 24,
			"its 24 unbanked embers join the purse, once (%d)" % game.embers())
	var t3 := FileAccess.get_file_as_string(game.slot_path(3))
	game.load_save()
	_check(game.embers() == 24 and FileAccess.get_file_as_string(game.slot_path(3)) == t3, "a second load adds nothing and writes nothing")
	game.use_slot(2)
	_check(FileAccess.get_file_as_string(game.slot_path(2)) == t2 and FileAccess.get_file_as_string(game.slot_path(2) + ".v2") == s2,
			"back to slot 2: as it was")
	# The slots the feel-lab build wrote: v3 already.
	_fresh()
	var l1 := FileAccess.get_file_as_string(OWNER_1_LAB)
	var l3 := FileAccess.get_file_as_string(OWNER_3_LAB)
	_check(l1 != "" and l3 != "", "the lab build's slots 1 and 3 are there")
	if l1 == "" or l3 == "":
		return
	_write(game.slot_path(1), l1)
	_write(game.slot_path(3), l3)
	game.use_slot(1)
	_check(FileAccess.get_file_as_string(game.slot_path(1)) == l1 and not FileAccess.file_exists(game.slot_path(1) + ".v2"),
			"his v3 slot 1 (the lab build's) loads as it is: not migrated, not written")
	_check(game.hero_id() == "witch" and int(game.hero()["level"]) == 18 and int(game.heroes()["runner"]["level"]) == 15
			and (game.data["relics"] as Array).size() == 12 and game.unlocked_count("dusk") == 9 and int(game.data["relocked"].get("nightfall", 0)) == 6,
			"its heroes, relics, unlocks and the Nightfall kept aside")
	_check(game.points_back() == 0 and not game.seen("the_pull"), "nothing owed: no new-points card, no the_pull in a build without World 3")
	game.use_slot(3)
	_check(FileAccess.get_file_as_string(game.slot_path(3)) == l3 and game.embers() == 24 and game.unbanked() == 0,
			"his v3 slot 3 (the lab build's): as written, 24 embers in the purse")


# ---------------------------------------------------------------- switching

func _test_switch_reloads() -> void:
	_fresh()
	# Slot 1: a Candleknight far along, relics, the Chandler met, runs made.
	_make(1, "knight", 8, "1-4", 500)
	for id in ["tallow_heart", "rook_feather", "bellows"]:
		game.grant_relic(id)
	game.mark_seen("meet_waxley")
	game.mark_seen("bark:first_hurt")
	game.data["run_counter"] = 7
	game.data["unlocked"]["nightfall"] = 1
	game.set_diff("nightfall")
	game.wares()
	game.save()
	game.load_save()
	var stock1: String = JSON.stringify(game.wares())
	var relics1: Array = (game.data["relics"] as Array).duplicate()
	# Slot 2: a Taperwitch just begun.
	_make(2, "witch", 2, "", 20)
	game.data["run_counter"] = 1
	game.wares()
	game.save()
	game.load_save()
	var stock2: String = JSON.stringify(game.wares())
	game.last_melt = {"for": "x", "item": {}, "embers": 3, "old": false}
	game.use_slot(1)
	_check(game.current_slot() == 1 and game.hero_id() == "knight" and int(game.hero()["level"]) == 8 and not game.has_hero("witch"),
			"slot 1: its Candleknight, level 8, and no Taperwitch")
	_check(game.embers() == 500 and game.has_relic("tallow_heart") and game.has_relic("bellows") and game.data["relics"] == relics1,
			"its embers and relics (%s)" % [game.data["relics"]])
	_check(game.unlocked_count("dusk") == 5 and game.diff() == "nightfall" and game.diff_open("nightfall"), "its unlocks and difficulty")
	_check(game.seen("meet_waxley") and Story.bark_heard("first_hurt"), "its story seen, barks heard")
	_check(int(game.data["run_counter"]) == 7 and JSON.stringify(game.wares()) == stock1, "its run counter and the Chandler's stock")
	_check(game.last_melt.is_empty(), "the last melt (from slot 2) is forgotten")
	game.use_slot(2)
	_check(game.current_slot() == 2 and game.hero_id() == "witch" and not game.has_hero("knight") and game.heroes().size() == 1,
			"slot 2: only its Taperwitch")
	_check(game.embers() == 20 and (game.data["relics"] as Array).is_empty() and game.belt().is_empty(), "none of slot 1's embers or relics")
	_check(game.unlocked_count("dusk") == 1 and game.diff() == "dusk" and not game.diff_open("nightfall"), "none of its unlocks")
	_check(not game.seen("meet_waxley") and not Story.bark_heard("first_hurt"), "none of its story or barks")
	_check(int(game.data["run_counter"]) == 1 and JSON.stringify(game.wares()) == stock2, "its own run counter and stock")
	_check(game.sigil_count("all") == 0 and game.bells() == 0 and game.level_record("1-1", "dusk")["cleared"] == false, "no records from slot 1")
	# An empty slot: nothing at all carried in.
	game.use_slot(3)
	_check(game.heroes().is_empty() and game.embers() == 0 and game.data["seen"].is_empty() and game.bells() == 0,
			"an empty slot: nothing carried over")
	_check(game.hero()["cls"] == "knight" and int(game.hero()["level"]) == 1 and game.belt().is_empty(), "(the stand-in hero is a fresh one)")
	_check(not _exists(3), "and no file made for it")
	# The title shows the hero of the slot being played.
	game.use_slot(1)
	var t: Control = TitleS.new()
	root.add_child(t)
	_check(str(t._who) == "Save 1 · Candleknight · Level 8" and str(t._cls) == "knight", "the title: %s" % t._who)
	t.free()
	game.use_slot(2)
	t = TitleS.new()
	root.add_child(t)
	_check(str(t._who) == "Save 2 · Taperwitch · Level 2" and str(t._cls) == "witch", "then: %s" % t._who)
	t.free()


func _test_v3_keys_per_slot() -> void:
	## Phase 1's save keys stay in their own slot: the boss count, the
	## draughts, and a hero's Waxley's Reserve (stocked from depth 23).
	_fresh()
	_make(1, "knight", 25, "", 3000)
	game.hero()["deepest"] = 24
	game.data["bosses"] = 2
	game.grant_draught("rich")
	var r: Dictionary = game.reserve()
	_check(r.get("item") is Dictionary, "slot 1: a deep hero's Reserve is stocked")
	var uid: String = str(r["item"]["uid"]) if r.get("item") is Dictionary else ""
	game.save()
	_make(2, "witch", 3, "", 10)
	_check(int(game.data["bosses"]) == 0 and not bool(game.data["flask"]["rich"]) and game.reserve().is_empty() and not game.hero().has("reserve"),
			"slot 2: no boss count, no Rich Draught, no Reserve")
	game.use_slot(1)
	_check(int(game.data["bosses"]) == 2 and bool(game.data["flask"]["rich"]) and game.reserve().get("item") is Dictionary
			and str(game.reserve()["item"]["uid"]) == uid, "slot 1 again: its boss count, its Rich Draught, the same Reserve")
	var b1 := _bytes(1)
	var b2 := _bytes(2)
	game.use_slot(2)
	game.use_slot(1)
	_check(_bytes(1) == b1 and _bytes(2) == b2, "and looking at them writes nothing")


func _test_unsaved_kept() -> void:
	## Embers picked up in a level left early wait in memory for the next
	## save: switching slots writes them first, into their own slot only.
	_fresh()
	_make(1, "knight", 3, "", 100)
	_make(2, "witch", 3, "", 50)
	var b1 := _bytes(1)
	game.add_embers(7)
	game.use_slot(1)
	_check(int(_on_disk(2).get("embers", 0)) == 57, "slot 2's unsaved embers are written as it's left (%s)" % _on_disk(2).get("embers"))
	_check(game.embers() == 100 and _bytes(1) == b1, "and slot 1 is read untouched")
	var b2 := _bytes(2)
	game.use_slot(2)
	game.use_slot(1)
	_check(_bytes(2) == b2 and _bytes(1) == b1, "nothing changed: switching writes nothing")


# ---------------------------------------------------------------- erase

func _test_erase_undo() -> void:
	_fresh()
	_make(1, "knight", 4, "1-2", 90)
	_make(2, "witch", 6, "1-3", 120)
	_make(3, "runner", 2, "", 10)
	game.use_slot(1)
	var b2 := _bytes(2)
	var b3 := _bytes(3)
	_check(game.erase_slot(2), "erase slot 2")
	_check(not _exists(2) and _exists(2, ".erased") and game.slot_summary(2).is_empty(), "slot 2 is empty; its file kept aside as .erased")
	_check(game.can_restore(2) and not game.can_restore(3), "its erase can be undone (only its)")
	_check(game.current_slot() == 1 and game.hero_id() == "knight" and _bytes(3) == b3, "the slot being played, and slot 3, are untouched")
	_check(game.restore_slot(2), "undo")
	_check(_exists(2) and not _exists(2, ".erased") and _bytes(2) == b2, "slot 2 is back byte for byte")
	_check(not game.can_restore(2) and not game.restore_slot(2), "an undo is undone once")
	# One step: the next erase lets the last one go.
	game.erase_slot(2)
	game.erase_slot(3)
	_check(not _exists(2, ".erased") and _exists(3, ".erased"), "the next erase lets the last one go for good")
	_check(not game.can_restore(2) and game.can_restore(3), "only the last erase can be undone")
	_check(game.restore_slot(3) and _bytes(3) == b3, "slot 3 back")
	_check(not game.erase_slot(2), "an empty slot can't be erased")
	# The slot being played: what's in memory goes too.
	_check(game.erase_slot(1), "erase the slot being played")
	_check(game.heroes().is_empty() and game.embers() == 0 and not game.seen("intro"), "its heroes, embers and story leave memory too")
	_check(not _exists(1), "and no save brings it back behind the Undo's back")
	game.use_slot(1)
	_check(not _exists(1) and game.can_restore(1), "(picking the empty slot writes nothing, the undo still there)")
	_check(game.restore_slot(1) and game.hero_id() == "knight" and int(game.hero()["level"]) == 4, "undone: it's read again")
	# A restore never writes over a slot filled since.
	game.erase_slot(3)
	game.new_game(3)
	_check(not game.can_restore(3) and not game.restore_slot(3), "a slot begun again can't be restored over")
	# Quitting the app lets it go.
	_check(game.erase_slot(1) and _exists(1, ".erased"), "(slot 1 erased)")
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(not _exists(1, ".erased") and not game.can_restore(1), "the app's quit lets the erase go")


func _test_start_over() -> void:
	_fresh()
	_make(1, "knight", 5, "1-3", 200)
	_make(2, "founder", 7, "2-1", 300, ["witch"])
	var b1 := _bytes(1)
	game.use_slot(2)
	game.new_game(2)
	_check(game.current_slot() == 2 and game.heroes().is_empty() and game.embers() == 0 and not game.seen("intro")
			and game.bells() == 0 and (game.data["relics"] as Array).is_empty() and game.veteran() == 0,
			"start over: slot 2 begins again, nothing kept")
	_check(_exists(2) and int(_on_disk(2).get("embers", -1)) == 0 and (_on_disk(2).get("heroes", {}) as Dictionary).is_empty(), "its file is a fresh save")
	_check(_bytes(1) == b1, "slot 1 untouched")
	_check(int(_settings_file().get("last_slot", 0)) == 2, "slot 2 is the last played")


# ---------------------------------------------------------------- last slot, settings

func _test_last_slot() -> void:
	_fresh()
	_make(1, "knight", 2, "", 1)
	_make(3, "sexton", 3, "", 2)
	game.use_slot(1)
	game.use_slot(3)
	_check(int(_settings_file().get("last_slot", 0)) == 3, "the settings file remembers slot 3")
	game.reload_settings()
	_check(game.last_slot() == 3, "read back: slot 3")
	# The next launch opens it (a second Game, as the app would start).
	var g2: Node = load("res://scripts/game_state.gd").new()
	g2.settings_path = game.settings_path
	g2.slot_base = game.slot_base
	g2.save_path = g2.SAVE_PATH
	g2._pick_slot(false)
	g2.load_save()
	_check(g2.save_path == game.slot_path(3) and g2.hero_id() == "sexton", "the next launch opens slot 3 (%s)" % g2.save_path)
	g2.free()
	# That slot erased: the save played most recently of those left.
	_make(2, "witch", 2, "", 3)
	game.use_slot(3)
	var d1 := _on_disk(1)
	d1["saved_at"] = int(Time.get_unix_time_from_system()) - 3600
	_write(game.slot_path(1), JSON.stringify(d1))
	var d2 := _on_disk(2)
	d2["saved_at"] = int(Time.get_unix_time_from_system()) - 7200
	_write(game.slot_path(2), JSON.stringify(d2))
	game.erase_slot(3)
	_check(game.last_slot() == 1, "slot 3 erased: slot 1, played an hour ago, stands in (%d)" % game.last_slot())
	game.restore_slot(3)
	_check(game.last_slot() == 3, "restored: slot 3 again")
	_fresh()
	_check(game.last_slot() == 1, "no saves, no setting: slot 1")


func _test_settings_shared() -> void:
	_fresh()
	_make(1, "knight", 2, "", 0)
	_make(2, "witch", 2, "", 0)
	game.use_slot(1)
	game.set_setting("candle_strength", "strong")
	game.haptics = false
	game.use_slot(2)
	_check(str(game.setting("candle_strength")) == "strong" and not game.haptics, "slot 2 has the settings set in slot 1")
	game.set_setting("shake", 0.5)
	game.use_slot(1)
	_check(is_equal_approx(float(game.setting("shake")), 0.5), "and slot 1 the ones set in slot 2")
	game.new_game(2)
	_check(str(game.setting("candle_strength")) == "strong" and is_equal_approx(float(game.setting("shake")), 0.5), "a new game keeps the settings")
	for n in [1, 2]:
		var d := _on_disk(n)
		_check(not d.has("haptics") and not d.has("candle_strength") and not d.has("last_slot"), "slot %d's save holds no settings" % n)
	game.haptics = true


# ---------------------------------------------------------------- a save that can't be read

func _test_corrupt() -> void:
	_fresh()
	_make(1, "knight", 3, "1-1", 44)
	var junk := "{\"version\": 2, \"embers\": 12, \"heroes\": {\"kni"
	_write(game.slot_path(2), junk)
	game.use_slot(1)
	var sm: Dictionary = game.slot_summary(2)
	_check(sm.get("bad", false) and int(sm.get("slot", 0)) == 2, "a slot that can't be read says so (%s)" % [sm])
	_check(_exists(2, ".bad") and FileAccess.get_file_as_string(game.slot_path(2) + ".bad") == junk, "a copy is kept beside it as .bad, as today")
	var s: Control = SavesS.new()
	root.add_child(s)
	await process_frame
	await process_frame
	_check(s.summary(2).get("bad", false) and s.loss_line(2) == "Erases Save 2 (it couldn't be read)", "its card: couldn't be read")
	_check(s._dots[1].visible, "and it can still be erased")
	s.free()
	game.use_slot(2)
	_check(game.current_slot() == 2 and game.heroes().is_empty() and game.embers() == 0, "played: a fresh save, no crash")
	_check(FileAccess.get_file_as_string(game.slot_path(2)) == junk, "the file isn't written over until something saves")
	game.use_slot(1)
	_check(FileAccess.get_file_as_string(game.slot_path(2)) == junk, "nor by leaving it")
	_check(game.erase_slot(2) and game.slot_summary(2).is_empty(), "erased: the slot is empty")


func _test_atomic() -> void:
	_fresh()
	_make(1, "knight", 2, "", 5)
	game.save()
	game.set_setting("numbers", "on")
	_check(not FileAccess.file_exists(game.slot_path(1) + ".tmp") and not FileAccess.file_exists(game.settings_path + ".tmp"),
			"saves and settings are written to a side file and moved over (none left behind)")


# ---------------------------------------------------------------- backups and failed writes

func _mkdir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _rmdir(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_backups() -> void:
	## Every slot keeps the save a write replaces as <save>.bak, and a save
	## that goes missing or can't be read comes back from it (the card too).
	## Slot 1's v1 migration backs up the v1 file it rewrites.
	for n in [1, 2, 3]:
		_fresh()
		_make(n, "witch", 4, "1-1", 30)
		game.use_slot(n)
		var first := FileAccess.get_file_as_string(game.slot_path(n))
		game.add_embers(20)
		game.save()
		_check(_exists(n, ".bak") and FileAccess.get_file_as_string(game.slot_path(n) + ".bak") == first,
				"slot %d: a save keeps the one it replaced as .bak" % n)
		_check(int(_on_disk(n).get("embers", 0)) == 50 and not _exists(n, ".tmp"), "slot %d: and the new one is whole (50 embers, no .tmp left)" % n)
		# The save turns to junk: the card and the load come back from the backup.
		_write(game.slot_path(n), "{\"version\": 2, \"embers\": 9, \"her")
		game.use_slot(1 if n != 1 else 2)
		var sm: Dictionary = game.slot_summary(n)
		_check(not sm.get("bad", false) and int(sm.get("embers", -1)) == 30 and sm.get("cls") == "witch",
				"slot %d can't be read: its card shows the backup (%s)" % [n, sm])
		game.use_slot(n)
		_check(game.embers() == 30 and game.has_hero("witch") and int(game.hero()["level"]) == 4,
				"slot %d: played, it's the backup's game (%d embers)" % [n, game.embers()])
		_check(_exists(n, ".bad"), "slot %d: the junk is kept aside as .bad" % n)
		var bak := FileAccess.get_file_as_string(game.slot_path(n) + ".bak")
		game.add_embers(5)
		game.save()
		_check(FileAccess.get_file_as_string(game.slot_path(n) + ".bak") == bak and int(_on_disk(n).get("embers", 0)) == 35,
				"slot %d: the next save mends it, and doesn't back the junk up over the good backup" % n)
		# The save goes missing: the backup again.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.slot_path(n)))
		game.load_save()
		_check(game.embers() == 30 and game.has_hero("witch"), "slot %d: a missing save loads its backup (%d embers)" % [n, game.embers()])
		_check(_exists(n) and FileAccess.get_file_as_string(game.slot_path(n)) == FileAccess.get_file_as_string(game.slot_path(n) + ".bak"),
				"slot %d: and the backup is put back as the save" % n)
		# Erased: no backup to come back from (only its Undo brings it back).
		game.save()
		game.save()
		_check(_exists(n, ".bak"), "(slot %d has a backup)" % n)
		game.erase_slot(n)
		_check(not _exists(n, ".bak") and game.slot_summary(n).is_empty(), "slot %d: an erase takes its backup too" % n)
		game.load_save()
		_check(game.heroes().is_empty() and game.embers() == 0, "slot %d: and nothing comes back from one after it" % n)
		_check(game.restore_slot(n) and game.has_hero("witch"), "slot %d: its Undo still brings it back" % n)
		game.new_game(n)
		_check(game.heroes().is_empty() and not _exists(n, ".bak"), "slot %d: a new game there starts clean, no backup" % n)
		_check(_exists(n, ".erased") and _exists(n, ".erased.bak"), "slot %d: (the game it began over is kept aside, backup and all, till the erase is let go)" % n)
	# Slot 1's v1 save: migrated as before, the v1 file kept as the backup.
	_fresh()
	if FileAccess.file_exists(FIXTURE):
		var v1 := FileAccess.get_file_as_string(FIXTURE)
		_write(game.slot_path(1), v1)
		game.use_slot(1)
		_check(game.veteran() == 4 and game.embers() == 362 and int(_on_disk(1).get("version", 0)) == game.VERSION,
				"a v1 save in slot 1 still migrates (362 embers, written as v%d)" % game.VERSION)
		_check(FileAccess.get_file_as_string(game.slot_path(1) + ".bak") == v1, "and the v1 file it replaced is its backup")
	# The settings: a write keeps the last good file, and a broken one reads the backup.
	_fresh()
	game.set_setting("shake", 0.5)
	game.set_setting("numbers", "crits")
	_check(FileAccess.file_exists(game.settings_path + ".bak"), "the settings keep their last good file as .bak")
	_write(game.settings_path, "{\"shake\": 0.")
	game.reload_settings()
	_check(is_equal_approx(float(game.setting("shake")), 0.5), "settings.json can't be read: its backup is read (shake %.2f)" % float(game.setting("shake")))
	var good := FileAccess.get_file_as_string(game.settings_path + ".bak")
	game.set_setting("haptics", false)
	_check(FileAccess.get_file_as_string(game.settings_path + ".bak") == good, "a write over the broken file doesn't back it up over the good one")
	var now = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path))
	_check(now is Dictionary and is_equal_approx(float(now.get("shake", 0.0)), 0.5) and now.get("haptics") == false,
			"and it writes the backup's settings with the new one (%s)" % [now])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path))
	game.reload_settings()
	_check(is_equal_approx(float(game.setting("shake")), 0.5), "a missing settings.json reads its backup too")
	game.haptics = true


func _test_backup_only() -> void:
	## A slot whose save has gone, with its backup left, is a filled slot
	## everywhere the player can reach it: its card shows the backup's game,
	## it can be the slot played last, and Start over or Erase keep the
	## backup for the Undo. A save that can't be read, with a good backup,
	## comes back from an erase's Undo as it was: its card the backup's game.
	for n in [1, 2, 3]:
		_fresh()
		var other := 2 if n == 1 else 1
		_make(other, "knight", 2, "", 7)
		_make(n, "witch", 3, "1-1", 123)
		game.use_slot(n)
		game.save()
		_check(_exists(n, ".bak"), "(slot %d has a backup)" % n)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.slot_path(n)))
		game.use_slot(other)
		game.set_setting("last_slot", n)
		var sm: Dictionary = game.slot_summary(n)
		_check(sm.get("cls") == "witch" and int(sm.get("embers", -1)) == 123 and not sm.get("bad", false),
				"slot %d, its save gone: the card shows the backup's game (%s)" % [n, sm])
		_check(int(sm.get("played", 0)) > 0, "slot %d: with when it was played" % n)
		_check(game.last_slot() == n, "slot %d: it's still the slot played last (%d)" % [n, game.last_slot()])
		var s: Control = SavesS.new()
		root.add_child(s)
		await process_frame
		_check(not s.summary(n).is_empty() and s._dots[n - 1].visible, "slot %d: on the saves screen it's a filled card, with its menu" % n)
		s.free()
		# Start over there (what its menu does): the Undo brings it back.
		game.new_game(n)
		_check(game.heroes().is_empty() and _exists(n) and not game.can_restore(n), "slot %d: started over: a new game there (no Undo over a filled slot)" % n)
		_check(_exists(n, ".erased.bak"), "slot %d: the old game's backup is kept aside with it, not deleted" % n)
		game.erase_slot(n)
		_check(game.can_restore(n) and _exists(n, ".erased") and not _exists(n, ".erased.bak"), "(the new game erased in turn)")
		# Erase it with only its backup there: Undo brings it back.
		_fresh()
		_make(n, "witch", 3, "1-1", 123)
		game.use_slot(n)
		game.save()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.slot_path(n)))
		game.use_slot(other)
		_check(game.erase_slot(n), "slot %d: a slot with only its backup can be erased" % n)
		_check(not _exists(n, ".bak") and game.slot_summary(n).is_empty() and game.can_restore(n), "slot %d: now empty, with an Undo" % n)
		_check(game.restore_slot(n) and game.slot_summary(n).get("cls") == "witch", "slot %d: the Undo brings the backup's game back" % n)
		game.use_slot(n)
		_check(game.embers() == 123 and game.has_hero("witch"), "slot %d: and it plays (%d embers)" % [n, game.embers()])
		# A save that can't be read with a good backup: Erase, then Undo.
		game.save()
		game.save()
		_write(game.slot_path(n), "{\"version\": 2, \"embers\": 9, \"her")
		game.use_slot(other)
		_check(game.slot_summary(n).get("cls") == "witch", "(slot %d's card shows its backup)" % n)
		_check(game.erase_slot(n) and game.slot_summary(n).is_empty(), "slot %d: erased" % n)
		_check(game.restore_slot(n), "slot %d: undone" % n)
		var back: Dictionary = game.slot_summary(n)
		_check(not back.get("bad", false) and back.get("cls") == "witch" and int(back.get("embers", -1)) == 123,
				"slot %d: the card shows again what it showed, the backup's game (%s)" % [n, back])
		game.use_slot(n)
		_check(game.embers() == 123 and game.has_hero("witch"), "slot %d: and playing it is that game" % n)
		game._purge_erased()
		_check(not _exists(n, ".erased") and not _exists(n, ".erased.bak"), "slot %d: letting the erase go leaves nothing aside" % n)


func _test_failed_write() -> void:
	## A write that can't go down whole leaves the last save (and the
	## settings) as they were: here the side file can't be made.
	_fresh()
	_make(2, "knight", 3, "", 40)
	game.use_slot(2)
	var before := FileAccess.get_file_as_string(game.slot_path(2))
	var bak_before := FileAccess.get_file_as_string(game.slot_path(2) + ".bak") if _exists(2, ".bak") else ""
	_mkdir(game.slot_path(2) + ".tmp")   # a folder where the side file goes: opening it to write fails
	game.add_embers(500)
	game.save()
	_check(FileAccess.get_file_as_string(game.slot_path(2)) == before, "a failed write keeps the old save, byte for byte")
	_check((FileAccess.get_file_as_string(game.slot_path(2) + ".bak") if _exists(2, ".bak") else "") == bak_before, "and its backup")
	_check(game._unsaved(), "and the save in memory still knows it isn't on disk")
	_check(not game.SettingsLib.write_whole(game.slot_path(2), "{}"), "write_whole says it failed")
	_rmdir(game.slot_path(2) + ".tmp")
	game.save()
	_check(int(_on_disk(2).get("embers", 0)) == 540 and not _exists(2, ".tmp"), "once it can, the save goes down whole (540 embers)")
	var st := FileAccess.get_file_as_string(game.settings_path)
	_mkdir(game.settings_path + ".tmp")
	game.set_setting("shake", 0.25)
	_check(FileAccess.get_file_as_string(game.settings_path) == st, "a failed settings write keeps the old file")
	_rmdir(game.settings_path + ".tmp")


func _test_lab_writes_nothing() -> void:
	## The feel lab writes nothing to the slot (decisions.md), played as the
	## map's Feel lab button plays it (a level on screen, not headless): its
	## once-only barks play without being marked (the slot still hears them
	## in its levels), the candle-strength card never asks, and neither the
	## app sent away nor leaving the lab saves. The slot file is byte for byte.
	var LevelData = load("res://scripts/level_data.gd")
	var World: GDScript = load("res://scripts/world.gd")
	var lv = LevelData.load_file("res://levels/lab-1.txt")
	_fresh()
	_make(3, "witch", 1, "", 0)
	game.use_slot(3)
	var before := FileAccess.get_file_as_bytes(game.slot_path(3))
	var w: Node2D = World.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	var hud: Node = w.get("hud")
	var said := 0
	for k in ["first_hurt", "low_flame", "first_snuff", "first_sigil"]:
		var n0: int = (hud._msgs as Array).size() if hud != null else 0
		w.bark(k)
		if hud != null and ((hud._msgs as Array).size() > n0 or str((hud._msg as Dictionary).get("key", "")) == "bark:" + k):
			said += 1
	_check(hud != null and said == 4, "the lab's once-only barks play (%d of 4)" % said)
	_check(not game.seen("bark:first_hurt") and not game.seen("bark:first_sigil"), "and aren't marked heard in the slot")
	var n1: int = (hud._msgs as Array).size() if hud != null else 0
	w.bark("first_hurt")
	_check(hud != null and (hud._msgs as Array).size() == n1, "(once a visit: not twice in the lab)")
	w.snuffs = 6
	if hud != null:
		hud._step_strength()
	_check(not (game.data["notices"] as Array).has("candle_strength") and (hud == null or (hud._cardq as Array).is_empty()),
			"six snuffs in the lab: no candle-strength card, nothing noticed")
	w.embers_carried = 12
	w.backgrounded()
	_check(FileAccess.get_file_as_bytes(game.slot_path(3)) == before, "the app sent away from the lab writes nothing")
	w.queue_free()
	await process_frame
	await process_frame
	_check(FileAccess.get_file_as_bytes(game.slot_path(3)) == before, "leaving the lab leaves the slot's file byte for byte")
	game.load_save()
	_check(not game.seen("bark:first_hurt") and game.embers() == 0, "and the slot, loaded again, hasn't heard them")
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx":
			c.queue_free()
	await process_frame


func _test_unbanked() -> void:
	## Embers carried in a level when the app is sent away go into the slot's
	## save as unbanked, not into the purse: the level still carries them (a
	## snuff still spills them, only an altar banks them). If the app is
	## ended there, the next load puts them in the purse, as leaving the
	## level would have. A bank, a snuff or leaving clears them.
	var LevelData = load("res://scripts/level_data.gd")
	var World: GDScript = load("res://scripts/world.gd")
	var lv = LevelData.load_file("res://levels/1-1.txt")
	for n in [2, 3, 1]:
		_fresh()
		_make(n, "runner", 3, "", 40)
		game.use_slot(n)
		var w: Node2D = World.new()
		w.setup(lv, true)
		root.add_child(w)
		await process_frame
		w.embers_carried = 37
		w.backgrounded()
		_check(int(_on_disk(n).get("unbanked", -1)) == 37 and int(_on_disk(n).get("embers", 0)) == 40,
				"slot %d, sent away carrying 37: the save holds them unbanked, the purse as it was" % n)
		_check(game.embers() == 40 and w.embers_carried == 37, "slot %d: backgrounding banks nothing (still carried)" % n)
		# iOS ends the app: the next launch reads the save.
		game.load_save()
		_check(game.embers() == 77 and game.unbanked() == 0, "slot %d: ended there, the next load adds them to the purse (%d)" % [n, game.embers()])
		_check(int(_on_disk(n).get("embers", 0)) == 77 and int(_on_disk(n).get("unbanked", -1)) == 0, "slot %d: and writes that down, once" % n)
		game.load_save()
		_check(game.embers() == 77, "slot %d: a second load doesn't add them again" % n)
		w.queue_free()
		await process_frame
		# Back in the level: an altar banks them and clears the note.
		w = World.new()
		w.setup(lv, true)
		root.add_child(w)
		await process_frame
		w.embers_carried = 12
		w.backgrounded()
		w._bank()
		_check(game.embers() == 89 and game.unbanked() == 0 and w.embers_carried == 0, "slot %d: an altar banks them and clears the note" % n)
		game.save()
		game.load_save()
		_check(game.embers() == 89, "slot %d: nothing is added twice after a bank" % n)
		# A snuff spills them into the pool: the save forgets them at once.
		w.embers_carried = 25
		w.backgrounded()
		w.player.invuln = 0.0
		w.player.take_damage(w.player.max_hp * 9.0, w.player.position.x + 10.0)
		_check(w.state == "dead" and int(w.pool.get("embers", 0)) == 25, "slot %d: a snuff spills them into the pool" % n)
		_check(game.unbanked() == 0 and int(_on_disk(n).get("unbanked", -1)) == 0 and int(_on_disk(n).get("embers", 0)) == 89,
				"slot %d: and the save forgets them (no ending the app to keep what was spilt)" % n)
		w.queue_free()
		await process_frame
	# Leaving the level (the pause menu, or finishing) banks and clears them.
	_fresh()
	_make(2, "knight", 2, "", 10)
	game.use_slot(2)
	var w2: Node2D = World.new()
	w2.setup(lv)
	root.add_child(w2)
	await process_frame
	w2.embers_carried = 15
	w2.backgrounded()
	_check(int(_on_disk(2).get("unbanked", -1)) == 15, "(a level on screen, sent away with 15)")
	w2.queue_free()
	await process_frame
	await process_frame
	_check(game.embers() == 25 and int(_on_disk(2).get("embers", 0)) == 25 and int(_on_disk(2).get("unbanked", -1)) == 0,
			"leaving the level banks them and clears the note (%d)" % game.embers())
	game.load_save()
	_check(game.embers() == 25, "and a later load adds nothing")
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx":
			c.queue_free()
	await process_frame


# ---------------------------------------------------------------- the screen's words

func _test_texts() -> void:
	_fresh()
	_make(2, "knight", 9, "2-2", 412)
	var s: Control = SavesS.new()
	root.add_child(s)
	_check(s.loss_line(2) == "Erases Save 2: Candleknight Lv 9, 2-3", "what goes: %s" % s.loss_line(2))
	_make(3, "runner", 4, "", 10, ["witch", "knight"])
	s.refresh()
	_check(s.loss_line(3) == "Erases Save 3: Sootrunner Lv 4 (+2 callings), 1-1", "with more callings: %s" % s.loss_line(3))
	s.free()
	# Last played, in local time (bias 0 here): Fri 25 Sep 2026, 14:05.
	var now := int(Time.get_unix_time_from_datetime_string("2026-09-25T14:05:00"))
	_check(SavesS.played_text(now - 600, now, 0) == "Played today, 13:55", SavesS.played_text(now - 600, now, 0))
	_check(SavesS.played_text(now - 86400, now, 0) == "Played yesterday, 14:05", SavesS.played_text(now - 86400, now, 0))
	_check(SavesS.played_text(now - 3 * 86400, now, 0) == "Played Tuesday", SavesS.played_text(now - 3 * 86400, now, 0))
	_check(SavesS.played_text(now - 13 * 86400, now, 0) == "Played 12 Sep", SavesS.played_text(now - 13 * 86400, now, 0))
	_check(SavesS.played_text(now - 400 * 86400, now, 0) == "Played 21 Aug 2025", SavesS.played_text(now - 400 * 86400, now, 0))
	_check(SavesS.played_text(0, now, 0) == "", "never played: nothing")
	_check(SavesS.diffs_text(["dusk", "nightfall"]) == "Dusk · Nightfall", SavesS.diffs_text(["dusk", "nightfall"]))


# ---------------------------------------------------------------- layout

func _test_layout() -> void:
	## The three cards side by side inside the safe area: 844 x 390 and the
	## phone's 1266 x 585 (the same view, 1.5 times), the island's inset on
	## the left, the right, or both; every button a thumb's height.
	_fresh()
	_make(1, "knight", 9, "2-2", 412)
	_make(2, "witch", 4, "1-2", 96)
	var vs := Vector2(844, 390)
	var side := 55.0
	var safes := {"left": Rect2(side, 10.0, vs.x - side - 14.0, vs.y - 27.7), "right": Rect2(14.0, 10.0, vs.x - side - 14.0, vs.y - 27.7),
			"both": UI.phone_safe(vs), "margins": Rect2(14, 10, vs.x - 28.0, vs.y - 18.0)}
	for k in safes:
		UI.safe_override = safes[k]
		var S: Rect2 = safes[k]
		var s: Control = SavesS.new()
		root.add_child(s)
		await process_frame
		await process_frame
		var R: Array = s.card_rects()
		_check(R.size() == 3, "[%s] three cards" % k)
		for i in R.size():
			_inside(R[i], S, "[%s] card %d" % [k, i + 1])
			_check((R[i] as Rect2).size.y >= 280.0 and (R[i] as Rect2).size.x >= 200.0, "[%s] card %d is big enough for what it shows (%s)" % [k, i + 1, R[i]])
			if i > 0:
				_check((R[i] as Rect2).position.x >= (R[i - 1] as Rect2).end.x + 8.0, "[%s] cards %d and %d stand apart" % [k, i, i + 1])
			_check(absf((R[i] as Rect2).position.y - (R[0] as Rect2).position.y) < 0.1, "[%s] side by side" % k)
		_inside(_rect(s._back_btn), S, "[%s] Back" % k)
		_check(not _rect(s._back_btn).intersects(R[0]), "[%s] Back is clear of the cards" % k)
		for i in 2:
			var d: Button = s._dots[i]
			_check(d.visible and d.size.y >= UI.TAP_H and d.size.x >= UI.TAP_H, "[%s] card %d's \"...\" is a thumb's size (%s)" % [k, i + 1, d.size])
			_inside(_rect(d), R[i], "[%s] card %d's \"...\"" % [k, i + 1])
		_check(not s._dots[2].visible, "[%s] an empty card has no \"...\"" % k)
		_check(s._back_btn.size.y >= UI.TAP_H, "[%s] Back is a thumb's height" % k)
		s.open_menu(1)
		await process_frame
		var P: Rect2 = s.menu_rect()
		_inside(P, S, "[%s] the menu" % k)
		for b in [s._start_btn, s._erase_btn, s._cancel_btn]:
			_check((b as Button).visible and (b as Button).size.y >= UI.TAP_H, "[%s] menu's %s is a thumb's height" % [k, (b as Button).text])
			_inside(_rect(b), P, "[%s] menu's %s" % [k, (b as Button).text])
		_check(not _rect(s._start_btn).intersects(_rect(s._erase_btn)), "[%s] Start over and Erase apart" % k)
		s.ask("erase")
		await process_frame
		_check(s._hold.visible and not s._start_btn.visible and s._hold.size.y >= UI.TAP_H, "[%s] the hold replaces them" % k)
		_inside(_rect(s._hold), P, "[%s] the hold" % k)
		_inside(_rect(s._cancel_btn), P, "[%s] Cancel" % k)
		_check(not _rect(s._hold).intersects(_rect(s._cancel_btn)), "[%s] the hold and Cancel apart" % k)
		s.close_menu()
		s.undo_slot = 2
		s.undo_left = 3.0
		s._layout()
		await process_frame
		_inside(s.toast_rect(), R[1], "[%s] the Undo, in the card erased" % k)
		_inside(_rect(s._undo_btn), s.toast_rect(), "[%s] the Undo button" % k)
		_check(s._undo_btn.size.y >= UI.TAP_H, "[%s] Undo is a thumb's height" % k)
		s.free()
	UI.safe_override = UI.phone_safe(vs)


# ---------------------------------------------------------------- the screen

func _test_screen() -> void:
	_fresh()
	_make(1, "knight", 9, "2-2", 412)
	_make(2, "witch", 4, "1-2", 96)
	game.use_slot(2)
	var s: Control = SavesS.new()
	root.add_child(s)
	await process_frame
	await process_frame
	var played: Array = []
	var begun: Array = []
	var backs := [0]
	s.play.connect(func(n): played.append(n))
	s.new_game.connect(func(n): begun.append(n))
	s.back.connect(func(): backs[0] += 1)
	_check(not s.taking_taps(), "a screen just opened takes no tap yet")
	_settle(s)
	_check(s.taking_taps(), "then it does")
	_check(s._last == 2 and s.focus == 1, "the slot played last is the one lit (and the keys start there)")
	_check(not s.summary(1).is_empty() and not s.summary(2).is_empty() and s.summary(3).is_empty(), "two filled cards, one empty")
	# The "..." opens the menu; a tap outside closes it.
	var R: Array = s.card_rects()
	await _click(_rect(s._dots[0]).get_center())
	_check(s.menu_slot == 1 and s.confirm == "" and s._menu.visible, "a card's \"...\" opens its menu")
	_check(played.is_empty() and begun.is_empty(), "and doesn't play the card")
	await _click(Vector2(s.menu_rect().position.x - 6.0, s.menu_rect().get_center().y) if s.menu_rect().position.x > 20.0 else Vector2(10, 10))
	_check(s.menu_slot == 0 and not s._menu.visible, "a tap outside closes it")
	# Erase: asked, then held.
	s.open_menu(1)
	await process_frame
	await _click(_rect(s._erase_btn).get_center())
	_check(s.confirm == "erase" and s._hold.visible and s._hold.label == "Hold to erase", "Erase asks for a hold")
	_check(_exists(1), "a tap alone erases nothing")
	# Held a second: not yet. Let go: it drains.
	var hc: Vector2 = _rect(s._hold).get_center()
	await _press(hc, true)
	_check(s._hold.holding(), "the hold is being held")
	s._hold.step(1.0)
	_check(_exists(1) and s._hold.fill > 0.7 and s._hold.fill < 1.0, "held a second of %.1f: not yet (%.2f)" % [s.HOLD_SECS, s._hold.fill])
	await _press(hc, false)
	s._hold.step(0.5)
	_check(s._hold.fill < 0.5 and _exists(1), "let go: it drains, nothing erased (%.2f)" % s._hold.fill)
	# Cancel.
	await _click(_rect(s._cancel_btn).get_center())
	_check(s.menu_slot == 0 and _exists(1), "Cancel: nothing erased")
	# Held the whole way.
	s.open_menu(1)
	s.ask("erase")
	await process_frame
	hc = _rect(s._hold).get_center()
	await _press(hc, true)
	s._hold.step(0.7)
	s._hold.step(0.6)
	_check(not _exists(1) and _exists(1, ".erased"), "held %.1f s: Save 1 is erased" % s.HOLD_SECS)
	_check(not s.taking_taps() and s._lift > 0.0, "the finger still down: no tap is taken")
	await _press(hc, false)
	await process_frame
	_check(s.menu_slot == 0 and s.undo_slot == 1 and s._toast.visible and s.summary(1).is_empty(), "the card is empty, and the Undo shows")
	_check(played.is_empty() and begun.is_empty(), "(nothing played)")
	# A tap just after the hold (the finger coming down again where it was,
	# over Save 2) is let go by.
	_check(not s.taking_taps() and s._lift == 0.0 and s._calm > 0.0, "lifted: a moment's calm")
	await _click((R[1] as Rect2).get_center())
	await _click((R[0] as Rect2).get_center())
	_check(played.is_empty() and begun.is_empty() and s.undo_slot == 1, "a tap straight after the hold plays nothing, and the Undo stays")
	s._process(s.CALM_SECS + 0.05)
	_check(s.taking_taps(), "then taps are taken again")
	# The card just erased takes no tap while its Undo shows: not on its
	# "New Game" (now "Erased"), nor on the Undo's panel.
	await _click((R[0] as Rect2).get_center())
	await _click(s.toast_rect().position + Vector2(10, 10))
	_check(begun.is_empty() and s.undo_slot == 1 and not _exists(1), "a tap on the erased card starts nothing there")
	s.focus = 0
	await _key(KEY_SPACE)
	_check(begun.is_empty() and s.undo_slot == 1 and not s._gone, "nor Space on it")
	# Another card's menu over it: the Undo waits, hidden, and can't be
	# tapped through the menu.
	var ub: Rect2 = _rect(s._undo_btn)
	s.open_menu(2)
	await process_frame
	_check(not s._toast.visible and not s._undo_btn.is_visible_in_tree(), "a menu open: the Undo is hidden")
	var left: float = s.undo_left
	s._process(1.0)
	_check(is_equal_approx(s.undo_left, left), "and its time waits (%.2f of %.2f)" % [s.undo_left, left])
	await _click(_rect(s._erase_btn).get_center())
	_check(s.confirm == "erase" and s.owes_note() == "Save 1's erase can't be undone after this.", "the hold warns the Undo would go: %s" % s.owes_note())
	await process_frame
	_inside(_rect(s._hold), s.menu_rect(), "the hold, lower for the warning,")
	_check(_rect(s._hold).position.y >= s.menu_rect().position.y + 100.0 + 2 * 16.0 + 8.0, "below the warning")
	_check(not _rect(s._hold).intersects(_rect(s._cancel_btn)), "and clear of Cancel")
	var hit: Rect2 = ub.intersection(s.menu_rect())
	await _click(hit.get_center() if hit.has_area() else ub.get_center())
	_check(s.undo_slot == 1 and not _exists(1), "a tap where the Undo was, through the menu, restores nothing")
	if s.menu_slot == 0:
		s.open_menu(2)
	await _click(_rect(s._cancel_btn).get_center())
	_check(s.menu_slot == 0 and s._toast.visible and s._undo_btn.is_visible_in_tree(), "the menu shut: the Undo is back")
	# Left before it runs out, the next saves screen offers it again.
	s.free()
	_check(SavesS._owed == 1, "(the Undo is owed)")
	s = SavesS.new()
	root.add_child(s)
	await process_frame
	_settle(s)
	s.play.connect(func(n): played.append(n))
	s.new_game.connect(func(n): begun.append(n))
	s.back.connect(func(): backs[0] += 1)
	_check(s.undo_slot == 1 and s._toast.visible and s.undo_left > s.UNDO_SECS - 0.5, "the next saves screen offers the Undo again, for %.0f s (%.2f)" % [s.UNDO_SECS, s.undo_left])
	_check(s.owes_note() == "", "(no warning outside a hold)")
	await _click(_rect(s._undo_btn).get_center())
	_check(_exists(1) and s.undo_slot == 0 and not s._toast.visible and s.summary(1).get("cls") == "knight", "Undo: Save 1 is back")
	# The Undo waits UNDO_SECS, then goes (and the erase stays).
	s.open_menu(1)
	s.ask("erase")
	s._hold.held = true
	s._hold.step(1.3)
	s._hold.held = false
	_check(s.undo_slot == 1, "erased again")
	s._process(s.UNDO_SECS * 0.6)
	_check(s.undo_slot == 1 and s._toast.visible, "the Undo is still there after %.0f s" % (s.UNDO_SECS * 0.6))
	s._process(s.UNDO_SECS * 0.5)
	_check(s.undo_slot == 0 and not s._toast.visible and not _exists(1), "and gone after %.0f s: the erase stays" % s.UNDO_SECS)
	var s2: Control = SavesS.new()
	root.add_child(s2)
	_check(s2.undo_slot == 0, "an Undo that ran out isn't offered again")
	s2.free()
	game.restore_slot(1)
	s.refresh()
	# Start over: asked the same way, then new_game(n).
	s.open_menu(2)
	s.ask("start_over")
	_check(s._hold.label == "Hold to start over", "Start over asks for a hold too")
	s._hold.held = true
	s._hold.step(0.6)
	_check(begun.is_empty(), "half held: not yet")
	s._hold.step(0.7)
	_check(begun == [2], "held: a new game in slot 2 (main erases it and plays the intro)")
	s.free()
	# Taps on the cards.
	s = SavesS.new()
	root.add_child(s)
	await process_frame
	_settle(s)
	s.play.connect(func(n): played.append(n))
	s.new_game.connect(func(n): begun.append(n))
	R = s.card_rects()
	await _click((R[2] as Rect2).get_center())
	_check(begun == [2, 3] and played.is_empty(), "a tap on an empty card: a new game there")
	await _click((R[0] as Rect2).get_center())
	_check(played.is_empty(), "once one is chosen, the screen takes no more taps")
	s.free()
	s = SavesS.new()
	root.add_child(s)
	await process_frame
	_settle(s)
	s.play.connect(func(n): played.append(n))
	s.back.connect(func(): backs[0] += 1)
	await _click((s.card_rects()[0] as Rect2).get_center())
	_check(played == [1], "a tap on a filled card plays it")
	s.free()
	s = SavesS.new()
	root.add_child(s)
	await process_frame
	_settle(s)
	s.play.connect(func(n): played.append(n))
	await _key(KEY_SPACE)
	_check(played == [1, s._last], "Space plays the card the keys are on (the one lit): %s" % [played])
	s.free()
	s = SavesS.new()
	root.add_child(s)
	await process_frame
	_settle(s)
	s.back.connect(func(): backs[0] += 1)
	await _click(_rect(s._back_btn).get_center())
	_check(backs[0] == 1, "Back says back")
	s.free()


# ---------------------------------------------------------------- through main

func _test_flow_new_game() -> void:
	## The title leads to the saves; an empty slot is a new game: the intro,
	## the oath, the map. Slot 1 is left byte for byte.
	_fresh()
	_make(1, "knight", 6, "1-3", 150)
	var b1 := _bytes(1)
	game.use_slot(1)
	await _clear_root()
	var main: Node = await _new_main()
	_check(main.current.get_script() == TitleS, "main opens on the title")
	main.current.start.emit()
	_check(main.current.get_script() == SavesS, "a title tap opens the saves")
	main.current.back.emit()
	_check(main.current.get_script() == TitleS, "the saves' Back: the title")
	main.current.start.emit()
	await process_frame
	main.current.tap_card(2)
	_check(_is_scene(main.current, "intro"), "an empty slot: a new game, from the intro")
	_check(game.current_slot() == 2 and _exists(2) and game.heroes().is_empty(), "in slot 2, fresh")
	_check(_play_out(main.current), "the intro plays through")
	_check(_is_scene(main.current, "oath"), "then the oath")
	_check(_play_out(main.current, "witch"), "the oath: a calling chosen")
	_check(main.current.get_script() == MapS and game.hero_id() == "witch" and int(game.hero()["level"]) == 1, "then the map, a new Taperwitch at level 1")
	_check(_bytes(1) == b1, "slot 1 is byte for byte as it was")
	_check(_on_disk(2).get("hero") == "witch" and (_on_disk(2)["seen"] as Array).has("intro"), "slot 2 holds the new game")
	# The map's Title button: the title shows this save, and leads to the saves.
	main.current.back.emit()
	_check(main.current.get_script() == TitleS and str(main.current._who).begins_with("Save 2 · Taperwitch"), "the map's back: the title, with slot 2's hero")
	main.current.start.emit()
	_check(main.current.get_script() == SavesS and main.current._last == 2, "and the saves, slot 2 lit")
	# A filled slot: straight to the map, no intro.
	main.current.tap_card(1)
	_check(main.current.get_script() == MapS and game.current_slot() == 1 and game.hero_id() == "knight", "a filled slot: straight to its map")
	_check(game.last_slot() == 1, "slot 1 is the last played now")
	# The pause menu's Restart still restarts the level; Leave goes to the map.
	main.play_level(0)
	var w: Node = main.current
	w.restart.emit()
	_check(main.current != w and str(main.current.get("level_id")) == "1-1", "the pause menu's Restart plays the level again")
	main.current.quit.emit()
	_check(main.current.get_script() == MapS, "and leaving it goes to the map")
	_check(game.current_slot() == 1 and game.hero_id() == "knight", "still in slot 1")
	main.queue_free()
	await process_frame


func _test_flow_start_over() -> void:
	_fresh()
	_make(1, "knight", 6, "1-3", 150)
	_make(2, "founder", 5, "1-2", 90)
	var b1 := _bytes(1)
	await _clear_root()
	var main: Node = await _new_main()
	main.show_saves()
	var s: Control = main.current
	s.open_menu(2)
	s.ask("start_over")
	s._hold.held = true
	s._hold.step(1.3)
	_check(_is_scene(main.current, "intro"), "start over: the intro plays")
	_check(game.current_slot() == 2 and game.heroes().is_empty() and game.embers() == 0 and _exists(2) and _exists(2, ".erased"), "slot 2 begun again (the old one kept aside)")
	_check(_bytes(1) == b1, "slot 1 untouched")
	main.queue_free()
	await process_frame


func _test_flow_corrupt() -> void:
	_fresh()
	_make(1, "knight", 2, "", 5)
	_write(game.slot_path(3), "not a save")
	await _clear_root()
	var main: Node = await _new_main()
	main.show_saves()
	await process_frame
	await process_frame
	_check(main.current.summary(3).get("bad", false), "the saves screen draws a card that can't be read")
	main.current.tap_card(3)
	_check(_is_scene(main.current, "intro"), "tapped: it begins anew there, as a broken save always has")
	_check(FileAccess.get_file_as_string(game.slot_path(3) + ".bad") == "not a save", "the broken file is kept as .bad")
	main.queue_free()
	await process_frame


func _test_title_hero() -> void:
	## A save made then left: the next title shows it; with none, no hero.
	_fresh()
	await _clear_root()
	var main: Node = await _new_main()
	_check(str(main.current._who) == "", "no saves: the title names no hero")
	main.queue_free()
	await process_frame


func _test_double_tap() -> void:
	## A quick second tap on "Tap to begin" (or a second key press) lands on
	## the saves as they open: it mustn't choose a card.
	_fresh()
	_make(1, "knight", 4, "1-2", 60)
	game.use_slot(1)
	var b1 := _bytes(1)
	var settings := FileAccess.get_file_as_string(game.settings_path)
	await _clear_root()
	var main: Node = await _new_main()
	main.current._t = 1.0   # the title's own guard passed
	var mid := Vector2(422, 220)
	await _click(mid)
	_check(main.current.get_script() == SavesS, "a real tap on the title opens the saves")
	var s: Control = main.current
	_check((s.card_rects()[1] as Rect2).has_point(mid), "(the title's middle is over Save 2)")
	await create_timer(0.1).timeout
	await _click(mid)
	_check(main.current == s and not s._gone, "a second tap 0.1 s later: still the saves")
	_check(not _exists(2) and game.current_slot() == 1 and FileAccess.get_file_as_string(game.settings_path) == settings, "no new game in Save 2, nothing remembered")
	await _click(_rect(s._back_btn).get_center())
	await _click(_rect(s._dots[0]).get_center())
	_check(main.current == s and s.menu_slot == 0, "nor Back, nor a card's \"...\"")
	await _key(KEY_SPACE)
	await _key(KEY_ENTER)
	_check(main.current == s and _bytes(1) == b1, "nor Space or Enter (Save 1 not played)")
	await create_timer(s.GUARD_SECS + 0.05).timeout
	await process_frame
	_check(s.taking_taps(), "a moment later the saves take taps")
	await _click(mid)
	_check(_is_scene(main.current, "intro") and game.current_slot() == 2, "and a tap on Save 2 begins a new game there")
	main.queue_free()
	await process_frame


func _test_erase_current_back() -> void:
	## Erasing the slot being played, then Back: the title shows the slot
	## played last of those left (not a blank stand-in), and writes nothing;
	## undone, the erased one is back on the title.
	_fresh()
	_make(2, "witch", 5, "1-2", 70)
	_make(1, "knight", 7, "1-3", 90)
	game.use_slot(1)
	var b2 := _bytes(2)
	var settings := FileAccess.get_file_as_string(game.settings_path)
	await _clear_root()
	var main: Node = await _new_main()
	main.show_saves()
	var s: Control = main.current
	s.open_menu(1)
	s.ask("erase")
	s._hold.held = true
	s._hold.step(1.3)
	_check(not _exists(1) and game.current_slot() == 1 and game.heroes().is_empty(), "Save 1, being played, is erased")
	_check(s._last == 2, "Save 2 is lit as the last played now")
	s._leave()
	var t: Control = main.current
	_check(t.get_script() == TitleS and game.current_slot() == 2 and game.hero_id() == "witch", "Back: the title, on Save 2 (%d)" % game.current_slot())
	_check(str(t._who) == "Save 2 · Taperwitch · Level 5" and str(t._cls) == "witch", "the title shows Save 2's hero: %s" % t._who)
	_check(_bytes(2) == b2 and FileAccess.get_file_as_string(game.settings_path) == settings, "and nothing was written")
	# The Undo, owed from the screen left early.
	main.show_saves()
	s = main.current
	_check(s.undo_slot == 1 and s._last == 2, "the saves again: Save 1's Undo still offered")
	s.undo()
	_check(_exists(1) and s._last == 1, "undone: Save 1 is back, and lit as the last played")
	s._leave()
	_check(game.current_slot() == 1 and game.hero_id() == "knight" and str(main.current._who) == "Save 1 · Candleknight · Level 7", "the title: Save 1 again (%s)" % main.current._who)
	_check(_bytes(2) == b2, "Save 2 untouched")
	# The only save erased: the title has no hero to show.
	_fresh()
	_make(1, "knight", 3, "", 5)
	main.show_saves()
	s = main.current
	s.open_menu(1)
	s.ask("erase")
	s._hold.held = true
	s._hold.step(1.3)
	s._leave()
	_check(str(main.current._who) == "" and game.current_slot() == 1 and not _exists(1), "no save left: the title names no hero")
	main.queue_free()
	await process_frame


func _test_look_only() -> void:
	## A slot's map looked at, then another slot chosen: the first isn't
	## written (its card's "last played" stays), though a real change is.
	_fresh()
	_make(1, "knight", 4, "1-1", 50)
	_make(2, "witch", 3, "", 20)
	var d1 := _on_disk(1)
	d1["saved_at"] = 1000
	_write(game.slot_path(1), JSON.stringify(d1, "\t"))
	var b1 := _bytes(1)
	await _clear_root()
	var main: Node = await _new_main()
	main._play_slot(1)
	_check(main.current.get_script() == MapS and game.current_slot() == 1, "Save 1's map")
	await process_frame
	await process_frame
	game.level_record("2-4", "nightfall")   # as the map does for a level never played
	_check(not game._unsaved(), "looking adds nothing to save")
	main.show_title()
	main.show_saves()
	main._play_slot(2)
	_check(_bytes(1) == b1 and int(game.slot_summary(1).get("played", 0)) == 1000, "Save 1 not written by being looked at (played %s)" % game.slot_summary(1).get("played"))
	main._play_slot(1)
	game.level_record("1-2")["best_time"] = 71.5
	_check(game._unsaved(), "a record really set is something to save")
	main._play_slot(2)
	_check(float(_on_disk(1)["levels"]["dusk"]["1-2"]["best_time"]) == 71.5 and int(_on_disk(1)["saved_at"]) > 1000, "and is written as the slot is left")
	main.queue_free()
	await process_frame


func _test_launch_purge() -> void:
	## A new launch of the game lets the last session's erase go (iOS ends
	## an app without a quit); a test or tool run never does.
	_fresh()
	_check(not game.app_launch(), "(a --script run isn't the game's own launch)")
	_make(1, "knight", 2, "", 5)
	_make(2, "witch", 2, "", 5)
	game.erase_slot(2)
	var g2: Node = load("res://scripts/game_state.gd").new()
	g2.settings_path = game.settings_path
	g2.slot_base = game.slot_base
	g2.save_path = g2.SAVE_PATH
	g2._pick_slot(false, false)
	_check(_exists(2, ".erased") and g2.save_path == game.slot_path(1), "not a launch: the erased file is kept (%s)" % g2.save_path)
	g2.save_path = g2.SAVE_PATH
	g2._pick_slot(false, true)
	_check(not _exists(2, ".erased") and _exists(1) and g2.save_path == game.slot_path(1), "a launch: it's let go, and the last slot opens")
	_check(not game.restore_slot(2), "there's nothing left to undo")
	g2.free()


# ---------------------------------------------------------------- autoplay

func _test_autoplay() -> void:
	## The bot (--autoplay) keeps its own save, its slots beside it.
	_check(not game.autoplay_launch(), "(this isn't an autoplay launch)")
	var m: Node = MainS.new()
	m._autoplay_save(false)   # the paths only: the bot's real save isn't read
	_check(game.save_path == "user://autoplay_save.json" and game.slot_base == "user://autoplay_save", "main's autoplay save: its own (%s, %s)" % [game.save_path, game.slot_base])
	_check(game.slot_path(1) == game.save_path and game.slot_path(2) == "user://autoplay_save_2.json", "and its slots beside it")
	m.free()
	# At launch, the bot's save is picked before any real slot is read.
	var g2: Node = load("res://scripts/game_state.gd").new()
	g2.settings_path = game.settings_path
	_check(g2.save_path == g2.SAVE_PATH, "(a second Game starts on user://save.json)")
	g2._pick_slot(true)
	_check(g2.save_path == g2.AUTOPLAY_SAVE and g2.slot_base == "user://autoplay_save", "an autoplay launch opens the bot's save, not the last slot")
	g2.free()
	_fresh()
