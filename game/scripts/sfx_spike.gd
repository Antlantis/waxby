extends Node
## The Phase 0 audio spikes (workstreams.md step 0.8), for the phone. Debug
## builds start one with `-- --autoplay=spike:<what>` (main.gd routes it to
## Sfx.start_spike; Sfx starts it itself if main doesn't):
##
##   spike:boot    first-boot render times: the live boot's milestones, then
##                 cold boots of the core plus the v3 banks (the real bank
##                 files, and for any not written yet a dummy: its names
##                 rendered with their fallbacks' recipes) on 1, 2 and 3
##                 threads, the frame rate meanwhile, and a warm boot from the
##                 caches. It wipes the game's own sound caches at
##                 the end, so the next launch is a true first boot.
##   spike:stems[:minutes[:pcm]]
##                 five 64 s stems (QOA, or PCM) in one AudioStreamSynchronized
##                 through Sfx.play_stems for 10 minutes: each stem carries a
##                 burst at its own offset in every 2 s, the Music bus is
##                 captured, and the bursts' spacing gives the drift between
##                 stems (the gate: one frame at 120 Hz), the stream's clock
##                 against the output's and the output's against the wall.
##                 Then set_stem, tape_stop/tape_go and seek_music are checked
##                 on the same stems.
##
## Every line starts "[spike]"; the verdicts start "[spike] RESULT"; the last
## line is "[spike] DONE". It quits when done. tools/audio/spike_phone.sh runs
## it on the phone, tools/audio/spike_mac.sh on the Mac.

const SfxLib := preload("res://scripts/sfx.gd")
const SELF_PATH := "res://scripts/sfx_spike.gd"
const GATE_MS := 1000.0 / 120.0       # one frame at 120 Hz
const BOOT_GATE_MS := 4000.0          # first boot to the title with sound
const LOOP := 64.0                    # a stem's loop (hush_final: 32 bars at 120 bpm)
const PERIOD := 2.0                   # a burst in every stem every PERIOD seconds...
const OFFSET := 0.5                   # ...stem 0's this far in...
const GAP := 0.25                     # ...and stem i's GAP * i after it
const STEMS := 5
const SLOTS := 8                      # PERIOD / GAP: five taken, three empty
const BURST := 88                     # samples in a burst (4 ms), Hann-shaped
const BURST_HZ := 3000.0
const BURST_AMP := 0.5
const THRESHOLD := 0.04               # a burst starts where the capture first passes this
const QUIET := 0.01                   # ...and ends after QUIET_FRAMES under this
const QUIET_FRAMES := 400
const REPORT_EVERY := 30.0
# The dummy bank's frequent sounds get two takes, as the real banks will.
const DUMMY_TAKES := ["vine_climb", "bone_skitter", "tick", "tick_step", "ice_squeak", "glass_step",
		"glass_tink", "lake_step", "hush_pop"]

var what := ""                        # set by Sfx.start_spike
var host: Node = null                 # main (the title is shown on it)
var sfx: Node = null

# the stems run
var _cap: AudioEffectCapture = null
var _rate := 48000.0
var _n := 0                           # frames captured so far
var _inb := false
var _quiet := 0
var _onsets: Array = []               # capture frame of each burst's start
var _ignore_before := 0
var _wall0 := 0                       # usec at the first capture after a reset...
var _n_wall0 := 0                     # ...and the frames captured by then
var _frames: Array = []               # wall-clock frame times (sec) since the last report
var _peak := 0.0                      # the loudest captured sample since the last reset


func _ready() -> void:
	sfx = get_node_or_null("/root/Sfx")
	var parts := what.split(":")
	_say("start spike:%s on %s (%s), %d cores, audio %s at %d Hz, output latency %.1f ms" % [what, OS.get_model_name(),
			OS.get_name(), OS.get_processor_count(), AudioServer.get_driver_name(), AudioServer.get_mix_rate(),
			AudioServer.get_output_latency() * 1000.0])
	if sfx == null:
		_say("no Sfx autoload")
		_finish()
		return
	match parts[0]:
		"boot":
			_run_boot()
		"stems":
			_run_stems(float(parts[1]) if parts.size() > 1 and parts[1].is_valid_float() else 10.0,
					parts.size() > 2 and parts[2] == "pcm")
		_:
			_say("unknown spike '%s' (boot, stems[:minutes[:pcm]])" % what)
			_finish()


func _process(_dt: float) -> void:
	_frames.append(Time.get_ticks_usec())
	if _cap != null:
		_drain()


func _say(line: String) -> void:
	print("[spike] " + line)


func _finish() -> void:
	_say("DONE")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _show_title() -> void:
	## Out of main's bot level (when main didn't route the spike) onto the title.
	if host != null and host.has_method("show_title"):
		var cur = host.get("current")
		if cur == null or not cur.has_signal("start"):
			host.show_title()


func _frame_stats() -> Dictionary:
	## The frames since the last call: {n, fps, worst (ms), over (frames past 16.7 ms)}.
	var out := {"n": 0, "fps": 0.0, "worst": 0.0, "over": 0}
	if _frames.size() >= 2:
		var worst := 0.0
		var over := 0
		for i in range(1, _frames.size()):
			var d := (int(_frames[i]) - int(_frames[i - 1])) / 1000.0
			worst = maxf(worst, d)
			over += 1 if d > 16.7 else 0
		var span := (int(_frames[-1]) - int(_frames[0])) / 1e6
		out = {"n": _frames.size() - 1, "fps": (_frames.size() - 1) / maxf(span, 0.001), "worst": worst, "over": over}
	_frames = [_frames[-1]] if not _frames.is_empty() else []
	return out


# ---------------------------------------------------------------- boot

static func dummy_banks(cache_dir := "") -> Array:
	## A stand-in for v3's banks: every v3 name, in its bank, rendered with
	## its FALLBACK's recipe (so about the cost of a real one), the frequent
	## ones twice.
	var render := Callable(load(SELF_PATH), "dummy_render")
	var out := []
	for id in SfxLib.BANK_ORDER:
		var names: Array = SfxLib.BANKS[id]
		var takes := {}
		for n in names:
			if DUMMY_TAKES.has(n):
				takes[n] = 2
		out.append({"id": id, "names": names, "takes": takes, "jitter": {}, "render": render,
				"cache": cache_dir.path_join("sfx_cache_%s.bin" % id) if cache_dir != "" else "", "key": "spike-dummy|" + id})
	return out


static func spike_banks(cache_dir := "") -> Array:
	## The v3 banks the boot spike times: each real bank file (Sfx.load_bank,
	## its caches in cache_dir) and, for a bank not written yet, its dummy.
	var dummies := dummy_banks(cache_dir)
	var out := []
	for i in range(SfxLib.BANK_ORDER.size()):
		var real := SfxLib.load_bank(SfxLib.BANK_ORDER[i], cache_dir)
		out.append(real if not real.is_empty() else dummies[i])
	return out


static func dummy_render(sound: String, take: int) -> PackedFloat32Array:
	return SfxLib.render(str(SfxLib.FALLBACK.get(sound, "click")), take)


static func recordings(banks: Array) -> int:
	var n := 0
	for b in banks:
		for s in b["names"]:
			n += int((b["takes"] as Dictionary).get(s, 1))
	return n


static func wipe(dir: String) -> void:
	var path := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(path)
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))


func _run_boot() -> void:
	_show_title()
	# The live boot: this launch's own render (from its cache, or cold).
	var t0 := Time.get_ticks_msec()
	while not sfx.is_loaded() and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	var live: Dictionary = sfx.boot_times()
	var cold := not live.has("core:cached")
	_say("live boot (%s): Sfx made %d ms after the engine started; menus %s, voices %s, core %s ms%s" % [
			"cold: no cache" if cold else "warm: from the cache", int(live.get("init", -1)), live.get("menus", "?"),
			live.get("voices", "?"), live.get("core", "?"), "" if sfx.banks_for(0).size() <= 1 else ", all banks " + str(live.get(sfx.banks_for(0)[-1], "?"))])
	var title_ms := int(live.get("voices", -1))
	if cold and title_ms >= 0:
		_say("RESULT live first boot: the title's sounds ready %d ms after the engine started (gate %d ms): %s" % [
				title_ms, BOOT_GATE_MS, "PASS" if title_ms <= BOOT_GATE_MS else "FAIL"])
	# Cold boots with the v3 banks.
	var results := {}
	for threads in [1, 2, 3]:
		results[threads] = await _cold(threads)
	# A warm boot from the caches the last cold boot left.
	var banks := [SfxLib.core_bank(SfxLib, "user://spike_sfx")] + spike_banks("user://spike_sfx")
	var streams := {}
	var lock := Mutex.new()
	var stamps := {}
	var w0 := Time.get_ticks_usec()
	for b in banks:
		SfxLib.render_bank(streams, lock, [false], b, stamps)
	var warm_ms := (Time.get_ticks_usec() - w0) / 1000.0
	var cached := banks.filter(func(b): return stamps.has(str(b["id"]) + ":cached")).size()
	_say("warm boot: %d of %d banks from their caches in %.0f ms" % [cached, banks.size(), warm_ms])
	var best := 1
	for t in results:
		if float(results[t]["all"]) < float(results[best]["all"]) * 0.9:
			best = t
	var one: Dictionary = results[1]
	_say("RESULT cold boot with the v3 banks (%d recordings): the title's sounds in %d ms (gate %d ms): %s; the core in %d ms; everything in %d ms on 1 thread, %d on 2, %d on 3; fastest worth it: %d (Sfx.RENDER_THREADS is %d)" % [
			one["recordings"], one["voices"], BOOT_GATE_MS, "PASS" if float(one["voices"]) <= BOOT_GATE_MS else "FAIL",
			one["core"], one["all"], results[2]["all"], results[3]["all"], best, SfxLib.RENDER_THREADS])
	_say("RESULT warm boot: every bank from the cache in %.0f ms" % warm_ms)
	wipe("user://spike_sfx")
	# The game's own caches go too, so the next launch is a true first boot.
	var user := ProjectSettings.globalize_path("user://")
	for f in DirAccess.get_files_at(user):
		if f.begins_with("sfx_cache") and f.ends_with(".bin"):
			DirAccess.remove_absolute(user.path_join(f))
	_say("wiped the game's sound caches: launch spike:boot again for a true first boot (the live line)")
	_finish()


func _cold(threads: int) -> Dictionary:
	## One cold boot: the core and the v3 banks rendered from nothing on
	## `threads` threads (as Sfx does), with the frame rate meanwhile.
	var dir := "user://spike_sfx"
	wipe(dir)
	var banks := [SfxLib.core_bank(SfxLib, dir)] + spike_banks(dir)
	var streams := {}
	var lock := Mutex.new()
	var cancel := [false]
	var queue := banks.map(func(b): return b["id"])
	var done := {}
	var stamps := {}
	var t0 := Time.get_ticks_msec()
	var list: Array[Thread] = []
	for i in range(threads):
		var t := Thread.new()
		t.start(Callable(SfxLib, "_render_banks").bind(streams, lock, cancel, banks, queue, done, [""], stamps), Thread.PRIORITY_LOW)
		list.append(t)
	_frame_stats()
	while true:
		lock.lock()
		var n := done.size()
		lock.unlock()
		if n >= banks.size():
			break
		await get_tree().process_frame
	for t in list:
		t.wait_to_finish()
	var frames := _frame_stats()
	var rec := recordings(banks)
	var out := {"recordings": rec, "menus": int(stamps.get("menus", t0)) - t0, "voices": int(stamps.get("voices", t0)) - t0,
			"core": int(stamps.get("core", t0)) - t0, "all": Time.get_ticks_msec() - t0}
	var each := []
	for b in banks:
		each.append("%s %d" % [b["id"], int(stamps.get(b["id"], t0)) - t0])
	_say("cold boot, %d thread%s: %d recordings (core %d); menus %d ms, voices %d, done: %s; all %d ms (%.1f ms a recording); frames meanwhile %d at %.0f fps, worst %.1f ms, %d over 16.7 ms" % [
			threads, "" if threads == 1 else "s", rec, recordings([banks[0]]), out["menus"], out["voices"], ", ".join(each),
			out["all"], float(out["all"]) * threads / rec, frames["n"], frames["fps"], frames["worst"], frames["over"]])
	return out


# ---------------------------------------------------------------- stems

static func stem_bytes(index: int, loop := LOOP) -> PackedByteArray:
	## Stem `index` as a 16-bit mono WAV file at Sfx.RATE: `loop` seconds
	## (plus the MUSIC_PAD frames that repeat its start) of silence, with a
	## burst at OFFSET + GAP * index into every PERIOD.
	var rate := SfxLib.RATE
	var frames := roundi(loop * rate) + SfxLib.MUSIC_PAD
	var data := PackedByteArray()
	data.resize(44 + frames * 2)
	data.fill(0)
	data.encode_u32(0, 0x46464952)   # RIFF
	data.encode_u32(4, 36 + frames * 2)
	data.encode_u32(8, 0x45564157)   # WAVE
	data.encode_u32(12, 0x20746d66)  # "fmt "
	data.encode_u32(16, 16)
	data.encode_u16(20, 1)
	data.encode_u16(22, 1)
	data.encode_u32(24, rate)
	data.encode_u32(28, rate * 2)
	data.encode_u16(32, 2)
	data.encode_u16(34, 16)
	data.encode_u32(36, 0x61746164)  # data
	data.encode_u32(40, frames * 2)
	for k in range(roundi(loop / PERIOD)):
		var at := roundi((k * PERIOD + OFFSET + index * GAP) * rate)
		for j in range(BURST):
			var v := BURST_AMP * sin(TAU * BURST_HZ * j / rate) * (0.5 - 0.5 * cos(TAU * j / BURST))
			data.encode_s16(44 + (at + j) * 2, roundi(v * 32767.0))
	return data


static func make_stems(pcm: bool, loop := LOOP) -> Array:
	## The five stems, looping as Sfx loops music (QOA as the importer
	## compresses the music, unless pcm).
	var out := []
	for i in range(STEMS):
		var wav := AudioStreamWAV.load_from_buffer(stem_bytes(i, loop), {"compress/mode": 0 if pcm else 2})
		out.append(SfxLib.loop_music(wav))
	return out


static func mix_cost(streams: Array, seconds: float) -> float:
	## Msec to mix `seconds` of every stream in one AudioStreamSynchronized
	## on this thread: what the audio thread spends on them.
	var sync: AudioStream = ClassDB.instantiate("AudioStreamSynchronized")
	sync.set("stream_count", streams.size())
	for i in range(streams.size()):
		sync.call("set_sync_stream", i, streams[i])
	var pb := sync.instantiate_playback()
	pb.start(0.0)
	var frames := roundi(seconds * AudioServer.get_mix_rate())
	var t0 := Time.get_ticks_usec()
	var done := 0
	while done < frames:
		done += pb.mix_audio(1.0, 512).size()
	pb.stop()
	return (Time.get_ticks_usec() - t0) / 1000.0


static func analyze(onsets: Array, rate: float) -> Dictionary:
	## The bursts found (capture frames) read back as (period, stem): which of
	## the SLOTS in a period is stem 0 comes from where the gap of empty slots
	## falls. Returns {periods, found, stray, drift (the widest spread, in
	## frames, of any stem's offset from stem 0 against its GAP * i, over the
	## run), worst (that stem), offset (the largest offset itself), clock (stem
	## 0's lag behind PERIOD * k, in frames, at the end: the stream's clock
	## against the output's), clock_frames (the frames that spans)}.
	var out := {"periods": 0, "found": onsets.size(), "stray": 0, "drift": 0.0, "worst": -1, "offset": 0.0,
			"clock": 0.0, "clock_frames": 0}
	if onsets.size() < SLOTS:
		return out
	var first: int = onsets[0]
	var slots := []
	var count := []
	count.resize(SLOTS)
	count.fill(0)
	for o in onsets:
		var s := roundi((int(o) - first) / rate / GAP)
		slots.append(s)
		count[posmod(s, SLOTS)] += 1
	var p0 := 0
	var best := -1
	for p in range(SLOTS):
		var c := 0
		for i in range(STEMS):
			c += int(count[(p + i) % SLOTS])
		if c > best:
			best = c
			p0 = p
	var periods := {}   # k -> {stem: frame}
	for j in range(onsets.size()):
		var q: int = int(slots[j]) - p0
		var stem := posmod(q, SLOTS)
		if stem >= STEMS:
			out["stray"] += 1
			continue
		var k := floori(q / float(SLOTS))
		if not periods.has(k):
			periods[k] = {}
		periods[k][stem] = int(onsets[j])
	var lo := {}
	var hi := {}
	var k0 := -1
	var f0 := 0
	var last_k := -1
	var last_f := 0
	var ks := periods.keys()
	ks.sort()
	for k in ks:
		var p: Dictionary = periods[k]
		if not p.has(0):
			continue
		if k0 < 0:
			k0 = k
			f0 = p[0]
		last_k = k
		last_f = p[0]
		for stem in p:
			if stem == 0:
				continue
			var d: float = float(int(p[stem]) - int(p[0])) - stem * GAP * rate
			lo[stem] = minf(float(lo.get(stem, d)), d)
			hi[stem] = maxf(float(hi.get(stem, d)), d)
			out["offset"] = maxf(float(out["offset"]), absf(d))
	for stem in lo:
		var spread: float = float(hi[stem]) - float(lo[stem])
		if spread > float(out["drift"]) or int(out["worst"]) < 0:
			out["drift"] = spread
			out["worst"] = stem
	out["periods"] = periods.size()
	if k0 >= 0 and last_k > k0:
		out["clock"] = float(last_f - f0) - (last_k - k0) * PERIOD * rate
		out["clock_frames"] = last_f - f0
	return out


func _run_stems(minutes: float, pcm: bool) -> void:
	_show_title()
	var kind := "PCM" if pcm else "QOA"
	var t0 := Time.get_ticks_usec()
	var streams := make_stems(pcm)
	_say("stems: made %d %s stems of %.0f s in %.0f ms" % [streams.size(), kind, LOOP, (Time.get_ticks_usec() - t0) / 1000.0])
	var cost := mix_cost(streams, 10.0)
	_say("stems: mixing 10 s of all %d at once takes %.1f ms on this thread: %.2f%% of a core on the audio thread" % [
			streams.size(), cost, cost / 100.0])
	# Music on for the run whatever the settings say (in memory, never saved).
	var settings: Dictionary = sfx.get("_settings")
	var saved := settings.duplicate()
	settings["music_muted"] = false
	settings["volume"] = 1.0
	sfx.stop_music(0.0)
	var names := []
	for i in range(STEMS):
		names.append("spike_stem_%d" % i)
	sfx.register_stems("spike", names, streams)
	_rate = AudioServer.get_mix_rate()
	var bus := AudioServer.get_bus_index(SfxLib.MUSIC_BUS)
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, _cap)
	await get_tree().create_timer(0.3).timeout
	_cap.clear_buffer()
	_n = 0
	_wall0 = 0
	_ignore_before = 0
	sfx.play_stems("spike")
	_say("stems: playing '%s' as %s through Sfx.play_stems for %.1f min; capturing the Music bus at %d Hz" % [
			"spike", sfx.stem_mode(), minutes, _rate])
	var start := Time.get_ticks_msec()
	var next := REPORT_EVERY
	_frame_stats()
	var a := {}
	var last := 0.0
	while (Time.get_ticks_msec() - start) / 1000.0 < minutes * 60.0:
		await get_tree().process_frame
		var t := (Time.get_ticks_msec() - start) / 1000.0
		if t >= next:
			next += REPORT_EVERY
			a = analyze(_onsets, _rate)
			_report(t, a)
			last = t
	a = analyze(_onsets, _rate)
	if (Time.get_ticks_msec() - start) / 1000.0 - last > 5.0:
		_report((Time.get_ticks_msec() - start) / 1000.0, a)
	var want := int(a["periods"]) * STEMS
	var drift_ms := float(a["drift"]) / _rate * 1000.0
	var ok := drift_ms <= GATE_MS and int(a["found"]) >= want * 0.98 and int(a["periods"]) >= int(minutes * 60.0 / PERIOD) - 3
	_say("RESULT stems: %.1f min of %d %s stems in one AudioStreamSynchronized: the widest drift between stems %d frames = %.2f ms (gate %.2f ms, one frame at 120 Hz), %d of %d bursts, %d stray: %s -> %s" % [
			minutes, STEMS, kind, roundi(float(a["drift"])), drift_ms, GATE_MS, a["found"], want, a["stray"],
			"PASS" if ok else "FAIL", "keep the stems (Sfx.STEMS_PREMIXED = false)" if ok else "use the pre-mixed fallback (Sfx.STEMS_PREMIXED = true)"])
	_say("RESULT stems: the music's own clock against the output's %+.1f ms over %.1f min (%+.1f ppm): what seek_music(ftime) corrects" % [
			float(a["clock"]) / _rate * 1000.0, float(a["clock_frames"]) / _rate / 60.0,
			float(a["clock"]) / maxf(1.0, float(a["clock_frames"])) * 1e6])
	await _extras(names)
	AudioServer.remove_bus_effect(bus, _bus_effect(bus, _cap))
	_cap = null
	sfx.stop_music(0.0)
	for k in saved:
		settings[k] = saved[k]
	_finish()


func _report(t: float, a: Dictionary) -> void:
	var f := _frame_stats()
	var wall := (Time.get_ticks_usec() - _wall0) / 1e6 if _wall0 > 0 else 0.0
	var audio := (_n - _n_wall0) / _rate
	_say("stems t=%.0fs: %d periods, %d bursts, %d stray | drift between stems %d frames (%.2f ms), largest offset %d | stream vs output %+.1f ms | output vs wall %+.1f ms (%+.0f ppm) | %.0f fps, worst frame %.1f ms" % [
			t, a["periods"], a["found"], a["stray"], roundi(float(a["drift"])), float(a["drift"]) / _rate * 1000.0,
			roundi(float(a["offset"])), float(a["clock"]) / _rate * 1000.0, (audio - wall) * 1000.0,
			(audio - wall) / maxf(wall, 0.001) * 1e6, f["fps"], f["worst"]])


func _drain() -> void:
	## Take what the capture holds and find the bursts in it.
	var n := _cap.get_frames_available()
	if n <= 0:
		return
	var buf := _cap.get_buffer(n)
	if _wall0 == 0:
		_wall0 = Time.get_ticks_usec()
		_n_wall0 = _n + buf.size()
	for i in range(buf.size()):
		var v := absf(buf[i].x)
		_peak = maxf(_peak, v)
		if _inb:
			if v < QUIET:
				_quiet += 1
				if _quiet > QUIET_FRAMES:
					_inb = false
			else:
				_quiet = 0
		elif v > THRESHOLD:
			_inb = true
			_quiet = 0
			if _n + i >= _ignore_before:
				_onsets.append(_n + i)
	_n += buf.size()


func _bus_effect(bus: int, effect: AudioEffect) -> int:
	for i in range(AudioServer.get_bus_effect_count(bus)):
		if AudioServer.get_bus_effect(bus, i) == effect:
			return i
	return AudioServer.get_bus_effect_count(bus) - 1


func _listen(seconds: float) -> Dictionary:
	## A fresh stretch of bursts after a change (the spacing within a period
	## only: a tape stop or a seek moves where the periods fall).
	_onsets = []
	_ignore_before = _n + roundi(0.3 * _rate)
	_peak = 0.0
	await get_tree().create_timer(seconds).timeout
	return analyze(_onsets, _rate)


func _stems_seen(onsets: Array) -> Dictionary:
	## How many bursts each stem left, by slot (for a stem faded out).
	var a := {}
	if onsets.size() < 2:
		return a
	var first: int = onsets[0]
	for o in onsets:
		var s := posmod(roundi((int(o) - first) / _rate / GAP), SLOTS)
		a[s] = int(a.get(s, 0)) + 1
	return a


func _extras(names: Array) -> void:
	## set_stem, tape_stop/tape_go and seek_music on the playing stems.
	await _listen(4.5)
	var before := _stems_seen(_onsets).size()
	sfx.set_stem(names[4], SfxLib.STEM_OFF_DB, 1.0)
	await get_tree().create_timer(1.2).timeout
	await _listen(6.0)
	var during := _stems_seen(_onsets).size()
	sfx.set_stem(names[4], 0.0, 1.0)
	await get_tree().create_timer(1.2).timeout
	await _listen(6.0)
	var after := _stems_seen(_onsets).size()
	_say("RESULT set_stem: stems heard %d, with stem 4 faded to %d dB %d, back up %d: %s" % [before, SfxLib.STEM_OFF_DB,
			during, after, "PASS" if before == STEMS and during == STEMS - 1 and after == STEMS else "FAIL"])
	sfx.tape_stop(0.35)
	await get_tree().create_timer(0.6).timeout
	_peak = 0.0
	await get_tree().create_timer(1.5).timeout
	var held := _peak
	sfx.tape_go(0.25)
	await get_tree().create_timer(0.8).timeout
	var tape := await _listen(8.5)
	_say("RESULT tape_stop/tape_go: peak while stopped %.4f, then %d bursts, drift between stems %d frames: %s" % [
			held, tape["found"], roundi(float(tape["drift"])), "PASS" if held < 0.001 and int(tape["found"]) >= 15 and float(tape["drift"]) / _rate * 1000.0 <= GATE_MS else "FAIL"])
	sfx.seek_music(17.3)
	await get_tree().create_timer(0.8).timeout
	var seek := await _listen(8.5)
	_say("RESULT seek_music: then %d bursts, drift between stems %d frames: %s" % [seek["found"], roundi(float(seek["drift"])),
			"PASS" if int(seek["found"]) >= 15 and float(seek["drift"]) / _rate * 1000.0 <= GATE_MS else "FAIL"])
