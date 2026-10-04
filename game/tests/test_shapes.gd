extends SceneTree
## Build 2's shapes (the shape plan's E1, E2, E7, E8): the generator's
## shaped levels read back. The labs (tools/levels/lab_shapes.py):
##   - lab-shapes, 24 rows: its rows as placed (a start 9 rows down, a stair
##     drawn 24 tall, a landing, two storeys stacked, a stone ceiling), its
##     hints met along the walk map's route (the upper storey's sign, left
##     of the lower one's, comes after it), its checkpoints' gaps along the
##     route as the generator measured them, its sealed room met by its
##     right door, the first-time belt bark at the belt the route meets
##     first (not the leftmost), and every shape rule; the reachability bot
##     rings its bell and takes its sigils with Wick's own physics;
##   - lab-mirror, 15 rows, mirrored whole: facing: left (he starts facing
##     left, its Rattle faces right), every weight's and the swing's phase
##     half a swing on and the cog's 1 - turns, so each swings as the mirror
##     of its unmirrored self (tests/fixtures/shapes-unmirrored.txt) at
##     every moment, its barks' spots the mirror of the fixture's, its room
##     by its right door; the bot rings its bell.
## And each shape rule shown to catch what it should on made-up levels: the
## height, a goal under the HUD's corner, a required drop of 6 rows, a
## landing with no way out, a crumble 13 rows over its floor, a monster at a
## catch floor, facing left from the left, a screen's rows in a tall level;
## W6's barks facing left (deep.gd).
##
##     godot --headless --path game --script res://tests/test_shapes.gd

const LevelData := preload("res://scripts/level_data.gd")
const Rules := preload("res://tests/level_rules.gd")
const WalkMap := preload("res://scripts/walk_map.gd")
const Movers := preload("res://scripts/movers.gd")
const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
var WorldScript: GDScript
const TILE := 32
const DT := 1.0 / 120.0
const UNMIRRORED := "res://tests/fixtures/shapes-unmirrored.txt"

var _passed := 0
var _failed := 0
var game: Node


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	if game != null:
		game.save_path = "user://test_shapes_save.json"
		game.reset()
	var tall = LevelData.load_file("res://levels/lab-shapes.txt")
	var mirror = LevelData.load_file("res://levels/lab-mirror.txt")
	var plain = LevelData.load_file(UNMIRRORED)
	_test_tall(tall)
	_test_mirror(mirror, plain)
	_test_rules()
	_test_review_rules()
	_test_deep_barks()
	_test_bot(tall)
	_test_bot(mirror)
	await _test_worlds(tall, mirror, plain)
	print("test_shapes: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _level(text: String, id := "lab-x") -> RefCounted:
	var lv = LevelData.new()
	lv.id = id
	lv.parse(text)
	return lv


func _rows(rows: Array, header := "title: t\nsubtitle: t\n") -> RefCounted:
	return _level(header + "---\n" + "\n".join(rows))


func _sign_text(lv: RefCounted, cell: Vector2i) -> String:
	for e in lv.entities:
		if e["kind"] == "sign" and e["cell"] == cell:
			return str(e["text"])
	return "?"


# ---------------------------------------------------------------- lab-shapes

func _test_tall(lv: RefCounted) -> void:
	_check(lv.errors.is_empty() and lv.width == 98 and lv.height == 24 and Rules.height_ok(lv), "lab-shapes parses, 98 x 24 (%d x %d %s)" % [lv.width, lv.height, lv.errors])
	# The rows as placed: the start 9 rows down (rock over it), the stair's
	# steps, the landing's floor on row 13 with rock under it, the storeys'
	# floors on rows 10 and 22, the stone ceiling.
	_check(lv.start == Vector2i(2, 21) and lv.tile(0, 8) == LevelData.STONE and lv.tile(0, 9) == LevelData.AIR, "the start on row 21, rock over it to row 8")
	_check(lv.tile(24, 19) == LevelData.STONE and lv.tile(28, 16) == LevelData.STONE and lv.tile(32, 13) == LevelData.STONE and lv.tile(31, 12) == LevelData.AIR,
			"the stair: three steps up 3 rows each")
	_check(lv.tile(40, 13) == LevelData.STONE and lv.tile(40, 23) == LevelData.STONE and lv.tile(70, 10) == LevelData.STONE and lv.tile(70, 22) == LevelData.STONE,
			"the landing's floor on row 13 (rock under it), the storeys' on rows 10 and 22")
	var roof := true
	for x in lv.width:
		roof = roof and LevelData.is_solid(lv.tile(x, 0))
	_check(roof, "a stone ceiling row over the whole level")
	# The hints, met along the route: the upper storey's sign (72, 9) stands
	# left of the lower one's (86, 21) but comes after it.
	var want := {Vector2i(6, 21): "A level 24 rows tall", Vector2i(45, 12): "An altar on the landing", Vector2i(86, 21): "The lower storey", Vector2i(72, 9): "The upper storey"}
	for c in want:
		_check(_sign_text(lv, c).begins_with(want[c]), "the sign at %s reads '%s...' (%s)" % [c, want[c], _sign_text(lv, c)])
	var m = WalkMap.of(lv)
	_check(not m.route().is_empty() and m.touches(m.route().back(), [Vector2i(70, 9)]), "the walk map's route reaches the bell")
	var signs := [Vector2i(72, 9), Vector2i(45, 12), Vector2i(86, 21), Vector2i(6, 21)]
	var order := []
	while not signs.is_empty():
		var i := WalkMap.first_of(lv, signs)
		order.append(signs[i])
		signs.remove_at(i)
	_check(order == [Vector2i(6, 21), Vector2i(45, 12), Vector2i(86, 21), Vector2i(72, 9)], "the walk map meets the signs as the generator wrote their hints (%s)" % [order])
	_check(WalkMap.dir_of(lv, Vector2i(86, 21)) == 1 and WalkMap.dir_of(lv, Vector2i(72, 9)) == -1, "the route runs right on the lower storey, left on the upper")
	# Checkpoints along the route, as common.checkpoint_gaps measured them.
	var cg := Rules.checkpoint_gaps(lv)
	_check(cg["gaps"] == [46, 71, 21], "the checkpoints' gaps along the route: 46, 71, 21 as the generator wrote (%s)" % [cg["gaps"]])
	_check(Rules.checkpoint_problems(lv, 75, Vector2i(2, 2)).is_empty() and not Rules.checkpoint_problems(lv, 70, Vector2i(2, 2)).is_empty(),
			"the gap rule reads the route (71 on foot, though the altars are 31 apart in x)")
	# Its sealed room, met by its right door on the upper storey.
	var room: Dictionary = (preload("res://scripts/features/sealed.gd").parse(str(lv.headers["room"])) as Array)[0]
	_check(Rules.room_entry(lv, room["x0"], room["x1"], Rules.room_rows(lv, room)) == 1, "the duel room is met by its right door")
	_check(Rules.header_problems(lv).is_empty(), "lab-shapes keeps its headers' rules, its room's altar right of it %s" % [Rules.header_problems(lv)])
	_check(Rules.shape_problems(lv).is_empty(), "lab-shapes keeps the shape rules %s" % [Rules.shape_problems(lv)])
	var sr: Array = Rules.screen_rows(lv, 0)
	_check(sr == [Vector2i(13, 23), Vector2i(16, 23)] and Rules.screen_rows(lv, 76).has(Vector2i(4, 15)) and Rules.screen_rows(lv, 76).has(Vector2i(16, 23)),
			"a tall level's screens are the views over the rows he stands on: its start's (%s), both storeys' over the duel (%s)" % [sr, Rules.screen_rows(lv, 76)])


# ---------------------------------------------------------------- lab-mirror

func _test_mirror(lv: RefCounted, plain: RefCounted) -> void:
	_check(lv.errors.is_empty() and plain.errors.is_empty() and lv.width == plain.width and lv.height == 15, "lab-mirror and its unmirrored self parse, as wide")
	_check(lv.facing == -1 and plain.facing == 1 and str(lv.headers.get("facing", "")) == "left", "lab-mirror faces left")
	var w: int = lv.width
	var same := true
	var flip := {LevelData.BELT_L: LevelData.BELT_R, LevelData.BELT_R: LevelData.BELT_L}
	for y in lv.height:
		for x in w:
			var a: int = plain.tile(x, y)
			var b: int = lv.tile(w - 1 - x, y)
			same = same and b == int(flip.get(a, a))
	_check(same, "every tile mirrored, the belts turned")
	_check(lv.start.x == w - 1 - plain.start.x and lv.start.y == plain.start.y, "it starts at the mirror of the start")
	# The phases: every weight and the swing written, half a swing on at the
	# mirrored column; the cog's 1 - turns at the mirrored hub.
	_check(lv.weight_phase == {59: 0.0, 63: 0.5, 71: 0.75} and plain.weight_phase == {58: 0.25}, "weight_phase mirrored (%s)" % [lv.weight_phase])
	_check(lv.cog_phase == {84: 0.875} and plain.cog_phase == {45: 0.125}, "cog_phase mirrored (%s)" % [lv.cog_phase])
	# The cog's teeth at every moment: the mirror of the unmirrored ones.
	var ca = plain.of_kind("cog")[0]
	var cb = lv.of_kind("cog")[0]
	var ta := Movers.cog(LevelData.cell_center(ca["cell"]), int(ca["dir"]), float(plain.cog_phase[45]))
	var tb := Movers.cog(LevelData.cell_center(cb["cell"]), int(cb["dir"]), float(lv.cog_phase[84]))
	var teeth_ok := int(cb["dir"]) == -int(ca["dir"])
	for t in [0.0, 0.7, 1.9, 3.3, 5.1]:
		for m in ta + tb:
			m.update(t)
		for a in ta:
			var want := Vector2(w * TILE - a.rect().get_center().x, a.rect().get_center().y)
			teeth_ok = teeth_ok and tb.any(func(b): return b.rect().get_center().distance_to(want) < 0.01)
	_check(teeth_ok, "the cog turns the other way, its teeth the mirror of its unmirrored self's at every moment")
	var room: Dictionary = (preload("res://scripts/features/sealed.gd").parse(str(lv.headers["room"])) as Array)[0]
	_check(Rules.room_entry(lv, room["x0"], room["x1"], Rules.room_rows(lv, room)) == 1 and Rules.room_entry(plain, room["x0"], room["x1"], Vector2i(0, 14)) == -1,
			"a strip facing left meets its room by the right door, facing right the left")
	_check(Rules.header_problems(lv).is_empty() and Rules.header_problems(plain).is_empty(), "both keep their headers' rules (the altar by the door each meets) %s %s" % [Rules.header_problems(lv), Rules.header_problems(plain)])
	_check(Rules.shape_problems(lv).is_empty(), "lab-mirror keeps the shape rules %s" % [Rules.shape_problems(lv)])
	var hints := []
	for e in lv.entities:
		if e["kind"] == "sign":
			hints.append(str(e["text"]))
	_check(_sign_text(lv, Vector2i(w - 1 - 7, 12)).begins_with("The mirror lab") and _sign_text(lv, Vector2i(w - 1 - 81, 12)).begins_with("An altar"),
			"its hints met right to left (%s)" % [hints])
	var cells := [Vector2i(20, 12), Vector2i(109, 12), Vector2i(98, 12)]
	_check(WalkMap.first_of(lv, cells) == 1 and WalkMap.first_of(plain, cells) == 0 and WalkMap.dir_of(lv, Vector2i(5, 12)) == -1, "a strip facing left meets its rightmost first")


# ---------------------------------------------------------------- the rules catch

func _blank(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		rows.append(".".repeat(w))
	return rows


func _put(rows: Array, x: int, y: int, s: String) -> void:
	rows[y] = (rows[y] as String).substr(0, x) + s + (rows[y] as String).substr(x + s.length())


func _test_rules() -> void:
	# The height.
	var short := _blank(20, 14)
	_put(short, 0, 13, "#".repeat(20))
	_put(short, 2, 12, "P")
	_put(short, 9, 12, "E")
	_check(not Rules.height_ok(_rows(short)) and not Rules.shape_problems(_rows(short)).is_empty(), "14 rows is no level")
	# A goal under the HUD's top right corner where the camera stops.
	var hud := _blank(40, 15)
	_put(hud, 0, 13, "#".repeat(40))
	_put(hud, 0, 14, "#".repeat(40))
	_put(hud, 1, 12, "P")
	_put(hud, 6, 12, "E")
	_check(Rules.hud_problems(_rows(hud)).is_empty(), "a bell on the floor is clear of the HUD")
	_put(hud, 38, 1, "1")
	_check(Rules.hud_problems(_rows(hud)).size() == 1 and str(Rules.hud_problems(_rows(hud))[0]).contains("right corner"), "a sigil in the top right corner is caught %s" % [Rules.hud_problems(_rows(hud))])
	_put(hud, 38, 1, ".")
	_put(hud, 2, 1, "2")
	_check(str(Rules.hud_problems(_rows(hud))).contains("left corner"), "...and one in the top left")
	# Facing left from the left of its bell.
	_put(hud, 2, 1, ".")
	_check(Rules.shape_problems(_rows(hud)).is_empty() and Rules.shape_problems(_rows(hud, "title: t\nsubtitle: t\nfacing: left\n")).size() == 1,
			"facing left from the left of its bell is caught %s" % [Rules.shape_problems(_rows(hud, "title: t\nsubtitle: t\nfacing: left\n"))])
	# Descent: the only way on a 7-row drop.
	var drop := _blank(24, 21)
	for y in 6:
		_put(drop, 0, y, "#".repeat(24))
	_put(drop, 0, 12, "########")
	_put(drop, 0, 19, "#".repeat(24))
	_put(drop, 0, 20, "#".repeat(24))
	_put(drop, 2, 11, "P")
	_put(drop, 20, 18, "E")
	var dp := Rules.descent_problems(_rows(drop))
	_check(dp.size() == 1 and str(dp[0]).contains("drop of more than 5"), "a 7-row drop the only way on is caught %s" % [dp])
	# A pocket: dropped into, no way out.
	var pocket := drop.duplicate()
	for y in range(13, 19):
		_put(pocket, 14, y, "#")
	_put(pocket, 8, 12, "======")
	_check(str(Rules.descent_problems(_rows(pocket))).contains("lead nowhere"), "a pocket with no way out is caught %s" % [Rules.descent_problems(_rows(pocket))])
	# Catch: a crumble 13 rows over its floor; a monster where it lands.
	var tall := _blank(20, 20)
	_put(tall, 4, 4, "%%%%")
	_put(tall, 0, 18, "#".repeat(20))
	_put(tall, 0, 19, "#".repeat(20))
	_put(tall, 1, 17, "P")
	_put(tall, 15, 17, "E")
	_check(str(Rules.catch_problems(_rows(tall))).contains("lands 13 rows down"), "a crumble 13 rows over its floor is caught %s" % [Rules.catch_problems(_rows(tall))])
	var near := tall.duplicate()
	_put(near, 7, 17, "s")
	_check(str(Rules.catch_problems(_rows(near))).contains("waits where"), "a Rattle where the crumble drops him is caught")
	var caught := tall.duplicate()
	_put(caught, 3, 12, "======")
	_check(Rules.catch_problems(_rows(caught)).is_empty(), "a catch floor 7 rows down passes")
	# A tall level's screens are 12 rows: four Rattles on each of two storeys
	# 12 rows apart crowd no screen; eight on one do.
	var two := _blank(30, 24)
	_put(two, 0, 22, "#".repeat(30))
	_put(two, 0, 23, "#".repeat(30))
	_put(two, 0, 10, "#".repeat(30))
	_put(two, 3, 9, "ssss")
	_put(two, 3, 21, "ssss")
	_put(two, 1, 21, "P")
	_put(two, 20, 21, "E")
	_check(Rules.crowded_screens(_rows(two)).is_empty(), "four a storey, the storeys a screen apart: no screen crowded")
	_put(two, 3, 9, "....")
	_put(two, 9, 21, "ssss")
	_check(not Rules.crowded_screens(_rows(two)).is_empty(), "eight on one storey: crowded")
	var strip := _blank(30, 15)
	_put(strip, 0, 13, "#".repeat(30))
	_put(strip, 0, 14, "#".repeat(30))
	_put(strip, 3, 12, "s")
	_put(strip, 3, 2, "b")
	_check(Rules.screen_rows(_rows(strip)) == [Vector2i(0, 14)], "a strip's screen is its whole height")


func _fill(rows: Array, x0: int, x1: int, y0: int, y1: int, ch := "#") -> void:
	for y in range(y0, y1 + 1):
		_put(rows, x0, y, ch.repeat(x1 - x0 + 1))


func _hd(extra: Dictionary) -> String:
	var t := "title: t\nsubtitle: t\n"
	for k in extra:
		t += "%s: %s\n" % [k, extra[k]]
	return t


func _two_roads() -> Array:
	## common.review_check's two roads: a high road (stand 10) over the low
	## one (stand 21), split from x 14 to 45, rejoining for the bell.
	var r := _blank(60, 24)
	_fill(r, 0, 59, 0, 0)
	_fill(r, 0, 59, 22, 23)
	_fill(r, 14, 45, 11, 12)
	for xy in [Vector2i(10, 19), Vector2i(12, 16), Vector2i(10, 13), Vector2i(47, 13), Vector2i(49, 16), Vector2i(47, 19)]:
		_put(r, xy.x, xy.y, "===")
	_put(r, 2, 21, "P")
	_put(r, 56, 21, "E")
	_put(r, 5, 21, "K")
	_put(r, 52, 21, "K")
	_put(r, 20, 10, "s")
	_put(r, 30, 10, "s")
	_put(r, 25, 21, "s")
	return r


func _test_review_rules() -> void:
	## The rules the shape review asked for, as common.review_check proves
	## the generator's (the same levels, the same verdicts): threat per tile
	## of the route on foot and per road; gaps per road; screens over the
	## rows he stands on; a level's own descent keys; drops:; waxfalls off
	## the drops; a dark level's roads lit apart; the clockwork's column
	## keys; the boss and secret levels kept strips; a two-deck room's door
	## altar on his deck; a Creepbone at a rotten run's foot; a deck's gusts.
	var c := func(k: String) -> float: return float(load("res://scripts/enemy_kinds.gd").COST[k])
	# A loop: threat per tile of the route on foot.
	var loop := _blank(40, 24)
	_fill(loop, 0, 39, 0, 0)
	_fill(loop, 0, 39, 22, 23)
	_fill(loop, 0, 31, 11, 12)
	_put(loop, 2, 21, "P")
	_put(loop, 3, 10, "E")
	_put(loop, 34, 19, "====")
	_put(loop, 36, 16, "===")
	_put(loop, 34, 13, "====")
	_put(loop, 12, 21, "s")
	_put(loop, 20, 10, "s")
	var ll := _rows(loop)
	var run: int = WalkMap.of(ll).run_lengths().back()
	_check(run > 60 and is_equal_approx(Rules.threat_of(ll), 2.0 * c.call("skeleton") * 100.0 / run),
			"a loop's threat is per tile of its route on foot (%.2f over %d tiles, %d wide)" % [Rules.threat_of(ll), run, ll.width])
	# Two roads: each road's threat, the heavier the level's; gaps per road.
	var roads := "high 30,10; low 30,21"
	var two := _two_roads()
	var tl := _rows(two, _hd({"roads": roads}))
	var m = WalkMap.of(tl)
	var rs: Array = m.roads()
	_check(rs.size() == 2 and not (rs[0]["path"] as Array).is_empty() and not (rs[1]["path"] as Array).is_empty() and m.road_of(Vector2i(20, 10)) == [0]
			and m.road_of(Vector2i(25, 21)) == [1] and m.road_of(Vector2i(2, 21)) == [0, 1], "two roads: each its route, road_of the nearest (both where they share)")
	var hi: float = 2.0 * c.call("skeleton") * 100.0 / float(m.run_lengths(rs[0]["path"]).back())
	var lo: float = c.call("skeleton") * 100.0 / float(m.run_lengths(rs[1]["path"]).back())
	_check(is_equal_approx(Rules.threat_of(tl), maxf(hi, lo)), "two roads: the heavier road's threat (%.2f)" % Rules.threat_of(tl))
	var rg: Array = Rules.road_gaps(tl)
	_check(rg.size() == 2 and str(rg[0]["road"]) == "high" and str(rg[1]["road"]) == "low", "the gaps along each road %s" % [rg])
	var tight: int = maxi(int(rg[0]["worst"]), int(rg[1]["worst"])) - 1
	_check(str(Rules.checkpoint_problems(tl, tight, Vector2i(2, 2))).contains("road"), "a gap too wide on a road is named by its road")
	_check(str(Rules.shape_problems(_rows(two, _hd({"roads": "high 30,10; nowhere 30,5"})))).contains("no way to the goal"), "a road that goes nowhere")
	# Screens over the rows he stands on: the roads apart.
	var crowd := two.duplicate()
	for x in [16, 18, 22, 24, 26, 28, 32]:
		_put(crowd, x, 10, "s")
		_put(crowd, x, 21, "s")
	var cl := _rows(crowd)
	var sr: Array = Rules.screen_rows(cl, 16)
	_check(sr.has(Vector2i(5, 16)) and sr.has(Vector2i(16, 23)) and not sr.any(func(b): return b.x <= 10 and b.y >= 21), "screen_rows: the roads apart (%s)" % [sr])
	_check(not Rules.crowded_screens(cl).is_empty() and Rules.crowded_screens(_rows(two)).is_empty(), "eight a road crowds its screen")
	# A level's own descent keys.
	var dr := _blank(40, 24)
	_fill(dr, 0, 39, 22, 23)
	_fill(dr, 0, 17, 17, 23)
	_put(dr, 2, 16, "P")
	_put(dr, 30, 21, "E")
	_check(not str(Rules.shape_problems(_rows(dr))).contains("descent"), "a 5-row drop keeps the shape rules")
	_check(str(Rules.shape_problems(_rows(dr, _hd({"max_drop": 4})))).contains("own descent rules (max_drop 4)")
			and not str(Rules.shape_problems(_rows(dr, _hd({"max_drop": 5})))).contains("descent"), "max_drop 4 catches it, 5 passes")
	_check(str(Rules.shape_problems(_rows(dr, _hd({"lit_drops": 3})))).contains("lit_drops 3"), "lit_drops: a 5-row drop is too far")
	var lit := dr.duplicate()
	_put(lit, 18, 19, "======")
	_put(lit, 23, 18, "L")
	_put(lit, 26, 20, "L")
	_check(not str(Rules.shape_problems(_rows(lit, _hd({"lit_drops": 3})))).contains("descent"), "lit_drops: lit 3- and 2-row drops pass %s" % [Rules.shape_problems(_rows(lit, _hd({"lit_drops": 3})))])
	var dark := lit.duplicate()
	_put(dark, 23, 18, ".")
	_put(dark, 26, 20, ".")
	_check(str(Rules.shape_problems(_rows(dark, _hd({"lit_drops": 3})))).contains("lit_drops 3"), "lit_drops: the same in the dark fails")
	_check(str(Rules.shape_problems(_rows(lit, _hd({"landing": "0/0"})))).contains("landing 0/0")
			and not str(Rules.shape_problems(_rows(lit, _hd({"landing": "1/0"})))).contains("descent")
			and Rules.shape_problems(_rows(lit, _hd({"landing": "x"}))).any(func(p): return str(p).begins_with("landing 'x'")), "landing: walk-offs land a column ahead; one that doesn't read")
	# drops: where the route drops through a ledge.
	var led := _blank(30, 24)
	_fill(led, 0, 29, 22, 23)
	_fill(led, 0, 9, 13, 23)
	_put(led, 10, 13, "=====")
	_fill(led, 15, 29, 13, 21)
	_put(led, 2, 12, "P")
	_put(led, 12, 21, "E")
	_check(str(Rules.shape_problems(_rows(led))).contains("drops: yes") and not str(Rules.shape_problems(_rows(led, _hd({"drops": "yes"})))).contains("drops:"),
			"drops: required where the route drops through a ledge")
	# Waxfalls: one over the only landing.
	var wx := _blank(40, 24)
	_fill(wx, 0, 39, 22, 23)
	_fill(wx, 0, 17, 17, 23)
	_fill(wx, 19, 39, 17, 19)
	_put(wx, 2, 16, "P")
	_put(wx, 30, 21, "E")
	_put(wx, 18, 12, "!")
	_check(str(Rules.shape_problems(_rows(wx))).contains("only landing"), "a waxfall over the only landing")
	var beside := wx.duplicate()
	_fill(beside, 25, 27, 17, 19, ".")
	_check(not str(Rules.shape_problems(_rows(beside))).contains("waxfall"), "another way down beside it: not its only landing")
	_check(Rules.fall_secs(5) + 32.0 / 205.0 < 1.2, "a 5-row drop and a step fit a waxfall's off window (%.2f s)" % Rules.fall_secs(5))
	# The dark: a lantern on a high road 3 rows up lights the low road.
	var nr := two.duplicate()
	_fill(nr, 14, 45, 11, 12, ".")
	_fill(nr, 14, 45, 19, 19)
	_put(nr, 34, 18, "L")
	var nroads := "high 30,18; low 30,21"
	_check(str(Rules.shape_problems(_rows(nr, _hd({"roads": nroads, "twist": "dark"})))).contains("lights the low road")
			and not str(Rules.shape_problems(_rows(nr, _hd({"roads": nroads})))).contains("lights"), "a dark level's roads lit apart (and only in the dark)")
	var far := two.duplicate()
	_put(far, 34, 10, "L")
	_check(not str(Rules.shape_problems(_rows(far, _hd({"roads": roads, "twist": "dark"})))).contains("lights"), "a lantern 11 rows up: apart")
	# The clockwork's column keys.
	var ck := loop.duplicate()
	_put(ck, 10, 5, "O")
	_put(ck, 10, 17, "Q")
	_check(str(Rules.clockwork_problems(_rows(ck))).contains("two cog hubs in column 10"), "two cogs in a column")
	_put(ck, 10, 17, ".")
	_put(ck, 12, 8, "Y")
	_put(ck, 12, 19, "T")
	_check(str(Rules.clockwork_problems(_rows(ck))).contains("two weights or swings in column 12"), "a weight over a swing")
	var bf := loop.duplicate()
	_put(bf, 5, 11, ">>>>")
	_put(bf, 5, 22, "<<<<")
	_check(str(Rules.clockwork_problems(_rows(bf, _hd({"belt_flip": "5-8=8"})))).contains("two storeys")
			and Rules.clockwork_problems(_rows(bf, _hd({"belt_flip": "20-24=8"}))).is_empty(), "a belt_flip over both storeys")
	# The boss and secret levels stay strips.
	var boss := _level(_hd({}) + "---\n" + "\n".join(loop), "4-4")
	var reg := _level(_hd({}) + "---\n" + "\n".join(loop), "4-2")
	_check(not Rules.height_ok(boss) and str(Rules.shape_problems(boss)).contains("stays a strip") and Rules.height_ok(reg)
			and not Rules.height_ok(_level(_hd({}) + "---\n" + "\n".join(loop), "3-S")), "a boss or secret level stays a strip, a regular one may be taller")
	# A two-deck room: its door altar on the deck he comes in on.
	var deck := _blank(60, 24)
	_fill(deck, 0, 59, 0, 0)
	_fill(deck, 0, 59, 22, 23)
	_fill(deck, 20, 50, 1, 1)
	_fill(deck, 20, 20, 1, 18)
	_fill(deck, 50, 50, 1, 7)
	_fill(deck, 50, 50, 11, 21)
	for xy in [Vector2i(24, 19), Vector2i(29, 16), Vector2i(24, 13)]:
		_put(deck, xy.x, xy.y, "====")
	_fill(deck, 31, 49, 11, 11)
	_fill(deck, 51, 59, 11, 21)
	_put(deck, 2, 21, "P")
	_put(deck, 56, 10, "E")
	_put(deck, 36, 21, "s")
	_put(deck, 40, 10, "s")
	_put(deck, 14, 21, "K")
	var room := _hd({"room": "ambush 20-50 rows 1-22"})
	_check(Rules.room_problems(_rows(deck, room)).is_empty(), "the altar by its lower door, on its deck %s" % [Rules.room_problems(_rows(deck, room))])
	var up := deck.duplicate()
	_put(up, 14, 21, ".")
	_fill(up, 10, 18, 9, 9)
	_put(up, 14, 8, "K")
	_check(str(Rules.room_problems(_rows(up, room))).contains("no altar on the deck of its door"), "an altar over the lower door, on another deck %s" % [Rules.room_problems(_rows(up, room))])
	# A Creepbone at a rotten run's foot: the run's foot, as common.py reads it now.
	var rv := _blank(20, 24)
	_fill(rv, 0, 19, 22, 23)
	_fill(rv, 0, 19, 0, 0)
	for y in range(3, 6):
		_put(rv, 6, y, "}")
	_put(rv, 6, 6, "i")
	_put(rv, 2, 21, "P")
	_put(rv, 15, 21, "E")
	_fill(rv, 0, 5, 3, 3)
	_check(str(Rules.catch_problems(_rows(rv))).contains("lands 15 rows down"), "a Creepbone at a rotten run's foot: the foot (common.py agrees) %s" % [Rules.catch_problems(_rows(rv))])
	# The review's labs as the generator wrote them (lab_shaped.py): the
	# roads' threat per road as common.threat_of measured it, its gaps per
	# road; the islands' gust zone on its rows; every one keeping its rules.
	var rl = LevelData.load_file("res://levels/lab-shape-roads.txt")
	_check(Rules.declared_threat(rl) > 0.0 and absf(Rules.threat_of(rl) - Rules.declared_threat(rl)) <= 0.011,
			"lab-shape-roads: its threat per road as the generator wrote it (%.3f, declared %.2f)" % [Rules.threat_of(rl), Rules.declared_threat(rl)])
	var want_gaps := [{"road": "high", "marks": [0, 4, 97, 112], "gaps": [4, 93, 15], "worst": 93},
			{"road": "low", "marks": [0, 4, 86, 101], "gaps": [4, 82, 15], "worst": 82}]
	_check(str(Rules.road_gaps(rl)) == str(want_gaps) and Rules.checkpoint_problems(rl, 100, Vector2i(2, 2)).is_empty(),
			"its gaps along each road, as the generator measured them %s" % [Rules.road_gaps(rl)])
	var il = LevelData.load_file("res://levels/lab-shape-islands.txt")
	_check(il.gusts.size() == 1 and int(il.gusts[0]["y0"]) == 4 and int(il.gusts[0]["y1"]) == 16, "lab-shape-islands: its gust zone on its rows (%s)" % [il.gusts])
	for id in ["lab-shape-roads", "lab-shape-switchback", "lab-shape-terraces", "lab-shape-islands", "lab-shape-works", "lab-shape-rootvault", "lab-shape-decks"]:
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		_check(lv.errors.is_empty() and Rules.shape_problems(lv).is_empty() and Rules.header_problems(lv).is_empty(),
				"%s keeps the shape and header rules %s %s" % [id, Rules.shape_problems(lv), Rules.header_problems(lv)])
	# A deck's gusts on its rows.
	var gl := _level(_hd({"gusts": "4-7:L:A:0-11, 20-23:R:B"}) + "---\n" + "\n".join(loop))
	_check(gl.gusts.size() == 2 and int(gl.gusts[0]["y0"]) == 0 and int(gl.gusts[0]["y1"]) == 11 and not (gl.gusts[1] as Dictionary).has("y0"),
			"a gust zone's rows read (%s)" % [gl.gusts])


func _test_deep_barks() -> void:
	## W6's how-tos facing left (deep.gd): the first float on the route is the
	## rightmost, its window right of it.
	var rows := _blank(60, 15)
	_put(rows, 0, 13, "#".repeat(10) + "::&:::####::&:::" + "#".repeat(34))
	_put(rows, 0, 14, "#".repeat(10) + "::::::####::::::" + "#".repeat(34))
	var left := rows.duplicate()
	_put(left, 56, 12, "P")
	_put(left, 2, 12, "E")
	var lv := _level("title: t\nsubtitle: 6-1\nfacing: left\n---\n" + "\n".join(left), "6-1")
	var d = load("res://scripts/features/deep.gd").new()
	d._plan_barks(lv)
	var fl: Array = d._barks.filter(func(b): return b["key"] == "first_float")
	_check(lv.errors.is_empty() and fl.size() == 1 and int(fl[0]["x0"]) == 21 and int(fl[0]["x1"]) == 32, "facing left: the float met first is the right one, its bark window right of it %s" % [fl])
	var right := rows.duplicate()
	_put(right, 2, 12, "P")
	_put(right, 56, 12, "E")
	var r := _level("title: t\nsubtitle: 6-1\n---\n" + "\n".join(right), "6-1")
	var d2 = load("res://scripts/features/deep.gd").new()
	d2._plan_barks(r)
	var fr: Array = d2._barks.filter(func(b): return b["key"] == "first_float")
	_check(fr.size() == 1 and int(fr[0]["x0"]) == 2 and int(fr[0]["x1"]) == 13, "facing right: the left one, its window left of it, as ever %s" % [fr])


# ---------------------------------------------------------------- the bot

func _test_bot(lv: RefCounted) -> void:
	## The reachability bot (Wick's own physics, test_core's) rings the bell
	## and takes every sigil.
	var t0 := Time.get_ticks_msec()
	var copy = Reach.static_copy(lv)
	var s = ReachSearch.new()
	s.setup(copy, LevelData.cell_floor(copy.start), {"timed": Reach.timed_cells(lv)})
	s.run()
	s.free_player()
	print("  %s: %d states, %d ms" % [lv.id, s.seen.size(), Time.get_ticks_msec() - t0])
	_check(not s.capped, "%s: the bot finishes under the cap" % lv.id)
	for g in s.goals:
		_check(s.found.has(g["what"]), "%s: the bot reaches the %s" % [lv.id, g["what"]])


# ---------------------------------------------------------------- the World

func _world(lv: RefCounted) -> Node2D:
	game.reset()
	game.new_hero("knight")
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	return w


func _test_worlds(tall: RefCounted, mirror: RefCounted, plain: RefCounted) -> void:
	# lab-shapes: it runs; the belt bark waits at the lower belt (met first)
	# though the upper one stands left of it.
	var w := _world(tall)
	await process_frame
	w.test_pad = {}
	for i in 240:
		w.tick(DT)
	_check(w.player.on_floor and w.player.facing == 1, "lab-shapes: he settles on the floor at the start, facing right")
	var cw = w.features.module("clockwork")
	var belt: Dictionary = cw._bark_at.get("belt", {})
	_check(int(belt.get("first", -1)) == 82 and int(belt.get("dir", 0)) == 1 and int(belt.get("sign", -1)) == 76,
			"lab-shapes: the first-time belt bark is the lower belt's (82, met first), not the leftmost (73) %s" % [belt])
	var rattle = w.enemies.filter(func(e): return e.spawn["kind"] == "skeleton")
	_check(rattle.size() == 1 and rattle[0].facing == -1, "facing right, its monsters face left as ever")
	w.queue_free()
	await process_frame
	# lab-mirror and its unmirrored self, one after the other on the same
	# clock: he faces left, the Rattle right; every weight and the swing
	# swing as each other's mirror; each bark's first and spot the mirror.
	var runs := []
	for lv in [plain, mirror]:
		var v := _world(lv)
		await process_frame
		var cw2 = v.features.module("clockwork")
		var thorn = v.enemies.filter(func(e): return e.spawn["kind"] == "skeleton")
		var run := {"facing": v.player.facing, "thorn": thorn[0].facing if thorn.size() == 1 else 0, "bark": cw2._bark_at.duplicate(true),
				"weights": [], "swings": [], "n": [cw2.weights.size(), cw2.swings.size()]}
		for i in 120:
			v.tick(DT)
		# (On the same clock: each World's own, set to the same moments.)
		for t in [0.0, 0.41, 1.3, 2.2, 3.05, 4.4]:
			v.ftime = t
			var at := {}
			for wt in cw2.weights:
				at[int(wt["cell"].x)] = cw2.weight_angle(wt)
			run["weights"].append(at)
			var sw := []
			for m in cw2.swings:
				m.update(t)
				sw.append(float(m.angle))
			run["swings"].append(sw)
		runs.append(run)
		v.queue_free()
		await process_frame
	var ra: Dictionary = runs[0]
	var rb: Dictionary = runs[1]
	_check(int(rb["facing"]) == -1 and int(ra["facing"]) == 1, "lab-mirror: he starts facing left")
	_check(int(rb["thorn"]) == 1 and int(ra["thorn"]) == -1, "lab-mirror: its Rattle faces right, toward him (%d / %d)" % [rb["thorn"], ra["thorn"]])
	var wmax := 0.0
	var smax := 0.0
	for k in 6:
		var wa: Dictionary = ra["weights"][k]
		var wb: Dictionary = rb["weights"][k]
		for x in wa:
			wmax = maxf(wmax, absf(float(wa[x]) + float(wb.get(mirror.width - 1 - int(x), 99.0))))
		smax = maxf(smax, absf(float(ra["swings"][k][0]) + float(rb["swings"][k][0])))
	_check(ra["n"] == [2, 1] and rb["n"] == [2, 1] and wmax < 0.0001, "lab-mirror: each weight's angle the negative of its mirror's at every moment (%.5f)" % wmax)
	_check(smax < 0.0001, "lab-mirror: the swing's too (%.5f)" % smax)
	var bark_ok := true
	for f in ["belt", "cog", "weight", "swing"]:
		var ba: Dictionary = ra["bark"].get(f, {})
		var bb: Dictionary = rb["bark"].get(f, {})
		bark_ok = bark_ok and not ba.is_empty() and not bb.is_empty() and int(bb["first"]) == mirror.width - 1 - int(ba["first"]) \
				and int(bb["sign"]) == mirror.width - 1 - int(ba["sign"]) and int(bb["dir"]) == -1 and int(ba["dir"]) == 1
	_check(bark_ok, "lab-mirror: every first-time bark's first and spot the mirror of the unmirrored one's (%s / %s)" % [rb["bark"], ra["bark"]])
