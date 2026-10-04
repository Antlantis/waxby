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
##
## Build 2's shapes (shape_problems; common.py shape_problems): 15 to 36
## rows; no goal under the HUD's top corners where the camera stops; a
## level taller than a strip keeps the descent rules (its goal reached with
## no fall over MAX_DROP rows; from every landing the walk map reaches, a
## way out) and the catch rules (a floor that gives way drops him at most
## CATCH_ROWS, onto a landing with no monster within CATCH_CLEAR); facing:
## left or right, a level facing left starting right of its bell. A taller
## level's checkpoints are measured along its route, its screens are
## SCREEN_ROWS tall, and its sealed rooms are met by the door its route
## comes in by (scripts/walk_map.gd); a strip's as before (x, its height,
## its left door; facing left its right). A taller level's threat is per
## tile of its route on foot, not of its width (a loop's two storeys, a
## switchback's tiers, a tower's climb are walked); its screens are the
## views over the rows he can stand on (two roads or decks a screen apart
## never count together); a door altar stands on the deck he comes in on.
## A level with two ways through names its roads (`roads:`, WalkMap.roads):
## its threat, gaps and XP are each road's own (road_of: a cell's nearest
## road; the stretches they share, every road's), the heavier road's
## threat, the widest gap. The boss and secret levels (x-4, x-S) stay
## strips (STRIP_ONLY). A level's own descent keys (max_drop:, landing:,
## lit_drops:; common.descent_limits), drops: where its route drops through
## a one-way ledge, a taller level's waxfalls off its drops, a dark level's
## roads lit apart, and its clockwork's column keys kept apart
## (clockwork_problems) are held as common.py writes them.

const LevelData := preload("res://scripts/level_data.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const Elites := preload("res://scripts/elites.gd")
const Sealed := preload("res://scripts/features/sealed.gd")
const Twists := preload("res://scripts/twists.gd")
const WalkMap := preload("res://scripts/walk_map.gd")
const LevelFeatures := preload("res://scripts/level_features.gd")
const Themes := preload("res://scripts/themes/loader.gd")
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
# Worlds 1-2 stay gentle on Dusk (common.GENTLE_WORLDS): only their X-3's
# fodder is held, under its X-1's and at most GENTLE_X3.
const GENTLE_WORLDS := [1, 2]
const GENTLE_X3 := 0.85
const SCREEN := 26
const MIXED_KINDS := 3
const MIXED_SCREENS := 2
const AWAKE_MAX := 6
# The shapes (common.py's: H_MIN, H_MAX, H, SCREEN_ROWS, MAX_DROP, CATCH_ROWS,
# CATCH_CLEAR, the view and the HUD's corners with the phone's safe-area
# inset both sides, world.gd's feet line and the stone under a level).
const HEIGHT_MIN := 15
const HEIGHT_MAX := 36
const STRIP_ROWS := 15
const SCREEN_ROWS := 12
const MAX_DROP := 5
const CATCH_ROWS := 10
const CATCH_CLEAR := 3
const VIEW := Vector2(844, 390)
const FEET_LINE := 193.0
const BELOW_PX := 160.0
const HUD_LEFT := Rect2(0, 0, 237, 58)
const HUD_RIGHT := Rect2(672, 0, 172, 44)
const GIVE_WAY := [LevelData.CRUMBLE, LevelData.DAWNGLASS, LevelData.GLASS, LevelData.ROTTEN_VINE]
const FEET_UP := 5                 # rows the camera shows over his feet's row, standing (common.FEET_UP)
const FEET_DOWN := 6               # ...and under it
const DESCENT_KEYS := ["max_drop", "landing", "lit_drops"]
# A lit landing's lights (common.LIGHTS): kind -> [radius px, the light's
# height over the cell's floor]; a sconce's flame hangs 7 px under its
# cell's top (world.gd).
const LIGHTS := {"lantern": [140.0, 33.0], "altar": [150.0, 30.0], "vigil": [90.0, 30.0], "sconce": [110.0, 25.0]}
const LAMP_NEAR := 64.0            # px past a lantern's reach: a lily run this near one is by it (common.LAMP_NEAR)
const LIGHT_TOUCH := 2             # a light the route passes this near (WalkMap.near) is lit as he goes (common.LIGHT_TOUCH)
const ONE_WAY_TILES := [LevelData.LEDGE, LevelData.CRUMBLE, LevelData.FROST_LEDGE, LevelData.DAWNGLASS]
const STOREY_ROWS := 6             # a taller level's belt_flip: its belts within these rows (common.STOREY_ROWS)
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
	## level's width; a boss level's approach). A taller level's tiles are its
	## route's length on foot (WalkMap.run_lengths), each road's its own with
	## its own monsters (road_of), the heavier road's the level's.
	var forced := forced_cells(lv)
	var bodies := []
	for p in in_play(lv):
		var k: String = p[1]
		bodies.append([p[0], EnemyKinds.cost(k, "anointed" if forced.has(p[0]) else "") + EnemyKinds.cost(k) * (float(p[2]) - 1.0)])
	var cost := 0.0
	for b in bodies:
		cost += float(b[1])
	if tiles > 0.0 or WalkMap.strip(lv):
		return cost * 100.0 / (float(lv.width) if tiles <= 0.0 else tiles)
	var m = WalkMap.of(lv)
	var best := -1.0
	var roads: Array = m.roads()
	for i in roads.size():
		var path: Array = roads[i]["path"]
		var run: float = float(m.run_lengths(path).back()) if not path.is_empty() else 0.0
		if run <= 0.0:
			continue
		var c := 0.0
		for b in bodies:
			if (m.road_of(b[0]) as Array).has(i):
				c += float(b[1])
		best = maxf(best, c * 100.0 / run)
	return best if best >= 0.0 else cost * 100.0 / float(lv.width)


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


static func checkpoint_gaps(lv: RefCounted) -> Dictionary:
	## {marks, gaps, worst}: a level's checkpoints (start, altars, bell or
	## boss) in its route's order and how far apart they are on it: a
	## strip's by x (either way), a taller level's along the walk map's route
	## (each at its nearest index, WalkMap.proj; the columns walked and rows
	## climbed between: run_lengths; common.checkpoint_gaps). marks: x in a
	## strip, the distance along the route in a taller level. With roads,
	## the road with the widest gap's (road_gaps has each).
	var best := {}
	for g in road_gaps(lv):
		if best.is_empty() or int(g["worst"]) > int(best["worst"]):
			best = g
	return best


static func road_gaps(lv: RefCounted) -> Array:
	## [{road, marks, gaps, worst}]: checkpoint_gaps along each road (its own
	## checkpoints: road_of), "" the one road (common.road_gaps).
	var cells: Array = [lv.start]
	for e in lv.entities:
		if e["kind"] in ["altar", "bell", "boss"]:
			cells.append(e["cell"])
	var out := []
	if WalkMap.strip(lv):
		var xs := []
		for c in cells:
			xs.append(int(c.x))
		out.append(_gaps("", xs))
		return out
	var m = WalkMap.of(lv)
	var roads: Array = m.roads()
	for i in roads.size():
		var path: Array = roads[i]["path"]
		if path.is_empty():
			out.append({"road": roads[i]["name"], "marks": [], "gaps": [1000000], "worst": 1000000})
			continue
		var run: Array = m.run_lengths(path)
		var marks := []
		for c in cells:
			if (m.road_of(c) as Array).has(i):
				marks.append(int(run[_nearest(m, path, c)]))
		out.append(_gaps(str(roads[i]["name"]), marks))
	return out


static func _nearest(m: RefCounted, path: Array, cell: Vector2i) -> int:
	## The index on path nearest cell (as WalkMap.proj; ties to the earlier).
	var best := -1
	var bi := 0
	for i in path.size():
		var c: Vector2i = m.cell_of(path[i])
		var d := absi(c.x - cell.x) + 2 * absi(c.y - cell.y)
		if best < 0 or d < best:
			best = d
			bi = i
	return bi


static func _gaps(road: String, marks: Array) -> Dictionary:
	marks.sort()
	var gaps := []
	var worst := 0
	for i in range(1, marks.size()):
		gaps.append(int(marks[i]) - int(marks[i - 1]))
		worst = maxi(worst, int(gaps.back()))
	return {"road": road, "marks": marks, "gaps": gaps, "worst": worst}


static func road_of(lv: RefCounted, cell: Vector2i) -> Array:
	## The roads a cell is on (indices into WalkMap.roads(); a strip's and a
	## level with no roads: [0]).
	if WalkMap.strip(lv):
		return [0]
	return WalkMap.of(lv).road_of(cell)


static func room_rows(lv: RefCounted, spec: Dictionary) -> Vector2i:
	## A sealed room's rows (its rows header, else the level's).
	var rows: Array = spec["rows"]
	return Vector2i(0, lv.height - 1) if rows.is_empty() else Vector2i(int(rows[0]), int(rows[1]))


static func room_entry(lv: RefCounted, x0: int, x1: int, ys: Vector2i) -> int:
	## The door the route comes in by: -1 the left (x0), +1 the right (x1): a
	## strip's left door (facing left, its right); a taller level's where the
	## walk map's route first steps inside the room's box, from the side it
	## comes from (one it never enters: the way the route runs past it;
	## common.room_entry; WalkMap.entry_of, which boss_arena.gd asks too).
	return WalkMap.entry_of(lv, x0, x1, ys).x


static func door_rows(lv: RefCounted, x: int, ys: Vector2i, row: int) -> Vector2i:
	## The doorway run (its rows) of column x between ys.x and ys.y that the
	## route's entry row comes in at (the run holding it, else the nearest),
	## or (-1, -1): a two-deck room's door on the deck he comes in on
	## (common.door_rows).
	var runs := []
	var y := ys.x
	while y <= ys.y:
		if not LevelData.is_solid(lv.tile(x, y)):
			var a := y
			while y + 1 <= ys.y and not LevelData.is_solid(lv.tile(x, y + 1)):
				y += 1
			runs.append(Vector2i(a, y))
		y += 1
	if runs.is_empty() or row < 0:
		return Vector2i(-1, -1)
	var best: Vector2i = runs[0]
	var bd := 1 << 20
	for r in runs:
		var d := 0 if (row >= r.x and row <= r.y) else mini(absi(row - r.x), absi(row - r.y))
		if d < bd:
			bd = d
			best = r
	return best


static func deck_altar(lv: RefCounted, x0: int, x1: int, ys: Vector2i, cells: Array) -> String:
	## A taller level's sealed room: of the altar cells before its door (cells),
	## is one on the deck he comes in on (in that door's rows, or the row
	## over them)? "" when one is (or in a strip), else the problem.
	var e := WalkMap.entry_of(lv, x0, x1, ys)
	if WalkMap.strip(lv) or e.y < 0 or cells.is_empty():
		return ""
	var door := x0 if e.x < 0 else x1
	var band := door_rows(lv, door, ys, e.y)
	if band.x < 0:
		return ""
	for c in cells:
		if (c as Vector2i).y >= band.x - 1 and (c as Vector2i).y <= band.y:
			return ""
	return "no altar on the deck of its door at %d (its doorway rows %d-%d; altars %s)" % [door, band.x, band.y, cells]


static func checkpoint_problems(lv: RefCounted, max_gap: int, band := ALTARS) -> Array:
	## A regular level's checkpoints (start, altars, bell): at most max_gap
	## apart along its route (checkpoint_gaps: x in a strip; with roads, along
	## each road), band altars (ALTARS), and an altar at most DOOR_ALTAR tiles
	## before every sealed room's door (the one its route comes in by:
	## room_entry; a strip's left column, as features/sealed.gd reads it), in
	## a taller level on the deck he comes in on (deck_altar).
	var altars := altars_of(lv)
	var out := []
	for g in road_gaps(lv):
		if int(g["worst"]) > max_gap:
			out.append("checkpoints %d tiles apart%s (at most %d): %s" % [g["worst"], (" on the %s road" % g["road"]) if str(g["road"]) != "" else "", max_gap, g["marks"]])
	if altars.size() < band.x or altars.size() > band.y:
		out.append("%d altars (%d-%d)" % [altars.size(), band.x, band.y])
	for room in Sealed.parse(str(lv.headers.get("room", ""))):
		var side := room_entry(lv, int(room["x0"]), int(room["x1"]), room_rows(lv, room))
		var door := int(room["x0"]) if side < 0 else int(room["x1"])
		var near := []
		for e in lv.entities:
			var a: Vector2i = e["cell"]
			if e["kind"] == "altar" and (door - a.x) * -side >= 0 and (door - a.x) * -side <= DOOR_ALTAR:
				near.append(a)
		if near.is_empty():
			out.append("no altar within %d tiles of the %s door at %d (altars %s)" % [DOOR_ALTAR, room["kind"], door, altars])
		else:
			var deck := deck_altar(lv, int(room["x0"]), int(room["x1"]), room_rows(lv, room), near)
			if deck != "":
				out.append("the %s: %s" % [room["kind"], deck])
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

static func screen_rows(lv: RefCounted, x0 := -1, width := SCREEN) -> Array:
	## [Vector2i(y0, y1)]: the rows a screen spans (inclusive): a strip's one
	## screen is its whole height (its camera shows it all as it goes); a
	## taller level's are the views over each row he can stand on
	## (WalkMap.stand) in the columns x0..x0+width-1 (every column with x0 <
	## 0): FEET_UP rows over it and FEET_DOWN under (SCREEN_ROWS in all; at
	## the level's top the camera stops, so its first SCREEN_ROWS rows), so
	## two roads or decks a screen apart never count together where he can't
	## see both (common.screen_rows). A test's per-screen caps count in these.
	if int(lv.height) <= STRIP_ROWS:
		return [Vector2i(0, lv.height - 1)]
	var m = WalkMap.of(lv)
	var feet := {}
	for x in range(maxi(x0, 0) if x0 >= 0 else 0, mini(x0 + width, int(lv.width)) if x0 >= 0 else int(lv.width)):
		for y in int(lv.height):
			if m.stand(x, y):
				feet[y] = true
	var ys := feet.keys()
	ys.sort()
	var out := []
	for f in ys:
		var y0 := maxi(0, int(f) - FEET_UP)
		var y1 := mini(int(lv.height) - 1, (y0 + SCREEN_ROWS - 1) if int(f) - FEET_UP < 0 else int(f) + FEET_DOWN)
		if not out.has(Vector2i(y0, y1)):
			out.append(Vector2i(y0, y1))
	return out


static func in_rows(c: Vector2i, ys: Vector2i) -> bool:
	return c.y >= ys.x and c.y <= ys.y


static func mixed_screens(lv: RefCounted) -> int:
	## How many screens (SCREEN tiles wide, none overlapping: the most a
	## level holds; screen_rows tall) have MIXED_KINDS kinds of monster or
	## more (common.py).
	var cols := {}
	for e in lv.entities:
		var k := kind_of(e)
		if k == "":
			continue
		var x := int(e["cell"].x)
		if not cols.has(x):
			cols[x] = []
		(cols[x] as Array).append([e["cell"], k])
	var n := 0
	var x0 := 0
	while x0 < int(lv.width):
		var most := 0
		for ys in screen_rows(lv, x0):
			var kinds := {}
			for x in range(x0, x0 + SCREEN):
				for ck in cols.get(x, []):
					if in_rows(ck[0], ys):
						kinds[ck[1]] = true
			most = maxi(most, kinds.size())
		if most >= MIXED_KINDS:
			n += 1
			x0 += SCREEN
		else:
			x0 += 1
	return n


static func crowded_screens(lv: RefCounted) -> Array:
	## [Vector2(x0, n)]: each screen (SCREEN tiles from x0, screen_rows tall)
	## with more than AWAKE_MAX bodies in play in it (in_play: packs at their
	## size).
	var at := {}
	for p in in_play(lv):
		var x := int((p[0] as Vector2i).x)
		if not at.has(x):
			at[x] = []
		(at[x] as Array).append(p)
	var out := []
	for x0 in range(0, maxi(int(lv.width) - SCREEN, 0) + 1):
		for ys in screen_rows(lv, x0):
			var n := 0.0
			for x in range(x0, x0 + SCREEN):
				for p in at.get(x, []):
					if in_rows(p[0], ys):
						n += float(p[2])
			if n > AWAKE_MAX + 0.000001:
				out.append(Vector2(x0, n))
	return out


static func recut_problems(levels: Array) -> Array:
	## A re-cut world's variety rules (common.world_problems), [] for a world
	## that isn't: the fodder ceilings falling X-1 > X-2 > X-3 and at most
	## FODDER_CAPS (in GENTLE_WORLDS only the X-3's: under the X-1's and
	## GENTLE_X3); its X-3 with MIXED_SCREENS screens of MIXED_KINDS kinds;
	## no screen of an X-1..X-3 with more than AWAKE_MAX in play.
	var out := []
	if not recut(levels):
		return out
	var sorted := levels.duplicate()
	sorted.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var last := []
	var before := []
	for lv in sorted:
		var n := level_no(str(lv.id))
		var r := roster_of(lv)
		if r.has("fodder_max"):
			var fm := float(r["fodder_max"])
			if GENTLE_WORLDS.has(int(lv.world)):
				if n == 3:
					if fm > GENTLE_X3 + 0.000001:
						out.append("%s: fodder_max %s (a gentle world's X-3 at most %s)" % [lv.id, fm, GENTLE_X3])
					for b in before:
						if level_no(str(b[0])) == 1 and fm >= float(b[1]) - 0.000001:
							out.append("%s: fodder_max %s, not under %s's %s (a gentle world's X-3 under its X-1)" % [lv.id, fm, b[0], b[1]])
				before.append([lv.id, fm])
			else:
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
	## Sealed.ALTAR_REACH tiles before the door its route comes in by
	## (room_entry: a strip's left, facing left its right).
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
		var side := room_entry(lv, x0, x1, Vector2i(y0, y1))
		var before := []
		for e in lv.entities:
			var ax: int = e["cell"].x
			if e["kind"] == "altar" and ((ax >= x0 - Sealed.ALTAR_REACH and ax < x0) if side < 0 else (ax > x1 and ax <= x1 + Sealed.ALTAR_REACH)):
				before.append(e["cell"])
		if before.is_empty():
			out.append("%s has no altar within %d tiles before its %s door (altars %s)" % [tag, Sealed.ALTAR_REACH, "left" if side < 0 else "right", altars])
		else:
			var deck := deck_altar(lv, x0, x1, Vector2i(y0, y1), before)
			if deck != "":
				out.append("%s has %s" % [tag, deck])
	return out


# ---------------------------------------------------------------- every header at once

static func header_problems(lv: RefCounted) -> Array:
	## A level file's own Build 2 headers, whatever level it is (test_core's
	## sweep): its anoint:, twist: and lesson:, roster: and room: rules, and
	## its clockwork's column keys (clockwork_problems).
	return anoint_problems(lv) + twist_problems(lv) + roster_problems(lv) + room_problems(lv) + clockwork_problems(lv)


static func clockwork_problems(lv: RefCounted) -> Array:
	## What its clockwork headers can't tell apart (common.clockwork_problems):
	## cog_phase and weight_phase are keyed by column (level_data.gd), so no
	## two cog hubs share a column, nor two weights or swings (a swing by its
	## first); in a taller level a belt_flip span reverses one storey's belts
	## (features/clockwork.gd reverse_belts takes its every column: its belts
	## within STOREY_ROWS rows of each other).
	var out := []
	var hubs := {}
	var keys := {}
	for e in lv.entities:
		var c: Vector2i = e["cell"]
		var into = hubs if e["kind"] == "cog" else (keys if e["kind"] in ["weight", "swing"] else null)
		if into == null:
			continue
		if not into.has(c.x):
			into[c.x] = []
		(into[c.x] as Array).append(c.y)
	for x in hubs:
		if (hubs[x] as Array).size() > 1:
			out.append("%s: two cog hubs in column %d (rows %s): cog_phase is keyed by column" % [lv.id, x, hubs[x]])
	for x in keys:
		if (keys[x] as Array).size() > 1:
			out.append("%s: two weights or swings in column %d (rows %s): weight_phase is keyed by column" % [lv.id, x, keys[x]])
	if not WalkMap.strip(lv):
		for r in ranges_of(str(lv.headers.get("belt_flip", ""))):
			var lo := 1 << 20
			var hi := -1
			for x in range(r.x, r.y + 1):
				for y in lv.height:
					if lv.tile(x, y) in [LevelData.BELT_L, LevelData.BELT_R]:
						lo = mini(lo, y)
						hi = maxi(hi, y)
			if hi - lo > STOREY_ROWS:
				out.append("%s: belt_flip %d-%d reverses belts on rows %d and %d (two storeys)" % [lv.id, r.x, r.y, lo, hi])
	return out


# ---------------------------------------------------------------- shapes

static func height_ok(lv: RefCounted) -> bool:
	## 15 to 36 rows, and a boss or secret level (strip_only) a strip.
	if strip_only(str(lv.id)):
		return int(lv.height) == STRIP_ROWS
	return int(lv.height) >= HEIGHT_MIN and int(lv.height) <= HEIGHT_MAX


static func strip_only(id: String) -> bool:
	## The boss and secret levels (x-4, x-S) stay strips: their rooms, doors,
	## root walls and Warden rooms are cut for 15 rows (common.STRIP_ONLY;
	## the plan reshapes the 18 regular levels only).
	return id.length() == 3 and "123456789".contains(id[0]) and id[1] == "-" and (id[2] == "4" or id[2] == "S")


static func goal_rects(lv: RefCounted) -> Array:
	## [[what, cell, Rect2 px]]: each goal as drawn: a sigil its cell, the bell
	## its beam and bell over its floor (world.gd add_bell), a silver bell its
	## smaller one (common.goal_rects).
	var out := []
	for e in lv.entities:
		var c: Vector2i = e["cell"]
		var fx := c.x * 32.0 + 16.0
		var fy := (c.y + 1) * 32.0
		match str(e["kind"]):
			"sigil":
				out.append(["sigil %d" % (int(e["index"]) + 1), c, Rect2(c.x * 32.0, c.y * 32.0, 32.0, 32.0)])
			"bell":
				out.append(["bell", c, Rect2(fx - 32.0, fy - 105.0, 64.0, 105.0)])
			"silver_bell":
				out.append(["silver bell", c, Rect2(fx - 16.0, fy - 70.0, 32.0, 70.0)])
	return out


static func hud_problems(lv: RefCounted) -> Array:
	## Each goal under the HUD's top corners where the camera stops: with him
	## at the goal (his feet on its floor), the camera holding his feet on
	## FEET_LINE but stopped at the level's top (and bottom), and its x on him
	## (70 px ahead either way) but stopped at the level's sides
	## (common.hud_problems).
	var w := float(lv.width) * 32.0
	var h := float(lv.height) * 32.0
	var out := []
	for g in goal_rects(lv):
		var r: Rect2 = g[2]
		var top := minf(maxf(0.0, r.end.y - FEET_LINE), maxf(0.0, h + BELOW_PX - VIEW.y))
		var hit := ""
		for look in [-70.0, 70.0]:
			var cx := (w - VIEW.x) / 2.0 if w <= VIEW.x else minf(maxf(r.get_center().x - VIEW.x / 2.0 + look, 0.0), w - VIEW.x)
			var vr := Rect2(r.position - Vector2(cx, top), r.size)
			# (Open on the far edges, as common.py's strict compares.)
			if hit == "" and vr.position.x < HUD_LEFT.end.x and vr.end.x > HUD_LEFT.position.x and vr.position.y < HUD_LEFT.end.y and vr.end.y > HUD_LEFT.position.y:
				hit = "left"
			if hit == "" and vr.position.x < HUD_RIGHT.end.x and vr.end.x > HUD_RIGHT.position.x and vr.position.y < HUD_RIGHT.end.y and vr.end.y > HUD_RIGHT.position.y:
				hit = "right"
		if hit != "":
			out.append("the %s at %s is under the HUD's top %s corner where the camera stops" % [g[0], g[1], hit])
	return out


static func descent_problems(lv: RefCounted) -> Array:
	## A taller level's descent rules: its goal reached with no fall over
	## MAX_DROP rows (what he sees under his feet standing: a required drop's
	## landing is in view), and from every landing the walk map reaches a way
	## out (a fall inside a tall level isn't a snuff; common.descent_problems).
	var m = WalkMap.of(lv)
	var g: Vector2i = m.goal()
	if m.start() < 0 or g.x < 0:
		return ["no start on a floor, or no goal (bell, boss or silver bell)"]
	var out := []
	var fair: Dictionary = m.reach(MAX_DROP)
	if not fair.keys().any(func(s): return m.touches(s, [g])):
		out.append("the goal at %s needs a drop of more than %d rows" % [g, MAX_DROP])
	var edges: Dictionary = m.reach()
	var exits: Array = m.exits()
	var ends := edges.keys().filter(func(s): return m.touches(s, exits))
	if ends.is_empty():
		return out + ["the walk map finds no way from the start to the goal"]
	var back := {}
	for s in edges:
		for t in edges[s]:
			if not back.has(t[0]):
				back[t[0]] = []
			(back[t[0]] as Array).append(s)
	var seen := {}
	var todo := ends.duplicate()
	for s in ends:
		seen[s] = true
	while not todo.is_empty():
		var t: int = todo.pop_back()
		for s in back.get(t, []):
			if not seen.has(s):
				seen[s] = true
				todo.append(s)
	var stuck := []
	for s in edges:
		if not seen.has(s) and not m.on_vine(s):
			stuck.append(m.cell_of(s))
	if not stuck.is_empty():
		stuck.sort()
		out.append("%d landings lead nowhere (no way out from them), e.g. %s" % [stuck.size(), stuck.slice(0, 6)])
	return out


static func _landing(m: RefCounted, x: int, y: int) -> int:
	## The row a fall from just under (x, y) ends on (a floor, or a vine
	## caught), -1 for no fall or a snuff.
	var yy := y + 1
	while yy < m.h:
		if m.solid(x, yy) or m.hazard(x, yy):
			return -1
		if m.climb(x, yy) or m.support(x, yy + 1):
			return yy
		yy += 1
	return -1


static func _catch_rows(lv: RefCounted, m: RefCounted, x: int, ly: int) -> Array:
	## [Vector2i(y0, y1)]: the rows a catch at (x, ly) can set him down in:
	## ly's, a row either side; on a floor that gives way itself, the next
	## landing's too, and so on; one that ends in water or a hazard, its rows
	## (both of a pool's: a Brinejaw lies in them; common._catch_rows).
	var out := [Vector2i(ly - 1, ly + 1)]
	while ly + 1 < lv.height and GIVE_WAY.has(lv.tile(x, ly + 1)):
		var nxt := _landing(m, x, ly + 1)
		if nxt >= 0:
			ly = nxt
			out.append(Vector2i(ly - 1, ly + 1))
			continue
		var yy := ly + 2
		while yy < lv.height and not m.solid(x, yy) and not m.hazard(x, yy):
			yy += 1
		if yy < lv.height and m.hazard(x, yy):
			out.append(Vector2i(yy - 1, yy + 1))
		break
	return out


static func catch_problems(lv: RefCounted) -> Array:
	## A taller level's catch rules: a fall from a floor that gives way (a
	## crumble, dawnglass, glass, the foot of a rotten run) lands within
	## CATCH_ROWS rows (a catch floor, not the bottom of the climb) or snuffs,
	## and no monster stands within CATCH_CLEAR columns of where it lands, nor,
	## when that landing gives way too, of the next catch or the water it
	## ends in (_catch_rows; common.catch_problems).
	var m = WalkMap.of(lv)
	var mons := {}
	for e in lv.entities:
		if kind_of(e) != "":
			mons[e["cell"]] = true
	var out := []
	var seen := {}
	for y in lv.height:
		for x in lv.width:
			var t: int = lv.tile(x, y)
			if not GIVE_WAY.has(t):
				continue
			if (t == LevelData.ROTTEN_VINE and m.climb(x, y + 1)) or (t != LevelData.ROTTEN_VINE and not m.body(x, y - 1)):
				continue
			var ly := _landing(m, x, y)
			if ly < 0:
				continue
			if ly - y > CATCH_ROWS:
				out.append("a fall through %d,%d lands %d rows down (a catch floor within %d)" % [x, y, ly - y, CATCH_ROWS])
			for span in _catch_rows(lv, m, x, ly):
				for my in range(span.x, span.y + 1):
					for mx in range(x - CATCH_CLEAR, x + CATCH_CLEAR + 1):
						var c := Vector2i(mx, my)
						if mons.has(c) and not seen.has(c):
							seen[c] = true
							out.append("a monster at %s waits where a fall through %d,%d lands" % [c, x, y])
	return out


static func descent_limits(lv: RefCounted) -> Dictionary:
	## {max_drop, landing: Vector2i(columns, rows), lit_drops, problems}: the
	## level's own descent keys read (-1 / (-1, -1) where it has none) and
	## what doesn't read (common.descent_limits).
	var out := {"max_drop": -1, "landing": Vector2i(-1, -1), "lit_drops": -1, "problems": []}
	var hd: Dictionary = lv.headers
	for k in ["max_drop", "lit_drops"]:
		var v := str(hd.get(k, "")).strip_edges()
		if v == "":
			continue
		if v.is_valid_int() and int(v) >= 1 and int(v) <= MAX_DROP:
			out[k] = int(v)
		else:
			(out["problems"] as Array).append("%s '%s' (a number of rows, 1-%d)" % [k, v, MAX_DROP])
	var ld := str(hd.get("landing", "")).strip_edges()
	if ld != "":
		var ab := ld.split("/")
		if ab.size() == 2 and ab[0].strip_edges().is_valid_int() and ab[1].strip_edges().is_valid_int():
			out["landing"] = Vector2i(int(ab[0]), int(ab[1]))
		else:
			(out["problems"] as Array).append("landing '%s' (columns/rows: 6/2)" % ld)
	return out


static func lit_posts_of(lv: RefCounted) -> Array:
	## [Vector2i]: the level's lit posts (`lit_posts: x,y; x,y`: lantern posts
	## lit from the start that never burn down, level_features.gd); a part
	## that doesn't read is left out (common.lit_posts_of names it).
	var out := []
	for part in str(lv.headers.get("lit_posts", "")).split(";", false):
		var xy := part.strip_edges().split(",")
		if xy.size() == 2 and xy[0].strip_edges().is_valid_int() and xy[1].strip_edges().is_valid_int():
			out.append(Vector2i(int(xy[0]), int(xy[1])))
	return out


static func lit_cells(lv: RefCounted) -> Dictionary:
	## {Vector2i: int}: the cells where his middle, standing in them, is in a
	## light's reach (LIGHTS) once it burns, and the route index from which
	## the first light on it burns: a sconce (where the theme's sconces give
	## light: not W6's, world.gd) and a lit post (lit_posts_of) from the
	## start (-1); a lantern, an altar or a Vigil candle (none lit till he
	## touches it) once the route has passed it (proj, when the route comes
	## within LIGHT_TOUCH of it: one it never nears is never lit;
	## common.lit_cells).
	var m = WalkMap.of(lv)
	var path: Array = m.route()
	var steady := lit_posts_of(lv)
	var th := str(lv.theme)
	var sconces: bool = not Themes.has_theme(th) or bool(Themes.theme(th).get("sconce_light", true))
	var srcs := []
	for e in lv.entities:
		var k := str(e["kind"])
		if LIGHTS.has(k):
			var c: Vector2i = e["cell"]
			var cy: float = c.y * 32.0 + 7.0 if k == "sconce" else (c.y + 1) * 32.0 - float(LIGHTS[k][1])
			var i := -1
			if k == "sconce":
				if not sconces:
					continue
			elif not (k == "lantern" and steady.has(c)):
				if path.is_empty() or m.near(path, c) > LIGHT_TOUCH:
					continue
				i = m.proj(c)
			srcs.append([Vector2(c.x * 32.0 + 16.0, cy), float(LIGHTS[k][0]), i])
	var out := {}
	for y in lv.height:
		for x in lv.width:
			var p := Vector2(x * 32.0 + 16.0, (y + 1) * 32.0 - 22.0)
			for sr in srcs:
				if p.distance_squared_to(sr[0]) <= float(sr[1]) * float(sr[1]):
					var c := Vector2i(x, y)
					out[c] = mini(int(out.get(c, 1 << 30)), int(sr[2]))
	return out


static func limit_allow(m: RefCounted, lim: Dictionary, lit: Dictionary) -> Callable:
	## allow(from, to, drop) for WalkMap.reach: the landing and lit_drops
	## rules (descent_limits; common.limit_allow): a lit landing is lit
	## before he gets there, by a sconce or a light the route passed by the
	## state he falls from (lit_cells).
	var ld: Vector2i = lim["landing"]
	var ln: int = int(lim["lit_drops"])
	var at := {}
	return func(s: int, t: int, drop: int) -> bool:
		if drop <= 0:
			return true
		var a: Vector2i = m.cell_of(s)
		var b: Vector2i = m.cell_of(t)
		if ld.x >= 0 and absi(b.x - a.x) > ld.x and drop > ld.y:
			return false
		if ln >= 0 and not m.on_vine(t) and not m.band_at(b.x, b.y + 1):
			if not at.has(s):
				at[s] = m.proj(a)
			return drop <= ln and lit.has(b) and int(lit[b]) <= int(at[s])
		return true


static func own_descent_problems(lv: RefCounted) -> Array:
	## A level's own descent keys kept (its goal reached by falls within
	## them), and drops: where its route drops through a one-way ledge (the
	## bots drop through only then: reach.gd drops_of; common's).
	var lim := descent_limits(lv)
	var out: Array = (lim["problems"] as Array).duplicate()
	var m = WalkMap.of(lv)
	var g: Vector2i = m.goal()
	for part in str(lv.headers.get("lit_posts", "")).split(";", false):
		var xy := part.strip_edges().split(",")
		if xy.size() != 2 or not xy[0].strip_edges().is_valid_int() or not xy[1].strip_edges().is_valid_int():
			out.append("lit_posts '%s' (x,y; x,y)" % part.strip_edges())
	for c in lit_posts_of(lv):
		if not lv.entities.any(func(e): return str(e["kind"]) == "lantern" and e["cell"] == c):
			out.append("lit_posts %d,%d is no lantern post" % [c.x, c.y])
	if out.is_empty() and (int(lim["max_drop"]) >= 0 or (lim["landing"] as Vector2i).x >= 0 or int(lim["lit_drops"]) >= 0):
		var lit := lit_cells(lv) if int(lim["lit_drops"]) >= 0 else {}
		var fair: Dictionary = m.reach(int(lim["max_drop"]), limit_allow(m, lim, lit))
		if not fair.keys().any(func(s): return m.touches(s, [g])):
			var keys := []
			for k in DESCENT_KEYS:
				if str(lv.headers.get(k, "")).strip_edges() != "":
					keys.append("%s %s" % [k, lv.headers[k]])
			out.append("its goal needs a fall past its own descent rules (%s)" % ", ".join(keys))
	var drops := str(lv.headers.get("drops", "")).strip_edges().to_lower() not in ["", "0", "no", "false"]
	var r: Array = m.route()
	for i in range(1, r.size()):
		var a: Vector2i = m.cell_of(r[i - 1])
		var b: Vector2i = m.cell_of(r[i])
		if not m.on_vine(r[i - 1]) and b.x == a.x and b.y > a.y and ONE_WAY_TILES.has(lv.tile(a.x, a.y + 1)) and not drops:
			out.append("its route drops through the one-way ledge at %d,%d: write drops: yes (the bots drop through only then)" % [a.x, a.y + 1])
			break
	return out


static func waxfall_columns(lv: RefCounted) -> Array:
	## [Vector3i(x, y0, y1)]: each waxfall's douse column, its head's row down
	## to the first solid row under it (level_features.gd; common's).
	var out := []
	for e in lv.entities:
		if e["kind"] == "waxfall":
			var c: Vector2i = e["cell"]
			var b := c.y + 1
			while b < lv.height and not LevelData.is_solid(lv.tile(c.x, b)):
				b += 1
			out.append(Vector3i(c.x, c.y, b - 1))
	return out


static func fall_secs(rows_down: int) -> float:
	## The seconds a fall of rows_down rows takes (player.gd GRAVITY_DOWN to
	## MAX_FALL; common._fall_secs).
	var P = load("res://scripts/player.gd")
	var g := float(P.GRAVITY_DOWN)
	var top := float(P.MAX_FALL)
	var d := rows_down * 32.0
	var t1 := top / g
	var d1 := 0.5 * g * t1 * t1
	return sqrt(2.0 * d / g) if d <= d1 else t1 + (d - d1) / top


static func waxfall_problems(lv: RefCounted) -> Array:
	## A taller level's waxfalls off its drops (common.waxfall_problems): its
	## goal reached with no fall landing in a douse column (one never covers
	## the only landing), and a fall on its route through one fits its off
	## window (the fall and a step out of the column at a run).
	var cols := waxfall_columns(lv)
	if cols.is_empty():
		return []
	var m = WalkMap.of(lv)
	var under := func(c: Vector2i) -> bool:
		for k in cols:
			if (k as Vector3i).x == c.x and c.y >= (k as Vector3i).y and c.y <= (k as Vector3i).z:
				return true
		return false
	var out := []
	var dry: Dictionary = m.reach(-1, func(_s: int, t: int, drop: int) -> bool: return drop <= 0 or not under.call(m.cell_of(t)))
	if not dry.keys().any(func(s): return m.touches(s, [m.goal()])):
		out.append("a waxfall's column covers the only landing of a drop on the way to the goal")
	var LF = load("res://scripts/level_features.gd")
	var P = load("res://scripts/player.gd")
	var step := 32.0 / float(P.RUN_SPEED)
	var r: Array = m.route()
	for i in range(1, r.size()):
		var a: Vector2i = m.cell_of(r[i - 1])
		var b: Vector2i = m.cell_of(r[i])
		var drop := b.y - a.y
		if drop <= 0:
			continue
		for k in cols:
			if (k as Vector3i).x == b.x and (k as Vector3i).y <= b.y and (k as Vector3i).z >= a.y and fall_secs(drop) + step > float(LF.FALL_OFF):
				out.append("the drop at %d,%d through a waxfall takes %.2f s and a step (its off window %.1f s)" % [b.x, a.y, fall_secs(drop), float(LF.FALL_OFF)])
				break
	return out


static func light_problems(lv: RefCounted) -> Array:
	## A dark level's roads lit apart (common.light_problems): no lantern on
	## one road alone lights a cell of another's way that's its alone.
	if str(lv.headers.get("twist", "")).strip_edges().to_lower() != "dark":
		return []
	var m = WalkMap.of(lv)
	var roads: Array = m.roads()
	if roads.size() < 2:
		return []
	var rad := float(LIGHTS["lantern"][0])
	var out := []
	for e in lv.entities:
		if e["kind"] != "lantern":
			continue
		var c: Vector2i = e["cell"]
		var mine: Array = m.road_of(c)
		if mine.size() != 1:
			continue
		var lp := Vector2(c.x * 32.0 + 16.0, (c.y + 1) * 32.0 - float(LIGHTS["lantern"][1]))
		for j in roads.size():
			if mine.has(j):
				continue
			for st in roads[j]["path"]:
				var sc: Vector2i = m.cell_of(st)
				if (m.road_of(sc) as Array).has(mine[0]):
					continue
				if Vector2(sc.x * 32.0 + 16.0, (sc.y + 1) * 32.0 - 22.0).distance_to(lp) <= rad:
					out.append("the lantern at %s on the %s road lights the %s road's way at %s" % [c, roads[mine[0]]["name"], roads[j]["name"], sc])
					break
	return out


static func lamp_problems(lv: RefCounted) -> Array:
	## A lamplit level's lilies kept in their lanterns' reach: each run of
	## soft wax by a lantern (a cell within Twists.LAMP_R + LAMP_NEAR px of
	## its flame) held whole, every cell within LAMP_R of some lantern's
	## flame (twists.gd _find_lamp_cells; common.lamp_problems).
	if Twists.id_in(lv) != "lamplit":
		return []
	var flames := []
	for e in lv.entities:
		if str(e["kind"]) == "lantern":
			flames.append(LevelData.cell_floor(e["cell"]) - Vector2(0, LevelFeatures.LANTERN_FLAME))
	var out := []
	for y in lv.height:
		var x := 0
		while x < lv.width:
			if lv.tile(x, y) != LevelData.CRUMBLE:
				x += 1
				continue
			var x1 := x
			while x1 + 1 < lv.width and lv.tile(x1 + 1, y) == LevelData.CRUMBLE:
				x1 += 1
			var by := false
			var dark := []
			for cx in range(x, x1 + 1):
				var mid := LevelData.cell_center(Vector2i(cx, y))
				var held := false
				for f in flames:
					var d: float = (f as Vector2).distance_to(mid)
					by = by or d <= Twists.LAMP_R + LAMP_NEAR
					held = held or d <= Twists.LAMP_R
				if not held:
					dark.append(cx)
			if by and not dark.is_empty():
				out.append("the lily run at %d-%d,%d is by a lantern, but its cells at %s are out of every lantern's reach" % [x, x1, y, dark])
			x = x1 + 1
	return out


static func shape_problems(lv: RefCounted) -> Array:
	## A level's shape rules, whatever its shape (common.shape_problems): its
	## height, the HUD's corners, its facing; a taller level's descent and
	## catch rules too.
	var out := []
	if not height_ok(lv):
		out.append("%s: %d rows (%d-%d%s)" % [lv.id, lv.height, HEIGHT_MIN, HEIGHT_MAX, "; a boss or secret level stays a strip" if strip_only(str(lv.id)) else ""])
	out += hud_problems(lv) + lamp_problems(lv)
	if not WalkMap.strip(lv):
		out += descent_problems(lv) + catch_problems(lv) + own_descent_problems(lv) + waxfall_problems(lv) + light_problems(lv)
		var m = WalkMap.of(lv)
		for r in m.roads():
			if str(r["name"]) != "" and (r["path"] as Array).is_empty():
				out.append("the %s road finds no way to the goal by its cells" % r["name"])
	else:
		out += descent_limits(lv)["problems"]
	var f := str(lv.headers.get("facing", "right")).strip_edges()
	if f != "left" and f != "right":
		out.append("facing '%s' (left or right)" % f)
	elif f == "left":
		for e in lv.entities:
			if e["kind"] in ["bell", "boss"] and int(e["cell"].x) > int(lv.start.x):
				out.append("facing left, but it starts left of its %s (%d, %d)" % [e["kind"], lv.start.x, e["cell"].x])
	return out
