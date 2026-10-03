extends SceneTree
## What the thumb buttons cover while playing, on the phone's safe area (a
## 1266x585 window is the 844x390 view): where the camera holds Waxby's feet
## against the Special's and the flask's tops, a monster standing on his
## floor right under the Special (running right) and under the flask
## (running left), the real Bonebows of 1-3 and 2-3 drawing on him, what
## hangs overhead (drip spouts, Dripkins, Flits with their wind-up, a
## Gutterwing nest) and how far the camera leans up for it, a full jump's
## and a double jump's top, every level's start and a jump there (his flame
## against the HUD's corner blocks), a jump under a boss bar, and the title
## and level-up cards over his flame. Prints the numbers and saves shots.
##   godot --path game --resolution 1266x585 --script res://../tools/shot_floor.gd -- <out_dir> [tag] [button_scale]
## A clearance is how far a thing's lowest pixel sits above the top of the
## button under it (negative: that many px behind it).

var UI
var Story
var TouchScript
var game: Node
var _out := "/tmp"
var _tag := "now"
var _scale := 1.0
var _lines: Array = []
const HERO_TALL := 76.0      # feet to the flame's tip (test_screens)
const RIM := 5.25            # the Special's resource arc reaches this far past its disc


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	_tag = args[1] if args.size() > 1 else "now"
	_scale = float(args[2]) if args.size() > 2 else 1.0
	DirAccess.make_dir_recursive_absolute(_out)
	UI = load("res://scripts/ui.gd")
	Story = load("res://scripts/story.gd")
	TouchScript = load("res://scripts/touch_controls.gd")
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://shot_floor_save.json"
	game.settings_path = "user://shot_floor_settings.json"
	game.reset()
	game.set_setting("button_scale", _scale)
	UI.safe_override = UI.phone_safe(root.get_visible_rect().size)
	_say("view %s safe %s button_scale %.2f" % [root.get_visible_rect().size, UI.safe_override, _scale])
	var L: Dictionary = TouchScript.layout_for(UI.safe_override, _scale)
	_say("Special: disc top %.1f, its arc's top %.1f (x %.0f-%.0f); flask: disc top %.1f; attack top %.1f; jump top %.1f" % [
			L["special"].y - L["r_special"], L["special"].y - L["r_special"] - RIM, L["special"].x - L["r_special"], L["special"].x + L["r_special"],
			L["flask"].y - L["r_flask"], L["attack"].y - L["r_attack"], L["jump"].y - L["r_jump"]])
	await _floor()
	await _bonebows()
	await _overhead()
	await _jumps()
	await _starts()
	await _boss_bar()
	await _cards()
	var f := FileAccess.open("%s/%s_floor.txt" % [_out, _tag], FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	quit()


func _say(s: String) -> void:
	print(s)
	_lines.append(s)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var path := "%s/%s_%s.png" % [_out, _tag, name]
	root.get_texture().get_image().save_png(path)


func _clear() -> void:
	for c in root.get_children():
		if c.name != "Game" and c.name != "Sfx":
			c.queue_free()
	for i in 2:
		await process_frame


func _world(level_id: String, x := -1, cls := "knight", lvl := 6) -> Node:
	game.reset()
	game.set_setting("button_scale", _scale)
	for id in Story.scenes().keys():
		game.mark_seen(id)
	for k in Story.BARKS.keys():
		game.mark_seen("bark:" + k)
	game.new_hero(cls)
	game.add_xp(load("res://scripts/progression.gd").total_to(lvl) - int(game.hero()["xp"]))
	var LevelData = load("res://scripts/level_data.gd")
	var World = load("res://scripts/world.gd")
	var lv = LevelData.load_file("res://levels/%s.txt" % level_id)
	var w = World.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	if x >= 0:
		_stand(w, x)
	for i in 40:
		await physics_frame
	w.hud._title = {}
	return w


func _stand(w: Node, x: int, lowest := true) -> void:
	## On the lowest floor (or the highest) in column x, or the nearest
	## column that has one.
	var lv = w.level
	var ys: Array = range(lv.height - 1, 0, -1) if lowest else range(1, lv.height)
	for dx in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6]:
		var cx: int = x + dx
		var put := false
		for y in ys:
			if lv.tile(cx, y) == 0 and (lv.is_solid(lv.tile(cx, y + 1)) or lv.is_ledge(lv.tile(cx, y + 1))):
				w.player.reset_at(Vector2(cx * 32 + 16, (y + 1) * 32))
				put = true
				break
		if put:
			break
	w.cam = w._clamp_cam(w.player.position)


func _view(w: Node, p: Vector2) -> Vector2:
	return w.get_viewport().get_canvas_transform() * p


func _world_at(w: Node, v: Vector2) -> Vector2:
	return w.get_viewport().get_canvas_transform().affine_inverse() * v


func _buttons(w: Node) -> Array:
	## [name, centre, radius as drawn]: the Special with its arc, the flask
	## with its badge, the rest by their rings.
	var L: Dictionary = w.touch.layout()
	var out := []
	out.append(["special", L["special"], float(L["r_special"]) + RIM])
	out.append(["flask", L["flask"], float(L["r_flask"]) + 1.0])
	out.append(["flask badge", TouchScript.flask_badge(L["flask"], float(L["r_flask"])), TouchScript.FLASK_BADGE_R + 1.5])
	for b in ["left", "right"]:
		out.append([b, L[b], float(L["r_move"]) + 1.0])
	for b in ["attack", "jump"]:
		out.append([b, L[b], float(L["r_" + b]) + 1.0])
	out.append(["pause", L["pause"], float(L["r_pause"]) + 1.0])
	return out


static func _clearance(r: Rect2, c: Vector2, rad: float) -> float:
	## How far the rect's bottom sits above the circle's top edge where they
	## share x (INF if no column of the rect is over the circle).
	var x0 := maxf(r.position.x, c.x - rad)
	var x1 := minf(r.end.x, c.x + rad)
	if x0 > x1:
		return INF
	# The circle's highest point over [x0, x1]: at the x nearest its centre.
	var nx := clampf(c.x, x0, x1)
	var top := c.y - sqrt(maxf(rad * rad - (nx - c.x) * (nx - c.x), 0.0))
	return top - r.end.y


func _covered(w: Node, r: Rect2) -> String:
	## The buttons and HUD blocks in front of view rect r, with how many px
	## each hides.
	var out := []
	for b in _buttons(w):
		var cl := _clearance(r, b[1], b[2])
		if cl < 0.0 and r.position.y < (b[1] as Vector2).y + float(b[2]):
			out.append("%s %.1f px" % [b[0], -cl])
	var H: Dictionary = w.hud.layout()
	for k in ["badge", "life", "res", "embers", "sigils"]:
		if (H[k] as Rect2).intersects(r):
			out.append("HUD " + k)
	return "nothing" if out.is_empty() else ", ".join(out)


func _body(w: Node, e: Node2D) -> Rect2:
	## A monster as drawn, in view px: its box, and 3 px under its feet
	## (the art's frame runs a little past them).
	var r: Rect2 = e.rect()
	var a := _view(w, r.position)
	var b := _view(w, r.end + Vector2(0, 3))
	return Rect2(a, b - a)


func _hero_rect(w: Node) -> Rect2:
	var feet := _view(w, w.player.global_position)
	return Rect2(feet + Vector2(-12, -HERO_TALL), Vector2(24, HERO_TALL + 3))


func _feet_line(w: Node, what: String) -> float:
	var feet := _view(w, w.player.global_position)
	var L: Dictionary = w.touch.layout()
	var sp := float(L["special"].y - L["r_special"]) - RIM
	_say("%s: feet at view (%.0f, %.1f); %.1f px over the Special's arc (%.1f), %.1f over the flask's disc (%.1f); flame tip at %.1f" % [
			what, feet.x, feet.y, sp - feet.y, sp, float(L["flask"].y - L["r_flask"]) - feet.y, float(L["flask"].y - L["r_flask"]), feet.y - HERO_TALL])
	return feet.y


func _run(w: Node, dir: int, frames: int) -> void:
	w.test_pad = {"right": dir > 0, "left": dir < 0}
	for i in frames:
		await physics_frame


func _floor() -> void:
	## Stand, run, then a Bonebow put on his floor under the Special (and,
	## running left, under the flask), swept across the button's width.
	for spot in [["1-1", 20], ["1-3", 90], ["2-1", 40], ["2-2", 60], ["2-3", 120]]:
		await _clear()
		var w = await _world(spot[0], spot[1])
		_feet_line(w, "%s standing" % spot[0])
		await _shot("stand_%s" % spot[0])
		for dir in [1, -1]:
			await _run(w, dir, 110)
			_feet_line(w, "%s running %s" % [spot[0], "right" if dir > 0 else "left"])
			var L: Dictionary = w.touch.layout()
			var key := "special" if dir > 0 else "flask"
			var c: Vector2 = L[key]
			var rr: float = float(L["r_" + key])
			var worst := INF
			var worst_x := 0.0
			var e = w.spawn_enemy("bonebow", w.player.position, {"facing": -dir})
			e.set_physics_process(false)
			for k in 9:
				var vx: float = c.x - rr + rr * 2.0 * k / 8.0
				var at := _world_at(w, Vector2(vx, 0))
				e.position = Vector2(at.x, w.player.position.y)
				var rb := _body(w, e)
				for b in _buttons(w):
					var cl := _clearance(rb, b[1], b[2])
					if cl < worst:
						worst = cl
						worst_x = vx
			var at2 := _world_at(w, Vector2(c.x, 0))
			e.position = Vector2(at2.x, w.player.position.y)
			_say("   a Bonebow on his floor across the %s (view x %.0f-%.0f, %.0f-%.0f px ahead): least clearance %.1f px (at view x %.0f); at its centre: %s" % [
					key, c.x - rr, c.x + rr, absf(c.x - rr - _view(w, w.player.global_position).x), absf(c.x + rr - _view(w, w.player.global_position).x),
					worst, worst_x, _covered(w, _body(w, e))])
			w.test_pad = {"right": dir > 0, "left": dir < 0}
			w.set_physics_process(false)
			for i in 6:
				await process_frame
			await _shot("run_%s_%s" % [spot[0], "right" if dir > 0 else "left"])
			w.set_physics_process(true)
			e.queue_free()
			w.enemies.erase(e)
			w.test_pad = {}


func _bonebows() -> void:
	## The real Bonebows, walked up to until they draw.
	for spot in [["1-3", Vector2i(77, 12), -1, 86], ["1-3", Vector2i(77, 12), 1, 71], ["2-3", Vector2i(171, 8), 1, 157],
			["2-3", Vector2i(253, 7), 1, 239], ["2-3", Vector2i(188, 5), -1, 202]]:
		await _clear()
		var id: String = spot[0]
		var cell: Vector2i = spot[1]
		var dir: int = spot[2]
		var w = await _world(id)
		_stand(w, spot[3], spot[3] != 71)
		var bow: Node2D = null
		for e in w.enemies:
			if e.kind == "bonebow" and Vector2i(floori(e.position.x / 32.0), floori((e.position.y - 4.0) / 32.0)) == cell:
				bow = e
		if bow == null:
			_say("%s: no Bonebow at %s" % [id, cell])
			continue
		var drew := false
		for i in 480:
			w.test_pad = {"right": dir > 0, "left": dir < 0}
			await physics_frame
			if str(bow.get("state")) == "draw":
				drew = true
				break
			if absf(w.player.position.x - bow.position.x) < 150.0:
				break
		w.test_pad = {}
		var feet := _feet_line(w, "%s Bonebow at %s %s" % [id, cell, "draws" if drew else "never drew"])
		for i in 12:
			await physics_frame
		var rb := _body(w, bow)
		_say("   it stands at view (%.0f, %.0f)-(%.0f, %.0f), %.0f px from him, %.0f px over his feet; covered by: %s" % [
				rb.position.x, rb.position.y, rb.end.x, rb.end.y, absf(bow.position.x - w.player.position.x),
				w.player.position.y - bow.position.y, _covered(w, rb)])
		w.set_physics_process(false)
		for i in 4:
			await process_frame
		await _shot("bonebow_%s_%d_%d_from_%d" % [id, cell.x, cell.y, spot[3]])


func _overhead() -> void:
	## Under the highest drip spouts, Dripkins, Flits and nests (192-236 px
	## over the floor, with a Flit's bob and wind-up): does the camera lean
	## up to show them, and what does that cost below? Under a Flit he then
	## jumps: its wind-up, if it starts one, must be in plain view.
	for spot in [["2-1", 12, "spout", Vector2i(7, 6)], ["2-2", 57, "dripkin", Vector2i(60, 6)], ["2-4", 18, "spout", Vector2i(21, 6)],
			["2-4", 24, "dripkin", Vector2i(27, 6)], ["1-2", 13, "dripkin", Vector2i(15, 7)], ["1-2", 127, "bat", Vector2i(127, 6)],
			["1-2", 12, "bat", Vector2i(11, 7)], ["1-4", 12, "bat", Vector2i(14, 7)], ["2-3", 34, "nest", Vector2i(34, 6)]]:
		await _clear()
		var w = await _world(spot[0], spot[1], "knight", 3 if spot[0].begins_with("1") else 11)
		for i in 120:
			await physics_frame
		var feet := _feet_line(w, "%s under the %s at %s" % [spot[0], spot[2], spot[3]])
		var top_y := INF
		var bat: Node2D = null
		if spot[2] == "spout":
			for sp in w.features.spouts:
				if sp["cell"] == spot[3]:
					top_y = _view(w, sp["tip"]).y
		elif spot[2] == "nest":
			for n in w.features.nests:
				if n["cell"] == spot[3]:
					top_y = _view(w, w.features.nest_rect(n).position).y
		else:
			for e in w.enemies:
				if e.kind == spot[2] and absf(e.position.x - (spot[3].x * 32 + 16)) < 40.0:
					if e.kind == "bat":
						bat = e
						top_y = _view(w, e.reach_rect().position).y
					else:
						top_y = _body(w, e).position.y
		_say("   its top%s at view y %.1f (%s); look_up %.1f" % [" (roost + bob + wind-up)" if bat else "", top_y, "in view" if top_y >= 0.0 else "OFF the top", w.look_up()])
		w.set_physics_process(false)
		for i in 4:
			await process_frame
		await _shot("overhead_%s_%s_%d" % [spot[0], spot[2], spot[3].x])
		w.set_physics_process(true)
		if bat != null:
			var winds := 0
			var hidden := 0
			var hi := INF
			var shot := false
			for i in 170:
				w.test_pad = {"jump": i < 60}
				await physics_frame
				if bat.alive and str(bat._state) == "windup":
					winds += 1
					hi = minf(hi, _view(w, bat.rect().position).y)
					if not w.in_plain_view(bat.rect()):
						hidden += 1
					if not shot:
						shot = true
						w.set_physics_process(false)
						await _shot("windup_%s_%d" % [spot[0], spot[1]])
						w.set_physics_process(true)
			w.test_pad = {}
			_say("   a jump under it: %s" % (("it winds up for %d ticks, its top at least at view y %.1f, %d ticks not in plain view" % [winds, hi, hidden]) if winds > 0 else "no wind-up (not in plain view, or out of reach)"))


func _jumps() -> void:
	## A full jump, then a double jump, from standing on 1-1 and 2-1's floor.
	for spot in [["1-1", 20], ["2-1", 40]]:
		for double in [false, true]:
			await _clear()
			var w = await _world(spot[0], spot[1])
			if double:
				w.player.double_jump = true
			var feet0: float = _view(w, w.player.global_position).y
			var top := INF
			var flame := INF
			var cam_moved := 0.0
			var cam0: float = w.cam.y
			for i in 170:
				var hold: bool = (i < 60) if not double else (i < 40 or (i >= 44 and i < 100))
				w.test_pad = {"jump": hold}
				await physics_frame
				top = minf(top, _view(w, w.player.global_position).y)
				flame = minf(flame, _view(w, w.rig.flame_point()).y)
				cam_moved = minf(cam_moved, w.cam.y - cam0)
			w.test_pad = {}
			_say("%s %s: feet from %.1f up to %.1f; flame tip (feet - %d) %.1f; flame_point %.1f; the camera rose %.1f px" % [
					spot[0], "double jump" if double else "full jump", feet0, top, HERO_TALL, top - HERO_TALL, flame, -cam_moved])


func _starts() -> void:
	## Every level's first frames: is he behind a button? Then a full jump
	## there, where he's under the HUD's corner blocks: his flame against
	## them at the top, and how far the camera goes up with him.
	for id in ["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4"]:
		await _clear()
		var w = await _world(id)
		var hr := _hero_rect(w)
		_say("%s start: hero at view (%.0f, %.0f)-(%.0f, %.0f): covered by %s" % [id, hr.position.x, hr.position.y, hr.end.x, hr.end.y, _covered(w, hr)])
		if id in ["1-3", "2-3"]:
			w.set_physics_process(false)
			await _shot("start_%s" % id)
			w.set_physics_process(true)
		var cam0: float = w.cam.y
		var rise := 0.0
		var top := INF
		var worst := "nothing"
		var at_top := Rect2()
		var shot := false
		for i in 170:
			w.test_pad = {"jump": i < 60}
			await physics_frame
			rise = maxf(rise, cam0 - w.cam.y)
			var r := _hero_rect(w)
			if r.position.y < top:
				top = r.position.y
				at_top = r
			var c := _covered(w, r)
			if c != "nothing":
				worst = c
			if not shot and w.player.velocity.y > 0.0 and not w.player.on_floor:
				shot = true
				if id in ["1-1", "2-1"]:
					w.set_physics_process(false)
					await _shot("start_jump_%s" % id)
					w.set_physics_process(true)
		w.test_pad = {}
		var H: Dictionary = w.hud.layout()
		var clear := INF
		for k in ["badge", "life", "res", "embers", "sigils"]:
			var q: Rect2 = H[k]
			if q.position.x < at_top.end.x and q.end.x > at_top.position.x:
				clear = minf(clear, at_top.position.y - q.end.y)
		_say("   a full jump there: flame tip up to view y %.1f (%s px under the corner block over him); the camera rose %.1f px; behind: %s" % [
				top, ("%.1f" % clear) if clear < INF else "no block", rise, worst])


func _boss_bar() -> void:
	## A jump under the boss bar in Tollgrave's arena: it goes see-through.
	await _clear()
	game.mark_seen("boss_card_tollgrave")
	var w = await _world("1-4")
	if w.boss == null:
		return
	w.player.reset_at(w.boss.position + Vector2(-260, 0))
	w.player.invuln = 99.0
	w.cam = w._clamp_cam(w.player.position)
	var woke := false
	for i in 900:
		await physics_frame
		if w.hud.boss_alpha() >= 0.99:
			woke = true
			break
	if not woke:
		_say("1-4 arena: Tollgrave didn't wake (the bar never showed)")
		return
	var low := 1.0
	var shot := false
	for i in 170:
		w.test_pad = {"jump": i < 60}
		await physics_frame
		low = minf(low, w.hud.boss_alpha())
		if not shot and w.hud.boss_alpha() < 0.35:
			shot = true
			w.set_physics_process(false)
			await _shot("boss_bar_jump")
			w.set_physics_process(true)
	w.test_pad = {}
	_say("1-4 arena: a jump's top under the boss bar: it drops to %.2f of itself (see-through), whole again on the floor" % low)


func _cards() -> void:
	## The title card and the level-up card over his flame, standing.
	await _clear()
	var w = await _world("1-1", 20)
	w.set_physics_process(false)
	var feet: float = _view(w, w.player.global_position).y
	var T: Rect2 = w.hud.title_rect("The Drowned Chandlery")
	var lr: Rect2 = w.hud.level_rect()
	_say("cards: title ends %.1f, level-up ends %.1f; the flame tip %.1f (%.1f and %.1f px clear)" % [
			T.end.y, lr.end.y, feet - HERO_TALL, feet - HERO_TALL - T.end.y, feet - HERO_TALL - lr.end.y])
	w.hud.level_up(7)
	w.hud._lvl["t"] = 0.9
	await _shot("card_levelup")
	w.hud._lvl = {}
	w.hud.title_card("The Tallow Deep", "The Drowned Chandlery")
	for i in 40:
		await process_frame
	w.hud._title["t"] = 1.2
	await _shot("card_title")
