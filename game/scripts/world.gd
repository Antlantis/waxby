extends Node2D
## One level being played. Builds everything from the LevelData and the
## hero, then runs it at the physics rate: the moving ledges, the hero and
## the calling's kit, the monsters, shots and hazards, what touches what
## (stomps, the basic attack, bonks from below, pickups, spikes, lava, pits,
## water, altars, the bell), XP and loot, the camera, and the lights handed
## to the Darkness. Emits finished() when the bell is rung, quit() and
## restart() from the pause menu.
##
## The API other scripts use (frozen; see contract.md):
##   deal(e, coef, opts) hurt_player(amount, from_x, kind, source, opts)
##   freeze(sec, force) number(pos, value, kind, key) banner(text)
##   spawn_shot(d) add_hazard(d) add_light(pos, r, s, life, tag) remove_light(id)
##   lights_tagged(tag) hero_light_radius() add_temp_ledge(rect, life)
##   enemies_in(rect) spawn_enemy(kind, pos, opts) gain_xp(n, at)
##   drop_item(at, source) place_item(item, at, vel) apply_hero() play_beat(id, then) fell(kind)
##   tells_mult() dust_at(p) bark(key)
##   vars: kit features diff area player rig hud touch glow level
##
## v3 (contract.md §5, frozen at Phase 0):
##   ftime (the feature clock) stop_time(sec, caller) time_stopped()
##   push_player(vel, sec, tag) add_light(pos, r, s, life, tag, tint)
##   set_dark(color, sec) set_warm(color, sec) lit_at(p, pad, opts)
##   dim(key, mult, sec) undim(key) light_override(r) vine_present(x, y)
##   belt_dir(cell, dir) add_bell(floor_pos, swing, {silver}) elite_rules()
##   hazards "beam" {seg, width} and "pit_band" {rect, fall}
##   the mode hooks (mode.gd): diff strength on_build on_tick on_spawn
##   on_snuffed allows stats_filter tells_mult elite_rules loot lights
##   result_extra; the boss's is_open configure checkpoint reset_fight(keep)
##   vars: mode world_n lights (world_lights.gd when it's there) movers
##
## Build 2 (twists.gd, from an optional `twist:` header; none, none of this):
##   twist_id() twist(rule) twist_heal() title_sub() twist_cards()
##   vars: twists (its runtime, or null)

signal finished(result: Dictionary)
signal quit
signal restart
signal enemy_killed(enemy: Node2D, how: String)
signal secret_rung(level_id: String)
signal boss_near                 # once a level: Waxby reached its last altar before the boss (main asks for the boss's scene then)

const LevelData := preload("res://scripts/level_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const RigScript := preload("res://scripts/wick_rig.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const TileView := preload("res://scripts/tile_view.gd")
const BackdropScript := preload("res://scripts/backdrop.gd")
const GlowScript := preload("res://scripts/glow.gd")
const HudScript := preload("res://scripts/hud.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const PauseScript := preload("res://scripts/pause_menu.gd")
const FeaturesScript := preload("res://scripts/level_features.gd")
const Movers := preload("res://scripts/movers.gd")
const AutoBot := preload("res://scripts/autoplay_bot.gd")
const Relics := preload("res://scripts/relics.gd")
const Combat := preload("res://scripts/combat.gd")
const Classes := preload("res://scripts/classes.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Progression := preload("res://scripts/progression.gd")
const Floaters := preload("res://scripts/floaters.gd")
const Playlog := preload("res://scripts/playlog.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const Themes := preload("res://scripts/themes/loader.gd")
const DARKNESS := preload("res://shaders/darkness.gdshader")
const UI := preload("res://scripts/ui.gd")
const TILE := LevelData.TILE
const MAX_LIGHTS := 48
const BELOW := 160.0             # px of stone under the level's last row (TileView draws 5 rows)
# The camera holds a standing hero's feet FEET_CLEAR px over the highest of
# the thumb buttons (the Special with its resource arc, and the flask), so
# a monster on his floor is never behind one (feet_line). A jump that takes
# his feet above FEET_TOP (view y) lifts the camera with him, so the tip of
# his flame (HERO_TALL over his feet) stays on the glass. Where he's under
# one of the HUD's corner blocks (the level badge, the life bar, the ember
# count; the sigils and the pause button), as at a level's start and end
# where the camera stops at the edge, it goes up with him sooner
# (head_top), so the tip of his flame stays FEET_CLEAR under the block.
const FEET_CLEAR := 7.0
const FEET_TOP := 84.0
const HERO_TALL := 76.0          # his feet to the tip of his flame (view px)
const HERO_HALF := 12.0          # half his width, helmet and flame
const HEAD_EASE := 900.0         # px/s that stop moves down the glass when he goes under a block mid-air
# Where a tell hangs over him (a drip spout's glint, a Dripkin, a Bonebow on
# a ledge, a Flit's roost with the rise of its wind-up, a Gutterwing nest)
# higher than the feet line shows, the camera leans up, lowering his feet by
# up to this much (to the line it held before the thumbs were taken into
# account), so the tell isn't off the top of the glass. Flits and nests
# tell only in plain view, so one too high even for that waits.
const LOOK_UP_MAX := 52.0
# Spec §4.1 rule 3 (nothing knocks Wick into a pit without a tell), from
# World 5 on, where the floor is gone (the rev5 review: a Glassmite's touch
# on 2-wide glass sent him into the void): a contact knock that would carry
# him off a floor edge over a pit, the void or deep water loses its sideways
# part; one that lands while he's airborne over one keeps his own drift.
# W1-W4 keep their knock (their play is the owner's, unchanged).
const KNOCK_BRAKE_FROM := 5
const KNOCK_REACH := 112.0        # px a contact knock carries him (210 px/s unsteered, then its arc)
const KNOCK_AIR := 0.5            # s a knock's arc keeps him aloft (it carries him vx x this)
const KNOCK_EDGE := 10.0          # px short of the edge a braked knock sets him down
const ARENA_FACE := 28.0         # px past a v3 boss's face the camera leans to keep on the glass (_arena_lean)
const ARENA_EDGE := 64.0         # px Waxby keeps inside the view's safe edge while it leans
const SPIKE_PCT := 0.20
const HITSTOP_BUDGET := 0.12     # at most this much freeze in any half second
const FULL_RETRY := 1.2          # s before an item the full satchel turned away asks again
const LEGEND_FREEZE := 0.25      # s the world stops when a Legendary is taken (_legend_moment)
const CHAIN_PAY_MAX := 4         # bonus embers a single chained stomp pays at most
const PUSH_CAP := 170.0          # px/s: every push together, on every difficulty
const GUST_GRACE := 0.8          # a gust that starts while he's airborne waits until he lands, or this long
const SHOT_KINDS := ["shot", "arrow", "beam", "shard", "glass", "icicle", "bolt"]   # shot_dr counts on these
const OWN_SHARE := ["pit", "lava", "water", "void", "tide"]   # their own share of life: never clamped
const LAB_KEEPS_NOT := ["xp", "loot", "record"]   # what a feel lab never pays (allows)
const V2_BOSSES := ["tollgrave", "snuffer"]       # their phase barks stay v2's (boss_phase)
# Spec §8: a Legendary the hero already holds is a third as likely. Off in
# Phase 0 (it changes which Legendary a W1-W2 drop gives); on since the
# wave-1 merge (decisions.md: "turn on with Phase 1"): a W1-W2 drop still
# picks among v2's twelve, weighted away from the ones the hero holds.
const PREFER_UNOWNED := true
# The blow clamp (Combat.BLOW_CLAMP) on v2's eight main levels too. Off in
# Phase 0: W1-W2 play as v2 did (an under-levelled hero's big blow there still
# lands in full). The owner's call whether v3 turns it on for them (it guards
# the Taperwitch); v3's own levels, the secrets, the labs and the modes clamp.
const CLAMP_V2_LEVELS := false
const WORLD_LIGHTS := "res://scripts/world_lights.gd"   # W0-render's packer and dim pipeline (when it's there)
const AMBIENT := "res://scripts/ambient.gd"              # W0-render's motes (when it's there)
const EDGE_LINES := "res://scripts/edge_lines.gd"        # W0-render's readability lines (when it's there)
const STORY := "res://scripts/story.gd"
const ChoiceCard := preload("res://scripts/choice_card.gd")
const Rites := preload("res://scripts/rites.gd")
const Twists := preload("res://scripts/twists.gd")
const RITES_CLEAR := 200.0       # an altar's Rites open with no monster awake this near (px)...
const RITES_LEASH := 480.0       # ...waiting for it only while he's this near the altar
const BOON_WAIT := 1.0           # s of play after a boss's fall before his boon opens (his drops land first)
# Dims that aren't floored (scripted boss moves: Swallow the Light, the finale's give).
const DIM_EXEMPT := "script:"
const DROP_WEIGHTS := {
	"dusk": {"common": 60, "magic": 32, "rare": 7.5, "legendary": 0.5},
	"nightfall": {"common": 45, "magic": 40, "rare": 13, "legendary": 2},
	"witching": {"common": 30, "magic": 45, "rare": 21, "legendary": 4},
	"anointed": {"magic": 70, "rare": 27, "legendary": 3},
	"dread": {"rare": 92, "legendary": 8},
	"boss": {"magic": 50, "rare": 42, "legendary": 8},
	"lidlurk": {"magic": 60, "rare": 36, "legendary": 4},
	"gold": {"rare": 92, "legendary": 8},
}


var level: RefCounted
var level_id := ""
var player: Node2D
var rig: Node2D
var kit: Object
var features: Object
var camera: Camera2D
var backdrop: Node2D
var glow: Node2D
var hud: CanvasLayer
var touch: CanvasLayer
var pause_menu: CanvasLayer
var boss: Node2D = null
var warden: Node2D = null       # a secret level's Warden (level.warden, placed with D): a boss bar of its own
var _warden_bar := false        # its bar is up
var enemies: Array = []
var pickups: Array = []         # {kind, pos, vel, t, taken, loose, ...}
var blocks := {}                # Vector2i -> {contents, spent, sprite, bump}
var movers: Array = []
var crumbles := {}              # Vector2i -> {state, timer}
var sconces: Array = []         # flame points
var altars: Array = []          # {cell, pos, flame, lit, glow, sprite}
var bells: Array = []           # {pos, rope: Rect2, sprite, beam, swing, rung}
var signs: Array = []           # {pos, text, node}
var shots: Array = []           # see spawn_shot
var hazards: Array = []         # see add_hazard
var bolts: Array = []           # old name kept empty: shots replaced them
var chunks: Array = []
var spawns: Array = []          # {kind, cell, opts} to respawn ordinary monsters from
var floaters := Floaters.new()
var checkpoint := Vector2.ZERO
var diff := "dusk"
var area := 1
var strength := "normal"
var embers_got := 0             # picked up this level (banked or not), in worth: kills and chains too
var embers_carried := 0         # not banked yet: lost to the pool on a snuff
var embers_total := 0           # the level's own embers, in pieces: placed 'o's + 3 per ember reliquary
var embers_placed := 0          # of those, how many pieces were taken (never worth, never drops)
var sigils_got := [false, false, false]
var relics_found: Array = []
var items_found: Array = []
var xp_gained := 0
var levels_gained := 0
var level_start := 1
var snuffs := 0
var snuff_causes := {}
var _pool_cause := "hit"        # v2's snuff cause (a hit's was set after it landed; a fall's before): where the pool goes
var flask_uses := 0
var flask_charges := 1
var _flask_t := -1.0             # seconds into a drink, -1 when not drinking
var pool := {}                  # the Guttered Pool: {pos, embers, t}
var time := 0.0
var snuff_time := 0.0
var clear_time := 0.0
var state := "play"             # play, dead, clear
var paused := false
var hitstop := 0.0
var _hitstop_spent: Array = []   # [time, amount] in the last half second
var shake := 0.0
var cam := Vector2.ZERO
var _look := 0.0
var _cam_y_target := 0.0
var _feet_y := -1.0             # feet_line(), refreshed every half second
var _feet_t := 0.0
var _ui_cover := {}             # _ui_shapes() for in_plain_view (view px), refreshed with _feet_y
var _head_y := FEET_TOP         # the stop in use (head_top, eased when it comes down mid-air)
var _ember_streak := 0
var _ember_streak_t := 0.0
var _phoenix_used := false      # the Phoenix Wick has risen in this level (a new level is a new World)
var _darkness: Control
var _dark_mat: ShaderMaterial
var ambient: Node2D = null      # ambient.gd on the glow layer (when it's there)
var edges: Node2D = null        # edge_lines.gd on the glow layer (when it's there)
var hero_flame := {}            # the hero's flame palette (glow.flame's pal), {} = the candle's own
var _flame_id := ""             # the hero's cosmetic flame (Cosmetics.FLAMES id), for one that cycles
var _pad := {}
var _prev := {}                 # test_pad: the last held state of each button
var _latched := {}              # edges pressed during a freeze, delivered after
var _special_held := false
var _special_t := 0.0
var _dyn_lights := {}           # id -> {p, r, s, life, tag}
var _next_light := 1
var _last_attack_scanned := -1
var _t := 0.0
var _last_altar_hp: Array = []
var chain := 0                  # stomps and bounces since last touching the floor
var _chain_wax_given := false
var _twin_ready := true         # the Twin Wick's spare flame (a legendary candle)
var bone_wards := 0             # the Ossuary Coat's wards
var _basics := 0                # basic attacks so far (Dawnsliver: every 3rd)
var _knuckle_shots := 0         # hero shots so far (the Saint's Knuckle: every 3rd pierces)
var owls_eye := false           # the Owl's Eye is worn: glow twinkles sigils, false stone, mimics
var _hurt_barked := false       # the first-hurt bark was asked for in this level
var _tips_done := false         # both thumb tips (TIPS) are seen in this save
var _trail_t := 0.0
var _heart_t := 0.0
var _lowpass_on := false
var rng := RandomNumberGenerator.new()
var headless := false           # tests: no HUD, no touch, no sounds needed
var no_display := DisplayServer.get_name() == "headless"   # no screen at all (a --headless run): no choice stops play (player_block)
var test_pad = null             # tests feed a pad Dictionary here instead of Input
var autoplay := false           # a bot at the controls (debug: main's --autoplay)
var play_beats := false         # debug (main's --story): the bot's level plays its beats over the level, as a player's does
var last_stomp_boss := false    # the last stomp bounced off the boss (or a prop of his: a bell, a seed); the kits read it
var _near_sent := false         # boss_near emitted
var _spur_tops := {}            # Vector2i -> true: the standing cells of the blocks Spurwheels roll round (safe_vetoed)
var _spur_done := false
var _auto_i := 0
var _bot: RefCounted = null     # the autoplay bot's route (autoplay_bot.gd)
var no_monsters := false        # build without monsters (golden routes: tools/record_route.gd, tests/test_routes.gd)
var on_pad: Callable            # called with the pad each physics tick, after it's read (the route recorder)
# v3
var ftime := 0.0                # the feature clock: every unpaused tick (hitstop too), not during stop_time
var _stop_t := 0.0
var _stop_caller: Node = null
var mode = null                 # a mode controller (scripts/modes/mode.gd), or null
var world_n := 0                # the level's world (a mode may set its room's biome world)
var lights: RefCounted = null   # world_lights.gd when it exists (the v3 packer); else the v2 packer here
var _pushes := {}               # key -> {v, t, grace, tag}
var _push_n := 0
var _dims := {}                 # key -> {mult, t}
var _dim_on := false
var _light_override := -1.0
var _dark_to := {}              # set_dark: {from, to, t, dur}
var _warm_to := {}              # set_warm
var _boss_opts := {}            # what configure() was handed (a mode's boss)
var secret_found := ""          # the secret level a silver bell opened here
var secret_new := false         # its bell opened it just now, the first time (find_secret at the ring)
var phase_reached := 0          # the boss's highest phase
var snuff_sections: Array = []  # [{x, cause, move}]
var _hollin_ready := true       # Hollin's Ember: once per altar
# v3's Legendary and relic powers (their numbers are in stats.flags: items.gd
# LEGENDS fx, relics.gd; PR's request, wired at the wave-1 merge).
var _lastcandle_ready := true   # The Last Candle: once per altar
var _hoarfrost_at := -99.0      # Hoarfrost Mantle: the feature clock it may freeze again at
var _escape_shots := 0          # The Escapement on a thrower or caster: basic shots so far
var _flute_kills := 0           # the Bone Flute: kills so far
var special_override := {}      # merged into touch.special_state (the finale's hold ring)
var bot_us := 0                 # --autoplay: µs the debug bot's own planning took (the perf line reports it apart from phys)
var finale_black := 0.0         # the finale's black (0..1): the HUD covers the level with it, the touch controls fade by it
var _mode_after_snuff := ""     # what the mode said to a snuff: "" | "restart" | "end"
# "Continue from the altar" (spec §9.1, P1): main sets resume (Game.suspended())
# before add_child to start the level at the altar it was left at; the World
# writes the snapshot as each altar is lit and drops it when the level is left.
var resume := {}                # {level, diff, altar, time, sigils, embers_carried, killed, taken, opened, at}
var _killed: Array = []         # level.entities indices of the placed monsters killed so far
var _taken: Array = []          # ...and of the placed embers and wax taken
var _opened: Array = []         # the reliquaries opened ([x, y])
# The Altar Rites (rites.gd): an altar lit with a skill point waiting offers
# skills on the choice card (offer_choice), at once or once the area clears.
var choice: Control = null      # choice_card.gd over the level (made the first time one is offered)
var _rites_altar := -1          # the altar whose Rites wait to open (-1: none)
var _rites_wait := 0.0          # s they've waited on a title card going
var _rites_snuffed := -1        # the altar whose waiting Rites a snuff cut off: they wait again when he relights there
var _relic_wait: Array = []     # relics found this visit with the belt full: the next lit altar offers each (open_relic)
# The Boss Boons: a boss's first kill offers his prize on the same card
# (open_boon), once his fall has settled (_tick_boon).
var _boon := {}                 # {at, who, t, wait}: a boss's boon waiting to open ({}: none)
# Build 2: the level's twist (twists.gd), from its optional `twist:` header;
# null with none (or in a mode), and then nothing below changes a thing.
var twists: RefCounted = null
var _twist_id = null            # the header's id, read once (twist_id)


func setup(p_level: RefCounted, p_headless := false) -> void:
	level = p_level
	level_id = level.id
	headless = p_headless
	rng.seed = hash(level_id + str(Game.data.get("run_counter", 0)))


func _ready() -> void:
	_build()
	_warm_haptics()


func _warm_haptics() -> void:
	## iOS starts its haptic engine (Core Haptics) on the first vibration,
	## blocking the thread that asks: the rev5 review matched the phone's one
	## 50-65 ms first-use frame in every level to the session's first haptic
	## (a hit, a bonk), 4-7 s in. A 1 ms pulse at 1% while the level builds (a
	## frame that's long anyway) starts it here; the engine shuts itself down
	## after a quiet while, so every level build asks again. (Desktop: a no-op.)
	if headless or not Game.haptics or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(1, 0.01)


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _build() -> void:
	if ResourceLoader.exists(WORLD_LIGHTS):
		# W0-render's lights: the packer, lit_at, the dims, the dark itself.
		lights = load(WORLD_LIGHTS).new(self)
	diff = Game.diff()
	strength = str(Game.setting("candle_strength"))
	if mode != null:
		# A mode (the Descent, the Waxworks, a Trial) says first.
		diff = str(mode.diff())
		strength = str(mode.strength())
	area = level_area()
	world_n = int(level.world)
	flask_charges = flask_max()
	floaters.mode = str(Game.setting("numbers"))
	var view := _view_size()
	backdrop = BackdropScript.new()
	backdrop.z_index = -10
	add_child(backdrop)
	backdrop.build(_theme(), level.pixel_size(), view)

	# Tiles, in chunks the canvas can cull.
	var n := ceili(float(level.width) / TileView.CHUNK)
	for i in n:
		var tv := TileView.new()
		tv.level = level
		tv.col0 = i * TileView.CHUNK
		tv.world = self
		add_child(tv)
		chunks.append(tv)

	var under := Node2D.new()
	under.name = "Under"
	under.draw.connect(func(): if features: features.draw_under(under))
	add_child(under)
	var props := Node2D.new()
	props.name = "Props"
	add_child(props)
	var monsters := Node2D.new()
	monsters.name = "Monsters"
	add_child(monsters)

	# Reliquaries and slabs.
	for y in level.height:
		for x in level.width:
			var t: int = level.tile(x, y)
			if t == LevelData.BLOCK or t == LevelData.SPENT:
				var cell := Vector2i(x, y)
				var contents: String = level.blocks.get(cell, "")
				var s := _sprite("res://art/props/%s.svg" % ("reliquary_gold" if contents == "relic" else ("reliquary" if t == LevelData.BLOCK else "reliquary_spent")), 0.25)
				s.centered = false
				s.position = Vector2(x * TILE, y * TILE)
				props.add_child(s)
				blocks[cell] = {"contents": contents, "spent": t == LevelData.SPENT, "sprite": s, "bump": 0.0}
				if contents == "embers" and t == LevelData.BLOCK:
					embers_total += 3
			elif t == LevelData.CRUMBLE:
				crumbles[Vector2i(x, y)] = {"state": "idle", "timer": 0.0}

	for mv in Movers.from_level(level):
		var node := Node2D.new()
		node.set_script(load("res://scripts/mover_view.gd"))
		node.set("length", mv.length)
		if world_n >= 3 and Themes.has_theme(str(level.theme)):
			node.call("set_theme", Themes.palette(str(level.theme)), world_n)
		node.position = mv.pos
		props.add_child(node)
		mv.node = node
		movers.append(mv)

	var cls: String = Game.hero()["cls"]
	if not _resuming():
		resume = {}
	var ei := -1
	for e in level.entities:
		ei += 1
		var cell: Vector2i = e["cell"]
		var floor_pos := LevelData.cell_floor(cell)
		match e["kind"]:
			"ember":
				embers_total += 1
				if _resume_has("taken", ei):
					embers_placed += 1
					continue
				var p := _add_pickup("ember", LevelData.cell_center(cell))
				p["placed"] = true
				p["ent"] = ei
			"wax":
				if _resume_has("taken", ei):
					continue
				var pw := _add_pickup("wax", LevelData.cell_center(cell))
				pw["ent"] = ei
			"sigil":
				var p := _add_pickup("sigil", LevelData.cell_center(cell))
				p["index"] = e["index"]
				if Game.sigil_found(level_id, e["index"]):
					p["ghost"] = true
			"sconce":
				var s := _sprite(prop_path("sconce"), 0.25)
				s.centered = false
				s.position = Vector2(cell.x * TILE, cell.y * TILE)
				props.add_child(s)
				# W6's `c` is a dead sconce (the theme's sconce_light false,
				# spec §3.2): its sprite, but no light and no flame.
				if bool(Themes.theme(str(level.theme)).get("sconce_light", true)) or not Themes.has_theme(str(level.theme)):
					sconces.append(Vector2(cell.x * TILE + 16, cell.y * TILE + 7))
			"altar":
				var s := _sprite(prop_path("altar"), 0.25)
				s.centered = false
				s.position = floor_pos - Vector2(16, 48)
				props.add_child(s)
				altars.append({"cell": cell, "pos": floor_pos, "flame": floor_pos - Vector2(16, 48) + Vector2(16, 11), "lit": false, "glow": 0.0, "sprite": s})
			"bell":
				add_bell(floor_pos, 0.0)
			"sign":
				var s := Node2D.new()
				s.set_script(load("res://scripts/sign_view.gd"))
				s.position = floor_pos
				props.add_child(s)
				var text: String = e["text"]
				var sign_info: Dictionary = Classes.info(cls)
				text = text.replace("{special_tip}", str(sign_info.get("sign_tip", sign_info["special_text"])))
				text = text.replace("{special}", sign_info["special"]).replace("{calling}", sign_info["name"])
				signs.append({"pos": floor_pos, "text": text, "node": s})
			"boss":
				var bk: String = level.boss if level.boss != "" else "tollgrave"
				var b := spawn_enemy(bk, floor_pos, {"cell": cell, "boss": true})
				if b:
					boss = b
					if b.has_signal("woke"):
						b.woke.connect(_on_boss_woke)
			"dread":
				if _resume_has("killed", ei):
					continue
				if not level.dread.is_empty():
					var dk: String = level.dread["kind"]
					var de := spawn_enemy(dk, EnemyKinds.spawn_pos(dk, cell), {"tier": "dread", "name": level.dread["name"], "omens": level.dread.get("omens", []), "cell": cell})
					if de:
						de.spawn["ent"] = ei
				elif not level.warden.is_empty() and EnemyKinds.known(str(level.warden["kind"])):
					# A secret level's Warden (contract §2.3, §6.1): tier "warden"
					# (enemy.gd's WARDEN_LIFE, x1.25 damage), its Omens, and a boss
					# bar while it's awake (_update_warden_bar).
					var wk: String = level.warden["kind"]
					warden = spawn_enemy(wk, EnemyKinds.spawn_pos(wk, cell), {"tier": "warden", "name": level.warden["name"],
							"omens": level.warden.get("omens", []), "cell": cell})
			_:
				if EnemyKinds.known(e["kind"]):
					if _resume_has("killed", ei):
						continue
					var ek: String = e["kind"]
					var en := spawn_enemy(ek, EnemyKinds.spawn_pos(ek, cell), {"cell": cell})
					if en:
						en.spawn["ent"] = ei
					if en and en.ordinary:
						spawns.append({"kind": ek, "cell": cell})

	# The hero.
	player = PlayerScript.new()
	player.level = level
	player.world = self
	var info: Dictionary = Classes.info(cls)
	var kit_path: String = info["kit"]
	kit = load(kit_path).new() if ResourceLoader.exists(kit_path) else load("res://scripts/kits/kit.gd").new()
	kit.cls = cls
	player.kit = kit
	player.quirk = info["quirk_id"]
	rig = RigScript.new()
	rig.cls = cls
	rig.player = player
	rig.kit = kit
	player.add_child(rig)
	add_child(player)
	checkpoint = LevelData.cell_floor(level.start)
	player.reset_at(checkpoint)
	player.facing = int(level.facing)   # `facing: left`: he starts facing the way the level runs
	apply_hero()
	player.hp = player.max_hp
	player.res = float(info["res_start"]) if float(info["res_max"]) > 0.0 else 0.0
	player.res = minf(player.res, player.res_max)
	player.double_jump = Game.equipped("rook_feather")
	kit.setup(player, self)
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)
	player.attacked.connect(_on_attacked)
	player.hurt_taken.connect(_on_hurt)
	player.snuffed.connect(_on_snuffed)
	player.stepped.connect(func(): _sfx("step"))
	level_start = int(Game.hero()["level"])
	if mode == null and not is_lab() and Game.has_method("note_area"):
		Game.note_area(area)   # the hero's deepest area (the Chandler stocks by it)

	features = FeaturesScript.new()
	features.build(self, level)
	features.assign_elites(rng)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	cam = cam_on(player.position)
	_cam_y_target = cam.y
	camera.position = cam

	var glow_layer := CanvasLayer.new()
	glow_layer.layer = 2
	glow_layer.follow_viewport_enabled = true
	add_child(glow_layer)
	# Under glow: the readability lines (edge_lines.gd), then the motes
	# (ambient.gd), once W0-render's files are there.
	if ResourceLoader.exists(EDGE_LINES):
		edges = load(EDGE_LINES).new()
		glow_layer.add_child(edges)
		edges.build(level, world_n, "", self)
	if ResourceLoader.exists(AMBIENT):
		ambient = load(AMBIENT).new()
		ambient.world = self
		glow_layer.add_child(ambient)
		ambient.set_theme(level.theme)
	glow = GlowScript.new()
	glow.world = self
	glow_layer.add_child(glow)

	var dark_layer := CanvasLayer.new()
	dark_layer.layer = 1
	add_child(dark_layer)
	if lights != null and lights.has_method("attach"):
		# The dark: Plan A (darkness.gdshader) or Plan B (the field at a
		# quarter size), as world_lights.gd's setting says.
		_darkness = lights.attach(dark_layer)
		_dark_mat = lights.material()
	else:
		var dr := ColorRect.new()
		dr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dark_mat = ShaderMaterial.new()
		_dark_mat.shader = DARKNESS
		dr.material = _dark_mat
		dark_layer.add_child(dr)
		_darkness = dr
	_apply_theme_dark()
	# The twist's runtime (its painters go beside the monsters and the glow).
	twists = Twists.make(self)

	kit.on_level_start()
	if autoplay:
		_bot = AutoBot.new()
		_bot.setup(self)
	if not headless:
		hud = HudScript.new()
		hud.world = self
		add_child(hud)
		touch = TouchScript.new()
		add_child(touch)
		touch.pause_pressed.connect(open_pause)
		pause_menu = PauseScript.new()
		pause_menu.world = self
		add_child(pause_menu)
		Sfx.play_music(level.music)
		sync_music()
		var beat: String = level.story.get("start", "")
		if beat != "" and not Game.seen(beat):
			play_beat(beat, func():
				hud.title_card(title_sub(), level.title)
				_twist_cards())
		else:
			hud.title_card(title_sub(), level.title)
			_twist_cards()
	if not is_lab():
		Game.next_run()   # (a lab's runs aren't counted: it writes nothing)
	_refresh_look()      # the hero's flame, before a mode's on_build overrides it
	_apply_resume()
	if mode != null:
		mode.on_build(self)


func level_area() -> int:
	## The area level this level plays at: area_abs when set (the modes), else
	## the header's area through the difficulty (Combat.level_area when it's there).
	if int(level.get("area_abs")) >= 0:
		return int(level.area_abs)
	if _combat_has("level_area"):
		return int((Combat as Script).call("level_area", level, diff))
	return Combat.area_level(level.area, diff)


static func _combat_has(fn: String) -> bool:
	for m in (Combat as Script).get_script_method_list():
		if m["name"] == fn:
			return true
	return false


static func _combat_const(key: String, fallback):
	return (Combat as Script).get_script_constant_map().get(key, fallback)


func _theme() -> String:
	return level.theme


func _apply_theme_dark() -> void:
	var c: Dictionary = backdrop.colors()
	var dark := {"nave": Color(0.30, 0.25, 0.42), "crypt": Color(0.24, 0.30, 0.32), "choir": Color(0.40, 0.24, 0.24), "tower": Color(0.26, 0.28, 0.46)}
	var col: Color = c.get("dark", dark.get(_theme(), dark["nave"]))
	var bright := float(Game.setting("brightness"))
	if lights != null and lights.has_method("theme_dark"):
		lights.theme_dark(col, bright)
	else:
		_dark_mat.set_shader_parameter("dark_color", col.lightened(bright))


func _sprite(path: String, sc: float) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(path):
		s.texture = load(path)
	s.scale = Vector2(sc, sc)
	return s


func _add_pickup(kind: String, pos: Vector2) -> Dictionary:
	var p := {"kind": kind, "pos": pos, "vel": Vector2.ZERO, "t": randf() * 3.0, "taken": false, "loose": false, "age": 0.0}
	if kind == "wax" or kind == "sigil":
		var path := {"wax": "res://art/props/wax.svg", "sigil": "res://art/props/sigil.svg"}.get(kind, "")
		var s := _sprite(path, 0.25)
		s.position = pos
		get_node("Props").add_child(s)
		p["sprite"] = s
	pickups.append(p)
	return p


func _view_size() -> Vector2:
	if not is_inside_tree():
		return Vector2(844, 390)
	return get_viewport_rect().size


func view_rect() -> Rect2:
	var v := _view_size()
	return Rect2(cam - v * 0.5, v)


# ---------------------------------------------------------------- the API

func apply_hero() -> void:
	## Re-derives the hero's numbers (level up, gear, relics), keeping life %,
	## on this World's difficulty; a mode may filter them (a Trial's loadout).
	if mode == null and diff == Game.diff():
		Game.apply_hero(player)
	else:
		var h: Dictionary = Game.hero()
		var st: Dictionary = Hero.stats(h, h.get("belt", []), diff)
		if mode != null:
			st = mode.stats_filter(st)
		player.set_stats(st)
	player.double_jump = Game.equipped("rook_feather")
	owls_eye = Game.equipped("owls_eye")
	_refresh_look()      # a flame worn from pause's Sheet shows at once


const COSMETICS := "res://scripts/modes/cosmetics.gd"   # MO's flames (when they're there)


func _refresh_look() -> void:
	## world.hero_flame from the hero's look (Cosmetics.hero_pal of what he
	## owns and wears; {} is Tallow, the candle's own). A mode's on_build and
	## its tick override it; with no mode a cycling flame turns in tick.
	if not ResourceLoader.exists(COSMETICS):
		return
	var gs := _game()
	if gs == null or not gs.has_method("look") or not gs.has_method("has_cosmetic"):
		return
	var C = load(COSMETICS)
	var lk: Dictionary = C.look_of({"look": gs.look()}, func(n): return gs.has_cosmetic(n))
	_flame_id = str(lk.get("flame", ""))
	hero_flame = C.hero_pal(lk, ftime)


func tells_mult() -> float:
	var m := float(Combat.diff(diff)["tells"])
	if mode != null:
		m *= float(mode.tells_mult())
	return m


func allows(what: String) -> bool:
	## A mode's gates: xp loot embers record special flask pool. A feel lab
	## (lab-*, off a mode) keeps nothing in the save either: no XP, no loot,
	## no record (LAB_KEEPS_NOT; its embers count in the level but are never
	## banked: _bank). The playlog still has every attempt.
	if mode != null:
		return bool(mode.allows(what))
	return not (is_lab() and LAB_KEEPS_NOT.has(what))


func is_lab() -> bool:
	## A feel lab (lab-0, lab-1): played with the hero, written nowhere.
	return mode == null and level_id.begins_with("lab-")


func flask_max() -> int:
	## The flask's charges: a mode's own when it says (the Descent's Deep
	## Flask, the Waxworks' Dry Flask), else Game.flask_charges(diff)
	## (draughts, flask_add) when it's there, else the difficulty's.
	if mode != null and mode.has_method("flask_max"):
		return int(mode.flask_max())
	var g := _game()
	if mode == null and g != null and g.has_method("flask_charges"):
		return int(g.flask_charges(diff))
	return int(Combat.diff(diff)["flask_charges"])


func flask_heal() -> float:
	## A drink's share of life: a mode's own when it says, else
	## Game.flask_heal(diff) (the Rich Draught, flask_pct) when it's there,
	## else the difficulty's; x the dry twist's cut (twist_heal).
	if mode != null and mode.has_method("flask_heal"):
		return float(mode.flask_heal())
	var g := _game()
	if mode == null and g != null and g.has_method("flask_heal"):
		return float(g.flask_heal(diff)) * twist_heal()
	return float(Combat.diff(diff)["flask"]) * twist_heal()


static func _arity(sc: Script, fn: String) -> int:
	for m in sc.get_script_method_list():
		if m["name"] == fn:
			return (m["args"] as Array).size()
	return -1


func _pick_slot() -> String:
	## A drop's slot: among Items.live_slots(area) when it's there (boots
	## from area 13, charms from 18), else v2's.
	var its := Items as Script
	if _arity(its, "live_slots") >= 1:
		return Items.pick_slot(rng, its.call("live_slots", area))
	return Items.pick_slot(rng)


func _pick_legend(slot: String, cls: String, pool: Array = []) -> String:
	## Items.pick_legend with the area and the Legendaries found (v3's
	## signature) when it takes them, else v2's. With PREFER_UNOWNED, the
	## hero's own (worn or carried) weigh a third (spec §8: x3 for the rest).
	## pool (a boss's first kill: Items.world_legends) picks among those.
	var its := Items as Script
	var owned: Array = []
	if PREFER_UNOWNED:
		var gs = _game()
		if gs != null:
			(gs.get_script() as Script).call("_legends_held", gs.hero(), owned)
	if not pool.is_empty():
		return _pick_among(pool, owned)
	if _arity(its, "pick_legend") >= 6 and not owned.is_empty():
		var g := _game()
		var found: Array = g.legends_found() if g != null and g.has_method("legends_found") else []
		return str(its.call("pick_legend", slot, cls, rng, area, found, owned))
	if _arity(its, "pick_legend") >= 5:
		var g := _game()
		var found: Array = g.legends_found() if g != null and g.has_method("legends_found") else []
		return str(its.call("pick_legend", slot, cls, rng, area, found))
	return Items.pick_legend(slot, cls, rng)


func _pick_among(pool: Array, owned: Array) -> String:
	## One of pool (a world's boss pair), the hero's own weighing a third.
	var total := 0.0
	for id in pool:
		total += 1.0 if owned.has(id) else 3.0
	var x := rng.randf() * total
	for id in pool:
		x -= 1.0 if owned.has(id) else 3.0
		if x <= 0.0:
			return str(id)
	return str(pool[pool.size() - 1])


func ember_worth() -> int:
	## One ember pickup's worth: Combat.ember_worth(area, diff) when it's there
	## (else the difficulty's, v2), x (1 + the hero's ember_pct), x a mode's
	## loot().embers; nothing when the mode doesn't allow embers.
	var worth := int(Combat.diff(diff)["embers"])
	if _combat_has("ember_worth"):
		worth = int((Combat as Script).call("ember_worth", area, diff))
	var pct := float(player.stats.get("ember_pct", 0.0)) if player != null else 0.0
	if pct != 0.0:
		worth = roundi(worth * (1.0 + pct))
	if mode != null:
		if not allows("embers"):
			return 0
		worth = roundi(worth * float(mode.loot().get("embers", 1.0)))
	return worth


func elite_rules() -> Dictionary:
	## {anoint, max_anoint, omens, second_omen}: Combat.elite_rules(diff, world)
	## merged with the mode's (elites.gd reads it).
	var out := {}
	if _combat_has("elite_rules"):
		out = (Combat as Script).call("elite_rules", diff, world_n, mode == null)   # (a mode keeps v3's Dusk rows)
	else:
		var d := Combat.diff(diff)
		out = {"anoint": float(d.get("anoint", 0.0)), "max_anoint": int(d.get("max_anoint", 0)),
				"omens": int(d.get("omens", 1)), "second_omen": float(d.get("second_omen", 0.0))}
	if mode != null:
		out.merge(mode.elite_rules(), true)
	else:
		Twists.elite_rules(twist_id(), out)   # (omens: twice the chance, the max kept)
	return out


# ---------------------------------------------------------------- the twist (Build 2)

func twist_id() -> String:
	## The level's twist id (twists.gd TWISTS) from its `twist:` header: ""
	## with none, and always in a mode (a twist is the story's).
	if mode != null:
		return ""
	if _twist_id == null:
		_twist_id = Twists.id_in(level)
	return str(_twist_id)


func twist(rule: String) -> bool:
	## Is this twist rule on here (restless, dark, omens, dry, packs, toll, lamplit)?
	return rule != "" and Twists.rule_of(twist_id()) == rule


func twist_heal() -> float:
	## What an altar or a draught heals here, of its own (dry: 0.75; else 1).
	return Twists.heal_mult(twist_id())


func title_sub() -> String:
	## The title card's line: "4-2 · On the Hour" with a twist, else the subtitle.
	var c := Twists.card_of(twist_id(), world_n, str(level.id))
	return level.subtitle if c.is_empty() else "%s · %s" % [level.subtitle, c[0]]


func twist_cards() -> Array:
	## The top band's cards after the title: [id, title, line] for the twist's
	## line, then a lesson's (an X-1's `lesson: Title|Line`); [] for neither.
	var out := []
	var key := "twist:%s:%s" % [level_id, diff]
	var c := Twists.card_of(twist_id(), world_n, str(level.id))
	if not c.is_empty():
		out.append([key, str(c[0]), str(c[1])])
	var l := Twists.lesson_in(level) if mode == null else []
	if not l.is_empty():
		out.append([key + ":lesson", str(l[0]), str(l[1])])
	return out


func _twist_cards() -> void:
	## Queued under the title card (they wait their turn in the band, and for a
	## start beat's lines), once per level and difficulty (Game.seen). Never
	## marked seen by the bot, a test's pad or a golden route, nor in a feel
	## lab (it writes nothing: its cards show every time).
	if hud == null:
		return
	var marks := not (autoplay or test_pad != null or on_pad.is_valid() or is_lab())
	for c in twist_cards():
		if marks and Game.seen(str(c[0])):
			continue
		card(str(c[0]), str(c[1]), str(c[2]))
		if marks:
			Game.mark_seen(str(c[0]))


func freeze(sec: float, force := false) -> void:
	## Hitstop, within a budget so fast attacks don't stutter.
	if not force:
		var spent := 0.0
		for e in _hitstop_spent:
			spent += e[1]
		if spent + sec > HITSTOP_BUDGET:
			sec = maxf(HITSTOP_BUDGET - spent, 0.0)
		if sec <= 0.0:
			return
		_hitstop_spent.append([_t, sec])
	hitstop = maxf(hitstop, sec)


func number(pos: Vector2, value: float, kind := "hit", key := 0) -> void:
	floaters.add(pos, value, kind, key)


func banner(text: String) -> void:
	## A big word: the HUD's banner, or a floater over the hero when there's
	## no HUD (headless). Never both: the two read as one word said twice.
	if hud and hud.has_method("banner"):
		hud.banner(text)
	else:
		floaters.add(player.center() + Vector2(0, -50), 0.0, "text", 0, text)


func deal(e: Node2D, coef: float, opts := {}) -> Dictionary:
	## The hero hurts a monster: the roll, the hit, the number, hitstop, the
	## kit's reaction, and XP and loot on a kill. opts: how ("slash"),
	## force_crit, from_x, attack_id, flat (a fixed amount instead of a roll),
	## heavy (more hitstop), no_hitstop, extra_pct (a skill's own bonus),
	## special (a Special's hit that isn't how "skill": a Peal wave, a Knell
	## mote, Thousand Cuts' knives; special_pct counts on it).
	## Returns {hit: bool, amount, crit, killed}.
	var how: String = opts.get("how", "slash")
	var from_x: float = float(opts.get("from_x", player.position.x))
	var roll: Dictionary
	if opts.has("flat"):
		roll = {"amount": float(opts["flat"]), "crit": opts.get("force_crit", false)}
	else:
		var extra: float = float(opts.get("extra_pct", 0.0))
		if how == "skill" or opts.get("special", false):
			extra += float(player.stats.get("special_pct", 0.0))
		if e.tier != "" or e == boss:
			extra += float(player.stats.get("elite_pct", 0.0))
		var legends: Dictionary = player.stats.get("legends", {})
		if legends.has("gutterlight") and player.life_frac() < _flag("gutterlight_below", 0.35):
			extra += _flag("gutterlight_dmg", 0.40)
		if legends.has("tollbreaker") and e == boss and _boss_open(e):
			extra += _flag("tollbreaker_pct", 1.0)
		# The Hour-Hand: each hit on the same foe within 3 s adds +8%, to +40%.
		if legends.has("hour_hand"):
			var hh: Dictionary = e.get_meta("hour_hand", {"n": 0, "t": -99.0})
			if ftime - float(hh["t"]) <= _flag("hourhand_t", 3.0):
				extra += minf(int(hh["n"]) * _flag("hourhand_step", 0.08), _flag("hourhand_max", 0.40))
		# The Saint's Lens: foes inside his light take +15%.
		if _flag("lens_bonus", 0.0) > 0.0 and e.center().distance_to(player.center()) <= hero_light_radius():
			extra += _flag("lens_bonus", 0.0)
		# Hushbane: every 5th hit on the same foe deals +150%.
		if legends.has("hushbane") and (int(e.get_meta("hushbane", 0)) + 1) % maxi(int(_flag("hushbane_every", 5.0)), 1) == 0:
			extra += _flag("hushbane_bonus", 1.5)
		var back := Combat.is_back_hit(e, from_x)
		roll = Combat.roll(player.stats, coef, rng, e, opts.get("force_crit", false) or opts.get("backstab", false) and back, extra)
	var h := {"how": how, "from_x": from_x, "amount": float(roll["amount"]), "crit": roll["crit"], "source": player, "attack_id": opts.get("attack_id", -1)}
	if opts.get("safe_stomp", false):
		h["safe_stomp"] = true
	if opts.get("stomp_born", false):
		h["stomp_born"] = true
	var ok: bool = e.hit(h)
	var out := {"hit": ok, "amount": e.last_damage if ok else 0.0, "crit": roll["crit"], "killed": ok and not e.alive}
	if ok and not opts.has("flat"):
		_legend_hit(e, coef, roll["crit"], how)
	if ok:
		var kind := "chip" if h.get("chip", false) else ("crit" if roll["crit"] else "hit")
		number(e.center() + Vector2(0, -e.size.y * 0.4), out["amount"], kind, e.get_instance_id())
		if roll["crit"]:
			_sfx("crit")   # layers over the hit's own sound
		if not opts.get("no_hitstop", false):
			var hs := 0.06 if opts.get("heavy", false) else (0.02 if how in ["shot", "bolt"] else 0.035)
			if roll["crit"]:
				hs += 0.02
			if out["killed"]:
				hs += 0.015
			if e == boss:
				hs = 0.07
			freeze(hs)
		kit.on_hit_landed(e, out)
	return out


func _legend_hit(e: Node2D, coef: float, crit: bool, how: String) -> void:
	## After a rolled hit lands: the Hour-Hand's stack, Hushbane's count and
	## stun, Prismglass's shard off a crit.
	var legends: Dictionary = player.stats.get("legends", {})
	if legends.has("hour_hand"):
		var hh: Dictionary = e.get_meta("hour_hand", {"n": 0, "t": -99.0})
		var n := int(hh["n"]) if ftime - float(hh["t"]) <= _flag("hourhand_t", 3.0) else 0
		e.set_meta("hour_hand", {"n": n + 1, "t": ftime})
	if legends.has("hushbane"):
		var c := int(e.get_meta("hushbane", 0)) + 1
		e.set_meta("hushbane", c)
		if c % maxi(int(_flag("hushbane_every", 5.0)), 1) == 0 and e.alive and e != boss:
			e.apply_status("stun", _flag("hushbane_stun", 0.5))
	if crit and legends.has("prismglass") and how != "prism":
		var o := nearest_enemy(e.center(), _flag("prism_range", 200.0), func(x): return x != e and x.alive and x.active)
		if o != null:
			if glow:
				glow.burst(e.center(), 6, Color("f8f0ff"), 90.0, 0.25, 0.0, 1.8)
				glow.burst(o.center(), 10, Color("f8f0ff"), 140.0, 0.35, 0.0, 2.0)
			deal(o, coef * _flag("prism_coef", 0.5), {"how": "prism", "no_hitstop": true})


func _after_hurt(source: Object) -> void:
	## A blow landed on the hero: Hoarfrost Mantle freezes who struck (bosses
	## briefly), once every 4 s; below 30% life the Last Candle stuns every
	## foe in his light and makes him untouchable, once per altar.
	if not player.alive:
		return
	var legends: Dictionary = player.stats.get("legends", {})
	if legends.has("hoarfrost") and source is Node2D and is_instance_valid(source) and enemies.has(source) \
			and source.alive and ftime >= _hoarfrost_at and source.has_method("apply_status"):
		_hoarfrost_at = ftime + _flag("hoarfrost_cd", 4.0)
		source.apply_status("stun", _flag("hoarfrost_boss", 0.3) if source == boss else _flag("hoarfrost_stun", 1.5))
		if glow:
			glow.burst((source as Node2D).get("position") if not source.has_method("center") else source.center(), 14, Color("bfe4f4"), 120.0, 0.5, 0.0, 2.2)
	if legends.has("last_candle") and _lastcandle_ready and player.life_frac() < _flag("lastcandle_below", 0.30):
		_lastcandle_ready = false
		player.invuln = maxf(player.invuln, _flag("lastcandle_invuln", 1.5))
		var r := hero_light_radius()
		for o in enemies:
			if o.alive and o != boss and o.center().distance_to(player.center()) <= r:
				o.apply_status("stun", _flag("lastcandle_stun", 1.0))
		if glow:
			glow.burst(rig.flame_point(), 30, Color("fff4cf"), 220.0, 0.6, 0.0, 2.6)
		_sfx("relight")
		if hud:
			hud.toast("The Last Candle", "Untouchable")


func _flag(key: String, fallback: float) -> float:
	## A worn Legendary's number from stats.flags (items.gd LEGENDS fx).
	var f = player.stats.get("flags", {}) if player else {}
	return float(f.get(key, fallback)) if f is Dictionary else fallback


func _boss_open(e: Node2D) -> bool:
	## A boss stuck or staggered (Tollbreaker's +100%): the boss's is_open()
	## when it has one (v3); else Tollgrave's bell stuck or reeling from
	## "RUNG!", the Snuffer's pole stuck or his recoil.
	if e.has_method("is_open"):
		return bool(e.is_open())
	return str(e.get("state")) in ["stuck", "hurt", "recoil"]


func clamp_here() -> bool:
	## Does the blow clamp apply in this level? Everywhere but v2's own main
	## levels (worlds 1-2 off a mode, not a secret), unless CLAMP_V2_LEVELS.
	if CLAMP_V2_LEVELS or mode != null or world_n < 1 or world_n > 2:
		return true
	var g := _game()
	return g != null and g.has_method("is_secret") and bool(g.is_secret(level_id))


func hurt_player(amount: float, from_x: float, kind := "hit", source: Object = null, opts := {}) -> bool:
	## A monster, shot or hazard hurts the hero (see player.take_damage). In
	## order: shot_dr for shot kinds, the kit's filter, invulnerability, DR,
	## then the clamp (Combat.BLOW_CLAMP[diff] x max life) for everything but
	## a share-of-life hazard (pits, lava, deep water, the void, the tide).
	## opts may carry move (the move id, for the playlog: "rootmother:sweep_high")
	## and feature (what terrain did it: "glass", "gust", "tide"...).
	if state != "play":
		return false
	var legends: Dictionary = player.stats.get("legends", {})
	var a := amount
	if SHOT_KINDS.has(kind) or opts.get("shot", false):
		a *= 1.0 - clampf(float(player.stats.get("shot_dr", 0.0)), 0.0, 0.5)
	var clamp_share: float = float((_combat_const("BLOW_CLAMP", {}) as Dictionary).get(diff, 0.0)) if clamp_here() else 0.0
	if clamp_share > 0.0 and not opts.get("pct", false) and not OWN_SHARE.has(kind):
		opts = opts.duplicate()
		opts["clamp"] = clamp_share * player.max_hp
	if kind == "latch" and Game.equipped("wind_wick"):
		a *= 0.5   # the Wind Wick: moths drink half
	if not opts.get("pct", false) and player.invuln <= 0.0 and player.alive:
		if legends.has("twin_wick") and _twin_ready:
			# The spare flame takes the whole hit, once per altar.
			_twin_ready = false
			player.invuln = float(player.stats.get("invuln", 0.9))
			number(player.center() + Vector2(0, -34), 0.0, "blocked")
			if glow:
				glow.burst(rig.flame_point(), 16, Color("c0c8f0"), 140.0, 0.5, 0.0, 2.2)
			_sfx("guard_block")
			return false
		if bone_wards > 0:
			bone_wards -= 1
			a *= _flag("ossuary_cut", 0.5)
	# What to blame in the playlog: the monster's kind (a boss by name), its
	# move, the feature. Set before the hit lands (a snuff inside take_damage
	# reads it) and put back if the hit didn't land.
	var was := [snuff_causes.get("_last", "hit"), snuff_causes.get("_move", ""), snuff_causes.get("_feature", "")]
	var cause := kind
	if source != null:
		if source.get("boss_id") != null:
			cause = str(source.get("boss_id"))
		elif source.get("kind") != null:
			cause = str(source.get("kind"))
	var mv := str(opts.get("move", ""))
	if mv == "" and source != null and source.get("move_id") != null:
		mv = str(source.get("move_id"))
	snuff_causes["_last"] = cause
	snuff_causes["_move"] = mv
	snuff_causes["_feature"] = str(opts.get("feature", ""))
	var ok: bool = player.take_damage(a, from_x, kind, source, opts)
	if not ok:
		snuff_causes["_last"] = was[0]
		snuff_causes["_move"] = was[1]
		snuff_causes["_feature"] = was[2]
	else:
		_pool_cause = cause   # after the hit, as v2 recorded it (see _on_snuffed's pool)
		_after_hurt(source)
	return ok


func spawn_shot(d: Dictionary) -> Dictionary:
	## A projectile. Keys: kind (spark knife arrow mote bolt crescent flare
	## skull shard...), pos, vel, g (gravity), life, owner ("player"/"enemy"),
	## coef (player shots: x basic) or dmg (enemy shots: flat), how ("shot"),
	## pierce (enemies it may pass through), bounce (wall bounces), homing
	## (turn rate rad/s toward the nearest enemy), light (radius), deflect
	## (a melee swing sends it back), douse, radius (hit radius, 6),
	## on_hit (Callable(shot, enemy)), on_end (Callable(shot)), breaks (bricks),
	## special (a Special's shot, which special_pct counts on), force_crit (a
	## sure crit: Thousand Cuts). A hero shot's life is x the Longsword's
	## range_mult.
	var s := {"kind": "spark", "pos": Vector2.ZERO, "vel": Vector2.ZERO, "g": 0.0, "life": 1.0, "owner": "player",
			"coef": 1.0, "dmg": 10.0, "how": "shot", "pierce": 0, "bounce": 0, "homing": 0.0, "light": 0.0,
			"deflect": false, "douse": false, "radius": 6.0, "hit_ids": [], "breaks": true, "t": 0.0}
	s.merge(d, true)
	# The Longsword: "shots fly 30% further" (every hero shot lives longer).
	if s["owner"] == "player":
		s["life"] = float(s["life"]) * _flag("range_mult", 1.0)
	# The Saint's Knuckle on a thrower or caster: every 3rd basic shot pierces
	# (a melee calling gets its bolt in _on_attacked instead).
	if s["owner"] == "player" and s["kind"] in ["spark", "knife"] and Game.equipped("saints_knuckle"):
		_knuckle_shots += 1
		if _knuckle_shots % 3 == 0:
			s["pierce"] = int(s["pierce"]) + 1
	# The Escapement on a thrower or caster: every 4th basic shot strikes twice.
	if s["owner"] == "player" and s["kind"] in ["spark", "knife"] and not s.get("special", false) \
			and player.stats.get("legends", {}).has("escapement"):
		_escape_shots += 1
		if _escape_shots % maxi(int(_flag("escapement_every", 4.0)), 1) == 0:
			s["twice"] = true
	shots.append(s)
	return s


func add_hazard(d: Dictionary) -> Dictionary:
	## Something that hurts on touch. Keys: kind (wave skull rubble fire
	## smoke...), rect, vel, g, life, delay, owner ("enemy" hurts the hero,
	## "player" hurts monsters), dmg (flat) or coef (x basic, player), motion:
	##   floor  runs along the floor, dies at walls and edges
	##   bounce bounces on floors, turns at walls (skulls)
	##   fall   falls; dies on the floor (rubble, drips)
	##   fly    moves freely, dies in walls
	##   tide   moves freely, ignores everything (smoke tides)
	##   still  stays put (fire floors)
	## shadow (draw a landing shadow), douse, hit_ids, special (a player
	## Special's hazard, which special_pct counts on).
	var h := {"kind": "wave", "rect": Rect2(), "vel": Vector2.ZERO, "life": 1.0, "delay": 0.0, "owner": "enemy",
			"dmg": 20.0, "coef": 1.0, "motion": "floor", "hit_ids": []}
	h.merge(d, true)
	# The whole wait, so a landing shadow grows over the hazard's own delay
	# (the Toll of Ruin's 0.6 s, the Drip Choir's 0.8 s).
	if not h.has("delay0"):
		h["delay0"] = float(h["delay"])
	hazards.append(h)
	return h


func add_light(pos: Vector2, r: float, s := 0.8, life := -1.0, tag := "", tint := Color(0, 0, 0, 0)) -> int:
	## A light for the dark (-1 life = until removed). Returns its id. s < 0 is
	## a Hush light; tint.a is how much of tint it throws; tag may list several,
	## comma-separated ("lantern,haven,anchor"). A gameplay light (lit_at
	## counts it) unless the tag says "deco".
	if lights != null:
		return lights.add(pos, r, s, life, tag, tint)
	var id := _next_light
	_next_light += 1
	_dyn_lights[id] = {"p": pos, "r": r, "s": s, "life": life, "tag": tag, "tint": tint}
	return id


func move_light(id: int, pos: Vector2, r := -1.0) -> void:
	if lights != null:
		lights.move(id, pos, r)
		return
	if _dyn_lights.has(id):
		_dyn_lights[id]["p"] = pos
		if r >= 0.0:
			_dyn_lights[id]["r"] = r


func remove_light(id: int) -> void:
	if lights != null:
		lights.remove(id)
		return
	_dyn_lights.erase(id)


func lights_tagged(tag: String) -> Array:
	## [{p, r, s}] of the live lights with this tag (braziers, beacons; one of
	## a comma-separated list counts).
	if lights != null:
		return lights.tagged(tag)
	var out := []
	for id in _dyn_lights:
		if _has_tag(str(_dyn_lights[id]["tag"]), tag):
			out.append(_dyn_lights[id])
	return out


static func _has_tag(tags: String, tag: String) -> bool:
	if tags == tag:
		return true
	if not tags.contains(","):
		return false
	for t in tags.split(","):
		if t.strip_edges() == tag:
			return true
	return false


func light_by_id(id: int) -> Dictionary:
	return dyn_lights().get(id, {})


func dyn_lights() -> Dictionary:
	## id -> {p, r, s, life, tag, tint}: the World's own lights (world_lights.gd
	## holds them once it's there).
	if lights != null and "dyn" in lights:
		return lights.dyn
	return _dyn_lights


func gameplay_lights(exclude_hero := false) -> Array:
	## [{p, r, tag}] every light that counts for lit_at, at nominal radii: the
	## hero's (unless excluded), the World's own (lanterns, braziers, beacons,
	## tolls...), lit altars, the kit's, and the features' and the mode's
	## entries marked gameplay.
	var out := []
	if not exclude_hero and player != null and player.alive:
		out.append({"p": player.center() + Vector2(0, -8), "r": hero_light_radius(), "tag": "hero"})
	var dl := dyn_lights()
	for id in dl:
		var l: Dictionary = dl[id]
		if float(l["s"]) > 0.0 and not _has_tag(str(l["tag"]), "deco"):
			out.append({"p": l["p"], "r": float(l["r"]), "tag": str(l["tag"])})
	for a in altars:
		if a["lit"]:
			out.append({"p": a["flame"], "r": 150.0, "tag": "altar,haven"})
	if kit != null:
		for l in kit.lights():
			if not l.get("hero", false):
				out.append({"p": l["p"], "r": float(l["r"]), "tag": str(l.get("tag", "kit,haven"))})
	if features != null:
		for l in features.lights():
			if l.get("gameplay", false):
				out.append({"p": l["p"], "r": float(l["r"]), "tag": str(l.get("tag", ""))})
	if mode != null:
		for l in mode.lights():
			if l.get("gameplay", false):
				out.append({"p": l["p"], "r": float(l["r"]), "tag": str(l.get("tag", ""))})
	return out


var _lit_memo := {}             # Vector2i(p) -> was lit (the 8 px off-edge hysteresis)


func lit_at(p: Vector2, pad := 0.0, opts := {}) -> bool:
	## Is p inside a gameplay light? Nominal radii (never the flicker), with
	## 8 px of hysteresis on the off edge. opts: exclude_hero (Wick's own light
	## doesn't count: dawnglass), tag (only lights with it: "haven").
	if lights != null and lights.has_method("lit_at"):
		return lights.lit_at(p, pad, opts)
	var key := Vector2i(roundi(p.x), roundi(p.y))
	var was: bool = _lit_memo.get(key, false)
	var tag := str(opts.get("tag", ""))
	var lit := false
	for l in gameplay_lights(bool(opts.get("exclude_hero", false))):
		if tag != "" and not _has_tag(str(l["tag"]), tag):
			continue
		var r: float = float(l["r"]) + pad + (8.0 if was else 0.0)
		if (l["p"] as Vector2).distance_squared_to(p) <= r * r:
			lit = true
			break
	_lit_memo[key] = lit
	return lit


func dim(key: String, mult: float, seconds: float) -> void:
	## The one dimming pipeline (spores, Hush zones, hushed, the Stillmaw, the
	## Hushed Omen, gusts, a mode's dark...): re-dimming a key refreshes it.
	## hero_light_radius applies dim_resist to each, floors the product at
	## Combat.DIM_FLOOR[diff], then LIGHT_MIN. A key starting "script:" (a
	## scripted boss move) isn't floored.
	_dims[key] = {"mult": clampf(mult, 0.0, 1.0), "t": seconds}
	if lights != null and lights.has_method("dim") and not key.begins_with(DIM_EXEMPT):
		lights.dim(key, mult, seconds)


func undim(key: String) -> void:
	if lights != null and lights.has_method("undim"):
		lights.undim(key)
	_dims.erase(key)


func dims() -> Dictionary:
	## The active dims, key -> {mult, t}.
	return _dims


func _exempt() -> float:
	## The scripted dims' product (keys "script:..."), never floored.
	var m := 1.0
	for k in _dims:
		if str(k).begins_with(DIM_EXEMPT):
			m *= float(_dims[k]["mult"])
	return m


func light_override(r: float) -> void:
	## The finale's give: r >= 0 forces the hero's radius (below LIGHT_MIN
	## too); -1 lets go.
	_light_override = r
	if lights != null and lights.has_method("light_override"):
		lights.light_override(r)


func set_dark(color: Color, seconds: float) -> void:
	## The dark's colour, eased there over seconds.
	if lights != null and lights.has_method("set_dark"):
		lights.set_dark(color, seconds)
		return
	var from: Color = _dark_mat.get_shader_parameter("dark_color") if _dark_mat else color
	_dark_to = {"from": from, "to": color, "t": 0.0, "dur": maxf(seconds, 0.0)}
	if seconds <= 0.0 and _dark_mat:
		_dark_mat.set_shader_parameter("dark_color", color)


func set_warm(color: Color, seconds: float) -> void:
	## The warm band near lights, eased there over seconds.
	if lights != null and lights.has_method("set_warm"):
		lights.set_warm(color, seconds)
		return
	var from: Color = _dark_mat.get_shader_parameter("warm_color") if _dark_mat else color
	_warm_to = {"from": from, "to": color, "t": 0.0, "dur": maxf(seconds, 0.0)}
	if seconds <= 0.0 and _dark_mat:
		_dark_mat.set_shader_parameter("warm_color", color)


func _ease_tints(dt: float) -> void:
	for pair in [[_dark_to, "dark_color"], [_warm_to, "warm_color"]]:
		var d: Dictionary = pair[0]
		if d.is_empty() or _dark_mat == null:
			continue
		d["t"] = float(d["t"]) + dt
		var k := clampf(float(d["t"]) / maxf(float(d["dur"]), 0.001), 0.0, 1.0)
		_dark_mat.set_shader_parameter(pair[1], (d["from"] as Color).lerp(d["to"], k))
		if k >= 1.0:
			d.clear()


func _resist(m: float, dr: float) -> float:
	return m if dr <= 0.0 else 1.0 - (1.0 - m) * (1.0 - dr)


func dim_mult() -> float:
	## The dims' product for the hero's light (douse and latch among them),
	## with dim_resist and the difficulty's floor (world_lights.gd's
	## dim_product once it's there: douse and latch stay outside it as in v2).
	if lights != null and lights.has_method("dim_product"):
		return lights.dim_product() * _exempt()
	var dr := clampf(float(player.stats.get("dim_resist", 0.0)), 0.0, float(_combat_const("DIM_RESIST_CAP", 0.5)))
	var m := 1.0
	if player.has_status("douse"):
		m *= _resist(0.5, dr)
	if player.has_status("latch"):
		m *= _resist(0.55, dr)
	var exempt := 1.0
	var fl = player.stats.get("flags", {})
	var sr := clampf(float(fl.get("spore_resist", 0.0)), 0.0, 1.0) if fl is Dictionary else 0.0
	for k in _dims:
		if str(k).begins_with(DIM_EXEMPT):
			exempt *= float(_dims[k]["mult"])
		else:
			var dm := float(_dims[k]["mult"])
			if sr > 0.0 and str(k).begins_with("spore"):
				dm = _resist(dm, sr)   # Sporeward: spore clouds dim half as much
			m *= _resist(dm, dr)
	var floors: Dictionary = _combat_const("DIM_FLOOR", {})
	m = maxf(m, float(floors.get(diff, 0.0)))
	return m * exempt


func hero_light_radius() -> float:
	## Spec §1.7: the dims through dim_mult (floored), then LIGHT_MIN in
	## Combat.light_radius, then the finale's override.
	if lights != null and lights.has_method("hero_radius"):
		# world_lights.gd floors its dims; a scripted dim ("script:") isn't.
		var r: float = lights.hero_radius()
		return r if _light_override >= 0.0 else r * _exempt()
	if _light_override >= 0.0:
		return _light_override
	return base_light_radius()


func base_light_radius() -> float:
	## The hero's radius before any override (world_lights.gd may call it).
	var mult: float = features.light_mult() if features else 1.0
	mult *= dim_mult()
	var extra := 0.0
	for l in kit.lights():
		if l.get("hero", false):
			extra += float(l["r"])
	return Combat.light_radius(player.life_frac(), player.stats, diff, mult, extra)


func add_temp_ledge(r: Rect2, life: float) -> Object:
	## A one-way ledge that lasts a while (a kit's bone step, the finale's rings).
	var mv := Movers.temp(r, life)
	movers.append(mv)
	return mv


func add_mover(mv: Object, view: Node2D = null) -> Object:
	## A feature's mover (a cog tooth, a swing, a float): ridden like any
	## ledge; view (optional) is placed at its pos each step.
	if view != null:
		mv.node = view
		view.position = mv.pos
		get_node("Props").add_child(view)
	movers.append(mv)
	return mv


func enemies_in(r: Rect2) -> Array:
	return enemies.filter(func(e): return e.alive and e.active and e.rect().intersects(r))


func nearest_enemy(p: Vector2, max_dist: float, filter: Callable = Callable()) -> Node2D:
	var best: Node2D = null
	var bd := max_dist
	for e in enemies:
		if not e.alive or not e.active:
			continue
		if filter.is_valid() and not filter.call(e):
			continue
		var d: float = e.center().distance_to(p)
		if d < bd:
			bd = d
			best = e
	return best


func spawn_enemy(kind: String, pos: Vector2, opts := {}) -> Node2D:
	## Places a monster of a registered kind. opts: tier, name, omens, cell,
	## respawned, scale (Twinned copies), facing; v3: world (the DMG_WORLD_TRIM
	## world, else world_n), area, boss (a mode's boss options go to its
	## configure first). None at all with no_monsters.
	if no_monsters:
		return null
	var en: Node2D = EnemyKinds.make(kind)
	if en == null:
		return null
	en.level = level
	en.world = self
	en.position = pos
	en.facing = int(opts.get("facing", -int(level.facing)))   # toward him: right in a level played right to left
	en.tier = opts.get("tier", "")
	en.elite_name = opts.get("name", "")
	en.omens = opts.get("omens", [])
	en.respawned = opts.get("respawned", false)
	en.spawn = {"kind": kind, "cell": opts.get("cell", Vector2i(-1, -1))}
	if opts.has("scale"):
		en.scale_mult = float(opts["scale"])
	en.setup_stats(int(opts.get("area", area)), diff, strength, int(opts.get("world", world_n)))
	if opts.has("hp_frac"):
		en.max_hp *= float(opts["hp_frac"])
		en.hp = en.max_hp
	if mode != null:
		mode.on_spawn(en)
	if opts.get("boss", false) and en.has_method("configure"):
		# A mode's boss (the Waxworks, a Descent boss depth): its options before _ready.
		var bo := _mode_boss_opts(kind)
		if not bo.is_empty():
			_boss_opts = bo
			en.configure(bo)
	en.died.connect(_on_enemy_died)
	get_node("Monsters").add_child(en)
	enemies.append(en)
	if en.tier != "":
		en.active = false
	return en


func _update_warden_bar() -> void:
	## A Warden's boss bar (when no boss holds the bar): up while it's awake
	## (in play near the view), its life each tick; gone when it falls.
	if warden == null or boss != null:
		return
	if not is_instance_valid(warden) or not warden.alive:
		warden = null
		if _warden_bar:
			_warden_bar = false
			hud_call("boss_bar", [{}])
		return
	if warden.active:
		_warden_bar = true
		# Its Omens on the bar's title line (no elite plate for a Warden).
		var wt := "Warden"
		for o in (warden.get("omens") if warden.get("omens") is Array else []):
			wt += " · " + str(o).capitalize()
		hud_call("boss_bar", [{"id": "warden", "name": str(warden.elite_name), "title": wt,
				"frac": float(warden.hp) / maxf(float(warden.max_hp), 1.0), "awake": true}])
	elif _warden_bar:
		_warden_bar = false
		hud_call("boss_bar", [{}])


func _mode_boss_opts(kind: String) -> Dictionary:
	## The mode's options for its boss ({rush, mods, hp_mult, area}): its
	## boss_opts(kind), or a boss_opts Dictionary.
	if mode == null:
		return {}
	if mode.has_method("boss_opts"):
		var o = mode.boss_opts(kind)
		return o if o is Dictionary else {}
	var d = mode.get("boss_opts")
	return d if d is Dictionary else {}


func gain_xp(n: int, at: Vector2) -> void:
	if n <= 0 or not allows("xp"):
		return
	var pct := float(player.stats.get("xp_pct", 0.0)) if player != null else 0.0
	if pct != 0.0:
		n = roundi(n * (1.0 + pct))
	xp_gained += n
	var gained: int = Game.add_xp(n)
	if hud and hud.has_method("xp_tick"):
		hud.xp_tick()
	if gained > 0:
		levels_gained += gained
		_level_up(at, gained)


func _level_up(_at: Vector2, gained := 1) -> void:
	## Level up: a pillar of light, a shove, a heal, the new numbers. A level
	## that opens a tier (the capstones at 8, Deep at 16, Mastery at 24) has
	## its own bark, level_up_<n>, pointing at it.
	apply_hero()
	player.heal_pct(0.20)
	player.res = player.res_max
	freeze(0.12, true)
	_sfx("level_up")
	_haptic(40)
	shake = maxf(shake, 4.0)
	if glow:
		glow.burst(player.center(), 36, Color("ffd84a"), 220.0, 0.9, -60.0, 2.8)
		glow.pillar(player.position)
	for e in enemies:
		if e.alive and e.active and e != boss and e.center().distance_to(player.center()) < 90.0:
			e.apply_status("stun", 0.6)
			e.velocity.x = 220.0 * signf(e.position.x - player.position.x)
	var lv := int(Game.hero()["level"])
	if hud:
		hud.level_up(lv)
	var key := "level_up"
	for t in [5, 4, 3]:
		var at := int(Classes.GATES[t]["level"])
		if lv - gained < at and lv >= at and _bark_exists("level_up_%d" % at):
			key = "level_up_%d" % at
			break
	bark(key)
	if int(Game.hero()["points"]) > 0:
		bark("skill_point")


func drop_item(at: Vector2, source := "kill", tier := "", slot_want := "") -> void:
	## An item from a kill (or a chest, a boss): rarity by source and
	## difficulty, class weapons only for the hero's calling. A mode may stop
	## drops (allows "loot") or lean the rarities (loot(): rare, legend).
	## An ordinary kill's rarities are Items.kill_weights(area, diff) when
	## it's there (Dusk richer from area 13, no Commons in a story level; a
	## mode's Dusk keeps v3's; v2's table on Nightfall and Witching).
	## slot_want (a Dread's gift: Game.gift_slot) picks the slot, else a live
	## slot at random.
	if not allows("loot"):
		return
	var h: Dictionary = Game.hero()
	var key := source
	if source == "kill":
		key = tier if tier != "" else diff
	var weights: Dictionary = DROP_WEIGHTS.get(key, DROP_WEIGHTS[diff])
	if source == "kill" and tier == "" and (Items as Script).has_method("kill_weights"):
		weights = (Items as Script).call("kill_weights", area, diff, mode == null)
	if mode != null:
		var lt: Dictionary = mode.loot()
		if lt.has("rare") or lt.has("legend"):
			weights = weights.duplicate()
			if weights.has("rare"):
				weights["rare"] = float(weights["rare"]) * float(lt.get("rare", 1.0))
			if weights.has("legendary"):
				weights["legendary"] = float(weights["legendary"]) * float(lt.get("legend", 1.0))
	var rarity := Items.pick_rarity(weights, rng)
	var ilvl = area + {"kill": 0, "anointed": 1, "dread": 2, "boss": 2, "lidlurk": 2, "gold": 1}.get(key, 0)
	var slot := slot_want if slot_want != "" else _pick_slot()
	var legend := _pick_legend(slot, h["cls"]) if rarity == "legendary" else ""
	if rarity == "legendary" and legend == "":
		rarity = "rare"
	var it := Items.make(slot, h["cls"], ilvl, rarity, rng, legend)
	place_item(it, at, Vector2(randf_range(-50, 50), -360.0))


func place_item(it: Dictionary, at: Vector2, vel := Vector2(0, -360.0)) -> Dictionary:
	## An item popping out at `at` to bounce and land, with its beam: the
	## pickup it makes (drop_item, the boss's prize, tests).
	var rarity: String = it["rarity"]
	var p := {"kind": "item", "item": it, "rarity": rarity, "pos": at, "vel": vel,
			"t": 0.0, "taken": false, "loose": true, "age": 0.0}
	var s := _sprite("res://art/items/%s.svg" % _item_icon(it), 0.25)
	s.position = at
	get_node("Props").add_child(s)
	p["sprite"] = s
	pickups.append(p)
	_sfx("item_drop", {"common": 1.0, "magic": 1.12, "rare": 1.26, "legendary": 1.5}.get(rarity, 1.0))
	if rarity == "legendary":
		_haptic(50)
	return p


func _item_icon(it: Dictionary) -> String:
	## art/items/<slot>_<cls or base>_<tier>.svg (W6a draws them), clamped
	## to the highest tier drawn (Items.icon: a T4/T5 without its icon yet
	## shows the T3 one), so PR can let tiers 4-5 roll.
	return Items.icon(it).get_file().get_basename()


func play_beat(id: String, then: Callable) -> void:
	## A story beat over the level (the cutscene player, once built).
	var cs = load("res://scripts/cutscene.gd")
	if cs and cs.has_method("play_overlay"):
		cs.play_overlay(self, id, then)
	else:
		then.call()


func bark(key: String) -> void:
	if hud and hud.has_method("bark"):
		hud.bark(key)


# The v3 World -> HUD calls (the Screens stream implements them; each is
# made only when the HUD has it).

func hud_call(method: String, args := []) -> void:
	if hud != null and hud.has_method(method):
		hud.callv(method, args)


func mode_pill(state: Dictionary) -> void:
	hud_call("mode_pill", [state])


func card(id: String, title: String, body: String) -> void:
	hud_call("card", [id, title, body])


func special_pill(text: String) -> void:
	hud_call("special_pill", [text])


func fade_for_finale(on: bool) -> void:
	hud_call("fade_for_finale", [on])


func fell(kind := "pit") -> void:
	## Into a pit, lava or deep water: a share of life (no invulnerability,
	## no damage reduction) and back to the last firm ground.
	if state != "play" or not player.alive:
		return
	if not player.fall_charge_ok():
		return
	snuff_causes["_last"] = kind
	_pool_cause = kind
	if world_n == 5 and kind in ["pit", "void"]:
		_sfx("void_whoosh")   # the Sanctum's pits open on the void (A7)
	var pct: float = float(Combat.diff(diff)["pit"])
	if world_n == 5 and kind in ["pit", "void"] and features != null and features.has_method("module"):
		# The Sanctum's void has its own knob (glass.gd DIFF_KNOBS void_pct).
		var gm: Object = features.module("glass")
		if gm != null and gm.has_method("knob") and (gm.get_script().get_script_constant_map().get("DIFF_KNOBS", {}) as Dictionary).has("void_pct"):
			pct = float(gm.knob("void_pct"))
	# Cinderstep halves lava and deep water, never a plain pit.
	if kind in ["lava", "water"] and player.stats.get("legends", {}).has("cinderstep"):
		pct *= _flag("cinderstep_hazard", 0.5)
	player.take_damage(pct, player.position.x, kind, null, {"pct": true, "ignore_invuln": true, "no_knock": true})
	if not player.alive:
		return
	player.reset_at(player.last_safe)
	player.invuln = maxf(player.invuln, 1.0)
	player.hurt_time = 0.0
	if features != null and features.has_method("on_fall"):
		features.on_fall(player.position)
	cam = cam_on(player.position)
	_cam_y_target = cam.y


func dust_at(p: Vector2) -> void:
	_rubble().burst(p, 3, true)


func _rubble() -> Node2D:
	var fx: Node2D = get_node_or_null("Rubble")
	if fx == null:
		fx = Node2D.new()
		fx.name = "Rubble"
		fx.set_script(load("res://scripts/rubble.gd"))
		add_child(fx)
	return fx


# ---------------------------------------------------------------- the step

func _physics_process(dt: float) -> void:
	if paused:
		return
	if autoplay:
		_auto_i += 1
		if _bot == null:
			_bot = AutoBot.new()
			_bot.setup(self)
		var b0 := Time.get_ticks_usec()
		test_pad = _bot.pad(dt)
		bot_us += Time.get_ticks_usec() - b0
	_read_pad()
	if on_pad.is_valid():
		on_pad.call(_pad)
	tick(dt)


const EDGES := ["jump", "attack", "special", "flask", "equip"]


func _read_pad() -> void:
	if test_pad != null:
		var tp: Dictionary = test_pad
		_pad = tp.duplicate()
		for k in EDGES:
			var now: bool = tp.get(k, false)
			var was: bool = _prev.get(k, false)
			_pad[k + "_pressed"] = now and not was
			_pad[k + "_released"] = was and not now
			_prev[k] = now
	else:
		_pad = {
			"left": Input.is_action_pressed("left"),
			"right": Input.is_action_pressed("right"),
			"down": Input.is_action_pressed("down"),
			"jump": Input.is_action_pressed("jump"),
			"special": Input.is_action_pressed("special"),
			"flask": Input.is_action_pressed("flask"),
			"up": InputMap.has_action("up") and Input.is_action_pressed("up"),
		}
		for k in EDGES:
			_pad[k + "_pressed"] = Input.is_action_just_pressed(k)
			_pad[k + "_released"] = Input.is_action_just_released(k)
	# Presses during a freeze are kept and delivered after it.
	for k in _latched:
		_pad[k] = true
	if hitstop <= 0.0:
		_latched.clear()


func tick(dt: float) -> void:
	_t += dt
	# The feature clock runs on every unpaused tick, hitstop included, and
	# stops while time is stopped (a boss's move).
	var stopped := _stop_t > 0.0
	if stopped:
		_stop_t = maxf(_stop_t - dt, 0.0)
		if _stop_t <= 0.0:
			_stop_caller = null
	else:
		ftime += dt
	_hitstop_spent = _hitstop_spent.filter(func(e): return _t - e[0] < 0.5)
	if hitstop > 0.0:
		hitstop -= dt
		for k in EDGES:
			if _pad.get(k + "_pressed", false):
				_latched[k + "_pressed"] = true
			if _pad.get(k + "_released", false):
				_latched[k + "_released"] = true
		return
	if state == "play":
		time += dt
		if not _near_sent and boss != null and player != null:
			_check_boss_near()
	if not stopped:
		for m in movers:
			m.update(ftime, dt)
			if m.life >= 0.0 and not m.forever:
				m.life -= dt
		movers = movers.filter(func(m): return m.kind != "temp" or m.forever or m.life > 0.0)
		_update_crumbles(dt)
	_update_pushes(dt, stopped)
	var playing: bool = state == "play" and player.alive
	player.pad = _pad if state == "play" else {}
	if playing:
		kit.step(dt, _pad)
		_update_special(dt)
		_update_flask(dt)
	player.step(dt)
	if player.on_floor:
		chain = 0
	if playing:
		_after_player_moved()
		_thumb_tips()
		if player.stats.get("legends", {}).has("cinderstep") and player.on_floor and absf(player.velocity.x) > 60.0:
			_trail_t -= dt
			if _trail_t <= 0.0:
				_trail_t = 0.18
				add_hazard({"kind": "fire", "motion": "still", "owner": "player", "coef": _flag("cinderstep_trail_pct", 0.3),
						"rect": Rect2(player.position.x - 8.0, player.position.y - 12.0, 16.0, 12.0), "life": 1.0})
	_update_enemies(dt)
	_update_warden_bar()
	_update_shots(dt)
	_update_hazards(dt)
	_update_pickups(dt)
	_update_pool(dt)
	if not stopped:
		features.step(dt)
		if twists != null:
			twists.step(dt)
	if mode != null:
		mode.on_tick(self, dt)
	elif _flame_id != "" and _flame_id != "tallow" and not special_override.has("hold_ring"):
		# (Not while the finale owns his flame: it fades an animated one
		# itself, hush_finale.gd; BB's request.)
		var C = load(COSMETICS)
		if C.animated(_flame_id):
			hero_flame = C.palette(_flame_id, ftime)
	floaters.step(dt)
	if not stopped:
		if lights != null:
			lights.step(dt)
		else:
			for id in _dyn_lights.keys():
				var l: Dictionary = _dyn_lights[id]
				if l["life"] >= 0.0:
					l["life"] -= dt
					if l["life"] <= 0.0:
						_dyn_lights.erase(id)
		for k in _dims.keys():
			_dims[k]["t"] = float(_dims[k]["t"]) - dt
			if float(_dims[k]["t"]) <= 0.0:
				_dims.erase(k)
	_ease_tints(dt)
	if state == "play" and player.alive:
		_touch_enemies()
		_touch_pickups()
		_touch_world()
		features.touch(player)
	if _rites_altar >= 0 or (choice != null and choice.is_open()):
		_tick_rites(dt)
	if not _boon.is_empty():
		_tick_boon(dt)
	_update_dead(dt)
	_update_clear(dt)
	_update_camera(dt)
	if touch and "special_state" in touch:
		var st: Dictionary = kit.button_state()
		if not special_override.is_empty():
			st = st.duplicate()
			st.merge(special_override, true)
		touch.special_state = st
		touch.flask_state = {"charges": flask_charges, "max": flask_max(), "drinking": _flask_t >= 0.0}
		# The finale's black is black: nothing can be pressed in it, so the
		# buttons go with the level (the rev5 review).
		var tv = touch.get("_view")
		if tv is CanvasItem:
			var ta := 1.0 - clampf(finale_black, 0.0, 1.0)
			if not is_equal_approx((tv as CanvasItem).modulate.a, ta):
				(tv as CanvasItem).modulate.a = ta
	var dimmed: bool = player.alive and (not _dims.is_empty() or player.has_status("douse") or player.has_status("latch"))
	if dimmed != _dim_on:
		_dim_on = dimmed
		if hud and hud.has_method("dim_ring"):
			hud.dim_ring(dimmed)


# ---------------------------------------------------------------- time and pushes

func stop_time(sec: float, caller: Node = null) -> void:
	## Everything but the hero (his kit and shots) and the caller freezes for
	## sec: the feature clock, movers, monsters, their shots and hazards (which
	## still hurt where they hang). sec <= 0 cancels a stop at once (a boss's
	## retry: the Tinker's reset_fight), but only the caller's own stop, or
	## any stop when no caller is named.
	if sec <= 0.0:
		if caller == null or caller == _stop_caller:
			_stop_t = 0.0
			_stop_caller = null
		return
	_stop_t = maxf(_stop_t, sec)
	_stop_caller = caller


func time_stopped() -> bool:
	return _stop_t > 0.0


func push_player(vel: Vector2, sec: float, tag := "") -> void:
	## A horizontal displacement for sec seconds (a gust, a Gustling, a boss's
	## breath); vertical is dropped. A push with a tag refreshes the one with
	## the same tag (a gust asks every tick); "" is a new push each call. The
	## World sums them, caps the total at PUSH_CAP, ignores it while he dashes
	## (or climbs, or hauls), and for gusts ("gust..." tags) halves it while
	## he's grounded and holds one that began while he was airborne until he
	## lands (or GUST_GRACE). actor.gd brakes a grounded push at a floor edge.
	var key := tag
	if key == "":
		_push_n += 1
		key = "_%d" % _push_n
	var p: Dictionary = _pushes.get(key, {})
	if p.is_empty():
		var airborne: bool = player != null and not player.on_floor
		p = {"grace": GUST_GRACE if tag.begins_with("gust") and airborne else 0.0}
		_pushes[key] = p
	p["v"] = vel.x
	p["t"] = sec
	p["tag"] = tag


const FEATURE_BLAME := 3.0      # s: a snuff this soon after a feature's note is put down to it
var _feature_note := {}


func note_feature(name: String) -> void:
	## A feature did something that may cost him (a rotten vine snapped, glass
	## shattered, a float went under): a snuff within FEATURE_BLAME is put
	## down to it in the playlog.
	_feature_note = {"name": name, "t": ftime}


func push_total() -> float:
	return player.push.x if player else 0.0


func _update_pushes(dt: float, stopped := false) -> void:
	var total := 0.0
	for key in _pushes.keys():
		var p: Dictionary = _pushes[key]
		if not stopped:
			p["t"] = float(p["t"]) - dt
		if float(p["t"]) <= 0.0:
			_pushes.erase(key)
			continue
		var v := float(p["v"])
		if str(p["tag"]).begins_with("gust"):
			if float(p["grace"]) > 0.0:
				if player.on_floor:
					p["grace"] = 0.0
				else:
					p["grace"] = float(p["grace"]) - dt
					v = 0.0
			if player.on_floor:
				v *= 0.5
		total += v
	total = clampf(total, -PUSH_CAP, PUSH_CAP)
	if player.dash_time > 0.0 or player.climbing or player.ledge_t >= 0.0 or not player.alive or state != "play":
		total = 0.0
	player.push = Vector2(total, 0.0)


func _update_special(dt: float) -> void:
	if not allows("special"):
		return
	if special_override.has("hold_ring"):
		# The finale's hold (hush_finale.gd reads the button itself): no
		# kit's Special fires at the top of the stair (BB's request).
		_special_held = false
		return
	var pressed: bool = _pad.get("special_pressed", false)
	if pressed and player.climbing:
		# A Special lets go of the vine first, then works as in the air; one
		# that would fizzle (its button greyed: no pips) keeps him on it.
		var bs = kit.button_state() if kit.has_method("button_state") else {}
		if not (bs is Dictionary and bool(bs.get("grey", false))):
			player.release_vine()
	var released: bool = _pad.get("special_released", false)
	var still_down: bool = _pad.get("special", false) or (test_pad == null and Input.is_action_pressed("special"))
	if pressed and released:
		# Both edges were kept through a hitstop freeze, so their order is
		# lost; the button's state now tells it. Held before: the old hold
		# was let go and a new one began, so end the old one first. Down now:
		# the last edge was the press, so the new hold stays held.
		if _special_held:
			_special_held = false
			kit.special_released(_special_t)
			released = false
		elif still_down:
			released = false
	if pressed:
		_special_held = true
		_special_t = 0.0
		kit.special_hold = 0.0
		kit.special_pressed()
	if _special_held:
		_special_t += dt
		kit.special_hold = _special_t
		kit.special_held(dt)
		if released or not still_down:
			_special_held = false
			kit.special_released(_special_t)


func _update_flask(dt: float) -> void:
	## The Tallow Flask: a slow drink, a share of life over half a second.
	if not allows("flask"):
		return
	if _pad.get("flask_pressed", false) and _flask_t < 0.0 and flask_charges > 0 and player.hp < player.max_hp:
		flask_charges -= 1
		flask_uses += 1
		_flask_t = 0.0
		_sfx("flask")
		if _flag("chalice_invuln", 0.0) > 0.0:
			player.invuln = maxf(player.invuln, _flag("chalice_invuln", 0.0))   # the Deep Chalice
	if _flask_t >= 0.0:
		var total: float = flask_heal()
		var step := minf(dt, 0.5 - _flask_t)
		player.heal_pct(total * step / 0.5)
		_flask_t += dt
		player.move_mult = minf(player.move_mult, 0.6)
		if _flask_t >= 0.5:
			_flask_t = -1.0
			number(player.center() + Vector2(0, -30), total * player.max_hp, "heal")


func safe_vetoed(feet: Vector2) -> bool:
	## Is this standing spot one a fall mustn't bring Waxby back to (player
	## _track_safe)? Where a W4 weight's bob sweeps a standing hero (the
	## clockwork module), or on the outline a Spurwheel rolls (the top of
	## its box or pillar). The int2 review: in 4-3's WT_PENDULA every fall
	## past the middle landing came back under the weight, and in 4-4's
	## HC_GEARS onto the Spurwheel's pillar.
	if world_n < 3:
		return false
	if features != null:
		var cw: Object = features.module("clockwork") if features.has_method("module") else null
		if cw != null and cw.has_method("safe_vetoed") and cw.safe_vetoed(feet):
			return true
	if _spur_tops.is_empty() and not _spur_done:
		_spur_done = true
		for e in enemies:
			if str(e.get("kind")) == "spurwheel":
				_spur_outline(e)
	return _spur_tops.has(Vector2i(floori(feet.x / TILE), floori((feet.y + 1.0) / TILE)))


func _spur_outline(e: Node2D) -> void:
	## The standing cells on the block a Spurwheel rolls round: the solid
	## piece under where it was placed (4-connected, at most 400 cells), each
	## cell of it with air above, and the cells either side of them.
	var start := Vector2i(floori(e.position.x / TILE), floori((e.position.y + 2.0) / TILE))
	if not LevelData.is_solid(level.tile(start.x, start.y)):
		return
	var seen := {start: true}
	var todo := [start]
	while not todo.is_empty() and seen.size() < 400:
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= level.width or n.y >= level.height or seen.has(n):
				continue
			if LevelData.is_solid(level.tile(n.x, n.y)):
				seen[n] = true
				todo.append(n)
	if seen.size() >= 400:
		return   # (the level's own floor: a wheel there is no box's)
	for c in seen:
		if not LevelData.is_solid(level.tile(c.x, c.y - 1)):
			for dx in [-1, 0, 1]:
				_spur_tops[Vector2i(c.x + dx, c.y)] = true


func _check_boss_near() -> void:
	## boss_near, once: Waxby at (or past) the last altar before the boss's
	## arena, else 20 tiles short of the boss where there's none.
	var bx := float(boss.position.x)
	var x := bx - 20.0 * TILE
	var last := -INF
	for a in altars:
		var ax: float = (a["pos"] as Vector2).x
		if ax < bx:
			last = maxf(last, ax)
	if last > -INF:
		x = last - TILE
	if player.position.x >= x:
		_near_sent = true
		boss_near.emit()


func _in_v3_arena(e: Node2D) -> bool:
	## A v3 boss stands where his arena's art puts him, which may be past
	## the view's wake margin while Waxby is already inside (Gravebough is
	## rooted 48 px into her arena's right wall, 300+ px off a camera on the
	## door): he wakes by his own rule (wake_check: WAKE_IN px past the door)
	## once Waxby is between the arena's walls. v2's bosses keep v2's wake.
	if e != boss or player == null or V2_BOSSES.has(str(e.get("boss_id"))) or e.get("arena_left") == null:
		return false
	return player.position.x > float(e.arena_left) and player.position.x < float(e.arena_right)


func _update_enemies(dt: float) -> void:
	var view := view_rect()
	var wake := view.grow(TILE * 6)
	var sleep := view.grow(view.size.x * 2.0)
	for e in enemies:
		if not e.active and (wake.has_point(e.position) or _in_v3_arena(e)):
			e.active = true
			if e.tier != "" and hud and hud.has_method("elite_seen"):
				hud.elite_seen(e)
		elif e.active and e != boss and not sleep.has_point(e.position) and e.alive:
			e.active = false
		if e.active and (_stop_t <= 0.0 or e == _stop_caller):
			e.step(dt, player)
	for e in enemies.duplicate():
		if e.gone:
			enemies.erase(e)
			e.queue_free()


func _after_player_moved() -> void:
	if player.bumped.size() > 0:
		_bonk(player.bumped[0])
	if player.attack_time >= 0.0 and player.attack_time <= player.ATTACK_ACTIVE:
		var ar: Rect2 = player.attack_rect()
		features.strike(ar, player.attack_id)
		for x in range(floori(ar.position.x / TILE), floori(ar.end.x / TILE) + 1):
			for y in range(floori(ar.position.y / TILE), floori(ar.end.y / TILE) + 1):
				if LevelData.is_breakable(level.tile(x, y)):
					break_tile(Vector2i(x, y))
		# A swing sends deflectable shots back.
		for s in shots:
			if s["owner"] == "enemy" and s["deflect"] and ar.has_point(s["pos"]):
				s["owner"] = "player"
				s["vel"] = -s["vel"] * 1.25
				s["coef"] = 1.5
				s["life"] = 1.2
				_sfx("parry")
				freeze(0.03)


# ---------------------------------------------------------------- blocks

func _bonk(cell: Vector2i) -> void:
	var t: int = level.tile(cell.x, cell.y)
	shake = maxf(shake, 2.0)
	if blocks.has(cell) and not blocks[cell]["spent"]:
		_open_block(cell)
	elif LevelData.is_breakable(t):
		break_tile(cell)
	else:
		_sfx("bump")
		_haptic(10)
	if blocks.has(cell):
		blocks[cell]["bump"] = 1.0
	# Monsters standing on it are knocked out (fodder) or hurt.
	var top := Rect2(cell.x * TILE, cell.y * TILE - 6, TILE, 8)
	for e in enemies:
		if e.alive and e.rect().intersects(top):
			var st := Combat.stomp_damage(player.stats, rng)
			var amt: float = float(st["amount"])
			if e.ordinary:
				amt = maxf(amt, e.max_hp)
			deal(e, 1.0, {"how": "bump", "flat": amt, "from_x": cell.x * TILE + 16})


func _open_block(cell: Vector2i) -> void:
	var b: Dictionary = blocks[cell]
	b["spent"] = true
	_opened.append([cell.x, cell.y])
	level.set_tile(cell.x, cell.y, LevelData.SPENT)
	var s: Sprite2D = b["sprite"]
	var spent := "res://art/props/reliquary_spent.svg"
	if ResourceLoader.exists(spent):
		s.texture = load(spent)
	var top := Vector2(cell.x * TILE + 16, cell.y * TILE - 4)
	_sfx("reliquary")
	_haptic(18)
	gain_xp(Progression.event_xp("reliquary", area), top)
	if glow:
		glow.burst(top + Vector2(0, 4), 14, Color("ffd07a"), 160.0, 0.5, 300.0, 2.5, 60.0)
	match b["contents"]:
		"embers":
			# Like a coin from a block: they pop up and count themselves.
			for i in 3:
				var p := _add_pickup("ember", top)
				p["pop"] = true
				p["placed"] = true
				p["age"] = -0.07 * i
				p["vel"] = Vector2((i - 1) * 26.0, -430.0)
			if diff != "dusk" and rng.randf() < 0.05:
				drop_item(top + Vector2(0, -10), "kill")
		"wax":
			var p := _add_pickup("wax", top + Vector2(0, -6))
			p["rise"] = 0.0
		"relic":
			_drop_relic(top, true, "common", world_n)   # a gold reliquary favours its world's relics (x2)


func break_tile(cell: Vector2i) -> void:
	## A cracked brick or false stone breaks.
	level.set_tile(cell.x, cell.y, LevelData.AIR)
	_redraw_at(cell.x)
	_sfx("block_break")
	_haptic(16)
	shake = maxf(shake, 3.0)
	_rubble().burst(LevelData.cell_center(cell), 8)


func _break_brick(cell: Vector2i) -> void:
	break_tile(cell)


func _redraw_at(x: int) -> void:
	if edges != null:
		edges.redraw_cell(x)
	var i := x / TileView.CHUNK
	if i >= 0 and i < chunks.size():
		chunks[i].queue_redraw()
	# A neighbour chunk's edge outlines may change too.
	var j := (x + 1) / TileView.CHUNK
	if j != i and j < chunks.size():
		chunks[j].queue_redraw()
	var k := (x - 1) / TileView.CHUNK
	if k != i and k >= 0:
		chunks[k].queue_redraw()


# ---------------------------------------------------------------- crumbling ledges

func vine_present(x: int, y: int) -> bool:
	## Is this vine cell climbable now? (A snapped rotten run isn't.)
	return features.vine_present(x, y) if features != null else true


func belt_dir(cell: Vector2i, dir: int) -> int:
	## Which way the belt at cell carries now (a boss may reverse a run).
	return features.belt_dir(cell, dir) if features != null and features.has_method("belt_dir") else dir


func relight(p: Node2D) -> bool:
	## A blow would snuff him: Hollin's Ember first (once an altar: 1 life,
	## burning white, untouchable for a moment). True when it caught him.
	if p != player or not player.stats.get("legends", {}).has("hollins_ember") or not _hollin_ready:
		return false
	_hollin_ready = false
	player.hp = 1.0
	player.invuln = maxf(player.invuln, _flag("hollin_invuln", 2.0))
	if glow:
		glow.burst(rig.flame_point(), 26, Color("f4f0ff"), 200.0, 0.8, -60.0, 2.8)
	if hud:
		hud.toast("Hollin's Ember", "Not yet, little flame")
	_sfx("relight")
	return true


func ledge_present(x: int, y: int) -> bool:
	var c: Dictionary = crumbles.get(Vector2i(x, y), {})
	return c.is_empty() or c["state"] != "fallen"


func ledge_shake(x: int, y: int) -> Vector2:
	var c: Dictionary = crumbles.get(Vector2i(x, y), {})
	if c.is_empty() or c["state"] != "shake":
		return Vector2.ZERO
	return Vector2(sin(_t * 70.0 + x) * 1.5, 0)


func stood_on(who: Node2D, x: int, y: int) -> void:
	if features != null:
		features.stood_on(who, x, y)
	if who != player:
		return
	var cell := Vector2i(x, y)
	if crumbles.has(cell) and crumbles[cell]["state"] == "idle":
		if twists != null and twists.holds_crumble(cell):
			return   # (lamplit: soft wax holds firm in lantern light)
		# The whole run of slabs goes together (but a lamplit slab in it).
		var cx := x
		while crumbles.has(Vector2i(cx - 1, y)):
			cx -= 1
		while crumbles.has(Vector2i(cx, y)):
			if crumbles[Vector2i(cx, y)]["state"] == "idle" and not (twists != null and twists.holds_crumble(Vector2i(cx, y))):
				crumbles[Vector2i(cx, y)] = {"state": "shake", "timer": 0.55}
			cx += 1


func _update_crumbles(dt: float) -> void:
	for cell in crumbles:
		var c: Dictionary = crumbles[cell]
		if c["state"] == "idle":
			continue
		c["timer"] -= dt
		if c["state"] == "shake":
			_redraw_at(cell.x)
			if c["timer"] <= 0.0:
				c["state"] = "fallen"
				c["timer"] = 3.5
				_redraw_at(cell.x)
				_rubble().burst(LevelData.cell_center(cell) + Vector2(0, -10), 3, true)
				if cell.x % 2 == 0:
					_sfx("block_break", 1.3)
		elif c["state"] == "fallen" and c["timer"] <= 0.0:
			# Back, unless something is standing in the way.
			var r := Rect2(cell.x * TILE, cell.y * TILE, TILE, 12)
			if not r.intersects(player.rect()):
				c["state"] = "idle"
				_redraw_at(cell.x)


# ---------------------------------------------------------------- touching

func _touch_enemies() -> void:
	var pr: Rect2 = player.rect()
	var ar: Rect2 = player.attack_rect()
	for e in enemies:
		if not e.alive or not e.active:
			continue
		var er: Rect2 = e.rect()
		# The swing first: a swing that lands saves the stomp-or-hurt check.
		if ar.size.x > 0.0 and ar.intersects(er) and e.last_swing != player.attack_id:
			e.last_swing = player.attack_id
			# The kit's opts for this swing on this foe (Judgment's force_crit,
			# Barrow Bind's extra_pct) ride in the swing's own deal.
			var o := {"how": "slash", "attack_id": player.attack_id, "heavy": kit.melee_coef() > 1.2}
			if kit.has_method("melee_opts"):
				o.merge(kit.melee_opts(e), true)
			var res := deal(e, kit.melee_coef(), o)
			# The Escapement: every 4th basic swing ticks twice (60%).
			if res["hit"] and e.alive and player.stats.get("legends", {}).has("escapement") \
					and _basics % maxi(int(_flag("escapement_every", 4.0)), 1) == 0:
				deal(e, kit.melee_coef() * _flag("escapement_coef", 0.6), {"how": "slash", "no_hitstop": true})
			if res["hit"]:
				_sfx("slash_hit")
				_haptic(14)
				shake = maxf(shake, 2.5)
				if glow:
					glow.burst(er.get_center(), 10, Color("fff4cf"), 190.0, 0.28, 0.0, 2.0)
			else:
				_sfx("clang")
				number(er.get_center() + Vector2(0, -er.size.y * 0.5), 0.0, "blocked", 0)
			continue
		if not e.hurt_rect().intersects(pr):
			continue
		if player.falling_onto(er):
			var thorn: bool = player.stats.get("legends", {}).has("thornsole")
			# Thornsole makes spikes and shields safe, not a boss: his head is
			# safe only while his body is (boss.gd keeps stompable in step).
			if e.stompable or e.status.has("flipped") or (thorn and e != boss):
				var st := Combat.stomp_damage(player.stats, rng)
				# Thornsole's double lives here only (hero.stats leaves it out).
				var amt: float = float(st["amount"]) * (_flag("thornsole_stomp", 2.0) if thorn else 1.0)
				if e.ordinary:
					amt = maxf(amt, e.max_hp)   # a stomp always kills fodder
				# A boss's head pays no chain: bouncing on it is no ember farm.
				# A monster back from a snuff (Nightfall, Dusk from World 3)
				# or an add counts but pays no embers: snuff, respawn and pogo
				# would be one too.
				if e != boss:
					_stomp_chain(er, not e.respawned)
				# Gravebloom Treads: a stomp always crits (x the crit multiplier)
				# and a stomp kill gives back 15% of his resource.
				var bloom: bool = player.stats.get("legends", {}).has("gravebloom")
				var scrit: bool = bool(st["crit"])
				if bloom and not scrit:
					amt *= float(player.stats.get("crit_mult", 1.5))
					scrit = true
				var sres := deal(e, 1.0, {"how": "stomp", "flat": amt, "force_crit": scrit, "safe_stomp": thorn})
				if bloom and sres["killed"] and player.res_max > 0.0:
					player.res = minf(player.res + player.res_max * _flag("gravebloom_res", 0.15), player.res_max)
				_stomp_powers(e, er)
				# An Anvil Drop's forced fall would override the bounce and drive
				# her back into the same head every tick: a head ends the drop.
				if player.dash_flags.get("anvil", false):
					player.end_dash()
				last_stomp_boss = e == boss
				player.bounce(player.jump_held())
				player.position.y = er.position.y
				_sfx("stomp")
				_haptic(20)
				freeze(0.04)
				if glow:
					glow.burst(Vector2(player.position.x, er.position.y), 8, Color("ffe0a0"), 120.0, 0.3, 200.0, 2.0)
				if Game.equipped("iron_boots"):
					_shockwave(Vector2(player.position.x, er.end.y))
				if Game.equipped("bell_shard"):
					# Not the boss: a stun skips his think(), so bouncing on his
					# head would freeze the fight (every other stun skips him too).
					for o in enemies_in(Rect2(player.position - Vector2(64, 64), Vector2(128, 96))):
						if o != boss:
							o.apply_status("stun", 1.0)
				continue
			# Spikes on top: ow, and up you go.
			if hurt_player(e.dmg("touch"), e.position.x, "spikes", e):
				player.velocity.y = -420.0
				_sfx("clang")
			continue
		if e.has_method("touch_damage") and not e.touch_damage():
			continue
		hurt_player(e.dmg("touch"), e.position.x, "hit", e)


func _stomp_powers(e: Node2D, er: Rect2) -> void:
	## A stomp landed: Rootbound Treads root every foe within 90 px of it;
	## the Hoarfrost Bell chills what he stomped (40% slower for 2 s).
	var at := Vector2(player.position.x, er.end.y)
	if player.stats.get("legends", {}).has("rootbound"):
		var r := _flag("rootbound_r", 90.0)
		for o in enemies:
			if o.alive and o != boss and o.center().distance_to(at) <= r:
				o.apply_status("root", _flag("rootbound_s", 1.2))
		if glow:
			glow.burst(at, 16, Color("9fc46a"), 130.0, 0.5, 200.0, 2.4)
	if _flag("chill_slow", 0.0) > 0.0 and e.alive:
		e.apply_status("slow", _flag("chill_t", 2.0))


func _stomp_chain(er: Rect2, pays := true) -> void:
	## Stomps without touching the floor: each pays one more ember, up to
	## CHAIN_PAY_MAX a stomp (a long Drift chain doesn't pay quadratically),
	## and five drops a wax stub (once a level). A stomp that doesn't pay (a
	## respawned monster's) still counts, sounds and shows.
	chain += 1
	if chain < 2:
		return
	for i in (mini(chain - 1, CHAIN_PAY_MAX) if pays else 0):
		var p := _add_pickup("ember", Vector2(player.position.x, er.position.y - 8.0))
		p["pop"] = true
		p["age"] = -0.05 * i
		p["vel"] = Vector2(randf_range(-40, 40), -380.0)
	floaters.add(Vector2(player.position.x, er.position.y - 24.0), 0.0, "text", 0, "Chain x%d" % chain)
	_sfx("chain_step", Sfx.note(mini(chain, 9)) if _has_sfx() else 1.0)
	if chain >= 5 and not _chain_wax_given:
		_chain_wax_given = true
		var w := _add_pickup("wax", Vector2(player.position.x, er.position.y - 20.0))
		w["loose"] = true
		w["vel"] = Vector2(0, -300)
		if glow:
			glow.burst(player.center(), 26, Color("ffd84a"), 200.0, 0.7, 0.0, 2.6)


func _shockwave(at: Vector2) -> void:
	shake = maxf(shake, 5.0)
	if glow:
		glow.burst(at, 16, Color("c8c8d4"), 220.0, 0.35, 0.0, 2.2)
	for e in enemies:
		if e.alive and e.active and e.position.distance_to(at) < 80.0 and e != boss:
			deal(e, 0.6, {"how": "shock", "no_hitstop": true})


func _touch_pickups() -> void:
	var pr: Rect2 = player.rect().grow(6.0)
	for p in pickups:
		if p["taken"]:
			continue
		if (p["loose"] and p["age"] < 0.25) or p.get("pop", false):
			continue
		if p.has("rise") and p["rise"] < 0.45:
			continue
		var over: bool = pr.has_point(p["pos"])
		if p.get("full", false):
			# A pickup the full satchel turned away waits until he has
			# stepped off it and its retry time has run out.
			if not over:
				p["near"] = false
			if p["near"] or float(p.get("retry", 0.0)) > 0.0:
				continue
		if over:
			_collect(p)


func _collect(p: Dictionary) -> void:
	if int(p.get("ent", -1)) >= 0:
		_taken.append(int(p["ent"]))   # (a placed ember or wax: the altar snapshot's)
	match p["kind"]:
		"ember":
			p["taken"] = true
			var worth: int = ember_worth()
			embers_got += worth
			embers_carried += worth
			if p.get("placed", false):
				# One of the level's own (embers_total's pieces): counted
				# once a piece, whatever the difficulty makes it worth.
				embers_placed += 1
			_ember_streak = _ember_streak + 1 if _ember_streak_t > 0.0 else 0
			_ember_streak_t = 0.7
			_sfx("ember", Sfx.note(mini(_ember_streak, 8)) if _has_sfx() else 1.0)
			if glow:
				glow.burst(p["pos"], 6, Color("f7b64a"), 90.0, 0.35, -60.0, 2.0)
			if hud:
				hud.bump_embers()
		"wax":
			if player.heal_pct(float(Combat.diff(diff)["wax"])):
				p["taken"] = true
				_sfx("wax")
				_haptic(12)
				number(p["pos"], float(Combat.diff(diff)["wax"]) * player.max_hp, "heal")
				if glow:
					glow.burst(p["pos"], 10, Color("fff4cf"), 100.0, 0.5, -100.0, 2.2)
				if hud:
					hud.bump_flames()
		"sigil":
			p["taken"] = true
			sigils_got[p["index"]] = true
			_sfx("sigil")
			_haptic(25)
			if not Game.sigil_found(level_id, p["index"]):
				gain_xp(Progression.event_xp("sigil", area), p["pos"])
			if glow:
				glow.burst(p["pos"], 20, Color("ffd84a"), 160.0, 0.7, 0.0, 2.6)
			if hud:
				hud.sigil_found(p["index"], sigils_got)
			bark("first_sigil")
		"relic":
			p["taken"] = true
			var id: String = p["relic"]
			var on: bool = Game.grant_relic(id)
			relics_found.append(id)
			if not on and not _relic_wait.has(id):
				_relic_wait.append(id)   # (the next lit altar offers it: open_relic)
			apply_hero()
			var r: Dictionary = Relics.get_relic(id)
			_sfx("relic_" + r["rarity"])
			if _has_sfx():
				Sfx.duck_music(-10.0, 1.6)
			_haptic(40)
			if glow:
				glow.burst(p["pos"], 24, glow.RARITY[r["rarity"]], 180.0, 0.8, -40.0, 2.8)
			if hud:
				hud.relic_found(id)
				if not on:
					hud.toast(r["name"], relic_where())
			bark("first_relic")
		"item":
			if _take_item(p["item"]) == "full":
				# No room: it stays on the ground with its beam. It asks again
				# only once he has stepped off it and a moment has passed.
				p["full"] = true
				p["retry"] = FULL_RETRY
				p["near"] = true
			else:
				p["taken"] = true
				p.erase("full")
				_mark_boss_first(p)
	if p["taken"] and p.has("sprite"):
		p["sprite"].queue_free()
		p.erase("sprite")


func _mark_boss_first(p: Dictionary) -> void:
	## The boss's first-kill prize has been picked up: only now does this
	## difficulty's record say it was given.
	if p.get("boss_first", false) and allows("record"):
		Game.level_record(level_id)["boss_first"] = true


func _take_item(it: Dictionary) -> String:
	## A new item: worn at once if it's plainly better (auto-equip), else
	## into the satchel. The pickup card says which, with its two chips.
	## Returns where it went: "equipped", "satchel", "salvaged" (melted into
	## embers: a Common with auto-salvage, or anything no better than what's
	## worn when the satchel is full) or "full" (no room: it stays put).
	## A Legendary counts as better over a worn piece that isn't one (its
	## power is nothing in the chips: _legend_over), and has its moment; a
	## worn Legendary is never swapped out by a piece that isn't one, however
	## its chips read (_legend_kept): that goes to the satchel, its card
	## offering to wear it.
	var h: Dictionary = Game.hero()
	var chips := Hero.compare(h, it["slot"], it, h.get("belt", []), diff)
	var better: bool = chips["dmg"] >= 0.0 and chips["life"] >= 0.0 and (chips["dmg"] > 0.0 or chips["life"] > 0.0)
	better = (better and not _legend_kept(h, it)) or _legend_over(h, it)
	var where := ""
	if better and bool(Game.setting("auto_equip")):
		Game.equip(it)
		where = "equipped"
		apply_hero()
		_sfx("equip")
	else:
		where = Game.add_item(it)
		if where == "salvaged":
			_sfx("salvage")
			if hud:
				hud.bump_embers()
		elif where == "full":
			_sfx("clang", 0.8)
	if where != "full":
		items_found.append(it)
		var g := _game()
		if str(it.get("legend", "")) != "" and g != null and g.has_method("note_legend"):
			g.note_legend(str(it["legend"]))
	if hud and hud.has_method("show_pickup"):
		hud.show_pickup(it, chips, where)
	_legend_moment(it, where)
	if where != "full":
		bark("first_item")   # "...the rest waits in your satchel": not while it's full
	return where


func _legend_over(h: Dictionary, it: Dictionary) -> bool:
	## A new Legendary is worn (with auto-equip) over a piece that isn't one,
	## or in an empty slot, whatever its chips say, unless wearing it would
	## melt the worn piece for good (the satchel full: Game.melt_on_equip);
	## then the card asks, as for any piece.
	if str(it.get("legend", "")) == "":
		return false
	var worn = h.get("equip", {}).get(str(it.get("slot", "")))
	if worn is Dictionary and str(worn.get("rarity", "")) == "legendary":
		return false
	return Game.melt_on_equip(it).is_empty()


func _legend_kept(h: Dictionary, it: Dictionary) -> bool:
	## A piece that isn't a Legendary, for a slot that wears one: never worn
	## over it by itself (the Legendary's power is nothing in the chips).
	if str(it.get("legend", "")) != "":
		return false
	var worn = h.get("equip", {}).get(str(it.get("slot", "")))
	return worn is Dictionary and str(worn.get("rarity", "")) == "legendary"


func _legend_moment(it: Dictionary, where: String) -> void:
	## A Legendary taken (worn, or into the satchel): the world stops a beat
	## (LEGEND_FREEZE), its glow bursts round him, a buzz, and the HUD holds
	## its card 5 s as a "New power" (hud.power_card). Only for a player at
	## the controls (_loot_moment_ok). A Legendary the full satchel left on
	## the ground has its card ask instead (and asks again), never a moment.
	if str(it.get("legend", "")) == "" or not (where in ["equipped", "satchel"]) or not _loot_moment_ok():
		return
	freeze(LEGEND_FREEZE, true)
	if glow:
		glow.burst(player.center(), 30, glow.RARITY["legendary"], 210.0, 0.9, -30.0, 3.0, 60.0)
	_haptic(40)
	hud_call("power_card", [it])


func _loot_moment_ok() -> bool:
	## A pickup's moment (a freeze, a held card) is a player's: never headless,
	## under --autoplay, or while a golden route is replayed or recorded
	## (no_monsters, on_pad, test_pad), where a freeze would put the run off
	## its recorded ticks.
	return not headless and not autoplay and not no_monsters and test_pad == null and not on_pad.is_valid()


func claim_item(it: Dictionary) -> void:
	## The "Satchel full" card was tapped: the HUD wears the item, so it
	## leaves the ground now (the next tick would see it owned anyway).
	var uid := str(it.get("uid", "-"))
	for p in pickups:
		if p["taken"] or str(p.get("kind", "")) != "item" or not (p.get("item") is Dictionary):
			continue
		if str(p["item"].get("uid", "")) != uid:
			continue
		p["taken"] = true
		p.erase("full")
		items_found.append(p["item"])
		_mark_boss_first(p)
		if p.has("sprite"):
			p["sprite"].queue_free()
			p.erase("sprite")
		if glow:
			glow.burst(p["pos"], 10, glow.RARITY.get(p["rarity"], Color.WHITE), 110.0, 0.4, -60.0, 2.2)
		return


func _owned(it: Dictionary) -> bool:
	## Is this item worn or in the satchel now? (A "full" pickup worn from its
	## card leaves the ground.)
	var h: Dictionary = Game.hero()
	var uid := str(it.get("uid", "-"))
	for slot in h.get("equip", {}):
		var e = h["equip"][slot]
		if e is Dictionary and str(e.get("uid", "")) == uid:
			return true
	for o in h.get("satchel", []):
		if o is Dictionary and str(o.get("uid", "")) == uid:
			return true
	return false


func undo_equip(it: Dictionary) -> void:
	## The pickup card's tap within 3 s after an auto-equip.
	var h: Dictionary = Game.hero()
	for i in range((h["satchel"] as Array).size() - 1, -1, -1):
		var o = h["satchel"][i]
		if o is Dictionary and o["slot"] == it["slot"] and o.get("uid", "") != it.get("uid", ""):
			Game.equip(o)
			apply_hero()
			return


func _touch_world() -> void:
	var pr: Rect2 = player.rect()
	var x0 := floori(pr.position.x / TILE)
	var x1 := floori((pr.end.x - 0.01) / TILE)
	var y0 := floori(pr.position.y / TILE)
	var y1 := floori((pr.end.y - 0.01) / TILE)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var t: int = level.tile(x, y)
			if not level.hurts_at(x, y, pr):
				continue
			match t:
				LevelData.SPIKES_UP:
					if hurt_player(SPIKE_PCT, x * TILE + 16, "spikes", null, {"pct": true}):
						player.velocity = Vector2(player.velocity.x * 0.3, -430.0)
						_spike_sfx()
						shake = maxf(shake, 4.0)
				LevelData.SPIKES_DOWN:
					if hurt_player(SPIKE_PCT, x * TILE + 16, "spikes", null, {"pct": true}):
						player.velocity.y = 200.0
						_spike_sfx()
				LevelData.LAVA:
					_sfx("lava")
					if glow:
						glow.burst(player.position, 18, Color("f28a2b"), 170.0, 0.6, 200.0, 2.5, 120.0)
					fell("lava")
					return
				LevelData.WATER:
					# (not while he rides a float that's still there: it goes
					# under at float_sink's 1.3 s, and he with it, not before;
					# the rev5 review found the water taking him at 23 of 24 px)
					var fm = player.riding
					if fm != null and is_instance_valid(fm) and str(fm.get("kind")) == "float" and bool(fm.get("present")):
						continue
					_sfx("splash")
					fell("water")
					return
	for h in hazards:
		if h["owner"] != "enemy" or h.get("delay", 0.0) > 0.0:
			continue
		if h["kind"] == "beam":
			# A segment with a width (a Refractor's, the Saint's): a Knight's
			# Guard may block it (the kit's filter sees kind "beam" and the hazard).
			var seg: Array = h.get("seg", [])
			if seg.size() == 2 and seg_hits_rect(seg[0], seg[1], float(h.get("width", 8.0)), pr.grow(-3.0)):
				if hurt_player(float(h["dmg"]), (seg[0] as Vector2).x, "beam", h.get("source"), {"hazard": h, "shot": true}) and h.get("douse", false):
					_douse()
			continue
		if h["kind"] == "pit_band":
			if (h["rect"] as Rect2).has_point(player.center()):
				fell(str(h.get("fall", "pit")))
				return
			continue
		var hr: Rect2 = h["rect"]
		if hr.grow(-3.0).intersects(pr):
			if hurt_player(float(h["dmg"]), hr.get_center().x, h["kind"], h.get("source"), {"shot": h.get("shot", false), "move": h.get("move", ""), "feature": h.get("feature", "")}) and h.get("douse", false):
				_douse()
	if player.position.y > level.height * TILE + 48:
		fell("pit")
		return
	# Altars.
	for a in altars:
		if not a["lit"] and absf(player.position.x - a["pos"].x) < 22.0 and absf(player.position.y - a["pos"].y) < 40.0:
			_light_altar(a)
	# The bell.
	for b in bells:
		if not b["rung"] and b["rope"].intersects(pr):
			_ring(b)
	# The Guttered Pool.
	if not pool.is_empty() and pr.grow(8.0).has_point(pool["pos"]):
		_reclaim_pool()
	# Signs.
	_read_signs()
	if player.life_frac() < 0.25:
		bark("low_flame")


const SIGN_REACH := 64.0        # px across a sign's post he reads it from (v2's 44: a run passed it in under half a second)
const SIGN_LINGER := 2.0        # s the last sign's text stays up after he walks on (then the HUD's own fade)
var _sign_text := ""            # the last sign read...
var _sign_left := -100.0        # ...and the _t he was last by it


func _read_signs() -> void:
	## The sign Wick stands by puts its text in the HUD's slot, and the last
	## one keeps it there SIGN_LINGER s after he walks on, so a sign reads on
	## the run. While the slot can't draw it (hud.hint_held: a title card or
	## the level-up card is up, or a message has the slot: a level's first
	## sign is under its title, then under the barks queued behind it, like
	## 3-1's first_vine and beat_3_1), the linger waits, so its SIGN_LINGER s
	## start once the slot is free. A board he has stood by stops glinting
	## (sign_view.gd, this visit only).
	var near := ""
	for s in signs:
		if absf(player.position.x - s["pos"].x) < SIGN_REACH and absf(player.position.y - s["pos"].y) < 60.0:
			near = s["text"]
			var node = s.get("node")
			if node != null and node.has_method("mark_read"):
				node.mark_read()
	if near != "":
		_sign_text = near
		_sign_left = _t
	elif _sign_text != "" and _t - _sign_left < SIGN_LINGER:
		near = _sign_text
		if hud and hud.has_method("hint_held") and hud.hint_held():
			_sign_left = _t
	if hud:
		hud.show_hint(near)


func _douse() -> void:
	if Game.equipped("wind_wick"):
		return
	if player.has_status("douse"):
		hurt_player(float(Combat.diff(diff)["douse_pct"]), player.position.x, "douse", null, {"pct": true, "no_knock": true})
	player.apply_status("douse", 3.0)
	_sfx("douse")
	bark("first_douse")


func douse_player() -> void:
	_douse()


func _light_altar(a: Dictionary) -> void:
	a["lit"] = true
	a["glow"] = 1.0
	checkpoint = a["pos"]
	var pct: float = Combat.altar_heal(diff, _teeth_world()) * twist_heal()   # (Dusk heals less from World 3; dry less again)
	_last_altar_hp.append(roundf(player.life_frac() * 100.0))
	var healed = player.heal_pct(pct)
	flask_charges = flask_max()
	_twin_ready = true
	_hollin_ready = true
	_lastcandle_ready = true
	_bank()
	gain_xp(Progression.event_xp("altar", area), a["pos"])
	var lit := prop_path("altar_lit")
	if ResourceLoader.exists(lit):
		a["sprite"].texture = load(lit)
	_frost_altar(a)
	_sfx("altar")
	_haptic(20)
	if glow:
		glow.burst(a["flame"], 22, Twists.FROST if twist("dry") else Color("f7b64a"), 150.0, 0.8, -60.0, 2.6)
	if healed:
		number(a["flame"] + Vector2(0, -10), pct * player.max_hp, "heal")
	if hud:
		hud.toast("Altar lit", "Your flame will return here")
	bark("first_altar")
	_write_suspend(a)
	_altar_rites(a)


func _frost_altar(a: Dictionary) -> void:
	## dry (twists.gd): a lit altar burns frost-blue, so the rule shows on
	## the altar and not only on its card (glow.gd draws its flame so).
	if twist("dry") and a.get("sprite") is CanvasItem:
		(a["sprite"] as CanvasItem).modulate = Twists.FROST


# ---------------------------------------------------------------- the Altar Rites

func rites_block() -> String:
	## Why a lit altar can't offer its Rites ("" = it can): only a story
	## level played by a player (player_block), with a skill point waiting.
	var why := player_block()
	if why != "":
		return why
	if int(Game.hero().get("points", 0)) <= 0 or Rites.picks(Game.hero()).is_empty():
		return "no points"
	return ""


func player_block() -> String:
	## Why no choice may stop this level ("" = one may: the Rites, a boss's
	## boon): only a story level played by a player. Never in a mode (the
	## Descent's landing has its Glimmers) or a feel lab, under the
	## --autoplay bot, a golden route's recording or replay (no_monsters,
	## on_pad), a scripted pad (tests, shots) or headless (a World made so,
	## or no display at all: no_display).
	if mode != null:
		return "mode"
	if is_lab():
		return "lab"
	if autoplay:
		return "autoplay"
	if no_monsters or on_pad.is_valid():
		return "route"
	if test_pad != null:
		return "scripted"
	if headless or no_display:
		return "headless"
	if hud == null:
		return "no hud"
	return ""


func foes_near(r := RITES_CLEAR) -> bool:
	## A monster awake within r px of Waxby, or a boss awake anywhere (one
	## asleep in his arena, or a mimic, doesn't count).
	for e in enemies:
		if not e.alive or not e.active or str(e.get("state")) == "sleep":
			continue
		if e == boss or e.center().distance_to(player.center()) < r:
			return true
	return false


func _altar_rites(a: Dictionary) -> void:
	## An altar lit with a skill point waiting, or a relic found with the
	## belt full: its Rites (and then the relic) wait for a tick that may
	## open them (_tick_rites; the next one, if the area is clear).
	if rites_block() == "" or relic_block() == "":
		_rites_altar = altars.find(a)
		_rites_wait = 0.0


func _tick_rites(dt: float) -> void:
	## The waiting Rites open once he stands in play with no monster awake
	## near and the top band clear: a title card is cut short (at most 0.5 s,
	## as the Descent's landing does), the level-up card has its 2.2 s. Gone
	## past RITES_LEASH from the altar first (or the point spent), the next
	## altar asks instead. Snuffed first, they wait again when he relights
	## at that altar (_rites_snuffed). A choice up holds the World (as the
	## Descent holds it under its Glimmers), and a story beat that took the
	## World this very tick goes first.
	if choice != null and choice.is_open():
		paused = true
		return
	if paused:
		return
	var a: Dictionary = altars[_rites_altar] if _rites_altar < altars.size() else {}
	if a.is_empty() or (rites_block() != "" and relic_block() != "") or state != "play" or not player.alive \
			or player.position.distance_to(a["pos"]) > RITES_LEASH:
		_rites_snuffed = _rites_altar if state == "dead" or not player.alive else -1
		_rites_altar = -1
		return
	if not player.on_floor or hitstop > 0.0 or time_stopped() or foes_near():
		return
	if hud.has_method("title_showing") and hud.title_showing() and _rites_wait < 0.5:
		_rites_wait += dt
		if hud.has_method("cut_title"):
			hud.cut_title()
		return
	if hud.has_method("top_card_showing") and hud.top_card_showing() and not hud.title_showing():
		return   # (the level-up card, or a title card waiting behind it)
	_rites_altar = -1
	if not open_rites():
		open_relic()


func open_rites() -> bool:
	## The Rites on the choice card: up to three skills Waxby can learn now
	## (rites.gd), or Later (the point keeps: the next altar asks again, or
	## the Sheet). A pick learns it at once: the pillar, the sound, a toast.
	var cards := Rites.offers(Game.hero())
	return offer_choice(cards, {"heading": Rites.heading(Game.hero()), "later": "Later", "pick": func(i): _rite_picked(cards, i)})


func _rite_picked(cards: Array, i: int) -> void:
	## A skill picked: learned at once. The first of a big tier (a capstone,
	## a Deep or Mastery node) grows the flame (Hero.FLAME_TIER), and that
	## has its own beat: a flare at the flame and "Your flame grows". While
	## points and skills are left the cards come again with the next three
	## (as the results screen's do); Later ends it. Then a relic found with
	## the belt full has its turn (open_relic).
	if i < 0 or i >= cards.size():
		open_relic()
		return
	var id := str(cards[i].get("id", ""))
	var flame0 := float(player.stats.get("flame_scale", 1.0))
	if not Game.buy_skill(id):
		return
	apply_hero()
	var grew := float(player.stats.get("flame_scale", 1.0)) > flame0 + 0.001
	_sfx("glimmer")
	_haptic(30)
	if glow:
		glow.burst(player.center(), 28, Color("ffd84a"), 200.0, 0.8, -60.0, 2.6)
		glow.pillar(player.position)
		if grew:
			glow.burst(rig.flame_point(), 24, Color("fff4cf"), 140.0, 0.9, -120.0, 3.0)
	if hud:
		hud.toast(str(cards[i].get("name", "")), Rites.learned(Game.hero(), id))
		if grew:
			hud.toast("Your flame grows", "A new tier of your tree")
	if int(Game.hero().get("points", 0)) > 0 and not Rites.picks(Game.hero()).is_empty():
		open_rites()
	else:
		open_relic()


func relic_block() -> String:
	## Why a lit altar can't offer a relic found with the belt full ("" = it
	## can): a player's story level (player_block, as for the Rites) and one
	## found this visit that's still off the belt.
	var why := player_block()
	if why != "":
		return why
	var belt: Array = Game.hero().get("belt", [])
	if _relic_wait.all(func(id): return belt.has(id)):
		return "none waiting"
	return ""


func relic_ahead() -> bool:
	## Whether a relic found now with the belt full will be offered on the
	## swap card (open_relic): a player's story level (player_block) with an
	## altar still to light, or one just lit still to ask (_rites_altar).
	## Else it waits in the codex for the map's Sheet. (The HUD's relic card
	## asks this too.)
	if player_block() != "":
		return false
	return _rites_altar >= 0 or altars.any(func(a): return not bool(a.get("lit", false)))


func relic_where() -> String:
	## Where a relic found with the belt full goes on, for its toast: the
	## next altar's swap card, or the map's Sheet.
	return "The next altar offers it" if relic_ahead() else "In your codex · change your belt on the map"


func open_relic() -> bool:
	## A relic found with the belt full, at the next lit altar: it on one
	## card and the weakest worn one (by rarity, then the first belted) on
	## the other, and no button: a tap wears the new one in its place (the
	## old one back in the codex) or keeps the belt. This card is the only
	## way the belt changes in a level (the pause Sheet's Belt tab is only to
	## look at); otherwise it changes on the map. With a slot free by now (a
	## level gained) it simply goes on. Then the next one waiting. False when
	## nothing was asked.
	if relic_block() != "":
		return false
	var belt: Array = Game.hero().get("belt", [])
	var id := ""
	while id == "" and not _relic_wait.is_empty():
		var r := str(_relic_wait.pop_front())
		if not belt.has(r):
			id = r
	if id == "":
		return false
	if Game.grant_relic(id):
		_relic_on(id, "")
		open_relic()
		return true
	var weak := _weakest_relic(belt)
	var cards := [_relic_card(id, "new · wear it"), _relic_card(weak, "worn · keep it")]
	cards[0]["new"] = true
	return offer_choice(cards, {"heading": "Your belt is full", "later": "", "pick": func(i): _relic_picked(id, weak, i)})


static func _weakest_relic(belt: Array) -> String:
	## The worn relic of the lowest rarity (Relics.RARITY_ORDER), the first
	## belted of those.
	var out := ""
	var low := 99
	for r in belt:
		var k := Relics.RARITY_ORDER.find(str(Relics.get_relic(str(r)).get("rarity", "common")))
		if k < low:
			low = k
			out = str(r)
	return out


func _relic_card(id: String, sub: String) -> Dictionary:
	## A relic as a choice card: its name, what it does, its rarity's colour.
	var r: Dictionary = Relics.get_relic(id)
	var rarity := str(r.get("rarity", "common"))
	return {"id": id, "name": str(r.get("name", id)), "text": str(r.get("text", "")), "glyph": "charm",
			"col": UI.rarity_color(rarity), "sub": "%s · %s" % [Relics.RARITY_NAME.get(rarity, ""), sub]}


func _relic_picked(id: String, weak: String, i: int) -> void:
	## The new relic tapped (0): on the belt in the weak one's place. The worn
	## one: the belt stays. Then the next relic waiting, if any.
	if i == 0:
		var belt: Array = (Game.hero().get("belt", []) as Array).duplicate()
		var k := belt.find(weak)
		if k >= 0:
			belt[k] = id
			Game.set_belt(belt)
			_relic_on(id, weak)
	open_relic()


func _relic_on(id: String, off: String) -> void:
	## A relic just put on the belt at an altar: felt at once (apply_hero),
	## its fanfare, a burst, and a toast naming what went back to the codex.
	apply_hero()
	var r: Dictionary = Relics.get_relic(id)
	var rarity := str(r.get("rarity", "common"))
	_sfx("relic_" + rarity)
	_haptic(30)
	if glow:
		glow.burst(player.center(), 24, glow.RARITY.get(rarity, Color.WHITE), 180.0, 0.8, -40.0, 2.8)
	if hud:
		var sub := "On your belt" if off == "" else "On your belt · %s back in the codex" % str(Relics.get_relic(off).get("name", off))
		hud.toast(str(r.get("name", id)), sub)


func offer_choice(offers: Array, opts: Dictionary) -> bool:
	## A choice over the paused level, on the choice card (choice_card.gd;
	## opts as its open(): heading, later, pick, pair). pick(i) is called once
	## the card is down and play is back (i = -1: the button). The touch
	## controls let go of every press they held and take no touch while it's
	## up, so nothing held runs on after it, and a tick-locked track is put
	## back on the feature clock as after the pause (sync_music: the clock
	## stood still under the card, the music didn't). Never on a headless
	## World; the caller says when a player is there to ask (rites_block).
	## False when nothing was asked.
	if headless or offers.is_empty() or (choice != null and choice.is_open()):
		return false
	if choice == null:
		var layer := CanvasLayer.new()
		layer.layer = 7   # over the HUD (5) and the touch controls (6), under pause (10)
		add_child(layer)
		choice = ChoiceCard.new()
		choice.world = self
		layer.add_child(choice)
	paused = true
	_hold_touch(true)
	var then: Callable = opts.get("pick", Callable())
	var o := opts.duplicate()
	o["pick"] = func(i: int) -> void:
		choice.close()
		_hold_touch(false)
		paused = false
		sync_music()
		if then.is_valid():
			then.call(i)
	choice.open(offers, o)
	return true


func _hold_touch(on: bool) -> void:
	## The touch controls under a choice: every held press let go, and no
	## touch taken while it's up (on); live again after, holding nothing.
	if touch == null:
		return
	if touch.has_method("release_all"):
		touch.release_all()
	touch.set_process_input(not on)


# ---------------------------------------------------------------- the Boss Boons

func boon_block() -> String:
	## Why a boss's first kill can't offer his boon ("" = it can): a player
	## at the controls of a story level (player_block, as for the Rites), the
	## screen not under the Hush finale's black (it stays black to the
	## level's end: his prize drops and the finale gathers it to him), and a
	## choice to make (boon_ids: two at least). Else his prize drops as it
	## always did (_boss_prize). Later kills drop as they always did.
	var why := player_block()
	if why != "":
		return why
	if finale_black > 0.0:
		return "finale"
	if boon_ids(RandomNumberGenerator.new()).size() < 2:
		return "no choice"
	return ""


func boon_ids(r: RandomNumberGenerator = null) -> Array:
	## The Legendaries this level's boss offers the hero now
	## (Items.boon_legends): his signature first, then others the hero
	## doesn't hold; r draws the others (the World's rng by default).
	var k := _legends_known()
	return Items.boon_legends(world_n, str(Game.hero()["cls"]), area, k["held"], k["found"], r if r != null else rng)


func _legends_known() -> Dictionary:
	## {held: the Legendaries the hero wears or carries, found: every one
	## picked up in this save}.
	var held: Array = []
	var found: Array = []
	var gs = _game()
	if gs != null:
		(gs.get_script() as Script).call("_legends_held", gs.hero(), held)
		if gs.has_method("legends_found"):
			found = gs.legends_found()
	return {"held": held, "found": found}


func boon_offers(who := "") -> Array:
	## boon_ids() as choice cards, each Legendary made now at the prize's
	## item level (area + 2, as _boss_prize's): {id, item, name, text (its
	## power), glyph (its slot's), col (Legendary gold), sub ("Weapon · Old
	## Tollgrave's own" for his signature, "· you have one" for one the hero
	## holds), new (never found in this save)}.
	var h: Dictionary = Game.hero()
	var k := _legends_known()
	var signed := Items.world_legends(world_n)
	var out: Array = []
	for id in boon_ids():
		var slot := str(Items.LEGENDS[id]["slot"])
		var it := Items.make(slot, h["cls"], area + 2, "legendary", rng, id)
		var sub := slot.capitalize()
		if (k["held"] as Array).has(id):
			sub += " · you have one"
		elif signed.has(id):
			sub += " · %s own" % whose(who)
		out.append({"id": id, "item": it, "name": str(it["name"]), "text": Items.key_line(it), "glyph": UI.slot_glyph(slot),
				"col": UI.rarity_color("legendary"), "sub": sub, "new": not (k["found"] as Array).has(id)})
	return out


func _tick_boon(dt: float) -> void:
	## A boss's boon waiting: it opens once his fall has settled (BOON_WAIT
	## of play, no monster awake near, the level-up card his XP brought had
	## its time, a title card cut short as for the Rites). A bell rung first
	## (the Saint's and the Hush's come down at his feet) holds the level's
	## end for it (_update_clear). Snuffed first, it waits for the relight.
	## A choice, a story beat or the pause holding the World goes first. No
	## player left to ask (a test's pad, a route), or no choice: the prize
	## drops as before.
	if paused or (choice != null and choice.is_open()):
		return
	var at: Vector2 = _boon["at"]
	if player_block() != "":
		_boon = {}
		_boss_prize(at)
		return
	if state == "dead" or not player.alive:
		return   # (snuffed: it opens after the relight)
	_boon["t"] = float(_boon["t"]) + dt
	if float(_boon["t"]) < BOON_WAIT or time_stopped() or (state == "play" and foes_near()):
		return
	if hud.has_method("title_showing") and hud.title_showing() and float(_boon["wait"]) < 0.5:
		_boon["wait"] = float(_boon["wait"]) + dt
		if hud.has_method("cut_title"):
			hud.cut_title()
		return
	if hud.has_method("top_card_showing") and hud.top_card_showing() and not hud.title_showing():
		return   # (the level-up card, or a title card waiting behind it)
	var who := str(_boon.get("who", ""))
	_boon = {}
	if not open_boon(who):
		_boss_prize(at)


func open_boon(who := "") -> bool:
	## The boss's boon on the choice card: two or three Legendaries, his
	## signature first (boon_offers), each naming its power, and no button
	## (a prize is taken, not put off). False with no choice to make (the
	## caller drops his prize as before).
	var cards := boon_offers(who)
	if cards.size() < 2:
		return false
	var heading := ("%s prize · choose one" % whose(who)) if who != "" else "Choose a prize"
	return offer_choice(cards, {"heading": heading, "later": "", "pick": func(i): _boon_picked(cards, i)})


static func whose(who: String) -> String:
	## A boss's name as an owner, short of its " of ...": "Old Tollgrave's",
	## "The Tinker's" (the Tinker of Hours); "the boss's" with no name.
	return (who.get_slice(" of ", 0) if who != "" else "the boss") + "'s"


func _boon_picked(cards: Array, i: int) -> void:
	## A boon chosen (a stray -1 takes the first, his signature): it's his at
	## once through the pickup's own path (_collect, _take_item: worn over a
	## piece that isn't a Legendary with auto-equip, its New power moment;
	## with the satchel full it waits at his feet and asks, as any pickup
	## does), and the first kill counts once it's taken (_mark_boss_first).
	if cards.is_empty():
		return
	var c: Dictionary = cards[i] if i >= 0 and i < cards.size() else cards[0]
	var p := place_item(c["item"], player.center(), Vector2(0, -160.0))
	p["boss_first"] = true
	_collect(p)


# ---------------------------------------------------------------- the altar snapshot

func _resuming() -> bool:
	## main handed a snapshot for this very level (and no mode is playing it).
	return not resume.is_empty() and mode == null and str(resume.get("level", "")) == level_id \
			and str(resume.get("diff", diff)) == diff


func _resume_has(key: String, ei: int) -> bool:
	if resume.is_empty():
		return false
	var a = resume.get(key, [])
	if not (a is Array):
		return false
	for x in a:
		if int(x) == ei:
			return true
	return false


func _suspend_allowed() -> bool:
	return mode == null and not is_lab() and not headless and not autoplay and allows("record") \
			and _game() != null and _game().has_method("set_suspend")


func _write_suspend(a: Dictionary) -> void:
	## The snapshot main offers on the map after an app kill (spec §9.1): the
	## level loads fresh, the hero starts at this altar with these sigils, and
	## what he killed or took before it stays gone.
	if not _suspend_allowed():
		return
	# What the feature modules keep (deep.gd: the Vigil candles lit).
	var feats := {}
	if features != null and "by_name" in features:
		for n in features.by_name:
			var m = features.by_name[n]
			if m != null and m.has_method("snapshot"):
				var d: Dictionary = m.snapshot()
				if not d.is_empty():
					feats[n] = d
	var sus := {"level": level_id, "diff": diff, "altar": altars.find(a), "time": time,
			"sigils": sigils_got.duplicate(), "embers_carried": embers_carried, "killed": _killed.duplicate(),
			"taken": _taken.duplicate(), "opened": _opened.duplicate(true), "at": int(Time.get_unix_time_from_system())}
	if not feats.is_empty():
		sus["features"] = feats
	_game().set_suspend(sus)


func _drop_suspend() -> void:
	if _suspend_allowed() and _game().has_method("clear_suspend"):
		var sus: Dictionary = _game().suspended() if _game().has_method("suspended") else {}
		if str(sus.get("level", "")) == level_id:
			_game().clear_suspend()


func _apply_resume() -> void:
	## Starts the level at the snapshot's altar: the altars up to it lit (no
	## heal, XP or sound), its sigils back, its reliquaries spent, the clock
	## where it was. The monsters and pickups in it were skipped at the build.
	if not _resuming():
		resume = {}
		return
	var ai := int(resume.get("altar", -1))
	if ai < 0 or ai >= altars.size():
		resume = {}
		return
	var lit := prop_path("altar_lit")
	for i in ai + 1:
		var a: Dictionary = altars[i]
		a["lit"] = true
		if ResourceLoader.exists(lit):
			a["sprite"].texture = load(lit)
		_frost_altar(a)
	checkpoint = altars[ai]["pos"]
	player.reset_at(checkpoint)
	cam = cam_on(player.position)
	_cam_y_target = cam.y
	time = float(resume.get("time", 0.0))
	embers_carried = int(resume.get("embers_carried", 0))
	for c in resume.get("opened", []):
		if c is Array and c.size() == 2:
			var cell := Vector2i(int(c[0]), int(c[1]))
			if blocks.has(cell) and not blocks[cell]["spent"]:
				var b: Dictionary = blocks[cell]
				b["spent"] = true
				_opened.append([cell.x, cell.y])
				level.set_tile(cell.x, cell.y, LevelData.SPENT)
				var spent := "res://art/props/reliquary_spent.svg"
				if ResourceLoader.exists(spent):
					(b["sprite"] as Sprite2D).texture = load(spent)
	var sg = resume.get("sigils", [])
	for p in pickups:
		if p["kind"] == "sigil" and sg is Array and int(p["index"]) < sg.size() and bool(sg[int(p["index"])]):
			sigils_got[int(p["index"])] = true
			p["taken"] = true
			if p.has("sprite"):
				(p["sprite"] as Node).queue_free()
				p.erase("sprite")
			if hud and hud.has_method("sigil_found"):
				hud.sigil_found(int(p["index"]), sigils_got)
	for k in resume.get("killed", []):
		_killed.append(int(k))
	for k in resume.get("taken", []):
		_taken.append(int(k))
	var feats = resume.get("features", {})
	if feats is Dictionary and features != null and features.has_method("module"):
		for n in feats:
			var m = features.module(str(n))
			if m != null and m.has_method("restore") and feats[n] is Dictionary:
				m.restore(feats[n])
	resume = {}


func _bank() -> void:
	## Carried embers become safe (an altar, the bell, leaving the level). A
	## feel lab's go nowhere (it writes nothing), with the same look and sound.
	if embers_carried > 0:
		if not is_lab():
			Game.add_embers(embers_carried)
		embers_carried = 0
		if hud and hud.has_method("banked"):
			hud.banked()
		_sfx("bank")
	Game.carry_embers(0)   # nothing left unbanked for the save to hold


func _ring(b: Dictionary) -> void:
	b["rung"] = true
	b["vel"] = 3.2
	if b.get("silver", false):
		# A silver bell: the level clears by its other way out, and the
		# secret level its header names opens.
		secret_found = str(level.secret)
		# Opened (and saved) as it rings, so quitting during the bell loses
		# nothing; the result says whether this was the first time
		# (secret_new), so record_result still reports it. Never in a lab or
		# a mode (they keep no records).
		if secret_found != "" and allows("record") and not headless and Game.has_method("find_secret"):
			secret_new = bool(Game.find_secret(secret_found))
		_sfx("secret_found")
		if hud:
			hud.toast("Secret found!", "")
		secret_rung.emit(secret_found)
	state = "clear"
	clear_time = 0.0
	_drop_suspend()
	player.frozen = true
	rig.mood = "happy"
	_gather_boss_embers()
	_bank()
	var first: bool = allows("record") and not Game.level_record(level_id)["cleared"]
	# A secret level's first clear pays its own 45 x E(A) (spec §7, contract).
	var clear_ev := "clear"
	if first:
		clear_ev = "secret_clear" if is_secret_level() and Progression.EVENT_XP.has("secret_clear") else "first_clear"
	gain_xp(Progression.event_xp(clear_ev, area), b["top"])
	# A silver bell rings its own voice (falls back to v2's bell until it's
	# rendered). From World 3 on, the level's bell rings the Lull's first
	# note (spec §6.6); W1-W2's is v2's D.
	if b.get("silver", false):
		_sfx("silver_bell")
	elif world_n >= 3 and _has_sfx() and Sfx.has_method("note"):
		_sfx("bell", Sfx.note(3))
	else:
		_sfx("bell")
	if _has_sfx():
		Sfx.duck_music(-14.0, 3.0)
	_haptic(50)
	shake = 3.0
	if glow:
		glow.burst(b["top"] + Vector2(0, 40), 30, Color("ffd84a"), 200.0, 1.0, 60.0, 2.6)


func _update_clear(dt: float) -> void:
	for b in bells:
		b["vel"] += -b["swing"] * 18.0 * dt
		b["vel"] *= exp(-dt * 0.9)
		b["swing"] += b["vel"] * dt
		b["sprite"].rotation = b["swing"] * 0.35
	if state != "clear" or not _boon.is_empty():
		return   # (a boss's boon still to choose holds the level's end: _tick_boon)
	clear_time += dt
	if clear_time > 0.4 and player.on_floor and fmod(clear_time, 0.7) < dt:
		player.velocity.y = -300.0
		player.on_floor = false
	if clear_time > 2.6 and clear_time - dt <= 2.6:
		if _has_sfx():
			Sfx.play("clear")
	if clear_time > 3.4 and clear_time - dt <= 3.4:
		if embers_carried > 0:
			_bank()   # (embers taken after the bell: a boss's, gathered to him)
		_log(true)
		finished.emit(result())


func result() -> Dictionary:
	var out := {"level": level_id, "cleared": state == "clear", "embers": embers_got, "embers_total": embers_total,
			"embers_placed": embers_placed,
			"sigils": sigils_got.duplicate(), "time": time, "relics": relics_found.duplicate(),
			"items": items_found.duplicate(), "xp": xp_gained, "levels": levels_gained, "level_start": level_start,
			"level_now": int(Game.hero()["level"]), "snuffs": snuffs, "diff": diff, "dread": _dread_slain(),
			"story_end": level.story.get("end", ""),
			# v3
			"secret": secret_found, "secret_new": secret_new, "candles": features.candles() if features != null else {"lit": 0, "total": 0},
			"lost_wick": int(level.world) if state == "clear" and is_secret_level() else 0,
			"rush_boss": str(boss.get("boss_id")) if _boss_opts.get("rush", false) and boss != null and is_instance_valid(boss) else "",
			"phase_reached": phase_reached, "snuff_sections": snuff_sections.duplicate(true)}
	if mode != null:
		out["mode"] = str(mode.id)
		out.merge(mode.result_extra(), true)
	return out


func is_secret_level() -> bool:
	return level_id.ends_with("-S")


func _dread_slain() -> bool:
	for e in enemies:
		if e.tier == "dread" and e.alive:
			return false
	return level.dread.is_empty() == false


func _log(cleared: bool) -> void:
	if headless:
		return
	var causes := snuff_causes.duplicate()
	for k in ["_last", "_move", "_feature"]:
		causes.erase(k)   # the running "what hurt last", not a snuff
	var line := Playlog.entry(self, cleared, causes)
	if twists != null:
		line.merge(twists.log_extra(), true)   # (the twist, and what it did: for tuning)
	Playlog.write(line)
	var g := _game()
	if g != null and g.get("embers_spent") != null:
		g.set("embers_spent", 0)   # (a line's embers_spent: what was paid since the one before)


# ---------------------------------------------------------------- pickups & drops

func _update_pickups(dt: float) -> void:
	var magnet := Game.equipped("moth_charm")
	for p in pickups:
		if p["taken"]:
			continue
		p["t"] += dt
		p["age"] += dt
		if p.get("full", false):
			p["retry"] = maxf(float(p.get("retry", 0.0)) - dt, 0.0)
			if _owned(p["item"]):
				# Worn from its "Satchel full" card: it leaves the ground.
				p["taken"] = true
				p.erase("full")
				items_found.append(p["item"])
				_mark_boss_first(p)
				if p.has("sprite"):
					p["sprite"].queue_free()
					p.erase("sprite")
				if glow:
					glow.burst(p["pos"], 10, glow.RARITY.get(p["rarity"], Color.WHITE), 110.0, 0.4, -60.0, 2.2)
				continue
		if p.get("pop", false):
			if p["age"] < 0.0:
				continue
			p["vel"].y += 1500.0 * dt
			p["pos"] += p["vel"] * dt
			if p["age"] > 0.34:
				_collect(p)
			continue
		if p.has("rise"):
			# A wax stub rising out of its reliquary.
			p["rise"] += dt
			p["pos"].y -= 40.0 * dt * clampf(1.0 - p["rise"] * 2.0, 0.0, 1.0)
		if p["loose"]:
			p["vel"].y = minf(p["vel"].y + 1100.0 * dt, 500.0)
			var next: Vector2 = p["pos"] + p["vel"] * dt
			var below := Vector2i(floori(next.x / TILE), floori((next.y + 5.0) / TILE))
			var t: int = level.tile(below.x, below.y)
			if p["vel"].y > 0.0 and (LevelData.is_solid(t) or LevelData.is_ledge(t)) and p["pos"].y + 5.0 <= below.y * TILE + 2.0:
				next.y = below.y * TILE - 5.0
				p["vel"].y = -p["vel"].y * 0.35 if absf(p["vel"].y) > 90.0 else 0.0
				p["vel"].x *= 0.6
				if (p["kind"] == "relic" or p["kind"] == "item") and not p.get("landed", false):
					p["landed"] = true
					_sfx("relic_drop")
			var side := Vector2i(floori((next.x + signf(p["vel"].x) * 5.0) / TILE), floori(next.y / TILE))
			if LevelData.is_solid(level.tile(side.x, side.y)):
				p["vel"].x = -p["vel"].x * 0.5
				next.x = p["pos"].x
			p["pos"] = next
			if p["pos"].y > level.height * TILE + 64:
				if p["kind"] == "item" or p["kind"] == "relic":
					# Loot never falls out of the world: it comes back to the hero.
					p["pos"] = player.center() + Vector2(0, -40)
					p["vel"] = Vector2.ZERO
				else:
					p["taken"] = true
			if p["kind"] == "ember" and p["age"] > 9.0:
				p["taken"] = true
		if magnet and (p["kind"] == "ember" or p["kind"] == "item") and p["age"] > 0.25 and not p.get("full", false):
			var d: Vector2 = player.center() - p["pos"]
			if d.length() < 110.0:
				p["loose"] = false
				p["pos"] += d.normalized() * minf(d.length(), 320.0 * dt)
		if p.has("sprite"):
			var s: Sprite2D = p["sprite"]
			if p.get("ghost", false):
				s.modulate.a = 0.4
			s.position = p["pos"] + Vector2(0, sin(p["t"] * 3.0) * 2.5 if not p["loose"] else 0.0)
			if p["kind"] == "sigil":
				s.scale.x = 0.25 * cos(p["t"] * 2.2)
	pickups = pickups.filter(func(p): return not p["taken"] or p.has("sprite"))
	_ember_streak_t = maxf(_ember_streak_t - dt, 0.0)


func _drop_relic(at: Vector2, guaranteed: bool, min_rarity := "common", favor := 0) -> void:
	## A relic not yet found; favor (a world: a gold reliquary's or a boss's
	## own level's) makes that world's relics twice as likely (spec §8.3). In
	## W1-W2 every relic is World 1's, so the roll is v2's exactly.
	var id: String = Game.roll_relic(rng, min_rarity, favor) if favor > 0 else Game.roll_relic(rng, min_rarity)
	if id == "":
		# Everything's found: a Rare item instead (or embers).
		if guaranteed:
			drop_item(at, "gold")
		return
	var r: Dictionary = Relics.get_relic(id)
	var p := {"kind": "relic", "relic": id, "rarity": r["rarity"], "pos": at, "vel": Vector2(randf_range(-40, 40), -360.0),
			"t": 0.0, "taken": false, "loose": true, "age": 0.0}
	var s := _sprite("res://art/relics/%s.svg" % id, 0.25)
	s.position = at
	get_node("Props").add_child(s)
	p["sprite"] = s
	pickups.append(p)
	_sfx("relic_" + r["rarity"])


func _on_enemy_died(e: Node2D, how: String) -> void:
	match e.kind:
		"skeleton":
			_sfx("bones")
		"bat":
			_sfx("bat")
		_:
			_sfx("enemy_hit")
	enemy_killed.emit(e, how)
	var sp = e.get("spawn")
	if sp is Dictionary and int(sp.get("ent", -1)) >= 0 and not _killed.has(int(sp["ent"])):
		_killed.append(int(sp["ent"]))   # (the altar snapshot's)
	# Restless (twists.gd): a stomped one's remains may get up; one that did pays nothing.
	var risen := Twists.is_risen(e)
	if twists != null:
		twists.on_enemy_died(e, how)
	kit.on_kill(e)
	if player.stats.get("legends", {}).has("ossuary_coat"):
		bone_wards = mini(bone_wards + 1, int(_flag("ossuary_max", 3.0)))
	if int(_flag("bone_flute_every", 0.0)) > 0 and e != boss:
		# The Bone Flute: every 8th kill a bone moth strikes the nearest foe
		# for 150% basic.
		_flute_kills += 1
		if _flute_kills % int(_flag("bone_flute_every", 8.0)) == 0:
			var o := nearest_enemy(e.center(), 320.0, func(x): return x != e and x.alive and x.active)
			if o != null:
				if glow:
					glow.burst(o.center(), 12, Color("e8e0d0"), 120.0, 0.4, 0.0, 2.0)
				deal(o, _flag("bone_flute_coef", 1.5), {"how": "moth", "no_hitstop": true})
	var xk: String = e.xp_kind if e.xp_kind != "" else e.kind
	if not risen:
		gain_xp(Progression.kill_xp(xk, e.area, int(Game.hero()["level"]), diff, e.tier, e.respawned), e.center())
	if player.alive:
		var heal := float(player.stats.get("on_kill_heal", 0.0))
		if heal > 0.0:
			player.heal_pct(heal)
	if e == boss:
		# The fight is over the moment he falls: what he threw goes with him
		# (a wave already rolling mustn't snuff the hero after the win), and
		# the door opens, since reset_fight won't run for a dead boss and a
		# snuff before the bell would relight outside a sealed arena.
		hazards = hazards.filter(func(h): return h.get("owner", "enemy") != "enemy")
		shots = shots.filter(func(s): return s.get("owner", "enemy") != "enemy")
		if e.get("door") != null:
			Arena.unseal(self, level, e.door)
		return
	if risen:
		return   # (no embers, no loot: a stomp-and-rise is no farm)
	var at: Vector2 = e.center()
	var lost: bool = how == "pit"
	if lost:
		# Lost in deep water, lava or a pit (a Dripkin that fell): it counts,
		# but its embers go down with it, and any loot comes up to the hero.
		at = player.center() + Vector2(player.facing * 24.0, -30.0)
	if not e.respawned and not lost:
		var n: int = e.embers * (3 if e.tier == "anointed" else (6 if e.tier == "dread" else 1))
		for i in n:
			var p := _add_pickup("ember", at)
			p["loose"] = true
			p["vel"] = Vector2(randf_range(-110, 110), randf_range(-380, -220))
	var chance := kill_item_chance(e)
	# A tiered monster back again (a sealed room's reset brings a put-out
	# Dread or Anointed back at its post, features/sealed.gd) paid its tier's
	# drops the first time: now it rolls as any respawn (half the kill chance).
	var paid: bool = e.respawned and (e.tier == "anointed" or e.tier == "dread")
	if paid:
		if rng.randf() < chance:
			drop_item(at, "kill")
	elif e.tier == "anointed":
		drop_item(at, "anointed")
	elif e.tier == "dread":
		# The first Dread of World 3 drops boots, of World 4 a charm, while
		# the hero has none (Game.gift_slot; "" elsewhere: a random slot).
		var gift := ""
		var gs := _game()
		if gs != null and gs.has_method("gift_slot"):
			gift = str(gs.gift_slot(world_n))
		drop_item(at, "dread", "", gift)
		drop_item(at + Vector2(10, -8), "boss")
	elif e.kind == "lidlurk":
		_lidlurk_prize(at)
	elif rng.randf() < chance:
		drop_item(at, "kill")
	if rng.randf() < e.relic_chance and not e.respawned:
		_drop_relic(at, false)


func kill_item_chance(e: Node2D) -> float:
	## An ordinary kill's chance of an item: its item_chance x the
	## difficulty's (Combat.kill_drop: Dusk's 0.5 in a story level, a mode's
	## Dusk keeps v3's 1.0), halved for a respawned monster, x a mode's
	## loot().drop (the Descent's deeper drops, §10.1).
	var chance: float = e.item_chance * Combat.kill_drop(diff, mode == null) * (0.5 if e.respawned else 1.0)
	if mode != null:
		chance *= float(mode.loot().get("drop", 1.0))
	return chance


func boss_defeated(b: Node2D, at: Vector2) -> void:
	## The boss drops his prize (a first kill on this difficulty: a
	## Legendary, a player's to choose: his boon) and the bell comes down to
	## ring. A rush boss (configured with rush) pays no drops: the seals pay.
	if _boss_opts.get("rush", false) or not allows("loot"):
		shake = 8.0
		_haptic(60)
		freeze(0.25, true)
		if hud and hud.has_method("boss_bar"):
			hud.boss_bar({})
		if _has_sfx():
			Sfx.stop_music(1.0)
		return
	var first: bool = not Game.level_record(level_id).get("boss_first", false)
	if first:
		# The first-kill prize counts as given only once it's taken
		# (_mark_boss_first): a snuff, a quit or a Restart before then
		# leaves it to come again. A player chooses it once his fall has
		# settled (the Boss Boons: _tick_boon, open_boon); with no player
		# to ask (headless, the bot, a golden route) it drops as before.
		if boon_block() == "":
			var who = b.get("boss_name") if b != null else null
			_boon = {"at": at, "who": str(who) if who != null else "", "t": 0.0, "wait": 0.0}
		else:
			_boss_prize(at)
	else:
		drop_item(at, "boss")
	drop_item(at + Vector2(-16, -10), "boss")
	drop_item(at + Vector2(16, -10), "boss")
	_drop_relic(at + Vector2(0, -20), false, "rare", world_n)
	_pay_boss_embers(b, at)
	shake = 8.0
	_haptic(60)
	freeze(0.25, true)
	if hud and hud.has_method("boss_bar"):
		hud.boss_bar({})
	if _has_sfx():
		Sfx.stop_music(1.0)


func _boss_prize(at: Vector2) -> Dictionary:
	## A boss's first-kill prize, dropped where he fell (no player to choose
	## it: open_boon's fallback): one of his world's signature pieces
	## (Items.world_legends: W3-W6's pair, Tollgrave's and the Snuffer's
	## one) in its own slot; a world without one picks as v2 did. Its pickup,
	## marked boss_first.
	var h: Dictionary = Game.hero()
	var slot := _pick_slot()
	var pair: Array = Items.world_legends(world_n).filter(func(id):
		return not (Items.LEGENDS[id] as Dictionary).has("cls") or Items.LEGENDS[id]["cls"] == h["cls"])
	var legend := ""
	if pair.is_empty():
		legend = _pick_legend(slot, h["cls"])
	else:
		legend = _pick_legend(slot, h["cls"], pair)
		slot = str(Items.LEGENDS[legend]["slot"])
	var it := Items.make(slot, h["cls"], area + 2, "legendary" if legend != "" else "rare", rng, legend)
	var p := place_item(it, at, Vector2(0, -380.0))
	p["boss_first"] = true
	return p


func _pay_boss_embers(b: Node2D, at: Vector2) -> void:
	## A boss's embers (b.embers pieces, 30 to 120, each ember_worth()), loose
	## from where he fell, as a kill's are: the kill handler returns for him
	## before its ember loop. Only with his drops (boss_defeated's loot
	## branch): a rush boss is paid by its mode (the Waxworks' embers and
	## seals, the Descent's echo drops) and a feel lab keeps nothing.
	## Still loose when the bell rings (rung at once, or at his feet as the
	## Saint's is), they're gathered to Waxby (_gather_boss_embers).
	var n := int(b.get("embers")) if b != null and b.get("embers") != null else 0
	for i in n:
		var p := _add_pickup("ember", at)
		p["loose"] = true
		p["boss"] = true
		p["vel"] = Vector2(randf_range(-170, 170), randf_range(-480, -240))


func _gather_boss_embers() -> void:
	## The bell rang with a boss's embers still loose (only play picks them
	## up): each pops out of Waxby and is his a moment later, one after
	## another (as the Hush finale gathers his drops). Taken after the bell,
	## they bank with the level's end (_update_clear).
	var k := 0
	for p in pickups:
		if p["taken"] or p["kind"] != "ember" or not p.get("boss", false) or p.get("pop", false):
			continue
		p["pop"] = true
		p["loose"] = false
		p["age"] = -0.012 * k
		p["pos"] = player.center()
		p["vel"] = Vector2(randf_range(-30.0, 30.0), -160.0)
		k += 1


func _lidlurk_prize(at: Vector2) -> void:
	## The Lidlurk guarding a level's hidden vault pays a relic: at least a
	## Blessed while one is left, else any not yet found, and once the codex
	## is full a gold-table item (_drop_relic's fallback, Rare 92 / Legendary
	## 8). A mode's Lidlurk (a Descent room's) keeps the Lidlurk table's item,
	## and a feel lab's pays nothing (it keeps no relic either).
	if mode != null or not allows("loot"):
		drop_item(at, "lidlurk")
		return
	_drop_relic(at, true, "magic")


func boss_phase(b: Node2D, phase: int) -> void:
	## A boss screams into a new phase. A v3 boss barks "<boss_id>_p<n>" when
	## that bark exists; Tollgrave and the Snuffer keep v2's barks whatever
	## story.gd gains (V2_BOSSES). The Snuffer's third is "Lights Out": every
	## brazier dies, and Mother Taper says only Waxby's light is left.
	phase_reached = maxi(phase_reached, phase)
	var bid := str(b.get("boss_id"))
	# A rush boss (the Waxworks, a Descent boss depth) skips every story
	# beat (spec §5.6): no phase bark (BR's request).
	if b.get("rush") == true or _mode_boss_opts(bid).get("rush", false):
		return
	var key := "%s_p%d" % [bid, phase]
	if not V2_BOSSES.has(bid) and _bark_exists(key):
		bark(key)
		return
	if b.get("boss_id") == "tollgrave":
		bark("tollgrave_angry")
	elif phase >= 3:
		bark("snuffer_dark")
	else:
		bark("snuffer_angry")


func _bark_exists(key: String) -> bool:
	if not ResourceLoader.exists(STORY):
		return false
	var barks = (load(STORY) as Script).get_script_constant_map().get("BARKS", {})
	return barks is Dictionary and barks.has(key)


func boss_music() -> String:
	## The fight's track: the level's boss_music, else v2's choice.
	if str(level.boss_music) != "":
		return str(level.boss_music)
	return "boss" if boss.get("boss_id") != "snuffer" else "snuffer"


func _on_boss_woke() -> void:
	var beat: String = level.story.get("boss", "")
	phase_reached = maxi(phase_reached, 1)
	var go := func():
		if _has_sfx():
			var bm := boss_music()
			if Sfx.has_method("play_stems") and ((Sfx.get_script() as Script).get_script_constant_map().get("STEMS", {}) as Dictionary).has(bm):
				# A boss resumed at a checkpoint says its phase's stem levels
				# (BB's stem_levels(): the drums, choir or bells already gone).
				var vols = boss.call("stem_levels") if boss != null and boss.has_method("stem_levels") else {}
				Sfx.play_stems(bm, vols if vols is Dictionary else {})
			else:
				Sfx.play_music(bm)
		if hud and hud.has_method("boss_bar"):
			# He has woken: a v3 boss emits `woke` from inside its wake_check,
			# while its state still reads "sleep" (a retry, a seen beat, a
			# cast), so the bar is told he's awake rather than asking.
			var info: Dictionary = boss.boss_info()
			if boss.alive:
				info["awake"] = true
			hud.boss_bar(info)
	if beat != "" and not Game.seen(beat):
		play_beat(beat, go)
	else:
		# Named once; a retry after that is music and the boss bar only.
		var card := "boss_card_" + str(boss.get("boss_id"))
		if hud and not Game.seen(card):
			hud.title_card(boss.boss_title, boss.boss_name)
			if not is_lab():
				Game.mark_seen(card)
		go.call()


func _spike_sfx() -> void:
	## A thorn bed's hurt: World 3's thorns snag (A7's thorn_snag), else v2's spikes.
	_sfx("thorn_snag" if world_n == 3 else "spikes")   # (Sfx falls back to spikes itself)


func prop_path(key: String) -> String:
	## A World prop's picture: the level theme's own (its "props" map, A1/A2:
	## W3's bone altar and skull lanterns, W4's brass), else v2's
	## art/props/<key>.svg. The themed frames keep v2's sizes and points
	## (tests/test_world_art.gd), so nothing else moves; W1-W2's themes have
	## no map and keep v2's pictures.
	var th := str(level.theme) if level != null else ""
	var name := str((Themes.theme(th).get("props", {}) as Dictionary).get(key, key)) if th != "" and Themes.has_theme(th) else key
	var p := "res://art/props/%s.svg" % name
	return p if ResourceLoader.exists(p) else "res://art/props/%s.svg" % key


func add_bell(floor_pos: Vector2, swing := 0.4, opts := {}) -> Dictionary:
	## The great bell (rung, it clears the level), or with opts.silver a
	## silver bell: half size, its rope 28 x 44, and ringing it clears the
	## level by its secret way out (result.secret, secret_rung).
	var props := get_node("Props")
	var silver: bool = opts.get("silver", false)
	var beam := _sprite(prop_path("bell_beam"), 0.25)
	var bell := _sprite("res://art/props/silver_bell.svg" if silver and ResourceLoader.exists("res://art/props/silver_bell.svg") else prop_path("bell"), 0.25 if not silver else 0.14)
	var top := floor_pos - Vector2(0, 95 if not silver else 60)
	beam.centered = false
	beam.position = top - Vector2(32, 10)
	bell.centered = false
	bell.offset = -Vector2(64, 20) * 2.0
	bell.position = top
	if silver:
		bell.modulate = Color(0.85, 0.9, 1.0)
		beam.visible = false
	props.add_child(beam)
	props.add_child(bell)
	var rope := Rect2(floor_pos.x - 14, floor_pos.y - 70, 28, 70) if not silver else Rect2(floor_pos.x - 14, floor_pos.y - 44, 28, 44)
	var b := {"pos": floor_pos, "top": top, "rope": rope, "sprite": bell, "swing": swing, "vel": 0.0, "rung": false, "silver": silver}
	bells.append(b)
	return b


# ---------------------------------------------------------------- shots & hazards

func _update_shots(dt: float) -> void:
	for s in shots:
		if _stop_t > 0.0 and s["owner"] != "player":
			# Time is stopped: it hangs where it is, and still hurts there.
			if player.alive and state == "play" and player.rect().grow(-2.0).has_point(s["pos"]):
				if hurt_player(float(s["dmg"]), s["pos"].x - signf(s["vel"].x) * 20.0, s["kind"], s.get("source"), {"shot": true, "vel": s["vel"], "pos": s["pos"]}):
					if s["douse"]:
						_douse()
				s["life"] = 0.0
			continue
		s["t"] += dt
		s["life"] -= dt
		if s["homing"] > 0.0 and s["owner"] == "player":
			var tgt := nearest_enemy(s["pos"], 220.0)
			if tgt:
				var want: Vector2 = (tgt.center() - s["pos"]).normalized() * s["vel"].length()
				var ang: float = s["vel"].angle_to(want)
				s["vel"] = s["vel"].rotated(clampf(ang, -s["homing"] * dt, s["homing"] * dt))
		s["vel"].y += s["g"] * dt
		var next: Vector2 = s["pos"] + s["vel"] * dt
		var cell := Vector2i(floori(next.x / TILE), floori(next.y / TILE))
		var t: int = level.tile(cell.x, cell.y)
		if LevelData.is_solid(t):
			if s["owner"] == "player" and s["breaks"] and LevelData.is_breakable(t):
				break_tile(cell)
			if s["bounce"] > 0:
				s["bounce"] -= 1
				var cx := Vector2i(floori(next.x / TILE), floori(s["pos"].y / TILE))
				if LevelData.is_solid(level.tile(cx.x, cx.y)):
					s["vel"].x = -s["vel"].x
				else:
					s["vel"].y = -s["vel"].y * 0.6
				next = s["pos"]
			else:
				s["life"] = 0.0
		s["pos"] = next
		if s["life"] <= 0.0:
			continue
		if features != null:
			features.shot_hit(s)
			if s["life"] <= 0.0:
				continue
		if s["owner"] == "player":
			for e in enemies:
				if not e.alive or not e.active or (s["hit_ids"] as Array).has(e.get_instance_id()):
					continue
				if e.rect().grow(s["radius"]).has_point(s["pos"]):
					s["hit_ids"].append(e.get_instance_id())
					var res := deal(e, float(s["coef"]), {"how": s["how"], "from_x": s["pos"].x - signf(s["vel"].x) * 20.0,
							"backstab": s.get("backstab", false), "extra_pct": float(s.get("extra_pct", 0.0)),
							"no_hitstop": s.get("no_hitstop", false), "special": s.get("special", false),
							"force_crit": s.get("force_crit", false)})
					if s.has("on_hit") and (s["on_hit"] as Callable).is_valid():
						s["on_hit"].call(s, e, res)
					if s.get("twice", false) and res["hit"] and e.alive:
						deal(e, float(s["coef"]) * _flag("escapement_coef", 0.6), {"how": s["how"], "no_hitstop": true})
					if res["hit"] or not s.get("stop_on_block", true):
						if s["pierce"] > 0:
							s["pierce"] -= 1
						else:
							s["life"] = 0.0
					else:
						s["life"] = 0.0
						_sfx("clang")
					break
		else:
			if player.alive and state == "play" and player.rect().grow(-2.0).has_point(s["pos"]):
				# (its flight, for a guard that throws it back along its line)
				if hurt_player(float(s["dmg"]), s["pos"].x - signf(s["vel"].x) * 20.0, s["kind"], null, {"vel": s["vel"], "pos": s["pos"]}):
					if s["douse"]:
						_douse()
				s["life"] = 0.0
			# Hero shots cancel enemy arrows (knives vs arrows).
			for o in shots:
				if o["owner"] == "player" and o.get("cancels", false) and o["pos"].distance_to(s["pos"]) < 10.0:
					s["life"] = 0.0
					o["life"] = 0.0
	for s in shots:
		if s["life"] <= 0.0:
			if s.has("on_end") and (s["on_end"] as Callable).is_valid():
				s["on_end"].call(s)
			if glow and not s.get("quiet", false):
				glow.burst(s["pos"], 6, Color("f7b64a") if s["owner"] == "player" else Color("e8e2d0"), 80.0, 0.25, 0.0, 1.8)
	shots = shots.filter(func(s): return s["life"] > 0.0)


func _update_hazards(dt: float) -> void:
	for h in hazards:
		if _stop_t > 0.0 and h.get("owner", "enemy") != "player":
			continue   # time is stopped: it hangs there (and still hurts: _touch_world)
		if h.get("delay", 0.0) > 0.0:
			h["delay"] -= dt
			continue
		h["life"] -= dt
		if h["kind"] == "beam" or h["kind"] == "pit_band":
			continue   # a beam's segment and a pit band stay where they were put
		var r: Rect2 = h["rect"]
		if h.has("g"):
			h["vel"].y += h["g"] * dt
		r.position += h["vel"] * dt
		var foot := Vector2(r.get_center().x, r.end.y + 2.0)
		var ahead := r.get_center() + Vector2(signf(h["vel"].x) * 10.0, 0)
		match h.get("motion", "floor"):
			"bounce":
				if h["vel"].y > 0.0 and solid_at(foot):
					r.position.y = floorf(foot.y / TILE) * TILE - r.size.y
					h["vel"].y = -maxf(absf(h["vel"].y) * 0.55, 240.0)
				if solid_at(ahead):
					h["vel"].x = -h["vel"].x
			"fall":
				if solid_at(foot) and h["vel"].y > 0.0:
					h["life"] = 0.0
					dust_at(Vector2(r.get_center().x, r.end.y))
			"fly":
				if solid_at(r.get_center()):
					h["life"] = 0.0
			"tide", "still":
				pass
			_:
				if solid_at(ahead) or not _floor_at(foot):
					h["life"] = 0.0
					if glow:
						glow.burst(r.get_center(), 6, Color("c8c8d4"), 90.0, 0.3, 0.0, 2.0)
		h["rect"] = r
		if h["owner"] == "player" and h["life"] > 0.0:
			for e in enemies_in(r):
				if (h["hit_ids"] as Array).has(e.get_instance_id()):
					continue
				h["hit_ids"].append(e.get_instance_id())
				if h.has("flat"):
					deal(e, 1.0, {"how": "wave", "flat": float(h["flat"]), "no_hitstop": true})
				else:
					# special: a Special's wave (the Peal's), which special_pct counts on.
					var wo := {"how": "wave", "no_hitstop": true, "special": h.get("special", false)}
					if h.get("stomp_born", false):
						wo["stomp_born"] = true   # an Aftershock wave: a v3 boss chips it after the window's first stomp
					deal(e, float(h["coef"]), wo)
	hazards = hazards.filter(func(h): return h["life"] > 0.0)


func solid_at(p: Vector2) -> bool:
	return LevelData.is_solid(level.tile(floori(p.x / TILE), floori(p.y / TILE)))


static func seg_hits_rect(a: Vector2, b: Vector2, width: float, r: Rect2) -> bool:
	## Does a segment of this width touch r? (A beam against Wick.)
	var g := r.grow(width * 0.5)
	if g.has_point(a) or g.has_point(b):
		return true
	var c := [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


func _floor_at(p: Vector2) -> bool:
	## Something a floor wave can run on at p: stone, or the top few px of a
	## one-way ledge that's there (a Peal from a ledge runs along it).
	var x := floori(p.x / TILE)
	var y := floori(p.y / TILE)
	var t: int = level.tile(x, y)
	if LevelData.is_solid(t):
		return true
	return LevelData.is_ledge(t) and p.y - y * TILE < 8.0 and ledge_present(x, y)


# ---------------------------------------------------------------- the hero's events

func _on_jumped(double: bool) -> void:
	_sfx("double_jump" if double else "jump")
	if glow and double:
		glow.burst(player.position, 8, Color("c0c8f0"), 90.0, 0.35, 0.0, 2.0)


func _on_landed(impact: float) -> void:
	if impact > 250.0:
		_sfx("land")
		_rubble().dust(player.position, clampi(int(impact / 150.0), 2, 6))
	if impact > 560.0:
		shake = maxf(shake, 1.5)


func _on_attacked() -> void:
	_basics += 1
	if player.stats.get("legends", {}).has("dawnsliver") and _basics % maxi(int(_flag("dawnsliver_every", 3.0)), 1) == 0:
		spawn_shot({"kind": "crescent", "pos": player.center() + Vector2(player.facing * 14.0, -2.0),
				"vel": Vector2(player.facing * 420.0, 0.0), "life": _flag("dawnsliver_range", 190.0) / 420.0,
				"coef": _flag("dawnsliver_coef", 0.6), "pierce": 3, "light": 90.0})
	if player.attack_time >= 0.0:
		_sfx("slash")
		if glow:
			glow.slash(player.center() + Vector2(player.facing * 6.0, -4.0), player.facing, player.reach)
	if Game.equipped("saints_knuckle") and Classes.info(Game.hero()["cls"])["melee"]:
		spawn_shot({"kind": "bolt", "pos": player.center() + Vector2(player.facing * 16.0, -4.0),
				"vel": Vector2(player.facing * 330.0, 0.0), "life": 0.6, "coef": 0.5, "light": 70.0})


func _on_hurt(amount: float, _left: float) -> void:
	_sfx("hurt")
	_haptic(35)
	shake = maxf(shake, 5.0) * float(Game.setting("shake"))
	freeze(0.07, true)
	number(player.center() + Vector2(0, -34), amount, "hurt")
	kit.on_hurt(amount)
	if glow:
		glow.burst(rig.flame_point(), 12, Color("f28a2b"), 120.0, 0.5, 100.0, 2.2)
	if hud:
		hud.bump_flames()
	if not _hurt_barked:
		_hurt_barked = true
		call_deferred("_first_hurt_bark")


func _first_hurt_bark() -> void:
	## Mother Taper's "that flame is your life", on the first hurt. main.gd
	## hooks hurt_taken once for it too; a frame later, if that already
	## played it (a once-only bark, marked heard), there's nothing to say.
	if not is_inside_tree() or Game.seen("bark:first_hurt"):
		return
	bark("first_hurt")


# The lit thumb pad's one-time cards (Game.seen keeps them, once a save):
# id -> [title, words].
const TIPS := {
	"tip:drop": ["Slide your thumb down to drop", "Hold it a moment on a ledge, or slide down and jump"],
	"tip:climb": ["Slide up to climb", "Left thumb up the vine; jump with an arrow held leaps off"],
}


func _thumb_tips() -> void:
	## The thumb's down and up, taught where they first matter: the first time
	## Waxby stands on a ledge he could drop through, and the first time he
	## catches a vine. Only for a player at the glass: never headless, for the
	## bot or a pad a test or a golden route feeds (replayed or recorded), in
	## a mode or the feel lab (it writes nothing).
	if _tips_done or headless or autoplay or test_pad != null or on_pad.is_valid() or mode != null or is_lab() or hud == null:
		return
	var id := "tip:climb" if player.climbing else ("tip:drop" if player.on_ledge() else "")
	if id == "":
		return
	if not Game.seen(id):
		card(id, str(TIPS[id][0]), str(TIPS[id][1]))
		Game.mark_seen(id)
	_tips_done = Game.seen("tip:drop") and Game.seen("tip:climb")


func _on_snuffed() -> void:
	if Game.equipped("phoenix_wick") and not _phoenix_used:
		# Once a level the phoenix wick lights itself again.
		_phoenix_used = true
		player.alive = true
		player.hp = player.max_hp * 0.5
		player.invuln = 2.0
		player.velocity = Vector2(0, -380)
		_sfx("relight")
		if glow:
			glow.burst(rig.flame_point(), 30, Color("ff8a2a"), 220.0, 0.9, -80.0, 3.0)
		if hud:
			hud.toast("Phoenix Wick", "Your flame rekindles!")
		return
	state = "dead"
	snuff_time = 0.0
	snuffs += 1
	var cause: String = snuff_causes.get("_last", "hit")
	snuff_causes[cause] = int(snuff_causes.get(cause, 0)) + 1
	# For tuning on the owner's phone: where (the tile x), what and which move.
	var feat := str(snuff_causes.get("_feature", ""))
	if feat == "" and not _feature_note.is_empty() and ftime - float(_feature_note["t"]) <= FEATURE_BLAME:
		feat = str(_feature_note["name"])
	snuff_sections.append({"x": floori(player.position.x / TILE), "cause": cause,
			"move": str(snuff_causes.get("_move", "")), "feature": feat})
	_mode_after_snuff = str(mode.on_snuffed(self)) if mode != null else ""
	# The Guttered Pool: carried embers stay where he fell (last firm ground
	# after a pit, lava, deep water, the void or the tide). Placed by v2's
	# cause, which a hit set only after it landed: a monster's killing blow
	# soon after a fall leaves the pool at last_safe, as v2 did (W1-W2 play
	# exactly as before). The playlog's cause above is the killing blow's.
	if embers_carried > 0 and allows("pool"):
		var at: Vector2 = player.last_safe if (OWN_SHARE.has(_pool_cause) or OWN_SHARE.has(cause)) else player.position
		pool = {"pos": at + Vector2(0, -6), "embers": embers_carried, "t": 0.0}
		embers_carried = 0
	if Game.unbanked() > 0:
		# The save held them for a trip away from the app: spilt now, they
		# aren't the save's any more (the pool is this level's alone).
		Game.carry_embers(0)
		Game.save()
	_sfx("snuff")
	_haptic(60)
	if _has_sfx():
		Sfx.duck_music(-12.0, 1.6)


func _update_pool(dt: float) -> void:
	if not pool.is_empty():
		pool["t"] += dt


func _reclaim_pool() -> void:
	embers_carried += int(pool["embers"])
	# No ember floater (decisions: none for XP or embers); the toast says it.
	if glow:
		glow.burst(pool["pos"], 12, Color("f7b64a"), 110.0, 0.5, -80.0, 2.2)
	if hud:
		hud.bump_embers()
		hud.toast("Reclaimed", "+%d embers" % int(pool["embers"]))
	_sfx("pool_reclaim")
	pool = {}


func _update_dead(dt: float) -> void:
	if state != "dead":
		return
	snuff_time += dt
	if _mode_after_snuff == "restart":
		# The mode starts over, 0.6 s after the snuff.
		if snuff_time >= 0.6 and snuff_time - dt < 0.6:
			restart.emit()
		return
	if _mode_after_snuff == "end":
		if snuff_time > 1.5 and snuff_time - dt <= 1.5:
			var res := result()
			res["cleared"] = false
			finished.emit(res)
		return
	if snuff_time > 1.5:
		state = "play"
		player.reset_at(checkpoint)
		player.hp = player.max_hp
		player.res = player.res_max if float(Classes.info(Game.hero()["cls"])["res_start"]) >= player.res_max else player.res
		player.invuln = 1.6
		player.hurt_time = 10.0
		player.status.clear()
		flask_charges = flask_max()
		# (_phoenix_used stays spent: the Phoenix Wick rises once a level, not once a life.)
		shots.clear()
		hazards.clear()
		if boss != null and is_instance_valid(boss) and boss.has_method("reset_fight"):
			# The Hush keeps its phase on Dusk (P2 and P3) and Nightfall (P3);
			# a mode never checkpoints.
			var keep := false
			if boss.has_method("checkpoint") and mode == null:
				var ph := int((boss.checkpoint() as Dictionary).get("phase", 1))
				keep = checkpoint_allowed(str(boss.get("boss_id")), ph)
			if keep:
				boss.reset_fight(true)
			else:
				boss.reset_fight()
			if features != null:
				features.on_boss_reset()
			if hud and hud.has_method("boss_bar"):
				hud.boss_bar({})
			if _has_sfx():
				Sfx.play_music(level.music)
		if respawns_here():
			_respawn_monsters()
		kit.on_respawn()
		features.on_respawn()
		if twists != null:
			twists.on_respawn()   # (the remains still lying are at rest)
		if _has_sfx():
			_reset_audio(get_node_or_null("/root/Sfx"), false)
		sync_music()
		if _rites_snuffed >= 0 and _rites_snuffed < altars.size() and altars[_rites_snuffed]["pos"] == checkpoint:
			_altar_rites(altars[_rites_snuffed])   # (the Rites the snuff cut off, at the altar he relights at)
		_rites_snuffed = -1
		cam = cam_on(player.position)
		_cam_y_target = cam.y
		_sfx("relight")
		if glow:
			glow.burst(rig.flame_point(), 18, Color("f7b64a"), 120.0, 0.6, -80.0, 2.4)
		bark("first_snuff")
		if not pool.is_empty():
			bark("first_pool")


func checkpoint_allowed(boss_id: String, phase: int) -> bool:
	## Combat.checkpoint_allowed when it's there; else the ruling (the Hush
	## only): Dusk keeps P2 and P3, Nightfall P3, Witching nothing.
	if _combat_has("checkpoint_allowed"):
		return bool((Combat as Script).call("checkpoint_allowed", diff, boss_id, phase))
	if boss_id != "hush":
		return false
	match diff:
		"dusk":
			return phase >= 2
		"nightfall":
			return phase >= 3
	return false


func respawns_here() -> bool:
	## Do ordinary monsters come back on a snuff here? Nightfall and deeper,
	## and Dusk in a story level from World 3 (Combat.respawns). HK.relit
	## asks it too, so a Hushling pack comes back with them.
	return Combat.respawns(diff, _teeth_world())


func _teeth_world() -> int:
	## The world Combat's Dusk-from-World-3 rules see: world_n in a story
	## level (a secret one too), 0 in a mode (its room's biome isn't the
	## story's) or a feel lab, which keep the difficulty's row.
	return world_n if mode == null and not is_lab() else 0


func _respawn_monsters() -> void:
	## Nightfall and deeper, and Dusk from World 3 (respawns_here): ordinary
	## monsters come back (less reward).
	for sp in spawns:
		var alive_here := false
		for e in enemies:
			if e.spawn.get("cell", Vector2i(-9, -9)) == sp["cell"] and e.alive:
				alive_here = true
				break
		if not alive_here:
			spawn_enemy(sp["kind"], EnemyKinds.spawn_pos(sp["kind"], sp["cell"]), {"cell": sp["cell"], "respawned": true})


# ---------------------------------------------------------------- camera & lights

func _clamp_cam(c: Vector2) -> Vector2:
	var v := _view_size()
	var size: Vector2 = level.pixel_size()
	var out := c
	out.x = size.x * 0.5 if size.x <= v.x else clampf(c.x, v.x * 0.5, size.x - v.x * 0.5)
	# Below the level there's more stone to see (TileView draws it), so the
	# floor can sit above the thumbs.
	var bottom := size.y + BELOW
	out.y = bottom * 0.5 if bottom <= v.y else clampf(c.y, v.y * 0.5, bottom - v.y * 0.5)
	return out


func feet_line() -> float:
	## The view y where the camera holds a standing hero's feet: FEET_CLEAR
	## over the thumb buttons that reach highest, the Special (with its
	## resource arc) and the flask, so nothing on his floor is behind one.
	## It follows the button-size setting and the safe area (with no touch
	## controls yet, or none at all headless, the buttons they would draw).
	var vs := _view_size()
	var L: Dictionary
	if touch != null and touch.is_inside_tree() and touch.has_method("layout"):
		L = touch.layout()
	else:
		var k := clampf(float(Game.setting("button_scale")), 0.85, 1.1)
		L = TouchScript.layout_for(UI.safe_rect(get_viewport()) if is_inside_tree() else Rect2(Vector2.ZERO, vs), k)
	var top: float = minf(float(L["special"].y) - float(L["r_special"]), float(L["flask"].y) - float(L["r_flask"]))
	return clampf(top - FEET_CLEAR, vs.y * 0.4, vs.y - 60.0)


func in_plain_view(r: Rect2) -> bool:
	## A world rect wholly on the glass and out from behind what's drawn over
	## the level: the thumb buttons and the HUD's corner blocks. A shooter
	## (elites.gd in_view) wakes and looses only like this, so nothing shoots
	## from behind a thumb, the Special or the life bar. Headless, nothing
	## is drawn over the level.
	var view := view_rect()
	if not view.encloses(r):
		return false
	if _ui_cover.is_empty():
		_ui_cover = _ui_shapes()
	var vr := Rect2(r.position - view.position, r.size)
	for c in _ui_cover["circles"]:
		var p: Vector2 = c[0]
		var near := Vector2(clampf(p.x, vr.position.x, vr.end.x), clampf(p.y, vr.position.y, vr.end.y))
		if near.distance_to(p) < float(c[1]):
			return false
	for q in _ui_cover["rects"]:
		if vr.intersects(q):
			return false
	return true


func _ui_shapes() -> Dictionary:
	## What covers the level (view px): the touch buttons as discs (the
	## Special with its resource arc) and the HUD's fixed corner rects.
	var out := {"circles": [], "rects": []}
	if touch != null and touch.is_inside_tree() and touch.has_method("layout"):
		var L: Dictionary = touch.layout()
		for b in ["left", "right", "attack", "jump", "special", "flask", "pause"]:
			var rad := float(L["r_" + ("move" if b in ["left", "right"] else b)])
			out["circles"].append([L[b], rad + (6.0 if b == "special" else 2.0)])
	if hud != null and hud.is_inside_tree() and hud.has_method("layout"):
		var H: Dictionary = hud.layout()
		for k in ["badge", "life", "res", "embers", "sigils"]:
			if H.get(k) is Rect2:
				out["rects"].append(H[k])
	return out


func knock_brake(pl: Node2D, away: float) -> float:
	## How far sideways a contact knock `away` (+1 / -1) may carry him
	## (player.gd asks), as its speed: -1 as ever; standing with the floor
	## behind him ending over a pit within KNOCK_REACH, a speed that stops
	## him short of that edge (0 at it: straight up); -2 airborne over a pit
	## (he keeps his own drift).
	if world_n < KNOCK_BRAKE_FROM or level == null or pl == null:
		return -1.0
	if not pl.on_floor:
		return -2.0 if _over_pit_at(pl.position.x, pl.position.y) else -1.0
	var dx := 0.0
	while dx <= KNOCK_REACH:
		var x: float = pl.position.x + away * dx
		if _floor_near(x, pl.position.y) == false:
			if not _over_pit_at(x, pl.position.y):
				return -1.0
			# The edge is dx - 8 .. dx away: stop his feet KNOCK_EDGE short of it
			# over the knock's arc (about KNOCK_AIR s aloft).
			var room := maxf(dx - 8.0 - KNOCK_EDGE, 0.0)
			return minf(room / KNOCK_AIR, 210.0)
		dx += 8.0
	return -1.0


func _floor_near(x: float, feet: float) -> bool:
	## Floor (stone, glass, a ledge, a mover) under x within 4 rows of feet.
	var cx := floori(x / TILE)
	var cy := floori((feet + 2.0) / TILE)
	for y in range(cy, mini(cy + 4, level.height)):
		var t: int = level.tile(cx, y)
		if LevelData.is_solid(t) or LevelData.is_ledge(t):
			return true
	for m in movers:
		if m.present:
			var mr: Rect2 = m.rect()
			if x >= mr.position.x and x <= mr.end.x and mr.position.y >= feet - 4.0 and mr.position.y <= feet + 4.0 * TILE:
				return true
	return false


func _over_pit_at(x: float, feet: float) -> bool:
	## The column under x from feet down: a pit, the void or deep water (or
	## lava, or spikes) before any floor.
	var cx := floori(x / TILE)
	for y in range(maxi(floori(feet / TILE), 0), level.height):
		var t: int = level.tile(cx, y)
		if t == LevelData.LAVA or t == LevelData.SPIKES_UP:
			return true
		if t == LevelData.WATER:
			return level.is_deep(cx, y)
		if LevelData.is_solid(t) or LevelData.is_ledge(t):
			return false
	for m in movers:
		if m.present:
			var mr: Rect2 = m.rect()
			if x >= mr.position.x and x <= mr.end.x and mr.position.y >= feet - 4.0:
				return false
	return true


func look_up() -> float:
	## How much lower than feet_line the camera puts a standing hero's feet
	## (0..LOOK_UP_MAX) to show what hangs over him in the view's width and
	## would be over its top edge: a drip spout's nozzle with its glint, a
	## Dripkin still hanging, a Bonebow up on a ledge, a Flit's roost with
	## its bob and the rise of its wind-up (bat.gd reach_rect), a Gutterwing
	## nest. One too high to show whole even so still gets the full lean if
	## that shows some of it (never less of it than the old line showed);
	## one that wouldn't show at all gets none. Either way their own rules
	## keep them fair: a Bonebow looses, a Flit winds up and a nest breeds
	## only in plain view.
	var v := _view_size()
	var x0 := cam.x - v.x * 0.5
	var x1 := cam.x + v.x * 0.5
	var feet: float = player.position.y
	var line: float = _feet_y if _feet_y >= 0.0 else feet_line()
	var need := 0.0
	if features != null:
		for sp in features.spouts:
			var tip: Vector2 = sp["tip"]
			if tip.x > x0 and tip.x < x1 and tip.y < feet:
				need = _lean(need, feet - tip.y + 16.0, line, 16.0)
		for n in features.nests:
			var nr: Rect2 = features.nest_rect(n)
			if nr.end.x > x0 and nr.position.x < x1 and nr.end.y < feet:
				need = _lean(need, feet - nr.position.y + 3.0, line, nr.size.y)
		# World 4's icicles still hanging (or about to drop) over him: seen
		# whole, with their 0.45 s crack, as a Dripkin is (WL4's request).
		var cw: Object = features.module("clockwork") if world_n == 4 and features.has_method("module") else null
		if cw != null:
			for ic in cw.get("icicles"):
				var st := str(ic["state"])
				var hang: Vector2 = ic["hang"]
				if (st == "hang" or st == "tell" or st == "grow") and hang.x > x0 and hang.x < x1 and hang.y < feet:
					need = _lean(need, feet - hang.y + 4.0, line, 30.0)
	for e in enemies:
		if not e.alive or e.gone:
			continue
		if e == boss and e.has_method("camera_top"):
			# A boss that says how high it rises (the Saint hovering over her
			# nave, BB's request): its top in view while it's awake.
			var top: float = e.camera_top()
			if top < feet:
				# (the full lean whenever it shows more of her: her line is her
				# halo plus the HUD's row, so even the most is worth having)
				need = _lean(need, feet - top + 8.0, line, 400.0)
			continue
		var r := Rect2()
		var pad := 8.0
		if (e.kind == "dripkin" and e.has_method("hanging") and e.hanging()) or e.kind == "bonebow":
			r = e.rect()
		elif e.kind == "bat" and e.has_method("reach_rect"):
			# Only one near enough to swoop soon: the camera has settled by
			# the time he's in its range (half a second's run).
			r = e.reach_rect()
			pad = 3.0
			if absf(r.get_center().x - player.position.x) > e.SWOOP_RANGE + e.SWAY + 130.0:
				continue
		else:
			continue
		if r.end.x > x0 and r.position.x < x1 and r.end.y < feet:
			need = _lean(need, feet - r.position.y + pad, line, r.size.y)
	return need


func _arena_lean(tx: float, v: Vector2) -> float:
	## A v3 boss awake in his arena, with Waxby between its walls: the camera
	## leans his way (so his face is on the glass: its x plus ARENA_FACE),
	## as far as it can while Waxby stays ARENA_EDGE px inside the view's safe
	## edge. Gravebough stands in her right wall, past a camera that follows
	## a hero at the door (the int2 review: an empty arena after her scene,
	## her first sweep from off the glass). v2's bosses: never.
	if boss == null or not is_instance_valid(boss) or not boss.alive or not _in_v3_arena(boss) or str(boss.get("state")) in ["sleep", "dead"]:
		return tx
	var face: float = boss.center().x
	var eyes: Array = boss.eye_points() if boss.has_method("eye_points") else []
	if not eyes.is_empty():
		face = 0.0
		for p in eyes:
			face += (p as Vector2).x / eyes.size()
	var hx: float = player.position.x
	var safe: Rect2 = UI.safe_rect(get_viewport()) if is_inside_tree() else Rect2(Vector2.ZERO, v)
	if face >= hx:
		var want := face + ARENA_FACE - v.x * 0.5
		var most := hx + v.x * 0.5 - safe.position.x - ARENA_EDGE
		return maxf(tx, minf(want, most)) if want > tx else tx
	var want2 := face - ARENA_FACE + v.x * 0.5
	var least := hx - (safe.end.x - ARENA_EDGE) + v.x * 0.5
	return minf(tx, maxf(want2, least)) if want2 < tx else tx


static func _lean(need: float, above: float, line: float, tall: float) -> float:
	## A thing `above` px over his feet (its top) and `tall` px tall: how far
	## the feet must come down from line to show it, up to LOOK_UP_MAX; the
	## most, if even that shows only some of it; none, if it wouldn't show.
	var more := above - line
	if more <= 0.0:
		return need
	if more <= LOOK_UP_MAX:
		return maxf(need, more)
	return maxf(need, LOOK_UP_MAX) if more - LOOK_UP_MAX < tall else need


func hero_view_rect() -> Rect2:
	## Waxby as drawn, in view px: his width, from his feet up to the tip of
	## his flame (the HUD lets what he's behind in the top band go
	## see-through).
	var f: Vector2 = player.position - cam + _view_size() * 0.5
	return Rect2(f.x - HERO_HALF, f.y - HERO_TALL, HERO_HALF * 2.0, HERO_TALL)


func head_top() -> float:
	## The view y his feet may rise to in the air before the camera goes up
	## with him: FEET_TOP, or lower down the glass where he's under one of
	## the HUD's corner blocks or the pause button (at a level's start and
	## end, where the camera stops at the edge), so the tip of his flame
	## stays FEET_CLEAR under it. His width is taken a little wider the
	## faster he runs, so the stop is in place as he comes under a block.
	if _ui_cover.is_empty():
		_ui_cover = _ui_shapes()
	var v := _view_size()
	var hx: float = hero_view_rect().get_center().x
	var half: float = HERO_HALF + absf(player.velocity.x) * 0.1
	var top := FEET_TOP
	for q in _ui_cover["rects"]:
		if q.end.y < v.y * 0.5 and hx + half > q.position.x and hx - half < q.end.x:
			top = maxf(top, q.end.y + FEET_CLEAR + HERO_TALL)
	for c in _ui_cover["circles"]:
		var p: Vector2 = c[0]
		if p.y < v.y * 0.3 and absf(hx - p.x) < float(c[1]) + half:
			top = maxf(top, p.y + float(c[1]) + FEET_CLEAR + HERO_TALL)
	return top


func cam_on(feet: Vector2) -> Vector2:
	## The camera centre that holds a hero standing at feet on feet_line().
	_feet_y = feet_line()
	return _clamp_cam(feet + Vector2(0.0, _view_size().y * 0.5 - _feet_y))


func _update_camera(dt: float) -> void:
	var v := _view_size()
	_feet_t -= dt
	if _feet_y < 0.0 or _feet_t <= 0.0:
		# The buttons can change size (Settings) and the view its shape.
		_feet_y = feet_line()
		_ui_cover = {}
		_feet_t = 0.5
	var moving: bool = absf(player.velocity.x) > 40.0
	_look = lerpf(_look, (player.facing * 70.0) if moving else _look * 0.98, 1.0 - exp(-dt * 2.2))
	var tx: float = player.position.x + _look
	var target_x: float = _clamp_cam(Vector2(_arena_lean(tx, v), cam.y)).x
	cam.x = lerpf(cam.x, target_x, 1.0 - exp(-dt * 7.0))
	# Vertically: settle so his feet are on feet_line (over the thumbs); in
	# the air follow him only once he leaves the band from head_top (FEET_TOP,
	# or lower under a HUD block) down to 70 px under that line. On the
	# floor the stop is where it would be; in the air it eases down the
	# glass (HEAD_EASE) when he comes under a block, so the camera never
	# jumps.
	var head: float = head_top()
	var settled: bool = player.on_floor or player.climbing   # on a vine the camera settles as on the floor
	_head_y = head if (settled or head < _head_y) else move_toward(_head_y, head, HEAD_EASE * dt)
	var feet_at: float = player.position.y + v.y * 0.5   # his feet's view y is feet_at - cam.y
	var py: float = feet_at - (_feet_y + look_up())
	var feet_view: float = feet_at - cam.y
	if settled or state != "play":
		_cam_y_target = py
	else:
		var low := _feet_y + v.y * 0.18
		if feet_view < _head_y:
			_cam_y_target = feet_at - _head_y
		elif feet_view > low:
			_cam_y_target = feet_at - low
	var target_y: float = _clamp_cam(Vector2(cam.x, _cam_y_target)).y
	cam.y = lerpf(cam.y, target_y, 1.0 - exp(-dt * (9.0 if player.velocity.y > 400.0 else 4.5)))
	if state == "play" and player.alive:
		# The easing never lags his flame off the top or under a HUD block:
		# over the stop the camera goes up with him.
		cam.y = _clamp_cam(Vector2(cam.x, minf(cam.y, feet_at - _head_y))).y
	shake = maxf(shake - dt * 18.0, 0.0)
	var amt := shake * float(Game.setting("shake"))
	var jolt := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amt if amt > 0.0 else Vector2.ZERO
	camera.position = (cam + jolt).round()


func _process(dt: float) -> void:
	if level == null:
		return
	for cell in blocks:
		var b: Dictionary = blocks[cell]
		if b["bump"] > 0.0:
			b["bump"] = maxf(b["bump"] - dt * 7.0, 0.0)
			b["sprite"].position.y = cell.y * TILE - sin(b["bump"] * PI) * 8.0
	for a in altars:
		a["glow"] = maxf(a["glow"] - dt * 0.8, 0.0)
	if backdrop:
		backdrop.follow(view_rect().position)
	var under: Node2D = get_node_or_null("Under")
	if under:
		under.queue_redraw()
	_low_life(dt)
	_update_lights()


func _low_life(dt: float) -> void:
	## Under a quarter of life: a heartbeat, a small buzz, muffled music.
	var low: bool = state == "play" and player.alive and player.life_frac() < 0.25
	if low:
		_heart_t -= dt
		if _heart_t <= 0.0:
			_heart_t = 1.1
			_sfx("heartbeat")
			_haptic(8)
	if low != _lowpass_on and _has_sfx() and Sfx.has_method("set_lowpass"):
		_lowpass_on = low
		Sfx.set_lowpass(low)


func _update_lights() -> void:
	## Packed by priority: the hero, tells, shots, beacons and braziers,
	## altars and lanterns, eyes, pickups and the pool, then sconces, glass
	## and lava with what's left. world_lights.gd (W0-render) packs instead
	## when it's there (the v3 priority table, tints, Hush lights).
	if lights != null and lights.has_method("pack"):
		lights.pack(view_rect())
		return
	var xf := get_viewport().get_canvas_transform()
	var view := view_rect().grow(120.0)
	var packed := PackedVector4Array()
	var k := xf.get_scale().x
	var flick := 1.0 + 0.03 * sin(_t * 13.0) + 0.02 * sin(_t * 23.0)
	var add := func(p: Vector2, r: float, s: float) -> void:
		if packed.size() < MAX_LIGHTS and view.has_point(p) and s > 0.0:
			var at: Vector2 = xf * p
			packed.append(Vector4(at.x, at.y, r * k, s))
	if player.alive:
		var r := hero_light_radius()
		if player.hurt_time < 0.3:
			r *= 0.6 + player.hurt_time * 1.3
		if player.life_frac() < 0.25:
			r *= 0.9 + 0.1 * sin(_t * TAU)
		add.call(player.center() + Vector2(0, -8), r * flick, 1.0)
	elif state == "dead":
		add.call(player.center(), 60.0 * maxf(0.0, 1.0 - snuff_time), 0.8)
	for e in enemies:
		if e.alive and e.active:
			for l in e.lights():
				add.call(l["p"], l["r"], l["s"])
	var nshots := 0
	for s in shots:
		if s["light"] > 0.0 and nshots < 4:
			add.call(s["pos"], s["light"], 0.8)
			nshots += 1
	for l in kit.lights():
		if not l.get("hero", false):
			add.call(l["p"], l["r"], l.get("s", 0.8))
	for id in _dyn_lights:
		var l: Dictionary = _dyn_lights[id]
		add.call(l["p"], l["r"], l["s"])
	for l in features.lights():
		add.call(l["p"], l["r"], l.get("s", 0.8))
	if mode != null:
		for l in mode.lights():
			add.call(l["p"], l["r"], l.get("s", 0.8))
	for a in altars:
		if a["lit"]:
			add.call(a["flame"], (150.0 + a["glow"] * 60.0) * flick, 0.95)
	if boss != null and is_instance_valid(boss) and boss.get("state") != "sleep":
		var flare := 1.0
		if boss.get("state") == "windup":
			flare = 1.5 + 0.3 * sin(_t * 30.0)
		add.call(boss.center() + Vector2(0, -20), 130.0 * flare, 0.7 if boss.alive else 0.4)
	var neyes := 0
	for e in enemies:
		if neyes >= 8:
			break
		if e.alive and e.active and e != boss:
			for p in e.eye_points():
				if view.has_point(p):
					add.call(p, 16.0, 0.35)
					neyes += 1
	for b in bells:
		add.call(b["top"] + Vector2(0, 50), 90.0, 0.5)
	if not pool.is_empty():
		add.call(pool["pos"], 60.0, 0.7)
	var npick := 0
	for p in pickups:
		if npick >= 6:
			break
		if p["taken"]:
			continue
		match p["kind"]:
			"ember":
				add.call(p["pos"], 34.0, 0.55)
			"relic", "item":
				add.call(p["pos"], 90.0, 0.9)
			"sigil":
				add.call(p["pos"], 60.0, 0.7)
		npick += 1
	for s in sconces:
		add.call(s, 110.0 * (1.0 + 0.04 * sin(_t * 11.0 + s.x)), 0.85)
	# The stained glass glows a little, and lights what's in front of it.
	if backdrop:
		var cam0 := view_rect().position
		var nwin := 0
		for wnd in backdrop.windows:
			if nwin >= 6 or packed.size() >= MAX_LIGHTS - 4:
				break
			var off: Vector2 = backdrop.layer_offset(wnd["layer"], cam0)
			var wc: Vector2 = (wnd["center"] if wnd["rose"] else (wnd["rect"] as Rect2).get_center()) + off
			if not view.has_point(wc):
				continue
			add.call(wc, (wnd["radius"] * 1.5 if wnd["rose"] else 70.0), 0.42)
			nwin += 1
	# Lava glows along its surface.
	var x0 := maxi(floori(view.position.x / TILE), 0)
	var x1 := mini(floori(view.end.x / TILE), level.width - 1)
	var y0 := maxi(floori(view.position.y / TILE), 0)
	var y1 := mini(floori(view.end.y / TILE), level.height - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1, 2):
			if packed.size() >= MAX_LIGHTS:
				break
			if level.tile(x, y) == LevelData.LAVA and level.tile(x, y - 1) != LevelData.LAVA:
				add.call(Vector2(x * TILE + 16, y * TILE + 10), 85.0 * (1.0 + 0.06 * sin(_t * 3.0 + x)), 0.75)
	var n := packed.size()
	while packed.size() < MAX_LIGHTS:
		packed.append(Vector4.ZERO)
	_dark_mat.set_shader_parameter("lights", packed)
	_dark_mat.set_shader_parameter("light_count", n)
	_dark_mat.set_shader_parameter("view_size", _view_size())


# ---------------------------------------------------------------- pause, sound, haptics

func _notification(what: int) -> void:
	# Leaving the app (a call, the home swipe) pauses the level.
	if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		if not headless:
			open_pause()
			backgrounded()


func backgrounded() -> void:
	## The app sent away mid-level: iOS may end it there. The save gets the
	## embers carried since the last altar as "unbanked" (they aren't banked:
	## back in the level they're still carried, and a snuff still spills
	## them), so if the app never comes back, the next load puts them in the
	## purse, as leaving the level through the pause menu would have.
	if is_lab():
		return   # a feel lab writes nothing to the save (decisions.md), not even the slot's time
	Game.carry_embers(embers_carried if state != "dead" else 0)
	Game.save()


func _exit_tree() -> void:
	if not headless:
		# Leaving banks what was carried; only a death spills it.
		_bank()
		# Left through the game (Leave, Restart, the bell): no altar to come
		# back to. (An app kill never gets here: its snapshot stays.)
		_drop_suspend()
		if state != "clear":
			_log(false)
		if not is_lab():
			Game.save()   # a feel lab writes nothing (its playlog entry above is kept)
		# Quitting or restarting under a quarter of life mustn't leave the
		# music muffled on the map and through the next level.
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null and sfx.has_method("set_lowpass"):
			sfx.set_lowpass(false)
		_lowpass_on = false
		# Nor a Hush zone's hush, a stopped tape (the Tinker) or the level's
		# ambience bed into the results and the map (A7's engine).
		_reset_audio(sfx, true)


func _reset_audio(sfx: Node, leaving: bool) -> void:
	## The v3 audio states a level may leave behind: the hush, a tape stop,
	## and (leaving) the ambience bed. Safe on v2's Sfx (each behind has_method).
	if sfx == null:
		return
	if sfx.has_method("set_hush"):
		sfx.set_hush(0.0)
	if sfx.has_method("tape_stopped") and sfx.has_method("tape_go") and bool(sfx.tape_stopped()):
		sfx.tape_go(0.0)
	if leaving and sfx.has_method("stop_ambience"):
		sfx.stop_ambience()


func open_pause() -> void:
	if state != "play" or paused:
		return
	paused = true
	if pause_menu:
		pause_menu.open()
	if _has_sfx():
		Sfx.play("pause")


func close_pause() -> void:
	paused = false
	sync_music()


const TICK_LOCKED_MUSIC := ["carillon"]   # the tracks rendered on the W4 tick (A6)


func sync_music() -> void:
	## A ticking level (a tick: header, W4) realigns its music to the feature
	## clock: at the start, after a pause or a choice card (offer_choice) and
	## after a snuff, but only a tick-locked track (the carillon; the
	## Tinker's and the secret track aren't on the tick, so they never jump).
	## Cosmetic only: gameplay never waits on audio.
	if _has_sfx() and (level.headers.has("tick") or world_n == 4) and Sfx.has_method("seek_music") \
			and Sfx.has_method("music_playing") and TICK_LOCKED_MUSIC.has(str(Sfx.music_playing())):
		Sfx.seek_music(ftime)


func _has_sfx() -> bool:
	return not headless and is_inside_tree() and get_node_or_null("/root/Sfx") != null


func _sfx(name: String, pitch := 1.0, _jitter := 0.0, gain := 1.0) -> void:
	## A sound at a pitch; gain (0..1) for distance falloff (A7's play).
	if _has_sfx():
		Sfx.play(name, pitch, gain)


func _tell_sfx(name: String, seconds: float, gain := 1.0) -> void:
	## A tell's sound fitted to its real length (Sfx.tell trims a tell that
	## builds so its peak lands as the threat does), for the feature modules.
	if _has_sfx():
		if Sfx.has_method("tell"):
			Sfx.tell(name, seconds, gain)
		else:
			Sfx.play(name, 1.0, gain)


func _haptic(ms: int) -> void:
	if headless or not Game.haptics:
		return
	Input.vibrate_handheld(ms, clampf(ms / 60.0, 0.2, 1.0))
