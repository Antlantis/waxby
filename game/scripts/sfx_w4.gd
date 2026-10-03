extends RefCounted
## Sfx's World 4 bank, the Frozen Carillon (contract.md section 14): the
## tick, ice and rime, icicles, belts, cogs, weights, its monsters and the
## Tinker of Hours. The family is brass and ice: escapement ticks, ratchets,
## springs, small bells, glassy cracks. Until rendered each plays its
## FALLBACK. Tells last at least 0.35 s and sit in 500 Hz-3 kHz (test_sfx).
##
## Pitchable on purpose (the caller passes Sfx.note(i)): ice_crack by crack
## stage (1, note(1), note(3): D6, F6, A6), chime_hour per hour bell.
## tinker_stop is played at the start of Stop the Clock's 0.8 s tell: its
## swell lands 0.8 s in, where time stops (call Sfx.tape_stop() then).
##
## A tell that builds is cut for its longest tell, its threat landing
## TELL_AT seconds in (Sfx.tell trims its start for a shorter one); one that
## warns with its onset (the owl's hoot, the Tinker's "krrk-krrk") plays whole.
## Tonal sounds are never jittered (a random pitch would put them between
## two notes): takes vary them.

const S := preload("res://scripts/sfx.gd")

const NAMES := [
	# the features
	"tick", "ice_slide", "ice_squeak", "ice_crack", "rime_melt", "rime_freeze", "icicle_tell", "icicle_fall",
	"icicle_shatter", "belt_run", "belt_reverse", "gear_tick", "gear_clunk", "pendulum_swing", "clock_chime",
	# the monsters (and the Echoing Omen)
	"wind_up", "tick_step", "spring_boing", "gear_roll", "gear_catch", "gear_spark", "ice_creak", "ice_spike",
	"ice_shatter", "heavy_step", "owl_tick", "owl_hoot", "owl_screech", "omen_tick",
	# the Tinker of Hours, the long ones last
	"tinker_windup", "tinker_throw", "clock_tock", "tinker_stop", "tinker_go", "chime_hour", "wrong_hour",
	"tinker_open", "tinker_step", "tinker_overwind", "midnight_chimes", "tinker_die",
]
const TAKES := {"tick_step": 2, "heavy_step": 2, "tinker_step": 2, "gear_tick": 2, "ice_spike": 3, "ice_squeak": 2}
const JITTER := {"ice_slide": 0.04, "icicle_fall": 0.03, "gear_clunk": 0.03, "gear_spark": 0.04, "heavy_step": 0.03,
		"tinker_step": 0.02, "spring_boing": 0.03, "rime_melt": 0.03}
# When each building tell's threat lands, in seconds from its start (spec
# 4.4, the features' DIFF_KNOBS at Dusk, the Tinker's first-phase tells, 5.3).
const TELL_AT := {"icicle_tell": 0.45, "wind_up": 0.55, "gear_catch": 0.40, "ice_creak": 0.70, "tinker_stop": 0.80}


static func _hour_bell(b: PackedFloat32Array, at: float, freq: float, amp: float, ring: float) -> void:
	## A small tuned clock bell (the carillon's hour bells, the quarter
	## chime): a clear strike note, its minor-third and fifth partials and a
	## hum under it, lighter than a great bell (five partials, not 24).
	S._partial(b, at, freq, amp, 0.55 * ring, 0.0015)
	S._partial(b, at, freq * 1.003, amp * 0.4, 0.5 * ring, 0.0015)
	S._partial(b, at, freq * 0.5, amp * 0.12, 0.6 * ring, 0.003)
	S._partial(b, at, freq * 1.19, amp * 0.25, 0.3 * ring, 0.0015)
	S._partial(b, at, freq * 1.5, amp * 0.15, 0.25 * ring, 0.0015)
	S._partial(b, at, freq * 2.76, amp * 0.18, 0.1 * ring, 0.001)
	S._partial(b, at, freq * 4.1, amp * 0.1, 0.04 * ring, 0.0008)


static func render(sound: String, take: int = 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound) + 7919 * take
	var b: PackedFloat32Array
	match sound:
		# ---- the tick, ice and rime
		"tick":
			# World 4's beat (0.536 s), for a lamp or a clock hand that pulses
			# on it: the escapement's dry "tk", wood and brass.
			b = S._silence(0.06)
			S._hiss(b, rng, 0.0, 0.003, 0.3)
			S._partial(b, 0.0, 2350.0, 0.6, 0.006, 0.0008)
			S._partial(b, 0.0, 4700.0, 0.2, 0.003, 0.0008)
			S._bar(b, 0.0, 1180.0, 0.35, 0.008, 0.4)
			return S._finish(b, -26.0, 0.015)
		"ice_slide":
			# Sliding on wax-ice: a thin high scrape that wavers, 0.4 s.
			b = S._silence(0.4)
			var lv := [[0.0, 0.0], [0.04, 0.8], [0.12, 0.5], [0.2, 0.9], [0.28, 0.45], [0.36, 0.6], [0.4, 0.0]]
			S._band(b, rng, 0.0, 0.4, 1.0, lv, [[0.0, 3200.0], [0.4, 4600.0]], 1.8)
			S._band(b, rng, 0.0, 0.4, 0.4, lv, [[0.0, 1700.0], [0.4, 2200.0]], 2.0)
			return S._finish(b, -24.0, 0.05)
		"ice_squeak":
			# A boot turning on ice: a short rubbery squeak.
			# Two takes, squeaking up C7 to D7 or D7 to F7.
			b = S._silence(0.1)
			var up: Array = [[2093.0, 2349.3], [2349.3, 2793.8]][take % 2]
			S._sweep(b, 0.0, [[0.0, up[0]], [0.015, up[1]], [0.07, up[1]]], 0.5, 0.05, 0.07, [1.0, 0.3], 0.01, 60.0)
			S._air(b, rng, 0.0, 0.05, 0.3, 2000.0, 3000.0, 2400.0, 0.3, 1.2)
			return S._finish(b, -24.0, 0.02)
		"ice_crack":
			# Ice cracking (a stage of a crack, a bell's frost breaking): a
			# sharp snap, the split running with a crackle, and the ice ringing
			# glassy on D6 (pitched per stage: D6, F6, A6).
			b = S._silence(0.6)
			S._air(b, rng, 0.0, 0.02, 1.0, 2800.0, 3600.0, 2400.0, 0.1, 0.9)
			S._thud(b, 0.0, 520.0, 260.0, 0.3, 0.015)
			var t := 0.01
			while t < 0.3:
				S._partial(b, t, rng.randf_range(2600.0, 5200.0), rng.randf_range(0.1, 0.25) * (1.0 - t * 2.5), 0.004, 0.0008)
				t += rng.randf_range(0.008, 0.03)
			S._glass(b, 0.005, S._hz(86), 0.55, 0.12)
			S._partial(b, 0.005, S._hz(98), 0.15, 0.05, 0.001)
			return S._finish(b, -16.0, 0.08)
		"rime_melt":
			# Rime melting under him (0.4 s at full): a hiss of steam, the
			# frost softening, drips.
			b = S._silence(0.5)
			S._hiss(b, rng, 0.0, 0.35, 0.4, 0.6)
			S._band(b, rng, 0.0, 0.4, 0.4, [[0.0, 0.0], [0.05, 1.0], [0.4, 0.0]], [[0.0, 3800.0], [0.4, 2600.0]], 1.5)
			for i in range(3):
				var f0 := rng.randf_range(900.0, 1200.0)
				S._sweep(b, 0.15 + 0.1 * i, [[0.0, f0], [0.02, f0 * 2.0]], 0.35, 0.02, 0.06, [1.0])
			S._sweep(b, 0.0, [[0.0, S._hz(93)], [0.4, S._hz(86)]], 0.1, 0.2, 0.4, [1.0])
			return S._finish(b, -20.0, 0.06)
		"rime_freeze":
			# Melted rime freezing back over its 1.0 s: frost creeping across
			# (a crackle thickening), a cold glassy shimmer stepping up D6, F6,
			# A6.
			b = S._silence(1.05)
			var t := 0.0
			while t < 1.0:
				S._partial(b, t, rng.randf_range(3000.0, 6000.0), 0.06 + 0.2 * t, 0.003, 0.0008)
				t += 0.05 - 0.035 * t
			S._harmonica(b, 0.0, S._hz(86), 0.15, 0.6, 0.3, 0.25, 2.0)
			S._harmonica(b, 0.3, S._hz(89), 0.2, 0.55, 0.25, 0.25, 2.5)
			S._harmonica(b, 0.6, S._hz(93), 0.25, 0.42, 0.2, 0.2, 3.0)
			S._glass(b, 0.92, S._hz(93), 0.3, 0.08)
			return S._finish(b, -21.0, 0.08)

		# ---- icicles
		"icicle_tell":
			# An icicle about to drop (its 0.45 s tell): a crack at the root,
			# the ice ticking C7 and D7 as it shakes, creaking at the root.
			b = S._silence(0.5)
			S._air(b, rng, 0.0, 0.02, 0.6, 2600.0, 3400.0, 2200.0, 0.1, 0.9)
			S._clink(b, rng, 0.02, S._hz(96), 0.5)
			S._clink(b, rng, 0.14, S._hz(98), 0.55)
			S._clink(b, rng, 0.24, S._hz(96), 0.5)
			S._clink(b, rng, 0.33, S._hz(98), 0.6)
			S._creak(b, rng, 0.0, 0.46, [[0.0, 30.0], [0.46, 70.0]], S._hz(81), 0.35, [[0.0, 0.3], [0.35, 1.0], [0.46, 0.6]])
			return S._finish(b, -17.0, 0.04)
		"icicle_fall":
			# An icicle falling: a whistle dropping from 2.4 to 1.2 kHz.
			b = S._silence(0.35)
			S._band(b, rng, 0.0, 0.34, 0.8, [[0.0, 0.0], [0.05, 1.0], [0.3, 0.7], [0.34, 0.0]], [[0.0, 2400.0], [0.34, 1200.0]], 5.0)
			S._sweep(b, 0.0, [[0.0, 2400.0], [0.34, 1200.0]], 0.2, 20.0, 0.34, [1.0])
			return S._finish(b, -19.0, 0.05)
		"icicle_shatter":
			# An icicle breaks on the floor (or on him): a crash of ice, shards
			# tinkling off.
			b = S._silence(0.45)
			S._band(b, rng, 0.0, 0.1, 1.0, [[0.0, 1.0], [0.1, 0.0]], [[0.0, 5000.0], [0.1, 2500.0]], 0.8)
			S._thud(b, 0.0, 480.0, 240.0, 0.5, 0.025)
			for i in range(8):
				S._clink(b, rng, 0.01 + rng.randf() * 0.18, rng.randf_range(2000.0, 6000.0), rng.randf_range(0.2, 0.45))
			return S._finish(b, -15.0, 0.08)

		# ---- belts, cogs, weights, the clock
		"belt_run":
			# A gear belt running: its teeth clacking by in an even patter over
			# a brass hum. Half a second, to be played again while it runs.
			b = S._silence(0.5)
			for i in range(10):
				S._partial(b, 0.02 + 0.048 * i, S._hz(93), rng.randf_range(0.3, 0.45), 0.006, 0.0008)
				S._hiss(b, rng, 0.02 + 0.048 * i, 0.004, 0.2)
			S._sweep(b, 0.0, [[0.0, 220.0]], 0.15, 20.0, 0.5, [1.0, 0.8, 0.6, 0.5, 0.4], 0.01, 21.0)
			return S._finish(b, -24.0, 0.08)
		"belt_reverse":
			# A belt changing direction: a heavy clunk, the teeth running down
			# and catching again the other way, a spring settling.
			b = S._silence(0.5)
			S._thud(b, 0.0, 380.0, 180.0, 0.8, 0.04)
			S._bronze(b, 0.0, 700.0, 0.35, 0.06)
			S._ratchet(b, rng, 0.04, 0.18, 0.02, 0.06, 1900.0, 0.45)
			S._ratchet(b, rng, 0.26, 0.2, 0.06, 0.02, 2100.0, 0.45)
			S._sweep(b, 0.2, [[0.0, 420.0], [0.1, 600.0]], 0.2, 0.08, 0.2, [1.0, 0.4], 0.04, 24.0)
			return S._finish(b, -17.0, 0.06)
		"gear_tick":
			# A cog's tooth passing: a bright little click and an A7 ping.
			b = S._silence(0.08)
			S._hiss(b, rng, 0.0, 0.008, 0.4)
			S._partial(b, 0.0, S._hz(105), 0.5, 0.012, 0.0008)
			S._partial(b, 0.0, S._hz(105) * 2.76, 0.12, 0.005, 0.0008)
			return S._finish(b, -25.0, 0.02)
		"gear_clunk":
			# A big gear engaging (a cog's quarter turn, a weight's catch): a
			# deep brass clunk, a clink and the pawl's tick.
			b = S._silence(0.32)
			S._thud(b, 0.0, 320.0, 130.0, 1.0, 0.06)
			S._bronze(b, 0.0, 430.0, 0.4, 0.07)
			S._clink(b, rng, 0.0, 1200.0, 0.4)
			S._partial(b, 0.09, 2500.0, 0.25, 0.006, 0.0008)
			return S._finish(b, -17.0, 0.06)
		"pendulum_swing":
			# A pendulum weight swinging past: a heavy whoosh that rises and
			# falls as it passes, and the rod's soft tick at the bottom.
			b = S._silence(0.6)
			S._air(b, rng, 0.0, 0.56, 1.0, 400.0, 900.0, 400.0, 0.5, 1.2)
			S._band(b, rng, 0.05, 0.46, 0.35, [[0.0, 0.0], [0.23, 1.0], [0.46, 0.0]], [[0.0, 1000.0], [0.23, 1900.0], [0.46, 900.0]], 1.2)
			S._partial(b, 0.28, 2200.0, 0.2, 0.01, 0.0008)
			S._thud(b, 0.28, 420.0, 280.0, 0.2, 0.02)
			return S._finish(b, -18.0, 0.08)
		"clock_chime":
			# The Carillon's quarter chime (and World 4's altar lit): D5 F5 G5
			# A5 on small hour bells, 1.6 s.
			b = S._silence(1.6)
			var q := [74, 77, 79, 81]
			for i in range(q.size()):
				_hour_bell(b, 0.02 + 0.28 * i, S._hz(q[i]), 0.7, 1.0 if i < 3 else 1.6)
			return S._finish(b, -16.0, 0.3)

		# ---- the Tickwind
		"wind_up":
			# A Tickwind winding up to charge (its 0.55 s tell): the key on its
			# back cranking round, the ratchet quickening, the spring whining
			# up, a puff of steam as it lets go.
			b = S._silence(0.58)
			S._ratchet(b, rng, 0.0, 0.5, 0.06, 0.02, 2100.0, 0.6, 0.6)
			var spring := S._silence(0.5)
			S._sweep(spring, 0.0, [[0.0, 420.0], [0.5, 980.0]], 0.3, 20.0, 0.5, [1.0, 0.45, 0.25], 0.02, 17.0)
			S._layer(b, 0.0, spring, [[0.0, 0.2], [0.45, 1.0], [0.5, 0.0]])
			S._band(b, rng, 0.44, 0.14, 0.4, [[0.0, 0.0], [0.02, 1.0], [0.14, 0.0]], [[0.0, 4200.0], [0.14, 2800.0]], 1.0)
			return S._finish(b, -17.0, 0.03)
		"tick_step":
			# A Tickwind marching on the tick: a tin foot's "tk" on the stone,
			# its two takes F6 and G6, so a march goes tick-tock.
			b = S._silence(0.08)
			var f := S._hz(89 if take % 2 == 0 else 91)
			S._partial(b, 0.0, f, 0.5, 0.01, 0.0008)
			S._partial(b, 0.0, f * 2.0, 0.15, 0.005, 0.0008)
			S._thud(b, 0.0, 480.0, 300.0, 0.4, 0.012)
			return S._finish(b, -26.0, 0.02)
		"spring_boing":
			# A Tickwind hits a wall and reels: "boing", the spring shivering,
			# and a tin clank.
			b = S._silence(0.5)
			S._sweep(b, 0.0, [[0.0, 220.0], [0.08, 620.0], [0.45, 480.0]], 0.8, 0.14, 0.48, [1.0, 0.45, 0.2], 0.06, 26.0)
			S._bronze(b, 0.0, 820.0, 0.35, 0.05)
			S._thud(b, 0.0, 380.0, 200.0, 0.4, 0.03)
			return S._finish(b, -17.0, 0.08)

		# ---- the Spurwheel
		"gear_roll":
			# A Spurwheel rolling along the stone: its teeth clattering fast and
			# a grinding brass whirr on A3. 0.6 s, played again as it rolls.
			b = S._silence(0.6)
			var t := 0.01
			while t < 0.58:
				S._partial(b, t, rng.randf_range(1500.0, 1900.0), 0.3, 0.005, 0.0008)
				t += 0.026
			S._band(b, rng, 0.0, 0.6, 0.35, [[0.0, 0.0], [0.05, 1.0], [0.55, 1.0], [0.6, 0.0]], [[0.0, 2200.0]], 3.0)
			S._sweep(b, 0.0, [[0.0, 220.0], [0.6, 220.0]], 0.2, 20.0, 0.6, [1.0, 0.7, 0.5, 0.4, 0.3], 0.02, 38.0)
			return S._finish(b, -21.0, 0.08)
		"gear_catch":
			# A Spurwheel jamming at a corner (its 0.40 s tell before it's
			# caught): the teeth grinding and stuttering to a halt, a shriek
			# of brass, sparks.
			b = S._silence(0.45)
			S._ratchet(b, rng, 0.0, 0.34, 0.018, 0.07, 1760.0, 0.7)
			var shriek := S._silence(0.36)
			S._sweep(shriek, 0.0, [[0.0, 1400.0], [0.3, 1000.0]], 0.3, 20.0, 0.36, [1.0, 0.5, 0.3], 0.03, 33.0)
			S._layer(b, 0.0, shriek, [[0.0, 0.6], [0.25, 1.0], [0.36, 0.0]])
			for i in range(8):
				S._hiss(b, rng, rng.randf() * 0.35, rng.randf_range(0.004, 0.01), rng.randf_range(0.2, 0.4))
			S._bronze(b, 0.36, S._hz(74), 0.4, 0.05)
			return S._finish(b, -16.0, 0.04)
		"gear_spark":
			# Sparks off a cog: a bright crackle and a few tiny pings.
			b = S._silence(0.3)
			S._hiss(b, rng, 0.0, 0.2, 0.5, 0.8)
			for i in range(4):
				S._partial(b, rng.randf() * 0.15, rng.randf_range(3500.0, 6000.0), 0.15, 0.01, 0.0008)
			S._air(b, rng, 0.0, 0.08, 0.3, 2000.0, 3400.0, 2400.0, 0.2, 1.2)
			return S._finish(b, -20.0, 0.06)

		# ---- the Frostbuckle
		"ice_creak":
			# A Frostbuckle's Frost Stomp or Shield Slam coming (its 0.7 s
			# tell): the ice around it straining, a deep glassy groan, cracks
			# ticking along it faster and faster.
			b = S._silence(0.72)
			S._creak(b, rng, 0.0, 0.7, [[0.0, 30.0], [0.7, 85.0]], 880.0, 0.45, [[0.0, 0.3], [0.62, 1.0], [0.7, 0.8]])
			var groan := S._silence(0.7)
			S._sweep(groan, 0.0, [[0.0, 520.0], [0.68, 700.0]], 0.3, 20.0, 0.7, [1.0, 0.4, 0.3, 0.15], 0.01, 7.0)
			S._layer(b, 0.0, groan, [[0.0, 0.3], [0.6, 1.0], [0.7, 0.0]])
			var t := 0.08
			while t < 0.66:
				S._partial(b, t, rng.randf_range(2500.0, 4200.0), 0.1 + 0.25 * t, 0.004, 0.0008)
				t += 0.09 - 0.07 * t
			return S._finish(b, -16.0, 0.04)
		"ice_spike":
			# An ice spike bursting up (one tile of a Frost Stomp's line): a
			# crystalline crack and a rising "shing", ringing A6, C7 or D7 (three
			# takes, so a line of them runs about the scale).
			b = S._silence(0.3)
			S._air(b, rng, 0.0, 0.02, 0.9, 2600.0, 3400.0, 2200.0, 0.1, 0.9)
			S._sweep(b, 0.0, [[0.0, 1200.0], [0.1, 2900.0]], 0.4, 0.08, 0.2, [1.0, 0.3])
			S._glass(b, 0.01, S._hz([93, 96, 98][take % 3]), 0.3, 0.06)
			S._thud(b, 0.0, 520.0, 300.0, 0.4, 0.015)
			return S._finish(b, -17.0, 0.05)
		"ice_shatter":
			# A Frostbuckle's rime shell bursting (it's thawed, and open): a
			# great crash of ice, shards raining off and ringing.
			b = S._silence(0.75)
			S._band(b, rng, 0.0, 0.14, 1.0, [[0.0, 1.0], [0.14, 0.0]], [[0.0, 5200.0], [0.14, 2200.0]], 0.8)
			S._thud(b, 0.0, 420.0, 180.0, 0.9, 0.05)
			S._air(b, rng, 0.0, 0.3, 0.5, 800.0, 1800.0, 700.0, 0.1, 0.8)
			for i in range(16):
				var t := 0.01 + pow(rng.randf(), 1.4) * 0.5
				S._clink(b, rng, t, rng.randf_range(1800.0, 6000.0), rng.randf_range(0.2, 0.5) * (1.0 - t))
			S._glass(b, 0.01, S._hz(89), 0.3, 0.2)
			return S._finish(b, -13.0, 0.15)
		"heavy_step":
			# A Frostbuckle's step: an armoured thud with ice crunching under
			# it. Two takes.
			b = S._silence(0.25)
			S._thump(b, 0.0, 360.0, 180.0, 1.0, 0.04, 3.0)
			S._thud(b, 0.0, 560.0, 300.0, 0.5, 0.02)
			S._air(b, rng, 0.0, 0.05, 0.5, 900.0, 1600.0, 800.0, 0.2, 0.9)
			for i in range(6):
				S._partial(b, rng.randf() * 0.06, rng.randf_range(2000.0, 4000.0), 0.15, 0.004, 0.0008)
			S._bronze(b, 0.0, 520.0 + 30.0 * take, 0.25, 0.03)
			return S._finish(b, -18.0, 0.05)

		# ---- the Hoarowl
		"owl_tick":
			# A Hoarowl's clockwork turning its head on the tick: a small tick
			# on F7 and the whirr of its gears (D7 and F7 in turn).
			b = S._silence(0.12)
			S._partial(b, 0.0, S._hz(101), 0.5, 0.006, 0.0008)
			S._hiss(b, rng, 0.0, 0.004, 0.3)
			for i in range(6):
				S._partial(b, 0.02 + 0.013 * i, S._hz(98 if i % 2 == 0 else 101), 0.13, 0.004, 0.0008)
				S._hiss(b, rng, 0.02 + 0.013 * i, 0.003, 0.06)
			return S._finish(b, -25.0, 0.02)
		"owl_hoot":
			# Spotted in a Hoarowl's light (its meter fills in 0.6 s): a hollow
			# clockwork "hoo-oo" rising, C5 then D5 up to F5, its gears
			# whirring faster.
			b = S._silence(0.6)
			S._sweep(b, 0.0, [[0.0, 523.25], [0.22, 523.25]], 0.6, 0.3, 0.24, [1.0, 0.25, 0.12])
			S._sweep(b, 0.26, [[0.0, 587.33], [0.12, 587.33], [0.17, 698.46], [0.3, 698.46]], 0.7, 0.4, 0.32, [1.0, 0.25, 0.12])
			S._air(b, rng, 0.0, 0.58, 0.2, 700.0, 1200.0, 1100.0, 0.8, 1.0)
			S._ratchet(b, rng, 0.0, 0.55, 0.04, 0.015, 3000.0, 0.15, 0.7)
			return S._finish(b, -17.0, 0.06)
		"owl_screech":
			# A Hoarowl's alarm (0.5 s): a metallic screech, a tinny alarm bell
			# hammering, the icicles it calls about to fall.
			b = S._silence(0.55)
			S._sweep(b, 0.0, [[0.0, 1760.0], [0.1, 2349.3], [0.48, 1396.9]], 0.6, 0.4, 0.5, [1.0, 0.5, 0.3, 0.15], 0.03, 37.0)
			for i in range(6):
				S._bronze(b, 0.02 + 0.08 * i, 1396.9, 0.25, 0.03)
			S._air(b, rng, 0.0, 0.3, 0.3, 1500.0, 3000.0, 2000.0, 0.2, 1.2)
			return S._finish(b, -14.0, 0.06)
		"omen_tick":
			# An Echoing elite: tick-tock, and a pale shimmer played backwards,
			# the blow it will repeat.
			b = S._silence(0.5)
			S._partial(b, 0.0, 2350.0, 0.5, 0.006, 0.0008)
			S._bar(b, 0.0, 1180.0, 0.3, 0.008, 0.4)
			S._partial(b, 0.14, 1760.0, 0.5, 0.008, 0.0008)
			S._bar(b, 0.14, 880.0, 0.3, 0.01, 0.4)
			var echo := S._silence(0.3)
			S._glass(echo, 0.0, S._hz(93), 0.6, 0.06)
			S._glass(echo, 0.0, S._hz(86), 0.4, 0.06)
			S._layer(b, 0.18, S._reversed(echo))
			return S._finish(b, -19.0, 0.04)

		# ---- the Tinker of Hours
		"tinker_windup":
			# Gear Toss coming (its 0.55 s tell): an arm cranking back,
			# "krrk-krrk", two bursts of the ratchet, steam hissing, and the
			# cogs glinting as it lets fly.
			b = S._silence(0.58)
			S._ratchet(b, rng, 0.0, 0.18, 0.016, 0.012, 1600.0, 0.8)
			S._ratchet(b, rng, 0.26, 0.18, 0.016, 0.011, 1800.0, 0.9)
			S._band(b, rng, 0.0, 0.5, 0.25, [[0.0, 0.0], [0.4, 1.0], [0.5, 0.0]], [[0.0, 3000.0], [0.5, 4600.0]], 1.2)
			S._bronze(b, 0.02, 380.0, 0.3, 0.06)
			S._bronze(b, 0.28, 400.0, 0.3, 0.06)
			S._partial(b, 0.48, S._hz(98), 0.3, 0.05, 0.0008)
			return S._finish(b, -15.0, 0.03)
		"tinker_throw":
			# The cogs flung: a whirring launch, rising, and the air behind it.
			b = S._silence(0.42)
			S._sweep(b, 0.0, [[0.0, 300.0], [0.3, 1200.0]], 0.6, 0.3, 0.34, [1.0, 0.5, 0.3, 0.2], 0.12, 60.0)
			S._air(b, rng, 0.0, 0.3, 0.7, 500.0, 2200.0, 1200.0, 0.3, 1.2)
			S._thud(b, 0.0, 400.0, 200.0, 0.4, 0.03)
			return S._finish(b, -16.0, 0.06)
		"clock_tock":
			# The great clock's hand jumping to the next hour bell: one heavy
			# "tock", wood and brass, that you feel as much as hear.
			b = S._silence(0.36)
			S._bar(b, 0.0, S._hz(62), 0.8, 0.05, 0.8)
			S._bronze(b, 0.0, S._hz(74), 0.35, 0.08)
			S._thump(b, 0.0, 300.0, 140.0, 0.8, 0.05, 2.5)
			S._partial(b, 0.0, 2350.0, 0.25, 0.01, 0.0008)
			return S._finish(b, -15.0, 0.08)
		"tinker_stop":
			# Stop the Clock: the pocket watch ticks twice (tick... tick...) as
			# a great bell swells backwards up into the stop, 0.8 s in, where
			# time freezes (tape_stop) with a sagging "vwoom" and a glassy
			# suck of air.
			b = S._silence(1.4)
			S._partial(b, 0.0, 2600.0, 0.35, 0.008, 0.0008)
			S._bar(b, 0.0, 1300.0, 0.25, 0.012, 0.5)
			S._partial(b, 0.4, 2600.0, 0.4, 0.008, 0.0008)
			S._bar(b, 0.4, 1300.0, 0.3, 0.012, 0.5)
			var bell := S._silence(0.8)
			S._great_bell(bell, rng, 0.0, S._hz(50), 0.6, 0.55)
			S._bell(bell, 0.0, S._hz(74), 0.6, 0.4)
			S._bell(bell, 0.0, S._hz(81), 0.4, 0.35)
			S._layer(b, 0.0, S._reversed(bell), [[0.0, 0.0], [0.3, 0.4], [0.8, 1.0]])
			S._sweep(b, 0.8, [[0.0, 520.0], [0.5, 110.0]], 0.5, 0.3, 0.58, [0.6, 0.8, 0.7, 0.55, 0.4, 0.3])
			var suck := S._silence(0.3)
			S._band(suck, rng, 0.0, 0.3, 1.0, [[0.0, 1.0], [0.3, 0.0]], [[0.0, 5200.0], [0.3, 2600.0]], 1.2)
			S._layer(b, 0.5, S._reversed(suck))
			return S._finish(b, -13.0, 0.2)
		"tinker_go":
			# Time runs again (tape_go): a whoosh played backwards and three
			# ticks, quickening.
			b = S._silence(0.6)
			var whoosh := S._silence(0.35)
			S._air(whoosh, rng, 0.0, 0.35, 1.0, 400.0, 2400.0, 600.0, 0.15, 1.2)
			S._layer(b, 0.0, S._reversed(whoosh))
			var ticks := [0.34, 0.44, 0.51]
			for t in ticks:
				S._partial(b, t, 2600.0, 0.4, 0.008, 0.0008)
				S._bar(b, t, 1300.0, 0.3, 0.012, 0.5)
			return S._finish(b, -16.0, 0.06)
		"chime_hour":
			# The lit hour bell rung (he's Chimed): the hour strikes, a clear
			# gold bell on D5 with a shimmer of chimes sweeping round it.
			b = S._silence(1.5)
			_hour_bell(b, 0.0, S._hz(74), 1.0, 1.6)
			S._bell(b, 0.0, S._hz(86), 0.3, 0.6)
			var ring := [86, 89, 93, 98]
			for i in range(ring.size()):
				S._chime(b, 0.08 + 0.06 * i, S._hz(ring[i]), 0.2, 0.25)
			S._thud(b, 0.0, 380.0, 200.0, 0.4, 0.03)
			return S._finish(b, -13.0, 0.3)
		"wrong_hour":
			# "Wrong hour!": a sour, choked clank (two bells a semitone apart,
			# damped), a buzz and frost crackling over every bell.
			b = S._silence(0.62)
			var bells := S._silence(0.6)
			_hour_bell(bells, 0.0, S._hz(75), 0.8, 0.8)
			_hour_bell(bells, 0.0, S._hz(74), 0.7, 0.8)
			S._shape(bells, [[0.0, 1.0], [0.05, 1.0], [0.25, 0.0]])
			S._layer(b, 0.0, bells)
			S._thud(b, 0.0, 400.0, 180.0, 0.8, 0.04)
			S._sweep(b, 0.02, [[0.0, 180.0], [0.3, 150.0]], 0.3, 0.2, 0.32, [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4], 0.05, 43.0)
			var t := 0.1
			while t < 0.58:
				S._partial(b, t, rng.randf_range(3000.0, 5500.0), 0.12, 0.003, 0.0008)
				t += rng.randf_range(0.01, 0.03)
			return S._finish(b, -15.0, 0.06)
		"tinker_open":
			# Chimed: the body falls forward and the case springs open (the
			# window: strike the spring): a hinge creaking, a spring's boing,
			# and a cuckoo's two notes, D6 then A5.
			b = S._silence(1.0)
			S._creak(b, rng, 0.0, 0.3, [[0.0, 60.0], [0.3, 30.0]], 520.0, 0.5)
			S._sweep(b, 0.0, [[0.0, 500.0], [0.3, 300.0]], 0.25, 20.0, 0.3, [1.0, 0.6, 0.4], 0.03, 29.0)
			S._sweep(b, 0.3, [[0.0, 260.0], [0.06, 640.0], [0.35, 520.0]], 0.5, 0.15, 0.38, [1.0, 0.4, 0.2], 0.05, 22.0)
			S._pluck(b, 0.42, S._hz(86), 0.8, 0.2, 0.3)
			S._chime(b, 0.42, S._hz(86), 0.4, 0.2)
			S._pluck(b, 0.62, S._hz(81), 0.8, 0.3, 0.3)
			S._chime(b, 0.62, S._hz(81), 0.4, 0.3)
			return S._finish(b, -14.0, 0.15)
		"tinker_step":
			# A step of the clockwork body: a heavy brass footfall, a clank of
			# its bell-shell and a tick of its works. Two takes.
			b = S._silence(0.3)
			S._thump(b, 0.0, 360.0, 170.0, 1.0, 0.045, 3.0)
			S._bronze(b, 0.0, 400.0 + 25.0 * take, 0.45, 0.08)
			S._air(b, rng, 0.0, 0.04, 0.4, 1000.0, 1800.0, 900.0, 0.2, 0.9)
			S._partial(b, 0.05, 2400.0, 0.2, 0.006, 0.0008)
			return S._finish(b, -17.0, 0.06)
		"tinker_overwind":
			# Overwound (a phase change): six springs going "boing", each lower
			# and duller (coming to rest down the scale, A4 to A3), its works
			# clattering loose, a grinding roar of gears.
			b = S._silence(1.5)
			var rest := [440.0, 392.0, 349.23, 293.66, 261.63, 220.0]
			for i in range(6):
				var at := 0.03 + 0.16 * i
				S._sweep(b, at, [[0.0, 200.0 + 40.0 * i], [0.06, 600.0 - 30.0 * i], [0.3, rest[i]]], 0.5 * (1.0 - 0.1 * i),
						0.12, 0.32, [1.0, 0.45, 0.2], 0.06, 24.0)
			for i in range(14):
				S._clink(b, rng, 0.1 + rng.randf() * 1.0, rng.randf_range(1200.0, 3000.0), 0.3)
			S._band(b, rng, 0.0, 1.4, 0.4, [[0.0, 0.0], [0.2, 1.0], [1.2, 0.7], [1.4, 0.0]], [[0.0, 900.0], [1.4, 600.0]], 1.5)
			S._sweep(b, 0.0, [[0.0, 146.83], [0.6, 146.83], [1.0, 174.61], [1.4, 110.0]], 0.4, 20.0, 1.4,
					[1.0, 0.8, 0.6, 0.5, 0.4, 0.3], 0.03, 31.0)
			return S._finish(b, -12.5, 0.3)
		"midnight_chimes":
			# Midnight (the Tinker's last roar): twelve hour-strokes over 3 s,
			# D4 and A4 in turn like a tower clock, the icicles coming down
			# between them.
			b = S._silence(3.3)
			for i in range(12):
				var at := 0.02 + 0.25 * i
				var m := 62 if i % 2 == 0 else 69
				_hour_bell(b, at, S._hz(m), 0.55, 0.6)
				S._bell(b, at, S._hz(m + 12), 0.7, 0.35)
				S._thud(b, at, 360.0, 180.0, 0.25, 0.03)
			return S._finish(b, -13.0, 0.3)
		"tinker_die":
			# The Tinker undone: its ratchet running down, slower and slower
			# to a stop, springs flopping loose, then the four hour bells
			# struck at once in the true hour's chord (D F A C).
			b = S._silence(3.0)
			S._ratchet(b, rng, 0.0, 1.2, 0.02, 0.16, 1500.0, 0.8)
			for i in range(3):
				S._sweep(b, 0.3 + 0.35 * i, [[0.0, 500.0], [0.3, 180.0]], 0.35, 0.2, 0.34, [1.0, 0.4, 0.2], 0.08, 18.0)
			S._thump(b, 1.3, 260.0, 90.0, 0.9, 0.1, 2.5)
			var chord := [74, 77, 81, 84]
			for i in range(chord.size()):
				_hour_bell(b, 1.35 + 0.012 * i, S._hz(chord[i]), 0.55, 2.0)
			S._great_bell(b, rng, 1.35, S._hz(50), 0.4, 0.6)
			return S._finish(b, -12.0, 0.4)
	push_error("sfx_w4: unknown sound '%s'" % sound)
	return PackedFloat32Array()
