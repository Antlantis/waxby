extends Control
## "Choose your Calling": five alcoves side by side, each with a live rig of
## that calling standing in its candlelight. A calling not yet enabled is a
## sealed alcove. Tapping one opens its card (face, name, role, how easy it
## is, its Special and quirk) with a Choose button.
##
## On its own (the map's Callings button) Choose says picked(id), then makes
## or switches to that calling's hero through Game.new_hero() (after the
## signal, so a listener can still tell a new calling from an old one).
## Embedded (W4's oath scene sets embedded, or in_story, to true) it has no
## Back, no backdrop of its own (the scene's plinths show through a dim) and
## only emits picked(id): the host makes the hero. The three flags under
## embedded can still be set one by one. hovered(id) fires when a card opens.

signal hovered(id: String)
signal picked(id: String)
signal back

const UI := preload("res://scripts/ui.gd")
const Classes := preload("res://scripts/classes.gd")
const GlowScript := preload("res://scripts/glow.gd")
# What a calling's ease pips mean, by how many are lit (the oath's chooser
# says the same words).
const EASE_WORDS := ["", "for the bold", "a challenge", "steady", "forgiving", "the gentlest start"]

var standalone := true
var show_back := true
var show_backdrop := true         # false: only a dim over whatever is behind
var embedded := false:            # hosted by a story scene: all three of the above off
	set(v):
		embedded = v
		if v:
			standalone = false
			show_back = false
			show_backdrop = false
var in_story := false:            # the same as embedded (W4 sets whichever it finds)
	set(v):
		in_story = v
		if v:
			embedded = true
var title := "Choose your Calling"
var focus := 0                    # the alcove the keys move between
var open_id := ""                 # the calling whose card is open
var _rigs := {}                   # cls -> {holder, rig}
var _glow: Node2D
var _overlay: Control
var _back_btn: Button
var _choose_btn: Button
var _close_btn: Button
var _faces := {}
var _t := 0.0
var _open_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	var ids := Classes.ids()
	var cur := _current()
	for i in ids.size():
		var cls: String = ids[i]
		_faces[cls] = UI.hero_face(cls, "happy")
		if cls == cur:
			focus = i
		if not bool(Classes.info(cls)["enabled"]):
			continue
		var holder := Node2D.new()
		holder.name = "Alcove_" + cls
		add_child(holder)
		var fake = preload("res://scripts/player.gd").new()
		fake.on_floor = true
		fake.hurt_time = 10.0
		fake.facing = 1 if i < ids.size() / 2 else -1
		var rig = preload("res://scripts/wick_rig.gd").new()
		rig.cls = cls
		rig.player = fake
		holder.add_child(fake)
		holder.add_child(rig)
		holder.scale = Vector2(1.55, 1.55)
		_rigs[cls] = {"holder": holder, "rig": rig, "player": fake}
	_glow = GlowScript.new()
	add_child(_glow)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_card)
	add_child(_overlay)
	_back_btn = UI.make_button("Back", false, func(): back.emit(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	_back_btn.visible = show_back
	add_child(_back_btn)
	_choose_btn = UI.make_button("Choose", true, func(): choose(open_id), "", 18)
	_choose_btn.custom_minimum_size = Vector2(140, 44)
	_close_btn = UI.make_button("Back", false, func(): close_card(), "back", 15)
	_close_btn.custom_minimum_size = Vector2(90, 40)
	for b in [_choose_btn, _close_btn]:
		b.visible = false
		add_child(b)


func _current() -> String:
	## The calling being played, or "" before any hero is made.
	var g := get_node_or_null("/root/Game")
	if g and g.has_hero(g.hero_id()):
		return g.hero_id()
	return ""


func alcove_rects() -> Array:
	## One rect per calling, left to right, inside the safe area.
	var s := UI.safe_rect(get_viewport())
	var n := Classes.ids().size()
	var gap := 12.0
	var w := minf((s.size.x - gap * (n - 1)) / n, 134.0)
	var x0 := s.get_center().x - (n * w + (n - 1) * gap) * 0.5
	var top := s.position.y + 70.0
	var bottom := s.end.y - 62.0
	var out: Array = []
	for i in n:
		out.append(Rect2(x0 + i * (w + gap), top, w, bottom - top))
	return out


func card_rect() -> Rect2:
	var s := UI.safe_rect(get_viewport())
	var w := minf(560.0, s.size.x - 20.0)
	var h := minf(282.0, s.size.y - 24.0)
	return Rect2(s.get_center().x - w * 0.5, s.get_center().y - h * 0.5 + 6.0, w, h)


static func ease_word(ease: int) -> String:
	## "the gentlest start" for five lit pips ... "for the bold" for one.
	return EASE_WORDS[clampi(ease, 0, EASE_WORDS.size() - 1)]


func open_card(id: String) -> void:
	if not Classes.ALL.has(id):
		return
	open_id = id
	_open_t = 0.0
	focus = Classes.ids().find(id)
	_sfx("select")
	hovered.emit(id)
	for cls in _rigs:
		_rigs[cls]["rig"].mood = "happy" if cls == id else ""


func close_card() -> void:
	open_id = ""
	for cls in _rigs:
		_rigs[cls]["rig"].mood = ""


func choose(id: String) -> void:
	## Choose: on its own, make (or switch to) that calling's hero.
	if id == "" or not bool(Classes.info(id)["enabled"]):
		_sfx("back")
		return
	_sfx("level_up")
	# Say which first: main.gd asks Game.has_hero(id) to know a new calling
	# (Mother Taper greets it). new_hero() is idempotent, so a listener that
	# made the hero already costs nothing here.
	picked.emit(id)
	if standalone:
		var g := get_node_or_null("/root/Game")
		if g:
			g.new_hero(id)


func _sfx(name: String) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s and name != "":
		s.play(name)


func _gui_input(event: InputEvent) -> void:
	var tapped := UI.is_tap(event)   # one tap, once (not its touch twin too)
	if not tapped:
		return
	if open_id != "":
		if not card_rect().has_point(event.position):
			close_card()
		return
	var R := alcove_rects()
	var ids := Classes.ids()
	for i in R.size():
		if (R[i] as Rect2).grow(4.0).has_point(event.position):
			if bool(Classes.info(ids[i])["enabled"]):
				open_card(ids[i])
			else:
				focus = i
				_sfx("back")
			return


func _unhandled_input(event: InputEvent) -> void:
	var ids := Classes.ids()
	if event.is_action_pressed("pause"):
		if open_id != "":
			close_card()
		elif show_back:
			back.emit()
	elif event.is_action_pressed("right") and open_id == "":
		focus = mini(focus + 1, ids.size() - 1)
	elif event.is_action_pressed("left") and open_id == "":
		focus = maxi(focus - 1, 0)
	elif event.is_action_pressed("jump") or event.is_action_pressed("equip"):
		if open_id == "":
			if bool(Classes.info(ids[focus])["enabled"]):
				open_card(ids[focus])
		else:
			choose(open_id)


func _process(dt: float) -> void:
	_t += dt
	_open_t += dt
	var s := UI.safe_rect(get_viewport())
	_back_btn.visible = show_back
	_back_btn.position = s.position + Vector2(0, 2)
	var R := alcove_rects()
	var ids := Classes.ids()
	var flames: Array = []
	for i in ids.size():
		if not _rigs.has(ids[i]):
			continue
		var r: Rect2 = R[i]
		var d: Dictionary = _rigs[ids[i]]
		d["holder"].position = Vector2(r.get_center().x, r.end.y - 38.0)
		var fs := float(Classes.info(ids[i])["flame_scale"])
		var dim := 1.0 if open_id == "" or open_id == ids[i] else 0.6
		flames.append({"p": d["rig"].flame_point() - global_position, "h": 17.0 * fs * d["holder"].scale.x * dim})
	_glow.extra_flames = flames
	var C := card_rect()
	var showing := open_id != ""
	_choose_btn.visible = showing
	_close_btn.visible = showing
	if showing:
		var g := get_node_or_null("/root/Game")
		var has: bool = g != null and g.has_hero(open_id)
		var is_cur := _current() == open_id
		_choose_btn.text = ("Play on" if is_cur else "Choose") if has or not standalone else "Begin"
		_choose_btn.reset_size()
		_choose_btn.position = Vector2(C.end.x - _choose_btn.size.x - 16.0, C.end.y - _choose_btn.size.y - 14.0)
		_close_btn.reset_size()
		_close_btn.position = Vector2(C.position.x + 16.0, C.end.y - _close_btn.size.y - 14.0)
	queue_redraw()
	_overlay.queue_redraw()


func _draw() -> void:
	var vs := get_size()
	var s := UI.safe_rect(get_viewport())
	if show_backdrop:
		draw_rect(Rect2(Vector2.ZERO, vs), UI.BG)
		# Far, faint vaulting.
		for i in 9:
			UI.arch(self, i * vs.x / 8.0 - 50.0, 100.0, 20.0 + (i % 2) * 24.0, vs.y + 10.0, Color("130e1d"))
	else:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.04, 0.55))
	UI.text(self, Vector2(0, s.position.y + 34.0), title, 30, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 6)
	UI.text(self, Vector2(0, s.position.y + 56.0), "Each calling is its own hero, with its own level, skills and gear.", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var R := alcove_rects()
	var ids := Classes.ids()
	for i in ids.size():
		_alcove(R[i], ids[i], i == focus)


func _alcove(r: Rect2, cls: String, sel: bool) -> void:
	var info: Dictionary = Classes.info(cls)
	var col := UI.class_color(cls)
	var on := bool(info["enabled"])
	var lit := sel or open_id == cls
	var top := r.position.y
	var bottom := r.end.y - 18.0
	# The stone frame, the niche inside it, the candlelight in the niche.
	UI.arch(self, r.position.x, r.size.x, top, bottom, Color("2a2138") if on else Color("1d1726"))
	UI.arch(self, r.position.x + 7.0, r.size.x - 14.0, top + 9.0, bottom, Color("0b0811"))
	if on:
		var c := Vector2(r.get_center().x, bottom - 40.0)
		var fl := 1.0 + 0.04 * sin(_t * 11.0 + r.position.x)
		var k := 1.6 if lit else 1.0
		for j in 3:
			draw_circle(c, (r.size.x * 0.55 - j * 14.0) * fl, Color(col.lerp(Color(1.0, 0.72, 0.35), 0.6), (0.035 + 0.03 * j) * k))
	else:
		# Bricked up and sealed with wax.
		var inner := r.grow_individual(-9.0, -26.0 - r.size.x * 0.4, -9.0, -18.0)
		var rows := int(inner.size.y / 12.0)
		for j in rows:
			var y := inner.position.y + j * 12.0
			draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color("1c1626"), 1.5)
			var off := 0.0 if j % 2 == 0 else 11.0
			var x := inner.position.x + off
			while x < inner.end.x:
				draw_line(Vector2(x, y), Vector2(x, y + 12.0), Color("1c1626"), 1.5)
				x += 22.0
		var sc := Vector2(r.get_center().x, r.position.y + r.size.y * 0.52)
		draw_circle(sc, 17.0, Color("4a1414"))
		draw_circle(sc, 14.0, Color("8a2020"))
		draw_arc(sc, 10.0, 0, TAU, 20, Color("5a1616"), 2.0)
		UI.glyph(self, "flame", sc + Vector2(0, 1), 12.0, Color("e0a080"))
	# The plinth.
	var pr := Rect2(r.position.x + 12.0, bottom - 20.0, r.size.x - 24.0, 12.0)
	draw_rect(pr, Color("3a2e4a") if on else Color("241d2e"))
	draw_rect(Rect2(pr.position, Vector2(pr.size.x, 2.0)), Color(1, 1, 1, 0.12))
	# A keystone in the calling's colour.
	var ks := Vector2(r.get_center().x, top + 4.0)
	draw_colored_polygon(PackedVector2Array([ks + Vector2(0, -6), ks + Vector2(6, 2), ks + Vector2(0, 10), ks + Vector2(-6, 2)]), col if on else Color("3a3148"))
	if lit and on:
		# Both sides down to the plinth (the line is open: no floor edge).
		var pts := UI.arch_points(r.position.x, r.size.x, top, bottom)
		draw_polyline(pts, Color(UI.GOLD, 0.45 + 0.25 * sin(_t * 3.0)), 2.0, true)
	# The name plate.
	var ny := r.end.y + 4.0
	UI.text(self, Vector2(r.position.x - 10.0, ny), str(info["name"]), UI.fit_size(str(info["name"]), r.size.x + 20.0, 17, 13, "title", 700),
			(UI.GOLD if lit else UI.CREAM) if on else Color(UI.MUTED, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20.0, "title", 700)
	var g := get_node_or_null("/root/Game")
	var sub := str(info["role"]).to_upper() if on else "SEALED"
	UI.text(self, Vector2(r.position.x - 10.0, ny + 16.0), sub, 9, Color(UI.MUTED, 0.9 if on else 0.5), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20.0, "body", 800)
	if on and g != null and g.has_hero(cls):
		var lv := "Level %d" % int(g.heroes()[cls]["level"])
		var cur := _current() == cls
		UI.text(self, Vector2(r.position.x - 10.0, ny + 31.0), lv + (" · playing" if cur else ""), 11, UI.GOLD if cur else UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20.0, "body", 700)


func _draw_card() -> void:
	if open_id == "":
		return
	var vs := get_size()
	var a := clampf(_open_t * 6.0, 0.0, 1.0)
	_overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.04, 0.72 * a))
	var info: Dictionary = Classes.info(open_id)
	var col := UI.class_color(open_id)
	var C := card_rect()
	C.position.y += (1.0 - a) * 12.0
	UI.panel(_overlay, C, Color(col, 0.9 * a), Color(UI.PANEL, 0.97 * a), 14.0)
	# The face, big, with its flame.
	var fc := Vector2(C.position.x + 82.0, C.position.y + 96.0)
	var f: Dictionary = _faces.get(open_id, {})
	_overlay.draw_circle(fc, 70.0, Color(col, 0.10 * a))
	UI.portrait(_overlay, fc, 58.0, f.get("tex"), col, a, f.get("uv", Rect2(0, 0, 1, 1)), str(info["name"]).substr(0, 1))
	# Its candle burning, where the portrait's wick is (rig.json says).
	var pf := portrait_flame(open_id)
	if not pf.is_empty() and f.get("tex") != null and f.get("uv", Rect2(0, 0, 1, 1)) == Rect2(0, 0, 1, 1):
		UI.flame(_overlay, fc + (pf["uv"] - Vector2(0.5, 0.5)) * 2.0 * 57.0, float(pf["h"]) * 57.0 / 46.0, _t, 1.0, false, a)
	# Ease: five pips.
	UI.text(_overlay, Vector2(C.position.x + 24.0, C.position.y + 184.0), "EASE", 10, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	UI.pips(_overlay, Vector2(C.position.x + 66.0, C.position.y + 180.0), 5, int(info["ease"]), 5.0, UI.GOLD, 4.0, a)
	UI.text(_overlay, Vector2(C.position.x + 24.0, C.position.y + 202.0), ease_word(int(info["ease"])), 11, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, 150.0)
	var x := C.position.x + 170.0
	var w := C.end.x - x - 18.0
	UI.text(_overlay, Vector2(x, C.position.y + 42.0), str(info["name"]), 30, Color(UI.GOLD, a), HORIZONTAL_ALIGNMENT_LEFT, w, "title", 700)
	UI.text(_overlay, Vector2(x, C.position.y + 60.0), str(info["role"]).to_upper(), 11, Color(col.lightened(0.2), a), HORIZONTAL_ALIGNMENT_LEFT, w, "body", 800)
	var y := C.position.y + 88.0
	y = _feature(x, y, w, "Special", str(info["special"]), str(info["special_text"]), col, a)
	y = _feature(x, y + 4.0, w, "Quirk", str(info["quirk"]), str(info["quirk_text"]), col, a)
	var g := get_node_or_null("/root/Game")
	var line := ""
	if g != null and g.has_hero(open_id):
		line = "Your Level %d %s" % [int(g.heroes()[open_id]["level"]), str(info["name"])]
	elif standalone and g != null:
		line = "A new hero, starting at level %d" % maxi(1, int(g.best_level()) - 2)
	if line != "":
		UI.text(_overlay, Vector2(x, C.end.y - 64.0), line, 13, Color(UI.CREAM, 0.85 * a), HORIZONTAL_ALIGNMENT_LEFT, w, "body", 700)


var _flame_at := {}                # cls -> {uv, h} from its rig.json


func portrait_flame(cls: String) -> Dictionary:
	## Where a calling's candle burns in its portrait: {uv (0..1 across the
	## picture), h (px at a portrait radius of 46)}, or {} if the rig says
	## nothing (the same reading as the cutscene's dialogue box).
	if not _flame_at.has(cls):
		var out := {}
		var p := "res://art/heroes/%s/rig.json" % cls
		var rd = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		if rd is Dictionary:
			var uv = rd.get("portrait_flame_uv", null)
			var vb = rd.get("portrait_viewbox", null)
			var pf = rd.get("portrait_flame", null)
			if uv is Array and uv.size() >= 2:
				out["uv"] = Vector2(float(uv[0]), float(uv[1]))
			elif pf is Array and pf.size() >= 2 and vb is Array and vb.size() >= 4 and float(vb[2]) > 0.0:
				out["uv"] = Vector2(float(pf[0]) / float(vb[2]), float(pf[1]) / float(vb[3]))
			if out.has("uv"):
				out["h"] = 15.0 * float(rd.get("flame_scale", 1.0))
				if pf is Array and pf.size() > 2 and vb is Array and vb.size() >= 4 and float(vb[2]) > 0.0:
					out["h"] = float(pf[2]) * 92.0 / float(vb[2])
		_flame_at[cls] = out
	return _flame_at[cls]


func _feature(x: float, y: float, w: float, label: String, name: String, body: String, col: Color, a: float) -> float:
	UI.text(_overlay, Vector2(x, y), label.to_upper(), 10, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	var lw := UI.text_width(label.to_upper(), 10, "body", 800)
	UI.text(_overlay, Vector2(x + lw + 8.0, y + 1.0), name, 16, Color(col.lightened(0.3), a), HORIZONTAL_ALIGNMENT_LEFT, w - lw - 8.0, "body", 800)
	var lines := UI.wrap(body, w, 13)
	for i in mini(lines.size(), 2):
		UI.text(_overlay, Vector2(x, y + 19.0 + i * 16.0), lines[i], 13, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, w)
	return y + 22.0 + mini(lines.size(), 2) * 16.0 + 6.0
