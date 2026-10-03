extends SceneTree
## test_classes: the five callings. Physics parity (a calling with quirk ""
## moves exactly like v1 Wick, and each quirk leaves the jump and the run
## alone until it's used); each quirk does its one thing (Ledge Grab,
## Drift, Moth Cling, Stampede, Grave Step); level 1 hits-to-kill stay in
## sane bands; a stomp kills a Rattle for everyone; and each Special does
## what it says (Guard and Perfect Guard, Shield Rush, the Peal's waves, a
## Flare's Beacon, Smoke Step's soot and the backstab after it, the wisps'
## firing window, Toll the Dead's hold, knives cancelling arrows), and the
## holes a review found stay shut: no stairway of bones, no free Knell, no
## Toll from the press that calls the last wisp, no single-wall climb, no
## shield against fire, smoke or a foe overhead.
## Grave Chill roots, then thaws (never a stun-lock); Sealing Wax never slows
## a boss; "of the Keeper" still counts on a root at rank 5.
## Integration: the calling-only Legendary charms (Everburning Taper, Cracked
## Tenor, The Unrung Bell, the Glass of the First Dawn, the Moth-Queen's
## Scale) and Gutterlight's faster swings; the rig wearing
## each calling's real art (no stand-ins), its capes flaring back, weapons
## kept off the face in the air, the Knell's bell swung about plumb, and
## visible gear (candle size, cape tint, a Legendary's glint).
##
##     godot --headless --path game --script res://tests/test_classes.gd

const LevelData := preload("res://scripts/level_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Hero := preload("res://scripts/hero.gd")
const Classes := preload("res://scripts/classes.gd")
const Items := preload("res://scripts/items.gd")
var WorldScript: GDScript   # loaded at run time: it needs the autoloads
const TILE := 32
const DT := 1.0 / 120.0
const GROUND := 13 * 32

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
	game = root.get_node_or_null("Game")
	if game == null:
		print("test_classes: no Game autoload")
		quit(1)
		return
	game.save_path = "user://test_classes_save.json"
	for suffix in [".bak", ".tmp"]:   # a last run's backup would be loaded as the save
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	_test_data()
	_test_parity()
	_test_ledge_grab()
	_test_drift()
	_test_cling()
	_test_cling_climb()
	_test_stampede()
	await _test_grave_step()
	await _test_hits_to_kill()
	await _test_stomps()
	await _test_guard()
	await _test_block_cost()
	await _test_guard_limits()
	await _test_rush()
	await _test_finisher()
	await _test_peal()
	await _test_flare()
	await _test_sealing_wax()
	await _test_smoke_step()
	await _test_knives()
	await _test_wisps()
	await _test_toll()
	await _test_grave_chill()
	await _test_rigs()
	await _test_poses()
	await _test_smoke()
	await _test_tree()
	await _test_everburning()
	await _test_cracked_tenor()
	await _test_unrung_bell()
	await _test_first_dawn()
	await _test_moth_queen()
	await _test_cuts_crit()
	await _test_special_tags()
	await _test_longsword_range()
	_test_gutterlight()
	await _test_real_art()
	await _test_capes()
	await _test_weapon_lean()
	await _test_shield_clear()
	await _test_dash_reset()
	await _test_gear()
	for suffix in ["", ".bak", ".tmp"]:   # (a save keeps its last one as .bak, and a load falls back to it)
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_classes_save.json" + suffix))
	game.save_path = game.SAVE_PATH
	game.load_save()
	print("test_classes: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _level(rows: Array) -> RefCounted:
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\n---\n" + "\n".join(rows))
	return lv


func _flat(w := 60) -> RefCounted:
	var rows := []
	for y in 15:
		rows.append("#".repeat(w) if y >= 13 else ".".repeat(w))
	rows[12] = "..P" + ".".repeat(w - 3)
	return _level(rows)


func _bare(lv: RefCounted, at: Vector2, cls := "", quirk := "") -> Node2D:
	## A player on its own (no World): a calling's stats and kit if cls is set.
	var p: Node2D = PlayerScript.new()
	p.level = lv
	p.reset_at(at)
	p.hurt_time = 10.0   # not reeling from a hit (that locks steering for a beat)
	if cls != "":
		p.set_stats(Hero.stats(Hero.blank(cls)))
		var kit: Object = load(Classes.info(cls)["kit"]).new()
		kit.cls = cls
		kit.setup(p, null)
		p.kit = kit
	p.quirk = quirk
	return p


func _drive(p: Node2D, pad: Dictionary, steps: int) -> void:
	for i in steps:
		p.pad = pad
		p.step(DT)


func _world(cls: String, lv: RefCounted, fresh := true) -> Node2D:
	if fresh:
		game.reset()
		game.new_hero(cls)
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	return w


func _tick(w: Node2D, pad: Dictionary, n := 1) -> void:
	for i in n:
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _enemy(w: Node2D, kind: String, at: Vector2, rooted := true) -> Node2D:
	var e: Node2D = w.spawn_enemy(kind, at, {})
	e.active = true
	if rooted:
		e.apply_status("root", 999.0)
	return e


func _free(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _skilled(cls: String, skills: Dictionary, lv: RefCounted = null) -> Node2D:
	## A world with a level 10 hero of this calling holding these ranks.
	game.reset()
	var h: Dictionary = game.new_hero(cls)
	h["level"] = 10
	for id in skills:
		h["skills"][id] = int(skills[id])
	var w := await _world(cls, lv if lv != null else _flat(), false)
	w.apply_hero()
	return w


# ---------------------------------------------------------------- data

func _test_data() -> void:
	for cls in Classes.ORDER:
		var info: Dictionary = Classes.info(cls)
		_check(info["enabled"], "%s is enabled" % cls)
		_check(ResourceLoader.exists(info["kit"]), "%s has its kit (%s)" % [cls, info["kit"]])
		var tree := Classes.tree(cls)
		# v2's root and 8 nodes; the v3 tree (Classes.deep, on in the game
		# since the wave-1 merge) adds Tiers 4 and 5 in both branches, and its
		# root's per holds 8 (ranks 1-7 and of the Keeper's 8th)
		_check(tree.size() == (13 if Classes.deep else 9), "%s has a root and %d nodes" % [cls, 12 if Classes.deep else 8])
		for n in tree:
			var per: Array = n["per"]
			_check(per.size() == int(n["max"]) or (n["branch"] == -1 and per.size() == (8 if Classes.deep else 5)), "%s: %s has a number per rank" % [cls, n["id"]])
			_check(Classes.node_text(n, 1).find("{") < 0, "%s: %s's card text fills in" % [cls, n["id"]])
	# The kits read ranks through rank()/per(): the root counts gear's +1.
	var p := _bare(_flat(), Vector2(100, GROUND), "knight")
	p.stats["root_rank"] = 1
	_check(p.kit.rank("k_aegis") == 2 and is_equal_approx(p.kit._rush_coef(), 1.4), "a +1 root rank from gear lifts the rush to 1.4x")
	p.free()
	# "of the Keeper" past a full v2 root (rank 5, open from L12): the +1 still
	# counts, for a weapon's and a charm's (v3's ranks 6 and 7, spec §2.2;
	# the Sootrunner's dash stays 144 px, so hers is Sooted's bonus).
	var roots := {"knight": ["k_aegis", "_rush_coef"], "witch": ["w_flare", "_full_coef"], "runner": ["r_step", "_soot_bonus"],
			"founder": ["f_peal", "_wave_coef"], "sexton": ["x_knell", "_mote_coef"]}
	for cls in roots:
		var q := _bare(_flat(), Vector2(100, GROUND), cls)
		q.stats["ranks"][roots[cls][0]] = 5
		var v5: float = q.kit.call(roots[cls][1])
		q.stats["root_rank"] = 1
		var v6: float = q.kit.call(roots[cls][1])
		q.stats["root_rank"] = 2
		var v7: float = q.kit.call(roots[cls][1])
		_check(v6 > v5 and v7 > v6, "%s: of the Keeper on a rank 5 %s still counts (%.2f -> %.2f -> %.2f)" % [cls, roots[cls][0], v5, v6, v7])
		q.free()
	var kq := _bare(_flat(), Vector2(100, GROUND), "knight")
	kq.stats["ranks"]["k_aegis"] = 5
	kq.stats["root_rank"] = 1
	_check(is_equal_approx(kq.kit._rush_coef(), 2.2) and is_equal_approx(kq.kit._block_share(), 0.27) and is_equal_approx(kq.kit._rush_cost(), 17.0),
			"the knight's rank 6 Aegis (spec §2.2): rush 2.2x, blocks cost 27%, a rush 17 Grace")
	kq.free()
	var xq := _bare(_flat(), Vector2(100, GROUND), "sexton")
	xq.stats["ranks"]["x_ward"] = 3   # past a branch node's 2 ranks (no save allows it): it stops at its max
	_check(int(xq.kit.per("x_ward", [50, 70], 40)) == 70, "only the root goes past its ranks; a branch node stops at its max")
	xq.free()
	_check(Classes.at_rank([2, 2, 3, 3, 3], 7) == 3 and Classes.at_rank([25, 24, 23, 22, 20], 6) == 18 and Classes.at_rank([1], 3) == 1,
			"a table's last step goes on past its end, ints staying ints")


# ---------------------------------------------------------------- parity

func _trace(p: Node2D) -> Array:
	## A fixed run of inputs; every position and velocity along the way.
	var out := []
	var seq := [[{}, 24], [{"right": true}, 48], [{"right": true, "jump": true, "jump_pressed": true}, 1],
			[{"right": true, "jump": true}, 70], [{}, 60], [{"left": true, "jump": true, "jump_pressed": true}, 1],
			[{"left": true, "jump": true}, 3], [{"left": true}, 90], [{"jump": true, "jump_pressed": true}, 1], [{"jump": true}, 120]]
	for s in seq:
		for i in s[1]:
			p.pad = s[0]
			p.step(DT)
			out.append([p.position, p.velocity])
	return out


func _test_parity() -> void:
	var lv := _flat()
	var ref := _bare(lv, Vector2(200, GROUND))
	var want := _trace(ref)
	ref.free()
	for cls in Classes.ORDER:
		var p := _bare(lv, Vector2(200, GROUND), cls, "")
		var got := _trace(p)
		var same := got.size() == want.size()
		for i in mini(got.size(), want.size()):
			if got[i][0] != want[i][0] or got[i][1] != want[i][1]:
				same = false
				print("  %s parts from v1 at step %d: %s vs %s" % [cls, i, got[i], want[i]])
				break
		_check(same, "%s with quirk \"\" moves exactly like v1 Wick" % cls)
		p.free()
		# With its quirk on, the plain run and jump are still v1's.
		var q := _bare(lv, Vector2(200, GROUND), cls, Classes.info(cls)["quirk_id"])
		var r0 := _bare(lv, Vector2(200, GROUND))
		_drive(q, {}, 20)
		_drive(r0, {}, 20)
		_drive(q, {"right": true}, 36)
		_drive(r0, {"right": true}, 36)
		_check(q.velocity.x == r0.velocity.x and q.velocity.x == PlayerScript.RUN_SPEED, "%s's quirk leaves the run at 205 (%.1f)" % [cls, q.velocity.x])
		var top_q: float = q.position.y
		var top_r: float = r0.position.y
		for i in 150:
			var pd := {"jump": true, "jump_pressed": i == 0}
			q.pad = pd
			r0.pad = pd
			q.step(DT)
			r0.step(DT)
			top_q = minf(top_q, q.position.y)
			top_r = minf(top_r, r0.position.y)
		_check(is_equal_approx(top_q, top_r), "%s's quirk leaves the held jump's height alone (%.1f vs %.1f)" % [cls, GROUND - top_q, GROUND - top_r])
		q.free()
		r0.free()


# ---------------------------------------------------------------- quirks

func _wall_level() -> RefCounted:
	## Floor at row 13; a stone column (cols 10-11) whose top is row 10 (3 tiles up).
	var rows := []
	for y in 15:
		var row := ".".repeat(40)
		if y >= 13:
			row = "#".repeat(40)
		elif y >= 10:
			row = "..........##" + ".".repeat(28)
		rows.append(row)
	return _level(rows)


func _test_ledge_grab() -> void:
	var lv := _wall_level()
	var top := 10.0 * TILE
	var face := 10.0 * TILE - 10.0 - 0.01   # his right side against the column's left face
	# Midair, 10 px short of the top, pushing in: he hauls up onto it.
	var p := _bare(lv, Vector2(face, top + 10.0), "knight", "ledge_grab")
	p.on_floor = false
	var grabbed := false
	for i in 60:
		p.pad = {"right": true}
		p.step(DT)
		grabbed = grabbed or p.ledge_t >= 0.0
	_check(grabbed, "Ledge Grab catches a top 10 px above the feet")
	_check(p.on_floor and absf(p.position.y - top) < 0.5 and p.position.x > 10.0 * TILE, "and he ends up standing on it (%s)" % p.position)
	p.free()
	# 14 px short: out of reach, he drops.
	p = _bare(lv, Vector2(face, top + 14.0), "knight", "ledge_grab")
	p.on_floor = false
	grabbed = false
	for i in 60:
		p.pad = {"right": true}
		p.step(DT)
		grabbed = grabbed or p.ledge_t >= 0.0
	_check(not grabbed and p.position.y > top + 20.0, "and misses one 14 px above the feet (%.0f)" % (p.position.y - top))
	p.free()
	# A real jump that peaks just short: find the release that tops out 8 px
	# under the ledge, then compare the knight with the bot.
	var release := -1
	for n in range(4, 40):
		var t := _bare(_flat(), Vector2(200, GROUND))
		var best: float = GROUND
		for i in 120:
			t.pad = {"jump": i < n, "jump_pressed": i == 0}
			t.step(DT)
			best = minf(best, t.position.y)
		t.free()
		if GROUND - best >= 3.0 * TILE - 8.0:
			release = n
			break
	_check(release > 0, "a jump that peaks 8 px under a 3-tile ledge exists (release at %d)" % release)
	var knight := _bare(lv, Vector2(face, GROUND), "knight", "ledge_grab")
	var bot := _bare(lv, Vector2(face, GROUND))
	var knight_up := false
	var bot_up := false
	for i in 150:
		var pd := {"right": true, "jump": i < release, "jump_pressed": i == 0}
		knight.pad = pd
		bot.pad = pd
		knight.step(DT)
		bot.step(DT)
		knight_up = knight_up or (knight.on_floor and absf(knight.position.y - top) < 0.5)
		bot_up = bot_up or (bot.on_floor and absf(bot.position.y - top) < 0.5)
	_check(knight_up, "a jump 8 px short: the Candleknight grabs the ledge and stands on it")
	_check(not bot_up and absf(bot.position.y - GROUND) < 0.5, "and the bot (no quirk) falls back to the floor")
	knight.free()
	bot.free()
	# Coyote time: 0.15 s for him (0.12 for everyone else).
	var edge := _level(["", "", "", "", "", "", "", "", "", "", "", "", "", "##########" + ".".repeat(30), "##########" + ".".repeat(30)])
	for who in [["knight", "ledge_grab", true], ["", "", false]]:
		var c := _bare(edge, Vector2(9.5 * TILE, GROUND), who[0], who[1])
		c.velocity.x = 205.0
		for i in 200:
			c.pad = {"right": true}
			c.step(DT)
			if not c.on_floor:
				break
		_drive(c, {"right": true}, 16)   # 0.133 s after the edge
		c.pad = {"right": true, "jump": true, "jump_pressed": true}
		c.step(DT)
		_check((c.velocity.y < -400.0) == who[2], "coyote at 0.14 s: %s" % ("the knight still jumps" if who[2] else "too late for the bot"))
		c.free()


func _test_drift() -> void:
	var lv := _flat()
	var p := _bare(lv, Vector2(300, 60), "witch", "drift")
	p.on_floor = false
	_drive(p, {}, 30)
	_check(p.velocity.y > 300.0, "(the Taperwitch falls fast before drifting: %.0f)" % p.velocity.y)
	p.pad = {"jump": true, "jump_pressed": true}
	p.step(DT)
	var most := 0.0
	var held := 0
	while held < 100:
		p.pad = {"jump": true}
		p.step(DT)
		most = maxf(most, p.velocity.y)
		held += 1
	_check(p.drifting and most <= PlayerScript.DRIFT_FALL + 0.01, "a second press while falling caps the fall at 80 (%.1f)" % most)
	# It runs out after 1.2 s in all.
	var after := 0.0
	for i in 60:
		p.pad = {"jump": true}
		p.step(DT)
		after = maxf(after, p.velocity.y)
	_check(after > 200.0 and p.drift_left <= 0.0, "and gives out after 1.2 s (%.0f)" % after)
	p.pad = {"jump": true, "jump_pressed": true}
	p.step(DT)
	_check(not p.drifting, "and no more drift until she lands")
	for i in 200:
		p.pad = {}
		p.step(DT)
	_check(p.on_floor and is_equal_approx(p.drift_left, PlayerScript.DRIFT_TIME), "landing gives it back")
	# From a real jump: let go at the top, press again: drift.
	for i in 40:
		p.pad = {"jump": true, "jump_pressed": i == 0}
		p.step(DT)
	for i in 30:
		p.pad = {}
		p.step(DT)
	p.pad = {"jump": true, "jump_pressed": true}
	p.step(DT)
	_drive(p, {"jump": true}, 30)
	_check(absf(p.velocity.y - PlayerScript.DRIFT_FALL) < 0.01, "after a jump, the second press drifts (%.1f)" % p.velocity.y)
	p.free()
	# The bot presses jump in the air to no effect.
	var b := _bare(lv, Vector2(300, 60))
	b.on_floor = false
	_drive(b, {}, 30)
	b.pad = {"jump": true, "jump_pressed": true}
	b.step(DT)
	_drive(b, {"jump": true}, 20)
	_check(b.velocity.y > 400.0, "without the quirk the fall goes on (%.0f)" % b.velocity.y)
	b.free()


func _tall_wall() -> RefCounted:
	var rows := []
	for y in 15:
		var row := ".".repeat(40)
		if y >= 13:
			row = "#".repeat(40)
		elif y >= 1:
			row = "............#" + ".".repeat(27)
		rows.append(row)
	return _level(rows)


func _test_cling() -> void:
	var lv := _tall_wall()
	var face := 12.0 * TILE - 10.0 - 0.01
	var p := _bare(lv, Vector2(face, 150.0), "runner", "cling")
	p.on_floor = false
	p.velocity = Vector2(0, 300)
	_drive(p, {"right": true}, 12)
	var y0: float = p.position.y
	_drive(p, {"right": true}, 36)
	var speed: float = (p.position.y - y0) / (36.0 * DT)
	_check(p.clinging == 1 and absf(speed - PlayerScript.CLING_SLIDE) < 1.0, "Moth Cling slides down a wall at 70 (%.1f)" % speed)
	_check(p.clings == 1, "and counts the cling (the air dash comes back on it)")
	var x0: float = p.position.x
	p.pad = {"right": true, "jump": true, "jump_pressed": true}
	p.step(DT)
	_check(is_equal_approx(p.velocity.x, -PlayerScript.CLING_KICK.x) and p.velocity.y < -500.0, "jump kicks off the wall (%s)" % p.velocity)
	_drive(p, {"right": true, "jump": true}, 13)
	_check(p.position.x < x0 - 25.0 and p.velocity.x < -200.0, "with steering locked for 0.12 s though right is held (%.1f px)" % (x0 - p.position.x))
	p.free()
	# Without the quirk, pushing into a wall doesn't slow the fall.
	var b := _bare(lv, Vector2(face, 150.0))
	b.on_floor = false
	b.velocity = Vector2(0, 300)
	_drive(b, {"right": true}, 30)
	_check(b.velocity.y > 400.0, "the bot slides down no wall (%.0f)" % b.velocity.y)
	b.free()


func _climb(chimney: bool, secs: float) -> Dictionary:
	## Moth Cling up a tall wall (or a chimney of two), kicking off each
	## cling at once and pushing back at a wall the whole way.
	var rows := []
	for y in 40:
		var row := ".".repeat(40)
		if y >= 38:
			row = "#".repeat(40)
		elif chimney:
			row = "............#...#" + ".".repeat(23)
		else:
			row = "............#" + ".".repeat(27)
		rows.append(row)
	var ground := 38.0 * TILE
	var p := _bare(_level(rows), Vector2(460.0 if chimney else 12.0 * TILE - 10.01, ground), "runner", "cling")
	var dir := 1
	var used := false
	var out := {"kicks": 0, "first": INF, "best": 0.0}
	for i in int(secs / DT):
		var press := false
		if p.on_floor and i < 3:
			press = true
		if p.clinging != 0 and not used:
			press = true
			used = true
			out["kicks"] += 1
			if out["first"] == INF:
				out["first"] = ground - p.position.y
			out["last"] = ground - p.position.y
			if chimney:
				dir = -p.clinging
		if p.clinging == 0:
			used = false
		p.pad = {"right": dir > 0, "left": dir < 0, "jump": press or p.velocity.y < 0.0, "jump_pressed": press}
		p.step(DT)
		out["best"] = maxf(out["best"], ground - p.position.y)
	p.free()
	return out


func _test_cling_climb() -> void:
	# One wall alone never lifts her: the wall she kicked off holds her again
	# only once she's back down to where she left it.
	var one := _climb(false, 12.0)
	_check(one["kicks"] >= 8, "on one wall she keeps clinging and kicking (%d kicks)" % one["kicks"])
	_check(one["best"] < one["first"] + 110.0, "but never climbs past one kick's rise (%.0f px up, first kick at %.0f)" % [one["best"], one["first"]])
	_check(one["last"] <= one["first"] + 1.0, "and her last kick is no higher than her first (%.0f vs %.0f)" % [one["last"], one["first"]])
	# Two walls close together: a chimney, kick to kick, climbs.
	var two := _climb(true, 6.0)
	_check(two["best"] > 600.0, "a chimney of two walls climbs (%.0f px in 6 s)" % two["best"])


func _test_stampede() -> void:
	var lv := _flat(200)
	var p := _bare(lv, Vector2(100, GROUND), "founder", "stampede")
	_drive(p, {}, 10)
	_drive(p, {"right": true}, 60)   # 0.5 s
	_check(is_equal_approx(p.velocity.x, PlayerScript.RUN_SPEED) and not p.stampeding, "Stampede: at 0.5 s still 205")
	_drive(p, {"right": true}, 60)   # 1.0 s
	_check(p.stampeding and absf(p.velocity.x - PlayerScript.STAMPEDE_SPEED) < 0.5, "after 0.8 s flat out, top speed is 250 (%.1f)" % p.velocity.x)
	# A jump keeps it, easing back to 225 in the air.
	p.pad = {"right": true, "jump": true, "jump_pressed": true}
	p.step(DT)
	_drive(p, {"right": true, "jump": true}, 40)
	_check(p.stampeding and absf(p.velocity.x - PlayerScript.STAMPEDE_AIR) < 1.0, "in the air it eases to 225 (%.1f)" % p.velocity.x)
	for i in 200:
		p.pad = {"right": true}
		p.step(DT)
		if p.on_floor:
			break
	_drive(p, {"right": true}, 20)
	_check(p.stampeding and absf(p.velocity.x - 250.0) < 0.5, "and lands back at 250 (%.1f)" % p.velocity.x)
	_drive(p, {"left": true}, 2)
	_check(not p.stampeding, "a turn ends it")
	p.free()


func _test_grave_step() -> void:
	var w := await _world("sexton", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	_check(pl.quirk == "grave_step", "the Sexton's quirk is Grave Step")
	# Jump, let go, and near the top jump again: a bone ledge, and a leap off it.
	_tick(w, {"jump": true}, 1)
	_tick(w, {"jump": true}, 14)
	_tick(w, {}, 14)
	var movers_before: int = w.movers.size()
	_tick(w, {"jump": true}, 1)
	_check(w.movers.size() == movers_before + 1 and kit.ledges.size() == 1, "a midair jump raises a bone ledge")
	_check(pl.velocity.y < -0.85 * PlayerScript.JUMP_SPEED, "and leaps off it at 90%% of a jump (%.0f)" % pl.velocity.y)
	var ledge = kit.ledges[0] if kit.ledges.size() > 0 else null
	# A short hop off it: he comes back down onto the bone.
	var stood := false
	for i in 90:
		_tick(w, {})
		if ledge != null and pl.on_floor and pl.riding == ledge:
			stood = true
			break
	_check(stood, "the bone ledge can be stood on")
	# Jump off the bone, and near the top try again: the bone isn't ground,
	# so Grave Step doesn't come back (else bone after bone would climb forever).
	_tick(w, {"jump": true}, 1)
	var left_bone: bool = not pl.on_floor and pl.velocity.y < -500.0
	_tick(w, {"jump": true}, 12)
	_tick(w, {}, 6)
	var n_ledges: int = kit.ledges.size()
	var n_movers: int = w.movers.size()
	_tick(w, {"jump": true}, 1)
	_check(left_bone and kit.ledges.size() <= n_ledges and w.movers.size() <= n_movers,
			"a jump off his own bone doesn't give Grave Step back")
	_tick(w, {}, 120)
	_check(kit.ledges.is_empty() and not w.movers.has(ledge), "and the bone is gone after a second")
	_tick(w, {}, 60)
	_check(pl.on_floor and absf(pl.position.y - GROUND) < 0.5, "and he's back on the floor")
	# Real ground gives it back.
	_tick(w, {"jump": true}, 15)
	_tick(w, {}, 14)
	_tick(w, {"jump": true}, 1)
	_check(kit.ledges.size() == 1, "real ground gives Grave Step back")
	# A whole stairway of bones: jump from each, Grave Step at the top. Only
	# one bone per trip off the ground, so he never gets far above it.
	_tick(w, {}, 240)
	var best := pl.position.y
	for cycle in 8:
		_tick(w, {"jump": true}, 1)
		for i in 60:
			_tick(w, {"jump": true})
			best = minf(best, pl.position.y)
			if pl.velocity.y >= 0.0:
				break
		_tick(w, {}, 1)
		_tick(w, {"jump": true}, 1)
		for i in 110:
			_tick(w, {"jump": pl.velocity.y < 0.0})
			best = minf(best, pl.position.y)
			if pl.on_floor:
				break
	_check(GROUND - best < 260.0, "no stairway of bones: 8 tries top out %.0f px up (one bone and a jump is ~225)" % (GROUND - best))
	await _free(w)


# ---------------------------------------------------------------- damage

func _hits_to_kill(cls: String, kind: String) -> int:
	var w := await _world(cls, _flat(80))
	var pl: Node2D = w.player
	pl.reset_at(Vector2(300, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	var melee: bool = Classes.info(cls)["melee"]
	var gap := 26.0 if melee else 110.0
	var e := _enemy(w, kind, Vector2(300 + gap, GROUND))
	var hits := 0
	for n in 12:
		if not e.alive:
			break
		e.position = Vector2(pl.position.x + gap, GROUND)
		e.velocity = Vector2.ZERO
		var before: float = e.hp
		_tick(w, {"attack": true}, 2)
		_tick(w, {}, 70)
		if e.hp < before:
			hits += 1
	var dead: bool = not e.alive
	await _free(w)
	return hits if dead else 99


func _test_hits_to_kill() -> void:
	var table := []
	for cls in Classes.ORDER:
		var r := await _hits_to_kill(cls, "skeleton")
		var t := await _hits_to_kill(cls, "thornback")
		table.append("%s %d/%d" % [cls, r, t])
		_check(r >= 1 and r <= 3, "%s at level 1 fells a Rattle in 1-3 hits (%d)" % [cls, r])
		_check(t >= 2 and t <= 6, "%s at level 1 fells a Thornback in 2-6 hits (%d)" % [cls, t])
	print("  level 1 hits to kill, Rattle/Thornback: ", ", ".join(table))


func _test_stomps() -> void:
	for cls in Classes.ORDER:
		var w := await _world(cls, _flat())
		var pl: Node2D = w.player
		var e := _enemy(w, "skeleton", Vector2(400, GROUND))
		pl.reset_at(e.position + Vector2(0, -70))
		pl.velocity = Vector2(0, 100)
		pl.on_floor = false
		var hp0: float = pl.hp
		for i in 90:
			_tick(w, {})
			if not e.alive:
				break
		_check(not e.alive and pl.hp == hp0, "%s: one stomp kills a Rattle, unhurt" % cls)
		await _free(w)


# ---------------------------------------------------------------- the Candleknight

func _wave(w: Node2D, from: float, dir: int, dmg := 36.0) -> Dictionary:
	return w.add_hazard({"kind": "wave", "motion": "floor", "rect": Rect2(from - 9.0, GROUND - 22.0, 18.0, 22.0),
			"vel": Vector2(dir * 250.0, 0), "life": 2.0, "dmg": dmg})


func _test_guard() -> void:
	var w := await _world("knight", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(400, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.res = 50.0
	var hp0: float = pl.hp
	# A wave from the front meets the shield in its first 0.18 s: Perfect Guard.
	_wave(w, pl.position.x + 44.0, -1)
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, 50)
	_check(pl.hp == hp0, "a Perfect Guard takes a shockwave for nothing")
	# (Grace keeps its 4/s while guarding, REGEN_WHILE_GUARDING: up to 51 ticks of it here.)
	var gr := 4.0 * DT if kit.REGEN_WHILE_GUARDING else 0.0
	_check(kit.perfect_guards == 1 and pl.res > 64.5 and pl.res < 65.5 + 51 * gr, "and pays 15 Grace back (%.1f)" % pl.res)
	_tick(w, {}, 60)
	w.hazards.clear()
	# A later block: Grace pays half the blow (70% of that on Dusk).
	pl.res = 50.0
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, 40)
	_wave(w, pl.position.x + 60.0, -1)
	_tick(w, {"special": true}, 60)
	_check(pl.hp == hp0 and kit.blocks == 1, "an ordinary block stops the wave")
	var paid: float = 36.0 * 0.5 * kit.DUSK_BLOCK
	_check(pl.res > 49.5 - paid and pl.res < 50.5 - paid + 101 * gr, "and costs half its harm in Grace, less on Dusk (%.1f)" % pl.res)
	# From behind, the shield is no help.
	_wave(w, pl.position.x - 60.0, 1)
	_tick(w, {"special": true}, 60)
	_check(pl.hp < hp0, "a wave from behind still hurts")
	_tick(w, {}, 10)
	w.hazards.clear()
	# Not enough Grace: the guard breaks, part of the blow gets through, a stagger.
	pl.hp = pl.max_hp
	pl.invuln = 0.0
	pl.res = 6.0
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, 40)
	_wave(w, pl.position.x + 60.0, -1)
	var broke := false
	var least := 99.0
	for i in 60:
		_tick(w, {"special": true})
		broke = broke or kit._stagger > 0.0
		if kit._stagger > 0.0:
			least = minf(least, pl.res)
	_check(broke and pl.hp < pl.max_hp and pl.hp > pl.max_hp - 36.0, "a guard with too little Grace breaks and staggers (%.1f lost)" % (pl.max_hp - pl.hp))
	_check(least < 0.1, "and empties the Grace (%.2f)" % least)
	# Contact from a Rattle walking into the raised shield.
	_tick(w, {}, 120)
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	pl.res = 60.0
	var e := _enemy(w, "skeleton", pl.position + Vector2(40, 0), false)
	e.facing = -1
	_tick(w, {"special": true}, 1)
	var pg0: int = kit.perfect_guards
	_tick(w, {"special": true}, 90)
	_check(pl.hp == pl.max_hp, "a Rattle walking into the shield doesn't hurt him")
	_check(kit.perfect_guards > pg0 and e.status.has("stun") or kit.blocks > 1, "and is turned away by it")
	await _free(w)


func _test_block_cost() -> void:
	## A block's Grace: half the blow, weighed as it would be at level 1 (so
	## the growth of life and blows with level doesn't price the guard out),
	## 70% of that on Dusk, never under 5.
	var w := await _world("knight", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	_check(is_equal_approx(kit.block_cost(30.0), 30.0 * 0.5 * 0.7), "on Dusk at L1 a Rattle's touch costs 10.5 Grace (%.2f)" % kit.block_cost(30.0))
	_check(is_equal_approx(kit.block_cost(2.0), kit.BLOCK_MIN), "a graze still costs the least a block costs")
	var s0: Dictionary = pl.stats
	var s: Dictionary = s0.duplicate(true)
	s["level"] = 11
	pl.set_stats(s)
	var touch := 30.0 * pow(1.12, 11)   # a Rattle in 2-4 (area 12)
	var c11: float = kit.block_cost(touch)
	_check(absf(c11 - touch * 0.35 / pow(1.10, 10)) < 0.01 and c11 < 16.0,
			"at L11 a 2-4 Rattle's touch (%.0f) costs %.1f Grace, not the %.0f its raw harm would" % [touch, c11, touch * 0.35])
	pl.set_stats(s0)
	w.diff = "nightfall"
	_check(is_equal_approx(kit.block_cost(30.0), 15.0), "Nightfall pays in full (%.2f)" % kit.block_cost(30.0))
	w.diff = "dusk"
	await _free(w)


func _test_guard_limits() -> void:
	## What a shield can't stop: fire underfoot, smoke, and a foe dropping
	## on his head (whatever kind of blow it calls itself).
	var w := await _world("knight", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	for kind in ["fire", "smoke"]:
		pl.reset_at(Vector2(300, GROUND))
		pl.facing = 1
		pl.hp = pl.max_hp
		pl.invuln = 0.0
		_tick(w, {}, 5)
		pl.res = 60.0
		_tick(w, {"special": true}, 40)   # past the Perfect window
		var b0: int = kit.blocks
		var p0: int = kit.perfect_guards
		w.add_hazard({"kind": kind, "motion": "still", "owner": "enemy", "dmg": 20.0, "life": 1.0,
				"rect": Rect2(pl.position.x - 6.0, GROUND - 10.0, 36.0, 10.0)})
		_tick(w, {"special": true}, 60)
		_check(pl.hp < pl.max_hp and kit.blocks == b0 and kit.perfect_guards == p0, "the shield doesn't keep out %s" % kind)
		_tick(w, {}, 150)
		w.hazards.clear()
	pl.reset_at(Vector2(300, GROUND))
	pl.facing = 1
	pl.hp = pl.max_hp
	pl.invuln = 0.0
	_tick(w, {}, 5)
	pl.res = 60.0
	_tick(w, {"special": true}, 40)
	var e := _enemy(w, "skeleton", Vector2(300, GROUND - 60))
	var hp0: float = pl.hp
	_check(w.hurt_player(20.0, e.position.x, "hit", e) and pl.hp < hp0, "a foe dropping from right overhead gets past the shield")
	pl.invuln = 0.0
	pl.hurt_time = 10.0
	e.position = pl.position + Vector2(24, 0)
	var b0: int = kit.blocks
	hp0 = pl.hp
	_check(not w.hurt_player(20.0, e.position.x, "hit", e) and pl.hp == hp0 and kit.blocks == b0 + 1, "one in front at his height is blocked")
	# Something towering over him (a boss) that strikes from the front meets the shield.
	kit._block_cd.clear()
	var was_size: Vector2 = e.size
	e.size = Vector2(60, 120)
	e.position = pl.position + Vector2(40, 0)
	b0 = kit.blocks
	_check(not w.hurt_player(20.0, e.position.x, "hit", e) and pl.hp == hp0 and kit.blocks == b0 + 1, "so does a towering foe striking from the front")
	e.size = was_size
	# A Perfect Guard staggers its attacker: reeling, it can't bite him even
	# if the shield drops for a moment.
	e.alive = false
	w.enemies.erase(e)
	_tick(w, {}, 60)
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	pl.res = 60.0
	var r := _enemy(w, "skeleton", pl.position + Vector2(90, 0), false)
	r.facing = -1
	var pg0: int = kit.perfect_guards
	_tick(w, {"special": true}, 1)
	r.position = pl.position + Vector2(16, 0)   # it walks in just as the shield goes up
	for i in 20:
		_tick(w, {"special": true})
		if kit.perfect_guards > pg0:
			break
	_check(kit.perfect_guards > pg0 and r.stunned(), "a Rattle walking into a fresh guard is a Perfect Guard")
	r.position = pl.position + Vector2(14, 0)   # still pressed against him
	r.velocity = Vector2.ZERO
	_tick(w, {}, 80)   # past a plain block's 0.5 s, inside the 1 s stagger
	_check(r.stunned() and pl.hp == pl.max_hp, "and while it reels it can't hurt him, shield down or not")
	await _free(w)


func _test_rush() -> void:
	# A floor that ends at column 20: the rush must stop at the edge.
	var rows := []
	for y in 15:
		rows.append(("#".repeat(20) + ".".repeat(20)) if y >= 13 else ".".repeat(40))
	var w := await _world("knight", _level(rows))
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(12 * TILE, GROUND))
	_tick(w, {}, 10)
	pl.res = 60.0
	var e := _enemy(w, "skeleton", pl.position + Vector2(50, 0))
	var hp0: float = pl.hp
	var ehp: float = e.hp
	_tick(w, {"right": true, "special": true}, 1)
	_check(kit.rushing > 0.0, "holding a direction on the ground: Shield Rush")
	_tick(w, {"right": true, "special": true}, 30)
	_check(e.hp < ehp or not e.alive, "the rush strikes the Rattle it passes")
	_check(pl.hp == hp0, "and he takes nothing from it")
	_check(absf(pl.res - (60.0 - 25.0)) < 6.0 + 0.5, "it costs 25 Grace (+6 back per hit): %.1f" % pl.res)
	# Rush again toward the edge from 60 px away: he stops on the floor.
	w.hazards.clear()
	pl.reset_at(Vector2(20 * TILE - 50, GROUND))
	_tick(w, {}, 10)
	pl.res = 60.0
	_tick(w, {"right": true, "special": true}, 1)
	_tick(w, {"special": true}, 40)
	_check(pl.on_floor and pl.position.x < 20 * TILE, "a rush stops at the ledge's edge (x %.0f)" % pl.position.x)
	_check(kit.guarding, "and, still held, flows into Guard")
	await _free(w)


func _test_finisher() -> void:
	var w := await _world("knight", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	var coefs := []
	for n in 4:
		_tick(w, {"attack": true}, 1)
		coefs.append(kit.melee_coef())
		_tick(w, {}, 36)   # 0.3 s: quicker than the 0.5 s gap
	_check(coefs[0] == 1.0 and coefs[1] == 1.0 and coefs[2] == 1.6 and coefs[3] == 1.0, "the third quick cut is a 1.6x Finisher (%s)" % [coefs])
	_tick(w, {}, 80)
	_tick(w, {"attack": true}, 1)
	_tick(w, {}, 1)
	var box: Rect2 = pl.attack_rect()
	_check(box.size.x == 38.0, "an ordinary cut keeps the 38 px box (%s)" % box)
	_tick(w, {}, 35)
	_tick(w, {"attack": true}, 1)
	_tick(w, {}, 35)
	_tick(w, {"attack": true}, 1)
	_tick(w, {}, 1)
	box = pl.attack_rect()
	_check(box.size.x == 48.0 and box.size.y == 38.0, "and a Finisher thrusts 48x38 (%s)" % box)
	_tick(w, {}, 80)
	await _free(w)


# ---------------------------------------------------------------- the Bellfounder

func _test_peal() -> void:
	# The floor ends at x 480 (a pit beyond).
	var rows := []
	for y in 15:
		rows.append(("#".repeat(15) + ".".repeat(25)) if y >= 13 else ".".repeat(40))
	var w := await _world("founder", _level(rows))
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(336, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.res = 20.0
	_tick(w, {"special": true}, 1)
	_check(kit.peals == 0 and w.hazards.is_empty(), "under 35 Heat the Peal won't ring")
	_tick(w, {}, 5)
	pl.res = 50.0
	var e := _enemy(w, "skeleton", Vector2(336 + 120, GROUND))
	_tick(w, {"special": true}, 1)
	var right: Dictionary = {}
	for h in w.hazards:
		if h["owner"] == "player" and h["kind"] == "wave" and h["vel"].x > 0.0:
			right = h
	_check(not right.is_empty() and absf(pl.res - 15.0) < 0.5, "35 Heat: a slam and a wave each way")
	var last_x := 0.0
	var gone_at := -1
	for i in 90:
		_tick(w, {})
		if not right.is_empty() and w.hazards.has(right):
			last_x = right["rect"].get_center().x
		elif gone_at < 0:
			gone_at = i
	_check(not e.alive, "the wave kills a Rattle 120 px away")
	_check(last_x <= 482.0 and gone_at >= 0 and gone_at * DT < 150.0 / 260.0, "and stops at the floor's edge (%.0f, %.2f s)" % [last_x, gone_at * DT])
	# Anvil Drop: in the air, down fast, keeping the sideways speed.
	pl.reset_at(Vector2(200, GROUND - 120))
	pl.on_floor = false
	pl.velocity = Vector2(120, 0)
	pl.res = 50.0
	_tick(w, {"special": true}, 1)
	_check(kit.anvil and pl.velocity.y >= 899.0 and absf(pl.velocity.x - 120.0) < 1.0, "in the air it's an Anvil Drop that keeps its vx (%s)" % pl.velocity)
	_tick(w, {}, 30)
	_check(not kit.anvil and pl.on_floor and kit.peals == 2, "which lands as a Peal")
	await _free(w)


# ---------------------------------------------------------------- the Taperwitch

func _test_flare() -> void:
	var w := await _world("witch", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.res = 100.0
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true, "jump": true}, 60)
	_check(kit.charging and kit.charge >= 0.99, "holding charges the Flare in 0.5 s")
	_check(pl.on_floor, "and she can't jump while charging")
	_tick(w, {}, 1)
	_check(absf(pl.res - 50.0) < 1.0, "a full flare costs 50 Melt (%.1f)" % pl.res)
	var lit := false
	for i in 180:
		_tick(w, {})
		lit = lit or w.lights_tagged("beacon").size() == 1
	_check(lit and kit.bursts == 1, "the burst leaves a Beacon light")
	var fire := false
	pl.res = 100.0
	_tick(w, {"special": true}, 1)
	_tick(w, {}, 1)
	for i in 120:
		_tick(w, {})
		for h in w.hazards:
			fire = fire or (h["kind"] == "fire" and h["owner"] == "player")
	_check(w.lights_tagged("beacon").size() == 1 and kit.bursts == 2, "a second flare moves the one Beacon (%d)" % w.lights_tagged("beacon").size())
	_check(fire, "and leaves burning ground")
	# A flare that lands by a Rattle kills it (a full lob comes down ~230 px on).
	pl.res = 100.0
	var e := _enemy(w, "skeleton", pl.position + Vector2(215, 0))
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, 60)
	_tick(w, {}, 120)
	_check(not e.alive, "a full flare fells a Rattle where it bursts")
	# Sparks: at most three alive, soft-aimed at a Flit above the line.
	pl.res = 100.0
	for o in w.enemies:
		o.alive = false
	var bat := _enemy(w, "bat", pl.position + Vector2(140, -60))
	_tick(w, {"attack": true}, 1)
	var spark: Dictionary = w.shots.back() if w.shots.size() > 0 else {}
	_check(not spark.is_empty() and spark["kind"] == "spark" and spark["vel"].y < -40.0, "a spark soft-aims up at a Flit (%s)" % (spark.get("vel", "none")))
	bat.alive = false
	await _free(w)


func _test_sealing_wax() -> void:
	## Sealing Wax slows what a flare bursts on, but never a boss: his tells
	## and windows keep their time, as with every other slow, stun and root
	## (the wax still tints him).
	var w := await _skilled("witch", {"w_reservoir": 2, "w_waxskin": 1, "w_seal": 3})
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	_tick(w, {}, 10)
	var foe := _enemy(w, "thornback", Vector2(400, GROUND))
	var big := _enemy(w, "thornback", Vector2(432, GROUND))
	for o in [foe, big]:
		o.max_hp = 9999.0
		o.hp = 9999.0
	w.boss = big
	kit._burst({"pos": Vector2(416, GROUND - 10), "vel": Vector2.ZERO, "coef": 0.2, "frac": 0.0}, null)
	_check(foe.status.has("slow") and foe.status.has("waxed") and big.hp < big.max_hp, "Sealing Wax slows a foe in the flare's burst")
	_check(not big.status.has("slow") and big.status.has("waxed"), "but never a boss (only the wax shows on him)")
	w.boss = null
	await _free(w)


# ---------------------------------------------------------------- the Sootrunner

func _test_smoke_step() -> void:
	var w := await _world("runner", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	var e := _enemy(w, "skeleton", pl.position + Vector2(50, 0))
	e.facing = -1
	var hp0: float = pl.hp
	var ehp: float = e.hp
	var pips: float = pl.res
	_tick(w, {"right": true, "special": true}, 1)
	_tick(w, {"special": true}, 30)
	_check(pl.position.x > e.position.x + 20.0, "Smoke Step carries her through the Rattle (%.0f past)" % (pl.position.x - e.position.x))
	_check(pl.hp == hp0 and e.hp == ehp, "unharmed, and harming nothing")
	_check(e.status.has("sooted"), "and leaves it Sooted")
	_check(absf(pl.res - (pips - 1.0 + 30.0 * DT / 2.2)) < 0.05, "for one pip of Smoke")
	# Turn round: the knife hits its back, a sure crit.
	_tick(w, {"left": true}, 3)
	_tick(w, {"left": true, "attack": true}, 1)
	_tick(w, {}, 40)
	_check(kit.last_hit.get("back", false) and kit.last_hit.get("crit", false), "the next knife in its back is a Backstab crit (%s)" % [kit.last_hit])
	# Once per airtime.
	pl.reset_at(Vector2(600, GROUND - 100))
	pl.on_floor = false
	pl.res = 3.0
	_tick(w, {"special": true}, 1)
	_tick(w, {}, 30)
	var r1: float = pl.res
	_tick(w, {"special": true}, 1)
	_check(absf(pl.res - r1) < 0.05 and kit.stepping <= 0.0, "only one Smoke Step per airtime")
	await _free(w)


func _test_knives() -> void:
	var w := await _world("runner", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	# An arrow coming in, a knife going out: they cancel.
	var arrow: Dictionary = w.spawn_shot({"kind": "arrow", "owner": "enemy", "pos": pl.center() + Vector2(200, 0), "vel": Vector2(-300, 0), "life": 2.0, "dmg": 22.0})
	var hp0: float = pl.hp
	_tick(w, {"attack": true}, 1)
	_tick(w, {}, 60)
	_check(not w.shots.has(arrow) and pl.hp == hp0, "a knife cancels an arrow in flight")
	# A foe close in front gets a Stab, not a throw.
	var e := _enemy(w, "thornback", pl.position + Vector2(24, 0))
	var before: int = w.shots.size()
	var ehp: float = e.hp
	_tick(w, {"attack": true}, 1)
	_check(w.shots.size() == before and e.hp < ehp, "a foe within 28 px gets a Stab")
	# At most three knives in flight.
	e.alive = false
	w.enemies.erase(e)
	for i in 6:
		_tick(w, {"attack": i % 2 == 0}, 1)
		_tick(w, {}, 30)
	_check(kit._knives.size() <= 3, "at most three knives in flight")
	await _free(w)


# ---------------------------------------------------------------- the Sexton

func _test_wisps() -> void:
	var w := await _world("sexton", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.res = 100.0
	for i in 2:
		_tick(w, {"special": true}, 1)
		_tick(w, {}, 10)
	_check(kit.wisps.size() == 2 and absf(pl.res - 50.0) < 1.0, "two taps call two wisps for 25 Dirge each (%.0f)" % pl.res)
	_tick(w, {"special": true}, 1)
	_tick(w, {}, 5)
	_check(kit.wisps.size() == 2, "and two is the most at rank 1")
	_tick(w, {}, 150)
	# A foe in range, but no spade hit: the wisps hold their fire.
	var far := _enemy(w, "thornback", pl.position + Vector2(150, 0))
	var m0: int = kit.motes
	_tick(w, {}, 240)
	_check(kit.motes == m0, "wisps don't fire on their own")
	# A spade hit on a foe close by opens the window: they fire.
	var near := _enemy(w, "thornback", pl.position + Vector2(26, 0))
	_tick(w, {"attack": true}, 1)
	_tick(w, {}, 60)
	_check(kit.motes > m0, "a spade hit wakes them: motes fly (%d)" % (kit.motes - m0))
	near.alive = false
	w.enemies.erase(near)
	# Past 170 px they don't reach, even woken.
	_tick(w, {}, 200)
	far.position = pl.position + Vector2(215, 0)
	m0 = kit.motes
	kit.fire_window = 0.8
	_tick(w, {}, 90)
	_check(kit.motes == m0, "and a foe 215 px off is out of their reach")
	# A wisp pops to soak 40% of a blow.
	pl.invuln = 0.0
	var hp0: float = pl.hp
	w.hurt_player(30.0, pl.position.x + 10.0, "hit", null)
	var through := 18.0 * (1.0 - float(pl.stats["dr"]))
	_check(absf((hp0 - pl.hp) - through) < 0.01 and kit.wisps.size() == 1, "a wisp soaks 40%% of a hit (%.1f lost)" % (hp0 - pl.hp))
	await _free(w)


func _test_toll() -> void:
	var w := await _world("sexton", _flat())
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.res = 100.0
	_tick(w, {"special": true}, 1)
	_tick(w, {}, 10)
	# The press that calls the last wisp, held on, never goes on into a Toll
	# (one nervous press mustn't throw away the wisps it just paid for).
	var ring := 0.0
	for i in 60:
		_tick(w, {"special": true})
		ring = maxf(ring, float(kit.button_state()["ring"]))
	_tick(w, {}, 5)
	_check(kit.wisps.size() == 2 and kit._divers.is_empty(), "the press that calls the last wisp, held 0.5 s, doesn't toll")
	_check(ring == 0.0, "and shows no ring (%.2f)" % ring)
	_tick(w, {}, 120)   # the call's window closes
	var e := _enemy(w, "skeleton", pl.position + Vector2(90, 0))
	# At full wisps a tap is a Knell: it wakes them for a little Dirge. No Toll.
	pl.res = 100.0
	var m0: int = kit.motes
	_tick(w, {"special": true}, 12)
	_tick(w, {}, 1)
	var regen := 13.0 * DT * 3.0
	_check(kit.wisps.size() == 2 and e.alive, "at full wisps a quick tap doesn't toll")
	_check(absf(100.0 - pl.res + regen - kit.WAKE_COST) < 0.1 and kit.fire_window > 0.0,
			"it rings them awake for %d Dirge (%.1f spent)" % [kit.WAKE_COST, 100.0 - pl.res + regen])
	_tick(w, {}, 40)
	_check(kit.motes > m0, "and they fire (%d motes)" % (kit.motes - m0))
	# A fresh press held 0.3 s is Toll the Dead, the ring filling: 10 Dirge in all.
	_tick(w, {}, 60)
	pl.res = 100.0
	_tick(w, {"special": true}, 1)
	ring = 0.0
	var n := 1
	for i in 60:
		if not kit._divers.is_empty():
			break
		_tick(w, {"special": true})
		n += 1
		ring = maxf(ring, float(kit.button_state()["ring"]))
	_check(kit.wisps.is_empty() and not kit._divers.is_empty(), "a fresh 0.3 s hold is Toll the Dead")
	_check(ring > 0.9, "shown by the ring filling (%.2f)" % ring)
	_check(absf(100.0 - pl.res + n * DT * 3.0 - kit.TOLL_COST) < 0.1, "for %d Dirge in all (%.1f)" % [kit.TOLL_COST, 100.0 - pl.res + n * DT * 3.0])
	_tick(w, {"special": true}, 20)
	_tick(w, {}, 60)
	_check(not e.alive, "and the diving wisps burst on the Rattle")
	# Without the Dirge for a wake, tapping at full wisps looses nothing: the
	# wisps don't fight on their own, however often the bell is tapped.
	pl.res = 100.0
	for i in 2:
		_tick(w, {"special": true}, 1)
		_tick(w, {}, 10)
	_tick(w, {}, 120)
	var far := _enemy(w, "skeleton", pl.position + Vector2(120, 0))
	m0 = kit.motes
	pl.res = 0.0
	for k in 15:
		_tick(w, {"special": true}, 2)
		_tick(w, {}, 46)
		pl.res = minf(pl.res, 5.0)
	_check(kit.wisps.size() == 2 and kit.motes == m0 and far.hp == far.max_hp,
			"tapping with too little Dirge to wake them looses no motes (%d)" % (kit.motes - m0))
	await _free(w)


func _chill_run(w: Node2D, e: Node2D, secs: float) -> Dictionary:
	## The Sexton stands and swings at e, held before him, for secs: when was
	## it first rooted, and how much of the time after was it rooted?
	var pl: Node2D = w.player
	var first := -1
	var rooted := 0
	var after := 0
	for i in int(secs / DT):
		pl.invuln = 999.0
		e.position.x = pl.position.x + 28.0
		_tick(w, {"attack": (i / 2) % 2 == 0})
		if e.status.has("root"):
			rooted += 1
			if first < 0:
				first = i
		if first >= 0:
			after += 1
	return {"first": first, "share": float(rooted) / maxf(float(after), 1.0)}


func _test_grave_chill() -> void:
	## Grave Chill roots what the spade hits, then the foe thaws for 1.5 s
	## before a hit can root it again. (A root is a stun and the spade swings
	## every 0.3 s: without the thaw a Dread never acted again.)
	var w := await _skilled("sexton", {"x_digger": 2, "x_gravedirt": 1, "x_chill": 1})
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	var e := _enemy(w, "skeleton", pl.position + Vector2(28, 0), false)
	e.max_hp = 99999.0
	e.hp = 99999.0
	e.facing = -1
	var r := _chill_run(w, e, 4.2)
	_check(r["first"] >= 0 and e.hp < e.max_hp, "Grave Chill: a spade hit roots the foe")
	_check(r["share"] > 0.15 and r["share"] < 0.45, "but it thaws between roots: rooted %.0f%% of the time, not all of it" % (100.0 * r["share"]))
	# A boss is never rooted (as ever).
	e.alive = false
	w.enemies.erase(e)
	var b := _enemy(w, "skeleton", pl.position + Vector2(28, 0), false)
	b.max_hp = 99999.0
	b.hp = 99999.0
	w.boss = b
	r = _chill_run(w, b, 1.5)
	_check(r["first"] < 0 and b.hp < b.max_hp, "and a boss the spade hits is never rooted")
	w.boss = null
	var thaw := float(load("res://scripts/kits/sexton.gd").CHILL_THAW)
	_check(Classes.node_text(Classes.find_node("sexton", "x_chill"), 1).find("thaws for %ss" % str(thaw)) >= 0, "the card says it thaws, for the kit's own %.1f s" % thaw)
	await _free(w)


# ---------------------------------------------------------------- a run through 1-1

func _test_smoke() -> void:
	## Each calling runs 1-1 for 12 s, jumping, attacking and using its
	## Special (tapped and held) the whole way: nothing may break.
	for cls in Classes.ORDER:
		game.reset()
		game.new_hero(cls)
		var lv = LevelData.load_file("res://levels/1-1.txt")
		var w: Node2D = WorldScript.new()
		w.setup(lv, true)
		root.add_child(w)
		await process_frame
		var far := 0.0
		for i in int(12.0 / DT):
			var pd := {"right": (i / 240) % 5 != 4, "left": (i / 240) % 5 == 4, "jump": (i / 45) % 3 == 0,
					"attack": (i / 15) % 2 == 0, "special": (i / 70) % 4 == 0 or (i / 70) % 9 == 5, "down": (i / 90) % 7 == 3}
			w.test_pad = pd
			w._read_pad()
			w.tick(DT)
			far = maxf(far, w.player.position.x)
		print("  %s: 12 s through 1-1 got to x=%.0f, hp %.0f/%.0f, res %.1f, state %s" % [cls, far, w.player.hp, w.player.max_hp, w.player.res, w.state])
		_check(far > 300.0, "%s gets somewhere through 1-1" % cls)
		w.queue_free()
		await process_frame


# ---------------------------------------------------------------- the trees

func _maxed(cls: String) -> Node2D:
	## A world with a level 12 hero of this calling whose every node is maxed
	## (both capstones too, which play never allows: it runs every branch).
	game.reset()
	var h: Dictionary = game.new_hero(cls)
	h["level"] = 12
	for n in Classes.tree(cls):
		h["skills"][n["id"]] = int(n["max"])
	var w := await _world(cls, _flat(), false)
	w.apply_hero()
	w.player.hp = w.player.max_hp
	w.player.res = w.player.res_max
	return w


func _test_tree() -> void:
	# Candleknight: Mirrored Glass throws a perfectly guarded arrow back; Devout heals.
	var w := await _maxed("knight")
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(300, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.hp = pl.max_hp * 0.5
	w.spawn_shot({"kind": "arrow", "owner": "enemy", "pos": pl.center() + Vector2(40, 0), "vel": Vector2(-300, 0), "life": 2.0, "dmg": 22.0})
	_tick(w, {"special": true}, 1)
	var mine := false
	for i in 20:
		_tick(w, {"special": true})
		for s in w.shots:
			mine = mine or (s["owner"] == "player" and s["vel"].x > 0.0)
	_check(kit.perfect_guards == 1 and mine, "Mirrored Glass sends a perfectly guarded arrow back")
	_check(pl.hp > pl.max_hp * 0.5, "and Devout Guard heals on it (%.0f%%)" % (100.0 * pl.hp / pl.max_hp))
	_tick(w, {}, 30)
	# Dawnbringer: the rush leaves holy fire.
	pl.res = 100.0
	_tick(w, {"right": true, "special": true}, 1)
	_tick(w, {"special": true}, 30)
	var fire := false
	for hz in w.hazards:
		fire = fire or (hz["kind"] == "fire" and hz["owner"] == "player")
	_check(fire, "Dawnbringer's rush leaves holy fire")
	await _free(w)
	# Taperwitch: Kindle burns; Sunburst scatters; the Effigy takes a snuff.
	w = await _maxed("witch")
	pl = w.player
	kit = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	var e := _enemy(w, "thornback", pl.position + Vector2(90, 0))
	e.max_hp = 9999.0
	e.hp = 9999.0
	_tick(w, {"attack": true}, 1)
	_tick(w, {}, 30)
	var hp1: float = e.hp
	_tick(w, {}, 60)
	_check(e.hp < hp1 and kit.burning(e), "Kindle's burn keeps hurting after the spark (%.0f -> %.0f)" % [hp1, e.hp])
	e.alive = false
	pl.res = pl.res_max
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, 70)
	var before: int = kit.bursts
	_tick(w, {}, 200)
	_check(kit.bursts >= before + 5, "a full Sunburst flare splits into four more bursts (%d)" % (kit.bursts - before))
	pl.invuln = 0.0
	pl.take_damage(pl.max_hp * 5.0, pl.position.x + 10.0)
	_check(pl.alive and absf(pl.hp / pl.max_hp - 0.3) < 0.01, "the Wax Effigy takes a snuff and she relights at 30%")
	pl.invuln = 0.0
	pl.take_damage(pl.max_hp * 5.0, pl.position.x + 10.0)
	_check(not pl.alive, "but only once per altar")
	await _free(w)
	# Sootrunner: Thousand Cuts after a Step; Mercy Stroke on a wounded back.
	w = await _maxed("runner")
	pl = w.player
	kit = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	e = _enemy(w, "thornback", pl.position + Vector2(60, 0))
	e.facing = -1
	var shots0: int = w.shots.size()
	_tick(w, {"right": true, "special": true}, 1)
	var cuts := 0
	for i in 30:
		_tick(w, {})
		cuts = maxi(cuts, w.shots.size() - shots0)
	_check(cuts >= 1, "Thousand Cuts looses knives when a Step ends (%d)" % cuts)
	await _free(w)
	# Bellfounder: the Great Bell rings on the 5th maul hit; Crucible goes Molten.
	w = await _maxed("founder")
	pl = w.player
	kit = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	e = _enemy(w, "thornback", pl.position + Vector2(30, 0))
	e.max_hp = 9999.0
	e.hp = 9999.0
	pl.res = 0.0
	for n in 5:
		e.position = pl.position + Vector2(30, 0)
		_tick(w, {"attack": true}, 1)
		_tick(w, {}, 62)
	_check(kit._bell_count == 0 and kit._slam_fx.size() >= 0, "the Great Bell's count rolls over on the 5th hit")
	pl.res = pl.res_max
	_tick(w, {}, 2)
	_check(kit.molten_t > 0.0, "Crucible: full Heat turns her Molten")
	await _free(w)
	# Sexton: Choir's extra wisps; the Last Bell relights him.
	w = await _maxed("sexton")
	pl = w.player
	kit = w.kit
	pl.reset_at(Vector2(200, GROUND))
	_tick(w, {}, 10)
	_check(kit.max_wisps() == 5, "Choir of the Lost: five wisps at rank 5 (%d)" % kit.max_wisps())
	for i in 3:
		pl.res = pl.res_max
		_tick(w, {"special": true}, 1)
		_tick(w, {}, 6)
	pl.invuln = 0.0
	var n_w: int = kit.wisps.size()
	pl.take_damage(pl.max_hp * 5.0, pl.position.x + 10.0, "pit", null, {"pct": true, "ignore_invuln": true})
	_check(pl.alive and absf(pl.hp / pl.max_hp - minf(0.6, 0.15 * n_w)) < 0.01, "the Last Bell relights him at 15%% a wisp (%d wisps)" % n_w)
	await _free(w)


# ---------------------------------------------------------------- the rig

func _test_rigs() -> void:
	## Every calling's rig builds from art/wick when its own art is missing,
	## with a weapon (the knight's sword or a stand-in) and poses that apply.
	for cls in Classes.ORDER:
		var w := await _world(cls, _flat())
		var rig: Node2D = w.rig
		await process_frame
		_check(rig._sprites.has("body") and rig._sprites.has("head"), "%s's rig has a body and a head" % cls)
		_check(rig._sprites.has("sword") or rig._joints["sword"].get_child_count() > 0, "%s's rig holds a weapon" % cls)
		var tip: Vector2 = rig.weapon_point()
		_check(tip.distance_to(w.player.center()) < 60.0, "%s's weapon tip is near the hand (%.0f px)" % [cls, tip.distance_to(w.player.center())])
		if Classes.info(cls)["special"] in ["Aegis", "Knell"]:
			_check(rig._joints.has("offhand"), "%s carries an offhand" % cls)
		await _free(w)


func _test_poses() -> void:
	## The kit poses the rig must show: the Sootrunner's fist empty while a
	## knife flies (the code-drawn stand-in too, not only a sprite), the
	## Candleknight's shield out in front and over the sword arm, the
	## Sexton's handbell rung clear of the spade.
	var w := await _world("runner", _flat())
	var pl: Node2D = w.player
	var rig: Node2D = w.rig
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	_tick(w, {"attack": true}, 1)
	_tick(w, {}, 6)
	rig._process(0.0)
	var wj: Node2D = rig._joints["sword"]
	_check(wj.modulate.a == 0.0, "a thrown knife leaves her fist empty (alpha %.2f)" % wj.modulate.a)
	_tick(w, {}, 40)
	rig._process(0.0)
	_check(wj.modulate.a == 1.0, "and a fresh one is back in it after (alpha %.2f)" % wj.modulate.a)
	await _free(w)
	w = await _world("knight", _flat())
	pl = w.player
	rig = w.rig
	for f in [1, -1]:
		pl.reset_at(Vector2(300, GROUND))
		pl.facing = f
		_tick(w, {}, 10)
		pl.res = 80.0
		_tick(w, {"special": true}, 30)
		rig._process(0.0)
		var shield: Vector2 = rig.hand_point(true)
		var ahead: float = (shield.x - pl.center().x) * f
		var up: float = pl.position.y - shield.y
		_check(ahead > 6.0 and up > 12.0 and up < 26.0, "guarding (facing %d), the shield is out in front at his chest (%.1f ahead, %.1f up)" % [f, ahead, up])
		_check(rig._joints["offhand"].get_index() > rig._joints["arm_front"].get_index(), "and drawn over the sword arm")
		_check((rig.weapon_point().x - pl.center().x) * f < 0.0, "with the sword drawn back behind it")
		_tick(w, {}, 20)
	await _free(w)
	w = await _world("sexton", _flat())
	pl = w.player
	rig = w.rig
	pl.reset_at(Vector2(300, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.res = 100.0
	_tick(w, {"special": true}, 1)
	_tick(w, {}, 4)
	rig._process(0.0)
	var bell: Vector2 = rig.hand_point(true)
	_check(bell.x - pl.center().x > 10.0 and rig._joints["offhand"].get_index() > rig._joints["arm_front"].get_index(),
			"the Knell's handbell is rung out in front, over everything (%.1f ahead)" % (bell.x - pl.center().x))
	_check(rig.weapon_point().x < pl.center().x, "with the spade swung back out of its way")
	await _free(w)
	# The Flare's charge hum is let go with the throw (and on a respawn).
	w = await _world("witch", _flat())
	var kit: Object = w.kit
	w.player.res = 100.0
	_tick(w, {"special": true}, 1)
	var hum := AudioStreamPlayer.new()
	kit._hum = hum
	_tick(w, {"special": true}, 10)
	_tick(w, {}, 1)
	_check(kit._hum == null and not kit.charging, "the charge's sound is let go on the throw")
	kit._hum = hum
	kit.on_respawn()
	_check(kit._hum == null, "and on a respawn")
	hum.free()
	await _free(w)


# ---------------------------------------------------------------- the calling charms

func _test_cuts_crit() -> void:
	## Thousand Cuts' knives are sure crits the World rolls (force_crit): the
	## crit star on each, and one crit, not two (on a back, a Backstab's +25%
	## and that one crit). They're the Special's knives, so special_pct
	## ("of the Bell") counts on them.
	var w := await _skilled("runner", {"r_cuts": 1})
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 5)
	pl.stats["crit"] = 0.0   # no chance crits: a crit is the knife's own
	var cm := float(pl.stats["crit_mult"])
	var basic := float(pl.stats["basic"])
	var dmg := float(pl.stats["dmg_pct"])
	for back in [false, true]:
		for bell in [0.0, 1.0]:
			pl.stats["special_pct"] = bell
			var e := _enemy(w, "skeleton", pl.position + Vector2(90, 0))
			e.max_hp = 99999.0
			e.hp = 99999.0
			e.facing = 1 if back else -1   # the knife flies right: facing right, its back is to her
			var hp0: float = e.hp
			kit.last_hit = {}
			var s: Dictionary = kit._knife(pl.center(), Vector2.RIGHT, true)
			_check(bool(s.get("force_crit", false)) and bool(s.get("special", false)) and not s.has("base_extra"),
					"a Thousand Cuts knife is a sure crit and the Special's (no stand-in bonus)")
			for i in 40:
				_tick(w, {})
			var got: float = hp0 - e.hp
			var want: float = basic * (1.0 + dmg + (0.25 if back else 0.0) + bell) * cm
			var tag := "%s, special %+.0f%%" % ["on a back" if back else "from the front", bell * 100.0]
			_check(bool(kit.last_hit.get("crit", false)), "a Thousand Cuts knife %s crits (the star)" % tag)
			_check(got >= want * 0.89 and got <= want * 1.11, "and it crits once: %.1f for about %.1f (%s)" % [got, want, tag])
			w.enemies.erase(e)
			e.queue_free()
	await _free(w)


func _test_special_tags() -> void:
	## "of the Bell" (special_pct) counts on every hit a Special makes: the
	## Bellfounder's Peal waves (and a Cracked Tenor's halves), the Sexton's
	## Knell motes. A plain knife isn't the Special's.
	var w := await _skilled("founder", {})
	var kit: Object = w.kit
	var pl: Node2D = w.player
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 5)
	pl.res = pl.res_max
	kit.special_pressed()
	var waves: Array = w.hazards.filter(func(h): return h.get("kind") == "wave" and h.get("owner") == "player")
	_check(waves.size() >= 2 and waves.all(func(h): return bool(h.get("special", false))), "the Peal's waves are the Special's (%d)" % waves.size())
	if waves.size() > 0:
		var h: Dictionary = waves[0]
		h["run"] = 1.0
		var wv := {"h": h, "x0": h["rect"].get_center().x - 14.0 - 1.0, "fade": 0.0, "run": 1.0}
		pl.stats["flags"]["cracked_tenor_split"] = 2
		var n0: int = w.hazards.size()
		kit._crack(wv)
		var kids: Array = w.hazards.slice(n0)
		_check(kids.size() == 2 and kids.all(func(k): return bool(k.get("special", false))), "a Cracked Tenor's halves are too (%d)" % kids.size())
	await _free(w)
	w = await _skilled("sexton", {})
	kit = w.kit
	var e := _enemy(w, "skeleton", w.player.position + Vector2(80, 0))
	var n1: int = w.shots.size()
	kit._mote(w.player.center() + Vector2(0, -30), e)
	_check(w.shots.size() == n1 + 1 and bool(w.shots[-1].get("special", false)), "the Knell's motes are the Special's")
	await _free(w)
	w = await _skilled("runner", {})
	w.player.reset_at(Vector2(200, GROUND))
	_tick(w, {}, 5)
	var n2: int = w.shots.size()
	w.kit.basic()
	_check(w.shots.size() == n2 + 1 and not bool(w.shots[-1].get("special", false)) and not bool(w.shots[-1].get("force_crit", false)),
			"a plain thrown knife is neither")
	await _free(w)


func _test_longsword_range() -> void:
	## The Longsword: "shots fly 30% further" (world.gd spawn_shot stretches a
	## hero shot's life by range_mult), and the Sootrunner's aim reaches as
	## far as her knife now flies.
	for cls in ["witch", "runner"]:
		var reach := {}
		for belt in [[], ["longsword"]]:
			game.reset()
			game.new_hero(cls)
			if not belt.is_empty():
				game.grant_relic("longsword")
				game.set_belt(belt)
			var w := await _world(cls, _flat(), false)
			w.apply_hero()
			w.player.reset_at(Vector2(200, GROUND))
			w.player.facing = 1
			_tick(w, {}, 5)
			var n0: int = w.shots.size()
			w.kit.basic()
			if w.shots.size() > n0:
				var s: Dictionary = w.shots[-1]
				reach[belt.size()] = float(s["life"]) * (s["vel"] as Vector2).length()
			if cls == "runner":
				# A foe a little up and 350 px on: past the plain aim's reach
				# (309 px), inside the Longsword's.
				var e := _enemy(w, "skeleton", Vector2(w.player.position.x + 360.0, GROUND - 30.0))
				var n1: int = w.shots.size()
				w.kit.basic()
				if w.shots.size() > n1:
					var v: Vector2 = (w.shots[-1]["vel"] as Vector2).normalized()
					reach["aim%d" % belt.size()] = absf(v.y) > 0.02
				w.enemies.erase(e)
				e.queue_free()
			await _free(w)
		_check(reach.has(0) and reach.has(1) and absf(reach[1] / reach[0] - 1.3) < 0.02,
				"%s: the Longsword's shots fly 30%% further (%.0f -> %.0f px)" % [cls, reach.get(0, 0.0), reach.get(1, 0.0)])
		if cls == "runner":
			_check(not reach.get("aim0", true) and reach.get("aim1", false), "the Sootrunner's aim reaches a foe out where her Longsword's knife now flies")


func _charmed(cls: String, legend: String, lv: RefCounted = null) -> Node2D:
	## A world whose hero of this calling wears a Legendary charm.
	game.reset()
	game.new_hero(cls)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var it: Dictionary = Items.make("charm", cls, 5, "legendary", rng, legend)
	game.equip(it)
	var w := await _world(cls, lv if lv != null else _flat(), false)
	w.apply_hero()
	return w


func _everburn_run(w: Node2D) -> Dictionary:
	## A flare bursts at x 300; a sturdy foe waits 110 px on, clear of the
	## blast and the burning ground but inside the Beacon's light.
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	var e := _enemy(w, "thornback", Vector2(410, GROUND))
	e.max_hp = 9999.0
	e.hp = 9999.0
	kit._burst({"pos": Vector2(300, GROUND - 4), "vel": Vector2.ZERO, "coef": 1.8, "frac": 0.0}, null)
	var hp0: float = e.hp
	_tick(w, {}, int(2.0 / DT))
	var hp2: float = e.hp
	_tick(w, {}, int(4.5 / DT))
	var hp_out: float = e.hp
	_tick(w, {}, 120)
	return {"lost": hp0 - hp2, "ticks": kit.everburns, "after": hp_out - e.hp}


func _test_everburning() -> void:
	var w := await _charmed("witch", "everburning")
	_check(is_equal_approx(float(w.player.stats["flags"].get("everburning_coef", 0.0)), 0.10), "the Everburning Taper's numbers reach the kit")
	var r := await _everburn_run(w)
	_check(r["ticks"] >= 3 and r["lost"] > 0.0, "the Everburning Taper: the Beacon burns a foe inside its light (%d ticks, %.0f in 2 s)" % [r["ticks"], r["lost"]])
	_check(r["after"] == 0.0, "and stops once the Beacon is out (%.0f)" % r["after"])
	await _free(w)
	w = await _world("witch", _flat())
	r = await _everburn_run(w)
	_check(r["ticks"] == 0 and r["lost"] == 0.0, "without it the Beacon is only a light (%.0f)" % r["lost"])
	await _free(w)


func _tenor_run(w: Node2D) -> Dictionary:
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(600, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	# Just past where a rank-1 wave ends (600 + 14 + 150 = 764, 18 px wide).
	var far := _enemy(w, "thornback", Vector2(806, GROUND))
	far.max_hp = 9999.0
	far.hp = 9999.0
	pl.res = 50.0
	_tick(w, {"special": true}, 1)
	var back := false
	for i in 150:
		_tick(w, {})
		for h in w.hazards:
			if h["owner"] == "player" and h["kind"] == "wave" and h["vel"].x < 0.0 and h["rect"].get_center().x > 640.0:
				back = true   # running back toward her from the right-hand wave's end
	return {"splits": kit.splits, "hit": far.max_hp - far.hp, "back": back}


func _test_cracked_tenor() -> void:
	var w := await _charmed("founder", "cracked_tenor")
	var r := await _tenor_run(w)
	_check(r["splits"] == 2, "the Cracked Tenor: each Peal wave cracks in two at the end of its run (%d)" % r["splits"])
	_check(r["hit"] > 0.0, "one half runs on and hits a foe past the wave's reach (%.0f)" % r["hit"])
	_check(r["back"], "and one half runs back")
	await _free(w)
	w = await _world("founder", _flat())
	r = await _tenor_run(w)
	_check(r["splits"] == 0 and r["hit"] == 0.0, "without it the wave stops short of that foe (%.0f)" % r["hit"])
	await _free(w)
	# A wave stopped by an edge doesn't crack (the floor ends at x 480).
	var rows := []
	for y in 15:
		rows.append(("#".repeat(15) + ".".repeat(25)) if y >= 13 else ".".repeat(40))
	w = await _charmed("founder", "cracked_tenor", _level(rows))
	w.player.reset_at(Vector2(336, GROUND))
	w.player.facing = 1
	_tick(w, {}, 10)
	w.player.res = 50.0
	_tick(w, {"special": true}, 1)
	_tick(w, {}, 150)
	_check(w.kit.splits == 1, "a wave an edge stopped doesn't crack; the other, which ran its course, does (%d)" % w.kit.splits)
	await _free(w)


func _toll_now(w: Node2D) -> bool:
	## A fresh press held 0.4 s: true if it sent the wisps diving.
	w.player.res = 100.0
	_tick(w, {}, 2)
	_tick(w, {"special": true}, 1)
	var dove := false
	for i in 48:
		_tick(w, {"special": true})
		dove = dove or not w.kit._divers.is_empty()
	_tick(w, {}, 2)
	return dove


func _test_unrung_bell() -> void:
	var w := await _charmed("sexton", "unrung_bell")
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(200, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	for i in 2:
		pl.res = 100.0
		_tick(w, {"special": true}, 1)
		_tick(w, {}, 10)
	_check(kit.wisps.size() == 2, "two wisps called")
	var e := _enemy(w, "skeleton", pl.position + Vector2(90, 0))
	_check(await _toll_now(w), "Toll the Dead goes with The Unrung Bell")
	_check(kit.wisps.size() == 2 and kit.toll_cd > 7.0, "and the wisps are still there after (%d, %.1f s rest)" % [kit.wisps.size(), kit.toll_cd])
	_check(kit.button_state()["icon"] == "sexton", "the button shows the Knell, not the Toll, while it rests")
	_tick(w, {}, 60)
	_check(not e.alive, "the dive still bursts on the Rattle")
	_check(not await _toll_now(w), "no second Toll inside its 8 s")
	_tick(w, {}, int(8.0 / DT))
	_check(kit.button_state()["icon"] == "toll" and await _toll_now(w), "and it's back after them")
	await _free(w)


func _test_first_dawn() -> void:
	## The Glass of the First Dawn: its first_dawn_guard IS the Perfect Guard
	## window (the ring and the white ward show it too).
	var w := await _charmed("knight", "first_dawn")
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(300, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	_check(is_equal_approx(kit.pg_window(), float(Items.LEGENDS["first_dawn"]["fx"]["first_dawn_guard"])), "the Glass's window reaches the guard (%.2f s)" % kit.pg_window())
	pl.stats["flags"]["first_dawn_guard"] = 0.40   # a retuned Glass is the window the guard keeps
	pl.res = 60.0
	_tick(w, {"special": true}, 1)
	_tick(w, {"special": true}, int(0.34 / DT))
	var ring: float = kit.button_state()["ring"]
	var pg0: int = kit.perfect_guards
	pl.invuln = 0.0
	w.hurt_player(20.0, pl.position.x + 20.0, "hit", null)
	_check(kit.perfect_guards == pg0 + 1 and ring > 0.0, "a blow 0.35 s into a 0.40 s window is a Perfect Guard (ring %.2f)" % ring)
	_tick(w, {}, 30)
	await _free(w)
	w = await _world("knight", _flat())
	_check(is_equal_approx(w.kit.pg_window(), w.kit.PG_WINDOW), "without the Glass the window is the usual %.2f s" % w.kit.PG_WINDOW)
	await _free(w)


func _test_moth_queen() -> void:
	## The Moth-Queen's Scale: moth_queen_pips is the Smoke she holds.
	var w := await _charmed("runner", "moth_queen")
	_tick(w, {}, 2)
	_check(is_equal_approx(w.player.res_max, 4.0), "the Moth-Queen's Scale: four Smoke pips (%.0f)" % w.player.res_max)
	w.player.stats["flags"]["moth_queen_pips"] = 5.0
	_tick(w, {}, 2)
	_check(is_equal_approx(w.player.res_max, 5.0), "and its moth_queen_pips is the number the kit keeps (%.0f)" % w.player.res_max)
	await _free(w)


func _test_gutterlight() -> void:
	var h := Hero.blank("knight")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	h["equip"]["candle"] = Items.make("candle", "knight", 5, "legendary", rng, "gutterlight")
	var s := Hero.stats(h)
	var cd := float(s["cooldown"])
	var p: Node2D = _bare(_flat(), Vector2(100, GROUND))
	p.set_stats(s)
	p.hp = p.max_hp * 0.5
	_check(is_equal_approx(p.basic_cooldown(), cd), "Gutterlight above 35%% life: the usual swing (%.3f)" % p.basic_cooldown())
	p.hp = p.max_hp * 0.3
	_check(is_equal_approx(p.basic_cooldown(), cd / 1.2), "below 35%%: 20%% faster attacks (%.3f s -> %.3f s)" % [cd, p.basic_cooldown()])
	p.pad = {"attack_pressed": true}
	p.step(DT)
	_check(is_equal_approx(p._cooldown, cd / 1.2), "and the swing's cooldown is the faster one (%.3f)" % p._cooldown)
	var plain: Node2D = _bare(_flat(), Vector2(100, GROUND), "knight")
	plain.hp = plain.max_hp * 0.3
	_check(is_equal_approx(plain.basic_cooldown(), float(plain.stats["cooldown"])), "without it, low life changes nothing")
	p.free()
	plain.free()


# ---------------------------------------------------------------- the rig and the real art

func _rigjson(cls: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://art/heroes/%s/rig.json" % cls))
	return parsed if parsed is Dictionary else {}


func _settle(rig: Node2D, n := 12) -> void:
	for i in n:
		rig._process(1.0 / 60.0)


func _test_real_art() -> void:
	## Each calling wears its own art: its weapon and offhand SVGs, placed by
	## its rig.json; the code-drawn stand-ins stay out of it.
	for cls in Classes.ORDER:
		var rd := _rigjson(cls)
		var w := await _world(cls, _flat())
		var rig: Node2D = w.rig
		_check(rig.dir == "res://art/heroes/%s/" % cls, "%s: the rig reads art/heroes/%s/" % [cls, cls])
		var wj: Node2D = rig._joints["sword"]
		_check(rig._sprites.has("sword") and str(rig._sprites["sword"].texture.resource_path).ends_with("/%s/weapon.svg" % cls),
				"%s holds its own weapon.svg" % cls)
		_check(wj.get_node_or_null("standin_weapon") == null, "%s: no code-drawn stand-in weapon" % cls)
		if rd.get("offhand", false):
			_check(rig._sprites.has("offhand") and rig._joints["offhand"].get_node_or_null("standin_offhand") == null,
					"%s carries its own offhand.svg, no stand-in" % cls)
		else:
			_check(not rig._joints.has("offhand"), "%s carries no offhand" % cls)
		var wt: Array = rd.get("weapon_tip", [0, 0])
		var ft: Array = rd.get("flame_tip", [0, 0])
		_check(rig._weapon_tip == Vector2(float(wt[0]), float(wt[1])) and rig.flame_tip == Vector2(float(ft[0]), float(ft[1]))
				and is_equal_approx(rig.weapon_rest, deg_to_rad(float(rd.get("weapon_rest_deg", 80)))),
				"%s: weapon tip, flame tip and rest angle come from rig.json" % cls)
		_check(rig.WEAPON_TIPS[cls] == rig._weapon_tip, "%s: the fallback weapon tip matches the art's measured one" % cls)
		await _free(w)


func _test_capes() -> void:
	## Every cape flares back (a positive turn on the joint, which is how the
	## art shows) running and in the air, both facings, and so do the kits'
	## own flares.
	for cls in Classes.ORDER:
		var w := await _world(cls, _flat())
		var pl: Node2D = w.player
		var rig: Node2D = w.rig
		var cape: Node2D = rig._joints["cape"]
		for f in [1, -1]:
			pl.reset_at(Vector2(900, GROUND))
			pl.facing = f
			_tick(w, {}, 10)
			_tick(w, {"right" if f > 0 else "left": true}, 60)
			_settle(rig)
			var run: float = cape.rotation
			_tick(w, {"jump": true}, 12)
			_settle(rig)
			var up: float = cape.rotation
			_check(run > 0.2 and up > 0.35, "%s (facing %d): the cape flares back running (%.2f) and jumping (%.2f)" % [cls, f, run, up])
			_tick(w, {}, 80)
		await _free(w)
	var w := await _world("knight", _flat())
	w.kit.rushing = 0.1
	_settle(w.rig, 30)
	_check(w.rig._joints["cape"].rotation > 0.8, "the Shield Rush's own flare shows too (%.2f)" % w.rig._joints["cape"].rotation)
	w.kit.rushing = 0.0
	await _free(w)


func _test_weapon_lean() -> void:
	## A staff or spade carried upright at rest doesn't swing back over the
	## face when the arms go up in a jump, a fall or a flinch.
	for cls in ["witch", "sexton"]:
		var w := await _world(cls, _flat())
		var pl: Node2D = w.player
		var rig: Node2D = w.rig
		for f in [1, -1]:
			for what in ["jump", "fall", "hurt"]:
				pl.reset_at(Vector2(600, GROUND))
				pl.facing = f
				pl.hurt_time = 10.0
				pl.invuln = 0.0
				_tick(w, {}, 20)
				match what:
					"jump":
						_tick(w, {"jump": true}, 16)
					"fall":
						_tick(w, {"jump": true}, 60)
						_tick(w, {}, 30)
					"hurt":
						pl.take_damage(1.0, pl.position.x + f * 16.0, "hit", null, {})
						_tick(w, {}, 6)
				_settle(rig, 1)
				var d: Vector2 = rig.weapon_point() - rig.hand_point()
				var ang := atan2(d.x * f, -d.y)   # 0 = straight up, + = leaning forward
				_check(ang > 0.25, "%s (facing %d, %s): the weapon leans forward of plumb (%.2f rad)" % [cls, f, what, ang])
				_tick(w, {}, 90)
		await _free(w)
	# On the run the arm swings back and forth; the weapon stays leaning
	# forward (the witch's staff, carried near upright, would cross her
	# face), and the others keep their carry.
	for cls in Classes.ORDER:
		var w := await _world(cls, _flat(200))
		var pl: Node2D = w.player
		var rig: Node2D = w.rig
		var least: float = rig.WEAPON_LEAN - 0.02
		for f in [1, -1]:
			pl.reset_at(Vector2(3000 if f < 0 else 300, GROUND))
			pl.facing = f
			pl.hurt_time = 10.0
			_tick(w, {}, 20)
			var lo := 9.0
			for i in 240:
				_tick(w, {"right" if f > 0 else "left": true})
				rig._process(DT)
				if i < 60:
					continue
				var d: Vector2 = rig.weapon_point() - rig.hand_point()
				lo = minf(lo, atan2(d.x * f, -d.y))
			_check(lo >= least, "%s (facing %d) running: the weapon leans forward of plumb all stride (least %.2f rad, rest %.2f)" % [cls, f, lo, rig.weapon_rest])
			# ...and standing, the staff is carried at its own rest again.
			_tick(w, {}, 90)
			rig._process(DT)
			var carry: float = rig._joints["sword"].rotation + rig._joints["arm_front"].rotation
			_check(absf(carry - rig.weapon_rest) < 0.06, "%s (facing %d) at a stand carries it at its rest angle (%.2f, rest %.2f)" % [cls, f, carry, rig.weapon_rest])
		await _free(w)
	# The Knell swings the handbell about plumb (the art hangs it 45 deg back).
	var w := await _world("sexton", _flat())
	var pl: Node2D = w.player
	var rig: Node2D = w.rig
	pl.reset_at(Vector2(300, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.res = 100.0
	_tick(w, {"special": true}, 1)
	_tick(w, {}, 2)
	var sum := 0.0
	var lo := 9.0
	var hi := -9.0
	for i in 40:
		_tick(w, {}, 1)   # the swing runs on the kit's clock
		rig._process(0.0)
		var r: float = rig._joints["offhand"].rotation + deg_to_rad(45.0)
		sum += r
		lo = minf(lo, r)
		hi = maxf(hi, r)
	_check(absf(sum / 40.0) < 0.12 and lo < -0.2 and hi > 0.2, "the Knell swings the bell about plumb (mean %.2f, %.2f..%.2f rad)" % [sum / 40.0, lo, hi])
	await _free(w)


func _test_shield_clear() -> void:
	## The knight's shield is worn in front of the body, so a back arm thrown
	## up in a jump, a fall or a flinch would hold it over his face: it rides
	## at his chest there instead. A raised guard (the kit's own pose) still
	## lifts it, and in a Ledge Grab it goes up behind his head.
	var w := await _world("knight", _flat())
	var pl: Node2D = w.player
	var rig: Node2D = w.rig
	var head: Node2D = rig._joints["head"]
	var off: Node2D = rig._joints["offhand"]
	for f in [1, -1]:
		for what in ["jump", "fall", "hurt"]:
			pl.reset_at(Vector2(600, GROUND))
			pl.facing = f
			pl.hurt_time = 10.0
			pl.invuln = 0.0
			_tick(w, {}, 20)
			match what:
				"jump":
					_tick(w, {"jump": true}, 16)
				"fall":
					_tick(w, {"jump": true}, 60)
					_tick(w, {}, 30)
				"hurt":
					pl.take_damage(1.0, pl.position.x + f * 16.0, "hit", null, {})
					_tick(w, {}, 6)
			_settle(rig, 1)
			var below: float = rig.hand_point(true).y - head.global_position.y
			_check(below > 4.0 and off.get_index() > head.get_index(),
					"knight (facing %d, %s): the shield rides below his face (%.1f px under the head's joint)" % [f, what, below])
			_tick(w, {}, 90)
	pl.reset_at(Vector2(600, GROUND))
	pl.facing = 1
	_tick(w, {}, 20)
	pl.res = pl.res_max
	_tick(w, {"special": true}, 30)
	_settle(rig, 1)
	_check(w.kit.guarding and rig._joints["arm_back"].rotation < -1.3, "a raised guard still lifts the shield (%.2f rad)" % rig._joints["arm_back"].rotation)
	_tick(w, {}, 30)
	pl.set("_ledge_from", pl.position)
	pl.set("_ledge_to", pl.position)
	pl.ledge_t = 0.05
	_settle(rig, 1)
	_check(off.get_index() < head.get_index(), "in a Ledge Grab the shield goes up behind his head")
	pl.ledge_t = -1.0
	_settle(rig, 1)
	_check(off.get_index() > head.get_index(), "and comes back in front of him after")
	await _free(w)


func _test_dash_reset() -> void:
	## Put back out of lava in the middle of a move, nothing of the move rides
	## along: a Smoke Step's invulnerability ends (the next blow lands), a
	## Shield Rush stops, and an Anvil Drop doesn't slam where she lands.
	var lv := _flat()
	var w := await _world("runner", lv)
	var pl: Node2D = w.player
	pl.reset_at(Vector2(600, GROUND))
	pl.facing = 1
	_tick(w, {}, 20)
	pl.res = pl.res_max
	_tick(w, {"right": true}, 4)
	_tick(w, {"right": true, "special": true}, 3)
	_check(pl.dash_time > 0.0 and pl.dash_flags.get("invuln", false), "mid Smoke Step she is untouchable")
	w.fell("lava")
	_check(pl.alive and pl.dash_flags.is_empty() and w.kit.stepping <= 0.0, "put back out of the lava, the step is over (flags %s)" % str(pl.dash_flags))
	_tick(w, {}, 240)
	pl.invuln = 0.0
	var hp0: float = pl.hp
	_check(pl.take_damage(10.0, pl.position.x + 16.0, "hit", null, {}) and pl.hp < hp0, "and the next blow lands (%.1f -> %.1f)" % [hp0, pl.hp])
	# A Smoke Step run to its end leaves nothing behind either.
	_tick(w, {}, 120)
	pl.res = pl.res_max
	_tick(w, {"right": true, "special": true}, 3)
	_tick(w, {}, 60)
	_check(pl.dash_time <= 0.0 and pl.dash_flags.is_empty(), "a finished Smoke Step clears its flags")
	await _free(w)
	w = await _world("knight", lv)
	pl = w.player
	pl.reset_at(Vector2(600, GROUND))
	pl.facing = 1
	_tick(w, {}, 20)
	pl.res = pl.res_max
	_tick(w, {"right": true, "special": true}, 3)
	_check(w.kit.rushing > 0.0, "mid Shield Rush")
	w.fell("lava")
	_check(w.kit.rushing <= 0.0 and pl.dash_flags.is_empty(), "put back, the rush is over")
	await _free(w)
	w = await _world("founder", lv)
	pl = w.player
	pl.reset_at(Vector2(600, GROUND))
	_tick(w, {}, 20)
	pl.res = pl.res_max
	_tick(w, {"jump": true}, 30)
	_tick(w, {"special": true}, 1)
	_tick(w, {}, 2)
	_check(w.kit.anvil and pl.dash_time > 0.0, "mid Anvil Drop")
	w.fell("lava")
	var waves := 0
	for i in 120:
		_tick(w, {})
		for h in w.hazards:
			if h["kind"] == "wave" and h["owner"] == "player":
				waves += 1
	_check(pl.on_floor and not w.kit.anvil and waves == 0 and pl.dash_flags.is_empty(),
			"put back out of the lava, she lands without a free Peal (%d wave ticks)" % waves)
	await _free(w)


func _test_gear() -> void:
	## Visible gear: the candle grows with its tier about its seat on the head
	## (the flame riding it), a Blessed / Rare / Legendary coat tints the cape,
	## and a Legendary weapon glints; read from the hero the calling belongs to.
	var w := await _world("witch", _flat())
	var rig: Node2D = w.rig
	var candle: Node2D = rig._joints["candle"]
	var seat_of := func() -> Vector2: return candle.to_global((rig._candle_base - rig.PIVOTS["candle"]) * 0.5)
	rig.gear_auto = false
	rig.set_gear({})
	var seat0: Vector2 = seat_of.call()
	var flame0: Vector2 = rig.flame_point()
	rig.set_gear({"candle_tier": 3})
	_check(is_equal_approx(candle.scale.x, 1.15) and seat_of.call().distance_to(seat0) < 0.01, "a tier 3 candle is 1.15x, still seated on her hat")
	_check(rig.flame_point().y < flame0.y - 0.5, "and its flame burns higher (%.1f px)" % (flame0.y - rig.flame_point().y))
	rig.set_gear({"candle_tier": 1})
	_check(is_equal_approx(candle.scale.x, 0.85) and seat_of.call().distance_to(seat0) < 0.01, "a tier 1 candle is 0.85x")
	rig.set_gear({"coat_rarity": "rare"})
	var tint: Color = rig._sprites["cape"].modulate
	_check(tint != Color.WHITE and tint.b < tint.r, "a Rare coat warms the cape toward gold (%s)" % tint)
	rig.set_gear({"coat_rarity": "common"})
	_check(rig._sprites["cape"].modulate == Color.WHITE, "a Common coat leaves it as drawn")
	_check(not rig._glint.visible, "an ordinary weapon doesn't glint")
	rig.set_gear({"weapon_legend": true})
	_check(rig._glint.visible, "a Legendary weapon does")
	# From the save: equip a Legendary weapon and the rig shows it within half a second.
	rig.gear_auto = true
	rig.set_gear({})
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	game.equip(Items.make("weapon", "witch", 22, "legendary", rng, "dawnsliver"))
	w.apply_hero()
	_settle(rig, 40)
	_check(rig._glint.visible and is_equal_approx(candle.scale.x, 0.85), "gear is read from the hero (glint on, starter candle 0.85x)")
	await _free(w)
