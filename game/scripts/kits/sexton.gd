extends "res://scripts/kits/kit.gd"
## Sexton: the Spade (the player's own swing, a low scoop), Dirge (3/s, +6 a
## spade hit, +12 for any kill within 200 px), and the Knell. A tap calls a
## Mourning Wisp (25 Dirge; two at most, three from rank 3): they circle his
## head and loose homing motes at foes within 170 px, but only in the 0.8 s
## after a spade hit or a Knell. With every wisp out, a tap rings them awake
## for 8 Dirge, and a fresh press held 0.3 s (the ring on the button) is
## Toll the Dead (10 Dirge in all): they dive at the nearest foes and burst
## (1.5x in 36 px). A wisp pops to soak 40% of a blow. Grave Step: a second
## jump in the air raises a bone ledge under him for 1 s and he jumps off it;
## it comes back on real ground or a stomp, not on the bone. With The
## Unrung Bell (a charm) Toll the Dead keeps the wisps: copies of them dive
## and the Toll then rests for unrung_bell_cd seconds (the button shows the
## Knell, not the Toll, until it's back).
##
## v3: the Knell root runs to 7 ranks (and an 8th for of the Keeper), with
## three wisps at most from rank 3 on: no new light appears. Requiem (Souls
## T5): the wisps' firing window lasts v% longer after a hit or a Knell.
## Barrow Bind (Grave T5): rooted foes take v% more from him (the spade,
## motes, the Toll). A Stillmaw's Gulp takes a wisp before it takes him
## (decoy). A vine is footing: catching one gives Grave Step back.

const ORBIT_R := 30.0
const ORBIT_PERIOD := 2.4
const MOTE_EVERY := 1.2
const MOTE_RANGE := 170.0
const MOTE_SPEED := 240.0
const MOTE_TURN := 6.0
const FIRE_WINDOW := 0.8
const TOLL_HOLD := 0.3
const TOLL_COST := 10.0
const WAKE_COST := 8.0           # a Knell with every wisp out (it counts toward a Toll)
const TOLL_R := 36.0
const TOLL_COEF := 1.5
const KILL_NEAR := 200.0
const LEDGE_SIZE := Vector2(34, 8)
const LEDGE_LIFE := 1.0
const STEP_JUMP := 0.9           # Grave Step jumps at 90% of a jump
const CHILL_THAW := Classes.CHILL_THAW   # Grave Chill: free seconds after a root before the next one (the card reads the same)
const PALE := Color("c0c8f0")
const CORE := Color("e8ecff")
const BONE := Color("e8e0cc")
# The Knell root by rank (spec §2.2): v2's 5, ranks 6 and 7, and an 8th for
# of the Keeper. Three wisps at most from the root, whatever the rank.
const KNELL_WISPS := [2, 2, 3, 3, 3, 3, 3, 3]
const KNELL_COST := [25, 24, 23, 22, 20, 19, 18, 18]
const KNELL_MOTE := [45, 53, 61, 69, 77, 85, 93, 93]
const ROOT_WISPS_MAX := 3
const GULP_TIME := 0.4           # a gulped wisp's flight into the mouth...
const GULP_PUFF := 0.3           # ...and the pale puff where it goes in

var wisps: Array = []            # {phase, cd, pop}
var fire_window := 0.0           # seconds the wisps may still fire
var toll_cd := 0.0               # The Unrung Bell: seconds until Toll the Dead is back
var motes := 0                   # motes loosed (tests)
var ledges: Array = []           # the World's temporary Movers from Grave Step
var _divers: Array = []          # Toll the Dead in flight {p, e, aim, t}
var _pops: Array = []            # {p, t}
var _remnants: Array = []        # Soul Harvest {p, t}
var _step_used := false
var _bounces := 0
var _holding := false
var _spent_press := false        # this press called a wisp or tolled: no Toll from it
var _paid := 0.0                 # Dirge this press paid to wake them (counts toward a Toll)
var _knell_t := 9.0
var _lastbell_used := false
var _checkpoint := Vector2.INF
var _t := 0.0
var gulped := 0                  # wisps a Stillmaw took instead of him (tests)
var _gulps: Array = []           # {a, b, t}: a gulped wisp on its way into the mouth
var _motes: Array = []           # motes in flight (Barrow Bind rides on them)


func setup(p: Node2D, w: Node) -> void:
	super(p, w)
	cls = "sexton"
	_bounces = int(p.bounces)


func max_wisps() -> int:
	return mini(int(per("x_knell", KNELL_WISPS, 2)), ROOT_WISPS_MAX) + (2 if _flag("choir") else 0)


func _call_cost() -> float:
	return float(per("x_knell", KNELL_COST, 25))


func _mote_coef() -> float:
	return float(per("x_knell", KNELL_MOTE, 45)) / 100.0 * (1.0 + float(per("x_bright", [30, 60], 0)) / 100.0)


func fire_time() -> float:
	## How long the wisps may fire after a spade hit or a Knell: Requiem
	## (Souls T5) makes it last v% longer.
	return FIRE_WINDOW * (1.0 + float(per("x_requiem", [30, 60], 0)) / 100.0)


func _barrow() -> float:
	return float(per("x_barrow", [20, 35], 0)) / 100.0


func bonus_vs(e) -> float:
	## Barrow Bind (Grave T5): a rooted foe takes v% more from him.
	var v := _barrow()
	if v <= 0.0 or e == null or not is_instance_valid(e):
		return 0.0
	var st = e.get("status")
	return v if st is Dictionary and float(st.get("root", 0.0)) > 0.0 else 0.0


func _melee_opts(e) -> Dictionary:
	var b := bonus_vs(e)
	return {"extra_pct": b} if b > 0.0 else {}


func decoy(kind: String, at: Vector2) -> Dictionary:
	## A Stillmaw's Gulp (kind "gulp") takes a wisp before it takes him: the
	## last wisp flies into the mouth at `at`, and the Gulp has its meal.
	if wisps.is_empty() or kind != "gulp":
		return {}
	var i := wisps.size() - 1
	var p := wisp_pos(i)
	wisps.remove_at(i)
	gulped += 1
	_gulps.append({"a": p, "b": at, "t": 0.0})
	burst(p, 8, PALE, 60.0, 0.3, 0.0, 2.0)
	sfx("wisp_pop", 0.8, "")
	return {"p": p, "kind": "wisp"}


func _flag(f: String) -> bool:
	return stats().get("flags", {}).has(f)


func _head() -> Vector2:
	return player.center() + Vector2(0, -30)


func wisp_pos(i: int) -> Vector2:
	## Where wisp i is on its orbit round his head.
	var n := maxi(wisps.size(), 1)
	var a: float = _t * TAU / ORBIT_PERIOD + TAU * i / n
	return _head() + Vector2(cos(a) * ORBIT_R, sin(a) * ORBIT_R * 0.45)


# ---------------------------------------------------------------- the tick

func step(dt: float, _pad: Dictionary) -> void:
	_t += dt
	_knell_t += dt
	fire_window = maxf(fire_window - dt, 0.0)
	toll_cd = maxf(toll_cd - dt, 0.0)
	regen(dt)
	if world == null:
		return
	tick_dots(dt)
	# The bone ledges crumble away (the World would keep an expired one).
	for mv in ledges:
		if mv.life <= 0.0:
			world.movers.erase(mv)
			burst(mv.pos + Vector2(17, 4), 6, BONE, 60.0, 0.4, 300.0, 2.0)
	ledges = ledges.filter(func(mv): return mv.life > 0.0)
	# Grave Step comes back on real ground or a stomp, never on his own bone
	# (else: jump off the bone, Grave Step at the top, land on the new bone,
	# and so on up forever).
	var b := int(player.bounces)
	if (player.on_floor and not ledges.has(player.riding)) or b != _bounces or on_vine():
		_step_used = false   # real ground, a stomp or a vine (never his own bone)
	_bounces = b
	# The Last Bell comes back with each new altar.
	if world.checkpoint != _checkpoint:
		_checkpoint = world.checkpoint
		_lastbell_used = false
	# Wisps: motes only while the window is open.
	for i in wisps.size():
		var w: Dictionary = wisps[i]
		w["cd"] = maxf(w["cd"] - dt, 0.0)
		if fire_window > 0.0 and w["cd"] <= 0.0:
			var at := wisp_pos(i)
			var e: Node2D = world.nearest_enemy(at, MOTE_RANGE)
			if e != null:
				w["cd"] = MOTE_EVERY
				_mote(at, e)
	_step_divers(dt)
	for p in _pops:
		p["t"] += dt
	_pops = _pops.filter(func(p): return p["t"] < 0.35)
	for g in _gulps:
		g["t"] += dt
		if g["t"] >= GULP_TIME and not g.get("in", false):
			g["in"] = true   # swallowed: a pale puff at the mouth
			burst(g["b"], 10, PALE, 70.0, 0.35, 0.0, 2.2)
	_gulps = _gulps.filter(func(g): return g["t"] < GULP_TIME + GULP_PUFF)
	_motes = _motes.filter(func(m): return m["life"] > 0.0)
	if _barrow() > 0.0:
		for m in _motes:
			shot_bonus(m, dt)   # Barrow Bind rides on a mote about to meet a rooted foe
	_step_remnants(dt)


func _mote(at: Vector2, e: Node2D) -> void:
	motes += 1
	var m: Dictionary = world.spawn_shot({"kind": "mote", "pos": at, "vel": (e.center() - at).normalized() * MOTE_SPEED, "life": 1.1,
			"homing": MOTE_TURN, "coef": _mote_coef(), "how": "shot", "light": 0.0, "radius": 5.0, "quiet": true,
			"no_hitstop": true, "special": true})   # the Knell's wisps: special_pct counts on them
	if not m.is_empty():
		_motes.append(m)
	sfx("mote", 1.0, "")


# ---------------------------------------------------------------- the spade

func basic() -> bool:
	return false   # the player's own swing, with the spade's reach from classes.gd


func attack_box(r: Rect2) -> Rect2:
	# A scoop: 6 px lower than a sword's cut, better against what's at his feet.
	return Rect2(r.position + Vector2(0, 6), r.size)


func on_hit_landed(e: Node2D, res: Dictionary) -> void:
	if not res.get("hit", false) or not melee_hit(e, res):
		return
	var bb := bonus_vs(e)
	if bb > 0.0 and not swing_opts_applied(e):
		# Barrow Bind, while the World doesn't take the swing's opts
		# (melee_opts): the share the spade would have added, straight after.
		top_up(e, res, bb / (1.0 + float(stats().get("dmg_pct", 0.0))))
	player.res = minf(player.res + 6.0, player.res_max)
	fire_window = fire_time()
	# Grave Chill: the spade roots a foe, then it has CHILL_THAW s to shake the
	# frost off before the next hit can root it again. (A root is a stun, and
	# the spade swings every 0.3 s: without the thaw a foe never acted again.)
	var chill := float(per("x_chill", [0.6, 0.8, 1.0], 0))
	if chill > 0.0 and e.alive and not is_boss(e) and not e.status.has("chill_cd"):
		e.apply_status("root", chill)
		e.apply_status("chill_cd", chill + CHILL_THAW)
		burst(Vector2(e.center().x, e.rect().end.y), 6, PALE, 50.0, 0.4, -80.0, 2.0)


func on_kill(e: Node2D) -> void:
	if e.center().distance_to(player.center()) <= KILL_NEAR:
		player.res = minf(player.res + 12.0, player.res_max)
	var harvest := float(per("x_harvest", [20, 35, 50], 0)) / 100.0
	if harvest > 0.0 and world != null and world.rng.randf() < harvest:
		_remnants.append({"p": e.center(), "t": 6.0})


# ---------------------------------------------------------------- the knell

func special_pressed() -> void:
	_holding = true
	_spent_press = false
	_paid = 0.0
	if wisps.size() < max_wisps():
		# A call. This press is used up: even held, it never goes on into Toll
		# the Dead (the press that calls the last wisp must not throw them all
		# away). Toll needs a fresh press with every wisp out.
		_spent_press = true
		if not spend(_call_cost()):
			sfx("fizzle", 1.0, "bump")
			return
		call_wisp()
		_ring()
		return
	# Every wisp out: the bell wakes them, for a little Dirge. What it costs
	# counts toward a Toll if this press is held that long.
	if spend(WAKE_COST):
		_paid = WAKE_COST
		_ring()
	else:
		sfx("fizzle", 1.0, "bump")


func _ring() -> void:
	## The Knell: the handbell shaken, and the wisps may fire for a moment.
	_knell_t = 0.0
	fire_window = fire_time()
	sfx("knell", 1.0, "")


func call_wisp() -> void:
	wisps.append({"cd": 0.15 * wisps.size(), "born": _t})
	var at := wisp_pos(wisps.size() - 1)
	burst(at, 10, PALE, 80.0, 0.45, -40.0, 2.2)
	sfx("wisp_call", 1.0, "relic_common")


func special_held(_dt: float) -> void:
	if not _holding or _spent_press or wisps.size() < max_wisps() or special_hold < TOLL_HOLD or toll_cd > 0.0:
		return
	_spent_press = true
	if spend(maxf(TOLL_COST - _paid, 0.0)):
		if on_vine():
			player.release_vine()   # a Toll held into a vine catch lets go of it, as every Special does
		toll()
	else:
		sfx("fizzle", 1.0, "bump")


func special_released(_held: float) -> void:
	_holding = false


func holding_special() -> bool:
	## A press that may still become Toll the Dead (every wisp out, the bell
	## free): no vine catch meanwhile. A call or a Toll already rung is done.
	return _holding and not _spent_press and toll_cd <= 0.0


func toll() -> void:
	## Toll the Dead: every wisp dives at the nearest foes (up to 3) and bursts.
	var targets: Array = world.enemies_in(Rect2(player.center() - Vector2(240, 160), Vector2(480, 320))) if world != null else []
	targets.sort_custom(func(a, b): return a.center().distance_to(player.center()) < b.center().distance_to(player.center()))
	targets = targets.slice(0, 3)
	for i in wisps.size():
		var e: Node2D = targets[i % targets.size()] if targets.size() > 0 else null
		var aim: Vector2 = e.center() if e != null else player.center() + Vector2(player.facing * 70.0, -6.0)
		_divers.append({"p": wisp_pos(i), "e": e, "aim": aim, "t": 0.0, "v": Vector2(0, -120)})
	var keep := float(stats().get("flags", {}).get("unrung_bell_cd", 0.0))
	if keep > 0.0:
		toll_cd = keep   # The Unrung Bell: they dive, and are still here after
		for i in wisps.size():
			wisps[i]["born"] = _t   # re-formed round his head
	else:
		wisps.clear()
	_knell_t = 0.0   # the bell swung once more
	sfx("toll_dead", 1.0, "bell")
	haptic(24)


func _step_divers(dt: float) -> void:
	for d in _divers:
		d["t"] += dt
		var e = d["e"]
		if e != null and is_instance_valid(e) and e.alive:
			d["aim"] = e.center()
		var to: Vector2 = d["aim"] - d["p"]
		# A swoop: up a touch, then down on the target, faster as it goes.
		d["v"] = d["v"].lerp(to.normalized() * (380.0 + 500.0 * d["t"]), 1.0 - exp(-dt * 10.0))
		d["p"] += d["v"] * dt
		if to.length() < 10.0 or d["t"] > 0.55:
			d["done"] = true
			_toll_burst(d["p"])
	_divers = _divers.filter(func(d): return not d.get("done", false))


func _toll_burst(p: Vector2) -> void:
	var hit := []
	for e in enemies_near(p, TOLL_R):
		deal_as("toll", e, TOLL_COEF, {"how": "skill", "heavy": true, "from_x": p.x})
		hit.append(e)
	if _flag("choir") and hit.size() > 0:
		# Choir of the Lost: the toll leaps to one more foe close by.
		for e in enemies_near(p, 80.0):
			if not hit.has(e):
				deal_as("toll", e, TOLL_COEF, {"how": "skill", "no_hitstop": true, "from_x": p.x})
				_pops.append({"p": e.center(), "t": 0.0})
				break
	burst(p, 18, PALE, 170.0, 0.45, 0.0, 2.6)
	burst(p, 8, CORE, 90.0, 0.3, 0.0, 2.0)
	_pops.append({"p": p, "t": 0.0})
	shake(3.0)


# ---------------------------------------------------------------- the dead as armour

func filter_damage(amount: float, h: Dictionary) -> float:
	if wisps.is_empty() or player.invuln > 0.0 or player.dash_flags.get("invuln", false) or amount <= 0.0 \
			or str(h.get("kind", "")) in ["pit", "lava", "water"]:
		return amount
	var soak := float(per("x_ward", [50, 70], 40)) / 100.0 if rank("x_ward") > 0 else 0.4
	var i := wisps.size() - 1
	var at := wisp_pos(i)
	wisps.remove_at(i)
	_pops.append({"p": at, "t": 0.0})
	burst(at, 12, PALE, 120.0, 0.4, 0.0, 2.2)
	sfx("wisp_pop", 1.0, "")
	return amount * (1.0 - soak)


func on_snuffed() -> bool:
	## The Last Bell: the wisps give themselves up to light him again.
	if not _flag("lastbell") or wisps.is_empty() or _lastbell_used:
		return false
	_lastbell_used = true
	player.hp = player.max_hp * minf(0.6, 0.15 * wisps.size())
	player.invuln = maxf(player.invuln, 1.5)
	for i in wisps.size():
		_pops.append({"p": wisp_pos(i), "t": 0.0})
		burst(wisp_pos(i), 10, PALE, 140.0, 0.5, 0.0, 2.4)
	wisps.clear()
	say(player.center() + Vector2(0, -46), "The Last Bell")
	sfx("toll_dead", 0.8, "relight")
	return true


func _step_remnants(dt: float) -> void:
	for r in _remnants:
		r["t"] -= dt
		if player.rect().grow(6.0).has_point(r["p"]):
			r["t"] = 0.0
			if wisps.size() < max_wisps():
				call_wisp()
			else:
				player.res = minf(player.res + 20.0, player.res_max)
	_remnants = _remnants.filter(func(r): return r["t"] > 0.0)


# ---------------------------------------------------------------- Grave Step

func air_jump() -> bool:
	if world == null or _step_used or player.on_floor:
		return false
	_step_used = true
	var mv = world.add_temp_ledge(Rect2(player.position.x - LEDGE_SIZE.x * 0.5, player.position.y, LEDGE_SIZE.x, LEDGE_SIZE.y), LEDGE_LIFE)
	ledges.append(mv)
	player.air_leap(player.JUMP_SPEED * STEP_JUMP)
	burst(player.position + Vector2(0, 3), 8, BONE, 70.0, 0.35, 200.0, 2.0)
	sfx("grave_step", 1.0, "bones")
	return true


# ---------------------------------------------------------------- the rest

func on_respawn() -> void:
	for mv in ledges:
		if world != null:
			world.movers.erase(mv)
	ledges.clear()
	_divers.clear()
	fire_window = 0.0
	_dots.clear()
	_gulps.clear()
	_motes.clear()


func on_level_start() -> void:
	on_respawn()
	wisps.clear()
	toll_cd = 0.0


func lights() -> Array:
	# Each wisp adds to his own light.
	var out := []
	var per_wisp := 18.0 + float(per("x_bright", [6, 12], 0))
	for i in wisps.size():
		out.append({"p": player.center(), "r": per_wisp, "hero": true})
	return out


func _tolling() -> bool:
	## A fresh press held with every wisp out, and the Dirge to finish it:
	## Toll the Dead is gathering (the ring fills).
	return _holding and not _spent_press and wisps.size() >= max_wisps() and player.res + _paid >= TOLL_COST and toll_cd <= 0.0


func button_state() -> Dictionary:
	var p := player
	if p == null:
		return {}
	var full := wisps.size() >= max_wisps()
	var ok: bool = p.res >= (TOLL_COST if full else _call_cost())
	var can_toll := full and toll_cd <= 0.0
	return {"fill": p.res / maxf(p.res_max, 0.001), "ready": ok, "grey": not ok,
			"pips": wisps.size(), "pips_max": max_wisps(),
			"ring": clampf(special_hold / TOLL_HOLD, 0.0, 1.0) if _tolling() else 0.0,
			"icon": "toll" if can_toll else "sexton"}


func pose(k: Dictionary) -> Dictionary:
	if player == null:
		return {}
	var o := {}
	var at: float = k.get("attack_time", -1.0)
	if at >= 0.0:
		# The scoop: from down behind to up in front.
		var q := clampf(at / player.ATTACK_ACTIVE, 0.0, 1.0)
		q = 1.0 - pow(1.0 - q, 2.0)
		if at > player.ATTACK_ACTIVE:
			q = 1.0
		o["arm_f"] = lerpf(0.3, -1.8, q)
		o["weapon_rel"] = lerpf(1.9, 2.3, q)
		o["lean"] = lerpf(0.12, -0.04, q)
	if _knell_t < 0.45 or _tolling():
		# The handbell rung out in front at arm's length, over everything,
		# with the spade swung back out of its way (unless it's swinging).
		o["arm_b"] = -1.55
		o["offhand_off"] = Vector2(9, -4)
		o["offhand_top"] = true
		o["offhand_scale"] = 1.35
		# Swung about upright: the art hangs the bell 45 deg back from the fist
		# and the rig tilts it by arm_b / 4, so -0.40 brings it back to plumb.
		o["offhand_rot"] = -0.40 + sin(_t * 40.0) * 0.4
		if at < 0.0:
			o["arm_f"] = 0.9
			o["weapon_rel"] = -2.2
	return o


func draw(glow: Node2D) -> void:
	if player == null or world == null:
		return
	# Bone ledges (Grave Step): they flicker before they go.
	for mv in ledges:
		var r: Rect2 = Rect2(mv.pos, Vector2(LEDGE_SIZE.x, LEDGE_SIZE.y))
		var a := 1.0 if mv.life > 0.3 else (0.5 + 0.5 * sin(_t * 40.0))
		glow.draw_rect(r.grow(2.0), Color(0.75, 0.72, 1.0, 0.18 * a))
		glow.draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(r.size.x - 6, 4)), Color(BONE, a))
		for end in [r.position + Vector2(3, 2), r.position + Vector2(3, 6), r.end - Vector2(3, 6), r.end - Vector2(3, 2)]:
			glow.draw_circle(end, 2.6, Color(BONE, a))
		glow.draw_line(r.position + Vector2(5, 7), r.end - Vector2(5, 1), Color(0.55, 0.5, 0.6, 0.6 * a), 1.0)
	# The wisps: pale flames with two dot eyes; brighter while they may fire.
	var awake := fire_window > 0.0
	for i in wisps.size():
		var p := wisp_pos(i) + Vector2(0, sin(_t * 5.0 + i) * 1.5)
		var born: float = wisps[i].get("born", 0.0)
		var grow := clampf((_t - born) / 0.25, 0.0, 1.0)
		var s := (1.15 if awake else 1.0) * grow
		glow.draw_circle(p + Vector2(0, -3), 10.0 * s, Color(0.75, 0.8, 1.0, 0.07 if awake else 0.045))
		glow.draw_circle(p + Vector2(0, -3), 6.5 * s, Color(0.75, 0.8, 1.0, 0.1 if awake else 0.06))
		teardrop(glow, p + Vector2(0, 3), 4.6 * s, 13.0 * s, sin(_t * 7.0 + i) * 1.5, PALE)
		teardrop(glow, p + Vector2(0, 2), 3.0 * s, 8.0 * s, sin(_t * 7.0 + i) * 1.0, CORE)
		var eye := Color("1c1830")
		var f := float(player.facing)
		glow.draw_circle(p + Vector2(-1.6 + f * 0.6, -1.0), 0.9 * s, eye)
		glow.draw_circle(p + Vector2(1.6 + f * 0.6, -1.0), 0.9 * s, eye)
	for d in _divers:
		var v: Vector2 = d["v"]
		var dirn := v.normalized() if v.length() > 1.0 else Vector2.DOWN
		glow.draw_line(d["p"], d["p"] - dirn * 16.0, Color(PALE, 0.5), 3.0)
		teardrop(glow, d["p"] + Vector2(0, 3), 4.0, 11.0, 0.0, CORE)
	for p in _pops:
		var q: float = p["t"] / 0.35
		glow.draw_arc(p["p"], 4.0 + 22.0 * q, 0, TAU, 20, Color(0.85, 0.88, 1.0, 0.8 * (1.0 - q)), 2.0)
	for r in _remnants:
		var fade := clampf(r["t"], 0.0, 1.0)
		teardrop(glow, r["p"] + Vector2(0, 6 + sin(_t * 3.0) * 2.0), 3.6, 10.0, sin(_t * 4.0), Color(PALE, 0.7 * fade))
	_draw_gulps(glow)


func _draw_gulps(glow: Node2D) -> void:
	## A gulped wisp drawn into the Stillmaw's mouth, a bright streak with a
	## soft halo (it must read inside the Stillmaw's dim on a muted phone),
	## then a pale puff where it goes in (new drawing: one TriBatch).
	if _gulps.is_empty():
		return
	var tb = TriBatch.new()
	for g in _gulps:
		var a: Vector2 = g["a"]
		var b: Vector2 = g["b"]
		if g["t"] < GULP_TIME:
			var q: float = g["t"] / GULP_TIME
			var k := q * q
			var p: Vector2 = a.lerp(b, k)
			var back: Vector2 = a.lerp(b, maxf(k - 0.35, 0.0))
			var r := 7.0 * (1.0 - 0.45 * q)
			tb.circle(p, r * 2.4, Color(0.75, 0.8, 1.0, 0.2), 14)
			tb.line(back, p, r * 1.8, Color(PALE, 0.5 * (1.0 - 0.4 * q)))
			tb.line(back.lerp(p, 0.4), p, r * 0.8, Color(CORE, 0.7))
			tb.circle(p, r, Color(PALE, 0.95), 12)
			tb.circle(p, r * 0.55, Color(CORE, 1.0), 10)
		else:
			var pq: float = clampf((g["t"] - GULP_TIME) / GULP_PUFF, 0.0, 1.0)
			tb.circle(b, 4.0 + 8.0 * (1.0 - pq), Color(PALE, 0.35 * (1.0 - pq)), 14)
			tb.ring(b, 5.0 + 18.0 * pq, 2.5, Color(0.85, 0.88, 1.0, 0.85 * (1.0 - pq)), 20)
	tb.flush(glow)
