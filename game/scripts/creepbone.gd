extends "res://scripts/elites.gd"
## Creepbone (i, World 3 fodder): a centipede of knuckle-bones and vertebrae
## with a small grinning skull, drawn upright: it lives on a lane, the vine
## run it was placed on (features.vine_lane) or the face of the wall it
## clings to (placement vine_or_wall). It crawls its lane at CRAWL px/s,
## turning at the ends. When Wick is on its lane within LANE_SEE px, or
## passes within PASS_X of it, it coils (the tell, COIL s: it curls into an
## S, the bones rattle, its eyes glint r 18), then lunges LUNGE px along the
## lane toward him at LUNGE_SPEED px/s, and lies stretched STRETCHED s
## (+25% damage).
##
## Any hit while it's on its lane knocks it off: it falls, lies on its back
## dazed DAZED s (+50%), then crawls back to its lane at RETURN px/s and
## climbs on again. A stomp kills it (fodder). Nightfall: lunge 128 px.
## Witching (and a level's packs twist): two share a lane, out of step.

const Twists := preload("res://scripts/twists.gd")
const MOVES := {"lunge": 32.0, "touch": 28.0}
const ARCHETYPE := "fodder"
const TELLS := {"coil": {"sec": 0.50, "floor": 0.40, "escape_px": 18.0}}
const FRAMES := ["creep_crawl1", "creep_crawl2", "creep_coil", "creep_lunge", "creep_fall", "creep_hit"]
const CRAWL := 40.0
const LANE_SEE := 128.0
const PASS_X := 48.0
const COIL := 0.50
const LUNGE := 96.0
const LUNGE_NF := 128.0
const LUNGE_SPEED := 360.0
const STRETCHED := 0.8
const STRETCH_BONUS := 1.25
const DAZED := 1.2
const RETURN := 60.0
const AGAIN := 1.0
const UP_SIZE := Vector2(16, 40)
const DOWN_SIZE := Vector2(40, 16)
const BONE := Color("efe6d2")
const BONE_SHADE := Color("b8ab92")
const HAIR := Color("8a6a48")
const GLINT := Color("d8ff9a")

var state := "crawl"             # crawl, coil, lunge, stretched, fallen (knocked off), return
var timer := 0.0
var tell_len := 0.0
var move_id := "touch"
var lane := {}                   # {x, top, bottom, vine: bool, side} in px; {} = no lane (it paces the floor)
var dir := -1                    # along the lane: -1 up, 1 down
var partner := false             # Witching's second on the lane
var _lunge_left := 0.0
var _lunge_dir := -1
var _tail := 0.0                 # the stretched tail's length (px), for the look
var _crawl := 0.0
var _again := 0.0
var _started := false


func _init() -> void:
	kind = "creepbone"
	size = UP_SIZE
	base_hp = 22.0
	base_dmg = MOVES["touch"]
	poise = 0.0
	embers = 3
	item_chance = 0.08
	flier = true                 # on its lane it hangs where it is (no tile physics)
	echo_by_body = false


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("creep_crawl1")
	_find_lane()


func on_lane() -> bool:
	return not lane.is_empty() and state in ["crawl", "coil", "lunge", "stretched"]


func _find_lane() -> void:
	## Its lane: the vine through its cell, or the wall face beside it.
	lane = {}
	if level == null:
		return
	var cell := Vector2i(floori(position.x / TILE), floori((position.y - 1.0) / TILE))
	var vl := _vine_lane(cell)
	if vl.is_empty() and not LevelData.is_climb(level.tile(cell.x, cell.y)):
		# Placed in a vine column by a glyph that isn't a vine carrier (a 'D'
		# Warden): the vine above and below it, bridged over its cell.
		var up := _vine_lane(cell + Vector2i(0, -1))
		var down := _vine_lane(cell + Vector2i(0, 1))
		if not up.is_empty() or not down.is_empty():
			vl = {"x": cell.x, "y0": int(up["y0"]) if not up.is_empty() else cell.y,
					"y1": int(down["y1"]) if not down.is_empty() else cell.y}
	if not vl.is_empty():
		lane = {"x": (int(vl["x"]) + 0.5) * TILE, "top": float(int(vl["y0"]) * TILE), "bottom": float((int(vl["y1"]) + 1) * TILE),
				"vine": true, "side": 0}
	else:
		var side := 0
		if LevelData.is_solid(level.tile(cell.x - 1, cell.y)):
			side = -1
		elif LevelData.is_solid(level.tile(cell.x + 1, cell.y)):
			side = 1
		if side == 0:
			return
		var y0 := cell.y
		var y1 := cell.y
		while y0 > 0 and not LevelData.is_solid(level.tile(cell.x, y0 - 1)) and LevelData.is_solid(level.tile(cell.x + side, y0 - 1)):
			y0 -= 1
		while y1 < level.height - 1 and not LevelData.is_solid(level.tile(cell.x, y1 + 1)) and LevelData.is_solid(level.tile(cell.x + side, y1 + 1)):
			y1 += 1
		var fx := (cell.x + (0 if side < 0 else 1)) * TILE
		lane = {"x": fx - side * UP_SIZE.x * 0.5 * scale_mult, "top": float(y0 * TILE), "bottom": float((y1 + 1) * TILE),
				"vine": false, "side": side}
	position.x = float(lane["x"])
	position.y = clampf(position.y, lane_min(), float(lane["bottom"]))


func _vine_lane(cell: Vector2i) -> Dictionary:
	## features.vine_lane (the orchard's snap state), else the tiles.
	if world != null and world.get("features") != null and world.features.has_method("vine_lane"):
		return world.features.vine_lane(cell)
	if not LevelData.is_climb(level.tile(cell.x, cell.y)):
		return {}
	var y0 := cell.y
	var y1 := cell.y
	while LevelData.is_climb(level.tile(cell.x, y0 - 1)):
		y0 -= 1
	while LevelData.is_climb(level.tile(cell.x, y1 + 1)):
		y1 += 1
	return {"x": cell.x, "y0": y0, "y1": y1}


func lane_min() -> float:
	## Its feet's highest place on the lane (its body fits under the top).
	return minf(float(lane["top"]) + size.y, float(lane["bottom"]))


func lane_len() -> float:
	return float(lane["bottom"]) - float(lane["top"])


func dmg(what := "touch") -> float:
	if what == "touch" and state == "lunge":
		what = "lunge"
	return float(MOVES.get(what, base_dmg)) * dmg_mult


func _stunned(dt: float) -> void:
	## Rooted on its lane it stays put; off it, it falls as ever.
	if on_lane():
		velocity = Vector2.ZERO
		return
	flier = false
	super(dt)


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_again = maxf(_again - dt, 0.0)
	_tail = maxf(_tail - dt * 120.0, 0.0) if state != "stretched" else _tail
	if not _started:
		_started = true
		_maybe_partner()
	if lane.is_empty() and state in ["crawl", "coil", "lunge", "stretched"]:
		state = "return"
	match state:
		"crawl":
			move_id = "touch"
			flier = true
			velocity = Vector2.ZERO
			position.y += dir * spd(CRAWL) * dt
			if position.y <= lane_min():
				position.y = lane_min()
				dir = 1
			elif position.y >= float(lane["bottom"]):
				position.y = float(lane["bottom"])
				dir = -1
			_crawl += dt
			show_frame("creep_crawl1" if fmod(_crawl, 0.4) < 0.2 else "creep_crawl2")
			if _again <= 0.0 and _sees(player):
				state = "coil"
				timer = tell(COIL, TELLS["coil"]["floor"])
				tell_len = timer
				_lunge_dir = 1 if player.center().y > center().y else -1
				tell_sfx("creep_rattle", timer, "bones")
		"coil":
			show_frame("creep_coil")
			if timer <= 0.0:
				state = "lunge"
				move_id = "lunge"
				_lunge_left = LUNGE if difficulty() == "dusk" else LUNGE_NF
				sfx("creep_snap", "bones", 1.0)
				var span := _lunge_left
				var y0 := position.y if _lunge_dir > 0 else position.y - span - size.y
				strike_logged({"rect": Rect2(position.x - size.x * 0.5, y0, size.x, span + size.y), "life": span / LUNGE_SPEED}, dmg("lunge"))
		"lunge":
			show_frame("creep_lunge")
			var step := minf(LUNGE_SPEED * dt, _lunge_left)
			var before := position.y
			position.y = clampf(position.y + _lunge_dir * step, lane_min(), float(lane["bottom"]))
			var moved := absf(position.y - before)
			_tail += moved
			_lunge_left -= step
			if _lunge_left <= 0.0 or moved < step * 0.5:
				state = "stretched"
				timer = STRETCHED
				move_id = "touch"
		"stretched":
			show_frame("creep_lunge")
			_tail = maxf(_tail - dt * 90.0, 0.0)
			if timer <= 0.0:
				state = "crawl"
				dir = -_lunge_dir
				_again = AGAIN
		"fallen":
			# On its back on the floor (the daze wears off in enemy.gd's step).
			show_frame("creep_fall")
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * dt)
			velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
			move(dt)
			if lost_in_pit():
				_kill({"how": "pit", "from_x": position.x})
				return
			if on_floor:
				state = "return"
		"return":
			_return(dt)


func _sees(player: Node2D) -> bool:
	if not player.alive:
		return false
	var pc2: Vector2 = player.center()
	var c := center()
	var on_it: bool = absf(player.position.x - position.x) < 14.0
	if player.get("climbing") and lane.get("vine", false):
		on_it = on_it or int(player.get("climb_col")) == floori(float(lane["x"]) / TILE)
	if on_it and absf(pc2.y - c.y) <= LANE_SEE:
		return true
	return absf(pc2.x - c.x) <= PASS_X and absf(pc2.y - c.y) <= PASS_X


func _return(dt: float) -> void:
	## Crawling back along the floor to its lane, then onto it.
	flier = false
	show_frame("creep_crawl1" if fmod(_crawl, 0.4) < 0.2 else "creep_crawl2")
	_crawl += dt
	if lane.is_empty():
		walk(dt, spd(RETURN))
		return
	var dx := float(lane["x"]) - position.x
	var reach: bool = position.y >= float(lane["top"]) + 8.0 and position.y <= float(lane["bottom"]) + TILE * 2.0 + 1.0
	if absf(dx) < 3.0 and reach:
		# Back on: up the lane from its foot.
		_set_up(true)
		position.x = float(lane["x"])
		position.y = clampf(position.y, lane_min(), float(lane["bottom"]))
		state = "crawl"
		dir = -1
		flier = true
		velocity = Vector2.ZERO
		return
	facing = 1 if dx > 0.0 else -1
	velocity.x = facing * minf(spd(RETURN), absf(dx) / maxf(dt, 0.001))
	if on_floor and not ground_ahead(facing) and absf(dx) > 3.0:
		velocity.x = 0.0
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
	if lost_in_pit():
		_kill({"how": "pit", "from_x": position.x})


func _set_up(up: bool) -> void:
	var s := UP_SIZE if up else DOWN_SIZE
	size = Vector2(s.x * scale_mult, maxf(s.y * scale_mult, SHOT_LINE if not up else 0.0))


func _hurt(h: Dictionary) -> void:
	## Any hit on its lane knocks it off: it falls on its back, dazed.
	if on_lane():
		_knock_off(float(h.get("from_x", position.x)))
		return
	super(h)


func _knock_off(from_x: float) -> void:
	state = "fallen"
	move_id = "touch"
	flier = false
	_tail = 0.0
	_set_up(false)
	var away := 1.0 if position.x >= from_x else -1.0
	if int(lane.get("side", 0)) != 0:
		away = -float(lane["side"])   # off a wall, away from it
	velocity = Vector2(away * 80.0, -120.0)
	apply_status("dazed", DAZED)
	status.erase("stun")
	status.erase("root")
	sfx("bone_skitter", "bones", 0.9)


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	if state == "stretched" and h.has("amount"):
		h["amount"] = float(h["amount"]) * STRETCH_BONUS
	return super(h)


func as_copy() -> void:
	## A Twinned half (never rolled for it, but a header may ask) lands on the floor.
	state = "fallen"
	flier = false
	_set_up(false)


func _maybe_partner() -> void:
	## Witching (and a level's packs twist, twists.gd): a second on the same
	## lane, out of step.
	if (difficulty() != "witching" and not Twists.on(self, "packs")) or partner or copy or respawned or lane.is_empty() or world == null or lane_len() < TILE * 3.0:
		return
	if not world.has_method("spawn_enemy"):
		return
	var o: Node2D = world.spawn_enemy("creepbone", Vector2(float(lane["x"]), float(lane["top"]) + lane_len() * 0.5 + size.y * 0.5),
			{"cell": Vector2i(-1, -1)})
	if o != null:
		o.set("partner", true)
		o.set("dir", -dir)
		o.set("_again", 0.6)
		o.active = active


func _kill(h: Dictionary) -> void:
	flier = false
	super(h)
	if str(h.get("how", "")) == "pit":
		velocity = Vector2(0.0, 60.0)


func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	if alive and on_lane() and bool(lane.get("vine", false)) and world != null and world.has_method("vine_present") and level != null:
		# Its rotten run snapped under it (WL3's guard; no level places one
		# on a rotten run today, and test_w3 holds that): it falls, dazed.
		var cx := floori(float(lane["x"]) / TILE)
		var cy := floori((position.y - 1.0) / TILE)
		if LevelData.is_climb(level.tile(cx, cy)) and not world.vine_present(cx, cy):
			_knock_off(position.x)
	if sprite and not frames.is_empty():
		# The frames are drawn head-up: flipped when it heads down its lane,
		# and laid on its back along the floor when it's off it.
		if on_lane():
			var up := dir < 0 if state == "crawl" else _lunge_dir < 0
			sprite.rotation = 0.0
			sprite.scale.y = absf(sprite.scale.y) * (1.0 if up else -1.0)
			sprite.position = Vector2(0, 0 if up else -size.y)
		else:
			# (drawn on the feet anchor: turned, the body runs from the anchor
			# along its heading, so the anchor sits half a body back)
			sprite.rotation = -PI * 0.5 * facing
			sprite.scale.y = -absf(sprite.scale.y)
			sprite.position = Vector2(-facing * size.x * 0.5, -size.y * 0.5)


func _dying(dt: float) -> void:
	show_frame("creep_hit")
	super(dt)


func head_point() -> Vector2:
	## Its skull (world space): at the end of the body it faces along the lane.
	if not on_lane():
		return position + Vector2(facing * (size.x * 0.5 - 4.0), -size.y * 0.5)
	var up := dir < 0 if state == "crawl" else _lunge_dir < 0
	return Vector2(position.x, position.y - size.y + 6.0) if up else Vector2(position.x, position.y - 6.0)


func lights() -> Array:
	var out := super()
	if alive and state == "coil":
		out.append({"p": head_point(), "r": 18.0, "s": 0.6})
	return out


func eye_points() -> Array:
	if tier == "" or has_omen("hushed"):
		return []
	return [head_point()]


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := gtb()
	var hp2 := head_point()
	# (Its own head points, not the frames': its frames are flipped and laid
	# on their side in code, which frame_point doesn't follow.)
	glow_eyes(tb, [hp2 + Vector2(-3.5, 0), hp2 + Vector2(3.5, 0)], GLINT, 3.0 if state != "coil" else 3.8)
	if state == "fallen":
		# Dazed on its back: three little stars wheel over its belly, upright
		# (creep_fall draws none: they'd turn with the frame).
		var belly := position + Vector2(0, -size.y * 0.5 - 7.0)
		for i in 3:
			var a := t * 4.0 + TAU * i / 3.0
			var sp := belly + Vector2(cos(a) * 9.0, sin(a) * 3.0)
			var r := 2.6
			tb.quad(sp + Vector2(0, -r), sp + Vector2(r * 0.35, 0), sp + Vector2(0, r), sp + Vector2(-r * 0.35, 0), Color(1.0, 0.92, 0.6, 0.85))
			tb.quad(sp + Vector2(-r, 0), sp + Vector2(0, -r * 0.35), sp + Vector2(r, 0), sp + Vector2(0, r * 0.35), Color(1.0, 0.92, 0.6, 0.85))
	if state == "coil" and on_lane():
		# The tell: an S of light along its spine, and the lunge's reach up or
		# down the lane.
		var k := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 9:
			var y := position.y - size.y * i / 8.0
			pts.append(Vector2(position.x + sin(i * 1.2 + t * 12.0) * 5.0, y))
		tb.polyline(pts, 1.6, Color(GLINT, 0.4 + 0.5 * k))
		var reach := LUNGE if difficulty() == "dusk" else LUNGE_NF
		var y0 := position.y - size.y if _lunge_dir < 0 else position.y
		var y1 := clampf(y0 + _lunge_dir * reach, float(lane["top"]), float(lane["bottom"]))
		tb.line(Vector2(position.x - 7.0, y0), Vector2(position.x - 7.0, y1), 1.2, Color(GLINT, 0.18 + 0.3 * k))
		tb.line(Vector2(position.x + 7.0, y0), Vector2(position.x + 7.0, y1), 1.2, Color(GLINT, 0.18 + 0.3 * k))
	if status.has("dazed"):
		var c := Vector2(position.x, rect().position.y - 5.0)
		for i in 3:
			var a := t * 5.0 + TAU * i / 3.0
			tb.circle(c + Vector2(cos(a) * 9.0, sin(a) * 3.0), 2.0, Color(1.0, 0.95, 0.6, 0.9), 8)
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var tb := btb()
	var sm := scale_mult
	if not on_lane():
		# Knocked off: on its back along the floor, legs kicking.
		var n := 6
		for i in n:
			var x := (-16.0 + i * 6.4) * sm
			var kick := sin(t * 18.0 + i) * 2.0
			cel_line(tb, Vector2(x, -7.0 * sm), Vector2(x - 2.0, -13.0 * sm + kick), 1.4 * sm, HAIR, 0.8)
			cel_circle(tb, Vector2(x, -5.0 * sm), 3.6 * sm, BONE if i % 2 == 0 else BONE_SHADE, 1.2, 10)
		var hx := float(facing) * 18.0 * sm
		cel_circle(tb, Vector2(hx, -6.0 * sm), 5.0 * sm, BONE, 1.6)
		tb.flush(self)
		return
	var up := dir < 0 if state == "crawl" else _lunge_dir < 0
	var h := size.y
	var coil := 0.0
	if state == "coil":
		coil = 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
	# The stretched tail after a lunge.
	if _tail > 0.0:
		var ty := -h if not up else 0.0
		var sgn := 1.0 if up else -1.0
		for i in 4:
			var yy := ty + sgn * (_tail * (i + 1) / 4.0)
			tb.circle(Vector2(0, yy), 2.6 * sm, pc(Color(BONE_SHADE, 0.7)), 8)
	var segs := 6
	# The spine first (a dark cord the knuckles hang on), then the bones.
	var spine := PackedVector2Array()
	for i in segs:
		var k0 := float(i) / (segs - 1)
		var y0 := -h * (0.12 + 0.76 * k0) if up else -h * (0.88 - 0.76 * k0)
		spine.append(Vector2(sin(k0 * TAU * 0.9 + t * (3.0 if state == "crawl" else 0.0)) * (1.2 + coil * 5.0), y0))
	tb.polyline(spine, 3.0 * sm, pc(OUTLINE))
	for i in segs:
		var k := float(i) / (segs - 1)
		var p: Vector2 = spine[i]
		var wig := sin(_crawl * 18.0 + i) * 2.0
		cel_line(tb, p + Vector2(-4.0, 0), p + Vector2(-9.0, wig + 2.0), 1.4 * sm, HAIR, 0.8)
		cel_line(tb, p + Vector2(4.0, 0), p + Vector2(9.0, -wig + 2.0), 1.4 * sm, HAIR, 0.8)
		cel_ellipse(tb, p, 5.0 * sm, 3.6 * sm, BONE if i % 2 == 0 else BONE_SHADE, 1.4, 12)
		tb.rect(Rect2(p + Vector2(-1.0, -1.0) * sm, Vector2(2.0, 2.0) * sm), pc(Color(BONE_SHADE, 0.9)))
	# The grinning skull at the head.
	var hy := -h + 6.5 if up else -6.5
	cel_circle(tb, Vector2(0, hy), 6.8 * sm, BONE, 1.8)
	var jaw := 4.5 if up else -4.5
	for j in 4:
		tb.rect(Rect2(Vector2(-3.8 + j * 2.0, hy + jaw - 1.2), Vector2(1.4, 2.4)), pc(Color("2a2030")))
	tb.circle(Vector2(-3.5, hy - jaw * 0.25), 2.0, pc(Color("2a2030")), 8)
	tb.circle(Vector2(3.5, hy - jaw * 0.25), 2.0, pc(Color("2a2030")), 8)
	tb.flush(self)
