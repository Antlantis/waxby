extends RefCounted
## Sfx's story bank (contract.md section 14): the three new blips, the story's
## big moments (pull, give, lull first, as the story needs them first), and
## the secret doors' sounds, which World 1's 1-3 reaches before any new
## world. Rendered in the background after the core, before World 3's bank;
## until then each plays its FALLBACK (sfx.gd). Every recipe is built from
## sfx.gd's primitives and levelled by its _finish, like v2's.

const S := preload("res://scripts/sfx.gd")

const NAMES := [
	# the voices of the new cast: a blip every few letters as a line types
	"talk_wood", "talk_tick", "talk_glass",
	# the_pull, the finale's hold and the Lull, then the rest of the story's
	"pull", "give", "lull", "bell_choke", "anvil", "clock_strike",
	# the secret doors
	"secret_hum", "secret_found", "silver_bell",
]
const TAKES := {}
const JITTER := {}


static func render(sound: String, take: int = 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound) + 7919 * take
	var b: PackedFloat32Array
	match sound:
		# ---- the blips. Each is centred on D, like talk, so a blip played at
		# Sfx.voice_note(voice, i) sings in the speaker's register and in key.
		"talk_wood":
			# Mother Gravebough and Mother Yarrow: a hollow wooden knock on D5
			# (a bone-marimba bar, its overtones soft) with a quick rustle of
			# leaves for a tail, 60 ms.
			b = S._silence(0.06)
			S._bar(b, 0.0, S._hz(74), 1.0, 0.016, 0.55)
			S._thud(b, 0.0, 700.0, 520.0, 0.25, 0.008)
			S._band(b, rng, 0.012, 0.045, 0.22, [[0.0, 0.0], [0.008, 1.0], [0.045, 0.0]], [[0.0, 3800.0], [0.045, 5200.0]], 1.4)
			return S._finish(b, -20.5, 0.012)
		"talk_tick":
			# The Tinker and Master Tickwell: a dry clock tick, the escapement's
			# click and a tiny metal ring on D6, 35 ms. Dry, so a clipped line
			# ticks on its own.
			b = S._silence(0.035)
			S._hiss(b, rng, 0.0, 0.003, 0.35)
			S._partial(b, 0.0, 3300.0, 0.18, 0.0025, 0.0008)
			S._partial(b, 0.0, S._hz(86), 1.0, 0.009, 0.0008)
			S._partial(b, 0.0, S._hz(86) * 2.76, 0.16, 0.004, 0.0008)
			return S._finish(b, -21.0, 0.008)
		"talk_glass":
			# The Prism Saint and Tessel: a soft glass-rim ping on D6, 50 ms,
			# its attack rounded so it never pricks.
			b = S._silence(0.05)
			S._glass(b, 0.0, S._hz(86), 1.0, 0.018, 0.004)
			return S._finish(b, -21.0, 0.014)

		# ---- the story's moments
		"pull":
			# the_pull (the Hush drags the Undercandle's flame down): a deep
			# in-drawn whoosh, air rushing inward and falling in pitch as it
			# goes, a groan sinking under it, and a swallowed thump at the end
			# as the dark closes over it. 1.4 s.
			b = S._silence(1.4)
			S._air(b, rng, 0.0, 1.12, 1.0, 900.0, 2600.0, 420.0, 0.62, 0.8)
			S._band(b, rng, 0.0, 1.1, 0.4, [[0.0, 0.0], [0.6, 0.8], [1.0, 1.0], [1.1, 0.0]],
					[[0.0, 3200.0], [1.1, 900.0]], 1.2)
			var groan := S._silence(1.2)
			S._sweep(groan, 0.0, [[0.0, 330.0], [1.15, 82.0]], 0.5, 30.0, 1.2, [1.0, 0.7, 0.5, 0.35, 0.25, 0.15])
			S._layer(b, 0.0, groan, [[0.0, 0.0], [0.5, 0.6], [1.05, 1.0], [1.18, 0.0]])
			S._thump(b, 1.13, 280.0, 70.0, 1.0, 0.07, 3.0)
			S._thud(b, 1.13, 520.0, 240.0, 0.35, 0.03)
			S._muffle(b, 1600.0, 1.12)
			return S._finish(b, -13.0, 0.12)
		"give":
			# The finale's hold, while Waxby gives his flame: a soft shimmer
			# on D (D6 falling to D5, with a glint of D7) over a breath of air
			# sinking with it, nothing but D in it, so a caller stepping it
			# down with the light at Sfx.in_key(pitch) walks it down the scale
			# in key (D C A G F D). Half a second, made to be played again
			# every 0.5 s while the thumb holds: each ends as the next begins.
			b = S._silence(0.5)
			S._chime(b, 0.012, S._hz(86), 0.55, 0.12)
			S._partial(b, 0.012, S._hz(98), 0.12, 0.04, 0.002)
			S._chime(b, 0.16, S._hz(74), 0.5, 0.16)
			S._partial(b, 0.16, S._hz(86), 0.12, 0.05, 0.002)
			S._band(b, rng, 0.0, 0.5, 0.18, [[0.0, 0.0], [0.08, 1.0], [0.35, 0.5], [0.5, 0.0]], [[0.0, 3600.0], [0.5, 1400.0]], 2.0)
			return S._finish(b, -20.0, 0.06)
		"lull":
			# The Lull: three bell notes, A4, F#4 and D4 in D major, 0.55 s
			# apart, on the great bell's voice (a small bell's clear core with
			# each so the tune carries on a phone), a low D an octave under
			# the last. About 2.2 s; the only tune in the game that isn't
			# minor.
			b = S._silence(2.3)
			var tune := [69, 66, 62]
			for i in range(tune.size()):
				var at := 0.55 * i
				S._great_bell(b, rng, at, S._hz(tune[i] - 12), 0.75, 0.32 if i < 2 else 0.6)
				S._chime(b, at + 0.004, S._hz(tune[i]), 0.35, 0.3 if i < 2 else 0.6)
			S._great_bell(b, rng, 1.1, S._hz(38), 0.45, 0.6)
			return S._finish(b, -13.0, 0.6)
		"bell_choke":
			# In the_pull: a bell struck and a hand closing on it, the ring
			# damped to nothing within 0.3 s, a dull grab of cloth and wax.
			b = S._silence(0.6)
			var bell := S._silence(0.6)
			S._great_bell(bell, rng, 0.0, S._hz(50), 1.0, 0.8)
			S._great_bell(bell, rng, 0.0, S._hz(62), 0.5, 0.5)
			S._shape(bell, [[0.0, 1.0], [0.06, 1.0], [0.14, 0.35], [0.3, 0.0]])
			S._layer(b, 0.0, bell)
			S._thud(b, 0.07, 330.0, 170.0, 0.5, 0.04)
			S._air(b, rng, 0.06, 0.14, 0.35, 600.0, 1300.0, 500.0, 0.2, 0.8)
			return S._finish(b, -14.0, 0.25)
		"anvil":
			# The reforge (Master Tickwell's bench): a small bright hammer tap
			# on a tiny anvil, steel ringing on D6. The story plays it at 1.0,
			# 1.12 and 1.26, so the three taps climb.
			b = S._silence(0.22)
			S._partial(b, 0.0, S._hz(86), 0.9, 0.05, 0.0008)
			S._partial(b, 0.0, S._hz(86) * 2.76, 0.4, 0.03, 0.0008)
			S._partial(b, 0.0, S._hz(86) * 5.4, 0.15, 0.015, 0.0008)
			S._partial(b, 0.0, S._hz(86) * 1.003, 0.3, 0.05, 0.0008)
			S._air(b, rng, 0.0, 0.012, 0.6, 2600.0, 3400.0, 2400.0, 0.1, 0.9)
			S._thud(b, 0.0, 520.0, 300.0, 0.35, 0.012)
			return S._finish(b, -17.0, 0.05)
		"clock_strike":
			# The Carillon's clock strikes (boss 4's scenes): the gears whirr
			# and the hammer lifts, then one deep chime on D, a tubular chime
			# over the bell so its strike cuts through. 2 s (the story also
			# plays it at half speed, deeper and slower).
			b = S._silence(2.0)
			S._ratchet(b, rng, 0.0, 0.32, 0.03, 0.014, 2600.0, 0.3, 0.6)
			S._sweep(b, 0.0, [[0.0, 110.0], [0.3, 150.0]], 0.2, 20.0, 0.34, [1.0, 0.8, 0.6, 0.5, 0.4, 0.3, 0.2], 0.02, 19.0)
			var at := 0.34
			S._great_bell(b, rng, at, S._hz(50), 0.9, 0.7)
			S._bell(b, at, S._hz(74), 0.4, 0.5)
			S._thud(b, at, 360.0, 170.0, 0.4, 0.05)
			return S._finish(b, -13.0, 0.5)

		# ---- the secret doors
		"secret_hum":
			# A secret door's bell-shaped window, heard from up to 320 px away
			# (WLS plays it every 3 s, softer with distance): a faint
			# music-box fragment, A5 C6 D6, over a hummed D, 1.8 s.
			b = S._silence(1.8)
			var frag := [81, 84, 86]
			for i in range(frag.size()):
				S._tine(b, rng, 0.02 + 0.28 * i, S._hz(frag[i]), 0.5, 0.35 if i < 2 else 0.5)
			S._harmonica(b, 0.0, S._hz(74), 0.18, 1.8, 0.5, 0.8, 1.2)
			return S._finish(b, -24.0, 0.3)
		"secret_found":
			# A silver bell rung, a secret level opened: a celesta arpeggio up
			# D minor pentatonic (D5 F5 G5 A5 C6 D6), then a silver bell and
			# its shimmering twin on D6.
			b = S._silence(1.6)
			var run := [74, 77, 79, 81, 84, 86]
			for i in range(run.size()):
				S._tine(b, rng, 0.065 * i, S._hz(run[i]), 0.55, 0.22)
			var at := 0.42
			S._bell(b, at, S._hz(86), 0.8, 0.5)
			S._bell(b, at, S._hz(86) + 3.5, 0.45, 0.5)
			S._bell(b, at + 0.05, S._hz(93), 0.35, 0.35)
			S._air(b, rng, at, 0.5, 0.15, 1500.0, 3400.0, 3000.0, 0.3, 1.2)
			return S._finish(b, -14.0, 0.3)
		"silver_bell":
			# The silver bell that ends a level by its secret way (and a secret
			# level by its Lost Wick's grave candle): higher, brighter and
			# purer than the bronze bell, a D4 bell with a D5 and an A5 bell
			# struck with it, each shimmering.
			b = S._silence(3.0)
			S._great_bell(b, rng, 0.0, S._hz(62), 0.8, 0.8)
			S._bell(b, 0.0, S._hz(86), 0.45, 0.9)
			S._bell(b, 0.0, S._hz(86) + 3.0, 0.3, 0.9)
			S._bell(b, 0.02, S._hz(93), 0.3, 0.6)
			S._glass(b, 0.03, S._hz(98), 0.15, 0.4)
			return S._finish(b, -12.5, 0.8)
	push_error("sfx_story: unknown sound '%s'" % sound)
	return PackedFloat32Array()
