extends Control
## The Sheet's Skills tab: the calling's tree. The root medallion (its
## Special) at the top centre; below it two branches, each Tier 1 (a pair),
## Tier 2 and a Tier 3 capstone, with lines lit as they're taken. Locked
## nodes are dim, ones a point can buy now have a gold rim, owned ones fill
## with the calling's colour; pips show the ranks. An owned node a point can
## raise again takes the gold pulse over its fill and a small "+"; a fully
## learned one has a steady gold ring. Tap a node for its card: what it does
## now and at the next rank, and "+" to buy it. Respec is free. Only one
## capstone per hero in v2's tree.
##
## v3's deep tree (Classes.deep): six rows, the root and Tiers 1 to 5; each
## branch goes on under its capstone to a Tier 4 "Deep" node (level 16 and 7
## points in the branch) and a Tier 5 "Mastery" node (level 24 and 10), and
## the other capstone opens at level 30. A locked node's card says what
## opens it ("Opens at level 16.", "The other capstone opens at level 30.").

const UI := preload("res://scripts/ui.gd")
const Classes := preload("res://scripts/classes.gd")

const GLYPH_BY_STAT := {"max_hp_pct": "heart", "crit": "star", "crit_mult_add": "star", "basic_pct": "blade",
		"dmg_pct": "blade", "dr": "shield", "res_max_add": "drop", "cooldown_pct": "swift", "special_pct": "star",
		"res_regen_pct": "drop"}
const GLYPH_BY_ID := {"k_devout": "heart", "k_mirror": "shield", "k_crescent": "blade", "w_twin": "star",
		"w_kindle": "flame", "w_waxskin": "drop", "w_seal": "drop", "r_veil": "swift", "r_bandolier": "blade",
		"r_ricochet": "swift", "f_bellows": "bell", "f_stoked": "flame", "f_slag": "flame", "f_after": "bell",
		"x_bright": "sun", "x_ward": "shield", "x_harvest": "skull", "x_chill": "drop",
		# v3's Tier 4 and 5 kit nodes
		"k_bastion": "shield", "k_sanctuary": "bell", "k_judgment": "blade", "w_wildfire": "flame",
		"w_candlemold": "drop", "r_phantom": "swift", "r_fan": "blade", "f_moltencore": "flame",
		"f_carillon": "bell", "x_requiem": "skull", "x_barrow": "skull"}
const TIER_NAME := {1: "Tier 1", 2: "Tier 2", 3: "Capstone", 4: "Deep", 5: "Mastery"}
const STUD_R := 2.3               # the deep tree's rank studs on a node's rim

var host: Control
var selected := ""
var _plus: Button
var _respec: Button
var _t := 0.0
var _flash := {}                  # id -> 1..0 after a buy
var _deny := 0.0
var _confirm_respec := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_plus = UI.make_button("+", true, func(): buy(), "", 26)
	_plus.custom_minimum_size = Vector2(46, 46)
	UI.small_button(_plus, 26)
	add_child(_plus)
	_respec = UI.make_button("Respec · free", false, func(): _respec_pressed(), "click", 13)
	UI.small_button(_respec, 13)
	_respec.custom_minimum_size = Vector2(0, UI.TAP_H)
	add_child(_respec)
	var tree := Classes.tree(_cls())
	selected = tree[0]["id"] if not tree.is_empty() else ""
	# Start on something worth looking at: the first node a point can buy.
	for n in tree:
		if _state(n) == "available":
			selected = n["id"]
			break


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _hero() -> Dictionary:
	var g := _game()
	return g.hero() if g else {}


func _cls() -> String:
	return str(_hero().get("cls", "knight"))


func rank_of(n: Dictionary) -> int:
	return int(_hero().get("skills", {}).get(n["id"], 1 if n["branch"] == -1 else 0))


func _state(n: Dictionary) -> String:
	## locked / open (its gates are met, no points) / available / owned / maxed
	var h := _hero()
	var r := rank_of(n)
	if r >= int(n["max"]):
		return "maxed"
	var gates := Classes.can_buy(_cls(), n["id"], h.get("skills", {}), int(h.get("level", 1)), 99)
	var now := Classes.can_buy(_cls(), n["id"], h.get("skills", {}), int(h.get("level", 1)), int(h.get("points", 0)))
	if now == "":
		return "available" if r == 0 else "owned_more"
	if r > 0:
		return "owned"
	return "open" if gates == "" else "locked"


func deep() -> bool:
	## The v3 tree is in play: six rows (Classes.deep).
	for n in Classes.tree(_cls()):
		if int(n["tier"]) >= 4:
			return true
	return false


func rows() -> Array:
	## Each row's centre height: the root, then Tier 1, 2, 3 (and 4, 5).
	var h := size.y
	if not deep():
		return [h * 0.11, h * 0.36, h * 0.6, h * 0.85]
	var top := 32.0
	var step := (h - 36.0 - top) / 5.0
	var out: Array = []
	for i in 6:
		out.append(top + i * step)
	return out


func positions() -> Dictionary:
	## Each node's centre and radius in this panel: {id: [Vector2, r]}.
	var out := {}
	var tw := minf(size.x * 0.56, 420.0)
	var cx := tw * 0.5
	var rows := rows()
	var d := rows.size() > 4
	var col := [cx - tw * 0.26, cx + tw * 0.26]
	var t1_seen := {0: 0, 1: 0}
	for n in Classes.tree(_cls()):
		var b: int = int(n["branch"])
		var tier := int(n["tier"])
		match tier:
			0:
				out[n["id"]] = [Vector2(cx, rows[0]), 20.0 if d else 23.0]
			1:
				var k: int = t1_seen[b]
				t1_seen[b] = k + 1
				out[n["id"]] = [Vector2(col[b] + (k * 2 - 1) * 34.0, rows[1]), 16.0 if d else 19.0]
			2:
				out[n["id"]] = [Vector2(col[b], rows[2]), 17.0 if d else 20.0]
			3:
				out[n["id"]] = [Vector2(col[b], rows[3]), 18.0 if d else 22.0]
			4, 5:
				if tier < rows.size():
					out[n["id"]] = [Vector2(col[b], rows[tier]), 17.0 if tier == 4 else 18.0]
	return out


func tree_rect() -> Rect2:
	## The tree's panel, left of the card.
	return Rect2(0, 4, minf(size.x * 0.56, 420.0), size.y - 8.0)


func card_rect() -> Rect2:
	var tw := minf(size.x * 0.56, 420.0)
	return Rect2(tw + 10.0, 4.0, size.x - tw - 10.0, size.y - 8.0)


func select(id: String) -> void:
	selected = id
	queue_redraw()


func buy() -> bool:
	## Buys the next rank of the selected node (the "+" button).
	var g := _game()
	if g == null or selected == "":
		return false
	if g.buy_skill(selected):
		_flash[selected] = 1.0
		_sfx("select")
		if host and host.has_method("notify_changed"):
			host.notify_changed()
		return true
	_deny = 1.0
	_sfx("back")
	return false


func respec() -> void:
	var g := _game()
	if g == null:
		return
	g.respec()
	_confirm_respec = 0.0
	_sfx("salvage")
	if host and host.has_method("notify_changed"):
		host.notify_changed()


func _respec_pressed() -> void:
	## Twice to be sure (it's free, but it undoes every choice).
	if _confirm_respec > 0.0:
		respec()
	else:
		_confirm_respec = 3.0


func _sfx(name: String) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s and name != "":
		s.play(name)


func _gui_input(event: InputEvent) -> void:
	var tapped := UI.is_tap(event)   # one tap, once (not its touch twin too)
	if not tapped:
		return
	var P := positions()
	for id in P:
		if event.position.distance_to(P[id][0]) < float(P[id][1]) + 10.0:
			if selected != id:
				_sfx("click")
			select(id)
			accept_event()
			return


func _process(dt: float) -> void:
	_t += dt
	for id in _flash.keys():
		_flash[id] = maxf(_flash[id] - dt * 2.0, 0.0)
	_deny = maxf(_deny - dt * 3.0, 0.0)
	_confirm_respec = maxf(_confirm_respec - dt, 0.0)
	var C := card_rect()
	var h := _hero()
	var n := Classes.find_node(_cls(), selected)
	var why := Classes.can_buy(_cls(), selected, h.get("skills", {}), int(h.get("level", 1)), int(h.get("points", 0))) if not n.is_empty() else "unknown"
	_plus.disabled = why != ""
	_plus.visible = not n.is_empty() and why != "maxed"
	_plus.reset_size()
	_plus.position = Vector2(C.end.x - _plus.size.x - 12.0, C.end.y - _plus.size.y - 12.0)
	var spent := 0
	for id in h.get("skills", {}):
		var m := Classes.find_node(_cls(), id)
		spent += int(h["skills"][id]) - (1 if not m.is_empty() and m["branch"] == -1 else 0)
	_respec.visible = spent > 0
	_respec.text = "Tap again to respec" if _confirm_respec > 0.0 else "Respec · free"
	_respec.reset_size()
	_respec.position = Vector2(C.end.x - _respec.size.x - 10.0, C.position.y + 10.0)
	queue_redraw()


func _draw() -> void:
	var cls := _cls()
	var col := UI.class_color(cls)
	var h := _hero()
	var P := positions()
	var tree := Classes.tree(cls)
	var tw := minf(size.x * 0.56, 420.0)
	var R := rows()
	var d := R.size() > 4
	UI.panel(self, Rect2(0, 4, tw, size.y - 8.0), Color(UI.PANEL_EDGE, 0.7), Color(UI.PANEL, 0.85), 12.0)
	# The lines: root to each Tier 1, the pair to Tier 2, Tier 2 to the
	# capstone, and on down the deep tree to Tiers 4 and 5.
	var root_id := ""
	var by := {0: {1: [], 2: [], 3: [], 4: [], 5: []}, 1: {1: [], 2: [], 3: [], 4: [], 5: []}}
	for n in tree:
		if n["branch"] == -1:
			root_id = n["id"]
		elif by[int(n["branch"])].has(int(n["tier"])):
			by[int(n["branch"])][int(n["tier"])].append(n)
	for b in [0, 1]:
		for n in by[b][1]:
			_link(P[root_id][0], P[n["id"]][0], rank_of(n) > 0, col)
			for m in by[b][2]:
				_link(P[n["id"]][0], P[m["id"]][0], rank_of(m) > 0, col)
		for t in [2, 3, 4]:
			for m in by[b][t]:
				for c in by[b][t + 1]:
					if P.has(m["id"]) and P.has(c["id"]):
						_link(P[m["id"]][0], P[c["id"]][0], rank_of(c) > 0, col)
	# The capstone rule, between the two capstones: one per hero in v2's
	# tree; in the deep tree the other opens at level 30.
	var caps: Array = by[0][3] + by[1][3]
	if caps.size() == 2:
		var a: Vector2 = P[caps[0]["id"]][0]
		var b2: Vector2 = P[caps[1]["id"]][0]
		var mid := (a + b2) * 0.5
		var owned := rank_of(caps[0]) > 0 or rank_of(caps[1]) > 0
		var both := rank_of(caps[0]) > 0 and rank_of(caps[1]) > 0
		var top := "ONE CAPSTONE"
		var sub := "per hero"
		if d:
			top = "BOTH CAPSTONES" if both else ("SECOND CAPSTONE" if owned else "ONE CAPSTONE")
			var lvl := int(_hero().get("level", 1))
			if both:
				sub = ""
			elif owned:
				sub = "open now" if lvl >= Classes.SECOND_CAPSTONE else "at level %d" % Classes.SECOND_CAPSTONE
			else:
				sub = "then a second at %d" % Classes.SECOND_CAPSTONE
		UI.text(self, Vector2(mid.x - 70.0, mid.y - 4.0), top, 9, Color(UI.GOLD if owned else UI.MUTED, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 140.0, "body", 800)
		if sub != "":
			UI.text(self, Vector2(mid.x - 70.0, mid.y + 8.0), sub, 9, Color(UI.MUTED, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 140.0, "body", 700)
	if d:
		for t in range(1, 6):
			UI.text(self, Vector2(8.0, R[t] + 4.0), "T%d" % t, 9, Color(UI.MUTED, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
		# The deep rows' gates, by the right branch's column.
		for t in [4, 5]:
			var g: Dictionary = Classes.GATES.get(t, {})
			if not g.is_empty() and not by[1][t].is_empty() and P.has(by[1][t][0]["id"]):
				var c: Vector2 = P[by[1][t][0]["id"]][0]
				var lx := c.x + 28.0
				UI.text(self, Vector2(lx, R[t] - 2.0), "Lv %d" % int(g["level"]), 9, Color(UI.MUTED, 0.7), HORIZONTAL_ALIGNMENT_LEFT, tw - lx - 6.0, "body", 800)
				UI.text(self, Vector2(lx, R[t] + 9.0), "%d pts" % int(g["branch"]), 9, Color(UI.MUTED, 0.55), HORIZONTAL_ALIGNMENT_LEFT, tw - lx - 6.0, "body", 700)
	else:
		UI.text(self, Vector2(10.0, size.y * 0.36 - 30.0), "TIER 1", 9, Color(UI.MUTED, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
		UI.text(self, Vector2(10.0, size.y * 0.6 - 16.0), "TIER 2", 9, Color(UI.MUTED, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
		UI.text(self, Vector2(10.0, size.y * 0.85 - 16.0), "TIER 3", 9, Color(UI.MUTED, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	for n in tree:
		if P.has(n["id"]):
			_medallion(n, P[n["id"]][0], float(P[n["id"]][1]), col)
	_draw_card(h, col)


func _link(a: Vector2, b: Vector2, lit: bool, col: Color) -> void:
	draw_line(a, b, Color(UI.INK, 0.9), 6.0)
	draw_line(a, b, Color(col, 0.9) if lit else Color(UI.PANEL_EDGE, 0.45), 2.5)


func _medallion(n: Dictionary, c: Vector2, r: float, col: Color) -> void:
	var st := _state(n)
	var rank := rank_of(n)
	var sel: bool = n["id"] == selected
	var cap := int(n["tier"]) == 3
	var mastery := int(n["tier"]) == 5
	var fill := Color("1a1424")
	var rim := Color("3a3148")
	var gcol := Color(UI.MUTED, 0.45)
	match st:
		"open":
			fill = Color("241b30")
			rim = UI.PANEL_EDGE
			gcol = Color(UI.MUTED, 0.8)
		"available":
			fill = Color("2e2238")
			rim = UI.GOLD
			gcol = UI.CREAM
		"owned", "owned_more", "maxed":
			fill = col.darkened(0.45)
			rim = col
			gcol = UI.CREAM
	if sel:
		draw_circle(c, r + 9.0, Color(1.0, 0.85, 0.45, 0.14))
	var fl := float(_flash.get(n["id"], 0.0))
	if fl > 0.0:
		draw_circle(c, r + 14.0 * (1.0 - fl) + 4.0, Color(col.lightened(0.3), 0.35 * fl))
	draw_circle(c, r + 3.0, UI.INK)
	if cap:
		# A capstone: a star-pointed medallion.
		var pts := PackedVector2Array()
		for i in 16:
			var rr := (r + 3.0) * (1.0 if i % 2 == 0 else 0.86)
			var a := TAU * i / 16.0 - PI * 0.5
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, rim.darkened(0.3))
	draw_circle(c, r, fill)
	if mastery:
		# Tier 5: a second, finer rim just outside the first.
		var tb := UI.batch()
		tb.ring(c, r + 4.5, 1.4, Color(rim, 0.8), 32)
		tb.flush(self)
	var pulse := 0.65 + 0.35 * sin(_t * 4.0)
	var rim_a := pulse if st == "available" else 1.0
	draw_arc(c, r, 0, TAU, 36, Color(rim, rim_a), 2.5 if st != "locked" else 1.5, true)
	if st == "owned_more":
		# Owned, and a point can raise it: the class fill keeps, and the gold
		# pulse a buyable node has runs over its rim.
		draw_arc(c, r, 0, TAU, 36, Color(UI.GOLD, pulse), 2.5, true)
	if st == "maxed":
		draw_arc(c, r + 3.5, 0, TAU, 36, Color(UI.GOLD, 0.9), 1.5, true)
	var g: String = "flame" if n["branch"] == -1 else ("sun" if cap else GLYPH_BY_ID.get(n["id"], GLYPH_BY_STAT.get(n["stat"], "star")))
	UI.glyph(self, g, c, r * 1.05, gcol)
	var studs := _studded(n)
	if st == "locked":
		# (Up at its shoulder where the ranks sit on its lower rim.)
		UI.glyph(self, "lock", c + Vector2(r * 0.62, -r * 0.62 if studs else r * 0.62), 13.0, Color(UI.MUTED, 0.8))
	elif st == "owned_more":
		# And a small gold "+" at its shoulder.
		var bp := c + Vector2(r * 0.74, -r * 0.74)
		var k := 1.0 + 0.08 * sin(_t * 4.0)
		draw_circle(bp, 9.0 * k, UI.INK)
		draw_circle(bp, 7.5 * k, UI.GOLD)
		UI.glyph(self, "plus", bp, 11.0, UI.INK)
	# Rank pips: in a row under the node, or in the deep tree (rows closer
	# together) set as studs along its lower rim.
	var mx := int(n["max"])
	var pc := col if rank > 0 else UI.GOLD
	if studs:
		var tb := UI.batch()
		var pts := pip_centres(n, c, r)
		for i in pts.size():
			tb.circle(pts[i], STUD_R + 1.0, Color(UI.INK, 0.9), 10)
			if i < rank:
				tb.circle(pts[i], STUD_R, pc, 10)
				tb.circle(pts[i] + Vector2(-STUD_R * 0.3, -STUD_R * 0.3), STUD_R * 0.35, Color(1, 1, 1, 0.45), 6)
			else:
				tb.circle(pts[i], STUD_R - 0.2, Color("1a1424"), 10)
				tb.ring(pts[i], STUD_R - 0.5, 1.2, Color(pc, 0.55), 12)
		tb.flush(self)
		return
	var pr := 2.6
	var left := c + Vector2(-(mx - 1) * (pr * 2.0 + 2.0) * 0.5, r + 8.0)
	UI.pips(self, left, mx, rank, pr, pc, 2.0)


func _studded(n: Dictionary) -> bool:
	## The deep tree's nodes below the root carry their ranks on the rim.
	return int(n["tier"]) >= 1 and rows().size() > 4


func pip_centres(n: Dictionary, c: Vector2, r: float) -> Array:
	## Each rank pip's centre (tests and drawing): a row r + 8 under the
	## node (pips 2.6), or in the deep tree studs STUD_R on its lower rim,
	## centred under it.
	var mx := int(n["max"])
	var out: Array = []
	if _studded(n):
		var th := (STUD_R * 2.0 + 2.4) / r
		for i in mx:
			var ang := PI * 0.5 + ((mx - 1) * 0.5 - i) * th
			out.append(c + Vector2(cos(ang), sin(ang)) * r)
		return out
	for i in mx:
		out.append(c + Vector2(-(mx - 1) * (2.6 * 2.0 + 2.0) * 0.5 + i * (2.6 * 2.0 + 2.0), r + 8.0))
	return out


func pip_radius(n: Dictionary) -> float:
	## A pip's radius with its ink edge.
	return STUD_R + 1.0 if _studded(n) else 3.6


func outer_radius(n: Dictionary, r: float) -> float:
	## How far a node's drawing reaches from its centre (not its glow): the
	## ink disc, a capstone's star, Tier 5's outer rim, a maxed ring.
	var o := r + 3.0
	if int(n["tier"]) == 5:
		o = maxf(o, r + 4.5 + 0.7)
	if _state(n) == "maxed":
		o = maxf(o, r + 3.5 + 0.75)
	return o


func _draw_card(h: Dictionary, col: Color) -> void:
	var C := card_rect()
	var pts := int(h.get("points", 0))
	UI.panel(self, C, Color(col, 0.55), Color(UI.PANEL, 0.92), 12.0)
	var x := C.position.x + 14.0
	var w := C.size.x - 28.0
	# The points.
	UI.text(self, Vector2(x, C.position.y + 34.0), "Points", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	UI.text(self, Vector2(x + 50.0, C.position.y + 35.0), str(pts), 22, UI.GOLD if pts > 0 else UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
	draw_line(Vector2(x, C.position.y + 56.0), Vector2(C.end.x - 14.0, C.position.y + 56.0), Color(UI.PANEL_EDGE, 0.5), 1.0)
	var n := Classes.find_node(_cls(), selected)
	if n.is_empty():
		return
	var rank := rank_of(n)
	var mx := int(n["max"])
	var y := C.position.y + 82.0
	UI.text(self, Vector2(x, y), str(n["name"]), UI.fit_size(str(n["name"]), w, 22, 15, "title", 700), col.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, w, "title", 700)
	var tier_name := "Special" if n["branch"] == -1 else str(TIER_NAME.get(int(n["tier"]), "Tier %d" % int(n["tier"])))
	UI.text(self, Vector2(x, y + 18.0), ("%s · rank %d of %d" % [tier_name, rank, mx]).to_upper(), 10, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, w, "body", 800)
	y += 42.0
	if rank > 0:
		y = _para(x, y, w, "Now", Classes.node_text(n, rank), UI.CREAM)
	if rank < mx:
		y = _para(x, y, w, "Next" if rank > 0 else "Rank 1", Classes.node_text(n, rank + 1), UI.GOLD if _state(n) in ["available", "owned_more"] else Color(UI.CREAM, 0.75))
	else:
		UI.text(self, Vector2(x, y + 4.0), "Fully learned.", 13, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, w, "body", 700)
	var why := Classes.can_buy(_cls(), n["id"], h.get("skills", {}), int(h.get("level", 1)), pts)
	if why != "" and why != "maxed":
		var shake := sin(_t * 60.0) * 5.0 * _deny
		var rs := _reason(why)
		var lines := UI.wrap(rs, w - 60.0, 12, "body", 700)
		if lines.size() > 1:
			UI.text(self, Vector2(x + shake, C.end.y - 40.0), str(lines[0]), 12, UI.MUTED.lerp(UI.BAD, _deny), HORIZONTAL_ALIGNMENT_LEFT, w - 60.0, "body", 700)
			rs = " ".join(lines.slice(1))
		UI.text(self, Vector2(x + shake, C.end.y - 26.0), rs, UI.fit_size(rs, w - 60.0, 12, 10, "body", 700), UI.MUTED.lerp(UI.BAD, _deny), HORIZONTAL_ALIGNMENT_LEFT, w - 60.0, "body", 700)


func _para(x: float, y: float, w: float, label: String, body: String, col: Color) -> float:
	UI.text(self, Vector2(x, y), label.to_upper(), 10, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, w, "body", 800)
	var lines := UI.wrap(body, w, 14)
	for i in mini(lines.size(), 3):
		UI.text(self, Vector2(x, y + 18.0 + i * 18.0), lines[i], 14, col, HORIZONTAL_ALIGNMENT_LEFT, w)
	return y + 26.0 + mini(lines.size(), 3) * 18.0


func _reason(why: String) -> String:
	var n := Classes.find_node(_cls(), selected)
	match why:
		"no points":
			return "No points: earn one each level."
		"one capstone only":
			return "One capstone per hero: respec to swap."
	if why.ends_with(" points in branch"):
		return "Needs %s points in this branch." % why.get_slice(" ", 0)
	if why.begins_with("level "):
		var lv := why.substr(6)
		if not n.is_empty() and int(n["tier"]) == 3 and lv == str(Classes.SECOND_CAPSTONE):
			return "The other capstone opens at level %s." % lv
		return "Opens at level %s." % lv
	return why.capitalize()
