extends SceneTree
## test_story: the story script and its player. Every scene a level header,
## main or another scene names exists; every @slot speaks for all five
## callings; every line fits in 80 characters with the longest calling name
## in it; every cue is known and has what it needs; the stand-in stage has
## every panel, anchor, figure and light the script uses (and so does
## art/story/panels.json once it exists); every scene plays headless to its
## end exactly once within 2000 steps; skipping marks a scene seen; an
## overlay pauses its level and mutes the touch buttons, then gives both
## back; the typewriter's pace and blips; the credits' length; barks; and
## main's way through the story.
##
## Also: panels.json's own shapes (null portrait flames, eye pupils, flipped
## anchors) and the hero portrait's flame; hosting the Keeper screen in the
## oath; the chooser's cards never overlapping; cards and the Hush's words
## kept off faces; one copy of a beat asked for twice; boss cards counted
## seen when their beat is skipped; the first-hurt bark; no hole in any
## picture along its camera's move (the belfry's wall stops at the floor
## line), and no panel edge showing through the drift or a shake.
##
## v3 (spec §6, workstreams.md ST): every scene set; the chain (boss_2_after
## -> the_pull, boss_6_after -> homecoming -> lullaby; ending and
## post_credits gone); a v2 save gets the_pull on its next map and
## homecoming after 6-4; the Hush always lowercase; the hero's name always
## {hero} (never "Waxby" outright), said at the oath and in homecoming;
## openers of at most 5 lines; the hold (headless, and held by hand:
## released halfway it pauses); if / unless shots; Mother Taper's state
## across seen sets and REST_SUBS; "off" lights and lights_on, with W1-W2's
## lights as they were before E6 (a snapshot); no scene on a string-surgery
## shader (darkness_lit.gdshader); tints on v3 panels only; the new motes;
## the credits then the cast roll; a Tales replay changes nothing.
##
## The hero's own name (the save's): the rules a name keeps to; the name
## plate, {hero}, a bark's plate and the cast roll say it; the oath asks it
## after his first words (his plate blank till then) with Taper's question
## kept up and asked again in the entry's heading (a phone's keyboard covers
## the box), and her welcome says it; nobody to type (stepped by hand,
## headless, --autoplay): Waxby at once and no entry; the entry filters what's
## typed, falls back to Waxby, keeps above a phone's keyboard at 844 x 390;
## Skip goes on to the entry with his flame lit. Every line fits in 80 with
## a name NAME_MAX long in it too.
##
##     godot --headless --path game --script res://tests/test_story.gd

const Story := preload("res://scripts/story.gd")
const UI := preload("res://scripts/ui.gd")
const Stage := preload("res://scripts/cutscene_stage.gd")
const Classes := preload("res://scripts/classes.gd")
const LevelData := preload("res://scripts/level_data.gd")
const DT := 1.0 / 60.0
const V2_PANELS := ["glass_legend", "lanternfold", "chapel", "callings", "crypt_row", "belfry",
	"tallow_vista", "undercandle", "bells_all", "dawn_rise", "hush_eye"]
# The story draft's ten (spec §6.6; the art draft's five extra are cut).
const V3_PANELS := ["orchard_vista", "heartwood", "carillon_vista", "escapement", "sanctum_vista", "glass_throne",
	"glass_truth", "hushdeep_vista", "hushdeep_heart", "homecoming"]
const PANELS := V2_PANELS + V3_PANELS
const CUT_PANELS := ["spire", "tower_window", "deep_mouth", "helmet", "moth_face", "six_bells", "evenbell_noon",
	"keepers_wall", "descent_stair", "trial_hall"]
const SPEC_SCENES := ["intro", "oath", "meet_waxley", "beat_1_1", "beat_1_2", "beat_1_3", "beat_1_4",
	"boss_1_before", "boss_1_after", "world_2", "beat_2_1", "beat_2_2", "beat_2_3", "beat_2_4",
	"boss_2_before", "boss_2_after"]
# contract.md §9.1: every v3 scene id.
const V3_SCENES := ["the_pull", "world_3", "world_4", "world_5", "world_6",
	"beat_3_1", "beat_3_2", "beat_3_3", "beat_3_4", "beat_4_1", "beat_4_2", "beat_4_3", "beat_4_4",
	"beat_5_1", "beat_5_2", "beat_5_3", "beat_5_4", "beat_6_1", "beat_6_2", "beat_6_3", "beat_6_4",
	"boss_3_before", "boss_3_after", "boss_4_before", "boss_4_after", "boss_5_before", "boss_5_after",
	"boss_6_before", "boss_6_after", "homecoming", "lullaby", "waxworks_open", "trials_open", "trials_open_hollin",
	"descent_open", "new_calling_hollin"]
# The W1-W2 scenes as v2 left them (boss_2_after trimmed by the spec).
const V2_SCENES := ["intro", "oath", "meet_waxley", "new_calling", "beat_1_1", "beat_1_2", "beat_1_3", "beat_1_4",
	"boss_1_before", "boss_1_after", "world_2", "beat_2_1", "beat_2_2", "beat_2_3", "beat_2_4", "boss_2_before", "boss_2_after"]
# contract.md §9.2: the bark keys other streams fire.
const FIRED_BARKS := ["first_vine", "first_spore", "first_ice", "first_rime", "first_belt", "first_gear", "first_pendulum",
	"first_swing", "first_wind", "first_glass", "first_dawnglass", "first_float", "first_buoy", "first_grasp",
	"first_hush_zone", "first_candle", "first_deepdark", "first_tide",
	"rootmother_p2", "rootmother_p3", "tinker_p2", "tinker_p3", "saint_p2", "saint_p3", "hush_p2", "hush_p3", "hush_last",
	"first_secret", "first_lost_wick", "lost_wick_1", "lost_wick_2", "lost_wick_3", "lost_wick_4", "lost_wick_5", "lost_wick_6",
	"secret_hint_1", "secret_hint_2", "secret_hint_3", "secret_hint_4", "secret_hint_5", "secret_hint_6",
	"descent_5", "descent_10", "descent_20", "descent_30", "descent_40", "descent_50", "descent_record",
	"waxworks_won", "waxworks_lost", "second_capstone", "reserve_stocked", "nightfall"]
# Taken out of the script by the spec (renamed or cut).
const GONE_BARKS := ["first_still", "endless_5", "endless_record", "trial_won", "trial_miss", "echo_won", "echo_lost",
	"prism_p2", "prism_p3"]
# Every v2 scene shot's lights lit as it starts, before E6 (id:k, k > 0.001,
# md5'd): E6 must change none of them. Taken from the Phase 0 cutscene.gd.
const V2_LIGHTS := {
	"intro/0": "d41d8cd98f", "intro/1": "ba0061f33f", "intro/2": "b31a08662c", "oath/0": "fcca850f62", "oath/1": "b31a08662c",
	"beat_1_2/0": "edfdb5f283", "boss_1_before/0": "233be2f85e", "boss_1_after/0": "2751a65e63", "boss_1_after/1": "c62f4b5d64",
	"boss_1_after/2": "908f37ec50", "world_2/0": "a015f811fe", "boss_2_before/0": "af47230476", "boss_2_after/0": "df0a8763cc",
	"boss_2_after/1": "13cd94e5da"}
const MAIN_SCENES := ["intro", "oath", "meet_waxley", "new_calling"]
# A stand-in 6-4 for the finale's flow (the level streams haven't built it
# yet): 1-1's rows under the Hush's story_end.
const STUB_64 := "user://test_story_stub_6-4.txt"
# The longest name the entry lets through (Story.NAME_MAX), its widest letter.
const LONGEST_NAME := "WWWWWWWWWWWW"

var Cutscene: GDScript        # loaded at run time, after the autoloads
var game: Node
var _passed := 0
var _failed := 0
var _called := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Cutscene = load("res://scripts/cutscene.gd")
	game = root.get_node_or_null("Game")
	_check(game != null, "the Game autoload is there")
	if game == null:
		quit(1)
		return
	game.save_path = "user://test_story_save.json"
	game.reset()
	# The phone's own shape (844 x 390): headless, the window is square.
	var aspect := root.content_scale_aspect
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	# Nodes added before the first frame wait for it to get their _ready.
	await process_frame
	_test_scene_ids()
	_test_slots_and_lines()
	_test_speakers_and_cues()
	await _test_hero_name()
	_test_decisions()
	_test_stage_covers_script()
	_test_art_manifest()
	_test_barks()
	await _test_every_scene_plays()
	await _test_resident()
	await _test_skip()
	await _test_overlay_fake_world()
	await _test_overlay_real_world()
	await _test_overlay_screens()
	await _test_typewriter()
	_test_wrapping()
	await _test_credits()
	_test_art_shapes()
	await _test_art_in_play()
	await _test_keeper_host()
	await _test_chooser_cards()
	await _test_text_bands()
	await _test_main_flow()
	await _test_perf_meter()
	await _test_loading_ahead()
	await _test_flow_fresh()
	await _test_flow_world_1()
	await _test_flow_ending()
	await _test_flow_veteran()
	await _test_flow_second_calling()
	_test_blips_in_key()
	await _test_taunt()
	_test_no_holes()
	_test_shake_edges()
	# v3
	_test_v3_script()
	_test_taper_state()
	await _test_rest_subs()
	await _test_if_unless()
	await _test_hold()
	await _test_off_lights()
	await _test_tints_and_motes()
	await _test_replay()
	await _test_flow_v2_save()
	await _test_flow_homecoming()
	await _test_shader()
	await _test_tales()
	root.content_scale_aspect = aspect
	game.reset()
	game.save_path = game.SAVE_PATH
	print("test_story: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _level_files() -> Array:
	var out := []
	var d := DirAccess.open("res://levels")
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".txt"):
			out.append("res://levels/" + f)
	out.sort()
	return out


func _lines_raw() -> Array:
	## [where, beat] for every line in the script.
	var out := []
	for id in Story.scenes():
		var si := 0
		for shot in Story.scene(id).get("shots", []):
			for b in shot.get("beats", []):
				if Story.is_line(b):
					out.append(["%s shot %d" % [id, si], b])
			si += 1
	for k in Story.BARKS:
		out.append(["bark " + k, Story.BARKS[k]])
	for k in Story.AFTER:
		out.append(["after " + k, Story.AFTER[k]])
	return out


func _cb() -> Callable:
	return func(): _called += 1


func _drive(cs: Node, steps := 2000, tap_every := 10) -> int:
	## Plays a cutscene with taps; answers the chooser with the first calling.
	## Returns the steps it took, or -1 if it never finished.
	for i in steps:
		if cs.finished:
			return i
		if cs.waiting == "class":
			cs.pick(Classes.enabled_ids()[0])
		elif i % tap_every == tap_every - 1:
			cs.tap()
		cs.advance(DT)
	return steps if cs.finished else -1


func _fake_world() -> Node:
	## A stand-in level: what an overlay touches, and a record of its barks.
	var ts := GDScript.new()
	ts.source_code = "extends Node\nvar visible_controls := true\nvar released := 0\nfunc release_all() -> void:\n\treleased += 1\nfunc _input(_e: InputEvent) -> void:\n\tpass\n"
	ts.reload()
	var touch: Node = ts.new()
	var ws := GDScript.new()
	ws.source_code = "extends Node2D\nvar paused := false\nvar headless := false\nvar autoplay := false\nvar state := \"play\"\nvar touch: Node\nvar boss: Object = null\nvar barks: Array = []\nfunc bark(k: String) -> void:\n\tbarks.append(k)\nfunc play_beat(_id: String, _then: Callable) -> void:\n\tpass\n"
	ws.reload()
	var w: Node = ws.new()
	w.add_child(touch)
	w.touch = touch
	root.add_child(w)
	return w


func _test_text_off_heroes(vs: Vector2) -> void:
	## The review's staging nits: over a live level the Hush's words keep off
	## the level's hero (an overlay has no figures of its own, so they used
	## to sit mid-screen on his head), and boss_3_after's last narration sits
	## at the top, off Waxby's face as the camera holds him low.
	var ws := GDScript.new()
	ws.source_code = "extends Node2D\nvar paused := false\nvar headless := false\nvar autoplay := false\nvar state := \"play\"\nvar touch: Node = null\nvar boss: Object = null\nvar player: Node2D = null\nvar barks: Array = []\nfunc bark(k: String) -> void:\n\tbarks.append(k)\nfunc play_beat(_id: String, _then: Callable) -> void:\n\tpass\n"
	ws.reload()
	var fw: Node2D = ws.new()
	root.add_child(fw)
	var pl := Node2D.new()
	fw.add_child(pl)
	pl.position = Vector2(vs.x * 0.5, vs.y * 0.62)   # his feet a little under the middle, as a level's camera keeps him
	fw.player = pl
	game.reset()
	var cs := _play("beat_6_2", true, fw)
	var n := 0
	while n < 2000 and not (cs.waiting == "line" and cs._line.get("style", "") == "hush"):
		cs.advance(DT)
		n += 1
	var hr: Array = cs._level_hero_rects()
	if cs.waiting == "line" and cs._line.get("style", "") == "hush":
		var y: float = cs.text_band(str(cs._line.get("at", "")), vs.y * 0.5, 28.0, 10.0, hr)
		var band := Rect2(vs.x * 0.2, y - 28.0, vs.x * 0.6, 38.0)
		_check(not hr.is_empty() and not (hr[0] as Rect2).intersects(band), "beat_6_2's Hush keeps off the level's hero (words at y %.0f, him %s)" % [y, hr])
	else:
		_check(false, "beat_6_2 reaches the Hush's words")
	cs.queue_free()
	fw.queue_free()
	await process_frame
	var last: Array = Story.scene("boss_3_after")["shots"][1]["beats"]
	var nar = last[last.size() - 1]
	_check(Story.is_line(nar) and str(nar[0]) == "narrator" and nar.size() > 2 and str((nar[2] as Dictionary).get("at", "")) == "top",
			"boss_3_after's last narration is at the top (the camera holds Waxby low)")


func _cutscene_in(n: Node) -> Node:
	for c in n.get_children():
		if c.get_script() == Cutscene and not c.is_queued_for_deletion():
			return c
	return null


# ---------------------------------------------------------------- the script as data

func _test_scene_ids() -> void:
	for path in _level_files():
		var lv: RefCounted = LevelData.load_file(path)
		for k in lv.story:
			_check(Story.has_scene(lv.story[k]), "%s names story_%s '%s', which exists" % [lv.id, k, lv.story[k]])
	for id in MAIN_SCENES + SPEC_SCENES + V3_SCENES:
		_check(Story.has_scene(id), "scene '%s' exists" % id)
	for w in Story.WORLD_OPENERS:
		_check(Story.has_scene(Story.WORLD_OPENERS[w]), "world %d's opening scene exists" % w)
	for id in Story.scenes():
		var sc := Story.scene(id)
		for k in ["next", "finale"]:
			if sc.has(k):
				_check(Story.has_scene(sc[k]), "%s's %s '%s' exists" % [id, k, sc[k]])
		for b in sc.get("barks", []):
			_check(Story.BARKS.has(b), "%s's bark '%s' exists" % [id, b])
		_check(sc.has("shots") or sc.has("barks"), "%s has shots or barks" % id)
	for id in Story.TITLES:
		_check(Story.has_scene(id), "the Tales title for '%s' names a scene" % id)
	# The 1-4 header wires the boss beats (W5 owns the files; this is the contract).
	var p14 := "res://levels/1-4.txt"
	if FileAccess.file_exists(p14):
		var lv: RefCounted = LevelData.load_file(p14)
		_check(lv.story.get("boss", "") == "boss_1_before" and lv.story.get("end", "") == "boss_1_after",
				"1-4 plays boss_1_before and boss_1_after")


func _test_slots_and_lines() -> void:
	var ids: Array = Classes.ids()
	for slot in Story.CLASS_LINES:
		var lines: Dictionary = Story.CLASS_LINES[slot]
		for cls in ids:
			_check(lines.has(cls) or lines.has("_"), "@%s speaks for %s" % [slot, cls])
		for cls in lines:
			var e = lines[cls]
			if e is Array:
				_check(e.size() == 2 and ((Story.MOODS["wick"] as Array).has(e[0]) or slot == "taper_react"),
						"@%s/%s's mood '%s' is one the speaker has" % [slot, cls, e[0]])
	for slot in Story.slots_used():
		_check(Story.CLASS_LINES.has(slot), "@%s is written" % slot)
	var longest := Story.longest_calling()
	_check(longest == "Candleknight", "the longest calling name is Candleknight (%s)" % longest)
	# The longest name a player can give, filled in as the longest calling is.
	_check(LONGEST_NAME.length() == Story.NAME_MAX and Story.clean_name(LONGEST_NAME) == LONGEST_NAME, "the longest name is %d letters" % Story.NAME_MAX)
	game.reset()
	game.set_hero_name(LONGEST_NAME)
	var worst := 0
	for pair in _lines_raw():
		var b: Array = pair[1]
		var raw: String = b[1]
		if not raw.begins_with("@"):
			var filled := raw.replace("{calling}", longest).replace("{hero}", LONGEST_NAME)
			worst = maxi(worst, filled.length())
			_check(filled.length() <= Story.MAX_LINE, "%s fits in 80: '%s' (%d)" % [pair[0], filled, filled.length()])
		for cls in ids:
			var r := Story.resolve(b, cls)
			_check(r["text"].length() <= Story.MAX_LINE, "%s for %s fits in 80 (%d)" % [pair[0], cls, r["text"].length()])
			_check(r["text"] != "", "%s for %s says something" % [pair[0], cls])
			_check(not r["text"].contains("{"), "%s for %s has no unfilled name" % [pair[0], cls])
	for slot in Story.CLASS_LINES:
		for cls in Story.CLASS_LINES[slot]:
			var t: String = Story.class_line(slot, cls)[1].replace("{calling}", longest)
			worst = maxi(worst, t.length())
			_check(t.length() <= Story.MAX_LINE, "@%s/%s fits in 80 (%d)" % [slot, cls, t.length()])
	for c in Story.CREDITS:
		_check(str(c[0]).length() <= Story.MAX_LINE, "the credit '%s' fits" % c[0])
	game.reset()
	print("  longest line: %d characters (a %d-letter name in it)" % [worst, Story.NAME_MAX])


func _test_speakers_and_cues() -> void:
	for pair in _lines_raw():
		var b: Array = pair[1]
		var tag: String = b[0]
		var who := tag.get_slice(":", 0)
		_check(Story.CAST.has(who), "%s: '%s' is in the cast" % [pair[0], who])
		if tag.contains(":"):
			_check((Story.MOODS.get(who, []) as Array).has(tag.get_slice(":", 1)), "%s: %s has the mood '%s'" % [pair[0], who, tag.get_slice(":", 1)])
		if who == "hush":
			_check(str(b[1]) == str(b[1]).to_lower(), "%s: the Hush speaks in lowercase" % pair[0])
		if who == "taper":
			var low := str(b[1]).to_lower()
			_check(not low.contains("health") and not low.split(" ").has("hp"), "%s: Taper never says health or HP" % pair[0])
		if b.size() > 2:
			_check(b[2] is Dictionary or str(b[2]) == "every", "%s: its third entry is options or 'every'" % pair[0])
	for id in Story.scenes():
		for shot in Story.scene(id).get("shots", []):
			_check(["fade", "cut", "flash"].has(str(shot.get("in", "fade"))), "%s: a known transition" % id)
			var cam: Array = shot.get("cam", [])
			for c in cam:
				_check((c as Array).size() == 3, "%s: a camera stop is [x, y, z]" % id)
			for b in shot.get("beats", []):
				if Story.is_line(b):
					continue
				_check(b is Dictionary and b.has("do"), "%s: a beat is a line or a cue: %s" % [id, b])
				if not (b is Dictionary):
					continue
				var cue := str(b.get("do", ""))
				_check(Story.CUES.has(cue), "%s: the cue '%s' is known" % [id, cue])
				for p in Story.CUES.get(cue, []):
					_check(b.has(p), "%s: '%s' has its %s" % [id, cue, p])


func _oath_to_name(cs: Node, cls := "runner", steps := 4000) -> Dictionary:
	## Plays an oath (its entry not instant) up to the name entry: the
	## calling picked, the lines tapped through. {steps, plate: the hero's
	## name plate on his first words}.
	var plate := "?"
	var n := 0
	while not cs.finished and cs.waiting != "name" and n < steps:
		if cs.waiting == "class":
			cs.pick(cls)
		elif cs.waiting == "line" and str(cs._line.get("who", "")) == "wick":
			plate = str(cs._line["sp"]["name"])
		if n % 10 == 9:
			cs.tap()
		cs.advance(DT)
		n += 1
	return {"steps": n, "plate": plate}


func _on_disk() -> Dictionary:
	var p = JSON.parse_string(FileAccess.get_file_as_string(game.save_path)) if FileAccess.file_exists(game.save_path) else null
	return p if p is Dictionary else {}


func _test_hero_name() -> void:
	# The rules a name keeps to (Story.clean_name; the entry's as it's typed).
	for c in [["  Ash  ", "Ash"], ["", "Waxby"], ["   ", "Waxby"], ["!!!", "Waxby"], ["--''", "Waxby"], ["Ash1", "Ash"],
			["A   B", "A B"], ["O’Neil", "O'Neil"], ["Mary–Kate", "Mary-Kate"], ["Zoë", "Zoë"], ["Ash🔥", "Ash"], ["_Ash_", "Ash"],
			["Bartholomew the Bold", "Bartholomew"], ["Mary-Kate O'Neil", "Mary-Kate O'"], [42, "Waxby"], [null, "Waxby"],
			["Rene\u0301e", "Rene\u0301e"], ["\u0301Ash", "Ash"], ["A \u0301B", "A B"], ["王小明", "王小明"]]:
		_check(Story.clean_name(c[0]) == c[1], "the name %s keeps as '%s' (%s)" % [JSON.stringify(c[0]), c[1], Story.clean_name(c[0])])
	_check(Story.name_typed("Ash ") == "Ash " and Story.name_typed(" Ash") == "Ash", "while it's typed a space may end it, never start it")
	_check(Story.name_typed("ABCDEFGHIJKLMNOP").length() == Story.NAME_MAX, "and it stops at %d" % Story.NAME_MAX)
	# The name plate, {hero}, a bark's plate and the cast roll say the save's name.
	game.reset()
	game.new_hero("witch")
	_check(Story.hero_name() == "Waxby" and Story.speaker("wick", "witch")["name"] == "Waxby", "no name given: Waxby")
	game.set_hero_name("Ash")
	_check(Story.hero_name() == "Ash" and Story.speaker("wick", "witch")["name"] == "Ash", "the hero's name plate says his name")
	_check(Story.CAST["wick"]["name"] == Story.HERO_NAME and Story.speaker("taper", "witch")["name"] == "Mother Taper", "(and no one else's changes)")
	_check(Story.fill("Well done, {hero}.", "witch") == "Well done, Ash." and Story.fill("the {calling}", "witch") == "the Taperwitch", "{hero} is his name")
	var hc := ""
	for l in Story.lines_of("homecoming", "witch"):
		if l["who"] == "taper" and str(l["text"]).begins_with("Well done"):
			hc = l["text"]
	_check(hc == "Well done, Ash.", "homecoming: %s" % hc)
	var wick_bark := ""
	for k in Story.BARKS:
		if str(Story.BARKS[k][0]).get_slice(":", 0) == "wick":
			wick_bark = k
			break
	_check(wick_bark != "" and str(Story.bark_line(wick_bark, "witch").get("name", "")) == "Ash", "a bark of his carries his plate (%s)" % wick_bark)
	_check(str(Story.bark_line("first_hurt", "witch").get("name", "")) != "Ash", "(and Taper's, hers)")
	var cc := _play("intro", false)
	var cast: Array = cc.cast_layout(0)
	_check(not cast.is_empty() and str(cast[0]["who"]) == "wick" and str(cast[0]["name"]) == "Ash", "the cast roll names him Ash")
	cc.queue_free()
	if ResourceLoader.exists("res://scripts/modes/cosmetics.gd"):
		var Cos = load("res://scripts/modes/cosmetics.gd")
		var ending: Array = Cos.ids_for("story:homecoming")
		var said := str(Cos.source_text(str(ending[0]))) if not ending.is_empty() else ""
		_check(said == "See Ash home", "the ending's flame on the Look tab: \"%s\"" % said)
	await process_frame
	# Nobody to type (stepped by hand, as the tests and the shot tools do;
	# headless; --autoplay): the oath answers Waxby at once, no entry shows.
	game.reset()
	game.set_hero_name("Ash")
	var cs := _play("oath", false)
	_check(cs.name_is_instant(), "stepped by hand, the entry answers itself")
	var showed := false
	for i in 4000:
		if cs.finished:
			break
		showed = showed or cs.waiting == "name"
		if cs.waiting == "class":
			cs.pick("knight")
		elif i % 10 == 9:
			cs.tap()
		cs.advance(DT)
	_check(cs.finished and not showed and game.hero_name() == "Waxby", "the oath goes through: no entry, and the hero is Waxby (%s)" % game.hero_name())
	await process_frame
	var auto: Node = Cutscene.make("oath", func(): pass)
	auto.auto_advance = true
	_check(auto.name_is_instant(), "--autoplay (its lines going by themselves): instant")
	auto.name_instant = false
	_check(not auto.name_is_instant(), "and name_instant says so outright")
	auto.free()
	var plain: Node = Cutscene.new()
	_check(DisplayServer.get_name() != "headless" or plain.name_is_instant(), "headless: instant")
	plain.free()
	# The entry, asked for real: after his first words (a blank plate), with
	# Taper's question kept up and the cue's prompt heading the entry; it
	# starts at Waxby and takes the keys.
	game.reset()
	cs = _play("oath", false)
	cs.name_instant = false
	var got := _oath_to_name(cs)
	_check(cs.waiting == "name" and cs.naming(), "the oath asks his name (%d steps)" % got["steps"])
	_check(got["plate"] == "", "his first words, with no name yet, have a blank plate ('%s')" % got["plate"])
	_check(game.has_hero("runner") and game.hero_name() == "Waxby", "(the calling made; still Waxby)")
	await process_frame
	var e: Control = cs.name_entry()
	_check(e != null and e.get_script().resource_path == "res://scripts/name_entry.gd" and e.is_inside_tree(), "the name entry is up")
	if e == null:
		cs.queue_free()
		return
	_check(e.field.text == "Waxby" and e.field.max_length == Story.NAME_MAX, "it holds Waxby to start, %d letters at most" % Story.NAME_MAX)
	_check(e.field.has_focus(), "its field has the keys (a phone's keyboard comes up)")
	_check(str(cs._line.get("text", "")) == "Tell the flame your name, sprout." and float(cs._box_goal) > 0.5, "Taper's question stays up under it")
	_check(e.prompt == "Tell the flame your name", "and the entry asks it in its own heading, which a phone's keyboard can't cover: '%s'" % e.prompt)
	_check(not cs._pill_visible(), "no Skip pill while it asks")
	cs.tap()
	for i in 30:
		cs.advance(DT)
	_check(cs.waiting == "name", "a tap or a wait doesn't get past it")
	var ev := InputEventKey.new()
	ev.keycode = KEY_Z
	ev.physical_keycode = KEY_Z
	ev.pressed = true
	cs._input(ev)
	_check(cs.waiting == "name" and not root.is_input_handled(), "Z (jump) is a letter there: the scene leaves it to the field")
	# What's typed: what a name can't hold doesn't land.
	e.field.text = "Ash7!"
	e.field.text_changed.emit("Ash7!")
	_check(e.field.text == "Ash", "typed 'Ash7!', the field keeps 'Ash' (%s)" % e.field.text)
	e.field.text = "O’Ne il"
	e.field.text_changed.emit("O’Ne il")
	_check(e.field.text == "O'Ne il", "a phone's curly apostrophe is a plain one (%s)" % e.field.text)
	e.field.text = "Ash"
	e.confirm_btn.pressed.emit()
	_check(game.hero_name() == "Ash" and not cs.naming() and cs.waiting != "name", "Confirm: he's Ash, and the oath goes on")
	_check(str(_on_disk().get("hero_name", "")) == "Ash", "the save holds it")
	var welcome := ""
	var n := 0
	while not cs.finished and n < 4000:
		if cs.waiting == "line" and str(cs._line.get("text", "")).begins_with("Carry the flame"):
			welcome = str(cs._line["text"])
		if n % 10 == 9:
			cs.tap()
		cs.advance(DT)
		n += 1
	_check(welcome == "Carry the flame and you're a Wick. Every keeper is. Welcome, Ash.", "Taper's welcome: %s" % welcome)
	_check(cs.finished and game.seen("oath"), "the oath ends")
	await process_frame
	# Nothing fit to keep falls back to Waxby; Return confirms.
	for typed in ["   ", "!!7", ""]:
		game.reset()
		cs = _play("oath", false)
		cs.name_instant = false
		_oath_to_name(cs)
		await process_frame
		e = cs.name_entry()
		e.field.text = typed
		e.field.text_submitted.emit(typed)
		_check(game.hero_name() == "Waxby" and cs.waiting != "name", "'%s' given (Return): Waxby" % typed)
		_check(not cs.name_hero("Ash") and game.hero_name() == "Waxby", "(answered once only)")
		cs.queue_free()
		await process_frame
	# At the phone's 844 x 390, the field and Confirm stay in sight above a
	# keyboard of any height a phone gives one; with none, it sits high.
	game.reset()
	cs = _play("oath", false)
	cs.name_instant = false
	_oath_to_name(cs)
	await process_frame
	e = cs.name_entry()
	var vs: Vector2 = root.get_visible_rect().size
	_check(vs.is_equal_approx(Vector2(844, 390)), "(the phone's own shape: %s)" % vs)
	e.keyboard_override = 0.0
	e._layout()
	_check(e.panel_rect().position.y < vs.y / 3.0 and e.field.get_global_rect().end.y <= vs.y * 0.4,
			"no keyboard: the entry sits high (%s)" % e.panel_rect())
	_check(e.confirm_btn.size.y >= UI.TAP_H - 0.5 and e.field.size.y >= UI.TAP_H - 0.5, "Confirm and the field are a thumb tall")
	_check(not e.confirm_btn.get_global_rect().intersects(e.field.get_global_rect()), "side by side, apart")
	var safe := UI.safe_rect(root)
	for kb in [160.0, 200.0, 230.0, 270.0]:
		e.keyboard_override = kb
		e._layout()
		var F: Rect2 = e.field.get_global_rect()
		var C: Rect2 = e.confirm_btn.get_global_rect()
		_check(F.position.y >= 0.0 and F.end.y <= vs.y - kb and C.end.y <= vs.y - kb, "a %d-high keyboard: the field and Confirm above it (%s, %s)" % [kb, F, C])
		var P: Rect2 = e.panel_rect()
		_check(P.position.y >= 0.0 and P.position.y + e.PROMPT_Y < F.position.y, "and the heading, her question, on the screen over the field (%s)" % P)
		_check(F.position.x >= safe.position.x and C.end.x <= safe.end.x, "and inside the safe area")
	cs.queue_free()
	await process_frame
	# Skip after the calling: on to the entry, his flame lit as the cues it
	# skipped would have left it; Skip again waits; named, the rest skips.
	game.reset()
	cs = _play("oath", false)
	cs.name_instant = false
	n = 0
	while cs.waiting != "class" and n < 600:
		cs.advance(DT)
		n += 1
	cs.pick("sexton")
	for i in 20:
		cs.advance(DT)
	cs.skip()
	for i in 5:
		cs.advance(DT)
	_check(cs.waiting == "name" and cs.naming(), "Skip after the calling goes on to the name entry (%s)" % cs.waiting)
	_check(cs._lights.has("actor") and float(cs._lights["actor"]["k"]) > 0.9, "his flame lit, as the ignite it skipped would have")
	cs.skip()
	_check(cs.waiting == "name", "Skip again: the name is still asked")
	_check(cs.name_hero("  Wren ") and game.hero_name() == "Wren", "named Wren")
	cs.skip()
	n = 0
	while not cs.finished and n < 200:
		cs.advance(DT)
		n += 1
	_check(cs.finished and game.seen("oath") and game.hero_name() == "Wren", "then the rest of the oath skips")
	game.reset()
	await process_frame


func _test_decisions() -> void:
	## decisions.md's story rules, as written into the script.
	_check(Story.CAST["wick"]["name"] == "Waxby", "the hero's name plate says Waxby")
	var intro := Story.lines_of("intro", "knight")
	_check(intro.size() <= 6, "the intro has at most 6 lines (%d)" % intro.size())
	for l in intro:
		for noun in ["Lanternfold", "Vigil", "Undercandle"]:
			_check(not l["text"].contains(noun), "the intro saves '%s' for later: %s" % [noun, l["text"]])
	# The oath: choose, Taper's reaction, the lighting, his oath; then Taper
	# asks his name, the name, the title explained, the send-off. No spire,
	# no iris.
	var seq := []
	for shot in Story.scene("oath")["shots"]:
		_check(str(shot.get("panel", "")) != "spire", "the oath has no spire shot")
		for b in shot["beats"]:
			if Story.is_line(b):
				seq.append("line")
			elif b.get("do", "") in ["choose_class", "ignite", "iris", "choose_name"]:
				seq.append(b["do"])
	_check(seq == ["choose_class", "line", "ignite", "line", "line", "choose_name", "line", "line"],
			"the oath is choose, react, ignite, his oath, the question, the name, the title, the send-off: %s" % [seq])
	var after_name := []
	var asked := ""
	for b in Story.scene("oath")["shots"][1]["beats"]:
		if b is Dictionary and b.get("do", "") == "choose_name":
			after_name.append("name")
		elif Story.is_line(b):
			if after_name.is_empty():
				asked = str(b[1])
			else:
				after_name.append(str(b[0]) + " " + str(b[1]))
	_check(asked == "Tell the flame your name, sprout.", "Taper asks his name: %s" % asked)
	_check(after_name == ["name", "taper:proud Carry the flame and you're a Wick. Every keeper is. Welcome, {hero}.",
			"taper:warm Now go and ring the bells, sprout. Give Evenbell its breath back."],
			"then the title, once, in her words, with his name, and the send-off: %s" % [after_name])
	var b11 := Story.scene("beat_1_1")
	_check((b11.get("shots", []) as Array).is_empty() and (b11.get("barks", []) as Array).size() == 2, "beat_1_1 is two barks")
	for id in ["beat_3_1", "beat_4_1", "beat_5_1", "beat_6_1"]:
		var bb := Story.scene(id)
		_check((bb.get("shots", []) as Array).is_empty() and (bb.get("barks", []) as Array).size() == 2, "%s is two barks" % id)
	for id in Story.scenes():
		var sc := Story.scene(id)
		if bool(sc.get("overlay", false)):
			_check(Story.lines_of(id, "knight").size() <= 3, "overlay %s has at most 3 lines (%d)" % [id, Story.lines_of(id, "knight").size()])
		for shot in sc.get("shots", []):
			if shot.has("panel"):
				_check(PANELS.has(shot["panel"]), "%s uses a panel that's kept: %s" % [id, shot["panel"]])
				_check(not CUT_PANELS.has(shot["panel"]), "%s uses no cut panel" % id)
	_check(str(Story.scene("world_2")["shots"][0].get("panel", "")) == "tallow_vista", "world_2 opens on tallow_vista")
	for id in ["beat_2_2", "beat_2_3"]:
		for shot in Story.scene(id)["shots"]:
			_check(not shot.has("panel"), "%s plays over the live level (no panel)" % id)
	var taunt := false
	for shot in Story.scene("boss_1_after")["shots"]:
		if shot.get("panel", "") == "belfry" and (shot.get("figs", {}) as Dictionary).values().has("snuffer_stand"):
			taunt = true
	_check(taunt, "the Snuffer's taunt plays on the belfry with snuffer_stand")
	var want := ["WAXBY", "A game by Anthony Craig", "Made with Claude", "Built with Godot",
		"Every picture drawn in code. Every sound, too.", "Thank you for keeping the light."]
	var got := []
	for c in Story.CREDITS:
		if str(c[0]) != "":
			got.append(c[0])
	_check(got == want, "the credits read as decided: %s" % [got])
	# The renames reached the words.
	var all_text := ""
	for pair in _lines_raw():
		for cls in Classes.ids():
			all_text += Story.resolve(pair[1], cls)["text"] + "\n"
	for old in ["Toll ", "Wax bar", "Level Up!", "Keeper", " Wick:"]:
		_check(not all_text.contains(old), "no old word '%s' in the lines" % old)


func _test_stage_covers_script() -> void:
	## The stand-in stage knows every panel, anchor, figure and light the
	## script names, so the story plays in full before the art exists.
	var problems := _references(func(pid): return Stage.panel(pid), func(fid): return Stage.FIGURES.get(fid, {}))
	# And what the cutscene plays with: the art where it's there, the
	# stand-in (and its manifest-only additions) where it isn't.
	var probe: Node = Cutscene.new()
	problems.append_array(_references(func(pid): return probe._panel_def(pid), func(fid): return probe._figure_def(fid)))
	probe.free()
	for p in problems:
		_check(false, "stand-in stage: " + p)
	_check(problems.is_empty(), "the stand-in stage covers the whole script")
	for pid in PANELS:
		var d := Stage.panel(pid)
		_check(not d.is_empty() and (d.get("layers", []) as Array).size() >= 1, "stand-in panel %s has layers" % pid)
		for l in d.get("layers", []):
			_check(float(l.get("depth", 1.0)) > 0.0, "%s: a layer has a depth" % pid)


func _references(panel_of: Callable, figure_of: Callable, only: Array = []) -> Array:
	## What the script names that a stage (stand-in or manifest) lacks (in
	## every scene, or only those named).
	var out := []
	for id in (only if not only.is_empty() else Story.scenes().keys()):
		for shot in Story.scene(id).get("shots", []):
			if not shot.has("panel"):
				for b in shot.get("beats", []):
					if b is Dictionary and b.get("do", "") in ["snuff", "ignite", "fig", "walk", "pose", "chain"]:
						out.append("%s: a '%s' cue with no panel" % [id, b["do"]])
				continue
			var pid: String = shot["panel"]
			var pd: Dictionary = panel_of.call(pid)
			if pd.is_empty():
				out.append("%s: panel %s is missing" % [id, pid])
				continue
			var anchors: Dictionary = pd.get("anchors", {})
			var lights := {}
			for k in pd.get("lights", {}):
				lights[k] = true
			var figs: Dictionary = shot.get("figs", {})
			var fig_ids: Array = figs.values()
			for b in shot.get("beats", []):
				if b is Dictionary and b.get("do", "") == "pose":
					fig_ids.append(b["frame"])
			for a in figs:
				if not anchors.has(a):
					out.append("%s: %s has no anchor '%s'" % [id, pid, a])
			for fid in fig_ids:
				var fd: Dictionary = figure_of.call(fid)
				if fd.is_empty():
					out.append("%s: figure %s is missing" % [id, fid])
			for a in figs:
				var fids := [figs[a]]
				for b in shot.get("beats", []):
					if b is Dictionary and b.get("do", "") == "pose" and b["fig"] == a:
						fids.append(b["frame"])
				for fid in fids:
					for fl in (figure_of.call(fid) as Dictionary).get("flames", {}):
						lights["%s.%s" % [a, fl]] = true
			if shot.has("actor"):
				if not anchors.has(shot["actor"]):
					out.append("%s: %s has no anchor '%s' for the hero" % [id, pid, shot["actor"]])
				lights["actor"] = true
			var named := []
			named.append_array(shot.get("lights_off", []))
			named.append_array((shot.get("light_r", {}) as Dictionary).keys())
			for b in shot.get("beats", []):
				if not (b is Dictionary):
					continue
				match str(b.get("do", "")):
					"snuff", "ignite", "light":
						named.append(b["light"])
					"chain":
						named.append_array(b["lights"])
					"iris":
						named.append(b["on"])
					"burst":
						named.append(b["at"])
					"fig", "pose":
						if not figs.has(b["fig"]):
							out.append("%s: a cue moves '%s', which isn't in the shot" % [id, b["fig"]])
					"walk", "face", "mood":
						if not shot.has("actor"):
							out.append("%s: '%s' with no hero in the shot" % [id, b["do"]])
			for n in named:
				if not lights.has(n) and not anchors.has(n):
					out.append("%s: %s has no light '%s'" % [id, pid, n])
	return out


func _test_art_manifest() -> void:
	var path := "res://art/story/panels.json"
	if not FileAccess.file_exists(path):
		print("  art pending: no art/story/panels.json yet (the stand-in stage plays)")
		return
	var m = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(m is Dictionary, "panels.json parses")
	if not (m is Dictionary):
		return
	var panels: Dictionary = m.get("panels", {})
	var figures: Dictionary = m.get("figures", {})
	# W1-W2's scenes need the art as it is (a regression); the v3 scenes'
	# art comes with the story art stream: until then the stand-in stage
	# plays what's missing, and this says what's pending.
	var problems := _references(func(pid): return panels.get(pid, {}), func(fid): return figures.get(fid, {}), V2_SCENES)
	for p in problems:
		_check(false, "panels.json: " + p)
	var pending := _references(func(pid): return panels.get(pid, {}), func(fid): return figures.get(fid, {}))
	var mp := 0
	var mf := 0
	for pid in PANELS:
		mp += 0 if panels.has(pid) else 1
	for fid in Stage.FIGURES:
		mf += 0 if figures.has(fid) else 1
	if not pending.is_empty():
		print("  art pending: %d panels and %d figures not in panels.json yet, %d references the stand-in stage plays" % [mp, mf, pending.size()])
	for pid in panels:
		for l in panels[pid].get("layers", []):
			_check(ResourceLoader.exists(str(l.get("tex", ""))), "panels.json: %s's layer %s exists" % [pid, l.get("tex", "")])
	for fid in figures:
		_check(ResourceLoader.exists(str(figures[fid].get("tex", ""))), "panels.json: figure %s's texture exists" % fid)
	if DirAccess.dir_exists_absolute("res://art/story/portraits"):
		# A face the art lists must be there; the rest is pending (the
		# stand-in faces play); v2's cast keeps every face it had.
		var ports: Dictionary = m.get("portraits", {})
		var faces_pending := {}
		for pair in _lines_raw():
			var r := Story.resolve(pair[1], "knight")
			if r["who"] in ["narrator", "hush", "wick"]:
				continue
			var pp := Story.portrait_path(r["who"], r["mood"], "knight")
			var moods: Array = (ports.get(Story.face_of(r["who"]), {}) as Dictionary).get("moods", [])
			if moods.has(r["mood"]):
				_check(ResourceLoader.exists(pp), "portrait %s_%s exists" % [r["who"], r["mood"]])
			elif not ResourceLoader.exists(pp):
				faces_pending[pp.get_file()] = true
		var v2_moods := {"taper": ["warm", "worried", "stern", "sad", "proud"], "waxley": ["grin", "shifty", "shock"],
			"tollgrave": ["hushed", "kind"], "snuffer": ["cold", "wrath"], "hollin": ["lost", "relit"]}
		for who in v2_moods:
			for mood in v2_moods[who]:
				_check(ResourceLoader.exists(Story.portrait_path(who, mood, "knight")), "v2 portrait %s_%s is kept" % [who, mood])
		if not faces_pending.is_empty():
			print("  art pending: %d portraits (the stand-in faces play): %s" % [faces_pending.size(), ", ".join(faces_pending.keys())])
	print("  panels.json: %d panels, %d figures checked" % [panels.size(), figures.size()])


func _test_barks() -> void:
	game.reset()
	var l := Story.bark_line("first_altar", "knight")
	_check(l.get("who", "") == "taper" and l.get("mood", "") == "warm" and str(l.get("text", "")) != "", "bark_line gives who, mood and text")
	var lu := Story.bark_line("level_up", "witch")
	_check(lu.get("who", "") == "wick" and lu.get("text", "") == Story.CLASS_LINES["level_up"]["witch"], "a hero bark speaks for the calling")
	_check(Story.bark_line("no_such_bark", "knight").is_empty(), "an unknown bark is empty")
	_check(Story.bark_every("level_up") and not Story.bark_every("first_altar"), "bark_every tells the two kinds apart")
	_check(not Story.bark_heard("first_sigil") and Story.bark_once("first_sigil"), "bark_once: true the first time")
	_check(game.seen("bark:first_sigil") and Story.bark_heard("first_sigil"), "and marks the bark seen through Game")
	_check(not Story.bark_once("first_sigil"), "bark_once: false the second time")
	_check(not Story.bark_once("level_up") and not Story.bark_once("level_up") and not Story.bark_once("no_such_bark"),
			"bark_once: always false for 'every' barks and unknown keys")
	_check(not game.seen("bark:level_up"), "an 'every' bark is never marked")
	_check(not Story.take_bark("first_altar", "knight").is_empty(), "take_bark: a once-only bark plays the first time")
	_check(game.seen("bark:first_altar"), "and is marked seen through Game")
	_check(Story.take_bark("first_altar", "knight").is_empty(), "and never again")
	_check(not Story.take_bark("level_up", "knight").is_empty() and not Story.take_bark("level_up", "knight").is_empty(),
			"an 'every' bark plays every time")
	for k in ["tollgrave_angry", "snuffer_angry", "snuffer_dark"]:
		_check(not Story.take_bark(k, "witch").is_empty() and not Story.take_bark(k, "witch").is_empty(),
				"take_bark('%s') shows twice (the HUD gates with take_bark, not bark_once)" % k)
	for k in ["first_altar", "first_relic", "first_sigil", "first_item", "first_elite", "first_dread", "first_snuff",
			"first_pool", "first_douse", "low_flame", "skill_point", "tollgrave_angry", "snuffer_angry", "snuffer_dark",
			"nightfall", "level_up", "first_hurt", "level_up_8", "level_up_16", "level_up_24"]:
		_check(Story.BARKS.has(k), "the '%s' bark world.gd and the HUD fire exists" % k)
	# skill_point names the point and both places to spend it: an altar's
	# Rites (rites.gd) and the Sheet. No bare "it" with nothing before it.
	var sp := str(Story.BARKS["skill_point"][1])
	var sp_words := Array(sp.to_lower().replace(",", " ").replace(".", " ").split(" ", false))
	_check(sp_words.has("point") and sp_words.has("altar") and sp_words.has("sheet") and not sp_words.has("it")
			and sp.length() <= Story.MAX_LINE, "skill_point says what to spend and where: '%s'" % sp)
	# A level-up that opens a tier has its own line for each calling, in the
	# bark's own format, heard every time it comes (once a hero, at 8, 16, 24).
	for t in [8, 16, 24]:
		var key := "level_up_%d" % t
		_check(Story.bark_every(key) and Story.BARKS[key][0] == Story.BARKS["level_up"][0] and Story.BARKS[key][1] == "@" + key,
				"%s is the hero's, every time, from @%s" % [key, key])
		for cls in Classes.ids():
			var tl := Story.bark_line(key, cls)
			_check(str(tl.get("text", "")) != "" and str(tl["text"]) != str(Story.bark_line("level_up", cls)["text"]) and str(tl["text"]).length() <= Story.MAX_LINE,
					"%s for %s says something of its own, in %d (%s)" % [key, cls, Story.MAX_LINE, tl.get("text", "")])
	for lv in ["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4"]:
		_check(not Story.after_line(lv, "runner").is_empty(), "the after-line for %s" % lv)
	_check(Story.after_line("9-9", "runner").is_empty(), "no after-line for a level that isn't one")


# ---------------------------------------------------------------- playing

func _play(id: String, as_overlay: bool, lvl: Node = null) -> Node:
	var cs: Node = Cutscene.new()
	cs.setup(id, _cb(), as_overlay, lvl)
	cs.manual = true
	cs.follow_next = false
	(lvl if lvl != null else root).add_child(cs)
	return cs


func _test_resident() -> void:
	## Spec §6.6: a scene holds at most two panels' pictures (this shot's and
	## the next's; the next scene's first at a hand-over): the ones before are
	## let go as each shot starts, and a scene played on into another
	## (homecoming into lullaby) leaves its own behind.
	for id in ["the_pull", "boss_6_after", "homecoming", "intro"]:
		if not Story.has_scene(id):
			continue
		game.reset()
		var cs: Node = Cutscene.new()
		cs.setup(id, _cb(), false, null)
		cs.manual = true
		cs.follow_next = id == "homecoming"
		root.add_child(cs)
		var worst := 0
		var bad := []
		var handed := false
		for i in 12000:
			if cs.finished:
				break
			if cs.waiting == "class":
				cs.pick(Classes.enabled_ids()[0])
			elif i % 10 == 9:
				cs.tap()
			cs.advance(DT)
			var allow := {}
			var si: int = cs._shot_i
			var shots: Array = cs._shots
			if si >= 0 and si < shots.size():
				for p in Cutscene.shot_textures(shots[si]):
					allow[p] = true
			if si + 1 < shots.size():
				for p in Cutscene.shot_textures(shots[si + 1]):
					allow[p] = true
			# (the shot on stage: the one fading out, or the last as it closes)
			for p in Cutscene.shot_textures(cs._shot):
				allow[p] = true
			var nx := str(cs._scene.get("next", ""))
			if si + 1 >= shots.size() and nx != "":
				for p in Cutscene.first_textures(nx):
					allow[p] = true
			var res: Array = cs.resident()
			var panels := {}
			for p in res:
				if not allow.has(p):
					bad.append("%s shot %d: %s" % [cs.scene_id, si, str(p).get_file()])
				if str(p).contains("/sets/"):
					panels[str(p).get_file().get_slice("_", 0)] = true
			worst = maxi(worst, res.size())
			handed = handed or str(cs.scene_id) != id
			if bad.size() > 3:
				break
		_check(bad.is_empty(), "%s holds only this shot's picture and the next's (%d textures at most): %s" % [id, worst, bad.slice(0, 3)])
		if id == "homecoming" and Story.has_scene("lullaby"):
			_check(handed, "(homecoming played on into lullaby)")
		cs.queue_free()
		await process_frame


func _test_every_scene_plays() -> void:
	var fw := _fake_world()
	var worst := ["", 0]
	for id in Story.scenes():
		var sc := Story.scene(id)
		if (sc.get("shots", []) as Array).is_empty():
			continue
		game.reset()
		_called = 0
		var ov := bool(sc.get("overlay", false))
		var cs := _play(id, ov, fw if ov else null)
		var steps := _drive(cs, 4000)
		_check(steps >= 0, "%s plays to its end within 4000 steps" % id)
		for i in 30:
			cs.advance(DT)
			cs.tap()
		_check(_called == 1, "%s calls back exactly once (%d)" % [id, _called])
		_check(game.seen(id), "%s is marked seen" % id)
		if steps > int(worst[1]):
			worst = [id, steps]
		await process_frame
	print("  longest scene with taps: %s, %d steps (%.1f s)" % [worst[0], worst[1], worst[1] * DT])
	# A chained scene plays its "next" before calling back.
	game.reset()
	_called = 0
	var chain: Node = Cutscene.make("homecoming", _cb())
	chain.manual = true
	root.add_child(chain)
	var steps := _drive(chain, 8000)
	_check(steps >= 0 and _called == 1, "homecoming plays on into lullaby, then calls back once")
	_check(game.seen("homecoming") and game.seen("lullaby"), "both are marked seen")
	# Auto-advance plays a scene with no taps at all.
	game.reset()
	_called = 0
	var au := _play("intro", false)
	au.auto = true
	var n := 0
	while not au.finished and n < 4000:
		au.advance(DT)
		n += 1
	_check(au.finished and _called == 1, "auto-advance plays the intro by itself (%.1f s)" % (n * DT))
	fw.queue_free()
	await process_frame


func _test_skip() -> void:
	game.reset()
	_called = 0
	var cs := _play("intro", false)
	for i in 40:
		cs.advance(DT)
	cs.skip()
	var n := 0
	while not cs.finished and n < 120:
		cs.advance(DT)
		n += 1
	_check(cs.finished and _called == 1, "skip() ends the intro and calls back (%d steps)" % n)
	_check(game.seen("intro"), "skip() marks the scene seen")
	await process_frame
	# The oath can't be skipped past the choice.
	game.reset()
	_called = 0
	var oath := _play("oath", false)
	for i in 30:
		oath.advance(DT)
	oath.skip()
	for i in 5:
		oath.advance(DT)
	_check(oath.waiting == "class" and not oath.finished, "skipping the oath still asks for a calling")
	var sealed := ""
	for c in Classes.ALL:
		if not bool(Classes.ALL[c]["enabled"]):
			sealed = c
	_check(sealed == "" or not oath.pick(sealed), "a sealed calling can't be picked")
	_check(not oath.pick("nobody"), "an unknown calling can't be picked")
	_check(oath.pick("witch"), "the Taperwitch is picked")
	_check(game.has_hero("witch") and game.hero_id() == "witch", "picking makes the hero")
	oath.skip()
	n = 0
	while not oath.finished and n < 120:
		oath.advance(DT)
		n += 1
	_check(oath.finished and _called == 1 and game.seen("oath"), "then the rest of the oath skips")
	await process_frame
	# Skipped while it fades out to its first panel: it still closes.
	game.reset()
	var fw := _fake_world()
	var mid: Node = Cutscene.play_overlay(fw, "beat_1_2", func(): pass)
	mid.manual = true
	for i in 6:
		mid.advance(DT)
	_check(mid.waiting == "fade_out", "beat_1_2 fades out to its panel first")
	mid.skip()
	n = 0
	while not mid.finished and n < 200:
		mid.advance(DT)
		n += 1
	_check(mid.finished and not fw.paused, "an overlay skipped mid-fade still closes and unpauses (%d steps)" % n)
	fw.queue_free()
	await process_frame
	# play_scene adds a full scene to a parent; resume() goes on past a chooser
	# answered elsewhere.
	game.reset()
	_called = 0
	var holder := Node.new()
	root.add_child(holder)
	var ps: Node = Cutscene.play_scene(holder, "oath", _cb())
	_check(ps != null and ps.get_parent() == holder and not ps.overlay, "play_scene plays a full scene in its parent")
	ps.manual = true
	n = 0
	while ps.waiting != "class" and n < 600:
		ps.advance(DT)
		n += 1
	game.new_hero("runner")
	ps.resume()
	_check(ps.waiting != "class" and ps.cls == "runner", "resume() goes on with the calling chosen elsewhere")
	_drive(ps)
	_check(ps.finished and _called == 1, "and the oath ends")
	_check(Cutscene.play_scene(holder, "no_such_scene", _cb()) == null and _called == 2, "an unknown scene just calls back")
	holder.queue_free()
	await process_frame
	# The pill: two taps for a new scene, one for a seen one.
	game.reset()
	var p1 := _play("boss_1_after", false)
	for i in 30:
		p1.advance(DT)
	p1._pill_tap()
	_check(p1.waiting != "close", "one tap on Skip doesn't skip a new scene")
	p1._pill_tap()
	_check(p1.waiting == "close", "a second tap does")
	await process_frame
	var p2 := _play("boss_1_after", false)
	p2.seen_before = true
	for i in 30:
		p2.advance(DT)
	p2._pill_tap()
	_check(p2.waiting == "close", "one tap skips a scene seen before")
	for c in [p1, p2]:
		c.queue_free()
	await process_frame


func _test_overlay_fake_world() -> void:
	game.reset()
	var fw := _fake_world()
	var touch: Node = fw.touch
	_called = 0
	var cs: Node = Cutscene.play_overlay(fw, "beat_1_3", _cb())
	_check(cs != null, "an overlay beat plays over the level")
	if cs == null:
		return
	cs.manual = true
	_check(fw.paused, "the level is paused under it")
	_check(not touch.visible_controls and not touch.is_processing_input() and touch.released == 1,
			"the touch buttons are let go, muted and hidden")
	_drive(cs)
	_check(cs.finished and _called == 1, "the overlay finishes and calls back once")
	_check(not fw.paused, "the level is unpaused after")
	_check(touch.visible_controls and touch.is_processing_input(), "the touch buttons come back")
	var q := fw.get_node_or_null("StoryBarks")
	_check(q != null, "its barks are queued for live play")
	if q != null:
		for i in 400:
			if q.is_queued_for_deletion():
				break
			q.step(DT)
		_check(fw.barks == ["beat_1_3_a", "beat_1_3_b"], "the barks play in order after it: %s" % [fw.barks])
	await process_frame
	# A boss's beat marks his HUD card seen, so a retry is straight to the fight.
	var bs := GDScript.new()
	bs.source_code = "extends Node\nvar boss_id := \"tollgrave\"\n"
	bs.reload()
	var boss: Node = bs.new()
	fw.add_child(boss)
	fw.boss = boss
	var cb: Node = Cutscene.play_overlay(fw, "boss_1_before", func(): pass)
	cb.manual = true
	_drive(cb)
	_check(game.seen("boss_1_before") and game.seen("boss_card_tollgrave"), "the boss beat marks itself and his card seen")
	# Skipped before the card: the card still counts as seen.
	game.reset()
	var sk: Node = Cutscene.play_overlay(fw, "boss_1_before", func(): pass)
	sk.manual = true
	for i in 5:
		sk.advance(DT)
	_check(not game.seen("boss_card_tollgrave"), "(the card isn't up yet)")
	sk.skip()
	for i in 200:
		if sk.finished:
			break
		sk.advance(DT)
	_check(sk.finished and game.seen("boss_card_tollgrave"), "a boss beat skipped before its card still marks the card seen")
	_check(not fw.paused, "and gives the level back")
	fw.boss = null
	boss.queue_free()
	await process_frame
	# Asked for twice at once (a screen and main both): one copy plays, and
	# both callers hear when it ends.
	game.reset()
	var screen := Control.new()
	root.add_child(screen)
	var heard := [0, 0]
	var one: Node = Cutscene.play_overlay(screen, "meet_waxley", func(): heard[0] += 1)
	var two: Node = Cutscene.play_overlay(screen, "meet_waxley", func(): heard[1] += 1)
	var copies := 0
	for c in screen.get_children():
		if c.get_script() == Cutscene:
			copies += 1
	_check(one != null and one == two and copies == 1, "a beat asked for twice on one screen plays once (%d)" % copies)
	one.manual = true
	_drive(one)
	_check(heard == [1, 1], "and both callers are called back once: %s" % [heard])
	var three: Node = Cutscene.play_overlay(screen, "meet_waxley", func(): pass)
	_check(three != null and three != one, "once it's over, a new one can play")
	if three != null:
		three.manual = true
		_drive(three)
	screen.queue_free()
	await process_frame
	# Paused already (the pause menu): stays paused after.
	fw.paused = true
	var cs2: Node = Cutscene.play_overlay(fw, "beat_1_4", func(): pass)
	cs2.manual = true
	_drive(cs2)
	_check(fw.paused, "a level paused before the overlay stays paused after")
	fw.paused = false
	await process_frame
	# A bark-only beat: no pause, straight back, barks queued, seen.
	_called = 0
	fw.barks.clear()
	var none: Node = Cutscene.play_overlay(fw, "beat_1_1", _cb())
	_check(none == null and _called == 1 and not fw.paused, "beat_1_1 never stops play")
	_check(game.seen("beat_1_1"), "and is marked seen")
	var q2: Node = null
	for c in fw.get_children():
		if str(c.name).begins_with("StoryBarks") and not c.is_queued_for_deletion():
			q2 = c
	_check(q2 != null, "beat_1_1's barks are queued")
	if q2 != null:
		for i in 600:
			if q2.is_queued_for_deletion():
				break
			q2.step(DT)
	_check(fw.barks == ["beat_1_1_a", "beat_1_1_b"], "its two barks follow: %s" % [fw.barks])
	# The bot and headless worlds never see a beat.
	fw.headless = true
	_called = 0
	_check(Cutscene.play_overlay(fw, "beat_1_3", _cb()) == null and _called == 1 and not fw.paused, "a headless level just calls back")
	fw.headless = false
	fw.autoplay = true
	_called = 0
	_check(Cutscene.play_overlay(fw, "beat_1_3", _cb()) == null and _called == 1 and not fw.paused, "the autoplay bot just calls back")
	_called = 0
	_check(Cutscene.play_overlay(fw, "no_such_beat", _cb()) == null and _called == 1, "an unknown beat just calls back")
	fw.queue_free()
	await process_frame


func _test_overlay_real_world() -> void:
	## A real level with its HUD and touch buttons: 1-2 opens on an overlay.
	game.reset()
	var path := "res://levels/1-2.txt"
	if not FileAccess.file_exists(path):
		return
	var World: GDScript = load("res://scripts/world.gd")
	var w: Node = World.new()
	w.setup(LevelData.load_file(path))
	root.add_child(w)
	var cs := _cutscene_in(w)
	_check(cs != null, "1-2 opens on its beat")
	if cs == null:
		w.queue_free()
		return
	cs.manual = true
	_check(w.paused and w.touch != null and not w.touch.visible_controls and not w.touch.is_processing_input(),
			"the level is paused and its touch buttons muted")
	# The HUD (layer 5, under the letterbox's layer 8) is hidden, so the top
	# bar never cuts its life bar in half; it's back once the bars are gone.
	_check(w.hud != null and not w.hud.visible and w.hud.layer < cs.layer, "the HUD is hidden under the letterbox")
	for i in 30:
		cs.advance(DT)
	_check(not w.hud.visible and cs._lb > 0.99, "and stays hidden while the bars are down")
	_drive(cs)
	_check(cs.finished, "the beat finishes")
	_check(not w.paused and w.touch.visible_controls and w.touch.is_processing_input(), "the level and its buttons are given back")
	_check(w.hud.visible, "and its HUD")
	_check(game.seen("beat_1_2"), "beat_1_2 is seen")
	# A beat over a HUD someone else hid (the pause menu) leaves it hidden.
	w.hud.visible = false
	var cs3: Node = Cutscene.play_overlay(w, "beat_1_3", func(): pass)
	cs3.manual = true
	_drive(cs3)
	_check(cs3.finished and not w.hud.visible, "a HUD hidden before the beat stays hidden after")
	w.hud.visible = true
	w.queue_free()
	await process_frame
	# The second time in, no beat.
	var w2: Node = World.new()
	w2.setup(LevelData.load_file(path))
	root.add_child(w2)
	_check(_cutscene_in(w2) == null and not w2.paused, "a seen beat doesn't play again")
	w2.queue_free()
	await process_frame


func _top_row_rects(screen: Node) -> Array:
	## [name, rect] of what a screen shows up top: its small controls, and
	## what the map and the Chandler draw there themselves.
	var out := []
	var stack: Array = [screen]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		stack.append_array(nd.get_children())
		if nd is Control and nd != screen and (nd as Control).is_visible_in_tree():
			var r := (nd as Control).get_global_rect()
			if r.size.x > 0.0 and r.size.y > 0.0 and r.size.y <= 100.0:
				out.append([str(nd.name) + (" \"%s\"" % nd.text if nd is Button else ""), r])
	if screen.has_method("bell_rects"):
		for r in screen.bell_rects():
			out.append(["bell", r])
		out.append(["hero pill", screen.pill_rect()])
		if screen.world_open(2):
			for r in screen.tab_rects():
				out.append(["world tab", r])
	if screen.has_method("_line_row"):
		var sf: Rect2 = screen._safe()
		out.append(["purse", Rect2(sf.end.x - 102.0, sf.position.y, 102.0, float(screen.HEADER_H))])
		out.append(["Waxley's row", screen._line_row()])
	return out


func _test_overlay_screens() -> void:
	## A beat over a screen (Waxley on the Chandler, Taper's word for a new
	## calling on the map): the top bar covers the screen's whole top row,
	## so its edge cuts nothing there in half, and there's no bottom bar to
	## cut the bottom row (the map's Callings and Play, the Chandler's cards
	## either side of the dialogue box). Skip sits in the bar, on none of the
	## screen's own buttons. On the phone's safe area and a Mac's.
	var UIs: GDScript = load("res://scripts/ui.gd")
	var vs := root.get_visible_rect().size
	var Chandler: GDScript = load("res://scripts/chandler_screen.gd")
	var MapS: GDScript = load("res://scripts/map_screen.gd")
	for safe in [UIs.phone_safe(vs), Rect2(14, 10, vs.x - 28, vs.y - 18)]:
		UIs.safe_override = safe
		for which in ["chandler", "map", "map_world_2"]:
			game.reset()
			game.new_hero("knight")
			game.data["embers"] = 640
			var screen: Node
			var cs: Node
			if which == "chandler":
				screen = Chandler.new()
				root.add_child(screen)
				cs = Cutscene.running_on(screen, "meet_waxley")
			else:
				if which == "map_world_2":
					_clear_up_to("2-1")
				game.new_hero("witch")
				screen = MapS.new()
				root.add_child(screen)
				cs = Cutscene.play_overlay(screen, "new_calling", func(): pass)
			await process_frame
			var tag := "%s (safe top %.0f, right %.0f)" % [which, safe.position.y, safe.end.x]
			_check(cs != null, "a beat plays over the %s" % tag)
			if cs == null:
				screen.queue_free()
				continue
			cs.manual = true
			for i in 40:
				cs.advance(DT)
			var h: float = cs.top_bar_h()
			_check(cs._lb > 0.99 and h >= safe.position.y + 40.0, "the top bar is down, past the %s's top row: %.1f" % [tag, h])
			var cut := []
			var pill: Rect2 = cs._pill_rect()
			var on := []
			for nr in _top_row_rects(screen):
				var r: Rect2 = nr[1]
				if r.position.y < h - 0.5 and r.end.y > h + 0.5:
					cut.append("%s %s" % [nr[0], r])
				if r.end.y > h + 0.5 and r.intersects(pill):
					on.append(nr[0])
			_check(cut.is_empty(), "the bar's edge cuts nothing on the %s in half: %s" % [tag, cut])
			_check(Rect2(0, 0, vs.x, h).encloses(pill) and pill.end.x <= safe.end.x and pill.position.y >= 0.0,
					"Skip is in the bar, inside the safe area on the %s: %s" % [tag, pill])
			_check(on.is_empty(), "and on none of its buttons: %s" % [on])
			var edge: float = vs.y - cs.bottom_bar_h()
			var cut_low := []
			for nr in _top_row_rects(screen):
				var r: Rect2 = nr[1]
				if r.position.y < edge - 0.5 and r.end.y > edge + 0.5:
					cut_low.append("%s %s" % [nr[0], r])
			_check(cs.bottom_bar_h() == 0.0 and cut_low.is_empty(), "no bottom bar over the %s, so its bottom row isn't cut: %s" % [tag, cut_low])
			cs.skip()
			for i in 200:
				if cs.finished:
					break
				cs.advance(DT)
			screen.queue_free()
			await process_frame
	UIs.safe_override = Rect2()
	# Over a level the bar stays a letterbox (the HUD is hidden instead).
	var fw := _fake_world()
	var lv: Node = Cutscene.play_overlay(fw, "beat_1_3", func(): pass)
	lv.manual = true
	_check(is_equal_approx(lv.top_bar_h(), lv.LETTERBOX) and lv._pill_rect().end.y <= lv.LETTERBOX, "over a level the top bar is the letterbox's, Skip in it")
	lv.skip()
	for i in 200:
		if lv.finished:
			break
		lv.advance(DT)
	fw.queue_free()
	game.reset()
	await process_frame


func _test_typewriter() -> void:
	game.reset()
	var fw := _fake_world()
	var cs: Node = Cutscene.play_overlay(fw, "beat_1_4", func(): pass)
	cs.manual = true
	var n := 0
	while cs.waiting != "line" and n < 200:
		cs.advance(DT)
		n += 1
	var text: String = cs._line["text"]
	var pauses := 0.0
	var nonspace := 0
	for i in text.length():
		var ch := text[i]
		# (A pause after the last letter never shows: the line is done.)
		if ".!?".contains(ch) and i < text.length() - 1:
			pauses += 0.18
		elif ch == "," and i < text.length() - 1:
			pauses += 0.08
		if ch != " ":
			nonspace += 1
	var want := text.length() / 45.0 + pauses
	var t := 0.0
	cs.tap()
	_check(not cs._line["done"], "a tap inside the first 0.15 s is ignored")
	while not cs._line["done"] and t < 10.0:
		cs.advance(DT)
		t += DT
	_check(absf(t - want) < 0.12, "the typewriter runs at 45 a second with its pauses (%.2f s, want %.2f)" % [t, want])
	_check(cs.blips == int(ceil(nonspace / 3.0)), "a blip every third letter (%d for %d letters)" % [cs.blips, nonspace])
	cs.tap()
	_check(cs.waiting == "line" and cs._line["text"] != text, "a tap after the line moves on")
	for i in 3:
		cs.advance(DT)
	cs.tap()
	_check(not cs._line["done"], "a second tap too soon is ignored")
	for i in 12:
		cs.advance(DT)
	cs.tap()
	_check(cs._line["done"], "a tap mid-line finishes it")
	cs.skip()
	for i in 60:
		cs.advance(DT)
	fw.queue_free()
	await process_frame


func _test_wrapping() -> void:
	## Every box line fits the box in at most two lines at phone and desk
	## widths, and never leaves one lonely word on the second.
	var cs: Node = Cutscene.new()
	var f: Font = load("res://scripts/ui.gd").font("body", 600)
	var bad := 0
	for pair in _lines_raw():
		for cls in Classes.ids():
			var r := Story.resolve(pair[1], cls)
			if Story.speaker(r["who"], cls)["style"] != "box":
				continue
			for width in [540.0, 565.0, 600.0, 644.0]:
				var lines: PackedStringArray = cs._wrap(r["text"], f, 22 if r["shout"] else 18, width)
				if lines.size() > 2 or (lines.size() == 2 and lines[1].split(" ").size() < 2):
					bad += 1
					if bad <= 5:
						print("  wraps badly at %d: %s" % [width, " | ".join(lines)])
	_check(bad == 0, "every box line wraps into two balanced lines at most (%d bad)" % bad)
	cs.free()


func _test_credits() -> void:
	## homecoming ends in the credits: v2's approved lines (6 to 12 s), then
	## the cast roll (the owner's answer), a page of friends and one of every
	## boss, each with a small portrait; a tap speeds it all up.
	game.reset()
	game.new_hero("sexton")
	var cs := _play("homecoming", false)
	var n := 0
	while cs.waiting != "credits" and n < 6000 and not cs.finished:
		if cs.waiting == "line" and n % 10 == 9:
			cs.tap()
		cs.advance(DT)
		n += 1
	_check(cs.waiting == "credits" and cs.credits_phase() == "roll", "homecoming reaches its credits")
	var steps := 0
	while cs.credits_phase() == "roll" and steps < 1200:
		cs.advance(DT)
		steps += 1
	_check(steps * DT <= 12.0 and steps * DT >= 6.0, "v2's credit lines last 6 to 12 s (%.1f s)" % (steps * DT))
	_check(cs.credits_phase() == "cast" and cs.cast_page() == 0, "then the cast roll")
	var names := []
	var pages := {}
	var cast_steps := 0
	while cs.waiting == "credits" and cast_steps < 2000:
		var pg: int = cs.cast_page()
		if pg >= 0 and not pages.has(pg):
			pages[pg] = true
			var safe: Rect2 = cs._safe()
			for e in cs.cast_layout(pg):
				names.append(e["name"])
				var c: Vector2 = e["c"]
				_check(c.x - float(e["w"]) * 0.5 >= safe.position.x - 0.5 and c.x + float(e["w"]) * 0.5 <= safe.end.x + 0.5
						and c.y - float(e["r"]) >= cs.LETTERBOX + 50.0 and c.y + 76.0 <= 390.0 - cs.LETTERBOX,
						"cast page %d: %s sits inside the safe area, under the title" % [pg, e["name"]])
				# (the cast roll draws each face's 128 px copy, asked for on a
				# thread as the credits begin: the rev5 review's 1.3 s freeze)
				var pp := Story.portrait_path(e["who"], e["mood"], "sexton")
				if str(e["who"]) != "wick":
					pp = UI.hud_face(pp)
				_check(cs._tex.has(pp) or cs._requested.has(pp), "%s's portrait (its small copy) was asked for before it's drawn" % e["name"])

		cs.advance(DT)
		cast_steps += 1
	_check(pages.size() == Story.CAST_ROLL.size(), "every cast page shows (%d)" % pages.size())
	for want in ["Waxby", "Mother Taper", "Hollin", "Waxley", "Tessel", "Mother Yarrow", "Master Tickwell", "The Lost Wicks",
			"Old Tollgrave", "The Snuffer", "Mother Gravebough", "The Tinker of Hours", "The Prism Saint", "The Hush"]:
		_check(names.has(want), "the cast roll names %s" % want)
	_check(cast_steps * DT <= 14.0, "the cast roll lasts %.1f s" % (cast_steps * DT))
	var lay: Array = cs.cast_layout(0)
	_check(not lay.is_empty() and str(lay[0]["what"]) == "the Sexton", "Waxby is named with his calling (%s)" % [lay[0]["what"] if not lay.is_empty() else ""])
	# The Lost Wicks' caption says how many came home (none here); nothing in
	# it says what the story doesn't.
	var lw := lay.filter(func(e): return e["name"] == "The Lost Wicks")
	_check(lw.size() == 1 and str(lw[0]["what"]) == "six old keepers, still waiting", "the Lost Wicks wait, none found: %s" % [lw])
	game.mark_seen("lost_wick:3")
	game.mark_seen("bark:lost_wick_5")
	lw = cs.cast_layout(0).filter(func(e): return e["name"] == "The Lost Wicks")
	_check(lw.size() == 1 and str(lw[0]["what"]) == "two of six, home at last", "two found: %s" % [lw])
	for w in range(1, 7):
		game.mark_seen("lost_wick:%d" % w)
	lw = cs.cast_layout(0).filter(func(e): return e["name"] == "The Lost Wicks")
	_check(lw.size() == 1 and str(lw[0]["what"]) == "six old keepers, home at last", "all six: home at last")
	for e in cs.cast_layout(0):
		_check(not str(e["what"]).contains("{") and not str(e["what"]).contains("abbess of"), "%s's caption: %s" % [e["name"], e["what"]])
	cs.queue_free()
	await process_frame
	# A tap speeds the whole roll up.
	var fast := _play("homecoming", false)
	n = 0
	while fast.waiting != "credits" and n < 6000 and not fast.finished:
		if fast.waiting == "line" and n % 10 == 9:
			fast.tap()
		fast.advance(DT)
		n += 1
	fast.tap()
	var fs := 0
	while fast.waiting == "credits" and fs < 3000:
		fast.advance(DT)
		fs += 1
	_check(fs * DT < 8.0, "tapped, the credits and the cast go by fast (%.1f s)" % (fs * DT))
	fast.queue_free()
	await process_frame


# ---------------------------------------------------------------- the art's own shapes

# A figure and portraits as W6c's panels.json writes them.
const W6C_SNUFFER := {"tex": "res://icon.svg", "frame": [256, 256], "feet": [128.0, 244.0], "h": 282.4,
	"flames": {"eyes": [133.96, 142.18, 2.55]},
	"light": {"eyes": {"kind": "eyes", "color": "e8e4ff", "pts": [[125.04, 142.81], [142.89, 141.54]], "dot": 1.44, "r": 59.5, "s": 0.6}}}
const W6C_PORTRAITS := {
	"taper": {"moods": ["warm"], "flame": [63.11, 1.38, 15.11], "flames": [[63.11, 1.38, 15.11]]},
	"waxley": {"moods": ["grin"], "flame": [28.44, 33.73, 13.33], "flames": [[28.44, 33.73, 13.33], [99.56, 33.73, 13.33]]},
	"tollgrave": {"moods": ["hushed", "kind"], "flame": null, "flames": []},
	"hollin": {"moods": ["lost", "relit"], "flame": null, "flames": [], "mood_flames": {"relit": [[57.96, 1.86, 15.11]]}}}


func _test_art_shapes() -> void:
	## The pure readers of panels.json's and rig.json's shapes.
	var pf: Callable = Cutscene.portrait_flames
	_check(pf.call(W6C_PORTRAITS["tollgrave"], "hushed") == [], "a null portrait flame is no flame (and no error)")
	_check(pf.call({"flame": null}, "kind") == [], "a lone null flame is no flame")
	_check(pf.call(W6C_PORTRAITS["taper"], "warm") == [[63.11, 1.38, 15.11]], "a portrait's one flame")
	_check((pf.call(W6C_PORTRAITS["waxley"], "grin") as Array).size() == 2, "a portrait's flames list, both of them")
	_check(pf.call(W6C_PORTRAITS["hollin"], "lost") == [] and pf.call(W6C_PORTRAITS["hollin"], "relit") == [[57.96, 1.86, 15.11]],
			"mood_flames: Hollin's candle burns only once he's relit")
	_check(pf.call({"flame": [40, 10]}, "x") == [[40.0, 10.0, 12.0]], "a two-number flame gets a small height")
	_check(pf.call({"flames": [50, 12, 9]}, "x") == [[50.0, 12.0, 9.0]], "one flame given bare in 'flames'")
	_check(pf.call({}, "x") == [] and pf.call(null, "x") == [] and pf.call({"flame": "nope"}, "x") == [], "nothing, or nonsense, is no flame")
	# The hero's portrait flame: uv wins; else portrait_flame over the viewbox's size (from its corner).
	var hf: Callable = Cutscene.hero_portrait_flame
	var witch := {"portrait_flame": [64, 10.5], "portrait_flame_uv": [0.64, 0.105], "portrait_viewbox": [20, -4.5, 100, 100], "flame_scale": 0.95}
	var w: Dictionary = hf.call(witch, 1.0)
	_check(not w.is_empty() and (w["uv"] as Vector2).is_equal_approx(Vector2(0.64, 0.105)), "the hero portrait's flame from portrait_flame_uv")
	_check(is_equal_approx(float(w["h"]), 15.0 * 0.95), "sized by the calling's flame_scale (%.2f)" % float(w.get("h", 0.0)))
	var knight: Dictionary = hf.call({"portrait_flame": [37, 8], "portrait_viewbox": [23, 11, 82, 82]}, 1.0)
	_check(not knight.is_empty() and (knight["uv"] as Vector2).is_equal_approx(Vector2(37.0 / 82.0, 8.0 / 82.0)),
			"portrait_flame is read inside the viewbox (its corner isn't taken off twice)")
	_check((hf.call({}, 1.0) as Dictionary).is_empty(), "a rig with no portrait flame: none")
	for c in Classes.ids():
		var rp := "res://art/heroes/%s/rig.json" % c
		if FileAccess.file_exists(rp):
			var rd = JSON.parse_string(FileAccess.get_file_as_string(rp))
			if rd is Dictionary and rd.has("portrait_flame_uv"):
				var r: Dictionary = hf.call(rd, 1.0)
				var uv: Vector2 = r.get("uv", Vector2(-1, -1))
				_check(uv.x > 0.0 and uv.x < 1.0 and uv.y >= 0.0 and uv.y < 0.5, "%s's portrait flame burns inside the top of its picture" % c)
	# A figure's light: W6c's eyes (pupils, their size and colour), a flame's own r and s, and the old stand-in shape.
	var fl: Callable = Cutscene.fig_light
	var e: Dictionary = fl.call("snuffer_reach", "eyes", W6C_SNUFFER["flames"]["eyes"], W6C_SNUFFER["light"]["eyes"])
	_check(e["kind"] == "eyes" and e["col"] == "e8e4ff" and (e["pts"] as Array).size() == 2, "W6c's eyes: kind, colour and two pupils")
	_check(is_equal_approx(float(e["dot"]), 1.44) and is_equal_approx(float(e["r"]), 59.5) and is_equal_approx(float(e["s"]), 0.6),
			"the pupils' size and the light's r and s come from the art")
	_check((e["pts"][0] as Vector2).is_equal_approx(Vector2(125.04, 142.81)), "the first pupil where the art put it")
	var t: Dictionary = fl.call("tollgrave_boss", "eyes", [153.4, 125.0, 9.0], null)
	_check(t["col"] == "7ef0c8", "Tollgrave's eyes are teal when the art gives no colour")
	var gap: float = absf((t["pts"][1] as Vector2).x - (t["pts"][0] as Vector2).x)
	_check(gap > 0.0 and gap < 20.0, "and default pupils sit close together (%.1f apart)" % gap)
	_check(fl.call("moth_swarm", "eyes", [128, 123, 3], {"kind": "eyes"})["col"] == "d8e8c8", "the moths' eyes default to ivory-green")
	_check(fl.call("mystery", "eyes", [128, 123, 3], null)["col"] == "f7b64a", "an unknown figure's eyes are amber")
	var head: Dictionary = fl.call("taper_stand", "head", [132.0, 122.45, 26.0], {"kind": "flame", "r": 150.0, "s": 0.95})
	_check(head["kind"] == "flame" and is_equal_approx(float(head["r"]), 150.0) and is_equal_approx(float(head["h"]), 26.0),
			"a figure's flame: its height, and the light's radius from the art")
	var odd: Dictionary = fl.call("tollgrave_boss", "eyes", [140, 120, null], {"kind": "eyes", "pts": null, "dot": null, "r": null, "color": null})
	_check(odd["col"] == "7ef0c8" and (odd["pts"] as Array).size() == 2 and float(odd["dot"]) > 0.0, "nulls in a figure's light fall back quietly")
	var old: Dictionary = fl.call("x", "eyes", [128, 96, 5, "eyes", "7ef0c8"], null)
	_check(old["col"] == "7ef0c8" and (old["fp"] as Vector2).is_equal_approx(Vector2(128, 96)), "the older [x, y, h, kind, colour] shape still reads")
	for fid in Stage.FIGURES:
		var d: Dictionary = Stage.FIGURES[fid]
		for n in d.get("flames", {}):
			var r: Dictionary = fl.call(fid, n, d["flames"][n], d.get("light", {}).get(n, null))
			if r["kind"] == "eyes":
				_check((r["pts"] as Array).size() == 2 and r["col"] != "", "stand-in %s has two coloured pupils" % fid)
	# The chooser's spacing rule.
	var sp: Callable = Cutscene.spread
	var got: Array = sp.call([150.0, 286.0, 422.0, 558.0, 693.0], 150.0, 89.0, 755.0)
	var ok := true
	for i in range(1, got.size()):
		ok = ok and float(got[i]) - float(got[i - 1]) >= 149.99
	_check(ok and float(got[0]) >= 89.0 and float(got[4]) <= 755.0, "spread keeps cards apart and inside: %s" % [got])
	_check(absf((float(got[0]) + float(got[4])) * 0.5 - 422.0) < 1.0, "and centred where they wanted to be")
	_check(sp.call([100.0, 300.0, 500.0], 150.0, 50.0, 600.0) == [100.0, 300.0, 500.0], "cards already apart don't move")
	var tight: Array = sp.call([400.0, 400.0, 400.0], 150.0, 350.0, 450.0)
	_check(tight == [350.0, 400.0, 450.0], "too many to fit: evenly spread across the room")


func _test_art_in_play() -> void:
	## panels.json's shapes playing: a flipped anchor mirrors its figure and
	## its eye-lights, and a speaker with a null portrait flame is fine.
	var kept = Cutscene._manifest
	var panel := Stage.panel("crypt_row").duplicate(true)
	panel["anchors"] = {"far": {"p": [600, 275], "depth": 1.0, "h": 110, "flip": true}}
	Cutscene._manifest = {"panels": {"crypt_row": panel}, "figures": {"snuffer_reach": W6C_SNUFFER}, "portraits": W6C_PORTRAITS}
	game.reset()
	var cs := _play("beat_1_2", false)
	var n := 0
	while not cs._figs.has("far") and n < 200:
		cs.advance(DT)
		n += 1
	for i in 3:
		cs.advance(DT)
	_check(cs._figs.has("far") and bool(cs._figs["far"]["flip"]), "a flipped anchor's figure knows it")
	if cs._figs.has("far"):
		var f: Dictionary = cs._figs["far"]
		_check((f["node"] as Node2D).scale.x < 0.0, "and is drawn mirrored")
		var feet: Vector2 = cs._fig_point(f, f["feet"])
		var right: Vector2 = cs._fig_point(f, f["feet"] + Vector2(20, -40))
		_check(right.x < feet.x - 1.0, "a point right of its feet lands left of them on screen")
		var L: Dictionary = cs._lights.get("far.eyes", {})
		_check(L.get("kind", "") == "eyes" and L.get("col", "") == "e8e4ff" and (L.get("pts", []) as Array).size() == 2,
				"its eyes light from the art: kind, colour, pupils")
		var eyes := {}
		for fe in cs._flames:
			if fe.get("eyes", false):
				eyes = fe
		_check(not eyes.is_empty() and (eyes["pts"] as Array).size() == 2, "the eyes are drawn as its two pupils")
		if not eyes.is_empty():
			var p0: Vector2 = eyes["pts"][0]
			var p1: Vector2 = eyes["pts"][1]
			_check(p0.x > p1.x, "mirrored too: the pupil on the left of the art is on the right")
			_check(p0.distance_to(p1) < 20.0, "and they sit close, where his eyes are (%.1f px apart)" % p0.distance_to(p1))
	_drive(cs)
	_check(cs.finished, "the beat plays through with the art's shapes")
	await process_frame
	# A figure whose texture is missing is its stand-in, lights and all.
	var gone := W6C_SNUFFER.duplicate(true)
	gone["tex"] = "res://art/story/figures/not_there.svg"
	Cutscene._manifest = {"figures": {"snuffer_reach": gone}}
	var probe: Node = Cutscene.new()
	var fd: Dictionary = probe._figure_def("snuffer_reach")
	_check(fd["tex"] == "" and fd["look"] == Stage.FIGURES["snuffer_reach"]["look"] and fd["flames"] == Stage.FIGURES["snuffer_reach"]["flames"],
			"a figure with its texture missing is drawn and lit as its stand-in")
	probe.free()
	Cutscene._manifest = kept


func _keeper_stub() -> GDScript:
	var ks := GDScript.new()
	ks.source_code = "extends Control\nsignal hovered(id: String)\nsignal picked(id: String)\nsignal back\n" + \
		"var standalone := true\nvar show_back := true\nvar show_backdrop := true\nvar embedded := false\n" + \
		"var in_story := false\nvar title := \"Choose your Calling\"\n"
	ks.reload()
	return ks


func _test_keeper_host() -> void:
	## The oath chooses on its own carved plinths: the Keeper screen's alcoves
	## would cover them (in another order). Asked to (host_keeper), it hosts
	## the Keeper screen as a part of the scene, not a screen of its own.
	game.reset()
	var plain := _play("oath", false)
	plain.keeper_script = _keeper_stub()
	var n := 0
	while plain.waiting != "class" and n < 400:
		plain.advance(DT)
		n += 1
	_check(plain.waiting == "class" and plain._keeper == null and not plain._chooser.is_empty(),
			"by default the oath's chooser is its own, on the plinths (the Keeper screen stays for the map)")
	plain.queue_free()
	var cs := _play("oath", false)
	cs.keeper_script = _keeper_stub()
	cs.host_keeper = true
	n = 0
	while cs.waiting != "class" and n < 400:
		cs.advance(DT)
		n += 1
	var k = cs._keeper
	_check(k != null and k.get_parent() == cs._ui, "the oath hosts the Keeper screen")
	if k == null:
		cs.queue_free()
		return
	_check(not k.standalone and not k.show_back and not k.show_backdrop, "hosted: no Back, no backdrop, not on its own")
	_check(k.embedded and k.in_story, "and told it's in the story")
	_check(k.title == "Pick the calling that fits your hands. Not your pride.", "Mother Taper's words are its title: %s" % k.title)
	_check(cs._chooser.is_empty(), "the built-in chooser stays away")
	var own := _play("oath", false)
	own.keeper_script = _keeper_stub()
	n = 0
	while own.waiting != "class" and n < 400:
		own.advance(DT)
		n += 1
	_check(own._keeper == null and not own._chooser.is_empty(), "host_keeper left false keeps the built-in chooser")
	own.queue_free()
	k.hovered.emit("witch")
	for i in 20:
		cs.advance(DT)
	_check(float(cs._lights["plinth_witch"]["k"]) > 0.5 and float(cs._lights["plinth_knight"]["k"]) < 0.5, "hovering a calling lights its plinth")
	k.picked.emit("witch")
	_check(game.has_hero("witch") and game.hero_id() == "witch" and cs.cls == "witch", "picking there makes the hero (the scene does)")
	_check(cs.waiting != "class" and cs._keeper == null, "and the oath goes on without it")
	_drive(cs)
	_check(cs.finished and game.seen("oath"), "the oath ends")
	await process_frame


func _test_chooser_cards() -> void:
	## The built-in chooser: a card under each plinth, never overlapping; the
	## looked-at calling's face and words in a box between the prompt and
	## the cards; and the plinths' own order.
	game.reset()
	var cs := _play("oath", false)
	var n := 0
	while cs.waiting != "class" and n < 400:
		cs.advance(DT)
		n += 1
	for c in Classes.ids():
		if not bool(Classes.ALL[c]["enabled"]):
			var before := int(cs._chooser["sel"])
			cs._hover(c)
			_check(int(cs._chooser["sel"]) == before, "a sealed calling (%s) can't be picked out in the chooser" % c)
	var t := 0
	for step in [0, 90, 200]:
		for i in step:
			cs.advance(DT)
		t += step
		var cards: Array = cs._chooser_cards()
		var ok := cards.size() == 5
		for i in range(1, cards.size()):
			ok = ok and (cards[i][1] as Rect2).position.x >= (cards[i - 1][1] as Rect2).end.x + 7.9
		var safe: Rect2 = cs._safe()
		ok = ok and (cards[0][1] as Rect2).position.x >= safe.position.x and (cards[4][1] as Rect2).end.x <= safe.end.x
		_check(ok, "the chooser's five cards never overlap and stay in the safe area (%.1f s in)" % (t * DT))
		# Each sits under its own plinth, near enough.
		var near := true
		for i in cards.size():
			var px: float = cs._to_screen(Vector2(cs.PLINTH_X[i], 300.0), 1.0).x
			near = near and absf((cards[i][1] as Rect2).get_center().x - px) < (cards[i][1] as Rect2).size.x * 0.5
		_check(near, "and each is under its own plinth (%.1f s in)" % (t * DT))
	# The plinths as carved (the lights panels.json names them by) and the
	# cards agree, every calling enabled and on its plinth.
	_check(cs.PLINTHS.size() == Classes.ids().size(), "a plinth for each of the %d callings" % Classes.ids().size())
	for c in Classes.ids():
		_check(cs.PLINTHS.has(c) and bool(Classes.ALL[c]["enabled"]), "%s has a plinth and can be chosen" % c)
		_check(cs._lights.has("plinth_" + c), "the callings panel has %s's plinth candle" % c)
	var cards: Array = cs._chooser_cards()
	var safe: Rect2 = cs._safe()
	_check_oath_ease(cs, "")
	for c in Classes.ids():
		cs._hover(c)
		for i in 20:
			cs.advance(DT)
		var ib: Rect2 = cs.chooser_info_rect(c)
		# Under the prompt and its note (whose descenders reach 5 below it).
		var clear: bool = ib.position.x >= safe.position.x - 0.5 and ib.end.x <= safe.end.x + 0.5 and ib.position.y >= cs.chooser_note_y() + 5.0
		for cr in cards:
			clear = clear and not ib.intersects((cr[1] as Rect2).grow_individual(0, 8, 0, 0))
		_check(clear, "%s's box fits the safe area, under the prompt's note and over the cards (%s)" % [c, ib])
		var lines: Array = cs._info_lines(Classes.ALL[c])
		var lay: Dictionary = cs.chooser_info_layout(c)
		var room: float = float(lay["text_end"]) - float(lay["text_x"])
		var size: int = cs._info_size(Classes.ALL[c])
		_check(float(cs._info_w(lines[0], size)) <= room + 0.5 and float(cs._info_w(lines[1], size)) <= room + 0.5,
				"%s's Special and quirk each fit on a line, clear of its ease" % c)
		_check(cs._tex.get(Story.portrait_path("wick", "happy", c)) != null, "%s's face was loaded before it's drawn" % c)
		_check(float(cs._lights["plinth_" + c]["to"]) > 0.5, "looking at %s lights its own plinth" % c)
	# Tap a card to look, tap it again to choose.
	cs._hover("knight")
	var sx: Rect2 = cards[cs.PLINTHS.find("sexton")][1]
	cs._chooser_tap(sx.get_center())
	_check(cs.waiting == "class" and int(cs._chooser["sel"]) == cs.PLINTHS.find("sexton"), "one tap on a card looks at that calling")
	cs._chooser_tap(sx.get_center())
	_check(cs.waiting != "class" and game.hero_id() == "sexton" and cs.cls == "sexton", "a second tap chooses it")
	cs.queue_free()
	await process_frame
	# The phone's notch: the cards and the box stay inside its safe area.
	var UIs: GDScript = load("res://scripts/ui.gd")
	UIs.safe_override = Rect2(62, 10, 720, 362)
	game.reset()
	var nc := _play("oath", false)
	n = 0
	while nc.waiting != "class" and n < 400:
		nc.advance(DT)
		n += 1
	var ok := true
	for c in Classes.ids():
		nc._hover(c)
		var ib: Rect2 = nc.chooser_info_rect(c)
		ok = ok and ib.position.x >= 62.0 and ib.end.x <= 782.0
	for cr in nc._chooser_cards():
		ok = ok and (cr[1] as Rect2).position.x >= 62.0 and (cr[1] as Rect2).end.x <= 782.0
	_check(ok, "with the notch's safe area, the chooser stays inside it")
	_check_oath_ease(nc, " (notch)")
	UIs.safe_override = Rect2()
	nc.queue_free()
	await process_frame


func _check_oath_ease(cs: Node, tag: String) -> void:
	## The oath's first decision reads right: every card's pips are labelled
	## EASE (beside them, clear of the card's edges and of a picked card's
	## Choose button), the looked-at calling's box says what they mean, and
	## a note under the prompt says the other callings can be raised later.
	var Keeper: GDScript = load("res://scripts/keeper_screen.gd")
	var UIs: GDScript = load("res://scripts/ui.gd")
	var safe: Rect2 = cs._safe()
	var ok := true
	for cr in cs._chooser_cards():
		for picked in [false, true]:
			var r: Rect2 = cr[1]
			if picked:
				r.position.y -= 8.0          # as _draw_chooser lifts it
			var row: Dictionary = cs.chooser_ease_row(r, picked)
			var pips: Array = row["pips"]
			var lx: float = (row["label"] as Vector2).x
			var fits: bool = pips.size() == 5 and lx >= r.position.x + 6.0 \
					and lx + float(row["label_w"]) + 3.0 <= (pips[0] as Vector2).x - cs.PIP_R \
					and (pips[4] as Vector2).x + cs.PIP_R <= r.end.x - 6.0
			# Under the role (its baseline 45 down), over the card's foot.
			var top: float = (pips[0] as Vector2).y - cs.PIP_R
			var foot: float = cs.chooser_choose_rect(r).position.y if picked else r.end.y - 6.0
			fits = fits and top >= r.position.y + 48.0 and (pips[0] as Vector2).y + cs.PIP_R <= foot - 2.0 \
					and (row["label"] as Vector2).y <= foot - 2.0
			if not fits:
				print("  %s%s: EASE at %s, pips %s, card %s" % [cr[0], " picked" if picked else "", row["label"], pips, r])
			ok = ok and fits
	_check(ok, "every chooser card labels its pips EASE, beside them and clear of its edges and Choose button" + tag)
	# What they mean, in the looked-at calling's box, beside its words.
	var words := true
	for c in Classes.ids():
		var lay: Dictionary = cs.chooser_info_layout(c)
		var box: Rect2 = lay["box"]
		var word: String = Keeper.ease_word(int(Classes.ALL[c]["ease"]))
		words = words and word != "" and float(lay["ease_x"]) > float(lay["text_end"]) \
				and float(lay["ease_x"]) + UIs.text_width(word, 13) <= box.end.x - 8.0 \
				and float(lay["ease_x"]) + cs._ease_col_w() <= box.end.x - 8.0
	_check(words, "each calling's box says what its ease means, in its own column" + tag)
	_check(Keeper.ease_word(5) == "the gentlest start" and Keeper.ease_word(1) == "for the bold"
			and Keeper.ease_word(int(Classes.ALL["knight"]["ease"])) == "the gentlest start",
			"more lit pips is gentler: the Candleknight's five are the gentlest start" + tag)
	# The note: under the prompt, over the box, inside the safe area.
	var nw: float = UIs.text_width(cs.CHOOSER_NOTE, 11, "body", 700)
	_check(cs.CHOOSER_NOTE.contains("later") and nw <= safe.size.x - 8.0
			and cs.chooser_note_y() - 11.0 >= cs.chooser_prompt_y() + 3.0
			and cs.chooser_note_y() + 5.0 <= cs.chooser_info_rect("knight").position.y,
			"under the prompt, a note that the other callings can be raised later" + tag)


func _test_text_bands() -> void:
	## Cards and the Hush's words keep off faces.
	game.reset()
	var cs := _play("oath", false)
	var n := 0
	while cs._card.is_empty() and n < 3000:
		if cs.waiting == "class":
			cs.pick("knight")
		elif n % 10 == 9:
			cs.tap()
		cs.advance(DT)
		n += 1
	_check(not cs._card.is_empty(), "the oath reaches its world card")
	var vs: Vector2 = cs._vs()
	_check(vs == Vector2(844, 390), "(the tests see the phone's 844 x 390)")
	_check(not cs.band_clear(cs._actor.position.y - 20.0, 52.0, 28.0), "the hero's own place isn't clear for a card")
	var y: float = cs.text_band(str(cs._card.get("at", "")), vs.y * 0.44, 52.0, 28.0)
	_check(cs.band_clear(y, 52.0, 28.0), "the oath's card sits clear of Taper, the hero and his flame (y %.0f)" % y)
	var ya: float = cs.text_band("", vs.y * 0.44, 52.0, 28.0)
	_check(cs.band_clear(ya, 52.0, 28.0), "and a card left to choose finds a clear place too (y %.0f)" % ya)
	_check(is_equal_approx(cs.text_band("mid", 100.0, 10.0, 10.0), 100.0), "at: mid is the middle")
	_check(cs.text_band("top", 100.0, 20.0, 10.0) < 100.0 and cs.text_band("low", 100.0, 20.0, 10.0) > vs.y * 0.6, "at: top and low")
	cs.skip()
	_drive(cs)
	await process_frame
	# An empty stage: the middle.
	var ln := _play("intro", false)
	for i in 30:
		ln.advance(DT)
	_check(is_equal_approx(ln.text_band("", vs.y * 0.44, 52.0, 28.0), vs.y * 0.44), "with no one on stage, the middle")
	ln.queue_free()
	# The Hush over the Undercandle ("...not yet."): between its flame up top
	# and their faces below; and under its eye after the credits.
	game.reset()
	var h := _play("the_pull", false)
	n = 0
	while n < 3000 and not (h.waiting == "line" and h._line.get("style", "") == "hush"):
		if h.waiting == "line" and n % 10 == 9:
			h.tap()
		h.advance(DT)
		n += 1
	_check(h._line.get("style", "") == "hush" and str(h._line["text"]) == "...not yet.", "the_pull reaches the Hush's first words")
	var hy: float = h.text_band(str(h._line.get("at", "")), vs.y * 0.5, 28.0, 10.0)
	_check(hy > vs.y * 0.3 and hy < vs.y * 0.7 and h.band_clear(hy, 28.0, 10.0),
			"the Hush's words keep off their faces and the flame, over the candle (y %.0f)" % hy)
	h.queue_free()
	await _test_text_off_heroes(vs)
	var lows := 0
	for b in Story.scene("lullaby")["shots"][0]["beats"]:
		if Story.is_line(b) and Story.resolve(b, "knight")["at"] == "low":
			lows += 1
	_check(lows == 1, "after the credits the Hush speaks under its eye")
	await process_frame


# ---------------------------------------------------------------- main's way through

func _test_main_flow() -> void:
	game.reset()
	var Main: GDScript = load("res://scripts/main.gd")
	var TitleS: GDScript = load("res://scripts/title_screen.gd")
	var MapS: GDScript = load("res://scripts/map_screen.gd")
	var ResultsS: GDScript = load("res://scripts/results_screen.gd")
	var main: Node = Main.new()
	root.add_child(main)
	await process_frame
	_check(main.current != null and main.current.get_script() == TitleS, "main opens on the title")
	main._after_title()
	var cs: Node = main.current
	_check(cs.get_script() == Cutscene and cs.scene_id == "intro", "a first title tap plays the intro")
	_drive(cs)
	cs = main.current
	_check(cs.get_script() == Cutscene and cs.scene_id == "oath", "then the oath")
	var picked := false
	for i in 2000:
		if cs.finished:
			break
		if cs.waiting == "class" and not picked:
			picked = cs.pick("runner")
		elif i % 10 == 9:
			cs.tap()
		cs.advance(DT)
	_check(picked and game.has_hero("runner") and game.hero_id() == "runner", "the oath's choice makes the hero")
	_check(main.current.get_script() == MapS, "then the map")
	_check(game.seen("intro") and game.seen("oath"), "both are seen")
	await process_frame
	main._after_title()
	_check(main.current.get_script() == MapS, "later title taps go straight to the map")
	await process_frame
	# A player who saw the intro but never chose: the oath alone.
	var kept_heroes: Dictionary = game.data["heroes"].duplicate(true)
	game.data["heroes"] = {}
	game.data["hero"] = ""
	main._after_title()
	_check(main.current.get_script() == Cutscene and main.current.scene_id == "oath", "no hero yet: the oath again")
	main.current.skip()
	main.current.pick("knight")
	_drive(main.current)
	await process_frame
	game.data["heroes"] = kept_heroes
	game.data["hero"] = "runner"
	# The first clear of 1-4: the belfry scene, then the results; then on.
	var i14: int = game.index_of("1-4")
	if i14 >= 0:
		main.last_level = i14
		var res := {"level": "1-4", "cleared": true, "embers": 10, "embers_total": 20, "sigils": [false, false, false],
			"time": 90.0, "relics": [], "items": [], "xp": 0, "levels": 0, "level_start": 1, "level_now": 1, "snuffs": 0,
			"diff": "dusk", "dread": false, "story_end": "boss_1_after"}
		main._on_finished(res)
		cs = main.current
		_check(cs.get_script() == Cutscene and cs.scene_id == "boss_1_after", "a first clear of 1-4 plays boss_1_after")
		_drive(cs)
		var results: Node = main.current
		_check(results.get_script() == ResultsS, "then the results")
		await process_frame
		results.next.emit()
		var after: Node = main.current
		if game.LEVELS.size() > i14 + 1 and int(game.LEVELS[i14 + 1]["world"]) == 2:
			_check(after.get_script() == Cutscene and after.scene_id == "world_2", "Onward into World 2 plays world_2 first")
			_drive(after)
			_check(main.current.get_script() == load("res://scripts/world.gd"), "then 2-1 starts")
		else:
			_check(after.get_script() == MapS, "Onward past the last level built goes to the map")
		await process_frame
		main._on_finished(res)
		_check(main.current.get_script() == ResultsS, "a second clear goes straight to the results")
		await process_frame
	# After the Snuffer: the_pull, owed until it plays (v2's ending is gone),
	# once World 3 is built to go down into (a stand-in 3-1 until WL3's).
	if game.index_of("2-4") >= 0:
		game.level_record("2-4", "dusk")["cleared"] = true
		if game.levels_in_world(3).is_empty():
			main.show_map()
			_check(main.current.get_script() == MapS and not game.seen("the_pull") and Story.taper_phase() == "well",
					"with no World 3 built, the map owes nothing after 2-4 (the_pull waits; Taper stays well)")
			await process_frame
		var kept31 := _stand_in_31()
		main.show_map()
		cs = main.current
		_check(cs.get_script() == Cutscene and cs.scene_id == "the_pull", "the map owes the_pull once the Snuffer falls (World 3 built)")
		_drive(cs, 4000)
		_check(game.seen("the_pull") and not game.seen("ending") and not game.seen("post_credits"), "the_pull plays (no ending, no post_credits)")
		_check(main.current.get_script() == MapS, "then the map, with nothing owed")
		_put_levels(kept31)
		await process_frame
	# A new calling from the Callings screen: Taper has a word for it, even
	# when the screen made the hero before saying which.
	game.reset()
	game.new_hero("knight")
	game.new_hero("witch")
	main._on_calling_picked("witch", ["knight"])
	_check(main.current.get_script() == MapS and Cutscene.running_on(main.current, "new_calling") != null,
			"a calling new since the screen opened gets Mother Taper's word")
	main._on_calling_picked("knight", ["knight", "witch"])
	_check(Cutscene.running_on(main.current, "new_calling") == null, "an old one doesn't")
	await process_frame
	# Into World 2 from the map (not Onward): its opening scene first.
	game.reset()
	game.new_hero("knight")
	var kept2: Array = game.LEVELS.duplicate()
	if game.levels_in_world(2).is_empty():
		game.LEVELS.append({"id": "2-1", "path": "res://levels/1-1.txt", "world": 2})
	var i21 := -1
	for i in game.LEVELS.size():
		if int(game.LEVELS[i]["world"]) == 2:
			i21 = i
			break
	main.play_level(i21)
	cs = main.current
	_check(cs.get_script() == Cutscene and cs.scene_id == "world_2", "a world's first level from the map plays its opening scene first")
	_drive(cs)
	_check(main.current.get_script() == load("res://scripts/world.gd") and main.last_level == i21, "then the level")
	main.play_level(i21)
	_check(main.current.get_script() == load("res://scripts/world.gd"), "the second time, straight in")
	game.LEVELS.clear()
	game.LEVELS.append_array(kept2)
	await process_frame
	# The first hurt: Mother Taper says the flame is your life.
	game.reset()
	game.new_hero("knight")
	main.play_level(0)
	var lv: Node = main.current
	var hs := GDScript.new()
	hs.source_code = "extends CanvasLayer\nvar barks: Array = []\nfunc bark(k: String) -> void:\n\tbarks.append(k)\n" + \
		"func bump_flames() -> void:\n\tpass\n"
	hs.reload()
	var real_hud = lv.hud
	var fake_hud: CanvasLayer = hs.new()
	lv.hud = fake_hud
	lv.player.hurt_taken.emit(10.0, 90.0)
	lv.player.hurt_taken.emit(10.0, 80.0)
	_check(fake_hud.barks.count("first_hurt") == 1, "the first hurt fires the first_hurt bark, once: %s" % [fake_hud.barks])
	lv.hud = real_hud
	fake_hud.free()
	game.mark_seen("bark:first_hurt")
	main.play_level(0)
	var hooked := 0
	for c in main.current.player.hurt_taken.get_connections():
		if c["flags"] & CONNECT_ONE_SHOT:
			hooked += 1
	_check(hooked == 0, "once heard, it isn't listened for again")
	await process_frame
	# The bot never sees the story.
	game.reset()
	main._autoplay = "1-2"
	main.play_level(maxi(game.index_of("1-2"), 0))
	var lvl: Node = main.current
	_check(_cutscene_in(lvl) == null and not lvl.paused, "the autoplay bot skips the level's beat")
	main._after_title()
	_check(main.current.get_script() == MapS, "and the intro")
	main._autoplay = ""
	await process_frame
	main.queue_free()
	await process_frame


# ---------------------------------------------------------------- the whole way through, end to end

var _Main: GDScript
var _MapS: GDScript
var _ResultsS: GDScript
var _WorldS: GDScript


func _flow_scripts() -> void:
	_Main = load("res://scripts/main.gd")
	_MapS = load("res://scripts/map_screen.gd")
	_ResultsS = load("res://scripts/results_screen.gd")
	_WorldS = load("res://scripts/world.gd")


func _test_perf_meter() -> void:
	## main's --autoplay frame meter reads the wall clock: a frame longer than
	## the delta Godot clamps (6 ticks of 1/120 s) reads as long as it was,
	## the frame rate is frames over real time, each slow frame gets a line
	## of its own, and the frame that held the meter's own screenshot is
	## left out of the figures.
	_flow_scripts()
	var m: Node = _Main.new()
	m._autoplay = "2-4"
	m.perf_start()
	m.perf_frame(0.2528, 0.05)
	var slow: Array = m.perf_lines.filter(func(l): return str(l).contains("hitch"))
	_check(slow.size() == 1 and str(slow[0]).contains("hitch 252.8 ms") and str(slow[0]).contains("dt 50.0 ms"),
			"a 252.8 ms build frame reads 252.8 ms, not the clamped 50: %s" % [slow])
	var k := 0
	while m.perf_lines.size() < 2 and k < 1000:
		m.perf_frame(1.0 / 120.0, 1.0 / 120.0)
		k += 1
	var win: String = str(m.perf_lines.back())
	var fps := (k + 1) / (0.2528 + k / 120.0)
	_check(win.contains("worst frame 252.8 ms") and win.contains("fps %.1f" % fps), "the window's worst is the build and its fps real time's (%.1f): %s" % [fps, win])
	_check(k == 210, "the window is 2 s of wall clock (%d frames after the build)" % k)
	# Many ordinary frames: none of them is a hitch line.
	var before: int = m.perf_lines.size()
	for i in 239:
		m.perf_frame(1.0 / 120.0, 1.0 / 120.0)
	_check(m.perf_lines.size() == before, "frames under 20 ms get no line of their own")
	# The screenshot's frame (about 100 ms of reading the screen back).
	m._perf_skip = true
	m.perf_frame(0.105, 0.05)
	_check(str(m.perf_lines.back()).contains("screenshot frame 105.0 ms") and str(m.perf_lines.back()).contains("not counted"),
			"the screenshot's frame is named and left out: %s" % [m.perf_lines.back()])
	before = m.perf_lines.size()
	k = 0
	while m.perf_lines.size() == before and k < 1000:
		m.perf_frame(1.0 / 120.0, 1.0 / 120.0)
		k += 1
	win = str(m.perf_lines.back())
	_check(win.contains("worst frame 8.3 ms") and win.contains("fps 120.0"), "and the window it fell in reads as if it weren't there: %s" % win)
	_check(not m._perf_skip, "only that one frame")
	m.free()
	# The real screenshot marks its frame, even with nothing to read back.
	var main := await _new_main()
	var shot := "user://test_perf_shot.png"
	await main._shoot_later(shot, 0.0)
	_check(main._perf_skip, "the autoplay screenshot leaves its frame out")
	if FileAccess.file_exists(shot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(shot))
	main.queue_free()
	await process_frame


func _wait_loaded(paths: Array) -> bool:
	## Until every threaded load here is done (headless, nothing else may
	## make a texture meanwhile: the stand-in renderer can't make two at once).
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		var busy := false
		for p in paths:
			if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				busy = true
		if not busy:
			return true
		OS.delay_msec(2)
	return false


func _test_loading_ahead() -> void:
	## A story scene's first picture is asked for on a thread before it plays
	## (the scene then takes it up instead of loading it as it opens), and
	## main asks at the right moments: the intro at the title, a level's
	## opening and boss beats as it builds, its closing scene during the
	## clear, the ending and the next world's opening while the results are
	## up. A level's monsters and props (and the monsters' scripts) are
	## loaded ahead at the title and kept.
	game.reset()
	var pd: Dictionary = Cutscene.manifest().get("panels", {})
	var fd: Dictionary = Cutscene.manifest().get("figures", {})
	var want: Array = []
	for l in pd.get("undercandle", {}).get("layers", []):
		want.append(str(l["tex"]))
	want.append(str(fd.get("snuffer_reach", {}).get("tex", "")))
	_check(Cutscene.first_textures("boss_2_before") == want, "boss_2_before's first picture: the undercandle's layers and the Snuffer (%s)" % [Cutscene.first_textures("boss_2_before")])
	_check(Cutscene.first_textures("beat_1_3").is_empty() and Cutscene.first_textures("no_such").is_empty(), "a scene of lines only needs none")
	_check(not Cutscene.first_textures("intro").is_empty() and not Cutscene.first_textures("the_pull").is_empty(), "the intro's and the_pull's are there")
	# Asked for, loaded on a thread, and taken up by the scene.
	Cutscene.prefetch(["boss_2_before"])
	var ahead: Array = Cutscene.ahead()
	ahead.sort()
	var sorted_want := want.duplicate()
	sorted_want.sort()
	_check(ahead == sorted_want, "prefetch asks for them: %s" % [ahead])
	_check(_wait_loaded(ahead), "and they load")
	var fw := _fake_world()
	var cs: Node = Cutscene.play_overlay(fw, "boss_2_before", func(): pass)
	cs.manual = true
	for i in 60:
		cs.advance(DT)
	var took := true
	for p in want:
		took = took and cs._tex.get(p) != null
	_check(took and cs._panel_id == "undercandle", "the scene takes them up as it opens its panel")
	_check(Cutscene.ahead().is_empty(), "nothing is left asked for")
	cs.skip()
	for i in 200:
		if cs.finished:
			break
		cs.advance(DT)
	fw.queue_free()
	await process_frame
	# Asked for, then not wanted any more: let go.
	Cutscene.prefetch(["the_pull"])
	_check(not Cutscene.ahead().is_empty(), "the_pull's picture is asked for")
	_wait_loaded(Cutscene.ahead())
	Cutscene.prefetch(["lullaby"])
	var pc: Array = Cutscene.first_textures("lullaby")
	var left: Array = Cutscene.ahead().filter(func(p): return not pc.has(p))
	_check(left.is_empty(), "asking for another lets the first go: %s" % [left])
	_wait_loaded(Cutscene.ahead())
	Cutscene.prefetch([])
	_check(Cutscene.ahead().is_empty(), "and asking for none lets everything go")
	# A shot's own next-shot request never asks again for what's ahead.
	Cutscene.prefetch(["boss_2_after"])
	var ahead2: Array = Cutscene.ahead()
	_wait_loaded(ahead2)
	var cs2: Node = Cutscene.make("boss_2_after", func(): pass)
	cs2.manual = true
	root.add_child(cs2)
	var twice := false
	for p in ahead2:
		twice = twice or cs2._requested.has(p)
	_check(not twice and Cutscene.ahead().is_empty(), "the scene takes up what was ahead and asks for none of it again")
	cs2.queue_free()
	await process_frame
	# main: what it asks for, and when. (Headless it only says: nothing is
	# loaded ahead there.)
	var main := await _new_main()
	_check(main.story_ahead == ["intro"], "the title asks for the intro's picture: %s" % [main.story_ahead])
	game.mark_seen("intro")
	main.show_title()
	_check(main.story_ahead.is_empty(), "not once it's seen")
	main.show_map()
	_check(main.story_ahead.is_empty(), "the map asks for none (and lets go what a level left)")
	game.new_hero("knight")
	for id in ["oath", "world_1", "world_2"]:
		game.mark_seen(id)
	var i24: int = game.index_of("2-4")
	if i24 >= 0:
		_clear_up_to("2-4")
		(game.data["seen"] as Array).erase("boss_2_before")
		main.play_level(i24)
		_check(main.story_ahead == ["beat_2_4"], "2-4 asks for its opening beat as it builds (the boss's waits for the last altar): %s" % [main.story_ahead])
		var w: Node = main.current
		var beat := _cutscene_in(w)
		if beat != null:
			beat.manual = true
			_drive(beat)
		main._process(DT)
		_check(main.story_ahead == ["beat_2_4"], "(nothing more while it plays)")
		# At the last altar before the boss (the int2 review: a player's 3-4
		# held boss_3_before's 46 MB from the level's start).
		var last_altar := -INF
		for a in w.altars:
			if (a["pos"] as Vector2).x < w.boss.position.x:
				last_altar = maxf(last_altar, (a["pos"] as Vector2).x)
		w.player.reset_at(Vector2(last_altar - 64.0, (w.altars[0]["pos"] as Vector2).y))
		w.tick(DT)
		_check(main.story_ahead == ["beat_2_4"], "short of the last altar, still nothing: %s" % [main.story_ahead])
		for a in w.altars:
			if (a["pos"] as Vector2).x == last_altar:
				w.player.reset_at(a["pos"])
		w.tick(DT)
		_check(main.story_ahead == ["boss_2_before"], "at the last altar before the Snuffer, his scene is asked for: %s" % [main.story_ahead])
		w.state = "clear"
		main._process(DT)
		_check(main.story_ahead == ["boss_2_after"], "the closing scene is asked for during the clear: %s" % [main.story_ahead])
		w.state = "play"
		game.mark_seen("boss_2_before")
		main.play_level(i24)
		_check(main.story_ahead.is_empty(), "a retry with both beats seen asks for none: %s" % [main.story_ahead])
		# The results after the Snuffer's first clear: the ending is owed.
		main.last_level = i24
		game.record_result(_result("2-4", "boss_2_after"))
		if game.levels_in_world(3).is_empty():
			main._show_results(_result("2-4", "boss_2_after"), {"first_clear": true})
			_check(not main.story_ahead.has("the_pull"), "with no World 3 built, the results ask for no the_pull: %s" % [main.story_ahead])
			await process_frame
		var kept31 := _stand_in_31()
		main._show_results(_result("2-4", "boss_2_after"), {"first_clear": true})
		_check(not main.story_ahead.is_empty() and main.story_ahead[0] == "the_pull", "the results ask for the_pull once it's owed: %s" % [main.story_ahead])
		_put_levels(kept31)
		await process_frame
	var i14: int = game.index_of("1-4")
	if i14 >= 0:
		game.reset()
		game.new_hero("knight")
		main.last_level = i14
		main._show_results(_result("1-4", "boss_1_after"), {"first_clear": true})
		_check(main.story_ahead == ["world_2"], "1-4's results ask for World 2's opening: %s" % [main.story_ahead])
		# Map instead of Onward: the map opens on 2-1 and plays World 2's
		# opening from there, so its picture stays asked for.
		main.show_map(game.index_of("2-1"))
		_check(main.story_ahead == ["world_2"], "then the Map (not Onward) keeps World 2's opening asked for: %s" % [main.story_ahead])
		main.show_map(game.index_of("1-1"))
		_check(main.story_ahead.is_empty(), "a map opening on World 1 lets it go: %s" % [main.story_ahead])
		game.mark_seen("world_2")
		await process_frame
	# The levels' art: v2's monsters' frames, every prop and v2's scripts at
	# the title; each v3 world's monsters and each new boss in a set of their
	# own (main.WORLD_ART), warmed only where they're played (the review's
	# texmem finding: all of it at the title took W1-W2 past 160 MB).
	var art: Array = main.level_art()
	var sets := {}
	for key in main.WORLD_ART:
		sets[key] = main.world_art(key)
	var set_of := {}
	for key in sets:
		for p in sets[key]:
			set_of[p] = key
	var missing := []
	var misplaced := []
	var EK: GDScript = load("res://scripts/enemy_kinds.gd")
	var rx := RegEx.create_from_string("load_frames\\(\\[([^\\]]*)\\]")
	for f in DirAccess.get_files_at("res://scripts"):
		if not f.ends_with(".gd"):
			continue
		var kind := ""
		for k in EK.KINDS:
			if str(EK.KINDS[k]["script"]) == "res://scripts/" + f:
				kind = str(k)
		for m in rx.search_all(FileAccess.get_file_as_string("res://scripts/" + f)):
			for nm in m.get_string(1).split(","):
				var p := "res://art/enemies/%s.svg" % nm.strip_edges().trim_prefix("\"").trim_suffix("\"")
				if not art.has(p) and not set_of.has(p):
					missing.append(p)
				elif kind != "" and main.KIND_ART.has(kind) and str(set_of.get(p, "")) != str(main.KIND_ART[kind]):
					misplaced.append(p)
	for k in EK.KINDS:
		var sp := str(EK.KINDS[k]["script"])
		var key := str(main.KIND_ART.get(k, ""))
		if key == "" and not art.has(sp):
			missing.append(sp)
		if key != "" and not (sets[key] as Array).has(sp):
			misplaced.append(sp)
		# v3's kinds name their frames in a FRAMES const (load_frames(FRAMES)):
		# each one's art must be there, in its world's set (a v2 kind's at the title).
		var ks = load(sp)
		var fr = (ks as Script).get_script_constant_map().get("FRAMES") if ks is Script else null
		if fr is Array:
			for nm in fr:
				var fp := "res://art/enemies/%s.svg" % str(nm)
				if key == "" and not art.has(fp):
					missing.append(fp)
				elif key != "" and not (sets[key] as Array).has(fp):
					misplaced.append(fp)
	# Each new boss's frames and props (A4's points files) are its own set.
	for b in ["rootmother", "tinker", "saint", "hush"]:
		var pj = JSON.parse_string(FileAccess.get_file_as_string("res://art/enemies/points_%s.json" % b))
		if not (pj is Dictionary):
			continue
		var names: Array = (pj as Dictionary).keys().filter(func(k): return not str(k).begins_with("_"))
		for part in ["_props", "_parts"]:
			if pj.get(part) is Dictionary:
				names.append_array((pj[part] as Dictionary).keys())
		for nm in names:
			var fp := "res://art/enemies/%s.svg" % str(nm)
			if ResourceLoader.exists(fp) and not (sets[b] as Array).has(fp):
				misplaced.append(fp)
	# Every frame is in exactly one place: the title's, or one set.
	var not_once := []
	for f in DirAccess.get_files_at("res://art/enemies"):
		if not f.ends_with(".svg"):
			continue
		var fp := "res://art/enemies/" + f
		var n := (1 if art.has(fp) else 0)
		for key in sets:
			n += 1 if (sets[key] as Array).has(fp) else 0
		if n != 1:
			not_once.append("%s x%d" % [f, n])
	for p in ["res://art/props/altar.svg", "res://art/props/reliquary_gold.svg", "res://art/props/bell_beam.svg"]:
		if not art.has(p):
			missing.append(p)
	# Every prop in one place too: the title's (v2's), a v3 world's set (A1's
	# W3/W4 props, main.WORLD_PROPS), or main.PROPS_UNDRAWN (drawn by no one).
	var props_not_once := []
	for f in DirAccess.get_files_at("res://art/props"):
		if not f.ends_with(".svg"):
			continue
		var fp := "res://art/props/" + f
		var n := (1 if art.has(fp) else 0) + (1 if main.PROPS_UNDRAWN.has(f.get_basename()) else 0)
		for key in sets:
			n += 1 if (sets[key] as Array).has(fp) else 0
		if n != 1:
			props_not_once.append("%s x%d" % [f, n])
	_check(props_not_once.is_empty(), "every prop is in one place, the title's, a world's set or the undrawn list: %s" % [props_not_once])
	_check(not art.has("res://art/props/gear_l.svg") and not art.has("res://art/props/altar_orchard.svg")
			and (sets["w4"] as Array).has("res://art/props/gear_l.svg") and (sets["w3"] as Array).has("res://art/props/altar_orchard.svg"),
			"(W3's and W4's props warm with their world, not at the title)")
	_check(missing.is_empty() and art.size() > 60, "v2's art and every prop are warmed at the title (%d): missing %s" % [art.size(), missing])
	_check(misplaced.is_empty(), "every v3 kind's and new boss's art is in its own set, not the title's: %s" % [misplaced])
	_check(not_once.is_empty(), "every monster frame is in one place, the title's or one set: %s" % [not_once])
	var v3_at_title := art.filter(func(p): return str(p).contains("rootmother_") or str(p).contains("hush_eye") or str(p).contains("spur_") or str(p).contains("tinker_"))
	_check(v3_at_title.is_empty(), "(no W3-W6 frame at the title: %s)" % [v3_at_title])
	# A level asks for the sets of the kinds it places; a W1-W2 level for no
	# v3 set, and a v2 boss level for its boss's own (v2's bosses' frames
	# left the title at the int2 review: 34 MB nothing in W3-W6 draws).
	var lv24 = LevelData.load_file("res://levels/2-4.txt")
	var lv14 = LevelData.load_file("res://levels/1-4.txt")
	var lv11 = LevelData.load_file("res://levels/1-1.txt")
	_check(main.art_sets_of(lv24) == ["snuffer"] and main.sets_for(game.index_of("2-4")) == ["snuffer"]
			and main.art_sets_of(lv14) == ["tollgrave"] and main.sets_for(game.index_of("1-4")) == ["tollgrave"]
			and main.art_sets_of(lv11).is_empty() and main.sets_for(game.index_of("1-1")).is_empty(),
			"2-4 asks for the Snuffer's set, 1-4 for Tollgrave's, 1-1 for none (%s, %s, %s)" % [main.art_sets_of(lv24), main.art_sets_of(lv14), main.art_sets_of(lv11)])
	var v2boss_at_title := art.filter(func(p): return str(p).contains("/snuffer_") or str(p).contains("/boss_"))
	_check(v2boss_at_title.is_empty() and (sets["snuffer"] as Array).has("res://art/enemies/snuffer_idle.svg")
			and (sets["tollgrave"] as Array).has("res://art/enemies/boss_idle.svg"), "(v2's bosses' frames are their own sets, not the title's: %s)" % [v2boss_at_title])
	# A boss level's X is its header's boss: 3-4 builds with Gravebough's
	# frames, 4-4 with the Tinker's (the map's look-ahead asked for them too).
	for row in [["3-4", "w3", "rootmother"], ["4-4", "w4", "tinker"]]:
		if FileAccess.file_exists("res://levels/%s.txt" % row[0]):
			var blv = LevelData.load_file("res://levels/%s.txt" % row[0])
			var bs: Array = main.art_sets_of(blv)
			_check(bs.has(row[1]) and bs.has(row[2]) and main.sets_for(game.index_of(row[0])) == [row[1], row[2]],
					"%s builds with its world's and its boss's art (%s)" % [row[0], bs])
	var fake = LevelData.new()
	fake.parse("title: t\nsubtitle: t\narea: 13\n---\n..........\n..........\n##########")
	fake.world = 4
	fake.entities.append({"kind": "rootling", "cell": Vector2i(2, 1)})
	fake.entities.append({"kind": "tinker", "cell": Vector2i(5, 1)})
	var got: Array = main.art_sets_of(fake)
	_check(got.has("w4") and got.has("kind:rootling") and got.has("props:w3") and got.has("tinker") and got.size() == 4,
			"a W4 level with a Rootling and the Tinker asks for w4, the Rootling's own frames and W3's props, and tinker: %s" % [got])
	# (the rev5 review: another world's kind warms its own frames, not its world's)
	var rl: Array = main.world_art("kind:rootling")
	var w3: Array = main.world_art("w3")
	_check(rl.has("res://art/enemies/rootling_mound.svg") and not rl.has("res://art/enemies/creep_coil.svg") and rl.size() < w3.size()
			and rl.all(func(p): return w3.has(p)), "a kind's subset is its own frames from its world's set (%d of %d)" % [rl.size(), w3.size()])
	_check(main.warm_art().is_empty() and main._warming.is_empty(), "(headless, nothing is loaded ahead)")
	main.queue_free()
	game.reset()
	await process_frame


func _new_main() -> Node:
	_flow_scripts()
	var main: Node = _Main.new()
	root.add_child(main)
	await process_frame
	return main


func _is_scene(n: Node, id: String) -> bool:
	return n != null and n.get_script() == Cutscene and str(n.scene_id) == id


func _play_out(cs: Node, cls := "knight", steps := 4000) -> bool:
	## A scene played the way a player plays it: taps on the lines, and the
	## calling chosen by tapping its card twice (look, then choose).
	for i in steps:
		if cs.finished:
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


func _result(id: String, story_end := "") -> Dictionary:
	return {"level": id, "cleared": true, "embers": 10, "embers_total": 20, "sigils": [false, false, false],
		"time": 90.0, "relics": [], "items": [], "xp": 0, "levels": 0, "level_start": 1, "level_now": 1, "snuffs": 0,
		"diff": "dusk", "dread": false, "story_end": story_end}


func _clear_up_to(id: String) -> void:
	## Every level before `id` cleared on Dusk, as a player would have.
	for info in game.LEVELS:
		if info["id"] == id:
			return
		game.record_result(_result(str(info["id"])))


func _test_flow_fresh() -> void:
	## A new player: the title, the intro, the oath (the calling chosen by
	## tapping its plinth's card), the map open on 1-1, and 1-1 itself.
	game.reset()
	var main: Node = await _new_main()
	_check(main.current is Control and main.current.has_signal("start"), "a fresh save opens on the title")
	main._after_title()
	_check(_is_scene(main.current, "intro"), "the first tap plays the intro")
	_check(_play_out(main.current), "the intro plays through")
	_check(_is_scene(main.current, "oath"), "then the oath")
	var oath: Node = main.current
	var n := 0
	while oath.waiting != "class" and n < 600:
		oath.advance(DT)
		n += 1
	_check(oath.waiting == "class" and not oath._chooser.is_empty() and oath._keeper == null,
			"the oath asks for a calling on its own plinths (%.1f s in)" % (n * DT))
	_check(_play_out(oath, "founder"), "the oath plays through once a calling is tapped")
	_check(game.has_hero("founder") and game.hero_id() == "founder" and game.heroes().size() == 1, "the calling tapped is the hero")
	var h: Dictionary = game.hero()
	_check(int(h["level"]) == 1 and str(h["equip"]["weapon"]["rarity"]) == "common", "a first hero starts at L1 in Common gear")
	_check(main.current.get_script() == _MapS and int(main.current.focus) == 0 and int(main.current.world_tab) == 1,
			"then the map, on 1-1")
	_check(game.seen("intro") and game.seen("oath"), "both scenes are seen")
	await process_frame
	await process_frame
	_check(main.current.get_script() == _MapS, "and nothing else plays over the map")
	main.current.play.emit(0)
	var w: Node = main.current
	_check(w.get_script() == _WorldS and str(w.level_id) == "1-1", "Play goes into 1-1")
	_check(str(w.player.kit.cls) == "founder" if w.player.kit != null else true, "as the calling chosen")
	_check(game.seen("beat_1_1") and not bool(w.paused) and w.get_node_or_null("StoryBarks") != null,
			"1-1's beat is two barks over live play, no pause")
	await process_frame
	# Quit to the map: 1-1 again; a later title tap goes straight to the map.
	w.quit.emit()
	_check(main.current.get_script() == _MapS and int(main.current.focus) == 0, "quitting 1-1 goes back to the map on 1-1")
	main.show_title()
	main._after_title()
	_check(main.current.get_script() == _MapS, "a later title tap goes straight to the map")
	main.queue_free()
	await process_frame


func _test_flow_world_1() -> void:
	## Into 1-4: its beat, Tollgrave's beat on waking (once: a retry is
	## straight to the fight), then the first clear's belfry scene, the
	## results, and World 2's opening scene by either way out.
	if game.index_of("1-4") < 0 or game.index_of("2-1") < 0:
		return
	game.reset()
	game.new_hero("witch")
	_clear_up_to("1-4")
	var main: Node = await _new_main()
	var i14: int = game.index_of("1-4")
	main.play_level(i14)
	var w: Node = main.current
	_check(w.get_script() == _WorldS and str(w.level_id) == "1-4", "1-4 starts")
	var beat := _cutscene_in(w)
	_check(beat != null and str(beat.scene_id) == "beat_1_4" and bool(w.paused), "1-4 opens on Mother Taper's beat, paused")
	if beat != null:
		beat.manual = true
		_play_out(beat)
	_check(not bool(w.paused), "and gives the level back")
	await process_frame
	_check(w.boss != null, "1-4 has its boss")
	if w.boss != null:
		w._on_boss_woke()
		var bb := _cutscene_in(w)
		_check(bb != null and str(bb.scene_id) == "boss_1_before" and bool(w.paused), "Tollgrave wakes: his beat, over the paused level")
		if bb != null:
			bb.manual = true
			_play_out(bb)
		_check(game.seen("boss_1_before") and game.seen("boss_card_tollgrave") and not bool(w.paused), "seen, his card too, and the fight is on")
		await process_frame
		# Snuffed and back: straight to the fight.
		main.play_level(i14)
		var w2: Node = main.current
		var again := _cutscene_in(w2)
		_check(again == null and not bool(w2.paused), "a retry of 1-4 has no beat")
		w2._on_boss_woke()
		_check(_cutscene_in(w2) == null and not bool(w2.paused), "and Tollgrave's beat doesn't play again")
		await process_frame
	# The bell rung: boss_1_after, the results, then Onward into World 2.
	main.last_level = i14
	main._on_finished(_result("1-4", "boss_1_after"))
	var after: Node = main.current
	_check(_is_scene(after, "boss_1_after"), "the first clear of 1-4 plays boss_1_after")
	_check(_play_out(after), "which plays through")
	_check(main.current.get_script() == _ResultsS, "then the results")
	_check(game.is_unlocked(game.index_of("2-1")), "2-1 is open")
	await process_frame
	main.current.next.emit()
	_check(_is_scene(main.current, "world_2"), "Onward: World 2's opening scene first")
	_check(_play_out(main.current), "which plays through")
	_check(main.current.get_script() == _WorldS and str(main.current.level_id) == "2-1", "then 2-1")
	_check(game.seen("world_2"), "world_2 is seen")
	await process_frame
	# The other way out: the results' map button, onto World 2's tab.
	game.reset()
	game.new_hero("witch")
	_clear_up_to("1-4")
	game.mark_seen("boss_1_after")
	main.last_level = i14
	main._on_finished(_result("1-4", "boss_1_after"))
	_check(main.current.get_script() == _ResultsS, "a clear with its scene seen goes straight to the results")
	main.current.to_map.emit()
	await process_frame
	await process_frame
	_check(_is_scene(main.current, "world_2"), "the map opening on World 2 plays its opening scene")
	if _is_scene(main.current, "world_2"):
		_play_out(main.current)
	_check(main.current.get_script() == _MapS and int(main.current.world_tab) == 2 and int(main.current.focus) == game.index_of("2-1"),
			"then the map, on 2-1")
	await process_frame
	await process_frame
	_check(main.current.get_script() == _MapS, "and it doesn't play twice")
	main.queue_free()
	await process_frame


func _test_flow_ending() -> void:
	## The Snuffer falls: boss_2_after, the results (no Nightfall: in v3 it
	## waits for the Hush, for everyone; 2-4 keeps v2's "Go on, sprout.
	## Rest."), then the_pull (the turn), whichever way out, and after it the
	## player's own choice (resume): Onward into World 3 once it's built, else
	## the map. Then Nightfall, once a (stub) Hush has opened it.
	var i24: int = game.index_of("2-4")
	if i24 < 0:
		return
	var main: Node
	if game.levels_in_world(3).is_empty():
		# No World 3 built (a W1-W2 build): the turn waits. boss_2_after, the
		# results, and Onward goes to the map with nothing owed, Taper well.
		game.reset()
		game.new_hero("sexton")
		_clear_up_to("2-4")
		for id in ["intro", "oath", "world_2"]:
			game.mark_seen(id)
		main = await _new_main()
		main.last_level = i24
		main._on_finished(_result("2-4", "boss_2_after"))
		_check(_is_scene(main.current, "boss_2_after") and _play_out(main.current), "(no World 3) the first clear of 2-4 plays boss_2_after")
		_check(main.current.get_script() == _ResultsS and main._finale_due() == "", "(no World 3) then the results, the_pull not owed")
		if main.current.get_script() == _ResultsS:
			main.current.next.emit()
		_check(main.current.get_script() == _MapS and not game.seen("the_pull") and Story.taper_phase() == "well",
				"(no World 3) Onward goes to the map: the_pull unseen, Mother Taper well")
		main.queue_free()
		await process_frame
	# World 3 built (a stand-in 3-1 until WL3's): the turn is owed.
	var kept31 := _stand_in_31()
	game.reset()
	game.new_hero("sexton")
	_clear_up_to("2-4")
	for id in ["intro", "oath", "world_2"]:
		game.mark_seen(id)
	main = await _new_main()
	main.last_level = i24
	main._on_finished(_result("2-4", "boss_2_after"))
	_check(_is_scene(main.current, "boss_2_after"), "the first clear of 2-4 plays boss_2_after")
	_check(_play_out(main.current), "which plays through")
	var res: Node = main.current
	_check(res.get_script() == _ResultsS, "then the results")
	_check(str(res.after.get("text", "")) == "Every bell. Every lamp. Go on, sprout. Rest.", "2-4's results line stays v2's, on purpose")
	var opened := false
	for r in res.rewards:
		opened = opened or (r is Dictionary and r.get("kind", "") == "difficulty" and r.get("id", "") == "nightfall")
	_check(not opened and not game.diff_open("nightfall"), "the results open no Nightfall: it waits for the Hush (the owner's answer)")
	await process_frame
	res.next.emit()
	var turn: Node = main.current
	_check(_is_scene(turn, "the_pull"), "Onward from 2-4: the_pull first")
	_check(bool(Story.scene("the_pull").get("resume", false)), "(a finale that resumes the player's choice)")
	var credits := false
	for i in 6000:
		if turn.finished:
			break
		credits = credits or turn.waiting == "credits"
		if turn.waiting == "line" and i % 10 == 9:
			turn.tap()
		turn.advance(DT)
	_check(turn.finished and not credits, "the_pull plays through, and rolls no credits")
	_check(game.seen("the_pull") and main._finale_due() == "", "the_pull is seen, and nothing is owed")
	var i31: int = game.index_of("3-1")
	if i31 >= 0:
		_check(_is_scene(main.current, "world_3") or (main.current.get_script() == _WorldS and str(main.current.level_id) == "3-1"),
				"then Onward goes on into World 3")
	else:
		_check(main.current.get_script() == _MapS, "then, with no 3-1 built yet, the map")
	_check(Story.taper_phase() == "faint" and not Story.taper_resting(), "Mother Taper is faint from here on")
	await process_frame
	# After that, the results' buttons are just themselves again.
	main.last_level = i24
	main._on_finished(_result("2-4", "boss_2_after"))
	_check(main.current.get_script() == _ResultsS, "a second clear of 2-4: the results")
	main.current.replay.emit()
	_check(main.current.get_script() == _WorldS and str(main.current.level_id) == "2-4", "and Replay replays it")
	_check(main.current.get_node_or_null("StoryBarks") == null, "(on Dusk, no Nightfall word)")
	await process_frame
	# Replay from the first results (the_pull owed): the_pull, then the replay.
	game.reset()
	game.new_hero("sexton")
	_clear_up_to("2-4")
	for id in ["intro", "oath", "world_2", "boss_2_after"]:
		game.mark_seen(id)
	main.last_level = i24
	game.record_result(_result("2-4", "boss_2_after"))
	main._show_results(_result("2-4", "boss_2_after"), {"first_clear": true})
	main.current.replay.emit()
	_check(_is_scene(main.current, "the_pull"), "Replay with the_pull owed plays it first")
	_play_out(main.current)
	_check(main.current.get_script() == _WorldS and str(main.current.level_id) == "2-4", "and then the replay, as chosen")
	await process_frame
	# Nightfall, first walked: Mother Taper's word on it, over live play, once
	# (after the level's own barks, if its beat left some). The Hush opens
	# it (a stub 6-4 in the build for the moment).
	var kept: Array = game.LEVELS
	game.LEVELS = kept + [{"id": "6-4", "path": "res://levels/6-4.txt", "world": 6}]
	game.record_result(_result("6-4"))
	game.LEVELS = kept
	_check(game.diff_open("nightfall"), "(the Hush opens Nightfall)")
	game.set_diff("nightfall")
	_check(game.diff() == "nightfall", "(Nightfall chosen)")
	main.play_level(0)
	var q: Node = main.current.get_node_or_null("StoryBarks")
	_check(q != null and q.keys == ["beat_1_1_a", "beat_1_1_b", "nightfall"], "1-1's own barks, then Taper's word on Nightfall: %s" % [q.keys if q != null else []])
	await process_frame
	game.mark_seen("beat_1_2")     # (seen on Dusk)
	main.play_level(1)
	q = main.current.get_node_or_null("StoryBarks")
	_check(q != null and q.keys == ["nightfall"], "the first level on Nightfall has Taper's word on it")
	if q != null:
		for i in 400:
			if q.is_queued_for_deletion():
				break
			q.step(DT)
	_check(Story.bark_heard("nightfall"), "said once")
	await process_frame
	main.play_level(1)
	_check(main.current.get_node_or_null("StoryBarks") == null, "and not again")
	game.set_diff("dusk")
	_put_levels(kept31)
	main.queue_free()
	await process_frame


func _stand_in_31() -> Array:
	## A stand-in 3-1 while no World 3 level is built (WL3 lands in wave 2):
	## the_pull resumes into World 3, so it's owed only once World 3 is in
	## the build. Returns the levels to put back with _put_levels.
	var kept: Array = game.LEVELS.duplicate()
	if game.levels_in_world(3).is_empty():
		game.LEVELS.append({"id": "3-1", "path": "res://levels/1-1.txt", "world": 3})
	return kept


func _put_levels(kept: Array) -> void:
	game.LEVELS.clear()
	game.LEVELS.append_array(kept)


func _test_flow_veteran() -> void:
	## A v1 save: kept as a veteran (unlocks, codex, +150 embers), the story
	## plays once from the top, the first hero starts at L1, and the map
	## opens on 1-1 (not on World 2's door, whose scene would play).
	var fixture := "res://tests/fixtures/v1_save.json"
	if not FileAccess.file_exists(fixture):
		return
	var haptics = game.setting("haptics")
	var f := FileAccess.open(game.save_path, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(fixture))
	f.close()
	game.load_save()
	_check(game.veteran() == 4 and game.embers() == 212 + 150 and game.heroes().is_empty(), "the v1 save loads as a veteran")
	_check(game.unlocked_count("dusk") == 5 and not game.seen("intro"), "unlocks kept (2-1 open), no story seen")
	var main: Node = await _new_main()
	main._after_title()
	_check(_is_scene(main.current, "intro"), "the veteran's first tap plays the new intro")
	_play_out(main.current)
	_check(_is_scene(main.current, "oath"), "and the oath")
	_play_out(main.current, "runner")
	_check(game.hero_id() == "runner" and int(game.hero()["level"]) == 1, "his first hero starts at L1")
	_check(main.current.get_script() == _MapS and int(main.current.focus) == 0 and int(main.current.world_tab) == 1, "the map opens on 1-1")
	await process_frame
	await process_frame
	_check(main.current.get_script() == _MapS and not game.seen("world_2"), "and World 2's scene doesn't play")
	# The next launch, from disk.
	game.load_save()
	_check(game.seen("intro") and game.seen("oath") and game.has_hero("runner"), "the save remembers the story and the hero")
	main.show_title()
	main._after_title()
	_check(main.current.get_script() == _MapS, "the next launch: straight to the map, no intro")
	_check(int(main.current.focus) == 0, "still on 1-1, the first level he hasn't cleared in v2")
	await process_frame
	await process_frame
	_check(main.current.get_script() == _MapS and not game.seen("world_2"), "and no World 2 scene")
	_check(main.next_level() == 0, "(main's next level is 1-1)")
	game.record_result(_result("1-1"))
	_check(main.next_level() == 1, "clearing 1-1 moves it to 1-2")
	main.queue_free()
	await process_frame
	game.set_setting("haptics", haptics)
	game.reset()
	game.save()


func _test_flow_second_calling() -> void:
	## Another calling from the map's Callings screen starts at
	## max(1, best - 2) in a Blessed kit at that item level, its points
	## unspent, and Mother Taper has a word for it.
	if not ResourceLoader.exists("res://scripts/keeper_screen.gd"):
		return
	game.reset()
	game.new_hero("knight")
	game.add_xp(load("res://scripts/progression.gd").total_to(7))
	_check(int(game.hero()["level"]) == 7, "(a level 7 Candleknight)")
	var main: Node = await _new_main()
	main.show_map()
	main.show_callings()
	var k: Node = main.current
	_check(k.get_script() == load("res://scripts/keeper_screen.gd"), "Callings opens the Keeper screen")
	await process_frame
	k.open_card("founder")
	k.choose("founder")
	await process_frame
	var h: Dictionary = game.hero()
	_check(game.hero_id() == "founder" and int(h["level"]) == 5, "the Bellfounder starts at 5 = 7 - 2 (%d)" % int(h["level"]))
	var kit_ok := true
	for slot in ["weapon", "candle", "coat"]:
		var it = h["equip"][slot]
		kit_ok = kit_ok and it is Dictionary and str(it["rarity"]) == "magic" and int(it["ilvl"]) == 5
	_check(kit_ok, "in a Blessed kit at item level 5")
	_check(int(h["points"]) == 4, "with its 4 points unspent (%d)" % int(h["points"]))
	_check(main.current.get_script() == _MapS and Cutscene.running_on(main.current, "new_calling") != null,
			"back on the map, Mother Taper greets the new calling")
	var greet: Node = Cutscene.running_on(main.current, "new_calling")
	if greet != null:
		greet.manual = true
		var line := ""
		for i in 400:
			if greet.waiting == "line":
				line = str(greet._line["text"])
				break
			greet.advance(DT)
		_check(line == Story.class_line("taper_react", "founder")[1], "with the Bellfounder's own line: %s" % line)
		_play_out(greet)
	# Back to the knight: an old calling, no greeting, still level 7.
	main.show_callings()
	main.current.choose("knight")
	await process_frame
	_check(game.hero_id() == "knight" and int(game.hero()["level"]) == 7, "switching back keeps the knight at 7")
	_check(Cutscene.running_on(main.current, "new_calling") == null, "and has no greeting")
	main.queue_free()
	await process_frame


func _test_taunt() -> void:
	## The Snuffer's taunt: in the belfry's broken window (the sill), and when
	## he drops out of it his eyes go with him.
	game.reset()
	var cs := _play("boss_1_after", false)
	var n := 0
	while n < 4000 and not cs.finished and not (cs._figs.has("sill") and not (cs._figs["sill"]["tw"] as Dictionary).is_empty()):
		if cs.waiting == "line" and n % 10 == 9:
			cs.tap()
		cs.advance(DT)
		n += 1
	_check(cs._figs.has("sill") and str(cs._figs["sill"]["id"]) == "snuffer_stand", "the taunt stands the Snuffer on the sill")
	var eyes_before := false
	for fe in cs._flames:
		eyes_before = eyes_before or fe.get("eyes", false)
	_check(eyes_before, "his eyes are lit as he goes")
	for i in 48:     # his 0.7 s drop, and a moment (the shot holds 0.9 s)
		cs.advance(DT)
	var eyes_after := false
	for fe in cs._flames:
		eyes_after = eyes_after or fe.get("eyes", false)
	_check(cs._figs.has("sill") and float(cs._figs["sill"]["alpha"]) < 0.01 and not eyes_after, "gone, and no eyes left hanging in the window (%s, %s, %s)" % [cs._figs.has("sill"), cs._figs.get("sill", {}).get("alpha", -1), eyes_after])
	cs.queue_free()
	await process_frame


func _test_blips_in_key() -> void:
	## Story blips sing on D minor pentatonic in each speaker's register.
	var sfx := root.get_node_or_null("Sfx")
	if sfx == null or not sfx.has_method("voice_note"):
		return
	var scale := [0, 3, 5, 7, 10]
	var bad := []
	var voices := []
	for who in Story.CAST:
		voices.append(Story.speaker(who, "knight")["voice"])
	for c in Classes.ids():
		voices.append(float(Classes.ALL[c]["voice"]))
	for v in voices:
		if float(v) <= 0.0:
			continue
		for i in 5:
			var p: float = Cutscene.blip_pitch(sfx, float(v), i)
			var semis := roundi(12.0 * log(p) / log(2.0))
			if absf(12.0 * log(p) / log(2.0) - semis) > 0.02 or not scale.has(posmod(semis, 12)):
				bad.append("%.2f/%d" % [v, i])
			if absf(p / float(v) - 1.0) > 1.2:
				bad.append("far %.2f/%d" % [v, i])
	_check(bad.is_empty(), "every speaker's blips are on the scale, near their voice: %s" % [bad])


# ---------------------------------------------------------------- holes in the picture

const HOLE_CLOCKS := [1.2, 5.07, 15.0]      # the drift: all the way down; right; left and level
const HOLE_US := [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]


func _alpha_mask(path: String) -> Image:
	## A layer's art, rasterized small, for its alpha.
	if path == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_svg_from_string(FileAccess.get_file_as_string(path), 0.25) != OK:
		return null
	return img


func _hole_layers(cs, pd: Dictionary, masks: Dictionary) -> Array:
	## [depth, rect, alpha image] for every layer with art, far to near. Only
	## its solid pixels count as cover (a moon shaft over a hole still shows it).
	var out := []
	var size := Vector2(float(pd["size"][0]), float(pd["size"][1]))
	for l in pd.get("layers", []):
		var path := str(l.get("tex", ""))
		if not masks.has(path):
			masks[path] = _alpha_mask(path)
		if masks[path] == null:
			continue
		var rect := Rect2(Vector2.ZERO, size)
		if l.has("rect"):
			var rr: Array = l["rect"]
			rect = Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3]))
		out.append([float(l.get("depth", 1.0)), rect, masks[path]])
	return out


func _holes_at(cs, layers: Array, cam: Vector3, clock: float) -> int:
	## Screen points between the letterbox bars that no layer's art covers,
	## with the camera at `cam` (no lift: it moves every layer alike, and the
	## bottom bar grows with it).
	cs._cam = cam
	cs._clock = clock
	var vs: Vector2 = cs._vs()
	var xfs := []
	for L in layers:
		xfs.append(cs._xf_raw(L[0]))
	var pts := []
	var top: float = cs.LETTERBOX
	var bot: float = vs.y - cs.LETTERBOX
	for x in [0.5, 2.5, vs.x * 0.25, vs.x * 0.5, vs.x * 0.75, vs.x - 2.5, vs.x - 0.5]:
		var y := top + 0.5
		while y < bot:
			pts.append(Vector2(x, y))
			y += 1.0
	for y in [top + 0.5, vs.y * 0.3, vs.y * 0.5, vs.y * 0.7, bot - 0.5]:
		var x := 0.5
		while x < vs.x:
			pts.append(Vector2(x, y))
			x += 4.0
	var holes := 0
	for p in pts:
		var covered := false
		for i in layers.size():
			var q: Vector2 = (p - (xfs[i][0] as Vector2)) / float(xfs[i][1])
			var r: Rect2 = layers[i][1]
			if not r.has_point(q):
				continue
			var img: Image = layers[i][2]
			var t := (q - r.position) / r.size * Vector2(img.get_width(), img.get_height())
			if img.get_pixel(clampi(int(t.x), 0, img.get_width() - 1), clampi(int(t.y), 0, img.get_height() - 1)).a > 0.95:
				covered = true
				break
		if not covered:
			holes += 1
	return holes


func _worst_hole(cs, layers: Array, segs: Array) -> Array:
	## [holes, cam, clock] at the worst sampled point of the moves.
	var worst := [0, Vector3.ZERO, 0.0]
	for sg in segs:
		for u in HOLE_US:
			var cam: Vector3 = (sg[0] as Vector3).lerp(sg[1], u)
			for clock in HOLE_CLOCKS:
				var h := _holes_at(cs, layers, cam, clock)
				if h > int(worst[0]):
					worst = [h, cam, clock]
	return worst


func _test_no_holes() -> void:
	## Every shot's picture covers the screen between the letterbox bars all
	## along its camera's moves, whatever the drift. A far layer whose art
	## stops at the floor line (the belfry's wall at 302, the chapel's at 286)
	## opens a band of the clear colour when the camera zooms in looking up.
	## The Snuffer's taunt had one right across the belfry.
	var cs = Cutscene.new()
	cs._lb = 1.0
	var masks := {}
	var bad := []
	var shots := 0
	for id in Story.scenes():
		var si := -1
		for shot in Story.scene(id).get("shots", []):
			si += 1
			var pid := str(shot.get("panel", ""))
			if pid == "":
				continue
			var pd: Dictionary = cs._panel_def(pid)
			if pd.get("stand_in", false):
				continue
			var layers := _hole_layers(cs, pd, masks)
			if layers.is_empty():
				continue
			cs._size = Vector2(float(pd["size"][0]), float(pd["size"][1]))
			var cams: Array = shot.get("cam", [])
			var a: Vector3 = cs._v3(cams[0]) if cams.size() > 0 else Vector3(0.5, 0.5, 1.0)
			var b: Vector3 = cs._v3(cams[1]) if cams.size() > 1 else a
			var segs := [[a, b]]
			# A "cam" beat moves on from wherever the camera is then.
			var froms := [a, a.lerp(b, 0.5), b]
			for beat in shot.get("beats", []):
				if beat is Dictionary and str(beat.get("do", "")) == "cam":
					var to: Vector3 = cs._v3(beat["to"])
					for f in froms:
						segs.append([f, to])
					froms.append(to)
			var w := _worst_hole(cs, layers, segs)
			shots += 1
			if int(w[0]) > 0:
				bad.append("%s shot %d (%s): %d at cam %s, clock %.1f" % [id, si, pid, w[0], w[1], w[2]])
	_check(shots >= 17, "the hole check saw every shot with art (%d)" % shots)
	_check(bad.is_empty(), "no shot shows a hole between its layers: %s" % [bad])
	# The check itself sees the band the old taunt camera opened.
	var pd: Dictionary = cs._panel_def("belfry")
	if not pd.get("stand_in", false):
		cs._size = Vector2(1000, 460)
		var layers := _hole_layers(cs, pd, masks)
		_check(_holes_at(cs, layers, Vector3(0.7, 0.42, 1.2), 1.2) > 100, "(and it sees the old taunt camera's band)")
		_check(_holes_at(cs, layers, Vector3(0.7, 0.5, 1.2), 1.2) > 20, "(and the thinner one of a level camera at that zoom)")
	cs.free()


func _test_shake_edges() -> void:
	## A shake (or the drift) never shows a panel's edge at the sides or past
	## the letterbox bars: the picture is pushed in just enough while it shakes.
	var cs = Cutscene.new()
	var vs: Vector2 = cs._vs()
	var bad := []
	var checked := 0
	for pid in PANELS:
		var pd: Dictionary = cs._panel_def(pid)
		cs._size = Vector2(float(pd["size"][0]), float(pd["size"][1]))
		var depths := {}
		for l in pd.get("layers", []):
			var rr: Array = l.get("rect", [0, 0, cs._size.x, cs._size.y])
			if Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3])).is_equal_approx(Rect2(Vector2.ZERO, cs._size)):
				depths[float(l.get("depth", 1.0))] = true
		for lb in [0.0, 1.0]:
			cs._lb = lb
			var inset: float = cs.LETTERBOX * lb
			for amt in [0.0, 4.0, 8.0, 10.0]:
				for k in 24:
					cs._shake = amt
					cs._clock = k * 0.37
					cs._cam = Vector3(0.5, 0.5, 1.0)
					for d in depths:
						checked += 1
						var x: Array = cs._xf_raw(d)
						var r := Rect2(x[0], cs._size * float(x[1]))
						if r.position.x > 0.01 or r.end.x < vs.x - 0.01 or r.position.y > inset + 0.01 or r.end.y < vs.y - inset - 0.01:
							bad.append("%s d%.1f shake %.0f lb %.0f: %s" % [pid, d, amt, lb, r])
	_check(checked > 1000, "(the edge check ran: %d)" % checked)
	_check(bad.is_empty(), "no panel edge shows through a shake or the drift: %s" % [bad.slice(0, 4)])
	cs.free()


# ================================================================ v3

func _all_scene_lines() -> Array:
	## [scene id, shot index, beat] for every line (and the hold's nudge).
	var out := []
	for id in Story.scenes():
		var si := 0
		for shot in Story.scene(id).get("shots", []):
			for b in shot.get("beats", []):
				if Story.is_line(b):
					out.append([id, si, b])
				elif b is Dictionary and b.get("do", "") == "hold" and b.get("nudge", []) is Array and (b["nudge"] as Array).size() >= 2:
					out.append([id, si, b["nudge"]])
			si += 1
	return out


func _test_v3_script() -> void:
	## The script's v3 rules (spec §6.1-6.5, contract.md §9).
	# The chain: the turn after 2-4, the finale after 6-4; v2's ending gone.
	_check(str(Story.scene("boss_2_after").get("finale", "")) == "the_pull", "boss_2_after's finale is the_pull")
	_check(bool(Story.scene("the_pull").get("resume", false)), "the_pull resumes the player's choice after it")
	_check(str(Story.scene("boss_6_after").get("finale", "")) == "homecoming", "boss_6_after's finale is homecoming")
	_check(str(Story.scene("homecoming").get("next", "")) == "lullaby" and not Story.scene("homecoming").has("resume"),
			"homecoming plays on into lullaby, then the map")
	for old in ["ending", "post_credits"]:
		var named := Story.has_scene(old) or Story.TITLES.has(old) or Story.CLASS_LINES.has(old)
		for id in Story.scenes():
			var sc := Story.scene(id)
			named = named or str(sc.get("next", "")) == old or str(sc.get("finale", "")) == old
		for t in Story.TALES:
			named = named or str(t[1]) == old
		_check(not named and Story.RETIRED.has(old), "'%s' is retired: named nowhere" % old)
	# From 6-3 on Hollin is quiet (gone to fetch everyone): nothing said in
	# 6-3 or 6-4 after his "go quiet" is his, nor any Taper line he'd take.
	var quiet := []
	for k in ["first_tide", "hush_p2", "hush_p3", "hush_last", "hush_give_a", "hush_give_b", "give", "hush_keep", "hush_quiet",
			"hush_remembers"]:
		quiet.append(str(Story.BARKS[k][0]))
	quiet.append(str(Story.AFTER["6-3"][0]))
	var b63: Array = Story.scene("beat_6_3")["shots"][0]["beats"]
	for i in range(1, b63.size()):
		if Story.is_line(b63[i]):
			quiet.append(str(b63[i][0]))
	for b in Story.scene("beat_6_4")["shots"][0]["beats"]:
		if Story.is_line(b):
			quiet.append(str(b[0]))
	var talkers := quiet.filter(func(w): return w.begins_with("hollin") or w.begins_with("taper"))
	_check(talkers.is_empty() and str(b63[0][0]).begins_with("hollin"),
			"from Hollin's 'go quiet' in 6-3 on, only the Hush (and the hero) speak in 6-3 and 6-4: %s" % [talkers])
	_check(Story.BARKS["first_tide"][1] == str(Story.BARKS["first_tide"][1]).to_lower(), "(the tide's teaching is the Hush's, lowercase)")
	# A world opener for every world past the first, each of at most 5 lines
	# and ending on its world's card.
	for w in game.WORLD_NAMES:
		if int(w) < 2:
			continue
		var op := Story.world_opener(int(w))
		_check(op == "world_%d" % int(w) and Story.has_scene(op), "world %d has its opener" % int(w))
		_check(Story.lines_of(op, "knight").size() <= 5, "%s has at most 5 lines (%d)" % [op, Story.lines_of(op, "knight").size()])
		var card := {}
		for shot in Story.scene(op).get("shots", []):
			for b in shot.get("beats", []):
				if b is Dictionary and b.get("do", "") == "card":
					card = b
		_check(str(card.get("sub", "")) == "World %d" % int(w) and str(card.get("title", "")) == str(game.WORLD_NAMES[w]),
				"%s's card names World %d, %s" % [op, int(w), game.WORLD_NAMES[w]])
	# The Hush in lowercase, everywhere (the hold's nudge too).
	for e in _all_scene_lines():
		if str(e[2][0]).get_slice(":", 0) == "hush":
			_check(str(e[2][1]) == str(e[2][1]).to_lower(), "%s: the Hush speaks in lowercase" % e[0])
	# His name is always {hero}, never "Waxby" outright (a name the player
	# gave is the one said). Hollin says it in his warmest lines to him;
	# Mother Taper (who says sprout) only when it counts: her welcome at the
	# oath and homecoming; the hero never says his own. "Wick" is the title,
	# explained once: at the oath.
	var named_lines := []
	var hardcoded := []
	var title_lines := []
	for pair in _lines_raw():
		var raw := str(pair[1][1])
		if raw.contains("Waxby"):
			hardcoded.append(pair[0])
		if raw.contains("{hero}"):
			named_lines.append([pair[0], str(pair[1][0]).get_slice(":", 0)])
		if raw.contains("you're a Wick"):
			title_lines.append(pair[0])
	for cls in Classes.ids():
		for slot in Story.CLASS_LINES:
			var t := str(Story.class_line(slot, cls)[1])
			if t.contains("Waxby"):
				hardcoded.append("@%s/%s" % [slot, cls])
	for slot in Story.CLASS_LINES:
		for cls in Story.CLASS_LINES[slot]:
			var e = Story.CLASS_LINES[slot][cls]
			if str(e[1] if e is Array else e).contains("Waxby"):
				hardcoded.append("@%s/%s (raw)" % [slot, cls])
	_check(hardcoded.is_empty(), "no line writes the hero's name out (it's {hero}) %s" % [hardcoded])
	var by_taper := named_lines.filter(func(n): return n[1] == "taper")
	var others := named_lines.filter(func(n): return n[1] != "taper" and n[1] != "hollin")
	var taper_ok := by_taper.size() == 2 and by_taper.has(["oath shot 1", "taper"]) and by_taper.has(["homecoming shot 2", "taper"])
	_check(taper_ok and others.is_empty() and named_lines.size() >= 4,
			"the hero's name: Taper's at the oath's welcome and in homecoming; else Hollin's: %s" % [named_lines])
	_check(title_lines == ["oath shot 1"], "the title is explained once, at the oath: %s" % [title_lines])
	var said := ""
	for l in Story.lines_of("homecoming", "witch"):
		if l["who"] == "taper" and str(l["text"]).contains(Story.HERO_NAME):
			said = l["text"]
	_check(said == "Well done, Waxby.", "\"Well done, Waxby.\" (%s)" % said)
	# Every level beat the level streams will name exists (contract §2.6).
	for w in range(3, 7):
		for n in range(1, 5):
			_check(Story.has_scene("beat_%d_%d" % [w, n]), "beat_%d_%d exists" % [w, n])
		for k in ["before", "after"]:
			_check(Story.has_scene("boss_%d_%s" % [w, k]), "boss_%d_%s exists" % [w, k])
	# The bark keys other streams fire, and none of the retired ones.
	for k in FIRED_BARKS:
		_check(Story.BARKS.has(k), "the bark '%s' (contract §9.2) exists" % k)
	for k in GONE_BARKS:
		_check(not Story.BARKS.has(k) and not Story.CLASS_LINES.has(k), "the old bark '%s' is gone" % k)
	for k in ["give", "hush_give_a", "hush_give_b", "hush_keep", "hush_quiet", "hush_remembers"]:
		_check(Story.BARKS.has(k) and Story.bark_every(k), "the finale's '%s' plays every time" % k)
	for k in Story.REST_SUBS:
		var v := str(Story.REST_SUBS[k])
		_check((Story.has_scene(k) or Story.BARKS.has(k)) and (Story.has_scene(v) or Story.BARKS.has(v)),
				"REST_SUBS %s -> %s both exist" % [k, v])
	# No speaker "prism": the saint (spec §6.5.1); the names as approved.
	for pair in _lines_raw():
		_check(str(pair[1][0]).get_slice(":", 0) != "prism", "%s: the saint speaks as 'saint'" % pair[0])
	_check(Story.CAST["rootmother"]["name"] == "Mother Gravebough", "the Rootmother shows as Mother Gravebough")
	var cards := {}
	for w in range(3, 7):
		for shot in Story.scene("boss_%d_before" % w).get("shots", []):
			for b in shot.get("beats", []):
				if b is Dictionary and b.get("do", "") == "boss_card":
					cards[w] = [b["name"], b["title"]]
	_check(cards == {3: ["Mother Gravebough", "The Bone Gardener"], 4: ["The Tinker of Hours", "The Frozen Minute"],
			5: ["The Prism Saint", "The First Light"], 6: ["The Hush", "The Hungry Quiet"]}, "the boss cards: %s" % [cards])
	# The rule hints (spec §6.5.2), Yarrow's flask (6.5.3), the finale's shots (6.5.5).
	var all_text := ""
	for pair in _lines_raw():
		all_text += str(pair[1][1]) + "\n"
	for hint in ["Her heart runs through the roots. Hit it where it blooms.", "Follow her heart, sprout. It blooms where she can't guard it.",
			"Ring the bell the clock points at. Then hit his spring.", "When her light locks, get behind a mirror.",
			"Her beam bounces off mirrors. Keep one between you.",
			"Here. My old flask. It always had one more drink in it than you'd think.",
			"...not yet.", "little lights. i am so much deeper than your candle.", "Well done, {hero}."]:
		_check(all_text.contains(hint), "the script says: %s" % hint)
	var b6: Array = Story.scene("boss_6_after")["shots"]
	_check(str(b6[0].get("unless", "")) == "hush_given", "boss_6_after's first shot plays unless hush_given")
	var ifs := b6.filter(func(sh): return str(sh.get("if", "")) == "lost_wicks_all")
	_check(ifs.size() == 1, "one shot plays only with every Lost Wick home")
	var holds := 0
	for sh in b6:
		for b in sh.get("beats", []):
			if b is Dictionary and b.get("do", "") == "hold":
				holds += 1
				_check(str(b["prompt"]) == "Hold to give your flame" and str(b["into"]) == "wick.wick" and is_equal_approx(float(b["t"]), 3.0),
						"the hold: 'Hold to give your flame', into the cold wick, 3 s")
	_check(holds == 1, "boss_6_after has its one hold")
	# The results lines, the signs and the Lost Wicks.
	for id in ["3-1", "3-2", "3-3", "3-4", "4-1", "4-2", "4-3", "4-4", "5-1", "5-2", "5-3", "5-4", "6-1", "6-2", "6-3", "6-4",
			"1-S", "2-S", "3-S", "4-S", "5-S", "6-S"]:
		_check(not Story.after_line(id, "knight").is_empty(), "the after-line for %s" % id)
		var ins: Array = Story.INSCRIPTIONS.get(id, [])
		# One a level at most since the sign cut (4-2 has none); a secret's epitaph.
		_check((ins.size() == 1) if id.ends_with("-S") else (ins.size() <= 1), "%s has its inscription (%d)" % [id, ins.size()])
		_check(Story.INSCRIPTIONS.has(id), "%s is in INSCRIPTIONS" % id)
		for t in ins:
			_check(str(t).length() <= Story.MAX_SIGN, "%s's sign fits in %d: %s" % [id, Story.MAX_SIGN, t])
			if id.begins_with("6-") and not id.ends_with("-S"):
				_check(str(t) == str(t).to_lower(), "%s's signs are the Hush's whispers, lowercase" % id)
	for w in Story.LOST_WICKS:
		var who := str(Story.LOST_WICKS[w])
		_check(Story.CAST.has(who) and Story.face_of(who) == "echo", "Lost Wick %d (%s) wears echo_glow" % [w, who])
		var bl := Story.bark_line(Story.lost_wick_bark(int(w)), "knight")
		_check(str(bl.get("who", "")) == who and str(bl.get("portrait", "")).ends_with("echo_glow.svg"), "lost_wick_%d is %s's, in the echo face" % [w, who])
	for m in ["bronze", "silver", "gold", "dawn", "none"]:
		_check(Story.MEDAL_LINES["taper"].has(m) and Story.MEDAL_LINES["hollin"].has(m), "the %s medal line, in both voices" % m)
	# The Tales list: every tale has a title, every title a tale.
	var tale_ids := Story.TALES.map(func(t): return str(t[1]))
	for id in Story.TITLES:
		_check(tale_ids.has(id), "the tale '%s' is in the Tales list" % id)
	for id in tale_ids:
		_check(Story.TITLES.has(id) and Story.has_scene(id), "the tale '%s' has a title and a scene" % id)
	# Every mote a shot or a stand-in panel names is one the cutscene draws.
	for id in Story.scenes():
		for shot in Story.scene(id).get("shots", []):
			if shot.has("motes"):
				_check(Story.MOTES.has(str(shot["motes"])), "%s's motes '%s' are known" % [id, shot["motes"]])
	for pid in PANELS:
		var mk = Stage.panel(pid).get("motes", "")
		_check(mk == null or Story.MOTES.has(str(mk)), "%s's motes are known" % pid)


func _test_taper_state() -> void:
	## E7: Mother Taper's flame is her state, across the seen sets.
	game.reset()
	_check(Story.taper_phase() == "well" and Story.taper_state() == {} and Story.taper_flame() == 1.0 and not Story.taper_resting(),
			"before the_pull she is well (as v2: taper_state {})")
	_check(Story.rest_sub("new_calling") == "new_calling" and Story.bark_line("first_altar", "knight")["mood"] == "warm", "and speaks as she did")
	game.mark_seen("the_pull")
	var st := Story.taper_state()
	_check(Story.taper_phase() == "faint" and st.get("state", "") == "faint" and is_equal_approx(Story.taper_flame(), 0.35)
			and not Story.taper_resting(), "from the_pull she is faint (0.35)")
	_check(Story.bark_line("first_altar", "knight")["mood"] == "faint" and Story.after_line("1-1", "knight")["mood"] == "faint",
			"her barks and results lines wear her faint face")
	_check(Story.after_line("3-3", "knight")["who"] == "hollin", "(Hollin's lines stay his)")
	game.mark_seen("world_5")
	_check(Story.taper_resting() and bool(Story.taper_state()["resting"]), "from world_5 she rests her voice")
	for k in Story.REST_SUBS:
		_check(Story.rest_sub(k) == Story.REST_SUBS[k], "while she rests, %s is Hollin's %s" % [k, Story.REST_SUBS[k]])
	_check(Story.rest_sub("first_altar") == "first_altar", "and nothing else changes")
	_check(Story.medal_line("gold")["who"] == "hollin" and Story.medal_line("gold")["text"] == "Beautiful. Mother would ring a bell for that.",
			"her medal lines are Hollin's while she rests")
	_check(Story.after_line("1-S", "knight")["who"] == "hollin" and Story.after_line("3-S", "knight")["who"] == "hollin",
			"and so are her secret levels' lines")
	game.mark_seen("boss_6_after")
	_check(Story.taper_phase() == "tall" and is_equal_approx(Story.taper_flame(), 2.0) and not Story.taper_resting(),
			"after the finale she stands tall (2.0), awake")
	_check(Story.bark_line("first_altar", "knight")["mood"] == "warm" and Story.medal_line("gold")["who"] == "taper"
			and Story.after_line("1-S", "knight")["who"] == "taper", "and speaks for herself again")
	# By the story's time, for the cutscene (a replay shows her as she was).
	var era := {"intro": "well", "boss_2_after": "well", "the_pull": "faint", "world_3": "faint", "boss_6_after": "faint",
		"homecoming": "tall", "lullaby": "tall"}
	for id in era:
		_check(Story.scene_taper(id) == era[id], "in %s her flame is %s" % [id, era[id]])
	_check(Story.scene_taper("new_calling") == "tall", "a new calling, made any time, shows her as she is now (tall)")
	game.reset()
	game.new_hero("knight")
	for id in ["intro", "oath", "the_pull", "world_3"]:
		game.mark_seen(id)
	_check(Story.scene_taper("new_calling") == "faint" and Story.scene_taper("intro") == "well", "(and faint in W3)")
	game.reset()


func _test_rest_subs() -> void:
	## While she rests, REST_SUBS hands her lines to Hollin, once.
	game.reset()
	game.mark_seen("the_pull")
	game.mark_seen("world_5")
	var l := Story.take_bark("first_secret", "knight")
	_check(l.get("who", "") == "hollin" and str(l.get("text", "")).begins_with("A hidden way! Mother says"), "first_secret is Hollin's while she rests")
	_check(Story.bark_heard("first_secret") and Story.bark_heard("first_secret_hollin") and Story.take_bark("first_secret", "knight").is_empty(),
			"and counts as heard: nobody says it again")
	game.reset()
	game.mark_seen("the_pull")
	_check(Story.take_bark("first_lost_wick", "knight").get("who", "") == "taper", "awake, it's Taper's")
	game.mark_seen("world_5")
	_check(Story.take_bark("first_lost_wick", "knight").is_empty(), "and once heard, Hollin doesn't say it again for her")
	_check(Story.take_bark("new_keeper", "witch").get("who", "") == "hollin" and Story.take_bark("new_keeper", "witch").get("who", "") == "hollin",
			"a new calling's 'every' bark is Hollin's each time")
	# The scenes: new_calling and trials_open play Hollin's, and both count.
	var screen := Control.new()
	root.add_child(screen)
	await process_frame
	for pair in [["new_calling", "new_calling_hollin"], ["trials_open", "trials_open_hollin"]]:
		var cs: Node = Cutscene.play_overlay(screen, pair[0], func(): pass)
		_check(cs != null and str(cs.scene_id) == pair[1], "%s plays %s while she rests" % pair)
		_check(Cutscene.running_on(screen, pair[0]) == cs, "(and is found by the name asked for)")
		if cs != null:
			cs.manual = true
			_drive(cs)
		_check(game.seen(pair[0]) and game.seen(pair[1]), "both are seen after")
	# A caller that swaps it itself (Story.rest_sub, then Hollin's id): both still count.
	game.data["seen"].erase("trials_open")
	game.data["seen"].erase("trials_open_hollin")
	var own: Node = Cutscene.play_overlay(screen, Story.rest_sub("trials_open"), func(): pass)
	if own != null:
		own.manual = true
		_drive(own)
	_check(own != null and game.seen("trials_open") and game.seen("trials_open_hollin"),
			"asked for Hollin's by name, Taper's trials_open counts as seen too")
	screen.queue_free()
	game.reset()
	await process_frame


func _shots_played(cs: Node, steps := 8000) -> Array:
	## The shot indices a scene sets up, in order, played with taps.
	var out := []
	for i in steps:
		if cs.finished:
			break
		if int(cs._shot_i) >= 0 and int(cs._shot_i) < cs._shots.size() and (out.is_empty() or out.back() != int(cs._shot_i)) \
				and cs.waiting != "fade_out":
			out.append(int(cs._shot_i))
		if cs.waiting == "class":
			cs.pick("knight")
		elif i % 10 == 9:
			cs.tap()
		cs.advance(DT)
	return out


func _test_if_unless() -> void:
	## E2: a shot plays only with its "if" flag, or without its "unless" one.
	game.reset()
	_check(not Story.flag("lost_wicks_all") and not Story.flag("hush_given"), "(no flags yet)")
	var cs := _play("boss_6_after", false)
	var played := _shots_played(cs)
	_check(played == [0, 1, 3, 4], "boss_6_after with no flags: the hold, the far bell, the relight, the Lull (%s)" % [played])
	await process_frame
	for w in range(1, 6):
		game.mark_seen("lost_wick:%d" % w)
	_check(Story.lost_wicks_found() == 5 and not Story.flag("lost_wicks_all"), "five Lost Wicks home: not all")
	game.mark_seen("bark:lost_wick_6")
	_check(Story.flag("lost_wicks_all"), "the sixth (heard at its grave candle): all")
	cs = _play("boss_6_after", false)
	played = _shots_played(cs)
	_check(played == [0, 1, 2, 3, 4], "with every Lost Wick home, shot 2b plays too (%s)" % [played])
	await process_frame
	Story.set_flag("hush_given")
	cs = _play("boss_6_after", false)
	played = _shots_played(cs)
	_check(not played.is_empty() and played[0] == 1, "given in the level (hush_given), it opens on the far bell (%s)" % [played])
	await process_frame
	# A cue's "if": lullaby's Descent card shows only with the Descent built.
	game.reset()
	var lu := _play("lullaby", false)
	var titles := []
	for i in 6000:
		if lu.finished:
			break
		if not lu._card.is_empty() and not titles.has(str(lu._card["title"])):
			titles.append(str(lu._card["title"]))
		if i % 10 == 9:
			lu.tap()
		lu.advance(DT)
	var want := ["Nightfall", "Endless Descent"] if Story.flag("modes_descent") else ["Nightfall"]
	_check(titles == want, "lullaby's cards: %s (the Descent %s)" % [titles, "built" if Story.flag("modes_descent") else "not built yet"])
	await process_frame


func _test_hold() -> void:
	## E1: the hold. Held, the light drains over 3 s of held time; let go,
	## it pauses; idle 8 s, the Hush's nudge once; headless it completes at
	## once; with auto-advance it holds by itself after 4 s.
	game.reset()
	var cs := _play("boss_6_after", false)
	cs.hold_instant = false
	var n := 0
	while cs.waiting != "hold" and n < 3000 and not cs.finished:
		if cs.waiting == "line" and n % 10 == 9:
			cs.tap()
		cs.advance(DT)
		n += 1
	_check(cs.waiting == "hold", "boss_6_after waits on its hold (%.1f s in)" % (n * DT))
	if cs.waiting != "hold":
		cs.queue_free()
		return
	_check(str(cs._hold["prompt"]) == "Hold to give your flame" and absf(cs.hold_left() - 1.0) < 0.01, "the prompt is up, the flame whole")
	var vs: Vector2 = cs._vs()
	var hr: Rect2 = cs.hold_rect()
	var hero: Rect2 = cs.figure_rects().back()
	_check(hr.end.y <= vs.y - cs.LETTERBOX and hr.position.y >= 0.0 and not hr.intersects(hero) and hr.size.y >= 36.0,
			"the prompt sits over the letterbox, clear of the hero and his flame (%s, hero %s)" % [hr, hero])
	for i in 60:
		cs.tap()
		cs.advance(DT)
	_check(absf(cs.hold_left() - 1.0) < 0.01 and cs.waiting == "hold", "taps don't give it: only a hold")
	cs.hold_down = true
	var streamed := false
	for i in 90:
		cs.advance(DT)
		streamed = streamed or not cs._streams.is_empty()
	_check(absf(cs.hold_left() - 0.5) < 0.03, "held 1.5 s, half the flame is given (%.2f left)" % cs.hold_left())
	_check(streamed, "its motes stream into the cold wick while held")
	cs.hold_down = false
	for i in 120:
		cs.advance(DT)
	_check(absf(cs.hold_left() - 0.5) < 0.03 and cs.waiting == "hold", "let go, it pauses (%.2f left, no refill)" % cs.hold_left())
	_check(not bool(cs._hold["nudged"]), "(no nudge yet)")
	for i in 400:
		cs.advance(DT)
	_check(bool(cs._hold["nudged"]) and str(cs._line.get("text", "")) == "keep it, then. keep it all alone." and cs.waiting == "hold",
			"after 8 s idle the Hush nudges, and the hold still waits")
	var said_at: float = cs._line.get("start", 0.0)
	for i in 700:
		cs.advance(DT)
	_check(float(cs._line.get("start", -1.0)) == said_at, "the nudge is said once")
	# Keys hold too (a Mac): Space down, Space up.
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	cs._input(ev)
	_check(cs.holding(), "Space held holds")
	ev = ev.duplicate() as InputEventKey
	ev.pressed = false
	cs._input(ev)
	_check(not cs.holding(), "and let go lets go")
	# A finger on Skip doesn't hold; one anywhere else does.
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = cs._pill_rect().get_center()
	_check(not cs._hold_input(t) and not cs.holding(), "a finger on Skip is Skip's")
	t.position = vs * 0.5
	_check(cs._hold_input(t) and cs.holding(), "a finger anywhere else holds")
	t = t.duplicate() as InputEventScreenTouch
	t.pressed = false
	cs._hold_input(t)
	_check(not cs.holding(), "lifted, it lets go")
	cs.hold_down = true
	n = 0
	while cs.waiting == "hold" and n < 400:
		cs.advance(DT)
		n += 1
	_check(cs.waiting != "hold" and absf(n * DT - 1.5) < 0.1, "held again, the rest goes in 1.5 s (%.2f s)" % (n * DT))
	_check(float(cs._lights["actor"]["k"]) <= 0.001 and cs.hold_left() < 0.0, "his light is out, the hold done")
	cs.hold_down = false
	_drive(cs, 6000)
	_check(cs.finished, "and the scene goes on to its end")
	await process_frame
	# Auto-advance: it holds by itself after 4 s.
	game.reset()
	var au := _play("boss_6_after", false)
	au.hold_instant = false
	au.auto = true
	n = 0
	var hold_t := 0
	while not au.finished and n < 12000:
		if au.waiting == "hold":
			hold_t += 1
		au.advance(DT)
		n += 1
	_check(au.finished and absf(hold_t * DT - 7.0) < 0.2, "with auto-advance the hold gives itself after 4 s, over 3 (%.1f s)" % (hold_t * DT))
	await process_frame
	# Headless (the default there), it completes at once.
	var hl := _play("boss_6_after", false)
	_check(hl.hold_is_instant(), "(headless: a hold completes at once)")
	# Stepped by hand (a shot tool's advance(), windowed too), it completes
	# at once; said outright, it doesn't.
	var mh = Cutscene.new()
	mh.manual = true
	var mh_at_once: bool = mh.hold_is_instant()
	mh.hold_instant = false
	var mh_held: bool = not mh.hold_is_instant()
	mh.manual = false
	mh.hold_instant = true
	_check(mh_at_once and mh_held and mh.hold_is_instant(), "a scene stepped by advance() completes a hold at once; hold_instant false keeps it")
	mh.free()
	var waited := false
	var out_at := -1.0
	for i in 8000:
		if hl.finished:
			break
		waited = waited or hl.waiting == "hold"
		if out_at < 0.0 and int(hl._shot_i) == 0 and hl._beat_i > 6:
			out_at = float(hl._lights.get("actor", {}).get("k", 1.0))
		if i % 10 == 9:
			hl.tap()
		hl.advance(DT)
	_check(hl.finished and not waited, "headless, advance() completes the hold and the scene reaches its end")
	_check(out_at >= 0.0 and out_at <= 0.001, "his light went out (%.2f)" % out_at)
	await process_frame


func _start_lights(cs: Node, shot: Dictionary) -> Dictionary:
	## The lights a shot starts with: id -> k.
	cs._clear_stage()
	cs._shot = shot
	cs._panel_id = str(shot["panel"])
	cs._build_panel(shot)
	var out := {}
	for id in cs._lights:
		out[id] = float(cs._lights[id]["k"])
	return out


func _test_off_lights() -> void:
	## E6: "off" lights start dark in every shot, lights_on lights them; and
	## W1-W2's shots start lit exactly as before E6 (the snapshot).
	game.reset()
	var cs := _play("intro", false)
	await process_frame
	for key in V2_LIGHTS:
		var id := str(key).get_slice("/", 0)
		var si := int(str(key).get_slice("/", 1))
		var shot: Dictionary = Story.scene(id)["shots"][si]
		var st := _start_lights(cs, shot)
		var lit := []
		for lid in st:
			if float(st[lid]) > 0.001:
				lit.append("%s:%.3f" % [lid, st[lid]])
		lit.sort()
		_check(",".join(lit).md5_text().substr(0, 10) == V2_LIGHTS[key], "%s starts lit as it did before E6" % key)
	for id in V2_SCENES:
		for shot in Story.scene(id).get("shots", []):
			_check(not shot.has("lights_on") and not shot.has("if") and not shot.has("unless"), "%s needs no v3 keys" % id)
	# Every shot: its panel's off lights, and its figures', start dark
	# unless the shot lights them itself.
	var bad := []
	for id in Story.scenes():
		for shot in Story.scene(id).get("shots", []):
			if not shot.has("panel"):
				continue
			var st := _start_lights(cs, shot)
			var pd: Dictionary = cs._panel
			var offs := []
			for lid in pd.get("lights", {}):
				if bool((pd["lights"][lid] as Dictionary).get("off", false)):
					offs.append(lid)
			var figs: Dictionary = shot.get("figs", {})
			for a in figs:
				var fd: Dictionary = cs._figure_def(str(figs[a]))
				var fl: Dictionary = fd.get("light", {}) if fd.get("light", null) is Dictionary else {}
				for nm in fl:
					if bool((fl[nm] as Dictionary).get("off", false)):
						offs.append("%s.%s" % [a, nm])
			for lid in offs:
				var lit_by_shot: bool = (shot.get("lights_on", []) as Array).has(lid) or (shot.get("light_r", {}) as Dictionary).has(lid)
				if not lit_by_shot and float(st.get(lid, 0.0)) > 0.001:
					bad.append("%s: %s" % [id, lid])
	_check(bad.is_empty(), "every off light starts dark: %s" % [bad])
	var th: Dictionary = _start_lights(cs, Story.scene("the_pull")["shots"][0])
	_check(th.get("under_warm", -1.0) == 0.0 and th.get("grasp.stolen", -1.0) == 0.0 and th.get("under_flame", -1.0) == 0.0,
			"the_pull opens with the warm Undercandle dark (a cue lights it) and the grasp's flame out")
	var hw: Dictionary = _start_lights(cs, Story.scene("boss_3_after")["shots"][1])
	var on := true
	for i in range(1, 7):
		on = on and float(hw.get("kept%d" % i, 0.0)) == 1.0 and float(hw.get("cage%d" % i, 1.0)) == 0.0
	_check(on and float(hw.get("spirit.head", 0.0)) == 1.0, "lights_on: the kept lights and Yarrow's candle start lit in the goodbye")
	var lb: Dictionary = _start_lights(cs, Story.scene("lullaby")["shots"][0])
	_check(lb.get("eye.pupil", -1.0) == 0.0 and lb.get("float.wick", -1.0) == 0.0, "the eye's glint and its candle start dark in lullaby")
	cs.queue_free()
	await process_frame


func _test_tints_and_motes() -> void:
	## Lights carry their colour as a tint on v3 panels (never on v2's),
	## a "hush" light eats light; the new motes move and draw in a batch.
	game.reset()
	var cs := _play("intro", false)
	await process_frame
	_start_lights(cs, Story.scene("boss_2_before")["shots"][0])
	cs._feed_lights()
	var tints: PackedVector4Array = cs._mat.get_shader_parameter("tints")
	var any := false
	for t in tints:
		any = any or t.w > 0.0
	_check(not any, "a v2 panel (the undercandle) carries no tints")
	_start_lights(cs, Story.scene("world_3")["shots"][0])
	cs._feed_lights()
	tints = cs._mat.get_shader_parameter("tints")
	var warm := 0
	for t in tints:
		if t.w > 0.0 and t.x > t.z:
			warm += 1
	_check(warm >= 6, "the orchard's scorch tints its light warm (%d)" % warm)
	cs._lights["scorch1"]["hush"] = true
	cs._feed_lights()
	var lights: PackedVector4Array = cs._mat.get_shader_parameter("lights")
	var neg := 0
	for L in lights:
		neg += 1 if L.w < 0.0 else 0
	_check(neg == 1, "a hush light goes in with a negative strength (%d)" % neg)
	var TB: GDScript = load("res://scripts/tri_batch.gd")
	var vs: Vector2 = cs._vs()
	for kind in ["spores", "rime", "shards", "fireflies"]:
		cs._init_motes(kind)
		_check(cs._motes.size() == int(cs.MOTE_COUNT[kind]), "%s: %d motes" % [kind, cs._motes.size()])
		var before: Vector2 = cs._motes[0]["p"]
		for i in 60:
			cs._step_motes(DT)
		var moved: bool = (cs._motes[0]["p"] as Vector2).distance_to(before) > 0.5
		var inside := true
		for m in cs._motes:
			var p: Vector2 = m["p"]
			inside = inside and p.x >= -25.0 and p.x <= vs.x + 25.0 and p.y >= -25.0 and p.y <= vs.y + 25.0
		var tb = TB.new()
		var drew: bool = cs._mote_tb(tb, cs._motes[0], cs._motes[0]["p"])
		_check(moved and inside and drew and tb.vertex_count() > 0, "%s drift and draw through the batch" % kind)
	cs._init_motes("dust")
	var tb2 = TB.new()
	_check(not cs._mote_tb(tb2, cs._motes[0], Vector2.ZERO), "(v2's motes draw as they did)")
	cs.queue_free()
	await process_frame


func _test_replay() -> void:
	## A tale replayed (the Tales screen): the oath asks for no calling and
	## makes no hero; a boss beat marks no card; the scene still ends.
	game.reset()
	game.new_hero("founder")
	game.set_hero_name("Ash")
	for id in ["intro", "oath", "boss_1_before"]:
		game.mark_seen(id)
	var cs: Node = Cutscene.make("oath", _cb())
	cs.replay = true
	cs.manual = true
	cs.name_instant = false   # (a player's replay: still no entry)
	cs.follow_next = false
	root.add_child(cs)
	var asked := false
	var named := false
	var welcome := ""
	for i in 4000:
		if cs.finished:
			break
		asked = asked or cs.waiting == "class"
		named = named or cs.waiting == "name"
		if cs.waiting == "line" and str(cs._line.get("text", "")).begins_with("Carry the flame"):
			welcome = str(cs._line["text"])
		if i % 10 == 9:
			cs.tap()
		cs.advance(DT)
	_check(cs.finished and not asked, "the oath replays without its chooser")
	_check(game.heroes().size() == 1 and game.hero_id() == "founder", "and makes no hero")
	_check(not named and game.hero_name() == "Ash", "and asks no name: he's still Ash (%s)" % game.hero_name())
	_check(welcome.ends_with("Welcome, Ash."), "Taper's welcome says the name he has: %s" % welcome)
	await process_frame
	var bb: Node = Cutscene.make("boss_1_before", func(): pass)
	bb.replay = true
	bb.manual = true
	root.add_child(bb)
	_check(bb.get_node_or_null("Backdrop") != null, "a replay has a dark backdrop behind it")
	_drive(bb)
	_check(bb.finished and not game.seen("boss_card_tollgrave"), "a boss beat replayed marks no card")
	game.reset()
	await process_frame


func _load_fixture(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(game.save_path, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(path))
	f.close()
	game.load_save()
	return true


func _test_flow_v2_save() -> void:
	## The owner's v2 saves (and the v2 fixture): v2's ending seen, the_pull
	## not; its next map plays the_pull, then nothing more is owed.
	var haptics = game.setting("haptics")
	var turned := 0
	# (owner_v3_lab_save.json: his slot 1 as the phone holds it now, written
	# as v3 by the feel-lab build; the save he plays World 3 with.)
	for fx in ["res://tests/fixtures/v2_save.json", "res://tests/fixtures/owner_v2_save.json", "res://tests/fixtures/owner_v2_save_2.json",
			"res://tests/fixtures/owner_v3_lab_save.json"]:
		if not _load_fixture(fx):
			continue
		var tag: String = str(fx).get_file()
		var cleared := bool(game.level_record("2-4", "dusk")["cleared"])
		if not cleared:
			print("  %s: 2-4 not cleared on Dusk; no turn owed" % tag)
			continue
		turned += 1
		_check(not game.seen("the_pull") and Story.taper_phase() == "well", "%s: the_pull not seen yet, Taper well" % tag)
		var main: Node = await _new_main()
		if game.levels_in_world(3).is_empty():
			# This build (no World 3): the map owes it nothing, and the save keeps it owed.
			main.show_map()
			_check(main.current.get_script() == _MapS and not game.seen("the_pull") and Story.taper_phase() == "well",
					"%s: with no World 3 built, its map owes nothing (the_pull kept for World 3)" % tag)
			await process_frame
		var kept31 := _stand_in_31()
		main.show_map()
		_check(_is_scene(main.current, "the_pull"), "%s: its next map plays the_pull" % tag)
		if _is_scene(main.current, "the_pull"):
			_check(_play_out(main.current), "%s: which plays through" % tag)
		_check(main.current.get_script() == _MapS and game.seen("the_pull") and main._finale_due() == "", "%s: then the map, nothing owed" % tag)
		_check(Story.taper_phase() == "faint", "%s: Mother Taper is faint now" % tag)
		if game.index_of("3-1") >= 0 and not game.seen("world_3"):
			# World 3's tab opens: its opener, then the map on 3-1.
			main._on_world_opened(3)
			_check(_is_scene(main.current, "world_3"), "%s: World 3's tab plays world_3" % tag)
			if _is_scene(main.current, "world_3"):
				_check(_play_out(main.current), "%s: which plays through" % tag)
			_check(main.current.get_script() == _MapS and game.seen("world_3") and main._finale_due() == "", "%s: then the map, on World 3" % tag)
		_put_levels(kept31)
		main.queue_free()
		await process_frame
	_check(turned > 0, "a v2 save with 2-4 cleared was checked (%d; the fixtures are there)" % turned)
	game.reset()
	game.set_setting("haptics", haptics)
	game.save()


func _write_stub_64() -> bool:
	var src := FileAccess.get_file_as_string("res://levels/1-1.txt")
	if src == "":
		return false
	src = src.replace("title: The Nave", "title: The Heart of the Hush").replace("story_start: beat_1_1", "story_end: boss_6_after")
	var f := FileAccess.open(STUB_64, FileAccess.WRITE)
	f.store_string(src)
	f.close()
	return true


func _test_flow_homecoming() -> void:
	## The Hush falls (a stand-in 6-4 until WL6 builds it): boss_6_after, the
	## results, then homecoming (the credits, then the cast roll), lullaby and
	## the map; Mother Taper tall, nothing owed. Given in the level
	## (hush_given), boss_6_after opens on the far bell.
	# (With WL6's 6-4 in the build, the real level; else the stand-in.)
	var built: bool = game.index_of("6-4") >= 0
	if not built and not _write_stub_64():
		return
	for given in [false, true]:
		game.reset()
		game.new_hero("runner")
		_clear_up_to("2-4")
		game.record_result(_result("2-4", "boss_2_after"))
		for id in ["intro", "oath", "world_2", "boss_2_after", "the_pull"]:
			game.mark_seen(id)
		if given:
			Story.set_flag("hush_given")
		var kept: Array = game.LEVELS.duplicate()
		if not built:
			game.LEVELS.append({"id": "6-4", "path": STUB_64, "world": 6})
		var i64: int = game.index_of("6-4")
		var main: Node = await _new_main()
		main.last_level = i64
		main._on_finished(_result("6-4", "boss_6_after"))
		var end: Node = main.current
		_check(_is_scene(end, "boss_6_after"), "the Hush's first clear plays boss_6_after (given %s)" % given)
		if _is_scene(end, "boss_6_after"):
			end.manual = true
			var shots := _shots_played(end)
			_check(shots == ([1, 3, 4] if given else [0, 1, 3, 4]), "it opens on shot %d (%s)" % [1 if given else 0, shots])
		await process_frame
		_check(main.current.get_script() == _ResultsS, "then the results")
		_check(str(main.current.after.get("text", "")) != "", "with Hollin's line (%s)" % main.current.after.get("text", ""))
		main.current.next.emit()
		var home: Node = main.current
		_check(_is_scene(home, "homecoming"), "then homecoming")
		var credits := false
		var cast := false
		for i in 12000:
			if home.finished:
				break
			credits = credits or home.credits_phase() == "roll"
			cast = cast or home.credits_phase() == "cast"
			if home.waiting == "line" and i % 10 == 9:
				home.tap()
			home.advance(DT)
		_check(home.finished and credits and cast, "homecoming rolls the credits, then the cast")
		_check(game.seen("homecoming") and game.seen("lullaby"), "and plays on into lullaby")
		_check(main.current.get_script() == _MapS and main._finale_due() == "", "then the map, nothing owed")
		_check(Story.taper_phase() == "tall" and not Story.taper_resting(), "Mother Taper stands tall")
		game.LEVELS.clear()
		game.LEVELS.append_array(kept)
		main.queue_free()
		await process_frame
	if not built:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STUB_64))
	game.reset()


func _test_shader() -> void:
	## The cutscene's layers use darkness_lit.gdshader, the dark's sibling:
	## no string surgery, no fallback copy of the bands.
	var lit: Shader = load("res://shaders/darkness_lit.gdshader")
	_check(Cutscene._lit_shader() == lit, "the layer shader is darkness_lit.gdshader")
	_check(not FileAccess.get_file_as_string("res://scripts/cutscene.gd").contains("LIT_" + "FALLBACK")
			and not Cutscene.get_script_constant_map().has("LIT_" + "FALLBACK"), "and there is no fallback copy of it")
	# The phone's GPU test: levels keep Plan A, the cutscenes take the
	# quarter field (Plan B: darkness_field once, darkness_lit_b per layer).
	var WL: GDScript = load("res://scripts/world_lights.gd")
	_check(Cutscene.field_plan() == "quarter" and WL.field_mode() == "full", "cutscenes on the quarter field, levels on the full one")
	var lit_b: Shader = load("res://shaders/darkness_lit_b.gdshader")
	game.reset()
	for id in ["intro", "boss_2_after", "world_4", "boss_6_after"]:
		var cs := _play(id, false)
		await process_frame
		_check(cs._mat is ShaderMaterial and (cs._mat as ShaderMaterial).shader == lit_b and cs._field != null
				and is_equal_approx(float(cs._field.scale), 0.25), "%s plays on the quarter field (darkness_lit_b.gdshader)" % id)
		var on: bool = cs._field != null and cs._field.viewport().render_target_update_mode == SubViewport.UPDATE_ALWAYS
		var uses: bool = cs._layers.any(func(r): return not bool(r["lit"]))
		_check(on or not uses, "(%s: its field pass runs once a layer is drawn lit)" % id)
		cs.queue_free()
	# An overlay of lines alone over a live level never runs the field pass.
	var ov := _play("beat_3_1", true)
	await process_frame
	_check(ov._field == null or ov._field.viewport().render_target_update_mode == SubViewport.UPDATE_DISABLED, "a bark-only overlay runs no field pass")
	ov.queue_free()
	# Plan A still works where it's asked for (--cutscene-field=full).
	WL.force_cutscene_field = "full"
	for id in ["intro", "world_4"]:
		var cs := _play(id, false)
		await process_frame
		_check(cs._mat is ShaderMaterial and (cs._mat as ShaderMaterial).shader == lit and cs._field == null, "%s plays on darkness_lit.gdshader under Plan A" % id)
		cs.queue_free()
	WL.force_cutscene_field = ""
	await process_frame


func _test_tales() -> void:
	## The Tales (P1): the tales this save has seen, by world, each replayed
	## over the screen without changing anything; every control a thumb's
	## size, inside the safe area, at the phone's widths.
	var path := "res://scripts/tales_screen.gd"
	if not ResourceLoader.exists(path):
		print("  skipped: tales_screen.gd missing")
		return
	var Tales: GDScript = load(path)
	var UIs: GDScript = load("res://scripts/ui.gd")
	game.reset()
	var none: Control = Tales.new()
	root.add_child(none)
	await process_frame
	_check(none.empty() and none.cards().is_empty(), "a new save has no tales yet (and says so)")
	for t in none._tab_btns:
		_check((none._tab_btns[t] as Button).disabled, "(tab %s is shut)" % Story.TALE_TABS[t])
	for t in Story.TALE_TABS:
		var built: bool = int(t) == 7 or game.levels_in_world(int(t)).size() > 0
		_check(none._tab_btns.has(t) == (built and int(t) <= 6), "(tab %s: %s)" % [Story.TALE_TABS[t],
				"a world this build has" if built and int(t) <= 6 else "not there (no levels in this build, or no tale yet)"])
	none.queue_free()
	await process_frame
	game.new_hero("founder")
	for id in ["intro", "oath", "beat_1_2", "boss_1_after", "the_pull", "world_3", "boss_3_after", "homecoming", "trials_open_hollin"]:
		game.mark_seen(id)
	for vs in [Vector2(844, 390), Vector2(847, 390)]:
		for safe in [UIs.phone_safe(vs), Rect2(14, 10, vs.x - 28, vs.y - 18)]:
			UIs.safe_override = safe
			var ts: Control = Tales.new()
			root.add_child(ts)
			await process_frame
			ts.size = vs
			ts._layout()
			var tag := "%dx%d, safe %s" % [vs.x, vs.y, safe]
			_check(ts.tab == 3, "it opens on the furthest world with a tale (%d) [%s]" % [ts.tab, tag])
			_check(ts.cards() == ["world_3", "boss_3_after"], "World 3's tales seen, in story order: %s" % [ts.cards()])
			var rects := [["Back", ts.back_rect()]]
			var tr: Dictionary = ts.tab_rects()
			for k in tr:
				rects.append(["tab %s" % Story.TALE_TABS[k], tr[k]])
			for c in ts._cards:
				rects.append(["card " + str(c["id"]), (c["btn"] as Button).get_rect()])
			var ok := true
			for i in rects.size():
				var r: Rect2 = rects[i][1]
				var inside: bool = r.size.y >= 40.0 and r.size.x >= 40.0 and safe.grow(0.5).encloses(r)
				if not inside:
					print("  %s: %s outside %s or too small" % [rects[i][0], r, safe])
				ok = ok and inside
				for j in range(i + 1, rects.size()):
					if (rects[j][1] as Rect2).intersects(r):
						print("  %s overlaps %s" % [rects[i][0], rects[j][0]])
						ok = false
			_check(ok, "every control is at least 40 px, inside the safe area, apart [%s]" % tag)
			# Every tale's title fits its card's text on two lines, whole.
			var cr: Rect2 = ts.card_rects(1)[0]
			var tw: float = cr.size.x - (8.0 + Tales.THUMB_W + 12.0) - 10.0
			var cut := []
			for tid in Story.TITLES:
				var fit: Array = Tales.title_fit(str(Story.TITLES[tid]), tw)
				var joined := " ".join(PackedStringArray((fit[1] as Array).map(func(x): return str(x))))
				if (fit[1] as Array).size() > 2 or joined != str(Story.TITLES[tid]):
					cut.append("%s (%s at %d)" % [tid, fit[1], fit[0]])
				for ln in fit[1]:
					if UIs.text_width(str(ln), int(fit[0]), "title", 700) > tw + 0.5:
						cut.append("%s: '%s' is wider than %.0f" % [tid, ln, tw])
			_check(cut.is_empty(), "every Tales title fits its card whole, on two lines, at %.0f px [%s]: %s" % [tw, tag, cut])
			ts.queue_free()
			await process_frame
	UIs.safe_override = Rect2()
	var ts: Control = Tales.new()
	root.add_child(ts)
	await process_frame
	_check(not (ts._tab_btns[1] as Button).disabled and not (ts._tab_btns[2] as Button).disabled
			and (not ts._tab_btns.has(4) or (ts._tab_btns[4] as Button).disabled) and ts._tab_btns.has(3),
			"the tabs with tales are open, the rest shut (a world with a tale seen has its tab)")
	ts.show_tab(2)
	_check(ts.cards() == ["the_pull"], "World 2's tab has the_pull (boss_2_after unseen): %s" % [ts.cards()])
	ts.show_tab(7)
	_check(ts.cards() == ["homecoming", "trials_open"], "After: homecoming and the Trials (seen in Hollin's voice): %s" % [ts.cards()])
	ts.show_tab(1)
	_check(ts.cards() == ["intro", "oath", "beat_1_2", "boss_1_after"], "World 1's: %s" % [ts.cards()])
	# Its pictures are baked at art build time (tools/art/bake_tale_thumbs.gd):
	# none is made here, and each is as new as its layers.
	var n := 0
	while ts.thumbs_pending() > 0 and n < 200:
		await process_frame
		n += 1
	_check(ts.thumbs_pending() == 0 and n == 0, "the tab's pictures are there at once, baked (%d frames made here)" % n)
	var idx = JSON.parse_string(FileAccess.get_file_as_string("res://art/story/thumbs/thumbs.json"))
	var stale := []
	for pid in Tales.manifest().get("panels", {}):
		var layers: Array = ts._layers_of(str(pid))
		if layers.is_empty() or str(layers[0][1]) == "":
			continue
		var parts := PackedStringArray()
		for e in layers:
			var lp := str(e[1])
			parts.append(lp + ":" + (FileAccess.get_md5(lp) if lp != "" and FileAccess.file_exists(lp) else ""))
		var rec = idx.get(str(pid), {}) if idx is Dictionary else {}
		if not ResourceLoader.exists(Tales.BAKED % str(pid)) or str((rec as Dictionary).get("src", "")) != "|".join(parts).md5_text():
			stale.append(str(pid))
	_check(stale.is_empty(), "every panel's baked Tales picture is there and as new as its layers (re-run tools/art/bake_tale_thumbs.gd): %s" % [stale])
	# From the imported textures (an export ships those, not the .svg files).
	var tsrc := FileAccess.get_file_as_string("res://scripts/tales_screen.gd")
	_check(not tsrc.contains("load_svg") and not tsrc.contains("get_file_as_string") and not tsrc.contains("FileAccess"),
			"the Tales' pictures never read a raw file (the phone has only the imported textures)")
	var belfry_pic: Texture2D = Tales._thumbs.get("belfry", null)
	var pic_ok := belfry_pic != null and belfry_pic.get_width() >= int(Tales.THUMB_W * 2.0)
	if pic_ok:
		var pimg := belfry_pic.get_image()
		var c := pimg.get_pixel(pimg.get_width() / 2, pimg.get_height() / 2)
		pic_ok = c.a > 0.9 and (c.r + c.g + c.b) > 0.02
	_check(pic_ok, "the belfry's picture is made from its art, small and filled: %s" % [belfry_pic.get_size() if belfry_pic != null else null])
	_check(Tales.first_panel("boss_1_after") == "belfry" and Tales.first_panel("meet_waxley") == "", "a tale's picture is its first panel's")
	# A replay: over the screen, and nothing changes.
	ts._t = 1.0
	var heroes: Dictionary = game.heroes().duplicate(true)
	var seen: Array = (game.data["seen"] as Array).duplicate()
	var cs: Node = ts.play("oath")
	_check(cs != null and cs.get_parent() == ts and bool(cs.replay) and not bool(cs.follow_next), "a tale replays over the Tales")
	_check(ts.play("intro") == null, "(one at a time)")
	if cs != null:
		cs.manual = true
		var asked := false
		for i in 4000:
			if cs.finished:
				break
			asked = asked or cs.waiting == "class"
			if i % 10 == 9:
				cs.tap()
			cs.advance(DT)
		_check(cs.finished and not asked and ts.playing() == null, "the oath replays to its end, asking for no calling, then the Tales")
	_check(game.heroes() == heroes and (game.data["seen"] as Array) == seen, "a replay changes nothing in the save")
	var tp: Node = ts.play("trials_open")
	_check(tp != null and str(tp.scene_id) == "trials_open_hollin", "a host's tale plays as it was seen (Hollin's)")
	if tp != null:
		tp.manual = true
		_drive(tp)
	_check(ts.play("world_4") == null, "an unseen tale doesn't play")
	var backs := [0]
	ts.back.connect(func(): backs[0] += 1)
	(ts._back_btn as Button).pressed.emit()
	_check(backs[0] == 1, "Back says back")
	ts.queue_free()
	game.reset()
	await process_frame
