extends "res://scripts/elites.gd"
## Lurecoil `7` (World 6, a brute and a set piece; spec §4.5): a long eel of
## the black lake, a chain of dark rings with a pale bone face and a stolen
## candle in its jaws: its lure, a light under the surface, so you always
## know where it is. The W6 rules (hush_kind): seen only in light, eyes
## always drawn, a silver rim, silent until close. It keeps to one span of
## deep water (its lane: the lake's surface row round its cell, islets
## included, at most `lane_max` tiles), and never leaves it.
##   swim   under the surface, the lure following Wick along the lane
##   tell   the lake goes still (the ripples flatten: the visual twin of its
##          sound dip), a ring of ripples forms at the launch point, the lure
##          brightens, and a dashed arc shows its whole path (`leap_tell`)
##   leap   the head flies that very arc (arc_point(u)), 5-7 tiles long and
##          3-4 high, from the launch ring to a landing ring past the islet;
##          its `segs` rings and tail trail along the same arc. Head `bite`,
##          body `body`.
##   rest   after every `rest_every`-th leap its head rests on an islet edge
##          for `rest` s: full damage (a stomp too). A hit on the lure knocks
##          the stolen candle loose once (a wisp that flies to Wick and heals
##          `heal` of his life); a Warden's lure carries 3.
## Under water it can't be reached. Poise 1.0: it never flinches. A stun
## (a Perfect Guard on the bite: "staggers the head") never holds it in the
## air: the leap flies on, bites no more, and the head lands staggered,
## resting exposed for the longer of the stun and `rest` (the knight's
## window). At most one on screen (the levels' rule). Never Anointed.
## Numbers: TUNE.
##
## Nightfall: it rests after every third leap. Witching: a double leap (the
## second arc `double_gap` s after the first lands, back the way it came),
## both arcs drawn from the start. The 6-S Warden is Old Lampgullet.

const HK := preload("res://scripts/hush_kind.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TUNE := {
	"life": 90.0, "bite": 40.0, "body": 30.0, "touch": 30.0, "poise": 1.0,
	"embers": 10, "item": 0.25, "relic": 0.05,
	"lane_max": 20,               # tiles of lake it may use
	"islet_max": 4,               # a solid run this short on the surface row is an islet (longer: the shore)
	"swim": 60.0,
	"reach": 3,                   # tiles: a launch point this close to Wick
	"rise": 3,                    # tiles: Wick no higher than this over the water
	"leap_tell": 0.80, "leap_floor": 0.40,
	"leap_lens": [6, 5, 7],       # tiles, in order of preference
	"leap_time": 0.75,            # the head's flight, launch to landing
	"segs": 8, "seg_px": 24.0,
	"rest_every": {"dusk": 2, "nightfall": 3, "witching": 3},
	"rest": 1.2,
	"sink": 0.3,
	"again": 1.6,
	"double": {"dusk": 1, "nightfall": 1, "witching": 2},
	"double_gap": 0.4,
	"lure_r": 30.0, "lure_tell_r": 50.0,
	"heal": 0.06, "lure_flames": 1, "warden_flames": 3,
	"head_w": 36.0, "head_h": 28.0, "seg_w": 22.0, "seg_h": 18.0,
	"under": 14.0,                # px under the water line while it swims
	"wisp_speed": 260.0,          # a knocked-loose flame flying to Wick
	"lure_glide": 600.0,          # px/s the lure slides to the launch ring during the tell
	"sink_speed": 120.0,          # px/s the head goes back under
	"heal_reach": 10.0,           # px: a wisp this close to him heals
	"wisp_life": 4.0,             # s a loose flame chases him before it fades
}
# Its blows at area 1 (TUNE's), for test_progression's share-cap scan (PR's ask).
const MOVES := {"bite": TUNE["bite"], "body": TUNE["body"]}
const FRAMES := ["coil_head_closed", "coil_head_open", "coil_head_rest", "coil_seg", "coil_tail", "coil_hit",
	# (A3: each head's twin with no candle, no flame and no lure point, for
	# once the last flame is knocked loose)
	"coil_head_closed_bare", "coil_head_open_bare", "coil_head_rest_bare", "coil_hit_bare"]
const BONE := Color("e4dccb")

var state := "swim"             # swim, tell, leap, gap, rest, sink
var timer := 0.0
var move_id := ""
var seen := HK.DARK_A
var surface_y := 0.0
var lane := Vector2i.ZERO       # tile columns (x0, x1) of its lake
var water: Array[int] = []      # deep-water surface columns in the lane
var arcs: Array = []            # the leap's arcs: [{x0, x1, h}] (world px), drawn from the tell
var arc_i := 0
var leaps := 0
var flames := 1                 # the stolen candle's flames still in its jaws
var lure_x := 0.0
var trail: Array = []           # the body along the arc: segment centres (world px)
var head_path: Array = []       # the head's positions this leap (tests)
var wisps: Array = []           # {p, t}: a knocked-loose candle flying to Wick
var _tell_t := 0.8
var _u := 0.0
var _bit := false
var _bodied := false
var _cd := 0.0
var _knocked := false
var _stagger := 0.0             # a stun taken mid-leap: served on landing
var _seg_sprites: Array = []
var _tb := TriBatch.new()


func _init() -> void:
	kind = "lurecoil"
	size = Vector2(float(TUNE["head_w"]), float(TUNE["head_h"]))
	base_hp = float(TUNE["life"])
	base_dmg = float(TUNE["touch"])
	poise = float(TUNE["poise"])
	embers = int(TUNE["embers"])
	item_chance = float(TUNE["item"])
	relic_chance = float(TUNE["relic"])
	anchor = Vector2(64, 64)
	flier = true
	set("echo_by_body", false)     # MA's Echoing: its leaps are logged (strike_logged)
	set("lit_alpha_own", true)     # MA's Hushed Omen: its alpha is the W6 rule it already keeps (a no-op until elites.gd declares it)


func k(n: String) -> float:
	return HK.pick(TUNE, HK.behave_of(self), n)


func show_frame(n: String) -> void:
	## Its head's frame; once the stolen candle's last flame is gone, the
	## candle-less twin (a Warden keeps its candle to its last flame).
	if flames <= 0 and frames.has(n + "_bare"):
		n = n + "_bare"
	super(n)


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("coil_head_closed")
	flames = int(TUNE["warden_flames"]) if tier == "warden" else int(TUNE["lure_flames"])
	_find_lake()
	if frames.has("coil_seg"):
		for i in int(TUNE["segs"]) + 1:
			var s := Sprite2D.new()
			s.texture = frames["coil_tail" if i == int(TUNE["segs"]) and frames.has("coil_tail") else "coil_seg"]
			s.centered = true
			s.scale = Vector2(TEX_SCALE, TEX_SCALE)
			s.top_level = true
			s.visible = false
			add_child(s)
			_seg_sprites.append(s)


func moves() -> Dictionary:
	return {"touch": float(TUNE["touch"]), "bite": float(TUNE["bite"]), "body": float(TUNE["body"])}


func dmg(what := "touch") -> float:
	if what == "bite":
		return float(TUNE["bite"]) * dmg_mult
	if what == "body":
		return float(TUNE["body"]) * dmg_mult
	return base_dmg * dmg_mult


func sfx(name: String, fallback := "", pitch := 1.0, gain := 1.0) -> void:
	if HK.quiet(self):
		return
	super(name, fallback, pitch, gain)


func tell_sfx(name: String, seconds: float, fallback := "") -> void:
	## (silent beyond 90 px, as every W6 sound: hush_kind.quiet)
	if HK.quiet(self):
		return
	super(name, seconds, fallback)


# ---------------------------------------------------------------- the lake

func _find_lake() -> void:
	## Its surface row, and the lane: water and islets either way from its
	## cell, up to lane_max tiles in all.
	lure_x = position.x
	if level == null:
		surface_y = position.y
		lane = Vector2i(floori(position.x / TILE), floori(position.x / TILE))
		return
	var cx := floori(position.x / TILE)
	var cy := floori(position.y / TILE)
	while cy > 0 and level.tile(cx, cy - 1) == LevelData.WATER:
		cy -= 1
	surface_y = cy * TILE + 8.0
	var half := int(TUNE["lane_max"]) / 2
	var x0 := _extend(cx, cy, -1, half)
	var x1 := _extend(cx, cy, 1, half)
	lane = Vector2i(x0, x1)
	water.clear()
	for x in range(x0, x1 + 1):
		if level.tile(x, cy) == LevelData.WATER and level.is_deep(x, cy):
			water.append(x)
	position = Vector2(position.x, surface_y + float(TUNE["under"]))


func _extend(cx: int, cy: int, dir: int, half: int) -> int:
	var x := cx
	var last_water := cx
	var i := 0
	while i < half:
		var nx := x + dir
		var tt: int = level.tile(nx, cy)
		if tt == LevelData.WATER:
			x = nx
			last_water = nx
			i += 1
			continue
		if LevelData.is_solid(tt):
			# An islet (a short solid run with water past it), or the shore.
			var run := 0
			var q := nx
			while LevelData.is_solid(level.tile(q, cy)) and run <= int(TUNE["islet_max"]):
				q += dir
				run += 1
			if run <= int(TUNE["islet_max"]) and level.tile(q, cy) == LevelData.WATER and i + run < half:
				x = q
				last_water = q
				i += run + 1
				continue
		break
	return last_water


func in_lane(x: float) -> bool:
	var c := floori(x / TILE)
	return c >= lane.x and c <= lane.y


# ---------------------------------------------------------------- the arc

static func arc_at(a: Dictionary, u: float, sy: float) -> Vector2:
	## The leap's parabola: from x0 to x1 on the water line, h at the middle.
	var x := lerpf(float(a["x0"]), float(a["x1"]), u)
	return Vector2(x, sy - 4.0 * float(a["h"]) * u * (1.0 - u))


func arc_point(i: int, u: float) -> Vector2:
	return arc_at(arcs[i], u, surface_y)


func arc_length(a: Dictionary) -> float:
	var l := 0.0
	var p := arc_at(a, 0.0, surface_y)
	for j in range(1, 33):
		var q := arc_at(a, j / 32.0, surface_y)
		l += p.distance_to(q)
		p = q
	return l


func plan(player: Node2D) -> Array:
	## The arcs for a leap at Wick now ([] when none fits): a launch ring in
	## deep water within `reach` tiles of him, over him, landing in deep water
	## of its lane 5-7 tiles on (6 first). Witching: back again as well.
	if water.is_empty() or player == null:
		return []
	var px := floori(player.position.x / TILE)
	var cands := water.duplicate()
	cands.sort_custom(func(a, b): return absi(a - px) < absi(b - px))
	for x0 in cands:
		if absi(x0 - px) > int(TUNE["reach"]):
			break
		var dirs := [1, -1] if px >= x0 else [-1, 1]
		if x0 == px:
			dirs = [1, -1] if player.facing < 0 else [-1, 1]
		for dir in dirs:
			for len in TUNE["leap_lens"]:
				var x1: int = x0 + dir * int(len)
				if not water.has(x1):
					continue
				var h := (float(len) * 0.5 + 0.5) * TILE
				var one := {"x0": (x0 + 0.5) * TILE, "x1": (x1 + 0.5) * TILE, "h": h}
				var out := [one]
				if int(k("double")) > 1:
					out.append({"x0": one["x1"], "x1": one["x0"], "h": h})
				return out
	return []


# ---------------------------------------------------------------- reach

func submerged() -> bool:
	return state in ["swim", "tell", "gap", "sink"]


func rect() -> Rect2:
	if submerged() or not alive:
		return NOWHERE
	return Rect2(position - size * 0.5, size)


func center() -> Vector2:
	return position


func hurt_rect() -> Rect2:
	# Its head, up out of the water (what a stomp lands on).
	if submerged() or not alive:
		return NOWHERE
	return rect().grow(-4.0)


func touch_damage() -> bool:
	# Leaping, the bite and the body are its own checks (once a leap);
	# resting, its head bites like any monster's.
	return state == "rest"


func hit(h: Dictionary) -> bool:
	if submerged():
		return false
	var ok := super(h)
	if ok and alive and state == "rest" and flames > 0 and not _knocked:
		_knock_loose()
	return ok


func _hurt(h: Dictionary) -> void:
	flash = 1.0
	show_frame("coil_hit")


func apply_status(name: String, seconds: float, data := {}) -> void:
	## Mid-leap a stun, a root or a flip can't hold it in the air (think()
	## would stop and the head would hang over the lake): the flight goes on
	## without its bite, and the stun is served on landing, resting exposed.
	if state == "leap" and name in ["stun", "root", "flipped"]:
		_stagger = maxf(_stagger, seconds)
		_bit = true
		return
	super(name, seconds, data)


func _knock_loose() -> void:
	## A hit on the resting head shakes a flame of the stolen candle free.
	_knocked = true
	flames -= 1
	wisps.append({"p": lure_point(), "t": 0.0})
	sfx("coil_hiss", "snuffer_whisper", 1.4)
	if world != null and world.glow:
		world.glow.burst(lure_point(), 10, Color("f7b64a"), 90.0, 0.4, -60.0, 2.2)


func lure_point() -> Vector2:
	if state == "swim" or state == "tell" or state == "gap" or state == "sink":
		return Vector2(lure_x, surface_y + 6.0)
	return position + Vector2(facing * float(TUNE["head_w"]) * 0.5, 8.0)


# ---------------------------------------------------------------- the step

func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	seen = move_toward(seen, HK.lit_alpha(self) if alive and not submerged() else HK.DARK_A, dt * 6.0)
	HK.own_alpha(self, seen)
	if sprite:
		sprite.visible = not submerged() or state == "rest"
	_step_wisps(dt, player)
	_place_segments()


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_cd = maxf(_cd - dt, 0.0)
	match state:
		"swim":
			show_frame("coil_head_closed")
			var want := lure_x
			if player != null and player.alive:
				want = clampf(player.position.x, (lane.x + 0.5) * TILE, (lane.y + 0.5) * TILE)
			lure_x = move_toward(lure_x, want, spd(float(TUNE["swim"])) * dt)
			position = Vector2(lure_x, surface_y + float(TUNE["under"]))
			if _cd <= 0.0 and _can_leap(player):
				var a := plan(player)
				if not a.is_empty():
					_start_tell(a)
		"tell":
			show_frame("coil_head_closed")
			lure_x = move_toward(lure_x, float(arcs[0]["x0"]), float(TUNE["lure_glide"]) * dt)
			position = Vector2(lure_x, surface_y + float(TUNE["under"]))
			if timer <= 0.0:
				_start_leap(0)
		"leap":
			show_frame("coil_head_open")
			var a: Dictionary = arcs[arc_i]
			var span := float(TUNE["leap_time"])
			_u += dt / span
			var hu := minf(_u, 1.0)
			position = arc_at(a, hu, surface_y)
			facing = 1 if float(a["x1"]) > float(a["x0"]) else -1
			if _u <= 1.0:
				head_path.append(position)
			_lay_body(a)
			_leap_hits(player)
			var body_u := float(TUNE["segs"] + 1) * float(TUNE["seg_px"]) / maxf(arc_length(a), 1.0)
			if _u >= 1.0 + body_u:
				_land(a)
		"gap":
			show_frame("coil_head_closed")
			trail.clear()
			if timer <= 0.0:
				_start_leap(arc_i + 1)
		"rest":
			show_frame("coil_head_rest")
			if timer <= 0.0:
				state = "sink"
				timer = float(TUNE["sink"])
		"sink":
			trail.clear()
			position.y = move_toward(position.y, surface_y + float(TUNE["under"]), float(TUNE["sink_speed"]) * dt)
			if timer <= 0.0:
				state = "swim"
				lure_x = position.x
				move_id = ""
				_cd = cd(float(TUNE["again"]))


func _can_leap(player: Node2D) -> bool:
	if player == null or not player.alive:
		return false
	if not in_lane(player.position.x - 2 * TILE) and not in_lane(player.position.x + 2 * TILE) and not in_lane(player.position.x):
		return false
	return player.position.y >= surface_y - float(TUNE["rise"]) * TILE - 8.0 and player.position.y <= surface_y + TILE


func _start_tell(a: Array) -> void:
	state = "tell"
	arcs = a
	arc_i = 0
	_tell_t = tell(float(TUNE["leap_tell"]), float(TUNE["leap_floor"]))
	timer = _tell_t
	move_id = "lurecoil:bite"
	tell_sfx("lake_still", timer, "curdle")
	if world != null and not world.headless and world.has_method("_has_sfx") and world._has_sfx():
		var s = world.get_node_or_null("/root/Sfx")
		if s != null and s.has_method("hush_pulse"):
			s.hush_pulse(0.4, 0.6)


func _start_leap(i: int) -> void:
	state = "leap"
	arc_i = i
	_u = 0.0
	_bit = false
	_bodied = false
	head_path.clear()
	trail.clear()
	position = arc_point(i, 0.0)
	strike_logged({"kind": "arc", "arc": arcs[i], "surface": surface_y}, dmg("bite"))
	sfx("coil_splash", "dripkin_splat")


func _lay_body(a: Dictionary) -> void:
	## The rings follow the head along the same arc.
	trail.clear()
	var al := maxf(arc_length(a), 1.0)
	var du := float(TUNE["seg_px"]) / al
	for i in range(1, int(TUNE["segs"]) + 2):
		var u := _u - i * du
		if u < 0.0 or u > 1.0:
			continue
		trail.append(arc_at(a, u, surface_y))


func _leap_hits(player: Node2D) -> void:
	if player == null or not player.alive:
		return
	var pr: Rect2 = (player.rect() as Rect2).grow(-2.0)
	if not _bit and _u <= 1.0 and Rect2(position - size * 0.5, size).intersects(pr):
		_bit = true
		world.hurt_player(dmg("bite"), position.x, "hit", self, {"move": "lurecoil:bite"})
	if not _bodied:
		var sz := Vector2(float(TUNE["seg_w"]), float(TUNE["seg_h"]))
		for p in trail:
			if Rect2((p as Vector2) - sz * 0.5, sz).intersects(pr):
				_bodied = true
				world.hurt_player(dmg("body"), (p as Vector2).x, "hit", self, {"move": "lurecoil:body"})
				break


func _land(a: Dictionary) -> void:
	trail.clear()
	lure_x = float(a["x1"])
	if arc_i + 1 < arcs.size() and _stagger <= 0.0:
		state = "gap"
		timer = float(TUNE["double_gap"])
		position = Vector2(lure_x, surface_y + float(TUNE["under"]))
		return
	leaps += 1
	move_id = ""
	if leaps % int(k("rest_every")) == 0 or _stagger > 0.0:
		# Its head comes up to rest on the islet's edge, the lure hanging
		# (staggered: for the stun, or the rest if that's longer).
		state = "rest"
		timer = maxf(float(TUNE["rest"]), _stagger)
		_stagger = 0.0
		_knocked = false
		var x := float(a["x1"])
		var dir := -signf(float(a["x1"]) - float(a["x0"]))
		var cx := floori(x / TILE)
		var edge := x
		for i in range(1, 3):
			if LevelData.is_solid(level.tile(cx + int(dir) * i, floori(surface_y / TILE))):
				edge = (cx + int(dir) * i + (0.0 if dir > 0 else 1.0)) * TILE - dir * float(TUNE["head_w"]) * 0.3
				break
		facing = int(dir)
		position = Vector2(edge, surface_y - float(TUNE["head_h"]) * 0.35)
		sfx("coil_hiss", "snuffer_whisper")
	else:
		state = "swim"
		position = Vector2(lure_x, surface_y + float(TUNE["under"]))
		_cd = cd(float(TUNE["again"]))


func _step_wisps(dt: float, player: Node2D) -> void:
	## A knocked-loose flame flies to Wick and heals him.
	for w in wisps:
		w["t"] = float(w["t"]) + dt
		if player == null or not player.alive:
			continue
		var to: Vector2 = player.center()
		var p: Vector2 = w["p"]
		w["p"] = p.move_toward(to, float(TUNE["wisp_speed"]) * dt)
		if (w["p"] as Vector2).distance_to(to) < float(TUNE["heal_reach"]) and not w.get("done", false):
			w["done"] = true
			if player.heal_pct(float(TUNE["heal"])) and world != null:
				world.number(player.center() + Vector2(0, -30), float(TUNE["heal"]) * player.max_hp, "heal")
	wisps = wisps.filter(func(w): return not w.get("done", false) and float(w["t"]) < float(TUNE["wisp_life"]))


func _place_segments() -> void:
	if _seg_sprites.is_empty():
		return
	for i in _seg_sprites.size():
		var s: Sprite2D = _seg_sprites[i]
		s.visible = i < trail.size() and alive
		if s.visible:
			s.global_position = trail[i]
			s.modulate = Color(1, 1, 1, seen * fade)


func _kill(h: Dictionary) -> void:
	super(h)
	trail.clear()
	velocity = Vector2(0, 30)
	if world != null and world.glow:
		world.glow.burst(position, 16, Color(0.6, 0.58, 0.75, 0.7), 120.0, 0.7, 200.0, 2.6)
	sfx("coil_splash", "dripkin_splat", 0.8)


func _dying(dt: float) -> void:
	position += velocity * dt
	fade = clampf(1.0 - death_time * 1.2, 0.0, 1.0)
	if death_time > 1.0:
		gone = true


func eye_points() -> Array:
	## What the World lights (8 a screen): an elite's only, as v2's kinds.
	return w6_eyes() if tier != "" else []


func w6_eyes() -> Array:
	## Two pale eyes in the bone face (always; under water too, dimmer).
	var eyes := HK.frame_eyes(frame_name)
	if not frames.is_empty() and not eyes.is_empty() and not submerged():
		var out := []
		for p in eyes:
			out.append(frame_point(p))
		return out
	var f := float(facing)
	var c := position + Vector2(f * 6.0, -5.0)
	return [c + Vector2(-3.0, 0), c + Vector2(3.5, 0)]


func lights() -> Array:
	var out := super()
	if not alive or flames <= 0:
		return out
	var r := float(TUNE["lure_tell_r"]) if state == "tell" else float(TUNE["lure_r"])
	out.append({"p": lure_point(), "r": r, "s": 0.8 if state == "tell" else 0.6})
	return out


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := _tb
	if state == "tell":
		var kk := 1.0 - clampf(timer / maxf(_tell_t, 0.01), 0.0, 1.0)
		# The lake goes still: a flat bright line over the lane's water.
		for x in water:
			tb.rect(Rect2(x * TILE, surface_y - 1.0, TILE, 2.0), Color(0.85, 0.85, 1.0, 0.35 + 0.3 * kk))
		# A ring of ripples where it will launch.
		var lp := Vector2(float(arcs[0]["x0"]), surface_y)
		for j in 3:
			var ph := fmod(t * 1.6 + j / 3.0, 1.0)
			tb.ring(lp, 6.0 + 18.0 * ph, 1.5, Color(1, 1, 1, (0.9 - ph * 0.8) * (0.5 + 0.5 * kk)), 18)
	if state in ["tell", "gap", "leap"]:
		# Every arc still to come, dashed, from the tell on.
		for i in range(arc_i if state != "tell" else 0, arcs.size()):
			if state == "leap" and i == arc_i and _u > 1.0:
				continue
			var pts := PackedVector2Array()
			for j in 25:
				pts.append(arc_point(i, j / 24.0))
			# A dark edge under the dashes, so the arc reads over his pale
			# sprite too (it always starts near him).
			HK.dashed(tb, pts, 5.0, Color(HK.OUTLINE, 0.6), 9.0, 6.0)
			HK.dashed(tb, pts, 2.4, Color(1, 1, 1, 0.9), 9.0, 6.0)
	# Eyes over the dark; under water only a faint pair.
	if submerged():
		# Under the surface: the same pale eyes (r >= 3 at >= 0.9), a dimmer halo.
		for e in w6_eyes():
			var q := Vector2(e.x, surface_y + 10.0)
			tb.circle(q, HK.EYE_R * 1.8, Color(HK.EYE, 0.12), 10)
			tb.circle(q, HK.EYE_R, Color(HK.EYE, HK.EYE_A), 10)
	else:
		HK.draw_eyes(self, glow, tb)
	# The stolen candle's flames.
	if flames > 0:
		var lp := lure_point()
		var up := 0.0 if submerged() else 1.0
		tb.circle(lp, 4.0 + 2.0 * up, Color(1.0, 0.72, 0.3, 0.35 + 0.35 * up), 10)
		tb.circle(lp, 2.0, Color("fff4cf"), 8)
	for w in wisps:
		tb.circle(w["p"], 5.0, Color(1.0, 0.8, 0.4, 0.4), 10)
		tb.circle(w["p"], 2.4, Color("fff4cf"), 8)
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var tb := _tb
	var a := clampf(fade, 0.0, 1.0) * seen
	var sw := float(TUNE["seg_w"]) * 0.5
	var sh := float(TUNE["seg_h"]) * 0.5
	# The body's rings (world points, drawn from here).
	for i in range(trail.size() - 1, -1, -1):
		var p: Vector2 = (trail[i] as Vector2) - position
		var shrink := 1.0 - 0.06 * i
		tb.ellipse(p, sw * shrink + HK.RIM_PX, sh * shrink + HK.RIM_PX, Color(HK.RIM, a), 14)
		tb.ellipse(p, sw * shrink, sh * shrink, _c(HK.BODY, a), 14)
		tb.ellipse(p + Vector2(0, -sh * 0.3), sw * shrink * 0.6, sh * shrink * 0.35, _c(HK.BODY.lightened(0.12), a), 10)
	if submerged() and state != "sink":
		tb.flush(self)
		return
	# The head: a pale bone face, jaws round the candle.
	var f := float(facing)
	var hw := float(TUNE["head_w"]) * 0.5
	var hh := float(TUNE["head_h"]) * 0.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
	tb.ellipse(Vector2.ZERO, hw + HK.RIM_PX, hh + HK.RIM_PX, Color(HK.RIM, a), 18)
	tb.ellipse(Vector2.ZERO, hw, hh, _c(HK.BODY, a), 18)
	tb.ellipse(Vector2(5, -2), hw * 0.62, hh * 0.72, _c(BONE, a), 16)
	tb.ellipse(Vector2(3, -5), 2.6, 2.2, _c(Color("1c1830"), a), 8)
	tb.ellipse(Vector2(9, -5), 2.6, 2.2, _c(Color("1c1830"), a), 8)
	var open := state == "leap"
	var jaw := 7.0 if open else 3.0
	tb.convex(PackedVector2Array([Vector2(8, 4), Vector2(hw + 2, 3), Vector2(hw, 3 + jaw), Vector2(8, 3 + jaw * 0.6)]), _c(BONE.darkened(0.15), a))
	for i in 3:
		tb.tri(Vector2(12 + i * 4, 3), Vector2(14 + i * 4, 3), Vector2(13 + i * 4, 6), _c(Color("f4f0e4"), a))
	tb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _c(col: Color, a := 1.0) -> Color:
	return HK.shade(self, col, a)
