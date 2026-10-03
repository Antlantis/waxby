extends Control
## One choice over a paused game: a heading, up to three cards side by side
## and one button under them. The Descent's landing offers its Glimmers on
## it (mode_hud.glimmer_card: two cards, "Walk on · +20 embers"), a lit altar
## in a story level its Altar Rites (world.offer_choice, rites.gd: up to three
## skills, "Later"), and the results screen the same Rites; the bosses' boons
## come next.
##
## An offer is a card: {name, text, glyph, sub, new} (and col, the glyph's
## colour, EMBER by default; any other keys are the caller's). new puts a gold
## NEW tag on it. Two "pair" cards are 220 x 140, 24 px apart (the Descent's,
## the second slot kept even for one card); otherwise one to three are
## 200 x 150, 16 px apart, centred (3 x 200 + 2 x 16 = 632 px: inside the
## 844 px glass between the island's insets). They sit under the HUD's top
## band (hud.title_rect, where a title card or the level-up card shows) and
## the heading.
##
## open(offers, opts) shows it, opts {heading, later (the button's words),
## pick: Callable(i), pair}. A card tapped calls pick(i), the button pick(-1);
## the caller closes it (close()) and lets go of whatever it paused. A full
## rect over its layer, it takes every touch while it's open and none after.

const UI := preload("res://scripts/ui.gd")

const MAX := 3
const W := 200.0                  # a card (three across)
const H := 150.0
const GAP := 16.0
const PAIR_W := 220.0             # the Descent's two Glimmers
const PAIR_H := 140.0
const PAIR_GAP := 24.0
const FILL := Color("241a33")

var world: Node = null            # the level under it: its HUD's top band sets the heading's height
var offers: Array = []
var heading := ""
var later := ""
var pair := false
var _pick: Callable
var _t := 0.0
var _buttons: Array = []
var _later_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.warm()


func is_open() -> bool:
	return not offers.is_empty()


func open(p_offers: Array, opts := {}) -> void:
	close()
	offers = p_offers.slice(0, MAX)
	heading = str(opts.get("heading", ""))
	later = str(opts.get("later", "Later"))
	pair = bool(opts.get("pair", false))
	_pick = opts.get("pick", Callable())
	_t = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rs := rects()
	for i in offers.size():
		var k := i
		_flat_button(rs[i], func(): choose(k))
	_later_btn = UI.make_button(later, false, func(): choose(-1), "click", 15)
	_later_btn.custom_minimum_size = Vector2(200, 40)
	add_child(_later_btn)
	_buttons.append(_later_btn)
	_layout_buttons()
	queue_redraw()


func close() -> void:
	offers = []
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()
	_later_btn = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func choose(i: int) -> void:
	## A card tapped (its index), or the button (-1): the caller's pick.
	if not is_open() or i >= offers.size():
		return
	if _pick.is_valid():
		_pick.call(i)
	else:
		close()


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
	add_child(b)
	_buttons.append(b)
	b.set_meta("rect", r)
	return b


# ---------------------------------------------------------------- layout

func _safe() -> Rect2:
	return UI.safe_rect(get_viewport()) if is_inside_tree() else Rect2(0, 0, 844, 390)


func heading_y() -> float:
	## The heading's baseline: under the HUD's top band (hud.title_rect).
	var s := _safe()
	var band := s.position.y + 101.0
	var h = world.get("hud") if world != null else null
	if h != null and h.has_method("title_rect"):
		band = (h.title_rect() as Rect2).end.y
	return band + 22.0


func rects() -> Array:
	## Where each card is (the pair's two slots, or one per offer).
	return layout(_safe(), heading_y() + 12.0, offers.size(), pair)


static func layout(s: Rect2, top: float, n: int, two_up := false) -> Array:
	## The cards' rects under `top`, centred across the safe area s: the
	## Descent's two 220 x 140 slots (two_up), else n of 200 x 150 (narrower
	## if three wouldn't fit), 16 px apart.
	var c := s.get_center()
	if two_up:
		return [Rect2(c.x - PAIR_GAP * 0.5 - PAIR_W, top, PAIR_W, PAIR_H), Rect2(c.x + PAIR_GAP * 0.5, top, PAIR_W, PAIR_H)]
	var k := clampi(n, 1, MAX)
	var w := minf(W, (s.size.x - 8.0 - GAP * (MAX - 1)) / MAX)
	var total := k * w + (k - 1) * GAP
	var out: Array = []
	for i in k:
		out.append(Rect2(c.x - total * 0.5 + i * (w + GAP), top, w, H))
	return out


func button_rect() -> Rect2:
	## The button under the cards (tests): where it is now.
	return _later_btn.get_rect() if _later_btn != null and is_instance_valid(_later_btn) else Rect2()


func _layout_buttons() -> void:
	var rs := rects()
	for b in _buttons:
		if not is_instance_valid(b):
			continue
		if (b as Button).has_meta("rect"):
			var rr: Rect2 = b.get_meta("rect")
			b.position = rr.position
			b.size = rr.size
	if _later_btn == null or not is_instance_valid(_later_btn) or rs.is_empty():
		return
	_later_btn.reset_size()
	var y: float = (rs[0] as Rect2).end.y + 6.0
	_later_btn.position = Vector2(_safe().get_center().x - _later_btn.size.x * 0.5, y + (50.0 - _later_btn.size.y) * 0.5)


func _process(dt: float) -> void:
	if not is_open():
		return
	_t += dt
	_layout_buttons()
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not is_open():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.05, 0.7))
	var s := _safe()
	if heading != "":
		UI.text(self, Vector2(s.position.x, heading_y()), heading, 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 4)
	var rs := rects()
	for i in mini(offers.size(), rs.size()):
		_draw_offer(offers[i], rs[i])


func _draw_offer(o: Dictionary, r: Rect2) -> void:
	var pop := clampf(_t / 0.2, 0.0, 1.0)
	var rr := r.grow(-6.0 * (1.0 - pop))
	UI.panel(self, rr, UI.GOLD, FILL, 14.0)
	var col: Color = o.get("col", UI.EMBER)
	var name := str(o.get("name", ""))
	var text := str(o.get("text", ""))
	var sub := str(o.get("sub", ""))
	if pair:
		# The Descent's Glimmer, as it always was: one line of 14 under the
		# name (two of 13 should a long one come).
		UI.glyph(self, str(o.get("glyph", "star")), rr.position + Vector2(rr.size.x * 0.5, 36.0), 32.0, col)
		UI.text(self, rr.position + Vector2(0, 78.0), name, 19, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, "title", 700)
		var long := UI.text_width(text, 14) > rr.size.x - 8.0
		if not long:
			UI.text(self, rr.position + Vector2(0, 101.0), text, 14, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		else:
			var two := UI.wrap(text, rr.size.x - 16.0, 13)
			for i in mini(two.size(), 2):
				UI.text(self, rr.position + Vector2(0, 96.0 + i * 15.0), str(two[i]), 13, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		UI.text(self, rr.position + Vector2(0, 128.0 if long else 124.0), sub, 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
	else:
		# A skill: its mark, its name, what it does (up to three lines of 13,
		# centred between the name and the rank line) and the rank line.
		UI.glyph(self, str(o.get("glyph", "star")), rr.position + Vector2(rr.size.x * 0.5, 32.0), 28.0, col)
		var w := rr.size.x - 16.0
		UI.text(self, rr.position + Vector2(8.0, 70.0), name, UI.fit_size(name, w, 18, 13, "title", 700), UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w, "title", 700)
		var lines := UI.wrap(text, w, 13)
		var n := mini(lines.size(), 3)
		for i in n:
			UI.text(self, rr.position + Vector2(8.0, 92.0 + (3 - n) * 8.0 + i * 16.0), str(lines[i]), 13, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, w)
		UI.text(self, rr.position + Vector2(8.0, rr.size.y - 10.0), sub, UI.fit_size(sub, w, 11, 9, "body", 700), UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w, "body", 700)
	if bool(o.get("new", false)):
		# NEW: a gold tag on its shoulder.
		var tw := UI.text_width("NEW", 10, "body", 800) + 12.0
		var tag := Rect2(rr.end.x - tw - 8.0, rr.position.y + 8.0, tw, 16.0)
		var sb := UI.box()
		sb.bg_color = UI.GOLD
		sb.set_corner_radius_all(8)
		sb.draw(get_canvas_item(), tag)
		UI.text(self, Vector2(tag.position.x, tag.position.y + 12.0), "NEW", 10, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, "body", 800)
