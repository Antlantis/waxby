extends "res://scripts/kits/kit.gd"
## Taperwitch: Sparks for a basic (soft-aimed fire bolts, three at most, each
## a moving light; down in the air fires straight down), Melt for a resource
## (14/s, paused 0.6 s after a spend), and the Flare: hold to charge (0.5 s,
## no jumping, 60% ground speed), let go to lob it. It bursts on a foe, the
## ground or after 1.2 s: 1.8x -> 4.0x basic (more with rank) in 44 -> 70 px,
## 1.5 s of burning ground, and a Beacon, a light of 160 px for 6 s (one at a
## time; the Snuffer counts it as light). Drift lives in player.gd; a second
## jump press in the air turns it on through air_jump(). The Everburning
## Taper (a charm) makes the Beacon burn every foe inside its light:
## everburning_coef x basic each everburning_tick s.
##
## v3: the Flare root runs to 7 ranks (and an 8th for of the Keeper);
## Wildfire (Fire T5): a burning foe that dies bursts into 3 sparks for v%
## basic (shots, never lights); Candlemold (Wax T5): waxed foes take v% more
## from her (sparks, flares and their direct hits, blasts, burns), a boss's
## big body too. A press on a vine lets go of it (world.gd), and while the
## charge is held she catches none (holding_special): she throws as in the air.

const SPARK_SPEED := 360.0
const SPARK_LIFE := 0.5
const SPARK_MAX := 3
const SPARK_LIGHT := 80.0
const AIM_RANGE := 220.0
const AIM_CONE := 30.0
const CHARGE_TIME := 0.5
const TAP := 0.08                # held less than this: the minimum flare
const COST_MIN := 25.0
const COST_MAX := 50.0
const REGEN_PAUSE := 0.6
const FLARE_V := Vector2(300, -260)
const FLARE_G := 900.0
const FLARE_LIFE := 1.2
const BEACON_R := 160.0
const BEACON_LIFE := 6.0
const FIRE_LIFE := 1.5
const MELT := Color("7ec8ff")
# The Flare root by rank (spec §2.2): v2's 5, ranks 6 and 7, and an 8th for of the Keeper.
const FLARE_COEF := [4.0, 4.4, 4.8, 5.2, 5.6, 6.0, 6.4, 6.6]
const WILDFIRE_N := 3            # Wildfire's sparks from a burning foe that dies
const WILDFIRE_AIM := 220.0      # each seeks a foe this near, else flies out on its own line

var charging := false
var charge := 0.0                # 0..1 while charging
var beacon := -1                 # the Beacon's light id in the World
var beacon_pos := Vector2.ZERO
var beacon_t := 0.0
var beacon_r := BEACON_R
var everburns := 0               # Everburning Taper ticks that found a foe (tests)
var _ever_t := 0.0
var bursts := 0                  # (tests)
var _pause := 0.0
var _cast_t := 9.0
var _pad := {}
var _t := 0.0
var _sparks: Array = []
var _drift_puffs: Array = []     # {p, t}
var _effigy_used := false
var _effigy := {}                # the melting wax double {p, t, facing}
var _checkpoint := Vector2.INF
var _hum: Object = null          # the flare_charge voice while it plays
var wildfires := 0               # Wildfire bursts (tests)
var _wild: Array = []            # Wildfire's sparks in flight
var _flares: Array = []          # flares in flight (Candlemold rides on their direct hit)


func setup(p: Node2D, w: Node) -> void:
	super(p, w)
	cls = "witch"


func _full_coef() -> float:
	return float(per("w_flare", FLARE_COEF, 4.0))


func _flag(f: String) -> bool:
	return stats().get("flags", {}).has(f)


func _max_charge() -> float:
	## The charge stops rising when Melt runs out.
	return clampf((player.res - COST_MIN) / (COST_MAX - COST_MIN), 0.0, 1.0)


# ---------------------------------------------------------------- the tick

func step(dt: float, pad: Dictionary) -> void:
	_t += dt
	_pad = pad
	_cast_t += dt
	beacon_t = maxf(beacon_t - dt, 0.0)
	if world != null:
		tick_dots(dt)
		tick_pulses(dt)
		_everburn(dt)
		_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
		_wild = _wild.filter(func(s): return s["life"] > 0.0)
		_flares = _flares.filter(func(s): return s["life"] > 0.0 and not s.get("burst", false))
		if _candlemold() > 0.0:
			for s in _sparks + _wild + _flares:
				shot_bonus(s, dt)   # Candlemold rides on a shot about to meet a waxed foe
	_pause = maxf(_pause - dt, 0.0)
	if _pause <= 0.0:
		regen(dt)
	if world != null and world.checkpoint != _checkpoint:
		_checkpoint = world.checkpoint
		_effigy_used = false   # the Effigy comes back at each new altar
	if not _effigy.is_empty():
		_effigy["t"] -= dt
		if _effigy["t"] <= 0.0:
			_effigy = {}
	if charging:
		player.move_mult = minf(player.move_mult, 0.6)
		player.jump_lock = true
	else:
		player.jump_lock = false
	# Drift's smoke: a cushion under her hem that sinks a little slower than
	# she does (so it stays about her feet instead of rising over her face).
	for d in _drift_puffs:
		d["t"] += dt
		d["p"].y += (player.DRIFT_FALL - 22.0) * dt
	_drift_puffs = _drift_puffs.filter(func(d): return d["t"] < 0.6)
	if player.drifting and player.velocity.y >= player.DRIFT_FALL - 1.0 and fmod(_t, 0.07) < dt:
		_drift_puffs.append({"p": player.position + Vector2(randf_range(-8, 8), -1.0), "t": 0.0})


# ---------------------------------------------------------------- sparks

func basic() -> bool:
	if charging:
		return true
	if world == null or _sparks.size() >= SPARK_MAX:
		return true
	var origin := _tip()
	var dir := Vector2(player.facing, 0)
	if not player.on_floor and _pad.get("down", false):
		dir = Vector2(0, 1)
	else:
		dir = soft_aim(origin, dir, AIM_RANGE * 1.2, AIM_CONE)
	var twin := float(per("w_twin", [35, 60], 0)) / 100.0
	if twin > 0.0 and world.rng.randf() < twin:
		_spark(origin, dir.rotated(deg_to_rad(9.0)))
		_spark(origin, dir.rotated(deg_to_rad(-9.0)))
	else:
		_spark(origin, dir)
	_cast_t = 0.0
	sfx("spark", 1.0, "slash")
	return true


func _spark(origin: Vector2, dir: Vector2) -> void:
	var s: Dictionary = world.spawn_shot({"kind": "spark", "pos": origin, "vel": dir * SPARK_SPEED, "life": SPARK_LIFE,
			"coef": 1.0, "light": SPARK_LIGHT, "how": "shot", "on_hit": _spark_hit})
	_sparks.append(s)


# ---------------------------------------------------------------- v3: the Mastery nodes

func _candlemold() -> float:
	return float(per("w_candlemold", [15, 25], 0)) / 100.0


func bonus_vs(e) -> float:
	## Candlemold (Wax T5): a waxed foe takes v% more from her.
	var v := _candlemold()
	if v <= 0.0 or e == null or not is_instance_valid(e):
		return 0.0
	var st = e.get("status")
	return v if st is Dictionary and float(st.get("waxed", 0.0)) > 0.0 else 0.0


func on_kill(e: Node2D) -> void:
	## Wildfire (Fire T5): a foe that dies burning bursts into sparks.
	var v := float(per("w_wildfire", [60, 100], 0)) / 100.0
	if v <= 0.0 or world == null or e == null or not is_instance_valid(e):
		return
	var st = e.get("status")
	if not (burning(e) or (st is Dictionary and float(st.get("burn", 0.0)) > 0.0)):
		return
	wildfires += 1
	var at: Vector2 = e.center()
	var near: Array = []
	for o in world.enemies:
		if o != e and o.alive and o.active and o.center().distance_to(at) <= WILDFIRE_AIM:
			near.append(o)
	near.sort_custom(func(a, b): return a.center().distance_to(at) < b.center().distance_to(at))
	for i in WILDFIRE_N:
		# At the nearest foes (one each), else out and up on its own line.
		var dir := Vector2(float([-1, 0, 1][i]) * 0.8, -0.6).normalized() if i != 1 else Vector2(0, -1)
		if i < near.size():
			dir = (near[i].center() - at).normalized()
		var s: Dictionary = world.spawn_shot({"kind": "spark", "pos": at, "vel": dir * SPARK_SPEED, "life": SPARK_LIFE,
				"coef": v, "light": 0.0, "how": "shot", "on_hit": _spark_hit, "wildfire": true})
		_wild.append(s)   # not hers to count against the three in flight
	burst(at, 14, Color("ffb050"), 160.0, 0.4, 200.0, 2.4, 40.0)
	sfx("flare_burst", 1.4, "relight")


func _spark_hit(_s: Dictionary, e: Node2D, res: Dictionary) -> void:
	var kindle := float(per("w_kindle", [15, 22, 30], 0)) / 100.0
	if kindle > 0.0 and res.get("hit", false) and e.alive:
		add_dot(e, kindle, 2.0, "kindle")


func _tip() -> Vector2:
	## Where the spells leave from: the staff's tip as play sees it (fixed, so
	## aim never hangs on the animation): held out front, or raised overhead
	## while a flare charges.
	if charging:
		return player.center() + Vector2(player.facing * 6.0, -34.0)
	return player.center() + Vector2(player.facing * 16.0, -6.0)


func _staff() -> Vector2:
	## The staff's tip as drawn (for the charge's glow).
	var rig = world.rig if world != null else null
	if rig != null and rig.has_method("weapon_point"):
		return rig.weapon_point()
	return _tip()


# ---------------------------------------------------------------- the flare

func special_pressed() -> void:
	if player.res < COST_MIN:
		sfx("fizzle", 1.0, "bump")
		burst(_tip(), 6, Color("8b90a8"), 60.0, 0.4, -40.0, 2.0)
		return
	charging = true
	charge = 0.0
	_hum = sfx("flare_charge", 1.0, "")   # a held sound: let go on the throw


func special_held(_dt: float) -> void:
	if not charging:
		return
	var was := charge
	charge = minf(clampf((special_hold - TAP) / (CHARGE_TIME - TAP), 0.0, 1.0), _max_charge())
	if charge >= 1.0 and was < 1.0:
		burst(_tip(), 10, Color("fff4cf"), 90.0, 0.3, 0.0, 2.0)
		haptic(10)


func special_released(_held_for: float) -> void:
	if not charging:
		return
	charging = false
	player.jump_lock = false
	_end_hum()
	throw_flare(charge)


func throw_flare(frac: float) -> Dictionary:
	## Lobs a flare at this charge (0..1). It bursts on what it meets.
	if world == null:
		return {}
	spend(lerpf(COST_MIN, COST_MAX, frac))
	_pause = REGEN_PAUSE
	_cast_t = 0.0
	var coef := lerpf(1.8, _full_coef(), frac)
	var vel := Vector2(player.facing * FLARE_V.x + 0.5 * player.velocity.x, FLARE_V.y)
	var s: Dictionary = world.spawn_shot({"kind": "flare", "pos": _tip(), "vel": vel, "g": FLARE_G, "life": FLARE_LIFE,
			"coef": coef, "how": "skill", "light": 90.0, "radius": 8.0, "frac": frac, "quiet": true})
	s["on_hit"] = func(sh, e, _res): _burst(sh, e)
	s["on_end"] = func(sh): _burst(sh, null)
	_flares.append(s)
	sfx("flare_throw", 1.0, "slash")
	return s


func holding_special() -> bool:
	return charging   # a charge held: no vine catch until it's thrown


func _burst(s: Dictionary, direct: Node2D) -> void:
	## The flare goes off: the blast, the fire floor, the Beacon.
	if s.get("burst", false):
		return
	s["burst"] = true
	bursts += 1
	var frac: float = s.get("frac", 0.0)
	var child: bool = s.get("child", false)
	var p: Vector2 = _out_of_stone(s["pos"], s["vel"])
	var r := 34.0 if child else lerpf(44.0, 70.0, frac)
	var coef: float = s["coef"]
	for e in enemies_near(p, r):
		if e == direct:
			continue
		var extra := 0.15 if rank("w_kindle") > 0 and burning(e) else 0.0
		deal_as("flare", e, coef, {"how": "skill", "heavy": true, "from_x": p.x, "extra_pct": extra})
	var seal := float(per("w_seal", [1.5, 2.0, 2.5], 0))
	if seal > 0.0:
		for e in enemies_near(p, r):
			# A boss's tells and windows keep their time, as with every other
			# slow, stun and root in the kits; the wax still shows on him.
			if not is_boss(e):
				e.apply_status("slow", seal)
			e.apply_status("waxed", seal)
	world.freeze(0.06)
	shake(4.0 if not child else 2.0)
	burst(p, 26 if not child else 12, Color("ffb050"), 230.0, 0.55, 250.0, 3.0, 80.0)
	burst(p, 10, Color("fff4cf"), 120.0, 0.35, 0.0, 2.4)
	world.dust_at(p)
	sfx("flare_burst", 1.0, "relight")
	haptic(18)
	# Burning ground where it lands.
	var fy := floor_below(p + Vector2(0, -6), 40.0)
	if fy < INF:
		var w := r * 1.3
		pulse(world.add_hazard({"kind": "fire", "owner": "player", "motion": "still", "life": FIRE_LIFE,
				"rect": Rect2(p.x - w * 0.5, fy - 14.0, w, 14.0), "flat": basic_flat(0.3)}), 0.5)
	if child:
		return
	# The Beacon: a light that lingers (one at a time).
	if beacon >= 0:
		world.remove_light(beacon)
	beacon_pos = Vector2(p.x, (fy if fy < INF else p.y) - 26.0)
	var br := BEACON_R * (1.3 if _equipped("bellows") else 1.0)
	beacon = world.add_light(beacon_pos, br, 0.9, BEACON_LIFE, "beacon")
	beacon_t = BEACON_LIFE
	beacon_r = br
	_ever_t = 0.0
	if frac >= 1.0 and _flag("sunburst"):
		# Sunburst: four little flares scatter from a full one.
		for i in 4:
			var kid: Dictionary = world.spawn_shot({"kind": "flare", "pos": p + Vector2(0, -8), "vel": Vector2([-170.0, -70.0, 70.0, 170.0][i], -300.0),
					"g": FLARE_G, "life": 0.9, "coef": coef * 0.4, "how": "skill", "light": 0.0, "child": true, "quiet": true})
			kid["on_hit"] = func(sh, e, _res): _burst(sh, e)
			kid["on_end"] = func(sh): _burst(sh, null)
			_flares.append(kid)


func _everburn(dt: float) -> void:
	## The Everburning Taper: while the Beacon hangs, every foe inside its
	## light takes a burn tick (no roll, no crit, no hitstop).
	var fx: Dictionary = stats().get("flags", {})
	if beacon_t <= 0.0 or not fx.has("everburning_coef"):
		return
	var every := maxf(float(fx.get("everburning_tick", 0.5)), 0.1)
	_ever_t += dt
	if _ever_t < every:
		return
	_ever_t -= every
	var flat := basic_flat(float(fx["everburning_coef"]))
	var any := false
	for e in enemies_near(beacon_pos, beacon_r):
		if e.alive:
			any = true
			e.apply_status("burn", every + 0.1)
			deal_as("dot", e, 1.0, {"how": "burn", "flat": flat, "no_hitstop": true})
	if any:
		everburns += 1


func _equipped(id: String) -> bool:
	var g = world.get_node_or_null("/root/Game") if world != null else null
	return g != null and g.equipped(id)


func _out_of_stone(p: Vector2, v: Vector2) -> Vector2:
	## A flare that struck stone is inside the tile: step it back out.
	var q := p
	var back := -v.normalized() * 2.0 if v.length() > 1.0 else Vector2(0, -2)
	for i in 20:
		if not world.solid_at(q):
			break
		q += back
	return q


# ---------------------------------------------------------------- drift

func air_jump() -> bool:
	return player.start_drift()


# ---------------------------------------------------------------- the rest

func filter_damage(amount: float, _h: Dictionary) -> float:
	## Candlewax Skin: part of each blow is paid from Melt instead.
	var share := float(per("w_waxskin", [20, 35], 0)) / 100.0
	if share <= 0.0 or player.invuln > 0.0 or player.dash_flags.get("invuln", false) or player.res <= 0.0:
		return amount
	var paid := minf(amount * share, player.res)
	player.res -= paid
	_pause = REGEN_PAUSE
	return amount - paid


func on_snuffed() -> bool:
	## Wax Effigy: once per altar, a wax double takes the snuff, bursts as a
	## full flare, and she lights again at 30%.
	if not _flag("effigy") or _effigy_used or world == null:
		return false
	_effigy_used = true
	player.hp = player.max_hp * 0.3
	player.invuln = maxf(player.invuln, 1.5)
	_effigy = {"p": player.position, "t": 1.2, "facing": player.facing}
	_burst({"pos": player.center(), "vel": Vector2.ZERO, "coef": _full_coef(), "frac": 1.0}, null)
	say(player.center() + Vector2(0, -46), "Wax Effigy")
	return true


func on_respawn() -> void:
	charging = false
	player.jump_lock = false
	_end_hum()
	_dots.clear()


func _end_hum() -> void:
	## The charge's sound stops with the charge (it would ring on over the throw).
	release_sfx(_hum)
	_hum = null


func on_level_start() -> void:
	on_respawn()
	beacon = -1
	beacon_t = 0.0


func put_out_beacon() -> void:
	## A Stillmaw swallowed the Beacon (MB's stillmaw.gd calls this): its
	## light is gone, and so is its time.
	if beacon >= 0 and world != null and world.has_method("remove_light"):
		world.remove_light(beacon)
	beacon = -1
	beacon_t = 0.0


func lights() -> Array:
	if charging:
		return [{"p": _staff(), "r": 34.0 + 60.0 * charge, "s": 0.6}]
	return []


func button_state() -> Dictionary:
	var p := player
	if p == null:
		return {}
	return {"fill": p.res / maxf(p.res_max, 0.001), "ready": p.res >= COST_MIN, "grey": p.res < COST_MIN,
			"pips": 0, "pips_max": 0, "ring": charge if charging else 0.0, "icon": "witch"}


func pose(k: Dictionary) -> Dictionary:
	if player == null:
		return {}
	if charging:
		# The staff raised overhead, trembling as it fills.
		var tr := sin(_t * 55.0) * 0.05 * charge
		return {"arm_f": -2.45 + tr, "weapon_rel": 2.75 - tr, "arm_b": -0.5 - 0.4 * charge, "lean": -0.06}
	if player.drifting and not k.get("grounded", false) and player.velocity.y >= 0.0:
		# Drifting down like a seed, arms out, hat brim fluttering.
		var fl := sin(_t * 14.0) * 0.08
		return {"arm_b": -2.3 + fl, "arm_f": -2.0 - fl, "leg_b": 0.15, "leg_f": 0.05, "cape": -1.3 + fl, "weapon_rel": 2.3}
	if _cast_t < 0.16:
		# A staff thrust.
		var q := clampf(_cast_t / 0.16, 0.0, 1.0)
		var arm := lerpf(-1.4, -0.9, q)
		return {"arm_f": arm, "weapon_rel": 1.1 - arm, "lean": 0.08}
	return {}


func draw(glow: Node2D) -> void:
	if player == null or world == null:
		return
	# The charge gathering at the staff's tip.
	if charging:
		var tp := _staff()
		var j := Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 1.2 * charge
		glow.draw_circle(tp + j, 6.0 + 9.0 * charge, Color(1.0, 0.6, 0.2, 0.22))
		glow.flame(tp + j + Vector2(0, 4), 5.0 + 9.0 * charge, _t * 3.0)
		glow.draw_circle(tp + j, 1.8 + 2.2 * charge, Color("fff4cf"))
		if charge >= 1.0:
			glow.draw_arc(tp, 14.0 + 2.0 * sin(_t * 20.0), 0, TAU, 20, Color(1.0, 0.85, 0.5, 0.7), 1.6)
	# The Beacon: a flame that hangs where the flare burst.
	if beacon_t > 0.0:
		var fade := clampf(beacon_t / 1.0, 0.0, 1.0)
		var bp := beacon_pos + Vector2(0, sin(_t * 2.2) * 2.0)
		glow.draw_circle(bp, 16.0, Color(1.0, 0.7, 0.3, 0.12 * fade))
		glow.draw_arc(bp, 11.0, 0, TAU, 24, Color(1.0, 0.85, 0.5, 0.45 * fade), 1.4)
		if fade > 0.05:
			glow.flame(bp + Vector2(0, 5), 13.0 * fade, bp.x)
	# The Effigy: a wax double slumping where the blow fell.
	if not _effigy.is_empty():
		var q := clampf(_effigy["t"] / 1.2, 0.0, 1.0)
		var ep: Vector2 = _effigy["p"]
		var h := 34.0 * q
		glow.draw_rect(Rect2(ep.x - 9.0, ep.y - h, 18.0, h), Color(0.96, 0.92, 0.84, 0.55 * q))
		glow.draw_circle(Vector2(ep.x, ep.y - h), 8.0 * q, Color(0.96, 0.92, 0.84, 0.55 * q))
		glow.draw_rect(Rect2(ep.x - 14.0 * (1.2 - q), ep.y - 3.0, 28.0 * (1.2 - q), 3.0), Color(0.96, 0.92, 0.84, 0.6))
	# Drift's little puffs of smoke.
	for d in _drift_puffs:
		var a: float = 1.0 - d["t"] / 0.6
		glow.draw_circle(d["p"], 3.0 + d["t"] * 8.0, Color(0.82, 0.8, 0.92, 0.38 * a))
