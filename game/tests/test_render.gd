extends SceneTree
## test_render (W0-render, v3 Phase 0): the render foundation keeps its
## contracts (contract.md §12, spec §11.2).
## - tri_batch.gd: every shape's vertices and indices, one flush = one
##   command, an empty flush draws nothing, the vertex ceiling, circles at 64
##   segments on draw_circle's own points (glow's sparks keep v2's pixels).
## - The dark: darkness.gdshader v3's uniforms (tints[48], hush_depth,
##   hero_guard), darkness_lit.gdshader for cutscene layers, Plan B's two
##   passes; the field, modelled here in GDScript, is v2's exactly with no tint
##   and no Hush light, and the hero guard keeps a Hush light out of the hero's
##   pool inside 0.6 of its radius.
## - world_lights.gd on a real headless World (every W1-W2 level, many camera
##   places): the v3 packer packs exactly the lights v2's world.gd packed; the
##   caps (Hush 6, decorative 10 and never the last 4 slots, altars and
##   lanterns 14); counts(); lit_at (gameplay lights only, tags, 8 px of
##   hysteresis); the dims (dim_resist, the floor, expiry); light_override;
##   reflections; set_dark / set_warm; Plan A and Plan B's nodes.
## - themes/loader.gd with the stub theme (tests/render/theme_stub.gd): the
##   merge, "dark" from dark_color, the painter / style dispatch and the plain
##   fallbacks; backdrop slices with windows made at build; tile_view's
##   painter path; the plain painter draws every v3 tile inside the static
##   chunk budget; v2's themes keep their path.
## - edge_lines.gd, ambient.gd: no chunks / no motes for v2's worlds; the
##   stub's lines and motes within their caps.
## - 16 x 16 tile chunks (the shapes plan's E4): a 15-row level is one row of
##   them laid out as before; the four painters' levels and their tall render
##   labs (levels/tall, 24 and 36 rows) paint exactly what whole columns did,
##   each chunk inside the budget; the World's grid, its bedrock and what a
##   redraw asks for (chunks_at); edge lines chunk the same way.
## - glow.gd: flame(..., pal), sparks in one batch, the mirror hook.
## - perf_meter.gd's line; the grep rule: no draw_circle,
##   draw_colored_polygon or draw_polyline in the new render files.
##     godot --headless --path game --script res://tests/test_render.gd

const LEVELS := ["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4"]
const NO_IMMEDIATE := ["draw_circle(", "draw_colored_polygon(", "draw_polyline("]
const STUB := "res://tests/render/theme_stub.gd"

var _passed := 0
var _failed := 0
var TriBatch: Script
var WorldLights: Script
var Themes: Script


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	TriBatch = load("res://scripts/tri_batch.gd")
	WorldLights = load("res://scripts/world_lights.gd")
	Themes = load("res://scripts/themes/loader.gd")
	await process_frame
	_test_tri_batch()
	await _test_tri_draw()
	_test_shader_files()
	_test_field_model()
	_test_grep()
	_test_themes()
	await _test_worlds_pack_like_v2()
	await _test_caps_and_counts()
	await _test_lit_at_and_dims()
	await _test_reflect_and_colors()
	await _test_plans()
	await _test_backdrop_and_tiles()
	await _test_edges_and_ambient()
	await _test_cell_chunks()
	await _test_glow()
	_test_perf_meter()
	print("test_render: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- tri_batch

func _valid(tb) -> bool:
	for i in tb.indices:
		if i < 0 or i >= tb.points.size():
			return false
	return tb.indices.size() % 3 == 0 and tb.points.size() == tb.colors.size()


func _test_tri_batch() -> void:
	var tb = TriBatch.new()
	var c := Color(1, 0.5, 0.2, 0.8)
	tb.tri(Vector2(0, 0), Vector2(4, 0), Vector2(0, 4), c)
	_check(tb.vertex_count() == 3 and tb.indices.size() == 3, "tri: 3 vertices, 1 triangle")
	tb.quad(Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4), c)
	_check(tb.vertex_count() == 7 and tb.indices.size() == 9, "quad: 4 vertices, 2 triangles")
	tb.rect(Rect2(10, 10, 5, 5), c)
	_check(tb.vertex_count() == 11, "rect: a quad")
	tb.circle(Vector2(20, 20), 5.0, c, 10)
	_check(tb.vertex_count() == 22 and tb.indices.size() == 15 + 30, "circle 10: a centre and 10 rim points, 10 triangles")
	tb.ellipse(Vector2(30, 20), 6.0, 3.0, c, 12)
	_check(tb.vertex_count() == 35, "ellipse 12: 13 points")
	tb.line(Vector2(0, 0), Vector2(10, 0), 2.0, c)
	var n: int = tb.vertex_count()
	_check(n == 39, "line: a quad")
	tb.polyline(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 12)]), 2.0, c)
	_check(tb.vertex_count() == n + 8, "polyline: two points a joint")
	tb.convex(PackedVector2Array([Vector2(0, 0), Vector2(5, -2), Vector2(8, 3), Vector2(2, 6)]), c)
	var before: int = tb.vertex_count()
	tb.origin = Vector2(4000, 0)
	tb.concave(PackedVector2Array([Vector2(4000, 0), Vector2(4010, 0), Vector2(4010, 10), Vector2(4005, 4), Vector2(4000, 10)]), c)
	_check(tb.vertex_count() == before + 5 and tb.indices.size() % 3 == 0, "concave: triangulated relative to the origin (far along a level)")
	tb.fan(Vector2(50, 50), PackedVector2Array([Vector2(55, 50), Vector2(50, 55), Vector2(45, 50), Vector2(50, 45)]), c)
	tb.ring(Vector2(60, 60), 8.0, 2.0, c, 12)
	_check(_valid(tb), "every index points at a vertex; colours per vertex")
	tb.clear()
	_check(tb.is_empty() and tb.vertex_count() == 0, "clear empties it")
	# The ceiling: refused shapes are counted, never half-added.
	var big = TriBatch.new()
	for i in 4000:
		big.circle(Vector2(i, 0), 2.0, c, 10)
	_check(big.vertex_count() <= TriBatch.MAX_VERTICES and big.dropped > 0 and _valid(big), "past MAX_VERTICES it refuses whole shapes (%d dropped)" % big.dropped)
	# Sparks: 400 at 64 segments fit, on draw_circle's own points.
	var sp = TriBatch.new()
	var ps := PackedVector2Array()
	var rs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in 400:
		ps.append(Vector2(i * 3.0, 7.0))
		rs.append(2.5)
		cs.append(c)
	sp.circles(ps, rs, cs, 64)
	_check(sp.vertex_count() == 400 * 65 and sp.dropped == 0 and _valid(sp), "400 sparks of 65 vertices fit one batch")
	var ok := true
	for k in 64:
		var a := k * 2.0 * PI / 64.0
		var want := Vector2(3.0, 7.0) + Vector2(cos(a), sin(a)) * 2.5
		if sp.points[65 + 1 + k].distance_to(want) > 1e-4:
			ok = false
	_check(ok, "a circle's rim is draw_circle's 64 points (angle k * 2pi / 64 from +x)")


func _test_tri_draw() -> void:
	## One flush is one command; an empty flush adds none (drawn headless).
	var node := Node2D.new()
	root.add_child(node)
	var tb = TriBatch.new()
	var calls := [0]
	node.draw.connect(func():
		tb.flush(node)            # empty: nothing
		tb.circle(Vector2(5, 5), 3.0, Color.RED)
		tb.line(Vector2(0, 0), Vector2(9, 9), 2.0, Color.WHITE)
		tb.flush(node)
		calls[0] += 1
	)
	node.queue_redraw()
	for i in 2:
		await process_frame
	_check(calls[0] == 1 and tb.is_empty(), "a flush inside _draw hands the batch over and clears it")
	node.queue_free()


# ---------------------------------------------------------------- the dark

func _uniforms(path: String) -> Array:
	var sh: Shader = load(path)
	var out := []
	if sh != null:
		for u in sh.get_shader_uniform_list():
			out.append(str(u["name"]))
	return out


func _test_shader_files() -> void:
	var need := ["view_size", "light_count", "lights", "tints", "dark_color", "warm_color", "hush_depth", "hero_guard"]
	var u := _uniforms("res://shaders/darkness.gdshader")
	for k in need:
		_check(u.has(k), "darkness.gdshader has the uniform %s" % k)
	var lit := _uniforms("res://shaders/darkness_lit.gdshader")
	for k in need:
		_check(lit.has(k), "darkness_lit.gdshader has the uniform %s" % k)
	var code := FileAccess.get_file_as_string("res://shaders/darkness.gdshader")
	_check(code.contains("render_mode blend_mul, unshaded;") and code.contains("vec2 p = UV * view_size;"), "the level's dark multiplies the screen, in view pixels (v2)")
	var lcode := FileAccess.get_file_as_string("res://shaders/darkness_lit.gdshader")
	_check(lcode.contains("render_mode unshaded;") and not lcode.contains("blend_mul") and lcode.contains("SCREEN_UV * view_size") and lcode.contains("COLOR.rgb *="),
			"the cutscene sibling multiplies its layer's own colour at screen positions")
	var inc := FileAccess.get_file_as_string("res://shaders/light_field.gdshaderinc")
	_check(inc.contains("uniform vec4 lights[48];") and inc.contains("uniform vec4 tints[48];") and inc.contains("uniform float hero_guard = 0.0;"),
			"48 lights and 48 tints; the guard is off unless the World turns it on")
	var bands := FileAccess.get_file_as_string("res://shaders/light_bands.gdshaderinc")
	_check(bands.contains("uniform float hush_depth = 0.7;"), "hush_depth defaults to 0.7")
	var fu := _uniforms("res://shaders/darkness_field.gdshader")
	var au := _uniforms("res://shaders/darkness_apply.gdshader")
	_check(fu.has("lights") and fu.has("tints") and fu.has("hero_guard"), "Plan B's field pass takes the lights")
	_check(au.has("field_tex") and au.has("dark_color") and au.has("hush_depth"), "Plan B's bands pass takes the field and the dark")


# A GDScript model of light_field.gdshaderinc + light_bands.gdshaderinc, and
# v2's shader, for the logic (the GPU identity itself is
# tools/perf/shader_identity.gd and tools/perf/shot_diff.py).
func _v2(p: Vector2, lights: Array, dark: Color, warm: Color) -> Color:
	var lit := 0.0
	for L in lights:
		var d: float = p.distance_to(Vector2(L.x, L.y)) / maxf(L.z, 1.0)
		var v: float = (1.0 - smoothstep(0.22, 1.0, d)) * L.w
		lit = 1.0 - (1.0 - lit) * (1.0 - v)
	return _bands(lit, 0.0, warm, dark)


func _v3(p: Vector2, lights: Array, tints: Array, dark: Color, warm: Color, guard: float) -> Color:
	var lit := 0.0
	var hush := 0.0
	var acc := Vector3.ZERO
	var w := 0.0
	for i in lights.size():
		var L: Vector4 = lights[i]
		var dd := p.distance_squared_to(Vector2(L.x, L.y))
		var rr := maxf(L.z, 1.0)
		if dd >= rr * rr:
			continue
		var v := 1.0 - smoothstep(0.22, 1.0, sqrt(dd) / rr)
		if L.w < 0.0:
			hush = 1.0 - (1.0 - hush) * (1.0 - v * -L.w)
			continue
		v *= L.w
		lit = 1.0 - (1.0 - lit) * (1.0 - v)
		var T: Vector4 = tints[i]
		acc += (Vector3(T.x, T.y, T.z) - Vector3(warm.r, warm.g, warm.b)) * (T.w * v)
		w += v
	if guard > 0.0 and hush > 0.0:
		var H: Vector4 = lights[0]
		var hd := p.distance_to(Vector2(H.x, H.y)) / maxf(H.z, 1.0)
		hush = minf(hush, lerpf(1.0 - guard, 1.0, smoothstep(0.6, 1.0, hd)))
	lit *= 1.0 - hush
	var wm := warm
	if w > 0.0:
		wm = Color(warm.r + acc.x / w, warm.g + acc.y / w, warm.b + acc.z / w)
	return _bands(lit, hush, wm, dark)


func _bands(lit: float, hush: float, warm: Color, dark: Color) -> Color:
	var dk := dark * (1.0 - 0.7 * hush)
	var b := lit * 3.0
	var seam := smoothstep(0.82, 1.0, fposmod(b, 1.0))
	var stepped := clampf((floorf(b) + seam) / 3.0, 0.0, 1.0)
	return Color(lerpf(dk.r, warm.r, stepped), lerpf(dk.g, warm.g, stepped), lerpf(dk.b, warm.b, stepped))


func _test_field_model() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var dark := Color(0.3, 0.25, 0.4)
	var warm := Color(1.0, 0.95, 0.86)
	var worst := 0.0
	for case_i in 20:
		var lights := []
		var tints := []
		for i in rng.randi_range(1, 48):
			lights.append(Vector4(rng.randf_range(0, 844), rng.randf_range(0, 390), rng.randf_range(10, 230), rng.randf_range(0.3, 1.0)))
			tints.append(Vector4.ZERO)
		for k in 40:
			var p := Vector2(rng.randf_range(0, 844), rng.randf_range(0, 390))
			var a := _v2(p, lights, dark, warm)
			var b := _v3(p, lights, tints, dark, warm, 1.0)
			worst = maxf(worst, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
	_check(worst < 0.5 / 255.0, "no tints, no Hush lights: v2's colour (largest gap %.8f)" % worst)
	# The guard: a Hush light on the hero leaves his pool alone inside 0.6 r.
	var hero := Vector4(400, 200, 150, 1.0)
	var hl := [hero, Vector4(420, 200, 200, -1.0)]
	var tt := [Vector4.ZERO, Vector4.ZERO]
	var clean := [hero]
	var inside := Vector2(400 + 150 * 0.5, 200)
	var a2 := _v3(inside, hl, tt, dark, warm, 1.0)
	var b2 := _v3(inside, clean, [Vector4.ZERO], dark, warm, 1.0)
	_check(a2.is_equal_approx(b2), "hero guard 1.0: no dimming inside 0.6 of light 0's radius")
	var c2 := _v3(inside, hl, tt, dark, warm, 0.0)
	_check(c2.v < b2.v, "without the guard the Hush light eats the hero's pool")
	var outside := Vector2(400 - 150 * 1.1, 200)
	var d2 := _v3(outside, [hero, Vector4(outside.x, outside.y, 100, -1.0)], tt, dark, warm, 1.0)
	var e2 := _v3(outside, [Vector4(0, 0, 1, 0)], [Vector4.ZERO], dark, warm, 1.0)
	_check(d2.v < e2.v - 0.01, "past light 0's radius a Hush light deepens the dark (by hush_depth)")
	# A tint of amount 0 is the warm colour itself; amount 1 is the tint.
	var one := [Vector4(400, 200, 200, 1.0)]
	var cold := _v3(Vector2(400, 200), one, [Vector4(0.2, 0.6, 1.0, 1.0)], dark, warm, 0.0)
	_check(is_equal_approx(cold.r, 0.2) and is_equal_approx(cold.b, 1.0), "a full tint colours the light's core")
	var none := _v3(Vector2(400, 200), one, [Vector4(0.2, 0.6, 1.0, 0.0)], dark, warm, 0.0)
	_check(none.is_equal_approx(warm), "amount 0 is the warm candle colour")


func _test_grep() -> void:
	var files := ["res://scripts/tri_batch.gd", "res://scripts/ambient.gd", "res://scripts/edge_lines.gd", "res://scripts/world_lights.gd",
			"res://scripts/themes/loader.gd"]
	for dir in ["res://scripts/tiles/", "res://scripts/backdrops/", "res://scripts/features/", "res://scripts/themes/"]:
		if DirAccess.dir_exists_absolute(dir):
			for f in DirAccess.get_files_at(dir):
				if f.ends_with(".gd"):
					files.append(dir + f)
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		var hits := []
		for line in src.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for bad in NO_IMMEDIATE:
				if code.contains(bad):
					hits.append(bad)
		_check(hits.is_empty(), "%s draws nothing one call at a time (%s)" % [path, ", ".join(hits)])


# ---------------------------------------------------------------- themes

func _test_themes() -> void:
	_check(not Themes.has_theme("nave") and not Themes.has_theme("undercandle"), "v2's themes are not the loader's (they keep their path)")
	Themes.register(STUB)
	_check(Themes.has_theme("stub"), "a registered theme file's THEMES merge in")
	var t: Dictionary = Themes.theme("stub")
	_check(t.get("dark") == t.get("dark_color") and t.has("sky"), "theme(): the World's \"dark\" is the file's dark_color")
	_check((Themes.palette("stub") as Dictionary).has("stone"), "palette(): PALETTES[id]")
	_check(Themes.ambient("stub").size() == 2 and Themes.edges("stub").size() == 3, "AMBIENT and EDGES merge in")
	_check(Themes.painter("stub") == load("res://scripts/tiles/plain.gd"), "the painter by name: scripts/tiles/plain.gd")
	_check(Themes.style("stub") == load("res://scripts/backdrops/plain.gd"), "the style by name: scripts/backdrops/plain.gd")
	_check(Themes.painter("stub_missing") == load("res://scripts/tiles/plain.gd") and Themes.style("stub_missing") == load("res://scripts/backdrops/plain.gd"),
			"a missing painter or style falls back to the plain one")
	_check(Themes.theme("no_such").is_empty() and not Themes.has_theme("no_such"), "unknown ids give {}")


# ---------------------------------------------------------------- worlds

func _world_script() -> Script:
	var ws: Script = load("res://scripts/world.gd")
	for m in ws.get_script_method_list():
		if str(m["name"]) == "lit_at":
			return ws
	var seam := "res://../tools/perf/world_seam.gd"
	if ResourceLoader.exists(seam):
		return load(seam)
	return null


func _new_world(id: String, lv = null) -> Node:
	var ws := _world_script()
	if ws == null:
		return null
	var game = root.get_node("Game")
	game.settings_path = "user://test_render_settings.json"
	game.save_path = "user://test_render_save.json"
	game.reset()
	if lv == null:
		var LevelData = load("res://scripts/level_data.gd")
		lv = LevelData.load_file("res://levels/%s.txt" % id)
	var w: Node = ws.new()
	w.setup(lv, true)
	root.add_child(w)
	return w


func _v2_pack(w: Node) -> Array:
	## v2's world.gd _update_lights, verbatim in what it picks: [x, y, r, s].
	var xf: Transform2D = w.get_viewport().get_canvas_transform()
	var view: Rect2 = w.view_rect().grow(120.0)
	var out := []
	var k := xf.get_scale().x
	var t: float = w._t
	var flick := 1.0 + 0.03 * sin(t * 13.0) + 0.02 * sin(t * 23.0)
	var add := func(p: Vector2, r: float, s: float) -> void:
		if out.size() < 48 and view.has_point(p):
			var at: Vector2 = xf * p
			out.append([at.x, at.y, r * k, s])
	var pl = w.player
	if pl.alive:
		var r: float = w.hero_light_radius()
		if pl.hurt_time < 0.3:
			r *= 0.6 + pl.hurt_time * 1.3
		if pl.life_frac() < 0.25:
			r *= 0.9 + 0.1 * sin(t * TAU)
		add.call(pl.center() + Vector2(0, -8), r * flick, 1.0)
	elif w.state == "dead":
		add.call(pl.center(), 60.0 * maxf(0.0, 1.0 - w.snuff_time), 0.8)
	for e in w.enemies:
		if e.alive and e.active:
			for l in e.lights():
				add.call(l["p"], l["r"], l["s"])
	var nshots := 0
	for s in w.shots:
		if s["light"] > 0.0 and nshots < 4:
			add.call(s["pos"], s["light"], 0.8)
			nshots += 1
	for l in w.kit.lights():
		if not l.get("hero", false):
			add.call(l["p"], l["r"], l.get("s", 0.8))
	for id in w.lights.dyn:
		var l: Dictionary = w.lights.dyn[id]
		add.call(l["p"], l["r"], l["s"])
	for l in w.features.lights():
		add.call(l["p"], l["r"], l.get("s", 0.8))
	for a in w.altars:
		if a["lit"]:
			add.call(a["flame"], (150.0 + a["glow"] * 60.0) * flick, 0.95)
	var boss = w.boss
	if boss != null and is_instance_valid(boss) and boss.get("state") != "sleep":
		var flare := 1.0
		if boss.get("state") == "windup":
			flare = 1.5 + 0.3 * sin(t * 30.0)
		add.call(boss.center() + Vector2(0, -20), 130.0 * flare, 0.7 if boss.alive else 0.4)
	var neyes := 0
	for e in w.enemies:
		if neyes >= 8:
			break
		if e.alive and e.active and e != boss:
			for p in e.eye_points():
				if view.has_point(p):
					add.call(p, 16.0, 0.35)
					neyes += 1
	for b in w.bells:
		add.call(b["top"] + Vector2(0, 50), 90.0, 0.5)
	if not w.pool.is_empty():
		add.call(w.pool["pos"], 60.0, 0.7)
	var npick := 0
	for p in w.pickups:
		if npick >= 6:
			break
		if p["taken"]:
			continue
		match p["kind"]:
			"ember":
				add.call(p["pos"], 34.0, 0.55)
			"relic", "item":
				add.call(p["pos"], 90.0, 0.9)
			"sigil":
				add.call(p["pos"], 60.0, 0.7)
		npick += 1
	for s in w.sconces:
		add.call(s, 110.0 * (1.0 + 0.04 * sin(t * 11.0 + s.x)), 0.85)
	if w.backdrop:
		var cam0: Vector2 = w.view_rect().position
		var nwin := 0
		for wnd in w.backdrop.windows:
			if nwin >= 6 or out.size() >= 44:
				break
			var off: Vector2 = w.backdrop.layer_offset(wnd["layer"], cam0)
			var wc: Vector2 = (wnd["center"] if wnd["rose"] else (wnd["rect"] as Rect2).get_center()) + off
			if not view.has_point(wc):
				continue
			add.call(wc, (wnd["radius"] * 1.5 if wnd["rose"] else 70.0), 0.42)
			nwin += 1
	var lv = w.level
	var x0 := maxi(floori(view.position.x / 32), 0)
	var x1 := mini(floori(view.end.x / 32), lv.width - 1)
	var y0 := maxi(floori(view.position.y / 32), 0)
	var y1 := mini(floori(view.end.y / 32), lv.height - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1, 2):
			if out.size() >= 48:
				break
			if lv.tile(x, y) == 9 and lv.tile(x, y - 1) != 9:
				add.call(Vector2(x * 32 + 16, y * 32 + 10), 85.0 * (1.0 + 0.06 * sin(t * 3.0 + x)), 0.75)
	return out


func _packed(w: Node) -> Array:
	var m: ShaderMaterial = w.lights.materials[0]
	var arr: PackedVector4Array = m.get_shader_parameter("lights")
	var n: int = m.get_shader_parameter("light_count")
	var out := []
	for i in n:
		out.append([arr[i].x, arr[i].y, arr[i].z, arr[i].w])
	return out


func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var key := func(l: Array) -> String: return "%.2f,%.2f,%.3f,%.3f" % [l[0], l[1], l[2], l[3]]
	var ka := a.map(key)
	var kb := b.map(key)
	ka.sort()
	kb.sort()
	return ka == kb


func _test_worlds_pack_like_v2() -> void:
	if _world_script() == null:
		print("skipped: the v3 light seam (world.gd or tools/perf/world_seam.gd) missing")
		return
	var places := 0
	var same := 0
	var crowded := 0
	var worst := ""
	for id in LEVELS:
		var w := _new_world(id)
		await process_frame
		var lv = w.level
		for f in [0.02, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.97]:
			var x := clampi(int(f * lv.width), 2, lv.width - 3)
			for y in range(lv.height - 1, 0, -1):
				if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
					w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
					break
			w.cam = w._clamp_cam(w.player.position)
			# Wake what the camera would wake, so their lights count too.
			for e in w.enemies:
				e.active = w.view_rect().grow(160).has_point(e.position)
			w.lights.pack(w.view_rect())
			var mine := _packed(w)
			var v2 := _v2_pack(w)
			places += 1
			if mine.size() >= 48:
				crowded += 1
			if _same_set(mine, v2):
				same += 1
			elif worst == "":
				worst = "%s at column %d: v3 %d lights, v2 %d" % [id, x, mine.size(), v2.size()]
		w.queue_free()
		await process_frame
	_check(same == places, "the v3 packer packs v2's lights at every place tried (%d/%d; %s)" % [same, places, worst if worst != "" else "all equal"])
	print("   (the packer: %d places in W1-W2, %d of them with 48 lights)" % [places, crowded])


const FAKE_WORLD := """extends Node2D
var player
var enemies := []
var shots := []
var kit = null
var features = null
var altars := []
var boss = null
var bells := []
var pool := {}
var pickups := []
var sconces := []
var backdrop = null
var level
var state := "play"
var snuff_time := 0.0
var _t := 0.0
var diff := "dusk"
var rig = null
func view_rect() -> Rect2:
	return Rect2(0, 0, 844, 390)
func _view_size() -> Vector2:
	return Vector2(844, 390)
"""
const FAKE_PLAYER := """extends Node2D
var alive := true
var hurt_time := 1.0
var stats := {}
func center() -> Vector2:
	return Vector2(422, 200)
func life_frac() -> float:
	return 1.0
func has_status(_s: String) -> bool:
	return false
"""


func _fake_world() -> Node2D:
	var ws := GDScript.new()
	ws.source_code = FAKE_WORLD
	ws.reload()
	var ps := GDScript.new()
	ps.source_code = FAKE_PLAYER
	ps.reload()
	var w: Node2D = ws.new()
	w.player = ps.new()
	var LevelData = load("res://scripts/level_data.gd")
	var lv = LevelData.new()
	lv.parse("title: x\n---\n" + ".".repeat(30) + "\n" + "#".repeat(30) + "\n")
	w.level = lv
	root.add_child(w)
	return w


func _test_caps_and_counts() -> void:
	var w := _fake_world()
	var layer := CanvasLayer.new()
	w.add_child(layer)
	var wl = WorldLights.new(w)
	wl.attach(layer, "full")
	await process_frame
	var v := Rect2(0, 0, 844, 390)
	var c := v.get_center()
	wl.pack(v)
	var base: Dictionary = wl.counts()
	_check(int(base["lights"]) == 1 and int(base["hush"]) == 0 and int(base["tint"]) == 0, "alone: the hero's light only")
	var m: ShaderMaterial = wl.materials[0]
	_check(is_equal_approx(float(m.get_shader_parameter("hero_guard")), 1.0), "the hero's light is packed: hero_guard 1.0")
	var arr: PackedVector4Array = m.get_shader_parameter("lights")
	_check(Vector2(arr[0].x, arr[0].y).is_equal_approx(Vector2(422, 192)), "light 0 is the hero, 8 px over his centre")
	for i in 10:
		wl.add(c + Vector2(i * 30 - 150, 0), 80.0, -0.8)
	for i in 5:
		wl.add(c + Vector2(0, i * 10 - 20), 40.0, 0.6, -1.0, "", Color(0.4, 0.8, 1.0, 0.6))
	wl.pack(v)
	var k2: Dictionary = wl.counts()
	_check(int(k2["hush"]) == 6, "Hush lights: at most 6 (packed %d)" % int(k2["hush"]))
	_check(int(k2["tint"]) == 5 and int(k2["lights"]) == 12, "tinted lights counted, 12 in all (%s)" % str(k2))
	var tints: PackedVector4Array = m.get_shader_parameter("tints")
	arr = m.get_shader_parameter("lights")
	var paired := true
	for i in int(k2["lights"]):
		if (tints[i].w > 0.0) != is_equal_approx(arr[i].w, 0.6):
			paired = false
	_check(paired, "each tint sits beside its own light")
	var near := true
	var hush_d := []
	for i in int(k2["lights"]):
		if arr[i].w < 0.0:
			hush_d.append(absf(arr[i].x - 422.0))
	for d in hush_d:
		if d > 90.0:
			near = false
	_check(near, "the 6 nearest the hero win")
	wl.dyn.clear()
	for i in 20:
		wl.add(c + Vector2(i * 8 - 80, 20), 30.0, 0.4, -1.0, "deco")
	for i in 20:
		wl.add(c + Vector2(i * 8 - 80, -20), 30.0, 0.5, -1.0, "lantern,haven")
	wl.pack(v)
	arr = m.get_shader_parameter("lights")
	var n_deco := 0
	var n_lant := 0
	for i in int(wl.counts()["lights"]):
		if is_equal_approx(arr[i].w, 0.4):
			n_deco += 1
		elif is_equal_approx(arr[i].w, 0.5):
			n_lant += 1
	_check(n_lant == 14, "altars and lanterns: at most 14 (%d)" % n_lant)
	_check(n_deco == 10, "decorative lights: at most 10 (%d)" % n_deco)
	for i in 40:
		wl.add(c + Vector2(i * 4 - 80, 60), 20.0, 0.7)
	wl.pack(v)
	arr = m.get_shader_parameter("lights")
	n_deco = 0
	for i in int(wl.counts()["lights"]):
		if is_equal_approx(arr[i].w, 0.4):
			n_deco += 1
	_check(int(wl.counts()["lights"]) == 48 and n_deco == 0, "48 at most, and decoration never takes the last 4 slots (%d deco)" % n_deco)
	_check(wl.tagged("haven").size() == 20 and wl.tagged("lantern").size() == 20 and wl.tagged("anchor").is_empty(), "tagged() reads comma-separated tags")
	# Timed lights age with the World's tick.
	var tid: int = wl.add(c, 50.0, 0.8, 0.5, "flare")
	wl.step(0.3)
	_check(wl.dyn.has(tid), "a timed light is there before its life runs out")
	wl.step(0.3)
	_check(not wl.dyn.has(tid), "and gone after it")
	# The snuff light keeps the guard; no hero light, no guard.
	w.player.alive = false
	w.state = "dead"
	wl.pack(v)
	_check(is_equal_approx(float(m.get_shader_parameter("hero_guard")), 1.0), "the snuff light is light 0: the guard stays")
	w.state = "clear"
	wl.dyn.clear()
	wl.pack(v)
	_check(is_equal_approx(float(m.get_shader_parameter("hero_guard")), 0.0), "no hero light packed: hero_guard 0")
	w.queue_free()
	await process_frame


func _test_lit_at_and_dims() -> void:
	var w := _new_world("1-1")
	if w == null:
		return
	await process_frame
	var pl = w.player
	var hc: Vector2 = pl.center() + Vector2(0, -8)
	var r: float = w.hero_light_radius()
	_check(w.lit_at(hc), "the hero's own light counts")
	_check(w.lights.gameplay_lights(false).all(func(l): return str(l.get("tag", "")) != "hero") and w.lights.gameplay_lights(true).any(func(l): return str(l.get("tag", "")) == "hero"),
			"exclude_hero leaves the hero's light out")
	var far := hc + Vector2(r + 30.0, 0)
	_check(not w.lit_at(far, 0.0, {"key": "probe"}), "outside the nominal radius: not lit")
	_check(w.lit_at(hc + Vector2(r - 2.0, 0), 0.0, {"key": "probe"}), "inside it: lit")
	_check(w.lit_at(hc + Vector2(r + 6.0, 0), 0.0, {"key": "probe"}), "8 px of hysteresis: still lit just past the edge")
	_check(not w.lit_at(hc + Vector2(r + 9.0, 0), 0.0, {"key": "probe"}), "and not past the 8 px")
	_check(w.lit_at(far, 40.0), "pad widens it")
	var spot := hc + Vector2(900, 0)
	var id: int = w.add_light(spot, 60.0, 0.9, -1.0, "lantern,haven")
	_check(w.lit_at(spot + Vector2(30, 0), 0.0, {"tag": "haven"}), "a tagged light answers for its tag")
	_check(not w.lit_at(spot + Vector2(30, 0), 0.0, {"tag": "anchor", "key": "a2"}), "and not for another")
	var hid: int = w.add_light(spot + Vector2(0, 300), 80.0, -0.9)
	_check(not w.lit_at(spot + Vector2(0, 300), 0.0, {"exclude_hero": true, "key": "h"}), "a Hush light never lights anything")
	w.remove_light(id)
	w.remove_light(hid)
	# Dims: one path, dim_resist per entry, the floor, expiry, undim.
	var r0: float = w.lights.hero_radius()
	w.dim("spores", 0.55, 2.0)
	var r1: float = w.lights.hero_radius()
	_check(r1 < r0 and w.lights.dimmed(), "dim() shrinks the hero's own radius")
	w.dim("hush", 0.2, 2.0)
	w.dim("maw", 0.2, 2.0)
	var prod: float = w.lights.dim_product()
	_check(is_equal_approx(prod, 0.5), "the product floors at x0.50 on Dusk (%.3f)" % prod)
	w.undim("hush")
	w.undim("maw")
	pl.stats["dim_resist"] = 0.5
	var p2: float = w.lights.dim_product()
	_check(is_equal_approx(p2, 1.0 - 0.45 * 0.5), "dim_resist halves each entry's loss (%.3f)" % p2)
	pl.stats["dim_resist"] = 0.9
	_check(is_equal_approx(w.lights.dim_product(), 1.0 - 0.45 * 0.5), "dim_resist caps at 50%")
	pl.stats["dim_resist"] = 0.0
	w.set("_t", float(w.get("_t")) + 3.0)
	if w.get("ftime") != null:
		w.set("ftime", float(w.get("ftime")) + 3.0)
	_check(is_equal_approx(w.lights.dim_product(), 1.0) and not w.lights.dimmed(), "a dim runs out on the World's clock")
	w.dim("douse", 0.5, -1.0)
	w.set("_t", float(w.get("_t")) + 100.0)
	_check(w.lights.dim_product() < 1.0, "seconds < 0 holds until undim")
	w.undim("douse")
	_check(is_equal_approx(w.lights.hero_radius(), r0), "undim restores it")
	w.light_override(20.0)
	_check(is_equal_approx(w.lights.hero_radius(), 20.0), "light_override forces the radius, even under LIGHT_MIN")
	w.lights.pack(w.view_rect())
	var m: ShaderMaterial = w.lights.materials[0]
	var arr: PackedVector4Array = m.get_shader_parameter("lights")
	var k := w.get_viewport().get_canvas_transform().get_scale().x
	_check(is_equal_approx(arr[0].z, 20.0 * k), "and the dark shows exactly that radius (no flicker)")
	w.light_override(-1.0)
	_check(is_equal_approx(w.lights.hero_radius(), r0), "-1 releases it")
	w.queue_free()
	await process_frame


func _test_reflect_and_colors() -> void:
	var w := _new_world("1-1")
	if w == null:
		return
	await process_frame
	var pl = w.player
	var hc: Vector2 = pl.center() + Vector2(0, -8)
	var spans := [{"x0": hc.x - 100, "x1": hc.x + 100, "y": hc.y + 40, "tint": Color(0.75, 0.9, 0.96, 0.5), "k": 0.45}]
	var out: Array = w.lights.reflect(spans)
	_check(out.size() >= 1 and (out[0]["p"] as Vector2).is_equal_approx(Vector2(hc.x, 2.0 * (hc.y + 40) - hc.y)), "a mirror light at (x, 2y - y') for the hero first")
	_check(is_equal_approx(float(out[0]["s"]), 0.45) and is_equal_approx(float(out[0]["r"]), w.lights.hero_radius() * 0.6), "r x 0.6, s x k")
	_check(w.lights.mirrors.size() == out.size() and bool(w.lights.mirrors[0]["hero"]), "glow gets the mirrored flame points")
	var many := []
	for i in 10:
		many.append({"x0": hc.x - 1000, "x1": hc.x + 1000, "y": hc.y + 20 + i, "tint": Color(1, 1, 1, 0.5), "k": 0.3})
	for i in 8:
		w.sconces.append(hc + Vector2(i * 30 - 120, -20))
	_check(w.lights.reflect(many).size() <= 4, "at most 4 mirror lights")
	w.sconces.clear()
	_check(w.lights.reflect([]).is_empty() and w.lights.mirrors.is_empty(), "no spans, no mirrors")
	# Colours: theme_dark with the brightness on top, tweens that land.
	w.lights.theme_dark(Color(0.3, 0.2, 0.4), 0.1)
	_check(w.lights.dark_color().is_equal_approx(Color(0.3, 0.2, 0.4).lightened(0.1)), "the brightness setting lightens the theme's dark (v2)")
	w.set_dark(Color(0.1, 0.1, 0.3), 0.0)
	_check(w.lights.dark_color().is_equal_approx(Color(0.1, 0.1, 0.3).lightened(0.1)), "set_dark(c, 0) is at once")
	w.set_warm(Color(1.0, 1.0, 1.0), 1.0)
	w.lights._step_colors(0.5)
	var wm = w.lights.materials[0].get_shader_parameter("warm_color")
	_check(wm is Vector3 and absf((wm as Vector3).z - 0.93) < 0.01, "set_warm tweens (halfway at half the time)")
	w.lights._step_colors(0.6)
	wm = w.lights.materials[0].get_shader_parameter("warm_color")
	_check(wm is Vector3 and (wm as Vector3).is_equal_approx(Vector3(1, 1, 1)), "and lands")
	w.queue_free()
	await process_frame


func _test_plans() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var a = WorldLights.new(null)
	var na: Control = a.attach(layer, "full")
	_check(na is ColorRect and a.materials.size() == 1 and a.dark_mat.shader == load("res://shaders/darkness.gdshader"), "Plan A: one full-screen rect, darkness.gdshader")
	var b = WorldLights.new(null)
	var nb: Control = b.attach(layer, "quarter")
	await process_frame
	var vp: SubViewport = b.get("_vp")
	var win := Vector2(root.size)
	_check(vp != null and b.materials.size() == 2 and b.dark_mat.shader == load("res://shaders/darkness_apply.gdshader"), "Plan B: a field SubViewport and the bands pass")
	_check(vp != null and vp.size.x == 2 * ceili(win.x * 0.25) and vp.size.y == ceili(win.y * 0.25), "Plan B's field: a quarter of the window each way, twice as wide (%s for %s)" % [vp.size if vp else Vector2i.ZERO, win])
	b.set_param("light_count", 3)
	_check(int(b.materials[0].get_shader_parameter("light_count")) == 3, "set_param reaches the field")
	var LF = load("res://scripts/light_field.gd")
	var f = LF.new()
	layer.add_child(f)
	await process_frame
	var lm: ShaderMaterial = f.make_bands_material(true)
	var am: ShaderMaterial = f.make_bands_material(false)
	_check(lm.shader == load("res://shaders/darkness_lit_b.gdshader") and am.shader == load("res://shaders/darkness_apply.gdshader"),
			"light_field.gd makes bands for a cutscene layer and for the screen")
	f.set_param("dark_color", Color(0.1, 0.2, 0.3))
	f.set_param("light_count", 7)
	_check(int(f.field_mat.get_shader_parameter("light_count")) == 7 and (lm.get_shader_parameter("dark_color") as Color).is_equal_approx(Color(0.1, 0.2, 0.3)),
			"set_param reaches the field and every bands material")
	_check(lm.get_shader_parameter("field_tex") == f.texture() and (lm.get_shader_parameter("field_size") as Vector2) == Vector2(f.half_size()),
			"a layer reads the shared field")
	var lbu := _uniforms("res://shaders/darkness_lit_b.gdshader")
	_check(lbu.has("field_tex") and lbu.has("dark_color") and not lbu.has("lights"), "a Plan B layer runs no light loop of its own")
	var c = WorldLights.new(null)
	c.attach(layer, "nonsense")
	_check(c.field == "full", "an unknown plan is Plan A")
	WorldLights.force_field = "quarter"
	_check(WorldLights.field_mode() == "quarter", "force_field wins (the spike)")
	WorldLights.force_field = ""
	_check(WorldLights.field_mode() == WorldLights.LIGHT_FIELD or ProjectSettings.has_setting("waxby/render/light_field"), "else the setting, else LIGHT_FIELD")
	_check(WorldLights.LIGHT_FIELD == "full", "levels keep Plan A (the phone's GPU test)")
	# ...and the cutscenes take the quarter field (Plan B for cutscenes only).
	_check(WorldLights.CUTSCENE_FIELD == "quarter" and WorldLights.cutscene_field_mode() == "quarter", "cutscenes take the quarter field")
	WorldLights.force_cutscene_field = "full"
	_check(WorldLights.cutscene_field_mode() == "full" and WorldLights.field_mode() == "full", "force_cutscene_field wins, and leaves the levels' plan alone")
	WorldLights.force_cutscene_field = ""
	WorldLights.force_field = "half"
	_check(WorldLights.cutscene_field_mode() == "half", "a Plan B level run keeps its scenes on its own field")
	WorldLights.force_field = ""
	layer.queue_free()
	await process_frame


# ---------------------------------------------------------------- backdrop, tiles

func _stub_level():
	var fx: Script = load(STUB)
	return fx.call("stub_level") if fx != null else null


func _test_backdrop_and_tiles() -> void:
	var Backdrop = load("res://scripts/backdrop.gd")
	var bd = Backdrop.new()
	root.add_child(bd)
	bd.build("stub", Vector2(9000, 480), Vector2(844, 390))
	var slices := 0
	var covered := true
	for i in bd.get_child_count():
		var layer = bd.get_child(i)
		_check(int(layer.get("mode")) == 1, "a v3 style's layer is a parent of slices")
		var sp: Vector2 = bd.span(i)
		var x := -INF
		for sl in layer.get_children():
			slices += 1
			if int(sl.get("mode")) != 2 or float(sl.get("x1")) - float(sl.get("x0")) != Backdrop.SLICE:
				covered = false
			x = maxf(x, float(sl.get("x1")))
		if x < sp.x:
			covered = false
	_check(slices > 3 and covered, "1024 px slices cover every layer's span (%d slices)" % slices)
	_check(not bd.windows.is_empty() and bd.windows.all(func(w): return int(w["layer"]) == 1), "the style's windows are made at build, on their layer")
	_check(bd.colors().has("dark") and bd.style() == "plain", "colors() is the theme's; style() its style")
	await process_frame
	bd.build("nave", Vector2(9000, 480), Vector2(844, 390))
	await process_frame
	var v2_children := 0
	for i in bd.get_child_count():
		v2_children += bd.get_child(i).get_child_count()
	_check(v2_children == 0 and int(bd.get_child(0).get("mode")) == 0, "v2's themes keep one unsliced node a layer")
	bd.queue_free()
	# Tile chunks: the stub level through the plain painter, inside the budget.
	var lv = _stub_level()
	if lv == null:
		print("skipped: the stub level (tools/shot_render.gd) missing")
		return
	var TileView = load("res://scripts/tile_view.gd")
	var Plain = load("res://scripts/tiles/plain.gd")
	var seen := {}
	for y in lv.height:
		for x in lv.width:
			seen[lv.tile(x, y)] = true
	var all_v3 := true
	for t in range(12, 23):
		if not seen.has(t):
			all_v3 = false
	_check(all_v3, "the stub level holds every v3 tile (12..22)")
	var worst := 0
	var chunks := []
	for i in ceili(lv.width / 16.0):
		var tv = TileView.new()
		tv.level = lv
		tv.col0 = i * 16
		root.add_child(tv)
		chunks.append(tv)
	# The painter's own batch, for the vertex budget.
	var probe := Node2D.new()
	root.add_child(probe)
	var tb = TriBatch.new()
	var counts := []
	probe.draw.connect(func():
		for i in chunks.size():
			Plain.paint_chunk(probe, tb, lv, i * 16, mini(i * 16 + 16, lv.width), Themes.palette("stub"), null)
			counts.append(tb.vertex_count())
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_check(counts.size() == chunks.size(), "the plain painter paints every chunk")
	_check(counts.all(func(n): return n == 0), "each chunk's batch is flushed (empty after paint_chunk)")
	# Count by painting cells into a fresh batch (no flush).
	var tb2 = TriBatch.new()
	var dummy := Node2D.new()
	root.add_child(dummy)
	var most := [0]
	dummy.draw.connect(func():
		for i in chunks.size():
			for x in range(i * 16, mini(i * 16 + 16, lv.width)):
				for y in lv.height:
					var t: int = lv.tile(x, y)
					if t != 0:
						Plain.paint_cell(dummy, tb2, lv, x, y, t, {}, null)
			most[0] = maxi(most[0], tb2.vertex_count())
			tb2.clear()
	)
	dummy.queue_redraw()
	await process_frame
	await process_frame
	worst = most[0]
	_check(worst > 0 and worst <= 6000, "a static chunk stays within 6000 vertices (at most %d)" % worst)
	for tv in chunks:
		tv.queue_free()
	probe.queue_free()
	dummy.queue_free()
	await process_frame


func _test_edges_and_ambient() -> void:
	var Edges = load("res://scripts/edge_lines.gd")
	var LevelData = load("res://scripts/level_data.gd")
	var e = Edges.new()
	root.add_child(e)
	e.build(LevelData.load_file("res://levels/1-1.txt"), 1)
	_check(e.chunks.is_empty(), "W1: no edge lines, no chunks")
	e.build(LevelData.load_file("res://levels/2-2.txt"), 0)
	_check(e.chunks.is_empty(), "v2's levels (world 0 before level_data v3): none either")
	var lv = _stub_level()
	if lv != null:
		e.build(lv, 0)
		_check(e.chunks.size() == ceili(lv.width / 16.0) and e.styles.size() == 3, "the stub theme's EDGES: a chunk per 16 columns")
		await process_frame
		var six = LevelData.load_file("res://levels/2-2.txt")
		e.build(six, 6)
		_check(e.styles.size() == 3 and str(e.styles[0]["what"]) == "lip" and is_equal_approx(float(e.styles[0]["alpha"]), 0.30),
				"W6's default: every walkable lip at 0.30")
		e.build(six, 3)
		_check(str(e.styles[0]["what"]) == "vine" and is_equal_approx(float(e.styles[0]["alpha"]), 0.35), "W3's default: vine veins at 0.35")
	# A fallen crumble gets no lip or ledge line (A1's request: W3's lip and
	# shelf lines, W6's lips): edge_lines asks the World.
	var fw := FallenWorld.new()
	e.world = fw
	_check(e._fallen(LevelData.CRUMBLE, 3, 5) and not e._fallen(LevelData.LEDGE, 3, 5), "a fallen crumble is left unlined; a ledge isn't a crumble")
	e.world = null
	_check(not e._fallen(LevelData.CRUMBLE, 3, 5), "(with no World to ask, a crumble is there)")
	fw.free()
	e.queue_free()
	var Amb = load("res://scripts/ambient.gd")
	var a = Amb.new()
	root.add_child(a)
	a.set_theme("nave")
	_check(a.table.is_empty(), "v2's themes: no motes")
	await process_frame
	_check(a.mote_count() == 0, "and nothing drawn")
	a.set_theme("stub")
	_check(a.table.size() == 2, "the stub's AMBIENT")
	a.queue_redraw()
	await process_frame
	await process_frame
	_check(a.mote_count() > 0 and a.mote_count() <= 64 + 4, "motes drawn within their caps (%d)" % a.mote_count())
	a.burst("spore", Vector2(100, 100), 500)
	_check(a.bursts.size() == Amb.BURST_MAX, "bursts cap at %d" % Amb.BURST_MAX)
	a.set_wind(-1.0, 2.0)
	_check(a.wind_dir == -1.0 and a.wind_k == 1.0, "set_wind clamps k to 0..1")
	a.queue_free()
	Themes.unregister(STUB)
	await process_frame


func _test_glow() -> void:
	var Glow = load("res://scripts/glow.gd")
	var g = Glow.new()
	root.add_child(g)
	var args := 0
	for m in g.get_method_list():
		if str(m["name"]) == "flame":
			args = maxi(args, (m["args"] as Array).size())
	_check(args == 6, "flame(base, h, seed, big, guttering, pal)")
	_check(g.has_method("mirror_flame") and g.has_method("spark_count"), "glow has the mirror hook and the spark count")
	_check(Glow.SPARK_SEG == 64 and Glow.MAX_SPARKS == 400, "sparks: draw_circle's 64 segments, 400 at most")
	g.extra_flames = [{"p": Vector2(50, 50), "h": 12.0}]
	g.burst(Vector2(40, 40), 30, Color.ORANGE)
	g.queue_redraw()
	await process_frame
	await process_frame
	_check(g.spark_count() > 0, "sparks live and draw (headless, no world)")
	g.queue_free()
	await process_frame


func _test_perf_meter() -> void:
	var M = load("res://scripts/perf_meter.gd")
	var m = M.new()
	m.start(null)
	m.sample()
	var line: String = m.line("1-1", 120.0, 0.0083, null)
	var re := RegEx.new()
	re.compile("^\\[perf\\] 1-1 fps 120\\.0 worst frame 8\\.3 ms dc \\d+ \\| gpu (n/a|[\\d.]+) ms rcpu [\\d.]+ ms \\| proc [\\d.]+ ms phys [\\d.]+ ms bot [\\d.]+ ms \\| lights \\d+ hush \\d+ tint \\d+ refl \\d+ \\| sparks \\d+ motes \\d+ \\| texmem (\\d+|n/a) MB art (\\d+|n/a) MB$")
	_check(re.search(line) != null, "the perf line's format (the debug bot's time apart from phys since the rev5 review): %s" % line)
	_check(line.contains("worst frame 8.3 ms") and line.contains("fps 120.0"), "it keeps v2's words (test_story reads them)")


class FallenWorld extends Node:
	func ledge_present(_x: int, _y: int) -> bool:
		return false

# ---------------------------------------------------------------- 16 x 16 chunks (the shapes plan's E4)

class TriLog extends "res://scripts/tri_batch.gd":
	## A batch that keeps every triangle it flushes (corners and colours as
	## text, to compare as a multiset) and the most vertices it held.
	var tris := PackedStringArray()
	var most := 0

	func flush(ci: CanvasItem) -> void:
		most = maxi(most, vertex_count())
		for t in range(0, indices.size(), 3):
			var s := ""
			for q in 3:
				s += "%s %s|" % [points[indices[t + q]], colors[indices[t + q]]]
			tris.append(s)
		clear()


func _sorted(a: PackedStringArray) -> PackedStringArray:
	var b := a.duplicate()
	b.sort()
	return b


func _test_cell_chunks() -> void:
	## Tiles are chunked 16 x 16 (tile_view.gd's row0, world.gd's grid): a
	## 15-row level is one row of chunks laid out as before; a taller one
	## paints exactly what whole-height columns painted (every triangle, once),
	## its bottom chunks the bedrock; a redraw asks only for the chunks at and
	## next to the changed cell; edge lines chunk the same way.
	var LevelData = load("res://scripts/level_data.gd")
	var Edges = load("res://scripts/edge_lines.gd")
	var probe := Node2D.new()
	root.add_child(probe)
	var cases := []
	for id in ["3-1", "4-1", "5-3", "6-1"]:
		for rows in [15, 24, 36]:
			var path := "res://levels/%s.txt" % id if rows == 15 else "res://levels/tall/lab-tall-%s-%d.txt" % [id, rows]
			if FileAccess.file_exists(path):
				cases.append(LevelData.load_file(path))
	_check(cases.size() == 12, "the four painters' levels at 15 rows and their tall render labs at 24 and 36 (%d)" % cases.size())
	var res := {}
	probe.draw.connect(func():
		for lv in cases:
			var painter: Script = Themes.painter(str(lv.theme))
			var pal: Dictionary = Themes.palette(str(lv.theme))
			var whole := TriLog.new()
			var cells := TriLog.new()
			for x0 in range(0, lv.width, 16):
				painter.paint_chunk(probe, whole, lv, x0, mini(x0 + 16, lv.width), pal, null)
				for y0 in range(0, lv.height, 16):
					painter.paint_chunk(probe, cells, lv, x0, mini(x0 + 16, lv.width), pal, null, y0, mini(y0 + 16, lv.height))
			res[lv.id] = [_sorted(whole.tris) == _sorted(cells.tris) and whole.tris.size() > 0, cells.most, whole.most, whole.tris.size()]
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	for id in res:
		var r: Array = res[id]
		_check(r[0], "%s: its 16 x 16 chunks paint exactly what whole columns did (%d triangles)" % [id, r[3]])
		_check(r[1] <= 6000, "%s: a 16 x 16 chunk within 6000 vertices (%d; a whole column %d)" % [id, r[1], r[2]])
	# The World's grid, and what a redraw asks for.
	var ws: Script = load("res://scripts/world.gd")
	for lv in [LevelData.load_file("res://levels/3-1.txt"), LevelData.load_file("res://levels/tall/lab-tall-3-1-36.txt")]:
		var w: Node = ws.new()
		w.setup(lv, true)
		root.add_child(w)
		await process_frame
		var n: int = ceili(lv.width / 16.0)
		var m: int = ceili(lv.height / 16.0)
		var laid: bool = w.chunks.size() == n * m and w.chunk_rows == m
		for k in w.chunks.size():
			laid = laid and w.chunks[k].col0 == (k / m) * 16 and w.chunks[k].row0 == (k % m) * 16
		_check(laid, "%s: %d x %d chunks, column-major (%d)" % [lv.id, n, m, w.chunks.size()])
		if lv.height == 15:
			var same := true
			for x in [0, 5, 15, 16, 17, 31, lv.width - 1]:
				var old := [x / 16]
				if (x + 1) / 16 != x / 16 and (x + 1) / 16 < n:
					old.append((x + 1) / 16)
				if x > 0 and (x - 1) / 16 != x / 16:
					old.append((x - 1) / 16)
				var got: Array = w.chunks_at(x, 12)
				got.sort()
				old.sort()
				same = same and got == old and w.chunks_at(x) == w.chunks_at(x, 3)
			_check(same and m == 1, "a 15-row level: one row of chunks, a redraw asks for the columns it always did")
		else:
			_check(w.chunks_at(20, 20).size() == 1, "36 rows: a change inside a chunk redraws that chunk only")
			_check(w.chunks_at(16, 16).size() == 4 and w.chunks_at(15, 15).size() == 4, "at a chunk's corner, the four that touch it")
			_check(w.chunks_at(20, 0).size() == 1 and w.chunks_at(20, lv.height - 1).size() == 1, "the top and bottom rows: their chunk")
			_check(w.chunks_at(20).size() == m and w.chunks_at(16).size() == 2 * m, "y -1: every chunk down the column(s)")
			var bottoms := 0
			for tv in w.chunks:
				if tv.row0 + 16 >= lv.height:
					bottoms += 1
			_check(bottoms == n, "the bottom chunk of every column draws the bedrock (%d)" % bottoms)
		w.queue_free()
		await process_frame
	# Edge lines: the same grid; every chunk's lines are its cells' lines, once.
	var tall_lv = LevelData.load_file("res://levels/tall/lab-tall-5-3-36.txt")
	var e = Edges.new()
	root.add_child(e)
	e.build(tall_lv, 5, str(tall_lv.theme))
	var en := ceili(tall_lv.width / 16.0)
	_check(e.rows == 3 and e.chunks.size() == en * 3, "edge lines: 16 x 16 chunks too (%d)" % e.chunks.size())
	_check(e.chunks_at(20, 20).size() == 1 and e.chunks_at(16, 16).size() == 4 and e.chunks_at(20).size() == 3,
			"edge lines: a redraw asks for the chunks at and next to the cell")
	var got := TriLog.new()
	var want := TriLog.new()
	var host := Node2D.new()
	root.add_child(host)
	host.draw.connect(func():
		e._tb = got
		for k in e.chunks.size():
			e._draw_chunk(host, k)
		e._tb = want
		for st in e.styles:
			var c: Color = st.get("color", Color(1, 1, 1))
			c.a = float(st.get("alpha", 0.3))
			for x in tall_lv.width:
				for y in tall_lv.height:
					e._cell(str(st.get("what", "lip")), x, y, c, float(st.get("width", 1.5)))
		want.flush(host)
	)
	host.queue_redraw()
	await process_frame
	await process_frame
	_check(_sorted(got.tris) == _sorted(want.tris) and got.tris.size() > 0,
			"edge lines: the chunks draw every cell's lines once (%d triangles)" % got.tris.size())
	host.queue_free()
	e.queue_free()
	probe.queue_free()
	await process_frame
