extends "res://scripts/enemy.gd"
## Old Tollgrave, the Bell Warden: a giant hooded skeleton who swings the
## tower's bell as a hammer. He walks at the hero, heaves the bell up (the
## tell) and slams it down, sending shockwaves along the floor to jump over,
## and the bell sticks: his head hangs low and open. Hit him then (many hits
## per window); hits outside a window only chip. Three phases: from 60% he
## is angrier (shorter tells, waves both ways twice, skulls, a leap); under
## 25% the "Toll of Ruin" rains rubble after each slam. A window never
## crosses into the next phase. Once per phase, heavy damage inside one
## window rings him ("RUNG!"): the window ends with a bonus. His head is a
## stomp target only while his body is safe to touch (stuck, reeling,
## roaring); landing on it mid-attack hurts.
##
## Shared boss interface (frozen): signal woke; boss_info() -> Dictionary;
## reset_fight(); touch_damage() -> bool; the world calls reset_fight when
## the hero relights after being snuffed. v3 (contract §6.4): is_open(),
## configure(opts), window_bonus(), reset_fight(keep_phase).
##
## The rush, "Unquiet" (spec §5.6; BR): only a mode's configure({rush: true})
## turns any of this on, so the story's fight is v2's to the tick.
##   Bell Roll    P2+, after every third slam of a phase: he wrenches the bell
##                off its chain and swings it behind him (0.6 s, floor 0.45; a
##                lane of light runs along the floor where it will go), then
##                bowls it along the floor: a 48 x 48 bell at 280 px/s (36).
##                It rebounds off the far wall once and rolls back (jump it
##                twice), hopping up a one-tile step. He is open 1.2 s while
##                it rolls (+Tollbreaker), head low and empty-handed; then,
##                still empty-handed and closed, he throws the Skull Choir,
##                comes at Wick (1.6 s, less in P3) and throws it again, and
##                comes on until the bell rolls back past him and he catches
##                it (one that comes to rest, he walks to). No slams without it.
##   Skull Choir  in P1 too (3 skulls, every third move, as P2 counts them).
##   Toll of Ruin 6 chunks, still 64 px apart, each with its shadow.
## The life (BossMods.RUSH_HP x the mode's hp_mult) and the Warded and
## Echoing Wax mods are boss_mods.gd's; the boss bar gets its segments.

signal woke

const Arena := preload("res://scripts/boss_arena.gd")
const BossMods := preload("res://scripts/boss_mods.gd")
const WALK := 62.0
const FRAME_FEET := Vector2(128, 244)
const PHASES := [0.60, 0.25]
const WINDOW := [1.9, 1.5, 1.2]
const TELL := [0.7, 0.45, 0.4]
const CHIP := 0.10
const STAGGER := 0.30
const TELL_FLOOR := 0.35          # spec: every tell lasts at least 0.35 s...
const TELL_FLOOR_WITCHING := 0.30 # ...and never under 0.30 s on Witching Hour
const RUNG_NUMBER_UP := 66.0      # the RUNG bonus sits this far over his middle, clear of the hit's number
const RUBBLE_DROP := 275.0        # a Toll of Ruin chunk starts at least this far over his floor (a 0.39 s fall after its 0.6 s shadow)
# The rush (configure only).
const ROLL_TELL := 0.6            # Bell Roll's wrench and swing...
const ROLL_FLOOR := 0.45          # ...never shorter than this, on any difficulty or Tweak
const ROLL_SPEED := 280.0
const ROLL_SIZE := 48.0
const ROLL_OPEN := 1.2            # he is open this long while it rolls
const ROLL_EVERY := 3             # slams of a phase before each roll (P2+)
const ROLL_GRAVITY := 1800.0
const ROLL_HOP := 390.0           # up a one-tile step: a hop of about 42 px
const ROLL_WAIT := 9.0            # the longest he waits for it (it's back in about 7 s at most)
const ROLL_CATCH := 22.0          # the bell back this near his middle: caught
const ROLL_STALK := 1.6           # with it out, he comes at Wick this long (P2) between his Skull Choirs...
const ROLL_TOSSES := 2            # ...at most this many while it's out
const RUSH_RUBBLE := 6
const BELL_TEX := "res://art/props/bell.svg"
const BELL_SRC := Rect2(30, 26, 196, 198)   # bell.svg's body over its rope (texture px)
# While his bell is out he's empty-handed: A4's boss_bowl / boss_catch when
# they're there, else boss_hurt (arms up, the bell swung clear on its chain)
# with the texture cut left of the bell, so only the snapped chain shows.
const EMPTY_CUT := Rect2(0, 0, 356, 512)
# The same for his closed frames: boss_windup under the bell swung overhead
# (the Skull Choir's throw); boss_idle in three pieces round the bell and
# the hand at his side (coming at Wick), the robe the bell hid painted in.
const WINDUP_CUT := Rect2(0, 152, 512, 360)
const IDLE_CUT_TOP := Rect2(0, 0, 512, 300)
const IDLE_CUT_MID := Rect2(0, 300, 360, 46)
const IDLE_CUT_LOW := Rect2(0, 346, 322, 166)
const IDLE_PATCH := [Vector2(321, 346), Vector2(360, 346), Vector2(368, 478), Vector2(352, 486), Vector2(336, 478), Vector2(321, 486)]
const IDLE_EDGE := [Vector2(358, 300), Vector2(361, 346), Vector2(368, 478), Vector2(352, 486), Vector2(336, 478), Vector2(321, 486)]
const ROBE := Color("4c3f60")
const ROBE_LINE := Color("0c0812")
const ROBE_RIM := Color("ffeccc")
# Which frames read as what (the tests hold his touch to them): dazed, safe
# to touch and stomp; the rest closed.
const DAZED_FRAMES := ["boss_hurt", "boss_stuck", "boss_bowl"]
# A4's empty-handed frames (requested; loaded only when they exist, and then
# warmed at the title with v2's: main.gd).
const RUSH_FRAMES := ["boss_bowl", "boss_catch"]
const BELL_BODY := Color("c8962e")
const BELL_DARK := Color("2a1406")
const BELL_LIT := Color("f0c860")

var state := "sleep"
var timer := 0.0
var phase := 1
var _attacks := 0
var arena_left := 0.0
var arena_right := 0.0
var door: Array[Vector2i] = []
var door_side := -1                # the door's wall: -1 left, 1 right (boss_arena.gd find)
var home := Vector2.ZERO
var _window_dmg := 0.0
var _rung_phase := 0          # the last phase he was rung in
var boss_id := "tollgrave"
var boss_name := "Old Tollgrave"
var boss_title := "The Bell Warden"
# The rush's state (all idle in the story).
var rush := false                 # set by configure({rush: true}) (BossMods.configure)
var _bm: RefCounted = null        # boss_mods.gd's runtime (Warded, Echoing), or null
var _phase_slams := 0             # slams this phase (a Bell Roll after every ROLL_EVERY)
var _bell := {}                   # the rolling bell: {x, y (its bottom), vx, vy, bounced, spin, t}
var _roll_dir := 1
var _bell_tex: Texture2D = null
var _bell_moves := 0              # his moves since the bowl (the Skull Choir first, then he comes at Wick)
var _cut_node: Node2D = null      # draws boss_idle's lower pieces while it's cut round the bell
var rolls := 0                    # Bell Rolls bowled (tests)
var catches := 0                  # ...and caught (tests)


func _init() -> void:
	kind = "boss"
	xp_kind = "tollgrave"
	size = Vector2(58, 78)
	base_hp = 260.0
	base_dmg = 28.0
	embers = 30
	item_chance = 0.0
	relic_chance = 0.0
	stompable = true
	ordinary = false
	anchor = FRAME_FEET


func _ready() -> void:
	super()
	load_frames(["boss_idle", "boss_windup", "boss_slam", "boss_stuck", "boss_hurt"])
	if rush:
		load_frames(RUSH_FRAMES)
	show_frame("boss_idle")
	home = position
	var a := Arena.find(level, position)
	arena_left = a["left"]
	arena_right = a["right"]
	door.assign(a["door"])
	door_side = int(a["side"])
	if rush and ResourceLoader.exists(BELL_TEX):
		_bell_tex = load(BELL_TEX)
	if rush and sprite:
		_cut_node = Node2D.new()
		_cut_node.visible = false
		_cut_node.draw.connect(_draw_cut)
		add_child(_cut_node)


func configure(opts: Dictionary) -> void:
	## A mode's boss (the Waxworks, a Descent echo depth), before _ready:
	## {rush, mods, hp_mult, area, echo}. rush turns on the rush's moves;
	## its life and mods are BossMods'. (area is the World's area_abs already.)
	BossMods.configure(self, opts)
	_bm = BossMods.of(self)


func boss_info() -> Dictionary:
	var info := {"id": boss_id, "name": boss_name, "title": boss_title, "frac": hp / maxf(max_hp, 1.0),
			"phases": PHASES, "awake": state != "sleep" and alive}
	if rush:
		info["segments"] = PHASES   # the rush's three-part bar (the story's stays v2's)
	return info


func is_open() -> bool:
	## A window: the bell stuck, the RUNG! reel (v2's Tollbreaker rule), or
	## (the rush) the Bell Roll's opening.
	return state in ["stuck", "hurt", "bowled"]


func window_bonus() -> float:
	return _window_bonus()


func reset_fight(_keep_phase := false) -> void:
	## Back to sleep at full life with the door open (the hero fell). (No
	## checkpoint: Tollgrave always starts over.)
	if not alive:
		return
	Arena.unseal(world, level, door)
	hp = max_hp
	phase = 1
	_attacks = 0
	_rung_phase = 0
	state = "sleep"
	timer = 0.0
	position = home
	velocity = Vector2.ZERO
	_phase_slams = 0
	_end_bell(false)
	if _bm:
		_bm.reset()
	_sync_head()
	if world:
		world.hazards.clear()


func vulnerable() -> bool:
	return state == "stuck" or state == "bowled"


func rect() -> Rect2:
	if state == "stuck" or (state == "bowled" and frame_is("boss_bowl")):
		# Hunched over the stuck bell: lower, the head at the front.
		return Rect2(position.x - size.x * 0.5, position.y - size.y * 0.7, size.x, size.y * 0.7)
	return super()


func touch_damage() -> bool:
	## Touching him hurts, except while the bell is stuck (hit him!) or he's reeling.
	return not (state in ["sleep", "dead", "stuck", "hurt", "roar", "bowled"])


func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	_sync_head()
	if rush and sprite:
		_cut_empty()
	if not _bell.is_empty():
		# The bell rolls on whatever he's doing (stunned, reeling, roaring).
		_step_bell(dt, player)
	if _bm:
		_bm.step(dt, player)


func _sync_head() -> void:
	## His head is safe to land on exactly when his body is safe to touch
	## (stuck, reeling, roaring): landing on it at any other time hurts like
	## a Thornback's spikes, so it's no perch to wait out his attacks on.
	stompable = not touch_damage()


func dmg(what := "touch") -> float:
	var base = {"touch": 28.0, "wave": 36.0, "skull": 22.0, "rubble": 30.0, "bell": 36.0}.get(what, base_dmg)
	return float(base) * dmg_mult


func hit(h: Dictionary) -> bool:
	if not alive or state == "sleep":
		return false
	var how: String = h.get("how", "slash")
	if how == "shock" or how == "bump":
		return false
	if _bm and _bm.blocks(h):
		return false   # Warded Wax: a mote took it
	var amount: float = float(h.get("amount", 0.0))
	if vulnerable():
		if how == "stomp":
			amount *= 3.0
	else:
		amount *= CHIP
		h["chip"] = true
	# A window never crosses a phase threshold.
	var floor_hp := 0.0
	if phase <= PHASES.size():
		floor_hp = max_hp * PHASES[phase - 1]
	var clamped := false
	if hp - amount <= floor_hp and phase <= PHASES.size():
		amount = hp - floor_hp
		clamped = true
	hp = maxf(hp - amount, 0.0)
	last_damage = amount
	flash = 1.0
	hp_bar = 2.5
	if vulnerable():
		_window_dmg += amount
	if world:
		world._sfx("boss_hit" if not h.get("chip", false) else "clang")
		world.shake = maxf(world.shake, 6.0 if not h.get("chip", false) else 2.0)
	if hp <= 0.0:
		_kill(h)
		state = "dead"
		timer = 0.0
		if world:
			world._sfx("boss_die")
		return true
	if clamped:
		# The next phase: a roar, and straight into a faster fight.
		phase += 1
		_phase_slams = 0
		state = "roar"
		timer = 1.2
		_window_dmg = 0.0
		velocity = Vector2.ZERO
		show_frame("boss_hurt")
		if world:
			world._sfx("boss_roar")
			world.shake = 8.0
			world.boss_phase(self, phase)
		_sync_head()
		return true
	if vulnerable() and _window_dmg >= STAGGER * max_hp and _rung_phase < phase:
		# RUNG: the window ends early with a bonus.
		_rung_phase = phase
		var floor2 = max_hp * PHASES[phase - 1] if phase <= PHASES.size() else 0.0
		var bonus := minf(0.10 * max_hp, hp - floor2 - 1.0)
		if bonus > 0.0:
			hp -= bonus
		_window_dmg = 0.0
		state = "hurt"
		timer = 0.8 + _window_bonus()
		velocity = Vector2(160.0 * (1.0 if position.x > float(h.get("from_x", position.x)) else -1.0), -220.0)
		show_frame("boss_hurt")
		if world:
			if bonus > 0.0:
				world.number(center() + Vector2(0, -RUNG_NUMBER_UP), bonus, "crit")
			world.banner("RUNG!")
			world.freeze(0.08, true)
		_sync_head()
	return true


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	var dx: float = player.position.x - position.x
	var tell: float = tell_time()
	match state:
		"sleep":
			show_frame("boss_idle")
			if player.alive and Arena.past_door(door_side, arena_left, arena_right, player.position.x, 48.0) and absf(dx) < 420.0:
				state = "roar"
				timer = 1.3
				Arena.seal(world, level, door)
				woke.emit()
				if world:
					world._sfx("boss_roar")
					world.shake = 6.0
		"roar":
			_gravity(dt)
			if timer <= 0.0:
				_next()
		"walk":
			facing = 1 if dx > 0.0 else -1
			velocity.x = facing * WALK * (1.0 + 0.25 * (phase - 1))
			_gravity(dt)
			show_frame("boss_idle")
			if sprite:
				sprite.position.y = -absf(sin(t * 5.0)) * 3.0
			if timer <= 0.0 or absf(dx) < 70.0:
				state = "windup"
				timer = tell
				velocity.x = 0.0
		"windup":
			velocity.x = 0.0
			_gravity(dt)
			show_frame("boss_windup")
			if sprite:
				sprite.position = Vector2(sin(t * 60.0) * 1.5, 0)
			if timer <= 0.0:
				_slam(player)
		"slam":
			_gravity(dt)
			if timer <= 0.0:
				state = "stuck"
				_window_dmg = 0.0
				timer = WINDOW[clampi(phase - 1, 0, 2)] + _window_bonus()
		"stuck":
			velocity.x = 0.0
			_gravity(dt)
			show_frame("boss_stuck")
			if sprite:
				sprite.position = Vector2(sin(t * 30.0) * (1.0 if timer < 0.5 else 0.0), 0)
			if timer <= 0.0:
				_next()
		"hurt":
			_gravity(dt)
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * dt)
			if timer <= 0.0:
				if rush and not _bell.is_empty():
					# Rung in the Bell Roll's opening: no bell to swing yet.
					_next()
				else:
					state = "windup"
					timer = tell
		"leap":
			if rush:
				show_frame("boss_windup")   # (a leap is an attack: never a dazed frame)
			_gravity(dt)
			if on_floor and timer <= 0.0:
				velocity.x = 0.0
				_waves(1)
				if world:
					world._sfx("boss_slam")
					world.shake = 7.0
				state = "walk"
				timer = 0.9
		"toss":
			velocity.x = 0.0
			_gravity(dt)
			show_frame("boss_windup")
			if rush and not _bell.is_empty() and frames.has("boss_catch"):
				show_frame("boss_catch")
			if timer <= 0.0:
				_skulls(player)
				state = "walk"
				timer = 1.0
				if rush and not _bell.is_empty():
					_next()   # no bell to slam with: he comes at Wick for it
		# ---- the rush's states (never reached in the story)
		"roll_tell":
			# Bell Roll: he wrenches the bell off its chain and swings it back.
			velocity.x = 0.0
			_gravity(dt)
			show_frame("boss_windup")
			if sprite:
				sprite.position = Vector2(sin(t * 50.0) * 1.2, 0)
			if timer <= 0.0:
				_bowl()
		"bowled":
			# Open while it rolls: hunched, head low, nothing to swing.
			velocity.x = 0.0
			_gravity(dt)
			show_frame(_bowled_frame())
			if timer <= 0.0:
				_next()
		"stalk":
			# The bell's out: he comes at Wick empty-handed (his touch hurts)
			# and catches it as it rolls back past him (_step_bell).
			_gravity(dt)
			show_frame(_closed_frame())
			if _bell.is_empty() or bool(_bell["rest"]) or timer <= 0.0:
				velocity.x = 0.0
				_next()
			else:
				if absf(dx) > 6.0:
					facing = 1 if dx > 0.0 else -1
				velocity.x = facing * WALK * (1.0 + 0.25 * (phase - 1)) if absf(dx) > 44.0 else 0.0
				if sprite:
					sprite.position.y = -absf(sin(t * 5.0)) * 3.0
		"await_bell":
			# His bell came to rest: he walks to it and picks it up.
			_gravity(dt)
			show_frame(_closed_frame())
			if _bell.is_empty() or timer <= 0.0:
				_end_bell(true)
				velocity.x = 0.0
				_next()
			else:
				var bx: float = float(_bell["x"])
				if on_floor and position.y < float(_bell["y"]) - 20.0:
					drop_through = 0.3   # up on a ledge: down he comes for it
				if absf(bx - position.x) > 4.0:
					facing = 1 if bx > position.x else -1
				velocity.x = facing * WALK * (1.0 + 0.25 * (phase - 1)) if not bool(_bell["rest"]) or absf(bx - position.x) > ROLL_CATCH * 0.5 else 0.0
				if sprite:
					sprite.position.y = -absf(sin(t * 5.0)) * 3.0
	if sprite and state not in ["walk", "windup", "stuck", "roll_tell", "await_bell", "stalk"]:
		sprite.position = Vector2.ZERO
	position.x = clampf(position.x, arena_left + size.x * 0.5, arena_right - size.x * 0.5)


func tell_time() -> float:
	## The windup before a slam: shorter each phase and on harder
	## difficulties, but never under the spec's floor.
	var m: float = world.tells_mult() if world else 1.0
	var lo: float = TELL_FLOOR_WITCHING if world and str(world.diff) == "witching" else TELL_FLOOR
	return maxf(float(TELL[clampi(phase - 1, 0, 2)]) * m, lo)


func _window_bonus() -> float:
	## Seconds a worn Tollbreaker adds to a stuck or staggered window.
	if world == null or world.player == null:
		return 0.0
	var f = world.player.stats.get("flags", {})
	return float(f.get("tollbreaker_window", 0.0)) if f is Dictionary else 0.0


func _gravity(dt: float) -> void:
	velocity.y = minf(velocity.y + 1800.0 * dt, 700.0)
	move(dt)


func _next() -> void:
	if rush and _rush_next():
		return
	_attacks += 1
	if phase >= 2 and _attacks % 3 == 0:
		state = "toss"
		timer = 0.6
	elif phase >= 2 and _attacks % 3 == 2 and world:
		state = "leap"
		timer = 0.3
		var target: float = world.player.position.x
		velocity = Vector2(clampf((target - position.x) * 1.4, -420.0, 420.0), -620.0)
		on_floor = false
	else:
		state = "walk"
		timer = randf_range(1.2, 2.0) / (1.0 + 0.2 * (phase - 1))


func _slam(player: Node2D) -> void:
	state = "slam"
	timer = 0.25
	_phase_slams += 1
	show_frame("boss_slam")
	_waves(2 if phase >= 2 else 1)
	if phase >= 3:
		_rubble(player)
	if world:
		world._sfx("boss_slam")
		world.shake = 9.0
		world._haptic(45)


func _waves(n: int) -> void:
	if world == null:
		return
	var front := position.x + facing * size.x * 0.55
	for i in n:
		for dir in [-1, 1]:
			var hw: Dictionary = world.add_hazard({"kind": "wave", "motion": "floor", "rect": Rect2(front - 9.0, position.y - 22.0, 18.0, 22.0),
					"vel": Vector2(dir * (250.0 + i * 70.0), 0.0), "life": 2.0, "delay": i * 0.28, "dmg": dmg("wave"), "owner": "enemy"})
			if _bm:
				_bm.watch(hw)


func _skulls(player: Node2D) -> void:
	if world == null:
		return
	var n := 5 if phase >= 3 else 3
	for i in n:
		var dir := 1.0 if player.position.x > position.x else -1.0
		var hs: Dictionary = world.add_hazard({"kind": "skull", "motion": "bounce", "rect": Rect2(position.x + dir * 20.0 - 9.0, position.y - 70.0, 18.0, 18.0),
				"vel": Vector2(dir * (150.0 + i * 45.0), -300.0 - i * 50.0), "g": 1100.0, "life": 3.2, "dmg": dmg("skull"), "owner": "enemy"})
		if _bm:
			_bm.watch(hs)
	world._sfx("slash", 0.6)


func _rubble(player: Node2D) -> void:
	## The Toll of Ruin: four chunks fall (six in the rush), one where the
	## hero stands, each with a shadow on the floor first.
	var xs := [player.position.x]
	var tries := 0
	var chunks := RUSH_RUBBLE if rush else 4
	var most := 120 if rush else 40
	while xs.size() < chunks and tries < most:
		tries += 1
		var x := randf_range(arena_left + 24.0, arena_right - 24.0)
		var ok := true
		for o in xs:
			if absf(o - x) < 64.0:
				ok = false
		if ok:
			xs.append(x)
	# From over the view's top, and never less than RUBBLE_DROP over his floor
	# (the camera shows less over the hero than it did, and the fall is part
	# of the warning).
	var top := minf(world.view_rect().position.y - 30.0, position.y - RUBBLE_DROP)
	for x in xs:
		var hr: Dictionary = world.add_hazard({"kind": "rubble", "motion": "fall", "rect": Rect2(x - 11.0, top, 22.0, 22.0),
				"vel": Vector2(0, 700.0), "life": 2.0, "delay": 0.6, "dmg": dmg("rubble"), "owner": "enemy", "shadow": true})
		if _bm:
			_bm.watch(hr)


func _dying(dt: float) -> void:
	show_frame("boss_hurt")
	if sprite:
		sprite.modulate.a = clampf(1.0 - (death_time - 1.2) * 1.5, 0.0, 1.0)
		sprite.position = Vector2(sin(death_time * 40.0) * 3.0 * clampf(1.2 - death_time, 0.0, 1.0), death_time * 6.0)
	if world and fmod(death_time, 0.15) < dt and death_time < 1.2 and world.glow:
		world.glow.burst(center() + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 8, Color("7ef0c8"), 140.0, 0.5, 0.0, 2.4)
	if death_time > 1.2 and death_time - dt <= 1.2 and world:
		world.boss_defeated(self, center())
		world.add_bell(Vector2((arena_left + arena_right) * 0.5, position.y))
	if death_time > 2.0:
		gone = true


func eye_points() -> Array:
	var low := state == "stuck" or (state == "bowled" and frame_is("boss_bowl"))
	var head := center() + Vector2(facing * 14.0, -22.0 if not low else -4.0)
	return [head + Vector2(-5, 0), head + Vector2(5, 0)]


func _draw() -> void:
	if not frames.is_empty():
		return
	var r := rect()
	r.position -= position
	draw_rect(r, Color("2a2238"))
	draw_circle(Vector2(facing * 12.0, r.position.y + 20.0), 16.0, Color("efe6d2"))
	draw_circle(Vector2(facing * 18.0, r.position.y + 18.0), 4.0, Color("7ef0c8"))
	var bell_y := r.position.y - 20.0 if state == "windup" else r.end.y - 26.0
	draw_circle(Vector2(facing * 40.0, bell_y), 22.0, Color("b8862a"))


# ---------------------------------------------------------------- the rush ("Unquiet")

func _rush_next() -> bool:
	## The rush's own picks, before v2's (true when it chose): with his bell
	## out, no slams (_bell_less); a Bell Roll after every ROLL_EVERY slams of
	## a phase (P2+); the Skull Choir in P1 on every third move, as P2 counts them.
	if not _bell.is_empty():
		_bell_less()
		return true
	if phase >= 2 and _phase_slams >= ROLL_EVERY and on_floor:
		# (Up on a ledge he's leapt to, the bell drops to the floor and rolls
		# there, and he comes down for it.)
		_phase_slams = 0
		_start_roll()
		return true
	if phase == 1 and (_attacks + 1) % 3 == 0:
		_attacks += 1
		state = "toss"
		timer = 0.6
		return true
	return false


func roll_tell_time() -> float:
	## Bell Roll's tell: 0.6 s by the difficulty's and the Tweaks' multiplier,
	## never under ROLL_FLOOR.
	var m: float = world.tells_mult() if world else 1.0
	return maxf(ROLL_TELL * m, ROLL_FLOOR)


func _start_roll() -> void:
	var pl: Node2D = world.player if world else null
	if pl != null:
		facing = 1 if pl.position.x > position.x else -1
	# He bowls toward the wall with more room when Wick is right at the other.
	var room_fwd := (arena_right - position.x) if facing > 0 else (position.x - arena_left)
	if room_fwd < ROLL_SIZE * 2.0:
		facing = -facing
	_roll_dir = facing
	state = "roll_tell"
	timer = roll_tell_time()
	velocity.x = 0.0
	if world:
		world._sfx("clank", 0.7)
		world._tell_sfx("gear_roll", timer)


func _bowl() -> void:
	## The bell leaves his hands behind him and rolls out ahead along the floor.
	var half := ROLL_SIZE * 0.5
	var x := clampf(position.x - _roll_dir * 10.0, arena_left + half, arena_right - half)
	_bell = {"x": x, "y": position.y, "vx": _roll_dir * ROLL_SPEED, "vy": 0.0, "bounced": false, "rest": false,
			"spin": 0.0, "t": 0.0}
	rolls += 1
	state = "bowled"
	timer = ROLL_OPEN + _window_bonus()
	_window_dmg = 0.0
	_bell_moves = 0
	if _ground_below(position.x, position.y + 2.0) > position.y + 2.0:
		drop_through = 0.35   # up on a ledge: he comes down with it, to its floor
	show_frame(_bowled_frame())
	if world:
		world._sfx("boss_slam", 0.8)
		world.shake = maxf(world.shake, 5.0)
		world.dust_at(Vector2(x, position.y))
		world._haptic(30)


func _await_bell() -> void:
	state = "await_bell"
	timer = ROLL_WAIT


func _bell_less() -> void:
	## His bell's out, so no slams: after his opening he throws the Skull
	## Choir, comes at Wick empty-handed, throws it again, and comes on until
	## it rolls back past him (caught: his pattern goes on). One that came to
	## rest, he walks to.
	if bool(_bell.get("rest", false)):
		_await_bell()
		return
	_bell_moves += 1
	if _bell_moves % 2 == 1 and _bell_moves <= ROLL_TOSSES * 2 - 1:
		state = "toss"
		timer = 0.6
	else:
		state = "stalk"
		timer = ROLL_STALK / (1.0 + 0.2 * (phase - 2)) if _bell_moves < ROLL_TOSSES * 2 else ROLL_WAIT


func bell_rect() -> Rect2:
	## The rolling bell's box (48 x 48 on the floor), or an empty rect.
	if _bell.is_empty():
		return Rect2()
	var half := ROLL_SIZE * 0.5
	return Rect2(float(_bell["x"]) - half, float(_bell["y"]) - ROLL_SIZE, ROLL_SIZE, ROLL_SIZE)


func _ground_below(x: float, y: float) -> float:
	## The top of the floor under x, from just above y down (INF: none near).
	var ty := floori((y - 8.0) / TILE)
	for k in 8:
		if LevelData.is_solid(level.tile(floori(x / TILE), ty + k)):
			return (ty + k) * TILE
	return INF


func _step_bell(dt: float, player: Node2D) -> void:
	var b := _bell
	b["t"] = float(b["t"]) + dt
	if not alive or float(b["t"]) > ROLL_WAIT + ROLL_OPEN:
		_end_bell(false)
		return
	var half := ROLL_SIZE * 0.5
	var vx: float = float(b["vx"])
	var dir := signf(vx)
	var x: float = float(b["x"]) + vx * dt
	var y: float = float(b["y"])
	var vy: float = float(b["vy"])
	var grounded := vy == 0.0 and _ground_below(x, y) <= y + 0.5
	var wall := false
	if dir > 0.0 and x + half >= arena_right:
		x = arena_right - half
		wall = true
	elif dir < 0.0 and x - half <= arena_left:
		x = arena_left + half
		wall = true
	elif dir != 0.0:
		var fx := x + dir * (half + 2.0)
		var step1: bool = LevelData.is_solid(level.tile(floori(fx / TILE), floori((y - 16.0) / TILE)))
		var step2: bool = LevelData.is_solid(level.tile(floori(fx / TILE), floori((y - 48.0) / TILE)))
		if step1 and step2:
			x = floorf(fx / TILE) * TILE - dir * (half + 2.0) + (TILE if dir < 0.0 else 0.0)
			wall = true
		elif step1 and grounded:
			vy = -ROLL_HOP   # a one-tile step: it hops up
	if wall:
		if not bool(b["bounced"]):
			# The far wall: it rings off it and rolls back.
			b["bounced"] = true
			vx = -vx
			if world:
				world._sfx("bell", 0.75)
				world.shake = maxf(world.shake, 4.0)
				if world.glow:
					world.glow.burst(Vector2(x + dir * half, y - half), 14, BELL_LIT, 170.0, 0.4, 300.0, 2.4)
		else:
			# Back at the near wall with no one to catch it: it lies there.
			vx = 0.0
			b["rest"] = true
	# Falling and landing.
	if vy != 0.0 or not grounded:
		vy += ROLL_GRAVITY * dt
		y += vy * dt
		var g := _ground_below(x, y - vy * dt)
		if vy > 0.0 and y >= g:
			y = g
			vy = 0.0
	if y > level.height * TILE + 64.0:
		_end_bell(false)
		return
	b["x"] = x
	b["y"] = y
	b["vx"] = vx
	b["vy"] = vy
	b["spin"] = float(b["spin"]) + vx * dt / half
	var r := bell_rect()
	var live := not bool(b["rest"])
	if _bm:
		_bm.follow("bell", r, dmg("bell"), live)
	if live and player != null and player.alive and world and r.grow(-3.0).intersects(player.rect()):
		world.hurt_player(dmg("bell"), x, "hit", self, {"move": "bell_roll"})
	# Home: back at his feet, he catches it.
	if bool(b["bounced"]) and absf(x - position.x) < ROLL_CATCH and absf(y - position.y) < 40.0:
		_end_bell(true)
		if state in ["await_bell", "stalk"]:
			velocity.x = 0.0
			_next()


func _end_bell(caught: bool) -> void:
	if _bell.is_empty():
		return
	if _bm:
		_bm.end("bell")
	if world:
		var at := Vector2(float(_bell["x"]), float(_bell["y"]) - ROLL_SIZE * 0.5)
		if caught:
			catches += 1
			world._sfx("clang", 0.8)
		if world.glow:
			world.glow.burst(at, 10 if caught else 16, BELL_LIT, 120.0, 0.35, 200.0, 2.2)
	_bell = {}


func _bowled_frame() -> String:
	## His opening while the bell rolls: A4's empty-handed hunch when it's
	## there (boss_bowl), else boss_hurt cut empty-handed (step()).
	return "boss_bowl" if frames.has("boss_bowl") else "boss_hurt"


func _closed_frame() -> String:
	## Empty-handed and closed (coming at Wick, walking to his bell): A4's
	## boss_catch when it's there, else boss_idle cut round the bell (step()).
	return "boss_catch" if frames.has("boss_catch") else "boss_idle"


func shown_frame() -> String:
	## The frame on show (tests), "" with none.
	for n in frames:
		if frame_is(n):
			return n
	return ""


func _cut_empty() -> void:
	## While his bell is out he's drawn empty-handed: A4's frames as they
	## are, else v2's with the bell cut away (boss_hurt left of the swung
	## bell; boss_windup under the bell overhead; boss_idle in two pieces).
	var a := Rect2()
	var low := false
	if not _bell.is_empty() or state == "bowled":
		if frame_is("boss_hurt"):
			a = EMPTY_CUT
		elif frame_is("boss_windup"):
			a = WINDUP_CUT
		elif frame_is("boss_idle"):
			a = IDLE_CUT_TOP
			low = true
	var cut := a.size.x > 0.0
	sprite.region_enabled = cut
	sprite.region_rect = a
	sprite.offset.y = -anchor.y * 2.0 + a.position.y
	if _cut_node == null:
		return
	_cut_node.visible = low and sprite.visible
	if low:
		_cut_node.modulate = sprite.modulate
		_cut_node.z_index = sprite.z_index
		_cut_node.queue_redraw()


func _draw_cut() -> void:
	## boss_idle's pieces under the top one (left of the hand, left of the
	## bell), and the robe's edge the bell hid, in the sprite's own space.
	var tex: Texture2D = sprite.texture
	if tex == null:
		return
	var o := Vector2(sprite.offset.x, -anchor.y * 2.0)
	_cut_node.draw_set_transform(sprite.position, 0.0, sprite.scale)
	for r in [IDLE_CUT_MID, IDLE_CUT_LOW]:
		_cut_node.draw_texture_rect_region(tex, Rect2(o + r.position, r.size), r)
	_cut_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var xf := Transform2D(0.0, sprite.scale, 0.0, sprite.position)
	var tb: RefCounted = _roll_tb()
	var patch := PackedVector2Array()
	var edge := PackedVector2Array()
	var rim := PackedVector2Array()
	for q in IDLE_PATCH:
		patch.append(xf * (o + (q as Vector2)))
	for q in IDLE_EDGE:
		edge.append(xf * (o + (q as Vector2)))
		rim.append(xf * (o + (q as Vector2) + Vector2(4, 3)))
	var k := absf(sprite.scale.y)
	tb.concave(patch, ROBE)
	tb.polyline(rim, 4.0 * k, ROBE_RIM)
	tb.polyline(edge, 6.0 * k, ROBE_LINE)
	tb.flush(_cut_node)


func frame_is(n: String) -> bool:
	return sprite != null and frames.has(n) and sprite.texture == frames[n]


func _kill(h: Dictionary) -> void:
	super(h)
	# The fight is over the moment he falls: the bell and the echoes go with him.
	_end_bell(false)
	if _bm:
		_bm.clear()


func lights() -> Array:
	## The rolling bell carries a light (it reads in the dark); the Warded
	## motes theirs. None in the story.
	var out: Array = []
	if not _bell.is_empty():
		out.append({"p": bell_rect().get_center(), "r": 70.0, "s": 0.75})
	if _bm:
		out.append_array(_bm.lights())
	return out


func draw_glow(glow: Node2D) -> void:
	## Above the dark: Bell Roll's lane while he winds up, the bell itself,
	## and the mods. Nothing in the story (enemy.gd's is empty).
	if state == "roll_tell" or not _bell.is_empty():
		_draw_roll(glow)
	if _bm:
		_bm.draw_glow(glow)


func _draw_roll(glow: Node2D) -> void:
	var tb: RefCounted = _roll_tb()
	var half := ROLL_SIZE * 0.5
	if state == "roll_tell":
		# The lane: a band of light along the floor from his feet to the far
		# wall, chevrons running the bell's way, brightening as the tell ends.
		var k := 1.0 - clampf(timer / maxf(roll_tell_time(), 0.01), 0.0, 1.0)
		var x0 := position.x - _roll_dir * 10.0
		var gy := _ground_below(x0, position.y + 2.0)   # the floor it will roll on (a ledge drops it there)
		var y := (gy if gy < INF else position.y) - 2.0
		var x1 := arena_right - 4.0 if _roll_dir > 0 else arena_left + 4.0
		var a := minf(x0, x1)
		var bnd := absf(x1 - x0)
		tb.rect(Rect2(a, y - ROLL_SIZE, bnd, ROLL_SIZE), Color(BELL_LIT, 0.05 + 0.10 * k))
		tb.rect(Rect2(a, y - 2.0, bnd, 3.0), Color(BELL_LIT, 0.35 + 0.5 * k))
		var n := int(bnd / 40.0)
		for i in n:
			var cx := x0 + _roll_dir * (fmod(float(i) * 40.0 + t * 160.0, maxf(bnd, 1.0)))
			var cy := y - 12.0
			var c := Color(1.0, 0.86, 0.5, (0.25 + 0.6 * k) * (1.0 - float(i) / maxf(n, 1)))
			tb.line(Vector2(cx - _roll_dir * 7.0, cy - 7.0), Vector2(cx, cy), 2.5, c)
			tb.line(Vector2(cx - _roll_dir * 7.0, cy + 7.0), Vector2(cx, cy), 2.5, c)
		# Dust off his heels as he wrenches it free.
		var heel := Vector2(position.x - _roll_dir * 26.0, position.y - 3.0)
		for i in 4:
			var q := fmod(t * 2.5 + i * 0.25, 1.0)
			tb.circle(heel + Vector2(-_roll_dir * q * 22.0, -q * 10.0), 3.0 + q * 5.0, Color(0.8, 0.72, 0.6, 0.35 * (1.0 - q)), 8)
		tb.flush(glow)
		return
	var r := bell_rect()
	var c2 := r.get_center()
	var rest := bool(_bell["rest"])
	var spin := float(_bell["spin"])
	# A warm halo under it and speed streaks behind it.
	tb.ellipse(Vector2(c2.x, r.end.y - 1.0), half + 6.0, 4.0, Color(0, 0, 0, 0.45), 14)
	tb.circle(c2, half + 10.0, Color(1.0, 0.8, 0.4, 0.10), 16)
	if not rest:
		var d := signf(float(_bell["vx"]))
		for i in 3:
			var yy := r.position.y + 12.0 + i * 12.0
			tb.line(Vector2(c2.x - d * (half + 4.0), yy), Vector2(c2.x - d * (half + 26.0 + i * 6.0), yy), 2.0, Color(1.0, 0.85, 0.55, 0.35 - i * 0.08))
	if _bell_tex == null:
		# The stand-in: a bronze bell on its side, turning.
		var rot := Transform2D(spin, c2)
		var body := PackedVector2Array()
		for q in [Vector2(-10, -20), Vector2(10, -20), Vector2(16, 4), Vector2(22, 18), Vector2(-22, 18), Vector2(-16, 4)]:
			body.append(rot * (q as Vector2))
		tb.convex(body, BELL_DARK)
		var inner := PackedVector2Array()
		for q in [Vector2(-8, -17), Vector2(8, -17), Vector2(13, 4), Vector2(19, 15), Vector2(-19, 15), Vector2(-13, 4)]:
			inner.append(rot * (q as Vector2))
		tb.convex(inner, BELL_BODY)
		tb.line(rot * Vector2(-18, 13), rot * Vector2(18, 13), 2.0, BELL_LIT)
		tb.flush(glow)
		return
	tb.flush(glow)
	var sc := ROLL_SIZE / BELL_SRC.size.x * 1.1
	glow.draw_set_transform(c2, spin, Vector2(sc, sc))
	glow.draw_texture_rect_region(_bell_tex, Rect2(-BELL_SRC.size * 0.5, BELL_SRC.size), BELL_SRC)
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var _tb: RefCounted = null


func _roll_tb() -> RefCounted:
	if _tb == null:
		_tb = BossMods.TriBatch.new()
	return _tb
