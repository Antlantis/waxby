extends "res://scripts/elites.gd"
## Rattle: a little skeleton that paces its floor and turns at edges. A stomp
## knocks it into a pile of bones; the sword does too. (Harder difficulties
## change only its numbers; elites.gd adds the Omens.)

const SPEED := 48.0
# The art's eyes (frame units, facing right, feet (64,122)), for an
# elite's glints.
const EYES := {
	"skel_walk1": [Vector2(60.4, 80.6), Vector2(77.6, 80.2)],
	"skel_walk2": [Vector2(60.4, 81.4), Vector2(77.6, 81.0)],
	"skel_hit": [Vector2(55.0, 80.6), Vector2(71.9, 76.5)],
}

var _walk := 0.0


func _init() -> void:
	kind = "skeleton"
	size = Vector2(22, 28)
	base_hp = 18.0
	base_dmg = 30.0
	embers = 2
	item_chance = 0.08


func _ready() -> void:
	super()
	load_frames(["skel_walk1", "skel_walk2", "skel_hit", "skel_bones"])
	show_frame("skel_walk1")


func think(dt: float, _player: Node2D) -> void:
	walk(dt, spd(SPEED))
	_walk += dt * spd(1.0)
	show_frame("skel_walk1" if fmod(_walk, 0.4) < 0.2 else "skel_walk2")
	if sprite:
		sprite.position.y = -absf(sin(_walk * TAU / 0.4)) * 1.5


func _kill(h: Dictionary) -> void:
	super(h)
	if h.get("how", "") == "stomp":
		# Flattened where it stood.
		velocity = Vector2.ZERO
	show_frame("skel_bones")


func _dying(dt: float) -> void:
	if death_time < 0.05 and velocity != Vector2.ZERO:
		show_frame("skel_hit")
	if velocity == Vector2.ZERO:
		# A pile of bones that sinks away.
		show_frame("skel_bones")
		if sprite:
			sprite.position.y = 0
		fade = clampf(1.8 - death_time * 1.6, 0.0, 1.0)
		if death_time > 1.1:
			gone = true
	else:
		super(dt)


func eye_points() -> Array:
	## Only an elite's eyes glint (the world lights at most 8 eyes, and the
	## fodder of World 1 would take them from the new monsters).
	return art_eyes(EYES, []) if tier != "" else []
