extends RefCounted
## The camera's rules for a level taller than a strip (Build 2's shapes, E5:
## LevelData.tall()). world.gd builds one only for such a level and its
## _update_camera asks it (aim, rate, ride); a strip never has one, so its
## camera is exactly as before (6-3's chases are tuned to it to the second).
## The prototype's (proto-tall), made rules:
##
## - A fall looks ahead. Once he has fallen FALL_BELOW px under the floor he
##   left (a jump back onto it never does, so plain jumps don't bob the
##   camera) and falls faster than FALL_VY, or while he slides down a vine,
##   the camera eases in (over 1 / FALL_EASE s) to hold his feet at
##   FALL_FEET on the glass, led by his speed so its easing doesn't drag
##   them down: where he'll land is in view, not under the thumb buttons or
##   off the bottom (the strip camera trails a long fall 3.5-4 tiles behind
##   the buttons, the prototype found). He lands and it eases back.
## - A lift carries the camera with it (ride), so its easing never lags his
##   floor under the thumb buttons (the strip camera trails a lift's sweep:
##   on its way down his floor sinks under the Special's top).
## - A look down: down held DOWN_HOLD s standing still on stone eases his
##   feet up to DOWN_FEET (about two more rows under him), back when let go.
##   (On a one-way ledge down drops him through first: player.gd DROP_HOLD.)
## - The top band at a tower's top: where the camera stops at the level's
##   top edge, a goal there must show clear of the HUD's top band (its
##   corner blocks and the pause button): band_hits, with the camera where
##   it settles on him at the goal (world.gd cam_on), is the shapes' HUD rule
##   (tests/test_shaped.gd holds the labs to it; the level rules can ask it).
##   The camera never leans for a goal: that would put his floor under the
##   thumb buttons, which a lean keeps only for a tell (look_up).
## - World 4's icicle lean only for an icicle within ICICLE_ROWS of his feet
##   (world.gd look_up asks icicle_near): one 7 rows up in a tall level
##   pushed his feet under the Special.

const LevelData := preload("res://scripts/level_data.gd")
const TILE := 32
const FALL_BELOW := 16.0         # px under the floor he left before a fall looks ahead
const FALL_VY := 250.0           # px/s: ...and falling faster than this
const FALL_FEET := 112.0         # view y the look-ahead holds his feet at (FEET_TOP 84 is the highest the flame allows)
const FALL_EASE := 6.0           # 1/s the look-ahead comes in at
const FALL_RATE := 9.0           # the camera's easing rate while it looks ahead (world.gd's for a fast fall)
const SLIDE_VY := 220.0          # a vine slide's speed (player.gd CLIMB_SLIDE: on a vine his velocity reads 0)
const DOWN_HOLD := 0.3           # s of down held standing still before the camera looks down
const DOWN_FEET := 130.0         # view y a look down holds his feet at
const ICICLE_ROWS := 5           # W4's icicle lean: only this many rows over his feet

var w: Node                      # the World
var floor_y := 0.0               # his feet when he last stood (or hung on a vine)
var fall_k := 0.0                # the look-ahead's share (0..1)
var down_t := 0.0                # s of down held standing still
var looking := ""                # what the camera does now: "" | fall | slide | down (the tests read it)


func _init(world: Node) -> void:
	w = world


func aim(target_y: float, feet_at: float, settled: bool, dt: float) -> float:
	## The camera centre's y to ease to, from world.gd's (target_y: the feet
	## line, or the air band's); feet_at is his feet's y plus half the view.
	var pl: Node2D = w.player
	looking = ""
	if w.state != "play" or pl == null or not pl.alive:
		fall_k = 0.0
		down_t = 0.0
		return target_y
	if settled:
		floor_y = pl.position.y
	var sliding: bool = pl.climbing and str(pl.climb_state) == "slide"
	var falling: bool = not settled and float(pl.velocity.y) > FALL_VY and pl.position.y > floor_y + FALL_BELOW
	if falling or sliding:
		fall_k = minf(fall_k + dt * FALL_EASE, 1.0)
	else:
		fall_k = 0.0 if settled else maxf(fall_k - dt * FALL_EASE, 0.0)
	var out := target_y
	if fall_k > 0.0:
		# His feet at FALL_FEET, led by his speed (the easing's lag at FALL_RATE).
		var vy: float = SLIDE_VY if sliding else float(pl.velocity.y)
		var ahead := feet_at - FALL_FEET + vy / FALL_RATE
		var k := fall_k * fall_k * (3.0 - 2.0 * fall_k)
		out = lerpf(target_y, maxf(target_y, ahead), k)
		looking = "slide" if sliding else "fall"
	var pd = w.get("_pad")
	var down: bool = pd is Dictionary and bool(pd.get("down", false)) and not pd.get("left", false) and not pd.get("right", false)
	if down and pl.on_floor and not pl.climbing and absf(float(pl.velocity.x)) < 10.0:
		down_t += dt
	else:
		down_t = 0.0
	if down_t >= DOWN_HOLD:
		out = maxf(out, feet_at - DOWN_FEET)
		looking = "down"
	return out


func rate(base: float) -> float:
	## The camera's easing rate: FALL_RATE while a fall looks ahead.
	return maxf(base, FALL_RATE) if fall_k > 0.0 else base


func ride() -> float:
	## The y the lift he stands on moved this step (the camera moves with it).
	var m = w.player.riding if w.player != null else null
	return float(m.delta.y) if m != null and w.state == "play" else 0.0


func icicle_near(feet: float, hang: Vector2) -> bool:
	## World 4's icicle lean: only for one within ICICLE_ROWS of his feet.
	return feet - hang.y <= ICICLE_ROWS * TILE


# ---------------------------------------------------------------- the top band

func goals() -> Array:
	## The goals still to reach as world rects: each bell not rung (its beam
	## to its floor) and each sigil not taken.
	var out := []
	for b in w.bells:
		if not bool(b["rung"]):
			var top: Vector2 = b["top"]
			var f: Vector2 = b["pos"]
			out.append(Rect2(f.x - 24.0, top.y - 10.0, 48.0, f.y - top.y + 10.0))
	for p in w.pickups:
		if str(p["kind"]) == "sigil" and not bool(p["taken"]):
			out.append(Rect2((p["pos"] as Vector2) - Vector2(12, 12), Vector2(24, 24)))
	return out


func band() -> Array:
	## The HUD's top band, in view px: its corner blocks (the level badge,
	## the life bar, the ember count, the sigils) and the pause button, as
	## rects (the button's square), as world.gd's head_top picks them.
	var v: Vector2 = w._view_size()
	var cover: Dictionary = w._ui_cover if not (w._ui_cover as Dictionary).is_empty() else w._ui_shapes()
	var out := []
	for q in cover["rects"]:
		if (q as Rect2).end.y < v.y * 0.5:
			out.append(q)
	for c in cover["circles"]:
		var p: Vector2 = c[0]
		if p.y < v.y * 0.3:
			var r := float(c[1])
			out.append(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0))
	return out


func band_hits(r: Rect2, cam_c := Vector2.INF) -> String:
	## Which of the top band's blocks a world rect is behind with the camera
	## centred at cam_c (the camera now by default), as "x,y wxh" of the
	## block, or "" (the shapes' HUD rule asks it with the camera where it
	## settles on him at the goal: goal_hits).
	var c: Vector2 = w.cam if cam_c == Vector2.INF else cam_c
	var vr := Rect2(r.position - (c - w._view_size() * 0.5), r.size)
	for q in band():
		if (q as Rect2).intersects(vr):
			return "%d,%d %dx%d" % [q.position.x, q.position.y, q.size.x, q.size.y]
	return ""


func goal_hits() -> Array:
	## The shapes' HUD rule: each goal (goals()) that the top band covers with
	## the camera where it settles on him standing at it (the floor under its
	## middle; world.gd cam_on, stopped at the level's edges), as
	## "<x,y>: <block>"; [] when every one shows clear.
	var out := []
	var lv: RefCounted = w.level
	for g in goals():
		var gr: Rect2 = g
		var cx := floori(gr.get_center().x / TILE)
		var feet := Vector2.INF
		for y in range(maxi(floori(gr.get_center().y / TILE), 0), lv.height):
			if not LevelData.is_solid(lv.tile(cx, y)) and LevelData.is_floor(lv.tile(cx, y + 1)):
				feet = LevelData.cell_floor(Vector2i(cx, y))
				break
		if feet == Vector2.INF:
			continue
		var hit := band_hits(gr, w.cam_on(feet))
		if hit != "":
			out.append("%d,%d: %s" % [cx, floori(gr.get_center().y / TILE), hit])
	return out
