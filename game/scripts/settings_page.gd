extends Control
## The Settings page. Over a level it is the pause menu's (pause_menu.gd:
## world set, a see-through backdrop, the level's settings applied at once);
## on its own (standalone) main.gd opens it from the title and from the map,
## over the menus' backdrop, and Back (or Esc / Menu) says back().
##
## Along the top: Back, the title, and the Sound, Music and Buzz switches
## (Sfx.muted, Sfx.music_muted, Game.haptics: each saved). Then the settings
## in two columns (SETTINGS: tap a value; a row's note under it where the
## row is tall enough). Along the foot: the game's version and its links
## out (links.gd): Privacy policy, Support, Licenses (licenses_page.gd, over
## this page) and Rate Waxby (only while Links has an app id).

signal back

const UI := preload("res://scripts/ui.gd")
const Links := preload("res://scripts/links.gd")
const LicensesScript := preload("res://scripts/licenses_page.gd")

# key, label, [values], [names], note
const SETTINGS := [
	["numbers", "Damage numbers", ["on", "crits", "off"], ["On", "Crits", "Off"], ""],
	["shake", "Screen shake", [1.0, 0.5, 0.0], ["Full", "Half", "Off"], ""],
	["button_scale", "Button size", [0.9, 1.0, 1.1], ["S", "M", "L"], ""],
	["brightness", "Brightness", [0.0, 0.08, 0.16], ["Dark", "Lighter", "Lightest"], "How deep the dark is."],
	["candle_strength", "Candle strength", ["gentle", "normal", "fierce"], ["Gentle", "Normal", "Fierce"], "Monster damage ×0.75 / ×1 / ×1.3."],
	["auto_equip", "Auto-equip upgrades", [true, false], ["On", "Off"], "Wear what's plainly better."],
	["auto_sell", "Sell weaker finds", [true, false], ["On", "Off"], "Tap the card to keep one."],
	["auto_advance", "Story lines", [false, true], ["Tap", "Auto"], ""],
]
const TOP := 50.0                 # the rows start this far under the safe area's top
const ROW_MAX := 74.0             # a row's pitch at most
const ROW_GAP := 6.0              # between two rows' panels
const FOOT_GAP := 6.0             # between the last row and the foot's links
const NOTE_ROOM := 56.0           # a row this tall or more has room for its note

var world: Node = null            # the level being paused, or null
var standalone := false           # on its own (the title's, the map's): its own backdrop
var licenses: Control = null      # the Licenses page while it is open over this one
var _body: Control                # everything but the Licenses page
var _back_btn: Button
var _sound: Button
var _music: Button
var _haptics: Button
var _links: Array = []            # the foot's buttons, left to right
var _setting_btns := {}           # key -> [Button]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name = "Settings"
	mouse_filter = Control.MOUSE_FILTER_STOP if standalone else Control.MOUSE_FILTER_IGNORE
	UI.warm()
	_body = Control.new()
	_body.name = "Body"
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(func(): _draw_body(_body))
	add_child(_body)
	_back_btn = UI.make_button("Back", false, func(): back.emit(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	_back_btn.name = "Back"
	_body.add_child(_back_btn)
	_sound = _small("", toggle_sound, "Sound")
	_music = _small("", toggle_music, "Music")
	_haptics = _small("", toggle_haptics, "Buzz")
	for b in [_sound, _music, _haptics]:
		b.custom_minimum_size = Vector2(88, UI.TAP_H)
	for row in SETTINGS:
		var btns: Array = []
		for i in (row[2] as Array).size():
			var v = row[2][i]
			var key: String = row[0]
			var b := UI.make_button(row[3][i], false, func(): set_value(key, v), "click", 13)
			UI.small_button(b, 13)
			b.custom_minimum_size = Vector2(62, UI.TAP_H)
			_body.add_child(b)
			btns.append(b)
		_setting_btns[row[0]] = btns
	_links.append(_small("Privacy policy", func(): Links.privacy(), "Privacy"))
	_links.append(_small("Support", func(): Links.support(), "Support"))
	_links.append(_small("Licenses", open_licenses, "LicensesLink"))
	_links.append(_small("Rate Waxby", func(): Links.rate(), "Rate"))
	for b in _links:
		b.add_theme_color_override("font_color", UI.MUTED)
	refresh()


func _small(text: String, cb: Callable, node_name: String) -> Button:
	var b := UI.make_button(text, false, cb, "click", 13)
	UI.small_button(b, 13)
	b.custom_minimum_size = Vector2(0, UI.TAP_H)
	b.name = node_name
	_body.add_child(b)
	return b


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _sfx_node() -> Node:
	return get_node_or_null("/root/Sfx")


# ---------------------------------------------------------------- the switches and settings

func toggle_sound() -> void:
	var s := _sfx_node()
	if s:
		s.muted = not s.muted
	refresh()


func toggle_music() -> void:
	var s := _sfx_node()
	if s:
		s.music_muted = not s.music_muted
	refresh()


func toggle_haptics() -> void:
	var g := _game()
	if g:
		g.haptics = not g.haptics
	refresh()


func set_value(key: String, v) -> void:
	## Saves a setting and, over a level, applies it there where it can.
	var g := _game()
	if g == null:
		return
	g.set_setting(key, v)
	if world:
		match key:
			"numbers":
				if world.get("floaters") != null:
					world.floaters.mode = str(v)
			"button_scale":
				if world.get("touch") != null and world.touch.has_method("apply_settings"):
					world.touch.apply_settings()
			"brightness":
				if world.has_method("_apply_theme_dark"):
					world._apply_theme_dark()
	refresh()


static func same(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.001
	return str(a) == str(b)


func refresh() -> void:
	## The switches' words, the lit value in each row, and the layout.
	if _sound == null:
		return
	var s := _sfx_node()
	var g := _game()
	if s:
		_sound.text = "Sound " + ("off" if s.muted else "on")
		_music.text = "Music " + ("off" if s.music_muted else "on")
	_haptics.text = "Buzz " + ("on" if g and g.haptics else "off")
	(_links[3] as Button).visible = Links.can_rate()
	if g != null:
		for row in SETTINGS:
			var cur = g.setting(row[0])
			var btns: Array = _setting_btns[row[0]]
			for i in btns.size():
				var on := same(cur, row[2][i])
				var b: Button = btns[i]
				var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
				sb.bg_color = Color("3a2a1a") if on else Color("221a2e")
				sb.border_color = UI.GOLD if on else Color(UI.PANEL_EDGE, 0.7)
				b.add_theme_stylebox_override("normal", sb)
				b.add_theme_color_override("font_color", UI.GOLD if on else UI.MUTED)
	layout()


# ---------------------------------------------------------------- Licenses

func open_licenses() -> void:
	## Credits and licenses over this page; its Back comes back here.
	if licenses != null and is_instance_valid(licenses):
		return
	licenses = LicensesScript.new()
	licenses.back.connect(close_licenses)
	add_child(licenses)
	_body.visible = false


func close_licenses() -> void:
	if licenses != null and is_instance_valid(licenses):
		licenses.queue_free()
	licenses = null
	_body.visible = true
	refresh()


func handle_back() -> bool:
	## Esc / Menu / Back on the page: closes the Licenses if they're open
	## (true), else false (the host leaves the page).
	if licenses != null and is_instance_valid(licenses):
		close_licenses()
		return true
	return false


# ---------------------------------------------------------------- layout

func foot_y() -> float:
	## The top of the foot's links.
	var s := UI.safe_rect(get_viewport())
	return s.end.y - UI.TAP_H - 2.0


func rows() -> Array:
	## {key, rect} for each setting: two columns between the top row and the
	## foot's links.
	var s := UI.safe_rect(get_viewport())
	var out: Array = []
	var colw := (s.size.x - 20.0) * 0.5
	var top := s.position.y + TOP
	var per := ceili(SETTINGS.size() / 2.0)
	var rh := minf((foot_y() - FOOT_GAP - top + ROW_GAP) / per, ROW_MAX)
	for i in SETTINGS.size():
		var c := i / per
		var x := s.position.x + c * (colw + 20.0)
		var y := top + (i % per) * rh
		out.append({"key": SETTINGS[i][0], "rect": Rect2(x, y, colw, rh - ROW_GAP)})
	return out


func toggles_x() -> float:
	## Where the Sound / Music / Buzz switches start (they end at the right).
	var s := UI.safe_rect(get_viewport())
	var w := 0.0
	for b in [_sound, _music, _haptics]:
		b.reset_size()
		w += b.size.x
	return s.end.x - w - 12.0


func layout() -> void:
	if _back_btn == null:
		return
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)
	var x := toggles_x()
	for b in [_sound, _music, _haptics]:
		b.reset_size()
		b.position = Vector2(x, s.position.y + 2.0)
		x += b.size.x + 6.0
	for r in rows():
		var rect: Rect2 = r["rect"]
		var btns: Array = _setting_btns[r["key"]]
		var bx := rect.end.x - 10.0
		var by := rect.position.y + (4.0 if rect.size.y < 66.0 else 5.0)
		for i in range(btns.size() - 1, -1, -1):
			var b: Button = btns[i]
			b.reset_size()
			bx -= b.size.x
			b.position = Vector2(bx, by)
			bx -= 4.0
	# The links, right to left from the right edge.
	var lx := s.end.x
	for i in range(_links.size() - 1, -1, -1):
		var b: Button = _links[i]
		if not b.visible:
			continue
		b.reset_size()
		lx -= b.size.x
		b.position = Vector2(lx, foot_y())
		lx -= 6.0
	_body.queue_redraw()


func version_text() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return "Waxby %s" % v if v != "" else "Waxby"


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _back_btn != null:
		layout()


func _unhandled_input(event: InputEvent) -> void:
	# Over a level the pause menu takes Esc (it asks handle_back first).
	if not standalone or not is_visible_in_tree():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if not handle_back():
			back.emit()
		get_viewport().set_input_as_handled()


func _draw_body(ci: Control) -> void:
	var s := UI.safe_rect(ci.get_viewport())
	var vs := ci.get_size()
	if standalone:
		UI.backdrop(ci, vs)
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(UI.BG, 0.35))
	else:
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.5))
	# The title, centred on the screen where it clears Back and the
	# switches, else in the room between them.
	var l := _back_btn.position.x + _back_btn.size.x + 8.0
	var r := toggles_x() - 8.0
	var tsize := UI.fit_size("Settings", r - l, 30, 20, "title", 700)
	var tw := UI.text_width("Settings", tsize, "title", 700)
	var tx := vs.x * 0.5 - tw * 0.5
	if tx < l or tx + tw > r:
		tx = l + (r - l - tw) * 0.5
	UI.text(ci, Vector2(tx, s.position.y + 30.0), "Settings", tsize, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 6)
	var rs := rows()
	for i in rs.size():
		var rect: Rect2 = rs[i]["rect"]
		var row: Array = SETTINGS[i]
		UI.panel(ci, rect, Color(UI.PANEL_EDGE, 0.5), Color(UI.PANEL, 0.85), 10.0)
		var btns: Array = _setting_btns[row[0]]
		var lw: float = (btns[0] as Button).position.x - rect.position.x - 18.0
		var compact := rect.size.y < 66.0
		UI.text(ci, Vector2(rect.position.x + 12.0, rect.position.y + (27.0 if compact else 30.0)), row[1], UI.fit_size(row[1], lw, 15, 11, "body", 700), UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, lw, "body", 700)
		var note: String = row[4]
		if row[0] == "candle_strength" and world != null:
			note = "Monster damage ×0.75 / ×1 / ×1.3, from the next level in."
		if note != "" and rect.size.y >= NOTE_ROOM:
			var nw := rect.size.x - 24.0
			UI.text(ci, Vector2(rect.position.x + 12.0, rect.position.y + (55.0 if compact else 59.0)), note, UI.fit_size(note, nw, 11 if compact else 12, 9), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, nw)
	# The version, left of the links where there's room.
	var vt := version_text()
	var first_link := s.end.x
	for b in _links:
		if (b as Button).visible:
			first_link = minf(first_link, (b as Button).position.x)
	if s.position.x + UI.text_width(vt, 12, "body", 600) + 12.0 < first_link:
		UI.text(ci, Vector2(s.position.x + 2.0, foot_y() + 25.0), vt, 12, Color(UI.MUTED, 0.75), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 600)
