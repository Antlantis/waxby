# Screenshots of every screen and the in-level HUD, for checking by eye.
#   godot --path game --resolution 1266x585 --audio-driver Dummy \
#       --script res://../tools/shot_screens.gd -- <out_dir> [safe] [sets]
# safe: "both" (the phone's island inset on both sides, as iOS reports it),
#       "left" / "right" (the inset on that side only), "none" (plain margins).
# sets: a comma list of title, map, sheet, chandler, pause, results, hud,
#       cards, boss, touch (default: all of them).
# Files are <out_dir>/<W>x<H>_<safe>_<name>.png. The shots keep their own save
# (user://shots_save.json), so a real save is never touched.
extends SceneTree

const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]

var UI
var Items
var Hero
var Progression
var Story
var game: Node
var _out := "/tmp"
var _safe := "both"
var _tag := ""
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	_safe = args[1] if args.size() > 1 else "both"
	var sets: Array = Array(args[2].split(",")) if args.size() > 2 else ["all"]
	DirAccess.make_dir_recursive_absolute(_out)
	UI = load("res://scripts/ui.gd")
	Items = load("res://scripts/items.gd")
	Hero = load("res://scripts/hero.gd")
	Progression = load("res://scripts/progression.gd")
	Story = load("res://scripts/story.gd")
	_rng.seed = 7
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shots_save.json"
	game.settings_path = "user://shots_settings.json"
	for p in [game.save_path, game.settings_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	game.reset()
	await process_frame
	var vs: Vector2 = root.get_visible_rect().size
	UI.safe_override = _safe_rect(vs)
	var win := DisplayServer.window_get_size()
	_tag = "%dx%d_%s" % [win.x, win.y, _safe]
	print("view ", vs, " window ", win, " safe ", UI.safe_override)
	var all := sets.has("all")
	for s in ["title", "map", "sheet", "chandler", "pause", "results", "hud", "cards", "boss", "touch"]:
		if not (all or sets.has(s)):
			continue
		match s:
			"title": await _set_title()
			"map": await _set_map()
			"sheet": await _set_sheet()
			"chandler": await _set_chandler()
			"pause": await _set_pause()
			"results": await _set_results()
			"hud": await _set_hud()
			"cards": await _set_cards()
			"boss": await _set_boss()
			"touch": await _set_touch()
	UI.safe_override = Rect2()
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


# ---------------------------------------------------------------- helpers

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	## Time, not frames: a shot run draws far faster than 60 frames a second.
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
		if c.name != "Game" and c.name != "Sfx" and c.name != "Overlay":
			c.queue_free()
	await _frames(2)


func _seen_all() -> void:
	## Every story scene marked seen, so levels start straight into play.
	for id in Story.scenes().keys():
		game.mark_seen(id)
	for k in Story.BARKS.keys():
		game.mark_seen("bark:" + k)


func _hero(cls: String, level: int, satchel := 5) -> Dictionary:
	## A fresh save with this calling at this level, some gear in the satchel,
	## a few relics found and embers banked.
	game.reset()
	game.data["unlocked"]["dusk"] = 8
	game.data["unlocked"]["nightfall"] = 1
	for id in ["1-1", "1-2", "1-3"]:
		var r: Dictionary = game.level_record(id, "dusk")
		r["cleared"] = true
		r["sigils"] = [true, id != "1-2", id == "1-1"]
	game.level_record("1-3", "dusk")["dread"] = true
	for id in ["tallow_heart", "rook_feather", "bellows", "moth_charm", "saints_knuckle", "owls_eye", "choir_bone"]:
		game.grant_relic(id)
	game.new_hero(cls)
	if level > 1:
		game.add_xp(Progression.total_to(level) - int(game.hero()["xp"]))
	var h: Dictionary = game.hero()
	h["belt"] = ["tallow_heart", "rook_feather", "bellows", "saints_knuckle"].slice(0, game.belt_slots())
	for i in satchel:
		var slot: String = ["weapon", "candle", "coat", "weapon", "coat", "candle"][i % 6]
		var rar: String = ["magic", "rare", "common", "legendary", "magic", "rare"][i % 6]
		var lg: String = Items.pick_legend(slot, cls, _rng) if rar == "legendary" else ""
		if rar == "legendary" and lg == "":
			rar = "rare"
		h["satchel"].append(Items.make(slot, cls, maxi(level - 1 + i % 3, 1), rar, _rng, lg))
	game.data["embers"] = 640
	_seen_all()
	return h


func _item(slot: String, rarity: String, cls := "", ilvl := 6) -> Dictionary:
	var c: String = cls if cls != "" else str(game.hero()["cls"])
	var lg: String = Items.pick_legend(slot, c, _rng) if rarity == "legendary" else ""
	return Items.make(slot, c, ilvl, rarity if lg != "" or rarity != "legendary" else "rare", _rng, lg)


func _world(level_id: String, x := -1) -> Node:
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	var lv = LevelData.load_file("res://levels/%s.txt" % level_id)
	var w = World.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	if x >= 0:
		for y in range(lv.height - 1, 0, -1):
			if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
				w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
				break
	w.cam = w._clamp_cam(w.player.position)
	for i in 30:
		await physics_frame
	w.hud._title = {}
	return w


func _freeze(w: Node) -> void:
	## Gameplay stops (no monsters walk in); the HUD and touch keep running.
	w.set_physics_process(false)


# ---------------------------------------------------------------- the sets

func _set_title() -> void:
	await _clear()
	_hero("witch", 7)
	var t = load("res://scripts/title_screen.gd").new()
	root.add_child(t)
	await _wait(0.833)
	await _shot("title")
	await _clear()
	# A first run: no hero yet.
	game.reset()
	t = load("res://scripts/title_screen.gd").new()
	root.add_child(t)
	await _wait(0.833)
	await _shot("title_new")
	await _clear()


func _set_map() -> void:
	await _clear()
	_hero("knight", 6)
	game.data["unlocked"]["dusk"] = 4
	var m = load("res://scripts/map_screen.gd").new()
	m.focus = 2
	root.add_child(m)
	await _wait(0.333)
	await _shot("map_w1")
	await _clear()
	_hero("founder", 11)
	game.hero()["points"] = 2
	for id in ["1-1", "1-2", "1-3", "1-4", "2-1"]:
		game.level_record(id, "dusk")["cleared"] = true
	game.data["unlocked"]["dusk"] = 7
	m = load("res://scripts/map_screen.gd").new()
	m.focus = 5
	root.add_child(m)
	await _wait(0.333)
	await _shot("map_w2")
	await _clear()


func _set_sheet() -> void:
	for cls in CALLINGS:
		await _clear()
		var lvl: int = {"knight": 9, "witch": 4, "runner": 12, "founder": 6, "sexton": 14}[cls]
		_hero(cls, lvl, 6)
		# A few points spent, some left.
		for id in ["x_bright", "k_devout", "w_twin", "r_veil", "f_bellows"]:
			game.buy_skill(id)
		var h = load("res://scripts/hero_screen.gd").new()
		root.add_child(h)
		for tab in ["stats", "skills", "gear", "belt"]:
			h.open_tab(tab)
			await _wait(0.200)
			await _shot("sheet_%s_%s" % [cls, tab])
		# Gear: comparing a satchel item.
		h.open_tab("gear")
		await _wait(0.25)
		var items: Array = h.panel.items_for("weapon")
		if not items.is_empty():
			h.panel.pick(items[0])
			await _wait(0.25)
			await _shot("sheet_%s_gear_compare" % cls)
		if cls == "knight":
			# A full satchel, on the Stats tab.
			var sat: Array = game.hero()["satchel"]
			while sat.size() < game.SATCHEL_MAX:
				sat.append(_item(["boots", "charm"][sat.size() % 2], "common", cls, 2))
			h.open_tab("stats")
			await _wait(0.2)
			await _shot("sheet_knight_stats_full")
			while sat.size() > 6:
				sat.pop_back()
			# Junk below what's worn: "Salvage all below equipped" shows.
			for i in 3:
				var junk: Dictionary = Items.make("weapon", cls, 1, "common", _rng)
				for k in junk["implicit"]:
					if k != "id":
						junk["implicit"][k] = 0.0
				game.hero()["satchel"].append(junk)
			h.open_tab("gear")
			await _wait(0.3)
			await _shot("sheet_knight_gear_salvage")
			h.panel._bulk_pressed()
			await _wait(0.2)
			await _shot("sheet_knight_gear_salvage_ask")
	await _clear()


func _set_chandler() -> void:
	await _clear()
	_hero("runner", 6, 3)
	var seen: Array = game.data["seen"]
	seen.erase("meet_waxley")
	var c = load("res://scripts/chandler_screen.gd").new()
	root.add_child(c)
	await _wait(1.500)
	await _shot("chandler_meet_waxley")
	await _clear()
	game.mark_seen("meet_waxley")
	c = load("res://scripts/chandler_screen.gd").new()
	root.add_child(c)
	await _wait(0.200)
	await _shot("chandler_wares")
	# The first tap asks.
	c._buy(0)
	await _wait(0.25)
	await _shot("chandler_wares_ask")
	c._buy(0)
	await _wait(0.25)
	await _shot("chandler_wares_bought")
	# Poor.
	game.data["embers"] = 12
	c._refresh()
	c._buy(1)
	await _wait(0.25)
	await _shot("chandler_wares_poor")
	# Full: a satchel of 16 weaker things.
	game.data["embers"] = 900
	var h: Dictionary = game.hero()
	h["satchel"].clear()
	for i in 16:
		h["satchel"].append(Items.make(["weapon", "candle", "coat"][i % 3], "runner", 1, "common", _rng))
	# A ware that's no upgrade, so it would go to the satchel.
	var stock: Array = game.wares()
	for i in stock.size():
		if stock[i] is Dictionary:
			var eq = h["equip"].get(stock[i]["slot"])
			if eq is Dictionary:
				var weak: Dictionary = Items.make(stock[i]["slot"], "runner", 1, "magic", _rng)
				stock[i] = weak
	c._refresh()
	var full_i := -1
	for i in stock.size():
		if game.ware_verdict(i) == "full":
			full_i = i
	if full_i >= 0:
		c._buy(full_i)
	await _wait(0.25)
	await _shot("chandler_wares_full")
	# An upgrade for a worn slot, into the full satchel: the old one melts.
	for i in stock.size():
		if stock[i] is Dictionary and h["equip"].get(stock[i]["slot"]) is Dictionary:
			stock[i] = Items.make(stock[i]["slot"], "runner", 14, "rare", _rng)
			c._refresh()
			c._buy(i)
			await _wait(0.25)
			await _shot("chandler_wares_full_ask_melt")
			c._buy(i)
			await _wait(0.25)
			await _shot("chandler_wares_full_bought_melt")
			break
	c.show_tab("relics")
	await _wait(0.25)
	await _shot("chandler_relics")
	c._buy(0)
	await _wait(0.25)
	await _shot("chandler_relics_ask")
	c.show_tab("unmake")
	await _wait(0.25)
	await _shot("chandler_unmake")
	await _clear()


func _set_pause() -> void:
	await _clear()
	_hero("sexton", 8)
	game.hero()["points"] = 1
	var w = await _world("1-2", 30)
	_freeze(w)
	w.open_pause()
	await _wait(0.25)
	await _shot("pause")
	w.pause_menu.show_page("settings")
	await _wait(0.25)
	await _shot("pause_settings")
	w.pause_menu.show_page("main")
	w.pause_menu.open_sheet()
	await _wait(0.167)
	await _shot("pause_sheet")
	# The Belt tab over a level: only to look at (it changes on the map).
	w.pause_menu._sheet.open_tab("belt")
	await _wait(0.167)
	await _shot("pause_sheet_belt")
	await _clear()


func _set_results() -> void:
	await _clear()
	_hero("witch", 4)
	var h: Dictionary = game.hero()
	var before := int(h["xp"])
	game.add_xp(Progression.xp_to_next(4) + 40)
	var it1: Dictionary = _item("weapon", "rare")
	var it2: Dictionary = _item("coat", "magic")
	var it3: Dictionary = _item("candle", "common")
	var res := {"level": "1-2", "cleared": true, "embers": 38, "embers_total": 52, "sigils": [true, false, true], "time": 148.2,
			"relics": ["bell_shard"], "items": [it1, it2, it3], "xp": int(h["xp"]) - before, "levels": 1,
			"level_start": 4, "level_now": 5, "diff": "dusk", "dread": true}
	var r = load("res://scripts/results_screen.gd").new()
	r.result = res
	r.index = 1
	r.set("rewards", [{"kind": "relic", "id": "wind_wick"}, {"kind": "difficulty", "id": "nightfall"}])
	r.set("first_clear", true)
	r.set("after", Story.after_line("1-2", "witch"))
	root.add_child(r)
	await _wait(1.667)
	await _shot("results_levelup")
	await _wait(3.333)
	await _shot("results")
	await _clear()
	# A snuffed run: nothing found.
	r = load("res://scripts/results_screen.gd").new()
	r.result = {"level": "1-3", "cleared": false, "embers": 0, "embers_total": 60, "sigils": [false, false, false], "time": 64.0,
			"relics": [], "items": [], "xp": 22, "levels": 0, "diff": "dusk"}
	r.index = 2
	root.add_child(r)
	await _wait(5.000)
	await _shot("results_snuffed")
	await _clear()


func _hud_world(cls: String, level_id: String, x: int) -> Node:
	_hero(cls, 7)
	var w = await _world(level_id, x)
	return w


func _set_hud() -> void:
	## Each calling in play: the Special and its resource, the flask, life,
	## XP, embers and sigils.
	for cls in CALLINGS:
		await _clear()
		var w = await _hud_world(cls, "1-1", 20)
		w.player.hp = w.player.max_hp * 0.62
		w.player.res = w.player.res_max * 0.55
		w.flask_charges = 1
		w.embers_carried = 23
		w.sigils_got = [true, false, false]
		game.add_xp(int(Progression.xp_to_next(7) * 0.4))
		await _wait(0.667)
		_freeze(w)
		await _wait(0.333)
		await _shot("hud_%s" % cls)
	# The Sexton with every wisp out: Toll the Dead.
	await _clear()
	var w2 = await _hud_world("sexton", "1-1", 20)
	_freeze(w2)
	w2.touch.special_state = {"fill": 1.0, "ready": true, "grey": false, "pips": 3, "pips_max": 3, "ring": 0.6, "icon": "toll"}
	await _wait(0.333)
	await _shot("hud_sexton_toll")
	# The Taperwitch charging a Flare (held through the touch layer).
	await _clear()
	var w3 = await _hud_world("witch", "1-1", 20)
	w3.player.res = w3.player.res_max
	w3.test_pad = null
	var L: Dictionary = w3.touch.layout()
	_touch(w3.touch, 0, L["special"], true)
	for i in 30:
		await physics_frame
	_freeze(w3)
	await _wait(0.25)
	await _shot("hud_witch_charge")
	_touch(w3.touch, 0, L["special"], false)
	# Low life, the flask held, empty flask.
	await _clear()
	var w4 = await _hud_world("knight", "1-1", 20)
	w4.player.hp = w4.player.max_hp * 0.18
	w4.flask_charges = 0
	await _wait(0.333)
	_freeze(w4)
	await _wait(0.167)
	await _shot("hud_low_life")
	await _clear()


func _touch(t: Node, idx: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = p
	e.pressed = down
	t._input(e)


func _set_cards() -> void:
	## The pickup card in each state, the sold card and notes, a relic card, the
	## level-up toast, a bark, an elite plate.
	await _clear()
	var w = await _hud_world("knight", "1-1", 20)
	_freeze(w)
	var hud = w.hud
	var h: Dictionary = game.hero()
	var worn: Dictionary = h["equip"]["weapon"]
	var better: Dictionary = _item("weapon", "rare", "knight", 9)
	# Equipped (auto-equip).
	game.equip(better)
	hud.show_pickup(better, {"dmg": 18.0, "life": 0.0}, "equipped")
	await _wait(0.500)
	await _shot("card_equipped")
	# Undo: a tap puts the old one back.
	hud.tap_card()
	await _wait(0.333)
	await _shot("card_undone")
	hud._card = {}
	hud._cards.clear()
	# Satchel.
	var side: Dictionary = _item("coat", "magic", "knight", 7)
	game.add_item(side)
	hud.show_pickup(side, {"dmg": 4.0, "life": -6.0}, "satchel")
	await _wait(0.500)
	await _shot("card_satchel")
	hud._card = {}
	# A Legendary: its power wraps to two lines rather than being cut.
	var twin: Dictionary = Items.make("candle", "knight", 7, "legendary", _rng, "twin_wick")
	game.add_item(twin)
	hud.show_pickup(twin, {"dmg": 0.0, "life": 8.0}, "satchel")
	await _wait(0.500)
	await _shot("card_legendary")
	hud._card = {}
	# Build 1: a Legendary worn on pickup is a "New power" card (world.gd's
	# moment: power_card), its power large and the chips small; and one into
	# the satchel.
	var dawn: Dictionary = Items.make("weapon", "knight", 7, "legendary", _rng, "dawnsliver")
	game.equip(dawn)
	hud.show_pickup(dawn, {"dmg": -6.0, "life": 0.0}, "equipped")
	hud.power_card(dawn)
	await _wait(0.500)
	await _shot("card_power")
	hud._card = {}
	var gutter: Dictionary = Items.make("candle", "knight", 7, "legendary", _rng, "gutterlight")
	game.add_item(gutter)
	hud.show_pickup(gutter, {"dmg": 0.0, "life": -3.0}, "satchel")
	hud.power_card(gutter)
	await _wait(0.500)
	await _shot("card_power_satchel")
	hud._card = {}
	game.equip(worn)
	# Full (a satchel of 16): wearing it melts the old one, so the first tap
	# (a touch, as the touch layer sends it) only asks; the second wears it.
	while (h["satchel"] as Array).size() < game.SATCHEL_MAX:
		h["satchel"].append(_item(["boots", "charm"][(h["satchel"] as Array).size() % 2], "common", "knight", 2))
	var left: Dictionary = _item("candle", "rare", "knight", 8)
	hud.show_pickup(left, {"dmg": 6.0, "life": -3.0}, "full")
	await _wait(0.500)
	await _shot("card_full")
	hud.tap_card(true)
	await _wait(0.333)
	await _shot("card_full_armed")
	hud.tap_card(true)
	await _wait(0.333)
	await _shot("card_full_worn")
	hud._card = {}
	# Auto-equip into the full satchel: the old weapon melts, no undo.
	var best: Dictionary = _item("weapon", "rare", "knight", 12)
	game.equip(best)
	hud.show_pickup(best, {"dmg": 22.0, "life": 0.0}, "equipped")
	await _wait(0.500)
	await _shot("card_equipped_melt")
	hud._card = {}
	# Sold: a find no better than what's worn ("Sell weaker finds"), its
	# card's tap keeping it; and, the satchel full, a note (a Rare, a Blessed).
	(h["satchel"] as Array).pop_back()
	var com: Dictionary = _item("coat", "magic", "knight", 5)
	game.add_embers(Items.sell_value(com))
	hud.show_pickup(com, {"dmg": 0.0, "life": -8.0}, "sold")
	await _wait(0.500)
	await _shot("card_sold")
	hud.tap_card()
	await _wait(0.333)
	await _shot("card_sold_kept")
	hud._card = {}
	while (h["satchel"] as Array).size() < game.SATCHEL_MAX:
		h["satchel"].append(_item("boots", "common", "knight", 2))
	var rare: Dictionary = _item("weapon", "rare", "knight", 4)
	hud.show_pickup(rare, {"dmg": -12.0, "life": 0.0}, "sold")
	await _wait(0.500)
	await _shot("card_sold_full_rare")
	hud._msg = {}
	var bl: Dictionary = _item("candle", "magic", "knight", 4)
	hud.show_pickup(bl, {"dmg": -2.0, "life": -1.0}, "sold")
	await _wait(0.500)
	await _shot("card_sold_full_blessed")
	hud._msg = {}
	# A relic card.
	game.grant_relic("wind_wick")
	hud.relic_found("wind_wick")
	await _wait(0.500)
	await _shot("card_relic")
	hud._card = {}
	# Level up.
	hud.level_up(8)
	await _wait(0.400)
	await _shot("levelup_toast")
	hud._lvl = {}
	# A level that opens a belt slot (L5), two levels at once.
	hud._xp_level = 3
	hud.level_up(5)
	await _wait(0.4)
	await _shot("levelup_toast_belt")
	hud._lvl = {}
	hud._xp_level = int(game.hero()["level"])
	# A bark with Taper's face, and a hint.
	hud._bark_last = {}
	hud._push({"kind": "bark", "key": "bark:x", "text": "Mind the flame, sprout. It's your life down here.", "who": "taper",
			"tex": UI.tex(UI.portrait_path("taper", "warm")), "uv": Rect2(0, 0, 1, 1), "col": UI.speaker_color("taper")})
	await _wait(0.500)
	await _shot("bark")
	await _clear()


func _set_boss() -> void:
	for lid in ["1-4", "2-4"]:
		await _clear()
		_hero("knight" if lid == "1-4" else "founder", 9)
		var w = await _world(lid, -1)
		var b = w.boss
		if b == null:
			continue
		w.player.reset_at(b.position + Vector2(-160, 0))
		w.cam = w._clamp_cam(w.player.position)
		b.state = "idle" if b.state == "sleep" else b.state
		b.hp = b.max_hp * 0.52
		w.hud.boss_bar(b.boss_info())
		for i in 10:
			await physics_frame
		_freeze(w)
		w.hud._title = {}
		w.hud.show_hint("")
		await _wait(0.667)
		await _shot("boss_%s" % lid)
		# With a message under it.
		w.hud.toast("Altar lit", "Your flame will return here")
		await _wait(0.500)
		await _shot("boss_%s_msg" % lid)
	await _clear()


func _set_touch() -> void:
	## The touch buttons with their hit zones drawn, at each button size.
	for k in [0.9, 1.0, 1.1]:
		await _clear()
		_hero("founder", 5)
		game.set_setting("button_scale", k)
		var w = await _world("1-1", 20)
		_freeze(w)
		var dbg := Control.new()
		dbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var layer := CanvasLayer.new()
		layer.layer = 20
		layer.add_child(dbg)
		w.add_child(layer)
		var t = w.touch
		dbg.draw.connect(func():
			var L: Dictionary = t.layout()
			for n in ["left", "right", "flask", "attack", "jump", "special", "pause"]:
				var rr: float = L["r_" + ("move" if n in ["left", "right"] else n)]
				dbg.draw_arc(L[n], rr, 0, TAU, 48, Color(1, 0.2, 0.2, 0.9), 1.5)
			var s: Rect2 = UI.safe_override
			dbg.draw_rect(s, Color(0.2, 1, 0.4, 0.7), false, 1.0)
			var c: Rect2 = w.hud.card_slot()
			dbg.draw_rect(c, Color(0.3, 0.6, 1, 0.8), false, 1.0))
		await _wait(0.167)
		await _shot("touch_zones_%d" % roundi(k * 100))
		# An item card up in its tap window: what a touch starting at each
		# spot becomes (blue the card, red attack, green move, yellow jump,
		# violet special, grey nothing).
		w.hud.show_pickup(_item("coat", "magic", "founder", 5), {"dmg": 4.0, "life": -6.0}, "satchel")
		w.hud._process(0.05)
		var cols := {"card": Color(0.3, 0.6, 1.0, 0.9), "attack": Color(1, 0.25, 0.25, 0.9), "move": Color(0.3, 1, 0.4, 0.8),
				"jump": Color(1, 0.9, 0.2, 0.8), "special": Color(0.8, 0.4, 1, 0.8), "flask": Color(1, 1, 1, 0.9), "pause": Color(1, 1, 1, 0.9), "": Color(0.5, 0.5, 0.5, 0.5)}
		dbg.draw.connect(func():
			var c: Rect2 = w.hud.card_slot().grow(12.0)
			var y := c.position.y
			while y <= c.end.y:
				var x := c.position.x - 40.0
				while x <= c.end.x + 60.0:
					dbg.draw_rect(Rect2(x - 1.0, y - 1.0, 2.0, 2.0), cols.get(t.role_at(Vector2(x, y)), Color.BLACK))
					x += 4.0
				y += 4.0)
		dbg.queue_redraw()
		await _wait(0.167)
		await _shot("touch_card_claims_%d" % roundi(k * 100))
	game.set_setting("button_scale", 1.0)
	await _clear()
