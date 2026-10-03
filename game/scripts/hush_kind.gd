extends RefCounted
## World 6's rules for every W6 kind (spec §4.5, contract §6.1), and the few
## helpers the W5-W6 kinds share (MB). Static only: a kind preloads it as
##     const HK := preload("res://scripts/hush_kind.gd")
##
## The W6 rules:
##   seen only in light   lit_alpha(e): 1.0 inside any gameplay light
##                        (world.lit_at), DARK_A (0.15) outside; never 0
##   eyes always drawn    draw_eyes(e, glow): pale dots over the dark, r >=
##                        EYE_R (3 px) at EYE_A (>= 0.9), whatever the alpha
##   silent until close   quiet(e, dist): no sound past QUIET_R (90 px);
##                        every tell has a glow cue, never sound alone
##   the look             a silver rim (RIM, 4 units = 2 px) round a body
##                        BODY; the stand-ins draw it, the art (A3) too
##
## The hushed status (spec §4.1): hush_player(world) dims him through the
## pipeline (world.dim("hushed", HUSHED_MULT, HUSHED_T)); a hush while
## hushed also costs DIFF.douse_pct of his life, like douse.
##
## Havens (decisions: a tag, not a radius): haven_at(world, p) asks the
## gameplay lights tagged haven, lantern, brazier, beacon, altar, toll or
## vigil (lanterns, braziers, Beacons, buoy tolls, lit altars, relit Vigil
## candles), never Wick's own. Hushlings stop at their edge.
##
## Fair pushes (spec §4.1 rule 3): over_pit(world, body) is true while a body
## is airborne over a pit, the void or deep water; no monster push starts
## then.
##
## The tuning tables: each kind keeps every number in one TUNE dictionary
## (a value, or {dusk, nightfall, witching}); pick(TUNE, diff, name) reads
## one.

const LevelData := preload("res://scripts/level_data.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const Combat := preload("res://scripts/combat.gd")
const TILE := 32
const DARK_A := 0.15             # a W6 body outside every light
const QUIET_R := 90.0            # px: a W6 kind is silent further off than this
const RIM := Color("c8c8f0")     # the silver rim (4 units, 2 px)
const RIM_PX := 2.0
const BODY := Color("2a2838")    # the body, 2 units lighter than the dark
const EYE := Color("e8e4ff")     # pale eyes
const EYE_R := 3.0
const EYE_A := 0.95
const OUTLINE := Color("1c1830")
const HUSHED_MULT := 0.7
const HUSHED_T := 3.0
const HAVEN_TAGS := ["haven", "lantern", "brazier", "beacon", "altar", "toll", "vigil"]
const W6_KINDS := ["hushling", "stillmaw", "unwick", "lurecoil"]
const POINTS := "res://art/enemies/points_monsters4.json"

static var _points := {}         # frame -> {eyes: [...], ...} from A3's points file
static var _points_read := false


# ---------------------------------------------------------------- the W6 rules

static func lit_alpha(e) -> float:
	## How much of a W6 body shows: 1.0 inside any gameplay light, DARK_A
	## outside (never 0: its eyes and tells show anyway). The body counts as
	## inside once its edge is (pad = half its smaller side), with lit_at's
	## 8 px of hysteresis kept per monster.
	if e == null or not is_instance_valid(e):
		return 1.0
	var w = e.get("world")
	if w == null or not w.has_method("lit_at"):
		return 1.0
	var sz: Vector2 = e.size if "size" in e else Vector2(20, 20)
	var pad := minf(sz.x, sz.y) * 0.5
	var at: Vector2 = e.center() if e.has_method("center") else e.position
	return 1.0 if w.lit_at(at, pad, {"key": "hk:%d" % e.get_instance_id()}) else DARK_A


static func draw_eyes(e, glow: Node2D, tb: RefCounted = null, r := EYE_R, col := EYE) -> void:
	## The eyes over the dark, always (a monster that can't be seen still
	## looks at you): a soft halo and a pale core, r >= EYE_R at EYE_A. Into
	## tb when given (the caller flushes), else a batch of its own.
	if e == null or glow == null:
		return
	var pts: Array = eyes_of(e)
	if pts.is_empty():
		return
	var own := tb == null
	var b = TriBatch.new() if own else tb
	var rr := maxf(r, EYE_R)
	for p in pts:
		b.circle(p, rr * 2.2, Color(col, 0.22), 12)
		b.circle(p, rr, Color(col, EYE_A), 10)
	if own:
		b.flush(glow)


static func eyes_of(e) -> Array:
	## A W6 kind's eyes, always (w6_eyes()); anything else's eye_points().
	## (eye_points() is what the World lights, 8 a screen at most: the W6
	## kinds give it only for an elite, as v2's kinds do, and draw their eyes
	## over the dark themselves.)
	if e.has_method("w6_eyes"):
		return e.w6_eyes()
	return e.eye_points() if e.has_method("eye_points") else []


static func quiet(e, dist := -1.0) -> bool:
	## Must it keep silent? A W6 kind (or anything Hushed) further than
	## QUIET_R px from Wick makes no sound; dist < 0 measures it here.
	if e == null:
		return true
	if e.has_method("has_omen") and e.has_omen("hushed"):
		return true
	if dist < 0.0:
		var w = e.get("world")
		var pl = w.get("player") if w != null else null
		if pl == null:
			return true
		dist = (e.center() as Vector2).distance_to(pl.center())
	return dist > QUIET_R


static func is_w6(kind: String) -> bool:
	return W6_KINDS.has(kind)


static func shade(e, col: Color, a := 1.0) -> Color:
	## A stand-in's colour: elites.pc()'s tint and hit flash, with its alpha
	## set here, once: col.a x the tint's x a (the caller's fade, and a W6
	## kind's own lit alpha). Whatever alpha pc() adds itself (MA's v3
	## elites.gd multiplies its fade and the Hushed Omen's alpha in) is
	## replaced, not stacked, so a death's fade is never squared; a W5 kind
	## keeps the Hushed Omen's alpha (_om_alpha), a W6 kind has its own.
	var c: Color = e.pc(col)
	var tn: Color = e.get("tint") if e.get("tint") is Color else Color.WHITE
	var om = e.get("_om_alpha")
	var extra := 1.0 if om == null or is_w6(str(e.get("kind"))) else float(om)
	c.a = col.a * tn.a * a * extra
	return c


static func own_alpha(e, seen: float) -> void:
	## A W6 kind's sprite alpha, set (not multiplied): its fade x its lit
	## alpha, whatever the elites step multiplied in before (the Hushed
	## Omen's alpha is the same rule, so it's never applied twice).
	var sp = e.get("sprite")
	if sp != null:
		var m: Color = sp.modulate
		m.a = clampf(float(e.get("fade")), 0.0, 1.0) * seen
		sp.modulate = m


# ---------------------------------------------------------------- packs

static func pack_count(world: Node, kind: String, leader_cell: Vector2i) -> int:
	## The extras a pack leader brought that are still alive (each carries
	## pack_of = its leader's cell).
	var n := 0
	if world == null:
		return n
	for e in world.enemies:
		if e.alive and e.kind == kind and e.get("pack_of") == leader_cell:
			n += 1
	return n


static func relit(e) -> bool:
	## True once after each relight (world.snuffs moved on, and he's back in
	## play) on a difficulty whose ordinary monsters come back: a pack
	## leader brings its pack back up to size then, as the World respawns
	## the placed ones. e keeps the count it last saw in _snuffs.
	var w = e.get("world")
	if w == null:
		return false
	var sn = w.get("snuffs")
	if sn == null:
		return false
	var seen := int(e.get("_snuffs"))
	if seen < 0:
		e.set("_snuffs", int(sn))
		return false
	if int(sn) == seen or str(w.get("state")) != "play":
		return false
	e.set("_snuffs", int(sn))
	return bool(Combat.diff(str(w.get("diff")))["respawn"])


# ---------------------------------------------------------------- statuses and lights

static func hush_player(world: Node) -> void:
	## The hushed status: his light x0.7 for 3 s through the dim pipeline; a
	## hush while he's already hushed costs DIFF.douse_pct, as douse does.
	if world == null or world.get("player") == null:
		return
	var pl: Node2D = world.player
	var hushed := false
	if world.has_method("dims"):
		hushed = (world.dims() as Dictionary).has("hushed")
	if hushed:
		world.hurt_player(float(Combat.diff(world.diff)["douse_pct"]), pl.position.x, "douse", null, {"pct": true, "no_knock": true})
	if world.has_method("dim"):
		world.dim("hushed", HUSHED_MULT, HUSHED_T)


static func haven_at(world: Node, p: Vector2, pad := 0.0) -> bool:
	## Is p inside a haven (a light Hushlings won't enter)? Wick's own light
	## never is one.
	if world == null:
		return false
	var ls: Array = []
	var wl = world.get("lights")
	if wl != null and wl.has_method("gameplay_lights"):
		ls = wl.gameplay_lights(true)       # world_lights' list, cached for the tick (lit_at's too)
	elif world.has_method("gameplay_lights"):
		ls = world.gameplay_lights(true)
	for l in ls:
		var tags := str(l.get("tag", ""))
		if tags == "hero":
			continue
		var ok := false
		for t in HAVEN_TAGS:
			if _has_tag(tags, t):
				ok = true
				break
		if not ok:
			continue
		var r := float(l.get("rule_r", l.get("r", 0.0))) + pad
		if (l["p"] as Vector2).distance_to(p) <= r:
			return true
	return false


static func _has_tag(tags: String, tag: String) -> bool:
	if tags == tag:
		return true
	if not tags.contains(","):
		return false
	for t in tags.split(","):
		if t.strip_edges() == tag:
			return true
	return false


# ---------------------------------------------------------------- fair pushes

static func over_pit(world: Node, body: Node2D) -> bool:
	## Airborne over a pit, the void or deep water (or lava, or spikes): the
	## column under his feet has no floor before one of those or the bottom.
	## On the floor, climbing, riding or hauling, never.
	if body == null or world == null or world.get("level") == null:
		return false
	if body.get("on_floor") or body.get("climbing") == true or body.get("riding") != null:
		return false
	var lt = body.get("ledge_t")
	if lt != null and float(lt) >= 0.0:
		return false
	var lv: RefCounted = world.level
	var x := floori(body.position.x / TILE)
	for y in range(maxi(floori(body.position.y / TILE), 0), lv.height):
		var t: int = lv.tile(x, y)
		if t == LevelData.LAVA or t == LevelData.SPIKES_UP:
			return true
		if t == LevelData.WATER:
			return lv.is_deep(x, y)
		if LevelData.is_solid(t) or LevelData.is_ledge(t):
			return false
	# Nothing under him but the bottom of the level: a pit (unless a mover is there).
	if "movers" in world:
		for m in world.movers:
			if m.present:
				var mr: Rect2 = m.rect()
				if body.position.x >= mr.position.x and body.position.x <= mr.end.x and mr.position.y >= body.position.y - 4.0:
					return false
	return true


# ---------------------------------------------------------------- tuning tables

static func pick(table: Dictionary, diff: String, name: String) -> float:
	## TUNE[name]: a value, or {dusk, nightfall, witching} (Dusk's when the
	## difficulty has none). 0 when missing (a test catches that).
	var v = table.get(name, 0.0)
	if v is Dictionary:
		return float(v.get(diff, v.get("dusk", 0.0)))
	return float(v)


static func diff_of(e) -> String:
	var w = e.get("world") if e != null else null
	if w != null and "diff" in w:
		return str(w.diff)
	return "dusk"


# ---------------------------------------------------------------- the art's points

static func frame_points(frame: String) -> Dictionary:
	## A frame's points from A3's points_monsters4.json ({} until it exists).
	if not _points_read:
		_points_read = true
		if FileAccess.file_exists(POINTS):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(POINTS))
			if parsed is Dictionary:
				_points = parsed
	var d = _points.get(frame, {})
	return d if d is Dictionary else {}


static func frame_eyes(frame: String) -> Array:
	## The eyes of a frame (frame units), whether the file lists one point
	## [x, y] or several [[x, y], ...]; [] when it doesn't say.
	var v = frame_points(frame).get("eyes", [])
	var out := []
	if v is Array and v.size() >= 2 and (v[0] is float or v[0] is int):
		out.append(Vector2(float(v[0]), float(v[1])))
	elif v is Array:
		for q in v:
			if q is Array and q.size() >= 2:
				out.append(Vector2(float(q[0]), float(q[1])))
	return out


# ---------------------------------------------------------------- stand-in drawing
# The kinds draw their stand-ins (until A3's frames) into a TriBatch: the cel
# look (a dark outline, a flat fill), no draw_circle / draw_colored_polygon /
# draw_polyline (contract §1).

static func o_ellipse(tb: RefCounted, c: Vector2, rx: float, ry: float, fill: Color, ol := 2.0, edge := OUTLINE) -> void:
	if ol > 0.0:
		tb.ellipse(c, rx + ol, ry + ol, edge, 16)
	tb.ellipse(c, rx, ry, fill, 16)


static func o_poly(tb: RefCounted, pts: PackedVector2Array, fill: Color, ol := 2.0, edge := OUTLINE) -> void:
	## A convex polygon with an outline pushed out from its middle.
	if pts.size() < 3:
		return
	if ol > 0.0:
		tb.convex(grow(pts, ol), edge)
	tb.convex(pts, fill)


static func grow(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - c).normalized() * by)
	return out


static func ellipse_pts(c: Vector2, rx: float, ry: float, n := 16, a0 := 0.0, a1 := TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var full := is_equal_approx(absf(a1 - a0), TAU)
	var m := n if full else n + 1
	for i in m:
		var a := a0 + (a1 - a0) * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func dashed(tb: RefCounted, pts: PackedVector2Array, w: float, col: Color, dash := 8.0, gap := 6.0) -> void:
	## A dashed line along the points (a Lurecoil's arc, a crack to come).
	var on := true
	var left := dash
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var at := 0.0
		while at < seg - 0.001:
			var step := minf(left, seg - at)
			var p0 := a.lerp(b, at / seg)
			var p1 := a.lerp(b, (at + step) / seg)
			if on:
				tb.line(p0, p1, w, col)
			at += step
			left -= step
			if left <= 0.001:
				on = not on
				left = dash if on else gap
