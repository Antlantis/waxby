extends CanvasLayer
## Story scenes and in-level beats. Plays one scene of story.gd: its shots (a
## panel of up to four parallax layers lit by the panel's own lights, with
## figures and the hero's own rig standing on its anchors), the camera, the
## lines (a dialogue box with round portraits and a typewriter that blips in
## the speaker's voice, storybook narration, the Hush's own letters) and the
## cues (snuffs, ignitions, cards, the calling chooser, the credits...).
##
## A full scene is a screen of its own: main swaps it in (make / play_scene).
## An overlay beat plays over a level or a screen (play_overlay): a level is
## paused, its touch buttons muted and its HUD hidden (the letterbox would cut
## its top row in half) until the beat is done, and the beat's barks then
## follow over live play. Over a screen the top bar covers the screen's whole
## top row instead. Everything moves through advance(dt),
## which _process calls; tests set `manual` and call it themselves. Without
## art/story/panels.json (or one of its textures) the stand-in stage from
## cutscene_stage.gd is drawn instead, so the story always plays.
##
## Panels are lit by the dark's own light bands, applied to each layer as a
## material (so a far "lit" layer never covers the near ones): the sibling
## shader darkness_lit.gdshader (Plan A), or Plan B's darkness_lit_b over one
## reduced light field when world_lights.gd runs that plan. Lights may carry
## a tint (their "color", on v3 panels) and "hush": true (they eat light).
## Glow draws the flames above the dark.
##
## v3 (spec §6.3): the hold cue (E1: hold anywhere to drain a light into
## another; the finale's fallback), a shot's "if" / "unless" flag (E2) and a
## cue's "if", chains that snuff (E3), the spores, rime, shards and
## fireflies motes (E4), an sfx's "vol" (E5), panel lights marked "off" and
## a shot's "lights_on" (E6), Mother Taper's flame by the story's time (E7),
## a portrait's "face" alias (E8), the cast roll after the credits, and
## replays from the Tales screen (replay: no chooser, no side effects). While
## Mother Taper rests, a scene in Story.REST_SUBS plays Hollin's instead.
##
## The oath's choose_name: Mother Taper's question stays up while the name
## entry (name_entry.gd) asks the hero's name under the cue's own prompt (on
## a phone the keyboard covers the box, never the entry), and the save keeps
## what's given; the hero's name plate is blank until then. Where nobody
## types (headless, stepped by hand, --autoplay) it answers Waxby at once.

signal done
signal need_class

const Story := preload("res://scripts/story.gd")
const Stage := preload("res://scripts/cutscene_stage.gd")
const UI := preload("res://scripts/ui.gd")
const Classes := preload("res://scripts/classes.gd")
const GlowScript := preload("res://scripts/glow.gd")
const RigScript := preload("res://scripts/wick_rig.gd")
const PlayerScript := preload("res://scripts/player.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const LIT_SHADER := preload("res://shaders/darkness_lit.gdshader")
const WORLD_LIGHTS := "res://scripts/world_lights.gd"   # field_mode(): Plan A or B (loaded when asked)
const LIGHT_FIELD := "res://scripts/light_field.gd"     # Plan B's shared field
const SELF_PATH := "res://scripts/cutscene.gd"
const PANELS_PATH := "res://art/story/panels.json"
const KEEPER_PATH := "res://scripts/keeper_screen.gd"
const NameEntry := preload("res://scripts/name_entry.gd")
const Keeper := preload("res://scripts/keeper_screen.gd")   # its ease words

const CPS := 45.0              # typewriter characters per second
const HUSH_CPS := 18.0
const GUARD := 0.15            # taps ignored this long after a new line
const LETTERBOX := 28.0
# Over a screen (the Chandler, the map) the top bar covers the screen's whole
# top row: its header (a TAP_H row at most 44 under the safe top) and not the
# row under it (the map's world tabs start 46 down), so nothing there is cut
# in half by the bar's edge.
const SCREEN_ROW := 45.0
# There's no bottom bar over a screen: its bottom row (the map's Callings,
# Sheet, Chandler and Play, the Chandler's tall ware cards) shows whole
# either side of the dialogue box, under the dim, never cut flat by a bar.
const LIFT_MAX := 56.0         # at most this far
const FADE_OUT := 0.3
const FADE_IN := 0.35
const MAX_LIGHTS := 48
const CREDITS_TIME := 11.0     # the whole roll (at most 12 s)
const COLD := Color(0.62, 0.8, 1.0)
const PLINTHS := ["knight", "founder", "witch", "runner", "sexton"]   # left to right, as carved
const PLINTH_X := [180.0, 340.0, 500.0, 660.0, 820.0]                # their middles in the callings panel
# The oath's chooser: under its prompt, a small word that the choice isn't
# for ever (the map's Callings button makes the others); on each card, EASE
# and five pips (lit: easier), so they don't read as power.
const CHOOSER_NOTE := "You can raise the other callings later."
const PIP_R := 3.2
const PIP_STEP := 12.0
const EASE_GAP := 5.0          # EASE to its first pip
const INFO_FACE := 66.0        # the info box's words start this far in, past the face
const INFO_GAP := 14.0         # the words to the rule, the rule to the ease
const INFO_PAD := 14.0         # the ease to the box's right edge

# v2's panels keep v2's light: no tints there (their "color" is only for eyes).
const V2_PANELS := ["glass_legend", "lanternfold", "chapel", "callings", "crypt_row", "belfry", "tallow_vista",
	"undercandle", "bells_all", "dawn_rise", "hush_eye"]
const TINT_K := 0.55           # how far a v3 light's colour tints its warm band
# The hold (E1).
const HOLD_AUTO := 4.0         # auto-advance holds by itself after this long
const HOLD_STREAM := 0.1       # a mote from the light to its target this often while held
const HOLD_TICK := 0.4         # a 10 ms haptic this often while held
const HOLD_GIVE := 0.5         # the give sound's loop
# The cast roll, after v2's credit lines (Story.CAST_ROLL): each page fades
# in, holds and fades out.
const CAST_PAGE := 6.0
const CAST_FADE := 0.6
const SHARD_COLS := ["b8324e", "3a6ab8", "d8a830", "5aa860", "7a5ab8", "e07aa0"]
const MOTE_COUNT := {"moths": 9, "spores": 30, "rime": 50, "shards": 20, "fireflies": 36}

## A beat's barks, handed to the level one at a time once the beat is over
## (the HUD shows them). Holds while the level is paused.
class BarkQueue extends Node:
	var world: Node
	var keys: Array = []
	var wait := 0.8
	var gap := 3.4

	func _process(dt: float) -> void:
		step(dt)

	func step(dt: float) -> void:
		if world == null or not is_instance_valid(world) or keys.is_empty():
			queue_free()
			return
		if bool(world.get("paused")):
			return
		var st = world.get("state")
		if st != null and str(st) != "play":
			return
		wait -= dt
		if wait <= 0.0:
			world.bark(str(keys.pop_front()))
			wait = gap
			if keys.is_empty():
				queue_free()


static var _manifest = null
# Textures asked for on a thread before their scene plays (prefetch): the
# scene that shows them takes them up; path -> true.
static var _ahead := {}

# What the scene is doing.
var scene_id := ""
var cls := "knight"
var overlay := false
var manual := false            # tests: they call advance() themselves
var auto := false              # lines move on by themselves (the setting; tests)
var follow_next := true        # play a scene's "next" straight after it
var finished := false
var waiting := ""              # line, time, class, name, hold, credits, fade_out, fade_in, drain, close, ""
var blips := 0                 # voice blips played (the tests count them)
var world: Node = null         # the level under an overlay
var then_cb := Callable()
var seen_before := false
var keeper_script: Script = null   # the calling chooser to host (tests set a stand-in); else keeper_screen.gd
# The oath chooses on the callings panel's own carved plinths (a card under
# each, the looked-at one's candle catching). Hosting the Keeper screen
# instead (true) covers the plinths with its alcoves, in another order; it's
# kept for a host that wants it. The map's Callings button opens the Keeper.
var host_keeper := false
# A replay (the Tales screen): no calling chooser, no boss cards or barks,
# and a dark backdrop behind shots with no panel.
var replay := false
# A hold completes at once (contract: "advance() completes a hold") when
# this is null and the scene runs headless or is stepped by hand (`manual`:
# the tests and the shot tools), as the chooser is answered there. True or
# false says so outright: tests that exercise the hold set it false.
var hold_instant = null
var hold_down := false         # tests: a finger on the screen
# The name entry answers Waxby at once when this is null and nobody types
# (name_is_instant); true or false says so outright (tests of the entry set
# it false).
var name_instant = null
var asked_id := ""             # the scene asked for, when REST_SUBS played another
# main's --autoplay=scene:<id> sets it: the lines (and a hold) go by themselves.
var auto_advance := false:
	set(v):
		auto_advance = v
		auto = v

var _scene := {}
var _shots: Array = []
var _shot := {}
var _shot_i := -1
var _beat_i := 0
var _class_done := true
var _name_done := true         # the hero has his name (or this scene never asks it)
var _clock := 0.0
var _wait_until := 0.0
var _last_tap := -1.0

# The world under an overlay, as it was.
var _grabbed := false
var _w_paused := false
var _t_input := true
var _t_visible := true
var _h_visible := true         # the level's HUD (hidden under the letterbox, as the pause menu does)

# The stage.
var _panel := {}
var _panel_id := ""
var _size := Vector2(1000, 460)
var _dark = null               # Color, or null for a panel lit all over
var _layers: Array = []        # {node, depth, lit, tex, def, rect}
var _figs := {}                # anchor -> {node, def, tex, look, p, depth, h, feet, frame, alpha, move, scale, scale_y, tw, ph}
var _lights := {}              # id -> {p, r, s, kind, h, col, depth, k, from, to, t, dur, fig, fp, ph}
var _actor: Node2D = null      # holder: the fake player and the rig
var _rig = null
var _fake = null
var _actor_def := {}           # {p, x, depth, h, walk}
var _cam := Vector3(0.5, 0.5, 1.0)
var _cam_from := Vector3(0.5, 0.5, 1.0)
var _cam_to := Vector3(0.5, 0.5, 1.0)
var _cam_t := 0.0
var _cam_dur := 0.0
var _chains: Array = []
var _motes: Array = []
var _motes_kind := ""
var _puffs: Array = []
var _flames: Array = []        # {p, h, seed, cold} or {p, eyes, r, gap, col}
var _ui_flames: Array = []
var _shake := 0.0
var _flash := 0.0
var _fade := 0.0
var _fade_goal := 0.0
var _lb := 0.0                 # letterbox, 0..1
var _lb_goal := 1.0
var _dim_k := 0.0
var _dim_goal := 0.0
var _dawn := {}
var _iris := {}
var _card := {}
var _boss := {}
var _credits := {}
var _hold := {}                # the hold cue while it waits: {light, into, t, prompt, nudge, nudge_at, idle, age, ...}
var _touch_ids := {}           # fingers down during a hold
var _mouse_down := false
var _key_down := false
var _streams: Array = []       # motes flying from a light to its target (the hold): {from, to, t, dur, seed}
var _field = null              # Plan B's light field (light_field.gd), when that plan runs
var _pending_shot := -1
var _close_phase := 0
var _lift := 0.0               # px the picture rises over the bottom bar while a shot has dialogue
var _shot_talks := false       # this shot has lines in the box
var _lift_on := false          # ...and the first has begun (then it stays up for the shot)

# The line being said.
var _line := {}
var _box_a := 0.0
var _box_goal := 0.0
var _box_shake := 0.0

# The calling chooser.
var _keeper = null             # keeper_screen.gd, when it exists
var _chooser := {}             # the built-in one: {sel, prompt, deny, t}
var _namer: Control = null     # the name entry while it asks
var _pill_armed := 0.0

var _stage: Node2D
var _glow = null
var _cold = null
var _fx: Node2D
var _ui: Control
var _ui_glow = null
var _dim: ColorRect
var _world_hidden: Array = []   # the level's layers hidden under an overlay's panel (_cover_world)
var _mat: ShaderMaterial
var _tex := {}                 # path -> Texture2D, loaded ahead of drawing
var _requested := {}           # paths asked for on a thread
var _rigdata_cache := {}
var _rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------- entry points

static func play_overlay(parent: Node, id: String, then: Callable) -> Node:
	## A beat over a level (world.play_beat) or a screen (the Chandler).
	## A headless world, the autoplay bot, or an unknown id just calls back.
	## A beat that is only barks hands them to the level and calls back.
	## While Mother Taper rests, a scene in REST_SUBS plays Hollin's instead.
	var asked := id
	id = Story.rest_sub(id)
	var sc := Story.scene(id)
	var lvl: Node = parent if parent != null and parent.has_method("play_beat") else null
	if sc.is_empty() or parent == null or not parent.is_inside_tree():
		then.call()
		return null
	if lvl != null and (bool(lvl.get("headless")) or (bool(lvl.get("autoplay")) and lvl.get("play_beats") != true)):
		then.call()
		return null
	if (sc.get("shots", []) as Array).is_empty():
		var g := Story._game()
		if g != null:
			g.mark_seen(id)
			g.mark_seen(asked)
			if Story.rest_base(id) != "":
				g.mark_seen(Story.rest_base(id))
		if lvl != null:
			queue_barks(lvl, sc.get("barks", []), float(sc.get("bark_delay", 0.8)))
		then.call()
		return null
	# Asked twice (a screen that plays its own first-visit beat, and main
	# too): one copy plays, and the second caller hears when it's over.
	var running := running_on(parent, id)
	if running != null:
		if then.is_valid() and not running.done.is_connected(then):
			running.done.connect(then, CONNECT_ONE_SHOT)
		return running
	var cs = load(SELF_PATH).new()
	cs.setup(id, then, true, lvl)
	cs.asked_id = asked
	if lvl != null and lvl.get("autoplay") == true:
		cs.auto_advance = true   # (main's --story: the bot's level, its lines by themselves)
	parent.add_child(cs)
	return cs


static func running_on(parent: Node, id: String) -> Node:
	## The scene `id` already playing on `parent`, or null.
	if parent == null:
		return null
	var ids := [id, Story.rest_sub(id)]
	for c in parent.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path == SELF_PATH and ids.has(str(c.get("scene_id"))) \
				and not bool(c.get("finished")) and not c.is_queued_for_deletion():
			return c
	return null


static func play_scene(parent: Node, id: String, then: Callable) -> Node:
	## A full-screen scene added to `parent`.
	if not Story.has_scene(Story.rest_sub(id)) or parent == null:
		then.call()
		return null
	var cs := make(id, then)
	parent.add_child(cs)
	return cs


static func make(id: String, then: Callable) -> Node:
	## A full-screen scene, not yet in the tree (main swaps it in).
	var cs = load(SELF_PATH).new()
	var asked := id
	cs.setup(Story.rest_sub(id), then, false, null)
	cs.asked_id = asked
	return cs


static func queue_barks(lvl: Node, keys: Array, delay := 0.8) -> Node:
	## Barks for the level's HUD, one at a time over live play.
	if lvl == null or keys.is_empty() or not lvl.has_method("bark"):
		return null
	var q := BarkQueue.new()
	q.name = "StoryBarks"
	q.world = lvl
	q.keys = keys.duplicate()
	q.wait = delay
	lvl.add_child(q)
	return q


func setup(id: String, then: Callable, as_overlay := false, lvl: Node = null) -> void:
	scene_id = id
	then_cb = then
	overlay = as_overlay
	world = lvl


# ---------------------------------------------------------------- building

func _g() -> Node:
	return get_node_or_null("/root/Game") if is_inside_tree() else Story._game()


func _ready() -> void:
	layer = 8
	_rng.seed = hash(scene_id)
	var g := _g()
	if g != null:
		cls = str(g.hero_id())
		if g.has_method("setting") and bool(g.setting("auto_advance")):
			auto = true
	if not Classes.ALL.has(cls):
		cls = "knight"
	_make_material()
	if overlay:
		_dim = ColorRect.new()
		_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dim.color = Color(UI.INK, 0.0)
		add_child(_dim)
	elif replay:
		# A tale replayed over the Tales screen: shots with no panel still
		# have the dark behind them.
		var bd := ColorRect.new()
		bd.name = "Backdrop"
		bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bd.color = UI.BG
		add_child(bd)
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_glow = GlowScript.new()
	_glow.draw.connect(_draw_flames.bind(false))
	add_child(_glow)
	_cold = GlowScript.new()
	_cold.modulate = COLD
	_cold.draw.connect(_draw_flames.bind(true))
	add_child(_cold)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_ui = Control.new()
	_ui.name = "UI"
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.draw.connect(_draw_ui)
	_ui.gui_input.connect(_on_ui_input)
	add_child(_ui)
	_ui_glow = GlowScript.new()
	_ui_glow.draw.connect(_draw_ui_flames)
	_ui.add_child(_ui_glow)
	if overlay:
		_grab_world()
	_fade = 0.0 if overlay else 1.0
	_begin_scene(scene_id)


func _process(dt: float) -> void:
	if not manual:
		advance(minf(dt, 0.1))


func _exit_tree() -> void:
	# Freed early (the level quit under us): never leave it paused and mute.
	_release_world()
	# Collect textures asked for ahead and never shown (a skip), so their
	# loads don't linger until the game quits.
	for p in _requested:
		ResourceLoader.load_threaded_get(p)
	_requested.clear()


static func _lit_shader() -> Shader:
	## The dark's field for a layer: darkness_lit.gdshader, the sibling of
	## darkness.gdshader (the same lights, tints, Hush lights and bands,
	## multiplying the layer's own colour). No string surgery.
	return LIT_SHADER


static func field_plan() -> String:
	## The cutscenes' render plan (world_lights.gd cutscene_field_mode():
	## "quarter" since the phone's GPU test, Plan B for cutscenes only), or
	## "full" (Plan A: darkness_lit.gdshader on every layer).
	if not ResourceLoader.exists(WORLD_LIGHTS):
		return "full"
	var wl = load(WORLD_LIGHTS)
	if wl == null:
		return "full"
	var fns := (wl as Script).get_script_method_list().map(func(m): return str(m["name"]))
	if fns.has("cutscene_field_mode"):
		return str(wl.cutscene_field_mode())
	if fns.has("field_mode"):
		return str(wl.field_mode())
	return "full"


func _make_material() -> void:
	## Plan A: one ShaderMaterial on darkness_lit.gdshader for every layer,
	## figure and the hero. Plan B: the bands of one reduced light field.
	var plan := field_plan()
	var scales := {"quarter": 0.25, "half": 0.5}
	if scales.has(plan) and ResourceLoader.exists(LIGHT_FIELD):
		_field = load(LIGHT_FIELD).new()
		_field.scale = float(scales[plan])
		add_child(_field)
		_mat = _field.make_bands_material(true)
		# Its field pass runs only once something is drawn lit (_use_mat): an
		# overlay of lines over a live level never pays for it.
		_field.viewport().render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_mat = ShaderMaterial.new()
	_mat.shader = _lit_shader()


func _use_mat(n: CanvasItem) -> void:
	## A layer, figure or the hero drawn lit: the shared material (Plan B's
	## field pass starts with the first of them).
	n.material = _mat
	if _field != null:
		_field.viewport().render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _mat_set(key: String, v) -> void:
	if _field != null:
		_field.set_param(key, v)
	else:
		_mat.set_shader_parameter(key, v)


static func manifest() -> Dictionary:
	## art/story/panels.json (from the story art), or {} while it's pending.
	if _manifest == null:
		_manifest = {}
		if FileAccess.file_exists(PANELS_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(PANELS_PATH))
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	if not _tex.has(path):
		if _requested.has(path):
			_tex[path] = ResourceLoader.load_threaded_get(path)
			_requested.erase(path)
		elif _ahead.has(path):
			_tex[path] = ResourceLoader.load_threaded_get(path)
			_ahead.erase(path)
		else:
			_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func shot_textures(shot: Dictionary) -> Array:
	## The textures a shot's picture is drawn with: its panel's layers and
	## the figures standing on it (from panels.json; none while it's pending).
	var out := []
	var m := manifest()
	var panels: Dictionary = m.get("panels", {})
	var pid := str(shot.get("panel", ""))
	if pid == "" or not panels.has(pid):
		return out
	for l in (panels[pid] as Dictionary).get("layers", []):
		out.append(str(l.get("tex", "")))
	var figures: Dictionary = m.get("figures", {})
	var figs: Dictionary = shot.get("figs", {})
	for a in figs:
		if figures.has(str(figs[a])):
			out.append(str((figures[str(figs[a])] as Dictionary).get("tex", "")))
	return out.filter(func(p): return p != "" and ResourceLoader.exists(p))


static func first_textures(id: String) -> Array:
	## The textures a scene's first picture needs (its first shot with a
	## panel that plays), or [] for a scene of lines only.
	for shot in Story.scene(Story.rest_sub(id)).get("shots", []):
		if (shot as Dictionary).has("panel") and shot_plays(shot):
			return shot_textures(shot)
	return []


static func shot_plays(shot: Dictionary) -> bool:
	## E2: a shot with "if" plays only with that flag set, one with "unless"
	## only without it (Story.flag).
	if shot.has("if") and not Story.flag(str(shot["if"])):
		return false
	if shot.has("unless") and Story.flag(str(shot["unless"])):
		return false
	return true


static func prefetch(ids: Array) -> void:
	## Ask for these scenes' first pictures on a thread, ahead of their
	## playing, so a scene doesn't stall the frame it opens in loading them
	## (a 3000 x 1800 layer is about 18 ms on the main thread): main asks for
	## a level's opening and boss beats as it builds, its closing scene during
	## the clear, the ending and a new world's opening while the results are
	## up, and the intro while the title is up. The scene takes them up when
	## it plays (the next shot is still asked for as each one starts).
	## Whatever was asked for before and isn't wanted now is let go, so
	## nothing lingers past the screen it was meant for.
	var want := {}
	for id in ids:
		for p in first_textures(str(id)):
			want[p] = true
	for p in _ahead.keys():
		if not want.has(p):
			ResourceLoader.load_threaded_get(p)
			_ahead.erase(p)
	for p in want:
		if not _ahead.has(p) and ResourceLoader.load_threaded_request(p) == OK:
			_ahead[p] = true


static func ahead() -> Array:
	## What prefetch has asked for and no scene has taken up yet (tests).
	return _ahead.keys()


func _panel_def(id: String) -> Dictionary:
	## The panel from panels.json, falling back to the stand-in stage for the
	## layers when a texture is missing (or for the whole panel).
	var m: Dictionary = manifest().get("panels", {})
	var fallback := Stage.panel(id)
	var plain := [{"depth": 1.0, "shapes": [["grad", "2a2038", "161020", 0, 460]]}]
	if not m.has(id):
		var fb := fallback.duplicate(true)
		if fb.is_empty():
			fb = {"size": [1000, 460], "dark": [0.3, 0.25, 0.42], "lights": {}, "anchors": {}, "layers": plain}
		fb["stand_in"] = true
		return fb
	var d: Dictionary = (m[id] as Dictionary).duplicate(true)
	var missing := false
	for l in d.get("layers", []):
		if not ResourceLoader.exists(str(l.get("tex", ""))):
			missing = true
	if missing:
		d["layers"] = fallback.get("layers", plain)
		d["stand_in"] = true
	for k in ["lights", "anchors"]:
		if not d.has(k):
			d[k] = fallback.get(k, {})
	# The stand-in's manifest-only additions the art hasn't caught up with
	# (v3: undercandle's grasp and under_warm, hush_eye's float): anchors it
	# lacks, and lights marked off (they stay dark until a cue lights them,
	# so nothing already drawn changes).
	var fl: Dictionary = fallback.get("lights", {})
	for lid in fl:
		if not (d["lights"] as Dictionary).has(lid) and bool((fl[lid] as Dictionary).get("off", false)):
			d["lights"][lid] = (fl[lid] as Dictionary).duplicate()
			d["lights"][lid]["extra"] = true
	var fa: Dictionary = fallback.get("anchors", {})
	for aid in fa:
		if not (d["anchors"] as Dictionary).has(aid):
			d["anchors"][aid] = fa[aid]
	return d


func _figure_def(id: String) -> Dictionary:
	## The figure from panels.json; its stand-in (look, flames and all, so
	## its lights sit on what is drawn) while its texture is missing.
	var m: Dictionary = manifest().get("figures", {})
	var stand := Stage.figure(id)
	var d: Dictionary = (m[id] as Dictionary).duplicate(true) if m.has(id) else stand
	if not ResourceLoader.exists(str(d.get("tex", ""))):
		d = stand.duplicate(true)
		d["tex"] = ""
	elif m.has(id):
		# Flames the stand-in adds, dark until lit (v3: the hush_eye's pupil),
		# that the art's manifest doesn't have yet.
		var sf: Dictionary = stand.get("flames", {})
		var sl: Dictionary = stand.get("light", {}) if stand.get("light", null) is Dictionary else {}
		if not (d.get("flames", null) is Dictionary):
			d["flames"] = {}
		if not (d.get("light", null) is Dictionary):
			d["light"] = {}
		for n in sf:
			if not (d["flames"] as Dictionary).has(n) and bool((sl.get(n, {}) as Dictionary).get("off", false)):
				d["flames"][n] = sf[n]
				d["light"][n] = (sl[n] as Dictionary).duplicate()
				d["light"][n]["extra"] = true
	if not d.has("frame"):
		d["frame"] = [256, 256]
	if not d.has("feet"):
		d["feet"] = stand["feet"]
	return d


# ---------------------------------------------------------------- the world under an overlay

func _grab_world() -> void:
	if world == null or _grabbed:
		return
	_grabbed = true
	_w_paused = bool(world.get("paused"))
	world.set("paused", true)
	var t = world.get("touch")
	if t != null:
		if t.has_method("release_all"):
			t.release_all()
		_t_input = t.is_processing_input()
		t.set_process_input(false)
		_t_visible = bool(t.get("visible_controls"))
		t.set("visible_controls", false)
	# The HUD (layer 5) is under the letterbox (layer 8): its top row would
	# be cut in half by the bar. Hidden until the beat is over.
	var h = world.get("hud")
	if h != null and "visible" in h:
		_h_visible = bool(h.visible)
		h.visible = false


func _cover_world(on: bool) -> void:
	## Under an overlay's panel (or its fade's black) the level can't be
	## seen: its layers stop drawing (the dark's full-field pass, the tiles,
	## the sprites, the glow), so the GPU pays for the scene alone (the int2
	## review: boss_3_before over the live 3-4 cost 3.4-4.1 ms against the
	## scene's 1.2-1.4). They're back as the panel goes, before the fade in.
	if world == null or not is_instance_valid(world) or on == not _world_hidden.is_empty():
		return
	if on:
		var keep := [self, world.get("hud"), world.get("touch"), world.get("pause_menu")]
		for c in world.get_children():
			if keep.has(c) or c is Camera2D:
				continue
			if (c is CanvasItem or c is CanvasLayer) and c.visible:
				_world_hidden.append(c)
				c.visible = false
	else:
		for c in _world_hidden:
			if is_instance_valid(c):
				c.visible = true
		_world_hidden.clear()


func world_covered() -> bool:
	## (tests) The level's layers are hidden under this overlay's panel.
	return not _world_hidden.is_empty()


func _release_world() -> void:
	_cover_world(false)
	if world == null or not _grabbed or not is_instance_valid(world):
		return
	_grabbed = false
	world.set("paused", _w_paused)
	var t = world.get("touch")
	if t != null and is_instance_valid(t):
		t.set_process_input(_t_input)
		t.set("visible_controls", _t_visible)
	var h = world.get("hud")
	if is_instance_valid(h) and "visible" in h:
		h.visible = _h_visible


# ---------------------------------------------------------------- scenes and shots

func _begin_scene(id: String) -> void:
	scene_id = id
	_scene = Story.scene(id)
	_shots = _scene.get("shots", [])
	_shot_i = -1
	_close_phase = 0
	var g := _g()
	seen_before = g != null and g.seen(id)
	_class_done = replay or not _has_choose()
	_name_done = replay or not _has_cue("choose_name")
	_lb_goal = 1.0
	if overlay:
		_dim_goal = 1.0
	if _scene.has("music"):
		_music(str(_scene["music"]))
	_next_shot()


func _has_choose() -> bool:
	return _has_cue("choose_class")


func _next_shot() -> void:
	_shot_i += 1
	while _shot_i < _shots.size() and not shot_plays(_shots[_shot_i]):
		_shot_i += 1
	if _shot_i >= _shots.size():
		_end_scene()
		return
	var shot: Dictionary = _shots[_shot_i]
	var kind: String = shot.get("in", "fade")
	var has_panel := shot.has("panel")
	if kind == "cut" or (not has_panel and _panel_id == "") or (kind == "fade" and _fade >= 0.999):
		_setup_shot(shot)
		if _fade > 0.0 and kind != "cut":
			_fade_goal = 0.0
			waiting = "fade_in"
		else:
			_fade = 0.0
			_fade_goal = 0.0
			_run()
	elif kind == "flash":
		_setup_shot(shot)
		_flash = 1.4
		_fade = 0.0
		_fade_goal = 0.0
		_run()
	else:
		_pending_shot = _shot_i
		_fade_goal = 1.0
		waiting = "fade_out"
	_preload(_shot_i + 1)


func _preload(i: int) -> void:
	## Ask for the next shot's textures early, on a thread. At the last shot
	## of a scene that plays on into another (homecoming into lullaby), the
	## next scene's first picture instead, so the hand-over doesn't load it
	## on the main thread.
	var paths := []
	if i < _shots.size():
		paths = shot_textures(_shots[i])
	else:
		var nxt := str(_scene.get("next", ""))
		if follow_next and nxt != "" and Story.has_scene(nxt):
			paths = first_textures(nxt)
	for p in paths:
		if not _tex.has(p) and not _requested.has(p) and not _ahead.has(p):
			if ResourceLoader.load_threaded_request(p) == OK:
				_requested[p] = true


func _ask_faces(shot: Dictionary) -> void:
	for b in shot.get("beats", []):
		if not Story.is_line(b):
			continue
		var r: Dictionary = Story.resolve(b, cls)
		if str(r.get("who", "")) == "wick":
			continue
		_ask(Story.portrait_path(str(r["who"]), str(r["mood"]), cls))


func _ask(p: String) -> void:
	## A texture on a thread, taken up by _load_tex when it's drawn.
	if p == "" or _tex.has(p) or _requested.has(p) or _ahead.has(p) or not ResourceLoader.exists(p):
		return
	if ResourceLoader.load_threaded_request(p) == OK:
		_requested[p] = true


func _prune_tex(keep_paths: Array) -> void:
	## Spec §6.6 (at most two panels resident): the story sets and figures
	## not in keep_paths are let go (freed once the stage's nodes holding
	## them are); portraits and the hero's parts, small, stay for the scene.
	var keep := {}
	for p in keep_paths:
		keep[str(p)] = true
	for p in _tex.keys():
		var sp := str(p)
		if not keep.has(sp) and (sp.begins_with("res://art/story/sets/") or sp.begins_with("res://art/story/figures/")):
			_tex.erase(p)


func resident() -> Array:
	## The story sets and figures this scene holds now (tests).
	return _tex.keys().filter(func(p): return str(p).begins_with("res://art/story/sets/") or str(p).begins_with("res://art/story/figures/"))


func _clear_stage() -> void:
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
	_layers.clear()
	_figs.clear()
	_lights.clear()
	_chains.clear()
	_puffs.clear()
	_actor = null
	_rig = null
	_fake = null
	_actor_def = {}
	_panel = {}
	_panel_id = ""
	_dark = null
	_dawn = {}
	_iris = {}


func _setup_shot(shot: Dictionary) -> void:
	_clear_stage()
	# This shot's picture and the next's stay; the ones before are let go.
	var keep := shot_textures(shot)
	if _shot_i + 1 < _shots.size():
		keep.append_array(shot_textures(_shots[_shot_i + 1]))
	_prune_tex(keep)
	# Its speakers' faces (and the next shot's) on a thread now, so a line
	# never loads its portrait on the frame it starts (the rev5 review:
	# homecoming's taper_stern cost a 172 ms frame).
	_ask_faces(shot)
	if _shot_i + 1 < _shots.size():
		_ask_faces(_shots[_shot_i + 1])
	_shot = shot
	_beat_i = 0
	_panel_id = str(shot.get("panel", ""))
	if _panel_id != "":
		_build_panel(shot)
	var cam: Array = shot.get("cam", [])
	_cam = _v3(cam[0]) if cam.size() > 0 else Vector3(0.5, 0.5, 1.0)
	_cam_from = _cam
	_cam_to = _v3(cam[1]) if cam.size() > 1 else _cam
	_cam_t = 0.0
	_cam_dur = float(shot.get("time", 0.0))
	_shot_talks = false
	for b in shot.get("beats", []):
		if Story.is_line(b) and str(Story.speaker(str(b[0]).get_slice(":", 0), cls)["style"]) == "box":
			_shot_talks = true
	_lift_on = false
	var first = shot.get("beats", [null])[0] if not shot.get("beats", []).is_empty() else null
	if _shot_talks and Story.is_line(first) and str(Story.speaker(str(first[0]).get_slice(":", 0), cls)["style"]) == "box":
		_lift_on = true
	_lift = _lift_goal() if _fade > 0.5 or _panel_id == "" else _lift
	var motes := str(shot.get("motes", _panel.get("motes", "") if _panel_id != "" else ""))
	_init_motes(motes if motes != "<null>" else "")
	if shot.has("music"):
		_music(str(shot["music"]))
	_apply_stage(0.0)


func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]) if (a as Array).size() > 2 else 1.0)


func _arr2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _build_panel(shot: Dictionary) -> void:
	_panel = _panel_def(_panel_id)
	var sz: Array = _panel.get("size", [1000, 460])
	_size = Vector2(float(sz[0]), float(sz[1]))
	var dk = _panel.get("dark", null)
	_dark = Color(float(dk[0]), float(dk[1]), float(dk[2])) if dk is Array else null
	# Everything drawn far to near: the layers, and the figures at their depth.
	var items := []   # [depth, order, kind, data]
	var order := 0
	for l in _panel.get("layers", []):
		items.append([float(l.get("depth", 1.0)), order, "layer", l])
		order += 1
	var anchors: Dictionary = _panel.get("anchors", {})
	var figs: Dictionary = shot.get("figs", {})
	var nowhere := {"p": [_size.x * 0.5, _size.y * 0.9], "depth": 1.0}
	for a in figs:
		var ad: Dictionary = anchors.get(a, nowhere)
		items.append([float(ad.get("depth", 1.0)) + 0.001, order, "fig", [a, str(figs[a]), ad]])
		order += 1
	var actor_anchor := str(shot.get("actor", ""))
	if actor_anchor != "":
		var ad: Dictionary = anchors.get(actor_anchor, nowhere)
		items.append([float(ad.get("depth", 1.0)) + 0.002, order, "actor", ad])
	items.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var lights: Dictionary = _panel.get("lights", {})
	for id in lights:
		var L: Dictionary = lights[id]
		# A stand-in addition the art lacks takes no draw from the shot's
		# random numbers, so everything else flickers as it always did.
		var keep_rng := _rng.state
		_lights[id] = _new_light(_arr2(L.get("p", [0, 0])), float(L.get("r", 100)), float(L.get("s", 0.8)),
				str(L.get("kind", "flame")), float(L.get("h", 0.0)), float(L.get("depth", 1.0)), str(L.get("color", "")))
		_lights[id]["hush"] = bool(L.get("hush", false))
		if bool(L.get("extra", false)):
			_rng.state = keep_rng
	for it in items:
		match it[2]:
			"layer":
				_add_layer(it[3])
			"fig":
				_add_figure(it[3][0], it[3][1], it[3][2])
			"actor":
				_add_actor(it[3], figs)
	# How the shot starts: the panel's "off" lights dark (E6: a figure's are
	# set as it's added), the shot's lights_off out, its lights_on lit, then
	# the ones it sets low; figures hidden.
	for id in lights:
		if bool((lights[id] as Dictionary).get("off", false)):
			_set_light(id, 0.0)
	for id in shot.get("lights_off", []):
		_set_light(id, 0.0)
	for id in shot.get("lights_on", []):
		_set_light(id, 1.0)
	var lr: Dictionary = shot.get("light_r", {})
	for id in lr:
		_set_light(id, float(lr[id]))
	if actor_anchor != "" and not bool(shot.get("actor_lit", true)):
		_set_light("actor", 0.0)
	var fa: Dictionary = shot.get("fig_alpha", {})
	for a in fa:
		if _figs.has(a):
			_figs[a]["alpha"] = float(fa[a])


func _new_light(p: Vector2, r: float, s: float, kind: String, h: float, depth := 1.0, col := "") -> Dictionary:
	return {"p": p, "r": r, "s": s, "kind": kind, "h": h, "depth": depth, "col": col, "k": 1.0, "from": 1.0, "to": 1.0,
			"t": 0.0, "dur": 0.0, "fig": "", "fp": Vector2.ZERO, "ph": _rng.randf() * TAU, "hush": false}


func _add_layer(l: Dictionary) -> void:
	var n := Node2D.new()
	var lit := bool(l.get("lit", false)) or _dark == null
	var tex := _load_tex(str(l.get("tex", "")))
	var depth := float(l.get("depth", 1.0))
	var rect := Rect2(Vector2.ZERO, _size)
	if l.has("rect"):
		var rr: Array = l["rect"]
		rect = Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3]))
	elif depth > 1.0:
		# Near layers are drawn 10% larger on every side, so parallax never
		# shows their edges.
		rect = rect.grow_individual(_size.x * 0.1, _size.y * 0.1, _size.x * 0.1, _size.y * 0.1)
	if not lit:
		_use_mat(n)
	var rec := {"node": n, "depth": depth, "lit": lit, "tex": tex, "def": l, "rect": rect}
	n.draw.connect(_draw_layer.bind(rec))
	_stage.add_child(n)
	_layers.append(rec)


func _draw_layer(rec: Dictionary) -> void:
	var n: Node2D = rec["node"]
	if rec["tex"] != null:
		n.draw_texture_rect(rec["tex"], rec["rect"], false)
	else:
		Stage.draw_layer(n, rec["def"])


func _add_figure(anchor: String, fig_id: String, ad: Dictionary) -> void:
	var d := _figure_def(fig_id)
	var n := Node2D.new()
	if _dark != null:
		_use_mat(n)
	_stage.add_child(n)
	var frame := _arr2(d["frame"])
	# A placement's own size (a far-off figure is smaller) wins over the figure's.
	var h := float(ad.get("h", d.get("h", 150.0)))
	var f := {"node": n, "id": fig_id, "def": d, "tex": _load_tex(str(d.get("tex", ""))), "look": str(d.get("look", "")),
			"p": _arr2(ad.get("p", [500, 420])), "depth": float(ad.get("depth", 1.0)), "h": h,
			"feet": _arr2(d["feet"]), "frame": frame, "alpha": 1.0, "move": Vector2.ZERO, "scale": 1.0, "scale_y": 1.0,
			"flip": bool(ad.get("flip", false)), "tw": {}, "ph": _rng.randf() * TAU}
	n.draw.connect(_draw_figure.bind(anchor))
	_figs[anchor] = f
	_add_fig_lights(anchor, d)


# Eye-lights by figure when the art gives no colour (spec §7.4).
const EYE_COLORS := {"tollgrave_boss": "7ef0c8", "tollgrave_sit": "f7b64a", "snuffer_stand": "e8e4ff",
	"snuffer_reach": "e8e4ff", "moth_swarm": "d8e8c8"}


static func fig_light(fig_id: String, name: String, e, ld) -> Dictionary:
	## One of a figure's flames as a light record, in its frame's units:
	## {fp, h, kind, r, s, col, pts, dot}. `e` is its flames entry ([x, y, h],
	## or the older [x, y, h, kind, colour] or {p, h, kind, color}); `ld` is
	## its entry in the figure's "light" (kind, r, s, color, and for eyes the
	## two pupils pts and their radius dot), or null.
	var out := {"fp": Vector2(128, 60), "h": 5.0, "kind": "eyes" if name == "eyes" else "flame", "col": "", "pts": [], "dot": 0.0}
	if e is Array and e.size() >= 2:
		out["fp"] = Vector2(_num(e[0], 128.0), _num(e[1], 60.0))
		out["h"] = _num(e[2], 5.0) if e.size() > 2 else 5.0
		if e.size() > 3:
			out["kind"] = str(e[3])
		if e.size() > 4:
			out["col"] = str(e[4])
	elif e is Dictionary:
		var p = e.get("p", null)
		if p is Array and p.size() >= 2:
			out["fp"] = Vector2(_num(p[0], 128.0), _num(p[1], 60.0))
		out["h"] = _num(e.get("h", null), 5.0)
		if e.get("kind", null) != null:
			out["kind"] = str(e["kind"])
		if e.get("color", null) != null:
			out["col"] = str(e["color"])
	var eyes: bool = out["kind"] == "eyes"
	out["r"] = float(out["h"]) * (10.0 if eyes else 14.0)
	out["s"] = 0.55 if eyes else 0.9
	if ld is Dictionary:
		if ld.get("kind", null) != null:
			out["kind"] = str(ld["kind"])
		eyes = out["kind"] == "eyes"
		out["r"] = _num(ld.get("r", null), out["r"])
		out["s"] = _num(ld.get("s", null), out["s"])
		if ld.get("color", null) != null:
			out["col"] = str(ld["color"])
		var pts = ld.get("pts", null)
		if pts is Array:
			for p in pts:
				if p is Array and p.size() >= 2:
					out["pts"].append(Vector2(_num(p[0], 128.0), _num(p[1], 60.0)))
		out["dot"] = _num(ld.get("dot", null), 0.0)
	if eyes:
		if out["col"] == "":
			out["col"] = EYE_COLORS.get(fig_id, "f7b64a")
		if (out["pts"] as Array).is_empty():
			# No pupils given: two, a little apart, either side of the point.
			var gap: float = float(out["h"]) * 1.8
			out["pts"] = [out["fp"] - Vector2(gap * 0.5, 0.0), out["fp"] + Vector2(gap * 0.5, 0.0)]
		if out["dot"] <= 0.0:
			out["dot"] = maxf(float(out["h"]) * 0.4, 1.2)
	return out


static func _num(v, fallback: float) -> float:
	## A number from JSON, or the fallback for a null or a non-number.
	return float(v) if v is float or v is int else fallback


func _add_fig_lights(anchor: String, d: Dictionary) -> void:
	## A figure's flames are lights named "<anchor>.<flame>".
	var fl: Dictionary = d.get("flames", {})
	var lights: Dictionary = d.get("light", {}) if d.get("light", null) is Dictionary else {}
	for name in fl:
		var ld = lights.get(name, null)
		var r := fig_light(str(_figs[anchor]["id"]), str(name), fl[name], ld)
		var id := "%s.%s" % [anchor, name]
		# E6: a flame marked off starts dark (the art's "off" in its light,
		# or in a flame given as a dictionary).
		var off: bool = (ld is Dictionary and bool(ld.get("off", false))) or (fl[name] is Dictionary and bool(fl[name].get("off", false)))
		var keep: float = _lights[id]["k"] if _lights.has(id) else (0.0 if off else 1.0)
		var keep_rng := _rng.state
		var L := _new_light(Vector2.ZERO, r["r"], r["s"], r["kind"], r["h"], 1.0, r["col"])
		if ld is Dictionary and bool(ld.get("extra", false)):
			_rng.state = keep_rng
		L["fig"] = anchor
		L["fp"] = r["fp"]
		L["pts"] = r["pts"]
		L["dot"] = r["dot"]
		L["k"] = keep
		L["from"] = keep
		L["to"] = keep
		L["hush"] = ld is Dictionary and bool(ld.get("hush", false))
		_lights[id] = L


func _draw_figure(anchor: String) -> void:
	if not _figs.has(anchor):
		return
	var f: Dictionary = _figs[anchor]
	var n: Node2D = f["node"]
	n.draw_set_transform(-f["feet"], 0.0, Vector2.ONE)
	if f["tex"] != null:
		n.draw_texture_rect(f["tex"], Rect2(Vector2.ZERO, f["frame"]), false)
	else:
		Stage.draw_figure(n, f["look"], _clock)


func _add_actor(ad: Dictionary, figs: Dictionary) -> void:
	## The hero's own rig, standing on the anchor, candle and all.
	_actor = Node2D.new()
	_actor.name = "Actor"
	if _dark != null:
		_use_mat(_actor)
	_fake = PlayerScript.new()
	_fake.on_floor = true
	_fake.hurt_time = 10.0
	_actor.add_child(_fake)
	_rig = RigScript.new()
	_rig.cls = cls
	_rig.player = _fake
	_actor.add_child(_rig)
	_stage.add_child(_actor)
	_rig.use_parent_material = true
	for c in _all_children(_rig):
		c.use_parent_material = true
	var p := _arr2(ad.get("p", [500, 420]))
	_actor_def = {"p": p, "x": p.x, "depth": float(ad.get("depth", 1.0)), "h": float(ad.get("h", 120.0)), "walk": {}}
	# Face whoever shares the shot (or the middle of the panel).
	var target := _size.x * 0.5
	var best := INF
	var anchors: Dictionary = _panel.get("anchors", {})
	for a in figs:
		var fx: float = _arr2(anchors.get(a, {"p": [target, 0]})["p"]).x
		if absf(fx - p.x) < best and absf(fx - p.x) > 1.0:
			best = absf(fx - p.x)
			target = fx
	_fake.facing = 1 if target >= p.x else -1
	# The anchor's own hint wins (a "walk" or "face" cue can still turn him).
	if ad.get("face", null) != null:
		_fake.facing = 1 if float(ad["face"]) >= 0.0 else -1
	_lights["actor"] = _new_light(Vector2.ZERO, _actor_def["h"] * 1.6, 0.95, "actor", 19.0)


func _all_children(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out


# ---------------------------------------------------------------- the camera and the stage transform

func _vs() -> Vector2:
	if not is_inside_tree():
		return Vector2(844, 390)
	return get_viewport().get_visible_rect().size


func _xf(depth: float) -> Array:
	## [position, scale] of the panel plane at `depth`, lifted over the box.
	var x := _xf_raw(depth)
	return [x[0] - Vector2(0.0, _lift), x[1]]


func _lift_goal() -> float:
	## How far the picture must rise for every face on stage to clear the
	## dialogue box (the space it leaves below is under the bottom bar).
	if not _shot_talks or not _lift_on or _panel_id == "":
		return 0.0
	# The shot's last word said: the picture settles back down.
	if not (waiting == "line" and str(_line.get("style", "")) == "box") and not _box_lines_left():
		return 0.0
	var top := _safe().end.y - 6.0 - 96.0
	var need := 0.0
	for a in _figs:
		var f: Dictionary = _figs[a]
		if f["alpha"] < 0.1:
			continue
		var x := _xf_raw(f["depth"])
		var face: Vector2 = f["p"] + f["move"] - Vector2(0.0, f["h"] * 0.55 * f["scale"])
		need = maxf(need, (x[0] + face * float(x[1])).y + 20.0 - top)
	if not _actor_def.is_empty():
		var x := _xf_raw(_actor_def["depth"])
		var face := Vector2(_actor_def["x"], _actor_def["p"].y - _actor_def["h"] * 0.47)
		need = maxf(need, (x[0] + face * float(x[1])).y + 20.0 - top)
	return clampf(need, 0.0, LIFT_MAX)


func _box_lines_left() -> bool:
	## A line for the box still to come in this shot.
	var beats: Array = _shot.get("beats", [])
	for i in range(_beat_i, beats.size()):
		if Story.is_line(beats[i]) and str(Story.speaker(str(beats[i][0]).get_slice(":", 0), cls)["style"]) == "box":
			return true
	return false


func _xf_raw(depth: float) -> Array:
	## [position, scale] of the panel plane at `depth` (spec §7.2).
	var vs := _vs()
	var s0 := maxf(vs.x / _size.x, vs.y / _size.y)
	var z := maxf(_cam.z, 1.0)
	var hv := vs / (2.0 * s0 * z)
	var c := Vector2(_cam.x * _size.x, _cam.y * _size.y)
	# A slow handheld drift, a few tenths of a percent of the view. It stays
	# inside the panel (clamped after, so no edge of it shows), and it only
	# ever looks down, never up: a far layer that stops at the floor line
	# (the belfry's wall, the chapel's) then stays tucked behind the near one.
	c += Vector2(sin(_clock * 0.31), 0.5 + 0.5 * sin(_clock * 0.23 + 1.3)) * vs * 0.004 / s0
	c.x = _size.x * 0.5 if hv.x * 2.0 >= _size.x else clampf(c.x, hv.x, _size.x - hv.x)
	c.y = _size.y * 0.5 if hv.y * 2.0 >= _size.y else clampf(c.y, hv.y, _size.y - hv.y)
	var P := _size * 0.5
	var sd := s0 * (1.0 + (z - 1.0) * depth) * _shake_zoom(vs)
	var cd := P + (c - P) * depth
	return [vs * 0.5 - cd * sd + _shake_off(), sd]


func _shake_zoom(vs: Vector2) -> float:
	## While the picture shakes it is pushed in just enough that its edges
	## never show at the sides (or past the letterbox bars).
	if _shake <= 0.05:
		return 1.0
	return 1.0 + maxf(2.0 * _shake / vs.x, 2.0 * maxf(_shake - LETTERBOX * _lb, 0.0) / vs.y)


func _shake_off() -> Vector2:
	if _shake <= 0.05:
		return Vector2.ZERO
	return Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * _shake


func _to_screen(p: Vector2, depth: float) -> Vector2:
	var x := _xf(depth)
	return x[0] + p * float(x[1])


func _apply_stage(dt: float) -> void:
	if _panel_id == "":
		return
	for rec in _layers:
		var x := _xf(rec["depth"])
		var n: Node2D = rec["node"]
		n.position = x[0]
		n.scale = Vector2(x[1], x[1])
	for a in _figs:
		var f: Dictionary = _figs[a]
		var x := _xf(f["depth"])
		var n: Node2D = f["node"]
		var k: float = float(x[1]) * f["h"] / f["frame"].y * f["scale"]
		var breath := 1.0 + 0.012 * sin(_clock * 2.2 + f["ph"])
		n.position = x[0] + (f["p"] + f["move"]) * float(x[1])
		# A flipped figure is mirrored about its feet.
		n.scale = Vector2(-k if f["flip"] else k, k * breath * f["scale_y"])
		n.modulate.a = clampf(f["alpha"], 0.0, 1.0)
		n.visible = f["alpha"] > 0.004
		if f["tex"] == null:
			n.queue_redraw()
	if _actor != null:
		var x := _xf(_actor_def["depth"])
		var k: float = float(x[1]) * _actor_def["h"] / 64.0
		_actor.position = x[0] + Vector2(_actor_def["x"], _actor_def["p"].y) * float(x[1])
		_actor.scale = Vector2(k, k)
		if manual and _rig != null:
			_rig._process(dt)


# ---------------------------------------------------------------- running beats

func _run() -> void:
	## Beats until one holds: a line, a wait, the chooser, the credits.
	var beats: Array = _shot.get("beats", [])
	while _beat_i < beats.size():
		var b = beats[_beat_i]
		_beat_i += 1
		if Story.is_line(b):
			_start_line(b)
			return
		# A cue with "if" runs only with that flag set (lullaby's Descent card).
		if b is Dictionary and b.has("if") and not Story.flag(str(b["if"])):
			continue
		if b is Dictionary and _cue(b):
			if waiting != "name":   # (the question stays up while the name is asked)
				_hide_line()
			return
	_hide_line()
	_next_shot()


func _start_line(b: Array, nudge := false) -> void:
	## A line: typed into the box, told by the narrator, or the Hush's own
	## letters. A nudge (the hold's) shows while the scene still waits on it.
	var r := Story.resolve(b, cls)
	var sp := Story.speaker(r["who"], cls)
	if r["who"] == "wick" and not _name_done:
		sp["name"] = ""   # (the oath: no name yet, till Taper asks it)
	var style: String = sp["style"]
	var text: String = r["text"]
	if style == "hush":
		text = text.to_lower()
	var f: Font
	var size := 18
	var width := 600.0
	var vs := _vs()
	match style:
		"narrate":
			f = UI.font("title", 700)
			size = 23
			width = vs.x * 0.8
		"hush":
			f = UI.font("title", 600)
			size = 26
			width = vs.x * 0.8
		_:
			f = UI.font("body", 600)
			size = 22 if r["shout"] else 18
			width = _box_text_width()
	_line = {"who": r["who"], "mood": r["mood"], "text": text, "style": style, "shout": r["shout"], "sp": sp, "at": r.get("at", ""),
			"t": 0.0, "shown": 0, "acc": 0.0, "nonspace": 0, "done": false, "hold": 0.0,
			"wrap": _wrap(text, f, size, width), "font": f, "size": size, "start": _clock, "shown_line": true, "nudge": nudge}
	_preload_portrait(r["who"], r["mood"])
	_box_goal = 1.0 if style == "box" else 0.0
	if style == "box":
		_lift_on = true
	if r["shout"]:
		_box_shake = 0.25
		_shake = maxf(_shake, 4.0)
		_haptic(20)
	if style == "hush":
		var s := _sfx_node()
		if s != null:
			s.duck_music(10.0, text.length() / HUSH_CPS + 2.5)
	if not nudge:
		waiting = "line"


func _hide_line() -> void:
	if not _line.is_empty():
		_line["shown_line"] = false
	_box_goal = 0.0


func _box_text_width() -> float:
	return _safe().size.x - 24.0 - 124.0 - 24.0


func _wrap(text: String, f: Font, size: int, width: float) -> PackedStringArray:
	## Words into lines no wider than `width`. Two lines are balanced (the
	## break that evens them out), so a line never ends on one lonely word.
	var out := PackedStringArray()
	var cur := ""
	var words := text.split(" ")
	for w in words:
		var t := w if cur == "" else cur + " " + w
		if cur != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(cur)
			cur = w
		else:
			cur = t
	if cur != "":
		out.append(cur)
	if out.size() == 2:
		var best := INF
		for i in range(1, words.size()):
			var a := " ".join(words.slice(0, i))
			var b := " ".join(words.slice(i))
			var wa := f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var wb := f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if wa <= width and wb <= width and maxf(wa, wb) < best:
				best = maxf(wa, wb)
				out = PackedStringArray([a, b])
	return out


func _line_len() -> int:
	return (_line.get("text", "") as String).length()


func _update_line(dt: float) -> void:
	if _line.is_empty() or not (waiting == "line" or (waiting == "hold" and bool(_line.get("nudge", false)))):
		return
	_line["t"] += dt
	if not _line["done"]:
		match _line["style"]:
			"narrate":
				var words: int = (_line["text"] as String).split(" ").size()
				_line["shown"] = _line_len()
				if _line["t"] >= words * 0.06 + 0.3:
					_line["done"] = true
			"hush":
				_type(dt, 1.0 / HUSH_CPS, false)
			_:
				_type(dt, 1.0 / CPS, true)
	elif auto and waiting == "line":
		_line["hold"] += dt
		if _line["hold"] >= 1.2 + 0.035 * _line_len():
			_advance_line()


func _type(dt: float, step: float, voice: bool) -> void:
	## The typewriter: a pause after . ! ? and after a comma, and a voice
	## blip on every third letter.
	var text: String = _line["text"]
	_line["acc"] += dt
	while _line["acc"] >= step and _line["shown"] < text.length():
		_line["acc"] -= step
		var ch := text[_line["shown"]]
		_line["shown"] += 1
		if ".!?".contains(ch):
			_line["acc"] -= 0.18
		elif ch == ",":
			_line["acc"] -= 0.08
		if ch != " ":
			_line["nonspace"] += 1
			if voice and _line["nonspace"] % 3 == 1:
				_blip()
	if _line["shown"] >= text.length():
		_line["done"] = true


func _blip() -> void:
	## A voice blip in key: one of the five notes of D minor pentatonic
	## counting up from the one nearest the speaker's voice (Sfx.voice_note),
	## so every speaker sings in their own register and on the music's scale.
	blips += 1
	var sp: Dictionary = _line["sp"]
	var voice: float = sp["voice"]
	var blip: String = sp.get("blip", "")
	if voice <= 0.0 or blip == "":
		return
	var s := _sfx_node()
	if s == null:
		return
	_sfx(blip, blip_pitch(s, voice, _rng.randi() % 5), 0.7)


static func blip_pitch(s: Object, voice: float, i: int) -> float:
	## The pitch of a voice's i-th blip note: Sfx.voice_note when it has it,
	## else the voice times the scale's step (the older, looser way).
	if s == null or voice <= 0.0:
		return voice
	if s.has_method("voice_note"):
		return float(s.voice_note(voice, i))
	return voice * float(s.note(i)) / float(s.note(0))


func _finish_typing() -> void:
	_line["shown"] = _line_len()
	_line["done"] = true
	_line["t"] = maxf(_line["t"], 10.0)


func _advance_line() -> void:
	waiting = ""
	_run()


func tap() -> void:
	## A tap anywhere (or jump, attack, Enter): finish the line, or go on.
	## Waits don't skip; the credits speed up.
	if finished:
		return
	match waiting:
		"line":
			if _clock - float(_line.get("start", 0.0)) < GUARD:
				return
			if not _line["done"]:
				_finish_typing()
			else:
				_advance_line()
		"credits":
			_credits["fast"] = true


# ---------------------------------------------------------------- cues

func _cue(b: Dictionary) -> bool:
	## Runs one cue; true when the scene now waits on it.
	var t := float(b.get("t", 0.0))
	match str(b.get("do", "")):
		"wait":
			_wait_until = _clock + t
			waiting = "time"
			return true
		"cam":
			_cam_from = _cam
			_cam_to = _v3(b["to"])
			_cam_t = 0.0
			_cam_dur = maxf(t, 0.001)
		"snuff":
			_snuff(str(b["light"]))
		"ignite":
			_ignite(str(b["light"]), 0)
		"light":
			_tween_light(str(b["light"]), float(b["r"]), t)
		"chain":
			_chains.append({"lights": b["lights"], "gap": float(b.get("gap", 0.3)), "sfx": str(b.get("sfx", "")), "i": 0, "t": 0.0,
					"snuff": bool(b.get("snuff", false))})
		"fig":
			var a := str(b["fig"])
			if _figs.has(a):
				var f: Dictionary = _figs[a]
				var tw := {"t": 0.0, "dur": t}
				for k in ["alpha", "scale", "scale_y"]:
					if b.has(k):
						tw[k] = [f[k], float(b[k])]
				if b.has("move"):
					tw["move"] = [f["move"], f["move"] + _arr2(b["move"])]
				f["tw"] = tw
				if t <= 0.0:
					_step_fig(f, 0.0)
		"pose":
			_pose(str(b["fig"]), str(b["frame"]))
		"walk":
			if _actor != null:
				var to := float(b["to"]) * _size.x
				_actor_def["walk"] = {"from": _actor_def["x"], "to": to, "t": 0.0, "dur": maxf(t, 0.05)}
				_fake.facing = 1 if to >= _actor_def["x"] else -1
		"face":
			if _fake != null:
				var d = b["dir"]
				_fake.facing = (-1 if str(d) == "left" else 1) if d is String else (1 if float(d) >= 0.0 else -1)
		"mood":
			if _rig != null:
				_rig.mood = str(b["mood"])
		"burst":
			_glow.burst(_point_of(str(b["at"])), int(b.get("n", 20)), Color(str(b.get("color", "ffd84a"))), 150.0, 0.7, 120.0, 2.6, 60.0)
		"shake":
			_shake = maxf(_shake, float(b["amt"]))
		"flash":
			_flash = 1.4
		"sfx":
			_sfx(str(b["name"]), float(b.get("pitch", 1.0)), clampf(float(b.get("vol", 1.0)), 0.0, 1.0))
		"music":
			_music(str(b["track"]))
		"haptic":
			_haptic(int(b["ms"]))
		"dawn":
			_dawn = {"t": 0.0, "dur": maxf(t, 0.01)}
		"iris":
			_iris = {"light": str(b["on"]), "t": 0.0, "dur": maxf(t, 0.01)}
		"card":
			_card = {"sub": str(b["sub"]), "title": str(b["title"]), "at": str(b.get("at", "")), "t": 0.0}
		"boss_card":
			var tag := str(b.get("portrait", ""))
			_boss = {"name": str(b["name"]), "title": str(b["title"]), "who": tag.get_slice(":", 0),
					"mood": tag.get_slice(":", 1) if tag.contains(":") else "", "t": 0.0}
			_preload_portrait(_boss["who"], _boss["mood"])
			_sfx("bell", 0.5)
			_sfx("boss_roar")
			_haptic(50)
			_mark_boss_card()
		"choose_class":
			if replay:
				return false
			_open_chooser(str(b.get("prompt", "Choose your calling")))
			return true
		"choose_name":
			if replay:
				return false
			return _open_namer(str(b.get("prompt", NameEntry.PROMPT)))
		"credits":
			_credits = {"t": 0.0, "cast_t": 0.0, "fast": false, "embers": []}
			# The cast roll's faces: their 128 px copies (drawn at r 26), asked
			# for on a thread while v2's credit lines run (the rev5 review: all
			# fourteen 768 px portraits loaded on one frame, 910-1281 ms, and
			# +38 MB past the 160 MB ceiling).
			for page in Story.CAST_ROLL:
				for pe in page["people"]:
					if str(pe[0]) == "wick":
						_preload_portrait(str(pe[0]), str(pe[1]))
					else:
						_ask(UI.hud_face(Story.portrait_path(str(pe[0]), str(pe[1]), cls)))
			_lift_on = false
			waiting = "credits"
			return true
		"hold":
			return _start_hold(b)
	return false


func _snuff(id: String) -> void:
	_tween_light(id, 0.0, 0.4)
	if _lights.has(id):
		_puffs.append({"id": id, "t": 0.0})
	_sfx("snuff", 1.0, 0.6)


# ---------------------------------------------------------------- the hold (E1)

func _start_hold(b: Dictionary) -> bool:
	## Hold anywhere but Skip (a finger, or jump, attack or Space): the light
	## drains to nothing over t seconds of held time (letting go pauses it),
	## its motes streaming to `into`; after nudge_at idle seconds the nudge
	## line says its piece once. Headless it completes at once; with the
	## auto-advance setting it holds by itself after HOLD_AUTO seconds.
	var id := str(b["light"])
	_touch_ids.clear()
	_mouse_down = false
	_key_down = false
	if hold_is_instant() or not _lights.has(id):
		_hold = {"light": id}
		_hold_done(false)
		return false
	var nd = b.get("nudge", [])
	_hold = {"light": id, "into": str(b.get("into", "")), "t": maxf(float(b.get("t", 3.0)), 0.1),
			"prompt": str(b.get("prompt", "Hold to give your flame")), "nudge": nd if nd is Array else [],
			"nudge_at": float(b.get("nudge_at", 8.0)), "idle": 0.0, "age": 0.0, "nudged": false, "pulse": 0.0,
			"stream": 0.0, "tick": 0.0, "give": 0.0}
	_lift_on = false
	waiting = "hold"
	return true


func hold_is_instant() -> bool:
	if hold_instant == null:
		return manual or DisplayServer.get_name() == "headless"
	return bool(hold_instant)


func holding() -> bool:
	## A finger, the mouse, a key (or a test's hold_down) is on the hold.
	return hold_down or _mouse_down or _key_down or not _touch_ids.is_empty()


func hold_left() -> float:
	## How much of the held light is left (1 to 0), or -1 with no hold up.
	if _hold.is_empty() or not _lights.has(str(_hold["light"])):
		return -1.0
	return float(_lights[str(_hold["light"])]["k"])


func _step_hold(dt: float) -> void:
	var h := _hold
	var id := str(h["light"])
	if not _lights.has(id):
		_hold_done(true)
		return
	h["age"] += dt
	h["pulse"] += dt
	var L: Dictionary = _lights[id]
	if holding() or (auto and float(h["age"]) >= HOLD_AUTO):
		h["idle"] = 0.0
		L["dur"] = 0.0
		L["k"] = maxf(float(L["k"]) - dt / float(h["t"]), 0.0)
		L["from"] = L["k"]
		L["to"] = L["k"]
		h["stream"] -= dt
		if h["stream"] <= 0.0:
			h["stream"] = HOLD_STREAM
			if str(h["into"]) != "":
				_streams.append({"from": id, "to": str(h["into"]), "t": 0.0, "dur": 0.75, "seed": _rng.randf() * TAU})
		h["tick"] -= dt
		if h["tick"] <= 0.0:
			h["tick"] = HOLD_TICK
			_haptic(10)
		h["give"] -= dt
		if h["give"] <= 0.0:
			h["give"] = HOLD_GIVE
			# (give holds only D: in_key snaps each replay onto the scale as the
			# light drains, D C A G F D: A7's ask)
			var gp := lerpf(0.5, 1.0, float(L["k"]))
			var sn := _sfx_node()
			if sn != null and sn.has_method("in_key"):
				gp = float(sn.in_key(gp))
			_sfx("give", gp, 0.6)
		if float(L["k"]) <= 0.0:
			_hold_done(true)
	else:
		h["idle"] += dt
		var nd: Array = h["nudge"]
		if not bool(h["nudged"]) and nd.size() >= 2 and float(h["idle"]) >= float(h["nudge_at"]):
			h["nudged"] = true
			h["pulse"] = 0.0
			_start_line(nd, true)


func _hold_done(go_on: bool) -> void:
	## The light is out: a snuff puff, a haptic, the music gone quiet; then
	## the scene goes on (its next beat is a wait: the dark and the silence).
	var id := str(_hold.get("light", ""))
	_set_light(id, 0.0)
	if _lights.has(id):
		_puffs.append({"id": id, "t": 0.0})
	_sfx("snuff", 0.8, 0.8)
	_haptic(60)
	_music("")
	_hold = {}
	_touch_ids.clear()
	_mouse_down = false
	_key_down = false
	if bool(_line.get("nudge", false)):
		_line = {}
	if go_on:
		waiting = ""
		_run()


func _mark_boss_card() -> void:
	## Over a level, the boss's HUD card counts as seen once his beat has
	## named him: a retry goes straight to the fight (world.gd checks
	## boss_card_<id>).
	if replay:
		return
	var bnode = world.get("boss") if world != null and is_instance_valid(world) else null
	var g := _g()
	if bnode != null and g != null and bnode.get("boss_id") != null:
		g.mark_seen("boss_card_" + str(bnode.get("boss_id")))


func _has_cue(cue: String) -> bool:
	for shot in _shots:
		for b in shot.get("beats", []):
			if b is Dictionary and b.get("do", "") == cue:
				return true
	return false


func _pose(a: String, frame: String) -> void:
	## A figure changes pose: a new texture, and the new pose's own flames
	## (out until a cue lights them).
	if not _figs.has(a):
		return
	var d := _figure_def(frame)
	var f: Dictionary = _figs[a]
	f["id"] = frame
	f["def"] = d
	f["tex"] = _load_tex(str(d.get("tex", "")))
	f["look"] = str(d.get("look", ""))
	(f["node"] as Node2D).queue_redraw()
	var flames: Dictionary = d.get("flames", {})
	for id in _lights.keys():
		if str(id).begins_with(a + ".") and not flames.has(str(id).get_slice(".", 1)):
			_lights.erase(id)
	var had := {}
	for name in flames:
		had[name] = _lights.has("%s.%s" % [a, name])
	_add_fig_lights(a, d)
	for name in flames:
		if not had[name]:
			_set_light("%s.%s" % [a, name], 0.0)


func _ignite(id: String, note_i: int, sound := "relight") -> void:
	if not _lights.has(id):
		return
	_tween_light(id, 1.0, 0.5)
	_glow.burst(_point_of(id), 18, Color("ffc86a"), 120.0, 0.6, 60.0, 2.4, 40.0)
	if sound != "":
		var s := _sfx_node()
		_sfx(sound, float(s.note(note_i)) if s != null and note_i > 0 else 1.0)
	_haptic(25)


func _set_light(id: String, k: float) -> void:
	if _lights.has(id):
		var L: Dictionary = _lights[id]
		L["k"] = k
		L["from"] = k
		L["to"] = k
		L["dur"] = 0.0


func _tween_light(id: String, to: float, dur: float) -> void:
	if not _lights.has(id):
		return
	var L: Dictionary = _lights[id]
	L["from"] = L["k"]
	L["to"] = to
	L["t"] = 0.0
	L["dur"] = dur
	if dur <= 0.0:
		L["k"] = to


func _point_of(id: String) -> Vector2:
	## A light's (or an anchor's) place on screen.
	if _lights.has(id):
		return _light_pos(_lights[id])
	var anchors: Dictionary = _panel.get("anchors", {})
	if anchors.has(id):
		return _to_screen(_arr2(anchors[id]["p"]), float(anchors[id].get("depth", 1.0)))
	return _vs() * 0.5


func _light_pos(L: Dictionary) -> Vector2:
	if L["kind"] == "actor":
		return _rig.flame_point() if _rig != null and _rig.is_inside_tree() else _vs() * 0.5
	if L["fig"] != "":
		var f: Dictionary = _figs.get(L["fig"], {})
		if f.is_empty():
			return _vs() * 0.5
		return _fig_point(f, L["fp"])
	return _to_screen(L["p"], L["depth"])


func _fig_point(f: Dictionary, fp: Vector2) -> Vector2:
	## A point of a figure's frame on screen: breathing, scaled and, for a
	## flipped figure, mirrored about its feet as the figure is.
	var x := _xf(f["depth"])
	var k: float = f["h"] / f["frame"].y * f["scale"]
	var breath := 1.0 + 0.012 * sin(_clock * 2.2 + f["ph"])
	var off: Vector2 = (fp - f["feet"]) * k
	off.y *= breath * f["scale_y"]
	if f["flip"]:
		off.x = -off.x
	return x[0] + (f["p"] + f["move"] + off) * float(x[1])


func _light_scale(L: Dictionary) -> float:
	if L["kind"] == "actor":
		return _actor.scale.x if _actor != null else 1.0
	if L["fig"] != "":
		var f: Dictionary = _figs.get(L["fig"], {})
		if f.is_empty():
			return 1.0
		return float(_xf(f["depth"])[1]) * f["h"] / f["frame"].y * f["scale"]
	return float(_xf(L["depth"])[1])


# ---------------------------------------------------------------- the calling chooser

func _open_chooser(prompt: String) -> void:
	waiting = "class"
	need_class.emit()
	var ks: Script = keeper_script if host_keeper else null
	if ks == null and host_keeper and ResourceLoader.exists(KEEPER_PATH):
		ks = load(KEEPER_PATH)
	if ks != null:
		_keeper = ks.new()
		# Hosted by the scene, not on its own: no Back, no backdrop of its own
		# (the plinths show through), Mother Taper's words as its title, and
		# the scene makes the hero (pick). Each flag is set only if it has it.
		var flags := {"embedded": true, "in_story": true, "standalone": false, "show_back": false,
				"show_backdrop": false, "title": prompt}
		for prop in flags:
			if prop in _keeper:
				_keeper.set(prop, flags[prop])
		if _keeper.has_signal("hovered"):
			_keeper.connect("hovered", func(id): _hover(str(id)))
		if _keeper.has_signal("picked"):
			_keeper.connect("picked", func(id): pick(str(id)))
		_ui.add_child(_keeper)
		_keeper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_chooser = {"sel": -1, "prompt": prompt, "deny": 0.0, "t": 0.0}
		# Every calling's face, loaded now (a texture first loaded while
		# drawing shows up white).
		for c in PLINTHS:
			_load_tex(Story.portrait_path("wick", "happy", c))
		var g := _g()
		if g != null and not (g.heroes() as Dictionary).is_empty():
			_hover(str(g.hero_id()))


func _hover(id: String) -> void:
	## A calling looked at: its plinth's candle catches; the others go out.
	## A sealed calling can't be looked at (its card says so instead).
	if not Classes.ALL.has(id) or not bool(Classes.ALL[id]["enabled"]):
		return
	for p in PLINTHS:
		var lid: String = "plinth_" + p
		if p == id:
			if _lights.has(lid) and float(_lights[lid]["to"]) < 0.5 and float(_lights[lid]["k"]) < 0.5:
				_ignite(lid, 0, "")
				_sfx("select")
		else:
			_tween_light(lid, 0.0, 0.25)
	if not _chooser.is_empty():
		_chooser["sel"] = PLINTHS.find(id)


func pick(id: String) -> bool:
	## The calling is chosen: make (or switch to) that hero, and go on.
	if waiting != "class" or not Classes.ALL.has(id) or not bool(Classes.ALL[id]["enabled"]):
		return false
	var g := _g()
	if g != null:
		g.new_hero(id)
	cls = id
	_close_chooser()
	for p in PLINTHS:
		if p != id:
			_tween_light("plinth_" + p, 0.0, 0.25)
	_ignite("plinth_" + id, 0)
	waiting = ""
	_run()
	return true


func resume() -> void:
	## Go on after choose_class when something else did the choosing.
	if waiting == "class":
		var g := _g()
		if g != null:
			cls = str(g.hero_id())
		_close_chooser()
		waiting = ""
		_run()


func _close_chooser() -> void:
	_class_done = true
	_chooser = {}
	if _keeper != null:
		_keeper.queue_free()
		_keeper = null


func _chooser_cards() -> Array:
	## The built-in chooser's cards, one under each plinth: [id, Rect2]. They
	## sit under the plinths' middles (a candle can hang off to one side),
	## narrow to the plinths' spacing (112 at least), and are always kept 8
	## apart inside the safe area.
	var out := []
	var safe := _safe()
	var gap := 8.0
	var anchors: Dictionary = _panel.get("anchors", {})
	var xs := []
	for i in PLINTHS.size():
		var x := safe.position.x + 20.0 + (safe.size.x - 40.0) * (i + 0.5) / 5.0
		if _panel_id != "":
			var ad: Dictionary = anchors.get("plinth_" + str(PLINTHS[i]), {"p": [PLINTH_X[i], 300.0]})
			x = _to_screen(_arr2(ad["p"]), float(ad.get("depth", 1.0))).x
		xs.append(x)
	var w := 142.0
	for i in range(1, xs.size()):
		w = minf(w, float(xs[i]) - float(xs[i - 1]) - gap)
	w = clampf(w, 112.0, minf(142.0, (safe.size.x - 8.0 - gap * 4.0) / 5.0))
	xs = spread(xs, w + gap, safe.position.x + w * 0.5 + 4.0, safe.end.x - w * 0.5 - 4.0)
	var h := 84.0
	var y := safe.end.y - 10.0 - h
	for i in PLINTHS.size():
		out.append([PLINTHS[i], Rect2(float(xs[i]) - w * 0.5, y, w, h)])
	return out


static func spread(xs: Array, min_gap: float, lo: float, hi: float) -> Array:
	## Centres (left to right) at least min_gap apart inside [lo, hi], moved
	## as little as that allows: pushed apart left to right, pulled back in
	## from the right edge, then the row re-centred on where it wanted to be.
	## Evenly spaced when they can't fit.
	var n := xs.size()
	var out := []
	var want := 0.0
	for x in xs:
		out.append(clampf(float(x), lo, hi))
		want += clampf(float(x), lo, hi) / n
	if n <= 1:
		return out
	if (n - 1) * min_gap > hi - lo:
		for i in n:
			out[i] = lerpf(lo, hi, float(i) / (n - 1))
		return out
	for i in range(1, n):
		out[i] = maxf(out[i], out[i - 1] + min_gap)
	if out[n - 1] > hi:
		out[n - 1] = hi
		for i in range(n - 2, -1, -1):
			out[i] = minf(out[i], out[i + 1] - min_gap)
	var have := 0.0
	for x in out:
		have += x / n
	var shift := clampf(want - have, lo - out[0], hi - out[n - 1])
	for i in n:
		out[i] += shift
	return out


func _chooser_tap(pos: Vector2) -> void:
	for c in _chooser_cards():
		var r: Rect2 = c[1]
		if r.grow(4.0).has_point(pos):
			var id: String = c[0]
			if not bool(Classes.ALL[id]["enabled"]):
				_chooser["deny"] = 1.4
				_sfx("back")
				return
			if PLINTHS.find(id) == int(_chooser["sel"]):
				pick(id)
			else:
				_hover(id)
			return


func _chooser_key(dir: int) -> void:
	var ids := PLINTHS.filter(func(c): return bool(Classes.ALL[c]["enabled"]))
	if ids.is_empty():
		return
	var sel := int(_chooser["sel"])
	var cur := ids.find(PLINTHS[sel]) if sel >= 0 else -1
	cur = wrapi(cur + dir, 0, ids.size()) if cur >= 0 else 0
	_hover(ids[cur])


# ---------------------------------------------------------------- the name entry

func name_is_instant() -> bool:
	## Nobody is there to type (as the chooser and the hold are answered
	## there): headless, stepped by hand (the tests and the shot tools), its
	## lines going by themselves for --autoplay=scene:<id> or the bot's
	## level, or any --autoplay launch. name_instant says so outright.
	if name_instant != null:
		return bool(name_instant)
	if manual or auto_advance or DisplayServer.get_name() == "headless":
		return true
	var g := _g()
	return g != null and g.has_method("autoplay_launch") and bool(g.autoplay_launch())


func _open_namer(prompt: String) -> bool:
	## choose_name: the entry over the shot, headed by the cue's prompt (a
	## phone's keyboard covers the box, where Mother Taper's question stays
	## up), holding Waxby to start from; true while it waits. Where nobody
	## types, Waxby at once (and false: the scene goes straight on).
	var g := _g()
	if name_is_instant():
		if g != null and g.has_method("set_hero_name"):
			g.set_hero_name(Story.HERO_NAME)
		_name_done = true
		return false
	waiting = "name"
	_namer = NameEntry.new()
	_namer.name = "NameEntry"
	_namer.prompt = prompt
	_namer.start = Story.HERO_NAME
	_namer.accent = Color(Classes.ALL[cls]["color"]) if Classes.ALL.has(cls) else UI.GOLD
	_namer.dim = 0.25
	_namer.named.connect(func(n): name_hero(n))
	_ui.add_child(_namer)
	return true


func name_hero(text: String) -> bool:
	## The name is given (the entry's Confirm, or a test): the save keeps it
	## (Story.clean_name's: nothing fit to keep is Waxby), and the scene goes on.
	if waiting != "name":
		return false
	var g := _g()
	if g != null and g.has_method("set_hero_name"):
		g.set_hero_name(text)
	_close_namer()
	waiting = ""
	_run()
	return true


func naming() -> bool:
	## The name entry is up, waiting.
	return waiting == "name" and _namer != null


func name_entry() -> Control:
	return _namer


func _close_namer() -> void:
	_name_done = true
	if _namer != null:
		_namer.queue_free()
		_namer = null


# ---------------------------------------------------------------- the end of a scene

func _end_scene() -> void:
	## Everything said: let the cards and walks finish, then close.
	waiting = "drain"


func _drained() -> bool:
	return _card.is_empty() and _boss.is_empty() and _chains.is_empty() and \
			(_actor_def.is_empty() or (_actor_def["walk"] as Dictionary).is_empty())


func _close() -> void:
	waiting = "close"
	_close_phase = 0
	_box_goal = 0.0
	if overlay and _panel_id == "":
		_close_phase = 1
		_fade_goal = 0.0
		_lb_goal = 0.0
		_dim_goal = 0.0
	else:
		_fade_goal = 1.0


func _step_close() -> void:
	if not overlay:
		if _fade >= 0.999:
			_finish_scene()
		return
	if _close_phase == 0 and _fade >= 0.999:
		# Out of the panel, back to the level under it.
		_clear_stage()
		_motes.clear()
		_close_phase = 1
		_fade_goal = 0.0
		_lb_goal = 0.0
		_dim_goal = 0.0
	elif _close_phase == 1 and _fade <= 0.001 and _lb <= 0.001 and _dim_k <= 0.001 and _box_a <= 0.001:
		_finish_scene()


func _finish_scene() -> void:
	var g := _g()
	if g != null and not replay:
		g.mark_seen(scene_id)
		# Hollin's stand-in played (REST_SUBS): Taper's counts as seen too,
		# whether the caller asked for hers or already swapped it for his.
		if asked_id != "" and asked_id != scene_id:
			g.mark_seen(asked_id)
		var base := Story.rest_base(scene_id)
		if base != "":
			g.mark_seen(base)
	asked_id = ""
	var nxt := str(_scene.get("next", ""))
	if follow_next and nxt != "" and Story.has_scene(nxt):
		_clear_stage()
		_prune_tex(first_textures(nxt))   # the scene before's pictures go with it
		_fade = 1.0
		_line = {}
		_begin_scene(nxt)
		return
	_finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	waiting = ""
	# A boss beat skipped before its card still counts the card as seen.
	if overlay and _has_cue("boss_card"):
		_mark_boss_card()
	_release_world()
	if overlay and world != null:
		queue_barks(world, _scene.get("barks", []), float(_scene.get("bark_delay", 0.8)))
	done.emit()
	if then_cb.is_valid():
		then_cb.call()
	queue_free()


func skip() -> void:
	## Skip the rest of this scene. A calling still has to be chosen and a
	## name given, so an oath skips to its chooser first, then to its name
	## entry (where someone types: else the name stays Waxby).
	if finished:
		return
	if not _class_done:
		if waiting == "class":
			return
		if _jump_to("choose_class"):
			return
	if not _name_done and not name_is_instant():
		if waiting == "name":
			return
		if _jump_to("choose_name"):
			return
	_card = {}
	_boss = {}
	_credits = {}
	_hold = {}
	_streams.clear()
	_chains.clear()
	_line = {}
	_box_goal = 0.0
	if not _actor_def.is_empty():
		_actor_def["walk"] = {}
	_sfx("back")
	_close()


func _jump_to(cue: String) -> bool:
	## Skip on to this scene's next `cue` (a choice still to make): its shot
	## set up afresh, with the lights and the hero's mood as the cues before
	## it in the shot would have left them (the oath's name: his flame lit);
	## the lines and waits before it dropped. False when there's none ahead.
	for si in range(maxi(_shot_i, 0), _shots.size()):
		var beats: Array = _shots[si].get("beats", [])
		for bi in beats.size():
			if beats[bi] is Dictionary and beats[bi].get("do", "") == cue:
				_shot_i = si
				_setup_shot(_shots[si])
				for k in bi:
					_settle(beats[k])
				_beat_i = bi
				_fade = 0.0
				_fade_goal = 0.0
				_line = {}
				_run()
				return true
	return false


func _settle(b) -> void:
	## A cue _jump_to skips over, as it would have left things (no sound, no
	## burst, no wait).
	if not (b is Dictionary) or (b.has("if") and not Story.flag(str(b["if"]))):
		return
	match str(b.get("do", "")):
		"ignite":
			_set_light(str(b["light"]), 1.0)
		"snuff":
			_set_light(str(b["light"]), 0.0)
		"light":
			_set_light(str(b["light"]), float(b["r"]))
		"mood":
			if _rig != null:
				_rig.mood = str(b["mood"])
		"pose":
			_pose(str(b["fig"]), str(b["frame"]))


# ---------------------------------------------------------------- the clock

func advance(dt: float) -> void:
	## One step of everything: the camera, lights, figures, cards, fades,
	## the line being typed and whatever the scene is waiting on.
	if finished:
		return
	_clock += dt
	if _cam_dur > 0.0:
		_cam_t = minf(_cam_t + dt, _cam_dur)
		var u := 0.5 - 0.5 * cos(PI * _cam_t / _cam_dur)
		_cam = _cam_from.lerp(_cam_to, u)
	for id in _lights:
		var L: Dictionary = _lights[id]
		if L["dur"] > 0.0:
			L["t"] += dt
			var u := clampf(L["t"] / L["dur"], 0.0, 1.0)
			L["k"] = lerpf(L["from"], L["to"], sin(u * PI * 0.5))
			if u >= 1.0:
				L["dur"] = 0.0
	for c in _chains.duplicate():
		c["t"] -= dt
		if c["t"] <= 0.0:
			var ids: Array = c["lights"]
			if c["i"] < ids.size():
				# E3: a chain can put its lights out in order instead.
				if bool(c.get("snuff", false)):
					_snuff(str(ids[c["i"]]))
				else:
					_ignite(str(ids[c["i"]]), c["i"], c["sfx"] if c["sfx"] != "" else "relight")
				c["i"] += 1
				c["t"] = c["gap"]
			else:
				_chains.erase(c)
	for a in _figs:
		_step_fig(_figs[a], dt)
	if not _actor_def.is_empty():
		var w: Dictionary = _actor_def["walk"]
		if not w.is_empty():
			w["t"] += dt
			var u := clampf(w["t"] / w["dur"], 0.0, 1.0)
			_actor_def["x"] = lerpf(w["from"], w["to"], u)
			_fake.velocity.x = (w["to"] - w["from"]) / w["dur"] / (_actor_def["h"] / 64.0)
			if u >= 1.0:
				_actor_def["walk"] = {}
				_fake.velocity.x = 0.0
	for p in _puffs:
		p["t"] += dt
	_puffs = _puffs.filter(func(p): return p["t"] < 1.2)
	for st in _streams:
		st["t"] += dt
	_streams = _streams.filter(func(st): return st["t"] < st["dur"])
	# Timers.
	_shake = maxf(_shake - dt * 14.0 - _shake * dt * 3.0, 0.0)
	_flash = maxf(_flash - dt / 0.12, 0.0)
	_box_shake = maxf(_box_shake - dt, 0.0)
	_pill_armed = maxf(_pill_armed - dt, 0.0)
	if not _dawn.is_empty():
		_dawn["t"] = minf(_dawn["t"] + dt, _dawn["dur"])
	if not _iris.is_empty():
		_iris["t"] = minf(_iris["t"] + dt, _iris["dur"])
	if not _card.is_empty():
		_card["t"] += dt
		if _card["t"] >= 2.9:
			_card = {}
	if not _boss.is_empty():
		_boss["t"] += dt
		if _boss["t"] >= 2.1:
			_boss = {}
	if not _chooser.is_empty():
		_chooser["t"] += dt
		_chooser["deny"] = maxf(_chooser["deny"] - dt, 0.0)
	if not _credits.is_empty():
		_step_credits(dt)
	# Fades, the letterbox, the dim, the box.
	var fr := 1.0 / (FADE_OUT if _fade_goal > _fade else FADE_IN)
	if waiting == "close" and not overlay:
		fr = 1.0 / 0.45
	_fade = move_toward(_fade, _fade_goal, dt * fr)
	_lb = move_toward(_lb, _lb_goal, dt / 0.3)
	_dim_k = move_toward(_dim_k, _dim_goal, dt / 0.3)
	_box_a = move_toward(_box_a, _box_goal, dt / 0.15)
	_lift = lerpf(_lift, _lift_goal(), 1.0 - exp(-dt * 6.0))
	# Whatever the scene waits on.
	match waiting:
		"fade_out":
			if _fade >= 0.999:
				_setup_shot(_shots[_pending_shot])
				_fade_goal = 0.0
				waiting = "fade_in"
		"fade_in":
			if _fade <= 0.001:
				waiting = ""
				_run()
		"time":
			if _clock >= _wait_until:
				waiting = ""
				_run()
		"credits":
			if _credits.is_empty():
				waiting = ""
				_run()
		"hold":
			_step_hold(dt)
		"drain":
			if _drained():
				_close()
		"close":
			_step_close()
	if finished:
		return
	_update_line(dt)
	_step_motes(dt)
	_apply_stage(dt)
	_feed_lights()
	if overlay:
		_cover_world(_grabbed and (_panel_id != "" or _fade >= 0.999))
	if _dim != null:
		_dim.color = Color(UI.INK, 0.35 * _dim_k)
	if manual:
		for gl in [_glow, _cold, _ui_glow]:
			gl._process(dt)
	_fx.queue_redraw()
	_ui.queue_redraw()


func _step_fig(f: Dictionary, dt: float) -> void:
	var tw: Dictionary = f["tw"]
	if tw.is_empty():
		return
	tw["t"] += dt
	var u := 1.0 if tw["dur"] <= 0.0 else clampf(tw["t"] / tw["dur"], 0.0, 1.0)
	var e := 0.5 - 0.5 * cos(PI * u)
	for k in ["alpha", "scale", "scale_y"]:
		if tw.has(k):
			f[k] = lerpf(tw[k][0], tw[k][1], e)
	if tw.has("move"):
		f["move"] = (tw["move"][0] as Vector2).lerp(tw["move"][1], e)
	if u >= 1.0:
		f["tw"] = {}


func _feed_lights() -> void:
	## The panel's lights into the layers' material (their tints and Hush
	## lights too), and its flames to Glow.
	_flames.clear()
	if _panel_id == "":
		_glow.queue_redraw()
		_cold.queue_redraw()
		return
	var arr := PackedVector4Array()
	var tints := PackedVector4Array()
	var tinted := not V2_PANELS.has(_panel_id)
	var iu := 0.0
	if not _iris.is_empty():
		iu = _iris["t"] / _iris["dur"]
	for id in _lights:
		var L: Dictionary = _lights[id]
		var k: float = L["k"]
		# A figure's own flames and eyes fade with it (the Snuffer leaving the
		# window takes his eyes with him), and with it squashed shut (the eye).
		if L["fig"] != "" and _figs.has(L["fig"]):
			var fg: Dictionary = _figs[L["fig"]]
			k *= clampf(float(fg["alpha"]), 0.0, 1.0) * clampf(float(fg["scale_y"]) / 0.3, 0.0, 1.0)
		if k <= 0.01:
			continue
		var p := _light_pos(L)
		var sc := _light_scale(L)
		var fl := 1.0
		if L["kind"] in ["flame", "actor", "cold"]:
			fl = 1.0 + 0.03 * sin(_clock * 13.0 + L["ph"]) + 0.02 * sin(_clock * 23.0 + L["ph"])
		var r: float = L["r"] * sc * (0.35 + 0.65 * minf(k, 1.5))
		var s: float = L["s"] * minf(k, 1.0) * fl
		# A flame's height follows its light, up to 2.0: homecoming's light_r
		# 2.0 is Taper standing tall. No other shot or cue takes a light past
		# 1.0, so nothing else draws differently.
		var fh: float = L["h"] * sc * minf(k, 2.0)
		if L["kind"] == "actor" and _rig != null:
			fh = 19.0 * float(Classes.ALL[cls].get("flame_scale", 1.0)) * sc * minf(k, 1.2)
			r = L["r"] * float(_xf(_actor_def["depth"])[1]) * (0.35 + 0.65 * minf(k, 1.5))
		if iu > 0.0:
			if id == _iris["light"]:
				r *= lerpf(1.0, 0.45, iu)
			else:
				r *= 1.0 - iu
				s *= 1.0 - iu
				fh *= 1.0 - iu
		var hush := bool(L.get("hush", false))
		if arr.size() < MAX_LIGHTS:
			arr.append(Vector4(p.x, p.y, r, -s if hush else s))
			var tint := Vector4.ZERO
			if tinted and not hush and L["col"] != "" and L["kind"] != "eyes":
				var c := Color(str(L["col"]))
				tint = Vector4(c.r, c.g, c.b, TINT_K)
			tints.append(tint)
		if hush:
			continue
		if fh > 0.6 and L["kind"] in ["flame", "actor", "cold"]:
			_flames.append({"p": p, "h": fh, "seed": L["ph"] * 7.0, "cold": L["kind"] == "cold"})
		elif L["kind"] == "eyes" and k > 0.05:
			var c: Color = Color(L["col"]) if L["col"] != "" else Color("f7b64a")
			var pupils := []
			var f: Dictionary = _figs.get(L["fig"], {})
			for fp in L.get("pts", []):
				pupils.append(_fig_point(f, fp) if not f.is_empty() else p)
			_flames.append({"p": p, "eyes": true, "pts": pupils, "r": maxf(float(L.get("dot", 1.2)) * sc, 1.2),
					"col": Color(c, minf(k, 1.0) * (1.0 - iu))})
	var n := arr.size()
	while arr.size() < MAX_LIGHTS:
		arr.append(Vector4.ZERO)
		tints.append(Vector4.ZERO)
	var dark: Color = _dark if _dark != null else Color.WHITE
	var warm := Color(1.0, 0.95, 0.86)
	if not _dawn.is_empty():
		var du: float = _dawn["t"] / _dawn["dur"]
		dark = dark.lerp(Color.WHITE, du)
		warm = warm.lerp(Color.WHITE, du)
	if iu > 0.0:
		dark = dark.lerp(Color(0.02, 0.01, 0.03), iu)
	_mat_set("lights", arr)
	_mat_set("tints", tints)
	_mat_set("light_count", n)
	_mat_set("view_size", _vs())
	_mat_set("dark_color", Vector3(dark.r, dark.g, dark.b))
	_mat_set("warm_color", Vector3(warm.r, warm.g, warm.b))
	_glow.queue_redraw()
	_cold.queue_redraw()


func _draw_flames(cold: bool) -> void:
	var g = _cold if cold else _glow
	for f in _flames:
		if f.get("eyes", false):
			if cold:
				continue
			var c: Color = f["col"]
			for p in f["pts"]:
				g.draw_circle(p, f["r"] * 3.2, Color(c, c.a * 0.12))
				g.draw_circle(p, f["r"] * 1.8, Color(c, c.a * 0.3))
				g.draw_circle(p, f["r"], c)
			continue
		if bool(f["cold"]) == cold:
			g.flame(f["p"], f["h"], f["seed"], true)


# ---------------------------------------------------------------- motes, smoke, credits

func _init_motes(kind: String) -> void:
	_motes.clear()
	_motes_kind = kind
	if kind == "":
		return
	var vs := _vs()
	var n: int = MOTE_COUNT.get(kind, 44)
	for i in n:
		var m := {"p": Vector2(_rng.randf() * vs.x, _rng.randf() * vs.y), "s": _rng.randf_range(0.8, 2.4),
				"v": _rng.randf_range(10.0, 34.0), "ph": _rng.randf() * TAU, "a": _rng.randf_range(0.25, 0.7)}
		match kind:
			"spores":
				m["s"] = _rng.randf_range(3.0, 6.0)
			"shards":
				m["s"] = _rng.randf_range(1.6, 3.0)
				m["rot"] = _rng.randf() * TAU
				m["spin"] = _rng.randf_range(-3.0, 3.0)
				m["col"] = Color(SHARD_COLS[i % SHARD_COLS.size()])
			"rime":
				m["s"] = _rng.randf_range(1.2, 2.6)
		_motes.append(m)


func _step_motes(dt: float) -> void:
	var vs := _vs()
	for m in _motes:
		var p: Vector2 = m["p"]
		match _motes_kind:
			"snow":
				p += Vector2(sin(_clock * 0.9 + m["ph"]) * 10.0, m["v"]) * dt
			"embers":
				p += Vector2(sin(_clock * 1.3 + m["ph"]) * 8.0, -m["v"]) * dt
			"wax":
				p += Vector2(0.0, m["v"] * 0.6) * dt
			"moths":
				# Circling the middle of the screen, fluttering.
				m["ph"] += dt * (0.5 + m["s"] * 0.2)
				var c := vs * Vector2(0.5, 0.42) + Vector2(cos(m["ph"]), sin(m["ph"] * 1.7)) * vs * Vector2(0.3, 0.18)
				p = p.lerp(c + Vector2(sin(_clock * 5.0 + m["ph"]) * 14.0, cos(_clock * 4.0 + m["ph"]) * 9.0), minf(dt * 2.0, 1.0))
			"spores":
				# Soft puffs drifting slowly up and sideways.
				p += Vector2(sin(_clock * 0.3 + m["ph"]) * 9.0, -m["v"] * 0.35) * dt
			"rime":
				# Tiny glints, falling slowly.
				p += Vector2(sin(_clock * 0.7 + m["ph"]) * 4.0, m["v"] * 0.45) * dt
			"shards":
				# Slivers of coloured glass, spinning as they fall.
				p += Vector2(sin(_clock * 0.5 + m["ph"]) * 10.0, m["v"] * 0.8) * dt
				m["rot"] += m["spin"] * dt
			"fireflies":
				# Rising and wandering.
				p += Vector2(sin(_clock * 0.9 + m["ph"] * 3.0) * 18.0, -m["v"] * 0.5 + cos(_clock * 1.3 + m["ph"]) * 8.0) * dt
			_:
				p += Vector2(sin(_clock * 0.4 + m["ph"]) * 6.0, sin(_clock * 0.3 + m["ph"] * 2.0) * 4.0 - 2.0) * dt
		m["p"] = Vector2(fposmod(p.x + 20.0, vs.x + 40.0) - 20.0, fposmod(p.y + 20.0, vs.y + 40.0) - 20.0)


func _draw_fx() -> void:
	var vs := _vs()
	# The glass's slow shimmer.
	if bool(_panel.get("shimmer", false)):
		var x := fposmod(_clock * 90.0, vs.x + 600.0) - 300.0
		var a := Color(1, 1, 1, 0.07)
		var z := Color(1, 1, 1, 0.0)
		_fx.draw_polygon(PackedVector2Array([Vector2(x - 90, 0), Vector2(x, 0), Vector2(x - 140, vs.y), Vector2(x - 230, vs.y)]),
				PackedColorArray([z, a, a, z]))
	var tb := TriBatch.new()
	for m in _motes:
		var p: Vector2 = m["p"]
		var tw := 0.7 + 0.3 * sin(_clock * 3.0 + m["ph"])
		if _mote_tb(tb, m, p):
			continue
		match _motes_kind:
			"snow":
				_fx.draw_circle(p, m["s"], Color(1, 1, 1, m["a"] * 0.8))
			"embers":
				_fx.draw_circle(p, m["s"] * 1.6, Color(1.0, 0.6, 0.2, 0.12 * tw))
				_fx.draw_circle(p, m["s"] * 0.7, Color(1.0, 0.8, 0.4, m["a"] * tw))
			"wax":
				_fx.draw_colored_polygon(Stage._ellipse(p, m["s"] * 0.8, m["s"] * 1.8, 10), Color(0.94, 0.9, 0.8, m["a"] * 0.6))
			"moths":
				var flap := absf(sin(_clock * 14.0 + m["ph"])) * 5.0 + 1.0
				var col := Color(0.85, 0.92, 0.78, 0.85)
				_fx.draw_line(p, p + Vector2(-6, -flap), col, 2.0)
				_fx.draw_line(p, p + Vector2(6, -flap), col, 2.0)
				_fx.draw_circle(p, 1.6, col)
			_:
				_fx.draw_circle(p, m["s"] * 0.7, Color(1.0, 0.95, 0.85, m["a"] * 0.45 * tw))
	# The hold's motes, streaming from the light into its target.
	for st in _streams:
		if not _lights.has(st["from"]):
			continue
		var a := _light_pos(_lights[st["from"]])
		var b := _point_of(str(st["to"]))
		var u: float = st["t"] / st["dur"]
		var mid := a.lerp(b, 0.5) + Vector2(sin(st["seed"]) * 24.0, -40.0 - cos(st["seed"]) * 16.0)
		var q := a.lerp(mid, u).lerp(mid.lerp(b, u), u)
		var al := sin(u * PI)
		tb.circle(q, 6.0, Color(1.0, 0.75, 0.3, 0.25 * al), 10)
		tb.circle(q, 2.2, Color(1.0, 0.92, 0.6, 0.9 * al), 8)
	tb.flush(_fx)
	# Smoke where a light was put out.
	for pf in _puffs:
		if not _lights.has(pf["id"]):
			continue
		var base := _light_pos(_lights[pf["id"]])
		var k: float = pf["t"] / 1.2
		for i in 4:
			var y := -k * 34.0 - i * 7.0
			_fx.draw_circle(base + Vector2(sin(_clock * 4.0 + i) * 3.0, y), 2.5 + i * 0.9 + k * 3.0,
					Color(0.7, 0.68, 0.75, maxf(0.0, 0.45 - k * 0.4 - i * 0.06)))
	# A stand-in stage says so, quietly, and names its lights.
	if bool(_panel.get("stand_in", false)) and _fade < 0.5:
		var f := UI.font("body", 600)
		for id in _lights:
			var L: Dictionary = _lights[id]
			if L["fig"] != "" or L["kind"] in ["actor", "glow"]:
				continue
			var p := _light_pos(L)
			_fx.draw_string(f, p + Vector2(-40, 12), str(id), HORIZONTAL_ALIGNMENT_CENTER, 80, 7, Color(UI.MUTED, 0.3))
		_fx.draw_string(f, Vector2(_safe().position.x + 4.0, LETTERBOX + 13.0), "%s: art pending" % _panel_id,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(UI.MUTED, 0.4))


func _mote_tb(tb, m: Dictionary, p: Vector2) -> bool:
	## The v3 motes (E4), into the effects' TriBatch; false for v2's kinds.
	match _motes_kind:
		"spores":
			var c := Color(0.66, 0.74, 0.56)
			tb.circle(p, m["s"] * 1.7, Color(c, 0.1), 12)
			tb.circle(p, m["s"], Color(c, 0.3), 12)
		"rime":
			var a := 0.2 + 0.7 * maxf(0.0, sin(_clock * 4.0 + m["ph"]))
			var r: float = m["s"] * 2.0
			tb.line(p - Vector2(r, 0), p + Vector2(r, 0), 1.2, Color(0.95, 0.98, 1.0, a))
			tb.line(p - Vector2(0, r), p + Vector2(0, r), 1.2, Color(0.95, 0.98, 1.0, a))
			tb.circle(p, 1.0, Color(1, 1, 1, a), 6)
		"shards":
			var d := Vector2(cos(m["rot"]), sin(m["rot"]))
			var o := d.orthogonal()
			var ln: float = m["s"] * 3.5
			var w: float = m["s"] * 1.1
			tb.quad(p - d * ln + o * w * 0.3, p + d * ln, p - d * ln * 0.2 - o * w, p - d * ln - o * w * 0.2, Color(m["col"], 0.75))
		"fireflies":
			var a := lerpf(0.4, 1.0, 0.5 + 0.5 * sin(_clock * 2.5 + m["ph"]))
			var c := Color(0.85, 0.95, 0.45)
			tb.circle(p, 5.0, Color(c, a * 0.22), 10)
			tb.circle(p, 1.8, Color(c, a), 8)
		_:
			return false
	return true


func _step_credits(dt: float) -> void:
	var sp := 4.0 if bool(_credits["fast"]) else 1.0
	_credits["t"] += dt * sp
	var vs := _vs()
	var em: Array = _credits["embers"]
	if em.size() < 50 and _rng.randf() < dt * 30.0:
		em.append({"p": Vector2(_rng.randf() * vs.x, vs.y + 10.0), "v": _rng.randf_range(20.0, 55.0),
				"ph": _rng.randf() * TAU, "s": _rng.randf_range(1.0, 2.4)})
	for e in em:
		e["p"] += Vector2(sin(_clock * 1.2 + e["ph"]) * 10.0, -e["v"]) * dt
	_credits["embers"] = em.filter(func(e): return e["p"].y > -10.0)
	# v2's lines, then the cast roll (the owner's answer), page by page.
	if _credits["t"] >= CREDITS_TIME:
		_credits["cast_t"] += dt * sp
		if _credits["cast_t"] >= CAST_PAGE * Story.CAST_ROLL.size():
			_credits = {}


func credits_phase() -> String:
	## "roll" (v2's lines), "cast" (the cast roll) or "" (no credits up).
	if _credits.is_empty():
		return ""
	return "roll" if float(_credits["t"]) < CREDITS_TIME else "cast"


func cast_page() -> int:
	## The cast roll's page showing, or -1.
	if credits_phase() != "cast":
		return -1
	return mini(int(float(_credits["cast_t"]) / CAST_PAGE), Story.CAST_ROLL.size() - 1)


# ---------------------------------------------------------------- input

func _on_ui_input(e: InputEvent) -> void:
	if waiting == "hold" and not finished and _hold_input(e):
		_ui.accept_event()
		return
	if waiting == "name":
		return   # (the name entry takes its own taps)
	var pos = null
	if e is InputEventScreenTouch and e.pressed:
		pos = e.position
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
	if pos == null or finished:
		return
	_ui.accept_event()
	# One touch arrives twice (the touch, and the mouse click made from it).
	if _last_tap >= 0.0 and _clock - _last_tap < 0.08:
		return
	_last_tap = _clock
	if _pill_visible() and _pill_rect().grow(10.0).has_point(pos):
		_pill_tap()
		return
	if waiting == "class" and not _chooser.is_empty():
		_chooser_tap(pos)
		return
	tap()


func _hold_input(e: InputEvent) -> bool:
	## A finger (or the mouse) down anywhere but Skip holds; lifted, it lets go.
	## false for what the ordinary taps should see (a press on Skip).
	var on_pill := func(p: Vector2) -> bool: return _pill_visible() and _pill_rect().grow(10.0).has_point(p)
	if e is InputEventScreenTouch:
		if e.pressed:
			if on_pill.call(e.position):
				return false
			_touch_ids[e.index] = true
		else:
			_touch_ids.erase(e.index)
		return true
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if on_pill.call(e.position):
				return false
			_mouse_down = true
		else:
			_mouse_down = false
		return true
	return false


func _input(e: InputEvent) -> void:
	if waiting == "hold" and not finished and e is InputEventKey and not e.echo:
		# On a Mac: jump, attack, Space or Enter held down holds.
		if e.pressed and e.keycode == KEY_ESCAPE:
			skip()
			get_viewport().set_input_as_handled()
			return
		if e.is_action("jump") or e.is_action("attack") or e.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_key_down = e.pressed
			get_viewport().set_input_as_handled()
			return
	if finished or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if waiting == "name":
		return   # every key is the name entry's (Z, X and Space are letters there)
	if waiting == "class" and _keeper != null:
		return
	var handled := true
	if e.keycode == KEY_ESCAPE:
		skip()
	elif waiting == "class" and not _chooser.is_empty():
		if e.is_action_pressed("left"):
			_chooser_key(-1)
		elif e.is_action_pressed("right"):
			_chooser_key(1)
		elif e.is_action_pressed("jump") or e.is_action_pressed("attack") or e.keycode == KEY_ENTER:
			if int(_chooser["sel"]) >= 0:
				pick(PLINTHS[int(_chooser["sel"])])
		else:
			handled = false
	elif e.is_action_pressed("jump") or e.is_action_pressed("attack") or e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		tap()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _pill_visible() -> bool:
	return waiting != "class" and waiting != "name" and waiting != "close" and not finished


func _pill_rect() -> Rect2:
	## In the top letterbox bar, clear of the picture (and, over a screen,
	## in the bar that covers its top row, not on the screen's own buttons).
	var safe := _safe()
	return Rect2(safe.end.x - 72.0, (top_bar_h() - 22.0) * 0.5, 66.0, 22.0)


func top_bar_h() -> float:
	## The top letterbox bar at its full height: LETTERBOX over a picture or
	## a level (whose HUD is hidden meanwhile), and down past a screen's top
	## row over a screen.
	if overlay and world == null:
		return maxf(LETTERBOX, _safe().position.y + SCREEN_ROW)
	return LETTERBOX


func bottom_bar_h() -> float:
	## The bottom letterbox bar at its full height, before a picture's lift:
	## LETTERBOX, and none over a screen (the dim does the framing there).
	if overlay and world == null:
		return 0.0
	return LETTERBOX


func _pill_tap() -> void:
	## Skip: one tap for a scene seen before, two for a new one.
	if seen_before or _pill_armed > 0.0:
		skip()
	else:
		_pill_armed = 2.0
		_sfx("click")


# ---------------------------------------------------------------- sound and haptics

func _sfx_node() -> Node:
	return get_node_or_null("/root/Sfx") if is_inside_tree() else null


func _sfx(name: String, pitch := 1.0, vol := 1.0) -> void:
	var s := _sfx_node()
	if s == null or name == "":
		return
	# A sound not made yet stays quiet rather than warning on every blip.
	var names = s.get_script().get_script_constant_map().get("NAMES", []) if s.get_script() != null else []
	if names is Array and not (names as Array).is_empty() and not (names as Array).has(name):
		return
	var p = s.play(name, pitch)
	if p != null and vol < 1.0:
		p.volume_db += linear_to_db(vol)


# Tracks the story asks for that may not be rendered yet, and what plays in
# their place meanwhile (so a missing track never warns or goes silent).
const MUSIC_STAND_IN := {"story": "chapel", "hush": "", "dawn": "title"}


func _music(track: String) -> void:
	var s := _sfx_node()
	if s == null:
		return
	if track != "" and not ResourceLoader.exists("res://audio/%s.wav" % track) and MUSIC_STAND_IN.has(track):
		track = MUSIC_STAND_IN[track]
	if track == "":
		s.stop_music(0.8)
	else:
		s.play_music(track)


func _haptic(ms: int) -> void:
	var g := _g()
	if g != null and bool(g.get("haptics")):
		Input.vibrate_handheld(ms, clampf(ms / 60.0, 0.2, 1.0))


# ---------------------------------------------------------------- drawing: the UI layer

func _safe() -> Rect2:
	if not is_inside_tree():
		return Rect2(14, 10, 816, 362)
	return UI.safe_rect(get_viewport())


func _draw_ui() -> void:
	var vs := _vs()
	_ui_flames.clear()
	if _fade > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, _fade))
	if _flash > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, minf(_flash, 1.0) * 0.9))
	if _lb > 0.0:
		var k := 1.0 - pow(1.0 - _lb, 3.0)
		_ui.draw_rect(Rect2(0, 0, vs.x, top_bar_h() * k), UI.INK)
		# The bottom bar grows under the picture as it lifts.
		var h := bottom_bar_h() * k
		var hb := h + _lift * minf(_lb * 2.0, 1.0)
		_ui.draw_rect(Rect2(0, vs.y - hb, vs.x, hb), UI.INK)
		if hb > h + 2.0:
			_ui.draw_line(Vector2(0, vs.y - hb), Vector2(vs.x, vs.y - hb), Color(UI.PANEL_EDGE, 0.35), 1.0)
	if not _line.is_empty():
		match _line["style"]:
			"narrate":
				if _line["shown_line"]:
					_draw_narration(vs)
			"hush":
				if _line["shown_line"]:
					_draw_hush(vs)
			_:
				if _box_a > 0.01:
					_draw_box()
	if not _chooser.is_empty():
		_draw_chooser(vs)
	if not _hold.is_empty():
		_draw_hold()
	if not _credits.is_empty():
		_draw_credits(vs)
	if not _card.is_empty():
		_draw_card(vs)
	if not _boss.is_empty():
		_draw_boss_card(vs)
	if _pill_visible() and _lb > 0.5:
		_draw_pill()
	_ui_glow.queue_redraw()


func _draw_ui_flames() -> void:
	for f in _ui_flames:
		_ui_glow.flame(f["p"], f["h"], f.get("seed", 0.0), false, false, {"alpha": f["a"]} if f.has("a") else {})


func _draw_box() -> void:
	var sp: Dictionary = _line["sp"]
	var col: Color = sp["color"]
	var safe := _safe()
	var r := Rect2(safe.position.x + 12.0, safe.end.y - 6.0 - 96.0, safe.size.x - 24.0, 96.0)
	var a := _box_a
	r.position.y += (1.0 - a) * 14.0
	if _box_shake > 0.0:
		r.position.x += sin(_clock * 80.0) * 4.0 * (_box_shake / 0.25)
	UI.panel(_ui, r, Color(col, 0.8 * a), Color(UI.PANEL, 0.94 * a), 12.0)
	var left: bool = sp["side"] == "left"
	var pc := Vector2(r.position.x + 58.0, r.position.y + 4.0) if left else Vector2(r.end.x - 58.0, r.position.y + 4.0)
	_portrait(_line["who"], _line["mood"], pc, 46.0, col, a)
	var x0 := r.position.x + 124.0 if left else r.position.x + 24.0
	var x1 := r.end.x - 24.0 if left else r.end.x - 124.0
	# The name plate.
	var nm: String = sp["name"]
	if nm != "":
		var nf := UI.font("title", 700)
		_ui.draw_string_outline(nf, Vector2(x0, r.position.y + 28.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 5, Color(UI.INK, a))
		_ui.draw_string(nf, Vector2(x0, r.position.y + 28.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(col, a))
	# The words typed so far.
	var f: Font = _line["font"]
	var size: int = _line["size"]
	var left_chars: int = _line["shown"]
	var y := r.position.y + (56.0 if size <= 18 else 58.0)
	for ln in _line["wrap"]:
		if left_chars <= 0:
			break
		var s: String = ln.substr(0, left_chars)
		_ui.draw_string(f, Vector2(x0, y), s, HORIZONTAL_ALIGNMENT_LEFT, x1 - x0 + 40.0, size, Color(UI.CREAM, a))
		left_chars -= ln.length() + 1
		y += 24.0
	# "Next": a little flame, bobbing, once the line is done.
	if _line["done"] and waiting == "line" and a > 0.9:
		_ui_flames.append({"p": Vector2(r.end.x - 22.0, r.end.y - 10.0 + sin(_clock * 5.0) * 2.0), "h": 9.0, "seed": 1.0})


func _draw_narration(vs: Vector2) -> void:
	## Storybook words, fading in one by one, low in the frame.
	var f: Font = _line["font"]
	var size: int = _line["size"]
	var lines: PackedStringArray = _line["wrap"]
	var base_y := vs.y - 62.0 - (lines.size() - 1) * 30.0
	var t: float = _line["t"]
	# A soft dark shelf for the words to sit on (a line's "at": "top" puts
	# them under the top bar, off a face the picture holds low).
	var ga := clampf(t / 0.3, 0.0, 1.0) * 0.7
	var g0 := Color(0.03, 0.02, 0.05, 0.0)
	var g1 := Color(0.03, 0.02, 0.05, ga)
	if str(_line.get("at", "")) == "top":
		base_y = LETTERBOX + 40.0
		var end_y := base_y + (lines.size() - 1) * 30.0 + 40.0
		_ui.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, end_y), Vector2(0, end_y)]),
				PackedColorArray([g1, g1, g0, g0]))
	else:
		_ui.draw_polygon(PackedVector2Array([Vector2(0, base_y - 64.0), Vector2(vs.x, base_y - 64.0), Vector2(vs.x, vs.y), Vector2(0, vs.y)]),
				PackedColorArray([g0, g0, g1, g1]))
	var space := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var wi := 0
	for li in lines.size():
		var words := lines[li].split(" ")
		var total := f.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x := (vs.x - total) * 0.5
		for w in words:
			var k := clampf((t - wi * 0.06) / 0.25, 0.0, 1.0)
			if k > 0.0:
				var p := Vector2(x, base_y + li * 30.0 + (1.0 - k) * 4.0)
				_ui.draw_string_outline(f, p, w, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(UI.INK, k * 0.9))
				_ui.draw_string(f, p, w, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(UI.CREAM, k))
			x += f.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + space
			wi += 1


func _draw_hush(vs: Vector2) -> void:
	## The Hush: lowercase letters in the middle of the dark, each one
	## settling out of a small tremble as it arrives.
	var f: Font = _line["font"]
	var size: int = _line["size"]
	var col := Color("9a90c8")
	var lines: PackedStringArray = _line["wrap"]
	var shown: int = _line["shown"]
	var idx := 0
	var spread_y := (lines.size() - 1) * 17.0
	if not _line.has("y"):
		# Over a live level (an overlay has no figures of its own) its words
		# keep off the level's hero too, as a scene's keep off its actor.
		_line["y"] = text_band(str(_line.get("at", "")), vs.y * 0.5, 28.0 + spread_y, 10.0 + spread_y, _level_hero_rects())
	var y0: float = _line["y"] - spread_y
	for li in lines.size():
		var ln := lines[li]
		var total := f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x := (vs.x - total) * 0.5
		for ci in ln.length():
			if idx >= shown:
				return
			var ch := ln[ci]
			var age: float = float(_line["t"]) - (idx + 1) / HUSH_CPS
			var jit := clampf(1.0 - age / 0.35, 0.0, 1.0)
			var off := Vector2(sin(idx * 7.3 + _clock * 30.0), cos(idx * 3.1 + _clock * 27.0)) * 3.0 * jit
			var p := Vector2(x, y0 + li * 34.0) + off
			_ui.draw_string_outline(f, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 9, Color(0.02, 0.01, 0.04, 0.55 * (1.0 - jit)))
			_ui.draw_string_outline(f, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.02, 0.01, 0.04, 0.9))
			_ui.draw_string(f, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, 1.0 - jit * 0.6))
			x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			idx += 1
		idx += 1


func _draw_card(vs: Vector2) -> void:
	## A world card: the sub line in spaced capitals, the title in gold.
	var t: float = _card["t"]
	var a := clampf(t / 0.4, 0.0, 1.0) * clampf((2.9 - t) / 0.5, 0.0, 1.0)
	if not _card.has("y"):
		_card["y"] = text_band(str(_card.get("at", "")), vs.y * 0.44, 52.0, 28.0)
	var y: float = _card["y"] - (1.0 - a) * 6.0
	var sub := " ".join(str(_card["sub"]).to_upper().split(""))
	UI.text(_ui, Vector2(0, y - 36.0), sub, 14, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, "body", 700, 4)
	var f := UI.font("title", 700)
	_ui.draw_string_outline(f, Vector2(0, y + 8.0), _card["title"], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 40, 8, Color(UI.INK, a * 0.9))
	_ui.draw_string(f, Vector2(0, y + 8.0), _card["title"], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 40, Color(UI.GOLD, a))
	var w := 90.0 * a
	_ui.draw_line(Vector2(vs.x * 0.5 - w, y + 24.0), Vector2(vs.x * 0.5 + w, y + 24.0), Color(UI.GOLD, a * 0.6), 2.0)


func _level_hero_rects() -> Array:
	## The level's hero on screen, flame and all, when this plays over one.
	if not overlay or world == null or not is_instance_valid(world) or world.get("player") == null:
		return []
	var pl = world.get("player")
	if not (pl is Node2D) or not (pl as Node2D).is_inside_tree():
		return []
	var xf: Transform2D = (pl as Node2D).get_global_transform_with_canvas()
	var k: float = xf.get_scale().y
	var feet: Vector2 = xf.origin
	return [Rect2(feet + Vector2(-20.0, -86.0) * k, Vector2(40.0, 86.0) * k)]


func text_band(at: String, mid: float, above: float, below: float, extra: Array = []) -> float:
	## Where a card or the Hush's words sit (the y their block is measured
	## from; the block reaches `above` over it and `below` under it): "top"
	## (just under the letterbox), "mid", or "low" (just over the bottom
	## bar). "" chooses the first of mid, top and low that no figure or hero
	## (candle flame and all) stands in, else the top.
	var vs := _vs()
	var bands := {"mid": mid, "top": LETTERBOX + 10.0 + above, "low": vs.y - LETTERBOX - _lift_goal() - 10.0 - below}
	if bands.has(at):
		return bands[at]
	for k in ["mid", "top", "low"]:
		if band_clear(bands[k], above, below, extra):
			return bands[k]
	return bands["top"]


func band_clear(y: float, above: float, below: float, extra: Array = []) -> bool:
	## No one stands in the middle of the screen between y - above and
	## y + below, judged where the picture is going (it may still be
	## settling back down after the last line).
	var vs := _vs()
	var settle := _lift - _lift_goal()
	var band := Rect2(vs.x * 0.2, y - above - settle, vs.x * 0.6, above + below)
	for r in figure_rects() + extra:
		if (r as Rect2).intersects(band):
			return false
	return true


func figure_rects() -> Array:
	## Where the figures and the hero stand on screen now, roughly: the
	## middle half of each one's frame, from its top down to its feet (the
	## hero's candle flame included).
	var out := []
	for a in _figs:
		var f: Dictionary = _figs[a]
		var n: Node2D = f["node"]
		if f["alpha"] < 0.1 or not n.visible:
			continue
		var k := Vector2(absf(n.scale.x), n.scale.y)
		var fr: Vector2 = f["frame"] * k
		var feet: Vector2 = f["feet"] * k
		out.append(Rect2(n.position.x - fr.x * 0.25, n.position.y - feet.y, fr.x * 0.5, fr.y))
	if _actor != null:
		# The rig's 64-unit frame, feet at (32, 61), and the flame over it.
		var k := _actor.scale.x
		var r := Rect2(_actor.position + Vector2(-16.0, -61.0) * k, Vector2(32.0, 64.0) * k)
		if _rig != null and _rig.is_inside_tree():
			var fs := float(Classes.ALL[cls].get("flame_scale", 1.0))
			r = r.expand(_rig.flame_point() - Vector2(0.0, 19.0 * fs * k * 1.3))
		out.append(r)
	return out


func _draw_boss_card(vs: Vector2) -> void:
	## The boss's name on a slanted ink band that sweeps in from the right.
	var t: float = _boss["t"]
	var slide := 0.0
	if t < 0.25:
		slide = pow(1.0 - t / 0.25, 3.0) * vs.x
	elif t > 1.85:
		slide = -pow((t - 1.85) / 0.25, 2.0) * vs.x
	var y0 := vs.y * 0.40
	var y1 := vs.y * 0.62
	var sl := 34.0
	var band := PackedVector2Array([Vector2(-60 + slide, y0 + sl * 0.3), Vector2(vs.x + 60 + slide, y0 - sl * 0.3),
			Vector2(vs.x + 60 + slide, y1 - sl * 0.3), Vector2(-60 + slide, y1 + sl * 0.3)])
	_ui.draw_colored_polygon(band, Color(UI.INK, 0.93))
	var sp := Story.speaker(_boss["who"], cls)
	var col: Color = sp["color"]
	_ui.draw_line(band[0] + Vector2(0, 2), band[1] + Vector2(0, 2), col, 3.0)
	_ui.draw_line(band[3] - Vector2(0, 2), band[2] - Vector2(0, 2), Color(col, 0.5), 2.0)
	var cx := vs.x * 0.3 + slide
	var cy := (y0 + y1) * 0.5
	_portrait(_boss["who"], _boss["mood"], Vector2(cx, cy), 34.0, col, 1.0)
	var title := " ".join(str(_boss["title"]).to_upper().split(""))
	UI.text(_ui, Vector2(cx + 54.0, cy - 12.0), title, 13, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	var f := UI.font("title", 700)
	_ui.draw_string_outline(f, Vector2(cx + 52.0, cy + 26.0), _boss["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 6, UI.INK)
	_ui.draw_string(f, Vector2(cx + 52.0, cy + 26.0), _boss["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UI.GOLD)


func _draw_credits(vs: Vector2) -> void:
	var t: float = _credits["t"]
	_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.03, clampf(t / 0.6, 0.0, 1.0)))
	for e in _credits["embers"]:
		var tw := 0.7 + 0.3 * sin(_clock * 4.0 + e["ph"])
		_ui.draw_circle(e["p"], e["s"] * 2.2, Color(1.0, 0.6, 0.2, 0.1 * tw))
		_ui.draw_circle(e["p"], e["s"] * 0.8, Color(1.0, 0.8, 0.4, 0.8 * tw))
	if float(_credits["t"]) >= CREDITS_TIME:
		_draw_cast(vs)
		return
	# The roll rises until its last line sits in the middle, then holds.
	var heights := []
	var total := 0.0
	for c in Story.CREDITS:
		var h := 64.0 if c[1] == "title" else (24.0 if c[1] == "" else 38.0)
		heights.append(h)
		total += h
	var rest := (vs.y - total) * 0.5 - 14.0
	var u := clampf((t - 0.4) / (CREDITS_TIME - 3.4), 0.0, 1.0)
	var y := lerpf(vs.y + 10.0, rest, 1.0 - pow(1.0 - u, 3.0))
	var fade := clampf((CREDITS_TIME - t) / 0.8, 0.0, 1.0)
	var f_title := UI.font("title", 700)
	var f_body := UI.font("body", 600)
	for i in Story.CREDITS.size():
		var c: Array = Story.CREDITS[i]
		y += heights[i]
		if c[1] == "":
			continue
		if c[1] == "title":
			var size := 46 if i == 0 else 30
			_ui.draw_string_outline(f_title, Vector2(0, y), c[0], HORIZONTAL_ALIGNMENT_CENTER, vs.x, size, 6, Color(UI.INK, fade))
			_ui.draw_string(f_title, Vector2(0, y), c[0], HORIZONTAL_ALIGNMENT_CENTER, vs.x, size, Color(UI.GOLD, fade))
		else:
			_ui.draw_string(f_body, Vector2(0, y), c[0], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 18, Color(UI.CREAM, fade))


func cast_layout(page: int) -> Array:
	## The cast roll's page: [{who, mood, name, what, c (the portrait's
	## centre), r}] in its grid, inside the safe area, under the page title.
	var out := []
	if page < 0 or page >= Story.CAST_ROLL.size():
		return out
	var pg: Dictionary = Story.CAST_ROLL[page]
	var people: Array = pg["people"]
	var cols: int = int(pg.get("cols", 4))
	var rows := int(ceil(people.size() / float(cols)))
	var safe := _safe()
	var cw := safe.size.x / cols
	var row_h := 118.0
	var top := LETTERBOX + 92.0 + (2 - rows) * row_h * 0.5
	for i in people.size():
		var pe: Array = people[i]
		var row := i / cols
		var in_row := mini(cols, people.size() - row * cols)
		var x0 := safe.position.x + (safe.size.x - in_row * cw) * 0.5
		var c := Vector2(x0 + ((i % cols) + 0.5) * cw, top + row * row_h + 26.0)
		var what := Story.fill(str(pe[3]), cls).replace("{lost_home}", Story.lost_home())
		out.append({"who": str(pe[0]), "mood": str(pe[1]), "name": Story.fill(str(pe[2]), cls), "what": what,
				"c": c, "r": 26.0, "w": cw})
	return out


func _draw_cast(vs: Vector2) -> void:
	## A cast page: its title, then each one's small portrait, name and what
	## they are, fading in and out over the credits' embers.
	var page := cast_page()
	if page < 0:
		return
	var u := float(_credits["cast_t"]) - page * CAST_PAGE
	var a := clampf(u / CAST_FADE, 0.0, 1.0) * clampf((CAST_PAGE - u) / CAST_FADE, 0.0, 1.0)
	var f_title := UI.font("title", 700)
	var title := str(Story.CAST_ROLL[page]["title"])
	var ty := LETTERBOX + 44.0
	_ui.draw_string_outline(f_title, Vector2(0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 30, 6, Color(UI.INK, a))
	_ui.draw_string(f_title, Vector2(0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 30, Color(UI.GOLD, a))
	for e in cast_layout(page):
		var sp := Story.speaker(e["who"], cls)
		var col: Color = sp["color"]
		var c: Vector2 = e["c"]
		var nf := _ui_flames.size()
		_portrait(e["who"], e["mood"], c, e["r"], col, a, true)
		for i in range(nf, _ui_flames.size()):
			_ui_flames[i]["a"] = a
		var w: float = e["w"]
		var size := UI.fit_size(e["name"], w - 10.0, 17, 13, "title", 700)
		_ui.draw_string_outline(f_title, Vector2(c.x - w * 0.5, c.y + 52.0), e["name"], HORIZONTAL_ALIGNMENT_CENTER, w, size, 5, Color(UI.INK, a))
		_ui.draw_string(f_title, Vector2(c.x - w * 0.5, c.y + 52.0), e["name"], HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(col, a))
		var ws := UI.fit_size(e["what"], w - 10.0, 13, 10)
		UI.text(_ui, Vector2(c.x - w * 0.5, c.y + 70.0), e["what"], ws, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_hold() -> void:
	## The hold's prompt: a pill with a ring that fills as the light drains,
	## at the bottom (over the letterbox), clear of the hero and his flame;
	## it pulses once the nudge has spoken.
	if _hold.is_empty():
		return
	var r := hold_rect()
	var pulse := 0.0
	if bool(_hold.get("nudged", false)):
		pulse = 0.5 + 0.5 * sin(float(_hold["pulse"]) * 6.0)
	var edge := Color(UI.GOLD, 0.55 + 0.45 * pulse)
	UI.panel(_ui, r.grow(2.0 * pulse), edge, Color(UI.PANEL, 0.92), r.size.y * 0.5)
	var given := 1.0 - clampf(hold_left(), 0.0, 1.0)
	var rc := Vector2(r.position.x + 23.0, r.get_center().y)
	var tb := TriBatch.new()
	tb.ring(rc, 10.0, 3.0, Color(UI.PANEL_EDGE, 0.9), 24)
	if given > 0.001:
		tb.ring(rc, 10.0, 4.0, UI.GOLD, 24, -PI * 0.5, -PI * 0.5 + TAU * given)
	tb.circle(rc, 3.0 + 2.0 * (1.0 - given), Color(UI.FLAME_MID, 0.9), 10)
	tb.flush(_ui)
	UI.text(_ui, Vector2(r.position.x + 42.0, r.position.y + r.size.y * 0.5 + 6.0), str(_hold["prompt"]), 16, UI.CREAM,
			HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)


func hold_rect() -> Rect2:
	## Where the hold's prompt sits: the bottom centre, over the letterbox,
	## moved aside (or up top) when the hero and his flame are there.
	var vs := _vs()
	var tw := UI.text_width(str(_hold.get("prompt", "")), 16, "body", 700)
	var sz := Vector2(tw + 60.0, 38.0)
	var safe := _safe()
	var y := vs.y - LETTERBOX - sz.y - 8.0
	var hero := Rect2()
	if _actor != null:
		var rs := figure_rects()
		hero = (rs.back() as Rect2).grow(10.0)
	var tries := [Vector2((vs.x - sz.x) * 0.5, y)]
	if hero.has_area():
		tries.append(Vector2(hero.position.x - sz.x - 12.0, y))
		tries.append(Vector2(hero.end.x + 12.0, y))
	tries.append(Vector2((vs.x - sz.x) * 0.5, LETTERBOX + 12.0))
	for t in tries:
		var r := Rect2(t, sz)
		if r.position.x >= safe.position.x and r.end.x <= safe.end.x and not (hero.has_area() and r.intersects(hero)):
			return r
	return Rect2(tries.back(), sz)


func _draw_pill() -> void:
	var r := _pill_rect()
	var armed := _pill_armed > 0.0
	UI.panel(_ui, r, UI.GOLD if armed else Color(UI.PANEL_EDGE, 0.7), Color(UI.PANEL, 0.8), 11.0)
	UI.text(_ui, Vector2(r.position.x, r.position.y + 15.5), "Skip?  ›" if armed else "Skip  ›", 12,
			UI.GOLD if armed else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 700)


func _draw_chooser(vs: Vector2) -> void:
	## The oath's own chooser, on the callings panel's plinths: a card under
	## each plinth; tap one to look, tap it again to choose.
	var a := clampf(float(_chooser["t"]) / 0.35, 0.0, 1.0)
	var f := UI.font("title", 700)
	var py := chooser_prompt_y()
	_ui.draw_string_outline(f, Vector2(0, py), _chooser["prompt"], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 22, 6, Color(UI.INK, a))
	_ui.draw_string(f, Vector2(0, py), _chooser["prompt"], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 22, Color(UI.GOLD, a))
	UI.text(_ui, Vector2(0, chooser_note_y()), CHOOSER_NOTE, 11, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, "body", 700, 4)
	var sel := int(_chooser["sel"])
	var cards := _chooser_cards()
	for c in cards:
		var id: String = c[0]
		var r: Rect2 = c[1]
		var info: Dictionary = Classes.ALL[id]
		var on: bool = info["enabled"]
		var col := Color(info["color"])
		var picked := PLINTHS.find(id) == sel
		if picked:
			r.position.y -= 8.0
		UI.panel(_ui, r, Color(UI.GOLD if picked else (col if on else UI.PANEL_EDGE), a * (1.0 if on else 0.5)),
				Color(UI.PANEL, 0.9 * a), 10.0)
		var name_col := Color(col if on else UI.MUTED, a * (1.0 if on else 0.6))
		UI.text(_ui, Vector2(r.position.x, r.position.y + 26.0), info["name"], 17, name_col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "title", 700)
		UI.text(_ui, Vector2(r.position.x, r.position.y + 45.0), info["role"] if on else "Sealed", 12,
				Color(UI.MUTED, a * (1.0 if on else 0.7)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if on:
			var row := chooser_ease_row(r, picked)
			UI.text(_ui, row["label"], "EASE", 10, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
			_ease_pips(row["pips"], int(info.get("ease", 3)), a)
		if picked:
			var br := chooser_choose_rect(r)
			UI.panel(_ui, br, UI.GOLD, Color("3a2a1a"), 8.0)
			UI.text(_ui, Vector2(br.position.x, br.position.y + 12.5), "Choose  ›", 12, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, "body", 700)
	if sel >= 0:
		_draw_chooser_info(PLINTHS[sel], a)
	if float(_chooser["deny"]) > 0.0:
		UI.text(_ui, Vector2(0, vs.y * 0.5), "That calling is still sealed.", 16, Color(UI.MUTED, minf(_chooser["deny"], 1.0)),
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, "body", 700, 5)


func chooser_prompt_y() -> float:
	## The prompt's baseline.
	return LETTERBOX + 29.0


func chooser_note_y() -> float:
	## The baseline of the small note under the prompt (CHOOSER_NOTE, 11 px).
	return LETTERBOX + 45.0


func chooser_ease_row(r: Rect2, picked: bool) -> Dictionary:
	## A card's ease, under its role: a small EASE, then five pips, the two
	## centred on the card together (on a picked card, above its Choose
	## button). {label: EASE's baseline start, label_w, pips: their centres}.
	var y := r.position.y + (56.0 if picked else 60.0)
	var lw := UI.text_width("EASE", 10, "body", 800)
	var span := lw + EASE_GAP + 4.0 * PIP_STEP + 2.0 * PIP_R
	var x0 := r.get_center().x - span * 0.5
	var pips := []
	for i in 5:
		pips.append(Vector2(x0 + lw + EASE_GAP + PIP_R + i * PIP_STEP, y))
	return {"label": Vector2(x0, y + 3.5), "label_w": lw, "pips": pips}


func chooser_choose_rect(r: Rect2) -> Rect2:
	## The Choose button along a picked card's foot.
	return Rect2(r.position.x + 12.0, r.end.y - 21.0, r.size.x - 24.0, 17.0)


func _ease_pips(centres: Array, lit: int, a: float) -> void:
	for i in centres.size():
		_ui.draw_circle(centres[i], PIP_R, Color(UI.GOLD if i < lit else UI.PANEL_EDGE, a))


func chooser_info_rect(id: String) -> Rect2:
	return chooser_info_layout(id)["box"]


func chooser_info_layout(id: String) -> Dictionary:
	## The looked-at calling's box, under the prompt and its note: its face;
	## its Special and its quirk, one line each; then, past a rule, its ease
	## (EASE and its pips, and what they mean: "the gentlest start"...).
	## Centred, inside the safe area. {box, size, text_x, text_end (where the
	## words must stop), ease_x}.
	var info: Dictionary = Classes.ALL[id]
	var size := _info_size(info)
	var w := 0.0
	for l in _info_lines(info):
		w = maxf(w, _info_w(l, size))
	var safe := _safe()
	var ew := _ease_col_w()
	var bw := minf(INFO_FACE + w + INFO_GAP * 2.0 + ew + INFO_PAD, safe.size.x - 8.0)
	var box := Rect2(safe.get_center().x - bw * 0.5, LETTERBOX + 51.0, bw, 54.0)
	var ex := box.end.x - INFO_PAD - ew
	return {"box": box, "size": size, "text_x": box.position.x + INFO_FACE, "text_end": ex - INFO_GAP * 2.0, "ease_x": ex}


func _ease_col_w() -> float:
	## The info box's ease column: as wide as its widest word (13 px), or
	## EASE and its pips if they're wider. The same for every calling.
	var w := UI.text_width("EASE", 10, "body", 800) + EASE_GAP + 4.0 * PIP_STEP + 2.0 * PIP_R
	for e in Keeper.EASE_WORDS:
		w = maxf(w, UI.text_width(str(e), 13))
	return ceilf(w)


func _info_lines(info: Dictionary) -> Array:
	return [[str(info["special"]), str(info["special_text"])], [str(info["quirk"]), str(info["quirk_text"])]]


func _info_size(info: Dictionary) -> int:
	## 14 px, or 13 when that's what it takes to fit the safe area (beside
	## the face and the ease column).
	var room := _safe().size.x - 8.0 - INFO_FACE - INFO_GAP * 2.0 - _ease_col_w() - INFO_PAD
	for l in _info_lines(info):
		if _info_w(l, 14) > room:
			return 13
	return 14


func _info_w(l: Array, size: int) -> float:
	## One line's width: the name in bold, a gap, the words.
	return UI.text_width(str(l[0]), size, "body", 700) + 7.0 + UI.text_width(str(l[1]), size)


func _draw_chooser_info(id: String, a: float) -> void:
	var info: Dictionary = Classes.ALL[id]
	var col := Color(info["color"])
	var L := chooser_info_layout(id)
	var br: Rect2 = L["box"]
	UI.panel(_ui, br, Color(col, 0.7 * a), Color(UI.PANEL, 0.9 * a), 10.0)
	# The calling's face, its candle burning (drawn as the hero's portrait is).
	var keep := cls
	cls = id
	_portrait("wick", "happy", Vector2(br.position.x + 33.0, br.get_center().y + 1.0), 22.0, col, a)
	cls = keep
	var size: int = L["size"]
	var x0: float = L["text_x"]
	var x1: float = L["text_end"]
	var lines := _info_lines(info)
	for i in 2:
		var y := br.position.y + 23.0 + i * 20.0
		var nw := UI.text_width(str(lines[i][0]), size, "body", 700)
		UI.text(_ui, Vector2(x0, y), lines[i][0], size, Color(col.lightened(0.35), a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
		UI.text(_ui, Vector2(x0 + nw + 7.0, y), lines[i][1], size, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, x1 - x0 - nw - 7.0)
	# Past a rule, its ease: EASE and the card's pips, then what they mean.
	var ex: float = L["ease_x"]
	var rx := ex - INFO_GAP
	_ui.draw_line(Vector2(rx, br.position.y + 10.0), Vector2(rx, br.end.y - 10.0), Color(UI.PANEL_EDGE, 0.8 * a), 1.0)
	var lw := UI.text_width("EASE", 10, "body", 800)
	UI.text(_ui, Vector2(ex, br.position.y + 23.0), "EASE", 10, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	var centres := []
	for i in 5:
		centres.append(Vector2(ex + lw + EASE_GAP + PIP_R + i * PIP_STEP, br.position.y + 19.5))
	_ease_pips(centres, int(info.get("ease", 3)), a)
	UI.text(_ui, Vector2(ex, br.position.y + 43.0), Keeper.ease_word(int(info.get("ease", 3))), 13, Color(UI.CREAM, a),
			HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 600)


# ---------------------------------------------------------------- portraits

func _preload_portrait(who: String, mood: String) -> void:
	_load_tex(Story.portrait_path(who, mood, cls))
	if who == "wick":
		for p in _hero_parts(mood):
			_load_tex(p)


func _hero_parts(mood: String) -> Array:
	## The rig's own head and candle, for a hero portrait not drawn yet.
	var dir := "res://art/heroes/%s/" % cls
	if not ResourceLoader.exists(dir + "head.svg"):
		dir = "res://art/wick/"
	var head: String = {"happy": "head_happy", "fierce": "head_fierce", "hurt": "head_hurt"}.get(mood, "head")
	if not ResourceLoader.exists(dir + head + ".svg"):
		head = "head"
	return [dir + head + ".svg", dir + "candle.svg"]


func _circle(c: Vector2, r: float, uvc: Vector2, uvr: float, n := 40) -> Array:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(uvc + d * uvr)
	return [pts, uvs]


func _portrait(who: String, mood: String, c: Vector2, r: float, col: Color, a: float, small := false) -> void:
	## A round portrait: an ink ring, the speaker's ring, the face, and its
	## candle flame burning live. small: the 128 px copy (the cast roll).
	_ui.draw_circle(c, r + 6.5, Color(UI.INK, a))
	_ui.draw_circle(c, r + 2.5, Color(col, a))
	_ui.draw_circle(c, r, Color(col.darkened(0.72), a))
	_ui.draw_circle(c, r * 0.8, Color(col.darkened(0.6), a * 0.6))
	var ppath := Story.portrait_path(who, mood, cls)
	if small and who != "wick":
		ppath = UI.hud_face(ppath)
	var tex := _load_tex(ppath)
	var white := Color(1, 1, 1, a)
	if tex != null:
		if who == "wick":
			# The hero's portrait fills the circle: its flame by where it
			# burns in the picture (0..1 across it).
			var ci := _circle(c, r, Vector2(0.5, 0.5), 0.5)
			_ui.draw_colored_polygon(ci[0], white, ci[1], tex)
			var hf := hero_portrait_flame(_hero_rigdata(), float(Classes.ALL[cls].get("flame_scale", 1.0)))
			if not hf.is_empty():
				_ui_flames.append({"p": c + (hf["uv"] - Vector2(0.5, 0.5)) * 2.0 * r, "h": float(hf["h"]) * r / 46.0})
		else:
			# A story portrait: the 128 frame, its face near (64, 62).
			var ci := _circle(c, r, Vector2(64, 62) / 128.0, 0.42)
			_ui.draw_colored_polygon(ci[0], white, ci[1], tex)
			var k := r / (0.42 * 128.0)
			var ports = manifest().get("portraits", {})
			var pm = ports.get(Story.face_of(who), {}) if ports is Dictionary else {}
			# Mother Taper's flame follows her (E7), unless the art drew this
			# mood's flame itself (taper_faint's own little one).
			var fk := taper_flame_k(mood, pm) if who == "taper" else 1.0
			for fp in portrait_flames(pm, mood):
				_ui_flames.append({"p": c + (Vector2(fp[0], fp[1]) - Vector2(64, 62)) * k, "h": float(fp[2]) * k * fk})
	elif who == "wick":
		# The rig's own head and candle, framed the same way.
		var uvc := Vector2(64, 58) / 128.0
		var uvr := 42.0 / 128.0
		for p in _hero_parts(mood):
			var t := _load_tex(p)
			if t != null:
				var ci := _circle(c, r, uvc, uvr)
				_ui.draw_colored_polygon(ci[0], white, ci[1], t)
		var tip := Vector2(60, 19)
		var rd := _hero_rigdata()
		if rd.has("flame_tip"):
			tip = Vector2(float(rd["flame_tip"][0]), float(rd["flame_tip"][1]))
		_ui_flames.append({"p": c + (tip - Vector2(64, 58)) * (r / 42.0), "h": 9.0 * r / 46.0})
	else:
		var k := r / 54.0
		var face := Story.face_of(who)
		_ui.draw_set_transform(c - Vector2(64, 62) * k, 0.0, Vector2(k, k))
		Stage.draw_portrait(_ui, face, mood)
		_ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var fp: Array = Stage.portrait_flame(face, mood)
		if not fp.is_empty():
			var fk := taper_flame_k(mood, {}) if who == "taper" else 1.0
			_ui_flames.append({"p": c + (Vector2(fp[0], fp[1]) - Vector2(64, 62)) * k, "h": float(fp[2]) * k * 1.4 * fk})
	_ui.draw_arc(c, r + 0.5, 0, TAU, 48, Color(UI.INK, a * 0.5), 1.5)


func taper_flame_k(mood: String, pm) -> float:
	## How tall Mother Taper's portrait flame burns in this scene: 1.0 well,
	## 0.35 faint, 2.0 tall, by where the scene falls in the story (a replay
	## shows her as she was). A mood the art gave its own flame keeps it.
	if pm is Dictionary and pm.get("mood_flames", null) is Dictionary and (pm["mood_flames"] as Dictionary).has(mood):
		return 1.0
	return float(Story.TAPER_FLAME.get(Story.scene_taper(scene_id), 1.0))


static func portrait_flames(pm, mood: String) -> Array:
	## A story portrait's live flames from panels.json, as [x, y, h] in its
	## 128 frame (the flame's base, and its height): the mood's own list
	## (mood_flames), else the portrait's list (flames), else its one flame;
	## none for a null flame (a skull has no candle). No height: a small one.
	var src = []
	if pm is Dictionary:
		var mf = pm.get("mood_flames", null)
		if mf is Dictionary and mf.has(mood):
			src = mf[mood]
		elif pm.get("flames", null) is Array:
			src = pm["flames"]
		elif pm.get("flame", null) is Array:
			src = [pm["flame"]]
	if src is Array and not src.is_empty() and not (src[0] is Array):
		src = [src]            # one flame given bare, [x, y, h]
	var out := []
	if src is Array:
		for e in src:
			if e is Array and e.size() >= 2 and e[0] != null and e[1] != null:
				out.append([float(e[0]), float(e[1]), float(e[2]) if e.size() > 2 and e[2] != null else 12.0])
	return out


static func hero_portrait_flame(rd: Dictionary, flame_scale := 1.0) -> Dictionary:
	## Where the hero's candle burns in his portrait, {uv (0..1 across the
	## picture), h (px at a portrait radius of 46)}, from his rig.json: its
	## portrait_flame_uv, else portrait_flame (in the portrait's viewbox, from
	## its corner) over the viewbox's size. {} when the rig says neither.
	var uv = rd.get("portrait_flame_uv", null)
	var vb = rd.get("portrait_viewbox", null)
	var pf = rd.get("portrait_flame", null)
	var out := {}
	if uv is Array and uv.size() >= 2:
		out["uv"] = Vector2(float(uv[0]), float(uv[1]))
	elif pf is Array and pf.size() >= 2 and vb is Array and vb.size() >= 4 and float(vb[2]) > 0.0:
		out["uv"] = Vector2(float(pf[0]) / float(vb[2]), float(pf[1]) / float(vb[3]))
	else:
		return {}
	out["h"] = 15.0 * float(rd.get("flame_scale", flame_scale))
	if pf is Array and pf.size() > 2 and vb is Array and vb.size() >= 4:
		out["h"] = float(pf[2]) * 92.0 / float(vb[2])
	return out


func _hero_rigdata() -> Dictionary:
	if not _rigdata_cache.has(cls):
		var d := {}
		var p := "res://art/heroes/%s/rig.json" % cls
		if FileAccess.file_exists(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary:
				d = parsed
		_rigdata_cache[cls] = d
	return _rigdata_cache[cls]
