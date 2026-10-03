extends CanvasLayer
## The modes' layer over a level (p_modes §5.15): the mode pill (while the
## HUD has no mode_pill of its own, SC's, it is drawn here in the sigils'
## corner, widened to 150 x 26), and the cards, over the HUD and the touch
## buttons:
##   glimmer_card(offers)   the landing's two Glimmers (the World is paused)
##   finish_card(finish)    a trial's time, medal, best and next target
##   rematch_card(outcome)  a Waxworks win: time, drips, seal, rewards
##   deep_keeps(then)       "The Deep keeps you", 2 s, then(): the run ended
## Headless, none of it is made (the mode never adds this layer).

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/modes/mode_art.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const Data := preload("res://scripts/modes/descent_data.gd")
const TrialData := preload("res://scripts/modes/trial_data.gd")
const Cosmetics := preload("res://scripts/modes/cosmetics.gd")

var mode: Object = null
var world: Node = null
var pill := {}:
	set(v):
		pill = v
		if _view != null:
			_view.queue_redraw()
var card := ""                    # "" | glimmer | finish | rematch | deep
var _data := {}
var _view: Control
var _buttons: Array = []
var _t := 0.0
var _card_t := 0.0
var _then: Callable
var _tb := TriBatch.new()


func _ready() -> void:
	layer = 7
	UI.warm()
	Art.warm()
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	add_child(_view)


func _process(dt: float) -> void:
	_t += dt
	_card_t += dt
	if card == "finish" and _card_t >= 0.6 and _card_t - dt < 0.6:
		# The medal stamps down: its sound (pitched by the medal) and 30 ms.
		_haptic(30)
		var s := get_node_or_null("/root/Sfx")
		if s != null:
			s.play("medal", float(_data.get("medal_pitch", 1.0)))
			if bool(_data.get("medal_glimmer", false)):
				s.play("glimmer")   # Dawn: the Gold, and a glimmer over it
	elif card == "rematch" and _card_t >= 0.3 and _card_t - dt < 0.3 and int(_data.get("seal", 0)) > 0:
		_haptic(30)   # the seal stamps down
	if card == "deep" and _card_t >= 2.0:
		var cb := _then
		close_card()
		if cb.is_valid():
			cb.call()
	_view.queue_redraw()
	if card != "":
		_layout_buttons()


func _haptic(ms: int) -> void:
	var g := get_node_or_null("/root/Game")
	if g != null and bool(g.setting("haptics")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _safe() -> Rect2:
	return UI.safe_rect(get_viewport())


func pill_rect() -> Rect2:
	## The sigils' corner widened to 150 x 26 (the HUD's layout()["sigils"]),
	## reaching over the sigils' dark tray (its 4 px on the right) so the
	## empty sigil slots never show through a mode's pill.
	var h = world.get("hud") if world != null else null
	if h != null and h.has_method("layout"):
		var sr: Rect2 = h.layout()["sigils"]
		return Rect2(sr.end.x + 4.0 - 154.0, sr.position.y - 2.0, 154.0, 26.0)
	var s := _safe()
	return Rect2(s.end.x - 46.0 - 154.0, s.position.y + 7.0, 154.0, 26.0)


# ---------------------------------------------------------------- cards

func close_card() -> void:
	card = ""
	_data = {}
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open(kind: String, data: Dictionary) -> void:
	close_card()
	card = kind
	_data = data
	_card_t = 0.0
	_view.mouse_filter = Control.MOUSE_FILTER_STOP


func _button(label: String, accent: bool, cb: Callable, size := 17, min_size := Vector2(120, 44)) -> Button:
	var b := UI.make_button(label, accent, cb, "click", size)
	b.custom_minimum_size = min_size
	_view.add_child(b)
	_buttons.append(b)
	return b


func _flat_button(r: Rect2, cb: Callable) -> Button:
	## An invisible button over a drawn card.
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.position = r.position
	b.size = r.size
	b.pressed.connect(cb)
	_view.add_child(b)
	_buttons.append(b)
	b.set_meta("rect", r)
	return b


func glimmer_card(offers: Array) -> void:
	_open("glimmer", {"offers": offers})
	for i in offers.size():
		var k := i
		_flat_button(glimmer_rects()[i], func(): _pick(k))
	var e := Data.WALK_ON * int(_embers_mult())
	_button("Walk on · +%d embers" % e, false, func(): _pick(-1), 15, Vector2(200, 40))


func _embers_mult() -> int:
	var d := str(mode.get("mode_diff")) if mode != null else "dusk"
	return int({"dusk": 1, "nightfall": 2, "witching": 3}.get(d, 1))


func _pick(i: int) -> void:
	if mode != null and mode.has_method("choose_glimmer"):
		mode.choose_glimmer(i)
	else:
		close_card()


func glimmer_rects() -> Array:
	## Two 220 x 140 cards, 24 px apart, centred across, under the HUD's top
	## band (where a title card or the level-up card shows) and its heading.
	var s := _safe()
	var top := glimmer_heading_y() + 12.0
	var c := s.get_center()
	return [Rect2(c.x - 12.0 - 220.0, top, 220.0, 140.0), Rect2(c.x + 12.0, top, 220.0, 140.0)]


func glimmer_heading_y() -> float:
	## The heading's baseline: under the HUD's top band (hud.title_rect).
	var s := _safe()
	var band := s.position.y + 101.0
	var h = world.get("hud") if world != null else null
	if h != null and h.has_method("title_rect"):
		band = (h.title_rect() as Rect2).end.y
	return band + 22.0


func finish_card(f: Dictionary) -> void:
	_open("finish", f)
	_button("Retry", true, func(): _mode_call("restart"), 20, Vector2(150, 50))
	if str(f.get("next", "")) != "":
		_button("Next trial", false, func(): _next_trial(str(f["next"])), 16, Vector2(130, 44))
	_button("Trials", false, func(): _mode_call("quit"), 16, Vector2(110, 44))


func _next_trial(nid: String) -> void:
	var m = mode
	close_card()
	if m == null:
		return
	var trials = load("res://scripts/modes/trials.gd")
	trials.play_trial(m.main, nid)


func rematch_card(o: Dictionary) -> void:
	_open("rematch", o)
	if bool(o.get("gauntlet", false)):
		_button("Waxworks", true, func(): _mode_call("leave"), 18, Vector2(150, 48))
	else:
		_button("Retry", true, func(): _rematch_again(), 20, Vector2(150, 50))
		_button("Waxworks", false, func(): _mode_call("leave"), 16, Vector2(130, 44))


func _rematch_again() -> void:
	var m = mode
	close_card()
	if m != null:
		m.set("over", "")
		m.begin()


func deep_keeps(then: Callable) -> void:
	_open("deep", {})
	_then = then
	var s := get_node_or_null("/root/Sfx")
	if s != null:
		s.play("snuff", 0.7)


func _mode_call(fn: String) -> void:
	var m = mode
	close_card()
	if m != null and m.has_method(fn):
		m.call(fn)


func card_rect() -> Rect2:
	var s := _safe()
	var w := minf(480.0, s.size.x - 40.0)
	var h := minf(300.0, s.size.y - 30.0)
	return Rect2(s.get_center() - Vector2(w, h) * 0.5, Vector2(w, h))


func _layout_buttons() -> void:
	var r := card_rect()
	var row: Array = []
	for b in _buttons:
		if not is_instance_valid(b):
			continue
		if (b as Button).has_meta("rect"):
			var rr: Rect2 = b.get_meta("rect")
			b.position = rr.position
			b.size = rr.size
		else:
			row.append(b)
	if row.is_empty():
		return
	var total := 0.0
	for b in row:
		(b as Button).reset_size()
		total += (b as Button).size.x
	total += 12.0 * (row.size() - 1)
	var x := r.get_center().x - total * 0.5
	var y := r.end.y - 58.0
	if card == "glimmer":
		y = glimmer_rects()[0].end.y + 6.0
	for b in row:
		(b as Button).position = Vector2(x, y + (50.0 - (b as Button).size.y) * 0.5)
		x += (b as Button).size.x + 12.0


# ---------------------------------------------------------------- drawing

func _draw_view() -> void:
	var h = world.get("hud") if world != null else null
	if not pill.is_empty() and not (h != null and h.has_method("mode_pill")):
		_draw_pill()   # under a card's shade too, so the sigil tray never shows
	match card:
		"glimmer":
			_draw_glimmers()
		"finish":
			_draw_finish()
		"rematch":
			_draw_rematch()
		"deep":
			_draw_deep()
	_tb.flush(_view)


func _draw_pill() -> void:
	var r := pill_rect()
	UI.panel(_view, r, Color(UI.PANEL_EDGE, 0.8), UI.PANEL, 12.0)
	var m := str(pill.get("mode", ""))
	var cy := r.get_center().y
	match m:
		"descent":
			UI.text(_view, Vector2(r.position.x + 10.0, cy + 6.0), str(pill.get("text", "")), 16, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
			var x := r.position.x + 54.0
			for i in int(pill.get("spare", 0)):
				Art.spare_wick(_view, _tb, Vector2(x + i * 13.0, cy), 16.0, true)
			x += 13.0 * maxi(int(pill.get("spare", 0)), 0) + 6.0
			for i in mini(int(pill.get("hushings", 0)), 6):
				Art.hushing(_view, _tb, Vector2(x + i * 11.0, cy), 12.0)
		"trial":
			# The clock: a small candle whose flame shortens as time goes.
			var t := float(pill.get("time", 0.0))
			var burn := clampf(1.0 - t / 90.0, 0.25, 1.0)
			_view.draw_rect(Rect2(r.position.x + 12.0, cy - 6.0, 6.0, 13.0 * burn), Art.TAPER)
			UI.flame(_view, Vector2(r.position.x + 15.0, cy - 6.0), 10.0 * burn + 3.0, _t, 0.0, false, 1.0, false)
			UI.text(_view, Vector2(r.position.x + 26.0, cy + 6.0), str(pill.get("text", "0:00.00")), 15, UI.CREAM if bool(pill.get("started", false)) else UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
			if int(pill.get("total", 0)) > 0:
				UI.text(_view, Vector2(r.end.x - 70.0, cy + 6.0), "%d/%d" % [int(pill.get("lit", 0)), int(pill.get("total", 0))], 14, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 60.0, "body", 700)
		"waxworks":
			Art.drip(_view, _tb, Vector2(r.position.x + 16.0, cy), 16.0)
			UI.text(_view, Vector2(r.position.x + 28.0, cy + 6.0), str(pill.get("text", "")), 15, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
			if pill.has("clock"):
				var c := float(pill["clock"])
				UI.text(_view, Vector2(r.end.x - 70.0, cy + 6.0), "%d:%02d" % [int(c) / 60, int(c) % 60], 15, UI.BAD if c < 15.0 else UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 60.0, "body", 700)
			elif pill.has("spare"):
				for i in int(pill["spare"]):
					Art.spare_wick(_view, _tb, Vector2(r.end.x - 14.0 - i * 13.0, cy), 16.0, true)


func _shade(a := 0.72) -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0.03, 0.02, 0.05, a))


func _draw_glimmers() -> void:
	_shade(0.7)
	var s := _safe()
	UI.text(_view, Vector2(s.position.x, glimmer_heading_y()), "A Glimmer for the run", 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 4)
	var offers: Array = _data.get("offers", [])
	var rs := glimmer_rects()
	for i in mini(offers.size(), 2):
		var gid: String = offers[i]
		var gd: Dictionary = Data.GLIMMERS.get(gid, {})
		var r: Rect2 = rs[i]
		var pop := clampf(_card_t / 0.2, 0.0, 1.0)
		var rr := r.grow(-6.0 * (1.0 - pop))
		UI.panel(_view, rr, UI.GOLD, Color("241a33"), 14.0)
		var have := 0
		if mode != null and mode.has_method("glimmer"):
			have = int(mode.glimmer(gid))
		UI.glyph(_view, str(gd.get("glyph", "star")), rr.position + Vector2(rr.size.x * 0.5, 36.0), 32.0, UI.EMBER)
		UI.text(_view, rr.position + Vector2(0, 78.0), str(gd.get("name", gid)), 19, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, "title", 700)
		UI.text(_view, rr.position + Vector2(0, 101.0), str(gd.get("text", "")), 14, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		UI.text(_view, rr.position + Vector2(0, 124.0), "%d of %d" % [have + 1, int(gd.get("max", 1))], 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)


func _draw_finish() -> void:
	_shade(0.62)
	var r := card_rect()
	UI.panel(_view, r, UI.GOLD, Color("1d1529"), 16.0)
	var f := _data
	var tid := str(f.get("id", ""))
	var tname := str(TrialData.TRIALS.get(tid, {}).get("name", "Trial"))
	UI.text(_view, r.position + Vector2(0, 34.0), tname, 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "title", 700)
	# The time counts up to the final one in 0.6 s.
	var t := float(f.get("time", 0.0)) * clampf(_card_t / 0.6, 0.0, 1.0)
	var cs := int(round(t * 100.0))
	UI.text(_view, r.position + Vector2(24.0, 84.0), "%d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100], 34, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	# The medal stamps down, 1.6 -> 1.0 over 0.18 s, once the time is up.
	var m := int(f.get("medal", 1))
	var k := clampf((_card_t - 0.6) / 0.18, 0.0, 1.0)
	if _card_t >= 0.6:
		var sc := lerpf(1.6, 1.0, k)
		Art.medal(_view, _tb, r.position + Vector2(r.size.x - 70.0, 88.0), 30.0 * sc, m, k)
		UI.text(_view, r.position + Vector2(r.size.x - 130.0, 138.0), TrialData.MEDAL_NAME[m], 15, Art.MEDAL_COL[m], HORIZONTAL_ALIGNMENT_CENTER, 120.0, "body", 700)
	var best := float(f.get("best", 0.0))
	var bcs := int(round(best * 100.0))
	var best_line := "Best %d:%02d.%02d" % [bcs / 6000, (bcs / 100) % 60, bcs % 100]
	if bool(f.get("new_best", false)):
		best_line += "  · a new best"
	UI.text(_view, r.position + Vector2(24.0, 114.0), best_line, 15, UI.MUTED)
	var nm := int(f.get("next_medal", 0))
	if nm >= 2:
		var nt := float(f.get("next_time", 0.0))
		var ncs := int(round(nt * 100.0))
		UI.text(_view, r.position + Vector2(24.0, 136.0), "Next: %s at %d:%02d" % [TrialData.MEDAL_NAME[nm], ncs / 6000, (ncs / 100) % 60], 15, UI.GOLD)
	var extra := PackedStringArray()
	if int(f.get("embers", 0)) > 0:
		extra.append("+%d embers" % int(f["embers"]))
	for nid in f.get("cosmetics", []):
		var rn := Cosmetics.reward_name(str(nid))
		extra.append(rn if rn != "" else str(nid))
	if not extra.is_empty():
		UI.text(_view, r.position + Vector2(24.0, 158.0), " · ".join(extra), 14, UI.GOOD)
	var who := "Hollin" if str(f.get("speaker", "taper")) == "hollin" else "Mother Taper"
	var line := "%s: \"%s\"" % [who, str(f.get("line", ""))]
	var lines := UI.wrap(line, r.size.x - 48.0, 15, "italic", 500)
	for i in mini(lines.size(), 2):
		UI.text(_view, r.position + Vector2(24.0, 190.0 + i * 20.0), str(lines[i]), 15, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "italic", 500)


func _draw_rematch() -> void:
	_shade(0.62)
	var r := card_rect()
	UI.panel(_view, r, UI.GOLD, Color("1d1529"), 16.0)
	var o := _data
	if bool(o.get("gauntlet", false)):
		var cleared := bool(o.get("cleared", false))
		UI.text(_view, r.position + Vector2(0, 36.0), "The Gauntlet" if cleared else "The Gauntlet ends", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "title", 700)
		UI.text(_view, r.position + Vector2(0, 76.0), "%d of %d casts" % [int(o.get("reached", 0)), int(o.get("of", 6))], 20, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 700)
		var tt := float(o.get("time", 0.0))
		UI.text(_view, r.position + Vector2(0, 104.0), "%d:%02d · %d drips" % [int(tt) / 60, int(tt) % 60, int(o.get("drips", 0))], 16, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_rewards(o, r, 136.0)
		return
	var boss := str(o.get("boss", ""))
	var names := {"tollgrave": "Old Tollgrave", "snuffer": "The Snuffer", "rootmother": "Mother Gravebough",
			"tinker": "The Tinker of Hours", "saint": "The Prism Saint", "hush": "The Hush"}
	UI.text(_view, r.position + Vector2(0, 34.0), "%s, cast again" % str(names.get(boss, boss)), 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "title", 700)
	var tt := float(o.get("time", 0.0))
	UI.text(_view, r.position + Vector2(24.0, 80.0), "%d:%02d.%d" % [int(tt) / 60, int(tt) % 60, int(fmod(tt, 1.0) * 10.0)], 30, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	UI.text(_view, r.position + Vector2(24.0, 106.0), "%d drips" % int(o.get("drips", 0)), 16, UI.MUTED)
	var seal := int(o.get("seal", 0))
	var k := clampf((_card_t - 0.3) / 0.18, 0.0, 1.0)
	if seal > 0 and _card_t >= 0.3:
		Art.seal(_view, _tb, r.position + Vector2(r.size.x - 70.0, 86.0), 30.0 * lerpf(1.6, 1.0, k), seal, true)
		UI.text(_view, r.position + Vector2(r.size.x - 130.0, 134.0), "%s seal" % ["", "Bronze", "Silver", "Gold"][seal], 14, Art.SEAL_COL[seal], HORIZONTAL_ALIGNMENT_CENTER, 120.0, "body", 700)
	_rewards(o, r, 130.0)
	var line := "Waxley: \"%s\"" % ("Lovely work. I'll have him melted down and cast again." if seal > 0 else "Not bad! Try it hotter next time.")
	UI.text(_view, r.position + Vector2(24.0, 212.0), line, 14, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48.0, "italic", 500)


func _rewards(o: Dictionary, r: Rect2, y: float) -> void:
	var bits := PackedStringArray()
	if int(o.get("xp", 0)) > 0:
		bits.append("+%d XP" % int(o["xp"]))
	var embers := int(o.get("embers", 0))
	for rw in o.get("rewards", []):
		if str(rw.get("kind", "")) == "embers":
			embers += int(rw["n"])
	if embers > 0:
		bits.append("+%d embers" % embers)
	for rw in o.get("rewards", []):
		match str(rw.get("kind", "")):
			"item":
				bits.append(str((rw["item"] as Dictionary).get("name", "an item")))
			"cosmetic":
				bits.append(Cosmetics.reward_name(str(rw["id"])))
	var lines := UI.wrap(" · ".join(bits), r.size.x - 48.0, 14)
	for i in mini(lines.size(), 3):
		UI.text(_view, r.position + Vector2(24.0, y + i * 19.0), str(lines[i]), 14, UI.GOOD)


func _draw_deep() -> void:
	var a := clampf(_card_t / 0.4, 0.0, 1.0)
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0.01, 0.0, 0.02, 0.9 * a))
	var s := _safe()
	UI.text(_view, Vector2(s.position.x, s.get_center().y), "The Deep keeps you", 30, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 4)
	UI.text(_view, Vector2(s.position.x, s.get_center().y + 30.0), "Your XP, your gear and your banked embers stay yours.", 14, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "italic", 500)
