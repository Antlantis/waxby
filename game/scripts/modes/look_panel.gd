extends Control
## The Sheet's Look tab (spec §7.5; hero_screen.gd's PANEL_PATH["look"]): the
## hero standing in candlelight, twice size, wearing the look chosen, and the
## fifteen flames as swatches, each a little candle flame in its colours.
## Tap an owned one to wear it (Game.set_look); a locked one shows what earns
## it; a new one wears a gold dot until the tab has been open. Cape trims and
## weapon glows (P2) come with their art and the rig's cape_trim part.
## Nothing here changes a number, and the hero's light is never tinted.

const UI := preload("res://scripts/ui.gd")
const Cosmetics := preload("res://scripts/modes/cosmetics.gd")
const ModesSave := preload("res://scripts/modes/modes_save.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const RIG := "res://scripts/wick_rig.gd"
const PLAYER := "res://scripts/player.gd"
const SW := 40.0                  # a swatch
const GAP := 8.0
const LEFT_W := 280.0

var host: Control
var shown := ""                   # the swatch last tapped (its name and source show below)
var _t := 0.0
var _holder: Node2D
var _rig: Node2D
var _tb := TriBatch.new()
var _flash := 0.0


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	var g := _game()
	if g != null and g.has_method("grant_story_cosmetics"):
		g.grant_story_cosmetics()   # (a save that saw homecoming before the flame was paid there)
	var cls := str(g.hero_id()) if g != null else "knight"
	_holder = Node2D.new()
	_holder.name = "Wick"
	add_child(_holder)
	var fake = load(PLAYER).new()
	fake.on_floor = true
	fake.hurt_time = 10.0
	fake.facing = 1
	_rig = load(RIG).new()
	_rig.cls = cls
	_rig.player = fake
	_holder.add_child(fake)
	_holder.add_child(_rig)
	_holder.scale = Vector2(2.0, 2.0)
	shown = "flame:" + worn()


func _exit_tree() -> void:
	## The flames were seen: their gold dots go.
	var g := _game()
	if g == null:
		return
	var m = g.modes().get("cosmetics", {})
	if m is Dictionary and m.get("new") is Array:
		var before: int = (m["new"] as Array).size()
		m["new"] = (m["new"] as Array).filter(func(n): return not str(n).begins_with("flame:"))
		if (m["new"] as Array).size() != before:
			g.save()


func worn() -> String:
	var g := _game()
	if g == null:
		return "tallow"
	return str(Cosmetics.look_of({"look": g.look()}, func(n): return g.has_cosmetic(n))["flame"])


func owns(nid: String) -> bool:
	var g := _game()
	return g != null and bool(g.has_cosmetic(nid))


func is_new(nid: String) -> bool:
	var g := _game()
	if g == null:
		return false
	var m = g.modes().get("cosmetics", {})
	return m is Dictionary and m.get("new") is Array and (m["new"] as Array).has(nid)


func source_line(nid: String) -> String:
	## What a locked swatch wants, or "Deeper down" where this build can't
	## pay it (a boss, the ending, a Descent depth it hasn't got).
	if ModesSave.source_reachable(Cosmetics.source_of(nid), _game()):
		return Cosmetics.source_text(nid)
	return Cosmetics.DEEPER


func swatch_rects() -> Array:
	var x0 := LEFT_W + 24.0
	var room := size.x - x0 - 10.0
	var per := maxi(int((room + GAP) / (SW + GAP)), 1)
	var out: Array = []
	for i in Cosmetics.FLAME_ORDER.size():
		out.append(Rect2(x0 + (i % per) * (SW + GAP), 36.0 + (i / per) * (SW + GAP + 6.0), SW, SW))
	return out


func tap(i: int) -> void:
	var id: String = Cosmetics.FLAME_ORDER[i]
	var nid := "flame:" + id
	shown = nid
	var g := _game()
	var s := get_node_or_null("/root/Sfx")
	if owns(nid) and g != null:
		g.set_look("flame", id)
		_flash = 0.4
		if s != null:
			s.play("select")
		if host != null and host.has_method("notify_changed"):
			host.notify_changed()
	elif s != null:
		s.play("back")


func _gui_input(event: InputEvent) -> void:
	if not UI.is_tap(event):
		return
	var pos: Vector2 = (event as InputEventMouseButton).position
	var rs := swatch_rects()
	for i in rs.size():
		if (rs[i] as Rect2).grow(3.0).has_point(pos):
			tap(i)
			accept_event()
			return


func _process(dt: float) -> void:
	_t += dt
	_flash = maxf(_flash - dt, 0.0)
	_holder.position = Vector2(LEFT_W * 0.5, size.y - 40.0)
	queue_redraw()


func _draw() -> void:
	# Candlelight pooled where he stands.
	var c := Vector2(LEFT_W * 0.5, size.y - 60.0)
	var fl := 1.0 + 0.03 * sin(_t * 11.0)
	for i in 3:
		_tb.circle(c, (150.0 - i * 40.0) * fl, Color(1.0, 0.7, 0.35, 0.04 + 0.03 * i), 28)
	_tb.flush(self)
	# His flame in its colours (the rig's own flame point, twice size).
	var fid := worn()
	var fp: Vector2 = (_rig.flame_point() - global_position) if _rig != null else c
	UI.flame(self, fp, 19.0 * 2.0 * (1.0 + _flash * 0.3), _t, 0.0, false, 1.0, true, Cosmetics.palette(fid, _t))
	UI.text(self, Vector2(0, 22.0), str(Cosmetics.FLAMES[fid]["name"]), 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, LEFT_W, "title", 700)
	# The swatches.
	UI.text(self, Vector2(LEFT_W + 24.0, 24.0), "Flame", 15, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	var rs := swatch_rects()
	for i in rs.size():
		var id: String = Cosmetics.FLAME_ORDER[i]
		var nid := "flame:" + id
		var r: Rect2 = rs[i]
		var own := owns(nid)
		var on := id == fid
		UI.panel(self, r, UI.GOLD if on else (UI.PANEL_EDGE if own else Color("30283e")), Color("1a1426") if own else Color("120d1a"), 8.0)
		UI.flame(self, r.position + Vector2(r.size.x * 0.5, r.size.y - 6.0), 24.0, _t, i * 1.3, false, 1.0 if own else 0.28, false, Cosmetics.palette(id, _t))
		if not own:
			UI.glyph(self, "lock", r.position + Vector2(r.size.x - 9.0, r.size.y - 9.0), 11.0, Color(UI.MUTED, 0.85))
		if is_new(nid):
			_tb.circle(r.position + Vector2(r.size.x - 5.0, 5.0), 4.5, UI.GOLD, 10)
	_tb.flush(self)
	# What's shown: its name, and what earns it.
	if shown != "":
		var e := Cosmetics.entry(shown)
		var y := (rs[rs.size() - 1] as Rect2).end.y + 28.0
		var line := str(e.get("name", ""))
		if not owns(shown):
			line += " · " + source_line(shown)
		elif shown == "flame:" + fid:
			line += " · worn"
		UI.text(self, Vector2(LEFT_W + 24.0, y), line, 14, UI.CREAM if owns(shown) else UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, size.x - LEFT_W - 34.0)
	UI.text(self, Vector2(LEFT_W + 24.0, size.y - 12.0), "Looks never change your numbers.", 11, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, size.x - LEFT_W - 34.0)
