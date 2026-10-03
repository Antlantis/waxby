extends RefCounted
## Sfx's World 6 bank, the Hushdeep (contract.md section 14): the black lake,
## floats and bell-buoys, still water, grasps, Hush zones, the tide, its
## monsters and the Hush. The family is breath and silence: air, sounds
## played backwards, drowned bells, sounds that stop dead. Until rendered each
## plays its FALLBACK. Tells last at least 0.35 s and sit in 500 Hz-3 kHz
## (test_sfx), silence tells too: each ends in quiet but begins audibly.
##
## Pitchable on purpose: finale_ring is on D3, played at Sfx.note(0) ...
## note(5) for the six rings (D3 F3 G3 A3 C4 D4).
##
## A tell that builds is cut for its longest tell, its threat landing
## TELL_AT seconds in (Sfx.tell trims its start for a shorter one); one that
## warns with its onset (the Gaze's lock, the lake going still) plays whole.
## Two open a telegraphed silence
## by themselves (Sfx.SILENCES): hush_silence, the Snuff's tell (a breath
## swelling 0.9 s, then all sound gone for the 0.3 s before the hand lands),
## and deep_quiet (a breath stopped dead at 0.5 s, then nothing until the
## water rises at 1.6 s). Tonal sounds are never jittered.

const S := preload("res://scripts/sfx.gd")

const NAMES := [
	# the features
	"lake_step", "float_sink", "buoy_toll", "still_crack", "grasp_hiss", "candle_light", "buoy_light",
	"hush_near", "tide_rise",
	# the monsters
	"hush_pop", "stitch_snap", "gulp_inhale", "choke_spit", "echo_whisper", "unwick_fade", "lake_still",
	"coil_splash", "coil_hiss",
	# the Hush, the long ones last
	"hush_still", "bell_peal_sunken", "grasp_rise", "snuff_slam", "inhale_roar", "choke", "flame_freed",
	"gaze_lock", "deep_quiet", "hush_eye_open", "hush_wince", "hush_blink", "hush_silence",
	"hush_scream_silent", "finale_ring",
]
const TAKES := {"lake_step": 3}
const JITTER := {"lake_step": 0.05, "coil_splash": 0.03, "hush_pop": 0.04, "grasp_rise": 0.02}
# When each building tell's threat lands, in seconds from its start (spec
# 3.7 and 4.5, deep.gd's DIFF_KNOBS at Dusk, the Hush's first-phase tells,
# 5.5).
const TELL_AT := {"still_crack": 1.5, "grasp_hiss": 0.60, "stitch_snap": 1.0, "gulp_inhale": 0.8, "echo_whisper": 0.6,
		"hush_still": 0.65, "inhale_roar": 0.8, "deep_quiet": 1.6, "hush_silence": 1.2}


static func _drowned_bell(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, prime_hz: float, amp: float,
		ring: float, length: float) -> void:
	## A bell under black water: a great bell muffled (its crowd of high
	## partials drowned), lapping slowly in level as the water moves over it,
	## with a stone hall's tail. Rendered on its own and laid into b at `at`.
	var bell := S._silence(length)
	S._great_bell(bell, rng, 0.0, prime_hz, amp, ring)
	S._muffle(bell, 2400.0)
	S._tremolo(bell, 0.3, length - 0.3, 3.2, 0.25)
	S._space(bell, 0.35, 1.4, 0.8)
	S._layer(b, at, bell)


static func render(sound: String, take: int = 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound) + 7919 * take
	var b: PackedFloat32Array
	match sound:
		# ---- the lake
		"lake_step":
			# A step in the black lake's shallows (or onto a float): a soft lap
			# of water and a tiny drip. Three takes.
			b = S._silence(0.16)
			S._band(b, rng, 0.0, 0.12, 1.0, [[0.0, 0.0], [0.015, 1.0], [0.12, 0.0]], [[0.0, 900.0], [0.12, 420.0]], 1.2)
			var f0 := rng.randf_range(1000.0, 1400.0)
			S._sweep(b, 0.05 + 0.02 * take, [[0.0, f0], [0.02, f0 * 1.9]], 0.3, 0.02, 0.05, [1.0])
			return S._finish(b, -25.0, 0.03)
		"float_sink":
			# A wax float starting to go under him (about 1.7 s to the water):
			# the wax creaking, fat bubbles glugging up slower and lower, the
			# water closing over the rim.
			b = S._silence(1.2)
			S._creak(b, rng, 0.0, 0.5, [[0.0, 30.0], [0.5, 18.0]], 560.0, 0.3, [[0.0, 1.0], [0.5, 0.2]])
			var t := 0.05
			var gap := 0.08
			while t < 1.1:
				var f := rng.randf_range(520.0, 900.0) * (1.0 - 0.35 * t)
				S._sweep(b, t, [[0.0, f], [0.05, f * 1.6]], 0.5 * (1.0 - 0.5 * t), 0.04, 0.07, [1.0, 0.25])
				t += gap * rng.randf_range(0.7, 1.3)
				gap = minf(0.2, gap * 1.12)
			S._band(b, rng, 0.2, 1.0, 0.3, [[0.0, 0.0], [0.6, 1.0], [1.0, 0.0]], [[0.0, 1200.0], [1.0, 600.0]], 1.0)
			return S._finish(b, -19.0, 0.15)
		"buoy_toll":
			# A bell-buoy tolls: a deep drowned bell on A (its strike A3),
			# lapping on the water, and the lake falling still around it.
			b = S._silence(2.8)
			_drowned_bell(b, rng, 0.0, S._hz(45), 0.8, 0.8, 2.8)
			S._bell(b, 0.0, S._hz(69), 0.55, 0.8)
			S._bell(b, 0.0, S._hz(69) + 2.0, 0.3, 0.8)
			S._chime(b, 0.01, S._hz(81), 0.2, 0.5)
			S._band(b, rng, 0.0, 0.3, 0.3, [[0.0, 0.0], [0.03, 1.0], [0.3, 0.0]], [[0.0, 900.0], [0.3, 400.0]], 1.0)
			return S._finish(b, -12.5, 0.6)
		"still_crack":
			# Still water failing (its last 1.5 s): the stilled surface
			# cracking, a hiss rising and ripples starting to run.
			b = S._silence(1.52)
			S._band(b, rng, 0.0, 1.5, 1.0, [[0.0, 0.1], [1.35, 1.0], [1.5, 0.0]], [[0.0, 1200.0], [1.5, 2600.0]], 1.5)
			var t := 0.02
			while t < 1.45:
				S._partial(b, t, rng.randf_range(1500.0, 3200.0), 0.1 + 0.3 * t / 1.5, 0.006, 0.0008)
				t += 0.12 - 0.07 * t / 1.5
			for i in range(6):
				var at := 0.6 + 0.14 * i
				var f := rng.randf_range(700.0, 1000.0)
				S._sweep(b, at, [[0.0, f], [0.03, f * 1.5]], 0.25, 0.03, 0.06, [1.0])
			return S._finish(b, -17.0, 0.03)
		"grasp_hiss":
			# A Hushgrasp about to rise (its 0.6 s tell): a cold, bright hiss
			# off the water (brighter than the Snuffer's "shhh", never mistaken
			# for it), ripples ringing out, a hollow note under the lake.
			b = S._silence(0.62)
			var lv := [[0.0, 0.0], [0.45, 1.0], [0.6, 0.8], [0.62, 0.0]]
			S._band(b, rng, 0.0, 0.62, 0.8, lv, [[0.0, 2200.0], [0.6, 3000.0]], 3.0)
			S._band(b, rng, 0.0, 0.62, 0.6, lv, [[0.0, 1300.0], [0.6, 1700.0]], 2.5)
			S._band(b, rng, 0.0, 0.62, 0.4, lv, [[0.0, 4500.0], [0.6, 5200.0]], 2.0)
			for i in range(4):
				var f := rng.randf_range(800.0, 1100.0)
				S._sweep(b, 0.08 + 0.13 * i, [[0.0, f], [0.03, f * 1.6]], 0.2, 0.03, 0.06, [1.0])
			var hollow := S._silence(0.6)
			S._sweep(hollow, 0.0, [[0.0, S._hz(62)]], 0.3, 20.0, 0.6, [1.0, 0.5, 0.3, 0.15])
			S._layer(b, 0.0, hollow, [[0.0, 0.0], [0.5, 1.0], [0.6, 0.0]])
			return S._finish(b, -16.0, 0.02)
		"candle_light":
			# A Vigil candle relit (a haven for good): a match scratched, a
			# small warm flame catching and a chime, A5 and D6.
			b = S._silence(0.9)
			for i in range(3):
				S._air(b, rng, i * 0.015, 0.018, 0.5, 2400.0, 3400.0, 2600.0, 0.3, 1.8)
			S._air(b, rng, 0.05, 0.35, 0.7, 300.0, 1200.0, 700.0, 0.35, 0.9)
			S._chime(b, 0.12, S._hz(81), 0.5, 0.3)
			S._chime(b, 0.2, S._hz(86), 0.6, 0.4)
			S._bell(b, 0.2, S._hz(93), 0.15, 0.25)
			return S._finish(b, -17.0, 0.2)
		"buoy_light":
			# A buoy's lantern lit by the toll: a wet ignition (a hiss and the
			# flame taking) and a low bell partial on D4.
			b = S._silence(1.0)
			S._hiss(b, rng, 0.0, 0.2, 0.5, 0.6)
			S._air(b, rng, 0.03, 0.45, 0.9, 250.0, 1400.0, 800.0, 0.3, 0.9)
			S._bell(b, 0.15, S._hz(62), 0.5, 0.5)
			S._chime(b, 0.2, S._hz(74), 0.4, 0.35)
			return S._finish(b, -17.0, 0.2)
		"hush_near":
			# The Hush close (a Hush zone's edge, the hush crossing 0.5): a slow
			# low-pressure swell, the air thickening, sagging away.
			b = S._silence(1.5)
			var lv := [[0.0, 0.0], [0.7, 1.0], [1.5, 0.0]]
			S._band(b, rng, 0.0, 1.5, 1.0, lv, [[0.0, 300.0], [0.7, 480.0], [1.5, 280.0]], 3.0)
			S._band(b, rng, 0.0, 1.5, 0.35, lv, [[0.0, 900.0], [1.5, 700.0]], 1.2)
			var swell := S._silence(1.5)
			S._sweep(swell, 0.0, [[0.0, 150.0], [0.7, 175.0], [1.5, 140.0]], 0.4, 20.0, 1.5, [1.0, 0.8, 0.6, 0.4, 0.3])
			S._layer(b, 0.0, swell, lv)
			return S._finish(b, -20.0, 0.2)
		"tide_rise":
			# The Hush tide (6-3's chase): the dark rolling in behind him, a
			# deep hushing roar swelling up, the water churning.
			b = S._silence(2.0)
			var lv := [[0.0, 0.0], [1.2, 1.0], [1.7, 0.85], [2.0, 0.0]]
			S._band(b, rng, 0.0, 2.0, 1.0, lv, [[0.0, 400.0], [1.2, 900.0], [2.0, 600.0]], 1.0)
			S._band(b, rng, 0.0, 2.0, 0.4, lv, [[0.0, 1800.0], [1.2, 3200.0], [2.0, 2400.0]], 1.2)
			var roar := S._silence(2.0)
			S._sweep(roar, 0.0, [[0.0, 110.0], [1.2, 146.83], [2.0, 110.0]], 0.4, 20.0, 2.0, [1.0, 0.8, 0.6, 0.5, 0.4, 0.3, 0.2], 0.04, 7.0)
			S._layer(b, 0.0, roar, lv)
			for i in range(10):
				var t := 0.4 + rng.randf() * 1.4
				var f := rng.randf_range(400.0, 800.0)
				S._sweep(b, t, [[0.0, f], [0.04, f * 1.6]], 0.25, 0.03, 0.07, [1.0, 0.3])
			return S._finish(b, -14.0, 0.2)

		# ---- the Hushling
		"hush_pop":
			# A Hushling pops: a little puff of dark sucked backwards into a
			# soft "pff".
			b = S._silence(0.36)
			var pop := S._silence(0.22)
			S._sweep(pop, 0.0, [[0.0, 1400.0], [0.03, 500.0]], 0.8, 0.03, 0.06, [1.0, 0.3])
			S._air(pop, rng, 0.0, 0.2, 0.7, 700.0, 1800.0, 900.0, 0.1, 0.9)
			S._layer(b, 0.0, S._reversed(pop))
			S._air(b, rng, 0.2, 0.14, 0.4, 900.0, 1600.0, 700.0, 0.2, 0.9)
			return S._finish(b, -18.0, 0.05)

		# ---- the Stillmaw
		"stitch_snap":
			# A Stillmaw's stitches snapping one by one (its 1.0 s swallow
			# tell): four threads twanging and popping over a rising in-draw.
			b = S._silence(1.02)
			S._air(b, rng, 0.0, 0.98, 0.6, 600.0, 1500.0, 1600.0, 0.93, 0.9)
			for i in range(4):
				var at := 0.02 + 0.24 * i
				var k := 0.4 + 0.25 * i
				S._partial(b, at, 3300.0, 0.4 * k, 0.006, 0.0008)
				S._sweep(b, at, [[0.0, 1250.0 + 120.0 * i], [0.08, 1050.0 + 120.0 * i]], 0.5 * k, 0.05, 0.1, [1.0, 0.4, 0.2])
				S._hiss(b, rng, at, 0.006, 0.3 * k)
			return S._finish(b, -16.0, 0.03)
		"gulp_inhale":
			# A Stillmaw's Gulp (its 0.8 s tell): a sucking inhale through the
			# porcelain mouth, hollow and rising.
			b = S._silence(0.82)
			S._air(b, rng, 0.0, 0.78, 1.0, 500.0, 1400.0, 1500.0, 0.92, 1.0)
			var hollow := S._silence(0.78)
			S._sweep(hollow, 0.0, [[0.0, 640.0], [0.76, 820.0]], 0.35, 20.0, 0.78, [1.0, 0.3, 0.15], 0.01, 4.0)
			S._layer(b, 0.0, hollow, [[0.0, 0.0], [0.6, 1.0], [0.78, 0.0]])
			return S._finish(b, -16.0, 0.03)
		"choke_spit":
			# Hit mid-swallow: the Stillmaw coughs the light back out, a hard
			# cough and the flame's chime returning, A5 to D6.
			b = S._silence(0.55)
			S._thud(b, 0.0, 420.0, 200.0, 0.8, 0.04)
			S._air(b, rng, 0.0, 0.12, 1.0, 600.0, 1800.0, 700.0, 0.1, 0.8)
			S._chime(b, 0.08, S._hz(81), 0.5, 0.2)
			S._chime(b, 0.16, S._hz(86), 0.6, 0.3)
			return S._finish(b, -15.0, 0.1)

		# ---- the Unwick
		"echo_whisper":
			# An Unwick about to copy his blow (0.6 s before it lands): a
			# whisper drawn in backwards and the ghost of a chime reversed.
			b = S._silence(0.62)
			var w := S._silence(0.6)
			S._band(w, rng, 0.0, 0.6, 1.0, [[0.0, 1.0], [0.15, 0.6], [0.6, 0.0]], [[0.0, 2600.0], [0.6, 2000.0]], 1.8)
			S._band(w, rng, 0.0, 0.6, 0.6, [[0.0, 1.0], [0.6, 0.0]], [[0.0, 1300.0], [0.6, 1100.0]], 2.0)
			S._glass(w, 0.0, S._hz(86), 0.5, 0.15)
			S._layer(b, 0.0, S._reversed(w))
			return S._finish(b, -18.0, 0.02)
		"unwick_fade":
			# An Unwick put out: its dark flame drawn back in, a faint chime
			# sinking, gone.
			b = S._silence(0.8)
			var out := S._silence(0.4)
			S._air(out, rng, 0.0, 0.4, 1.0, 1400.0, 2400.0, 900.0, 0.15, 0.8)
			S._layer(b, 0.0, S._reversed(out))
			S._chime(b, 0.35, S._hz(81), 0.4, 0.15)
			S._chime(b, 0.45, S._hz(74), 0.35, 0.2)
			return S._finish(b, -17.0, 0.15)

		# ---- the Lurecoil
		"lake_still":
			# A Lurecoil about to leap (its 0.8 s tell: the lake goes still):
			# the water drawn in with a soft suck, a hollow note fading, the
			# lure's glow humming, then nothing.
			b = S._silence(0.82)
			var lap := S._silence(0.5)
			S._band(lap, rng, 0.0, 0.5, 1.0, [[0.0, 1.0], [0.5, 0.0]], [[0.0, 1100.0], [0.5, 700.0]], 1.2)
			S._layer(b, 0.0, S._reversed(lap))
			S._harmonica(b, 0.0, S._hz(81), 0.4, 0.78, 0.1, 0.4, 2.0)
			S._sweep(b, 0.0, [[0.0, S._hz(62)], [0.75, S._hz(60)]], 0.25, 20.0, 0.78, [1.0, 0.5, 0.25])
			S._shape(b, [[0.0, 0.6], [0.45, 1.0], [0.8, 0.0]])
			return S._finish(b, -18.0, 0.02)
		"coil_splash":
			# The Lurecoil bursting out of the lake (or diving back): a heavy
			# splash, spray and bubbles.
			b = S._silence(0.85)
			S._thud(b, 0.0, 340.0, 150.0, 0.7, 0.05)
			S._air(b, rng, 0.0, 0.4, 1.0, 500.0, 2400.0, 800.0, 0.12, 0.6)
			S._band(b, rng, 0.0, 0.32, 0.45, [[0.0, 0.0], [0.02, 1.0], [0.32, 0.0]], [[0.0, 2400.0], [0.05, 4800.0], [0.32, 2600.0]], 0.8)
			for i in range(9):
				var t := 0.08 + rng.randf() * 0.5
				var f := rng.randf_range(420.0, 1000.0)
				S._sweep(b, t, [[0.0, f], [0.03, f * 1.7]], rng.randf_range(0.15, 0.3) * (1.0 - t), 0.02, 0.05, [1.0])
			return S._finish(b, -14.0, 0.2)
		"coil_hiss":
			# The Lurecoil's hiss (as it rests its head, or bares its lure): a
			# long serpent's hiss with a flicker of the stolen candle in it.
			b = S._silence(0.62)
			var lv := [[0.0, 0.0], [0.05, 1.0], [0.45, 0.8], [0.6, 0.0]]
			S._band(b, rng, 0.0, 0.6, 1.0, lv, [[0.0, 3600.0], [0.6, 3000.0]], 2.0)
			S._band(b, rng, 0.0, 0.6, 0.5, lv, [[0.0, 1800.0], [0.6, 1500.0]], 2.0)
			S._hiss(b, rng, 0.0, 0.5, 0.15, 0.8)
			return S._finish(b, -17.0, 0.06)

		# ---- the Hush
		"hush_still":
			# A Grasp coming (its 0.65 s tell): the water beside him going still
			# and the sound sucked out of the air (a soft in-draw that stops,
			# with the engine's hush_pulse over it).
			b = S._silence(0.66)
			var draw := S._silence(0.5)
			S._band(draw, rng, 0.0, 0.5, 1.0, [[0.0, 1.0], [0.5, 0.0]], [[0.0, 2200.0], [0.5, 1200.0]], 1.5)
			S._air(draw, rng, 0.0, 0.5, 0.8, 1600.0, 1100.0, 700.0, 0.1, 0.9)
			S._layer(b, 0.0, S._reversed(draw))
			S._partial(b, 0.48, S._hz(74), 0.25, 0.05, 0.004)
			return S._finish(b, -17.0, 0.05)
		"bell_peal_sunken":
			# A sunken bell rung (the Hush Heard): a great drowned bell on D,
			# its peal ring rushing out over the water in a gold shimmer.
			b = S._silence(3.0)
			_drowned_bell(b, rng, 0.0, S._hz(50), 1.0, 0.85, 3.0)
			S._bell(b, 0.0, S._hz(74), 0.35, 0.8)
			var ring := [86, 89, 93, 98, 93]
			for i in range(ring.size()):
				S._chime(b, 0.06 + 0.07 * i, S._hz(ring[i]), 0.15, 0.3)
			S._band(b, rng, 0.02, 0.6, 0.12, [[0.0, 0.0], [0.1, 1.0], [0.6, 0.0]], [[0.0, 2000.0], [0.6, 4000.0]], 2.0)
			return S._finish(b, -12.5, 0.6)
		"grasp_rise":
			# A Hand closing up out of the lake: a surge of water, the grip
			# clenching (a muffled thump) and a cold hiss.
			b = S._silence(0.7)
			S._air(b, rng, 0.0, 0.3, 1.0, 400.0, 1800.0, 800.0, 0.5, 0.8)
			S._band(b, rng, 0.0, 0.3, 0.5, [[0.0, 0.0], [0.15, 1.0], [0.3, 0.0]], [[0.0, 2400.0], [0.3, 4200.0]], 1.2)
			S._thump(b, 0.16, 300.0, 120.0, 0.9, 0.07, 2.5)
			S._muffle(b, 2200.0, 0.16)
			S._band(b, rng, 0.2, 0.45, 0.25, [[0.0, 0.0], [0.05, 1.0], [0.45, 0.0]], [[0.0, 3200.0], [0.45, 2600.0]], 2.5)
			return S._finish(b, -14.0, 0.1)
		"snuff_slam":
			# Snuff: the hand slamming down out of the silence onto an islet: a
			# huge smothered thump, a bronze clang on D4 choked by black water,
			# spray.
			b = S._silence(1.25)
			S._thump(b, 0.0, 300.0, 90.0, 1.0, 0.12, 3.0)
			S._thud(b, 0.0, 480.0, 190.0, 0.9, 0.07)
			var clang := S._silence(1.2)
			S._bronze(clang, 0.0, S._hz(62), 0.8, 0.3)
			S._muffle(clang, 1800.0)
			S._layer(b, 0.0, clang, [[0.0, 1.0], [0.9, 0.5], [1.2, 0.0]])
			S._air(b, rng, 0.0, 0.5, 0.8, 500.0, 2200.0, 700.0, 0.1, 0.7)
			for i in range(8):
				var t := 0.1 + rng.randf() * 0.6
				S._sweep(b, t, [[0.0, rng.randf_range(500.0, 900.0)], [0.03, rng.randf_range(900.0, 1500.0)]], 0.15, 0.02, 0.05, [1.0])
			return S._finish(b, -12.0, 0.25)
		"inhale_roar":
			# Inhale (its 0.8 s tell, then the 2.5 s pull): a roar of air
			# rushing into the Maw, rising, then a long hard wind pulling him
			# in, a dark throat humming under it.
			b = S._silence(3.3)
			var lv := [[0.0, 0.0], [0.75, 1.0], [2.8, 0.85], [3.3, 0.0]]
			S._band(b, rng, 0.0, 3.3, 1.0, lv, [[0.0, 700.0], [0.8, 1500.0], [3.3, 900.0]], 1.0)
			S._band(b, rng, 0.0, 3.3, 0.5, lv, [[0.0, 2200.0], [0.8, 3600.0], [3.3, 2400.0]], 1.4)
			var throat := S._silence(3.2)
			S._roar(throat, rng, 0.0, [[0.0, 95.0], [0.8, 125.0], [3.0, 105.0]], 0.5, 3.2, 11.0, S.OO)
			S._layer(b, 0.0, throat, lv)
			return S._finish(b, -13.0, 0.3)
		"choke":
			# The Maw chokes on a bell's sound (the window): a bell struck and
			# swallowed whole, and a great gagging gulp that sticks.
			b = S._silence(1.0)
			var bell := S._silence(0.5)
			S._great_bell(bell, rng, 0.0, S._hz(50), 0.9, 0.6)
			S._shape(bell, [[0.0, 1.0], [0.1, 0.8], [0.3, 0.0]])
			S._layer(b, 0.0, bell)
			S._roar(b, rng, 0.15, [[0.0, 150.0], [0.1, 210.0], [0.25, 120.0], [0.4, 190.0], [0.75, 90.0]], 0.9, 0.8, 26.0, S.AW)
			S._thump(b, 0.15, 280.0, 120.0, 0.6, 0.06, 2.5)
			return S._finish(b, -13.0, 0.15)
		"flame_freed":
			# A stolen flame struck free: it rushes up and home, a bright
			# rising chime run D5 F5 A5 D6 over a warm whoosh.
			b = S._silence(0.95)
			S._air(b, rng, 0.0, 0.5, 0.8, 300.0, 2000.0, 900.0, 0.3, 0.9)
			var up := [74, 77, 81, 86]
			for i in range(up.size()):
				S._chime(b, 0.05 + 0.06 * i, S._hz(up[i]), 0.55, 0.25 + 0.05 * i)
				S._partial(b, 0.05 + 0.06 * i, S._hz(up[i]) * 2.0, 0.15, 0.1, 0.002)
			S._hiss(b, rng, 0.0, 0.3, 0.2, 0.7)
			return S._finish(b, -15.0, 0.2)
		"gaze_lock":
			# The Gaze locks (0.50 s, then the beam of silence): a cold held
			# tone, A5 over D5 hollowed out and trembling, a pale whistle.
			b = S._silence(0.52)
			S._partial(b, 0.0, 2800.0, 0.2, 0.01, 0.0008)
			var tone := S._silence(0.5)
			S._harmonica(tone, 0.0, S._hz(81), 0.6, 0.5, 0.015, 0.04, 6.0)
			S._harmonica(tone, 0.0, S._hz(74), 0.4, 0.5, 0.015, 0.04, 4.0)
			S._tremolo(tone, 0.0, 0.5, 11.0, 0.4)
			S._layer(b, 0.0, tone)
			S._band(b, rng, 0.0, 0.5, 0.2, [[0.0, 0.0], [0.1, 1.0], [0.5, 0.6]], [[0.0, 2400.0]], 8.0)
			return S._finish(b, -15.0, 0.02)
		"deep_quiet":
			# The Deep Quiet coming (its 1.6 s tell, the water rising at
			# TELL_AT): the lake drawn perfectly still, a hollow suck of breath
			# over a note sinking D5 C5 A4, stopped dead at 0.5 s; then
			# Sfx.SILENCES takes every other sound away until the water rises.
			b = S._silence(0.62)
			var suck := S._silence(0.5)
			S._band(suck, rng, 0.0, 0.5, 1.0, [[0.0, 1.0], [0.5, 0.0]], [[0.0, 1800.0], [0.5, 900.0]], 1.3)
			S._air(suck, rng, 0.0, 0.5, 0.6, 1500.0, 900.0, 600.0, 0.1, 0.9)
			S._layer(b, 0.0, S._reversed(suck))
			var tone := S._silence(0.5)
			S._sweep(tone, 0.0, [[0.0, S._hz(74)], [0.18, S._hz(74)], [0.22, S._hz(72)], [0.32, S._hz(72)], [0.36, S._hz(69)],
					[0.5, S._hz(69)]], 0.3, 20.0, 0.5, [1.0, 0.6, 0.4, 0.25, 0.15])
			S._layer(b, 0.0, tone, [[0.0, 0.2], [0.44, 1.0], [0.5, 0.0]])
			S._shape(b, [[0.0, 1.0], [0.48, 1.0], [0.5, 0.0]])
			return S._finish(b, -16.0, 0.01)
		"hush_eye_open":
			# The Eye opens (the Hush's last phase): a colossal bell played
			# backwards, swelling out of nothing into the dark, and the lid
			# sliding open.
			b = S._silence(2.3)
			var bell := S._silence(2.0)
			S._great_bell(bell, rng, 0.0, S._hz(38), 0.8, 0.9)
			S._great_bell(bell, rng, 0.0, S._hz(50), 0.7, 0.6)
			S._bell(bell, 0.0, S._hz(74), 0.4, 0.6)
			S._bell(bell, 0.0, S._hz(81), 0.25, 0.5)
			S._layer(b, 0.0, S._reversed(bell), [[0.0, 0.0], [1.0, 0.6], [2.0, 1.0]])
			S._band(b, rng, 1.5, 0.7, 0.4, [[0.0, 0.0], [0.4, 1.0], [0.7, 0.0]], [[0.0, 1500.0], [0.7, 900.0]], 1.2)
			S._thump(b, 2.0, 260.0, 90.0, 0.8, 0.08, 2.5)
			return S._finish(b, -12.5, 0.1)
		"hush_wince":
			# The Eye hurt: a glassy crack across it and a short low groan.
			b = S._silence(0.72)
			S._air(b, rng, 0.0, 0.02, 1.0, 2600.0, 3600.0, 2400.0, 0.1, 0.9)
			S._glass(b, 0.0, S._hz(86), 0.5, 0.12)
			S._roar(b, rng, 0.03, [[0.0, 130.0], [0.2, 150.0], [0.6, 95.0]], 0.9, 0.65, 19.0, S.OO)
			return S._finish(b, -14.0, 0.1)
		"hush_blink":
			# Blink (the window: the Eye shut and drifting close): a soft, wet
			# close, muffled.
			b = S._silence(0.4)
			S._thud(b, 0.0, 400.0, 200.0, 0.8, 0.04)
			S._air(b, rng, 0.0, 0.16, 0.7, 800.0, 1500.0, 600.0, 0.2, 0.9)
			S._sweep(b, 0.0, [[0.0, 700.0], [0.08, 380.0]], 0.4, 0.05, 0.1, [1.0, 0.4])
			S._muffle(b, 2000.0)
			return S._finish(b, -17.0, 0.08)
		"hush_silence":
			# The Snuff coming (its 1.2 s tell, the hand landing at TELL_AT, a
			# palm's outline over the islet): a breath swelling in for 0.9 s,
			# and at its top all sound cuts out (Sfx.SILENCES) for the 0.3 s
			# before the slam (snuff_slam). It ends in true digital silence.
			b = S._silence(1.2)
			var lv := [[0.0, 0.0], [0.85, 1.0], [0.9, 0.0]]
			S._band(b, rng, 0.0, 0.9, 1.0, lv, [[0.0, 1400.0], [0.9, 2600.0]], 1.6)
			S._band(b, rng, 0.0, 0.9, 0.6, lv, [[0.0, 700.0], [0.9, 1100.0]], 1.4)
			var tone := S._silence(0.9)
			S._sweep(tone, 0.0, [[0.0, S._hz(74)], [0.88, S._hz(81)]], 0.3, 20.0, 0.9, [1.0, 0.3])
			S._layer(b, 0.0, tone, lv)
			return S._finish(b, -15.0, 0.01)
		"hush_scream_silent":
			# The Hush's roar, which isn't a sound so much as the air
			# giving way: a deep swell with no top to it, cut off.
			b = S._silence(1.8)
			var lv := [[0.0, 0.0], [1.3, 1.0], [1.6, 0.0]]
			var swell := S._silence(1.7)
			S._sweep(swell, 0.0, [[0.0, 110.0], [1.3, 174.61], [1.6, 146.83]], 0.5, 20.0, 1.7, [1.0, 0.9, 0.8, 0.6, 0.45, 0.3])
			S._layer(b, 0.0, swell, lv)
			S._band(b, rng, 0.0, 1.7, 0.6, lv, [[0.0, 300.0], [1.3, 520.0]], 2.0)
			S._muffle(b, 900.0)
			return S._finish(b, -14.0, 0.2)
		"finale_ring":
			# A pale ring of light settling as a step of the finale's stair:
			# a cold, clear chime on D3 (played at note(0) to note(5), D3 F3 G3
			# A3 C4 D4), its octaves up high so a phone speaker carries it.
			b = S._silence(1.6)
			var f := S._hz(50)
			S._partial(b, 0.0, f, 0.5, 0.6, 0.003)
			S._partial(b, 0.0, f * 2.0, 0.9, 0.55, 0.002)
			S._partial(b, 0.0, f * 2.0 + 1.3, 0.4, 0.5, 0.002)
			S._partial(b, 0.0, f * 4.0, 0.45, 0.35, 0.0015)
			S._partial(b, 0.0, f * 6.0, 0.15, 0.2, 0.0015)
			S._glass(b, 0.0, f * 8.0, 0.2, 0.25)
			S._space(b, 0.3, 1.2, 0.78)
			return S._finish(b, -14.0, 0.4)
	push_error("sfx_w6: unknown sound '%s'" % sound)
	return PackedFloat32Array()
