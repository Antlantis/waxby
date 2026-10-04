extends SceneTree
## test_screens (W3): the HUD, the touch layer and every menu, headless.
## At 847x390 (the iPhone 17 Pro Max), 844x390 and a narrower 780x390, with
## the phone's safe area and with plain margins: every screen builds, its
## buttons and drawn pieces stay inside the safe area and clear of each other
## (the HUD's bars, sigils, boss bar, message slot and pickup card, and the
## touch buttons at every button size). The HUD takes every World -> HUD call
## on a real World, and its message slot keeps its priorities. The touch
## layer tests pause, flask, card, then move/right; a tap on the flask never
## moves, a touch that began as a move never drinks, and a held flask really
## drinks in a level; a thumb slid off the flask runs. The lit thumb pad
## (build 1): down and up count 26 px from where the thumb landed (less low
## on the glass), a steep slide is pure down or up, each switches on with a
## tick (haptics allowing), its idle tick sits clear of the discs, and its
## one-time cards (the first ledge, the first vine) come once a save and
## never for the bot, headless or a fed pad. Only an item card
## in its tap window takes a touch, and never one just off a thumb button
## (attack, the right arrow); a tap that would melt the worn piece asks
## first. The life numbers are never cut and stay clear of the flame at any
## life, 2- to 5-digit. Barks follow story.gd's once / every
## rule, and the HUD's clocks hold while the level is paused. The Sheet buys
## a skill and respecs, equips from the satchel, salvages, and edits the belt
## only where it may; its Stats tab names the hero and renames him (the
## oath's name entry: Confirm, Cancel, Escape, above a phone's keyboard). Real taps (sent through Input, as a phone sends them)
## do one thing each on the belt, the keeper, the map and the Sheet. The
## keeper hosted by the oath scene hides its Back and backdrop; the map says
## when a world's tab opens. With the satchel full, a pickup is never lost
## and the satchel never grows past its cap (in a real level and at the
## Chandler), and the card's, Waxley's and the results pills' text fits.
##
## v3 (SC): at every size, the six-world map (tabs, the Lv 30+ / 40+ chips,
## the secret medallions, the Challenges button, a one-time card), the HUD's
## mode pill, Special pill, top-band card and Candlemark, the deep Skills
## tree, five belt slots, pause in a mode, results with a secret, a Lost Wick
## and candles, and the Tales buttons stay inside the safe area and clear of
## each other, every button a thumb tall. A secret shows only once opened
## (its level built, its exit's level cleared for the spark, its bell rung
## for the medallion), and plays by play_secret; main.gd's cards mark their
## notice when closed; the Nightfall warning comes once; Continue from the
## altar is offered once a snapshot; the Challenges button waits for the hub
## and 1-2; the World's v3 HUD calls land (the dim ring through its dims, the
## pill, a queued card, the three-part boss bar, the finale's fade that
## spares the Special's pill); the candle-strength card comes once, at 6
## snuffs in a level or 5 at a boss, on Dusk at Normal only; a mode's pause
## items (one asking twice); the deep tree's lock texts; the gear slots that
## turn up deeper down; icons clamp to the tiers drawn. The W3-W6 and secret
## levels are header-only stand-ins in user:// until the level streams land.
##
##     godot --headless --path game --script res://tests/test_screens.gd

const DT := 1.0 / 120.0
const SIZES := [Vector2i(847, 390), Vector2i(844, 390), Vector2i(780, 390)]

var UI
var HudScript
var TouchScript
var WorldScript
var LevelData
var Items
var Classes
var Progression
var Combat
var StatsPanel
var game: Node
var _passed := 0
var _failed := 0
var _where := ""
var catch: ErrCatch
var _errs_seen := 0


class ErrCatch extends Logger:
	## Every script and engine error while the screens run (warnings aside):
	## a draw callback that fails fails the test that drew it.
	var errors: Array = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func since(n: int) -> Array:
		_lock.lock()
		var out := errors.slice(n)
		_lock.unlock()
		return out


func _no_errors(what: String) -> void:
	## No script or engine error since the last look.
	var fresh: Array = catch.since(_errs_seen)
	_errs_seen += fresh.size()
	_check(fresh.is_empty(), "%s: no script or engine errors (%d: %s)" % [what, fresh.size(), fresh.slice(0, 3)])


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL [%s]: %s" % [_where, what])


func _initialize() -> void:
	catch = ErrCatch.new()
	OS.add_logger(catch)
	# Scripts that use the autoloads are loaded now, not preloaded.
	UI = load("res://scripts/ui.gd")
	HudScript = load("res://scripts/hud.gd")
	TouchScript = load("res://scripts/touch_controls.gd")
	WorldScript = load("res://scripts/world.gd")
	LevelData = load("res://scripts/level_data.gd")
	Items = load("res://scripts/items.gd")
	Classes = load("res://scripts/classes.gd")
	Progression = load("res://scripts/progression.gd")
	Combat = load("res://scripts/combat.gd")
	StatsPanel = load("res://scripts/stats_panel.gd")
	game = root.get_node("Game")
	game.save_path = "user://test_screens_save.json"
	game.settings_path = "user://test_screens_settings.json"
	# The autoloads' _ready (Game loads its save) runs after _initialize: wait
	# for it, then start clean.
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:   # (a missing settings file is read from its .bak)
		if FileAccess.file_exists(game.settings_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path + suffix))
	game.reset()
	for size in SIZES:
		for phone in [true, false]:
			await _set_view(size, phone)
			await _test_hud_layout()
			_no_errors("hud_layout")
			_test_touch_layout()
			_no_errors("touch_layout")
			await _test_screen_layouts()
			_no_errors("screen_layouts")
			await _test_v3_layouts()
			_no_errors("v3_layouts")
			await _test_choice_layout()
			_no_errors("choice_layout")
	await _set_view(Vector2i(847, 390), true)
	await _test_message_slot()
	_no_errors("message_slot")
	await _test_message_time()
	_no_errors("message_time")
	await _test_barks()
	_no_errors("barks")
	await _test_hud_paused()
	_no_errors("hud_paused")
	await _test_hud_on_world()
	_no_errors("hud_on_world")
	await _test_title_band()
	_no_errors("title_band")
	await _test_floor_clear()
	_no_errors("floor_clear")
	_test_quiet_discs()
	_no_errors("quiet_discs")
	await _test_touch_roles()
	_no_errors("touch_roles")
	await _test_flask_slide()
	_no_errors("flask_slide")
	await _test_thumb_pad()
	_no_errors("thumb_pad")
	await _test_thumb_tips()
	_no_errors("thumb_tips")
	await _test_card_claims()
	_no_errors("card_claims")
	await _test_card_rest()
	_no_errors("card_rest")
	await _test_flask_drinks()
	_no_errors("flask_drinks")
	await _test_skills()
	_no_errors("skills")
	await _test_rename()
	_no_errors("rename")
	await _test_gear()
	_no_errors("gear")
	await _test_belt()
	_no_errors("belt")
	await _test_keeper()
	_no_errors("keeper")
	await _test_keeper_hosted()
	_no_errors("keeper_hosted")
	await _test_map()
	_no_errors("map")
	await _test_world_opened()
	_no_errors("world_opened")
	await _test_real_taps()
	_no_errors("real_taps")
	await _test_pause()
	_no_errors("pause")
	await _test_results()
	_no_errors("results")
	await _test_pickup_states()
	_no_errors("pickup_states")
	await _test_power_card()
	_no_errors("power_card")
	await _test_level_up_card()
	_no_errors("level_up_card")
	await _test_points_pip()
	_no_errors("points_pip")
	await _test_altar_rites()
	_no_errors("altar_rites")
	await _test_rites_more()
	_no_errors("rites_more")
	await _test_tier_barks()
	_no_errors("tier_barks")
	await _test_touch_specials()
	_no_errors("touch_specials")
	await _test_chandler()
	_no_errors("chandler")
	await _test_results_from_main()
	_no_errors("results_from_main")
	await _test_milestones()
	_no_errors("milestones")
	await _test_map_secrets()
	_no_errors("map_secrets")
	await _test_map_cards()
	_no_errors("map_cards")
	await _test_map_challenges()
	_no_errors("map_challenges")
	await _test_hud_v3()
	_no_errors("hud_v3")
	await _test_strength_card()
	_no_errors("strength_card")
	await _test_pause_modes()
	_no_errors("pause_modes")
	await _test_skills_deep()
	_no_errors("skills_deep")
	await _test_gear_waits()
	_no_errors("gear_waits")
	await _test_results_v3()
	_no_errors("results_v3")
	await _test_ui_v3()
	_no_errors("ui_v3")
	UI.safe_override = Rect2()
	print("test_screens: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _set_view(size: Vector2i, phone: bool) -> void:
	root.size = size
	root.content_scale_size = size
	var vs := Vector2(size)
	UI.safe_override = UI.phone_safe(vs) if phone else Rect2(14, 10, vs.x - 28.0, vs.y - 18.0)
	_where = "%dx%d %s" % [size.x, size.y, "phone" if phone else "margins"]
	await process_frame
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _inside(r: Rect2, what: String, tol := 0.6) -> void:
	var s: Rect2 = UI.safe_override
	_check(r.position.x >= s.position.x - tol and r.position.y >= s.position.y - tol and r.end.x <= s.end.x + tol and r.end.y <= s.end.y + tol,
			"%s %s is inside the safe area %s" % [what, r, s])


func _apart(a: Rect2, b: Rect2, what: String) -> void:
	_check(not a.grow(-0.5).intersects(b.grow(-0.5)), "%s don't overlap (%s, %s)" % [what, a, b])


func _circle(c: Vector2, r: float) -> Rect2:
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


func _local(r: Rect2, n: Control) -> Rect2:
	return Rect2(r.position + n.global_position, r.size)


func _stub_world(claim := false) -> Node:
	## Just what the HUD reads: a player's numbers, embers, sigils, the boss,
	## the touch layer; undo_equip and apply_hero are counted. claim: it can
	## lift an item left on the ground (satchel full) off the floor too.
	var ps := GDScript.new()
	ps.source_code = "extends Node2D\nvar hp := 84.0\nvar max_hp := 120.0\nvar res := 50.0\nvar res_max := 100.0\nvar stats := {\"cls\": \"knight\"}\nfunc life_frac():\n\treturn hp / max_hp\n"
	ps.reload()
	var ws := GDScript.new()
	ws.source_code = """extends Node
var player
var embers_carried := 7
var embers_got := 9
var flask_charges := 1
var sigils_got := [true, false, false]
var boss = null
var touch = null
var hud = null
var paused := false
var pickups := []
var undone := []
var applied := 0
func undo_equip(it):
	undone.append(it)
func apply_hero():
	applied += 1
""" + ("var claimed := []\nfunc claim_item(it):\n\tclaimed.append(it)\n" if claim else "")
	ws.reload()
	var w: Node = ws.new()
	w.player = ps.new()
	w.add_child(w.player)
	return w


func _stub_story(with_take := true) -> GDScript:
	## story.gd as W4 built it: every key but "none" has a line; the "every"
	## barks repeat, the rest play once per save (seen through Game as
	## "bark:<key>"); bark_once is false for "every" barks and unknown keys;
	## take_bark is what the HUD calls. Without take_bark: an older story.gd.
	var s := GDScript.new()
	var src := """extends RefCounted
const EVERY := ["tollgrave_angry", "snuffer_angry", "snuffer_dark", "level_up"]
static func _game():
	return Engine.get_main_loop().root.get_node_or_null("Game")
static func bark_every(k):
	return EVERY.has(k)
static func bark_once(k):
	if k == "none" or bark_every(k):
		return false
	var g = _game()
	if g.seen("bark:" + k):
		return false
	g.mark_seen("bark:" + k)
	return true
static func bark_line(k, cls):
	if k == "none":
		return {}
	return {"who": "taper", "mood": "warm", "text": "A line for " + k + "."}
"""
	if with_take:
		src += """static func take_bark(k, cls):
	if k == "none":
		return {}
	if not bark_every(k) and not bark_once(k):
		return {}
	return bark_line(k, cls)
"""
	s.source_code = src
	s.reload()
	return s


func _click(p: Vector2) -> void:
	## A real tap: a left press and release through Input, as the phone sends
	## it. (The mouse emulates touch here, so each also arrives as a screen
	## touch: a screen that took both would see this tap twice.)
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


func _buttons(n: Node, out: Array) -> Array:
	## Every visible Button under n that isn't inside a scroll list.
	for c in n.get_children():
		if c is ScrollContainer or c.is_queued_for_deletion():
			continue
		if c is CanvasItem and not c.visible:
			continue
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out


func _buttons_ok(n: Node, what: String, tall := true) -> void:
	## Every button inside the safe area, clear of the others and (tall) at
	## least UI.TAP_H high: 40 view units is 45 pt on the iPhone 17 Pro Max,
	## past Apple's 44.
	var bs := _buttons(n, [])
	_check(bs.size() > 0, "%s has buttons" % what)
	for i in bs.size():
		var a: Button = bs[i]
		_inside(a.get_global_rect(), "%s button '%s'" % [what, a.text])
		if tall:
			_check(a.size.y >= UI.TAP_H - 0.5, "%s button '%s' is a thumb tall (%.0f)" % [what, a.text, a.size.y])
		for j in range(i + 1, bs.size()):
			var b: Button = bs[j]
			_apart(a.get_global_rect(), b.get_global_rect(), "%s buttons '%s' and '%s'" % [what, a.text, b.text])


func _fresh_hero(level := 1, cls := "knight") -> void:
	game.reset()
	game.new_hero(cls)
	if level > 1:
		game.add_xp(Progression.total_to(level))


# ---------------------------------------------------------------- layout

func _name_plates() -> void:
	## The hero's own name on the map's pill and the Sheet's top-bar plate,
	## his calling and level beside it while they fit (at the phone's own
	## 844 x 390, "Ash" keeps both); the longest name a player can give, at
	## the level cap with points waiting, still fits: the pill clear of the
	## bells, their chips and the buttons, the plate's words inside it (cut
	## short only where nothing else fits).
	var wide := root.content_scale_size.x >= 844
	for named in ["Ash", "WWWWWWWWWWWW"]:
		_fresh_hero(7)
		if named.length() > 3:
			game.add_xp(Progression.total_to(Progression.CAP))
		game.set_hero_name(named)
		var lv := int(game.hero()["level"])
		_check(game.hero_name() == named and (named == "Ash" or int(game.hero().get("points", 0)) > 0), "(%s at Lv %d)" % [named, lv])
		var m = load("res://scripts/map_screen.gd").new()
		root.add_child(m)
		await _frames(2)
		var pw: Dictionary = m.pill_words()
		var pr: Rect2 = m.pill_rect()
		var said := str(pw["name"])
		_check(said == named or (said.ends_with("…") and named.begins_with(said.trim_suffix("…"))), "the map's pill names him: %s" % [pw])
		_check(str(pw["sub"]) in ["Candleknight Lv %d" % lv, "Lv %d" % lv, ""] and int(pw["size"]) >= 10, "and his calling and level while they fit: %s" % [pw])
		if named == "Ash" and wide:
			_check(pw["sub"] == "Candleknight Lv 7", "at the phone's own width, 'Ash' keeps his calling on the pill")
		_inside(pr, "map hero plate, '%s'" % named)
		for r in m.bell_rects():
			_apart(r, pr, "map bell and '%s's plate" % named)
		for d in Combat.DIFFS:
			var cr: Rect2 = m.chip_rect(d)
			if cr.has_area():
				_apart(cr, pr, "%s chip and '%s's plate" % [d, named])
		for b in _buttons(m, []):
			_apart(pr, b.get_global_rect(), "'%s's plate and button '%s'" % [named, b.text])
		m.queue_free()
		var h = load("res://scripts/hero_screen.gd").new()
		root.add_child(h)
		await _frames(2)
		var pl: Dictionary = h.plate_words()
		said = str(pl["name"])
		var used: float = 30.0 + UI.text_width(said, pl["size"], "title", 700) + UI.text_width(pl["lvl"], 15, "body", 700)
		_check(said == named or (said.ends_with("…") and named.begins_with(said.trim_suffix("…"))), "the Sheet's plate names him: %s" % [pl])
		_check(str(pl["lvl"]) in ["Candleknight · Level %d" % lv, "Level %d" % lv, ""] and int(pl["size"]) >= 11, "and his calling and level while they fit: %s" % [pl])
		_check(used <= h.plate_rect().size.x + 0.5, "its words fit the plate (%.0f of %.0f)" % [used, h.plate_rect().size.x])
		if named == "Ash" and wide:
			_check(pl["lvl"] == "Candleknight · Level 7", "at the phone's own width, 'Ash' keeps his calling on the plate")
		h.queue_free()
		await _frames(1)
	_fresh_hero(7)


func _test_hud_layout() -> void:
	var w := _stub_world()
	root.add_child(w)
	var touch = TouchScript.new()
	w.touch = touch
	w.add_child(touch)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	touch.hud = hud
	w.add_child(hud)
	await _frames(2)
	for k in [0.9, 1.0, 1.1]:
		touch.button_scale = k
		var L: Dictionary = hud.layout()
		var T: Dictionary = touch.layout()
		var tag := "HUD (buttons ×%.1f)" % k
		for key in ["badge", "life", "xp", "res", "embers", "sigils", "boss", "boss_label", "msg", "msg_boss", "card"]:
			_inside(L[key], "%s %s" % [tag, key])
		var left := ["badge", "life", "xp", "res", "embers"]
		for a in left:
			for b in ["sigils", "boss", "boss_label", "msg", "msg_boss", "card"]:
				_apart(L[a], L[b], "%s %s and %s" % [tag, a, b])
		for b in ["boss", "boss_label", "msg", "msg_boss"]:
			_apart(L["sigils"], L[b], "%s sigils and %s" % [tag, b])
			_apart(_circle(T["pause"], T["r_pause"]), L[b], "%s pause and %s" % [tag, b])
		_apart(L["sigils"], _circle(T["pause"], T["r_pause"]), "%s sigils and pause" % tag)
		_apart(L["boss"], L["msg_boss"], "%s boss bar and message slot" % tag)
		_apart(L["boss_label"], L["msg_boss"], "%s boss name and message slot" % tag)
		_check((L["card"] as Rect2).size.x >= 200.0, "%s the pickup card keeps a usable width (%.0f)" % [tag, (L["card"] as Rect2).size.x])
		for bname in ["left", "right", "flask", "attack", "jump", "special", "pause"]:
			var br := _circle(T[bname], T["r_" + ("move" if bname in ["left", "right"] else bname)])
			_apart(L["card"], br, "%s pickup card and the %s button" % [tag, bname])
			if bname != "pause":
				for key in left + ["msg", "msg_boss", "boss", "sigils"]:
					_apart(L[key], br, "%s %s and the %s button" % [tag, key, bname])
		_card_claims_ok(hud, touch, tag)
		_key_lines_ok((L["card"] as Rect2).size.x - 82.0, tag, k)
		# The corners' backing: a wash under the left block and a tray for the
		# sigils, each covering its cluster and staying in its corner (the boss
		# bar and the message slot draw over the wash's edge on their panels).
		var B: Dictionary = hud.backing_rects()
		var vw: float = root.get_visible_rect().size.x
		for key in left:
			_check((B["left"] as Rect2).encloses(L[key]), "%s the left wash covers %s" % [tag, key])
		_check((B["right"] as Rect2).encloses(L["sigils"]), "%s the sigils sit on their tray" % tag)
		_apart(B["right"], _circle(T["pause"], T["r_pause"]), "%s sigil tray and pause" % tag)
		_check((B["left"] as Rect2).end.x < vw * 0.35 and (B["right"] as Rect2).position.x > vw * 0.7, "%s the backings stay in their corners" % tag)
		for side in ["left", "right"]:
			_inside(B[side], "%s %s backing" % [tag, side], 6.0)
			_check((B[side] as Rect2).end.y <= UI.safe_override.position.y + 66.0, "%s the %s backing stays in the top band (%.0f)" % [tag, side, (B[side] as Rect2).end.y])
			_apart(B[side], L["card"], "%s %s backing and the pickup card" % [tag, side])
	_life_text_ok(hud)
	w.queue_free()
	await _frames(2)


func _card_claims_ok(hud, touch, tag: String) -> void:
	## With an item card up in its tap window: no touch within 2.0 x an
	## arrow's radius or 1.6 x attack's, jump's or the Special's (from their
	## centres) is the card's (the card's edge is a few px from attack and
	## the right arrow, and a card tap can undo an equip or wear an item),
	## the card still takes most of itself, and presses up to that far past
	## attack's and the right arrow's edges, toward the card, are those
	## buttons'.
	var kept: Dictionary = hud._card
	hud._card = {"kind": "item", "item": {}, "chips": {}, "where": "satchel", "t": 1.0, "tap_left": 2.0, "icon": null}
	var T: Dictionary = touch.layout()
	var card: Rect2 = hud.card_rect()
	var grown := card.grow(4.0)
	var near: Array = []
	var claimed := 0
	var total := 0
	var y := grown.position.y
	while y <= grown.end.y:
		var x := grown.position.x
		while x <= grown.end.x:
			var q := Vector2(x, y)
			var mine: bool = hud.card_hit(q)
			if card.has_point(q):
				total += 1
				if mine:
					claimed += 1
			if mine:
				for b in ["left", "right", "attack", "jump", "special"]:
					var mv: bool = b in ["left", "right"]
					var rb: float = T["r_move"] if mv else T["r_" + b]
					var kk: float = HudScript.CARD_CLEAR_MOVE if mv else HudScript.CARD_CLEAR_BUTTON
					if q.distance_to(T[b]) < rb * kk and near.size() < 3:
						near.append("%s near %s" % [q, b])
			x += 3.0
		y += 3.0
	_check(near.is_empty(), "%s: no touch near a thumb button is the card's %s" % [tag, near])
	_check(claimed >= total * 0.7, "%s: the card still takes most of itself (%d of %d)" % [tag, claimed, total])
	_check(touch.role_at(card.get_center()) == "card", "%s: a tap in the card's middle is the card's" % tag)
	# Presses up to 0.55 x attack's radius past its edge, and up to 0.95 x
	# the arrows' past theirs, toward the card: the buttons'.
	for frac in [0.1, 0.3, 0.55]:
		for deg in [-40.0, -20.0, 0.0, 20.0, 40.0]:
			var a := deg_to_rad(deg)
			var qa: Vector2 = T["attack"] + Vector2(-cos(a), sin(a)) * float(T["r_attack"]) * (1.0 + frac)
			if grown.has_point(qa):
				_check(touch.role_at(qa) == "attack", "%s: %.0f px off attack at %.0f deg, it swings (%s)" % [tag, float(T["r_attack"]) * frac, deg, touch.role_at(qa)])
			var qr: Vector2 = T["right"] + Vector2(cos(a), sin(a)) * float(T["r_move"]) * (1.0 + frac * 1.7)
			if grown.has_point(qr):
				_check(touch.role_at(qr) == "move", "%s: %.0f px off the right arrow at %.0f deg, it moves (%s)" % [tag, float(T["r_move"]) * frac * 1.7, deg, touch.role_at(qr)])
	hud._card = kept


func _key_lines_ok(w: float, tag: String, k: float) -> void:
	## The pickup card's "what it does" line: a Legendary's power wraps to
	## two lines (at 10 px or more) rather than being cut; every line fits
	## the card. On the phone at the default button size every power reads
	## whole.
	var bad: Array = []
	var cut: Array = []
	for id in Items.LEGENDS:
		var text := str(Items.LEGENDS[id]["text"])
		var kl: Dictionary = HudScript.card_key_lines(text, w)
		var lines: Array = kl["lines"]
		var ok: bool = lines.size() >= 1 and lines.size() <= 2 and int(kl["size"]) >= 10
		for l in lines:
			ok = ok and UI.text_width(str(l), int(kl["size"])) <= w + 0.5
		if not ok:
			bad.append(id)
		if " ".join(lines) != text:
			cut.append(id)
	_check(bad.is_empty(), "%s: every Legendary's line fits the card in 1-2 lines (%s)" % [tag, bad])
	if root.get_visible_rect().size.x >= 844.0 and k <= 1.0:
		_check(cut.is_empty(), "%s: and reads whole, nothing cut (%s)" % [tag, cut])
	var short: Dictionary = HudScript.card_key_lines("+12% damage", w)
	_check((short["lines"] as Array).size() == 1 and int(short["size"]) == 12, "%s: a short line stays one line at 12 px" % tag)


func _life_text_ok(hud) -> void:
	## The life numbers never get cut (draw_string trims text to the width
	## it's given: "211 / 38" for 211 / 382) and stay clear of the flame at
	## the burning end, at every life from 2-digit to 5-digit and every
	## length of wax: "hp / max" whenever it fits at 10 px or more on one
	## side, else "hp/max", else just the life left.
	var r: Rect2 = hud.layout()["life_bar"]
	var bad: Array = []
	var shrunk := 0
	var short := 0
	var tight := 0
	var fails := 0
	for mx in [38.0, 120.0, 302.0, 382.0, 999.0, 1044.0, 1880.0, 9999.0, 24000.0]:
		for i in range(1, 201):
			var fr := i / 200.0
			var hp := roundf(mx * fr)
			var lt: Dictionary = hud.life_text(r, fr, hp, mx)
			var txt := str(lt["text"])
			var fs := int(lt["size"])
			var strip: Rect2 = lt["rect"]
			var wx := r.position.x + r.size.x * fr
			var tw: float = UI.text_width(txt, fs, "body", 800)
			var full := "%d / %d" % [roundi(hp), roundi(mx)]
			var compact := "%d/%d" % [roundi(hp), roundi(mx)]
			var wax_room: float = wx - r.position.x - 22.0
			var dark_room: float = r.end.x - maxf(wx + 8.0, r.position.x + 4.0) - 2.0
			var ok: bool = txt != "" and tw <= strip.size.x + 0.01 and fs >= HudScript.LIFE_FONT_MIN
			# The text's own span, centred in its strip: inside the bar, clear of the flame.
			var x0 := strip.position.x + (strip.size.x - tw) * 0.5
			ok = ok and x0 >= r.position.x + 2.0 and x0 + tw <= r.end.x - 1.0
			ok = ok and (x0 + tw <= wx - 12.0 or x0 >= wx + 8.0)
			ok = ok and (txt == full or txt == compact or txt == str(roundi(hp)))
			if txt == str(roundi(hp)):
				short += 1
				# Only when "hp/max" fits at 10 px on neither side.
				var cw: float = UI.text_width(compact, HudScript.LIFE_FONT_MIN, "body", 800)
				ok = ok and cw > wax_room and cw > dark_room
			elif txt == compact:
				tight += 1
				# Only when "hp / max" fits at 10 px on neither side.
				var fw: float = UI.text_width(full, HudScript.LIFE_FONT_MIN, "body", 800)
				ok = ok and fw > wax_room and fw > dark_room and mx >= 1000.0
			elif fs < HudScript.LIFE_FONT:
				shrunk += 1
			if not ok:
				fails += 1
				if bad.size() < 4:
					bad.append("%d/%d at %.3f: '%s' %dpx (%.1f in %.1f)" % [roundi(hp), roundi(mx), fr, txt, fs, tw, strip.size.x])
	_check(fails == 0, "life numbers: never cut, clear of the flame, inside the bar (%d bad: %s)" % [fails, bad])
	_check(shrunk > 0 and tight > 0 and short > 0, "(the sweep reaches the smaller type (%d), \"hp/max\" (%d) and the life-only text (%d))" % [shrunk, tight, short])
	# The old clipping band ("163 / 30", "211 / 38") reads in full.
	var at54: Dictionary = hud.life_text(r, 163.0 / 302.0, 163.0, 302.0)
	_check(str(at54["text"]) == "163 / 302", "163 of 302 (54%%) reads \"163 / 302\" (\"%s\" at %d px)" % [at54["text"], at54["size"]])
	var at55: Dictionary = hud.life_text(r, 211.0 / 382.0, 211.0, 382.0)
	_check(str(at55["text"]) == "211 / 382", "211 of 382 reads \"211 / 382\" (\"%s\")" % at55["text"])
	# 4-digit life (L25-L30) always shows both numbers.
	var worst := 0
	for i in range(1, 201):
		var t4 := str(hud.life_text(r, i / 200.0, roundf(1999.0 * i / 200.0), 1999.0)["text"])
		if not t4.contains("/"):
			worst += 1
	_check(worst == 0, "with 1999 life, both numbers show all along the bar (%d without)" % worst)
	# Where it always fitted it looks as it did: 13 px, ink on the wax high
	# up, cream past the flame low down.
	var hi: Dictionary = hud.life_text(r, 0.9, 272.0, 302.0)
	var lo: Dictionary = hud.life_text(r, 0.2, 60.0, 302.0)
	_check(bool(hi["on_wax"]) and int(hi["size"]) == HudScript.LIFE_FONT, "high life: on the wax at 13 px")
	_check(not bool(lo["on_wax"]) and int(lo["size"]) == HudScript.LIFE_FONT, "low life: past the flame at 13 px")


func _test_touch_layout() -> void:
	var s: Rect2 = UI.safe_override
	for k in [0.9, 1.0, 1.1]:
		var T: Dictionary = TouchScript.layout_for(s, k)
		var names := ["left", "right", "flask", "attack", "jump", "special", "pause"]
		for i in names.size():
			var a: String = names[i]
			var ra: float = T["r_" + ("move" if a in ["left", "right"] else a)]
			_inside(_circle(T[a], ra), "button %s ×%.1f" % [a, k])
			for j in range(i + 1, names.size()):
				var b: String = names[j]
				var rb: float = T["r_" + ("move" if b in ["left", "right"] else b)]
				_check((T[a] as Vector2).distance_to(T[b]) > ra + rb + 2.0, "buttons %s and %s ×%.1f don't overlap" % [a, b, k])
		# The Special sits clear of jump and attack, above them.
		_check((T["special"] as Vector2).distance_to(T["jump"]) > 100.0 * k, "special is well clear of jump ×%.1f" % k)
		_check(T["special"].y < T["attack"].y and T["special"].y < T["jump"].y, "special is above jump and attack ×%.1f" % k)
		# The idle up/down tick sits in the gap between the arrows, its strokes
		# clear of both discs and the flask.
		var h: Dictionary = TouchScript.slide_hint(T)
		for dir in [-1, 1]:
			var pts: PackedVector2Array = TouchScript.chevron(h["up" if dir < 0 else "down"], dir, h["w"], h["h"])
			for b in ["left", "right", "flask"]:
				var c: Vector2 = T[b]
				var rb: float = T["r_move" if b != "flask" else "r_flask"]
				var near := INF
				for i in 2:
					near = minf(near, c.distance_to(Geometry2D.get_closest_point_to_segment(c, pts[i], pts[i + 1])))
				_check(near > rb + float(h["width"]) * 0.5 + 0.5, "the idle %s tick ×%.1f is clear of the %s disc (%.1f px off its rim)" % ["up" if dir < 0 else "down", k, b, near - rb])
			_inside(Rect2(pts[0], Vector2.ZERO).expand(pts[1]).expand(pts[2]), "the idle tick ×%.1f" % k)


func _test_screen_layouts() -> void:
	_fresh_hero(7)
	# Title.
	var t = load("res://scripts/title_screen.gd").new()
	root.add_child(t)
	await _frames(3)
	_check(t.get_node("Wick").get_meta("rig").cls == "knight", "the title rig wears the hero's calling")
	t.queue_free()
	# Map.
	var m = load("res://scripts/map_screen.gd").new()
	root.add_child(m)
	await _frames(3)
	_buttons_ok(m, "map")
	var bs := _buttons(m, [])
	for r in m.bell_rects():
		_inside(r, "map bell")
		_apart(r, m.pill_rect(), "map bell and hero plate")
		for b in bs:
			_apart(r, b.get_global_rect(), "map bell and button '%s'" % b.text)
	_inside(m.pill_rect(), "map hero plate")
	for b in bs:
		_apart(m.pill_rect(), b.get_global_rect(), "map hero plate and button '%s'" % b.text)
	var N: Dictionary = m.nodes()
	for i in N:
		# The medallion with its Lv tag above and name and sigils below.
		var mr := Rect2(N[i] - Vector2(40, 58), Vector2(80, 146))
		_inside(mr, "map medallion %d" % i)
		for b in bs:
			_apart(mr, b.get_global_rect(), "medallion %d and button '%s'" % [i, b.text])
		# With a twist (Build 2) its name sits under the title and the sigils
		# move 12 down: still on the glass and clear of the buttons.
		m._info[i]["twist"] = "The Saint's Guard"
		var tr := Rect2(N[i] - Vector2(40, 58), Vector2(80, 146 + 12))
		_inside(tr, "map medallion %d with a twist's name" % i)
		for b in bs:
			_apart(tr, b.get_global_rect(), "medallion %d (a twist's name) and button '%s'" % [i, b.text])
		m._info[i]["twist"] = ""
	m.queue_free()
	# Keeper.
	var k = load("res://scripts/keeper_screen.gd").new()
	root.add_child(k)
	await _frames(3)
	var R: Array = k.alcove_rects()
	for i in R.size():
		_inside((R[i] as Rect2).grow_individual(0, 0, 0, 44.0), "alcove %d with its name" % i)
		for j in range(i + 1, R.size()):
			_apart(R[i], R[j], "alcoves %d and %d" % [i, j])
	k.open_card("knight")
	await _frames(2)
	_inside(k.card_rect(), "calling card")
	# The keeper's own Back is 34 high (keeper_screen.gd is the story
	# integrator's; the one-line fix is requested): not held to the height yet.
	_buttons_ok(k, "calling card")
	k.queue_free()
	# The Sheet, every tab.
	var h = load("res://scripts/hero_screen.gd").new()
	root.add_child(h)
	for tab in ["stats", "skills", "gear", "belt"]:
		h.open_tab(tab)
		await _frames(3)
		_buttons_ok(h, "sheet %s" % tab)
		_inside(h.plate_rect(), "sheet name plate")
		for b in _buttons(h, []):
			_apart(h.plate_rect(), b.get_global_rect(), "sheet name plate and button '%s'" % b.text)
		var c: Rect2 = h.content_rect()
		_inside(c, "sheet %s panel" % tab)
		_check(h.panel.get_global_rect().is_equal_approx(c), "sheet %s panel fills its place" % tab)
		match tab:
			"skills":
				var P: Dictionary = h.panel.positions()
				var ids: Array = P.keys()
				for i in ids.size():
					var a: Array = P[ids[i]]
					_inside(_circle(a[0] + h.panel.global_position, a[1] + 12.0), "skill node %s" % ids[i])
					for j in range(i + 1, ids.size()):
						var b: Array = P[ids[j]]
						_check((a[0] as Vector2).distance_to(b[0]) > a[1] + b[1] + 8.0, "skill nodes %s and %s apart" % [ids[i], ids[j]])
				_inside(_local(h.panel.card_rect(), h.panel), "skill card")
			"gear":
				var S: Dictionary = h.panel.slot_rects()
				for s in S:
					_inside(_local((S[s] as Rect2).grow_individual(0, 0, 0, 16.0), h.panel), "gear slot %s with its label" % s)
			"belt":
				for r in h.panel.slot_rects() + h.panel.codex_rects():
					_inside(_local(r, h.panel), "belt tile")
	h.queue_free()
	await _name_plates()
	# Pause, on its own.
	var pm = load("res://scripts/pause_menu.gd").new()
	root.add_child(pm)
	await _frames(1)
	pm.open()
	await _frames(2)
	_buttons_ok(pm, "pause")
	pm.show_page("settings")
	await _frames(2)
	_buttons_ok(pm, "settings")
	for r in pm.settings_rows():
		_inside(r["rect"], "setting row %s" % r["key"])
	pm.queue_free()
	await _frames(2)
	# Results.
	var r = load("res://scripts/results_screen.gd").new()
	r.result = {"level": "1-1", "cleared": true, "embers": 12, "embers_total": 40, "sigils": [true, false, false], "time": 90.0,
			"relics": [], "items": [], "xp": 60, "levels": 0, "diff": "dusk"}
	r.rewards = [{"kind": "relic", "id": "moth_charm"}, {"kind": "embers", "n": 60}, {"kind": "difficulty", "id": "nightfall"}]
	root.add_child(r)
	r._t = 10.0
	await _frames(3)
	_buttons_ok(r, "results")
	_check(r.pills.size() == 3, "results: a pill for each milestone reward (%d)" % r.pills.size())
	for pl in r.pills:
		var pr: Rect2 = pl["panel"]
		var sr: Rect2 = pl["sub"]
		_inside(pr, "results reward pill")
		# Clear of the border and its rounded corner (8), not on them.
		_check(sr.position.x >= pr.position.x + 8.0 and sr.end.x <= pr.end.x - 8.0, "results pill label '%s' %s sits inside its pill %s" % [pl["text"], sr, pr])
	r.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the HUD

func _test_message_slot() -> void:
	_where = "message slot"
	_fresh_hero(1)
	var w := _stub_world()
	root.add_child(w)
	var hud = HudScript.new()
	hud.world = w
	hud.story = _stub_story()
	hud._story_checked = true
	w.add_child(hud)
	await _frames(1)
	# Four at once come out pickup, elite, bark, toast, 2.5 s each.
	var E = load("res://scripts/enemy.gd")
	var e = E.new()
	e.kind = "skeleton"
	e.tier = "anointed"
	e.omens = ["swift"]
	e.max_hp = 40.0
	e.hp = 40.0
	w.add_child(e)
	hud.toast("Altar lit", "Your flame will return here")
	hud.bark("first_altar")
	hud.elite_seen(e)
	hud.sigil_found(0, [true, false, false])
	var order: Array = []
	var shown_at := {}
	for i in 12 * 60:
		hud._process(1.0 / 60.0)
		var k: String = hud._msg.get("kind", "")
		if k != "" and (order.is_empty() or order[-1] != k):
			order.append(k)
			shown_at[k + str(order.size())] = i / 60.0
	_check(order.slice(0, 3) == ["pickup", "elite", "bark"], "priority: pickup, elite, then the barks (got %s)" % [order])
	_check(hud._msgs.is_empty() and hud._msg.is_empty(), "the slot empties")
	_check(not order.has("toast"), "a toast left waiting past 6 s is dropped, not shown late (got %s)" % [order])
	# Each shows its 2.5 s.
	_check(absf(float(shown_at.get("elite2", 0.0)) - 2.5) < 0.05, "each message holds the slot 2.5 s (elite at %.2f)" % float(shown_at.get("elite2", 0.0)))
	# A toast on its own shows at once.
	hud.toast("Reclaimed", "+12 embers")
	hud._process(0.02)
	_check(hud._msg.get("title", "") == "Reclaimed", "a toast alone shows at once")
	# A more important message cuts a toast short once it's been read.
	hud._process(1.0)
	hud.sigil_found(1, [true, true, false])
	hud._process(0.05)
	hud._process(0.4)
	_check(hud._msg.get("kind", "") == "pickup", "a pickup cuts in over a toast that's been read")
	# Barks: once a key in a while; nothing without a line.
	hud._msg = {}
	hud._msgs.clear()
	hud.bark("low_flame")
	hud.bark("low_flame")
	_check(hud._msgs.size() == 1, "the same bark twice in a moment is one message")
	_check(hud._msgs[0]["text"] == "A line for low_flame." and hud._msgs[0]["who"] == "taper", "the line and speaker come from story.gd")
	hud.bark("none")
	_check(hud._msgs.size() == 1, "a bark with no line shows nothing")
	var h2 = HudScript.new()
	h2.world = w
	w.add_child(h2)
	await _frames(1)
	h2._story_checked = true
	h2.story = null
	h2.bark("first_item")
	_check(h2._msgs.is_empty(), "no story.gd: barks are quiet")
	# A title card holds the slot back; a message takes a sign hint's place.
	hud._msgs.clear()
	hud._msg = {}
	hud.show_hint("Tap the wing to jump")
	hud.title_card("1-1", "The Nave")
	hud.toast("Held", "")
	hud._process(0.5)
	_check(hud._msg.is_empty(), "messages wait while a title card is up")
	hud._title = {}
	hud._process(0.1)
	_check(hud._msg.get("title", "") == "Held" and hud._hint_on, "then the message takes the hint's place")
	# A relic's card swallows the matching toast (where it goes on).
	hud._msgs.clear()
	hud._msg = {}
	hud.relic_found("rook_feather")
	hud.toast("Rook Feather", "The next altar offers it")
	_check(hud._msgs.is_empty() and hud._cards.size() == 1, "the relic card, not a toast too")
	# The card says where a relic found with the belt full goes on: the next
	# altar's swap card (world.relic_ahead), else the map's Sheet.
	var st: Array = [HudScript.relic_status({"on": true}), HudScript.relic_status({"on": false, "altar": true}),
			HudScript.relic_status({"on": false, "altar": false})]
	_check(st[0] == "on your belt" and st[1] == "the next altar offers it" and st[2].contains("map"),
			"the relic card: on the belt, the next altar offers it, or put on from the map (%s)" % [st])
	_check(not bool(hud._cards[0].get("altar", true)), "a World that can't say (no relic_ahead): the map, never a promise of an altar")
	w.queue_free()
	await _frames(2)


func _test_message_time() -> void:
	## A message holds the slot by its length: 1 s and 0.05 s a character,
	## 2.5 s at least and 5 s at most (msg_time), set once in _push and used
	## by the slot's timer, its fade and a cut-in alike.
	_where = "message time"
	_fresh_hero(1)
	var w := _stub_world()
	root.add_child(w)
	var hud = HudScript.new()
	hud.world = w
	hud.story = _stub_story()
	hud._story_checked = true
	w.add_child(hud)
	await _frames(1)
	var long := "Ice holds nothing still. Let go of the arrow early and slide to a stop."   # 71 characters
	_check(is_equal_approx(HudScript.msg_time({"kind": "bark", "text": "Short."}), HudScript.MSG_TIME), "a short line keeps the 2.5 s")
	_check(is_equal_approx(HudScript.msg_time({"kind": "bark", "text": long}), 1.0 + 0.05 * long.length()), "a %d-character bark holds %.2f s" % [long.length(), 1.0 + 0.05 * long.length()])
	_check(is_equal_approx(HudScript.msg_time({"kind": "bark", "text": long + " " + long}), HudScript.MSG_MAX), "a very long one stops at 5 s")
	var note := {"kind": "toast", "title": "A title of forty characters, give or take", "sub": "and a line under it for the rest"}
	_check(is_equal_approx(HudScript.msg_time(note), 1.0 + 0.05 * (str(note["title"]) + " " + str(note["sub"])).length()),
			"a note counts its title and its line")
	# Through the slot: the long bark shows its own time, then a short toast its 2.5 s.
	hud._push({"kind": "bark", "key": "bark:long", "text": long, "who": "taper"})
	hud.toast("Altar lit", "")
	var shown := {}
	var gone := {}
	var faded_late := false
	for i in 10 * 60:
		hud._process(1.0 / 60.0)
		var k := str(hud._msg.get("kind", ""))
		if k != "" and not shown.has(k):
			shown[k] = i / 60.0
		for was in shown:
			if not gone.has(was) and k != was:
				gone[was] = i / 60.0
		# Still fully up a second past the old 2.5 s (the fade reads its own time).
		if k == "bark" and absf(i / 60.0 - 3.5) < 0.01:
			var t := float(hud._msg["t"])
			faded_late = clampf((float(hud._msg["dur"]) - t) * 3.5, 0.0, 1.0) >= 1.0
	var want := 1.0 + 0.05 * long.length()
	_check(absf(float(gone.get("bark", 0.0)) - float(shown.get("bark", 0.0)) - want) < 0.05,
			"the long bark holds the slot %.2f s (%.2f)" % [want, float(gone.get("bark", 0.0)) - float(shown.get("bark", 0.0))])
	_check(faded_late, "and is still fully up at 3.5 s (its fade waits for its own end)")
	_check(absf(float(gone.get("toast", 0.0)) - float(shown.get("toast", 0.0)) - HudScript.MSG_TIME) < 0.05,
			"the short toast after it holds 2.5 s (%.2f)" % (float(gone.get("toast", 0.0)) - float(shown.get("toast", 0.0))))
	# A pickup cuts a long message short once it's been read, at its own end less 0.3 s.
	hud._msg = {}
	hud._msgs.clear()
	hud._push({"kind": "bark", "key": "bark:long2", "text": long, "who": "taper"})
	hud._process(0.02)
	hud._process(1.5)
	hud.sigil_found(1, [true, true, false])
	hud._process(0.05)
	_check(str(hud._msg.get("kind", "")) == "bark" and absf(float(hud._msg["t"]) - (want - 0.3)) < 0.06,
			"a pickup cuts a long bark to its last 0.3 s (t %.2f of %.2f)" % [float(hud._msg.get("t", 0.0)), want])
	hud._process(0.35)
	_check(str(hud._msg.get("kind", "")) == "pickup", "then the pickup shows")
	# A message put in by hand (no _push) keeps the old 2.5 s.
	hud._msgs.clear()
	hud._msg = {"kind": "toast", "title": "By hand", "sub": "", "pri": 1, "t": 0.0}
	hud._process(2.45)
	_check(not hud._msg.is_empty(), "(one put in by hand is up at 2.45 s)")
	hud._process(0.1)
	_check(hud._msg.is_empty(), "and gone at 2.55 s: MSG_TIME")
	w.queue_free()
	await _frames(2)


func _test_barks() -> void:
	## Barks through story.gd as W4 built it (take_bark), and through an older
	## one with only bark_every / bark_once: the "every" barks (the boss's
	## phase-2 taunt, level up, the Snuffer's dark) play each time they fire,
	## the rest once per save, and an unknown key says nothing.
	for with_take in [true, false]:
		_where = "barks (%s)" % ("take_bark" if with_take else "bark_once only")
		_fresh_hero(1)
		var w := _stub_world()
		root.add_child(w)
		var hud = HudScript.new()
		hud.world = w
		hud.story = _stub_story(with_take)
		hud._story_checked = true
		w.add_child(hud)
		await _frames(1)
		for key in ["tollgrave_angry", "level_up", "snuffer_dark"]:
			var plays := 0
			for n in 2:
				hud._msgs.clear()
				hud._msg = {}
				hud._t += HudScript.BARK_GAP + 1.0
				hud.bark(key)
				if hud._msgs.size() == 1 and str(hud._msgs[0]["text"]) == "A line for %s." % key:
					plays += 1
			_check(plays == 2, "the every-bark %s plays each time it fires (%d of 2)" % [key, plays])
		var once := 0
		for n in 2:
			hud._msgs.clear()
			hud._msg = {}
			hud._t += HudScript.BARK_GAP + 1.0
			hud.bark("first_item")
			once += hud._msgs.size()
		_check(once == 1, "a once-only bark plays once per save (%d)" % once)
		_check(game.seen("bark:first_item"), "and is marked heard")
		hud._msgs.clear()
		hud._t += HudScript.BARK_GAP + 1.0
		hud.bark("none")
		_check(hud._msgs.is_empty(), "an unknown key says nothing")
		w.queue_free()
		await _frames(2)


func _test_hud_paused() -> void:
	## While the level is paused (the pause menu, a story beat over the
	## level) the HUD's clocks hold: the pickup card keeps its tap window, the
	## message in the slot its turn, the level-up card its time.
	_where = "HUD paused"
	_fresh_hero(1)
	var w := _stub_world()
	root.add_child(w)
	var hud = HudScript.new()
	hud.world = w
	w.add_child(hud)
	await _frames(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	hud.show_pickup(Items.make("coat", "knight", 2, "magic", rng), {"dmg": 0.0, "life": -1.0}, "satchel")
	hud.toast("Altar lit", "Your flame will return here")
	hud._process(0.05)
	_check(not hud._card.is_empty() and hud._msg.get("title", "") == "Altar lit", "(a pickup card and a toast are up)")
	hud.level_up(2)
	var tap0 := float(hud._card["tap_left"])
	var msg0 := float(hud._msg["t"])
	w.paused = true
	for i in 4 * 60:
		hud._process(1.0 / 60.0)
	_check(not hud._card.is_empty() and is_equal_approx(float(hud._card["tap_left"]), tap0), "paused 4 s: the pickup card keeps its tap window (%.2f of %.2f)" % [float(hud._card.get("tap_left", -1.0)), tap0])
	_check(hud._msg.get("title", "") == "Altar lit" and is_equal_approx(float(hud._msg["t"]), msg0), "the toast keeps its turn")
	_check(not hud._lvl.is_empty() and is_equal_approx(float(hud._lvl["t"]), 0.0), "the level-up card waits")
	_check(hud.tap_card(), "and a tap still counts after the pause")
	w.paused = false
	for i in 60:
		hud._process(1.0 / 60.0)
	_check(float(hud._card["tap_left"]) < HudScript.CARD_TAP - 0.9, "unpaused, the window runs again")
	_check(float(hud._lvl["t"]) > 0.9, "and so do the cards")
	w.queue_free()
	await _frames(2)


func _test_hud_on_world() -> void:
	## Every World -> HUD call on a real World (headless, with the HUD and the
	## touch layer put on by hand), and the pickup card's tap.
	_where = "HUD on a World"
	_fresh_hero(3)
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var w = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await _frames(1)
	var hud = HudScript.new()
	hud.world = w
	hud.story = _stub_story()
	hud._story_checked = true
	w.hud = hud
	w.add_child(hud)
	var touch = TouchScript.new()
	w.touch = touch
	w.add_child(touch)
	await _frames(1)
	w.test_pad = {}
	for i in 60:
		w.tick(DT)
	_check(touch.special_state.has("fill") and touch.flask_state.has("charges"), "the World pushes the Special's and flask's state to the touch layer")
	# The calls, with frames between so each one draws.
	hud.title_card("1-1", "The Nave")
	hud.show_hint("Land on skeletons to stomp them")
	hud.toast("Altar lit", "Your flame will return here")
	hud.bump_embers()
	hud.bump_flames()
	hud.sigil_found(2, [false, false, true])
	hud.relic_found("rook_feather")
	hud.bark("first_item")
	hud.boss_bar({"id": "tollgrave", "name": "Old Tollgrave", "title": "The Bell Warden", "frac": 0.7, "phases": [0.6, 0.25], "awake": true})
	hud.level_up(4)
	hud.banner("RUNG!")
	hud.xp_tick()
	var e = w.spawn_enemy("skeleton", w.player.position + Vector2(80, 0), {"tier": "anointed", "omens": ["swift", "burning"]})
	hud.elite_seen(e)
	w.embers_carried = 6
	await _frames(2)
	hud.banked()
	await _frames(20)
	_check(not hud._boss.is_empty(), "the boss bar is up")
	_check(not hud._lvl.is_empty() and not w.paused, "the level-up card is up, and play didn't pause")
	var elite: Array = hud._msgs.filter(func(q): return q["kind"] == "elite")
	if hud._msg.get("kind", "") == "elite":
		elite = [hud._msg]
	_check(not elite.is_empty(), "the elite plate is queued or showing")
	if not elite.is_empty():
		_check(str(elite[0]["title"]) == "Anointed Rattle", "an Anointed without a name is named for its kind (%s)" % elite[0]["title"])
		_check(elite[0]["omens"] == ["Swift", "Burning"], "its omens are listed")
	hud.boss_bar({})
	_check(hud._boss.is_empty(), "boss_bar({}) takes the bar down")
	# Low life: the vignette draws.
	w.player.hp = w.player.max_hp * 0.1
	await _frames(4)
	w.player.hp = w.player.max_hp
	# The pickup card, through the World: an auto-equipped upgrade, undone by a tap.
	hud._cards.clear()
	hud._card = {}
	var old: Dictionary = game.hero()["equip"]["weapon"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var better = Items.make("weapon", "knight", 12, "rare", rng)
	w._take_item(better)
	hud._process(0.05)
	_check(str(game.hero()["equip"]["weapon"]["uid"]) == str(better["uid"]), "a plainly better weapon is worn at once")
	_check(hud.card_rect().size.x > 0.0 and str(hud._card.get("where", "")) == "equipped", "the card says it's equipped")
	_check(hud.tap_card(), "a tap inside the window is taken")
	_check(str(game.hero()["equip"]["weapon"]["uid"]) == str(old["uid"]), "the tap undoes the auto-equip")
	_check(str(hud._card["where"]) == "undone", "the card now says it's in the satchel")
	_check(hud.accept_pickup(), "the equip key does what a tap does")
	_check(str(game.hero()["equip"]["weapon"]["uid"]) == str(better["uid"]), "and wears it again")
	for i in 60 * 5:
		hud._process(1.0 / 60.0)
	_check(hud._card.is_empty(), "the card goes after its window")
	_check(not hud.tap_card(), "no card, no tap")
	# A find no better than what's worn is sold on touch ("Sell weaker
	# finds", on by default); a tap keeps it, the embers going back.
	var worse = Items.make("coat", "knight", 1, "magic", rng)
	worse["affixes"] = []
	worse["implicit"]["v"] = 0.0
	var purse := int(game.embers())
	_check(w._take_item(worse) == "sold" and int(game.embers()) == purse + Items.sell_value(worse), "a weaker find is sold on touch (+%d)" % Items.sell_value(worse))
	hud._process(0.05)
	var where: String = str(hud._card.get("where", ""))
	_check(where == "sold" and hud.card_hit(hud.card_rect().get_center()), "its card says so and takes a tap (%s)" % where)
	await _frames(1)
	_check(hud.card_line == "SOLD  +%d · TAP TO KEEP" % Items.sell_value(worse), "\"%s\"" % hud.card_line)
	_check(hud.tap_card() and str(hud._card["where"]) == "kept" and int(game.embers()) == purse
			and (game.hero()["satchel"] as Array).any(func(x): return str(x["uid"]) == str(worse["uid"])), "a tap keeps it: into the satchel, the embers back")
	_check(not hud.tap_card(), "kept: no more taps")
	# With the setting off it goes to the satchel; a tap wears it.
	hud._card = {}
	game.set_setting("auto_sell", false)
	var worse2 = worse.duplicate(true)
	worse2["uid"] = "worse-2"
	w._take_item(worse2)
	game.set_setting("auto_sell", true)
	hud._process(0.05)
	where = str(hud._card.get("where", ""))
	_check(where == "satchel", "Sell weaker finds off: an item that isn't an upgrade goes to the satchel (%s)" % where)
	hud.tap_card()
	_check(str(game.hero()["equip"]["coat"]["uid"]) == str(worse2["uid"]), "tapping a satchel card wears it")
	# A Common find sells too (what auto-salvage melted): a card, as any sale with room.
	hud._card = {}
	hud._cards.clear()
	hud._msgs.clear()
	var common = Items.make("candle", "knight", 1, "common", rng)
	var before := int(game.embers())
	var res: String = game.add_item(common, true)
	hud.show_pickup(common, {"dmg": 0.0, "life": 0.0}, res)
	_check(res == "sold" and int(game.embers()) > before, "a Common find is sold for embers")
	_check(hud._cards.size() == 1 and str(hud._cards[0]["where"]) == "sold" and not hud._msgs.any(func(q): return q["kind"] == "pickup"),
			"with room in the satchel a sale is a card (it can be kept), not a note")
	_check(hud._tick_t > 0.0 and hud._tick == Items.sell_value(common) and hud._tick_word == "sold", "and \"+%d sold\" ticks by the embers" % hud._tick)
	hud._cards.clear()
	# Level up through the World, and banking.
	hud._lvl = {}
	w.gain_xp(Progression.xp_to_next(3) + 5, w.player.position)
	_check(not hud._lvl.is_empty() and int(hud._lvl["n"]) == 4, "gaining a level shows its card")
	w.embers_carried = 9
	hud._process(0.01)
	w._bank()
	_check(hud._bank_flash > 0.9 and hud._bank_amount == 9, "banking flashes the ember count with what was banked")
	# A run with the HUD on: the per-tick calls (hints, the low-life bark).
	w.player.hp = w.player.max_hp * 0.2
	for i in 600:
		w.test_pad = {"right": true, "jump": (i / 50) % 3 == 0, "attack": (i / 17) % 2 == 0}
		w._read_pad()
		w.tick(DT)
		if i % 4 == 0:
			await process_frame
	_check(w.player.position.x > 200.0, "the World ran with the HUD on")
	w.queue_free()
	await _frames(3)


# ---------------------------------------------------------------- touch

const HERO_TALL := 76.0   # Waxby's feet to the tip of his flame, in view px


func _longest_title() -> String:
	## The widest name a title card shows: a level's, a Dread's or a boss's.
	var names := ["Old Tollgrave", "The Snuffer"]
	for info in game.LEVELS:
		var d = LevelData.load_file(info["path"])
		names.append(str(d.title))
		if not d.dread.is_empty():
			names.append(str(d.dread.get("name", "")))
	var best := ""
	for n in names:
		if UI.text_width(n, 40, "title", 700) > UI.text_width(best, 40, "title", 700):
			best = n
	return best


func _test_title_band() -> void:
	## Title cards (a level, a Dread, a boss) and the level-up card sit in
	## the top band: inside the safe area, clear of the left block, the
	## sigils and pause, and over the hero's flame where the camera holds
	## him on the floor (a Dread's card comes as it closes in, a boss's as
	## he wakes). They take turns: a title card waits out the level-up
	## card, and a boss's bar grows in once his card has gone.
	_where = "title band"
	var longest := _longest_title()
	for lid in ["1-1", "1-4"]:
		_fresh_hero(6)
		var lv = LevelData.load_file("res://levels/%s.txt" % lid)
		var w = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await _frames(1)
		var hud = HudScript.new()
		hud.world = w
		w.hud = hud
		w.add_child(hud)
		var touch = TouchScript.new()
		w.touch = touch
		w.add_child(touch)
		await _frames(1)
		w.test_pad = {}
		if lid == "1-1":
			for y in range(lv.height - 1, 0, -1):
				if lv.tile(20, y) == 0 and LevelData.is_solid(lv.tile(20, y + 1)):
					w.player.reset_at(Vector2(20 * 32 + 16, (y + 1) * 32))
					break
		elif w.boss != null:
			w.player.reset_at(w.boss.position + Vector2(-160, 0))
		for i in 240:
			w.tick(DT)
		var vs := Vector2(root.size)
		var feet: float = w.player.position.y - w.cam.y + vs.y * 0.5
		var flame := feet - HERO_TALL
		var T: Rect2 = hud.title_rect(longest)
		var L: Dictionary = hud.layout()
		var tag := "%s (feet at %.0f)" % [lid, feet]
		_check(w.player.on_floor, "%s: the hero stands on the floor" % tag)
		_inside(T, "%s title card '%s'" % [tag, longest])
		_check(T.end.y + 6.0 <= flame, "%s: the title card ends (%.0f) over the hero's flame (%.0f)" % [tag, T.end.y, flame])
		for key in ["badge", "life", "res", "embers", "sigils"]:
			_apart(T, L[key], "%s title card and %s" % [tag, key])
		var P: Dictionary = touch.layout()
		_apart(T, _circle(P["pause"], P["r_pause"]), "%s title card and pause" % tag)
		var lr: Rect2 = hud.level_rect()
		_check(lr.end.y + 6.0 <= flame, "%s: the level-up card ends (%.0f) over the hero's flame (%.0f)" % [tag, lr.end.y, flame])
		for key in ["badge", "life", "res", "embers", "sigils"]:
			_apart(lr, L[key], "%s level-up card and %s" % [tag, key])
		# A boss wakes: his card, then his bar.
		if lid == "1-4":
			hud.title_card("The Bell Warden", "Old Tollgrave")
			hud.boss_bar({"id": "tollgrave", "name": "Old Tollgrave", "title": "The Bell Warden", "frac": 1.0, "phases": [0.6, 0.25], "awake": true})
			var bar_during := 0.0
			for i in int(HudScript.TITLE_TIME * 60.0) - 2:
				hud._process(1.0 / 60.0)
				if hud.title_alpha() > 0.05:
					bar_during = maxf(bar_during, hud.boss_alpha())
			_check(bar_during == 0.0, "%s: the boss bar waits while his card is up (%.2f)" % [tag, bar_during])
			for i in 90:
				hud._process(1.0 / 60.0)
			_check(hud._title.is_empty() and hud._boss_in >= 1.0 and hud.boss_alpha() >= 0.99, "%s: then it grows in (%.2f)" % [tag, hud.boss_alpha()])
			# A level-up in the fight: the bar steps aside for its card, then comes back.
			hud.level_up(9)
			var low := 1.0
			for i in 60:
				hud._process(1.0 / 60.0)
				low = minf(low, hud.boss_alpha())
			_check(low == 0.0, "%s: the bar steps aside for a level-up card (%.2f)" % [tag, low])
			for i in int(HudScript.LEVEL_TIME * 60.0) + 30:
				hud._process(1.0 / 60.0)
			_check(hud._lvl.is_empty() and hud.boss_alpha() >= 0.99, "%s: and comes back after it (%.2f)" % [tag, hud.boss_alpha()])
			hud.boss_bar({})
		# The level-up card first, then a title card: it waits its turn.
		hud._title = {}
		hud._lvl = {}
		hud.level_up(7)
		for i in 30:
			hud._process(1.0 / 60.0)
		hud.title_card("Dread", "Old Drippings")
		var seen_both := false
		var shown := 0.0
		for i in 400:
			hud._process(1.0 / 60.0)
			if hud.title_alpha() > 0.05:
				shown += 1.0 / 60.0
				if not hud._lvl.is_empty():
					seen_both = true
		_check(not seen_both, "%s: a title card never shows over the level-up card" % tag)
		_check(absf(shown - HudScript.TITLE_TIME) < 0.5 and hud._title.is_empty(), "%s: it shows after it, for its whole time (%.2f s)" % [tag, shown])
		# A level-up cuts a showing title card short (as it did).
		hud.title_card("1-1", "The Nave")
		for i in 30:
			hud._process(1.0 / 60.0)
		hud.level_up(8)
		for i in 30:
			hud._process(1.0 / 60.0)
		_check(hud._title.is_empty() and not hud._lvl.is_empty(), "%s: a level-up cuts a showing title card short" % tag)
		w.queue_free()
		await _frames(2)


func _floor_world(lid: String, x: int) -> Node:
	## A headless World on a level with the HUD and the touch controls, the
	## hero standing on the lowest floor in column x (x < 0: where the level
	## starts him), the camera settled.
	var lv = LevelData.load_file("res://levels/%s.txt" % lid)
	var w = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await _frames(1)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	var touch = TouchScript.new()
	w.touch = touch
	touch.hud = hud
	w.add_child(touch)
	await _frames(1)
	touch.apply_settings()
	w.test_pad = {}
	for y in range(lv.height - 1, 0, -1):
		if x >= 0 and lv.tile(x, y) == 0 and LevelData.is_solid(lv.tile(x, y + 1)):
			w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
			break
	for i in 240:
		w.tick(DT)
	return w


func _hero_view(w: Node) -> Rect2:
	## Waxby as drawn, in view px: his width, from his feet to his flame's tip.
	var v := Vector2(root.size)
	var feet: Vector2 = w.player.position - w.cam + v * 0.5
	return Rect2(feet.x - WorldScript.HERO_HALF, feet.y - WorldScript.HERO_TALL, WorldScript.HERO_HALF * 2.0, WorldScript.HERO_TALL)


func _under_hud(w: Node, r: Rect2) -> String:
	## The HUD corner block or top button r is behind, or "".
	var H: Dictionary = w.hud.layout()
	for k in ["badge", "life", "res", "embers", "sigils"]:
		if (H[k] as Rect2).intersects(r):
			return k
	var L: Dictionary = w.touch.layout()
	var p: Vector2 = L["pause"]
	var near := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	if near.distance_to(p) < float(L["r_pause"]) + 2.0:
		return "pause"
	return ""


func _jump_clear(w: Node, hold: int, what: String) -> void:
	## A jump (held for hold ticks, a double jump if he has one): all the
	## way up and down his flame stays FEET_CLEAR clear of the HUD's blocks.
	var worst := ""
	var top := INF
	for i in 170:
		w.test_pad = {"jump": i < hold or (i >= hold + 6 and i < hold + 50 and w.player.double_jump)}
		w._read_pad()
		w.tick(DT)
		var r := _hero_view(w).grow(WorldScript.FEET_CLEAR - 0.5)
		top = minf(top, r.position.y)
		var k := _under_hud(w, r)
		if k != "" and worst == "":
			worst = "%s at view %s (tick %d)" % [k, _hero_view(w), i]
	w.test_pad = {}
	_check(worst == "", "%s: his flame stays clear of the HUD's blocks all through a jump (%s)" % [what, worst if worst != "" else "clear"])


func _feet_view(w: Node) -> float:
	return w.player.position.y - w.cam.y + Vector2(root.size).y * 0.5


func _test_floor_clear() -> void:
	## world.gd holds a standing hero's feet just over the thumb buttons, at
	## every button size: nothing on his floor (a Bonebow drawing on him, a
	## pickup) is behind the Special with its resource arc, or the flask,
	## standing or running either way. A full jump keeps his flame on the
	## glass; where a tell hangs over him the camera leans up to show it (no
	## further than the old line); a shooter behind a button or the HUD's
	## corner doesn't wake. Under the level there's stone as deep as it shows.
	_where = "floor clear"
	var kept = game.setting("button_scale")
	for k in [0.9, 1.0, 1.1]:
		game.set_setting("button_scale", k)
		_fresh_hero(6)
		var w = await _floor_world("1-1", 20)
		var L: Dictionary = w.touch.layout()
		var arc_top: float = float(L["special"].y) - float(L["r_special"]) - 5.25
		var flask_top: float = float(L["flask"].y) - float(L["r_flask"])
		var tag := "x%.1f" % k
		var feet := _feet_view(w)
		_check(w.player.on_floor and feet <= arc_top + 0.5 and feet <= flask_top,
				"%s standing: his floor (%.1f) is over the Special's arc (%.1f) and the flask (%.1f)" % [tag, feet, arc_top, flask_top])
		_check(feet >= arc_top - 10.0, "%s: and only just (no view spent under it): %.1f" % [tag, feet])
		for dir in [1, -1]:
			for i in 150:
				w.test_pad = {"right": dir > 0, "left": dir < 0}
				w._read_pad()
				w.tick(DT)
			feet = _feet_view(w)
			_check(w.player.on_floor and feet <= arc_top + 0.5 and feet <= flask_top,
					"%s running %s: his floor (%.1f) is still over both" % [tag, "right" if dir > 0 else "left", feet])
		# In plain view: over the Special no; out in the open, yes.
		var vr: Rect2 = w.view_rect()
		var under := Rect2(vr.position + Vector2(float(L["special"].x) - 11.0, float(L["special"].y) - 14.0), Vector2(22, 28))
		var open := Rect2(vr.position + Vector2(vr.size.x * 0.5 - 11.0, 120.0), Vector2(22, 28))
		var H: Dictionary = w.hud.layout()
		var sig: Rect2 = H["sigils"]
		var corner := Rect2(vr.position + sig.get_center() - Vector2(11, 14), Vector2(22, 28))
		_check(not w.in_plain_view(under) and w.in_plain_view(open) and not w.in_plain_view(corner),
				"%s: a thing behind the Special or the sigils isn't in plain view; one in the open is" % tag)
		var bow = w.spawn_enemy("bonebow", under.get_center() + Vector2(0, 14), {})
		bow.position = under.get_center() + Vector2(0, 14)
		_check(not bow.in_view(), "%s: a Bonebow behind the Special won't loose (in_view false)" % tag)
		bow.position = open.get_center() + Vector2(0, 14)
		_check(bow.in_view(), "%s: out in the open it may" % tag)
		w.enemies.erase(bow)
		bow.queue_free()
		# A full jump from standing: his flame stays on the glass.
		for i in 120:
			w.test_pad = {}
			w._read_pad()
			w.tick(DT)
		var top := INF
		for i in 100:
			w.test_pad = {"jump": i < 60}
			w._read_pad()
			w.tick(DT)
			top = minf(top, _feet_view(w))
		_check(top - HERO_TALL >= 4.0, "%s: a full jump's top keeps his flame on the glass (its tip at %.1f)" % [tag, top - HERO_TALL])
		w.queue_free()
		await _frames(2)
	game.set_setting("button_scale", kept)
	# A drip spout hanging 224 px over 2-1's floor: the camera leans up to show it.
	_fresh_hero(6)
	var w2 = await _floor_world("2-1", 12)
	var spout: Vector2 = Vector2.ZERO
	for sp in w2.features.spouts:
		if sp["cell"] == Vector2i(7, 6):
			spout = sp["tip"]
	var lean: float = w2.look_up()
	var tip_view: float = spout.y - w2.cam.y + Vector2(root.size).y * 0.5
	_check(lean > 0.0 and lean <= WorldScript.LOOK_UP_MAX and tip_view >= 0.0,
			"under a high drip spout the camera leans up %.1f px (at most %.0f): its nozzle is on the glass (%.1f)" % [lean, WorldScript.LOOK_UP_MAX, tip_view])
	w2.queue_free()
	await _frames(2)
	var TileViewS: GDScript = load("res://scripts/tile_view.gd")
	_check(float(TileViewS.BEDROCK_ROWS * 32) >= WorldScript.BELOW, "the stone under a level (%d rows) is as deep as the camera shows (%.0f px)" % [TileViewS.BEDROCK_ROWS, WorldScript.BELOW])
	await _test_flits_shown()
	await _test_head_clear()
	await _test_see_through()


func _test_flits_shown() -> void:
	## A Flit's wind-up and a Gutterwing nest's tell are never off the glass:
	## the camera leans up to show a Flit roosting high over his floor (its
	## bob and the rise of its wind-up too) and a nest, and one it can't
	## show waits (a Flit winds up, and a nest breeds, only in plain view).
	_where = "flits shown"
	_fresh_hero(3)
	var w = await _floor_world("1-2", 127)
	var bat: Node2D = null
	for e in w.enemies:
		if e.kind == "bat" and absf(e.home.x - (127 * 32 + 16)) < 48.0:
			bat = e
	var lean: float = w.look_up()
	var vr: Rect2 = w.view_rect()
	_check(bat != null and lean > 0.0 and lean <= WorldScript.LOOK_UP_MAX and bat.reach_rect().position.y >= vr.position.y,
			"1-2: under the Flit roosting 208 px over his floor the camera leans up %.1f px: its bob and wind-up are on the glass (top %.1f, view top %.1f)" % [
				lean, bat.reach_rect().position.y if bat else 0.0, vr.position.y])
	# He jumps up under it: it winds up, all of it on the glass.
	var winds := 0
	var hidden := 0
	for i in 170:
		w.test_pad = {"jump": i < 60}
		w._read_pad()
		w.tick(DT)
		if bat != null and bat.alive and str(bat._state) == "windup":
			winds += 1
			if not w.in_plain_view(bat.rect()):
				hidden += 1
	w.test_pad = {}
	_check(winds > 0 and hidden == 0, "a jump under it: it winds up (%d ticks) in plain view the whole time (%d ticks not)" % [winds, hidden])
	# A Flit where its wind-up would be off the glass doesn't start one.
	for i in 240:
		w.tick(DT)
	var pl: Node2D = w.player
	var hi: Node2D = w.spawn_enemy("bat", pl.center() + Vector2(40, -120), {})
	hi.home = hi.position
	w.cam.y = hi.position.y + Vector2(root.size).y * 0.5 - 4.0   # its top a few px over the view's top
	hi._timer = 0.0
	hi.think(DT, pl)
	_check(not hi.tell_shows() and str(hi._state) == "hover", "a Flit in range with its wind-up off the glass waits (%s)" % hi._state)
	w.cam.y = pl.position.y - 40.0
	hi.position = hi.home
	hi._timer = 0.0
	hi.think(DT, pl)
	_check(hi.tell_shows() and str(hi._state) == "windup", "in plain view it winds up (%s)" % hi._state)
	w.enemies.erase(hi)
	hi.queue_free()
	w.queue_free()
	await _frames(2)
	# A Gutterwing nest over 2-3's floor: leaned to, and one off the glass waits
	# (Build 2's switchback: the nest in the drop, over the stair's foot).
	_fresh_hero(11)
	var w3 = await _floor_world("2-3", 102)
	var nest: Dictionary = {}
	for n in w3.features.nests:
		if n["cell"] == Vector2i(102, 15):
			nest = n
	var nlean: float = w3.look_up()
	var nr: Rect2 = w3.features.nest_rect(nest) if not nest.is_empty() else Rect2()
	_check(not nest.is_empty() and nlean > 0.0 and nr.position.y >= w3.view_rect().position.y,
			"2-3: under the nest 222 px over his floor the camera leans up %.1f px: the sconce is on the glass" % nlean)
	nest["tell"] = -1.0
	nest["cool"] = 0.0
	nest["wings"] = []
	var keep: Vector2 = w3.cam
	w3.cam.y = float(nest["cocoon"].y) + Vector2(root.size).y * 0.5 + 12.0   # the cocoon over the view's top
	w3.features._nest_step(nest, DT, w3.player)
	_check(float(nest["tell"]) < 0.0, "a nest in range with its cocoon off the glass doesn't start its tell")
	w3.cam = keep
	w3.features._nest_step(nest, DT, w3.player)
	_check(float(nest["tell"]) >= 0.0, "on the glass it does")
	w3.queue_free()
	await _frames(2)


func _test_see_through() -> void:
	## Out in the level, a jump's top takes his flame up into the top band:
	## the boss bar, a title or level-up card and the message slot go
	## see-through while he's behind them, and come back as he comes down.
	## Standing, nothing is.
	_where = "see-through"
	_fresh_hero(6)
	var w = await _floor_world("1-1", 20)
	var hud = w.hud
	hud.boss_bar({"id": "tollgrave", "name": "Old Tollgrave", "title": "The Bell Warden", "frac": 1.0, "phases": [0.6], "awake": true})
	hud._title = {}
	hud._lvl = {}
	for i in 90:
		hud._process(1.0 / 60.0)
	_check(hud.boss_alpha() >= 0.99 and hud.see("msg") >= 0.99, "standing, the boss bar and the message slot show whole (%.2f)" % hud.boss_alpha())
	var low := 1.0
	var low_msg := 1.0
	for i in 170:
		w.test_pad = {"jump": i < 60}
		w._read_pad()
		w.tick(DT)
		hud._process(DT)
		low = minf(low, hud.boss_alpha())
		low_msg = minf(low_msg, hud.see("msg"))
	_check(low <= HudScript.SEE_THROUGH + 0.05 and low_msg <= HudScript.SEE_THROUGH + 0.05,
			"a jump's top under the boss bar: it goes see-through (%.2f), and so does the message slot (%.2f)" % [low, low_msg])
	for i in 120:
		w.tick(DT)
		hud._process(DT)
	_check(hud.boss_alpha() >= 0.99, "back on the floor, it's whole again (%.2f)" % hud.boss_alpha())
	hud.boss_bar({})
	hud.title_card("1-1", "The Nave")
	for i in 40:
		hud._process(1.0 / 60.0)
	var full: float = hud.title_alpha()
	var card_low := 1.0
	for i in 110:
		w.test_pad = {"jump": i < 60}
		w._read_pad()
		w.tick(DT)
		hud._process(DT)
		card_low = minf(card_low, hud.see("card"))
	w.test_pad = {}
	_check(full >= 0.99 and card_low <= HudScript.SEE_THROUGH + 0.05, "a title card he jumps up behind goes see-through (%.2f, whole %.2f)" % [card_low, full])
	w.queue_free()
	await _frames(2)


func _test_head_clear() -> void:
	## At every level's start (and at the far end of two), where the camera
	## stops at the level's edge and he stands under the HUD's corner blocks,
	## a full jump and a double jump keep his flame clear of them: the
	## camera goes up with him sooner there (world.gd head_top).
	_where = "head clear"
	var kept = game.setting("button_scale")
	for k in [0.9, 1.0, 1.1]:
		game.set_setting("button_scale", k)
		for id in ["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4"]:
			for double in ([false, true] if k == 1.0 else [false]):
				_fresh_hero(6)
				var w = await _floor_world(id, -1)
				w.player.double_jump = double
				var hr := _hero_view(w)
				var tag := "%s start (x%.1f)" % [id, k]
				_check(_under_hud(w, hr.grow(WorldScript.FEET_CLEAR - 0.5)) == "", "%s: standing, he's clear of the HUD (%s)" % [tag, hr])
				_jump_clear(w, 60, "%s, %s" % [tag, "a double jump" if double else "a full jump"])
				w.queue_free()
				await _frames(2)
	game.set_setting("button_scale", kept)
	for id in ["1-1", "2-1"]:
		_fresh_hero(6)
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		var w = await _floor_world(id, lv.width - 3)
		_jump_clear(w, 60, "%s's far end (under the pause button)" % id)
		w.queue_free()
		await _frames(2)
		# Running on under the sigils mid-jump: the stop eases in, so the
		# camera never jolts, and his flame still stays clear.
		_fresh_hero(6)
		w = await _floor_world(id, lv.width - 10)
		var last: float = w.cam.y
		var jolt := 0.0
		var under := ""
		for i in 150:
			w.test_pad = {"jump": i < 60, "right": true}
			w._read_pad()
			w.tick(DT)
			jolt = maxf(jolt, absf(w.cam.y - last))
			last = w.cam.y
			var k := _under_hud(w, _hero_view(w))
			if k != "" and under == "":
				under = "%s at tick %d" % [k, i]
		_check(jolt <= WorldScript.HEAD_EASE * DT + 6.0, "%s: running on under the blocks mid-jump, the camera never jolts (at most %.1f px a tick)" % [id, jolt])
		_check(under == "", "%s: and his flame isn't behind them (%s)" % [id, under if under != "" else "clear"])
		w.queue_free()
		await _frames(2)


func _test_quiet_discs() -> void:
	## The Special and the flask sit in the play lane at the hero's height:
	## at rest they're rings with a faint fill (the world reads through) and
	## their icons at about the decided idle alpha of 0.45; pressed, they
	## light up.
	_where = "quiet discs"
	for grey in [false, true]:
		var idle: Dictionary = TouchScript.special_look(false, grey)
		var down: Dictionary = TouchScript.special_look(true, grey)
		var tag := "the Special%s" % (" (can't afford)" if grey else "")
		_check((idle["fill"] as Color).a <= 0.15, "%s at rest: a faint fill (%.2f)" % [tag, (idle["fill"] as Color).a])
		_check((idle["icon"] as Color).a >= 0.4 and (idle["icon"] as Color).a <= 0.605, "%s at rest: its icon at about 0.45-0.55 (%.2f)" % [tag, (idle["icon"] as Color).a])
		if not grey:
			_check((down["icon"] as Color).a >= 0.9 and (down["fill"] as Color).a > (idle["fill"] as Color).a, "%s pressed lights up" % tag)
	for empty in [false, true]:
		var idle: Dictionary = TouchScript.flask_look(false, empty)
		var tag := "the flask%s" % (" (dry)" if empty else "")
		_check((idle["fill"] as Color).a <= 0.15, "%s at rest: a faint fill (%.2f)" % [tag, (idle["fill"] as Color).a])
		_check((idle["icon"] as Color).a <= 0.605, "%s at rest: its icon quiet (%.2f)" % [tag, (idle["icon"] as Color).a])
	_check((TouchScript.flask_look(true)["icon"] as Color).a >= 0.9, "the flask held lights up")


func _test_touch_roles() -> void:
	_where = "touch"
	_fresh_hero(1)
	var touch = TouchScript.new()
	root.add_child(touch)
	await _frames(1)
	var L: Dictionary = touch.layout()
	_check(touch.role_at(L["pause"]) == "pause", "pause first")
	_check(touch.role_at(L["flask"]) == "flask", "the flask")
	_check(touch.role_at(L["flask"] + Vector2(0, L["r_flask"] * 1.1)) == "move", "just off the flask is a move (its hit zone is r×1.0)")
	_check(touch.role_at(L["left"]) == "move" and touch.role_at(L["right"]) == "move", "the arrows are the move zone")
	for b in ["jump", "attack", "special"]:
		_check(touch.role_at(L[b]) == b, "%s on its own centre" % b)
	var between: Vector2 = (L["jump"] + L["attack"]) * 0.5
	_check(touch.role_at(between) == "jump", "between jump and attack, the bigger jump wins")
	# A tap on the flask: nothing moves, and it only drinks after 0.2 s.
	touch._begin(0, L["flask"])
	touch._process(0.1)
	_check(not touch.is_down("flask"), "not yet at 0.1 s")
	_check(not touch.is_down("left") and not touch.is_down("right"), "a tap on the flask doesn't move")
	touch._process(0.12)
	_check(touch.is_down("flask"), "held 0.2 s: it drinks")
	_check(Input.is_action_pressed("flask"), "the flask action is pressed")
	touch._end(0)
	_check(not touch.is_down("flask") and not Input.is_action_pressed("flask"), "let go: released")
	# A quick brush of the flask never drinks.
	touch._begin(1, L["flask"])
	touch._process(0.08)
	touch._end(1)
	touch._process(0.3)
	_check(not touch.is_down("flask"), "a brush of the flask doesn't drink")
	# A touch that began as a move never drinks, even held on the flask.
	touch._begin(2, L["left"])
	_check(touch.is_down("left"), "the move starts on the left arrow")
	touch._touches[2]["pos"] = L["flask"]
	touch._refresh()
	for i in 30:
		touch._process(0.02)
	_check(not touch.is_down("flask"), "a move slid onto the flask never drinks")
	touch._end(2)
	# Sliding off the flask cancels it.
	touch._begin(3, L["flask"])
	touch._process(0.1)
	touch._touches[3]["pos"] = L["flask"] + Vector2(90, 0)
	touch._process(0.2)
	_check(not touch.is_down("flask"), "sliding off the flask cancels the drink")
	touch._end(3)
	# The pickup card takes the tap before the move zone.
	var hs := GDScript.new()
	hs.source_code = "extends Node\nvar taps := 0\nvar r := Rect2()\nfunc card_hit(p):\n\treturn r.has_point(p)\nvar confirm := false\nfunc tap_card(c := false):\n\ttaps += 1\n\tconfirm = c\n\treturn true\n"
	hs.reload()
	var stub = hs.new()
	var s: Rect2 = UI.safe_override
	stub.r = Rect2(s.get_center().x - 160.0, s.end.y - 100.0, 320.0, 90.0)
	root.add_child(stub)
	touch.hud = stub
	var p := Vector2(stub.r.position.x + 20.0, stub.r.get_center().y)
	_check(p.x < root.get_visible_rect().size.x * 0.45, "(the probe is in the move half)")
	touch._begin(4, p)
	_check(stub.taps == 1, "a tap on the card goes to the HUD")
	_check(stub.confirm, "as a touch, so a tap that would melt the worn piece asks first")
	_check(str(touch._touches.get(4, {}).get("role", "")) == "card" and not touch.is_down("left") and not touch.is_down("right"),
			"and doesn't move Waxby (the touch is kept as the card's, pressing nothing)")
	touch._end(4)
	stub.r = Rect2()
	touch._begin(5, p)
	_check(touch._touches.has(5) and touch._touches[5]["role"] == "move", "without a card the same spot is a move")
	touch._end(5)
	# The button size setting.
	game.set_setting("button_scale", 1.1)
	touch.apply_settings()
	var L2: Dictionary = touch.layout()
	_check(is_equal_approx(touch.button_scale, 1.1) and is_equal_approx(L2["r_jump"], 55.0), "button size L scales the radii")
	_check(L2["jump"].distance_to(L2["attack"]) > L["jump"].distance_to(L["attack"]), "and the centres")
	game.set_setting("button_scale", 1.0)
	touch.release_all()
	touch.queue_free()
	stub.queue_free()
	await _frames(2)


func _test_flask_slide() -> void:
	## A thumb held on the flask, then slid down onto the arrows, runs:
	## it becomes a move (drunk or not), without reading as a slide down.
	_where = "flask slide"
	_fresh_hero(1)
	var touch = TouchScript.new()
	root.add_child(touch)
	await _frames(1)
	var L: Dictionary = touch.layout()
	for drink in [true, false]:
		var tag := "after the drink" if drink else "before the drink"
		touch._begin(0, L["flask"])
		touch._process(0.25 if drink else 0.05)
		_check(touch.is_down("flask") == drink, "(%s: the flask is %s)" % [tag, "drunk" if drink else "not yet drunk"])
		# The thumb slides down to the right arrow over a few frames.
		for k in range(1, 7):
			touch._touches[0]["pos"] = (L["flask"] as Vector2).lerp(L["right"], k / 6.0)
			touch._refresh()
			touch._process(1.0 / 60.0)
		_check(touch._touches.has(0) and touch._touches[0]["role"] == "move", "%s: a thumb slid off the flask becomes a move" % tag)
		_check(touch.is_down("right") and not touch.is_down("flask"), "%s: on the right arrow, Waxby runs right" % tag)
		_check(not touch.is_down("down"), "%s: coming down onto the arrows isn't a drop" % tag)
		# Then on to the left arrow, and further down: a real slide down.
		touch._touches[0]["pos"] = L["left"]
		touch._refresh()
		_check(touch.is_down("left") and not touch.is_down("right"), "%s: it slides across to the left" % tag)
		touch._touches[0]["pos"] = (L["left"] as Vector2) + Vector2(0, 40)
		touch._refresh()
		_check(touch.is_down("down"), "%s: and below the arrows it holds down" % tag)
		touch._end(0)
		touch._process(0.3)
		_check(not touch.is_down("flask"), "%s: it never drinks after" % tag)
	touch.release_all()
	touch.queue_free()
	await _frames(2)


func _test_thumb_pad() -> void:
	## Build 1's lit thumb pad: down counts once the thumb is SLIDE (26 px)
	## below where it landed (less where the glass below is shorter), up
	## SLIDE above. A slide within SNAP (25 degrees) of straight down or up
	## lets go of left and right; a slanted one keeps the diagonal. Each
	## switches on with one tick (none with haptics off). The chevrons and
	## the idle tick draw.
	_where = "thumb pad"
	_fresh_hero(1)
	var touch = TouchScript.new()
	root.add_child(touch)
	await _frames(1)
	var L: Dictionary = touch.layout()
	var bottom: float = touch._glass_bottom()
	var a: Vector2 = L["left"]
	_check(is_equal_approx(TouchScript.SLIDE, 26.0), "the slide is 26 px (it was 34)")
	_check(is_equal_approx(TouchScript.slide_need(a.y, bottom), TouchScript.SLIDE),
			"landing on the arrows' row, down needs the whole slide (%.0f px of glass below)" % (bottom - a.y))
	_check(is_equal_approx(TouchScript.slide_need(bottom - 20.0, bottom), 14.0), "landing 20 px over the glass's edge, it needs 14")
	_check(is_equal_approx(TouchScript.slide_need(bottom - 3.0, bottom), TouchScript.SLIDE_MIN), "and never less than %.0f" % TouchScript.SLIDE_MIN)
	game.set_setting("haptics", true)
	# Straight down from the left arrow: nothing at 25 px, pure down past 26.
	var b0: int = touch.buzzes
	touch._begin(0, a)
	_check(touch.is_down("left") and not touch.is_down("down"), "the thumb lands on the left arrow: left")
	var at := func(off: Vector2) -> void:
		touch._touches[0]["pos"] = a + off
		touch._refresh()
	at.call(Vector2(0, 25))
	_check(touch.is_down("left") and not touch.is_down("down"), "25 px down: still only left")
	_check(touch.buzzes == b0, "(no tick yet)")
	at.call(Vector2(0, 27))
	_check(touch.is_down("down") and not touch.is_down("left") and not touch.is_down("right"), "27 px straight down: pure down (left let go)")
	_check(Input.is_action_pressed("down") and not Input.is_action_pressed("left"), "(the actions follow)")
	_check(touch.buzzes == b0 + 1, "one tick as down switches on (%d)" % (touch.buzzes - b0))
	at.call(Vector2(8, 34))
	_check(touch.is_down("down") and not touch.is_down("left") and touch.buzzes == b0 + 1, "a steep slide (13 degrees off) stays pure down, with no second tick")
	at.call(Vector2(-17, 40))
	_check(touch.is_down("down") and not touch.is_down("left"), "23 degrees off straight down: still pure down")
	at.call(Vector2(-21, 40))
	_check(touch.is_down("down") and touch.is_down("left"), "28 degrees off: the diagonal, down and left")
	at.call(Vector2(-30, 30))
	_check(touch.is_down("down") and touch.is_down("left"), "a 45 degree slide keeps the diagonal")
	at.call(Vector2(0, 10))
	_check(touch.is_down("left") and not touch.is_down("down"), "back up near where it landed: left again")
	at.call(Vector2(0, -27))
	_check(touch.is_down("up") and not touch.is_down("down") and not touch.is_down("left"), "27 px straight up: pure up")
	_check(touch.buzzes == b0 + 2, "with its own tick (%d)" % (touch.buzzes - b0))
	at.call(Vector2(-24, -30))
	_check(touch.is_down("up") and touch.is_down("left"), "slanted up keeps the diagonal")
	at.call(Vector2(0, -20))
	_check(touch.is_down("left") and not touch.is_down("up"), "20 px up: no up")
	# The chevrons draw while the thumb is down (and with nothing held).
	at.call(Vector2(0, 30))
	touch._view.queue_redraw()
	await _frames(2)
	touch._end(0)
	_check(not touch.is_down("down") and not touch.is_down("left"), "let go: nothing held")
	# A thumb landing low on the glass: down at its room less 6 px.
	var low := Vector2(a.x, bottom - 18.0)
	touch._begin(1, low)
	touch._touches[1]["pos"] = low + Vector2(0, 13)
	touch._refresh()
	_check(touch.is_down("down"), "a thumb landing 18 px over the glass's edge holds down 13 px lower (it needs %.0f)" % TouchScript.slide_need(low.y, bottom))
	touch._end(1)
	# Haptics off: no tick.
	game.set_setting("haptics", false)
	var b1: int = touch.buzzes
	touch._begin(2, a)
	touch._touches[2]["pos"] = a + Vector2(0, 30)
	touch._refresh()
	_check(touch.is_down("down") and touch.buzzes == b1, "haptics off: down, without the tick")
	touch._end(2)
	game.set_setting("haptics", true)
	# A thumb creeping down over a long run keeps running (only a quick slide
	# lets go of left and right): 30 px straight down over 2 s on the right
	# arrow holds right and down; the same 30 px in 0.05 s is pure down.
	var ra: Vector2 = L["right"]
	touch._begin(3, ra)
	for i in 120:
		touch._process(1.0 / 60.0)
		touch._touches[3]["pos"] = ra + Vector2(0, 30.0 * (i + 1) / 120.0)
		touch._refresh()
	_check(touch.is_down("right") and touch.is_down("down"), "a slow 30 px creep down through a 2 s right hold keeps right held")
	touch._end(3)
	touch._begin(4, ra)
	for i in 3:
		touch._process(1.0 / 60.0)
		touch._touches[4]["pos"] = ra + Vector2(0, 10.0 * (i + 1))
		touch._refresh()
	_check(touch.is_down("down") and not touch.is_down("right"), "a quick 30 px slide down from the right arrow is pure down")
	touch._touches[4]["pos"] = ra + Vector2(0, 5)
	touch._refresh()
	_check(touch.is_down("right") and not touch.is_down("down"), "back near where it landed: right again")
	touch._end(4)
	# The idle tick (no move touch), lit by a key's down.
	Input.action_press("down")
	touch._view.queue_redraw()
	await _frames(2)
	Input.action_release("down")
	touch.release_all()
	touch.queue_free()
	await _frames(2)


func _tip_shown(hud, id: String) -> Dictionary:
	## The card with this id, queued or up in the top band ({} when neither).
	for c in hud._cardq:
		if str(c["id"]) == id:
			return c
	return hud._title if str(hud._title.get("id", "")) == id else {}


func _test_thumb_tips() -> void:
	## The lit thumb pad's one-time cards: "Slide your thumb down to drop"
	## the first time Waxby stands on a ledge, "Slide up to climb" the first
	## time he catches a vine, once a save (Game.seen); never for the
	## autoplay bot, headless, or a pad a test or a golden route feeds (a
	## replay, or the recorder's on_pad). Their words fit the band at 12 px
	## or more at every size.
	_where = "thumb tips"
	var lines := []
	for y in 15:
		var row := ".".repeat(40)
		if y >= 4 and y <= 10:
			row = row.substr(0, 30) + "{" + row.substr(31)
		if y == 9:
			row = "...." + "=".repeat(10) + row.substr(14)
		if y >= 13:
			row = "#".repeat(40)
		lines.append(row)
	lines[12] = "P" + lines[12].substr(1)
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n---\n" + "\n".join(lines))
	for case in ["player", "again", "autoplay", "headless", "test pad", "route recorder"]:
		_fresh_hero(3)
		if case == "again":
			game.mark_seen("tip:drop")
			game.mark_seen("tip:climb")
		var w = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await _frames(1)
		w.set_physics_process(false)   # (ticked here)
		var hud = HudScript.new()
		hud.world = w
		hud.story = _stub_story()
		hud._story_checked = true
		w.hud = hud
		w.add_child(hud)
		await _frames(1)
		w.headless = case == "headless"
		w.autoplay = case == "autoplay"
		w.test_pad = {} if case == "test pad" else null
		if case == "route recorder":
			w.on_pad = func(_pad: Dictionary) -> void: pass
		# On the ledge.
		w.player.reset_at(Vector2(8.5 * 32.0, 9.0 * 32.0))
		for i in 12:
			w.tick(DT)
		var on_ledge: bool = w.player.on_ledge()
		var drop := _tip_shown(hud, "tip:drop")
		# On the vine.
		w.player.reset_at(Vector2(30.5 * 32.0, 7.0 * 32.0))
		w.player.grab_vine(30, 1.0)
		for i in 6:
			w.tick(DT)
		var climbing: bool = w.player.climbing
		var climb := _tip_shown(hud, "tip:climb")
		_check(on_ledge and climbing, "%s: (he stood on the ledge, then hung on the vine)" % case)
		if case == "player":
			_check(str(drop.get("title", "")) == "Slide your thumb down to drop" and game.seen("tip:drop"),
					"on his first ledge: \"Slide your thumb down to drop\", marked seen (%s)" % [drop])
			_check(str(climb.get("title", "")) == "Slide up to climb" and game.seen("tip:climb"),
					"on his first vine: \"Slide up to climb\", marked seen (%s)" % [climb])
		elif case == "again":
			_check(drop.is_empty() and climb.is_empty(), "seen once: never again")
		else:
			_check(drop.is_empty() and climb.is_empty() and not game.seen("tip:drop") and not game.seen("tip:climb"),
					"%s: no card, nothing marked" % case)
		w.headless = true   # (leaving writes nothing)
		w.queue_free()
		await _frames(1)
	for size in SIZES:
		await _set_view(size, true)
		var sw := _stub_world()
		root.add_child(sw)
		var hud = HudScript.new()
		hud.world = sw
		sw.add_child(hud)
		await _frames(1)
		for id in WorldScript.TIPS:
			var t: Array = WorldScript.TIPS[id]
			var r: Rect2 = hud.band_card_rect(str(t[0]), str(t[1]))
			var fs: int = UI.fit_size(str(t[1]), r.size.x - 24.0, 14, 10)
			_check(fs >= 12, "%s's words fit the band at %d px (%d wide)" % [id, fs, size.x])
		sw.queue_free()
		await _frames(1)
	await _set_view(Vector2i(847, 390), true)
	_where = "thumb tips"


func _test_card_claims() -> void:
	## Only an item card inside its tap window claims a touch. A relic card
	## (it takes no tap) or an item card fading out lets the thumb through.
	_where = "card claims"
	_fresh_hero(1)
	var w := _stub_world()
	root.add_child(w)
	var touch = TouchScript.new()
	w.touch = touch
	w.add_child(touch)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	touch.hud = hud
	w.add_child(hud)
	await _frames(1)
	var r: Rect2 = hud.card_slot()
	var p := Vector2(r.position.x + 44.0, r.get_center().y)
	_check(p.x < root.get_visible_rect().size.x * 0.45, "(the probe is in the move half)")
	hud.relic_found("rook_feather")
	hud._process(0.05)
	_check(hud._card.get("kind", "") == "relic", "(a relic card is up)")
	_check(not hud.card_hit(p) and touch.role_at(p) == "move", "a relic card takes no tap: a thumb on it moves (%s)" % touch.role_at(p))
	touch._begin(1, p)
	_check(touch.is_down("left") or touch.is_down("right"), "and Waxby moves")
	touch._end(1)
	hud._card = {}
	hud._cards.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	hud.show_pickup(Items.make("coat", "knight", 2, "magic", rng), {"dmg": 0.0, "life": 1.0}, "satchel")
	hud._process(0.05)
	_check(hud.card_hit(p) and touch.role_at(p) == "card", "an item card in its window takes the tap")
	# On the phone the card's edge comes within a few px of attack: a right
	# thumb landing just off attack, level with it, still swings, and a card
	# tap never happens from there.
	var T: Dictionary = touch.layout()
	var off_attack: Vector2 = T["attack"] - Vector2(float(T["r_attack"]) + 4.0, 0.0)
	_check(hud.card_rect().grow(4.0).has_point(off_attack), "(4 px off attack is inside the card's reach)")
	_check(touch.role_at(off_attack) == "attack", "4 px off attack is still attack (%s)" % touch.role_at(off_attack))
	var taps0: String = str(hud._card.get("where", ""))
	touch._begin(2, off_attack)
	_check(touch.is_down("attack") and str(hud._card.get("where", "")) == taps0 and float(hud._card["tap_left"]) < HudScript.CARD_TAP,
			"it swings, and the card isn't tapped")
	touch._end(2)
	var off_right: Vector2 = T["right"] + Vector2(float(T["r_move"]) + 4.0, 0.0)
	_check(hud.card_rect().grow(4.0).has_point(off_right), "(4 px off the right arrow is inside the card's reach)")
	touch._begin(3, off_right)
	_check(touch.is_down("right") and float(hud._card["tap_left"]) < HudScript.CARD_TAP, "4 px off the right arrow, Waxby runs right; the card isn't tapped")
	touch._end(3)
	# Where a phone review's thumbs landed (847x390, the island's inset each
	# side): just right of the right arrow, 26 px past it in the move zone,
	# and just left of attack. Each is the button's, never the card's.
	if root.get_visible_rect().size.x == 847.0:
		var want := {Vector2(269, 326): "move", Vector2(283, 316): "move", Vector2(572, 326): "attack", Vector2(564, 326): "attack"}
		for q in want:
			_check(hud.card_rect().grow(4.0).has_point(q), "(%s is over the card)" % q)
			_check(touch.role_at(q) == want[q], "a thumb at %s is %s, not the card (%s)" % [q, want[q], touch.role_at(q)])
	var near_right: Vector2 = T["right"] + Vector2(float(T["r_move"]) + 12.0, 0.0)
	var near_attack: Vector2 = T["attack"] - Vector2(float(T["r_attack"]) + 12.0, 0.0)
	_check(touch.role_at(near_right) == "move" and touch.role_at(near_attack) == "attack" and touch.role_at(hud.card_rect().get_center()) == "card",
			"12 px past the right arrow moves, 12 px past attack swings, the card's middle is the card's")
	# An auto-equipped upgrade's card: a thumb running right 26 px past the
	# arrow runs, and the new piece stays on.
	hud._card = {}
	hud._cards.clear()
	var worn_before = game.hero()["equip"]["coat"]
	var up: Dictionary = Items.make("coat", "knight", 6, "rare", rng)
	game.equip(up)
	hud.show_pickup(up, {"dmg": 0.0, "life": 9.0}, "equipped")
	hud._process(0.05)
	var run_at: Vector2 = T["right"] + Vector2(float(T["r_move"]) + 26.0, -10.0)
	_check(hud.card_rect().grow(4.0).has_point(run_at), "(26 px past the right arrow is over the card)")
	touch._begin(5, run_at)
	_check(touch.is_down("right"), "an equipped card up: a thumb 26 px past the right arrow runs right")
	_check(str(hud._card.get("where", "")) == "equipped" and str(game.hero()["equip"]["coat"]["uid"]) == str(up["uid"]),
			"and the upgrade stays on (the card isn't tapped)")
	touch._end(5)
	# A thumb that did land on the card, then slides off it into the move
	# zone: it runs from there (not dead until it lifts).
	var on_card: Vector2 = Vector2(hud.card_rect().position.x + 110.0, hud.card_rect().get_center().y)
	_check(touch.role_at(on_card) == "card", "(the card's own middle-left is the card's)")
	touch._begin(6, on_card)
	var drag := InputEventScreenDrag.new()
	drag.index = 6
	drag.position = T["left"] + Vector2(-4.0, 0.0)
	touch._input(drag)
	_check(touch.is_down("left") and not touch.is_down("flask"), "a thumb sliding off the card onto the left arrow runs left")
	touch._end(6)
	_check(not touch.is_down("left"), "and stops when it lifts")
	if worn_before != null:
		game.equip(worn_before)
	var n := 0
	while not hud._card.is_empty() and float(hud._card["tap_left"]) > 0.0 and n < 600:
		hud._process(1.0 / 60.0)
		n += 1
	_check(not hud._card.is_empty(), "(the card is fading out)")
	_check(not hud.card_hit(p) and touch.role_at(p) == "move", "fading, it lets the thumb through")
	touch.release_all()
	w.queue_free()
	await _frames(2)


func _test_card_rest() -> void:
	## A first pair of boots (or a first charm) worn in an empty slot: its
	## card says just "Equipped" and takes no tap (there's nothing to swap
	## back to). A thumb resting on a card stays the card's, pressing
	## nothing, even once the card stops taking taps, until it slides off
	## the card or toward a button. A level-up that cuts a title card short
	## comes in only once the title has gone.
	_where = "card rest"
	_fresh_hero(1)
	var w := _stub_world()
	root.add_child(w)
	var touch = TouchScript.new()
	w.touch = touch
	w.add_child(touch)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	touch.hud = hud
	w.add_child(hud)
	await _frames(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var h: Dictionary = game.hero()
	h["equip"]["boots"] = null
	var boots: Dictionary = Items.make("boots", "knight", 3, "magic", rng)
	game.equip(boots)
	hud.show_pickup(boots, {"dmg": 0.0, "life": 3.0}, "equipped")
	hud._process(0.05)
	var p: Vector2 = hud.card_rect().get_center()
	_check(str(hud._card.get("where", "")) == "equipped" and float(hud._card["tap_left"]) <= 0.0 and not hud.card_hit(p),
			"boots worn in an empty slot: the card takes no tap")
	for i in 3:
		hud._process(0.05)
	await _frames(2)
	var said := str(hud.card_line)
	_check(said.to_lower().find("undo") < 0, "and doesn't offer an undo ('%s')" % said)
	for i in 60:
		hud._process(1.0 / 60.0)
	_check(not hud._card.is_empty(), "it stays up a while all the same")
	hud._card = {}
	hud._cards.clear()
	# A coat card that takes a tap: the thumb lands on it, then the card stops
	# taking taps (the next card's turn): a 1 px jitter presses nothing.
	var coat: Dictionary = Items.make("coat", "knight", 2, "magic", rng)
	hud.show_pickup(coat, {"dmg": 0.0, "life": 1.0}, "satchel")
	hud._process(0.05)
	# On the card's left part, over the move half of the glass: a thumb there
	# that turned into a move would run.
	var on: Vector2 = Vector2(hud.card_rect().position.x + 60.0, hud.card_rect().get_center().y)
	_check(touch.role_at(on) == "card" and on.x < root.get_visible_rect().size.x * 0.45, "(the thumb lands on the card, over the move half)")
	touch._begin(7, on)
	hud._card["tap_left"] = 0.0
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = on + Vector2(1, 0)
	touch._input(drag)
	var pressed := []
	for a in ["left", "right", "down", "jump", "attack", "special", "flask"]:
		if touch.is_down(a):
			pressed.append(a)
	_check(pressed.is_empty() and str(touch._touches[7]["role"]) == "card", "a resting thumb's 1 px jitter presses nothing once the card is spent (%s)" % [pressed])
	var T: Dictionary = touch.layout()
	drag.position = T["left"] + Vector2(-4.0, 0.0)
	touch._input(drag)
	_check(touch.is_down("left"), "and sliding off onto the left arrow runs")
	touch._end(7)
	touch.release_all()
	hud._card = {}
	hud._cards.clear()
	# A level-up cuts a title card short: never both on the glass.
	hud.title_card("1-1", "The Nave")
	for i in 60:
		hud._process(1.0 / 60.0)
	hud.level_up(3)
	var both := 0.0
	var gone_at := -1.0
	for i in 60:
		hud._process(1.0 / 60.0)
		both = maxf(both, minf(hud.title_alpha(), hud.level_alpha()))
		if gone_at < 0.0 and hud._title.is_empty():
			gone_at = i / 60.0
	_check(both < 0.01, "a level-up that cuts a title card short comes in once it has gone (overlap %.2f)" % both)
	_check(gone_at >= 0.0 and gone_at <= HudScript.TITLE_CUT + 0.05 and hud.level_alpha() > 0.9,
			"the title goes within %.2f s (%.2f) and the level-up card is up" % [HudScript.TITLE_CUT, gone_at])
	w.queue_free()
	await _frames(2)


func _test_flask_drinks() -> void:
	## In a real level a held flask drinks: the press reaches the World's tick.
	_where = "flask in a level"
	_fresh_hero(1)
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var w = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await _frames(1)
	var touch = TouchScript.new()
	w.touch = touch
	w.add_child(touch)
	await _frames(2)
	w.test_pad = null
	w.player.hp = w.player.max_hp * 0.5
	var charges: int = w.flask_charges
	var L: Dictionary = touch.layout()
	touch._begin(9, L["flask"])
	for i in 60:
		await physics_frame
	touch._end(9)
	await physics_frame
	_check(w.flask_charges == charges - 1, "holding the flask drinks one charge (%d -> %d)" % [charges, w.flask_charges])
	_check(w.player.hp > w.player.max_hp * 0.5, "and heals")
	touch.release_all()
	w.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the Sheet

func _sheet(tab: String):
	var h = load("res://scripts/hero_screen.gd").new()
	root.add_child(h)
	h.open_tab(tab)
	await _frames(2)
	return h


func _test_skills() -> void:
	_where = "skills"
	_fresh_hero(9)
	var h = await _sheet("skills")
	var changes := [0]
	h.changed.connect(func(): changes[0] += 1)
	var p = h.panel
	var pts := int(game.hero()["points"])
	_check(pts == 8, "a level 9 hero has 8 points (%d)" % pts)
	p.select("k_tempered")
	_check(p.buy(), "buys Tempered Steel")
	_check(int(game.hero()["skills"]["k_tempered"]) == 1 and int(game.hero()["points"]) == pts - 1, "rank 1, one point spent")
	_check(changes[0] == 1, "the Sheet says the hero changed")
	p.select("k_mirror")
	_check(not p.buy(), "Tier 2 needs 3 points in the branch")
	p.select("k_tempered")
	p._plus.pressed.emit()
	_check(int(game.hero()["skills"]["k_tempered"]) == 2, "the + button buys the next rank")
	p.select("k_devout")
	p._process(0.01)
	_check(not p._plus.disabled, "the + is live on a node a point can buy")
	p._plus.pressed.emit()
	p.select("k_mirror")
	_check(p.buy(), "with 3 in the branch, Tier 2 opens")
	p.select("k_unbroken")
	p._process(0.01)
	var why: String = Classes.can_buy("knight", "k_unbroken", game.hero()["skills"], 9, int(game.hero()["points"]))
	_check(why == "5 points in branch" and p._plus.disabled, "the capstone waits for 5 in the branch (%s)" % why)
	p.select("k_mirror")
	p.buy()
	p.select("k_unbroken")
	_check(p.buy(), "then the capstone")
	p.select("k_dawn")
	p._process(0.01)
	_check(p._state(Classes.find_node("knight", "k_dawn")) == "locked" and p._plus.disabled, "the other capstone is shut: one per hero")
	await _frames(2)
	p._respec_pressed()
	_check(int(game.hero()["points"]) < pts, "respec asks twice")
	p._respec_pressed()
	_check(int(game.hero()["points"]) == pts and (game.hero()["skills"] as Dictionary).is_empty(), "respec gives every point back")
	h.queue_free()
	await _frames(2)


func _test_rename() -> void:
	## The Stats tab names the hero by his own name, and Rename renames him:
	## the oath's name entry over the Sheet, holding the name he has, its
	## field, Cancel and Confirm a thumb tall, in the safe area and above a
	## phone's keyboard. Confirm (or Return) keeps the new name in the save
	## (every calling's); Cancel and Escape leave it, and the Sheet open; what
	## a name can't hold doesn't land, and nothing fit to keep is Waxby.
	_where = "rename"
	_fresh_hero(5, "founder")
	var h = await _sheet("stats")
	var p = h.panel
	_check(p.hero_name() == "Waxby", "before he's named, the Stats tab calls him Waxby (%s)" % p.hero_name())
	var rb: Button = p._rename
	_check(rb != null and rb.visible and rb.text == "Rename" and rb.size.y >= UI.TAP_H - 0.5, "a Rename button, a thumb tall")
	var L: Rect2 = p._left_rect()
	var rr := Rect2(rb.position, rb.size)
	_check(rr.position.y >= L.position.y + 64.0 and rr.end.y <= L.position.y + p.LEVEL_Y - 16.0 and rr.position.x >= L.position.x + 90.0
			and rr.end.x <= L.end.x, "under his name and calling, clear of the face and the level line (%s in %s)" % [rr, L])
	rb.pressed.emit()
	await _frames(2)
	_check(h.renaming(), "Rename opens the name entry")
	var e = h.name_entry()
	_check(e != null and e.get_script().resource_path == "res://scripts/name_entry.gd" and e.get_parent() == h, "the oath's own entry, over the Sheet")
	if e == null:
		h.queue_free()
		return
	_check(e.field.text == "Waxby" and e.can_cancel and e.cancel_btn != null and e.field.has_focus(), "holding Waxby, with a Cancel, the field taking the keys")
	_buttons_ok(e, "rename entry")
	_inside(e.field.get_global_rect(), "rename field")
	var vs := Vector2(root.content_scale_size)
	for kb in [0.0, 200.0, 250.0]:
		e.keyboard_override = kb
		e._layout()
		for c in [e.field, e.cancel_btn, e.confirm_btn]:
			_check((c as Control).get_global_rect().end.y <= vs.y - kb, "a %d-high keyboard: %s stays above it" % [kb, c.name])
	e.field.text = "Ember-Lou9"
	e.field.text_changed.emit("Ember-Lou9")
	_check(e.field.text == "Ember-Lou", "a digit doesn't land (%s)" % e.field.text)
	e.confirm_btn.pressed.emit()
	await _frames(1)
	_check(game.hero_name() == "Ember-Lou" and not h.renaming(), "Confirm: he's Ember-Lou (%s)" % game.hero_name())
	_check(p.hero_name() == "Ember-Lou", "and the Stats tab says so")
	var disk = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	_check(disk is Dictionary and str(disk.get("hero_name", "")) == "Ember-Lou", "the save holds it")
	game.new_hero("witch")
	_check(game.hero_name() == "Ember-Lou", "one name for every calling of the save")
	game.set_hero("founder")
	# Cancel leaves it.
	rb.pressed.emit()
	await _frames(2)
	e = h.name_entry()
	_check(e.field.text == "Ember-Lou", "the entry starts from the name he has")
	e.field.text = "Nope"
	e.cancel_btn.pressed.emit()
	await _frames(1)
	_check(game.hero_name() == "Ember-Lou" and not h.renaming(), "Cancel leaves it")
	# Escape cancels, and the Sheet stays open.
	var backs := [0]
	h.back.connect(func(): backs[0] += 1)
	rb.pressed.emit()
	await _frames(2)
	e = h.name_entry()
	e.field.text = "Nope"
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(2)
	var up: InputEventKey = esc.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)
	_check(not h.renaming() and game.hero_name() == "Ember-Lou" and backs[0] == 0, "Escape cancels the entry, not the Sheet (backs %d)" % backs[0])
	# Nothing fit to keep: Waxby. Return confirms.
	rb.pressed.emit()
	await _frames(2)
	e = h.name_entry()
	e.field.text = "  "
	e.field.text_submitted.emit("  ")
	await _frames(1)
	_check(game.hero_name() == "Waxby" and not h.renaming(), "an empty name (Return) is Waxby (%s)" % game.hero_name())
	h.queue_free()
	await _frames(1)
	game.reset()


func _test_gear() -> void:
	_where = "gear"
	_fresh_hero(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var a = Items.make("weapon", "knight", 9, "rare", rng)
	var b = Items.make("weapon", "knight", 4, "magic", rng)
	var junk = Items.make("weapon", "knight", 1, "magic", rng)
	junk["affixes"] = []
	junk["implicit"]["v"] = 1.0
	for it in [b, a, junk]:
		_check(game.add_item(it) == "satchel", "a Blessed or Rare goes to the satchel")
	var h = await _sheet("gear")
	var p = h.panel
	p.select_slot("weapon")
	await _frames(2)
	var list: Array = p.items_for("weapon")
	_check(list.size() == 3 and Items.power(list[0]) >= Items.power(list[1]) and Items.power(list[1]) >= Items.power(list[2]), "the slot's items, most powerful first")
	_check(p._list.get_child_count() == 3, "one row each")
	var old: Dictionary = game.hero()["equip"]["weapon"]
	p.pick(a)
	p._process(0.01)
	_check(p._equip_btn.visible and p._salvage_btn.visible, "picking one shows the comparison with Equip and Salvage")
	p._equip_btn.pressed.emit()
	_check(str(game.hero()["equip"]["weapon"]["uid"]) == str(a["uid"]), "Equip wears it")
	_check((game.hero()["satchel"] as Array).any(func(x): return x["uid"] == old["uid"]), "the old one goes to the satchel")
	_check(p.picked == null, "back to the list")
	var below: Array = p.below_equipped()
	_check(below.any(func(x): return x["uid"] == junk["uid"]), "the junk counts as below equipped")
	var embers := int(game.embers())
	p._bulk_pressed()
	_check((game.hero()["satchel"] as Array).any(func(x): return x["uid"] == junk["uid"]), "salvage-all asks twice")
	p._bulk_pressed()
	_check(int(game.embers()) > embers, "salvage-all pays embers")
	_check(not (game.hero()["satchel"] as Array).any(func(x): return x["uid"] == junk["uid"]), "and the junk is gone")
	var c = Items.make("coat", "knight", 6, "rare", rng)
	game.add_item(c)
	p.select_slot("coat")
	p.pick(c)
	var e2 := int(game.embers())
	var v: int = p.salvage_picked()
	_check(v > 0 and int(game.embers()) == e2 + v, "Salvage turns one item into embers")
	_check(not (game.hero()["satchel"] as Array).any(func(x): return x["uid"] == c["uid"]), "and it's gone")
	h.queue_free()
	await _frames(2)


func _test_belt() -> void:
	_where = "belt"
	_fresh_hero(5)
	for id in ["tallow_heart", "rook_feather", "moth_charm", "bellows"]:
		game.grant_relic(id)
	var h = load("res://scripts/hero_screen.gd").new()
	h.over_level = true
	root.add_child(h)
	h.open_tab("belt")
	await _frames(2)
	var p = h.panel
	var before: Array = game.belt().duplicate()
	_check(before.size() == 3, "level 5: three slots, filled from the codex (%s)" % [before])
	_check(not p.editable(), "over a level the belt is only to look at")
	p.tap_relic(before[0])
	p.tap_relic("bellows")
	p.tap_slot(0)
	_check(game.belt() == before, "over a level the belt can't change: a worn one stays, a found one doesn't go on")
	_check(p.shown == before[0], "but the relic is shown")
	var note: String = p.note_text()
	_check(note.contains("on the map") and note.contains("altar"), "its line: change it on the map, and a lit altar offers a found relic (%s)" % note)
	_check(UI.text_width(note, 10) <= p.size.x - 150.0, "the line fits beside the heading (%.0f px at 12, of %.0f)" % [UI.text_width(note, 12), p.size.x])
	h.over_level = false
	_check(p.editable() and p.note_text().begins_with("Tap a relic"), "on the map (no level under it) the belt can change")
	p.tap_relic(before[0])
	_check(not game.belt().has(before[0]), "tapping a worn relic takes it off")
	p.tap_relic("bellows")
	_check(game.belt().has("bellows"), "tapping a found one puts it on")
	p.tap_relic("phoenix_wick")
	_check(not game.belt().has("phoenix_wick"), "an unfound relic can't go on")
	p.tap_slot(3)
	_check(game.belt().size() <= game.belt_slots(), "a locked slot stays locked")
	h.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- keeper, map, pause, results

func _test_keeper() -> void:
	_where = "keeper"
	_fresh_hero(8)
	var k = load("res://scripts/keeper_screen.gd").new()
	root.add_child(k)
	await _frames(2)
	var enabled: Array = Classes.enabled_ids()
	_check(k._rigs.size() == enabled.size(), "a live rig in every open alcove")
	for cls in k._rigs:
		_check(k._rigs[cls]["rig"].cls == cls, "the %s alcove's rig is a %s" % [cls, cls])
	var hovered := [""]
	var picked := [""]
	k.hovered.connect(func(id): hovered[0] = id)
	k.picked.connect(func(id): picked[0] = id)
	k.open_card("witch")
	_check(hovered[0] == "witch" and k.open_id == "witch", "opening a card says which")
	k.choose("witch")
	_check(picked[0] == "witch" and game.has_hero("witch") and game.hero_id() == "witch", "Choose makes the hero and plays it")
	_check(int(game.heroes()["witch"]["level"]) == 6, "a later calling starts two levels under the best")
	for cls in Classes.ids():
		if not bool(Classes.info(cls)["enabled"]):
			k.choose(cls)
			_check(not game.has_hero(cls), "the sealed %s can't be chosen" % cls)
	k.standalone = false
	picked[0] = ""
	k.choose("runner")
	_check(picked[0] == "runner" and not game.has_hero("runner"), "embedded, it only says which (the host makes the hero)")
	k.queue_free()
	await _frames(2)


func _test_map() -> void:
	_where = "map"
	_fresh_hero(4)
	var m = load("res://scripts/map_screen.gd").new()
	root.add_child(m)
	await _frames(2)
	_check(m.rec_level(0) == Combat.area_level(1, "dusk"), "the medallion's Lv is the level's area")
	m.set_difficulty("witching")
	_check(game.diff() == "dusk", "a locked difficulty's bell doesn't ring")
	# The last boss of what's built opens no Nightfall: it waits for the Hush
	# (the owner's answer), which opens it (a stub 6-4 in the build here).
	# (With 6-4 built, the last level before it: 6-4 itself is the finale.)
	var last_i: int = game.LEVELS.size() - 1
	if str(game.LEVELS[last_i]["id"]) == "6-4":
		last_i -= 1
	game.record_result({"level": game.LEVELS[last_i]["id"], "cleared": true, "time": 100.0, "sigils": [false, false, false], "embers": 0})
	m.set_difficulty("nightfall")
	_check(game.diff() == "dusk", "the last level built doesn't open Nightfall")
	var kept: Array = game.LEVELS
	if game.index_of("6-4") < 0:
		game.LEVELS = kept + [{"id": "6-4", "path": "res://levels/6-4.txt", "world": 6}]
	game.record_result({"level": "6-4", "cleared": true, "time": 100.0, "sigils": [false, false, false], "embers": 0})
	game.LEVELS = kept
	m.set_difficulty("nightfall")
	_check(game.diff() == "nightfall", "an open one does")
	_check(m.rec_level(0) == Combat.area_level(1, "nightfall"), "and the Lv follows the difficulty")
	game.set_diff("dusk")
	# The three buttons go to main.gd, which opens every one of those
	# screens: the map has no screens (or v1 relic shop) of its own.
	var heard := {"sheet": 0, "callings": 0, "chandler": 0}
	for sig in heard:
		m.connect(sig, func(): heard[sig] += 1)
	for sig in heard:
		m._open(sig)
	await _frames(2)
	_check(heard == {"sheet": 1, "callings": 1, "chandler": 1} and m._overlay == null, "Sheet, Callings and Chandler go to main.gd (%s)" % [heard])
	var kids := 0
	for c in m.get_children():
		if not (c is Button):
			kids += 1
	_check(kids == 0 and not ("_offers" in m) and not m.has_method("_draw_shop"), "and the map opens nothing itself (no v1 relic shop)")
	m._shop = true   # tools/shot.gd's old hook: the Chandler's now
	_check(heard["chandler"] == 2 and m._overlay == null, "the old shop hook asks for the Chandler")
	_check(m.world_open(2) == (not game.levels_in_world(2).is_empty() and game.is_unlocked(game.index_of("2-1"))), "World 2's tab waits for its levels and 2-1")
	m.queue_free()
	await _frames(2)


func _test_keeper_hosted() -> void:
	## W4's oath scene sets embedded (or in_story): no Back, no backdrop of its
	## own, and Choose only says which. On its own, Choose says which before it
	## makes the hero, so main.gd can still tell a new calling.
	_where = "keeper hosted"
	for prop in ["embedded", "in_story"]:
		_fresh_hero(1)
		var k = load("res://scripts/keeper_screen.gd").new()
		_check(prop in k, "the keeper has %s" % prop)
		k.set(prop, true)
		root.add_child(k)
		await _frames(2)
		_check(not k.standalone and not k.show_back and not k.show_backdrop, "%s: not standalone, no Back, no backdrop" % prop)
		_check(not k._back_btn.visible, "%s: the Back button is hidden" % prop)
		var picked := [""]
		k.picked.connect(func(id): picked[0] = id)
		k.open_card("runner")
		k._process(0.01)
		_check(k._choose_btn.text == "Choose", "%s: the card says Choose (%s)" % [prop, k._choose_btn.text])
		k.choose("runner")
		_check(picked[0] == "runner" and not game.has_hero("runner"), "%s: Choose only says which" % prop)
		k.queue_free()
		await _frames(2)
	_where = "keeper standalone"
	_fresh_hero(6)
	var k2 = load("res://scripts/keeper_screen.gd").new()
	root.add_child(k2)
	await _frames(2)
	var fresh_then := [null]
	k2.picked.connect(func(id): fresh_then[0] = not game.has_hero(id))
	k2.choose("witch")
	_check(fresh_then[0] == true, "picked(id) comes before the hero is made (a listener sees a new calling)")
	_check(game.has_hero("witch") and game.hero_id() == "witch", "then the keeper makes it and plays it")
	fresh_then[0] = null
	k2.choose("witch")
	_check(fresh_then[0] == false and game.hero_id() == "witch", "choosing it again only switches")
	k2.queue_free()
	await _frames(2)


func _test_world_opened() -> void:
	## The map says world_opened(w) when a world's tab comes up (switched to,
	## or open as the map opens on World 2); main.gd plays its opener once.
	_where = "world opened"
	_fresh_hero(1)
	var m = load("res://scripts/map_screen.gd").new()
	_check(m.has_signal("world_opened"), "the map has world_opened")
	var heard: Array = []
	m.world_opened.connect(func(w): heard.append(w))
	root.add_child(m)
	await _frames(2)
	_check(heard.is_empty(), "the map opening on World 1 says nothing")
	m.set_world(1)
	_check(heard.is_empty(), "nor does the tab it's already on")
	if game.levels_in_world(2).is_empty():
		m.set_world(2)
		_check(heard.is_empty(), "World 2 without its levels: no tab, nothing said")
		m.queue_free()
		await _frames(2)
		return
	# World 2's levels are here: clear World 1 and it opens.
	for info in game.levels_in_world(1):
		game.record_result({"level": info["id"], "cleared": true, "time": 100.0, "sigils": [false, false, false], "embers": 0})
	_check(m.world_open(2), "(World 2 is open once World 1 is cleared)")
	m.set_world(2)
	_check(heard == [2], "switching to World 2 says so (%s)" % [heard])
	m.set_world(1)
	_check(heard == [2, 1], "and back to World 1 (%s)" % [heard])
	m.queue_free()
	await _frames(2)
	var m2 = load("res://scripts/map_screen.gd").new()
	m2.focus = game.index_of(game.levels_in_world(2)[0]["id"])
	var heard2: Array = []
	m2.world_opened.connect(func(w): heard2.append(w))
	root.add_child(m2)
	await _frames(3)
	_check(heard2 == [2], "the map opening on World 2 says so, once (%s)" % [heard2])
	m2.queue_free()
	await _frames(2)


func _test_real_taps() -> void:
	## Taps sent as the phone sends them (Input, a left press and release,
	## which also arrives as a screen touch): one tap does one thing.
	_where = "real taps"
	# The belt: a tap on slot 1 takes off that relic only; a tap on a found
	# relic in the codex puts it on (into that slot) and leaves it there.
	_fresh_hero(5)
	for id in ["tallow_heart", "rook_feather", "moth_charm"]:
		game.grant_relic(id)
	var h = load("res://scripts/hero_screen.gd").new()
	h.tab = "belt"
	root.add_child(h)
	await _frames(3)
	var bp = h.panel
	var before: Array = game.belt().duplicate()
	_check(before.size() == 3, "(level 5: a full belt of three %s)" % [before])
	await _click(bp.global_position + (bp.slot_rects()[0] as Rect2).get_center())
	_check(game.belt() == before.slice(1), "one tap on slot 1 takes off just that relic (%s)" % [game.belt()])
	var ids: Array = load("res://scripts/relics.gd").ids()
	var i: int = ids.find(before[0])
	await _click(bp.global_position + (bp.codex_rects()[i] as Rect2).get_center())
	_check(game.belt() == before, "one tap on it in the codex puts it back in that slot, and it stays (%s)" % [game.belt()])
	h.queue_free()
	await _frames(2)
	# Skills and gear: a tap selects.
	_fresh_hero(3)
	var hs = load("res://scripts/hero_screen.gd").new()
	hs.tab = "skills"
	root.add_child(hs)
	await _frames(3)
	var sp = hs.panel
	var P: Dictionary = sp.positions()
	var pick: String = P.keys()[-1]
	await _click(sp.global_position + (P[pick][0] as Vector2))
	_check(sp.selected == pick, "a tap on a skill node selects it (%s)" % sp.selected)
	hs.open_tab("gear")
	await _frames(3)
	var gp = hs.panel
	var S: Dictionary = gp.slot_rects()
	await _click(gp.global_position + (S["coat"] as Rect2).get_center())
	_check(gp.slot == "coat", "a tap on a gear slot opens it (%s)" % gp.slot)
	hs.queue_free()
	await _frames(2)
	# The keeper: a tap on any open alcove opens its card and it stays open
	# (the first and last ones sit outside the card); a tap off the card
	# closes it; a sealed alcove only takes the focus.
	_fresh_hero(1)
	var k = load("res://scripts/keeper_screen.gd").new()
	root.add_child(k)
	await _frames(3)
	var cids: Array = Classes.ids()
	var R: Array = k.alcove_rects()
	for j in cids.size():
		k.close_card()
		await _click((R[j] as Rect2).get_center())
		if bool(Classes.info(cids[j])["enabled"]):
			_check(k.open_id == cids[j], "one tap on the %s alcove opens its card (open: '%s')" % [cids[j], k.open_id])
		else:
			_check(k.open_id == "" and k.focus == j, "a tap on the sealed %s alcove only takes the focus" % cids[j])
	k.open_card("knight")
	var C: Rect2 = k.card_rect()
	await _click(C.get_center())
	_check(k.open_id == "knight", "a tap on the card keeps it open")
	await _click(Vector2(C.position.x - 6.0, C.position.y + 6.0) if C.position.x > 8.0 else Vector2(C.get_center().x, C.end.y + 6.0))
	_check(k.open_id == "", "a tap off the card closes it")
	k.queue_free()
	await _frames(2)
	# The map: a tap on a medallion that isn't focused only focuses it; a
	# second tap goes in.
	_fresh_hero(1)
	game.record_result({"level": "1-1", "cleared": true, "time": 100.0, "sigils": [false, false, false], "embers": 0})
	var m = load("res://scripts/map_screen.gd").new()
	m.focus = 0
	var played: Array = []
	m.play.connect(func(idx): played.append(idx))
	root.add_child(m)
	await _frames(3)
	var N: Dictionary = m.nodes()
	_check(game.is_unlocked(1), "(1-2 is open)")
	await _click(N[1])
	_check(m.focus == 1 and played.is_empty(), "one tap on 1-2 picks it and doesn't go in (focus %d, played %s)" % [m.focus, played])
	await _click(N[1])
	_check(played == [1], "a second tap goes in (%s)" % [played])
	m.queue_free()
	await _frames(2)


func _test_pause() -> void:
	_where = "pause"
	_fresh_hero(3)
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var w = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await _frames(1)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	var touch = TouchScript.new()
	w.touch = touch
	w.add_child(touch)
	var pm = load("res://scripts/pause_menu.gd").new()
	pm.world = w
	w.pause_menu = pm
	w.add_child(pm)
	await _frames(2)
	w.open_pause()
	await _frames(2)
	_check(pm.visible and w.paused, "pause opens and pauses")
	_check(not hud.visible and not touch.visible_controls, "the HUD and buttons step aside")
	pm.show_page("settings")
	pm.set_value("numbers", "off")
	_check(str(game.setting("numbers")) == "off" and w.floaters.mode == "off", "damage numbers apply at once")
	pm.set_value("button_scale", 1.1)
	_check(is_equal_approx(touch.button_scale, 1.1), "button size applies at once")
	pm.set_value("shake", 0.5)
	_check(is_equal_approx(float(game.setting("shake")), 0.5), "shake is saved")
	pm.set_value("candle_strength", "gentle")
	_check(str(game.setting("candle_strength")) == "gentle", "candle strength is saved")
	pm.set_value("auto_equip", false)
	_check(game.setting("auto_equip") == false, "auto-equip can be turned off")
	for kv in [["numbers", "on"], ["button_scale", 1.0], ["shake", 1.0], ["candle_strength", "normal"], ["auto_equip", true]]:
		pm.set_value(kv[0], kv[1])
	pm.show_page("main")
	pm.open_sheet()
	await _frames(2)
	_check(pm._sheet != null and pm._sheet.over_level, "the Sheet opens from pause, over the level")
	_check(int(game.hero()["points"]) > 0 and pm._sheet.tab == "skills", "with a skill point waiting, on Skills (%s)" % pm._sheet.tab)
	pm._sheet.back.emit()
	await _frames(1)
	_check(pm.page == "main" and pm._sheet == null, "Back returns to the pause sheet")
	var pts := int(game.hero()["points"])
	game.hero()["points"] = 0
	pm.open_sheet()
	await _frames(2)
	_check(pm._sheet.tab == "stats", "with none, on Stats (%s)" % pm._sheet.tab)
	pm._sheet.back.emit()
	await _frames(1)
	game.hero()["points"] = pts
	# The map's Sheet (main.show_sheet) the same way.
	var mn = load("res://scripts/main.gd").new()
	mn.show_sheet()
	_check(mn.get("current") != null and str(mn.current.tab) == "skills", "the map's Sheet opens on Skills while points wait")
	game.hero()["points"] = 0
	mn.show_sheet()
	_check(str(mn.current.tab) == "stats", "and on Stats with none")
	game.hero()["points"] = pts
	mn.free()
	await _belt_in_level(w, pm)
	pm.close()
	await _frames(1)
	_check(not w.paused and hud.visible and touch.visible_controls, "closing brings everything back")
	w.queue_free()
	await _frames(2)


func _belt_in_level(w: Node, pm: Node) -> void:
	## The belt changes only between levels, from the map's Sheet: over a
	## paused level its tab is only to look at, even with Waxby standing by a
	## lit altar (that altar offers a relic found with the belt full on its
	## swap card, world.open_relic: test_core's relic_altar). The map's
	## Sheet changes it.
	for id in ["tallow_heart", "rook_feather", "moth_charm"]:
		game.grant_relic(id)
	var worn: Array = game.belt().duplicate()
	_check(worn.size() == game.belt_slots() and not worn.has("moth_charm"), "(the belt full, one found off it: %s)" % [worn])
	_check(w.altars.size() > 0, "(1-1 has an altar)")
	if w.altars.is_empty():
		return
	w.altars[0]["lit"] = true
	w.player.position = w.altars[0]["pos"]
	_check(not pm.has_method("near_lit_altar"), "the pause sheet has no altar route to the belt")
	pm.open_sheet()
	await _frames(2)
	pm._sheet.open_tab("belt")
	await _frames(2)
	var bp = pm._sheet.panel
	_check(not bp.editable(), "by a lit altar, the pause Sheet's belt is still only to look at")
	bp.tap_relic(worn[0])
	bp.tap_relic("moth_charm")
	bp.tap_slot(0)
	_check(game.belt() == worn, "a tap on the belt or the codex changes nothing (%s)" % [game.belt()])
	_check(bp.shown == worn[0], "but shows the relic")
	_check(bp.note_text().contains("on the map"), "its line sends him to the map (%s)" % bp.note_text())
	pm._sheet.back.emit()
	await _frames(1)
	# The map's Sheet (main.show_sheet): the belt can change there.
	var mn = load("res://scripts/main.gd").new()
	mn.show_sheet()
	var ms = mn.current
	_check(ms != null and not bool(ms.over_level), "the map's Sheet is over no level")
	mn.remove_child(ms)
	root.add_child(ms)
	ms.open_tab("belt")
	await _frames(2)
	var mp = ms.panel
	_check(mp.editable(), "the map's Sheet: the belt can change")
	mp.tap_relic(worn[0])
	_check(not game.belt().has(worn[0]), "a tap takes a worn relic off")
	mp.tap_relic("moth_charm")
	_check(game.belt().has("moth_charm"), "and one from the codex goes on")
	game.set_belt(worn)
	ms.queue_free()
	mn.free()
	await _frames(1)


func _test_results() -> void:
	_where = "results"
	_fresh_hero(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var it = Items.make("weapon", "knight", 3, "rare", rng)
	var gained := 400
	var from := int(game.hero()["xp"])
	game.add_xp(gained)
	var r = load("res://scripts/results_screen.gd").new()
	r.result = {"level": "1-1", "cleared": true, "embers": 20, "embers_total": 40, "sigils": [true, true, false], "time": 70.0,
			"relics": ["rook_feather"], "items": [it], "xp": gained, "levels": 2, "diff": "dusk"}
	r.rewards = [{"kind": "relic", "id": "moth_charm"}, {"kind": "difficulty", "id": "nightfall"}]
	root.add_child(r)
	await _frames(1)
	_check(r.xp_shown() == from, "the XP bar starts where the hero stood")
	var levels_seen := 0
	var last: int = Progression.level_of(from)
	for i in 5 * 60:
		r._process(1.0 / 60.0)
		var lv: int = Progression.level_of(r.xp_shown())
		if lv > last:
			levels_seen += lv - last
			last = lv
	_check(r.xp_shown() == int(game.hero()["xp"]), "and fills to where it stands now")
	_check(levels_seen == Progression.level_of(from + gained) - Progression.level_of(from), "a fanfare for each level gained (%d)" % levels_seen)
	await _frames(3)
	_buttons_ok(r, "results")
	# The points to spend: a pill that's a button, opening the Rites' cards.
	var pts := int(game.hero()["points"])
	_check(pts > 0 and r.spend_rect.has_area() and r._spend.visible and r._spend.get_global_rect().encloses(r.spend_rect),
			"%d points to spend: a pill, a thumb-tall button over it (%s)" % [pts, r.spend_rect])
	_check(r.open_rites() and r.choice.is_open() and r.choice.offers.size() > 0 and r.choice.offers.size() <= 3, "it opens the skills on the choice card (%d)" % (r.choice.offers.size() if r.choice else 0))
	var id := str(r.choice.offers[0]["id"])
	var rk := int(game.hero()["skills"].get(id, 0))
	r.choice.choose(0)
	_check(int(game.hero()["points"]) == pts - 1 and int(game.hero()["skills"].get(id, 0)) == rk + 1, "a pick learns it (%s)" % id)
	_check(r.choice.is_open() == (pts - 1 > 0), "and with points left the cards come again")
	if r.choice.is_open():
		r.choice.choose(-1)
	_check(not r.choice.is_open() and int(game.hero()["points"]) == pts - 1, "Later closes them, the rest kept")
	r.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- integration (the seams)

func _test_pickup_states() -> void:
	## The pickup card for everything Game.add_item can say: sold (a find
	## sold on touch: a card that keeps it; or, the satchel full, a note) and
	## "full". A full item the World already took up (world.gd today) takes a
	## tap and is worn, and the old one is sold so the satchel stays at its
	## cap; one the World left on the floor takes a tap only if the World can
	## lift it (claim_item), else the card says it's still there, once per
	## item.
	_where = "pickup states"
	_fresh_hero(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var w := _stub_world()
	root.add_child(w)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	await _frames(2)
	var com = Items.make("coat", "knight", 3, "common", rng)
	hud.show_pickup(com, {"dmg": 0.0, "life": -2.0}, "sold")
	hud._process(0.05)
	_check(str(hud._card.get("where", "")) == "sold" and int(hud._card.get("embers", 0)) == Items.sell_value(com) and hud._msg.is_empty(),
			"a find sold with room in the satchel: a card (+%d)" % int(hud._card.get("embers", 0)))
	hud._card = {}
	var h: Dictionary = game.hero()
	_fill_satchel(rng)
	for rar in ["magic", "rare"]:
		var it = Items.make("weapon", "knight", 3, rar, rng)
		hud.show_pickup(it, {"dmg": -5.0, "life": 0.0}, "sold")
		hud._process(0.05)
		var sub := str(hud._msg.get("sub", ""))
		_check(sub == "Satchel full · sold  +%d embers" % Items.sell_value(it), "a %s sold by a full satchel says why: \"%s\"" % [rar, sub])
		_check(hud._msg.get("col") == UI.rarity_color(rar), "in its rarity's colour")
		hud._msg = {}
	_check(hud._card.is_empty() and hud._cards.is_empty(), "sold with the satchel full: a note, not a card (nowhere to keep it)")
	# Full, and already off the floor: the tap is its one chance, as before.
	var worn: Dictionary = h["equip"]["candle"]
	var left = Items.make("candle", "knight", 9, "rare", rng)
	var e0: int = game.embers()
	hud.show_pickup(left, {"dmg": 5.0, "life": -2.0}, "full")
	hud._process(0.05)
	_check(str(hud._card.get("where", "")) == "full", "full: a card")
	_check(hud.card_hit(hud.card_rect().get_center()), "taken up already: the card takes a tap")
	_check(bool(hud._card.get("melts", false)), "and it knows wearing it melts the old one")
	# A touch (or the equip key) that would melt the worn one only asks first.
	_check(hud.tap_card(true), "a first tap is taken")
	_check(str(h["equip"]["candle"]["uid"]) == str(worn["uid"]) and _holds(h, worn) and game.embers() == e0,
			"but only asks: nothing is worn or melted yet")
	_check(bool(hud._card.get("armed", false)) and is_equal_approx(float(hud._card["tap_left"]), HudScript.CARD_TAP),
			"the card waits for a second tap, with a fresh window")
	await _frames(1)
	_check(hud.card_line.begins_with("TAP AGAIN") and hud.card_line.contains("SELLS"), "and says so: \"%s\"" % hud.card_line)
	hud._cards.append({"kind": "relic", "id": "rook_feather", "on": false, "t": 0.0, "tap_left": 0.0})
	for i in 20:
		hud._process(0.1)
	_check(float(hud._card.get("tap_left", 0.0)) > 0.0 and bool(hud._card.get("armed", false)),
			"another card waiting doesn't cut the second tap's window short")
	hud._cards.clear()
	_check(hud.tap_card(true), "a second tap")
	_check(str(h["equip"]["candle"]["uid"]) == str(left["uid"]), "wears it")
	_check((h["satchel"] as Array).size() == game.SATCHEL_MAX, "the satchel stays at %d (%d)" % [game.SATCHEL_MAX, (h["satchel"] as Array).size()])
	_check(game.embers() == e0 + Items.sell_value(worn), "the old one sold for its embers")
	_check(not _holds(h, worn), "and is gone")
	_check(str(hud._card["where"]) == "equipped" and hud._card.has("melt"), "the card says Equipped, and what was sold")
	_check(not hud.card_hit(hud.card_rect().get_center()) and not hud.tap_card(), "with nothing to flip back to")
	# The longest status lines still fit the card on the narrowest screen.
	await _set_view(Vector2i(780, 390), true)
	_where = "pickup states"
	await _frames(1)
	_check(hud.card_fits, "780 wide: \"Equipped · old one sold\" fits the card")
	hud._card["melt"]["old"] = false
	hud._card["melt"]["name"] = "Bright Padded Greatcoat of the Bell"
	await _frames(1)
	_check(hud.card_fits, "and with a long name in it")
	hud._card["melt"]["old"] = true
	var peek := {"kind": "item", "item": left, "chips": {"dmg": 5.0, "life": -2.0}, "where": "full", "t": 1.0, "tap_left": 2.0, "melts": true, "icon": null}
	var kept: Dictionary = hud._card
	hud._card = peek
	await _frames(1)
	_check(hud.card_fits, "780 wide: \"Satchel full · tap to wear, old one sells\" fits the card")
	# And every other state the card can be in.
	for v in [["equipped", 2.0, {}], ["equipped", 0.0, {}], ["undone", 2.0, {}], ["undone", 0.0, {}], ["satchel", 2.0, {}],
			["satchel", 0.0, {}], ["full", 2.0, {"melts": false}], ["full", 0.0, {"floor": true}], ["full", 0.0, {"floor": false}],
			["sold", 2.0, {"embers": 9999}], ["sold", 0.0, {"embers": 9999}], ["kept", 0.0, {}]]:
		var pk: Dictionary = peek.duplicate()
		pk["where"] = v[0]
		pk["tap_left"] = v[1]
		pk.erase("melts")
		pk.merge(v[2], true)
		hud._card = pk
		await _frames(1)
		_check(hud.card_fits, "780 wide: the %s card (tap %s, %s) fits" % [v[0], v[1] > 0.0, v[2]])
	var armed: Dictionary = peek.duplicate()
	armed["armed"] = true
	hud._card = armed
	await _frames(1)
	_check(hud.card_fits and hud.card_line.begins_with("TAP AGAIN"), "780 wide: \"%s\" (asking for the second tap) fits the card" % hud.card_line)
	hud._card = kept
	await _set_view(Vector2i(847, 390), true)
	_where = "pickup states"
	for i in 40:
		hud._process(0.1)
	_check(hud._card.is_empty(), "the card goes after a few seconds")
	# Full, and still on the floor with no claim_item: the card only says so.
	var left2 = Items.make("weapon", "knight", 9, "rare", rng)
	var sword: Dictionary = h["equip"]["weapon"]
	w.pickups = [{"kind": "item", "item": left2, "taken": false}]
	hud.show_pickup(left2, {"dmg": 5.0, "life": -2.0}, "full")
	hud._process(0.05)
	_check(bool(hud._card.get("floor", false)), "left on the floor: the card knows")
	_check(not hud.card_hit(hud.card_rect().get_center()), "without claim_item it takes no tap (a thumb there moves)")
	_check(not hud.tap_card() and not hud.tap_card(true), "and a tap does nothing")
	_check(not bool(hud._card.get("armed", false)), "(nor asks for a second)")
	_check(str(h["equip"]["weapon"]["uid"]) == str(sword["uid"]), "nothing is worn")
	hud.show_pickup(left2, {"dmg": 5.0, "life": -2.0}, "full")
	_check(hud._cards.is_empty(), "walking back over it doesn't stack another card")
	for i in 40:
		hud._process(0.1)
	_check(hud._card.is_empty(), "the card goes after a few seconds")
	hud.show_pickup(left2, {"dmg": 5.0, "life": -2.0}, "full")
	_check(hud._cards.is_empty(), "nor straight after")
	hud._t += 7.0
	hud.show_pickup(left2, {"dmg": 5.0, "life": -2.0}, "full")
	_check(hud._cards.size() == 1, "but later it says so again")
	w.queue_free()
	await _frames(2)
	# Full, on the floor, and the World can lift it: a tap wears it and takes it off the floor.
	var w2 := _stub_world(true)
	w2.pickups = [{"kind": "item", "item": left2, "taken": false}]
	root.add_child(w2)
	var hud2 = HudScript.new()
	hud2.world = w2
	w2.hud = hud2
	w2.add_child(hud2)
	await _frames(2)
	hud2.show_pickup(left2, {"dmg": 5.0, "life": -2.0}, "full")
	hud2._process(0.05)
	_check(hud2.card_hit(hud2.card_rect().get_center()), "with claim_item the card takes a tap")
	_check(hud2.tap_card(true), "a tap")
	_check(w2.claimed.is_empty() and str(h["equip"]["weapon"]["uid"]) == str(sword["uid"]), "the first only asks: it stays on the floor, the old one worn")
	_check(hud2.tap_card(true), "a second tap")
	_check(w2.claimed.size() == 1 and str(w2.claimed[0]["uid"]) == str(left2["uid"]), "lifts it off the floor")
	_check(str(h["equip"]["weapon"]["uid"]) == str(left2["uid"]), "and wears it")
	_check(str(hud2._card["where"]) == "equipped", "the card says Equipped")
	_check((h["satchel"] as Array).size() == game.SATCHEL_MAX, "the satchel still at its cap")
	w2.queue_free()
	await _frames(2)
	await _test_full_in_a_level()


func _test_power_card() -> void:
	## Build 1: a Legendary's "New power" card (power_card, called by world.gd's
	## moment): NEW POWER heads it, its power on one or two big lines (13 or
	## 12 px), the chips small; it holds CARD_POWER s, cards waiting or not,
	## while its tap window stays CARD_TAP (a tap still undoes). A plain
	## item's card gives way as before.
	_where = "power card"
	_fresh_hero(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var w := _stub_world()
	root.add_child(w)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	await _frames(2)
	var short: Dictionary = HudScript.card_power_lines(str(Items.LEGENDS["dawnsliver"]["text"]), 238.0)
	_check(int(short["size"]) >= 12 and (short["lines"] as Array).size() <= 2, "a power's text fits big: %d px, %d lines" % [int(short["size"]), (short["lines"] as Array).size()])
	var long_text := str(Items.LEGENDS["hollins_ember"]["text"]) + " " + str(Items.LEGENDS["last_candle"]["text"])
	_check(HudScript.card_power_lines(long_text, 238.0) == HudScript.card_key_lines(long_text, 238.0), "one too long for two big lines falls back to the small ones")
	var leg: Dictionary = Items.make("weapon", "knight", 3, "legendary", rng, "dawnsliver")
	game.equip(leg)
	hud.show_pickup(leg, {"dmg": -4.0, "life": 0.0}, "equipped")
	hud.power_card(leg)
	hud._process(0.05)
	_check(bool(hud._card.get("power", false)) and float(hud._card["tap_left"]) > HudScript.CARD_TAP - 0.1 and float(hud._card["tap_left"]) <= HudScript.CARD_TAP,
			"the Legendary's card is a New power, its tap window CARD_TAP")
	await _frames(1)
	_check(hud.card_line.begins_with("NEW POWER") and hud.card_line.contains("UNDO"), "it says so, and that a tap undoes: \"%s\"" % hud.card_line)
	_check(hud.card_hit(hud.card_rect().get_center()), "and it takes the tap")
	var t := 0.05
	while not hud._card.is_empty() and float(hud._card["tap_left"]) > 0.0 and t < 8.0:
		hud._process(0.05)
		t += 0.05
	_check(not hud._card.is_empty() and t < HudScript.CARD_POWER - 1.0, "its tap window closes after %.1f s, the card still up" % t)
	await _frames(1)
	_check(hud.card_line == "NEW POWER", "then it reads just NEW POWER (\"%s\")" % hud.card_line)
	while not hud._card.is_empty() and t < 8.0:
		hud._process(0.05)
		t += 0.05
	_check(absf(t - HudScript.CARD_POWER) < 0.11, "it holds %.2f s (CARD_POWER)" % t)
	# With a card waiting behind it: a plain item's gives way at 1.6 s, a New power holds.
	for power in [false, true]:
		var it: Dictionary = Items.make("coat", "knight", 3, "legendary" if power else "rare", rng, "ossuary_coat" if power else "")
		hud.show_pickup(it, {"dmg": 0.0, "life": 2.0}, "satchel")
		if power:
			hud.power_card(it)
		hud._cards.append({"kind": "relic", "id": "rook_feather", "on": false, "t": 0.0, "tap_left": 0.0})
		t = 0.0
		hud._process(0.05)
		while not hud._card.is_empty() and str(hud._card.get("kind", "")) == "item" and t < 8.0:
			hud._process(0.05)
			t += 0.05
		_check(t < 2.5 if not power else absf(t - HudScript.CARD_POWER) < 0.15,
				"a relic card waiting: %s card is up %.1f s" % ["a New power" if power else "a plain item's", t])
		hud._card = {}
		hud._cards.clear()
	# Into the satchel: NEW POWER, tap to wear.
	var sat: Dictionary = Items.make("boots", "knight", 3, "legendary", rng, "thornsole")
	hud.show_pickup(sat, {"dmg": 0.0, "life": -1.0}, "satchel")
	hud.power_card(sat)
	hud._process(0.05)
	await _frames(1)
	_check(hud.card_line.begins_with("NEW POWER") and hud.card_line.contains("WEAR"), "one in the satchel: \"%s\"" % hud.card_line)
	hud._card = {}
	hud._cards.clear()
	w.queue_free()
	await _frames(2)


func _fill_satchel(rng: RandomNumberGenerator) -> void:
	## A full satchel of weak boots and charms (nothing the tests wear).
	var h: Dictionary = game.hero()
	h["satchel"].clear()
	while (h["satchel"] as Array).size() < game.SATCHEL_MAX:
		h["satchel"].append(_zero_implicit(Items.make(["boots", "charm"][(h["satchel"] as Array).size() % 2], str(h["cls"]), 1, "common", rng)))


func _holds(h: Dictionary, it: Dictionary) -> bool:
	## Whether the hero still has it: worn or in the satchel.
	var uid := str(it.get("uid", "-"))
	for s in h["equip"]:
		if h["equip"][s] is Dictionary and str(h["equip"][s].get("uid", "")) == uid:
			return true
	for o in h["satchel"]:
		if o is Dictionary and str(o.get("uid", "")) == uid:
			return true
	return false


func _test_full_in_a_level() -> void:
	## The same seams on a real World (world.gd as merged): a Legendary the
	## satchel can't hold, picked up with auto-equip off, is worn by a tap on
	## its card, not lost; an upgrade auto-equipped into a full satchel melts
	## the old piece instead of pushing the satchel past its cap, and the
	## card says so with no undo; the Chandler sells into a full satchel the
	## same way and says what melted.
	_where = "full satchel in a level"
	_fresh_hero(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var h: Dictionary = game.hero()
	_fill_satchel(rng)
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var w = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await _frames(1)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	await _frames(2)
	game.set_setting("auto_equip", false)
	var leg = Items.make("coat", "knight", 2, "legendary", rng, Items.pick_legend("coat", "knight", rng))
	var coat: Dictionary = h["equip"]["coat"]
	var p := {"kind": "item", "item": leg, "rarity": leg["rarity"], "pos": w.player.center(), "vel": Vector2.ZERO, "t": 0.0, "taken": false, "loose": false, "age": 1.0}
	w.pickups.append(p)
	w._collect(p)
	hud._process(0.05)
	_check(str(hud._card.get("where", "")) == "full", "a Legendary with the satchel full: a full card (%s)" % hud._card.get("where", ""))
	var on_floor := false
	for q in w.pickups:
		if q["kind"] == "item" and not q["taken"] and str(q["item"].get("uid", "")) == str(leg["uid"]):
			on_floor = true
	if not on_floor:
		_check(hud.card_hit(hud.card_rect().get_center()), "the World took it up: the card takes a tap")
		_check(hud.accept_pickup() and str(h["equip"]["coat"]["uid"]) == str(coat["uid"]), "the equip key asks first")
		_check(hud.accept_pickup(), "and a second press")
		_check(str(h["equip"]["coat"]["uid"]) == str(leg["uid"]), "the Legendary is worn, not lost")
		_check(not _holds(h, coat), "the old coat melted")
	else:
		_check(hud.card_hit(hud.card_rect().get_center()) == w.has_method("claim_item"), "left on the floor: a tap only with claim_item")
	_check((h["satchel"] as Array).size() <= game.SATCHEL_MAX, "the satchel within its cap (%d)" % (h["satchel"] as Array).size())
	for i in 40:
		hud._process(0.1)
	# Auto-equip on: a plainly better weapon into a full satchel.
	game.set_setting("auto_equip", true)
	var sword: Dictionary = h["equip"]["weapon"]
	var better = Items.make("weapon", "knight", 12, "rare", rng)
	var e0: int = game.embers()
	w._take_item(better)
	hud._process(0.05)
	_check(str(h["equip"]["weapon"]["uid"]) == str(better["uid"]), "the better weapon is worn")
	_check((h["satchel"] as Array).size() == game.SATCHEL_MAX, "the satchel stays at %d (%d)" % [game.SATCHEL_MAX, (h["satchel"] as Array).size()])
	_check(game.embers() == e0 + Items.salvage_value(sword), "the old one melted for its embers")
	_check(str(hud._card.get("where", "")) == "equipped" and hud._card.has("melt"), "the card says what melted")
	_check(not hud.card_hit(hud.card_rect().get_center()), "and offers no undo")
	w.queue_free()
	await _frames(2)
	# The Chandler, a ware that beats the worn candle, the satchel full.
	game.mark_seen("meet_waxley")
	game.data["embers"] = 5000
	var stock: Array = game.wares()
	var candle: Dictionary = h["equip"]["candle"]
	var ware = Items.make("candle", "knight", 14, "rare", rng)
	stock[0] = ware
	var c = load("res://scripts/chandler_screen.gd").new()
	root.add_child(c)
	await _frames(2)
	c.show_tab("wares")
	_check(game.ware_verdict(0) == "equipped", "the ware would be worn (%s)" % game.ware_verdict(0))
	c._buy(0)
	_check(c._line.contains("old one melts"), "the first tap says the old one melts: \"%s\"" % c._line)
	var e1: int = game.embers()
	c._buy(0)
	_check(str(h["equip"]["candle"]["uid"]) == str(ware["uid"]), "bought and worn")
	_check((h["satchel"] as Array).size() == game.SATCHEL_MAX and not _holds(h, candle), "the satchel stays at %d, the old candle gone" % game.SATCHEL_MAX)
	_check(game.embers() == e1 - Items.price(ware) + Items.salvage_value(candle), "paid, and the old candle melted back")
	_check(c._line.contains("melted"), "Waxley says it melted: \"%s\"" % c._line)
	_check(str(c._notes.get(0, {}).get("sub", "")).begins_with("Old one melted"), "and the shelf says so")
	_check(str(c.wares_note()["text"]) == "Satchel full · %d / %d" % [game.SATCHEL_MAX, game.SATCHEL_MAX], "the note: \"%s\"" % c.wares_note()["text"])
	# Every line Waxley can say on Wares fits beside the red note and Salvage
	# weaker, on the narrowest screen. (On Relics and Unmake the small print
	# is muted and gives way to a long line.)
	for i in 3:
		h["satchel"][i] = _zero_implicit(Items.make("weapon", "knight", 1, "common", rng))
	c._update_salvage()
	await _set_view(Vector2i(780, 390), true)
	c._layout()
	for key in c.LINES:
		if ["belt", "stowed", "bare", "ask_belt", "ask_stowed", "tab_relics", "arm", "unmade", "nothing", "tab_unmake"].has(key):
			continue
		for line in c.LINES[key]:
			var extra := ""
			match str(key):
				"equipped_melt", "salvaged":
					extra = " +999 embers."
			c._line = str(line) + extra
			c.queue_redraw()
			await _frames(1)
			_check(c.line_fits, "780 wide, satchel full: Waxley's \"%s\" fits" % c._line)
	await _set_view(Vector2i(847, 390), true)
	c.queue_free()
	await _frames(2)


func _test_level_up_card() -> void:
	## The level-up card counts the points of every level gained and says
	## when a belt slot opens (Progression's L5 and L10, whatever the curve).
	_where = "level-up card"
	_fresh_hero(3)
	var w := _stub_world()
	root.add_child(w)
	var hud = HudScript.new()
	hud.world = w
	w.add_child(hud)
	await _frames(2)
	var cases := [[4, 5, true], [5, 6, false], [8, 10, true], [10, 11, false], [3, 4, false]]
	for c in cases:
		hud._lvl = {}
		hud._xp_level = c[0]
		hud.level_up(c[1])
		var line := str(hud._lvl.get("line", ""))
		_check(line.contains("belt slot") == c[2], "L%d -> L%d: \"%s\"" % [c[0], c[1], line])
	hud._lvl = {}
	hud._xp_level = 8
	hud.level_up(10)
	_check(str(hud._lvl["line"]).contains("+2 skill points"), "two levels at once: two points (\"%s\")" % hud._lvl["line"])
	# What the levels gave, in numbers: Combat's 1.09 and 1.10 a level.
	_check(str(hud._lvl["line"]).begins_with("+19% damage · +21% life · +2 skill points"), "and their damage and life, together (\"%s\")" % hud._lvl["line"])
	hud._lvl = {}
	hud._xp_level = 5
	hud.level_up(6)
	_check(str(hud._lvl["line"]) == "+9% damage · +10% life · +1 skill point", "one level: \"+9%% damage · +10%% life · +1 skill point\" (\"%s\")" % hud._lvl["line"])
	# Under it, what opened (gold) or the next unlock and its level (the
	# game's deep tree: a layout test above may have left v2's).
	var was_deep: bool = Classes.deep
	Classes.set_deep(true)
	hud._lvl = {}
	hud._xp_level = 5
	hud.level_up(6)
	var nx: Dictionary = hud._lvl["next"]
	_check(bool(nx.get("now", false)) and str(nx.get("text", "")) == "Now open: Aegis rank 3", "L6 opens the Special's rank 3 (\"%s\")" % nx.get("text", ""))
	for c in [[7, 8, true, "Now open: the capstones (Tier 3)"], [15, 16, true, "Now open: the Deep nodes (Tier 4)"],
			[23, 24, true, "Now open: the Mastery nodes (Tier 5)"], [6, 7, false, "Next at level 8: the capstones (Tier 3)"],
			[7, 9, true, "Now open: the capstones (Tier 3)"], [3, 4, false, "Next at level 5: a relic belt slot (3)"]]:
		hud._lvl = {}
		hud._xp_level = c[0]
		hud.level_up(c[1])
		nx = hud._lvl["next"]
		_check(bool(nx.get("now", false)) == c[2] and str(nx.get("text", "")) == c[3], "L%d -> L%d: \"%s\" (\"%s\")" % [c[0], c[1], c[3], nx.get("text", "")])
	_check(StatsPanel.next_unlock("knight", 4) == "Level 5: a relic belt slot (3)." and StatsPanel.next_unlock("knight", 7) == "Level 8: the capstones (Tier 3).",
			"stats_panel.next_unlock is the Stats tab's Next line, for any calling and level")
	Classes.set_deep(was_deep)
	# The longest first line (two levels, a belt slot) fits its width at
	# the smallest size the card draws it, and the card stays in its band.
	hud._lvl = {}
	hud._xp_level = 3
	hud.level_up(5)
	var longest := str(hud._lvl["line"])
	_check(longest.contains("a new belt slot") and UI.text_width(longest, UI.fit_size(longest, HudScript.LEVEL_LINE_W, 13, 10, "body", 700), "body", 700) <= HudScript.LEVEL_LINE_W,
			"\"%s\" fits the card's %d px" % [longest, HudScript.LEVEL_LINE_W])
	w.queue_free()
	await _frames(2)


func _test_points_pip() -> void:
	## A skill point waiting: a gold "+" on the level badge's shoulder, inside
	## the safe area and the left block's wash, gone once it's spent.
	_where = "points pip"
	_fresh_hero(3)
	var w := _stub_world()
	root.add_child(w)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	await _frames(2)
	_check(hud.points_waiting() == int(game.hero()["points"]) and hud.points_waiting() > 0, "points waiting show on the badge (%d)" % hud.points_waiting())
	var pr: Rect2 = hud.points_pip_rect()
	_inside(pr, "the badge's +")
	_check((hud.backing_rects()["left"] as Rect2).encloses(pr), "on the left block's wash")
	for key in ["life", "res", "embers"]:
		_apart(pr, hud.layout()[key], "the badge's + and %s" % key)
	var h: Dictionary = game.hero()
	h["points"] = 0
	await _frames(2)
	_check(hud.points_waiting() == 0, "none left: no +")
	w.queue_free()
	await _frames(2)


func _test_altar_rites() -> void:
	## The Altar Rites (rites.gd): an altar lit with a skill point waiting
	## pauses the level and offers up to three skills on the choice card.
	## Never headless, under the --autoplay bot, on a golden route (its
	## recording or replay) or a scripted pad: rites_block says why, and a
	## lit altar leaves nothing waiting. The card itself (open_rites) on a
	## real World: a pick learns the skill (the toast names it), Later keeps
	## the point, and the touch controls hold nothing and take no touch
	## while it's up.
	_where = "altar rites"
	_fresh_hero(5)
	var pts0 := int(game.hero()["points"])
	var lv = LevelData.load_file("res://levels/1-1.txt")
	for k in ["start", "boss"]:
		if str(lv.story.get(k, "")) != "":
			game.mark_seen(str(lv.story[k]))
	# A headless World (every test's, the golden routes'): lit, nothing waits.
	var w = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await _frames(1)
	w.paused = true
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	await _frames(1)
	_check(pts0 > 0, "the hero has %d points waiting" % pts0)
	_check(w.rites_block() == "headless", "headless: no Rites (%s)" % w.rites_block())
	w._light_altar(w.altars[0])
	for i in 30:
		w.tick(DT)
	_check(w._rites_altar < 0 and w.choice == null and int(game.hero()["points"]) >= pts0, "an altar lit headless leaves nothing waiting, and no card")
	w.autoplay = true
	_check(w.rites_block() == "autoplay", "nor under the bot (%s)" % w.rites_block())
	w.queue_free()
	await _frames(2)
	# A World with its HUD and buttons (not headless), as a player's is.
	w = WorldScript.new()
	w.setup(lv, false)
	root.add_child(w)
	await _frames(1)
	w.paused = true
	var whys := {}
	w.autoplay = true
	whys["autoplay"] = w.rites_block()
	w.autoplay = false
	w.no_monsters = true
	whys["route"] = w.rites_block()
	w.no_monsters = false
	w.on_pad = func(_p): pass
	whys["recording"] = w.rites_block()
	w.on_pad = Callable()
	w.test_pad = {}
	whys["scripted"] = w.rites_block()
	w.test_pad = null
	whys["headless"] = w.rites_block()
	_check(whys == {"autoplay": "autoplay", "route": "route", "recording": "route", "scripted": "scripted", "headless": "headless"},
			"never under the bot, on a golden route or its recording, a scripted pad, or with no display (%s)" % [whys])
	w._light_altar(w.altars[0])
	_check(w._rites_altar < 0, "so a lit altar leaves nothing waiting here either")
	# The card, asked for: up to three skills, on top of the paused level.
	var cards: Array = load("res://scripts/rites.gd").offers(game.hero())
	_check(w.open_rites() and w.paused and w.choice != null and w.choice.is_open(), "open_rites pauses the level under the card")
	_check(w.choice.offers.size() == mini(cards.size(), 3) and w.choice.offers.size() > 0 and not w.choice.pair, "with up to three skills (%d)" % w.choice.offers.size())
	_check(not w.touch.is_processing_input() and not w.touch.is_down("right"), "the touch controls let go and wait")
	var id := str(w.choice.offers[0]["id"])
	var r0 := int(game.hero()["skills"].get(id, 0))
	var name := str(w.choice.offers[0]["name"])
	w.choice.choose(0)
	var seen_toast := _toasted(w, name)
	_check(int(game.hero()["skills"].get(id, 0)) == r0 + 1 and int(game.hero()["points"]) == pts0 - 1, "a pick learns it (%s %d -> %d)" % [id, r0, int(game.hero()["skills"].get(id, 0))])
	_check(w.paused and w.choice.is_open() and w.choice.heading == load("res://scripts/rites.gd").heading(game.hero()) and not w.touch.is_processing_input(),
			"%d points left: the cards come again (%s)" % [pts0 - 1, w.choice.heading])
	w.choice.choose(-1)
	_check(not w.paused and not w.choice.is_open() and w.touch.is_processing_input(), "Later: play is back, the buttons live")
	_check(seen_toast, "a toast names the skill (%s)" % name)
	w.paused = true
	_check(w.open_rites(), "the next time, the card again")
	w.choice.choose(-1)
	_check(int(game.hero()["points"]) == pts0 - 1 and not w.paused and not w.choice.is_open(), "Later keeps the point and lets play go on")
	w.paused = true
	# A monster awake near holds them back (they open once the area clears).
	var e: Node2D = w.spawn_enemy("skeleton", w.player.position + Vector2(80, 0))
	e.active = true
	_check(w.foes_near(), "a monster awake 80 px off is near")
	e.position = w.player.position + Vector2(400, 0)
	_check(not w.foes_near(), "400 px off it isn't")
	game.hero()["points"] = 0
	_check(not w.open_rites() and not w.choice.is_open(), "no point waiting: no card")
	w.queue_free()
	await _frames(2)


func _test_rites_more() -> void:
	## The Altar Rites on a World played as a player's is (a display, no
	## pad): two points give two picks at one altar (the cards come again
	## while points are left); the first node of a big tier grows the flame
	## and says so ("Your flame grows"); Rites a snuff cut off wait again when
	## he relights at that altar.
	_where = "rites more"
	_fresh_hero(8)
	var lv = LevelData.load_file("res://levels/1-1.txt")
	for k in ["start", "boss"]:
		if str(lv.story.get(k, "")) != "":
			game.mark_seen(str(lv.story[k]))
	var w = WorldScript.new()
	w.setup(lv, false)
	root.add_child(w)
	await _frames(1)
	w.paused = true
	w.no_display = false
	for e in w.enemies:
		e.active = false
	_check(w.rites_block() == "", "a player's World: the Rites may open (%s)" % w.rites_block())
	var h: Dictionary = game.hero()
	# Five points in the first branch, so its capstone (L8) can be learned.
	var cls := str(h["cls"])
	var spent := 0
	h["points"] = 20
	for m in Classes.tree(cls):
		while spent < 5 and int(m["branch"]) == 0 and int(m["tier"]) < 3 \
				and Classes.can_buy(cls, str(m["id"]), h["skills"], int(h["level"]), int(h["points"])) == "":
			if not game.buy_skill(str(m["id"])):
				break
			spent += 1
	h["points"] = 2
	w.apply_hero()
	var f0 := float(w.player.stats.get("flame_scale", 1.0))
	_check(w.open_rites() and w.choice.is_open() and w.choice.heading.contains("2 points"), "two points: the card (%s)" % w.choice.heading)
	var first := str(w.choice.offers[0]["id"])
	var tier := int(Classes.find_node(str(h["cls"]), first).get("tier", 0))
	w.choice.choose(0)
	var f1 := float(w.player.stats.get("flame_scale", 1.0))
	_check(tier == 3 and f1 > f0 + 0.01 and _toasted(w, "Your flame grows"),
			"L8's capstone first: the flame grows (%.2f -> %.2f) and a toast says so" % [f0, f1])
	_check(int(h["points"]) == 1 and w.choice.is_open() and w.paused and w.choice.heading == "Choose a skill",
			"one point left: the cards come again at the same altar (%s)" % w.choice.heading)
	w.choice.choose(0)
	_check(int(h["points"]) == 0 and not w.choice.is_open() and not w.paused, "the second pick spends it, and play goes on")
	# Snuffed with the Rites waiting: they wait again at the altar he relights at.
	h["points"] = 1
	var a: Dictionary = w.altars[0]
	w.checkpoint = a["pos"]
	w.player.reset_at(a["pos"])
	w.paused = false
	w._altar_rites(a)
	_check(w._rites_altar == 0, "a lit altar with a point waiting: its Rites wait")
	w.player.alive = false
	w._on_snuffed()
	w.tick(DT)
	_check(w.state == "dead" and w._rites_altar < 0 and not w.choice.is_open(), "snuffed first: they're cut off")
	var t := 0.0
	while t < 3.5 and not w.choice.is_open():
		w.tick(DT)
		t += DT
	w.paused = true
	_check(w.state == "play" and w.choice.is_open() and w.choice.offers.size() > 0, "relit at that altar, they open again (%.1f s after the snuff)" % t)
	w.choice.choose(-1)
	w.paused = true
	w.queue_free()
	await _frames(2)


func _test_tier_barks() -> void:
	## A level-up that opens a tier barks its own line (story.gd level_up_8,
	## _16, _24), several levels at once too; any other, level_up's.
	_where = "tier barks"
	var lv = LevelData.load_file("res://levels/1-1.txt")
	for c in [[5, 8, "level_up_8"], [7, 9, "level_up_8"], [15, 16, "level_up_16"], [23, 24, "level_up_24"], [8, 9, "level_up"], [9, 15, "level_up"]]:
		_fresh_hero(c[0])
		var w = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await _frames(1)
		w.paused = true
		var hud = HudScript.new()
		hud.world = w
		w.hud = hud
		w.add_child(hud)
		await _frames(1)
		w.gain_xp(Progression.total_to(int(c[1])) - int(game.hero()["xp"]), w.player.position)
		var heard: Array = hud._bark_last.keys().filter(func(k): return str(k).begins_with("level_up"))
		_check(int(game.hero()["level"]) == int(c[1]) and heard == [c[2]], "L%d -> L%d barks %s (%s)" % [c[0], c[1], c[2], heard])
		w.queue_free()
		await _frames(2)


func _toasted(w: Node, title: String) -> bool:
	## The World's HUD holds a toast with this title (showing or waiting).
	var h = w.get("hud")
	if h == null:
		return false
	for m in h._msgs + [h._msg]:
		if str(m.get("kind", "")) == "toast" and str(m.get("title", "")) == title:
			return true
	return false


func _test_choice_layout() -> void:
	## The choice card at every size: three cards (632 px) and the button
	## under them inside the safe area and clear of each other; the pair two
	## up, as the Descent's Glimmers always were.
	var cc = load("res://scripts/choice_card.gd").new()
	root.add_child(cc)
	await _frames(1)
	var cards := []
	for i in 3:
		cards.append({"name": "Mirrored Glass", "text": "Perfect Guard throws shots back for 100% basic.", "glyph": "shield", "sub": "Tier 2 · rank 1 of 3", "new": i == 0})
	cc.open(cards, {"heading": "Choose a skill", "later": "Later"})
	await _frames(2)
	var rs: Array = cc.rects()
	_check(rs.size() == 3 and (rs[0] as Rect2).size == Vector2(200, 150), "three cards of 200 x 150 (%s)" % [rs])
	var b: Rect2 = cc.button_rect()
	for i in rs.size():
		_inside(rs[i], "choice card %d" % i)
		_apart(rs[i], b, "choice card %d and Later" % i)
		for j in range(i + 1, rs.size()):
			_apart(rs[i], rs[j], "choice cards %d and %d" % [i, j])
	_inside(b, "Later")
	_check(b.size.y >= UI.TAP_H - 0.5, "Later is a thumb tall (%.0f)" % b.size.y)
	cc.open(cards.slice(0, 1), {"pair": true, "later": "Walk on"})
	rs = cc.rects()
	var s: Rect2 = UI.safe_override
	_check(rs.size() == 2 and (rs[0] as Rect2).size == Vector2(220, 140) and is_equal_approx((rs[1] as Rect2).position.x - (rs[0] as Rect2).end.x, 24.0)
			and is_equal_approx((rs[0] as Rect2).end.x + 12.0, s.get_center().x), "the pair keeps its two 220 x 140 slots, 24 apart, centred (%s)" % [rs])
	cc.queue_free()
	await _frames(1)


func _test_touch_specials() -> void:
	## Hold-to-charge Specials through the touch layer, in a real level. The
	## Taperwitch's Flare charges while the thumb stays and flies when it
	## lifts; the Sexton's button turns to Toll the Dead with every wisp out,
	## and a 0.3 s hold tolls.
	_where = "touch specials"
	for cls in ["witch", "sexton"]:
		_fresh_hero(4, cls)
		var lv = LevelData.load_file("res://levels/1-1.txt")
		var w = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await _frames(1)
		var touch = TouchScript.new()
		w.touch = touch
		w.add_child(touch)
		await _frames(2)
		w.test_pad = null
		var kit = w.kit
		w.player.res = w.player.res_max
		var L: Dictionary = touch.layout()
		if cls == "sexton":
			while kit.wisps.size() < kit.max_wisps():
				kit.call_wisp()
		for i in 2:
			await physics_frame
		_check(str(touch.special_state.get("icon", "")) == ("toll" if cls == "sexton" else "witch"), "%s: the button's icon is %s" % [cls, touch.special_state.get("icon", "")])
		touch._begin(4, L["special"])
		var charged := false
		var ring := 0.0
		for i in 84:   # 0.7 s: past the Flare's 0.5 s charge and the Toll's 0.3 s hold
			await physics_frame
			if cls == "witch" and kit.charging and kit.charge >= 1.0:
				charged = true
			ring = maxf(ring, float(touch.special_state.get("ring", 0.0)))
		if cls == "witch":
			_check(charged, "held on the touch button, the Flare charges full")
			_check(ring > 0.9, "and the button's ring shows the charge (%.2f)" % ring)
			var res0: float = w.player.res
			touch._end(4)
			for i in 3:
				await physics_frame
			_check(not kit.charging and w.player.res < res0, "let go, it flies (Melt spent)")
		else:
			_check(ring > 0.5, "the hold shows its ring (%.2f)" % ring)
			_check(kit.wisps.is_empty(), "held 0.3 s, Toll the Dead sends every wisp")
			touch._end(4)
			for i in 3:
				await physics_frame
		touch.release_all()
		w.queue_free()
		await _frames(2)


func _zero_implicit(it: Dictionary) -> Dictionary:
	for k in it["implicit"]:
		if k != "id":
			it["implicit"][k] = 0.0
	it["affixes"] = []
	return it


func _test_chandler() -> void:
	## The Chandler's states read: every tab's buttons fit and are a thumb
	## tall; too dear is refused at once with the purse in red; a full
	## satchel is refused (the purse stays cream), the note says so, and
	## Salvage weaker (two taps, never a Legendary) makes the room.
	_where = "chandler"
	_fresh_hero(6, "runner")
	game.mark_seen("meet_waxley")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c = load("res://scripts/chandler_screen.gd").new()
	root.add_child(c)
	await _frames(3)
	for tab in ["wares", "relics", "unmake"]:
		c.show_tab(tab)
		await _frames(2)
		_buttons_ok(c, "chandler %s" % tab)
	c.show_tab("wares")
	game.data["embers"] = 0
	c._refresh()
	c._buy(0)
	_check(c._deny_why == "poor" and c._sale == -1, "too dear: refused on the first tap, for the embers")
	game.data["embers"] = 5000
	var h: Dictionary = game.hero()
	h["satchel"].clear()
	for i in game.SATCHEL_MAX - 1:
		h["satchel"].append(_zero_implicit(Items.make(["weapon", "candle", "coat"][i % 3], "runner", 1, "common", rng)))
	var leg = _zero_implicit(Items.make("coat", "runner", 1, "legendary", rng, Items.pick_legend("coat", "runner", rng)))
	h["satchel"].append(leg)
	var stock: Array = game.wares()
	stock[0] = _zero_implicit(Items.make("weapon", "runner", 1, "magic", rng))
	c._refresh()
	_check(game.ware_verdict(0) == "full", "a ware that wouldn't be worn, with the satchel full: %s" % game.ware_verdict(0))
	c._buy(0)
	_check(c._deny_why == "full" and c._sale == -1, "a full satchel refuses the sale")
	_check(str(c.wares_note()["text"]).begins_with("Satchel full"), "the note says the satchel is full")
	_check(c._salv_btn.visible, "and Salvage weaker shows")
	_buttons_ok(c, "chandler full")
	_check(game.weaker_items().size() == game.SATCHEL_MAX - 1, "every weaker Common counts, the Legendary doesn't (%d)" % game.weaker_items().size())
	var e0: int = game.embers()
	var want: int = game.weaker_value()
	c._salv_btn.pressed.emit()
	_check((h["satchel"] as Array).size() == game.SATCHEL_MAX, "the first tap only asks")
	c._salv_btn.pressed.emit()
	_check((h["satchel"] as Array).size() == 1 and str(h["satchel"][0]["uid"]) == str(leg["uid"]), "the second melts them, never the Legendary")
	_check(game.embers() == e0 + want and want > 0, "for their embers (+%d)" % want)
	_check(not c._salv_btn.visible, "nothing left to melt: the button goes")
	_check(game.ware_verdict(0) == "satchel", "and the sale can go through now")
	c._buy(0)
	c._buy(0)
	_check((h["satchel"] as Array).size() == 2, "two taps buy it into the satchel")
	c.queue_free()
	await _frames(2)


func _test_results_from_main() -> void:
	## main.gd hands the results screen first_clear and Mother Taper's line
	## (after): both are used.
	_where = "results from main"
	_fresh_hero(2)
	var r = load("res://scripts/results_screen.gd").new()
	r.result = {"level": "1-1", "cleared": true, "embers": 5, "embers_total": 40, "sigils": [false, false, false], "time": 70.0,
			"relics": [], "items": [], "xp": 10, "levels": 0, "diff": "dusk"}
	r.set("first_clear", true)
	r.set("after", {"who": "taper", "mood": "warm", "text": "A line main chose."})
	_check("first_clear" in r and "after" in r, "the results screen takes first_clear and after")
	root.add_child(r)
	await _frames(2)
	_check(str(r._after.get("text", "")) == "A line main chose.", "the line main hands over is the one shown")
	r.queue_free()
	await _frames(2)


func _test_milestones() -> void:
	## The screens' milestones come from Progression (the curve can change):
	## belt slots 3 and 4 open at L5 and L10, and the Stats tab says so.
	_where = "milestones"
	var BeltPanel = load("res://scripts/belt_panel.gd")
	for i in 4:
		var l: int = BeltPanel.opens_at(i)
		_check(Progression.belt_slots(l) > i and (l == 1 or Progression.belt_slots(l - 1) <= i), "belt slot %d opens at L%d" % [i + 1, l])
	_check(BeltPanel.opens_at(2) == 5 and BeltPanel.opens_at(3) == 10, "slots 3 and 4 at L5 and L10")
	_fresh_hero(4)
	var sp = load("res://scripts/stats_panel.gd").new()
	root.add_child(sp)
	await _frames(1)
	_check(str(sp._next_unlock(4)).begins_with("Level 5: a relic belt slot (3)"), "at L4 the Stats tab says L5 opens a belt slot: \"%s\"" % sp._next_unlock(4))
	_check(str(sp._next_unlock(9)).begins_with("Level 10: a relic belt slot (4)"), "at L9: L10 (\"%s\")" % sp._next_unlock(9))
	sp.queue_free()
	await _frames(1)


# ---------------------------------------------------------------- v3 (SC, Phase 1)
# The level streams land later: the maps below use header-only stand-ins in
# user:// for every level (and secret level) not in the build, and
# UI.secret_levels_override for the secret registry, put back after.

const V3_NAMES := {"3-1": "The Bramble Gate", "3-2": "The Hanging Ossuary", "3-3": "The Sporewood", "3-4": "The Heartwood",
		"4-1": "The Rime Stair", "4-2": "The Escapement", "4-3": "The Hall of Weights", "4-4": "The Hour Chamber",
		"5-1": "The Floating Aisle", "5-2": "The Gale Gallery", "5-3": "The Dawnglass Bridges", "5-4": "The Lightwell",
		"6-1": "The Black Shore", "6-2": "The Drowned Bells", "6-3": "The Long Quiet", "6-4": "The Heart of the Hush",
		"1-S": "The Roof of Evenbell", "2-S": "The Chandlers' Vault", "3-S": "The Rootcrown", "4-S": "The Mainspring",
		"5-S": "The Rose Window", "6-S": "The Lightless Mile"}
const STANDINS := "user://sc_standins"


func _standin(path: String, id: String, boss: bool) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("title: %s\nsubtitle: %s\narea: %d\n%s---\n" % [V3_NAMES.get(id, id), id, int(game.AREAS.get(id, 1)),
			"boss: rootmother\n" if boss else ""])
	f.close()


func _six_worlds(built_secrets := true) -> Array:
	## Every world laid out: the build's levels, stand-ins for the rest, and
	## six secret levels (their files only when built_secrets). Returns the
	## real LEVELS to put back (_back_to_build).
	var kept: Array = game.LEVELS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STANDINS))
	var lv: Array = []
	for l in game.ALL_LEVELS:
		var p: String = l["path"]
		if not FileAccess.file_exists(p):
			p = "%s/%s.txt" % [STANDINS, l["id"]]
			_standin(p, l["id"], str(l["id"]).ends_with("-4"))
		lv.append({"id": l["id"], "path": p, "world": l["world"]})
	game.LEVELS = lv
	var sec: Array = []
	for sl in game.SECRET_LEVELS:
		var p := "%s/%s.txt" % [STANDINS, sl["id"]]
		if built_secrets:
			_standin(p, sl["id"], false)
		else:
			p = "%s/none_%s.txt" % [STANDINS, sl["id"]]
		sec.append({"id": sl["id"], "path": p, "world": sl["world"], "from": sl["from"]})
	UI.secret_levels_override = sec
	return kept


func _back_to_build(kept: Array) -> void:
	game.LEVELS = kept
	UI.secret_levels_override = null
	load("res://scripts/map_screen.gd").modes_screen = load("res://scripts/map_screen.gd").MODES_SCREEN


func _clear_ids(ids: Array, d := "dusk") -> void:
	var keep := str(game.data["difficulty"])
	game.data["difficulty"] = d
	for id in ids:
		game.record_result({"level": id, "cleared": true, "time": 100.0, "sigils": [true, false, false], "embers": 0})
	game.data["difficulty"] = keep


func _all_ids() -> Array:
	var out: Array = []
	for l in game.LEVELS:
		out.append(l["id"])
	return out


func _test_v3_layouts() -> void:
	## Every v3 screen at this size: the six-world map (tabs, chips, secret
	## medallions, the Challenges button, a card), the HUD's new pieces, the
	## deep Skills tree and the five-slot belt, pause in a mode, results with
	## a secret and a Lost Wick, and the Tales buttons.
	var tag := _where
	var Map = load("res://scripts/map_screen.gd")
	var kept := _six_worlds()
	_fresh_hero(20)
	_clear_ids(_all_ids())
	for sl in game.SECRET_LEVELS:
		game.find_secret(str(sl["id"]), "dusk", false)
	Map.modes_screen = "res://scripts/ui.gd"   # a stand-in hub: the Challenges button shows
	game.data["unlocked"]["nightfall"] = 1
	var m = Map.new()
	root.add_child(m)
	await _frames(2)
	_check(m._challenges_btn.visible, "%s: the Challenges button shows once 1-2 is cleared" % tag)
	var T: Dictionary = m.tabs_by_world()
	_check(T.size() == 6 and m.tab_rects().size() == 6, "%s: six world tabs (%d)" % [tag, T.size()])
	_check(m.tab_rects()[2] == T[3], "%s: tab_rects() in world order" % tag)
	var fixed: Array = m.bell_rects() + [m.pill_rect(), m.purse_rect()]
	for w in T:
		var r: Rect2 = T[w]
		_inside(r, "%s world tab %d" % [tag, w])
		_check(r.size.y >= UI.TAP_H - 0.5 and r.size.x >= 44.0, "%s world tab %d is a thumb big (%s)" % [tag, w, r.size])
		for f in fixed:
			_apart(r, f, "%s world tab %d and %s" % [tag, w, f])
		for w2 in T:
			if w2 > w:
				_apart(r, T[w2], "%s world tabs %d and %d" % [tag, w, w2])
	for d in ["nightfall", "witching"]:
		var cr: Rect2 = m.chip_rect(d)
		_check(cr.has_area(), "%s: %s has its Lv chip" % [tag, d])
		_inside(cr, "%s %s chip" % [tag, d])
		_apart(cr, m.pill_rect(), "%s %s chip and the hero plate" % [tag, d])
		for w in T:
			_apart(cr, T[w], "%s %s chip and world tab %d" % [tag, d, w])
	for w in range(1, 7):
		m.set_world(w)
		await _frames(1)
		var bs := _buttons(m, [])
		_buttons_ok(m, "%s map world %d" % [tag, w])
		var N: Dictionary = m.nodes()
		var S: Dictionary = m.secret_nodes()
		_check(S.size() == 1, "%s world %d: its secret's medallion (%d)" % [tag, w, S.size()])
		var nr: Rect2 = m.name_rect()
		_inside(nr, "%s world %d name" % [tag, w])
		for t in T:
			_apart(nr, T[t], "%s world %d name and tab %d" % [tag, w, t])
		for i in N:
			var mr := Rect2(N[i] - Vector2(40, 58), Vector2(80, 146))
			_inside(mr, "%s world %d medallion %d" % [tag, w, i])
			_apart(mr, nr, "%s world %d medallion %d and the name" % [tag, w, i])
			for b in bs:
				_apart(mr, b.get_global_rect(), "%s medallion %d and button '%s'" % [tag, i, b.text])
		for id in S:
			var sr := _circle(S[id], m.SECRET_R + 4.0)
			_inside(sr, "%s secret %s" % [tag, id])
			_apart(sr, nr, "%s secret %s and the name" % [tag, id])
			for i in N:
				_apart(sr, Rect2(N[i] - Vector2(40, 58), Vector2(80, 146)), "%s secret %s and medallion %d" % [tag, id, i])
			for b in bs:
				_apart(sr, b.get_global_rect(), "%s secret %s and button '%s'" % [tag, id, b.text])
			m.focus_secret = id
			var nr2: Rect2 = m.name_rect()
			_inside(nr2, "%s picked secret %s's line" % [tag, id])
			_apart(nr2, sr, "%s picked secret %s's line and its medallion" % [tag, id])
			m.focus_secret = ""
	m.card("v3_update", "The bells below have woken", "Below the Tallow Deep lie four new worlds, and the Hush at the bottom. Your hero, gear and records came with you.")
	await _frames(2)
	_inside(m.card_panel(), "%s map card" % tag)
	_check(m._card_ok.visible and m._card_ok.size.y >= UI.TAP_H - 0.5, "%s the card's OK is a thumb tall" % tag)
	_inside(m._card_ok.get_global_rect(), "%s the card's OK" % tag)
	_check(m.card_panel().encloses(m._card_ok.get_global_rect()), "%s OK sits on the card" % tag)
	m.close_card()
	m.queue_free()
	await _frames(1)
	_back_to_build(kept)
	game.data["unlocked"]["nightfall"] = 0
	game.set_diff("dusk")
	# The HUD's new pieces: the mode pill, the Special's pill, a card in the
	# top band, the Candlemark under the badge.
	var w := _stub_world()
	root.add_child(w)
	var touch = TouchScript.new()
	w.touch = touch
	w.add_child(touch)
	var hud = HudScript.new()
	hud.world = w
	w.hud = hud
	touch.hud = hud
	w.add_child(hud)
	await _frames(2)
	for k in [0.9, 1.0, 1.1]:
		touch.button_scale = k
		var t2 := "%s HUD (buttons ×%.1f)" % [tag, k]
		hud.mode_pill({"label": "D7", "clock": 612.3, "lives": 2, "lives_max": 2, "dots": 4})
		hud.boss_bar({"id": "tinker", "name": "The Tinker of Hours", "title": "Keeper of the Carillon", "frac": 0.5, "segments": [0.65, 0.3], "awake": true})
		var L: Dictionary = hud.layout()
		var TL: Dictionary = touch.layout()
		var pill: Rect2 = L["sigils"]
		_check(is_equal_approx(pill.size.x, 150.0) and is_equal_approx(pill.size.y, 26.0), "%s the mode pill is 150 x 26 (%s)" % [t2, pill.size])
		_inside(pill, "%s mode pill" % t2)
		_apart(pill, _circle(TL["pause"], TL["r_pause"]), "%s mode pill and pause" % t2)
		for key in ["boss", "boss_label", "msg", "msg_boss", "badge", "life", "res", "embers"]:
			_apart(pill, L[key], "%s mode pill and %s" % [t2, key])
		_inside(L["boss_label"], "%s the boss bar's label beside a pill" % t2)
		hud.special_pill("Hold to give your flame")
		var sp: Rect2 = hud.special_pill_rect()
		_inside(sp, "%s the Special's pill" % t2)
		for b in ["left", "right", "flask", "attack", "jump", "special", "pause"]:
			var rad := float(TL["r_" + ("move" if b in ["left", "right"] else b)])
			_apart(sp, _circle(TL[b], rad + (10.0 if b == "special" else 0.0)), "%s the Special's pill and the %s button" % [t2, b])
		for key in ["sigils", "boss", "msg_boss", "badge", "life", "embers", "card"]:
			_apart(sp, L[key], "%s the Special's pill and %s" % [t2, key])
		var bc: Rect2 = hud.band_card_rect("Candle strength", "The flame can burn gentler. Settings → Candle strength.")
		_inside(bc, "%s a card in the top band" % t2)
		for key in ["badge", "life", "res", "embers", "marks", "sigils"]:
			_apart(bc, L[key], "%s the band card and %s" % [t2, key])
		_inside(L["marks"], "%s the Candlemark's place" % t2)
		for key in ["res", "embers", "life", "sigils", "boss_label"]:
			_apart(L["marks"], L[key], "%s the Candlemark and %s" % [t2, key])
		hud.mode_pill({})
		hud.special_pill("")
		hud.boss_bar({})
	# The segmented boss bar with v3's long names, alone and beside a pill:
	# the name and title share their row, and the phase marks stay in the
	# bar's frame, clear of both and of the message slot under it.
	for pill_on in [false, true]:
		hud.mode_pill({"label": "W3", "clock": 75.0, "lives": 1, "lives_max": 1} if pill_on else {})
		for bi in LONG_BOSSES:
			var info: Dictionary = bi.duplicate()
			info.merge({"frac": 0.5, "segments": [0.65, 0.3], "awake": true})
			hud.boss_bar(info)
			var lab: Dictionary = hud.boss_label_layout()
			var br: Rect2 = hud.boss_rect()
			var t3 := "%s boss bar '%s'%s" % [tag, bi["name"], " beside a pill" if pill_on else ""]
			var nr: Rect2 = lab["name_rect"]
			var tr: Rect2 = lab["title_rect"]
			_check(nr.end.x <= br.end.x + 0.5, "%s: the name fits over the bar (%s, %s)" % [t3, nr, br])
			if not pill_on:
				_check(int(lab["title_size"]) >= 8, "%s: the title shows (%d)" % [t3, int(lab["title_size"])])
			if int(lab["title_size"]) > 0:
				_apart(nr, tr, "%s name and title" % t3)
				_check(tr.end.x <= br.end.x + 0.5 and tr.position.x >= br.position.x, "%s: the title fits over the bar" % t3)
			var marks: Array = hud.boss_marker_rects()
			_check(marks.size() == 2, "%s: two phase marks (%d)" % [t3, marks.size()])
			for mr in marks:
				_check(br.grow(2.5).encloses(mr), "%s: a phase mark %s stays in the bar's frame %s" % [t3, mr, br.grow(2.0)])
				_apart(mr, nr, "%s phase mark and the name" % t3)
				if int(lab["title_size"]) > 0:
					_apart(mr, tr, "%s phase mark and the title" % t3)
				_apart(mr, hud.layout()["msg_boss"], "%s phase mark and the message slot" % t3)
			if pill_on:
				_apart(nr, hud.pill_rect(), "%s name and the pill" % t3)
				if int(lab["title_size"]) > 0:
					_apart(tr, hud.pill_rect(), "%s title and the pill" % t3)
	hud.boss_bar({})
	hud.mode_pill({})
	w.queue_free()
	await _frames(1)
	# The Stats rows: from 10 (v2's look kept up to 12) to a late hero's 18,
	# every row's label and value clear of its dividers and the panel edge.
	_fresh_hero(40)
	var hs = load("res://scripts/hero_screen.gd").new()
	root.add_child(hs)
	hs.open_tab("stats")
	await _frames(2)
	var R: Rect2 = hs.panel.list_rect()
	for n in range(10, 19):
		var prev_div := R.position.y
		var cols := {}
		for i in n:
			var c: Dictionary = hs.panel.row_layout(i, n, R, "+10% · +10%")
			var lb: Rect2 = c["label_box"]
			var vb: Rect2 = c["value_box"]
			var t4 := "%s stats %d rows, row %d" % [tag, n, i]
			if n <= 12:
				_check(int(c["value_size"]) == 20 and int(c["label_size"]) == 10, "%s keeps v2's look (%d/%d)" % [t4, c["label_size"], c["value_size"]])
			_check(int(c["value_size"]) >= 13, "%s: a readable value (%d)" % [t4, c["value_size"]])
			_check(lb.end.y <= vb.position.y + 0.5, "%s: the label sits over the value" % t4)
			var col_x := float(c["x"])
			if cols.has(col_x):
				_check(lb.position.y >= float(cols[col_x]) + 0.5, "%s: the label clears the divider above (%.1f, %.1f)" % [t4, lb.position.y, cols[col_x]])
			if float(c["divider"]) > 0.0:
				_check(vb.end.y <= float(c["divider"]) - 0.5, "%s: the value clears its divider (%.1f, %.1f)" % [t4, vb.end.y, c["divider"]])
				cols[col_x] = float(c["divider"])
			_check(vb.end.y <= R.end.y - 3.0 and lb.position.y >= R.position.y + 3.0, "%s: inside the panel (%s in %s)" % [t4, vb, R])
	hs.queue_free()
	await _frames(1)
	# The deep Skills tree, the Look tab's absence, and five belt slots.
	var Belt = load("res://scripts/belt_panel.gd")
	Classes.set_deep(true)
	Belt.slots_shown = 5
	_fresh_hero(27)
	var h = load("res://scripts/hero_screen.gd").new()
	root.add_child(h)
	for tab in ["skills", "belt"]:
		h.open_tab(tab)
		await _frames(2)
		_buttons_ok(h, "%s deep sheet %s" % [tag, tab])
		if tab == "skills":
			var P: Dictionary = h.panel.positions()
			_check(P.size() == Classes.tree(game.hero()["cls"]).size(), "%s every deep node has a place (%d)" % [tag, P.size()])
			var ids: Array = P.keys()
			for i in ids.size():
				var a: Array = P[ids[i]]
				# With its rank pips under it.
				var rr := Rect2(a[0] - Vector2(a[1] + 6.0, a[1] + 6.0), Vector2(a[1] * 2.0 + 12.0, a[1] * 2.0 + 20.0))
				_inside(_local(rr, h.panel), "%s deep node %s" % [tag, ids[i]])
				for j in range(i + 1, ids.size()):
					var b: Array = P[ids[j]]
					_check((a[0] as Vector2).distance_to(b[0]) > a[1] + b[1] + 8.0, "%s deep nodes %s and %s apart" % [tag, ids[i], ids[j]])
			# Each node's rank pips clear of every other node's disc and rims,
			# and inside the tree's panel.
			var nodes := {}
			for n in Classes.tree(game.hero()["cls"]):
				nodes[n["id"]] = n
			var tw := minf(h.panel.size.x * 0.56, 420.0)
			var tree_r := Rect2(0, 4, tw, h.panel.size.y - 8.0)
			for id in ids:
				var n: Dictionary = nodes[id]
				var pr: float = h.panel.pip_radius(n)
				for pc in h.panel.pip_centres(n, P[id][0], float(P[id][1])):
					_check(tree_r.grow(-1.0).encloses(_circle(pc, pr)), "%s node %s's pips inside the tree's panel" % [tag, id])
					for id2 in ids:
						if id2 == id:
							continue
						var o: float = h.panel.outer_radius(nodes[id2], float(P[id2][1]))
						_check((pc as Vector2).distance_to(P[id2][0]) >= o + pr + 0.5, "%s node %s's pips clear of node %s (%.1f < %.1f)" % [tag, id, id2, (pc as Vector2).distance_to(P[id2][0]), o + pr + 0.5])
		else:
			_check(h.panel.slot_rects().size() == 5, "%s five belt slots" % tag)
			for r in h.panel.slot_rects() + h.panel.codex_rects():
				_inside(_local(r, h.panel), "%s belt tile" % tag)
	h.queue_free()
	await _frames(1)
	# The second-capstone bark over the Sheet: bottom centre, inside the safe
	# area, clear of the tabs, Back and the Skills card's buttons.
	_capstone_hero(30, 1)
	h = load("res://scripts/hero_screen.gd").new()
	root.add_child(h)
	h.open_tab("skills")
	await _frames(2)
	_check(h.bark_showing(), "%s: the second-capstone bark plays over the Sheet" % tag)
	var bk: Rect2 = h.bark_rect()
	_inside(bk, "%s the Sheet's bark" % tag)
	_check(_local(h.panel.tree_rect(), h.panel).encloses(bk), "%s the bark sits on the tree's panel" % tag)
	for b in _buttons(h, []):
		_apart(bk, b.get_global_rect(), "%s the bark and button '%s'" % [tag, b.text])
	var P2: Dictionary = h.panel.positions()
	for n in Classes.tree(game.hero()["cls"]):
		if int(n["tier"]) >= 2 and P2.has(n["id"]):
			_apart(bk, _local(_circle(P2[n["id"]][0], float(P2[n["id"]][1]) + 3.0), h.panel), "%s the bark and Tier %d's %s" % [tag, n["tier"], n["id"]])
	h.queue_free()
	Classes.set_deep(false)
	Belt.slots_shown = 0
	await _frames(1)
	# Pause in a mode: its items instead of Restart and Leave.
	var pm = load("res://scripts/pause_menu.gd").new()
	pm.world = _mode_world()
	root.add_child(pm.world)
	root.add_child(pm)
	await _frames(1)
	pm.open()
	await _frames(2)
	_buttons_ok(pm, "%s pause in a mode" % tag)
	pm._mode_item(1)
	await _frames(1)
	_buttons_ok(pm, "%s pause, an item asking for its second tap" % tag)
	pm.queue_free()
	pm.world.queue_free()
	await _frames(1)
	# Results: a secret found, then a secret level with its Lost Wick and W6's candles.
	for res in [{"level": "1-3", "secret": "1-S", "secret_new": true}, {"level": "1-S", "lost_wick": 1, "candles": {"lit": 7, "total": 9}}]:
		var r = load("res://scripts/results_screen.gd").new()
		r.result = {"cleared": true, "embers": 12, "embers_total": 40, "sigils": [true, false, false], "time": 90.0,
				"relics": ["moth_charm"], "items": [], "xp": 60, "levels": 0, "diff": "dusk"}
		r.result.merge(res, true)
		r.rewards = [{"kind": "secret", "id": "1-S"}, {"kind": "draught", "id": "second"}]
		root.add_child(r)
		r._t = 10.0
		await _frames(3)
		_buttons_ok(r, "%s results %s" % [tag, res["level"]])
		for pl in r.pills:
			_inside(pl["panel"], "%s results pill %s" % [tag, pl["text"]])
		if r.lost_rect.has_area():
			_inside(r.lost_rect, "%s the Lost Wick's card" % tag)
			for pl in r.pills:
				_apart(r.lost_rect, pl["panel"], "%s the Lost Wick's card and pill %s" % [tag, pl["text"]])
		r.queue_free()
		await _frames(1)
	# Title and saves with their Tales buttons.
	var TS = load("res://scripts/title_screen.gd")
	var SS = load("res://scripts/saves_screen.gd")
	TS.tales_path = "res://scripts/ui.gd"
	SS.tales_path = "res://scripts/ui.gd"
	for sc in [TS, SS]:
		var n = sc.new()
		root.add_child(n)
		await _frames(3)
		_check(n.get_node("Tales").visible, "%s %s shows Tales" % [tag, sc.resource_path.get_file()])
		_buttons_ok(n, "%s %s" % [tag, sc.resource_path.get_file()])
		n.queue_free()
		await _frames(1)
	TS.tales_path = TS.TALES_SCREEN
	SS.tales_path = SS.TALES_SCREEN


const LONG_BOSSES := [
	{"id": "rootmother", "name": "Mother Gravebough", "title": "Heart of the Bone Orchard"},
	{"id": "tinker", "name": "The Tinker of Hours", "title": "Keeper of the Carillon"},
	{"id": "saint", "name": "The Prism Saint", "title": "The First Light"},
	{"id": "hush", "name": "The Hush", "title": "What Waits Beneath"},
]


func _capstone_hero(level: int, caps: int) -> void:
	## A deep-tree hero at level with caps capstones owned, the bark unheard.
	Classes.set_deep(true)
	_fresh_hero(level)
	var sk: Dictionary = game.hero()["skills"]
	var k := 0
	for n in Classes.tree(str(game.hero()["cls"])):
		if int(n["tier"]) == 3:
			if k < caps:
				sk[n["id"]] = 1
			k += 1
	game.data["notices"].erase("second_capstone")
	(game.data["seen"] as Array).erase("bark:second_capstone")


class PauseMode:
	## A mode with two pause items: Rest here, and Leave (asks twice).
	extends RefCounted
	var id := "descent"
	var called: Array = []
	func pause_items() -> Array:
		return [{"label": "Rest here", "cb": func(): called.append("rest"), "confirm": false},
				{"label": "Leave the Descent (costs a Spare Wick)", "cb": func(): called.append("leave"), "confirm": true}]


class PauseRest:
	## A mode whose one item resumes the level itself.
	extends RefCounted
	var id := "descent"
	var w
	func pause_items() -> Array:
		return [{"label": "Rest here", "cb": func(): w.close_pause(), "confirm": false}]


func _mode_world() -> Node:
	var ws := GDScript.new()
	ws.source_code = "extends Node\nvar mode\nvar touch = null\nvar hud = null\nvar player = null\nvar paused := true\nvar closed := 0\nfunc close_pause():\n\tpaused = false\n\tclosed += 1\n"
	ws.reload()
	var w: Node = ws.new()
	w.mode = PauseMode.new()
	return w


func _test_map_secrets() -> void:
	## A secret shows only once opened: nothing while its level isn't built;
	## once its exit's level is cleared, a spark on that medallion and "1
	## secret"; once its bell rings on this difficulty, its medallion, which
	## plays it (play_secret) on a second tap.
	_where = "map secrets"
	var Map = load("res://scripts/map_screen.gd")
	var kept := _six_worlds(false)
	_fresh_hero(8)
	_clear_ids(["1-1", "1-2", "1-3"])
	game.find_secret("1-S", "dusk", false)
	var m = Map.new()
	root.add_child(m)
	await _frames(2)
	_check(m.secret_of(1).is_empty() and m.secret_nodes().is_empty() and not m.secret_known(1), "no secret level in the build: nothing shows, even rung")
	_check(not m.spark_at(game.index_of("1-3")), "and no spark")
	m.queue_free()
	await _frames(1)
	_back_to_build(kept)
	kept = _six_worlds(true)
	_fresh_hero(8)
	_clear_ids(["1-1", "1-2"])
	m = Map.new()
	root.add_child(m)
	await _frames(2)
	_check(not m.secret_known(1) and not m.spark_at(game.index_of("1-3")), "built, its exit's level not cleared: no spark, no \"1 secret\"")
	_check(m.secret_nodes().is_empty(), "and no medallion")
	m.queue_free()
	_clear_ids(["1-3"])
	m = Map.new()
	root.add_child(m)
	await _frames(2)
	_check(m.secret_known(1) and m.spark_at(game.index_of("1-3")), "1-3 cleared: the spark and \"1 secret\"")
	_check(not m.spark_at(game.index_of("1-2")), "on 1-3 only")
	_check(m.secret_nodes().is_empty(), "but no medallion before its bell rings")
	m.queue_free()
	game.find_secret("1-S", "dusk", false)
	m = Map.new()
	root.add_child(m)
	await _frames(2)
	var S: Dictionary = m.secret_nodes()
	_check(S.has("1-S"), "its bell rung: 1-S's medallion (%s)" % [S.keys()])
	var went := [""]
	m.play_secret.connect(func(id): went[0] = str(id))
	var played := [-1]
	m.play.connect(func(i): played[0] = i)
	if S.has("1-S"):
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = S["1-S"]
		m._gui_input(e)
		_check(m.focus_secret == "1-S" and went[0] == "", "a tap picks it")
		m._gui_input(e)
		_check(went[0] == "1-S", "a second tap plays it (%s)" % went[0])
		went[0] = ""
		m._play_pressed()
		_check(went[0] == "1-S" and played[0] == -1, "and so does Play while it's picked")
		m.focus_secret = ""
		m._play_pressed()
		_check(played[0] == m.focus, "Play without it plays the level picked")
	game.set_diff("dusk")
	game.data["unlocked"]["nightfall"] = 1
	game.set_diff("nightfall")
	_check(m.secret_nodes().is_empty(), "on Nightfall, where its bell hasn't rung, it doesn't show")
	# Rung on Nightfall by a hero far under it: the warning card comes first.
	game.find_secret("1-S", "nightfall", false)
	game.data["notices"].erase("nightfall_warning")
	went[0] = ""
	_check(not m.warning_for_secret("1-S").is_empty(), "a hero of 8 going into a secret level on Nightfall is warned")
	m._go_secret("1-S")
	_check(m.card_showing() and went[0] == "", "the warning comes before the secret level")
	m.close_card()
	_check(went[0] == "1-S" and game.data["notices"].has("nightfall_warning"), "OK goes in (%s)" % went[0])
	game.set_diff("dusk")
	game.data["unlocked"]["nightfall"] = 0
	m.queue_free()
	await _frames(1)
	_back_to_build(kept)
	# A locked bell's or world tab's note: over the name line (clear of the
	# tabs and the bells), long enough to read, then gone.
	kept = _six_worlds(true)
	_fresh_hero(14)
	_clear_ids(["1-1", "1-2", "1-3", "1-4", "2-1", "2-2"])
	m = Map.new()
	root.add_child(m)
	await _frames(2)
	m.set_difficulty("witching")
	_check(m.note_text() != "", "a locked bell says why (%s)" % m.note_text())
	var nr: Rect2 = m.note_rect()
	_inside(nr, "the bell's note")
	for t in m.tabs_by_world().values():
		_apart(nr, t, "the bell's note and a world tab")
	for b in m.bell_rects():
		_apart(nr, b, "the bell's note and a bell")
	for i in 60:
		m._process(1.0 / 60.0)
	_check(m.note_text() != "", "still there a second later")
	for i in 120:
		m._process(1.0 / 60.0)
	_check(m.note_text() == "", "and gone after %.1f s" % m.NOTE_TIME)
	var T: Dictionary = m.tabs_by_world()
	if T.has(3):
		var e2 := InputEventMouseButton.new()
		e2.button_index = MOUSE_BUTTON_LEFT
		e2.pressed = true
		e2.position = (T[3] as Rect2).get_center()
		m._gui_input(e2)
		_check(m.world_tab != 3 and m.note_text() == "Ring 2-4's bell to open World 3", "a locked world's tab says which bell opens it (%s)" % m.note_text())
	m.queue_free()
	await _frames(1)
	_back_to_build(kept)


func _test_map_cards() -> void:
	## main.gd's one-time cards: the map's card() shows one, OK marks it seen
	## (Game.notice). The Nightfall warning: the first time into a level on
	## Nightfall with the hero more than 5 levels under it, then never again.
	_where = "map cards"
	var Map = load("res://scripts/map_screen.gd")
	_fresh_hero(3)
	var m = Map.new()
	root.add_child(m)
	await _frames(2)
	_check(m.has_method("card"), "the map takes main.gd's cards")
	game.data["notices"].erase("new_points")   # (a new save has it marked: only a migrated one owes it)
	m.card("new_points", "New skills", "5 points to spend. The skill trees grew deeper, and your Vigil ranks came back as points: spend them on the Sheet.")
	await _frames(2)
	_check(m.card_showing() and not game.data["notices"].has("new_points"), "a card shows, not yet marked")
	var played := [-1]
	m.play.connect(func(i): played[0] = i)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = m.nodes()[0]
	m._gui_input(e)
	_check(played[0] == -1, "the map under a card takes no taps")
	m._card_ok.pressed.emit()
	_check(not m.card_showing() and game.data["notices"].has("new_points"), "OK closes it and marks it seen")
	# The Nightfall warning.
	var kept := _six_worlds()
	m.queue_free()
	_fresh_hero(12)
	_clear_ids(["1-1"], "nightfall")
	game.data["unlocked"]["nightfall"] = 2
	game.set_diff("nightfall")
	m = Map.new()
	root.add_child(m)
	await _frames(2)
	m.play.connect(func(i): played[0] = i)
	played[0] = -1
	_check(not m.warning_for(0).is_empty(), "a hero of 12 on Nightfall is warned")
	m._go(0)
	_check(m.card_showing() and played[0] == -1, "the card comes first")
	_check(str(m._card.get("body", "")).contains("level 30"), "it says the dark is for level 30 and more (%s)" % m._card.get("body", ""))
	m.close_card()
	_check(played[0] == 0 and game.data["notices"].has("nightfall_warning"), "OK goes in, and it's marked")
	played[0] = -1
	m._go(0)
	_check(played[0] == 0 and not m.card_showing(), "the second time, straight in")
	game.data["notices"].erase("nightfall_warning")
	_fresh_hero(26)
	game.data["unlocked"]["nightfall"] = 2
	game.set_diff("nightfall")
	_check(m.warning_for(0).is_empty(), "a hero within 5 levels isn't warned")
	game.set_diff("dusk")
	_check(m.warning_for(0).is_empty(), "nor anyone on Dusk")
	game.data["unlocked"]["nightfall"] = 0
	m.queue_free()
	await _frames(1)
	_back_to_build(kept)
	# Continue from the altar: offered once a snapshot, only to a main that listens.
	_fresh_hero(5)
	if game.has_method("set_suspend"):
		game.set_suspend({"level": "1-2", "diff": "dusk", "altar": 1, "time": 30.0, "sigils": [true, false, false], "at": 1234})
		var Map2 = load("res://scripts/map_screen.gd")
		m = Map2.new()
		root.add_child(m)
		await _frames(2)
		_check(not m.card_showing(), "no listener for resume_altar: no offer")
		m.queue_free()
		m = Map2.new()
		var got := [{}]
		m.resume_altar.connect(func(sus): got[0] = sus)
		root.add_child(m)
		await _frames(2)
		_check(m.card_showing() and str(m._card["title"]) == "Continue from the altar", "a snapshot and a listener: the offer")
		_check(m._card_alt.visible and m._card_ok.text == "Continue", "Continue, or Not now")
		m._card_ok.pressed.emit()
		_check(str(got[0].get("level", "")) == "1-2", "Continue hands main the snapshot")
		m.queue_free()
		m = Map2.new()
		m.resume_altar.connect(func(sus): got[0] = sus)
		root.add_child(m)
		await _frames(2)
		_check(not m.card_showing(), "offered once a snapshot")
		m.queue_free()
		game.clear_suspend()
		await _frames(1)


func _test_map_challenges() -> void:
	## The Challenges button: only with the hub in the build and 1-2 cleared;
	## it says challenges() to main.gd, or with no one listening opens the hub
	## itself. The Feel lab button main.gd puts after the Chandler moves past it.
	_where = "map challenges"
	var Map = load("res://scripts/map_screen.gd")
	_fresh_hero(3)
	var m = Map.new()
	root.add_child(m)
	await _frames(2)
	_check(not m._challenges_btn.visible, "no hub in the build: no Challenges button")
	m.queue_free()
	Map.modes_screen = "res://scripts/ui.gd"
	m = Map.new()
	root.add_child(m)
	await _frames(2)
	_check(not m._challenges_btn.visible, "1-2 not cleared: none yet")
	m.queue_free()
	_clear_ids(["1-1", "1-2"])
	m = Map.new()
	var lab := Button.new()
	lab.name = "FeelLab"
	lab.text = "Feel lab"
	root.add_child(m)
	m.add_child(lab)
	await _frames(2)
	_check(m._challenges_btn.visible, "1-2 cleared: Challenges")
	_check(lab.position.x >= m._challenges_btn.position.x + m._challenges_btn.size.x, "main's Feel lab button goes after it")
	var heard := [0]
	m.challenges.connect(func(): heard[0] += 1)
	m._challenges_btn.pressed.emit()
	_check(heard[0] == 1, "it says challenges() to main.gd")
	var keep_md = game.data.get("modes", {})
	game.data["modes"] = {"descent": {"runs": {"knight": {"depth": 7}}}}
	_check(m.challenges_resume(), "a Descent run waiting for this calling: the ember")
	game.data["modes"]["descent"]["runs"] = {"witch": {"depth": 3}}
	_check(not m.challenges_resume(), "another calling's run: none")
	game.data["modes"] = keep_md
	var ms_lib = load("res://scripts/modes/modes_save.gd") if ResourceLoader.exists("res://scripts/modes/modes_save.gd") else null
	if ms_lib == null:
		_check(not m.challenges_news(), "no ModesSave in the build: no news")
	else:
		_check(m.challenges_news() == bool(ms_lib.has_news()), "the gold '!' is ModesSave.has_news()")
	m.queue_free()
	await _frames(1)
	Map.modes_screen = Map.MODES_SCREEN


func _test_hud_v3() -> void:
	## The v3 World -> HUD calls on a real World: the World turns the dim ring
	## on and off through its dims; the mode pill takes the sigils' place; a
	## card waits for the top band; the three-part boss bar; the finale fades
	## the HUD but not its message slot or the Special's pill; Candlemarks;
	## the flask's charges on the touch layer; a level with no sigils hides
	## their tray.
	_where = "HUD v3"
	_fresh_hero(40)
	game.add_xp(int(Progression.MARK_XP * 2.5))
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var w = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await _frames(1)
	var hud = HudScript.new()
	hud.world = w
	hud.story = _stub_story()
	hud._story_checked = true
	w.hud = hud
	w.add_child(hud)
	var touch = TouchScript.new()
	w.touch = touch
	w.add_child(touch)
	await _frames(1)
	w.test_pad = {}
	for i in 10:
		w.tick(DT)
	_check(hud._marks() == 2 and hud._marks_seen == 2, "two Candlemarks at level 40 (%d)" % hud._marks())
	var mf := float(game.xp_progress()["mark_frac"])
	_check(mf > 0.2 and mf < 0.8, "the stand-in hero is part way to the next Candlemark (%.2f)" % mf)
	for i in 180:
		hud._process(1.0 / 60.0)
	_check(absf(hud._xp_shown - mf) < 0.05, "the badge's ring settles toward the next Candlemark (%.2f of %.2f)" % [hud._xp_shown, mf])
	game.add_xp(int(Progression.MARK_XP * 0.6))
	for i in 120:
		hud._process(1.0 / 60.0)
	_check(hud._marks_seen == 3, "a third lands and the badge says so (%d)" % hud._marks_seen)
	# The dim ring, through the World's own dims.
	if w.has_method("dim"):
		w.dim("spores", 0.55, 1.0)
		w.tick(DT)
		_check(hud._dim_on, "a dim puts the ring on")
		for i in 150:
			w.tick(DT)
		_check(not hud._dim_on, "and it goes when the dim does")
	# The mode pill.
	w.mode_pill({"label": "D3", "clock": 61.0, "lives": 1, "lives_max": 2})
	_check(hud.pill_showing() and (hud.layout()["sigils"] as Rect2).size.x == 150.0, "the World's mode_pill puts the pill in the sigils' place")
	await _frames(2)
	w.mode_pill({})
	_check(not hud.pill_showing(), "{} takes it down")
	# A card: it waits for a title card, then shows for its time.
	hud.title_card("1-1", "The Nave")
	w.card("depth", "DEPTH 8", "The Tallow Deep")
	_check(str(hud._title.get("kind", "")) != "card" and hud._cardq.size() == 1, "a card waits behind a title card")
	for i in 60 * 4:
		hud._process(1.0 / 60.0)
	_check(str(hud._title.get("kind", "")) == "card" and str(hud._title["title"]) == "DEPTH 8", "then takes the top band")
	w.card("depth", "DEPTH 8", "The Tallow Deep")
	_check(hud._cardq.is_empty(), "the same card asked for again while it shows isn't queued twice")
	await _frames(2)
	for i in 60 * 5:
		hud._process(1.0 / 60.0)
	_check(hud._title.is_empty(), "and goes after %.1f s" % hud.CARD_TIME)
	# A level-up while a card is up: the card makes way (never drawn under
	# the level-up), and one cut early comes back after it.
	for early in [true, false]:
		hud._cardq.clear()
		w.card("depth9", "DEPTH 9", "The Tallow Deep")
		for i in (60 if early else 60 * 3):
			hud._process(1.0 / 60.0)
		_check(str(hud._title.get("kind", "")) == "card", "a card is up before the level-up")
		hud.level_up(int(game.hero()["level"]))
		var both := 0
		var back := false
		var left_lvl := false
		for i in 60 * 10:
			hud._process(1.0 / 60.0)
			if hud.title_alpha() > 0.02 and hud.level_alpha() > 0.02:
				both += 1
			if hud._lvl.is_empty():
				left_lvl = true
			if left_lvl and str(hud._title.get("title", "")) == "DEPTH 9" and hud.title_alpha() > 0.9:
				back = true
		_check(both == 0, "a level-up %s a card: the two never draw together (%d frames)" % ["early in" if early else "late in", both])
		_check(back == early, "a card cut %s %s after the level-up" % ["early" if early else "late", "comes back" if early else "doesn't come back"])
		hud._title = {}
		hud._lvl = {}
		hud._cardq.clear()
	# The boss bar in three.
	hud.boss_bar({"id": "saint", "name": "The Prism Saint", "title": "Light of the Sanctum", "frac": 0.5, "segments": [0.65, 0.3], "awake": true})
	await _frames(3)
	_check((hud._boss.get("segments", []) as Array).size() == 2, "the boss bar keeps its segments")
	hud.boss_bar({})
	# The finale: the HUD fades, the slot and the Special's pill don't.
	w.fade_for_finale(true)
	w.special_pill("Hold to give your flame")
	w.special_override = {"hold_ring": 0.5}
	for i in 90:
		w.tick(DT)
		hud._process(1.0 / 60.0)
	_check(hud.finale_alpha() < 0.05 and hud._view.modulate.a < 0.05, "the finale fades the HUD (%.2f)" % hud.finale_alpha())
	_check(hud._special_k > 0.99, "the Special's pill stays")
	# A line said while faded (the Hush's barks) draws on the unfaded layer.
	hud.slot_drawn = {}
	hud.toast("The Hush", "Give it to me.")
	for i in 20:
		hud._process(1.0 / 60.0)
		await process_frame
	var sd: Dictionary = hud.slot_drawn
	_check(sd.get("on") == hud._top and float(sd.get("a", 0.0)) > 0.5 and Engine.get_process_frames() - int(sd.get("frame", -99)) <= 2,
			"the message slot draws on the unfaded layer while the HUD is away (%s)" % [str(sd.get("kind", "none"))])
	_check(hud._top.visible and hud._top.modulate.a > 0.99 and hud._view.modulate.a < 0.05, "that layer is shown and unfaded, the rest faded")
	# The rev5 review: at the stair's top he stands under the top band, and the
	# finale's lines drew at SEE_THROUGH over the flame he gives. In the finale
	# the slot sits low between the thumbs and is read whole.
	var fr: Rect2 = hud.msg_rect(400.0, false)
	var gap: Array = hud._thumb_gap()
	_check(fr.position.y > hud._vs().y * 0.6 and fr.position.x >= float(gap[0]) - 0.5 and fr.end.x <= float(gap[1]) + 0.5,
			"in the finale the message slot is low, between the thumbs (%s, gap %s)" % [fr, gap])
	hud._see["msg"] = hud.SEE_THROUGH
	hud.toast("The Hush", "...there. quiet at last.")
	var full := 0.0
	for i in 40:
		hud._process(1.0 / 60.0)
		await process_frame
		full = maxf(full, float(hud.slot_drawn.get("a", 0.0)))
	_check(hud.see("msg") > 0.99 and full > 0.99, "the finale's lines draw whole, never see-through (see %.2f, a %.2f)" % [hud.see("msg"), full])
	w.finale_black = 1.0
	w.tick(DT)
	_check(touch._view.modulate.a < 0.01, "in the finale's black the touch controls go too (%.2f)" % touch._view.modulate.a)
	w.finale_black = 0.0
	w.tick(DT)
	_check(touch._view.modulate.a > 0.99, "and come back after it")
	_check(touch.special_state.has("hold_ring"), "the hold ring reaches the Special button")
	await _frames(2)
	w.fade_for_finale(false)
	w.special_pill("")
	w.special_override = {}
	for i in 120:
		hud._process(1.0 / 60.0)
	_check(hud.finale_alpha() > 0.99 and hud._special_k <= 0.0, "and both come back / go when it's over")
	# The flask's charges.
	touch.flask_state = {"charges": 2, "max": 3, "drinking": false}
	await _frames(2)
	var TL2: Dictionary = touch.layout()
	var rr := float(TL2["r_flask"])
	var arcs: Array = touch.flask_arcs(rr, 3, 2)
	_check(arcs.size() == 3 and arcs.filter(func(a): return a[2]).size() == 2, "a three-charge flask: three arcs, two lit")
	var badge_ang := -PI * 0.25
	var clear := asin((touch.FLASK_BADGE_R + 1.5) / (rr + 3.5))
	for k in arcs.size():
		var a0: float = arcs[k][0]
		var a1: float = arcs[k][1]
		_check(a1 > a0 + 0.3, "arc %d has length (%.2f..%.2f)" % [k, a0, a1])
		if k > 0:
			_check(a0 > float(arcs[k - 1][1]), "arcs %d and %d don't overlap" % [k - 1, k])
		# The badge's angular reach, wrapped into the arc's turn.
		for bang in [badge_ang, badge_ang + TAU]:
			_check(a1 <= bang - clear or a0 >= bang + clear, "arc %d stays out from under the charge badge" % k)
	_check(touch.flask_arcs(rr, 1, 1).is_empty(), "a one-charge flask has no arcs")
	_check(touch.flask_arcs(rr, 2, 0).size() == 2, "a two-charge flask, dry: two unlit arcs")
	w.queue_free()
	await _frames(2)
	# A level with no sigils (a mode's room): no sigil row, no tray.
	var lv2 = LevelData.load_file("res://levels/1-1.txt")
	lv2.entities = lv2.entities.filter(func(e): return str(e.get("kind", "")) != "sigil")
	var w2 = WorldScript.new()
	w2.setup(lv2, true)
	root.add_child(w2)
	await _frames(1)
	var hud2 = HudScript.new()
	hud2.world = w2
	w2.hud = hud2
	w2.add_child(hud2)
	await _frames(2)
	_check(not hud2.has_sigils(), "a level with no sigils hides their row")
	w2.queue_free()
	await _frames(2)


func _test_strength_card() -> void:
	## The candle-strength card: once a save, after 6 snuffs in a level or 5
	## at a boss, on Dusk at Normal strength; never in a mode or on Gentle.
	_where = "candle strength"
	_fresh_hero(3)
	game.data["notices"].erase("candle_strength")
	var ws := GDScript.new()
	ws.source_code = "extends Node\nvar player\nvar snuffs := 0\nvar diff := \"dusk\"\nvar mode = null\nvar paused := false\nvar boss = null\nvar touch = null\nvar embers_carried := 0\nvar sigils_got := [false, false, false]\n"
	ws.reload()
	var w: Node = ws.new()
	var ps := GDScript.new()
	ps.source_code = "extends Node2D\nvar hp := 50.0\nvar max_hp := 100.0\nvar res := 0.0\nvar res_max := 1.0\nvar stats := {\"cls\": \"knight\"}\nvar alive := true\n"
	ps.reload()
	w.player = ps.new()
	w.add_child(w.player)
	root.add_child(w)
	var hud = HudScript.new()
	hud.world = w
	w.add_child(hud)
	await _frames(1)
	for i in 5:
		w.snuffs += 1
		hud._process(0.1)
	_check(hud._cardq.is_empty() and str(hud._title.get("id", "")) != "candle_strength", "five snuffs in a level: nothing yet")
	w.snuffs += 1
	hud._process(0.1)
	var asked: bool = hud._cardq.any(func(c): return c["id"] == "candle_strength") or str(hud._title.get("id", "")) == "candle_strength"
	_check(asked, "the sixth: the card")
	_check(game.data["notices"].has("candle_strength"), "once a save (marked)")
	w.queue_free()
	await _frames(1)
	# At a boss: five, with the bar up.
	game.data["notices"].erase("candle_strength")
	w = ws.new()
	w.player = ps.new()
	w.add_child(w.player)
	root.add_child(w)
	hud = HudScript.new()
	hud.world = w
	w.add_child(hud)
	await _frames(1)
	hud.boss_bar({"id": "tollgrave", "name": "Old Tollgrave", "title": "", "frac": 0.9, "awake": true})
	for i in 5:
		w.snuffs += 1
		hud._process(0.1)
	asked = hud._cardq.any(func(c): return c["id"] == "candle_strength") or str(hud._title.get("id", "")) == "candle_strength"
	_check(asked, "five at a boss: the card")
	w.queue_free()
	await _frames(1)
	# Gentle already, or in a mode: never.
	for case in ["gentle", "mode"]:
		game.data["notices"].erase("candle_strength")
		game.set_setting("candle_strength", "gentle" if case == "gentle" else "normal")
		w = ws.new()
		w.player = ps.new()
		w.add_child(w.player)
		if case == "mode":
			w.mode = RefCounted.new()
		root.add_child(w)
		hud = HudScript.new()
		hud.world = w
		w.add_child(hud)
		await _frames(1)
		for i in 8:
			w.snuffs += 1
			hud._process(0.1)
		_check(hud._cardq.is_empty() and not game.data["notices"].has("candle_strength"), "%s: no card" % case)
		w.queue_free()
		await _frames(1)
	game.set_setting("candle_strength", "normal")


func _test_pause_modes() -> void:
	## Pause in a mode: its items replace Restart and Leave; one with confirm
	## asks for a second tap, then its callback runs.
	_where = "pause modes"
	var pm = load("res://scripts/pause_menu.gd").new()
	pm.world = _mode_world()
	root.add_child(pm.world)
	root.add_child(pm)
	await _frames(1)
	pm.open()
	await _frames(1)
	_check(not pm._restart_btn.visible and not pm._leave_btn.visible, "Restart and Leave step aside")
	_check(pm._mode_btns.size() == 2 and pm._mode_btns[0].text == "Rest here", "the mode's items show (%d)" % pm._mode_btns.size())
	var mode = pm.world.mode
	pm._mode_btns[1].pressed.emit()
	_check(mode.called.is_empty() and pm._mode_btns[1].text.begins_with("Tap again"), "one that asks: the first tap only asks")
	pm._mode_btns[1].pressed.emit()
	_check(mode.called == ["leave"], "the second runs it (%s)" % [mode.called])
	await _frames(2)
	_check(pm.world.closed == 1, "an item that leaves nothing behind hands the level back")
	pm.open()
	pm._mode_btns[0].pressed.emit()
	_check(mode.called == ["leave", "rest"], "one that doesn't ask runs at once")
	pm.world.mode = null
	pm.open()
	_check(pm._restart_btn.visible and pm._leave_btn.visible and pm._mode_btns.is_empty(), "out of a mode, Restart and Leave are back")
	pm.queue_free()
	pm.world.queue_free()
	await _frames(1)
	# An item that resumes the level itself ("Rest here" calling close_pause):
	# the HUD and the touch controls come back, live.
	pm = load("res://scripts/pause_menu.gd").new()
	pm.world = _mode_world()
	var ts := GDScript.new()
	ts.source_code = "extends Node\nvar visible_controls := true\nfunc release_all():\n\tpass\n"
	ts.reload()
	pm.world.touch = ts.new()
	pm.world.hud = Control.new()
	pm.world.add_child(pm.world.touch)
	pm.world.add_child(pm.world.hud)
	var rest := PauseRest.new()
	rest.w = pm.world
	pm.world.mode = rest
	root.add_child(pm.world)
	root.add_child(pm)
	await _frames(1)
	pm.open()
	_check(not pm.world.hud.visible and not pm.world.touch.visible_controls and not pm.world.touch.is_processing_input(), "pause hides the HUD and the touch controls")
	pm._mode_btns[0].pressed.emit()
	await _frames(2)
	_check(not pm.world.paused and not pm.visible, "the item resumed the level itself")
	_check(pm.world.hud.visible and pm.world.touch.visible_controls and pm.world.touch.is_processing_input(),
			"and the HUD and touch controls are back and live (hud %s, controls %s, input %s)" % [pm.world.hud.visible, pm.world.touch.visible_controls, pm.world.touch.is_processing_input()])
	pm.queue_free()
	pm.world.queue_free()
	await _frames(1)


func _test_skills_deep() -> void:
	## The deep tree's Tiers 4 and 5 and their lock texts.
	_where = "skills deep"
	Classes.set_deep(true)
	_fresh_hero(15)
	var sp = await _sheet("skills")
	await _frames(2)
	var panel = sp.panel
	_check(panel.deep() and panel.rows().size() == 6, "six rows")
	var t4 := ""
	var cap2 := ""
	for n in Classes.tree("knight"):
		if int(n["tier"]) == 4 and int(n["branch"]) == 0:
			t4 = n["id"]
	panel.select(t4)
	var why: String = Classes.can_buy("knight", t4, game.hero()["skills"], 15, 1)
	_check(panel._reason(why) == "Opens at level 16.", "a Tier 4 at L15: \"%s\"" % panel._reason(why))
	# Both capstones' branches bought up at L29: the other capstone waits for 30.
	game.add_xp(Progression.total_to(29) - int(game.hero()["xp"]))
	var caps: Array = Classes.tree("knight").filter(func(n): return int(n["tier"]) == 3)
	var sk: Dictionary = game.hero()["skills"]
	for n in Classes.tree("knight"):
		if int(n["tier"]) in [1, 2]:
			sk[n["id"]] = int(n["max"])
	sk[caps[0]["id"]] = 1
	cap2 = caps[1]["id"]
	panel.select(cap2)
	why = Classes.can_buy("knight", cap2, sk, 29, 3)
	_check(panel._reason(why) == "The other capstone opens at level 30.", "the other capstone: \"%s\"" % panel._reason(why))
	why = Classes.can_buy("knight", t4, {}, 20, 3)
	_check(panel._reason(why) == "Needs 7 points in this branch.", "Tier 4's branch gate: \"%s\"" % panel._reason(why))
	await _frames(2)
	sp.queue_free()
	Classes.set_deep(false)
	_fresh_hero(15)
	sp = await _sheet("skills")
	await _frames(2)
	_check(not sp.panel.deep() and sp.panel.rows().size() == 4, "v2's tree keeps its four rows")
	sp.queue_free()
	await _frames(1)
	# The two-capstone moment: at 30, one capstone owned, the Skills tab
	# plays second_capstone over the Sheet, once.
	var HS = load("res://scripts/hero_screen.gd")
	for c in [[29, 1, false], [30, 0, false], [30, 2, false], [30, 1, true]]:
		_capstone_hero(c[0], c[1])
		var hs = HS.new()
		root.add_child(hs)
		hs.open_tab("skills")
		await _frames(1)
		_check(hs.bark_showing() == c[2], "level %d, %d capstone%s: %s" % [c[0], c[1], "" if c[1] == 1 else "s", "the bark plays" if c[2] else "no bark"])
		if c[2]:
			_check(hs.bark_text() != "" and game.data["notices"].has("second_capstone"), "it says something and is marked (\"%s\")" % hs.bark_text())
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = true
			e.position = hs.bark_rect().get_center()
			hs._input(e)
			for i in 40:
				hs._process(1.0 / 60.0)
			_check(not hs.bark_showing(), "a tap on it ends it")
			hs.open_tab("stats")
			hs.open_tab("skills")
			await _frames(1)
			_check(not hs.bark_showing(), "the Skills tab again: no bark")
		hs.queue_free()
		await _frames(1)
	_capstone_hero(30, 1)
	Classes.set_deep(false)
	var hs2 = HS.new()
	root.add_child(hs2)
	hs2.open_tab("skills")
	await _frames(1)
	_check(not hs2.bark_showing(), "v2's tree: no bark")
	hs2.queue_free()
	await _frames(1)


func _test_gear_waits() -> void:
	## Where boots and charms turn up only deeper down, the empty slots say
	## where; worn, or on Nightfall, they don't.
	_where = "gear waits"
	Items.slots_by_area = true
	_fresh_hero(5)
	game.hero()["deepest"] = 5
	game.hero()["equip"].erase("boots")
	game.hero()["equip"].erase("charm")
	var sp = await _sheet("gear")
	await _frames(2)
	_check(sp.panel.waits_text("boots") == "Turns up in World 3", "boots: \"%s\"" % sp.panel.waits_text("boots"))
	_check(sp.panel.waits_text("charm") == "Turns up in World 4", "charm: \"%s\"" % sp.panel.waits_text("charm"))
	_check(sp.panel.waits_text("weapon") == "", "a weapon never waits")
	game.hero()["deepest"] = 18
	_check(sp.panel.waits_text("boots") == "" and sp.panel.waits_text("charm") == "", "down at area 18 both drop")
	game.hero()["deepest"] = 5
	sp.panel.select_slot("boots")
	await _frames(2)
	sp.queue_free()
	Items.slots_by_area = false
	sp = await _sheet("gear")
	await _frames(1)
	_check(sp.panel.waits_text("boots") == "", "with every slot live (v2), nothing waits")
	sp.queue_free()
	await _frames(1)


func _test_results_v3() -> void:
	## Results: "Secret found!" and its pill; the Second Draught's pill; W6's
	## candles; a Lost Wick; Candlemarks past 40; the spark on a level whose
	## secret waits (only when that secret level is built).
	_where = "results v3"
	var R = load("res://scripts/results_screen.gd")
	var kept := _six_worlds()
	_fresh_hero(6)
	var r = R.new()
	r.result = {"level": "1-3", "cleared": true, "embers": 5, "embers_total": 40, "sigils": [false, false, false], "time": 70.0,
			"relics": [], "items": [], "xp": 10, "levels": 0, "diff": "dusk", "secret": "1-S", "secret_new": true}
	r.rewards = [{"kind": "secret", "id": "1-S"}, {"kind": "draught", "id": "second"}]
	game.find_secret("1-S", "dusk", false)
	root.add_child(r)
	r._t = 10.0
	await _frames(2)
	var texts: Array = r.pills.map(func(p): return str(p["text"]))
	_check(texts.has("Secret level open") and texts.has("+1 flask charge"), "the secret's and the draught's pills (%s)" % [texts])
	_check(not r.secret_here("1-3"), "its secret found here: no spark")
	_check(r.head_text() == "Secret found!", "the first ring: \"Secret found!\" (%s)" % r.head_text())
	r.queue_free()
	await _frames(1)
	# Rung again once it's open: no "Secret found!", no pill.
	var r1 = R.new()
	r1.result = {"level": "1-3", "cleared": true, "embers": 5, "embers_total": 40, "sigils": [false, false, false], "time": 70.0,
			"relics": [], "items": [], "xp": 10, "levels": 0, "diff": "dusk", "secret": "1-S", "secret_new": false}
	r1.rewards = []
	root.add_child(r1)
	r1._t = 10.0
	await _frames(2)
	_check(r1.head_text() == "The bell is rung" and not r1.pills.any(func(p): return str(p["text"]) == "Secret level open"),
			"a ring once it's open: \"%s\", no secret pill" % r1.head_text())
	r1.queue_free()
	var r1b = R.new()
	r1b.result = {"level": "1-3", "cleared": true, "diff": "dusk", "secret": "1-S"}
	r1b.rewards = [{"kind": "secret", "id": "1-S"}]
	_check(r1b.head_text() == "Secret found!", "record_result's secret reward says it's new too")
	r1b.free()
	await _frames(1)
	game.data["secrets"]["dusk"].erase("1-S")
	var r2 = R.new()
	r2.result = {"level": "1-3", "cleared": true, "diff": "dusk"}
	_check(r2.secret_here("1-3"), "1-3's secret still to find: the spark")
	_check(not r2.secret_here("1-2"), "1-2 holds none")
	r2.free()
	_back_to_build(kept)
	var r3 = R.new()
	r3.result = {"level": "1-3", "cleared": true, "diff": "dusk"}
	# 1-S ships now (WLS): the build's own answer, then a registry whose 1-S
	# file is gone (UI's stand-in), which must show no spark.
	_check(r3.secret_here("1-3") == FileAccess.file_exists("res://levels/1-S.txt"), "the build's 1-S: the spark follows its file")
	var gone := []
	for sl in UI.secret_levels():
		var e: Dictionary = (sl as Dictionary).duplicate()
		if str(e["id"]) == "1-S":
			e["path"] = "res://levels/_not_built_1-S.txt"
		gone.append(e)
	UI.secret_levels_override = gone
	_check(not r3.secret_here("1-3"), "1-S not in the build: no spark")
	UI.secret_levels_override = null
	r3.free()
	# A Lost Wick and W6's candles, at level 40 with a Candlemark coming.
	_fresh_hero(40)
	game.add_xp(int(Progression.MARK_XP * 0.9))
	var gained := int(Progression.MARK_XP * 0.2)
	game.add_xp(gained)
	var r4 = R.new()
	r4.result = {"level": "1-S", "cleared": true, "embers": 5, "embers_total": 40, "sigils": [true, false, false], "time": 70.0,
			"relics": [], "items": [], "xp": gained, "levels": 0, "diff": "dusk", "lost_wick": 1, "candles": {"lit": 7, "total": 9}}
	root.add_child(r4)
	await _frames(1)
	_check(str(r4._lost.get("name", "")) == "The Lamplighter", "1-S's Lost Wick is the Lamplighter (%s)" % r4._lost.get("name", ""))
	_check(r4._candles() == Vector2i(7, 9), "the candles counted")
	var flashed := false
	for i in 5 * 60:
		r4._process(1.0 / 60.0)
		flashed = flashed or r4._mark_flash > 0.0
	_check(flashed and r4._marks_seen == 1, "a Candlemark lands as the bar fills")
	await _frames(2)
	r4.queue_free()
	await _frames(1)


func _test_ui_v3() -> void:
	## UI's v3 pieces: icons clamp to the highest tier drawn; the flame takes
	## a palette; every world's emblem draws; the Sheet has no Look tab until
	## the modes' panel is in the build.
	_where = "ui v3"
	var it := {"slot": "weapon", "cls": "knight", "tier": 5}
	var p: String = UI.item_icon_path(it)
	_check(ResourceLoader.exists(p), "a T5 weapon's icon is one that exists (%s)" % p)
	_check(UI.item_icon_path({"slot": "coat", "tier": 2}) == "res://art/items/coat_2.svg", "a T2 coat keeps its own")
	for k in UI.WORLD_ACCENT:
		_check(UI.world_accent(k) is Color, "world %d has its accent" % k)
	var c := Control.new()
	c.size = Vector2(200, 100)
	c.draw.connect(func():
		UI.flame(c, Vector2(50, 90), 30.0, 1.0, 0.0, false, 1.0, true, {"out": Color("e05a8a"), "mid": Color("f7b64a"), "core": Color.WHITE, "halo": Color("ff8888"), "shift": 0.1, "alpha": 0.8})
		for w in range(1, 7):
			UI.world_emblem(c, w, Vector2(20 + w * 25, 30), 22.0, UI.world_accent(w))
		UI.mark_badge(c, Vector2(10, 60), 3)
		UI.draw_card(c, Rect2(0, 0, 200, 100), "Title", "Body words here.", UI.GOLD, 1.0, 3))
	var drew := [0]
	c.draw.connect(func(): drew[0] += 1)
	root.add_child(c)
	var e0: int = catch.since(0).size()
	await _frames(2)
	_check(drew[0] > 0 and catch.since(e0).is_empty(), "the flame with a palette, the emblems, the mark and a card draw, without errors (%d draws, %s)" % [drew[0], catch.since(e0).slice(0, 2)])
	c.queue_free()
	var HS = load("res://scripts/hero_screen.gd")
	_check(HS.TABS.has("look") and HS.tabs().has("look") == ResourceLoader.exists(HS.PANEL_PATH["look"]), "the Look tab shows exactly when its panel is in the build")
	await _frames(1)
