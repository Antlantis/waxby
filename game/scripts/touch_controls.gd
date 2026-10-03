extends CanvasLayer
## The on-glass controls: left and right under the left thumb with the Tallow
## Flask above them, the jump, the attack and the calling's Special under the
## right, pause up in the corner. Several fingers at once; a finger can slide
## between left and right without lifting, and sliding the left thumb down
## holds "down" (to drop through a ledge), up holds "up" (v3: on a vine it
## climbs, as holding jump does; elsewhere it does nothing). They press the
## same input actions the keyboard does ("up" is made here if the game has
## no such action).
##
## A new touch is tested in this order: pause, the flask (a 0.2 s hold, so a
## thumb landing high doesn't drink; never from a touch that began as a
## move; a thumb sliding off it becomes a move), the pickup card while it
## takes a tap (the HUD's card_hit says; a touch near a thumb button stays
## the button's, and a thumb sliding off the card becomes a move or a
## button), then the move zone on the left or, on the right, whichever of
## jump / attack / special is nearest relative to its size. The
## button-size setting scales centres and radii together, so bigger
## buttons never overlap.
##
## The World pushes special_state (the kit's button_state()) and flask_state
## ({charges, max, drinking}) every tick. v3: special_state may carry
## {"hold_ring": 0..1} (the finale's "Hold to give your flame": a gold band
## round the Special, filling as it's held), and a flask of 2 or 3 charges
## shows one arc per charge round its rim.

signal pause_pressed

const UI := preload("res://scripts/ui.gd")
const FLASK_HOLD := 0.2
const FLASK_BADGE_R := 9.0
const SCALES := [0.9, 1.0, 1.1]
const SLIDE := 34.0               # px the left thumb slides down (down) or up (up) from where it landed

var hud: Node = null              # the HUD for pickup-card taps (else the parent World's)
var _view: Control
var _touches := {}                # index -> {role, start, pos, t, fired}
var _pressed := {"left": false, "right": false, "down": false, "up": false, "jump": false, "attack": false, "special": false, "flask": false}
var visible_controls := true
var special_state := {}           # the kit's button_state(), pushed by the World
var flask_state := {}             # {charges, max, drinking}
var button_scale := 1.0
var _special_icon := ""
var _special_tex: Texture2D
var _points := 0                  # unspent skill points: a gold "+" on pause
var _poll := 0.0
var _t := 0.0
var _flask_flash := 0.0


func _ready() -> void:
	layer = 6
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_controls)
	add_child(_view)
	if not InputMap.has_action("up"):
		InputMap.add_action("up", 0.2)
	UI.warm()
	apply_settings()


func apply_settings() -> void:
	## Re-reads the button size (the pause menu's Settings call this).
	var g := get_node_or_null("/root/Game")
	if g:
		button_scale = clampf(float(g.setting("button_scale")), 0.85, 1.1)
	_view.queue_redraw()


func _exit_tree() -> void:
	release_all()


static func layout_for(safe: Rect2, k := 1.0) -> Dictionary:
	## Button centres and radii for a safe rect and a size setting. Each thumb's
	## cluster scales about its own bottom corner.
	var b := safe.end.y
	var l := safe.position.x
	var r := safe.end.x
	return {
		"left": Vector2(l + 58.0 * k, b - 56.0 * k),
		"right": Vector2(l + 158.0 * k, b - 56.0 * k),
		"flask": Vector2(l + 108.0 * k, b - 146.0 * k),
		"attack": Vector2(r - 168.0 * k, b - 46.0 * k),
		"jump": Vector2(r - 62.0 * k, b - 64.0 * k),
		"special": Vector2(r - 140.0 * k, b - 136.0 * k),
		"pause": Vector2(r - 22.0, safe.position.y + 22.0),
		"r_move": 44.0 * k, "r_attack": 40.0 * k, "r_jump": 50.0 * k, "r_pause": 22.0,
		"r_special": 36.0 * k, "r_flask": 26.0 * k,
	}


func layout() -> Dictionary:
	return layout_for(UI.safe_rect(_view.get_viewport()), button_scale)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin(event.index, event.position)
		else:
			_end(event.index)
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			var t: Dictionary = _touches[event.index]
			t["pos"] = event.position
			if t["role"] == "card":
				_slide_off_card(t)
			_refresh()


func role_at(pos: Vector2) -> String:
	## What a touch starting here would be: pause, flask, card, move, jump,
	## attack, special, or "" (nothing).
	var L := layout()
	var vs := _view.get_size()
	if pos.distance_to(L["pause"]) < float(L["r_pause"]) * 1.8:
		return "pause"
	if pos.distance_to(L["flask"]) <= float(L["r_flask"]):
		return "flask"
	var h := _hud()
	if h != null and h.has_method("card_hit") and h.card_hit(pos):
		return "card"
	return _thumb_role(pos, L, vs)


static func _thumb_role(pos: Vector2, L: Dictionary, vs: Vector2) -> String:
	## The move zone on the left, or on the right whichever of jump / attack /
	## special is nearest relative to its size; "" in the gap between.
	if pos.x < vs.x * 0.45:
		return "move"
	if pos.x > vs.x * 0.5:
		var best := INF
		var role := ""
		for r in ["jump", "attack", "special"]:
			var d: float = pos.distance_to(L[r]) / float(L["r_" + r])
			if d < best:
				best = d
				role = r
		return role
	return ""


func _slide_off_card(t: Dictionary) -> void:
	## A thumb that landed on the pickup card (the tap was taken) and slides
	## off it, or toward a thumb button, becomes a move or that button from
	## where it is now, as a thumb sliding off the flask does; it never
	## becomes the flask.
	## While it rests where the card is (even once the card stops taking
	## taps: a tap spent it, or it gave way to the next) and isn't reaching
	## for a thumb button, it stays the card's and presses nothing.
	var p: Vector2 = t["pos"]
	var h := _hud()
	var L := layout()
	if h != null and h.has_method("card_slot") and (h.card_slot() as Rect2).grow(4.0).has_point(p) and h.clear_of_thumbs(p, L):
		return
	var role := _thumb_role(p, L, _view.get_size())
	if role == "":
		return
	t["role"] = role
	t["start"] = Vector2(p.x, maxf(p.y, float(L["left"].y))) if role == "move" else p


func _begin(index: int, pos: Vector2) -> void:
	var role := role_at(pos)
	match role:
		"":
			return
		"pause":
			pause_pressed.emit()
			return
		"card":
			# A tap that would melt the worn piece (satchel full) only asks
			# first: the HUD wants a second tap for that. The touch is kept,
			# pressing nothing, so a thumb sliding off the card moves.
			var h := _hud()
			if h and h.has_method("tap_card"):
				h.tap_card(true)
	_touches[index] = {"role": role, "start": pos, "pos": pos, "t": 0.0, "fired": false}
	_refresh()


func _end(index: int) -> void:
	_touches.erase(index)
	_refresh()


func _hud() -> Node:
	if hud != null and is_instance_valid(hud):
		return hud
	var p := get_parent()
	if p != null and p.get("hud") != null:
		return p.get("hud")
	return null


func _refresh() -> void:
	var L := layout()
	var want := {"left": false, "right": false, "down": false, "up": false, "jump": false, "attack": false, "special": false, "flask": false}
	var mid: float = (L["left"].x + L["right"].x) * 0.5
	for t in _touches.values():
		match t["role"]:
			"move":
				var p: Vector2 = t["pos"]
				if p.x < mid - 6.0:
					want["left"] = true
				elif p.x > mid + 6.0:
					want["right"] = true
				if p.y - t["start"].y > SLIDE:
					want["down"] = true
				elif t["start"].y - p.y > SLIDE:
					want["up"] = true
			"jump":
				want["jump"] = true
			"attack":
				want["attack"] = true
			"special":
				want["special"] = true
			"flask":
				if t["fired"]:
					want["flask"] = true
	for action in want:
		if want[action] != _pressed[action]:
			_pressed[action] = want[action]
			if not InputMap.has_action(action):
				continue
			if want[action]:
				Input.action_press(action)
			else:
				Input.action_release(action)
	_view.queue_redraw()


func is_down(action: String) -> bool:
	## Whether this layer is holding an action (tests read it).
	return bool(_pressed.get(action, false))


func release_all() -> void:
	_touches.clear()
	for action in _pressed:
		if _pressed[action]:
			if InputMap.has_action(action):
				Input.action_release(action)
			_pressed[action] = false


func _process(dt: float) -> void:
	_t += dt
	_flask_flash = maxf(_flask_flash - dt * 3.0, 0.0)
	# The flask drinks only after a short hold on it. A thumb that slides
	# away (drunk or not) becomes a move from where it is now, so holding the
	# flask and sliding down onto the arrows runs at once. A touch that began
	# as a move never becomes the flask.
	var L := layout()
	var changed := false
	for t in _touches.values():
		if t["role"] != "flask":
			continue
		if (t["pos"] as Vector2).distance_to(L["flask"]) > float(L["r_flask"]) * 1.6:
			# "Down" counts from the arrows' row at the highest, so a thumb
			# coming down from the flask onto them isn't read as a drop
			# (down + jump on a ledge drops through it).
			var p: Vector2 = t["pos"]
			t["role"] = "move"
			t["start"] = Vector2(p.x, maxf(p.y, float(L["left"].y)))
			changed = true
			continue
		t["t"] += dt
		if not t["fired"] and t["t"] >= FLASK_HOLD:
			t["fired"] = true
			_flask_flash = 1.0
			changed = true
	if changed:
		_refresh()
	# The Special's icon (loaded here, never inside the draw).
	var icon := str(special_state.get("icon", ""))
	if icon == "":
		var g := get_node_or_null("/root/Game")
		icon = str(g.hero()["cls"]) if g else "knight"
	if icon != _special_icon:
		_special_icon = icon
		_special_tex = UI.tex("res://art/ui/btn_special_%s.svg" % icon)
	_poll -= dt
	if _poll <= 0.0:
		_poll = 0.5
		var g := get_node_or_null("/root/Game")
		_points = int(g.hero().get("points", 0)) if g else 0
	_view.queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw_controls() -> void:
	if not visible_controls:
		return
	var L := layout()
	_button(L["left"], L["r_move"], "btn_left", _pressed["left"] or Input.is_action_pressed("left"))
	_button(L["right"], L["r_move"], "btn_right", _pressed["right"] or Input.is_action_pressed("right"))
	_button(L["attack"], L["r_attack"], "btn_attack", _pressed["attack"] or Input.is_action_pressed("attack"))
	_button(L["jump"], L["r_jump"], "btn_jump", _pressed["jump"] or Input.is_action_pressed("jump"))
	_draw_special(L["special"], L["r_special"], _pressed["special"] or Input.is_action_pressed("special"))
	_draw_flask(L["flask"], L["r_flask"])
	_draw_pause(L["pause"], L["r_pause"])


func _button(c: Vector2, r: float, icon: String, down: bool) -> void:
	var fill := Color(1.0, 0.85, 0.6, 0.30) if down else Color(0.08, 0.05, 0.12, 0.38)
	var rr := r * (0.94 if down else 1.0)
	_view.draw_circle(c, rr, fill)
	_view.draw_arc(c, rr, 0, TAU, 40, Color(1, 1, 1, 0.55 if down else 0.3), 2.0, true)
	var tex := UI.tex("res://art/ui/%s.svg" % icon)
	var s := rr * 1.15
	if tex:
		_view.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 0.95 if down else 0.8))
	else:
		var col := Color(1, 1, 1, 0.8)
		var k := r / 44.0
		match icon:
			"btn_left":
				_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0) * k, c + Vector2(8, -12) * k, c + Vector2(8, 12) * k]), col)
			"btn_right":
				_view.draw_colored_polygon(PackedVector2Array([c + Vector2(12, 0) * k, c + Vector2(-8, -12) * k, c + Vector2(-8, 12) * k]), col)
			"btn_jump":
				_view.draw_polyline(PackedVector2Array([c + Vector2(-14, 6) * k, c + Vector2(0, -8) * k, c + Vector2(14, 6) * k]), col, 5.0)
			"btn_attack":
				_view.draw_line(c + Vector2(-12, 12) * k, c + Vector2(12, -12) * k, col, 5.0)
				_view.draw_line(c + Vector2(-8, 2) * k, c + Vector2(-2, 8) * k, col, 4.0)


static func special_look(down: bool, grey := false) -> Dictionary:
	## {fill, icon}: the Special disc's colours. It sits in the play lane at
	## the hero's height (monsters, Tollgrave's bell and his tells pass under
	## it), so at rest it's a ring with a faint fill and its icon at about
	## the decided idle alpha of 0.45; pressed, it lights up.
	var a := 0.9 if down else 0.45
	return {"fill": Color(1.0, 0.85, 0.6, 0.30) if down else Color(0.08, 0.05, 0.12, 0.14),
			"icon": Color(0.55, 0.53, 0.6, a) if grey else Color(1, 1, 1, 0.95 if down else a + 0.1)}


static func flask_look(down: bool, empty := false) -> Dictionary:
	## {fill, icon}: the flask disc's colours, as quiet as the Special's at
	## rest (it sits where the hero stands as a level starts).
	return {"fill": Color(1.0, 0.85, 0.6, 0.28) if down else Color(0.08, 0.05, 0.12, 0.14),
			"icon": Color(0.5, 0.48, 0.55, 0.4) if empty else Color(1, 1, 1, 0.95 if down else 0.6)}


func _draw_special(c: Vector2, r: float, down: bool) -> void:
	## The calling's Special: its resource as an arc round the rim, grey when
	## it can't be afforded, pips (Smoke, wisps), and a white ring for a
	## charge or a hold. Quiet (special_look) until pressed.
	var st := special_state
	var grey := bool(st.get("grey", false))
	var ready := bool(st.get("ready", true)) and not grey
	var cls := _special_icon if _special_icon != "" else "knight"
	var col := UI.res_color(cls) if not ["toll"].has(cls) else UI.res_color("sexton")
	if grey:
		col = Color("8b8698")
	var a := 0.9 if down else 0.45
	var look := special_look(down, grey)
	var rr := r * (0.94 if down else 1.0)
	_view.draw_circle(c, rr, look["fill"])
	var fill := clampf(float(st.get("fill", 0.0)), 0.0, 1.0)
	# The resource arc.
	_view.draw_arc(c, rr + 3.5, 0, TAU, 48, Color(0, 0, 0, 0.35), 3.5, true)
	if fill > 0.0:
		_view.draw_arc(c, rr + 3.5, -PI * 0.5, -PI * 0.5 + TAU * fill, 48, Color(col, 0.55 + 0.4 * a), 3.5, true)
	if ready and fill >= 0.999:
		_view.draw_arc(c, rr + 6.5, 0, TAU, 48, Color(col, 0.18 + 0.12 * sin(_t * 4.0)), 2.0, true)
	_view.draw_arc(c, rr, 0, TAU, 40, Color(1, 1, 1, 0.55 if down else 0.28), 2.0, true)
	var s := rr * 1.2
	var tint: Color = look["icon"]
	if _special_tex:
		_view.draw_texture_rect(_special_tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
	else:
		var g: String = {"knight": "shield", "witch": "flame", "runner": "swift", "founder": "bell", "sexton": "skull", "toll": "bell"}.get(cls, "sun")
		UI.glyph(_view, g, c, rr * 0.95, Color(col.lerp(Color.WHITE, 0.35), tint.a) if not grey else tint)
	# Pips along the top of the rim.
	var n := int(st.get("pips_max", 0))
	var have := int(st.get("pips", 0))
	for i in n:
		var ang := -PI * 0.5 + (i - (n - 1) * 0.5) * 0.36
		var p := c + Vector2(cos(ang), sin(ang)) * (rr + 3.5)
		_view.draw_circle(p, 4.2, Color(0.05, 0.03, 0.08, 0.9))
		_view.draw_circle(p, 3.0, Color(col.lightened(0.2), 0.95) if i < have else Color(1, 1, 1, 0.22))
	# A charge or a hold.
	var ring := clampf(float(st.get("ring", 0.0)), 0.0, 1.0)
	if ring > 0.0:
		_view.draw_arc(c, rr - 5.0, -PI * 0.5, -PI * 0.5 + TAU * ring, 40, Color(1, 1, 1, 0.9), 3.0, true)
	# v3, the finale: "Hold to give your flame" (the HUD's pill says it). A
	# gold band round the button, and the hold filling it (hold_ring 0..1).
	if st.has("hold_ring"):
		var hk := clampf(float(st["hold_ring"]), 0.0, 1.0)
		var tb := UI.batch()
		tb.ring(c, rr + 10.0, 5.0, Color(0.05, 0.03, 0.08, 0.7), 40)
		tb.ring(c, rr + 10.0, 3.0, Color(UI.GOLD, 0.3 + 0.15 * sin(_t * 3.0)), 40)
		if hk > 0.0:
			tb.ring(c, rr + 10.0, 5.0, Color(UI.GOLD.lerp(Color.WHITE, hk * 0.5), 0.95), 40, -PI * 0.5, -PI * 0.5 + TAU * hk)
		tb.flush(_view)


func _draw_flask(c: Vector2, r: float) -> void:
	## The Tallow Flask: its charges as pips on the rim, and while a thumb
	## holds it, a ring filling over the 0.2 s it takes to drink.
	var charges := int(flask_state.get("charges", 0))
	var mx := int(flask_state.get("max", 0))
	var drinking := bool(flask_state.get("drinking", false))
	var hold := 0.0
	for t in _touches.values():
		if t["role"] == "flask":
			hold = 1.0 if t["fired"] else clampf(float(t["t"]) / FLASK_HOLD, 0.0, 1.0)
	var empty := charges <= 0 and not drinking
	var down := hold > 0.0 or drinking
	var look := flask_look(down, empty)
	var rr := r * (0.94 if down else 1.0)
	_view.draw_circle(c, rr, look["fill"])
	_view.draw_arc(c, rr, 0, TAU, 32, Color(1, 1, 1, 0.5 if down else 0.28), 2.0, true)
	var tex := UI.tex("res://art/ui/btn_flask.svg")
	var tint: Color = look["icon"]
	var s := rr * 1.25
	if tex:
		_view.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
	else:
		# A little stoppered bottle of melted tallow.
		var body := Color(0.95, 0.78, 0.42, tint.a) if not empty else tint
		_view.draw_circle(c + Vector2(0, rr * 0.18), rr * 0.42, body)
		_view.draw_rect(Rect2(c + Vector2(-rr * 0.14, -rr * 0.5), Vector2(rr * 0.28, rr * 0.4)), body)
		_view.draw_rect(Rect2(c + Vector2(-rr * 0.2, -rr * 0.62), Vector2(rr * 0.4, rr * 0.14)), Color(0.55, 0.36, 0.22, tint.a))
		_view.draw_circle(c + Vector2(-rr * 0.14, rr * 0.08), rr * 0.12, Color(1, 1, 1, 0.5 * tint.a))
	# v3: up to 3 charges (the Second Draught, Mother Taper's Match): with
	# two or more, one short arc per charge round the rim, lit while full.
	if mx >= 2 and hold <= 0.0:
		var tb := UI.batch()
		for arc in flask_arcs(rr, mx, charges):
			tb.ring(c, rr + 3.5, 3.0, Color(UI.EMBER, 0.85) if arc[2] else Color(1, 1, 1, 0.16), 12, arc[0], arc[1])
		tb.flush(_view)
	if hold > 0.0:
		_view.draw_arc(c, rr + 3.5, -PI * 0.5, -PI * 0.5 + TAU * hold, 36, Color(UI.EMBER, 0.95), 3.5, true)
	if _flask_flash > 0.0:
		_view.draw_circle(c, rr + 8.0 * (1.0 - _flask_flash), Color(1.0, 0.85, 0.5, 0.25 * _flask_flash))
	# The charges left, as a number on a badge at its shoulder (1 on Dusk,
	# 2 deeper down): ember while there's a drink, grey when it's dry.
	if mx > 0:
		var bp := flask_badge(c, rr)
		var br := FLASK_BADGE_R
		_view.draw_circle(bp, br + 1.5, Color(0.05, 0.03, 0.08, 0.95))
		_view.draw_circle(bp, br, Color("3a2412") if charges > 0 else Color("241d2e"))
		_view.draw_arc(bp, br, 0, TAU, 20, UI.EMBER if charges > 0 else Color(UI.MUTED, 0.6), 1.5, true)
		UI.text(_view, Vector2(bp.x - br, bp.y + 4.5), str(charges), 13, UI.EMBER.lightened(0.25) if charges > 0 else UI.MUTED,
				HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, "body", 800)


static func flask_arcs(rr: float, mx: int, charges: int) -> Array:
	## The rim arcs of a flask of 2 or 3 charges ([from, to, lit], radians,
	## on a ring rr + 3.5 out): they start beside the charge badge and run
	## clockwise, leaving it a gap so it never sits on one; the first ones lit.
	var out: Array = []
	if mx < 2:
		return out
	var n := mini(mx, 3)
	var span := TAU / n
	var badge := -PI * 0.25
	var clear := asin(clampf((FLASK_BADGE_R + 1.5) / (rr + 3.5), 0.0, 1.0)) + 0.08
	for i in n:
		var a0 := badge + i * span + (clear if i == 0 else 0.22)
		var a1 := badge + (i + 1) * span - (clear if i == n - 1 else 0.22)
		out.append([a0, a1, i < charges])
	return out


static func flask_badge(c: Vector2, r: float) -> Vector2:
	## Where the flask's charge badge sits: on its rim, up and to the right.
	return c + Vector2(cos(-PI * 0.25), sin(-PI * 0.25)) * (r + 1.0)


func _draw_pause(c: Vector2, r: float) -> void:
	## Two bars; a gold "+" at its shoulder while skill points wait.
	_view.draw_circle(c, r, Color(0.08, 0.05, 0.12, 0.45))
	_view.draw_arc(c, r, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5, true)
	_view.draw_rect(Rect2(c + Vector2(-6, -7), Vector2(4, 14)), Color(1, 1, 1, 0.8))
	_view.draw_rect(Rect2(c + Vector2(2, -7), Vector2(4, 14)), Color(1, 1, 1, 0.8))
	if _points > 0:
		var p := c + Vector2(-r * 0.72, r * 0.72)
		var pulse := 1.0 + 0.12 * sin(_t * 5.0)
		_view.draw_circle(p, 8.0 * pulse, UI.INK)
		_view.draw_circle(p, 6.5 * pulse, UI.GOLD)
		UI.glyph(_view, "plus", p, 9.0, UI.INK)
