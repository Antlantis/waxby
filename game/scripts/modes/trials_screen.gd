extends Control
## The Vigil Trials' screen (spec §7.6, p_modes §7.6): the callings as tabs
## (anyone may play any calling's trials: the loadout is fixed), the chosen
## calling's four cards (name, lesson, medal, best, the next target), a
## locked card saying what opens it, and Go for the card picked.

signal back

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/modes/mode_art.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const ModesSave := preload("res://scripts/modes/modes_save.gd")
const TrialData := preload("res://scripts/modes/trial_data.gd")
const Classes := preload("res://scripts/classes.gd")
const TRIALS := "res://scripts/modes/trials.gd"

var main: Node = null
var cls := "knight"
var picked := ""
var _t := 0.0
var _back_btn: Button
var _go_btn: Button
var _tabs := {}
var _tb := TriBatch.new()
var _faces := {}


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	Art.warm()
	var g := _game()
	if g != null and Classes.ALL.has(str(g.hero_id())):
		cls = str(g.hero_id())
	for c in Classes.ids():
		_faces[c] = UI.hero_face(c, "happy")
	_back_btn = UI.make_button("Back", false, func(): back.emit(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	add_child(_back_btn)
	for c in Classes.ids():
		var cc: String = c
		var b := UI.make_button(str(Classes.info(c)["name"]), false, func(): set_cls(cc), "select", 13)
		UI.small_button(b, 13)
		b.custom_minimum_size = Vector2(0, UI.TAP_H)
		add_child(b)
		_tabs[c] = b
	_go_btn = UI.make_button("Go", true, func(): go(), "", 20)
	_go_btn.custom_minimum_size = Vector2(150, 48)
	add_child(_go_btn)
	# Every open trial has been looked at once the screen is open (the hub's
	# "!" doesn't wait for each calling's tab).
	for id in TrialData.ORDER:
		if is_open(id):
			ModesSave.mark_seen(g, "trial:" + str(id), false)
	set_cls(cls)


func set_cls(c: String) -> void:
	cls = c
	picked = ""
	var ids: Array = TrialData.BY_CLS.get(cls, [])
	for id in ids:
		if is_open(id):
			picked = id
			break
	var g := _game()
	for id in ids:
		if is_open(id):
			ModesSave.mark_seen(g, "trial:" + str(id), false)
	if g != null:
		g.save()
	_refresh()


func is_open(id: String) -> bool:
	return TrialData.built(id) and ModesSave.trial_open(_game(), TrialData.number(id))


func _refresh() -> void:
	for c in _tabs:
		var b: Button = _tabs[c]
		var on: bool = c == cls
		b.add_theme_color_override("font_color", UI.class_color(c) if on else UI.CREAM)
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		sb.border_color = UI.class_color(c) if on else UI.PANEL_EDGE
		sb.bg_color = Color("2e2240") if on else Color("2a2038")
		b.add_theme_stylebox_override("normal", sb)
	_go_btn.disabled = picked == ""
	_layout()


func card_rects() -> Array:
	var s := UI.safe_rect(get_viewport())
	var w := minf((s.size.x - 3.0 * 12.0) / 4.0, 190.0)
	var h := minf(206.0, s.end.y - (s.position.y + 102.0) - 60.0)
	var x0 := s.get_center().x - (w * 4.0 + 36.0) * 0.5
	var out: Array = []
	for i in 4:
		out.append(Rect2(x0 + i * (w + 12.0), s.position.y + 100.0, w, h))
	return out


func _layout() -> void:
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)
	var ids: Array = Classes.ids()
	var w := (s.size.x - 8.0 * (ids.size() - 1)) / ids.size()
	for i in ids.size():
		var b: Button = _tabs[ids[i]]
		b.custom_minimum_size = Vector2(w, UI.TAP_H)
		b.reset_size()
		b.position = Vector2(s.position.x + i * (w + 8.0), s.position.y + 50.0)
	_go_btn.reset_size()
	_go_btn.position = Vector2(s.end.x - _go_btn.size.x, s.end.y - 50.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and _back_btn != null:
		_layout()


func _process(dt: float) -> void:
	_t += dt
	_layout()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not UI.is_tap(event):
		return
	var pos: Vector2 = (event as InputEventMouseButton).position
	var rs := card_rects()
	var ids: Array = TrialData.BY_CLS.get(cls, [])
	for i in rs.size():
		if (rs[i] as Rect2).has_point(pos) and i < ids.size():
			if is_open(ids[i]):
				if picked == ids[i]:
					go()
				else:
					picked = ids[i]
					var s := get_node_or_null("/root/Sfx")
					if s != null:
						s.play("select")
					_refresh()
			accept_event()
			return


func go() -> void:
	if picked == "":
		return
	load(TRIALS).play_trial(main, picked, 0)


static func _time(t: float) -> String:
	var cs := int(round(t * 100.0))
	return "%d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]


func _draw() -> void:
	UI.backdrop(self, get_size())
	var s := UI.safe_rect(get_viewport())
	var g := _game()
	UI.text(self, Vector2(s.position.x, s.position.y + 28.0), "The Vigil Trials", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 4)
	UI.text(self, Vector2(s.position.x, s.position.y + 45.0), "Mother Taper's lessons", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "italic", 500)
	var ids: Array = TrialData.BY_CLS.get(cls, [])
	var rs := card_rects()
	for i in mini(rs.size(), ids.size()):
		var id: String = ids[i]
		var r: Rect2 = rs[i]
		var t: Dictionary = TrialData.TRIALS[id]
		var open := is_open(id)
		var sel := id == picked
		UI.panel(self, r, UI.GOLD if sel else (UI.PANEL_EDGE if open else Color("3a3148")), Color("241a33") if open else Color("150f1f"), 12.0)
		var tag := "Master" if bool(t.get("master", false)) else "Trial %d" % int(t["n"])
		UI.text(self, r.position + Vector2(0, 20), tag, 11, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var nm := str(t["name"])
		UI.text(self, r.position + Vector2(0, 42), nm, UI.fit_size(nm, r.size.x - 14.0, 17, 12, "title", 700), UI.GOLD if open else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "title", 700)
		if not open:
			UI.glyph(self, "lock", r.position + Vector2(r.size.x * 0.5, r.size.y * 0.5), 26.0, Color(UI.MUTED, 0.7))
			var why := "Coming soon" if not TrialData.built(id) else ModesSave.trial_lock_text(int(t["n"]))
			var ls := UI.wrap(why, r.size.x - 16.0, 12)
			for k in mini(ls.size(), 2):
				UI.text(self, r.position + Vector2(0, r.size.y - 30.0 + k * 14.0), str(ls[k]), 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			continue
		var lesson := UI.wrap(str(t["lesson"]), r.size.x - 18.0, 12)
		for k in mini(lesson.size(), 3):
			UI.text(self, r.position + Vector2(9, 64 + k * 15), str(lesson[k]), 12, UI.CREAM)
		var rec: Dictionary = ModesSave.trial_rec(g, id) if g != null else {}
		var medal := int(rec.get("medal", 0))
		Art.medal(self, _tb, r.position + Vector2(r.size.x * 0.5, r.size.y - 74.0), 18.0, medal)
		var best := float(rec.get("best", 0.0))
		UI.text(self, r.position + Vector2(0, r.size.y - 36.0), "Best %s" % _time(best) if best > 0.0 else "Not yet walked", 12, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var nxt := medal + 1 if medal >= 1 else 2
		if nxt <= 4:
			var nt := TrialData.target(id, nxt)
			if nt > 0.0:
				UI.text(self, r.position + Vector2(0, r.size.y - 18.0), "%s %s" % [TrialData.MEDAL_NAME[nxt], _time(nt).trim_suffix(".00")], 12, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		else:
			UI.text(self, r.position + Vector2(0, r.size.y - 18.0), "Every medal", 12, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# Who the loadout is.
	if picked != "":
		var t2: Dictionary = TrialData.TRIALS[picked]
		var line := "%s · Level %d · fixed skills and gear" % [str(Classes.info(str(t2["cls"]))["name"]), int(t2["level"])]
		UI.text(self, Vector2(s.position.x, s.end.y - 20.0), line, 13, UI.MUTED)
	_tb.flush(self)
