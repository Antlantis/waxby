# Writes every Sfx sound (every take) as a .wav so a human can listen, and
# prints each one's length, peak, loudness (the loudest 50 ms, RMS), DC
# offset, end samples, how bright it is (its RMS frequency, from the energy
# of its slope), how much of it a phone speaker plays (the energy share above
# 250 Hz), the share in 500 Hz-3 kHz where a tell must sit (test_sfx wants
# 40% of a tell there), its sharpest click-like spike (see spike_ratio) and
# its render time.
# Every sound with a recipe: the core's (sfx.gd) and each v3 bank file's
# (scripts/sfx_<bank>.gd), bank by bank; then the v3 names still waiting for
# a recipe, with the fallback each plays meanwhile.
# Output defaults to /private/tmp/claude-501/wick-audio (the path is printed).
# Name sounds (or banks: core, story, w3 ... modes) after the directory to
# render only those.
#
#   Godot --headless --path game --script res://../tools/audio/render_sfx.gd [-- <out_dir> [sound|bank ...]]
extends SceneTree

const SfxLib := preload("res://scripts/sfx.gd")
const DEFAULT_OUT := "/private/tmp/claude-501/wick-audio"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else DEFAULT_OUT
	var only: Array = args.slice(1) if args.size() > 1 else []
	out_dir = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("%-16s %6s %7s %7s %8s %6s %6s %6s %5s %5s %6s" % ["sound", "secs", "peak", "loud", "dc", "edge", "bright", ">250", "mids", "spike", "ms"])
	var total_ms := 0
	var files := 0
	var made := {}
	for bank in SfxLib.bank_list(SfxLib):
		var render: Callable = bank["render"]
		for sound in bank["names"]:
			made[sound] = true
			if not only.is_empty() and not only.has(sound) and not only.has(bank["id"]):
				continue
			for take in range(int((bank["takes"] as Dictionary).get(sound, 1))):
				var t0 := Time.get_ticks_usec()
				var s: PackedFloat32Array = render.call(sound, take)
				var ms := (Time.get_ticks_usec() - t0) / 1000
				total_ms += ms
				var label: String = sound if take == 0 else "%s#%d" % [sound, take]
				var file: String = sound if take == 0 else "%s_%d" % [sound, take]
				SfxLib.to_wav(s).save_to_wav("%s/%s.wav" % [out_dir, file])
				files += 1
				var peak := 0.0
				var sum := 0.0
				for v in s:
					peak = maxf(peak, absf(v))
					sum += v
				var edge := maxf(maxf(absf(s[0]), absf(s[-1])), maxf(absf(s[1] - s[0]), absf(s[-1] - s[-2])))
				print("%-16s %6.3f %7.1f %7.1f %8.5f %6.4f %6d %5d%% %4d%% %5.1f %6d" % [label, s.size() / float(SfxLib.RATE),
						linear_to_db(peak), SfxLib.loudness_db(s), sum / s.size(), edge, roundi(bright_hz(s)),
						roundi(100.0 * share_above(s, 250.0)), roundi(100.0 * (share_above2(s, 500.0) - share_above2(s, 3000.0))),
						spike_ratio(s), ms])
	print("wrote %d files to %s (render %.2f s on the main thread)" % [files, out_dir, total_ms / 1000.0])
	var waiting := []
	for id in SfxLib.BANK_ORDER:
		for sound in SfxLib.BANKS[id]:
			if not made.has(sound):
				waiting.append("%s (%s: %s)" % [sound, id, SfxLib.FALLBACK[sound]])
	if not waiting.is_empty():
		print("%d v3 sounds have no recipe yet and play their fallback: %s" % [waiting.size(), ", ".join(waiting)])
	quit()


static func bright_hz(s: PackedFloat32Array) -> float:
	## The RMS frequency: sqrt(energy of the slope / energy) scaled to Hz. A
	## pure tone gives its own pitch; a bright sound gives a high number.
	var e := 0.0
	var d := 0.0
	for i in range(1, s.size()):
		e += s[i] * s[i]
		var x := s[i] - s[i - 1]
		d += x * x
	return SfxLib.RATE / TAU * 2.0 * asin(minf(1.0, 0.5 * sqrt(d / maxf(e, 1e-20))))


static func share_above(s: PackedFloat32Array, hz: float) -> float:
	## The fraction of the energy above hz (a one-pole high-pass).
	var a := 1.0 / (1.0 + TAU * hz / SfxLib.RATE)
	var y := 0.0
	var prev := 0.0
	var high := 0.0
	var all := 0.0
	for v in s:
		y = a * (y + v - prev)
		prev = v
		high += y * y
		all += v * v
	return high / maxf(all, 1e-20)


static func share_above2(s: PackedFloat32Array, hz: float) -> float:
	## The fraction of the energy above hz through a 2nd-order Butterworth
	## high-pass (as test_sfx's): the difference of two gives a band's share.
	var w := TAU * hz / SfxLib.RATE
	var alpha := sin(w) / (2.0 * 0.7071)
	var c := cos(w)
	var a0 := 1.0 + alpha
	var b0 := (1.0 + c) / 2.0 / a0
	var b1 := -(1.0 + c) / a0
	var a1 := -2.0 * c / a0
	var a2 := (1.0 - alpha) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var high := 0.0
	var all := 0.0
	for v in s:
		var y := b0 * v + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = v
		y2 = y1
		y1 = y
		high += y * y
		all += v * v
	return high / maxf(all, 1e-20)


static func spike_ratio(s: PackedFloat32Array) -> float:
	## How far the sharpest bend in the wave (its second difference) stands
	## above the bends around it (the RMS over +-5 ms). A click is a lone
	## spike, 10x and up; a sound's own attacks and noise stay far lower.
	var n := s.size()
	var d2 := PackedFloat32Array()
	d2.resize(n)
	d2.fill(0.0)
	for i in range(1, n - 1):
		d2[i] = s[i + 1] - 2.0 * s[i] + s[i - 1]
	var w := int(0.005 * SfxLib.RATE)
	var sq := PackedFloat64Array()
	sq.resize(n + 1)
	sq[0] = 0.0
	for i in range(n):
		sq[i + 1] = sq[i] + d2[i] * d2[i]
	var worst := 0.0
	for i in range(n):
		var v := absf(d2[i])
		if v < 0.004:
			continue
		var lo := maxi(0, i - w)
		var hi := mini(n, i + w + 1)
		var others := (sq[hi] - sq[lo] - v * v) / maxf(1.0, hi - lo - 1)
		worst = maxf(worst, v / sqrt(maxf(others, 1e-12)))
	return worst
