extends SceneTree
## Build 2's level twists (scripts/twists.gd), each played in a small level
## built here, and the twist labs (levels/lab-*.txt, tools/levels/lab_twists.py):
##
##   the registry   every twist has a name (NAME_MAX) and a line (48
##                  characters at most) per world, or per level (1-3's duel is
##                  "Barbs' Loft"); an unknown id or none is no twist; a
##                  lesson is Title|Line; dry heals x0.75 (its 0 row neutral,
##                  World 4's "Cold Altars"); omens doubles the chance, keeps
##                  the max and gives the second Omen two rolls; restless
##                  raises Rattles in Worlds 1-2, the floor kinds from 3
##   unchanged      no level on the path or secret carries a twist, lesson or
##                  belt_flip header, and a World built for every one of them
##                  has no twist runtime, no painters, its own title line, no
##                  cards, the elite rules, heals and belts it always had; a
##                  mode never has a twist
##   the cards      "3-9 · Restless" over the name, then the twist's line and a
##                  lesson's in the top band, once per level and difficulty
##                  (Game.seen), never marked by the bot or in a lab; every
##                  line, every level file's lesson and title line fits the
##                  phone's band at 14 px (the spec's; fit_size goes to 10);
##                  the map shows a level's twist name under its title
##   dark           his light x0.8, floored with a douse at Dusk's 0.5
##   omens          about twice the Anointed over many seeds, never over the max
##   dry            a World 3 Dusk altar heals 0.30 (Build 1's 0.40), the
##                  flask 0.30; a World 1 altar 0.375; a lit altar burns
##                  frost-blue; the Sheet's Stats show the flask's 30%
##   packs          a Hushling pack of 3-5 (2-3 without), a Glassmite trio, a
##                  Tickwind file, a Creepbone's partner, an Unwick's pair
##   restless       a stomped Rattle's remains twitch after 3 s for 1 s and it
##                  stands again (respawned, risen), once; a risen one pays no
##                  embers or XP; a swing lays the remains to rest; never within
##                  3 tiles of him or off the glass; a snuff clears them;
##                  restless keeps to Rattles in World 1 and raises a Rootling
##                  in World 3, restless_all raises the floor kinds but a
##                  Hushling; a monster back once (a respawn) stays down; no
##                  twist, no rise
##   the clock      a sealed hold's bar (info.clock) draws gold with no damage
##                  trail, and a level-up waits out its doors
##   toll           a warning beat 15, then on beat 16 every monster in plain
##                  view is alerted (x1.3) for 4 beats, the far one not; it
##                  waits out stop_time
##   belt_flip      a run of belts flips on beat 8 after its tell, back on 16,
##                  the list stays short; a boss retry keeps the beat; no
##                  header, no flip
##   lamplit        wax by a lit lantern holds; the far run, or the near one
##                  once the lantern is out (or with no twist), shakes and falls
##
##     godot --headless --path game --script res://tests/test_twists.gd

const LevelData := preload("res://scripts/level_data.gd")
const Twists := preload("res://scripts/twists.gd")
const Combat := preload("res://scripts/combat.gd")
const Elites := preload("res://scripts/elites.gd")
const HudScript := preload("res://scripts/hud.gd")
const UI := preload("res://scripts/ui.gd")
const TILE := 32
const DT := 1.0 / 120.0
const SAVE := "user://test_twists_save.json"
const LABS := {"lab-restless": "restless", "lab-restless-all": "restless_all", "lab-toll": "toll", "lab-dark": "dark",
		"lab-omens": "omens", "lab-dry": "dry", "lab-packs": "packs", "lab-lamplit": "lamplit", "lab-lesson": ""}
# The levels on the path re-cut with their twist headers (Build 2's
# redesigns): what each carries (the keys) and its twist id.
const RECUT := {"4-1": {"lesson": true}, "4-2": {"twist": "toll", "belt_flip": true}, "4-3": {"twist": "dry"}}

var WorldScript: GDScript
var game: Node
var _passed := 0
var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	if game != null:
		game.save_path = SAVE
		for suffix in [".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
		game.reset()
		game.new_hero("knight")
	_test_registry()
	_test_labs()
	await _test_unchanged()
	await _test_cards()
	await _test_fit()
	await _test_map_and_clock()
	await _test_dark()
	await _test_omens()
	await _test_dry()
	await _test_packs()
	await _test_restless()
	await _test_toll()
	await _test_belt_flip()
	await _test_lamplit()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("test_twists: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _level(row12: String, header := "", id := "3-9", w := 60, extra := {}) -> RefCounted:
	## A flat level: row 12 as given (P for him, monsters, an altar...), stone
	## from row 13; extra: {row: text} for the rows above (a vine, a ledge).
	var rows := []
	for y in 15:
		var r := ""
		if y == 12:
			r = row12
		elif extra.has(y):
			r = str(extra[y])
		elif y >= 13:
			r = "#".repeat(w)
		rows.append(r.rpad(w, "."))
	var lv = LevelData.new()
	lv.id = id
	lv.parse("title: The Test\nsubtitle: %s\narea: 14\n" % id + header + "---\n" + "\n".join(rows))
	return lv


func _world(lv: RefCounted, diff := "dusk", monsters := true, fresh := true) -> Node2D:
	## A World for lv, headless (fresh: a new save and hero first).
	if fresh:
		game.reset()
		game.new_hero("knight")
	game.data["difficulty"] = diff
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = not monsters
	w.paused = true   # (ticked here)
	root.add_child(w)
	return w


func _ticks(w: Node2D, n: int, pad := {}) -> void:
	for i in n:
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _secs(w: Node2D, s: float, pad := {}) -> void:
	_ticks(w, roundi(s / DT), pad)


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _stand(w: Node2D, x: float, feet_row := 13) -> void:
	var pl: Node2D = w.player
	pl.reset_at(Vector2(x, feet_row * TILE))
	pl.velocity = Vector2.ZERO
	pl.on_floor = true
	pl.invuln = 9.0
	pl.hurt_time = 9.0


func _of(w: Node2D, kind: String, alive := true) -> Array:
	return w.enemies.filter(func(e): return e.kind == kind and (e.alive or not alive))


func _stomp(w: Node2D, e: Node2D) -> void:
	w.deal(e, 1.0, {"how": "stomp", "flat": 99999.0, "no_hitstop": true})


func _embers(w: Node2D) -> int:
	return w.pickups.filter(func(p): return p["kind"] == "ember" and not p["taken"]).size()


# ---------------------------------------------------------------- the registry

func _test_registry() -> void:
	var rules := ["restless", "dark", "omens", "dry", "packs", "toll", "lamplit", ""]
	for id in Twists.TWISTS:
		var t: Dictionary = Twists.TWISTS[id]
		_check(rules.has(str(t.get("rule", "-"))), "%s's rule is one the World runs (%s)" % [id, t.get("rule")])
		var cards: Dictionary = t.get("cards", {})
		_check(cards.has(0), "%s has a card for every world (row 0)" % id)
		for wn in cards:
			var c: Array = cards[wn]
			_check(c.size() == 2 and str(c[0]) != "" and str(c[1]) != "", "%s (%s) has a name and a line" % [id, wn])
			_check(str(c[1]).length() <= Twists.LINE_MAX, "%s (%s): its line is %d characters (at most %d)" % [id, wn, str(c[1]).length(), Twists.LINE_MAX])
			_check(str(c[0]).length() <= Twists.NAME_MAX, "%s (%s): its name is %d characters (at most %d)" % [id, wn, str(c[0]).length(), Twists.NAME_MAX])
	_check(Twists.card_of("dark", 6)[0] == "The Drowned Dark" and Twists.card_of("dark", 2)[0] == "Dark", "a world's own card, else row 0")
	_check(Twists.card_of("duel", 1, "1-3")[0] == "Barbs' Loft" and Twists.card_of("duel", 1, "1-2")[0] == "Duel"
			and not str(Twists.card_of("duel", 4)[1]).contains("loft"), "1-3's duel is Barbs' Loft; any other duel's card names no loft")
	_check(Twists.card_of("dry", 4)[0] == "Cold Altars" and Twists.card_of("dry", 3)[0] != "Cold Altars" and not str(Twists.card_of("dry", 2)[1]).contains("Frozen"),
			"dry: World 4's Cold Altars, a neutral card elsewhere (%s)" % [Twists.card_of("dry", 3)])
	_check(Twists.kinds_of("restless", 1) == ["skeleton"] and Twists.kinds_of("restless", 0) == ["skeleton"] and str(Twists.kinds_of("restless", 3)) == "floor"
			and str(Twists.kinds_of("restless_all", 1)) == "floor", "restless: Rattles in Worlds 1-2 (and the labs), the floor kinds from World 3")
	_check(Twists.card_of("restless", 3)[1] != Twists.card_of("restless", 1)[1], "and World 3's card says the fallen, not the bones")
	_check(Twists.id_from(" Toll ") == "toll" and Twists.id_from("restles") == "", "id_from: a header's value as an id, or none")
	_check(Twists.card_of("nope", 3).is_empty() and Twists.rule_of("nope") == "", "an unknown twist has no card and no rule")
	var lv := _level(".P", "twist:  Restless \nlesson: First Frost | Ice carries you.\n")
	_check(Twists.id_in(lv) == "restless", "the header's id is read trimmed, in any case")
	_check(Twists.lesson_in(lv) == ["First Frost", "Ice carries you."], "a lesson is Title|Line (%s)" % [Twists.lesson_in(lv)])
	_check(Twists.id_in(_level(".P", "twist: sideways\n")) == "" and Twists.id_in(_level(".P")) == "", "no header, or an unknown id: no twist")
	_check(is_equal_approx(Twists.heal_mult("dry"), 0.75) and Twists.heal_mult("dark") == 1.0 and Twists.heal_mult("") == 1.0,
			"dry heals x0.75; nothing else touches healing")
	var w3 := {"anoint": 0.12, "max_anoint": 3, "omens": 1, "second_omen": 0.2}
	var o := Twists.elite_rules("omens", w3.duplicate())
	_check(is_equal_approx(float(o["anoint"]), 0.24) and int(o["max_anoint"]) == 3 and int(o["omens"]) == 1
			and is_equal_approx(float(o["second_omen"]), 0.36), "omens: World 3's 12%% is 24%%, the max 3 kept, a second Omen 36%% (%s)" % [o])
	var o5 := Twists.elite_rules("omens", {"anoint": 0.16, "max_anoint": 3, "omens": 1, "second_omen": 0.5})
	_check(is_equal_approx(float(o5["anoint"]), 0.32) and is_equal_approx(float(o5["second_omen"]), 0.75), "omens: World 5's 16% is 32%, a second Omen 75%")
	_check(Twists.elite_rules("dry", w3.duplicate()) == w3 and Twists.elite_rules("", w3.duplicate()) == w3, "no other twist touches the elite rules")


func _test_labs() -> void:
	for lid in LABS:
		var path := "res://levels/%s.txt" % lid
		if not FileAccess.file_exists(path):
			_check(false, "%s.txt is written (tools/make_levels.py lab_twists)" % lid)
			continue
		var lv = LevelData.load_file(path)
		_check(lv.errors.is_empty(), "%s parses: %s" % [lid, ", ".join(lv.errors)])
		_check(Twists.id_in(lv) == str(LABS[lid]), "%s carries twist '%s' (%s)" % [lid, LABS[lid], Twists.id_in(lv)])
		_check(lv.count("bell") == 1 and lv.world == 0, "%s is a feel lab with a bell (world 0)" % lid)
	var lt = LevelData.load_file("res://levels/lab-toll.txt")
	var cw: Script = load("res://scripts/features/clockwork.gd")
	var flips: Array = cw.belt_flips(str(lt.headers.get("belt_flip", "")))
	var ok := flips.size() == 2
	for f in flips:
		for x in range(int(f["x0"]), int(f["x1"]) + 1):
			ok = ok and LevelData.is_belt(lt.tile(x, 13))
	_check(ok and int(flips[0]["every"]) == 8, "lab-toll's belt_flip names its two runs of belts, every 8 beats (%s)" % [flips])
	_check(Twists.lesson_in(LevelData.load_file("res://levels/lab-lesson.txt")).size() == 2, "lab-lesson carries a lesson card")


# ---------------------------------------------------------------- today's levels

func _test_unchanged() -> void:
	## The re-cut levels (RECUT) carry the twist or lesson card the redesign
	## gave each, and their Worlds play it; every other level carries none
	## yet, and its World plays exactly as before.
	var ids := []
	for f in DirAccess.get_files_at("res://levels"):
		if f.ends_with(".txt") and not f.begins_with("lab-"):
			ids.append(f.get_basename())
	ids.sort()
	var bare := true
	for id in ids:
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		var mine: Dictionary = RECUT.get(id, {})
		for k in ["twist", "lesson", "belt_flip"]:
			if lv.headers.has(k) != mine.has(k):
				bare = false
				print("  %s %s a %s header" % [id, "has" if lv.headers.has(k) else "lacks", k])
		if mine.has("twist") and Twists.id_in(lv) != str(mine["twist"]):
			bare = false
			print("  %s's twist is '%s', not '%s'" % [id, Twists.id_in(lv), mine["twist"]])
	_check(bare and ids.size() >= 30, "no level on the path or secret carries a twist, lesson or belt_flip header but the re-cut ones, each its own (%s; %d levels)" % [RECUT.keys(), ids.size()])
	for id in RECUT:
		if not ids.has(id):
			continue
		var w := _world(LevelData.load_file("res://levels/%s.txt" % id))
		await process_frame
		var want: Dictionary = RECUT[id]
		var ok: bool = w.twist_id() == str(want.get("twist", "")) and not w.twist_cards().is_empty()
		if want.has("belt_flip"):
			ok = ok and not (w.features.module("clockwork").flips as Array).is_empty()
		_check(ok, "%s: its World plays its own (twist '%s', %d cards)" % [id, w.twist_id(), w.twist_cards().size()])
		await _done(w)
	ids = ids.filter(func(i): return not RECUT.has(i))
	var same := 0
	for id in ids:
		var w := _world(LevelData.load_file("res://levels/%s.txt" % id))
		await process_frame
		var ok: bool = w.twists == null and w.twist_id() == "" and w.title_sub() == w.level.subtitle and w.twist_cards().is_empty()
		ok = ok and w.get_node_or_null("TwistUnder") == null and w.twist_heal() == 1.0
		ok = ok and w.elite_rules() == Combat.elite_rules(w.diff, w.world_n, true)
		ok = ok and is_equal_approx(w.flask_heal(), float(game.flask_heal(w.diff)))
		ok = ok and (w.features.module("clockwork") == null or w.features.module("clockwork").flips.is_empty())
		for rule in ["restless", "dark", "omens", "dry", "packs", "toll", "lamplit"]:
			ok = ok and not w.twist(rule)
		if ok:
			same += 1
		else:
			print("  %s: a twist leaked in" % id)
		await _done(w)
	_check(same == ids.size(), "a World for every level without the header has no twist: no runtime, painters, card, rule or change (%d of %d)" % [same, ids.size()])
	# A mode never has one, whatever the header says.
	var w := _world(_level(".P...s", "twist: dark\n"))
	await process_frame
	_check(w.twist("dark") and w.twists != null, "(a story level reads its twist)")
	w.mode = RefCounted.new()
	_check(w.twist_id() == "" and not w.twist("dark") and w.title_sub() == "3-9" and w.twist_heal() == 1.0, "in a mode the twist is off: no rule, no card")
	w.mode = null
	await _done(w)


# ---------------------------------------------------------------- the cards

func _test_cards() -> void:
	var w := _world(_level(".P", "twist: restless_all\n"), "dusk", false)
	await process_frame
	_check(w.title_sub() == "3-9 · Restless", "the title card's line names the twist: '%s'" % w.title_sub())
	_check(w.twist_cards() == [["twist:3-9:dusk", "Restless", "The fallen rise once. Strike their remains."]],
			"then a card gives its line (%s)" % [w.twist_cards()])
	await _done(w)
	w = _world(_level(".P", "lesson: First Frost|Ice carries you. Walls stop what slides.\n", "4-9"), "nightfall", false)
	await process_frame
	_check(w.title_sub() == "4-9" and w.twist_cards() == [["twist:4-9:nightfall:lesson", "First Frost", "Ice carries you. Walls stop what slides."]],
			"a lesson keeps the plain line and gives its card (%s)" % [w.twist_cards()])
	await _done(w)
	w = _world(_level(".P", "twist: dark\n", "6-9"), "dusk", false)
	await process_frame
	_check(w.title_sub() == "6-9 · The Drowned Dark", "a world's own name (%s)" % w.title_sub())
	await _done(w)
	# Through the HUD: queued once per level and difficulty; the bot and a lab never mark it.
	game.reset()
	game.new_hero("knight")
	for case in ["player", "again", "nightfall", "autoplay", "lab"]:
		var lv := _level(".P", "twist: toll\n", {"lab": "lab-tw", "autoplay": "4-8"}.get(case, "4-9"))
		var diff := "nightfall" if case == "nightfall" else "dusk"
		w = _world(lv, diff, false, false)
		await process_frame
		var hud = HudScript.new()
		hud.world = w
		hud._story_checked = true
		w.hud = hud
		w.add_child(hud)
		await process_frame
		w.autoplay = case == "autoplay"
		var id := "twist:%s:%s" % [lv.id, diff]
		w._twist_cards()
		var queued: bool = hud._cardq.any(func(c): return str(c["id"]) == id)
		match case:
			"player", "nightfall":
				_check(queued and game.seen(id), "%s: the twist's card is queued under the title and marked seen" % case)
			"again":
				_check(not queued, "seen once on this difficulty: not again")
			_:
				_check(queued and not game.seen(id), "%s: the card shows, nothing is marked" % case)
		w.hud = null
		hud.queue_free()
		await _done(w)


func _test_fit() -> void:
	## Every twist's line, every level file's lesson (and an example's), and
	## every "6-3 · Name" title line fit the band at 14 px on the phone's
	## three sizes (the spec's size; fit_size would go down to 10), their
	## names at 22 px or more (the band's 26 px title).
	var lines := []
	for id in Twists.TWISTS:
		for wn in Twists.TWISTS[id]["cards"]:
			lines.append(Twists.TWISTS[id]["cards"][wn])
	lines.append(["First Frost", "Ice carries you. Walls stop what slides."])
	for f in DirAccess.get_files_at("res://levels"):
		if f.ends_with(".txt"):
			var l := Twists.lesson_in(LevelData.load_file("res://levels/" + f))
			if not l.is_empty():
				lines.append(l)
	var old_size := root.size
	var old_cs := root.content_scale_size
	var old_safe: Rect2 = UI.safe_override
	for size in [Vector2i(847, 390), Vector2i(844, 390), Vector2i(780, 390)]:
		root.size = size
		root.content_scale_size = size
		UI.safe_override = UI.phone_safe(Vector2(size))
		await process_frame
		var sw := _stub_world()
		root.add_child(sw)
		var hud = HudScript.new()
		hud.world = sw
		sw.add_child(hud)
		await process_frame
		var worst := 99
		var worst_name := 99
		var sub_ok := true
		for c in lines:
			var r: Rect2 = hud.band_card_rect(str(c[0]), str(c[1]))
			worst = mini(worst, UI.fit_size(str(c[1]), r.size.x - 24.0, 14, 10))
			worst_name = mini(worst_name, UI.fit_size(str(c[0]), r.size.x - 24.0, 26, 16, "title", 700))
			var s: Rect2 = UI.safe_override
			var room: float = r.size.x if r.size.x > 0.0 else s.size.x
			sub_ok = sub_ok and UI.text_width("6-3 · %s" % c[0], 20, "body", 700) <= maxf(room, hud.title_rect(str(c[0])).size.x)
			sub_ok = sub_ok and r.position.x >= s.position.x and r.end.x <= s.end.x
		_check(worst >= 14, "every twist's and lesson's line fits the band at %d px (14, the spec's; %d wide)" % [worst, size.x])
		_check(worst_name >= 22, "every card's name fits at %d px (22 or more of the band's 26; %d wide)" % [worst_name, size.x])
		_check(sub_ok, "every title line '6-3 · Name' and card stays in the band (%d wide)" % size.x)
		sw.queue_free()
		await process_frame
	root.size = old_size
	root.content_scale_size = old_cs
	UI.safe_override = old_safe
	await process_frame


func _test_map_and_clock() -> void:
	## The map names a level's twist under its title (map_screen.gd:
	## twist_name_of, its line and the sigils under it); a sealed hold's
	## clock bar draws gold with no damage trail, and a level-up waits out
	## its doors.
	var Map = load("res://scripts/map_screen.gd")
	_check(Map.twist_name_of({"twist": "toll"}, 4, "4-2") == "On the Hour" and Map.twist_name_of({"twist": "duel"}, 1, "1-3") == "Barbs' Loft"
			and Map.twist_name_of({"twist": "dry"}, 4, "4-3") == "Cold Altars" and Map.twist_name_of({}, 4, "4-1") == ""
			and Map.twist_name_of({"twist": "restles"}, 3, "3-2") == "", "the map's twist names: 4-2 On the Hour, 1-3 Barbs' Loft, none without")
	var m = Map.new()
	m._info = [{"twist": "On the Hour"}, {"twist": ""}]
	_check(m.twist_line_y(0) > 0.0 and m.twist_line_y(1) == 0.0, "a medallion with a twist draws its name under the title; one without, nothing")
	m.free()
	var sw := _stub_world()
	root.add_child(sw)
	var hud = HudScript.new()
	hud.world = sw
	sw.add_child(hud)
	await process_frame
	hud.boss_bar({"id": "room", "name": "Hold · 0:20", "title": "4 left", "frac": 1.0, "awake": true, "clock": true})
	_check((hud.bar_fill()[0] as Color).r > 0.8 and (hud.bar_fill()[0] as Color).g > 0.55, "a clock bar fills gold (%s)" % hud.bar_fill()[0])
	hud.level_up(9)
	_check(hud._lvl.is_empty() and not hud._lvl_held.is_empty() and not hud.top_card_showing(), "a level-up while the clock runs waits (the bar stays up)")
	hud._process(0.1)
	_check(hud._lvl.is_empty(), "(still waiting while it runs)")
	hud.boss_bar({})
	hud._process(0.1)
	_check(not hud._lvl.is_empty() and int(hud._lvl["n"]) == 9 and hud._lvl_held.is_empty(), "the doors open: its card comes (%s)" % [hud._lvl])
	hud.boss_bar({"id": "boss", "name": "Old Tollgrave", "frac": 1.0, "awake": true})
	_check((hud.bar_fill()[0] as Color).r > 0.7 and (hud.bar_fill()[0] as Color).g < 0.3, "a life bar stays red")
	sw.queue_free()
	await process_frame


func _stub_world() -> Node:
	## Just what the HUD reads (test_screens' stand-in): a player's numbers,
	## embers, sigils, the boss, the touch layer.
	var ps := GDScript.new()
	ps.source_code = "extends Node2D\nvar hp := 84.0\nvar max_hp := 120.0\nvar res := 50.0\nvar res_max := 100.0\nvar stats := {\"cls\": \"knight\"}\nfunc life_frac():\n\treturn hp / max_hp\n"
	ps.reload()
	var ws := GDScript.new()
	ws.source_code = "extends Node\nvar player\nvar embers_carried := 0\nvar embers_got := 0\nvar flask_charges := 1\nvar sigils_got := [false, false, false]\nvar boss = null\nvar touch = null\nvar hud = null\nvar paused := false\nvar pickups := []\nfunc undo_equip(_it):\n\tpass\nfunc apply_hero():\n\tpass\n"
	ws.reload()
	var w: Node = ws.new()
	w.player = ps.new()
	w.add_child(w.player)
	return w


# ---------------------------------------------------------------- dark

func _test_dark() -> void:
	var w := _world(_level(".P"), "dusk", false)
	await process_frame
	var r0: float = w.hero_light_radius()
	_check(is_equal_approx(w.dim_mult(), 1.0), "(no twist: no dim)")
	await _done(w)
	w = _world(_level(".P", "twist: dark\n"), "dusk", false)
	await process_frame
	_ticks(w, 2)
	_check(absf(w.dim_mult() - Twists.DARK) < 0.001, "dark: his light x0.8 (%.3f)" % w.dim_mult())
	_check(absf(w.hero_light_radius() - r0 * Twists.DARK) < 1.0, "his radius %.0f of %.0f" % [w.hero_light_radius(), r0])
	w.player.apply_status("douse", 2.0)
	_check(absf(w.dim_mult() - Combat.dim_floor("dusk")) < 0.001, "a douse on top floors at Dusk's 0.5 (%.3f)" % w.dim_mult())
	w.player.status.clear()
	_secs(w, 30.0)
	_check(absf(w.dim_mult() - Twists.DARK) < 0.001, "and it holds all level (%.3f after 30 s)" % w.dim_mult())
	await _done(w)


# ---------------------------------------------------------------- omens

func _test_omens() -> void:
	# Six Rattles 22 tiles apart, far from the start: the same World picks with
	# and without the twist over 200 seeds.
	var row := ".P" + ".".repeat(20)
	for i in 6:
		row += "s" + ".".repeat(21)
	var w := _world(_level(row, "twist: omens\n", "3-9", row.length() + 4))
	await process_frame
	var rr := RandomNumberGenerator.new()
	var with := 0
	var without := 0
	var most := 0
	for seed in 200:
		rr.seed = seed
		w._twist_id = "omens"
		var a: Array = Elites.pick_elites(w, w.level, rr)
		w._twist_id = ""
		var b: Array = Elites.pick_elites(w, w.level, rr)
		with += a.size()
		without += b.size()
		most = maxi(most, a.size())
	w._twist_id = "omens"
	var rules: Dictionary = w.elite_rules()
	_check(is_equal_approx(float(rules["anoint"]), 0.24) and int(rules["max_anoint"]) == 3, "omens in World 3: 24%%, at most 3 (%s)" % [rules])
	_check(with >= int(without * 1.6) and with > without, "about twice the Anointed over 200 seeds (%d against %d)" % [with, without])
	_check(most <= int(rules["max_anoint"]), "never more than the max in a level (%d)" % most)
	await _done(w)


# ---------------------------------------------------------------- dry

func _altar_heal(lv: RefCounted) -> Array:
	var w := _world(lv, "dusk", false)
	await process_frame
	var pl: Node2D = w.player
	pl.hp = pl.max_hp * 0.1
	w._light_altar(w.altars[0])
	var healed: float = (pl.hp - pl.max_hp * 0.1) / pl.max_hp
	var flask: float = w.flask_heal()
	await _done(w)
	return [healed, flask]


func _test_dry() -> void:
	var plain: Array = await _altar_heal(_level(".P....K", "", "3-9"))
	var dry: Array = await _altar_heal(_level(".P....K", "twist: dry\n", "3-9"))
	_check(absf(float(plain[0]) - 0.40) < 0.005, "(a World 3 Dusk altar heals Build 1's 0.40: %.3f)" % plain[0])
	_check(absf(float(dry[0]) - 0.30) < 0.005, "dry: a World 3 Dusk altar heals 0.30 (%.3f)" % dry[0])
	_check(absf(float(plain[1]) - 0.40) < 0.005 and absf(float(dry[1]) - 0.30) < 0.005, "and the flask 0.30, not 0.40 (%.3f)" % dry[1])
	var dry1: Array = await _altar_heal(_level(".P....K", "twist: dry\n", "1-9"))
	_check(absf(float(dry1[0]) - 0.375) < 0.005, "a World 1 altar 0.375 (of 0.50)")
	# Against the 1-2 snuff target (4-3's plan: five altars, each refilling the
	# one Dusk draught): what the level gives back, against today's four.
	var back := 5.0 * (float(dry[0]) + float(dry[1]))
	var today := 4.0 * (float(plain[0]) + float(plain[1]))
	print("  dry's budget: 5 stretches x (altar %.2f + draught %.2f) = %.2f lives back; today's 4-3: 4 x (%.2f + %.2f) = %.2f" % [
			dry[0], dry[1], back, plain[0], plain[1], today])
	_check(back <= today, "dry gives back no more over a five-altar level than today's four (%.2f against %.2f)" % [back, today])
	# What it looks like: a lit altar burns frost-blue (its sprite; glow.gd
	# draws its flame FROST_FLAME), only under dry; the Sheet's Stats over the
	# paused level show the flask as the World pours it.
	var tint := []
	for hd in ["twist: dry\n", ""]:
		var w := _world(_level(".P....K", hd, "4-9"), "dusk", false)
		await process_frame
		w._light_altar(w.altars[0])
		tint.append((w.altars[0]["sprite"] as CanvasItem).modulate)
		if hd != "":
			var sheet = load("res://scripts/hero_screen.gd").new()
			sheet.world = w
			var sp = load("res://scripts/stats_panel.gd").new()
			sp.host = sheet
			var flask: Array = (sp.rows() as Array).filter(func(r): return str(r[0]) == "Flask")
			_check(not flask.is_empty() and str(flask[0][1]).ends_with("%d%%" % roundi(w.flask_heal() * 100.0)) and roundi(w.flask_heal() * 100.0) == 30,
					"the Sheet's Stats in a dry level show the flask's 30%% (%s)" % [flask])
			sp.free()
			sheet.free()
		await _done(w)
	_check(tint[0] == Twists.FROST and tint[1] == Color.WHITE, "a lit altar burns frost-blue under dry, and only then (%s, %s)" % tint)
	var Glow = load("res://scripts/glow.gd")
	_check((Glow.FROST_FLAME as Dictionary).has("core") and (Glow.FROST_FLAME["mid"] as Color).b > (Glow.FROST_FLAME["mid"] as Color).r,
			"its flame's palette is blue (glow.gd FROST_FLAME)")


# ---------------------------------------------------------------- packs

func _count_after(lv: RefCounted, kind: String, secs := 1.0) -> int:
	var w := _world(lv)
	await process_frame
	_stand(w, 2.5 * TILE)
	_secs(w, secs)
	var n := _of(w, kind).size()
	await _done(w)
	return n


func _test_packs() -> void:
	var hush := ".P........" + "n" + ".".repeat(40)
	var with_n: int = await _count_after(_level(hush, "twist: packs\n", "6-9"), "hushling")
	var without_n: int = await _count_after(_level(hush, "", "6-9"), "hushling")
	_check(with_n >= 3 and with_n <= 5, "packs: a Hushling leader brings its pack to 3-5 on Dusk (%d)" % with_n)
	_check(without_n >= 2 and without_n <= 3, "(without: 2-3, %d)" % without_n)
	var mite := ".P........" + "x" + ".".repeat(40)
	_check(await _count_after(_level(mite, "twist: packs\n", "5-9"), "glassmite") == 3, "a Glassmite comes as a trio")
	_check(await _count_after(_level(mite, "", "5-9"), "glassmite") == 1, "(alone without the twist on Dusk)")
	var vine := {}
	for y in range(6, 12):
		vine[y] = ".".repeat(20) + "{"
	vine[9] = ".".repeat(20) + "i"
	var creep := ".P" + ".".repeat(18) + "{" + ".".repeat(30)
	_check(await _count_after(_level(creep, "twist: packs\n", "3-9", 60, vine), "creepbone") == 2, "a Creepbone brings its lane partner")
	_check(await _count_after(_level(creep, "", "3-9", 60, vine), "creepbone") == 1, "(alone without)")
	var unw := ".P........" + "6" + ".".repeat(40)
	_check(await _count_after(_level(unw, "twist: packs\n", "6-9"), "unwick") == 2, "an Unwick comes in a pair")
	_check(await _count_after(_level(unw, "", "6-9"), "unwick") == 1, "(alone without)")
	# Tickwinds: the first within sight (230 px), the second 32 px behind it
	# (past its own sight): it winds with the first as a file.
	for packs in [true, false]:
		var row := ".P" + ".".repeat(7) + "jj" + ".".repeat(40)
		var w := _world(_level(row, "twist: packs\n" if packs else "", "4-9"))
		await process_frame
		var ts := _of(w, "tickwind")
		ts.sort_custom(func(a, b): return a.position.x < b.position.x)
		_stand(w, ts[0].position.x - 230.0)
		var second := ""
		for i in 360:
			_ticks(w, 1)
			if str(ts[0].state) == "wind":
				second = str(ts[1].state)
				break
		_check(second == ("wind" if packs else "march"), "packs %s: the Tickwind behind %s (%s)" % [packs, "winds with it as a file" if packs else "marches on", second])
		await _done(w)


# ---------------------------------------------------------------- restless

func _restless(header: String, row: String, id := "1-9") -> Node2D:
	var w := _world(_level(row, header, id, 100))
	await process_frame
	_stand(w, 2.5 * TILE)
	_ticks(w, 6)
	return w


func _test_restless() -> void:
	var row := ".P" + ".".repeat(18) + "s" + ".".repeat(9) + "r" + ".".repeat(9) + "s" + ".".repeat(9) + "n" + ".".repeat(11) + "s" + ".".repeat(20)
	var w: Node2D = await _restless("twist: restless\n", row)
	var tw: RefCounted = w.twists
	_check(tw != null and tw.rule == "restless", "restless has its runtime")
	var rattles := _of(w, "skeleton")
	rattles.sort_custom(func(a, b): return a.position.x < b.position.x)
	var r0: Node2D = rattles[0]
	_stand(w, r0.position.x - 200.0)
	_ticks(w, 2)
	var xp0: int = w.xp_gained
	var cell0: Vector2i = r0.spawn["cell"]
	_stomp(w, r0)
	_check(tw.remains.size() == 1, "a stomped Rattle leaves its remains")
	var at: Vector2 = tw.remains[0]["pos"] if tw.remains.size() == 1 else Vector2.ZERO
	_check(absf(at.x - r0.position.x) < 1.0 and absf(at.y - 13.0 * TILE) < 0.5, "where it fell, on the floor (%s)" % at)
	_secs(w, Twists.RISE_WAIT - 0.1)
	_check(float(tw.remains[0]["tell"]) < 0.0, "they lie still for 3 s")
	_secs(w, 0.2)
	_check(not tw.remains.is_empty() and float(tw.remains[0]["tell"]) >= 0.0, "then twitch (the tell)")
	_secs(w, Twists.RISE_TELL - 0.2)
	_check(tw.remains.size() == 1 and tw.risen == 0, "for a whole second before it stands")
	_secs(w, 0.2)
	var up := _of(w, "skeleton").filter(func(e): return Twists.is_risen(e))
	_check(up.size() == 1 and tw.remains.is_empty() and tw.risen == 1, "then it stands again where it fell")
	if up.size() == 1:
		var e: Node2D = up[0]
		_check(e.respawned and absf(e.position.x - at.x) < 16.0 and e.spawn["cell"] == cell0,
				"as a respawn, on its spot, from its own cell (%s at %s, fell at %s; cell %s of %s)" % [e.respawned, e.position, at, e.spawn["cell"], cell0])
		var xp1: int = w.xp_gained
		var em: int = _embers(w)
		_stomp(w, e)
		_check(tw.remains.is_empty(), "a risen one never rises again")
		_check(w.xp_gained == xp1 and _embers(w) == em, "and pays nothing: no XP, no embers (%d -> %d xp)" % [xp1, w.xp_gained])
	_check(w.xp_gained > xp0, "(the first stomp paid as ever)")
	# A swing lays the next one to rest.
	var r1: Node2D = rattles[1]
	_stand(w, r1.position.x - 200.0)
	_ticks(w, 2)
	_stomp(w, r1)
	_check(tw.remains.size() == 1, "(the second's remains)")
	_stand(w, float(tw.remains[0]["pos"].x) - 30.0)
	w.player.facing = 1
	_ticks(w, 3, {"attack": true})
	_ticks(w, 30)
	_check(tw.remains.is_empty() and tw.laid == 1, "a swing on the remains lays them to rest")
	_secs(w, 6.0)
	_check(_of(w, "skeleton").filter(func(e): return Twists.is_risen(e)).is_empty() and tw.risen == 1, "and nothing gets up")
	# The Rootling stays down under restless (Rattles only).
	var root_e: Node2D = _of(w, "rootling")[0]
	_stand(w, root_e.position.x - 200.0)
	_ticks(w, 2)
	_stomp(w, root_e)
	_check(tw.remains.is_empty(), "restless (World 1's) raises Rattles only: a Rootling stays down")
	# A Rattle back once already (a respawn: a snuff's, the World's, a sealed
	# room's reset) stays down when stomped: a retry costs no more stomps.
	var again: Node2D = w.spawn_enemy("skeleton", Vector2(root_e.position.x + 64.0, 13 * TILE), {"cell": cell0, "respawned": true})
	_ticks(w, 2)
	_stomp(w, again)
	_check(tw.remains.is_empty(), "a respawned Rattle, stomped, stays down")
	await _done(w)
	# World 3's restless raises every ordinary floor kind (3-2's).
	w = await _restless("twist: restless\n", row, "3-9")
	tw = w.twists
	var rt3: Node2D = _of(w, "rootling")[0]
	_stand(w, rt3.position.x - 200.0)
	_ticks(w, 2)
	_stomp(w, rt3)
	_check(tw.remains.size() == 1, "restless in World 3: a stomped Rootling's remains wait too (%d)" % tw.remains.size())
	await _done(w)
	# Never within 3 tiles of him, and never off the glass.
	w = await _restless("twist: restless\n", row)
	tw = w.twists
	rattles = _of(w, "skeleton")
	rattles.sort_custom(func(a, b): return a.position.x < b.position.x)
	_stand(w, rattles[0].position.x - 40.0)
	_ticks(w, 2)
	_stomp(w, rattles[0])
	_secs(w, 6.0)
	_check(tw.risen == 0 and tw.remains.size() == 1, "standing 40 px off (the tell runs), it doesn't get up while he's that near")
	_stand(w, float(tw.remains[0]["pos"].x) - 160.0)
	_ticks(w, 4)
	_check(tw.risen == 1, "and it does as soon as he's 3 tiles off")
	_stand(w, rattles[1].position.x - 200.0)
	_ticks(w, 2)
	_stomp(w, rattles[1])
	_stand(w, rattles[1].position.x + 1400.0)
	_ticks(w, 2)
	_secs(w, 8.0)
	_check(tw.risen == 1 and tw.remains.size() == 1 and float(tw.remains[0]["tell"]) < 0.0, "off the glass it never starts its tell")
	_stand(w, float(tw.remains[0]["pos"].x) - 200.0)
	_secs(w, 0.5)   # (the camera comes back with him)
	var waited := float(tw.remains[0]["tell"]) if tw.remains.size() == 1 else -9.0
	_secs(w, Twists.RISE_TELL + 0.1)
	_check(waited >= 0.0 and waited < Twists.RISE_TELL and tw.risen == 2 and tw.remains.is_empty(),
			"back on the glass, it twitches its second and stands (tell %.2f s in)" % waited)
	# A snuff lays the waiting ones to rest.
	var r2: Node2D = _of(w, "skeleton").filter(func(e): return not Twists.is_risen(e))[0] if _of(w, "skeleton").any(func(e): return not Twists.is_risen(e)) else null
	if r2 == null:
		_check(false, "(a third Rattle to stomp)")
	else:
		_stand(w, r2.position.x - 200.0)
		_ticks(w, 2)
		_stomp(w, r2)
		_check(tw.remains.size() == 1, "(its remains)")
		w.player.invuln = 0.0
		w.player.hp = 1.0
		w.hurt_player(50.0, w.player.position.x + 20.0, "hit")
		_check(w.state == "dead", "(snuffed)")
		_secs(w, 2.0)
		_check(w.state == "play" and tw.remains.is_empty(), "a snuff lays the waiting remains to rest")
	await _done(w)
	# restless_all: every ordinary floor kind but a Hushling.
	w = await _restless("twist: restless_all\n", row, "3-9")
	tw = w.twists
	var rt: Node2D = _of(w, "rootling")[0]
	_stand(w, rt.position.x - 200.0)
	_ticks(w, 2)
	_stomp(w, rt)
	_check(tw.remains.size() == 1, "restless_all: a stomped Rootling's remains wait too")
	tw.remains.clear()
	var hs: Node2D = _of(w, "hushling")[0] if not _of(w, "hushling").is_empty() else null
	if hs != null:
		_stomp(w, hs)
		_check(tw.remains.is_empty(), "but not a Hushling's (a pack bringer)")
	var r3: Node2D = _of(w, "skeleton")[0]
	w.deal(r3, 1.0, {"how": "slash", "flat": 99999.0, "no_hitstop": true})
	_check(tw.remains.is_empty(), "and a blade's kill stays down")
	await _done(w)
	# No twist: nothing waits, nothing rises.
	w = await _restless("", row)
	_check(w.twists == null, "(no twist: no runtime)")
	var rr: Node2D = _of(w, "skeleton")[0]
	_stand(w, rr.position.x - 200.0)
	_ticks(w, 2)
	_stomp(w, rr)
	_secs(w, 6.0)
	_check(_of(w, "skeleton").filter(func(e): return e.respawned).is_empty(), "without the header a stomped Rattle stays down")
	await _done(w)
	# The real stomp, through the World's touch.
	w = await _restless("twist: restless\n", row)
	tw = w.twists
	var rs: Node2D = _of(w, "skeleton")[0]
	w.player.reset_at(rs.position + Vector2(0, -60))
	w.player.velocity = Vector2(0, 200)
	for i in 60:
		rs.active = true
		_ticks(w, 1)
		if not rs.alive:
			break
	_check(not rs.alive and tw.remains.size() == 1, "a real stomp from above leaves the remains too")
	await _done(w)


# ---------------------------------------------------------------- the toll

func _test_toll() -> void:
	var row := ".P" + ".".repeat(8) + "s" + ".".repeat(6) + "s" + ".".repeat(60) + "s" + ".".repeat(10)
	var w := _world(_level(row, "twist: toll\n", "4-9", 100))
	await process_frame
	var tw: RefCounted = w.twists
	_stand(w, 3.5 * TILE)
	var rattles := _of(w, "skeleton")
	rattles.sort_custom(func(a, b): return a.position.x < b.position.x)
	var tick: float = w.level.tick
	var warned := false
	while w.ftime < 15.0 * tick + 0.02:
		_ticks(w, 1)
		_stand(w, 3.5 * TILE)
	warned = tw.warning()
	_check(warned and tw.tolls == 0, "the beat before the toll is its warning (beat 15 of 16)")
	_check(not rattles[0].status.has("alerted"), "(nothing quickened yet)")
	while w.ftime < 16.0 * tick + 0.02:
		_ticks(w, 1)
		_stand(w, 3.5 * TILE)
	_check(tw.tolls == 1, "the bell tolls on beat 16")
	var near_ok: bool = rattles[0].status.has("alerted") and rattles[1].status.has("alerted")
	_check(near_ok and absf(float(rattles[0].status.get("alerted", 0.0)) - 4.0 * tick) < 0.05, "everything in plain view runs faster for 4 beats (%.2f s)" % float(rattles[0].status.get("alerted", 0.0)))
	_check(not rattles[2].status.has("alerted"), "the one far off the glass doesn't")
	_check(is_equal_approx(rattles[0].spd(10.0), 10.0 * Elites.ALERT_SPEED), "x1.3 (elites.gd's alert: speed only, the tells untouched)")
	_secs(w, 4.0 * tick + 0.05)
	_check(not rattles[0].status.has("alerted"), "and back to its pace after them")
	# stop_time holds the clock: no toll while it's stopped.
	while w.ftime < 31.5 * tick:
		_ticks(w, 1)
	w.stop_time(2.0)
	_secs(w, 1.5)
	_check(tw.tolls == 1, "stop_time holds the toll with everything else")
	_secs(w, 1.0)
	_check(tw.tolls == 2, "and it tolls once the clock runs again")
	_check(tw.log_extra() == {"twist": "toll", "tolls": 2}, "the playlog line counts the tolls (%s)" % [tw.log_extra()])
	await _done(w)


# ---------------------------------------------------------------- belt_flip

func _belt_level(header: String) -> RefCounted:
	return _level(".P", header, "4-9", 40, {13: "#####" + ">".repeat(10) + "#".repeat(25)})


func _test_belt_flip() -> void:
	var w := _world(_belt_level("belt_flip: 5-14=8\n"), "dusk", false)
	await process_frame
	var cw = w.features.module("clockwork")
	var tick: float = w.level.tick
	var c := Vector2i(8, 13)
	_check(cw.flips.size() == 1 and int(cw.flips[0]["every"]) == 8, "the header's run is read (%s)" % [cw.flips])
	while w.ftime < 8.0 * tick - 0.7:
		_ticks(w, 1)
	_check(w.belt_dir(c, 1) == 1 and cw.belts_rev.is_empty(), "(no flip yet)")
	while w.ftime < 8.0 * tick - 0.3:
		_ticks(w, 1)
	_check(w.belt_dir(c, 1) == 1 and not cw.belts_rev.is_empty() and not cw.belts_rev[0]["done"], "its tell runs before the beat")
	while w.ftime < 8.0 * tick + 0.02:
		_ticks(w, 1)
	_check(w.belt_dir(c, 1) == -1, "the belts flip on beat 8")
	while w.ftime < 16.0 * tick + 0.02:
		_ticks(w, 1)
	_check(w.belt_dir(c, 1) == 1 and cw.belts_rev.is_empty(), "and back on beat 16, the two flips gone from the list")
	while w.ftime < 64.0 * tick + 0.02:
		_ticks(w, 1)
	_check(w.belt_dir(c, 1) == 1 and cw.belts_rev.size() <= 1, "the list stays short over a long run (%d)" % cw.belts_rev.size())
	while w.ftime < 72.0 * tick + 0.02:
		_ticks(w, 1)
	cw.on_boss_reset()
	_check(w.belt_dir(c, 1) == -1, "a boss retry keeps the beat (flipped on an odd flip)")
	await _done(w)
	w = _world(_belt_level(""), "dusk", false)
	await process_frame
	_secs(w, 12.0)
	_check(w.belt_dir(c, 1) == 1 and w.features.module("clockwork").flips.is_empty(), "no header: the belts never flip")
	await _done(w)
	# With the toll on the same clock, every toll lands on a flip.
	_check(Twists.TOLL_EVERY % 8 == 0, "a toll every 16 beats lands on every second flip of an 8-beat run")


# ---------------------------------------------------------------- lamplit

func _wax_level(header: String) -> RefCounted:
	## A lantern at x 8, soft wax beside it (x 9-11) and far off (x 30-32), on row 11.
	return _level(".P......L" + ".".repeat(51), header, "2-9", 60, {11: ".".repeat(9) + "%%%" + ".".repeat(18) + "%%%"})


func _on_wax(w: Node2D, x: int) -> String:
	## He stands on the ledge cell (x, 11) a second: its state after.
	var pl: Node2D = w.player
	pl.reset_at(Vector2((x + 0.5) * TILE, 11 * TILE))
	pl.velocity = Vector2.ZERO
	for i in 6:
		_ticks(w, 1)
	var st := str(w.crumbles[Vector2i(x, 11)]["state"])
	_secs(w, 1.0)
	return st if st != "idle" else str(w.crumbles[Vector2i(x, 11)]["state"])


func _test_lamplit() -> void:
	var w := _world(_wax_level("twist: lamplit\n"), "dusk", false)
	await process_frame
	var l: Dictionary = w.features.lanterns[0]
	w.features.light(l)
	_check(bool(l["lit"]) and w.twists.holds_crumble(Vector2i(11, 11)) and not w.twists.holds_crumble(Vector2i(30, 11)),
			"lamplit: the wax within %d px of the lit lantern is set; the far run isn't" % int(Twists.LAMP_R))
	_check(_on_wax(w, 10) == "idle", "standing on lamplit wax, it holds firm")
	_check(_on_wax(w, 31) != "idle", "the far run shakes and falls")
	w.features.put_out(l)
	for i in 20:
		_ticks(w, 1)
	_check(_on_wax(w, 10) != "idle", "the lantern out, the near wax is soft again")
	await _done(w)
	w = _world(_wax_level(""), "dusk", false)
	await process_frame
	w.features.light(w.features.lanterns[0])
	_check(_on_wax(w, 10) != "idle", "without the twist a lit lantern holds nothing")
	await _done(w)
