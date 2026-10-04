extends RefCounted
## Build 2's level rules (not a test: test_w3 .. test_w6, test_progression,
## test_export, test_secrets and test_toolkit preload it). Each level file is
## held to what its own headers declare, written by tools/levels/common.py
## (world_tables, anoint_header, span), instead of fixed counts, widths and
## altar x; the generator checks the same as it writes (common.check_entry,
## world_problems), and these read the file back. A level that declares
## nothing has nothing checked here.
##
##   roster: headline=a,b; support=c; guest=d; rattle_max=3; fodder_max=0.75; count=18-24
##           every placed kind declared (a Rattle up to rattle_max, one Lidlurk:
##           the vault), each headline kind placed; from World 3 a headline
##           kind the world's own, a guest an earlier world's (HOME); the
##           fodder share (EnemyKinds.ROLE) and the count within theirs
##   threat: 11.5   the cost per 100 tiles within THREAT_SLACK of it, a forced
##           Anointed at TIER_COST's x2.5, and a world's X-1..X-3 ramping
##   anoint: x,y[:Omen+Omen[:Name]]; x,y   forced Anointed: an anointable kind,
##           Omens from its Dusk pool there (elites.gd omen_pool)
##   roles:  S C A ...   a re-cut level's section roles: no two alike in a world
##   room:   duel x0-x1 ...; ambush ...   the sealed rooms (features/sealed.gd
##           parse): an altar by each one's door
##   twist: packs   pack kinds budgeted at PACK_SIZE a placed pack

const LevelData := preload("res://scripts/level_data.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const Elites := preload("res://scripts/elites.gd")
const Sealed := preload("res://scripts/features/sealed.gd")
# common.py's numbers (THREAT_SLACK, RAMP_STEP, RAMP_TOL, PACK_SIZE, ALTARS,
# DOOR_ALTAR, HOME): the generator's checks and these are one rule.
const THREAT_SLACK := 0.10
const RAMP_STEP := 0.0
const RAMP_TOL := 0.25
const PACK_SIZE := {"hushling": 3, "glassmite": 3, "creepbone": 2, "unwick": 2}
const PACK_TILES := 4
const ALTARS := Vector2i(3, 5)
const DOOR_ALTAR := 8
const HOME := {"brinejaw": 2, "rootling": 3, "weepcap": 3, "rattlehound": 3, "creepbone": 3,
		"tickwind": 4, "spurwheel": 4, "frostbuckle": 4, "hoarowl": 4,
		"glassmite": 5, "gustling": 5, "refractor": 5, "paneguard": 5,
		"hushling": 6, "stillmaw": 6, "unwick": 6, "lurecoil": 6}
const ROSTER_KEYS := ["headline", "support", "guest", "rattle_max", "fodder_max", "count"]


static func home_of(kind: String) -> int:
	return int(HOME.get(kind, 1))


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
	## Its roster: header, {} when it has none: {headline, support, guest:
	## [kinds], rattle_max: int, fodder_max: float, count: Vector2i (lo, hi),
	## unknown: [keys it doesn't know]}.
	var raw := str(lv.headers.get("roster", "")).strip_edges()
	if raw == "":
		return {}
	var out := {"headline": [], "support": [], "guest": [], "unknown": []}
	for part in raw.split(";", false):
		var kv := part.split("=", true, 1)
		var k := kv[0].strip_edges()
		var v := kv[1].strip_edges() if kv.size() > 1 else ""
		match k:
			"headline", "support", "guest":
				out[k] = Array(v.split(",", false)).map(func(s): return str(s).strip_edges())
			"rattle_max":
				out[k] = int(v)
			"fodder_max":
				out[k] = float(v)
			"count":
				var ab := v.split("-")
				out[k] = Vector2i(int(ab[0]), int(ab[ab.size() - 1]))
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
	for k in ["rattle_max", "fodder_max"]:
		if not r.has(k):
			out.append("the roster has no %s" % k)
	if (r["headline"] as Array).is_empty():
		out.append("the roster has no headline")
	if not out.is_empty():
		return out
	var listed: Array = (r["headline"] as Array) + (r["support"] as Array) + (r["guest"] as Array)
	for k in listed:
		if k in ["skeleton", "lidlurk"] or not EnemyKinds.COST.has(k):
			out.append("%s is listed (a Rattle is rattle_max, a Lidlurk the vault, else no kind)" % k)
	var cast := cast_of(lv)
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
		elif not listed.has(k):
			out.append("%d %s it does not declare" % [c, k])
	for k in r["headline"]:
		if int(cast.get(k, 0)) == 0:
			out.append("no %s, a headline kind" % k)
	if w >= 3:
		for k in r["headline"]:
			if home_of(k) != w:
				out.append("%s is World %d's, no headline in World %d" % [k, home_of(k), w])
		for k in r["guest"]:
			if home_of(k) >= w:
				out.append("%s is no guest from an earlier world" % k)
		for k in r["support"]:
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
	## Each anoint: cell holds a kind elites.gd may anoint (ELIGIBLE), with
	## Omens from its Dusk pool in the level's world (omen_pool: so no
	## difficulty falls back to a roll), distinct, at most MAX_OMENS, and a
	## name with no ; : or , and 24 letters at most; World 1-2 at most one,
	## with one Omen, and none in 1-1.
	var w: int = int(lv.world) if world < 0 else world
	var cells := anoint_of(lv)
	var out := []
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


static func threat_of(lv: RefCounted, tiles := -1.0) -> float:
	## Threat cost per 100 tiles (EnemyKinds.cost, the Dread aside), as
	## common.threat_of counts it: an anoint: cell at TIER_COST's x2.5, and
	## under twist: packs each placed pack of a PACK_SIZE kind at that size at
	## least. tiles: the stretch it's spread over (the level's width; a boss
	## level's approach).
	var forced := forced_cells(lv)
	var packs_on := str(lv.headers.get("twist", "")).strip_edges() == "packs"
	var cost := 0.0
	var packs := {}
	for e in lv.entities:
		var k := kind_of(e)
		if k == "":
			continue
		cost += EnemyKinds.cost(k, "anointed" if forced.has(e["cell"]) else "")
		if packs_on and PACK_SIZE.has(k):
			if not packs.has(k):
				packs[k] = []
			(packs[k] as Array).append(e["cell"])
	for k in packs:
		for g in pack_groups(packs[k]):
			cost += EnemyKinds.cost(k) * maxi(0, int(PACK_SIZE[k]) - (g as Array).size())
	return cost * 100.0 / (float(lv.width) if tiles <= 0.0 else tiles)


static func declared_threat(lv: RefCounted) -> float:
	## Its threat: header (-1 with none).
	var raw := str(lv.headers.get("threat", "")).strip_edges()
	return float(raw) if raw.is_valid_float() else -1.0


static func threat_problems(levels: Array) -> Array:
	## Each level with a threat: header measured within THREAT_SLACK of it,
	## and the declared ones ramping in id order (X-1, X-2, X-3: each at least
	## RAMP_STEP over the one before, less RAMP_TOL).
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
		if not prev.is_empty() and want < float(prev[1]) + RAMP_STEP - RAMP_TOL:
			out.append("%s's threat %s after %s's %s (the ramp: +%s, less %s)" % [lv.id, want, prev[0], prev[1], RAMP_STEP, RAMP_TOL])
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


static func checkpoint_problems(lv: RefCounted, max_gap: int) -> Array:
	## A regular level's checkpoints (start, altars, bell): at most max_gap
	## apart, ALTARS altars, and an altar at most DOOR_ALTAR tiles before
	## every sealed room's door (the left column of each room in its room:
	## header, as features/sealed.gd reads it).
	var marks: Array = [int(lv.start.x)]
	var altars := []
	for e in lv.entities:
		if e["kind"] == "altar":
			altars.append(int(e["cell"].x))
		elif e["kind"] == "bell" or e["kind"] == "boss":
			marks.append(int(e["cell"].x))
	marks.append_array(altars)
	marks.sort()
	altars.sort()
	var out := []
	var worst := 0
	for i in range(1, marks.size()):
		worst = maxi(worst, int(marks[i]) - int(marks[i - 1]))
	if worst > max_gap:
		out.append("checkpoints %d tiles apart (at most %d): %s" % [worst, max_gap, marks])
	if altars.size() < ALTARS.x or altars.size() > ALTARS.y:
		out.append("%d altars (%d-%d)" % [altars.size(), ALTARS.x, ALTARS.y])
	for room in Sealed.parse(str(lv.headers.get("room", ""))):
		var x0 := int(room["x0"])
		var near := false
		for a in altars:
			near = near or (x0 - int(a) >= 0 and x0 - int(a) <= DOOR_ALTAR)
		if not near:
			out.append("no altar within %d tiles of the %s door at %d (altars %s)" % [DOOR_ALTAR, room["kind"], x0, altars])
	return out


static func roles_problems(levels: Array) -> Array:
	## No two of a world's re-cut levels (a roles: header) share their
	## section roles (the generator holds them to their siblings too).
	var out := []
	var by := {}
	for lv in levels:
		var r := " ".join(str(lv.headers.get("roles", "")).split(" ", false))
		if r == "":
			continue
		if by.has(r):
			out.append("%s and %s share their section roles (%s)" % [by[r], lv.id, r])
		by[r] = lv.id
	return out
