extends "res://scripts/elites.gd"
## Thornback: a hunched ghoul under a spiked iron shell. Jumping on it hurts
## (the spikes point up), so it teaches the sword: two cuts and it's done.
## When Wick is near it turns to face him and braces (its tell, BRACE s,
## tell()-scaled: the shell tips forward, the back claws dig in and scrape,
## the spikes glint in the glow layer), then charges a few steps. The brace
## is a commitment: it holds its ground through a cut (it only flashes) and
## charges the way it faced. Flipped, stunned or rooted (a Perfect Guard, a
## Finisher, a stagger), a brace or a run under way is lost, but the walk
## half of the cycle (its cooldown) is kept and waits out the stun, as it
## always did. Sooted (the Smoke Step) it loses him the same way and won't
## turn to him while the soot lasts (spec, Smoke Step).
## Flipped (the Bellfounder's maul from above: status "flipped", 2.5 s) it
## lies on its back with its legs kicking: harmless to touch, stompable
## (world), and it takes +25% (combat.roll). Then it rolls back upright.

const SPEED := 34.0
const CHARGE := 120.0
const SEE := Vector2(130.0, 40.0)   # how near Wick must be (x, y) for it to go for him
const BRACE := 0.35                 # the tell before a charge (spec: every tell >= 0.35 s)
const CYCLE := 1.4                  # a charge's cycle: its first half at CHARGE, then a walk
# The art's eyes (frame units, facing right, feet (64,122)), for an
# elite's glints.
const EYES := {
	"thorn_walk1": [Vector2(77.4, 101.0), Vector2(89.4, 100.4)],
	"thorn_walk2": [Vector2(77.4, 101.8), Vector2(89.4, 101.2)],
	"thorn_hit": [Vector2(76.2, 99.0), Vector2(88.0, 97.0)],
	"thorn_brace": [Vector2(83.1, 103.7), Vector2(95.0, 105.4)],
}
# The brace frame's spike tips and its back claws (tools/art/enemies.py,
# BRACE_TILT), where the tell glints and the grit flies.
const BRACE_TIPS := [Vector2(45.7, 67.3), Vector2(60.1, 58.0), Vector2(77.0, 56.3), Vector2(92.0, 63.1), Vector2(101.5, 76.4)]
const BRACE_CLAW := Vector2(41.0, 120.6)

var brace := 0.0                    # seconds left of the brace (the tell); > 0 while it plays
var brace_len := 0.0                # the brace's whole length, tell(BRACE)
var _walk := 0.0
var _charge := 0.0
var _grit_t := 0.0
var _was_flipped := false
var charges_left := 0              # charges still to come in this run (a Warden, Deacon Thistle, charges twice)


func _init() -> void:
	kind = "thornback"
	size = Vector2(28, 30)
	base_hp = 42.0
	base_dmg = 34.0
	poise = 0.30
	stompable = false
	embers = 5
	item_chance = 0.14
	relic_chance = 0.04


func _ready() -> void:
	super()
	load_frames(["thorn_walk1", "thorn_walk2", "thorn_hit", "thorn_brace"])
	show_frame("thorn_walk1")


func flipped() -> bool:
	return status.has("flipped")


func touch_damage() -> bool:
	## On its back it's only a kicking shell.
	return not flipped()


func charging() -> bool:
	## Running at Wick (the first half of a charge's cycle).
	return _charge > cd(CYCLE) * 0.5


func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	if not alive:
		return
	if stunned() or status.has("sooted"):
		# Flipped, stunned or rooted, the brace or run under way is lost;
		# Sooted, it has lost Wick in the smoke. (The cooldown is kept.)
		_stop_charge()
	var f := flipped()
	if sprite:
		if f:
			# Upside down in its own box, rocking, legs in the air.
			sprite.scale.y = -absf(sprite.scale.y)
			# (Its drawn height: a Twinned half's box stands taller, SHOT_LINE.)
			sprite.position = Vector2(0, -30.0 * scale_mult)
			sprite.rotation = sin(t * 14.0) * 0.12
			show_frame("thorn_walk1" if fmod(t, 0.24) < 0.12 else "thorn_walk2")
		elif _was_flipped:
			sprite.position = Vector2.ZERO
			sprite.rotation = 0.0
	if _was_flipped and not f:
		# Back on its feet with a hop.
		velocity.y = -220.0
	_was_flipped = f


func think(dt: float, player: Node2D) -> void:
	var dx: float = player.position.x - position.x
	var dy: float = player.position.y - position.y
	_charge = maxf(_charge - dt, 0.0)
	if brace > 0.0:
		_brace(dt)
		return
	if tier == "warden" and charges_left > 0 and not charging() and _charge > 0.0:
		# A Warden's second charge: straight into the next brace.
		_charge = 0.0
	if flash > 0.3:
		# Reeling from a cut.
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * dt)
		velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
		move(dt)
		show_frame("thorn_hit")
		return
	if player.alive and absf(dx) < SEE.x and absf(dy) < SEE.y and _charge <= 0.0 and on_floor and not status.has("sooted"):
		# The tell: it turns to him and braces, then charges (_brace).
		if charges_left <= 0:
			charges_left = 2 if tier == "warden" else 1
		facing = 1 if dx > 0.0 else -1
		brace = tell(BRACE)
		brace_len = brace
		_grit_t = 0.0
		velocity.x = 0.0
		show_frame("thorn_brace")
		sfx("clank", "", 0.8)
		if world and world.has_method("dust_at"):
			world.dust_at(frame_point(BRACE_CLAW))
		return
	var speed := spd(CHARGE) if charging() else spd(SPEED)
	walk(dt, speed)
	_walk += dt * (speed / SPEED)
	show_frame("thorn_walk1" if fmod(_walk, 0.5) < 0.25 else "thorn_walk2")


func _brace(dt: float) -> void:
	## Dug in, shell down, claws scraping: it holds its ground (a cut only
	## flashes it) and then charges the way it faces.
	brace -= dt
	velocity.x = 0.0
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
	show_frame("thorn_brace")
	if sprite:
		# The scrape: a short shove back and forth on the spot.
		sprite.position.x = -facing * absf(sin(t * 38.0)) * 1.4
	_grit_t -= dt
	if _grit_t <= 0.0 and world and world.get("glow"):
		# Grit and sparks off the back claws (the glow layer: they read in the dark).
		_grit_t = 0.07
		var claw := frame_point(BRACE_CLAW)
		world.glow.burst(claw, 2, Color(1.0, 0.72, 0.35, 0.95), 90.0, 0.22, 420.0, 1.6, 50.0)
	if brace <= 0.0:
		brace = 0.0
		charges_left = maxi(charges_left - 1, 0)
		if sprite:
			sprite.position.x = 0.0
		_charge = cd(CYCLE)


func _stop_charge() -> void:
	## The brace and the run stop; the walk half of the cycle (the cooldown
	## after a charge) is kept, so a stun can't reset it.
	if brace > 0.0 and sprite and not flipped():
		sprite.position.x = 0.0
	brace = 0.0
	charges_left = 0
	_charge = minf(_charge, cd(CYCLE) * 0.5)


func _hurt(h: Dictionary) -> void:
	if brace > 0.0:
		# Braced, it doesn't give ground (the white flash still shows the cut).
		return
	super(h)
	show_frame("thorn_hit")


func _dying(dt: float) -> void:
	if sprite:
		sprite.rotation = 0.0
	show_frame("thorn_hit")
	super(dt)


func draw_glow(glow: Node2D) -> void:
	super(glow)
	if alive and brace > 0.0:
		_draw_brace(glow)
	if alive and flipped():
		# Dizzy: three little stars wheeling over its belly.
		var c := Vector2(position.x, position.y - size.y - 6.0)
		for i in 3:
			var a := t * 4.0 + TAU * i / 3.0
			var p := c + Vector2(cos(a) * 11.0, sin(a) * 3.5)
			glow.draw_line(p + Vector2(-2.5, 0), p + Vector2(2.5, 0), Color(1.0, 0.95, 0.6, 0.9), 1.3)
			glow.draw_line(p + Vector2(0, -2.5), p + Vector2(0, 2.5), Color(1.0, 0.95, 0.6, 0.9), 1.3)


func _draw_brace(glow: Node2D) -> void:
	## The tell, above the dark: the spikes catch a hot glint that grows as
	## the brace runs out, and the ground under the back claws scores bright.
	var k := 1.0 - clampf(brace / maxf(brace_len, 0.01), 0.0, 1.0)
	var flick := 0.75 + 0.25 * absf(sin(t * 30.0))
	var hot := Color(1.0, 0.86, 0.5, (0.55 + 0.45 * k) * flick)
	var r := (2.0 + 2.6 * k) * scale_mult
	for q in BRACE_TIPS:
		var p := frame_point(q)
		glow.draw_circle(p, r * 1.4, Color(1.0, 0.6, 0.25, 0.14 + 0.16 * k))
		glow.draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), hot, 1.4)
		glow.draw_line(p + Vector2(0, -r), p + Vector2(0, r), hot, 1.4)
	var claw := frame_point(BRACE_CLAW)
	var back := Vector2(-facing, 0.0)
	var streak := (8.0 + 10.0 * k) * scale_mult
	glow.draw_line(claw + back * 2.0, claw + back * (2.0 + streak), Color(1.0, 0.7, 0.35, 0.8 * flick), 1.6)
	glow.draw_line(claw + back * 5.0 + Vector2(0, -3), claw + back * (4.0 + streak * 0.6) + Vector2(0, -3), Color(1.0, 0.7, 0.35, 0.5 * flick), 1.2)


func eye_points() -> Array:
	## Only an elite's eyes glint (see skeleton.gd). On its back (drawn
	## upside down) the face isn't where the table says.
	if flipped() or tier == "":
		return []
	return art_eyes(EYES, [])
