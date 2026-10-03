extends "res://scripts/kits/kit.gd"
## Candleknight: the sword (the player's own swing; a third quick cut is a
## Finisher), Grace, and the Aegis on the Special button:
##   - hold still, or in the air: Guard. Blocks frontal contact, shots and
##     shockwaves (never pits, lava, spikes, fire or smoke, nor a foe
##     dropping from overhead); each block costs Grace, and a
##     broken guard staggers him. A hit in the first 0.18 s is a Perfect
##     Guard: free, +15 Grace, the attacker staggered, a bell ping.
##   - hold a direction on the ground: Shield Rush, 96 px in 0.16 s through
##     foes, front invulnerable (which counts as a Perfect Guard window too),
##     stopping at walls and ledge edges; held on, it flows into Guard.
## Ledge Grab and his longer coyote time live in player.gd (quirk ledge_grab).
##
## v3: the root runs to 7 ranks (and an 8th for of the Keeper); Bastion
## (Guard T4) cheapens blocks, Sanctuary (Guard T5) makes a Perfect Guard
## stun every foe within 90 px, Judgment (Blade T5) makes Finishers crit
## and hit harder. A beam (a hazard with a segment: the Refractor's, the
## Saint's, the Hush's Gaze) is guarded by its line, not its source's body:
## it meets the shield when it comes in within GUARD_ARC of where he faces,
## and a Perfect Guard sends it back along its line to where it came from
## (REFLECT_COEF x basic to every foe on it, and the source's on_reflected).
## A beam coming in steeper than GUARD_ARC (straight down or up) is past the
## shield, Unbroken Vigil or not, like any blow from overhead. A press on a
## vine lets go of it (world.gd), and while the guard is up he catches none
## (holding_special): it plays as in the air.

const PG_WINDOW := 0.18          # a Perfect Guard: a hit this soon after raising the shield
const FINISH_GAP := 0.5          # a 3rd cut this soon after the 2nd is a Finisher
const FINISH_COEF := 1.6
const FINISH_BOX := Vector2(48, 38)
const FINISH_KNOCK := 260.0
const RUSH_DIST := 96.0
const RUSH_TIME := 0.16
const RUSH_KNOCK := 280.0
const GUARD_MOVE := 0.4          # ground speed while guarding (75% with Unbroken Vigil)
const BREAK_STAGGER := 0.5
const BLOCK_MIN := 5.0
const CONTACT_CD := 0.5          # a foe (or a wave) already blocked is free this long
const PG_STUN := 1.0             # a Perfect Guard staggers the attacker this long...
const PG_SHOVE := 260.0          # ...knocked back (about 38 px)
# Never blocked: the floor, what falls from above (a shield faces forward),
# and what a shield can't stop at all (fire underfoot, smoke).
const UNBLOCKABLE := ["spikes", "lava", "pit", "water", "douse", "drain", "latch", "rubble", "drip", "drop",
		"fire", "smoke",
		# v3: what comes from below (a Hushgrasp, a Rootling's pop, a spike
		# line) or above (an icicle, the Hush's Snuff), and the Deep Quiet.
		"grasp", "snuff", "pop", "icicle", "spike_line", "deep_quiet"]
const OVERHEAD_SLACK := 6.0      # how far a foe dropping on his head may already overlap it (px)
const GOLD := Color("f2c75a")
# Grace keeps its 4/s while the shield is up (the tuning knob; false pauses
# it, as W1 first had it; spec.md's Grace is a plain 4/s).
const REGEN_WHILE_GUARDING := true
# On Dusk a block costs this share of its usual Grace. Integration sim
# (tools/shot_kits_grace.gd): L1 in 1-1, holding still against a steady line
# of Rattles 64 px apart from the level start's 50 Grace, timed from the
# first Rattle meeting the shield. At full price the guard broke after 1.86 s
# with regen paused and 2.42 s with it on (4 blocks; 4/s is less than one
# 15-Grace block over that time, so regen alone can't carry it); at 0.7 it
# lasts 3.04 s (6 blocks), 4.68 s from full Grace, 1.98 s against a crowd
# shoulder to shoulder. Nightfall and the Witching Hour pay in full.
const DUSK_BLOCK := 0.7
# v3: beams and the Mastery nodes.
const GUARD_ARC := 1.309        # 75 deg: a beam meets the shield coming in within this of where he faces
const REFLECT_COEF := 1.5        # a Perfect Guard sends a beam back for this x basic (p_monsters: 150%)...
const REFLECT_MIRROR := 0.5      # ...plus this share of Mirrored Glass's number
const REFLECT_SHOW := 0.3        # seconds the reflected line shows
const SANCTUARY_R := 90.0        # Sanctuary: a Perfect Guard stuns every foe this near
# Shots any Perfect Guard throws back, Mirrored Glass or not (spec §5.5.7:
# the Hush's Silence Bolts; spec §5.4 and p_monsters §14.5: the Saint's Rose
# of Blades); the rest need Mirrored Glass, as in v2.
const ALWAYS_REFLECT := ["silence", "blade"]

var block_mult := 1.0            # scales every block's Grace cost (a tuning hook: sims, a playtest)
var guarding := false
var guard_t := 0.0               # seconds since the shield went up
var rushing := 0.0               # seconds left of a Shield Rush
var perfect_guards := 0          # (tests and the log)
var blocks := 0
var _rush_dir := 1
var _rush_hit := {}              # instance id -> true: each foe once per rush
var _rush_from := 0.0
var _rush_air_used := false
var _held := false
var _stagger := 0.0
var _combo := 0
var _last_swing := -9.0
var _finisher_id := -1           # attack_id of the swing that's a Finisher
var _t := 0.0
var _block_cd := {}              # key -> seconds of free blocking left
var _immune := 0.0               # Unbroken Vigil: after a Perfect Guard
var _flash := 0.0                # the ward's flash after a Perfect Guard
var _jolt := 0.0                 # the shield arm's jolt after a block
var _bounces := 0
var _pad := {}
var _streaks: Array = []         # rush speed lines {p, t}
var reflects := 0                # beams sent back (tests)
var _beams: Array = []           # reflected beams on show {a, b, t, w}
var _rings: Array = []           # Sanctuary's rings {p, t}
var _beam_n := 0                 # names each guarded beam (its free-block key)
var _judged := {}                # foe id -> attack_id: Judgment already paid on this swing


func setup(p: Node2D, w: Node) -> void:
	super(p, w)
	cls = "knight"
	_bounces = int(p.bounces)


# The Aegis root by rank (spec §2.2): v2's 5, ranks 6 and 7 (L18, L26), and an
# 8th for of the Keeper over a full root. Past the 8th the last step goes on.
const AEGIS_COEF := [1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.4, 2.5]
const AEGIS_COST := [25, 24, 22, 20, 18, 17, 16, 16]
const AEGIS_BLOCK := [50, 45, 40, 35, 30, 27, 25, 25]


func _rush_coef() -> float:
	return float(per("k_aegis", AEGIS_COEF, 1.2))


func _rush_cost() -> float:
	return float(per("k_aegis", AEGIS_COST, 25))


func _block_share() -> float:
	return float(per("k_aegis", AEGIS_BLOCK, 50)) / 100.0


func block_cost(amount: float) -> float:
	## A blocked blow's price in Grace: half of it (less with Aegis ranks),
	## weighed as the blow would be at level 1. Grace stays at 100 all game
	## while his life grows 10% a level and the monsters' blows 12% an area,
	## so by the blocked damage alone a Rattle's touch would cost 52 Grace in
	## 2-4 (the guard spent in two blocks) and more than a full bar on
	## Nightfall; this way a blow that takes the same share of his life costs
	## about the same Grace from 1-1 on. Dusk pays DUSK_BLOCK of it. Never
	## under BLOCK_MIN.
	var lvl := int(stats().get("level", 1))
	var diff := str(world.get("diff")) if world != null and world.get("diff") != null else "dusk"
	var m := block_mult * (DUSK_BLOCK if diff == "dusk" else 1.0)
	# Bastion (Guard T4): blocks cost v% less.
	m *= 1.0 - float(per("k_bastion", [15, 25, 35], 0)) / 100.0
	return maxf(BLOCK_MIN, amount * _block_share() * m / Combat.p_hp(lvl))


func pg_window() -> float:
	## The Perfect Guard window: PG_WINDOW, or the Glass of the First Dawn's
	## wider one (its first_dawn_guard, in seconds). The ring and the white
	## ward show the same window the guard uses.
	return maxf(PG_WINDOW, float(stats().get("flags", {}).get("first_dawn_guard", 0.0)))


func _flag(f: String) -> bool:
	return stats().get("flags", {}).has(f)


# ---------------------------------------------------------------- the tick

func step(dt: float, pad: Dictionary) -> void:
	_t += dt
	_pad = pad
	if world != null:
		tick_dots(dt)
		tick_pulses(dt)
	# Stomps pay Grace.
	var b := int(player.bounces)
	if b != _bounces:
		player.res = minf(player.res + 10.0 * (b - _bounces), player.res_max)
		_bounces = b
	_stagger = maxf(_stagger - dt, 0.0)
	_immune = maxf(_immune - dt, 0.0)
	_flash = maxf(_flash - dt * 3.0, 0.0)
	_jolt = maxf(_jolt - dt * 8.0, 0.0)
	for k in _block_cd.keys():
		_block_cd[k] -= dt
		if _block_cd[k] <= 0.0:
			_block_cd.erase(k)
	for s in _streaks:
		s["t"] += dt
	_streaks = _streaks.filter(func(s): return s["t"] < 0.22)
	for bm in _beams:
		bm["t"] += dt
	_beams = _beams.filter(func(bm): return bm["t"] < REFLECT_SHOW)
	for r in _rings:
		r["t"] += dt
	_rings = _rings.filter(func(r): return r["t"] < 0.4)
	if player.on_floor or on_vine():
		_rush_air_used = false   # a vine is footing: Dawnbringer's air rush comes back
	if rushing > 0.0:
		_step_rush(dt)
	elif guarding:
		guard_t += dt
		player.move_mult = minf(player.move_mult, 0.75 if _flag("unbroken") else GUARD_MOVE)
		if pad.get("jump_pressed", false) or not player.alive:
			guarding = false   # jumping drops the shield
		if REGEN_WHILE_GUARDING:
			regen(dt)
	else:
		regen(dt)
	if _stagger > 0.0:
		player.move_mult = 0.0


func special_pressed() -> void:
	_held = true
	if _stagger > 0.0 or player.ledge_t >= 0.0:
		return
	var dir := int(_pad.get("right", false)) - int(_pad.get("left", false))
	var can_rush: bool = player.on_floor or (_flag("dawn") and not _rush_air_used)
	if dir != 0 and can_rush and spend(_rush_cost()):
		_start_rush(dir)
		return
	_raise_guard(0.0)


func special_released(_held_for: float) -> void:
	_held = false
	guarding = false


func holding_special() -> bool:
	return guarding or rushing > 0.0   # the shield up: no vine catch until it's lowered


func _raise_guard(t0: float) -> void:
	guarding = true
	guard_t = t0
	sfx("guard_up", 1.0, "")


# ---------------------------------------------------------------- the rush

func _start_rush(dir: int) -> void:
	rushing = RUSH_TIME
	_rush_dir = dir
	_rush_hit.clear()
	_rush_from = player.position.x
	player.facing = dir
	var air: bool = not player.on_floor
	if air:
		_rush_air_used = true
	player.dash(Vector2(dir * RUSH_DIST / RUSH_TIME, 0.0), RUSH_TIME, {"front_guard": true, "no_grav": air, "stop_at_wall": true})
	sfx("rush", 1.0, "slash")
	haptic(18)
	if world != null:
		world.dust_at(player.position + Vector2(-dir * 8.0, 0))


func _step_rush(dt: float) -> void:
	## Runs before the player moves: clears bricks and strikes foes in the way,
	## and stops at a ledge's edge rather than rushing off it.
	rushing -= dt
	var v := RUSH_DIST / RUSH_TIME * dt
	if world != null:
		break_ahead(_rush_dir, v + 3.0)
		if player.on_floor:
			var ahead := Vector2(player.position.x + _rush_dir * (v + 3.0), player.position.y + 4.0)
			var t: int = world.level.tile(floori(ahead.x / 32.0), floori(ahead.y / 32.0))
			if not (world.level.is_solid(t) or world.level.is_ledge(t)):
				rushing = 0.0
		var sweep: Rect2 = player.rect().grow(4.0)
		if _rush_dir > 0:
			sweep.size.x += v
		else:
			sweep.position.x -= v
			sweep.size.x += v
		for e in world.enemies_in(sweep):
			_rush_strike(e)
		_streaks.append({"p": player.center() + Vector2(randf_range(-6, 6), randf_range(-14, 12)), "t": 0.0})
	if rushing <= 0.0 or player.dash_time <= 0.0:
		_end_rush()


func _rush_strike(e: Node2D) -> void:
	var id := e.get_instance_id()
	if _rush_hit.has(id):
		return
	_rush_hit[id] = true
	_block_cd[id] = CONTACT_CD
	var res := deal_as("rush", e, _rush_coef(), {"how": "skill", "heavy": true, "from_x": player.position.x - _rush_dir * 20.0})
	if res["hit"] and e.alive and not is_boss(e):
		e.apply_status("stun", 0.35)
		e.velocity = Vector2(_rush_dir * RUSH_KNOCK, -140.0)
	if res["hit"] and _flag("dawn"):
		player.res = minf(player.res + 8.0, player.res_max)
	burst(e.center(), 12, Color("fff4cf"), 200.0, 0.35, 0.0, 2.4)
	shake(3.0)


func _end_rush() -> void:
	rushing = 0.0
	player.end_dash()
	# Don't coast on: a rush ends at a walk.
	player.velocity.x = clampf(player.velocity.x, -110.0, 110.0)
	if _flag("dawn") and world != null:
		# Dawnbringer: the path burns with holy fire for 2 s.
		var x0 := minf(_rush_from, player.position.x)
		var x1 := maxf(_rush_from, player.position.x)
		var fy := floor_below(player.position + Vector2(0, -4), 48.0)
		if fy < INF:
			pulse(world.add_hazard({"kind": "fire", "owner": "player", "motion": "still", "life": 2.0,
					"rect": Rect2(x0 - 8.0, fy - 14.0, x1 - x0 + 16.0, 14.0), "flat": basic_flat(0.4)}), 0.5)
	if _held and player.alive:
		_raise_guard(pg_window())   # held on: straight into Guard (the rush was the perfect window)


# ---------------------------------------------------------------- the sword

func basic() -> bool:
	if guarding or _stagger > 0.0 or rushing > 0.0:
		return true   # the shield arm is busy: no swing
	_combo = _combo + 1 if _t - _last_swing <= FINISH_GAP else 1
	_last_swing = _t
	if _combo >= 3:
		_combo = 0
		_finisher_id = player.attack_id
		_judged.clear()
		sfx("finisher", 1.0, "")
		var cr := rank("k_crescent")
		if cr > 0 and world != null:
			# Radiant Crescent: the thrust looses a piercing arc of light.
			var reach: float = [120.0, 160.0, 200.0][clampi(cr - 1, 0, 2)]
			world.spawn_shot({"kind": "crescent", "pos": player.center() + Vector2(player.facing * 18.0, -2.0),
					"vel": Vector2(player.facing * 420.0, 0.0), "life": reach / 420.0, "how": "skill",
					"coef": float(per("k_crescent", [70, 85, 100], 70)) / 100.0, "pierce": 99, "light": 90.0})
	return false


func melee_coef() -> float:
	if player == null or player.attack_id != _finisher_id:
		return 1.0
	return FINISH_COEF * (1.0 + _judgment())


func _judgment() -> float:
	## Judgment (Blade T5): a Finisher deals v% more (and always crits).
	return float(per("k_judgment", [30, 60], 0)) / 100.0


func _melee_opts(_e) -> Dictionary:
	if player != null and player.attack_id == _finisher_id and _judgment() > 0.0:
		return {"force_crit": true}
	return {}


func attack_box(r: Rect2) -> Rect2:
	if player.attack_id != _finisher_id:
		return r
	# The Finisher's thrust reaches further (scaled like the usual reach).
	var k := r.size.x / 38.0
	var w := FINISH_BOX.x * k
	var h := FINISH_BOX.y * k
	var x: float = player.position.x + player.facing * (player.size.x * 0.5 - 4.0)
	if player.facing < 0:
		x -= w
	return Rect2(x, r.end.y - h, w, h)


func on_hit_landed(e: Node2D, res: Dictionary) -> void:
	if not res.get("hit", false) or not melee_hit(e, res):
		return
	if player.attack_id == _finisher_id and _judgment() > 0.0 and not res.get("crit", false) \
			and not swing_opts_applied(e) and int(_judged.get(e.get_instance_id(), -1)) != player.attack_id:
		# Judgment's crit, while the World doesn't take the swing's opts
		# (melee_opts): what the crit would have added, straight after.
		_judged[e.get_instance_id()] = player.attack_id
		top_up(e, res, float(stats().get("crit_mult", 1.5)) - 1.0, true)
	player.res = minf(player.res + 6.0, player.res_max)
	if player.attack_id == _finisher_id and e.alive and not is_boss(e):
		e.apply_status("stun", 0.3)
		e.velocity = Vector2(player.facing * FINISH_KNOCK, -120.0)
		burst(e.center(), 10, GOLD, 220.0, 0.35, 0.0, 2.4)


# ---------------------------------------------------------------- the shield

func filter_damage(amount: float, h: Dictionary) -> float:
	var kind: String = str(h.get("kind", "hit"))
	var src = h.get("source")
	var beam := _beam_of(h)
	if not beam.is_empty() and bool(beam.get("reflected", false)):
		return 0.0   # a beam he sent back ends at his shield: the rest of it is spent
	if kind in UNBLOCKABLE or player.invuln > 0.0 or player.dash_flags.get("invuln", false) \
			or (_overhead(src) if beam.is_empty() else _beam_steep(beam)):
		return amount   # (from overhead or below, a body or a beam: past the shield, Unbroken or not)
	if _immune > 0.0:
		return 0.0
	var key = src.get_instance_id() if src != null and is_instance_valid(src) else "k:" + kind
	if not beam.is_empty():
		# A beam is guarded by its line (shape "segment"): its own key, so a
		# second beam from the same source is a blow of its own.
		if not beam.has("guard_key"):
			_beam_n += 1
			beam["guard_key"] = "beam:%d" % _beam_n
		key = beam["guard_key"]
	var from_x := float(h.get("from_x", player.position.x))
	var front: bool = _beam_front(beam) if not beam.is_empty() else frontal(from_x)
	if rushing > 0.0:
		if is_enemy(src) and beam.is_empty():
			# Foes in the rush's path are struck, not suffered.
			_rush_strike(src)
			return 0.0
		if front:
			_perfect(h, key)
			return 0.0
		return amount
	if _block_cd.has(key) and (guarding or (is_enemy(src) and beam.is_empty())):
		return 0.0
	if not guarding:
		return amount
	if not (_flag("unbroken") or front):
		return amount
	if guard_t <= pg_window():
		_perfect(h, key)
		return 0.0
	# An ordinary block: Grace pays half the blow (less with rank), as it
	# would weigh at level 1.
	var cost := block_cost(amount)
	if player.res >= cost:
		player.res -= cost
		_blocked(h, key)
		return 0.0
	var covered: float = player.res / cost
	player.res = 0.0
	_break_guard()
	return amount * (1.0 - covered)


func _beam_of(h: Dictionary) -> Dictionary:
	## The hazard of a blow shaped as a segment (a beam: contract §5.2, the
	## World passes it as h.hazard), else {}.
	var hz = h.get("hazard")
	if hz is Dictionary and (hz.get("seg", []) is Array) and (hz["seg"] as Array).size() == 2:
		return hz
	return {}


func _beam_front(beam: Dictionary) -> bool:
	## Does the beam come in from the side he faces, within GUARD_ARC of
	## level? (A beam from straight overhead is past the shield, like
	## anything else dropping on him.)
	var seg: Array = beam["seg"]
	var d: Vector2 = (seg[1] as Vector2) - (seg[0] as Vector2)
	if d.length() < 1.0:
		return frontal((seg[0] as Vector2).x)
	var incoming := -d.normalized()   # from him back toward where it came from
	return absf(incoming.angle_to(Vector2(float(player.facing), 0.0))) <= GUARD_ARC


func _beam_steep(beam: Dictionary) -> bool:
	## A beam coming in more than GUARD_ARC off level on either side
	## (straight down on him, or up at his feet), whichever way he faces.
	var seg: Array = beam["seg"]
	var d: Vector2 = (seg[1] as Vector2) - (seg[0] as Vector2)
	if d.length() < 1.0:
		return false
	return absf(d.normalized().y) > sin(GUARD_ARC)


func _reflect_beam(beam: Dictionary, mirror: float) -> void:
	## A Perfect Guard sends a beam back along its line to where it came
	## from: the beam ends at the shield, and every foe the way back touches
	## takes REFLECT_COEF x basic (how "reflect", so a boss can tell: the
	## Saint Refracts); the source hears on_reflected(beam) for the rest (a
	## Blink, a cracked shard).
	var seg: Array = beam["seg"]
	var a: Vector2 = seg[0]
	var at := _shield_point()
	var w := maxf(float(beam.get("width", 8.0)), 8.0)
	beam["seg"] = [a, at]
	beam["reflected"] = true
	reflects += 1
	var src = beam.get("source")
	if src != null and is_instance_valid(src) and src.has_method("on_reflected"):
		src.on_reflected(beam)
	var coef := REFLECT_COEF + REFLECT_MIRROR * mirror
	for e in world.enemies.duplicate():
		if e.alive and e.active and seg_hits(at, a, w, e.rect()):
			deal_as("reflect", e, coef, {"how": "reflect", "heavy": true, "special": true, "from_x": at.x})
	_beams.append({"a": at, "b": a, "t": 0.0, "w": w})
	sfx("beam_reflect", 1.0, "perfect_guard")


static func seg_hits(a: Vector2, b: Vector2, width: float, r: Rect2) -> bool:
	## A segment of this width touching r (the World's own test, for the way back).
	var g := r.grow(width * 0.5)
	if g.has_point(a) or g.has_point(b):
		return true
	var c := [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


func _overhead(src) -> bool:
	## A foe coming down on his head (a Dripkin letting go right above him)
	## or up at his feet: the shield faces forward, so whatever the blow calls
	## itself, it's past the ward. By its body, not its middle, so a boss
	## towering over him still meets the shield when it strikes from the front.
	if src == null or not is_instance_valid(src) or not src.has_method("rect"):
		return false
	var sr: Rect2 = src.rect()
	var pr: Rect2 = player.rect()
	return sr.end.y <= pr.position.y + OVERHEAD_SLACK or sr.position.y >= pr.end.y - OVERHEAD_SLACK


func _perfect(h: Dictionary, key) -> void:
	perfect_guards += 1
	_block_cd[key] = CONTACT_CD
	player.res = minf(player.res + 15.0, player.res_max)
	var src = h.get("source")
	var beam := _beam_of(h)
	if is_enemy(src) and not is_boss(src) and src.has_method("apply_status") and beam.is_empty():
		# Staggered: it reels back, and while it reels its touch can't hurt
		# him (else a foe stunned against the shield bites in the moment the
		# shield drops between two presses). (A beam's source is answered by
		# the beam coming back, not shoved from across the room.)
		# (MA's hook first: the Frostbuckle and the Spurwheel tell a Perfect
		# Guard's stagger from a Peal's or a Bell Shard's stun by it)
		if src.has_method("on_perfect_guard"):
			src.on_perfect_guard(player)
		src.apply_status("stun", PG_STUN)
		src.velocity.x = player.facing * PG_SHOVE
		_block_cd[key] = PG_STUN
	var devout := float(per("k_devout", [5, 10], 0)) / 100.0
	if devout > 0.0 and player.heal_pct(devout) and world != null:
		world.number(player.center() + Vector2(0, -30), devout * player.max_hp, "heal")
	var mirror := float(per("k_mirror", [100, 150, 200], 0)) / 100.0
	var shot := bool((h.get("opts", {}) as Dictionary).get("shot", false)) if h.get("opts") is Dictionary else false
	var vin = (h.get("opts", {}) as Dictionary).get("vel", Vector2.ZERO) if h.get("opts") is Dictionary else Vector2.ZERO
	var pin = (h.get("opts", {}) as Dictionary).get("pos", null) if h.get("opts") is Dictionary else null
	var kind := str(h.get("kind", ""))
	if not beam.is_empty():
		if bool(beam.get("reflect", false)) and not bool(beam.get("reflected", false)) and world != null:
			_reflect_beam(beam, mirror)
	elif kind in ALWAYS_REFLECT and world != null:
		_reflect(kind, REFLECT_COEF + REFLECT_MIRROR * mirror, vin if vin is Vector2 else Vector2.ZERO, pin)
	elif mirror > 0.0 and world != null and (shot or not is_enemy(src)):
		# A shot (whoever loosed it) or a shockwave, never a foe's own touch.
		_reflect(kind, mirror, vin if vin is Vector2 else Vector2.ZERO, pin)
	var sanct := float(per("k_sanctuary", [0.6, 1.0], 0))
	if sanct > 0.0 and world != null:
		# Sanctuary (Guard T5): the Perfect Guard rings out and every foe near
		# reels (a boss keeps its time, as with every stun in the kits).
		for e in enemies_near(player.center(), SANCTUARY_R):
			if not is_boss(e) and e.has_method("apply_status"):
				e.apply_status("stun", sanct)
		_rings.append({"p": player.center(), "t": 0.0})
		sfx("peal", 1.5, "bell")
	if _flag("unbroken"):
		_immune = 1.0
	_flash = 1.0
	sfx("perfect_guard", 1.0, "clang")
	haptic(30)
	if world != null:
		world.freeze(0.06)
		var at := _shield_point()
		burst(at, 18, GOLD, 220.0, 0.45, 0.0, 2.6)
		burst(at, 8, Color("fff4cf"), 120.0, 0.3, 0.0, 2.0)
		say(player.center() + Vector2(0, -44), "Perfect!")
		shake(3.0)


func _reflect(kind: String, coef: float, vin := Vector2.ZERO, pin = null) -> void:
	## Mirrored Glass: the blocked shot (or shockwave) goes back as his own.
	## A shot goes home, back along the line it came in on (vin, its flight,
	## from pin, where the shield met it), as a timed swing sends one back: a
	## Bonebow's arrow loosed down from a post returns up to the post ("A
	## perfect guard throws it home": k1). (v2 threw every one back level
	## from his chest, whatever its angle; at 420 px/s for 0.7 s, as then.)
	var f: int = player.facing
	if kind == "wave":
		world.add_hazard({"kind": "wave", "owner": "player", "motion": "floor", "life": 0.9, "coef": coef,
				"rect": Rect2(player.position.x + f * 16.0 - 9.0, player.position.y - 22.0, 18.0, 22.0), "vel": Vector2(f * 260.0, 0)})
	else:
		var dir := Vector2(f, 0)
		var at: Vector2 = player.center() + Vector2(f * 14.0, -2.0)
		if vin.length() > 1.0 and signf(vin.x) != float(f):
			dir = -vin.normalized()
			if pin is Vector2:
				at = pin
		world.spawn_shot({"kind": kind if kind in ["arrow", "skull", "bolt"] else "crescent", "pos": at,
				"vel": dir * 420.0, "life": 0.7, "coef": coef, "how": "skill", "light": 60.0, "pierce": 1})


func _blocked(h: Dictionary, key) -> void:
	blocks += 1
	_block_cd[key] = CONTACT_CD
	_jolt = 1.0
	var src = h.get("source")
	if is_enemy(src) and not is_boss(src) and src.has_method("apply_status") and _beam_of(h).is_empty():
		# Shoved off the shield (not a beam's source, across the room).
		src.apply_status("stun", 0.3)
		src.velocity.x = player.facing * 220.0
	if player.on_floor:
		player.velocity.x = -player.facing * 90.0
	sfx("guard_block", 1.0, "clang")
	haptic(14)
	if world != null:
		world.number(_shield_point() + Vector2(0, -16), 0.0, "blocked")
		burst(_shield_point(), 8, Color("e8e2d0"), 150.0, 0.25, 0.0, 2.0)
		world.freeze(0.03)


func _break_guard() -> void:
	guarding = false
	_stagger = BREAK_STAGGER
	sfx("guard_break", 1.0, "clang")
	haptic(30)
	if world != null:
		say(player.center() + Vector2(0, -44), "Guard broken")
		burst(_shield_point(), 14, Color("8b90a8"), 180.0, 0.4, 300.0, 2.4)
		shake(4.0)


func _shield_point() -> Vector2:
	var rig = world.rig if world != null else null
	if rig != null and rig.has_method("hand_point"):
		return rig.hand_point(true)
	return player.center() + Vector2(player.facing * 12.0, -2.0)


# ---------------------------------------------------------------- the rest

func on_respawn() -> void:
	guarding = false
	rushing = 0.0
	_stagger = 0.0
	_immune = 0.0
	_combo = 0
	_block_cd.clear()
	_dots.clear()
	_beams.clear()
	_rings.clear()
	_judged.clear()


func on_reset() -> void:
	rushing = 0.0
	_streaks.clear()


func on_level_start() -> void:
	on_respawn()


func lights() -> Array:
	if guarding or rushing > 0.0 or _flash > 0.0:
		return [{"p": _shield_point(), "r": 46.0 + 40.0 * _flash, "s": 0.45}]
	return []


func button_state() -> Dictionary:
	var p := player
	if p == null:
		return {}
	return {"fill": p.res / maxf(p.res_max, 0.001), "ready": p.res >= _rush_cost() and _stagger <= 0.0,
			"grey": p.res < BLOCK_MIN or _stagger > 0.0, "pips": 0, "pips_max": 0,
			"ring": clampf(1.0 - guard_t / pg_window(), 0.0, 1.0) if guarding else 0.0, "icon": "knight"}


func pose(k: Dictionary) -> Dictionary:
	if player == null:
		return {}
	if rushing > 0.0:
		# Shoulder down behind the shield.
		return {"arm_b": -1.5, "offhand_off": Vector2(8, 0), "offhand_top": true, "offhand_rot": 0.1, "arm_f": 0.9, "weapon_rel": -2.3,
				"lean": 0.26, "cape": -1.1, "leg_b": 0.75, "leg_f": -0.65}
	if guarding:
		var j := sin(_jolt * 18.0) * 0.12 * _jolt
		# The shield pushed out at chest height, over everything (his eyes
		# just clear it); the sword drawn back low behind it, out of the way.
		# A block knocks the shield back toward him for a beat.
		var o := {"arm_b": -1.6 + j, "offhand_off": Vector2(6.0 - 2.5 * _jolt, -2.0), "offhand_top": true, "offhand_rot": 0.0,
				"arm_f": 0.9, "weapon_rel": -2.1, "lean": -0.05 - 0.06 * _jolt}
		if k.get("grounded", true) and absf(player.velocity.x) < 20.0:
			o["leg_b"] = 0.32
			o["leg_f"] = -0.28
		return o
	if _stagger > 0.0:
		return {"lean": -0.28, "arm_b": 0.5, "arm_f": 0.6, "weapon_rel": 1.8}
	var at: float = k.get("attack_time", -1.0)
	if at >= 0.0 and player.attack_id == _finisher_id:
		# The Finisher is a thrust, not an arc.
		var q := clampf(at / player.ATTACK_ACTIVE, 0.0, 1.0)
		var arm := lerpf(-0.9, -1.45, 1.0 - pow(1.0 - q, 3.0))
		return {"arm_f": arm, "weapon_rel": 1.6 - arm, "lean": 0.2, "arm_b": 0.5}
	return {}


func draw(glow: Node2D) -> void:
	if player == null or world == null:
		return
	_draw_v3(glow)
	var f := float(player.facing)
	var sp := _shield_point()
	# The Finisher's thrust: a line of light off the blade's point.
	var at: float = player.attack_time
	if at >= 0.0 and at <= player.ATTACK_ACTIVE + 0.06 and player.attack_id == _finisher_id:
		var q := clampf(at / (player.ATTACK_ACTIVE + 0.06), 0.0, 1.0)
		var o: Vector2 = player.center() + Vector2(f * 14.0, 2.0)
		var reach := 44.0 * (1.0 - pow(1.0 - q, 2.0))
		glow.draw_line(o, o + Vector2(f * reach, 0), Color(1.0, 0.95, 0.75, 0.8 * (1.0 - q)), 4.0)
		glow.draw_line(o, o + Vector2(f * reach * 0.8, 0), Color(1, 1, 1, 0.9 * (1.0 - q)), 1.6)
	# Rush speed lines.
	for s in _streaks:
		var a: float = 1.0 - s["t"] / 0.22
		var p: Vector2 = s["p"]
		glow.draw_line(p, p - Vector2(f * 26.0 * a, 0), Color(1.0, 0.9, 0.6, 0.55 * a), 2.0)
	# The Guard: a curved ward of light before the shield; it burns white in
	# the Perfect Guard window.
	if guarding or rushing > 0.0 or _flash > 0.0:
		var perfect: bool = rushing > 0.0 or (guarding and guard_t <= pg_window())
		var c := Color(1.0, 0.97, 0.85, 0.85) if perfect else Color(GOLD, 0.55)
		if _flash > 0.0:
			c = c.lerp(Color(1, 1, 1, 0.95), _flash)
		var ctr: Vector2 = player.center() + Vector2(f * 4.0, -2.0)
		var rr := 23.0 + 6.0 * _flash
		var pts := PackedVector2Array()
		var rim := PackedVector2Array()
		for i in 15:
			var ang := lerpf(-1.05, 1.05, i / 14.0)
			pts.append(ctr + Vector2(cos(ang) * f, sin(ang)) * rr)
			rim.append(pts[i])
		for i in range(14, -1, -1):
			var ang := lerpf(-1.05, 1.05, i / 14.0)
			pts.append(ctr + Vector2(cos(ang) * f, sin(ang)) * (rr - 3.0 - 3.5 * sin(PI * i / 14.0)))
		glow.draw_colored_polygon(pts, Color(c, c.a * 0.55))
		glow.draw_polyline(rim, c, 2.2)
		if _flag("unbroken") and guarding:
			glow.draw_arc(ctr, rr, 0, TAU, 28, Color(GOLD, 0.25), 2.0)
		if _flash > 0.0:
			glow.draw_arc(sp, 10.0 + (1.0 - _flash) * 40.0, 0, TAU, 28, Color(1.0, 0.92, 0.6, _flash), 3.0)
	elif player.res >= player.res_max - 0.01:
		# A full store of Grace: the shield's glass glints.
		var tw := 0.5 + 0.5 * sin(_t * 3.0)
		glow.draw_circle(sp, 7.0 + tw, Color(GOLD, 0.16))
		glow.draw_circle(sp, 2.2, Color(1.0, 0.95, 0.7, 0.55 + 0.3 * tw))
	if _stagger > 0.0:
		var hc: Vector2 = player.center() + Vector2(0, -34)
		for i in 3:
			var a := _t * 7.0 + TAU * i / 3.0
			glow.draw_circle(hc + Vector2(cos(a) * 10.0, sin(a) * 3.0), 2.2, Color(0.9, 0.9, 1.0, 0.8))


func _draw_v3(glow: Node2D) -> void:
	## A reflected beam racing back along its line, and Sanctuary's ring
	## (new drawing: one TriBatch, one draw call).
	if _beams.is_empty() and _rings.is_empty():
		return
	var tb = TriBatch.new()
	for b in _beams:
		var q: float = b["t"] / REFLECT_SHOW
		var a := 1.0 - q
		var w: float = b["w"]
		tb.line(b["a"], b["b"], w + 6.0, Color(GOLD, 0.30 * a))
		tb.line(b["a"], b["b"], w * 0.6, Color(1.0, 0.95, 0.75, 0.75 * a))
		tb.line(b["a"], b["b"], 2.0, Color(1, 1, 1, 0.95 * a))
		tb.circle(b["a"], 6.0 + 10.0 * q, Color(1.0, 0.97, 0.85, 0.6 * a), 12)
	for r in _rings:
		var q: float = r["t"] / 0.4
		var rr := 20.0 + (SANCTUARY_R - 20.0) * (1.0 - pow(1.0 - q, 2.0))
		tb.ring(r["p"], rr, 3.0 * (1.0 - q) + 1.0, Color(1.0, 0.92, 0.6, 0.8 * (1.0 - q)), 28)
	tb.flush(glow)
