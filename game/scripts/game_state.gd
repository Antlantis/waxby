extends Node
## The save and what carries between levels, autoloaded as Game.
## Account-wide: which levels are open (per difficulty), sigils and records,
## the relic codex, the ember purse, story seen, bells rung. Per hero (one
## per calling): level, XP, skill points, gear, satchel, relic belt, the
## Chandler's stock. Settings live in user://settings.json through
## settings.gd, not in the save. Also sets up the input actions.
##
## Outside this file, read and change the save only through these functions,
## never Game.data[...] directly.
##
## Save v2 (spec §6). A v1 save migrates on load: its unlocks, relic codex
## and embers carry over (+150 embers for a veteran), haptics moves to
## settings, and its level records are kept aside in "v1_levels" (the
## levels were rebuilt, so v2 starts them fresh). The first hero starts at
## L1. A later calling starts at max(1, best - 2) with a Blessed kit.
##
## Skill points: every level-up gives one; once the tree is full it gives a
## Vigil rank instead (+2% damage and life). _settle_points keeps
## spent + points + vigil == level - 1 for every hero.
##
## A save is written whole or not at all (SettingsLib.write_whole), and the
## good save it replaces is kept beside it as <save>.bak: load_save falls
## back to that when the save is missing or can't be read (a missing one is
## put back from it), and a slot with only its .bak left is still a filled
## slot to the saves screen (its card, Continue, the slot played last). An
## erase keeps the .bak with the save for its Undo. Embers carried in
## a level when the app is sent away are written as "unbanked", and the
## next load adds them to the purse, as leaving the level would have.
##
## Save slots: three saves, each a whole game of its own (see "save slots"
## below). Slot 1 is user://save.json, the one there has always been (and the
## only one that migrates a v1 save); slots 2 and 3 are save_2.json and
## save_3.json, made when a new game starts there. The settings are shared,
## and remember the slot played last ("last_slot"), which opens at launch.
##
## Save v3 (spec §9, contract §8). Every slot migrates on its own when it
## loads: v2 -> v3 in any slot, v1 -> v2 -> v3 in slot 1. The file a
## migration replaces is kept, once, as <save>.v1 or <save>.v2 beside it
## (never read, never written again), on top of the usual .bak. v2 -> v3:
## unlocks recounted past v2's clamp at 8; the difficulty set to Dusk;
## Nightfall and Witching locked again until the Hush (6-4) falls on the
## difficulty below, their unlocks kept aside in "relocked" and their records
## untouched, so they count again when it reopens (the owner's answer,
## decisions.md); each hero's "deepest" and "look" seeded; "legends_found"
## seeded from every Legendary held; "notices" empty, so the v3 cards show.
## New keys: secrets, flask, legends_found, modes, suspend, notices,
## relocked, bosses (bosses beaten at the hero's depth: the Reserve restocks
## on each, _restocks_reserve); per
## hero deepest and look (and, once Waxley holds one, reserve / reserve_seed /
## reserve_new). Level ids are exact and case-sensitive ("1-S"); secret
## levels live in SECRET_LEVELS, outside the linear ALL_LEVELS, so the
## index-based unlocks never shift.
##
## The hero's own name (hero_name): one a save, asked for at the oath and
## changed on the Sheet; Story.clean_name keeps it to NAME_MAX letters,
## spaces, apostrophes and hyphens. A save from before there was a name (any
## version, the v1 migration too) or one holding junk there is Waxby.
##
## The Chandler by depth (spec §8.2): shop_depth = max(hero.deepest, level
## - 1) sets the stock (4 wares below 13, 5 from 13, 6 from 28; the weakest
## slot's pick is the best of 6 Rares from 18), the relic shelf (3, 4 from
## 23; only worlds reached) and Waxley's Reserve (a Legendary, from 23,
## restocked when a boss falls). The Draughts tab: Mother Yarrow's Second
## Draught (a gift), the Rich Draught (after the Tinker, 1,600 embers) and
## Rekindle (from World 5: a Legendary re-made at the hero's level).

const Relics := preload("res://scripts/relics.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Progression := preload("res://scripts/progression.gd")
const Combat := preload("res://scripts/combat.gd")
const Classes := preload("res://scripts/classes.gd")
const SettingsLib := preload("res://scripts/settings.gd")
const Story := preload("res://scripts/story.gd")    # the hero's name: its default and its rules
const SAVE_PATH := "user://save.json"
const AUTOPLAY_SAVE := "user://autoplay_save.json"   # the bot's own (its slots sit beside it)
const VERSION := 3
const SATCHEL_MAX := 16
const VETERAN_EMBERS := 150
const WARES := 4            # the Chandler's stock: 2 Blessed, 1 Rare, 1 for the weakest slot
# The main levels, in order (contract §2.6); LEVELS holds those whose files
# exist in this build. Ids are exact and case-sensitive.
const ALL_LEVELS := [
	{"id": "1-1", "path": "res://levels/1-1.txt", "world": 1},
	{"id": "1-2", "path": "res://levels/1-2.txt", "world": 1},
	{"id": "1-3", "path": "res://levels/1-3.txt", "world": 1},
	{"id": "1-4", "path": "res://levels/1-4.txt", "world": 1},
	{"id": "2-1", "path": "res://levels/2-1.txt", "world": 2},
	{"id": "2-2", "path": "res://levels/2-2.txt", "world": 2},
	{"id": "2-3", "path": "res://levels/2-3.txt", "world": 2},
	{"id": "2-4", "path": "res://levels/2-4.txt", "world": 2},
	{"id": "3-1", "path": "res://levels/3-1.txt", "world": 3},
	{"id": "3-2", "path": "res://levels/3-2.txt", "world": 3},
	{"id": "3-3", "path": "res://levels/3-3.txt", "world": 3},
	{"id": "3-4", "path": "res://levels/3-4.txt", "world": 3},
	{"id": "4-1", "path": "res://levels/4-1.txt", "world": 4},
	{"id": "4-2", "path": "res://levels/4-2.txt", "world": 4},
	{"id": "4-3", "path": "res://levels/4-3.txt", "world": 4},
	{"id": "4-4", "path": "res://levels/4-4.txt", "world": 4},
	{"id": "5-1", "path": "res://levels/5-1.txt", "world": 5},
	{"id": "5-2", "path": "res://levels/5-2.txt", "world": 5},
	{"id": "5-3", "path": "res://levels/5-3.txt", "world": 5},
	{"id": "5-4", "path": "res://levels/5-4.txt", "world": 5},
	{"id": "6-1", "path": "res://levels/6-1.txt", "world": 6},
	{"id": "6-2", "path": "res://levels/6-2.txt", "world": 6},
	{"id": "6-3", "path": "res://levels/6-3.txt", "world": 6},
	{"id": "6-4", "path": "res://levels/6-4.txt", "world": 6},
]
# The secret levels, outside the linear order: each opened by the silver bell
# in its "from" level (that level's secret: header names it).
const SECRET_LEVELS := [
	{"id": "1-S", "path": "res://levels/1-S.txt", "world": 1, "from": "1-3"},
	{"id": "2-S", "path": "res://levels/2-S.txt", "world": 2, "from": "2-2"},
	{"id": "3-S", "path": "res://levels/3-S.txt", "world": 3, "from": "3-3"},
	{"id": "4-S", "path": "res://levels/4-S.txt", "world": 4, "from": "4-2"},
	{"id": "5-S", "path": "res://levels/5-S.txt", "world": 5, "from": "5-3"},
	{"id": "6-S", "path": "res://levels/6-S.txt", "world": 6, "from": "6-2"},
]
const FINALE := "6-4"      # the Hush: clearing it opens the next difficulty
const WORLD_NAMES := {1: "The Sunken Cathedral", 2: "The Tallow Deep", 3: "The Bone Orchard", 4: "The Frozen Carillon",
		5: "The Shattered Sanctum", 6: "The Hushdeep"}
const WORLD_NAME := "The Sunken Cathedral"
# Each level's Dusk area header (spec §1.1): what area_of() answers when a
# level's file isn't in this build (the files' headers win; a test checks
# they agree).
const AREAS := {"1-1": 1, "1-2": 3, "1-3": 5, "1-4": 6, "2-1": 8, "2-2": 9, "2-3": 11, "2-4": 12,
		"3-1": 13, "3-2": 14, "3-3": 16, "3-4": 17, "4-1": 18, "4-2": 19, "4-3": 21, "4-4": 22,
		"5-1": 23, "5-2": 24, "5-3": 26, "5-4": 27, "6-1": 28, "6-2": 29, "6-3": 30, "6-4": 31,
		"1-S": 6, "2-S": 12, "3-S": 17, "4-S": 22, "5-S": 27, "6-S": 31}
const V2_CAP := 30             # v2's level cap
const DRAUGHT_LEVEL := "3-4"   # Mother Gravebough's: her first defeat gives Mother Yarrow's Second Draught
const RICH_HEAL := 0.10        # the Rich Draught: the flask heals 10 points more
const FLASK_MAX := 3           # flask charges, whatever adds them
const NOTICE_V3 := "v3_update"          # the map's "The bells below have woken" toast
const NOTICE_RELOCK := "nightfall_waits"  # the card for a v2 save's Nightfall, locked again
const NOTICE_POINTS := "new_points"      # the map's "New skills: N points to spend" (Vigil ranks come back as points)
const LOOK_KEYS := ["flame", "trim", "trim_color", "glow"]
const COSMETIC_FREE := ["flame:tallow", "color:calling"]   # owned by everyone
const MODES_SAVE := "res://scripts/modes/modes_save.gd"    # ModesSave (the modes stream), when it's there
const SETTINGS_DEFAULT := {"haptics": true, "numbers": "on", "shake": 1.0, "auto_salvage": true, "auto_equip": true,
		"auto_advance": false, "button_scale": 1.0, "candle_strength": "normal", "brightness": 0.0}
const SIGIL_REWARD_EVERY := 6
# v3's sigil milestones past #4 alternate (odd: a Legendary; even: a relic from
# the deepest world reached, else 100 x an ember's worth). In a build of
# Worlds 1-2 only every milestone past #4 is a Legendary, as in v2, so W1-W2
# pay as they did (the owner is two sigils from #6); the rule comes on with
# World 3 in the build (milestones_alternate). MILESTONE_ALTERNATE forces it.
const MILESTONE_ALTERNATE := false
const SLOTS := 3
# The Chandler by shop depth (spec §8.2): from that depth, the wares' rarities
# (at the hero's level, one slot each), the weakest-slot pick's rarity (the
# best of 6), the relic shelf's size and whether Waxley's Reserve is stocked.
# The first row is v2's shop exactly.
const SHOP_ROWS := [
	{"from": 0, "wares": ["magic", "magic", "rare"], "weak": "magic", "shelf": 3, "reserve": false},
	{"from": 13, "wares": ["magic", "magic", "rare", "rare"], "weak": "magic", "shelf": 3, "reserve": false},
	{"from": 18, "wares": ["magic", "magic", "rare", "rare"], "weak": "rare", "shelf": 3, "reserve": false},
	{"from": 23, "wares": ["magic", "magic", "rare", "rare"], "weak": "rare", "shelf": 4, "reserve": true},
	{"from": 28, "wares": ["magic", "rare", "rare", "rare", "rare"], "weak": "rare", "shelf": 4, "reserve": true},
]
const RESERVE_FROM := 23
const RICH_PRICE := 1600       # the Rich Draught
const RICH_AFTER := "4-4"      # sold once the Tinker of Hours has fallen (any difficulty)
const REKINDLE_BASE := 200     # Rekindle: 200 + 30 x the new item level
const REKINDLE_PER := 30
const REKINDLE_WORLD := 5      # open once the Shattered Sanctum is reached
# The first Dread killed in World 3 drops boots, in World 4 a charm (spec
# §8.1), while the hero has none: gift_slot.
const GIFT_SLOTS := {3: "boots", 4: "charm"}
const NOTICE_DEEP := "nightfall_warning"   # the one-time card for a hero too shallow for Nightfall or Witching
const DEEP_WARN_GAP := 5
# A boss restocks Waxley's Reserve only when it's a fight at the hero's depth:
# its level's area on that difficulty at least RESERVE_FROM and within
# RESERVE_BOSS_GAP of the hero's shop depth (so a replay of Tollgrave's short
# 1-4 never re-rolls it; p_progression §12.3: it stays an event).
const RESERVE_BOSS_GAP := 5
# "of the Lantern" (dim_resist) rolls only in a build with a world whose dims
# go through the dim pipeline. W1-W2's douse and the Gutterwing's latch do
# since the wave-1 merge (world_lights.gd dim_product), so it rolls from
# World 1 (T3+ items only, so not on W1-W2's Dusk levels).
const LANTERN_FROM_WORLD := 1

signal leveled_up(level: int)
signal marked(n: int)      # a Candlemark landed (n marks now)

var save_path := SAVE_PATH
var settings_path := SettingsLib.PATH
var data := {}
var LEVELS: Array = []     # the levels that exist in this build
var _temp_hero := {}       # tests and autoplay with no hero made yet
var _rng := RandomNumberGenerator.new()
var _settings := {}        # settings.json as last read (setting() is asked every tick)
var _settings_from := ""   # the path _settings came from
var last_melt := {}        # what the last equip() melted for room: {for (the worn uid), item, embers, old}
var slot_base := "user://save"   # slot 1 is <base>.json, slot n <base>_n.json (tests and autoplay move it)
var _disk := ""            # the save as last read or written ("" if none): what _flush compares with
var _main_ok := false      # save_path holds a whole save (read or written): a save backs it up as .bak
var _undo_slot := 0        # the slot whose last erase can still be undone
var _titles := {}          # level id -> its title (level_title)
var _areas := {}           # level id -> its area header (area_of)
var _borrowed := {}        # a hero lent for a mode (borrow_hero), never saved
var _modes_lib = null      # ModesSave's script once looked for (false: not in this build)
var milestone_alternate := MILESTONE_ALTERNATE   # tests turn it on to check the v3 rule
var _prizes := {}          # a secret prize made this session: its uid -> [level id, difficulty] (paid when taken)
var _prizes_paid := []     # "id|diff" of prizes taken since the last record_result
var embers_spent := 0      # embers paid at the Chandler since the playlog's last line (playlog.gd; never saved)


func _init() -> void:
	_refresh_levels()
	reset()


func _ready() -> void:
	_setup_input()
	_pick_slot()
	load_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_purge_erased()   # an erase can be undone until the app quits


func _refresh_levels() -> void:
	LEVELS = ALL_LEVELS.filter(func(l): return FileAccess.file_exists(l["path"]))
	Items.lantern_live = Items.LANTERN_LIVE and _built_from(LANTERN_FROM_WORLD)


func _built_from(w: int) -> bool:
	## Whether a level of world w or deeper is in this build.
	for l in LEVELS:
		if int(l["world"]) >= w:
			return true
	return false


func reset() -> void:
	## An empty save in memory (the file isn't touched), and the settings
	## read fresh from their file.
	data = {"version": VERSION, "difficulty": "dusk", "unlocked": {"dusk": 1, "nightfall": 0, "witching": 0},
			"levels": {"dusk": {}, "nightfall": {}, "witching": {}}, "embers": 0, "relics": [], "sigil_rewards": 0,
			"seen": [], "hero": "", "heroes": {}, "veteran": 0, "run_counter": 0, "bells": 0, "v1_levels": {},
			"saved_at": 0, "unbanked": 0,
			"secrets": {"dusk": {}, "nightfall": {}, "witching": {}}, "flask": {"draughts": 0, "rich": false},
			"legends_found": [], "modes": _modes_defaults(), "suspend": {}, "notices": [NOTICE_V3, NOTICE_POINTS], "relocked": {},
			"bosses": 0, "hero_name": Story.HERO_NAME}
	_temp_hero = {}
	_prizes_paid = []
	reload_settings()


func _setup_input() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "down": [KEY_DOWN, KEY_S],
		"jump": [KEY_SPACE, KEY_Z, KEY_W, KEY_K], "attack": [KEY_X, KEY_J, KEY_SHIFT],
		"special": [KEY_C, KEY_L, KEY_E], "flask": [KEY_Q, KEY_TAB], "equip": [KEY_R, KEY_ENTER],
		"pause": [KEY_ESCAPE, KEY_P],
		# v3: climbing on a vine (the left pad's slide up; touch_controls sets
		# it too). The arrows are the four ways, as a pad's are: the Up arrow
		# climbs without ever leaping off (a fresh jump with a way held does),
		# and Space, Z and W jump.
		"up": [KEY_UP],
	}
	# A game controller (MFi, Xbox, PlayStation; every one connected): the
	# d-pad and the left stick move, A jumps, X attacks, Y is the Special,
	# the left shoulder drinks the flask, the right one takes a pickup,
	# Menu pauses. The map runs on these actions too (the other screens are
	# taps).
	var buttons := {
		"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN],
		"jump": [JOY_BUTTON_A], "attack": [JOY_BUTTON_X], "special": [JOY_BUTTON_Y],
		"flask": [JOY_BUTTON_LEFT_SHOULDER], "equip": [JOY_BUTTON_RIGHT_SHOULDER], "pause": [JOY_BUTTON_START],
	}
	const STICK_DEAD := 0.4   # the stick's dead zone (a worn stick drifts); keys and touch press at full strength
	var stick := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for b in buttons.get(action, []):
			var ev := InputEventJoypadButton.new()
			ev.device = -1   # any controller
			ev.button_index = b
			InputMap.action_add_event(action, ev)
		if stick.has(action):
			var ev := InputEventJoypadMotion.new()
			ev.device = -1
			ev.axis = stick[action][0]
			ev.axis_value = stick[action][1]
			InputMap.action_add_event(action, ev)
			InputMap.action_set_deadzone(action, STICK_DEAD)


# ---------------------------------------------------------------- save file

func load_save() -> void:
	## The save at save_path, or when it's missing or can't be read, the good
	## one it replaced (<save>.bak), else a fresh save in memory. A save that
	## can't be read is copied aside as .bad first (and isn't written over
	## until something saves). Embers a level left unbanked (the app sent
	## away mid-level, then ended) go into the purse. An older save migrates
	## (every slot on its own), and the file it came from is kept first as
	## <save>.v<its version>, once.
	reset()
	_refresh_levels()
	_disk = ""
	_main_ok = false
	var slot := current_slot()
	var from_path := save_path
	var text := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	var parsed = _parse_save(text, slot)
	if parsed == null:
		if text != "":
			# Unreadable (or a v1 save outside slot 1): keep a copy rather than
			# overwrite it on the next save.
			DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bad"))
		var bak := save_path + ".bak"
		from_path = bak
		parsed = _parse_save(FileAccess.get_file_as_string(bak) if FileAccess.file_exists(bak) else "", slot)
		if parsed == null:
			return
		if not FileAccess.file_exists(save_path):
			# Gone missing: the backup is the save again.
			_main_ok = DirAccess.copy_absolute(ProjectSettings.globalize_path(bak), ProjectSettings.globalize_path(save_path)) == OK
	else:
		_main_ok = true
	var was := int(_num(parsed.get("version", 1)))
	var old := was < VERSION
	var file_time := int(FileAccess.get_modified_time(from_path)) if FileAccess.file_exists(from_path) else 0
	if old:
		_archive(from_path, was)
	parsed = migrate(parsed)
	var vigil_was := _vigil_of(parsed)
	for k in data:
		if parsed.has(k):
			data[k] = parsed[k]
	_sanitize()
	_note_points_back(vigil_was)
	var folded := _fold_unbanked()
	_disk = JSON.stringify(data, "\t", true, true)
	if old or folded:
		# A write that only migrates keeps the slot's last-played time (its
		# saved_at, else its file's): the saves screen and last_slot go by
		# it. Embers folded in were a real game's, so they stamp it.
		if old and not folded and int(_num(data.get("saved_at", 0))) <= 0:
			data["saved_at"] = file_time
		save(old and not folded)


func _vigil_of(p: Dictionary) -> Dictionary:
	## Each hero's [Vigil ranks, unspent points] as the file holds them
	## (before _settle_points).
	var out := {}
	var hs = p.get("heroes", {})
	if hs is Dictionary:
		for cls in hs:
			if hs[cls] is Dictionary:
				var h: Dictionary = hs[cls]
				out[str(cls)] = [maxi(int(_num(h.get("vigil", 0))), 0), maxi(int(_num(h.get("points", 0))), 0)]
	return out


func _note_points_back(was: Dictionary) -> void:
	## A hero whose Vigil ranks the settle just turned back into points (a v2
	## hero under the deeper tree, spec §9.2.4): the points he has to spend
	## now that he didn't, in data.points_back, which the map's one-time "New
	## skills: N points to spend" card reads. Only while that card is still
	## owed (a new save has it marked from the start), and only when Vigil
	## ranks came back; kept until the card is closed.
	if (data["notices"] as Array).has(NOTICE_POINTS):
		return
	var back := 0
	for cls in was:
		if not (data["heroes"] as Dictionary).has(cls):
			continue
		var h: Dictionary = data["heroes"][cls]
		if int(h["vigil"]) < int(was[cls][0]):
			back += maxi(int(h["points"]) - int(was[cls][1]), int(was[cls][0]) - int(h["vigil"]))
	if back > 0:
		data["points_back"] = int(_num(data.get("points_back", 0))) + back


func points_back() -> int:
	## The points a load gave back from Vigil ranks, for the map's card (0: none).
	return maxi(int(_num(data.get("points_back", 0))), 0)


func _archive(from_path: String, version: int) -> void:
	## Keeps the file a migration reads as <save>.v<version>, the first time
	## only: the game as it was before the update, whatever happens after.
	## Nothing reads it; nothing writes over it.
	var dest := save_path + ".v%d" % maxi(version, 1)
	if FileAccess.file_exists(dest) or not FileAccess.file_exists(from_path):
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(dest))


func _parse_save(text: String, slot: int):
	## A save's text as a Dictionary this slot can read, else null.
	if text.strip_edges() == "":
		return null
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary) or not _may_migrate(j.data, slot):
		return null
	return j.data


func _fold_unbanked() -> bool:
	## Embers a level held unbanked when the app was sent away (and then
	## ended there) join the purse, as leaving the level would have banked
	## them. True if there were any.
	var n := int(_num(data.get("unbanked", 0)))
	data["unbanked"] = 0
	if n <= 0:
		return false
	data["embers"] = int(data["embers"]) + n
	return true


func carry_embers(n: int) -> void:
	## The embers a level holds right now, not banked (world.gd: written when
	## the app is sent away, 0 once they're banked, spilt or the level is
	## left). Only a later load_save turns them into purse embers; it never
	## banks them in the level.
	data["unbanked"] = maxi(n, 0)


func unbanked() -> int:
	return int(_num(data.get("unbanked", 0)))


func migrate(p: Dictionary) -> Dictionary:
	## An older save becomes the current one, a step at a time: v1 -> v2
	## (slot 1 only reads a v1 save; see _may_migrate), then v2 -> v3. A save
	## at VERSION (or newer) comes back as it is.
	var v := int(_num(p.get("version", 1)))
	if v >= VERSION:
		return p
	var out := p
	if v < 2:
		out = _v1_to_v2(out)
	return _v2_to_v3(out)


func _v1_to_v2(p: Dictionary) -> Dictionary:
	## A v1 save becomes v2. Unlocks move under Dusk (at least one past the
	## last level cleared), the relics become the codex, the embers stay
	## (+150 for a veteran), haptics moves to settings, veteran = levels
	## cleared, and the v1 records are kept aside in "v1_levels".
	var levels: Dictionary = p.get("levels", {}) if p.get("levels") is Dictionary else {}
	var cleared := 0
	var last := -1
	for id in levels:
		if levels[id] is Dictionary and bool(levels[id].get("cleared", false)):
			cleared += 1
			for i in ALL_LEVELS.size():
				if ALL_LEVELS[i]["id"] == id:
					last = maxi(last, i)
	var out := {"version": 2}
	out["unlocked"] = {"dusk": clampi(maxi(int(_num(p.get("unlocked", 1))), last + 2), 1, ALL_LEVELS.size()), "nightfall": 0, "witching": 0}
	out["levels"] = {"dusk": {}, "nightfall": {}, "witching": {}}
	out["v1_levels"] = levels.duplicate(true)
	out["relics"] = p.get("relics", []) if p.get("relics") is Array else []
	out["veteran"] = cleared
	out["embers"] = maxi(int(_num(p.get("embers", 0))), 0) + (VETERAN_EMBERS if cleared > 0 else 0)
	out["seen"] = []
	out["heroes"] = {}
	out["hero"] = ""
	if p.has("haptics"):
		set_setting("haptics", _flag(p["haptics"]))
	return out


func _v2_to_v3(p: Dictionary) -> Dictionary:
	## v2 -> v3 (spec §9.2, contract §8.2, and the owner's answer on
	## Nightfall). Everything v2 held is kept; what changes:
	##   - unlocks: max(unlocked, index of the highest level cleared + 2) on
	##     each difficulty (v2 clamped them at its 8 levels), at most 24;
	##   - Nightfall and Witching lock again until the Hush falls on the
	##     difficulty below: their unlocks go into "relocked" (unlocked 0),
	##     their records stay, and they count again when it reopens;
	##   - the difficulty is Dusk, where the new worlds are;
	##   - each hero: "deepest" (the highest Dusk level cleared's area, at
	##     least level - 1: the relocked difficulties don't count) and "look";
	##   - legends_found: every Legendary a hero holds;
	##   - notices empty (so the v3 cards show once); secrets, flask and
	##     suspend empty. Skill points settle with the tree in _sanitize.
	var out: Dictionary = p.duplicate(true)
	out["version"] = VERSION
	var unl: Dictionary = p.get("unlocked", {}) if p.get("unlocked") is Dictionary else {}
	var lv: Dictionary = p.get("levels", {}) if p.get("levels") is Dictionary else {}
	var unlocked := {}
	var relocked := {}
	for dd in Combat.DIFFS:
		var u := maxi(int(_num(unl.get(dd, 0))), 0)
		var hi := _highest_cleared(lv.get(dd, {}))
		if hi >= 0:
			u = maxi(u, hi + 2)
		if dd == "dusk":
			u = maxi(u, 1)
		u = mini(u, ALL_LEVELS.size())
		if dd != "dusk" and u > 0:
			relocked[dd] = u
			u = 0
		unlocked[dd] = u
	out["unlocked"] = unlocked
	out["relocked"] = relocked
	out["difficulty"] = "dusk"
	var deep := _deepest_cleared(lv)
	var found: Array = []
	var hs = out.get("heroes", {})
	if hs is Dictionary:
		for cls in hs:
			var h = hs[cls]
			if not (h is Dictionary):
				continue
			# v2 stopped levels at 30 but kept the XP a last gain carried past
			# it: that XP is worth its levels now.
			var xp := int(_num(h.get("xp", 0)))
			if int(_num(h.get("level", 1))) >= V2_CAP and xp >= Progression.total_to(V2_CAP + 1):
				h["level"] = maxi(int(_num(h.get("level", 1))), Progression.level_of(xp))
			if not h.has("deepest"):
				h["deepest"] = maxi(deep, int(_num(h.get("level", 1))) - 1)
			if not (h.get("look") is Dictionary):
				h["look"] = Hero.LOOK_DEFAULT.duplicate()
			_legends_held(h, found)
	var had = p.get("legends_found", [])
	for id in (had if had is Array else []):
		if str(id) != "" and not found.has(str(id)):
			found.append(str(id))
	out["legends_found"] = found
	out["notices"] = []
	out["secrets"] = {"dusk": {}, "nightfall": {}, "witching": {}}
	out["flask"] = {"draughts": 0, "rich": false}
	out["suspend"] = {}
	return out


func _highest_cleared(recs) -> int:
	## The ALL_LEVELS index of the furthest main level cleared in these
	## records, or -1.
	var hi := -1
	if not (recs is Dictionary):
		return hi
	for i in ALL_LEVELS.size():
		var r = recs.get(ALL_LEVELS[i]["id"])
		if r is Dictionary and _flag(r.get("cleared", false)):
			hi = i
	return hi


func _deepest_cleared(lv: Dictionary) -> int:
	## The deepest Dusk area a v2 save cleared a level at: what a migrated
	## hero's deepest starts at (with at least level - 1). Only Dusk counts:
	## the migration locks Nightfall and Witching again until the Hush, "like
	## a new player", so their clears (v2's areas + 10 / + 20) don't deepen
	## the Chandler's stock or the Legendary pool before then; starting a
	## level there once it reopens does (note_area).
	var best := 0
	var recs = lv.get("dusk", {})
	if not (recs is Dictionary):
		return best
	for id in recs:
		if recs[id] is Dictionary and _flag(recs[id].get("cleared", false)) and area_of(str(id)) > 0:
			best = maxi(best, area_of(str(id)))
	return best


static func _legends_held(h: Dictionary, into: Array) -> void:
	## Every Legendary power a hero holds (worn or in the satchel), into
	## `into` (once each).
	var items: Array = []
	var eq = h.get("equip", {})
	if eq is Dictionary:
		items.append_array(eq.values())
	var sat = h.get("satchel", [])
	if sat is Array:
		items.append_array(sat)
	for it in items:
		if it is Dictionary:
			var id := str(it.get("legend", ""))
			if id != "" and not into.has(id):
				into.append(id)


static func _num(v) -> float:
	return float(v) if (v is float or v is int) else 0.0


static func _flag(v) -> bool:
	## A saved true/false, whatever it came back as (junk is false).
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	return false


func _sanitize() -> void:
	## JSON brings every number back as a float, and an old or hand-edited
	## save can miss keys or hold junk: fix the types, fill the gaps, drop
	## what's unknown.
	var fresh := data.duplicate(true)
	reset()
	var d := data
	d["difficulty"] = str(fresh.get("difficulty", "dusk"))
	d["embers"] = maxi(int(_num(fresh.get("embers", 0))), 0)
	d["sigil_rewards"] = maxi(int(_num(fresh.get("sigil_rewards", 0))), 0)
	d["veteran"] = maxi(int(_num(fresh.get("veteran", 0))), 0)
	d["run_counter"] = maxi(int(_num(fresh.get("run_counter", 0))), 0)
	d["bells"] = maxi(int(_num(fresh.get("bells", 0))), 0)
	d["saved_at"] = maxi(int(_num(fresh.get("saved_at", 0))), 0)
	d["unbanked"] = maxi(int(_num(fresh.get("unbanked", 0))), 0)
	d["v1_levels"] = fresh.get("v1_levels", {}) if fresh.get("v1_levels") is Dictionary else {}
	var unl = fresh.get("unlocked", {})
	for dd in Combat.DIFFS:
		d["unlocked"][dd] = clampi(int(_num(unl.get(dd, 0))) if unl is Dictionary else 0, 0, ALL_LEVELS.size())
	d["unlocked"]["dusk"] = maxi(int(d["unlocked"]["dusk"]), 1)
	var lv = fresh.get("levels", {})
	for dd in Combat.DIFFS:
		var recs = lv.get(dd, {}) if lv is Dictionary else {}
		if not (recs is Dictionary):
			continue
		for id in recs:
			if recs[id] is Dictionary:
				d["levels"][dd][str(id)] = _clean_record(recs[id])
	for r in (fresh.get("relics", []) if fresh.get("relics") is Array else []):
		if (r is String or r is StringName) and Relics.known(str(r)) and not (d["relics"] as Array).has(str(r)):
			d["relics"].append(str(r))
	for s in (fresh.get("seen", []) if fresh.get("seen") is Array else []):
		if not (d["seen"] as Array).has(str(s)):
			d["seen"].append(str(s))
	var hs = fresh.get("heroes", {})
	if hs is Dictionary:
		for cls in hs:
			if Classes.ALL.has(cls) and hs[cls] is Dictionary:
				d["heroes"][cls] = _clean_hero(cls, hs[cls])
	d["hero"] = str(fresh.get("hero", ""))
	if not d["heroes"].has(d["hero"]):
		d["hero"] = "" if d["heroes"].is_empty() else str(d["heroes"].keys()[0])
	if not Combat.DIFF.has(d["difficulty"]) or not diff_open(d["difficulty"]):
		d["difficulty"] = "dusk"
	# v3's keys (contract §8.1); reset() gave each its default.
	var sec = fresh.get("secrets", {})
	for dd in Combat.DIFFS:
		var recs = sec.get(dd, {}) if sec is Dictionary else {}
		if not (recs is Dictionary):
			continue
		for id in recs:
			if is_secret(str(id)) and recs[id] is Dictionary:
				d["secrets"][dd][str(id)] = {"found": _flag(recs[id].get("found", false)),
						"cleared": _flag(recs[id].get("cleared", false)), "prize": _flag(recs[id].get("prize", false))}
	var fl = fresh.get("flask", {})
	if fl is Dictionary:
		d["flask"]["draughts"] = clampi(int(_num(fl.get("draughts", 0))), 0, 1)
		d["flask"]["rich"] = _flag(fl.get("rich", false))
	var lf = fresh.get("legends_found", [])
	for id in (lf if lf is Array else []):
		if (id is String or id is StringName) and str(id) != "" and not (d["legends_found"] as Array).has(str(id)):
			d["legends_found"].append(str(id))
	for cls in d["heroes"]:
		_legends_held(d["heroes"][cls], d["legends_found"])
	d["modes"] = _modes_clean(fresh.get("modes", {}))
	d["suspend"] = (fresh["suspend"] as Dictionary).duplicate(true) if fresh.get("suspend") is Dictionary else {}
	d["notices"] = []
	for n in (fresh.get("notices", []) if fresh.get("notices") is Array else []):
		if (n is String or n is StringName) and not (d["notices"] as Array).has(str(n)):
			d["notices"].append(str(n))
	var rl = fresh.get("relocked", {})
	for dd in Combat.DIFFS:
		var n := clampi(int(_num(rl.get(dd, 0))) if rl is Dictionary else 0, 0, ALL_LEVELS.size())
		if dd != "dusk" and n > 0:
			d["relocked"][dd] = n
	d["bosses"] = maxi(int(_num(fresh.get("bosses", 0))), 0)
	d["hero_name"] = Story.clean_name(fresh.get("hero_name", ""))
	# Only a save whose Vigil ranks came back as points holds points_back
	# (every other save is written without the key).
	var pb := maxi(int(_num(fresh.get("points_back", 0))), 0)
	if pb > 0:
		d["points_back"] = pb


func _clean_record(r: Dictionary) -> Dictionary:
	var out := r.duplicate(true)
	out["cleared"] = _flag(r.get("cleared", false))
	var sig: Array = [false, false, false]
	var got = r.get("sigils", [])
	if got is Array:
		for i in mini(got.size(), 3):
			sig[i] = _flag(got[i])
	out["sigils"] = sig
	out["best_time"] = maxf(_num(r.get("best_time", 0.0)), 0.0)
	out["best_embers"] = maxi(int(_num(r.get("best_embers", 0))), 0)
	out["boss_first"] = _flag(r.get("boss_first", false))
	out["dread"] = _flag(r.get("dread", false))
	return out


func _clean_hero(cls: String, src: Dictionary) -> Dictionary:
	var h := Hero.blank(cls)
	for k in src:
		if not h.has(k):
			h[k] = src[k]   # keep what a newer build may have added
	h.erase("respecs")   # an old count of respecs that nothing ever read
	h["cls"] = cls
	h["level"] = clampi(int(_num(src.get("level", 1))), 1, Progression.CAP)
	var lo := Progression.total_to(int(h["level"]))
	var hi := Progression.total_to(int(h["level"]) + 1) - 1 if int(h["level"]) < Progression.CAP else 1 << 30
	h["xp"] = clampi(int(_num(src.get("xp", lo))), lo, hi)
	h["points"] = maxi(int(_num(src.get("points", 0))), 0)
	h["vigil"] = maxi(int(_num(src.get("vigil", 0))), 0)
	h["wares_seed"] = maxi(int(_num(src.get("wares_seed", 0))), 0)
	h["deepest"] = maxi(int(_num(src.get("deepest", 0))), 0)
	var lk = src.get("look", {})
	for k in LOOK_KEYS:
		if lk is Dictionary and lk.has(k) and (lk[k] is String or lk[k] is StringName):
			h["look"][k] = str(lk[k])
	var sk = src.get("skills", {})
	if sk is Dictionary:
		for id in sk:
			var n := Classes.find_node(cls, str(id))
			if n.is_empty():
				continue
			h["skills"][str(id)] = clampi(int(_num(sk[id])), 1 if n["branch"] == -1 else 0, int(n["max"]))
	var eq = src.get("equip", {})
	for slot in Items.SLOTS:
		var it = _clean_item(eq.get(slot) if eq is Dictionary else null)
		h["equip"][slot] = it if it != null and it["slot"] == slot else null
	for it in (src.get("satchel", []) if src.get("satchel") is Array else []):
		var c = _clean_item(it)
		if c != null:
			h["satchel"].append(c)
	for it in (src.get("wares", []) if src.get("wares") is Array else []):
		h["wares"].append(_clean_item(it))
	if src.has("reserve"):
		# Waxley's Reserve (made only once the hero is deep enough): the item, or
		# null once bought; the boss count it was stocked at; not yet shown.
		h["reserve"] = _clean_item(src.get("reserve"))
		h["reserve_seed"] = int(_num(src.get("reserve_seed", 0)))
		h["reserve_new"] = _flag(src.get("reserve_new", false))
	var codex: Array = data["relics"]
	for r in (src.get("belt", []) if src.get("belt") is Array else []):
		if codex.has(r) and not (h["belt"] as Array).has(r):
			h["belt"].append(r)
	h["belt"] = (h["belt"] as Array).slice(0, Progression.belt_slots(int(h["level"])))
	_settle_points(h)
	return h


func _clean_item(it):
	## A saved item with its numbers cast back, or null if it isn't one.
	if not (it is Dictionary) or not Items.SLOTS.has(str(it.get("slot", ""))):
		return null
	var out: Dictionary = it.duplicate(true)
	out["slot"] = str(it["slot"])
	out["ilvl"] = maxi(int(_num(it.get("ilvl", 1))), 1)
	out["tier"] = clampi(int(_num(it.get("tier", Items.tier_of(out["ilvl"])))), 1, Items.TIERS)
	out["rarity"] = str(it.get("rarity", "common")) if Items.RARITIES.has(str(it.get("rarity", ""))) else "common"
	out["legend"] = str(it.get("legend", "")) if Items.LEGENDS.has(str(it.get("legend", ""))) else ""
	if out["rarity"] == "legendary" and out["legend"] == "":
		out["rarity"] = "rare"
	out["cls"] = str(it.get("cls", ""))
	out["uid"] = str(it.get("uid", "")) if str(it.get("uid", "")) != "" else "i%08x" % (_rng.randi() & 0x7fffffff)
	out["base"] = str(it.get("base", Items.base_name(out["slot"], out["cls"], out["tier"])))
	out["name"] = str(it.get("name", out["base"]))
	var imp = it.get("implicit", {})
	out["implicit"] = {}
	if imp is Dictionary:
		for k in imp:
			out["implicit"][k] = str(imp[k]) if k == "id" else _num(imp[k])
	out["affixes"] = []
	for a in (it.get("affixes", []) if it.get("affixes") is Array else []):
		if a is Dictionary and Items.AFFIXES.has(str(a.get("id", ""))):
			out["affixes"].append({"id": str(a["id"]), "t": clampi(int(_num(a.get("t", 1))), 1, Items.TIERS), "v": _num(a.get("v", 0.0))})
	return out


func save(keep_time := false) -> void:
	## Written whole or not at all (a side file moved over the save only once
	## every byte went down: an app killed mid-write or a full disk leaves the
	## last save as it was). The save it replaces, if that was a whole one,
	## is kept as <save>.bak for load_save to fall back to. keep_time: a write
	## that changes nothing played (a migration) keeps saved_at.
	if not keep_time or int(_num(data.get("saved_at", 0))) <= 0:
		data["saved_at"] = int(Time.get_unix_time_from_system())   # the saves screen's "last played"
	var text := JSON.stringify(data, "\t", true, true)
	if SettingsLib.write_whole(save_path, text, _main_ok):
		_disk = text
		_main_ok = true


static func _found(path: String) -> String:
	## The file a slot's game is in: its save, else the backup of it that's
	## left (load_save reads that), else "" (an empty slot).
	if FileAccess.file_exists(path):
		return path
	return path + ".bak" if FileAccess.file_exists(path + ".bak") else ""


# ---------------------------------------------------------------- save slots
# Each slot is a whole save: heroes, embers, relics, unlocks, story seen, the
# Chandler's stock, the run counter. Switching reads everything afresh, and
# writing one slot never touches another. A test or tool that points
# save_path elsewhere before launch gets its slots beside that file instead
# (slot_base), so it never sees a real one.

func slot_count() -> int:
	return SLOTS


func slot_path(n: int) -> String:
	## Slot 1 is the save there has always been, user://save.json; slot n is
	## user://save_n.json.
	return slot_base + (".json" if n <= 1 else "_%d.json" % n)


func current_slot() -> int:
	## The slot being played, or 0 when the save is somewhere else.
	for n in range(1, SLOTS + 1):
		if slot_path(n) == save_path:
			return n
	return 0


func last_slot() -> int:
	## The slot played last (the shared settings remember it; 1 before any).
	## If that one has been erased since, the save played most recently of
	## those left stands in for it.
	var n := clampi(int(_num(setting("last_slot"))), 1, SLOTS)
	if _found(slot_path(n)) != "":
		return n
	var best := 0
	var best_t := 0
	for k in range(1, SLOTS + 1):
		if _found(slot_path(k)) != "" and (best == 0 or _played_at(k) > best_t):
			best = k
			best_t = _played_at(k)
	return best if best > 0 else n


func _played_at(n: int) -> int:
	## When slot n was last saved: its "saved_at", else its file's time
	## (its backup's, if that's all there is).
	var path := _found(slot_path(n))
	if path == "":
		return 0
	var p = JSON.parse_string(FileAccess.get_file_as_string(path))
	var t := int(_num(p.get("saved_at", 0))) if p is Dictionary else 0
	return t if t > 0 else int(FileAccess.get_modified_time(path))


func _pick_slot(autoplay := autoplay_launch(), launch := app_launch()) -> void:
	## At launch: open the slot played last. A save pointed elsewhere before
	## launch (a test's) keeps its path, and its slots live beside it. The
	## bot (main's --autoplay) has its own save and slots: the player's are
	## never read, purged or written. The game's own launch (launch) lets the
	## last session's erase go: iOS mostly ends an app without a quit.
	if save_path == SAVE_PATH and autoplay:
		save_path = AUTOPLAY_SAVE
	if save_path != SAVE_PATH:
		slot_base = save_path.trim_suffix(".json")
		return
	if launch:
		_purge_erased()   # a new launch: the last session's undo is gone
	save_path = slot_path(last_slot())


static func app_launch() -> bool:
	## The game itself starting (its main loop the plain SceneTree), not a
	## --script run of a test or a tool.
	var ml := Engine.get_main_loop()
	return ml == null or ml.get_script() == null


static func autoplay_launch() -> bool:
	## A debug build launched with --autoplay=<level> (see main.gd).
	if not OS.is_debug_build():
		return false
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if str(a).begins_with("--autoplay="):
			return true
	return false


func _may_migrate(p: Dictionary, slot: int) -> bool:
	## Only slot 1 (or a save outside the slots) migrates a v1 save. Slots 2
	## and 3 were made by v2, so a v1 file there can't be read; a v2 save
	## migrates in any slot.
	return slot <= 1 or int(_num(p.get("version", 1))) >= 2


func use_slot(n: int) -> void:
	## Plays slot n from now on: the save being played keeps any change not
	## written yet, then everything is read afresh from slot n (an empty slot
	## is a fresh save in memory until something saves it).
	n = clampi(n, 1, SLOTS)
	_flush()
	save_path = slot_path(n)
	last_melt = {}
	load_save()
	if int(_num(setting("last_slot"))) != n:
		set_setting("last_slot", n)


func open_last() -> void:
	## The title shows the slot played last. If that isn't the one open (the
	## one open was just erased, or an Undo brought back the one played
	## before), it's opened now, the way use_slot opens one, but without
	## remembering it as played: nothing is written.
	var n := current_slot()
	var m := last_slot()
	if n == 0 or m == n or _found(slot_path(m)) == "":
		return
	_flush()
	save_path = slot_path(m)
	last_melt = {}
	load_save()


func new_game(n: int) -> void:
	## A new game in slot n: what was there is erased (undoable, see
	## erase_slot) and a fresh v2 save is written, nothing carried over (no
	## veteran, no story seen). The settings stay as they are.
	n = clampi(n, 1, SLOTS)
	_flush()
	if _found(slot_path(n)) != "":
		erase_slot(n)   # its save and backup kept aside for the Undo
	save_path = slot_path(n)
	last_melt = {}
	load_save()
	save()
	set_setting("last_slot", n)


func erase_slot(n: int) -> bool:
	## Empties slot n. One step of undo: its file is kept as <file>.erased,
	## and its backup as <file>.erased.bak, until the next erase or the app
	## quits (restore_slot brings both back, so the card shows again what it
	## showed, the backup's game if the save couldn't be read). Erasing the
	## slot being played leaves a fresh save in memory. False if it was
	## empty (neither file there).
	n = clampi(n, 1, SLOTS)
	var path := slot_path(n)
	if _found(path) == "":
		return false
	_purge_erased()
	var g := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(g, g + ".erased") != OK:
		return false
	if FileAccess.file_exists(path + ".bak") and DirAccess.rename_absolute(g + ".bak", g + ".erased.bak") != OK:
		if not FileAccess.file_exists(path + ".erased"):
			return false   # only the backup was there, and it stays
		DirAccess.remove_absolute(g + ".bak")   # the slot is empty; the Undo still has the save
	_undo_slot = n
	if save_path == path:
		reset()
		_refresh_levels()
		_disk = ""
		_main_ok = false
		last_melt = {}
	return true


func can_restore(n: int) -> bool:
	## The last erase was slot n, its files are still kept, and the slot is
	## still empty.
	var path := slot_path(n)
	return _undo_slot == n and (FileAccess.file_exists(path + ".erased") or FileAccess.file_exists(path + ".erased.bak")) \
			and _found(path) == ""


func restore_slot(n: int) -> bool:
	## Undoes the last erase, if it was slot n (see can_restore): the save
	## and its backup both come back.
	if not can_restore(n):
		return false
	var path := slot_path(n)
	var g := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path + ".erased") and DirAccess.rename_absolute(g + ".erased", g) != OK:
		return false
	if FileAccess.file_exists(path + ".erased.bak"):
		DirAccess.rename_absolute(g + ".erased.bak", g + ".bak")
	_undo_slot = 0
	if save_path == path:
		load_save()
	return true


func _purge_erased() -> void:
	## Lets the last erase go for good.
	for n in range(1, SLOTS + 1):
		for p in [slot_path(n) + ".erased", slot_path(n) + ".erased.bak"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_undo_slot = 0


func _flush() -> void:
	## Writes the save being played if it holds changes not on disk yet (a
	## level left early keeps its XP and embers in memory till the next
	## save), so switching slots loses nothing. Never makes a file that isn't
	## there, or writes over one that couldn't be read.
	if _disk != "" and FileAccess.file_exists(save_path) and _unsaved():
		save()


func _unsaved() -> bool:
	## The save in memory holds something its file doesn't. The blank records
	## the map adds as it reads levels never played (level_record) don't
	## count: looking at a save isn't playing it, and mustn't move its card's
	## "last played".
	if JSON.stringify(data, "\t", true, true) == _disk:
		return false
	var mine = JSON.parse_string(JSON.stringify(data))
	var disk = JSON.parse_string(_disk)
	if not (mine is Dictionary and disk is Dictionary):
		return true
	for d in [mine, disk]:
		var lv = d.get("levels", {})
		if lv is Dictionary:
			for dd in lv:
				if lv[dd] is Dictionary:
					for id in (lv[dd] as Dictionary).keys():
						if _blank(lv[dd][id]):
							lv[dd].erase(id)
	return JSON.stringify(mine, "", true) != JSON.stringify(disk, "", true)


static func _blank(v) -> bool:
	## Nothing in it: false, 0 or "", or only those inside.
	if v is Dictionary or v is Array:
		for k in v:
			if not _blank(v[k] if v is Dictionary else k):
				return false
		return true
	if v is bool or v is int or v is float:
		return not bool(v)
	return str(v) == ""


func slot_summary(n: int) -> Dictionary:
	## What the saves screen shows for slot n, without loading it: {} when
	## it's empty, {slot, bad: true} when its file can't be read (a copy is
	## kept beside it as .bad, as load_save keeps one), else {slot, cls, name,
	## level, callings, furthest (a level id), furthest_title, bells, sigils
	## (every difficulty), embers, diffs (those open), played (unix time),
	## veteran, world (the furthest level's), hero_name (the hero's own;
	## name is his calling's)}. cls and name are "" before a calling is
	## chosen.
	n = clampi(n, 1, SLOTS)
	var path := slot_path(n)
	var found := _found(path)
	if found == "":
		return {}
	var d: Dictionary = data if (path == save_path and _disk != "") else _peek(path, n)
	if d.get("bad", false):
		return {"slot": n, "bad": true}
	var hs: Dictionary = d["heroes"]
	var cls := str(d["hero"])
	var far := 0
	var diffs: Array = []
	var sig := 0
	for dd in Combat.DIFFS:
		var u := int(_num(d["unlocked"].get(dd, 0)))
		if dd == "dusk" or u > 0:
			diffs.append(dd)
		far = maxi(far, mini(u, LEVELS.size()))
		for id in d["levels"][dd]:
			for s in d["levels"][dd][id].get("sigils", []):
				if s:
					sig += 1
	var fid := str(LEVELS[far - 1]["id"]) if far > 0 else ""
	var fworld := int(LEVELS[far - 1]["world"]) if far > 0 else 1
	var played := int(_num(d.get("saved_at", 0)))
	if played <= 0:
		played = int(FileAccess.get_modified_time(found))
	return {"slot": n, "cls": cls if hs.has(cls) else "", "name": str(Classes.info(cls)["name"]) if hs.has(cls) else "",
			"level": int(hs[cls]["level"]) if hs.has(cls) else 0, "callings": hs.size(), "furthest": fid,
			"furthest_title": level_title(fid), "bells": int(_num(d["bells"])), "sigils": sig,
			"embers": int(_num(d["embers"])), "diffs": diffs, "played": played, "veteran": int(_num(d["veteran"])),
			"world": fworld, "hero_name": str(d.get("hero_name", Story.HERO_NAME))}


func _peek(path: String, slot: int) -> Dictionary:
	## A slot's save read as load_save would read it (its .bak if it's
	## missing or can't be read), into a copy: nothing is loaded or written
	## (a v1 save's haptics stay out of the settings). {"bad": true} when
	## neither can.
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var parsed = _parse_save(text, slot)
	if parsed == null:
		if text != "":
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bad"))
		var bak := path + ".bak"
		parsed = _parse_save(FileAccess.get_file_as_string(bak) if FileAccess.file_exists(bak) else "", slot)
		if parsed == null:
			return {"bad": true}
	var p: Dictionary = (parsed as Dictionary).duplicate(true)
	p.erase("haptics")
	p = migrate(p)
	var keep: Dictionary = data
	var keep_temp: Dictionary = _temp_hero
	reset()
	for k in data:
		if p.has(k):
			data[k] = p[k]
	_sanitize()
	_fold_unbanked()
	var out: Dictionary = data
	data = keep
	_temp_hero = keep_temp
	return out


func level_title(id: String) -> String:
	## A level's title from its file's header ("The Moth Garden"), or "".
	## Main and secret levels.
	if not _titles.has(id):
		_titles[id] = _header(id, "title")
	return _titles[id]


func area_of(id: String) -> int:
	## A level's Dusk area header (1..31): its file's "area:", else the
	## spec's table (AREAS), else 0 for an unknown id.
	if not _areas.has(id):
		var h := _header(id, "area")
		_areas[id] = int(h) if h.is_valid_int() else int(AREAS.get(id, 0))
	return _areas[id]


func _header(id: String, key: String) -> String:
	## One header value from a level file ("" if it isn't there).
	var info := level_info(id)
	if info.is_empty() or not FileAccess.file_exists(str(info["path"])):
		return ""
	var f := FileAccess.open(str(info["path"]), FileAccess.READ)
	while f != null and not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("---"):
			break
		if line.begins_with(key + ":"):
			return line.substr(key.length() + 1).strip_edges()
	return ""


# ---------------------------------------------------------------- settings

func setting(key: String):
	## From memory: the world asks for "shake" every physics tick, so the
	## file is read only by reset/load_save, reload_settings, or when
	## settings_path changes (the tests point it elsewhere).
	if _settings_from != settings_path:
		reload_settings()
	return _settings.get(key, SETTINGS_DEFAULT.get(key))


func set_setting(key: String, v) -> void:
	## Kept in memory and written through. SettingsLib merges it over what's
	## on disk, so the keys Sfx keeps there survive.
	if _settings_from != settings_path:
		reload_settings()
	_settings[key] = v
	SettingsLib.write({key: v}, settings_path)


func reload_settings() -> void:
	## Reads settings.json again. Call it after writing the file some other
	## way than set_setting.
	_settings = SettingsLib.read(settings_path)
	_settings_from = settings_path


var haptics: bool:
	get:
		return bool(setting("haptics"))
	set(v):
		set_setting("haptics", v)


# ---------------------------------------------------------------- difficulty & levels

func diff() -> String:
	return data["difficulty"]


func set_diff(d: String) -> void:
	if Combat.DIFF.has(d) and diff_open(d):
		data["difficulty"] = d
		save()


func diff_open(d: String) -> bool:
	return d == "dusk" or int(data["unlocked"].get(d, 0)) > 0


func levels_in_world(w: int) -> Array:
	return LEVELS.filter(func(l): return l["world"] == w)


func index_of(id: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == id:
			return i
	return -1


func unlocked_count(d := "") -> int:
	return int(data["unlocked"].get(d if d != "" else diff(), 0))


func is_unlocked(index: int) -> bool:
	return index >= 0 and index < mini(unlocked_count(), LEVELS.size())


func level_record(id: String, d := "") -> Dictionary:
	var dd := d if d != "" else diff()
	var levels: Dictionary = data["levels"][dd]
	if not levels.has(id):
		levels[id] = {"cleared": false, "sigils": [false, false, false], "best_time": 0.0, "best_embers": 0, "boss_first": false, "dread": false}
	return levels[id]


func sigil_found(id: String, index: int, d := "") -> bool:
	var dd := d if d != "" else diff()
	if not (data["levels"][dd] as Dictionary).has(id):
		return false
	return bool(level_record(id, dd)["sigils"][index])


func sigil_count(d := "") -> int:
	## Sigils found; all difficulties when d is "all".
	var n := 0
	var diffs: Array = Combat.DIFFS if d == "all" else [d if d != "" else diff()]
	for dd in diffs:
		for id in data["levels"][dd]:
			for s in data["levels"][dd][id]["sigils"]:
				if s:
					n += 1
	return n


func bells() -> int:
	## Bells rung, ever (every cleared level). The Chandler restocks on each.
	return int(data["bells"])


func veteran() -> int:
	## v1 levels cleared by a migrated save (0 for a new player). A record:
	## its +150 embers were paid at migration, and the saves screen's card
	## (slot_summary) names a veteran by it.
	return int(data["veteran"])


func record_result(res: Dictionary) -> Dictionary:
	## What a finished level leaves behind (on the current difficulty): cleared,
	## sigils (kept once found), records, the next level opened, a sigil
	## milestone paid; and in v3 a secret level opened (res.secret, its silver
	## bell rung) or cleared, Mother Yarrow's Second Draught (Gravebough's
	## level), and the next difficulty opened by the finale. Returns
	## {first_clear, rewards: [..]}, and when they happen: secret (the id
	## opened), secret_cleared (the id), prize (true: this run took the secret
	## level's prize, paid for this difficulty; see secret_prize), draught
	## ("second").
	var out := {"first_clear": false, "rewards": []}
	var id := str(res["level"])
	var rec := level_record(id)
	var opened := str(res.get("secret", ""))
	# The World opens it as the silver bell rings (so a quit then keeps it) and
	# says whether that was the first time (res.secret_new): either way it's
	# reported once, here.
	if opened != "" and (find_secret(opened, "", false) or bool(res.get("secret_new", false))):
		out["secret"] = opened
		out["rewards"].append({"kind": "secret", "id": opened})
	if res["cleared"]:
		data["bells"] = int(data["bells"]) + 1
		out["first_clear"] = not rec["cleared"]
		rec["cleared"] = true
		if float(rec["best_time"]) <= 0.0 or float(res["time"]) < float(rec["best_time"]):
			rec["best_time"] = float(res["time"])
		for i in 3:
			if res["sigils"][i]:
				rec["sigils"][i] = true
		rec["best_embers"] = maxi(int(rec["best_embers"]), int(res.get("embers", 0)))
		if res.get("dread", false):
			rec["dread"] = true
		var idx := index_of(id)
		if idx >= 0:
			# Capped at every level planned, not just those built, so a clear
			# of a World 1 build leaves World 2's first level open for when it
			# ships (is_unlocked stops at what exists).
			data["unlocked"][diff()] = clampi(maxi(unlocked_count(), idx + 2), 1, ALL_LEVELS.size())
		if is_secret(id):
			var s := _secret_rec(id, diff())
			s["found"] = true
			s["cleared"] = true
			out["secret_cleared"] = id
			# Its Lost Wick is home (Story.flag("lost_wicks_all"), the
			# finale's shot 2b, the cast roll's caption: ST's request).
			var lw := int(res.get("lost_wick", 0))
			if lw <= 0:
				lw = int(level_info(id).get("world", 0))
			if lw > 0:
				mark_seen("lost_wick:%d" % lw)
		if is_boss_level(id) and _restocks_reserve(id):
			data["bosses"] = int(data["bosses"]) + 1   # Waxley's Reserve restocks on each
		if id == DRAUGHT_LEVEL and int(data["flask"]["draughts"]) < 1:
			data["flask"]["draughts"] = 1
			out["draught"] = "second"
			out["rewards"].append({"kind": "draught", "id": "second"})
		# The finale (the Hush) opens the next difficulty. One a v2 save had
		# open, locked again by the migration, comes back with its old
		# unlocks and every level it had cleared.
		if _opens_next(id, idx):
			var nxt := Combat.DIFFS.find(diff()) + 1
			if nxt < Combat.DIFFS.size() and unlocked_count(Combat.DIFFS[nxt]) == 0:
				var nd: String = Combat.DIFFS[nxt]
				var waits := int(_num((data["relocked"] as Dictionary).get(nd, 0)))
				var back := maxi(waits, _highest_cleared(data["levels"][nd]) + 2)
				data["unlocked"][nd] = clampi(back, 1, ALL_LEVELS.size())
				(data["relocked"] as Dictionary).erase(nd)
				out["rewards"].append({"kind": "difficulty", "id": nd})
	# A secret level's prize is paid as it's picked up (add_item / equip:
	# _prize_taken); res.prize_taken (a World that tracks the pickup itself)
	# pays it too. out.prize says this run paid it.
	if is_secret(id):
		var key := "%s|%s" % [id, diff()]
		var srec := _secret_rec(id, diff())
		if bool(res.get("prize_taken", false)) and not bool(srec["prize"]):
			srec["prize"] = true
			_prizes_paid.append(key)
		if _prizes_paid.has(key):
			out["prize"] = true
			_prizes_paid.erase(key)
	# Sigil milestones: every 6 found, across every difficulty. #1-2 a relic,
	# #3-4 a Blessed-or-better relic (embers when the codex is full), then a
	# Legendary for the hero being played (v2); with World 3 built (v3,
	# milestones_alternate) odd ones a Legendary and even ones a relic from
	# the deepest world reached (spec §8.2; else 100 embers' worth). The
	# Legendary comes from the worlds reached only (a W1-W2 build picks v2's)
	# and prefers one the hero doesn't hold (spec §8.4, x3).
	var total := sigil_count("all")
	while total >= (int(data["sigil_rewards"]) + 1) * SIGIL_REWARD_EVERY:
		data["sigil_rewards"] = int(data["sigil_rewards"]) + 1
		var n: int = data["sigil_rewards"]
		if n <= 4:
			var rid := roll_relic(_rng, "common" if n <= 2 else "magic")
			if rid != "":
				grant_relic(rid)
				out["rewards"].append({"kind": "relic", "id": rid})
			else:
				add_embers(60)
				out["rewards"].append({"kind": "embers", "n": 60})
		elif n % 2 == 1 or not milestones_alternate():
			var h := hero()
			var slot := Items.pick_slot(_rng)
			var held: Array = []
			_legends_held(h, held)
			var lg := Items.pick_legend(slot, h["cls"], _rng, maxi(int(h.get("deepest", 0)), int(h["level"])), data["legends_found"], held, world_reached())
			var it := Items.make(slot, h["cls"], int(h["level"]), "legendary", _rng, lg)
			(h["satchel"] as Array).append(it)   # a reward is never lost to a full satchel
			note_legend(str(it.get("legend", "")))
			out["rewards"].append({"kind": "item", "item": it})
		else:
			var rid := _roll_world_relic(_rng, world_reached())
			if rid != "":
				grant_relic(rid)
				out["rewards"].append({"kind": "relic", "id": rid})
			else:
				var e := 100 * Combat.ember_worth(maxi(int(hero().get("deepest", 0)), 1), diff())
				add_embers(e)
				out["rewards"].append({"kind": "embers", "n": e})
	save()
	return out


func _opens_next(id: String, _idx: int) -> bool:
	## Whether clearing this level opens the next difficulty: the finale (the
	## Hush, 6-4) only, in every build. The owner's answer (decisions.md):
	## Nightfall waits for the Hush for everyone, a new player like a
	## migrated one. A build without 6-4 opens no Nightfall at all (its
	## areas start at 30: v2's W1-W2 Nightfall at 11-22 is gone). A secret
	## level never does.
	return id == FINALE


func is_boss_level(id: String) -> bool:
	## A world's fourth main level (1-4 ... 6-4): its boss's.
	for i in ALL_LEVELS.size():
		if ALL_LEVELS[i]["id"] == id:
			return i % 4 == 3
	return false


func milestones_alternate() -> bool:
	## v3's milestone rule (past #4: odd a Legendary, even a relic) is on once
	## World 3 is in the build; a W1-W2 build pays v2's (a Legendary each).
	## milestone_alternate (tests) or MILESTONE_ALTERNATE force it.
	return milestone_alternate or _built_from(3)


func _roll_world_relic(rng: RandomNumberGenerator, w: int) -> String:
	## A relic not yet found from world w's pool only (an even milestone's:
	## spec §8.2), or "" when that pool is empty.
	var skip: Array = (data["relics"] as Array).duplicate()
	for r in Relics.every():
		if int(r.get("world", 1)) != w and not skip.has(r["id"]):
			skip.append(r["id"])
	return Relics.roll(rng, skip, "common", w)


func _restocks_reserve(id: String) -> bool:
	## Whether this boss level's clear restocks Waxley's Reserve: a boss at the
	## hero's depth (its area on this difficulty at least RESERVE_FROM, and
	## within RESERVE_BOSS_GAP of the shop depth), never a shallow replay.
	var a := Combat.area_level(area_of(id), diff())
	return a >= maxi(RESERVE_FROM, shop_depth() - RESERVE_BOSS_GAP)


# ---------------------------------------------------------------- heroes

func heroes() -> Dictionary:
	return data["heroes"]


func has_hero(cls: String) -> bool:
	return (data["heroes"] as Dictionary).has(cls)


func hero_made() -> bool:
	## A calling has been chosen (else hero() is a temporary knight).
	return data["hero"] != "" and has_hero(data["hero"])


func hero_id() -> String:
	if not _borrowed.is_empty():
		return str(_borrowed.get("cls", "knight"))
	return data["hero"] if data["hero"] != "" else hero()["cls"]


func hero() -> Dictionary:
	## The hero being played. With none made yet (tests, autoplay), a
	## temporary level 1 Candleknight that is never saved. While a mode has
	## lent one (borrow_hero), that one.
	if not _borrowed.is_empty():
		return _borrowed
	if data["hero"] != "" and data["heroes"].has(data["hero"]):
		return data["heroes"][data["hero"]]
	if _temp_hero.is_empty():
		_temp_hero = Hero.blank("knight")
		_temp_hero["equip"] = Items.starter("knight")
		_temp_hero["belt"] = (data["relics"] as Array).slice(0, Progression.belt_slots(1))
	return _temp_hero


func best_level() -> int:
	var b := 0
	for cls in data["heroes"]:
		b = maxi(b, int(data["heroes"][cls]["level"]))
	return b


func new_hero(cls: String) -> Dictionary:
	## Makes (or returns) the hero for a calling and plays it. The first
	## starts at L1 in Common gear; a later calling starts at max(1, best - 2)
	## with a Blessed kit at that item level and its points unspent.
	if not Classes.ALL.has(cls):
		cls = "knight"
	if has_hero(cls):
		set_hero(cls)
		return data["heroes"][cls]
	var first: bool = (data["heroes"] as Dictionary).is_empty()
	var lvl := maxi(1, best_level() - 2)
	var h := Hero.blank(cls, lvl)
	h["xp"] = Progression.total_to(lvl)
	h["equip"] = Items.starter(cls, lvl, "common" if first else "magic", _rng)
	h["belt"] = (data["relics"] as Array).slice(0, Progression.belt_slots(lvl))
	_settle_points(h)
	data["heroes"][cls] = h
	data["hero"] = cls
	_temp_hero = {}
	save()
	return h


func set_hero(cls: String) -> void:
	if has_hero(cls):
		data["hero"] = cls
		save()


func hero_name() -> String:
	## The hero's own name in this save (every calling's; Waxby until one is
	## given).
	return str(data.get("hero_name", Story.HERO_NAME))


func set_hero_name(text: String) -> String:
	## Names the hero (the oath's entry, the Sheet's Rename): what's typed,
	## made fit by Story.clean_name (nothing fit to keep is Waxby). Saved
	## when it changes. Returns the name kept.
	var n := Story.clean_name(text)
	if n != hero_name():
		data["hero_name"] = n
		save()
	return n


func hero_stats(h: Dictionary = {}, d := "") -> Dictionary:
	## A hero's live numbers (the one being played by default) on difficulty
	## d (the save's by default; a mode passes its own).
	var hh := h if not h.is_empty() else hero()
	return Hero.stats(hh, hh.get("belt", []), d if d != "" else diff())


# ---------------------------------------------------------------- XP & skills

func add_xp(n: int) -> int:
	## Adds XP to the hero; returns how many levels were gained. At the cap
	## it keeps counting, toward Candlemarks (marked(n) when one lands; up to
	## the last one's worth). A borrowed hero earns none.
	var h := hero()
	if n <= 0 or not _borrowed.is_empty():
		return 0
	var top := Progression.total_to(Progression.CAP) + Progression.MARK_CAP * Progression.MARK_XP
	var marks0 := Progression.marks_of(int(h["xp"]))
	h["xp"] = mini(int(h["xp"]) + n, maxi(top, int(h["xp"])))
	var gained := 0
	while int(h["level"]) < Progression.CAP and int(h["xp"]) >= Progression.total_to(int(h["level"]) + 1):
		h["level"] = int(h["level"]) + 1
		gained += 1
		_grant_point(h)
		# A new belt slot fills itself from the codex.
		_fill_belt(h)
		leveled_up.emit(int(h["level"]))
	var marks1 := Progression.marks_of(int(h["xp"]))
	if marks1 > marks0:
		marked.emit(marks1)
	if (gained > 0 or marks1 > marks0) and hero_made():
		save()
	return gained


func _grant_point(h: Dictionary) -> void:
	## One level's point: into the tree while it has room, else a Vigil rank.
	if Hero.room(h) > 0:
		h["points"] = int(h["points"]) + 1
	else:
		h["vigil"] = int(h["vigil"]) + 1


func _settle_points(h: Dictionary) -> void:
	## Every level after the first gives one point: spent in the tree, unspent,
	## or (past a full tree) a Vigil rank. Puts the books straight.
	var owed := int(h["level"]) - 1
	var spent := Hero.spent(h)
	if spent > owed:
		h["skills"] = {}
		spent = 0
	var cap := Classes.tree_points(h["cls"]) - spent
	h["points"] = clampi(owed - spent, 0, cap)
	h["vigil"] = owed - spent - int(h["points"])


func xp_progress() -> Dictionary:
	var h := hero()
	var lvl: int = h["level"]
	var base := Progression.total_to(lvl)
	var need := Progression.xp_to_next(lvl)
	return {"level": lvl, "into": int(h["xp"]) - base, "need": need, "frac": 1.0 if need <= 0 else clampf(float(int(h["xp"]) - base) / need, 0.0, 1.0),
			"marks": Progression.marks_of(int(h["xp"])), "mark_frac": Progression.mark_frac(int(h["xp"]))}


func buy_skill(id: String) -> bool:
	var h := hero()
	var why := Classes.can_buy(h["cls"], id, h["skills"], int(h["level"]), int(h["points"]))
	if why != "":
		return false
	var n := Classes.find_node(h["cls"], id)
	h["skills"][id] = int(h["skills"].get(id, 1 if n["branch"] == -1 else 0)) + 1
	h["points"] = int(h["points"]) - 1
	save()
	return true


func points_spent() -> int:
	return Hero.spent(hero())


func respec() -> int:
	## The Chandler's Unmaking, always free: every point back. Returns how
	## many came back.
	var h := hero()
	var refund := Hero.spent(h)
	h["skills"] = {}
	h["points"] = int(h["points"]) + refund
	_settle_points(h)
	save()
	return refund


# ---------------------------------------------------------------- relics

func has_relic(id: String) -> bool:
	## Found (in the codex).
	return (data["relics"] as Array).has(id)


func equipped(id: String) -> bool:
	## On the current hero's belt: the gameplay checks use this.
	return (hero().get("belt", []) as Array).has(id)


func belt() -> Array:
	return hero().get("belt", [])


func belt_slots() -> int:
	return Progression.belt_slots(int(hero()["level"]))


func _fill_belt(h: Dictionary) -> void:
	var slots := Progression.belt_slots(int(h["level"]))
	for id in data["relics"]:
		if (h["belt"] as Array).size() >= slots:
			break
		if not (h["belt"] as Array).has(id):
			(h["belt"] as Array).append(id)


func grant_relic(id: String) -> bool:
	## Adds it to the codex; onto the belt if a slot is free. True if equipped.
	## (A borrowed hero's belt is left as lent.)
	if not Relics.ids().has(id):
		return false
	if not has_relic(id):
		(data["relics"] as Array).append(id)
	if not _borrowed.is_empty():
		save()
		return false
	var h := hero()
	var on := false
	if (h["belt"] as Array).has(id):
		on = true
	elif (h["belt"] as Array).size() < Progression.belt_slots(int(h["level"])):
		(h["belt"] as Array).append(id)
		on = true
	save()
	return on


func set_belt(ids: Array) -> void:
	var h := hero()
	var out := []
	for r in ids:
		if has_relic(r) and not out.has(r):
			out.append(r)
	h["belt"] = out.slice(0, belt_slots())
	save()


func roll_relic(rng: RandomNumberGenerator, min_rarity := "common", favor := 0) -> String:
	## A relic not yet found, from the worlds reached (world_reached); favor (a
	## world: a gold reliquary's or a boss's own) makes its relics twice as
	## likely. In Worlds 1-2 this is v2's roll exactly.
	return Relics.roll(rng, data["relics"], min_rarity, world_reached(), favor)


# ---------------------------------------------------------------- embers

func embers() -> int:
	return int(data["embers"])


func add_embers(n: int) -> void:
	data["embers"] = maxi(int(data["embers"]) + n, 0)


func spend_embers(n: int) -> bool:
	if n < 0 or int(data["embers"]) < n:
		return false
	_pay(n)
	save()
	return true


func _pay(n: int) -> void:
	## A price out of the purse (the caller's verdict said he has it), counted
	## for the playlog's embers_spent.
	data["embers"] = embers() - n
	embers_spent += n


# ---------------------------------------------------------------- gear

func add_item(it: Dictionary) -> String:
	## A picked-up item that isn't being worn: "satchel", "salvaged" or
	## "full". A Common melts into embers at once when auto-salvage is on.
	## With the satchel full (spec 4.4), anything no better than what's worn
	## in its slot (both chips at or below zero) melts too; an item that would
	## be better, a Legendary, or one for an empty slot is left: "full" (it
	## stays on the ground with its beam). A borrowed hero takes nothing
	## ("full"). A Legendary joins legends_found.
	var h := hero()
	if not _borrowed.is_empty():
		return "full"
	note_legend(str(it.get("legend", "")))
	if it["rarity"] == "common" and bool(setting("auto_salvage")):
		add_embers(Items.salvage_value(it))
		return "salvaged"   # the next save keeps the embers
	if (h["satchel"] as Array).size() >= SATCHEL_MAX:
		if it["rarity"] != "legendary" and h["equip"].get(it["slot"]) is Dictionary:
			var chips := Hero.compare(h, it["slot"], it, h.get("belt", []), diff())
			if float(chips["dmg"]) <= 0.0 and float(chips["life"]) <= 0.0:
				add_embers(Items.salvage_value(it))
				return "salvaged"
		return "full"
	(h["satchel"] as Array).append(it)
	_prize_taken(it)
	save()
	return "satchel"


func equip(it: Dictionary):
	## Wears an item (from the satchel or new); what it replaces goes to the
	## satchel. A new item worn with the satchel full leaves no room for it,
	## so something melts into embers instead (see melt_on_equip; last_melt
	## says what). Returns the replaced item or null. Refused (null, nothing
	## changes) for a borrowed hero.
	var h := hero()
	if not _borrowed.is_empty():
		return null
	note_legend(str(it.get("legend", "")))
	var slot: String = it["slot"]
	var old = h["equip"].get(slot)
	var victim := melt_on_equip(it)
	last_melt = {}
	h["equip"][slot] = it
	_take_from_satchel(h, it)
	if old != null:
		(h["satchel"] as Array).append(old)
	if not victim.is_empty():
		var v := Items.salvage_value(victim)
		_take_from_satchel(h, victim)
		add_embers(v)
		last_melt = {"for": str(it.get("uid", "")), "item": victim, "embers": v,
				"old": old is Dictionary and str(victim.get("uid", "")) == str(old.get("uid", "-"))}
	_prize_taken(it)
	save()
	return old


func melt_on_equip(it: Dictionary) -> Dictionary:
	## What wearing it would melt to keep the satchel at SATCHEL_MAX, or {}.
	## Only a new item (not one out of the satchel) that pushes a worn one
	## into a full satchel melts anything: the one it replaces, which is
	## weaker by then (spec 4.4.3), or, that being a Legendary (never
	## melted), the satchel's weakest non-Legendary. With nothing but
	## Legendaries in there, nothing melts and the satchel holds one more.
	var h := hero()
	var old = h["equip"].get(str(it.get("slot", "")))
	if not (old is Dictionary) or _in_satchel(h, it) or (h["satchel"] as Array).size() < SATCHEL_MAX:
		return {}
	if str(old.get("rarity", "")) != "legendary":
		return old
	var best := {}
	var best_p := 1 << 30
	for o in (h["satchel"] as Array):
		if o is Dictionary and str(o.get("rarity", "")) != "legendary" and Items.power(o) < best_p:
			best = o
			best_p = Items.power(o)
	return best


func _in_satchel(h: Dictionary, it: Dictionary) -> bool:
	var uid := str(it.get("uid", "-"))
	for o in (h["satchel"] as Array):
		if o is Dictionary and (str(o.get("uid", "")) == uid or o == it):
			return true
	return false


func _take_from_satchel(h: Dictionary, it: Dictionary) -> void:
	var uid: String = it.get("uid", "-")
	for i in range((h["satchel"] as Array).size() - 1, -1, -1):
		var o = h["satchel"][i]
		if o is Dictionary and (o.get("uid", "") == uid or o == it):
			h["satchel"].remove_at(i)


func salvage(it: Dictionary) -> int:
	## Melts a satchel item down for embers. Worn gear isn't salvaged.
	var h := hero()
	for slot in h["equip"]:
		var e = h["equip"][slot]
		if e is Dictionary and e.get("uid", "") == it.get("uid", "-"):
			return 0
	var v := Items.salvage_value(it)
	_take_from_satchel(h, it)
	add_embers(v)
	save()
	return v


func weaker_items() -> Array:
	## The satchel items no better than what's worn in their slot (both chips
	## at or below zero), never a Legendary (like a full satchel, salvage-all
	## never melts one): what salvage_weaker() takes. The Sheet's Gear tab and
	## the Chandler both show this list.
	var h := hero()
	var out: Array = []
	for it in (h["satchel"] as Array):
		if not (it is Dictionary) or str(it.get("rarity", "")) == "legendary":
			continue
		if not (h["equip"].get(it["slot"]) is Dictionary):
			continue
		var chips := Hero.compare(h, it["slot"], it, h.get("belt", []), diff())
		if float(chips["dmg"]) <= 0.0 and float(chips["life"]) <= 0.0:
			out.append(it)
	return out


func weaker_value() -> int:
	## What salvage_weaker() would pay now.
	var total := 0
	for it in weaker_items():
		total += Items.salvage_value(it)
	return total


func satchel_full() -> bool:
	return (hero()["satchel"] as Array).size() >= SATCHEL_MAX


func salvage_weaker() -> int:
	## Melts every item weaker_items() lists. Returns the embers.
	var h := hero()
	var total := 0
	for it in weaker_items():
		total += Items.salvage_value(it)
		_take_from_satchel(h, it)
	add_embers(total)
	save()
	return total


func weakest_slot(h: Dictionary = {}, slots: Array = []) -> String:
	## The live slot (of slots, else every live one) with the least behind it:
	## an empty one first, else the lowest Power.
	var hh := h if not h.is_empty() else hero()
	var best := ""
	var best_p := 1 << 30
	for slot in (slots if not slots.is_empty() else Items.LIVE_SLOTS):
		var it = hh["equip"].get(slot)
		var p := -1 if not (it is Dictionary) else Items.power(it)
		if p < best_p:
			best_p = p
			best = slot
	return best


# ---------------------------------------------------------------- the Chandler

func wares() -> Array:
	## Waxley's stock for the hero being played, at the hero's level, by shop
	## depth (SHOP_ROWS): below 13, v2's 4 (2 Blessed, 1 Rare, 1 for the
	## weakest slot); 5 from 13 (2 Rares), the weakest slot's a Rare from 18;
	## 6 from 28 (1 Blessed, 4 Rares and the weakest slot's Rare). The last
	## one is always for the weakest slot. null where one was bought.
	## Restocks after every bell rung (and when a new depth changes the row).
	var h := hero()
	if int(h["wares_seed"]) != _wares_mark(h) or (h["wares"] as Array).size() != ware_count(h):
		_restock(h)
	return h["wares"]


func _wares_mark(h: Dictionary) -> int:
	## What a stock is stamped with: the bell it was made after (v2's
	## bells + 1), and past v2's row the row's number in the millions, so a
	## deeper row restocks even when its count is the same.
	var row := _shop_row(shop_depth(h))
	return bells() + 1 + 1000000 * SHOP_ROWS.find(row)


func shop_depth(h: Dictionary = {}) -> int:
	## What the Chandler stocks for (spec §8.2): max(hero.deepest, level - 1).
	var hh := h if not h.is_empty() else hero()
	return maxi(int(_num(hh.get("deepest", 0))), int(_num(hh.get("level", 1))) - 1)


func _shop_row(depth: int) -> Dictionary:
	var row: Dictionary = SHOP_ROWS[0]
	for r in SHOP_ROWS:
		if depth >= int(r["from"]):
			row = r
	return row


func _shop_slots(h: Dictionary) -> Array:
	## The slots the Chandler offers: those that drop at his depth.
	return Items.live_slots(shop_depth(h))


func _restock(h: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	var row := _shop_row(shop_depth(h))
	var key := "%s|%d|%d|%d" % [h["cls"], bells(), int(h["level"]), int(data["run_counter"])]
	# (A deeper row mixes its depth in, so reaching it mid-bell makes a new
	# stock rather than the old one again; v2's row keeps v2's seed.)
	rng.seed = hash(key) if int(row["from"]) == 0 else hash("%s|%d" % [key, int(row["from"])])
	var lvl := int(h["level"])
	var live: Array = _shop_slots(h)
	var slots: Array = live.duplicate()
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = slots[i]
		slots[i] = slots[j]
		slots[j] = t
	# One slot each, in the shuffled order (v2's first row: Blessed, Blessed,
	# Rare, made in that order from the same rng, so W1-W2's stock is v2's).
	var stock := []
	var rarities: Array = row["wares"]
	for i in rarities.size():
		stock.append(Items.make(slots[i % slots.size()], h["cls"], lvl, str(rarities[i]), rng))
	# The one for the weakest slot: the best of a few rolls.
	var weak := weakest_slot(h, live)
	var weak_rarity := str(row["weak"])
	var best = null
	var best_score := -INF
	for i in 6:
		var it := Items.make(weak, h["cls"], lvl, weak_rarity, rng)
		var chips := Hero.compare(h, weak, it, h.get("belt", []), diff())
		var score := float(chips["dmg"]) + float(chips["life"])
		if score > best_score:
			best_score = score
			best = it
	stock.append(best)
	h["wares"] = stock
	h["wares_seed"] = _wares_mark(h)


func ware_price(it) -> int:
	return Items.price(it)


func ware_verdict(i: int) -> String:
	## What buying ware i would do, without buying it: "equipped" (it beats
	## what's worn, or the slot is empty), "satchel", or why not: "sold",
	## "poor", "full". The Chandler asks before it arms a sale.
	var h := hero()
	var stock := wares()
	if i < 0 or i >= stock.size() or not (stock[i] is Dictionary):
		return "sold"
	var it: Dictionary = stock[i]
	if embers() < Items.price(it):
		return "poor"
	var chips := Hero.compare(h, it["slot"], it, h.get("belt", []), diff())
	if h["equip"].get(it["slot"]) == null or Hero.is_upgrade(chips):
		return "equipped"
	if (h["satchel"] as Array).size() >= SATCHEL_MAX:
		return "full"
	return "satchel"


func buy_ware(i: int) -> String:
	## Buys ware i: "equipped", "satchel", or why not (see ware_verdict).
	var where := ware_verdict(i)
	if where != "equipped" and where != "satchel":
		return where
	var h := hero()
	var it: Dictionary = h["wares"][i]
	_pay(Items.price(it))
	h["wares"][i] = null
	if where == "equipped":
		equip(it)
		return "equipped"
	(h["satchel"] as Array).append(it)
	save()
	return "satchel"


func relic_offers(n := -1) -> Array:
	## The Chandler's relic shelf (Relics.for_sale: the cheapest not yet found
	## of each rarity), from the worlds reached; 3 of them (4 from shop depth
	## 23), or n.
	var k := n if n >= 0 else int(_shop_row(shop_depth())["shelf"])
	return Relics.for_sale(data["relics"], k, world_reached())


func relic_verdict(id: String) -> String:
	## What buying relic id would do, without buying it: "belt", "stowed",
	## or why not: "owned", "poor", "unknown".
	if not Relics.ids().has(id):
		return "unknown"
	if has_relic(id):
		return "owned"
	if embers() < Relics.price(id):
		return "poor"
	return "belt" if (belt() as Array).size() < belt_slots() else "stowed"


func buy_relic(id: String) -> String:
	## "belt" (worn at once), "stowed" (the belt is full), or why not (see
	## relic_verdict).
	var why := relic_verdict(id)
	if why != "belt" and why != "stowed":
		return why
	spend_embers(Relics.price(id))
	return "belt" if grant_relic(id) else "stowed"


# ---------------------------------------------------------------- story

func seen(id: String) -> bool:
	return (data["seen"] as Array).has(id)


func mark_seen(id: String) -> void:
	if not seen(id):
		(data["seen"] as Array).append(id)
		save()
		if id == "homecoming":
			grant_story_cosmetics()


func grant_story_cosmetics() -> void:
	## The ending's flame (Dawnwick, source "story:homecoming") is paid as
	## homecoming is seen, so the Look tab has it at once (the rev5 review: only
	## the Challenges hub paid it). Also called by the Look tab and the hub for
	## a save that saw homecoming before this.
	if not seen("homecoming"):
		return
	var C = load("res://scripts/modes/cosmetics.gd") if ResourceLoader.exists("res://scripts/modes/cosmetics.gd") else null
	if C == null:
		return
	for nid in C.ids_for("story:homecoming"):
		grant_cosmetic(str(nid))


func next_run() -> int:
	data["run_counter"] = int(data["run_counter"]) + 1
	return data["run_counter"]


# ---------------------------------------------------------------- v3: levels and secrets

func level_info(id: String) -> Dictionary:
	## A main or secret level by its exact id: {id, path, world, secret, from,
	## area} ({} for an unknown id; "from" is "" for a main level).
	for l in ALL_LEVELS:
		if l["id"] == id:
			return {"id": id, "path": l["path"], "world": int(l["world"]), "secret": false, "from": "", "area": int(AREAS.get(id, 0))}
	for l in SECRET_LEVELS:
		if l["id"] == id:
			return {"id": id, "path": l["path"], "world": int(l["world"]), "secret": true, "from": l["from"], "area": int(AREAS.get(id, 0))}
	return {}


func is_secret(id: String) -> bool:
	for l in SECRET_LEVELS:
		if l["id"] == id:
			return true
	return false


func secrets_built() -> Array:
	## The secret levels whose files are in this build.
	return SECRET_LEVELS.filter(func(l): return FileAccess.file_exists(l["path"]))


func _secret_rec(id: String, d: String) -> Dictionary:
	var dd := d if Combat.DIFF.has(d) else "dusk"
	var recs: Dictionary = data["secrets"][dd]
	if not recs.has(id):
		recs[id] = {"found": false, "cleared": false, "prize": false}
	return recs[id]


func find_secret(id: String, d := "", save_now := true) -> bool:
	## Its silver bell rung on difficulty d (the save's by default): the
	## secret level opens there. True the first time. (record_result does it
	## from res.secret; the world may call it as the bell rings.)
	if not is_secret(id):
		return false
	var s := _secret_rec(id, d if d != "" else diff())
	if bool(s["found"]):
		return false
	s["found"] = true
	if save_now:
		save()
	return true


func secret_open(id: String, d := "") -> bool:
	## Its silver bell has been rung on difficulty d, or on any for "".
	if not is_secret(id):
		return false
	for dd in (Combat.DIFFS if d == "" else [d]):
		var recs = (data["secrets"] as Dictionary).get(dd, {})
		if recs is Dictionary and recs.get(id) is Dictionary and bool(recs[id].get("found", false)):
			return true
	return false


func secret_prize(id: String, d := "") -> Dictionary:
	## The prize Legendary a secret level's shrine holds (spec §3.9, §8.4: its
	## file's secret_prize: header, else Items.SECRET_PRIZES) until it's been
	## taken on difficulty d (the save's by default), made for the hero at the
	## level's area + 2; {} once it has, for a level that isn't secret, or for
	## a hero borrowed by a mode. secrets.gd places it (world.place_item) when
	## the Warden falls. It's paid when it's picked up, worn or carried
	## (add_item / equip know it by its uid), as a boss's first prize is: left
	## on the shrine (the bell rung past it, the satchel full, a snuff), it's
	## there again next time; taken in a run that never rings the bell, it's
	## kept and never drops twice.
	if not is_secret(id) or borrowing():
		return {}
	var lg := _header(id, "secret_prize")
	if not Items.LEGENDS.has(lg):
		lg = str(Items.SECRET_PRIZES.get(id, ""))
	if lg == "" or not Items.LEGENDS.has(lg):
		return {}
	var dd := d if d != "" else diff()
	if bool(secret_record(id, dd)["prize"]):
		return {}
	var h := hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("prize|%s|%s|%s|%d" % [id, dd, h["cls"], int(data["run_counter"])])
	var ilvl := Combat.area_level(area_of(id), dd) + 2
	var it := Items.make(str(Items.LEGENDS[lg]["slot"]), h["cls"], ilvl, "legendary", rng, lg)
	_prizes[str(it["uid"])] = [id, dd]
	return it


func _prize_taken(it: Dictionary) -> void:
	## A secret prize (secret_prize) picked up, worn or carried: paid on its
	## difficulty now (the save that follows keeps it).
	var uid := str(it.get("uid", ""))
	if not _prizes.has(uid):
		return
	var p: Array = _prizes[uid]
	_prizes.erase(uid)
	var s := _secret_rec(str(p[0]), str(p[1]))
	if not bool(s["prize"]):
		s["prize"] = true
		_prizes_paid.append("%s|%s" % [p[0], p[1]])


func secret_record(id: String, d := "") -> Dictionary:
	## {found, cleared, prize} on difficulty d (the save's by default), a copy.
	var dd := d if d != "" else diff()
	var recs = (data["secrets"] as Dictionary).get(dd, {})
	if recs is Dictionary and recs.get(id) is Dictionary:
		return (recs[id] as Dictionary).duplicate()
	return {"found": false, "cleared": false, "prize": false}


func world_reached() -> int:
	## The deepest world with a level open on any difficulty, of those built
	## (1 at least): the worlds rolls and the relic shelf may draw from.
	var w := 1
	for dd in Combat.DIFFS:
		var u := mini(int(_num(data["unlocked"].get(dd, 0))), LEVELS.size())
		if u > 0:
			w = maxi(w, int(LEVELS[u - 1]["world"]))
	return w


# ---------------------------------------------------------------- v3: Nightfall locked again

func diff_waits(d: String) -> bool:
	## A difficulty a v2 save had open, locked again until the Hush falls on
	## the one below (its clears are kept: they count again when it opens).
	return int(_num((data["relocked"] as Dictionary).get(d, 0))) > 0


func relock_card() -> Dictionary:
	## The one-time card that says so, while it's owed: {id, title, body},
	## else {}. Whoever shows it then calls notice(card.id).
	var waiting: Array = Combat.DIFFS.filter(func(dd): return dd != "dusk" and diff_waits(dd))
	if waiting.is_empty() or (data["notices"] as Array).has(NOTICE_RELOCK):
		return {}
	var body := "Nightfall now waits beneath the Hush. Your Nightfall clears are kept."
	if waiting.has("witching"):
		body = "Nightfall and the Witching Hour now wait beneath the Hush. Your clears are kept."
	return {"id": NOTICE_RELOCK, "title": "Nightfall", "body": body}


func notice(id: String) -> bool:
	## A one-time card or toast: true the first time (and it's marked shown,
	## saved), false after.
	if id == "" or (data["notices"] as Array).has(id):
		return false
	(data["notices"] as Array).append(id)
	save()
	return true


# ---------------------------------------------------------------- v3: the flask, Legendaries, depth

func flask_charges(d := "") -> int:
	## Flask charges on difficulty d: DIFF's, the Second Draught, and the
	## hero's flask_add (Mother Taper's Match), at most FLASK_MAX.
	var dd := d if d != "" else diff()
	var n := int(Combat.diff(dd)["flask_charges"]) + int(_num(data["flask"].get("draughts", 0)))
	n += int(hero_stats({}, dd).get("flask_add", 0))
	return clampi(n, 1, FLASK_MAX)


func flask_heal(d := "") -> float:
	## What one draught heals, as a share of max life: DIFF's, 10 points more
	## with the Rich Draught, then the hero's flask_pct more (the Deep Chalice).
	var dd := d if d != "" else diff()
	var k := float(Combat.diff(dd)["flask"]) + (RICH_HEAL if _flag(data["flask"].get("rich", false)) else 0.0)
	return k * (1.0 + float(hero_stats({}, dd).get("flask_pct", 0.0)))


func grant_draught(id: String) -> void:
	## "second": Mother Yarrow's gift (+1 charge on every difficulty);
	## "rich": the Rich Draught (the flask heals more). Per save.
	match id:
		"second":
			data["flask"]["draughts"] = 1
		"rich":
			data["flask"]["rich"] = true
		_:
			return
	save()


func legends_found() -> Array:
	## Every Legendary power ever picked up in this save.
	return data["legends_found"]


func note_legend(id: String) -> void:
	## One more for legends_found (add_item, equip and the rewards call it;
	## the next save keeps it).
	if id != "" and not (data["legends_found"] as Array).has(id):
		(data["legends_found"] as Array).append(id)


func note_area(a: int) -> void:
	## The hero has started a level at area a: its deepest (the Chandler's
	## stock reads it). Called by the World at level start.
	if not _borrowed.is_empty():
		return
	var h := hero()
	h["deepest"] = maxi(int(_num(h.get("deepest", 0))), a)


func ware_count(h: Dictionary = {}) -> int:
	## The Chandler's stock size by shop depth: 4 below 13, 5 from 13, 6 from 28.
	var hh := h if not h.is_empty() else hero()
	return (_shop_row(shop_depth(hh))["wares"] as Array).size() + 1


# ---------------------------------------------------------------- v3: Waxley's Reserve

func reserve() -> Dictionary:
	## Waxley's Reserve: one Legendary legal for the shop depth (from depth 23),
	## at 300 + 40 x ilvl, restocked when a boss at the hero's depth falls
	## (data.bosses, _restocks_reserve).
	## {item (null once bought), price, new (not yet shown)}, or {} below 23.
	var h := hero()
	if not hero_made() or borrowing() or not bool(_shop_row(shop_depth(h))["reserve"]):
		return {}
	if int(_num(h.get("reserve_seed", -1))) != int(data["bosses"]) + 1 or not h.has("reserve"):
		_stock_reserve(h)
	var it = h.get("reserve")
	return {"item": it, "price": Items.price(it) if it is Dictionary else 0, "new": _flag(h.get("reserve_new", false))}


func _stock_reserve(h: Dictionary) -> void:
	## A Legendary for the depth, of the worlds reached: one the hero doesn't
	## hold when there is one, a secret one only once found
	## (Items.legal_legends), at the hero's level.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("reserve|%s|%d|%d" % [h["cls"], int(data["bosses"]), int(h["level"])])
	var owned: Array = []
	_legends_held(h, owned)
	var legal: Array = Items.legal_legends(h["cls"], shop_depth(h), data["legends_found"], _shop_slots(h), world_reached())
	var fresh: Array = legal.filter(func(id): return not owned.has(id))
	var pool: Array = fresh if not fresh.is_empty() else legal
	h["reserve_seed"] = int(data["bosses"]) + 1
	if pool.is_empty():
		h["reserve"] = null
		h["reserve_new"] = false
		return
	var lg: String = pool[rng.randi() % pool.size()]
	h["reserve"] = Items.make(str(Items.LEGENDS[lg]["slot"]), h["cls"], int(h["level"]), "legendary", rng, lg)
	h["reserve_new"] = true


func reserve_seen() -> void:
	## The Chandler has shown a fresh Reserve (Waxley said his line).
	var h := hero()
	if _flag(h.get("reserve_new", false)):
		h["reserve_new"] = false
		save()


func reserve_verdict() -> String:
	## What buying the Reserve would do: "equipped" (it beats what's worn, or
	## the slot is empty), "satchel", or why not: "none", "sold", "poor", "full".
	var r := reserve()
	if r.is_empty():
		return "none"
	if not (r["item"] is Dictionary):
		return "sold"
	var it: Dictionary = r["item"]
	if embers() < int(r["price"]):
		return "poor"
	var h := hero()
	if h["equip"].get(it["slot"]) == null or Hero.is_upgrade(Hero.compare(h, it["slot"], it, h.get("belt", []), diff())):
		return "equipped"
	if (h["satchel"] as Array).size() >= SATCHEL_MAX:
		return "full"
	return "satchel"


func buy_reserve() -> String:
	## Buys the Reserve: "equipped", "satchel", or why not (reserve_verdict).
	var where := reserve_verdict()
	if where != "equipped" and where != "satchel":
		return where
	var h := hero()
	var it: Dictionary = h["reserve"]
	_pay(Items.price(it))
	h["reserve"] = null
	h["reserve_new"] = false
	note_legend(str(it.get("legend", "")))
	if where == "equipped":
		equip(it)
		return "equipped"
	(h["satchel"] as Array).append(it)
	save()
	return "satchel"


# ---------------------------------------------------------------- v3: the Draughts tab

func draughts_open() -> bool:
	## The Chandler's fourth tab shows once World 3 is reached (or a draught is
	## had): before then Worlds 1-2 see v2's three tabs.
	return world_reached() >= 3 or int(data["flask"]["draughts"]) > 0 or _flag(data["flask"]["rich"])


func _beaten(id: String) -> bool:
	## A level cleared on any difficulty.
	for dd in Combat.DIFFS:
		var r = (data["levels"][dd] as Dictionary).get(id)
		if r is Dictionary and _flag(r.get("cleared", false)):
			return true
	return false


func draughts() -> Array:
	## The Draughts tab's cards: [{id, name, text, price, state, why}], state
	## "owned", "buy" or "locked" (why says what opens it). The Second Draught
	## is Mother Yarrow's gift, never sold; the Rich Draught opens after the
	## Tinker of Hours.
	var second := int(data["flask"]["draughts"]) >= 1
	var rich := _flag(data["flask"]["rich"])
	var rich_open := _beaten(RICH_AFTER)
	return [
		{"id": "second", "name": "The Second Draught", "text": "Mother Yarrow's gift: one more flask charge, on every difficulty.",
				"price": 0, "state": "owned" if second else "locked", "why": "" if second else "A gift, when Mother Gravebough falls."},
		{"id": "rich", "name": "The Rich Draught", "text": "Each draught heals a tenth more of your life, on every difficulty (40% becomes 50% on Dusk).",
				"price": RICH_PRICE, "state": "owned" if rich else ("buy" if rich_open else "locked"),
				"why": "" if rich or rich_open else "Sold once the Tinker of Hours falls."},
	]


func draught_verdict(id: String) -> String:
	## What buying draught id would do: "buy", or why not: "owned", "locked",
	## "poor", "unknown" (the Second Draught is a gift: "owned" or "locked").
	for d in draughts():
		if d["id"] == id:
			if d["state"] == "owned" or d["state"] == "locked":
				return str(d["state"])
			if id == "second":
				return "locked"
			return "poor" if embers() < int(d["price"]) else "buy"
	return "unknown"


func buy_draught(id: String) -> String:
	## Buys a draught: "bought", or why not (draught_verdict).
	var why := draught_verdict(id)
	if why != "buy":
		return why
	_pay(RICH_PRICE)
	data["flask"]["rich"] = true
	save()
	return "bought"


# ---------------------------------------------------------------- v3: Rekindle

func rekindle_open() -> bool:
	## Rekindle is offered once the Shattered Sanctum is reached.
	return world_reached() >= REKINDLE_WORLD


func rekindle_level() -> int:
	## The item level Rekindle makes: the hero's (at most Items.ILVL_CAP).
	return mini(int(hero()["level"]), Items.ILVL_CAP)


func rekindle_price(_it = null) -> int:
	## 200 + 30 x the new item level.
	return REKINDLE_BASE + REKINDLE_PER * rekindle_level()


func rekindle_list() -> Array:
	## The Legendaries the hero holds, worn first, then the satchel's:
	## [{item, worn: bool, verdict}].
	var h := hero()
	var out: Array = []
	for slot in Items.SLOTS:
		var it = h["equip"].get(slot)
		if it is Dictionary and str(it.get("rarity", "")) == "legendary":
			out.append({"item": it, "worn": true, "verdict": rekindle_verdict(it)})
	for it in (h["satchel"] as Array):
		if it is Dictionary and str(it.get("rarity", "")) == "legendary":
			out.append({"item": it, "worn": false, "verdict": rekindle_verdict(it)})
	return out


func rekindle_verdict(it) -> String:
	## "" when it can be re-made now, else why not: "locked" (before World 5),
	## "none" (not a Legendary the hero holds), "lower" (it's already at the
	## hero's level or above), "poor".
	if not (it is Dictionary) or str(it.get("rarity", "")) != "legendary" or not Items.LEGENDS.has(str(it.get("legend", ""))):
		return "none"
	if not rekindle_open() or borrowing():
		return "locked"
	if _held_at(it).is_empty():
		return "none"
	if rekindle_level() <= int(_num(it.get("ilvl", 1))):
		return "lower"
	if embers() < rekindle_price(it):
		return "poor"
	return ""


func _held_at(it: Dictionary) -> Dictionary:
	## Where the hero holds this item: {slot} worn, {index} in the satchel, or {}.
	var h := hero()
	var uid := str(it.get("uid", "-"))
	for slot in Items.SLOTS:
		var e = h["equip"].get(slot)
		if e is Dictionary and (str(e.get("uid", "")) == uid or e == it):
			return {"slot": slot}
	var sat: Array = h["satchel"]
	for i in sat.size():
		if sat[i] is Dictionary and (str(sat[i].get("uid", "")) == uid or sat[i] == it):
			return {"index": i}
	return {}


func rekindle(item: Dictionary) -> bool:
	## Re-makes a Legendary at the hero's level (spec §8.2): the same power,
	## a fresh tier, implicit and affixes, where it was (worn or carried, the
	## same uid). Only when that's higher than its item level; costs
	## rekindle_price. True if it happened.
	if rekindle_verdict(item) != "":
		return false
	var at := _held_at(item)
	var h := hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rekindle|%s|%d|%d" % [str(item.get("uid", "")), rekindle_level(), int(data["run_counter"])])
	var cls: String = str(item.get("cls", "")) if str(item.get("cls", "")) != "" else str(h["cls"])
	var it := Items.make(str(item["slot"]), cls, rekindle_level(), "legendary", rng, str(item["legend"]))
	it["uid"] = str(item.get("uid", it["uid"]))
	_pay(rekindle_price(item))
	if at.has("slot"):
		h["equip"][at["slot"]] = it
	else:
		h["satchel"][int(at["index"])] = it
	save()
	return true


# ---------------------------------------------------------------- v3: gifts and warnings

func gift_slot(world: int) -> String:
	## The first Dread killed in World 3 drops boots, in World 4 a charm (spec
	## §8.1: Blessed or better, as every Dread's drop is), while the hero holds
	## none (worn or carried): that slot, else "". world.gd asks it as a
	## Dread falls and makes that drop's slot this one.
	var slot := str(GIFT_SLOTS.get(world, ""))
	if slot == "" or not hero_made() or borrowing():
		return ""
	var h := hero()
	if h["equip"].get(slot) is Dictionary:
		return ""
	for it in (h["satchel"] as Array):
		if it is Dictionary and str(it.get("slot", "")) == slot:
			return ""
	return slot


func deep_warning(area: int, d := "") -> Dictionary:
	## The one-time card (spec §1.6) for a level on Nightfall or Witching with
	## the hero more than 5 levels under its area: {id, title, body} while
	## it's owed, else {}. Whoever shows it then calls notice(card.id).
	var dd := d if d != "" else diff()
	if dd == "dusk" or not Combat.DIFF.has(dd) or (data["notices"] as Array).has(NOTICE_DEEP):
		return {}
	if int(hero()["level"]) + DEEP_WARN_GAP >= area:
		return {}
	var want := 40 if dd == "witching" else 30
	return {"id": NOTICE_DEEP, "title": str(Combat.diff(dd)["name"]),
			"body": "The Vigil runs deeper now. This dark is for Wicks of level %d and more." % want}


# ---------------------------------------------------------------- v3: modes

func set_suspend(d: Dictionary) -> void:
	## A story level's resume point (P1: written when an altar is lit).
	data["suspend"] = d.duplicate(true)
	save()


func suspended() -> Dictionary:
	return data["suspend"]


func clear_suspend() -> void:
	if not (data["suspend"] as Dictionary).is_empty():
		data["suspend"] = {}
		save()


func modes() -> Dictionary:
	## The modes' block of the save: the one door mode scripts use (through
	## ModesSave's helpers, then save()).
	return data["modes"]


func _modes_script():
	## ModesSave's script, when it's in this build and compiles; else null.
	if _modes_lib == null:
		_modes_lib = false
		if ResourceLoader.exists(MODES_SAVE):
			var s = load(MODES_SAVE)
			if s is GDScript and (s as GDScript).can_instantiate():
				_modes_lib = s
	return null if _modes_lib is bool else _modes_lib


func _modes_defaults() -> Dictionary:
	var ms = _modes_script()
	return ms.defaults() if ms != null else {}


func _modes_clean(v) -> Dictionary:
	## ModesSave.clean when it's there; before then the block is kept as it
	## came (nothing of it is lost while the modes aren't built).
	var ms = _modes_script()
	if ms != null:
		return ms.clean(v if v is Dictionary else {})
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


func _cosmetics() -> Dictionary:
	var m: Dictionary = data["modes"]
	if not (m.get("cosmetics") is Dictionary):
		m["cosmetics"] = {}
	var c: Dictionary = m["cosmetics"]
	for k in ["owned", "new"]:
		if not (c.get(k) is Array):
			c[k] = []
	return c


func has_cosmetic(id: String) -> bool:
	## Owned ("flame:tallow" and "color:calling" always are).
	if COSMETIC_FREE.has(id):
		return true
	var m = data["modes"].get("cosmetics", {})
	return m is Dictionary and m.get("owned") is Array and (m["owned"] as Array).has(id)


func grant_cosmetic(id: String) -> bool:
	## A cosmetic owned from now on (namespaced: "flame:…", "trim:…",
	## "color:…", "glow:…"): true when it's new (it shows as new too).
	if id == "" or has_cosmetic(id):
		return false
	var c := _cosmetics()
	(c["owned"] as Array).append(id)
	(c["new"] as Array).append(id)
	save()
	return true


func look(cls := "") -> Dictionary:
	## A hero's look {flame, trim, trim_color, glow} (the one being played by
	## default; while a hero is borrowed, still the player's own).
	var c := cls if cls != "" else str(data["hero"])
	var out: Dictionary = Hero.LOOK_DEFAULT.duplicate()
	var h = (data["heroes"] as Dictionary).get(c)
	if h is Dictionary and h.get("look") is Dictionary:
		for k in LOOK_KEYS:
			if (h["look"] as Dictionary).has(k):
				out[k] = str(h["look"][k])
	return out


func set_look(key: String, id: String) -> void:
	## Wears a cosmetic on the hero being played (key flame, trim, trim_color
	## or glow). Cosmetics.gd checks it's owned.
	if not LOOK_KEYS.has(key) or not hero_made():
		return
	var h: Dictionary = data["heroes"][data["hero"]]
	if not (h.get("look") is Dictionary):
		h["look"] = Hero.LOOK_DEFAULT.duplicate()
	h["look"][key] = id
	save()


func borrow_hero(h: Dictionary) -> void:
	## A mode lends a hero (the Trials' loadouts): hero(), hero_id(),
	## equipped(), belt() and hero_stats() answer from it; add_xp, add_item
	## and equip are refused. Nothing of it is ever saved.
	_borrowed = h


func return_hero() -> void:
	_borrowed = {}


func borrowing() -> bool:
	return not _borrowed.is_empty()


# ---------------------------------------------------------------- the player

func apply_hero(player: Node, d := "") -> void:
	## Sets Wick's live numbers from the hero (kept as apply_relics too), on
	## difficulty d (the save's by default; a mode's World passes its own).
	player.set_stats(hero_stats({}, d))


func apply_relics(player: Node) -> void:
	apply_hero(player)
