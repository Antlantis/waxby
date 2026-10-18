extends "res://scripts/elites.gd"
## What v3's bosses share (spec §5.1, contract §6.4), and a small parts rig.
## Mother Gravebough (rootmother_boss.gd) and the Tinker of Hours
## (tinker_boss.gd) extend this; it extends elites.gd, as the Snuffer does,
## for tell(), cd(), spd(), frame_point(), sfx() and tell_sfx().
##
## The v2 interface (frozen): signal woke, boss_info(), reset_fight(),
## touch_damage(), dmg(what), boss_id, boss_name, boss_title. v3 adds
## is_open(), configure(opts), window_bonus() and reset_fight(keep_phase);
## boss_info() carries "segments": [0.65, 0.30] for the three-part bar.
##
## The shared rules:
##   Phases    PHASES [0.65, 0.30]. A blow never crosses a threshold: it
##             clamps there, the window ends, and the boss roars into the
##             next phase (ROAR s; world.boss_phase barks "<id>_p<n>").
##   Windows   one named opening per boss (open_window). Inside it a hit on
##             the weak spot lands in full and the window's first stomp
##             deals STOMP_MULT; anything else chips CHIP (10%), and so does
##             every later stomp in that window (a stomp bounces Wick straight
##             back onto a target on the floor about every 0.24 s with no
##             input: at 3x each, one window would take a whole phase).
##             Window lengths never scale with difficulty; Tollbreaker adds
##             window_bonus() (+0.4 s).
##   Stagger   STAGGER (30%) of max life inside one window, once a phase: a
##             STAGGER_BONUS (10%) bonus, the window ends, the boss's banner
##             (on_stagger). Until the phase's stagger a window's blows are cut
##             to reach 30% and no further, and the bonus stops STAGGER_ROOM
##             (5%) above the phase's line: every 35% phase takes two windows
##             at least, and a chip after a stagger never ends one (int2 review).
##   Mercy     one wax stub, once, in the last phase, with Wick under 25%.
##   Adds      spawn_add(): not ordinary, never respawn, half XP, no items
##             (elites.as_add), and they die when the boss roars and when it
##             falls (kill_adds).
##   Retries   reset_fight(): the door opens, full life, phase 1, asleep, and
##             the subclass puts every arena prop back (_reset_arena).
##   Rush      configure({rush, mods, hp_mult, area}) before _ready: rush
##             skips no story here (the World does), multiplies the life by
##             the boss's own RUSH_K and the mode's hp_mult, and hands mods
##             to boss_mods.gd (BR) when it's there.
##
## Blows go through strike(key, rect, from_x): world.hurt_player with the
## move id for the playlog ("rootmother:sweep_low"), and a report of what
## happened (missed, hurt, guarded, or a Knight's Perfect Guard: the kit
## doesn't stagger a boss itself, so a boss answers one on its own).
## struck(rect, key) is the other way round: did the hero's swing, shot,
## wave or stomp reach this rect this tick (a bell, a seed, a decoy)?
##
## The parts rig: add_part() makes a child Sprite2D for a part texture
## (art/enemies/<part>.svg, 2 units a pixel) pivoted at a point of its
## frame; place_part() puts its pivot at a world point, turned and mirrored
## with a facing (A4's rule: facing left, scale.x < 0 and the angle
## negated); chain() walks a pose's [[part, angle]] list joint to joint.
## look_face is the way the sprite faces (normally facing): a boss whose
## blows must read as from behind (the Tinker's spring) turns `facing` for
## the rules and keeps look_face for the look.
##
## Drawing: tells go in the glow layer through one TriBatch (elites.gtb())
## and glow.draw_rect (contract §1: no draw_circle / polygon / polyline).

signal woke

const Arena := preload("res://scripts/boss_arena.gd")
const PHASES := [0.65, 0.30]
const CHIP := 0.10
const STAGGER := 0.30
const STAGGER_BONUS := 0.10
const STAGGER_ROOM := 0.05          # the stagger's bonus stops this far above the phase's line
const ROAR := 1.2
const MERCY_BELOW := 0.25
const STOMP_MULT := 3.0
const STOMPS_FULL := 1              # stomps a window pays STOMP_MULT for (later ones chip)
const PART_SCALE := 0.25            # a part's texture is twice its frame: 2 frame units a pixel
const BOSS_MODS := "res://scripts/boss_mods.gd"
const WAKE_IN := 40.0               # px into the arena past its door's wall (the left, or door_side's) that wakes it

var boss_id := ""
var boss_name := ""
var boss_title := ""
var move_id := ""                   # the blow on its way (the World reads source.move_id for the playlog)
var state := "sleep"
var timer := 0.0
var phase := 1
var arena_left := 0.0
var arena_right := 0.0
var floor_y := 0.0
var door: Array[Vector2i] = []
var door_side := -1                 # the door's wall: -1 left, 1 right (boss_arena.gd find)
var home := Vector2.ZERO
var anchors: Array = []             # the arena's `+` cells (Vector2i), sorted by (x, y)
var rush := false
var configured := {}                # what configure() was handed
var window_t := 0.0                 # seconds left of the open window (0: shut)
var window_len := 0.0               # the open window's length (with Tollbreaker's bonus)
var windows_opened := 0             # (tests)
var moves_used := {}                # move id -> times used (tests: every move in a 300 s sim)
var blows := {}                     # move id -> blows that reached Wick, hurt or guarded (tests)
var window_stomps := 0              # stomps on the target in the open window
var look_face := -1                 # the way the sprite faces
var look_locked := false            # look_face doesn't follow facing (a pose of its own)
var _window_dmg := 0.0
var _stagger_phase := 0
var _mercy := false
var _adds: Array = []
var _struck := {}                   # struck() key -> the attack id that last reached it


func _init() -> void:
	kind = "boss"
	item_chance = 0.0
	relic_chance = 0.0
	stompable = false
	ordinary = false
	flier = true                    # it poses itself: no tile physics (not even stunned)
	anchor = Vector2(192, 368)


func _ready() -> void:
	super()
	home = position
	floor_y = position.y
	if level != null:
		var a := Arena.find(level, position)
		arena_left = float(a["left"])
		arena_right = float(a["right"])
		door.assign(a["door"])
		door_side = int(a["side"])
		for e in level.entities:
			if str(e.get("kind", "")) != "anchor":
				continue
			var c: Vector2i = e["cell"]
			var x := (c.x + 0.5) * TILE
			if x > arena_left and x < arena_right and (c.y + 1) * TILE <= floor_y + 1.0:
				anchors.append(c)
		anchors.sort_custom(func(p, q): return p.x < q.x or (p.x == q.x and p.y < q.y))
	look_face = facing


# ---------------------------------------------------------------- the boss interface

func boss_info() -> Dictionary:
	return {"id": boss_id, "name": boss_name, "title": boss_title, "frac": hp / maxf(max_hp, 1.0),
			"phases": PHASES, "segments": PHASES, "awake": state != "sleep" and alive}


func is_open() -> bool:
	## True only inside the boss's window.
	return alive and window_t > 0.0


func window_bonus() -> float:
	## Tollbreaker: every window this much longer (v2's pattern).
	if world == null or world.get("player") == null or not (world.player.stats is Dictionary):
		return 0.0
	var flags = world.player.stats.get("flags", {})
	return float(flags.get("tollbreaker_window", 0.0)) if flags is Dictionary else 0.0


func configure(opts: Dictionary) -> void:
	## A mode's boss (the Waxworks, a Descent boss depth), before _ready:
	## {rush: bool, mods: Array, hp_mult: float, area: int}.
	configured = opts.duplicate()
	rush = bool(opts.get("rush", false))
	if opts.has("area") and int(opts["area"]) > 0 and int(opts["area"]) != area and world != null:
		var wn = world.get("world_n")
		setup_stats(int(opts["area"]), str(world.get("diff")), str(world.get("strength")), int(wn) if wn != null else 0)
	var k := float(opts.get("hp_mult", 1.0))
	if rush:
		k *= rush_k()
	max_hp *= k
	hp = max_hp
	var mods = opts.get("mods", [])
	if mods is Array and not (mods as Array).is_empty() and ResourceLoader.exists(BOSS_MODS):
		var bm = load(BOSS_MODS)
		for m in (bm as Script).get_script_method_list():
			if m["name"] == "apply":
				bm.apply(self, mods)
				break


func rush_k() -> float:
	## The boss's own rush life (spec §5.6: Gravebough 0.9; the Tinker 1.42, v1.0.1).
	return float(own_const("RUSH_K", 1.0))


func own_const(name: String, fallback = null):
	## A constant of the boss's own script (the base can't name a subclass's).
	return (get_script() as Script).get_script_constant_map().get(name, fallback)


func dmg(what := "touch") -> float:
	## One blow's damage before damage reduction: MOVES[what] (base at area
	## 1, Dusk) x dmg_mult, or the touch.
	var moves: Dictionary = own_const("MOVES", {})
	var base := float(moves.get(what, base_dmg)) if what != "touch" else base_dmg
	return base * dmg_mult


func reset_fight(keep_phase := false) -> void:
	## Wick was snuffed: asleep again at full life, the door open, the arena
	## as it was (keep_phase is the Hush's; these bosses never checkpoint).
	if not alive:
		return
	if world != null and level != null:
		Arena.unseal(world, level, door)
	hp = max_hp
	phase = 1
	state = "sleep"
	timer = 0.0
	window_t = 0.0
	window_len = 0.0
	_window_dmg = 0.0
	_stagger_phase = 0
	_mercy = false
	move_id = ""
	position = home
	velocity = Vector2.ZERO
	status.clear()
	flash = 0.0
	fade = 1.0
	look_locked = false
	kill_adds()
	if _mods_rt() != null:
		_mods_rt().reset()
	_reset_arena(keep_phase)


func _reset_arena(_keep_phase: bool) -> void:
	## The subclass puts every prop back.
	pass


# ---------------------------------------------------------------- waking

func wake_check(player: Node2D) -> bool:
	## Asleep until Wick is well inside the arena; then the door seals.
	if player == null or not player.alive:
		return false
	var px: float = player.position.x
	if not Arena.past_door(door_side, arena_left, arena_right, px, WAKE_IN) or px >= arena_right or px <= arena_left \
			or absf(player.position.y - floor_y) > 400.0:
		return false
	if level != null:
		Arena.seal(world, level, door)
	woke.emit()
	return true


# ---------------------------------------------------------------- being hit

func weak_hit(_h: Dictionary) -> bool:
	## Did this blow land on the window's target (the subclass's rect() is
	## the target while the window is open, so every blow that reaches it
	## is)? A subclass may refuse some.
	return true


func can_hurt(_h: Dictionary) -> bool:
	## False while untouchable (a roar, Midnight).
	return true


func hit(h: Dictionary) -> bool:
	if not alive or state == "sleep" or state == "dead":
		return false
	if not can_hurt(h):
		return false
	if _ward_blocks(h):
		return false
	var how := str(h.get("how", "slash"))
	if how == "shock" or how == "bump":
		return false
	var bm = _mods_rt()
	if bm != null and bm.blocks(h):
		return false   # a Warded Wax mote took it (the Waxworks' Tweak, boss_mods.gd)
	var amount := float(h.get("amount", 0.0))
	var open := is_open() and weak_hit(h)
	if open and how == "stomp":
		# The window's first stomp is the big play; the bounce that follows
		# lands on the same target again and again, so the rest chip.
		window_stomps += 1
		if window_stomps <= STOMPS_FULL:
			amount *= STOMP_MULT
		else:
			open = false
	elif open and bool(h.get("stomp_born", false)) and window_stomps > STOMPS_FULL:
		# What a bounce throws off (the Bellfounder's Aftershock waves) is
		# the bounce's, and chips as it does: one press never takes a phase.
		open = false
	if not open:
		amount *= CHIP
		h["chip"] = true
	elif _stagger_phase < phase:
		# A window takes at most STAGGER of her life before the stagger ends
		# it, so no phase (35%) falls to one window, whatever lands at once.
		amount = minf(amount, maxf(STAGGER * max_hp - _window_dmg, 0.0))
	var floor_hp := phase_floor()
	var clamped := false
	if phase <= PHASES.size() and hp - amount <= floor_hp:
		amount = maxf(hp - floor_hp, 0.0)
		clamped = true
	hp = maxf(hp - amount, 0.0)
	last_damage = amount
	flash = 1.0
	hp_bar = 2.5
	if open:
		_window_dmg += amount
	if world != null:
		world._sfx("boss_hit" if open else "clang")
		world.shake = maxf(float(world.shake), 6.0 if open else 2.0)
	var frac := hp / maxf(max_hp, 1.0)
	on_hurt(h, amount, open, frac)
	if hp <= 0.0:
		close_window()
		kill_adds()
		_kill(h)
		state = "dead"
		timer = 0.0
		death_time = 0.0
		on_death()
		return true
	if clamped:
		phase += 1
		close_window()
		kill_adds()
		if world != null:
			world.shake = 8.0
			world.boss_phase(self, phase)
		on_phase(phase)
		return true
	if open and _window_dmg >= STAGGER * max_hp - 0.5 and _stagger_phase < phase:
		_stagger_phase = phase
		# The bonus never takes her closer than STAGGER_ROOM to the phase's
		# line (a stagger left at 1 HP over it let the next chip end the phase).
		var bonus := minf(STAGGER_BONUS * max_hp, hp - phase_floor() - STAGGER_ROOM * max_hp)
		if bonus > 0.0:
			hp -= bonus
		close_window()
		on_stagger()
	return true


func phase_floor() -> float:
	## The life this phase can't be hit below.
	if phase <= PHASES.size():
		return max_hp * float(PHASES[phase - 1])
	return 0.0


func on_hurt(_h: Dictionary, _amount: float, _open: bool, _frac: float) -> void:
	pass


func on_phase(_p: int) -> void:
	pass


func on_stagger() -> void:
	pass


func on_death() -> void:
	pass


func open_window(sec: float) -> void:
	## The window: sec (its length never scales with difficulty) plus
	## Tollbreaker's bonus.
	window_len = sec + window_bonus()
	window_t = window_len
	_window_dmg = 0.0
	window_stomps = 0
	windows_opened += 1


func close_window() -> void:
	window_t = 0.0


func _window_over() -> void:
	## The window ran out (the subclass moves on in think).
	pass


# ---------------------------------------------------------------- the step

func _mods_rt() -> RefCounted:
	## The Waxworks' boss Tweaks' runtime (boss_mods.gd: its meta), or null.
	return get_meta("boss_mods") if has_meta("boss_mods") else null


func draw_glow(glow: Node2D) -> void:
	super(glow)
	var bm = _mods_rt()
	if bm != null and alive:
		bm.draw_glow(glow)


func step(dt: float, player: Node2D) -> void:
	var bm = _mods_rt()
	if bm != null:
		bm.step(dt, player)
	if window_t > 0.0 and alive:
		# Counted here, not in think(): a stun or a slow never stretches it.
		window_t = maxf(window_t - dt, 0.0)
		if window_t <= 0.0:
			_window_over()
	if not look_locked:
		look_face = facing
	super(dt, player)
	if sprite:
		sprite.scale.x = absf(sprite.scale.x) * (1.0 if look_face > 0 else -1.0)


func _stunned(_dt: float) -> void:
	## A boss poses itself: a stun (Hoarfrost's 0.3 s) only holds it still.
	velocity = Vector2.ZERO


func frame_point(p: Vector2) -> Vector2:
	## A point on the frame on show (frame units, drawn facing right) in the
	## world, mirrored by the way the sprite faces.
	var off := (p - anchor) * 0.5 * scale_mult
	off.x *= 1.0 if look_face > 0 else -1.0
	return position + (sprite.position if sprite else Vector2.ZERO) + off


func used(move: String) -> void:
	moves_used[move] = int(moves_used.get(move, 0)) + 1


func mercy_check(player: Node2D) -> void:
	## One wax stub in the last phase, with Wick under 25%.
	if phase < 3 or _mercy or player == null or not player.alive or world == null:
		return
	if player.life_frac() >= MERCY_BELOW:
		return
	_mercy = true
	var x := clampf(player.position.x, arena_left + 24.0, arena_right - 24.0)
	var p: Dictionary = world._add_pickup("wax", Vector2(x, maxf(player.position.y - 120.0, floor_y - 300.0)))
	p["loose"] = true
	p["vel"] = Vector2.ZERO


# ---------------------------------------------------------------- blows

func strike(key: String, r: Rect2, from_x: float, kind_ := "hit", opts := {}) -> int:
	## A blow on Wick if r reaches him: 0 missed (or he's untouchable), 1
	## hurt, 2 blocked, 3 a Knight's Perfect Guard.
	if world == null:
		return 0
	var pl: Node2D = world.player
	if pl == null or not pl.alive or not r.intersects(pl.rect()):
		return 0
	if float(pl.invuln) > 0.0 or bool(pl.dash_flags.get("invuln", false)):
		return 0
	var pg0 := _pg_count()
	var o := {"move": "%s:%s" % [boss_id, key]}
	o.merge(opts, true)
	move_id = key
	var ok: bool = world.hurt_player(dmg(key), from_x, kind_, self, o)
	blows[key] = int(blows.get(key, 0)) + 1
	if _pg_count() > pg0:
		return 3
	return 1 if ok else 2


func strike_circle(key: String, c: Vector2, rad: float, from_x: float, opts := {}) -> int:
	## As strike(), for a round thing (a bob, a cog): its circle against his box.
	if world == null or world.player == null:
		return 0
	var pr: Rect2 = world.player.rect()
	var near := Vector2(clampf(c.x, pr.position.x, pr.end.x), clampf(c.y, pr.position.y, pr.end.y))
	if near.distance_to(c) > rad:
		return 0
	return strike(key, pr, from_x, "hit", opts)


func _pg_count() -> int:
	if world == null or world.get("kit") == null:
		return -1
	var n = world.kit.get("perfect_guards")
	return int(n) if n != null else -1


func struck(r: Rect2, key: String, shots_pass := false, waves_pass := false) -> String:
	## What of the hero's reached r this tick: "slash" (a live swing, once a
	## swing), "shot" (a hero shot inside it: spent there), "wave" (a hero
	## wave, once a wave), "stomp" (he came down on it: he bounces), or "".
	## shots_pass / waves_pass: shots and waves go through it (a frosted bell).
	if world == null:
		return ""
	var pl: Node2D = world.player
	if pl == null or not pl.alive:
		return ""
	if pl.attack_time >= 0.0 and pl.attack_time <= pl.ATTACK_ACTIVE and int(_struck.get(key, -1)) != int(pl.attack_id):
		var ar: Rect2 = pl.attack_rect()
		if ar.size.x > 0.0 and ar.intersects(r):
			_struck[key] = int(pl.attack_id)
			return "slash"
	if not shots_pass:
		for s in world.shots:
			if str(s.get("owner", "")) != "player" or float(s.get("life", 0.0)) <= 0.0:
				continue
			if r.grow(float(s.get("radius", 6.0))).has_point(s["pos"]):
				s["life"] = 0.0
				return "shot"
	if not waves_pass:
		var tag := "struck_" + key
		for hz in world.hazards:
			if str(hz.get("owner", "")) != "player" or str(hz.get("kind", "")) != "wave" or hz.has(tag):
				continue
			if float(hz.get("delay", 0.0)) <= 0.0 and float(hz.get("life", 0.0)) > 0.0 and (hz["rect"] as Rect2).intersects(r):
				hz[tag] = true
				return "wave"
	if pl.rect().intersects(r) and pl.falling_onto(r) and not pl.on_floor:
		if "last_stomp_boss" in world:
			world.last_stomp_boss = true
		pl.bounce(pl.jump_held())
		pl.position.y = r.position.y
		return "stomp"
	return ""


# ---------------------------------------------------------------- adds

func spawn_add(k: String, pos: Vector2, opts := {}) -> Node2D:
	## A summoned monster (spec §4.1 rule 7): half XP, no items, no respawn.
	if world == null or not world.has_method("spawn_enemy"):
		return null
	var e: Node2D = world.spawn_enemy(k, pos, opts)
	if e != null:
		if e.has_method("as_add"):
			e.as_add()
		e.active = true
		_adds.append(e)
	return e


func adds_alive(k := "") -> int:
	var n := 0
	for e in _adds:
		if is_instance_valid(e) and e.alive and (k == "" or str(e.kind) == k):
			n += 1
	return n


func kill_adds() -> void:
	## They die when the boss roars into a new phase (and on a retry).
	for e in _adds:
		if is_instance_valid(e) and e.alive:
			if world != null and world.get("glow") != null:
				world.glow.burst(e.center(), 10, Color(0.85, 0.8, 0.7, 0.9), 120.0, 0.4, 0.0, 2.2)
			e.alive = false
			e.gone = true
	_adds.clear()


# ---------------------------------------------------------------- the parts rig

func add_part(tex: String, pivot_units: Vector2, behind := false) -> Sprite2D:
	## A child sprite for a part (art/enemies/<tex>.svg), pivoted at a point
	## of its frame (frame units). Hidden until placed.
	var s := Sprite2D.new()
	s.centered = false
	var p := "res://art/enemies/%s.svg" % tex
	if ResourceLoader.exists(p):
		s.texture = load(p)
	s.offset = -pivot_units * 2.0
	s.scale = Vector2(PART_SCALE, PART_SCALE)
	s.visible = false
	add_child(s)
	if behind:
		move_child(s, 0)
	return s


func place_part(s: Sprite2D, at: Vector2, angle_deg := 0.0, face := 1, thick := 1.0, sc := 1.0) -> void:
	## Its pivot at the world point at, turned by angle (degrees, drawn facing
	## right; mirrored and negated facing left), thick across its length.
	s.position = at - position
	s.scale = Vector2(PART_SCALE * sc * (1.0 if face > 0 else -1.0), PART_SCALE * sc * thick)
	s.rotation = deg_to_rad(angle_deg) * (1.0 if face > 0 else -1.0)
	s.visible = true


static func chain(start: Vector2, links: Array, face: int, length_units: float) -> Array:
	## A pose's chain of [part, angle] from its first pivot: [[part, pivot
	## (world), angle], ...] and, last, the end point [0, end, 0].
	var out := []
	var p := start
	for c in links:
		var a := float(c[1])
		out.append([int(c[0]), p, a])
		p += Vector2(cos(deg_to_rad(a)) * face, sin(deg_to_rad(a))) * (length_units * 0.5)
	out.append([0, p, 0.0])
	return out


static func dash_line(tb: RefCounted, a: Vector2, b: Vector2, w: float, col: Color, dash := 10.0, gap := 7.0) -> void:
	## A dashed line into a TriBatch.
	var d := b - a
	var n := d.length()
	if n < 0.5:
		return
	var u := d / n
	var s := 0.0
	while s < n:
		var e := minf(s + dash, n)
		tb.line(a + u * s, a + u * e, w, col)
		s = e + gap


static func band_fill(tb: RefCounted, r: Rect2, col: Color, edge: Color) -> void:
	## A danger band: filled at col's alpha, with a dashed edge top and bottom.
	tb.rect(r, col)
	dash_line(tb, r.position, Vector2(r.end.x, r.position.y), 2.0, edge)
	dash_line(tb, Vector2(r.position.x, r.end.y), r.end, 2.0, edge)


func glow_light(p: Vector2, r: float, s := 0.8, grp := "tell", tint := Color(0, 0, 0, 0)) -> Dictionary:
	## A light dict for lights() (grp: the packer's group).
	var d := {"p": p, "r": r, "s": s, "kind": grp, "gameplay": false}
	if tint.a > 0.0:
		d["tint"] = tint
	return d


func ceiling_at(x: float, from_y: float) -> float:
	## The underside of the roof over x, looking up from from_y.
	if level == null:
		return from_y - 320.0
	var tx := floori(x / TILE)
	var ty := floori((from_y - 1.0) / TILE)
	while ty > 0 and not LevelData.is_solid(level.tile(tx, ty - 1)):
		ty -= 1
	return float(ty * TILE)


func surface_below(x: float, from_y: float) -> float:
	## The first floor (solid or a ledge) at or under from_y at x (its top).
	if level == null:
		return floor_y
	var tx := floori(x / TILE)
	var ty := maxi(floori(from_y / TILE), 0)
	while ty < level.height:
		if LevelData.is_floor(level.tile(tx, ty)):
			return float(ty * TILE)
		ty += 1
	return floor_y


func cell_px(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * TILE, (c.y + 0.5) * TILE)


static func seg_hits_rect(a: Vector2, b: Vector2, width: float, r: Rect2) -> bool:
	## Does a segment this wide touch r? (world.gd's, for a blade.)
	var g := r.grow(width * 0.5)
	if g.has_point(a) or g.has_point(b):
		return true
	var c := [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


func edge_marker(tb: RefCounted, p: Vector2, col: Color) -> bool:
	## A chevron at the view's edge pointing at p when p is off the screen (a
	## tell up out of the camera's reach: a high socket, the XII bell), kept
	## clear of the HUD's top strip and corners. True when it drew one.
	if world == null or not world.has_method("view_rect"):
		return false
	var v: Rect2 = world.view_rect()
	if v.grow(-10.0).has_point(p):
		return false
	var at := Vector2(clampf(p.x, v.position.x + 160.0, v.end.x - 90.0), clampf(p.y, v.position.y + 30.0, v.end.y - 150.0))
	var d := (p - at)
	if d.length() < 1.0:
		return false
	d = d.normalized()
	var o := d.orthogonal()
	var k := 0.5 + 0.5 * sin(t * 8.0)
	tb.circle(at, 13.0 + 2.0 * k, Color(col, 0.22), 16)
	for i in 2:
		var tip := at + d * (7.0 - 7.0 * i)
		tb.line(tip, tip - d * 9.0 + o * 8.0, 3.0, Color(col, 0.95 - 0.35 * i))
		tb.line(tip, tip - d * 9.0 - o * 8.0, 3.0, Color(col, 0.95 - 0.35 * i))
	return true
