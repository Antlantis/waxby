extends RefCounted
## The --autoplay bot at the controls (debug builds, for checking a build on
## the phone): it plans a route to the level's goal with the reachability
## engine (reach_search.gd, greedy: nearest the goal first) on the level's
## static copy, then plays the route's pads, action by action. When where it
## lands isn't where the plan said (a monster's knock, a crumble, a moving
## ledge's timing), it plans again from there. It swings at whatever is in
## front of it as it goes. At a boss (the arena reached) it fights as v2's bot
## did: toward him, swinging, hopping his waves. It plans a few sims a tick,
## so a route never stalls a frame; while it plans it stands still.
##
## v2's bot only held right and jumped every second: it stood forever at the
## 4-tile wall at x 406 on 2-4 (the owner saw it on the phone).

const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
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
			# Warden falls (features/secrets.gd); the fight is _warden_pad's.
			goal = g
	if goal.is_empty() and not goals.is_empty():
		goal = goals[goals.size() - 1]
	if w.get("mode") != null and not goal.is_empty():
		# A mode's room (a Descent depth): an altar within a plan's reach of
		# where he stands (the landing's), first, so the run lights it (its
		# Glimmers, its relight) as a player walking in would; the route
		# passes the others. The story's levels keep v2's route.
		_final = goal
		_to_altar()


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
		return _v2_pad()
	var wp := _warden_pad(pl)
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
		_search.setup(_static, pl.position, {"mode": "greedy", "target": goal["p"], "stop_on": goal["what"],
				"goals": [goal], "cap": PLAN_CAP, "start_climb": pl.climbing, "stop_x": pl.position.x + dir * HORIZON})
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
		return _v2_pad()
	var path: Array = s.path_to(end_node)
	if debug:
		print("  bot: plan %d from %s: %s, %d states, route %d" % [plans, pl.position, "goal" if not hit.is_empty() else "best", s.seen.size(), path.size() - 1])
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
		return _v2_pad()
	if pl.position.x > _best_x + 8.0 or _wait > 0.0:
		_best_x = maxf(_best_x, pl.position.x)
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
		if landed or caught or _t >= t_end:
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
	# enough (it plans again from there).
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
	return false


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


func _warden_pad(pl: Node2D) -> Dictionary:
	## A secret level's Warden awake in its sealed room (features/secrets.gd:
	## phase "fight"): toward it, swinging, hopping its blows; once it falls
	## the plan goes on to the silver bell rising at the S. {} otherwise.
	var f = world.get("features")
	var sm = f.by_name.get("secrets") if f != null and f.get("by_name") != null else null
	if sm == null or not bool(sm.get("secret_level")) or str(sm.get("phase")) != "fight":
		return {}
	var wd = sm.get("warden")
	if wd == null or not is_instance_valid(wd) or not wd.alive or bool(sm.get("dormant")):
		return {}
	_search = null
	_route = []
	state = "plan"
	var pd := {"attack": (_i / 20) % 2 == 0}
	var dx: float = wd.position.x - pl.position.x
	if absf(dx) > 36.0:
		pd["right" if dx > 0.0 else "left"] = true
	pd["jump"] = (_i / 50) % 3 == 0 or (wd.position.y < pl.position.y - 48.0 and absf(dx) < 96.0)
	pd["special"] = (_i / 90) % 4 == 0
	return pd


func _v2_pad() -> Dictionary:
	return {"right": true, "jump": (_i / 60) % 3 == 0, "attack": (_i / 20) % 2 == 0, "special": (_i / 90) % 4 == 0}
