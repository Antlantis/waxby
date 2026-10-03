extends "res://scripts/elites.gd"
## Flit: a bat that bobs about its roost and, when Wick comes close, swoops at
## where he was and flutters back up. Its position is its middle, not feet.
## Its tell is the wind-up, a pull up (WIND_RISE px/s) before the swoop: it
## starts one only in plain view, with the whole rise on the glass and out
## from behind the HUD and the thumb buttons (world.gd in_plain_view), and
## world.gd look_up leans the camera to show its roost (reach_rect).

const SWOOP_RANGE := 150.0
const SWOOP_SPEED := 230.0
const WIND_UP := 0.35         # s of wind-up at Dusk (elites.gd tell)
const WIND_RISE := 30.0       # px/s it pulls up by while winding up
const SWAY := 26.0            # its hover drifts this far either side of its roost
const BOB := 8.0              # ...and this far up and down
# The art's eyes (frame units, facing right, middle (64,64)), for an
# elite's glints.
const EYES := {
	"bat_up": [Vector2(62.6, 63.6), Vector2(72.8, 63.2)],
	"bat_down": [Vector2(62.6, 63.6), Vector2(72.8, 63.2)],
	"bat_hit": [Vector2(62.6, 63.8), Vector2(72.5, 61.7)],
}

var home := Vector2.ZERO
var _state := "hover"
var _target := Vector2.ZERO
var _timer := 0.0
var _flap := 0.0


func _init() -> void:
	kind = "bat"
	size = Vector2(24, 18)
	base_hp = 9.0
	base_dmg = 20.0
	embers = 2
	item_chance = 0.08
	anchor = Vector2(64, 64)
	flier = true


func _ready() -> void:
	super()
	load_frames(["bat_up", "bat_down", "bat_hit"])
	show_frame("bat_up")
	home = position


func rect() -> Rect2:
	return Rect2(position - size * 0.5, size)


func center() -> Vector2:
	return position


func wind_rise() -> float:
	## How far a wind-up pulls it up.
	return WIND_RISE * tell(WIND_UP)


func reach_rect() -> Rect2:
	## Everything its hover about the roost and a wind-up from there can
	## cover, for the camera to keep on the glass.
	var half := size * 0.5
	var top: float = home.y - half.y - BOB - wind_rise()
	return Rect2(home.x - SWAY - half.x, top, (SWAY + half.x) * 2.0, home.y + half.y + BOB - top)


func tell_shows() -> bool:
	## A wind-up from here would be seen whole: its box, and the rise it
	## pulls up by, in plain view (world.gd in_plain_view).
	if world == null or not world.has_method("in_plain_view"):
		return true
	return world.in_plain_view(rect().grow_individual(0.0, wind_rise(), 0.0, 0.0))


func think(dt: float, player: Node2D) -> void:
	_timer -= dt
	_flap += dt * (14.0 if _state == "swoop" else 9.0)
	show_frame("bat_up" if sin(_flap) > 0.0 else "bat_down")
	var to_player: Vector2 = player.center() - position
	match _state:
		"hover":
			var goal := home + Vector2(sin(t * 1.3) * SWAY, sin(t * 2.6) * BOB)
			position = position.lerp(goal, 1.0 - exp(-dt * 3.0))
			if player.alive and to_player.length() < SWOOP_RANGE and _timer <= 0.0 and to_player.y > -20.0 and tell_shows():
				_state = "windup"
				_timer = tell(WIND_UP)
				_target = player.center() + Vector2(0, -4)
				facing = 1 if to_player.x > 0.0 else -1
		"windup":
			position.y -= WIND_RISE * dt
			if _timer <= 0.0:
				_state = "swoop"
				_timer = 1.1
		"swoop":
			var d := _target - position
			if d.length() < 8.0 or _timer <= 0.0:
				_state = "return"
			else:
				_fly(d.normalized() * spd(SWOOP_SPEED) * dt)
		"return":
			var d := home - position
			if d.length() < 6.0:
				_state = "hover"
				_timer = cd(1.2)
			else:
				_fly(d.normalized() * spd(SWOOP_SPEED) * 0.6 * dt)
	if _state != "windup" and absf(to_player.x) > 4.0 and _state != "swoop":
		facing = 1 if to_player.x > 0.0 else -1


func _fly(d: Vector2) -> void:
	var next := position + d
	if solid_at(next):
		_state = "return" if _state == "swoop" else _state
		return
	position = next


func _dying(dt: float) -> void:
	show_frame("bat_hit")
	super(dt)


func eye_points() -> Array:
	## Only an elite's eyes glint (the world lights at most 8 eyes, and the
	## fodder of World 1 would take them from the new monsters).
	return art_eyes(EYES, []) if tier != "" else []
