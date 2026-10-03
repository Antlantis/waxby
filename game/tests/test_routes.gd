extends SceneTree
## The golden routes (contract.md §15): every game/tests/routes/<id>.json,
## recorded by tools/record_route.gd, replays in a headless World with no
## monsters and rings the bell with no snuff. Replays are exact: the World's
## timings come from world.ftime and x at fixed 1/120 s ticks. A route whose
## level isn't there is skipped (a level stream's file not merged yet). A boss
## level's approach stops short of the bell (until_of: "until_x", "until"
## {x | altar}, or a "<id>@<name>" level's recorded end) and passes there.
##
##     godot --headless --path game --script res://tests/test_routes.gd

const LevelData := preload("res://scripts/level_data.gd")
const Route := preload("res://scripts/route.gd")
const DT := 1.0 / 120.0
const DIR := "res://tests/routes"

var WorldScript: GDScript
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
	game.save_path = "user://test_routes_save.json"
	game.reset()
	_test_codec()
	var files := []
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".json"):
				files.append(f)
	files.sort()
	if files.is_empty():
		print("  (no routes recorded yet)")
	for f in files:
		await _replay(DIR.path_join(f))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_routes_save.json" + suffix))
	print("test_routes: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_codec() -> void:
	var masks := [0, 0, 3, 3, 3, 16, 0]
	_check(Route.decode(Route.encode(masks)) == masks, "a route's run-length code round-trips")
	_check(Route.pad_of(Route.mask({"left": true, "jump": true, "up": true})) == {"left": true, "jump": true, "up": true}, "a pad's mask round-trips")


static func until_of(route: Dictionary) -> Dictionary:
	## Where a route may stop short of the bell (a boss level's approach: its
	## bell only comes with the boss, whom no_monsters leaves out): "until_x"
	## (px), "until" {"x": px} or {"altar": cell x}, or, for a level id with
	## an '@' ("4-4@approach") and none of those, the x it ended at. {} means
	## the route must ring the bell.
	if route.has("until") and route["until"] is Dictionary:
		return route["until"]
	if route.has("until_x"):
		return {"x": float(route["until_x"])}
	if str(route.get("level", "")).contains("@") and (route.get("end", {}) as Dictionary).has("x"):
		return {"x": float(route["end"]["x"]) - 1.0}
	return {}


static func level_of(route: Dictionary, path: String) -> String:
	## The level a route plays: "for", else "level" up to any '@'.
	if route.has("for"):
		return str(route["for"])
	return str(route.get("level", path.get_file().get_basename())).get_slice("@", 0)


func _reached(w: Node2D, until: Dictionary) -> bool:
	if until.has("altar"):
		for a in w.altars:
			if int(a["cell"].x) == int(until["altar"]) and bool(a["lit"]):
				return true
		return false
	return w.player.position.x >= float(until.get("x", INF))


func _replay(path: String) -> void:
	var route := Route.read(path)
	var name := str(route.get("level", path.get_file().get_basename()))
	var id := level_of(route, path)
	var until := until_of(route)
	_check(not route.is_empty() and route.has("runs"), "%s reads" % path.get_file())
	if route.is_empty():
		return
	var lpath := "res://levels/%s.txt" % id
	if not FileAccess.file_exists(lpath):
		print("  %s: skipped: %s missing" % [path.get_file(), lpath.get_file()])
		return
	var lv = LevelData.load_file(lpath)
	Route.prepare(game, route, lv)
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = true
	# The replay drives every tick itself: the World's own loop stays off, or
	# the first frame would run it for as many idle ticks as that frame took
	# (up to 6, a timing), and every feature clock would start that far ahead.
	w.paused = true
	root.add_child(w)
	await process_frame
	var masks := Route.decode(route["runs"])
	var t0 := Time.get_ticks_msec()
	var rang_at := -1
	var got_at := -1
	for i in masks.size():
		w.test_pad = Route.pad_of(int(masks[i]))
		w._read_pad()
		w.tick(DT)
		if rang_at < 0 and w.state == "clear":
			rang_at = i
		if got_at < 0 and not until.is_empty() and _reached(w, until):
			got_at = i
	if until.is_empty():
		print("  %s: %d ticks (%.1f s), the bell at tick %d, %d snuffs, %d ms" % [id, masks.size(), masks.size() * DT, rang_at, w.snuffs, Time.get_ticks_msec() - t0])
		_check(w.state == "clear" and rang_at >= 0, "%s: the route rings the bell" % id)
	else:
		print("  %s (on %s): %d ticks (%.1f s), %s at tick %d, %d snuffs, %d ms" % [name, id, masks.size(), masks.size() * DT, until, got_at, w.snuffs, Time.get_ticks_msec() - t0])
		_check(got_at >= 0, "%s: the route gets to %s (x %.0f)" % [name, until, w.player.position.x])
	_check(w.snuffs == 0, "%s: with no snuff (%d)" % [name, w.snuffs])
	var end: Dictionary = route.get("end", {})
	if end.has("x"):
		_check(absf(w.player.position.x - float(end["x"])) <= 1.0, "%s: and ends where it was recorded (x %.0f, recorded %d)" % [name, w.player.position.x, int(end["x"])])
	w.queue_free()
	await process_frame
