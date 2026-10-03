# The skill cards a kit fix changed, on the Hero sheet's Skills tab, for
# checking the words fit by eye (the phone's island inset on both sides).
#   godot --path game --resolution 1266x585 --audio-driver Dummy \
#       --script res://../tools/shot_kits_cards.gd -- <out_dir>
# Saves <out_dir>/<W>x<H>_card_<calling>_<node>_r<rank>.png. Its own save
# (user://shots_cards_save.json), so a real save is never touched.
extends SceneTree

# [calling, hero level, nodes bought in order, the node shown]
const CARDS := [
	["sexton", 10, ["x_digger", "x_digger", "x_gravedirt"], "x_chill"],
	["sexton", 10, ["x_digger", "x_digger", "x_gravedirt", "x_chill"], "x_chill"],
	["sexton", 10, ["x_digger", "x_digger", "x_gravedirt", "x_chill", "x_chill", "x_chill"], "x_chill"],
	["witch", 10, ["w_reservoir", "w_reservoir", "w_waxskin", "w_seal"], "w_seal"],
]

var UI
var Progression
var game: Node
var _out := "/tmp"
var _tag := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(_out)
	UI = load("res://scripts/ui.gd")
	Progression = load("res://scripts/progression.gd")
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shots_cards_save.json"
	game.settings_path = "user://shots_cards_settings.json"
	for p in [game.save_path, game.settings_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	game.reset()
	await process_frame
	var vs: Vector2 = root.get_visible_rect().size
	UI.safe_override = UI.phone_safe(vs)
	var win := DisplayServer.window_get_size()
	_tag = "%dx%d" % [win.x, win.y]
	for c in CARDS:
		await _card(c[0], c[1], c[2], c[3])
	UI.safe_override = Rect2()
	for p in [game.save_path, game.settings_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("done ", _tag)
	quit()


func _card(cls: String, level: int, buys: Array, show: String) -> void:
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx" and c.name != "Overlay":
			c.queue_free()
	await process_frame
	game.reset()
	game.new_hero(cls)
	game.add_xp(Progression.total_to(level) - int(game.hero()["xp"]))
	for id in buys:
		game.buy_skill(id)
	var h = load("res://scripts/hero_screen.gd").new()
	root.add_child(h)
	h.open_tab("skills")
	await create_timer(0.2).timeout
	h.panel.select(show)
	await create_timer(0.3).timeout
	await process_frame
	await process_frame
	var rank := int(game.hero()["skills"].get(show, 0))
	var path := "%s/%s_card_%s_%s_r%d.png" % [_out, _tag, cls, show, rank]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
