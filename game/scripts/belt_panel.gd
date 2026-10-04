extends Control
## The Sheet's Belt tab: the relics Waxby carries (2 / 3 / 4 slots at level
## 1 / 5 / 10, and v3's fifth at 24 once Progression opens it) and, below,
## the codex of every relic (two rows: of six for v2's twelve, wider for
## v3's twenty): the found ones lit, the rest dark. On the map's Sheet the
## belt can be changed: tap a relic on the belt to take it off, tap one in
## the codex to put it on (into the chosen slot, else the first free one).
## Over a paused level (the host's over_level) it is only to look at: the
## belt changes between levels, and in a level a relic found with it full is
## offered at the next lit altar (world.gd open_relic). Any tap shows the
## relic.

const UI := preload("res://scripts/ui.gd")
const Relics := preload("res://scripts/relics.gd")
const Progression := preload("res://scripts/progression.gd")

static var slots_shown := 0      # tests and screenshots: lay out this many belt slots (0: Progression's)

var host: Control
var chosen := -1                  # the belt slot picked for a swap
var shown := ""                   # the relic in the info strip
var _t := 0.0
var _deny := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var b := belt()
	shown = b[0] if not b.is_empty() else ""


func _game() -> Node:
	return get_node_or_null("/root/Game")


func editable() -> bool:
	## On the map, yes; over a paused level, never (not even by a lit altar).
	return host == null or not bool(host.get("over_level"))


func belt() -> Array:
	var g := _game()
	return (g.belt() as Array).duplicate() if g else []


func slots() -> int:
	var g := _game()
	return g.belt_slots() if g else 2


func slot_count() -> int:
	## The belt slots laid out: every slot a hero can ever open (four in v2,
	## five with v3's fifth), the ones not open yet behind a lock.
	if slots_shown > 0:
		return slots_shown
	return maxi(Progression.belt_levels().size() + 1, slots())


func slot_rects() -> Array:
	var n := slot_count()
	var w := minf((size.x - 20.0 - (n - 1) * 10.0) / n, 170.0)
	var x0 := size.x * 0.5 - (n * w + (n - 1) * 10.0) * 0.5
	var out: Array = []
	for i in n:
		out.append(Rect2(x0 + i * (w + 10.0), 26.0, w, 84.0))
	return out


func codex_rects() -> Array:
	## Two rows of six, as big as fit between the belt and the info strip.
	var ids := Relics.ids()
	var cols := 6 if ids.size() <= 12 else ceili(ids.size() / 2.0)
	var y0 := 146.0
	var cell := minf(minf((size.x - 20.0) / cols, 62.0), (size.y - y0 - 58.0) * 0.5 + 2.0)
	var x0 := size.x * 0.5 - cols * cell * 0.5
	var out: Array = []
	for i in ids.size():
		out.append(Rect2(x0 + (i % cols) * cell + 4.0, y0 + (i / cols) * (cell - 2.0), cell - 8.0, cell - 8.0))
	return out


static func opens_at(i: int) -> int:
	## The hero level that opens belt slot i (0-based): Progression's 5 and 10.
	for l in range(1, Progression.CAP + 1):
		if Progression.belt_slots(l) > i:
			return l
	# Past every slot open today: v3's fifth, at FIFTH_BELT, once it's on.
	return int(Progression.FIFTH_BELT) if i == Progression.BELT_AT.size() + 1 else Progression.CAP


func tap_slot(i: int) -> void:
	var b := belt()
	if i >= slots():
		_deny = 1.0
		_sfx("back")
		return
	if i < b.size():
		shown = b[i]
	if not editable():
		chosen = -1
		return
	if i < b.size():
		# Take it off.
		b.remove_at(i)
		_put(b)
		chosen = i
		_sfx("click")
	else:
		chosen = i
		_sfx("click")


func tap_relic(id: String) -> void:
	var g := _game()
	shown = id
	if g == null or not g.has_relic(id) or not editable():
		_sfx("click")
		return
	var b := belt()
	if b.has(id):
		b.erase(id)
		_put(b)
		_sfx("click")
		return
	if b.size() < slots():
		var at := clampi(chosen if chosen >= 0 else b.size(), 0, b.size())
		b.insert(at, id)
		chosen = -1
		_put(b)
		_sfx("select")
	else:
		_deny = 1.0
		_sfx("back")


func _put(ids: Array) -> void:
	var g := _game()
	if g:
		g.set_belt(ids)
	if host and host.has_method("notify_changed"):
		host.notify_changed()


func _sfx(name: String) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s:
		s.play(name)


func _gui_input(event: InputEvent) -> void:
	var tapped := UI.is_tap(event)   # one tap, once (not its touch twin too)
	if not tapped:
		return
	var S := slot_rects()
	for i in S.size():
		if (S[i] as Rect2).has_point(event.position):
			tap_slot(i)
			accept_event()
			return
	var C := codex_rects()
	var ids := Relics.ids()
	for i in C.size():
		if (C[i] as Rect2).grow(3.0).has_point(event.position):
			tap_relic(ids[i])
			accept_event()
			return


func _process(dt: float) -> void:
	_t += dt
	_deny = maxf(_deny - dt * 3.0, 0.0)
	queue_redraw()


func note_text() -> String:
	## The line beside the belt's heading: how to change it here, or (over a
	## level) where it changes and what a lit altar does.
	if editable():
		return "Tap a relic to take it off or put it on."
	return "Change your belt on the map. With it full, a lit altar offers a relic you find."


func _draw() -> void:
	var g := _game()
	var b := belt()
	var n := slots()
	var ed := editable()
	var head := "Your belt · %d of %d" % [b.size(), n]
	UI.text(self, Vector2(8.0, 16.0), head.to_upper(), 11, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	var note := note_text()
	var shake := sin(_t * 60.0) * 5.0 * _deny
	var nw := size.x - 16.0 - UI.text_width(head.to_upper(), 11, "body", 800) - 16.0
	UI.text(self, Vector2(shake, 16.0), note, UI.fit_size(note, nw, 12, 10), UI.MUTED.lerp(UI.BAD, _deny) if ed else UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8.0)
	var S := slot_rects()
	for i in S.size():
		_slot(S[i], i, b, n)
	var found := 0
	for id in Relics.ids():
		if g != null and g.has_relic(id):
			found += 1
	UI.text(self, Vector2(8.0, 136.0), ("The codex · %d of %d found" % [found, Relics.ids().size()]).to_upper(), 11, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	var C := codex_rects()
	var ids := Relics.ids()
	for i in C.size():
		_codex(C[i], ids[i], g != null and g.has_relic(ids[i]), b.has(ids[i]))
	_info()


func _slot(r: Rect2, i: int, b: Array, n: int) -> void:
	if i >= n:
		UI.panel(self, r, Color("3a3148"), Color("130e1a"), 10.0)
		UI.glyph(self, "lock", r.get_center() + Vector2(0, -10), 20.0, Color(UI.MUTED, 0.45))
		UI.text(self, Vector2(r.position.x, r.get_center().y + 22.0), "Opens at level %d" % opens_at(i), 11, Color(UI.MUTED, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 700)
		return
	var sel := i == chosen
	if i >= b.size():
		UI.panel(self, r, Color(UI.GOLD, 0.9) if sel else Color(UI.PANEL_EDGE, 0.7), Color("17111f"), 10.0)
		UI.text(self, Vector2(r.position.x, r.get_center().y + 5.0), "Empty", 13, Color(UI.MUTED, 0.7), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 700)
		return
	var rel: Dictionary = Relics.get_relic(b[i])
	var col := UI.rarity_color(str(rel["rarity"]))
	UI.panel(self, r, Color(col, 0.9), Color(UI.PANEL, 0.95), 10.0)
	var ic := Vector2(r.position.x + 30.0, r.position.y + 32.0)
	draw_circle(ic, 22.0, Color(col, 0.14))
	var t := UI.relic_icon(b[i])
	if t:
		draw_texture_rect(t, Rect2(ic - Vector2(20, 20), Vector2(40, 40)), false)
	var tx := r.position.x + 58.0
	var tw := r.end.x - tx - 6.0
	var lines := UI.wrap(str(rel["name"]), tw, 14, "title", 700)
	for k in mini(lines.size(), 2):
		UI.text(self, Vector2(tx, r.position.y + 26.0 + k * 15.0), lines[k], 14, col, HORIZONTAL_ALIGNMENT_LEFT, tw, "title", 700)
	var body := UI.wrap(str(rel["text"]), r.size.x - 14.0, 11)
	for k in mini(body.size(), 2):
		UI.text(self, Vector2(r.position.x + 8.0, r.position.y + 63.0 + k * 13.0), body[k], 11, Color(UI.CREAM, 0.88), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14.0)


func _codex(r: Rect2, id: String, found: bool, worn: bool) -> void:
	var rel: Dictionary = Relics.get_relic(id)
	var col := UI.rarity_color(str(rel["rarity"]))
	var sel := id == shown
	UI.panel(self, r, Color(UI.GOLD, 0.95) if sel else (Color(col, 0.75) if found else Color("3a3148")), Color("241b30") if found else Color("120d19"), 9.0)
	var t := UI.relic_icon(id)
	if t:
		draw_texture_rect(t, r.grow(-7.0), false, Color(1, 1, 1, 1) if found else Color(0.12, 0.1, 0.16, 0.9))
	elif not found:
		UI.text(self, Vector2(r.position.x, r.get_center().y + 6.0), "?", 18, Color(UI.MUTED, 0.4), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "title", 700)
	if worn:
		var c := r.position + Vector2(r.size.x - 5.0, 5.0)
		draw_circle(c, 7.0, UI.INK)
		draw_circle(c, 5.5, UI.GOLD)
		draw_polyline(PackedVector2Array([c + Vector2(-2.5, 0), c + Vector2(-0.5, 2.2), c + Vector2(3, -2)]), UI.INK, 1.6)


func _info() -> void:
	## The chosen relic, spelled out along the bottom.
	var g := _game()
	var r := Rect2(8.0, size.y - 52.0, size.x - 16.0, 46.0)
	if shown == "":
		return
	var found: bool = g != null and g.has_relic(shown)
	var rel: Dictionary = Relics.get_relic(shown)
	var col := UI.rarity_color(str(rel["rarity"]))
	UI.panel(self, r, Color(col, 0.6) if found else Color(UI.PANEL_EDGE, 0.5), Color(UI.PANEL, 0.9), 10.0)
	if not found:
		UI.text(self, Vector2(r.position.x, r.get_center().y + 5.0), "Not found yet. Gold reliquaries hold relics; monsters drop them now and then.", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return
	var name := str(rel["name"])
	UI.text(self, Vector2(r.position.x + 14.0, r.position.y + 20.0), name, 17, col, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
	var nw := UI.text_width(name, 17, "title", 700)
	UI.text(self, Vector2(r.position.x + 22.0 + nw, r.position.y + 19.0), (Relics.RARITY_NAME[rel["rarity"]] + " relic").to_upper(), 10, Color(col, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	UI.text(self, Vector2(r.position.x + 14.0, r.position.y + 37.0), str(rel["text"]), 13, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0)
