extends "res://scripts/elites.gd"
## Dripkin: a living drip of wax hanging from the ceiling (spawn "ceiling":
## its position is the ceiling line while it hangs). When Wick is within
## 48 px of straight below it and it can see him, it quivers for 0.35 s
## with a glint, then drops at 520 px/s: 28 damage and a douse if it lands
## on him. It splats for 0.8 s (stuck, and it takes +50% damage), then
## crawls at 70 px/s. Hit while hanging, it lets go at once. One that falls
## into deep water, lava or a pit hisses out (a kill, how "pit").

const WAKE_X := 48.0
const QUIVER := 0.35
const DROP_SPEED := 520.0
const SPLAT := 0.8
const CRAWL := 70.0
# W6b's art (frame units, facing right, feet (64,122)). drip_hang keeps that
# anchor; while it hangs the sprite drops by HANG_Y so the frame's ceiling
# line (y 10) sits on ceiling_y (points_monsters.json _drip_hang).
const HANG_Y := 56.0
const EYES := {
	"drip_hang": [Vector2(59.4, 40.0), Vector2(68.6, 40.0)],
	"drip_drop": [Vector2(59.4, 107.4), Vector2(68.6, 107.4)],
	"drip_splat": [Vector2(58.0, 115.4), Vector2(70.0, 115.4)],
	"drip_crawl1": [Vector2(75.0, 112.4), Vector2(83.0, 112.4)],
	"drip_crawl2": [Vector2(68.2, 108.8), Vector2(76.0, 108.8)],
}

var state := "hang"             # hang, quiver, drop, splat, crawl
var timer := 0.0
var ceiling_y := 0.0
var _walk := 0.0
var _hit_player := false
var _slide := 0.0               # it splashes off his head, to the side


func _init() -> void:
	kind = "dripkin"
	size = Vector2(18, 20)
	base_hp = 20.0
	base_dmg = 20.0
	embers = 2
	item_chance = 0.08
	relic_chance = 0.02


func _ready() -> void:
	super()
	load_frames(["drip_hang", "drip_drop", "drip_splat", "drip_crawl1", "drip_crawl2"])
	ceiling_y = position.y
	show_frame("drip_hang")
	if sprite and hanging():
		sprite.position.y = HANG_Y


func as_copy() -> void:
	state = "crawl"
	if sprite:
		sprite.position.y = 0.0


func hanging() -> bool:
	return state == "hang" or state == "quiver"


func drawn_rect() -> Rect2:
	## The drawn body: on the floor the flat puddle or the crawling blob,
	## else its box (the bulb under the ceiling, the falling drop).
	var s := scale_mult
	match state:
		"splat":
			return Rect2(position.x - 13.0 * s, position.y - 10.0 * s, 26.0 * s, 10.0 * s)
		"crawl":
			return Rect2(position.x - 11.0 * s, position.y - 14.0 * s, 22.0 * s, 14.0 * s)
	return rect()


func rect() -> Rect2:
	## Where it can be hit: the bulb under the ceiling while it hangs, else
	## the drawn body, but never lower than SHOT_LINE (a flat puddle drawn
	## 10 px high would let a Taperwitch's sparks fly over it up close).
	if hanging():
		return Rect2(position.x - size.x * 0.5, ceiling_y, size.x, size.y)
	if state != "splat" and state != "crawl":
		return super()
	var d := drawn_rect()
	var h := maxf(d.size.y, SHOT_LINE)
	return Rect2(d.position.x, position.y - h, d.size.x, h)


func hurt_rect() -> Rect2:
	## Touching it hurts only on the drawing: on the floor, the puddle or
	## blob 4 px in from each side, its full height and at least half
	## SHOT_LINE (a slow landing on a small one meets it above the stomp line,
	## so it reads as a stomp).
	if hanging() or (state != "splat" and state != "crawl"):
		return super()
	var d := drawn_rect()
	var gx := minf(4.0, d.size.x * 0.25)
	var top := minf(d.position.y, position.y - SHOT_LINE * 0.5)
	return Rect2(d.position.x + gx, top, d.size.x - 2.0 * gx, position.y - top)


func center() -> Vector2:
	return rect().get_center()


func dmg(what := "touch") -> float:
	if what == "drop" or (what == "touch" and state == "drop"):
		return 28.0 * dmg_mult
	return base_dmg * dmg_mult


func hit(h: Dictionary) -> bool:
	if state == "splat" and h.has("amount"):
		# Splatted flat: soft and open.
		h["amount"] = float(h["amount"]) * 1.5
	return super(h)


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	if not hanging() and _lost():
		# It fell into deep water, lava or a pit: it hisses out, and counts.
		if world and world.glow:
			world.glow.burst(center(), 10, Color(0.85, 0.88, 0.92, 0.8), 80.0, 0.7, -120.0, 3.0, 40.0)
		sfx("dripkin_splat", "stomp", 0.8)
		_kill({"how": "pit", "from_x": position.x})
		return
	match state:
		"hang":
			show_frame("drip_hang")
			var dx: float = player.position.x - position.x
			if player.alive and absf(dx) < WAKE_X and player.position.y > ceiling_y + size.y and sees(player.center()):
				state = "quiver"
				timer = tell(QUIVER)
				sfx("drip", "", 0.6)
		"quiver":
			show_frame("drip_hang")
			if sprite:
				sprite.position.x = sin(t * 80.0) * 1.3
			if timer <= 0.0:
				_let_go()
		"drop":
			show_frame("drip_drop")
			velocity = Vector2(_slide, DROP_SPEED)
			move(dt)
			if not _hit_player and player.alive and rect().intersects(player.rect()) and world:
				_hit_player = true
				if world.hurt_player(dmg("drop"), position.x, "hit", self):
					world.douse_player()
				# Knocked one way, it slides off the other.
				var away := 1.0 if player.position.x >= position.x else -1.0
				_slide = -away * 150.0
			if on_floor:
				state = "splat"
				timer = SPLAT
				velocity = Vector2.ZERO
				_slide = 0.0
				sfx("dripkin_splat", "stomp", 1.3)
				if world:
					world.dust_at(position)
					if world.glow:
						world.glow.burst(position + Vector2(0, -3), 8, Color("f4ead6"), 110.0, 0.35, 500.0, 2.0)
		"splat":
			show_frame("drip_splat")
			velocity.x = 0.0
			velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
			move(dt)
			if timer <= 0.0:
				state = "crawl"
				facing = 1 if player.position.x > position.x else -1
		"crawl":
			walk(dt, spd(CRAWL))
			_walk += dt
			show_frame("drip_crawl1" if fmod(_walk, 0.5) < 0.25 else "drip_crawl2")


func _lost() -> bool:
	## Below the level, or its middle in deep water or lava (it never lands).
	if level == null:
		return false
	if position.y > level.height * TILE + 32.0:
		return true
	var c := center()
	var cx := floori(c.x / TILE)
	var cy := floori(c.y / TILE)
	var tl: int = level.tile(cx, cy)
	return (tl == LevelData.WATER or tl == LevelData.LAVA) and level.hurts_at(cx, cy, rect())


func _let_go() -> void:
	state = "drop"
	_hit_player = false
	_slide = 0.0
	position.y = ceiling_y + size.y
	velocity = Vector2(0, DROP_SPEED)
	if sprite:
		sprite.position = Vector2.ZERO


func _hurt(h: Dictionary) -> void:
	if hanging():
		# Knocked loose.
		_let_go()
		return
	super(h)


func _kill(h: Dictionary) -> void:
	if hanging():
		position.y = ceiling_y + size.y
		state = "drop"
		if sprite:
			sprite.position = Vector2.ZERO
	super(h)
	if h.get("how", "") == "pit":
		# No pop: it just sinks out of sight.
		velocity = Vector2(0.0, 60.0)


func _dying(dt: float) -> void:
	# It melts into a puddle.
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * dt)
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
	show_frame("drip_splat")
	fade = clampf(1.3 - death_time * 1.2, 0.0, 1.0)
	squash = clampf(1.0 - death_time * 0.6, 0.3, 1.0)
	if death_time > 1.2:
		gone = true


func eye_points() -> Array:
	var c := center()
	return art_eyes(EYES, [c + Vector2(-3, 1), c + Vector2(3, 1)])


func lights() -> Array:
	var out := super()
	if state == "quiver":
		out.append({"p": center(), "r": 30.0, "s": 0.75})
	return out


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if state == "quiver" and alive:
		var k := 1.0 - clampf(timer / maxf(tell(QUIVER), 0.01), 0.0, 1.0)
		var p := center() + Vector2(4, -4)
		var g := 3.0 + 5.0 * k
		glow.draw_circle(p, g * 0.7, Color(1, 1, 1, 0.25))
		glow.draw_line(p + Vector2(-g, 0), p + Vector2(g, 0), Color(1, 1, 1, 0.9), 1.3)
		glow.draw_line(p + Vector2(0, -g), p + Vector2(0, g), Color(1, 1, 1, 0.9), 1.3)


func _draw() -> void:
	if not frames.is_empty():
		return
	var wax := Color("f2e8d0")
	var shade := Color("d4c29c")
	var eye := Color("2a2030")
	var f := facing
	var a := 1.0 if alive else clampf(1.3 - death_time * 1.2, 0.0, 1.0)
	if a <= 0.0:
		return
	var st := state if alive else "splat"
	match st:
		"hang", "quiver":
			var q := sin(t * 80.0) * 1.2 if st == "quiver" else 0.0
			var o := Vector2(q, 0)
			# A drop hanging from a string of wax: point up, round below.
			var pts := PackedVector2Array([o + Vector2(-2, 0), o + Vector2(2, 0)])
			for i in 11:
				var ang := -0.2 + (PI + 0.4) * i / 10.0
				pts.append(o + Vector2(cos(ang) * 8.0, 13.0 + sin(ang) * 7.0))
			pts.reverse()
			o_poly(pts, wax, 2.0)
			draw_colored_polygon(PackedVector2Array([o + Vector2(3, 8), o + Vector2(7, 14), o + Vector2(3, 18)]), pc(shade))
			draw_circle(o + Vector2(-3, 7), 1.5, pc(Color(1, 1, 1, 0.8)))
			draw_circle(o + Vector2(-3, 14), 1.4, pc(eye))
			draw_circle(o + Vector2(3, 14), 1.4, pc(eye))
		"drop":
			var pts2 := PackedVector2Array()
			for i in 12:
				var ang := TAU * i / 12.0
				pts2.append(Vector2(cos(ang) * 7.0, -10.0 + sin(ang) * 9.0 - (5.0 if sin(ang) < 0.0 else 0.0)))
			o_poly(pts2, wax, 2.0)
			draw_circle(Vector2(-3, -9), 1.4, pc(eye))
			draw_circle(Vector2(3, -9), 1.4, pc(eye))
		"splat":
			var k := 1.0 - clampf(timer / SPLAT, 0.0, 1.0) if alive else 0.0
			o_poly(ellipse(Vector2(0, -3), 12.0 - k * 3.0, 3.5 + k * 3.0, 14), Color(wax, a), 1.5)
			draw_circle(Vector2(-3, -5 - k * 2), 1.4, pc(Color(eye, a)))
			draw_circle(Vector2(3, -5 - k * 2), 1.4, pc(Color(eye, a)))
		"crawl":
			var s := sin(_walk * TAU * 2.0)
			var body := PackedVector2Array()
			for i in 12:
				var ang := PI + PI * i / 11.0
				body.append(Vector2(cos(ang) * (9.0 + s * 0.8), sin(ang) * (12.0 - s * 1.0)))
			o_poly(body, wax, 2.0)
			draw_rect(Rect2(-8, -3, 16, 3), pc(shade))
			draw_circle(Vector2(f * 2.0 - 3.0, -7), 1.4, pc(eye))
			draw_circle(Vector2(f * 2.0 + 3.0, -7), 1.4, pc(eye))
			# The little wick on top.
			draw_line(Vector2(0, -12), Vector2(f * 1.5, -16), pc(Color("3a2a20")), 1.5)
