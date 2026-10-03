extends RefCounted
## Sfx's modes bank (contract.md section 14): the Vigil Trials, the Endless
## Descent, the Waxworks, cosmetics and Candlemarks. Rendered last of the
## banks (first when a mode starts: Sfx.prefer_bank(0)); until then each
## plays its FALLBACK. Everything tonal is on D minor pentatonic.
##
## Pitchable on purpose: trial_tick climbs Sfx.note(i) over the last five
## seconds; candle_lit takes note(n) for the nth candle; medal plays at
## note(4) * 0.5 (Bronze, on C), 1.0 (Silver, on D), note(2) (Gold, on G)
## and, for Dawn, note(2) with glimmer over it: it holds only D and A (roots
## and fifths), so each of those is in key; depth_mark at note(depth / 5 % 5).
## Tonal sounds are never jittered.

const S := preload("res://scripts/sfx.gd")

const NAMES := [
	"trial_go", "trial_tick", "candle_lit", "medal", "trial_fail", "descend", "glimmer", "cart_bell",
	"hushing", "wax_cast", "drip_plop", "record", "seal_stamp", "rush_bell", "cosmetic_unlock",
	"candlemark", "depth_mark",
]
const TAKES := {}
const JITTER := {"drip_plop": 0.05, "seal_stamp": 0.03}


static func render(sound: String, take: int = 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound) + 7919 * take
	var b: PackedFloat32Array
	match sound:
		# ---- the Vigil Trials
		"trial_go":
			# A trial's clock starting: three quick rising bell ticks, A4 D5
			# A5, the last one ringing on.
			b = S._silence(0.6)
			var up := [69, 74, 81]
			for i in range(up.size()):
				S._bell(b, 0.09 * i, S._hz(up[i]), 0.7, 0.04 if i < 2 else 0.3)
				S._partial(b, 0.09 * i, 2600.0, 0.15, 0.006, 0.0008)
			return S._finish(b, -16.0, 0.1)
		"trial_tick":
			# The last five seconds of a trial, one a second: a woodblock on D5
			# (the caller climbs it by note(i)).
			b = S._silence(0.12)
			S._bar(b, 0.0, S._hz(74), 1.0, 0.03, 0.7)
			S._hiss(b, rng, 0.0, 0.004, 0.2)
			return S._finish(b, -20.0, 0.02)
		"candle_lit":
			# A trial's candle lit (pitched note(n) for the nth): a soft
			# whoosh of flame and a glass ping on D5.
			b = S._silence(0.6)
			S._air(b, rng, 0.0, 0.3, 0.6, 300.0, 1400.0, 700.0, 0.3, 1.0)
			S._glass(b, 0.06, S._hz(74), 0.7, 0.2)
			S._glass(b, 0.06, S._hz(86), 0.2, 0.12)
			return S._finish(b, -18.0, 0.1)
		"medal":
			# A medal stamped down on the results: a short bell fanfare, D5 A5
			# up to D6 over a warm open fifth (roots and fifths only, so the
			# caller's C, D and G, note(4) * 0.5, 1.0 and note(2), stay in key).
			b = S._silence(1.3)
			S._thud(b, 0.0, 380.0, 180.0, 0.6, 0.04)
			var run := [74, 81, 86]
			for i in range(run.size()):
				S._pluck(b, 0.02 + 0.08 * i, S._hz(run[i]), 0.5, 0.2, 0.9)
				S._bell(b, 0.02 + 0.08 * i, S._hz(run[i]), 0.4, 0.3 if i < 2 else 0.6)
			for m in [62, 69, 74, 81]:
				S._organ(b, 0.18, S._hz(m), 0.18, 0.9, 0.4, 0.02, 0.4)
			return S._finish(b, -13.0, 0.3)
		"trial_fail":
			# A trial lost (snuffed, or the clock ran out): the flame blown out
			# and a harpsichord falling down the scale, A5 G5 F5 D5.
			b = S._silence(1.0)
			S._air(b, rng, 0.0, 0.3, 0.8, 1200.0, 2600.0, 900.0, 0.25, 0.7)
			var down := [81, 79, 77, 74]
			for i in range(down.size()):
				S._pluck(b, 0.2 + 0.13 * i, S._hz(down[i]), 0.6, 0.18 if i < 3 else 0.4, 0.8)
			return S._finish(b, -16.0, 0.2)

		# ---- the Endless Descent
		"descend":
			# Down to the next depth: a long falling whoosh into a deep bell on D.
			b = S._silence(1.6)
			S._air(b, rng, 0.0, 0.9, 1.0, 2200.0, 1200.0, 250.0, 0.2, 1.0)
			S._sweep(b, 0.0, [[0.0, 900.0], [0.9, 220.0]], 0.2, 20.0, 0.9, [1.0, 0.3])
			S._great_bell(b, rng, 0.85, S._hz(38), 0.7, 0.6)
			S._great_bell(b, rng, 0.85, S._hz(50), 0.6, 0.45)
			S._bell(b, 0.85, S._hz(62), 0.35, 0.4)
			return S._finish(b, -14.0, 0.3)
		"glimmer":
			# A Glimmer offered or taken: a bright two-note chime, D6 then A6.
			b = S._silence(0.7)
			S._bell(b, 0.0, S._hz(86), 0.7, 0.3)
			S._bell(b, 0.0, S._hz(86) + 3.0, 0.35, 0.3)
			S._bell(b, 0.09, S._hz(93), 0.8, 0.4)
			S._bell(b, 0.09, S._hz(93) + 3.5, 0.4, 0.4)
			S._air(b, rng, 0.05, 0.3, 0.1, 2000.0, 3400.0, 3000.0, 0.3, 1.2)
			return S._finish(b, -16.0, 0.15)
		"cart_bell":
			# Waxley's cart: a small shop bell struck twice, its clapper
			# jingling.
			b = S._silence(0.7)
			for i in range(2):
				var at := 0.14 * i
				S._partial(b, at, S._hz(93), 0.7, 0.18, 0.001)
				S._partial(b, at, S._hz(93) * 2.4, 0.3, 0.08, 0.0008)
				S._partial(b, at, S._hz(93) * 1.004, 0.4, 0.18, 0.001)
				S._clink(b, rng, at, 3400.0, 0.2)
			return S._finish(b, -18.0, 0.15)
		"hushing":
			# A Hushing settles on the run: a low bell swelling backwards out
			# of the dark over 1.2 s (the hush track's colour), a breath at
			# its top.
			b = S._silence(1.4)
			var bell := S._silence(1.25)
			S._great_bell(bell, rng, 0.0, S._hz(45), 0.8, 0.5)
			S._bell(bell, 0.0, S._hz(57), 0.5, 0.3)
			S._bell(bell, 0.0, S._hz(69), 0.35, 0.3)
			S._layer(b, 0.0, S._reversed(bell), [[0.0, 0.0], [0.6, 0.5], [1.25, 1.0]])
			S._air(b, rng, 1.1, 0.3, 0.3, 1200.0, 800.0, 400.0, 0.1, 0.8)
			return S._finish(b, -15.0, 0.1)
		"depth_mark":
			# Every fifth depth: a short bell on D5 (pitched note(depth / 5 % 5)).
			b = S._silence(0.8)
			S._bell(b, 0.0, S._hz(74), 0.8, 0.35)
			S._bell(b, 0.0, S._hz(74) + 2.5, 0.35, 0.35)
			S._thud(b, 0.0, 380.0, 200.0, 0.25, 0.03)
			return S._finish(b, -17.0, 0.2)
		"record":
			# A new best (depth or time): a triumphant four notes, D5 F5 A5 D6,
			# plucked and belled over an organ chord.
			b = S._silence(1.7)
			var up := [74, 77, 81, 86]
			for i in range(up.size()):
				var at := 0.12 * i
				S._pluck(b, at, S._hz(up[i]), 0.55, 0.25 if i < 3 else 0.6, 0.9)
				S._bell(b, at, S._hz(up[i]), 0.35, 0.3 if i < 3 else 0.7)
			for m in [62, 69, 74, 81]:
				S._organ(b, 0.36, S._hz(m), 0.2, 1.2, 0.5, 0.02, 0.5)
			S._thud(b, 0.36, 300.0, 140.0, 0.5, 0.1)
			return S._finish(b, -13.0, 0.4)

		# ---- the Waxworks
		"wax_cast":
			# A boss entering its cast (the Waxworks): a wet squelch of wax and
			# a dull bell on D4.
			b = S._silence(1.0)
			S._thud(b, 0.0, 380.0, 170.0, 0.9, 0.05)
			S._air(b, rng, 0.0, 0.2, 0.8, 400.0, 1200.0, 500.0, 0.15, 0.7)
			S._sweep(b, 0.02, [[0.0, 700.0], [0.1, 300.0]], 0.4, 0.06, 0.12, [1.0, 0.3])
			var bell := S._silence(0.95)
			S._great_bell(bell, rng, 0.0, S._hz(50), 0.8, 0.45)
			S._muffle(bell, 1800.0)
			S._layer(b, 0.05, bell, [[0.0, 1.0], [0.7, 0.6], [0.95, 0.0]])
			return S._finish(b, -15.0, 0.2)
		"drip_plop":
			# A Tweak toggled: a single drop of wax plopping, 60 ms.
			b = S._silence(0.08)
			var f0 := 900.0
			S._sweep(b, 0.0, [[0.0, f0], [0.02, f0 * 2.0]], 1.0, 0.02, 0.06, [1.0])
			return S._finish(b, -20.0, 0.015)
		"seal_stamp":
			# A seal won: the stamp thudding down and the wax crackling as it
			# sets.
			b = S._silence(0.5)
			S._thump(b, 0.0, 380.0, 200.0, 1.0, 0.04, 3.0)
			S._thud(b, 0.0, 560.0, 300.0, 0.5, 0.02)
			S._air(b, rng, 0.0, 0.04, 0.5, 1000.0, 1800.0, 900.0, 0.2, 0.9)
			S._hiss(b, rng, 0.03, 0.35, 0.45, 0.8)
			S._bar(b, 0.0, S._hz(62), 0.3, 0.04, 0.6)
			return S._finish(b, -15.0, 0.08)
		"rush_bell":
			# Tollgrave's bell announcing each cast in the Waxworks (tolled once
			# per boss beaten): a great bell on D3, dark and long, a smaller
			# one a fifth up struck with it.
			b = S._silence(3.0)
			S._great_bell(b, rng, 0.0, S._hz(50), 1.0, 0.9)
			S._great_bell(b, rng, 0.0, S._hz(57), 0.35, 0.6)
			return S._finish(b, -12.5, 0.8)

		# ---- cosmetics and Candlemarks
		"cosmetic_unlock":
			# A flame or trim unlocked: a warm chime, D6 and A6, and a swish of
			# cloth.
			b = S._silence(0.9)
			S._air(b, rng, 0.0, 0.15, 0.7, 700.0, 1800.0, 1000.0, 0.4, 1.0)
			S._chime(b, 0.08, S._hz(86), 0.7, 0.3)
			S._chime(b, 0.16, S._hz(93), 0.6, 0.4)
			S._bell(b, 0.16, S._hz(98), 0.15, 0.25)
			return S._finish(b, -16.0, 0.2)
		"candlemark":
			# A Candlemark earned past level 40: the level-up's run an octave
			# up and quicker, D6 F6 A6 D7, bells sparkling over it.
			b = S._silence(1.2)
			var run := [86, 89, 93, 98]
			for i in range(run.size()):
				S._pluck(b, 0.045 * i, S._hz(run[i]), 0.45, 0.15, 0.9)
				S._bell(b, 0.045 * i, S._hz(run[i]), 0.3, 0.3 if i < 3 else 0.6)
			var sparkle := [98, 101, 105, 110]
			for i in range(sparkle.size()):
				S._partial(b, 0.25 + 0.05 * i, S._hz(sparkle[i]), 0.15, 0.1, 0.001)
			S._chime(b, 0.18, S._hz(74), 0.3, 0.6)
			return S._finish(b, -14.0, 0.3)
	push_error("sfx_modes: unknown sound '%s'" % sound)
	return PackedFloat32Array()
