# Close-up shots of the monsters, props, elites and the Snuffer, for checking
# the art, the tells and the hitboxes by eye.
#   godot --path game --resolution 1266x585 --script res://../tools/shot_content.gd -- <out_dir> [scene...] [debug]
# Scenes: bonebow helm wing drip jaw lurk old thorn props elites snuffer dark
# copies (Twinned halves, and a Taperwitch's spark on a puddle) levels (every level at a few columns). "debug" draws each monster's
# body (green), what hurts (red), its eyes (cyan) and its feet (yellow).
extends SceneTree

var LevelData
var World
var EK
var out := "/tmp"
var only: Array = []
var debug := false
var _dbg: Node2D
var _w: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp"
	for i in range(1, args.size()):
		if args[i] == "debug":
			debug = true
		else:
			only.append(args[i])
	DirAccess.make_dir_recursive_absolute(out)
	LevelData = load("res://scripts/level_data.gd")
	World = load("res://scripts/world.gd")
	EK = load("res://scripts/enemy_kinds.gd")
	await process_frame
	var game = root.get_node("Game")
	game.save_path = "user://shot_content.json"
	game.reset()
	if _want("bonebow"):
		await bonebow()
	if _want("helm"):
		await helm()
	if _want("wing"):
		await wing()
	if _want("drip"):
		await drip()
	if _want("jaw"):
		await jaw()
	if _want("lurk"):
		await lurk()
	if _want("old"):
		await old()
	if _want("thorn"):
		await thorn()
	if _want("props"):
		await props()
	if _want("elites"):
		await elites()
	if _want("dark"):
		await dark()
	if _want("copies"):
		await copies()
	if _want("snframes"):
		await snframes()
	if _want("snuffer"):
		await snuffer()
	if _want("snextra"):
		await snextra()
	if _want("levels"):
		await levels()
	quit()


func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)


# ---------------------------------------------------------------- helpers

func _room(theme: String, rows: Array, header := "") -> Node:
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\narea: 8\ntheme: %s\n%s---\n%s" % [theme, header, "\n".join(rows)])
	lv.id = "show"
	var w = World.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	if w.hud:
		w.hud.visible = false
	if w.touch:
		w.touch.visible = false
	_w = w
	_overlay(w)
	return w


func _flat(w: int, ceil_row := -1) -> Array:
	## A flat floor at row 13; a roof down to ceil_row if given.
	var rows := []
	for y in 15:
		var r := "#".repeat(w) if y >= 13 or y <= ceil_row else ".".repeat(w)
		if y > ceil_row and y < 13:
			r = "#" + r.substr(1, w - 2) + "#"
		rows.append(r)
	_put(rows, 2, 12, "P")
	_put(rows, w - 3, 12, "E")
	return rows


func _put(rows: Array, x: int, y: int, ch: String) -> void:
	var r: String = rows[y]
	rows[y] = r.substr(0, x) + ch + r.substr(x + 1)


func _spawn(w, kind: String, cell: Vector2i, opts := {}) -> Node2D:
	var o := opts.duplicate()
	o["cell"] = cell
	var e = w.spawn_enemy(kind, EK.spawn_pos(kind, cell), o)
	e.active = true
	return e


func _run(w, n: int, pad := {}) -> void:
	for i in n:
		w.test_pad = pad
		await physics_frame


func _snap(name: String, focus := Vector2.INF, zoom := 1.0) -> void:
	## Saves the view; with a focus, a close-up there (the world is held
	## still meanwhile).
	var w = _w
	var was := false
	var cam0 := Vector2.ZERO
	if focus != Vector2.INF and w and is_instance_valid(w):
		was = w.paused
		cam0 = w.cam
		w.paused = true
		w.camera.zoom = Vector2(zoom, zoom)
		w.camera.position = focus.round()
		w.cam = focus.round()
	for i in 3:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	if focus != Vector2.INF and w and is_instance_valid(w):
		w.camera.zoom = Vector2.ONE
		w.cam = cam0
		w.camera.position = cam0
		w.paused = was


func _hold(w, x: float, row := 13) -> void:
	w.player.reset_at(Vector2(x, row * 32))
	w.player.invuln = 9999.0
	w.cam = w._clamp_cam(w.player.position + Vector2(0, -60))


func _lamps(w, xs: Array, row := 11, r := 110.0) -> void:
	for x in xs:
		w.add_light(Vector2(x * 32 + 16, row * 32), r, 0.8)


func _free(w) -> void:
	w.queue_free()
	_w = null
	await process_frame
	await process_frame


func _overlay(w) -> void:
	if not debug:
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.follow_viewport_enabled = true
	w.add_child(layer)
	_dbg = Node2D.new()
	layer.add_child(_dbg)
	_dbg.draw.connect(func():
		if not is_instance_valid(w):
			return
		for e in w.enemies:
			if not e.alive:
				continue
			var r: Rect2 = e.rect()
			if r.size.x > 2.0:
				_dbg.draw_rect(r, Color(0.2, 1.0, 0.3, 0.9), false, 1.0)
			var hr: Rect2 = e.hurt_rect()
			if hr.size.x > 2.0:
				_dbg.draw_rect(hr, Color(1.0, 0.25, 0.25, 0.9), false, 1.0)
			for p in e.eye_points():
				_dbg.draw_circle(p, 1.0, Color(0.2, 1.0, 1.0))
			_dbg.draw_line(e.position + Vector2(-3, 0), e.position + Vector2(3, 0), Color(1, 1, 0), 1.0)
			_dbg.draw_line(e.position + Vector2(0, -3), e.position + Vector2(0, 3), Color(1, 1, 0), 1.0)
		var pl = w.player
		if pl:
			_dbg.draw_rect(pl.rect(), Color(1, 1, 1, 0.6), false, 1.0)
	)
	var t := Timer.new()
	t.wait_time = 0.02
	t.autostart = true
	t.timeout.connect(func(): if is_instance_valid(_dbg): _dbg.queue_redraw())
	layer.add_child(t)


func _rowsnap(name: String, es: Array, zoom := 3.0, dy := -24.0) -> void:
	## The monsters in es, three to a close-up.
	var i := 0
	var part := 0
	while i < es.size():
		var grp := es.slice(i, i + 3)
		var x0: float = grp[0].position.x
		var x1: float = grp[grp.size() - 1].position.x
		var y: float = grp[0].get("floor_y") if grp[0].get("floor_y") != null else grp[0].position.y
		await _snap("%s_%d" % [name, part], Vector2((x0 + x1) * 0.5, y + dy), zoom)
		i += 3
		part += 1


func _pose(w, e, state: String, frame: String, timer := 99.0) -> void:
	e.set("state", state)
	e.set("timer", timer)
	e.show_frame(frame)


# ---------------------------------------------------------------- monsters

func bonebow() -> void:
	var w = await _room("waxfall", _flat(40, 6))
	_hold(w, 8 * 32)
	await _run(w, 10)
	var xs := [14, 17, 20, 23, 26]
	var es := []
	for x in xs:
		es.append(_spawn(w, "bonebow", Vector2i(x, 12), {"facing": -1}))
	_lamps(w, xs)
	await _run(w, 20)
	w.paused = true
	_pose(w, es[0], "idle", "bonebow_idle")
	_pose(w, es[1], "draw", "bonebow_draw", 0.4)
	es[1].aim = Vector2(-1, 0)
	_pose(w, es[2], "draw", "bonebow_draw", 0.1)
	es[2].aim = Vector2(-0.94, 0.34)
	es[2].locked = true
	_pose(w, es[3], "cool", "bonebow_loose")
	es[4].show_frame("bonebow_hit")
	await _snap("bonebow")
	await _rowsnap("bonebow_z", es)
	es[4]._kill({"how": "stomp", "from_x": 0.0})
	es[4].show_frame("bonebow_bones")
	await _snap("bonebow_bones", es[4].position + Vector2(0, -20), 4.0)
	# The other way round, and in the dark.
	for e in es:
		e.facing = 1
		e.step(0.0, w.player)
	w.paused = false
	await _free(w)
	w = await _room("waxfall", _flat(40, 6))
	_hold(w, 8 * 32)
	await _run(w, 10)
	var b = _spawn(w, "bonebow", Vector2i(14, 12))
	await _run(w, 40)
	await _snap("bonebow_live_dark")
	await _free(w)


func helm() -> void:
	var w = await _room("chandlery", _flat(40, 6))
	_hold(w, 8 * 32)
	await _run(w, 10)
	var xs := [13, 16, 19, 22, 25, 28]
	var es := []
	for x in xs:
		es.append(_spawn(w, "hollow_helm", Vector2i(x, 12), {"facing": -1}))
	_lamps(w, xs)
	await _run(w, 20)
	w.paused = true
	var poses := [["pace", "helm_walk1"], ["pace", "helm_walk2"], ["turn", "helm_block"], ["plant", "helm_bash"],
			["noshield", "helm_noshield"], ["pace", "helm_hit"]]
	for i in es.size():
		_pose(w, es[i], poses[i][0], poses[i][1], 0.2)
		es[i].velocity = Vector2.ZERO
		if es[i].sprite:
			es[i].sprite.position = Vector2.ZERO
	await _snap("helm")
	await _rowsnap("helm_z", es)
	await _free(w)


func wing() -> void:
	var w = await _room("garden", _flat(40, 4))
	_hold(w, 20 * 32)
	await _run(w, 10)
	var es := []
	for x in [14, 17, 26]:
		es.append(_spawn(w, "gutterwing", Vector2i(x, 9)))
	_lamps(w, [12, 16, 20, 26], 10)
	await _run(w, 10)
	w.paused = true
	es[0].show_frame("wing_fly1")
	es[1].show_frame("wing_fly2")
	es[2].set("state", "popped")
	es[2].show_frame("wing_pop")
	await _snap("wing")
	await _snap("wing_z", Vector2(15.5 * 32, 9 * 32), 4.0)
	await _snap("wing_pop_z", es[2].position, 4.0)
	w.paused = false
	# Latched, facing each way.
	for f in [1, -1]:
		w.player.facing = f
		var l = es[0]
		l.position = l.flame_point()
		l._base = l.position
		await _run(w, 100)
		await _snap("wing_latch_%d" % f)
		await _snap("wing_latch_z%d" % f, w.player.position + Vector2(0, -30), 4.0)
	await _free(w)


func drip() -> void:
	var rows := _flat(40, 7)
	var w = await _room("waxfall", rows)
	_hold(w, 4 * 32)
	await _run(w, 10)
	var xs := [12, 15, 18, 21, 24, 27]
	var es := []
	for x in xs:
		es.append(_spawn(w, "dripkin", Vector2i(x, 8)))
	_lamps(w, xs, 10, 130.0)
	await _run(w, 10)
	# hang, quiver, drop (mid-air), splat, crawl1, crawl2
	es[1].state = "quiver"
	es[1].timer = 99.0
	es[2]._let_go()
	es[3]._let_go()
	es[4]._let_go()
	es[5]._let_go()
	await _run(w, 40)
	es[3].state = "splat"
	es[3].timer = 99.0
	es[4].state = "crawl"
	es[5].state = "crawl"
	es[5]._walk = 0.3
	es[2].state = "drop"
	es[2].position.y = 10 * 32
	w.paused = true
	es[2].show_frame("drip_drop")
	es[3].show_frame("drip_splat")
	es[4].show_frame("drip_crawl1")
	es[5].show_frame("drip_crawl2")
	es[1].show_frame("drip_hang")
	await _snap("drip")
	await _snap("drip_z0", Vector2(15 * 32, 10 * 32), 3.0)
	await _snap("drip_z1", Vector2(24 * 32, 11 * 32), 3.0)
	w.paused = false
	await _free(w)


func jaw() -> void:
	var rows := _flat(40, 4)
	for y in [12, 13]:
		rows[y] = rows[y].substr(0, 10) + ":".repeat(20) + rows[y].substr(30)
	rows[14] = "#".repeat(40)
	_put(rows, 14, 13, "f")
	_put(rows, 20, 13, "f")
	_put(rows, 26, 13, "f")
	var w = await _room("chandlery", rows)
	# Stand him on a stone in the pool.
	rows = []
	_hold(w, 4 * 32)
	await _run(w, 10)
	var js := []
	for e in w.enemies:
		if e.kind == "brinejaw":
			js.append(e)
			e.active = true
	_lamps(w, [14, 20, 26], 10, 130.0)
	await _run(w, 10)
	js[1].state = "tell"
	js[1].timer = 99.0
	await _run(w, 6)
	w.paused = true
	# Mid-leap, rising and falling (posed: it doesn't wait for a hero).
	for i in [0, 2]:
		var j = js[i]
		j.state = "leap"
		j.position = Vector2(j.position.x, j.surface_y - 44.0)
		j.velocity = Vector2(0, -120.0 if i == 0 else 200.0)
		j.tint.a = 1.0
		j.show_frame("jaw_leap" if i == 0 else "jaw_fall")
		j.step(0.0, w.player)
		j.show_frame("jaw_leap" if i == 0 else "jaw_fall")
	await _snap("jaw")
	await _snap("jaw_z", Vector2(15 * 32, 11.5 * 32), 3.0)
	await _snap("jaw_z2", Vector2(25 * 32, 11.5 * 32), 3.0)
	w.paused = false
	await _free(w)


func lurk() -> void:
	var w = await _room("chandlery", _flat(40, 6))
	_hold(w, 4 * 32)
	await _run(w, 10)
	var es := []
	for x in [12, 15, 18, 21]:
		es.append(_spawn(w, "lidlurk", Vector2i(x, 12)))
	_lamps(w, [12, 15, 18, 21])
	await _run(w, 10)
	es[1].wake()
	es[2].wake()
	es[3].wake()
	await _run(w, 2)
	es[2].state = "hop"
	es[2].velocity = Vector2(0, -300)
	await _run(w, 8)
	w.paused = true
	es[1].show_frame("lurk_open")
	es[2].show_frame("lurk_hop")
	es[3].show_frame("lurk_hit")
	await _snap("lurk")
	await _rowsnap("lurk_z", es, 3.0, -30.0)
	w.paused = false
	await _free(w)


func old() -> void:
	## World 1's kinds next to the new ones, for scale and style.
	var w = await _room("nave", _flat(44, 6))
	_hold(w, 4 * 32)
	await _run(w, 10)
	var row := [["skeleton", 11], ["bonebow", 14], ["thornback", 17], ["hollow_helm", 20], ["lidlurk", 23]]
	for r in row:
		_spawn(w, r[0], Vector2i(r[1], 12))
	_spawn(w, "bat", Vector2i(26, 9))
	_spawn(w, "gutterwing", Vector2i(29, 9))
	_spawn(w, "dripkin", Vector2i(32, 7))
	_lamps(w, [11, 14, 17, 20, 23, 26, 29, 32])
	await _run(w, 20)
	await _snap("old_and_new", Vector2(22 * 32, 11 * 32), 1.6)
	await _snap("old_and_new_z0", Vector2(14 * 32, 11.8 * 32), 3.0)
	await _snap("old_and_new_z1", Vector2(22 * 32, 11.5 * 32), 3.0)
	await _snap("old_and_new_z2", Vector2(30 * 32, 10.5 * 32), 3.0)
	await _free(w)


func thorn() -> void:
	## The Thornback's tell (review round 2): lit and posed (walking, the
	## brace just begun, the brace about to break, reeling), then in the
	## dark as the player sees it, mid-brace and then charging.
	var w = await _room("nave", _flat(40, 6))
	_hold(w, 4 * 32)
	await _run(w, 10)
	var xs := [14, 17, 20, 23]
	var es := []
	for x in xs:
		# (The third an Anointed one: its eye glints on the brace frame.)
		es.append(_spawn(w, "thornback", Vector2i(x, 12), {"facing": -1, "tier": "anointed" if x == 20 else ""}))
	_lamps(w, xs)
	await _run(w, 20)
	w.paused = true
	var poses := [["thorn_walk1", 0.0], ["thorn_brace", 0.30], ["thorn_brace", 0.04], ["thorn_hit", 0.0]]
	for i in es.size():
		es[i].show_frame(poses[i][0])
		es[i].brace = poses[i][1]
		es[i].brace_len = 0.35
		es[i].velocity = Vector2.ZERO
		if es[i].sprite:
			es[i].sprite.position = Vector2.ZERO
	await _snap("thorn")
	await _rowsnap("thorn_z", es)
	await _free(w)
	# In the dark, no helper lights: Wick walks up, it braces, it charges.
	w = await _room("nave", _flat(40, 6))
	_hold(w, 10 * 32)
	w.player.facing = 1
	await _run(w, 10)
	var th = _spawn(w, "thornback", Vector2i(14, 12), {"facing": -1})
	for i in 120:
		await _run(w, 1)
		if th.brace > 0.0 and th.brace < 0.2:
			break
	await _snap("thorn_dark")
	await _snap("thorn_dark_brace_z", th.position + Vector2(-40, -24), 3.0)
	for i in 120:
		await _run(w, 1)
		if th.charging():
			break
	await _run(w, 6)
	await _snap("thorn_dark_charge_z", th.position + Vector2(-40, -24), 3.0)
	await _free(w)


func dark() -> void:
	## What the player sees: no helper lights.
	var rows := _flat(50, 7)
	var w = await _room("undercandle", rows)
	_hold(w, 25 * 32)
	await _run(w, 10)
	_spawn(w, "bonebow", Vector2i(32, 12))
	_spawn(w, "hollow_helm", Vector2i(18, 12), {"facing": 1})
	_spawn(w, "dripkin", Vector2i(29, 8))
	_spawn(w, "gutterwing", Vector2i(21, 9))
	_spawn(w, "lidlurk", Vector2i(35, 12))
	await _run(w, 30)
	await _snap("dark")
	await _free(w)


# ---------------------------------------------------------------- props

func props() -> void:
	## Every World 2 prop close up: posts lit and out, a spout swelling, a
	## waxfall on, off and gurgling, a nest idle and breeding, false stone
	## in a light. A low roof (row 8) so the hanging ones are in view.
	var rows := _flat(60, 8)
	_put(rows, 8, 12, "L")
	_put(rows, 11, 12, "L")
	_put(rows, 16, 9, "d")
	_put(rows, 19, 9, "d")
	_put(rows, 24, 9, "!")
	_put(rows, 28, 9, "!")
	_put(rows, 32, 9, "!")
	_put(rows, 38, 10, "N")
	_put(rows, 42, 10, "N")
	for y in [11, 12]:
		rows[y] = rows[y].substr(0, 47) + "FF" + rows[y].substr(49)
	var w = await _room("waxfall", rows)
	_hold(w, 4 * 32)
	await _run(w, 10)
	var f = w.features
	f.light(f.lanterns[1], true)
	# Spouts: one waiting, one swelling. Falls: on, off, gurgling.
	var cyc: float = f.FALL_ON + f.FALL_OFF
	f.spouts[0]["phase"] = fposmod(0.5 - f._t, f.SPOUT_EVERY)
	f.spouts[1]["phase"] = fposmod(2.2 - f._t, f.SPOUT_EVERY)
	f.falls[0]["phase"] = fposmod(0.8 - f._t, cyc)
	f.falls[1]["phase"] = fposmod(2.4 - f._t, cyc)
	f.falls[2]["phase"] = fposmod(3.05 - f._t, cyc)
	f.nests[1]["tell"] = 0.6
	w.add_light(Vector2(48 * 32, 11 * 32), 120.0, 0.8, -1.0, "lantern")
	_lamps(w, [8, 11, 16, 19, 24, 28, 32, 38, 42], 11, 90.0)
	await _run(w, 4)
	await _snap("props_posts", Vector2(9.5 * 32, 11.5 * 32), 3.0)
	await _snap("props_spouts", Vector2(17.5 * 32, 10.8 * 32), 3.0)
	await _snap("props_falls", Vector2(28 * 32, 11 * 32), 2.4)
	await _snap("props_nests", Vector2(40 * 32, 11 * 32), 3.0)
	await _snap("props_false", Vector2(48 * 32, 11.5 * 32), 3.0)
	await _free(w)
	# Braziers in the Snuffer's arena (floor ones lit, ledge ones dark).
	w = await _snuffer_world()
	var sn = w.boss
	_hold(w, sn.arena_left + 200.0)
	w.player.position.y = sn.floor_y
	await _run(w, 30)
	var br: Array = w.features.braziers()
	for b in br:
		await _snap("props_brazier_%d" % br.find(b), (b["pos"] as Vector2) + Vector2(0, -24), 3.0)
	await _free(w)


# ---------------------------------------------------------------- elites

func elites() -> void:
	## An Anointed of each eligible kind with one Omen each (Dusk gets one),
	## then Dreads with two, close up.
	var w = await _room("garden", _flat(60, 6))
	_hold(w, 4 * 32)
	await _run(w, 20)
	var es := []
	es.append(_spawn(w, "skeleton", Vector2i(14, 12), {"tier": "anointed", "omens": ["Warded"], "name": "Anointed Rattle"}))
	es.append(_spawn(w, "hollow_helm", Vector2i(18, 12), {"tier": "anointed", "omens": ["Burning"], "facing": -1}))
	es.append(_spawn(w, "bat", Vector2i(22, 11), {"tier": "anointed", "omens": ["Swift"]}))
	es.append(_spawn(w, "bonebow", Vector2i(26, 12), {"tier": "anointed", "omens": ["Twinned"]}))
	es.append(_spawn(w, "thornback", Vector2i(30, 12), {"tier": "anointed", "omens": ["Vengeful"]}))
	for e in w.enemies:
		e.active = true
	_lamps(w, [14, 18, 22, 26, 30])
	await _run(w, 90)
	await _snap("elites", Vector2(22 * 32, 11 * 32), 1.6)
	await _snap("elites_z0", Vector2(16 * 32, 11.8 * 32), 3.0)
	await _snap("elites_z1", Vector2(22 * 32, 11.4 * 32), 3.0)
	await _snap("elites_z2", Vector2(28 * 32, 11.8 * 32), 3.0)
	# A Vengeful one hit: its shards.
	w.deal(es[4], 1.0, {"how": "slash", "flat": 1.0, "from_x": es[4].position.x - 20.0})
	await _run(w, 12)
	await _snap("elites_vengeful", Vector2(30 * 32, 11.5 * 32), 3.0)
	await _free(w)
	# Dreads with two Omens: Old Drippings, Captain Quiver, the Wick-Eater.
	w = await _room("waxfall", _flat(50, 5))
	_hold(w, 4 * 32)
	await _run(w, 20)
	_spawn(w, "dripkin", Vector2i(16, 12), {"tier": "dread", "omens": ["Twinned", "Warded"], "name": "Old Drippings"})
	_spawn(w, "bonebow", Vector2i(26, 12), {"tier": "dread", "omens": ["Swift", "Twinned"], "name": "Captain Quiver"})
	_spawn(w, "gutterwing", Vector2i(21, 10), {"tier": "dread", "omens": ["Swift", "Burning"], "name": "The Wick-Eater"})
	for e in w.enemies:
		e.active = true
		if e.kind == "dripkin":
			e.as_copy()
	_lamps(w, [16, 21, 26])
	await _run(w, 40)
	await _snap("dreads", Vector2(21 * 32, 11 * 32), 2.2)
	await _free(w)


func copies() -> void:
	## Twinned halves next to whole ones (a half on the ground keeps its hit
	## box SHOT_LINE tall), then a Taperwitch's sparks on a splatted and a
	## crawling Dripkin right in front of her.
	var w = await _room("garden", _flat(60, 6))
	_hold(w, 4 * 32)
	await _run(w, 20)
	var x := 12
	# (Lidlurks are never elites, so they never split.)
	for k in ["skeleton", "bonebow", "thornback", "hollow_helm", "dripkin"]:
		var full := _spawn(w, k, Vector2i(x, 12), {"facing": -1})
		var half := _spawn(w, k, Vector2i(x + 2, 12), {"scale": 0.6, "facing": -1})
		half.set("copy", true)
		half.as_copy()
		if k == "dripkin":
			full.as_copy()
			full.position.y = 13 * 32
			half.position.y = 13 * 32
		for e in [full, half]:
			e.apply_status("root", 999.0)
		x += 6
	_lamps(w, [13, 19, 25, 31, 37])
	await _run(w, 40)
	for e in w.enemies:
		if e.kind == "dripkin":
			e.show_frame("drip_crawl1")
	await _snap("copies", Vector2(25.5 * 32, 11 * 32), 1.0)
	await _snap("copies_z0", Vector2(16 * 32, 12 * 32), 3.0)
	await _snap("copies_z1", Vector2(35 * 32, 12 * 32), 3.0)
	await _free(w)
	var game = root.get_node("Game")
	for st in ["splat", "crawl"]:
		game.reset()
		var h: Dictionary = game.new_hero("witch")
		h["level"] = 5
		w = await _room("waxfall", _flat(40, 6))
		_hold(w, 10 * 32)
		w.player.facing = 1
		await _run(w, 20)
		var d := _spawn(w, "dripkin", Vector2i(11, 12), {})
		d.as_copy()
		d.state = st
		d.timer = 99.0
		d.position = Vector2(w.player.position.x + 30.0, 13 * 32)
		d.max_hp = 9999.0
		d.hp = 9999.0
		_lamps(w, [10, 11], 11, 140.0)
		w.player.invuln = 0.0
		var hold := func():
			d.state = st
			d.timer = 99.0
			d.position = Vector2(w.player.position.x + 30.0, 13 * 32)
			d.velocity = Vector2.ZERO
			d.show_frame("drip_splat" if st == "splat" else "drip_crawl1")
		hold.call()
		await _run(w, 10)
		# (Up close the spark is born on it: it lands at once.)
		for i in 24:
			hold.call()
			await _run(w, 1, {"attack": i < 2})
			if d.hp < 9999.0:
				break
		await _snap("copies_spark_%s" % st, Vector2(w.player.position.x + 16.0, 12 * 32), 3.0)
		print("spark on a %s Dripkin 30 px ahead: %s" % [st, "hit" if d.hp < 9999.0 else "MISS"])
		await _free(w)
	game.reset()

# ---------------------------------------------------------------- the Snuffer

func _load(id: String):
	## A level with its story beats marked seen (so none pauses the shot).
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	var game = root.get_node("Game")
	for k in lv.story:
		game.mark_seen(str(lv.story[k]))
	return lv


func _snuffer_world() -> Node:
	var lv = _load("2-4")
	var w = World.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	if w.hud:
		w.hud.visible = false
	if w.touch:
		w.touch.visible = false
	_w = w
	_overlay(w)
	return w


func snuffer() -> void:
	var w = await _snuffer_world()
	var sn = w.boss
	sn.active = true
	var mid: float = (sn.arena_left + sn.arena_right) * 0.5
	_hold(w, sn.arena_left + 60.0)
	w.player.position.y = sn.floor_y
	await _run(w, 60)
	await _snap("sn_wake", Vector2(mid, sn.floor_y - 150.0), 1.0)
	w.player.invuln = 9999.0
	# Idle, hollow, away from light.
	_hold(w, mid - 140.0)
	w.player.position.y = sn.floor_y
	sn.position.x = mid
	sn.state = "drift"
	sn.timer = 99.0
	sn.solid_t = 0.0
	await _run(w, 30)
	await _snap("sn_hollow", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	# Track, raise, slam, stuck.
	sn.state = "track"
	sn.timer = 0.2
	await _run(w, 30)
	await _snap("sn_raise", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	var n := 0
	while sn.state == "raise" and n < 200:
		await _run(w, 1)
		n += 1
	await _run(w, 2)
	await _snap("sn_slam", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	await _run(w, 20)
	await _snap("sn_stuck", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	# Snuff the Light: turn, glide, cap.
	w.player.attack_time = -1.0
	sn.state = "drift"
	sn._move_n = 1
	sn._next(w.player)
	await _run(w, 40)
	await _snap("sn_snuff_tell", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	n = 0
	while sn.state in ["snuff_tell", "glide"] and n < 400:
		await _run(w, 1)
		n += 1
	await _run(w, 20)
	await _snap("sn_cap", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	await _run(w, 60)
	# Phase 2: tide, choir, call.
	sn.hp = sn.max_hp * 0.5
	sn.phase = 2
	sn.state = "drift"
	sn._move_n = -1
	sn._next(w.player)
	await _run(w, 70)
	await _snap("sn_sink", Vector2(mid, sn.floor_y - 150.0), 1.0)
	await _run(w, 40)
	await _snap("sn_tide", Vector2(mid, sn.floor_y - 150.0), 1.0)
	n = 0
	while sn.state in ["sink", "under", "rise"] and n < 600:
		await _run(w, 1)
		n += 1
	await _snap("sn_rise", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	sn.state = "drift"
	sn._move_n = 1
	sn._next(w.player)
	await _run(w, 40)
	await _snap("sn_choir", Vector2(mid, sn.floor_y - 150.0), 1.0)
	await _run(w, 70)
	await _snap("sn_choir_fall", Vector2(mid, sn.floor_y - 150.0), 1.0)
	sn._call_pending = true
	sn.state = "drift"
	sn._next(w.player)
	await _run(w, 50)
	await _snap("sn_call", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	await _run(w, 90)
	await _snap("sn_wings", Vector2(mid, sn.floor_y - 150.0), 1.0)
	# Phase 3: Lights Out, lunge.
	sn.state = "stuck"
	sn.timer = 99.0
	sn.hp = sn.max_hp * 0.26
	w.deal(sn, 1.0, {"how": "slash", "flat": 99999.0})
	await _run(w, 40)
	await _snap("sn_lightsout", Vector2(mid, sn.floor_y - 150.0), 1.0)
	await _run(w, 150)
	sn.position.x = mid + 100.0
	_hold(w, mid - 60.0)
	w.player.position.y = sn.floor_y
	sn.state = "drift"
	sn.timer = 99.0
	await _run(w, 20)
	await _snap("sn_phase3", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	sn._move_n = 0
	sn._next(w.player)
	await _run(w, 20)
	await _snap("sn_lunge_draw", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	await _run(w, 25)
	await _snap("sn_lunge", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	# Death.
	sn.state = "stuck"
	sn.timer = 99.0
	sn.solid_t = 1.0
	w.deal(sn, 1.0, {"how": "slash", "flat": 99999.0})
	await _run(w, 40)
	await _snap("sn_die", Vector2(sn.position.x, sn.floor_y - 60.0), 2.0)
	for i in 10:
		await _run(w, 20)
		print("t ", i, " dt ", sn.death_time, " hs ", w.hitstop, " state ", w.state, " paused ", w.paused, " pl ", w.player.alive)
	print("after: valid ", is_instance_valid(sn), " gone ", sn.gone if is_instance_valid(sn) else true, " dt ", sn.death_time if is_instance_valid(sn) else -1.0)
	await _snap("sn_after", Vector2(mid, sn.floor_y - 150.0), 1.0)
	await _free(w)


func snextra() -> void:
	## A ledge brazier capped, the tide sweeping at the hero, the lunge's
	## draw-back glint, the Choir from a ledge.
	var w = await _snuffer_world()
	var sn = w.boss
	var pl = w.player
	sn.active = true
	_hold(w, sn.arena_left + 60.0)
	pl.position.y = sn.floor_y
	await _run(w, 60)
	pl.invuln = 9999.0
	var ledge: Dictionary = {}
	for b in w.features.braziers():
		if not b["start_lit"] and ledge.is_empty():
			ledge = b
	w.features.light(ledge)
	for b in w.features.braziers():
		if b != ledge:
			w.features.snuff_brazier(b)
	pl.reset_at(ledge["pos"] + Vector2(-40, 0))
	sn.state = "drift"
	sn._move_n = 1
	sn._next(pl)
	var n := 0
	while sn.state != "cap" and n < 1200:
		await _run(w, 1)
		n += 1
	await _run(w, 20)
	await _snap("snx_ledge_cap", (ledge["pos"] as Vector2) + Vector2(0, -50), 2.0)
	await _run(w, 200)
	# The tide, with Wick in its way.
	var mid: float = (sn.arena_left + sn.arena_right) * 0.5
	sn.position.x = sn.arena_left + 60.0
	_hold(w, mid)
	pl.position.y = sn.floor_y
	sn.phase = 2
	sn.state = "drift"
	sn._move_n = -1
	sn._next(pl)
	n = 0
	while (sn._tide.is_empty() or (sn._tide["rect"] as Rect2).end.x < mid - 160.0) and n < 1200:
		await _run(w, 1)
		n += 1
	await _snap("snx_tide", Vector2(mid - 80.0, sn.floor_y - 60.0), 2.0)
	await _run(w, 500)
	# The lunge's draw-back.
	sn.phase = 3
	sn.hp = sn.max_hp * 0.2
	w.features.lights_out()
	sn.position.x = mid + 120.0
	_hold(w, mid - 80.0)
	pl.position.y = sn.floor_y
	sn.state = "drift"
	sn._move_n = 0
	sn._next(pl)
	await _run(w, 40)
	await _snap("snx_lunge_draw", Vector2(mid + 40.0, sn.floor_y - 60.0), 2.0)
	await _free(w)


func snframes() -> void:
	## The Snuffer held in each of his frames (and the state that shows it),
	## both facings, for the art's anchor, eyes, bell and body box.
	var w = await _snuffer_world()
	var sn = w.boss
	sn.active = true
	var mid: float = (sn.arena_left + sn.arena_right) * 0.5
	_hold(w, sn.arena_left + 60.0)
	w.player.position.y = sn.floor_y
	await _run(w, 60)
	w.player.invuln = 9999.0
	_hold(w, mid - 150.0)
	w.player.position.y = sn.floor_y
	await _run(w, 10)
	var poses := [["drift", "snuffer_idle"], ["raise", "snuffer_raise"], ["stuck", "snuffer_stuck"],
			["glide", "snuffer_glide"], ["cap", "snuffer_snuff"], ["lunge", "snuffer_lunge"],
			["recoil", "snuffer_curdled"], ["slam", "snuffer_slam"]]
	for f in [-1, 1]:
		for ps in poses:
			sn.position = Vector2(mid, sn.floor_y - (6.0 if ps[0] != "stuck" else 0.0))
			sn.facing = f
			sn.state = ps[0]
			sn.timer = 0.3
			sn._slam_x = mid + f * sn.REACH
			sn._lunge_dir = f
			var br: Array = w.features.lit_braziers()
			sn._target = br[0] if br.size() > 0 else {}
			sn.solid_t = 1.0
			await _run(w, 1)
			w.paused = true
			sn.state = ps[0]
			sn.position = Vector2(mid, sn.floor_y - (6.0 if ps[0] != "stuck" else 0.0))
			sn.facing = f
			sn.show_frame(ps[1])
			sn.step(0.0, w.player)
			sn.state = ps[0]
			sn.show_frame(ps[1])
			await _snap("snf_%s_%d" % [ps[1].substr(8), f], Vector2(mid, sn.floor_y - 60.0), 2.5)
			w.paused = false
	await _free(w)


# ---------------------------------------------------------------- levels

func levels() -> void:
	var cols := {
		"1-1": [10, 75, 160, 248], "1-2": [11, 60, 110, 190], "1-3": [20, 58, 120, 170],
		"1-4": [10, 30, 60, 90],
		"2-1": [4, 40, 110, 200, 260], "2-2": [10, 57, 100, 160, 230], "2-3": [20, 90, 160, 230, 290],
		"2-4": [5, 18, 40, 60, 80, 94],
	}
	for id in cols:
		for x in cols[id]:
			await _level_shot(id, x)


func _level_shot(id: String, x: int) -> void:
	var lv = _load(id)
	if x >= lv.width:
		return
	var w = World.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	_w = w
	_overlay(w)
	w.test_pad = {}
	for y in range(lv.height - 1, 0, -1):
		if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
			w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
			break
	w.player.invuln = 9999.0
	w.cam = w._clamp_cam(w.player.position)
	await _run(w, 60, {"right": true})
	# Past the title card (about 3 s at 120 physics ticks a second).
	await _run(w, 330)
	await _snap("lv_%s_%03d" % [id, x])
	await _free(w)
