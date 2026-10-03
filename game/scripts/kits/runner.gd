extends "res://scripts/kits/kit.gd"
## Sootrunner: thrown knives for a basic (soft-aimed, three in flight, 45 deg
## down in the air with down held; a foe within 28 px in front gets a Stab
## instead), and every hit on a foe's back is a Backstab: a sure crit, +25%.
## Smoke (3 pips, one per 2.2 s) pays for Smoke Step: a 112 px dash in 0.14 s
## that passes through foes and shots, once per airtime (a landing, a stomp
## or a wall cling refreshes it). Foes passed are Sooted for 3 s (+25% harm)
## and Flits lose her and go home. Moth Cling lives in player.gd.
##
## v3: the Step root runs to 7 ranks (and an 8th for of the Keeper), but the
## dash stays 144 px from rank 5 on: the platforming never changes. Phantom
## Step (Shadow T5): a Step through a foe refunds v% of a pip, once a Step.
## Fan of Knives (Knives T5): every 6th throw fans out v extra knives (shots,
## never lights). A vine is footing: catching one gives the air Step back.

const KNIFE_SPEED := 560.0
const KNIFE_LIFE := 0.46
const KNIFE_MAX := 3
const AIM_CONE := 20.0
const STAB_REACH := 28.0
const STAB_COEF := 1.2
const STEP_TIME := 0.14
const BACKSTAB := 0.25           # the Backstab's extra damage
const SOOT_TIME := 3.0
const SMOKE := Color("d0d4e0")
# The Step root by rank (spec §2.2): v2's 5, ranks 6 and 7, and an 8th for of
# the Keeper. The dash stops at 144 px on purpose.
const STEP_PIP := [2.2, 2.1, 2.0, 1.9, 1.8, 1.7, 1.6, 1.6]
const STEP_DIST := [112, 120, 128, 136, 144, 144, 144, 144]
const STEP_SOOT := [25, 28, 31, 34, 37, 40, 43, 43]
const STEP_DIST_MAX := 144.0     # never past this, whatever the rank (the levels are drawn to it)
const FAN_EVERY := 6             # Fan of Knives: every 6th throw...
const FAN_SPREAD := 12.0         # ...fans its extra knives this many degrees apart

var stepping := 0.0              # seconds left of a Smoke Step
var last_hit := {}               # {crit, back} of the last knife or stab that landed (tests)
var backstabs := 0
var _step_dir := 1
var _step_passed := {}           # instance id -> foe
var _air_used := false
var _refresh := 0                # bounces + clings seen: each refreshes the air dash
var _prev_rect := Rect2()
var _knives: Array = []
var _throw_t := 9.0
var _stab_t := 9.0
var _pad := {}
var _t := 0.0
var _puffs: Array = []           # {p, v, t, life, r}
var _clouds: Array = []          # Smoke Veil {p, t}
var throws := 0                  # knife throws so far (Fan of Knives counts them)
var fans := 0                    # fans thrown (tests)
var phantoms := 0                # Phantom Step refunds (tests)
var _phantom_paid := false       # this Step has refunded already


func setup(p: Node2D, w: Node) -> void:
	super(p, w)
	cls = "runner"
	_refresh = int(p.bounces) + int(p.clings)


func _pip_time() -> float:
	return float(per("r_step", STEP_PIP, 2.2)) if rank("r_step") > 0 else 2.2


func _step_dist() -> float:
	return minf(float(per("r_step", STEP_DIST, 112)), STEP_DIST_MAX)


func _soot_bonus() -> float:
	return float(per("r_step", STEP_SOOT, 25)) / 100.0


func _flag(f: String) -> bool:
	return stats().get("flags", {}).has(f)


# ---------------------------------------------------------------- the tick

func step(dt: float, pad: Dictionary) -> void:
	_t += dt
	_pad = pad
	_throw_t += dt
	_stab_t += dt
	var pips := float(stats().get("flags", {}).get("moth_queen_pips", 0.0))
	if player.res_max < pips:
		player.res_max = pips   # the Moth-Queen's Scale: a fourth pip
	player.res = minf(player.res + dt / _pip_time(), player.res_max)
	var r := int(player.bounces) + int(player.clings)
	if player.on_floor or r != _refresh or on_vine():
		_air_used = false
	_refresh = r
	if world != null:
		tick_dots(dt)
		_knives = _knives.filter(func(s): return s["life"] > 0.0)
		# A knife about to land on a back hits harder (the World rolls the crit).
		for s in _knives:
			var e: Node2D = world.nearest_enemy(s["pos"], 34.0)
			var back := e != null and Combat.is_back_hit(e, s["pos"].x - signf(s["vel"].x) * 20.0)
			s["extra_pct"] = BACKSTAB if back else 0.0
	if stepping > 0.0:
		_step_smoke(dt)
	_prev_rect = player.rect()
	for p in _puffs:
		p["t"] += dt
		p["p"] += p["v"] * dt
		p["v"] *= exp(-dt * 4.0)
	_puffs = _puffs.filter(func(p): return p["t"] < p["life"])
	_step_clouds(dt)


# ---------------------------------------------------------------- knives

func basic() -> bool:
	if world == null or stepping > 0.0:
		return true
	var stab := _stab_target()
	if stab != null:
		_stab(stab)
		return true
	var most := KNIFE_MAX + (1 if rank("r_bandolier") > 0 else 0)
	if _knives.filter(func(k): return not k.get("fan", false)).size() >= most:
		return true
	var origin: Vector2 = player.center() + Vector2(player.facing * 10.0, -4.0)
	var dir := Vector2(player.facing, 0)
	if not player.on_floor and _pad.get("down", false):
		dir = Vector2(player.facing, 1).normalized()
	else:
		# The aim reaches as far as a knife flies (the Longsword's range_mult too).
		dir = soft_aim(origin, dir, KNIFE_SPEED * KNIFE_LIFE * 1.2 * float(stats().get("flags", {}).get("range_mult", 1.0)), AIM_CONE)
	_knife(origin, dir)
	var extra := float(per("r_bandolier", [30, 55], 0)) / 100.0
	if extra > 0.0 and world.rng.randf() < extra:
		_knife(origin, dir.rotated(deg_to_rad(-10.0 * player.facing)))
	throws += 1
	var fan := int(per("r_fan", [2, 3], 0))
	if fan > 0 and throws % FAN_EVERY == 0:
		# Fan of Knives (Knives T5): the 6th throw fans out, alternating
		# either side of the aim (they don't count against the three).
		fans += 1
		for i in fan:
			var ang := FAN_SPREAD * float(floori(i / 2.0) + 1) * (1.0 if i % 2 == 0 else -1.0)
			var fk: Dictionary = _knife(origin, dir.rotated(deg_to_rad(ang)))
			fk["fan"] = true
		burst(origin, 6, Color("e8ecf4"), 120.0, 0.2, 0.0, 1.6)
	_throw_t = 0.0
	sfx("knife_throw", 1.0, "slash")
	return true


func _knife(origin: Vector2, dir: Vector2, force := false) -> Dictionary:
	var ric := rank("r_ricochet")
	var s: Dictionary = world.spawn_shot({"kind": "knife", "pos": origin, "vel": dir * KNIFE_SPEED, "life": KNIFE_LIFE, "coef": 1.0,
			"how": "shot", "backstab": true, "cancels": true, "radius": 5.0, "quiet": true,
			"bounce": [0, 1, 1, 2][ric], "pierce": [0, 0, 1, 1][ric], "on_hit": _knife_hit})
	if force:
		# Thousand Cuts: a sure crit (the World rolls it with force_crit, so
		# it shows the crit star and crits once), and the Special's own
		# knife, so special_pct counts on it.
		s["force_crit"] = true
		s["special"] = true
	_knives.append(s)
	return s


func _knife_hit(s: Dictionary, e: Node2D, res: Dictionary) -> void:
	if not res.get("hit", false):
		return
	var back := Combat.is_back_hit(e, s["pos"].x - signf(s["vel"].x) * 20.0)
	_landed(e, res, back)
	burst(s["pos"], 5, Color("e8ecf4"), 110.0, 0.2, 0.0, 1.6)
	sfx("knife_hit", 1.0, "")


func _stab_target() -> Node2D:
	var r: Rect2 = player.rect()
	var x: float = r.end.x if player.facing > 0 else r.position.x - STAB_REACH
	var zone := Rect2(x, r.position.y + 4.0, STAB_REACH, r.size.y - 4.0)
	var best: Node2D = null
	for e in world.enemies_in(zone):
		if best == null or absf(e.position.x - player.position.x) < absf(best.position.x - player.position.x):
			best = e
	return best


func _stab(e: Node2D) -> void:
	var from_x: float = player.position.x
	var back := Combat.is_back_hit(e, from_x)
	var res := deal_as("stab", e, STAB_COEF, {"how": "slash", "backstab": true, "extra_pct": BACKSTAB if back else 0.0, "from_x": from_x})
	_stab_t = 0.0
	sfx("slash", 1.3, "")
	if res["hit"]:
		sfx("slash_hit", 1.2, "")
		burst(e.center(), 8, Color("e8ecf4"), 150.0, 0.25, 0.0, 2.0)
		_landed(e, res, back)
	# A stab breaks bricks the knife tip touches, like a swing.
	break_ahead(player.facing, 6.0)


func _landed(e: Node2D, res: Dictionary, back: bool) -> void:
	last_hit = {"crit": res.get("crit", false), "back": back, "target": e}
	if not back:
		return
	backstabs += 1
	say(e.center() + Vector2(0, -e.size.y * 0.5 - 18.0), "Backstab!")
	player.res = minf(player.res + 0.5, player.res_max)
	sfx("backstab", 1.0, "")
	haptic(16)
	if _flag("mercy") and e.alive and e.hp < 0.3 * e.max_hp:
		# Mercy Stroke: a wounded foe struck from behind is finished off.
		if is_boss(e):
			deal_as("mercy", e, 1.0, {"how": "skill", "flat": float(res.get("amount", 0.0)), "no_hitstop": true})
		else:
			deal_as("mercy", e, 1.0, {"how": "skill", "flat": e.hp + 1.0})
			player.res = minf(player.res + 1.0, player.res_max)


func on_hit_landed(_e: Node2D, _res: Dictionary) -> void:
	pass


# ---------------------------------------------------------------- Smoke Step

func special_pressed() -> void:
	if stepping > 0.0:
		return
	if player.res < 1.0 or (not player.on_floor and _air_used):
		sfx("fizzle", 1.0, "bump")
		_puff(player.center(), 4, 30.0)
		return
	player.res -= 1.0
	_phantom_paid = false
	var dir := int(_pad.get("right", false)) - int(_pad.get("left", false))
	if dir == 0:
		dir = player.facing
	_step_dir = dir
	player.facing = dir
	if not player.on_floor:
		_air_used = true
	stepping = STEP_TIME
	_step_passed.clear()
	_prev_rect = player.rect()
	player.dash(Vector2(dir * _step_dist() / STEP_TIME, 0.0), STEP_TIME, {"no_grav": true, "invuln": true, "pass": true, "stop_at_wall": true})
	sfx("smoke_step", 1.0, "double_jump")
	haptic(12)
	_puff(player.center(), 10, 90.0)


func _step_smoke(dt: float) -> void:
	## Every foe the smoke passes through is Sooted (and a Flit goes home).
	stepping -= dt
	if world != null:
		var swept: Rect2 = player.rect().merge(_prev_rect).grow(4.0)
		for e in world.enemies_in(swept):
			var id: int = e.get_instance_id()
			if _step_passed.has(id):
				continue
			_step_passed[id] = e
			soot(e, SOOT_TIME)
			var ph := float(per("r_phantom", [25, 50], 0)) / 100.0
			if ph > 0.0 and not _phantom_paid:
				# Phantom Step (Shadow T5): through a foe, a share of the pip back.
				_phantom_paid = true
				phantoms += 1
				player.res = minf(player.res + ph, player.res_max)
		_puff(player.center() + Vector2(randf_range(-6, 6), randf_range(-10, 10)), 1, 20.0)
	if stepping <= 0.0 or player.dash_time <= 0.0:
		_end_step()


func soot(e: Node2D, seconds: float) -> void:
	e.apply_status("sooted", seconds, {"bonus": _soot_bonus()})
	if is_boss(e):
		return
	if e.kind == "bat" and e.get("_state") != null and e.get("_state") in ["windup", "swoop"]:
		e.set("_state", "return")   # a Flit loses her and flutters home
	burst(e.center() + Vector2(0, -e.size.y * 0.3), 6, Color("8a8698"), 50.0, 0.6, -60.0, 3.0)


func _end_step() -> void:
	stepping = 0.0
	player.end_dash()
	player.velocity.x = _step_dir * player.RUN_SPEED
	if not player.on_floor:
		player.velocity.y = 0.0
	_puff(player.center(), 8, 70.0)
	if _flag("cuts") and world != null:
		# Thousand Cuts: a knife at every foe passed and every foe near.
		var targets := {}
		for id in _step_passed:
			targets[id] = _step_passed[id]
		for e in enemies_near(player.center(), 150.0):
			targets[e.get_instance_id()] = e
		for id in targets:
			var e: Node2D = targets[id]
			if is_instance_valid(e) and e.alive:
				var o: Vector2 = player.center()
				_knife(o, (e.center() - o).normalized(), true)
	var veil := float(per("r_veil", [1.0, 1.5, 2.0], 0))
	if veil > 0.0:
		_clouds.append({"p": player.center(), "t": veil, "max": veil})


func _step_clouds(dt: float) -> void:
	## Smoke Veil: shots entering the cloud vanish; foes inside lose her.
	for c in _clouds:
		c["t"] -= dt
		if world == null:
			continue
		for s in world.shots:
			if s["owner"] == "enemy" and s["pos"].distance_to(c["p"]) < 32.0:
				s["life"] = 0.0
		for e in enemies_near(c["p"], 32.0):
			e.apply_status("sooted", 0.4, {"bonus": _soot_bonus()})
	_clouds = _clouds.filter(func(c): return c["t"] > 0.0)


func _puff(p: Vector2, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		_puffs.append({"p": p, "v": Vector2(cos(a), sin(a)) * randf_range(0.3, 1.0) * speed + Vector2(0, -12), "t": 0.0,
				"life": randf_range(0.35, 0.7), "r": randf_range(3.0, 6.0)})
	if _puffs.size() > 90:
		_puffs = _puffs.slice(_puffs.size() - 90)


# ---------------------------------------------------------------- the rest

func on_respawn() -> void:
	stepping = 0.0
	_air_used = false
	_clouds.clear()
	_dots.clear()


func on_reset() -> void:
	stepping = 0.0
	_step_passed.clear()


func on_level_start() -> void:
	on_respawn()


func button_state() -> Dictionary:
	var p := player
	if p == null:
		return {}
	var ok: bool = p.res >= 1.0 and (p.on_floor or not _air_used)
	return {"fill": fmod(p.res, 1.0) if p.res < p.res_max else 1.0, "ready": ok, "grey": not ok,
			"pips": int(floor(p.res)), "pips_max": int(p.res_max), "ring": 0.0, "icon": "runner"}


func pose(k: Dictionary) -> Dictionary:
	if player == null:
		return {}
	if stepping > 0.0:
		# A blur of smoke, the moth-wing cloak flared.
		return {"alpha": 0.35, "lean": 0.32, "cape": -0.9, "arm_b": 0.9, "arm_f": 0.8, "leg_b": 0.6, "leg_f": -0.5, "weapon_alpha": 0.0}
	if player.clinging != 0 and not k.get("grounded", false):
		# Pressed to the wall, sliding.
		return {"arm_f": -2.2, "arm_b": -2.6, "weapon_rel": 2.3, "leg_f": -0.9, "leg_b": 0.4, "cape": -0.9, "lean": 0.12}
	if _stab_t < 0.14:
		var q := clampf(_stab_t / 0.07, 0.0, 1.0)
		var arm := lerpf(-0.8, -1.55, q)
		return {"arm_f": arm, "weapon_rel": 1.6 - arm, "lean": 0.14}
	if _throw_t < 0.15:
		# The arm whips through and the knife is gone for a moment.
		var q := clampf(_throw_t / 0.08, 0.0, 1.0)
		return {"arm_f": lerpf(1.2, -1.6, q), "weapon_alpha": 0.0, "lean": 0.1}
	if _throw_t < 0.24:
		# ...and a fresh one slides into her fist.
		return {"weapon_alpha": clampf((_throw_t - 0.15) / 0.09, 0.0, 1.0)}
	return {}


func draw(glow: Node2D) -> void:
	if player == null or world == null:
		return
	for p in _puffs:
		var a: float = 1.0 - p["t"] / p["life"]
		glow.draw_circle(p["p"], p["r"] * (1.0 + p["t"] * 1.5), Color(0.62, 0.6, 0.7, 0.42 * a))
	for c in _clouds:
		var a := clampf(c["t"] / 0.4, 0.0, 1.0)
		for i in 6:
			var ang := TAU * i / 6.0 + _t * 0.6
			glow.draw_circle(c["p"] + Vector2(cos(ang) * 18.0, sin(ang) * 10.0), 14.0, Color(0.5, 0.48, 0.58, 0.35 * a))
	# Sooted foes smoke from the head.
	for e in world.enemies:
		if e.alive and e.active and e.status.has("sooted"):
			var hp: Vector2 = e.center() + Vector2(0, -e.size.y * 0.5 - 2.0)
			for i in 3:
				var ph := fmod(_t * 0.9 + i / 3.0, 1.0)
				glow.draw_circle(hp + Vector2(sin(ph * 9.0 + i) * 3.0, -ph * 14.0), 1.8 + ph * 3.0, Color(0.35, 0.33, 0.42, 0.55 * (1.0 - ph)))
