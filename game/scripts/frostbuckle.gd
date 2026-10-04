extends "res://scripts/elites.gd"
## Frostbuckle (e, World 4 brute): a big chibi knight-statue frozen in a
## block of wax-ice, with a tower shield of ice, an icicle beard and one
## lantern-blue eye. Its rime is a shell worth RIME_SHARE of its life that
## breaks first (a blue segment over its bar): while it holds it doesn't
## flinch or stun and Grave Chill doesn't root it; fire deals x2.5 to it,
## the maul and a stomp x2, a Finisher x1.5. Breaking it shatters: THAWED s stunned, and
## its poise drops to 0.3. The rime regrows after REGROW s unhit (6 s on
## Nightfall and up, and for an elite on Dusk from World 3): the shell comes
## back over the life it has left (up to RIME_SHARE of its most), with no
## healing, so a broken shell's damage stays done. The shell is sized on the
## life it spawns with (after a Twinned half's share or a mode's scaling).
##
## It advances at ADVANCE px/s once Wick is within SEE px; turning takes
## TURN s (a slow swivel: Backstabs land in it). Frost Stomp (Wick within
## STOMP_X on its floor): the tell (0.70 s) is a line of ice cracks glowing
## along the floor toward him for its whole length, every tile that will
## spike; then spikes erupt tile by tile (the front at 400 px/s), each 20x28
## for 0.35 s, up to 7 tiles (9 on Nightfall, and for an elite on Dusk from
## World 3: behave_diff), stopping at walls and edges.
## Shield Slam (Wick within SLAM_X in front): tell 0.70 s (floor 0.50: the
## escape formula for a 60 px slam), the rim flashing white; a 60 px slam,
## then 0.8 s of recovery with the shield low. A Perfect Guard on the slam
## staggers it 1.0 s (the knight's own, perfect_guarded(): a Peal's or a
## Bell Shard's stun still can't while it's rimed). Witching: a second line 0.5 s after the first (both
## drawn from the start).

const MOVES := {"slam": 36.0, "spike_line": 34.0, "touch": 28.0}
const ARCHETYPE := "brute"
const TELLS := {"stomp": {"sec": 0.70, "floor": 0.40, "jump": true},
		"slam": {"sec": 0.70, "floor": 0.50, "escape_px": 70.0}}
const FRAMES := ["buckle_idle", "buckle_walk1", "buckle_walk2", "buckle_raise", "buckle_stomp", "buckle_slam",
		"buckle_thawed", "buckle_hit", "buckle_shell"]
const RIME_SHARE := 0.40
const FIRE_RIME := 2.5
const MAUL_RIME := 2.0
const FINISHER_RIME := 1.5
const THAWED := 1.2
const THAWED_POISE := 0.3
const REGROW := 8.0
const REGROW_NF := 6.0
const SEE := 260.0
const ADVANCE := 36.0
const TURN := 0.6
const STOMP_X := 200.0
const STOMP := 0.70
const SPIKE_STEP := 0.08           # a tile each 0.08 s: the front at 400 px/s
const SPIKE_LIFE := 0.35
const SPIKE_SIZE := Vector2(20, 28)
const LINE_TILES := 7
const LINE_TILES_NF := 9
const SECOND_LINE := 0.5
const SLAM_X := 56.0
const SLAM := 0.70
const SLAM_REACH := 60.0
const SLAM_ACTIVE := 0.12
const RECOVER := 0.8
const AGAIN := 1.3                 # s between its moves
const STEEL := Color("7a8aa6")
const STEEL_DARK := Color("4a5670")
const ICE := Color("a8d4ec")
const ICE_LIT := Color("dcefff")
const EYE := Color("7ad8ff")

var state := "stand"               # stand, advance, turn, stomp, slam, strike, recover
var timer := 0.0
var tell_len := 0.0
var move_id := "touch"
var rime := 0.0                    # the shell left (life points, part of hp)
var rime_max := 0.0
var lines: Array = []              # [{cells: [x], fy, dir, at, hit}] spike lines (at: s since it started running, < 0 waiting)
var _again := 0.0
var _unhit := 0.0
var _walk := 0.0
var _slam_hit := false
var _turn_to := 1
var _shell_sprite: Sprite2D
var last_move := ""                # the last move it made ("slam", "spike_line")


func _init() -> void:
	kind = "frostbuckle"
	size = Vector2(34, 40)
	base_hp = 70.0
	base_dmg = MOVES["touch"]
	poise = 1.0
	embers = 7
	item_chance = 0.16
	relic_chance = 0.04
	echo_by_body = false


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("buckle_idle")
	_shell_sprite = Sprite2D.new()
	_shell_sprite.centered = false
	_shell_sprite.offset = -anchor * 2.0
	_shell_sprite.texture = frames.get("buckle_shell")
	add_child(_shell_sprite)
	# The shell on the life it spawned with: world.spawn_enemy scales a
	# Twinned half (hp_frac) and a mode rescales (on_spawn) after
	# setup_stats, and before this.
	_size_rime()


func setup_stats(a: int, d: String, strength := "normal", world_n := 0) -> void:
	super(a, d, strength, world_n)
	_size_rime()


func _size_rime() -> void:
	rime_max = RIME_SHARE * max_hp
	rime = minf(rime_max, hp)


func rimed() -> bool:
	return rime > 0.0


func dmg(what := "touch") -> float:
	return float(MOVES.get(what, base_dmg)) * dmg_mult


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_again = maxf(_again - dt, 0.0)
	var dx: float = player.position.x - position.x
	match state:
		"stand", "advance":
			move_id = "touch"
			var near: bool = player.alive and absf(dx) < SEE and absf(player.position.y - position.y) < 80.0
			if not near:
				state = "stand"
				_brake(dt)
				show_frame("buckle_idle")
				return
			var want := 1 if dx > 0.0 else -1
			if want != facing and absf(dx) > 8.0:
				state = "turn"
				_turn_to = want
				timer = TURN
				return
			if _again <= 0.0:
				if absf(dx) <= SLAM_X + size.x * 0.5 and near_floor(player, 40.0):
					_start_slam()
					return
				if absf(dx) <= STOMP_X and near_floor(player) and player.on_floor:
					_start_stomp(player)
					return
			state = "advance"
			if on_floor and not ground_ahead(facing):
				_brake(dt)
			else:
				walk(dt, spd(ADVANCE))
			_walk += dt
			show_frame("buckle_walk1" if fmod(_walk, 0.7) < 0.35 else "buckle_walk2")
			if fmod(_walk, 0.7) < dt:
				sfx("heavy_step", "land", 0.8)
		"turn":
			_brake(dt)
			show_frame("buckle_idle")
			if timer <= 0.0:
				facing = _turn_to
				state = "stand"
		"stomp":
			_brake(dt)
			show_frame("buckle_raise")
			if timer <= 0.0:
				show_frame("buckle_stomp")
				for ln in lines:
					if float(ln["at"]) < -900.0:
						ln["at"] = 0.0 if ln == lines[0] else -SECOND_LINE
				sfx("ice_spike", "boss_slam", 1.1)
				if world != null and world.has_method("dust_at"):
					world.dust_at(position + Vector2(facing * 14.0, 0))
				state = "recover"
				timer = 0.5
				last_move = "spike_line"
				_again = AGAIN
		"slam":
			_brake(dt)
			show_frame("buckle_raise")
			if timer <= 0.0:
				state = "strike"
				timer = SLAM_ACTIVE
				move_id = "slam"
				_slam_hit = false
				sfx("heavy_step", "boss_slam", 1.2)
				strike_logged({"rect": slam_rect(), "life": SLAM_ACTIVE}, dmg("slam"))
		"strike":
			_brake(dt)
			show_frame("buckle_slam")
			if not _slam_hit and player.alive and slam_rect().intersects(player.rect()) and world != null:
				_slam_hit = true
				world.hurt_player(dmg("slam"), position.x, "hit", self, {"move": "slam"})
			if timer <= 0.0:
				state = "recover"
				timer = RECOVER
				last_move = "slam"
				move_id = "touch"
				_again = AGAIN
		"recover":
			_brake(dt)
			show_frame("buckle_slam" if last_move == "slam" else "buckle_idle")
			if timer <= 0.0:
				state = "stand"
	_step_lines(dt, player)


func _brake(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * dt)
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)


func slam_rect() -> Rect2:
	## The slam's reach in front of the shield.
	var x0 := position.x + facing * size.x * 0.5
	var w := SLAM_REACH * scale_mult
	return Rect2(x0 if facing > 0 else x0 - w, position.y - size.y * 0.85, w, size.y * 0.85)


func _start_slam() -> void:
	state = "slam"
	var sec := tell(SLAM, TELLS["slam"]["floor"])
	timer = sec
	tell_len = sec
	move_id = "slam"
	tell_sfx("ice_creak", sec, "creak")


func _start_stomp(player: Node2D) -> void:
	## The tell: the whole line cracks now (and Witching's second with it).
	state = "stomp"
	var sec := tell(STOMP, TELLS["stomp"]["floor"])
	timer = sec
	tell_len = sec
	move_id = "spike_line"
	var dir := 1 if player.position.x > position.x else -1
	facing = dir
	lines.clear()
	var cells := spike_cells(dir)
	lines.append({"cells": cells, "fy": floori((position.y + 1.0) / TILE), "dir": dir, "at": -1000.0, "hit": false, "logged": 0})
	if difficulty() == "witching":
		lines.append({"cells": cells.duplicate(), "fy": floori((position.y + 1.0) / TILE), "dir": dir, "at": -1000.0, "hit": false, "logged": 0})
	tell_sfx("ice_creak", sec, "creak")


func spike_cells(dir: int) -> Array:
	## The tiles the line will spike: from the one in front of it along its
	## floor, up to 7 (9 on Nightfall and up), stopping at a wall or an edge.
	var out := []
	if level == null:
		return out
	var n := LINE_TILES if behave_diff() == "dusk" else LINE_TILES_NF
	var fy := floori((position.y + 1.0) / TILE)
	var x := floori((position.x + dir * size.x * 0.5) / TILE)
	if dir < 0 and fmod(position.x + dir * size.x * 0.5, TILE) == 0.0:
		x -= 1
	for i in n:
		if LevelData.is_solid(level.tile(x, fy - 1)) or not LevelData.is_floor(level.tile(x, fy)):
			break
		out.append(x)
		x += dir
	return out


func spike_rect(ln: Dictionary, i: int) -> Rect2:
	var x: int = ln["cells"][i]
	var fy: int = ln["fy"]
	return Rect2(x * TILE + (TILE - SPIKE_SIZE.x) * 0.5, fy * TILE - SPIKE_SIZE.y, SPIKE_SIZE.x, SPIKE_SIZE.y)


func spike_up(ln: Dictionary, i: int) -> bool:
	## Is the line's i-th spike out now?
	var at := float(ln["at"])
	var t0 := i * SPIKE_STEP
	return at >= t0 and at < t0 + SPIKE_LIFE


func _step_lines(dt: float, player: Node2D) -> void:
	for ln in lines:
		if float(ln["at"]) < -900.0:
			continue
		ln["at"] = float(ln["at"]) + dt
		var cells: Array = ln["cells"]
		# Each spike as it breaks the floor (the Echoing Omen repeats it there).
		while int(ln["logged"]) < cells.size() and float(ln["at"]) >= int(ln["logged"]) * SPIKE_STEP:
			strike_logged({"rect": spike_rect(ln, int(ln["logged"])), "life": SPIKE_LIFE}, dmg("spike_line"))
			ln["logged"] = int(ln["logged"]) + 1
		if ln["hit"] or player == null or not player.alive or world == null:
			continue
		for i in cells.size():
			if spike_up(ln, i) and spike_rect(ln, i).intersects(player.rect()):
				ln["hit"] = true
				world.hurt_player(dmg("spike_line"), spike_rect(ln, i).get_center().x, "spikes", self, {"move": "spike_line"})
				break
	lines = lines.filter(func(ln): return float(ln["at"]) < -900.0 or float(ln["at"]) < (ln["cells"] as Array).size() * SPIKE_STEP + SPIKE_LIFE)


func _step_rime(dt: float) -> void:
	_unhit += dt
	if rime <= 0.0 and rime_max > 0.0 and _unhit >= (REGROW if behave_diff() == "dusk" else REGROW_NF):
		# The rime regrows over the life it has (no healing).
		rime = minf(rime_max, hp)
		poise = 1.0
		sfx("rime_freeze", "clink", 1.0)
		if world != null and world.get("glow") != null:
			world.glow.burst(center(), 12, Color(ICE_LIT, 0.9), 60.0, 0.5, 0.0, 2.4)


func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	if _ward_blocks(h):
		return false   # a Warded mote took it (the rime is untouched)
	if not h.has("amount") or rime <= 0.0:
		var ok0 := super(h)
		if ok0:
			_unhit = 0.0
		return ok0
	# The rime takes the blow first, the right tools harder.
	var a := float(h["amount"])
	var k := 1.0
	if fire_hit(h):
		k = FIRE_RIME
	elif is_maul(h) or str(h.get("how", "")) == "stomp":
		k = MAUL_RIME   # the maul, and a stomp (p_monsters §9: 2x into rime)
	elif is_finisher(h):
		k = FINISHER_RIME
	var into := minf(a * k, rime)
	rime -= into
	var rest := maxf(a - into / k, 0.0)
	h = h.duplicate()
	h["amount"] = into + rest
	h["crit"] = false
	var p0 := poise
	poise = INF   # rimed: no flinch
	var ok := super(h)
	poise = p0
	_unhit = 0.0
	if ok and alive and rime <= 0.0:
		_shatter()
	elif ok:
		sfx("ice_creak", "clink", 1.5)
	return ok


func _shatter() -> void:
	## The rime breaks: a stun, and it's soft now.
	rime = 0.0
	poise = THAWED_POISE
	state = "stand"
	lines = lines.filter(func(ln): return float(ln["at"]) >= 0.0)
	move_id = "touch"
	status["stun"] = THAWED
	sfx("ice_shatter", "clang", 0.9)
	pop_word("Shattered!")
	if world != null and world.get("glow") != null:
		world.glow.burst(center(), 24, Color(ICE_LIT, 0.95), 220.0, 0.55, 600.0, 2.6)


func apply_status(name: String, seconds: float, data := {}) -> void:
	if name in ["stun", "root", "flipped", "dazed"] and rime > 0.0:
		# Rimed, it doesn't stun, and Grave Chill doesn't root it; but a
		# Perfect Guard on its slam staggers it (the knight's, not a Peal's).
		if not (name == "stun" and perfect_guarded() and state in ["strike", "slam", "recover"]):
			return
	super(name, seconds, data)
	if name in ["stun", "root", "flipped", "dazed"]:
		if state in ["slam", "strike", "stomp"]:
			state = "stand"
			lines = lines.filter(func(ln): return float(ln["at"]) >= 0.0)
			move_id = "touch"


func _dying(dt: float) -> void:
	show_frame("buckle_hit")
	super(dt)


func eye_world() -> Vector2:
	return position + Vector2(facing * 6.0, -size.y * 0.72)


func lights() -> Array:
	var out := super()
	if alive:
		out.append({"p": eye_world(), "r": 26.0, "s": 0.45})
	return out


func eye_points() -> Array:
	if tier == "" or has_omen("hushed"):
		return []
	return [eye_world()]


func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	if alive:
		_step_rime(dt)   # (a stun doesn't stop the rime's clock)
	if _shell_sprite:
		_shell_sprite.visible = rimed() and alive and _shell_sprite.texture != null
		_shell_sprite.scale = sprite.scale if sprite else Vector2.ONE
		_shell_sprite.modulate = Color(1, 1, 1, 0.85 * _om_alpha)


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	# The spike lines: cracks glow along the floor for the whole tell (every
	# tile that will spike), then the spikes stab up tile by tile.
	var tb := gtb()
	for li in lines.size():
		var ln: Dictionary = lines[li]
		var cells: Array = ln["cells"]
		var waiting := float(ln["at"]) < -900.0
		var k := 1.0
		if waiting and state == "stomp":
			k = 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
		for i in cells.size():
			var r := spike_rect(ln, i)
			var fy := r.end.y
			var cx := r.get_center().x
			var second := li > 0
			if waiting or float(ln["at"]) < i * SPIKE_STEP:
				# The crack on the floor (the second line dashed).
				var a := (0.45 + 0.5 * k) if not second else (0.3 + 0.35 * k)
				for j in 3:
					var x0 := r.position.x + j * 7.0
					if second and j == 1:
						continue
					tb.line(Vector2(x0, fy - 1.0 - (j % 2) * 1.5), Vector2(x0 + 7.0, fy - 1.0 - ((j + 1) % 2) * 1.5), 1.6, Color(ICE_LIT, a))
				tb.circle(Vector2(cx, fy - 2.0), 2.0 + 2.0 * k, Color(EYE, 0.35 * a), 8)
			elif spike_up(ln, i):
				var up := clampf((float(ln["at"]) - i * SPIKE_STEP) / 0.06, 0.0, 1.0)
				var tip := Vector2(cx, fy - r.size.y * up)
				tb.convex(PackedVector2Array([Vector2(r.position.x, fy), Vector2(r.end.x, fy), tip]), Color(ICE, 0.85))
				tb.convex(PackedVector2Array([Vector2(cx - 3.0, fy), Vector2(cx + 3.0, fy), tip + Vector2(0, 4)]), Color(1, 1, 1, 0.8))
	if alive:
		glow_eyes(tb, art_points(POINTS3, "eyes", [eye_world()]), EYE, 3.0)
		if state == "slam":
			# The tell: the shield's rim flashes white, faster as it comes.
			var k2 := 1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0)
			var on := fmod(t * (6.0 + 10.0 * k2), 1.0) < 0.5
			var sx := position.x + facing * (size.x * 0.5 + 2.0)
			tb.line(Vector2(sx, position.y - size.y * 0.9), Vector2(sx, position.y - 3.0), 3.0,
					Color(1, 1, 1, (0.55 if on else 0.3) + 0.4 * k2))
			var sr := slam_rect()
			glow.draw_rect(sr, Color(1, 1, 1, 0.06 + 0.1 * k2))
		elif state == "strike":
			glow.draw_rect(slam_rect(), Color(ICE_LIT, 0.35))
		if hp_bar > 0.0 and rime_max > 0.0 and rime > 0.0:
			var w := 26.0
			var at := Vector2(rect().get_center().x - w * 0.5, rect().position.y - 13.0)
			glow.draw_rect(Rect2(at, Vector2(w, 2.0)), Color(0.1, 0.1, 0.15, 0.8))
			glow.draw_rect(Rect2(at, Vector2(w * rime / rime_max, 2.0)), Color("6ab8ff"))
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var tb := btb()
	var f := float(facing)
	var sm := scale_mult
	var h := size.y
	var raise := 0.0
	if state == "stomp":
		raise = 6.0 * (1.0 - clampf(timer / maxf(tell_len, 0.01), 0.0, 1.0))
	var gait := sin(_walk * TAU / 0.7) * 1.5 if state == "advance" else 0.0
	# Legs (one raised for the stomp).
	cel_line(tb, Vector2(-6.0 * sm, -10.0 * sm), Vector2(-7.0 * sm, 0.0 - (raise if f < 0 else 0.0)), 6.0 * sm, STEEL_DARK, 1.5)
	cel_line(tb, Vector2(6.0 * sm, -10.0 * sm), Vector2(7.0 * sm, 0.0 - (raise if f > 0 else 0.0)), 6.0 * sm, STEEL_DARK, 1.5)
	# The armoured body and head.
	var bc := Vector2(0, -h * 0.5 + gait)
	cel_poly(tb, PackedVector2Array([bc + Vector2(-12.0, -10.0) * sm, bc + Vector2(12.0, -10.0) * sm, bc + Vector2(10.0, 11.0) * sm,
			bc + Vector2(-10.0, 11.0) * sm]), STEEL, 2.0)
	tb.rect(Rect2(bc + Vector2(-12.0, -2.0) * sm, Vector2(24.0, 3.0) * sm), pc(STEEL_DARK))
	var hc := Vector2(f * 2.0, -h * 0.76 + gait)
	cel_poly(tb, PackedVector2Array([hc + Vector2(-2.0, -7.0) * sm, hc + Vector2(2.0, -7.0) * sm, hc + Vector2(-f * 6.0, -13.0) * sm]), ICE_LIT, 1.4)
	cel_circle(tb, hc, 8.0 * sm, STEEL, 2.0)
	tb.rect(Rect2(hc + Vector2(-6.0, -1.5) * sm, Vector2(12.0, 3.0) * sm), pc(Color("1c1830")))
	tb.circle(hc + Vector2(f * 3.0, 0.0) * sm, 1.8 * sm, pc(EYE), 8)
	# The icicle beard.
	for i in 3:
		var bx := hc.x + (i - 1) * 3.0 * sm
		tb.convex(PackedVector2Array([Vector2(bx - 1.6 * sm, hc.y + 5.0 * sm), Vector2(bx + 1.6 * sm, hc.y + 5.0 * sm),
				Vector2(bx, hc.y + (11.0 + (i % 2) * 3.0) * sm)]), pc(ICE_LIT))
	# The tower shield of ice, in front (low while it recovers from a slam).
	var low := 7.0 if state == "recover" and last_move == "slam" else 0.0
	var fwd := 6.0 if state == "strike" else 0.0
	var sx := f * (size.x * 0.5 - 1.0 + fwd)
	cel_poly(tb, PackedVector2Array([Vector2(sx - 4.0 * sm, -h * 0.92 + low), Vector2(sx + 4.0 * sm, -h * 0.92 + low),
			Vector2(sx + 4.0 * sm, -4.0 + low), Vector2(sx - 4.0 * sm, -4.0 + low)]), ICE, 1.8)
	tb.rect(Rect2(Vector2(sx - 1.5 * sm, -h * 0.85 + low), Vector2(1.5 * sm, h * 0.7)), pc(ICE_LIT))
	# The rime: a faceted block of wax-ice over it while it holds.
	if rimed():
		var shell := PackedVector2Array([Vector2(-15.0, -1.0) * sm, Vector2(-18.0, -h * 0.45), Vector2(-14.0, -h * 0.92),
				Vector2(-4.0, -h - 6.0 * sm), Vector2(9.0, -h - 3.0 * sm), Vector2(17.0, -h * 0.7), Vector2(18.0, -h * 0.25),
				Vector2(13.0, -1.0) * sm])
		tb.convex(shell, pc(Color(ICE_LIT, 0.30)))
		tb.polyline(shell, 1.4, pc(Color(ICE_LIT, 0.75)), true)
		# Facets: a few bright planes and seams.
		tb.convex(PackedVector2Array([shell[2], shell[3], Vector2(-2.0, -h * 0.7)]), pc(Color(1, 1, 1, 0.22)))
		tb.convex(PackedVector2Array([shell[5], shell[6], Vector2(8.0, -h * 0.45)]), pc(Color(1, 1, 1, 0.14)))
		tb.line(shell[3], Vector2(-2.0, -h * 0.7), 1.0, pc(Color(1, 1, 1, 0.5)))
		tb.line(Vector2(-2.0, -h * 0.7), Vector2(4.0, -h * 0.2), 1.0, pc(Color(1, 1, 1, 0.35)))
		tb.line(shell[5], Vector2(8.0, -h * 0.45), 1.0, pc(Color(1, 1, 1, 0.4)))
	tb.flush(self)
