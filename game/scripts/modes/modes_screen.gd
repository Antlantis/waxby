extends Control
## The Challenges hub (spec §7.6, p_modes §9.2): three arched doors, the
## Endless Descent, the Waxworks and the Vigil Trials, each with its status
## or its seal line; a tap opens its screen (descent_screen.gd,
## waxworks_screen.gd, trials_screen.gd), whose back comes here, and this
## screen's back goes to the map (main.gd's show_modes hooks it). open(screen)
## goes straight to one ("descent" | "waxworks" | "trials").
##
## The first visit: Mother Taper's line (Hollin's while she rests); Waxley's
## on the first visit once the Waxworks is open, and the Descent's once that
## is (each line its own seen key, so one that opens later still gets said).
## A door with something new behind it wears a gold "!". The doors' lines
## and news are worked out when something changes (and each second), not
## every frame.

signal back

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/modes/mode_art.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const ModesSave := preload("res://scripts/modes/modes_save.gd")
const Cosmetics := preload("res://scripts/modes/cosmetics.gd")
const TrialData := preload("res://scripts/modes/trial_data.gd")
const DOORS := ["descent", "waxworks", "trials"]
const SUB := {"descent": "res://scripts/modes/descent_screen.gd", "waxworks": "res://scripts/modes/waxworks_screen.gd",
		"trials": "res://scripts/modes/trials_screen.gd"}
const NAMES := {"descent": "Endless Descent", "waxworks": "The Waxworks", "trials": "The Vigil Trials"}
const SEALED := {"descent": "Sealed. Something under the Hushdeep still breathes.", "waxworks": "Beat Old Tollgrave",
		"trials": "Clear the Crypt Stair"}
const DOOR_W := 230.0
const DOOR_H := 250.0

var main: Node = null
var sub: Control = null
var lines: Array = []             # the first visit's lines still to show: [{who, mood, text}]
var _t := 0.0
var _back_btn: Button
var _deny := {}                   # door -> seconds of its sealed shake
var _tb := TriBatch.new()
var _faces := {}
var _cache := {}                  # door -> {status, news, open}, refreshed by _refresh_doors
var _cache_t := 0.0


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	Art.warm()
	_back_btn = UI.make_button("Back", false, func(): _go_back(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	add_child(_back_btn)
	var g := _game()
	if g != null:
		# The ending's flame (homecoming seen) is paid here, the first look after.
		if g.has_method("seen") and bool(g.seen("homecoming")):
			for nid in Cosmetics.ids_for("story:homecoming"):
				g.grant_cosmetic(nid)
		ModesSave.mark_seen(g, "door:challenges")
		lines = intro_lines(g)
	for who in ["taper", "waxley", "hollin"]:
		for mood in ["warm", "grin", "relit"]:
			var p := UI.portrait_path(who, mood)
			if p != "":
				_faces[who] = UI.tex(p)
				break
	_refresh_doors()
	_layout()


static func intro_lines(g: Node) -> Array:
	## The hub's lines not yet said whose door is open: {key, who, text}.
	## (A save from before the keys were split said the first as hub:intro.)
	var host := "taper"
	var st = load("res://scripts/story.gd")
	if st != null and (st as Script).get_script_method_list().any(func(m): return m["name"] == "taper_resting") and bool(st.taper_resting()):
		host = "hollin"
	var out: Array = []
	if not ModesSave.seen(g, "hub:taper") and not ModesSave.seen(g, "hub:intro"):
		out.append({"key": "hub:taper", "who": host, "text": "Every calling has its lessons. Show me you've learned yours."})
	if ModesSave.waxworks_open(g) and not ModesSave.seen(g, "hub:waxley"):
		out.append({"key": "hub:waxley", "who": "waxley", "text": "And I made something. For practice! Don't laugh."})
	if ModesSave.descent_open(g) and not ModesSave.seen(g, "hub:descent"):
		out.append({"key": "hub:descent", "who": host, "text": "The stair goes down past the bells. Keep your flame close."})
	return out


func _refresh_doors() -> void:
	## Each door's line, news dot and state, for _draw.
	_cache_t = 0.0
	for d in DOORS:
		_cache[d] = {"open": door_open(d), "status": door_status(d), "news": door_news(d)}


func _go_back() -> void:
	if sub != null:
		_close_sub()
		return
	back.emit()


func open(screen: String) -> void:
	## One of the doors' screens, over the hub (its back returns here).
	if not SUB.has(screen) or not ResourceLoader.exists(SUB[screen]):
		return
	if sub != null:
		sub.queue_free()
	var g := _game()
	var first := g != null and not ModesSave.seen(g, "door:" + screen)
	ModesSave.mark_seen(g, "door:" + screen)
	lines = []   # any line not yet tapped away is said on the next visit
	sub = load(SUB[screen]).new()
	if "main" in sub:
		sub.main = main
	if sub.has_signal("back"):
		sub.connect("back", _close_sub)
	add_child(sub)
	_back_btn.visible = false
	if first:
		_door_scene(screen)


func _door_scene(screen: String) -> void:
	## A door's first opening: its story beat (story.gd's waxworks_open,
	## trials_open or descent_open, Hollin's while Mother Taper rests), when
	## the story has it.
	var st = load("res://scripts/story.gd")
	var cs = load("res://scripts/cutscene.gd")
	if st == null or cs == null:
		return
	var id := "%s_open" % screen
	if (st as Script).get_script_method_list().any(func(m): return m["name"] == "rest_sub"):
		id = str(st.rest_sub(id))
	var g := _game()
	if st.has_scene(id) and g != null and not bool(g.seen(id)):
		cs.play_overlay(sub, id, func(): pass)


func _close_sub() -> void:
	if sub != null:
		sub.queue_free()
		sub = null
	_back_btn.visible = true
	_refresh_doors()
	queue_redraw()


func door_open(d: String) -> bool:
	var g := _game()
	match d:
		"descent":
			return ModesSave.descent_open(g)
		"waxworks":
			return ModesSave.waxworks_open(g)
		"trials":
			return ModesSave.hub_open(g)
	return false


func door_status(d: String) -> String:
	## The line under a door: its state, or what opens it.
	var g := _game()
	if not door_open(d):
		return str(SEALED[d])
	match d:
		"descent":
			if g != null and ModesSave.resume_ember(g):
				var run: Dictionary = ModesSave.block(g)["descent"]["runs"][str(g.hero_id())]
				return "Resume · Depth %d" % int(run.get("depth", 1))
			var best := 0
			var who := ""
			if g != null:
				for cls in (ModesSave.block(g)["descent"]["best"] as Dictionary):
					for df in ModesSave.block(g)["descent"]["best"][cls]:
						var dd := int(ModesSave.block(g)["descent"]["best"][cls][df].get("depth", 0))
						if dd > best:
							best = dd
							who = str(load("res://scripts/classes.gd").info(cls)["name"])
			return "Best: depth %d · %s" % [best, who] if best > 0 else "The Hush dreams"
		"waxworks":
			var casts := ModesSave.open_casts(g).size()
			var golds := 0
			for b in ModesSave.BOSSES:
				if ModesSave.best_seal(g, b) >= 3:
					golds += 1
			# Out of the casts this build has, as the map counts its levels.
			return "%d of %d cast · %d Gold seal%s" % [casts, ModesSave.built_casts().size(), golds, "" if golds == 1 else "s"]
		"trials":
			var opened := 0
			var gold := 0
			for id in TrialData.ORDER:
				if TrialData.built(id) and ModesSave.trial_open(g, TrialData.number(id)):
					opened += 1
				if int(ModesSave.trial_rec(g, id).get("medal", 0)) >= 3:
					gold += 1
			return "%d of %d open · %d Gold" % [opened, ModesSave.built_trials().size(), gold]
	return ""


func door_news(d: String) -> bool:
	var g := _game()
	for k in ModesSave.news_keys(g):
		var key: String = k
		if d == "descent" and key == "door:descent":
			return true
		if d == "waxworks" and (key == "door:waxworks" or key.begins_with("cast:")):
			return true
		if d == "trials" and key.begins_with("trial:"):
			return true
	return false


func door_rects() -> Array:
	## Three doors centred at 1/6, 1/2 and 5/6 of the safe width.
	var s := UI.safe_rect(get_viewport())
	var w := minf(DOOR_W, s.size.x / 3.0 - 14.0)
	var top := s.position.y + 58.0
	var h := minf(DOOR_H, s.end.y - top - 8.0)
	var out: Array = []
	for i in 3:
		var cx := s.position.x + s.size.x * (1.0 + 2.0 * i) / 6.0
		out.append(Rect2(cx - w * 0.5, top, w, h))
	return out


func _layout() -> void:
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and _back_btn != null:
		_layout()


func _process(dt: float) -> void:
	_t += dt
	for k in _deny.keys():
		_deny[k] = float(_deny[k]) - dt
		if float(_deny[k]) <= 0.0:
			_deny.erase(k)
	_cache_t += dt
	if _cache_t >= 1.0:
		_refresh_doors()
	_layout()
	queue_redraw()


func tap_door(i: int) -> void:
	var d: String = DOORS[i]
	if not door_open(d):
		_deny[d] = 0.5
		_sfx("back")
		return
	_sfx("select")
	open(d)


func _gui_input(event: InputEvent) -> void:
	if sub != null or not UI.is_tap(event):
		return
	var pos: Vector2 = (event as InputEventMouseButton).position
	if not lines.is_empty():
		var l: Dictionary = lines.pop_front()
		ModesSave.mark_seen(_game(), str(l.get("key", "hub:taper")))
		accept_event()
		return
	var rs := door_rects()
	for i in rs.size():
		if (rs[i] as Rect2).has_point(pos):
			tap_door(i)
			accept_event()
			return


func _sfx(n: String) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s != null:
		s.play(n)


func _draw() -> void:
	var vs := get_size()
	UI.backdrop(self, vs)
	if sub != null:
		return
	var s := UI.safe_rect(get_viewport())
	var g := _game()
	UI.text(self, Vector2(s.position.x, s.position.y + 28.0), "Challenges", 25, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 4)
	UI.text(self, Vector2(s.position.x, s.position.y + 46.0), "Beyond the bells", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x)
	# The ember purse.
	if g != null:
		var e := str(int(g.embers()))
		var ew := UI.text_width(e, 16, "body", 700)
		UI.ember_icon(self, Vector2(s.end.x - ew - 22.0, s.position.y + 20.0), 9.0)
		UI.text(self, Vector2(s.end.x - ew - 8.0, s.position.y + 26.0), e, 16, UI.EMBER, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	# In three passes, so a batch never covers what should be on top of it:
	# the arches; the pictures in them; the names, lines and news dots.
	var rs := door_rects()
	for i in 3:
		_draw_arch(DOORS[i], _door_body(DOORS[i], rs[i]))
	_tb.flush(self)
	for i in 3:
		_draw_icon(DOORS[i], _door_body(DOORS[i], rs[i]))
	_tb.flush(self)
	var marks: Array = []
	for i in 3:
		marks.append(_draw_words(DOORS[i], _door_rect(DOORS[i], rs[i])))
	_tb.flush(self)
	for np in marks:
		if np is Vector2:
			UI.text(self, (np as Vector2) + Vector2(-10.0, 5.5), "!", 15, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, 20.0, "body", 800)
	if not lines.is_empty():
		_draw_line(lines[0])


func _door_rect(d: String, r0: Rect2) -> Rect2:
	var shake := sin(_t * 60.0) * 5.0 * float(_deny.get(d, 0.0)) / 0.5 if _deny.has(d) else 0.0
	return Rect2(r0.position + Vector2(shake, 0), r0.size)


func _door_body(d: String, r0: Rect2) -> Rect2:
	var r := _door_rect(d, r0)
	return Rect2(r.position.x + 8.0, r.position.y + 8.0, r.size.x - 16.0, r.size.y - 60.0)


func _open_cached(d: String) -> bool:
	return bool((_cache[d] as Dictionary).get("open", false)) if _cache.has(d) else door_open(d)


func _draw_arch(d: String, body: Rect2) -> void:
	## The arch: its rim, then the dark inside.
	var is_open := _open_cached(d)
	Art.arch(_tb, body.position.x - 5.0, body.size.x + 10.0, body.position.y - 5.0, body.end.y + 5.0, Color(UI.PANEL_EDGE, 0.9) if is_open else Color("2a2238"))
	Art.arch(_tb, body.position.x, body.size.x, body.position.y, body.end.y, Color("140e1e") if is_open else Color("0c0812"))


func _draw_icon(d: String, body: Rect2) -> void:
	var is_open := _open_cached(d)
	var a := 1.0 if is_open else 0.3
	var c := Vector2(body.get_center().x, body.end.y - body.size.y * 0.38)
	match d:
		"descent":
			# A stair spiralling down into the dark, one flame on it.
			for k in 9:
				var ang := _t * 0.3 + k * 0.7
				var rr := 40.0 - k * 3.6
				var p := c + Vector2(cos(ang) * rr, k * 6.0 - 20.0 + sin(ang) * rr * 0.3)
				draw_rect(Rect2(p - Vector2(9.0 - k * 0.6, 2.5), Vector2(18.0 - k * 1.2, 5.0)), Color(UI.PANEL_EDGE, (0.9 - k * 0.08) * a))
			if is_open:
				UI.flame(self, c + Vector2(cos(_t * 0.3) * 40.0, -24.0 + sin(_t * 0.3) * 12.0), 12.0, _t, 0.3)
		"waxworks":
			# A wax bust on a plinth, under a bell.
			draw_rect(Rect2(c + Vector2(-24, 26), Vector2(48, 10)), Color(UI.PANEL_EDGE, a))
			draw_rect(Rect2(c + Vector2(-16, 18), Vector2(32, 9)), Color(UI.PANEL_EDGE.darkened(0.2), a))
			_tb.convex(PackedVector2Array([c + Vector2(-30, 18), c + Vector2(30, 18), c + Vector2(22, 2), c + Vector2(8, -4),
					c + Vector2(-8, -4), c + Vector2(-22, 2)]), Color(Art.WAX.darkened(0.08), 0.95 * a))
			_tb.rect(Rect2(c + Vector2(-5, -10), Vector2(10, 8)), Color(Art.WAX.darkened(0.12), 0.95 * a))
			_tb.ellipse(c + Vector2(0, -22), 11.0, 14.0, Color(Art.WAX, 0.95 * a), 16)
			Art.bell(_tb, c + Vector2(0, -62), 30.0, Color(UI.GOLD, 0.8 * a))
		"trials":
			# A candle in a ring of twelve ticks.
			for k in 12:
				var ang := TAU * k / 12.0
				_tb.line(c + Vector2(cos(ang), sin(ang)) * 38.0, c + Vector2(cos(ang), sin(ang)) * 46.0, 3.0, Color(UI.GOLD, 0.7 * a))
			draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 30)), Color(Art.TAPER, a))
			if is_open:
				UI.flame(self, c + Vector2(0, -9), 13.0, _t, 1.1)


func _draw_words(d: String, r: Rect2):
	## The door's name and line; returns where its news dot is (or null).
	var is_open := _open_cached(d)
	var cd: Dictionary = _cache.get(d, {})
	var body := Rect2(r.position.x + 8.0, r.position.y + 8.0, r.size.x - 16.0, r.size.y - 60.0)
	if not is_open:
		UI.glyph(self, "lock", Vector2(body.get_center().x, body.position.y + body.size.y * 0.3), 26.0, Color(UI.MUTED, 0.8))
	UI.text(self, Vector2(r.position.x, body.end.y + 26.0), str(NAMES[d]), 18, UI.GOLD if is_open else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "title", 700)
	var st := str(cd["status"]) if cd.has("status") else door_status(d)
	var size := UI.fit_size(st, r.size.x - 8.0, 13, 10)
	var ls := UI.wrap(st, r.size.x - 8.0, size)
	for k in mini(ls.size(), 2):
		UI.text(self, Vector2(r.position.x, body.end.y + 44.0 + k * 15.0), str(ls[k]), size, UI.CREAM if is_open else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if is_open and (bool(cd["news"]) if cd.has("news") else door_news(d)):
		var np := Vector2(body.end.x - 10.0, body.position.y + 16.0)
		_tb.circle(np, 11.0, UI.INK, 16)
		_tb.circle(np, 9.0, UI.GOLD, 16)
		return np
	return null


func _draw_line(l: Dictionary) -> void:
	## A first-visit line along the bottom: the speaker's face and words.
	var s := UI.safe_rect(get_viewport())
	var r := Rect2(s.position.x, s.end.y - 74.0, s.size.x, 66.0)
	UI.panel(self, r, UI.GOLD, Color(UI.PANEL, 0.97), 14.0)
	var who := str(l.get("who", "taper"))
	UI.portrait(self, r.position + Vector2(36, 33), 24.0, _faces.get(who), UI.speaker_color(who), 1.0, Rect2(0, 0, 1, 1), who.substr(0, 1).to_upper())
	var name := {"taper": "Mother Taper", "waxley": "Waxley", "hollin": "Hollin"}.get(who, who)
	UI.text(self, r.position + Vector2(70, 24), str(name), 14, UI.speaker_color(who), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	UI.text(self, r.position + Vector2(70, 46), str(l.get("text", "")), 15, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 84.0, "italic", 500)
	UI.text(self, r.position + Vector2(0, r.size.y - 6.0), "tap", 11, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12.0)
