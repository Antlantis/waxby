extends Control
## The hero's name, asked for: the oath's choose_name cue (cutscene.gd) and
## the Sheet's Rename (hero_screen.gd). A panel high on the screen with a
## field holding the name to start from (Waxby at the oath), Confirm and,
## where the asking can be put off, Cancel. On a phone the system keyboard
## comes up with the field (the LineEdit's own, and DisplayServer's
## virtual_keyboard_show besides), and the panel keeps clear of it: the
## 844 x 390 landscape gives the keyboard the bottom half or more, so the
## panel sits in the top third, and rises when a keyboard reaches it.
##
## While it's typed the field keeps only what a name may hold
## (Story.name_typed); what it hands back is Story.clean_name's: up to
## NAME_MAX letters, spaces, apostrophes and hyphens, trimmed, and Waxby when
## nothing fit to keep is left. Enter (the keyboard's Return) confirms;
## Escape cancels, where it can.

signal named(name: String)
signal cancelled

const UI := preload("res://scripts/ui.gd")
const Story := preload("res://scripts/story.gd")
const PROMPT := "Your name"
const HINT := "Up to %d letters, spaces, apostrophes or hyphens."
const PANEL_W := 520.0
const PANEL_H := 124.0
const TOP := 34.0              # the panel's top under the safe top: under a scene's letterbox (28)
const PAD := 16.0
const FIELD_Y := 40.0          # the field's row in the panel
const FIELD_H := 44.0          # (a thumb tall: UI.TAP_H and more)
const KEY_GAP := 8.0           # the panel's bottom to the keyboard's top, at least

var prompt := PROMPT
var start := Story.HERO_NAME   # what the field holds at first
var can_cancel := false
var accent: Color = UI.GOLD    # the panel's edge and the field's, while it's typed in
var dim := 0.6                 # the screen under it (a scene keeps its picture brighter)
var keyboard_override := -1.0  # tests: the keyboard's height in view units (else the system's)

var field: LineEdit
var confirm_btn: Button
var cancel_btn: Button
var _t := 0.0
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # nothing under it takes a tap meanwhile
	field = LineEdit.new()
	field.name = "Field"
	field.text = Story.name_typed(start).strip_edges()
	field.max_length = Story.NAME_MAX
	field.placeholder_text = Story.HERO_NAME
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.context_menu_enabled = false
	field.emoji_menu_enabled = false
	field.virtual_keyboard_enabled = true
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	field.select_all_on_focus = true   # typing replaces the name it starts with
	_style_field()
	field.text_changed.connect(_on_text)
	field.text_submitted.connect(func(_s): confirm())
	add_child(field)
	confirm_btn = UI.make_button("Confirm", true, confirm, "select", 16)
	UI.small_button(confirm_btn, 16)
	confirm_btn.custom_minimum_size = Vector2(100, FIELD_H)
	add_child(confirm_btn)
	if can_cancel:
		cancel_btn = UI.make_button("Cancel", false, cancel, "back", 16)
		UI.small_button(cancel_btn, 16)
		cancel_btn.custom_minimum_size = Vector2(92, FIELD_H)
		add_child(cancel_btn)
	_layout()
	open_keyboard.call_deferred()


func _style_field() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.INK
	sb.border_color = UI.PANEL_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	var focus := sb.duplicate()
	focus.border_color = accent
	field.add_theme_stylebox_override("normal", sb)
	field.add_theme_stylebox_override("focus", focus)
	field.add_theme_stylebox_override("read_only", sb)
	field.add_theme_font_override("font", UI.font("title", 700))
	field.add_theme_font_size_override("font_size", 22)
	field.add_theme_color_override("font_color", UI.CREAM)
	field.add_theme_color_override("font_selected_color", UI.CREAM)
	field.add_theme_color_override("font_placeholder_color", Color(UI.MUTED, 0.55))
	field.add_theme_color_override("caret_color", UI.GOLD)
	field.add_theme_color_override("selection_color", Color(UI.GOLD, 0.35))


func open_keyboard() -> void:
	## The field takes the keys, its name selected (typing replaces it); on a
	## phone the system keyboard comes up.
	if field == null or not field.is_inside_tree() or _done:
		return
	field.grab_focus()
	field.edit()
	field.select_all()
	_show_keyboard(0, field.text.length())


func _show_keyboard(from: int, to: int) -> void:
	## The phone's keyboard, holding what the field holds (the LineEdit asks
	## for it too as it starts editing; asked again, it only takes the text).
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and field.virtual_keyboard_enabled:
		DisplayServer.virtual_keyboard_show(field.text, field.get_global_rect(), DisplayServer.KEYBOARD_TYPE_DEFAULT,
				Story.NAME_MAX, from, to)


func _close_keyboard() -> void:
	if field != null and field.is_inside_tree():
		field.unedit()
		field.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


func _exit_tree() -> void:
	# Freed while it's up (the scene skipped, the Sheet closed): the
	# keyboard goes with it.
	if not _done:
		_done = true
		_close_keyboard()


func _on_text(t: String) -> void:
	## Only what a name may hold stays in the field (a digit or an emoji
	## typed just doesn't land); the phone's keyboard is told what's there.
	var kept := Story.name_typed(t)
	if kept == t:
		return
	var caret := clampi(field.caret_column - (t.length() - kept.length()), 0, kept.length())
	field.text = kept
	field.caret_column = caret
	_show_keyboard(caret, caret)


func typed() -> String:
	## What the field holds now.
	return field.text if field != null else start


func confirm() -> void:
	## The name is given: Story.clean_name's of what's typed.
	if _done:
		return
	_done = true
	var n := Story.clean_name(typed())
	_close_keyboard()
	named.emit(n)


func cancel() -> void:
	## Put off (the Sheet's Rename): the name stays as it was.
	if _done or not can_cancel:
		return
	_done = true
	_close_keyboard()
	cancelled.emit()


# ---------------------------------------------------------------- layout

func keyboard_height() -> float:
	## The system keyboard's height in view units (0 with none up).
	if keyboard_override >= 0.0:
		return keyboard_override
	if not is_inside_tree() or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0.0
	var px := float(DisplayServer.virtual_keyboard_get_height())
	var win := Vector2(DisplayServer.window_get_size())
	if px <= 0.0 or win.y <= 0.0:
		return 0.0
	return px * get_viewport().get_visible_rect().size.y / win.y


func panel_rect() -> Rect2:
	## Centred in the top third; with a keyboard up, wholly above it (never
	## off the top of the screen).
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(844, 390)
	var s := UI.safe_rect(get_viewport()) if is_inside_tree() else Rect2(14, 10, 816, 362)
	var w := minf(s.size.x - 24.0, PANEL_W)
	var top := s.position.y + TOP
	var kb := keyboard_height()
	if kb > 0.0:
		top = minf(top, vs.y - kb - KEY_GAP - PANEL_H)
	top = maxf(top, 2.0)
	return Rect2(s.get_center().x - w * 0.5, top, w, PANEL_H)


func field_rect() -> Rect2:
	var P := panel_rect()
	var right := P.end.x - PAD - confirm_btn.size.x - PAD
	if cancel_btn != null:
		right -= cancel_btn.size.x + 10.0
	return Rect2(P.position.x + PAD, P.position.y + FIELD_Y, right - P.position.x - PAD, FIELD_H)


func _layout() -> void:
	if field == null:
		return
	confirm_btn.reset_size()
	if cancel_btn != null:
		cancel_btn.reset_size()
	var F := field_rect()
	field.position = F.position
	field.size = F.size
	var x := F.end.x + PAD
	if cancel_btn != null:
		cancel_btn.position = Vector2(x, F.position.y + (FIELD_H - cancel_btn.size.y) * 0.5)
		x += cancel_btn.size.x + 10.0
	confirm_btn.position = Vector2(x, F.position.y + (FIELD_H - confirm_btn.size.y) * 0.5)


func _process(dt: float) -> void:
	_t += dt
	_layout()   # (the keyboard slides in over a few frames)
	queue_redraw()


func _draw() -> void:
	var vs := get_size()
	var a := clampf(_t / 0.2, 0.0, 1.0)
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.04, dim * a))
	var P := panel_rect()
	UI.panel(self, P, Color(accent, 0.85), Color(UI.PANEL, 0.97), 14.0)
	var tw := P.size.x - PAD * 2.0
	UI.text(self, Vector2(P.position.x, P.position.y + 28.0), prompt, UI.fit_size(prompt, tw, 20, 14, "title", 700), UI.GOLD,
			HORIZONTAL_ALIGNMENT_CENTER, P.size.x, "title", 700, 4)
	var hint := HINT % Story.NAME_MAX
	UI.text(self, Vector2(P.position.x, P.end.y - 13.0), hint, UI.fit_size(hint, tw, 11, 9, "body", 700), UI.MUTED,
			HORIZONTAL_ALIGNMENT_CENTER, P.size.x, "body", 700)


func _input(event: InputEvent) -> void:
	# Escape, before the field sees it (it would only stop editing): Cancel
	# where there is one; at the oath, nothing (the field keeps the keys).
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if can_cancel:
			cancel()
		get_viewport().set_input_as_handled()
