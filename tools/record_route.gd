# Records a golden route: every tick's held buttons while a level is played
# with no monsters, into game/tests/routes/<level id>.json (tests/test_routes.gd
# replays each and asserts the bell rings with no snuff).
#
#   godot --path game --script res://../tools/record_route.gd -- <level id> [options]
#     --calling=knight       the calling to play (its quirk moves him: keep ""-free
#                            callings for routes the bot must match? any works)
#     --diff=dusk            the difficulty (the feature knobs follow it)
#     --bot                  the autoplay bot plays instead of you (also headless)
#     --out=<path>           where to write (default game/tests/routes/<id>.json)
#     --max=<seconds>        give up after this long (default 600)
#     --note="..."           what the route proves (written into the file)
#     --no-monsters          accepted, and the default: a route never has monsters
#
# Play with the keyboard (arrows or A/D, Space to jump, X to attack) or the
# touch pad. The route is written when the bell rings; a snuff means start
# over (it quits without writing). Uses the autoplay save, never yours.
extends SceneTree

const Route := preload("res://scripts/route.gd")

var _masks: Array = []
var _world: Node2D
var _id := ""
var _out := ""
var _opts := {}
var _done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: record_route.gd -- <level id> [--bot] [--calling=knight] [--diff=dusk] [--out=path] [--max=600]")
		quit(1)
		return
	_id = args[0]
	for a in args.slice(1):
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_out = str(_opts.get("out", ProjectSettings.globalize_path("res://tests/routes/%s.json" % _id)))
	var game = root.get_node("Game")
	game.save_path = game.AUTOPLAY_SAVE
	game.slot_base = game.AUTOPLAY_SAVE.trim_suffix(".json")
	var LevelData = load("res://scripts/level_data.gd")
	var path := "res://levels/%s.txt" % _id
	if not FileAccess.file_exists(path):
		print("no level %s" % path)
		quit(1)
		return
	var lv = LevelData.load_file(path)
	var route := {"calling": str(_opts.get("calling", "knight")), "diff": str(_opts.get("diff", "dusk"))}
	Route.prepare(game, route, lv)
	_world = load("res://scripts/world.gd").new()
	_world.setup(lv, DisplayServer.get_name() == "headless")
	_world.no_monsters = true
	_world.autoplay = _opts.has("bot")
	_world.on_pad = func(pad: Dictionary) -> void:
		if not _done:
			_masks.append(Route.mask(pad))
	_world.finished.connect(_on_finished)
	root.add_child(_world)
	var limit := float(_opts.get("max", "600"))
	await create_timer(limit).timeout
	if not _done:
		print("gave up after %.0f s (%d ticks): nothing written" % [limit, _masks.size()])
		quit(1)


func _process(_dt: float) -> bool:
	if _world != null and is_instance_valid(_world) and not _done and _world.snuffs > 0:
		_done = true
		print("snuffed: nothing written (start over)")
		quit(1)
	return false


func _on_finished(res: Dictionary) -> void:
	if _done:
		return
	_done = true
	if not bool(res.get("cleared", false)) or int(res.get("snuffs", 0)) > 0:
		print("not a clean clear: nothing written")
		quit(1)
		return
	var route := {"level": _id, "calling": str(_opts.get("calling", "knight")), "diff": str(_opts.get("diff", "dusk")),
			"hero_level": 1, "ticks": _masks.size(), "runs": Route.encode(_masks),
			"end": {"x": roundi(_world.player.position.x), "state": _world.state},
			"note": str(_opts.get("note", "recorded by %s" % ("the autoplay bot" if _opts.has("bot") else "hand")))}
	if Route.save(_out, route):
		print("wrote %s (%d ticks, %.1f s)" % [_out, _masks.size(), _masks.size() / 120.0])
		quit(0)
	else:
		print("couldn't write %s" % _out)
		quit(1)
