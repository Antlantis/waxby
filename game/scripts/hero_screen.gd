extends Control
## The Sheet: the hero's numbers, skill tree, gear and relic belt, one tab
## each (stats_panel, skills_panel, gear_panel, belt_panel). From the map
## everything is editable; from pause the belt is only while Waxby stands by
## a lit altar (belt_editable). Emits changed whenever the hero changes (so
## a level in progress can re-apply the hero) and back when closed.
## v3: a fifth tab, Look (the modes' look_panel.gd: flames and trims), shows
## once that panel is in the build. At level 30, with one capstone owned, the
## Skills tab plays the bark second_capstone over the Sheet, once a save.

signal back
signal changed

const UI := preload("res://scripts/ui.gd")
const Classes := preload("res://scripts/classes.gd")
const TABS := ["stats", "skills", "gear", "belt", "look"]
const BAR_H := 46.0               # the top bar: Back, the name plate, the tabs
const TAB_NAME := {"stats": "Stats", "skills": "Skills", "gear": "Gear", "belt": "Belt", "look": "Look"}
const PANEL_PATH := {"stats": "res://scripts/stats_panel.gd", "skills": "res://scripts/skills_panel.gd",
		"gear": "res://scripts/gear_panel.gd", "belt": "res://scripts/belt_panel.gd",
		"look": "res://scripts/modes/look_panel.gd"}

const BARK_KEY := "second_capstone"
const BARK_TIME := 6.0            # the bark over the Sheet: in, held, out (a tap on it ends it)
# Spec §6.5's words, while story.gd has no second_capstone (ST's line wins).
const BARK_FALLBACK := {"who": "hollin", "mood": "relit", "text": "Two flames on one wick! Mother never managed that. Don't tell her."}

var tab := "stats"
var belt_editable := true
var over_level := false           # drawn over a paused level: a darker, see-through backdrop
var panel: Control                # the open tab's panel
var _tabs := {}                   # name -> Button
var _back_btn: Button
var _t := 0.0
var _bark := {}                   # {who, name, text, col, tex, letter, t}
var _bark_layer: Control          # over the panels: the bark draws here


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	_back_btn = UI.make_button("Back", false, func(): back.emit(), "back", 16)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	add_child(_back_btn)
	for name in tabs():
		var b := UI.make_button(TAB_NAME[name], false, func(): open_tab(name), "click", 15)
		UI.small_button(b, 15)
		b.custom_minimum_size = Vector2(78, UI.TAP_H)
		b.toggle_mode = true
		add_child(b)
		_tabs[name] = b
	_bark_layer = Control.new()
	_bark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bark_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bark_layer.draw.connect(func(): _draw_bark(_bark_layer))
	add_child(_bark_layer)
	open_tab(tab)


static func tabs() -> Array:
	## The tabs whose panels are in this build (Look waits for the modes).
	return TABS.filter(func(t): return ResourceLoader.exists(PANEL_PATH[t]))


func open_tab(name: String) -> void:
	tab = name if tabs().has(name) else "stats"
	if panel:
		panel.queue_free()
	var script = load(PANEL_PATH[tab])
	panel = script.new()
	panel.set("host", self)
	panel.name = tab.capitalize()
	add_child(panel)
	move_child(panel, 0)
	_layout()
	_refresh_tabs()
	if tab == "skills":
		_capstone_bark()


# ---------------------------------------------------------------- the two-capstone bark

func capstone_bark_due() -> bool:
	## Spec §2.1: the deep tree is on, the hero is level 30 or more and owns
	## exactly one capstone (so the other is his to buy), and the bark
	## hasn't played (on this Sheet or in a level).
	if panel == null or not panel.has_method("deep") or not panel.deep():
		return false
	var h := _hero()
	if int(h.get("level", 1)) < Classes.SECOND_CAPSTONE:
		return false
	var owned := 0
	var sk: Dictionary = h.get("skills", {})
	for n in Classes.tree(str(h.get("cls", "knight"))):
		if int(n["tier"]) == 3 and int(sk.get(n["id"], 0)) > 0:
			owned += 1
	if owned != 1:
		return false
	var g := get_node_or_null("/root/Game")
	if g == null or (g.data.get("notices", []) as Array).has(BARK_KEY):
		return false
	var st = _story()
	return not (st != null and st.has_method("bark_heard") and st.bark_heard(BARK_KEY))


func _capstone_bark() -> void:
	if not capstone_bark_due():
		return
	var g := get_node_or_null("/root/Game")
	if not g.notice(BARK_KEY):
		return
	var cls := str(_hero().get("cls", "knight"))
	var line: Dictionary = {}
	var st = _story()
	if st != null and st.has_method("bark_line"):
		line = st.bark_line(BARK_KEY, cls)
		if st.has_method("bark_once"):
			st.bark_once(BARK_KEY)   # heard: a level won't play it again
	if line.is_empty() or str(line.get("text", "")) == "":
		line = BARK_FALLBACK.duplicate()
	var who := str(line.get("who", "hollin"))
	var name := who.capitalize()
	var col := UI.speaker_color(who, cls)
	if st != null and st.has_method("speaker"):
		var sp = st.speaker(who, cls)
		if sp is Dictionary:
			name = str(sp.get("name", name))
			if sp.get("color") is Color:
				col = sp["color"]
	# The face: the line's mood, else any of the speaker's moods drawn.
	var moods: Array = [str(line.get("mood", ""))]
	var consts: Dictionary = st.get_script_constant_map() if st is Script else {}
	if consts.get("MOODS") is Dictionary:
		moods += (consts["MOODS"].get(who, []) as Array).duplicate()
	moods.append("normal")
	var tex: Texture2D = null
	for mood in moods:
		if tex == null and str(mood) != "":
			var p := UI.portrait_path(who, str(mood), cls)
			if p != "" and ResourceLoader.exists(p):
				tex = UI.tex(UI.hud_face(p))   # (drawn at radius 18: the 128 px copy)
	_bark = {"who": who, "name": name, "text": str(line["text"]), "col": col, "tex": tex, "letter": name.substr(0, 1), "t": 0.0}


func bark_showing() -> bool:
	return not _bark.is_empty()


func bark_text() -> String:
	return str(_bark.get("text", ""))


func bark_rect() -> Rect2:
	## At the top of the skill tree (over the root and Tier 1, long owned by
	## level 30), clear of the capstones, the deep rows and the card's buttons.
	var area := content_rect()
	if panel != null and panel.has_method("tree_rect"):
		var t: Rect2 = panel.tree_rect()
		area = Rect2(panel.position + t.position, t.size)
	var w := minf(area.size.x - 20.0, 470.0)
	var lines := UI.wrap_lines(str(_bark.get("text", "")), w - 76.0, 14)
	var h := 34.0 + mini(lines.size(), 2) * 18.0
	return Rect2(area.get_center().x - w * 0.5, area.position.y + 8.0, w, h)


func _bark_alpha() -> float:
	if _bark.is_empty():
		return 0.0
	var t := float(_bark["t"])
	return clampf(t * 4.0, 0.0, 1.0) * clampf((BARK_TIME - t) * 2.0, 0.0, 1.0)


func _draw_bark(ci: Control) -> void:
	var a := _bark_alpha()
	if a <= 0.0:
		return
	var r := bark_rect()
	var col: Color = _bark["col"]
	UI.panel(ci, r, Color(col, 0.85 * a), Color(UI.PANEL, 0.96 * a), 12.0)
	var pc := Vector2(r.position.x + 30.0, r.get_center().y)
	UI.portrait(ci, pc, 18.0, _bark["tex"], col, a, Rect2(0, 0, 1, 1), str(_bark["letter"]))
	var x := r.position.x + 60.0
	var w := r.size.x - 76.0
	UI.text(ci, Vector2(x, r.position.y + 19.0), str(_bark["name"]).to_upper(), 10, Color(col, a), HORIZONTAL_ALIGNMENT_LEFT, w, "body", 800)
	var lines := UI.wrap_lines(str(_bark["text"]), w, 14)
	for i in mini(lines.size(), 2):
		UI.text(ci, Vector2(x, r.position.y + 38.0 + i * 18.0), lines[i], 14, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, w)


func _story():
	return load("res://scripts/story.gd") if ResourceLoader.exists("res://scripts/story.gd") else null


func _input(event: InputEvent) -> void:
	# A tap on the bark ends it (and goes no further).
	if not _bark.is_empty() and UI.is_tap(event) and bark_rect().has_point(event.position):
		_bark["t"] = maxf(float(_bark["t"]), BARK_TIME - 0.5)
		get_viewport().set_input_as_handled()


func notify_changed() -> void:
	## A panel changed the hero: tell the host, refresh the tab labels.
	changed.emit()
	_refresh_tabs()


func _refresh_tabs() -> void:
	var pts := int(_hero().get("points", 0))
	for name in _tabs:
		var b: Button = _tabs[name]
		b.button_pressed = name == tab
		b.text = TAB_NAME[name] + ("  +%d" % pts if name == "skills" and pts > 0 else "")
		var col := UI.GOLD if name == tab or (name == "skills" and pts > 0) else UI.CREAM
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_pressed_color", UI.GOLD)
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		sb.border_color = UI.GOLD if name == tab else UI.PANEL_EDGE
		sb.bg_color = Color("3a2a1a") if name == tab else Color("2a2038")
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("pressed", sb)


func _hero() -> Dictionary:
	var g := get_node_or_null("/root/Game")
	return g.hero() if g else {}


func content_rect() -> Rect2:
	## Where the open panel goes: the safe area under the top bar.
	var s := UI.safe_rect(get_viewport())
	return Rect2(s.position.x, s.position.y + BAR_H + 4.0, s.size.x, s.size.y - BAR_H - 4.0)


func _layout() -> void:
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)
	var x := s.end.x
	var T := tabs()
	for i in range(T.size() - 1, -1, -1):
		var b: Button = _tabs[T[i]]
		b.reset_size()
		x -= b.size.x
		b.position = Vector2(x, s.position.y + 2)
		x -= 6.0
	if panel:
		var c := content_rect()
		panel.position = c.position
		panel.size = c.size


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and _back_btn != null:
		_layout()


func _process(dt: float) -> void:
	_t += dt
	_layout()
	if not _bark.is_empty():
		_bark["t"] = float(_bark["t"]) + dt
		if float(_bark["t"]) > BARK_TIME:
			_bark = {}
		_bark_layer.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var vs := get_size()
	if over_level:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.93))
	else:
		UI.backdrop(self, vs)
	var s := UI.safe_rect(get_viewport())
	var h := _hero()
	var cls := str(h.get("cls", "knight"))
	# The hero's name plate between Back and the tabs, shrunk to fit.
	var P := plate_rect()
	var x := P.position.x
	var col := UI.class_color(cls)
	var cy := s.position.y + 2.0 + UI.TAP_H * 0.5
	draw_circle(Vector2(x + 8.0, cy), 6.0, col)
	draw_arc(Vector2(x + 8.0, cy), 8.0, 0, TAU, 20, Color(UI.INK, 0.9), 2.0)
	var name := str(Classes.info(cls)["name"])
	var lvl := "Level %d" % int(h.get("level", 1))
	var room := P.size.x - 30.0 - UI.text_width(lvl, 15, "body", 700)
	var size := UI.fit_size(name, room, 21, 13, "title", 700)
	UI.text(self, Vector2(x + 22.0, cy + 7.0), name, size, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 4)
	var nw := UI.text_width(name, size, "title", 700)
	UI.text(self, Vector2(x + 30.0 + nw, cy + 6.0), lvl, 15, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	draw_line(Vector2(s.position.x, s.position.y + BAR_H), Vector2(s.end.x, s.position.y + BAR_H), Color(UI.PANEL_EDGE, 0.5), 1.0)


func plate_rect() -> Rect2:
	## The name plate's room: from Back to the first tab.
	var s := UI.safe_rect(get_viewport())
	var x0 := _back_btn.position.x + _back_btn.size.x + 12.0
	var first: Button = _tabs[tabs()[0]]
	return Rect2(x0, s.position.y + 4.0, maxf(first.position.x - 10.0 - x0, 40.0), UI.TAP_H - 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		back.emit()
		get_viewport().set_input_as_handled()
