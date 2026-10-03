# Screenshots of the level runtime's seams, for checking by eye on the
# phone-sized view:
#   godot --path game --resolution 1266x585 --script res://../tools/shot_world.gd -- <mode|all> <out_dir>
# Modes: satchel (a full satchel: the item stays with its tag, the card),
# owl (Owl's Eye glints on false stone and a sigil), rubble (the Toll of
# Ruin's shadows mid-wait), choir (the Drip Choir's shadows), shards (a
# Vengeful foe's splinters), lights_out (the Snuffer's third phase),
# numbers (hit, crit, hurt and heal floaters), callings (each calling
# mid-fight on 1-2), flames (glow's flames drawn as fans beside the old
# engine-triangulated teardrops, then a badly hurt Waxby far along 2-3 with
# embers by him, each with a close-up), rung (Tollgrave rung: the HUD's
# banner alone and the bonus number clear above the hit's, with a close-up),
# afterkill (a phase-3 slam's waves and rubble in flight, then the kill:
# they're gone and the arena door is open), head (Waxby landing on a
# walking Tollgrave's head: it hurts).
extends SceneTree

const LevelData := preload("res://scripts/level_data.gd")
const Items := preload("res://scripts/items.gd")
var _out := "/tmp"
var game: Node
var W: GDScript
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "all"
	_out = args[1] if args.size() > 1 else "/tmp"
	DirAccess.make_dir_recursive_absolute(_out)
	game = root.get_node("Game")
	game.save_path = "user://shot_world_save.json"
	W = load("res://scripts/world.gd")
	rng.seed = 5
	await process_frame
	var modes := ["flames", "satchel", "owl", "rubble", "choir", "shards", "lights_out", "numbers", "callings", "rung", "afterkill", "head"] if mode == "all" else [mode]
	for m in modes:
		await call("_" + m)
	quit()


func _world(id: String, cls := "knight") -> Node2D:
	game.reset()
	game.new_hero(cls)
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	for k in ["start", "boss"]:
		if str(lv.story.get(k, "")) != "":
			game.mark_seen(str(lv.story[k]))
	var w: Node2D = W.new()
	w.setup(lv)
	root.add_child(w)
	w.test_pad = {}
	return w


func _stand(w: Node2D, col: int) -> void:
	## Waxby on the lowest floor in a column, the camera on him.
	var lv = w.level
	for y in range(lv.height - 1, 0, -1):
		if lv.tile(col, y) == 0 and (lv.is_solid(lv.tile(col, y + 1)) or lv.is_ledge(lv.tile(col, y + 1))):
			w.player.reset_at(Vector2(col * 32 + 16, (y + 1) * 32))
			break
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


func _zoom(name: String, at: Vector2, half: Vector2, times: int) -> void:
	## A close-up: the screen round a point in the 844x390 view, blown up
	## with no smoothing so every pixel shows.
	var img := root.get_texture().get_image()
	var k := img.get_height() / 390.0
	var r := Rect2i(Vector2i((at - half) * k), Vector2i(half * 2.0 * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(r)
	c.resize(c.get_width() * times, c.get_height() * times, Image.INTERPOLATE_NEAREST)
	var path := "%s/%s.png" % [_out, name]
	c.save_png(path)
	print("saved ", path)


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame
	await process_frame


# ---------------------------------------------------------------- the modes

func _satchel() -> void:
	var w := _world("1-1")
	await process_frame
	var keep = game.setting("auto_equip")
	game.set_setting("auto_equip", false)
	_stand(w, 8)
	await _run(w, 400)   # the level's title card goes first
	var h: Dictionary = game.hero()
	while (h["satchel"] as Array).size() < int(game.SATCHEL_MAX):
		game.add_item(Items.make("coat", "knight", 1, "magic", rng))
	var legend := Items.pick_legend("candle", "knight", rng)
	var it := Items.make("candle", "knight", 8, "legendary" if legend != "" else "rare", rng, legend)
	w.place_item(it, w.player.position + Vector2(8, -40), Vector2.ZERO)
	await _run(w, 70)
	await _snap("satchel_card")
	await _run(w, 30, {"left": true})
	await _run(w, 60)
	await _snap("satchel_left_behind")
	game.set_setting("auto_equip", keep)
	await _done(w)


func _owl() -> void:
	var w := _world("2-4")
	await process_frame
	game.grant_relic("owls_eye")
	w.apply_hero()
	_stand(w, 16)
	await _run(w, 60)
	await _snap("owl_glints")
	await _done(w)


func _rubble() -> void:
	var w := _world("1-4")
	await process_frame
	var b: Node2D = w.boss
	b.active = true
	w.player.reset_at(Vector2(b.arena_left + 300.0, b.position.y))
	w.cam = w._clamp_cam(w.player.position + Vector2(0, -60))
	w.player.invuln = 99.0
	await _run(w, 60)
	b.phase = 3
	b._rubble(w.player)
	await _run(w, 36)   # 0.3 s of the 0.6 s wait
	await _snap("rubble_shadows_half")
	await _run(w, 26)
	await _snap("rubble_shadows_late")
	await _done(w)


func _choir() -> void:
	var w := _world("2-4")
	await process_frame
	var b: Node2D = w.boss
	b.active = true
	w.player.reset_at(Vector2(b.arena_left + 200.0, float(b.floor_y)))
	w.cam = w._clamp_cam(w.player.position + Vector2(0, -60))
	w.player.invuln = 99.0
	await _run(w, 80)
	b._choir()
	await _run(w, 48)   # 0.4 s of the 0.8 s swell
	await _snap("choir_shadows_half")
	await _run(w, 40)
	await _snap("choir_shadows_late")
	await _done(w)


func _shards() -> void:
	var w := _world("1-1")
	await process_frame
	_stand(w, 10)
	await _run(w, 40)
	var e: Node2D = w.spawn_enemy("skeleton", w.player.position + Vector2(90, 0), {})
	e.make_elite("anointed", ["vengeful"])
	e.active = true
	w.player.invuln = 99.0
	await _run(w, 10)
	await _run(w, 300)   # the level's title card goes first
	e._shards()
	await _run(w, 22)
	await _snap("vengeful_shards")
	await _done(w)


func _lights_out() -> void:
	var w := _world("2-4", "witch")
	await process_frame
	var b: Node2D = w.boss
	b.active = true
	w.player.reset_at(Vector2(b.arena_left + 160.0, float(b.floor_y)))
	w.cam = w._clamp_cam(w.player.position + Vector2(0, -60))
	w.player.invuln = 99.0
	await _run(w, 120)
	b.phase = 3
	b._enter_phase()
	await _run(w, 300)
	await _snap("snuffer_lights_out")
	w.player.hp = w.player.max_hp * 0.3
	await _run(w, 60)
	await _snap("snuffer_lights_out_low")
	await _done(w)


func _numbers() -> void:
	var w := _world("1-1")
	await process_frame
	_stand(w, 10)
	await _run(w, 330)   # the level's title card goes first
	var pl: Node2D = w.player
	var a: Node2D = w.spawn_enemy("thornback", pl.position + Vector2(70, 0), {})
	var b: Node2D = w.spawn_enemy("thornback", pl.position + Vector2(150, 0), {})
	for e in [a, b]:
		e.active = true
		e.max_hp = 9999.0
		e.hp = 9999.0
	await _run(w, 6)
	w.deal(a, 1.0, {"no_hitstop": true})
	w.deal(b, 3.0, {"force_crit": true, "no_hitstop": true})
	pl.invuln = 0.0
	w.hurt_player(12.0, pl.position.x - 20.0)
	w.number(pl.center() + Vector2(-30, -10), 18.0, "heal")
	await _run(w, 8)
	await _snap("numbers")
	await _done(w)


func _callings() -> void:
	for cls in ["knight", "witch", "runner", "founder", "sexton"]:
		var w := _world("1-2", cls)
		await process_frame
		_stand(w, 30)
		await _run(w, 30)
		for i in 90:
			var t := i / 120.0
			w.test_pad = {"right": i < 40, "attack": (i / 12) % 2 == 0, "special": i > 50 and i < 80}
			await physics_frame
		await _snap("calling_%s" % cls)
		await _done(w)


class OldTears extends Node2D:
	## The flame as glow drew it before: the same halo and teardrops, the
	## teardrops handed to the engine to triangulate (draw_colored_polygon).
	var g: Node2D
	var flames: Array = []

	func _draw() -> void:
		for f in flames:
			var base: Vector2 = f["p"]
			var hh: float = f["h"]
			var r := hh * 0.32
			draw_circle(base + Vector2(0, -hh * 0.4), hh * 1.25, Color(1.0, 0.7, 0.3, 0.10))
			draw_circle(base + Vector2(0, -hh * 0.4), hh * 0.85, Color(1.0, 0.75, 0.35, 0.14))
			draw_colored_polygon(g._tear(base, r, hh, 0.0), g.FLAME_OUT)
			draw_colored_polygon(g._tear(base + Vector2(0, -r * 0.1), r * 0.72, hh * 0.78, 0.0), g.FLAME_MID)
			draw_colored_polygon(g._tear(base + Vector2(0, -r * 0.2), r * 0.42, hh * 0.5, 0.0), g.FLAME_CORE)


func _flames() -> void:
	# 1. Side by side near the screen's corner, where the engine never
	# failed: the new fans (top row) must match the old teardrops (bottom).
	var bg := ColorRect.new()
	bg.color = Color("16121c")
	bg.size = Vector2(900, 400)
	root.add_child(bg)
	var g: Node2D = (load("res://scripts/glow.gd") as GDScript).new()
	var old := OldTears.new()
	old.g = g
	var hs := [2.0, 3.0, 4.5, 6.0, 9.0, 13.0, 19.0, 28.0]
	for i in hs.size():
		var x := 70.0 + i * 95.0
		g.extra_flames.append({"p": Vector2(x, 150.0), "h": hs[i]})
		old.flames.append({"p": Vector2(x, 300.0), "h": hs[i]})
	root.add_child(g)
	root.add_child(old)
	g.set_process(false)          # (after it's ready) time stands still: no flicker, no sway
	g.set("_t", 0.0)
	g.queue_redraw()
	await _snap("flames_fan_vs_old")
	await _zoom("flames_fan_vs_old_zoom_small", Vector2(165.0, 225.0), Vector2(120.0, 105.0), 4)
	for n in [g, old, bg]:
		n.queue_free()
	await process_frame
	# 2. In play, where it used to fail: Waxby at 8% life just hurt, far
	# along 2-3 (x ~3417, where the review saw it), embers by his feet.
	var w := _world("2-3", "witch")
	await process_frame
	_stand(w, 107)
	await _run(w, 330)   # the level's title card goes first
	var pl: Node2D = w.player
	pl.invuln = 99.0
	for i in 3:
		w._add_pickup("ember", pl.position + Vector2(52.0 + i * 22.0, -14.0))
	pl.hp = pl.max_hp * 0.08
	await _run(w, 30)
	var xf := w.get_viewport().get_canvas_transform()
	var at: Vector2 = xf * (pl.position + Vector2(20.0, -30.0))
	await _snap("flames_low_life_far")
	await _zoom("flames_low_life_far_zoom", at, Vector2(80.0, 45.0), 5)
	pl.invuln = 0.0
	pl.hurt_time = 0.02           # the first frames of a hurt: the flame at its smallest
	await process_frame
	await _zoom("flames_low_life_hurt_zoom", at, Vector2(80.0, 45.0), 5)
	await _done(w)


func _toll(cls := "knight") -> Node2D:
	## 1-4 with an L7 hero 200 px into the arena, Tollgrave awake, the phone's
	## safe area on, and the title card already seen.
	game.reset()
	game.new_hero(cls)
	var h: Dictionary = game.hero()
	h["level"] = 7
	h["xp"] = load("res://scripts/progression.gd").total_to(7)
	game.mark_seen("boss_card_tollgrave")
	var lv = LevelData.load_file("res://levels/1-4.txt")
	for k in ["start", "boss"]:
		if str(lv.story.get(k, "")) != "":
			game.mark_seen(str(lv.story[k]))
	var UI = load("res://scripts/ui.gd")
	UI.safe_override = UI.phone_safe(root.get_visible_rect().size)
	var w: Node2D = W.new()
	w.setup(lv)
	root.add_child(w)
	w.test_pad = {}
	await _run(w, 60)
	var b: Node2D = w.boss
	w.player.reset_at(Vector2(b.arena_left + 200.0, b.position.y))
	w.cam = w._clamp_cam(w.player.position + Vector2(0, -60))
	w.player.invuln = 999.0
	await _run(w, 520)   # past the level's title card
	return w


func _toll_done(w: Node2D) -> void:
	load("res://scripts/ui.gd").safe_override = Rect2()
	await _done(w)


func _rung() -> void:
	var w: Node2D = await _toll()
	var b: Node2D = w.boss
	b.state = "stuck"
	b.timer = 3.0
	b._window_dmg = 0.0
	b._rung_phase = 0
	b.phase = 1
	b.hp = b.max_hp
	w.deal(b, 1.0, {"flat": 0.34 * b.max_hp, "no_hitstop": true, "force_crit": true})
	await _run(w, 6)
	await _snap("toll_rung")
	var at: Vector2 = b.get_global_transform_with_canvas().origin
	await _zoom("toll_rung_numbers", at + Vector2(0, -90), Vector2(90, 60), 3)
	await _toll_done(w)


func _afterkill() -> void:
	var w: Node2D = await _toll()
	var b: Node2D = w.boss
	w.player.reset_at(Vector2(b.arena_left + 150.0, b.position.y))
	w.cam = w._clamp_cam(w.player.position + Vector2(160, -60))
	b.phase = 3
	b.hp = b.max_hp * 0.05
	b._rung_phase = 3
	b.state = "windup"
	b.timer = 0.01
	await _run(w, 36)
	await _snap("afterkill_before")
	print("  before the kill: %d hazards, door %s" % [w.hazards.size(), str(b.door.map(func(c): return w.level.tile(c.x, c.y)))])
	# The door, sealed, framed from inside the arena.
	var here: Vector2 = w.player.position
	w.player.reset_at(Vector2(b.arena_left + 40.0, b.position.y))
	await _run(w, 40)
	await _snap("afterkill_door_before")
	w.player.reset_at(here)
	w.deal(b, 1.0, {"flat": 99999.0, "no_hitstop": true})
	await _run(w, 12)
	await _snap("afterkill_now")
	print("  after the kill: %d hazards, door %s" % [w.hazards.size(), str(b.door.map(func(c): return w.level.tile(c.x, c.y)))])
	w.player.reset_at(Vector2(b.arena_left + 40.0, b.position.y))
	await _run(w, 40)
	await _snap("afterkill_door_open")
	await _toll_done(w)


func _head() -> void:
	var w: Node2D = await _toll()
	var b: Node2D = w.boss
	b.state = "walk"
	b.timer = 5.0
	await _run(w, 2)
	w.player.invuln = 0.0
	w.player.reset_at(Vector2(b.center().x, b.rect().position.y - 30.0))
	w.player.velocity = Vector2(0, 240)
	w.cam = w._clamp_cam(w.player.position + Vector2(0, -20))
	var hp0: float = w.player.hp
	var n := 0
	while w.player.hp >= hp0 and n < 60:
		await _run(w, 1)
		n += 1
	await _run(w, 8)
	print("  landing on a walking Tollgrave's head: hp %.0f -> %.0f, boss hp %.0f / %.0f" % [hp0, w.player.hp, b.hp, b.max_hp])
	await _snap("toll_head_hurts")
	await _toll_done(w)
