extends RefCounted
## The modes' little pictures, drawn in code until A8's art lands (spec §7.6,
## p_modes §12: medals, seals, drips, Spare Wicks, Hushings, the doors):
## every round or pointed shape goes into a TriBatch (one draw call), rects
## are drawn straight. Each function that has an art file draws the file when
## it's there (loaded ahead through UI.tex, never first inside a draw).

const TriBatch := preload("res://scripts/tri_batch.gd")
const UI := preload("res://scripts/ui.gd")

const MEDAL_COL := [Color("5a4a6a"), Color("b07a3a"), Color("c8d0e0"), Color("ffd84a"), Color("fff4e0")]
const MEDAL_ART := ["medal_none", "medal_bronze", "medal_silver", "medal_gold", "medal_dawn"]
const SEAL_COL := [Color("3a3148"), Color("b07a3a"), Color("c8d0e0"), Color("ffd84a")]
const WAX := Color("f4e6c8")
const TAPER := Color("7a5aa8")
const HUSH := Color("5a4a8a")


static func warm() -> void:
	for n in MEDAL_ART + ["seal_bronze", "seal_silver", "seal_gold", "drip", "spare_wick", "hushing"]:
		UI.tex("res://art/ui/%s.svg" % n)


static func art(name: String) -> Texture2D:
	return UI.tex("res://art/ui/%s.svg" % name)


static func medal(ci: CanvasItem, tb: RefCounted, c: Vector2, r: float, m: int, a := 1.0) -> void:
	## A medal (0 none .. 4 Dawn): a disc on a ribbon, a candle stamp (a
	## sunrise on Dawn). The art's medal_<kind>.svg when it's there.
	var t := art(MEDAL_ART[clampi(m, 0, 4)])
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a))
		return
	var col: Color = MEDAL_COL[clampi(m, 0, 4)]
	if m <= 0:
		tb.ring(c, r * 0.85, maxf(r * 0.12, 1.5), Color(col, 0.9 * a), 20)
		return
	# The ribbon.
	tb.quad(c + Vector2(-r * 0.55, -r * 1.25), c + Vector2(-r * 0.15, -r * 1.25), c + Vector2(r * 0.05, -r * 0.4), c + Vector2(-r * 0.35, -r * 0.4), Color(Color("7a2a2a"), a))
	tb.quad(c + Vector2(r * 0.15, -r * 1.25), c + Vector2(r * 0.55, -r * 1.25), c + Vector2(r * 0.35, -r * 0.4), c + Vector2(-r * 0.05, -r * 0.4), Color(Color("a83a3a"), a))
	tb.circle(c, r + 1.5, Color(UI.INK, 0.9 * a), 22)
	tb.circle(c, r, Color(col, a), 22)
	tb.circle(c, r * 0.72, Color(col.darkened(0.18), a), 22)
	if m == 4:
		# A sunrise: a half sun and rays.
		tb.circle(c + Vector2(0, r * 0.18), r * 0.3, Color(Color("ffb84a"), a), 14)
		for i in 5:
			var ang := PI + PI * (i + 0.5) / 5.0
			tb.line(c + Vector2(0, r * 0.18) + Vector2(cos(ang), sin(ang)) * r * 0.36, c + Vector2(0, r * 0.18) + Vector2(cos(ang), sin(ang)) * r * 0.56, maxf(r * 0.08, 1.2), Color(Color("ffb84a"), a))
		ci.draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.18), Vector2(r, r * 0.08)), Color(Color("ffb84a"), a))
	else:
		# A candle stamp.
		ci.draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.1), Vector2(r * 0.24, r * 0.5)), Color(col.darkened(0.45), a))
		tb.convex(PackedVector2Array([c + Vector2(0, -r * 0.5), c + Vector2(r * 0.13, -r * 0.18), c + Vector2(0, -r * 0.1), c + Vector2(-r * 0.13, -r * 0.18)]), Color(col.darkened(0.45), a))


static func seal(ci: CanvasItem, tb: RefCounted, c: Vector2, r: float, s: int, lit := true) -> void:
	## A wax seal (1 Bronze .. 3 Gold): a drip-edged disc with a bell stamp.
	var names := ["", "seal_bronze", "seal_silver", "seal_gold"]
	var t := art(names[clampi(s, 0, 3)]) if s > 0 else null
	var a := 1.0 if lit else 0.22
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a))
		return
	var col: Color = SEAL_COL[clampi(s, 0, 3)]
	if not lit:
		# Not earned: only its ring, faint.
		tb.ring(c, r * 0.8, maxf(r * 0.16, 1.2), Color(col, 0.4), 16)
		return
	var rim := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		var rr := r * (1.0 if i % 2 == 0 else 0.86)
		rim.append(c + Vector2(cos(ang), sin(ang)) * rr)
	tb.fan(c, rim, Color(col.darkened(0.35), a))
	tb.circle(c, r * 0.74, Color(col, a), 18)
	bell(tb, c, r * 0.9, Color(col.darkened(0.5), a))


static func bell(tb: RefCounted, c: Vector2, s: float, col: Color) -> void:
	tb.convex(PackedVector2Array([c + Vector2(-s * 0.17, -s * 0.34), c + Vector2(s * 0.17, -s * 0.34),
			c + Vector2(s * 0.25, s * 0.1), c + Vector2(s * 0.42, s * 0.28), c + Vector2(-s * 0.42, s * 0.28), c + Vector2(-s * 0.25, s * 0.1)]), col)
	tb.circle(c + Vector2(0, -s * 0.34), s * 0.17, col, 10)
	tb.circle(c + Vector2(0, s * 0.36), s * 0.09, col, 8)


static func drip(ci: CanvasItem, tb: RefCounted, c: Vector2, s: float, col := WAX) -> void:
	var t := art("drip")
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	var pts := PackedVector2Array()
	for i in 13:
		var ang := PI * i / 12.0
		pts.append(c + Vector2(cos(ang) * s * 0.3, s * 0.12 + sin(ang) * s * 0.3))
	pts.append(c + Vector2(0, -s * 0.46))
	tb.convex(pts, col)


static func spare_wick(ci: CanvasItem, tb: RefCounted, c: Vector2, s: float, lit := true) -> void:
	## A Spare Wick: a little candle stub, its flame lit or out.
	var t := art("spare_wick")
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 1.0 if lit else 0.35))
		return
	ci.draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.05), Vector2(s * 0.32, s * 0.5)), Color(Color("f4ead6"), 1.0 if lit else 0.35))
	if lit:
		tb.convex(PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.16, -s * 0.18), c + Vector2(0, -s * 0.06), c + Vector2(-s * 0.16, -s * 0.18)]), Color("f7b64a"))


static func hushing(ci: CanvasItem, tb: RefCounted, c: Vector2, s: float) -> void:
	var t := art("hushing")
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	tb.circle(c, s * 0.34, Color(HUSH, 0.95), 12)
	tb.ring(c, s * 0.42, maxf(s * 0.08, 1.0), Color(Color("c8d0e0"), 0.8), 14)


static func taper(ci: CanvasItem, tb: RefCounted, c: Vector2, s: float, lit: bool, t := 0.0) -> void:
	## A trial candle (the violet taper in an iron cup).
	ci.draw_rect(Rect2(c + Vector2(-s * 0.3, s * 0.34), Vector2(s * 0.6, s * 0.16)), Color("3a3148"))
	ci.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.3), Vector2(s * 0.36, s * 0.64)), TAPER.lightened(0.2) if lit else TAPER)
	if lit:
		var h := s * (0.5 + 0.05 * sin(t * 13.0))
		tb.convex(PackedVector2Array([c + Vector2(0, -s * 0.3 - h), c + Vector2(s * 0.14, -s * 0.42), c + Vector2(0, -s * 0.3), c + Vector2(-s * 0.14, -s * 0.42)]), Color("f7b64a"))


static func arch(tb: RefCounted, x: float, w: float, top: float, bottom: float, col: Color) -> void:
	## A pointed arch, filled (UI.arch's shape, in the batch).
	tb.concave(UI.arch_points(x, w, top, bottom), col)


static func glimmer_glyph(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	## A Glimmer's icon: UI.glyph's marks.
	UI.glyph(ci, kind, c, s, col)
