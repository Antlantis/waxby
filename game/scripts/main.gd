extends Node
## The root: switches between the title, the saves, the story's scenes, the
## map and the screens it opens (Callings, Sheet, Chandler), a level and its
## results.
##
## The way through: a title tap opens the saves (three slots). A filled one
## plays on where it was (the map); an empty one, or one started over, is a
## new game: the intro and the oath (where the calling is chosen), then the
## map (its Title button leads back to the title, and so to the saves).
## A level's end records the result;
## a first clear plays the level's closing scene (story_end) before the
## results. Onward goes to the next level. The first time into a new world
## (by Onward or from the map) its opening scene plays first, and after the
## last boss the ending (with the Nightfall tease after the credits) comes
## before the map. Scenes play once (Game.seen); the bot in --autoplay never
## sees one. main also fires the first-hurt bark (Taper: the flame is your
## life), which the level itself doesn't, and the first level on Nightfall's
## bark (the Hush is angry now).
##
## It loads ahead on threads, so nothing stalls the frame it opens in: the
## levels' monsters and props at the title (kept), and each story scene's
## first picture before it plays (the intro at the title; a level's opening
## and boss beats as it builds, its closing scene during the clear; the
## ending and a new world's opening scene while the results are up).
##
## v3 (contract.md §9.4): play_level_id(id) plays any level by id (the main
## path, a secret level, the feel labs); play_custom(data, mode) plays a
## mode's level (its finish goes to mode.finished, never Game.record_result);
## show_modes(screen) opens the Challenges hub; a finale whose scene says
## "resume": true runs the player's choice after it; the map shows one
## one-time card a visit (v3_update, new points, the Gauntlet, Nightfall);
## the map carries a "Feel lab" button (lab-1) until the lab is signed off.
## --autoplay=<level id> | lab-1 | descent:<d> | rush:<boss id> |
## trial:<trial id> | scene:<scene id> | screens, and --soak=<seconds>.

const LevelData := preload("res://scripts/level_data.gd")
const WorldScript := preload("res://scripts/world.gd")
const TitleScript := preload("res://scripts/title_screen.gd")
const SavesScript := preload("res://scripts/saves_screen.gd")
const MapScript := preload("res://scripts/map_screen.gd")
const ResultsScript := preload("res://scripts/results_screen.gd")
const CutsceneScript := preload("res://scripts/cutscene.gd")
const Story := preload("res://scripts/story.gd")
const UI := preload("res://scripts/ui.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
# Screens other workstreams build; each is used only once it exists.
const KEEPER_SCREEN := "res://scripts/keeper_screen.gd"
const HERO_SCREEN := "res://scripts/hero_screen.gd"
const CHANDLER_SCREEN := "res://scripts/chandler_screen.gd"
const BACK_SIGNALS := ["back", "closed", "close", "done"]
const MODES_SCREEN := "res://scripts/modes/modes_screen.gd"
const TALES_SCREEN := "res://scripts/tales_screen.gd"   # ST's Tales (P1), from the title and the saves screen
const MODE_SCRIPTS := {"descent": "res://scripts/modes/descent.gd", "rush": "res://scripts/modes/waxworks.gd",
		"trial": "res://scripts/modes/trials.gd"}
const FEEL_LAB := "lab-1"
const FEEL_LAB_BUTTON := true    # the map's Feel lab button (lab-1), until the owner signs the lab off
# Debug builds: --autoplay=spike:<name>. The audio spikes (A7, Sfx.start_spike)
# and the GPU spike (W0-render, scripts/perf_spike.gd) share the prefix.
const AUDIO_SPIKES := ["boot", "stems"]                  # stems[:minutes[:pcm]]
const GPU_SPIKES := ["all", "lights48", "lights48b", "scene33", "scene33b"]
const PERF_SPIKE := "res://scripts/perf_spike.gd"
const PERF_METER := "res://scripts/perf_meter.gd"
const Classes := preload("res://scripts/classes.gd")
# v2's monsters' frames and every prop: asked for on a thread while the
# title is up, and kept (see _warm_level_art), with the monsters' scripts.
# The art a v3 world adds is in WORLD_ART, warmed only while it's played.
const LEVEL_ART := ["res://art/enemies", "res://art/props"]
# The art/enemies frames each v3 world adds, in sets: a world's monsters
# ("w3": their FRAMES, and its Omens' marks) and each boss's frames and
# props (A4's points_<boss>.json frames, _props and _parts). A set is asked
# for on a thread when a level (or a mode's room) that holds its kinds is
# about to build, or when the map or the results look ahead to one, and let
# go when play moves where it isn't wanted; the title warms none of them, so
# a W1-W2 level holds v2's art alone (as v3-p0) and never the 110 MB of
# W3-W6 frames. tests/test_story.gd checks every file is in one place.
const WORLD_ART := {
	"w3": [
		"creep_coil", "creep_crawl1", "creep_crawl2", "creep_fall", "creep_hit", "creep_lunge", "hound_crouch",
		"hound_hit", "hound_howl", "hound_land", "hound_pant", "hound_pounce", "hound_prowl1", "hound_prowl2",
		"hound_run1", "hound_run2", "omen_spore_mote", "rootling_dazed", "rootling_hit", "rootling_mound", "rootling_pop",
		"rootling_swell", "rootling_walk1", "rootling_walk2", "weepcap_die", "weepcap_hit", "weepcap_idle",
		"weepcap_inhale", "weepcap_puff"],
	"rootmother": [
		"bloom_bud", "bloom_decoy", "bloom_open", "root_hump", "root_spear", "rootmother_bare", "rootmother_bough1",
		"rootmother_bough2", "rootmother_bough3", "rootmother_breath", "rootmother_die", "rootmother_dig",
		"rootmother_hollow", "rootmother_hurt", "rootmother_idle", "rootmother_legs", "rootmother_sweep_high",
		"rootmother_sweep_low", "rootmother_wilt", "skull_seed", "thorn"],
	"w4": [
		"buckle_hit", "buckle_idle", "buckle_raise", "buckle_shell", "buckle_slam", "buckle_stomp", "buckle_thawed",
		"buckle_walk1", "buckle_walk2", "omen_echo_dial", "owl_body", "owl_broken", "owl_hit", "owl_look_c", "owl_look_l",
		"owl_look_r", "owl_screech", "spur_catch", "spur_face", "spur_face_catch", "spur_face_hit", "spur_hit",
		"spur_roll", "tick_charge", "tick_dizzy", "tick_hit", "tick_march1", "tick_march2", "tick_wind"],
	"tinker": [
		"clock_face", "gear_saw", "hour_bell_frozen", "hour_bell_lit", "hour_hand", "soldier_hatch", "tinker_chimed",
		"tinker_die", "tinker_idle", "tinker_overwind", "tinker_rewind", "tinker_swing", "tinker_toss", "tinker_walk1",
		"tinker_walk2", "tinker_watch"],
	"w5": [
		"gust_blow", "gust_hit", "gust_idle1", "gust_idle2", "gust_inhale", "mite_gnaw", "mite_hit", "mite_walk1",
		"mite_walk2", "omen_glassed", "pane_cut", "pane_edge", "pane_face1", "pane_face2", "pane_hit", "pane_shatter",
		"pane_turn", "refractor_charge", "refractor_fire", "refractor_hit", "refractor_idle1", "refractor_idle2"],
	"saint": [
		"halo_shard", "mirror_shard", "mirror_shard_dim", "saint_beam", "saint_charge", "saint_die", "saint_halo",
		"saint_hurt", "saint_idle", "saint_refracted", "saint_rose", "saint_shard_blue", "saint_shard_gold",
		"saint_shard_red", "saint_sing", "saint_split"],
	"w6": [
		"coil_head_closed", "coil_head_closed_bare", "coil_head_open", "coil_head_open_bare", "coil_head_rest",
		"coil_head_rest_bare", "coil_hit", "coil_hit_bare", "coil_seg", "coil_tail", "hushling_blink", "hushling_crouch",
		"hushling_idle1", "hushling_idle2", "hushling_lunge", "hushling_pop", "maw_choke", "maw_hit", "maw_idle",
		"maw_open", "maw_strain", "omen_hush_mote"],
	# v2's bosses' frames: only their levels, and the modes' arenas and
	# boss depths, hold them (27 + 6.7 MB nothing in W3-W6 draws; the int2
	# review). art_sets_of reads 1-4's and 2-4's X as their header's boss.
	"tollgrave": ["boss_hurt", "boss_idle", "boss_slam", "boss_stuck", "boss_windup"],
	"snuffer": [
		"snuffer_curdled", "snuffer_die", "snuffer_glide", "snuffer_idle", "snuffer_lunge", "snuffer_raise",
		"snuffer_slam", "snuffer_snuff", "snuffer_stuck"],
	"hush": [
		"hush_core", "hush_eye_half", "hush_eye_open", "hush_eye_shut", "hush_eye_small", "hush_eye_wince",
		"hush_hand_grasp", "hush_hand_rise", "hush_hand_sink", "hush_hand_splay", "hush_pupil", "ring_ledge",
		"stolen_flame", "sunken_bell", "sunken_bell_smothered"],
}
# The props a v3 world's themes and features draw (A1's, art/props), warmed
# with that world's set: the title's LEVEL_ART leaves them (and the ones
# nothing draws yet, PROPS_UNDRAWN) out, so a W1-W2 level holds v2's props
# alone (9.6 MB less with mipmaps).
const WORLD_PROPS := {
	"w3": ["spore_pod_closed", "spore_pod_swell", "spore_pod_burst", "spore_pod_hang_closed", "spore_pod_hang_swell",
		"spore_pod_hang_burst", "glowfruit_hang", "glowfruit_lit", "glowfruit_dim", "skull_lantern_lit", "skull_lantern_out",
		"altar_orchard", "altar_orchard_lit", "bell_orchard", "bell_orchard_beam", "sconce_bone"],
	"w4": ["gear_l", "gear_l_shine", "cog_tooth", "swing_ledge", "swing_ledge_2", "swing_ledge_3", "belt_teeth",
		"pendulum_bob", "pendulum_pivot", "icicle_hang", "icicle_crack", "icicle_fall", "brass_lamp_lit", "brass_lamp_out",
		"altar_frost", "altar_frost_lit", "bell_frost", "bell_frost_beam", "sconce_brass"],
	# A2's (the track B merge; A2's request: out of the title's warm, ~9 MB).
	"w5": ["pennant_slack", "pennant_lift", "pennant_full", "prism_lamp_lit", "prism_lamp_out", "window_seal_open",
		"window_seal_closed", "altar_glass", "altar_glass_lit", "bell_glass", "bell_glass_beam", "sconce_glass"],
	"w6": ["bell_buoy", "bell_buoy_rung", "vigil_candle_out", "vigil_candle_lit", "grasp_hand", "buoy_lantern_lit",
		"buoy_lantern_out", "altar_hush", "altar_hush_lit", "bell_hush", "bell_hush_beam", "sconce_dead", "eye_seal_open",
		"eye_seal_closed"],
}
# spec §11.3's frames that nothing draws yet (the painters draw the vine's
# knot and the sealed doors; cogs use gear_l): loaded by no one (A1's P2).
const PROPS_UNDRAWN := ["vine_top", "root_seal_open", "root_seal_closed", "clock_door_open", "clock_door_closed",
		"gear_s", "gear_m", "gear_s_shine", "gear_m_shine",
		# A2's pane cracks (tiles/glass.gd draws them in code: draw_pane_overlay).
		"glass_crack1", "glass_crack2", "glass_crack3"]
# The set a kind's art is in (a v2 kind's is the title's).
const KIND_ART := {"rootling": "w3", "weepcap": "w3", "rattlehound": "w3", "creepbone": "w3", "rootmother": "rootmother",
		"tickwind": "w4", "spurwheel": "w4", "frostbuckle": "w4", "hoarowl": "w4", "tinker": "tinker",
		"glassmite": "w5", "gustling": "w5", "refractor": "w5", "paneguard": "w5", "saint": "saint",
		"hushling": "w6", "stillmaw": "w6", "unwick": "w6", "lurecoil": "w6", "hush": "hush",
		"tollgrave": "tollgrave", "snuffer": "snuffer"}

var current: Node = null
var last_level := 0
var _off_path := ""              # the level playing off the main path (a secret level, a lab), or ""
var _mode: Object = null         # the mode playing (play_custom), or null
var _lab_btn: Button = null      # the map's Feel lab button
var _map_focus := -1
var _art_cache := {}             # world_art(key) -> its files (a set's never changes)
var _ends := {}                 # level id -> its story_end scene (read once)
var _warm := {}                 # path -> Resource: the levels' art and monster scripts, loaded ahead and kept
var _warming: Array = []        # ...asked for on a thread, not loaded yet
var _warm_sets: Array = []      # the WORLD_ART sets wanted now (their files stay in _warm)
var _set_of := {}               # path -> the WORLD_ART sets holding it (built once)
var _sets_on := true            # levels ask for their sets ahead (the bot only with --warm)
# --story (debug, with --autoplay): the bot's level plays its story as a
# player's does: the scenes asked for ahead, the beats over the level played
# (their lines go by themselves; unmarked in the bot's save as the run
# starts), so a perf run measures boss_3_before over the live 3-4
# (tools/perf/run_phone.sh --story).
var _story_on := false
var _hero_warm := ""            # the calling whose rig art is warm
var _end_world: Node = null     # the level whose closing scene is asked for ahead once it's cleared
var _end_scene := ""
var story_ahead: Array = []     # the scenes last asked for ahead (the tests read it)
# Headless there's nothing to draw, and the stand-in renderer can't make
# textures on two threads at once: nothing is loaded ahead.
var _threads := DisplayServer.get_name() != "headless"


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0e0a14"))
	UI.warm()
	# Debug builds only: `-- --autoplay=1-1` runs a level with a bot and logs
	# the frame rate (for checking a build on the phone).
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if OS.is_debug_build() and a.begins_with("--autoplay="):
			_autoplay = a.get_slice("=", 1)
		elif OS.is_debug_build() and a.begins_with("--soak="):
			soak = float(a.get_slice("=", 1))
		elif OS.is_debug_build() and a == "--story":
			_story_on = true
	if _autoplay.begins_with("spike:"):
		_spike(_autoplay.trim_prefix("spike:"))
		return
	if _autoplay != "":
		_autoplay_save()
		_sets_on = false   # the bot plays cold, as v3-p0's did, unless --warm
		if _warm_flag():
			_warm_level_art(true)
		# The meter's clock starts here, so the level's build counts in the
		# first frame it measures.
		perf_start()
		autoplay_route(_autoplay)
		if _story_on:
			# A player always has the title's shader warm under a scene (the
			# rev5 review: --story runs compiled them as boss_5_before began).
			_warm_cutscene_field()
		return
	_warm_level_art()
	show_title()
	_warm_cutscene_field()


func _warm_cutscene_field() -> void:
	## The cutscenes' Plan B shaders (darkness_field in its SubViewport,
	## darkness_lit_b on the screen) compiled behind the title, as W0-render
	## asked: a material compiles on first use (~23 ms on the Mac), which
	## would otherwise land on the first scene's first frame. One frame of an
	## 8 x 8 field and a 1 px lit rect under the title, then gone.
	if not _threads or CutsceneScript.field_plan() == "full" or not ResourceLoader.exists("res://scripts/light_field.gd"):
		return
	var f = load("res://scripts/light_field.gd").new()
	f.scale = 0.001
	var under := CanvasLayer.new()
	under.layer = -20
	under.add_child(f)
	var r := ColorRect.new()
	r.size = Vector2(1, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = f.make_bands_material(true)
	under.add_child(r)
	add_child(under)
	for i in 3:
		await get_tree().process_frame
	if is_instance_valid(under):
		under.queue_free()


func _warm_flag() -> bool:
	## --warm (debug): the bot's run warms as a player's would (the title's
	## art, then the level's sets), so tools/perf/run_phone.sh measures the
	## texture memory a player has.
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a == "--warm":
			return true
	return false


func _spike(what: String) -> void:
	## A debug spike. The audio ones (boot, stems[:min[:pcm]]) go to Sfx with
	## the title up (boot measures the title's sounds); the GPU ones run
	## scripts/perf_spike.gd, which has its own meter (main's stays off).
	## Each logs "[spike]" lines and quits the app when it's done.
	_autoplay = ""
	if AUDIO_SPIKES.has(what.get_slice(":", 0)):
		_autoplay_save()
		if what == "boot":
			show_title()
		if Sfx.has_method("start_spike"):
			Sfx.start_spike(what, self)
		return
	if not GPU_SPIKES.has(what):
		print("[spike] unknown spike '%s': audio %s, GPU %s" % [what, AUDIO_SPIKES, GPU_SPIKES])
		what = "all"
	_autoplay_save()
	var sp: Node = load(PERF_SPIKE).new()
	sp.set("name_arg", what)
	add_child(sp)
	sp.call("run", what)


func _exit_tree() -> void:
	_claim_warm(true)
	_warm.clear()
	if _threads:
		CutsceneScript.prefetch([])


# ---------------------------------------------------------------- loading ahead

func level_art() -> Array:
	## What W1-W2's levels are made of, warmed at the title and kept: v2's
	## monsters' frames (every art/enemies file in no WORLD_ART set), every
	## prop but a v3 world's (WORLD_PROPS) and the undrawn ones, and the
	## monsters' own scripts (a v3 world's with its set).
	var out := []
	var v3 := {}
	for key in WORLD_ART:
		for nm in WORLD_ART[key]:
			v3["res://art/enemies/%s.svg" % nm] = true
	for key in WORLD_PROPS:
		for nm in WORLD_PROPS[key]:
			v3["res://art/props/%s.svg" % nm] = true
	for nm in PROPS_UNDRAWN:
		v3["res://art/props/%s.svg" % nm] = true
	for dir in LEVEL_ART:
		for f in ResourceLoader.list_directory(dir):
			var p := "%s/%s" % [dir, f]
			if (f.ends_with(".svg") or f.ends_with(".png")) and not v3.has(p):
				out.append(p)
	for k in EnemyKinds.KINDS:
		if not KIND_ART.has(k):
			out.append(str(EnemyKinds.KINDS[k]["script"]))
	for k in EnemyKinds.PLANNED:
		if not KIND_ART.has(k):
			out.append(str(EnemyKinds.PLANNED[k]["script"]))
	return out.filter(func(p): return ResourceLoader.exists(p))


func world_art(key: String) -> Array:
	## A WORLD_ART set's files, and the scripts of the kinds whose art it is.
	## "kind:<k>": one kind's frames from its world's set (the frames named
	## like its FRAMES, and that world's Omen marks) and its script;
	## "props:<wN>": a world's props alone. (A level of another world that
	## places a kind or two warms only theirs: the rev5 review, 6-4 held every
	## W3, W4 and W5 frame for a Rootling, a Creepbone, a Spurwheel, a
	## Tickwind, a Glassmite and a Gustling.)
	if _art_cache.has(key):
		return _art_cache[key]
	var out := []
	if key.begins_with("kind:"):
		var k := key.substr(5)
		var wkey := str(KIND_ART.get(k, ""))
		var info: Dictionary = EnemyKinds.KINDS.get(k, EnemyKinds.PLANNED.get(k, {}))
		var pre: Array = []
		if info.has("script") and ResourceLoader.exists(str(info["script"])):
			var fr = (load(str(info["script"])) as Script).get_script_constant_map().get("FRAMES")
			if fr is Array:
				for nm in fr:
					var q := str(nm).get_slice("_", 0) + "_"
					if not pre.has(q):
						pre.append(q)
		for nm in WORLD_ART.get(wkey, []):
			var n := str(nm)
			var mine := pre.is_empty() or n.begins_with("omen_")
			for q in pre:
				if n.begins_with(str(q)):
					mine = true
			if mine:
				out.append("res://art/enemies/%s.svg" % n)
		if info.has("script"):
			out.append(str(info["script"]))
	elif key.begins_with("props:"):
		for nm in WORLD_PROPS.get(key.substr(6), []):
			out.append("res://art/props/%s.svg" % nm)
	else:
		for nm in WORLD_ART.get(key, []):
			out.append("res://art/enemies/%s.svg" % nm)
		for nm in WORLD_PROPS.get(key, []):
			out.append("res://art/props/%s.svg" % nm)
		for k in KIND_ART:
			if KIND_ART[k] == key:
				var info: Dictionary = EnemyKinds.KINDS.get(k, EnemyKinds.PLANNED.get(k, {}))
				if info.has("script"):
					out.append(str(info["script"]))
	out = out.filter(func(p): return ResourceLoader.exists(p))
	_art_cache[key] = out
	return out


const BOSS_SETS := {"1-4": "tollgrave", "2-4": "snuffer", "3-4": "rootmother", "4-4": "tinker", "5-4": "saint", "6-4": "hush"}


func sets_for(index: int) -> Array:
	## The sets a main level will want, from its registry entry alone (the
	## map and the results look ahead with it): its world's, and its boss's.
	if index < 0 or index >= Game.LEVELS.size():
		return []
	var info: Dictionary = Game.LEVELS[index]
	var out := []
	var key := "w%d" % int(info.get("world", 0))
	if WORLD_ART.has(key):
		out.append(key)
	var b := str(BOSS_SETS.get(str(info.get("id", "")), ""))
	if b != "":
		out.append(b)
	return out


func art_sets_of(data: RefCounted) -> Array:
	## The WORLD_ART sets a level needs: its world's monsters (W3+) and the
	## set of every kind it places (a boss's own frames only where it stands).
	var out := []
	var wn := int(data.get("world")) if data != null and data.get("world") != null else 0
	var own := "w%d" % wn
	if WORLD_ART.has(own):
		out.append(own)
	if data != null and data.get("entities") is Array:
		for e in data.entities:
			var kind := str((e as Dictionary).get("kind", "")) if e is Dictionary else ""
			# The level's X is its header's boss, a D its Dread's kind (a
			# secret level's D, its Warden's): their own art.
			if kind == "boss":
				kind = str(data.get("boss")) if str(data.get("boss")) not in ["", "<null>"] else "tollgrave"
			elif kind == "dread":
				var named = data.get("dread") if data.get("dread") is Dictionary and not (data.dread as Dictionary).is_empty() else data.get("warden")
				kind = str((named as Dictionary).get("kind", "")) if named is Dictionary else ""
			var key := str(KIND_ART.get(kind, ""))
			if key.begins_with("w") and key != own and WORLD_ART.has(key):
				# Another world's kind: its own frames, and that world's props.
				for kk in ["kind:" + kind, "props:" + key]:
					if not out.has(kk):
						out.append(kk)
			elif key != "" and not out.has(key):
				out.append(key)
	return out


func warm_sets(keys: Array) -> void:
	## The WORLD_ART sets wanted now: asked for on a thread (those not warm
	## yet); every other set is let go (its textures freed once no monster
	## holds them). v2's art, warmed at the title, always stays.
	if not _sets_on:
		return
	_warm_sets = keys.duplicate()
	var want := {}
	for key in keys:
		for p in world_art(str(key)):
			want[p] = true
	for key in WORLD_ART:
		if keys.has(key):
			continue
		for p in world_art(key):
			if not want.has(p):
				_warm.erase(p)
	if not _threads:
		return
	for p in want:
		if not _warm.has(p) and not _warming.has(p) and ResourceLoader.load_threaded_request(p) == OK:
			_warming.append(p)


func _set_wanted(p: String) -> bool:
	## A path some wanted set holds (or v2's: in no set at all).
	if _set_of.is_empty():
		for key in WORLD_ART:
			for q in world_art(key):
				if not _set_of.has(q):
					_set_of[q] = []
				(_set_of[q] as Array).append(key)
	if not _set_of.has(p):
		return true
	for key in _warm_sets:
		if (_set_of[p] as Array).has(key) or world_art(str(key)).has(p):
			return true
	return false


func _warm_level_art(with_sets := false) -> void:
	## The levels' art (v2's, about 46 MB of textures) and the monsters'
	## scripts, asked for on a thread while the title is up and kept for
	## good. A level's build (Play, Onward, Restart) then finds them loaded,
	## where it used to load each kind's frames and compile its script on the
	## main thread whenever the level before had let them go: 2-4 froze for
	## about 200 ms as it started, and now about 40. (with_sets: --warm, the
	## bot's run, whose level asks for its own sets as it builds.)
	if not _threads:
		return
	for p in level_art():
		if not _warm.has(p) and not _warming.has(p) and ResourceLoader.load_threaded_request(p) == OK:
			_warming.append(p)
	_warm_hero()
	_sets_on = _sets_on or with_sets


func hero_art(cls: String) -> Array:
	## A calling's rig (its parts, heads and trims; not its portraits, UI's):
	## warmed with v2's art and kept, so a level's first frame doesn't load
	## them on the main thread (the int2 review: 3-1's first frame 281 ms).
	var out := []
	var dir := "res://art/heroes/%s" % cls
	if cls == "" or not DirAccess.dir_exists_absolute(dir):
		return out
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".svg") and not f.begins_with("portrait_"):
			out.append("%s/%s" % [dir, f])
	return out


func _warm_hero() -> void:
	## The calling being played: its rig asked for on threads (another
	## calling's let go).
	var cls := str(Game.hero_id())
	if cls == _hero_warm or not _threads:
		return
	if _hero_warm != "":
		for p in hero_art(_hero_warm):
			_warm.erase(p)
	_hero_warm = cls
	for p in hero_art(cls):
		if not _warm.has(p) and not _warming.has(p) and ResourceLoader.load_threaded_request(p) == OK:
			_warming.append(p)


func _claim_warm(wait := false) -> void:
	## Take up what has loaded (every load asked for is taken once; a set's
	## file let go while it loaded is taken and dropped).
	for p in _warming.duplicate():
		if wait or ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var r = ResourceLoader.load_threaded_get(p)
			if _set_wanted(p):
				_warm[p] = r
			_warming.erase(p)


func warm_art() -> Dictionary:
	## The levels' art loaded ahead so far (tests).
	return _warm


func _story_ahead(ids: Array) -> void:
	## A story scene's first picture asked for ahead, for each scene here that
	## will play (not seen yet); anything asked for before is let go. The bot
	## never sees a scene.
	var want := []
	for id in ids:
		if (_autoplay == "" or _story_on) and str(id) != "" and Story.has_scene(str(id)) and not Game.seen(str(id)):
			want.append(str(id))
	story_ahead = want
	if _threads:
		CutsceneScript.prefetch(want)


func _autoplay_save(and_load := true) -> void:
	## The bot keeps its own save, and its slots sit beside it: the player's
	## are left alone. (A test checks the paths without and_load.)
	Game.save_path = Game.AUTOPLAY_SAVE
	Game.slot_base = Game.AUTOPLAY_SAVE.trim_suffix(".json")
	if and_load:
		Game.load_save()


func _shoot_later(path: String, after: float) -> void:
	await get_tree().create_timer(after).timeout
	# Reading the screen back stalls the frame (about 100 ms at 2868 x 1320):
	# the meter's own doing, so it's timed and printed here and that frame
	# is left out of the figures.
	var t0 := Time.get_ticks_usec()
	# (Headless there's no screen to read back.)
	var img: Image = null if DisplayServer.get_name() == "headless" else get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(path)
	_perf_skip = true
	print("[perf] saved %s in %.1f ms (that frame is left out of the figures), safe area %s, window %s, viewport %s" % [path,
			(Time.get_ticks_usec() - t0) / 1000.0, DisplayServer.get_display_safe_area(), DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])


func autoplay_route(route: String) -> void:
	## What --autoplay=<route> runs: a level by id (1-1, 1-S, lab-1; <id>@<n>
	## from its altar n), or
	## descent:<d> / rush:<boss id> / trial:<trial id> (the mode script's own
	## static autoplay(main, arg), once it's there), scene:<id> (a story scene,
	## with the perf line), or screens.
	if route == "screens":
		_shoot_screens()
		return
	var kind := route.get_slice(":", 0) if route.contains(":") else ""
	var arg := route.get_slice(":", 1) if route.contains(":") else ""
	if kind == "scene":
		play_scene(arg, func(): _perf_say("[perf] scene %s done" % arg))
		if current != null and "auto_advance" in current:
			current.auto_advance = true
		return
	if MODE_SCRIPTS.has(kind):
		var path: String = MODE_SCRIPTS[kind]
		var sc = load(path) if ResourceLoader.exists(path) else null
		if sc != null and _script_has(sc, "autoplay"):
			(sc as Script).call("autoplay", self, arg)
		else:
			_perf_say("[perf] autoplay %s: skipped: %s missing" % [route, path.get_file()])
		return
	# <id>@<n>: the level started at its altar n (0 the first), as "Continue
	# from the altar" starts it: a perf run over a level's later sections
	# (the debug bot can't time World 4's weights and falls back to the
	# altar before them) or straight to a boss's door (3-4@2, 4-4@2).
	var at := -1
	if route.contains("@") and route.get_slice("@", 1).is_valid_int():
		at = int(route.get_slice("@", 1))
		route = route.get_slice("@", 0)
	if not level_exists(route):
		_perf_say("[perf] autoplay: no level '%s'; playing 1-1" % route)
		route = "1-1"
		at = -1
	if _story_on and Game.index_of(route) >= 0:
		# --story: the level's beats play again on every run (the bot's own
		# save marks them seen as they play).
		var sd: RefCounted = LevelData.load_file(str(Game.LEVELS[Game.index_of(route)]["path"]))
		for k in ["start", "boss"]:
			(Game.data["seen"] as Array).erase(str(sd.story.get(k, "")))
	if at >= 0 and Game.index_of(route) >= 0:
		_start_level(Game.LEVELS[Game.index_of(route)], Game.index_of(route), {"level": route, "diff": Game.diff(), "altar": at})
	else:
		play_level_id(route)
	if current != null and "autoplay" in current:
		current.autoplay = true
	_shoot_later("user://autoplay_level.png", 6.0)


var soak := 0.0                  # --soak=<seconds>: the Descent's soak run (its mode reads it)


static func _script_has(sc: Script, fn: String) -> bool:
	for m in sc.get_script_method_list():
		if m["name"] == fn:
			return true
	return false


func _shoot_screens() -> void:
	show_title()
	await _shoot_later("user://autoplay_title.png", 3.0)
	show_map()
	await _shoot_later("user://autoplay_map.png", 1.5)


# The frame meter (--autoplay): every 2 s the frame rate and the worst frame,
# and each frame over 20 ms on its own line. Timed by the wall clock, not by
# _process's delta: Godot clamps that to max_physics_steps_per_frame ticks
# (6 / 120 s = 50 ms), so a 250 ms frame would read as 50.
const PERF_WINDOW := 2.0
const PERF_HITCH := 0.020
const PIPELINES := [
	["canvas", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS],
	["mesh", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH],
	["surface", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE],
	["draw", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW],
	["spec", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION],
]

var _autoplay := ""
var perf_lines: Array = []     # what the meter printed (the tests read it)
var _perf_start_us := 0
var _perf_last_us := 0         # the wall clock at the last frame; 0 until started
var _perf_t := 0.0             # wall-clock seconds counted in this window
var _perf_frames := 0
var _perf_worst := 0.0
var _perf_skip := false        # the next frame held the meter's own screenshot: not counted
var _perf_pipes: Array = []
var _meter: RefCounted = null  # scripts/perf_meter.gd: the v3 line's GPU, CPU and light figures


func _process(dt: float) -> void:
	if not _warming.is_empty():
		_claim_warm()
	if _lab_btn != null and is_instance_valid(_lab_btn):
		_place_lab_button()
	# The level just cleared: its closing scene (played on a first clear) is
	# asked for during the bells, before the results.
	if _end_world != null:
		if not is_instance_valid(_end_world) or _end_world != current:
			_end_world = null
		elif str(_end_world.get("state")) == "clear":
			_end_world = null
			_story_ahead([_end_scene])
	if _autoplay == "":
		return
	var now := Time.get_ticks_usec()
	if _perf_last_us == 0:
		perf_start(now)
		return
	perf_frame((now - _perf_last_us) / 1e6, dt, now)


func perf_start(now := -1) -> void:
	_perf_start_us = Time.get_ticks_usec() if now < 0 else now
	_perf_last_us = _perf_start_us
	_perf_pipes = _pipelines()
	_meter = load(PERF_METER).new() if ResourceLoader.exists(PERF_METER) else null
	if _meter != null:
		_meter.start(get_viewport() if is_inside_tree() else null)


func perf_frame(real: float, dt: float, now := -1) -> void:
	## One frame of the meter: `real` seconds of wall clock since the last,
	## `dt` what _process was told.
	if now < 0:
		now = _perf_last_us + int(real * 1e6)
	_perf_last_us = now
	var pipes := _pipelines()
	var grew := []
	for i in pipes.size():
		var d: int = int(pipes[i]) - (int(_perf_pipes[i]) if i < _perf_pipes.size() else 0)
		if d != 0:
			grew.append("+%d %s" % [d, PIPELINES[i][0]])
	_perf_pipes = pipes
	var at := (now - _perf_start_us) / 1e6
	if _perf_skip:
		_perf_skip = false
		_perf_say("[perf] %s t=%.2fs screenshot frame %.1f ms (dt %.1f ms): not counted" % [_autoplay, at, real * 1000.0, dt * 1000.0])
		return
	_perf_t += real
	_perf_frames += 1
	_perf_worst = maxf(_perf_worst, real)
	if _meter != null:
		_meter.sample()
	if real > PERF_HITCH:
		_perf_say("[perf] %s t=%.2fs hitch %.1f ms (dt %.1f ms), pipelines %s" % [_autoplay, at, real * 1000.0, dt * 1000.0,
				", ".join(grew) if not grew.is_empty() else "none new"])
	if _perf_t >= PERF_WINDOW:
		# [perf] <id> fps F worst frame W ms dc D | gpu G ms rcpu R ms | proc P ms phys Q ms
		#        | lights L hush H tint T refl M | sparks S motes A | texmem X MB   (spec §13.2)
		if _meter != null:
			# (a scene played by --autoplay=scene:<id> frees itself when it ends)
			_perf_say(_meter.line(_autoplay, _perf_frames / _perf_t, _perf_worst, current if is_instance_valid(current) and current is Node2D else null))
		else:
			_perf_say("[perf] %s fps %.1f worst frame %.1f ms, draw calls %d" % [_autoplay, _perf_frames / _perf_t, _perf_worst * 1000.0,
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
		_perf_t = 0.0
		_perf_frames = 0
		_perf_worst = 0.0


func _pipelines() -> Array:
	var out := []
	for p in PIPELINES:
		out.append(RenderingServer.get_rendering_info(p[1]))
	return out


func _perf_say(line: String) -> void:
	perf_lines.append(line)
	if perf_lines.size() > 200:
		perf_lines.pop_front()
	print(line)


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)


func _hook(obj: Object, sig: String, cb: Callable) -> void:
	## Connect a signal a screen may or may not have (yet).
	if obj.has_signal(sig):
		obj.connect(sig, cb)


func _set_if(obj: Object, prop: String, v) -> void:
	if prop in obj:
		obj.set(prop, v)


# ---------------------------------------------------------------- the title and the story

func show_title() -> void:
	Game.open_last()   # the title shows the slot played last (one erased leaves it)
	var t := TitleScript.new()
	t.start.connect(show_saves)
	_hook(t, "tales", func(_a = null): show_tales(show_title))
	_swap(t)
	Sfx.play_music("title")
	# The first tap plays the intro: its first picture loads meanwhile, and
	# so does an owed finale's (the_pull plays as the map first opens).
	var ahead := ["intro"]
	var owed := _finale_due()
	if owed != "":
		ahead.append(owed)
	_story_ahead(ahead)


func show_saves() -> void:
	## The three save slots: play one on, start a new game in one, or back.
	var s := SavesScript.new()
	s.play.connect(_play_slot)
	s.new_game.connect(_new_game)
	s.back.connect(show_title)
	_hook(s, "tales", func(_a = null): show_tales(show_saves))
	_swap(s)
	Sfx.play_music("title")


func show_tales(back: Callable = Callable()) -> void:
	## The Tales (ST's tales_screen.gd; contract §11: the title and saves
	## screens emit `tales`), back to where it was opened from. Until ST's
	## screen is in the build, nothing happens.
	if not ResourceLoader.exists(TALES_SCREEN):
		return
	var s: Node = load(TALES_SCREEN).new()
	if "main" in s:
		s.main = self
	var to: Callable = back if back.is_valid() else show_title
	for sig in BACK_SIGNALS:
		_hook(s, sig, func(_a = null): to.call())
	_swap(s)


func _play_slot(n: int) -> void:
	## A filled slot: everything read afresh from it, then on where it was.
	Game.use_slot(n)
	_map_focus = -1
	_after_title()


func _new_game(n: int) -> void:
	## An empty slot, or one started over: a fresh save there, from the intro.
	Game.new_game(n)
	_map_focus = -1
	_after_title()


func _after_title() -> void:
	## The first time: the intro, then the oath (where the calling is chosen).
	## A player who saw the intro but never chose goes straight to the oath.
	if _autoplay == "" and not Game.seen("intro"):
		play_scene("intro", func(): play_scene("oath", _after_oath))
	elif _autoplay == "" and Game.heroes().is_empty():
		play_scene("oath", _after_oath)
	else:
		show_map()


func _after_oath() -> void:
	## The calling is chosen: the map, open on the first level to play (1-1
	## for a new player and for a v1 veteran alike).
	if Game.heroes().is_empty():
		Game.new_hero("knight")
	show_map()


func play_scene(id: String, then: Callable) -> void:
	## A full-screen story scene in place of the current screen.
	if not Story.has_scene(id):
		then.call()
		return
	_swap(CutsceneScript.make(id, then))


# ---------------------------------------------------------------- the map and its screens

func show_map(focus := -1) -> void:
	var owed := _finale_due()
	if owed != "":
		play_scene(owed, func(): show_map(focus))
		return
	var m := MapScript.new()
	m.focus = focus if focus >= 0 else next_level()
	_map_focus = m.focus
	# The map opens on the focus's world, and that world's opening scene
	# plays then if it's still owed (world_opened): keep its picture loading
	# (World 2's, asked for while 1-4's results were up); let the rest go.
	var opener := ""
	if m.focus >= 0 and m.focus < Game.LEVELS.size():
		opener = Story.world_opener(int(Game.LEVELS[m.focus]["world"]))
	_story_ahead([opener])
	warm_sets(sets_for(m.focus))   # the focus's world's art ahead; the rest let go
	m.play.connect(play_level)
	m.back.connect(show_title)
	_hook(m, "callings", show_callings)
	_hook(m, "sheet", show_sheet)
	_hook(m, "chandler", show_chandler)
	_hook(m, "world_opened", _on_world_opened)
	_hook(m, "challenges", func(_a = null): show_modes())
	_hook(m, "play_secret", func(id): play_level_id(str(id)))
	_hook(m, "resume_altar", func(sus): resume_level(sus))
	_swap(m)
	Sfx.play_music("title")
	_off_path = ""
	_mode = null
	# The owner signed the lab off (2026-09-26): only development builds show it; TestFlight and the store never do.
	if FEEL_LAB_BUTTON and OS.is_debug_build() and FileAccess.file_exists("res://levels/%s.txt" % FEEL_LAB):
		_add_lab_button(m)
	if _autoplay == "":
		_map_card(m)


func _add_lab_button(m: Control) -> void:
	## "Feel lab" beside the map's Chandler button: the owner opens lab-1
	## himself on the phone (placed each frame, since the map lays itself out).
	_lab_btn = UI.make_button("Feel lab", false, func(): play_level_id(FEEL_LAB), "click", 15)
	_lab_btn.name = "FeelLab"
	m.add_child(_lab_btn)
	_place_lab_button()


func _place_lab_button() -> void:
	if _lab_btn == null or not is_instance_valid(_lab_btn) or current == null:
		return
	var ch = current.get("_chandler_btn")
	if ch is Control and is_instance_valid(ch):
		_lab_btn.custom_minimum_size = Vector2(0, (ch as Control).size.y)
		_lab_btn.reset_size()
		_lab_btn.position = (ch as Control).position + Vector2((ch as Control).size.x + 12.0, 0.0)


# The one-time cards on the map, one a visit, in this order. A card is due
# while Game.data.notices lacks its id; it's marked (Game.notice(id), which
# saves) only when it's closed, so a map only looked at writes nothing. None
# before PR's notice().
const CARDS := [
	["v3_update", "The bells below have woken", "Below the Tallow Deep lie four new worlds, and the Hush at the bottom. Your hero, gear and records came with you."],
	["new_points", "New skills", "%d points to spend. The skill trees grew deeper, and your Vigil ranks came back as points: spend them on the Sheet."],
	["nightfall_waits", "Nightfall waits", "Nightfall now waits beneath the Hush. Your Nightfall clears are kept."],
	["gauntlet", "The Gauntlet", "Every boss, one after another: the Waxworks' Gauntlet is open."],
	["nightfall_open", "Nightfall", "The Hush sleeps. Nightfall is open: the same halls, deeper, darker, angrier."],
]


func v3_update_body() -> String:
	## The update card says what this build holds: all four new worlds and
	## the Hush (CARDS' words), or only the ones built so far, with more to
	## come (a W3-W4 build mustn't promise the Hush it hasn't got: the card
	## is seen once).
	var n := 0
	for w in range(3, 7):
		if _world_built(w):
			n += 1
	if n >= 4:
		return str(CARDS[0][2])
	var worlds: String = ["", "a new world", "two new worlds", "three new worlds"][clampi(n, 0, 3)]
	return "Below the Tallow Deep lie %s, and more wait deeper still. Your hero, gear and records came with you." % worlds


func _card_due(id: String) -> bool:
	match id:
		"v3_update":
			# Only once the new worlds are in the build (closing it marks it
			# for good; a Phase 0 build has W1-W2 alone).
			return Game.LEVELS.size() > 8
		"new_points":
			# Only when a load turned Vigil ranks back into points under the
			# deep tree (Game.points_back(), spec §9.2.4), never for a point a
			# level-up gave (a new save has it marked from the start).
			return Classes.deep and not Game.heroes().is_empty() and Game.has_method("points_back") and int(Game.points_back()) > 0
		"nightfall_waits":
			return Game.has_method("relock_card") and not (Game.relock_card() as Dictionary).is_empty()
		"gauntlet", "nightfall_open":
			return Game.seen("homecoming")
	return false


func _noticed(id: String) -> bool:
	var n = Game.data.get("notices", [])
	return n is Array and (n as Array).has(id)


func _map_card(m: Control) -> void:
	if not Game.has_method("notice"):
		return
	for c in CARDS:
		var id := str(c[0])
		if _noticed(id) or not _card_due(id):
			continue
		var title := str(c[1])
		var body := str(c[2])
		if id == "nightfall_waits":
			var rc: Dictionary = Game.relock_card()   # PR's words (Nightfall, or Nightfall and the Witching Hour)
			title = str(rc.get("title", title))
			body = str(rc.get("body", body))
		elif id == "v3_update":
			body = v3_update_body()
		elif id == "new_points":
			var n := int(Game.points_back())
			body = body % n
			if n == 1:
				body = body.replace("1 points to spend", "1 point to spend")
		if m.has_method("card"):
			# SC's card; it calls Game.notice(id) when it's closed.
			m.card(id, title, body)
		else:
			_show_card(m, title, body, id)
		return


func _show_card(host: Control, title: String, body: String, id := "") -> void:
	## A plain card over the map until SC's own (map.card): a tap closes it.
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var box := VBoxContainer.new()
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", UI.GOLD)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(400, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(b)
	var ok := UI.make_button("OK", true, func():
		if id != "" and Game.has_method("notice"):
			Game.notice(id)
		shade.queue_free(), "click", 16)
	box.add_child(ok)
	panel.add_child(box)
	shade.add_child(panel)
	host.add_child(shade)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shade.name = "Card"


func next_level() -> int:
	## Where the map opens by itself: the first open level not yet cleared
	## on this difficulty, else the last one open. (A migrated veteran keeps
	## his v1 unlocks but starts his records afresh, so his map opens on 1-1
	## rather than on World 2's door.)
	var n := mini(Game.unlocked_count(), Game.LEVELS.size())
	for i in n:
		if not bool(Game.level_record(str(Game.LEVELS[i]["id"]))["cleared"]):
			return i
	return maxi(n - 1, 0)


func _back_to_map(_a = null) -> void:
	show_map(_map_focus)


func _open(path: String, props := {}) -> Node:
	## One of the map's screens, with its way back (props set on it first).
	if not ResourceLoader.exists(path):
		return null
	var s: Node = load(path).new()
	for k in props:
		_set_if(s, k, props[k])
	for sig in BACK_SIGNALS:
		_hook(s, sig, _back_to_map)
	_swap(s)
	return s


func show_callings(_a = null) -> void:
	## The Keeper screen on its own: switch to a calling, or make a new one.
	if not ResourceLoader.exists(KEEPER_SCREEN):
		return
	var k: Node = load(KEEPER_SCREEN).new()
	for sig in BACK_SIGNALS:
		_hook(k, sig, _back_to_map)
	# The callings there were before: the screen may make the hero itself
	# before (or after) it says which, so "new" is judged from this.
	var had: Array = Game.heroes().keys()
	if k.has_signal("picked"):
		k.connect("picked", _on_calling_picked.bind(had))
	_swap(k)


func _on_calling_picked(id, had: Array = []) -> void:
	var cls := str(id)
	var fresh := not had.has(cls)
	Game.new_hero(cls)
	show_map(_map_focus)
	if fresh and Game.heroes().size() > 1:
		# A new calling: Mother Taper has a word for it.
		CutsceneScript.play_overlay(current, "new_calling", func(): pass)


func show_sheet(_a = null) -> void:
	## The Sheet from the map: on Skills while a skill point waits.
	_open(HERO_SCREEN, {"tab": "skills"} if int(Game.hero().get("points", 0)) > 0 else {})


func show_chandler(_a = null) -> void:
	## The Chandler's shop; Waxley introduces himself the first time. The
	## shop plays that itself when it can; asked again here, the beat that's
	## already playing is kept (play_overlay never plays one twice at once).
	var c := _open(CHANDLER_SCREEN)
	if c != null and not Game.seen("meet_waxley"):
		CutsceneScript.play_overlay(c, "meet_waxley", func(): pass)


func _on_world_opened(w = 1) -> void:
	## The map's tab for a world opened: its opening scene, the first time.
	var opener := Story.world_opener(int(w))
	if opener != "" and not Game.seen(opener) and _autoplay == "":
		var first := 0
		for i in Game.LEVELS.size():
			if int(Game.LEVELS[i]["world"]) == int(w):
				first = i
				break
		play_scene(opener, func(): show_map(first))


# ---------------------------------------------------------------- a level and its end

func level_exists(id: String) -> bool:
	return Game.index_of(id) >= 0 or not _secret_info(id).is_empty() or FileAccess.file_exists("res://levels/%s.txt" % id)


func _secret_info(id: String) -> Dictionary:
	## Game.SECRET_LEVELS' entry for id, or {} (before PR's registry, none).
	var reg = (Game.get_script() as Script).get_script_constant_map().get("SECRET_LEVELS", Game.get("SECRET_LEVELS"))
	if reg is Array:
		for info in reg:
			if info is Dictionary and str(info.get("id", "")) == id:
				return info
	return {}


func play_level_id(id: String) -> void:
	## Any level by its exact id: the main path (as play_level), a secret level
	## (1-S ... 6-S; Onward from it goes to the map), or a file in res://levels
	## off the path (the feel labs).
	var idx := Game.index_of(id)
	if idx >= 0:
		play_level(idx)
		return
	var info := _secret_info(id)
	if info.is_empty():
		info = {"id": id, "path": "res://levels/%s.txt" % id, "world": LevelData.world_of(id)}
	_start_level(info, -1)


func play_level(index: int) -> void:
	_start_level(Game.LEVELS[index], index)


func resume_level(sus: Dictionary) -> void:
	## "Continue from the altar" (the map's card, spec §9.1): the snapshot's
	## level on its difficulty, started at its altar. A snapshot that no
	## longer fits (a level gone, a difficulty locked) is dropped.
	var id := str(sus.get("level", ""))
	var d := str(sus.get("diff", Game.diff()))
	if d != Game.diff():
		Game.set_diff(d)
	var idx := Game.index_of(id)
	var info: Dictionary = _secret_info(id) if idx < 0 else Game.LEVELS[idx]
	if id == "" or info.is_empty() or Game.diff() != d:
		Game.clear_suspend()
		show_map()
		return
	_start_level(info, idx, sus)


func _start_level(info: Dictionary, index: int, sus := {}) -> void:
	## A level from its registry entry; index is its place on the main path
	## (-1 off it: a secret level, a lab).
	if index >= 0:
		last_level = index
	_off_path = "" if index >= 0 else str(info["id"])
	if Game.heroes().is_empty():
		# No calling chosen yet (a save from before the story): a Candleknight.
		Game.new_hero("knight")
	# The first time into a world (Onward, or its first level on the map):
	# its opening scene first.
	var opener := Story.world_opener(int(info.get("world", 0))) if index >= 0 else ""
	if _autoplay == "" and opener != "" and Story.has_scene(opener) and not Game.seen(opener):
		play_scene(opener, func(): _start_level(info, index, sus))
		return
	var data: RefCounted = LevelData.load_file(info["path"])
	if data.errors.size() > 0:
		push_error("level %s: %s" % [info["id"], ", ".join(data.errors)])
	warm_sets(art_sets_of(data))   # its v3 kinds' art (loading on threads as it builds)
	# That world's sound bank renders next (A7; unrendered sounds play their
	# core fallbacks meanwhile). A lab (world 0) asks for nothing.
	var wn := int(info.get("world", 0))
	if wn > 0 and Sfx.has_method("prefer_bank"):
		Sfx.prefer_bank(wn)
	# Its opening beat's picture loads on a thread while the level builds,
	# the boss's once Waxby nears the arena (world.boss_near: the last altar
	# before it; a player's 3-4 held boss_3_before's 46 MB from the level's
	# start, the int2 review); the closing scene's once it's cleared.
	_story_ahead([data.story.get("start", "")])
	var w := WorldScript.new()
	w.setup(data)
	# Set before it builds, so the bot never waits on a story beat.
	w.autoplay = _autoplay != ""
	w.play_beats = _story_on
	var boss_beat := str(data.story.get("boss", ""))
	if boss_beat != "":
		w.boss_near.connect(func(): _story_ahead([boss_beat]), CONNECT_ONE_SHOT)
	UI.keep_faces(str(Game.hero_id()))
	_warm_hero()
	if not sus.is_empty():
		w.resume = sus   # (the World starts at its altar)
	w.finished.connect(_on_finished)
	w.quit.connect(func(): show_map(index if index >= 0 else _map_focus))
	w.restart.connect(func(): _start_level(info, index))   # (fresh: a Restart is a new run of the level)
	_swap(w)
	_end_scene = str(data.story.get("end", ""))
	_end_world = w if _end_scene != "" and _autoplay == "" and not Game.seen(_end_scene) else null
	_hurt_bark(w)
	_harder_bark(w)
	_deep_warning(w)


func _deep_warning(w: Node) -> void:
	## A hero too shallow for this level's Nightfall or Witching depth (more
	## than 5 levels under its area) sees the one-time card as it starts
	## (spec §1.6; Game.deep_warning). The map shows the same card, with the
	## same notice id, before a level it starts, so it's only ever seen once.
	if _autoplay != "" or not Game.has_method("deep_warning") or w.is_lab():
		return
	var c: Dictionary = Game.deep_warning(int(w.area), Game.diff())
	if c.is_empty():
		return
	w.card(str(c["id"]), str(c["title"]), str(c["body"]))
	Game.notice(str(c["id"]))


func _hurt_bark(w: Node) -> void:
	## The first hurt ever: Mother Taper says what the flame is (the HUD's
	## once-only gate keeps it to once a save).
	var p = w.get("player")
	if _autoplay != "" or p == null or not p.has_signal("hurt_taken") or Story.bark_heard("first_hurt"):
		return
	var say := func(_amount, _left):
		if is_instance_valid(w):
			w.bark("first_hurt")
	p.hurt_taken.connect(say, CONNECT_ONE_SHOT)


func _harder_bark(w: Node) -> void:
	## The first level walked past Dusk (Nightfall, which the ending opens):
	## Mother Taper says the Hush is angry now, a few seconds into play.
	if _autoplay != "" or Game.diff() == "dusk" or Story.bark_heard("nightfall"):
		return
	# After the level's own barks, if its beat left some.
	var q: Node = w.get_node_or_null("StoryBarks")
	if q != null and not q.is_queued_for_deletion() and "keys" in q:
		q.keys.append("nightfall")
	else:
		CutsceneScript.queue_barks(w, ["nightfall"], 3.0)


func _on_finished(res: Dictionary) -> void:
	if _off_path.begins_with("lab-"):
		# The feel lab: no records, no unlocks; the playlog has the attempt.
		_show_results(res, {})
		return
	var out: Dictionary = Game.record_result(res)
	var end_id := str(res.get("story_end", ""))
	if bool(out.get("first_clear", false)) and end_id != "" and Story.has_scene(end_id) \
			and not Game.seen(end_id) and _autoplay == "":
		play_scene(end_id, func(): _show_results(res, out))
	else:
		_show_results(res, out)


func _show_results(res: Dictionary, out: Dictionary) -> void:
	var r := ResultsScript.new()
	r.result = res
	r.index = last_level
	if _off_path != "":
		# A secret level or a lab: Onward and the map go back to the map, and
		# Replay plays it again.
		var id := _off_path
		_set_if(r, "rewards", out.get("rewards", []))
		_set_if(r, "first_clear", out.get("first_clear", false))
		r.next.connect(func(): _leave_results(func(): show_map(_map_focus)))
		r.replay.connect(func(): _leave_results(func(): play_level_id(id)))
		r.to_map.connect(func(): _leave_results(func(): show_map(_map_focus)))
		_swap(r)
		Sfx.stop_music(0.6)
		_story_ahead([_finale_due()])
		return
	_set_if(r, "rewards", out.get("rewards", []))
	_set_if(r, "first_clear", out.get("first_clear", false))
	_set_if(r, "after", Story.after_line(str(res.get("level", "")), Game.hero_id()))
	r.next.connect(func(): _leave_results(_onward))
	r.replay.connect(func(): _leave_results(func(): play_level(last_level)))
	r.to_map.connect(func(): _leave_results(func(): show_map(mini(last_level + 1, Game.LEVELS.size() - 1))))
	_swap(r)
	Sfx.stop_music(0.6)
	# While the results are up: the ending, if it's owed now, and the next
	# world's opening scene (Onward into it plays that first).
	var nxt := last_level + 1
	_story_ahead([_finale_due(), Story.world_opener(int(Game.LEVELS[nxt]["world"])) if nxt < Game.LEVELS.size() else ""])
	var keep := sets_for(last_level)   # Replay
	for k in sets_for(nxt):            # Onward
		if not keep.has(k):
			keep.append(k)
	warm_sets(keep)


func _leave_results(then: Callable) -> void:
	## After the last boss's results, the ending comes first, whichever way
	## out: then the map, or, when the finale scene says "resume": true (v3's
	## the_pull), the player's own choice (Onward, Replay, the map).
	var owed := _finale_due()
	if owed != "":
		if bool(Story.scene(owed).get("resume", false)):
			play_scene(owed, then)
		else:
			play_scene(owed, func(): show_map(last_level))
	else:
		then.call()


func _onward() -> void:
	## The next level (a new world's opening scene plays first; see play_level).
	var nxt := last_level + 1
	if nxt >= Game.LEVELS.size():
		show_map(last_level)
		return
	play_level(nxt)


# ---------------------------------------------------------------- the modes

func play_custom(data: RefCounted, mode: Object) -> void:
	## A mode's level (a Descent depth, a Waxworks arena, a Trial), built in
	## memory: the World gets the mode before it builds; its finish goes to
	## mode.finished(res) (never Game.record_result), its pause menu's quit
	## and restart to the mode's.
	_mode = mode
	_off_path = str(data.id)
	if Game.heroes().is_empty():
		Game.new_hero("knight")
	if "main" in mode:
		mode.main = self
	warm_sets(art_sets_of(data))   # a Descent biome's, an arena boss's art
	UI.keep_faces(str(Game.hero_id()))
	_warm_hero()
	var w := WorldScript.new()
	w.setup(data)
	w.mode = mode
	w.autoplay = _autoplay != ""
	if "world" in mode:
		mode.world = w
	if Sfx.has_method("prefer_bank"):
		Sfx.prefer_bank(0)   # the modes draw on every bank
	w.finished.connect(func(res): mode.finished(res))
	w.quit.connect(func(): mode.quit())
	w.restart.connect(func(): mode.restart())
	_swap(w)


func show_modes(screen := "") -> void:
	## The Challenges hub (MO's modes_screen.gd), or straight to one of its
	## screens: "descent", "waxworks", "trials". Until it's there, the map.
	if not ResourceLoader.exists(MODES_SCREEN):
		show_map(_map_focus)
		return
	var s: Node = load(MODES_SCREEN).new()
	if "main" in s:
		s.main = self
	for sig in BACK_SIGNALS:
		_hook(s, sig, _back_to_map)
	_swap(s)
	if screen != "" and s.has_method("open"):
		s.open(screen)


func _story_end(id: String, path: String) -> String:
	if not _ends.has(id):
		var data: RefCounted = LevelData.load_file(path)
		_ends[id] = str(data.story.get("end", "")) if data.errors.is_empty() else ""
	return _ends[id]


func _finale_due() -> String:
	## A finale owed: a level whose closing scene names one ("finale") is
	## cleared, and the finale hasn't played yet. A finale that resumes into
	## the next world (the_pull: "Then go, Wick", then Onward into World 3)
	## waits until a level of that world is built, so a W1-W2 build owes
	## nothing after 2-4 (as v3-p0, once v2's ending was seen) and the turn
	## isn't spent, with Taper faint from then on, in a build with nowhere
	## to go down to.
	if _autoplay != "":
		return ""
	for info in Game.LEVELS:
		var end := _story_end(str(info["id"]), str(info["path"]))
		if end == "":
			continue
		var fin := str(Story.scene(end).get("finale", ""))
		if fin != "" and Story.has_scene(fin) and not Game.seen(fin) and bool(Game.level_record(str(info["id"]), "dusk")["cleared"]):
			if bool(Story.scene(fin).get("resume", false)) and not _world_built(int(info["world"]) + 1):
				continue
			# The clear is saved before its closing scene plays: an app killed
			# in boss_6_after owes it before homecoming, so the ending is whole
			# (the rev5 review). (Not the_pull's: a resume finale keeps v3-w1's
			# chain for the owner's W1-W2 slots.)
			if not bool(Story.scene(fin).get("resume", false)) and Story.has_scene(end) and not Game.seen(end):
				return end
			return fin
		# homecoming's "next" (lullaby) is owed until it's seen: a kill in it
		# mustn't lose the story's last scene.
		if fin != "" and Game.seen(fin) and not bool(Story.scene(fin).get("resume", false)):
			var nxt := str(Story.scene(fin).get("next", ""))
			if nxt != "" and Story.has_scene(nxt) and not Game.seen(nxt):
				return nxt
	return ""


func _world_built(w: int) -> bool:
	for info in Game.LEVELS:
		if int(info["world"]) == w:
			return true
	return false
