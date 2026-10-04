extends RefCounted
## The --autoplay bot at the controls (debug builds, for checking a build on
## the phone): it plans a route to the level's goal with the reachability
## engine (reach_search.gd, greedy: nearest the goal first) on the level's
## static copy, then plays the route's pads, action by action. When where it
## lands isn't where the plan said (a monster's knock, a crumble, a moving
## ledge's timing), it plans again from there. It swings at whatever is in
## front of it as it goes. At a boss (the arena reached) it fights as v2's bot
## did: toward him, swinging, hopping his waves; shut in a fight room (a
## secret level's Warden, a sealed duel, ambush or hold) it fights the room's
## foe the same way till the doors open (_room_pad). It plans a few sims a tick,
## so a route never stalls a frame; while it plans it stands still.
##
## A shaped level (Build 2's shapes: taller than a strip, or its goal behind
## the start: a level played right to left) goes by route (by_route): the
## goal's route field (route_field.gd, the way there in moves) orders its
## plans and sets their horizon (HORIZON_MOVES nearer, not HORIZON further
## right), measures its progress (STUCK), times a jump onto a lift, and
## points its fallback pad (_route_pad, where v2's held right); a step
## still falling past its sims' time runs on (Reach.fall_extra). In a room
## two decks tall a foe on the other deck is planned to as a goal, on the
## level as it is (the doors shut). A strip whose goal lies right (every
## level before the shapes, and every mode's room) plays exactly as before.
##
## v2's bot only held right and jumped every second: it stood forever at the
## 4-tile wall at x 406 on 2-4 (the owner saw it on the phone).

const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
const RouteField := preload("res://scripts/route_field.gd")
const Movers := preload("res://scripts/movers.gd")
const LevelData := preload("res://scripts/level_data.gd")
const TILE := 32
const DT := 1.0 / 120.0
const SIMS_PER_TICK := 3
# Planning's time a frame in a window (a phone's perf run): a state's sims
# cost up to 18 ms on the Mac in W3-W4 (0.5-3 ms each), so planning stops at
# this budget a frame instead (ReachSearch.run's budget_us), however many
# physics ticks the frame runs. Headless (the tests, the smoke bot) it keeps
# SIMS_PER_TICK a tick, exactly as before.
const PLAN_BUDGET_US := 1500
const PLAN_CAP := 6000
const STUCK := 4.0               # s without progress along the plan: plan again
const HORIZON := 20.0 * TILE     # plan this far on at a time (then plan again)
const HORIZON_MOVES := 20        # by route: plan till this many moves nearer the goal (route_field.gd)
const DECK := 4.5 * TILE         # a room's foe this far over or under him is on the other deck (planned to)

var world: Node
var goal := {}                   # {what, p, rope, rect}
var _live: RefCounted = null     # a search on the real level with its movers moving (timing checks)
var _wait := 0.0                 # s spent waiting for a moving ledge to come round
var state := "plan"              # plan | follow | fight | done
var _static: RefCounted
var _search: RefCounted = null
var _route: Array = []           # [{action, to: key}]
var _step := -1
var _act := {}
var _st := {}
var _t := 0.0
var _prev := {}
var _i := 0
var _progress_t := 0.0
var _best_x := -INF
var by_route := false            # a shaped level: the route field measures the way (use_route)
var field: RefCounted = null     # route_field.gd toward goal (by route)
var _best_d := RouteField.FAR    # by route: the fewest moves from the goal since the plan
var _level_goal := {}            # the goal a room's other-deck foe stood in for (_room_plan)
var _level_field: RefCounted = null
var _room_static: RefCounted = null   # the level as it is, its doors shut (a room goal's plans)
var plans := 0                   # routes planned (the tests read it)
var _final := {}                 # a mode's room: the goal after its altars (the landing's first, as a human walks into it)
var _altar_t := 0.0              # s spent going for the altar in goal (past ALTAR_GIVE_UP: on without it)
var _skip: Array = []            # altars given up on
const ALTAR_GIVE_UP := 15.0
var debug := false               # print why it plans again


func setup(w: Node) -> void:
	world = w
	_static = Reach.static_copy(w.level)
	if not w.movers.is_empty():
		# Moving ledges: time each jump on copies of them (the plan laid them
		# out over their whole sweep, as if the timing were perfect).
		var real = Reach.static_copy(w.level, {"movers": false})
		_live = ReachSearch.new()
		_live.setup(real, Vector2.ZERO, {"goals": []})
	var goals := Reach.goals_of(w.level)
	for g in goals:
		if g["what"] == "bell" or g["what"] == "boss arena":
			goal = g
		elif g["what"] == "silver bell" and str(w.level.id).ends_with("-S"):
			# A secret level: its S is where the silver bell rises once the
			# Warden falls (features/secrets.gd); the fight is _room_pad's.
			goal = g
	if goal.is_empty() and not goals.is_empty():
		goal = goals[goals.size() - 1]
	if w.get("mode") == null and not goal.is_empty() and shaped(w.level, goal):
		use_route()
	if w.get("mode") != null and not goal.is_empty():
		# A mode's room (a Descent depth): an altar within a plan's reach of
		# where he stands (the landing's), first, so the run lights it (its
		# Glimmers, its relight) as a player walking in would; the route
		# passes the others. The story's levels keep v2's route.
		_final = goal
		_to_altar()


static func shaped(lv: RefCounted, g: Dictionary) -> bool:
	## A shaped level goes by route: taller than a strip, or its goal left of
	## where it starts him (a level played right to left: `facing: left`,
	## whose bell the shape rules keep left of its start).
	return lv.tall() or (g["p"] as Vector2).x < LevelData.cell_floor(lv.start).x


func use_route(on := true) -> void:
	## Go by route (see the header): the goal's route field, built on the
	## static copy (the tests turn it on for a strip too).
	by_route = on
	field = RouteField.new().build(_static, goal, Reach.drops_of(world.level)) if on and not goal.is_empty() else null
	_search = null
	_route = []
	state = "plan" if state != "done" else state


func _to_altar() -> void:
	## The nearest unlit altar on the way to the final goal, within a plan's
	## reach (HORIZON) of him, as the goal; else the final goal.
	var pl: Node2D = world.player
	var from_x: float = pl.position.x if pl != null else 0.0
	var dir := signf((_final["p"] as Vector2).x - from_x)
	var best := {}
	_altar_t = 0.0
	for a in world.altars:
		if bool(a["lit"]) or _skip.has(a):
			continue
		var ax: float = (a["pos"] as Vector2).x
		if (ax - from_x) * dir < -8.0 or (ax - (_final["p"] as Vector2).x) * dir > 0.0 or absf(ax - from_x) > HORIZON:
			continue
		if best.is_empty() or absf(ax - from_x) < absf((best["pos"] as Vector2).x - from_x):
			best = a
	if best.is_empty():
		goal = _final
		return
	var ap: Vector2 = best["pos"]
	goal = {"what": "altar", "p": ap, "rope": true, "rect": Rect2(ap.x - 12.0, ap.y - 24.0, 24.0, 24.0), "altar": best}


func pad(dt: float) -> Dictionary:
	_i += 1
	var pl: Node2D = world.player
	if pl == null or not pl.alive or world.state != "play":
		_search = null
		state = "plan" if state != "done" else state
		return {}
	if goal.is_empty():
		return _v2_pad(pl)
	var wp := _room_pad(pl)
	if not wp.is_empty():
		return wp
	if goal.has("altar"):
		_altar_t += dt
		if _altar_t > ALTAR_GIVE_UP:
			_skip.append(goal["altar"])   # out of the plan's reach: on without it
	if goal.has("altar") and (bool((goal["altar"] as Dictionary)["lit"]) or _skip.has(goal["altar"])):
		# Lit: on to the next altar, or the goal.
		_to_altar()
		_search = null
		_route = []
		state = "plan"
	if _reached_goal(pl):
		state = "fight" if goal["what"] == "boss arena" else "done"
	match state:
		"fight":
			return _fight_pad(pl)
		"done":
			# On toward the goal (v2 held right; a shaped level's way, by route).
			if by_route:
				var hd := _heading(pl)
				return {"right": hd.x > 0, "left": hd.x < 0}
			return {"right": true}
		"plan":
			return _plan(pl)
		"follow":
			return _follow(pl, dt)
	return {}


func _reached_goal(pl: Node2D) -> bool:
	if goal["what"] == "boss arena":
		var b = world.boss
		if b != null and is_instance_valid(b) and b.get("state") != "sleep" and b.get("state") != null:
			return true
		return pl.rect().intersects(goal["rect"])
	return false


# ---------------------------------------------------------------- planning

func _plan(pl: Node2D) -> Dictionary:
	if not (pl.on_floor or pl.climbing):
		return {}   # plan from somewhere to stand
	if _search == null:
		_search = ReachSearch.new()
		var dir := signf(goal["p"].x - pl.position.x)
		var opts := {"mode": "greedy", "target": goal["p"], "stop_on": goal["what"],
				"goals": [goal], "cap": PLAN_CAP, "start_climb": pl.climbing, "stop_x": pl.position.x + dir * HORIZON}
		if field != null:
			# By route: ordered by the way there, till HORIZON_MOVES nearer.
			opts.erase("stop_x")
			opts["field"] = field
			opts["stop_d"] = maxi(int(field.at(pl.position)) - HORIZON_MOVES, 0)
		if goal.get("room", false):
			# A room's other deck: till he stands on it (a touch from below
			# beside its edge isn't there), so no goal to touch, only the field.
			opts["goals"] = []
			opts["stop_on"] = ""
			opts["stop_d"] = 0
		_search.setup(_room_static if goal.get("room", false) else _static, pl.position, opts)
		if pl.climbing:
			_search.nodes[0]["col"] = pl.climb_col
	var in_window: bool = not bool(world.get("headless"))
	if in_window:
		# The budget is a frame's, not a tick's: a slow frame runs up to 6
		# physics ticks, and 6 budgets would slow the next frame more (a
		# spiral the Mac showed on 4-2 at 30 s).
		var f := Engine.get_process_frames()
		if f != _plan_frame:
			_plan_frame = f
			_plan_left = PLAN_BUDGET_US
		if _plan_left <= 0:
			return {}
		var u0 := Time.get_ticks_usec()
		var fin: bool = _search.run(1 << 30, 1 << 30, _plan_left)
		_plan_left -= Time.get_ticks_usec() - u0
		if not fin:
			return {}
	elif not _search.run(SIMS_PER_TICK):
		return {}
	plans += 1
	var s = _search
	_search = null
	s.free_player()
	var end_node := -1
	var hit := {}
	if s.found.has(goal["what"]):
		hit = s.found[goal["what"]]
		end_node = int(hit["node"])
	elif s.best > 0:
		end_node = int(s.best)   # as far on as it got: follow that, then plan on
	if end_node < 0:
		# No way from here: v2's way, and plan again in a while.
		state = "follow"
		_route = []
		_progress_t = 0.0
		return _v2_pad(pl)
	var path: Array = s.path_to(end_node)
	if debug:
		print("  bot: plan %d from %s: %s, %d states, route %d (to the %s)" % [plans, pl.position, "goal" if not hit.is_empty() else "best", s.seen.size(), path.size() - 1, goal["what"]])
	_route = []
	for k in range(1, path.size()):
		var n: Dictionary = s.nodes[path[k]]
		_route.append({"action": n["action"], "to": Reach.key_of(n["pos"], n["climb"])})
	if not hit.is_empty():
		# The last action: the one that touched the goal.
		_route.append({"action": hit["action"], "to": null})
	_step = -1
	state = "follow"
	_progress_t = 0.0
	_best_x = pl.position.x
	_best_d = int(field.at(pl.position)) if field != null else RouteField.FAR
	return _next(pl)


func _next(pl: Node2D) -> Dictionary:
	_step += 1
	if _step >= _route.size():
		state = "plan"
		return {}
	_act = _route[_step]["action"]
	_st = {}
	_t = 0.0
	_settle = 0.0
	return _drive(pl)


var _settle := -1.0              # s spent coming to rest before an action (the sims start at rest)
var _plan_frame := -1            # the process frame planning last ran in (a window's budget is per frame)
var _plan_left := 0              # us of planning left in that frame


# ---------------------------------------------------------------- following

func _follow(pl: Node2D, dt: float) -> Dictionary:
	if _route.is_empty():
		_progress_t += dt
		if _progress_t > STUCK and (pl.on_floor or pl.climbing):
			state = "plan"
		return _v2_pad(pl)
	# Progress: further right (v2's), or by route a move nearer the goal.
	var d: int = int(field.at(pl.position)) if field != null else 0
	if (pl.position.x > _best_x + 8.0 if field == null else d < _best_d) or _wait > 0.0:
		_best_x = maxf(_best_x, pl.position.x)
		_best_d = mini(_best_d, d)
		_progress_t = 0.0   # (waiting for a moving ledge is progress)
	else:
		_progress_t += dt
	if _progress_t > STUCK:
		if debug:
			print("  bot: stuck at %s" % pl.position)
		state = "plan"
		return {}
	# The action ends as the sim's did: landed, or caught a vine.
	var started_climb: bool = bool(_act.get("vine", false))
	var t_end := Reach.SIM_TIME + (float(_act.get("t", 0.0)) if started_climb else 0.0)
	if started_climb and not pl.climbing:
		_st["left"] = true
	if _t > 0.0:
		var landed: bool = pl.on_floor and (_st.get("left", false) or (not started_climb and not _act.get("jump", false) and _t >= float(_act.get("walk", 0.0))))
		var caught: bool = pl.climbing and (_st.get("left", false) or not started_climb)
		# (a tall level's fall runs on past t_end while he's still falling, as its sims did)
		var falling: bool = Reach.still_falling(pl) and _t < t_end + Reach.fall_extra(world.level)
		if landed or caught or (_t >= t_end and not falling):
			var want = _route[_step]["to"]
			var got := Reach.key_of(pl.position, pl.climbing)
			if want != null and (absi(got.x - want.x) > 1 or got.y != want.y or got.z != want.z):
				if debug:
					print("  bot: off the plan at step %d/%d: want %s got %s (pos %s) after %s" % [_step, _route.size(), want, got, pl.position, _act])
				state = "plan"   # off the plan: plan again from here
				return {}
			return _next(pl)
	if not pl.on_floor and not pl.climbing:
		_st["left"] = true
	return _drive(pl)


var _last_held := {}


func _drive(pl: Node2D) -> Dictionary:
	if _settle >= 0.0:
		# Come to rest first, as every sim starts: the route's landings then
		# match (a carried run-up would overshoot a 0.22 s walk).
		_settle += DT
		if ((pl.climbing or (pl.on_floor and absf(pl.velocity.x) < 1.0)) and float(pl.hurt_time) >= 0.25) or _settle > 0.6:
			_settle = -1.0
			_wait = 0.0
		else:
			_last_held = {}
			return {}
	if _t == 0.0 and _live != null and _mover_near(pl) and not _timed_ok(pl):
		# Wait for the moving ledge to come round (a few seconds at most).
		_wait += DT
		if _wait > 8.0:
			_wait = 0.0
			state = "plan"
		_last_held = {}
		return {}
	if _t == 0.0 and _live != null and not _mover_near(pl) and not _timed_ok(pl):
		# Started from where he really is (a landing a few px off the sim's),
		# this action would miss (a walk off a pit's edge): plan again from
		# here, where the first action is simulated from this very spot.
		if debug:
			print("  bot: step %d would miss from %s: plan again" % [_step, pl.position])
		state = "plan"
		_last_held = {}
		return {}
	var held := Reach.action_pad(_act, _t, _st)
	if _t == 0.0 and held.get("jump", false) and _last_held.get("jump", false):
		# The World reads a press from the held state: let go for a tick first.
		held["jump"] = false
		_last_held = held
		return held
	if world.hitstop <= 0.0:
		_t += DT
	# Swing at what's in front on the way (it doesn't move him).
	held["attack"] = (_i / 12) % 2 == 0 and (_enemy_ahead(pl) or _breakable_ahead(pl))
	_last_held = held
	return held


func _mover_near(pl: Node2D) -> bool:
	for m in world.movers:
		if absf(float(m.pos.x) - pl.position.x) < 10.0 * TILE:
			return true
	return false


func _timed_ok(pl: Node2D) -> bool:
	## Would this action, started now, land where the plan says, with the
	## moving ledges where they'll really be? (One sim a tick while waiting.)
	var want = _route[_step]["to"]
	if want == null:
		return true
	_live.bw.movers = []
	for m in world.movers:
		_live.bw.movers.append(Movers.clone(m))
	_live.live_t0 = float(world.ftime) + DT
	var node := {"pos": pl.position, "climb": pl.climbing, "col": pl.climb_col, "carry": {}, "dmax": {}}
	var r: Dictionary = _live.simulate(node, _act)
	if not r["ok"]:
		return false
	var got := Reach.key_of(r["pos"], r["climb"])
	if absi(got.x - want.x) <= 1 and got.y == want.y and got.z == want.z:
		return true
	# Onto (or off) a moving ledge: any safe landing that gets on is good
	# enough (it plans again from there): two tiles on toward the goal, by
	# route two moves nearer it (a lift's ride up a tower).
	if field != null:
		return (r["riding"] or pl.riding != null) and int(field.at(r["pos"])) <= int(field.at(pl.position)) - 2
	var dir := signf(goal["p"].x - pl.position.x)
	return (r["riding"] or pl.riding != null) and (r["pos"].x - pl.position.x) * dir >= 2.0 * TILE


func _breakable_ahead(pl: Node2D) -> bool:
	## A cracked brick or false stone in the way (the plan went through it:
	## the static copy has them open): swing at it.
	var lv: RefCounted = world.level
	var x0 := floori((pl.position.x + (8.0 if pl.facing > 0 else -44.0)) / TILE)
	var x1 := floori((pl.position.x + (44.0 if pl.facing > 0 else -8.0)) / TILE)
	for x in range(x0, x1 + 1):
		for y in range(floori((pl.position.y - 44.0) / TILE), floori((pl.position.y - 1.0) / TILE) + 1):
			if LevelData.is_breakable(lv.tile(x, y)):
				return true
	return false


func _enemy_ahead(pl: Node2D) -> bool:
	var r := Rect2(pl.position.x + (0.0 if pl.facing > 0 else -70.0), pl.position.y - 50.0, 70.0, 56.0)
	for e in world.enemies:
		if e.alive and e.active and e.rect().intersects(r):
			return true
	# A restless level's remains (twists.gd): strike them as it passes, so they stay down.
	var tw = world.get("twists")
	return tw != null and tw.has_method("remains_in") and tw.remains_in(r)


# ---------------------------------------------------------------- the boss

func _fight_pad(pl: Node2D) -> Dictionary:
	var b = world.boss
	# A boss that knows its own fight (the Saint, the Hush and its finale:
	# BB's bot_pad) plays it while it's alive; else v2's crude pad.
	if b != null and is_instance_valid(b) and b.alive and b.has_method("bot_pad"):
		var bp: Dictionary = b.bot_pad(pl)
		if not bp.is_empty():
			return bp
	var pd := {"attack": (_i / 20) % 2 == 0}
	if b == null or not is_instance_valid(b) or not b.alive:
		# The boss's bell comes down in the arena's middle 1.2 s after it
		# falls. Behind him: back to its rope (v2's bot held right and stood
		# at the right wall for good when the boss fell right of the middle:
		# a Descent echo depth never went on). Ahead, v2's way: right, hopping.
		pd["jump"] = (_i / 60) % 3 == 0
		for bell in world.bells:
			if not bool(bell["rung"]) and (bell["rope"] as Rect2).get_center().x < pl.position.x - 6.0:
				pd["left"] = true
				return pd
		pd["right"] = true
		return pd
	var dx: float = b.position.x - pl.position.x
	if absf(dx) > 40.0:
		pd["right" if dx > 0.0 else "left"] = true
	pd["jump"] = (_i / 50) % 3 == 0
	pd["special"] = (_i / 90) % 4 == 0
	return pd


func _room_pad(pl: Node2D) -> Dictionary:
	## A shut fight room: the first feature module whose bot_target(pl) names
	## one (secrets.gd: a secret level's Warden awake in its sealed room;
	## sealed.gd: a duel's, an ambush's or a hold's nearest foe, or where to
	## wait while they drop in). Toward it, swinging, hopping its blows; once
	## the room opens the plan goes on from where he stands (to the silver
	## bell rising at a secret level's S, or the level's bell). {} otherwise.
	## In a tall level a foe on the room's other deck (DECK or more over or
	## under him) is planned to instead (_room_plan: {} while the planner
	## drives).
	var f = world.get("features")
	var mods = f.get("modules") if f != null else null
	if not (mods is Array):
		return {}
	var target = null
	for m in mods:
		if m != null and m.has_method("bot_target"):
			target = m.bot_target(pl)
			if target != null:
				break
	if target == null:
		if goal.get("room", false):
			_end_room_goal()
		return {}
	var at: Vector2 = (target as Node2D).position if target is Node2D else target
	# (planning to a deck goes on till he stands on it: mid-jump under it the
	# foe is near enough, but the crude pad would only steer him under it)
	var going: bool = goal.get("room", false) and not (pl.on_floor and absf(pl.position.y - (goal["p"] as Vector2).y) < TILE)
	if world.level.tall() and (absf(at.y - pl.position.y) > DECK or going):
		return _room_plan(at)
	if goal.get("room", false):
		_end_room_goal()
	_search = null
	_route = []
	state = "plan"
	var pd := {"attack": (_i / 20) % 2 == 0}
	var dx: float = at.x - pl.position.x
	if absf(dx) > 36.0:
		pd["right" if dx > 0.0 else "left"] = true
	# Under a foe over his head: jump again and again (a held jump is one
	# press; it stood under a Flit for good).
	pd["jump"] = (_i / 50) % 3 == 0 or (at.y < pl.position.y - 48.0 and absf(dx) < 96.0 and (_i / 12) % 2 == 0)
	pd["special"] = (_i / 90) % 4 == 0
	return pd


func _room_plan(at: Vector2) -> Dictionary:
	## A shut room's foe on the other deck: the floor under it as the goal
	## (the level's goal kept for after), planned on the level as it is, its
	## doors shut (a static copy of it now: the plan never leaves the room by
	## a door that's stone), by its own route field. Again when the foe has
	## gone to another floor, or, between routes, walked off along this one.
	## {}: the planner drives (pad's plan and follow).
	var foot := _floor_under(at)
	var moved: bool = not goal.get("room", false) or absf((goal["p"] as Vector2).y - foot.y) > 1.0 \
			or (state == "plan" and (goal["p"] as Vector2).distance_to(foot) > 3.0 * TILE)
	if moved:
		if not goal.get("room", false):
			_level_goal = goal
			_level_field = field
		_room_static = Reach.static_copy(world.level)
		goal = {"what": "room foe", "p": foot, "rope": true, "rect": Rect2(foot.x - 48.0, foot.y - 8.0, 96.0, 8.0), "room": true}
		field = RouteField.new().build(_room_static, goal, Reach.drops_of(world.level))
		_search = null
		_route = []
		state = "plan"
	return {}


func _end_room_goal() -> void:
	## Back to the level's goal (the room opened, or its foe came to his deck).
	goal = _level_goal
	field = _level_field
	_level_goal = {}
	_level_field = null
	_room_static = null
	_search = null
	_route = []
	state = "plan"


func _floor_under(at: Vector2) -> Vector2:
	## The first floor at or under a point (its top, mid-cell): where to stand under it.
	var lv: RefCounted = world.level
	var cx := floori(at.x / TILE)
	for y in range(maxi(floori((at.y - 1.0) / TILE), 0), lv.height):
		if not LevelData.is_solid(lv.tile(cx, y)) and LevelData.is_floor(lv.tile(cx, y + 1)):
			return LevelData.cell_floor(Vector2i(cx, y))
	return at


func _v2_pad(pl: Node2D = null) -> Dictionary:
	if by_route and field != null and pl != null:
		return _route_pad(pl)
	return {"right": true, "jump": (_i / 60) % 3 == 0, "attack": (_i / 20) % 2 == 0, "special": (_i / 90) % 4 == 0}


func _heading(pl: Node2D) -> Vector2i:
	## Which way the goal lies by the way there (route_field.gd heading); with
	## no way from here, toward it as the crow flies.
	var hd: Vector2i = field.heading(pl.position) if field != null else Vector2i.ZERO
	if hd == Vector2i.ZERO and not goal.is_empty():
		var dp: Vector2 = (goal["p"] as Vector2) - pl.position
		hd = Vector2i(int(signf(dp.x)) if absf(dp.x) > 8.0 else 0, int(signf(dp.y)) if absf(dp.y) > 16.0 else 0)
	return hd


func _route_pad(pl: Node2D) -> Dictionary:
	## v2's fallback pad down the route field (by route): toward where the
	## way to the goal goes, jumping now and then (often, while the way goes
	## up), climbing a vine while it goes up, sliding while it goes down,
	## and dropping through a ledge where the way goes straight down.
	var hd := _heading(pl)
	var pd := {"attack": (_i / 20) % 2 == 0, "special": (_i / 90) % 4 == 0}
	if hd.x != 0:
		pd["right" if hd.x > 0 else "left"] = true
	if pl.climbing:
		pd["up" if hd.y < 0 else "down"] = hd.y != 0
		pd["jump"] = hd.y >= 0 and hd.x != 0 and (_i / 30) % 2 == 0   # (a leap off, the way it goes)
		return pd
	pd["jump"] = (_i / (20 if hd.y < 0 else 60)) % 3 == 0
	if hd.x == 0 and hd.y > 0 and pl.on_floor:
		pd["down"] = true   # (down + jump: through a one-way ledge; a taller level's pure down only looks down)
		pd["jump"] = (_i / 6) % 2 == 0
	return pd
