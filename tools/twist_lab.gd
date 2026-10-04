# Plays a level by hand with Build 2's twists (scripts/twists.gd), monsters
# and all, on the Mac (the keyboard, a controller or the touch pad):
#   godot --path game --resolution 1266x585 --script res://../tools/twist_lab.gd -- <level id> [options]
#     <level id>             a twist lab (lab-restless, lab-restless-all, lab-toll,
#                            lab-dark, lab-omens, lab-dry, lab-packs, lab-lamplit,
#                            lab-lesson) or any level (1-2, 3-2, ...)
#     --twist=<id>           play it with this twist instead of its header's
#                            (restless, restless_all, dark, omens, dry, packs,
#                            toll, lamplit; "none" for none)
#     --lesson="Title|Line"  a lesson card on it too
#     --diff=dusk            the difficulty
#     --calling=knight       the calling
# The bell (or Esc's quit) ends it. Uses its own save (user://twist_lab_save.json),
# never yours; a lab writes nothing to it anyway.
extends SceneTree

const LevelData := preload("res://scripts/level_data.gd")
const Twists := preload("res://scripts/twists.gd")

var _opts := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: twist_lab.gd -- <level id> [--twist=<id>|none] [--lesson=\"Title|Line\"] [--diff=dusk] [--calling=knight]")
		quit(1)
		return
	var id := str(args[0])
	for a in args.slice(1):
		if str(a).begins_with("--"):
			var kv := str(a).substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var path := "res://levels/%s.txt" % id
	if not FileAccess.file_exists(path):
		print("no level %s" % path)
		quit(1)
		return
	var game: Node = root.get_node("Game")
	game.save_path = "user://twist_lab_save.json"
	game.reset()
	game.new_hero(str(_opts.get("calling", "knight")))
	game.data["difficulty"] = str(_opts.get("diff", "dusk"))
	var lv = LevelData.load_file(path)
	if _opts.has("twist"):
		lv.headers["twist"] = "" if str(_opts["twist"]) == "none" else str(_opts["twist"])
	if _opts.has("lesson"):
		lv.headers["lesson"] = str(_opts["lesson"])
	for k in ["start", "boss"]:
		if str(lv.story.get(k, "")) != "":
			game.mark_seen(str(lv.story[k]))   # (no scenes: straight to the level)
	var w: Node2D = load("res://scripts/world.gd").new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	print("%s: twist '%s' (rule '%s'), %s" % [id, w.twist_id(), Twists.rule_of(w.twist_id()), w.diff])
	w.finished.connect(func(r: Dictionary): _end(w, "the bell: %s" % ("rung" if r.get("cleared", false) else "not rung")))
	w.quit.connect(func(): _end(w, "quit"))
	w.restart.connect(func(): _end(w, "restart"))


func _end(w: Node2D, why: String) -> void:
	var tw = w.get("twists")
	print("%s (%s)" % [why, tw.log_extra() if tw != null else {}])
	quit()
