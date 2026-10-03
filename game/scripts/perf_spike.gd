extends Node
## The GPU spike (v3 Phase 0, step 0.1): the dark's worst cases, measured.
##   lights48  2-4's boss arena with the whole HUD, 48 lights on screen: 6 Hush
##             lights, 12 tinted, the rest warm (the level's own included)
##   scene33   the busiest cutscene's stand-in (boss_6_after shot 2b): 4 lit
##             layers covering the screen, 33 lights (4 Hush, 8 tinted), each
##             layer running the light loop (Plan A) or all four reading one
##             quarter-size field (Plan B, light_field.gd)
## Each case holds 12 s after 3 s of warm-up, printing the perf line every 2 s
## (perf_meter.gd), then ramps extra copies of its dark pass (0, 2, 4, 8, 16)
## for 4 s each: with vsync hiding the GPU (Metal has no timestamps), the
## frame time's climb with the copies measures what one pass costs.
## Both run under Plan A ("full") and Plan B ("quarter": the field at a
## quarter size each way in a SubViewport).
## Runs:
##   main.gd: --autoplay=spike:<all|lights48|lights48b|scene33|scene33b>  (the route W0 adds)
##   the spike build tools/perf/run_phone.sh makes: --spike=<name> (an autoload)
##   the Mac: godot --path game --resolution 2868x1320 -- --spike=all
## Engine flags work too: --rendering-driver vulkan gives real GPU times.
## Ends with "[spike] done" and quits. The summary lines start "[spike]".

const PerfMeter := preload("res://scripts/perf_meter.gd")
const LevelData := preload("res://scripts/level_data.gd")
const WARM := 3.0
const HOLD := 12.0
const RAMP := [0, 2, 4, 8, 16]
const RAMP_HOLD := 4.0
const WINDOW := 2.0
const TINTS := [Color("c8d46a"), Color("e8fcff"), Color("f8f0ff"), Color("e0e0ff"), Color("6ab0d8"), Color("e07ab8")]
const SCENE_TEX := ["res://art/story/sets/chapel_bg.svg", "res://art/story/sets/belfry_rafters.svg",
		"res://art/story/sets/chapel_fg.svg", "res://art/story/sets/belfry_floor.svg"]

var name_arg := ""
var world_script_path := ""      # a World script to use (the Mac runner passes this copy's seam)
var lines: Array = []
var summary: Array = []
var _meter := PerfMeter.new()
var _world: Node = null
var _synthetic: Array = []       # [id, base, phase]
var _extras: Array = []          # the ramp's extra dark passes (nodes)
var _layer: CanvasLayer = null
var _t0 := 0.0


static func wants() -> String:
	## The spike asked for on the command line, or "".
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--spike="):
			return a.get_slice("=", 1)
		if a.begins_with("--autoplay=spike:"):
			return a.get_slice(":", 1)
	return ""


func _ready() -> void:
	if name_arg != "":
		return
	# As an autoload (the spike build): take over only when asked.
	var want := wants()
	if want == "":
		queue_free()
		return
	name_arg = want
	_takeover.call_deferred()


func _takeover() -> void:
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene != null and scene != self:
		scene.queue_free()
	await get_tree().process_frame
	run(name_arg)


func run(which: String) -> void:
	## main.gd calls this for --autoplay=spike:<which> (after add_child).
	name_arg = which
	var game = get_node_or_null("/root/Game")
	if game != null:
		game.save_path = game.AUTOPLAY_SAVE
		game.slot_base = str(game.AUTOPLAY_SAVE).trim_suffix(".json")
		game.load_save()
	_say("[spike] start %s: driver %s, method %s, window %s, viewport %s" % [which, RenderingServer.get_current_rendering_driver_name(),
			RenderingServer.get_current_rendering_method(), DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])
	var cases: Array = []
	match which:
		"lights48":
			cases = [["lights48", "full"]]
		"lights48b":
			cases = [["lights48", "quarter"]]
		"scene33":
			cases = [["scene33", "full"]]
		"scene33b":
			cases = [["scene33", "quarter"]]
		_:
			cases = [["lights48", "full"], ["lights48", "quarter"], ["scene33", "full"], ["scene33", "quarter"]]
	for c in cases:
		if c[0] == "lights48":
			await _lights48(str(c[1]))
		else:
			await _scene33(str(c[1]))
	_say("[spike] summary:")
	for s in summary:
		_say("[spike]   " + str(s))
	_say("[spike] done")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _say(s: String) -> void:
	lines.append(s)
	print(s)


# ---------------------------------------------------------------- measuring

func _hold(id: String, secs: float, world: Node) -> Dictionary:
	## Frames for secs, a perf line every 2 s; returns the averages.
	_meter.start(get_viewport())
	var t0 := Time.get_ticks_usec()
	var last := t0
	var win_t := 0.0
	var win_n := 0
	var win_worst := 0.0
	var all_n := 0
	var all_t := 0.0
	var worst := 0.0
	var gpu_sum := 0.0
	var gpu_n := 0
	var dc := 0
	var counts := {}
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var real := (now - last) / 1e6
		last = now
		_meter.sample()
		win_t += real
		win_n += 1
		win_worst = maxf(win_worst, real)
		all_t += real
		all_n += 1
		worst = maxf(worst, real)
		if real > 0.0167:
			_say("[spike] %s hitch %.1f ms at %.2f s" % [id, real * 1000.0, (now - t0) / 1e6])
		if win_t >= WINDOW:
			_say(_meter.line(id, win_n / win_t, win_worst, world))
			var L: Dictionary = _meter.last
			if float(L["gpu"]) > 0.0:
				gpu_sum += float(L["gpu"])
				gpu_n += 1
			dc = maxi(dc, int(L["dc"]))
			counts = {"lights": L["lights"], "hush": L["hush"], "tint": L["tint"]}
			win_t = 0.0
			win_n = 0
			win_worst = 0.0
	if win_n > 0 and win_t >= 0.5:
		_say(_meter.line(id, win_n / win_t, win_worst, world))
	return {"fps": all_n / maxf(all_t, 0.001), "frame_ms": all_t * 1000.0 / maxi(all_n, 1), "worst_ms": worst * 1000.0,
			"gpu_ms": gpu_sum / gpu_n if gpu_n > 0 else -1.0, "dc": dc, "counts": counts}


func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		await get_tree().process_frame


func _ramp(id: String, add_passes: Callable, world: Node) -> void:
	## Extra copies of the case's dark pass; the frame time's climb per copy.
	var rows := []
	var have := 0
	for k in RAMP:
		add_passes.call(int(k) - have)
		have = int(k)
		await _wait(1.0)
		var r := await _hold("%s+%d" % [id, k], RAMP_HOLD, world)
		rows.append([k, r])
		_say("[spike] ramp %s +%d passes: fps %.1f frame %.2f ms gpu %s ms" % [id, k, r["fps"], r["frame_ms"],
				("%.2f" % r["gpu_ms"]) if r["gpu_ms"] >= 0.0 else "n/a"])
	add_passes.call(-have)
	# One pass's cost: the GPU slope when timestamps exist, else the frame
	# time's slope between the two largest ramps once past vsync (9 ms).
	var a: Array = rows[rows.size() - 2]
	var b: Array = rows[rows.size() - 1]
	var dk := float(b[0] - a[0])
	var per := -1.0
	var how := ""
	if float(b[1]["gpu_ms"]) > 0.0 and float(a[1]["gpu_ms"]) > 0.0:
		per = maxf((float(b[1]["gpu_ms"]) - float(a[1]["gpu_ms"])) / dk, 0.0)
		how = "gpu timestamps"
	elif float(a[1]["frame_ms"]) > 9.0:
		per = (float(b[1]["frame_ms"]) - float(a[1]["frame_ms"])) / dk
		how = "frame time past vsync"
	else:
		var first_slow := -1
		for r in rows:
			if float(r[1]["frame_ms"]) > 9.0:
				first_slow = int(r[0])
				break
		how = "vsync held to +%d passes" % RAMP.back() if first_slow < 0 else "vsync broke at +%d" % first_slow
	var s := "%s one dark pass ≈ %s (%s)" % [id, ("%.2f ms GPU" % per) if per >= 0.0 else "under 8.33 / 17 ms", how]
	_say("[spike] " + s)
	summary.append(s)


# ---------------------------------------------------------------- lights48

func _world_script() -> Script:
	## world.gd once it has the v3 light seam; before the merge, the seam
	## subclass the spike build copies in (tools/perf/world_seam.gd).
	if world_script_path != "" and ResourceLoader.exists(world_script_path):
		return load(world_script_path)
	var ws: Script = load("res://scripts/world.gd")
	for m in ws.get_script_method_list():
		if str(m["name"]) == "lit_at":
			return ws
	var seam := "res://scripts/perf_world_seam.gd"
	if ResourceLoader.exists(seam):
		return load(seam)
	return ws


func _lights48(plan: String) -> void:
	var WL: Script = load("res://scripts/world_lights.gd")
	WL.set("force_field", plan)
	var lv = LevelData.load_file("res://levels/2-4.txt")
	var boss_cell := Vector2i(lv.width - 12, lv.height - 3)
	for e in lv.entities:
		if str(e["kind"]) == "boss":
			boss_cell = e["cell"]
	var w: Node = _world_script().new()
	w.setup(lv)
	add_child(w)
	_world = w
	await get_tree().process_frame
	w.test_pad = {}
	w.player.reset_at(Vector2((boss_cell.x - 7) * 32 + 16, (boss_cell.y + 1) * 32))
	w.cam = w._clamp_cam(w.player.position)
	await _wait(0.5)
	w.paused = true
	# 48 on screen: 6 Hush lights, 12 tinted, 30 warm, on a jittered grid.
	var view: Rect2 = w.view_rect()
	var rng := RandomNumberGenerator.new()
	rng.seed = 48
	var n_args := 5
	for m in w.get_method_list():
		if str(m["name"]) == "add_light":
			n_args = maxi(n_args, (m["args"] as Array).size())
	_synthetic.clear()
	for i in 48:
		var p := view.position + Vector2((i % 8 + 0.5) / 8.0 * view.size.x + rng.randf_range(-30, 30),
				(floorf(i / 8.0) + 0.5) / 6.0 * view.size.y + rng.randf_range(-20, 20))
		var r := rng.randf_range(50.0, 200.0)
		var s := rng.randf_range(0.45, 0.95)
		var tint := Color(0, 0, 0, 0)
		if i % 8 == 3 and _count_hush() < 6:
			s = -rng.randf_range(0.5, 0.9)
			r = rng.randf_range(90.0, 170.0)
		elif i % 4 == 1 and _count_tint() < 12:
			var tc: Color = TINTS[i % TINTS.size()]
			tint = Color(tc.r, tc.g, tc.b, 0.65)
		var id: int
		if n_args >= 6:
			id = w.add_light(p, r, s, -1.0, "spike", tint)
		else:
			id = w.add_light(p, r, absf(s), -1.0, "spike")
		_synthetic.append([id, p, rng.randf() * TAU, s, tint.a > 0.0])
	set_process(true)
	var tag := "lights48/" + plan
	await _wait(WARM)
	var r := await _hold("spike:" + tag, HOLD, w)
	var s2 := "%s: fps %.1f frame %.2f ms worst %.1f ms gpu %s dc %d packed %s" % [tag, r["fps"], r["frame_ms"], r["worst_ms"],
			("%.2f ms" % r["gpu_ms"]) if r["gpu_ms"] >= 0.0 else "n/a", r["dc"], r["counts"]]
	_say("[spike] " + s2)
	summary.append(s2)
	await _ramp(tag, _add_level_passes.bind(w, plan), w)
	set_process(false)
	w.queue_free()
	_world = null
	await get_tree().process_frame
	WL.set("force_field", "")


func _count_hush() -> int:
	var n := 0
	for s in _synthetic:
		if float(s[3]) < 0.0:
			n += 1
	return n


func _count_tint() -> int:
	var n := 0
	for s in _synthetic:
		if bool(s[4]):
			n += 1
	return n


func _process(_dt: float) -> void:
	# The synthetic lights drift, so no two frames are the same.
	if _world != null and is_instance_valid(_world):
		var t := Time.get_ticks_msec() / 1000.0
		for s in _synthetic:
			var ph: float = s[2]
			_world.move_light(int(s[0]), (s[1] as Vector2) + Vector2(cos(t * 0.7 + ph), sin(t * 0.9 + ph)) * 18.0)


func _add_level_passes(n: int, w: Node, plan: String) -> void:
	## n more (or fewer) copies of the level's dark, sharing its materials so
	## they cost the GPU what it does and the CPU nothing: Plan A a full-screen
	## rect; Plan B another quarter-size field and its full-size bands.
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 1
		w.add_child(_layer)
	var wl = w.get("lights")
	var mats: Array = wl.materials if wl is Object and "materials" in wl else []
	for i in maxi(n, 0):
		var node: Control
		if plan == "full" or mats.size() < 2:
			var cr := ColorRect.new()
			cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cr.material = mats[0] if not mats.is_empty() else null
			node = cr
		else:
			node = Control.new()
			node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var src: SubViewport = wl.get("_vp")
			var vp := SubViewport.new()
			vp.disable_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			vp.size = src.size
			var fr := ColorRect.new()
			fr.size = Vector2(src.size)
			fr.material = mats[0]
			vp.add_child(fr)
			node.add_child(vp)
			var ap := ColorRect.new()
			ap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var am := ShaderMaterial.new()
			am.shader = load("res://shaders/darkness_apply.gdshader")
			am.set_shader_parameter("field_tex", vp.get_texture())
			am.set_shader_parameter("field_size", (mats[1] as ShaderMaterial).get_shader_parameter("field_size"))
			am.set_shader_parameter("dark_color", (mats[1] as ShaderMaterial).get_shader_parameter("dark_color"))
			ap.material = am
			node.add_child(ap)
		_layer.add_child(node)
		_extras.append(node)
	for i in maxi(-n, 0):
		if _extras.is_empty():
			break
		(_extras.pop_back() as Node).queue_free()
	if _extras.is_empty() and _layer != null:
		_layer.queue_free()
		_layer = null


# ---------------------------------------------------------------- scene33

func _scene33(plan: String) -> void:
	## Four lit layers over the whole screen, 33 lights (4 Hush, 8 tinted),
	## one material for all (as cutscene.gd does). Plan A: every layer runs
	## darkness_lit.gdshader's light loop. Plan B: one reduced field
	## (light_field.gd) that every layer reads (darkness_lit_b.gdshader).
	var stage := CanvasLayer.new()
	stage.layer = 8
	add_child(stage)
	var bg := ColorRect.new()
	bg.color = Color("0e0a14")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	var mat: ShaderMaterial
	var field: Node = null
	if plan == "full":
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/darkness_lit.gdshader")
	else:
		field = load("res://scripts/light_field.gd").new()
		field.scale = 0.25 if plan == "quarter" else 0.5
		stage.add_child(field)
		mat = field.make_bands_material(true)
	var setp := func(k: String, v) -> void:
		if field != null:
			field.set_param(k, v)
		else:
			mat.set_shader_parameter(k, v)
	var vs := get_viewport().get_visible_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var lights := PackedVector4Array()
	var tints := PackedVector4Array()
	for i in 48:
		if i < 33:
			var s := rng.randf_range(0.5, 1.0)
			var r := rng.randf_range(40.0, 240.0)
			if i % 8 == 5:
				s = -0.8
				r = 160.0
			lights.append(Vector4(rng.randf() * vs.x, rng.randf() * vs.y, r, s))
			var tc: Color = TINTS[i % TINTS.size()]
			tints.append(Vector4(tc.r, tc.g, tc.b, 0.6) if i % 4 == 2 else Vector4.ZERO)
		else:
			lights.append(Vector4.ZERO)
			tints.append(Vector4.ZERO)
	setp.call("lights", lights)
	setp.call("tints", tints)
	setp.call("light_count", 33)
	setp.call("view_size", vs)
	setp.call("dark_color", Color(0.2, 0.18, 0.3))
	var texs: Array = []
	for p in SCENE_TEX:
		if ResourceLoader.exists(p):
			texs.append(load(p))
	var layers: Array = []
	var add_layers := func(n: int) -> void:
		if n > 0:
			for i in n:
				var tr := TextureRect.new()
				tr.texture = texs[layers.size() % texs.size()] if not texs.is_empty() else null
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				tr.material = mat
				stage.add_child(tr)
				layers.append(tr)
		else:
			for i in -n:
				if layers.size() > 4:
					(layers.pop_back() as Node).queue_free()
	add_layers.call(4)
	await _wait(WARM)
	var tag := "scene33/" + plan
	var r := await _hold("spike:" + tag, HOLD, null)
	var s2 := "%s (4 layers, 33 lights): fps %.1f frame %.2f ms worst %.1f ms gpu %s dc %d" % [tag, r["fps"], r["frame_ms"], r["worst_ms"],
			("%.2f ms" % r["gpu_ms"]) if r["gpu_ms"] >= 0.0 else "n/a", r["dc"]]
	_say("[spike] " + s2)
	summary.append(s2)
	await _ramp(tag + " layer", add_layers, null)
	stage.queue_free()
	await get_tree().process_frame
