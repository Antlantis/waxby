extends RefCounted
## One search over a (static) level with the reachability engine
## (reach.gd): mode "bfs" (every state, in order; the tests) or "greedy"
## (nearest the target first, stopping at a goal: the autoplay bot's route).
## setup(level, start, opts) then run(max_sims, budget_ms) until it returns
## true (it can be spread over frames). found: goal what -> {node, action,
## dmax}; path_to(node) walks the route back; capped means STATE_CAP was hit.

const Reach := preload("res://scripts/reach.gd")
const LevelData := preload("res://scripts/level_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const TILE := 32
const DT := 1.0 / 120.0
const SIM_TIME := 2.2
const GUST_PUSH := 120.0

## One search over a (static) level. mode "bfs" (every state, in order)
## or "greedy" (nearest the target x first: the autoplay bot's route).
var lv: RefCounted
var goals: Array = []
var push := false             # the gust pass
var mode := "bfs"
var target := Vector2.ZERO    # greedy: where to head
var stop_on := ""             # greedy: stop once this goal is found
var stop_x := NAN             # greedy: ...or once a state gets past this x (toward target.x)
var best := 0                 # greedy: the state nearest the target so far
var _stop_dir := 0.0
var live_t0 := NAN            # a live check: bw.movers move from this ftime on (the autoplay's timing)
var cap := Reach.STATE_CAP
var p: Node2D
var bw
var nodes: Array = []         # {pos, climb, col, parent, action, carry, dmax}
var seen := {}                # key -> node index
var queue: Array = []         # bfs: node indices; greedy: [prio, idx] heap
var qi := 0
var found := {}               # goal what -> {node, dmax}
var touched := {}             # extra targets (buoys, lamps): name -> true
var touch_rects := {}         # name -> Rect2
var sims := 0
var capped := false
var done := false
var _timed := {}
var _floor_actions := []
var _vine_actions := []
var _cur := -1                # the state being expanded (run() stopped halfway through it), or -1
var _cur_a := 0               # ...and its next action

func setup(level: RefCounted, start: Vector2, opts := {}) -> void:
	lv = level
	goals = opts.get("goals", Reach.goals_of(level))
	push = opts.get("push", false)
	mode = str(opts.get("mode", "bfs"))
	target = opts.get("target", Vector2.ZERO)
	stop_on = str(opts.get("stop_on", ""))
	stop_x = float(opts.get("stop_x", NAN))
	_stop_dir = signf(target.x - start.x)
	cap = int(opts.get("cap", Reach.STATE_CAP))
	touch_rects = opts.get("touch", {})
	_timed = opts.get("timed", {})
	_floor_actions = Reach.floor_actions()
	_vine_actions = Reach.vine_actions()
	bw = Reach.BotWorld.new()
	bw.level = lv
	bw.rotten_hold = float(opts.get("rotten_hold", Reach.ROTTEN_HOLD))
	p = PlayerScript.new()
	p.level = lv
	p.world = bw
	var climb := bool(opts.get("start_climb", false))
	_add(start, climb, floori(start.x / TILE), -1, {}, {}, {})

func free_player() -> void:
	if p != null:
		p.free()
		p = null

func _add(pos: Vector2, climb: bool, col: int, parent: int, action: Dictionary, carry: Dictionary, dmax: Dictionary) -> void:
	var k := Reach.key_of(pos, climb)
	if seen.has(k):
		return
	if seen.size() >= cap:
		capped = true
		return
	var idx := nodes.size()
	nodes.append({"pos": pos, "climb": climb, "col": col, "parent": parent, "action": action, "carry": carry, "dmax": dmax})
	seen[k] = idx
	if mode == "greedy":
		var prio := _prio(pos)
		_heap_push([prio, idx])
		if prio < _prio(nodes[best]["pos"]):
			best = idx
		if not is_nan(stop_x) and (pos.x - stop_x) * _stop_dir >= 0.0:
			done = true
	else:
		queue.append(idx)


func _prio(pos: Vector2) -> float:
	return absf(pos.x - target.x) + 0.5 * absf(pos.y - target.y)

func run(max_sims := 1 << 30, budget_ms := 1 << 30, budget_us := 0) -> bool:
	## Search on; true once it's finished (every state tried, the cap hit,
	## or the greedy goal found). budget_us > 0 stops as soon as that much
	## time is spent, even halfway through a state's actions (the --autoplay
	## bot's plan on a device: one sim costs 0.5-3 ms, a state's 11 of them
	## up to 18 ms, a frame's worth); the next call carries on where it
	## stopped, so the sims run in exactly the same order either way.
	var t0 := Time.get_ticks_msec()
	var u0 := Time.get_ticks_usec()
	var n0 := sims
	while not done:
		if capped:
			done = true
			break
		if _cur < 0:
			var idx := _pop()
			if idx < 0:
				done = true
				break
			_cur = idx
			_cur_a = 0
		var node: Dictionary = nodes[_cur]
		var acts: Array = _vine_actions if node["climb"] else _floor_actions
		var out_of_time := false
		while _cur_a < acts.size():
			_expand(_cur, node, acts[_cur_a])
			_cur_a += 1
			if done:
				break
			if budget_us > 0 and Time.get_ticks_usec() - u0 >= budget_us:
				out_of_time = true
				break
		if done or _cur_a >= acts.size():
			_cur = -1
		if stop_on != "" and found.has(stop_on):
			done = true
		if out_of_time or sims - n0 >= max_sims or Time.get_ticks_msec() - t0 >= budget_ms:
			break
	return done

func _pop() -> int:
	if mode == "greedy":
		if queue.is_empty():
			return -1
		return int(_heap_pop()[1])
	if qi >= queue.size():
		return -1
	qi += 1
	return int(queue[qi - 1])

func _expand(idx: int, node: Dictionary, a: Dictionary) -> void:
	sims += 1
	var r := simulate(node, a)
	for what in r["found"]:
		if not found.has(what):
			found[what] = {"node": idx, "action": a, "dmax": r["found"][what]}
	for name in r["touched"]:
		touched[name] = true
	if r["ok"]:
		_add(r["pos"], r["climb"], r["col"], idx, a, r["carry"], r["dmax"])

func simulate(node: Dictionary, a: Dictionary, record := false) -> Dictionary:
	## One action from a state. {ok, pos, climb, col, found: {what: dmax},
	## touched: [], carry, dmax, pads (with record)}.
	p.reset_at(node["pos"])
	bw.reset()
	var from_climb: bool = node["climb"]
	if from_climb:
		p.grab_vine(int(node["col"]), 1.0)
	else:
		p.on_floor = true
	var st := {}
	var prev := {}
	var t := 0.0
	var left := false
	var ok := true
	var carry: Dictionary = (node["carry"] as Dictionary).duplicate()
	var dmax: Dictionary = (node["dmax"] as Dictionary).duplicate()
	var hits := {}
	var touched_now := []
	var pads := []
	var t_end := SIM_TIME + (float(a.get("t", 0.0)) if a.get("vine", false) else 0.0)
	var live := not is_nan(live_t0)
	while t < t_end:
		if live:
			for m in bw.movers:
				m.update(live_t0 + t, DT)
		var held := Reach.action_pad(a, t, st)
		var pd := held.duplicate()
		for k in ["jump", "attack"]:
			var now: bool = held.get(k, false)
			pd[k + "_pressed"] = now and not prev.get(k, false)
			prev[k] = now
		if record:
			pads.append(held)
		if push:
			p.push = Vector2(_gust_push(p), 0.0)
		p.pad = pd
		p.step(DT)
		bw.ftime += DT
		t += DT
		var r: Rect2 = p.rect()
		for g in goals:
			if hits.has(g["what"]):
				continue
			var got: bool = r.intersects(g["rect"]) if g["rope"] else r.grow(6.0).has_point(g["p"])
			if got:
				hits[g["what"]] = _merge_max(dmax, {})
		for name in touch_rects:
			if r.intersects(touch_rects[name]):
				touched_now.append(name)
		_dwell(carry, dmax)
		if Reach.hurts(lv, r) or p.position.y > lv.height * TILE + 40:
			ok = false
			break
		if from_climb and not left and not p.climbing:
			left = true   # off the vine (leapt, mounted, dropped)
		if p.climbing and (left or not from_climb):
			break         # caught a vine
		if not p.on_floor and not p.climbing and p.ledge_t < 0.0:
			left = true
		elif p.on_floor and (left or (not from_climb and not a.get("jump", false) and t >= float(a.get("walk", 0.0)))):
			break
	var out := {"ok": ok and (p.on_floor or p.climbing), "pos": p.position, "climb": p.climbing, "col": p.climb_col,
			"found": hits, "touched": touched_now, "carry": carry, "dmax": dmax, "riding": p.riding != null}
	if record:
		out["pads"] = pads
	return out

func _gust_push(pl: Node2D) -> float:
	if pl.climbing or pl.ledge_t >= 0.0:
		return 0.0
	var x := floori(pl.center().x / TILE)
	for g in lv.gusts:
		if x >= int(g["x0"]) and x <= int(g["x1"]):
			return float(g["dir"]) * (GUST_PUSH * 0.5 if pl.on_floor else GUST_PUSH)
	return 0.0

func _dwell(carry: Dictionary, dmax: Dictionary) -> void:
	if _timed.is_empty():
		return
	var kind := ""
	if p.climbing:
		kind = str(_timed.get(Vector2i(p.climb_col, floori(p.center().y / TILE)), ""))
	elif p.on_floor:
		var r: Rect2 = p.rect()
		var ty := floori((p.position.y + 1.0) / TILE)
		for tx in range(floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE) + 1):
			var k2 := str(_timed.get(Vector2i(tx, ty), ""))
			if k2 != "":
				kind = k2
				break
	for k in carry.keys():
		if k != kind:
			carry.erase(k)
	if kind != "":
		carry[kind] = float(carry.get(kind, 0.0)) + DT
		dmax[kind] = maxf(float(dmax.get(kind, 0.0)), float(carry[kind]))

func path_to(idx: int) -> Array:
	## [node indices] from the start to idx.
	var out := []
	while idx >= 0:
		out.push_front(idx)
		idx = int(nodes[idx]["parent"])
	return out

static func _merge_max(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = maxf(float(out.get(k, 0.0)), float(b[k]))
	return out

func _heap_push(item: Array) -> void:
	queue.append(item)
	var i := queue.size() - 1
	while i > 0:
		var par := (i - 1) / 2
		if float(queue[par][0]) <= float(queue[i][0]):
			break
		var tmp = queue[par]
		queue[par] = queue[i]
		queue[i] = tmp
		i = par

func _heap_pop() -> Array:
	var top: Array = queue[0]
	var last: Array = queue.pop_back()
	if not queue.is_empty():
		queue[0] = last
		var i := 0
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < queue.size() and float(queue[l][0]) < float(queue[m][0]):
				m = l
			if r < queue.size() and float(queue[r][0]) < float(queue[m][0]):
				m = r
			if m == i:
				break
			var tmp = queue[m]
			queue[m] = queue[i]
			queue[i] = tmp
			i = m
	return top
