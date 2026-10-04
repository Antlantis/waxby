extends "res://scripts/elites.gd"
## Weepcap (p, World 3): a tall mourning mushroom, its drooping grey-violet
## cap hung like a widow's veil over a pale stalk with a sleepy, sad face.
## Stationary; about 4 hits (a bar). When Wick is within SEE px and it's in
## plain view it inhales (the tell, INHALE s: the cap swells x1.2, the gills
## glow violet, r 26), then puffs: a spore cloud through features.add_spores
## (r 60, 5 s; the one cloud rule) centred OFFSET px toward him (on itself
## when he's within CLOSE px). The puff's first BURST s is a burst of BURST_R
## around the cap (it punishes hugging). Cooldown COOLDOWN s; at most 2 of
## its clouds at once (it waits).
##
## Fire clears its clouds (a spark, a Flare, a fire patch, a Burning Omen's
## fire, a lit brazier within 8 px): the whoomph deals 0.6x basic to every
## monster inside, never to Wick. A burning Weepcap takes +50% fire damage;
## a stomp deals 1.5x and cancels the inhale. Nightfall (and an elite on
## Dusk from World 3, behave_diff): clouds r 72 for 6 s.
## Witching: two puffs, forward and back.

const MOVES := {"burst": 18.0, "touch": 20.0}
const ARCHETYPE := "heavy"
const TELLS := {"inhale": {"sec": 0.70, "floor": 0.40, "escape_px": 46.0}}
const FRAMES := ["weepcap_idle", "weepcap_inhale", "weepcap_puff", "weepcap_hit", "weepcap_die"]
const SEE := 150.0
const INHALE := 0.70
const OFFSET := 48.0
const CLOSE := 40.0
const CLOUD_R := 60.0
const CLOUD_R_NF := 72.0
const CLOUD_LIFE := 5.0
const CLOUD_LIFE_NF := 6.0
const BURST := 0.2
const BURST_R := 36.0
const COOLDOWN := 3.0
const MAX_CLOUDS := 2
const FIRE_REACH := 8.0
const WHOOMPH := 0.6
const STOMP_MULT := 1.5
const BURNING_FIRE := 1.5
const STALK := Color("e8e0d8")
const STALK_SHADE := Color("b8aca4")
const CAP := Color("8a7aa0")
const CAP_DARK := Color("5e4f78")
const GILL := Color("b49cff")

var state := "idle"              # idle, inhale, puff
var timer := 0.0
var tell_len := 0.0
var move_id := "touch"
var clouds: Array = []           # its own: [{p, r, born, life, burnt}]
var _cool := 0.0
var _burst_hit := false
var _sway := 0.0


func _init() -> void:
	kind = "weepcap"
	size = Vector2(28, 34)
	base_hp = 44.0
	base_dmg = MOVES["touch"]
	poise = 0.35
	embers = 4
	item_chance = 0.12
	relic_chance = 0.03
	echo_by_body = false


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("weepcap_idle")


func dmg(what := "touch") -> float:
	return float(MOVES.get(what, base_dmg)) * dmg_mult


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_cool = maxf(_cool - dt, 0.0)
	_sway += dt
	velocity.x = 0.0
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
	_step_clouds()
	match state:
		"idle":
			move_id = "touch"
			show_frame("weepcap_idle")
			var d: float = player.center().distance_to(center())
			if _cool <= 0.0 and player.alive and d < SEE and in_view() and live_clouds() < MAX_CLOUDS:
				state = "inhale"
				timer = tell(INHALE, TELLS["inhale"]["floor"])
				tell_len = timer
				facing = 1 if player.position.x > position.x else -1
				tell_sfx("weepcap_inhale", timer, "mimic_snore")
		"inhale":
			show_frame("weepcap_inhale")
			if timer <= 0.0:
				_puff(player)
		"puff":
			show_frame("weepcap_puff")
			if not _burst_hit and timer > 0.0 and player.alive and world != null:
				if _circle_hits(cap_center(), BURST_R * scale_mult, player.rect()):
					_burst_hit = true
					world.hurt_player(dmg("burst"), position.x, "hit", self, {"move": "burst"})
			if timer <= 0.0:
				state = "idle"
				move_id = "touch"
				_cool = cd(COOLDOWN)


func cap_center() -> Vector2:
	return position + Vector2(0, -size.y * 0.72)


static func _circle_hits(c: Vector2, r: float, box: Rect2) -> bool:
	var q := Vector2(clampf(c.x, box.position.x, box.end.x), clampf(c.y, box.position.y, box.end.y))
	return q.distance_squared_to(c) <= r * r


func _puff(player: Node2D) -> void:
	state = "puff"
	timer = BURST
	move_id = "burst"
	_burst_hit = false
	sfx("spore_puff", "whoosh", 1.0)
	strike_logged({"rect": Rect2(cap_center() - Vector2(BURST_R, BURST_R), Vector2(BURST_R, BURST_R) * 2.0), "life": BURST}, dmg("burst"))
	var dx: float = player.position.x - position.x
	var dir := 1.0 if dx > 0.0 else -1.0
	var at := cap_center()
	if absf(dx) > CLOSE:
		at += Vector2(dir * OFFSET, 0.0)
	_cloud(at)
	if difficulty() == "witching":
		_cloud(cap_center() + Vector2(-dir * OFFSET, 0.0))
	if world != null and world.get("glow") != null:
		world.glow.burst(cap_center(), 14, Color(0.78, 0.84, 0.4, 0.9), 120.0, 0.5, -30.0, 3.0)


func _cloud(p: Vector2) -> void:
	var r := CLOUD_R_NF if behave_diff() != "dusk" else CLOUD_R
	var life := CLOUD_LIFE_NF if behave_diff() != "dusk" else CLOUD_LIFE
	clouds.append({"p": p, "r": r, "born": clock(), "life": life, "burnt": false})
	if world != null and world.get("features") != null:
		world.features.add_spores(p, r, life, self)


func live_clouds() -> int:
	var n := 0
	for c in clouds:
		if not c["burnt"] and clock() - float(c["born"]) < float(c["life"]):
			n += 1
	return n


func _step_clouds() -> void:
	## Fire near one of its clouds burns it (and the whoomph); a cloud the
	## orchard burnt on its own gets its whoomph too.
	var mine = _orchard_clouds()
	for c in clouds:
		if c["burnt"] or clock() - float(c["born"]) >= float(c["life"]):
			continue
		if mine != null:
			# Follow the orchard's cloud as it drifts.
			var best = null
			var bd := float(c["r"]) + 40.0
			for oc in mine:
				var d := (oc["p"] as Vector2).distance_to(c["p"])
				if d < bd and float(oc.get("burn", -1.0)) < 0.0:
					bd = d
					best = oc
			if best != null:
				c["p"] = best["p"]
		var fire := _fire_near(c["p"], float(c["r"]) + FIRE_REACH)
		var gone := false
		if mine != null:
			gone = true
			for oc in mine:
				if (oc["p"] as Vector2).distance_to(c["p"]) < float(c["r"]) + 40.0 and float(oc.get("burn", -1.0)) < 0.0:
					gone = false
			var burning := false
			for oc in mine:
				if float(oc.get("burn", -1.0)) >= 0.0 and (oc["p"] as Vector2).distance_to(c["p"]) < float(c["r"]) + 40.0:
					burning = true
			gone = gone and burning
		if fire:
			if world != null and world.get("features") != null:
				world.features.burn_spores(c["p"], FIRE_REACH)
			_whoomph(c)
		elif gone:
			_whoomph(c)
	clouds = clouds.filter(func(c): return not c["burnt"] and clock() - float(c["born"]) < float(c["life"]))


func _orchard_clouds():
	## The orchard's clouds that are this Weepcap's (read only), or null.
	if world == null or world.get("features") == null or not world.features.has_method("module"):
		return null
	var m = world.features.module("orchard")
	if m == null or m.get("clouds") == null:
		return null
	return (m.clouds as Array).filter(func(c): return c.get("source") == self)


func _fire_near(p: Vector2, r: float) -> bool:
	if world == null:
		return false
	for s in world.shots:
		if s["owner"] == "player" and str(s["kind"]) in ["spark", "flare"] and (s["pos"] as Vector2).distance_to(p) <= r:
			return true
	for h in world.hazards:
		if h.get("kind", "") == "fire" and float(h.get("delay", 0.0)) <= 0.0:
			var hr: Rect2 = h["rect"]
			if _circle_hits(p, r, hr):
				return true
	if world.get("features") != null and world.features.has_method("lit_braziers"):
		for l in world.features.lit_braziers():
			if (l["flame"] as Vector2).distance_to(p) <= r:
				return true
	return false


func _whoomph(c: Dictionary) -> void:
	## Fire took the cloud: an orange whoomph that burns the monsters in it
	## (0.6x basic, the hero's fire), never Wick.
	c["burnt"] = true
	sfx("spore_burn", "whoosh", 0.8)
	if world == null:
		return
	if world.get("glow") != null:
		world.glow.burst(c["p"], 22, Color(1.0, 0.6, 0.25, 0.95), 180.0, 0.4, -60.0, 3.0)
	for e in world.enemies:
		if e.alive and e != world.get("boss") and _circle_hits(c["p"], float(c["r"]), e.rect()):
			world.deal(e, WHOOMPH, {"how": "burn", "no_hitstop": true, "from_x": (c["p"] as Vector2).x})


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	var how := str(h.get("how", "slash"))
	if h.has("amount"):
		if how == "stomp":
			h["amount"] = float(h["amount"]) * STOMP_MULT
		elif status.has("burn") and fire_hit(h):
			h["amount"] = float(h["amount"]) * BURNING_FIRE   # a dry cap burns
	var ok := super(h)
	if ok and alive and how == "stomp" and state == "inhale":
		# Squashed: the breath goes out of it.
		state = "idle"
		_cool = cd(COOLDOWN) * 0.5
		move_id = "touch"
	return ok


func _dying(dt: float) -> void:
	# It wilts where it stands.
	show_frame("weepcap_die")
	velocity.x = 0.0
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
	fade = clampf(1.4 - death_time * 1.2, 0.0, 1.0)
	squash = clampf(1.0 - death_time * 0.7, 0.3, 1.0)
	if death_time > 1.2:
		gone = true


func lights() -> Array:
	var out := super()
	if alive and state == "inhale":
		out.append({"p": cap_center(), "r": 26.0, "s": 0.5, "tint": Color(GILL, 0.5)})
	return out


func eye_points() -> Array:
	if tier == "" or has_omen("hushed"):
		return []
	return _eyes_world()


func _eyes_world() -> Array:
	var c := position + Vector2(0, -size.y * 0.38)
	return [c + Vector2(-4.0, 0), c + Vector2(4.0, 0)]


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := gtb()
	var cc := cap_center()
	var k := 0.0
	if state == "inhale":
		k = 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
	# The gills glow faintly always (it's seen in the dark), bright in the tell.
	var gw := 12.0 * scale_mult * (1.0 + 0.2 * k)
	for i in 5:
		var gx := cc.x + (i - 2) * gw * 0.4
		tb.line(Vector2(gx, cc.y + 2.0), Vector2(gx + (i - 2) * 1.2, cc.y + 7.0 + 2.0 * k), 1.6,
				Color(GILL, 0.3 + 0.65 * k))
	if state == "inhale":
		# Air rushes in: rings close on the cap, and the burst's reach shows.
		for i in 3:
			var rr := BURST_R * (1.0 - fmod(k * 2.0 + i / 3.0, 1.0)) + 6.0
			tb.ring(cc, rr, 1.4, Color(0.85, 0.8, 1.0, 0.25 + 0.25 * k), 20)
		tb.ring(cc, BURST_R * scale_mult, 1.0, Color(GILL, 0.2 + 0.3 * k), 24)
	elif state == "puff":
		var kk := clampf(timer / BURST, 0.0, 1.0)
		tb.circle(cc, BURST_R * scale_mult, Color(0.8, 0.88, 0.45, 0.25 * kk), 20)
	glow_eyes(tb, art_points(POINTS3, "eyes", _eyes_world()), Color(0.85, 0.8, 1.0), 1.4)
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var tb := btb()
	var sm := scale_mult
	var h := size.y
	var k := 0.0
	if state == "inhale":
		k = 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
	var sway := sin(_sway * 1.6) * 1.5
	# The pale stalk, with its sleepy, sad face.
	cel_poly(tb, PackedVector2Array([Vector2(-6.0, 0.0) * sm, Vector2(6.0, 0.0) * sm, Vector2(4.5 + sway * 0.3, -h * 0.66),
			Vector2(-4.5 + sway * 0.3, -h * 0.66)]), STALK, 2.0)
	tb.rect(Rect2(Vector2(2.0, -h * 0.62), Vector2(2.5, h * 0.6)), pc(STALK_SHADE))
	var fc := Vector2(sway * 0.2, -h * 0.38)
	for sx in [-1.0, 1.0]:
		# Sleepy eyes: little downturned lids.
		var e: Vector2 = fc + Vector2(sx * 3.5, 0.0) * sm
		tb.line(e + Vector2(-1.8, -0.6), e + Vector2(1.8, 0.6 * sx), 1.3, pc(Color("2a2030")))
	tb.line(fc + Vector2(-2.0, 4.0) * sm, fc + Vector2(0.0, 3.2) * sm, 1.1, pc(Color("2a2030")))
	tb.line(fc + Vector2(0.0, 3.2) * sm, fc + Vector2(2.0, 4.0) * sm, 1.1, pc(Color("2a2030")))
	# The drooping cap, like a veil (it swells in the tell).
	var cc := Vector2(sway, -h * 0.72)
	var sw := 1.0 + 0.2 * k
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		cap.append(cc + Vector2(cos(a) * 14.0 * sw, sin(a) * 9.0 * sw) * sm)
	cap.append(cc + Vector2(15.0 * sw, 7.0) * sm)
	cap.append(cc + Vector2(11.0 * sw, 10.0) * sm)
	cap.append(cc + Vector2(-11.0 * sw, 10.0) * sm)
	cap.append(cc + Vector2(-15.0 * sw, 7.0) * sm)
	cel_poly(tb, cap, CAP, 2.0)
	# The veil's folds.
	for i in 4:
		var fx := cc.x + (-9.0 + i * 6.0) * sw * sm
		tb.line(Vector2(fx, cc.y - 4.0 * sm), Vector2(fx + 0.5, cc.y + 9.0 * sm), 1.4, pc(CAP_DARK))
	tb.flush(self)
