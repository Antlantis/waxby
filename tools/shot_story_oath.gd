extends SceneTree
# The oath's chooser, as a new player first meets it: the cards before any
# calling is looked at, then each calling looked at in turn (its info box,
# its plinth's candle lit), on a fresh save (no hero yet); then the map's
# Callings screen with a card open, which names the ease the same way.
#   godot --path game --resolution 1266x585 --script res://../tools/shot_story_oath.gd -- <out_dir> [notch]
# "notch" pretends to be the iPhone in landscape (a 62-px inset left and right).

const DT := 1.0 / 60.0
const NOTCH := Rect2(62, 10, 720, 362)
const ORDER := ["knight", "founder", "witch", "runner", "sexton"]
var out := "/tmp"
var tag := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp"
	if args.size() > 1 and args[1].contains("notch"):
		load("res://scripts/ui.gd").safe_override = NOTCH
		tag = "n_"
	DirAccess.make_dir_recursive_absolute(out)
	RenderingServer.set_default_clear_color(Color("0e0a14"))
	await process_frame
	var game = root.get_node("Game")
	game.save_path = "user://shot_oath_save.json"
	game.reset()
	var cs = load("res://scripts/cutscene.gd").new()
	cs.setup("oath", func(): pass, false, null)
	cs.manual = true
	cs.follow_next = false
	root.add_child(cs)
	await process_frame
	for i in 4000:
		cs.advance(DT)
		if cs.waiting == "class" and float(cs._chooser.get("t", 0.0)) > 0.6:
			break
	await _snap("00_chooser")
	for i in ORDER.size():
		cs._hover(ORDER[i])
		for k in 50:
			cs.advance(DT)
		await _snap("%02d_looked_%s" % [i + 1, ORDER[i]])
	cs.queue_free()
	await process_frame
	# The map's Callings screen says the same words on its card.
	game.new_hero("knight")
	var k = load("res://scripts/keeper_screen.gd").new()
	root.add_child(k)
	await process_frame
	for c in ["knight", "witch"]:
		k.open_card(c)
		for i in 30:
			k._process(DT)
		await _snap("callings_card_%s" % c)
	k.queue_free()
	game.reset()
	quit()


func _snap(what: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s%s.png" % [out, tag, what]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
