extends Control
## The Sheet's Gear tab: Waxby drawn large with his five slots round him
## (weapon, candle, coat; boots, charm). Tap a slot for the satchel's items
## that fit it, best first (by Items.power), each with its DMG and LIFE chips
## against what's worn (Hero.compare). Tap one to see the two side by side,
## then Equip or Salvage it. "Salvage all below equipped" clears out every
## item that would make nothing better (never a Legendary), after a second tap.
## v3: where boots and charms turn up only deeper down (Items.live_slots), an
## empty slot not yet in reach says where: "Turns up in World 3" (boots) or
## "World 4" (charms).

const UI := preload("res://scripts/ui.gd")
const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const Classes := preload("res://scripts/classes.gd")
const GlowScript := preload("res://scripts/glow.gd")

const LEFT_SLOTS := ["weapon", "candle", "coat"]
const RIGHT_SLOTS := ["boots", "charm"]

var host: Control
var slot := "weapon"
var picked = null                 # the satchel item being compared, or null
var _holder: Node2D
var _rig: Node2D
var _glow: Node2D
var _scroll: ScrollContainer
var _list: VBoxContainer
var _equip_btn: Button
var _salvage_btn: Button
var _cancel_btn: Button
var _bulk_btn: Button
var _bulk_confirm := 0.0
var _below_n := 0                 # how many items salvage-all would take (counted on rebuild)
var _note := ""
var _note_t := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_make_rig()
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_equip_btn = UI.make_button("Equip", true, func(): equip_picked(), "", 16)
	_salvage_btn = UI.make_button("Salvage", false, func(): salvage_picked(), "", 15)
	_cancel_btn = UI.make_button("Back", false, func(): pick(null), "back", 15)
	_bulk_btn = UI.make_button("Salvage all below equipped", false, func(): _bulk_pressed(), "click", 13)
	for b in [_equip_btn, _salvage_btn, _cancel_btn, _bulk_btn]:
		UI.small_button(b, b.get_theme_font_size("font_size"))
		b.custom_minimum_size = Vector2(0, UI.TAP_H)
		add_child(b)
	_rebuild()


func _make_rig() -> void:
	## Waxby himself, standing on the left in the candlelight, in his calling.
	if _holder:
		_holder.queue_free()
	_holder = Node2D.new()
	_holder.name = "Hero"
	add_child(_holder)
	var fake = preload("res://scripts/player.gd").new()
	fake.on_floor = true
	fake.hurt_time = 10.0
	_rig = preload("res://scripts/wick_rig.gd").new()
	_rig.cls = _cls()
	_rig.player = fake
	_holder.add_child(fake)
	_holder.add_child(_rig)
	_holder.scale = Vector2(2.3, 2.3)
	if _glow == null:
		_glow = GlowScript.new()
		add_child(_glow)
	move_child(_glow, get_child_count() - 1)


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _hero() -> Dictionary:
	var g := _game()
	return g.hero() if g else Hero.blank()


func _cls() -> String:
	return str(_hero().get("cls", "knight"))


func _stats_args() -> Array:
	var g := _game()
	return [_hero().get("belt", []), g.diff() if g else "dusk"]


func chips(it) -> Dictionary:
	var a := _stats_args()
	return Hero.compare(_hero(), str(it["slot"]), it, a[0], a[1])


func items_for(s: String) -> Array:
	## The satchel's items for a slot, the most powerful first.
	var out: Array = []
	for it in _hero().get("satchel", []):
		if it is Dictionary and str(it.get("slot", "")) == s:
			out.append(it)
	out.sort_custom(func(a, b): return Items.power(a) > Items.power(b))
	return out


func slot_waits(s: String) -> int:
	## The world an empty slot's first piece turns up in (Items.live_slots at
	## the hero's deepest area), or 0 when it drops already (or is filled).
	if _hero().get("equip", {}).get(s) is Dictionary:
		return 0
	var g := _game()
	if g != null and g.diff() != "dusk":
		return 0
	var area := maxi(int(_hero().get("deepest", 0)), 1)
	if Items.live_slots(area).has(s):
		return 0
	var from: int = Items.BOOTS_FROM if s == "boots" else Items.CHARM_FROM
	# The world whose levels first reach that area (World 3 for boots, 4 for charms).
	for info in Game.ALL_LEVELS:
		if int(Game.area_of(str(info["id"]))) >= from:
			return int(info["world"])
	return 3 if s == "boots" else 4


func waits_text(s: String) -> String:
	var w := slot_waits(s)
	return "Turns up in World %d" % w if w > 0 else ""


func below_equipped() -> Array:
	## Satchel items that would make nothing better than what's worn (never a
	## Legendary): Game.weaker_items(), the same list the Chandler melts.
	var g := _game()
	return g.weaker_items() if g else []


func select_slot(s: String) -> void:
	slot = s
	picked = null
	_rebuild()


func pick(it) -> void:
	picked = it
	_rebuild()


func equip_picked() -> bool:
	var g := _game()
	if g == null or not (picked is Dictionary):
		return false
	g.equip(picked)
	_say("Wearing %s" % picked["name"])
	picked = null
	_sfx("equip")
	_make_rig()
	_changed()
	return true


func salvage_picked() -> int:
	var g := _game()
	if g == null or not (picked is Dictionary):
		return 0
	var v: int = g.salvage(picked)
	_say("Salvaged for %d embers" % v)
	picked = null
	_sfx("salvage")
	_changed()
	return v


func salvage_below() -> int:
	## Salvages every item below what's worn; returns the embers.
	var g := _game()
	if g == null:
		return 0
	var n := below_equipped().size()
	var total: int = g.salvage_weaker()
	_bulk_confirm = 0.0
	if n > 0:
		_say("Salvaged %d item%s for %d embers" % [n, "" if n == 1 else "s", total])
		_sfx("salvage")
		_changed()
	return total


func _bulk_pressed() -> void:
	if _bulk_confirm > 0.0:
		salvage_below()
	else:
		_bulk_confirm = 3.0


func _changed() -> void:
	_rebuild()
	if host and host.has_method("notify_changed"):
		host.notify_changed()


func _say(s: String) -> void:
	_note = s
	_note_t = 2.5


func _sfx(name: String) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s and name != "":
		s.play(name)


# ---------------------------------------------------------------- layout

func _left() -> Rect2:
	return Rect2(0, 4, minf(size.x * 0.4, 300.0), size.y - 8.0)


func _right() -> Rect2:
	var L := _left()
	return Rect2(L.end.x + 10.0, 4, size.x - L.end.x - 10.0, size.y - 8.0)


func slot_rects() -> Dictionary:
	var L := _left()
	var out := {}
	var tile := 58.0
	var gap := (L.size.y - 38.0 - tile * 3.0) / 2.0
	for i in LEFT_SLOTS.size():
		out[LEFT_SLOTS[i]] = Rect2(L.position.x + 10.0, L.position.y + 12.0 + i * (tile + gap), tile, tile)
	for i in RIGHT_SLOTS.size():
		out[RIGHT_SLOTS[i]] = Rect2(L.end.x - tile - 10.0, L.position.y + 12.0 + (i + 0.5) * (tile + gap), tile, tile)
	return out


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	if picked == null:
		var items := items_for(slot)
		for it in items:
			_list.add_child(_row(it))
	_below_n = below_equipped().size()
	_bulk_btn.visible = picked == null and _below_n > 0
	queue_redraw()


func _row(it: Dictionary) -> Control:
	## One satchel item: a flat button drawn by hand.
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("item", it)
	var c := chips(it)
	var icon := UI.item_icon(it)
	b.draw.connect(func(): _draw_row(b, it, c, icon))
	b.pressed.connect(func():
		_sfx("click")
		pick(it))
	return b


func _draw_row(b: Button, it: Dictionary, c: Dictionary, icon: Texture2D) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	var col := UI.rarity_color(str(it["rarity"]))
	var hover := b.is_hovered() or b.button_pressed
	UI.panel(b, r.grow(-1.0), Color(col, 0.55 if not hover else 0.9), Color("241b30") if not hover else Color("2e2440"), 9.0)
	var ic := Vector2(24.0, r.get_center().y)
	b.draw_circle(ic, 17.0, Color(col, 0.12))
	if icon:
		b.draw_texture_rect(icon, Rect2(ic - Vector2(16, 16), Vector2(32, 32)), false)
	else:
		UI.glyph(b, UI.slot_glyph(str(it["slot"])), ic, 22.0, col)
	var cw := UI.chip_width("DMG", float(c["dmg"]), 11) + UI.chip_width("LIFE", float(c["life"]), 11) + 16.0
	var tw := r.size.x - 50.0 - cw
	var name := str(it["name"])
	UI.text(b, Vector2(48.0, 20.0), name, UI.fit_size(name, tw, 15, 11, "body", 700), col, HORIZONTAL_ALIGNMENT_LEFT, tw, "body", 700)
	UI.text(b, Vector2(48.0, 37.0), "Power %d · item level %d" % [Items.power(it), int(it["ilvl"])], 11, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, tw)
	var x := r.end.x - cw + 4.0
	x += UI.chip(b, Vector2(x, r.get_center().y - 9.0), "DMG", float(c["dmg"]), 11) + 5.0
	UI.chip(b, Vector2(x, r.get_center().y - 9.0), "LIFE", float(c["life"]), 11)


func _gui_input(event: InputEvent) -> void:
	var tapped := UI.is_tap(event)   # one tap, once (not its touch twin too)
	if not tapped:
		return
	var R := slot_rects()
	for s in R:
		if (R[s] as Rect2).grow(4.0).has_point(event.position):
			if s != slot or picked != null:
				_sfx("click")
				select_slot(s)
			accept_event()
			return


func _process(dt: float) -> void:
	_t += dt
	_note_t = maxf(_note_t - dt, 0.0)
	_bulk_confirm = maxf(_bulk_confirm - dt, 0.0)
	var L := _left()
	var R := _right()
	_holder.position = Vector2(L.get_center().x, L.end.y - 30.0)
	if _rig and _glow:
		var fs: float = float(Classes.info(_cls())["flame_scale"])
		_glow.extra_flames = [{"p": _rig.flame_point() - global_position, "h": 19.0 * fs * _holder.scale.x}]
	_scroll.position = R.position + Vector2(10, 52)
	_scroll.size = Vector2(R.size.x - 20.0, R.size.y - 62.0)
	_scroll.visible = picked == null
	for w in _list.get_children():
		w.custom_minimum_size.x = _scroll.size.x - 8.0
	var comparing := picked != null
	for b in [_equip_btn, _salvage_btn, _cancel_btn]:
		b.visible = comparing
	if comparing:
		_equip_btn.custom_minimum_size = Vector2(110, UI.TAP_H)
		_salvage_btn.text = "Salvage  +%d" % Items.salvage_value(picked)
		var y := R.end.y - 48.0
		_cancel_btn.reset_size()
		_cancel_btn.position = Vector2(R.position.x + 12.0, y)
		_equip_btn.reset_size()
		_equip_btn.position = Vector2(R.end.x - _equip_btn.size.x - 12.0, y)
		_salvage_btn.reset_size()
		_salvage_btn.position = Vector2(_equip_btn.position.x - _salvage_btn.size.x - 10.0, y)
	_bulk_btn.text = "Tap again: salvage %d" % _below_n if _bulk_confirm > 0.0 else "Salvage all below equipped"
	_bulk_btn.reset_size()
	_bulk_btn.position = Vector2(R.end.x - _bulk_btn.size.x - 10.0, R.position.y + 10.0)
	queue_redraw()


func _draw() -> void:
	var L := _left()
	var R := _right()
	var cls := _cls()
	var col := UI.class_color(cls)
	UI.panel(self, L, Color(col, 0.45), Color(UI.PANEL, 0.9), 12.0)
	# Candlelight pooled where he stands.
	var feet := Vector2(L.get_center().x, L.end.y - 30.0)
	for i in 3:
		draw_circle(feet + Vector2(0, -60), 110.0 - i * 30.0, Color(1.0, 0.72, 0.35, 0.04 + 0.025 * i))
	draw_colored_polygon(_ellipse(feet + Vector2(0, 3), 56.0, 9.0), Color(0, 0, 0, 0.35))
	var eq: Dictionary = _hero().get("equip", {})
	var R2 := slot_rects()
	for s in R2:
		_tile(s, R2[s], eq.get(s))
	UI.panel(self, R, Color(UI.PANEL_EDGE, 0.8), Color(UI.PANEL, 0.9), 12.0)
	if picked == null:
		_draw_list_head(R, eq.get(slot))
	else:
		_draw_compare(R, eq.get(slot), picked)
	if _note_t > 0.0:
		var a := clampf(_note_t * 2.0, 0.0, 1.0)
		UI.text(self, Vector2(R.position.x, R.end.y + 0.0 - 6.0), _note, 13, Color(UI.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, R.size.x, "body", 700, 3)


func _tile(s: String, r: Rect2, it) -> void:
	var has: bool = it is Dictionary
	var col := UI.rarity_color(str(it["rarity"])) if has else UI.PANEL_EDGE
	var sel := s == slot
	if sel:
		draw_rect(r.grow(5.0), Color(UI.GOLD, 0.16))
	UI.panel(self, r, Color(UI.GOLD, 0.95) if sel else Color(col, 0.8 if has else 0.45), Color("241b30") if has else Color("17111f"), 10.0)
	if has:
		var icon := UI.item_icon(it)
		if icon:
			draw_texture_rect(icon, r.grow(-6.0), false)
		else:
			UI.glyph(self, UI.slot_glyph(s), r.get_center(), 30.0, col)
	else:
		# Nothing worn: the slot's own art, as a dark silhouette.
		var ghost := UI.tex(UI.empty_slot_icon_path(s, _cls()))
		var wait := slot_waits(s)
		var ga := 0.2 if wait > 0 else 0.32
		if ghost:
			draw_texture_rect(ghost, r.grow(-9.0), false, Color(0.42, 0.38, 0.52, ga))
		else:
			UI.glyph(self, UI.slot_glyph(s), r.get_center(), 26.0, Color(UI.MUTED, ga))
		if wait > 0:
			# Not yet in reach: the world it turns up in, in that world's colour.
			var acc := UI.world_accent(wait)
			var cr := Rect2(r.position.x + 3.0, r.end.y - 17.0, r.size.x - 6.0, 14.0)
			var sb := UI.box()
			sb.bg_color = Color(UI.INK, 0.85)
			sb.border_color = Color(acc, 0.6)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(7)
			sb.draw(get_canvas_item(), cr)
			UI.text(self, Vector2(cr.position.x, cr.position.y + 10.5), "WORLD %d" % wait, 8, acc, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, "body", 800)
	var n := items_for(s).size()
	if n > 0:
		var bc := r.position + Vector2(r.size.x - 4.0, 4.0)
		draw_circle(bc, 9.0, UI.INK)
		draw_circle(bc, 7.5, UI.GOLD if sel else UI.PANEL_EDGE)
		UI.text(self, Vector2(bc.x - 9.0, bc.y + 4.0), str(n), 11, UI.INK if sel else UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 18.0, "body", 800)
	UI.text(self, Vector2(r.position.x - 10.0, r.end.y + 13.0), UI.SLOT_NAME[s].to_upper(), 9, Color(UI.GOLD if sel else UI.MUTED, 0.9), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20.0, "body", 800)


func _draw_list_head(R: Rect2, worn) -> void:
	var x := R.position.x + 14.0
	UI.text(self, Vector2(x, R.position.y + 22.0), UI.SLOT_NAME[slot].to_upper(), 11, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	var bw := _bulk_btn.size.x + 20.0 if _bulk_btn.visible else 0.0
	var w := R.size.x - 28.0 - bw
	if worn is Dictionary:
		var name := "Worn: %s" % worn["name"]
		UI.text(self, Vector2(x, R.position.y + 42.0), name, UI.fit_size(name, w, 16, 11, "title", 700), UI.rarity_color(str(worn["rarity"])), HORIZONTAL_ALIGNMENT_LEFT, w, "title", 700)
	elif waits_text(slot) != "":
		var wt := "%s: %s" % [waits_text(slot), str(Game.WORLD_NAMES.get(slot_waits(slot), ""))]
		UI.text(self, Vector2(x, R.position.y + 42.0), wt, UI.fit_size(wt, w, 14, 10), UI.world_accent(slot_waits(slot)), HORIZONTAL_ALIGNMENT_LEFT, w)
	else:
		UI.text(self, Vector2(x, R.position.y + 42.0), "Nothing worn here yet.", 14, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, w)
	if items_for(slot).is_empty():
		UI.text(self, Vector2(R.position.x, R.get_center().y + 10.0), "Nothing for this slot in your satchel.", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, R.size.x)


func _draw_compare(R: Rect2, worn, it: Dictionary) -> void:
	## The worn item and the candidate, side by side, with the chips.
	var half := (R.size.x - 36.0) * 0.5
	var a := Rect2(R.position.x + 12.0, R.position.y + 12.0, half, R.size.y - 72.0)
	var b := Rect2(a.end.x + 12.0, a.position.y, half, a.size.y)
	_item_card(a, worn, "Worn")
	_item_card(b, it, "This one")
	var c := chips(it)
	var x := b.position.x + 10.0
	x += UI.chip(self, Vector2(x, b.end.y - 26.0), "DMG", float(c["dmg"]), 12) + 6.0
	UI.chip(self, Vector2(x, b.end.y - 26.0), "LIFE", float(c["life"]), 12)


func _item_card(r: Rect2, it, label: String) -> void:
	var has: bool = it is Dictionary
	var col := UI.rarity_color(str(it["rarity"])) if has else UI.PANEL_EDGE
	UI.panel(self, r, Color(col, 0.7), Color("201829"), 10.0)
	UI.text(self, Vector2(r.position.x + 10.0, r.position.y + 16.0), label.to_upper(), 9, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	if not has:
		UI.text(self, Vector2(r.position.x, r.get_center().y), "Empty", 14, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return
	var ic := Vector2(r.position.x + 28.0, r.position.y + 44.0)
	draw_circle(ic, 19.0, Color(col, 0.13))
	var icon := UI.item_icon(it)
	if icon:
		draw_texture_rect(icon, Rect2(ic - Vector2(17, 17), Vector2(34, 34)), false)
	else:
		UI.glyph(self, UI.slot_glyph(str(it["slot"])), ic, 24.0, col)
	var tx := r.position.x + 54.0
	var tw := r.end.x - tx - 8.0
	var lines := UI.wrap(str(it["name"]), tw, 14, "title", 700)
	for i in mini(lines.size(), 2):
		UI.text(self, Vector2(tx, r.position.y + 40.0 + i * 15.0 - (7.0 if lines.size() > 1 else 0.0)), lines[i], 14, col, HORIZONTAL_ALIGNMENT_LEFT, tw, "title", 700)
	var y := r.position.y + 72.0
	var sub := "%s · %s · item level %d" % [Items.RARITY_NAME.get(str(it["rarity"]), ""), str(it.get("base", "")), int(it["ilvl"])]
	UI.text(self, Vector2(r.position.x + 10.0, y), sub, UI.fit_size(sub, r.size.x - 20.0, 10, 8), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0)
	y += 18.0
	for line in _lines(it):
		if y > r.end.y - 30.0:
			break
		var wl := UI.wrap(str(line[0]), r.size.x - 20.0, 12)
		for l in wl:
			if y > r.end.y - 30.0:
				break
			UI.text(self, Vector2(r.position.x + 10.0, y), l, 12, line[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0)
			y += 15.0


func _lines(it: Dictionary) -> Array:
	## [text, color] for an item's implicit, affixes and legend.
	var out: Array = []
	var imp: Dictionary = it.get("implicit", {})
	if imp.has("id"):
		out.append([Items.describe(str(imp["id"]), float(imp["v"])), UI.CREAM])
	if imp.has("light"):
		out.append([Items.describe("light_pct", float(imp["light"])), UI.CREAM])
	if imp.has("dr") and str(imp.get("id", "")) != "dr":
		out.append([Items.describe("dr", float(imp["dr"])), UI.CREAM])
	for a in it.get("affixes", []):
		out.append([Items.describe(str(a["id"]), float(a["v"])), UI.RARITY["magic"].lightened(0.2)])
	if str(it.get("legend", "")) != "":
		out.append([str(Items.LEGENDS.get(it["legend"], {}).get("text", "")), UI.RARITY["legendary"]])
	return out


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
