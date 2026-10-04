extends RefCounted
## Build 2's level rules (not a test: test_w3 .. test_w6, test_core,
## test_rooms, test_progression, test_export, test_secrets and test_toolkit
## preload it). Each level file is held to what its own headers declare,
## written by tools/levels/common.py (world_tables, anoint_header, span,
## rooms_header), instead of fixed counts, widths and altar x; the generator
## checks the same as it writes (common.check_headers, world_problems), and
## these read the file back. A level that declares nothing has nothing
## checked here.
##
##   roster: headline=a,b; support=c; guest=d; rattle_max=3; fodder_max=0.75; count=18-24;
##           banned=e; pack_leaders=glassmite:3; stamps=crossfire
##           every placed kind declared (a Rattle listed is rattle_max's,
##           left out; one Lidlurk: the vault), each headline kind placed;
##           from World 3 a headline kind the world's own (or one
##           HEADLINE_RETURN brings back), a guest an earlier world's (HOME);
##           no banned kind placed; the fodder share (EnemyKinds.ROLE) and
##           the count within theirs
##   threat: 11.5   the cost per 100 tiles within THREAT_SLACK of it: each
##           monster at the bodies it comes to in play (in_play: packs at
##           their size), a forced Anointed at TIER_COST's x2.5; a world's
##           X-1..X-3 ramping (RAMP_STEP, RECUT_RAMP once re-cut)
##   anoint: x,y[:Omen+Omen[:Name]]; x,y   forced Anointed: an anointable kind,
##           Omens from its Dusk pool there (elites.gd omen_pool)
##   roles:  S C A ...   a re-cut level's section roles: a world's levels all
##           declare them once one does, and then no two share their
##           landmarks or line their altars up; the variety rules hold
##           (recut_problems: fodder falling, the X-3's mix, a screen's crowd)
##   room:   duel x0-x1 ...; ambush ...   the sealed rooms (features/sealed.gd
##           parse): a monster in each, doorways of air or stone that never
##           opens, no monster by a door, an altar by each one's door
##   twist: packs   the pack kinds at their pack size (in_play)
##   twist:, lesson:   an id twists.gd knows; a lesson Title|Line that fits

const LevelData := preload("res://scripts/level_data.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const Elites := preload("res://scripts/elites.gd")
const Sealed := preload("res://scripts/features/sealed.gd")
const Twists := preload("res://scripts/twists.gd")
# common.py's numbers (THREAT_SLACK, RAMP_STEP, RECUT_RAMP, RAMP_TOL, the
# pack tables, ALTARS, DOOR_ALTAR, HOME, HEADLINE_RETURN, the variety rules'
# numbers, DOOR_SOLID): the generator's checks and these are one rule.
const THREAT_SLACK := 0.10
const RAMP_STEP := 0.0
const RECUT_RAMP := 1.0
const RAMP_TOL := 0.25
const PACK_EACH := {"glassmite": 3, "creepbone": 2, "unwick": 2}
const PACK_GROUP := {"hushling": 4, "tickwind": 2}
const DUSK_PACK := {"hushling": 2.5}
const ANOINTED_PACK := {"hushling": 4}
const PACK_TILES := 4
const ALTARS := Vector2i(3, 5)
const DOOR_ALTAR := 8
const HOME := {"brinejaw": 2, "rootling": 3, "weepcap": 3, "rattlehound": 3, "creepbone": 3,
		"tickwind": 4, "spurwheel": 4, "frostbuckle": 4, "hoarowl": 4,
		"glassmite": 5, "gustling": 5, "refractor": 5, "paneguard": 5,
		"hushling": 6, "stillmaw": 6, "unwick": 6, "lurecoil": 6}
const HEADLINE_RETURN := {6: ["brinejaw"]}
const ROSTER_KEYS := ["headline", "support", "guest", "rattle_max", "fodder_max", "count", "banned", "pack_leaders", "stamps"]
const ALTAR_NEAR := 8
const FODDER_CAPS := [0.85, 0.75, 0.65]
const SCREEN := 26
const MIXED_KINDS := 3
const MIXED_SCREENS := 2
const AWAKE_MAX := 6
# A doorway's cells: air, or what never opens (stone, a reliquary or a spent
# one, wax-ice, a belt: common.py DOOR_SOLID).
const DOOR_SOLID := [LevelData.STONE, LevelData.BLOCK, LevelData.SPENT, LevelData.ICE, LevelData.BELT_L, LevelData.BELT_R]


static func home_of(kind: String) -> int:
	return int(HOME.get(kind, 1))


static func level_no(id: String) -> int:
	## "3-2" -> 2 (X-1, X-2, X-3), 0 for anything else (common.level_no).
	if id.length() == 3 and id[1] == "-" and id[0].is_valid_int() and id[2].is_valid_int():
		return int(id[2])
	return 0


static func kind_of(e: Dictionary) -> String:
	## A placed entity's monster kind ("" for anything else): a nest counts
	## as its Gutterwing; the Dread and the boss have their own headers.
	var k := str(e["kind"])
	if k == "nest":
		k = "gutterwing"
	return k if EnemyKinds.COST.has(k) else ""


static func cast_of(lv: RefCounted) -> Dictionary:
	## {kind: n}: the monsters a level places.
	var out := {}
	for e in lv.entities:
		var k := kind_of(e)
		if k != "":
			out[k] = int(out.get(k, 0)) + 1
	return out


# ---------------------------------------------------------------- roster

static func roster_of(lv: RefCounted) -> Dictionary:
	## Its roster: header, {} when it has none: {headline, support, guest,
	## banned, stamps: [kinds or names], rattle_max: int, fodder_max: float,
	## count: Vector2i (lo, hi), pack_leaders: {kind: n}, unknown: [keys it
	## doesn't know]}.
	var raw := str(lv.headers.get("roster", "")).strip_edges()
	if raw == "":
		return {}
	var out := {"headline": [], "support": [], "guest": [], "banned": [], "stamps": [], "pack_leaders": {}, "unknown": []}
	for part in raw.split(";", false):
		var kv := part.split("=", true, 1)
		var k := kv[0].strip_edges()
		var v := kv[1].strip_edges() if kv.size() > 1 else ""
		match k:
			"headline", "support", "guest", "banned", "stamps":
				out[k] = Array(v.split(",", false)).map(func(s): return str(s).strip_edges())
			"rattle_max":
				out[k] = int(v)
			"fodder_max":
				out[k] = float(v)
			"count":
				var ab := v.split("-")
				out[k] = Vector2i(int(ab[0]), int(ab[ab.size() - 1]))
			"pack_leaders":
				for a in v.split(",", false):
					var kn := a.split(":")
					if kn.size() == 2:
						out[k][kn[0].strip_edges()] = int(kn[1])
			_:
				(out["unknown"] as Array).append(k)
	return out


static func roster_problems(lv: RefCounted, world := -1) -> Array:
	## What breaks its declared roster, as common.roster_problems says it
	## ([] with no roster: header). world: the level's (else its id's).
	var r := roster_of(lv)
	if r.is_empty():
		return []
	var w: int = int(lv.world) if world < 0 else world
	var out := []
	for k in r["unknown"]:
		out.append("unknown roster key %s" % k)
		if str(k).contains(","):
			out.append("a roster is keys (headline=..; rattle_max=..; fodder_max=..), not a list of kinds")
	for k in ["rattle_max", "fodder_max"]:
		if not r.has(k):
			out.append("the roster has no %s" % k)
	if not out.is_empty():
		return out
	# A Rattle listed is rattle_max's: left out of every list.
	var head: Array = (r["headline"] as Array).filter(func(k): return k != "skeleton")
	var sup: Array = (r["support"] as Array).filter(func(k): return k != "skeleton")
	var guest: Array = (r["guest"] as Array).filter(func(k): return k != "skeleton")
	if head.is_empty():
		out.append("the roster has no headline kind but the Rattle (rattle_max holds Rattles)")
	var listed: Array = head + sup + guest
	for k in listed:
		if k == "lidlurk" or not EnemyKinds.COST.has(k):
			out.append("%s is listed (a Lidlurk is the vault, else no kind)" % k)
	var cast := cast_of(lv)
	var banned: Array = r["banned"]
	for k in banned:
		if not EnemyKinds.COST.has(k):
			out.append("%s is banned, but no kind" % k)
		elif listed.has(k):
			out.append("%s is both listed and banned" % k)
		elif int(cast.get(k, 0)) > 0:
			out.append("%d %s, banned" % [cast[k], k])
	for k in r["pack_leaders"]:
		if not listed.has(k) or int(r["pack_leaders"][k]) < 1:
			out.append("pack_leaders %s:%s (a listed kind, at 1 or more)" % [k, r["pack_leaders"][k]])
	var kinds := cast.keys()
	kinds.sort()
	var n := 0
	var fodder := 0
	for k in kinds:
		var c := int(cast[k])
		n += c
		if str(EnemyKinds.ROLE.get(k, "")) == "fodder":
			fodder += c
		if k == "skeleton":
			if c > int(r["rattle_max"]):
				out.append("%d Rattles (rattle_max %d)" % [c, r["rattle_max"]])
		elif k == "lidlurk":
			if c > 1:
				out.append("%d Lidlurks (one: the vault)" % c)
		elif not listed.has(k) and not banned.has(k):
			out.append("%d %s it does not declare" % [c, k])
	for k in head:
		if int(cast.get(k, 0)) == 0:
			out.append("no %s, a headline kind" % k)
	if w >= 3:
		var back: Array = HEADLINE_RETURN.get(w, [])
		for k in head:
			if home_of(k) != w and not back.has(k):
				out.append("%s is World %d's, no headline in World %d" % [k, home_of(k), w])
		for k in guest:
			if home_of(k) >= w:
				out.append("%s is no guest from an earlier world" % k)
		for k in sup:
			if home_of(k) > w:
				out.append("%s is from a later world" % k)
	if n > 0 and float(fodder) > float(r["fodder_max"]) * n + 0.000001:
		out.append("fodder %d of %d (fodder_max %s)" % [fodder, n, r["fodder_max"]])
	if r.has("count"):
		var band: Vector2i = r["count"]
		if n < band.x or n > band.y:
			out.append("%d monsters (count %d-%d)" % [n, band.x, band.y])
	return out


# ---------------------------------------------------------------- forced Anointed

static func anoint_of(lv: RefCounted) -> Array:
	## Its anoint: header, [{cell: Vector2i, omens: [], name}] ([] with none).
	var out := []
	for part in str(lv.headers.get("anoint", "")).split(";", false):
		var bits := part.strip_edges().split(":")
		var xy := bits[0].split(",")
		if xy.size() != 2 or not xy[0].strip_edges().is_valid_int() or not xy[1].strip_edges().is_valid_int():
			continue
		var omens := []
		if bits.size() > 1:
			for o in bits[1].split("+", false):
				if o.strip_edges() != "":
					omens.append(o.strip_edges())
		out.append({"cell": Vector2i(int(xy[0]), int(xy[1])), "omens": omens, "name": bits[2].strip_edges() if bits.size() > 2 else ""})
	return out


static func forced_cells(lv: RefCounted) -> Dictionary:
	## {cell: true} for every anoint: cell.
	var out := {}
	for a in anoint_of(lv):
		out[a["cell"]] = true
	return out


static func anoint_problems(lv: RefCounted, world := -1) -> Array:
	## Each anoint: part reads, its cell holds a kind elites.gd may anoint
	## (ELIGIBLE), with Omens from its Dusk pool in the level's world
	## (omen_pool: so no difficulty falls back to a roll), distinct, at most
	## MAX_OMENS, and a name with no ; : or , and 24 letters at most; World
	## 1-2 at most one, with one Omen, and none in 1-1.
	var w: int = int(lv.world) if world < 0 else world
	var cells := anoint_of(lv)
	var out := []
	for part in str(lv.headers.get("anoint", "")).split(";", false):
		var xy := part.strip_edges().split(":")[0].split(",")
		if part.strip_edges() != "" and (xy.size() != 2 or not xy[0].strip_edges().is_valid_int() or not xy[1].strip_edges().is_valid_int()):
			out.append("the anoint part '%s' doesn't read (x,y[:Omen+Omen[:Name]])" % part.strip_edges())
	for a in cells:
		var c: Vector2i = a["cell"]
		var kind := ""
		for e in lv.entities:
			if e["cell"] == c and kind_of(e) != "":
				kind = kind_of(e)
		if not Elites.ELIGIBLE.has(kind):
			out.append("the anoint at %s holds %s, no kind elites.gd may anoint" % [c, kind if kind != "" else "no monster"])
			continue
		var pool: Array = Elites.omen_pool(kind, "dusk", w)
		var omens: Array = a["omens"]
		for o in omens:
			if not pool.has(o):
				out.append("the %s at %s may not carry %s in World %d on Dusk" % [kind, c, o, w])
		var seen := {}
		for o in omens:
			seen[o] = true
		if seen.size() != omens.size() or omens.size() > Elites.MAX_OMENS:
			out.append("the %s at %s: Omens %s" % [kind, c, omens])
		var nm := str(a["name"])
		if nm.length() > 24 or nm.contains(";") or nm.contains(":") or nm.contains(","):
			out.append("the %s at %s: its name '%s'" % [kind, c, nm])
		if w >= 1 and w <= 2 and (omens.size() > 1 or cells.size() > 1 or lv.id == "1-1"):
			out.append("World 1-2 takes at most one set piece, with one Omen, and none in 1-1 (%s)" % c)
	return out


# ---------------------------------------------------------------- twist and lesson

static func twist_problems(lv: RefCounted) -> Array:
	## A twist: header is an id twists.gd knows (a typo would be no rule and
	## no card, silently); a lesson: is Title|Line, the title at most
	## Twists.NAME_MAX characters and the line Twists.LINE_MAX (common.py
	## lesson_problems; test_twists measures them in the band).
	var out := []
	var raw := str(lv.headers.get("twist", "")).strip_edges()
	if raw != "" and Twists.id_from(raw) == "":
		out.append("twist '%s' is none of twists.gd's" % raw)
	if lv.headers.has("lesson"):
		var parts := str(lv.headers["lesson"]).split("|", true, 1)
		var title := parts[0].strip_edges()
		var line := parts[1].strip_edges() if parts.size() > 1 else ""
		if title == "" or line == "":
			out.append("a lesson is Title|Line: '%s'" % lv.headers["lesson"])
		if title.length() > Twists.NAME_MAX:
			out.append("the lesson title '%s' is %d characters (at most %d)" % [title, title.length(), Twists.NAME_MAX])
		if line.length() > Twists.LINE_MAX:
			out.append("the lesson line '%s' is %d characters (at most %d)" % [line, line.length(), Twists.LINE_MAX])
	return out


# ---------------------------------------------------------------- threat

static func pack_groups(cells: Array) -> Array:
	## Groups of cells within PACK_TILES across and a row up or down of one
	## another (a placed pack, as hushling.gd finds one; common._packs).
	var sorted := cells.duplicate()
	sorted.sort()
	var groups := []
	for c in sorted:
		var merged := [c]
		var keep := []
		for g in groups:
			var near := false
			for o in g:
				if absi(c.x - o.x) <= PACK_TILES and absi(c.y - o.y) <= 1:
					near = true
			if near:
				merged.append_array(g)
			else:
				keep.append(g)
		keep.append(merged)
		groups = keep
	return groups


static func in_play(lv: RefCounted) -> Array:
	## [[cell, kind, n]]: each placed monster (the Dread and the boss aside)
	## and the bodies it comes to in play, as common.in_play counts them: a
	## roster's pack_leaders at its n; under twist: packs PACK_EACH apiece;
	## each placed pack of a PACK_GROUP or DUSK_PACK kind up to its size, on
	## its leftmost (ANOINTED_PACK behind a forced Anointed from World 3; else
	## PACK_GROUP under the twist; else DUSK_PACK).
	var forced := forced_cells(lv)
	var packs_on := str(lv.headers.get("twist", "")).strip_edges() == "packs"
	var leaders: Dictionary = roster_of(lv).get("pack_leaders", {})
	var out := []
	var groups := {}
	for e in lv.entities:
		var k := kind_of(e)
		if k == "":
			continue
		var p := [e["cell"], k, 1.0]
		out.append(p)
		if leaders.has(k):
			p[2] = float(leaders[k])
		elif packs_on and PACK_EACH.has(k):
			p[2] = float(PACK_EACH[k])
		elif PACK_GROUP.has(k) or DUSK_PACK.has(k):
			if not groups.has(k):
				groups[k] = {}
			groups[k][e["cell"]] = p
	for k in groups:
		var by: Dictionary = groups[k]
		for g in pack_groups(by.keys()):
			var lead_c: Vector2i = g[0]
			for c in g:
				if c < lead_c:
					lead_c = c
			var size := float(DUSK_PACK.get(k, 0.0))
			if forced.has(lead_c) and int(lv.world) >= 3 and ANOINTED_PACK.has(k):
				size = float(ANOINTED_PACK[k])
			elif packs_on and PACK_GROUP.has(k):
				size = float(PACK_GROUP[k])
			by[lead_c][2] = float(by[lead_c][2]) + maxf(0.0, size - (g as Array).size())
	return out


static func threat_of(lv: RefCounted, tiles := -1.0) -> float:
	## Threat cost per 100 tiles (EnemyKinds.cost, the Dread aside), as
	## common.threat_of counts it: each monster at the bodies it comes to in
	## play (in_play: its pack's extras at its kind's cost), an anoint: cell
	## itself at TIER_COST's x2.5. tiles: the stretch it's spread over (the
	## level's width; a boss level's approach).
	var forced := forced_cells(lv)
	var cost := 0.0
	for p in in_play(lv):
		var k: String = p[1]
		cost += EnemyKinds.cost(k, "anointed" if forced.has(p[0]) else "") + EnemyKinds.cost(k) * (float(p[2]) - 1.0)
	return cost * 100.0 / (float(lv.width) if tiles <= 0.0 else tiles)


static func declared_threat(lv: RefCounted) -> float:
	## Its threat: header (-1 with none).
	var raw := str(lv.headers.get("threat", "")).strip_edges()
	return float(raw) if raw.is_valid_float() else -1.0


static func recut(levels: Array) -> bool:
	## A world's regular levels re-cut: any declares its roles:.
	for lv in levels:
		if str(lv.headers.get("roles", "")).strip_edges() != "":
			return true
	return false


static func threat_problems(levels: Array, ramp := -1.0) -> Array:
	## Each level with a threat: header measured within THREAT_SLACK of it,
	## and the declared ones ramping in id order (X-1, X-2, X-3: each at least
	## the ramp over the one before, less RAMP_TOL; ramp: a world's own, else
	## RECUT_RAMP once re-cut, else RAMP_STEP).
	var step := ramp if ramp >= 0.0 else (RECUT_RAMP if recut(levels) else RAMP_STEP)
	var out := []
	var sorted := levels.duplicate()
	sorted.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var prev := []
	for lv in sorted:
		var want := declared_threat(lv)
		if want < 0.0:
			continue
		var got := threat_of(lv)
		if absf(got - want) > want * THREAT_SLACK + 0.000001:
			out.append("%s: threat %.2f per 100 tiles, declared %s (within %d%%)" % [lv.id, got, want, roundi(THREAT_SLACK * 100.0)])
		if not prev.is_empty() and want < float(prev[1]) + step - RAMP_TOL:
			out.append("%s's threat %s after %s's %s (the ramp: +%s, less %s)" % [lv.id, want, prev[0], prev[1], step, RAMP_TOL])
		prev = [lv.id, want]
	return out


# ---------------------------------------------------------------- checkpoints and roles

static func ranges_of(value: String) -> Array:
	## [Vector2i(x0, x1)] from a range header ("a-b, c-d@8"; a belt_flip's
	## "c-d=8").
	var out := []
	for part in value.split(",", false):
		var ab := part.split("@")[0].split("=")[0].split("-")
		if ab.size() == 2 and ab[0].strip_edges().is_valid_int() and ab[1].strip_edges().is_valid_int():
			out.append(Vector2i(int(ab[0]), int(ab[1])))
	return out


static func altars_of(lv: RefCounted) -> Array:
	var out := []
	for e in lv.entities:
		if e["kind"] == "altar":
			out.append(int(e["cell"].x))
	out.sort()
	return out


static func checkpoint_problems(lv: RefCounted, max_gap: int, band := ALTARS) -> Array:
	## A regular level's checkpoints (start, altars, bell): at most max_gap
	## apart, band altars (ALTARS), and an altar at most DOOR_ALTAR tiles
	## before every sealed room's door (the left column of each room in its
	## room: header, as features/sealed.gd reads it).
	var marks: Array = [int(lv.start.x)]
	var altars := altars_of(lv)
	for e in lv.entities:
		if e["kind"] == "bell" or e["kind"] == "boss":
			marks.append(int(e["cell"].x))
	marks.append_array(altars)
	marks.sort()
	var out := []
	var worst := 0
	for i in range(1, marks.size()):
		worst = maxi(worst, int(marks[i]) - int(marks[i - 1]))
	if worst > max_gap:
		out.append("checkpoints %d tiles apart (at most %d): %s" % [worst, max_gap, marks])
	if altars.size() < band.x or altars.size() > band.y:
		out.append("%d altars (%d-%d)" % [altars.size(), band.x, band.y])
	for room in Sealed.parse(str(lv.headers.get("room", ""))):
		var x0 := int(room["x0"])
		var near := false
		for a in altars:
			near = near or (x0 - int(a) >= 0 and x0 - int(a) <= DOOR_ALTAR)
		if not near:
			out.append("no altar within %d tiles of the %s door at %d (altars %s)" % [DOOR_ALTAR, room["kind"], x0, altars])
	return out


static func landmarks_of(roles: String) -> String:
	## A roles header's landmarks: its content (C) left out, a run of one
	## landmark as one ("S C C A C A C V A D B" -> "S A V A D B";
	## common.landmarks_of).
	var out := []
	for r in roles.split(" ", false):
		if r != "C" and (out.is_empty() or out.back() != r):
			out.append(r)
	return " ".join(out)


static func roles_problems(levels: Array) -> Array:
	## A world's regular levels, once any is re-cut (a roles: header): every
	## one declares its roles, and no two share their landmarks (landmarks_of:
	## a content section added or split is no change) or have their altars
	## within ALTAR_NEAR tiles of each other's (the generator holds the same,
	## and that each roles: is what its sections hold).
	var out := []
	if not recut(levels):
		return out
	var sorted := levels.duplicate()
	sorted.sort_custom(func(a, b): return str(a.id) < str(b.id))
	for lv in sorted:
		if str(lv.headers.get("roles", "")).strip_edges() == "":
			out.append("%s declares no roles: (a re-cut world's levels all do)" % lv.id)
	for i in sorted.size():
		for j in range(i + 1, sorted.size()):
			var a: RefCounted = sorted[i]
			var b: RefCounted = sorted[j]
			var la := landmarks_of(str(a.headers.get("roles", "")))
			if la != "" and la == landmarks_of(str(b.headers.get("roles", ""))):
				out.append("%s and %s share their landmarks (%s)" % [a.id, b.id, la])
			var pa := altars_of(a)
			var pb := altars_of(b)
			var near := pa.size() == pb.size()
			for k in pa.size():
				near = near and absi(int(pa[k]) - int(pb[k])) <= ALTAR_NEAR
			if near:
				out.append("%s and %s have their altars within %d tiles of each other's (%s, %s)" % [a.id, b.id, ALTAR_NEAR, pa, pb])
	return out


# ---------------------------------------------------------------- a re-cut world's variety

static func mixed_screens(lv: RefCounted) -> int:
	## How many screens (SCREEN tiles wide, none overlapping: the most a
	## level holds) have MIXED_KINDS kinds of monster or more (common.py).
	var cols := {}
	for e in lv.entities:
		var k := kind_of(e)
		if k == "":
			continue
		var x := int(e["cell"].x)
		if not cols.has(x):
			cols[x] = {}
		cols[x][k] = true
	var n := 0
	var x0 := 0
	while x0 < int(lv.width):
		var kinds := {}
		for x in range(x0, x0 + SCREEN):
			if cols.has(x):
				kinds.merge(cols[x])
		if kinds.size() >= MIXED_KINDS:
			n += 1
			x0 += SCREEN
		else:
			x0 += 1
	return n


static func crowded_screens(lv: RefCounted) -> Array:
	## [Vector2(x0, n)]: each screen (SCREEN tiles from x0) with more than
	## AWAKE_MAX bodies in play in it (in_play: packs at their size).
	var at := {}
	for p in in_play(lv):
		var x := int((p[0] as Vector2i).x)
		at[x] = float(at.get(x, 0.0)) + float(p[2])
	var out := []
	for x0 in range(0, maxi(int(lv.width) - SCREEN, 0) + 1):
		var n := 0.0
		for x in range(x0, x0 + SCREEN):
			n += float(at.get(x, 0.0))
		if n > AWAKE_MAX + 0.000001:
			out.append(Vector2(x0, n))
	return out


static func recut_problems(levels: Array) -> Array:
	## A re-cut world's variety rules (common.world_problems), [] for a world
	## that isn't: the fodder ceilings falling X-1 > X-2 > X-3 and at most
	## FODDER_CAPS; its X-3 with MIXED_SCREENS screens of MIXED_KINDS kinds;
	## no screen of an X-1..X-3 with more than AWAKE_MAX in play.
	var out := []
	if not recut(levels):
		return out
	var sorted := levels.duplicate()
	sorted.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var last := []
	for lv in sorted:
		var n := level_no(str(lv.id))
		var r := roster_of(lv)
		if r.has("fodder_max"):
			var fm := float(r["fodder_max"])
			if n >= 1 and n <= FODDER_CAPS.size() and fm > float(FODDER_CAPS[n - 1]) + 0.000001:
				out.append("%s: fodder_max %s (an X-%d at most %s)" % [lv.id, fm, n, FODDER_CAPS[n - 1]])
			if not last.is_empty() and fm >= float(last[1]) - 0.000001:
				out.append("%s: fodder_max %s, not under %s's %s (it falls X-1 to X-3)" % [lv.id, fm, last[0], last[1]])
			last = [lv.id, fm]
		if n == 3 and mixed_screens(lv) < MIXED_SCREENS:
			out.append("%s: %d screens with %d kinds or more (an X-3 mixes: at least %d)" % [lv.id, mixed_screens(lv), MIXED_KINDS, MIXED_SCREENS])
		if n >= 1:
			var crowd := crowded_screens(lv)
			if not crowd.is_empty():
				var worst: Vector2 = crowd[0]
				for c in crowd:
					if c.y > worst.y:
						worst = c
				out.append("%s: %s in play on the screen from x %d (at most %d a screen)" % [lv.id, worst.y, int(worst.x), AWAKE_MAX])
	return out


static func world_problems(levels: Array, ramp := -1.0) -> Array:
	## A world's regular levels against every rule across them: the threat
	## (threat_problems), the roles (roles_problems) and, once re-cut, the
	## variety (recut_problems). The test of each world (test_w3 .. test_w6)
	## and test_core's sweep of every world call it.
	return threat_problems(levels, ramp) + roles_problems(levels) + recut_problems(levels)


# ---------------------------------------------------------------- sealed rooms

static func room_problems(lv: RefCounted) -> Array:
	## Every sealed room of its room: header (features/sealed.gd parse), as
	## common.room_problems: a monster in it; a way in at an end; every
	## doorway cell (each end column between ceiling and floor) air or stone
	## that never opens (DOOR_SOLID: no water, vine, ledge, crumble,
	## dawnglass, brick, false stone, rime or glass); no monster of it within
	## Sealed.DOOR_CLEAR columns of either end; an altar within
	## Sealed.ALTAR_REACH tiles before its door.
	var out := []
	var altars := altars_of(lv)
	for spec in Sealed.parse(str(lv.headers.get("room", ""))):
		var x0: int = spec["x0"]
		var x1: int = spec["x1"]
		var rows: Array = spec["rows"]
		var y0: int = 0 if rows.is_empty() else int(rows[0])
		var y1: int = lv.height - 1 if rows.is_empty() else int(rows[1])
		var tag := "%s: the %s at %d-%d" % [lv.id, spec["kind"], x0, x1]
		var monsters := []
		for e in lv.entities:
			var c: Vector2i = e["cell"]
			if (str(e["kind"]) == "dread" or kind_of(e) != "") and c.x >= x0 and c.x <= x1 and c.y >= y0 and c.y <= y1:
				monsters.append(c)
		if monsters.is_empty():
			out.append("%s holds no monster" % tag)
		var door := 0
		for x in [x0, x1]:
			for y in (range(0, lv.height - 1) if rows.is_empty() else range(y0 + 1, y1)):
				var t: int = lv.tile(x, y)
				if t == LevelData.AIR:
					door += 1
				elif not DOOR_SOLID.has(t):
					out.append("%s: its doorway cell %d,%d is tile %d (air, or stone that never opens)" % [tag, x, y, t])
		if door == 0:
			out.append("%s has no way in" % tag)
		var near := monsters.filter(func(c): return c.x - x0 <= Sealed.DOOR_CLEAR or x1 - c.x <= Sealed.DOOR_CLEAR)
		if not near.is_empty():
			out.append("%s has monsters within %d columns of a door %s" % [tag, Sealed.DOOR_CLEAR, near])
		if not altars.any(func(ax): return ax >= x0 - Sealed.ALTAR_REACH and ax < x0):
			out.append("%s has no altar within %d tiles before its door (altars %s)" % [tag, Sealed.ALTAR_REACH, altars])
	return out


# ---------------------------------------------------------------- every header at once

static func header_problems(lv: RefCounted) -> Array:
	## A level file's own Build 2 headers, whatever level it is (test_core's
	## sweep): its anoint:, twist: and lesson:, roster: and room: rules.
	return anoint_problems(lv) + twist_problems(lv) + roster_problems(lv) + room_problems(lv)
