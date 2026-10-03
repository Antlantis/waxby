extends RefCounted
## The perf line (spec §13.2, F9), every 2 s under --autoplay (main.gd's
## meter asks for it) and in the GPU spike (perf_spike.gd):
##   [perf] <id> fps F worst frame W ms dc D | gpu G ms rcpu R ms | proc P ms phys Q ms
##          | lights L hush H tint T refl M | sparks S motes A | texmem X MB art Y MB
## ("worst frame" keeps v2's words, which test_story reads.) Per window: fps
## and the worst frame from main's wall clock; dc the most draw calls in a
## frame; gpu and rcpu the averages of the viewport's measured render time
## (gpu reads "n/a" where the driver has no timestamps: Metal, so on the
## phone run a spike with --rendering-driver vulkan for GPU time, or read the
## pass ramp); the light counts from world.lights.counts(); sparks from
## world.glow; motes from world.ambient; texmem Performance's texture memory,
## and art the art textures in ResourceLoader's cache by their own sizes
## (the engine's count reads low once a scene has freed its pictures).
## proc and phys are the main thread's own work, timed from the tree's
## signals: phys from the frame's first physics tick to the process step,
## proc from the process step to the render's start (every _process, the
## deferred _draw calls, the canvas updates). Performance.TIME_PROCESS is not
## used: it includes the render and the vsync wait.
##   var m := PerfMeter.new(); m.start(viewport)
##   each counted frame: m.sample()
##   when the window closes: _perf_say(m.line(id, fps, worst_s, world))   (resets the window)

var _vp := RID()
var _n := 0
var _gpu := 0.0
var _gpu_n := 0
var _rcpu := 0.0
var _proc := 0.0
var _phys := 0.0
var _dc := 0
var last := {}                    # the last line's numbers (the spike's summary reads them)
var _art_paths: Array = []         # every imported texture under res://art (walked once)
var _art_size := {}                # path -> its bytes in video memory (width x height x 4, x 4/3 with mipmaps)
var _art_walked := false
var _art_mips := {}                # path -> its import makes mipmaps


var _t_phys := 0                   # usec: this frame's first physics tick (0: none yet)
var _t_proc := 0                   # usec: this frame's process step
var _frame_proc := 0.0             # ms, the last whole frame's
var _frame_phys := 0.0
var _hooked := false


func start(vp: Viewport = null) -> void:
	_walk_art_once()
	if vp != null:
		_vp = vp.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_vp, true)
		var tree := vp.get_tree()
		if tree != null and not _hooked:
			_hooked = true
			tree.physics_frame.connect(_on_physics)
			tree.process_frame.connect(_on_process)
			RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_reset()


func _on_physics() -> void:
	if _t_phys == 0:
		_t_phys = Time.get_ticks_usec()


func _on_process() -> void:
	_t_proc = Time.get_ticks_usec()
	_frame_phys = (_t_proc - _t_phys) / 1000.0 if _t_phys > 0 else 0.0
	_t_phys = 0


func _on_pre_draw() -> void:
	if _t_proc > 0:
		_frame_proc = (Time.get_ticks_usec() - _t_proc) / 1000.0


func _reset() -> void:
	_n = 0
	_gpu = 0.0
	_gpu_n = 0
	_rcpu = 0.0
	_proc = 0.0
	_phys = 0.0
	_dc = 0


func sample() -> void:
	## One counted frame.
	_n += 1
	if _vp.is_valid():
		var g := RenderingServer.viewport_get_measured_render_time_gpu(_vp)
		if g > 0.0:
			_gpu += g
			_gpu_n += 1
		_rcpu += RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu()
	if _hooked:
		_proc += _frame_proc
		_phys += _frame_phys
	else:
		_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_dc = maxi(_dc, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func art_mb() -> float:
	## The art textures loaded now (ResourceLoader's cache), from their own
	## sizes: the engine's texmem count drops below what's loaded after a
	## scene frees its pictures (the int2 review: 227 -> 113 MB with 147 MB
	## still loaded), so perf_report gates on the larger of the two.
	_walk_art_once()
	if _art_paths.is_empty():
		return -1.0
	var b := 0
	for p in _art_paths:
		if ResourceLoader.has_cached(p):
			if not _art_size.has(p):
				# (the cache's own copy: a load() here cost ~1 ms a path)
				var t = ResourceLoader.get_cached_ref(p)
				_art_size[p] = (t.get_width() * t.get_height() * 4 * (4 if _art_mips.get(p, true) else 3) / 3) if t is Texture2D else 0
			b += int(_art_size[p])
	return b / 1048576.0


func _walk_art_once() -> void:
	## The art's paths and which import mipmaps, read once (start() does it,
	## inside the level's build, so no counted frame pays the ~100 ms).
	if _art_walked:
		return
	_art_walked = true
	_walk_art("res://art")
	for p in _art_paths:
		var cf := ConfigFile.new()
		_art_mips[p] = cf.load(p + ".import") == OK and bool(cf.get_value("params", "mipmaps/generate", false))


func _walk_art(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_walk_art(dir + "/" + sub)
	for fn in d.get_files():
		if fn.ends_with(".import"):
			_art_paths.append(dir + "/" + fn.trim_suffix(".import"))


func line(id: String, fps: float, worst_s: float, world: Node = null) -> String:
	## The window's line; starts the next window.
	var n := maxi(_n, 1)
	var dc := _dc if _n > 0 else RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var gpu := _gpu / _gpu_n if _gpu_n > 0 else -1.0
	var c := {"lights": 0, "hush": 0, "tint": 0, "refl": 0}
	var sparks := 0
	var motes := 0
	if world != null and is_instance_valid(world):
		var wl = world.get("lights")
		if wl is Object and wl.has_method("counts"):
			c = wl.counts()
		var gl = world.get("glow")
		if gl is Object and gl.has_method("spark_count"):
			sparks = gl.spark_count()
		elif gl is Object and gl.get("sparks") is Array:
			sparks = (gl.sparks as Array).size()
		var am = world.get("ambient")
		if am is Object and am.has_method("mote_count"):
			motes = am.mote_count()
	var tex := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	if tex < 0.0 or tex > 1.0e6:
		tex = -1.0                 # the engine's count can wrap after a scene is freed
	var art := art_mb()
	# The --autoplay bot's own planning, a debug tool's cost, not the game's:
	# shown apart and taken out of phys (the rev5 review: 1-3.6 ms a tick
	# where it stalls at W6's buoys and the secrets' climbs read as the game's).
	var bot := 0.0
	if world != null and is_instance_valid(world) and world.get("bot_us") != null:
		bot = float(world.get("bot_us")) / 1000.0 / n
		world.set("bot_us", 0)
	var phys := maxf(_phys / n - bot, 0.0)
	last = {"fps": fps, "worst": worst_s * 1000.0, "dc": dc, "gpu": gpu, "rcpu": _rcpu / n, "proc": _proc / n, "phys": phys, "bot": bot,
			"lights": int(c.get("lights", 0)), "hush": int(c.get("hush", 0)), "tint": int(c.get("tint", 0)), "refl": int(c.get("refl", 0)),
			"sparks": sparks, "motes": motes, "texmem": tex, "art": art}
	var out := "[perf] %s fps %.1f worst frame %.1f ms dc %d | gpu %s ms rcpu %.2f ms | proc %.2f ms phys %.2f ms bot %.2f ms | lights %d hush %d tint %d refl %d | sparks %d motes %d | texmem %s MB art %s MB" % [
			id, fps, worst_s * 1000.0, dc, ("%.2f" % gpu) if gpu >= 0.0 else "n/a", _rcpu / n, _proc / n, phys, bot,
			last["lights"], last["hush"], last["tint"], last["refl"], sparks, motes, ("%.0f" % tex) if tex >= 0.0 else "n/a",
			("%.0f" % art) if art >= 0.0 else "n/a"]
	_reset()
	return out
