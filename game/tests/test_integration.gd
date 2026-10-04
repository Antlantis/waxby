extends SceneTree
## The seams between the parts, played for real: every level (1-1 to 2-4)
## with every calling, in the real World with its HUD, touch layer, sounds
## and the calling's kit, driven by a simple two-thumb bot (hold the way on:
## right, left in a level facing left, a taller level's by its route field;
## jump on a timer, swing and use the Special often, drink the flask when
## low; _test_bot_ways proves its ways on the shape labs).
## Then each boss fought by each calling. Checks: no script errors (a
## Logger catches them) and no unknown sound names; the hero deals damage;
## Specials fire and cost their resource; XP and embers come in; items drop
## and are taken; a level-up happens; Tollgrave and the Snuffer take damage
## from every calling. Then the world-side hand-offs one by one: a full
## satchel, Thornsole, Cinderstep, Tollbreaker, a Special let go and pressed
## again inside a freeze, the first-hurt bark, the low-pass on leaving, the
## crit sound, hazard shadows, the Snuffer's "Lights Out" bark, and small
## flames far along a level drawing without the renderer refusing them.
##
##     godot --headless --path game --script res://tests/test_integration.gd
## WAXBY_FAST=1 plays shorter runs; WAXBY_DEBUG=1 prints each boss fight.
## Script errors, push_error()s and unknown sound or monster names fail.
## So does a draw call the renderer refuses (a polygon it can't triangulate)
## when the line that made it is in one of the world's own scripts; one made
## in another part's script is printed as a notice naming that script, for
## its owner.

const LevelData := preload("res://scripts/level_data.gd")
const Progression := preload("res://scripts/progression.gd")
const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const Classes := preload("res://scripts/classes.gd")
const DT := 1.0 / 120.0
const LEVELS := ["1-1", "1-2", "1-3", "1-4", "2-1", "2-2", "2-3", "2-4"]
const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
# The hero's level coming into each level on a first Dusk run (W2's pacing).
const ENTRY := {"1-1": 1, "1-2": 3, "1-3": 5, "1-4": 7, "2-1": 8, "2-2": 10, "2-3": 11, "2-4": 12,
		"3-1": 13, "3-2": 14, "3-3": 15, "3-4": 17, "4-1": 18, "4-2": 19, "4-3": 20, "4-4": 21,
		"5-1": 23, "5-2": 23, "5-3": 24, "5-4": 26, "6-1": 27, "6-2": 28, "6-3": 29, "6-4": 30}
# World 3 to 6 (the wave-2 merges), played the same way when their files are
# in the build, after v2's levels. Their lines print as "  v3 <calling> ..."
# so tools/play_identity.py's W1-W2 comparison reads v2's alone.
const V3_LEVELS := ["3-1", "3-2", "3-3", "3-4", "4-1", "4-2", "4-3", "4-4", "5-1", "5-2", "5-3", "5-4", "6-1", "6-2", "6-3", "6-4"]
const RANGED := ["witch", "runner"]

var WorldScript: GDScript   # loaded at run time: it needs the autoloads
var game: Node
var sfx: Node
var catch: Catch
var _passed := 0
var _failed := 0
var _run_s := 30.0
var _boss_s := 28.0
var rng := RandomNumberGenerator.new()


class Catch extends Logger:
	## Every script error, engine error and the warnings that mean a seam
	## is wrong (a sound or monster name nobody has).
	# The world's own scripts: a render refusal made from one of these fails.
	const WORLD_FILES := ["world.gd", "glow.gd", "boss.gd", "boss_arena.gd", "floaters.gd",
		"playlog.gd", "actor.gd", "combat.gd", "enemy.gd"]
	var errors: Array = []
	var warnings: Array = []
	var notices: Array = []         # render refusals made in other parts' scripts: printed
	var renders := 0                # every render refusal, wherever it was made
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := "%s:%d %s %s %s" % [file, line, function, code, rationale]
		# Where in the scripts it came from (an engine error names only C++):
		# the top frame is the line that made the call.
		var top := ""
		for bt in script_backtraces:
			if bt != null and not bt.is_empty():
				var frames := []
				for i in mini(bt.get_frame_count(), 3):
					frames.append("%s:%d %s" % [bt.get_frame_file(i), bt.get_frame_line(i), bt.get_frame_function(i)])
				text += "  <- " + " <- ".join(frames)
				top = bt.get_frame_file(0).get_file()
				break
		_lock.lock()
		if error_type == ERROR_TYPE_WARNING:
			if code.contains("no sound named") or code.contains("no script for") or code.contains("no music track"):
				warnings.append(text)
		elif error_type != ERROR_TYPE_SCRIPT and file.begins_with("servers/rendering"):
			# A draw call the renderer turned down (a polygon it couldn't
			# triangulate): a failure when the world's scripts made it, else
			# a notice for the script's owner.
			renders += 1
			if top in WORLD_FILES:
				errors.append(text)
			else:
				notices.append("(%s) %s" % [top if top != "" else "no script line", text])
		else:
			errors.append(text)
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func count() -> int:
		_lock.lock()
		var n := errors.size() + warnings.size()
		_lock.unlock()
		return n

	func since(n: int) -> Array:
		_lock.lock()
		var all := errors + warnings
		_lock.unlock()
		return all.slice(n)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	catch = Catch.new()
	OS.add_logger(catch)
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	sfx = root.get_node_or_null("Sfx")
	rng.seed = 11
	if OS.get_environment("WAXBY_FAST") != "":
		_run_s = 12.0
		_boss_s = 16.0
	if game == null:
		_check(false, "the Game autoload is there")
		quit(1)
		return
	game.save_path = "user://test_integration_save.json"
	game.reset()
	var auto_equip = game.setting("auto_equip")
	var t0 := Time.get_ticks_msec()
	await _test_play_all()
	await _test_bot_ways()
	await _test_full_satchel()
	await _test_legends()
	await _test_special_in_freeze()
	await _test_world_hooks()
	await _test_small_flames()
	await _test_v3_boss_levels()
	await _test_v3_boss_rewake()
	await _test_v3_dread_gifts()
	game.set_setting("auto_equip", auto_equip)
	var leftover := catch.since(0)
	_check(leftover.is_empty(), "no script errors and no unknown sounds anywhere (%d)" % leftover.size())
	for e in leftover.slice(0, 12):
		print("  ! ", e)
	for e in catch.notices.slice(0, 6):
		print("  (render notice, not a world script) ", e)
	print("test_integration: %d passed, %d failed (%.0f s)" % [_passed, _failed, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- set-up

func _world(id: String, headless := false) -> Node2D:
	## The real World for a level, story beats already seen (so no overlay
	## pauses the bot). Its physics tick is ours to call.
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	for k in ["start", "boss"]:
		var s := str(lv.story.get(k, ""))
		if s != "":
			game.mark_seen(s)
	var w: Node2D = WorldScript.new()
	w.setup(lv, headless)
	root.add_child(w)
	w.set_physics_process(false)
	return w


func _hero_for(cls: String, level_id: String) -> void:
	## The calling's hero at (at least) its entry level for this level, a
	## few XP short of the next, so the level's first kill levels it up.
	game.new_hero(cls)
	var h: Dictionary = game.hero()
	var want: int = maxi(int(h["level"]), int(ENTRY[level_id]))
	var target := Progression.total_to(want + 1) - 3
	if int(h["xp"]) < target:
		game.add_xp(target - int(h["xp"]))
	if V3_LEVELS.has(level_id) and (h["satchel"] as Array).size() >= 12:
		# Sixteen levels a calling fill the 16-slot satchel (a full one turns
		# the level's drops away): World 3 and 4's runs start with room, as
		# a player who sold at the Chandler would. v2's runs are as before.
		h["satchel"] = (h["satchel"] as Array).slice(0, 8)


func _step(w: Node2D, pad: Dictionary) -> void:
	w.test_pad = pad
	w._read_pad()
	w.tick(DT)


# ---------------------------------------------------------------- the bot

class Bot:
	## Two thumbs: the left one holds the way on (backing off and hopping
	## when stuck), the right one taps jump on a beat, swings, and presses
	## the Special for 0.6 s every couple of seconds. The flask when low. The
	## way on is right, as v2's held; a level played right to left (facing:
	## left) holds left, and a taller one heads the way its route field goes
	## (route_field.gd heading, as autoplay_bot.gd's _route_pad: right round
	## a loop, up a tower), its last way kept where it says none.
	var i := 0
	var dir := 1                    # the way on: 1 right, -1 left
	var field: RefCounted = null    # a taller level's route field toward its goal
	var cls := ""
	var last_x := 0.0
	var unstick := 0
	var stuck_n := 0
	var flask_press := false
	var special_down := false
	var target: Node2D = null       # a boss to fight instead of running right
	var want := 34.0
	var ranged := false
	var back_len := 20
	var wait := 0                   # ticks to stand still (a dropped item landing)
	var rng := RandomNumberGenerator.new()

	func _way(pl: Node2D) -> int:
		## The way on now: a taller level's route field's heading, else dir.
		if field != null:
			var hd: Vector2i = field.heading(pl.position)
			if hd.x != 0:
				dir = 1 if hd.x > 0 else -1
		return dir

	func _foe_ahead(w: Node2D, pl: Node2D) -> Node2D:
		## The nearest live monster just ahead at about his height.
		var reach := 230.0 if ranged else 70.0
		var best: Node2D = null
		var bd := reach
		for e in w.enemies:
			if not e.alive or not e.active or e == w.boss:
				continue
			var dx: float = (e.position.x - pl.position.x) * dir
			if dx < -6.0 or dx > bd or absf(e.center().y - pl.center().y) > 44.0:
				continue
			bd = dx
			best = e
		return best

	func _loot_near(w: Node2D, pl: Node2D) -> Dictionary:
		## An item lying close by at about his height (not one a full
		## satchel turned away).
		for p in w.pickups:
			if p["kind"] != "item" or p["taken"] or p.get("full", false) or float(p["age"]) < 0.3:
				continue
			var d: Vector2 = p["pos"] - pl.position
			if absf(d.x) < 200.0 and d.y > -44.0 and d.y < 8.0:
				return p
		return {}

	func pad(w: Node2D) -> Dictionary:
		i += 1
		var pl: Node2D = w.player
		var p := {}
		var t := i * DT
		_way(pl)
		var fwd := "right" if dir > 0 else "left"
		var bwd := "left" if dir > 0 else "right"
		var foe: Node2D = null if target != null else _foe_ahead(w, pl)
		var loot: Dictionary = {} if target != null else _loot_near(w, pl)
		if not loot.is_empty() and foe == null and unstick <= 0:
			# Loot on the floor near him: walk over to it (no hopping).
			var lx: float = loot["pos"].x - pl.position.x
			p["right"] = lx > 4.0
			p["left"] = lx < -4.0
		elif foe != null and unstick <= 0:
			# Something in the way: stand and fight it (a stomp now and then).
			var dx: float = (foe.position.x - pl.position.x) * dir
			p[fwd] = dx > (110.0 if ranged else 26.0) or (i / 30) % 4 == 0
			p["jump"] = (i / 45) % 5 == 0 and not ranged
		elif target != null and is_instance_valid(target) and target.alive:
			var dx: float = target.center().x - pl.position.x
			if dx > want:
				p["right"] = true
			elif dx < -want:
				p["left"] = true
			elif i % 36 == 0:
				p["right" if dx > 0.0 else "left"] = true   # a nudge to face him
			p["jump"] = fmod(t, 1.15) < 0.28
			if pl.on_floor and pl.position.y < target.position.y - 24.0:
				# On a ledge over him: down + jump drops through it.
				p["down"] = true
				p["jump"] = (i / 6) % 2 == 0
		else:
			if i % 96 == 0:
				if absf(pl.position.x - last_x) < 12.0 and pl.on_floor:
					# Stuck at a wall: back off a random way, then run and
					# jump at it with the jump held (onto a ledge, or over).
					back_len = rng.randi_range(12, 90)
					unstick = back_len + 70
					stuck_n += 1
				last_x = pl.position.x
			if unstick > 0:
				unstick -= 1
				var back := unstick > 70
				p[bwd] = back
				p[fwd] = not back
				p["jump"] = not back and unstick > 8 and (unstick < 62 or (stuck_n % 3 == 2 and unstick < 68))
			else:
				p[fwd] = true
				p["jump"] = fmod(t, 0.9) < 0.34 or (stuck_n % 2 == 1 and fmod(t, 0.9) < 0.6)
		if wait > 0:
			wait -= 1
			p = {}
		p["attack"] = (i / 14) % 2 == 0
		special_down = fmod(t, 2.2) < 0.6
		p["special"] = special_down
		var low: bool = pl.alive and pl.life_frac() < 0.4 and int(w.flask_charges) > 0
		p["flask"] = low and not flask_press
		flask_press = p["flask"]
		return p


# ---------------------------------------------------------------- play every level

func _test_play_all() -> void:
	var totals := {}
	var natural_drops := 0
	for cls in CALLINGS:
		game.reset()
		totals[cls] = {"dealt": 0.0, "presses": 0, "spent": 0, "xp": 0, "embers": 0, "drops": 0, "taken": 0, "levels": 0}
		for id in LEVELS + V3_LEVELS.filter(func(v): return FileAccess.file_exists("res://levels/%s.txt" % v)):
			var only := OS.get_environment("WAXBY_ONLY")   # (debug: "witch:4-3" plays that run alone)
			if only != "" and only != "%s:%s" % [cls, id]:
				continue
			_hero_for(cls, id)
			var r: Dictionary = await _play(cls, id)
			for k in ["dealt", "presses", "spent", "xp", "embers", "drops", "taken", "levels"]:
				totals[cls][k] += r[k]
			natural_drops += int(r["natural"])
			print("  %s%-7s %s: dealt %5.0f, specials %d/%d spent, xp %4d, embers %2d, items %d/%d taken, +%d lv, x %4.0f, snuffs %d%s" % [
					"v3 " if V3_LEVELS.has(id) else "", cls, id, r["dealt"], r["spent"], r["presses"], r["xp"], r["embers"], r["taken"], r["drops"], r["levels"],
					r["far"], r["snuffs"], ("  boss -%.0f" % r["boss"]) if r.has("boss") else ""])
			_check(r["errors"].is_empty(), "%s on %s: no script errors (%s)" % [cls, id, "; ".join(r["errors"].slice(0, 3))])
			_check(r["dealt"] > 0.0, "%s on %s: the hero deals damage" % [cls, id])
			_check(r["taken"] >= 1, "%s on %s: an item drops and is taken (%d of %d)" % [cls, id, r["taken"], r["drops"]])
			# The results screen's "found" count: the level's own embers,
			# never more than it holds, whatever the fighting paid.
			_check(r["own"] >= 0 and r["own"] <= r["own_total"],
					"%s on %s: the level's own embers found stay within its total (%d / %d, %d in the purse)" % [cls, id, r["own"], r["own_total"], r["embers"]])
			if r.has("boss"):
				_check(r["boss"] > 0.0, "%s: %s takes damage from the %s (%.0f)" % [id, r["boss_name"], Classes.info(cls)["name"], r["boss"]])
		var tt: Dictionary = totals[cls]
		var name: String = Classes.info(cls)["name"]
		_check(tt["spent"] >= 3, "the %s's Special fires and costs its %s (%d of %d presses)" % [name, Classes.info(cls)["res_name"], tt["spent"], tt["presses"]])
		_check(tt["xp"] > 0, "the %s earns XP (%d)" % [name, tt["xp"]])
		_check(tt["embers"] > 0, "the %s picks up embers (%d)" % [name, tt["embers"]])
		_check(tt["levels"] >= 1, "the %s levels up somewhere (%d)" % [name, tt["levels"]])
	_check(natural_drops > 0, "monsters drop items on their own (%d)" % natural_drops)


func _play(cls: String, id: String) -> Dictionary:
	var n0 := catch.count()
	var w := _world(id)
	await process_frame
	var pl: Node2D = w.player
	_check(w.kit != null and str(w.kit.cls) == cls, "%s on %s: the %s kit is on" % [cls, id, cls])
	var bot := _bot_for(w)
	bot.cls = cls
	bot.ranged = cls in RANGED
	bot.rng.seed = hash(cls + id)
	var hp_seen := {}
	var r := {"dealt": 0.0, "presses": 0, "spent": 0, "drops": 0, "taken": 0, "natural": 0, "far": 0.0}
	var uids := {}
	var watch: Array = []            # Special presses being watched: {res, min, left}
	var was_down := false
	var forced := false
	var ticks := int(_run_s / DT)
	# One Rattle a few tiles ahead on firm floor (the way on), so every run
	# has a fight in its first seconds (the level's own monsters come after).
	var cell := _floor_ahead(w, pl.position, 4, 9, bot._way(pl))
	if cell.x >= 0:
		var rattle: Node2D = w.spawn_enemy("skeleton", LevelData.cell_floor(cell), {"cell": cell})
		if rattle:
			rattle.facing = -bot.dir
	for i in ticks:
		var under: int = w.level.tile(floori(pl.position.x / 32.0), floori((pl.position.y + 2.0) / 32.0))
		if i >= 90 and not forced and pl.alive and pl.on_floor and pl.riding == null and w.state == "play" \
				and LevelData.is_solid(under) and not LevelData.is_slick(under):
			# One item from the world's own roller dropped at his feet (he
			# waits a moment for it), so the pickup path always runs. Not on
			# ice (World 4): he'd slide on past it while he waits.
			forced = true
			w.drop_item(pl.position + Vector2(0, -30.0), "kill")
			w.pickups[w.pickups.size() - 1]["vel"] = Vector2.ZERO
			bot.wait = 60
			if OS.get_environment("WAXBY_DEBUG") != "":
				print("    forced drop at %s (tick %d)" % [pl.position, i])
		var p := bot.pad(w)
		var res0: float = pl.res
		if bot.special_down and not was_down and w.state == "play" and pl.alive:
			r["presses"] += 1
			watch.append({"res": res0, "min": res0, "left": 84})
		was_down = bot.special_down
		_step(w, p)
		_observe(w, hp_seen, r, uids)
		for wt in watch:
			wt["min"] = minf(wt["min"], pl.res)
			wt["left"] -= 1
			if wt["left"] <= 0 and wt["min"] < wt["res"] - maxf(0.2, 0.01 * pl.res_max):
				r["spent"] += 1
		watch = watch.filter(func(wt): return wt["left"] > 0)
		r["far"] = maxf(r["far"], pl.position.x * bot.dir)
		if i % 40 == 0:
			await process_frame
		if w.state == "clear":
			break
	if forced and w.items_found.is_empty() and w.state == "play" and pl.alive:
		# A monster or a snuff took him away from the dropped item (World 4's
		# busier starts): walk him onto it, so the pickup path still runs.
		for p in w.pickups:
			if p["kind"] == "item":
				pl.reset_at(p["pos"] as Vector2)
				for k in 30:
					_step(w, {})
				break
	r["natural"] = maxi(r["drops"] - 1, 0)
	if w.boss != null and is_instance_valid(w.boss):
		r["boss"] = await _fight(w, cls, bot, hp_seen, r, uids)
		r["boss_name"] = str(w.boss.get("boss_name")) if is_instance_valid(w.boss) else "the boss"
	r["xp"] = w.xp_gained
	r["embers"] = w.embers_got
	var res: Dictionary = w.result()
	r["own"] = int(res.get("embers_placed", -1))
	r["own_total"] = int(res.get("embers_total", -1))
	r["levels"] = w.levels_gained
	r["snuffs"] = w.snuffs
	r["taken"] = w.items_found.size()
	w.queue_free()
	await process_frame
	await process_frame
	r["errors"] = catch.since(n0)
	return r


func _bot_for(w: Node2D) -> Bot:
	## The two-thumb bot for a World's level: its way on right, facing left
	## left; a taller level's by its route field toward the bell (or the boss
	## arena), as autoplay_bot.gd builds it.
	var bot := Bot.new()
	bot.dir = int(w.level.facing)
	if w.level.tall():
		var Reach = load("res://scripts/reach.gd")
		var goal := {}
		for g in Reach.goals_of(w.level):
			if g["what"] == "bell" or g["what"] == "boss arena":
				goal = g
		if not goal.is_empty():
			bot.field = load("res://scripts/route_field.gd").new().build(Reach.static_copy(w.level), goal, Reach.drops_of(w.level))
	return bot


func _floor_ahead(w: Node2D, feet: Vector2, from: int, to: int, dir := 1) -> Vector2i:
	## The first air cell on solid floor at his height, from..to tiles ahead
	## (dir: the way on).
	var lv = w.level
	var y := floori((feet.y - 1.0) / 32.0)
	var x0 := floori(feet.x / 32.0)
	for dx in range(from, to + 1):
		var x := x0 + dx * dir
		if lv.tile(x, y) == LevelData.AIR and lv.tile(x, y - 1) == LevelData.AIR and LevelData.is_solid(lv.tile(x, y + 1)):
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _observe(w: Node2D, hp_seen: Dictionary, r: Dictionary, uids: Dictionary) -> void:
	## Damage dealt (life lost by every monster, a boss reset aside) and
	## item pickups seen.
	for e in w.enemies:
		var k: int = e.get_instance_id()
		var hp: float = e.hp
		if hp_seen.has(k) and hp < hp_seen[k]:
			r["dealt"] += hp_seen[k] - hp
		hp_seen[k] = hp
	for p in w.pickups:
		if p["kind"] == "item":
			var u := str(p["item"].get("uid", ""))
			if not uids.has(u):
				uids[u] = true
				r["drops"] += 1


func _fight(w: Node2D, cls: String, bot: Bot, hp_seen: Dictionary, r: Dictionary, uids: Dictionary) -> float:
	## Into the arena: face the boss and fight him (again after a snuff).
	var b: Node2D = w.boss
	var pl: Node2D = w.player
	var floor_y: float = float(b.get("floor_y")) if b.get("floor_y") != null else b.position.y
	var door := Vector2(float(b.arena_left) + 80.0, floor_y)
	var own_pad: bool = b.has_method("bot_pad")
	if own_pad:
		# The Saint and the Hush fight by their own rules (their bot_pad, as
		# the --autoplay bot plays them): in on the arena's entry footing.
		var dc := floori(float(b.arena_left) / 32.0) + 1   # (inside: the loop below puts him back past arena_left)
		for ty in range(2, w.level.height):
			if LevelData.is_solid(w.level.tile(dc, ty)):
				door = Vector2(dc * 32.0 + 16.0, ty * 32.0)
				break
	pl.reset_at(door)
	pl.hp = pl.max_hp
	w.cam = w._clamp_cam(pl.position)
	bot.target = b
	bot.want = 150.0 if cls in RANGED else 30.0
	var dealt := 0.0
	var last: float = b.hp
	var dead_t := 0
	for i in int(_boss_s / DT):
		if not is_instance_valid(b) or not b.alive:
			break
		if w.state == "play" and pl.alive and pl.position.x < float(b.arena_left) - 8.0:
			# Snuffed and relit back at the altar: straight back in.
			pl.reset_at(door)
			w.cam = w._clamp_cam(pl.position)
		var pad: Dictionary = {}
		if own_pad and is_instance_valid(b) and b.alive and pl.alive:
			pad = b.bot_pad(pl)
		_step(w, pad if not pad.is_empty() else bot.pad(w))
		_observe(w, hp_seen, r, uids)
		if is_instance_valid(b):
			if b.hp < last:
				dealt += last - b.hp
			last = b.hp
		if w.state == "dead":
			dead_t += 1
		if OS.get_environment("WAXBY_DEBUG") != "" and i % 120 == 0 and is_instance_valid(b):
			print("    t=%4.1f boss %s hp %.0f/%.0f at %.0f  hero x %.0f y %.0f hp %.0f alive %s state %s  arena %.0f-%.0f" % [i * DT, b.get("state"), b.hp, b.max_hp, b.position.x, pl.position.x, pl.position.y, pl.hp, pl.alive, w.state, b.arena_left, b.arena_right])
		if i % 40 == 0:
			await process_frame
	return dealt


# ---------------------------------------------------------------- the full satchel

func _test_bot_ways() -> void:
	## The two-thumb bot holds the way on: right to left in a level facing
	## left (the shapes' mirror lab, 4-3's way), its warm-up Rattle on that
	## side, and a fight; round a taller level's loop by its route field
	## (right along the bottom, then up and back left over it).
	var cls := "knight"
	game.reset()
	game.new_hero(cls)
	var w := _world("lab-shape-mirror")
	await process_frame
	var pl: Node2D = w.player
	var bot := _bot_for(w)
	bot.cls = cls
	var x0: float = pl.position.x
	var cell := _floor_ahead(w, pl.position, 4, 9, bot._way(pl))
	_check(bot.dir == -1 and cell.x >= 0 and cell.x < floori(x0 / 32.0), "facing left: the way on is left, the warm-up Rattle's floor on that side (%d, %s)" % [bot.dir, cell])
	var rattle: Node2D = w.spawn_enemy("skeleton", LevelData.cell_floor(cell), {"cell": cell})
	var hp_seen := {}
	var r := {"dealt": 0.0, "drops": 0}
	for i in int(8.0 / DT):
		pl.invuln = 5.0
		_step(w, bot.pad(w))
		_observe(w, hp_seen, r, {})
	_check(pl.position.x < x0 - 200.0 and float(r["dealt"]) > 0.0, "it heads left and fights (%.0f px, dealt %.0f)" % [x0 - pl.position.x, r["dealt"]])
	_check(rattle != null and (not rattle.alive or float(rattle.hp) < float(rattle.max_hp)), "the Rattle it meets on the way is hit")
	w.queue_free()
	await process_frame
	game.reset()
	game.new_hero(cls)
	w = _world("lab-shape-loop")
	await process_frame
	pl = w.player
	bot = _bot_for(w)
	bot.cls = cls
	var far0: int = bot.field.at(pl.position)
	var best := far0
	for i in int(25.0 / DT):
		pl.invuln = 5.0
		pl.hp = pl.max_hp
		_step(w, bot.pad(w))
		best = mini(best, bot.field.at(pl.position))
	_check(bot.field != null and best < far0 - 40, "a taller level: by its route field round the loop (%d moves from the bell at the start, %d at best)" % [far0, best])
	w.queue_free()
	await process_frame
	game.reset()


func _test_full_satchel() -> void:
	## Satchel full, auto-equip off: a better item stays on the ground with
	## its beam and a "Satchel full" card, asks again only after he steps
	## off and back, and a tap on the card wears it and lifts it off the
	## ground. A Rare no better than what's worn melts into embers.
	game.reset()
	game.new_hero("knight")
	game.set_setting("auto_equip", false)
	var w := _world("1-1")
	await process_frame
	var pl: Node2D = w.player
	var hud = w.hud
	for i in 60:
		_step(w, {})
	var h: Dictionary = game.hero()
	while (h["satchel"] as Array).size() < int(game.SATCHEL_MAX):
		game.add_item(Items.make("coat", "knight", 1, "magic", rng))
	_check((h["satchel"] as Array).size() == int(game.SATCHEL_MAX), "the satchel is full (%d)" % (h["satchel"] as Array).size())
	var legend := Items.pick_legend("candle", "knight", rng)
	var it := Items.make("candle", "knight", 12, "legendary" if legend != "" else "rare", rng, legend)
	var p: Dictionary = w.place_item(it, pl.position + Vector2(0, -20), Vector2.ZERO)
	var cards0: int = _full_cards(hud)
	for i in 60:
		_step(w, {})
	_check(not p["taken"] and p.get("full", false), "a better item with no room stays on the ground")
	_check(w.pickups.has(p) and p.has("sprite"), "with its sprite (and beam)")
	_check(not w.items_found.has(it), "and isn't counted as found")
	_check(_full_cards(hud) == cards0 + 1, "the card says the satchel is full (%d)" % (_full_cards(hud) - cards0))
	for i in int(2.0 / DT):
		_step(w, {})
	_check(_full_cards(hud) == cards0 + 1, "standing on it doesn't ask again and again (%d)" % (_full_cards(hud) - cards0))
	var at: Vector2 = pl.position
	pl.position = at + Vector2(-120, 0)
	# The HUD shows one "full" card per item at most every FULL_GAP seconds.
	for i in int((float(hud.FULL_GAP) + 0.5) / DT):
		_step(w, {})
	pl.position = at
	for i in 10:
		_step(w, {})
	_check(_full_cards(hud) >= 1 and _t_now(hud) - float(hud._full_seen.get(str(it["uid"]), -100.0)) < 0.5,
			"stepping off and back (after the HUD's gap) asks once more")
	# Wear it from its card.
	hud._card = {}
	hud._cards = hud._cards.filter(func(c): return c.get("where", "") == "full")
	hud._step_cards(0.01)
	_check(hud.tap_card(), "the full card takes a tap")
	for i in 5:
		_step(w, {})
	var worn = game.hero()["equip"].get("candle")
	_check(worn is Dictionary and worn.get("uid", "") == it["uid"], "a tap wears it")
	_check(p["taken"] and not p.has("sprite"), "and it leaves the ground")
	_check(w.items_found.has(it), "and counts as found")
	# A Rare weaker than what's worn, satchel still full: it melts.
	game.equip(Items.make("weapon", "knight", 30, "rare", rng))
	w.apply_hero()
	while (game.hero()["satchel"] as Array).size() < int(game.SATCHEL_MAX):
		game.add_item(Items.make("coat", "knight", 1, "magic", rng))
	var weak := Items.make("weapon", "knight", 1, "rare", rng)
	var purse: int = game.embers()
	var q: Dictionary = w.place_item(weak, pl.position + Vector2(0, -20), Vector2.ZERO)
	for i in 60:
		_step(w, {})
	_check(q["taken"], "a weaker Rare with no room is taken...")
	_check(game.embers() == purse + Items.salvage_value(weak), "...and salvaged for its embers (%d)" % (game.embers() - purse))
	var said := false
	for m in hud._msgs + [hud._msg]:
		if str(m.get("key", "")) == "salv:" + str(weak["uid"]):
			said = true
	_check(said, "and the HUD says it was salvaged")
	w.queue_free()
	await process_frame
	game.set_setting("auto_equip", true)


func _t_now(hud) -> float:
	return float(hud._t)


func _full_cards(hud) -> int:
	var n := 0
	for c in hud._cards + [hud._card]:
		if c is Dictionary and c.get("where", "") == "full":
			n += 1
	return n


# ---------------------------------------------------------------- Legendaries

func _test_legends() -> void:
	game.reset()
	game.new_hero("knight")
	# Thornsole: stomps safely onto spikes, double damage, and only once.
	var boots := Items.make("boots", "knight", 5, "legendary", rng, "thornsole")
	game.equip(boots)
	var w := _world("1-1", true)
	await process_frame
	var pl: Node2D = w.player
	for i in 30:
		_step(w, {})
	_check(float(pl.stats["flags"].get("thornsole_stomp", 0.0)) == 2.0, "Thornsole sets its stomp flag")
	# The same boots without their power: the stomp must match (the boots'
	# own implicit adds stomp; the legend must add nothing on top).
	var bare := boots.duplicate(true)
	bare["legend"] = ""
	var h2: Dictionary = game.hero().duplicate(true)
	h2["equip"]["boots"] = bare
	var no_legend: Dictionary = Hero.stats(h2, [], "dusk")
	_check(is_equal_approx(float(pl.stats["stomp"]), float(no_legend["stomp"])), "and hero.stats doesn't double the stomp itself (%.1f vs %.1f)" % [float(pl.stats["stomp"]), float(no_legend["stomp"])])
	var tb: Node2D = w.spawn_enemy("thornback", pl.position + Vector2(90, 0))
	tb.active = true
	tb.max_hp = 99999.0
	tb.hp = 99999.0
	for i in 10:
		_step(w, {})
	pl.reset_at(tb.position + Vector2(0, -70))
	pl.velocity = Vector2(0, 150)
	var hp_before: float = pl.hp
	var landed := false
	for i in 80:
		_step(w, {})
		if tb.hp < 99999.0:
			landed = true
			break
	var st := float(pl.stats["stomp"])
	var got: float = 99999.0 - tb.hp
	var one := roundf(st) * 2.0
	var crit := roundf(st * float(pl.stats["crit_mult"])) * 2.0
	_check(landed and (absf(got - one) < 1.01 or absf(got - crit) < 1.01), "a Thornsole stomp on spikes deals double, once (%.0f; plain %.0f)" % [got, roundf(st)])
	_check(pl.hp >= hp_before, "and the spikes don't hurt")
	w.queue_free()
	await process_frame
	# Cinderstep: lava and deep water cost half; a plain pit costs the lot.
	game.reset()
	game.new_hero("knight")
	game.equip(Items.make("boots", "knight", 5, "legendary", rng, "cinderstep"))
	w = _world("1-1", true)
	await process_frame
	pl = w.player
	for i in 30:
		_step(w, {})
	var costs := {}
	for kind in ["pit", "lava", "water"]:
		pl.hp = pl.max_hp
		pl.invuln = 0.0
		for i in 70:
			_step(w, {})
		var before: float = pl.hp
		w.fell(kind)
		costs[kind] = (before - pl.hp) / pl.max_hp
	_check(absf(costs["pit"] - 0.33) < 0.01, "Cinderstep: a pit still costs a third (%.3f)" % costs["pit"])
	_check(absf(costs["lava"] - 0.165) < 0.01 and absf(costs["water"] - 0.165) < 0.01, "lava and deep water cost half (%.3f, %.3f)" % [costs["lava"], costs["water"]])
	w.queue_free()
	await process_frame
	# Tollbreaker: Tollgrave's stuck and staggered windows last 0.4 s longer.
	for with_it in [false, true]:
		game.reset()
		game.new_hero("knight")
		if with_it:
			game.equip(Items.make("weapon", "knight", 7, "legendary", rng, "tollbreaker"))
		w = _world("1-4", true)
		await process_frame
		pl = w.player
		var b: Node2D = w.boss
		b.active = true
		pl.reset_at(Vector2(b.arena_left + 80.0, b.position.y))
		pl.invuln = 1000.0
		for i in 20:
			_step(w, {})
		b.state = "slam"
		b.timer = 0.0
		_step(w, {})
		var stuck_t: float = b.timer
		b._window_dmg = 0.0
		b._rung_phase = 0
		b.hit({"how": "slash", "from_x": pl.position.x, "amount": b.max_hp * 0.31})
		var hurt_t: float = b.timer
		var extra := 0.4 if with_it else 0.0
		_check(b.state == "hurt" and absf(hurt_t - (0.8 + extra)) < 0.02, "Tollgrave reels %.1f s after RUNG! %s (%.2f)" % [0.8 + extra, "with Tollbreaker" if with_it else "without it", hurt_t])
		_check(absf(stuck_t - (1.9 + extra - DT)) < 0.02, "his bell sticks %.1f s %s (%.2f)" % [1.9 + extra, "with Tollbreaker" if with_it else "without it", stuck_t])
		if with_it:
			_check(w._boss_open(b), "a staggered Tollgrave counts as open for Tollbreaker's +100%")
		w.queue_free()
		await process_frame


# ---------------------------------------------------------------- the Special through a freeze

func _recorder() -> Object:
	var s := GDScript.new()
	s.source_code = "extends \"res://scripts/kits/kit.gd\"\nvar calls: Array = []\n" \
			+ "func special_pressed() -> void:\n\tcalls.append(\"press\")\n" \
			+ "func special_released(held: float) -> void:\n\tcalls.append(\"release\")\n"
	s.reload()
	return s.new()


func _test_special_in_freeze() -> void:
	## Let go and pressed again during a hitstop freeze: both edges arrive
	## together after it. The old hold must end first, and the new one
	## stays held (not a press and an instant release).
	game.reset()
	game.new_hero("knight")
	var w := _world("1-1", true)
	await process_frame
	var pl: Node2D = w.player
	for i in 30:
		_step(w, {})
	var rec := _recorder()
	rec.cls = "knight"
	rec.setup(pl, w)
	w.kit = rec
	pl.kit = rec
	w.rig.kit = rec
	_step(w, {"special": true})
	_check(rec.calls == ["press"] and w._special_held, "a press starts a hold")
	w.hitstop = 0.1
	_step(w, {"special": false})
	_step(w, {"special": true})
	for i in 14:
		_step(w, {"special": true})
	_check(rec.calls == ["press", "release", "press"], "a release and re-press in one freeze: the old hold ends, then the new press (%s)" % str(rec.calls))
	_check(w._special_held, "and the new hold is still held")
	for i in 3:
		_step(w, {"special": true})
	_step(w, {"special": false})
	_check(rec.calls == ["press", "release", "press", "release"], "and lets go when the button does (%s)" % str(rec.calls))
	# A tap inside a freeze that ends held: one press, still held.
	rec.calls.clear()
	w.hitstop = 0.1
	_step(w, {"special": true})
	_step(w, {"special": false})
	_step(w, {"special": true})
	for i in 14:
		_step(w, {"special": true})
	_check(rec.calls == ["press"] and w._special_held, "a press, release and press in a freeze from rest: one held press (%s)" % str(rec.calls))
	_step(w, {"special": false})
	# Pressed and let go inside one freeze: still a whole tap.
	rec.calls.clear()
	w.hitstop = 0.1
	_step(w, {"special": true})
	_step(w, {"special": false})
	for i in 14:
		_step(w, {"special": false})
	_check(rec.calls == ["press", "release"] and not w._special_held, "a tap inside a freeze is still a tap (%s)" % str(rec.calls))
	w.queue_free()
	await process_frame


# ---------------------------------------------------------------- the world's other hooks

func _test_world_hooks() -> void:
	game.reset()
	game.new_hero("knight")
	var w := _world("1-1")
	await process_frame
	var pl: Node2D = w.player
	for i in 30:
		_step(w, {})
	# The first hurt: Mother Taper's bark, through the world's own hook.
	_check(not game.seen("bark:first_hurt"), "(the first-hurt bark not heard yet)")
	pl.invuln = 0.0
	w.hurt_player(5.0, pl.position.x + 10.0)
	await process_frame   # the world asks for it a frame on (main's own hook goes first)
	await process_frame
	_check(game.seen("bark:first_hurt"), "the first hurt plays Mother Taper's bark")
	# Hazard shadows grow over the hazard's own wait.
	var hz: Dictionary = w.add_hazard({"kind": "drip", "motion": "fall", "delay": 0.8, "shadow": true, "rect": Rect2(pl.position.x, 0, 12, 16)})
	_check(is_equal_approx(float(hz.get("delay0", 0.0)), 0.8), "a hazard keeps its whole delay for its shadow (%.2f)" % float(hz.get("delay0", 0.0)))
	w.hazards.clear()
	# The crit sound, once the sounds are loaded.
	var e: Node2D = w.spawn_enemy("skeleton", pl.position + Vector2(40, 0))
	e.active = true
	var ready := false
	for i in 200:
		if sfx != null and (sfx.get("_streams") as Dictionary).has("crit"):
			ready = true
			break
		await process_frame
	if ready and not bool(sfx.get("muted")) and sfx.get_volume() > 0.0:
		(sfx.get("_recent") as Dictionary).erase("crit")
		var res: Dictionary = w.deal(e, 1.0, {"force_crit": true})
		_check(res["crit"] and (sfx.get("_recent") as Dictionary).has("crit"), "a crit plays the crit sound")
	else:
		print("  (sounds not loaded or muted: crit sound not checked)")
	# The Snuffer's third phase ("Lights Out") has its own bark.
	var snuffer_like := GDScript.new()
	snuffer_like.source_code = "extends Node2D\nvar boss_id := \"snuffer\"\n"
	snuffer_like.reload()
	var sb: Node2D = snuffer_like.new()
	w.boss_phase(sb, 3)
	var dark := false
	for m in w.hud._msgs + [w.hud._msg]:
		if str(m.get("key", "")) == "bark:snuffer_dark":
			dark = true
	_check(dark, "the Snuffer's Lights Out plays the snuffer_dark bark")
	sb.free()
	# Leaving under a quarter of life doesn't leave the music muffled.
	if sfx != null and sfx.has_method("set_lowpass"):
		pl.hp = pl.max_hp * 0.1
		for i in 3:
			await process_frame
		_check(sfx.lowpass_on(), "under a quarter of life the music is muffled")
		w.queue_free()
		await process_frame
		await process_frame
		_check(not sfx.lowpass_on(), "and leaving the level opens it up again")
	else:
		w.queue_free()
		await process_frame


func _test_small_flames() -> void:
	## Small flames far along a level (a badly hurt hero's, an ember's) draw
	## without the renderer refusing them. Glow's teardrops used to go to the
	## engine to triangulate in world coordinates, and past x ~3000 a tear
	## under a pixel or two across failed that now and then (float precision):
	## an engine error each time, and that frame's core not drawn.
	var g: Node2D = (load("res://scripts/glow.gd") as GDScript).new()
	var rs := RandomNumberGenerator.new()
	rs.seed = 7
	g.extra_flames.append({"p": Vector2(3417.0, 300.0), "h": 1.81})   # the one seen in play
	for i in 500:
		g.extra_flames.append({"p": Vector2(rs.randf_range(3000.0, 10200.0), rs.randf_range(-100.0, 900.0)), "h": rs.randf_range(0.6, 9.0)})
	var n0 := catch.renders
	var e0 := catch.count()
	var draws := [0]
	g.draw.connect(func(): draws[0] += 1)
	root.add_child(g)
	for i in 8:
		await process_frame
	g.queue_free()
	await process_frame
	_check(draws[0] >= 4, "the flames were drawn (%d frames)" % draws[0])
	_check(catch.renders == n0, "501 small flames far along a level, %d frames: no draw refused (%d)" % [draws[0], catch.renders - n0])
	_check(catch.count() == e0, "and no error of any kind while drawing them")


# ---------------------------------------------------------------- World 3 and 4's boss levels

func _test_v3_boss_levels() -> void:
	## 3-4 and 4-4 through their seams in the real World (the wave-2 merge):
	## the boss from the level's X in its real arena, its track, the
	## "before" scene over the level when he wakes, the three-part bar, the
	## phases to his fall, the bell after the kill, his world's Legendary
	## as the first-kill prize, the bell rung, and the level's record paying
	## Mother Yarrow's Second Draught (3-4) or opening the Rich Draught (4-4).
	var Cut: GDScript = load("res://scripts/cutscene.gd")
	for row in [["3-4", "rootmother", 3, 17, "boss_3_before", "second"], ["4-4", "tinker", 4, 22, "boss_4_before", "rich"]]:
		var id: String = row[0]
		if not FileAccess.file_exists("res://levels/%s.txt" % id):
			print("  skipped: %s.txt missing" % id)
			continue
		var n0 := catch.count()
		game.reset()
		game.new_hero("knight")
		game.add_xp(Progression.total_to(int(row[3])) - int(game.hero()["xp"]))
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		game.mark_seen(str(lv.story.get("start", "")))
		var w: Node2D = WorldScript.new()
		w.setup(lv, false)
		root.add_child(w)
		w.set_physics_process(false)
		await process_frame
		var b: Node2D = w.boss
		_check(b != null and str(b.get("boss_id")) == row[1], "%s: the level's X spawns %s" % [id, row[1]])
		if b == null:
			w.queue_free()
			continue
		_check(int(w.world_n) == int(row[2]) and w.boss_music() == row[1], "%s: World %d, the fight's track is %s" % [id, row[2], w.boss_music()])
		_check(str(b.get("state")) == "sleep" and b.arena_left > 100.0 * 32.0, "%s: asleep in the level's own arena (x %.0f-%.0f)" % [id, b.arena_left, b.arena_right])
		# Into the arena: he wakes and the "before" scene plays over the level.
		var pl: Node2D = w.player
		pl.reset_at(Vector2(float(b.arena_left) + 150.0, float(b.floor_y)))
		w.cam = w._clamp_cam(pl.position)
		var cs: Node = null
		for i in 600:
			_step(w, {})
			if cs == null:
				cs = Cut.running_on(w, str(row[4]))
			if str(b.get("state")) != "sleep" and cs != null:
				break
			if i % 60 == 0:
				await process_frame
		_check(str(b.get("state")) != "sleep", "%s: %s wakes once Waxby is in the arena" % [id, row[1]])
		_check(cs != null, "%s: and %s plays over the level" % [id, row[4]])
		if cs != null:
			var covered := false
			var dark_hidden := false
			var vis0 := {}
			for c in w.get_children():
				if (c is CanvasLayer or c is CanvasItem) and c != cs:
					vis0[c] = c.visible
			for i in 6000:
				if cs.finished:
					break
				if i % 10 == 9:
					cs.tap()
				cs.advance(DT)
				if cs.world_covered():
					covered = true
					for c in w.get_children():
						if c is CanvasLayer and int(c.layer) == 1 and not c.visible:
							dark_hidden = true
				if i % 200 == 0:
					await process_frame
			_check(cs.finished and game.seen(str(row[4])), "%s: %s plays to its end" % [id, row[4]])
			# Under its panel the level doesn't draw (the int2 review: the
			# level's full-field dark kept rendering under the opaque panel).
			var back := true
			for c in vis0:
				if is_instance_valid(c) and c != w.get("hud") and c != w.get("touch"):
					back = back and c.visible == vis0[c]
			_check(covered and dark_hidden and back, "%s: under %s's panel the level's layers (its dark too) are hidden, and back after (%s, %s, %s)" % [id, row[4], covered, dark_hidden, back])
		await process_frame
		var bar: Dictionary = w.hud.get("_boss") if w.hud != null else {}
		_check(not bar.is_empty() and bar.get("segments", []) == [0.65, 0.30] and str(bar.get("name", "")) != "", "%s: the boss bar in three parts (%s)" % [id, bar.get("name", "")])
		# His phases to his fall: each blow clamps at a phase's line; he
		# roars between them (a blow then is refused), so time runs on.
		for k in 60:
			if not b.alive:
				break
			b.hit({"how": "slash", "from_x": pl.position.x, "amount": 9999999.0})
			for t in 120:
				_step(w, {})
			pl.hp = pl.max_hp
			await process_frame
		_check(not b.alive and int(b.get("phase")) >= 3, "%s: %s falls through all three phases" % [id, row[1]])
		var bell_at := -1.0
		var prize := {}
		for i in 900:
			_step(w, {})
			pl.hp = pl.max_hp
			if bell_at < 0.0 and not w.bells.is_empty():
				bell_at = i * DT
			if prize.is_empty():
				for p in w.pickups:
					if p["kind"] == "item" and bool(p.get("boss_first", false)):
						prize = p["item"]
			if bell_at >= 0.0 and not prize.is_empty():
				break
			if i % 60 == 0:
				await process_frame
		_check(bell_at >= 0.0, "%s: the bell comes down after the kill (%.1f s)" % [id, bell_at])
		var pair: Array = Items.world_legends(int(row[2]))
		_check(not prize.is_empty() and pair.has(str(prize.get("legend", ""))),
				"%s: the first-kill prize is one of World %d's Legendaries (%s of %s)" % [id, row[2], prize.get("legend", ""), pair])
		# Ring it.
		if not w.bells.is_empty():
			var rope: Rect2 = w.bells[0]["rope"]
			pl.reset_at(Vector2(rope.get_center().x, rope.end.y))
			for i in 240:
				_step(w, {"up": true} if i % 2 == 0 else {})
				if w.state == "clear":
					break
		_check(w.state == "clear", "%s: the bell rings and the level is cleared (%s)" % [id, w.state])
		var res: Dictionary = w.result()
		var out: Dictionary = game.record_result(res)
		if row[5] == "second":
			_check(str(out.get("draught", "")) == "second" and game.flask_charges("dusk") == 2,
					"3-4's first clear gives Mother Yarrow's Second Draught (%s: %d charges on Dusk)" % [out.get("draught", ""), game.flask_charges("dusk")])
		else:
			var rich: Dictionary = {}
			for d in game.draughts():
				if d["id"] == "rich":
					rich = d
			_check(str(rich.get("state", "")) == "buy", "4-4's clear opens the Rich Draught at the Chandler (%s)" % rich.get("state", ""))
		var errs := catch.since(n0)
		_check(errs.is_empty(), "%s: no script errors (%s)" % [id, "; ".join(errs.slice(0, 3))])
		w.queue_free()
		await process_frame
		await process_frame
	game.reset()


func _test_v3_boss_rewake() -> void:
	## The bar on every wake, not only the first (the int2 review: a v3 boss
	## emits `woke` while its state still reads "sleep", and with the scene
	## and the card already seen the bar was cleared at once: a retry, a
	## later visit and the Waxworks cast had none). And the camera leans to
	## show him once he's up (Gravebough stands in her right wall).
	for row in [["3-4", 17], ["4-4", 22]]:
		var id: String = row[0]
		if not FileAccess.file_exists("res://levels/%s.txt" % id):
			continue
		game.reset()
		game.new_hero("knight")
		game.add_xp(Progression.total_to(int(row[1])) - int(game.hero()["xp"]))
		var lv = LevelData.load_file("res://levels/%s.txt" % id)
		for k in ["start", "boss"]:
			game.mark_seen(str(lv.story.get(k, "")))
		game.mark_seen("boss_card_rootmother")
		game.mark_seen("boss_card_tinker")
		var w: Node2D = WorldScript.new()
		w.setup(lv, false)
		root.add_child(w)
		w.set_physics_process(false)
		await process_frame
		var b: Node2D = w.boss
		var pl: Node2D = w.player
		for attempt in 2:
			pl.reset_at(Vector2(float(b.arena_left) + 150.0, float(b.floor_y)))
			w.cam = w._clamp_cam(pl.position)
			for i in 600:
				pl.invuln = 9.0
				_step(w, {})
				if str(b.get("state")) != "sleep":
					break
			for i in 150:
				pl.invuln = 9.0
				pl.hp = pl.max_hp
				_step(w, {})
			await process_frame
			var bar: Dictionary = w.hud.get("_boss") if w.hud != null else {}
			_check(str(b.get("state")) != "sleep" and not bar.is_empty() and bar.get("segments", []) == [0.65, 0.30],
					"%s, wake %d (scene and card seen): the boss bar in three parts (%s)" % [id, attempt + 1, bar.get("name", "<none>")])
			var face: float = b.center().x
			var eyes: Array = b.eye_points()
			if not eyes.is_empty():
				face = (eyes[0] as Vector2).x
			var vr: Rect2 = w.view_rect()
			_check(face >= vr.position.x and face <= vr.end.x, "%s, wake %d: the camera shows his face (x %.0f in %.0f-%.0f)" % [id, attempt + 1, face, vr.position.x, vr.end.x])
			if attempt == 0:
				# Snuffed: the fight resets, and he sleeps until Waxby is back.
				pl.invuln = 0.0
				pl.take_damage(999999.0, pl.position.x + 10.0)
				for i in 600:
					_step(w, {})
					if w.state == "play" and str(b.get("state")) == "sleep" and pl.alive:
						break
				_check(str(b.get("state")) == "sleep", "%s: a snuff puts him back to sleep" % id)
		w.queue_free()
		await process_frame


func _test_v3_dread_gifts() -> void:
	## spec §8.1 on the real levels: the first Dread killed in World 3 (3-1's
	## Mister Mandrake) drops boots to a hero who has none, World 4's (4-1's)
	## a charm; with the slot held, it's any Dread drop.
	for row in [["3-1", "boots", 13], ["4-1", "charm", 18]]:
		if not FileAccess.file_exists("res://levels/%s.txt" % row[0]):
			continue
		for held in [false, true]:
			game.reset()
			game.new_hero("knight")
			game.add_xp(Progression.total_to(int(row[2])) - int(game.hero()["xp"]))
			var h: Dictionary = game.hero()
			h["equip"].erase(row[1])
			h["satchel"] = (h["satchel"] as Array).filter(func(it): return not (it is Dictionary and str(it.get("slot", "")) == row[1]))
			if held:
				h["equip"][row[1]] = Items.make(str(row[1]), "knight", 13, "magic", rng)
			var w := _world(str(row[0]))
			await process_frame
			var d: Node2D = null
			for e in w.enemies:
				if e.tier == "dread":
					d = e
			_check(d != null, "%s: its Dread is placed" % row[0])
			if d == null:
				w.queue_free()
				continue
			var before: int = w.pickups.size()
			d.active = true
			if not d.hit({"how": "slash", "from_x": d.position.x - 20.0, "amount": 9999999.0}):
				d.set("state", "walk")   # (3-1's Mister Mandrake waits buried: up he comes)
				d.hit({"how": "slash", "from_x": d.position.x - 20.0, "amount": 9999999.0})
			for i in 30:
				_step(w, {})
			var slots := []
			for i in range(before, w.pickups.size()):
				if w.pickups[i]["kind"] == "item":
					slots.append(str(w.pickups[i]["item"].get("slot", "")))
			if held:
				_check(not slots.is_empty(), "%s: with %s held, the Dread drops an item (%s)" % [row[0], row[1], slots])
			else:
				_check(slots.has(row[1]), "%s: the first Dread drops %s to a hero with none (%s)" % [row[0], row[1], slots])
			w.queue_free()
			await process_frame
	game.reset()
