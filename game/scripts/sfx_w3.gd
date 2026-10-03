extends RefCounted
## Sfx's World 3 bank, the Bone Orchard (contract.md section 14): its
## features, its monsters and Mother Gravebough. The family is wood and bone:
## bone-marimba bars, creaking wood, leaves, soil and spores. Rendered in the
## background (before World 4's, and first of the worlds when a World 3 level
## asks: Sfx.prefer_bank); until then each plays its FALLBACK. Tells (a sound
## that announces a timed threat) last at least 0.35 s and sit in the phone
## speaker's 500 Hz-3 kHz; test_sfx checks both. A tell that builds is cut
## for its longest tell (Dusk's, a boss's first phase), its threat landing
## TELL_AT seconds in, its climax in the back half before that, and
## Sfx.tell(name, seconds) trims its start to fit a shorter one; a tell that
## warns with its onset (a howl, a growl) has no TELL_AT and plays whole from
## the tell's start. Tonal sounds are on D minor pentatonic and never
## jittered (a random pitch would put them between two notes); takes vary
## them instead.

const S := preload("res://scripts/sfx.gd")

const NAMES := [
	# the features
	"vine_grab", "vine_climb", "vine_creak", "vine_snap", "spore_swell", "spore_puff", "spore_choke",
	"spore_burn", "glowfruit_drop", "skull_lantern", "root_burst", "thorn_snag",
	# the monsters (and the Sporebound Omen)
	"dig_rustle", "root_pop", "dizzy", "weepcap_inhale", "hound_howl", "hound_growl", "hound_bite",
	"hound_pant", "bone_rattle", "bone_skitter", "creep_rattle", "creep_snap", "omen_spores",
	# Mother Gravebough, the long ones last
	"root_creak", "bough_sweep", "bloom_open", "bloom_close", "bloom_decoy_puff", "rootmother_dig",
	"seed_spit", "seed_splat", "rootmother_breath", "thorn_crown", "rootmother_roar", "rootmother_wilt",
	"rootmother_die",
]
const TAKES := {"vine_climb": 3, "bone_skitter": 2, "vine_grab": 2, "bone_rattle": 2}
const JITTER := {"vine_climb": 0.05, "spore_puff": 0.04, "seed_spit": 0.05, "seed_splat": 0.04, "thorn_snag": 0.04}
# When each building tell's threat lands, in seconds from its start (spec 3.2
# and 4.3, the features' DIFF_KNOBS at Dusk; Gravebough's first-phase tells,
# 5.2).
const TELL_AT := {"vine_creak": 0.9, "spore_swell": 0.40, "dig_rustle": 0.50, "weepcap_inhale": 0.70,
		"creep_rattle": 0.50, "root_creak": 0.75, "rootmother_dig": 0.60, "rootmother_breath": 0.80, "thorn_crown": 0.80}
# D minor pentatonic from D5, the notes the bone bars clack on.
const BONES := [74, 77, 79, 81, 84, 86, 89, 91, 93]


static func render(sound: String, take: int = 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound) + 7919 * take
	var b: PackedFloat32Array
	match sound:
		# ---- vines
		"vine_grab":
			# A catch on a vine: hands closing on leaves (three quick rustles
			# up high), the stem giving a soft woody creak, the weight landing
			# in it.
			# Two takes, the stem's creak falling G4 to D4 or F4 to C4.
			b = S._silence(0.22)
			S._rustle(b, rng, 0.0, 0.09, 0.5, 5, 2200.0, 6000.0)
			var creak := S._silence(0.14)
			var fall: Array = [[392.0, 293.66], [349.23, 261.63]][take % 2]
			S._sweep(creak, 0.0, [[0.0, fall[0]], [0.12, fall[1]]], 0.4, 0.05, 0.14, [1.0, 0.6, 0.45, 0.3, 0.2], 0.02, 23.0)
			S._layer(b, 0.02, creak)
			S._thud(b, 0.0, 460.0, 280.0, 0.35, 0.02)
			return S._finish(b, -21.0, 0.04)
		"vine_climb":
			# A hand over hand up (or down) a vine: one grain of leaves and a
			# twig's tick. Three takes, so a climb never loops.
			b = S._silence(0.1)
			S._rustle(b, rng, 0.0, 0.05, 0.5, 3, 1800.0, 5200.0)
			S._clink(b, rng, 0.01 + 0.01 * take, rng.randf_range(2200.0, 2700.0), 0.2)
			return S._finish(b, -27.0, 0.03)
		"vine_creak":
			# A rotten vine fraying, from FRAY (0.5 s into its hold) until it
			# snaps at TELL_AT: 0.9 s on Dusk (rotten_hold 1.4 - FRAY), and
			# Sfx.tell starts it further in for Nightfall's and Witching's
			# shorter holds. The stem creaking tighter and faster, fibres
			# popping one by one, more and more of them.
			b = S._silence(0.9)
			S._creak(b, rng, 0.0, 0.88, [[0.0, 22.0], [0.88, 70.0]], S._hz(74), 0.5, [[0.0, 0.3], [0.7, 1.0], [0.88, 0.8]])
			var t := 0.05
			while t < 0.85:
				S._bar(b, t, rng.randf_range(1700.0, 2600.0), 0.3 + 0.4 * t, 0.004, 0.4)
				t += rng.randf_range(0.04, 0.12) * (1.0 - 0.6 * t)
			S._rustle(b, rng, 0.2, 0.65, 0.25, 8, 2000.0, 4500.0, [[0.0, 0.3], [0.65, 1.0]])
			return S._finish(b, -18.0, 0.05)
		"vine_snap":
			# The rotten vine goes: a woody crack, the fibres tearing, the stem
			# whipping away, and its leaves falling after.
			b = S._silence(0.55)
			S._air(b, rng, 0.0, 0.025, 1.0, 2600.0, 3600.0, 2000.0, 0.1, 0.8)
			S._bar(b, 0.0, 720.0, 0.8, 0.03, 1.2)
			S._thud(b, 0.0, 420.0, 220.0, 0.5, 0.03)
			S._band(b, rng, 0.005, 0.09, 0.6, [[0.0, 1.0], [0.09, 0.0]], [[0.0, 5200.0], [0.09, 2600.0]], 1.2)
			S._air(b, rng, 0.02, 0.18, 0.4, 1200.0, 2400.0, 700.0, 0.2, 1.4)
			S._rustle(b, rng, 0.1, 0.4, 0.3, 9, 1800.0, 5000.0, [[0.0, 1.0], [0.4, 0.2]])
			return S._finish(b, -15.0, 0.08)

		# ---- spores
		"spore_swell":
			# A spore pod about to burst (its pod_tell: 0.40 s on Dusk, 0.34
			# and 0.30 harder; the burst, spore_puff, at TELL_AT): an inflating
			# "fff" rising up the mids, the skin stretching (a rubbery squeak
			# climbing) and a bubble at its top, just before it goes.
			b = S._silence(0.42)
			S._air(b, rng, 0.0, 0.4, 1.0, 500.0, 1800.0, 1600.0, 0.88, 1.1)
			var skin := S._silence(0.37)
			S._sweep(skin, 0.0, [[0.0, 380.0], [0.35, 760.0]], 0.35, 20.0, 0.37, [1.0, 0.5, 0.3, 0.15], 0.015, 11.0)
			S._layer(b, 0.0, skin, [[0.0, 0.0], [0.28, 0.8], [0.37, 0.0]])
			S._sweep(b, 0.29, [[0.0, 420.0], [0.06, 900.0]], 0.6, 0.04, 0.08, [1.0, 0.3])
			return S._finish(b, -17.0, 0.02)
		"spore_puff":
			# A pod (or a Weepcap) bursts: a soft wide puff of spores and a few
			# tiny pops in it.
			b = S._silence(0.4)
			S._band(b, rng, 0.0, 0.3, 1.0, [[0.0, 0.0], [0.01, 1.0], [0.3, 0.0]], [[0.0, 1500.0], [0.3, 380.0]], 0.9)
			S._thud(b, 0.0, 380.0, 200.0, 0.4, 0.03)
			for i in range(3):
				S._pluck(b, 0.04 + 0.05 * i + rng.randf() * 0.02, S._hz(BONES[5 + i]), 0.15, 0.02, 0.6)
			return S._finish(b, -16.0, 0.08)
		"spore_choke":
			# Waxby's flame in a spore cloud: it sputters, three breathy puffs
			# and a fizz, as the light shrinks.
			b = S._silence(0.45)
			for i in range(3):
				S._air(b, rng, 0.09 * i, 0.07, 0.8 - 0.15 * i, 700.0, 1600.0, 800.0, 0.25, 1.0)
			S._hiss(b, rng, 0.05, 0.12, 0.35, 0.7)
			S._sweep(b, 0.0, [[0.0, 523.25], [0.12, 523.25], [0.3, 349.23]], 0.2, 0.1, 0.32, [1.0, 0.5, 0.2])
			return S._finish(b, -20.0, 0.06)
		"spore_burn":
			# Fire reaches a cloud (it burns in 0.3 s): a whoomph as the spores
			# catch, flame roaring through them and crackling out.
			b = S._silence(0.8)
			S._thud(b, 0.0, 360.0, 140.0, 0.6, 0.06)
			S._air(b, rng, 0.0, 0.42, 1.0, 260.0, 1900.0, 500.0, 0.2, 0.8)
			S._band(b, rng, 0.02, 0.35, 0.4, [[0.0, 0.0], [0.05, 1.0], [0.35, 0.0]], [[0.0, 2400.0], [0.35, 5200.0]], 1.0)
			for i in range(18):
				var t := 0.03 + pow(rng.randf(), 1.3) * 0.6
				S._hiss(b, rng, t, rng.randf_range(0.004, 0.012), rng.randf_range(0.2, 0.5) * (1.0 - t * 1.2))
			return S._finish(b, -14.0, 0.2)
		"glowfruit_drop":
			# A glowfruit lets go of its stem (struck, or it falls): a stem's
			# pop, a soft fleshy knock and its glow ringing A5, then D6.
			b = S._silence(0.55)
			S._sweep(b, 0.0, [[0.0, 1300.0], [0.03, 560.0]], 0.5, 0.02, 0.05, [1.0, 0.3])
			S._thud(b, 0.04, 420.0, 250.0, 0.35, 0.025)
			S._chime(b, 0.05, S._hz(81), 0.5, 0.22)
			S._chime(b, 0.12, S._hz(86), 0.6, 0.3)
			S._air(b, rng, 0.04, 0.3, 0.12, 900.0, 2400.0, 1600.0, 0.3, 1.0)
			return S._finish(b, -19.0, 0.12)
		"skull_lantern":
			# A skull lantern lit: a hollow bony "tok" on A4, then the wick
			# catching (a scratch, a soft whoomp) and the skull's glow ringing
			# a warm A5 and D6.
			b = S._silence(1.0)
			S._bar(b, 0.0, S._hz(69), 0.8, 0.04, 0.9)
			S._thud(b, 0.0, 440.0, 260.0, 0.4, 0.02)
			for i in range(4):
				S._air(b, rng, 0.06 + i * 0.014, 0.018, 0.5, 2400.0, 3400.0, 2600.0, 0.3, 1.8)
			S._air(b, rng, 0.1, 0.42, 0.8, 250.0, 1300.0, 800.0, 0.35, 0.9)
			S._bell(b, 0.18, S._hz(81), 0.4, 0.3)
			S._bell(b, 0.26, S._hz(86), 0.45, 0.38)
			return S._finish(b, -17.0, 0.2)
		"root_burst":
			# Roots bursting up through the floor (the Root Spear, a root
			# trap): the earth heaving, wood cracking, bones rattling loose and
			# clods raining.
			b = S._silence(0.8)
			S._thump(b, 0.0, 300.0, 90.0, 1.0, 0.09, 3.0)
			S._thud(b, 0.0, 480.0, 200.0, 0.8, 0.05)
			S._air(b, rng, 0.0, 0.03, 1.0, 2400.0, 4200.0, 2000.0, 0.1, 0.8)
			S._bar(b, 0.0, 640.0, 0.6, 0.03, 1.1)
			for i in range(6):
				S._bar(b, 0.04 + 0.035 * i + rng.randf() * 0.015, S._hz(BONES[rng.randi_range(2, 8)]), 0.35 - 0.04 * i, 0.02, 1.2)
			for i in range(12):
				var t := 0.05 + pow(rng.randf(), 1.4) * 0.55
				S._air(b, rng, t, rng.randf_range(0.01, 0.03), rng.randf_range(0.2, 0.5) * (1.0 - t),
						800.0, rng.randf_range(1100.0, 2600.0), 800.0, 0.3, 1.5)
			return S._finish(b, -13.0, 0.2)
		"thorn_snag":
			# Thorns catch him: a scratchy tear, fast and rough.
			b = S._silence(0.25)
			var lv := []
			for i in range(9):
				lv.append([i * 0.011, 1.0 if i % 2 == 0 else 0.25])
			lv.append([0.1, 0.0])
			S._band(b, rng, 0.0, 0.1, 1.0, lv, [[0.0, 3000.0], [0.1, 6400.0]], 1.3)
			S._air(b, rng, 0.0, 0.1, 0.4, 1600.0, 2600.0, 1400.0, 0.2, 1.2)
			S._partial(b, 0.0, 2900.0, 0.12, 0.03, 0.0008)
			return S._finish(b, -19.0, 0.06)

		# ---- the Rootling
		"dig_rustle":
			# A Rootling's mound churning: the 0.5 s swell before it pops (at
			# full level, its tell), and, played quietly every second or so
			# (a gain of 0.3), the mound following him. Soil and roots
			# rustling, more and faster, clods ticking up, a hollow earthen
			# knock.
			b = S._silence(0.5)
			S._rustle(b, rng, 0.0, 0.48, 0.7, 26, 700.0, 2400.0, [[0.0, 0.12], [0.48, 1.0]])
			S._air(b, rng, 0.0, 0.48, 0.3, 500.0, 1200.0, 900.0, 0.9, 0.8)
			for i in range(6):
				S._bar(b, 0.06 + 0.07 * i, rng.randf_range(900.0, 1500.0), 0.08 + 0.08 * i, 0.008, 0.6)
			S._thud(b, 0.42, 420.0, 260.0, 0.3, 0.02)
			return S._finish(b, -19.0, 0.05)
		"root_pop":
			# A Rootling pops up: a cork-like pop out of the soil, a spray of
			# dirt and its turnip body's woody knock on D5.
			b = S._silence(0.35)
			S._sweep(b, 0.0, [[0.0, 1500.0], [0.035, 480.0]], 0.9, 0.025, 0.06, [1.0, 0.35])
			S._air(b, rng, 0.0, 0.18, 0.8, 800.0, 2200.0, 900.0, 0.15, 0.8)
			S._bar(b, 0.02, S._hz(74), 0.5, 0.05, 0.9)
			S._thud(b, 0.0, 440.0, 220.0, 0.5, 0.03)
			return S._finish(b, -16.0, 0.08)
		"dizzy":
			# Dazed (a Rootling knocked silly, a stunned hound): a wobbly
			# cartoon whistle going round and three little stars twinkling on
			# the scale.
			b = S._silence(0.8)
			S._sweep(b, 0.0, [[0.0, 1400.0], [0.75, 1150.0]], 0.3, 3.0, 0.78, [1.0, 0.15], 0.07, 5.5)
			var stars := [93, 89, 96]
			for i in range(stars.size()):
				S._chime(b, 0.08 + 0.2 * i, S._hz(stars[i]), 0.35, 0.12)
			return S._finish(b, -21.0, 0.1)

		# ---- the Weepcap
		"weepcap_inhale":
			# A Weepcap drawing breath (its 0.7 s tell): a long sad "hhhh"
			# pulled in, rising, the cap's rubbery skin creaking as it swells.
			b = S._silence(0.72)
			S._air(b, rng, 0.0, 0.7, 1.0, 600.0, 1500.0, 1700.0, 0.9, 0.9)
			S._band(b, rng, 0.0, 0.7, 0.5, [[0.0, 0.05], [0.62, 1.0], [0.7, 0.0]], [[0.0, 1800.0], [0.7, 2600.0]], 1.4)
			var skin := S._silence(0.66)
			S._sweep(skin, 0.0, [[0.0, 300.0], [0.64, 520.0]], 0.35, 20.0, 0.66, [1.0, 0.55, 0.35, 0.2], 0.02, 9.0)
			S._layer(b, 0.02, skin, [[0.0, 0.0], [0.5, 0.7], [0.66, 0.0]])
			return S._finish(b, -17.0, 0.03)

		# ---- the Rattlehound
		"hound_howl":
			# A Rattlehound sees him (a 0.55 s howl before the chase): a thin,
			# hollow, bony howl rising to D5 and sagging to C5 and G4, its bones
			# rattling.
			b = S._silence(0.62)
			S._roar(b, rng, 0.0, [[0.0, 293.66], [0.16, 587.33], [0.32, 587.33], [0.36, 523.25], [0.46, 523.25],
					[0.6, 392.0]], 0.9, 0.6, 12.0, S.OO)
			for i in range(5):
				S._bar(b, 0.08 + 0.09 * i + rng.randf() * 0.02, S._hz(BONES[rng.randi_range(3, 8)]), 0.2, 0.012, 1.1)
			return S._finish(b, -15.0, 0.08)
		"hound_growl":
			# A Rattlehound crouching to pounce (its 0.45 s tell): a low bony
			# growl that rattles, its teeth chattering.
			b = S._silence(0.47)
			S._roar(b, rng, 0.0, [[0.0, 150.0], [0.2, 172.0], [0.45, 160.0]], 1.0, 0.46, 42.0)
			var t := 0.02
			while t < 0.42:
				S._bar(b, t, rng.randf_range(1400.0, 2000.0), 0.18, 0.005, 0.5)
				t += rng.randf_range(0.035, 0.06)
			return S._finish(b, -16.0, 0.04)
		"hound_bite":
			# The pounce lands on him: the lunge's rush of air and the bony jaws
			# snapping shut, clack-clack.
			b = S._silence(0.36)
			S._air(b, rng, 0.0, 0.14, 0.6, 400.0, 1600.0, 600.0, 0.5, 1.0)
			S._bar(b, 0.08, S._hz(84), 0.9, 0.025, 1.1)
			S._bar(b, 0.11, S._hz(89), 0.7, 0.02, 1.1)
			S._thud(b, 0.08, 420.0, 200.0, 0.7, 0.035)
			S._air(b, rng, 0.08, 0.03, 0.7, 2000.0, 3000.0, 1600.0, 0.1, 0.8)
			return S._finish(b, -15.0, 0.06)
		"hound_pant":
			# Tired after three pounces (1.5 s, and it's open): quick panting
			# breaths in and out, its ribs jiggling.
			b = S._silence(1.2)
			for i in range(8):
				var at := 0.02 + 0.145 * i
				var inn := i % 2 == 0
				S._air(b, rng, at, 0.09, 0.8 if inn else 0.55, 900.0 if inn else 1500.0, 1900.0 if inn else 1200.0,
						1300.0 if inn else 800.0, 0.35, 1.0)
				S._bar(b, at + 0.02, S._hz(BONES[rng.randi_range(4, 8)]), 0.1, 0.008, 1.0)
			return S._finish(b, -22.0, 0.1)
		"bone_rattle":
			# Bones rattling (a prowling hound, a skeleton shaking): quick dry
			# clacks jumping about the scale, never settling. Two takes.
			b = S._silence(0.4)
			var t := 0.0
			for i in range(10):
				S._bar(b, t, S._hz(BONES[rng.randi_range(1, 8)]), rng.randf_range(0.4, 0.9), rng.randf_range(0.01, 0.02), 1.2)
				t += rng.randf_range(0.022, 0.045)
			return S._finish(b, -20.0, 0.06)

		# ---- the Creepbone
		"bone_skitter":
			# A Creepbone crawling its lane: many tiny bony feet tapping, light
			# and dry, on C7 D7 F7 G7. Two takes.
			b = S._silence(0.3)
			var feet := [96, 98, 101, 103]
			var t := 0.01
			while t < 0.27:
				S._bar(b, t, S._hz(feet[rng.randi_range(0, 3)]), rng.randf_range(0.25, 0.6), 0.004, 0.6)
				t += rng.randf_range(0.018, 0.034)
			S._rustle(b, rng, 0.0, 0.28, 0.12, 5, 3000.0, 6000.0)
			return S._finish(b, -24.0, 0.04)
		"creep_rattle":
			# A Creepbone coiling to lunge (its 0.5 s tell): its knuckle-bones
			# rattling faster and louder as it curls into an S, a hiss of
			# breath through its grin.
			b = S._silence(0.52)
			var t := 0.0
			var gap := 0.07
			while t < 0.48:
				S._bar(b, t, S._hz(BONES[rng.randi_range(2, 8)]), 0.25 + 0.9 * t, rng.randf_range(0.008, 0.016), 1.2)
				t += gap * rng.randf_range(0.8, 1.2)
				gap = maxf(0.018, gap * 0.86)
			S._band(b, rng, 0.1, 0.4, 0.25, [[0.0, 0.0], [0.35, 1.0], [0.4, 0.0]], [[0.0, 1800.0], [0.4, 2800.0]], 1.4)
			return S._finish(b, -17.0, 0.04)
		"creep_snap":
			# The lunge: a whip of air along the lane and its jaws snapping.
			b = S._silence(0.35)
			S._air(b, rng, 0.0, 0.16, 0.8, 800.0, 2600.0, 1000.0, 0.4, 1.4)
			S._bar(b, 0.1, S._hz(86), 0.9, 0.02, 1.2)
			S._bar(b, 0.12, S._hz(91), 0.6, 0.015, 1.2)
			S._thud(b, 0.1, 460.0, 260.0, 0.4, 0.02)
			return S._finish(b, -16.0, 0.06)
		"omen_spores":
			# A Sporebound elite's burst of spores: a breath drawn in, then a
			# sour puff, the pops in it off the scale on purpose.
			b = S._silence(0.55)
			var draw := S._silence(0.2)
			S._air(draw, rng, 0.0, 0.2, 0.7, 1800.0, 1000.0, 800.0, 0.2, 1.0)
			S._layer(b, 0.0, S._reversed(draw))
			S._band(b, rng, 0.18, 0.3, 1.0, [[0.0, 0.0], [0.01, 1.0], [0.3, 0.0]], [[0.0, 1600.0], [0.3, 420.0]], 0.9)
			for i in range(4):
				S._pluck(b, 0.2 + 0.045 * i, 1245.0 + 110.0 * i, 0.12, 0.02, 0.6)
			return S._finish(b, -16.0, 0.08)

		# ---- Mother Gravebough
		"root_creak":
			# Her bough rearing back for a sweep (its 0.75 s tell): great old
			# wood creaking under strain, slow at first and tightening, a deep
			# groan in the trunk under it.
			b = S._silence(0.78)
			S._creak(b, rng, 0.0, 0.76, [[0.0, 18.0], [0.76, 55.0]], 560.0, 0.8, [[0.0, 0.4], [0.65, 1.0], [0.76, 0.9]])
			S._creak(b, rng, 0.0, 0.76, [[0.0, 30.0], [0.76, 80.0]], 1150.0, 0.3, [[0.0, 0.2], [0.7, 1.0], [0.76, 0.8]])
			var groan := S._silence(0.74)
			S._sweep(groan, 0.0, [[0.0, 160.0], [0.72, 215.0]], 0.25, 20.0, 0.74, [0.5, 0.8, 0.8, 0.7, 0.6, 0.5, 0.4], 0.03, 13.0)
			S._layer(b, 0.0, groan, [[0.0, 0.2], [0.6, 1.0], [0.74, 0.0]])
			return S._finish(b, -15.0, 0.04)
		"bough_sweep":
			# The bough sweeping the arena: a huge rush of air, leaves and
			# skull-fruit rattling along its length.
			b = S._silence(0.95)
			S._air(b, rng, 0.0, 0.92, 1.0, 220.0, 950.0, 300.0, 0.35, 0.8)
			S._band(b, rng, 0.05, 0.8, 0.35, [[0.0, 0.0], [0.3, 1.0], [0.8, 0.0]], [[0.0, 1600.0], [0.3, 2800.0], [0.8, 1200.0]], 1.0)
			S._rustle(b, rng, 0.05, 0.8, 0.45, 22, 1500.0, 5000.0, [[0.0, 0.3], [0.3, 1.0], [0.8, 0.2]])
			for i in range(5):
				S._bar(b, 0.2 + 0.1 * i + rng.randf() * 0.04, S._hz(BONES[rng.randi_range(0, 6)]), 0.2, 0.02, 1.0)
			return S._finish(b, -13.0, 0.15)
		"bloom_open":
			# The heart blooms at a socket (the window: strike it now): petals
			# unfurling, soft plucks climbing D5 F5 A5 D6 into a warm chime,
			# the heartwood creaking open.
			b = S._silence(0.95)
			S._creak(b, rng, 0.0, 0.3, [[0.0, 40.0], [0.3, 25.0]], 520.0, 0.25)
			S._rustle(b, rng, 0.0, 0.35, 0.3, 10, 2000.0, 5000.0)
			var up := [74, 77, 81, 86]
			for i in range(up.size()):
				S._pluck(b, 0.05 + 0.06 * i, S._hz(up[i]), 0.5, 0.2, 0.8)
			S._chime(b, 0.25, S._hz(86), 0.6, 0.4)
			S._chime(b, 0.25, S._hz(93), 0.25, 0.3)
			return S._finish(b, -15.0, 0.2)
		"bloom_close":
			# The blossom closing (the window's over): a soft woody "thup" and
			# a muted fall, A5 to D5.
			b = S._silence(0.4)
			S._thud(b, 0.0, 380.0, 220.0, 0.6, 0.03)
			S._rustle(b, rng, 0.0, 0.1, 0.3, 4, 1800.0, 4000.0)
			S._pluck(b, 0.02, S._hz(81), 0.5, 0.08, 0.5)
			S._pluck(b, 0.1, S._hz(74), 0.5, 0.12, 0.5)
			return S._finish(b, -18.0, 0.08)
		"bloom_decoy_puff":
			# The decoy struck: it bursts into spores, a sour puff with a
			# tritone twanging in it, never the true bloom's warm notes.
			b = S._silence(0.55)
			S._band(b, rng, 0.0, 0.34, 1.0, [[0.0, 0.0], [0.012, 1.0], [0.34, 0.0]], [[0.0, 1700.0], [0.34, 400.0]], 0.9)
			S._thud(b, 0.0, 400.0, 180.0, 0.5, 0.035)
			S._pluck(b, 0.01, S._hz(80), 0.4, 0.15, 0.7)
			S._pluck(b, 0.01, S._hz(74), 0.3, 0.15, 0.7)
			S._sweep(b, 0.02, [[0.0, S._hz(80)], [0.3, S._hz(78)]], 0.2, 0.12, 0.3, [1.0, 0.3])
			return S._finish(b, -15.0, 0.1)
		"rootmother_dig":
			# A Root Spear coming (its 0.6 s tell under him): the ground
			# rumbling up from below, louder and louder, soil trickling and
			# pebbles ticking as it bulges.
			b = S._silence(0.62)
			var lv := [[0.0, 0.15], [0.55, 1.0], [0.62, 0.8]]
			S._band(b, rng, 0.0, 0.62, 1.0, lv, [[0.0, 180.0], [0.6, 520.0]], 2.5)
			S._band(b, rng, 0.0, 0.62, 0.8, lv, [[0.0, 700.0], [0.6, 1400.0]], 1.5)
			var t := 0.0
			while t < 0.58:
				S._thump(b, t, 240.0, 110.0, 0.12 + 0.35 * t, 0.03, 2.5)
				t += 0.09 - 0.05 * t
			S._hiss(b, rng, 0.1, 0.5, 0.2, 0.8)
			S._rustle(b, rng, 0.1, 0.5, 0.45, 18, 900.0, 2400.0, [[0.0, 0.2], [0.5, 1.0]])
			return S._finish(b, -15.0, 0.04)
		"seed_spit":
			# A skull-seed spat out of her crown: "ptoo".
			b = S._silence(0.24)
			S._sweep(b, 0.0, [[0.0, 640.0], [0.07, 300.0]], 0.8, 0.05, 0.1, [1.0, 0.5, 0.2])
			S._air(b, rng, 0.0, 0.06, 0.6, 1400.0, 2400.0, 1200.0, 0.2, 1.0)
			S._bar(b, 0.0, S._hz(79), 0.2, 0.03, 1.0)
			return S._finish(b, -18.0, 0.05)
		"seed_splat":
			# A skull-seed lands: a wet splat and the little skull's crack.
			b = S._silence(0.4)
			S._thud(b, 0.0, 400.0, 180.0, 1.0, 0.04)
			S._air(b, rng, 0.0, 0.12, 0.8, 500.0, 1300.0, 500.0, 0.15, 0.7)
			S._sweep(b, 0.01, [[0.0, 760.0], [0.06, 340.0]], 0.4, 0.04, 0.08, [1.0, 0.3])
			S._bar(b, 0.0, 1180.0, 0.4, 0.015, 1.1)
			return S._finish(b, -16.0, 0.06)
		"rootmother_breath":
			# Spore Breath (its 0.8 s tell): her face swells on a vast in-drawn
			# breath, the hood's gills fizzing, a wooden moan inside it.
			b = S._silence(0.82)
			S._air(b, rng, 0.0, 0.8, 1.0, 500.0, 1500.0, 1700.0, 0.92, 0.8)
			S._band(b, rng, 0.0, 0.8, 0.4, [[0.0, 0.05], [0.72, 1.0], [0.8, 0.0]], [[0.0, 2400.0], [0.8, 3400.0]], 1.4)
			var moan := S._silence(0.78)
			S._roar(moan, rng, 0.0, [[0.0, 120.0], [0.78, 150.0]], 0.5, 0.78, 9.0, S.OO)
			S._layer(b, 0.02, moan, [[0.0, 0.0], [0.6, 1.0], [0.78, 0.0]])
			S._hiss(b, rng, 0.3, 0.45, 0.12, 0.7)
			return S._finish(b, -15.0, 0.03)
		"thorn_crown":
			# Thorn Crown: her crown creaks open (0.8 s, the lanes glowing),
			# thorns bristling with a rising shiver, then raining from the roof
			# in a patter of little strikes for 1.2 s.
			b = S._silence(2.1)
			S._creak(b, rng, 0.0, 0.8, [[0.0, 25.0], [0.8, 60.0]], 780.0, 0.5, [[0.0, 0.3], [0.8, 1.0]])
			var shiver := S._silence(0.8)
			S._sweep(shiver, 0.0, [[0.0, 900.0], [0.78, 2200.0]], 0.3, 20.0, 0.8, [1.0, 0.3], 0.03, 17.0)
			S._layer(b, 0.0, shiver, [[0.0, 0.0], [0.7, 1.0], [0.8, 0.0]])
			for i in range(34):
				var t := 0.82 + rng.randf() * 1.15
				S._clink(b, rng, t, rng.randf_range(1800.0, 3200.0), rng.randf_range(0.15, 0.35))
				if i % 3 == 0:
					S._air(b, rng, t - 0.04, 0.05, 0.2, 1500.0, 3000.0, 2000.0, 0.8, 1.4)
			return S._finish(b, -14.0, 0.2)
		"rootmother_roar":
			# Her roar at each phase: a sad, deep, creaking groan, "oo", the old
			# wood of her splitting under it and a low hummed A beneath.
			b = S._silence(1.55)
			# Two throats a hair apart, so their peaks don't line up: the groan
			# keeps its weight without spiking.
			S._roar(b, rng, 0.0, [[0.0, 110.0], [0.3, 140.0], [1.0, 128.0], [1.45, 88.0]], 0.6, 1.45, 17.0, S.OO)
			S._roar(b, rng, 0.012, [[0.0, 111.3], [0.3, 141.6], [1.0, 129.5], [1.45, 89.0]], 0.55, 1.43, 14.0, S.OO)
			S._creak(b, rng, 0.05, 1.3, [[0.0, 20.0], [0.6, 45.0], [1.3, 18.0]], 360.0, 0.22, [[0.0, 0.5], [0.5, 1.0], [1.3, 0.3]])
			S._choir(b, rng, 0.1, S._hz(57), 0.3, 1.35, 0.3, 0.6, S.OO)
			S._air(b, rng, 0.0, 1.3, 0.25, 400.0, 900.0, 300.0, 0.3, 0.7)
			return S._finish(b, -12.5, 0.35)
		"rootmother_wilt":
			# A phase broken (she wilts): a cascade of leaves and petals
			# rustling down, bone-fruit plucks falling down the scale.
			b = S._silence(1.3)
			S._band(b, rng, 0.0, 1.25, 0.6, [[0.0, 0.0], [0.08, 1.0], [1.25, 0.0]], [[0.0, 4200.0], [1.25, 1000.0]], 1.2)
			S._rustle(b, rng, 0.0, 1.2, 0.4, 30, 1200.0, 5000.0, [[0.0, 1.0], [1.2, 0.2]])
			var down := [93, 89, 86, 84, 81, 79, 77, 74]
			for i in range(down.size()):
				S._pluck(b, 0.05 + 0.12 * i, S._hz(down[i]), 0.35, 0.18, 0.7)
			S._thud(b, 0.0, 360.0, 170.0, 0.5, 0.05)
			return S._finish(b, -14.0, 0.25)
		"rootmother_die":
			# She's freed: a long creaking collapse as she settles, a shower of
			# blossom chimes falling, and a last sigh over a low D.
			b = S._silence(3.0)
			S._creak(b, rng, 0.0, 1.4, [[0.0, 40.0], [1.4, 12.0]], 330.0, 0.6, [[0.0, 1.0], [1.4, 0.2]])
			var groan := S._silence(1.4)
			S._sweep(groan, 0.0, [[0.0, 220.0], [1.35, 95.0]], 0.5, 20.0, 1.4, [1.0, 0.7, 0.5, 0.35, 0.25, 0.15])
			S._layer(b, 0.0, groan, [[0.0, 0.3], [0.3, 1.0], [1.4, 0.0]])
			S._thump(b, 1.2, 260.0, 90.0, 0.8, 0.12, 2.5)
			for i in range(14):
				var t := 0.6 + 0.08 * i + rng.randf() * 0.04
				S._chime(b, t, S._hz(BONES[8 - (i % 9)]), 0.28 * (1.0 - i * 0.04), 0.3)
			var sigh := S._silence(0.9)
			S._air(sigh, rng, 0.0, 0.9, 1.0, 1400.0, 900.0, 500.0, 0.2, 0.8)
			S._layer(b, 1.6, sigh, [[0.0, 0.0], [0.15, 0.4], [0.9, 0.0]])
			S._great_bell(b, rng, 1.7, S._hz(50), 0.35, 0.5)
			return S._finish(b, -12.0, 0.4)
	push_error("sfx_w3: unknown sound '%s'" % sound)
	return PackedFloat32Array()
