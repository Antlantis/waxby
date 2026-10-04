# Screenshots of Build 2's twists (scripts/twists.gd) in their labs, for
# checking by eye on the phone-sized view:
#   godot --path game --resolution 1266x585 --script res://../tools/shot_twists.gd -- <mode|all> <out_dir>
# Modes: cards (lab-restless's title card "lab-restless · Restless", then the
# twist's line in the top band; lab-lesson's lesson card), restless (a
# stomped Rattle's remains lying with their wisp, mid-tell, then risen),
# toll (the warning beat's rings on what the bell will quicken, then the
# toll), lamplit (the warm glint on the wax by a lit lantern), dark (the
# dark lab with and without the twist, side by side in two shots).
extends SceneTree

const LevelData := preload("res://scripts/level_data.gd")
const Twists := preload("res://scripts/twists.gd")
var _out := "/tmp"
var game: Node
var W: GDScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "all"
	_out = args[1] if args.size() > 1 else "/tmp"
	DirAccess.make_dir_recursive_absolute(_out)
	game = root.get_node("Game")
	game.save_path = "user://shot_twists_save.json"
	W = load("res://scripts/world.gd")
	await process_frame
	var modes := ["cards", "restless", "toll", "lamplit", "dark"] if mode == "all" else [mode]
	for m in modes:
		await call("_" + m)
	quit()


func _world(id: String, twist := "-") -> Node2D:
	## A lab's World with the HUD and the thumbs (twist: the header to play
	## it with instead, "" for none; "-" keeps the file's).
	game.reset()
	game.new_hero("knight")
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	if twist != "-":
		lv.headers["twist"] = twist
	var w: Node2D = W.new()
	w.setup(lv)
	root.add_child(w)
	w.test_pad = {}
	return w


func _stand(w: Node2D, x: float) -> void:
	w.player.reset_at(Vector2(x, 13 * 32))
	w.player.invuln = 99.0
	w.cam = w._clamp_cam(w.player.position + Vector2(0, -60))


func _run(w: Node2D, n: int, pad := {}) -> void:
	for i in n:
		w.test_pad = pad
		await physics_frame


func _snap(name: String) -> void:
	for i in 3:
		await process_frame
	var path := "%s/%s.png" % [_out, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame
	await process_frame


func _cards() -> void:
	var w := _world("lab-restless")
	await process_frame
	await _run(w, 120)
	await _snap("twist_title")
	await _run(w, 300)
	await _snap("twist_card")
	await _done(w)
	w = _world("lab-lesson")
	await process_frame
	await _run(w, 420)
	await _snap("lesson_card")
	await _done(w)


func _restless() -> void:
	var w := _world("lab-restless")
	await process_frame
	await _run(w, 900)   # (the title and the card go first)
	var tw = w.twists
	var r: Node2D = null
	for e in w.enemies:
		if e.kind == "skeleton" and e.alive and (r == null or e.position.x < r.position.x):
			r = e
	_stand(w, r.position.x - 180.0)
	await _run(w, 20)
	w.deal(r, 1.0, {"how": "stomp", "flat": 9999.0, "no_hitstop": true})
	await _run(w, 220)
	await _snap("restless_lying")
	while tw.remains.size() > 0 and float(tw.remains[0]["tell"]) < 0.6:
		await _run(w, 1)
	await _snap("restless_tell")
	await _run(w, 60)
	await _snap("restless_risen")
	await _done(w)


func _toll() -> void:
	var w := _world("lab-toll")
	await process_frame
	var tw = w.twists
	_stand(w, 44.0 * 32.0)
	while not tw.warning():
		await _run(w, 1)
		w.player.invuln = 99.0
	await _run(w, 30)
	await _snap("toll_warning")
	while tw.warning():
		await _run(w, 1)
	await _run(w, 8)
	await _snap("toll_rung")
	await _done(w)


func _lamplit() -> void:
	var w := _world("lab-lamplit")
	await process_frame
	await _run(w, 900)
	var l: Dictionary = w.features.lanterns[0]
	w.features.light(l)
	_stand(w, (l["cell"].x - 2) * 32.0)
	await _run(w, 30)
	await _snap("lamplit_glint")
	await _done(w)


func _dark() -> void:
	for t in ["", "-"]:
		var w := _world("lab-dark", t)
		await process_frame
		await _run(w, 900)
		_stand(w, 24.0 * 32.0)
		await _run(w, 30)
		await _snap("dark_on" if t == "-" else "dark_off")
		await _done(w)
