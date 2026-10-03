extends Node2D
## Everything that gives off light, drawn in world space on a layer above the
## Darkness so it never dims: candle flames (Wick's, the sconces', the lit
## altars'), embers, lava, relic beams, the stained glass, sparks and the
## sword's arc. Redrawn every frame. Also owns the bright particles.
##
## v3: the sparks are one TriBatch (one draw call for up to 400, a W5
## shatter's burst); flame(..., pal) takes a palette {out, mid, core, halo,
## shift, alpha} (empty = the candle's own colours; world.hero_flame holds
## the hero's); flames over a reflecting span (world.lights.mirrors: ice,
## the lake) get a squashed upside-down twin at alpha 0.3; and the mode's
## draw_glow(glow) runs after the features'.

const LevelData := preload("res://scripts/level_data.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TILE := LevelData.TILE
const FLAME_OUT := Color("f07a2a")
const FLAME_MID := Color("f7b64a")
const FLAME_CORE := Color("fff4cf")
const TEAR_POINTS := 22          # the rim of one flame teardrop (see _tear)
const MAX_SPARKS := 400
const SPARK_SEG := 64            # draw_circle's own segments: sparks look exactly as in v2
const MIRROR_ALPHA := 0.3        # a reflected flame (spec §11.2 F7)
const MIRROR_SQUASH := 0.6
const RARITY := {
	"common": Color("e8e0d0"), "magic": Color("6aa0ff"),
	"rare": Color("ffd84a"), "legendary": Color("ff8a2a"),
}

var world: Node
var extra_flames: Array = []     # {p, h}: flames to draw with no world (the title)
var sparks: Array = []           # {p, v, life, max, col, size, g}
var arcs: Array = []             # {p, facing, t, reach}
var pillars: Array = []          # {p, t}: the level-up beam
var _t := 0.0
var _sparks_tb := TriBatch.new()
var _hero_h := 0.0               # the hero's flame height this frame (his reflection)
# A teardrop's triangles: a fan from its round middle (the 23rd point) to its
# 22 rim points. Glow hands the renderer these itself instead of letting
# canvas_item_add_polygon triangulate the tear: that runs in world
# coordinates, and past x ~3000 a tear a pixel or two across (a badly hurt
# hero's flame, an ember's core) failed it now and then on float precision,
# an engine error and a missing core each time. The tear is convex, so the
# fan is always right, at any size and anywhere along a level.
var _tear_fan := _fan(TEAR_POINTS)


func _process(dt: float) -> void:
	_t += dt
	for s in sparks:
		s["life"] -= dt
		s["v"].y += s["g"] * dt
		s["p"] += s["v"] * dt
	sparks = sparks.filter(func(s): return s["life"] > 0.0)
	for a in arcs:
		a["t"] += dt
	arcs = arcs.filter(func(a): return a["t"] < 0.16)
	for p in pillars:
		p["t"] += dt
	pillars = pillars.filter(func(p): return p["t"] < 0.9)
	queue_redraw()


func pillar(p: Vector2) -> void:
	pillars.append({"p": p, "t": 0.0})


func burst(p: Vector2, n: int, col: Color, speed := 140.0, life := 0.5, g := 300.0, size := 2.5, up_bias := 0.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(0.3, 1.0) * speed
		v.y -= up_bias
		sparks.append({"p": p, "v": v, "life": life * randf_range(0.6, 1.0), "max": life, "col": col, "size": size * randf_range(0.7, 1.2), "g": g})
	if sparks.size() > MAX_SPARKS:
		sparks = sparks.slice(sparks.size() - MAX_SPARKS)


func slash(p: Vector2, facing: int, reach: float) -> void:
	arcs.append({"p": p, "facing": facing, "t": 0.0, "reach": reach})


func _draw() -> void:
	for f in extra_flames:
		flame(f["p"], f["h"], 0.0, true)
	if world == null:
		_draw_sparks()
		return
	var view: Rect2 = world.view_rect().grow(80.0)
	_lava(view)
	for s in world.sconces:
		if view.has_point(s):
			flame(s, 11.0, s.x * 0.13)
	for a in world.altars:
		if a["lit"] and view.has_point(a["flame"]):
			flame(a["flame"], 15.0 + a["glow"] * 10.0, a["flame"].x * 0.07)
	_draw_mirrors()
	if world.features:
		world.features.draw_glow(self)
	var md = world.get("mode")
	if md != null and md.has_method("draw_glow"):
		md.draw_glow(self)
	for p in world.pickups:
		if p["taken"] or not view.has_point(p["pos"]):
			continue
		match p["kind"]:
			"ember":
				_ember(p["pos"], p["t"])
			"relic", "item":
				_beam(p["pos"], RARITY.get(p["rarity"], Color.WHITE), p["t"])
				if p["kind"] == "item":
					_item_name(p)
			"sigil":
				_halo(p["pos"], Color("ffd84a"), 20.0 + sin(p["t"] * 3.0) * 2.0)
			"wax":
				pass
	if not world.pool.is_empty():
		_pool(world.pool)
	for sh in world.shots:
		_shot(sh)
	for h in world.hazards:
		_hazard(h)
	for e in world.enemies:
		if e.alive and e.active:
			e.draw_glow(self)
			if e.hp_bar > 0.0 and e != world.boss:
				_hp_bar(e)
	if world.kit:
		world.kit.draw(self)
	if bool(world.get("owls_eye")):
		_owl_glints(view)
	for p in pillars:
		_pillar(p)
	var pl: Node2D = world.player
	if pl != null:
		var fp: Vector2 = world.rig.flame_point()
		if pl.alive:
			var f: float = pl.life_frac()
			var h: float = (4.0 + 15.0 * f) * float(pl.stats.get("flame_scale", 1.0))
			if pl.hurt_time < 0.3:
				h *= 0.45 + pl.hurt_time * 1.5
			if f < 0.25:
				h *= 1.0 + 0.25 * sin(_t * 24.0)
			if pl.has_status("douse"):
				h *= 0.6
			_hero_h = h
			var hp := _hero_pal(pl, f)
			# The wind bends it (W5's gusts: from the tell on; world.features.wind_at).
			var wind := 0.0
			if world.features and world.features.has_method("wind_at"):
				wind = float(world.features.wind_at(fp))
			if wind != 0.0:
				hp = hp.duplicate()
				hp["lean"] = wind
			flame(fp, h, 0.0, true, f < 0.25 or pl.has_status("douse"), hp)
		elif world.snuff_time < 1.2:
			# A thread of smoke where the flame was.
			var k: float = world.snuff_time
			for i in 5:
				var y := -k * 30.0 - i * 6.0
				draw_circle(fp + Vector2(sin(_t * 4.0 + i) * 3.0, y), 2.5 + i * 0.6, Color(0.7, 0.68, 0.75, maxf(0.0, 0.5 - k * 0.4 - i * 0.07)))
	for a in arcs:
		_arc(a)
	_draw_sparks()
	world.floaters.draw(self)


func _draw_sparks() -> void:
	## Every spark in one triangle array (one draw call, where v2 spent one a
	## spark), each draw_circle's exact 64-sided shape (the same pixels).
	if sparks.is_empty():
		return
	var n := sparks.size()
	var ps := PackedVector2Array()
	var rs := PackedFloat32Array()
	var cs := PackedColorArray()
	ps.resize(n)
	rs.resize(n)
	cs.resize(n)
	for i in n:
		var s: Dictionary = sparks[i]
		var k: float = s["life"] / s["max"]
		var c: Color = s["col"]
		c.a = clampf(k * 1.5, 0.0, 1.0)
		ps[i] = s["p"]
		rs[i] = s["size"] * (0.5 + 0.5 * k)
		cs[i] = c
	_sparks_tb.circles(ps, rs, cs, SPARK_SEG)
	_sparks_tb.flush(self)


func spark_count() -> int:
	return sparks.size()


func _draw_mirrors() -> void:
	## The flames' upside-down twins in the ice and the lake (the mirror
	## points world_lights.gd found this frame).
	var wl = world.get("lights")
	if wl == null or not (wl is Object) or not ("mirrors" in wl):
		return
	for m in wl.mirrors:
		var h: float = float(m["h"])
		if bool(m.get("hero", false)):
			h = _hero_h
		if h <= 0.5:
			continue
		mirror_flame(m["p"], h, float(m.get("seed", 0.0)))


func mirror_flame(base: Vector2, h: float, seed: float, pal := {}) -> void:
	## A flame reflected in a surface below it: flipped, squashed to 0.6 of
	## its height, at alpha 0.3. base is the mirror point of the flame's base.
	var p2 := pal.duplicate()
	p2["alpha"] = float(pal.get("alpha", 1.0)) * MIRROR_ALPHA
	draw_set_transform(base, 0.0, Vector2(1.0, -MIRROR_SQUASH))
	flame(Vector2.ZERO, h, seed, false, false, p2)
	draw_set_transform_matrix(Transform2D.IDENTITY)


# Hushed (spec §4.1): his flame goes violet-black round a pale core.
const HUSHED_PAL := {"out": Color("2a1d3e"), "mid": Color("4b3a70"), "core": Color("e6e0f5"), "halo": Color("6a5a9a")}


func _hero_pal(pl: Node2D, f: float) -> Dictionary:
	## The hero's flame colours: hushed first (the W6 dim), then his own
	## candle's while doused, guttering low or burning with Gutterlight (they
	## override a cosmetic flame: spec §7.5), else world.hero_flame.
	var dm = world.call("dims") if world.has_method("dims") else {}
	if dm is Dictionary and dm.has("hushed"):
		return HUSHED_PAL
	if pl.has_status("douse") or f < 0.25:
		return {}
	var st = pl.get("stats")
	if st is Dictionary and (st.get("legends", {}) as Dictionary).has("gutterlight"):
		var fl = st.get("flags", {})
		if f < float(fl.get("gutterlight_below", 0.35) if fl is Dictionary else 0.35):
			return {}
	var hp = world.get("hero_flame")
	return hp if hp is Dictionary else {}


func flame(base: Vector2, h: float, seed: float, big := false, guttering := false, pal := {}) -> void:
	## A cel-shaded candle flame: three teardrops, flickering. pal (optional)
	## recolours it: {out, mid, core: Color; halo: Color (its alpha is kept
	## from the flame's own); shift: hue turns a second (a cycling flame);
	## alpha: a multiplier on every part}. Empty is today's candle.
	if h <= 0.5:
		return
	var fl := 1.0 + 0.09 * sin(_t * 17.0 + seed) + 0.05 * sin(_t * 31.0 + seed * 2.0)
	if guttering:
		fl = 1.0 + 0.22 * sin(_t * 23.0 + seed) + 0.12 * sin(_t * 41.0)
	var sway := sin(_t * 6.5 + seed) * h * 0.08
	var hh := h * fl
	var lean: float = float(pal.get("lean", 0.0))
	if lean != 0.0:
		# Bent by the wind: the tip goes downwind, the flame a little lower,
		# flickering harder.
		sway = sway * (1.0 + absf(lean)) + lean * h * 0.62 + sin(_t * 23.0 + seed) * absf(lean) * h * 0.06
		hh *= 1.0 - 0.14 * absf(lean)
	var r := h * 0.32
	var c_out := FLAME_OUT
	var c_mid := FLAME_MID
	var c_core := FLAME_CORE
	var halo := Color(1.0, 0.7, 0.3, 0.10 if big else 0.07)
	var halo2 := Color(1.0, 0.75, 0.35, halo.a * 1.4)
	if not pal.is_empty():
		c_out = pal.get("out", c_out)
		c_mid = pal.get("mid", c_mid)
		c_core = pal.get("core", c_core)
		if pal.has("halo"):
			var hc: Color = pal["halo"]
			halo = Color(hc.r, hc.g, hc.b, halo.a)
			halo2 = Color(hc.lightened(0.1).r, hc.lightened(0.1).g, hc.lightened(0.1).b, halo2.a)
		var shift: float = float(pal.get("shift", 0.0))
		if shift != 0.0:
			var dh := fposmod(_t * shift, 1.0)
			c_out = _hue(c_out, dh)
			c_mid = _hue(c_mid, dh)
			c_core = _hue(c_core, dh)
		var al: float = float(pal.get("alpha", 1.0))
		if al != 1.0:
			c_out.a *= al
			c_mid.a *= al
			c_core.a *= al
			halo.a *= al
			halo2.a *= al
	# A soft halo, in flat rings.
	draw_circle(base + Vector2(0, -hh * 0.4), hh * 1.25, halo)
	draw_circle(base + Vector2(0, -hh * 0.4), hh * 0.85, halo2)
	_fill_tear(base, r, hh, sway, c_out)
	_fill_tear(base + Vector2(0, -r * 0.1), r * 0.72, hh * 0.78, sway * 0.8, c_mid)
	_fill_tear(base + Vector2(0, -r * 0.2), r * 0.42, hh * 0.5, sway * 0.5, c_core)


static func _hue(c: Color, dh: float) -> Color:
	return Color.from_hsv(fposmod(c.h + dh, 1.0), c.s, c.v, c.a)


func _fill_tear(base: Vector2, r: float, h: float, sway: float, col: Color) -> void:
	var pts := _tear(base, r, h, sway)
	pts.append(base + Vector2(0.0, -r))       # the hub: the round part's middle
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _tear_fan, pts, PackedColorArray([col]))


static func _fan(n: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for i in n:
		idx.append_array([n, i, (i + 1) % n])
	return idx


func _tear(base: Vector2, r: float, h: float, sway: float) -> PackedVector2Array:
	## TEAR_POINTS points round a teardrop: the round bottom, then up the
	## left side to the tip and down the right.
	var pts := PackedVector2Array()
	for k in range(0, 11):
		var a := PI * k / 10.0
		pts.append(base + Vector2(r * cos(a), -r + r * sin(a)))
	var tip := base + Vector2(sway, -h)
	var left := base + Vector2(-r, -r)
	var ctrl_l := base + Vector2(-r * 0.95, -h * 0.55)
	for k in range(1, 7):
		var s := k / 6.0
		pts.append(left.lerp(ctrl_l, s).lerp(ctrl_l.lerp(tip, s), s))
	var right := base + Vector2(r, -r)
	var ctrl_r := base + Vector2(r * 0.95, -h * 0.55)
	for k in range(1, 6):
		var s := k / 6.0
		pts.append(tip.lerp(ctrl_r, s).lerp(ctrl_r.lerp(right, s), s))
	return pts


func _ember(p: Vector2, t: float) -> void:
	var bob := sin(t * 3.0 + p.x * 0.05) * 2.0
	var c := p + Vector2(0, bob)
	var pulse := 0.5 + 0.5 * sin(t * 5.0 + p.x)
	draw_circle(c, 9.0, Color(1.0, 0.6, 0.2, 0.10 + 0.05 * pulse))
	draw_circle(c, 6.0, Color("2a1410"))
	draw_circle(c, 5.0, Color("e0602a"))
	draw_circle(c + Vector2(-1, -1), 3.2, FLAME_MID)
	draw_circle(c + Vector2(-1.5, -1.5), 1.5, FLAME_CORE)
	flame(c + Vector2(0, -3), 6.0, p.x)


func _halo(p: Vector2, col: Color, r: float) -> void:
	var c := col
	c.a = 0.12
	draw_circle(p, r, c)
	c.a = 0.18
	draw_circle(p, r * 0.7, c)


func _beam(p: Vector2, col: Color, t: float) -> void:
	## The loot beam: a column of the rarity's color standing on the item.
	var h := 150.0
	var grow := clampf(t * 3.0, 0.0, 1.0)
	for i in 3:
		var w := (18.0 - i * 5.0)
		var c := col
		c.a = (0.10 + 0.08 * i) * grow
		draw_rect(Rect2(p.x - w * 0.5, p.y - h * grow + 8.0, w, h * grow), c)
	_halo(p, col, 22.0 + sin(t * 4.0) * 2.0)


func _shot(sh: Dictionary) -> void:
	## Projectiles by kind; anything unknown is a small glowing orb.
	var p: Vector2 = sh["pos"]
	var v: Vector2 = sh["vel"]
	var dir := v.normalized() if v.length() > 1.0 else Vector2.RIGHT
	match sh["kind"]:
		"spark", "bolt", "flare":
			var big: float = 1.6 if sh["kind"] == "flare" else 1.0
			draw_circle(p, 9.0 * big, Color(1.0, 0.6, 0.2, 0.18))
			flame(p + Vector2(0, 6) * big, 13.0 * big, p.x)
			draw_circle(p, 3.2 * big, FLAME_CORE)
		"knife":
			var a := p - dir * 8.0
			var b := p + dir * 8.0
			draw_line(a, b, Color("1c1830"), 5.0)
			draw_line(a + dir * 2.0, b, Color("e8ecf4"), 2.5)
			draw_line(a, a + dir * 4.0, Color("8a6444"), 3.0)
		"arrow":
			var a := p - dir * 9.0
			draw_line(a, p + dir * 9.0, Color("2a2030"), 4.5)
			draw_line(a, p + dir * 9.0, Color("efe6d2"), 2.0)
			draw_colored_polygon(PackedVector2Array([p + dir * 12.0, p + dir * 6.0 + dir.orthogonal() * 4.0, p + dir * 6.0 - dir.orthogonal() * 4.0]), Color("c8c8d4"))
			if sh["owner"] == "player":
				draw_circle(p, 8.0, Color(1.0, 0.9, 0.5, 0.25))
		"mote":
			draw_circle(p, 7.0, Color(0.75, 0.78, 0.94, 0.25))
			draw_circle(p, 3.5, Color("e8ecff"))
		"crescent":
			var o := dir.orthogonal()
			var pts := PackedVector2Array()
			for i in 9:
				var k := (i / 8.0) * 2.0 - 1.0
				pts.append(p + o * k * 16.0 + dir * (1.0 - k * k) * 8.0)
			for i in range(8, -1, -1):
				var k := (i / 8.0) * 2.0 - 1.0
				pts.append(p + o * k * 14.0 + dir * (1.0 - k * k) * 2.0)
			draw_colored_polygon(pts, Color(1.0, 0.96, 0.8, 0.8))
		_:
			draw_circle(p, 8.0, Color(1.0, 0.7, 0.3, 0.2))
			draw_circle(p, 3.5, FLAME_MID if sh["owner"] == "player" else Color("c0c8f0"))


func _bolt(b: Dictionary) -> void:
	_shot({"kind": "bolt", "pos": b["pos"], "vel": b.get("vel", Vector2.ZERO), "owner": "player"})


func _hp_bar(e: Node2D) -> void:
	var r: Rect2 = e.rect()
	var w := 26.0
	var at := Vector2(r.get_center().x - w * 0.5, r.position.y - 10.0)
	var frac: float = clampf(e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0)
	var edge := Color("1c1830")
	if e.tier == "anointed":
		edge = Color("6aa0ff")
	elif e.tier == "dread":
		edge = Color("ffd84a")
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, 6)), edge)
	draw_rect(Rect2(at, Vector2(w, 4)), Color("2a1418"))
	draw_rect(Rect2(at, Vector2(w * minf(frac + e.recent, 1.0), 4)), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(at, Vector2(w * frac, 4)), Color("e04a4a"))


func _item_name(p: Dictionary) -> void:
	var pl: Node2D = world.player
	if pl == null or pl.position.distance_to(p["pos"]) > 96.0:
		return
	var it: Dictionary = p["item"]
	var UIk = load("res://scripts/ui.gd")
	var f: Font = UIk.font("body", 700)
	var w := f.get_string_size(it["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var at: Vector2 = p["pos"] + Vector2(-w * 0.5, -22.0)
	draw_string_outline(f, at, it["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color("120d1a"))
	draw_string(f, at, it["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RARITY.get(it["rarity"], Color.WHITE))
	if p.get("full", false):
		# Turned away by a full satchel: it waits here, and says why.
		var tag := "SATCHEL FULL"
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var tat: Vector2 = p["pos"] + Vector2(-tw * 0.5, -35.0)
		draw_string_outline(f, tat, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 4, Color("120d1a"))
		draw_string(f, tat, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("e8866a"))


func _pool(pool: Dictionary) -> void:
	## The Guttered Pool: spilled embers glowing in a puddle of wax.
	var p: Vector2 = pool["pos"]
	var pulse := 0.5 + 0.5 * sin(float(pool["t"]) * 3.0)
	draw_circle(p + Vector2(0, 4), 22.0, Color(1.0, 0.7, 0.3, 0.12 + 0.06 * pulse))
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(p + Vector2(cos(a) * 18.0, sin(a) * 5.0 + 4.0))
	draw_colored_polygon(pts, Color("efe6cc"))
	for i in 5:
		var q := p + Vector2(-10 + i * 5.0, 2.0 + sin(float(pool["t"]) * 4.0 + i) * 1.5)
		draw_circle(q, 2.2, FLAME_MID)


func _pillar(p: Dictionary) -> void:
	var k: float = p["t"] / 0.9
	var a := (1.0 - k) * 0.5
	var w := 30.0 * (1.0 - k * 0.5)
	draw_rect(Rect2(p["p"].x - w * 0.5, p["p"].y - 400.0, w, 400.0), Color(1.0, 0.9, 0.5, a * 0.5))
	draw_rect(Rect2(p["p"].x - w * 0.2, p["p"].y - 400.0, w * 0.4, 400.0), Color(1.0, 1.0, 0.85, a))
	draw_arc(p["p"] + Vector2(0, -20), 20.0 + k * 90.0, 0, TAU, 32, Color(1.0, 0.85, 0.4, a), 3.0)


func _hazard(h: Dictionary) -> void:
	var r: Rect2 = h["rect"]
	if h.get("delay", 0.0) > 0.0:
		# A falling thing's shadow on the floor first (the tell).
		if h.get("shadow", false) and world:
			var fx := r.get_center().x
			var fy := _floor_below(Vector2(fx, maxf(r.position.y, world.view_rect().position.y)))
			# It grows over the hazard's own wait (delay0, set by add_hazard):
			# a dark spot swelling under a pale ring that closes in on it,
			# so it reads on a dark floor too. The Drip Choir draws its own.
			var wait := float(h.get("delay0", 0.6))
			var k := 1.0 - clampf(float(h["delay"]) / maxf(wait, 0.05), 0.0, 1.0)
			var at := Vector2(fx, fy - 2.0)
			var half := maxf(r.size.x * 0.5, 8.0)
			draw_colored_polygon(_ellipse(at, half * (0.6 + 0.6 * k), 3.0 + 1.5 * k), Color(0, 0, 0, 0.45 + 0.3 * k))
			if not h.get("choir", false):
				var ring := half * (2.6 - 1.4 * k)
				var pts := _ellipse(at, ring, ring * 0.3)
				pts.append(pts[0])
				draw_polyline(pts, Color(0.98, 0.9, 0.72, 0.25 + 0.6 * k), 1.5 + k)
		return
	match h["kind"]:
		"wave":
			var c := Vector2(r.get_center().x, r.end.y)
			var d := signf(h["vel"].x)
			var mine: bool = h.get("owner", "enemy") == "player"
			var tone := Color(1.0, 0.8, 0.45, 0.6) if mine else Color(0.75, 1.0, 0.92, 0.55)
			var pts := PackedVector2Array([c + Vector2(-d * 16, 0), c + Vector2(-d * 6, -22 - sin(_t * 30.0) * 3.0), c + Vector2(d * 4, -14), c + Vector2(d * 12, 0)])
			draw_colored_polygon(pts, tone)
			var inner := PackedVector2Array([c + Vector2(-d * 10, 0), c + Vector2(-d * 5, -13), c + Vector2(d * 5, 0)])
			draw_colored_polygon(inner, Color(1, 1, 1, 0.8))
		"skull":
			var c := r.get_center()
			draw_circle(c, 10.0, Color("2a2030"))
			draw_circle(c, 8.5, Color("efe6d2"))
			var spin := _t * 10.0 * signf(h["vel"].x)
			var e := Vector2(cos(spin), sin(spin)) * 3.0
			draw_circle(c + e + Vector2(-3, -1), 2.2, Color("7ef0c8"))
			draw_circle(c + e + Vector2(3, -1), 2.2, Color("7ef0c8"))
		"rubble":
			var c := r.get_center()
			draw_rect(Rect2(c - Vector2(12, 12), Vector2(24, 24)), Color("17121f"))
			draw_rect(Rect2(c - Vector2(10, 10), Vector2(20, 20)), Color("62505e"))
			draw_rect(Rect2(c - Vector2(10, 10), Vector2(20, 5)), Color("8a7488"))
		"fire":
			for i in 3:
				flame(Vector2(r.position.x + (i + 0.5) * r.size.x / 3.0, r.end.y), 9.0 + 3.0 * sin(_t * 9.0 + i), r.position.x + i)
		"smoke":
			for i in 4:
				draw_circle(r.position + Vector2(r.size.x * (i + 0.5) / 4.0, r.size.y * 0.5 + sin(_t * 5.0 + i) * 3.0), r.size.y * 0.4, Color(0.55, 0.52, 0.62, 0.55))
		"drip":
			var c := r.get_center()
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 3), c + Vector2(0, 7), c + Vector2(-5, 3)]), Color("bfe8ff"))
		"shard":
			# A Vengeful foe's splinter of hushed wax: a pale diamond, point first.
			var c := r.get_center()
			var v: Vector2 = h["vel"]
			var d := v.normalized() if v.length() > 1.0 else Vector2.RIGHT
			var o := d.orthogonal()
			draw_circle(c, 7.0, Color(0.75, 0.6, 1.0, 0.22))
			draw_colored_polygon(PackedVector2Array([c + d * 7.0, c + o * 3.0, c - d * 5.0, c - o * 3.0]), Color("2a1f3a"))
			draw_colored_polygon(PackedVector2Array([c + d * 5.5, c + o * 1.8, c - d * 3.5, c - o * 1.8]), Color("e6dcff"))
		_:
			draw_rect(r, Color(1.0, 0.6, 0.6, 0.5))


func _owl_glints(view: Rect2) -> void:
	## The Owl's Eye relic: sigils, false stone and mimics glint in the dark
	## (a slow four-point twinkle each, near enough to matter).
	var pl: Node2D = world.player
	if pl == null or not pl.alive:
		return
	var near: Vector2 = pl.center()
	var spots: Array = []
	for p in world.pickups:
		if p["kind"] == "sigil" and not p["taken"] and not p.get("ghost", false):
			spots.append(p["pos"])
	var cells = world.features.get("false_cells") if world.features else null
	if cells is Array:
		for c in cells:
			if world.level.tile(c.x, c.y) == LevelData.FALSE_STONE:
				spots.append(Vector2(c.x * TILE + 11.0, c.y * TILE + 9.0))
	for e in world.enemies:
		if e.alive and e.kind == "lidlurk" and str(e.get("state")) == "sleep":
			spots.append(e.center() + Vector2(-6.0, -8.0))
	var n := 0
	for s in spots:
		if n >= 12:
			break
		if not view.has_point(s) or s.distance_to(near) > 300.0:
			continue
		n += 1
		var k := 0.5 + 0.5 * sin(_t * 2.6 + s.x * 0.37 + s.y * 0.11)
		var arm := 3.0 + 5.0 * k
		var c := Color(0.85, 0.95, 1.0, 0.35 + 0.55 * k)
		draw_circle(s, 5.0 + 3.0 * k, Color(0.7, 0.85, 1.0, 0.10 + 0.10 * k))
		draw_line(s + Vector2(-arm, 0), s + Vector2(arm, 0), c, 1.4)
		draw_line(s + Vector2(0, -arm), s + Vector2(0, arm), c, 1.4)
		draw_circle(s, 1.6, Color(1, 1, 1, 0.9))


func _floor_below(p: Vector2) -> float:
	var ty := floori(p.y / TILE)
	while ty < 40:
		if world.solid_at(Vector2(p.x, ty * TILE + 1.0)):
			return ty * TILE
		ty += 1
	return p.y + 200.0


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _arc(a: Dictionary) -> void:
	## The sword's swish: a crescent from over the head to the front.
	var k: float = a["t"] / 0.16
	var p: Vector2 = a["p"]
	var f: int = a["facing"]
	var rr: float = 30.0 * a["reach"]
	var pts := PackedVector2Array()
	var a0 := -100.0
	var a1 := 60.0
	var n := 14
	for i in n + 1:
		var ang := deg_to_rad(lerpf(a0, a1, float(i) / n))
		pts.append(p + Vector2(cos(ang) * f, sin(ang)) * rr)
	for i in range(n, -1, -1):
		var ang := deg_to_rad(lerpf(a0, a1, float(i) / n))
		var w := sin(PI * float(i) / n) * 9.0
		pts.append(p + Vector2(cos(ang) * f, sin(ang)) * (rr - w))
	var c := Color(1.0, 0.95, 0.85, 0.75 * (1.0 - k))
	if pts.size() >= 3:
		draw_colored_polygon(pts, c)


func _lava(view: Rect2) -> void:
	var lvl: RefCounted = world.level
	var x0 := maxi(floori(view.position.x / TILE), 0)
	var x1 := mini(ceili(view.end.x / TILE), lvl.width - 1)
	var y0 := maxi(floori(view.position.y / TILE), 0)
	var y1 := mini(ceili(view.end.y / TILE), lvl.height - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if lvl.tile(x, y) != LevelData.LAVA:
				continue
			var top = lvl.tile(x, y - 1) != LevelData.LAVA
			var p := Vector2(x * TILE, y * TILE)
			if top:
				var pts := PackedVector2Array()
				for i in 9:
					var xx := p.x + i * 4.0
					pts.append(Vector2(xx, p.y + 9.0 + sin(_t * 2.4 + xx * 0.12) * 2.2))
				pts.append(Vector2(p.x + TILE, p.y + TILE))
				pts.append(Vector2(p.x, p.y + TILE))
				draw_colored_polygon(pts, Color("c8352a"))
				var crest := PackedVector2Array()
				for i in 9:
					var xx := p.x + i * 4.0
					crest.append(Vector2(xx, p.y + 9.0 + sin(_t * 2.4 + xx * 0.12) * 2.2))
				draw_polyline(crest, Color("f7b64a"), 3.0)
				if fmod(_t * 0.7 + x * 0.37, 1.0) < 0.3:
					var bx := p.x + 8.0 + fmod(x * 13.7, 16.0)
					draw_circle(Vector2(bx, p.y + 13.0), 2.5 + fmod(_t * 0.7 + x * 0.37, 1.0) * 6.0, Color("f28a2b"))
			else:
				draw_rect(Rect2(p, Vector2(TILE, TILE)), Color("a82a22"))
			draw_rect(Rect2(p + Vector2(0, 18), Vector2(TILE, TILE - 18)), Color("8a1e1a"))
