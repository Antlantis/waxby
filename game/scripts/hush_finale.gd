extends RefCounted
## The finale: the stair and the gift (spec §5.5.6, decisions "The ending").
## A state of hush_boss.gd, played in the level with the player's thumbs on
## it; it cannot be failed (Wick is invulnerable throughout, and nothing here
## hurts him).
##   1. The grip opens (1.5 s): the Eye recoils to the arena's top right
##      (the spec's columns 37-40, rows 2-4); the stolen flame, out and cold,
##      floats up and settles beside it; the lake drains (its water goes, a
##      stone bed under the gaps) and the roof over it dissolves (p_worlds
##      §8.7: a jump up the stair never bumps it); the HUD fades but for the
##      Special button.
##   2. The rings (about 5 s): six pale rings drop one by one, 0.8 s apart,
##      each settling as a one-way ledge (world.add_temp_ledge) 3 tiles wide
##      at the spec's column 5 + 5k, its top at row 10 - k (rows 9 to 4); each
##      is a real light (r 140) and chimes finale_ring on D3 F3 G3 A3 C4 D4
##      (Sfx.note(k)); the hush_final bells stem comes back, +3 dB a ring.
##   3. The climb: the dark rises from below at 60 px/s. It doesn't hurt: if
##      it reaches him his flame gutters and he's lifted to the last ring he
##      stood on (ring 1 before any; never lower than he is). The Hands sweep
##      across at most twice (a 0.6 s pale outline) and knock him down a ring,
##      with no damage.
##   4. At the top (standing on ring 6): the Special button's pill reads "Hold
##      to give your flame"; the Hush's two lines and the calling's @give play
##      as barks one at a time, LINE s apart (hush_give_a, hush_give_b, give).
##   5. The hold (Special, or jump while he stands, or Space on a Mac): his
##      real light drains to 0 over 3.0 s of held time (world.light_override,
##      below LIGHT_MIN; the dark closes in as when he's hurt), his flame fades
##      with it (its own palette, a cosmetic one too), motes stream from it
##      into the dead wick, `give` steps down the scale every 0.5 s, a 10 ms
##      haptic every 0.4 s. Letting go pauses it (no refill). The drain never
##      outruns the words: held from the first moment it keeps pace with the
##      three lines and goes dark as the @give line has been read (LINES_END).
##      After 8 s at the top with no hold (and the lines said) the Hush says
##      hush_keep once and the pill pulses; the auto_advance setting completes
##      it after 4 s; a headless World nobody drives (no test pad) or the
##      --autoplay bot completes it at once.
##   6. Out: a snuff puff, a 60 ms haptic, 1.6 s of black and silence, then
##      "...there. quiet at last." (hush_quiet). Story.set_flag("hush_given")
##      (so boss_6_after opens on its second shot, the far bell), then the
##      boss's finish(): the XP (the World's died), world.boss_defeated() (the
##      prize and the drops, gathered to him at once) and the bell at his feet,
##      which he rings where he stands: the results, homecoming, lullaby.

const LevelData := preload("res://scripts/level_data.gd")
const TILE := 32
const GRIP := 1.5
const RING_EVERY := 0.8
const RING_FALL := 0.5
const RING_W := 96.0
const RING_LIGHT := 140.0
const DARK_SPEED := 60.0
const LIFT := 0.6
const SWEEP_TELL := 0.6
const SWEEP_GO := 0.3
const SWEEPS := 2
const HOLD := 3.0
const BLACK := 1.6
const AFTER := 1.4                # s from "quiet at last" to the bell
const NUDGE_AT := 8.0
const AUTO_AT := 4.0
const GIVE_EVERY := 0.5
const LINE := 2.6                 # s a line holds the message slot (the HUD's 2.5 s and a beat)
const LINES := [[0.4, "hush_give_a"], [3.0, "hush_give_b"], [5.6, "give"]]
const LINES_END := 8.2            # the @give line read (5.6 + LINE): no black before it
const COSMETICS := "res://scripts/modes/cosmetics.gd"
const HAPTIC_EVERY := 0.4
const EYE_SCALE := 0.55
const PALE := Color("d8d4f0")
const RIM := Color("c8c8f0")
const RING_COL := Color(0.86, 0.88, 1.0)

var boss: Node2D
var world: Node
var state := "grip"               # grip, climb, top, black, done
var t := 0.0
var rings: Array = []             # [{k, x0, top, land, landed, mover, light, flash}]
var dark_y := 0.0
var last_ring := -1               # the last ring he stood on (0-based)
var sweeps := 0
var sweep := {}                   # {ring, t, phase: tell|go, side}
var top_t := 0.0
var hold_t := 0.0
var idle_t := 0.0
var r0 := -1.0                    # his light as the hold began
var nudged := false
var lift := {}                    # {from, to, t, len}
var eye_from := Vector2.ZERO
var eye_p := Vector2.ZERO
var wick_from := Vector2.ZERO
var wick_p := Vector2.ZERO
var black_t := 0.0
var motes: Array = []
var lifts := 0                    # times the dark lifted him (tests)
var knocks := 0                   # times a sweep knocked him down (tests)
var gave := false                 # the hold ran out (tests)
var said: Array = []              # the barks fired, in order (tests)
var _give_t := 0.0
var _haptic_t := 0.0
var _sweep_cd := 4.0
var _bark_at: Array = []          # [[top_t, key]]
var _fade := 1.0                  # the rings' and the Eye's look (they go in the black)
var _bj := 0                      # bot_pad: frames of a held jump left
var _flame_id := ""               # his cosmetic flame (an animated one is refreshed here)
var _flame_pal := {}              # his flame's own palette as the finale began
var _cos: Script = null


func setup(b: Node2D, w: Node) -> void:
	boss = b
	world = w


func start() -> void:
	state = "grip"
	t = 0.0
	var pl: Node2D = world.player
	# His flame whole for the gift (and nothing hushing or dousing it).
	pl.hp = pl.max_hp
	pl.status.clear()
	pl.invuln = 9999.0
	for k in (world.dims() as Dictionary).keys():
		world.undim(str(k))
	world.light_override(-1.0)
	# His own flame (a cosmetic one too) stays his through the climb; the
	# finale owns it from here (an animated one is refreshed in _flame(), not
	# by the World's tick, which would drop the gift's fade: W0 asked).
	var fid = world.get("_flame_id")
	_flame_id = str(fid) if fid != null else ""
	var hf = world.get("hero_flame")
	_flame_pal = (hf as Dictionary).duplicate() if hf is Dictionary else {}
	if ResourceLoader.exists(COSMETICS):
		_cos = load(COSMETICS)
	if _flame_id != "" and fid != null:
		world.set("_flame_id", "")
	_flame(0.0)
	world.fade_for_finale(true)
	_stem("bells", -80.0, 0.3)
	_drain()
	var bx0: int = int(boss.block_x0)
	var dy: float = float(boss.islet_top) - 11.0 * TILE   # (an arena drawn at another height)
	for k in range(1, 7):
		var col := bx0 + 4 + 5 * k
		rings.append({"k": k, "x0": col * TILE, "top": (10 - k) * TILE + dy, "land": GRIP + (k - 1) * RING_EVERY + RING_FALL,
				"landed": false, "mover": null, "light": -1, "flash": 0.0})
	eye_from = boss.eye3.get("p", boss.position) if boss.eye3 is Dictionary else boss.position
	eye_p = Vector2((bx0 + 39) * TILE, 3.5 * TILE + dy)
	wick_from = eye_from + Vector2(0, 40)
	wick_p = Vector2((bx0 + 37) * TILE + 8.0, 4.0 * TILE + dy - 6.0)
	dark_y = float(world.level.height) * TILE + 24.0
	world._sfx("hush_blink")


func player() -> Node2D:
	return world.player


# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	t += dt
	var pl := player()
	if pl == null:
		return
	pl.invuln = maxf(pl.invuln, 9999.0)
	for r in rings:
		r["flash"] = maxf(float(r["flash"]) - dt, 0.0)
	_step_rings()
	_step_motes(dt)
	match state:
		"grip":
			if t >= GRIP:
				state = "climb"
		"climb":
			_note_ring(pl)
			_step_dark(dt, pl)
			_step_sweep(dt, pl)
			if world.get("autoplay"):
				_auto_climb(pl)
			if _on_ring(pl) == 5 and bool(rings[5]["landed"]):
				_reach_top()
		"top":
			_note_ring(pl)
			_step_dark(dt, pl)
			_step_top(dt, pl)
		"black":
			_step_black(dt, pl)
	_step_lift(dt, pl)


func _drain() -> void:
	## The lake drains: its water cells go (the level's restore list keeps
	## them), with a stone bed at the bottom of each gap so nothing falls out.
	## And the roof over the arena dissolves (the Hush's own dark stone): a
	## jump up the stair never bumps it (ring 5 to ring 6 sits two rows under
	## it, and a bumped jump falls short of the next ring).
	var lv = world.level
	var c0 := floori(float(boss.arena_left) / TILE) - 2
	var c1 := floori(float(boss.arena_right) / TILE) + 1
	var top_row := floori(float(boss.arena_top) / TILE)
	for x in range(c0, c1 + 1):
		var any := false
		for y in lv.height:
			if lv.tile(x, y) == LevelData.WATER:
				lv.set_tile(x, y, LevelData.AIR)
				any = true
		if any:
			lv.set_tile(x, lv.height - 1, LevelData.STONE)
		if x >= floori(float(boss.arena_left) / TILE) and x < floori(float(boss.arena_right) / TILE):
			for y in range(0, top_row):
				if LevelData.is_solid(lv.tile(x, y)):
					lv.set_tile(x, y, LevelData.AIR)
					any = true
					if world.get("glow") != null and (x + y) % 3 == 0:
						world.glow.burst(Vector2((x + 0.5) * TILE, (y + 0.5) * TILE), 4, Color(0.3, 0.28, 0.4), 60.0, 0.8, 200.0, 3.0)
		if any:
			world._redraw_at(x)


func _step_rings() -> void:
	for r in rings:
		if r["landed"] or t < float(r["land"]):
			continue
		r["landed"] = true
		r["flash"] = 0.6
		var rect := Rect2(float(r["x0"]), float(r["top"]), RING_W, 12.0)
		r["mover"] = world.add_temp_ledge(rect, -1.0)
		r["light"] = world.add_light(Vector2(float(r["x0"]) + RING_W * 0.5, float(r["top"]) - 8.0), RING_LIGHT, 0.8, -1.0, "finale_ring")
		var k: int = int(r["k"])
		var s = _sfx_node()
		var pitch: float = s.note(k - 1) if s != null and s.has_method("note") else 1.0
		world._sfx("finale_ring", pitch)
		_stem("bells", -18.0 + 3.0 * k, 0.4)
		if world.get("glow") != null:
			world.glow.burst(Vector2(float(r["x0"]) + RING_W * 0.5, float(r["top"])), 16, RING_COL, 160.0, 0.5, 0.0, 2.2)


func ring_rect(i: int) -> Rect2:
	var r: Dictionary = rings[i]
	return Rect2(float(r["x0"]), float(r["top"]), RING_W, 12.0)


func _on_ring(pl: Node2D) -> int:
	## The ring he stands on (0-based), or -1.
	if pl == null or not pl.on_floor:
		return -1
	for i in rings.size():
		var m = rings[i]["mover"]
		if m != null and pl.riding == m:
			return i
		if bool(rings[i]["landed"]) and absf(pl.position.y - float(rings[i]["top"])) < 2.0 \
				and pl.position.x >= float(rings[i]["x0"]) - 4.0 and pl.position.x <= float(rings[i]["x0"]) + RING_W + 4.0:
			return i
	return -1


func _note_ring(pl: Node2D) -> void:
	var i := _on_ring(pl)
	if i >= 0 and lift.is_empty():
		last_ring = i


func _step_dark(dt: float, pl: Node2D) -> void:
	## The last of the dark rises; reaching him, it lifts him (never hurts).
	var cap := float(rings[5]["top"]) + 80.0
	if not bool(rings[0]["landed"]):
		cap = float(boss.islet_top) + 12.0   # (it waits for the first ring)
	dark_y = maxf(dark_y - DARK_SPEED * dt, cap)
	if not lift.is_empty():
		return
	if pl.position.y > dark_y + 2.0:
		var to := _lift_target(pl)
		if to < 0:
			return
		# His flame gutters; he's lifted (standing on that ring already, he
		# stays where he is and the dark falls back).
		world.dim("script:finale_gutter", 0.7, 0.6)
		if world.get("glow") != null:
			world.glow.burst(world.rig.flame_point(), 10, Color(0.7, 0.68, 0.8), 80.0, 0.5, -60.0, 2.4)
		if _on_ring(pl) != to:
			lifts += 1
			_lift_to(pl, to)
		dark_y = float(rings[to]["top"]) + 3.0 * TILE


func _lift_target(pl: Node2D) -> int:
	## The last ring he stood on (ring 1 before any), but never down: from
	## higher up, the lowest landed ring above his feet.
	var i := maxi(last_ring, 0)
	if not bool(rings[i]["landed"]):
		return -1
	if _on_ring(pl) == i:
		return i
	if float(rings[i]["top"]) > pl.position.y + 1.0:
		# (he's higher than that ring, on a perch or mid-jump: the lowest
		# landed ring at his height or above, or the highest there is)
		var best := i
		for j in range(i, rings.size()):
			if bool(rings[j]["landed"]):
				best = j
				if float(rings[j]["top"]) <= pl.position.y + 1.0:
					return j
		return best
	return i


func _lift_to(pl: Node2D, i: int) -> void:
	var to := Vector2(float(rings[i]["x0"]) + RING_W * 0.5, float(rings[i]["top"]))
	lift = {"from": pl.position, "to": to, "t": 0.0, "len": LIFT, "ring": i}
	pl.frozen = true
	pl.velocity = Vector2.ZERO


func _step_lift(dt: float, pl: Node2D) -> void:
	if lift.is_empty():
		return
	lift["t"] = float(lift["t"]) + dt
	var k := clampf(float(lift["t"]) / float(lift["len"]), 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var a: Vector2 = lift["from"]
	var b: Vector2 = lift["to"]
	pl.position = a.lerp(b, e) + Vector2(0, -sin(k * PI) * 18.0)
	pl.velocity = Vector2.ZERO
	if k >= 1.0:
		pl.reset_at(b)
		pl.invuln = 9999.0
		last_ring = int(lift["ring"])
		lift = {}
		pl.frozen = state == "top" and hold_t > 0.0 and _holding(pl)


func _step_sweep(dt: float, pl: Node2D) -> void:
	## At most twice: a pale hand's outline at the side (0.6 s), then it
	## sweeps across his ring and knocks him down one, harmless.
	_sweep_cd -= dt
	if sweep.is_empty():
		var i := _on_ring(pl)
		if sweeps < SWEEPS and _sweep_cd <= 0.0 and i >= 1 and i <= 4 and lift.is_empty() and bool(rings[5]["landed"]):
			sweeps += 1
			var side := -1.0 if pl.position.x > (float(boss.arena_left) + float(boss.arena_right)) * 0.5 else 1.0
			sweep = {"ring": i, "t": SWEEP_TELL, "phase": "tell", "side": side}
			world._sfx("grasp_rise")
		return
	sweep["t"] = float(sweep["t"]) - dt
	if str(sweep["phase"]) == "tell":
		if float(sweep["t"]) <= 0.0:
			sweep["phase"] = "go"
			sweep["t"] = SWEEP_GO
			var i2 := int(sweep["ring"])
			if _on_ring(pl) == i2 and lift.is_empty():
				knocks += 1
				_lift_to(pl, i2 - 1)
				world._sfx("snuff_slam", 1.0, 0.0, 0.5)
	elif float(sweep["t"]) <= 0.0:
		sweep = {}
		_sweep_cd = 5.0


func _auto_climb(pl: Node2D) -> void:
	## The --autoplay bot at the stair: a ring a second, up it goes. Only from
	## his feet: in the air _on_ring is -1, and the next ring would be ring 1
	## again (the rev5 review: the bot_pad's hops lifted him back to ring 1 for
	## 14 s, so a phone's 6-4@1 run never reached the top).
	if not lift.is_empty() or not pl.on_floor:
		return
	var i := _on_ring(pl)
	if i < 0:
		i = last_ring
	var next := i + 1
	if next < rings.size() and bool(rings[next]["landed"]) and fmod(t, 1.2) < 0.02:
		_lift_to(pl, next)


func bot_pad(pl: Node2D) -> Dictionary:
	## A pad up the stair (the Hush's bot_pad in the finale: the --autoplay
	## bot's and the tests'): right along the lake bed, a held jump at a wall,
	## at the end of a floor or when a landed ring is just ahead; still on the
	## top ring, the Special held.
	if state == "top":
		return {"special": true} if lift.is_empty() and pl.on_floor else {}
	var pad := {}
	if _bj > 0:
		_bj -= 1
		pad["jump"] = true
		pad["right"] = true
		return pad
	var top := ring_rect(5)
	if bool(rings[5]["landed"]) and absf(pl.position.y - top.position.y) < 2.0 and pl.position.x > top.position.x + 30.0:
		return pad
	pad["right"] = true
	if not pl.on_floor or not lift.is_empty():
		return pad
	var x: float = pl.position.x
	var feet: float = pl.position.y
	var lv = world.level
	var jump := LevelData.is_solid(lv.tile(floori((x + 14.0) / TILE), floori((feet - 8.0) / TILE)))
	var cx := floori((x + 18.0) / TILE)
	var cy := floori((feet + 2.0) / TILE)
	var ahead: bool = LevelData.is_solid(lv.tile(cx, cy)) or LevelData.is_ledge(lv.tile(cx, cy))
	for m in world.movers:
		var mr: Rect2 = m.rect()
		if absf(mr.position.y - feet) < 3.0 and x + 18.0 >= mr.position.x and x + 18.0 <= mr.end.x:
			ahead = true
	if not ahead:
		jump = true
	for i in 6:
		if not bool(rings[i]["landed"]):
			continue
		var r := ring_rect(i)
		if r.position.y < feet - 1.0 and r.position.x > x + 10.0 and r.position.x < x + 90.0 and r.position.y > feet - 110.0:
			jump = true
	if jump:
		_bj = 30
		pad["jump"] = true
	return pad


# ---------------------------------------------------------------- the top and the gift

func _reach_top() -> void:
	state = "top"
	top_t = 0.0
	world.special_pill("Hold to give your flame")
	world.special_override = {"hold_ring": 0.0}
	_bark_at = LINES.duplicate(true)


func _holding(pl: Node2D) -> bool:
	## The Special or jump held while he stands (a jump press lifts him first:
	## the hold waits for his feet, so the gift never freezes him in the air).
	var pad = world.get("_pad")
	if not (pad is Dictionary) or not _at_top(pl):
		return false
	return (bool(pad.get("special", false)) or bool(pad.get("jump", false))) and pl.on_floor


func k_max() -> float:
	## How far the drain may have gone by now: never ahead of the three lines
	## (dark only once the @give line has been read).
	return clampf((top_t - float(LINES[0][0])) / (LINES_END - float(LINES[0][0])), 0.0, 1.0)


func _at_top(pl: Node2D) -> bool:
	var r: Dictionary = rings[5]
	return pl.position.x >= float(r["x0"]) - 20.0 and pl.position.y <= float(r["top"]) + 4.0


func _step_top(dt: float, pl: Node2D) -> void:
	top_t += dt
	# The Special gives, it doesn't fire: with no resource every kit's Special
	# fizzles (a knight's guard just rises). (W0: better, skip the kit's
	# Special while special_override holds the finale's hold_ring.)
	pl.res = 0.0
	world.undim("hushed")
	for b in _bark_at.duplicate():
		if top_t >= float(b[0]):
			_bark_at.erase(b)
			_say(str(b[1]))
	var holding := _holding(pl)
	var g = world.get_node_or_null("/root/Game")
	if g != null and g.has_method("setting") and bool(g.setting("auto_advance")) and top_t >= AUTO_AT:
		holding = true
	var at_once := bool(world.get("autoplay")) or (bool(world.get("headless")) and world.get("test_pad") == null)
	if at_once:
		holding = true
		hold_t = HOLD   # (headless with nobody at the pad: at once)
	if holding and lift.is_empty():
		if r0 < 0.0:
			world.light_override(-1.0)
			r0 = float(world.hero_light_radius())
		hold_t = minf(hold_t + dt, HOLD) if at_once else minf(minf(hold_t + dt, HOLD), HOLD * k_max())
		pl.frozen = true
		pl.velocity.x = 0.0
		pl.facing = 1
		idle_t = 0.0
		_give_t -= dt
		if _give_t <= 0.0:
			_give_t = GIVE_EVERY
			var s = _sfx_node()
			var k0 := hold_t / HOLD
			var pitch: float = s.in_key(lerpf(0.5, 1.0, 1.0 - k0)) if s != null and s.has_method("in_key") else 1.0
			world._sfx("give", pitch)
		_haptic_t -= dt
		if _haptic_t <= 0.0:
			_haptic_t = HAPTIC_EVERY
			world._haptic(10)
		if randf() < 0.6:
			motes.append({"p": world.rig.flame_point(), "t": 0.0})
	else:
		pl.frozen = false
		idle_t += dt
		if idle_t >= NUDGE_AT and top_t >= LINES_END and not nudged:
			nudged = true
			_say("hush_keep")
	var k := clampf(hold_t / HOLD, 0.0, 1.0)
	if r0 >= 0.0:
		world.light_override(r0 * (1.0 - k))
	_flame(k)
	world.special_override = {"hold_ring": k}
	if k >= 1.0:
		_go_black(pl)


func _say(key: String) -> void:
	said.append(key)
	world.bark(key)


func _flame(k: float) -> void:
	## His flame faded by k: his own palette (an animated cosmetic one at this
	## moment) with its alpha times 1 - k; {} for the plain candle unfaded.
	var pal := _flame_pal.duplicate()
	if _flame_id != "" and _cos != null and bool(_cos.animated(_flame_id)):
		pal = _cos.palette(_flame_id, float(world.get("ftime")) if world.get("ftime") != null else 0.0)
	if k > 0.0:
		pal["alpha"] = float(pal.get("alpha", 1.0)) * (1.0 - k)
	world.hero_flame = pal


func flame_given() -> void:
	## (the Hush's _dying: his flame stays given through the bell and the
	## level's end)
	_flame(1.0)


func _go_black(pl: Node2D) -> void:
	state = "black"
	black_t = 0.0
	gave = true
	world.light_override(0.0)
	_flame(1.0)
	world.special_pill("")
	world.special_override = {}
	if world.get("glow") != null:
		world.glow.burst(world.rig.flame_point(), 14, Color(0.7, 0.68, 0.78), 70.0, 0.9, -70.0, 3.0)
	world._haptic(60)
	world._sfx("snuff")
	var s = _sfx_node()
	if s != null:
		if s.has_method("stop_music"):
			s.stop_music(0.4)
		if s.has_method("hush_pulse"):
			s.hush_pulse(BLACK + 0.4, 1.0, true)
	for r in rings:
		if int(r["light"]) >= 0:
			world.remove_light(int(r["light"]))
			r["light"] = -1


func _step_black(dt: float, pl: Node2D) -> void:
	black_t += dt
	_fade = clampf(1.0 - black_t / 0.5, 0.0, 1.0)
	# The 1.6 s of black are black (spec §5.5.6 step 6; the rev5 review: the
	# lake's rings, the ledges, his rim and every button still showed): the
	# HUD lays a black over the level, the touch controls fade with it, and
	# "...there. quiet at last." reads over it.
	world.set("finale_black", 1.0 - _fade)
	pl.frozen = true
	_flame(1.0)
	if black_t >= BLACK and black_t - dt < BLACK:
		_say("hush_quiet")
	if black_t >= BLACK + AFTER and state == "black":
		state = "done"
		_finish(pl)


func _finish(pl: Node2D) -> void:
	## The gift is given: the flag (boss_6_after opens on the far bell), then
	## the XP, the prize and drops (gathered to him), and the bell he rings
	## where he stands.
	var St = load("res://scripts/story.gd")
	if St != null and (St as Script).get_script_method_list().any(func(m): return m["name"] == "set_flag"):
		St.set_flag("hush_given")
	var n0: int = world.pickups.size()   # (the prize and the drops are appended after these)
	# The bell comes down on the top ring he stands on (never where a jump
	# left him in the air).
	var top := ring_rect(5)
	var at := Vector2(clampf(pl.position.x, top.position.x + 14.0, top.end.x - 14.0), top.position.y)
	if not _at_top(pl):
		at = pl.position
	boss.finish(at)
	for i in range(n0, world.pickups.size()):
		var p: Dictionary = world.pickups[i]
		if bool(p.get("taken", false)):
			continue
		if str(p.get("kind", "")) in ["item", "relic", "ember"]:
			p["pop"] = true
			p["age"] = 0.0
			p["pos"] = pl.center()
			p["vel"] = Vector2(randf_range(-30.0, 30.0), -160.0)
	world.fade_for_finale(false)


# ---------------------------------------------------------------- the look

func _step_motes(dt: float) -> void:
	## His flame's motes, streaming into the dead wick.
	for m in motes:
		m["t"] = float(m["t"]) + dt
	motes = motes.filter(func(m): return float(m["t"]) < 0.9)


func eye_now() -> Vector2:
	var k := clampf(t / GRIP, 0.0, 1.0)
	return eye_from.lerp(eye_p, k * k * (3.0 - 2.0 * k))


func wick_now() -> Vector2:
	var k := clampf((t - 0.3) / (GRIP + 0.8), 0.0, 1.0)
	return wick_from.lerp(wick_p, k * k * (3.0 - 2.0 * k)) + Vector2(0, sin(t * 1.3) * 2.0)


func lights() -> Array:
	## The rings are the World's lights (add_light); the Eye keeps a faint
	## glint of its own until the black.
	if state == "black" or state == "done":
		return []
	return [{"p": eye_now(), "r": 40.0, "s": 0.3, "tint": Color(0.7, 0.6, 1.0, 0.3)}]


func draw_glow(glow: Node2D, tb: RefCounted) -> void:
	var a := _fade
	if a <= 0.0:
		return
	# The rings: falling as pale bands, then a bright rim on each ledge.
	for r in rings:
		var land := float(r["land"])
		if t < land - RING_FALL:
			continue
		var k := clampf((t - (land - RING_FALL)) / RING_FALL, 0.0, 1.0)
		var y := lerpf(float(r["top"]) - 220.0, float(r["top"]), k * k)
		var x0 := float(r["x0"])
		tb.rect(Rect2(x0 + 4.0, y - 1.0, RING_W - 8.0, 2.0), Color(1, 1, 1, (0.55 + 0.4 * float(r["flash"])) * a))
		tb.ring(Vector2(x0 + RING_W * 0.5, y + 4.0), 50.0 + 30.0 * float(r["flash"]), 1.2, Color(RING_COL, 0.35 * float(r["flash"]) * a), 28)
	# The dark's pale ragged surface.
	var bl: float = float(boss.arena_left)
	var br: float = float(boss.arena_right)
	if dark_y < float(world.level.height) * TILE:
		var pts := PackedVector2Array()
		var n := 30
		for i in n + 1:
			var x := bl + (br - bl) * float(i) / n
			pts.append(Vector2(x, dark_y + sin(t * 3.0 + i * 1.3) * 3.0))
		tb.polyline(pts, 2.0, Color(PALE, 0.6 * a))
	# A sweep's hand: its pale outline at the side, then across.
	if not sweep.is_empty():
		var i2 := int(sweep["ring"])
		var ry := float(rings[i2]["top"])
		var side := float(sweep["side"])
		var x: float
		if str(sweep["phase"]) == "tell":
			x = bl + 30.0 if side > 0.0 else br - 30.0
		else:
			var k2 := 1.0 - clampf(float(sweep["t"]) / SWEEP_GO, 0.0, 1.0)
			x = lerpf(bl + 30.0, br - 30.0, k2) if side > 0.0 else lerpf(br - 30.0, bl + 30.0, k2)
		var kk := 1.0 - clampf(float(sweep["t"]) / SWEEP_TELL, 0.0, 1.0) if str(sweep["phase"]) == "tell" else 1.0
		var hand := PackedVector2Array()
		for j in 14:
			var ang := PI * 0.5 + (j / 13.0 - 0.5) * 2.4
			var rr := 26.0 if j % 3 != 0 else 40.0
			hand.append(Vector2(x, ry - 22.0) + Vector2(cos(ang) * rr * side, sin(ang) * rr * 0.8))
		tb.polyline(hand, 2.0, Color(PALE, (0.4 + 0.5 * kk) * a), true)
		tb.rect(Rect2(bl, ry - 1.0, br - bl, 2.0), Color(PALE, 0.15 * kk * a))
	# The motes into the dead wick, and its cold glint.
	var w := wick_now()
	for m in motes:
		var k3 := float(m["t"]) / 0.9
		var p: Vector2 = (m["p"] as Vector2).lerp(w, k3) + Vector2(0, -sin(k3 * PI) * 16.0)
		tb.circle(p, 2.2 * (1.0 - k3 * 0.5), Color(1.0, 0.85, 0.5, 0.9 * (1.0 - k3 * 0.4)), 8)
	tb.circle(w + Vector2(0, -6), 2.4, Color(0.8, 0.85, 1.0, 0.7 * a), 8)
	# The Eye's iris, faint, watching him climb.
	var e := eye_now()
	tb.circle(e, 4.0, Color(1, 1, 1, 0.8 * a), 10)
	tb.ring(e, 16.0, 1.2, Color(0.72, 0.62, 1.0, 0.5 * a), 20)


func draw_parts(ci: CanvasItem) -> void:
	## Over the dark, on the glow layer: the rising dark itself, the rings,
	## the Eye (at 0.55: the spec's four columns), the dead wick, the hand.
	var a := _fade
	var bl: float = float(boss.arena_left) - 64.0
	var br: float = float(boss.arena_right) + 64.0
	var bottom: float = float(world.level.height) * TILE + 64.0
	if dark_y < bottom:
		ci.draw_rect(Rect2(bl, dark_y, br - bl, bottom - dark_y), Color(0.01, 0.01, 0.025, 0.92))
	if a <= 0.0:
		return
	var art: Dictionary = boss.get("_art") if boss.get("_art") is Dictionary else {}
	var ring_tex: Texture2D = art.get("ring_ledge")
	for r in rings:
		var land := float(r["land"])
		if t < land - RING_FALL:
			continue
		var k := clampf((t - (land - RING_FALL)) / RING_FALL, 0.0, 1.0)
		var y := lerpf(float(r["top"]) - 220.0, float(r["top"]), k * k)
		if ring_tex != null:
			# ring_ledge: 192 x 64 units, its one-way top at y 24 (12 px down).
			ci.draw_texture_rect(ring_tex, Rect2(float(r["x0"]), y - 12.0, RING_W, 32.0), false, Color(1, 1, 1, a))
		else:
			ci.draw_rect(Rect2(float(r["x0"]), y, RING_W, 8.0), Color(RING_COL, 0.8 * a))
	var eye_tex: Texture2D = art.get("hush_eye_open" if state != "black" else "hush_eye_shut")
	var e := eye_now()
	var sc := lerpf(1.0, EYE_SCALE, clampf(t / GRIP, 0.0, 1.0))
	if eye_tex != null:
		var sz := Vector2(256, 128) * sc
		ci.draw_texture_rect(eye_tex, Rect2(e - sz * 0.5, sz), false, Color(1, 1, 1, a))
		var pu: Texture2D = art.get("hush_pupil")
		if pu != null and state != "black":
			var look := Vector2.ZERO
			if world.get("player") != null:
				look = ((world.player.center() as Vector2) - e).limit_length(18.0 * sc)
			ci.draw_texture_rect(pu, Rect2(e + look - Vector2(16, 16) * sc, Vector2(32, 32) * sc), false, Color(1, 1, 1, a))
	var fl: Texture2D = art.get("stolen_flame")
	var w := wick_now()
	if fl != null:
		# stolen_flame: 64 units, its base at (32, 54): 32 x 32 px, base 5 px up.
		ci.draw_texture_rect(fl, Rect2(w - Vector2(16, 27), Vector2(32, 32)), false, Color(1, 1, 1, a))


func _sfx_node() -> Node:
	if world == null or not world.has_method("_has_sfx") or not world._has_sfx():
		return null
	return world.get_node_or_null("/root/Sfx")


func _stem(name: String, db: float, sec: float) -> void:
	var s = _sfx_node()
	if s != null and s.has_method("set_stem"):
		s.set_stem("hush_final_" + name, db, sec)
