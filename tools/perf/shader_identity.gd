# The darkness shader v3 against v2's, pixel for pixel, on random light sets
# (no tints, no Hush lights): the F1 identity check without a level. Also
# renders the v3 features (tints, Hush lights, the hero guard) for a look.
#   godot --path game --resolution 1266x585 --script res://../tools/perf/shader_identity.gd -- <v2 shader file> <out_dir>
# Prints the largest channel difference (in 1/255 steps) per case; exits 1 if
# any case is over 1.
extends SceneTree

const W := 844
const H := 390


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var v2_path: String = args[0] if args.size() > 0 else ""
	var out: String = args[1] if args.size() > 1 else "/tmp/shader_identity"
	DirAccess.make_dir_recursive_absolute(out)
	var v2 := Shader.new()
	v2.code = FileAccess.get_file_as_string(v2_path)
	if v2.code == "":
		push_error("no v2 shader at %s" % v2_path)
		quit(2)
		return
	var v3: Shader = load("res://shaders/darkness.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926
	var worst := 0
	for case_i in 12:
		var n: int = [1, 5, 12, 24, 36, 48][case_i % 6]
		var lights := PackedVector4Array()
		for i in 48:
			if i < n:
				lights.append(Vector4(rng.randf_range(-60, W + 60), rng.randf_range(-60, H + 60), rng.randf_range(12, 240), rng.randf_range(0.3, 1.0)))
			else:
				lights.append(Vector4.ZERO)
		var dark := Color(rng.randf_range(0.1, 0.5), rng.randf_range(0.1, 0.4), rng.randf_range(0.2, 0.5))
		var a := await _render(v2, lights, n, dark, {})
		var b := await _render(v3, lights, n, dark, {"hero_guard": 1.0 if case_i % 2 == 0 else 0.0})
		var d := _diff(a, b)
		worst = maxi(worst, d[0])
		print("[identity] case %2d lights %2d  max diff %d/255  pixels differing %d" % [case_i, n, d[0], d[1]])
		if case_i == 5:
			a.save_png(out + "/v2_case5.png")
			b.save_png(out + "/v3_case5.png")
	# The v3 features, for the eye: tints, Hush lights, the guard.
	var lights2 := PackedVector4Array([Vector4(300, 220, 180, 1.0), Vector4(520, 200, 150, 0.9), Vector4(700, 120, 120, 0.8),
			Vector4(360, 200, 160, -0.9), Vector4(640, 260, 110, -0.7), Vector4(140, 120, 90, 0.85)])
	var tints := PackedVector4Array([Vector4(0, 0, 0, 0), Vector4(0.55, 0.85, 1.0, 0.8), Vector4(0.8, 0.9, 0.4, 0.6),
			Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0), Vector4(1.0, 0.5, 0.8, 0.7)])
	while lights2.size() < 48:
		lights2.append(Vector4.ZERO)
		tints.append(Vector4.ZERO)
	for g in [0.0, 1.0]:
		var img := await _render(v3, lights2, 6, Color(0.3, 0.25, 0.4), {"tints": tints, "hero_guard": g})
		img.save_png(out + "/v3_features_guard%d.png" % int(g))
	# Plan B on a lit layer (a cutscene's): the shared quarter field against
	# darkness_lit.gdshader's own loop, on a textured layer. For the record.
	var lf_worst := await _plan_b_layer(out)
	print("[identity] Plan B lit layer vs darkness_lit: worst %d/255, %.3f%% of pixels over 1/255" % [lf_worst[0], lf_worst[1]])
	print("[identity] worst %d/255 (%s)" % [worst, "ok" if worst <= 1 else "OVER"])
	quit(0 if worst <= 1 else 1)


func _render(sh: Shader, lights: PackedVector4Array, n: int, dark: Color, extra: Dictionary) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.8, 0.75, 0.7)
	bg.size = Vector2(W, H)
	vp.add_child(bg)
	var cr := ColorRect.new()
	cr.size = Vector2(W, H)
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("lights", lights)
	m.set_shader_parameter("light_count", n)
	m.set_shader_parameter("view_size", Vector2(W, H))
	m.set_shader_parameter("dark_color", dark)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	cr.material = m
	vp.add_child(cr)
	for i in 4:
		await process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _diff(a: Image, b: Image) -> Array:
	var worst := 0
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := maxi(maxi(absi(ca.r8 - cb.r8), absi(ca.g8 - cb.g8)), absi(ca.b8 - cb.b8))
			if d > 0:
				count += 1
			worst = maxi(worst, d)
	return [worst, count]


func _plan_b_layer(out: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var lights := PackedVector4Array()
	var tints := PackedVector4Array()
	for i in 48:
		if i < 33:
			lights.append(Vector4(rng.randf() * W, rng.randf() * H, rng.randf_range(40, 240), -0.8 if i % 8 == 5 else rng.randf_range(0.5, 1.0)))
			tints.append(Vector4(0.8, 0.9, 0.4, 0.6) if i % 4 == 2 else Vector4.ZERO)
		else:
			lights.append(Vector4.ZERO)
			tints.append(Vector4.ZERO)
	var tex: Texture2D = load("res://art/story/sets/chapel_bg.svg")
	var imgs := []
	for plan in ["full", "quarter"]:
		var vp := SubViewport.new()
		vp.size = Vector2i(W, H)
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var mat: ShaderMaterial
		var field: Node = null
		if plan == "full":
			mat = ShaderMaterial.new()
			mat.shader = load("res://shaders/darkness_lit.gdshader")
		else:
			field = load("res://scripts/light_field.gd").new()
			vp.add_child(field)
			field.scale = 0.25 * 3.4          # the phone's quarter, at this viewport's 1:1 pixels
			field.resize()
			mat = field.make_bands_material(true)
		var params := {"lights": lights, "tints": tints, "light_count": 33, "view_size": Vector2(W, H), "dark_color": Color(0.2, 0.18, 0.3)}
		for k in params:
			if field != null:
				field.set_param(k, params[k])
			else:
				mat.set_shader_parameter(k, params[k])
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(W, H)
		tr.material = mat
		vp.add_child(tr)
		for i in 5:
			await process_frame
		imgs.append(vp.get_texture().get_image())
		vp.queue_free()
	imgs[0].save_png(out + "/lit_layer_full.png")
	imgs[1].save_png(out + "/lit_layer_quarter.png")
	var d := _diff(imgs[0], imgs[1])
	return [d[0], 100.0 * d[1] / float(W * H)]
