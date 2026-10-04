extends SceneTree
## Build 2's level toolkit (the spec's build_plan steps 2-3): the rules
## tests/level_rules.gd holds every level file to, proven on the toolkit's
## fixture, tests/fixtures/toolkit-cast.txt (tools/levels/toolkit.py: a
## made-up World 6 level cut with swap, stamp, span and anoint_header, and
## carrying every Build 2 key). The generator's side proves itself as it
## builds (common.self_check); this is the file read back:
##   - the headers as written: roster:, threat:, roles:, anoint: with Omens
##     and names, twist:, the sealed room (room:, rooms_header) and the
##     belts' flip (belt_flip:, a span), each read back by the game script
##     that plays it (twists.gd, features/sealed.gd, features/clockwork.gd);
##   - the cast (a nest as its Gutterwing) and each roster rule, shown to
##     catch what it should on edited copies (a Rattle over the cap, a kind
##     it doesn't declare, a missing headline, the fodder share, the count, a
##     later world's headline, a guest that isn't one);
##   - the threat: forced Anointed at x2.5, packs at their size, the 10%
##     band and the X-1..X-3 ramp, all to the tile (40.5 over 162 tiles);
##   - checkpoints: the gap, 3-5 altars, an altar by a sealed room's door;
##   - the anoint: cells' rules (an anointable kind, Omens from its Dusk
##     pool, World 1-2's limit) and no two re-cut levels' roles alike;
##   - the stamps where they were drawn, standing where PLACEMENT says.
##
##     godot --headless --path game --script res://tests/test_toolkit.gd

const LevelData := preload("res://scripts/level_data.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const Rules := preload("res://tests/level_rules.gd")
const Twists := preload("res://scripts/twists.gd")
const Sealed := preload("res://scripts/features/sealed.gd")
const Clockwork := preload("res://scripts/features/clockwork.gd")
const FIXTURE := "res://tests/fixtures/toolkit-cast.txt"
const WIDTH := 162
const MAX_GAP := 78

var _passed := 0
var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	if not FileAccess.file_exists(FIXTURE):
		_check(false, "the toolkit's fixture %s is written (tools/make_levels.py runs tools/levels/toolkit.py)" % FIXTURE)
	else:
		_test_headers()
		_test_roster()
		_test_threat()
		_test_checkpoints()
		_test_anoint()
		_test_stamps()
	print("test_toolkit: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _lv(id := "") -> RefCounted:
	## The fixture, fresh (each test edits its own copy); id: a level id to
	## read it as (its world then follows), else World 6, as toolkit.py
	## declares it.
	var lv: RefCounted = LevelData.load_file(FIXTURE)
	if id != "":
		lv.id = id
		lv.world = LevelData.world_of(id)
	else:
		lv.world = 6
	return lv


func _with(lv: RefCounted, key: String, value: String) -> RefCounted:
	lv.headers[key] = value
	return lv


func _has(problems: Array, what: String) -> bool:
	for p in problems:
		if str(p).contains(what):
			return true
	return false


func _c(kind: String) -> float:
	return float(EnemyKinds.COST[kind])


# ---------------------------------------------------------------- tests

func _test_headers() -> void:
	var lv := _lv()
	_check(lv.errors.is_empty() and lv.width == WIDTH and lv.height == 15, "the fixture parses, %d x 15 (%s)" % [WIDTH, lv.errors])
	_check(str(lv.headers.get("twist", "")) == "packs", "twist: passes through (%s)" % lv.headers.get("twist", ""))
	_check(Twists.id_in(lv) == "packs", "and twists.gd reads it as its packs twist (%s)" % Twists.id_in(lv))
	_check(str(lv.headers.get("room", "")) == "duel 106-129", "room: the sealed room's columns from rooms_header(TK_ROOM), walls and all (%s)" % lv.headers.get("room", ""))
	var rooms: Array = Sealed.parse(str(lv.headers.get("room", "")))
	_check(rooms.size() == 1 and rooms[0]["kind"] == "duel" and rooms[0]["x0"] == 106 and rooms[0]["x1"] == 129,
			"and features/sealed.gd reads one duel there (%s)" % [rooms])
	_check(str(lv.headers.get("belt_flip", "")) == "62-69=8", "belt_flip: a span with its beats, x0-x1=N (%s)" % lv.headers.get("belt_flip", ""))
	var flips: Array = Clockwork.belt_flips(str(lv.headers.get("belt_flip", "")))
	_check(flips.size() == 1 and flips[0]["x0"] == 62 and flips[0]["x1"] == 69 and flips[0]["every"] == 8,
			"and features/clockwork.gd flips that run every 8 beats (%s)" % [flips])
	_check(str(lv.headers.get("roles", "")) == "S C A C A V A B", "roles: the declared section roles (%s)" % lv.headers.get("roles", ""))
	var a := Rules.anoint_of(lv)
	_check(a.size() == 3 and a[0]["cell"] == Vector2i(37, 12) and a[0]["omens"] == ["Swift", "Warded"] and a[0]["name"] == "Sister Thistle"
			and a[1]["cell"] == Vector2i(33, 9) and (a[1]["omens"] as Array).is_empty() and a[1]["name"] == "Old Quiver"
			and a[2]["cell"] == Vector2i(72, 5) and (a[2]["omens"] as Array).is_empty() and a[2]["name"] == "",
			"anoint: three cells, with Omens and a name, a name alone, and bare (%s)" % [a])
	_check(Rules.forced_cells(lv).size() == 3 and Rules.forced_cells(lv).has(Vector2i(72, 5)), "the forced cells")
	_check(Rules.ranges_of("106-129, 62-69@8") == [Vector2i(106, 129), Vector2i(62, 69)] and Rules.ranges_of("62-69=8") == [Vector2i(62, 69)],
			"range headers read back")
	_check(Rules.roles_problems([lv]).is_empty(), "one re-cut level shares its roles with nobody")
	var twin := _lv("6-2")
	_check(_has(Rules.roles_problems([_lv("6-1"), twin]), "share their section roles"), "two re-cut levels with the same roles are caught")
	_check(Rules.roles_problems([_lv("6-1"), _with(twin, "roles", "S C A V A B")]).is_empty(), "and different ones pass")


func _test_roster() -> void:
	var lv := _lv()
	var cast := Rules.cast_of(lv)
	var want := {"bonebow": 1, "thornback": 2, "creepbone": 2, "hushling": 3, "stillmaw": 1, "gutterwing": 1, "skeleton": 1,
			"rattlehound": 1, "rootling": 2, "lidlurk": 1}
	_check(cast == want, "the cast: 15 monsters, the nest counted as its Gutterwing, the Dread aside (%s)" % [cast])
	var r := Rules.roster_of(lv)
	_check(r["headline"] == ["hushling", "stillmaw"] and r["support"] == ["bonebow", "gutterwing"]
			and r["guest"] == ["thornback", "creepbone", "rattlehound", "rootling"] and int(r["rattle_max"]) == 1
			and is_equal_approx(float(r["fodder_max"]), 0.67) and r["count"] == Vector2i(15, 15) and (r["unknown"] as Array).is_empty(),
			"roster: read back as written (%s)" % [r])
	_check(Rules.roster_problems(lv).is_empty(), "the fixture holds its roster (%s)" % [Rules.roster_problems(lv)])
	_check(Rules.roster_problems(_with(_lv(), "roster", "")).is_empty() and Rules.roster_of(_with(_lv(), "roster", "")).is_empty(),
			"no roster: header, nothing checked")
	var extra := _lv()
	extra.entities.append({"kind": "skeleton", "cell": Vector2i(8, 12)})
	_check(_has(Rules.roster_problems(extra), "2 Rattles"), "a Rattle over rattle_max is caught")
	var moved := _lv()
	moved.entities.append({"kind": "unwick", "cell": Vector2i(8, 12)})
	_check(_has(Rules.roster_problems(moved), "unwick it does not declare"), "a kind it doesn't declare is caught")
	var base := "support=bonebow,gutterwing; guest=thornback,creepbone,rattlehound,rootling; rattle_max=1; fodder_max=0.67; count=15"
	_check(_has(Rules.roster_problems(_with(_lv(), "roster", "headline=hushling,stillmaw,unwick; " + base)), "no unwick, a headline kind"),
			"a headline kind it never places is caught")
	_check(_has(Rules.roster_problems(_with(_lv(), "roster", "headline=hushling,stillmaw; " + base.replace("0.67", "0.6"))), "fodder 10 of 15"),
			"the fodder share over fodder_max is caught")
	_check(_has(Rules.roster_problems(_with(_lv(), "roster", "headline=hushling,stillmaw; " + base.replace("count=15", "count=16-20"))), "count 16-20"),
			"a count outside its band is caught")
	_check(_has(Rules.roster_problems(_with(_lv(), "roster", "headline=hushling,stillmaw; " + base.replace("rootling", "rootling,unwick"))), "unwick is no guest"),
			"a guest from this world is caught")
	_check(_has(Rules.roster_problems(_lv(), 5), "hushling is World 6's"), "in World 5, a World 6 headline is caught")
	_check(_has(Rules.roster_problems(_with(_lv(), "roster", "headline=hushling; support=skeleton; rattle_max=1; fodder_max=1; oops=2")), "unknown roster key oops")
			and _has(Rules.roster_problems(_with(_lv(), "roster", "headline=hushling; support=skeleton; rattle_max=1; fodder_max=1")), "skeleton is listed"),
			"an unknown key and a listed Rattle are caught")


func _test_threat() -> void:
	var lv := _lv()
	# Forced (x2.5): the Bonebow, the Thornback at 37,12, the Stillmaw. Packs:
	# the two Creepbones 8 apart are two packs of one (+1 each), the Hushlings
	# a pair (+1) and one alone (+2).
	var forced := 2.5 * (_c("bonebow") + _c("thornback") + _c("stillmaw"))
	var plain := _c("thornback") + 2 * _c("creepbone") + 3 * _c("hushling") + _c("gutterwing") + _c("skeleton") + _c("rattlehound") \
			+ 2 * _c("rootling") + _c("lidlurk")
	var packs := 2 * _c("creepbone") + 3 * _c("hushling")
	var got := Rules.threat_of(lv)
	_check(is_equal_approx(got, (forced + plain + packs) * 100.0 / WIDTH) and is_equal_approx(got, 25.0),
			"the threat counts forced Anointed at x2.5 and packs at their size: %.3f (40.5 over 162 tiles)" % got)
	_check(is_equal_approx(Rules.threat_of(_with(_lv(), "twist", "")), (forced + plain) * 100.0 / WIDTH), "with no packs twist, placed packs count as drawn")
	_check(is_equal_approx(Rules.threat_of(_with(_lv(), "anoint", "")), (forced / 2.5 + plain + packs) * 100.0 / WIDTH), "with no anoint:, nobody at x2.5")
	_check(is_equal_approx(Rules.threat_of(lv, 81.0), got * 2.0), "a stretch of tiles given (a boss level's approach)")
	_check(is_equal_approx(Rules.declared_threat(lv), 25.0) and Rules.threat_problems([lv]).is_empty(), "the declared threat holds (25: the generator's own count)")
	_check(_has(Rules.threat_problems([_with(_lv(), "threat", "30")]), "declared 30"), "a threat 17% off its declared one is caught")
	var ramp := [_with(_lv("6-1"), "threat", "25"), _with(_lv("6-2"), "threat", "24"), _with(_lv("6-3"), "threat", "26")]
	_check(_has(Rules.threat_problems(ramp), "the ramp"), "a world whose declared threat falls from X-1 to X-2 is caught")
	ramp[1] = _with(_lv("6-2"), "threat", "24.8")
	_check(Rules.threat_problems(ramp).is_empty(), "and a fall within RAMP_TOL passes (%s)" % [Rules.threat_problems(ramp)])
	_check(Rules.pack_groups([Vector2i(64, 12), Vector2i(67, 12), Vector2i(80, 12)]).size() == 2
			and Rules.pack_groups([Vector2i(1, 12), Vector2i(4, 12), Vector2i(8, 11)]).size() == 1, "packs chain within 4 tiles and a row")


func _test_checkpoints() -> void:
	var lv := _lv()
	_check(Rules.checkpoint_problems(lv, MAX_GAP).is_empty(), "checkpoints 52 apart at most, 3 altars, one 6 tiles before the duel's door (%s)" % [Rules.checkpoint_problems(lv, MAX_GAP)])
	_check(_has(Rules.checkpoint_problems(lv, 40), "52 tiles apart"), "a gap over the world's limit is caught")
	_check(_has(Rules.checkpoint_problems(_with(_lv(), "room", "duel 120-130"), MAX_GAP), "the duel door at 120"), "a sealed room with no altar by its door is caught")
	_check(_has(Rules.checkpoint_problems(_with(_lv(), "room", "duel 106-129; hold 120-130 @20"), MAX_GAP), "the hold door at 120"),
			"a second room's too (a hold, on a clock)")
	var few := _lv()
	few.entities = few.entities.filter(func(e): return e["kind"] != "altar" or e["cell"].x != 54)
	_check(_has(Rules.checkpoint_problems(few, 200), "2 altars"), "fewer than 3 altars is caught")


func _test_anoint() -> void:
	_check(Rules.anoint_problems(_lv()).is_empty(), "the fixture's anoint: cells keep the rules (%s)" % [Rules.anoint_problems(_lv())])
	_check(_has(Rules.anoint_problems(_with(_lv(), "anoint", "125,12")), "no kind elites.gd may anoint"), "an anoint on the Lidlurk is caught")
	_check(_has(Rules.anoint_problems(_with(_lv(), "anoint", "40,12")), "no monster"), "an anoint on nothing is caught")
	_check(_has(Rules.anoint_problems(_with(_lv(), "anoint", "72,5:Hushed")), "may not carry Hushed"), "an Omen its kind can't carry is caught")
	_check(_has(Rules.anoint_problems(_with(_lv(), "anoint", "37,12:Vengeful"), 5), "may not carry Vengeful")
			and Rules.anoint_problems(_with(_lv(), "anoint", "37,12:Vengeful")).is_empty(), "Vengeful on Dusk only from World 6")
	_check(_has(Rules.anoint_problems(_with(_lv(), "anoint", "37,12:Swift+Swift")), "Omens"), "an Omen twice is caught")
	_check(_has(Rules.anoint_problems(_with(_lv(), "anoint", "37,12:Swift; 26,12"), 2), "World 1-2") and Rules.anoint_problems(_with(_lv(), "anoint", "37,12:Swift"), 2).is_empty(),
			"World 1-2: one set piece with one Omen at most")


func _test_stamps() -> void:
	## The stamps toolkit.py drew, where it drew them, standing where
	## PLACEMENT says: crossfire (a Bonebow on the post, a Thornback 3 down
	## and 4 on), lane-and-thorn (a Thornback between the vines, a Creepbone
	## riding each), hound-and-mounds (in the room); swap's Hushlings and Rattle.
	var lv := _lv()
	var at := {}
	for e in lv.entities:
		at[e["cell"]] = str(e["kind"])
	var want := {Vector2i(33, 9): "bonebow", Vector2i(37, 12): "thornback", Vector2i(26, 12): "thornback", Vector2i(22, 9): "creepbone",
			Vector2i(30, 9): "creepbone", Vector2i(112, 12): "rattlehound", Vector2i(117, 12): "rootling", Vector2i(120, 12): "rootling",
			Vector2i(64, 12): "hushling", Vector2i(67, 12): "hushling", Vector2i(80, 12): "hushling", Vector2i(70, 12): "skeleton"}
	var wrong := []
	for c in want:
		if str(at.get(c, "")) != want[c]:
			wrong.append("%s at %s (%s)" % [want[c], c, at.get(c, "nothing")])
	_check(wrong.is_empty(), "each stamp and swap where it was drawn %s" % [wrong])
	_check(LevelData.is_solid(lv.tile(33, 10)) and LevelData.is_solid(lv.tile(37, 13)) and LevelData.is_solid(lv.tile(26, 13)),
			"the Bonebow on its post, the Thornbacks on the floor")
	_check(lv.tile(22, 9) == LevelData.VINE and lv.tile(30, 9) == LevelData.VINE, "each Creepbone rides its vine (its cell a vine)")
	_check(lv.count("glassmite") == 0, "swap took every Glassmite drawn for a Hushling")
