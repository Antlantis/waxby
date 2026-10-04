extends "res://scripts/actor.gd"
## The hero: running, jumping and the basic attack, tuned for thumbs on
## glass, plus life, harm and the calling's kit. The feel is in the numbers
## below: quick to top speed, a jump whose height follows how long it's held,
## a hang at the apex, a little grace after running off an edge (coyote
## time) and a jump pressed a moment before landing still counts (the
## buffer). NO stat, item, skill or level ever changes these constants;
## kits add abilities through dash(), move_mult (ground only) and quirks.
## The World feeds a pad each step and listens to the signals; the rig
## child draws him. Works with world, kit and stats all unset (tests, the
## reachability bot, the title screen's rig).
##
## Movement quirks (one per calling, only ever adding mobility) are extra
## code gated on `quirk`; with quirk "" every line of physics is as before:
##   ledge_grab  a jump <= 12 px short of a solid top, pushing into it, hauls
##               him up in 0.18 s; coyote time 0.15 s (the Candleknight)
##   drift       a second jump press while falling caps the fall at 80 px/s
##               while held, 1.2 s per airtime (the Taperwitch, via kit.air_jump)
##   cling       pushing into a wall while falling slides at 70 px/s; jump
##               kicks off it. The wall she kicked off won't hold her again
##               until she's back down to where she left it (or lands, a stomp,
##               the other wall): a chimney climbs, one wall alone doesn't
##               (the Sootrunner)
##   stampede    0.8 s of running flat out lifts top speed to 250 (the Bellfounder)
##   grave_step  the kit's bone ledge and air_leap() (the Sexton)
##
## Terrain (v3, contract.md §3; never a stat): climbing a vine is an
## early-return branch like the Ledge Grab haul, so none of the above runs
## while he's on one; ice scales only the ground accelerations; belts, movers
## and pushes are displacements in actor.gd.
##   catch   airborne, his centre within CATCH_REACH of a vine column's centre
##           and inside a vine cell (world.vine_present: a snapped rotten run
##           reads false), vy >= CATCH_VY, not holding down, not holding a
##           Special the kit is still playing (kit.holding_special(): a raised
##           guard, a charging flare, a Knell that may yet Toll; it plays as in
##           the air), and not within RECATCH of leaving that column: x snaps
##           to the column, velocity, air jumps, Drift and cling reset, and the
##           jump buffer clears
##   climb   jump held (whatever the left thumb holds; a direction only sets
##           facing) or the pad's `up`: CLIMB_SPEED up; a fresh press with no
##           direction climbs too; nothing: hang; down: CLIMB_SLIDE
##   leap    a fresh jump press >= LEAP_AFTER after the catch with a direction
##           held: vx +-LEAP_VX, vy -LEAP_VY, gravity as if jump were held for
##           LEAP_HOLD (then as if it were let go, however long it's held),
##           and the steering the leap's own until he lands, catches, jumps
##           again or is hit: one arc for a tap and a held thumb, 3.6 tiles
##           back to its height, 3.95 to a tile lower (4 tiles vine to vine)
##   mount   at the top cell, jump (or up) held toward a floor within 2 tiles:
##           a LEDGE_HAUL haul onto it (never up through a roof over the vine)
##   hit     a hit slides him down a tile and keeps him on (no knockback);
##           where the vine ends he drops. dash(), air_leap() and
##           release_vine() let go (so a Special does)
##   ice     on the floor over any SLICK cell: GROUND_ACCEL x0.25, GROUND_DECEL
##           x0.065, TURN_ACCEL x0.16 (134 px to stop from a run; the owner's feel lab, round 2); knockback x0.5

signal jumped(double: bool)
signal landed(impact: float)
signal attacked
signal hurt_taken(amount: float, hp_left: float)
signal snuffed
signal stepped
signal vine(event: String)        # "catch" "leap" "mount" "drop" "land" "release" "hit"

const Combat := preload("res://scripts/combat.gd")
const RUN_SPEED := 205.0
const GROUND_ACCEL := 1900.0
const GROUND_DECEL := 2400.0
const TURN_ACCEL := 3200.0
const AIR_ACCEL := 1350.0
const AIR_DECEL := 700.0
const JUMP_SPEED := 585.0
const DOUBLE_JUMP_SPEED := 470.0
const GRAVITY_UP := 1500.0        # rising with jump held
const GRAVITY_CUT := 3300.0       # rising after jump let go: a short hop
const GRAVITY_DOWN := 2150.0
const APEX_SPEED := 70.0          # |vy| under this near the top floats...
const APEX_GRAVITY := 0.55        # ...at this share of gravity, while held
const MAX_FALL := 640.0
const COYOTE := 0.12
const BUFFER := 0.15
const STOMP_BOUNCE := 380.0
const STOMP_BOUNCE_HELD := 560.0
const ATTACK_ACTIVE := 0.13
const ATTACK_COOLDOWN := 0.28
const ATTACK_BUFFER := 0.1        # an attack pressed this soon before the cooldown ends still swings
const DROP_HOLD := 0.15           # pure down (no left or right) held this long on a ledge drops through it
const INVULN := 0.9
const KNOCKBACK := Vector2(210, -300)
const CORNER_NUDGE := 9.0         # px of ceiling corner a jump slides round
const MAX_FLAMES := 3             # the old flame count, now derived from life
# Quirks (never touched by stats; see the header).
const LEDGE_COYOTE := 0.15        # the Candleknight's coyote time
const LEDGE_REACH := 12.0         # how far short of a top a Ledge Grab still catches
const LEDGE_HAUL := 0.18          # seconds to haul up
const DRIFT_FALL := 80.0
const DRIFT_TIME := 1.2
const CLING_SLIDE := 70.0
const CLING_KICK := Vector2(230, -540)
const CLING_LOCK := 0.12          # steering is locked this long after a kick
const CLING_GRACE := 0.1          # a kick still works this long after leaving the wall
const STAMPEDE_SPEED := 250.0
const STAMPEDE_AIR := 225.0       # in the air the top speed eases back to this...
const STAMPEDE_EASE := 0.25       # ...over this long
const STAMPEDE_AFTER := 0.8       # seconds of flat-out running before it starts
# Terrain (v3). The feel lab (lab-1) signs these off on the phone.
const CLIMB_SPEED := 130.0
const CLIMB_SLIDE := 220.0
const CATCH_REACH := 14.0         # px from a vine column's centre
const CATCH_VY := -200.0          # no catch while rising faster than this
const RECATCH := 0.25             # s before the column he left holds him again
const LEAP_VX := 205.0
const LEAP_VY := 470.0
const LEAP_HOLD := 0.30           # s of held gravity and locked steering after a leap
const LEAP_AFTER := 0.15          # a press this soon after the catch climbs instead
const MOUNT_REACH := 2            # tiles from the vine to a floor he can mount at the top
const HIT_SLIDE := 32.0           # px a hit slides him down the vine
const HIT_SLIDE_SPEED := 320.0
const ICE_ACCEL := 0.25
const ICE_DECEL := 0.065
const ICE_TURN := 0.16
const ICE_KNOCK := 0.5

var pad := {}
var facing := 1
var stats := {}                   # hero.gd stats(); empty = level 1 defaults
var kit: Object = null            # the calling's kit (kits/kit.gd), may be null
var quirk := ""                   # the calling's movement quirk id ("" = none: the bot)
var hp := 100.0
var max_hp := 100.0
var res := 0.0                    # the calling's resource (Grace, Melt, Smoke...)
var res_max := 100.0
var status := {}                  # name -> seconds left (douse, latch, ...)
var move_mult := 1.0              # ground speed multiplier for a kit this step (never in the air)
var double_jump := false
var reach := 1.0                  # melee reach multiplier (kept for old callers)
var alive := true
var frozen := false               # cutscenes: the bell, the boss's intro
var invuln := 0.0
var hurt_time := 0.0              # seconds since the last hit (the rig flinches)
var attack_time := -1.0           # seconds into the current swing, -1 when none
var attack_id := 0                # new per swing: a monster is hit once per swing
var dash_vel := Vector2.ZERO      # a kit's dash: velocity forced for dash_time
var dash_time := 0.0
var dash_flags := {}              # {no_grav, invuln, front_guard, pass}
var _cooldown := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _attack_buffer := 0.0         # a press held for a moment (hitstop stretches a cooldown)
var _down_t := 0.0                # pure down held standing (DROP_HOLD); -1 while a down held from the air or a vine waits to be let go
var hold_drops := true            # pure down held DROP_HOLD on a ledge drops through it; false in a level taller than a strip
                                  #   (world.gd): down held there looks down (tall_cam.gd), down + jump drops
var _jump_held := false
var _air_jumps := 0
var _fall_peak := 0.0             # fastest fall since leaving the ground (for the landing thump)
var _step_phase := 0.0
var air_time := 0.0
var last_safe := Vector2.ZERO     # where to put him back after a pit
var _safe_timer := 0.0
var _fall_guard := 0.0            # a pit can't charge twice in a row
var jump_lock := false            # a kit holds jumps off for now (a Flare's charge)
var bounces := 0                  # stomp bounces so far (kits count them: Grace, air dashes)
var ledge_t := -1.0               # seconds into a Ledge Grab's haul, -1 when none
var _ledge_from := Vector2.ZERO
var _ledge_to := Vector2.ZERO
var drift_left := DRIFT_TIME      # Drift seconds left this airtime
var drifting := false             # Drift switched on by a second press (while jump is held)
var clinging := 0                 # Moth Cling: the wall's side (-1 / 1), 0 when not on one
var clings := 0                   # clings so far (the kit refreshes its air dash on one)
var _cling_side := 0
var _kick_side := 0               # the wall she last kicked off (-1 / 1), 0 when any wall holds her
var _kick_y := 0.0                # ...and where her feet were then
var _cling_grace := 0.0
var _steer_lock := 0.0
var stampeding := false           # Stampede at full tilt
var _stampede_t := 0.0
var climbing := false             # on a vine (see the header)
var climb_col := -1               # the vine column he's on
var climb_t := 0.0                # seconds since the catch
var climb_state := ""             # "climb" | "hang" | "slide" (the rig reads it)
var _lock_col := -1               # the column he just left...
var _lock_t := 0.0                # ...and how long before it holds him again
var _leap_t := 0.0                # held gravity left after a vine leap
var _leap_dir := 0
var _leap_air := false            # a vine leap's flight: the steering is its own until he lands or catches
var _hit_slide := 0.0             # px left of a hit's slide down the vine
var on_ice := false               # on the floor over a SLICK cell this step

var flames: int:
	## The old flame count (1-3), from life. Setting it sets life to that share.
	get:
		if not alive or hp <= 0.0:
			return 0
		return clampi(ceili(3.0 * hp / maxf(max_hp, 1.0) - 0.001), 1, MAX_FLAMES)
	set(v):
		hp = max_hp * clampf(float(v) / MAX_FLAMES, 0.0, 1.0)

var max_flames: int:
	get:
		return MAX_FLAMES
	set(_v):
		pass


func _init() -> void:
	size = Vector2(20, 38)
	is_hero = true


func set_stats(s: Dictionary) -> void:
	## New numbers from hero.gd, keeping the share of life (and resource).
	var frac := hp / maxf(max_hp, 1.0)
	stats = s
	max_hp = float(s.get("max_hp", 100.0))
	hp = clampf(max_hp * frac, 1.0 if alive else 0.0, max_hp)
	var rfrac := res / maxf(res_max, 0.001)
	res_max = float(s.get("res_max", 100.0))
	res = clampf(res_max * rfrac, 0.0, res_max)
	var ranks: Dictionary = s.get("ranks", {})
	reach = float((s.get("reach", Vector2(38, 34)) as Vector2).x) / 38.0 if s.has("reach") else 1.0


func life_frac() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0) if alive else 0.0


func reset_at(p: Vector2) -> void:
	position = p
	velocity = Vector2.ZERO
	last_safe = p
	alive = true
	invuln = 0.0
	attack_time = -1.0
	on_floor = false
	riding = null
	dash_time = 0.0
	dash_vel = Vector2.ZERO
	dash_flags = {}   # a Smoke Step's invulnerability doesn't ride out of the lava with him
	_fall_peak = 0.0
	_buffer = 0.0
	_attack_buffer = 0.0
	ledge_t = -1.0
	stampeding = false
	_stampede_t = 0.0
	clinging = 0
	_kick_side = 0
	drifting = false
	climbing = false
	climb_col = -1
	_lock_col = -1
	_leap_t = 0.0
	_leap_air = false
	_hit_slide = 0.0
	push = Vector2.ZERO
	if kit != null and kit.has_method("on_reset"):
		kit.on_reset()   # and a move in flight (a rush, an Anvil Drop) ends here too


func end_dash() -> void:
	## A kit's dash over early (the kit's own call): its flags go with it.
	dash_time = 0.0
	dash_flags = {}


func dash(vel: Vector2, seconds: float, flags := {}) -> void:
	## A kit moves him: the velocity is forced for that long (no gravity with
	## no_grav). Movement constants stay as they are. It lets go of a vine.
	release_vine()
	_leap_t = 0.0
	_leap_air = false
	dash_vel = vel
	dash_time = seconds
	dash_flags = flags
	velocity = vel


func apply_status(name: String, seconds: float) -> void:
	status[name] = maxf(float(status.get(name, 0.0)), seconds)


func has_status(name: String) -> bool:
	return float(status.get(name, 0.0)) > 0.0


func step(dt: float) -> void:
	if not alive or frozen:
		if frozen and alive:
			# Still fall to the floor during a cutscene.
			velocity.x = move_toward(velocity.x, 0.0, GROUND_DECEL * dt)
			velocity.y = minf(velocity.y + GRAVITY_DOWN * dt, MAX_FALL)
			move(dt)
		return
	var left: bool = pad.get("left", false)
	var right: bool = pad.get("right", false)
	var down: bool = pad.get("down", false)
	var jump_pressed: bool = pad.get("jump_pressed", false)
	_jump_held = pad.get("jump", false)
	var attack_pressed: bool = pad.get("attack_pressed", false)

	invuln = maxf(invuln - dt, 0.0)
	_fall_guard = maxf(_fall_guard - dt, 0.0)
	hurt_time += dt
	_cooldown = maxf(_cooldown - dt, 0.0)
	for k in status.keys():
		status[k] = float(status[k]) - dt
		if status[k] <= 0.0:
			status.erase(k)
	if attack_time >= 0.0:
		attack_time += dt
		if attack_time > ATTACK_ACTIVE + 0.12:
			attack_time = -1.0
	_lock_t = maxf(_lock_t - dt, 0.0)
	_leap_t = maxf(_leap_t - dt, 0.0)
	# Hold-to-drop counts only a down pressed while standing: one held on
	# from a vine's slide or out of the air (a drop through the ledge above)
	# waits to be let go, so it never carries him on through the next ledge.
	if not down:
		_down_t = 0.0
	elif not on_floor or climbing:
		_down_t = -1.0
	elif _down_t >= 0.0:
		_down_t = 0.0 if left or right else _down_t + dt

	# A Ledge Grab's haul owns the motion while it lasts.
	if ledge_t >= 0.0:
		if jump_pressed:
			_buffer = BUFFER
		_step_ledge(dt)
		move_mult = 1.0
		return

	# A kit's dash owns the motion while it lasts (a jump pressed during it
	# is buffered for after).
	if dash_time > 0.0:
		if jump_pressed:
			_buffer = BUFFER
		dash_time -= dt
		velocity.x = dash_vel.x
		if dash_flags.get("no_grav", false):
			velocity.y = dash_vel.y
		else:
			velocity.y = minf(velocity.y + GRAVITY_DOWN * dt, float(dash_flags.get("max_fall", MAX_FALL)))
		var was := on_floor
		move(dt)
		if on_floor and not was:
			landed.emit(_fall_peak)
			_fall_peak = 0.0
		if on_wall != 0 and dash_flags.get("stop_at_wall", true):
			dash_time = 0.0
		if dash_time <= 0.0:
			dash_flags = {}
		move_mult = 1.0
		return

	# On a vine: the climb owns the motion (v2's physics below never runs).
	if climbing:
		_step_climb(dt, left, right, down, jump_pressed, attack_pressed)
		move_mult = 1.0
		return

	# Run.
	var want := int(right) - int(left)
	if hurt_time < 0.22:
		want = 0   # a knock back isn't steerable for a beat
	var locked := quirk == "cling" and _steer_lock > 0.0
	if locked:
		want = 0   # just kicked off a wall: the kick carries him
	if _leap_air:
		want = _leap_dir   # a vine leap's arc is fixed, whatever the thumb does
	if want != 0:
		facing = want
	var top := RUN_SPEED
	if quirk == "stampede" and stampeding:
		top = STAMPEDE_SPEED if on_floor else lerpf(STAMPEDE_SPEED, STAMPEDE_AIR, clampf(air_time / STAMPEDE_EASE, 0.0, 1.0))
	var target := want * top * (move_mult if on_floor else 1.0)
	var accel: float
	on_ice = on_floor and riding == null and _slick_under()
	if on_floor:
		# Ice scales the ground accelerations only (top speed and every jump
		# constant are untouched).
		if want == 0:
			accel = GROUND_DECEL * (ICE_DECEL if on_ice else 1.0)
		elif signf(velocity.x) != 0.0 and signf(velocity.x) != float(want):
			accel = TURN_ACCEL * (ICE_TURN if on_ice else 1.0)
		else:
			accel = GROUND_ACCEL * (ICE_ACCEL if on_ice else 1.0)
	else:
		accel = AIR_ACCEL if want != 0 else AIR_DECEL
	if not locked:
		velocity.x = move_toward(velocity.x, target, accel * dt)

	# Jump: the buffer holds a press for a moment; coyote time lets a jump
	# leave from just past an edge.
	if jump_lock:
		jump_pressed = false
		_buffer = 0.0
	if jump_pressed:
		_buffer = BUFFER
	else:
		_buffer = maxf(_buffer - dt, 0.0)
	if on_floor:
		_coyote = COYOTE if quirk != "ledge_grab" else LEDGE_COYOTE
		_air_jumps = 1 if double_jump else 0
		if quirk != "":
			drift_left = DRIFT_TIME
			drifting = false
			_kick_side = 0
	else:
		_coyote = maxf(_coyote - dt, 0.0)
	if _buffer > 0.0:
		if down and on_floor and _on_ledge_only():
			# Down + jump on a ledge drops through it.
			_drop_through()
		elif _coyote > 0.0:
			_jump(JUMP_SPEED, false)
		elif quirk == "cling" and (clinging != 0 or _cling_grace > 0.0):
			_wall_kick()
		elif _air_jumps > 0 and jump_pressed:
			_air_jumps -= 1
			_jump(DOUBLE_JUMP_SPEED, true)
		elif jump_pressed and kit != null and kit.air_jump():
			_buffer = 0.0
	elif hold_drops and _down_t >= DROP_HOLD and on_floor and _on_ledge_only():
		# So does pure down held a moment (the lit thumb pad's slide down; on
		# solid floor it does nothing). Not in a level taller than a strip:
		# there down held looks down, from a ledge too (2-2's shelves over the
		# low road); down + jump drops.
		_drop_through()

	# Gravity, heavier once the jump is let go, lighter at the apex (a vine
	# leap's first LEAP_HOLD falls as if jump were held, and then as if it
	# weren't, whatever the thumb does: the leap's arc is the same for a tap
	# and a held press).
	var held := (_leap_t > 0.0) if _leap_air else (_jump_held or _leap_t > 0.0)
	var g: float
	if velocity.y < 0.0:
		g = GRAVITY_UP if held else GRAVITY_CUT
	else:
		g = GRAVITY_DOWN
	if held and absf(velocity.y) < APEX_SPEED:
		g *= APEX_GRAVITY
	velocity.y = minf(velocity.y + g * dt, MAX_FALL)
	if quirk == "drift" and drifting:
		# Drift: the fall is held back while jump stays down.
		if not _jump_held or drift_left <= 0.0:
			drifting = false
		elif velocity.y > DRIFT_FALL:
			velocity.y = DRIFT_FALL
			drift_left -= dt
	elif quirk == "cling" and clinging != 0 and want == clinging and velocity.y > CLING_SLIDE:
		velocity.y = CLING_SLIDE   # Moth Cling: sliding down the wall
	if not on_floor:
		_fall_peak = maxf(_fall_peak, velocity.y)

	_basic(attack_pressed, dt)

	var was_floor := on_floor
	move(dt)
	if on_floor:
		_leap_air = false
		if not was_floor:
			landed.emit(_fall_peak)
			_fall_peak = 0.0
		air_time = 0.0
		if absf(velocity.x) > 40.0:
			_step_phase += absf(velocity.x) * dt
			if _step_phase > 44.0:
				_step_phase = 0.0
				stepped.emit()
		_track_safe(dt)
	else:
		air_time += dt
		if _try_catch(down):
			move_mult = 1.0
			return
	if quirk != "":
		_quirk_after_move(dt, want, down)
	move_mult = 1.0


func _basic(attack_pressed: bool, dt: float) -> void:
	## The basic attack: the kit's own (a spark, a knife...) or the swing. A
	## press a hair early is kept until the cooldown ends, so a rhythm of taps
	## never loses one (hitstop freezes the cooldown for a moment).
	if attack_pressed:
		_attack_buffer = ATTACK_BUFFER
	else:
		_attack_buffer = maxf(_attack_buffer - dt, 0.0)
	if _attack_buffer > 0.0 and _cooldown <= 0.0:
		_attack_buffer = 0.0
		attack_id += 1
		_cooldown = basic_cooldown()
		if kit == null or not kit.basic():
			attack_time = 0.0
		attacked.emit()


# ---------------------------------------------------------------- vines

func _vine_at(x: int, y: int) -> bool:
	## A climbable cell there now (a snapped rotten run isn't: the World says).
	if not LevelData.is_climb(level.tile(x, y)):
		return false
	if world != null and world.has_method("vine_present"):
		return world.vine_present(x, y)
	return true


func _try_catch(down: bool) -> bool:
	if on_floor or down or velocity.y < CATCH_VY or ledge_t >= 0.0 or dash_time > 0.0 or not alive:
		return false
	var c := center()
	var col := floori(c.x / TILE)
	if absf(c.x - (col + 0.5) * TILE) > CATCH_REACH:
		return false
	if col == _lock_col and _lock_t > 0.0:
		return false
	if not _vine_at(col, floori(c.y / TILE)):
		return false
	if kit != null and kit.has_method("holding_special") and kit.holding_special():
		return false   # a held Special plays on as in the air (the press let go of the vine)
	grab_vine(col)
	return true


func grab_vine(col: int, t := 0.0) -> void:
	## On the vine in column col, at his height now (the catch; the bot and
	## tests call it to start on a vine, t seconds after the catch).
	climbing = true
	climb_col = col
	climb_t = 0.0
	climb_state = "hang"
	position.x = (col + 0.5) * TILE
	velocity = Vector2.ZERO
	# As a landing does: the air jump, Drift and cling come back.
	_air_jumps = 1 if double_jump else 0
	drift_left = DRIFT_TIME
	drifting = false
	clinging = 0
	_kick_side = 0
	_cling_grace = 0.0
	_steer_lock = 0.0
	stampeding = false
	_stampede_t = 0.0
	# A press buffered just before the catch never fires a leap.
	_buffer = 0.0
	_coyote = 0.0
	_leap_t = 0.0
	_leap_air = false
	_hit_slide = 0.0
	_fall_peak = 0.0
	air_time = 0.0
	climb_t = t
	vine.emit("catch")


func _step_climb(dt: float, left: bool, right: bool, down: bool, jump_pressed: bool, attack_pressed: bool) -> void:
	climb_t += dt
	var dir := int(right) - int(left)
	if dir != 0:
		facing = dir
	var up_held: bool = pad.get("up", false)
	var c := center()
	var row := floori(c.y / TILE)
	if not _vine_at(climb_col, row):
		# A rotten run snapped under him, or he slid off the vine's end.
		_let_go("drop")
		return
	if jump_pressed and climb_t >= LEAP_AFTER and dir != 0 and _hit_slide <= 0.0:
		_leap(dir, dt)
		return
	var top_row := row
	while _vine_at(climb_col, top_row - 1):
		top_row -= 1
	var min_cy := top_row * TILE + 6.0
	var vy := 0.0
	if _hit_slide > 0.0:
		var d := minf(_hit_slide, HIT_SLIDE_SPEED * dt)
		_hit_slide -= d
		vy = d / dt
		climb_state = "slide"
	elif down:
		vy = CLIMB_SLIDE
		climb_state = "slide"
	elif _jump_held or up_held or jump_pressed:
		if dir != 0 and (c.y <= min_cy + 1.0 or solid_at(Vector2(position.x, position.y - size.y - 2.0))) and _try_mount(dir):
			return
		vy = -CLIMB_SPEED
		climb_state = "climb"
	else:
		climb_state = "hang"
	if vy < 0.0 and c.y + vy * dt < min_cy:
		vy = minf((min_cy - c.y) / dt, 0.0)
		climb_state = "hang" if vy == 0.0 else climb_state
	position.x = (climb_col + 0.5) * TILE
	velocity = Vector2(0.0, vy)
	move(dt)
	velocity = Vector2.ZERO
	if on_floor:
		# Slid down onto a floor or a ledge across the vine.
		_let_go("land")
		landed.emit(0.0)
	_basic(attack_pressed, dt)


func _leap(dir: int, dt: float) -> void:
	## Off the vine on a fixed arc.
	_let_go("leap")
	velocity = Vector2(dir * LEAP_VX, -LEAP_VY)
	facing = dir
	_leap_t = LEAP_HOLD
	_leap_dir = dir
	_leap_air = true
	_buffer = 0.0
	_coyote = 0.0
	jumped.emit(false)
	velocity.y = minf(velocity.y + GRAVITY_UP * dt, MAX_FALL)
	move(dt)


func _end_leap() -> void:
	## A vine leap's flight is over (a jump, a kick, a bounce of his own).
	_leap_air = false
	_leap_t = 0.0


func _try_mount(dir: int) -> bool:
	## At the vine's top, a floor within MOUNT_REACH tiles that way: haul up
	## onto it (as a Ledge Grab hauls). Never up through a ceiling: a floor
	## whose top is above his head needs the vine column clear from his head
	## up to where his head would be on it (a vine under a 1-tile roof
	## doesn't haul him onto the roof).
	var feet := position.y
	for k in range(1, MOUNT_REACH + 1):
		var cx := climb_col + dir * k
		for ty in range(floori((feet - 2.0 * TILE) / TILE), floori((feet + 16.0) / TILE) + 1):
			var t: int = level.tile(cx, ty)
			if not LevelData.is_floor(t) or LevelData.is_floor(level.tile(cx, ty - 1)):
				continue
			if LevelData.is_ledge(t) and not _ledge_there(cx, ty):
				continue
			var top := float(ty * TILE)
			var edge := float(cx * TILE) if dir > 0 else float((cx + 1) * TILE)
			var dest := Vector2(edge + dir * (size.x * 0.5 + 2.0), top)
			if not _room_at(dest) or not _clear_above(dest.y - size.y):
				continue
			_let_go("mount")
			ledge_t = 0.0
			_ledge_from = position
			_ledge_to = dest
			velocity = Vector2.ZERO
			attack_time = -1.0
			return true
	return false


func _clear_above(head_to: float) -> bool:
	## Nothing solid in his column from his head now up to head_to (the head
	## height a haul would lift him to); true when that isn't above his head.
	var head := position.y - size.y
	if head_to >= head:
		return true
	var x0 := floori((position.x - size.x * 0.5 + 0.5) / TILE)
	var x1 := floori((position.x + size.x * 0.5 - 0.5) / TILE)
	for cy in range(floori(head_to / TILE), floori((head - 0.01) / TILE) + 1):
		for cx in range(x0, x1 + 1):
			if LevelData.is_solid(level.tile(cx, cy)):
				return false
	return true


func _room_at(feet: Vector2) -> bool:
	## Room to stand with the feet there, and nothing that hurts.
	var room := Rect2(feet.x - size.x * 0.5, feet.y - size.y, size.x, size.y - 0.5)
	for cy in range(floori(room.position.y / TILE), floori(room.end.y / TILE) + 1):
		for cx in range(floori(room.position.x / TILE), floori((room.end.x - 0.01) / TILE) + 1):
			var t: int = level.tile(cx, cy)
			if LevelData.is_solid(t) or t == LevelData.SPIKES_UP or t == LevelData.SPIKES_DOWN or t == LevelData.LAVA:
				return false
	return true


func _let_go(why: String) -> void:
	if not climbing:
		return
	climbing = false
	_lock_col = climb_col
	_lock_t = RECATCH
	climb_state = ""
	_hit_slide = 0.0
	vine.emit(why)


func release_vine() -> void:
	## Let go of a vine (a Special, a dash, a scripted move).
	_let_go("release")


func _slick_under() -> bool:
	var r := rect()
	var ty := floori((position.y + 1.0) / TILE)
	for tx in range(floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE) + 1):
		if LevelData.is_slick(level.tile(tx, ty)):
			return true
	return false


func basic_cooldown() -> float:
	## Seconds between basics: stats.cooldown (attack speed already in it),
	## faster still while Gutterlight gutters (below its share of life, +20%
	## attack speed on top of gear's, as its +40% damage is in world.deal).
	var cd := float(stats.get("cooldown", ATTACK_COOLDOWN))
	var flags: Dictionary = stats.get("flags", {})
	if flags.has("gutterlight_speed") and life_frac() < float(flags.get("gutterlight_below", 0.35)):
		cd /= 1.0 + float(flags["gutterlight_speed"])
	return cd


func _quirk_after_move(dt: float, want: int, down: bool) -> void:
	## The quirks that look at where the step left him.
	match quirk:
		"ledge_grab":
			if not on_floor and want != 0 and on_wall == want and not down and velocity.y > -60.0:
				_try_ledge(want)
		"cling":
			_steer_lock = maxf(_steer_lock - dt, 0.0)
			if not on_floor and want != 0 and on_wall == want and velocity.y >= 0.0 and not down \
					and (want != _kick_side or position.y >= _kick_y):
				if clinging == 0:
					clings += 1
				if want != _kick_side:
					_kick_side = 0   # the other wall: the first holds her again
				clinging = want
				_cling_side = want
				_cling_grace = CLING_GRACE
			else:
				clinging = 0
				_cling_grace = 0.0 if on_floor else maxf(_cling_grace - dt, 0.0)
		"stampede":
			# Flat out on the ground for a while, and she hits her stride; a stop,
			# a turn, a wall or a hit ends it (a jump keeps it).
			var flat_out := want != 0 and signf(velocity.x) == float(want) and absf(velocity.x) >= 0.95 * RUN_SPEED and on_wall == 0
			if on_floor:
				if flat_out:
					_stampede_t += dt
					if _stampede_t >= STAMPEDE_AFTER:
						stampeding = true
				else:
					_stampede_t = 0.0
					stampeding = false
			elif stampeding and (want == 0 or signf(velocity.x) != float(want) or on_wall != 0):
				stampeding = false
				_stampede_t = 0.0


func _try_ledge(want: int) -> void:
	## Ledge Grab: the feet are just under the top of the wall he pushes into,
	## with room to stand up there: haul up onto it.
	var r := rect()
	var tx := floori((r.end.x + 1.0) / TILE) if want > 0 else floori((r.position.x - 1.0) / TILE)
	var ty := floori((position.y - 0.5) / TILE)
	if not LevelData.is_solid(level.tile(tx, ty)):
		return
	var top := float(ty * TILE)
	var short := position.y - top
	if short <= 0.0 or short > LEDGE_REACH:
		return
	var edge := float(tx * TILE) if want > 0 else float((tx + 1) * TILE)
	var dest := Vector2(edge + want * (size.x * 0.5 + 2.0), top)
	# Room to stand there, and nothing that hurts.
	var room := Rect2(dest.x - size.x * 0.5, top - size.y, size.x, size.y - 0.5)
	for cy in range(floori(room.position.y / TILE), floori(room.end.y / TILE) + 1):
		for cx in range(floori(room.position.x / TILE), floori((room.end.x - 0.01) / TILE) + 1):
			var t: int = level.tile(cx, cy)
			if LevelData.is_solid(t) or t == LevelData.SPIKES_UP or t == LevelData.SPIKES_DOWN or t == LevelData.LAVA:
				return
	ledge_t = 0.0
	_ledge_from = position
	_ledge_to = dest
	velocity = Vector2.ZERO
	end_dash()
	attack_time = -1.0


func _step_ledge(dt: float) -> void:
	## The haul: up the wall face first, then over the lip.
	ledge_t += dt
	var k := clampf(ledge_t / LEDGE_HAUL, 0.0, 1.0)
	var up := 1.0 - pow(1.0 - clampf(k / 0.6, 0.0, 1.0), 2.0)
	var over := smoothstep(0.55, 1.0, k)
	position = Vector2(lerpf(_ledge_from.x, _ledge_to.x, over), lerpf(_ledge_from.y, _ledge_to.y, up))
	if k >= 1.0:
		ledge_t = -1.0
		position = _ledge_to
		velocity = Vector2.ZERO
		on_floor = true
		_coyote = LEDGE_COYOTE
		air_time = 0.0
		landed.emit(0.0)


func _wall_kick() -> void:
	## Moth Cling: jump kicks off the wall, away from it.
	var away := -(clinging if clinging != 0 else _cling_side)
	_kick_side = -away
	_kick_y = position.y
	velocity = Vector2(away * CLING_KICK.x, CLING_KICK.y)
	facing = away
	_steer_lock = CLING_LOCK
	_end_leap()
	clinging = 0
	_cling_grace = 0.0
	_buffer = 0.0
	_coyote = 0.0
	jumped.emit(false)


func start_drift() -> bool:
	## Drift (the Taperwitch's kit calls this from air_jump): a second press of
	## jump near the top or on the way down holds the fall back while held.
	if quirk != "drift" or on_floor or drift_left <= 0.0 or velocity.y < -150.0:
		return false
	drifting = true
	return true


func air_leap(speed: float) -> void:
	## A quirk's jump from midair (the Sexton's bone ledge), like one off the floor.
	release_vine()
	_jump(speed, true)


func _jump(speed: float, double: bool) -> void:
	velocity.y = -speed
	_buffer = 0.0
	_coyote = 0.0
	_end_leap()   # a jump of his own (an air jump off a vine leap) is his to steer and hold
	on_floor = false
	riding = null
	jumped.emit(double)


func bounce(held: bool) -> void:
	## Off a monster's head: higher if the jump is held, and it gives the
	## double jump back.
	velocity.y = -(STOMP_BOUNCE_HELD if held else STOMP_BOUNCE)
	_coyote = 0.0
	_end_leap()
	_air_jumps = 1 if double_jump else 0
	_fall_peak = 0.0
	bounces += 1
	if quirk != "":
		drift_left = DRIFT_TIME   # a stomp refreshes the Drift
		_kick_side = 0            # and any wall holds her again


func take_damage(amount: float, from_x: float, kind := "hit", source: Object = null, opts := {}) -> bool:
	## Harm. The order: a hazard's share of life (skips DR and, for pits,
	## invulnerability) -> the kit's filter (guards, wards) -> invulnerability
	## -> damage reduction -> life -> the kit's last word -> snuffed.
	## opts: pct (amount is a share of max life), ignore_invuln, no_knock.
	## True when it hurt.
	if not alive:
		return false
	var a := amount
	var pct: bool = opts.get("pct", false)
	if pct:
		a = amount * max_hp
	var h := {"amount": a, "from_x": from_x, "kind": kind, "source": source, "pct": pct}
	# What hurt him, for the kit's filter (contract §5.2: a Knight's Perfect
	# Guard reflects a beam along its segment): the hazard itself (a beam's
	# seg, width, reflect, source) when the World passed one, and every opt.
	h["hazard"] = opts.get("hazard")
	h["opts"] = opts
	if kit != null and not pct:
		a = kit.filter_damage(a, h)
		if a <= 0.0:
			return false
	if invuln > 0.0 and not opts.get("ignore_invuln", false):
		return false
	if dash_flags.get("invuln", false) and not opts.get("ignore_invuln", false):
		return false
	if not pct:
		a = Combat.mitigate(a, float(stats.get("dr", 0.0)))
		if opts.has("clamp"):
			# The blow clamp (world.hurt_player): no single blow takes more.
			a = minf(a, float(opts["clamp"]))
	hp = maxf(hp - a, 0.0)
	hurt_time = 0.0
	if quirk != "":
		ledge_t = -1.0
		stampeding = false
		_stampede_t = 0.0
	invuln = maxf(invuln, float(stats.get("invuln", INVULN)))
	attack_time = -1.0
	end_dash()
	if climbing:
		# On a vine a hit slides him down a tile and keeps him on.
		_hit_slide = HIT_SLIDE
		velocity = Vector2.ZERO
		vine.emit("hit")
	elif not opts.get("no_knock", false):
		_leap_air = false
		var away := 1.0 if position.x >= from_x else -1.0
		var kb := Vector2(away * KNOCKBACK.x * float(stats.get("knock_mult", 1.0)), KNOCKBACK.y)
		if on_floor and _slick_under():
			kb *= ICE_KNOCK
		# (World 5 on: never off a floor edge into a pit; world.knock_brake)
		var brake: float = float(world.knock_brake(self, away)) if world != null and world.has_method("knock_brake") else -1.0
		if brake == -2.0:
			kb.x = velocity.x
		elif brake >= 0.0:
			kb.x = away * minf(absf(kb.x), brake)
		velocity = kb
	hurt_taken.emit(a, hp)
	if hp <= 0.0:
		# The relights, one per snuff: Hollin's Ember (the World's), then the
		# kit's (on_snuffed), then the Phoenix Wick (the World's, after).
		if world != null and world.has_method("relight") and world.relight(self):
			return true
		if kit != null and kit.on_snuffed():
			return true
		die()
	return true


func take_hit(from_x: float, _amount: int = 1) -> bool:
	## The old one-flame hit: a third of life, no damage reduction.
	return take_damage(1.0 / MAX_FLAMES, from_x, "hit", null, {"pct": true})


func die() -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	velocity = Vector2.ZERO
	snuffed.emit()


func heal_pct(p: float) -> bool:
	## Heals a share of max life. False when already full.
	if not alive or hp >= max_hp:
		return false
	hp = minf(hp + p * max_hp, max_hp)
	return true


func heal(n: int = 1) -> bool:
	## Old callers: one "flame" is a third of life.
	return heal_pct(float(n) / MAX_FLAMES)


func fall_charge_ok() -> bool:
	## A pit charges once, then not again for half a second.
	if _fall_guard > 0.0:
		return false
	_fall_guard = 0.5
	return true


func attack_rect() -> Rect2:
	## The sword's reach while the swing is live, else an empty rect.
	if attack_time < 0.0 or attack_time > ATTACK_ACTIVE:
		return Rect2()
	var rv: Vector2 = stats.get("reach", Vector2(38, 34))
	var w := rv.x
	var h := rv.y
	var x := position.x + (facing * (size.x * 0.5 - 4.0))
	if facing < 0:
		x -= w
	var box := Rect2(x, position.y - size.y - 4.0, w, h)
	if kit != null and kit.has_method("attack_box"):
		box = kit.attack_box(box)
	return box


func jump_held() -> bool:
	return _jump_held


func falling_onto(r: Rect2) -> bool:
	## Coming down on top of r: moving down with the feet in its upper part.
	return velocity.y > -40.0 and position.y <= r.position.y + minf(r.size.y * 0.55, 14.0) + velocity.y * (1.0 / 60.0)


func _drop_through() -> void:
	## Down through the ledge under him (down + jump, or pure down held).
	drop_through = 0.22
	_buffer = 0.0
	on_floor = false
	position.y += 2.0


func on_ledge() -> bool:
	## Standing on a ledge he could drop through (the World's one-time card).
	return on_floor and _on_ledge_only()


func _on_ledge_only() -> bool:
	## Standing on ledges (or a moving ledge) and no solid floor.
	if riding != null:
		return true
	var r := rect()
	var ty := floori((position.y + 1.0) / TILE)
	var any_ledge := false
	for tx in range(floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE) + 1):
		var t: int = level.tile(tx, ty)
		if LevelData.is_solid(t):
			return false
		if LevelData.is_ledge(t):
			any_ledge = true
	return any_ledge


func _corner_nudge(hit: Array[Vector2i]) -> bool:
	## Clipping a ceiling corner by a few px slides Wick round it instead of
	## stopping the jump dead.
	if hit.size() != 1:
		return false
	var cell: Vector2i = hit[0]
	var r := rect()
	var left_edge := cell.x * TILE
	var right_edge := (cell.x + 1) * TILE
	var overlap_right := r.end.x - left_edge     # hit with our right side
	var overlap_left := right_edge - r.position.x
	if overlap_right <= CORNER_NUDGE and overlap_right < overlap_left:
		if not solid_at(Vector2(r.position.x - overlap_right, r.position.y + 1.0)):
			position.x -= overlap_right + 0.1
			return true
	elif overlap_left <= CORNER_NUDGE:
		if not solid_at(Vector2(r.end.x + overlap_left, r.position.y + 1.0)):
			position.x += overlap_left + 0.1
			return true
	return false


func _track_safe(dt: float) -> void:
	## Remember firm, hazard-free ground to come back to after a pit or lava:
	## only the SAFE floors (never glass, dawnglass, a float, still water, a
	## belt, a frosted ledge or a vine), never while riding or climbing, and
	## never where the World says something sweeps him (world.safe_vetoed).
	_safe_timer += dt
	if _safe_timer < 0.15 or riding != null or climbing:
		return
	_safe_timer = 0.0
	var r := rect()
	var ty := floori((position.y + 1.0) / TILE)
	for px in [r.position.x + 1.0, r.end.x - 1.0]:
		var tx := floori(px / TILE)
		var under: int = level.tile(tx, ty)
		if not LevelData.is_safe(under):
			return
		# Ice is safe ground, but not its outer tile at a pit's edge.
		if under == LevelData.ICE and not (LevelData.is_floor(level.tile(tx - 1, ty)) and LevelData.is_floor(level.tile(tx + 1, ty))):
			return
		for dx in [-1, 0, 1]:
			var t: int = level.tile(tx + dx, ty - 1)
			if t == LevelData.SPIKES_UP or t == LevelData.LAVA:
				return
	# Nor where something sweeps a standing Waxby (a W4 weight's low arc, a
	# Spurwheel's outline): a fall mustn't put him back in its way.
	if world != null and world.has_method("safe_vetoed") and world.safe_vetoed(position):
		return
	last_safe = position
