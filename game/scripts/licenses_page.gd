extends Control
## Credits and licenses, from Settings (settings_page.gd's Licenses): who
## made Waxby, then what it is built on and the terms that come with it:
## the Godot Engine's MIT license (Engine.get_license_text()), every
## third-party component Godot carries with its copyright lines and license
## (Engine.get_copyright_info()), and each of those licenses in full
## (Engine.get_license_info()). Fonts are the phone's own (ui.gd), so none
## need a line here.
##
## One long list under Back and the title, scrolled with a thumb (a
## ScrollContainer, its bar on the right). It's about 80 KB of text, so the
## list is filled a few blocks a frame (PER_FRAME) rather than all in the
## frame it opens; `done` says when it is all there. Back (or Esc / Menu)
## says back().

signal back

const UI := preload("res://scripts/ui.gd")
const PER_FRAME := 12             # blocks added a frame while the list fills
const HEAD := 18                  # a section's title
const NAME := 14                  # a component's or a license's name
const BODY := 13                  # running text
const SMALL := 12                 # copyright lines and the license texts
const TOP := 50.0                 # the list starts this far under the safe area's top
const CREDITS := "A game by Anthony Craig. © 2026 Anthony Craig.\nMade with Claude. Every picture is drawn in code and every sound is synthesized.\nBuilt with the Godot Engine, under the MIT license below."

var done := false
var _back_btn: Button
var _scroll: ScrollContainer
var _list: VBoxContainer
var _todo: Array = []             # [kind, text] still to add


static func blocks() -> Array:
	## Everything the page says, in order, as [kind, text]: kind is "head"
	## (a section), "name" (a component or a license), "body" or "small".
	var out: Array = []
	out.append(["head", "Waxby"])
	out.append(["body", CREDITS])
	out.append(["head", "Godot Engine"])
	out.append(["body", Engine.get_license_text().strip_edges()])
	out.append(["head", "Third-party components in Godot"])
	out.append(["body", "The Godot Engine includes the components below, each under the license named. The licenses are given in full after them."])
	for c in Engine.get_copyright_info():
		var nm := str(c.get("name", ""))
		if nm == "" or nm == "Godot Engine":
			continue   # Godot's own notice is the section above
		out.append(["name", nm])
		out.append(["small", component_text(c)])
	out.append(["head", "License texts"])
	var li: Dictionary = Engine.get_license_info()
	var keys: Array = li.keys()
	keys.sort()
	for k in keys:
		out.append(["name", str(k)])
		out.append(["small", str(li[k]).strip_edges()])
	return out


static func component_text(c: Dictionary) -> String:
	## A component's copyright lines ("© 2011, Ole Kniemeyer, ..."), each
	## once, then "License: ..." (its parts' licenses, each once).
	var lines: Array = []
	var lic: Array = []
	for p in c.get("parts", []):
		if not (p is Dictionary):
			continue
		for cr in p.get("copyright", []):
			var l := "© %s" % str(cr)
			if not lines.has(l):
				lines.append(l)
		var ln := str(p.get("license", ""))
		if ln != "" and not lic.has(ln):
			lic.append(ln)
	if not lic.is_empty():
		lines.append("License: %s" % "; ".join(lic))
	return "\n".join(lines)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	name = "Licenses"
	UI.warm()
	_back_btn = UI.make_button("Back", false, func(): back.emit(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	_back_btn.name = "Back"
	add_child(_back_btn)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = false
	add_child(_scroll)
	_style_bar(_scroll.get_v_scroll_bar())
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	_todo = blocks()
	_layout()
	_fill(PER_FRAME)


func _style_bar(bar: VScrollBar) -> void:
	## A thin bar in the menus' colours, wide enough to drag with a thumb.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(UI.PANEL, 0.6)
	track.set_corner_radius_all(4)
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(UI.PANEL_EDGE, 0.9)
	grab.set_corner_radius_all(4)
	var lit := grab.duplicate()
	lit.bg_color = UI.MUTED
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", lit)
	bar.add_theme_stylebox_override("grabber_pressed", lit)
	bar.custom_minimum_size = Vector2(10, 0)


func _label(kind: String, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size: int = {"head": HEAD, "name": NAME, "body": BODY}.get(kind, SMALL)
	var col: Color = {"head": UI.GOLD, "name": UI.GOLD, "body": UI.CREAM}.get(kind, Color(UI.CREAM, 0.82))
	var font := UI.font("title", 700) if kind == "head" else UI.font("body", 700 if kind == "name" else 500)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.set_meta("kind", kind)
	return l


func _fill(n: int) -> void:
	## Adds up to n of the blocks still to come (a section's head with a
	## little room above it).
	while n > 0 and not _todo.is_empty():
		var b: Array = _todo.pop_front()
		if b[0] == "head" and _list.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 10)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_list.add_child(gap)
		_list.add_child(_label(str(b[0]), str(b[1])))
		n -= 1
	done = _todo.is_empty()


func fill_all() -> void:
	## Everything at once (tests, screenshots).
	_fill(1 << 30)


func labels() -> Array:
	## The page's text blocks, as added so far.
	return _list.get_children().filter(func(c): return c is Label)


func text() -> String:
	## All of the page's text added so far, one block a line.
	return "\n".join(labels().map(func(l): return (l as Label).text))


func scroll_rect() -> Rect2:
	## Where the list scrolls, in the safe area under Back and the title.
	var s := UI.safe_rect(get_viewport())
	return Rect2(s.position.x, s.position.y + TOP, s.size.x, s.size.y - TOP)


func scroll_by(dy: float) -> void:
	_scroll.scroll_vertical = int(_scroll.scroll_vertical + dy)


func _layout() -> void:
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)
	var r := scroll_rect()
	_scroll.position = r.position
	_scroll.size = r.size


func _process(_dt: float) -> void:
	if not done:
		_fill(PER_FRAME)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _back_btn != null:
		_layout()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		back.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
		scroll_by(80.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
		scroll_by(-80.0)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var vs := get_size()
	var s := UI.safe_rect(get_viewport())
	UI.backdrop(self, vs)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(UI.BG, 0.55))
	UI.text(self, Vector2(0, s.position.y + 30.0), "Credits & licenses", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 5)
