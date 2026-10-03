extends SceneTree
## (WLS's recorder, adopted at the track B merge: re-record 4-S / 5-S when
## clockwork.gd or glass.gd timing changes.)
##   godot --headless --path game --script res://../tools/route_dfs.gd -- 4-S --max=300 --out=game/tests/routes/4-S.json
## Play a level headless (no monsters) to its silver bell by a live depth-first
## search: from Wick's real state, try the reach engine's actions in one continuous run of
## his physics on the real tiles with the real movers cloned (the gusts only in calm air, a
## weight's bob a hurt), until a foothold he may wait on (stone, a plain ledge, a sound vine,
## a cog tooth, a swing, a moving ledge: never a float, glass or a crumble) nearer the goal;
## play those pads; if none, wait on the foothold and look again. Writes a golden route.
##   -- <id> [--out=path] [--touch=x,y;x,y] [--max=400] [--debug] [--note=...] [--depth=4]
const LevelData := preload("res://scripts/level_data.gd")
const Reach := preload("res://scripts/reach.gd")
const Movers := preload("res://scripts/movers.gd")
const Route := preload("res://scripts/route.gd")
const PlayerScript := preload("res://scripts/player.gd")
const DT := 1.0 / 120.0
var w: Node2D
var masks: Array = []
var debug := false
var orig_lv: RefCounted
var sp: Node2D
var bw
var glass = null
var weights: Array = []
var weight_period := 3.216
var goal_rect := Rect2()
var goal_is_touch := false
var _sims := 0
var budget := 4000
var max_depth := 4
var cur: RefCounted
var orchard = null
var static_lv: RefCounted
var guide := Vector2.INF       # a spot on the static plan to make for (out of a dead end)
var guides: Array = []


class SimWorld:
	## What the sim's Wick asks the World: the real rotten runs and crumbles,
	## carried forward in sim time from the root (the real ftime t0).
	extends RefCounted
	var ftime := 0.0
	var movers: Array = []
	var level: RefCounted
	var t0 := 0.0
	var orchard = null
	var hold := 1.4
	var crumb := {}
	var rot := {}
	func reset() -> void:
		pass
	func vine_present(x: int, y: int) -> bool:
		var t: int = level.tile(x, y)
		if t != 12 and t != 13:
			return false
		if t == 12 or orchard == null:
			return true
		var i = orchard._run_of.get(Vector2i(x, y))
		if i == null:
			return true
		var r: Dictionary = orchard.runs[i]
		var now := t0 + ftime
		match str(r["state"]):
			"held":
				return now - float(r["t"]) < hold
			"snapped", "regrow":
				return false
		if rot.has(i):
			return ftime - float(rot[i]) < hold
		return true
	func touch_rotten(x: int, y: int) -> void:
		if orchard == null:
			return
		var i = orchard._run_of.get(Vector2i(x, y))
		if i != null and str(orchard.runs[i]["state"]) == "idle" and not rot.has(i):
			rot[i] = ftime
	func ledge_present(x: int, y: int) -> bool:
		var c = crumb.get(Vector2i(x, y))
		return c == null or str(c["state"]) != "fallen"
	func stood_on(_who, x: int, y: int) -> void:
		var cell := Vector2i(x, y)
		if crumb.has(cell) and str(crumb[cell]["state"]) == "idle":
			var cx := x
			while crumb.has(Vector2i(cx - 1, y)):
				cx -= 1
			while crumb.has(Vector2i(cx, y)):
				if str(crumb[Vector2i(cx, y)]["state"]) == "idle":
					crumb[Vector2i(cx, y)] = {"state": "shake", "timer": 0.55}
				cx += 1
	func step_crumbles(dt: float) -> void:
		for c in crumb:
			var d: Dictionary = crumb[c]
			if str(d["state"]) == "idle":
				continue
			d["timer"] = float(d["timer"]) - dt
			if str(d["state"]) == "shake" and float(d["timer"]) <= 0.0:
				d["state"] = "fallen"
				d["timer"] = 3.5
			elif str(d["state"]) == "fallen" and float(d["timer"]) <= 0.0:
				d["state"] = "idle"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0]
	var opts := {}
	for a in args.slice(1):
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	debug = opts.has("debug")
	max_depth = int(opts.get("depth", "4"))
	var game = root.get_node("Game")
	game.save_path = "user://wls_dfs_%s.json" % id
	game.slot_base = "user://wls_dfs_%s" % id
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	var route := {"calling": str(opts.get("calling", "knight")), "diff": str(opts.get("diff", "dusk"))}
	Route.prepare(game, route, lv)
	w = load("res://scripts/world.gd").new()
	w.setup(lv, true)
	w.no_monsters = true
	w.paused = true
	root.add_child(w)
	await process_frame
	orig_lv = LevelData.load_file("res://levels/%s.txt" % id)
	static_lv = Reach.static_copy(orig_lv)
	bw = SimWorld.new()
	orchard = w.features.module("orchard")
	bw.orchard = orchard
	if orchard != null:
		bw.hold = orchard.knob("rotten_hold")
	sp = PlayerScript.new()
	sp.world = bw
	glass = w.features.module("glass")
	if glass != null and (glass.zones as Array).is_empty():
		glass = null
	var cw = w.features.module("clockwork")
	if cw != null:
		weights = cw.weights
		weight_period = cw.knob("weight_period")
	var waypoints: Array = []
	if opts.has("touch"):
		for part in str(opts["touch"]).split(";"):
			var xy := part.split(",")
			var c := Vector2i(int(xy[0]), int(xy[1]))
			var pos := LevelData.cell_center(c)
			waypoints.append({"what": "touch", "rect": Rect2(pos - Vector2(16, 24), Vector2(32, 32))})
	for g in Reach.goals_of(lv):
		if g["what"] == str(opts.get("goal", "silver bell")):
			waypoints.append({"what": g["what"], "rect": g["rect"] if g.has("rect") else Rect2(g["p"] - Vector2(6, 6), Vector2(12, 12))})
	var maxt := int(float(opts.get("max", "400")) / DT)
	var wi := 0
	var t0 := Time.get_ticks_msec()
	var stuck := 0
	while masks.size() < maxt and w.state == "play" and w.snuffs == 0:
		var wp: Dictionary = waypoints[mini(wi, waypoints.size() - 1)]
		goal_rect = wp["rect"]
		goal_is_touch = wp["what"] == "touch"
		if goal_is_touch and goal_rect.intersects(w.player.rect()):
			print("  touched the waypoint at t=%.1f" % (masks.size() * DT))
			wi += 1
			continue
		if not (w.player.on_floor or w.player.climbing):
			_tick({})
			if debug and masks.size() % 1200 == 0:
				print("  airborne at %s v %s riding %s" % [w.player.position, w.player.velocity, w.player.riding])
			continue
		cur = _cur_level()
		_sims = 0
		var pads = _dfs(_snap_root(), 0)
		if pads == null:
			if not _waitable():
				if debug:
					print("  nothing from %s (not a foothold, %d sims)" % [w.player.position, _sims])
				_tick({})
			else:
				for i in 6:
					_tick({})
				stuck += 6
				if stuck >= 240 and guides.is_empty():
					guides = _guide_spots()
					guide = guides[0] if not guides.is_empty() else Vector2.INF
					if debug:
						print("  a dead end at %s: following the static plan by %d footholds" % [w.player.position, guides.size()])
				if debug and stuck % 600 == 0:
					print("  waiting at %s (%.1f s)" % [w.player.position, stuck * DT])
			continue
		stuck = 0
		if debug and OS.get_environment("DFS_TRACE") != "":
			print("  at %s: %d pads (%d sims)" % [w.player.position, (pads as Array).size(), _sims])
		if guide != Vector2.INF and w.player.position.distance_to(guide) < 60.0:
			pass
		for pd in pads:
			var q: Dictionary = (pd as Dictionary).duplicate()
			if _breakable_ahead():
				q["attack"] = (masks.size() / 10) % 2 == 0
			_tick(q)
			if w.state != "play":
				break
		if guide != Vector2.INF and w.player.position.distance_to(guide) < 48.0:
			guides.pop_front()
			guide = guides[0] if not guides.is_empty() else Vector2.INF
	for i in 420:
		_tick({})
	var ok: bool = w.state == "clear" and w.snuffs == 0
	print("%s: %s after %.1f s (%d ticks), snuffs %d, %d ms" % [id, w.state, masks.size() * DT, masks.size(), w.snuffs, Time.get_ticks_msec() - t0])
	if ok and opts.has("out"):
		var out := {"level": id, "calling": route["calling"], "diff": route["diff"], "hero_level": int(game.hero()["level"]),
			"ticks": masks.size(), "runs": Route.encode(masks), "end": {"x": roundi(w.player.position.x), "state": w.state},
			"note": str(opts.get("note", ""))}
		Route.save(str(opts["out"]), out)
		print("wrote ", opts["out"])
	sp.free()
	quit(0 if ok else 1)


func _tick(pad: Dictionary) -> void:
	w.test_pad = pad
	w._read_pad()
	masks.append(Route.mask(w._pad))
	w.tick(DT)


func _guide_spots() -> Array:
	## Footholds along the static plan to the goal, 3 tiles or more apart.
	var pl = w.player
	var ReachSearch = load("res://scripts/reach_search.gd")
	var s = ReachSearch.new()
	var g := {"what": "goal", "p": goal_rect.get_center(), "rope": true, "rect": goal_rect}
	s.setup(static_lv, pl.position, {"goals": [g], "stop_on": "goal", "start_climb": pl.climbing})
	s.run()
	var out := []
	if s.found.has("goal"):
		var path: Array = s.path_to(int(s.found["goal"]["node"]))
		var last: Vector2 = pl.position
		for k in range(1, path.size()):
			var p: Vector2 = s.nodes[path[k]]["pos"]
			if p.distance_to(last) >= 3.0 * 32.0 and _safe(p, bool(s.nodes[path[k]]["climb"]), true, null):
				out.append(p)
				last = p
			if out.size() >= 12:
				break
	s.free_player()
	return out


func _guide_spot() -> Vector2:
	## The static plan's footholds toward the goal: the first one 5 tiles or
	## more from here (the way on out of a dead end, which may go back first).
	var pl = w.player
	var ReachSearch = load("res://scripts/reach_search.gd")
	var s = ReachSearch.new()
	var g := {"what": "goal", "p": goal_rect.get_center(), "rope": true, "rect": goal_rect}
	s.setup(static_lv, pl.position, {"goals": [g], "stop_on": "goal", "start_climb": pl.climbing})
	s.run()
	var out := Vector2.INF
	if s.found.has("goal"):
		var path: Array = s.path_to(int(s.found["goal"]["node"]))
		for k in range(1, path.size()):
			var p: Vector2 = s.nodes[path[k]]["pos"]
			if p.distance_to(pl.position) >= 5.0 * 32.0:
				out = p
				break
	s.free_player()
	return out


func _breakable_ahead() -> bool:
	## A cracked brick or false stone in his way (the sims walk through them): swing.
	var pl = w.player
	var lv: RefCounted = w.level
	var x0 := floori((pl.position.x + (8.0 if pl.facing > 0 else -44.0)) / 32.0)
	var x1 := floori((pl.position.x + (44.0 if pl.facing > 0 else -8.0)) / 32.0)
	for x in range(x0, x1 + 1):
		for y in range(floori((pl.position.y - 44.0) / 32.0), floori((pl.position.y - 1.0) / 32.0) + 1):
			if LevelData.is_breakable(lv.tile(x, y)):
				return true
	return false


func _cur_level() -> RefCounted:
	var c = LevelData.new()
	c.id = w.level.id
	c.width = w.level.width
	c.height = w.level.height
	c.tiles = w.level.tiles.duplicate()
	c.entities = w.level.entities
	for i in c.tiles.size():
		if c.tiles[i] == LevelData.FALSE_STONE or c.tiles[i] == LevelData.BRICK:
			c.tiles[i] = LevelData.AIR
	return c


func _waitable() -> bool:
	var pl = w.player
	if pl.riding != null:
		return str(pl.riding.kind) != "float"
	return _safe(pl.position, pl.climbing, pl.on_floor, null)


func _safe(pos: Vector2, climb: bool, floor: bool, riding) -> bool:
	if riding != null:
		return str(riding.kind) != "float"
	if climb:
		return orig_lv.tile(floori(pos.x / 32.0), floori((pos.y - 19.0) / 32.0)) == LevelData.VINE
	if not floor:
		return false
	for dx in [-8.0, 0.0, 8.0]:
		var t: int = orig_lv.tile(floori((pos.x + dx) / 32.0), floori((pos.y + 1.0) / 32.0))
		if LevelData.is_safe(t) and t != LevelData.ICE or t == LevelData.BELT_L or t == LevelData.BELT_R:
			return true
	return false


func _snap(p: Node2D) -> Dictionary:
	var out := {}
	for pr in p.get_property_list():
		if not (int(pr["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = p.get(pr["name"])
		if v is Object:
			continue
		out[pr["name"]] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	out["position"] = p.position
	return out


func _snap_root() -> Dictionary:
	var pl = w.player
	var ms := []
	for m in w.movers:
		ms.append(Movers.clone(m))
	var ride: int = w.movers.find(pl.riding) if pl.riding != null else -1
	return {"props": _snap(pl), "movers": ms, "ride": ride, "t": 0.0, "t0": float(w.ftime), "crumb": w.crumbles.duplicate(true), "rot": {},
		"prev": {"jump": bool(w._prev.get("jump", false)), "attack": bool(w._prev.get("attack", false))}, "pads": [],
		"d0": pl.position.distance_to(goal_rect.get_center())}


func _restore(state: Dictionary) -> Array:
	## The sim player and a fresh copy of the movers as they were in state.
	var ms := []
	for m in state["movers"]:
		ms.append(Movers.clone(m))
	var props: Dictionary = state["props"]
	for k in props:
		if k == "position":
			continue
		var v = props[k]
		sp.set(k, v.duplicate(true) if (v is Dictionary or v is Array) else v)
	sp.position = props["position"]
	sp.level = cur
	sp.world = bw
	bw.level = cur
	bw.movers = ms
	sp.riding = ms[int(state["ride"])] if int(state["ride"]) >= 0 and int(state["ride"]) < ms.size() else null
	bw.crumb = (state["crumb"] as Dictionary).duplicate(true)
	bw.rot = (state["rot"] as Dictionary).duplicate()
	bw.t0 = float(state["t0"])
	bw.ftime = float(state["t"])
	return ms


func _order(acts: Array, from: Vector2) -> Array:
	var gx := goal_rect.get_center().x
	var dir := signf(gx - from.x)
	var out := acts.duplicate()
	out.sort_custom(func(a, b):
		var da := 0 if int(a.get("dir", 0)) == int(dir) else (1 if int(a.get("dir", 0)) == 0 else 2)
		var db := 0 if int(b.get("dir", 0)) == int(dir) else (1 if int(b.get("dir", 0)) == 0 else 2)
		if da != db:
			return da < db
		return float(a.get("hold", a.get("t", 0.0))) > float(b.get("hold", b.get("t", 0.0))))
	return out


func _dfs(state: Dictionary, depth: int):
	if depth >= max_depth or _sims > budget:
		return null
	var props: Dictionary = state["props"]
	var climbing: bool = props.get("climbing", false)
	var acts: Array = _order(_vine_actions() if climbing else Reach.floor_actions(), props["position"])
	if not climbing:
		acts.append({"walk": 0.22, "dir": int(signf(goal_rect.get_center().x - (props["position"] as Vector2).x)), "jump": false, "short": true})
	for a in acts:
		_sims += 1
		var r = _run(state, a)
		if r == null:
			continue
		if r["goal"]:
			return r["pads"]
		var d1: float = (r["pos"] as Vector2).distance_to(goal_rect.get_center())
		if guide != Vector2.INF:
			if r["safe"] and (r["pos"] as Vector2).distance_to(guide) < 40.0:
				return r["pads"]
		elif r["safe"] and d1 < float(state["d0"]) - 24.0:
			return r["pads"]
		if not r["safe"] or depth == 0:
			r["d0"] = state["d0"]
			var sub = _dfs(r, depth + 1)
			if sub != null:
				return sub
	return null


func _vine_actions() -> Array:
	## Leap now, or climb (jump held, no direction: a direction with a fresh
	## press is a leap) or slide first, then leap: what a thumb does.
	var out := []
	for dir in [-1, 1]:
		out.append({"cl": true, "mode": "none", "t": 0.0, "dir": dir})
		for t in [0.2, 0.45, 0.8, 1.3]:
			out.append({"cl": true, "mode": "climb", "t": t, "dir": dir})
		for t in [0.25, 0.5]:
			out.append({"cl": true, "mode": "slide", "t": t, "dir": dir})
	return out


func _cl_pad(a: Dictionary, ts: float) -> Dictionary:
	## climb / slide for t, a tick with nothing held, then the leap: jump and a direction, held 0.6 s.
	var t0: float = a["t"]
	var pd := {}
	if ts < t0:
		if a["mode"] == "climb":
			pd["jump"] = true
		elif a["mode"] == "slide":
			pd["down"] = true
		return pd
	if ts < t0 + DT * 1.5:
		return pd
	pd["left" if int(a["dir"]) < 0 else "right"] = true
	pd["jump"] = ts < t0 + 0.6
	return pd


func _run(state: Dictionary, a: Dictionary):
	## One action from state; the new state, or null (hurt, fell, a gust, nowhere to stand).
	var ms := _restore(state)
	var t: float = state["t"]
	var t0: float = state["t0"]
	var prev: Dictionary = (state["prev"] as Dictionary).duplicate()
	var pads: Array = (state["pads"] as Array).duplicate()
	var from_climb: bool = sp.climbing
	# A leap needs a fresh press 0.15 s after the catch; a press needs the button let go.
	if from_climb:
		while sp.climb_t < 0.17:
			if not _step({}, prev, t0 + t, pads, ms):
				return null
			t += DT
	var first: Dictionary = _cl_pad(a, 0.0) if a.get("cl", false) else Reach.action_pad(a, 0.0, {})
	if first.get("jump", false) and prev["jump"]:
		if not _step({}, prev, t0 + t, pads, ms):
			return null
		t += DT
	var st := {}
	var ts := 0.0
	var left := false
	var t_end := 2.2 + (float(a.get("t", 0.0)) if (a.get("vine", false) or a.get("cl", false)) else 0.0)
	var hit := false
	while ts < t_end:
		var held: Dictionary = _cl_pad(a, ts) if a.get("cl", false) else Reach.action_pad(a, ts, st)
		if not _step(held, prev, t0 + t, pads, ms):
			return null
		t += DT
		ts += DT
		if goal_rect.intersects(sp.rect()):
			hit = true
			break
		if from_climb and not left and not sp.climbing:
			left = true
		if sp.climbing and (left or not from_climb):
			break
		if not sp.on_floor and not sp.climbing and sp.ledge_t < 0.0:
			left = true
		elif sp.on_floor and (left or (not from_climb and not a.get("jump", false) and ts >= float(a.get("walk", 0.0)))):
			break
	if not hit and not (sp.on_floor or sp.climbing):
		return null
	var ride: int = ms.find(sp.riding) if sp.riding != null else -1
	return {"props": _snap(sp), "movers": ms, "ride": ride, "t": t, "t0": t0, "prev": prev, "pads": pads,
		"crumb": bw.crumb.duplicate(true), "rot": bw.rot.duplicate(),
		"pos": sp.position, "goal": hit, "safe": hit or _safe(sp.position, sp.climbing, sp.on_floor, sp.riding)}


func _step(held: Dictionary, prev: Dictionary, t: float, pads: Array, ms: Array) -> bool:
	for m in ms:
		m.update(t, DT)
	var pd := held.duplicate()
	for k in ["jump", "attack"]:
		var now: bool = held.get(k, false)
		pd[k + "_pressed"] = now and not prev.get(k, false)
		prev[k] = now
	if _gust_on(sp, t):
		return false
	sp.push = Vector2.ZERO
	sp.pad = pd
	sp.step(DT)
	bw.ftime += DT
	bw.step_crumbles(DT)
	if sp.climbing:
		bw.touch_rotten(sp.climb_col, floori(sp.center().y / 32.0))
	pads.append(held)
	var r: Rect2 = sp.rect()
	if Reach.hurts(cur, r) or sp.position.y > cur.height * 32 + 40:
		return false
	for wt in weights:
		var ang: float = deg_to_rad(50.0) * sin(TAU * (t / weight_period + float(wt["phase"])))
		var bob: Vector2 = (wt["anchor"] as Vector2) + Vector2(sin(ang), cos(ang)) * float(wt["rod"])
		var near := Vector2(clampf(bob.x, r.position.x, r.end.x), clampf(bob.y, r.position.y, r.end.y))
		if near.distance_to(bob) <= 24.0:
			return false
	return true


func _gust_on(p: Node2D, t: float) -> bool:
	if glass == null:
		return false
	var x := floori(p.center().x / 32.0)
	for z in glass.zones:
		if x >= int(z["x0"]) - 1 and x <= int(z["x1"]) + 1:
			var off: float = 0.0 if str(z.get("phase", "A")) == "A" else float(glass.CYCLE) * 0.5
			var tt: float = fposmod(t - off, float(glass.CYCLE))
			if tt >= float(glass.CYCLE) - float(glass.GUST_ON) - 0.05:
				return true
	return false
