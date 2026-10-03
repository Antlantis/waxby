extends RefCounted
## ModesSave: the "modes" block of a save slot (spec §9, p_modes §10), and
## when each mode opens. Game builds its defaults with defaults() and cleans a
## loaded save's block with clean() (game_state.gd reset / _sanitize); mode
## scripts change the block only through the helpers here, on Game.modes(),
## then Game.save().
##
##   "modes": {
##     "seen": ["door:descent", "trial:k1", "cast:tollgrave", ...],   what the player has looked at
##     "descent": {"best": {cls: {diff: {depth, time, level, strength, date}}},
##                 "cleared": {diff: depth}, "milestones": {diff: [5, 10]},
##                 "runs": {cls: <a suspended run>}, "runs_total": n, "diff": "dusk"},
##     "waxworks": {"bosses": {boss: {diff: {drips, time, time_at_best, paid: [...]}}},
##                  "gauntlet": {diff: {cleared, time, drips, paid: [...]}},
##                  "tweaks": ["hotter", ...], "diff": "dusk", "boss": "tollgrave"},
##     "trials": {id: {best, medal (0 none .. 4 Dawn), paid, tries}},
##     "cosmetics": {"owned": [...], "new": [...]},
##   }
##
## Static only, and it never names an autoload (Game loads this file while
## it's being made itself); the unlock checks take the Game node, or find it.

const Cosmetics := preload("res://scripts/modes/cosmetics.gd")
const TrialData := preload("res://scripts/modes/trial_data.gd")
const Classes := preload("res://scripts/classes.gd")

const DIFFS := ["dusk", "nightfall", "witching"]
# Story order: the boss, its level, and the level whose clear opens it.
const BOSSES := ["tollgrave", "snuffer", "rootmother", "tinker", "saint", "hush"]
const BOSS_LEVEL := {"tollgrave": "1-4", "snuffer": "2-4", "rootmother": "3-4", "tinker": "4-4", "saint": "5-4", "hush": "6-4"}
const HUB_FROM := "1-2"           # the Challenges button, and trial 1 of every calling
const TRIAL_FROM := {1: "1-2", 2: "1-4", 3: "2-4", 4: "4-4"}   # what opens trial n
const FINALE := "6-4"
const RUN_KEYS := ["diff", "seed", "start", "depth", "strength", "hp", "res", "flask", "spare", "glimmers", "hushings",
		"time", "kills", "elites", "items", "embers", "history", "level", "spare_used", "hp_at", "wardens", "spare_glimmer",
		"offered", "cache"]
const SEED_MAX := 9007199254740991   # 2^53 - 1: a JSON number holds an int exactly up to here
# Tests and --autoplay may open everything (a build before its worlds exist).
static var force_open := false


static func defaults() -> Dictionary:
	return {
		"seen": [],
		"descent": {"best": {}, "cleared": {"dusk": 0, "nightfall": 0, "witching": 0},
				"milestones": {"dusk": [], "nightfall": [], "witching": []}, "runs": {}, "runs_total": 0, "diff": "dusk"},
		"waxworks": {"bosses": {}, "gauntlet": {}, "tweaks": [], "diff": "dusk", "boss": "tollgrave"},
		"trials": {},
		"cosmetics": {"owned": Cosmetics.FREE.duplicate(), "new": []},
	}


# ---------------------------------------------------------------- cleaning

static func _i(v, lo := -2147483647, hi := 2147483647) -> int:
	return clampi(int(v) if (v is int or v is float) else (int(v) if v is String and (v as String).is_valid_float() else 0), lo, hi)


static func _f(v, lo := -1.0e12, hi := 1.0e12) -> float:
	var x := 0.0
	if v is int or v is float:
		x = float(v)
	elif v is String and (v as String).is_valid_float():
		x = float(v)
	if is_nan(x) or is_inf(x):
		x = 0.0
	return clampf(x, lo, hi)


static func _strs(v, allowed: Array = []) -> Array:
	var out: Array = []
	if v is Array:
		for s in v:
			if not (s is String):
				continue
			var t: String = s
			if t != "" and not out.has(t) and (allowed.is_empty() or allowed.has(t)):
				out.append(t)
	return out


static func _dict(v) -> Dictionary:
	return v if v is Dictionary else {}


static func clean(d) -> Dictionary:
	## A loaded block made whole: JSON's floats cast back to ints, depths and
	## medals clamped, unknown callings, difficulties, bosses, trials and
	## cosmetics dropped, a suspended run of the wrong shape dropped (the run
	## ends rather than crashing), and the free cosmetics always owned.
	var src := _dict(d)
	var out := defaults()
	out["seen"] = _strs(src.get("seen", []))
	# The Descent.
	var ds := _dict(src.get("descent", {}))
	var dd: Dictionary = out["descent"]
	for cls in _dict(ds.get("best", {})):
		if not Classes.ALL.has(str(cls)):
			continue
		var per := _dict(ds["best"][cls])
		var keep := {}
		for df in per:
			if not DIFFS.has(str(df)):
				continue
			var r := _dict(per[df])
			var depth := _i(r.get("depth", 0), 0, 9999)
			if depth <= 0:
				continue
			keep[str(df)] = {"depth": depth, "time": _f(r.get("time", 0.0), 0.0), "level": _i(r.get("level", 1), 1, 99),
					"strength": str(r.get("strength", "normal")), "date": str(r.get("date", ""))}
		if not keep.is_empty():
			dd["best"][str(cls)] = keep
	var cl := _dict(ds.get("cleared", {}))
	var ms := _dict(ds.get("milestones", {}))
	for df in DIFFS:
		dd["cleared"][df] = _i(cl.get(df, 0), 0, 9999)
		var marks: Array = []
		for v in (ms.get(df, []) if ms.get(df) is Array else []):
			var n := _i(v, 1, 9999)
			if not marks.has(n):
				marks.append(n)
		marks.sort()
		dd["milestones"][df] = marks
	for cls in _dict(ds.get("runs", {})):
		var run = clean_run(ds["runs"][cls])
		if Classes.ALL.has(str(cls)) and not run.is_empty():
			dd["runs"][str(cls)] = run
	dd["runs_total"] = _i(ds.get("runs_total", 0), 0)
	dd["diff"] = str(ds.get("diff", "dusk")) if DIFFS.has(str(ds.get("diff", ""))) else "dusk"
	# The Waxworks.
	var ws := _dict(src.get("waxworks", {}))
	var wd: Dictionary = out["waxworks"]
	for b in _dict(ws.get("bosses", {})):
		if not BOSSES.has(str(b)):
			continue
		var per := _dict(ws["bosses"][b])
		var keep := {}
		for df in per:
			if not DIFFS.has(str(df)):
				continue
			var r := _dict(per[df])
			keep[str(df)] = {"drips": _i(r.get("drips", 0), 0, 99), "time": _f(r.get("time", 0.0), 0.0),
					"time_at_best": _f(r.get("time_at_best", 0.0), 0.0), "paid": _strs(r.get("paid", []))}
		if not keep.is_empty():
			wd["bosses"][str(b)] = keep
	for df in _dict(ws.get("gauntlet", {})):
		if not DIFFS.has(str(df)):
			continue
		var r := _dict(ws["gauntlet"][df])
		wd["gauntlet"][str(df)] = {"cleared": bool(r.get("cleared", false)), "time": _f(r.get("time", 0.0), 0.0),
				"drips": _i(r.get("drips", 0), 0, 99), "paid": _strs(r.get("paid", []))}
	wd["tweaks"] = _strs(ws.get("tweaks", []))
	wd["diff"] = str(ws.get("diff", "dusk")) if DIFFS.has(str(ws.get("diff", ""))) else "dusk"
	wd["boss"] = str(ws.get("boss", "tollgrave")) if BOSSES.has(str(ws.get("boss", ""))) else "tollgrave"
	# The Trials.
	var ts := _dict(src.get("trials", {}))
	for id in ts:
		if not TrialData.TRIALS.has(str(id)):
			continue
		var r := _dict(ts[id])
		out["trials"][str(id)] = {"best": _f(r.get("best", 0.0), 0.0), "medal": _i(r.get("medal", 0), 0, 4),
				"paid": _i(r.get("paid", 0), 0, 4), "tries": _i(r.get("tries", 0), 0)}
	# Cosmetics.
	var cs := _dict(src.get("cosmetics", {}))
	var known := Cosmetics.all_ids()
	var owned := _strs(cs.get("owned", []), known)
	for f in Cosmetics.FREE:
		if not owned.has(f):
			owned.push_front(f)
	out["cosmetics"] = {"owned": owned, "new": _strs(cs.get("new", []), known)}
	return out


static func clean_run(v) -> Dictionary:
	## A suspended Descent run, or {} when it isn't one.
	var r := _dict(v)
	if r.is_empty() or not DIFFS.has(str(r.get("diff", ""))) or not (r.get("seed") is int or r.get("seed") is float):
		return {}
	# The seed exactly as it was (never clamped: a run's depths are built from
	# it, so a changed seed would resume a different level).
	var sd = r["seed"]
	if sd is float and (is_nan(sd) or is_inf(sd) or absf(sd) > float(SEED_MAX) or sd != floorf(sd)):
		return {}
	var depth := _i(r.get("depth", 0), 0, 9999)
	if depth < 1:
		return {}
	var out := {
		"diff": str(r["diff"]), "seed": int(sd), "start": _i(r.get("start", 1), 1, 9999), "depth": depth,
		"strength": str(r.get("strength", "normal")) if ["gentle", "normal", "fierce"].has(str(r.get("strength", ""))) else "normal",
		"hp": _f(r.get("hp", 1.0), 0.01, 1.0), "res": _f(r.get("res", -1.0), -1.0), "flask": _i(r.get("flask", -1), -1, 9),
		"spare": _i(r.get("spare", 0), 0, 9), "time": _f(r.get("time", 0.0), 0.0), "kills": _i(r.get("kills", 0), 0),
		"elites": _i(r.get("elites", 0), 0), "items": _i(r.get("items", 0), 0), "embers": _i(r.get("embers", 0), 0),
		"level": _i(r.get("level", 1), 1, 99), "spare_used": _i(r.get("spare_used", 0), 0),
		"history": _strs(r.get("history", [])).slice(0, 12), "hp_at": [],
		"glimmers": {}, "hushings": {}, "wardens": _strs(r.get("wardens", [])).slice(0, 40),
		"spare_glimmer": bool(r.get("spare_glimmer", false)),
		# The depth whose landing Glimmers were taken (or walked past), and
		# whose landing reliquary was opened: a rebuilt landing (Rest here and
		# Resume, an app kill, a restart there) pays neither again.
		"offered": _i(r.get("offered", 0), 0, 9999), "cache": _i(r.get("cache", 0), 0, 9999),
	}
	for k in _dict(r.get("glimmers", {})):
		out["glimmers"][str(k)] = _i(r["glimmers"][k], 0, 9)
	for k in _dict(r.get("hushings", {})):
		out["hushings"][str(k)] = _i(r["hushings"][k], 0, 9)
	for x in (r.get("hp_at", []) if r.get("hp_at") is Array else []):
		(out["hp_at"] as Array).append(_i(x, 0, 100))
	return out


# ---------------------------------------------------------------- the save's block

static func game() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).root.get_node_or_null("Game") if ml is SceneTree else null


static func block(g: Node = null) -> Dictionary:
	## Game.modes() (made whole in place when a key is missing), or a fresh
	## block when there's no Game (a test with no autoloads).
	var gg := g if g != null else game()
	if gg == null or not gg.has_method("modes"):
		return defaults()
	var m: Dictionary = gg.modes()
	var dflt := defaults()
	for k in dflt:
		if not m.has(k) or typeof(m[k]) != typeof(dflt[k]):
			m[k] = dflt[k]
	return m


static func seen(g: Node, key: String) -> bool:
	return (block(g)["seen"] as Array).has(key)


static func mark_seen(g: Node, key: String, save := true) -> void:
	var s: Array = block(g)["seen"]
	if not s.has(key):
		s.append(key)
		if save and g != null and g.has_method("save"):
			g.save()


# ---------------------------------------------------------------- what's open

static func _cleared_any(g: Node, id: String) -> bool:
	## A level cleared on any difficulty (read without making a record).
	if g == null:
		return false
	var lv = g.data.get("levels", {}) if "data" in g else {}
	for df in DIFFS:
		var per = lv.get(df, {}) if lv is Dictionary else {}
		if per is Dictionary and per.has(id) and per[id] is Dictionary and bool(per[id].get("cleared", false)):
			return true
	return false


static func hub_open(g: Node = null) -> bool:
	## The map's Challenges button: once the Crypt Stair (1-2) is cleared.
	var gg := g if g != null else game()
	return force_open or _cleared_any(gg, HUB_FROM)


static func boss_beaten(g: Node, boss: String) -> bool:
	return force_open or _cleared_any(g if g != null else game(), str(BOSS_LEVEL.get(boss, "")))


static func waxworks_open(g: Node = null) -> bool:
	## Once Old Tollgrave is first beaten, on any difficulty.
	return boss_beaten(g if g != null else game(), "tollgrave")


static func descent_open(g: Node = null) -> bool:
	## Once the Hush (6-4) is beaten, on any difficulty, and homecoming seen.
	var gg := g if g != null else game()
	if force_open:
		return true
	return gg != null and _cleared_any(gg, FINALE) and gg.has_method("seen") and bool(gg.seen("homecoming"))


static func trial_open(g: Node, n: int) -> bool:
	## Trial n (1..4) of every calling: 1 after 1-2, 2 after Tollgrave, 3
	## after the Snuffer, 4 (the Master) after the Tinker.
	return force_open or _cleared_any(g if g != null else game(), str(TRIAL_FROM.get(n, "")))


static func trial_lock_text(n: int) -> String:
	return {1: "Clear the Crypt Stair", 2: "Ring the Bell Tower's bell", 3: "Put out the Snuffer",
			4: "Stop the Tinker of Hours"}.get(n, "Sealed")


static func open_casts(g: Node = null) -> Array:
	## The bosses cast in the Waxworks (beaten, and their arena file built).
	var gg := g if g != null else game()
	var out: Array = []
	for b in BOSSES:
		if boss_beaten(gg, b) and FileAccess.file_exists("res://levels/rush/%s.txt" % b):
			out.append(b)
	return out


static func cast_built(boss: String) -> bool:
	## A boss's Waxworks cast is in this build: its level and its arena.
	return BOSS_LEVEL.has(boss) and FileAccess.file_exists("res://levels/%s.txt" % BOSS_LEVEL[boss]) \
			and FileAccess.file_exists("res://levels/rush/%s.txt" % boss)


static func built_casts() -> Array:
	## The casts this build has (a W1-W2 build: Tollgrave and the Snuffer).
	return BOSSES.filter(func(b): return cast_built(b))


static func built_trials() -> Array:
	return TrialData.ORDER.filter(func(id): return TrialData.built(id))


static func source_reachable(src: String, g: Node = null) -> bool:
	## Whether this build can pay a cosmetic's source (Cosmetics.SRC_TEXT):
	## the Look tab names only those, the rest say Cosmetics.DEEPER, so a
	## W1-W2 build never names a boss, the ending or a Descent depth it can't
	## reach. A cast needs its boss's level and arena; the six-cast seals and
	## the Gauntlet all six; homecoming the finale (6-4); a depth the Descent's
	## door open; a Trials count or a calling's four (or its Master) the
	## trials built.
	var kind := src.get_slice(":", 0)
	var arg := src.get_slice(":", 1)
	match kind:
		"default":
			return true
		"waxworks":
			return cast_built(arg) if BOSSES.has(arg) else built_casts().size() == BOSSES.size()
		"gauntlet":
			return built_casts().size() == BOSSES.size()
		"story":
			return FileAccess.file_exists("res://levels/%s.txt" % FINALE)
		"descent":
			return descent_open(g)
		"trials":
			var cls := src.get_slice(":", 2)
			if arg == "gold4":
				return (TrialData.BY_CLS.get(cls, []) as Array).all(func(id): return TrialData.built(str(id)))
			if arg == "master":
				for id in TrialData.BY_CLS.get(cls, []):
					if bool(TrialData.TRIALS[id].get("master", false)):
						return TrialData.built(str(id))
				return false
			var n := arg.to_int()   # "golds10", "dawns20", "medals5"...
			return built_trials().size() >= maxi(n, 1)
	return true


static func gauntlet_open(g: Node = null) -> bool:
	## All six beaten (their arenas built).
	return open_casts(g).size() == BOSSES.size()


static func news_keys(g: Node = null) -> Array:
	## What has opened and not been looked at: the doors, the trials, the
	## casts (the Look tab's new cosmetics are counted apart).
	var gg := g if g != null else game()
	var out: Array = []
	if hub_open(gg):
		out.append("door:challenges")
	if waxworks_open(gg):
		out.append("door:waxworks")
		for b in open_casts(gg):
			out.append("cast:" + b)
	if descent_open(gg):
		out.append("door:descent")
	for id in TrialData.ORDER:
		if TrialData.built(id) and trial_open(gg, TrialData.number(id)):
			out.append("trial:" + id)
	return out.filter(func(k): return not seen(gg, k))


static func has_news(g: Node = null) -> bool:
	## The Challenges button's gold "!".
	var gg := g if g != null else game()
	return not news_keys(gg).is_empty()


static func resume_ember(g: Node = null) -> bool:
	## The calling being played has a suspended Descent run.
	var gg := g if g != null else game()
	if gg == null or not gg.has_method("hero_id"):
		return false
	return (block(gg)["descent"]["runs"] as Dictionary).has(str(gg.hero_id()))


static func has_suspended(cls: String, g: Node = null) -> bool:
	## A suspended Descent run waiting for this calling (the map's resume ember,
	## asked with the calling: SC's call).
	var gg := g if g != null else game()
	if gg == null:
		return false
	var run = (block(gg)["descent"]["runs"] as Dictionary).get(cls)
	return run is Dictionary and not (run as Dictionary).is_empty()


# ---------------------------------------------------------------- records

static func descent_best(g: Node, cls: String, df: String) -> Dictionary:
	var per: Dictionary = (block(g)["descent"]["best"] as Dictionary).get(cls, {})
	return per.get(df, {})


static func descent_cleared(g: Node, df: String) -> int:
	return int((block(g)["descent"]["cleared"] as Dictionary).get(df, 0))


static func note_descent_best(g: Node, cls: String, df: String, depth: int, time: float, level: int, strength: String) -> bool:
	## A cleared depth for a calling: a new best (true) when deeper, or as deep
	## and faster.
	var best := descent_best(g, cls, df)
	var d0 := int(best.get("depth", 0))
	if depth < d0 or (depth == d0 and time >= float(best.get("time", 1.0e9)) and d0 > 0):
		return false
	var b: Dictionary = block(g)["descent"]["best"]
	if not b.has(cls):
		b[cls] = {}
	b[cls][df] = {"depth": depth, "time": time, "level": level, "strength": strength, "date": Time.get_date_string_from_system()}
	var c: Dictionary = block(g)["descent"]["cleared"]
	c[df] = maxi(int(c.get(df, 0)), depth)
	return true


static func trial_rec(g: Node, id: String) -> Dictionary:
	var t: Dictionary = block(g)["trials"]
	return t.get(id, {"best": 0.0, "medal": 0, "paid": 0, "tries": 0})


static func set_trial_rec(g: Node, id: String, r: Dictionary) -> void:
	(block(g)["trials"] as Dictionary)[id] = r


static func medal_count(g: Node, at_least: int) -> int:
	## Trials with a medal of at least this rank (1 Bronze .. 4 Dawn).
	var n := 0
	for id in block(g)["trials"]:
		if int(block(g)["trials"][id].get("medal", 0)) >= at_least:
			n += 1
	return n


static func boss_rec(g: Node, boss: String, df: String) -> Dictionary:
	var per: Dictionary = (block(g)["waxworks"]["bosses"] as Dictionary).get(boss, {})
	return per.get(df, {"drips": 0, "time": 0.0, "time_at_best": 0.0, "paid": []})


static func set_boss_rec(g: Node, boss: String, df: String, r: Dictionary) -> void:
	var b: Dictionary = block(g)["waxworks"]["bosses"]
	if not b.has(boss):
		b[boss] = {}
	b[boss][df] = r


static func best_seal(g: Node, boss: String) -> int:
	## The best seal a cast has on any difficulty: 0 none, 1 Bronze .. 3 Gold.
	var best := 0
	for df in DIFFS:
		var paid: Array = boss_rec(g, boss, df).get("paid", [])
		for i in 3:
			if paid.has(["bronze", "silver", "gold"][i]):
				best = maxi(best, i + 1)
	return best
