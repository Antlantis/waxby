extends "res://scripts/elites.gd"
## Hoarowl (u, World 4 sentinel): a round clockwork owl of tarnished silver
## on a bracket, a keyhole in its chest and two lantern eyes that throw a
## cone of cold blue light (CONE_LEN px long, CONE_DEG wide, drawn at alpha
## 0.22 with bright edges and clipped by stone, plus a real light r 50). It
## sweeps from left to right over SWEEP s, pausing PAUSE s at each end, its
## head ticking on the level's tick; the sweep is phased by its x (on
## Witching every owl sweeps in step). Being dim doesn't hide Wick (it sees
## by its own light); a Smoke Veil cloud does.
##
## Spotted: his centre inside the cone with line of sight (and the owl in
## plain view) fills a meter over it in METER s (floor 0.40); leaving drains
## it over DRAIN s. Full: the alarm (a SCREECH s screech, its eyes flare):
## three icicles fall over where he is, ICICLE_GAP px apart, each with a
## SHADOW s floor shadow (24 each), and every monster within ALERT_R is
## alerted for ALERT s (x1.3 speed, awake); cooldown COOLDOWN s. Two hits
## break it. Nightfall: meter 0.50 s, sweep 2.6 s. Witching: meter 0.40 s.
## An Anointed one on Dusk from World 3 sweeps in 2.6 s (behave_diff); its
## meter is a tell and stays Dusk's.
## As a Warden (Great-Aunt Hoot, 4-S), her alarm calls two Tickwinds instead.

const MOVES := {"icicle": 24.0, "touch": 18.0}
const ARCHETYPE := "sentinel"
# The icicles' escape: out past the outer one, 55 px (his half plus the
# 40 px gap and the drop's half); "after" is the least fall before a drop
# reaches his head (the lowest space he stands in, 2 tiles: 11 px at 2000).
const TELLS := {"meter": {"sec": 0.60, "floor": 0.40}, "icicle": {"sec": 0.60, "floor": 0.40, "escape_px": 55.0, "after": 0.10}}
const FRAMES := ["owl_body", "owl_look_l", "owl_look_c", "owl_look_r", "owl_screech", "owl_hit", "owl_broken"]
const CONE_LEN := 150.0
const CONE_DEG := 40.0
const SWEEP := 3.0
const SWEEP_NF := 2.6
const PAUSE := 0.8
const ANGLE_L := 160.0             # degrees, screen space (90 = straight down)
const ANGLE_R := 20.0
const METER := 0.60
const METER_NF := 0.50
const METER_WITCHING := 0.40
const DRAIN := 0.5
const SCREECH := 0.5
const ICICLES := 3
const ICICLE_GAP := 40.0
const SHADOW := 0.6
const ICICLE_G := 2000.0
const ALERT_R := 300.0
const ALERT := 4.0
const COOLDOWN := 4.0
const VEIL_R := 32.0
const CALLS := 2                   # a Warden's alarm: Tickwinds instead of icicles
const CALLS_MAX := 4
const RAYS := 9
const SILVER := Color("a8acbc")
const SILVER_DARK := Color("6a6e80")
const IRON := Color("3e3a48")
const CONE := Color("9ad8ff")
const EYE := Color("bfeaff")

var state := "watch"               # watch, screech, cool
var timer := 0.0
var move_id := "touch"
var meter := 0.0                   # 0..1: how spotted he is
var look := 90.0                   # the cone's direction (degrees)
var look_hold := -1.0              # >= 0: the cone held at this angle (tests; a scripted stare)
var _cool := 0.0
var _tick_i := -1
var _head: Sprite2D
var _calls: Array = []


func _init() -> void:
	kind = "hoarowl"
	size = Vector2(24, 26)
	base_hp = 20.0
	base_dmg = MOVES["touch"]
	poise = 0.0
	embers = 3
	item_chance = 0.10
	relic_chance = 0.03
	echo_by_body = false


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("owl_body")
	_head = Sprite2D.new()
	_head.centered = false
	_head.offset = -anchor * 2.0
	add_child(_head)


func dmg(what := "touch") -> float:
	return float(MOVES.get(what, base_dmg)) * dmg_mult


func touch_damage() -> bool:
	return true


func meter_time() -> float:
	## The meter's fill: 0.60 / 0.50 / 0.40 s (decisions: the escape formula's
	## fix), never under its floor.
	return maxf(float(by_diff(METER, METER_NF, METER_WITCHING)), TELLS["meter"]["floor"])


func eye_world() -> Vector2:
	return position + Vector2(0, -size.y * 0.62)


func sweep_angle() -> float:
	## The cone's direction now, from the feature clock (phased by x off Witching).
	var sw := float(by_behave(SWEEP, SWEEP_NF, SWEEP_NF))
	var period := 2.0 * (sw + PAUSE)
	var off := 0.0 if difficulty() == "witching" else fmod(position.x * 0.013, period)
	var ph := fmod(clock() + off, period)
	var k := 0.0
	if ph < PAUSE:
		k = 0.0
	elif ph < PAUSE + sw:
		k = (ph - PAUSE) / sw
	elif ph < PAUSE * 2.0 + sw:
		k = 1.0
	else:
		k = 1.0 - (ph - PAUSE * 2.0 - sw) / sw
	k = k * k * (3.0 - 2.0 * k)
	return lerpf(ANGLE_L, ANGLE_R, k)


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_cool = maxf(_cool - dt, 0.0)
	velocity.x = 0.0
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
	_calls = _calls.filter(func(e): return is_instance_valid(e) and e.alive)
	match state:
		"watch", "cool":
			look = sweep_angle() if look_hold < 0.0 else look_hold
			var i := floori(clock() / tick_len())
			if i != _tick_i:
				_tick_i = i
				if player != null and player.center().distance_to(center()) < 300.0:
					sfx("owl_tick", "click", 1.2)
			if spotted(player):
				var was := meter
				meter = minf(meter + dt / meter_time(), 1.0)
				if was <= 0.0:
					tell_sfx("owl_hoot", meter_time(), "pause")   # an onset tell: plays whole
			else:
				meter = maxf(meter - dt / DRAIN, 0.0)
			if state == "cool" and _cool <= 0.0:
				state = "watch"
			if state == "watch" and meter >= 1.0:
				_alarm(player)
			_head_frame()
		"screech":
			show_frame("owl_screech")
			if timer <= 0.0:
				state = "cool"
				_cool = cd(COOLDOWN)
				meter = 0.0


func _head_frame() -> void:
	show_frame("owl_body")
	if _head:
		var n := "owl_look_c"
		if look > 115.0:
			n = "owl_look_l"
		elif look < 65.0:
			n = "owl_look_r"
		_head.texture = frames.get(n)
		_head.visible = _head.texture != null and alive and state != "screech"
		_head.scale = sprite.scale if sprite else Vector2.ONE
		_head.modulate = sprite.modulate if sprite else Color.WHITE


func spotted(player: Node2D) -> bool:
	## His centre inside the cone, in sight, not behind a Smoke Veil, with the
	## owl itself in plain view.
	if player == null or not player.alive or not in_view():
		return false
	var e := eye_world()
	var p: Vector2 = player.center()
	var d := p - e
	if d.length() > CONE_LEN:
		return false
	var dir := Vector2.from_angle(deg_to_rad(look))
	if rad_to_deg(absf(dir.angle_to(d))) > CONE_DEG * 0.5:
		return false
	if not sight(e, p):
		return false
	return not _veiled(e, p)


func _blocks(q: Vector2) -> bool:
	## Stone that stops its sight: any, but its own perch (the floor it
	## stands on, a tile either side), which it looks over.
	if not solid_at(q):
		return false
	var fy := floori((position.y + 1.0) / TILE)
	var cx := floori(position.x / TILE)
	var qc := Vector2i(floori(q.x / TILE), floori(q.y / TILE))
	return not (qc.y == fy and absi(qc.x - cx) <= 1)


func sight(a: Vector2, b: Vector2) -> bool:
	## Line of sight from its eyes (every 8 px), over its perch.
	var d := b - a
	var n := int(d.length() / 8.0) + 1
	for i in range(1, n):
		if _blocks(a + d * (float(i) / n)):
			return false
	return true


func _veiled(a: Vector2, b: Vector2) -> bool:
	## A Sootrunner's Smoke Veil between the owl and him (the kit's clouds).
	if world == null or world.get("kit") == null:
		return false
	var cl = world.kit.get("_clouds")
	if not (cl is Array):
		return false
	for c in cl:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(c["p"], a, b)
		if q.distance_to(c["p"]) <= VEIL_R:
			return true
	return false


func _alarm(player: Node2D) -> void:
	state = "screech"
	timer = SCREECH
	move_id = "icicle"
	sfx("owl_screech", "bat", 0.9)
	if world == null:
		return
	# Every monster near is alerted.
	for e in world.enemies:
		if e != self and e.alive and e != world.get("boss") and e.center().distance_to(center()) <= ALERT_R and e.has_method("alert"):
			e.alert(ALERT)
	if tier == "warden":
		_call_tickwinds(player)
		return
	var px: float = player.position.x
	for i in ICICLES:
		var x := px + (i - (ICICLES - 1) * 0.5) * ICICLE_GAP
		var top := _ceiling_above(Vector2(x, player.center().y))
		var r := Rect2(x - 5.0, top, 10.0, 18.0)
		world.add_hazard({"kind": "drip", "motion": "fall", "rect": r, "vel": Vector2.ZERO, "g": ICICLE_G, "life": 3.0,
				"delay": maxf(tell(SHADOW, TELLS["icicle"]["floor"]), TELLS["icicle"]["floor"]), "shadow": true,
				"dmg": dmg("icicle"), "owner": "enemy", "source": self, "move": "icicle", "shot": true, "icicle": true})
		strike_logged({"rect": Rect2(x - 8.0, player.position.y - 40.0, 16.0, 40.0), "life": 0.2}, dmg("icicle"))
	sfx("icicle_fall", "drip", 1.0)


func _ceiling_above(p: Vector2) -> float:
	## Where an icicle hangs: the ceiling over p, else just above the view.
	var top := -INF
	if world != null and world.has_method("view_rect"):
		top = (world.view_rect() as Rect2).position.y - 24.0
	if level == null:
		return top
	var cx := floori(p.x / TILE)
	var y := floori(p.y / TILE)
	while y >= 0:
		if LevelData.is_solid(level.tile(cx, y)):
			return maxf(float((y + 1) * TILE), top)
		y -= 1
	return top


func _call_tickwinds(player: Node2D) -> void:
	## Great-Aunt Hoot calls two Tickwinds onto his floor, one each side.
	if _calls.size() >= CALLS_MAX or not world.has_method("spawn_enemy"):
		return
	for i in CALLS:
		var side := -1.0 if i == 0 else 1.0
		var x: float = player.position.x + side * 110.0
		var cell := Vector2i(floori(x / TILE), floori((player.position.y - 1.0) / TILE))
		if level != null and (LevelData.is_solid(level.tile(cell.x, cell.y)) or not LevelData.is_floor(level.tile(cell.x, cell.y + 1))):
			continue
		var e: Node2D = world.spawn_enemy("tickwind", Vector2((cell.x + 0.5) * TILE, player.position.y),
				{"respawned": true, "facing": -int(side)})
		if e != null:
			e.active = true
			_calls.append(e)
			if world.get("glow") != null:
				world.glow.burst(e.center(), 10, Color(EYE, 0.9), 110.0, 0.4, 0.0, 2.2)


func hit(h: Dictionary) -> bool:
	var ok := super(h)
	if ok and alive:
		meter = 0.0   # knocked, it loses the thread
	return ok


func _hurt(h: Dictionary) -> void:
	flash = 1.0   # bolted to its bracket: it doesn't budge


func _dying(dt: float) -> void:
	show_frame("owl_broken")
	if _head:
		_head.visible = false
	super(dt)


func lights() -> Array:
	var out := super()
	if alive:
		var dir := Vector2.from_angle(deg_to_rad(look))
		var hot := state == "screech"
		out.append({"p": eye_world() + dir * CONE_LEN * 0.5, "r": 50.0, "s": 0.35 if not hot else 0.6,
				"tint": Color(CONE, 0.5)})
	return out


func eye_points() -> Array:
	## Its lantern eyes always show (they are its watch).
	if has_omen("hushed"):
		return []
	var e := eye_world()
	return [e + Vector2(-4, 0), e + Vector2(4, 0)]


# ---------------------------------------------------------------- the look

func cone_points() -> PackedVector2Array:
	## The cone's rim, each ray stopped at stone (what it can see).
	var e := eye_world()
	var out := PackedVector2Array()
	for i in RAYS:
		var a := deg_to_rad(look - CONE_DEG * 0.5 + CONE_DEG * i / (RAYS - 1))
		var d := Vector2.from_angle(a)
		var reach := CONE_LEN
		var s := 8.0
		while s < CONE_LEN:
			if _blocks(e + d * s):
				reach = s
				break
			s += 8.0
		out.append(e + d * reach)
	return out


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := gtb()
	var e := eye_world()
	var rim := cone_points()
	var hot := state == "screech"
	var a := 0.22 + (0.2 if hot else 0.0) + 0.15 * meter
	tb.fan(e, rim, Color(CONE, a), false)
	tb.line(e, rim[0], 1.6, Color(CONE, 0.8))
	tb.line(e, rim[rim.size() - 1], 1.6, Color(CONE, 0.8))
	tb.polyline(rim, 1.2, Color(CONE, 0.45))
	glow_eyes(tb, art_points(POINTS3, "eyes", [e + Vector2(-4, 0), e + Vector2(4, 0)]), EYE, 3.0 if not hot else 4.5)
	if meter > 0.0:
		# The meter: a ring over the owl filling as it watches him.
		var c := position + Vector2(0, -size.y - 10.0)
		tb.ring(c, 6.0, 2.2, Color(0.1, 0.1, 0.15, 0.7), 20)
		tb.ring(c, 6.0, 2.2, Color(1.0, 0.95 - 0.5 * meter, 0.6 - 0.5 * meter, 0.95), 20, -PI * 0.5, -PI * 0.5 + TAU * meter)
	if hot:
		var k := clampf(timer / SCREECH, 0.0, 1.0)
		for i in 3:
			tb.ring(e, 10.0 + (1.0 - k) * 30.0 + i * 8.0, 1.5, Color(EYE, 0.5 * k), 20)
	# The icicles it called: a bright spike over each falling drop.
	if world != null:
		for h in world.hazards:
			if h.get("icicle", false) and h.get("source") == self and float(h.get("delay", 0.0)) <= 0.0:
				var r: Rect2 = h["rect"]
				tb.convex(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.get_center().x, r.end.y + 4.0)]),
						Color(0.85, 0.95, 1.0, 0.95))
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var tb := btb()
	var sm := scale_mult
	var h := size.y
	# The bracket it's bolted to.
	tb.rect(Rect2(Vector2(-10.0, -3.0) * sm, Vector2(20.0, 3.0) * sm), pc(IRON))
	tb.rect(Rect2(Vector2(-2.0, -6.0) * sm, Vector2(4.0, 3.0) * sm), pc(IRON))
	# The round body with its keyhole, frosted feathers.
	var bc := Vector2(0, -h * 0.42)
	cel_ellipse(tb, bc, 10.0 * sm, 9.0 * sm, SILVER, 2.0)
	for i in 3:
		tb.line(bc + Vector2(-6.0 + i * 5.0, 3.0) * sm, bc + Vector2(-5.0 + i * 5.0, 7.0) * sm, 1.2, pc(Color("dcefff")))
	tb.circle(bc + Vector2(0, -1.0) * sm, 1.8 * sm, pc(IRON), 8)
	tb.rect(Rect2(bc + Vector2(-0.8, 0.0) * sm, Vector2(1.6, 3.0) * sm), pc(IRON))
	# The head, turned with the cone.
	var hc := Vector2(0, -h * 0.74)
	var tilt := (90.0 - look) / 70.0
	cel_ellipse(tb, hc, 9.0 * sm, 7.0 * sm, SILVER, 2.0)
	cel_poly(tb, PackedVector2Array([hc + Vector2(-8.0, -3.0) * sm, hc + Vector2(-4.0, -5.0) * sm, hc + Vector2(-7.0, -10.0) * sm]), SILVER_DARK, 1.2)
	cel_poly(tb, PackedVector2Array([hc + Vector2(8.0, -3.0) * sm, hc + Vector2(4.0, -5.0) * sm, hc + Vector2(7.0, -10.0) * sm]), SILVER_DARK, 1.2)
	for sx in [-1.0, 1.0]:
		var ec := hc + Vector2(sx * 3.8 + tilt * 1.5, 0.0) * sm
		cel_circle(tb, ec, 3.2 * sm, Color("2a3040"), 1.0, 12)
		tb.circle(ec + Vector2(tilt * 0.8, 0.0), 2.0 * sm, pc(EYE), 10)
	cel_poly(tb, PackedVector2Array([hc + Vector2(-1.5 + tilt, 2.0) * sm, hc + Vector2(1.5 + tilt, 2.0) * sm, hc + Vector2(tilt, 5.0) * sm]),
			Color("c8a24a"), 1.0)
	tb.flush(self)
