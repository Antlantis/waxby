extends SceneTree
## Contact sheets of the five callings in a real level, for checking the rig
## by eye: each calling in 1-1 at idle, run, jump, fall, its basic attack,
## its Special and hurt, facing right (top row) and left (bottom row), close
## up (camera zoom), plus a full-size frame at the phone's own scale.
##   godot --path game --resolution 1266x585 --script res://../tools/shot_kits.gd -- <out_dir> [cls,cls,...|all] [set] [zoom] [level]
## set: "base" (the seven poses above, the default), "extra" (each calling's
## own moves: a second run phase, landing, the Special's other forms, the
## quirk) or "gear" (Legendary gear worn: candle size, cape tint, glint).
## Saves <out_dir>/kits_<cls>[_<set>].png and, for base, <out_dir>/kits_<cls>_game.png.
## The world is paused while each frame is taken, so the pose holds still.

const LevelData := preload("res://scripts/level_data.gd")
const Items := preload("res://scripts/items.gd")
const CELL := Vector2i(300, 360)   # each pose's crop, in window px
const BASE := ["idle", "run", "jump", "fall", "basic", "special", "hurt"]
const EXTRA := {
	"knight": ["run2", "land", "rush", "finisher", "block", "stagger", "ledge", "dead"],
	"witch": ["run2", "land", "charged", "drift", "tap_flare", "beacon", "dead"],
	"runner": ["run2", "land", "cling", "throw_down", "stab", "reload", "dead"],
	"founder": ["run2", "land", "anvil", "stampede", "molten", "swing_up", "dead"],
	"sexton": ["run2", "land", "wisps", "toll_hold", "grave_step", "knell_late", "dead"],
}
const GEAR := ["idle", "run", "jump", "basic"]

var _out := "/tmp"
var _w: Node2D
var _zoom := 3.0
var _set := "base"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	var classes: Array = ["knight", "witch", "runner", "founder", "sexton"]
	if args.size() > 1 and args[1] != "all":
		classes = Array(args[1].split(","))
	if args.size() > 2:
		_set = args[2]
	if args.size() > 3:
		_zoom = float(args[3])
	var level_id: String = args[4] if args.size() > 4 else "1-1"
	DirAccess.make_dir_recursive_absolute(_out)
	_game = root.get_node("Game")
	_game.save_path = "user://shot_kits_save.json"
	await process_frame
	for cls in classes:
		_game.reset()
		_game.new_hero(cls)
		for s in ["intro", "oath", "beat_1_1"]:
			_game.mark_seen(s)
		if _set == "gear":
			_dress(cls)
		var poses: Array = BASE if _set == "base" else (GEAR if _set == "gear" else EXTRA[cls])
		await _sheet(cls, level_id, poses)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_kits_save.json"))
	quit()


func _dress(cls: String) -> void:
	## Tier 3 gear: a Legendary weapon, a Legendary candle, a Rare coat.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_game.equip(Items.make("weapon", cls, 24, "legendary", rng, "dawnsliver"))
	_game.equip(Items.make("candle", cls, 24, "legendary", rng, "gutterlight"))
	_game.equip(Items.make("coat", cls, 24, "rare", rng))


func _world(level_id: String) -> void:
	var lv = LevelData.load_file("res://levels/%s.txt" % level_id)
	_w = load("res://scripts/world.gd").new()
	_w.setup(lv)
	root.add_child(_w)
	await process_frame
	_w.test_pad = {}
	for e in _w.enemies.duplicate():
		if e != _w.boss:
			e.alive = false
			e.gone = true
			e.visible = false
	if _w.hud:
		_w.hud.visible = false
	if _w.touch:
		_w.touch.visible = false


func _frames(pad: Dictionary, n: int) -> void:
	for i in n:
		_w.test_pad = pad
		await physics_frame


func _place(x: float, facing: int) -> void:
	var pl: Node2D = _w.player
	pl.alive = true
	pl.reset_at(Vector2(x, 13 * 32))
	pl.facing = facing
	pl.hurt_time = 10.0
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	pl.attack_time = -1.0
	_w.state = "play"
	_w.kit.on_respawn()
	_w.floaters.items.clear()   # the last pose's numbers and words
	await _frames({}, 50)
	pl.res = pl.res_max   # after on_respawn (the Bellfounder's Heat starts cold)


func _rattle(at: Vector2, f: int) -> Node2D:
	var e: Node2D = _w.spawn_enemy("skeleton", at, {})
	e.active = true
	e.facing = f
	e.apply_status("root", 99.0)
	return e


func _pose(name: String, f: int) -> void:
	## Drives the hero into one pose (facing f) and leaves him there.
	var dir := "right" if f > 0 else "left"
	var pl: Node2D = _w.player
	var kit: Object = _w.kit
	var cls: String = pl.stats.get("cls", "knight")
	await _place(12 * 32 if f > 0 else 22 * 32, f)
	match name:
		"idle":
			await _frames({}, 60)
		"run":
			await _frames({dir: true}, 60)
		"run2":
			await _frames({dir: true}, 71)
		"jump":
			await _frames({dir: true}, 20)
			await _frames({dir: true, "jump": true}, 16)
		"fall":
			await _frames({"jump": true}, 50)
			await _frames({}, 26)
		"land":
			await _frames({"jump": true}, 40)
			for i in 200:
				await _frames({}, 1)
				if pl.on_floor:
					break
			await _frames({}, 2)
		"basic":
			await _frames({"attack": true}, 1)
			await _frames({}, 7 if cls in ["knight", "founder", "sexton"] else 5)
		"special":
			match cls:
				"knight":
					await _frames({"special": true}, 40)
				"witch":
					await _frames({"special": true}, 50)
				"runner":
					await _frames({dir: true}, 10)
					await _frames({dir: true, "special": true}, 6)
				"founder":
					await _frames({"special": true}, 6)
				"sexton":
					pl.res = pl.res_max
					await _frames({"special": true}, 1)
					await _frames({}, 14)
		"hurt":
			pl.take_damage(5.0, pl.position.x + f * 16.0, "hit", null, {})
			await _frames({}, 8)
		"dead":
			pl.die()
			await _frames({}, 90)
		# The Candleknight.
		"rush":
			await _frames({dir: true, "special": true}, 8)
		"finisher":
			for i in 2:
				await _frames({"attack": true}, 1)
				await _frames({}, 40)
			await _frames({"attack": true}, 1)
			await _frames({}, 9)
		"block":
			_rattle(pl.position + Vector2(f * 60, 0), -f)
			await _frames({"special": true}, 40)
			pl.take_damage(30.0, pl.position.x + f * 20.0, "hit", _w.enemies.back(), {})
			await _frames({"special": true}, 3)
		"ledge":
			# The Ledge Grab's haul, held where it starts (no wall needed).
			await _frames({"jump": true}, 20)
			pl.set("_ledge_from", pl.position)
			pl.set("_ledge_to", pl.position)
			pl.velocity = Vector2.ZERO
			pl.ledge_t = 0.06
			await _frames({}, 2)
		"stagger":
			await _frames({"special": true}, 40)
			pl.res = 0.0
			pl.take_damage(30.0, pl.position.x + f * 20.0, "hit", null, {})
			await _frames({}, 10)
		# The Taperwitch.
		"charged":
			await _frames({"special": true}, 90)
		"drift":
			await _frames({"jump": true}, 44)
			await _frames({}, 2)
			await _frames({"jump": true}, 50)
		"tap_flare":
			await _frames({"special": true}, 2)
			await _frames({}, 10)
		"beacon":
			await _frames({"special": true}, 70)
			await _frames({}, 110)
		# The Sootrunner.
		"cling":
			await _frames({"jump": true}, 30)
			pl.clinging = f
			pl.velocity = Vector2(0, 70)
		"throw_down":
			await _frames({"jump": true}, 30)
			await _frames({"attack": true, "down": true}, 1)
			await _frames({"down": true}, 3)
		"stab":
			_rattle(pl.position + Vector2(f * 30, 0), f)
			await _frames({"attack": true}, 1)
			await _frames({}, 5)
		"reload":
			await _frames({"attack": true}, 1)
			await _frames({}, 22)
		# The Bellfounder.
		"anvil":
			await _frames({"jump": true}, 36)
			await _frames({"special": true}, 1)
			await _frames({}, 3)
		"stampede":
			await _frames({dir: true}, 150)
		"molten":
			pl.res = pl.res_max
			kit.set("_since_hit", 0.0)
			await _frames({}, 1)
		"swing_up":
			await _frames({"attack": true}, 1)
			await _frames({}, 2)
		# The Sexton.
		"wisps":
			for i in 2:
				pl.res = pl.res_max
				await _frames({"special": true}, 1)
				await _frames({}, 20)
			await _frames({}, 120)
		"toll_hold":
			for i in 2:
				pl.res = pl.res_max
				await _frames({"special": true}, 1)
				await _frames({}, 20)
			pl.res = pl.res_max
			await _frames({"special": true}, 30)
		"grave_step":
			await _frames({"jump": true}, 40)
			await _frames({}, 2)
			await _frames({"jump": true}, 8)
		"knell_late":
			pl.res = pl.res_max
			await _frames({"special": true}, 1)
			await _frames({}, 34)


func _grab() -> Image:
	## The window now, centred on the hero; the world holds still meanwhile.
	_w.paused = true
	for i in 3:
		_aim()
		await process_frame
	var img := root.get_texture().get_image()
	_w.paused = false
	img.convert(Image.FORMAT_RGBA8)
	return img


func _aim() -> void:
	var cam: Camera2D = _w.camera
	cam.zoom = Vector2(_zoom, _zoom)
	cam.offset = _w.player.center() + Vector2(0, -14) - cam.position


func _sheet(cls: String, level_id: String, poses: Array) -> void:
	await _world(level_id)
	var sheet := Image.create_empty(CELL.x * poses.size(), CELL.y * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		var f := 1 if row == 0 else -1
		for col in poses.size():
			await _pose(poses[col], f)
			var img := await _grab()
			var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
			sheet.blit_rect(img, Rect2i(c - CELL / 2, CELL), Vector2i(col * CELL.x, row * CELL.y))
			for e in _w.enemies:
				if e.alive:
					e.alive = false
					e.gone = true
					e.visible = false
	var path := "%s/kits_%s%s.png" % [_out, cls, "" if _set == "base" else "_" + _set]
	sheet.save_png(path)
	print("saved ", path)
	if _set == "base":
		# One frame at the game's own scale: running, mid-Special.
		var cam: Camera2D = _w.camera
		cam.zoom = Vector2.ONE
		cam.offset = Vector2.ZERO
		await _place(12 * 32, 1)
		await _frames({"right": true}, 40)
		if _w.hud:
			_w.hud.visible = true
		if _w.touch:
			_w.touch.visible = true
		await _frames({"right": true, "special": cls != "runner"}, 20 if cls == "witch" else 8)
		for i in 3:
			await process_frame
		root.get_texture().get_image().save_png("%s/kits_%s_game.png" % [_out, cls])
	_w.queue_free()
	await process_frame
	await process_frame
