extends "res://scripts/enemy.gd"
## What every monster shares on top of enemy.gd: the elite tiers and the
## Omens, their look in the glow layer, and the small helpers every kind uses
## for fair tells (tell(), cd(), spd()), line of sight and sounds. Rattle,
## Flit, Thornback, the World 2 monsters and every v3 kind extend this.
##
## The static half picks the Anointed for a level (pick_elites), called by
## level_features.assign_elites(): deterministic for a seed, never in 1-1,
## only on safe ground (5 flat tiles each side, no pit, lava or deep water
## within 4, not within 12 tiles of an altar or the start, 20 tiles apart).
##
## Omen effects (spec §5 and §4.6, decisions):
##   Swift      +40% speed, cooldowns x0.75; tells x0.75 only off Dusk (floor
##              0.30 s): on Dusk its tells stay x1.0; 3 afterimages
##   Warded     3 orbiting candle motes (lights); each blocks one hit and regrows
##              after 4 s; a stomp breaks all three (and still lands)
##   Burning    a fire patch every 0.6 s (32x8, 2 s, 30% of its touch); fliers drop cinders
##   Twinned    dies into 2 copies at 0.6 scale and 25% of its life, with no Omens
##   Vengeful   a successful hit on it fires 4 shards in an X (160 px/s, 0.8 s, 40%)
##   v3 (P1, one a world):
##   Sporebound (W3) its death bursts into a spore cloud (features.add_spores, r 56,
##              4 s); green motes drift up from it and its eyes glow green
##   Echoing    (W4) each of its strikes repeats ECHO_DELAY later at the same place
##              at 60% (strike_logged); a clock-hand ring ticks round its feet and
##              the echo's box is outlined from the strike until it fires. A kind
##              that strikes only with its body leaves a pale echo of its body
##              ECHO_DELAY behind it instead (60% of its touch)
##   Glassed    (W5) a glass shell worth 30% of its life: no flinch, basic shots
##              deal 50%, heavy hits x2 to it; breaking it stuns 1.0 s
##   Hushed     (W6) silent, eyes dark, seen only in light; an aura (r 120) dims
##              Wick x0.7 (world.dim); a violet rim
## Pools by world (roll_omens): W1-2 (and world 0: labs, tests) v2's five, never
## Vengeful on Dusk; W3 + Sporebound; W4 + Sporebound, and Echoing from
## Nightfall; W5 + Echoing and Glassed; W6 all nine (Vengeful on Dusk too).
## Never more than 3 Omens.
##
## The statuses v3 adds here: "alerted" (a Hoarowl's alarm: speed x1.3 for 4 s,
## and a sleeping monster wakes; a tiny white "!").
##
## Build 2: behave_diff() (by_behave, hush_kind's behave_of): an Anointed or
## a Dread on Dusk in a story level from World 3 fights with its Nightfall
## moves, its life, damage and tells still Dusk's. And a level's anoint:
## header names monsters Anointed every run, in any level (anoint_specs):
##   anoint: x,y[:Omen+Omen[:Name]]; x,y ...
## each cell a placed monster's; its Omens checked against omen_pool (the
## ones that don't fit dropped; none left, they're rolled as the World's
## would be) and topped up to the difficulty's least; the name shows on its
## plate (hud.gd elite_seen). level_features.assign_elites anoints them
## before pick_elites, outside its max, and the random picks keep 20 tiles
## from them.
##
## Stand-in drawing (until a kind's frames exist): the v2 kinds keep the
## o_circle / o_poly helpers; v3 kinds draw with cel_* into one TriBatch per
## draw (contract §1: no draw_circle / draw_colored_polygon / draw_polyline
## in new code), flushed once.

const ELITE_TB := preload("res://scripts/tri_batch.gd")   # (not "TriBatch": a kind may preload its own under that name)
const OMENS := ["Swift", "Warded", "Burning", "Twinned", "Vengeful", "Sporebound", "Echoing", "Glassed", "Hushed"]
const V3_OMENS := ["Sporebound", "Echoing", "Glassed", "Hushed"]
# The v3 Omens each world adds to v2's five (spec §4.6); an Omen listed in
# DUSK_WAITS[world] joins only from Nightfall. Worlds 0-2 add none.
const WORLD_OMENS := {3: ["Sporebound"], 4: ["Sporebound", "Echoing"], 5: ["Sporebound", "Echoing", "Glassed"],
		6: ["Sporebound", "Echoing", "Glassed", "Hushed"]}
const DUSK_WAITS := {4: ["Echoing"]}
const DUSK_VENGEFUL_FROM := 6   # Vengeful joins Dusk's pool only in W6 ("all nine")
const MAX_OMENS := 3
# The tiers behave_diff() lends Nightfall's moves on Dusk from World 3 (not
# "warden": the secret levels' Wardens keep theirs).
const BEHAVE_TIERS := ["anointed", "dread"]
const NEVER_ON := {"Swift": ["lidlurk", "hoarowl"], "Burning": ["brinejaw", "weepcap"], "Twinned": ["creepbone", "unwick"],
		"Vengeful": ["hushling"], "Sporebound": ["weepcap"], "Echoing": ["unwick", "hoarowl"],
		"Glassed": ["frostbuckle", "paneguard"], "Hushed": ["stillmaw", "hushling", "unwick"]}
# Who may be Anointed (never Spurwheel or Lurecoil; a Dread or Warden may be any kind).
const ELIGIBLE := ["skeleton", "bat", "thornback", "bonebow", "hollow_helm",
		"rootling", "weepcap", "rattlehound", "creepbone", "tickwind", "frostbuckle", "hoarowl",
		"glassmite", "gustling", "refractor", "paneguard", "hushling", "stillmaw", "unwick"]
const NAMES := {"skeleton": "Rattle", "bat": "Flit", "thornback": "Thornback", "bonebow": "Bonebow",
		"hollow_helm": "Hollow Helm", "gutterwing": "Gutterwing", "dripkin": "Dripkin", "brinejaw": "Brinejaw",
		"lidlurk": "Lidlurk",
		"rootling": "Rootling", "weepcap": "Weepcap", "rattlehound": "Rattlehound", "creepbone": "Creepbone",
		"tickwind": "Tickwind", "spurwheel": "Spurwheel", "frostbuckle": "Frostbuckle", "hoarowl": "Hoarowl",
		"glassmite": "Glassmite", "gustling": "Gustling", "refractor": "Refractor", "paneguard": "Paneguard",
		"hushling": "Hushling", "stillmaw": "Stillmaw", "unwick": "Unwick", "lurecoil": "Lurecoil"}
const TELL_FLOOR := 0.30
# v3 (contract §6.2): the damage trim by the level's world (bosses skip it;
# enemy.gd's setup_stats reads it). W1-W4 1.0, so W1-W2 are unchanged.
const DMG_WORLD_TRIM := {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.9, 6: 0.8}
const ANOINTED_COL := Color("6aa0ff")
const DREAD_COL := Color("ffd84a")
const WARDEN_COL := Color("dfe4ff")
const OUTLINE := Color("1c1830")
const NOWHERE := Rect2(-1.0e6, -1.0e6, 1.0, 1.0)
const MOTE_REGROW := 4.0
const ALERT_SPEED := 1.3
# Dreads drawn bigger than their kind (spec §4.6: Queen Crackle x1.6, the Hush-a-Bye x1.8).
const DREAD_SCALE := {"glassmite": 1.6, "hushling": 1.8}
# The v3 Omens' numbers.
const SPORE_R := 56.0
const SPORE_LIFE := 4.0
const ECHO_DELAY := 0.8
const ECHO_SHARE := 0.6
const ECHO_LINE_T := 0.6           # a shot echo's drawn line: where it flies in this long
const GLASS_SHARE := 0.30
const GLASS_STUN := 1.0
const HUSH_AURA := 120.0
const HUSH_DIM := 0.7
const HUSH_COL := Color("b49cff")
const SPORE_COL := Color("c8d46a")
# The lowest a basic shot fired from level ground passes: a Taperwitch's spark
# leaves 25 px up with a 6 px reach, a Sootrunner's knife 23 px up with 5 px.
# A ground monster's hit box stands at least this tall (a Twinned half, a
# splatted Dripkin), or those shots fly over it up close.
const SHOT_LINE := 20.0
const EYE_R := 3.0               # the least eye in the glow layer (rule 4)
const HUSH_KIND := "res://scripts/hush_kind.gd"   # MB's lit_alpha(e) (W6 rule 1), when it's there
const POINTS3 := "res://art/enemies/points_monsters3.json"   # A3's eyes and tell anchors for W3-W4

var copy := false               # a Twinned half: no Omens, doesn't split again
var frame_name := ""            # the frame show_frame() last put up
var fade := 1.0                 # the sprite's alpha on top of its tint (a death fading out)
var squash := 1.0               # the sprite's height share (a death melting down)
var motes: Array = []           # Warded: seconds until each mote is back (0 = up)
var _mote_spin := 0.0
var _fire_t := 0.0
var _trail: Array = []          # Swift: [{p, f, tex, sp}] the last few places
var _trail_t := 0.0
var _venge_t := 0.0
var _venge_flash := 0.0
var _mote_flash: Array = []     # {p, t}: a mote just broken
# The v3 Omens (P1).
var echo_by_body := true        # Echoing: false for a kind that calls strike_logged with blows of its own
var _om_echoes: Array = []      # Echoing: [{t, rect, life, shot, dmg, fired, done}] strikes to repeat
var _om_body: Array = []        # Echoing by body: [[t, rect]] where it was, newest first
var _om_body_cd := 0.0
var _om_glass := 0.0            # Glassed: the shell left
var _om_glass_max := 0.0
var _om_glass_flash := 0.0
var _om_alpha := 1.0            # Hushed: 1 in light, 0.15 outside it
var lit_alpha_own := false       # a W6 kind keeps the light-only alpha itself (MB's hush_kind): Hushed adds none
var _om_spin := 0.0
var _pg_seen := -1              # the knight kit's perfect_guards at this monster's last step
var _pg_hook := false            # KT's on_perfect_guard(player) (requested) just said so
var eye_r_drawn := 0.0           # the eye radius glow_eyes last drew (tests; rule 4)
var echo_marks := 0              # Echoing: the waiting echoes the last glow draw outlined (tests)
var _gtb: RefCounted = null      # a reused TriBatch for the glow layer (flush clears it)
var _btb: RefCounted = null      # and one for the stand-in body
static var _art_pts := {}         # a points json's path -> its Dictionary ({} when missing)
static var _hush_kind: Script = null
static var _hush_kind_looked := false
static var _hush_kind_has := false


func _ready() -> void:
	super()
	if copy:
		omens = []
	if tier != "":
		ordinary = false
	if tier == "dread" and DREAD_SCALE.has(kind) and scale_mult == 1.0:
		scale_mult = float(DREAD_SCALE[kind])
	_setup_look()
	if scale_mult != 1.0:
		# A Twinned half is smaller, but one on the ground keeps SHOT_LINE.
		size = Vector2(size.x * scale_mult, size.y * scale_mult if flier else maxf(size.y * scale_mult, SHOT_LINE))


func make_elite(t: String, o: Array) -> void:
	## Promotes a placed monster (level_features.assign_elites).
	tier = t
	omens = o.duplicate()
	ordinary = false
	if elite_name == "":
		elite_name = "Anointed " + str(NAMES.get(kind, kind.capitalize()))
	if world:
		var wn = world.get("world_n")
		setup_stats(area, world.diff, world.strength, int(wn) if wn != null else 0)
		# setup_stats starts the numbers over: what a mode multiplied in at
		# the spawn (the Descent's Stout Bones / Sharp Teeth) goes back on.
		var md = world.get("mode")
		if md != null and md.has_method("on_spawn"):
			md.on_spawn(self)
	else:
		setup_stats(area, "dusk")
	_setup_look()


func _setup_look() -> void:
	motes = [0.0, 0.0, 0.0] if has_omen("warded") else []
	match tier:
		"anointed":
			tint = Color(0.82, 0.9, 1.25)
		"dread":
			tint = Color(1.2, 1.02, 0.78)
		"warden":
			tint = Color(1.08, 1.08, 1.22)
	# Glassed: a shell worth 30% of its life, on top of it.
	_om_glass_max = GLASS_SHARE * max_hp if has_omen("glassed") else 0.0
	_om_glass = _om_glass_max


func show_frame(n: String) -> void:
	super(n)
	if frames.has(n):
		frame_name = n


func frame_point(p: Vector2) -> Vector2:
	## A point on the current frame (frame units, drawn facing right, 2 units
	## a pixel) where it is in the world: from the anchor, mirrored with the
	## facing and scaled like the sprite.
	var off := (p - anchor) * 0.5 * scale_mult
	off.x *= 1.0 if facing > 0 else -1.0
	return position + (sprite.position if sprite else Vector2.ZERO) + off


func art_eyes(table: Dictionary, fallback: Array) -> Array:
	## The eyes for the frame on show, from a kind's {frame: [eye, eye]}
	## table of W6b's eye points (frame units); fallback (world points)
	## before any frame is up, or with the stand-in drawing.
	if has_omen("hushed"):
		return []   # the Hushed Omen: its eyes go dark
	if frames.is_empty() or not table.has(frame_name):
		return fallback
	var out := []
	for p in table[frame_name]:
		out.append(frame_point(p))
	return out


func has_omen(o: String) -> bool:
	for x in omens:
		if str(x).to_lower() == o:
			return true
	return false


# ---------------------------------------------------------------- fair numbers

func tell(sec: float, floor_sec := TELL_FLOOR) -> float:
	## A tell's length: the difficulty's multiplier, then Swift's x0.75 only
	## off Dusk (decisions: on Dusk the Swift Omen changes speed and cooldowns
	## only), never under 0.30 s, nor under the move's own floor when the
	## caller passes one (contract §6.2: tell(sec, floor), e.g. the Shield
	## Slam's tell(0.70, 0.50)).
	var m: float = world.tells_mult() if world != null and world.has_method("tells_mult") else 1.0
	if has_omen("swift") and difficulty() != "dusk":
		m *= 0.75
	return maxf(sec * m, maxf(TELL_FLOOR, floor_sec))


func difficulty() -> String:
	## The World's difficulty ("dusk" with no World).
	if world == null:
		return "dusk"
	var d = world.get("diff")
	return str(d) if d != null else "dusk"


func behave_diff() -> String:
	## The difficulty its moves are chosen by (Build 2): difficulty(), but
	## an Anointed or a Dread (BEHAVE_TIERS) on Dusk in a story level from
	## World 3 (Combat.DUSK_TEETH_FROM) fights with Nightfall's moves: a
	## Rattlehound's second pounce, a Paneguard's 150 px lunge, an Anointed
	## Hushling's pack of 3-5. Only those lookups read it: its life, damage
	## and tells stay Dusk's (setup_stats, tell() and cd() read difficulty(),
	## so the Swift Omen still leaves Dusk's tells whole). Never "witching"
	## on Dusk, so a Witching-only branch stays on difficulty(). A Warden
	## keeps its own (the secrets are unchanged), a Twinned half is plain
	## (no tier), and a mode keeps v3's Dusk. The level's header
	## elite_behave: nightfall turns it on in any world (lab-elites), and
	## elite_behave: dusk off.
	var d := difficulty()
	if not BEHAVE_TIERS.has(tier) or d != "dusk" or world == null or world.get("mode") != null:
		return d
	var hd = level.get("headers") if level != null else null
	var say := str(hd.get("elite_behave", "")).strip_edges().to_lower() if hd is Dictionary else ""
	if say == "nightfall" or say == "dusk":
		return say
	var wn = world.get("world_n")
	return "nightfall" if wn != null and int(wn) >= Combat.DUSK_TEETH_FROM else d


func by_diff(dusk, nightfall, witching):
	## One of three values by the World's difficulty (a kind's per-difficulty numbers).
	match difficulty():
		"nightfall":
			return nightfall
		"witching":
			return witching
	return dusk


func by_behave(dusk, nightfall, witching):
	## by_diff by behave_diff(): a move's per-difficulty number (a speed, a
	## reach, a count), never a life, a blow or a tell.
	match behave_diff():
		"nightfall":
			return nightfall
		"witching":
			return witching
	return dusk


func cd(sec: float) -> float:
	## A cooldown: the same multipliers (Swift's on every difficulty), no floor.
	var m: float = world.tells_mult() if world != null and world.has_method("tells_mult") else 1.0
	if has_omen("swift"):
		m *= 0.75
	return sec * m


func spd(v: float) -> float:
	## A speed: Anointed x1.15, Swift x1.4, alerted x1.3.
	var m := 1.0
	if tier == "anointed":
		m *= 1.15
	if has_omen("swift"):
		m *= 1.4
	if status.has("alerted"):
		m *= ALERT_SPEED
	return v * m


func on_perfect_guard(_player: Node2D) -> void:
	## The knight's Perfect Guard on this monster (the hook MA asked KT for:
	## kits/knight.gd _perfect() calls it when the source has it).
	_pg_hook = true


func perfect_guarded() -> bool:
	## Is the stun being put on it now a Perfect Guard's (the knight's 1.0 s
	## stagger), not a Peal's or a Bell Shard's? KT's hook when it's there;
	## else the knight kit's perfect_guards count, which its _perfect()
	## bumps just before it staggers the source, has gone up since this
	## monster's last step.
	if _pg_hook:
		return true
	if world == null or world.get("kit") == null:
		return false
	var k = world.kit
	if str(k.get("cls")) != "knight" or k.get("perfect_guards") == null:
		return false
	return _pg_seen >= 0 and int(k.perfect_guards) > _pg_seen


func alert(seconds := 4.0) -> void:
	## A Hoarowl's alarm: faster for a while, and awake at once.
	apply_status("alerted", seconds)
	if alive:
		active = true


func sees(to: Vector2, from := Vector2.INF) -> bool:
	## Line of sight through the tiles (every 8 px).
	var a: Vector2 = center() if from == Vector2.INF else from
	var d := to - a
	var n := int(d.length() / 8.0) + 1
	for i in range(1, n):
		if solid_at(a + d * (float(i) / n)):
			return false
	return true


func drawn_rect() -> Rect2:
	## The body as drawn, for looks (a kind whose hit box stands taller than
	## its drawing, like a splatted Dripkin, overrides this).
	return rect()


func in_view() -> bool:
	## Wholly on screen, and not behind a thumb button or the HUD's corners
	## (world.gd in_plain_view): shooters only shoot like this.
	if world == null:
		return true
	if world.has_method("in_plain_view"):
		return world.in_plain_view(rect())
	return (world.view_rect() as Rect2).encloses(rect())


func sfx(name: String, fallback := "", pitch := 1.0, gain := 1.0) -> void:
	## A sound (a v3 one at pitch 1.0: its takes and its key are its own; the
	## pitch is kept for a v2 fallback), gain 0..1 for a quieter one.
	if has_omen("hushed"):
		return   # the Hushed Omen makes no sound (its tells are all drawn)
	play(world, name, fallback, pitch, gain)


func tell_sfx(name: String, seconds: float, fallback := "") -> void:
	## A tell's sound fitted to this tell's actual length (Sfx.tell trims a
	## tell that builds so its climax lands as the move does, and plays one
	## that warns with its onset whole), else as sfx(). Called at the tell's
	## start with the seconds it really lasts (after tells_mult and Swift).
	if has_omen("hushed"):
		return
	if world == null or not world.has_method("_has_sfx") or not world._has_sfx():
		return
	var s = world.get_node_or_null("/root/Sfx")
	if s != null and s.has_method("tell") and (s.get("NAMES") as Array).has(name):
		s.tell(name, seconds)
	else:
		sfx(name, fallback)


static func play(w: Node, name: String, fallback := "", pitch := 1.0, gain := 1.0) -> void:
	## A sound if it exists yet (W7 adds the new ones), else the fallback.
	if w == null or not w.has_method("_has_sfx") or not w._has_sfx():
		return
	var s = w.get_node_or_null("/root/Sfx")
	if s == null:
		return
	var names = s.get("NAMES")
	if names is Array and not (names as Array).has(name):
		if fallback == "":
			return
		name = fallback
	elif pitch != 1.0:
		var v3 = s.get("V3_NAMES")
		if v3 is Array and (v3 as Array).has(name):
			pitch = 1.0   # (A7: a v3 recording's length is its tell, and it's tuned)
	if gain != 1.0:
		w._sfx(name, pitch, 0.0, gain)
	else:
		w._sfx(name, pitch)


func pc(c: Color) -> Color:
	## A placeholder drawing's colour: the sprite's tint and hit flash.
	var k := c * tint
	if status.has("sooted"):
		k = k * Color(0.55, 0.55, 0.6)
	k = k.lerp(Color(1, 1, 1, k.a), clampf(flash, 0.0, 1.0) * 0.8)
	k.a *= _om_alpha * fade
	return k


# ---------------------------------------------------------------- the step

func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	_pg_hook = false
	if world != null and world.get("kit") != null and world.kit.get("perfect_guards") != null:
		_pg_seen = int(world.kit.perfect_guards)
	if sprite:
		# enemy.gd sets the sprite's colour and scale every step, so a death's
		# fade and melt go on top of that here.
		if fade < 1.0:
			sprite.modulate.a *= clampf(fade, 0.0, 1.0)
		if squash != 1.0:
			sprite.scale.y *= squash
	if not alive:
		return
	_venge_t = maxf(_venge_t - dt, 0.0)
	_venge_flash = maxf(_venge_flash - dt, 0.0)
	_mote_spin += dt * 2.4
	for i in motes.size():
		motes[i] = maxf(float(motes[i]) - dt, 0.0)
	for m in _mote_flash:
		m["t"] += dt
	_mote_flash = _mote_flash.filter(func(m): return m["t"] < 0.35)
	if has_omen("swift"):
		_trail_t -= dt
		if _trail_t <= 0.0:
			_trail_t = 0.06
			_trail.push_front({"p": position, "f": facing, "tex": sprite.texture if sprite else null,
					"sp": sprite.position if sprite else Vector2.ZERO})
			if _trail.size() > 3:
				_trail.pop_back()
	if has_omen("burning") and world and not stunned():
		_fire_t -= dt
		if _fire_t <= 0.0:
			_burn_trail()
	_step_v3_omens(dt, player)


func _step_v3_omens(dt: float, player: Node2D) -> void:
	## Sporebound's motes, Echoing's repeats, Glassed's glint, Hushed's aura
	## and its light-only look.
	_om_spin += dt
	_om_glass_flash = maxf(_om_glass_flash - dt, 0.0)
	if has_omen("echoing"):
		_step_echoes(dt, player)
	if has_omen("hushed"):
		# (a W6 kind already draws by the light-only rule: HK.shade / own_alpha)
		_om_alpha = 1.0 if lit_alpha_own else lit_alpha()
		if sprite and not lit_alpha_own:
			sprite.modulate.a *= _om_alpha
		if world != null and player != null and player.alive and world.has_method("dim") \
				and player.center().distance_to(center()) <= HUSH_AURA:
			world.dim("hushed_omen", HUSH_DIM, 0.25)


func lit_alpha() -> float:
	## W6 rule 1: 1.0 inside any gameplay light, 0.15 outside (MB's
	## hush_kind.lit_alpha when it's there, else world.lit_at).
	if not _hush_kind_looked:
		_hush_kind_looked = true
		if ResourceLoader.exists(HUSH_KIND):
			_hush_kind = load(HUSH_KIND)
			for m in _hush_kind.get_script_method_list():
				_hush_kind_has = _hush_kind_has or m["name"] == "lit_alpha"
	if _hush_kind_has:
		return float(_hush_kind.call("lit_alpha", self))
	if world != null and world.has_method("lit_at"):
		return 1.0 if world.lit_at(center()) else 0.15
	return 1.0


func strike_logged(what, damage: float) -> void:
	## The Echoing Omen's hook (contract §6.2): a kind calls it as it strikes,
	## with the box it struck (a Rect2, or {rect, life}), the shot it fired
	## (a spawn_shot Dictionary: pos, vel) or the beam hazard it laid (seg),
	## and the blow's damage. An Echoing monster strikes again ECHO_DELAY
	## later at the same place, at ECHO_SHARE. A kind that calls it has blows
	## of its own, so it leaves no body echo (echo_by_body goes off here, and
	## no other stream need know the flag).
	if echo_by_body:
		echo_by_body = false
		_om_body.clear()
	if not has_omen("echoing") or not alive:
		return
	var e := {"t": ECHO_DELAY, "dmg": damage * ECHO_SHARE, "fired": -1.0, "life": 0.15}
	if what is Rect2:
		e["rect"] = what
	elif what is Dictionary:
		var d: Dictionary = what
		if d.has("rect"):
			e["rect"] = d["rect"]
			e["life"] = float(d.get("life", 0.15))
		elif d.has("seg"):
			# A beam hazard (a Refractor's): the same segment again.
			var hz := d.duplicate(true)
			hz["hit_ids"] = []
			hz["echo"] = true
			e["hazard"] = hz
		elif d.has("pos") and d.has("vel"):
			var sh := d.duplicate(true)
			sh["hit_ids"] = []
			sh["t"] = 0.0
			e["shot"] = sh
		else:
			return   # a shape it can't repeat (a Lurecoil's arc): no echo
	else:
		return
	_om_echoes.append(e)


func _step_echoes(dt: float, player: Node2D) -> void:
	for e in _om_echoes:
		if float(e["fired"]) < 0.0:
			e["t"] = float(e["t"]) - dt
			if float(e["t"]) <= 0.0:
				e["fired"] = 0.0
				sfx("omen_tick", "click", 0.8)
				if e.has("shot") and world != null and world.has_method("spawn_shot"):
					var sh: Dictionary = e["shot"]
					sh["dmg"] = float(e["dmg"])
					sh["life"] = float(sh.get("life", 1.0))
					sh["echo"] = true
					world.spawn_shot(sh)
				elif e.has("hazard") and world != null and world.has_method("add_hazard"):
					var hz: Dictionary = e["hazard"]
					hz["dmg"] = float(e["dmg"])
					world.add_hazard(hz)
		else:
			e["fired"] = float(e["fired"]) + dt
			if e.has("rect") and not e.get("hit", false) and float(e["fired"]) <= float(e["life"]) and player != null \
					and player.alive and world != null and (e["rect"] as Rect2).intersects(player.rect()):
				e["hit"] = true
				world.hurt_player(float(e["dmg"]), (e["rect"] as Rect2).get_center().x, "hit", self, {"move": "echo"})
	_om_echoes = _om_echoes.filter(func(e): return float(e["fired"]) < maxf(float(e["life"]), 0.25))
	if not echo_by_body:
		return
	# A body that strikes only by touch: a pale echo of it ECHO_DELAY behind
	# (its own clock t, sampled every step; the oldest kept is the echo).
	_om_body_cd = maxf(_om_body_cd - dt, 0.0)
	_om_body.push_front([t, hurt_rect()])
	while _om_body.size() > 1 and t - float(_om_body[_om_body.size() - 2][0]) >= ECHO_DELAY - 0.0001:
		_om_body.pop_back()
	var er := echo_body_rect()
	if er.size.x > 0.0 and _om_body_cd <= 0.0 and player != null and player.alive and world != null and er.intersects(player.rect()):
		if world.hurt_player(omen_dmg(ECHO_SHARE), er.get_center().x, "hit", self, {"move": "echo"}):
			_om_body_cd = ECHO_DELAY


func echo_lines(e: Dictionary) -> Array:
	## Where an echo that isn't a box will strike, as [[from, to]]: a beam's
	## segment, or a shot's line over its first ECHO_LINE_T s (or its life).
	if e.has("hazard"):
		var seg: Array = (e["hazard"] as Dictionary).get("seg", [])
		return [[seg[0], seg[1]]] if seg.size() == 2 else []
	if e.has("shot"):
		var sh: Dictionary = e["shot"]
		var p0: Vector2 = sh["pos"]
		var v: Vector2 = sh["vel"]
		return [[p0, p0 + v * minf(float(sh.get("life", 1.0)), ECHO_LINE_T)]]
	return []


func _dash(tb: RefCounted, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	## A dashed line (8 px on, 6 off) into a batch.
	var len := a.distance_to(b)
	if len < 0.5:
		return
	var d := (b - a) / len
	var x := 0.0
	while x < len:
		tb.line(a + d * x, a + d * minf(x + 8.0, len), w, col)
		x += 14.0


func echo_body_rect() -> Rect2:
	## Where its body echo is (ECHO_DELAY behind it), or an empty rect.
	if not has_omen("echoing") or not echo_by_body or _om_body.is_empty():
		return Rect2()
	var last: Array = _om_body[_om_body.size() - 1]
	if t - float(last[0]) < ECHO_DELAY - 0.0001:
		return Rect2()   # not yet ECHO_DELAY of its past
	return last[1]


func glass_left() -> float:
	## Glassed: the shell's share left (0..1), 0 without one.
	return _om_glass / _om_glass_max if _om_glass_max > 0.0 else 0.0


func is_maul(h: Dictionary) -> bool:
	## The Bellfounder's own swing.
	return str(h.get("how", "")) == "slash" and world != null and world.get("kit") != null and str(world.kit.get("cls")) == "founder"


func is_finisher(h: Dictionary) -> bool:
	## The Candleknight's third cut.
	if str(h.get("how", "")) != "slash" or world == null or world.get("kit") == null or str(world.kit.get("cls")) != "knight":
		return false
	return float(world.kit.melee_coef()) > 1.2


func heavy_hit(h: Dictionary) -> bool:
	## The heavy blows (Glassed: x2 to the shell): a stomp, a wave, a Special,
	## the maul, a Finisher.
	var how := str(h.get("how", ""))
	return how in ["stomp", "wave", "skill", "shock"] or is_maul(h) or is_finisher(h)


func fire_hit(h: Dictionary) -> bool:
	## A fire blow: a burn tick, the Taperwitch's sparks and Flares, or a
	## player's fire patch under it (a knight's or founder's burning floor).
	var how := str(h.get("how", ""))
	if how == "burn":
		return true
	if world == null or world.get("kit") == null:
		return false
	if str(world.kit.get("cls")) == "witch" and how in ["shot", "skill"]:
		return true
	if how == "wave":
		for hz in world.hazards:
			if hz.get("owner", "") == "player" and hz.get("kind", "") == "fire" and (hz["rect"] as Rect2).intersects(rect().grow(4.0)):
				return true
	return false


func omen_dmg(share: float) -> float:
	## An Omen's hurt: a share of its touch (a moth has none, so a stand-in).
	return share * maxf(dmg("touch"), 18.0 * dmg_mult)


func _burn_trail() -> void:
	if flier:
		_fire_t = 0.9
		# Not straight onto his head while it clings to his flame.
		if world.player and rect().intersects((world.player.rect() as Rect2).grow(10.0)):
			return
		world.add_hazard({"kind": "fire", "motion": "fall", "rect": Rect2(center() - Vector2(5, -6), Vector2(10, 10)),
				"vel": Vector2(0, 40), "g": 900.0, "life": 2.5, "dmg": omen_dmg(0.3), "owner": "enemy"})
	elif on_floor:
		_fire_t = 0.6
		world.add_hazard({"kind": "fire", "motion": "still", "rect": Rect2(position.x - 16, position.y - 8, 32, 8),
				"life": 2.0, "dmg": omen_dmg(0.3), "owner": "enemy"})


# ---------------------------------------------------------------- being hit

func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	if _ward_blocks(h):
		return false
	var shell := 0.0
	if _om_glass > 0.0 and h.has("amount"):
		# Glassed: the shell takes the blow first (heavy hits x2, basic shots
		# x0.5), it doesn't flinch while the shell holds, and the blow's rest
		# goes on through at its own rate.
		var k := 2.0 if heavy_hit(h) else (0.5 if str(h.get("how", "")) == "shot" else 1.0)
		var a := float(h["amount"])
		shell = minf(a * k, _om_glass)
		_om_glass -= shell
		h = h.duplicate()
		h["amount"] = maxf(a - shell / k, 0.0)
		h["crit"] = false
		_om_glass_flash = 0.25
		if _om_glass <= 0.0:
			_om_glass = 0.0
			apply_status("stun", GLASS_STUN)
			sfx("omen_glass_break", "clang", 1.2)
			if world != null and world.get("glow") != null:
				world.glow.burst(center(), 18, Color(0.85, 0.95, 1.0, 0.95), 190.0, 0.45, 500.0, 2.2)
		else:
			sfx("glass_tink", "clang", 1.5)
	var p0 := poise
	if shell > 0.0 and _om_glass > 0.0:
		poise = INF
	var ok := super(h)
	poise = p0
	if shell > 0.0:
		ok = true
		last_damage += shell
	if ok and has_omen("vengeful") and _venge_t <= 0.0:
		_shards()
	return ok


func _ward_blocks(h: Dictionary) -> bool:
	## Warded: a mote takes the hit. A stomp breaks all of them and lands.
	var up := motes_up()
	if up == 0:
		return false
	var how: String = h.get("how", "slash")
	if how == "stomp":
		for i in motes.size():
			if float(motes[i]) <= 0.0:
				_mote_flash.append({"p": mote_pos(i), "t": 0.0})
			motes[i] = MOTE_REGROW
		sfx("shield_clang", "clang", 1.3)
		return false
	# The mote nearest the blow goes.
	var from_x: float = float(h.get("from_x", position.x))
	var best := -1
	var bd := INF
	for i in motes.size():
		if float(motes[i]) > 0.0:
			continue
		var d: float = absf(mote_pos(i).x - from_x)
		if d < bd:
			bd = d
			best = i
	motes[best] = MOTE_REGROW
	_mote_flash.append({"p": mote_pos(best), "t": 0.0})
	flash = 0.4
	sfx("shield_clang", "clang", 1.4)
	if world and how != "slash":
		world.number(center() + Vector2(0, -size.y * 0.5), 0.0, "blocked", 0)
	return true


func motes_up() -> int:
	var n := 0
	for m in motes:
		if float(m) <= 0.0:
			n += 1
	return n


func mote_pos(i: int) -> Vector2:
	var a := _mote_spin + TAU * i / 3.0
	var r := size.x * 0.5 + 14.0
	return center() + Vector2(cos(a) * r, sin(a) * r * 0.55 - 4.0)


func _shards() -> void:
	_venge_t = 0.25
	_venge_flash = 0.2
	if world == null:
		return
	var c := center()
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		world.add_hazard({"kind": "shard", "motion": "fly", "rect": Rect2(c - Vector2(4, 4), Vector2(8, 8)),
				"vel": (d as Vector2).normalized() * 160.0, "life": 0.8, "dmg": omen_dmg(0.4), "owner": "enemy"})


func _kill(h: Dictionary) -> void:
	super(h)
	if has_omen("twinned") and not copy:
		_split()
	if has_omen("sporebound") and world != null and world.get("features") != null:
		# Sporebound: it bursts into a spore cloud (the one cloud rule).
		world.features.add_spores(center(), SPORE_R, SPORE_LIFE, self)
		sfx("omen_spores", "spore_puff")
		if world.get("glow") != null:
			world.glow.burst(center(), 14, Color(SPORE_COL, 0.9), 90.0, 0.8, -40.0, 3.0, 30.0)


func _split() -> void:
	## Twinned: two smaller halves, each with a quarter of its life.
	if world == null:
		return
	var tm := 2.5 if tier == "anointed" else (4.0 if tier == "dread" else 1.0)
	for dir in [-1, 1]:
		var c: Node2D = world.spawn_enemy(kind, position + Vector2(dir * 8.0, -2.0), {"scale": 0.6 * scale_mult,
				"hp_frac": 0.25 * tm, "facing": dir})
		if c:
			c.set("copy", true)
			c.omens = []
			c.velocity = Vector2(dir * 140.0, -260.0)
			if c.has_method("as_copy"):
				c.as_copy()
	if world.glow:
		world.glow.burst(center(), 14, Color("efe6d2"), 150.0, 0.4, 200.0, 2.2)


func as_copy() -> void:
	## A Twinned half starting out mid-air (kinds that hang or hide override).
	pass


func as_add() -> void:
	## A boss's summoned add (spec §4.1 rule 7): not fodder, never respawns,
	## half XP (respawned), no items or embers. The boss kills it when it
	## roars into a new phase.
	respawned = true
	ordinary = false
	item_chance = 0.0
	relic_chance = 0.0
	embers = 0


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	if tier != "":
		_draw_elite(glow)
	if has_omen("swift"):
		_draw_trail(glow)
	if has_omen("warded"):
		_draw_motes(glow)
	if has_omen("burning"):
		for i in 3:
			var k := fmod(t * 1.7 + i * 0.33, 1.0)
			var p := center() + Vector2(sin(t * 3.0 + i * 2.1) * size.x * 0.4, size.y * 0.3 - k * (size.y + 14.0))
			glow.draw_circle(p, 2.6 * (1.0 - k) + 0.6, Color(1.0, 0.55 + 0.3 * k, 0.2, 0.85 * (1.0 - k)))
	if has_omen("twinned") and not copy:
		# The seam it will split along.
		var r := drawn_rect()
		var pts := PackedVector2Array()
		for i in 7:
			var y := r.position.y + 3.0 + (r.size.y - 6.0) * i / 6.0
			pts.append(Vector2(r.get_center().x + (2.5 if i % 2 == 0 else -2.5), y))
		glow.draw_polyline(pts, Color(1.0, 0.95, 0.8, 0.55), 1.5)
	if _venge_flash > 0.0:
		glow.draw_arc(center(), size.x * 0.6 + (0.2 - _venge_flash) * 90.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.25, _venge_flash * 4.0), 3.0)
	if status.has("alerted") or has_omen("sporebound") or has_omen("echoing") or has_omen("glassed") or has_omen("hushed"):
		_draw_v3_omens(glow)


func gtb() -> RefCounted:
	## The glow layer's batch (reused; each flush clears it).
	if _gtb == null:
		_gtb = ELITE_TB.new()
	return _gtb


func btb() -> RefCounted:
	## The stand-in body's batch (reused; each flush clears it).
	if _btb == null:
		_btb = ELITE_TB.new()
	return _btb


func _draw_v3_omens(glow: Node2D) -> void:
	## The v3 Omens' tells and the alerted "!" (one TriBatch, rects beside it).
	var tb := gtb()
	var r := drawn_rect()
	var c := r.get_center()
	if has_omen("sporebound"):
		# Green motes drift up off it.
		for i in 5:
			var k := fmod(_om_spin * 0.6 + i * 0.2, 1.0)
			var p := Vector2(c.x + sin(_om_spin * 2.0 + i * 1.7) * r.size.x * 0.45, r.end.y - k * (r.size.y + 22.0))
			tb.circle(p, 2.4 * (1.0 - k) + 0.8, Color(SPORE_COL, 0.9 * (1.0 - k)), 8)
	if has_omen("echoing"):
		# A clock-hand ring ticking round its feet (a step a quarter second).
		var feet := Vector2(position.x, r.end.y)
		var rx := r.size.x * 0.6 + 6.0
		var ring := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			ring.append(feet + Vector2(cos(a) * rx, sin(a) * rx * 0.3))
		tb.polyline(ring, 1.5, Color(0.85, 0.9, 1.0, 0.55), true)
		var ha := floorf(_om_spin * 4.0) * TAU / 12.0 - PI * 0.5
		tb.line(feet, feet + Vector2(cos(ha) * rx * 0.9, sin(ha) * rx * 0.27), 2.0, Color(0.95, 0.97, 1.0, 0.85))
		echo_marks = 0
		for e in _om_echoes:
			var waiting := float(e["fired"]) < 0.0
			var k := 1.0 - clampf(float(e["t"]) / ECHO_DELAY, 0.0, 1.0)
			if e.has("rect"):
				var er: Rect2 = e["rect"]
				if waiting:
					# Outlined from the strike until it fires, brighter as it nears.
					glow.draw_rect(er, Color(0.85, 0.92, 1.0, 0.35 + 0.5 * k), false, 1.5)
					echo_marks += 1
				else:
					glow.draw_rect(er, Color(0.85, 0.92, 1.0, 0.45 * (1.0 - float(e["fired"]) / 0.25)))
			elif waiting:
				# A shot's or a beam's echo: its line, pale, brightening as it nears.
				var segs := echo_lines(e)
				for seg in segs:
					_dash(tb, seg[0], seg[1], 2.0 if e.has("hazard") else 1.5, Color(0.85, 0.92, 1.0, 0.3 + 0.55 * k))
					tb.ring(seg[0], 5.0 + 3.0 * (1.0 - k), 1.4, Color(0.9, 0.95, 1.0, 0.35 + 0.5 * k), 12)
				if not segs.is_empty():
					echo_marks += 1
		var br := echo_body_rect()
		if br.size.x > 0.0:
			glow.draw_rect(br, Color(0.82, 0.9, 1.0, 0.22))
			glow.draw_rect(br, Color(0.9, 0.95, 1.0, 0.6), false, 1.5)
	if has_omen("glassed") and _om_glass > 0.0:
		# A faceted shell: a six-sided pane round the body, its facets
		# catching a glint that slides across it (brighter when struck).
		var hw := r.size.x * 0.5 + 3.0
		var hh := r.size.y * 0.5 + 3.0
		var hex := PackedVector2Array([c + Vector2(-hw, 0), c + Vector2(-hw * 0.5, -hh), c + Vector2(hw * 0.5, -hh),
				c + Vector2(hw, 0), c + Vector2(hw * 0.5, hh), c + Vector2(-hw * 0.5, hh)])
		var bright := 0.35 + 0.5 * clampf(_om_glass_flash * 4.0, 0.0, 1.0)
		tb.convex(hex, Color(0.85, 0.95, 1.0, 0.07 + 0.08 * clampf(_om_glass_flash * 4.0, 0.0, 1.0)))
		tb.polyline(hex, 1.2, Color(0.9, 0.97, 1.0, bright), true)
		for i in 3:
			tb.line(c + Vector2(0, hh * 0.15), hex[i * 2 + 1], 0.8, Color(0.9, 0.97, 1.0, 0.18))
		var gk := fmod(_om_spin * 0.7, 1.6) - 0.3
		if gk > 0.0 and gk < 1.0:
			var gx := c.x - hw + gk * hw * 2.0
			tb.line(Vector2(gx - 3.0, c.y + hh * 0.7), Vector2(gx + 3.0, c.y - hh * 0.7), 1.6, Color(1, 1, 1, 0.55))
	if has_omen("hushed"):
		# A faint violet rim, always (it's seen whole only in light).
		var rim := PackedVector2Array()
		for i in 18:
			var a := TAU * i / 18.0
			rim.append(c + Vector2(cos(a) * (r.size.x * 0.5 + 3.0), sin(a) * (r.size.y * 0.5 + 3.0)))
		tb.polyline(rim, 2.0, Color(HUSH_COL, 0.55), true)
	if status.has("alerted"):
		# A tiny white "!".
		var at := Vector2(c.x, r.position.y - 16.0)
		glow.draw_rect(Rect2(at.x - 1.5, at.y - 9.0, 3.0, 7.0), Color(1, 1, 1, 0.95))
		glow.draw_rect(Rect2(at.x - 1.5, at.y, 3.0, 3.0), Color(1, 1, 1, 0.95))
	tb.flush(glow)
	if _om_glass_max > 0.0 and hp_bar > 0.0 and _om_glass > 0.0:
		# The shell's white segment, just over the life bar.
		var w := 26.0
		var at2 := Vector2(rect().get_center().x - w * 0.5, rect().position.y - 13.0)
		glow.draw_rect(Rect2(at2, Vector2(w, 2.0)), Color(0.1, 0.1, 0.15, 0.8))
		glow.draw_rect(Rect2(at2, Vector2(w * glass_left(), 2.0)), Color(0.95, 0.98, 1.0, 0.95))


func eye_col(col: Color) -> Color:
	## An elite's eye glint: its tier's colour, green when Sporebound.
	return SPORE_COL if has_omen("sporebound") else col.lightened(0.35)


func _draw_elite(glow: Node2D) -> void:
	var col := DREAD_COL if tier == "dread" else (WARDEN_COL if tier == "warden" else ANOINTED_COL)
	var pulse := 0.5 + 0.5 * sin(t * 3.2)
	var feet := Vector2(position.x, rect().end.y if flier else position.y)
	var rx := size.x * 0.75 + 4.0
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		pts.append(feet + Vector2(cos(a) * rx, sin(a) * rx * 0.28 - 1.0))
	glow.draw_polyline(pts, Color(col, 0.45 + 0.35 * pulse), 2.0)
	var c2 := col
	c2.a = 0.10 + 0.06 * pulse
	glow.draw_circle(center(), size.y * 0.75, c2)
	if has_omen("hushed"):
		return   # its eyes go dark
	for p in eye_points():
		glow.draw_circle(p, 2.6, eye_col(col))
		glow.draw_circle(p, 5.0, Color(col, 0.25))


func _draw_trail(glow: Node2D) -> void:
	for i in _trail.size():
		var g: Dictionary = _trail[i]
		var a := 0.26 - i * 0.07
		var col := Color(0.6, 0.78, 1.0, a)
		var tex = g["tex"]
		if tex is Texture2D:
			var sm := TEX_SCALE * scale_mult
			glow.draw_set_transform(g["p"] + g["sp"], 0.0, Vector2(sm * (1.0 if int(g["f"]) > 0 else -1.0), sm))
			glow.draw_texture(tex, Vector2(-anchor.x * 2.0, -anchor.y * 2.0), col)
			glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var r := rect()
			r.position += g["p"] - position
			glow.draw_rect(r.grow(-2.0), col)


func _draw_motes(glow: Node2D) -> void:
	for i in motes.size():
		if float(motes[i]) > 0.0:
			# Regrowing: a faint ember where it will be.
			var k := 1.0 - float(motes[i]) / MOTE_REGROW
			glow.draw_circle(mote_pos(i), 1.5 + 2.0 * k, Color(0.9, 0.85, 0.7, 0.25 * k))
			continue
		var p := mote_pos(i)
		glow.draw_circle(p, 7.0, Color(1.0, 0.8, 0.45, 0.16))
		glow.draw_circle(p + Vector2(0, 3), 2.6, Color("efe6d2"))
		if glow.has_method("flame"):
			glow.flame(p + Vector2(0, 2), 7.0, p.x + i)
	for m in _mote_flash:
		var k: float = m["t"] / 0.35
		glow.draw_arc(m["p"], 4.0 + k * 14.0, 0.0, TAU, 16, Color(1.0, 0.9, 0.6, 1.0 - k), 2.0)


func lights() -> Array:
	var out := []
	for i in motes.size():
		if float(motes[i]) <= 0.0:
			out.append({"p": mote_pos(i), "r": 30.0, "s": 0.7})
	return out


# ---------------------------------------------------------------- picking the Anointed

static func pick_elites(world: Node, level: RefCounted, rng: RandomNumberGenerator) -> Array:
	## The Anointed for this level: [{enemy, omens}]. Deterministic for the
	## seed (the level, the difficulty and rng's seed). None in 1-1.
	var out := []
	if level.id == "1-1":
		return out
	# The chances and the cap: world.elite_rules() (Combat.elite_rules by
	# world, a mode's merged over it; contract §5.5), else the difficulty's.
	# W1-W2 on Dusk read 6% / 2, as ever.
	var d: Dictionary = world.elite_rules() if world.has_method("elite_rules") else Combat.diff(world.diff)
	var wn = world.get("world_n")
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(level.id) + str(world.diff) + str(rng.seed))
	var keep_away: Array = [level.start]
	for e in level.entities:
		if e["kind"] == "altar":
			keep_away.append(e["cell"])
	var chosen: Array[Vector2i] = []
	for e in level.entities:
		if e["kind"] == "dread":
			chosen.append(e["cell"])
	# And the ones already tiered: the Anointed an anoint: header placed
	# (level_features.assign_elites, before this). They're outside the max.
	for en in world.enemies:
		var tc: Vector2i = en.spawn.get("cell", Vector2i(-1, -1))
		if en.tier != "" and tc.x >= 0 and not chosen.has(tc):
			chosen.append(tc)
	var cands := []
	for en in world.enemies:
		if en.tier != "" or not (en.kind in ELIGIBLE) or en.get("copy"):
			continue
		var cell: Vector2i = en.spawn.get("cell", Vector2i(-1, -1))
		if cell.x < 0:
			continue
		cands.append(en)
	cands.sort_custom(func(a, b): return a.spawn["cell"].x < b.spawn["cell"].x)
	for en in cands:
		if out.size() >= int(d["max_anoint"]):
			break
		var roll := r.randf()
		if roll >= float(d["anoint"]):
			continue
		var cell: Vector2i = en.spawn["cell"]
		# A flier (and a Creepbone on its lane) is judged by the floor under it,
		# a Hoarowl on its bracket by the floor under its perch.
		if not safe_for(level, cell, en.kind, bool(en.get("flier"))):
			continue
		var near := false
		for k in keep_away:
			if absi(k.x - cell.x) < 12 and absi(k.y - cell.y) < 8:
				near = true
		for c in chosen:
			if absi(c.x - cell.x) < 20:
				near = true
		if near:
			continue
		chosen.append(cell)
		out.append({"enemy": en, "omens": roll_omens(en.kind, world.diff, int(wn) if wn != null else 0, r, d)})
	return out


static func omen_span(diff_id: String) -> Vector2i:
	## How many Omens an elite carries on a difficulty, (least, most): at
	## most its Combat.DIFF omens, and at least what the difficulty below
	## could give (1 on Dusk). The table's 1 / 2 / 2 makes the spec's
	## 1 / 1-2 / 2 (spec §5); tune the table, not this.
	var i := maxi(Combat.DIFFS.find(diff_id), 0)
	var most := maxi(int(Combat.diff(Combat.DIFFS[i])["omens"]), 1)
	var least := 1 if i == 0 else maxi(int(Combat.diff(Combat.DIFFS[i - 1])["omens"]), 1)
	return Vector2i(mini(least, most), most)


static func omen_pool(k: String, diff_id: String, world_n: int) -> Array:
	## The Omens a kind may roll in this world on this difficulty (spec §4.6):
	## v2's five (no Vengeful on Dusk before W6), plus the world's v3 ones
	## (WORLD_OMENS; W4's Echoing only from Nightfall), less NEVER_ON. In
	## OMENS order, so W1-W2 pools (and their seeds' picks) are v2's exactly.
	var w := clampi(world_n, 0, 6)
	var extra: Array = WORLD_OMENS.get(w, [])
	var waits: Array = DUSK_WAITS.get(w, []) if diff_id == "dusk" else []
	var pool := []
	for o in OMENS:
		if V3_OMENS.has(o) and (not extra.has(o) or waits.has(o)):
			continue
		if NEVER_ON.get(o, []).has(k):
			continue
		if diff_id == "dusk" and o == "Vengeful" and w < DUSK_VENGEFUL_FROM:
			continue
		pool.append(o)
	return pool


static func roll_omens(k: String, diff_id: String, world_n: int, r: RandomNumberGenerator, rules := {}) -> Array:
	## An elite's Omens (contract §6.2: roll_omens(kind, diff, world, rng)).
	## How many: omen_span(diff) (a mode's rules.omens may raise the most, and
	## rules.omens_min the least); on
	## Dusk one more at rules.second_omen (Combat.elite_rules: 20-60% from W3
	## in a story level; a mode's v3 rows, W5 35%, W6 50%).
	## A fixed count takes no roll, and W1-W2 take no second-Omen roll, so a
	## seed picks the same Omens there as ever. Never more than MAX_OMENS.
	## rules.omens_ban: Omens never rolled here (the toll's twist: no Swift,
	## so its x1.3 never stacks on Swift's x1.4; Twists.elite_rules).
	var span := omen_span(diff_id)
	var most := span.y
	var least := span.x
	if rules.has("omens"):
		most = maxi(most, int(rules["omens"]))
	if rules.has("omens_min"):
		# A mode's own floor (the Descent's deeper elites carry 2 each).
		least = clampi(int(rules["omens_min"]), least, most)
	var n := least if least == most else r.randi_range(least, most)
	if diff_id == "dusk":
		var second := float(rules.get("second_omen", _second_omen(diff_id, world_n)))
		if second > 0.0 and r.randf() < second:
			n += 1
	n = mini(n, MAX_OMENS)
	var ban: Array = rules.get("omens_ban", [])
	var pool := omen_pool(k, diff_id, world_n).filter(func(o): return not ban.has(o))
	var out := []
	while out.size() < n and pool.size() > 0:
		var i := r.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


static func anoint_specs(level: RefCounted) -> Array:
	## The level's anoint: header as [{cell, omens, name}]: "x,y" (its Omens
	## rolled), "x,y:Swift+Warded" (those Omens), "x,y:Swift:Brother Clatter"
	## or "x,y::Brother Clatter" (a name, rolled Omens), parts by ";". An
	## Omen's case doesn't matter; a part whose cell isn't "x,y" is skipped.
	var out := []
	var hd = level.get("headers") if level != null else null
	if not (hd is Dictionary) or str(hd.get("anoint", "")).strip_edges() == "":
		return out
	for part in str(hd["anoint"]).split(";"):
		var bits := part.strip_edges().split(":", true, 2)
		var xy := bits[0].strip_edges().split(",")
		if xy.size() != 2 or not xy[0].strip_edges().is_valid_int() or not xy[1].strip_edges().is_valid_int():
			continue
		var omens := []
		if bits.size() > 1:
			for o in bits[1].split("+", false):
				var want := str(o).strip_edges().to_lower()
				for known in OMENS:
					if str(known).to_lower() == want and not omens.has(known):
						omens.append(known)
		out.append({"cell": Vector2i(int(xy[0]), int(xy[1])), "omens": omens,
				"name": bits[2].strip_edges() if bits.size() > 2 else ""})
	return out


static func forced_omens(k: String, chosen: Array, diff_id: String, world_n: int, r: RandomNumberGenerator, rules := {}) -> Array:
	## A header's Anointed's Omens: the chosen ones its kind may carry here
	## (omen_pool: not NEVER_ON, the world's, Vengeful and W4's Echoing only
	## where they're allowed), then topped up from the pool to the
	## difficulty's least (Witching's 2; never an Omen rules.omens_ban
	## holds), never more than MAX_OMENS. None chosen, or none that fit:
	## roll_omens, as the World would (so 3-S's plain cells roll what they
	## always rolled).
	var pool := omen_pool(k, diff_id, world_n)
	var out := []
	for o in chosen:
		if pool.has(o) and not out.has(o) and out.size() < MAX_OMENS:
			out.append(o)
	if out.is_empty():
		return roll_omens(k, diff_id, world_n, r, rules)
	var least := omen_span(diff_id).x
	if rules.has("omens_min"):
		least = maxi(least, int(rules["omens_min"]))
	var ban: Array = rules.get("omens_ban", [])
	var rest := pool.filter(func(o): return not out.has(o) and not ban.has(o))
	while out.size() < mini(least, MAX_OMENS) and rest.size() > 0:
		var i := r.randi_range(0, rest.size() - 1)
		out.append(rest[i])
		rest.remove_at(i)
	return out


static func _second_omen(diff_id: String, world_n: int) -> float:
	## Combat.elite_rules' second_omen (0 before PR's table has it).
	for m in (Combat as Script).get_script_method_list():
		if m["name"] == "elite_rules":
			var rr = (Combat as Script).call("elite_rules", diff_id, world_n)
			return float(rr.get("second_omen", 0.0)) if rr is Dictionary else 0.0
	return 0.0


static func safe_for(level: RefCounted, cell: Vector2i, kind: String, flier := false) -> bool:
	## Is this monster's cell safe ground for an elite, judged its kind's way:
	## a flier (and a Creepbone on its lane) by the floor under it; a Hoarowl
	## by its own floor when that is wide, else by the floor under its perch.
	if kind == "bat" or flier or kind == "creepbone":
		return safe_cell(level, cell, true)
	if kind == "hoarowl" and not safe_cell(level, cell, false):
		# Below the perch's stone (and any stone under it): the next floor.
		var y := cell.y + 1
		while y < level.height and LevelData.is_solid(level.tile(cell.x, y)):
			y += 1
		return y < level.height and safe_cell(level, Vector2i(cell.x, y), true)
	return safe_cell(level, cell, false)


static func safe_cell(level: RefCounted, cell: Vector2i, flying := false) -> bool:
	## Ground an elite may stand on: 5 flat floor tiles each side, and no
	## pit, lava, spikes or deep water within 4 tiles.
	var fy := cell.y + 1
	if flying:
		# A flier: judge the floor under it.
		fy = -1
		for y in range(cell.y + 1, mini(cell.y + 7, level.height)):
			if LevelData.is_solid(level.tile(cell.x, y)):
				fy = y
				break
		if fy < 0:
			return false
	for dx in range(-5, 6):
		var x := cell.x + dx
		if x < 0 or x >= level.width:
			return false
		if not LevelData.is_solid(level.tile(x, fy)) or LevelData.is_solid(level.tile(x, fy - 1)):
			return false
	for dx in range(-4, 5):
		for y in range(fy - 4, fy + 2):
			var t: int = level.tile(cell.x + dx, y)
			if t == LevelData.LAVA or t == LevelData.SPIKES_UP or t == LevelData.SPIKES_DOWN or level.is_deep(cell.x + dx, y):
				return false
	return true


# ---------------------------------------------------------------- stand-in drawing
# Until W6b's frames exist, each kind draws itself with these (local space,
# feet at the origin; cel look: a dark outline, flat fill, a hard shade).

func o_circle(c: Vector2, r: float, fill: Color, ol := 2.0) -> void:
	draw_circle(c, r + ol, pc(OUTLINE))
	draw_circle(c, r, pc(fill))


func o_poly(pts: PackedVector2Array, fill: Color, ol := 2.0) -> void:
	if pts.size() < 3:
		return
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var grown := PackedVector2Array()
	for p in pts:
		grown.append(p + (p - c).normalized() * ol)
	draw_colored_polygon(grown, pc(OUTLINE))
	draw_colored_polygon(pts, pc(fill))


func o_line(a: Vector2, b: Vector2, w: float, fill: Color) -> void:
	draw_line(a, b, pc(OUTLINE), w + 3.0)
	draw_circle(a, (w + 3.0) * 0.5, pc(OUTLINE))
	draw_circle(b, (w + 3.0) * 0.5, pc(OUTLINE))
	draw_line(a, b, pc(fill), w)
	draw_circle(a, w * 0.5, pc(fill))
	draw_circle(b, w * 0.5, pc(fill))


func ellipse(c: Vector2, rx: float, ry: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func skull(c: Vector2, r: float, f: int, bone := Color("efe6d2")) -> void:
	## A chibi skull facing f: a big round cranium, a jaw, two dark sockets.
	o_circle(c, r, bone)
	o_poly(PackedVector2Array([c + Vector2(-r * 0.55 + f * 2.0, r * 0.55), c + Vector2(r * 0.55 + f * 2.0, r * 0.55),
			c + Vector2(r * 0.45 + f * 2.0, r * 1.05), c + Vector2(-r * 0.45 + f * 2.0, r * 1.05)]), bone, 1.5)
	draw_circle(c + Vector2(f * r * 0.2 - r * 0.32, r * 0.05), r * 0.26, pc(Color("2a2030")))
	draw_circle(c + Vector2(f * r * 0.2 + r * 0.36, r * 0.05), r * 0.26, pc(Color("2a2030")))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.45), r * 0.22, pc(Color(1, 1, 1, 0.55)))


# ---------------------------------------------------------------- v3 helpers

func floor_strip(p: Vector2, max_tiles := 40) -> Vector2:
	## The floor run p stands on, as (left x, right x) in px: the cells either
	## side whose floor is there (solid or a ledge) and that aren't walls.
	if level == null:
		return Vector2(p.x - 1.0e5, p.x + 1.0e5)
	var cx := floori(p.x / TILE)
	var fy := floori((p.y + 1.0) / TILE)
	var x0 := cx
	var x1 := cx
	for i in max_tiles:
		var nx := x0 - 1
		if LevelData.is_solid(level.tile(nx, fy - 1)) or not LevelData.is_floor(level.tile(nx, fy)):
			break
		x0 = nx
	for i in max_tiles:
		var nx := x1 + 1
		if LevelData.is_solid(level.tile(nx, fy - 1)) or not LevelData.is_floor(level.tile(nx, fy)):
			break
		x1 = nx
	return Vector2(x0 * TILE, (x1 + 1) * TILE)


func near_floor(pl: Node2D, dy := 24.0) -> bool:
	## Wick's feet on (about) the same floor as its own.
	return pl != null and absf(pl.position.y - position.y) < dy


func clock() -> float:
	## The feature clock (world.ftime; contract §1: timed things read it).
	var ft = world.get("ftime") if world != null else null
	return float(ft) if ft != null else t


func tick_len() -> float:
	## World 4's tick (level.tick, 0.536 s on every difficulty).
	var tk = level.get("tick") if level != null else null
	return float(tk) if tk != null and float(tk) > 0.0 else 0.536


func art_points(path: String, key := "eyes", fallback: Array = []) -> Array:
	## Points on the frame on show from an art points file (A3's
	## points_monsters3.json: {frame: {key: [x, y] or [[x, y], ...]}}, frame
	## units), in world space; fallback with no frames, no file or no entry.
	if frames.is_empty() or frame_name == "":
		return fallback
	if not _art_pts.has(path):
		var d = {}
		if FileAccess.file_exists(path):
			var j = JSON.parse_string(FileAccess.get_file_as_string(path))
			if j is Dictionary:
				d = j
		_art_pts[path] = d
	var fr = (_art_pts[path] as Dictionary).get(frame_name)
	if not (fr is Dictionary) or not (fr as Dictionary).has(key):
		return fallback
	var v = fr[key]
	var out := []
	if v is Array and v.size() == 2 and not (v[0] is Array):
		out.append(frame_point(Vector2(float(v[0]), float(v[1]))))
	elif v is Array:
		for q in v:
			if q is Array and q.size() == 2:
				out.append(frame_point(Vector2(float(q[0]), float(q[1]))))
	return out if not out.is_empty() else fallback


func lost_in_pit() -> bool:
	## Fallen out of the level, or its middle in deep water or lava: gone
	## (a kill, how "pit", as a Dripkin that falls).
	if level == null:
		return false
	if position.y > level.height * TILE + 32.0:
		return true
	var c := center()
	var cx := floori(c.x / TILE)
	var cy := floori(c.y / TILE)
	var tl: int = level.tile(cx, cy)
	return (tl == LevelData.WATER or tl == LevelData.LAVA) and level.hurts_at(cx, cy, rect())


func slick_under() -> bool:
	## Standing on wax-ice or a frosted ledge (features.slick_at, else the tile).
	var p := position + Vector2(0, 2.0)
	if world != null and world.get("features") != null and world.features.has_method("slick_at"):
		return bool(world.features.slick_at(p))
	return level != null and LevelData.is_slick(level.tile(floori(p.x / TILE), floori(p.y / TILE)))


func pop_word(text: String, at := Vector2.INF) -> void:
	## A small word over it ("Unwound!").
	if world != null and world.get("floaters") != null:
		world.floaters.add(center() + Vector2(0, -size.y * 0.5 - 12.0) if at == Vector2.INF else at, 0.0, "text", 0, text)


func escape_tell(escape_px: float) -> float:
	## The escape formula's least tell (spec §4.1): 0.35 + escape_px / 205.
	return 0.35 + escape_px / 205.0


# ---------------------------------------------------------------- v3 stand-ins (TriBatch)
# The v3 kinds draw their stand-ins (until a kind's frames exist) into one
# TriBatch in local space, then flush it once: a dark outline, a flat fill,
# a hard shade (the cel look), coloured by pc() (tint, hit flash, Hushed).

func cel_circle(tb: RefCounted, c: Vector2, r: float, fill: Color, ol := 2.0, seg := 14) -> void:
	if ol > 0.0:
		tb.circle(c, r + ol, pc(OUTLINE), seg)
	tb.circle(c, r, pc(fill), seg)


func cel_ellipse(tb: RefCounted, c: Vector2, rx: float, ry: float, fill: Color, ol := 2.0, seg := 16) -> void:
	if ol > 0.0:
		tb.ellipse(c, rx + ol, ry + ol, pc(OUTLINE), seg)
	tb.ellipse(c, rx, ry, pc(fill), seg)


func cel_poly(tb: RefCounted, pts: PackedVector2Array, fill: Color, ol := 2.0) -> void:
	## A convex shape with its outline grown from its middle.
	if pts.size() < 3:
		return
	if ol > 0.0:
		var c := Vector2.ZERO
		for p in pts:
			c += p
		c /= pts.size()
		var grown := PackedVector2Array()
		for p in pts:
			grown.append(p + (p - c).normalized() * ol)
		tb.convex(grown, pc(OUTLINE))
	tb.convex(pts, pc(fill))


func cel_line(tb: RefCounted, a: Vector2, b: Vector2, w: float, fill: Color, ol := 1.5) -> void:
	## A rounded stroke (a bone, a leg, a rod).
	if ol > 0.0:
		tb.line(a, b, w + ol * 2.0, pc(OUTLINE))
		tb.circle(a, w * 0.5 + ol, pc(OUTLINE), 8)
		tb.circle(b, w * 0.5 + ol, pc(OUTLINE), 8)
	tb.line(a, b, w, pc(fill))
	tb.circle(a, w * 0.5, pc(fill), 8)
	tb.circle(b, w * 0.5, pc(fill), 8)


func cel_eyes(tb: RefCounted, pts: Array, r := 2.0, col := Color("fff4cf")) -> void:
	## Two small bright eyes (drawn on the body; the glow's glints are separate).
	for p in pts:
		tb.circle(p, r + 1.0, pc(Color("1c1830")), 8)
		tb.circle(p, r, pc(col), 8)


func glow_eyes(tb: RefCounted, pts: Array, col: Color, r := 3.0) -> void:
	## Eyes in the glow layer (spec §4.1 rule 4, decisions: r >= 3 px at alpha
	## >= 0.9), so a monster in the dark still shows them. Dark when Hushed.
	if has_omen("hushed"):
		return
	r = maxf(r, EYE_R)
	eye_r_drawn = r
	for p in pts:
		tb.circle(p, r + 2.5, Color(col, 0.22), 10)
		tb.circle(p, r, Color(col.lightened(0.3), 0.95), 10)
