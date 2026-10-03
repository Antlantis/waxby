extends RefCounted
## Sfx's World 5 bank, the Shattered Sanctum (contract.md section 14): glass,
## gusts, dawnglass, the void, its monsters and the Prism Saint. The family
## is glass: rim pings, glass-harmonica tones, cracks and showers of shards,
## wind. Until rendered each plays its FALLBACK. Tells last at least 0.35 s
## and sit in 500 Hz-3 kHz (test_sfx).
##
## Pitchable on purpose: glass_crack by strain stage (1, note(1), note(3):
## D6, F6, A6) and glass_chime (the story's stair plays it up the scale).
##
## A tell that builds is cut for its longest tell, its threat landing
## TELL_AT seconds in (Sfx.tell trims its start for a shorter one:
## glass_shing serves the Paneguard's 0.45 s turn and its 0.70 s Glass Cut);
## one that warns with its onset (a lock's tone, the choir) plays whole.
## Tonal sounds are never jittered (a random pitch would put them between
## two notes).

const S := preload("res://scripts/sfx.gd")

const NAMES := [
	# the features
	"gust_tell", "gust", "glass_step", "glass_crack", "glass_shatter", "void_whoosh", "dawnglass_on",
	"dawnglass_off", "prism_lamp", "pennant_flap", "shard_hum",
	# the monsters (and the Glassed Omen)
	"glass_tink", "glass_break", "gust_inhale", "gust_blow", "glass_chime", "prism_hum", "prism_lock",
	"beam_fire", "glass_shing", "glass_clang", "glass_slide", "omen_glass_break",
	# the Prism Saint, the long ones last
	"saint_charge", "beam_lock", "beam_reflect", "saint_rose", "gale", "saint_choir", "saint_crack",
	"saint_split", "saint_refract", "saint_die",
]
const TAKES := {"glass_step": 3}
const JITTER := {"gust": 0.03, "glass_slide": 0.03, "beam_fire": 0.02, "gust_blow": 0.02, "pennant_flap": 0.05,
		"void_whoosh": 0.02}
# When each building tell's threat lands, in seconds from its start (spec
# 3.2 and 4.5, glass.gd's DIFF_KNOBS at Dusk and DAWN_FLICKER, the Saint's
# first-phase tells, 5.4).
const TELL_AT := {"gust_tell": 1.0, "dawnglass_off": 0.35, "glass_tink": 0.60, "gust_inhale": 0.70, "prism_hum": 0.90,
		"glass_shing": 0.70, "saint_charge": 1.1, "saint_rose": 0.60, "gale": 0.9}


static func _shards(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, length: float, n: int, amp: float,
		lo_hz: float = 2000.0, hi_hz: float = 7000.0) -> void:
	## A shower of glass: n shards over `length` seconds, most at the start,
	## each a tiny rim ping (a clink with a glassy tail) between lo_hz and
	## hi_hz, quieter as it goes.
	for i in range(n):
		var t := pow(rng.randf(), 1.5) * length
		var f := rng.randf_range(lo_hz, hi_hz)
		var a := amp * rng.randf_range(0.4, 1.0) * (1.0 - 0.6 * t / length)
		S._clink(b, rng, at + t, f, a)
		S._partial(b, at + t, f * 1.5, a * 0.3, 0.05, 0.0008)


static func render(sound: String, take: int = 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound) + 7919 * take
	var b: PackedFloat32Array
	match sound:
		# ---- the wind
		"gust_tell":
			# A gust coming (its 1.0 s tell on Dusk): a whistle rising through
			# the mids, the wind gathering under it.
			b = S._silence(1.0)
			var lv := [[0.0, 0.0], [0.8, 1.0], [0.97, 0.9], [1.0, 0.0]]
			S._band(b, rng, 0.0, 1.0, 1.0, lv, [[0.0, 700.0], [0.95, 2300.0]], 7.0)
			S._band(b, rng, 0.0, 1.0, 0.5, lv, [[0.0, 500.0], [0.95, 1400.0]], 1.2)
			var whistle := S._silence(1.0)
			S._sweep(whistle, 0.0, [[0.0, 900.0], [0.95, 2200.0]], 0.2, 20.0, 1.0, [1.0], 0.006, 5.0)
			S._layer(b, 0.0, whistle, [[0.0, 0.0], [0.85, 1.0], [1.0, 0.0]])
			return S._finish(b, -17.0, 0.04)
		"gust":
			# The gust itself (1.8 s, easing in and out): a broad rush of wind,
			# rising and sagging, whistling a little in the glass.
			b = S._silence(1.9)
			var lv := [[0.0, 0.0], [0.3, 0.9], [0.6, 0.7], [1.0, 1.0], [1.4, 0.75], [1.9, 0.0]]
			S._band(b, rng, 0.0, 1.9, 1.0, lv, [[0.0, 500.0], [1.0, 900.0], [1.9, 500.0]], 0.8)
			S._band(b, rng, 0.0, 1.9, 0.45, lv, [[0.0, 1800.0], [1.0, 2800.0], [1.9, 1600.0]], 1.2)
			S._band(b, rng, 0.2, 1.4, 0.25, [[0.0, 0.0], [0.7, 1.0], [1.4, 0.0]], [[0.0, 2200.0], [1.4, 1900.0]], 8.0)
			return S._finish(b, -16.0, 0.2)

		# ---- glass
		"glass_step":
			# A step on glass: a tiny rim ping on D7, F7 or G7 and a tick.
			b = S._silence(0.12)
			S._clink(b, rng, 0.0, S._hz([98, 101, 103][take % 3]), 0.25)
			S._glass(b, 0.0, S._hz([98, 101, 103][take % 3]), 0.35, 0.03)
			return S._finish(b, -25.0, 0.03)
		"glass_crack":
			# A pane cracking under him (a strain stage: pitched D6, F6, A6):
			# a sharp click, the crack running with a crackle, and the pane
			# ringing.
			b = S._silence(0.5)
			S._air(b, rng, 0.0, 0.015, 1.0, 2800.0, 3600.0, 2600.0, 0.1, 0.9)
			var t := 0.005
			while t < 0.18:
				S._partial(b, t, rng.randf_range(3000.0, 6000.0), rng.randf_range(0.1, 0.25), 0.003, 0.0008)
				t += rng.randf_range(0.006, 0.02)
			S._glass(b, 0.0, S._hz(86), 0.6, 0.16)
			return S._finish(b, -16.0, 0.08)
		"glass_shatter":
			# A pane gone (a breaking platform, a Paneguard's end): a crash of
			# glass and a shower of shards over half a second, a thud of the
			# frame under it.
			b = S._silence(0.8)
			S._band(b, rng, 0.0, 0.12, 1.0, [[0.0, 1.0], [0.12, 0.0]], [[0.0, 5600.0], [0.12, 2600.0]], 0.8)
			S._thud(b, 0.0, 420.0, 200.0, 0.6, 0.04)
			_shards(b, rng, 0.0, 0.5, 14, 0.45)
			S._glass(b, 0.0, S._hz(89), 0.3, 0.2)
			return S._finish(b, -13.0, 0.15)
		"void_whoosh":
			# Falling into the void: a long falling wind, down from bright to
			# dark, echoing away in the empty nave.
			b = S._silence(1.4)
			var fall := S._silence(1.4)
			S._band(fall, rng, 0.0, 1.0, 1.0, [[0.0, 0.0], [0.08, 1.0], [0.7, 0.6], [1.0, 0.0]], [[0.0, 1400.0], [1.0, 220.0]], 1.5)
			S._sweep(fall, 0.0, [[0.0, 1200.0], [1.0, 300.0]], 0.2, 20.0, 1.0, [1.0, 0.3], 0.01, 4.0)
			S._space(fall, 0.5, 1.3, 0.8)
			S._layer(b, 0.0, fall)
			return S._finish(b, -16.0, 0.3)
		"dawnglass_on":
			# Dawnglass lit solid (a lamp's light reached it): a warm glass
			# harmonica swelling D5 up to A5, and a soft chime as it sets.
			b = S._silence(0.75)
			S._harmonica(b, 0.0, S._hz(74), 0.5, 0.7, 0.12, 0.3)
			S._harmonica(b, 0.15, S._hz(81), 0.5, 0.55, 0.1, 0.3)
			S._glass(b, 0.2, S._hz(86), 0.3, 0.2, 0.004)
			return S._finish(b, -19.0, 0.1)
		"dawnglass_off":
			# Dawnglass about to go back to air: played at the start of its
			# 0.35 s flicker (DAWN_FLICKER, TELL_AT), whoever stands on it
			# falling at the end. Its glass tone wavering as it flickers and
			# stepping down the scale, A5 G5 F5 D5, a thin breath rising under
			# it, and gone.
			b = S._silence(0.4)
			var tone := S._silence(0.36)
			var steps := [[0.0, S._hz(81)], [0.08, S._hz(81)], [0.095, S._hz(79)], [0.165, S._hz(79)], [0.18, S._hz(77)],
					[0.25, S._hz(77)], [0.265, S._hz(74)], [0.36, S._hz(74)]]
			S._sweep(tone, 0.0, steps, 0.5, 20.0, 0.36, [1.0, 0.12, 0.05], 0.004, 5.0)
			S._tremolo(tone, 0.0, 0.34, 14.0, 0.55)
			S._layer(b, 0.0, tone, [[0.0, 0.0], [0.02, 0.8], [0.3, 1.0], [0.35, 0.0]])
			S._air(b, rng, 0.0, 0.36, 0.35, 1400.0, 2400.0, 1800.0, 0.85, 1.0)
			return S._finish(b, -18.0, 0.03)
		"prism_lamp":
			# A prism lamp lit: the wick catching, and the light split into a
			# chord of chimes, D6 A6 D7.
			b = S._silence(1.0)
			for i in range(4):
				S._air(b, rng, i * 0.014, 0.018, 0.5, 2400.0, 3400.0, 2600.0, 0.3, 1.8)
			S._air(b, rng, 0.05, 0.4, 0.8, 250.0, 1300.0, 800.0, 0.35, 0.9)
			var chord := [86, 93, 98]
			for i in range(chord.size()):
				S._glass(b, 0.15 + 0.025 * i, S._hz(chord[i]), 0.45, 0.35)
			return S._finish(b, -17.0, 0.2)
		"pennant_flap":
			# A pennant snapping in the wind: a flutter of cloth.
			b = S._silence(0.4)
			for i in range(8):
				S._air(b, rng, i * 0.045, 0.04, 0.6 * rng.randf_range(0.6, 1.0), 700.0, 1500.0, 900.0, 0.3, 1.1)
			return S._finish(b, -24.0, 0.05)
		"shard_hum":
			# A floating shard humming near him: a faint glass harmonica on A5.
			b = S._silence(1.5)
			S._harmonica(b, 0.0, S._hz(81), 0.5, 1.5, 0.4, 0.6, 1.8)
			return S._finish(b, -26.0, 0.2)

		# ---- the Glassmite
		"glass_tink":
			# A Glassmite gnawing the glass (its 0.6 s tell): taps quickening
			# on the pane and a crack creeping toward his feet.
			b = S._silence(0.62)
			var t := 0.0
			var gap := 0.12
			while t < 0.56:
				S._clink(b, rng, t, S._hz(98) * rng.randf_range(0.98, 1.02), 0.3 + 0.5 * t)
				S._glass(b, t, S._hz(93), 0.15 + 0.2 * t, 0.03)
				t += gap
				gap = maxf(0.04, gap * 0.82)
			var creep := S._silence(0.6)
			S._band(creep, rng, 0.0, 0.6, 1.0, [[0.0, 0.0], [0.55, 1.0], [0.6, 0.0]], [[0.0, 1400.0], [0.6, 2600.0]], 3.0)
			S._layer(b, 0.0, creep, [[0.0, 0.0], [0.6, 0.3]])
			return S._finish(b, -18.0, 0.03)
		"glass_break":
			# The glass along a mite's crack breaking through: a crunchy snap
			# and a few shards dropping.
			b = S._silence(0.5)
			S._band(b, rng, 0.0, 0.08, 1.0, [[0.0, 1.0], [0.08, 0.0]], [[0.0, 4800.0], [0.08, 2400.0]], 0.9)
			S._thud(b, 0.0, 440.0, 240.0, 0.4, 0.025)
			_shards(b, rng, 0.0, 0.3, 7, 0.4)
			return S._finish(b, -15.0, 0.1)

		# ---- the Gustling
		"gust_inhale":
			# A Gustling filling its cheeks (its 0.7 s tell): air rushing in,
			# rising, a whistle climbing, and a little "hup" as it holds.
			b = S._silence(0.72)
			S._air(b, rng, 0.0, 0.66, 1.0, 600.0, 1600.0, 1800.0, 0.92, 1.0)
			var whistle := S._silence(0.66)
			S._sweep(whistle, 0.0, [[0.0, 900.0], [0.64, 1800.0]], 0.25, 20.0, 0.66, [1.0, 0.1], 0.008, 6.0)
			S._layer(b, 0.0, whistle, [[0.0, 0.0], [0.55, 1.0], [0.66, 0.0]])
			S._sweep(b, 0.62, [[0.0, 500.0], [0.05, 700.0]], 0.4, 0.04, 0.08, [1.0, 0.4])
			return S._finish(b, -17.0, 0.03)
		"gust_blow":
			# The Gustling's gust (0.7 s on Dusk): a round-cheeked "whoooo", its
			# bellows wheezing, the wind whistling past its halo.
			b = S._silence(0.85)
			var lv := [[0.0, 0.0], [0.08, 1.0], [0.6, 0.8], [0.85, 0.0]]
			S._band(b, rng, 0.0, 0.85, 1.0, lv, [[0.0, 900.0], [0.85, 600.0]], 1.0)
			S._band(b, rng, 0.0, 0.85, 0.4, lv, [[0.0, 2200.0], [0.85, 1700.0]], 5.0)
			S._roar(b, rng, 0.0, [[0.0, 420.0], [0.7, 380.0]], 0.2, 0.8, 7.0, S.OO)
			return S._finish(b, -16.0, 0.1)
		"glass_chime":
			# A glass bell (a Gustling's halo popping, a step of the story's
			# stair): a clear glass ring on D6, 0.8 s, pitchable.
			b = S._silence(0.8)
			S._glass(b, 0.0, S._hz(86), 1.0, 0.3)
			S._glass(b, 0.0, S._hz(98), 0.2, 0.12)
			return S._finish(b, -17.0, 0.2)

		# ---- the Refractor
		"prism_hum":
			# A Refractor tracking him (0.9 s, the rainbow aim line following):
			# a prism's hum swelling and brightening, its beating quickening.
			b = S._silence(0.92)
			S._harmonica(b, 0.0, S._hz(81), 0.6, 0.9, 0.3, 0.15, 3.0)
			S._harmonica(b, 0.1, S._hz(93), 0.25, 0.8, 0.5, 0.15, 5.0)
			S._band(b, rng, 0.0, 0.9, 0.12, [[0.0, 0.0], [0.85, 1.0], [0.9, 0.0]], [[0.0, 2000.0], [0.9, 3000.0]], 4.0)
			S._shape(b, [[0.0, 0.25], [0.8, 1.0], [0.92, 1.0]])
			return S._finish(b, -18.0, 0.04)
		"prism_lock":
			# The line turns white and stops (0.45 s, then the beam): a sharp
			# tick and a thin piercing tone, trembling fast.
			b = S._silence(0.47)
			S._partial(b, 0.0, 3000.0, 0.3, 0.01, 0.0008)
			var tone := S._silence(0.45)
			S._harmonica(tone, 0.0, S._hz(86), 0.7, 0.45, 0.01, 0.04, 9.0)
			S._harmonica(tone, 0.0, S._hz(98), 0.3, 0.45, 0.01, 0.04, 13.0)
			S._tremolo(tone, 0.0, 0.45, 18.0, 0.5)
			S._layer(b, 0.0, tone)
			return S._finish(b, -16.0, 0.02)
		"beam_fire":
			# A Refractor's beam (0.25 s): a hard bright zap and a crackle.
			b = S._silence(0.35)
			S._band(b, rng, 0.0, 0.28, 1.0, [[0.0, 0.0], [0.005, 1.0], [0.25, 0.6], [0.28, 0.0]], [[0.0, 3200.0], [0.28, 2400.0]], 2.0)
			S._sweep(b, 0.0, [[0.0, 2800.0], [0.25, 1600.0]], 0.4, 0.2, 0.28, [1.0, 0.4, 0.2])
			S._hiss(b, rng, 0.0, 0.25, 0.3, 0.7)
			return S._finish(b, -15.0, 0.05)

		# ---- the Paneguard
		"glass_shing":
			# A Paneguard's Glass Cut coming (its 0.70 s tell, TELL_AT), and its
			# 0.45 s turn edge-on (Sfx.tell starts it 0.25 s in): a glint
			# running along its lead, a rising glassy "shiiing".
			b = S._silence(0.74)
			S._sweep(b, 0.0, [[0.0, 1100.0], [0.68, 2700.0]], 0.4, 20.0, 0.7, [1.0, 0.35, 0.15], 0.004, 8.0)
			S._band(b, rng, 0.0, 0.7, 0.6, [[0.0, 0.0], [0.62, 1.0], [0.7, 0.0]], [[0.0, 2000.0], [0.7, 4800.0]], 2.5)
			S._shape(b, [[0.0, 0.35], [0.4, 0.7], [0.66, 1.0]])
			S._glass(b, 0.62, S._hz(93), 0.3, 0.08)
			return S._finish(b, -16.0, 0.03)
		"glass_clang":
			# A blow on a Paneguard face-on: glass that won't break, a hard
			# clang with a ring of lead and glass.
			b = S._silence(0.4)
			S._air(b, rng, 0.0, 0.015, 0.8, 2600.0, 3400.0, 2200.0, 0.1, 0.9)
			S._bronze(b, 0.0, 780.0, 0.6, 0.1)
			S._glass(b, 0.0, S._hz(86), 0.5, 0.15)
			S._thud(b, 0.0, 400.0, 240.0, 0.4, 0.02)
			return S._finish(b, -16.0, 0.08)
		"glass_slide":
			# The edge lunge: a pane slicing through the air, glass scraping.
			b = S._silence(0.36)
			S._band(b, rng, 0.0, 0.3, 1.0, [[0.0, 0.0], [0.04, 1.0], [0.3, 0.0]], [[0.0, 2000.0], [0.3, 5000.0]], 2.0)
			S._air(b, rng, 0.0, 0.3, 0.6, 800.0, 2400.0, 1400.0, 0.3, 1.6)
			S._partial(b, 0.02, 3500.0, 0.12, 0.08, 0.001)
			return S._finish(b, -16.0, 0.06)
		"omen_glass_break":
			# A Glassed elite's panes breaking: a glassy burst with a sour ring.
			b = S._silence(0.5)
			S._band(b, rng, 0.0, 0.1, 1.0, [[0.0, 1.0], [0.1, 0.0]], [[0.0, 5200.0], [0.1, 2600.0]], 0.9)
			_shards(b, rng, 0.0, 0.35, 9, 0.4)
			S._glass(b, 0.0, S._hz(87), 0.35, 0.18)
			S._thud(b, 0.0, 420.0, 220.0, 0.35, 0.025)
			return S._finish(b, -15.0, 0.1)

		# ---- the Prism Saint
		"saint_charge":
			# The Judgement Beam's aim (its 1.1 s track): a glass-harmonica
			# chord rising D5, A5, D6, swelling, the air brightening.
			b = S._silence(1.12)
			S._harmonica(b, 0.0, S._hz(74), 0.45, 1.1, 0.2, 0.2, 2.0)
			S._harmonica(b, 0.3, S._hz(81), 0.45, 0.8, 0.2, 0.2, 2.5)
			S._harmonica(b, 0.6, S._hz(86), 0.5, 0.5, 0.15, 0.15, 3.5)
			S._band(b, rng, 0.0, 1.1, 0.25, [[0.0, 0.0], [1.0, 1.0], [1.1, 0.0]], [[0.0, 1500.0], [1.1, 3400.0]], 1.2)
			S._shape(b, [[0.0, 0.4], [1.0, 1.0], [1.12, 1.0]])
			return S._finish(b, -15.0, 0.04)
		"beam_lock":
			# The beam locks white (0.50 s): a piercing held A6 over D6,
			# trembling, and a hard tick as it sets.
			b = S._silence(0.52)
			S._partial(b, 0.0, 3200.0, 0.3, 0.012, 0.0008)
			S._bronze(b, 0.0, 1500.0, 0.15, 0.03)
			var tone := S._silence(0.5)
			S._harmonica(tone, 0.0, S._hz(86), 0.6, 0.5, 0.01, 0.04, 7.0)
			S._harmonica(tone, 0.0, S._hz(93), 0.45, 0.5, 0.01, 0.04, 11.0)
			S._tremolo(tone, 0.0, 0.5, 14.0, 0.45)
			S._layer(b, 0.0, tone)
			return S._finish(b, -15.0, 0.02)
		"beam_reflect":
			# The beam turned back on her: a bright upward rush of chimes, D6
			# F6 A6 D7, and a glassy flash.
			b = S._silence(0.65)
			var up := [86, 89, 93, 98]
			for i in range(up.size()):
				S._glass(b, 0.03 * i, S._hz(up[i]), 0.55, 0.2)
			S._band(b, rng, 0.0, 0.2, 0.6, [[0.0, 0.0], [0.01, 1.0], [0.2, 0.0]], [[0.0, 2800.0], [0.2, 6000.0]], 1.0)
			S._thud(b, 0.0, 520.0, 300.0, 0.3, 0.02)
			return S._finish(b, -14.0, 0.12)
		"saint_rose":
			# Rose of Blades (its 0.6 s spin-up): her halo whirling faster and
			# faster, glass ringing on its rim, and the blades let go.
			b = S._silence(0.72)
			var lv := []
			var t := 0.0
			var gap := 0.12
			while t < 0.6:
				lv.append([t, 0.3 + 0.7 * t / 0.6])
				lv.append([t + gap * 0.5, 0.1])
				t += gap
				gap = maxf(0.03, gap * 0.8)
			lv.append([0.6, 1.0])
			lv.append([0.72, 0.0])
			S._band(b, rng, 0.0, 0.72, 1.0, lv, [[0.0, 1100.0], [0.6, 2400.0]], 1.6)
			var ring := [81, 86, 89, 93]
			for i in range(ring.size()):
				S._glass(b, 0.1 + 0.12 * i, S._hz(ring[i]), 0.25, 0.12)
			S._band(b, rng, 0.53, 0.14, 0.6, [[0.0, 0.0], [0.01, 1.0], [0.14, 0.0]], [[0.0, 3000.0], [0.14, 5500.0]], 1.5)
			return S._finish(b, -15.0, 0.04)
		"gale":
			# Gale Hymn: wind gathering on one side with glass chiming in it
			# (the 0.9 s tell), then a great gust over the arena for 2 s.
			b = S._silence(2.95)
			var lv := [[0.0, 0.0], [0.85, 0.7], [1.0, 1.0], [2.4, 0.85], [2.95, 0.0]]
			S._band(b, rng, 0.0, 2.95, 1.0, lv, [[0.0, 600.0], [0.9, 1300.0], [2.95, 700.0]], 0.9)
			S._band(b, rng, 0.0, 2.95, 0.4, lv, [[0.0, 1600.0], [0.9, 2800.0], [2.95, 1800.0]], 4.0)
			var chimes := [81, 86, 89, 93, 86]
			for i in range(chimes.size()):
				S._glass(b, 0.1 + 0.16 * i, S._hz(chimes[i]), 0.3, 0.2)
			return S._finish(b, -14.0, 0.3)
		"saint_choir":
			# Stained Choir (0.8 s): the Saint's held "aaah" on D5, her colours
			# flaring in a glassy shimmer over it.
			b = S._silence(0.9)
			S._choir(b, rng, 0.0, S._hz(74), 0.9, 0.88, 0.12, 0.25)
			S._choir(b, rng, 0.0, S._hz(81), 0.4, 0.88, 0.2, 0.25)
			for i in range(4):
				S._glass(b, 0.1 + 0.15 * i, S._hz([86, 93, 89, 98][i]), 0.12, 0.15)
			return S._finish(b, -15.0, 0.08)
		"saint_crack":
			# A phase broken: three cracks across her glass, a low thud, and
			# her choir cut off mid-note.
			b = S._silence(1.0)
			var voice := S._silence(0.5)
			S._choir(voice, rng, 0.0, S._hz(74), 0.6, 0.5, 0.05, 0.02)
			S._shape(voice, [[0.0, 1.0], [0.3, 1.0], [0.34, 0.0]])
			S._layer(b, 0.0, voice)
			var pitches := [86, 89, 93]
			for i in range(pitches.size()):
				var at := 0.3 + 0.12 * i
				S._air(b, rng, at, 0.015, 1.0, 2800.0, 3600.0, 2600.0, 0.1, 0.9)
				S._glass(b, at, S._hz(pitches[i]), 0.5, 0.2)
			S._thump(b, 0.3, 320.0, 120.0, 0.9, 0.08, 2.5)
			_shards(b, rng, 0.35, 0.5, 8, 0.3)
			return S._finish(b, -13.0, 0.2)
		"saint_split":
			# Scattered Dawn: she bursts into three prism shards, a crack and a
			# whoosh and three chimes at once, D6 F6 A6, flying apart.
			b = S._silence(1.0)
			S._air(b, rng, 0.0, 0.02, 1.0, 2800.0, 3600.0, 2400.0, 0.1, 0.9)
			S._thud(b, 0.0, 440.0, 200.0, 0.6, 0.04)
			S._air(b, rng, 0.0, 0.5, 0.8, 400.0, 2600.0, 700.0, 0.2, 1.0)
			for m in [86, 89, 93]:
				S._glass(b, 0.02, S._hz(m), 0.5, 0.35)
			_shards(b, rng, 0.02, 0.4, 8, 0.3)
			return S._finish(b, -14.0, 0.2)
		"saint_refract":
			# Refracted (her own beam hit her, the window): she cracks and
			# sinks, her glass tone falling and her halo's hum winding down.
			b = S._silence(0.95)
			S._air(b, rng, 0.0, 0.02, 1.0, 2600.0, 3600.0, 2400.0, 0.1, 0.9)
			S._glass(b, 0.0, S._hz(93), 0.5, 0.2)
			var tone := S._silence(0.85)
			S._sweep(tone, 0.0, [[0.0, S._hz(86)], [0.8, S._hz(74)]], 0.4, 20.0, 0.85, [1.0, 0.2, 0.08], 0.01, 5.0)
			S._layer(b, 0.05, tone, [[0.0, 0.0], [0.05, 1.0], [0.85, 0.0]])
			S._sweep(b, 0.05, [[0.0, 520.0], [0.8, 260.0]], 0.25, 20.0, 0.85, [1.0, 0.6, 0.4, 0.2], 0.02, 9.0)
			return S._finish(b, -14.0, 0.15)
		"saint_die":
			# The Prism Saint freed: the window shattering into light, a long
			# fall of glass, and D major swelling out of it on choir and
			# bells (dawn through the rose window).
			b = S._silence(3.3)
			S._band(b, rng, 0.0, 0.2, 1.0, [[0.0, 1.0], [0.2, 0.0]], [[0.0, 5600.0], [0.2, 2400.0]], 0.8)
			S._thump(b, 0.0, 320.0, 110.0, 0.8, 0.1, 2.5)
			_shards(b, rng, 0.0, 1.4, 26, 0.4)
			for m in [62, 66, 69]:
				S._choir(b, rng, 0.5, S._hz(m), 0.35, 2.7, 0.8, 0.9)
			var chord := [74, 78, 81, 86]
			for i in range(chord.size()):
				S._bell(b, 0.7 + 0.08 * i, S._hz(chord[i]), 0.35, 0.7)
				S._glass(b, 0.7 + 0.08 * i, S._hz(chord[i]) * 2.0, 0.12, 0.5)
			return S._finish(b, -12.0, 0.5)
	push_error("sfx_w5: unknown sound '%s'" % sound)
	return PackedFloat32Array()
