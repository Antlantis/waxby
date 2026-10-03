extends Control
## The Waxworks' screen (spec §7.6, p_modes §6.7): the six casts as portrait
## discs (an unbeaten one a dark silhouette with a "?"), the chosen cast's
## three seal ribbons on this difficulty, the Tweak chips (tap to add or
## take away; gold when on; the two that need boss_mods.gd stay hidden until
## it's in the build), what the last one tapped does, the drip total and its
## seal, Waxley's line, and Rematch (and the Gauntlet, once all six are
## cast). The Tweaks and the difficulty chosen are remembered.

signal back

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/modes/mode_art.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const ModesSave := preload("res://scripts/modes/modes_save.gd")
const WAXWORKS := "res://scripts/modes/waxworks.gd"
const DIFFS := ["dusk", "nightfall", "witching"]
const DIFF_NAME := {"dusk": "Dusk", "nightfall": "Nightfall", "witching": "Witching"}
# The wax casts' calm faces (the portraits that exist: the Hush has only
# hush_open; "normal" fell back to wrath or, for the Hush, to a letter).
const FACES := {"tollgrave": ["tollgrave", "kind"], "snuffer": ["snuffer", "cold"], "rootmother": ["rootmother", "keeping"],
		"tinker": ["tinker", "ticking"], "saint": ["saint", "serene"], "hush": ["hush", "open"]}
const NAMES := {"tollgrave": "Old Tollgrave", "snuffer": "The Snuffer", "rootmother": "Mother Gravebough",
		"tinker": "The Tinker of Hours", "saint": "The Prism Saint", "hush": "The Hush"}

var main: Node = null
var diff := "dusk"
var boss := "tollgrave"
var tweaks: Array = []
var _t := 0.0
var _back_btn: Button
var _rematch_btn: Button
var _gauntlet_btn: Button
var _diff_btns := {}
var _chips := {}
var tip := ""                     # the Tweak last tapped (its effect is shown)
var _tb := TriBatch.new()
var _faces := {}
var _W = null


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	Art.warm()
	_W = load(WAXWORKS)
	var g := _game()
	if g != null:
		var wb: Dictionary = ModesSave.block(g)["waxworks"]
		diff = str(wb.get("diff", "dusk"))
		if not g.diff_open(diff):
			diff = "dusk"
		tweaks = (wb.get("tweaks", []) as Array).filter(func(t): return _W.tweak_open(str(t)))
		boss = str(wb.get("boss", "tollgrave"))
		for b in ModesSave.open_casts(g):
			ModesSave.mark_seen(g, "cast:" + str(b), false)
		g.save()
	var casts := ModesSave.open_casts(g)
	if not casts.has(boss) and not casts.is_empty():
		boss = str(casts[0])
	for b in ModesSave.BOSSES:
		var f: Array = FACES[b]
		var p := UI.portrait_path(str(f[0]), str(f[1]))
		_faces[b] = UI.tex(p) if p != "" else null
	_back_btn = UI.make_button("Back", false, func(): back.emit(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	add_child(_back_btn)
	for d in DIFFS:
		var dd: String = d
		var b := UI.make_button(DIFF_NAME[d], false, func(): _set_diff(dd), "select", 13)
		UI.small_button(b, 13)
		b.custom_minimum_size = Vector2(82, UI.TAP_H)
		add_child(b)
		_diff_btns[d] = b
	for tid in _W.TWEAK_ORDER:
		var t: String = tid
		var b := UI.make_button("", false, func(): toggle(t), "", 12)
		UI.small_button(b, 12)
		b.custom_minimum_size = Vector2(0, 40)
		b.clip_text = true
		add_child(b)
		_chips[tid] = b
	_rematch_btn = UI.make_button("Rematch", true, func(): _rematch(), "", 19)
	_rematch_btn.custom_minimum_size = Vector2(170, 46)
	add_child(_rematch_btn)
	_gauntlet_btn = UI.make_button("Gauntlet", false, func(): _gauntlet(), "", 16)
	_gauntlet_btn.custom_minimum_size = Vector2(170, 46)
	add_child(_gauntlet_btn)
	_refresh()


func drips() -> int:
	var g := _game()
	var st := str(g.setting("candle_strength")) if g != null else "normal"
	return int(_W.drips_of(tweaks, st, boss))


func toggle(tid: String) -> void:
	if not _W.tweak_open(tid, boss):
		return
	if tweaks.has(tid):
		tweaks.erase(tid)
	else:
		tweaks.append(tid)
	tip = tid
	var s := get_node_or_null("/root/Sfx")
	if s != null:
		s.play("drip_plop", 1.0 + 0.05 * tweaks.size())
	_save()
	_refresh()


func _save() -> void:
	var g := _game()
	if g == null:
		return
	var wb: Dictionary = ModesSave.block(g)["waxworks"]
	wb["tweaks"] = tweaks.duplicate()
	wb["diff"] = diff
	wb["boss"] = boss
	g.save()


func _set_diff(d: String) -> void:
	var g := _game()
	if g != null and not g.diff_open(d):
		return
	diff = d
	_save()
	_refresh()


func pick(b: String) -> void:
	if not ModesSave.open_casts(_game()).has(b):
		return
	boss = b
	_save()
	_refresh()


func _refresh() -> void:
	var g := _game()
	for d in DIFFS:
		var b: Button = _diff_btns[d]
		b.visible = g == null or bool(g.diff_open(d))
		b.add_theme_color_override("font_color", UI.GOLD if d == diff else UI.CREAM)
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		sb.border_color = UI.GOLD if d == diff else UI.PANEL_EDGE
		b.add_theme_stylebox_override("normal", sb)
	for tid in _chips:
		var b: Button = _chips[tid]
		var t: Dictionary = _W.TWEAKS[tid]
		var open: bool = _W.tweak_open(tid, boss)
		var on := tweaks.has(tid)
		b.text = "%s · %d" % [t["name"], int(t["drips"])]
		b.visible = open
		b.add_theme_color_override("font_color", UI.INK if on else UI.CREAM)
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		sb.bg_color = UI.GOLD if on else Color("2a2038")
		sb.border_color = UI.GOLD if on else UI.PANEL_EDGE
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
	_rematch_btn.disabled = not ModesSave.open_casts(g).has(boss)
	_gauntlet_btn.disabled = not ModesSave.gauntlet_open(g)
	# (all six casts: a build without them all says only that they're deeper)
	_gauntlet_btn.text = "Gauntlet" if ModesSave.gauntlet_open(g) else ("Gauntlet: beat all six first"
			if ModesSave.built_casts().size() == ModesSave.BOSSES.size() else "Gauntlet: deeper down")
	_layout()


func disc_centers() -> Array:
	var s := UI.safe_rect(get_viewport())
	var n := ModesSave.BOSSES.size()
	var gap := minf(78.0, (s.size.x - 40.0) / n)
	var x0 := s.get_center().x - gap * (n - 1) * 0.5
	var out: Array = []
	for i in n:
		out.append(Vector2(x0 + gap * i, s.position.y + 88.0))
	return out


func shown_tweaks() -> Array:
	## The Tweaks this build can play on this cast, in order (Warded and
	## Echoing wait for boss_mods.gd; Echoing for the casts it echoes).
	return (_W.TWEAK_ORDER as Array).filter(func(t): return _W.tweak_open(str(t), boss))


func chip_rects() -> Array:
	## The shown chips in two rows (4 + 4, or 5 + 5 once all ten are in).
	var s := UI.safe_rect(get_viewport())
	var n := shown_tweaks().size()
	var per := maxi((n + 1) / 2, 1)
	var w := (s.size.x - (per - 1) * 8.0) / per
	var out: Array = []
	for i in n:
		out.append(Rect2(s.position.x + (i % per) * (w + 8.0), s.position.y + 178.0 + (i / per) * 46.0, w, 40.0))
	return out


func tip_text() -> String:
	## What the last Tweak tapped does ("" before one is).
	if tip == "" or not _W.TWEAKS.has(tip):
		return ""
	var t: Dictionary = _W.TWEAKS[tip]
	var what := str(t["text"])
	if tip == "clock":
		var c := float(_W.CLOCK.get(boss, 120.0))
		what = "Beat %s inside %d:%02d" % [str(NAMES.get(boss, boss)), int(c) / 60, int(c) % 60]
	return "%s%s: %s" % [str(t["name"]), "" if tweaks.has(tip) else " (off)", what]


func _layout() -> void:
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)
	var x := s.end.x
	for i in range(DIFFS.size() - 1, -1, -1):
		var b: Button = _diff_btns[DIFFS[i]]
		if not b.visible:
			continue
		b.reset_size()
		x -= b.size.x
		b.position = Vector2(x, s.position.y + 2)
		x -= 6.0
	var rs := chip_rects()
	var shown := shown_tweaks()
	for i in shown.size():
		var b: Button = _chips[shown[i]]
		b.custom_minimum_size = (rs[i] as Rect2).size
		b.size = (rs[i] as Rect2).size
		b.position = (rs[i] as Rect2).position
	_rematch_btn.reset_size()
	_gauntlet_btn.reset_size()
	var y := s.end.y - 50.0
	_rematch_btn.position = Vector2(s.end.x - _rematch_btn.size.x, y)
	_gauntlet_btn.position = Vector2(_rematch_btn.position.x - _gauntlet_btn.size.x - 10.0, y)


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
	var cs := disc_centers()
	for i in cs.size():
		if (cs[i] as Vector2).distance_to(pos) <= 34.0:
			pick(ModesSave.BOSSES[i])
			accept_event()
			return


func _rematch() -> void:
	var g := _game()
	_W.rematch(main, boss, diff, tweaks, str(g.setting("candle_strength")) if g != null else "normal")


func _gauntlet() -> void:
	var g := _game()
	if not ModesSave.gauntlet_open(g):
		return
	_W.start_gauntlet(main, diff, tweaks, str(g.setting("candle_strength")) if g != null else "normal")


func _draw() -> void:
	UI.backdrop(self, get_size())
	var s := UI.safe_rect(get_viewport())
	var g := _game()
	UI.text(self, Vector2(s.position.x, s.position.y + 28.0), "The Waxworks", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 4)
	UI.text(self, Vector2(s.position.x, s.position.y + 45.0), "Waxley's cellar", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "italic", 500)
	var casts := ModesSave.open_casts(g)
	var cs := disc_centers()
	# The discs: the unbeaten ones' dark first, then the faces, their cream
	# wash and the seals over them, then the "?"s on top.
	for i in cs.size():
		var b: String = ModesSave.BOSSES[i]
		if not casts.has(b):
			_tb.circle(cs[i], 29.0, Color("100b18"), 24)
			_tb.ring(cs[i], 29.0, 2.0, Color(UI.PANEL_EDGE, 0.6), 24)
	_tb.flush(self)
	for i in cs.size():
		var b: String = ModesSave.BOSSES[i]
		if casts.has(b):
			UI.portrait(self, cs[i], 28.0, _faces.get(b), Art.WAX, 1.0, Rect2(0, 0, 1, 1), str(NAMES[b]).get_slice(" ", 1).substr(0, 1))
	for i in cs.size():
		var b: String = ModesSave.BOSSES[i]
		var c: Vector2 = cs[i]
		if casts.has(b):
			_tb.circle(c, 27.0, Color(Art.WAX, 0.28), 24)
			if b == boss:
				_tb.ring(c, 36.0, 3.0, UI.GOLD, 28)
		# This difficulty's three seals under the cast.
		var paid: Array = ModesSave.boss_rec(g, b, diff).get("paid", []) if g != null else []
		for k in 3:
			var lit: bool = paid.has(["bronze", "silver", "gold"][k])
			Art.seal(self, _tb, c + Vector2((k - 1) * 19.0, 44.0), 8.0, k + 1, lit)
	_tb.flush(self)
	for i in cs.size():
		if not casts.has(ModesSave.BOSSES[i]):
			UI.text(self, (cs[i] as Vector2) + Vector2(-20, 9), "?", 26, Color(UI.MUTED, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 40.0, "title", 700)
	# The chosen cast's name and records.
	var rec: Dictionary = ModesSave.boss_rec(g, boss, diff) if g != null else {}
	var name := str(NAMES.get(boss, boss))
	var info := name
	if float(rec.get("time", 0.0)) > 0.0:
		var t := float(rec["time"])
		info += "  ·  best %d:%02d  ·  most %d drips" % [int(t) / 60, int(t) % 60, int(rec.get("drips", 0))]
	UI.text(self, Vector2(s.position.x, s.position.y + 158.0), info, 15, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "body", 700)
	# What the last Tweak tapped does.
	var tt := tip_text()
	if tt != "":
		var rs := chip_rects()
		var ty := ((rs[rs.size() - 1] as Rect2).end.y if not rs.is_empty() else s.position.y + 270.0) + 22.0
		UI.text(self, Vector2(s.position.x, ty), tt, UI.fit_size(tt, s.size.x, 14, 11, "body", 700), UI.GOLD if tweaks.has(tip) else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "body", 700)
	# The drips and the seal they make.
	var d := drips()
	var seal: int = _W.seal_of(d)
	var y := s.end.y - 58.0
	Art.drip(self, _tb, Vector2(s.position.x + 12.0, y + 14.0), 22.0)
	var line := "%d drips%s" % [d, (" · %s seal" % ["", "Bronze", "Silver", "Gold"][seal]) if seal > 0 else " · no seal yet"]
	UI.text(self, Vector2(s.position.x + 28.0, y + 21.0), line, 17, UI.GOLD if seal > 0 else UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	if seal > 0:
		Art.seal(self, _tb, Vector2(s.position.x + 36.0 + UI.text_width(line, 17, "body", 700) + 14.0, y + 14.0), 12.0, seal, true)
	var wl := "Waxley: \"%s\"" % str(_W.waxley_line(tweaks))
	var room := _gauntlet_btn.position.x - s.position.x - 12.0
	UI.text(self, Vector2(s.position.x, y + 42.0), wl, UI.fit_size(wl, room, 13, 10, "italic", 500), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, room, "italic", 500)
	_tb.flush(self)
