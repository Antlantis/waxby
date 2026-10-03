extends RefCounted
## A golden route: the held buttons of every tick of one play of a level with
## no monsters, recorded by tools/record_route.gd into
## game/tests/routes/<level id>.json and replayed by tests/test_routes.gd in
## a headless World. The World's timings come only from world.ftime and x,
## at fixed 1/120 s ticks, so a replay is exact: it proves a person (or the
## autoplay bot) can make every timed crossing (a cog, a swing, a float, a
## buoy, a gust zone, the tide), and it breaks when a later edit makes one
## impossible.
##
## The file: {level, calling, diff, hero_level, ticks, runs: [[mask, n], ...],
## end: {x, state}, note}. mask has a bit per held button (KEYS).

const LevelData := preload("res://scripts/level_data.gd")
const KEYS := ["left", "right", "down", "up", "jump", "attack", "special", "flask"]
const DT := 1.0 / 120.0


static func mask(pad: Dictionary) -> int:
	var m := 0
	for i in KEYS.size():
		if pad.get(KEYS[i], false):
			m |= 1 << i
	return m


static func pad_of(m: int) -> Dictionary:
	var out := {}
	for i in KEYS.size():
		if m & (1 << i):
			out[KEYS[i]] = true
	return out


static func encode(masks: Array) -> Array:
	## Run-length: [[mask, n], ...].
	var out := []
	for m in masks:
		if not out.is_empty() and int(out[out.size() - 1][0]) == int(m):
			out[out.size() - 1][1] = int(out[out.size() - 1][1]) + 1
		else:
			out.append([int(m), 1])
	return out


static func decode(runs: Array) -> Array:
	var out := []
	for r in runs:
		for i in int(r[1]):
			out.append(int(r[0]))
	return out


static func save(path: String, route: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(route, "\t"))
	return true


static func read(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func prepare(game: Node, route: Dictionary, lv: RefCounted) -> void:
	## The Game as the route was recorded: a fresh save, its calling and
	## difficulty, the level's story already seen (so no beat plays).
	game.reset()
	game.new_hero(str(route.get("calling", "knight")))
	game.data["difficulty"] = str(route.get("diff", "dusk"))
	for k in ["start", "boss", "end"]:
		var s := str(lv.story.get(k, ""))
		if s != "":
			game.mark_seen(s)
