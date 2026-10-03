extends Control
## The Endless Descent's screen (spec §7.6, p_modes §9.3). Left: the records,
## the best depth cleared by each calling on each difficulty (its time under
## it; the calling being played lit gold; a leaf or thorn for a Gentle or
## Fierce run). Right: who's going down, the difficulty bells (the open
## ones; the story's own difficulty is never changed), where to start, what
## the run carries, and Descend, or Resume · Depth 7 with a two-tap End run.

signal back

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/modes/mode_art.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const ModesSave := preload("res://scripts/modes/modes_save.gd")
const Data := preload("res://scripts/modes/descent_data.gd")
const Classes := preload("res://scripts/classes.gd")
const DESCENT := "res://scripts/modes/descent.gd"
const DIFFS := ["dusk", "nightfall", "witching"]
const DIFF_NAME := {"dusk": "Dusk", "nightfall": "Nightfall", "witching": "Witching"}

var main: Node = null
var diff := "dusk"
var _t := 0.0
var _back_btn: Button
var _go_btn: Button
var _end_btn: Button
var _diff_btns := {}
var _end_armed := 0.0
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
	if g != null:
		diff = str(ModesSave.block(g)["descent"].get("diff", "dusk"))
		if not g.diff_open(diff):
			diff = "dusk"
	for cls in Classes.ids():
		_faces[cls] = UI.hero_face(cls, "happy")
	_back_btn = UI.make_button("Back", false, func(): back.emit(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	add_child(_back_btn)
	for d in DIFFS:
		var dd: String = d
		var b := UI.make_button(DIFF_NAME[d], false, func(): _set_diff(dd), "select", 14)
		UI.small_button(b, 14)
		b.custom_minimum_size = Vector2(0, UI.TAP_H)
		add_child(b)
		_diff_btns[d] = b
	_go_btn = UI.make_button("Descend", true, func(): _go(), "", 22)
	_go_btn.custom_minimum_size = Vector2(0, 52)
	add_child(_go_btn)
	_end_btn = UI.make_button("End run", false, func(): _end_run(), "click", 14)
	UI.small_button(_end_btn, 14)
	_end_btn.custom_minimum_size = Vector2(0, UI.TAP_H)
	add_child(_end_btn)
	_refresh()


func _cls() -> String:
	var g := _game()
	return str(g.hero_id()) if g != null else "knight"


func suspended() -> Dictionary:
	var g := _game()
	if g == null:
		return {}
	return (ModesSave.block(g)["descent"]["runs"] as Dictionary).get(_cls(), {})


func _set_diff(d: String) -> void:
	var g := _game()
	if g != null and not g.diff_open(d):
		return
	if not suspended().is_empty():
		return   # a suspended run keeps its own difficulty
	diff = d
	if g != null:
		ModesSave.block(g)["descent"]["diff"] = d
	_refresh()


func _refresh() -> void:
	var run := suspended()
	var g := _game()
	for d in DIFFS:
		var b: Button = _diff_btns[d]
		var is_open: bool = g == null or bool(g.diff_open(d))
		b.visible = is_open
		var on: bool = (str(run.get("diff", diff)) if not run.is_empty() else diff) == d
		b.add_theme_color_override("font_color", UI.GOLD if on else UI.CREAM)
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		sb.border_color = UI.GOLD if on else UI.PANEL_EDGE
		sb.bg_color = Color("3a2a1a") if on else Color("2a2038")
		b.add_theme_stylebox_override("normal", sb)
	if run.is_empty():
		_go_btn.text = "Descend"
		_end_btn.visible = false
	else:
		_go_btn.text = "Resume · Depth %d" % int(run.get("depth", 1))
		_end_btn.visible = true
		_end_btn.text = "Tap again to end" if _end_armed > 0.0 else "End run"
	_layout()


func left_rect() -> Rect2:
	var s := UI.safe_rect(get_viewport())
	return Rect2(s.position.x, s.position.y + 52.0, s.size.x * 0.54 - 8.0, s.size.y - 58.0)


func right_rect() -> Rect2:
	var s := UI.safe_rect(get_viewport())
	var l := left_rect()
	return Rect2(l.end.x + 16.0, l.position.y, s.end.x - l.end.x - 16.0, l.size.y)


func _layout() -> void:
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)
	var r := right_rect()
	var x := r.position.x + 12.0
	var shown: Array = DIFFS.filter(func(d): return (_diff_btns[d] as Button).visible)
	var w := (r.size.x - 24.0 - 8.0 * (shown.size() - 1)) / maxf(shown.size(), 1)
	for d in shown:
		var b: Button = _diff_btns[d]
		b.custom_minimum_size = Vector2(w, UI.TAP_H)
		b.reset_size()
		b.position = Vector2(x, r.position.y + 70.0)
		x += w + 8.0
	_go_btn.custom_minimum_size = Vector2(r.size.x - 24.0, 52)
	_go_btn.reset_size()
	_go_btn.position = Vector2(r.position.x + 12.0, r.end.y - 58.0 - (48.0 if _end_btn.visible else 0.0))
	_end_btn.custom_minimum_size = Vector2(r.size.x - 24.0, UI.TAP_H)
	_end_btn.reset_size()
	_end_btn.position = Vector2(r.position.x + 12.0, r.end.y - 50.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and _back_btn != null:
		_layout()


func _process(dt: float) -> void:
	_t += dt
	if _end_armed > 0.0:
		_end_armed -= dt
		if _end_armed <= 0.0:
			_refresh()
	_layout()
	queue_redraw()


func _go() -> void:
	var D = load(DESCENT)
	var g := _game()
	var strength := str(g.setting("candle_strength")) if g != null else "normal"
	if not suspended().is_empty():
		D.resume(main, _cls())
	else:
		D.start(main, _cls(), diff, strength, 1)


func _end_run() -> void:
	if _end_armed <= 0.0:
		_end_armed = 2.0
		_refresh()
		return
	_end_armed = 0.0
	load(DESCENT).end_suspended(_cls())
	_refresh()


func _draw() -> void:
	UI.backdrop(self, get_size())
	var s := UI.safe_rect(get_viewport())
	var g := _game()
	UI.text(self, Vector2(s.position.x, s.position.y + 28.0), "Endless Descent", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 4)
	UI.text(self, Vector2(s.position.x, s.position.y + 45.0), "The Hush dreams", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "italic", 500)
	# Records.
	var l := left_rect()
	UI.panel(self, l, UI.PANEL_EDGE, Color(UI.PANEL, 0.92), 12.0)
	UI.text(self, l.position + Vector2(14, 24), "Deepest cleared", 15, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
	var col0 := l.position.x + l.size.x * 0.42
	var colw := (l.end.x - 10.0 - col0) / 3.0
	for i in DIFFS.size():
		var cx := col0 + colw * (i + 0.5)
		Art.bell(_tb, Vector2(cx, l.position.y + 44.0), 16.0, Color(UI.GOLD, 0.8))
		UI.text(self, Vector2(cx - colw * 0.5, l.position.y + 64.0), DIFF_NAME[DIFFS[i]], 11, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, colw)
	var rows: Array = Classes.ids()
	var rh := minf((l.size.y - 78.0) / rows.size(), 40.0)
	for k in rows.size():
		var cls: String = rows[k]
		var y := l.position.y + 74.0 + k * rh
		var cur := cls == _cls()
		if cur:
			draw_rect(Rect2(l.position.x + 6.0, y, l.size.x - 12.0, rh - 2.0), Color(UI.GOLD, 0.10))
		var face: Dictionary = _faces[cls]
		UI.portrait(self, Vector2(l.position.x + 26.0, y + rh * 0.5), 13.0, face.get("tex"), UI.class_color(cls), 1.0, face.get("uv", Rect2(0, 0, 1, 1)))
		var name := str(Classes.info(cls)["name"])
		UI.text(self, Vector2(l.position.x + 46.0, y + rh * 0.5 + 5.0), name, UI.fit_size(name, col0 - l.position.x - 50.0, 14, 10), UI.GOLD if cur else UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
		for i in DIFFS.size():
			var rec := ModesSave.descent_best(g, cls, DIFFS[i]) if g != null else {}
			var cx := col0 + colw * (i + 0.5)
			if rec.is_empty():
				UI.text(self, Vector2(cx - colw * 0.5, y + rh * 0.5 + 5.0), "·", 16, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, colw)
				continue
			UI.text(self, Vector2(cx - colw * 0.5, y + rh * 0.5 + 3.0), str(int(rec["depth"])), 20, UI.GOLD if cur else UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, colw, "body", 700)
			var t := float(rec.get("time", 0.0))
			UI.text(self, Vector2(cx - colw * 0.5, y + rh * 0.5 + 15.0), "%d:%02d" % [int(t) / 60, int(t) % 60], 10, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, colw)
			var st := str(rec.get("strength", "normal"))
			if st != "normal":
				UI.glyph(self, "drop" if st == "gentle" else "star", Vector2(cx + 16.0, y + rh * 0.5 - 6.0), 9.0, UI.GOOD if st == "gentle" else UI.BAD)
	# The run to come.
	var r := right_rect()
	UI.panel(self, r, UI.PANEL_EDGE, Color(UI.PANEL, 0.92), 12.0)
	var cls := _cls()
	var face2: Dictionary = _faces.get(cls, {})
	UI.portrait(self, r.position + Vector2(30, 32), 17.0, face2.get("tex"), UI.class_color(cls), 1.0, face2.get("uv", Rect2(0, 0, 1, 1)))
	var lvl := int(g.hero().get("level", 1)) if g != null else 1
	UI.text(self, r.position + Vector2(56, 30), str(Classes.info(cls)["name"]), 17, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
	UI.text(self, r.position + Vector2(56, 48), "Level %d" % lvl, 13, UI.CREAM)
	var run := suspended()
	var d := str(run.get("diff", diff)) if not run.is_empty() else diff
	var line1 := ""
	var line2 := ""
	if run.is_empty():
		line1 = "Start at: Depth 1 · area %d" % Data.area_at(1, _a_end(d))
		line2 = "Spare Wicks %d · Glimmers 0 · Hushings from depth %d" % [int(Data.SPARE.get(d, 0)), Data.HUSH_FROM]
	else:
		var gl := 0
		for k in run.get("glimmers", {}):
			gl += int(run["glimmers"][k])
		var hs := 0
		for k in run.get("hushings", {}):
			hs += int(run["hushings"][k])
		line1 = "Waiting at the landing of depth %d · %s" % [int(run.get("depth", 1)), DIFF_NAME.get(str(run.get("diff", "dusk")), "")]
		line2 = "Spare Wicks %d · Glimmers %d · Hushings %d" % [int(run.get("spare", 0)), gl, hs]
	UI.text(self, r.position + Vector2(14, 136), line1, UI.fit_size(line1, r.size.x - 28.0, 14, 10), UI.CREAM)
	UI.text(self, r.position + Vector2(14, 158), line2, UI.fit_size(line2, r.size.x - 28.0, 13, 10), UI.MUTED)
	_tb.flush(self)


static func _a_end(d: String) -> int:
	var m = load("res://scripts/modes/mode.gd")
	return int(m.a_end(d))
