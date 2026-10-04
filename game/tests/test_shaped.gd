extends SceneTree
## Build 2's shapes, the engine's side (the shape plan's E5, E6 and E10's
## runtime): levels up to 36 rows tall, climbs, bowls, loops and a level
## played right to left, on the shape labs (tools/levels/lab_shaped.py; the
## shape tools' lab-shapes and lab-mirror, tools/levels/lab_shapes.py, too)
## and small levels drawn here.
## The camera (scripts/tall_cam.gd), on only in a level taller than a strip:
## - every strip has none (its camera as before): a fall there still trails
##   (its feet low on the glass), down held never looks down;
## - a fall in a tall level looks ahead: on a 24-row fall his feet stay over
##   the thumb buttons all the way, held at 90-150 on the glass once it's
##   in, and 5 rows or more show under him; he lands and it eases back to the
##   feet line; a jump back onto his own floor never looks ahead; so too off
##   the tower's lookout ledge, 30 rows down its shaft;
## - a slide down a vine looks ahead too;
## - a lift carries the camera: riding one a whole sweep his floor stays
##   over the Special (the strip camera lags it, under it on the way down);
## - down held standing on stone looks down (about two more rows), and comes
##   back when let go;
## - the shapes' HUD rule (goal_hits): with the camera where it settles on
##   him at each goal (stopped at the level's top edge at a tower's top), no
##   goal is behind the HUD's top band: every tall lab keeps it, a sigil in a
##   tower's top right corner breaks it;
## - World 4's icicle lean only for an icicle within 5 rows of his feet.
## The bots (scripts/route_field.gd, reach.gd, reach_search.gd, autoplay_bot.gd):
## - the route field measures the way there: the loop's bell, straight over
##   the start, is further from it than from the loop's far end; its heading
##   points the way (right in the loop, left in the mirror); the tower's top
##   storey is nearer the bell than its start; every level on the path has
##   a way by it from its start to its goal;
## - a tall level's sims run on through a fall the level's whole height,
##   climb a storey's vine in one go, and a level with `drops` drops through
##   one-way ledges (a strip's sims are as they were);
## - every shape lab's goals are reached by the reachability bot (test_core
##   proves them too: LAB_LEVELS) and the --autoplay bot rings each lab's
##   bell by route (the shape tools' too: lab-shapes' stacked storeys and
##   its duel met by its right door, lab-mirror's clockwork right to left);
##   by x it never gets round the loop; it goes by route only
##   in a shaped level (every strip and mode room keeps v2's way); with no
##   plan, or done, its pad heads the way there (v2's held right, as a
##   strip's still does);
## Rooms and arenas from either side (boss_arena.gd, features/sealed.gd):
## - an arena entered from the right finds its door in its right wall and
##   its boss wakes once he's past it, the door sealed; every arena before
##   the shapes keeps its left door;
## - the mirror's duel, entered from the right, seals both doors and opens
##   when won; the decks' ambush, two decks tall, seals its lower door and
##   its upper one, drops foes on both decks, and the bot clears it;
##   lab-shapes' duel, on the upper storey of a 24-row level, met by its
##   right door as its route comes, seals both and opens when won.
## The three together (the tools' labs, the tall camera, 16 x 16 tile
## chunks: the rendering's E4):
## - down the tower's shaft the camera looks ahead and never shows past what
##   the chunks draw (the level and the bedrock), meeting all 3 rows of them;
## - a crumble on lab-shapes giving way, and its duel's doors sealing,
##   redraw their own chunks only, never the row of chunks under them.
##
##     godot --headless --path game --script res://tests/test_shaped.gd

const TILE := 32
const DT := 1.0 / 120.0

var LevelData: GDScript
var WorldScript: GDScript
var HudScript: GDScript
var TouchScript: GDScript
var UI: GDScript
var Reach: GDScript
var ReachSearch: GDScript
var RouteField: GDScript
var AutoBot: GDScript
var Arena: GDScript
var TallCam: GDScript
var game: Node
var _passed := 0
var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	# Scripts that use the autoloads are loaded now, not preloaded.
	LevelData = load("res://scripts/level_data.gd")
	WorldScript = load("res://scripts/world.gd")
	HudScript = load("res://scripts/hud.gd")
	TouchScript = load("res://scripts/touch_controls.gd")
	UI = load("res://scripts/ui.gd")
	Reach = load("res://scripts/reach.gd")
	ReachSearch = load("res://scripts/reach_search.gd")
	RouteField = load("res://scripts/route_field.gd")
	AutoBot = load("res://scripts/autoplay_bot.gd")
	Arena = load("res://scripts/boss_arena.gd")
	TallCam = load("res://scripts/tall_cam.gd")
	game = root.get_node("Game")
	game.save_path = "user://test_shaped_save.json"
	game.settings_path = "user://test_shaped_settings.json"
	await process_frame
	game.reset()
	var vs := Vector2(844, 390)
	root.size = Vector2i(vs)
	root.content_scale_size = Vector2i(vs)
	UI.safe_override = UI.phone_safe(vs)
	await process_frame
	_test_strip_heights()
	await _test_strip_camera()
	await _test_fall()
	await _test_slide()
	await _test_lift()
	await _test_look_down()
	await _test_goal_band()
	await _test_icicle_cap()
	_test_field()
	_test_sims()
	_test_reach_labs()
	await _test_autoplay()
	await _test_route_pad()
	await _test_arena_sides()
	await _test_room_from_right()
	await _test_room_two_decks()
	await _test_room_tall_lab()
	await _test_tall_chunks()
	for p in [game.save_path, game.settings_path]:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p + suffix))
	print("test_shaped: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

const LABS := ["lab-shape-tower", "lab-shape-climb", "lab-shape-bowl", "lab-shape-loop", "lab-shape-mirror", "lab-shape-decks"]
# The shape tools' labs (tools/levels/lab_shapes.py, test_shapes.gd's): lab-shapes
# 24 rows, placed and stacked storeys, its upper storey's duel met by its right
# door; lab-mirror a clockwork strip mirrored whole (facing: left).
const TOOL_LABS := ["lab-shapes", "lab-mirror"]


func _lab(id: String) -> RefCounted:
	return LevelData.load_file("res://levels/%s.txt" % id)


func _drawn(id: String, rows: Array, headers := {}) -> RefCounted:
	## A level drawn here: its rows (the legend's glyphs) and headers.
	var text := "title: %s\nsubtitle: %s\narea: 3\ntheme: nave\n" % [id, id]
	for k in headers:
		text += "%s: %s\n" % [k, headers[k]]
	text += "---\n" + "\n".join(rows) + "\n"
	var lv = LevelData.new()
	lv.id = id
	lv.parse(text)
	return lv


func _column(h: int, shelf_row: int, w := 30) -> Array:
	## A shaft h rows tall and w wide: a shelf at the top left (its floor on
	## shelf_row, the start on it), the floor at the bottom (two rows), walls.
	var rows := []
	for y in h:
		var r := ""
		for x in w:
			var c := "."
			if x < 2 or x >= w - 2 or y >= h - 2:
				c = "#"
			elif y == shelf_row and x < 8:
				c = "#"
			elif y == shelf_row - 1 and x == 3:
				c = "P"
			elif y == h - 3 and x == w - 5:
				c = "E"
			r += c
		rows.append(r)
	return rows


func _world(lv: RefCounted, with_ui := true) -> Node:
	## A headless World on lv, with the HUD and the touch controls (what
	## the camera's lines are drawn against), the hero at level 8.
	game.reset()
	var h: Dictionary = game.new_hero("knight")
	h["level"] = 8
	var w = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	if with_ui:
		var hud = HudScript.new()
		hud.world = w
		w.hud = hud
		w.add_child(hud)
		var touch = TouchScript.new()
		w.touch = touch
		touch.hud = hud
		w.add_child(touch)
		await process_frame
		touch.apply_settings()
	w.test_pad = {}
	return w


func _stand(w: Node, x: int, row: int) -> void:
	## The hero standing on the floor under (x, row), the camera settled.
	w.player.reset_at(Vector2(x * TILE + 16, (row + 1) * TILE))
	w.player.velocity = Vector2.ZERO
	_ticks(w, 2.0)


func _ticks(w: Node, seconds: float, pad := {}) -> void:
	for i in int(round(seconds / DT)):
		w.player.invuln = 5.0
		w.player.hp = w.player.max_hp
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _feet(w: Node) -> float:
	## His feet's y on the glass.
	return w.player.position.y - w.cam.y + w._view_size().y * 0.5


func _special_top(w: Node) -> float:
	var L: Dictionary = w.touch.layout()
	return float(L["special"].y) - float(L["r_special"])


func _done(w: Node) -> void:
	w.queue_free()
	await process_frame


# ---------------------------------------------------------------- the camera

func _test_strip_heights() -> void:
	## Every level file but the shape labs (both streams') is a strip (not
	## tall), so no camera or bot rule of the shapes touches it.
	var tall := []
	for f in DirAccess.get_files_at("res://levels"):
		if f.ends_with(".txt"):
			var lv = LevelData.load_file("res://levels/" + f)
			if lv.tall():
				tall.append(lv.id)
	tall.sort()
	var want := (LABS + TOOL_LABS).filter(func(id): return _lab(id).height > LevelData.STRIP_ROWS)
	want.sort()
	_check(tall == want, "the tall level files are the shape labs' (%s)" % ", ".join(tall))
	_check(_lab("lab-shape-tower").height == 36 and _lab("lab-shape-mirror").height == 15, "the tower is 36 rows (3-2's), the mirror a strip")


func _test_strip_camera() -> void:
	## A strip's World has no tall camera: an 11-row fall trails as it always
	## has (his feet low on the glass, under the feet line), and down held
	## standing never looks down.
	var w = await _world(_drawn("lab-strip-fall", _column(15, 3)))
	_check(w.tall_cam == null, "a strip has no tall camera")
	_stand(w, 4, 2)
	var line: float = w._feet_y
	var low := 0.0
	var off := false
	for i in 300:
		off = off or not w.player.on_floor
		_ticks(w, DT, {"right": not off})
		low = maxf(low, _feet(w))
	_check(low > line + 40.0, "a strip's 11-row fall trails as before: his feet sink to %.0f (the line %.0f)" % [low, line])
	_ticks(w, 1.5)
	var settled := _feet(w)
	_ticks(w, 1.5, {"down": true})
	_check(absf(_feet(w) - settled) < 1.0, "down held in a strip never looks down (%.1f, %.1f)" % [_feet(w), settled])
	await _done(w)
	var w2 = await _world(LevelData.load_file("res://levels/1-1.txt"), false)
	_check(w2.tall_cam == null, "1-1 has no tall camera")
	await _done(w2)


func _test_fall() -> void:
	## A 24-row fall in a 30-row shaft: once it looks ahead his feet stay
	## over the thumb buttons, are eased to 90-150 on the glass, and 5 rows
	## or more show under him; he lands and it eases back.
	var w = await _world(_drawn("lab-tall-fall", _column(30, 4)))
	_check(w.tall_cam != null, "a 30-row level has the tall camera")
	_stand(w, 4, 3)
	var line: float = w._feet_y
	var top := _special_top(w)
	var vh: float = w._view_size().y
	var worst := 0.0
	var fewest := 99.0
	var eased := []
	var looked := 0
	var full := 0.0
	var landed := false
	var t := 0.0
	var off := false
	while t < 5.0 and not landed:
		off = off or not w.player.on_floor
		_ticks(w, DT, {"right": not off})
		t += DT
		var pl: Node2D = w.player
		if str(w.tall_cam.looking) == "fall":
			looked += 1
			worst = maxf(worst, _feet(w))
			fewest = minf(fewest, (vh - _feet(w)) / TILE)
			full = full + DT if w.tall_cam.fall_k >= 1.0 else 0.0
			# (till the camera stops at the level's bottom edge, 6 rows over the floor)
			if full >= 0.3 and pl.velocity.y >= 600.0 and pl.position.y < 22 * TILE:
				eased.append(_feet(w))
		landed = pl.on_floor and pl.position.y > 20 * TILE
	_check(landed and looked > 60, "the fall lands at the bottom (%s) and looks ahead on the way (%d ticks)" % [landed, looked])
	_check(worst <= top, "his feet stay over the Special's top all the fall (lowest %.0f, the top %.0f)" % [worst, top])
	_check(fewest >= 5.0, "5 rows or more show under him (fewest %.1f)" % fewest)
	var lo: float = eased.min() if not eased.is_empty() else -1.0
	var hi: float = eased.max() if not eased.is_empty() else -1.0
	_check(eased.size() > 30 and lo >= 90.0 and hi <= 150.0, "once it's in, at full speed it holds his feet at 90-150 on the glass (%.0f-%.0f)" % [lo, hi])
	_ticks(w, 1.5)
	_check(absf(_feet(w) - line) < 3.0, "landed, it eases back to the feet line (%.1f, the line %.1f)" % [_feet(w), line])
	# A full jump back onto his own floor never looks ahead.
	var any := false
	for i in 120:
		_ticks(w, DT, {"jump": i < 60})
		any = any or str(w.tall_cam.looking) == "fall"
	_check(not any, "a jump back onto his own floor never looks ahead")
	await _done(w)
	# The tower: off the lookout ledge, 30 rows down the shaft.
	var tw = await _world(_lab("lab-shape-tower"))
	_stand(tw, 25, 3)
	var low := 0.0
	var few := 99.0
	var gone := false
	var down := false
	for i in 400:
		gone = gone or not tw.player.on_floor
		_ticks(tw, DT, {"right": not gone})
		if str(tw.tall_cam.looking) == "fall":
			low = maxf(low, _feet(tw))
			few = minf(few, (vh - _feet(tw)) / TILE)
		if gone and tw.player.on_floor:
			down = tw.player.position.y > 30 * TILE
			break
	_check(down and low > 0.0 and low <= top and few >= 5.0, "the tower: off the lookout to the ground, his feet over the Special (lowest %.0f) and %.1f rows or more under him" % [low, few])
	await _done(tw)


func _test_slide() -> void:
	## The tower's vine: he slides down it, the camera looks ahead.
	var w = await _world(_lab("lab-shape-tower"))
	w.player.reset_at(Vector2(26 * TILE + 16, 14 * TILE))
	w.player.grab_vine(26, 1.0)
	_ticks(w, 0.5)
	var hang := _feet(w)
	var looked := false
	var feet := 999.0
	for i in 60:
		_ticks(w, DT, {"down": true})
		if str(w.tall_cam.looking) == "slide":
			looked = true
		feet = _feet(w)
	_check(looked and feet < hang - 20.0, "sliding down the vine the camera looks ahead (his feet %.0f, %.0f hanging)" % [feet, hang])
	await _done(w)


func _lift_run(lv: RefCounted, tall: bool) -> Dictionary:
	## Rides the tower's lift a whole sweep (up and down again) from its
	## lowest: his feet's lowest on the glass, and how high it took him.
	var w = await _world(lv)
	if not tall:
		w.tall_cam = null
	var lift = null
	for m in w.movers:
		if str(m.kind) == "y":
			lift = m
	var out := {"ok": false, "lowest": 0.0, "rose": 0.0}
	if lift == null:
		await _done(w)
		return out
	# Wait for it at its lowest, then step onto it.
	var guard := 0
	while guard < 2000 and not (float(lift.delta.y) < 0.0 and float(lift.pos.y) > float(lift.start.y) + 80.0):
		_ticks(w, DT)
		guard += 1
	w.player.reset_at(Vector2(float(lift.pos.x) + float(lift.w()) * 0.5, float(lift.pos.y)))
	w.player.velocity = Vector2.ZERO
	_ticks(w, 0.1)
	w.cam = w.cam_on(w.player.position)
	var y0: float = w.player.position.y
	var lowest := 0.0
	var rose := 0.0
	for i in int(float(lift.period) / DT):
		_ticks(w, DT)
		rose = maxf(rose, y0 - w.player.position.y)
		if w.player.riding != null:
			lowest = maxf(lowest, _feet(w))
	out["ok"] = w.player.riding != null
	out["lowest"] = lowest
	out["rose"] = rose
	out["top"] = _special_top(w)
	await _done(w)
	return out


func _test_lift() -> void:
	## Riding the tower's lift up and down: the camera rides with it, his
	## floor over the Special all the way; the strip camera's easing lags it
	## (on the way down his floor sinks under the Special's top).
	var lv = _lab("lab-shape-tower")
	var on: Dictionary = await _lift_run(lv, true)
	var off: Dictionary = await _lift_run(_lab("lab-shape-tower"), false)
	_check(on["ok"] and float(on["rose"]) > 80.0, "he rides the lift up (%.0f px)" % float(on["rose"]))
	_check(float(on["lowest"]) <= float(on.get("top", 0.0)) + 0.5, "riding it his floor stays over the Special (lowest %.1f, its top %.1f)" % [on["lowest"], on.get("top", 0.0)])
	_check(float(off["lowest"]) > float(on["lowest"]) + 4.0, "the strip camera lags it (lowest %.1f against %.1f)" % [off["lowest"], on["lowest"]])


func _test_look_down() -> void:
	## Down held on the tower's catch floor (stone): the camera looks down,
	## about two rows; let go, it comes back.
	var w = await _world(_lab("lab-shape-tower"))
	_stand(w, 16, 21)
	var line := _feet(w)
	_ticks(w, 0.2, {"down": true})
	_check(str(w.tall_cam.looking) != "down", "a tap of down doesn't look down")
	_ticks(w, 1.5, {"down": true})
	var down := _feet(w)
	_check(str(w.tall_cam.looking) == "down" and down < line - 50.0 and absf(down - TallCam.DOWN_FEET) < 6.0,
			"held, it looks down: his feet up to %.0f (the line %.0f)" % [down, line])
	_ticks(w, 1.5)
	_check(absf(_feet(w) - line) < 3.0, "let go, it comes back (%.1f)" % _feet(w))
	await _done(w)


func _test_goal_band() -> void:
	## The shapes' HUD rule (tall_cam.gd goal_hits): with the camera where it
	## settles on him at each goal (stopped at the level's top edge at a
	## tower's top), no goal is behind the HUD's top band. Every tall shape
	## lab keeps it (lab-shapes too); a sigil drawn in a tower's top right
	## corner breaks it.
	for id in LABS + TOOL_LABS:
		var lv = _lab(id)
		if not lv.tall():
			continue
		var w = await _world(lv)
		_ticks(w, 0.5)
		_check(w.tall_cam.goal_hits().is_empty(), "%s: every goal shows clear of the HUD's top band (%s)" % [id, w.tall_cam.goal_hits()])
		await _done(w)
	var rows := []
	for y in 24:
		var r := ""
		for x in 40:
			var c := "."
			if y >= 22 or y == 0 or (y == 3 and x >= 30):
				c = "#"
			elif y == 21 and x == 4:
				c = "P"
			elif y == 1 and x == 38:
				c = "1"
			elif y == 21 and x == 30:
				c = "E"
			r += c
		rows.append(r)
	var bad = await _world(_drawn("lab-band", rows))
	_ticks(bad, 0.5)
	var hits: Array = bad.tall_cam.goal_hits()
	_check(hits.size() == 1 and str(hits[0]).begins_with("38,1"), "a sigil in a tower's top right corner is behind the band (%s; the band %s)" % [hits, bad.tall_cam.band()])
	await _done(bad)


func _test_icicle_cap() -> void:
	## World 4's icicle lean (look_up): in a tall level only for an icicle
	## within ICICLE_ROWS of his feet; a strip leans for one 7 rows up.
	for h in [24, 15]:
		var rows := []
		for y in h:
			var r := ""
			for x in 30:
				var c := "."
				if y >= h - 2 or y == 0:
					c = "#"
				elif y == h - 3 and x == 4:
					c = "P"
				elif y == h - 3 and x == 27:
					c = "E"
				elif y == h - 10 and x == 12:
					c = "V"
				elif y == h - 11 and x == 12:
					c = "#"
				r += c
			rows.append(r)
		var lv = _drawn("4-9", rows, {"theme": "clockface"})
		var w = await _world(lv)
		_stand(w, 19, h - 3)   # (7 tiles off: under it, it drops)
		var lean: float = w.look_up()
		if h > 15:
			_check(w.world_n == 4 and lean == 0.0, "a tall W4 level doesn't lean for an icicle 7 rows up (%.1f)" % lean)
		else:
			_check(w.world_n == 4 and lean > 0.0, "a strip leans for it, as before (%.1f)" % lean)
		await _done(w)


# ---------------------------------------------------------------- the bots

func _goal(lv: RefCounted, what := "bell") -> Dictionary:
	for g in Reach.goals_of(lv):
		if g["what"] == what:
			return g
	return {}


func _test_field() -> void:
	## The route field measures the way there, not the crow's.
	var loop = _lab("lab-shape-loop")
	var f = RouteField.new().build(Reach.static_copy(loop), _goal(loop))
	var start: Vector2 = LevelData.cell_floor(loop.start)
	var far_end := Vector2(66 * TILE + 16, 22 * TILE)
	_check(f.at(start) < RouteField.FAR and f.at(start) > f.at(far_end),
			"the loop: the bell over the start is further from it (%d moves) than from the far end (%d)" % [f.at(start), f.at(far_end)])
	_check(f.heading(start).x > 0, "and the way from the start heads right (%s)" % f.heading(start))
	var mir = _lab("lab-shape-mirror")
	var fm = RouteField.new().build(Reach.static_copy(mir), _goal(mir))
	_check(fm.heading(LevelData.cell_floor(mir.start)).x < 0, "the mirror: the way heads left (%s)" % fm.heading(LevelData.cell_floor(mir.start)))
	var tw = _lab("lab-shape-tower")
	var ft = RouteField.new().build(Reach.static_copy(tw), _goal(tw))
	var at_start: int = ft.at(LevelData.cell_floor(tw.start))
	var on_c: int = ft.at(Vector2(20 * TILE + 16, 12 * TILE))
	_check(at_start < RouteField.FAR and on_c < at_start, "the tower: nearer the bell on its third storey (%d) than at the start (%d)" % [on_c, at_start])
	# Every strip on the path: a way from its start to its bell or arena.
	var none := []
	for info in game.LEVELS:
		var lv = LevelData.load_file(str(info["path"]))
		var g := _goal(lv)
		if g.is_empty():
			g = _goal(lv, "boss arena")
		if g.is_empty():
			continue
		var fl = RouteField.new().build(Reach.static_copy(lv), g)
		if fl.at(LevelData.cell_floor(lv.start)) >= RouteField.FAR:
			none.append(lv.id)
	_check(none.is_empty(), "every level on the path has a way by the field from its start to its goal (none: %s)" % ", ".join(none))


func _sim(lv: RefCounted, from: Vector2, a: Dictionary) -> Dictionary:
	var s = ReachSearch.new()
	s.setup(lv, from, {"goals": []})
	var r: Dictionary = s.simulate(s.nodes[0], a)
	s.free_player()
	return r


func _test_sims() -> void:
	## A tall level's sims: a fall the level's whole height is a landing (a
	## strip's time would end it mid-air); a storey's vine climbed in one go;
	## a level with `drops` drops through a one-way ledge.
	var lv = _drawn("lab-sim-fall", _column(40, 3))
	var from: Vector2 = LevelData.cell_floor(lv.start)
	var walk := {"walk": 0.3, "dir": 1, "jump": true, "hold": 0.6}
	var r := _sim(lv, from, walk)
	_check(r["ok"] and (r["pos"] as Vector2).y >= 37 * TILE, "a 35-row fall (a jump off the shelf) lands at the bottom (%s, %s)" % [r["ok"], r["pos"]])
	_check(Reach.fall_extra(lv) > 1.5 and Reach.fall_extra(_lab("lab-shape-mirror")) == 0.0, "a strip's sims run no longer (%.2f s)" % Reach.fall_extra(_lab("lab-shape-mirror")))
	var acts: Array = Reach.vine_actions(true)
	_check(acts.size() == Reach.vine_actions().size() + 2 and acts.any(func(a): return float(a["t"]) == Reach.TALL_CLIMB), "a tall level's vine actions add the long climb either way")
	# drops: a one-way ledge over a pit with the bell under it.
	var rows := []
	for y in 20:
		var r2 := ""
		for x in 30:
			var c := "."
			if x < 2 or x >= 28 or y >= 18:
				c = "#"
			elif y == 9 and x < 12:
				c = "#"
			elif y == 9 and x >= 12 and x < 16:
				c = "="
			elif y == 9 and x >= 16:
				c = "#"
			elif y == 8 and x == 4:
				c = "P"
			elif y == 17 and x == 14:
				c = "E"
			r2 += c
		rows.append(r2)
	for drops in [false, true]:
		var dl = _drawn("lab-sim-drop", rows, {"drops": "1"} if drops else {})
		var s = ReachSearch.new()
		s.setup(Reach.static_copy(dl), LevelData.cell_floor(dl.start), {})
		s.run()
		s.free_player()
		_check(s.found.has("bell") == drops, "the bell under a one-way ledge: %s %s" % ["reached with drops" if drops else "out of reach without", s.found.keys()])


func _test_reach_labs() -> void:
	## The reachability bot reaches every goal of every shape lab, under the cap.
	for id in LABS + TOOL_LABS:
		var lv = _lab(id)
		var s = ReachSearch.new()
		s.setup(Reach.static_copy(lv), LevelData.cell_floor(lv.start), {"timed": Reach.timed_cells(lv)})
		s.run()
		s.free_player()
		var miss := []
		for g in s.goals:
			if not s.found.has(g["what"]):
				miss.append(g["what"])
		_check(not s.capped and miss.is_empty() and not s.goals.is_empty(), "%s: the bot reaches every goal (%d states; missed %s)" % [id, s.seen.size(), miss])


func _play(lv: RefCounted, secs: float, route = null) -> Dictionary:
	## The --autoplay bot on lv (never snuffed) till the bell or secs.
	var w = await _world(lv, false)
	w.autoplay = true
	var bot = AutoBot.new()
	bot.setup(w)
	if route != null:
		bot.use_route(bool(route))
	var t := 0.0
	var n := 0
	var rooms := {}
	var m = w.features.module("sealed") if w.features != null and w.features.has_method("module") else null
	while t < secs and w.state == "play":
		w.player.invuln = 5.0
		w.player.hp = w.player.max_hp
		w.test_pad = bot.pad(DT)
		w._read_pad()
		w.tick(DT)
		t += DT
		n += 1
		if m != null:
			for i in m.rooms.size():
				if m.rooms[i]["phase"] == "fight":
					rooms[i] = true
		if n % 2400 == 0:
			await process_frame
	var out := {"clear": w.state == "clear", "t": t, "by_route": bot.by_route, "shut": rooms.keys(),
			"won": m.rooms.map(func(r): return str(r["won"])) if m != null else []}
	await _done(w)
	return out


func _test_autoplay() -> void:
	## The --autoplay bot rings every shape lab's bell, going by route (the
	## tools' labs' too, through their duels from the right); by x it never
	## gets round the loop.
	for id in LABS + TOOL_LABS:
		var r: Dictionary = await _play(_lab(id), 120.0)
		_check(r["clear"] and r["by_route"], "%s: the bot rings the bell by route (%.1f s)" % [id, r["t"]])
		if id == "lab-shape-decks":
			_check(r["shut"] == [0] and r["won"] == ["clear"], "the decks: it walks into the ambush two decks tall and clears it (%s, %s)" % [r["shut"], r["won"]])
		if id == "lab-shape-mirror" or id in TOOL_LABS:
			_check(r["shut"] == [0] and r["won"] == ["clear"], "%s: it walks into the duel from the right and wins it (%s, %s)" % [id, r["shut"], r["won"]])
	var x: Dictionary = await _play(_lab("lab-shape-loop"), 40.0, false)
	_check(not x["clear"], "by x (v2's horizon) it never gets round the loop in 40 s (%s)" % x["clear"])


func _test_route_pad() -> void:
	## By route only in a shaped level: every strip on the path, its goal to
	## the right, keeps v2's way. With no plan the fallback pad heads the way
	## there: right round the loop (its bell is overhead), left in the mirror,
	## right up the tower's ledges; a strip's holds right as v2's did; done,
	## it heads for the goal the same way.
	var by := []
	for info in game.LEVELS:
		var lv = LevelData.load_file(str(info["path"]))
		var g := _goal(lv)
		if g.is_empty():
			g = _goal(lv, "boss arena")
		if not g.is_empty() and AutoBot.shaped(lv, g):
			by.append(lv.id)
	_check(by.is_empty(), "no level on the path goes by route (%s)" % ", ".join(by))
	for id in LABS + TOOL_LABS:
		_check(AutoBot.shaped(_lab(id), _goal(_lab(id))), "%s goes by route" % id)
	for spot in [["lab-shape-loop", 1], ["lab-shape-mirror", -1], ["lab-shape-tower", 1], ["lab-mirror", -1], ["lab-shapes", 1], ["1-1", 1]]:
		var w = await _world(LevelData.load_file("res://levels/%s.txt" % spot[0]), false)
		_ticks(w, 0.5)
		var bot = AutoBot.new()
		bot.setup(w)
		var pd: Dictionary = bot._v2_pad(w.player)
		var dir: int = (1 if pd.get("right", false) else 0) - (1 if pd.get("left", false) else 0)
		bot.state = "done"
		var dn: Dictionary = bot.pad(DT)
		var ddir: int = (1 if dn.get("right", false) else 0) - (1 if dn.get("left", false) else 0)
		_check(dir == int(spot[1]) and ddir == int(spot[1]), "%s: with no plan, and done, the pad heads %s (%d, %d; by route %s)" % [
				spot[0], "right" if spot[1] > 0 else "left", dir, ddir, bot.by_route])
		await _done(w)


# ---------------------------------------------------------------- rooms and arenas

func _arena_rows(from_right: bool) -> Array:
	## A boss arena (columns 10-29, walls at 8-9 and 30-31) with its doorway
	## on the side he comes from, the start on that side.
	var rows := []
	for y in 15:
		var r := ""
		for x in 44:
			var c := "."
			var wall: bool = (x >= 8 and x <= 9) or (x >= 30 and x <= 31)
			if y >= 13:
				c = "#"
			elif wall and (y < 10 or (from_right != (x >= 30))):
				c = "#"
			elif y == 12 and x == 20:
				c = "X"
			elif y == 12 and x == (40 if from_right else 3):
				c = "P"
			elif y == 12 and x == (36 if from_right else 5):
				c = "K"
			r += c
		rows.append(r)
	return rows


func _test_arena_sides() -> void:
	## Arena.find: the door on the side he comes in by.
	for right in [false, true]:
		var lv = _drawn("lab-arena-" + ("r" if right else "l"), _arena_rows(right), {"boss": "tollgrave"})
		var feet: Vector2 = LevelData.cell_floor(Vector2i(20, 12))
		var a: Dictionary = Arena.find(lv, feet)
		var xs := {}
		for c in a["door"]:
			xs[(c as Vector2i).x] = true
		var want := [30, 31] if right else [8, 9]
		var ks := xs.keys()
		ks.sort()
		_check(int(a["side"]) == (1 if right else -1) and ks == want, "an arena entered from the %s: its door in that wall (side %d, columns %s)" % ["right" if right else "left", a["side"], ks])
		_check(Arena.past_door(a["side"], a["left"], a["right"], (24.0 if right else 16.0) * TILE, 48.0)
				and not Arena.past_door(a["side"], a["left"], a["right"], (29.5 if right else 10.5) * TILE, 48.0), "past_door: in past it, not at it")
	# The World: walked into from the right, the boss wakes and the right door seals.
	var w = await _world(_drawn("lab-arena-r", _arena_rows(true), {"boss": "tollgrave"}), false)
	_ticks(w, 0.5)
	var b = w.boss
	var awake := false
	for i in 480:
		_ticks(w, DT, {"left": true})
		if b != null and str(b.state) != "sleep":
			awake = true
			break
	var shut := true
	for c in (b.door if b != null else []):
		shut = shut and LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(b != null and int(b.door_side) == 1 and awake, "walked into from the right, the boss wakes (%s)" % (str(b.state) if b != null else "no boss"))
	_check(b != null and not (b.door as Array).is_empty() and shut, "and the door in its right wall is sealed")
	await _done(w)
	# Every arena before the shapes keeps its door in its left wall.
	var moved := []
	for dir in ["res://levels", "res://levels/rush"]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".txt"):
				continue
			var lv = LevelData.load_file(dir + "/" + f)
			for e in lv.entities:
				if str(e["kind"]) == "boss":
					var a: Dictionary = Arena.find(lv, LevelData.cell_floor(e["cell"]))
					var left_ok: bool = (a["door"] as Array).all(func(c): return float((c as Vector2i).x * TILE) < float(a["left"]))
					if int(a["side"]) != -1 or (a["door"] as Array).is_empty() or not left_ok:
						moved.append(lv.id)
	_check(moved.is_empty(), "every boss arena before the shapes keeps its door in its left wall (moved: %s)" % ", ".join(moved))


func _test_room_from_right() -> void:
	## The mirror's duel, walked into from the right: both doors seal, the
	## foe wakes; it falls and the doors open.
	var w = await _world(_lab("lab-shape-mirror"), false)
	var m = w.features.module("sealed")
	_ticks(w, 0.5)
	var r: Dictionary = m.rooms[0]
	w.player.reset_at(Vector2(68 * TILE, 13 * TILE))
	var phase := ""
	for i in 360:
		_ticks(w, DT, {"left": w.player.position.x > 60 * TILE})
		if str(r["phase"]) == "fight":
			phase = "fight"
			break
	var doors := {}
	for c in r["sealed"]:
		doors[(c as Vector2i).x] = true
	var ks := doors.keys()
	ks.sort()
	_check(phase == "fight" and ks == [40, 65], "walked into from the right, the duel shuts at both ends (%s, %s)" % [r["phase"], ks])
	for e in m.counted(r):
		e.hp = 0.0
		e._kill({"how": "slash", "from_x": e.position.x + 20.0})
	_ticks(w, 0.5)
	_check(str(r["phase"]) == "won" and (r["sealed"] as Array).is_empty(), "its foe falls and the doors open (%s)" % r["phase"])
	await _done(w)


func _test_room_two_decks() -> void:
	## The decks' ambush, two decks tall: in at its lower door, it shuts
	## there and at its upper door; foes drop in on both decks.
	var w = await _world(_lab("lab-shape-decks"), false)
	var m = w.features.module("sealed")
	_ticks(w, 0.5)
	var r: Dictionary = m.rooms[0]
	w.player.reset_at(Vector2(16 * TILE, 22 * TILE))
	for i in 240:
		_ticks(w, DT, {"right": i < 30})
		if str(r["phase"]) == "fight":
			break
	var rows := {}
	for c in r["sealed"]:
		rows[(c as Vector2i)] = true
	var low: bool = rows.has(Vector2i(14, 20)) and rows.has(Vector2i(14, 21))
	var high: bool = rows.has(Vector2i(45, 9)) and rows.has(Vector2i(45, 10))
	_check(str(r["phase"]) == "fight" and low and high, "in at its lower door, it shuts there and at its upper door (%s, %d cells)" % [r["phase"], rows.size()])
	_ticks(w, 4.0)
	var decks := {}
	for e in m.counted(r):
		decks[int(e.position.y / TILE) < 15] = true
	_check(decks.has(true) and decks.has(false), "foes on both decks (%s)" % [decks.keys()])
	await _done(w)


# ---------------------------------------------------------------- the three together

func _drawn_chunks(w: Node) -> Dictionary:
	## Counts each tile chunk's draws (chunk index -> draws) from now on.
	var n := {}
	for k in w.chunks.size():
		n[k] = 0
		w.chunks[k].draw.connect(func(): n[k] += 1)
	return n


func _frames(n: int) -> void:
	## n frames, for the chunks' queued draws to run.
	for i in n:
		await process_frame


func _view_rect(w: Node) -> Rect2:
	var v: Vector2 = w._view_size()
	return Rect2(w.cam - v * 0.5, v)


func _chunk_rect(tv: Node) -> Rect2:
	return Rect2(tv.col0 * TILE, tv.row0 * TILE, 16 * TILE, 16 * TILE)


func _test_tall_chunks() -> void:
	## The tall camera over 16 x 16 tile chunks (world.gd's grid, the
	## rendering's E4): down the tower's shaft, 30 rows, the camera looking
	## ahead, the view never leaves what the chunks draw (the level and the
	## bedrock under it) and meets every row of them on the way; on
	## lab-shapes (24 rows, two chunk rows) a crumble shaking and falling
	## under him redraws its own chunks only, never the row under it.
	var tw = await _world(_lab("lab-shape-tower"))
	var cols: int = ceili(tw.level.width / 16.0)
	_check(tw.chunk_rows == 3 and tw.chunks.size() == cols * 3, "the tower: 3 rows of chunks (%d chunks)" % tw.chunks.size())
	_stand(tw, 25, 3)
	var all_rect := Rect2(0, 0, tw.level.width * TILE, tw.level.height * TILE + 160.0)
	var inside := true
	var met := {}
	var gone := false
	var looked := false
	for i in 400:
		gone = gone or not tw.player.on_floor
		_ticks(tw, DT, {"right": not gone})
		looked = looked or str(tw.tall_cam.looking) == "fall"
		var vr := _view_rect(tw)
		inside = inside and all_rect.encloses(vr.grow(-0.5))
		for tv in tw.chunks:
			if _chunk_rect(tv).intersects(vr):
				met[int(tv.row0) / 16] = true
		if gone and tw.player.on_floor:
			break
	_check(looked and inside and met.size() == 3, "down the shaft the camera looks ahead, never shows past the chunks and the bedrock, and meets all 3 rows of them (%s, %s, %s)" % [looked, inside, met.keys()])
	await _done(tw)
	# lab-shapes' crumble (row 8, columns 44-47: chunk row 0), its catch floor 4 rows under it.
	var w = await _world(_lab("lab-shapes"))
	_check(w.chunk_rows == 2, "lab-shapes: 2 rows of chunks")
	var n: Dictionary = _drawn_chunks(w)
	w.player.reset_at(Vector2(45 * TILE + 16, 8 * TILE))
	w.player.velocity = Vector2.ZERO
	await _frames(2)
	for k in n:
		n[k] = 0
	var fell := false
	for i in 600:
		_ticks(w, DT)
		if w.player.position.y > 10 * TILE and w.player.on_floor:
			fell = true
			break
	await _frames(2)
	var hit := []
	for k in n:
		if int(n[k]) > 0:
			hit.append(k)
	var want: Array = w.chunks_at(44, 8) + w.chunks_at(47, 8)
	var low := hit.filter(func(k): return int(w.chunks[k].row0) > 0)
	_check(fell and not hit.is_empty() and hit.all(func(k): return want.has(k)) and low.is_empty(),
			"lab-shapes: the crumble gives way under him and redraws its own chunks only (%s of %s; the lower row %s)" % [hit, want, low])
	await _done(w)


func _test_room_tall_lab() -> void:
	## Sealed rooms in a tall level: lab-shapes' duel, on its upper storey
	## (rows 1-10), walked into from its right door as its route comes: both
	## doors seal (their chunks redrawn, the lower row of chunks not), the
	## tall camera on him; its foe falls and the doors open.
	var w = await _world(_lab("lab-shapes"))
	var m = w.features.module("sealed")
	_ticks(w, 0.5)
	var r: Dictionary = m.rooms[0]
	var n: Dictionary = _drawn_chunks(w)
	_stand(w, 93, 9)
	await _frames(2)
	for k in n:
		n[k] = 0
	var phase := ""
	for i in 480:
		_ticks(w, DT, {"left": w.player.position.x > 86 * TILE})
		if str(r["phase"]) == "fight":
			phase = "fight"
			break
	await _frames(2)
	var doors := {}
	for c in r["sealed"]:
		doors[(c as Vector2i).x] = true
	var ks := doors.keys()
	ks.sort()
	_check(phase == "fight" and ks == [76, 89], "lab-shapes: in by its right door, the upper storey's duel shuts at both ends (%s, %s)" % [r["phase"], ks])
	var hit := []
	for k in n:
		if int(n[k]) > 0:
			hit.append(k)
	var want: Array = w.chunks_at(76, 8) + w.chunks_at(89, 8)
	_check(not hit.is_empty() and hit.all(func(k): return want.has(k) and int(w.chunks[k].row0) == 0),
			"its doors redraw their own chunks, in the upper row (%s of %s)" % [hit, want])
	_check(w.tall_cam != null and _feet(w) <= _special_top(w), "the tall camera keeps him over the Special in the room (feet %.0f)" % _feet(w))
	for e in m.counted(r):
		e.hp = 0.0
		e._kill({"how": "slash", "from_x": e.position.x - 20.0})
	_ticks(w, 0.5)
	_check(str(r["phase"]) == "won" and (r["sealed"] as Array).is_empty(), "its foe falls and the doors open (%s)" % r["phase"])
	await _done(w)
