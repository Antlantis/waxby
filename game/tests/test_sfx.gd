extends SceneTree
## Sfx: every sound renders to clean, levelled 16-bit data (no clicks at the
## ends or anywhere inside); the new sounds have the characters they were made
## for (the story blips' lengths and pitch, a glassy crit, a rising flare, a
## two-beat heart, a whisper with nothing low, the kits' handbell and motes in
## key); every name the callings' kits play exists; the story voices render
## first; every name plays on the dummy audio driver once rendered; pitch,
## jitter, takes, aliases, voice_note and in_key (every speaker in key),
## release (never on a voice since handed to another sound) and the voice
## pool behave; the render cache round-trips and ignores anything stale or
## torn; mute, volume and music mute survive a restart in the shared settings
## file; the music runs on its own bus with a low-pass that glides in and
## out; and every track loops, crossfades, ducks, mutes and shrugs off a
## missing file. The music WAVs are read straight off disk
## (AudioStreamWAV.load_from_file), never through the import system.
##
## v3's engine (contract.md section 14): the Effects and Ambience buses; the
## banks (every v3 name in one bank with a core fallback it plays until it's
## rendered, bank files checked like the core, the render queue, per-bank
## caches, bank_ready); set_hush and hush_pulse (the glide, the effects' cap,
## a telegraphed silence); the stems (one AudioStreamSynchronized that stays
## sample-aligned for ten loops, QOA included, set_stem live, the premixes
## and the stand-in track); tape_stop and tape_go; seek_music; the ambience
## beds; the track fallbacks; and the spike's arithmetic.
##
## v3's sounds (the bank files, scripts/sfx_<bank>.gd): every v3 name has its
## own recipe, each as clean as v2's; every tell sounds for at least 0.35 s
## with most of its energy in 500 Hz-3 kHz, where a phone speaker plays, and
## peaks before its threat lands (TELL_AT, which matches the features' own
## knobs); tell() fits one to a shorter tell (a trimmed take that can't
## click, a silence moved with it); every recipe is in key unless it's sour
## on purpose, and no tonal sound is jittered (the pitched ones on D, the
## medal only roots and fifths), the Lull is A, F#, D; the story's sounds
## have their shapes (blip lengths, the choked bell, the falling pull, the
## descending give, the Snuff's and the Deep Quiet's silences); the loud and
## the quiet sit where they should; impacts keep their body in the phone's
## mids; the story bank renders its blips and pull, give and lull first; and
## play() takes a gain (a flam keeps the louder).
##
##     Godot --headless --path game --script res://tests/test_sfx.gd

const SfxLib := preload("res://scripts/sfx.gd")
const SettingsLib := preload("res://scripts/settings.gd")
const SpikeLib := preload("res://scripts/sfx_spike.gd")

# Each track's loop length in seconds: [shortest, longest]. v2's are there;
# v3's (spec 12.2, p_artaudio 9.2) are checked once music.py writes them.
const TRACKS := {"title": [24.0, 32.0], "chapel": [48.0, 64.0], "boss": [32.0, 48.0],
		"story": [60.0, 68.0], "hush": [30.0, 48.0], "dawn": [48.0, 66.0], "tallow": [52.0, 66.0],
		"snuffer": [36.0, 56.0],
		"orchard": [44.0, 70.0], "carillon": [55.0, 86.0], "sanctum": [58.0, 90.0], "hushdeep": [64.0, 100.0],
		"rootmother": [34.0, 60.0], "tinker": [46.0, 72.0], "saint": [34.0, 60.0], "lullaby": [16.0, 80.0],
		"secret": [36.0, 60.0], "trial": [20.0, 40.0], "evenbell": [80.0, 126.0], "lament": [38.0, 60.0],
		"amb_orchard": [8.0, 20.0], "amb_carillon": [8.0, 20.0], "amb_sanctum": [8.0, 20.0], "amb_hushdeep": [8.0, 20.0]}
const V2_TRACKS := ["title", "chapel", "boss", "story", "hush", "dawn", "tallow", "snuffer"]
# Each stem's (and premix's) loop: every stem of a set the same length.
const STEM_LOOPS := {"hush_final": [60.0, 68.0], "descent": [54.0, 62.0]}
# Drums and impacts whose body must sit where a phone speaker plays.
const THUMPS := ["land", "bump", "stomp", "enemy_hit", "slash_hit", "block_break", "spikes",
		"boss_slam", "boss_hit", "boss_die", "relic_legendary", "bell", "clear",
		"guard_block", "maul_hit", "peal", "knife_hit", "shield_clang", "bash", "rubble", "flare_burst",
		"mimic_chomp", "dripkin_splat", "snuffer_slam", "brazier_snuff", "toll_dead", "level_up",
		"guard_break", "clank", "finisher"]
# Everything added for v2 (the rest are v1's).
const NEW := ["talk", "talk_low", "talk_breath", "whoosh", "crit", "guard_block", "perfect_guard", "rush",
		"maul_hit", "peal", "anvil_drop", "spark", "flare_charge", "flare_burst", "knife_throw", "knife_hit",
		"smoke_step", "backstab", "wisp_call", "toll_dead", "grave_step", "level_up", "flask", "item_drop",
		"equip", "salvage", "pool_reclaim", "bank", "heartbeat", "chain_step", "arrow_draw", "arrow_fly",
		"parry", "shield_clang", "bash", "wing_sip", "wing_pop", "drip", "douse", "splash", "dripkin_splat",
		"mimic_snore", "mimic_chomp", "waxfall", "lantern_light", "rubble", "snuffer_whisper",
		"snuffer_slam", "snuffer_scream", "curdle", "brazier_snuff",
		# the names the callings' kits play (kits/*.gd)
		"guard_up", "finisher", "guard_break", "flare_throw", "fizzle", "clank", "knell", "mote", "wisp_pop"]
# Every speaker's voice in the story (story.gd) and the callings' (classes.gd).
const VOICES := [1.6, 0.85, 1.25, 0.5, 0.7, 1.2, 1.45, 1.3, 0.95, 1.05]
# v3's tells (spec 12.3): sounds that announce a timed threat. Each sounds
# for at least 0.35 s, with at least 40% of its energy in 500 Hz-3 kHz.
const TELLS := ["vine_creak", "spore_swell", "dig_rustle", "weepcap_inhale", "hound_howl", "hound_growl", "creep_rattle",
		"root_creak", "rootmother_dig", "rootmother_breath", "thorn_crown",
		"icicle_tell", "wind_up", "gear_catch", "ice_creak", "owl_hoot", "tinker_windup", "tinker_stop", "midnight_chimes",
		"gust_tell", "glass_tink", "gust_inhale", "prism_hum", "prism_lock", "glass_shing", "saint_charge", "beam_lock",
		"saint_rose", "gale", "saint_choir", "dawnglass_off",
		"float_sink", "still_crack", "grasp_hiss", "stitch_snap", "gulp_inhale", "echo_whisper", "lake_still", "hush_still",
		"inhale_roar", "gaze_lock", "deep_quiet", "hush_silence"]
# Tells that aren't timed to a threat: a float sinks at its own pace, and
# Midnight's chimes run alongside its icicles rather than before them.
const UNTIMED := ["float_sink", "midnight_chimes"]
# Tells that warn with their onset, loudest early, played whole from the
# tell's start (no TELL_AT: trimming would cut off the warning).
const ONSET := ["hound_howl", "hound_growl", "owl_hoot", "tinker_windup", "prism_lock", "beam_lock", "saint_choir",
		"gaze_lock", "lake_still"]
# Tells whose sound runs on into the move they announce (the rain, the gust,
# the pull): louder after their TELL_AT, on purpose.
const TELL_THEN := ["thorn_crown", "gale", "inhale_roar"]
# The features' tells and the knob each is cut for: [script, knob] (its Dusk
# value), [script, knob, minus] (a knob less a const: the fray window), or
# [script, const].
const KNOBBED := {"spore_swell": ["features/orchard.gd", "pod_tell"],
		"vine_creak": ["features/orchard.gd", "rotten_hold", "FRAY"], "gust_tell": ["features/glass.gd", "gust_tell"],
		"dawnglass_off": ["features/glass.gd", "DAWN_FLICKER"], "icicle_tell": ["features/clockwork.gd", "icicle_tell"],
		"grasp_hiss": ["features/deep.gd", "grasp_tell"], "still_crack": ["features/deep.gd", "still_tell"]}
# Off the scale on purpose: the Tinker's wrong hour, the decoy's tritone, the
# Omens' sour notes, and the Lull, whose F# is the lullaby's D major (spec 6.6).
const SOUR := ["wrong_hour", "bloom_decoy_puff", "omen_glass_break", "omen_spores", "lull"]
# Tells that build: louder at their end than their start (a creak tightening,
# a breath drawn in, a whistle rising).
const RISING := ["vine_creak", "root_creak", "ice_creak", "creep_rattle", "wind_up", "weepcap_inhale", "rootmother_breath",
		"gust_tell", "gust_inhale", "gulp_inhale", "stitch_snap", "saint_charge", "prism_hum", "still_crack", "spore_swell",
		"dig_rustle", "rootmother_dig", "hush_silence"]
# v3's impacts, whose body must sit where a phone speaker plays (as THUMPS).
const V3_THUMPS := ["root_burst", "hound_bite", "seed_splat", "root_pop", "gear_clunk", "clock_tock", "heavy_step",
		"tinker_step", "spring_boing", "icicle_shatter", "ice_shatter", "glass_shatter", "glass_break", "glass_clang",
		"snuff_slam", "grasp_rise", "coil_splash", "choke", "choke_spit", "wax_cast", "seal_stamp"]
# Tonal v3 sounds: each lands on a note of D minor pentatonic (D F G A C)...
const IN_KEY := ["glowfruit_drop", "skull_lantern", "bloom_open", "bloom_close", "secret_hum", "secret_found",
		"clock_strike", "clock_chime", "icicle_tell", "rime_freeze", "dawnglass_on", "dawnglass_off", "prism_lamp",
		"candle_light", "buoy_light", "buoy_toll", "flame_freed", "trial_go", "glimmer", "cart_bell", "cosmetic_unlock",
		"candlemark", "descend", "hushing", "midnight_chimes", "tinker_open", "saint_choir", "prism_hum", "shard_hum",
		"beam_lock", "gaze_lock", "trial_fail", "wax_cast", "tinker_die"]
# ...and these, which callers pitch by Sfx.note(i) or voice_note, are on D.
const ON_D := ["talk_wood", "talk_tick", "talk_glass", "finale_ring", "trial_tick", "candle_lit", "depth_mark", "glass_crack",
		"ice_crack", "chime_hour", "glass_chime", "anvil", "medal", "record", "bell_peal_sunken", "rush_bell", "silver_bell",
		"glass_step", "give"]
# Heard over and over, so they sit under a sword swing.
const V3_QUIET := ["vine_climb", "glass_step", "lake_step", "tick", "tick_step", "gear_tick", "owl_tick", "bone_skitter",
		"ice_slide", "ice_squeak", "belt_run", "pennant_flap", "shard_hum", "secret_hum"]
# The big moments: well over a sword's hit.
const V3_BIG := ["rootmother_die", "rootmother_roar", "tinker_die", "tinker_overwind", "saint_die", "bell_peal_sunken",
		"snuff_slam", "hush_eye_open", "lull", "pull", "silver_bell", "rush_bell", "buoy_toll"]
const TEST_WAV := "user://test_sfx_music.wav"
const TEST_CACHE := "user://test_sfx_cache.bin"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	# A script error that aborts this coroutine would leave the tree idling
	# forever; fail the suite instead of hanging it.
	create_timer(420.0).timeout.connect(func() -> void:
		printerr("FAIL: test_sfx timed out")
		quit(1))
	# The tests flip the real settings; put the file back the way it was.
	var had_settings := FileAccess.file_exists(SfxLib.SETTINGS_PATH)
	var settings_text := FileAccess.get_file_as_string(SfxLib.SETTINGS_PATH) if had_settings else ""
	_test_render()
	_test_character()
	_test_v3_recipes()
	_test_order()
	_test_tables()
	_test_spike()
	var sfx = root.get_node_or_null("Sfx")
	_check(sfx != null, "Sfx is an autoload")
	if sfx == null:
		quit(1)
		return
	var early = SfxLib.new()
	_check(early.play("click") == null, "playing before the tree is up is a quiet no-op")
	# Wait for its first sound so the free lands while it is mid-render.
	while _rendered(early) == 0:
		OS.delay_msec(1)
	var t0 := Time.get_ticks_msec()
	early.free()
	_check(not is_instance_valid(early) and Time.get_ticks_msec() - t0 < 1500,
			"Sfx can be freed mid-render without waiting out the whole render (%d ms)" % (Time.get_ticks_msec() - t0))
	sfx.muted = false
	sfx.music_muted = false
	sfx.set_volume(1.0)
	await process_frame   # the root joins the tree once it is ticking
	var start := Time.get_ticks_msec()
	while not sfx.is_loaded() and Time.get_ticks_msec() - start < 60000:
		await process_frame
	_check(sfx.is_loaded(), "every sound is rendered in the background soon after boot (%.1f s)"
			% ((Time.get_ticks_msec() - start) / 1000.0))
	var limited := false
	for i in range(AudioServer.get_bus_effect_count(0)):
		limited = limited or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	_check(limited, "the master bus has a limiter against voices piling up")
	await _test_cache(sfx)
	_test_play(sfx)
	_test_release(sfx)
	_test_gain(sfx)
	_test_tell(sfx)
	_test_settings(sfx)
	_test_music_files()
	await _test_music(sfx)
	_test_lowpass(sfx)
	_test_buses(sfx)
	_test_banks(sfx)
	_test_hush(sfx)
	_test_stems(sfx)
	_test_premix(sfx)
	_test_tape(sfx)
	_test_seek(sfx)
	_test_ambience(sfx)
	_test_track_fallbacks(sfx)
	sfx.stop_music(0.0)
	sfx.stop_ambience(0.0)
	sfx.set_hush(0.0)
	sfx._aim_hush(0.0)
	sfx._tick_music(0.0)
	sfx.muted = false
	sfx.music_muted = false
	sfx.set_volume(1.0)
	if had_settings:
		FileAccess.open(SfxLib.SETTINGS_PATH, FileAccess.WRITE).store_string(settings_text)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SfxLib.SETTINGS_PATH))
	print("%d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: %s" % label)
	else:
		_failed += 1
		printerr("FAIL: %s" % label)


# ---------------------------------------------------------------- rendering

func _renderable() -> Array:
	## [sound, takes, render] for every sound that has a recipe: the core's
	## and every bank file's.
	var out := []
	for b in SfxLib.bank_list(SfxLib):
		for sound in b["names"]:
			out.append([sound, int((b["takes"] as Dictionary).get(sound, 1)), b["render"]])
	return out


func _test_render() -> void:
	var ceiling := db_to_linear(-2.0) + 0.0001
	var loud := {}
	for entry in _renderable():
		var sound: String = entry[0]
		var render: Callable = entry[2]
		for take in range(int(entry[1])):
			var label: String = sound if take == 0 else "%s (take %d)" % [sound, take + 1]
			var s: PackedFloat32Array = render.call(sound, take)
			if s.size() < 2:
				_check(false, "%s renders samples" % label)
				continue
			var secs := s.size() / float(SfxLib.RATE)
			var peak := 0.0
			var sum := 0.0
			var finite := true
			for v in s:
				finite = finite and is_finite(v)
				peak = maxf(peak, absf(v))
				sum += v
			_check(finite, "%s is all finite numbers" % label)
			_check(peak > 0.05 and peak <= ceiling, "%s is audible and peaks at or under -2 dBFS (%.1f dB)" % [label, linear_to_db(peak)])
			_check(absf(sum / s.size()) < 0.001, "%s has no DC offset" % label)
			_check(absf(s[0]) < 0.001 and absf(s[-1]) < 0.001 and absf(s[1] - s[0]) < 0.01 and absf(s[-1] - s[-2]) < 0.01,
					"%s starts and ends at silence, without a click" % label)
			var spike := _spike_ratio(s)
			_check(spike < 10.0, "%s has no click inside it (sharpest bend %.1fx its surroundings)" % [label, spike])
			_check(secs >= 0.03 and secs <= 3.5, "%s lasts %.2f s" % [label, secs])
			var wav: AudioStreamWAV = SfxLib.to_wav(s)
			var top := 0
			for i in range(0, wav.data.size(), 2):
				top = maxi(top, absi(wav.data.decode_s16(i)))
			_check(wav.format == AudioStreamWAV.FORMAT_16_BITS and not wav.stereo and wav.mix_rate == SfxLib.RATE
					and wav.data.size() == s.size() * 2 and top > 0 and top < 32767, "%s is 16-bit mono PCM that never clips" % label)
			if take == 0:
				loud[sound] = SfxLib.loudness_db(s)
				if sound in THUMPS:
					var share := _share_above(s, 250.0)
					_check(share >= 0.55, "%s keeps its body in the mids for a phone speaker (%d%% above 250 Hz)" % [sound, roundi(share * 100)])
	_check(loud.size() == _renderable().size() and _renderable().size() >= SfxLib.CORE.size(),
			"every sound with a recipe renders (%d: the core's %d and the banks')" % [loud.size(), SfxLib.CORE.size()])
	var missing := NEW.filter(func(n): return not SfxLib.CORE.has(n))
	_check(missing.is_empty(), "all %d v2 sounds are in the core %s" % [NEW.size(), missing])
	var tiers := ["relic_common", "relic_magic", "relic_rare", "relic_legendary"]
	var rising := true
	for i in range(1, tiers.size()):
		rising = rising and loud[tiers[i]] > loud[tiers[i - 1]] + 1.0
	_check(rising, "rarer relics sound louder: %s" % ", ".join(tiers.map(func(t): return "%.1f" % loud[t])))
	var quiet := maxf(loud["step"], maxf(loud["land"], loud["ember"]))
	var big := minf(loud["bell"], minf(loud["clear"], loud["relic_legendary"]))
	_check(big > quiet + 6.0, "the bell, clear and legendary are much louder than step, land and ember")
	var quietest := true
	for sound in loud:
		quietest = quietest and (sound == "step" or loud[sound] > loud["step"])
	_check(quietest, "the footstep is the quietest sound (%.1f dB)" % loud["step"])
	var bell := SfxLib.render("bell")
	var clear := SfxLib.render("clear")
	_check(bell.size() >= 3 * SfxLib.RATE and clear.size() >= 2 * SfxLib.RATE, "the bell tolls for 3 s and the fanfare lasts 2")
	_check(SfxLib.render("click") == SfxLib.render("click"), "rendering is deterministic")
	_check(SfxLib.render("step", 0) != SfxLib.render("step", 1), "a sound's takes differ")
	# How the new sounds sit against each other.
	_check(loud["crit"] < loud["slash_hit"] - 1.0 and loud["crit"] < loud["knife_hit"] - 0.5,
			"the crit tick sits under the hits it rides on (%.1f dB)" % loud["crit"])
	_check(loud["perfect_guard"] > loud["guard_block"] + 2.0, "a Perfect Guard rings out over a plain block")
	_check(loud["backstab"] > loud["knife_hit"] + 3.0, "a backstab stings louder than a knife landing")
	for s in ["level_up", "peal", "snuffer_slam", "snuffer_scream"]:
		_check(loud[s] > loud["slash_hit"] + 3.0, "%s is one of the big moments (%.1f dB)" % [s, loud[s]])
	for s in ["drip", "wing_sip", "mimic_snore", "heartbeat", "talk_breath", "bank", "mote", "guard_up"]:
		_check(loud[s] < loud["slash"], "%s sits in the background, under a sword swing (%.1f dB)" % [s, loud[s]])
	_check(loud["guard_break"] > loud["guard_block"] + 2.0, "a broken guard lands harder than a block")
	_check(loud["finisher"] > loud["slash"] + 2.0, "the finisher rings out over the swing it rides on")
	_check(loud["flare_throw"] < loud["flare_burst"] - 3.0, "the flare's toss is small beside its burst")
	_check(loud["fizzle"] < loud["flare_throw"] and loud["fizzle"] < loud["knell"] and loud["clank"] < loud["peal"] - 6.0,
			"a dud (fizzle, clank) is quieter than the casts it stands in for")
	var hb := _share_above(SfxLib.render("heartbeat"), 250.0)
	_check(hb >= 0.4, "the heartbeat's thump still reaches a phone speaker (%d%% above 250 Hz)" % roundi(hb * 100))


# ---------------------------------------------------------------- character

func _test_character() -> void:
	## The new sounds are what they were made to be, measured: lengths the
	## story engine counts on, pitches that stay in key, and shapes.
	var lengths := {"talk": 0.035, "talk_low": 0.06, "talk_breath": 0.07, "whoosh": 0.25}
	for s in lengths:
		var secs := SfxLib.render(s).size() / float(SfxLib.RATE)
		_check(absf(secs - float(lengths[s])) < 0.002, "%s lasts %d ms" % [s, roundi(secs * 1000.0)])
	for s in ["talk", "talk_low", "chain_step", "item_drop"]:
		var pc := _pitch_class(SfxLib.render(s))
		_check(pc == 2, "%s is centred on D, so note(i) keeps it in key (pitch class %d)" % [s, pc])
	var talk := _tonality(SfxLib.render("talk"))
	var breath := _tonality(SfxLib.render("talk_breath"))
	_check(talk > 0.6 and breath < 0.45, "talk is a pitched pluck (%.2f), talk_breath has no pitch at all (%.2f)" % [talk, breath])
	var crit := SfxLib.render("crit")
	_check(crit.size() <= 0.15 * SfxLib.RATE and _bright(crit) > 2500.0,
			"crit is a short, glassy tick (%.2f s, %d Hz)" % [crit.size() / float(SfxLib.RATE), roundi(_bright(crit))])
	_check(_bright(SfxLib.render("perfect_guard")) > 1.8 * _bright(SfxLib.render("guard_block")),
			"a Perfect Guard is a bright ping; a block is a dull thunk")
	var hush := _share_above2(SfxLib.render("snuffer_whisper"), 1500.0)
	_check(hush > 0.7, "the Snuffer's \"shhh\" is all breath up high (%d%% above 1.5 kHz)" % roundi(hush * 100))
	# The flare charge swells and climbs over its first half second.
	var fc := SfxLib.render("flare_charge")
	var early := _span(fc, 0.0, 0.15)
	var full := _span(fc, 0.45, 0.6)
	_check(_rms_db(full) > _rms_db(early) + 6.0 and _bright(full) > _bright(early) * 1.3,
			"flare_charge rises: %.0f to %.0f dB, %d to %d Hz" % [_rms_db(early), _rms_db(full), roundi(_bright(early)), roundi(_bright(full))])
	_check(fc.size() >= 1.2 * SfxLib.RATE, "flare_charge holds on past a full charge, until it is released")
	# The heart: two beats, a quiet gap between them.
	var heart := SfxLib.render("heartbeat")
	var lub := _rms_db(_span(heart, 0.0, 0.04))
	var gap := _rms_db(_span(heart, 0.11, 0.15))
	var dub := _rms_db(_span(heart, 0.17, 0.21))
	_check(lub > gap + 10.0 and dub > gap + 8.0 and lub > dub, "heartbeat goes lub (%.0f dB), gap (%.0f), dub (%.0f)" % [lub, gap, dub])
	# Tells fit inside the windows they announce.
	_check(SfxLib.render("arrow_draw").size() <= 0.66 * SfxLib.RATE, "a Bonebow's draw fits its 0.65 s tell")
	var draw := SfxLib.render("arrow_draw")
	_check(_rms_db(_span(draw, 0.42, 0.52)) > _rms_db(_span(draw, 0.0, 0.1)) + 3.0, "the draw creaks tighter toward the loose")
	# The kits' tonal sounds stay in key: the handbell on A, the motes and
	# the spent wisp on notes of D minor pentatonic.
	_check(_pitch_class(SfxLib.render("knell")) == 9, "knell is a handbell on A (pitch class %d)" % _pitch_class(SfxLib.render("knell")))
	_check(_bright(SfxLib.render("knell")) > _bright(SfxLib.render("toll_dead")), "knell is small and bright beside toll_dead")
	var motes := []
	for take in range(int(SfxLib.TAKES["mote"])):
		motes.append(_pitch_class(SfxLib.render("mote", take)))
	var in_scale := motes.all(func(pc): return pc in [2, 5, 7, 9, 0])
	_check(in_scale and motes.size() == 3 and motes[0] != motes[1] and motes[1] != motes[2],
			"each mote is a different note of the scale (pitch classes %s)" % [motes])
	_check(_pitch_class(SfxLib.render("wisp_pop")) in [2, 9], "wisp_pop's chime falls on D and A")
	var fizz := SfxLib.render("fizzle")
	_check(fizz.size() <= 0.3 * SfxLib.RATE and _bright(_span(fizz, 0.1, 0.2)) < _bright(_span(fizz, 0.0, 0.05)),
			"fizzle is short and sinks as it dies")
	var brk := SfxLib.render("guard_break")
	_check(_rms_db(_span(brk, 0.2, 0.3)) > _rms_db(_span(SfxLib.render("guard_block"), 0.2, 0.3)) + 3.0,
			"a broken guard rattles on after a block would have stopped")
	# Peal is a bell, not just a thud: it still rings a second later.
	var peal := SfxLib.render("peal")
	_check(_rms_db(_span(peal, 1.0, 1.2)) > _rms_db(_span(peal, 0.0, 0.2)) - 24.0, "peal's bell rings on after the slam")


# ---------------------------------------------------------------- v3: the recipes

func _v3_render() -> Dictionary:
	## sound -> [its bank's render, its takes] for every sound a bank file makes.
	var out := {}
	for b in SfxLib.bank_list(SfxLib).slice(1):
		for n in b["names"]:
			out[n] = [b["render"], int((b["takes"] as Dictionary).get(n, 1))]
	return out


func _sounding(s: PackedFloat32Array) -> float:
	## How long a sound is actually heard: from the first 20 ms window within
	## 30 dB of its loudest to the last, in seconds (padding doesn't count).
	var win := SfxLib.RATE / 50
	var hop := win / 2
	var level := []
	var top := 0.0
	for i in range(0, s.size() - win, hop):
		var e := 0.0
		for j in range(i, i + win):
			e += s[j] * s[j]
		level.append(e)
		top = maxf(top, e)
	var first := -1
	var last := -1
	for k in range(level.size()):
		if level[k] >= top * 0.001:
			first = k if first < 0 else first
			last = k
	return 0.0 if first < 0 else ((last - first) * hop + win) / float(SfxLib.RATE)


func _test_v3_recipes() -> void:
	var made := _v3_render()
	var missing := SfxLib.V3_NAMES.filter(func(n): return not made.has(n))
	_check(missing.is_empty() and made.size() == SfxLib.V3_NAMES.size(),
			"every one of the %d v3 names has its own recipe in its bank %s" % [SfxLib.V3_NAMES.size(), missing])
	var got := {}   # each sound's take 0, rendered once
	var sound := func(n: String, take := 0) -> PackedFloat32Array:
		if take == 0 and got.has(n):
			return got[n]
		var r: PackedFloat32Array = (made[n][0] as Callable).call(n, take) if made.has(n) else PackedFloat32Array([0.0, 0.0])
		if take == 0:
			got[n] = r
		return r
	var secs := func(n: String) -> float:
		return (sound.call(n) as PackedFloat32Array).size() / float(SfxLib.RATE)
	var loud := {}
	for n in made:
		loud[n] = SfxLib.loudness_db(sound.call(n))
	var slash := SfxLib.loudness_db(SfxLib.render("slash"))
	var slash_hit := SfxLib.loudness_db(SfxLib.render("slash_hit"))
	# The tells: long enough to react to, and where a phone speaker plays.
	for n in TELLS:
		var s: PackedFloat32Array = sound.call(n)
		var heard := _sounding(s)
		var mids := _share_above2(s, 500.0) - _share_above2(s, 3000.0)
		_check(heard >= 0.35 and mids >= 0.4, "tell %s sounds for %.2f s with %d%% of it in 500 Hz-3 kHz" % [n, heard, roundi(mids * 100)])
		_check(float(loud.get(n, -99.0)) >= slash, "tell %s is heard over a fight (%.1f dB, a swing is %.1f)" % [n, loud.get(n, -99.0), slash])
	for n in RISING:
		var s: PackedFloat32Array = sound.call(n)
		var third := s.size() / 3
		var early := _rms_db(s.slice(0, third))
		var late := _rms_db(s.slice(2 * third - third / 2, 2 * third + third / 2))
		_check(late > early + 3.0, "%s builds toward its end (%.0f dB to %.0f)" % [n, early, late])
	# When their threats land: every tell that builds has a TELL_AT, isn't
	# jittered, peaks in the back half before it (so a tell half as long,
	# trimmed, keeps its climax) or runs on into its move, and is cut for the
	# knob of the feature it announces; one that warns with its onset is
	# loudest early.
	var tell_at := {}
	var jit := {}
	for b in SfxLib.bank_list(SfxLib).slice(1):
		tell_at.merge(b.get("tell_at", {}))
		jit.merge(b["jitter"])
	var untimed := TELLS.filter(func(n): return not tell_at.has(n) and not UNTIMED.has(n) and not ONSET.has(n))
	var stray := tell_at.keys().filter(func(n): return not TELLS.has(n) or ONSET.has(n))
	_check(untimed.is_empty() and stray.is_empty(), "every building tell has a TELL_AT, and only they do %s %s" % [untimed, stray])
	for n in ONSET:
		var s: PackedFloat32Array = sound.call(n)
		var peak := _loudest_at(s)
		_check(peak <= 0.6 * s.size() / float(SfxLib.RATE), "%s warns with its onset (loudest at %.2f s), so it plays whole" % [n, peak])
	var jittered := tell_at.keys().filter(func(n): return jit.has(n))
	_check(jittered.is_empty(), "no tell is jittered: its length is its tell %s" % [jittered])
	for n in tell_at:
		var s: PackedFloat32Array = sound.call(n)
		var at := float(tell_at[n])
		if TELL_THEN.has(n):
			_check(s.size() / float(SfxLib.RATE) > at + 0.5, "%s runs on past its tell (%.2f s) into the move it announces" % [n, at])
		elif not SfxLib.SILENCES.has(n):   # a silence's swell has its own check, below
			var peak := _loudest_at(s)
			_check(peak <= at + 0.02 and peak >= 0.5 * at, "%s peaks at %.2f s, in the back half before its threat lands at %.2f"
					% [n, peak, at])
	for n in KNOBBED:
		var k: Array = KNOBBED[n]
		var path := "res://scripts/" + str(k[0])
		if not ResourceLoader.exists(path):
			print("NOTE: no %s yet, so %s's knob isn't checked" % [path, n])
			continue
		var consts := (load(path) as Script).get_script_constant_map()
		var knobs: Dictionary = consts.get("DIFF_KNOBS", {})
		var want := -1.0
		if knobs.has(k[1]):
			var row = knobs[k[1]]
			want = float((row as Dictionary).get("dusk", -1.0)) if row is Dictionary else float(row)
		elif consts.has(k[1]):
			want = float(consts[k[1]])
		if k.size() > 2 and want >= 0.0:
			want -= float(consts.get(k[2], 0.0))
		if want < 0.0:
			print("NOTE: %s has no %s, so %s's knob isn't checked" % [path, k[1], n])
			continue
		_check(absf(float(tell_at.get(n, 0.0)) - want) <= 0.1, "%s is cut for %s's %s (TELL_AT %.2f s, Dusk's %.2f)"
				% [n, str(k[0]).get_file(), k[1], float(tell_at.get(n, 0.0)), want])
	# In key, all of them: no recipe's strongest note is off the scale, over
	# the whole sound or held at its loudest, but the sour ones; and no tonal
	# sound is jittered, since a random pitch lands between two notes.
	var scale := [0, 2, 5, 7, 9]
	var off := []
	var tonal := []
	for n in made:
		var s: PackedFloat32Array = sound.call(n)
		var peak := _loudest_at(s)
		var whole := _top_class(_class_shares(s))
		var held := _top_class(_class_shares(_span(s, maxf(peak - 0.025, 0.0), peak + 0.125)))
		var sour: bool = (not scale.has(whole[0]) and whole[1] >= 0.4) or (not scale.has(held[0]) and held[1] >= 0.6)
		if sour and not SOUR.has(n):
			off.append("%s %d (%d%%, %d at its loudest %d%%)" % [n, whole[0], roundi(whole[1] * 100), held[0], roundi(held[1] * 100)])
		if jit.has(n) and (whole[1] >= 0.4 or held[1] >= 0.6):
			tonal.append(n)
	_check(off.is_empty(), "every v3 recipe is on D minor pentatonic, bar the sour ones %s" % [off])
	_check(tonal.is_empty(), "no tonal v3 sound is jittered %s" % [tonal])
	var medal := _class_shares(sound.call("medal"))
	var rest := 1.0 - medal[2] - medal[9]
	_check(rest < 0.1, "medal holds only D and A, so a C, D or G medal stays in key (%d%% else)" % roundi(rest * 100))
	# In key: the tonal ones on the scale, the pitched ones on D.
	for n in IN_KEY:
		var pc := _pitch_class(sound.call(n))
		_check(pc in [2, 5, 7, 9, 0], "%s is on a note of D minor pentatonic (pitch class %d)" % [n, pc])
	for n in ON_D:
		var pc := _pitch_class(sound.call(n))
		_check(pc == 2, "%s is centred on D, so its callers' note(i) stays in key (pitch class %d)" % [n, pc])
	var lull: PackedFloat32Array = sound.call("lull")
	var tune := []
	for seg in [[0.02, 0.45], [0.57, 1.0], [1.12, 1.6]]:
		tune.append(_pitch_class(_span(lull, seg[0], seg[1])))
	_check(tune == [9, 6, 2] and absf(secs.call("lull") - 2.25) < 0.2,
			"the Lull is A, F#, D, 0.55 s apart, about 2.2 s (%s, %.2f s)" % [tune, secs.call("lull")])
	var up := _pitch_class(_span(sound.call("finale_ring"), 0.0, 0.8))
	_check(up == 2, "finale_ring is on D, so note(0) to note(5) ring D3 F3 G3 A3 C4 D4")
	# The story's shapes.
	var blips := {"talk_wood": 0.06, "talk_tick": 0.035, "talk_glass": 0.05}
	for n in blips:
		_check(absf(secs.call(n) - float(blips[n])) < 0.002, "%s lasts %d ms" % [n, roundi(secs.call(n) * 1000.0)])
	var give: PackedFloat32Array = sound.call("give")
	_check(absf(secs.call("give") - 0.5) < 0.01 and _bright(_span(give, 0.0, 0.15)) > _bright(_span(give, 0.35, 0.5)),
			"give is half a second, running down (played again every 0.5 s while held)")
	var pull: PackedFloat32Array = sound.call("pull")
	_check(absf(secs.call("pull") - 1.4) < 0.01 and _bright(_span(pull, 0.1, 0.6)) > 1.3 * _bright(_span(pull, 0.8, 1.3)),
			"pull is 1.4 s, falling as it goes (%d Hz to %d)" % [roundi(_bright(_span(pull, 0.1, 0.6))), roundi(_bright(_span(pull, 0.8, 1.3)))])
	var choke: PackedFloat32Array = sound.call("bell_choke")
	_check(_rms_db(_span(choke, 0.36, 0.6)) < _rms_db(_span(choke, 0.0, 0.1)) - 30.0,
			"bell_choke's bell is damped to nothing within 0.3 s")
	_check(absf(secs.call("clock_strike") - 2.0) < 0.05 and secs.call("anvil") <= 0.25 and _bright(sound.call("anvil")) > 1500.0,
			"clock_strike rings 2 s; anvil is a bright tap under 0.25 s")
	for n in SfxLib.SILENCES:
		var s: PackedFloat32Array = sound.call(n)
		var sil: Array = SfxLib.SILENCES[n]
		var tail := 0.0
		for v in _span(s, float(sil[0]) + 0.03, s.size() / float(SfxLib.RATE)):
			tail = maxf(tail, absf(v))
		var swell := _sounding(_span(s, 0.0, float(sil[0])))
		_check(tail < 0.002 and swell >= SfxLib.MIN_TELL and absf(float(sil[0]) + float(sil[1]) - float(tell_at.get(n, 0.0))) < 0.001,
				"%s swells %.2f s, then is truly silent where SILENCES starts its silence, held until its threat lands (%.4f)"
				% [n, swell, tail])
	_check(absf(secs.call("hush_silence") - 1.2) < 0.01 and is_equal_approx(float(SfxLib.SILENCES["hush_silence"][1]), 0.3),
			"hush_silence is the Snuff's 1.2 s tell: all sound out for the 0.3 s before the hand lands")
	for n in ["deep_quiet", "hush_still", "lake_still"]:
		var s: PackedFloat32Array = sound.call(n)
		var end := _rms_db(_span(s, s.size() / float(SfxLib.RATE) - 0.06, s.size() / float(SfxLib.RATE)))
		_check(end < float(loud[n]) - 30.0, "%s ends in quiet (its last 60 ms %.0f dB under it)" % [n, float(loud[n]) - end])
	_check(float(loud["secret_hum"]) <= -22.0 and secs.call("secret_hum") <= 2.0,
			"the secret hum is faint and over before it repeats (every 3 s): %.1f dB, %.1f s" % [loud["secret_hum"], secs.call("secret_hum")])
	# Loud and quiet.
	for n in V3_QUIET:
		_check(float(loud[n]) < slash - 1.0, "%s sits under a sword swing (%.1f dB)" % [n, loud[n]])
	for n in V3_BIG:
		_check(float(loud[n]) > slash_hit + 3.0, "%s is one of the big moments (%.1f dB)" % [n, loud[n]])
	for n in V3_THUMPS:
		var share := _share_above(sound.call(n), 250.0)
		_check(share >= 0.55, "%s keeps its body in the mids for a phone speaker (%d%% above 250 Hz)" % [n, roundi(share * 100)])
	# Takes, determinism, order and cost.
	for n in ["vine_climb", "glass_step", "lake_step", "bone_skitter", "heavy_step", "tinker_step"]:
		var a: PackedFloat32Array = sound.call(n, 0)
		var b: PackedFloat32Array = sound.call(n, 1)
		_check(int(made[n][1]) >= 2 and a != b and a == sound.call(n, 0), "%s has %d takes, each different, each the same every boot" % [n, made[n][1]])
	var story: Array = SfxLib.load_bank("story")["names"]
	_check(story.slice(0, 6) == ["talk_wood", "talk_tick", "talk_glass", "pull", "give", "lull"] and SfxLib.BANK_ORDER[0] == "story"
			and SfxLib.BANK_ORDER[1] == "w3", "the story bank renders first, its blips, pull, give and lull first; World 3's next")
	var t0 := Time.get_ticks_usec()
	for n in story:
		SfxLib.to_wav(sound.call(n))
	var story_ms := (Time.get_ticks_usec() - t0) / 1000.0
	_check(story_ms < 2000.0, "the story bank renders in %d ms" % roundi(story_ms))


func _test_order() -> void:
	## The story's voices render first (after the menus), so an intro that
	## starts the moment the game boots still has its blips; the long bells
	## and fanfares come last.
	var names: Array = SfxLib.CORE
	var first_big := 1000
	for s in ["bell", "relic_legendary", "clear", "boss_die", "level_up", "peal", "snuffer_scream"]:
		first_big = mini(first_big, names.find(s))
	var early := true
	for s in ["talk", "talk_low", "talk_breath", "whoosh"]:
		early = early and names.find(s) >= 0 and names.find(s) < 10
	_check(early, "talk, talk_low, talk_breath and whoosh are among the first ten rendered")
	var combat := true
	for s in ["step", "jump", "slash", "slash_hit", "stomp", "hurt", "crit", "guard_block", "spark", "knife_throw", "maul_hit"]:
		combat = combat and names.find(s) < first_big - 30
	_check(combat, "the sounds of a fight's first seconds render well before the long bells")
	var t0 := Time.get_ticks_usec()
	for s in names.slice(0, names.find("whoosh") + 1):
		for take in range(int(SfxLib.TAKES.get(s, 1))):
			SfxLib.to_wav(SfxLib.render(s, take))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_check(ms < 300.0, "everything up to the story's voices renders in %d ms" % roundi(ms))


func _spike_ratio(s: PackedFloat32Array) -> float:
	## How far the sharpest bend in the wave (its second difference) stands
	## above the bends around it (their RMS over +-5 ms). A click is a lone
	## spike, 10x and up; attacks, crackle and noise stay well under 8.
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


func _goertzel(s: PackedFloat32Array, hz: float) -> float:
	## The power of one frequency in a Hann-windowed sound.
	var w := TAU * hz / SfxLib.RATE
	var c := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	var n := s.size()
	for i in range(n):
		var x := s[i] * (0.5 - 0.5 * cos(TAU * i / n))
		var s0 := x + c * s1 - s2
		s2 = s1
		s1 = s0
	return s1 * s1 + s2 * s2 - c * s1 * s2


func _loudest_at(s: PackedFloat32Array) -> float:
	## The middle of a sound's loudest 20 ms, in seconds.
	var win := SfxLib.RATE / 50
	var e := 0.0
	var best := -1.0
	var at := 0
	for i in range(s.size()):
		e += s[i] * s[i]
		if i >= win:
			e -= s[i - win] * s[i - win]
		if i >= win - 1 and e > best:
			best = e
			at = i - win + 1
	return (at + win / 2) / float(SfxLib.RATE)


func _class_shares(s: PackedFloat32Array) -> PackedFloat32Array:
	## Each pitch class's share (0 = C) of the power at the equal-tempered
	## notes D3 to D8, over at most a sound's first 1.2 s, at half the rate
	## (pairs averaged: D8 is still under that Nyquist), Hann-windowed.
	var n := mini(s.size(), int(1.2 * SfxLib.RATE)) / 2
	var x := PackedFloat32Array()
	x.resize(n)
	for i in range(n):
		x[i] = 0.5 * (s[2 * i] + s[2 * i + 1]) * (0.5 - 0.5 * cos(TAU * i / n))
	var power := PackedFloat32Array()
	power.resize(12)
	power.fill(0.0)
	var total := 0.0
	var rate := SfxLib.RATE / 2.0
	for m in range(50, 111):
		var c := 2.0 * cos(TAU * 440.0 * pow(2.0, (m - 69) / 12.0) / rate)
		var s1 := 0.0
		var s2 := 0.0
		for v in x:
			var s0 := v + c * s1 - s2
			s2 = s1
			s1 = s0
		var p := s1 * s1 + s2 * s2 - c * s1 * s2
		power[m % 12] += p
		total += p
	for pc in range(12):
		power[pc] = power[pc] / maxf(total, 1e-30)
	return power


func _top_class(shares: PackedFloat32Array) -> Array:
	## [the pitch class with the most, its share].
	var best := 0
	for pc in range(12):
		best = pc if shares[pc] > shares[best] else best
	return [best, shares[best]]


func _pitch_class(s: PackedFloat32Array) -> int:
	## The pitch class (0 = C, 2 = D, 9 = A) holding the most power across
	## the equal-tempered notes from D3 to D8.
	var power := []
	power.resize(12)
	power.fill(0.0)
	for m in range(50, 111):
		power[m % 12] += _goertzel(s, 440.0 * pow(2.0, (m - 69) / 12.0))
	var best := 0
	for pc in range(12):
		best = pc if power[pc] > power[best] else best
	return best


func _tonality(s: PackedFloat32Array) -> float:
	## The strongest normalized autocorrelation at a lag of one period of
	## 150 Hz to 1.5 kHz: near 1 for a pitched note, low for noise.
	var e := 0.0
	for v in s:
		e += v * v
	var best := 0.0
	for lag in range(SfxLib.RATE / 1500, SfxLib.RATE / 150 + 1):
		var r := 0.0
		for i in range(s.size() - lag):
			r += s[i] * s[i + lag]
		best = maxf(best, r / maxf(e, 1e-20))
	return best


func _bright(s: PackedFloat32Array) -> float:
	## The RMS frequency (see tools/audio/render_sfx.gd): high for bright sounds.
	var e := 0.0
	var d := 0.0
	for i in range(1, s.size()):
		e += s[i] * s[i]
		d += (s[i] - s[i - 1]) * (s[i] - s[i - 1])
	return SfxLib.RATE / TAU * 2.0 * asin(minf(1.0, 0.5 * sqrt(d / maxf(e, 1e-20))))


func _span(s: PackedFloat32Array, from: float, to: float) -> PackedFloat32Array:
	return s.slice(int(from * SfxLib.RATE), int(to * SfxLib.RATE))


func _rms_db(s: PackedFloat32Array) -> float:
	var e := 0.0
	for v in s:
		e += v * v
	return linear_to_db(sqrt(e / maxf(1.0, s.size())) + 1e-9)


func _share_above2(s: PackedFloat32Array, hz: float) -> float:
	## The fraction of the energy above hz, through a 2nd-order Butterworth
	## high-pass (flat above its cutoff, unlike the one-pole in _share_above,
	## which reads bright sounds low when hz is a sizable part of the rate).
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


func _share_above(s: PackedFloat32Array, hz: float) -> float:
	## The fraction of a sound's energy above hz (a one-pole high-pass).
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


# ---------------------------------------------------------------- playing

func _test_play(sfx) -> void:
	_check(is_equal_approx(sfx.note(0), 1.0) and is_equal_approx(sfx.note(5), 2.0) and is_equal_approx(sfx.note(10), 4.0),
			"note 0 is the root, 5 the octave, 10 two octaves")
	var rising := true
	for d in range(1, 16):
		rising = rising and sfx.note(d) > sfx.note(d - 1)
	_check(rising, "each note() is higher than the last")
	_check(is_equal_approx(sfx.note(3), pow(2.0, 7.0 / 12.0)), "note 3 is the fifth (D minor pentatonic)")
	_test_in_key(sfx)
	for sound in SfxLib.NAMES:
		var p: AudioStreamPlayer = sfx.play(sound)
		var own: bool = sfx.rendered(sound)
		var want: Array = sfx._streams.get(sound if own else str(SfxLib.FALLBACK.get(sound, "")), [])
		_check(p != null and p.playing and p.stream is AudioStreamWAV and want.has(p.stream),
				"play('%s') starts a voice%s" % [sound, "" if own else " (its fallback, %s)" % SfxLib.FALLBACK.get(sound, "?")])
		if not own:
			_quiet(sfx)
	_quiet(sfx)
	var sel: AudioStreamPlayer = sfx.play("select", sfx.note(3))
	_check(sel != null and is_equal_approx(sel.pitch_scale, sfx.note(3)), "play() takes a pitch")
	var exact: AudioStreamPlayer = sfx.play("step", 1.2)
	_check(exact != null and is_equal_approx(exact.pitch_scale, 1.2), "an explicit pitch is used exactly, even on a jittered sound")
	var bell: AudioStreamPlayer = sfx.play("bell")
	var ember_p: AudioStreamPlayer = sfx.play("ember")
	_check(bell.pitch_scale == 1.0 and ember_p.pitch_scale == 1.0, "tonal sounds are not jittered")
	_check(sfx.play("no_such_sound") == null, "an unknown sound is a quiet no-op")
	var toll: AudioStreamPlayer = sfx.play("toll")
	_check(toll != null and sfx._streams["peal"].has(toll.stream), "\"toll\" is another name for peal (the Special's old name)")
	# Jitter and takes, spaced past the flam guard.
	var pitches := {}
	var in_range := true
	var repeats := 0
	var last_stream = null
	for i in range(14):
		OS.delay_msec(SfxLib.FLAM_MSEC + 5)
		var p: AudioStreamPlayer = sfx.play("step")
		in_range = in_range and p != null and absf(p.pitch_scale - 1.0) <= float(SfxLib.JITTER["step"]) + 0.0001
		pitches[snappedf(p.pitch_scale, 0.0001)] = true
		repeats += 1 if p.stream == last_stream else 0
		last_stream = p.stream
	_check(in_range and pitches.size() > 5, "footsteps wander in pitch within +-%d%% (%d distinct in 14)" % [roundi(SfxLib.JITTER["step"] * 100), pitches.size()])
	_check(repeats == 0, "footsteps never repeat a take twice running")
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var first: AudioStreamPlayer = sfx.play("stomp")
	var second: AudioStreamPlayer = sfx.play("stomp")
	_check(first != null and first == second, "the same sound twice in one moment plays once")
	var other: AudioStreamPlayer = sfx.play("ember", sfx.note(2))
	var higher: AudioStreamPlayer = sfx.play("ember", sfx.note(3))
	_check(other != null and higher != null and other != higher, "at different pitches it layers (an ember streak)")
	var last := 0.0
	var climbs := true
	for i in range(SfxLib.STREAK_TOP + 4):
		var p: AudioStreamPlayer = sfx.ember(i)
		var want: float = sfx.note(mini(i, SfxLib.STREAK_TOP))
		climbs = climbs and p != null and is_equal_approx(p.pitch_scale, want) and (p.pitch_scale > last or i > SfxLib.STREAK_TOP)
		last = p.pitch_scale if p != null else last
	_check(climbs, "ember(i) climbs the scale, then holds at the top note")
	_quiet(sfx)
	var voices := {}
	for i in range(SfxLib.VOICES + 4):
		var p: AudioStreamPlayer = sfx.play("bell", 1.0 + 0.01 * i)
		if p != null:
			voices[p] = true
	var ringing := 0
	for p in voices:
		ringing += 1 if p.playing else 0
	_check(voices.size() == SfxLib.VOICES and ringing == SfxLib.VOICES,
			"sounds overlap across all %d voices, then steal the oldest" % SfxLib.VOICES)
	_quiet(sfx)


func _test_in_key(sfx) -> void:
	## Speakers in key: a blip at voice_note(voice, i) is always on D minor
	## pentatonic, in the speaker's own register; in_key snaps any pitch.
	var on_scale := func(r: float) -> bool:
		var semis: float = 12.0 * log(r) / log(2.0)
		return absf(semis - roundi(semis)) < 0.001 and SfxLib.SCALE.has(posmod(roundi(semis), 12))
	var every_note := true
	var rising := true
	var close := true
	var snapped := true
	for v in VOICES:
		var last := 0.0
		for i in range(5):
			var r: float = SfxLib.voice_note(v, i)
			every_note = every_note and on_scale.call(r)
			rising = rising and r > last
			last = r
			snapped = snapped and on_scale.call(SfxLib.in_key(v * sfx.note(i)))
		close = close and absf(12.0 * log(SfxLib.voice_note(v, 0) / v) / log(2.0)) <= 1.5 + 0.0001
	_check(every_note and rising, "every story and calling voice blips five rising notes of D minor pentatonic")
	_check(close, "a speaker's first note is within a semitone and a half of their voice")
	_check(snapped, "in_key snaps any pitch (a voice times a note) onto the scale")
	var taper := []
	for i in range(5):
		taper.append(roundi(12.0 * log(SfxLib.voice_note(1.6, i)) / log(2.0)))
	_check(taper == [7, 10, 12, 15, 17], "Mother Taper (1.6) blips A C D F G above the D, not Bb C# Eb F Ab (%s)" % [taper])
	var fixed := true
	for d in range(11):
		for k in [1.0, 0.5, 0.25]:
			var r: float = sfx.note(d) * k
			fixed = fixed and absf(SfxLib.in_key(r) - r) < 0.0001 and absf(SfxLib.voice_note(r, 0) - r) < 0.0001
	_check(fixed, "a pitch already on the scale is left where it is")
	_check(absf(SfxLib.voice_note(1.0, 3) - sfx.note(3)) < 0.0001 and absf(SfxLib.voice_note(0.5, 5) - 1.0) < 0.0001,
			"a voice on D just walks note()")
	_check(SfxLib.in_key(0.0) == 0.0 and SfxLib.in_key(-1.0) == -1.0 and SfxLib.voice_note(0.0, 2) == 0.0,
			"no voice (0) stays 0")
	var node: Node = sfx
	_check(absf(node.voice_note(1.25, 2) - SfxLib.voice_note(1.25, 2)) < 0.0001 and absf(node.in_key(1.25) - SfxLib.in_key(1.25)) < 0.0001,
			"voice_note and in_key can be called on the Sfx autoload, as the story does")


func _test_release(sfx) -> void:
	## A held sound (the flare charge) is let go with a short fade, not cut.
	var v: AudioStreamPlayer = sfx.play("flare_charge")
	sfx.release(v, 0.1)
	sfx._tick_release(0.05)
	_check(v.playing and v.volume_db < -4.0 and v.volume_db > -30.0, "release() fades a held sound (%.1f dB halfway)" % v.volume_db)
	sfx._tick_release(0.06)
	_check(not v.playing, "then stops it")
	var w: AudioStreamPlayer = sfx.play("flare_charge")
	sfx.release(w, 0.5)
	w.stream = sfx._streams["bell"][0]   # the voice is handed to another sound meanwhile
	w.volume_db = 0.0
	w.play()
	sfx._tick_release(1.0)
	_check(w.playing and is_equal_approx(w.volume_db, 0.0), "a voice handed on to another sound is left alone")
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var x: AudioStreamPlayer = sfx.play("flare_charge")
	sfx.release(x, 0.5)
	x.stop()
	var y: AudioStreamPlayer = sfx.play("click")
	sfx._tick_release(1.0)
	_check(y != null and y.playing and sfx._releasing.is_empty(), "a sound played on a voice being released plays at full")
	sfx.release(null)
	_check(true, "release(null) is harmless")
	_quiet(sfx)
	# The charge ran out (she held on past its 1.5 s) and its voice went to
	# another sound: letting go of the charge now must not touch that one.
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var spent: AudioStreamPlayer = sfx.play("flare_charge")
	spent.stop()
	var reused: AudioStreamPlayer = null
	for i in range(SfxLib.VOICES + 2):
		var p: AudioStreamPlayer = sfx.play("slash_hit", 1.0 + 0.01 * i)
		if p == spent:
			reused = p
			break
	_check(reused != null, "a finished charge's voice is handed to the next sounds")
	sfx.release(spent, 0.1)
	sfx._tick_release(0.5)
	_check(reused != null and reused.playing and is_equal_approx(reused.volume_db, 0.0) and not sfx._releasing.has(reused),
			"letting go of a charge whose voice now plays another sound leaves that sound at full")
	_quiet(sfx)
	# Every voice busy: a new sound steals the one the charge is on.
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var held: AudioStreamPlayer = sfx.play("flare_charge")
	var thief: AudioStreamPlayer = null
	for i in range(SfxLib.VOICES + 2):
		var p: AudioStreamPlayer = sfx.play("bell", 1.0 + 0.01 * i)
		if p == held:
			thief = p
			break
	_check(thief != null and sfx._streams["bell"].has(thief.stream), "with every voice busy, the charge's voice is stolen")
	sfx.release(held, 0.1)
	sfx._tick_release(0.5)
	_check(thief != null and thief.playing and is_equal_approx(thief.volume_db, 0.0), "letting go of it then leaves the thief alone")
	# And a held sound is the only kind release() fades.
	_quiet(sfx)
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var bell: AudioStreamPlayer = sfx.play("bell")
	sfx.release(bell, 0.1)
	sfx._tick_release(0.5)
	_check(bell.playing and is_equal_approx(bell.volume_db, 0.0), "release() on a one-shot sound does nothing")
	_quiet(sfx)


func _test_gain(sfx) -> void:
	## play(sound, pitch, gain): quieter by exactly the gain, never louder,
	## and a gain of 0 plays nothing.
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var full: AudioStreamPlayer = sfx.play("click")
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var half: AudioStreamPlayer = sfx.play("click", 1.0, 0.5)
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var over: AudioStreamPlayer = sfx.play("select", 1.0, 3.0)
	_check(full != null and half != null and absf(half.volume_db - (full.volume_db + linear_to_db(0.5))) < 0.01
			and over != null and absf(over.volume_db - full.volume_db) < 0.01, "a gain plays a sound quieter by just that much, never louder")
	_check(sfx.play("bell", 1.0, 0.0) == null, "a gain of 0 plays nothing")
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var soft: AudioStreamPlayer = sfx.play("select", 1.0, 0.25)
	var loud: AudioStreamPlayer = sfx.play("select", 1.0, 0.8)
	_check(soft != null and loud == soft and absf(soft.volume_db - (full.volume_db + linear_to_db(0.8))) < 0.01,
			"the same sound twice within a flam plays once, at the louder of the two gains")
	sfx.set_volume(0.5)
	_check(absf(half.volume_db - linear_to_db(0.25)) < 0.01, "the master volume keeps a voice's gain")
	sfx.set_volume(1.0)
	_quiet(sfx)


func _test_tell(sfx) -> void:
	## tell(sound, seconds): a tell's sound fitted to a shorter tell starts
	## that much further in (a trimmed copy of its take, eased in so it can't
	## click), at its own pitch; a longer tell, or a sound with no TELL_AT,
	## plays the take itself; one not rendered yet plays its fallback from the
	## start; a silence tell's silence moves with it and ends as its threat
	## lands.
	var takes: Array = sfx._streams.get("spore_swell", [])
	var at := float(sfx._tell_at.get("spore_swell", 0.0))
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var v: AudioStreamPlayer = sfx.tell("spore_swell", at - 0.1)
	var ok: bool = at > 0.0 and v != null and not takes.is_empty() and v.stream is AudioStreamWAV and not takes.has(v.stream) \
			and is_equal_approx(v.pitch_scale, 1.0)
	if ok:
		var whole: PackedByteArray = (takes[0] as AudioStreamWAV).data
		var cut: PackedByteArray = (v.stream as AudioStreamWAV).data
		var skip := roundi(0.1 * SfxLib.RATE)
		var ease := int(SfxLib.TRIM_EASE * SfxLib.RATE)
		ok = cut.size() == whole.size() - 2 * skip and cut.slice(2 * ease) == whole.slice(2 * (skip + ease)) and cut.decode_s16(0) == 0
	_check(ok, "a tell 0.1 s shorter plays its take from 0.1 s in, eased in, at its own pitch")
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var again: AudioStreamPlayer = sfx.tell("spore_swell", at - 0.1)
	_check(again != null and v != null and again.stream == v.stream, "the same length again reuses the trimmed take")
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var longer: AudioStreamPlayer = sfx.tell("spore_swell", at + 0.3)
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var plain: AudioStreamPlayer = sfx.tell("slash", 0.2)
	_check(longer != null and takes.has(longer.stream) and plain != null and (sfx._streams["slash"] as Array).has(plain.stream),
			"a longer tell, and a sound with no TELL_AT, play the take itself")
	sfx._lock.lock()
	var kept: Array = sfx._streams["spore_swell"]
	sfx._streams.erase("spore_swell")
	sfx._lock.unlock()
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	var fb: AudioStreamPlayer = sfx.tell("spore_swell", at - 0.1)
	sfx._lock.lock()
	sfx._streams["spore_swell"] = kept
	sfx._lock.unlock()
	var fb_takes: Array = sfx._streams.get(SfxLib.FALLBACK["spore_swell"], [])
	_check(fb != null and fb_takes.has(fb.stream), "a tell not rendered yet plays its fallback from its start")
	# The Snuff at its 0.8 s floor: its silence 0.3 s before the hand lands.
	sfx.set_hush(0.0)
	sfx._aim_hush(0.0)
	sfx._tick_music(0.4)
	sfx.tell("hush_silence", 0.8)
	sfx._tick_music(0.45)
	var clear := is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), 0.0)
	sfx._tick_music(0.1)
	var fell := _bus_db(SfxLib.EFFECTS_BUS) < -15.0
	sfx._tick_music(0.25)
	var held := _bus_db(SfxLib.EFFECTS_BUS) < -15.0
	sfx._tick_music(0.1)
	_check(clear and fell and held and _bus_db(SfxLib.EFFECTS_BUS) > -15.0,
			"the Snuff on a 0.8 s tell: its silence falls 0.5 s in, 0.3 s before the hand lands, and lifts as it does")
	sfx._tick_music(0.5)
	# The Deep Quiet at its 1.2 s floor keeps 0.35 s of its breath, the rest
	# coming off the silence, which ends as the water rises.
	sfx.tell("deep_quiet", 1.2)
	sfx._tick_music(0.3)
	clear = is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), 0.0)
	sfx._tick_music(0.07)
	sfx._tick_music(0.1)
	fell = _bus_db(SfxLib.EFFECTS_BUS) < -15.0
	sfx._tick_music(0.7)
	held = _bus_db(SfxLib.EFFECTS_BUS) < -15.0
	sfx._tick_music(0.1)
	_check(clear and fell and held and _bus_db(SfxLib.EFFECTS_BUS) > -15.0,
			"the Deep Quiet on a 1.2 s tell: 0.35 s of breath, then silence until the water rises")
	sfx._tick_music(0.5)
	_check(is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), 0.0) and is_equal_approx(sfx.hush_level(), 0.0), "and back to nothing")
	_quiet(sfx)


# ---------------------------------------------------------------- the cache

func _test_cache(sfx) -> void:
	## The render cache: the autoload leaves one on disk under this build's
	## key; it round-trips byte for byte; anything stale, torn or short is
	## ignored; and with it in place a fresh Sfx has every sound at once.
	var key: String = SfxLib.cache_key()
	_check(key.begins_with(FileAccess.get_md5("res://scripts/sfx.gd")), "the cache key is a hash of sfx.gd, the engine version and the rate")
	var start := Time.get_ticks_msec()
	while not sfx.is_loaded() and Time.get_ticks_msec() - start < 30000:
		await process_frame
	var f := FileAccess.open(SfxLib.CACHE_PATH, FileAccess.READ)
	_check(f != null and SfxLib._read_text(f, f.get_length()) == SfxLib.CACHE_MAGIC and SfxLib._read_text(f, f.get_length()) == key,
			"the autoload leaves a cache of this build's sounds in %s" % SfxLib.CACHE_PATH)
	f = null
	var streams: Dictionary = sfx._streams.duplicate()
	_check(SfxLib.save_cache(streams, TEST_CACHE, "test-key"), "save_cache writes a cache")
	var lock := Mutex.new()
	var back := {}
	var t0 := Time.get_ticks_usec()
	var ok := SfxLib.load_cache(back, lock, TEST_CACHE, "test-key")
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var same := ok and back.size() == SfxLib.CORE.size()
	for s in SfxLib.CORE:
		if not same:
			break
		var a: Array = streams[s]
		var b: Array = back[s]
		same = a.size() == b.size()
		for i in range(mini(a.size(), b.size())):
			same = same and (a[i] as AudioStreamWAV).data == (b[i] as AudioStreamWAV).data and (b[i] as AudioStreamWAV).mix_rate == SfxLib.RATE
	_check(same, "a cache round-trips every take byte for byte")
	_check(ms < 400.0, "loading all %d sounds from the cache takes %d ms" % [SfxLib.CORE.size(), roundi(ms)])
	var other := {}
	_check(not SfxLib.load_cache(other, lock, TEST_CACHE, "another-key") and other.is_empty(), "a cache made by another build is ignored")
	var bytes := FileAccess.get_file_as_bytes(TEST_CACHE)
	FileAccess.open(TEST_CACHE, FileAccess.WRITE).store_buffer(bytes.slice(0, bytes.size() / 2))
	_check(not SfxLib.load_cache(other, lock, TEST_CACHE, "test-key") and other.is_empty(), "a torn cache is ignored")
	FileAccess.open(TEST_CACHE, FileAccess.WRITE).store_buffer(bytes + PackedByteArray([1, 2, 3]))
	_check(not SfxLib.load_cache(other, lock, TEST_CACHE, "test-key") and other.is_empty(), "so is one with junk after it")
	var junk := PackedByteArray()
	for i in range(4096):
		junk.append((i * 7919 + 13) % 256)
	FileAccess.open(TEST_CACHE, FileAccess.WRITE).store_buffer(junk)
	_check(not SfxLib.load_cache(other, lock, TEST_CACHE, "test-key") and other.is_empty(), "a file of junk is shrugged off")
	var fewer := streams.duplicate()
	fewer.erase("bell")
	SfxLib.save_cache(fewer, TEST_CACHE, "test-key")
	_check(not SfxLib.load_cache(other, lock, TEST_CACHE, "test-key") and other.is_empty(), "and one missing a sound")
	_check(not SfxLib.load_cache(other, lock, "user://no_such_cache.bin", "test-key"), "no cache at all: nothing loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CACHE))
	var stray := DirAccess.get_files_at(ProjectSettings.globalize_path("user://"))
	var tmp := 0
	for name in stray:
		tmp += 1 if name.ends_with(".tmp") and name.begins_with("sfx_cache") else 0
	_check(tmp == 0, "no scratch files are left behind")
	var warm = SfxLib.new()
	var t1 := Time.get_ticks_msec()
	while not warm.is_loaded() and Time.get_ticks_msec() - t1 < 5000:
		OS.delay_msec(1)
	var boot := Time.get_ticks_msec() - t1
	_check(warm.is_loaded() and boot < 600, "with the cache on disk, a fresh Sfx has every sound in %d ms" % boot)
	warm.free()


# ---------------------------------------------------------------- settings

func _test_settings(sfx) -> void:
	# Another setting in the same file must survive Sfx rewriting it.
	FileAccess.open(SfxLib.SETTINGS_PATH, FileAccess.WRITE).store_string(JSON.stringify({"other": 7}))
	sfx.play("bell")
	sfx.muted = true
	_check(sfx.play("click") == null, "muted: play() is silent")
	var any_playing := false
	for p in sfx._voices:
		any_playing = any_playing or p.playing
	_check(not any_playing, "muting stops what is ringing")
	sfx.set_volume(0.4)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SfxLib.SETTINGS_PATH))
	_check(saved is Dictionary and saved.get("muted") == true and is_equal_approx(float(saved.get("volume", 0.0)), 0.4)
			and saved.get("music_muted") == false and saved.get("other") == 7,
			"settings.json holds muted, volume and music_muted, and keeps other keys")
	var restarted = SfxLib.new()
	_check(restarted.muted and not restarted.music_muted and is_equal_approx(restarted.get_volume(), 0.4),
			"muted and volume survive a restart")
	restarted.free()
	sfx.muted = false
	sfx.music_muted = true
	saved = JSON.parse_string(FileAccess.get_file_as_string(SfxLib.SETTINGS_PATH))
	_check(saved is Dictionary and saved.get("muted") == false and saved.get("music_muted") == true,
			"music_muted is saved separately from muted")
	restarted = SfxLib.new()
	_check(not restarted.muted and restarted.music_muted, "music_muted survives a restart on its own")
	restarted.free()
	sfx.music_muted = false
	sfx.set_volume(1.0)
	restarted = SfxLib.new()
	_check(not restarted.muted and not restarted.music_muted and is_equal_approx(restarted.get_volume(), 1.0),
			"unmuting survives a restart too")
	restarted.free()
	# Someone else saves after Sfx loaded the file: Sfx never writes back a
	# stale copy of their key.
	FileAccess.open(SfxLib.SETTINGS_PATH, FileAccess.WRITE).store_string(JSON.stringify({"haptics": true, "muted": false}))
	var loaded = SfxLib.new()
	SettingsLib.write({"haptics": false})
	loaded.muted = false
	saved = JSON.parse_string(FileAccess.get_file_as_string(SfxLib.SETTINGS_PATH))
	_check(saved is Dictionary and saved.get("haptics") == false, "Sfx never writes back a stale copy of another setting")
	loaded.free()
	_check(sfx.play("click") != null, "unmuted: play() is back")
	_quiet(sfx)


# ---------------------------------------------------------------- music

func _raw_track(track: String) -> AudioStream:
	## A track read off disk and set looping, bypassing the import system.
	return SfxLib.loop_music(AudioStreamWAV.load_from_file(SfxLib.MUSIC_PATH % track))


func _test_music_files() -> void:
	var listed: Array = SfxLib.TRACKS.duplicate()
	listed.sort()
	var here: Array = TRACKS.keys()
	here.sort()
	_check(listed == here, "Sfx.TRACKS names exactly the tracks tested here (%s)" % ", ".join(SfxLib.TRACKS))
	var waiting := []
	for track in SfxLib.TRACKS:
		if not V2_TRACKS.has(track) and not FileAccess.file_exists(SfxLib.MUSIC_PATH % track):
			waiting.append(track)
			continue
		# The way the game loads it: the imported stream if there is one, else the file.
		var game := SfxLib.load_music(SfxLib.MUSIC_PATH % track) as AudioStreamWAV
		var shortest := 6.0 if str(track).begins_with("amb_") else 14.0
		_check(game != null and game.loop_mode == AudioStreamWAV.LOOP_FORWARD and game.loop_end > 0
				and game.get_length() > shortest, "the game can load %s, looping (%.1f s)" % [track, game.get_length() if game else 0.0])
	if not waiting.is_empty():
		print("skipped: %d v3 tracks music.py hasn't written yet (%s)" % [waiting.size(), ", ".join(waiting)])
	for track in TRACKS:
		var path: String = SfxLib.MUSIC_PATH % track
		if not V2_TRACKS.has(track) and not FileAccess.file_exists(path):
			continue
		_check(FileAccess.file_exists(path), "%s exists" % path)
		if not FileAccess.file_exists(path):
			continue
		var wav := _raw_track(track) as AudioStreamWAV
		var frames := roundi(wav.get_length() * wav.mix_rate)
		var loop_secs := wav.loop_end / float(wav.mix_rate)
		var span: Array = TRACKS[track]
		_check(wav.mix_rate == 22050 and not wav.stereo, "%s is mono at 22050 Hz" % track)
		_check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_begin == 0 and wav.loop_end == frames - SfxLib.MUSIC_PAD,
				"%s loops forward over all but its %d padding frames" % [track, SfxLib.MUSIC_PAD])
		_check(loop_secs >= float(span[0]) and loop_secs <= float(span[1]), "%s loops every %.1f s" % [track, loop_secs])
	# The stems and premixes, once written: mono 22050, looping, every stem of
	# a set the same length (else AudioStreamSynchronized would drift them).
	var sets := {}
	for set in SfxLib.STEMS:
		sets[set] = (SfxLib.STEMS[set] as Array).duplicate()
		if SfxLib.PREMIX.has(set):
			sets[set].append_array((SfxLib.PREMIX[set] as Dictionary).keys())
	for set in sets:
		var lengths := {}
		for stem in sets[set]:
			var path: String = SfxLib.MUSIC_PATH % stem
			if not FileAccess.file_exists(path):
				continue
			var wav := _raw_track(stem) as AudioStreamWAV
			var secs := wav.loop_end / float(wav.mix_rate)
			lengths[stem] = wav.loop_end
			var span: Array = STEM_LOOPS[set]
			_check(wav.mix_rate == 22050 and not wav.stereo and secs >= float(span[0]) and secs <= float(span[1]),
					"%s is mono at 22050 Hz and loops every %.1f s" % [stem, secs])
		if lengths.size() > 1:
			var one: int = lengths.values()[0]
			_check(lengths.values().all(func(v): return int(v) == one), "every stem of %s loops on the same frame (%s)" % [set, lengths])
		elif lengths.is_empty():
			print("skipped: the %s stems aren't written yet" % set)
	# The raw-file fallback, from a path the import system has never seen.
	var bytes := FileAccess.get_file_as_bytes(SfxLib.MUSIC_PATH % "title")
	FileAccess.open(TEST_WAV, FileAccess.WRITE).store_buffer(bytes)
	var fallback := SfxLib.load_music(TEST_WAV) as AudioStreamWAV
	_check(fallback != null and fallback.loop_mode == AudioStreamWAV.LOOP_FORWARD and fallback.loop_end > 0,
			"an unimported WAV is read straight off disk and set looping")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_WAV))
	_check(SfxLib.load_music("res://audio/no_such_track.wav") == null, "a missing file loads as null")


func _test_music(sfx) -> void:
	for track in TRACKS:
		if FileAccess.file_exists(SfxLib.MUSIC_PATH % track):
			sfx._music_cache[track] = _raw_track(track)
	var music: Array = sfx._music
	sfx.play_music("chapel")
	var a: AudioStreamPlayer = music[sfx._music_cur]
	_check(a.playing and a.stream == sfx._music_cache["chapel"] and sfx.music_playing() == "chapel", "play_music starts the track")
	_check(a.volume_db < -60.0, "it fades in from silence")
	sfx._tick_music(0.2)
	_check(a.volume_db < SfxLib.MUSIC_DB - 1.0 and a.volume_db > -60.0, "partway in after 0.2 s (%.1f dB)" % a.volume_db)
	sfx._tick_music(0.25)
	_check(is_equal_approx(a.volume_db, SfxLib.MUSIC_DB), "at full level after the %.1f s fade (%.1f dB)" % [SfxLib.MUSIC_FADE, a.volume_db])
	var cur: int = sfx._music_cur
	sfx.play_music("chapel")
	_check(sfx._music_cur == cur and a.playing and is_equal_approx(a.volume_db, SfxLib.MUSIC_DB) and not music[1 - cur].playing,
			"asking for the track already playing changes nothing")
	# Crossfade.
	sfx.play_music("boss")
	var b: AudioStreamPlayer = music[sfx._music_cur]
	_check(b != a and b.playing and a.playing and b.stream == sfx._music_cache["boss"], "a new track crossfades: both play at once")
	sfx._tick_music(0.2)
	var mid_a := a.volume_db
	var mid_b := b.volume_db
	_check(mid_a < SfxLib.MUSIC_DB and mid_b < SfxLib.MUSIC_DB and absf(mid_a - mid_b) < 0.5,
			"halfway, they cross at equal power (%.1f, %.1f dB)" % [mid_a, mid_b])
	sfx._tick_music(0.25)
	_check(not a.playing and b.playing and is_equal_approx(b.volume_db, SfxLib.MUSIC_DB), "then the old one stops")
	# Ducking.
	sfx.duck_music(9.0, 1.0)
	sfx._tick_music(0.1)
	sfx._tick_music(0.1)
	_check(absf(b.volume_db - (SfxLib.MUSIC_DB - 9.0)) < 0.1, "duck_music(9, 1) dips the music 9 dB within 0.2 s (%.1f dB)" % b.volume_db)
	sfx.duck_music(-4.0, 2.0)   # 0.2 s into the first: this one ends 2.2 s after it began
	sfx._tick_music(0.5)
	sfx._tick_music(0.5)
	sfx._tick_music(0.3)
	_check(absf(b.volume_db - (SfxLib.MUSIC_DB - 9.0)) < 0.1, "an overlapping duck keeps the deeper dip and the later end")
	sfx._tick_music(0.6)
	_check(absf(b.volume_db - (SfxLib.MUSIC_DB - 9.0)) < 0.1, "held until the later end")
	sfx._tick_music(0.2)
	_check(b.volume_db > SfxLib.MUSIC_DB - 9.0 and b.volume_db < SfxLib.MUSIC_DB, "then it comes back up (%.1f dB)" % b.volume_db)
	for i in range(10):
		sfx._tick_music(0.1)
	_check(is_equal_approx(b.volume_db, SfxLib.MUSIC_DB), "all the way, within a second")
	sfx.set_volume(0.5)
	_check(absf(b.volume_db - (SfxLib.MUSIC_DB + linear_to_db(0.5))) < 0.01, "the volume setting turns the music down too")
	sfx.set_volume(1.0)
	# Sound mute and music mute are separate switches.
	sfx.muted = true
	_check(b.playing, "muting the sound effects leaves the music playing")
	sfx.muted = false
	sfx.music_muted = true
	_check(not music[0].playing and not music[1].playing and sfx.music_playing() == "boss", "music_muted silences the music but remembers the track")
	sfx.play_music("title")
	_check(not music[0].playing and not music[1].playing and sfx.music_playing() == "title", "a track asked for while muted is only remembered")
	sfx.music_muted = false
	var t: AudioStreamPlayer = music[sfx._music_cur]
	_check(t.playing and t.stream == sfx._music_cache["title"], "unmuting starts the remembered track")
	# The real clock drives the fades too.
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 700:
		await process_frame
	_check(is_equal_approx(t.volume_db, SfxLib.MUSIC_DB), "the fade runs by itself as frames pass")
	# Stopping.
	sfx.stop_music(0.5)
	sfx._tick_music(0.25)
	_check(t.playing and t.volume_db < SfxLib.MUSIC_DB, "stop_music fades out")
	sfx._tick_music(0.3)
	_check(not music[0].playing and not music[1].playing and sfx.music_playing() == "", "and then stops, forgetting the track")
	sfx.play_music("chapel")
	sfx.stop_music(0.0)
	_check(not music[0].playing and not music[1].playing, "stop_music(0) stops at once")
	# A missing track warns and does no harm.
	sfx.play_music("boss")
	sfx._tick_music(0.5)
	sfx.play_music("no_such_track")
	_check(sfx._music_cache.has("no_such_track") and sfx._music_cache["no_such_track"] == null, "a missing track is looked for once")
	sfx._tick_music(0.5)
	_check(not music[0].playing and not music[1].playing, "and the old track fades out rather than playing on")
	sfx.play_music("no_such_track")
	_check(not music[0].playing and not music[1].playing, "asking again stays quiet")


func _test_lowpass(sfx) -> void:
	## The music has a bus of its own, so a low-pass can muffle it (and only
	## it) while the flame is low, gliding in and out rather than switching.
	var bus := AudioServer.get_bus_index(SfxLib.MUSIC_BUS)
	_check(bus > 0 and AudioServer.get_bus_send(bus) == &"Master", "there is a Music bus, sending to Master")
	var more = SfxLib.new()
	more.free()
	var buses := 0
	for i in range(AudioServer.bus_count):
		buses += 1 if AudioServer.get_bus_name(i) == SfxLib.MUSIC_BUS else 0
	_check(buses == 1, "a second Sfx finds the Music bus rather than making another")
	var music: Array = sfx._music
	var voices_on_fx := true
	for p in sfx._voices:
		voices_on_fx = voices_on_fx and p.bus == &"Effects"
	_check(music[0].bus == &"Music" and music[1].bus == &"Music" and voices_on_fx,
			"the music plays through it; the effects play through their own bus, not it")
	var slot: int = SfxLib._lowpass_slot(bus)
	_check(slot >= 0 and not AudioServer.is_bus_effect_enabled(bus, slot), "a low-pass waits on the Music bus, switched off")
	if slot < 0:
		return
	var lp := AudioServer.get_bus_effect(bus, slot) as AudioEffectLowPassFilter
	sfx.set_lowpass(true)
	_check(sfx.lowpass_on() and AudioServer.is_bus_effect_enabled(bus, slot), "set_lowpass(true) switches it on")
	sfx._tick_music(0.2)
	_check(lp.cutoff_hz < SfxLib.LOWPASS_OPEN * 0.5 and lp.cutoff_hz > SfxLib.LOWPASS_HZ, "it glides down (%d Hz after 0.2 s)" % roundi(lp.cutoff_hz))
	sfx._tick_music(0.3)
	_check(is_equal_approx(lp.cutoff_hz, SfxLib.LOWPASS_HZ), "and reaches %d Hz within half a second" % roundi(SfxLib.LOWPASS_HZ))
	for i in range(10):
		sfx._tick_music(0.5)
	_check(is_equal_approx(lp.cutoff_hz, SfxLib.LOWPASS_HZ) and AudioServer.is_bus_effect_enabled(bus, slot), "it stays there while the flame is low")
	sfx.set_lowpass(false)
	_check(not sfx.lowpass_on(), "set_lowpass(false) lets it go")
	sfx._tick_music(0.2)
	_check(AudioServer.is_bus_effect_enabled(bus, slot) and lp.cutoff_hz > SfxLib.LOWPASS_HZ * 2.0, "it opens back up (%d Hz after 0.2 s)" % roundi(lp.cutoff_hz))
	sfx._tick_music(0.3)
	_check(not AudioServer.is_bus_effect_enabled(bus, slot) and is_equal_approx(lp.cutoff_hz, SfxLib.LOWPASS_OPEN), "fully open, then switched off")
	sfx.set_lowpass(true)
	sfx.set_lowpass(false)
	_check(not AudioServer.is_bus_effect_enabled(bus, slot), "on and straight off again leaves it off")


# ---------------------------------------------------------------- helpers

func _rendered(sfx) -> int:
	sfx._lock.lock()
	var n: int = sfx._streams.size()
	sfx._lock.unlock()
	return n


func _quiet(sfx) -> void:
	for p in sfx._voices:
		p.stop()


# ---------------------------------------------------------------- v3: the tables

func _test_tables() -> void:
	## Every v3 name sits in exactly one bank, and falls back to a core sound
	## until it's rendered.
	var all := {}
	var dup := []
	for n in SfxLib.NAMES:
		if all.has(n):
			dup.append(n)
		all[n] = true
	_check(dup.is_empty() and SfxLib.NAMES == SfxLib.CORE + SfxLib.V3_NAMES, "NAMES is the core then every v3 name, none twice %s" % [dup])
	_check(SfxLib.BANK_ORDER.size() == SfxLib.BANKS.size() and SfxLib.BANK_ORDER.all(func(id): return SfxLib.BANKS.has(id)),
			"BANK_ORDER lists every bank once")
	var in_banks := []
	for id in SfxLib.BANK_ORDER:
		in_banks.append_array(SfxLib.BANKS[id])
	_check(in_banks == SfxLib.V3_NAMES, "the banks, in order, are exactly V3_NAMES (%d names)" % in_banks.size())
	var bad := []
	for n in SfxLib.V3_NAMES:
		if not SfxLib.FALLBACK.has(n) or not SfxLib.CORE.has(SfxLib.FALLBACK[n]):
			bad.append(n)
	var stray := SfxLib.FALLBACK.keys().filter(func(n): return not SfxLib.V3_NAMES.has(n))
	_check(bad.is_empty() and stray.is_empty(), "every v3 name falls back to a core sound, and only they do %s %s" % [bad, stray])
	# The contract's own fallbacks (its "crumble" is the crumble ledge's block_break).
	var contract := {"vine_snap": "block_break", "spore_burn": "whoosh", "glowfruit_drop": "ember",
			"skull_lantern": "lantern_light", "root_burst": "boss_slam", "creep_snap": "bones", "rootmother_roar": "boss_roar",
			"rootmother_die": "boss_die", "talk_wood": "talk", "talk_tick": "talk", "talk_glass": "talk", "lull": "bell"}
	var off := contract.keys().filter(func(n): return SfxLib.FALLBACK[n] != contract[n])
	_check(off.is_empty(), "the contract's fallbacks are kept %s" % [off])
	# A tell never falls back to something shorter than a tell.
	for n in ["vine_creak", "icicle_tell", "gust_tell", "wind_up", "tinker_windup", "root_creak", "saint_charge",
			"weepcap_inhale", "gust_inhale", "gulp_inhale", "spore_swell", "float_sink"]:
		var secs := SfxLib.render(SfxLib.FALLBACK[n]).size() / float(SfxLib.RATE)
		_check(secs >= 0.35, "the %s tell's stand-in (%s) lasts %.2f s, a tell's length" % [n, SfxLib.FALLBACK[n], secs])
	for set in SfxLib.STEMS:
		_check((SfxLib.STEMS[set] as Array).size() <= 5 and SfxLib.TRACK_FALLBACK.has(set), "%s has at most 5 stems and a stand-in track" % set)
	var fb := {"trial": "chapel", "evenbell": "dawn", "rootmother": "boss", "tinker": "boss", "saint": "boss", "hush_final": "boss"}
	_check(fb.keys().all(func(t): return SfxLib.TRACK_FALLBACK[t] == fb[t]), "the contract's track fallbacks: trial chapel, evenbell dawn, a boss's boss")
	_check(SfxLib.TRACK_FALLBACK.values().all(func(t): return V2_TRACKS.has(t)), "every track stand-in is a v2 track")


func _test_spike() -> void:
	## The spike's dummy bank and its drift arithmetic (the phone reads it).
	var dummy: Array = SpikeLib.dummy_banks("")
	var names := []
	for b in dummy:
		names.append_array(b["names"])
	_check(names == SfxLib.V3_NAMES and SpikeLib.recordings(dummy) > SfxLib.V3_NAMES.size(),
			"the spike's dummy bank is every v3 name, bank by bank (%d recordings)" % SpikeLib.recordings(dummy))
	_check(SpikeLib.dummy_render("vine_snap", 0) == SfxLib.render("block_break", 0), "a dummy sound is its fallback's recipe")
	var timed: Array = SpikeLib.spike_banks("")
	var real := SfxLib.bank_list(SfxLib).slice(1).map(func(b): return str(b["id"]))
	_check(timed.size() == SfxLib.BANK_ORDER.size() and timed.all(func(b): return (b["key"] as String).begins_with("spike-dummy") != real.has(b["id"])),
			"the boot spike times each real bank file, and a dummy only for a bank not written (%s real)" % [real])
	_check(SfxLib.spike_arg() == "", "no spike without --autoplay=spike:<what>")
	var rate := 48000.0
	var onsets := []
	for k in range(10):
		for i in range(SpikeLib.STEMS):
			onsets.append(roundi((k * SpikeLib.PERIOD + SpikeLib.OFFSET + i * SpikeLib.GAP) * rate) + (k if i == 3 else 0) + k)
	var a: Dictionary = SpikeLib.analyze(onsets.slice(2), rate)   # the run caught mid-period: stem 2 first
	# Period 0 lost its stem 0 (the run began with stem 2), so it's read from period 1 on.
	_check(int(a["periods"]) == 10 and int(a["found"]) == 48 and int(a["stray"]) == 0 and roundi(float(a["drift"])) == 8
			and int(a["worst"]) == 3, "the spike reads the stems back from a run begun mid-period: stem 3 drifted 8 frames (%s)" % [a])
	_check(roundi(float(a["clock"])) == 8, "and stem 0's own clock ran 8 frames long over periods 1 to 9 (%s)" % a["clock"])
	var none: Dictionary = SpikeLib.analyze(onsets.filter(func(o): return true).slice(0, 3), rate)
	_check(int(none["periods"]) == 0, "too few bursts: nothing is read into them")
	var bytes: PackedByteArray = SpikeLib.stem_bytes(2, 4.0)
	var wav := AudioStreamWAV.load_from_buffer(bytes)
	_check(wav != null and wav.mix_rate == SfxLib.RATE and roundi(wav.get_length() * SfxLib.RATE) == 4 * SfxLib.RATE + SfxLib.MUSIC_PAD,
			"a spike stem is a WAV of its loop and the pad")


# ---------------------------------------------------------------- v3: buses and banks

func _test_buses(sfx) -> void:
	for name in [SfxLib.MUSIC_BUS, SfxLib.EFFECTS_BUS, SfxLib.AMBIENCE_BUS]:
		var i := AudioServer.get_bus_index(name)
		var count := 0
		for b in range(AudioServer.bus_count):
			count += 1 if AudioServer.get_bus_name(b) == name else 0
		_check(i > 0 and AudioServer.get_bus_send(i) == &"Master" and count == 1, "one %s bus, sending to Master" % name)
	_check(sfx._voices.size() == SfxLib.VOICES and sfx._voices.all(func(p): return p.bus == &"Effects"), "all %d voices play on Effects" % SfxLib.VOICES)
	_check(sfx._amb.size() == 2 and sfx._amb.all(func(p): return p.bus == &"Ambience"), "the beds play on Ambience")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SfxLib.EFFECTS_BUS)), 0.0),
			"with no hush the Effects bus is at 0 dB: v2's sounds come out as they were")


func _test_banks(sfx) -> void:
	var banks: Array = SfxLib.bank_list(SfxLib)
	_check(banks[0]["id"] == "core" and banks[0]["cache"] == SfxLib.CACHE_PATH and banks[0]["key"] == SfxLib.cache_key(),
			"the core renders first, cached where and as v2 cached it")
	var ok := true
	for b in banks.slice(1):
		var mine: Array = SfxLib.BANKS[b["id"]]
		ok = ok and (b["names"] as Array).all(func(n): return mine.has(n)) and str(b["key"]).contains(FileAccess.get_md5("res://scripts/sfx.gd"))
	_check(ok, "each bank file's sounds are its own, keyed to sfx.gd and to itself (%s)" % ", ".join(banks.map(func(b): return b["id"])))
	var written := banks.slice(1).map(func(b): return str(b["id"]))
	print("banks written: %s" % (", ".join(written) if not written.is_empty() else "none yet (every v3 sound plays its fallback)"))
	# A v3 sound plays its fallback until it has its own.
	var t := "vine_grab"
	var own: Array = sfx._streams.get(t, [])
	sfx._lock.lock()
	sfx._streams.erase(t)
	sfx._lock.unlock()
	var p: AudioStreamPlayer = sfx.play(t)
	_check(p != null and (sfx._streams["land"] as Array).has(p.stream) and not sfx.rendered(t), "vine_grab, not rendered, plays land")
	var mine := SfxLib.to_wav(SfxLib.render("click"))
	sfx._lock.lock()
	sfx._streams[t] = [mine]
	sfx._lock.unlock()
	OS.delay_msec(SfxLib.FLAM_MSEC + 5)
	p = sfx.play(t)
	_check(p != null and p.stream == mine and sfx.rendered(t), "once rendered it plays its own")
	sfx._lock.lock()
	if own.is_empty():
		sfx._streams.erase(t)
	else:
		sfx._streams[t] = own
	sfx._lock.unlock()
	_quiet(sfx)
	# bank_ready: a bank not done holds back only the worlds that use it.
	for w in [0, 1, 2, 3, 4, 5, 6]:
		_check(sfx.bank_ready(w), "everything rendered: bank_ready(%d)" % w)
	var fake := {"id": "w3", "names": [], "takes": {}, "jitter": {}, "render": Callable(), "cache": "", "key": ""}
	var had_w3: bool = sfx._done.has("w3")
	var real_banks: Array = sfx._banks.duplicate()
	if not sfx._banks.any(func(b): return b["id"] == "w3"):
		sfx._banks.append(fake)
	sfx._done.erase("w3")
	_check(not sfx.bank_ready(3) and not sfx.bank_ready(0) and sfx.bank_ready(1) and sfx.bank_ready(2) and sfx.bank_ready(4),
			"World 3's bank still rendering: bank_ready(3) and (0) wait, Worlds 1, 2 and 4 don't")
	_check(not sfx.is_loaded(), "and is_loaded() waits for it")
	sfx._done["w3"] = true
	_check(sfx.bank_ready(3) and sfx.bank_ready(0), "done: they're ready")
	sfx._banks = real_banks
	if not had_w3:
		sfx._done.erase("w3")
	sfx.prefer_bank(5)
	_check(sfx._prefer[0] == "w5", "prefer_bank(5) puts World 5's bank next")
	sfx.prefer_bank(1)
	_check(sfx._prefer[0] == "", "and a v2 world asks for nothing")
	var times: Dictionary = sfx.boot_times()
	_check(times.has("init") and times.has("menus") and times.has("voices") and times.has("core") and times["order"][0] == "core",
			"boot_times has the init, the title's sounds and the core, the core first (%s)" % [times])
	# A bank file as Phase 1 writes them (here one written on the fly).
	var file := "user://test_sfx_bank_w3.gd"
	FileAccess.open(file, FileAccess.WRITE).store_string("\n".join([
		"extends RefCounted", "const S := preload(\"res://scripts/sfx.gd\")",
		"const NAMES := [\"vine_climb\", \"vine_grab\", \"tick\"]", "const TAKES := {\"vine_climb\": 2}",
		"const JITTER := {\"vine_climb\": 0.03}", "", "static func render(sound: String, take: int = 0) -> PackedFloat32Array:",
		"\treturn S.render(\"step\" if sound == \"vine_climb\" else \"land\", take)", ""]))
	var bank: Dictionary = SfxLib.load_bank("w3", "user://test_sfx_banks", file)
	_check(bank.get("names") == ["vine_climb", "vine_grab"] and bank["takes"] == {"vine_climb": 2} and bank["jitter"] == {"vine_climb": 0.03}
			and str(bank["cache"]).ends_with("test_sfx_banks/sfx_cache_w3.bin"),
			"a bank file gives its sounds (only its own: World 4's tick is refused), takes and jitter")
	_check(str(bank["key"]).begins_with(FileAccess.get_md5("res://scripts/sfx.gd") + "+" + FileAccess.get_md5(file)),
			"its cache key hashes sfx.gd and the bank file")
	var r: Callable = bank["render"]
	_check(r.call("vine_climb", 1) == SfxLib.render("step", 1), "its render() is called as the core's is")
	_check(SfxLib.load_bank("w9", "", file).is_empty() and SfxLib.load_bank("w3", "", "user://no_such_bank.gd").is_empty(),
			"no bank for an id BANKS doesn't have, or a file that isn't there")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	# The render queue on two stand-in banks: the preferred first, each cached.
	var dir := "user://test_sfx_banks"
	SpikeLib.wipe(dir)
	var two: Array = SpikeLib.dummy_banks(dir).filter(func(b): return b["id"] in ["story", "modes"])
	var streams := {}
	var lock := Mutex.new()
	var done := {}
	var stamps := {}
	SfxLib._render_banks(streams, lock, [false], two, ["story", "modes"], done, ["modes"], stamps)
	var count := 0
	for b in two:
		count += (b["names"] as Array).size()
	_check(done.size() == 2 and streams.size() == count and stamps["order"] == ["modes", "story"],
			"the render takes the preferred bank first, and fills in every sound (%s)" % [stamps.get("order")])
	_check(FileAccess.file_exists(dir.path_join("sfx_cache_story.bin")) and FileAccess.file_exists(dir.path_join("sfx_cache_modes.bin")),
			"each bank leaves its own cache")
	var again := {}
	var st2 := {}
	for b in two:
		SfxLib.render_bank(again, lock, [false], b, st2)
	var same := again.size() == streams.size()
	for n in streams:
		same = same and again.has(n) and (again[n][0] as AudioStreamWAV).data == (streams[n][0] as AudioStreamWAV).data
	_check(same and st2.has("story:cached") and st2.has("modes:cached"), "and the next boot reads them back, byte for byte")
	var cancelled := {}
	_check(not SfxLib.render_bank(cancelled, lock, [true], {"id": "x", "names": ["a"], "takes": {}, "render": Callable(), "cache": "", "key": ""}, {}),
			"a render called off stops before its first sound")
	# Two threads, as Sfx runs them: the bank waits for the core's title sounds.
	var core := {"id": "core", "names": ["click", "select", "back", "pause", "talk", "talk_low", "talk_breath", "whoosh", "bell", "clear"],
			"takes": {}, "jitter": {}, "render": Callable(SfxLib, "render"), "cache": "", "key": ""}
	var pair: Array = [core, two[0]]
	var st3 := {}
	var got := {}
	var done3 := {}
	var q3 := ["core", str(two[0]["id"])]
	var threads: Array[Thread] = []
	for i in range(2):
		var th := Thread.new()
		th.start(Callable(SfxLib, "_render_banks").bind(got, lock, [false], pair, q3, done3, [""], st3))
		threads.append(th)
	for th in threads:
		th.wait_to_finish()
	_check(done3.size() == 2 and int(st3.get(str(two[0]["id"]) + ":start", -1)) >= int(st3.get("voices", 1 << 30)),
			"with two threads, a bank starts only once the core's title sounds are made (%s)" % [st3])
	SpikeLib.wipe(dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


# ---------------------------------------------------------------- v3: the hush

func _bus_db(name: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(name))


func _test_hush(sfx) -> void:
	var bus := AudioServer.get_bus_index(SfxLib.MUSIC_BUS)
	var slot: int = SfxLib._lowpass_slot(bus)
	var lp := AudioServer.get_bus_effect(bus, slot) as AudioEffectLowPassFilter
	sfx.set_lowpass(false)
	sfx.set_hush(0.0)
	sfx._aim_hush(0.0)
	sfx._tick_music(1.0)
	sfx.set_hush(1.0)
	sfx._tick_music(0.15)
	_check(absf(_bus_db(SfxLib.MUSIC_BUS) + 4.0) < 0.1 and absf(_bus_db(SfxLib.EFFECTS_BUS) + 2.5) < 0.1
			and absf(_bus_db(SfxLib.AMBIENCE_BUS) + 6.0) < 0.1, "set_hush(1) glides: halfway after 0.15 s (%.1f, %.1f, %.1f dB)" % [
			_bus_db(SfxLib.MUSIC_BUS), _bus_db(SfxLib.EFFECTS_BUS), _bus_db(SfxLib.AMBIENCE_BUS)])
	_check(absf(lp.cutoff_hz - sqrt(20000.0 * 700.0)) < 5.0 and AudioServer.is_bus_effect_enabled(bus, slot),
			"the music's low-pass halfway on an exponential curve (%d Hz)" % roundi(lp.cutoff_hz))
	sfx._tick_music(0.16)
	_check(is_equal_approx(_bus_db(SfxLib.MUSIC_BUS), -8.0) and is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), -5.0)
			and is_equal_approx(_bus_db(SfxLib.AMBIENCE_BUS), -12.0) and is_equal_approx(lp.cutoff_hz, 700.0),
			"in 0.3 s: music -8 dB and muffled to 700 Hz, effects -5 (never more), ambience -12")
	sfx.set_hush(0.6)
	sfx._tick_music(0.31)
	_check(is_equal_approx(sfx.hush_level(), 0.6) and absf(_bus_db(SfxLib.MUSIC_BUS) + 4.8) < 0.01 and absf(_bus_db(SfxLib.EFFECTS_BUS) + 3.0) < 0.01,
			"a Hush zone's 0.6: music -4.8, effects -3")
	sfx.set_lowpass(true)
	sfx._tick_music(0.5)
	_check(is_equal_approx(lp.cutoff_hz, SfxLib.LOWPASS_HZ), "with the flame low too, the lower cutoff wins (%d Hz)" % roundi(lp.cutoff_hz))
	sfx.set_lowpass(false)
	sfx._tick_music(0.6)
	_check(absf(lp.cutoff_hz - sfx.hush_hz()) < 1.0 and sfx.hush_hz() < 3000.0, "the flame back up: the hush's own cutoff (%d Hz)" % roundi(lp.cutoff_hz))
	# Every frame is fine: it only glides.
	for i in range(30):
		sfx.set_hush(0.6)
		sfx._tick_music(1.0 / 120.0)
	_check(is_equal_approx(sfx.hush_level(), 0.6), "set_hush every frame holds steady")
	sfx.set_hush(0.0)
	sfx._tick_music(0.31)
	_check(is_equal_approx(_bus_db(SfxLib.MUSIC_BUS), 0.0) and is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), 0.0)
			and is_equal_approx(_bus_db(SfxLib.AMBIENCE_BUS), 0.0) and not AudioServer.is_bus_effect_enabled(bus, slot),
			"set_hush(0): every bus back to 0 dB and the filter off")
	# A pulse: fast in, held, back out over the glide.
	sfx.hush_pulse(0.5, 0.8)
	sfx._tick_music(0.1)
	_check(is_equal_approx(sfx.hush_level(), 0.8), "hush_pulse(0.5, 0.8) is in within 0.1 s")
	sfx._tick_music(0.3)
	_check(is_equal_approx(sfx.hush_level(), 0.8), "and holds")
	sfx._tick_music(0.2)
	_check(sfx.hush_level() > 0.0 and sfx.hush_level() < 0.8, "then lets go (%.2f)" % sfx.hush_level())
	sfx._tick_music(0.3)
	_check(is_equal_approx(sfx.hush_level(), 0.0), "back to nothing")
	sfx.set_hush(0.3)
	sfx.hush_pulse(0.2, 0.9)
	sfx._tick_music(0.1)
	sfx.hush_pulse(0.5, 0.5)
	sfx._tick_music(0.3)
	_check(is_equal_approx(sfx.hush_level(), 0.9), "overlapping pulses keep the deeper one...")
	sfx._tick_music(0.35)
	sfx._tick_music(0.3)
	_check(is_equal_approx(sfx.hush_level(), 0.3), "...and the later end, then fall back to set_hush's 0.3")
	sfx.set_hush(0.0)
	sfx._aim_hush(0.0)
	sfx._tick_music(0.0)
	# The telegraphed silence: effects may drop past 5 dB, for that second only.
	sfx.set_hush(1.0)
	sfx._tick_music(0.31)
	sfx.hush_pulse(1.0, 1.0, true)
	sfx._tick_music(0.1)
	_check(is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), -SfxLib.HUSH_SILENCE_DB), "a silence takes the effects to -18 dB (%.1f)" % _bus_db(SfxLib.EFFECTS_BUS))
	sfx._tick_music(1.0)
	sfx._tick_music(0.1)
	_check(is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), -SfxLib.HUSH_EFFECTS_DB), "then back to the 5 dB cap (%.1f)" % _bus_db(SfxLib.EFFECTS_BUS))
	sfx.set_hush(0.0)
	sfx._aim_hush(0.0)
	sfx._tick_music(0.2)
	sfx.play("hush_silence")
	sfx._tick_music(0.85)
	_check(is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), 0.0), "hush_silence's breath swells in the clear")
	sfx._tick_music(0.1)
	_check(_bus_db(SfxLib.EFFECTS_BUS) < -15.0, "then, 0.9 s in, all sound cuts out (%.1f dB)" % _bus_db(SfxLib.EFFECTS_BUS))
	sfx._tick_music(0.25)
	var held := _bus_db(SfxLib.EFFECTS_BUS) < -15.0
	sfx._tick_music(0.4)
	_check(held and is_equal_approx(_bus_db(SfxLib.EFFECTS_BUS), 0.0) and is_equal_approx(sfx.hush_level(), 0.0),
			"held until the Snuff lands, 1.2 s in, then lifts")
	_quiet(sfx)


# ---------------------------------------------------------------- v3: stems

func _burst_slots(mixed: PackedVector2Array, rate: float) -> Array:
	var ons := []
	var inb := false
	var quiet := 0
	for i in range(mixed.size()):
		var v := absf(mixed[i].x)
		if inb:
			quiet = quiet + 1 if v < SpikeLib.QUIET else 0
			if quiet > SpikeLib.QUIET_FRAMES:
				inb = false
		elif v > SpikeLib.THRESHOLD:
			inb = true
			quiet = 0
			ons.append(i)
	return ons


func _test_stems(sfx) -> void:
	# Offline, through the engine's own mixer: five stems in one
	# AudioStreamSynchronized stay aligned to the sample for ten loops (QOA,
	# as the music is imported), and a stem's volume applies while it plays.
	var rate := AudioServer.get_mix_rate()
	for pcm in [false, true]:
		var stems: Array = SpikeLib.make_stems(pcm, 4.0)
		var sync: AudioStream = ClassDB.instantiate("AudioStreamSynchronized")
		sync.set("stream_count", stems.size())
		for i in range(stems.size()):
			sync.call("set_sync_stream", i, stems[i])
		var pb := sync.instantiate_playback()
		pb.start(0.0)
		var mixed := PackedVector2Array()
		var loops := 10
		while mixed.size() < roundi(4.0 * loops * rate):
			mixed.append_array(pb.mix_audio(1.0, 1024))
		var a: Dictionary = SpikeLib.analyze(_burst_slots(mixed, rate), rate)
		_check(int(a["found"]) == loops * 2 * SpikeLib.STEMS and float(a["drift"]) <= 2.0 and int(a["stray"]) == 0,
				"%s stems in one AudioStreamSynchronized stay aligned through %d loops (%d bursts, drift %d frames)" % [
				"PCM" if pcm else "QOA", loops, a["found"], roundi(float(a["drift"]))])
		if pcm:
			continue
		# Stem 2 turned off mid-play: its bursts stop, the others carry on.
		sync.call("set_sync_stream_volume", 2, SfxLib.STEM_OFF_DB)
		var later := PackedVector2Array()
		while later.size() < roundi(8.0 * rate):
			later.append_array(pb.mix_audio(1.0, 1024))
		var b: Dictionary = SpikeLib.analyze(_burst_slots(later, rate), rate)
		_check(int(b["found"]) == 4 * (SpikeLib.STEMS - 1), "a stem's volume applies while it plays: %d bursts once stem 2 is off" % b["found"])
		pb.stop()
	# Through Sfx: a stem set plays, holds, glides.
	var names := ["t_a", "t_b", "t_c", "t_d", "t_e"]
	var streams: Array = SpikeLib.make_stems(true, 4.0)
	sfx.register_stems("t5", names, streams)
	sfx.stop_music(0.0)
	sfx.play_stems("t5", {"t_e": -80.0})
	var p: AudioStreamPlayer = sfx._music[sfx._music_cur]
	var s: AudioStream = p.stream
	_check(p.playing and s != null and s.get_class() == "AudioStreamSynchronized" and int(s.get("stream_count")) == 5
			and sfx.stem_mode() == "sync" and sfx.music_playing() == "t5", "play_stems plays the set as one AudioStreamSynchronized")
	_check(is_equal_approx(s.call("get_sync_stream_volume", 4), -80.0) and is_equal_approx(s.call("get_sync_stream_volume", 0), 0.0),
			"each stem at its level: the ones given, the rest at 0 dB")
	sfx._tick_music(0.5)
	sfx.play_stems("t5")
	sfx.play_music("t5")
	_check(sfx._music[sfx._music_cur] == p and p.playing and p.stream == s, "asking for the set playing doesn't restart it")
	sfx.set_stem("t_a", -18.0, 1.0)
	sfx._tick_music(0.5)
	var half := float(s.call("get_sync_stream_volume", 0))
	_check(half < -2.0 and half > -18.0 and is_equal_approx(half, sfx.stem_db("t_a")), "set_stem glides (%.1f dB halfway)" % half)
	sfx._tick_music(0.6)
	_check(is_equal_approx(s.call("get_sync_stream_volume", 0), -18.0), "and lands on its level")
	sfx.set_stem("t_e", 0.0, 0.0)
	_check(is_equal_approx(s.call("get_sync_stream_volume", 4), 0.0), "at once, with 0 s")
	sfx.set_stem("t_b", -80.0, 2.0)
	sfx._tick_music(2.1)
	_check(is_equal_approx(s.call("get_sync_stream_volume", 1), -80.0) and sfx._stem_speed.is_empty(), "a stem faded out rests at -80 dB")
	sfx.play_stems("t5", {"t_b": 0.0})
	sfx._tick_music(0.6)
	_check(is_equal_approx(s.call("get_sync_stream_volume", 1), 0.0) and sfx._music[sfx._music_cur] == p,
			"replaying the set with levels glides them in, without a restart")
	sfx.play_music("chapel")
	_check(sfx.stem_mode() == "" and sfx.music_playing() == "chapel", "a track after a set: no set playing")
	sfx.play_stems("t5")
	_check(is_equal_approx(sfx.stem_db("t_a"), 0.0), "a set started again starts its stems at 0 dB")
	sfx.stop_music(0.0)
	sfx._extra_stems.erase("t5")


func _tone(hz: float, secs: float) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	s.resize(roundi(secs * SfxLib.RATE) + SfxLib.MUSIC_PAD)
	for i in range(s.size()):
		s[i] = 0.3 * sin(TAU * hz * i / SfxLib.RATE)
	return SfxLib.loop_music(SfxLib.to_wav(s)) as AudioStreamWAV


func _test_premix(sfx) -> void:
	## hush_final with its stems missing: the premixes stand in, following
	## the stems that are up; with those missing too, the boss track.
	var stems: Array = SfxLib.STEMS["hush_final"]
	var keep := {}
	for k in stems + ["hush_final_a", "hush_final_d", "hush_final_b", "hush_final_c", "stems:hush_final"]:
		if sfx._music_cache.has(k):
			keep[k] = sfx._music_cache[k]
	for st in stems:
		sfx._music_cache[st] = null
	sfx._music_cache.erase("stems:hush_final")
	var mixes := {"hush_final_a": _tone(220.0, 2.0), "hush_final_d": _tone(275.0, 2.0), "hush_final_b": _tone(330.0, 2.0), "hush_final_c": _tone(440.0, 2.0)}
	for k in mixes:
		sfx._music_cache[k] = mixes[k]
	sfx.stop_music(0.0)
	sfx.play_stems("hush_final", {"hush_final_wick": -80.0})
	var cur := func() -> AudioStream: return sfx._music[sfx._music_cur].stream
	_check(sfx.stem_mode() == "premix" and cur.call() == mixes["hush_final_a"], "stems missing: the full premix stands in")
	sfx._tick_music(0.5)
	sfx.set_stem("hush_final_drums", -80.0, 0.0)
	_check(cur.call() == mixes["hush_final_d"], "drums eaten, the choir still up: every stem but the drums")
	sfx._tick_music(1.2)   # (the fight goes on: that crossfade is done before the choir goes, 65% to 47%)
	sfx.set_stem("hush_final_choir", -80.0, 0.0)
	_check(cur.call() == mixes["hush_final_b"] and sfx._premix == "hush_final_b", "the choir eaten: the void, wick and bells mix")
	var p: AudioStreamPlayer = sfx._music[sfx._music_cur]
	var q: AudioStreamPlayer = sfx._music[1 - sfx._music_cur]
	_check(p.playing and q.playing and sfx._fade_goal[1 - sfx._music_cur] == 0.0, "crossfading from one to the other")
	sfx.set_stem("hush_final_bells", -80.0, 0.0)
	_check(cur.call() == mixes["hush_final_c"], "the bells sunk: just the void and the wick")
	sfx.set_stem("hush_final_bells", 0.0, 0.0)
	_check(cur.call() == mixes["hush_final_b"], "a ring brings the bells back")
	sfx.stop_music(0.0)
	for k in mixes:
		sfx._music_cache[k] = null
	sfx._music_cache["boss"] = _raw_track("boss")
	sfx.play_music("hush_final")
	_check(sfx.stem_mode() == "track" and cur.call() == sfx._music_cache["boss"] and sfx.music_playing() == "hush_final",
			"no stems and no premixes: the boss track stands in")
	sfx.stop_music(0.0)
	for k in stems + mixes.keys() + ["stems:hush_final"]:
		sfx._music_cache.erase(k)
	for k in keep:
		sfx._music_cache[k] = keep[k]


func _test_tape(sfx) -> void:
	sfx._music_cache["chapel"] = _raw_track("chapel")
	sfx._music_cache["boss"] = _raw_track("boss")
	sfx.stop_music(0.0)
	sfx.play_music("chapel")
	sfx._tick_music(0.5)
	var p: AudioStreamPlayer = sfx._music[sfx._music_cur]
	sfx.tape_stop(0.35)
	sfx._tick_music(0.2)
	_check(p.pitch_scale < 0.7 and p.pitch_scale > 0.4 and not p.stream_paused and sfx.tape_stopped(),
			"tape_stop ramps the music's pitch down (%.2f after 0.2 s)" % p.pitch_scale)
	sfx._tick_music(0.2)
	_check(is_equal_approx(p.pitch_scale, SfxLib.TAPE_FLOOR) and p.stream_paused, "and pauses it at %.2f, never 0" % SfxLib.TAPE_FLOOR)
	sfx.play_music("chapel")
	_check(sfx._music[sfx._music_cur] == p and p.stream_paused, "asking for the track then leaves it held")
	sfx.tape_go(0.25)
	_check(not p.stream_paused and not sfx.tape_stopped(), "tape_go lets it go at once")
	sfx._tick_music(0.125)
	_check(p.pitch_scale > 0.5 and p.pitch_scale < 0.75, "ramping back up (%.2f)" % p.pitch_scale)
	sfx._tick_music(0.2)
	_check(is_equal_approx(p.pitch_scale, 1.0), "to its own pitch")
	sfx.tape_stop(0.0)
	_check(p.stream_paused and is_equal_approx(p.pitch_scale, SfxLib.TAPE_FLOOR), "tape_stop(0): at once")
	sfx.play_music("boss")
	var b: AudioStreamPlayer = sfx._music[sfx._music_cur]
	_check(b != p and not b.stream_paused and is_equal_approx(b.pitch_scale, 1.0) and not sfx.tape_stopped(), "a new track starts time again")
	sfx.tape_stop(0.0)
	sfx.stop_music(0.0)
	_check(not sfx._music[0].playing and not sfx._music[1].playing and not sfx._music[0].stream_paused and not sfx.tape_stopped(),
			"stop_music during a time stop stops it clean")


func _test_seek(sfx) -> void:
	sfx._music_cache["title"] = _raw_track("title")
	sfx.stop_music(0.0)
	sfx.play_music("title")
	sfx._tick_music(0.5)
	var p: AudioStreamPlayer = sfx._music[sfx._music_cur]
	var loop: float = SfxLib.loop_seconds(p.stream)
	_check(loop > 20.0 and absf(loop - (p.stream as AudioStreamWAV).loop_end / 22050.0) < 0.001, "a track's loop is its loop_end (%.2f s)" % loop)
	sfx.seek_music(12.0)
	var q: AudioStreamPlayer = sfx._music[sfx._music_cur]
	_check(q != p and q.stream == p.stream and absf(q.get_playback_position() - 12.0) < 0.2 and sfx._fade_goal[1 - sfx._music_cur] == 0.0,
			"seek_music(12) crossfades to the same track 12 s in (%.2f s)" % q.get_playback_position())
	sfx._tick_music(SfxLib.SEEK_FADE + 0.01)
	_check(not p.playing and q.playing, "in %.2f s" % SfxLib.SEEK_FADE)
	sfx.seek_music(12.0 + q.get_playback_position() - 12.0)
	_check(sfx._music[sfx._music_cur] == q, "already there: no jump")
	sfx.seek_music(loop * 3.0 + 5.0)
	var r: AudioStreamPlayer = sfx._music[sfx._music_cur]
	_check(r != q and absf(r.get_playback_position() - 5.0) < 0.2, "the feature clock wraps with the loop (%.2f s)" % r.get_playback_position())
	sfx.music_muted = true
	sfx.seek_music(8.0)
	sfx.music_muted = false
	var m: AudioStreamPlayer = sfx._music[sfx._music_cur]
	_check(m.playing and absf(m.get_playback_position() - 8.0) < 0.3, "muted, it remembers: unmuted, the track starts in step (%.2f s)" % m.get_playback_position())
	sfx.play_music("chapel")
	_check(sfx._anchor.is_empty(), "a new track forgets the old one's step")
	sfx.stop_music(0.0)


func _test_ambience(sfx) -> void:
	var bed := _tone(180.0, 1.0)
	sfx._music_cache["amb_test"] = bed
	sfx.play_ambience("amb_test")
	var a: AudioStreamPlayer = sfx._amb[sfx._amb_cur]
	_check(a.playing and a.stream == bed and a.bus == &"Ambience" and a.volume_db < -60.0 and sfx.ambience_playing() == "amb_test",
			"play_ambience fades a bed in on the Ambience bus")
	sfx._tick_music(1.01)
	_check(is_equal_approx(a.volume_db, SfxLib.AMBIENCE_DB), "in %.1f s, to %.0f dB" % [SfxLib.AMBIENCE_FADE, SfxLib.AMBIENCE_DB])
	sfx.play_ambience("amb_test", -6.0)
	_check(sfx._amb[sfx._amb_cur] == a and is_equal_approx(a.volume_db, SfxLib.AMBIENCE_DB - 6.0), "the same bed again only takes the new level")
	sfx.muted = true
	_check(not a.playing and sfx.ambience_playing() == "amb_test", "muting the sounds silences the bed, remembering it")
	sfx.muted = false
	_check(sfx._amb[sfx._amb_cur].playing and sfx._amb[sfx._amb_cur].stream == bed, "unmuting brings it back")
	sfx.music_muted = true
	_check(sfx._amb[sfx._amb_cur].playing, "muting the music leaves it")
	sfx.music_muted = false
	var other := _tone(240.0, 1.0)
	sfx._music_cache["amb_other"] = other
	sfx._tick_music(0.5)
	sfx.play_ambience("amb_other")
	_check(sfx._amb[0].playing and sfx._amb[1].playing and sfx._amb[sfx._amb_cur].stream == other, "another bed crossfades")
	sfx.stop_ambience(0.5)
	sfx._tick_music(0.6)
	_check(not sfx._amb[0].playing and not sfx._amb[1].playing and sfx.ambience_playing() == "", "stop_ambience fades it out and forgets it")
	sfx.play_ambience("amb_orchard_not_written")
	_check(not sfx._amb[0].playing and not sfx._amb[1].playing, "a bed not written yet is just quiet")
	sfx.stop_ambience(0.0)
	sfx._music_cache.erase("amb_test")
	sfx._music_cache.erase("amb_other")


func _test_track_fallbacks(sfx) -> void:
	## A v3 track music.py hasn't written yet plays its stand-in.
	var tried := 0
	for track in SfxLib.TRACK_FALLBACK:
		if SfxLib.STEMS.has(track) or FileAccess.file_exists(SfxLib.MUSIC_PATH % track):
			continue
		tried += 1
		sfx._music_cache.erase(track)
		var s: AudioStream = sfx._music_stream(track)
		var want: AudioStream = sfx._music_stream(str(SfxLib.TRACK_FALLBACK[track]))
		_check(s != null and s == want, "%s, not written yet, plays %s" % [track, SfxLib.TRACK_FALLBACK[track]])
	if tried == 0:
		print("skipped: every v3 track is written")
	sfx.stop_music(0.0)
	sfx.play_music("orchard")
	_check(sfx.music_playing() == "orchard" and sfx._music[sfx._music_cur].playing, "play_music('orchard') plays (and reports its own name)")
	sfx.stop_music(0.0)
