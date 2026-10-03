# The results screen's "Embers" row from real level runs, before and after
# the fix that splits the purse from the level's own embers:
#   godot --path game --resolution 1266x585 --audio-driver Dummy \
#       --script res://../tools/shot_world_embers.gd -- <out_dir>
# Two runs are played through world.gd itself (not made-up results): 1-1 on
# Nightfall with every monster killed, a stomp chain and some of its own
# embers taken; and 2-4 (the Snuffer's level, which holds none of its own)
# with its monsters killed. Each result is shown on results_screen.gd as it
# is ("<run>_now.png") and on a copy compiled with the proposed Embers row
# ("<run>_fixed.png"), plus a close-up of the tally for each.
extends SceneTree

const LevelData := preload("res://scripts/level_data.gd")
const DT := 1.0 / 120.0

# The line results_screen.gd draws the row's number with today.
const OLD_LINE := "\tUI.text(self, Vector2(x, y), \"%d / %d\" % [int(_shown_embers), int(result.get(\"embers_total\", 0))], 20, Color(UI.GOLD, a1), HORIZONTAL_ALIGNMENT_RIGHT, w, \"body\", 700)\n"
# The proposed row: the purse gained, and the level's own embers found (in
# pieces) muted after the label when it holds any.
const NEW_LINES := "\tUI.text(self, Vector2(x, y), \"%d\" % int(_shown_embers), 20, Color(UI.GOLD, a1), HORIZONTAL_ALIGNMENT_RIGHT, w, \"body\", 700)\n" \
		+ "\t# The level's own embers found (placed ones and reliquaries, in pieces,\n" \
		+ "\t# not worth); kill drops and chains only swell the purse above.\n" \
		+ "\tvar own := int(result.get(\"embers_total\", 0))\n" \
		+ "\tif own > 0 and result.has(\"embers_placed\"):\n" \
		+ "\t\tvar lw := UI.text_width(\"Embers\", 18, \"body\", 700)\n" \
		+ "\t\tUI.text(self, Vector2(x + 32.0 + lw + 10.0, y - 1.0), \"%d / %d found\" % [int(result[\"embers_placed\"]), own], 13, Color(UI.MUTED, a1), HORIZONTAL_ALIGNMENT_LEFT, -1, \"body\", 700)\n"

var game: Node
var W: GDScript
var _out := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shot_world_embers_save.json"
	game.settings_path = "user://shot_world_embers_settings.json"
	W = load("res://scripts/world.gd")
	var fixed := _patched()
	var runs := [["1-1_nightfall", "1-1", "nightfall", 0.5], ["2-4_dusk", "2-4", "dusk", 1.0]]
	for r in runs:
		var res: Dictionary = await _play(r[1], r[2], r[3])
		print("%s: embers %d, embers_total %d, embers_placed %d" % [r[0], int(res["embers"]), int(res["embers_total"]), int(res["embers_placed"])])
		await _show(load("res://scripts/results_screen.gd"), res, r[0] + "_now")
		if fixed:
			await _show(fixed, res, r[0] + "_fixed")
	quit()


func _patched() -> GDScript:
	var src := FileAccess.get_file_as_string("res://scripts/results_screen.gd")
	if not src.contains(OLD_LINE):
		print("results_screen.gd no longer has the old Embers line: no _fixed shots")
		return null
	var scr := GDScript.new()
	scr.source_code = src.replace(OLD_LINE, NEW_LINES)
	var err := scr.reload()
	if err != OK:
		print("the patched results_screen.gd fails to compile: ", err)
		return null
	return scr


func _play(id: String, diff: String, own_frac: float) -> Dictionary:
	## Plays a level through world.gd: every monster (not a boss) killed and
	## its embers picked up, a 4-stomp chain, then own_frac of the level's
	## placed embers and one ember reliquary. Returns world.result(), shown
	## as a clear.
	game.reset()
	game.data["unlocked"]["nightfall"] = 1
	game.new_hero("knight")
	game.data["difficulty"] = diff
	var w: Node2D = W.new()
	w.setup(LevelData.load_file("res://levels/%s.txt" % id), true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	for i in 10:
		w.tick(DT)
	var pl: Node2D = w.player
	for e in w.enemies.duplicate():
		if e.alive and e != w.boss:
			pl.position = e.position + Vector2(-40, 0)
			w.deal(e, 1.0, {"flat": e.max_hp * 20.0, "no_hitstop": true})
	w.chain = 0
	for i in 4:
		w._stomp_chain(Rect2(pl.position.x - 10, pl.position.y, 20, 20))
	for i in int(1.5 / DT):
		w.tick(DT)
	var own: Array = []
	for p in w.pickups:
		if p["kind"] == "ember" and not p["taken"]:
			if p.get("placed", false):
				own.append(p)
			else:
				w._collect(p)
	for i in int(own.size() * own_frac):
		w._collect(own[i])
	for c in w.blocks:
		if w.blocks[c]["contents"] == "embers" and not w.blocks[c]["spent"]:
			w._open_block(c)
			break
	for i in int(1.0 / DT):
		w.tick(DT)
	var res: Dictionary = w.result()
	res["cleared"] = true
	w.queue_free()
	await process_frame
	return res


func _show(scr: GDScript, res: Dictionary, name: String) -> void:
	var r: Control = scr.new()
	r.result = res
	r.index = maxi(game.LEVELS.map(func(l): return l["id"]).find(res["level"]), 0)
	root.add_child(r)
	await create_timer(4.5).timeout
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	# The tally, close up (the left column's top rows).
	var k := img.get_width() / 844.0
	var crop := img.get_region(Rect2i(Vector2i(int(60 * k), int(70 * k)), Vector2i(int(380 * k), int(130 * k))))
	crop.save_png("%s/%s_tally.png" % [_out, name])
	print("saved %s/%s.png" % [_out, name])
	r.queue_free()
	await process_frame
