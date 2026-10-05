extends CanvasLayer
## The pause sheet over a level: Resume, the Sheet (the hero's stats, skills,
## gear and belt; the belt only to look at: it changes between levels, on the
## map's Sheet, and a lit altar offers a relic found with it full, world.gd
## open_relic), Settings, Restart and Leave, the sound / music / buzz
## switches, and on the right who's playing and the relics on the belt.
## Settings (settings_page.gd, the same page the title and the map open)
## take effect at once where they can (numbers, shake, button size,
## brightness); candle strength from the next level in. Its foot links to the
## privacy policy, support, the licenses and the App Store review.
##
## v3: in a mode (world.mode), its pause_items() ([{label, cb, confirm}])
## take the place of Restart and Leave ("Rest here", "Leave the Descent",
## "Retry"...); one with confirm asks for a second tap ("Tap again: ..."). A
## belt of four or five relics is listed a line each.

const UI := preload("res://scripts/ui.gd")
const Relics := preload("res://scripts/relics.gd")
const Classes := preload("res://scripts/classes.gd")
const SheetScript := preload("res://scripts/hero_screen.gd")
const SettingsPage := preload("res://scripts/settings_page.gd")

const SETTINGS := SettingsPage.SETTINGS

var world: Node
var _root: Control
var _card: Control
var _main: VBoxContainer
var _toggles: HBoxContainer
var _sheet_btn: Button
var _sound: Button
var _music: Button
var _haptics: Button
var _settings: Control           # the Settings page (settings_page.gd)
var _sheet: Control
var page := "main"                # main, settings, sheet
var _face := {}
var _restart_btn: Button
var _leave_btn: Button
var _mode_btns: Array = []        # a mode's items (v3), in place of Restart and Leave
var _armed := -1                  # the mode item waiting for its second tap
var _armed_t := 0.0


func _ready() -> void:
	layer = 10
	visible = false
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_card = Control.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.draw.connect(func(): _draw_card(_card))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 8)
	_main.name = "Buttons"
	_root.add_child(_main)
	_main.add_child(_button("Resume", true, _resume))
	_sheet_btn = _button("Sheet", false, open_sheet)
	_main.add_child(_sheet_btn)
	_main.add_child(_button("Settings", false, func(): show_page("settings")))
	_restart_btn = _button("Restart level", false, _restart)
	_leave_btn = _button("Leave to map", false, _leave)
	_main.add_child(_restart_btn)
	_main.add_child(_leave_btn)
	_toggles = HBoxContainer.new()
	_toggles.add_theme_constant_override("separation", 8)
	_main.add_child(_toggles)
	_sound = _button("", false, _toggle_sound)
	_music = _button("", false, _toggle_music)
	_haptics = _button("", false, _toggle_haptics)
	for b in [_sound, _music, _haptics]:
		UI.small_button(b, 13)
		b.custom_minimum_size = Vector2(88, UI.TAP_H)
		_toggles.add_child(b)
	_build_settings()
	_labels()


func _button(text: String, accent: bool, cb: Callable) -> Button:
	var b := UI.make_button(text, accent, cb, "click", 17)
	b.custom_minimum_size = Vector2(280, UI.TAP_H)
	return b


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _sfx_node() -> Node:
	return get_node_or_null("/root/Sfx")


func _labels() -> void:
	var s := _sfx_node()
	var g := _game()
	if s:
		_sound.text = "Sound " + ("off" if s.muted else "on")
		_music.text = "Music " + ("off" if s.music_muted else "on")
	_haptics.text = "Buzz " + ("on" if g and g.haptics else "off")
	var pts := int(g.hero().get("points", 0)) if g else 0
	_sheet_btn.text = "Sheet" + ("   +%d skill point%s" % [pts, "" if pts == 1 else "s"] if pts > 0 else "")
	_sheet_btn.add_theme_color_override("font_color", UI.GOLD if pts > 0 else UI.CREAM)
	for i in _mode_btns.size():
		var b: Button = _mode_btns[i]
		var label := str(b.get_meta("label", ""))
		b.text = ("Tap again: %s" % label) if i == _armed else label
		b.add_theme_color_override("font_color", UI.BAD if i == _armed else UI.CREAM)
		# A long one ("Leave the Descent (costs a Spare Wick)") keeps to the column.
		b.add_theme_font_size_override("font_size", UI.fit_size(b.text, 280.0 - 34.0, 17, 12, "body", 700))
	_refresh_settings()


func mode_items() -> Array:
	## A mode's pause items, or [] outside one (or before the mode has any).
	var m = world.get("mode") if world != null else null
	if m == null or not (m is Object) or not m.has_method("pause_items"):
		return []
	var items = m.pause_items()
	return items if items is Array else []


func _build_mode_items() -> void:
	## In a mode its items replace Restart and Leave.
	for b in _mode_btns:
		b.queue_free()
	_mode_btns = []
	_armed = -1
	var items := mode_items()
	_restart_btn.visible = items.is_empty()
	_leave_btn.visible = items.is_empty()
	for i in items.size():
		var it = items[i]
		if not (it is Dictionary):
			continue
		var k := i
		var b := _button(str(it.get("label", "")), false, func(): _mode_item(k))
		b.set_meta("label", str(it.get("label", "")))
		_main.add_child(b)
		_main.move_child(b, _toggles.get_index())
		_mode_btns.append(b)


func _mode_item(i: int) -> void:
	var items := mode_items()
	if i < 0 or i >= items.size() or not (items[i] is Dictionary):
		return
	var it: Dictionary = items[i]
	if bool(it.get("confirm", false)) and _armed != i:
		_armed = i
		_armed_t = 3.0
		_labels()
		return
	_armed = -1
	var cb = it.get("cb")
	visible = false
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()
	# An item that leaves the level (the usual) takes the World with it; one
	# that doesn't hands the level back.
	_after_item.call_deferred()


func _after_item() -> void:
	## A frame after a mode item ran, a World still here gets its level back:
	## unpaused if the item left it paused, and either way its HUD and touch
	## controls shown and live again (an item may resume the level itself).
	if world != null and is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and not visible:
		if world.get("paused") == true:
			close()
		else:
			page = "main"
			_restore_level()


func open() -> void:
	visible = true
	_build_mode_items()
	show_page("main")
	_face = UI.hero_face(_cls(), "normal")
	_labels()
	if world and world.touch:
		world.touch.release_all()
		world.touch.set_process_input(false)
		world.touch.visible_controls = false
	if world and world.get("hud") != null:
		world.hud.visible = false


func show_page(p: String) -> void:
	page = p
	_main.visible = p == "main"
	if p != "settings" and _settings.licenses != null:
		_settings.close_licenses()
	_settings.visible = p == "settings"
	if p != "sheet" and _sheet:
		_sheet.queue_free()
		_sheet = null
	_labels()
	_place()


func open_sheet() -> void:
	## The Sheet over the paused level; changes go straight onto Waxby. It
	## opens on Skills while a skill point waits. Over a level its Belt tab
	## is only to look at (belt_panel.editable: the hero_screen's over_level).
	show_page("sheet")
	_sheet = SheetScript.new()
	var g := _game()
	if g != null and int(g.hero().get("points", 0)) > 0:
		_sheet.tab = "skills"
	_sheet.over_level = true
	_sheet.world = world
	_sheet.back.connect(func(): show_page("main"))
	_sheet.changed.connect(func():
		if world and world.has_method("apply_hero"):
			world.apply_hero())
	_root.add_child(_sheet)


func _place() -> void:
	var s := UI.safe_rect(_root.get_viewport())
	_main.reset_size()
	_main.position = Vector2(s.position.x + maxf((s.size.x * 0.5 - _main.size.x) * 0.5, 10.0), s.position.y + 74.0)
	_settings.position = Vector2.ZERO
	_settings.size = _root.get_size()
	_card.queue_redraw()


func close() -> void:
	visible = false
	if _settings.licenses != null:
		_settings.close_licenses()
	if _sheet:
		_sheet.queue_free()
		_sheet = null
	page = "main"
	if world:
		_restore_level()
		world.close_pause()


func _restore_level() -> void:
	## What open() took away: the touch controls (shown, live) and the HUD.
	if world == null:
		return
	if world.touch:
		world.touch.set_process_input(true)
		world.touch.visible_controls = true
		if world.touch.has_method("apply_settings"):
			world.touch.apply_settings()
	if world.get("hud") != null:
		world.hud.visible = true


func _resume() -> void:
	close()


func _restart() -> void:
	visible = false
	world.restart.emit()


func _leave() -> void:
	visible = false
	world.quit.emit()


func _toggle_sound() -> void:
	var s := _sfx_node()
	if s:
		s.muted = not s.muted
	_labels()


func _toggle_music() -> void:
	var s := _sfx_node()
	if s:
		s.music_muted = not s.music_muted
	_labels()


func _toggle_haptics() -> void:
	var g := _game()
	if g:
		g.haptics = not g.haptics
	_labels()


# ---------------------------------------------------------------- settings

func _build_settings() -> void:
	_settings = SettingsPage.new()
	_settings.world = world
	_settings.visible = false
	_root.add_child(_settings)
	_settings.back.connect(func(): show_page("main"))


func settings_rows() -> Array:
	## {key, rect} for each setting row: the page's two columns.
	return _settings.rows()


func set_value(key: String, v) -> void:
	## Saves a setting and applies it to the level where it can.
	_settings.world = world
	_settings.set_value(key, v)


func _refresh_settings() -> void:
	if _settings != null:
		_settings.world = world
		_settings.refresh()


# ---------------------------------------------------------------- input and drawing

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("pause") and world:
			world.open_pause()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if page == "main":
			close()
		elif page == "settings" and not _settings.handle_back():
			show_page("main")
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if visible and page == "main":
		_card.queue_redraw()
	if _armed >= 0:
		_armed_t -= dt
		if _armed_t <= 0.0:
			_armed = -1
			_labels()


func _cls() -> String:
	var g := _game()
	return str(g.hero()["cls"]) if g else "knight"


func _draw_card(ci: Control) -> void:
	if not visible or page != "main":
		return
	var s := UI.safe_rect(ci.get_viewport())
	var colx := _main.position.x
	UI.text(ci, Vector2(colx, s.position.y + 38.0), "Paused", 34, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 6)
	if world and world.get("level") != null:
		UI.text(ci, Vector2(colx, s.position.y + 60.0), "%s  %s" % [world.level.subtitle, world.level.title], 14, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	# Who's playing, and what's on the belt.
	var g := _game()
	if g == null:
		return
	var h: Dictionary = g.hero()
	var cls := str(h["cls"])
	var col := UI.class_color(cls)
	var R := Rect2(s.get_center().x + 10.0, s.position.y + 74.0, s.end.x - s.get_center().x - 20.0, s.size.y - 90.0)
	R.size.x = minf(R.size.x, 360.0)
	UI.panel(ci, R, Color(col, 0.55), Color(UI.PANEL, 0.9), 12.0)
	var fc := R.position + Vector2(40.0, 42.0)
	UI.portrait(ci, fc, 24.0, _face.get("tex"), col, 1.0, _face.get("uv", Rect2(0, 0, 1, 1)), cls.substr(0, 1).to_upper())
	UI.text(ci, Vector2(R.position.x + 74.0, R.position.y + 38.0), str(Classes.info(cls)["name"]), 20, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
	var xp: Dictionary = g.xp_progress()
	UI.text(ci, Vector2(R.position.x + 74.0, R.position.y + 56.0), "Level %d" % int(xp["level"]), 13, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	var bar := Rect2(R.position.x + 74.0, R.position.y + 62.0, R.size.x - 90.0, 4.0)
	ci.draw_rect(bar.grow(1.0), UI.INK)
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(xp["frac"]), bar.size.y)), UI.GOLD)
	var y := R.position.y + 98.0
	var belt: Array = g.belt()
	UI.text(ci, Vector2(R.position.x + 16.0, y), ("Belt · %d of %d" % [belt.size(), g.belt_slots()]).to_upper(), 10, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	y += 10.0
	if belt.is_empty():
		UI.text(ci, Vector2(R.position.x + 16.0, y + 22.0), "No relics yet. Gold reliquaries hold them;", 13, UI.MUTED)
		UI.text(ci, Vector2(R.position.x + 16.0, y + 40.0), "monsters drop them now and then.", 13, UI.MUTED)
	# This level so far: its sigils and the embers not yet banked.
	var bottom := R.end.y
	if world and world.get("sigils_got") is Array:
		bottom = R.end.y - 44.0
		ci.draw_line(Vector2(R.position.x + 16.0, bottom + 4.0), Vector2(R.end.x - 16.0, bottom + 4.0), Color(UI.PANEL_EDGE, 0.35), 1.0)
		UI.text(ci, Vector2(R.position.x + 16.0, bottom + 27.0), "THIS LEVEL", 10, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
		var full := UI.tex("res://art/props/sigil.svg")
		var empty := UI.tex("res://art/ui/sigil_empty.svg")
		for k in 3:
			var got: bool = world.sigils_got[k]
			var t: Texture2D = full if got else empty
			if t:
				ci.draw_texture_rect(t, Rect2(R.position.x + 90.0 + k * 22.0, bottom + 12.0, 20, 20), false)
		var carried := int(world.get("embers_carried"))
		UI.ember_icon(ci, Vector2(R.position.x + 176.0, bottom + 22.0), 8.0)
		UI.text(ci, Vector2(R.position.x + 188.0, bottom + 27.0), "%d carried" % carried, 13, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	# Up to three relics with their words; four or five a line each.
	var compact := belt.size() > 3
	var step := minf(34.0, (bottom - y - 8.0) / maxf(belt.size(), 1.0)) if compact else 34.0
	for i in belt.size():
		var r: Dictionary = Relics.get_relic(belt[i])
		var cy := y + 6.0 + i * step
		if cy + (step - 4.0 if compact else 30.0) > bottom:
			break
		var icon := UI.relic_icon(belt[i])
		var isz := minf(step - 4.0, 22.0) if compact else 28.0
		if icon:
			ci.draw_texture_rect(icon, Rect2(R.position.x + 16.0, cy, isz, isz), false)
		if compact:
			var nm := str(r["name"])
			UI.text(ci, Vector2(R.position.x + 46.0, cy + isz * 0.5 + 5.0), nm, 13, UI.rarity_color(r["rarity"]), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
			var nw := UI.text_width(nm, 13, "body", 700)
			var rest := R.size.x - 46.0 - nw - 26.0
			if rest > 60.0:
				UI.text(ci, Vector2(R.position.x + 56.0 + nw, cy + isz * 0.5 + 4.5), str(r["text"]), UI.fit_size(str(r["text"]), rest, 10, 8), Color(UI.CREAM, 0.7), HORIZONTAL_ALIGNMENT_LEFT, rest)
			continue
		UI.text(ci, Vector2(R.position.x + 52.0, cy + 13.0), r["name"], 14, UI.rarity_color(r["rarity"]), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
		UI.text(ci, Vector2(R.position.x + 52.0, cy + 27.0), r["text"], 11, Color(UI.CREAM, 0.8), HORIZONTAL_ALIGNMENT_LEFT, R.size.x - 64.0)
