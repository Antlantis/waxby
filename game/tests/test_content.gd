extends SceneTree
## test_content (W5): the World 2 monsters and their rules, the level
## features, elites and Omens, the Snuffer, and the interaction table
## below; the level rules and 1-1's teaching signs (the Special, the
## flask); then the reachability bot again with every waxfall pouring (it
## must still reach every bell and every sigil).
##
##     godot --headless --path game --script res://tests/test_content.gd
##
## THE INTERACTION TABLE (source of truth; crit_director 2.9). How each
## calling's Special or shot reaches a monster:
##   Rush    world.deal(e, 1.2, {how: "skill", from_x: Wick's x})         (Candleknight)
##   Peal    world.add_hazard({kind: "wave", owner: "player", coef, ...})  (Bellfounder; how "wave")
##   Beacon  world.add_light(p, 160, s, 6.0, "beacon")                     (Taperwitch)
##   knife   world.spawn_shot({kind: "knife", owner: "player", ...})       (Sootrunner; how "shot")
##   mote    world.spawn_shot({kind: "mote", owner: "player", homing})     (Sexton; how "shot")
##
##          | Helm, front      | Gutterwing, latched  | Snuffer, hollow  | Warded motes     | Thornback, flipped
##  --------+------------------+----------------------+------------------+------------------+-------------------
##  Rush    | blocked (0), and | the press pops it    | passes through   | takes one mote,  | lands, x1.25
##          | Wick shoved back | off; the blow kills  | (0)              | 0 damage         |
##  Peal    | blocked (0)      | can't reach it (it   | passes through   | takes one mote,  | lands, x1.25
##          |                  | rides the flame)     | (0)              | 0 damage         |
##  Beacon  | nothing          | nothing (it lures    | solid within     | nothing          | nothing
##          |                  | only free moths)     | 110 px           |                  |
##  knife   | stopped (0)      | the throw pops it;   | flies through    | takes one mote,  | lands, x1.25
##          |                  | a hit kills it       | (0)              | knife stops      |
##  mote    | stopped (0)      | a hit knocks it off  | flies through    | takes one mote   | lands, x1.25
##          |                  |                      | (0)              |                  |

const LevelData := preload("res://scripts/level_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Combat := preload("res://scripts/combat.gd")
const Rules := preload("res://tests/level_rules.gd")
var WorldScript: GDScript   # loaded at run time: it needs the autoloads
var Elites: GDScript
const TILE := 32
const DT := 1.0 / 120.0

var _passed := 0
var _failed := 0
var game: Node


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	Elites = load("res://scripts/elites.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_content_save.json"
	for suffix in [".bak", ".tmp"]:   # a last run's backup would be loaded as the save
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	await _test_helm()
	await _test_bonebow()
	await _test_gutterwing()
	await _test_dripkin()
	await _test_dripkin_lost()
	await _test_low_boxes()
	await _test_brinejaw()
	await _test_lidlurk()
	await _test_thornback()
	await _test_thornback_brace()
	await _test_douse()
	await _test_water()
	await _test_lanterns()
	await _test_waxfall()
	await _test_spouts_and_nests()
	await _test_omens()
	await _test_elite_picks()
	await _test_snuffer()
	await _test_choir()
	await _test_table()
	await _test_art_seams()
	await _test_snuffer_seams()
	_test_level_rules()
	await _test_tutorial_signs()
	await _test_sign_reading()
	_test_hang_heights()
	_test_star_routes()
	_test_bot_with_waxfalls()
	for suffix in ["", ".bak", ".tmp"]:   # (a save keeps its last one as .bak, and a load falls back to it)
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_content_save.json" + suffix))
	game.save_path = game.SAVE_PATH
	game.load_save()
	print("test_content: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _rows(w := 60, fill := {}) -> Array:
	## A flat room: floor on row 13, Wick at column 3, the bell far right.
	## fill: {Vector2i: char} to draw in.
	var rows := []
	for y in 15:
		var r := ("#".repeat(w)) if y >= 13 else ".".repeat(w)
		rows.append(r)
	rows[12] = rows[12].substr(0, 3) + "P" + rows[12].substr(4)
	rows[12] = rows[12].substr(0, w - 3) + "E" + rows[12].substr(w - 2)
	for c in fill:
		var cell: Vector2i = c
		var r: String = rows[cell.y]
		rows[cell.y] = r.substr(0, cell.x) + str(fill[c]) + r.substr(cell.x + 1)
	return rows


func _world(rows: Array, header := "", diff := "dusk") -> Node2D:
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n" + header + "---\n" + "\n".join(rows))
	lv.id = "t"
	game.reset()
	game.data["difficulty"] = diff
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	return w


func _level_world(id: String, diff := "dusk", run := 0) -> Node2D:
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	game.reset()
	game.data["difficulty"] = diff
	game.data["run_counter"] = run
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	return w


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _step(w: Node2D, n: int, pad := {}) -> void:
	for i in n:
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _until(w: Node2D, done: Callable, seconds: float) -> void:
	## Steps until done() is true (or the time runs out).
	for i in int(seconds / DT):
		if done.call():
			return
		_step(w, 1)


func _press(w: Node2D, key: String) -> void:
	_step(w, 1, {key: true})
	_step(w, 1, {})


func _settle(w: Node2D, at: Vector2) -> void:
	w.player.reset_at(at)
	w.player.invuln = 0.0
	_step(w, 20)


func _spawn(w: Node2D, kind: String, cell: Vector2i, opts := {}) -> Node2D:
	var EK = load("res://scripts/enemy_kinds.gd")
	var o := opts.duplicate()
	o["cell"] = cell
	var e: Node2D = w.spawn_enemy(kind, EK.spawn_pos(kind, cell), o)
	e.active = true
	return e


# ---------------------------------------------------------------- the art seams (integration)

func _test_art_seams() -> void:
	## W6b's frames on W5's monsters: anchors, the hanging Dripkin, eyes on
	## the drawn eyes, deaths that fade, and the World 2 props' points.
	var w := await _world(_hall(40))
	_settle(w, Vector2(4 * TILE, 13 * TILE))
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	# Anchors: Gutterwing and Brinejaw by the middle, the rest by the feet.
	var anchors := {"bonebow": Vector2(64, 122), "hollow_helm": Vector2(64, 122), "gutterwing": Vector2(64, 64),
			"dripkin": Vector2(64, 122), "lidlurk": Vector2(64, 122)}
	var mons := {}
	var x := 14
	for k in anchors:
		var e := _spawn(w, k, Vector2i(x, 9 if k == "dripkin" else (11 if k == "gutterwing" else 12)))
		mons[k] = e
		x += 4
		_check(e.anchor == anchors[k] and not e.frames.is_empty(), "%s: W6b's frames, anchored at %s" % [k, anchors[k]])
		_check(is_equal_approx(e.sprite.offset.x, -anchors[k].x * 2.0), "%s: the sprite is offset by its anchor" % k)
	var jw := await _world(_pool_rows())
	var jaw := _spawn(jw, "brinejaw", Vector2i(14, 13))
	_check(jaw.anchor == Vector2(64, 64) and not jaw.frames.is_empty(), "brinejaw: anchored by its middle")
	await _done(jw)
	_step(w, 2)
	# The hanging Dripkin: frame y 10 on the ceiling, then back on its feet.
	var dk: Node2D = mons["dripkin"]
	_check(dk.hanging() and is_equal_approx(dk.sprite.position.y, 56.0), "a hanging Dripkin's sprite drops 56 px")
	var ceil_px: float = dk.position.y + dk.sprite.position.y + (10.0 - dk.anchor.y) * 0.5
	_check(absf(ceil_px - dk.ceiling_y) < 0.01, "so the drawn ceiling line (frame y 10) sits on the ceiling")
	w.deal(dk, 1.0, {"how": "slash", "flat": 1.0, "from_x": dk.position.x - 20.0})
	_check(dk.state == "drop" and dk.sprite.position.y == 0.0 and dk.anchor == Vector2(64, 122), "knocked loose, it drops on its own feet (anchor unchanged)")
	# Eyes sit on the art's eyes, mirrored with the facing.
	var bow: Node2D = mons["bonebow"]
	bow.state = "idle"
	bow.show_frame("bonebow_idle")
	for f in [1, -1]:
		bow.facing = f
		var eyes: Array = bow.eye_points()
		var want: Vector2 = bow.position + Vector2((60.4 - 64.0) * 0.5 * f, (80.6 - 122.0) * 0.5)
		_check(eyes.size() == 2 and (eyes[0] as Vector2).distance_to(want) < 0.01, "a Bonebow's eyes follow its art (facing %d)" % f)
	var helm: Node2D = mons["hollow_helm"]
	helm.show_frame("helm_bash")
	helm.facing = 1
	_check((helm.eye_points()[1] as Vector2).distance_to(helm.position + helm.sprite.position + Vector2((81.9 - 64.0) * 0.5, (78.2 - 122.0) * 0.5)) < 0.01,
			"a Helm's glints follow the bash frame's lean")
	var wing: Node2D = mons["gutterwing"]
	wing.show_frame("wing_fly1")
	_check((wing.eye_points()[0] as Vector2).distance_to(wing.position + Vector2((61.6 - 64.0) * 0.5 * wing.facing, (63.4 - 64.0) * 0.5)) < 0.01,
			"a Gutterwing's eyes are on its face")
	# Shots and tells from the drawn bow: the arrowhead is on the arrow.
	bow.facing = 1
	bow.show_frame("bonebow_draw")
	bow.aim = Vector2.RIGHT
	_check(bow._tip().distance_to(bow.position + Vector2((110.4 - 64.0) * 0.5, (91.4 - 122.0) * 0.5)) < 0.01, "the Bonebow's glint is on the drawn arrowhead")
	# A death fades out (enemy.gd resets the sprite's colour every step).
	var lurk: Node2D = mons["lidlurk"]
	w.deal(bow, 1.0, {"how": "stomp", "flat": 9999.0})
	_step(w, int(0.9 / DT))
	_check(is_instance_valid(bow) and bow.sprite.modulate.a < 0.9, "a dead Bonebow's bones fade (a %.2f)" % (bow.sprite.modulate.a if is_instance_valid(bow) else -1.0))
	_check(lurk.alive, "(the Lidlurk sleeps on)")
	await _done(w)
	# The props' points (points_world2.json).
	var rows := _rows(40)
	for y in range(0, 9):
		rows[y] = "#".repeat(40)
	rows[12] = rows[12].substr(0, 10) + "L" + rows[12].substr(11)
	rows[9] = rows[9].substr(0, 16) + "d" + rows[9].substr(17)
	rows[9] = rows[9].substr(0, 20) + "!" + rows[9].substr(21)
	rows[10] = rows[10].substr(0, 26) + "N" + rows[10].substr(27)
	var pw := await _world(rows)
	var ft: Object = pw.features
	var l: Dictionary = ft.lanterns[0]
	_check(is_equal_approx(l["pos"].y - l["flame"].y, 33.0) and is_equal_approx((l["rect"] as Rect2).size.y, 48.0),
			"a lantern post hangs its light 33 px up, and is 48 px tall")
	_check(is_equal_approx(ft.spouts[0]["tip"].y - 9 * TILE, 18.0), "a spout's drops form 18 px under the tile top")
	_check(is_equal_approx(ft.falls[0]["top"] - 9 * TILE, 26.5), "a waxfall pours from 26.5 px under the tile top")
	var n: Dictionary = ft.nests[0]
	_check(is_equal_approx(n["flame"].y - 10 * TILE, 7.0) and is_equal_approx(n["cocoon"].y - 10 * TILE, 26.5),
			"a nest's flame is 7 px down its tile and its cocoon 26.5 px")
	await _done(pw)
	var aw := await _snuffer_world()
	var br: Dictionary = aw.features.braziers()[0]
	_check(is_equal_approx(br["pos"].y - br["flame"].y, 31.5), "a brazier's flame is 31.5 px up")
	await _done(aw)


func _test_snuffer_seams() -> void:
	## W6b's Snuffer on W5's fight: the lunge box, the slam's reach, his
	## eyes, the cap over the flame, hiding in the smoke, Tollbreaker.
	var w := await _snuffer_world()
	var pl: Node2D = w.player
	var sn: Node2D = w.boss
	sn.active = true
	pl.reset_at(Vector2(sn.arena_left + 80.0, 13 * TILE))
	pl.invuln = 1000.0
	_step(w, 5)
	var mid: float = (sn.arena_left + sn.arena_right) * 0.5
	sn.position.x = mid
	sn.state = "lunge"
	_check(sn.body_rect() == Rect2(mid - 50.0, sn.floor_y - 80.0, 100.0, 52.0), "the lunge's body is W6b's box")
	_check(is_equal_approx(sn.REACH, 65.0), "the slam lands 65 px ahead, under the drawn bell")
	# Eyes on the frame (idle: the art's pinpricks), mirrored with facing.
	sn.state = "recoil"
	sn.timer = 99.0
	sn.show_frame("snuffer_idle")
	sn.facing = -1
	var e0: Vector2 = sn.eye_points()[0]
	_check(e0.distance_to(sn.position + Vector2(-(200.9 - 192.0) * 0.5, (200.8 - 368.0) * 0.5)) < 0.01, "his eyes sit on the art's")
	_check(not sn.touch_damage(), "reeling from a blow, his touch is harmless")
	# Snuff the Light: his bell ends over the brazier's flame.
	sn.state = "drift"
	sn._move_n = 1
	sn.position.x = mid
	sn._next(pl)
	var target: Dictionary = sn._target
	var capped := false
	for i in int(6.0 / DT):
		_step(w, 1)
		if sn.state == "cap":
			capped = true
			break
	_step(w, 2)
	var mouth: Vector2 = sn._cone_mouth()
	_check(capped and absf(mouth.x - (target["flame"] as Vector2).x) < 8.0 and mouth.y < (target["flame"] as Vector2).y,
			"capping, the bell hangs over the flame (%.0f px off)" % (mouth.x - (target["flame"] as Vector2).x))
	# A ledge brazier: he floats up to it.
	await _done(w)
	w = await _snuffer_world()
	pl = w.player
	sn = w.boss
	sn.active = true
	pl.reset_at(Vector2(sn.arena_left + 80.0, 13 * TILE))
	pl.invuln = 1000.0
	_step(w, 5)
	var ledge: Dictionary = {}
	for b in w.features.braziers():
		if not b["start_lit"]:
			ledge = b
	w.features.light(ledge)
	for b in w.features.braziers():
		if b != ledge:
			w.features.snuff_brazier(b)
	pl.reset_at(ledge["pos"])
	sn._move_n = 1
	sn._next(pl)
	capped = false
	for i in int(8.0 / DT):
		_step(w, 1)
		if sn.state == "cap":
			capped = true
			break
	_step(w, 2)
	mouth = sn._cone_mouth()
	_check(capped and absf(mouth.y - ((ledge["flame"] as Vector2).y - 12.0)) < 8.0, "for a ledge brazier he floats up to cap it")
	# Between the wall and a brazier there's no room for his reach: he
	# comes at it from the other side instead of hovering at the wall.
	w.features.reset_braziers()
	var near_wall: Dictionary = {}
	for b in w.features.lit_braziers():
		if near_wall.is_empty() or (b["pos"] as Vector2).x < (near_wall["pos"] as Vector2).x:
			near_wall = b
	for b in w.features.lit_braziers():
		if b != near_wall:
			w.features.snuff_brazier(b)
	sn.state = "drift"
	sn._lift = 0.0
	sn.position.x = sn.arena_left + 20.0
	pl.reset_at(Vector2(near_wall["pos"].x - 30.0, 13 * TILE))
	sn._move_n = 1
	sn._next(pl)
	capped = false
	for i in int(7.0 / DT):
		_step(w, 1)
		if sn.state == "cap":
			capped = true
			break
	_step(w, 2)
	mouth = sn._cone_mouth()
	_check(capped and absf(mouth.x - (near_wall["flame"] as Vector2).x) < 8.0,
			"wedged by the wall, he still caps the brazier, from its far side")
	# The smoke tide: he fades into it and is gone under it.
	sn.state = "drift"
	sn.phase = 2
	sn._move_n = -1
	sn._next(pl)
	_check(sn.state == "sink", "phase 2 opens with the tide")
	_until(w, func(): return sn.state == "under", 3.0)
	_step(w, 2)
	_check(sn.state == "under" and sn.sprite.modulate.a < 0.01, "under the smoke his sprite is gone")
	_until(w, func(): return sn.state == "drift", 8.0)
	_step(w, 2)
	_check(sn.sprite.modulate.a > 0.5, "and back when he rises")
	await _done(w)
	# Tollbreaker holds his openings 0.4 s longer.
	w = await _snuffer_world()
	pl = w.player
	sn = w.boss
	sn.active = true
	pl.reset_at(Vector2(sn.arena_left + 80.0, 13 * TILE))
	pl.invuln = 1000.0
	_step(w, 5)
	pl.stats["flags"] = {"tollbreaker_window": 0.4}
	sn.state = "raise"
	sn.timer = 0.0
	sn._slam_x = sn.position.x + sn.facing * sn.REACH
	_step(w, 1)
	_check(sn.state == "stuck" and absf(sn.timer - (sn.STUCK[0] + 0.4)) < 0.02, "Tollbreaker: the pole sticks 0.4 s longer (%.2f)" % sn.timer)
	sn.state = "glide"
	sn.solid_t = 1.0
	w.deal(sn, 1.0, {"how": "slash", "flat": 1.0, "from_x": sn.position.x - 20.0})
	_check(sn.state == "recoil" and absf(sn.timer - 0.9) < 0.02, "and a stagger lasts 0.9 s")
	pl.stats["flags"] = {}
	await _done(w)


# ---------------------------------------------------------------- the monsters

func _test_helm() -> void:
	var w := await _world(_rows())
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	var helm := _spawn(w, "hollow_helm", Vector2i(12, 12), {"facing": -1})
	_step(w, 5)
	var hp0: float = helm.hp
	var res: Dictionary = w.deal(helm, 1.0, {"how": "slash", "from_x": pl.position.x})
	_check(not res["hit"] and helm.hp == hp0, "a front slash on a Hollow Helm is blocked")
	_check(pl.dash_time > 0.0 and pl.dash_vel.x < 0.0, "and shoves Wick back")
	res = w.deal(helm, 1.0, {"how": "slash", "from_x": helm.position.x + 40.0})
	_check(res["hit"] and helm.hp < hp0, "a slash from behind lands")
	# A real swing into the shield: clang, "Blocked".
	_settle(w, Vector2(helm.position.x - 30.0, 13 * TILE))
	pl.facing = 1
	helm.facing = -1
	var before: float = helm.hp
	_press(w, "attack")
	_step(w, 6)
	var blocked := false
	for it in w.floaters.items:
		if it["kind"] == "blocked":
			blocked = true
	_check(blocked and helm.hp == before, "a swing at its front shows Blocked and does nothing")
	# A stomp knocks the shield down for 1.2 s.
	res = w.deal(helm, 1.0, {"how": "stomp", "flat": 5.0})
	_check(res["hit"] and helm.state == "noshield", "a stomp knocks its shield down")
	before = helm.hp
	res = w.deal(helm, 1.0, {"how": "slash", "from_x": helm.position.x - 30.0})
	_check(res["hit"] and helm.hp < before, "with the shield down its front is open")
	helm.hp = helm.max_hp
	pl.reset_at(Vector2(helm.position.x - 320.0, 13 * TILE))
	pl.invuln = 100.0
	_step(w, int(1.3 / DT))
	_check(helm.shielded(), "and it picks the shield up again")
	# Frontal shots are stopped too.
	helm.facing = -1
	before = helm.hp
	w.spawn_shot({"kind": "knife", "owner": "player", "pos": helm.center() + Vector2(-40, 0), "vel": Vector2(500, 0), "life": 1.0, "coef": 1.0})
	_step(w, 20)
	_check(helm.hp == before, "a knife at its front is stopped")
	# Its turn is slow: 0.55 s to face someone behind it.
	helm.state = "advance"
	helm.facing = 1
	pl.reset_at(Vector2(helm.position.x - 60.0, 13 * TILE))
	_step(w, 2)
	_check(helm.state == "turn", "someone behind it makes it turn")
	_step(w, int(0.45 / DT))
	_check(helm.facing == 1, "and the turn takes over half a second")
	_step(w, int(0.2 / DT))
	_check(helm.facing == -1, "then it faces him")
	await _done(w)


func _test_bonebow() -> void:
	var w := await _world(_rows(80))
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	pl.invuln = 100.0
	# Off screen it never shoots.
	var far := _spawn(w, "bonebow", Vector2i(60, 12))
	_step(w, int(2.5 / DT))
	var arrows := 0
	for s in w.shots:
		if s["kind"] == "arrow":
			arrows += 1
	_check(arrows == 0 and far.state == "idle", "a Bonebow off screen doesn't shoot")
	far.alive = false
	far.gone = true
	# In view: it draws for 0.65 s, then looses.
	var bow := _spawn(w, "bonebow", Vector2i(18, 12))
	_step(w, 3)
	_check(bow.state == "draw", "in view and in range, it draws")
	_step(w, int(0.5 / DT))
	_check(bow.locked, "its aim locks before it looses")
	var arrow := {}
	for i in int(0.3 / DT):
		_step(w, 1)
		for s in w.shots:
			if s["kind"] == "arrow" and s["owner"] == "enemy":
				arrow = s
		if not arrow.is_empty():
			break
	_check(not arrow.is_empty() and arrow["deflect"], "then looses a deflectable bone arrow")
	# Swing as it comes: it flies back and can kill the archer.
	pl.facing = 1
	bow.hp = 4.0
	var swung := false
	for i in 200:
		if not arrow.is_empty() and not swung and arrow["pos"].x - pl.position.x < 40.0:
			swung = true
			_step(w, 1, {"attack": true})
		else:
			_step(w, 1)
		if not bow.alive:
			break
	_check(arrow.get("owner", "") == "player", "a swing sends the arrow back")
	_check(not bow.alive, "and the deflected arrow kills its Bonebow")
	# Two shots, then it steps back.
	var b2 := _spawn(w, "bonebow", Vector2i(18, 12))
	var x0: float = b2.position.x
	pl.invuln = 100.0
	_step(w, int(6.5 / DT))
	_check(b2.position.x > x0 + 16.0, "after two shots it steps back a tile (%.0f px)" % (b2.position.x - x0))
	await _done(w)


func _test_gutterwing() -> void:
	var w := await _world(_rows())
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	pl.invuln = 0.0
	var r0: float = w.hero_light_radius()
	var wing := _spawn(w, "gutterwing", Vector2i(14, 8))
	var latched := false
	for i in int(6.0 / DT):
		_step(w, 1)
		if wing.state == "latch":
			latched = true
			break
	_check(latched, "a Gutterwing drifts to the flame and latches on")
	_step(w, int(1.2 / DT))
	_check(pl.has_status("latch") and w.hero_light_radius() < r0 * 0.7, "a latched moth dims his light (%.0f -> %.0f)" % [r0, w.hero_light_radius()])
	var hp0: float = pl.hp
	_step(w, int(1.6 / DT))
	_check(absf((hp0 - pl.hp) / pl.max_hp - 0.12) < 0.02, "after 2.5 s it drains 12%% of his life (%.2f)" % ((hp0 - pl.hp) / pl.max_hp))
	_press(w, "attack")
	_step(w, 2)
	_check(wing.state != "latch" and not pl.has_status("latch"), "a swing pops it off his flame")
	_check(w.hero_light_radius() > r0, "Snatched back: his light flares")
	# A Beacon lures a free moth away from him.
	var w2 := _spawn(w, "gutterwing", Vector2i(20, 8))
	w.add_light(Vector2(22 * TILE, 8 * TILE), 160.0, 0.9, 6.0, "beacon")
	_step(w, int(2.0 / DT))
	_check(w2.state == "drift" and w2.position.distance_to(Vector2(22 * TILE, 8 * TILE)) < 60.0, "a Beacon lures a free Gutterwing")
	# With real art (a stand-in texture here) the latched moth's frame is
	# drawn in the glow layer, over the flame, and its sprite steps aside.
	var w3 := _latched_wing(w)
	w3.frames["wing_latch"] = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	_step(w, 2)
	_check(w3.state == "latch" and not w3.sprite.visible, "with a latch frame, the glow layer draws the latched moth")
	_press(w, "attack")
	_step(w, 2)
	_check(w3.state != "latch" and w3.sprite.visible, "and its sprite shows again once it's knocked off (%s)" % w3.state)
	await _done(w)


func _hall(w := 40) -> Array:
	## A low hall: stone down to row 8, open rows 9-12.
	var rows := _rows(w)
	for y in range(0, 9):
		rows[y] = "#".repeat(w)
	return rows


func _test_dripkin() -> void:
	var w := await _world(_hall())
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE + 16, 13 * TILE))
	var drip := _spawn(w, "dripkin", Vector2i(10, 9))
	_check(drip.state == "hang" and drip.rect().position.y == 9 * TILE, "a Dripkin hangs from the ceiling")
	_step(w, 2)
	_check(drip.state == "quiver", "it quivers when Wick is under it")
	var hp0: float = pl.hp
	for i in int(1.0 / DT):
		_step(w, 1)
		if drip.state == "splat":
			break
	_check(pl.hp < hp0 and pl.has_status("douse"), "its drop hurts and douses")
	_check(drip.state == "splat", "and it splats")
	var before: float = drip.hp
	w.deal(drip, 1.0, {"how": "slash", "flat": 4.0, "from_x": pl.position.x})
	_check(absf((before - drip.hp) - 6.0) < 0.01, "splatted, it takes +50%% (%.1f)" % (before - drip.hp))
	pl.invuln = 100.0
	_step(w, int(1.0 / DT))
	_check(drip.state == "crawl", "then it crawls")
	await _done(w)


func _test_dripkin_lost() -> void:
	## A Dripkin that drops into deep water or a pit never lands: it must
	## hiss out (a kill) rather than fall forever as a live monster.
	var rows := _pool_rows(40, 12, 20)
	for y in range(0, 9):
		rows[y] = "#".repeat(40)
	for y in [13, 14]:
		rows[y] = rows[y].substr(0, 28) + "...." + rows[y].substr(32)
	var w := await _world(rows)
	var killed := []
	w.enemy_killed.connect(func(e, how): killed.append([e, how]))
	for x in [16, 30]:
		var drip := _spawn(w, "dripkin", Vector2i(x, 9))
		w.deal(drip, 1.0, {"how": "slash", "flat": 1.0, "from_x": drip.position.x - 20.0})
		_check(drip.state == "drop", "a Dripkin knocked loose drops (%s)" % ("water" if x == 16 else "pit"))
		_until(w, func(): return not drip.alive, 2.0)
		_check(not drip.alive and killed.size() > 0 and killed[killed.size() - 1][1] == "pit",
				"one that falls into %s hisses out" % ("deep water" if x == 16 else "a pit"))
		_until(w, func(): return not w.enemies.has(drip), 2.0)
		_check(not w.enemies.has(drip), "and is gone from the world")
	await _done(w)


func _hero_world(cls: String, rows: Array) -> Node2D:
	## A room with a fresh level-5 hero of this calling (Dusk).
	game.reset()
	game.data["difficulty"] = "dusk"
	var h: Dictionary = game.new_hero(cls)
	h["level"] = 5
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n---\n" + "\n".join(rows))
	lv.id = "t"
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	w.apply_hero()
	return w


func _basic_hits(cls: String, kind: String, st: String, gap: float, sc := 1.0) -> bool:
	## Wick of this calling on flat ground taps his basic at a monster held
	## gap px in front of him (a Dripkin held splatted or crawling): does
	## anything land within 0.75 s?
	var w := await _hero_world(cls, _rows())
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	pl.facing = 1
	var px: float = pl.position.x
	var o := {"cell": Vector2i(0, 0)}
	if sc != 1.0:
		o["scale"] = sc
	var e: Node2D = w.spawn_enemy(kind, Vector2(px + gap, 13 * TILE), o)
	e.active = true
	if sc != 1.0:
		e.set("copy", true)
		e.as_copy()
	if kind == "dripkin":
		e.state = st
		if e.sprite:
			e.sprite.position = Vector2.ZERO
	else:
		e.apply_status("root", 999.0)
	e.max_hp = 99999.0
	e.hp = 99999.0
	pl.invuln = 999.0
	var hit := false
	for i in int(0.75 / DT):
		if kind == "dripkin":
			e.state = st
			e.timer = 9.0
		e.position = Vector2(px + gap, 13 * TILE)
		e.velocity = Vector2.ZERO
		e.facing = 1
		_step(w, 1, {"attack": (i % 24) < 12})
		pl.position.x = px
		pl.facing = 1
		if e.hp < 99999.0:
			hit = true
			break
	await _done(w)
	return hit


func _test_low_boxes() -> void:
	## A monster drawn low on the floor keeps a hit box a ranged basic meets:
	## a splatted or crawling Dripkin (and any Twinned half on the ground)
	## stands SHOT_LINE tall to be hit, while touching it hurts only on the
	## drawing, and landing on that drawing is a stomp.
	var line: float = Elites.SHOT_LINE
	var w := await _world(_rows())
	var pl: Node2D = w.player
	_settle(w, Vector2(6 * TILE, 13 * TILE))
	var fy := 13.0 * TILE
	for sc in [1.0, 0.6]:
		var o := {"cell": Vector2i(20, 12)}
		if sc != 1.0:
			o["scale"] = sc
		var drip: Node2D = w.spawn_enemy("dripkin", Vector2(20 * TILE + 16, fy), o)
		drip.active = true
		drip.as_copy()
		drip.position.y = fy
		# (A Twinned half starts out crawling and never hangs, so never splats.)
		for st in (["splat", "crawl"] if sc == 1.0 else ["crawl"]):
			drip.state = st
			var r: Rect2 = drip.rect()
			var hr: Rect2 = drip.hurt_rect()
			var d: Rect2 = drip.drawn_rect()
			var tag := "%s x%.1f" % [st, sc]
			_check(r.position.y <= fy - line + 0.01 and is_equal_approx(r.end.y, fy), "a %s Dripkin is hit up to %.0f px off the floor (%s)" % [tag, line, r])
			_check(r.size.x >= d.size.x - 0.01, "and its hit box is as wide as the drawing (%s)" % tag)
			_check(hr.size.x > 0.0 and hr.position.x >= d.position.x and hr.end.x <= d.end.x and is_equal_approx(hr.end.y, fy),
					"its touch box is on the drawing, 4 px in (%s: %s in %s)" % [tag, hr, d])
			_check(is_equal_approx(hr.position.y, minf(d.position.y, fy - line * 0.5)), "its full drawn height, at least half the shot line (%s: %s)" % [tag, hr])
			if sc == 1.0:
				_check(d.encloses(hr), "a full-size one's touch box is inside the drawing (%s)" % tag)
			# The first frame a slow landing (a Taperwitch's drift, 80 px/s)
			# touches it counts as a stomp, not a hurt.
			pl.position = Vector2(drip.position.x, hr.position.y + 80.0 * DT)
			pl.velocity = Vector2(0, 80.0)
			_check(pl.rect().intersects(hr) and pl.falling_onto(r), "landing slowly on a %s Dripkin is a stomp" % tag)
		drip.gone = true
		drip.alive = false
	_settle(w, Vector2(6 * TILE, 13 * TILE))
	# A real stomp on a puddle: it dies and Wick is unhurt.
	var dk: Node2D = w.spawn_enemy("dripkin", Vector2(8 * TILE, fy), {"cell": Vector2i(8, 12)})
	dk.active = true
	dk.as_copy()
	dk.position.y = fy
	pl.position = Vector2(dk.position.x, fy - 44.0)
	pl.velocity = Vector2.ZERO
	pl.invuln = 0.0
	var hp0: float = pl.hp
	for i in int(0.6 / DT):
		dk.state = "splat"
		dk.timer = 9.0
		_step(w, 1)
		if not dk.alive:
			break
	_check(not dk.alive and pl.hp >= hp0, "a stomp on a splatted Dripkin kills it, unhurt (alive %s, %.0f -> %.0f)" % [dk.alive, hp0, pl.hp])
	# Walking into a crawling one still hurts.
	var ck: Node2D = w.spawn_enemy("dripkin", Vector2(12 * TILE, fy), {"cell": Vector2i(12, 12)})
	ck.active = true
	ck.as_copy()
	_settle(w, Vector2(12 * TILE - 40.0, fy))
	hp0 = pl.hp
	for i in int(1.0 / DT):
		_step(w, 1, {"right": true})
		if pl.hp < hp0:
			break
	_check(pl.hp < hp0, "walking into a crawling Dripkin still hurts")
	# A Twinned half on the ground keeps SHOT_LINE; a flying one shrinks.
	for k in ["skeleton", "bonebow", "thornback", "lidlurk", "hollow_helm", "bat", "gutterwing"]:
		var c: Node2D = w.spawn_enemy(k, Vector2(30 * TILE, fy - 40.0), {"cell": Vector2i(30, 12), "scale": 0.6})
		var full: Node2D = w.spawn_enemy(k, Vector2(34 * TILE, fy - 40.0), {"cell": Vector2i(34, 12)})
		if c.flier:
			_check(is_equal_approx(c.size.y, full.size.y * 0.6), "a Twinned %s (a flier) is 0.6 as tall" % k)
		else:
			_check(c.size.y >= line and is_equal_approx(c.size.x, full.size.x * 0.6), "a Twinned %s stands %.0f px tall to be hit (%s)" % [k, line, c.size])
		c.gone = true
		c.alive = false
		full.gone = true
		full.alive = false
	# A flipped Thornback half still lies on the floor in its drawn height.
	_settle(w, Vector2(6 * TILE, fy))
	var tb: Node2D = w.spawn_enemy("thornback", Vector2(10 * TILE, fy), {"cell": Vector2i(10, 12), "scale": 0.6})
	tb.active = true
	tb.apply_status("flipped", 2.5)
	_step(w, 2)
	_check(tb.sprite.scale.y < 0.0 and is_equal_approx(tb.sprite.position.y, -30.0 * 0.6),
			"a flipped Twinned Thornback lies in its drawn height, not its taller box (%.1f)" % tb.sprite.position.y)
	await _done(w)
	# The shots themselves: a Taperwitch's spark and a Sootrunner's knife
	# land on a splatted or crawling Dripkin (and a Twinned half) up close.
	for cls in ["witch", "runner"]:
		for gap in [30.0, 48.0]:
			for st in ["splat", "crawl"]:
				_check(await _basic_hits(cls, "dripkin", st, gap), "a %s's basic hits a %s Dripkin %.0f px ahead" % [cls, st, gap])
			_check(await _basic_hits(cls, "dripkin", "crawl", gap, 0.6), "a %s's basic hits a Twinned Dripkin %.0f px ahead" % [cls, gap])
			_check(await _basic_hits(cls, "skeleton", "", gap, 0.6), "a %s's basic hits a Twinned Rattle %.0f px ahead" % [cls, gap])


func _pool_rows(w := 40, x0 := 12, x1 := 20) -> Array:
	## A deep pool in the floor from x0 to x1 (rows 13-14 water).
	var rows := _rows(w)
	for y in [13, 14]:
		var r: String = rows[y]
		rows[y] = r.substr(0, x0) + ":".repeat(x1 - x0 + 1) + r.substr(x1 + 1)
	return rows


func _test_brinejaw() -> void:
	var w := await _world(_pool_rows())
	var pl: Node2D = w.player
	_settle(w, Vector2(11 * TILE + 20, 13 * TILE))
	pl.invuln = 100.0
	var jaw := _spawn(w, "brinejaw", Vector2i(14, 13))
	_check(jaw.submerged() and not jaw.hit({"how": "slash", "amount": 99.0}), "a hidden Brinejaw can't be reached")
	var leapt := false
	var early_stomp := true
	for i in int(2.0 / DT):
		_step(w, 1)
		if jaw.state == "leap":
			leapt = true
			if jaw.velocity.y < -300.0:
				early_stomp = jaw.stompable
			if jaw.velocity.y > -150.0:
				break
	_check(leapt, "it leaps when Wick comes near")
	_check(not early_stomp, "rising fast, it can't be stomped")
	_check(jaw.stompable, "near the top of its leap it can")
	# Land on it there: the stomp kills it.
	pl.invuln = 0.0
	pl.position = jaw.position + Vector2(0, -4)
	pl.velocity = Vector2(0, 200)
	for i in 6:
		_step(w, 1)
		if not jaw.alive:
			break
	_check(not jaw.alive, "a stomp at the apex kills it")
	await _done(w)


func _test_lidlurk() -> void:
	# A Lidlurk sitting on a stone block Wick can bonk from below.
	var rows := _rows(40, {Vector2i(12, 9): "#"})
	var w := await _world(rows)
	var pl: Node2D = w.player
	var lurk := _spawn(w, "lidlurk", Vector2i(12, 8))
	_step(w, 30)
	_check(lurk.asleep() and not lurk.touch_damage(), "a Lidlurk sleeps, looking like a reliquary")
	_settle(w, Vector2(12 * TILE + 16, 13 * TILE))
	_step(w, 30, {"jump": true})
	_check(not lurk.asleep(), "a bonk from below wakes it")
	_check(not lurk.ordinary, "and it never counts as fodder (no respawn)")
	pl.invuln = 100.0
	_step(w, int(1.0 / DT))
	_check(lurk.state == "hop", "then it hops at him")
	var relics := 0
	w.deal(lurk, 1.0, {"how": "slash", "flat": 9999.0})
	_step(w, 10)
	for p in w.pickups:
		if p["kind"] == "relic":
			relics += 1
	_check(relics >= 1, "it always drops a relic (build 1: the vault's prize; an item once the codex is full)")
	await _done(w)


func _test_thornback() -> void:
	var w := await _world(_rows())
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	var th := _spawn(w, "thornback", Vector2i(14, 12))
	th.apply_status("flipped", 2.5)
	_step(w, 2)
	_check(not th.touch_damage(), "a flipped Thornback is harmless to touch")
	_check(th.sprite.scale.y < 0.0, "and lies on its back")
	pl.position = th.position + Vector2(0, -40)
	pl.velocity = Vector2(0, 200)
	var hp0: float = th.hp
	var php: float = pl.hp
	for i in 20:
		_step(w, 1)
		if th.hp < hp0:
			break
	_check(th.hp < hp0 and pl.hp == php, "and can be stomped")
	await _done(w)


func _brace_run(w: Node2D, th: Node2D, seconds := 1.0) -> Dictionary:
	## Steps until the Thornback runs at Wick. {t: seconds from the first
	## step until then (-1: never), moved: the most it slid meanwhile,
	## sparked: the glow layer gained sparks, braced: brace was ever > 0}.
	var x0: float = th.position.x
	var s0: int = w.glow.sparks.size() if w.glow else 0
	var out := {"t": -1.0, "moved": 0.0, "sparked": false, "braced": false}
	for i in int(seconds / DT):
		_step(w, 1)
		if th.get("brace") != null and float(th.get("brace")) > 0.0:
			out["braced"] = true
		if w.glow and w.glow.sparks.size() > s0:
			out["sparked"] = true
		var toward: float = th.velocity.x * signf(w.player.position.x - th.position.x)
		if toward > 60.0:
			out["t"] = (i + 1) * DT
			break
		out["moved"] = maxf(out["moved"], absf(th.position.x - x0))
	return out


func _until_brace(w: Node2D, th: Node2D) -> void:
	## A few steps at most: it lands on its first step, then sees Wick.
	_until(w, func(): return th.get("brace") != null and float(th.get("brace")) > 0.0, 0.1)


func _test_thornback_brace() -> void:
	## The Thornback's tell (review round 2): it braces before it charges,
	## for tell(0.35) (0.30 at the floor), holding its ground, with its tell
	## in the glow layer; a cut doesn't break the brace; Sooted, it stops.
	var TB = load("res://scripts/thornback.gd")
	var w := await _world(_rows())
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	# Facing away when Wick comes into range: it turns to him and braces.
	var th := _spawn(w, "thornback", Vector2i(13, 12), {"facing": 1})
	_until_brace(w, th)
	var b = th.get("brace")
	_check(b != null and float(b) > 0.0 and th.facing == -1 and th.frame_name == "thorn_brace",
			"a Thornback in range turns to Wick and braces (the brace frame) before it charges")
	_check(th.get("brace_len") != null and absf(float(th.get("brace_len")) - 0.35) < 0.001,
			"the brace lasts tell(0.35) on Dusk (%s)" % str(th.get("brace_len")))
	var r := _brace_run(w, th)
	_check(r["t"] >= 0.35 and r["t"] < 0.45, "it runs at him only after the brace: %.3f s after the trigger (want 0.35-0.45)" % r["t"])
	_check(r["moved"] < 1.5, "and holds its ground while braced (slid %.1f px)" % r["moved"])
	_check(r["sparked"], "the brace throws grit and sparks in the glow layer (drawn above the dark)")
	_step(w, 2)
	_check(absf(th.velocity.x + TB.CHARGE) < 0.5, "then charges at CHARGE (%.0f px/s)" % th.velocity.x)
	th.alive = false
	th.gone = true
	_step(w, 2)
	# A cut mid-brace flashes it but doesn't shove it back or break the brace.
	pl.reset_at(Vector2(10 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	th = _spawn(w, "thornback", Vector2i(13, 12), {"facing": -1})
	_step(w, 12)
	var x0: float = th.position.x
	var left: float = float(th.get("brace")) if th.get("brace") != null else 0.0
	w.deal(th, 1.0, {"how": "slash", "flat": th.max_hp * 0.4, "from_x": pl.position.x})
	_step(w, 8)   # past the hitstop
	_check(th.alive and th.get("brace") != null and float(th.get("brace")) > 0.0 and float(th.get("brace")) < left and absf(th.position.x - x0) < 1.0,
			"a heavy cut mid-brace doesn't break it or knock it back")
	r = _brace_run(w, th)
	_check(r["t"] > 0.0, "and it still charges when the brace runs out")
	th.alive = false
	th.gone = true
	_step(w, 2)
	# Sooted (the Smoke Step) mid-brace: the charge is off, and it won't go
	# for him while the soot lasts (spec: a Thornback's charge cancels).
	pl.reset_at(Vector2(10 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	th = _spawn(w, "thornback", Vector2i(13, 12), {"facing": -1})
	_step(w, 12)
	th.apply_status("sooted", 1.5)
	_step(w, 2)
	r = _brace_run(w, th, 1.2)
	_check(th.get("brace") != null and float(th.get("brace")) == 0.0 and r["t"] < 0.0 and not r["braced"],
			"Sooted, a bracing Thornback stops and doesn't charge or brace again while the soot lasts")
	th.alive = false
	th.gone = true
	# Flipped mid-brace, the charge is lost too.
	th = _spawn(w, "thornback", Vector2i(13, 12), {"facing": -1})
	pl.reset_at(Vector2(10 * TILE, 13 * TILE))
	_step(w, 6)
	th.apply_status("flipped", 1.0)
	_step(w, 2)
	_check(th.get("brace") != null and float(th.get("brace")) == 0.0 and absf(th.velocity.x) < 1.0,
			"flipped mid-brace, it loses the charge")
	# Stunned mid-run (a Perfect Guard, a Finisher, a stagger): the run
	# stops, but the walk half of the cycle, its cooldown, is kept and waits
	# out the stun, so it braces again only once that has run out.
	th.alive = false
	th.gone = true
	_step(w, 2)
	pl.reset_at(Vector2(10 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	th = _spawn(w, "thornback", Vector2i(13, 12), {"facing": -1})
	_until_brace(w, th)
	r = _brace_run(w, th)
	var ran: bool = r["t"] > 0.0 and th.charging()
	th.apply_status("stun", 0.5)
	_step(w, 1)
	var half: float = th.cd(TB.CYCLE) * 0.5
	var c0: float = float(th.get("_charge"))
	_check(ran and not th.charging() and absf(c0 - half) < 0.001,
			"stunned mid-run, it stops running but keeps the walk cooldown (%.3f, want %.3f)" % [c0, half])
	_step(w, int(0.4 / DT))
	_check(th.stunned() and absf(float(th.get("_charge")) - c0) < 0.001,
			"the stun pauses that cooldown instead of clearing it (%.3f)" % float(th.get("_charge")))
	var stun_left: float = float(th.status.get("stun", 0.0))
	var again := -1.0
	for i in int(1.5 / DT):
		_step(w, 1)
		if float(th.get("brace")) > 0.0:
			again = (i + 1) * DT - stun_left
			break
	_check(again >= half - 0.05 and again < half + 0.2,
			"and it braces again once the cooldown has run out, not straight after the stun (%.3f s after it, want ~%.2f)" % [again, half])
	await _done(w)
	# Harder difficulties and Swift shorten it, never below the 0.30 s floor.
	for d in ["nightfall", "witching"]:
		w = await _world(_rows(), "", d)
		_settle(w, Vector2(10 * TILE, 13 * TILE))
		w.player.invuln = 1000.0
		th = _spawn(w, "thornback", Vector2i(13, 12), {"facing": -1})
		_until_brace(w, th)
		var want: float = maxf(0.35 * float(Combat.diff(d)["tells"]), Elites.TELL_FLOOR)
		_check(th.get("brace_len") != null and absf(float(th.get("brace_len")) - want) < 0.001 and float(th.get("brace_len")) >= Elites.TELL_FLOOR,
				"%s: the brace is %.3f s (want %.3f, the floor %.2f)" % [d, float(th.get("brace_len")) if th.get("brace_len") != null else -1.0, want, Elites.TELL_FLOOR])
		r = _brace_run(w, th)
		_check(r["t"] >= Elites.TELL_FLOOR, "%s: it still runs only after the brace (%.3f s)" % [d, r["t"]])
		await _done(w)
	# Swift (v3, decisions): on Dusk its tells stay x1.0; off Dusk x0.75,
	# never under the floor.
	w = await _world(_rows())
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	w.player.invuln = 1000.0
	th = _spawn(w, "thornback", Vector2i(13, 12), {"facing": -1, "tier": "anointed", "omens": ["Swift"]})
	_until_brace(w, th)
	_check(th.get("brace_len") != null and absf(float(th.get("brace_len")) - 0.35) < 0.001,
			"Dusk: a Swift Thornback's brace stays 0.35 s (%s)" % str(th.get("brace_len")))
	await _done(w)
	w = await _world(_rows(), "", "nightfall")
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	w.player.invuln = 1000.0
	th = _spawn(w, "thornback", Vector2i(13, 12), {"facing": -1, "tier": "anointed", "omens": ["Swift"]})
	_until_brace(w, th)
	_check(th.get("brace_len") != null and absf(float(th.get("brace_len")) - Elites.TELL_FLOOR) < 0.001,
			"Nightfall: a Swift Thornback's brace stops at the 0.30 s floor (%s)" % str(th.get("brace_len")))
	await _done(w)


func _test_douse() -> void:
	var w := await _world(_rows())
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	var hp0: float = pl.hp
	w.douse_player()
	_check(pl.has_status("douse") and pl.hp == hp0, "a douse halves the light, no damage")
	w.douse_player()
	var lost: float = (hp0 - pl.hp) / pl.max_hp
	_check(absf(lost - float(Combat.diff("dusk")["douse_pct"])) < 0.005, "a douse while doused costs %d%% (%.3f)" % [int(Combat.diff("dusk")["douse_pct"] * 100), lost])
	await _done(w)


# ---------------------------------------------------------------- the features

func _test_water() -> void:
	# Deep water is a pit; shallow water only dims the light.
	var rows := _pool_rows(40, 14, 18)
	var r12: String = rows[12]
	rows[12] = r12.substr(0, 24) + ":::" + r12.substr(27)
	var w := await _world(rows)
	var pl: Node2D = w.player
	_settle(w, Vector2(12 * TILE, 13 * TILE))
	pl.position = Vector2(16 * TILE, 12 * TILE)
	pl.velocity = Vector2(0, 300)
	for i in 60:
		_step(w, 1)
	_check(absf(pl.hp / pl.max_hp - (1.0 - float(Combat.diff("dusk")["pit"]))) < 0.02, "deep water costs a pit's share (%.2f)" % (pl.hp / pl.max_hp))
	_check(pl.position.x < 14 * TILE, "and puts Wick back on the bank")
	pl.hp = pl.max_hp
	_settle(w, Vector2(22 * TILE, 13 * TILE))
	var dry: float = w.hero_light_radius()
	_settle(w, Vector2(25 * TILE + 16, 13 * TILE))
	_check(w.features.wading() and absf(w.hero_light_radius() / dry - 0.75) < 0.02, "wading dims his light to x0.75")
	_step(w, 60, {"right": true})
	_check(pl.position.x > 26 * TILE, "and doesn't slow him down")
	await _done(w)


func _test_lanterns() -> void:
	var w := await _world(_rows(40, {Vector2i(12, 12): "L"}))
	var pl: Node2D = w.player
	var l: Dictionary = w.features.lanterns[0]
	_check(not l["lit"] and not l["brazier"], "a lantern post starts dark")
	_settle(w, Vector2(12 * TILE + 16, 13 * TILE))
	_check(l["lit"] and w.lights_tagged("lantern").size() == 1, "touching it lights it")
	_check(absf(float(w.lights_tagged("lantern")[0]["r"]) - 140.0) < 10.0, "radius 140")
	pl.reset_at(Vector2(30 * TILE, 13 * TILE))
	_step(w, int(23.0 / DT))
	var gutter := false
	for i in int(1.5 / DT):
		_step(w, 1)
		if w.lights_tagged("lantern").size() > 0 and float(w.lights_tagged("lantern")[0]["r"]) < 120.0:
			gutter = true
	_check(l["lit"] and gutter, "it gutters near the end of its 25 s")
	_step(w, int(1.5 / DT))
	_check(not l["lit"] and w.lights_tagged("lantern").is_empty(), "and goes out after 25 s")
	# A swing lights it too.
	_settle(w, Vector2(11 * TILE, 13 * TILE))
	w.features.strike(Rect2(12 * TILE, 11 * TILE, 30, 30), 1)
	_check(l["lit"], "a swing lights a post")
	await _done(w)


func _test_waxfall() -> void:
	var rows := _rows(40)
	rows[1] = "#".repeat(40)
	rows[0] = "#".repeat(40)
	var r2: String = ".".repeat(40)
	rows[2] = r2.substr(0, 12) + "!" + r2.substr(13)
	var w := await _world(rows)
	var pl: Node2D = w.player
	var f: Dictionary = w.features.falls[0]
	_check(f["bottom"] == 13 * TILE, "a waxfall pours down to the floor")
	for i in int(4.0 / DT):
		_step(w, 1)
		if f["on"]:
			break
	_check(f["on"], "and runs")
	pl.position = Vector2(12 * TILE + 16, 9 * TILE)
	pl.velocity = Vector2(0, -500)
	pl.invuln = 0.0
	_step(w, 1)
	_check(pl.velocity.y >= 290.0, "while on it pushes him down (%.0f)" % pl.velocity.y)
	_check(pl.has_status("douse"), "and douses him")
	# The gurgle comes before it pours.
	var told := false
	for i in int(4.0 / DT):
		_step(w, 1)
		if f["tell"]:
			told = true
		if told and f["on"]:
			break
	_check(told, "a gurgle comes first")
	await _done(w)


func _test_spouts_and_nests() -> void:
	var rows := _rows(40, {Vector2i(12, 3): "d", Vector2i(26, 6): "N"})
	rows[2] = "#".repeat(40)
	var w := await _world(rows)
	var pl: Node2D = w.player
	_settle(w, Vector2(12 * TILE + 16, 13 * TILE))
	pl.invuln = 0.0
	var doused := false
	for i in int(3.0 / DT):
		_step(w, 1)
		if pl.has_status("douse"):
			doused = true
			break
	_check(doused, "a drip spout's drop douses whoever is under it")
	var wings := 0
	pl.invuln = 100.0
	_settle(w, Vector2(22 * TILE, 13 * TILE))
	pl.invuln = 100.0
	_step(w, int(4.0 / DT))
	for e in w.enemies:
		if e.kind == "gutterwing":
			wings += 1
	_check(wings == 2, "a nest breeds Gutterwings, two at most (%d)" % wings)
	await _done(w)


# ---------------------------------------------------------------- elites

func _test_omens() -> void:
	var w := await _world(_rows(60))
	var pl: Node2D = w.player
	_settle(w, Vector2(5 * TILE, 13 * TILE))
	pl.invuln = 100.0
	# Twinned: two small halves at a quarter of its life.
	var tw := _spawn(w, "skeleton", Vector2i(20, 12), {"tier": "anointed", "omens": ["Twinned"]})
	var full: float = tw.max_hp
	_step(w, 2)
	w.deal(tw, 1.0, {"how": "slash", "flat": 9999.0})
	var halves := []
	for e in w.enemies:
		if e.kind == "skeleton" and e.alive and e.get("copy"):
			halves.append(e)
	_check(halves.size() == 2, "a Twinned elite splits in two (%d)" % halves.size())
	if halves.size() == 2:
		_check(absf(halves[0].max_hp - 0.25 * full) < 0.5 and halves[0].scale_mult < 0.7, "each at 0.6 scale with a quarter of its life")
		_check(halves[0].omens.is_empty() and halves[0].tier == "", "with no Omens")
	# Warded: three motes, one per blow; a stomp breaks them all.
	var wd := _spawn(w, "skeleton", Vector2i(30, 12), {"tier": "anointed", "omens": ["Warded"]})
	_step(w, 2)
	var hp0: float = wd.hp
	var blocked := 0
	for i in 3:
		if not w.deal(wd, 1.0, {"how": "slash", "flat": 5.0, "from_x": wd.position.x - 20.0})["hit"]:
			blocked += 1
	_check(blocked == 3 and wd.hp == hp0, "Warded: three motes each stop a blow")
	_check(w.deal(wd, 1.0, {"how": "slash", "flat": 5.0, "from_x": wd.position.x - 20.0})["hit"], "the fourth lands")
	_check(wd.lights().is_empty(), "the broken motes give no light")
	_step(w, int(4.1 / DT))
	_check(wd.motes_up() == 3 and wd.lights().size() == 3, "they grow back after 4 s, and they are lights")
	hp0 = wd.hp
	var st: Dictionary = w.deal(wd, 1.0, {"how": "stomp", "flat": 5.0})
	_check(st["hit"] and wd.motes_up() == 0 and wd.hp < hp0, "a stomp breaks all three and still lands")
	# Vengeful: four shards in an X when hit.
	var vg := _spawn(w, "skeleton", Vector2i(40, 12), {"tier": "anointed", "omens": ["Vengeful"]})
	_step(w, 2)
	var n0: int = w.hazards.size()
	w.deal(vg, 1.0, {"how": "slash", "flat": 5.0})
	var shards := 0
	for h in w.hazards:
		if h["kind"] == "shard" and h["motion"] == "fly":
			shards += 1
	_check(shards == 4, "Vengeful: a hit fires 4 shards (%d)" % shards)
	# Burning: fire patches behind it.
	var bn := _spawn(w, "skeleton", Vector2i(48, 12), {"tier": "anointed", "omens": ["Burning"]})
	_step(w, int(1.0 / DT))
	var fires := 0
	for h in w.hazards:
		if h["kind"] == "fire" and h["owner"] == "enemy":
			fires += 1
	_check(fires >= 1, "Burning: it leaves fire on the floor")
	# Swift: faster, cooldowns shorter; on Dusk its tells stay (v3).
	var sw := _spawn(w, "bat", Vector2i(10, 6), {"tier": "anointed", "omens": ["Swift"]})
	_check(absf(sw.spd(100.0) - 100.0 * 1.15 * 1.4) < 0.01, "Swift: +40% speed on top of Anointed's")
	_check(absf(sw.tell(0.6) - 0.6) < 0.001 and absf(sw.tell(0.35) - 0.35) < 0.001, "Dusk: Swift leaves its tells at x1.0 (v3)")
	_check(absf(sw.cd(1.0) - 0.75) < 0.001, "and its cooldowns x0.75")
	# Elite life and the Dread's.
	var plain := _spawn(w, "skeleton", Vector2i(52, 12))
	var dread := _spawn(w, "skeleton", Vector2i(54, 12), {"tier": "dread", "omens": ["Twinned"]})
	_check(absf(dread.max_hp / plain.max_hp - 4.0) < 0.01 and not dread.ordinary, "a Dread has 4x life and is no fodder")
	await _done(w)


func _elite_cells(w: Node2D) -> Array:
	var out := []
	for e in w.enemies:
		if e.tier == "anointed":
			out.append([e.spawn["cell"], e.omens.duplicate()])
	out.sort()
	return out


func _test_elite_picks() -> void:
	# The same seed picks the same elites.
	var run_a := 0
	var ca := []
	while ca.is_empty() and run_a < 30:
		run_a += 1
		var a := await _level_world("2-1", "witching", run_a)
		ca = _elite_cells(a)
		await _done(a)
	var b := await _level_world("2-1", "witching", run_a)
	var cb := _elite_cells(b)
	await _done(b)
	_check(ca == cb and not ca.is_empty(), "elites are the same for the same seed (%s)" % [ca])
	# Never in 1-1; only on safe ground; never near an altar or the start.
	var ok := true
	var seen := 0
	var seeds_differ := false
	for id in ["1-1", "1-2", "1-3", "2-1", "2-2", "2-3"]:
		for run in 12:
			var w := await _level_world(id, "witching", run)
			var lv = w.level
			var cells := _elite_cells(w)
			if id == "1-1" and not cells.is_empty():
				ok = false
				print("  elite in 1-1: ", cells)
			if id == "2-1" and cells != ca:
				seeds_differ = true
			var n := 0
			for c in cells:
				n += 1
				var cell: Vector2i = c[0]
				var kind := ""
				var flier := false
				for e in w.enemies:
					if e.tier == "anointed" and e.spawn["cell"] == cell:
						kind = e.kind
						flier = bool(e.get("flier"))
						if e.ordinary:
							ok = false
				if not Elites.safe_for(lv, cell, kind, flier):
					ok = false
					print("  unsafe elite at ", id, " ", cell)
				for e in lv.entities:
					if e["kind"] == "altar" and absi(e["cell"].x - cell.x) < 12 and absi(e["cell"].y - cell.y) < 8:
						ok = false
				if absi(lv.start.x - cell.x) < 12:
					ok = false
				if c[1].size() != 2:
					ok = false
			if n > int(Combat.diff("witching")["max_anoint"]):
				ok = false
			seen += n
			for sp in w.spawns:
				for e in w.enemies:
					if e.tier == "anointed" and e.spawn["cell"] == sp["cell"]:
						ok = false
			await _done(w)
	_check(ok and seen > 0, "elites stand only on safe ground, never in 1-1, never respawn (%d seen)" % seen)
	_check(seeds_differ, "other seeds pick other elites")
	# On Dusk: one Omen, never Vengeful.
	var r := RandomNumberGenerator.new()
	var dusk_ok := true
	for i in 200:
		r.seed = i
		var o: Array = Elites.roll_omens("skeleton", "dusk", 1, r)
		if o.size() != 1 or o.has("Vengeful"):
			dusk_ok = false
	for i in 200:
		r.seed = i
		if Elites.roll_omens("lidlurk", "witching", 1, r).has("Swift") or Elites.roll_omens("brinejaw", "witching", 2, r).has("Burning"):
			dusk_ok = false
	_check(dusk_ok, "Dusk elites get one Omen, never Vengeful; Swift never on a Lidlurk, Burning never on a Brinejaw")
	# How many: Combat.DIFF[d].omens is the most (the table is read, not a
	# copy of it), and the least is what the difficulty below could give.
	_check(Elites.omen_span("dusk") == Vector2i(1, 1) and Elites.omen_span("nightfall") == Vector2i(1, 2)
			and Elites.omen_span("witching") == Vector2i(2, 2), "Omens per elite: Dusk 1, Nightfall 1-2, Witching 2 (spec §5)")
	for d in Combat.DIFFS:
		var counts := {}
		for i in 200:
			r.seed = i
			counts[Elites.roll_omens("skeleton", d, 1, r).size()] = true
		var most := int(Combat.diff(d)["omens"])
		var span: Vector2i = Elites.omen_span(d)
		var fits := counts.has(most) and counts.has(span.x)
		for n in counts:
			fits = fits and int(n) >= span.x and int(n) <= most
		_check(fits and span.y == most, "%s: elites carry %d-%d Omens, the most being Combat.DIFF's omens (%d; seen %s)" % [d, span.x, span.y, most, str(counts.keys())])
	# The Dreads the levels name.
	var dreads := {"1-1": ["Grandpa Rattle", "skeleton", ["Twinned"]], "1-2": ["Sootwing", "bat", ["Swift", "Burning"]],
			"1-3": ["Brother Barbs", "thornback", ["Warded", "Vengeful"]], "2-1": ["Old Drippings", "dripkin", ["Twinned", "Warded"]],
			"2-2": ["Captain Quiver", "bonebow", ["Swift", "Twinned"]], "2-3": ["The Wick-Eater", "gutterwing", ["Swift", "Burning"]]}
	for id in dreads:
		var w := await _level_world(id)
		var found := false
		# (A sealed room's foe sleeps out of the World's list till its doors
		# shut: 1-3's Barbs in his loft.)
		var sm = w.features.module("sealed") if w.features != null else null
		var all: Array = w.enemies.duplicate()
		if sm != null:
			for room in sm.rooms:
				all += room["away"]
		for e in all:
			if e.tier == "dread":
				found = e.elite_name == dreads[id][0] and e.kind == dreads[id][1] and e.omens == dreads[id][2] and not e.ordinary
		_check(found, "%s has its Dread, %s" % [id, dreads[id][0]])
		await _done(w)


# ---------------------------------------------------------------- the Snuffer

func _arena_rows() -> Array:
	var rows := [
		"##################################################",
		"##################################################",
		"................##.....d......d.....d......d....##",
		"................##..............................##",
		"................##..............................##",
		"................##..............................##",
		"................##..............................##",
		"................##..............................##",
		"................##..............................##",
		"................##.......L..............L.......##",
		".......................=====..........=====.....##",
		"................................................##",
		"...P...............L..:::::::X.......:::::::L...##",
		"##################################################",
		"##################################################",
	]
	return rows


func _snuffer_world() -> Node2D:
	var w := await _world(_arena_rows(), "boss: snuffer\n")
	return w


func _test_snuffer() -> void:
	var w := await _snuffer_world()
	var pl: Node2D = w.player
	var sn: Node2D = w.boss
	_check(sn != null and sn.boss_id == "snuffer" and sn.has_signal("woke"), "2-4's boss is the Snuffer")
	if sn == null:
		return
	var info: Dictionary = sn.boss_info()
	_check(info["name"] == "The Snuffer" and info["title"] == "The Hollow Wick" and info["phases"] == [0.60, 0.25], "his boss info")
	var start_lit: int = w.lights_tagged("brazier").size()
	_check(w.features.braziers().size() == 4 and start_lit == 2, "four braziers: the floor ones start lit, the ledge ones dark")
	sn.active = true
	_step(w, 30)
	_check(sn.state == "sleep", "he sleeps while Wick is outside")
	pl.reset_at(Vector2(sn.arena_left + 80.0, 13 * TILE))
	pl.invuln = 1000.0
	_step(w, 5)
	_check(sn.state == "roar", "he wakes when Wick steps in")
	var sealed := true
	for c in sn.door:
		sealed = sealed and LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(sealed and sn.door.size() >= 3, "and the door seals")
	# Far from any brazier: hollow.
	var mid: float = (sn.arena_left + sn.arena_right) * 0.5
	sn.position.x = mid
	sn.state = "recoil"
	sn.timer = 99.0
	sn.solid_t = 0.0
	_step(w, 2)
	var hp0: float = sn.hp
	var res: Dictionary = w.deal(sn, 1.0, {"how": "slash", "from_x": sn.position.x - 30.0})
	_check(not sn.solid() and not res["hit"] and sn.hp == hp0, "in the dark he's hollow: a hit deals 0")
	_check(sn.rect().size.x < 2.0 and sn.hurt_rect().size.x > 10.0, "blows pass through him, but his touch still hurts")
	# By a lit brazier: solid.
	var br: Dictionary = w.features.lit_braziers()[0]
	sn.position.x = br["pos"].x + 30.0
	sn.timer = 99.0
	_step(w, 2)
	res = w.deal(sn, 1.0, {"how": "slash", "from_x": sn.position.x - 30.0})
	_check(sn.solid() and res["hit"] and sn.hp < hp0, "by a lit brazier he's solid and a hit lands")
	# The afterglow: solid for 1.0 s after leaving the light.
	sn.position.x = mid
	_step(w, int(0.5 / DT))
	_check(sn.solid(), "and stays solid a moment after leaving it")
	_step(w, int(0.7 / DT))
	_check(not sn.solid(), "then goes hollow again")
	# A Beacon counts as light.
	var beacon: int = w.add_light(sn.center() + Vector2(40, 0), 160.0, 0.9, 6.0, "beacon")
	_step(w, 2)
	_check(sn.solid(), "a Beacon makes him solid too")
	w.remove_light(beacon)
	_step(w, int(1.2 / DT))
	# His slam: tracks, raises (the tell), comes down, sticks: solid while stuck.
	sn.state = "track"
	sn.timer = 0.3
	sn.position.x = mid
	pl.reset_at(Vector2(mid + 100.0, 13 * TILE))
	pl.invuln = 1000.0
	var stuck := false
	for i in int(3.0 / DT):
		_step(w, 1)
		if sn.state == "stuck":
			stuck = true
			break
	_check(stuck and sn.solid(), "a slam leaves his pole stuck, and him solid")
	_check(not sn.touch_damage(), "hunched over it, his touch is harmless")
	# Snuff the Light: he caps a brazier; a blow stops him.
	sn.state = "drift"
	sn.timer = 0.0
	sn._move_n = 1
	sn._next(pl)
	_check(sn.state == "snuff_tell" and not sn._target.is_empty(), "Snuff the Light: he picks a brazier")
	var target: Dictionary = sn._target
	for i in int(6.0 / DT):
		_step(w, 1)
		if not target["lit"]:
			break
	_check(not target["lit"], "and caps it")
	w.features.light(target)
	sn.state = "drift"
	sn._move_n = 1
	sn._next(pl)
	for i in int(4.0 / DT):
		_step(w, 1)
		if sn.state == "glide" or sn.state == "cap":
			break
	res = w.deal(sn, 1.0, {"how": "slash", "from_x": sn.position.x - 30.0})
	_check(res["hit"] and sn.state == "recoil" and target["lit"], "a blow while he goes for it stops him")
	# Phase 2 at 60% (a Gutter Call), phase 3 at 25%: Lights Out.
	sn.state = "stuck"
	sn.timer = 99.0
	w.deal(sn, 1.0, {"how": "slash", "flat": 99999.0})
	_check(sn.phase == 2 and absf(sn.hp - 0.6 * sn.max_hp) < 1.0, "a blow stops at the 60% line and starts phase 2")
	_step(w, int(1.3 / DT))
	_check(sn.state == "call", "then he calls the moths")
	_step(w, int(1.2 / DT))
	var wings: Array = sn._wings.duplicate()
	_check(wings.size() == 2, "two Gutterwings come")
	var dark: Dictionary = w.features.braziers()[0]
	w.features.snuff_brazier(dark)
	var lit_before: int = w.lights_tagged("brazier").size()
	if wings.size() > 0:
		w.deal(wings[0], 1.0, {"how": "slash", "flat": 9999.0})
	_check(w.lights_tagged("brazier").size() == lit_before + 1, "killing one relights a brazier")
	sn.state = "stuck"
	sn.timer = 99.0
	w.deal(sn, 1.0, {"how": "slash", "flat": 99999.0})
	_check(sn.phase == 3 and sn.state == "lights_out", "at 25%: Lights Out")
	_step(w, int(1.4 / DT))
	_check(w.lights_tagged("brazier").is_empty() and w.features.braziers_locked, "every brazier goes out for good")
	w.features.light(w.features.braziers()[0])
	_check(w.lights_tagged("brazier").is_empty(), "and can't be relit")
	# Now he is solid only inside Wick's own light.
	sn.state = "recoil"
	sn.timer = 99.0
	pl.hp = pl.max_hp
	var r: float = w.hero_light_radius()
	pl.reset_at(Vector2(mid, 13 * TILE))
	pl.invuln = 1000.0
	sn.position.x = mid + r * 0.5
	_step(w, 2)
	_check(sn.solid(), "in Lights Out he's solid inside Wick's light (r %.0f)" % r)
	sn.position.x = mid + r + 60.0
	_step(w, 2)
	_check(not sn.solid(), "and hollow outside it")
	pl.hp = pl.max_hp * 0.2
	var r_low: float = w.hero_light_radius()
	sn.position.x = mid + (r + r_low) * 0.5
	_step(w, 2)
	_check(r_low < r and not sn.solid(), "a dimmer flame shrinks where he can be hit (%.0f)" % r_low)
	_check(sn._mercy, "and brings the mercy wax stub")
	# Lunge: jump it.
	sn.state = "drift"
	sn._move_n = 1
	sn._next(pl)
	_check(sn.state == "lunge_draw" or sn.state == "track", "phase 3: the Lunge and the slam take turns")
	sn._move_n = 0
	sn._next(pl)
	_check(sn.state == "lunge_draw", "phase 3: the Lunge")
	# The bell comes when he falls.
	sn.state = "stuck"
	sn.timer = 99.0
	w.deal(sn, 1.0, {"how": "slash", "flat": 99999.0})
	_check(not sn.alive, "he falls")
	for i in int(2.5 / DT):
		w.tick(DT)
	_check(w.bells.size() == 1, "and the bell comes")
	var loot := 0
	for p in w.pickups:
		if p["kind"] == "item" or p["kind"] == "relic":
			loot += 1
	_check(loot >= 3, "with his hoard (%d)" % loot)
	_check(w.lights_tagged("brazier").size() == 4, "and the braziers catch again")
	await _done(w)
	# A snuff mid-fight: he sleeps, the braziers come back, the door opens.
	w = await _snuffer_world()
	pl = w.player
	sn = w.boss
	sn.active = true
	pl.reset_at(Vector2(sn.arena_left + 80.0, 13 * TILE))
	_step(w, 20)
	for b in w.features.braziers():
		w.features.snuff_brazier(b)
	sn.hp = sn.max_hp * 0.5
	pl.invuln = 0.0
	pl.take_damage(99999.0, pl.position.x + 5.0)
	for i in int(2.0 / DT):
		w.tick(DT)
	var open := true
	for c in sn.door:
		open = open and not LevelData.is_solid(w.level.tile(c.x, c.y))
	_check(sn.state == "sleep" and sn.hp == sn.max_hp, "a snuff puts him back to sleep at full life")
	_check(open, "and opens the door")
	_check(w.lights_tagged("brazier").size() == 2 and not w.features.braziers_locked, "and puts his braziers back as they were")
	await _done(w)


func _choir_drips(w: Node2D) -> Array:
	return w.hazards.filter(func(h): return h.get("choir", false))


func _test_choir() -> void:
	## The Drip Choir's drips swell inside the view (at the roof, or at the
	## view's top when the roof is out of sight), in lanes with clear floor
	## between; they fall and douse. Checked in the test arena (whose roof is
	## high) and in the real 2-4.
	for where in ["test arena", "2-4"]:
		var w: Node2D
		if where == "test arena":
			w = await _snuffer_world()
		else:
			w = await _level_world("2-4")
		var pl: Node2D = w.player
		var sn: Node2D = w.boss
		sn.active = true
		var mid: float = (sn.arena_left + sn.arena_right) * 0.5
		pl.reset_at(Vector2(mid - 40.0, 13 * TILE))
		pl.invuln = 1000.0
		_step(w, int(1.6 / DT))
		sn.phase = 2
		sn.state = "drift"
		sn._move_n = 1
		sn._call_pending = false
		w.hazards.clear()
		sn._next(pl)
		var drips := _choir_drips(w)
		_check(sn.state == "choir" and drips.size() == 6, "%s: the Drip Choir makes six drips (%d)" % [where, drips.size()])
		var view: Rect2 = w.view_rect()
		var seen := true
		var xs := []
		for h in drips:
			var r: Rect2 = h["rect"]
			seen = seen and r.position.y >= view.position.y + 2.0 and r.position.y >= sn._ceiling_at(r.get_center().x)
			xs.append(r.get_center().x)
		_check(seen, "%s: every drip swells inside the view (view top %.0f)" % [where, view.position.y])
		xs.sort()
		var lanes := true
		for i in range(1, xs.size()):
			lanes = lanes and xs[i] - xs[i - 1] >= 5 * TILE - 1.0
		_check(lanes, "%s: with four clear tiles between them" % where)
		# Under one: it lands on him and douses (the Snuffer waits across the room).
		sn.position.x = sn.arena_right - 60.0 if xs[2] < mid else sn.arena_left + 60.0
		sn.timer = 99.0
		pl.reset_at(Vector2(xs[2], 13 * TILE))
		pl.invuln = 0.0
		pl.hp = pl.max_hp
		_until(w, func(): return pl.has_status("douse"), 2.0)
		_check(pl.has_status("douse"), "%s: a Choir drip douses" % where)
		_until(w, func(): return _choir_drips(w).is_empty(), 3.0)
		_check(_choir_drips(w).is_empty(), "%s: and they're gone once they land" % where)
		await _done(w)


# ---------------------------------------------------------------- the table

func _rush(w: Node2D, e: Node2D) -> Dictionary:
	return w.deal(e, 1.2, {"how": "skill", "from_x": w.player.position.x, "heavy": true})


func _peal(w: Node2D, from_x: float, dir: float) -> void:
	w.add_hazard({"kind": "wave", "owner": "player", "motion": "floor", "rect": Rect2(from_x - 9.0, 13 * TILE - 22.0, 18.0, 22.0),
			"vel": Vector2(dir * 260.0, 0.0), "life": 1.0, "coef": 1.2})


func _shot(w: Node2D, kind: String, from: Vector2, to: Vector2) -> Dictionary:
	var d := (to - from).normalized()
	var opts := {"kind": kind, "owner": "player", "pos": from, "vel": d * (560.0 if kind == "knife" else 240.0),
			"life": 1.5, "coef": 1.0 if kind == "knife" else 0.45, "cancels": kind == "knife"}
	if kind == "mote":
		opts["homing"] = 6.0
	return w.spawn_shot(opts)


func _test_table() -> void:
	var w := await _world(_rows(70))
	var pl: Node2D = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	pl.facing = 1
	# --- Hollow Helm, front
	var helm := _spawn(w, "hollow_helm", Vector2i(14, 12), {"facing": -1})
	_step(w, 2)
	var hp0: float = helm.hp
	_check(not _rush(w, helm)["hit"] and helm.hp == hp0, "table: Rush vs Helm front: blocked")
	_peal(w, pl.position.x + 20.0, 1.0)
	_step(w, 40)
	_check(helm.hp == hp0, "table: Peal vs Helm front: blocked")
	w.add_light(helm.center(), 160.0, 0.9, 1.0, "beacon")
	_step(w, 2)
	_check(helm.hp == hp0 and helm.shielded(), "table: Beacon vs Helm: nothing")
	_shot(w, "knife", pl.center(), helm.center())
	_step(w, 30)
	_check(helm.hp == hp0, "table: knife vs Helm front: stopped")
	_shot(w, "mote", pl.center(), helm.center())
	_step(w, 60)
	_check(helm.hp == hp0, "table: mote vs Helm front: stopped")
	helm.alive = false
	helm.gone = true
	_step(w, 2)
	# --- Gutterwing, latched
	var wing := _latched_wing(w)
	_press(w, "special")
	_step(w, 2)
	_check(wing.state != "latch", "table: a Special (Rush) pops a latched Gutterwing")
	wing = _latched_wing(w)
	_check(_rush(w, wing)["hit"] and not wing.alive, "table: and the Rush's blow kills it")
	wing = _latched_wing(w)
	_peal(w, pl.position.x - 30.0, 1.0)
	_step(w, 30)
	_check(wing.alive and wing.state == "latch", "table: Peal can't reach a latched moth")
	w.add_light(pl.center() + Vector2(0, -60), 160.0, 0.9, 2.0, "beacon")
	_step(w, 20)
	_check(wing.state == "latch", "table: a Beacon doesn't pull a latched moth off")
	_press(w, "attack")
	_step(w, 2)
	_check(wing.state != "latch", "table: a knife throw (an attack) pops it")
	wing = _latched_wing(w)
	var kk: Dictionary = _shot(w, "knife", wing.position + Vector2(-60, 0), wing.position)
	kk["coef"] = 1.5
	_step(w, 20)
	_check(not wing.alive, "table: a knife that hits it kills it")
	wing = _latched_wing(w)
	var s: Dictionary = _shot(w, "mote", wing.position + Vector2(-50, 0), wing.position)
	s["coef"] = 0.01
	_step(w, 30)
	_check(wing.state != "latch", "table: a mote knocks it off")
	for e in w.enemies:
		if e.kind == "gutterwing":
			e.alive = false
			e.gone = true
	_step(w, 2)
	await _done(w)
	# --- The Snuffer, hollow
	w = await _snuffer_world()
	pl = w.player
	var sn: Node2D = w.boss
	sn.active = true
	pl.reset_at(Vector2(sn.arena_left + 80.0, 13 * TILE))
	pl.invuln = 1000.0
	_step(w, 5)
	var mid: float = (sn.arena_left + sn.arena_right) * 0.5
	var hollow := func():
		sn.position.x = mid
		sn.state = "recoil"
		sn.timer = 99.0
		sn.solid_t = 0.0
		pl.reset_at(Vector2(mid - 90.0, 13 * TILE))
		pl.invuln = 1000.0
		pl.facing = 1
		_step(w, 2)
	hollow.call()
	hp0 = sn.hp
	_check(not _rush(w, sn)["hit"] and sn.hp == hp0, "table: Rush vs hollow Snuffer: passes through")
	_peal(w, mid - 70.0, 1.0)
	_step(w, 30)
	_check(sn.hp == hp0, "table: Peal vs hollow Snuffer: passes through")
	var kn: Dictionary = _shot(w, "knife", sn.center() + Vector2(-70, 0), sn.center() + Vector2(70, 0))
	_step(w, 20)
	_check(sn.hp == hp0 and kn["pos"].x > sn.center().x + 20.0, "table: knife vs hollow Snuffer: flies through")
	hollow.call()
	_shot(w, "mote", sn.center() + Vector2(-60, 0), sn.center())
	_step(w, 40)
	_check(sn.hp == hp0, "table: mote vs hollow Snuffer: flies through")
	hollow.call()
	var bid: int = w.add_light(sn.center() + Vector2(30, 0), 160.0, 0.9, 6.0, "beacon")
	_step(w, 2)
	_check(sn.solid() and _rush(w, sn)["hit"], "table: a Beacon makes him solid")
	w.remove_light(bid)
	await _done(w)
	# --- Warded motes
	w = await _world(_rows(70))
	pl = w.player
	_settle(w, Vector2(10 * TILE, 13 * TILE))
	pl.invuln = 1000.0
	pl.facing = 1
	var wd := _spawn(w, "skeleton", Vector2i(14, 12), {"tier": "anointed", "omens": ["Warded"], "facing": -1})
	_step(w, 2)
	hp0 = wd.hp
	_check(not _rush(w, wd)["hit"] and wd.motes_up() == 2 and wd.hp == hp0, "table: Rush vs Warded: takes a mote, 0 damage")
	_peal(w, pl.position.x + 20.0, 1.0)
	_step(w, 40)
	_check(wd.motes_up() == 1 and wd.hp == hp0, "table: Peal vs Warded: takes a mote")
	w.add_light(wd.center(), 160.0, 0.9, 1.0, "beacon")
	_step(w, 2)
	_check(wd.motes_up() == 1, "table: Beacon vs Warded: nothing")
	var k2: Dictionary = _shot(w, "knife", pl.center(), wd.center())
	_until(w, func(): return k2["life"] <= 0.0, 1.0)
	_check(wd.motes_up() == 0 and wd.hp == hp0 and k2["life"] <= 0.0, "table: knife vs Warded: takes a mote, the knife stops")
	_step(w, int(4.2 / DT))
	var up: int = wd.motes_up()
	var m2: Dictionary = _shot(w, "mote", pl.center(), wd.center())
	_until(w, func(): return m2["life"] <= 0.0, 2.0)
	_check(wd.motes_up() == up - 1 and wd.hp == hp0, "table: mote vs Warded: takes a mote")
	wd.alive = false
	wd.gone = true
	# --- Thornback, flipped: everything lands x1.25.
	var ratios := {}
	for how in ["rush", "peal", "knife", "mote"]:
		var got := []
		for flip in [false, true]:
			var th := _spawn(w, "thornback", Vector2i(16, 12), {"facing": -1})
			th.max_hp = 9999.0
			th.hp = 9999.0
			if flip:
				th.apply_status("flipped", 5.0)
			pl.reset_at(Vector2(12 * TILE, 13 * TILE))
			pl.invuln = 1000.0
			w.shots.clear()
			w.hazards.clear()
			_step(w, 2)
			w.rng.seed = 42
			pl.stats["crit"] = 0.0
			match how:
				"rush":
					_rush(w, th)
				"peal":
					_peal(w, pl.position.x + 20.0, 1.0)
				"knife":
					_shot(w, "knife", pl.center(), th.center())
				"mote":
					_shot(w, "mote", pl.center(), th.center())
			_until(w, func(): return th.hp < 9999.0, 1.5)
			got.append(9999.0 - th.hp)
			th.alive = false
			th.gone = true
			_step(w, 2)
		ratios[how] = got[1] / maxf(got[0], 0.01)
		_check(got[0] > 0.0 and absf(ratios[how] - 1.25) < 0.12, "table: %s vs flipped Thornback lands x1.25 (%.2f)" % [how, ratios[how]])
	var thb := _spawn(w, "thornback", Vector2i(16, 12))
	thb.apply_status("flipped", 5.0)
	w.add_light(thb.center(), 160.0, 0.9, 1.0, "beacon")
	_step(w, 2)
	_check(thb.hp == thb.max_hp and thb.flipped(), "table: Beacon vs flipped Thornback: nothing")
	await _done(w)


func _latched_wing(w: Node2D) -> Node2D:
	var pl: Node2D = w.player
	var wing := _spawn(w, "gutterwing", Vector2i(int(pl.position.x / TILE), 8))
	wing.position = wing.flame_point()
	wing._base = wing.position
	_step(w, 3)
	return wing


# ---------------------------------------------------------------- the levels

func _test_level_rules() -> void:
	var EK = load("res://scripts/enemy_kinds.gd")
	for info in game.LEVELS:
		var lv = LevelData.load_file(info["path"])
		var altars := []
		for e in lv.entities:
			if e["kind"] == "altar":
				altars.append(e["cell"].x)
			if e["kind"] == "dread":
				# A Dread stands where its kind can: a Dripkin under a ceiling,
				# a walker over a floor, a flier in the air.
				var c: Vector2i = e["cell"]
				var spawn: String = EK.KINDS[lv.dread["kind"]]["spawn"]
				if spawn == "ceiling":
					_check(LevelData.is_solid(lv.tile(c.x, c.y - 1)), "%s: its Dread hangs from a ceiling" % lv.id)
				elif spawn == "floor":
					var y := c.y + 1
					while y < lv.height and not LevelData.is_solid(lv.tile(c.x, y)) and not LevelData.is_ledge(lv.tile(c.x, y)):
						y += 1
					_check(y < lv.height and y - c.y <= 3, "%s: its Dread stands on a floor" % lv.id)
		altars.sort()
		_check(not lv.dread.is_empty() or lv.boss != "", "%s has a Dread (or a boss)" % lv.id)
		_check(lv.story.has("start"), "%s keeps its story header" % lv.id)
		if lv.id in ["1-2", "1-3"]:
			_check(altars.size() >= 2, "%s has a second altar" % lv.id)
		if lv.id.begins_with("2-") and lv.boss == "":
			# Along the route (a taller level's on foot: level_rules.gd
			# checkpoint_gaps; with roads, each road's).
			var gaps: Dictionary = Rules.checkpoint_gaps(lv)
			var ok := true
			for gap in gaps["gaps"]:
				if int(gap) > 90:
					ok = false
			_check(ok, "%s: an altar every 90 tiles or less (%s)" % [lv.id, gaps])
		if lv.boss != "":
			# From the boss's own cell, as world.gd finds the arena (the Hush
			# stands on row 10, the Saint mid-nave): the door is its two
			# columns left of the wall (WL6's request, via MA's file).
			var bc := Vector2i(0, 12)
			for e in lv.entities:
				if e["kind"] == "boss":
					bc = e["cell"]
			var a = preload("res://scripts/boss_arena.gd").find(lv, LevelData.cell_floor(bc))
			var door_x: int = int(a["left"]) / TILE
			for dc in a["door"]:
				door_x = mini(door_x, (dc as Vector2i).x)
			_check(not altars.is_empty() and door_x - altars[altars.size() - 1] <= 8, "%s: an altar right at the arena door" % lv.id)
		if lv.id.begins_with("2-"):
			var lurks: int = lv.count("lidlurk")
			var false_stone := 0
			for t in lv.tiles:
				if t == LevelData.FALSE_STONE:
					false_stone += 1
			_check(lurks >= 1 and false_stone >= 2, "%s has a Lidlurk and a false-stone secret" % lv.id)
	# The Snuffer's arena: four braziers, and its pools lie on the floor.
	var u = LevelData.load_file("res://levels/2-4.txt")
	var pools_ok := true
	var pools := 0
	for y in u.height:
		for x in u.width:
			if u.tile(x, y) == LevelData.WATER:
				pools += 1
				if not LevelData.is_solid(u.tile(x, y + 1)):
					pools_ok = false
	_check(pools > 0 and pools_ok, "2-4's pools are shallow, over solid floor (not trenches)")
	_check(u.count("lantern") >= 4 and u.boss == "snuffer", "2-4's arena has the Snuffer and his braziers")


func _test_tutorial_signs() -> void:
	## 1-1 teaches the v2 verbs, not just v1's. Past the jump sign (the
	## arrows on screen teach the run since the sign cut) and before the
	## first skeleton stands the Special's sign: its hint is
	## {special_tip}, which the World fills with the calling's own line
	## (classes.gd "sign_tip", written round the button's icon, since the
	## player never learns the button is called Aegis). Just before the
	## first altar stands the flask's sign (a drink is a hold, and altars
	## refill it). In every level the signs stand 4 tiles apart or more, so
	## each hint shows on its own (a sign shows within world.SIGN_REACH,
	## 64 px, so two signs' reach never overlaps), there are no more than
	## the sign budget allows (tools/levels/common.py: 1-1 four, any other
	## level three, the feel labs free), and every
	## hint, filled for every calling, fits the phone's message slot at
	## 13 px or more (the HUD shrinks a long one from 15 down to 11).
	var EK = load("res://scripts/enemy_kinds.gd")
	var Classes = load("res://scripts/classes.gd")
	var UI = load("res://scripts/ui.gd")
	var lv = LevelData.load_file("res://levels/1-1.txt")
	var signs := []   # [x, hint], left to right
	var skel := 1 << 20
	var altar := 1 << 20
	for e in lv.entities:
		var x: int = e["cell"].x
		match str(e["kind"]):
			"sign":
				signs.append([x, str(e["text"])])
			"skeleton":
				skel = mini(skel, x)
			"altar":
				altar = mini(altar, x)
	signs.sort_custom(func(a, b): return a[0] < b[0])
	var at := {}   # a word in a hint -> that sign's x
	for s in signs:
		for word in ["to jump", "{special_tip}", "flask"]:
			if (s[1] as String).contains(word) and not at.has(word):
				at[word] = s[0]
	var jump_x: int = at.get("to jump", -1)
	var special_x: int = at.get("{special_tip}", -1)
	_check(jump_x >= 0 and special_x > jump_x and special_x < skel,
			"1-1: the Special's sign stands past the jump sign, before the first skeleton (%d, %d < %d)" % [jump_x, special_x, skel])
	var flask_x: int = at.get("flask", -1)
	var flask_hint := ""
	for s in signs:
		if s[0] == flask_x:
			flask_hint = s[1]
	var between := 0
	for e in lv.entities:
		if EK.KINDS.has(e["kind"]) and e["cell"].x > flask_x and e["cell"].x < altar:
			between += 1
	_check(flask_x >= 0 and flask_x < altar and altar - flask_x <= 12 and between == 0,
			"1-1: the flask's sign stands just before the first altar, nothing between (%d, altar %d)" % [flask_x, altar])
	_check(flask_hint.contains("Hold") and flask_hint.contains("refill"), "1-1: it says the flask is a hold and altars refill it ('%s')" % flask_hint)
	# Every level: signs 4 tiles apart or more on the same floor, and within
	# the budget.
	var close := []
	var over := []
	for info in game.LEVELS:
		var l = LevelData.load_file(info["path"])
		var cells := []
		for e in l.entities:
			if e["kind"] == "sign":
				cells.append(e["cell"])
		if not str(l.id).begins_with("lab-") and cells.size() > (4 if str(l.id) == "1-1" else 3):
			over.append("%s %d" % [l.id, cells.size()])
		cells.sort()
		for i in range(1, cells.size()):
			var a: Vector2i = cells[i - 1]
			var b: Vector2i = cells[i]
			if b.x - a.x < 4 and absi(b.y - a.y) < 2:
				close.append("%s %s-%s" % [l.id, a, b])
	_check(close.is_empty(), "every level's signs stand 4 tiles apart or more %s" % [close])
	_check(over.is_empty(), "every level keeps the sign budget (1-1 four, else three) %s" % [over])
	# Filled for every calling, as the World shows them, on the phone.
	var was := root.size
	root.size = Vector2i(844, 390)
	root.content_scale_size = Vector2i(844, 390)
	UI.safe_override = UI.phone_safe(Vector2(844, 390))
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	await process_frame
	var room: float = hud.msg_rect(10000.0).size.x - 24.0
	hud.queue_free()
	var landed: bool = Classes.info("knight").has("sign_tip")
	var unfilled := []
	var wide := []
	var tips := {}
	var hints: Array = []
	for info in game.LEVELS:
		if info["id"] != "1-1":
			hints.append_array(Array(LevelData.load_file(info["path"]).hints))
	for cls in Classes.ORDER:
		game.reset()
		game.data["difficulty"] = "dusk"
		game.new_hero(cls)
		var w: Node2D = WorldScript.new()
		w.setup(LevelData.load_file("res://levels/1-1.txt"), true)
		root.add_child(w)
		await process_frame
		_check(w.signs.size() == signs.size(), "1-1 for %s: every sign built" % cls)
		for s in w.signs:
			var t: String = s["text"]
			if s["pos"].x < (special_x + 1) * TILE and s["pos"].x >= special_x * TILE:
				tips[cls] = t
			if not landed and t == "{special_tip}":
				continue
			if t.contains("{") or t.contains("}"):
				unfilled.append("%s: %s" % [cls, t])
			hints.append(t)
		await _done(w)
	for t in hints:
		if UI.text_width(t, 13) > room:
			wide.append(t)
	UI.safe_override = Rect2()
	root.size = was
	root.content_scale_size = was
	_check(unfilled.is_empty(), "1-1's hints leave no {name} unfilled, for any calling %s" % [unfilled])
	_check(wide.is_empty() and room > 300.0, "every hint fits the phone's message slot (%.0f px) at 13 px %s" % [room, wide])
	if landed:
		var seen := {}
		for cls in tips:
			seen[tips[cls]] = true
		_check(tips.size() == Classes.ORDER.size() and seen.size() == tips.size(),
				"the Special's sign says each calling's own line %s" % [tips])
	else:
		print("  (the Special's sign shows {special_tip} until classes.gd gains sign_tip and world.gd fills it)")


func _test_sign_reading() -> void:
	## A sign reads from SIGN_REACH (64 px) either side of its post, not v2's
	## 44, and its text stays in the HUD's slot SIGN_LINGER (2 s) after he
	## walks on, then fades as before (show_hint and _hint_alpha), so it
	## reads on the run. The next sign's text takes over at once. Each
	## board's painted flame glints until he has stood by it once this visit;
	## nothing is saved, so the next visit's boards glint again.
	# (A phone's view for the HUDs below: headless the root has no size, and
	# the HUD's see-through areas came out with negative sizes every frame.)
	var was := root.size
	root.size = Vector2i(844, 390)
	root.content_scale_size = Vector2i(844, 390)
	var SignView = load("res://scripts/sign_view.gd")
	var rows := _rows(60, {Vector2i(20, 12): "@", Vector2i(26, 12): "@"})
	var w := await _world(rows, "hints: First board|Second board\n")
	var hud = load("res://scripts/hud.gd").new()
	hud.world = w
	hud.story = null
	hud._story_checked = true
	w.hud = hud
	w.add_child(hud)
	await process_frame
	_check(WorldScript.SIGN_REACH == 64.0 and WorldScript.SIGN_LINGER == 2.0, "a sign reads from 64 px and lingers 2 s")
	_check(w.signs.size() == 2, "(both signs built: %d)" % w.signs.size())
	var a: Node2D = w.signs[0]["node"]
	var b: Node2D = w.signs[1]["node"]
	_check(a.glinting() and b.glinting(), "a board not yet read glints")
	_check(SignView.glint_at(SignView.GLINT_LEN * 0.5) > 0.9 and SignView.glint_at(SignView.GLINT_LEN + 0.1) == 0.0
			and SignView.glint_at(SignView.GLINT_EVERY + SignView.GLINT_LEN * 0.5) > 0.9, "its glint comes and goes every %.1f s" % SignView.GLINT_EVERY)
	var floor_y: float = w.signs[0]["pos"].y
	var ax: float = w.signs[0]["pos"].x
	var bx: float = w.signs[1]["pos"].x
	var saved := var_to_str(game.data)
	# 54 px short of the first sign: past v2's 44, inside the 64.
	w.player.position = Vector2(ax - 54.0, floor_y)
	w.player.velocity = Vector2.ZERO
	_step(w, 1)
	_check(hud._hint_on and hud._hint == "First board", "54 px from a sign its text is up (%s '%s')" % [hud._hint_on, hud._hint])
	_check(not a.glinting() and a.read and b.glinting(), "the board he stood by stops glinting; the other still glints")
	# Walked on, 100 px past it: the text stays 2 s, then goes.
	w.player.position = Vector2(ax + 100.0, floor_y)
	_step(w, int(1.9 / DT))
	_check(hud._hint_on and hud._hint == "First board", "1.9 s after he walks on, it is still up")
	_step(w, int(0.2 / DT))
	_check(not hud._hint_on, "2.1 s after, it goes")
	for i in 30:
		hud._process(1.0 / 60.0)
	_check(hud._hint_alpha == 0.0 and hud._hint == "", "and fades out as before (alpha %.2f)" % hud._hint_alpha)
	# Lingering, the next sign takes over at once.
	w.player.position = Vector2(ax, floor_y)
	_step(w, 1)
	w.player.position = Vector2(bx - 60.0, floor_y)
	_step(w, 1)
	_check(hud._hint == "Second board" and b.read, "the next sign's text replaces a lingering one at once")
	_check(var_to_str(game.data) == saved, "reading the signs writes nothing to the save")
	await _done(w)
	# A new visit: its boards glint again.
	var w2 := await _world(rows, "hints: First board|Second board\n")
	_check(w2.signs.size() == 2 and w2.signs[0]["node"].glinting() and w2.signs[1]["node"].glinting(), "the next visit's boards glint again")
	await _done(w2)
	# A level's first sign, a few tiles from the start, under its 2.8 s title
	# card: held right from the first frame, its text still reads SIGN_LINGER
	# s once the card is gone (the linger waits while the slot can't draw).
	var w3 := await _world(_rows(60, {Vector2i(7, 12): "@"}), "hints: Wax-ice is slick\n")
	var hud3 = load("res://scripts/hud.gd").new()
	hud3.world = w3
	hud3.story = null
	hud3._story_checked = true
	w3.hud = hud3
	w3.add_child(hud3)
	await process_frame
	hud3.title_card("t", "t")
	var drawn := 0.0
	var titled := 0.0
	for i in int(6.0 / DT):
		_step(w3, 1, {"right": true})
		hud3._process(DT)
		if hud3.slot_blocked():
			titled += DT
		elif hud3._hint == "Wax-ice is slick" and hud3._hint_alpha > 0.0 and hud3._msg.is_empty():
			drawn += DT
	_check(titled >= 2.5 and w3.player.position.x > w3.signs[0]["pos"].x + 200.0, "(the title card held the slot %.1f s, and he ran on past the sign)" % titled)
	_check(drawn >= 1.9, "the first sign's text still shows %.1f s after the title card (it ran out under it before)" % drawn)
	await _done(w3)
	# The same first sign with messages queued under the title (3-1: the
	# beat's barks and first_vine wait for its card): they take the slot
	# first, the sign's text never flashes up for the frame between the card
	# and them (hud.hint_held), and its SIGN_LINGER s wait for them too, so it
	# reads once, in full, after them (it ran out under them before).
	var w4 := await _world(_rows(60, {Vector2i(7, 12): "@"}), "hints: Wax-ice is slick\n")
	var hud4 = load("res://scripts/hud.gd").new()
	hud4.world = w4
	hud4.story = null
	hud4._story_checked = true
	w4.hud = hud4
	w4.add_child(hud4)
	await process_frame
	hud4.title_card("t", "t")
	var stretches := []   # the length of each stretch the sign's text draws
	var was_on := false
	var msg_time := 0.0
	var sx: float = w4.signs[0]["pos"].x
	for i in int(14.0 / DT):
		_step(w4, 1, {"right": true} if w4.player.position.x < sx + 200.0 else {})
		if i == int(1.0 / DT):
			hud4.toast("A first note under the title", "and its line")
			hud4.toast("A second note", "behind it")
		hud4._process(DT)
		if not hud4._msg.is_empty():
			msg_time += DT
		var on: bool = hud4._hint == "Wax-ice is slick" and hud4.hint_showing()
		if on and not was_on:
			stretches.append(0.0)
		if on:
			stretches[-1] += DT
		was_on = on
	_check(msg_time >= 4.5 and w4.player.position.x > sx + 150.0, "(the notes held the slot %.1f s after the card, and he ran on past the sign)" % msg_time)
	_check(stretches.size() == 1 and float(stretches[0]) >= 1.9,
			"the first sign's text shows once, in full, after the notes queued under the title: no lone frame before them %s" % [stretches])
	await _done(w4)
	await _test_31_vine_sign()
	root.size = was
	root.content_scale_size = was


func _test_31_vine_sign() -> void:
	## 3-1's one control sign stands by the first vine, under the level's
	## title card; first_vine and beat_3_1's two barks queue behind the card.
	## Run right from the start, its text still reads SIGN_LINGER s once
	## they're done, and it names the climb as the thumb tip's card does
	## (world.TIPS "tip:climb": "Slide up to climb"), not a third way.
	var Cutscene = load("res://scripts/cutscene.gd")
	var Story = load("res://scripts/story.gd")
	var w := await _level_world("3-1")
	var hud = load("res://scripts/hud.gd").new()
	hud.world = w
	w.hud = hud
	w.add_child(hud)
	await process_frame
	var vine_sign := ""
	for s in w.signs:
		if str(s["text"]).begins_with("On a vine"):
			vine_sign = str(s["text"])
	var climb: String = str(WorldScript.TIPS["tip:climb"][0]).to_lower()
	_check(vine_sign.to_lower().contains(climb), "3-1's vine sign names the climb as the tip card does ('%s' in '%s')" % [climb, vine_sign])
	hud.title_card("Act", str(w.level.title))
	# (as cutscene.gd plays the beat: an overlay with no shots queues its barks)
	var beat: Dictionary = Story.scene("beat_3_1")
	Cutscene.queue_barks(w, beat["barks"], float(beat["bark_delay"]))
	var heard := {}
	var drawn := 0.0
	for i in int(20.0 / DT):
		_step(w, 1, {"right": true})
		hud._process(DT)
		for c in w.get_children():
			if c.name == "StoryBarks":
				c.step(DT)
		if not hud._msg.is_empty():
			heard[str(hud._msg.get("key", ""))] = true
		if hud._hint == vine_sign and hud.hint_showing():
			drawn += DT
	_check(heard.has("bark:first_vine") and heard.has("bark:beat_3_1_a") and heard.has("bark:beat_3_1_b"),
			"(first_vine and beat_3_1's barks took the slot after the card: %s)" % [heard.keys()])
	_check(drawn >= 1.9, "3-1: run on from the start, the vine sign still reads %.1f s after the title and the barks (0.01 s before)" % drawn)
	await _done(w)


func _test_hang_heights() -> void:
	## The camera shows about 7 rows above the floor Waxby stands on, so
	## every Dripkin (and Dripkin Dread) and drip spout hangs within 7 rows
	## of the floor below it: its tell plays on screen. A Dripkin lands on
	## the first thing it can stand on (a moving ledge's lane counts); a
	## spout's drop falls through ledges, so for a spout that's the stone
	## below, or over a pit the lowest ledge.
	for info in game.LEVELS:
		var lv = LevelData.load_file(info["path"])
		var st = _static_copy(lv)
		var n := 0
		var bad := []
		for e in lv.entities:
			var k: String = e["kind"]
			if k == "dread" and str(lv.dread.get("kind", "")) == "dripkin":
				k = "dripkin"
			if k != "dripkin" and k != "drip":
				continue
			n += 1
			var c: Vector2i = e["cell"]
			var stand := -1
			for y in range(c.y + 1, lv.height):
				var t: int = st.tile(c.x, y)
				if LevelData.is_solid(t):
					stand = y
					break
				if LevelData.is_ledge(t):
					stand = y
					if k == "dripkin":
						break
			if stand < 0 or stand - c.y > 7:
				bad.append("%s at %s (%s)" % [k, c, "no floor" if stand < 0 else "%d rows" % (stand - c.y)])
		if n > 0:
			_check(bad.is_empty(), "%s: all %d drips and Dripkins hang in view of the floor below %s" % [lv.id, n, bad])


# Each World 1 level's star-coin sigil (decisions: one per level, behind a
# tight optional route), the cells its route lands on, and a floor cell to
# start the bot from, before the route's approach.
const STAR_ROUTES := {
	"1-1": {"sigil": 3, "route": [Vector2i(264, 7), Vector2i(268, 5)], "from": Vector2i(241, 12),
			"what": "two lone stones past the bell stair"},
	"1-2": {"sigil": 2, "route": [Vector2i(110, 11), Vector2i(111, 11), Vector2i(116, 11), Vector2i(117, 11), Vector2i(121, 11), Vector2i(122, 11)],
			"from": Vector2i(101, 15), "what": "crumbling slabs under a spiked ceiling"},
	"1-3": {"sigil": 1, "route": [Vector2i(69, 14)], "from": Vector2i(55, 21), "what": "a lone post high over the lava"},
	"1-4": {"sigil": 1, "route": [Vector2i(18, 7), Vector2i(22, 5)], "from": Vector2i(3, 12),
			"what": "two lone stones up the tower, a bat between"},
}


func _test_star_routes() -> void:
	## Every World 1 level names its star sigil. The bot reaches it; with the
	## route's landings taken away it can't (so the route is the only way);
	## and every landing is tight: a lone one-tile stone or a crumbling slab.
	for info in game.LEVELS:
		if info["world"] != 1:
			continue
		var id: String = info["id"]
		_check(STAR_ROUTES.has(id), "%s names its star-coin sigil" % id)
		if not STAR_ROUTES.has(id):
			continue
		var sr: Dictionary = STAR_ROUTES[id]
		var lv = LevelData.load_file(info["path"])
		var goal := "sigil %d" % int(sr["sigil"])
		var tight := true
		for c in sr["route"]:
			var t: int = lv.tile(c.x, c.y)
			var lone: bool = LevelData.is_solid(t) and not LevelData.is_solid(lv.tile(c.x - 1, c.y)) and not LevelData.is_solid(lv.tile(c.x + 1, c.y)) \
					and not LevelData.is_solid(lv.tile(c.x, c.y - 1))
			tight = tight and (lone or t == LevelData.CRUMBLE)
		_check(tight, "%s: the star route's landings are tight (%s)" % [id, sr["what"]])
		# The bot runs on the stretch of level from "from" to past the route,
		# breakables open.
		var from: Vector2i = sr["from"]
		var x0 := from.x
		var x1 := from.x
		for c in sr["route"]:
			x0 = mini(x0, c.x)
			x1 = maxi(x1, c.x)
		for e in lv.entities:
			if e["kind"] == "sigil" and int(e["index"]) + 1 == int(sr["sigil"]):
				x0 = mini(x0, e["cell"].x)
				x1 = maxi(x1, e["cell"].x)
		var open = _crop(_static_copy(lv), maxi(x0 - 2, 0), mini(x1 + 12, lv.width), from)
		for i in open.tiles.size():
			if LevelData.is_breakable(open.tiles[i]):
				open.tiles[i] = LevelData.AIR
		_check(_reach(open, [])["found"].has(goal), "%s: the bot reaches the star %s" % [id, goal])
		for c in sr["route"]:
			open.set_tile(c.x - int(open.get_meta("x0")), c.y, LevelData.AIR)
		_check(not _reach(open, [])["found"].has(goal), "%s: and without its route it can't" % id)


func _crop(lv: RefCounted, x0: int, x1: int, from: Vector2i) -> RefCounted:
	## Columns x0..x1-1 of a level as a level of its own, starting at the
	## cell from (its sigils moved along).
	var c = LevelData.new()
	c.width = x1 - x0
	c.height = lv.height
	c.tiles = PackedByteArray()
	c.tiles.resize(c.width * c.height)
	for y in c.height:
		for x in c.width:
			c.tiles[y * c.width + x] = lv.tile(x0 + x, y)
	c.set_meta("x0", x0)
	c.entities = []
	for e in lv.entities:
		if e["kind"] == "sigil" and e["cell"].x >= x0 and e["cell"].x < x1:
			var m: Dictionary = e.duplicate()
			m["cell"] = Vector2i(e["cell"].x - x0, e["cell"].y)
			c.entities.append(m)
	c.start = Vector2i(from.x - x0, from.y)
	return c


# ---------------------------------------------------------------- the bot, waxfalls on

func _test_bot_with_waxfalls() -> void:
	## "Waxfalls assumed off" is enforced: with every column pouring (and
	## counted as hurting), the bot still reaches every bell and sigil.
	for info in game.LEVELS:
		var lv = LevelData.load_file(info["path"])
		var falls := []
		for e in lv.entities:
			if e["kind"] == "waxfall":
				var c: Vector2i = e["cell"]
				var b := c.y + 1
				while b < lv.height and not LevelData.is_solid(lv.tile(c.x, b)):
					b += 1
				falls.append(Rect2((c.x + 0.5) * TILE - 10, c.y * TILE + 14, 20, b * TILE - c.y * TILE - 14))
		if falls.is_empty():
			continue
		var open = _static_copy(lv)
		for i in open.tiles.size():
			if LevelData.is_breakable(open.tiles[i]):
				open.tiles[i] = LevelData.AIR
		var res := _reach(open, falls)
		for g in res["goals"]:
			_check(res["found"].has(g["what"]), "%s with the waxfalls on: the bot reaches the %s" % [lv.id, g["what"]])


func _static_copy(lv: RefCounted) -> RefCounted:
	var c = LevelData.new()
	c.width = lv.width
	c.height = lv.height
	c.tiles = lv.tiles.duplicate()
	c.entities = lv.entities
	c.start = lv.start
	for m in lv.movers:
		var cell: Vector2i = m["cell"]
		var n: int = m["length"]
		if m["axis"] == "x":
			for x in range(cell.x - 3, cell.x + n + 3):
				if c.tile(x, cell.y) == LevelData.AIR:
					c.set_tile(x, cell.y, LevelData.LEDGE)
		else:
			for y in range(cell.y - 3, cell.y + 4):
				for x in range(cell.x, cell.x + n):
					if c.tile(x, y) == LevelData.AIR:
						c.set_tile(x, y, LevelData.LEDGE)
	return c


func _reach(lv: RefCounted, falls: Array) -> Dictionary:
	var goals := []
	for e in lv.entities:
		if e["kind"] == "sigil":
			goals.append({"what": "sigil %d" % (e["index"] + 1), "p": LevelData.cell_center(e["cell"]), "rope": false})
		elif e["kind"] == "bell":
			var f := LevelData.cell_floor(e["cell"])
			goals.append({"what": "bell", "p": f, "rope": true, "rect": Rect2(f.x - 14, f.y - 70, 28, 70)})
	var found := {}
	var start := LevelData.cell_floor(lv.start)
	var seen := {}
	var queue: Array = [start]
	seen[Vector2i(floori(start.x / 16.0), floori(start.y / TILE))] = true
	var p: Node2D = PlayerScript.new()
	p.level = lv
	var actions := []
	for dir in [-1, 1]:
		actions.append({"walk": 0.22, "dir": dir, "jump": false})
		for run in [0.0, 0.3]:
			for hold in [0.12, 0.6]:
				actions.append({"walk": run, "dir": dir, "jump": true, "hold": hold})
	actions.append({"walk": 0.0, "dir": 0, "jump": true, "hold": 0.6})
	while queue.size() > 0 and seen.size() < 4000:
		var at: Vector2 = queue.pop_front()
		for a in actions:
			p.reset_at(at)
			p.on_floor = true
			var t := 0.0
			var left := false
			var ok := true
			var jumped := false
			var jump_t := 0.0
			while t < 2.2:
				var pd := {}
				if a["dir"] < 0:
					pd["left"] = true
				elif a["dir"] > 0:
					pd["right"] = true
				if a["jump"] and t >= a["walk"]:
					if not jumped:
						pd["jump_pressed"] = true
						jumped = true
						jump_t = t
					pd["jump"] = t - jump_t < a["hold"]
				p.pad = pd
				p.step(DT)
				t += DT
				var r: Rect2 = p.rect()
				for g in goals:
					if found.has(g["what"]):
						continue
					if g["rope"]:
						if r.intersects(g["rect"]):
							found[g["what"]] = true
					elif r.grow(6.0).has_point(g["p"]):
						found[g["what"]] = true
				var hurt: bool = p.position.y > lv.height * TILE + 40
				for fr in falls:
					if (fr as Rect2).intersects(r.grow(-2.0)):
						hurt = true
				if not hurt:
					for y in range(floori(r.position.y / TILE), floori((r.end.y - 0.01) / TILE) + 1):
						for x in range(floori(r.position.x / TILE), floori((r.end.x - 0.01) / TILE) + 1):
							if lv.hurts_at(x, y, r):
								hurt = true
				if hurt:
					ok = false
					break
				if not p.on_floor:
					left = true
				elif left or (not a["jump"] and t >= a["walk"]):
					break
			if ok and p.on_floor:
				var k := Vector2i(floori(p.position.x / 16.0), floori(p.position.y / TILE))
				if not seen.has(k):
					seen[k] = true
					queue.append(p.position)
	p.free()
	return {"found": found, "goals": goals}
