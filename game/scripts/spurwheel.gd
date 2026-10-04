extends "res://scripts/elites.gd"
## Spurwheel (q, World 4): a spiked brass cog with a stern little hub face,
## frost on its teeth and a red-orange grinder rim (no platform cog ever has
## it). It rolls along the edges of solid tiles, floor, wall and ceiling,
## clockwise when it faces right, at ROLL px/s. Every ROLL_MAX s of rolling,
## and at every outer corner, it jams: a JAM s tell (sparks, a ratchet, the
## face grimaces, a glint r 18), then CAUGHT s caught (its teeth stop: poise
## 0, full damage), then a RESPIN s re-spin tell, and it rolls on (round the
## corner, if it jammed at one). A faint frost trail shows its route 3 tiles
## ahead.
##
## It keeps inside the level: an outline that runs out of it (a pit's wall
## down to the level's open bottom, a face that meets the level's edge or its
## top) is an end, and at an end it jams and catches as at a corner, then
## rolls back the way it came. So a wheel on a floor between two pits
## patrols it, catching at each lip; round a block it goes all the way round.
##
## Rolling (and jamming, and spinning up), hit() is false (a clang, and Wick
## is pushed back 100 px/s), its touch hurts and a stomp hurts him (spikes).
## Caught, a stomp deals 2x and holds the catch 0.5 s more. The Bellfounder's
## maul on a rolling Spurwheel forces a catch; Grave Chill's root counts as
## one, and so does the knight's Perfect Guard (its stagger). Never
## Anointed (a Dread may be one). Nightfall (and a Dread on Dusk from World 3, behave_diff): 170 px/s, caught 0.85 s. Witching: 190, caught 0.75 s, and it hops at outer corners.
## (The spec's re-spin is 0.30 s; it's 0.50 here, floor 0.40: rule 1's
## escape formula for Wick hugging it when it rolls on, 0.35 + 24/205. The
## window itself stays CAUGHT s: a re-spinning wheel clangs.) Caught, its
## still teeth don't hurt to touch.

const MOVES := {"touch": 32.0}
const ARCHETYPE := "heavy"
const TELLS := {"jam": {"sec": 0.40, "floor": 0.30}, "respin": {"sec": 0.50, "floor": 0.40, "escape_px": 24.0}}
const FRAMES := ["spur_roll", "spur_catch", "spur_hit",
	# (A3: the face, drawn upright over the turning cog; the cog's own frames
	# point no way)
	"spur_face", "spur_face_catch", "spur_face_hit"]
# The face's eyes in px from the hub, unturned (A3's spur_face eye1 / eye2).
const FACE_EYES := [Vector2(-2.4, -1.0), Vector2(2.5, -1.2)]
const ROLL := 150.0
const ROLL_NF := 170.0
const ROLL_WITCHING := 190.0
const ROLL_MAX := 2.5
const JAM := 0.40
const CAUGHT := 1.0
const CAUGHT_NF := 0.85
const CAUGHT_WITCHING := 0.75
const RESPIN := 0.50
const STOMP_HOLD := 0.5
const STOMP_MULT := 2.0
const R := 14.0
const PUSH := 100.0
const TRAIL := 96.0
const HOP := 10.0
const BRASS := Color("c8a24a")
const BRASS_DARK := Color("8a6a2a")
const RIM := Color("e0602a")
const FROST := Color("dcefff")

var state := "fall"              # fall (until it lands), roll, jam, caught, respin, pivot
var timer := 0.0
var tell_len := 0.0
var move_id := "touch"
var contact := Vector2.ZERO      # the point it touches on the surface
var nrm := Vector2(0, -1)        # the surface's outward normal (one of the four)
var tdir := Vector2(1, 0)        # the way it rolls along it
var spin := 0.0                  # the drawn rotation
var _roll_t := 0.0
var _corner := false             # jammed at an outer corner: it goes round after
var _reverse := false            # jammed at an end of its outline: it rolls back after
var _pivot := 0.0                # 0..1 round the corner
var _pivot_from := Vector2.ZERO
var _sound_t := 0.0
var _spark_t := 0.0


func _init() -> void:
	kind = "spurwheel"
	size = Vector2(28, 28)
	base_hp = 30.0
	base_dmg = MOVES["touch"]
	poise = 0.0
	stompable = false
	embers = 4
	item_chance = 0.10
	relic_chance = 0.03
	flier = true                 # it keeps to its surface (no tile physics once rolling)


var face: Sprite2D = null        # the upright face over the cog (spur_face*), when drawn


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("spur_roll")
	anchor = Vector2(64, 64)
	if sprite:
		sprite.offset = -anchor * 2.0
		if frames.has("spur_face"):
			face = Sprite2D.new()
			face.texture = frames["spur_face"]
			face.centered = false   # as the cog (enemy.gd): the offset puts its hub on the cog's
			face.offset = -anchor * 2.0
			face.texture_filter = sprite.texture_filter
			add_child(face)


func cw() -> bool:
	return facing > 0


func hub() -> Vector2:
	## Its middle (the box is the square round it; position is its foot).
	return position - Vector2(0, R * scale_mult)


func rolling() -> bool:
	return state in ["roll", "jam", "respin", "pivot", "fall"]


func caught() -> bool:
	return state == "caught"


func roll_speed() -> float:
	return spd(by_behave(ROLL, ROLL_NF, ROLL_WITCHING))


func caught_len() -> float:
	return float(by_behave(CAUGHT, CAUGHT_NF, CAUGHT_WITCHING))


func _set_hub(c: Vector2) -> void:
	position = c + Vector2(0, R * scale_mult)


func touch_damage() -> bool:
	return not caught()


func _stunned(_dt: float) -> void:
	pass   # a stun is a catch (apply_status); it never falls off its surface


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_sound_t -= dt
	match state:
		"fall":
			# Dropped (or placed in the air): down to a floor, then it rolls.
			flier = false
			velocity.x = 0.0
			velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
			move(dt)
			if lost_in_pit():
				_kill({"how": "pit", "from_x": position.x})
				return
			if on_floor:
				flier = true
				contact = position
				nrm = Vector2(0, -1)
				tdir = _t_of(nrm)
				state = "roll"
				_roll_t = 0.0
		"roll":
			stompable = false
			_roll_t += dt
			var d := roll_speed() * dt
			spin += d / (R * scale_mult) * (1.0 if cw() else -1.0)
			var what := _advance(d)
			if what == "outer":
				_start_jam(true)
			elif what == "end":
				_start_jam(false)
				_reverse = true
			elif _roll_t >= ROLL_MAX:
				_start_jam(false)
			if _sound_t <= 0.0 and player != null and player.center().distance_to(hub()) < 200.0:
				_sound_t = 0.4
				sfx("gear_roll", "rush", 0.8)
		"jam":
			stompable = false
			_spark_t -= dt
			if _spark_t <= 0.0 and world != null and world.get("glow") != null:
				_spark_t = 0.05
				world.glow.burst(contact, 2, Color(1.0, 0.7, 0.3, 0.95), 150.0, 0.25, 400.0, 1.6, 60.0)
			if timer <= 0.0:
				state = "caught"
				timer = caught_len()
				stompable = true   # (the jam's gear_catch tell lands here)
		"caught":
			stompable = true
			if timer <= 0.0:
				state = "respin"
				timer = tell(RESPIN, TELLS["respin"]["floor"])
				tell_len = timer
				stompable = false
				sfx("gear_spark", "clink", 1.2)
		"respin":
			stompable = false
			spin += dt * 10.0 * (1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)) * (1.0 if cw() else -1.0)
			if timer <= 0.0:
				_roll_t = 0.0
				if _corner:
					_corner = false
					_begin_pivot()
				elif _reverse:
					_turn_back()
				else:
					state = "roll"
		"pivot":
			stompable = false
			var arc := PI * 0.5 * R * scale_mult
			_pivot = minf(_pivot + roll_speed() * dt / arc, 1.0)
			var a := _pivot * PI * 0.5
			var old_n := -tdir         # after the turn, tdir is the old normal's opposite
			var c := contact + (old_n * cos(a) + nrm * sin(a)) * R * scale_mult
			if difficulty() == "witching":
				c += (old_n + nrm).normalized() * HOP * sin(_pivot * PI)
			_set_hub(c)
			spin += roll_speed() * dt / (R * scale_mult) * (1.0 if cw() else -1.0)
			if _pivot >= 1.0:
				_set_hub(contact + nrm * R * scale_mult)
				state = "roll"
	on_floor = state != "fall" and nrm.y < -0.5
	if level != null and state != "fall" and not Rect2(Vector2.ZERO, level.pixel_size()).grow(TILE).has_point(hub()):
		# (Never on any outline it can roll: a last guard, so a wheel can't
		# live on out of sight.)
		_kill({"how": "pit", "from_x": position.x})


func _t_of(n: Vector2) -> Vector2:
	## The way it rolls on a surface with this normal (clockwise faces right).
	return Vector2(-n.y, n.x) if cw() else Vector2(n.y, -n.x)


func _void(p: Vector2) -> bool:
	## Outside the level (level.tile calls the sides stone and the bottom a
	## pit; to the wheel all of it is nowhere to roll).
	if level == null:
		return true
	var x := floori(p.x / TILE)
	var y := floori(p.y / TILE)
	return x < 0 or y < 0 or x >= level.width or y >= level.height


func _solid(p: Vector2) -> bool:
	return not _void(p) and LevelData.is_solid(level.tile(floori(p.x / TILE), floori(p.y / TILE)))


func _face_open(c: Vector2, n: Vector2, tv: Vector2) -> bool:
	## Does the face from c (normal n, running tv) run out of the level
	## before it turns a corner? (A pit's wall to the open bottom does.)
	for i in 64:
		var along := c.x if tv.x != 0.0 else c.y
		var sgn := signf(tv.x) if tv.x != 0.0 else signf(tv.y)
		var next := (floorf(along / TILE + 0.0001) + 1.0) * TILE if sgn > 0.0 else (ceilf(along / TILE - 0.0001) - 1.0) * TILE
		var k := c + tv * absf(next - along)
		var air := k + tv * 0.5 + n * 0.5
		var stone := k + tv * 0.5 - n * 0.5
		if _void(air) or _void(stone):
			return true
		if _solid(air) or not _solid(stone):
			return false   # a corner inside the level: the outline goes on
		c = k
	return false


func _advance(d: float) -> String:
	## Rolls d px along the surface: "outer" when it reached an outer corner
	## (it stops there, still on the old face, until the jam is over), "end"
	## when its outline runs out of the level (it stops, and rolls back after
	## its jam), else "".
	var w := walk_surface(contact, nrm, tdir, d, true)
	contact = w["c"]
	nrm = w["n"]
	tdir = w["t"]
	_set_hub(contact + nrm * R * scale_mult)
	if bool(w.get("end", false)):
		return "end"
	return "outer" if bool(w["outer"]) else ""


func _turn_back() -> void:
	## At an end of its outline: the same face, the other way (and it spins
	## the other way).
	_reverse = false
	facing = -facing
	tdir = -tdir
	state = "roll"


func walk_surface(c: Vector2, n: Vector2, tv: Vector2, d: float, stop_outer: bool, pts: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	## The rolling itself, for the wheel and its trail: from contact c on a
	## face with normal n, rolling tv, d px. An inner corner (a wall ahead)
	## turns it up the wall R before the corner, so the hub never jumps; an
	## outer corner stops it there (stop_outer) or turns it round (the trail).
	## pts gains the hub's path.
	## An end (the outline runs out of the level) stops it with "end" true
	## (the wheel jams there and rolls back; the trail stops there): r short
	## of a face that meets the level's edge or top, or of a wall that climbs
	## out of it, and at the lip of a pit whose wall runs down to the open
	## bottom.
	var r := R * scale_mult
	var guard := 0
	while d > 0.0001 and guard < 16:
		guard += 1
		var along := c.x if tv.x != 0.0 else c.y
		var sgn := signf(tv.x) if tv.x != 0.0 else signf(tv.y)
		var next := (floorf(along / TILE + 0.0001) + 1.0) * TILE if sgn > 0.0 else (ceilf(along / TILE - 0.0001) - 1.0) * TILE
		var k := c + tv * absf(next - along)       # the grid corner ahead
		var air := k + tv * 0.5 + n * 0.5
		var stone := k + tv * 0.5 - n * 0.5
		var end := _void(air) or _void(stone)    # the face meets the level's edge: stop r short
		var wall := not end and _solid(air)
		var short := r if end or wall else 0.0
		if wall and _face_open(k + n * r, -tv, n):
			end = true                                  # a wall that climbs out of the level: r short
			wall = false
		elif not end and not wall and not _solid(stone) and _face_open(k, tv, -n):
			end = true                                  # round this corner it would go out (a pit's lip): at the lip
		var stop := maxf(absf(next - along) - short, 0.0)
		if stop > d:
			c += tv * d
			d = 0.0
			pts.append(c + n * r)
			break
		c += tv * stop
		d -= stop
		pts.append(c + n * r)
		if end:
			return {"c": c, "n": n, "t": tv, "outer": false, "end": true}
		if wall:
			# Inner corner: onto the wall face, the hub where it is.
			var corner := c + tv * r
			var old_n := n
			c = corner + old_n * r
			n = -tv
			tv = old_n
		elif not _solid(k + tv * 0.5 - n * 0.5):
			if stop_outer:
				return {"c": c, "n": n, "t": tv, "outer": true}
			var o := n
			n = tv
			tv = -o
			pts.append(c + n * r)
	return {"c": c, "n": n, "t": tv, "outer": false}


func _begin_pivot() -> void:
	## Round an outer corner: the face's normal becomes the way it was rolling.
	var old_n := nrm
	nrm = tdir
	tdir = -old_n
	_pivot = 0.0
	state = "pivot"


func _start_jam(at_corner: bool) -> void:
	state = "jam"
	_corner = at_corner
	timer = tell(JAM, TELLS["jam"]["floor"])
	tell_len = timer
	_spark_t = 0.0
	tell_sfx("gear_catch", timer, "clang")   # fitted: its catch lands as the window opens


func force_catch(sec := -1.0) -> void:
	## Caught now (a maul, a root, a stun): open for sec (else its catch).
	if state == "caught":
		timer = maxf(timer, sec)
		return
	if state == "pivot":
		_set_hub(contact + nrm * R * scale_mult)
		_corner = false
	state = "caught"
	timer = maxf(caught_len(), sec)
	stompable = true
	sfx("gear_catch", "clang", 0.9)


func apply_status(name: String, seconds: float, data := {}) -> void:
	if name in ["stun", "root", "flipped", "dazed"]:
		# Grave Chill's root is a catch, and so is a Perfect Guard's stagger
		# (the knight's, perfect_guarded()); any other stun (a shield's
		# shove, a Peal, a Bell Shard) doesn't stop the teeth.
		if state != "fall" and (name != "stun" or perfect_guarded() or caught()):
			force_catch(seconds)
		return
	super(name, seconds, data)


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	var how := str(h.get("how", "slash"))
	if not caught():
		if is_maul(h) and state != "fall":
			# The maul ignores poise: it jams the cog at once, no damage.
			force_catch()
			flash = 0.4
			return false
		# Rolling teeth: a clang, and a shove back for him.
		flash = 0.2
		sfx("clang", "", 1.3)
		if world != null and world.get("player") != null and how in ["slash", "skill"]:
			var pl: Node2D = world.player
			var away := 1.0 if pl.position.x >= position.x else -1.0
			# A shove back (a displacement; never started in the air, so
			# never over a pit; the edge brake keeps a grounded one on stone).
			if world.has_method("push_player") and pl.on_floor:
				world.push_player(Vector2(away * PUSH, 0.0), 0.2, "spurwheel")
		return false
	if how == "stomp" and h.has("amount"):
		h["amount"] = float(h["amount"]) * STOMP_MULT
		timer += STOMP_HOLD
	return super(h)


func _hurt(_h: Dictionary) -> void:
	pass   # caught, it doesn't budge; the flash shows the hit


func _kill(h: Dictionary) -> void:
	flier = false
	super(h)


func _dying(dt: float) -> void:
	show_frame("spur_hit")
	super(dt)


func lights() -> Array:
	var out := super()
	if alive and state == "jam":
		out.append({"p": hub(), "r": 18.0, "s": 0.6})
	return out


func eye_points() -> Array:
	if tier == "" or has_omen("hushed"):
		return []
	return _face_eyes()


func _face_eyes() -> Array:
	## The face's two eyes (world space): upright, mirrored with its heading.
	var f := 1.0 if facing > 0 else -1.0
	var out := []
	for e in FACE_EYES:
		out.append(hub() + Vector2((e as Vector2).x * f, (e as Vector2).y) * scale_mult)
	return out


func route_ahead(dist := TRAIL) -> PackedVector2Array:
	## Where its hub will go over the next dist px of rolling (the frost trail).
	var out := PackedVector2Array()
	if state == "fall":
		return out
	var n := nrm
	var tv := tdir
	if _corner and state in ["jam", "caught", "respin"]:
		# Waiting at an outer corner: its route goes round it.
		var o := n
		n = tv
		tv = -o
	elif _reverse and state in ["jam", "caught", "respin"]:
		tv = -tv   # waiting at an end: its route goes back the way it came
	out.append(contact + n * R * scale_mult)
	walk_surface(contact, n, tv, dist, false, out)
	return out


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := gtb()
	# The frost trail: its route 3 tiles ahead, faint dots on the stone.
	var route := route_ahead()
	for i in range(1, route.size()):
		var a: Vector2 = route[i - 1]
		var b: Vector2 = route[i]
		var n := int(a.distance_to(b) / 10.0) + 1
		for j in n:
			var p := a.lerp(b, float(j) / n)
			var k := 1.0 - float(i - 1 + float(j) / n) / maxf(route.size() - 1, 1)
			tb.circle(p + (p - hub()).normalized() * 0.0, 1.6, Color(FROST, 0.18 + 0.2 * k), 6)
	var c := hub()
	if state == "jam":
		var k2 := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
		tb.ring(c, R * scale_mult + 3.0, 2.0, Color(1.0, 0.7, 0.3, 0.45 + 0.45 * k2), 20)
	elif state == "caught":
		# Open: a calm white ring counts the window down.
		var kk := clampf(timer / maxf(caught_len(), 0.01), 0.0, 1.0)
		tb.ring(c, R * scale_mult + 4.0, 2.0, Color(1, 1, 1, 0.55), 24, -PI * 0.5, -PI * 0.5 + TAU * kk)
	elif state == "respin":
		# The window closes: the grinder rim glows hot and spins up.
		var k3 := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
		tb.ring(c, R * scale_mult + 2.0, 2.5, Color(RIM, 0.5 + 0.5 * k3), 24)
		for i in 6:
			var a2 := spin + TAU * i / 6.0
			var p2 := c + Vector2(cos(a2), sin(a2)) * (R * scale_mult + 5.0)
			tb.line(p2, p2 + Vector2(cos(a2 + 1.4), sin(a2 + 1.4)) * 5.0, 1.4, Color(1.0, 0.75, 0.4, 0.6 * k3))
	else:
		# Its grinder rim reads in the dark (the Spurwheel's alone).
		tb.ring(c, R * scale_mult + 1.0, 1.4, Color(RIM, 0.35), 20)
	glow_eyes(tb, _face_eyes(), Color(1.0, 0.85, 0.6), 3.0)
	tb.flush(glow)


func _draw() -> void:
	if sprite:
		# The cog turns with it (rotated in code: its teeth bristle while it
		# jams, is caught and spins up); the face over it stays upright.
		var held := state in ["jam", "caught", "respin"]
		if alive:
			show_frame("spur_catch" if held else "spur_roll")
		sprite.rotation = spin
		sprite.position = Vector2(0, -R * scale_mult)
		if face != null:
			var fk := "spur_face_hit" if not alive else ("spur_face_catch" if held else "spur_face")
			if frames.has(fk):
				face.texture = frames[fk]
			face.position = sprite.position
			face.rotation = 0.0
			face.scale = sprite.scale
			face.modulate = sprite.modulate
			face.visible = sprite.visible
	if not frames.is_empty():
		return
	var tb := btb()
	var sm := scale_mult
	var c := Vector2(0, -R * sm)
	var rr := R * sm
	# The spiked rim: teeth round a red-orange grinder band.
	for i in 10:
		var a := spin + TAU * i / 10.0
		var d := Vector2(cos(a), sin(a))
		var o := d.orthogonal()
		cel_poly(tb, PackedVector2Array([c + d * (rr - 2.0) + o * 3.0, c + d * (rr + 4.5), c + d * (rr - 2.0) - o * 3.0]),
				FROST if i % 3 == 0 else BRASS, 1.2)
	cel_circle(tb, c, rr - 1.0, RIM, 2.0, 20)
	cel_circle(tb, c, rr - 4.0, BRASS, 0.0, 20)
	cel_circle(tb, c, rr * 0.45, BRASS_DARK, 1.2, 14)
	# The stern hub face (it grimaces while it jams).
	var grim := state in ["jam", "respin"]
	tb.circle(c + Vector2(-2.6, -1.0), 1.3, pc(Color("1c1830")), 8)
	tb.circle(c + Vector2(2.6, -1.0), 1.3, pc(Color("1c1830")), 8)
	tb.line(c + Vector2(-4.0, -3.5), c + Vector2(-1.2, -2.2 if grim else -3.0), 1.2, pc(Color("1c1830")))
	tb.line(c + Vector2(4.0, -3.5), c + Vector2(1.2, -2.2 if grim else -3.0), 1.2, pc(Color("1c1830")))
	tb.line(c + Vector2(-2.5, 2.5), c + Vector2(2.5, 2.5 if not grim else 1.5), 1.2, pc(Color("1c1830")))
	tb.flush(self)
