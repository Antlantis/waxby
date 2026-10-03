extends Control
## The Sheet's Stats tab: who the hero is (face, calling, level, XP, points
## to spend) on the left, and what the numbers come to now (life, damage,
## crit, damage reduction, light, the resource and the rest) on the right.

const UI := preload("res://scripts/ui.gd")
const Classes := preload("res://scripts/classes.gd")
const Hero := preload("res://scripts/hero.gd")
const Combat := preload("res://scripts/combat.gd")
const Progression := preload("res://scripts/progression.gd")
const CAPSTONE_LEVEL := 8         # classes.gd's can_buy gate for Tier 3

var host: Control
var _spend: Button
var _face := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_spend = UI.make_button("Spend", true, func():
		if host:
			host.open_tab("skills"), "select", 15)
	UI.small_button(_spend, 14)
	_spend.custom_minimum_size = Vector2(0, UI.TAP_H)
	add_child(_spend)
	_face = UI.hero_face(_cls(), "happy")


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _hero() -> Dictionary:
	var g := _game()
	return g.hero() if g else Hero.blank()


func _cls() -> String:
	return str(_hero().get("cls", "knight"))


func _stats() -> Dictionary:
	var g := _game()
	return g.hero_stats() if g else Hero.stats(Hero.blank())


func rows() -> Array:
	## [label, value, note] for the right-hand list.
	var s := _stats()
	var cls := _cls()
	var info: Dictionary = Classes.info(cls)
	var g := _game()
	var diff: String = g.diff() if g else "dusk"
	var hit := float(s["basic"]) * (1.0 + float(s["dmg_pct"]))
	var out: Array = [
		["Life", str(roundi(float(s["max_hp"]))), ""],
		["Damage", str(roundi(hit)), "a hit · %d a second" % roundi(Hero.dps_estimate(s))],
		["Critical", "%d%%" % roundi(float(s["crit"]) * 100.0), "hits for ×%.2f" % float(s["crit_mult"])],
		["Damage reduction", "%d%%" % roundi(float(s["dr"]) * 100.0), "cap %d%%" % roundi(Combat.DR_CAP * 100.0)],
		["Light", "%d px" % roundi(Combat.light_radius(1.0, s, diff)), "at full life"],
		[str(info["res_name"]), str(roundi(float(s["res_max"]))), "+%.1f a second" % float(s["res_regen"])],
		["Attack speed", UI.pct(float(s["attack_speed"]) - 1.0), ""],
		["Special damage", UI.pct(float(s["special_pct"])), ""],
		["Vs elites and bosses", UI.pct(float(s["elite_pct"])), ""],
		["Stomp", str(roundi(float(s["stomp"]))), ""],
	]
	if float(s["on_kill_heal"]) > 0.0:
		out.append(["Heal on kill", "%.1f%%" % (float(s["on_kill_heal"]) * 100.0), ""])
	# v3: the flask (charges on this difficulty, and what a draught heals),
	# and the new keys where they're more than nothing.
	if g != null and g.has_method("flask_charges"):
		out.append(["Flask", "%d × %d%%" % [int(g.flask_charges(diff)), roundi(float(g.flask_heal(diff)) * 100.0)], "charges · heal"])
	if float(s.get("dim_resist", 0.0)) > 0.0:
		out.append(["Dimming eased", "%d%%" % roundi(float(s["dim_resist"]) * 100.0), "cap %d%%" % roundi(Combat.DIM_RESIST_CAP * 100.0)])
	if float(s.get("shot_dr", 0.0)) > 0.0:
		out.append(["Shots and shards", "-%d%%" % roundi(float(s["shot_dr"]) * 100.0), ""])
	if float(s.get("xp_pct", 0.0)) > 0.0 or float(s.get("ember_pct", 0.0)) > 0.0:
		out.append(["XP · embers", "%s · %s" % [UI.pct(float(s.get("xp_pct", 0.0))), UI.pct(float(s.get("ember_pct", 0.0)))], ""])
	if int(s.get("vigil", 0)) > 0:
		out.append(["Vigil ranks", str(int(s["vigil"])), "+2% damage and life each"])
	if int(s.get("marks", 0)) > 0:
		out.append(["Candlemarks", str(int(s["marks"])), "+1% damage and life each"])
	return out


func _process(_dt: float) -> void:
	var pts := int(_hero().get("points", 0))
	_spend.visible = pts > 0
	_spend.reset_size()
	var left := _left_rect()
	_spend.position = Vector2(left.end.x - _spend.size.x - 12.0, left.position.y + 168.0 - _spend.size.y * 0.5 - 5.0)
	queue_redraw()


func _left_rect() -> Rect2:
	var w := minf(size.x * 0.38, 290.0)
	return Rect2(0, 4, w, size.y - 8.0)


func _draw() -> void:
	var h := _hero()
	var cls := _cls()
	var info: Dictionary = Classes.info(cls)
	var col := UI.class_color(cls)
	var g := _game()
	# Who: the face, the calling, the level and XP.
	var L := _left_rect()
	UI.panel(self, L, Color(col, 0.6), Color(UI.PANEL, 0.92), 12.0)
	var fc := Vector2(L.position.x + 50.0, L.position.y + 52.0)
	draw_circle(fc, 44.0, Color(col, 0.12))
	UI.portrait(self, fc, 34.0, _face.get("tex"), col, 1.0, _face.get("uv", Rect2(0, 0, 1, 1)), str(info["name"]).substr(0, 1))
	var tx := L.position.x + 96.0
	var tw := L.end.x - tx - 10.0
	UI.text(self, Vector2(tx, L.position.y + 44.0), str(info["name"]), UI.fit_size(str(info["name"]), tw, 24, 16, "title", 700), UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, tw, "title", 700)
	UI.text(self, Vector2(tx, L.position.y + 64.0), str(info["role"]).to_upper(), 11, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, tw, "body", 700)
	var xp: Dictionary = g.xp_progress() if g else {"level": 1, "into": 0, "need": 80, "frac": 0.0}
	var y := L.position.y + 118.0
	UI.text(self, Vector2(L.position.x + 14.0, y), "Level %d" % int(xp["level"]), 22, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
	var need := int(xp["need"])
	var into := "%d / %d XP" % [int(xp["into"]), need] if need > 0 else "The highest level"
	UI.text(self, Vector2(L.position.x, y), into, 12, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, L.size.x - 14.0, "body", 700)
	var bar := Rect2(L.position.x + 14.0, y + 10.0, L.size.x - 28.0, 8.0)
	draw_rect(bar.grow(1.0), UI.INK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(xp["frac"]), bar.size.y)), UI.GOLD)
	draw_rect(Rect2(bar.position + Vector2(0, 1), Vector2(bar.size.x * float(xp["frac"]), 2.0)), Color(1, 1, 1, 0.35))
	var pts := int(h.get("points", 0))
	y += 50.0
	if pts > 0:
		UI.glyph(self, "plus", Vector2(L.position.x + 22.0, y - 6.0), 16.0, UI.GOLD)
		var pt := "%d skill point%s to spend" % [pts, "" if pts == 1 else "s"]
		var room := L.size.x - 36.0 - _spend.size.x - 22.0
		if UI.text_width(pt, 12, "body", 700) > room:
			pt = "%d point%s" % [pts, "" if pts == 1 else "s"]
		UI.text(self, Vector2(L.position.x + 36.0, y), pt, UI.fit_size(pt, room, 14, 11, "body", 700), UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	else:
		UI.text(self, Vector2(L.position.x + 14.0, y), "Every skill point is spent.", 13, UI.MUTED)
	y += 44.0
	var nxt := _next_unlock(int(xp["level"]))
	if nxt != "":
		UI.text(self, Vector2(L.position.x + 14.0, y), "Next", 11, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
		var lines := UI.wrap(nxt, L.size.x - 28.0, 13)
		for i in mini(lines.size(), 2):
			UI.text(self, Vector2(L.position.x + 14.0, y + 17.0 + i * 16.0), lines[i], 13, UI.CREAM)
	# What's carried.
	var belt := "Belt %d of %d" % [(h.get("belt", []) as Array).size(), g.belt_slots() if g else 2]
	draw_line(Vector2(L.position.x + 14.0, L.end.y - 34.0), Vector2(L.end.x - 14.0, L.end.y - 34.0), Color(UI.PANEL_EDGE, 0.35), 1.0)
	var carried := ("%s · %s" % [satchel_line(h, g), belt]).to_upper()
	UI.text(self, Vector2(L.position.x + 14.0, L.end.y - 14.0), carried, UI.fit_size(carried, L.size.x - 28.0, 10, 8, "body", 800), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, L.size.x - 28.0, "body", 800)
	# What: the numbers, in two columns of rows.
	var R := list_rect()
	UI.panel(self, R, Color(UI.PANEL_EDGE, 0.8), Color(UI.PANEL, 0.88), 12.0)
	var list := rows()
	for i in list.size():
		var r: Array = list[i]
		var c := row_layout(i, list.size(), R, str(r[1]))
		var cx: float = c["x"]
		var cw: float = c["w"]
		UI.text(self, c["label_at"], str(r[0]).to_upper(), int(c["label_size"]), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, cw - 8.0, "body", 800)
		UI.text(self, c["value_at"], str(r[1]), int(c["value_size"]), UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
		if str(r[2]) != "":
			var vw := UI.text_width(str(r[1]), int(c["value_size"]), "body", 700)
			UI.text(self, c["note_at"], str(r[2]), int(c["note_size"]), Color(UI.MUTED, 0.9), HORIZONTAL_ALIGNMENT_LEFT, cw - vw - 18.0)
		if float(c["divider"]) > 0.0:
			draw_line(Vector2(cx + 4.0, c["divider"]), Vector2(cx + cw - 10.0, c["divider"]), Color(UI.PANEL_EDGE, 0.25), 1.0)


func list_rect() -> Rect2:
	## The numbers' panel, right of the hero's.
	var L := _left_rect()
	return Rect2(L.end.x + 10.0, L.position.y, size.x - L.end.x - 10.0, L.size.y)


func row_layout(i: int, n: int, R: Rect2, value := "") -> Dictionary:
	## Where row i of n draws in R: two columns, rows up to 50 tall. Rows of
	## 44 or more keep v2's look (label 10, value 20); shorter ones (a late
	## hero's 13 to 18 rows) set the label at 9 and size the value to the
	## row, so a row's words never reach its divider. {x, y, w, h,
	## label_at, label_size, value_at, value_size, note_at, note_size,
	## divider (its y, or 0 for none), label_box, value_box (the glyphs'
	## extent: caps 0.72 of the size up, descenders 0.22 down)}.
	var per_col := maxi(ceili(n / 2.0), 1)
	var cw := (R.size.x - 24.0) * 0.5
	var rh := minf((R.size.y - 20.0) / per_col, 50.0)
	var cx := R.position.x + 12.0 + (i / per_col) * cw
	var cy := R.position.y + 14.0 + (i % per_col) * rh
	var ls := 10
	var vs := 20
	var ns := 12
	var lb := cy + 14.0
	var vb := cy + 36.0
	var dv := cy + rh - 3.0
	if rh < 44.0:
		ls = 9
		vs = clampi(floori((rh - 14.5) / 0.94), 13, 20)
		ns = clampi(vs - 5, 10, 12)
		lb = cy + 3.0 + 0.72 * ls
		vb = lb + 3.0 + 0.72 * vs
		dv = cy + rh - 1.0
	if i % per_col == per_col - 1 or i == n - 1:
		dv = 0.0
	var vw := UI.text_width(value, vs, "body", 700) if value != "" else 0.0
	return {"x": cx, "y": cy, "w": cw, "h": rh,
			"label_at": Vector2(cx + 4.0, lb), "label_size": ls,
			"value_at": Vector2(cx + 4.0, vb), "value_size": vs,
			"note_at": Vector2(cx + 12.0 + vw, vb - (1.0 if vs >= 20 else 0.0)), "note_size": ns,
			"divider": dv,
			"label_box": Rect2(cx + 4.0, lb - 0.72 * ls, cw - 8.0, 0.72 * ls),
			"value_box": Rect2(cx + 4.0, vb - 0.72 * vs, maxf(vw, 1.0), 0.94 * vs)}


func satchel_line(h: Dictionary, g: Node) -> String:
	## How full the satchel is, against Game's cap.
	return UI.satchel_line((h.get("satchel", []) as Array).size(), int(g.SATCHEL_MAX) if g else 16)


func _next_unlock(level: int) -> String:
	return next_unlock(_cls(), level)


static func next_unlock(cls: String, level: int) -> String:
	## The next thing a level brings a hero of this calling at this level
	## (the Stats tab's Next line): a root rank, a belt slot, a tier (the
	## deep tree's 4 and 5, the second capstone), Candlemarks past the cap.
	for l in range(level + 1, Progression.CAP + 1):
		var what := unlock_at(cls, l)
		if what != "":
			return "Level %d: %s." % [l, what]
	if level >= Progression.CAP:
		return "Every %d XP past level %d: a Candlemark, +1%% damage and life." % [Progression.MARK_XP, Progression.CAP]
	return ""


static func next_unlock_level(cls: String, level: int) -> int:
	## The level next_unlock names (0: none before the cap).
	for l in range(level + 1, Progression.CAP + 1):
		if unlock_at(cls, l) != "":
			return l
	return 0


static func unlock_at(cls: String, l: int, skip_belt := false) -> String:
	## What reaching level l brings ("" when nothing): a relic belt slot,
	## the capstones (L8), a root rank, the Deep and Mastery tiers (L16,
	## L24), the other capstone (L30); the first of them when two land on
	## one level (skip_belt: the first but a belt slot). The level-up card
	## names it too (hud.level_up).
	var root_name := ""
	var deep := false
	for n in Classes.tree(cls):
		if n["branch"] == -1:
			root_name = n["name"]
		if int(n["tier"]) >= 4:
			deep = true
	var gate: Array = Classes.ROOT_GATE if deep else [0, 3, 6, 9, 12]
	if not skip_belt and Progression.belt_slots(l) > Progression.belt_slots(l - 1):
		return "a relic belt slot (%d)" % Progression.belt_slots(l)
	if l == CAPSTONE_LEVEL:
		return "the capstones (Tier 3)"
	var rank := gate.find(l)
	if rank > 0:
		return "%s rank %d" % [root_name, rank + 1]
	if deep:
		if l == int(Classes.GATES[4]["level"]):
			return "the Deep nodes (Tier 4)"
		if l == int(Classes.GATES[5]["level"]):
			return "the Mastery nodes (Tier 5)"
		if l == Classes.SECOND_CAPSTONE:
			return "the other capstone"
	return ""
