extends "res://scripts/elites.gd"
## Gustling `z` (World 5 fodder, a flier; spec §4.5): a chubby cloud-cherub
## with bellows for wings and a small glass halo. It floats in place with a
## 12 px bob and faces Wick once he's within `see` px and in view. Inhale
## (the tell): cheeks and bellows swell, wind lines converge on its mouth,
## a whistle. Then the gust: a band `band_h` tall and `band_len` long from
## its mouth (cut short by the first wall: reach(); nothing behind a wall,
## a floor or a pane feels it) that pushes Wick at up to the World's 170 px/s cap (a
## displacement through world.push_player, never tagged "gust", so it isn't
## halved on the ground: grounded he still walks against it at 35 px/s, and
## the World's edge brake keeps his feet on the floor; in the air he
## drifts). It deals no damage. It bends his shots (against it they keep
## `shot_slow` of their speed) and pushes Glassmites. The fair-push rule:
## it never starts a gust while Wick is airborne over a pit, the void or
## deep water (hush_kind.over_pit); the inhale waits, then gives up. Two
## hits or a stomp pop it. It must sit at least `edge_tiles` from any edge it
## pushes toward (placement_problems() checks a level). Numbers: TUNE.
##
## Nightfall: the gust lasts 0.9 s. Witching: two gusts 0.5 s apart. The
## 5-S Warden Cherub Blusterby is one at x1.5.

const HK := preload("res://scripts/hush_kind.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TUNE := {
	"life": 16.0, "touch": 20.0, "embers": 3, "item": 0.08,
	"bob": 12.0, "bob_period": 2.2,
	"see": 260.0,                  # it faces Wick this close (and in view)
	"inhale": 0.70, "inhale_floor": 0.40,
	"gust": {"dusk": 0.7, "nightfall": 0.9, "witching": 0.9},
	"band_len": 320.0, "band_h": 64.0,
	"wall_rows": 0.25,             # a wall across the band at +-this x band_h (and at the mouth's height) stops it
	"push": 170.0,                 # px/s, the World's PUSH_CAP
	"push_hold": 1.5,              # each tick's push lasts this many ticks (no gap between ticks)
	"again": 2.2,
	"gusts": {"dusk": 1, "nightfall": 1, "witching": 2},
	"second_gap": 0.5,             # Witching: the second gust starts this long after the first ends
	"wait_max": 2.0,               # an inhale held back (Wick airborne over a pit) gives up after this
	"gave_up_cd": 0.5,             # x again after an inhale that gave up
	"hit_cd": 0.6,                 # x again after a hit knocks it out of its breath
	"shot_slow": 0.4,
	"edge_tiles": 5,               # placement: at least this far from an edge it pushes toward
	"warden_scale": 1.5,           # Cherub Blusterby
}
const FRAMES := ["gust_idle1", "gust_idle2", "gust_inhale", "gust_blow", "gust_hit"]
const CLOUD := Color("e8eef8")
const CHEEK := Color("f0b8b8")

var state := "float"            # float, inhale, hold (waiting on the fair-push rule), gust, gap (Witching), rest
var timer := 0.0
var home := Vector2.ZERO
var move_id := ""
var gusts_left := 0
var _inhale_t := 0.7
var _held := 0.0
var _tb := TriBatch.new()


func _init() -> void:
	kind = "gustling"
	size = Vector2(26, 24)
	base_hp = float(TUNE["life"])
	base_dmg = float(TUNE["touch"])
	embers = int(TUNE["embers"])
	item_chance = float(TUNE["item"])
	anchor = Vector2(64, 64)
	flier = true


func k(n: String) -> float:
	return HK.pick(TUNE, HK.behave_of(self), n)


func _ready() -> void:
	if tier == "warden":
		scale_mult *= float(TUNE["warden_scale"])
	super()
	load_frames(FRAMES)
	show_frame("gust_idle1")
	home = position


func moves() -> Dictionary:
	return {"touch": float(TUNE["touch"]), "gust": 0.0}


func rect() -> Rect2:
	return Rect2(position - size * 0.5, size)


func center() -> Vector2:
	return position


func mouth() -> Vector2:
	return position + Vector2(facing * size.x * 0.45, 2.0 * scale_mult)


func band() -> Rect2:
	## The gust's reach: from the mouth along its facing, band_h tall, out to
	## band_len or the first wall, whichever is nearer (reach()).
	var m := mouth()
	var l := reach()
	var h := float(TUNE["band_h"])
	var x0 := m.x if facing > 0 else m.x - l
	return Rect2(x0, m.y - h * 0.5, l, h)


func reach() -> float:
	## How far the gust gets: band_len, or less where a wall stands in the
	## band (a solid tile, glass too, at the mouth's height, or across both
	## halves of the band). Nothing behind a wall is pushed.
	var m := mouth()
	var full := float(TUNE["band_len"])
	if level == null:
		return full
	var q := float(TUNE["band_h"]) * float(TUNE["wall_rows"])
	var ys := [m.y, m.y - q, m.y + q]
	var c0 := floori(m.x / TILE)
	var dir := 1 if facing > 0 else -1
	for i in range(0, int(full / TILE) + 2):
		var c := c0 + dir * i
		var d := 0.0 if i == 0 else absf((float(c * TILE) if dir > 0 else float((c + 1) * TILE)) - m.x)
		if d >= full:
			return full
		var mid := LevelData.is_solid(level.tile(c, floori(float(ys[0]) / TILE)))
		var both := LevelData.is_solid(level.tile(c, floori(float(ys[1]) / TILE))) and LevelData.is_solid(level.tile(c, floori(float(ys[2]) / TILE)))
		if mid or both:
			return d
	return full


func _body_in(r: Rect2) -> bool:
	## A body in the gust: inside the band, with a clear line from the mouth
	## to its nearest point (no floor, ceiling or pane between them).
	var b := band()
	if not b.intersects(r):
		return false
	var m := mouth()
	var q := Vector2(clampf(m.x, r.position.x, r.end.x), clampf(m.y, maxf(r.position.y, b.position.y) + 0.5, minf(r.end.y, b.end.y) - 0.5))
	return sees(q, m)


func _point_in(p: Vector2) -> bool:
	return band().has_point(p) and sees(p, mouth())


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	# The bob (it hangs where it was put).
	var bob := sin(t * TAU / float(TUNE["bob_period"])) * float(TUNE["bob"]) * 0.5
	if state == "inhale":
		bob *= 0.3
	position = Vector2(home.x, home.y + bob)
	var near: bool = player != null and player.alive and player.center().distance_to(position) <= k("see") and in_view()
	if near and state in ["float", "rest"]:
		facing = 1 if player.center().x > position.x else -1
	match state:
		"float":
			_frame_idle()
			if near and _in_band(player):
				_start_inhale()
		"rest":
			_frame_idle()
			if timer <= 0.0:
				state = "float"
		"inhale":
			show_frame("gust_inhale")
			if timer <= 0.0:
				if HK.over_pit(world, player):
					state = "hold"      # the fair-push rule: it waits
					_held = 0.0
				else:
					_start_gust()
		"hold":
			show_frame("gust_inhale")
			_held += dt
			if not HK.over_pit(world, player):
				_start_gust()
			elif _held >= float(TUNE["wait_max"]):
				state = "rest"
				timer = cd(float(TUNE["again"])) * float(TUNE["gave_up_cd"])
				move_id = ""
		"gust":
			show_frame("gust_blow")
			_blow(dt, player)
			if timer <= 0.0:
				gusts_left -= 1
				if gusts_left > 0:
					state = "gap"
					timer = float(TUNE["second_gap"])
				else:
					_end_gust()
		"gap":
			show_frame("gust_inhale")
			if timer <= 0.0:
				if HK.over_pit(world, player):
					_end_gust()
				else:
					state = "gust"
					timer = k("gust")
					sfx("gust_blow", "whoosh", 1.1)


func _frame_idle() -> void:
	show_frame("gust_idle1" if fmod(t, 0.5) < 0.25 else "gust_idle2")


func _in_band(player: Node2D) -> bool:
	## His body in the band (a band at head height catches him too), never
	## through a wall.
	return _body_in(player.rect())


func _start_inhale() -> void:
	state = "inhale"
	_inhale_t = tell(float(TUNE["inhale"]), float(TUNE["inhale_floor"]))
	timer = _inhale_t
	move_id = "gustling:gust"
	tell_sfx("gust_inhale", timer, "mimic_snore")


func _start_gust() -> void:
	state = "gust"
	timer = k("gust")
	gusts_left = int(k("gusts"))
	sfx("gust_blow", "whoosh")


func _end_gust() -> void:
	state = "rest"
	timer = cd(float(TUNE["again"]))
	move_id = ""
	if world != null and world.has_method("push_player"):
		world.push_player(Vector2.ZERO, 0.0, _push_tag())


func _push_tag() -> String:
	## Not a "gust..." tag: the World halves those on the ground (the level's
	## gusts); a Gustling's blast is the full push, capped.
	return "blow:gustling:%d" % get_instance_id()


func _blow(dt: float, player: Node2D) -> void:
	## One tick of the gust: Wick in the band is pushed (the World caps and
	## brakes it), his shots in it are bent, Glassmites in it are pushed.
	var b := band()
	var dir := float(facing)
	var cap = world.get("PUSH_CAP")
	var v := Vector2(dir * minf(float(TUNE["push"]), float(cap) if cap != null else float(TUNE["push"])), 0.0)
	if player != null and player.alive and _body_in(player.rect()) and world.has_method("push_player"):
		world.push_player(v, dt * float(TUNE["push_hold"]), _push_tag())
	for s in world.shots:
		if str(s.get("owner", "")) != "player" or not b.has_point(s["pos"]) or not _point_in(s["pos"]):
			continue
		if (s["vel"] as Vector2).x * dir < 0.0 and not s.get("gusted", false):
			s["gusted"] = true
			s["vel"] = Vector2((s["vel"] as Vector2).x * float(TUNE["shot_slow"]), (s["vel"] as Vector2).y)
	for e in world.enemies:
		if e != self and e.alive and e.kind == "glassmite" and _body_in(e.rect()):
			e.push = v


func _hurt(h: Dictionary) -> void:
	# A puff of cloud; it rocks back and keeps its place.
	flash = 1.0
	show_frame("gust_hit")
	if state == "inhale" or state == "hold":
		# Knocked out of its breath.
		state = "rest"
		timer = cd(float(TUNE["again"])) * float(TUNE["hit_cd"])
		move_id = ""


func _kill(h: Dictionary) -> void:
	super(h)
	show_frame("gust_hit")
	if world != null and world.has_method("push_player"):
		world.push_player(Vector2.ZERO, 0.0, _push_tag())
	if world != null and world.glow:
		world.glow.burst(position, 16, CLOUD, 150.0, 0.5, -40.0, 3.0)
		world.glow.burst(position, 6, Color("bfe8ff"), 120.0, 0.4, 300.0, 2.0)
	sfx("glass_chime", "crit", 1.4)


func _dying(dt: float) -> void:
	# It pops: a puff that thins away, the halo dropping.
	velocity = Vector2.ZERO
	squash = 1.0 + death_time * 0.8
	fade = clampf(1.0 - death_time * 2.5, 0.0, 1.0)
	if death_time > 0.45:
		gone = true


func eye_points() -> Array:
	if tier == "":
		return []
	var eyes := HK.frame_eyes(frame_name)
	if not eyes.is_empty():
		var out := []
		for p in eyes:
			out.append(frame_point(p))
		return out
	var c := position + Vector2(facing * 4.0, -3.0) * scale_mult
	return [c + Vector2(-3.0, 0) * scale_mult, c + Vector2(3.0, 0) * scale_mult]


# ---------------------------------------------------------------- placement

static func placement_problems(lv: RefCounted) -> Array:
	## Each Gustling at least edge_tiles from any floor edge its band reaches
	## in either facing (it faces Wick, so both): ["x,y: ..."]. The level
	## streams' tests call it on their levels (an empty list is a pass).
	var out := []
	var LD = LevelData
	var need := int(TUNE["edge_tiles"])
	var reach := int(ceilf(float(TUNE["band_len"]) / 32.0))
	for e in lv.entities:
		if e["kind"] != "gustling":
			continue
		var c: Vector2i = e["cell"]
		# The floor under it (it hangs over one; within 7 rows).
		var fy := -1
		for y in range(c.y + 1, mini(c.y + 8, lv.height)):
			if LD.is_solid(lv.tile(c.x, y)) or LD.is_ledge(lv.tile(c.x, y)):
				fy = y
				break
		if fy < 0:
			out.append("%d,%d: no floor under it" % [c.x, c.y])
			continue
		for dir in [-1, 1]:
			for i in range(0, reach + 1):
				var x: int = c.x + dir * i
				var t: int = lv.tile(x, fy)
				var t_above: int = lv.tile(x, fy - 1)
				if LD.is_solid(t_above) and i > 0:
					break   # a wall: the push stops at it
				if not (LD.is_solid(t) or LD.is_ledge(t)):
					if i < need:
						out.append("%d,%d: an edge %d tiles %s" % [c.x, c.y, i, "left" if dir < 0 else "right"])
					break
	return out


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := _tb
	var dir := float(facing)
	var m := mouth()
	if state == "inhale" or state == "hold" or state == "gap":
		# Wind lines drawn in toward the mouth; closing faster as it fills.
		var kk := 1.0 - clampf(timer / maxf(_inhale_t, 0.01), 0.0, 1.0) if state == "inhale" else 1.0
		var room := maxf(reach(), 14.0)
		for i in 6:
			var ph := fmod(t * 1.8 + i / 6.0, 1.0)
			var y := (float(i) - 2.5) * 9.0 * scale_mult
			var far := minf(70.0 * (1.0 - ph) + 14.0, room)
			var a := m + Vector2(dir * far, y * (1.0 - ph * 0.6))
			var b := a + Vector2(-dir * (10.0 + 6.0 * kk), -y * 0.12)
			tb.line(a, b, 1.6 + kk, Color(1, 1, 1, (0.35 + 0.5 * kk) * (1.0 - ph * 0.5)))
		# The cheeks swell (a white ring tightening on the face).
		tb.ring(position, (size.x * 0.62) * (1.25 - 0.25 * kk), 1.5 + 1.5 * kk, Color(1, 1, 1, 0.3 + 0.5 * kk), 18)
	elif state == "gust":
		# The band itself: streaks racing out along it.
		var b := band()
		var len := b.size.x
		for i in 12:
			var ph := fmod(t * 2.6 + i * 0.37, 1.0)
			var y := b.position.y + 5.0 + fmod(i * 23.0, b.size.y - 10.0)
			var x := m.x + dir * ph * len
			var sl := 24.0 + 16.0 * sin(i * 1.7)
			tb.line(Vector2(x, y), Vector2(x + dir * sl, y), 2.0, Color(1, 1, 1, 0.55 * (1.0 - ph * 0.7)))
		# Its edges, faint, so its reach reads.
		tb.rect(Rect2(b.position, Vector2(b.size.x, 1.5)), Color(1, 1, 1, 0.18))
		tb.rect(Rect2(b.position + Vector2(0, b.size.y - 1.5), Vector2(b.size.x, 1.5)), Color(1, 1, 1, 0.18))
	# The glass halo, a small bright ring above its head.
	var hc := position + Vector2(0, -size.y * 0.62)
	tb.ring(hc, 6.0 * scale_mult, 1.6, Color(0.85, 0.95, 1.0, 0.75), 14)
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var s := scale_mult
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s * facing, s * squash))
	var tb := _tb
	var a := clampf(fade, 0.0, 1.0)
	var puff := 1.0
	if state == "inhale" or state == "hold" or state == "gap":
		var kk := 1.0 - clampf(timer / maxf(_inhale_t, 0.01), 0.0, 1.0) if state == "inhale" else 1.0
		puff = 1.0 + 0.2 * kk
	var flap := sin(t * 9.0) * 2.5
	# Bellows wings behind: two pleated fans.
	for side in [-1.0, 1.0]:
		var wc := Vector2(-6.0 * side - 2.0, -3.0)
		var tip := wc + Vector2(-9.0 * side - 3.0, -8.0 + flap * side)
		HK.o_poly(tb, PackedVector2Array([wc + Vector2(0, 5), wc + Vector2(0, -4), tip, tip + Vector2(-2.0 * side, 9.0)]),
				_c(Color("b08a5a"), a), 1.5)
		tb.line(wc + Vector2(0, 0.5), tip + Vector2(-1.0 * side, 4.5), 1.0, _c(Color("7a5a36"), a))
	# The cloud body: three puffs.
	HK.o_ellipse(tb, Vector2(-5, 4), 7.0, 5.5, _c(CLOUD, a), 1.8)
	HK.o_ellipse(tb, Vector2(5, 4), 7.0, 5.5, _c(CLOUD, a), 1.8)
	tb.ellipse(Vector2(0, 5), 10.0, 5.0, _c(CLOUD, a), 16)
	# The head: a round cherub face.
	var hc := Vector2(2, -3)
	HK.o_ellipse(tb, hc, 9.0 * puff, 8.0, _c(Color("f6e8dc"), a), 1.8)
	tb.ellipse(hc + Vector2(-5.0 * puff, 2.0), 3.0 * puff, 2.2 * puff, _c(CHEEK, a), 10)
	tb.ellipse(hc + Vector2(4.5 * puff, 2.0), 3.0 * puff, 2.2 * puff, _c(CHEEK, a), 10)
	# Eyes squeezed shut, and the mouth: an O when it blows.
	tb.line(hc + Vector2(-4.0, -1.5), hc + Vector2(-1.5, -1.0), 1.4, _c(Color("3a2e3e"), a))
	tb.line(hc + Vector2(1.5, -1.0), hc + Vector2(4.0, -1.5), 1.4, _c(Color("3a2e3e"), a))
	if state == "gust":
		tb.ring(hc + Vector2(6.0, 2.5), 2.2, 1.4, _c(Color("3a2e3e"), a), 10)
	else:
		tb.circle(hc + Vector2(6.0, 2.5), 1.4, _c(Color("7a4a4a"), a), 8)
	# A curl of hair.
	tb.ring(hc + Vector2(-1, -8.5), 2.2, 1.2, _c(Color("d8c8b0"), a), 10, PI, TAU * 0.95)
	tb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _c(col: Color, a := 1.0) -> Color:
	return HK.shade(self, col, a)
