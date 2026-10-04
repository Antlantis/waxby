extends "res://scripts/elites.gd"
## Rootling (r, World 3 fodder): a turnip-bodied root sprite with a baby skull
## for a cap. Buried, only a dirt mound with two leaves shows; it follows Wick
## along its floor strip at FOLLOW px/s once he's within SEE_X on the same
## floor (the leaves shake and dirt flicks up: the rustle's visual twin).
## The swell (the tell, SWELL s) starts when it's within TRIGGER_X of his
## feet or after FOLLOW_MAX s of following: the mound swells, dirt specks
## spit up, a green glint (r 22), and the pop column LOCKS to his x at the
## tell's start (at most TRIGGER_X from the mound, on its strip), marked on
## the floor by a crack that closes in. Then the pop: a POP_SIZE column for
## POP s. Then it's dazed DAZED s above ground (+50%, stompable), walks at
## WALK px/s for WALK_TIME s, digs back in (DIG s) and rests COOL s.
##
## Buried, slashes and shots pass over it (hit() is false) and it can't be
## touched, but a stomp on the mound kills it (fodder); a Special (a Peal
## wave, an Anvil Drop, a Flare burst, a Rush), a shockwave or the Sexton's
## spade pops it out dazed. Nightfall (and an elite on Dusk from World 3,
## behave_diff): the mound moves at 110. Witching: a
## second pop POP2_AFTER s after the first at his new x (tell 0.45, floor 0.40).

const MOVES := {"pop": 32.0, "touch": 24.0}
const ARCHETYPE := "fodder"
# Every tell (Dusk seconds; floor on any difficulty; the escape distance of
# the zone it clears, for the escape formula: half the column plus half Wick).
const TELLS := {"swell": {"sec": 0.50, "floor": 0.40, "escape_px": 21.0},
		"swell2": {"sec": 0.45, "floor": 0.40}}   # Witching only (the formula is Dusk's)
const FRAMES := ["rootling_mound", "rootling_swell", "rootling_pop", "rootling_dazed", "rootling_walk1",
		"rootling_walk2", "rootling_hit"]
const FOLLOW := 90.0
const FOLLOW_NF := 110.0
const SEE_X := 200.0
const TRIGGER_X := 24.0
const FOLLOW_MAX := 2.5
const SWELL := 0.50
const SWELL2 := 0.45
const POP := 0.15
const POP2_AFTER := 0.6
const POP_SIZE := Vector2(22, 40)
const DAZED := 0.9
const WALK := 60.0
const WALK_TIME := 3.0
const DIG := 0.4
const COOL := 1.5
const BURIED_SIZE := Vector2(20, 10)
const UP_SIZE := Vector2(18, 20)
const GLINT := Color("9ce06a")
const SOIL := Color("6a4a2e")
const SOIL_LIT := Color("8a6238")
const BODY := Color("c89a5a")
const BODY_SHADE := Color("8a6238")
const BONE := Color("efe6d2")
const LEAF := Color("7ab860")

var state := "buried"            # buried, swell, pop, under (Witching's second), dazed, walk, dig
var timer := 0.0
var tell_len := 0.0
var move_id := "touch"
var pop_x := 0.0                 # where the column rises (locked at the tell's start)
var pops := 0                    # pops in this burst (Witching: 2)
var _follow_t := 0.0
var _cool := 0.0
var _hit_this_pop := false
var _walk := 0.0
var _rustle := 0.0
var _from_x := 0.0               # the mound's x at the tell's start (it slides to pop_x)


func _init() -> void:
	kind = "rootling"
	size = BURIED_SIZE
	base_hp = 16.0
	base_dmg = MOVES["touch"]
	poise = 0.0
	embers = 2
	item_chance = 0.08
	echo_by_body = false


func _ready() -> void:
	super()
	load_frames(FRAMES)
	_set_up(false)


func bowlable() -> bool:
	## A Stampede bowls it over only above ground (dazed, or walking): KT's ask.
	return state in ["dazed", "walk"]


func buried() -> bool:
	## Under the soil: the mound (hit only by a stomp, a Special or the spade).
	return state in ["buried", "swell", "under"]


func _set_up(up: bool) -> void:
	## Its box: the mound's, or the standing sprite's (a Twinned half keeps SHOT_LINE).
	var s := UP_SIZE if up else BURIED_SIZE
	size = Vector2(s.x * scale_mult, maxf(s.y * scale_mult, SHOT_LINE) if up else s.y * scale_mult)


func dmg(what := "touch") -> float:
	return float(MOVES.get(what, base_dmg)) * dmg_mult


func hurt_rect() -> Rect2:
	## The body shrunk 4 px a side, but never below 2 px (a Twinned half's
	## mound is only 6 px high).
	var r := rect()
	var gx := minf(4.0, maxf((r.size.x - 2.0) * 0.5, 0.0))
	var gy := minf(4.0, maxf((r.size.y - 2.0) * 0.5, 0.0))
	return r.grow_individual(-gx, -gy, -gx, -gy)


func touch_damage() -> bool:
	## Buried, walking over the mound is safe (its blow is the pop).
	return not buried() and state != "dig"


func as_copy() -> void:
	## A Twinned half lands above ground and digs in on its own.
	_set_up(true)
	state = "walk"
	timer = WALK_TIME * 0.5
	facing = 1 if velocity.x > 0.0 else -1


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_cool = maxf(_cool - dt, 0.0)
	_rustle = maxf(_rustle - dt, 0.0)
	match state:
		"buried":
			_buried(dt, player)
		"swell":
			velocity.x = 0.0
			var k := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
			position.x = lerpf(_from_x, pop_x, minf(k * 1.6, 1.0))
			_fall(dt)
			show_frame("rootling_swell")
			if timer <= 0.0:
				_pop()
		"pop":
			_fall(dt)
			show_frame("rootling_pop")
			_pop_hits(player)
			if timer <= 0.0:
				if pops < 2 and difficulty() == "witching":
					# Witching: back under, and up again at his new x.
					state = "under"
					timer = POP2_AFTER - tell(SWELL2, TELLS["swell2"]["floor"])
					_set_up(false)
				else:
					_daze()
		"under":
			_fall(dt)
			show_frame("rootling_mound")
			if timer <= 0.0:
				_start_swell(player, tell(SWELL2, TELLS["swell2"]["floor"]))
		"walk":
			walk(dt, spd(WALK))
			_walk += dt
			show_frame("rootling_walk1" if fmod(_walk, 0.4) < 0.2 else "rootling_walk2")
			if timer <= 0.0 and on_floor:
				state = "dig"
				timer = DIG
				sfx("dig_rustle", "grave_step", 1.0, 0.3)   # (quiet: the loud rustle is the swell's tell)
		"dig":
			velocity.x = 0.0
			_fall(dt)
			show_frame("rootling_mound")
			if timer <= 0.0:
				state = "buried"
				_cool = COOL
				_follow_t = 0.0
				_set_up(false)


func _fall(dt: float) -> void:
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)


func _buried(dt: float, player: Node2D) -> void:
	show_frame("rootling_mound")
	var dx: float = player.position.x - position.x
	var following: bool = player.alive and absf(dx) < SEE_X and near_floor(player) and player.on_floor
	if not following:
		_follow_t = 0.0
		velocity.x = 0.0
		_fall(dt)
		return
	_follow_t += dt
	var dir := 1 if dx > 0.0 else -1
	var v := spd(by_behave(FOLLOW, FOLLOW_NF, FOLLOW_NF))
	# It stops at edges and walls (and right under his feet).
	if absf(dx) > 3.0 and ground_ahead(dir) and not wall_ahead(dir):
		facing = dir
		velocity.x = dir * minf(v, absf(dx) / maxf(dt, 0.001))
		if _rustle <= 0.0:
			_rustle = 1.0
			sfx("dig_rustle", "grave_step", 1.0, 0.3)   # following: quiet and sparse (A7)
	else:
		velocity.x = 0.0
	_fall(dt)
	if _cool <= 0.0 and (absf(dx) <= TRIGGER_X or _follow_t >= FOLLOW_MAX):
		_start_swell(player, tell(SWELL, TELLS["swell"]["floor"]))


func _start_swell(player: Node2D, sec: float) -> void:
	## The tell: the column locks to his x now (within TRIGGER_X of the
	## mound and on its floor strip).
	state = "swell"
	timer = sec
	tell_len = sec
	_from_x = position.x
	var strip := floor_strip(position)
	var want: float = player.position.x if player != null else position.x
	pop_x = clampf(want, position.x - TRIGGER_X, position.x + TRIGGER_X)
	pop_x = clampf(pop_x, strip.x + size.x * 0.5, strip.y - size.x * 0.5)
	move_id = "pop"
	velocity.x = 0.0
	tell_sfx("dig_rustle", sec, "grave_step")   # the swell: fitted, loud, building to the pop
	if world != null and world.get("glow") != null:
		world.glow.burst(Vector2(position.x, position.y - 3.0), 6, Color(SOIL_LIT, 0.9), 70.0, 0.4, 500.0, 2.0, 120.0)


func _pop() -> void:
	state = "pop"
	timer = POP
	pops += 1
	_hit_this_pop = false
	position.x = pop_x
	_set_up(true)
	velocity = Vector2(0.0, -260.0)
	sfx("root_pop", "wing_pop")
	strike_logged({"rect": pop_rect(), "life": POP}, dmg("pop"))
	if world != null:
		if world.has_method("dust_at"):
			world.dust_at(Vector2(pop_x, position.y))
		if world.get("glow") != null:
			world.glow.burst(Vector2(pop_x, position.y - 4.0), 12, Color(SOIL_LIT, 0.95), 160.0, 0.45, 700.0, 2.4, 200.0)


func pop_rect() -> Rect2:
	## The column that rises (world space), from the floor at pop_x.
	var s := POP_SIZE * scale_mult
	return Rect2(pop_x - s.x * 0.5, position.y - s.y, s.x, s.y)


func _pop_hits(player: Node2D) -> void:
	if _hit_this_pop or player == null or not player.alive or world == null:
		return
	if pop_rect().intersects(player.rect()):
		_hit_this_pop = true
		world.hurt_player(dmg("pop"), pop_x, "hit", self, {"move": "pop"})


func _daze() -> void:
	state = "walk"
	timer = WALK_TIME
	pops = 0
	move_id = "touch"
	_set_up(true)
	apply_status("dazed", DAZED)
	sfx("dizzy", "chain_step")


func _unearth() -> void:
	## Dug out (a Special, a shockwave, the spade): up and dazed.
	if not buried():
		return
	pops = 0
	_set_up(true)
	velocity = Vector2(0.0, -220.0)
	_daze()


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	if buried():
		var how: String = str(h.get("how", "slash"))
		var kit = world.get("kit") if world != null else null
		var spade: bool = how == "slash" and kit != null and str(kit.get("cls")) == "sexton"
		var dig_out: bool = spade or how in ["wave", "skill", "shock"]
		if how == "stomp":
			var ok := super(h)
			if ok and alive:
				_unearth()   # an elite survives a stomp: up it comes
			return ok
		if not dig_out:
			return false   # it's under the soil: the blow passes over it
		_unearth()
	return super(h)


func _kill(h: Dictionary) -> void:
	if buried():
		_set_up(true)
	super(h)
	if str(h.get("how", "")) == "stomp":
		velocity = Vector2.ZERO   # squashed flat into its mound


func _dying(dt: float) -> void:
	show_frame("rootling_hit")
	if velocity == Vector2.ZERO:
		fade = clampf(1.6 - death_time * 1.6, 0.0, 1.0)
		squash = clampf(1.0 - death_time * 0.8, 0.25, 1.0)
		if death_time > 1.0:
			gone = true
	else:
		super(dt)


func lights() -> Array:
	var out := super()
	if alive and state == "swell":
		out.append({"p": Vector2(position.x, position.y - 6.0), "r": 22.0, "s": 0.6})
	return out


func eye_points() -> Array:
	## Only an elite's eyes glint, and only above ground.
	if tier == "" or buried() or has_omen("hushed"):
		return []
	return [position + Vector2(facing * 3.0 - 3.0, -size.y * 0.55), position + Vector2(facing * 3.0 + 3.0, -size.y * 0.55)]


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := gtb()
	var feet := position
	if buried():
		# The leaves poke out of the mound, faintly lit, and shake when it moves.
		var shake := sin(t * 40.0) * 1.5 if absf(velocity.x) > 1.0 or state == "swell" else 0.0
		for sx in [-1.0, 1.0]:
			var base := feet + Vector2(sx * 3.0 + shake, -BURIED_SIZE.y * scale_mult * 0.6)
			tb.line(base, base + Vector2(sx * 4.0, -6.0), 2.0, Color(LEAF, 0.45))
	if state == "swell" or state == "under":
		# The tell: the mound swells and spits dirt, a green glint grows, and
		# the floor cracks where the column will rise (locked at pop_x).
		var k := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0) if state == "swell" else 0.0
		var pr := pop_rect()
		var cy := feet.y - 1.0
		var hw := pr.size.x * 0.5 + 10.0 * (1.0 - k)
		tb.ellipse(Vector2(pop_x, cy), hw, 3.0 + 2.0 * k, Color(GLINT, 0.25 + 0.35 * k), 16)
		for i in 5:
			var fx := pop_x + (i - 2) * pr.size.x * 0.22
			var jag := 2.0 + 3.0 * k
			tb.line(Vector2(fx, cy), Vector2(fx + (1.5 if i % 2 == 0 else -1.5), cy - jag), 1.4, Color(GLINT, 0.6 + 0.4 * k))
		if state == "swell":
			tb.circle(Vector2(position.x, feet.y - 6.0), 3.0 + 3.0 * k, Color(GLINT, 0.7 + 0.25 * k), 12)
			# The column's edges, faint, so the lock reads.
			tb.line(Vector2(pr.position.x, cy), Vector2(pr.position.x, cy - pr.size.y * k), 1.2, Color(GLINT, 0.35 * k))
			tb.line(Vector2(pr.end.x, cy), Vector2(pr.end.x, cy - pr.size.y * k), 1.2, Color(GLINT, 0.35 * k))
	elif state == "pop":
		var pr2 := pop_rect()
		var kk := clampf(timer / POP, 0.0, 1.0)
		glow.draw_rect(pr2, Color(0.75, 0.9, 0.55, 0.22 * kk))
	if status.has("dazed"):
		# Dizzy: little leaves wheeling over its head.
		var c := Vector2(position.x, rect().position.y - 5.0)
		for i in 3:
			var a := t * 5.0 + TAU * i / 3.0
			var p := c + Vector2(cos(a) * 9.0, sin(a) * 3.0)
			tb.circle(p, 2.2, Color(1.0, 0.95, 0.6, 0.9), 8)
	elif not buried():
		glow_eyes(tb, art_points(POINTS3, "eyes", _eyes_local().map(func(p): return position + p)), Color(0.95, 0.85, 0.55), 1.6)
	tb.flush(glow)


func _eyes_local() -> Array:
	var h := size.y
	return [Vector2(facing * 2.0 - 4.0, -h * 0.5), Vector2(facing * 2.0 + 4.0, -h * 0.5)]


func _draw() -> void:
	if not frames.is_empty():
		return
	var tb := btb()
	var f := float(facing)
	var sm := scale_mult
	if buried():
		var swell := 1.0
		if state == "swell":
			swell = 1.0 + 0.35 * (1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0))
		var w := 11.0 * sm * swell
		var h := 5.0 * sm * swell
		cel_ellipse(tb, Vector2(0, -h * 0.6), w, h, SOIL, 1.5)
		cel_ellipse(tb, Vector2(-w * 0.25, -h * 0.9), w * 0.45, h * 0.35, SOIL_LIT, 0.0)
		for sx in [-1.0, 1.0]:
			var base := Vector2(sx * 3.0 * sm, -h * 1.2)
			cel_line(tb, base, base + Vector2(sx * 4.0, -6.0) * sm, 2.4 * sm, LEAF, 1.0)
		tb.flush(self)
		return
	if state == "dig":
		var k := clampf(timer / DIG, 0.0, 1.0)
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, k * 0.8 + 0.2))
	var hh := UP_SIZE.y * sm
	var bob := sin(_walk * TAU / 0.4) * 1.0 if state == "walk" else 0.0
	# Stubby root feet.
	cel_line(tb, Vector2(-4.0 * sm, -3.0 * sm), Vector2(-6.0 * sm, 0.0), 2.6 * sm, BODY_SHADE, 1.2)
	cel_line(tb, Vector2(4.0 * sm, -3.0 * sm), Vector2(6.0 * sm, 0.0), 2.6 * sm, BODY_SHADE, 1.2)
	# The turnip body.
	var bc := Vector2(0, -hh * 0.42 + bob)
	cel_ellipse(tb, bc, 8.5 * sm, 7.5 * sm, BODY, 2.0)
	cel_ellipse(tb, bc + Vector2(f * 3.0 * sm, 2.5 * sm), 4.5 * sm, 3.5 * sm, BODY_SHADE, 0.0)
	# The baby-skull cap.
	var cap := Vector2(0, -hh * 0.78 + bob)
	cel_ellipse(tb, cap, 7.5 * sm, 5.0 * sm, BONE, 1.8)
	tb.circle(cap + Vector2(f * 2.0 - 2.5, 1.0) * sm, 1.3 * sm, pc(Color("2a2030")), 8)
	tb.circle(cap + Vector2(f * 2.0 + 2.5, 1.0) * sm, 1.3 * sm, pc(Color("2a2030")), 8)
	# Two leaf sprouts on top.
	var spin := t * 12.0 if status.has("dazed") else 0.0
	for sx in [-1.0, 1.0]:
		var base := cap + Vector2(sx * 1.5, -4.0) * sm
		var d := Vector2(sx * 4.0, -6.0).rotated(spin * sx) * sm
		cel_line(tb, base, base + d, 2.4 * sm, LEAF, 1.0)
	# Its little face on the body.
	cel_eyes(tb, _eyes_local().map(func(p): return p + Vector2(0, bob)), 1.4 * sm)
	tb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
