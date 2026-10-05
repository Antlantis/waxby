extends Node
## Every sound effect in WAXBY, synthesized at startup: no audio files. The
## palette is a cathedral's: harpsichord plucks, small glassy bells, organ
## pipes, a sung "ahh", great bronze bells, stone, bone, armor, wax and water,
## all tuned to D minor so rising tones stay in key with the music. Rendering
## runs on worker threads and is cached in the OS's cache folder (keyed to the
## scripts that make the sounds; cache_home()), so after the first boot the
## sounds load in a blink. The
## music is the one exception: looping WAVs rendered offline by
## tools/audio/music.py, played here on a Music bus with crossfades, ducking
## and a low-pass for low life. Autoloaded as Sfx.
##
##     Sfx.play("stomp")                 Sfx.play("ember", Sfx.note(streak))
##     Sfx.play_music("chapel")          Sfx.duck_music(9.0, 2.5)
##     var v = Sfx.play("flare_charge")  Sfx.release(v)   # a held sound, let go
##     Sfx.set_lowpass(true)             # the flame is low: muffle the music
##     Sfx.play("talk", Sfx.voice_note(voice, i))  # a speaker's i-th blip, in key
##
## v3 (contract.md section 14):
##
##     Sfx.set_hush(0.6)                 # a Hush zone: music muffled and down, effects a little
##     Sfx.hush_pulse(0.4, 0.8)          # a short silence tell
##     Sfx.tell("gust_tell", knob("gust_tell"))   # a tell's sound fitted to this tell's length
##     Sfx.play("secret_hum", 1.0, 0.4)  # quieter (a gain: distance falloff)
##     Sfx.play_stems("hush_final", {"hush_final_wick": -80.0})
##     Sfx.set_stem("hush_final_drums", -80.0, 2.0)   # the Hush eats the drums
##     Sfx.tape_stop()  Sfx.tape_go()    # the Tinker stops time, and lets it go
##     Sfx.seek_music(world.ftime)       # the carillon back on the tick after a pause
##     Sfx.play_ambience("amb_orchard")  Sfx.stop_ambience()
##     Sfx.bank_ready(3)                 # World 3's sounds are rendered (else they fall back)
##
## The buses: Master (a hard limiter), Music (its low-pass), Effects (every
## voice) and Ambience (the world beds). The sounds come in banks: the core
## (v2's, CORE, rendered by this script) and the v3 banks, each a script
## scripts/sfx_<id>.gd with its own NAMES, TAKES, JITTER, TELL_AT and a static
## render(sound, take) built from the primitives here. Until a sound is
## rendered (or while its bank isn't written yet) play() plays its FALLBACK,
## a v2 sound, so nothing that announces a threat is ever silent.

const SettingsLib := preload("res://scripts/settings.gd")
const RATE := 22050
const VOICES := 16
const SETTINGS_PATH := "user://settings.json"   # SettingsLib.PATH: shared with the rest of the game
# v2's sounds, the core bank, rendered by this script in this order: the
# menus, then the story's voices (the intro's first lines must never be
# silent), then what a fight needs in its first seconds, then the rest roughly
# by size, the long bells and fanfares last.
const CORE := [
	"click", "select", "back", "pause",
	# the story's voices
	"talk", "talk_low", "talk_breath", "whoosh",
	# moving and fighting
	"step", "jump", "land", "double_jump", "slash", "ember", "stomp", "bump", "slash_hit", "enemy_hit",
	"hurt", "crit", "guard_up", "guard_block", "perfect_guard", "finisher", "guard_break", "spark",
	"flare_throw", "fizzle", "knife_throw", "knife_hit", "maul_hit", "clank", "knell", "mote", "wisp_pop",
	"grave_step", "smoke_step", "rush", "backstab", "parry", "arrow_draw", "arrow_fly", "shield_clang",
	"bash", "bones", "bat", "clang", "spikes", "lava", "wax", "flask", "item_drop", "chain_step",
	"heartbeat", "douse", "drip", "splash", "dripkin_splat", "wing_sip", "wing_pop", "anvil_drop",
	# the world, loot and the rest of the callings
	"block_break", "relic_drop", "equip", "salvage", "bank", "relic_common", "relic_magic", "reliquary",
	"relight", "snuff", "lantern_light", "mimic_snore", "mimic_chomp", "waxfall", "rubble",
	"flare_charge", "flare_burst", "wisp_call", "curdle", "brazier_snuff", "snuffer_whisper",
	"pool_reclaim", "relic_rare", "sigil", "altar", "boss_hit", "boss_slam", "snuffer_slam",
	"boss_roar", "toll_dead", "peal", "snuffer_scream", "level_up", "clear", "relic_legendary",
	"boss_die", "bell",
]
# The v3 sounds, bank by bank (contract.md section 14). A bank renders in the
# background after the core, in BANK_ORDER, and is cached on its own; its
# recipes live in scripts/sfx_<id>.gd. Within a bank the names are in the
# order they're needed: features, then monsters, then the boss, the long ones
# last.
const BANK_STORY := [
	"talk_wood", "talk_tick", "talk_glass", "anvil", "bell_choke", "give", "pull", "clock_strike", "lull",
	# the secret doors, from 1-3 on
	"secret_hum", "secret_found", "silver_bell",
]
const BANK_W3 := [
	"vine_grab", "vine_climb", "vine_creak", "vine_snap", "spore_swell", "spore_puff", "spore_choke",
	"spore_burn", "glowfruit_drop", "skull_lantern", "root_burst", "thorn_snag",
	"dig_rustle", "root_pop", "dizzy", "weepcap_inhale", "hound_howl", "hound_growl", "hound_bite",
	"hound_pant", "bone_rattle", "bone_skitter", "creep_rattle", "creep_snap", "omen_spores",
	"root_creak", "bough_sweep", "bloom_open", "bloom_close", "bloom_decoy_puff", "rootmother_dig",
	"seed_spit", "seed_splat", "rootmother_breath", "thorn_crown", "rootmother_roar", "rootmother_wilt",
	"rootmother_die",
]
const BANK_W4 := [
	"tick", "ice_slide", "ice_squeak", "ice_crack", "rime_melt", "rime_freeze", "icicle_tell", "icicle_fall",
	"icicle_shatter", "belt_run", "belt_reverse", "gear_tick", "gear_clunk", "pendulum_swing", "clock_chime",
	"wind_up", "tick_step", "spring_boing", "gear_roll", "gear_catch", "gear_spark", "ice_creak", "ice_spike",
	"ice_shatter", "heavy_step", "owl_tick", "owl_hoot", "owl_screech", "omen_tick",
	"tinker_windup", "tinker_throw", "clock_tock", "tinker_stop", "tinker_go", "chime_hour", "wrong_hour",
	"tinker_open", "tinker_step", "tinker_overwind", "midnight_chimes", "tinker_die",
]
const BANK_W5 := [
	"gust_tell", "gust", "glass_step", "glass_crack", "glass_shatter", "void_whoosh", "dawnglass_on",
	"dawnglass_off", "prism_lamp", "pennant_flap", "shard_hum",
	"glass_tink", "glass_break", "gust_inhale", "gust_blow", "glass_chime", "prism_hum", "prism_lock",
	"beam_fire", "glass_shing", "glass_clang", "glass_slide", "omen_glass_break",
	"saint_charge", "beam_lock", "beam_reflect", "saint_rose", "gale", "saint_choir", "saint_crack",
	"saint_split", "saint_refract", "saint_die",
]
const BANK_W6 := [
	"lake_step", "float_sink", "buoy_toll", "still_crack", "grasp_hiss", "candle_light", "buoy_light",
	"hush_near", "tide_rise",
	"hush_pop", "stitch_snap", "gulp_inhale", "choke_spit", "echo_whisper", "unwick_fade", "lake_still",
	"coil_splash", "coil_hiss",
	"hush_still", "bell_peal_sunken", "grasp_rise", "snuff_slam", "inhale_roar", "choke", "flame_freed",
	"gaze_lock", "deep_quiet", "hush_eye_open", "hush_wince", "hush_blink", "hush_silence",
	"hush_scream_silent", "finale_ring",
]
const BANK_MODES := [
	"trial_go", "trial_tick", "candle_lit", "medal", "trial_fail", "descend", "glimmer", "cart_bell",
	"hushing", "wax_cast", "drip_plop", "record", "seal_stamp", "rush_bell", "cosmetic_unlock",
	"candlemark", "depth_mark",
]
const BANKS := {"story": BANK_STORY, "w3": BANK_W3, "w4": BANK_W4, "w5": BANK_W5, "w6": BANK_W6, "modes": BANK_MODES}
const BANK_ORDER := ["story", "w3", "w4", "w5", "w6", "modes"]
const BANK_PATH := "res://scripts/sfx_%s.gd"
const V3_NAMES := BANK_STORY + BANK_W3 + BANK_W4 + BANK_W5 + BANK_W6 + BANK_MODES
# Every name play() answers to (kits and cutscenes check a name against this
# before playing it): the core and every v3 name, rendered or not.
const NAMES := CORE + V3_NAMES
# What a v3 sound plays until it is rendered: always a core sound, chosen to
# carry the same meaning (a creak for a creak, a tell's length for a tell),
# so a tell is never silent. The contract's own picks are kept (its
# "crumble" is block_break, the crumble ledge's sound).
const FALLBACK := {
	# the story and the secret doors
	"talk_wood": "talk", "talk_tick": "talk", "talk_glass": "talk", "anvil": "relic_common",
	"bell_choke": "toll_dead", "give": "bank", "pull": "whoosh", "clock_strike": "bell", "lull": "bell",
	"secret_hum": "mote", "secret_found": "sigil", "silver_bell": "bell",
	# World 3
	"vine_grab": "land", "vine_climb": "step", "vine_creak": "arrow_draw", "vine_snap": "block_break",
	"spore_swell": "curdle", "spore_puff": "wing_pop", "spore_choke": "douse", "spore_burn": "whoosh",
	"glowfruit_drop": "ember", "skull_lantern": "lantern_light", "root_burst": "boss_slam", "thorn_snag": "spikes",
	"dig_rustle": "grave_step", "root_pop": "wing_pop", "dizzy": "chain_step", "weepcap_inhale": "mimic_snore",
	"hound_howl": "boss_roar", "hound_growl": "mimic_snore", "hound_bite": "mimic_chomp", "hound_pant": "talk_breath",
	"bone_rattle": "bones", "bone_skitter": "bones", "creep_rattle": "bones", "creep_snap": "bones",
	"omen_spores": "wing_pop",
	"root_creak": "arrow_draw", "bough_sweep": "rush", "bloom_open": "relic_magic", "bloom_close": "guard_block",
	"bloom_decoy_puff": "wing_pop", "rootmother_dig": "rubble", "seed_spit": "arrow_fly", "seed_splat": "dripkin_splat",
	"rootmother_breath": "snuffer_whisper", "thorn_crown": "spikes", "rootmother_roar": "boss_roar",
	"rootmother_wilt": "boss_hit", "rootmother_die": "boss_die",
	# World 4
	"tick": "click", "ice_slide": "step", "ice_squeak": "step", "ice_crack": "block_break", "rime_melt": "drip",
	"rime_freeze": "relic_common", "icicle_tell": "arrow_draw", "icicle_fall": "whoosh", "icicle_shatter": "block_break",
	"belt_run": "click", "belt_reverse": "clank", "gear_tick": "click", "gear_clunk": "bump", "pendulum_swing": "whoosh",
	"clock_chime": "knell",
	"wind_up": "arrow_draw", "tick_step": "step", "spring_boing": "chain_step", "gear_roll": "rush", "gear_catch": "clang",
	"gear_spark": "spark", "ice_creak": "arrow_draw", "ice_spike": "spikes", "ice_shatter": "block_break",
	"heavy_step": "land", "owl_tick": "click", "owl_hoot": "pause", "owl_screech": "bat", "omen_tick": "click",
	"tinker_windup": "arrow_draw", "tinker_throw": "flare_throw", "clock_tock": "talk_low", "tinker_stop": "curdle",
	"tinker_go": "whoosh", "chime_hour": "knell", "wrong_hour": "clank", "tinker_open": "reliquary",
	"tinker_step": "bump", "tinker_overwind": "boss_roar", "midnight_chimes": "peal", "tinker_die": "boss_die",
	# World 5
	"gust_tell": "flare_charge", "gust": "whoosh", "glass_step": "mote", "glass_crack": "crit",
	"glass_shatter": "block_break", "void_whoosh": "whoosh", "dawnglass_on": "wisp_call", "dawnglass_off": "fizzle",
	"prism_lamp": "lantern_light", "pennant_flap": "wing_sip", "shard_hum": "mote",
	"glass_tink": "relic_common", "glass_break": "block_break", "gust_inhale": "mimic_snore", "gust_blow": "whoosh",
	"glass_chime": "crit", "prism_hum": "curdle", "prism_lock": "knell", "beam_fire": "spark", "glass_shing": "parry",
	"glass_clang": "clang", "glass_slide": "slash", "omen_glass_break": "block_break",
	"saint_charge": "flare_charge", "beam_lock": "knell", "beam_reflect": "parry", "saint_rose": "relic_rare",
	"gale": "rush", "saint_choir": "sigil", "saint_crack": "guard_break", "saint_split": "block_break",
	"saint_refract": "perfect_guard", "saint_die": "boss_die",
	# World 6
	"lake_step": "drip", "float_sink": "waxfall", "buoy_toll": "toll_dead", "still_crack": "guard_break",
	"grasp_hiss": "snuffer_whisper", "candle_light": "lantern_light", "buoy_light": "wisp_call", "hush_near": "curdle",
	"tide_rise": "waxfall",
	"hush_pop": "wisp_pop", "stitch_snap": "bones", "gulp_inhale": "mimic_snore", "choke_spit": "dripkin_splat",
	"echo_whisper": "snuffer_whisper", "unwick_fade": "douse", "lake_still": "curdle", "coil_splash": "dripkin_splat",
	"coil_hiss": "snuffer_whisper",
	"hush_still": "curdle", "bell_peal_sunken": "peal", "grasp_rise": "waxfall", "snuff_slam": "snuffer_slam",
	"inhale_roar": "boss_roar", "choke": "douse", "flame_freed": "relight", "gaze_lock": "knell",
	"deep_quiet": "curdle", "hush_eye_open": "curdle", "hush_wince": "boss_hit", "hush_blink": "whoosh",
	"hush_silence": "snuffer_whisper", "hush_scream_silent": "whoosh", "finale_ring": "ember",
	# the modes
	"trial_go": "select", "trial_tick": "click", "candle_lit": "lantern_light", "medal": "relic_magic",
	"trial_fail": "fizzle", "descend": "whoosh", "glimmer": "relic_rare", "cart_bell": "knell", "hushing": "curdle",
	"wax_cast": "wax", "drip_plop": "drip", "record": "level_up", "seal_stamp": "reliquary", "rush_bell": "toll_dead",
	"cosmetic_unlock": "relic_rare", "candlemark": "level_up", "depth_mark": "bank",
}
# Other names a caller might use for a sound (the design notes called the
# Bellfounder's Special "Toll" before it became Peal).
const ALIASES := {"toll": "peal"}
# Sounds heard over and over get a small random pitch (a ratio, +-) when
# play() is left at pitch 1.0, so a run of footsteps never sounds pasted.
# Tonal pickups are left alone: ember climbs a scale and must stay in tune,
# and so must talk, chain_step, item_drop, the chimes and the finisher's glint.
const JITTER := {
	"step": 0.03, "land": 0.03, "jump": 0.02, "double_jump": 0.02, "slash": 0.03, "slash_hit": 0.03,
	"stomp": 0.03, "bump": 0.03, "enemy_hit": 0.03, "bones": 0.03, "bat": 0.03, "clang": 0.02,
	"spikes": 0.03, "block_break": 0.03, "lava": 0.03, "relic_drop": 0.02, "boss_hit": 0.02,
	"guard_block": 0.03, "spark": 0.04, "knife_throw": 0.04, "knife_hit": 0.03, "maul_hit": 0.025,
	"grave_step": 0.03, "smoke_step": 0.03, "rush": 0.02, "arrow_fly": 0.03, "arrow_draw": 0.02,
	"shield_clang": 0.02, "bash": 0.03, "drip": 0.06, "splash": 0.03, "dripkin_splat": 0.04,
	"wing_sip": 0.05, "wing_pop": 0.03, "rubble": 0.05, "snuffer_slam": 0.02, "douse": 0.02,
	"whoosh": 0.04, "guard_up": 0.03, "guard_break": 0.02, "flare_throw": 0.03,
	"fizzle": 0.03, "clank": 0.03,
}
# ...and the most frequent are rendered more than once, with fresh noise
# each take; play() never picks the same take twice running.
const TAKES := {"step": 3, "land": 2, "slash": 2, "ember": 2, "bones": 2, "spark": 2, "knife_throw": 2,
		"knife_hit": 2, "maul_hit": 2, "drip": 3, "rubble": 2, "mote": 3, "finisher": 2}
# Sounds a caller holds and lets go of with release(): release() touches a
# voice only while it is still playing one of these.
const HELD := ["flare_charge"]
const SCALE := [0, 3, 5, 7, 10]   # D minor pentatonic, the notes note() climbs
const STREAK_TOP := 8   # ember(i) stops climbing here, the A two octaves up
const PEAK_CEILING := 0.794   # -2 dBFS
const FLAM_MSEC := 30   # the same sound at the same pitch again this soon plays once
const TABLE := 2048   # one wavetable cycle, a power of two

# The core's cache is keyed as it always was (a hash of this script, the
# engine and the rate); each v3 bank has its own, keyed to this script and
# its bank file, so a new bank or a changed recipe re-renders only its bank.
# They live in cache_home() (Build 5: the OS's cache folder; builds 1-4 kept
# them in user://, the phone's Documents, which the Files app lists).
const CACHE_FILE := "sfx_cache.bin"
const BANK_CACHE := "sfx_cache_%s.bin"
const OLD_CACHE_DIR := "user://"
const CACHE_MAGIC := "WAXBY-SFX-1"
# Render threads. The core goes first on one of them, so the title and a
# fight's first seconds sound as soon as in v2; the v3 banks take the others
# once the title's sounds are made (tools/audio/spike_phone.sh boot measures
# 1, 2 and 3 on the phone; on the Mac, cold, everything is ready in 8.7 s on
# 1, 4.6 s on 2 and 3.9 s on 3, and World 3's bank in 1.6 s on 2).
const RENDER_THREADS := 2
# Milestones of the core's render, stamped for boot_times() (the boot spike).
const MILESTONES := {"pause": "menus", "whoosh": "voices"}

const MUSIC_PATH := "res://audio/%s.wav"
# Every track music.py writes (v2's first, then v3's: P0, P1, then the P2
# beds and lament). play_music takes any of these, or a stem set.
const TRACKS := ["title", "chapel", "boss", "story", "hush", "dawn", "tallow", "snuffer",
		"orchard", "carillon", "sanctum", "hushdeep", "rootmother", "tinker", "saint", "lullaby", "secret",
		"trial", "evenbell",
		"lament", "amb_orchard", "amb_carillon", "amb_sanctum", "amb_hushdeep"]
# What a track plays until music.py has written it (contract: trial is
# chapel, evenbell is dawn, a boss's is boss; the rest are the nearest v2
# mood). The ambience beds have none: a missing bed is just quiet.
const TRACK_FALLBACK := {"trial": "chapel", "evenbell": "dawn", "rootmother": "boss", "tinker": "boss",
		"saint": "boss", "hush_final": "boss", "descent": "chapel", "orchard": "chapel", "carillon": "chapel",
		"sanctum": "chapel", "hushdeep": "hush", "lullaby": "dawn", "secret": "chapel", "lament": "story"}
# Stem sets: every stem a WAV of the same loop, played together in one
# AudioStreamSynchronized, each with its own level (set_stem).
const STEMS := {
	"hush_final": ["hush_final_bells", "hush_final_choir", "hush_final_drums", "hush_final_wick", "hush_final_void"],
	"descent": ["descent_floor", "descent_drive", "descent_deep"],
}
# The pre-mixed stand-ins for a stem set, each naming the stems it holds,
# fullest first: played instead of the stems when STEMS_PREMIXED is on (or a
# stem is missing), crossfading to the one that holds just the stems up.
const PREMIX := {"hush_final": {
	"hush_final_a": ["hush_final_bells", "hush_final_choir", "hush_final_drums", "hush_final_wick", "hush_final_void"],
	# (A6's fourth: every stem but the drums, for the drums' exit at 65%)
	"hush_final_d": ["hush_final_bells", "hush_final_choir", "hush_final_wick", "hush_final_void"],
	"hush_final_b": ["hush_final_void", "hush_final_wick", "hush_final_bells"],
	"hush_final_c": ["hush_final_void", "hush_final_wick"],
}}
# The phone spike's verdict (tools/audio/spike_phone.sh stems): true plays
# the pre-mixed variants instead of AudioStreamSynchronized.
const STEMS_PREMIXED := false
const STEM_OFF_DB := -80.0   # a stem this low is off (the floor of set_stem)
const STEM_ON_DB := -30.0    # ...and one above this counts as on, choosing a premix
const STEM_FADE := 0.5       # replaying a set: the new levels glide in over this
const PREMIX_FADE := 1.0     # one premix crossfading to another
const MUSIC_BUS := "Music"
const EFFECTS_BUS := "Effects"
const AMBIENCE_BUS := "Ambience"
const MUSIC_DB := -5.0   # the music sits this far under the effects
const AMBIENCE_DB := -5.0   # the beds too (they're rendered 12 dB under the music)
const AMBIENCE_FADE := 1.0
const MUSIC_PAD := 16    # frames after each loop's end that repeat its start (see loop_music)
const MUSIC_FADE := 0.4  # seconds for a crossfade between tracks
const SEEK_FADE := 0.12  # seek_music jumps with a crossfade this short...
const SEEK_SLACK := 0.03   # ...when the music is more than this far off
const DUCK_ATTACK := 60.0   # dB per second, going down
const DUCK_RELEASE := 14.0  # dB per second, coming back up
const LOWPASS_HZ := 1200.0     # the music's cutoff while the flame is low
const LOWPASS_OPEN := 20000.0  # ...and where it rests, open, before the effect is switched off
const LOWPASS_GLIDE := 9.0     # octaves per second: in or out in under half a second
# set_hush(k): the music's low-pass goes to HUSH_HZ at k = 1 (on an
# exponential curve from LOWPASS_OPEN), the buses drop by these many dB times
# k, over HUSH_GLIDE seconds. Effects never drop more than HUSH_EFFECTS_DB
# but in a telegraphed silence (SILENCES), where they may go to HUSH_SILENCE_DB.
const HUSH_HZ := 700.0
const HUSH_GLIDE := 0.3
const HUSH_PULSE_IN := 0.1    # hush_pulse comes in this fast (and goes out over HUSH_GLIDE)
const HUSH_MUSIC_DB := 8.0
const HUSH_EFFECTS_DB := 5.0
const HUSH_SILENCE_DB := 18.0
const HUSH_AMBIENCE_DB := 12.0
const SILENCE_EASE := 0.08    # the effects ease into and out of a silence this fast
# Sounds that open a telegraphed silence: [seconds after the sound starts,
# seconds held], as rendered (tell() fits both to a shorter tell). The
# Hush's Snuff (hush_silence, spec 5.5.3): a breath swells for 0.9 s, then
# all sound cuts out for the 0.3 s before the hand lands. The Deep Quiet
# (5.5.4): a breath drawn in and stopped dead at 0.5 s, then nothing at all
# until the water rises, 1.6 s in. Only the tell's picture is left.
const SILENCES := {"hush_silence": [0.9, 0.3], "deep_quiet": [0.5, 1.1]}
const MIN_TELL := 0.35   # tell() never cuts a silence's swell shorter than this
const TRIM_EASE := 0.004  # a tell started part-way in fades in this fast
# tape_stop: the music's pitch ramps to TAPE_FLOOR, then it pauses (a ramp to
# 0 clicks).
const TAPE_FLOOR := 0.25
const SPIKE_PATH := "res://scripts/sfx_spike.gd"   # the phone spikes (debug builds: --autoplay=spike:<what>)

# The formants of a sung "ahh", a growled "aw" and a hollow "oo": [hz, gain, width in hz].
const AH := [[760.0, 1.0, 120.0], [1150.0, 0.5, 130.0], [2800.0, 0.16, 220.0], [3300.0, 0.07, 260.0]]
const AW := [[570.0, 1.0, 110.0], [840.0, 0.7, 120.0], [2410.0, 0.2, 200.0]]
const OO := [[330.0, 1.0, 80.0], [760.0, 0.5, 110.0], [2300.0, 0.12, 200.0]]

var muted: bool:
	## Silences the sound effects and the ambience beds (not the music: see
	## music_muted). Saved.
	get:
		return bool(_settings["muted"])
	set(value):
		_settings["muted"] = value
		if value:
			for p in _voices:
				p.stop()
			for i in range(_amb.size()):
				_amb_to(i, 0.0, 0.0)
				_amb[i].stop()
		elif _amb_track != "" and is_inside_tree():
			_start_ambience(AMBIENCE_FADE)
		_save_settings()

var music_muted: bool:
	## Silences the music. The track asked for is remembered, and starts
	## again when music is unmuted. Saved, separately from muted.
	get:
		return bool(_settings["music_muted"])
	set(value):
		_settings["music_muted"] = value
		if value:
			for i in range(_music.size()):
				_fade_to(i, 0.0, 0.0)
				_music[i].stop()
		elif _music_track != "" and is_inside_tree():
			_start_music(MUSIC_FADE)
		_save_settings()

var _settings := {"muted": false, "volume": 1.0, "music_muted": false}
var _streams := {}          # name -> Array of AudioStreamWAV takes, filled in by the render threads
var _lock := Mutex.new()
var _cancel := [false]      # set under _lock when this node goes away; the render stops early
var _threads: Array[Thread] = []
var _banks: Array = []      # the banks to render (see bank_list), the core first
var _queue: Array = []      # bank ids not taken by a render thread yet
var _done := {}             # bank id -> true once all its sounds are in _streams
var _prefer := [""]         # a bank the render threads take next (prefer_bank)
var _stamps := {}           # render milestones, msec since the engine started (boot_times)
var _jitter := {}           # JITTER and every bank's
var _tell_at := {}          # every bank's TELL_AT (see tell)
var _trims := {}            # "take id:ms" -> that take trimmed for a shorter tell (_trimmed)
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _last_take := {}        # name -> the take played last
var _recent := {}           # name -> [msec, pitch asked for, voice] of its last start

var _music: Array[AudioStreamPlayer] = []   # two, so one can fade in as the other fades out
var _fade: Array[float] = [0.0, 0.0]        # each player's fade, 0 (silent) to 1
var _fade_goal: Array[float] = [0.0, 0.0]
var _fade_rate: Array[float] = [1.0, 1.0]   # fade per second
var _music_cur := 0         # the player carrying the current track
var _music_track := ""      # the track (or stem set) asked for, kept while music is muted
var _music_cache := {}      # track or stem -> AudioStream, or null when it would not load
var _clock := 0.0           # seconds of music time, advanced by _tick_music
var _duck_db := 0.0
var _duck_depth := 0.0
var _duck_until := 0.0
var _lowpass := false             # asked for (set_lowpass)
var _lowpass_hz := LOWPASS_OPEN   # where the cutoff is now, gliding toward the goal
var _cutoff := LOWPASS_OPEN       # the cutoff last put on the filter (the lower of the two)
var _releasing := {}              # voice -> [its stream, gain left, gain lost per second] (see release)
var _voice_sound := {}            # voice -> the sound play() last started on it
var _voice_gain := {}             # voice -> the gain play() gave it
var _anchor: Array = []           # [track, t, usec]: seek_music's alignment, for a start later

var _stem_db := {}          # stem -> its level now, in dB
var _stem_goal := {}        # stem -> the level set_stem asked for
var _stem_speed := {}       # stem -> linear gain per second toward it
var _stem_mode := ""        # the set playing as "sync", "premix", "track" (a stand-in) or ""
var _premix := ""           # the premix variant playing
var _extra_stems := {}      # set -> stems, registered at runtime (register_stems: the spike, the tests)

var _hush := 0.0            # the hush now, 0..1, gliding toward _hush_target
var _hush_base := 0.0       # set_hush's
var _hush_target := 0.0
var _hush_rate := 0.0       # per second
var _pulse_k := 0.0         # hush_pulse's, until _pulse_until
var _pulse_until := 0.0
var _hushed_fx := 0.0         # how far into a silence the effects are, 0..1
var _silence_until := 0.0
var _silence_at := -1.0     # a scheduled silence (SILENCES): when it starts...
var _silence_len := 0.0     # ...and how long it holds
var _bus_db := {}           # bus -> the volume last put on it

var _tape := 1.0            # the music's pitch (tape_stop, tape_go)
var _tape_goal := 1.0
var _tape_rate := 0.0
var _tape_held := false     # paused at the bottom of a tape stop

var _amb: Array[AudioStreamPlayer] = []   # the ambience beds, two for crossfades
var _amb_fade: Array[float] = [0.0, 0.0]
var _amb_goal: Array[float] = [0.0, 0.0]
var _amb_rate: Array[float] = [1.0, 1.0]
var _amb_cur := 0
var _amb_track := ""
var _amb_db := 0.0

var _spike := ""            # the spike started, if any


func _init() -> void:
	# The pause menu still clicks, and the music plays on under it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_load_settings()
	drop_old_caches()
	_stamps["init"] = Time.get_ticks_msec()
	var bus := music_bus()   # first, so it keeps v2's index
	var fx := AudioServer.get_bus_name(effects_bus())
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = fx
		add_child(p)
		_voices.append(p)
	for i in range(2):
		var m := AudioStreamPlayer.new()
		m.bus = AudioServer.get_bus_name(bus)
		add_child(m)
		_music.append(m)
	var amb := AudioServer.get_bus_name(ambience_bus())
	for i in range(2):
		var a := AudioStreamPlayer.new()
		a.bus = amb
		add_child(a)
		_amb.append(a)
	# Rendering is seconds of GDScript, so it runs off the main thread instead
	# of holding up the boot, and what it makes is cached in user:// for the
	# next boot. Sounds arrive one by one, bank by bank; one asked for before
	# it is ready plays its FALLBACK (a core sound), or is skipped. The threads
	# only touch the tables handed to them, never this node, so the node can
	# be freed while they run (a method call would lock it against free()).
	_jitter = JITTER.duplicate()
	_banks = bank_list(get_script())
	for b in _banks:
		_jitter.merge(b["jitter"])
		_tell_at.merge(b.get("tell_at", {}))
		_queue.append(b["id"])
	for i in range(clampi(RENDER_THREADS, 1, _banks.size())):
		var t := Thread.new()
		t.start(Callable(get_script(), "_render_banks").bind(_streams, _lock, _cancel, _banks, _queue, _done,
				_prefer, _stamps), Thread.PRIORITY_LOW)
		_threads.append(t)


func _ready() -> void:
	_guard_master()
	if _music_track != "" and not music_muted:
		_start_music(MUSIC_FADE)
	var spike := spike_arg()
	if spike != "":
		_spike_later(spike)


func _process(delta: float) -> void:
	_tick_music(delta)
	_tick_release(delta)


func _exit_tree() -> void:
	## Leaving the tree (at quit) only pauses a voice, and a sound still
	## ringing, or just stopped and still fading out on the audio thread, is
	## then reported as leaked. Stop them all and give the audio thread a
	## moment to let go.
	for p in _voices + _music + _amb:
		p.stop()
	OS.delay_msec(100)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Let the render stop after the sound it is on, then wait for it.
		_lock.lock()
		_cancel[0] = true
		_lock.unlock()
		for t in _threads:
			if t.is_started():
				t.wait_to_finish()


func is_loaded() -> bool:
	## True once every sound of every bank is rendered.
	_lock.lock()
	var n := _done.size()
	_lock.unlock()
	return n >= _banks.size()


func bank_ready(world: int) -> bool:
	## True once every sound a world's levels use is rendered: the core and
	## the story bank for Worlds 1 and 2, and that world's own bank from World
	## 3 on; 0 (a mode, which borrows from every world) waits for them all. A
	## bank not written yet counts as ready: its sounds play their fallbacks.
	var need := banks_for(world)
	_lock.lock()
	var ready := true
	for id in need:
		ready = ready and _done.has(id)
	_lock.unlock()
	return ready


func banks_for(world: int) -> Array:
	## The ids of the banks bank_ready(world) waits on (only those written).
	var have := _banks.map(func(b): return str(b["id"]))
	var want: Array = have
	if world >= 1 and world <= 2:
		want = ["core", "story"]
	elif world >= 3 and world <= 6:
		want = ["core", "story", "w%d" % world]
	return want.filter(func(id): return have.has(id))


func prefer_bank(world: int) -> void:
	## Render this world's bank next, ahead of the order (a level of World 5
	## played before World 3's bank is done). The core always goes first.
	_lock.lock()
	_prefer[0] = "w%d" % world if world >= 3 and world <= 6 else ("modes" if world == 0 else "")
	_lock.unlock()


func boot_times() -> Dictionary:
	## When the render reached its milestones, in msec since the engine
	## started: "init" (this node made), "menus" and "voices" (the title's
	## sounds), then each bank id as it finished, "<id>:start" as it began and
	## "<id>:cached" when it came from its cache; "order", the banks as taken.
	_lock.lock()
	var out := _stamps.duplicate(true)
	_lock.unlock()
	return out


# ---------------------------------------------------------------- the banks

static func bank_list(script: Script, cache_dir := "") -> Array:
	## Every bank to render, in order: the core (this script's recipes), then
	## each v3 bank whose file exists. A bank is {id, names, takes, jitter,
	## render (a Callable: sound, take -> samples), cache (its path), key}.
	## cache_dir moves the caches (the spike's cold boots).
	var out := [core_bank(script, cache_dir)]
	for id in BANK_ORDER:
		var b := load_bank(id, cache_dir)
		if not b.is_empty():
			out.append(b)
	return out


static func core_bank(script: Script, cache_dir := "") -> Dictionary:
	return {"id": "core", "names": CORE, "takes": TAKES, "jitter": JITTER, "render": Callable(script, "render"),
			"cache": (cache_home() if cache_dir == "" else cache_dir).path_join(CACHE_FILE), "key": cache_key()}


static func load_bank(id: String, cache_dir := "", file := "") -> Dictionary:
	## A v3 bank from its file (BANK_PATH, or `file`), or {} while there is
	## none. The file is a script with a static render(sound, take) returning
	## the finished samples (built from this script's primitives and _finish),
	## and consts NAMES (the names it renders, in order: each must be one
	## BANKS gives it; others are warned about and left out), TAKES and JITTER
	## as the core's, and TELL_AT (a tell's sound -> how many seconds into it
	## its threat lands, as rendered: see tell).
	var path := BANK_PATH % id if file == "" else file
	if not BANKS.has(id) or not ResourceLoader.exists(path):
		return {}
	var script := load(path) as Script
	if script == null:
		return {}
	var has_render := false
	for m in script.get_script_method_list():
		has_render = has_render or m["name"] == "render"
	if not has_render:
		push_warning("Sfx: bank %s has no render(sound, take)" % path)
		return {}
	var consts := script.get_script_constant_map()
	var names := []
	for n in consts.get("NAMES", []):
		if (BANKS[id] as Array).has(n) and not names.has(n):
			names.append(n)
		else:
			push_warning("Sfx: bank %s names '%s', which isn't one of its sounds (Sfx.BANKS)" % [path, n])
	var cache := (cache_home() if cache_dir == "" else cache_dir).path_join(BANK_CACHE % id)
	return {"id": id, "names": names, "takes": consts.get("TAKES", {}), "jitter": consts.get("JITTER", {}),
			"tell_at": consts.get("TELL_AT", {}), "render": Callable(script, "render"), "cache": cache,
			"key": bank_key(path)}


static func _render_banks(streams: Dictionary, lock: Mutex, cancel: Array, banks: Array, queue: Array,
		done: Dictionary, prefer: Array, stamps: Dictionary) -> void:
	## A render thread: takes the next bank off the queue (the preferred one
	## once the core is taken), fills it in from its cache or renders it sound
	## by sound, and marks it done; until the queue is empty or the node goes.
	while true:
		lock.lock()
		if cancel[0] or queue.is_empty():
			lock.unlock()
			return
		# The title's sounds first: while another thread is still on the
		# core's menus and story voices, this one waits for them before it
		# takes a bank (a few dozen ms), so on a slow phone core nothing
		# competes with them.
		if not queue.has("core") and stamps.has("core:start") and not stamps.has("voices") and not done.has("core"):
			lock.unlock()
			OS.delay_msec(4)
			continue
		var at := 0
		var want: String = prefer[0]
		if want != "" and not queue.has("core") and queue.has(want):
			at = queue.find(want)
		var id: String = queue.pop_at(at)
		stamps[id + ":start"] = Time.get_ticks_msec()
		if not stamps.has("order"):
			stamps["order"] = []
		stamps["order"].append(id)
		lock.unlock()
		var bank: Dictionary = {}
		for b in banks:
			if b["id"] == id:
				bank = b
		if not render_bank(streams, lock, cancel, bank, stamps):
			return
		lock.lock()
		done[id] = true
		stamps[id] = Time.get_ticks_msec()
		lock.unlock()


static func render_bank(streams: Dictionary, lock: Mutex, cancel: Array, bank: Dictionary, stamps := {}) -> bool:
	## One bank's sounds into streams: from its cache if that holds this
	## build's sounds, else rendered in order and then cached. False if the
	## render was called off partway.
	var key: String = bank["key"]
	var names: Array = bank["names"]
	var takes: Dictionary = bank["takes"]
	var id: String = bank["id"]
	if key != "" and load_cache(streams, lock, bank["cache"], key, names, takes):
		lock.lock()
		stamps[id + ":cached"] = true
		if id == "core":
			for m in MILESTONES.values():
				stamps[m] = Time.get_ticks_msec()
		lock.unlock()
		return true
	var render: Callable = bank["render"]
	var made := {}
	for sound in names:
		lock.lock()
		var stop: bool = cancel[0]
		lock.unlock()
		if stop:
			return false
		var list: Array = []
		for t in range(int(takes.get(sound, 1))):
			list.append(to_wav(render.call(sound, t)))
		made[sound] = list
		lock.lock()
		streams[sound] = list
		if id == "core" and MILESTONES.has(sound):
			stamps[MILESTONES[sound]] = Time.get_ticks_msec()
		lock.unlock()
	if key != "":
		save_cache(made, bank["cache"], key, names)
	return true


# ---------------------------------------------------------------- the cache

static var _cache_home := ""


static func cache_home() -> String:
	## The folder the sound caches live in: the OS's cache folder (on the
	## phone the app's own Library/Caches: never backed up and never in the
	## Files app; iOS may empty it when storage runs low, and then the sounds
	## are rendered again), in a folder named for this game (a Mac's
	## Library/Caches is every app's). user:// if there is none.
	if _cache_home == "":
		var base := OS.get_cache_dir()
		var dir := base.path_join(game_dir_name()) if base != "" else ""
		if dir == "" or (not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK):
			dir = OLD_CACHE_DIR
		_cache_home = dir
	return _cache_home


static func core_cache() -> String:
	## The core bank's cache file.
	return cache_home().path_join(CACHE_FILE)


static func game_dir_name() -> String:
	## The game's own folder name: its custom user folder's (a worktree's
	## override.cfg gives each its own), else its name.
	var n := ""
	if bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)):
		n = str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	if n == "":
		n = str(ProjectSettings.get_setting("application/config/name", "Waxby"))
	return n.validate_filename()


static func drop_old_caches() -> int:
	## Builds 1-4 cached the sounds in user:// (Documents on the phone, ~11
	## MB the Files app listed): they go at launch, now that the caches live
	## in cache_home() (nothing to carry over: a cache's key names this
	## script, which has changed since). How many files went.
	if cache_home() == OLD_CACHE_DIR:
		return 0
	var dir := ProjectSettings.globalize_path(OLD_CACHE_DIR)
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("sfx_cache") and (f.ends_with(".bin") or f.ends_with(".tmp")):
			if DirAccess.remove_absolute(dir.path_join(f)) == OK:
				n += 1
	return n


static func _file_md5(path: String) -> String:
	## The file's hash: the source, or in an export its compiled tokens; ""
	## when neither is there.
	for p in [path, path + "c"]:
		if FileAccess.file_exists(p):
			return FileAccess.get_md5(p)
	return ""


static func cache_key() -> String:
	## Changes whenever the core's sounds could: a hash of this script (the
	## source, or in an export its compiled tokens), the engine version (its
	## noise generator and maths) and the sample rate. "" if the script can't
	## be read, and then nothing is cached.
	var md5 := _file_md5("res://scripts/sfx.gd")
	if md5 == "":
		return ""
	return "%s|%s|%d" % [md5, Engine.get_version_info()["string"], RATE]


static func bank_key(path: String) -> String:
	## A bank's key: this script's hash (its primitives) and the bank file's,
	## the engine and the rate.
	var mine := _file_md5("res://scripts/sfx.gd")
	var theirs := _file_md5(path)
	if mine == "" or theirs == "":
		return ""
	return "%s+%s|%s|%d" % [mine, theirs, Engine.get_version_info()["string"], RATE]


static func save_cache(streams: Dictionary, path: String, key: String, names: Array = CORE) -> bool:
	## A bank's takes (names, in order), as the 16-bit PCM to_wav made, after a
	## header naming the key. Written to a scratch file and renamed into
	## place, so a boot killed halfway (or another copy of the game writing at
	## once) never leaves a torn cache behind.
	var tmp := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var have := names.filter(func(n): return streams.has(n))
	_write_text(f, CACHE_MAGIC)
	_write_text(f, key)
	f.store_32(have.size())
	for sound in have:
		var takes: Array = streams[sound]
		_write_text(f, sound)
		f.store_32(takes.size())
		for wav in takes:
			var data: PackedByteArray = (wav as AudioStreamWAV).data
			f.store_32(data.size())
			f.store_buffer(data)
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	return err == OK


static func load_cache(streams: Dictionary, lock: Mutex, path: String, key: String, names: Array = CORE,
		takes: Dictionary = TAKES) -> bool:
	## Fill streams from the cache and return true, but only if it holds
	## exactly these names, every take, under this key; otherwise leave
	## streams alone and return false (a stale, torn or foreign file is just
	## ignored).
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var size := f.get_length()
	if _read_text(f, size) != CACHE_MAGIC or _read_text(f, size) != key:
		return false
	var count := f.get_32()
	if count != names.size():
		return false
	var found := {}
	for i in range(count):
		var sound := _read_text(f, size)
		var n := f.get_32()
		if not names.has(sound) or found.has(sound) or n != int(takes.get(sound, 1)):
			return false
		var list: Array = []
		for t in range(n):
			var bytes := f.get_32()
			if bytes <= 0 or bytes % 2 != 0 or f.get_position() + bytes > size:
				return false
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.mix_rate = RATE
			wav.stereo = false
			wav.data = f.get_buffer(bytes)
			list.append(wav)
		found[sound] = list
	if f.get_position() != size:
		return false
	lock.lock()
	for sound in names:
		streams[sound] = found[sound]
	lock.unlock()
	return true


static func _write_text(f: FileAccess, text: String) -> void:
	var bytes := text.to_utf8_buffer()
	f.store_32(bytes.size())
	f.store_buffer(bytes)


static func _read_text(f: FileAccess, size: int) -> String:
	## A string _write_text wrote, or "" if the length in front of it is
	## implausible (a foreign or corrupt file): never a huge allocation.
	var n := f.get_32()
	if n > 1024 or f.get_position() + n > size:
		return ""
	return f.get_buffer(n).get_string_from_utf8()


# ---------------------------------------------------------------- the buses

func _guard_master() -> void:
	## A hard limiter on the master bus, added once unless one is there: a
	## dozen voices over the music can add up past full scale, and a phone
	## speaker clips harshly. Below its ceiling it does nothing.
	for i in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.3
	AudioServer.add_bus_effect(0, limiter)


static func _bus(bus_name: String) -> int:
	## A bus's index, made (sending to Master) the first time it's asked for:
	## the project has no bus layout, so Sfx builds its own.
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		i = AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


static func music_bus() -> int:
	## The Music bus's index, with a low-pass on it that stays switched off
	## until set_lowpass or set_hush wants it; later calls find it again.
	var i := _bus(MUSIC_BUS)
	if _lowpass_slot(i) < 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = LOWPASS_OPEN
		lp.db = AudioEffectFilter.FILTER_18DB
		AudioServer.add_bus_effect(i, lp)
		AudioServer.set_bus_effect_enabled(i, AudioServer.get_bus_effect_count(i) - 1, false)
	return i


static func effects_bus() -> int:
	## The Effects bus: every voice plays through it (set_hush turns it down).
	return _bus(EFFECTS_BUS)


static func ambience_bus() -> int:
	## The Ambience bus: the world beds (play_ambience).
	return _bus(AMBIENCE_BUS)


static func _lowpass_slot(bus: int) -> int:
	for k in range(AudioServer.get_bus_effect_count(bus)):
		if AudioServer.get_bus_effect(bus, k) is AudioEffectLowPassFilter:
			return k
	return -1


func _set_bus(bus_name: String, db: float) -> void:
	if absf(float(_bus_db.get(bus_name, 0.0)) - db) < 0.005 and _bus_db.has(bus_name):
		return
	_bus_db[bus_name] = db
	AudioServer.set_bus_volume_db(_bus(bus_name), db)


# ---------------------------------------------------------------- playing

func play(sound: String, pitch: float = 1.0, gain: float = 1.0) -> AudioStreamPlayer:
	## Start a sound on a free voice, or on the oldest busy one. Returns the
	## voice, or null when muted, unknown, not rendered yet (with no fallback
	## rendered either), or called before the tree is up. A v3 sound not
	## rendered yet plays its FALLBACK at the pitch asked for. A JITTER sound
	## left at pitch 1.0 gets a small random pitch; any other pitch is used
	## exactly. gain (linear, 0..1) plays it quieter: a hum falling off with
	## distance, a cutscene's "vol". The same sound at the same pitch asked
	## for twice within FLAM_MSEC plays once (two stomps in one frame would
	## otherwise double up into a louder, phasey hit), at the louder gain. A
	## sound in SILENCES opens its silence (at a pitch, when its own silence
	## comes).
	return _start(sound, pitch, gain, 0.0, -1.0)


func tell(sound: String, seconds: float, gain: float = 1.0) -> AudioStreamPlayer:
	## Play a tell's sound fitted to a tell that lasts `seconds` (a knob, a
	## difficulty's or a boss phase's shorter tell). Each is rendered for its
	## longest tell, its threat landing TELL_AT seconds in (its bank's
	## table), so for a shorter one it starts that much further in: its
	## climax still comes just before the threat, and at its own pitch (a
	## faster pitch would put a tonal tell off the scale). A longer tell
	## plays it from the start, so its climax comes early, never late. A
	## silence tell (SILENCES) keeps at least MIN_TELL of its swell, gives the
	## rest up from its silence, and its silence always ends as the threat
	## lands. A sound with no TELL_AT (a tell that warns with its onset, a
	## howl or a lock's tone, which trimming would cut off) plays whole, as
	## play() would; one still playing its fallback plays that from its
	## start, its silence fitted all the same. Tells play at pitch 1.0:
	## their length is the tell. Callers play every tell through this.
	var name: String = ALIASES.get(sound, sound)
	var at := float(_tell_at.get(name, 0.0))
	if at <= 0.0 or seconds <= 0.0:
		return _start(sound, 1.0, gain, 0.0, -1.0)
	var skip := maxf(at - seconds, 0.0)
	var hold := -1.0
	if SILENCES.has(name):
		var s0 := float(SILENCES[name][0])
		skip = minf(skip, maxf(s0 - MIN_TELL, 0.0))
		hold = maxf(seconds - (s0 - skip), 0.0)
	return _start(sound, 1.0, gain, skip, hold)


func _start(sound: String, pitch: float, gain: float, skip: float, hold: float) -> AudioStreamPlayer:
	## play() and tell(): start `skip` seconds into the sound (never into a
	## fallback), and hold a SILENCES sound's silence `hold` seconds (its own
	## when below 0).
	if not is_inside_tree():
		return null
	sound = ALIASES.get(sound, sound)
	if SILENCES.has(sound):
		var s: Array = SILENCES[sound]
		var sp := clampf(pitch, 0.25, 4.0)
		_silence_at = _clock + maxf(float(s[0]) - skip, 0.0) / sp
		_silence_len = (float(s[1]) if hold < 0.0 else hold) / sp
	if muted or get_volume() <= 0.0 or gain <= 0.0:
		return null
	_lock.lock()
	var takes: Array = _streams.get(sound, [])
	if takes.is_empty() and FALLBACK.has(sound):
		sound = FALLBACK[sound]
		takes = _streams.get(sound, [])
		skip = 0.0
	_lock.unlock()
	if takes.is_empty():
		if not NAMES.has(sound):
			push_warning("Sfx: no sound named '%s'" % sound)
		return null
	var now := Time.get_ticks_msec()
	var recent: Array = _recent.get(sound, [])
	if not recent.is_empty() and now - int(recent[0]) < FLAM_MSEC and is_equal_approx(float(recent[1]), pitch):
		var held: AudioStreamPlayer = recent[2]
		if held.playing and held.stream == recent[3]:
			if minf(gain, 1.0) > float(_voice_gain.get(held, 1.0)):
				_voice_gain[held] = minf(gain, 1.0)
				held.volume_db = linear_to_db(get_volume() * minf(gain, 1.0))
			return held
	var take := 0
	if takes.size() > 1:
		var last := int(_last_take.get(sound, -1))
		if last < 0:
			take = _rng.randi_range(0, takes.size() - 1)
		else:
			take = _rng.randi_range(0, takes.size() - 2)
			take += 1 if take >= last else 0
		_last_take[sound] = take
	var scale := pitch
	if pitch == 1.0 and _jitter.has(sound):
		var j: float = _jitter[sound]
		scale = 1.0 + _rng.randf_range(-j, j)
	var stream: AudioStream = takes[take]
	if skip > 0.0 and stream is AudioStreamWAV and (stream as AudioStreamWAV).format == AudioStreamWAV.FORMAT_16_BITS \
			and not (stream as AudioStreamWAV).stereo:
		stream = _trimmed(stream, skip)
	var p := _voice()
	_releasing.erase(p)
	_voice_sound[p] = sound
	p.stream = stream
	p.pitch_scale = clampf(scale, 0.25, 4.0)
	_voice_gain[p] = minf(gain, 1.0)
	p.volume_db = linear_to_db(get_volume() * minf(gain, 1.0))
	p.play()
	_recent[sound] = [now, pitch, p, stream]
	return p


func _trimmed(wav: AudioStreamWAV, skip: float) -> AudioStreamWAV:
	## A take from `skip` seconds in (to the millisecond), eased in over
	## TRIM_EASE so a start in mid-wave can't click (a seek would). Kept, so a
	## tell played again at the same length reuses it.
	var ms := roundi(skip * 1000.0)
	var key := "%d:%d" % [wav.get_instance_id(), ms]
	if _trims.has(key):
		return _trims[key]
	var src := wav.data
	var from := mini(roundi(ms * RATE / 1000.0), maxi(src.size() / 2 - 1, 0))
	var data := src.slice(from * 2)
	var ease := mini(int(TRIM_EASE * RATE), data.size() / 2)
	for i in range(ease):
		data.encode_s16(i * 2, roundi(data.decode_s16(i * 2) * (0.5 - 0.5 * cos(PI * i / ease))))
	var out := AudioStreamWAV.new()
	out.format = wav.format
	out.mix_rate = wav.mix_rate
	out.stereo = wav.stereo
	out.data = data
	if _trims.size() >= 64:
		_trims.clear()
	_trims[key] = out
	return out


func rendered(sound: String) -> bool:
	## True once this sound itself (not its fallback) is ready to play.
	_lock.lock()
	var ok := not (_streams.get(ALIASES.get(sound, sound), []) as Array).is_empty()
	_lock.unlock()
	return ok


func release(voice: AudioStreamPlayer, seconds: float = 0.08) -> void:
	## Let go of a held sound play() returned (flare_charge while the button
	## is held): fade it out over `seconds` and stop it, rather than cutting
	## it off mid-wave. Harmless on null, on a voice that already finished,
	## and on one that has since been handed to another sound: the charge
	## ran out and its voice was reused, or all the voices were busy and it
	## was stolen. Only a voice still playing one of the HELD sounds fades.
	if voice == null or not voice.playing or not _voices.has(voice):
		return
	var sound: String = _voice_sound.get(voice, "")
	_lock.lock()
	var takes: Array = _streams.get(sound, [])
	_lock.unlock()
	if not HELD.has(sound) or not takes.has(voice.stream):
		return
	if seconds <= 0.0:
		voice.stop()
		_releasing.erase(voice)
		return
	_releasing[voice] = [voice.stream, 1.0, 1.0 / seconds]


func _tick_release(delta: float) -> void:
	for p in _releasing.keys():
		var r: Array = _releasing[p]
		if not p.playing or p.stream != r[0]:
			_releasing.erase(p)
			continue
		r[1] = maxf(0.0, float(r[1]) - float(r[2]) * delta)
		if r[1] <= 0.0:
			p.stop()
			_releasing.erase(p)
		else:
			p.volume_db = linear_to_db(float(r[1]) * maxf(get_volume() * float(_voice_gain.get(p, 1.0)), 0.0001))


func note(degree: int) -> float:
	## Pitch ratio for a degree of D minor pentatonic: 0 is the root, 5 the
	## octave, 10 two octaves. Play a tonal sound at note(i) to walk it up in
	## tune with the music (an ember streak, a combo).
	return _degree_ratio(maxi(degree, 0))


static func in_key(ratio: float) -> float:
	## The pitch ratio nearest `ratio` that is a note of D minor pentatonic,
	## in any octave: a pitch snapped into the key the music is in, never
	## moved more than a semitone and a half (1.6 becomes 1.498, the fifth;
	## 0.85 becomes 0.891, the C below). 0 or less comes back as it is.
	## Snap the pitch that is played: in_key(voice) * note(i) is NOT in key
	## for most voices, since the scale's steps differ from note to note (a
	## voice on F, times note(1), lands on Ab). See voice_note.
	if ratio <= 0.0:
		return ratio
	return _degree_ratio(_nearest_degree(ratio))


static func voice_note(voice: float, i: int) -> float:
	## The i-th note (from 0) of D minor pentatonic counting up from the one
	## nearest a speaker's voice: a story blip played at voice_note(voice, i)
	## sings in that speaker's own register and always on the scale, so
	## Mother Taper (1.6) blips A5 C6 D6 F6 G6 over the story's D minor
	## rather than Bb5 C#6 Eb6 F6 Ab6. 0 or less comes back as it is.
	if voice <= 0.0:
		return voice
	return _degree_ratio(_nearest_degree(voice) + i)


static func _degree_semis(d: int) -> int:
	## Semitones above the root for any degree, negative ones counting down.
	return 12 * floori(d / 5.0) + int(SCALE[posmod(d, 5)])


static func _degree_ratio(d: int) -> float:
	## note() for any degree.
	return pow(2.0, _degree_semis(d) / 12.0)


static func _nearest_degree(ratio: float) -> int:
	## The degree whose note is nearest `ratio` (above 0); on a tie, the lower.
	var semis := 12.0 * log(ratio) / log(2.0)
	var guess := roundi(semis * 5.0 / 12.0)
	var best := guess - 3
	for d in range(guess - 2, guess + 4):
		if absf(_degree_semis(d) - semis) < absf(_degree_semis(best) - semis):
			best = d
	return best


func ember(i: int) -> AudioStreamPlayer:
	## The i-th ember of a streak (from 0), each a note higher up to
	## STREAK_TOP, then holding there.
	return play("ember", note(mini(i, STREAK_TOP)))


func set_volume(linear: float) -> void:
	## Overall volume, 0..1, for effects, music and ambience alike. Saved.
	_settings["volume"] = clampf(linear, 0.0, 1.0)
	for p in _voices:
		p.volume_db = linear_to_db(maxf(get_volume() * float(_voice_gain.get(p, 1.0)), 0.0001))
	_tick_music(0.0)
	_save_settings()


func get_volume() -> float:
	return float(_settings["volume"])


func _voice() -> AudioStreamPlayer:
	for i in range(VOICES):
		var p: AudioStreamPlayer = _voices[(_next + i) % VOICES]
		if not p.playing:
			_next = (_next + i + 1) % VOICES
			return p
	var oldest: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % VOICES
	return oldest


func _load_settings() -> void:
	## Only our own keys: the file's others belong to someone else, and a
	## copy of them kept here would overwrite their newer values on save.
	var saved: Dictionary = SettingsLib.read(SETTINGS_PATH)
	for key in _settings:
		if saved.has(key):
			_settings[key] = saved[key]


func _save_settings() -> void:
	## Other settings share the file; SettingsLib keeps theirs.
	SettingsLib.write(_settings, SETTINGS_PATH)


# ---------------------------------------------------------------- the hush

func set_hush(k: float) -> void:
	## How near the Hush is, 0..1 (a Hush zone 0.6, a tendril by distance):
	## the music's low-pass glides toward HUSH_HZ (exponentially, from wide
	## open), the Music bus drops 8k dB, Effects 5k and Ambience 12k, over
	## HUSH_GLIDE seconds. Calling it every frame is fine: it only glides. The
	## lower of this cutoff and the low-life one wins.
	_hush_base = clampf(k, 0.0, 1.0)
	_aim_hush(HUSH_GLIDE)


func hush_pulse(seconds: float, k: float, silence := false) -> void:
	## A short silence tell: the hush rises to at least k (fast) for `seconds`,
	## then glides back to set_hush's. Overlapping pulses keep the deeper one
	## and the later end. silence lets Effects drop past their 5 dB cap, to 18
	## dB at k = 1 (only for a telegraphed silence: see SILENCES).
	var k2 := clampf(k, 0.0, 1.0)
	if _clock >= _pulse_until:
		_pulse_k = k2
	else:
		_pulse_k = maxf(_pulse_k, k2)
	_pulse_until = maxf(_pulse_until, _clock + maxf(seconds, 0.0))
	if silence:
		_silence_until = maxf(_silence_until, _clock + maxf(seconds, 0.0))
	_aim_hush(HUSH_PULSE_IN)


func hush_level() -> float:
	## The hush now, 0..1 (after its glide).
	return _hush


func hush_hz() -> float:
	## The hush's cutoff for the music now: LOWPASS_OPEN at 0, HUSH_HZ at 1.
	if _hush <= 0.0:
		return LOWPASS_OPEN
	return exp(lerpf(log(LOWPASS_OPEN), log(HUSH_HZ), _hush))


func _aim_hush(glide: float) -> void:
	_hush_target = maxf(_hush_base, _pulse_k if _clock < _pulse_until else 0.0)
	if glide <= 0.0:
		_hush = _hush_target
		_hush_rate = 0.0
	else:
		_hush_rate = absf(_hush_target - _hush) / glide


func _tick_hush(delta: float) -> void:
	if _silence_at >= 0.0 and _clock >= _silence_at:
		_silence_at = -1.0
		hush_pulse(_silence_len, 1.0, true)
	if _pulse_k > 0.0 and _clock >= _pulse_until:
		_pulse_k = 0.0
		_aim_hush(HUSH_GLIDE)
	_hush = move_toward(_hush, _hush_target, _hush_rate * delta)
	_hushed_fx = move_toward(_hushed_fx, 1.0 if _clock < _silence_until else 0.0, delta / SILENCE_EASE)
	_set_bus(MUSIC_BUS, -HUSH_MUSIC_DB * _hush)
	_set_bus(EFFECTS_BUS, -lerpf(HUSH_EFFECTS_DB, HUSH_SILENCE_DB, _hushed_fx) * _hush)
	_set_bus(AMBIENCE_BUS, -HUSH_AMBIENCE_DB * _hush)


# ---------------------------------------------------------------- music

func play_music(track: String) -> void:
	## Crossfade to a looping track (one of TRACKS: the files in res://audio/)
	## over MUSIC_FADE seconds, or to a stem set (STEMS: see play_stems).
	## Nothing happens if that track is already playing. While music is muted
	## the track is only remembered. A track music.py hasn't written yet plays
	## its TRACK_FALLBACK; one with none is warned about once and fades out
	## the old.
	if track == "":
		stop_music()
		return
	if _is_stem_set(track):
		play_stems(track)
		return
	if track == _music_track and (music_muted or _current_on()):
		return
	_music_track = track
	_anchor = []
	_stem_mode = ""
	_premix = ""
	_reset_tape()
	if music_muted or not is_inside_tree():
		return
	_start_music(MUSIC_FADE)


func stop_music(fade: float = 0.5) -> void:
	## Fade the music out over `fade` seconds (0: at once) and forget the track.
	_music_track = ""
	_anchor = []
	_stem_mode = ""
	_premix = ""
	if _tape_held:
		for p in _music:
			p.stop()
	_reset_tape()
	for i in range(_music.size()):
		_fade_to(i, 0.0, fade)
	_tick_music(0.0)


func duck_music(amount_db: float, seconds: float) -> void:
	## Pull the music down by amount_db (either sign) at DUCK_ATTACK dB a
	## second (9 dB in 0.15 s), hold it there until `seconds` after the call,
	## then let it back up at DUCK_RELEASE (9 dB in 0.65 s): under the bell's
	## toll, a legendary relic, the level clear. Ducks that overlap keep the
	## deeper dip and the later end.
	var depth := -absf(amount_db)
	if _clock >= _duck_until:
		_duck_depth = depth
	else:
		_duck_depth = minf(_duck_depth, depth)
	_duck_until = maxf(_duck_until, _clock + maxf(seconds, 0.0))


func music_playing() -> String:
	## The track or stem set playing (or asked for, while music is muted), or "".
	return _music_track


func set_lowpass(on: bool) -> void:
	## Muffle the music behind a LOWPASS_HZ low-pass on the Music bus (the
	## flame is low: below a quarter of life), or open it back up. The cutoff
	## glides there in under half a second rather than switching, and the
	## filter is switched off entirely once it is open again. The effects
	## stay crisp: they don't go through the Music bus.
	if on == _lowpass:
		return
	_lowpass = on
	music_bus()
	_apply_lowpass()


func lowpass_on() -> bool:
	return _lowpass


func seek_music(t: float) -> void:
	## Put the music back in step with the feature clock (world.ftime): the
	## track or stem set jumps to t seconds (modulo its loop) with a
	## SEEK_FADE crossfade, if it is more than SEEK_SLACK off. Gameplay never
	## waits on this; a track that starts later (unmuted) starts in step.
	if _music_track == "":
		return
	_anchor = [_music_track, t, Time.get_ticks_usec()]
	var p := _music[_music_cur]
	if music_muted or not is_inside_tree() or p.stream == null or not (p.playing or p.stream_paused):
		return
	var loop := loop_seconds(p.stream)
	if loop <= 0.0:
		return
	var want := fposmod(t, loop)
	var off := absf(want - fposmod(p.get_playback_position(), loop))
	if minf(off, loop - off) <= SEEK_SLACK:
		return
	_start_music(SEEK_FADE, want)


static func loop_seconds(stream: AudioStream) -> float:
	## How long a music stream's loop is: a looping WAV's loop, a stem set's
	## first stem's, else its length.
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED and wav.loop_end > 0:
			return wav.loop_end / float(wav.mix_rate)
		return wav.get_length()
	if stream != null and stream.get_class() == "AudioStreamSynchronized":
		if int(stream.get("stream_count")) > 0:
			return loop_seconds(stream.call("get_sync_stream", 0))
		return 0.0
	return stream.get_length() if stream != null else 0.0


func _current_on() -> bool:
	## The current player carries the track (playing, or held by a tape stop).
	var p := _music[_music_cur]
	return (p.playing or p.stream_paused) and _fade_goal[_music_cur] > 0.0


func _start_music(fade: float, from := -1.0) -> void:
	var stream := _music_stream(_music_track)
	var old := _music_cur
	_fade_to(old, 0.0, fade)
	if stream == null:
		_tick_music(0.0)
		return
	if from < 0.0 and not _anchor.is_empty() and _anchor[0] == _music_track:
		var loop := loop_seconds(stream)
		if loop > 0.0:
			from = fposmod(float(_anchor[1]) + (Time.get_ticks_usec() - int(_anchor[2])) / 1e6, loop)
	var fresh := 1 - old
	var p := _music[fresh]
	p.stop()
	p.stream = stream
	p.stream_paused = false
	p.pitch_scale = _tape
	_fade[fresh] = 0.0
	_fade_to(fresh, 1.0, fade)
	_music_cur = fresh
	_apply_stems()
	_tick_music(0.0)
	p.play(maxf(from, 0.0))
	if _tape_held:
		p.stream_paused = true


func _fade_to(i: int, goal: float, seconds: float) -> void:
	_fade_goal[i] = goal
	if seconds <= 0.0:
		_fade[i] = goal
		_fade_rate[i] = 1.0
	else:
		_fade_rate[i] = 1.0 / seconds


func _tick_music(delta: float) -> void:
	## Move the fades, the duck, the hush, the tape and the stems on by delta
	## seconds, set the players' volumes, and stop a player once it has faded
	## out.
	_clock += delta
	var goal := _duck_depth if _clock < _duck_until else 0.0
	if _clock >= _duck_until:
		_duck_depth = 0.0
	if _duck_db > goal:
		_duck_db = maxf(goal, _duck_db - DUCK_ATTACK * delta)
	else:
		_duck_db = minf(goal, _duck_db + DUCK_RELEASE * delta)
	for i in range(_music.size()):
		_fade[i] = move_toward(_fade[i], _fade_goal[i], _fade_rate[i] * delta)
		var p := _music[i]
		if _fade[i] <= 0.0 and _fade_goal[i] <= 0.0:
			if p.playing or p.stream_paused:
				p.stop()
				p.stream_paused = false
			continue
		# Equal-power: two tracks crossing keep the same loudness.
		var g := sin(_fade[i] * PI * 0.5) * get_volume()
		p.volume_db = linear_to_db(maxf(g, 0.0001)) + MUSIC_DB + _duck_db
	_tick_hush(delta)
	_tick_tape(delta)
	_tick_stems(delta)
	_tick_ambience(delta)
	_tick_lowpass(delta)


func _tick_lowpass(delta: float) -> void:
	## Glide the low-life cutoff toward its goal, in octaves (so the sweep
	## sounds even), then put the lower of it and the hush's on the filter,
	## switching the filter off once both are fully open.
	var goal := LOWPASS_HZ if _lowpass else LOWPASS_OPEN
	if _lowpass_hz != goal:
		var octave := log(_lowpass_hz / goal) / log(2.0)
		var step := LOWPASS_GLIDE * delta
		_lowpass_hz = goal if absf(octave) <= step else _lowpass_hz * pow(2.0, -signf(octave) * step)
		_apply_lowpass()
	elif minf(_lowpass_hz, hush_hz()) != _cutoff:
		_apply_lowpass()


func _apply_lowpass() -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	var slot := _lowpass_slot(bus) if bus >= 0 else -1
	if slot < 0:
		return
	var lp := AudioServer.get_bus_effect(bus, slot) as AudioEffectLowPassFilter
	_cutoff = minf(_lowpass_hz, hush_hz())
	lp.cutoff_hz = _cutoff
	AudioServer.set_bus_effect_enabled(bus, slot, _lowpass or _cutoff < LOWPASS_OPEN or _hush > 0.0)


func _music_stream(track: String) -> AudioStream:
	## The track's stream, loaded (see load_music) the first time it is asked
	## for; a stem set's (see _stems_stream); a track not written yet stands in
	## with its TRACK_FALLBACK's; one with none is warned about once, then
	## stays null.
	if _is_stem_set(track):
		return _stems_stream(track)
	if _music_cache.has(track):
		return _music_cache[track]
	var path := MUSIC_PATH % track
	var stream := load_music(path)
	if stream == null and TRACK_FALLBACK.has(track):
		stream = _music_stream(str(TRACK_FALLBACK[track]))
	elif stream == null and not track.begins_with("amb_"):
		push_warning("Sfx: no music track '%s' (%s)" % [track, path])
	_music_cache[track] = stream
	return stream


static func load_music(path: String) -> AudioStream:
	## A music WAV, looping. The imported resource if there is one; before it
	## has been imported (a fresh checkout, the headless tests) the file read
	## straight off disk, never importing it; else null.
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamWAV.load_from_file(path)
	return loop_music(stream)


static func loop_music(stream: AudioStream) -> AudioStream:
	## Set a music WAV looping over all but its last MUSIC_PAD frames, which
	## repeat the loop's first ones: the resampler reads a frame past the
	## loop end, and finding silence there it would tick once a loop. (The
	## file's 'smpl' chunk marks the same loop, which the importer picks up.)
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var frames := roundi(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = maxi(1, frames - MUSIC_PAD)
	return stream


# ---------------------------------------------------------------- stems

func play_stems(set: String, vols := {}) -> void:
	## Play a stem set (STEMS) through the crossfade: every stem in one
	## AudioStreamSynchronized, so they never drift, each at 0 dB unless vols
	## gives it a level ({stem: dB}). Asking for the set already playing
	## doesn't restart it (a Descent floor keeps its music); vols then glide in
	## over STEM_FADE. When stems can't play (STEMS_PREMIXED, or a stem file
	## missing) the set's PREMIX variants stand in; with none, its
	## TRACK_FALLBACK track.
	if not _is_stem_set(set):
		push_warning("Sfx: no stem set '%s'" % set)
		return
	var same := set == _music_track and (music_muted or _current_on())
	if not same:
		for stem in _stem_list(set):
			_stem_db[stem] = 0.0
			_stem_goal[stem] = 0.0
			_stem_speed.erase(stem)
	for stem in vols:
		if same:
			set_stem(str(stem), float(vols[stem]), STEM_FADE)
		else:
			var db := clampf(float(vols[stem]), STEM_OFF_DB, 12.0)
			_stem_db[str(stem)] = db
			_stem_goal[str(stem)] = db
	if same:
		return
	_music_track = set
	_anchor = []
	_stem_mode = ""
	_premix = ""
	_reset_tape()
	if music_muted or not is_inside_tree():
		return
	_start_music(MUSIC_FADE)


func set_stem(stem: String, db: float, seconds: float) -> void:
	## Glide one stem of the set playing to db over `seconds` (0: at once):
	## the Hush eats the drums (-80 over 2 s), the wick melody follows the
	## flame (-18 + 18 f). A set starts its stems at 0 dB, or at play_stems'
	## vols. With the premixes standing in, the stems up choose which plays.
	var goal := clampf(db, STEM_OFF_DB, 12.0)
	_stem_goal[stem] = goal
	var now := float(_stem_db.get(stem, 0.0))
	_stem_db[stem] = now
	if seconds <= 0.0:
		_stem_db[stem] = goal
		_stem_speed.erase(stem)
	else:
		_stem_speed[stem] = absf(db_to_linear(goal) - db_to_linear(now)) / seconds
	_apply_stems()


func stem_db(stem: String) -> float:
	## A stem's level now, in dB (0 for one never set).
	return float(_stem_db.get(stem, 0.0))


func stem_mode() -> String:
	## How the stem set playing plays: "sync" (the stems themselves),
	## "premix", "track" (its TRACK_FALLBACK) or "" (no set).
	return _stem_mode


func register_stems(set: String, stems: Array, streams: Array = []) -> void:
	## A stem set made at runtime (the spike's, the tests'): its stems, and
	## optionally their streams (else they load from res://audio/<stem>.wav).
	_extra_stems[set] = stems.duplicate()
	_music_cache.erase("stems:" + set)
	for i in range(mini(stems.size(), streams.size())):
		_music_cache[stems[i]] = streams[i]


func _is_stem_set(track: String) -> bool:
	return STEMS.has(track) or _extra_stems.has(track)


func _stem_list(set: String) -> Array:
	return _extra_stems.get(set, STEMS.get(set, []))


func _stem_file(stem: String) -> AudioStream:
	if not _music_cache.has(stem):
		_music_cache[stem] = load_music(MUSIC_PATH % stem)
	return _music_cache[stem]


func _stems_stream(set: String) -> AudioStream:
	## The stream a stem set plays as now (and _stem_mode with it).
	if not STEMS_PREMIXED:
		var key := "stems:" + set
		if not _music_cache.has(key):
			_music_cache[key] = _build_sync(set)
		if _music_cache[key] != null:
			_stem_mode = "sync"
			return _music_cache[key]
	if PREMIX.has(set):
		var pick := _premix_pick(set)
		var s := _stem_file(pick)
		if s != null:
			_stem_mode = "premix"
			_premix = pick
			return s
	_stem_mode = "track"
	_premix = ""
	return _music_stream(str(TRACK_FALLBACK.get(set, "boss")))


func _build_sync(set: String) -> AudioStream:
	## Every stem of a set in one AudioStreamSynchronized, or null (warned
	## once) if a stem won't load or the engine has no such class.
	var stems := _stem_list(set)
	var streams := []
	for stem in stems:
		var s := _stem_file(str(stem))
		if s == null:
			push_warning("Sfx: stem '%s' of '%s' is missing; the set plays a stand-in" % [stem, set])
			return null
		streams.append(s)
	if streams.is_empty() or not ClassDB.class_exists("AudioStreamSynchronized"):
		return null
	var sync: AudioStream = ClassDB.instantiate("AudioStreamSynchronized")
	sync.set("stream_count", streams.size())
	for i in range(streams.size()):
		sync.call("set_sync_stream", i, streams[i])
		sync.call("set_sync_stream_volume", i, float(_stem_db.get(stems[i], 0.0)))
	return sync


func _premix_pick(set: String) -> String:
	## The premix holding every stem that's up (its goal above STEM_ON_DB)
	## with the fewest others; the fullest if none holds them all.
	var up := _stem_list(set).filter(func(s): return float(_stem_goal.get(s, 0.0)) > STEM_ON_DB)
	var variants: Dictionary = PREMIX[set]
	var best := ""
	for v in variants:
		var holds: Array = variants[v]
		if up.all(func(s): return holds.has(s)) and (best == "" or holds.size() < (variants[best] as Array).size()):
			best = v
	return best if best != "" else str(variants.keys()[0])


func _tick_stems(delta: float) -> void:
	if _stem_speed.is_empty():
		return
	for stem in _stem_speed.keys():
		var goal: float = _stem_goal[stem]
		var g := move_toward(db_to_linear(float(_stem_db[stem])), db_to_linear(goal), float(_stem_speed[stem]) * delta)
		var db := linear_to_db(maxf(g, db_to_linear(STEM_OFF_DB)))
		if absf(db - goal) < 0.01 or (goal <= STEM_OFF_DB and db <= STEM_OFF_DB + 0.01):
			db = goal
			_stem_speed.erase(stem)
		_stem_db[stem] = db
	_apply_stems()


func _apply_stems() -> void:
	## Put the stems' levels on the set playing: on the synchronized stream's
	## own volumes, or (premixed) by crossfading to the variant they call for.
	if _music_track == "" or not _is_stem_set(_music_track):
		return
	if _stem_mode == "sync":
		var stems := _stem_list(_music_track)
		for p in _music:
			if p.stream != null and p.stream.get_class() == "AudioStreamSynchronized":
				for i in range(mini(stems.size(), int(p.stream.get("stream_count")))):
					p.stream.call("set_sync_stream_volume", i, float(_stem_db.get(stems[i], 0.0)))
	elif _stem_mode == "premix" and PREMIX.has(_music_track):
		var pick := _premix_pick(_music_track)
		if pick != _premix and not music_muted and is_inside_tree():
			var p := _music[_music_cur]
			var loop := loop_seconds(p.stream)
			_start_music(PREMIX_FADE, fposmod(p.get_playback_position(), loop) if loop > 0.0 else 0.0)


# ---------------------------------------------------------------- the tape

func tape_stop(seconds := 0.35) -> void:
	## The Tinker stops time: the music's pitch ramps down to TAPE_FLOOR over
	## `seconds`, then it pauses there (never ramped to 0, which clicks).
	## tape_go() brings it back; a new track starts it afresh.
	_tape_goal = TAPE_FLOOR
	if seconds <= 0.0:
		_tape = TAPE_FLOOR
		_tape_rate = 0.0
	else:
		_tape_rate = (1.0 - TAPE_FLOOR) / seconds
	_tick_tape(0.0)


func tape_go(seconds := 0.25) -> void:
	## Time runs again: the music unpauses and its pitch ramps back to 1.
	_tape_goal = 1.0
	if seconds <= 0.0:
		_tape = 1.0
		_tape_rate = 0.0
	else:
		_tape_rate = (1.0 - TAPE_FLOOR) / seconds
	if _tape_held:
		_tape_held = false
		for p in _music:
			p.stream_paused = false
	_tick_tape(0.0)


func tape_stopped() -> bool:
	## True from tape_stop() until tape_go().
	return _tape_goal < 1.0


func _tick_tape(delta: float) -> void:
	_tape = move_toward(_tape, _tape_goal, _tape_rate * delta)
	for p in _music:
		if p.pitch_scale != _tape:
			p.pitch_scale = _tape
	if _tape_goal < 1.0 and _tape <= TAPE_FLOOR and not _tape_held:
		_tape_held = true
		for p in _music:
			if p.playing:
				p.stream_paused = true


func _reset_tape() -> void:
	_tape = 1.0
	_tape_goal = 1.0
	_tape_rate = 0.0
	_tape_held = false
	for p in _music:
		p.pitch_scale = 1.0
		p.stream_paused = false


# ---------------------------------------------------------------- ambience

func play_ambience(bed: String, db := 0.0) -> void:
	## Fade in a world's bed (res://audio/<bed>.wav, looping) on the Ambience
	## bus, crossfading from the one before; db moves it (a secret level
	## plays its world's bed at -6). The same bed again only takes the new
	## level. A bed not written yet is quiet. The beds are sounds: muted
	## silences them, not music_muted.
	if bed == "":
		stop_ambience()
		return
	_amb_db = db
	if bed == _amb_track and (muted or (_amb[_amb_cur].playing and _amb_goal[_amb_cur] > 0.0)):
		_tick_ambience(0.0)
		return
	_amb_track = bed
	if muted or not is_inside_tree():
		return
	_start_ambience(AMBIENCE_FADE)


func stop_ambience(fade := AMBIENCE_FADE) -> void:
	## Fade the bed out over `fade` seconds and forget it.
	_amb_track = ""
	for i in range(_amb.size()):
		_amb_to(i, 0.0, fade)
	_tick_ambience(0.0)


func ambience_playing() -> String:
	## The bed playing (or asked for, while muted), or "".
	return _amb_track


func _start_ambience(fade: float) -> void:
	var stream := _music_stream(_amb_track)
	var old := _amb_cur
	_amb_to(old, 0.0, fade)
	if stream == null:
		_tick_ambience(0.0)
		return
	var fresh := 1 - old
	var p := _amb[fresh]
	p.stop()
	p.stream = stream
	_amb_fade[fresh] = 0.0
	_amb_to(fresh, 1.0, fade)
	_amb_cur = fresh
	_tick_ambience(0.0)
	p.play()


func _amb_to(i: int, goal: float, seconds: float) -> void:
	_amb_goal[i] = goal
	if seconds <= 0.0:
		_amb_fade[i] = goal
		_amb_rate[i] = 1.0
	else:
		_amb_rate[i] = 1.0 / seconds


func _tick_ambience(delta: float) -> void:
	for i in range(_amb.size()):
		_amb_fade[i] = move_toward(_amb_fade[i], _amb_goal[i], _amb_rate[i] * delta)
		var p := _amb[i]
		if _amb_fade[i] <= 0.0 and _amb_goal[i] <= 0.0:
			if p.playing:
				p.stop()
			continue
		var g := sin(_amb_fade[i] * PI * 0.5) * get_volume()
		p.volume_db = linear_to_db(maxf(g, 0.0001)) + AMBIENCE_DB + _amb_db


# ---------------------------------------------------------------- the spikes

func start_spike(what: String, host: Node = null) -> bool:
	## Debug builds: start one of the audio spikes (scripts/sfx_spike.gd):
	## "boot" (first-boot render times with a dummy v3 bank) or
	## "stems[:minutes[:pcm]]" (5 stems played for 10 minutes, their drift
	## measured). host is main (the spike shows the title on it). It logs
	## "[spike]" lines and quits when done. False if it can't start.
	if _spike != "":
		return true
	if not OS.is_debug_build() or not is_inside_tree() or not ResourceLoader.exists(SPIKE_PATH):
		return false
	_spike = what
	var spike: Node = load(SPIKE_PATH).new()
	spike.name = "SfxSpike"
	spike.set("what", what)
	spike.set("host", host)
	get_tree().root.add_child.call_deferred(spike)
	return true


static func spike_arg() -> String:
	## The audio spike asked for on the command line (--autoplay=spike:<what>,
	## what = boot or stems[:minutes[:pcm]]), in a debug build, or "". The GPU
	## spike shares the prefix (spike:all, lights48 ...; W0-render's): not ours.
	if not OS.is_debug_build():
		return ""
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--autoplay=spike:"):
			var what := a.trim_prefix("--autoplay=spike:")
			if what.get_slice(":", 0) in ["boot", "stems"]:
				return what
	return ""


func _spike_later(what: String) -> void:
	## main.gd routes --autoplay=spike:<what> to start_spike; if it hasn't
	## (an older main), start it here once main is up.
	await get_tree().process_frame
	await get_tree().process_frame
	if _spike == "":
		start_spike(what, get_tree().current_scene)


# ---------------------------------------------------------------- the sounds

static func render(sound: String, take: int = 0) -> PackedFloat32Array:
	## The finished samples (mono, RATE Hz, -1..1) for one of NAMES; `take`
	## picks a variation for the sounds in TAKES. The last number in each is
	## how loud it should feel, in dB (see loudness_db).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound) + 7919 * take
	var b: PackedFloat32Array
	match sound:
		# ---- menus
		"click":
			# A small woodblock tick.
			b = _silence(0.07)
			_partial(b, 0.0, 980.0, 1.0, 0.011, 0.001)
			_partial(b, 0.0, 2540.0, 0.3, 0.005, 0.001)
			_air(b, rng, 0.0, 0.012, 0.25, 3000.0, 3000.0, 3000.0, 0.2, 1.2)
			return _finish(b, -23.0)
		"select":
			# Two harpsichord plucks, up a fourth.
			b = _silence(0.36)
			_pluck(b, 0.0, _hz(81), 0.75, 0.09)
			_pluck(b, 0.045, _hz(86), 1.0, 0.12)
			return _finish(b, -19.0)
		"back":
			# The same plucks coming back down, duller.
			b = _silence(0.34)
			_pluck(b, 0.0, _hz(86), 0.75, 0.07, 0.6)
			_pluck(b, 0.05, _hz(81), 1.0, 0.11, 0.6)
			return _finish(b, -20.0)
		"pause":
			# Two soft organ notes falling a fifth: the game holds its breath.
			b = _silence(0.6)
			_organ(b, 0.0, _hz(81), 0.8, 0.15, 0.1, 0.006, 0.05)
			_organ(b, 0.13, _hz(74), 1.0, 0.42, 0.1, 0.006, 0.25)
			return _finish(b, -19.0)

		# ---- the story's voices: a blip every few letters as a line types.
		# talk and talk_low are on D, so a blip played at voice_note(voice, i)
		# sings in D minor whatever the speaker's voice. (voice * note(i) only
		# does for a voice that is a D, like 0.5 or 1.0; Mother Taper's 1.6
		# would blip Bb, C#, Eb, F and Ab over the story's music.)
		"talk":
			# Most speakers: a tiny harpsichord pluck on D5, 35 ms, the quill's
			# tick and a bright string that is gone before the next letter.
			b = _silence(0.035)
			_pluck(b, 0.0, _hz(74), 1.0, 0.011, 0.85)
			_hiss(b, rng, 0.0, 0.003, 0.08)
			return _finish(b, -20.5, 0.008)
		"talk_low":
			# Old Tollgrave: a small low wooden knock on D4 with a bell's
			# partial ringing a fifth above it (60 ms), old wood and old bronze.
			b = _silence(0.06)
			_bar(b, 0.0, _hz(62), 0.9, 0.02, 1.1)
			_thud(b, 0.0, 340.0, 220.0, 0.45, 0.014)
			_partial(b, 0.003, _hz(81), 0.32, 0.03)
			_partial(b, 0.003, _hz(81) * 2.76, 0.1, 0.012, 0.001)
			return _finish(b, -20.0, 0.012)
		"talk_breath":
			# The Snuffer: no pitch at all, a 70 ms puff of breath, mostly the
			# airy top of a whisper with a little hollow under it.
			b = _silence(0.07)
			_air(b, rng, 0.0, 0.07, 0.7, 700.0, 1800.0, 1100.0, 0.3, 0.7)
			_band(b, rng, 0.0, 0.07, 0.9, [[0.0, 0.0], [0.02, 1.0], [0.07, 0.0]], [[0.0, 2200.0], [0.02, 3200.0], [0.07, 2600.0]], 0.9)
			return _finish(b, -22.0, 0.02)
		"whoosh":
			# Air moving (a figure leaving, a shot changing): a quarter second
			# of wind rising through the mids and falling away.
			b = _silence(0.25)
			_air(b, rng, 0.0, 0.25, 1.0, 300.0, 1700.0, 420.0, 0.45, 1.8)
			_band(b, rng, 0.02, 0.21, 0.4, [[0.0, 0.0], [0.1, 1.0], [0.21, 0.0]], [[0.0, 1500.0], [0.1, 4200.0], [0.21, 1700.0]], 2.2)
			return _finish(b, -20.0, 0.03)

		# ---- the knight
		"step":
			# A tiny tick of a boot on stone.
			b = _silence(0.07)
			_partial(b, 0.0, 620.0, 0.5, 0.01, 0.001)
			_air(b, rng, 0.0, 0.02, 1.0, 2600.0, 2200.0, 1500.0, 0.15, 1.3)
			return _finish(b, -30.0)
		"jump":
			# A springy chirp up, a little pluck at take-off and the air rushing past.
			b = _silence(0.26)
			_sweep(b, 0.0, [[0.0, 330.0], [0.075, 880.0]], 0.8, 0.07, 0.24, [1.0, 0.35, 0.12])
			_pluck(b, 0.0, _hz(74), 0.2, 0.04, 0.5)
			_air(b, rng, 0.0, 0.16, 0.35, 700.0, 2600.0, 1800.0, 0.35, 1.6)
			return _finish(b, -21.0)
		"land":
			# A soft boot on stone: the knock in the low mids, a scuff of grit.
			b = _silence(0.16)
			_thud(b, 0.0, 320.0, 160.0, 1.0, 0.025)
			_partial(b, 0.0, 520.0, 0.6, 0.015)
			_air(b, rng, 0.0, 0.05, 0.6, 1400.0, 1200.0, 700.0, 0.1, 1.0)
			return _finish(b, -25.0)
		"double_jump":
			# Airier and higher, with a flutter of feathers: four quick wingbeats.
			b = _silence(0.36)
			_sweep(b, 0.0, [[0.0, 560.0], [0.09, 1320.0]], 0.45, 0.08, 0.3, [1.0, 0.2])
			for i in range(4):
				_air(b, rng, 0.015 + i * 0.045, 0.05, 0.55 - 0.08 * i, 1200.0 + 250.0 * i, 3200.0, 2400.0, 0.3, 1.1)
			_air(b, rng, 0.0, 0.3, 0.3, 900.0, 2800.0, 2000.0, 0.4, 0.9)
			return _finish(b, -21.5)
		"slash":
			# The sword through the air: a band of noise sweeping up and away.
			b = _silence(0.2)
			_air(b, rng, 0.0, 0.17, 1.0, 900.0, 3500.0, 1700.0, 0.35, 2.4)
			_air(b, rng, 0.02, 0.1, 0.4, 2000.0, 3600.0, 3000.0, 0.4, 3.0)
			return _finish(b, -21.0)
		"slash_hit":
			# The blade connects: a crack, a metal plate ringing, a body under it.
			b = _silence(0.32)
			_air(b, rng, 0.0, 0.03, 1.0, 2500.0, 3200.0, 1800.0, 0.1, 0.8)
			_thud(b, 0.0, 320.0, 180.0, 0.7, 0.04)
			_bronze(b, 0.0, 1150.0, 0.45, 0.09)
			return _finish(b, -17.0)
		"stomp":
			# Squash! A drum-like thump and a squish, then a springy boing up.
			b = _silence(0.32)
			_thud(b, 0.0, 420.0, 150.0, 1.0, 0.05)
			_air(b, rng, 0.0, 0.05, 0.6, 700.0, 1100.0, 500.0, 0.2, 1.4)
			_sweep(b, 0.035, [[0.0, 300.0], [0.09, 820.0]], 0.6, 0.08, 0.26, [1.0, 0.4, 0.15], 0.04, 28.0)
			return _finish(b, -16.0)
		"hurt":
			# The candle flame gutters and crackles; the knight squeaks "eep".
			b = _silence(0.42)
			_sweep(b, 0.0, [[0.0, 620.0], [0.05, 1000.0], [0.18, 560.0]], 0.7, 0.1, 0.22, [1.0, 0.5, 0.3, 0.15])
			_air(b, rng, 0.0, 0.25, 0.5, 300.0, 900.0, 400.0, 0.2, 0.8)
			for i in range(7):
				_air(b, rng, 0.02 + rng.randf() * 0.3, rng.randf_range(0.008, 0.02), rng.randf_range(0.3, 0.8),
						1800.0, 3000.0, 2000.0, 0.3, 1.5)
			return _finish(b, -16.5)
		"snuff":
			# Death: the flame blown out, a curl of smoke, and a sad fall to the root.
			b = _silence(1.5)
			_air(b, rng, 0.0, 0.32, 0.9, 1200.0, 2600.0, 900.0, 0.25, 0.7)
			_air(b, rng, 0.2, 0.5, 0.2, 800.0, 600.0, 300.0, 0.2, 0.6)
			var notes := [81, 77, 76, 74]
			var times := [0.28, 0.5, 0.72, 0.98]
			for i in range(notes.size()):
				_bell(b, times[i], _hz(notes[i]), 0.7, 0.25 if i < 3 else 0.5)
			_organ(b, 0.98, _hz(62), 0.3, 0.5, 0.0, 0.05, 0.3)
			return _finish(b, -16.5, 0.25)
		"relight":
			# Respawn: a match struck, the flame catching, a warm rising chime.
			b = _silence(0.9)
			for i in range(6):
				_air(b, rng, i * 0.012, 0.018, 0.6, 2400.0, 3400.0, 2600.0, 0.3, 1.8)
			_hiss(b, rng, 0.0, 0.08, 0.25)
			_air(b, rng, 0.07, 0.5, 1.0, 250.0, 1400.0, 900.0, 0.45, 0.9)
			_bell(b, 0.25, _hz(74), 0.35, 0.2)
			_bell(b, 0.33, _hz(81), 0.4, 0.22)
			_bell(b, 0.41, _hz(86), 0.5, 0.3)
			return _finish(b, -17.0, 0.1)
		"crit":
			# Laid over a hit that crits: a glassy "ti-ting", D7 and then A7 a
			# breath later, gone in a tenth of a second, so it sparkles on top
			# of the blow without muddying it.
			b = _silence(0.13)
			_hiss(b, rng, 0.0, 0.004, 0.25)
			_partial(b, 0.0, _hz(98), 0.8, 0.022, 0.0008)
			_partial(b, 0.0, _hz(98) * 2.32, 0.25, 0.01, 0.0008)
			_partial(b, 0.016, _hz(105), 0.6, 0.02, 0.0008)
			_partial(b, 0.016, _hz(105) * 1.5, 0.15, 0.008, 0.0008)
			return _finish(b, -19.0, 0.02)
		"fizzle":
			# Not enough to cast (any calling's Special, short of its resource):
			# a dud. A damp little puff of air, a spark that catches and dies
			# on a falling "pfft", and a sputter; quiet, it only says "not yet".
			b = _silence(0.3)
			_air(b, rng, 0.0, 0.16, 0.8, 1300.0, 900.0, 500.0, 0.15, 0.9)
			_sweep(b, 0.0, [[0.0, 700.0], [0.14, 330.0]], 0.3, 0.06, 0.16, [1.0, 0.4, 0.2])
			_hiss(b, rng, 0.0, 0.08, 0.2, 0.7)
			return _finish(b, -21.0, 0.05)

		# ---- the Candleknight
		"guard_up":
			# The lantern shield raised: a shrug of leather and the brass rim
			# ticking against the arm guard. Small, so raising it again and
			# again never nags.
			b = _silence(0.22)
			_air(b, rng, 0.0, 0.1, 0.8, 500.0, 1400.0, 900.0, 0.45, 1.0)
			_bronze(b, 0.06, 1180.0, 0.35, 0.03)
			_thud(b, 0.06, 420.0, 260.0, 0.25, 0.015)
			return _finish(b, -23.0)
		"finisher":
			# The third blow of a combo, a thrust (laid over the swing's slash):
			# a heavier rush of air driven forward, the stamp of the lead foot,
			# and the blade ringing out bronze-bright with a D6 glint in it.
			b = _silence(0.5)
			_air(b, rng, 0.0, 0.22, 1.0, 450.0, 2400.0, 800.0, 0.4, 1.8)
			_air(b, rng, 0.03, 0.14, 0.4, 1800.0, 4000.0, 2800.0, 0.3, 2.4)
			_thud(b, 0.0, 300.0, 150.0, 0.45, 0.035)
			_bronze(b, 0.07, 990.0, 0.5, 0.16)
			_bell(b, 0.07, _hz(86), 0.25, 0.2)
			return _finish(b, -17.0, 0.08)
		"guard_break":
			# The guard broken by a blow it couldn't hold: a crack, the shield's
			# brass ringing cracked (a second plate a sour semitone off, buzzing
			# against it and choked short), the arm knocked back, bits rattling
			# off. Heavier and uglier than any block.
			b = _silence(0.7)
			_air(b, rng, 0.0, 0.03, 1.0, 2600.0, 3600.0, 2000.0, 0.1, 0.8)
			_thud(b, 0.0, 360.0, 150.0, 1.0, 0.06)
			_bronze(b, 0.0, 395.0, 0.7, 0.12)
			_bronze(b, 0.0, 419.0, 0.5, 0.1)
			_air(b, rng, 0.02, 0.2, 0.35, 700.0, 1500.0, 500.0, 0.2, 0.9)
			for i in range(5):
				_clink(b, rng, 0.05 + i * 0.05 + rng.randf() * 0.02, rng.randf_range(1500.0, 2600.0), 0.3 * (1.0 - i * 0.15))
			return _finish(b, -14.5, 0.12)
		"guard_block":
			# A blow caught on the lantern shield: a dull thunk and a short,
			# damped ring of brass, the arm soaking it up. Duller than a clang.
			b = _silence(0.3)
			_thud(b, 0.0, 380.0, 170.0, 1.0, 0.04)
			_bronze(b, 0.0, 395.0, 0.5, 0.07)
			_air(b, rng, 0.0, 0.03, 0.6, 1600.0, 2300.0, 1200.0, 0.1, 0.9)
			return _finish(b, -17.5)
		"perfect_guard":
			# Timed just right: the blow glances off and the shield rings like a
			# small bell, a bright A6 ping with a shimmering twin, D6 under it
			# and D7 over it.
			b = _silence(0.9)
			_thud(b, 0.0, 400.0, 200.0, 0.4, 0.03)
			_air(b, rng, 0.0, 0.02, 0.5, 2600.0, 3400.0, 2600.0, 0.1, 0.9)
			_bell(b, 0.0, _hz(93), 0.9, 0.3)
			_bell(b, 0.0, _hz(93) + 5.0, 0.45, 0.3)
			_bell(b, 0.0, _hz(86), 0.35, 0.22)
			_bell(b, 0.03, _hz(98), 0.45, 0.22)
			return _finish(b, -14.5, 0.15)
		"rush":
			# Shield Rush: a heavy rush of air behind the shield, the push off
			# the stone, and the armor and lantern jangling as he charges.
			b = _silence(0.42)
			_air(b, rng, 0.0, 0.3, 1.0, 280.0, 1200.0, 420.0, 0.3, 1.0)
			_thud(b, 0.0, 320.0, 150.0, 0.7, 0.04)
			for i in range(5):
				_clink(b, rng, 0.02 + i * 0.04 + rng.randf() * 0.012, rng.randf_range(1700.0, 2400.0), 0.28 * (1.0 - i * 0.15))
			return _finish(b, -18.0)

		# ---- the Bellfounder
		"maul_hit":
			# The maul lands: a heavy crunch with her bell-metal head ringing on
			# after it, lower and longer than a sword's.
			b = _silence(0.5)
			_thud(b, 0.0, 330.0, 130.0, 1.0, 0.06)
			_air(b, rng, 0.0, 0.045, 0.9, 1400.0, 2100.0, 900.0, 0.1, 0.8)
			_bronze(b, 0.0, 440.0 + 12.0 * take, 0.55, 0.15)
			_partial(b, 0.0, 250.0, 0.35, 0.06)
			return _finish(b, -15.0)
		"peal":
			# Peal: she slams her bell into the stone. A crunch of floor and a
			# deep bronze bell on D (its fifth, A, rung with it), cut short so
			# the waves can ride out on it.
			b = _silence(2.2)
			_thud(b, 0.0, 280.0, 95.0, 0.3, 0.16)
			_thud(b, 0.0, 440.0, 170.0, 1.0, 0.08)
			_air(b, rng, 0.0, 0.05, 1.0, 1400.0, 1900.0, 800.0, 0.1, 0.7)
			_great_bell(b, rng, 0.0, _hz(50), 0.95, 0.5)
			_great_bell(b, rng, 0.0, _hz(57), 0.4, 0.35)
			for i in range(6):
				var t := 0.06 + rng.randf() * 0.35
				_air(b, rng, t, rng.randf_range(0.015, 0.035), rng.randf_range(0.15, 0.35) * (1.0 - t),
						900.0, rng.randf_range(1300.0, 2600.0), 800.0, 0.3, 1.4)
			return _finish(b, -12.5, 0.4)
		"anvil_drop":
			# Anvil Drop, the dive begins: the maul swung under her with a short
			# metal shing, then the air tearing past as she plummets and a
			# falling whistle sinking under it. (The landing is peal.)
			b = _silence(0.45)
			_bronze(b, 0.0, 760.0, 0.4, 0.05)
			_air(b, rng, 0.0, 0.44, 1.0, 1900.0, 900.0, 300.0, 0.18, 0.9)
			_sweep(b, 0.02, [[0.0, 1150.0], [0.4, 380.0]], 0.3, 0.35, 0.42, [1.0, 0.25])
			return _finish(b, -18.0)
		"clank":
			# Her Special asked for while the bell-metal is still cold: a dull iron
			# clank with no ring to it, and a cough of soot after.
			b = _silence(0.4)
			_thud(b, 0.0, 340.0, 190.0, 0.8, 0.03)
			_bar(b, 0.0, 290.0, 0.6, 0.04, 0.6)
			_bronze(b, 0.0, 610.0, 0.3, 0.035)
			_air(b, rng, 0.0, 0.02, 0.6, 1600.0, 2200.0, 1400.0, 0.1, 0.8)
			_air(b, rng, 0.05, 0.25, 0.4, 600.0, 900.0, 400.0, 0.25, 0.7)
			return _finish(b, -20.0, 0.06)

		# ---- the Taperwitch
		"spark":
			# A spark flicked off the staff: "fwip", a tone that jumps up and
			# settles, riding a bright little crackle.
			b = _silence(0.22)
			_sweep(b, 0.0, [[0.0, 520.0], [0.05, 1300.0], [0.2, 1050.0]], 0.45, 0.06, 0.2, [1.0, 0.45, 0.2])
			_air(b, rng, 0.0, 0.18, 0.8, 700.0, 2400.0, 1500.0, 0.2, 1.3)
			_hiss(b, rng, 0.0, 0.14, 0.35, 0.6)
			return _finish(b, -21.0)
		"flare_charge":
			# The flare gathering while the button is held: a hiss climbing the
			# spectrum, crackles thickening and a warm tone rising from D4 to
			# the A above, full by half a second and then simmering. The kit
			# lets go of it (Sfx.release) when she throws.
			b = _silence(1.5)
			_band(b, rng, 0.0, 1.5, 1.0, [[0.0, 0.0], [0.08, 0.15], [0.5, 1.0], [1.25, 0.75], [1.5, 0.0]],
					[[0.0, 600.0], [0.5, 4200.0], [1.5, 3600.0]], 2.4)
			_band(b, rng, 0.0, 1.5, 0.35, [[0.0, 0.0], [0.5, 1.0], [1.25, 0.7], [1.5, 0.0]],
					[[0.0, 1500.0], [0.5, 7000.0], [1.5, 6500.0]], 1.5)
			for i in range(34):
				var t := 1.3 * sqrt(rng.randf())
				_hiss(b, rng, t, rng.randf_range(0.004, 0.012), rng.randf_range(0.2, 0.5) * (0.3 + 0.7 * minf(1.0, t / 0.5)))
			var tone := _silence(1.5)
			_sweep(tone, 0.0, [[0.0, _hz(62)], [0.5, _hz(81)], [1.5, _hz(81)]], 0.5, 20.0, 1.5, [1.0, 0.4, 0.15], 0.004, 6.0)
			_layer(b, 0.0, tone, [[0.0, 0.0], [0.5, 0.7], [1.2, 0.55], [1.5, 0.0]])
			return _finish(b, -18.0, 0.15)
		"flare_throw":
			# The flare lobbed when she lets go: a "whoomp" as the fire leaves
			# the staff (a swoop of air, the low of the flame catching) and a
			# sputter of sparks trailing it up. (The charge's hiss is released
			# under it; flare_burst is where it lands.)
			b = _silence(0.45)
			_air(b, rng, 0.0, 0.3, 1.0, 260.0, 1100.0, 380.0, 0.25, 1.6)
			_sweep(b, 0.0, [[0.0, 200.0], [0.07, 420.0], [0.25, 240.0]], 0.35, 0.12, 0.28, [1.0, 0.5, 0.25, 0.12])
			_band(b, rng, 0.03, 0.28, 0.2, [[0.0, 0.0], [0.06, 1.0], [0.28, 0.0]], [[0.0, 2600.0], [0.28, 4200.0]], 1.2)
			# The sparks sputter out with the whoosh, none left popping after it.
			for i in range(8):
				var t := 0.02 + rng.randf() * 0.2
				_hiss(b, rng, t, rng.randf_range(0.004, 0.01), rng.randf_range(0.15, 0.35) * (1.0 - t / 0.25))
			return _finish(b, -18.5, 0.08)
		"flare_burst":
			# The flare bursts: a whump, a fireball blooming open, and the
			# burning ground roaring and crackling on after it.
			b = _silence(1.1)
			_thud(b, 0.0, 360.0, 110.0, 1.0, 0.1)
			_air(b, rng, 0.0, 0.5, 1.0, 300.0, 2300.0, 500.0, 0.08, 0.7)
			_band(b, rng, 0.0, 0.35, 0.35, [[0.0, 1.0], [0.35, 0.0]], [[0.0, 5000.0], [0.35, 2500.0]], 0.9)
			_air(b, rng, 0.05, 1.0, 0.4, 250.0, 700.0, 300.0, 0.2, 0.6)
			for i in range(22):
				var t := 0.03 + pow(rng.randf(), 1.4) * 0.95
				_hiss(b, rng, t, rng.randf_range(0.004, 0.012), rng.randf_range(0.2, 0.6) * (1.0 - t))
			return _finish(b, -13.5, 0.3)

		# ---- the Sootrunner
		"knife_throw":
			# A thrown knife: a thin, quick "fwit" of air, higher and shorter
			# than a sword, with the faintest glint of steel.
			b = _silence(0.14)
			_air(b, rng, 0.0, 0.11, 1.0, 1500.0, 3500.0, 2600.0, 0.3, 2.6)
			_band(b, rng, 0.005, 0.09, 0.5, [[0.0, 0.0], [0.03, 1.0], [0.09, 0.0]], [[0.0, 3500.0], [0.03, 5500.0], [0.09, 4200.0]], 2.0)
			_partial(b, 0.0, 3950.0 + 150.0 * take, 0.06, 0.012, 0.0008)
			return _finish(b, -22.5)
		"knife_hit":
			# The knife lands: the quick thock of a blade biting in, the
			# handle's wooden knock and a tick of steel.
			b = _silence(0.2)
			_thud(b, 0.0, 540.0, 270.0, 0.9, 0.028)
			_bar(b, 0.0, 1080.0 + 60.0 * take, 0.35, 0.022)
			_partial(b, 0.0, 3100.0, 0.25, 0.015, 0.0008)
			_air(b, rng, 0.0, 0.03, 0.6, 1800.0, 2600.0, 1400.0, 0.1, 0.8)
			return _finish(b, -18.0)
		"smoke_step":
			# Smoke Step: a soft "fwoomp" as she goes to smoke, a low swoop
			# down, a hiss of cinders, and the smoke settling behind her.
			b = _silence(0.5)
			_air(b, rng, 0.0, 0.3, 1.0, 380.0, 1350.0, 350.0, 0.22, 0.7)
			_band(b, rng, 0.0, 0.2, 0.35, [[0.0, 0.0], [0.04, 1.0], [0.2, 0.0]], [[0.0, 2500.0], [0.2, 4500.0]], 1.2)
			_sweep(b, 0.0, [[0.0, 330.0], [0.16, 165.0]], 0.3, 0.12, 0.3, [1.0, 0.6, 0.35, 0.2])
			_air(b, rng, 0.14, 0.34, 0.3, 700.0, 520.0, 300.0, 0.25, 0.6)
			return _finish(b, -19.0, 0.08)
		"backstab":
			# A backstab: the sting. A slice of steel and a harsh, bright stab
			# of D minor plucked high up, a bell glinting over it.
			b = _silence(0.75)
			_air(b, rng, 0.0, 0.05, 0.8, 2600.0, 3600.0, 2400.0, 0.1, 1.5)
			_thud(b, 0.0, 460.0, 230.0, 0.6, 0.03)
			_bronze(b, 0.0, 1480.0, 0.35, 0.05)
			for m in [86, 89, 93]:
				_pluck(b, 0.004, _hz(m), 0.5, 0.16, 1.2)
			_bell(b, 0.01, _hz(98), 0.35, 0.28)
			return _finish(b, -14.0, 0.12)

		# ---- the Sexton
		"knell":
			# His handbell rung (the Special's press): a small bright bell on
			# A5, the clapper's tick, the twelfth above it that a handbell is
			# tuned to, and a shimmer as it swings. Small and silver beside
			# toll_dead's dark D4, and the note wisp_call rises from.
			b = _silence(0.9)
			_clink(b, rng, 0.0, 3400.0, 0.25)
			_partial(b, 0.0, _hz(81), 0.9, 0.32, 0.001)
			_partial(b, 0.0, _hz(81) + 2.5, 0.35, 0.3, 0.001)
			_partial(b, 0.0, _hz(81) * 3.0, 0.5, 0.2, 0.001)
			_partial(b, 0.0, _hz(81) * 3.0 + 4.0, 0.2, 0.18, 0.001)
			_partial(b, 0.0, _hz(81) * 2.43, 0.15, 0.1, 0.001)
			_partial(b, 0.0, _hz(81) * 4.2, 0.12, 0.07, 0.0008)
			_partial(b, 0.0, _hz(81) * 5.1, 0.1, 0.05, 0.0008)
			return _finish(b, -18.0, 0.15)
		"mote":
			# A wisp's mote flying off: the softest glassy tick with a breath
			# of air, on A6, C7 or D7 by take, so a volley twinkles on the scale.
			b = _silence(0.16)
			var f := _hz([93, 96, 98][take % 3])
			_partial(b, 0.0, f, 0.8, 0.03, 0.001)
			_partial(b, 0.0, f * 2.0, 0.15, 0.012, 0.001)
			_air(b, rng, 0.0, 0.05, 0.25, 2500.0, 3400.0, 3000.0, 0.2, 1.2)
			return _finish(b, -26.0, 0.03)
		"wisp_pop":
			# A wisp takes a blow for him and is spent: a soft glassy pop, a
			# breath of pale air, and its chime falling, D6 to A5, as it goes out.
			b = _silence(0.55)
			_sweep(b, 0.0, [[0.0, 1800.0], [0.025, 700.0]], 0.6, 0.02, 0.05, [1.0, 0.3])
			_air(b, rng, 0.0, 0.18, 0.6, 900.0, 2400.0, 1200.0, 0.15, 0.9)
			_chime(b, 0.03, _hz(86), 0.5, 0.14)
			_chime(b, 0.11, _hz(81), 0.45, 0.2)
			_partial(b, 0.0, _hz(98), 0.2, 0.03, 0.001)
			return _finish(b, -19.5, 0.1)
		"wisp_call":
			# A Mourning Wisp answers the handbell: a soft chime rising a
			# fourth, A5 to D6, and the ghost of a sung "oo" breathing under it.
			b = _silence(1.0)
			_chime(b, 0.0, _hz(81), 0.55, 0.28)
			_chime(b, 0.09, _hz(86), 0.8, 0.4)
			_choir(b, rng, 0.02, _hz(81), 0.3, 0.8, 0.12, 0.5, OO)
			_air(b, rng, 0.0, 0.6, 0.12, 600.0, 1500.0, 900.0, 0.35, 0.8)
			return _finish(b, -19.0, 0.2)
		"toll_dead":
			# Toll the Dead: his handbell tolls once, dark and small (a D4
			# bell), as the wisps dive on the air and burst.
			b = _silence(1.8)
			_great_bell(b, rng, 0.0, _hz(62), 0.85, 0.45)
			_air(b, rng, 0.0, 0.32, 0.6, 500.0, 1900.0, 600.0, 0.55, 1.0)
			var burst := [81, 86, 89]
			for i in range(burst.size()):
				_air(b, rng, 0.2 + i * 0.07, 0.12, 0.45, 600.0, 1500.0, 500.0, 0.15, 0.8)
				_chime(b, 0.2 + i * 0.07, _hz(burst[i]), 0.2, 0.2)
			return _finish(b, -13.5, 0.5)
		"grave_step":
			# Grave Step: a bone ledge clacks up under his feet, two dry
			# xylophone knocks, A5 then D6.
			b = _silence(0.3)
			_bar(b, 0.0, _hz(81), 0.8, 0.028, 1.3)
			_bar(b, 0.03, _hz(86), 0.65, 0.024, 1.3)
			_thud(b, 0.0, 400.0, 230.0, 0.4, 0.02)
			return _finish(b, -19.5)

		# ---- the world
		"bump":
			# A head against a stone block from below: dull, in the mids.
			b = _silence(0.22)
			_thud(b, 0.0, 480.0, 230.0, 1.0, 0.045)
			_partial(b, 0.0, 760.0, 0.35, 0.02)
			_partial(b, 0.0, 1130.0, 0.15, 0.012)
			_air(b, rng, 0.0, 0.06, 0.35, 900.0, 700.0, 400.0, 0.1, 0.9)
			return _finish(b, -18.0)
		"block_break":
			# Stone cracks and crumbles: a thump, a crack, then chunks and grit.
			b = _silence(0.55)
			_thud(b, 0.0, 380.0, 160.0, 1.0, 0.06)
			_air(b, rng, 0.0, 0.04, 1.0, 2400.0, 2000.0, 1200.0, 0.1, 0.7)
			_air(b, rng, 0.0, 0.3, 0.35, 600.0, 900.0, 300.0, 0.15, 0.8)
			for i in range(16):
				var t := 0.03 + pow(rng.randf(), 1.5) * 0.4
				_air(b, rng, t, rng.randf_range(0.01, 0.03), rng.randf_range(0.2, 0.7) * (1.0 - t),
						1000.0, rng.randf_range(1200.0, 3200.0), 900.0, 0.3, 1.6)
			for i in range(5):
				_bar(b, 0.04 + rng.randf() * 0.3, rng.randf_range(900.0, 1600.0), 0.25, 0.012, 0.8)
			return _finish(b, -16.0)
		"reliquary":
			# The box pops open: a lid, a bronze clang, a sparkle running up.
			b = _silence(0.9)
			_thud(b, 0.0, 300.0, 170.0, 0.6, 0.03)
			_air(b, rng, 0.0, 0.02, 0.6, 1500.0, 2000.0, 1500.0, 0.2, 1.0)
			_bronze(b, 0.02, 620.0, 1.0, 0.35)
			var sparkle := [86, 89, 93, 98]
			for i in range(sparkle.size()):
				_bell(b, 0.1 + i * 0.05, _hz(sparkle[i]), 0.3, 0.12)
			return _finish(b, -15.0, 0.12)
		"ember":
			# A bright little "ba-ding" landing on D6. The streak plays it at
			# note(i), so the landing note is the one in tune.
			b = _silence(0.2)
			var f := _hz(86)
			_partial(b, 0.0, _hz(81), 0.4, 0.02, 0.001)
			_partial(b, 0.028, f, 1.0, 0.06, 0.001)
			_partial(b, 0.028, f * 2.0, 0.3 + 0.08 * take, 0.03, 0.001)
			_partial(b, 0.028, f * 3.0, 0.1, 0.015, 0.001)
			_hiss(b, rng, 0.0, 0.006, 0.15)
			return _finish(b, -21.0)
		"wax":
			# A dribble of wax, healing: a warm, soft F major chime.
			b = _silence(0.6)
			_chime(b, 0.0, _hz(77), 0.7, 0.28)
			_chime(b, 0.05, _hz(81), 0.8, 0.32)
			_chime(b, 0.1, _hz(84), 0.5, 0.3)
			_air(b, rng, 0.0, 0.25, 0.08, 500.0, 1100.0, 700.0, 0.3, 0.8)
			return _finish(b, -19.0, 0.1)
		"sigil":
			# A rare sigil: little bells strummed on D minor, a choir humming it.
			b = _silence(1.2)
			var chord := [74, 77, 81, 86]
			for i in range(chord.size()):
				_bell(b, i * 0.035, _hz(chord[i]), 0.6, 0.45 + 0.05 * i)
			for m in [74, 77, 81]:
				_choir(b, rng, 0.03, _hz(m), 0.35, 1.1, 0.08, 0.45)
			return _finish(b, -15.0, 0.2)
		"altar":
			# A checkpoint lit: the fire catches with a whoosh, and an open
			# fifth is sung.
			b = _silence(1.8)
			_air(b, rng, 0.0, 0.45, 1.0, 250.0, 1600.0, 700.0, 0.35, 0.9)
			_hiss(b, rng, 0.05, 0.3, 0.06, 0.6)
			for m in [62, 69, 74]:
				_choir(b, rng, 0.12, _hz(m), 0.6, 1.65, 0.25, 0.6)
			_bell(b, 0.15, _hz(81), 0.2, 0.4)
			return _finish(b, -15.0, 0.3)
		"bell":
			# The great bell at the level's end: a real church bell's partials
			# on a D3 prime, so its strike note is D4, with a smaller bell an
			# octave up struck with it to carry the toll through a phone.
			b = _silence(3.4)
			_great_bell(b, rng, 0.0, _hz(50), 1.0)
			_great_bell(b, rng, 0.0, _hz(62), 0.6, 0.6)
			return _finish(b, -12.0, 1.0)
		"clear":
			# Level clear: a reed pickup into organ chords climbing Bb, C, then
			# a D major, the minor key turning bright at the end.
			b = _silence(2.4)
			var pickup := [69, 74, 77]
			for i in range(pickup.size()):
				_organ(b, i * 0.1, _hz(pickup[i]), 0.55, 0.11, 0.9, 0.008, 0.03)
			var chords := [[58, 62, 65, 70, 74, 77], [60, 64, 67, 72, 76, 79], [50, 62, 66, 69, 74, 78, 81]]
			var starts := [0.32, 0.64, 0.96]
			var lengths := [0.32, 0.32, 1.35]
			for c in range(chords.size()):
				var at: float = starts[c]
				for m in chords[c]:
					_organ(b, at, _hz(m), 0.3, lengths[c], 0.5, 0.012, 0.05 if c < 2 else 0.5)
				_thud(b, at, 220.0, 110.0, 0.5 if c < 2 else 0.8, 0.1 if c < 2 else 0.2)
			_bell(b, 0.97, _hz(86), 0.3, 0.5)
			return _finish(b, -13.0, 0.4)
		"lava":
			# A sizzle of bright crackling noise, a steamy hiss and a blorp.
			b = _silence(0.6)
			_hiss(b, rng, 0.0, 0.55, 0.6, 0.7)
			_air(b, rng, 0.0, 0.4, 0.4, 500.0, 1300.0, 700.0, 0.15, 1.0)
			_sweep(b, 0.0, [[0.0, 180.0], [0.06, 340.0]], 0.6, 0.05, 0.12, [1.0, 0.4])
			return _finish(b, -19.0, 0.15)
		"spikes":
			# A sharp impact: a crack, a thin metal "shink", a body.
			b = _silence(0.3)
			_air(b, rng, 0.0, 0.02, 1.0, 3000.0, 3600.0, 2500.0, 0.1, 0.8)
			_thud(b, 0.0, 340.0, 160.0, 0.8, 0.04)
			_partial(b, 0.0, 2100.0, 0.3, 0.06, 0.0008)
			_partial(b, 0.0, 3150.0, 0.25, 0.04, 0.0008)
			_partial(b, 0.0, 3480.0, 0.2, 0.03, 0.0008)
			return _finish(b, -16.0)
		"heartbeat":
			# Low life: a heartbeat, lub-dub, soft and muffled. Driven drums, so
			# their overtones still thump on a phone speaker.
			b = _silence(0.5)
			_thump(b, 0.0, 300.0, 105.0, 1.0, 0.055, 3.0)
			_thud(b, 0.0, 520.0, 300.0, 0.3, 0.02)
			_air(b, rng, 0.0, 0.06, 0.35, 300.0, 600.0, 300.0, 0.2, 0.9)
			_thump(b, 0.17, 330.0, 115.0, 0.75, 0.045, 3.0)
			_thud(b, 0.17, 560.0, 320.0, 0.22, 0.018)
			_air(b, rng, 0.17, 0.05, 0.25, 300.0, 600.0, 300.0, 0.2, 0.9)
			return _finish(b, -22.0, 0.05)
		"chain_step":
			# A stomp chain's next step: a springy boing up into a bell on D5.
			# The engine plays it at note(n), so a chain climbs the scale.
			b = _silence(0.32)
			_sweep(b, 0.0, [[0.0, _hz(62)], [0.05, _hz(74)]], 0.3, 0.05, 0.1, [1.0, 0.3])
			_bell(b, 0.03, _hz(74), 0.8, 0.16)
			_pluck(b, 0.03, _hz(74), 0.4, 0.08)
			return _finish(b, -19.0)
		"flask":
			# The Tallow Flask: the cork out, three glugs (bubbles rising up the
			# neck, each higher as it empties) and the warm F major chime of
			# healing as it settles in.
			b = _silence(0.8)
			_sweep(b, 0.0, [[0.0, 1300.0], [0.025, 700.0]], 0.45, 0.02, 0.04, [1.0, 0.3])
			for i in range(3):
				var at := 0.07 + i * 0.15
				_sweep(b, at, [[0.0, 240.0 + 30.0 * i], [0.05, 560.0 + 60.0 * i], [0.08, 620.0 + 60.0 * i]],
						0.9, 0.04, 0.1, [1.0, 0.35, 0.1])
				_air(b, rng, at, 0.07, 0.35, 450.0, 900.0, 500.0, 0.3, 1.6)
				_thud(b, at, 320.0, 190.0, 0.3, 0.02)
			_chime(b, 0.52, _hz(77), 0.3, 0.22)
			_chime(b, 0.56, _hz(81), 0.3, 0.25)
			return _finish(b, -18.0, 0.12)
		"bank":
			# Embers made safe: a soft chime, D6 and the A6 above, like coins
			# settling in a dish. It sits high, over the altar's choir and the bell.
			b = _silence(0.8)
			_chime(b, 0.0, _hz(86), 0.6, 0.3)
			_chime(b, 0.07, _hz(93), 0.45, 0.35)
			_clink(b, rng, 0.0, 3000.0, 0.12)
			return _finish(b, -21.5, 0.2)
		"pool_reclaim":
			# The Guttered Pool taken back: the lost embers rush in (a swell of
			# air and a bell played backwards), land on a warm A5-D6 chime over
			# a hummed D, and ember dings tumble up after them.
			b = _silence(1.3)
			var back := _silence(0.4)
			_bell(back, 0.0, _hz(86), 1.0, 0.12)
			_bell(back, 0.0, _hz(81), 0.6, 0.12)
			_layer(b, 0.0, _reversed(back))
			_air(b, rng, 0.0, 0.42, 0.6, 300.0, 2600.0, 2600.0, 0.97, 0.8)
			var at := 0.4
			_chime(b, at, _hz(81), 0.6, 0.35)
			_chime(b, at, _hz(86), 0.7, 0.45)
			_choir(b, rng, at, _hz(74), 0.25, 0.8, 0.05, 0.5)
			var dings := [86, 89, 91, 93, 96, 98]
			for i in range(dings.size()):
				var f := _hz(dings[i])
				_partial(b, at + 0.05 + 0.055 * i, f, 0.3, 0.05, 0.001)
				_partial(b, at + 0.05 + 0.055 * i, f * 2.0, 0.08, 0.025, 0.001)
			return _finish(b, -15.5, 0.3)
		"level_up":
			# Level up: a harpsichord and bell arpeggio racing up D minor, then
			# the minor turns major under it (the F lifting to F#): an organ and
			# choir D major chord, sparkles climbing, and air rushing up the
			# pillar of light.
			b = _silence(2.1)
			var run := [69, 74, 77, 81, 86]
			for i in range(run.size()):
				_pluck(b, i * 0.055, _hz(run[i]), 0.5, 0.15)
				_bell(b, i * 0.055, _hz(run[i]), 0.25, 0.25)
			var at := 0.3
			for m in [50, 62, 66, 69, 74]:
				_organ(b, at, _hz(m), 0.26, 1.25, 0.5, 0.01, 0.45)
			for m in [66, 69, 74, 78]:
				_choir(b, rng, at, _hz(m), 0.3, 1.45, 0.06, 0.6)
			_bell(b, at, _hz(90), 0.5, 0.6)
			_bell(b, at + 0.004, _hz(90) + 4.0, 0.3, 0.6)
			var sparkle := [86, 90, 93, 98, 102]
			for i in range(sparkle.size()):
				_bell(b, at + 0.12 + i * 0.05, _hz(sparkle[i]), 0.2, 0.15)
			_air(b, rng, 0.0, 0.7, 0.35, 400.0, 3000.0, 2000.0, 0.5, 0.8)
			_thud(b, at, 260.0, 120.0, 0.6, 0.15)
			return _finish(b, -12.5, 0.5)

		# ---- World 2: wax and water
		"drip":
			# A drop of wax or water landing: a classic "plip", the little
			# bubble's pitch leaping up as it closes. Each take a different drop.
			b = _silence(0.18)
			var f0 := rng.randf_range(820.0, 1000.0)
			_sweep(b, 0.0, [[0.0, f0], [0.022, f0 * 2.1]], 1.0, 0.022, 0.08, [1.0])
			_partial(b, 0.0, 2900.0, 0.1, 0.004, 0.0005)
			return _finish(b, -24.0)
		"douse":
			# Doused: the flame gutters with a low "fwmp" and steam hisses off
			# it, spitting and sizzling, fading as the light shrinks.
			b = _silence(0.8)
			_sweep(b, 0.0, [[0.0, 420.0], [0.12, 210.0]], 0.35, 0.08, 0.16, [1.0, 0.5, 0.25])
			_air(b, rng, 0.0, 0.16, 0.4, 500.0, 900.0, 300.0, 0.2, 0.8)
			_band(b, rng, 0.0, 0.75, 0.8, [[0.0, 0.0], [0.03, 1.0], [0.25, 0.7], [0.75, 0.0]],
					[[0.0, 3200.0], [0.1, 5200.0], [0.75, 4200.0]], 0.8)
			for i in range(12):
				var t := pow(rng.randf(), 1.6) * 0.45
				_hiss(b, rng, t, rng.randf_range(0.003, 0.01), rng.randf_range(0.2, 0.5) * (1.0 - t))
			return _finish(b, -16.5, 0.25)
		"splash":
			# Into deep water: the plunge, a spray thrown up (a wide burst of
			# noise), bubbles glugging up and drops pattering back down.
			b = _silence(0.9)
			_thud(b, 0.0, 320.0, 140.0, 0.6, 0.05)
			_air(b, rng, 0.0, 0.35, 1.0, 500.0, 2600.0, 900.0, 0.12, 0.6)
			_band(b, rng, 0.0, 0.3, 0.45, [[0.0, 0.0], [0.02, 1.0], [0.3, 0.0]], [[0.0, 2500.0], [0.05, 5000.0], [0.3, 3000.0]], 0.8)
			for i in range(9):
				var t := 0.08 + rng.randf() * 0.45
				var f := rng.randf_range(450.0, 1100.0)
				_sweep(b, t, [[0.0, f], [0.03, f * 1.7]], rng.randf_range(0.15, 0.35) * (1.0 - t), 0.02, 0.05, [1.0])
			for i in range(8):
				var t := 0.18 + rng.randf() * 0.5
				_partial(b, t, rng.randf_range(1800.0, 3200.0), 0.12 * (1.0 - t), 0.008, 0.0008)
			return _finish(b, -15.5, 0.2)
		"waxfall":
			# A waxfall about to pour (its 0.4 s tell), then pouring: a gurgle
			# of fat bubbles coming faster and faster, into a thick rushing fall.
			b = _silence(1.3)
			var t := 0.0
			var gap := 0.08
			while t < 0.45:
				var f := rng.randf_range(260.0, 520.0) * (1.0 + t)
				_sweep(b, t, [[0.0, f], [0.04, f * 1.6]], 0.5 + 0.5 * t / 0.45, 0.03, 0.06, [1.0, 0.25])
				t += gap * rng.randf_range(0.6, 1.2)
				gap *= 0.85
			_air(b, rng, 0.3, 1.0, 1.0, 300.0, 850.0, 450.0, 0.3, 0.5)
			_air(b, rng, 0.33, 0.95, 0.45, 1100.0, 2300.0, 1500.0, 0.3, 0.7)
			return _finish(b, -18.0, 0.3)
		"lantern_light":
			# A lantern post lit: the wick scratches and catches with a soft
			# whoomp, and the lamp's glass rings a warm A5, then D6.
			b = _silence(1.0)
			for i in range(4):
				_air(b, rng, i * 0.014, 0.018, 0.55, 2400.0, 3400.0, 2600.0, 0.3, 1.8)
			_air(b, rng, 0.05, 0.42, 0.9, 250.0, 1300.0, 800.0, 0.35, 0.9)
			_bell(b, 0.12, _hz(81), 0.45, 0.32)
			_bell(b, 0.2, _hz(86), 0.5, 0.4)
			return _finish(b, -17.0, 0.2)
		"rubble":
			# Tollgrave's roof coming down in chunks: a heavy stone crash, the
			# crack of it breaking and pieces skittering off.
			b = _silence(0.75)
			_thud(b, 0.0, 380.0, 130.0, 1.0, 0.07)
			_air(b, rng, 0.0, 0.05, 1.0, 1800.0, 2200.0, 1000.0, 0.1, 0.7)
			_air(b, rng, 0.0, 0.4, 0.4, 500.0, 900.0, 300.0, 0.1, 0.8)
			for i in range(12):
				var t := 0.03 + pow(rng.randf(), 1.5) * 0.45
				_air(b, rng, t, rng.randf_range(0.01, 0.03), rng.randf_range(0.2, 0.6) * (1.0 - t),
						900.0, rng.randf_range(1200.0, 3000.0), 900.0, 0.3, 1.6)
			for i in range(4):
				_bar(b, 0.05 + rng.randf() * 0.3, rng.randf_range(700.0, 1300.0), 0.3, 0.015, 0.8)
			return _finish(b, -15.0)

		# ---- loot, rarer is richer
		"relic_drop":
			# A relic clinks onto stone and bounces twice.
			b = _silence(0.4)
			var times := [0.0, 0.1, 0.165, 0.205]
			var amps := [1.0, 0.55, 0.3, 0.15]
			for i in range(times.size()):
				_clink(b, rng, times[i], 2350.0 * (1.0 + 0.02 * i), amps[i])
			return _finish(b, -19.0)
		"item_drop":
			# Gear spills from a kill: a little pop out, a clink on the stone and
			# a ding on D6. The engine plays it higher for rarer finds (x1.12,
			# x1.26, x1.5: D, E, F#, A), so the ding climbs toward a legendary.
			b = _silence(0.45)
			_sweep(b, 0.0, [[0.0, 480.0], [0.04, 950.0]], 0.35, 0.03, 0.06, [1.0, 0.3])
			_clink(b, rng, 0.03, 2050.0, 0.7)
			_bell(b, 0.03, _hz(86), 0.5, 0.2)
			return _finish(b, -18.5)
		"equip":
			# Gear put on: a shrug of leather, a buckle clinking shut twice and a
			# soft pluck to say it took.
			b = _silence(0.4)
			_air(b, rng, 0.0, 0.12, 0.8, 600.0, 1500.0, 900.0, 0.4, 1.0)
			_thud(b, 0.09, 360.0, 200.0, 0.4, 0.025)
			_clink(b, rng, 0.09, 1750.0, 0.55)
			_clink(b, rng, 0.15, 2300.0, 0.4)
			_pluck(b, 0.15, _hz(86), 0.3, 0.1, 0.7)
			return _finish(b, -19.0)
		"salvage":
			# Gear broken down for embers: a crunch, a smoulder, and three ember
			# dings rising D6, F6, A6 as it burns away.
			b = _silence(0.7)
			_air(b, rng, 0.0, 0.06, 1.0, 1200.0, 2000.0, 900.0, 0.15, 0.8)
			_thud(b, 0.0, 330.0, 160.0, 0.5, 0.04)
			_hiss(b, rng, 0.02, 0.35, 0.3, 0.7)
			var dings := [86, 89, 93]
			for i in range(dings.size()):
				var f := _hz(dings[i])
				_partial(b, 0.1 + i * 0.07, f, 0.5, 0.06, 0.001)
				_partial(b, 0.1 + i * 0.07, f * 2.0, 0.15, 0.03, 0.001)
			return _finish(b, -19.0, 0.1)
		"relic_common":
			# A plain tink.
			b = _silence(0.4)
			_pluck(b, 0.0, _hz(74), 1.0, 0.1, 0.6)
			return _finish(b, -20.0)
		"relic_magic":
			# Two bells rising, each doubled a hair apart so they shimmer.
			b = _silence(0.7)
			_bell(b, 0.0, _hz(81), 0.7, 0.2)
			_bell(b, 0.0, _hz(81) + 3.0, 0.4, 0.2)
			_bell(b, 0.08, _hz(86), 0.9, 0.3)
			_bell(b, 0.08, _hz(86) + 3.5, 0.5, 0.3)
			return _finish(b, -18.0, 0.1)
		"relic_rare":
			# A D minor arpeggio of shimmering bells, a sparkle, a soft hum.
			b = _silence(1.0)
			var run := [74, 77, 81, 86]
			for i in range(run.size()):
				_bell(b, i * 0.06, _hz(run[i]), 0.7, 0.3 + 0.05 * i)
				_bell(b, i * 0.06, _hz(run[i]) + 4.0, 0.35, 0.3 + 0.05 * i)
			_bell(b, 0.3, _hz(93), 0.3, 0.15)
			_bell(b, 0.36, _hz(98), 0.3, 0.2)
			for m in [74, 81]:
				_choir(b, rng, 0.1, _hz(m), 0.25, 0.85, 0.15, 0.4)
			return _finish(b, -16.0, 0.2)
		"relic_legendary":
			# Unmistakable: a low boom, then a D major chord (with its ninth) of
			# bells shimmering over a swelling choir, sparkles climbing on top.
			b = _silence(2.5)
			_thud(b, 0.0, 150.0, 46.0, 1.0, 0.4)
			_thud(b, 0.0, 330.0, 140.0, 0.55, 0.09)
			_air(b, rng, 0.0, 0.7, 0.3, 500.0, 300.0, 120.0, 0.05, 0.7)
			var chord := [62, 69, 74, 76, 78, 81]
			for i in range(chord.size()):
				var at := 0.04 + 0.025 * i
				_bell(b, at, _hz(chord[i]), 0.5, 0.9)
				_bell(b, at, _hz(chord[i]) + 4.5, 0.35, 0.9)
			for m in [62, 69, 74, 78]:
				_choir(b, rng, 0.08, _hz(m), 0.3, 2.3, 0.35, 0.8)
			var sparkle := [86, 88, 90, 93, 95, 98, 100, 102]
			for i in range(sparkle.size()):
				_bell(b, 0.3 + i * 0.045, _hz(sparkle[i]), 0.22, 0.18)
			return _finish(b, -12.0, 0.6)

		# ---- enemies
		"bones":
			# A skeleton collapses: bony xylophone clacks tumbling down the
			# scale, faster and faster, onto a little thump.
			b = _silence(0.55)
			var pent := [74, 77, 79, 81, 84, 86, 89]
			var t := 0.0
			var gap := 0.055
			var top := pent.size() - 1
			for i in range(11):
				var degree := clampi(top - int(i * 0.6) + rng.randi_range(-1, 1), 0, top)
				_bar(b, t, _hz(pent[degree]), rng.randf_range(0.55, 1.0) * (1.0 - i * 0.05), rng.randf_range(0.015, 0.03), 1.2)
				t += gap * rng.randf_range(0.6, 1.3)
				gap *= 0.86
			_thud(b, t, 300.0, 170.0, 0.4, 0.04)
			return _finish(b, -17.0)
		"bat":
			# Eek-eek: two squeaks, the second weaker, and a poof.
			b = _silence(0.3)
			_sweep(b, 0.0, [[0.0, 2300.0], [0.04, 3300.0], [0.1, 1900.0]], 0.7, 0.06, 0.12, [1.0, 0.2])
			_sweep(b, 0.11, [[0.0, 2600.0], [0.03, 3100.0], [0.09, 1600.0]], 0.5, 0.05, 0.1, [1.0, 0.2])
			_air(b, rng, 0.05, 0.15, 0.35, 900.0, 1800.0, 700.0, 0.3, 0.8)
			return _finish(b, -18.0)
		"clang":
			# Armor that will not break: a tink off it and a metal ring.
			b = _silence(0.45)
			_air(b, rng, 0.0, 0.015, 0.8, 2500.0, 3200.0, 2000.0, 0.1, 0.9)
			_bronze(b, 0.0, 480.0, 1.0, 0.2)
			_thud(b, 0.0, 280.0, 200.0, 0.4, 0.03)
			return _finish(b, -16.5, 0.08)
		"enemy_hit":
			# A punchy thwack.
			b = _silence(0.2)
			_thud(b, 0.0, 360.0, 190.0, 1.0, 0.035)
			_air(b, rng, 0.0, 0.035, 0.8, 1800.0, 2600.0, 1200.0, 0.15, 1.0)
			_partial(b, 0.0, 900.0, 0.25, 0.015)
			return _finish(b, -18.0)
		"arrow_draw":
			# A Bonebow drawing (its 0.65 s tell): the bone bow creaking tighter
			# and tighter, a thin strained buzz rising under the creaks, and a
			# glint as the aim locks, 0.2 s before it looses.
			b = _silence(0.65)
			var creak := _silence(0.62)
			_sweep(creak, 0.0, [[0.0, 150.0], [0.6, 230.0]], 0.35, 30.0, 0.62,
					[1.0, 0.7, 0.5, 0.35, 0.25, 0.18, 0.12], 0.02, 17.0)
			_layer(b, 0.0, creak, [[0.0, 0.2], [0.45, 1.0], [0.62, 0.0]])
			var t := 0.0
			var gap := 0.07
			while t < 0.45:
				_bar(b, t, rng.randf_range(1500.0, 2300.0), 0.25 + 0.4 * t, 0.004, 0.5)
				t += gap * rng.randf_range(0.7, 1.3)
				gap *= 0.88
			_partial(b, 0.45, 3150.0, 0.25, 0.04, 0.001)
			_partial(b, 0.45, 4700.0, 0.12, 0.02, 0.001)
			return _finish(b, -21.0, 0.03)
		"arrow_fly":
			# The Bonebow looses: a dry twang of the string and the arrow's hiss
			# as it flies.
			b = _silence(0.42)
			_sweep(b, 0.0, [[0.0, 340.0], [0.02, 300.0]], 0.8, 0.06, 0.22, [1.0, 0.8, 0.6, 0.45, 0.3, 0.2], 0.012, 38.0)
			_thud(b, 0.0, 420.0, 260.0, 0.3, 0.015)
			_air(b, rng, 0.01, 0.38, 0.65, 1700.0, 3100.0, 2300.0, 0.2, 2.2)
			return _finish(b, -19.0)
		"parry":
			# An arrow swatted back: a bright steel "shing" and a ping (the
			# Perfect Guard's A6), and the shaft whipping away.
			b = _silence(0.6)
			_air(b, rng, 0.0, 0.02, 1.0, 3000.0, 3600.0, 2800.0, 0.1, 0.9)
			_bronze(b, 0.0, 1250.0, 0.6, 0.1)
			_bell(b, 0.0, _hz(93), 0.45, 0.22)
			_air(b, rng, 0.02, 0.26, 0.4, 2300.0, 3400.0, 1800.0, 0.15, 2.0)
			return _finish(b, -15.0, 0.1)
		"shield_clang":
			# A Hollow Helm's church-door shield turns a blow: a thick wooden
			# thump and its iron bands ringing. Heavier than armor's clang.
			b = _silence(0.5)
			_thud(b, 0.0, 280.0, 160.0, 1.0, 0.05)
			_bar(b, 0.0, 230.0, 0.5, 0.05, 0.8)
			_bronze(b, 0.0, 560.0, 0.6, 0.14)
			_air(b, rng, 0.0, 0.02, 0.8, 2200.0, 3000.0, 1800.0, 0.1, 0.9)
			return _finish(b, -16.0, 0.08)
		"bash":
			# A Hollow Helm lunges shield-first: a shove of air, the door
			# slamming forward and the empty armor rattling behind it.
			b = _silence(0.45)
			_air(b, rng, 0.0, 0.2, 0.8, 300.0, 1100.0, 350.0, 0.4, 1.0)
			_thud(b, 0.05, 360.0, 175.0, 1.0, 0.06)
			_bar(b, 0.05, 280.0, 0.55, 0.05, 0.8)
			for i in range(4):
				_clink(b, rng, 0.07 + i * 0.035 + rng.randf() * 0.01, rng.randf_range(1400.0, 2000.0), 0.3 * (1.0 - i * 0.2))
			return _finish(b, -16.0)
		"wing_sip":
			# A Gutterwing at the flame: a fast flutter of soft wings and a thin,
			# wavering "tsip" as it drinks the light.
			b = _silence(0.5)
			for i in range(11):
				_air(b, rng, i * 0.04, 0.034, 0.5 * (0.6 + 0.4 * sin(PI * i / 10.0)), 900.0, 1700.0, 1100.0, 0.3, 1.2)
			_sweep(b, 0.12, [[0.0, 1500.0], [0.22, 2150.0]], 0.22, 1.0, 0.24, [1.0, 0.2], 0.03, 28.0)
			_band(b, rng, 0.1, 0.28, 0.3, [[0.0, 0.0], [0.12, 1.0], [0.28, 0.0]], [[0.0, 3000.0], [0.28, 4500.0]], 1.5)
			return _finish(b, -24.0, 0.08)
		"wing_pop":
			# A latched Gutterwing swatted off: a cork-like pop, a puff of wing
			# dust, a last flutter, and the light coming back (a bright D6, A6).
			b = _silence(0.6)
			_sweep(b, 0.0, [[0.0, 1500.0], [0.03, 520.0]], 0.9, 0.02, 0.05, [1.0, 0.3])
			_air(b, rng, 0.0, 0.12, 0.8, 700.0, 1600.0, 800.0, 0.15, 0.8)
			for i in range(4):
				_air(b, rng, 0.05 + i * 0.045, 0.035, 0.35 * (1.0 - i * 0.2), 1000.0, 1800.0, 1200.0, 0.3, 1.2)
			_chime(b, 0.06, _hz(86), 0.35, 0.2)
			_chime(b, 0.12, _hz(93), 0.3, 0.25)
			return _finish(b, -16.0, 0.1)
		"dripkin_splat":
			# A Dripkin hits the floor: a wet plop, a squelch sagging down and a
			# couple of bubbles popping in the puddle.
			b = _silence(0.45)
			_thud(b, 0.0, 380.0, 170.0, 1.0, 0.04)
			_air(b, rng, 0.0, 0.12, 0.9, 400.0, 1100.0, 500.0, 0.15, 0.7)
			_sweep(b, 0.01, [[0.0, 720.0], [0.06, 340.0]], 0.45, 0.04, 0.08, [1.0, 0.3])
			_sweep(b, 0.16, [[0.0, 600.0], [0.03, 1100.0]], 0.2, 0.02, 0.05, [1.0])
			_sweep(b, 0.24, [[0.0, 700.0], [0.03, 1300.0]], 0.14, 0.02, 0.05, [1.0])
			return _finish(b, -16.0)
		"mimic_snore":
			# A Lidlurk asleep (the tell that a reliquary isn't one): a slow,
			# nasal "hnnnk" in and a whistling sigh out, faint.
			b = _silence(1.3)
			var snore := _silence(0.62)
			_roar(snore, rng, 0.0, [[0.0, 96.0], [0.5, 118.0]], 0.6, 0.6, 19.0)
			_layer(b, 0.0, snore, [[0.0, 0.0], [0.4, 1.0], [0.6, 0.0]])
			_air(b, rng, 0.0, 0.6, 0.25, 500.0, 1100.0, 900.0, 0.7, 0.9)
			var sigh := _silence(0.55)
			_sweep(sigh, 0.0, [[0.0, 1250.0], [0.5, 880.0]], 0.3, 20.0, 0.55, [1.0, 0.1], 0.006, 5.0)
			_layer(b, 0.7, sigh, [[0.0, 0.0], [0.12, 1.0], [0.55, 0.0]])
			_air(b, rng, 0.68, 0.55, 0.15, 900.0, 1400.0, 700.0, 0.2, 0.8)
			return _finish(b, -25.0, 0.2)
		"mimic_chomp":
			# A Lidlurk wakes and bites: the lid clacks up, snaps shut on its
			# teeth with a crunch, and a little box-dog snarl.
			b = _silence(0.62)
			_bar(b, 0.0, 440.0, 0.7, 0.03)
			_thud(b, 0.0, 330.0, 170.0, 0.6, 0.035)
			_bar(b, 0.1, 520.0, 1.0, 0.03)
			_thud(b, 0.1, 380.0, 160.0, 1.0, 0.05)
			_air(b, rng, 0.1, 0.06, 0.8, 1200.0, 2100.0, 900.0, 0.1, 0.8)
			_roar(b, rng, 0.14, [[0.0, 190.0], [0.12, 250.0], [0.4, 170.0]], 0.45, 0.42, 34.0)
			return _finish(b, -14.5)
		"boss_roar":
			# A big cartoon roar: a buzzy growl rising and sagging through "aw".
			b = _silence(1.5)
			_roar(b, rng, 0.0, [[0.0, 130.0], [0.25, 175.0], [0.9, 150.0], [1.35, 95.0]], 1.0, 1.35)
			_air(b, rng, 0.0, 1.3, 0.35, 400.0, 900.0, 300.0, 0.25, 0.7)
			return _finish(b, -13.0, 0.35)
		"boss_slam":
			# A heavy slam: a ground-shaking drum with its crunch in the mids, a
			# crack, rumble and falling debris.
			b = _silence(1.0)
			_thud(b, 0.0, 170.0, 55.0, 0.35, 0.14)
			_thud(b, 0.0, 420.0, 180.0, 1.0, 0.09)
			_partial(b, 0.0, 260.0, 0.5, 0.12)
			_partial(b, 0.0, 610.0, 0.3, 0.06)
			_air(b, rng, 0.0, 0.06, 1.0, 1500.0, 1800.0, 900.0, 0.1, 0.7)
			_air(b, rng, 0.0, 0.6, 0.7, 500.0, 900.0, 300.0, 0.1, 0.7)
			for i in range(10):
				var t := 0.08 + rng.randf() * 0.5
				_air(b, rng, t, rng.randf_range(0.015, 0.04), rng.randf_range(0.15, 0.4) * (1.0 - t),
						900.0, rng.randf_range(1200.0, 2800.0), 800.0, 0.3, 1.4)
			return _finish(b, -12.0, 0.25)
		"boss_hit":
			# The boss takes a hit: a heavy metal thwack and a grunt.
			b = _silence(0.4)
			_thud(b, 0.0, 300.0, 140.0, 1.0, 0.06)
			_air(b, rng, 0.0, 0.03, 0.8, 2000.0, 2800.0, 1500.0, 0.1, 0.9)
			_bronze(b, 0.0, 520.0, 0.5, 0.1)
			_sweep(b, 0.02, [[0.0, 240.0], [0.15, 170.0]], 0.4, 0.1, 0.25, [1.0, 0.7, 0.5, 0.35, 0.25])
			return _finish(b, -15.0)
		"boss_die":
			# The boss falls: a last wail sinking away, a run of bursts and
			# crumbles, a final boom and a low bell on D.
			b = _silence(2.6)
			_roar(b, rng, 0.0, [[0.0, 200.0], [0.15, 240.0], [1.2, 70.0]], 0.8, 1.2, 24.0)
			for i in range(10):
				var t := 0.3 + i * 0.1 + rng.randf() * 0.04
				_air(b, rng, t, 0.08, 0.5 * (1.0 - i * 0.06), 400.0, rng.randf_range(1200.0, 2400.0), 500.0, 0.2, 0.9)
				_thud(b, t, 260.0, 130.0, 0.3, 0.04)
			_thud(b, 1.3, 150.0, 50.0, 0.5, 0.3)
			_thud(b, 1.3, 380.0, 170.0, 0.9, 0.1)
			_partial(b, 1.3, 250.0, 0.4, 0.15)
			_great_bell(b, rng, 1.32, _hz(62), 0.45, 0.5)
			return _finish(b, -12.0, 0.5)

		# ---- boss 2: the Snuffer, the Hollow Wick
		"snuffer_whisper":
			# His "shhh" as he turns to a brazier: breath shaped like the sh of
			# a whisper (bands from 2.5 to 6 kHz and nothing low), swelling
			# unevenly the way a breath does (not the steady hiss of steam) and
			# sagging as it runs out, a hollow breath behind it.
			b = _silence(1.15)
			var lv := [[0.0, 0.0], [0.22, 0.75], [0.34, 0.6], [0.52, 0.95], [0.64, 1.0], [0.78, 0.78],
					[0.9, 0.84], [1.15, 0.0]]
			_band(b, rng, 0.0, 1.15, 1.0, lv, [[0.0, 2500.0], [0.6, 3000.0], [1.15, 2300.0]], 1.8)
			_band(b, rng, 0.0, 1.15, 0.8, lv, [[0.0, 3900.0], [0.6, 4400.0], [1.15, 3600.0]], 2.0)
			_band(b, rng, 0.0, 1.15, 0.45, lv, [[0.0, 5600.0], [0.6, 6200.0], [1.15, 5200.0]], 1.8)
			_air(b, rng, 0.0, 1.1, 0.04, 500.0, 900.0, 600.0, 0.4, 0.6)
			return _finish(b, -16.5, 0.2)
		"snuffer_slam":
			# His slam: the great brass cup brought down on the stone. A hollow
			# bronze clang and a floor-shaking thud, smoke puffing out from
			# under the rim.
			b = _silence(1.3)
			_thud(b, 0.0, 190.0, 55.0, 0.4, 0.15)
			_thud(b, 0.0, 420.0, 160.0, 1.0, 0.08)
			_bronze(b, 0.0, 310.0, 0.75, 0.32)
			_bronze(b, 0.0, 465.0, 0.35, 0.22)
			_air(b, rng, 0.0, 0.06, 1.0, 1500.0, 1800.0, 900.0, 0.1, 0.7)
			_air(b, rng, 0.03, 0.55, 0.55, 700.0, 1700.0, 500.0, 0.15, 0.7)
			for i in range(8):
				var t := 0.08 + rng.randf() * 0.5
				_air(b, rng, t, rng.randf_range(0.015, 0.04), rng.randf_range(0.15, 0.35) * (1.0 - t),
						900.0, rng.randf_range(1200.0, 2800.0), 800.0, 0.3, 1.4)
			return _finish(b, -12.0, 0.3)
		"snuffer_scream":
			# Lights Out: he screams and every brazier dies. Two hollow voices a
			# tritone apart wail up and collapse, a rush of breath through them.
			b = _silence(2.0)
			_roar(b, rng, 0.0, [[0.0, 260.0], [0.25, 440.0], [1.1, 400.0], [1.8, 190.0]], 0.85, 1.85, 16.0, AH)
			_roar(b, rng, 0.03, [[0.0, 368.0], [0.25, 622.0], [1.1, 566.0], [1.8, 269.0]], 0.45, 1.8, 23.0, OO)
			_band(b, rng, 0.0, 1.9, 0.5, [[0.0, 0.0], [0.2, 1.0], [1.2, 0.7], [1.9, 0.0]],
					[[0.0, 1800.0], [0.3, 3400.0], [1.9, 2000.0]], 0.8)
			return _finish(b, -12.0, 0.4)
		"curdle":
			# He curdles solid near the light: a bell swelled backwards (A5 and
			# the tritone above, his colour) into a hard tock, now he can be
			# hit, and a hiss of wax setting.
			b = _silence(0.62)
			var back := _silence(0.26)
			_bell(back, 0.0, _hz(81), 1.0, 0.1)
			_bell(back, 0.0, _hz(87), 0.5, 0.1)
			_layer(b, 0.0, _reversed(back))
			_band(b, rng, 0.0, 0.5, 0.5, [[0.0, 0.0], [0.2, 1.0], [0.5, 0.0]], [[0.0, 2500.0], [0.5, 4500.0]], 1.0)
			_thud(b, 0.25, 420.0, 200.0, 0.7, 0.035)
			_bar(b, 0.25, 760.0, 0.6, 0.03)
			_bronze(b, 0.25, 620.0, 0.3, 0.08)
			return _finish(b, -16.0, 0.1)
		"brazier_snuff":
			# He caps a brazier: the cup clunks down, the fire chokes ("ffft"), a
			# curl of smoke, and a low, sad D fading under it.
			b = _silence(1.0)
			_bronze(b, 0.0, 520.0, 0.6, 0.12)
			_thud(b, 0.0, 320.0, 160.0, 0.7, 0.04)
			_air(b, rng, 0.01, 0.28, 0.85, 1500.0, 900.0, 400.0, 0.1, 0.7)
			_hiss(b, rng, 0.0, 0.2, 0.3)
			_air(b, rng, 0.15, 0.7, 0.25, 600.0, 400.0, 250.0, 0.3, 0.6)
			_bell(b, 0.05, _hz(62), 0.25, 0.4)
			return _finish(b, -15.5, 0.3)
	push_error("Sfx.render: unknown sound '%s'" % sound)
	return PackedFloat32Array()


static func loudness_db(samples: PackedFloat32Array) -> float:
	## RMS of the loudest 50 ms, in dBFS: a rough stand-in for how loud a
	## short sound feels. render() levels every sound by it.
	var win := RATE / 20
	var sq := 0.0
	var top := 0.0
	for i in range(samples.size()):
		sq += samples[i] * samples[i]
		if i >= win:
			sq -= samples[i - win] * samples[i - win]
		top = maxf(top, sq)
	return linear_to_db(sqrt(top / win))


static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	## 16-bit mono PCM at RATE.
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, roundi(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


# ---------------------------------------------------------------- synthesis

static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func _silence(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


static func _partial(b: PackedFloat32Array, at: float, freq: float, amp: float, decay: float, attack: float = 0.003) -> void:
	## One decaying sine, eased in over `attack` seconds so it never clicks.
	## Anything near Nyquist is dropped rather than aliased.
	if freq >= RATE * 0.45 or freq <= 0.0:
		return
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(decay * 6.0 * RATE))
	if n <= 0:
		return
	var rise := mini(n, maxi(1, int(attack * RATE)))
	var w := TAU * freq / RATE
	var fall := exp(-1.0 / (decay * RATE))
	var env := amp
	for i in range(rise):
		b[start + i] += env * (0.5 - 0.5 * cos(PI * i / rise)) * sin(w * i)
		env *= fall
	# After the attack it is a pure damped sine, amp * fall^i * sin(w i),
	# which a two-term recurrence carries on exactly without calling sin():
	# this is the render's hottest loop, most of the boot's render time.
	var c1 := 2.0 * fall * cos(w)
	var c2 := fall * fall
	var y0 := env / fall * sin(w * (rise - 1))
	var y1 := env * sin(w * rise)
	for i in range(rise, n):
		b[start + i] += y1
		var y2 := c1 * y1 - c2 * y0
		y0 = y1
		y1 = y2


static func _bar(b: PackedFloat32Array, at: float, freq: float, amp: float, decay: float, bright: float = 1.0) -> void:
	## A struck wooden (or bone) bar: the fundamental plus the marimba's 4x
	## and 10x overtones, which die much faster. `bright` scales the overtones.
	_partial(b, at, freq, amp, decay)
	_partial(b, at, freq * 3.93, amp * 0.3 * bright, decay * 0.28)
	_partial(b, at, freq * 9.2, amp * 0.09 * bright, decay * 0.1, 0.001)


static func _bell(b: PackedFloat32Array, at: float, freq: float, amp: float, decay: float) -> void:
	## A small glassy bell: inharmonic upper partials that ring on a little.
	_partial(b, at, freq, amp, decay)
	_partial(b, at, freq * 2.76, amp * 0.35, decay * 0.6)
	_partial(b, at, freq * 5.4, amp * 0.12, decay * 0.3, 0.001)


static func _chime(b: PackedFloat32Array, at: float, freq: float, amp: float, decay: float) -> void:
	## A soft, warm chime: nearly a pure tone, a gentle attack, a faint octave.
	_partial(b, at, freq, amp, decay, 0.01)
	_partial(b, at, freq * 2.0, amp * 0.2, decay * 0.5, 0.01)
	_partial(b, at, freq * 3.0, amp * 0.06, decay * 0.3, 0.01)


static func _pluck(b: PackedFloat32Array, at: float, freq: float, amp: float, decay: float, bright: float = 1.0) -> void:
	## A harpsichord-ish pluck: a quill catches the string an eighth of the
	## way along, so the harmonics come strong and bright and the high ones
	## die first. `bright` scales everything above the fundamental.
	for k in range(1, 9):
		var a := amp * absf(sin(PI * k * 0.18)) / pow(k, 0.8) * (1.0 if k == 1 else bright)
		_partial(b, at, freq * k, a, decay / (1.0 + 0.45 * (k - 1)), 0.0015)


static func _bronze(b: PackedFloat32Array, at: float, freq: float, amp: float, decay: float) -> void:
	## Struck bronze or plate armor: dense inharmonic partials, the upper ones
	## dying fastest, each paired with a twin a hair sharp so it shimmers.
	var ratios := [1.0, 1.47, 2.09, 2.56, 2.76, 3.42, 4.1, 5.2]
	var amps := [1.0, 0.6, 0.7, 0.45, 0.4, 0.3, 0.2, 0.12]
	for i in range(ratios.size()):
		var f: float = freq * float(ratios[i])
		var a: float = amp * float(amps[i])
		var d := decay / (1.0 + 0.6 * i)
		_partial(b, at, f, a, d, 0.0008)
		_partial(b, at, f * 1.003, a * 0.5, d, 0.0008)


static func _clink(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, freq: float, amp: float) -> void:
	## A small metal object hitting stone.
	_partial(b, at, freq, amp, 0.03, 0.0008)
	_partial(b, at, freq * 1.41, amp * 0.6, 0.02, 0.0008)
	_partial(b, at, freq * 2.17, amp * 0.3, 0.012, 0.0008)
	_thud(b, at, 480.0, 300.0, amp * 0.3, 0.012)
	_hiss(b, rng, at, 0.005, amp * 0.2)


static func _great_bell(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, prime_hz: float, amp: float, ring: float = 1.0) -> void:
	## A church bell: the partials of a real one (the hum an octave below the
	## prime, the minor-third tierce that gives a bell its sad colour, the
	## quint, the nominal an octave up where the strike note is heard, and the
	## crowd above), each split into a pair a fraction of a hertz apart so it
	## beats the way a big bell warbles. `ring` scales how long it sings.
	var parts := [
		# ratio to the prime, amplitude, decay in seconds
		[0.5, 0.15, 2.8], [1.0, 0.3, 2.0], [1.183, 0.35, 1.6], [1.506, 0.2, 1.1],
		[2.0, 1.0, 1.3], [2.514, 0.5, 0.8], [2.662, 0.45, 0.7], [3.011, 0.5, 0.55],
		[4.166, 0.35, 0.35], [5.433, 0.25, 0.25], [6.796, 0.15, 0.18], [8.215, 0.08, 0.12],
	]
	for p in parts:
		var f: float = prime_hz * float(p[0])
		var a: float = amp * float(p[1]) * 0.5
		var d: float = float(p[2]) * ring
		var beat: float = 0.35 + 0.25 * float(p[0])
		_partial(b, at, f - beat * 0.5, a, d, 0.002)
		_partial(b, at, f + beat * 0.5, a, d, 0.002)
	# The clapper's strike: a clank of short, high partials over a burst of noise.
	for r in [9.7, 11.3, 13.6]:
		_partial(b, at, prime_hz * float(r), amp * 0.12, 0.05, 0.0008)
	_air(b, rng, at, 0.03, amp * 0.5, 1800.0, 3000.0, 1500.0, 0.1, 0.8)


static func _thud(b: PackedFloat32Array, at: float, from_hz: float, to_hz: float, amp: float, decay: float) -> void:
	## A soft drum: a sine whose pitch sags from from_hz to to_hz as it dies.
	## Phones drop the low end, so give it a from_hz in the mids.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(decay * 6.0 * RATE))
	if n <= 0:
		return
	var rise := maxi(1, int(0.004 * RATE))
	var fall := exp(-1.0 / (decay * RATE))
	var sag := exp(-1.0 / (0.05 * RATE))
	var over := from_hz - to_hz
	var env := amp
	var phase := 0.0
	for i in range(n):
		var s := env * sin(phase)
		if i < rise:
			s *= 0.5 - 0.5 * cos(PI * i / rise)
		b[start + i] += s
		phase += TAU * (to_hz + over) / RATE
		over *= sag
		env *= fall


static func _air(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, length: float, amp: float,
		from_hz: float, peak_hz: float, to_hz: float, peak_at: float, q: float) -> void:
	## Band-passed noise under a smooth swell. The band glides from from_hz to
	## peak_hz as the swell peaks, then on to to_hz (all capped at RATE / 6,
	## where the filter stays stable). Short ones are grit and crunch, long
	## ones are air moving.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(length * RATE))
	if n <= 0:
		return
	var top := maxi(1, int(n * peak_at))
	var damp := 1.0 / q
	var low := 0.0
	var band := 0.0
	for i in range(n):
		var env: float
		var hz: float
		if i < top:
			var x := float(i) / top
			env = 0.5 - 0.5 * cos(PI * x)
			hz = from_hz * pow(peak_hz / from_hz, x)
		else:
			var x := float(i - top) / maxi(1, n - top)
			env = 0.5 + 0.5 * cos(PI * x)
			hz = peak_hz * pow(to_hz / peak_hz, x)
		var f := 2.0 * sin(PI * minf(hz, RATE / 6.0) / RATE)
		low += f * band
		band += f * (rng.randf_range(-1.0, 1.0) - low - damp * band)
		b[start + i] += amp * env * band


static func _hiss(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, length: float, amp: float, crackle: float = 0.0) -> void:
	## Bright noise, the part _air cannot reach: white noise with its lows
	## differenced away, rising in 2 ms and fading out. `crackle` (0..1)
	## breaks it into random pops, the sound of a sizzle or a spitting flame.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(length * RATE))
	if n <= 0:
		return
	var rise := mini(n, maxi(1, int(0.002 * RATE)))
	var prev := 0.0
	var pop := 1.0
	var pop_fall := exp(-1.0 / (0.004 * RATE))
	for i in range(n):
		var w := rng.randf_range(-1.0, 1.0)
		var s := (w - prev) * 0.5
		prev = w
		var env := 0.5 + 0.5 * cos(PI * float(i) / n)
		if i < rise:
			env *= 0.5 - 0.5 * cos(PI * i / rise)
		if crackle > 0.0:
			if rng.randf() < 0.004 * crackle:
				pop = 1.0
			env *= (1.0 - crackle) + crackle * pop
			pop *= pop_fall
		b[start + i] += amp * env * s


static func _contour(points: Array, n: int) -> PackedFloat32Array:
	## A pitch per sample for a contour of [seconds, hz] points, gliding
	## exponentially from one to the next and holding the last.
	var hz := PackedFloat32Array()
	hz.resize(n)
	var last := points.size() - 1
	var j := 0
	for i in range(n):
		var t := float(i) / RATE
		while j < last and t >= float(points[j + 1][0]):
			j += 1
		var k := mini(j + 1, last)
		var t0: float = points[j][0]
		var t1: float = points[k][0]
		var h0: float = points[j][1]
		var h1: float = points[k][1]
		var x := clampf((t - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
		hz[i] = h0 * pow(h1 / h0, x)
	return hz


static func _sweep(b: PackedFloat32Array, at: float, points: Array, amp: float, decay: float, length: float,
		harmonics: Array = [1.0], wobble: float = 0.0, wobble_hz: float = 0.0) -> void:
	## A tone following a pitch contour (see _contour). `harmonics` are the
	## amplitudes of partials 1, 2, 3...; `wobble` (a ratio) wavers the pitch
	## at wobble_hz, for springs and squeaks. It rises in 3 ms, decays with
	## time constant `decay` and fades out over its last 20 ms.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(length * RATE))
	if n <= 0:
		return
	var hz := _contour(points, n)
	var h := PackedFloat32Array(harmonics)
	var rise := maxi(1, int(0.003 * RATE))
	var tail := maxi(1, mini(n, int(0.02 * RATE)))
	var fall := exp(-1.0 / (decay * RATE))
	var ww := TAU * wobble_hz / RATE
	var env := amp
	var phase := 0.0
	for i in range(n):
		var f := hz[i]
		if wobble > 0.0:
			f *= 1.0 + wobble * sin(ww * i)
		phase += TAU * f / RATE
		var s := 0.0
		for k in range(h.size()):
			if f * (k + 1) < RATE * 0.45:
				s += h[k] * sin(phase * (k + 1))
		var e := env
		if i < rise:
			e *= 0.5 - 0.5 * cos(PI * i / rise)
		if i > n - tail:
			e *= 0.5 - 0.5 * cos(PI * (n - i) / tail)
		b[start + i] += e * s
		env *= fall


static func _wavetable(amps: Array, freq: float = 0.0) -> PackedFloat32Array:
	## One cycle (TABLE samples, peak 1) of harmonics 1, 2, 3... at `amps`. Give
	## freq and any harmonic that would pass 0.42 * RATE is left out.
	var t := PackedFloat32Array()
	t.resize(TABLE)
	t.fill(0.0)
	for k in range(amps.size()):
		var h := k + 1
		if freq > 0.0 and freq * h >= RATE * 0.42:
			break
		var a: float = amps[k]
		if a == 0.0:
			continue
		var w := TAU * h / TABLE
		for i in range(TABLE):
			t[i] += a * sin(w * i)
	var peak := 0.0
	for v in t:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		for i in range(TABLE):
			t[i] /= peak
	return t


static func _table_voice(b: PackedFloat32Array, at: float, table: PackedFloat32Array, freq: float, amp: float,
		length: float, attack: float, release: float, vib_depth: float = 0.0, vib_hz: float = 5.0,
		vib_phase: float = 0.0) -> void:
	## A wavetable played at freq for `length` seconds, easing in over
	## `attack` and out over `release` (raised cosines, so no clicks). A
	## vibrato of vib_depth (a ratio) grows in over the first 0.3 s.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(length * RATE))
	if n <= 0:
		return
	var mask := TABLE - 1
	var inc := freq * TABLE / RATE
	var rise := maxi(1, int(attack * RATE))
	var fall := maxi(1, mini(n, int(release * RATE)))
	var hold := n - fall
	var vw := TAU * vib_hz / RATE
	var grow := 1.0 / (0.3 * RATE)
	var phase := 0.0
	for i in range(n):
		var e := amp
		if i < rise:
			e *= 0.5 - 0.5 * cos(PI * i / rise)
		if i >= hold:
			e *= 0.5 + 0.5 * cos(PI * (i - hold) / fall)
		var j := int(phase)
		var x := phase - j
		var s0 := table[j & mask]
		b[start + i] += e * (s0 + (table[(j + 1) & mask] - s0) * x)
		var step := inc
		if vib_depth > 0.0:
			step *= 1.0 + vib_depth * minf(1.0, i * grow) * sin(vw * i + vib_phase)
		phase += step
		if phase >= TABLE:
			phase -= TABLE


static func _organ(b: PackedFloat32Array, at: float, freq: float, amp: float, length: float,
		bright: float = 0.3, attack: float = 0.012, release: float = 0.08) -> void:
	## A pipe organ note: 8' and 4' principals with a 2 2/3' and 2' for shine;
	## `bright` (0..1) leans it toward a reed. A second rank a few cents sharp
	## beats gently against the first, like a celeste.
	var amps := [1.0, 0.6, 0.3 + 0.2 * bright, 0.3 + 0.1 * bright, 0.08 + 0.3 * bright, 0.1 + 0.2 * bright,
			0.02 + 0.2 * bright, 0.12 + 0.12 * bright, 0.15 * bright, 0.12 * bright, 0.1 * bright, 0.08 * bright]
	var table := _wavetable(amps, freq * 1.003)
	_table_voice(b, at, table, freq, amp * 0.6, length, attack, release)
	_table_voice(b, at, table, freq * 1.003, amp * 0.4, length, attack, release)


static func _formant(hz: float, formants: Array) -> float:
	## How loud a vowel lets a harmonic at hz through: the sum of its peaks.
	var g := 0.02
	for f in formants:
		var d: float = (hz - float(f[0])) / float(f[2])
		g += float(f[1]) / (1.0 + d * d)
	return g


static func _choir(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, freq: float, amp: float,
		length: float, attack: float = 0.25, release: float = 0.5, vowel: Array = AH) -> void:
	## A sung "ahh" (or another vowel) at freq: three voices a few cents
	## apart, each with its own slow vibrato, over harmonics shaped by the
	## vowel's formants.
	var amps := []
	var k := 1
	while k <= 30 and freq * k < 4200.0:
		amps.append((0.25 + 2.0 * _formant(freq * k, vowel)) / k)
		k += 1
	var table := _wavetable(amps)
	var detune := [1.0, 1.0046, 0.9955]
	var rate := [5.1, 5.6, 4.7]
	for v in range(3):
		_table_voice(b, at + 0.01 * v, table, freq * float(detune[v]), amp / 3.0, length - 0.01 * v,
				attack, release, 0.006, float(rate[v]), rng.randf() * TAU)


static func _roar(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, points: Array, amp: float,
		length: float, growl_hz: float = 31.0, vowel: Array = AW) -> void:
	## A big cartoon voice: a buzzy tone following the pitch contour, its
	## harmonics shaped by a vowel ("aw" unless told otherwise, so its weight
	## sits in the mids, where a phone can carry it) and roughened by a fast,
	## wandering flutter.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(length * RATE))
	if n <= 0:
		return
	var hz := _contour(points, n)
	var high := 0.0
	var mid := 0.0
	for p in points:
		high = maxf(high, float(p[1]))
		mid += float(p[1]) / points.size()
	var amps := []
	var k := 1
	while k <= 40 and high * k < 4000.0:
		amps.append((0.3 + 2.0 * _formant(mid * k, vowel)) / pow(k, 0.4))
		k += 1
	var table := _wavetable(amps)
	var mask := TABLE - 1
	var rise := maxi(1, int(0.06 * RATE))
	var fall := maxi(1, int(n * 0.35))
	var hold := n - fall
	var phase := 0.0
	var flutter := 0.0
	var rate := TAU * growl_hz / RATE
	for i in range(n):
		var e := amp
		if i < rise:
			e *= 0.5 - 0.5 * cos(PI * i / rise)
		if i >= hold:
			e *= 0.5 + 0.5 * cos(PI * (i - hold) / fall)
		e *= 0.7 + 0.3 * sin(flutter)
		flutter += rate * rng.randf_range(0.6, 1.4)
		var j := int(phase)
		var x := phase - j
		var s0 := table[j & mask]
		b[start + i] += e * (s0 + (table[(j + 1) & mask] - s0) * x)
		phase += hz[i] * TABLE / RATE
		if phase >= TABLE:
			phase -= TABLE


static func _envelope(points: Array, n: int) -> PackedFloat32Array:
	## A level per sample for [seconds, level] points: straight lines between
	## them, holding the first level before it and the last after.
	var e := PackedFloat32Array()
	e.resize(n)
	var last := points.size() - 1
	var j := 0
	for i in range(n):
		var t := float(i) / RATE
		while j < last and t >= float(points[j + 1][0]):
			j += 1
		if j >= last or t <= float(points[j][0]):
			e[i] = float(points[j][1])
		else:
			var t0: float = points[j][0]
			var t1: float = points[j + 1][0]
			var x := (t - t0) / maxf(t1 - t0, 0.0001)
			e[i] = lerpf(float(points[j][1]), float(points[j + 1][1]), x)
	return e


static func _layer(b: PackedFloat32Array, at: float, layer: PackedFloat32Array, env: Array = []) -> void:
	## Add a part made on its own buffer into b at `at`, shaped by an
	## envelope of [seconds, level] points (see _envelope), or as it is. For
	## parts that swell, which the one-shot voices above can't do.
	var start := int(at * RATE)
	var n := mini(b.size() - start, layer.size())
	if n <= 0:
		return
	if env.is_empty():
		for i in range(n):
			b[start + i] += layer[i]
		return
	var e := _envelope(env, n)
	for i in range(n):
		b[start + i] += e[i] * layer[i]


static func _reversed(layer: PackedFloat32Array) -> PackedFloat32Array:
	## A part played backwards: a bell or a hit becomes a swell that ends
	## where it struck. Its old tail is its new start, so render it with room
	## for the tail to die first.
	var r := layer.duplicate()
	r.reverse()
	return r


static func _band(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, length: float, amp: float,
		levels: Array, hz: Array, q: float) -> void:
	## Noise through a band-pass whose level and centre follow [seconds,
	## value] contours (straight lines for the level, see _envelope; glides
	## for the pitch, see _contour). The filter is a zero-delay state-variable
	## one, stable right up to Nyquist, so unlike _air it reaches the "sh" of a
	## whisper and the fizz of steam at 4-8 kHz. Gain at the centre is q.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(length * RATE))
	if n <= 0:
		return
	var env := _envelope(levels, n)
	var f := _contour(hz, n)
	var k := 1.0 / q
	var ic1 := 0.0
	var ic2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var a3 := 0.0
	for i in range(n):
		if i % 8 == 0:
			var g := tan(PI * minf(f[i], RATE * 0.45) / RATE)
			a1 = 1.0 / (1.0 + g * (g + k))
			a2 = g * a1
			a3 = g * a2
		var v3 := rng.randf_range(-1.0, 1.0) - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		b[start + i] += amp * env[i] * v1


static func _thump(b: PackedFloat32Array, at: float, from_hz: float, to_hz: float, amp: float, decay: float,
		drive: float = 2.5) -> void:
	## _thud driven into soft saturation: the same sagging drum, with odd
	## harmonics of its own, so a heartbeat still thumps on a phone speaker
	## that drops everything under 200 Hz.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(decay * 6.0 * RATE))
	if n <= 0:
		return
	var rise := maxi(1, int(0.004 * RATE))
	var fall := exp(-1.0 / (decay * RATE))
	var sag := exp(-1.0 / (0.05 * RATE))
	var over := from_hz - to_hz
	var norm := 1.0 / tanh(drive)
	var env := amp
	var phase := 0.0
	for i in range(n):
		var s := env * tanh(drive * sin(phase)) * norm
		if i < rise:
			s *= 0.5 - 0.5 * cos(PI * i / rise)
		b[start + i] += s
		phase += TAU * (to_hz + over) / RATE
		over *= sag
		env *= fall


static func _finish(b: PackedFloat32Array, loud_db: float, fade: float = 0.015) -> PackedFloat32Array:
	## Block DC, ease the first 2 ms and the last `fade` seconds to silence,
	## then level the sound to loud_db, never letting a peak past -2 dBFS.
	var x1 := 0.0
	var y1 := 0.0
	for i in range(b.size()):
		var x := b[i]
		y1 = x - x1 + 0.995 * y1
		x1 = x
		b[i] = y1
	var head := mini(b.size(), int(0.002 * RATE))
	for i in range(head):
		b[i] *= 0.5 - 0.5 * cos(PI * i / head)
	var tail := mini(b.size(), int(fade * RATE))
	for i in range(tail):
		b[b.size() - 1 - i] *= 0.5 - 0.5 * cos(PI * i / tail)
	var peak := 0.0
	for v in b:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		var k := minf(db_to_linear(loud_db - loudness_db(b)), PEAK_CEILING / peak)
		for i in range(b.size()):
			b[i] *= k
	return b


# ---------------------------------------------------------------- v3 primitives
# For the v3 banks (scripts/sfx_<bank>.gd). Nothing above calls them, so v2's
# sounds render exactly as they did. They live here, not in a bank file,
# because every bank's cache key hashes this script: a change to one of them
# re-renders every bank that could use it.

static func _at(points: Array, t: float) -> float:
	## The value of [seconds, value] points at t: straight lines between them,
	## holding the first value before it and the last after.
	if points.is_empty():
		return 0.0
	if t <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var t1: float = points[i][0]
		if t <= t1:
			var t0: float = points[i - 1][0]
			return lerpf(float(points[i - 1][1]), float(points[i][1]), (t - t0) / maxf(t1 - t0, 0.0001))
	return float(points[-1][1])


static func _glass(b: PackedFloat32Array, at: float, freq: float, amp: float, decay: float, attack: float = 0.002) -> void:
	## A glass rim struck (a wine glass, a pane, a prism): a pure fundamental
	## with a twin a hair sharp that makes it shimmer, and the thin,
	## inharmonic partials of glass (x2.32, x4.25, x6.63) dying fast. Softer
	## in its attack and purer than a bell.
	_partial(b, at, freq, amp, decay, attack)
	_partial(b, at, freq + 1.1 + freq * 0.0008, amp * 0.3, decay * 0.9, attack)
	_partial(b, at, freq * 2.32, amp * 0.3, decay * 0.45, attack * 0.7)
	_partial(b, at, freq * 4.25, amp * 0.11, decay * 0.22, maxf(0.0008, attack * 0.5))
	_partial(b, at, freq * 6.63, amp * 0.05, decay * 0.12, maxf(0.0008, attack * 0.5))


static func _tine(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, freq: float, amp: float, decay: float) -> void:
	## A music-box tine (or a celesta bar): a clear fundamental, a faint
	## octave, the comb's bright partial far above (x5.93) dying fast, and the
	## pin's tiny tick.
	_partial(b, at, freq, amp, decay, 0.001)
	_partial(b, at, freq * 2.0, amp * 0.08, decay * 0.4, 0.001)
	_partial(b, at, freq * 5.93, amp * 0.16, decay * 0.1, 0.0008)
	_hiss(b, rng, at, 0.003, amp * 0.1)


static func _ratchet(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, length: float, from_gap: float,
		to_gap: float, freq: float, amp: float, grow: float = 0.0) -> int:
	## A pawl clicking over a toothed wheel for `length` seconds, the gap
	## between clicks gliding from from_gap to to_gap (winding up: long to
	## short; running down: short to long), each click a tiny metal tick near
	## freq with a grain of grit. grow (0..1) swells them as they go. Returns
	## how many clicks it made.
	var t := 0.0
	var n := 0
	while t < length:
		var x := t / length
		var a := amp * (1.0 - grow + grow * x) * rng.randf_range(0.8, 1.0)
		var f := freq * rng.randf_range(0.94, 1.06)
		_partial(b, at + t, f, a, 0.006, 0.0008)
		_partial(b, at + t, f * 1.73, a * 0.45, 0.004, 0.0008)
		_hiss(b, rng, at + t, 0.004, a * 0.45)
		t += lerpf(from_gap, to_gap, x) * rng.randf_range(0.9, 1.1)
		n += 1
	return n


static func _creak(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, length: float, rate: Array,
		body_hz: float, amp: float, env: Array = []) -> void:
	## Wood (a vine, a bough, a hinge, ice) under strain: stick-slip, a train
	## of tiny slips whose rate follows `rate` ([seconds, slips a second]),
	## each ringing the body at body_hz with its 2.1x and 3.4x modes, a little
	## irregular in time, pitch and force; the level follows env ([seconds,
	## level] points), full throughout without one.
	var t := 0.0
	while t < length:
		var lv := 1.0 if env.is_empty() else _at(env, t)
		if lv > 0.0:
			var a := amp * lv * rng.randf_range(0.55, 1.0)
			var f := body_hz * rng.randf_range(0.96, 1.04)
			_partial(b, at + t, f, a, 0.009, 0.0015)
			_partial(b, at + t, f * 2.1, a * 0.55, 0.006, 0.0012)
			_partial(b, at + t, f * 3.4, a * 0.3, 0.004, 0.001)
		t += 1.0 / maxf(1.0, _at(rate, t)) * rng.randf_range(0.7, 1.3)


static func _rustle(b: PackedFloat32Array, rng: RandomNumberGenerator, at: float, length: float, amp: float,
		grains: int, lo_hz: float, hi_hz: float, env: Array = []) -> void:
	## Leaves, straw, soil or cloth: `grains` short bursts of band-passed
	## noise scattered over `length` seconds, each 8-30 ms long at its own
	## centre between lo_hz and hi_hz (any height: the filter is _band's),
	## their level shaped by env ([seconds, level]).
	for i in range(grains):
		var t := rng.randf() * length
		var g := rng.randf_range(0.008, 0.03)
		var f := rng.randf_range(lo_hz, hi_hz)
		var lv := (1.0 if env.is_empty() else _at(env, t)) * rng.randf_range(0.4, 1.0)
		if lv > 0.0:
			_band(b, rng, at + t, g, amp * lv, [[0.0, 0.0], [g * 0.3, 1.0], [g, 0.0]], [[0.0, f]], 1.6)


static func _harmonica(b: PackedFloat32Array, at: float, freq: float, amp: float, length: float, attack: float = 0.15,
		release: float = 0.3, beat: float = 1.5) -> void:
	## A glass harmonica (a wet finger on a turning glass): nearly a pure
	## tone with a whisper of its octave and twelfth, swelling in and out,
	## with a twin `beat` Hz sharp so it slowly shimmers.
	var table := _wavetable([1.0, 0.1, 0.05], freq)
	_table_voice(b, at, table, freq, amp * 0.65, length, attack, release)
	_table_voice(b, at, table, freq + beat, amp * 0.35, length, attack, release)


static func _shape(b: PackedFloat32Array, points: Array, at: float = 0.0) -> void:
	## Multiply b, from `at` on, by a level contour of [seconds, level] points
	## (see _envelope): a bell a hand closes on, a sound cut off by silence.
	var start := int(at * RATE)
	var n := b.size() - start
	if n <= 0:
		return
	var e := _envelope(points, n)
	for i in range(n):
		b[start + i] *= e[i]


static func _muffle(b: PackedFloat32Array, hz: float, at: float = 0.0) -> void:
	## A two-pole low-pass over b from `at` on: a bell under water, a thump
	## through a wall.
	var start := clampi(int(at * RATE), 0, b.size())
	var a := 1.0 - exp(-TAU * hz / RATE)
	# Start from where the sound is, so a muffle begun partway never jumps.
	var y1 := b[start - 1] if start > 0 else 0.0
	var y2 := y1
	for i in range(start, b.size()):
		y1 += a * (b[i] - y1)
		y2 += a * (y1 - y2)
		b[i] = y2


static func _tremolo(b: PackedFloat32Array, at: float, length: float, rate: float, depth: float, phase: float = 0.0) -> void:
	## A slow swell and sag in the level (water lapping at a bell, a
	## shivering note): depth 0..1 at `rate` Hz, for `length` seconds from at.
	var start := int(at * RATE)
	var n := mini(b.size() - start, int(length * RATE))
	var w := TAU * rate / RATE
	for i in range(maxi(n, 0)):
		b[start + i] *= 1.0 - depth * (0.5 - 0.5 * cos(w * i + phase))


static func _space(b: PackedFloat32Array, wet: float, room: float = 1.0, tail: float = 0.84) -> void:
	## A stone room's tail (four feedback combs into two all-passes), mixed
	## in at `wet`: a cathedral over a whoosh, a drowned hall under a bell.
	## room scales the delays (1.0: 25-31 ms), tail the feedback (how long it
	## rings). Leave silence at the end of b for it to die into.
	var n := b.size()
	var dry := b.duplicate()
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	for d in [558, 594, 638, 678]:
		var k := maxi(8, int(d * room))
		var buf := PackedFloat32Array()
		buf.resize(k)
		buf.fill(0.0)
		var j := 0
		var lp := 0.0
		for i in range(n):
			var y := buf[j]
			lp = y * 0.7 + lp * 0.3
			buf[j] = dry[i] + lp * tail
			out[i] += y * 0.25
			j = (j + 1) % k
	for d in [112, 278]:
		var k := maxi(4, int(d * room))
		var buf := PackedFloat32Array()
		buf.resize(k)
		buf.fill(0.0)
		var j := 0
		for i in range(n):
			var y := buf[j]
			var x := out[i]
			buf[j] = x + y * 0.5
			out[i] = y * 0.75 - x * 0.5
			j = (j + 1) % k
	for i in range(n):
		b[i] = dry[i] + wet * out[i]
