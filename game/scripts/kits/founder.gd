extends "res://scripts/kits/kit.gd"
## Bellfounder: the Maul (the player's own swing, a big overhead box; every
## hit staggers whatever its poise, and from above it flips a Thornback onto
## its back), Heat (+12 for the first foe a swing hits, +4 each after, +6 when
## hurt, +8 a kill; after 2.5 s without a hit it cools at 8/s), and the Peal
## for 35 Heat: on the ground a slam (2.0x within 44 px) and two floor waves
## that run each way and stop at walls and edges; in the air an Anvil Drop
## that keeps its sideways speed, falls at 900 px/s untouchable, and lands
## harder the further it fell. At full Heat the Peal is Molten: it spends it
## all, and the waves run twice as far, hit half again as hard and leave
## fire. Stampede lives in player.gd; here, the foes it bowls over. With
## the Cracked Tenor (a charm) a wave that runs its full course cracks in
## two there: one runs on and one runs back, each at 60% for half the run.
##
## v3: the Peal root runs to 7 ranks (and an 8th for of the Keeper); Molten
## Core (Forge T5): white-hot or Molten, harm taken is cut v%; Carillon (Bell
## T5): Peal waves run v% further. A Stampede bowls over Tickwinds and
## Glassmites too, and a Rootling once it's up out of the ground.

const HEAT_FIRST := 12.0
const HEAT_EXTRA := 4.0
const HEAT_HURT := 6.0
const HEAT_KILL := 8.0
const COOL_AFTER := 2.5
const COOL_RATE := 8.0
const SLAM_R := 44.0
const SLAM_COEF := 2.0
const WAVE_SPEED := 260.0
const ANVIL_FALL := 900.0
const BOWLED := ["skeleton", "bat", "dripkin", "tickwind", "glassmite", "rootling"]   # what a Stampede knocks flat
const UP_STATES := ["dazed", "walk"]   # a Rootling is bowled only up out of the ground (p_monsters §5.1)
# The Peal root by rank (spec §2.2): v2's 5, ranks 6 and 7, and an 8th for of the Keeper.
const PEAL_COST := [35, 34, 32, 30, 28, 27, 26, 26]
const PEAL_COEF := [1.2, 1.35, 1.5, 1.65, 1.8, 1.95, 2.1, 2.1]
const PEAL_RANGE := [150, 165, 180, 195, 210, 220, 230, 230]
const HEAT := Color("ff6a2a")
const SPLIT_COEF := 0.6          # the Cracked Tenor's halves: this share of the wave...
const SPLIT_RUN := 0.5           # ...for this share of its run

var anvil := false               # mid Anvil Drop
var peals := 0                   # (tests)
var splits := 0                  # Cracked Tenor waves cracked (tests)
var molten_t := 0.0              # Crucible: seconds of Molten left
var _anvil_y := 0.0
var _anvil_molten := false
var _since_hit := 99.0
var _swing_id := -1
var _swing_hits := 0
var _bell_count := 0             # The Great Bell: maul hits toward the next ring
var _impact := 9.0               # since the last maul impact (the squash)
var _slam_fx: Array = []         # rings {p, r, t}
var _molten_waves: Array = []    # {h, last_x}
var _waves: Array = []           # the Peal's waves {h, x0}: their trails are drawn
var _t := 0.0
var _bounces := 0


func setup(p: Node2D, w: Node) -> void:
	super(p, w)
	cls = "founder"
	_bounces = int(p.bounces)
	if not p.landed.is_connected(_on_landed):
		p.landed.connect(_on_landed)


func _cost() -> float:
	return float(per("f_peal", PEAL_COST, 35))


func _wave_coef() -> float:
	return float(per("f_peal", PEAL_COEF, 1.2))


func _wave_range() -> float:
	## Carillon (Bell T5): the waves run v% further.
	return float(per("f_peal", PEAL_RANGE, 150)) * (1.0 + float(per("f_carillon", [20, 35], 0)) / 100.0)


func _molten_core() -> float:
	return float(per("f_moltencore", [15, 25], 0)) / 100.0


func bowlable(src) -> bool:
	## Can a Stampede bowl this foe over? A kind of BOWLED (a boss never);
	## a kind that answers bowlable() itself decides (a Rootling under the
	## ground can't be), else a Rootling only in one of its UP_STATES.
	if src == null or not is_instance_valid(src) or is_boss(src):
		return false
	var k := str(src.get("kind"))
	if not (k in BOWLED):
		return false
	if src.has_method("bowlable"):
		return bool(src.bowlable())
	if k == "rootling":
		if src.get("buried") == true:
			return false
		var st = src.get("state")
		if st == null:
			st = src.get("_state")
		return st != null and str(st) in UP_STATES
	return true


func _flag(f: String) -> bool:
	return stats().get("flags", {}).has(f)


func _extra() -> float:
	return 0.3 if molten_t > 0.0 else 0.0


func white_hot() -> bool:
	return player.res >= player.res_max - 0.01 or molten_t > 0.0


# ---------------------------------------------------------------- the tick

func step(dt: float, _pad: Dictionary) -> void:
	_t += dt
	_impact += dt
	if world != null:
		tick_dots(dt)
		tick_pulses(dt)
	# Heat cools once the hitting stops.
	_since_hit += dt
	var bellows := float(per("f_bellows", [50, 90], 0)) / 100.0
	if _since_hit > COOL_AFTER + rank("f_bellows") and molten_t <= 0.0:
		player.res = maxf(player.res - COOL_RATE * (1.0 - bellows) * dt, 0.0)
	if molten_t > 0.0:
		molten_t -= dt
		if molten_t <= 0.0:
			player.res = 0.0   # the Crucible burns itself out
	elif _flag("crucible") and player.res >= player.res_max - 0.01:
		molten_t = 6.0
		say(player.center() + Vector2(0, -46), "Molten!")
		burst(player.center(), 20, HEAT, 200.0, 0.6, -40.0, 2.6)
	# Aftershock: her stomps stun and send a small wave each way.
	var b := int(player.bounces)
	if b != _bounces:
		_bounces = b
		if anvil:
			_on_landed(0.0)   # an Anvil Drop that lands on a head slams there (world.gd ends the drop)
		if rank("f_after") > 0 and world != null:
			_stomp_shock()
	# The Anvil Drop: a fall cut short by a pit or a hurt ends it.
	if anvil and player.dash_time <= 0.0 and not player.on_floor:
		anvil = false
	if player.stampeding and world != null:
		# Bricks shatter on contact.
		break_ahead(1 if player.velocity.x > 0.0 else -1, absf(player.velocity.x) * dt + 3.0)
	for f in _slam_fx:
		f["t"] += dt
	_slam_fx = _slam_fx.filter(func(f): return f["t"] < 0.4)
	_trail_fire()
	# The waves' trails fade once a wave is spent; each kicks up grit as it goes.
	var cracked: Array = []
	for wv in _waves:
		var h: Dictionary = wv["h"]
		if h["life"] > 0.0:
			if fmod(_t, 0.04) < dt:
				burst(Vector2(h["rect"].get_center().x, h["rect"].end.y - 2.0), 1, Color("ffcf7a"), 70.0, 0.3, 400.0, 1.8, 90.0)
		else:
			if wv["fade"] == 0.0:
				cracked.append(wv)
			wv["fade"] += dt
	_waves = _waves.filter(func(wv): return wv["fade"] < 0.3)
	for wv in cracked:
		_crack(wv)
	# Embers off a white-hot maul; dust and sparks from a Stampede.
	if white_hot() and fmod(_t, 0.08) < dt:
		burst(_head(), 1, Color("ffb050"), 40.0, 0.4, -120.0, 1.8)
	if player.stampeding and player.on_floor and fmod(_t, 0.05) < dt:
		burst(player.position + Vector2(-player.facing * 8.0, -2.0), 2, Color("ffcf7a"), 60.0, 0.3, 200.0, 1.8, 40.0)


# ---------------------------------------------------------------- the maul

func basic() -> bool:
	return false   # the player's own swing, with the maul's reach from classes.gd


func melee_coef() -> float:
	return 1.3 if molten_t > 0.0 else 1.0


func attack_box(r: Rect2) -> Rect2:
	# Overhead: the arc starts above and a little behind the head.
	return Rect2(r.position.x - player.facing * 6.0, r.position.y - 8.0, r.size.x + 6.0, r.size.y + 4.0)


func on_hit_landed(e: Node2D, res: Dictionary) -> void:
	if not res.get("hit", false) or not melee_hit(e, res):
		return
	_since_hit = 0.0
	var first: bool = _swing_id != player.attack_id
	if first:
		_swing_id = player.attack_id
		_swing_hits = 0
	_swing_hits += 1
	var gain := (HEAT_FIRST if first else HEAT_EXTRA) + float(per("f_stoked", [6, 12], 0))
	_heat(gain)
	# Every blow staggers, poise or not; from above, a Thornback goes over.
	if e.alive and not is_boss(e):
		e.apply_status("stun", 0.22)
		e.velocity.x = player.facing * 190.0
		if e.kind == "thornback" and not player.on_floor and player.position.y < e.center().y:
			e.apply_status("flipped", 2.5)
			say(e.center() + Vector2(0, -26), "Flipped!")
	var slag := float(per("f_slag", [12, 18, 24], 0)) / 100.0
	if molten_t > 0.0:
		slag = maxf(slag, 0.12)
	if slag > 0.0 and e.alive:
		add_dot(e, slag, 2.0, "slag")
	if first:
		_impact = 0.0
		world.freeze(0.06)   # the maul lands heavy
		shake(3.0)
		sfx("maul_hit", 1.0, "")
		if _flag("greatbell"):
			_bell_count += 1
			if _bell_count >= 5:
				_bell_count = 0
				_great_bell()


func _heat(n: float) -> void:
	if molten_t > 0.0:
		return
	player.res = minf(player.res + n, player.res_max)


func on_hurt(_amount: float) -> void:
	_heat(HEAT_HURT)


func on_kill(_e: Node2D) -> void:
	_heat(HEAT_KILL)


func _great_bell() -> void:
	## The Great Bell: every 5th maul hit tolls a ring that staggers everything.
	var c: Vector2 = player.center()
	for e in enemies_near(c, 96.0):
		deal_as("bell", e, 1.5, {"how": "skill", "no_hitstop": true, "from_x": c.x, "extra_pct": _extra()})
		if e.alive and not is_boss(e):
			e.apply_status("stun", 0.8)
	_slam_fx.append({"p": c, "r": 96.0, "t": 0.0})
	sfx("peal", 1.3, "bell")
	shake(5.0)


# ---------------------------------------------------------------- the peal

func special_pressed() -> void:
	if anvil:
		return
	var free := molten_t > 0.0
	if not free and player.res < _cost():
		# Not hot enough: a dull clank and a puff of soot.
		sfx("clank", 1.0, "clang")
		burst(_head(), 8, Color("6a6272"), 60.0, 0.5, -30.0, 3.0)
		# Once per save, in words (the clank is lost with the sound off).
		if world != null and world.has_method("bark"):
			world.bark("special_empty_founder")
		return
	var molten: bool = free or player.res >= player.res_max - 0.01
	if molten and not free:
		player.res = 0.0   # a Molten Peal spends all of it
	elif not free:
		spend(_cost())
	_since_hit = 0.0
	peals += 1
	if player.on_floor:
		_peal(player.position, SLAM_R, molten)
	else:
		# Anvil Drop: straight down at 900 px/s, keeping the sideways speed.
		anvil = true
		_anvil_y = player.position.y
		_anvil_molten = molten
		player.dash(Vector2(player.velocity.x, ANVIL_FALL), 3.0, {"no_grav": true, "stop_at_wall": false, "anvil": true})
		sfx("anvil_drop", 1.0, "")


func _on_landed(_impact_v: float) -> void:
	if not anvil:
		return
	anvil = false
	player.end_dash()
	var fell_px: float = maxf(player.position.y - _anvil_y, 0.0)
	_peal(player.position, minf(SLAM_R + 0.2 * fell_px, 100.0), _anvil_molten)
	# It breaks the brick she lands on.
	if world != null:
		var ty := floori((player.position.y + 2.0) / 32.0)
		for x in [player.position.x - 8.0, player.position.x + 8.0]:
			var cell := Vector2i(floori(x / 32.0), ty)
			if world.level.is_breakable(world.level.tile(cell.x, cell.y)):
				world.break_tile(cell)


func _peal(at: Vector2, r: float, molten: bool) -> void:
	## The slam and its two waves.
	if world == null:
		return
	var c := at + Vector2(0, -14)
	var stun := float(per("f_after", [0.6, 0.9, 1.2], 0.3))
	for e in enemies_near(c, r):
		deal_as("peal", e, SLAM_COEF, {"how": "skill", "heavy": true, "from_x": at.x, "extra_pct": _extra()})
		if e.alive and not is_boss(e):
			e.apply_status("stun", stun)
			e.velocity = Vector2(signf(e.position.x - at.x) * 150.0, -200.0)
	var coef := _wave_coef() * (1.5 if molten else 1.0)
	var reach := _wave_range() * (2.0 if molten else 1.0)
	for d in [-1, 1]:
		var h: Dictionary = world.add_hazard({"kind": "wave", "owner": "player", "motion": "floor", "life": reach / WAVE_SPEED,
				"rect": Rect2(at.x + d * 14.0 - 9.0, at.y - 22.0, 18.0, 22.0), "vel": Vector2(d * WAVE_SPEED, 0.0), "coef": coef,
				"molten": molten, "special": true})   # the Special's own waves: special_pct counts on them
		_waves.append({"h": h, "x0": at.x, "fade": 0.0, "run": reach})
		if molten:
			_molten_waves.append({"h": h, "last_x": at.x})
	# Bricks at her feet and beside her crack.
	var cx := floori(at.x / 32.0)
	var cy := floori((at.y - 8.0) / 32.0)
	for dx in [-1, 0, 1]:
		for dy in [0, 1]:
			var cell := Vector2i(cx + dx, cy + dy)
			if world.level.is_breakable(world.level.tile(cell.x, cell.y)) and Vector2(cell.x * 32 + 16, cell.y * 32 + 16).distance_to(c) < r + 16.0:
				world.break_tile(cell)
	_impact = 0.0
	_slam_fx.append({"p": at, "r": r, "t": 0.0})
	world.freeze(0.07)
	shake(7.0 if molten else 5.0)
	haptic(30)
	world.dust_at(at + Vector2(-12, 0))
	world.dust_at(at + Vector2(12, 0))
	burst(at + Vector2(0, -4), 22, Color("ffcf7a") if not molten else Color("ff8a3a"), 240.0, 0.45, 300.0, 2.6, 60.0)
	sfx("peal", 1.0, "boss_slam")


func _crack(wv: Dictionary) -> void:
	## The Cracked Tenor: a Peal wave that ran its whole course (not one a
	## wall or an edge stopped) splits where it ends, one half running on and
	## one running back, each hitting afresh.
	var n := int(stats().get("flags", {}).get("cracked_tenor_split", 0))
	if n <= 0 or world == null or not wv.has("run"):
		return
	var h: Dictionary = wv["h"]
	var r: Rect2 = h["rect"]
	var x := r.get_center().x
	if absf(x - float(wv["x0"])) - 14.0 < float(wv["run"]) - 8.0:
		return   # stopped short by a wall or an edge (it set out 14 px from her)
	var d := signf(h["vel"].x)
	var molten: bool = h.get("molten", false)
	var run := float(wv["run"]) * SPLIT_RUN
	for i in n:
		var dir := d if i % 2 == 0 else -d
		var kid: Dictionary = world.add_hazard({"kind": "wave", "owner": "player", "motion": "floor", "life": run / WAVE_SPEED,
				"rect": Rect2(x + dir * 6.0 - 7.0, r.end.y - 16.0, 14.0, 16.0), "vel": Vector2(dir * WAVE_SPEED, 0.0),
				"coef": float(h["coef"]) * SPLIT_COEF, "molten": molten, "special": h.get("special", false)})
		_waves.append({"h": kid, "x0": x, "fade": 0.0})   # no "run": a half never cracks again
		if molten:
			_molten_waves.append({"h": kid, "last_x": x})
	splits += 1
	burst(Vector2(x, r.end.y - 4.0), 10, Color("ffcf7a"), 150.0, 0.35, 300.0, 2.2, 60.0)
	sfx("peal", 1.6, "bell")   # the tenor's cracked high note


func _stomp_shock() -> void:
	var stun := float(per("f_after", [0.6, 0.9, 1.2], 0.6))
	var at: Vector2 = player.position + Vector2(0, 30)
	for e in enemies_near(at, 44.0):
		if e.alive and not is_boss(e):
			e.apply_status("stun", stun)
	# A bounce off a boss (his window's target, a bell, a seed) throws no
	# waves: with no input the bounce lands on the blossom or the spring
	# about every 0.24 s, and two waves a bounce took a whole phase from one
	# stomp (the int2 review: 35% with Aftershock, 23.8% without).
	if bool(world.get("last_stomp_boss")):
		return
	var fy := floor_below(at, 80.0)
	if fy == INF:
		return
	for d in [-1, 1]:
		# stomp_born: a v3 boss pays these as it pays the bounce that threw
		# them (boss_rig: only the window's first stomp's are full).
		world.add_hazard({"kind": "wave", "owner": "player", "motion": "floor", "life": 90.0 / WAVE_SPEED, "coef": 0.6,
				"rect": Rect2(player.position.x + d * 12.0 - 7.0, fy - 16.0, 14.0, 16.0), "vel": Vector2(d * WAVE_SPEED, 0.0),
				"stomp_born": true})


func _trail_fire() -> void:
	## A Molten wave leaves burning floor behind it.
	if world == null:
		return
	for m in _molten_waves:
		var h: Dictionary = m["h"]
		if h["life"] <= 0.0:
			continue
		var x: float = h["rect"].get_center().x
		if absf(x - m["last_x"]) >= 36.0:
			m["last_x"] = x
			var fy: float = h["rect"].end.y
			pulse(world.add_hazard({"kind": "fire", "owner": "player", "motion": "still", "life": 2.0,
					"rect": Rect2(x - 18.0, fy - 14.0, 36.0, 14.0), "flat": basic_flat(0.25)}), 0.5)
	_molten_waves = _molten_waves.filter(func(m): return m["h"]["life"] > 0.0)


# ---------------------------------------------------------------- harm

func filter_damage(amount: float, h: Dictionary) -> float:
	var src = h.get("source")
	var kind: String = str(h.get("kind", "hit"))
	# Falling like an anvil: nothing that touches her counts.
	if anvil and kind in ["hit", "spikes"] and is_enemy(src):
		return 0.0
	# Stampede: small foes are bowled over instead of hurting her.
	if player.stampeding and kind == "hit" and is_enemy(src) and bowlable(src):
		var res := deal_as("bowl", src, 1.0, {"how": "skill", "heavy": true, "from_x": player.position.x - player.facing * 20.0, "extra_pct": _extra()})
		if res["hit"] and src.alive:
			src.apply_status("stun", 0.6)
			src.velocity = Vector2(player.facing * 260.0, -240.0)
		burst(src.center(), 10, Color("ffcf7a"), 180.0, 0.35, 200.0, 2.4)
		shake(3.0)
		return 0.0
	var core := _molten_core()
	if core > 0.0 and white_hot() and amount > 0.0:
		# Molten Core (Forge T5): white-hot, the harm is cut.
		return amount * (1.0 - core)
	return amount


func on_respawn() -> void:
	anvil = false
	molten_t = 0.0
	player.res = 0.0
	_since_hit = 99.0
	_molten_waves.clear()
	_dots.clear()


func on_reset() -> void:
	anvil = false   # an Anvil Drop into lava doesn't slam where she's put back


func on_level_start() -> void:
	on_respawn()


func _head() -> Vector2:
	var rig = world.rig if world != null else null
	if rig != null and rig.has_method("weapon_point"):
		return rig.weapon_point()
	return player.center() + Vector2(player.facing * 16.0, -14.0)


func lights() -> Array:
	if white_hot():
		return [{"p": _head(), "r": 60.0 + 6.0 * sin(_t * 9.0), "s": 0.55}]
	return []


func button_state() -> Dictionary:
	var p := player
	if p == null:
		return {}
	var ok: bool = molten_t > 0.0 or p.res >= _cost()
	return {"fill": p.res / maxf(p.res_max, 0.001), "ready": ok, "grey": not ok,
			"pips": _bell_count if _flag("greatbell") else 0, "pips_max": 5 if _flag("greatbell") else 0,
			"ring": 1.0 if white_hot() else 0.0, "icon": "founder"}


func pose(k: Dictionary) -> Dictionary:
	if player == null:
		return {}
	var o := {}
	if anvil:
		# Maul-first, knees up, the free arm thrown up: coming down like a bell
		# off its beam. (Held overhead, its bell sat over her face.)
		return {"arm_f": 0.35, "arm_b": -2.5, "weapon_rel": 2.75, "leg_b": 0.9, "leg_f": -1.0, "cape": -1.3, "lean": 0.05}
	var at: float = k.get("attack_time", -1.0)
	if at >= 0.0:
		# Overhead: wound up behind, brought down in front.
		var q := clampf(at / player.ATTACK_ACTIVE, 0.0, 1.0)
		q = 1.0 - pow(1.0 - q, 3.0)
		if at > player.ATTACK_ACTIVE:
			var back := clampf((at - player.ATTACK_ACTIVE) / 0.12, 0.0, 1.0)
			o["arm_f"] = lerpf(0.2, -0.2, back)
			o["weapon_rel"] = lerpf(1.35, 1.5, back)
		else:
			o["arm_f"] = lerpf(-3.2, 0.2, q)
			o["weapon_rel"] = lerpf(2.6, 1.35, q)
		o["arm_b"] = lerpf(-2.6, -0.4, q)
		o["lean"] = lerpf(-0.1, 0.16, q)
	if _impact < 0.14:
		var s := 1.0 - _impact / 0.14
		o["squash"] = Vector2(1.0 + 0.16 * s, 1.0 - 0.16 * s)
	if player.stampeding and k.get("grounded", false):
		o["lean"] = 0.2
		o["cape"] = -1.2
	return o


func draw(glow: Node2D) -> void:
	if player == null or world == null:
		return
	# White-hot: the maul's bell glows.
	if white_hot():
		var hp := _head()
		var fl := 0.5 + 0.5 * sin(_t * 11.0)
		glow.draw_circle(hp, 10.0 + 2.0 * fl, Color(1.0, 0.55, 0.2, 0.22))
		glow.draw_circle(hp, 5.0, Color(1.0, 0.85, 0.6, 0.55 + 0.3 * fl))
	# The slam's ring of force, and a flash where the maul met stone.
	for f in _slam_fx:
		var q: float = f["t"] / 0.4
		var a := 1.0 - q
		var p: Vector2 = f["p"]
		var r: float = f["r"] * (0.35 + 0.65 * (1.0 - pow(1.0 - q, 2.0)))
		if q < 0.3:
			var flash := PackedVector2Array()
			for i in 17:
				var ang := PI + PI * i / 16.0
				flash.append(p + Vector2(cos(ang) * f["r"] * 0.7, sin(ang) * 16.0))
			glow.draw_colored_polygon(flash, Color(1.0, 0.9, 0.6, 0.35 * (1.0 - q / 0.3)))
		for ring in 2:
			var rr: float = r * (1.0 - 0.3 * ring)
			var pts := PackedVector2Array()
			for i in 25:
				var ang := PI + PI * i / 24.0
				pts.append(p + Vector2(cos(ang) * rr, sin(ang) * rr * 0.45))
			glow.draw_polyline(pts, Color(1.0, 0.85, 0.5, (0.85 - 0.35 * ring) * a), 3.0 - ring)
	# Each wave's wake: a seam of light along the floor behind it.
	for wv in _waves:
		var h: Dictionary = wv["h"]
		var hr: Rect2 = h["rect"]
		var x1 := hr.get_center().x
		var y := hr.end.y - 1.0
		var fade: float = 1.0 - wv["fade"] / 0.3
		var col := Color(1.0, 0.55, 0.25) if h.get("molten", false) else Color(1.0, 0.85, 0.5)
		var x0: float = wv["x0"] + signf(x1 - wv["x0"]) * 10.0
		var mid := lerpf(x0, x1, 0.6)
		glow.draw_line(Vector2(x0, y), Vector2(mid, y), Color(col, 0.18 * fade), 3.0)
		glow.draw_line(Vector2(mid, y), Vector2(x1, y), Color(col, 0.6 * fade), 3.0)
	# The Anvil's streak, flanking her (not across her face).
	if anvil:
		var c: Vector2 = player.center()
		for i in 3:
			var x: float = c.x + [-14.0, 14.0, -20.0][i]
			glow.draw_line(Vector2(x, c.y - 4.0 - i * 4.0), Vector2(x, c.y - 38.0 - i * 8.0), Color(1.0, 0.8, 0.5, 0.45), 2.0)
