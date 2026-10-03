extends SceneTree
## BR (workstreams.md §2.2, spec §5.6 and §7.3): the rush additions to Old
## Tollgrave and the Snuffer, and boss_mods.gd.
##   - The story fights are v2's to the tick: a scripted fight against the
##     v3-w1 snapshot's boss.gd / snuffer_boss.gd traces the same (skipped
##     when that snapshot isn't on this Mac), and nothing rush-only happens
##     without configure.
##   - configure: {rush, mods, hp_mult, area}: the life (BossMods.RUSH_HP x
##     hp_mult), the flag, the mods, the three-part bar; is_open() only in
##     windows; window_bonus(); reset_fight(keep) clears the rush's state.
##   - Bell Roll (P2+, after every third slam): its tell and floor, the 48 x 48
##     bell at 280 px/s, the one rebound, the catch, its 36, his 1.2 s opening.
##     With the bell out: no slams and no idling (the Skull Choir, then he
##     comes at Wick until he catches it), and every frame tells the truth
##     (dazed only while he's safe to touch; empty-handed while it's out).
##     The Skull Choir in P1; the Toll of Ruin's six chunks.
##   - Smother (every fourth move): the ring follows at 60 px/s for 1.6 s on
##     what Wick stands on (each ledge too; he hangs over it), its countdown
##     sweep and its warning 0.5 s ahead, locks 0.45 s (floor 0.40), 40 and a
##     douse in its column (a jump doesn't clear it); a runner who reacts
##     0.25 s after the warning gets clear on every difficulty; the cone
##     sticks 1.0 s where it fell and he's solid (Lights Out too). Gutter
##     Call's three; Lights Out's two Lunges; no story line in the rush.
##   - Warded Wax (3 motes, a blow blocked even in a window, a stomp breaks
##     all, back in 5 s) and Echoing Wax (a strike again 0.8 s later at 60%,
##     at the same place; a moving one retraced; its box marked, and a
##     falling one's on the floor where it will land, in view).
##   - The Waxworks and a Descent echo wire through configure (no fallback
##     on top), and the rush sim: the reference knight's fight lasts 60-80 s
##     at every level a rematch is sampled at.
##
##     godot --headless --path game --script res://tests/test_rush_bosses.gd
##     WAXBY_RUSH_SIM=1   the rush sim's derivation too (RUSH_HP x0.80..1.20:
##                        the life whose median lands nearest 70 s); =2 also
##                        logs every sim fight's windows
##     WAXBY_RUSH_SHOTS=<dir> (with a window, no --headless): screenshots of
##                        Bell Roll, Smother and the mods, in the dark
##     WAXBY_V2_BOSSES=<dir>  where the v2 boss scripts are (default the
##                        v3-w1 snapshot's game/scripts)

const LevelData := preload("res://scripts/level_data.gd")
const Combat := preload("res://scripts/combat.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Classes := preload("res://scripts/classes.gd")
const Progression := preload("res://scripts/progression.gd")
const BossMods := preload("res://scripts/boss_mods.gd")
const TILE := 32
const DT := 1.0 / 120.0
const V2_DIR := "~/Developer/waxby-snapshots/v3-w1/game/scripts"
# The rush sim: the fight's length for the reference knight (spec §5.6).
const SIM_LO := 60.0
const SIM_HI := 80.0
const SIM_AIM := 70.0
const SIM_REACT := 0.30          # the fighter's reaction to a window opening
const SIM_LIMIT := 240.0
# The levels a rematch is fought at: just after the boss (his area), mid-game,
# the Gauntlet's (Dusk area 31) and the cap.
const SIM_LEVELS := {"tollgrave": [7, 20, 32, 40], "snuffer": [13, 20, 32, 40],
		"rootmother": [18, 26, 32, 40], "tinker": [22, 28, 34, 40], "saint": [27, 32, 36, 40], "hush": [31, 34, 37, 40]}
const STORY_OF := {"tollgrave": "1-4", "snuffer": "2-4", "rootmother": "3-4", "tinker": "4-4", "saint": "5-4", "hush": "6-4"}
# The reference knight's arrival at each boss (test_progression's EXIT_TARGET
# of the level before, floored), and spec §5.1's first-win lengths.
const STORY_AT := {"tollgrave": 6, "snuffer": 12, "rootmother": 17, "tinker": 21, "saint": 26, "hush": 30}
const STORY_TARGET := {"tollgrave": Vector2(40, 60), "snuffer": Vector2(45, 55), "rootmother": Vector2(70, 100),
		"tinker": Vector2(80, 110), "saint": Vector2(90, 120), "hush": Vector2(150, 210)}
const V2_BOSSES := ["tollgrave", "snuffer"]   # BR's; the other four are BA's and BB's (their rush life: informational)

var WorldScript: GDScript
var Waxworks: GDScript
var Descent: GDScript
var Mode: GDScript
var game: Node
var _passed := 0
var _failed := 0
var _sim_all := OS.get_environment("WAXBY_RUSH_SIM") != ""
var _sim_log := OS.get_environment("WAXBY_RUSH_SIM") == "2"
var _phone: SubViewport = null   # set: a mode's World goes in a phone-shaped (844 x 390) view


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	Waxworks = load("res://scripts/modes/waxworks.gd")
	Descent = load("res://scripts/modes/descent.gd")
	Mode = load("res://scripts/modes/mode.gd")
	game = root.get_node_or_null("Game")
	if game == null:
		print("test_rush_bosses: 0 passed, 1 failed")
		quit(1)
		return
	game.save_path = "user://test_rush_save.json"
	game.slot_base = "user://test_rush_save"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	var shots := OS.get_environment("WAXBY_RUSH_SHOTS")
	if shots != "":
		await _shots(shots)
		quit()
		return
	var t0 := Time.get_ticks_msec()
	await _test_story_identity()
	await _test_story_untouched()
	await _test_configure()
	await _test_bell_roll()
	await _test_bell_roll_timing()
	await _test_bell_out()
	await _test_tollgrave_rush()
	await _test_smother()
	await _test_smother_ledges()
	await _test_smother_reaction()
	await _test_snuffer_rush()
	await _test_warded()
	await _test_echoing()
	await _test_waxworks_wiring()
	await _test_rush_sim()
	_test_code_rules()
	game.return_hero()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_rush_save.json" + suffix))
	print("  (%d ms)" % (Time.get_ticks_msec() - t0))
	print("test_rush_bosses: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _fresh() -> void:
	game.return_hero()
	game.reset()
	if game.heroes().is_empty():
		game.new_hero("knight")


func _reference(level: int, area: int) -> Dictionary:
	## test_progression's _reference3: spec §1.3's reference Candleknight
	## (Blessed gear at ilvl = area, each piece's signature affix at a median
	## roll, Warded boots from area 13 and a Keen charm from 18, half his
	## points in stat nodes in turn, Vigil ranks past a full tree, no relics).
	var h := Hero.blank("knight", level)
	h["equip"] = Items.starter("knight", area, "magic")
	for slot in ["boots", "charm"]:
		if area < (13 if slot == "boots" else 18):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(slot + str(area))
		var it := Items.make(slot, "knight", area, "common", rng)
		var sig: String = Items.SIGNATURE[slot]
		it["rarity"] = "magic"
		it["affixes"] = [{"id": sig, "t": int(it["tier"]), "v": Items.median(sig, int(it["tier"]))}]
		h["equip"][slot] = it
	var stat_points := (level - 1) / 2
	var order := ["k_honed", "k_tempered", "k_keen", "k_vigilant"]
	var most := {"k_honed": 2, "k_tempered": 2, "k_keen": 2, "k_vigilant": 3}
	var i := 0
	while stat_points > 0 and i < 80:
		var id: String = order[i % order.size()]
		i += 1
		if id == "k_vigilant" and level < 16:
			continue
		if int(h["skills"].get(id, 0)) < int(most[id]):
			h["skills"][id] = int(h["skills"].get(id, 0)) + 1
			stat_points -= 1
	h["vigil"] = maxi(0, level - 1 - 32)
	h["xp"] = Progression.total_to(level)
	return h


func _mode_world(mode: Object, lv: RefCounted) -> Node2D:
	## A mode's World, headless, wired as main.play_custom wires it.
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.mode = mode
	mode.world = w
	w.finished.connect(func(res): mode.finished(res))
	w.paused = true   # its own loop off: every tick is the test's (deterministic)
	(_phone if _phone != null else root).add_child(w)
	return w


func _rematch(boss: String, diff := "dusk", tweaks: Array = [], level := 0) -> Node2D:
	## A Waxworks rematch (the real mode, headless) against this boss; with a
	## level, the reference knight at it is lent for the fight.
	_fresh()
	if level > 0:
		var a: int = Waxworks.rematch_area(boss, diff, level)
		game.borrow_hero(_reference(level, a))
	var m = Waxworks.new()
	m.headless = true
	m.setup(boss, diff, tweaks)
	var w := _mode_world(m, m.level_data())
	await process_frame
	w.test_pad = {}
	return w


func _story(id: String, level := 0, diff := "dusk") -> Node2D:
	game.return_hero()
	game.reset()
	game.data["difficulty"] = diff
	if level > 0:
		var lv0 = LevelData.load_file("res://levels/%s.txt" % id)
		game.borrow_hero(_reference(level, Combat.area_level(int(lv0.area), diff)))
	var lv = LevelData.load_file("res://levels/%s.txt" % id)
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.paused = true
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


func _until(w: Node2D, done: Callable, seconds: float, pad := {}) -> bool:
	for i in int(seconds / DT):
		if done.call():
			return true
		_step(w, 1, pad)
	return done.call()


func _floor_at(b: Node2D, x: float) -> Vector2:
	return Vector2(x, b.position.y if not b.get("floor_y") else float(b.floor_y))


func _wake(w: Node2D, dx := 160.0) -> Node2D:
	## Wick into the arena, the boss awake and done roaring.
	var b: Node2D = w.boss
	b.active = true
	var pl: Node2D = w.player
	pl.reset_at(Vector2(clampf(b.position.x - dx, b.arena_left + 60.0, b.arena_right - 60.0), _floor_at(b, 0).y))
	pl.invuln = 1000.0
	_step(w, 3)
	_until(w, func(): return b.state != "sleep" and b.state != "roar", 3.0)
	return b


func _god(w: Node2D) -> void:
	var pl: Node2D = w.player
	pl.hp = pl.max_hp
	pl.invuln = 1000.0


# ---------------------------------------------------------------- the story, untouched

func _v2_script(file: String) -> GDScript:
	## The v2 boss script as the v3-w1 snapshot has it, compiled from its
	## source (null when the snapshot isn't here).
	var dir := OS.get_environment("WAXBY_V2_BOSSES")
	if dir == "":
		dir = V2_DIR.replace("~", OS.get_environment("HOME"))
	var path := dir.path_join(file)
	if not FileAccess.file_exists(path):
		return null
	var gs := GDScript.new()
	gs.source_code = FileAccess.get_file_as_string(path)
	if gs.reload() != OK:
		return null
	return gs


func _swap_boss(w: Node2D, script: GDScript) -> Node2D:
	## The World's boss replaced by one of this script, placed and wired as
	## spawn_enemy and _build do (before it wakes).
	var nb: Node2D = w.boss
	var b: Node2D = script.new()
	b.level = w.level
	b.world = w
	b.position = nb.position
	b.facing = int(nb.facing)
	b.spawn = nb.spawn
	b.setup_stats(int(w.area), str(w.diff), str(w.strength), int(w.world_n))
	b.died.connect(w._on_enemy_died)
	w.enemies.erase(nb)
	nb.get_parent().remove_child(nb)
	nb.free()
	w.get_node("Monsters").add_child(b)
	w.enemies.append(b)
	w.boss = b
	b.woke.connect(w._on_boss_woke)
	return b


func _trace_fight(w: Node2D, seconds: float) -> Array:
	## A scripted fight (the pad from the positions and the tick, the hero's
	## life topped up), one line a tick: the boss, the hazards, the hero.
	var b: Node2D = w.boss
	var pl: Node2D = w.player
	b.active = true
	pl.reset_at(Vector2(b.arena_left + 90.0, b.position.y))
	var out := []
	for i in int(seconds / DT):
		pl.hp = pl.max_hp
		var dx: float = b.position.x - pl.position.x
		var pd := {"attack": i % 2 == 0, "jump": (i / 45) % 4 == 0}
		if absf(dx) > 46.0:
			pd["right" if dx > 0.0 else "left"] = true
		elif absf(dx) < 20.0:
			pd["left" if dx > 0.0 else "right"] = true
		_step(w, 1, pd)
		var hz := 0.0
		for h in w.hazards:
			hz += (h["rect"] as Rect2).position.x + (h["rect"] as Rect2).position.y * 0.01
		out.append("%s|%.2f,%.2f|%.3f|%d|%d|%.2f|%.2f,%.2f" % [b.state, b.position.x, b.position.y, b.hp, b.phase,
				w.hazards.size(), hz, pl.position.x, pl.position.y])
		if not b.alive:
			break
	return out


func _test_story_identity() -> void:
	## The story's Tollgrave and Snuffer trace the v2 scripts tick for tick.
	for pair in [["1-4", "boss.gd", 7], ["2-4", "snuffer_boss.gd", 13]]:
		var v2 := _v2_script(pair[1])
		if v2 == null:
			print("  skipped: the v2 %s (no snapshot at %s)" % [pair[1], V2_DIR])
			continue
		var traces := []
		for which in ["v2", "v3"]:
			seed(4242)
			var w := await _story(pair[0], pair[2])
			if which == "v2":
				_swap_boss(w, v2)
			seed(4242)
			traces.append(_trace_fight(w, 100.0))
			await _done(w)
		var a: Array = traces[0]
		var b: Array = traces[1]
		var first := -1
		for i in mini(a.size(), b.size()):
			if a[i] != b[i]:
				first = i
				break
		var phases := str(a[a.size() - 1]).split("|")[4] if not a.is_empty() else "?"
		_check(first < 0 and a.size() == b.size() and a.size() > 1000,
				"%s: the story's %s fights as v2's, tick for tick (%d ticks, to phase %s%s)" % [pair[0], pair[1], a.size(), phases,
				"" if first < 0 else "; first differs at tick %d: %s vs %s" % [first, a[first], b[first]]])


func _test_story_untouched() -> void:
	## Without configure nothing of the rush happens: no Bell Roll, no Skull
	## Choir in P1, four chunks; no Smother, two moths, one Lunge; no mods.
	var w := await _story("1-4", 7)
	var b: Node2D = w.boss
	_check(not b.rush and BossMods.of(b) == null and not b.boss_info().has("segments"), "1-4: Tollgrave is no rush boss (no mods, v2's bar)")
	_check(b.lights().is_empty(), "1-4: he gives off no light of his own (as v2)")
	b = _wake(w)
	b.phase = 2
	b._phase_slams = 9
	b._next()
	_check(b.state != "roll_tell", "no Bell Roll in the story, whatever his slams (%s)" % b.state)
	b.phase = 1
	b._attacks = 2
	b._next()
	_check(b.state == "walk", "no Skull Choir in the story's P1 (%s)" % b.state)
	b.phase = 3
	w.hazards.clear()
	b._rubble(w.player)
	_check(w.hazards.filter(func(h): return h["kind"] == "rubble").size() == 4, "the story's Toll of Ruin: four chunks")
	await _done(w)
	w = await _story("2-4", 13)
	var s: Node2D = w.boss
	_check(not s.rush and BossMods.of(s) == null and not s.boss_info().has("segments"), "2-4: the Snuffer is no rush boss")
	s = _wake(w)
	var smoth := false
	for i in 12:
		s._next(w.player)
		smoth = smoth or s.state in s.SMOTHER_STATES
	_check(not smoth and s.smothers == 0, "no Smother in the story")
	s._summon()
	_check(s._wings.size() == 2, "the story's Gutter Call: two moths")
	for m in s._wings:
		if is_instance_valid(m):
			m.alive = false
			m.gone = true
	s._wings.clear()
	_to_lights_out(w, s)
	_check(s.phase == 3 and s.barks_skipped == 0, "the story's Lights Out keeps Mother Taper's line")
	await _done(w)


# ---------------------------------------------------------------- configure

func _boss_life(kind: String, area: int, diff := "dusk") -> float:
	var ek = load("res://scripts/enemy_kinds.gd")
	var b: Node2D = ek.make(kind)
	b.setup_stats(area, diff, "normal", 1)
	var hp: float = b.max_hp
	b.free()
	return hp


func _test_configure() -> void:
	var ek = load("res://scripts/enemy_kinds.gd")
	for kind in ["tollgrave", "snuffer"]:
		var b: Node2D = ek.make(kind)
		b.setup_stats(20, "dusk", "normal", 1)
		var hp0: float = b.max_hp
		_check(b.has_method("configure") and b.has_method("is_open") and b.has_method("window_bonus"), "%s has configure, is_open and window_bonus" % kind)
		b.configure({"rush": true, "mods": ["warded", "echoing", "burning"], "hp_mult": 1.5, "area": 20})
		_check(b.rush and absf(b.max_hp - hp0 * BossMods.RUSH_HP[kind] * 1.5) < 0.01 and absf(b.hp - b.max_hp) < 0.01,
				"%s: rush life = own x%.2f x the mode's 1.5 (%.0f -> %.0f)" % [kind, BossMods.RUSH_HP[kind], hp0, b.max_hp])
		var m = BossMods.of(b)
		_check(m != null and m.has("warded") and m.has("echoing") and not m.has("burning") and m.motes_up() == 3,
				"%s: Warded and Echoing Wax on (3 motes); an unknown mod ignored" % kind)
		_check(b.boss_info().get("segments", []) == b.PHASES, "%s: the rush's boss bar has its segments" % kind)
		b.free()
		var c: Node2D = ek.make(kind)
		c.setup_stats(20, "dusk", "normal", 1)
		c.configure({"hp_mult": 0.8})
		_check(not c.rush and absf(c.max_hp - hp0 * 0.8) < 0.01 and BossMods.of(c) == null, "%s: without rush only the mode's share (x0.8)" % kind)
		c.free()
	# is_open only in windows; window_bonus is Tollbreaker's.
	var w := await _rematch("tollgrave")
	var t: Node2D = _wake(w)
	var seen := {}
	for i in int(20.0 / DT):
		_god(w)
		_step(w, 1)
		seen[t.state] = seen.get(t.state, false) or t.is_open()
	_check(bool(seen.get("stuck", false)) and not bool(seen.get("walk", true)) and not bool(seen.get("windup", true)),
			"Tollgrave: open with the bell stuck, never walking or winding up (%s)" % [seen])
	w.player.stats["flags"] = {"tollbreaker_window": 0.4}
	_check(absf(t.window_bonus() - 0.4) < 1e-6, "Tollgrave: window_bonus() is Tollbreaker's +0.4")
	await _done(w)
	w = await _rematch("snuffer")
	var s: Node2D = _wake(w)
	seen = {}
	for i in int(20.0 / DT):
		_god(w)
		_step(w, 1)
		seen[s.state] = seen.get(s.state, false) or s.is_open()
	_check(not bool(seen.get("drift", true)) and not bool(seen.get("track", true)) and not bool(seen.get("raise", true)),
			"the Snuffer: never open drifting, tracking or raising (%s)" % [seen])
	s.state = "stuck"
	_check(s.is_open(), "the Snuffer: open with the pole stuck")
	await _done(w)


# ---------------------------------------------------------------- Bell Roll

func _to_roll(w: Node2D) -> Node2D:
	var b: Node2D = _wake(w)
	b.phase = 2
	b.hp = b.max_hp * 0.5
	b._phase_slams = b.ROLL_EVERY
	b.state = "stuck"
	b.timer = 0.0
	_step(w, 1)
	return b


func _test_bell_roll() -> void:
	var w := await _rematch("tollgrave")
	var b: Node2D = _to_roll(w)
	var pl: Node2D = w.player
	_check(b.state == "roll_tell" and b._phase_slams == 0, "P2, the third slam's window over: Bell Roll's tell (%s)" % b.state)
	_check(absf(b.timer - (0.6 - DT)) < 0.02, "its tell is 0.6 s on Dusk (%.3f)" % b.timer)
	var lane_dir: int = b._roll_dir
	_until(w, func(): return b.state != "roll_tell", 1.0)
	_check(b.state == "bowled" and not b._bell.is_empty(), "then he bowls it and is open (%s)" % b.state)
	_check(b.is_open() and b.vulnerable() and not b.touch_damage(), "open while it rolls: full hits, safe to touch")
	var r: Rect2 = b.bell_rect()
	_check(r.size == Vector2(48, 48) and absf(r.end.y - b.position.y) < 1.0, "a 48 x 48 bell on the floor")
	var x0: float = float(b._bell["x"])
	_step(w, 12)
	var v := (float(b._bell["x"]) - x0) / (12.0 * DT)
	_check(absf(absf(v) - 280.0) < 1.0 and signf(v) == lane_dir, "it rolls at 280 px/s the way the lane showed (%.1f)" % v)
	# His opening: 1.2 s, then he walks to meet it.
	var open_t := 12.0 * DT
	while b.state == "bowled" and open_t < 3.0:
		_step(w, 1)
		open_t += DT
	_check(absf(open_t - 1.2) < 0.03 and b.state == "toss" and not b._bell.is_empty() and not b.is_open() and b.touch_damage(),
			"open 1.2 s, then (the bell still out, closed) the Skull Choir (%.2f s, %s)" % [open_t, b.state])
	# It rebounds once off the far wall and comes home to him.
	var bounced_at := -1.0
	var tt := 0.0
	while not b._bell.is_empty() and tt < 10.0:
		_god(w)
		_step(w, 1)
		tt += DT
		if bounced_at < 0.0 and not b._bell.is_empty() and bool(b._bell["bounced"]):
			bounced_at = tt
	_check(bounced_at > 0.0 and b._bell.is_empty() and b.rolls == 1, "it rings off the far wall once and he catches it (%.2f s out)" % bounced_at)
	_check(b.state != "await_bell" and b.state != "bowled", "caught: the fight goes on (%s)" % b.state)
	await _done(w)
	# Its 36, where it rolls; jumped, it misses.
	w = await _rematch("tollgrave")
	b = _to_roll(w)
	pl = w.player
	_until(w, func(): return b.state == "bowled", 1.0)
	var ahead: float = float(b._bell["x"]) + b._roll_dir * 150.0
	pl.reset_at(Vector2(ahead, b.position.y))
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	var hp0: float = pl.hp
	_until(w, func(): return pl.hp < hp0, 1.5)
	_check(pl.hp < hp0 and absf(b.dmg("bell") / b.dmg_mult - 36.0) < 1e-4, "the bell hits for 36 (x the fight's scale): %.1f lost" % (hp0 - pl.hp))
	await _done(w)
	w = await _rematch("tollgrave")
	b = _to_roll(w)
	pl = w.player
	_until(w, func(): return b.state == "bowled", 1.0)
	pl.reset_at(Vector2(float(b._bell["x"]) + b._roll_dir * 170.0, b.position.y))
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	hp0 = pl.hp
	# Jump as it comes: pressed when it's 60 px off, held.
	var jumped := false
	for i in int(1.5 / DT):
		var gap: float = absf(float(b._bell["x"]) - pl.position.x) if not b._bell.is_empty() else 999.0
		var pd := {}
		if gap < 95.0 or jumped:
			pd["jump"] = true
			jumped = true
		_step(w, 1, pd)
		if not b._bell.is_empty() and bool(b._bell["bounced"]):
			break
	_check(pl.hp >= hp0 - 0.01, "jumped as it comes, it rolls under him (%.1f lost)" % (hp0 - pl.hp))
	await _done(w)


func _test_bell_roll_timing() -> void:
	## Every difficulty, and Quick Wick: the tell never under 0.45 s. It comes
	## after every third slam of a phase, not in P1.
	for diff in ["dusk", "nightfall", "witching"]:
		for tw in [[], ["quick"]]:
			var w := await _rematch("tollgrave", diff, tw)
			var b: Node2D = _to_roll(w)
			var want := maxf(0.6 * float(w.tells_mult()), 0.45)
			_check(b.state == "roll_tell" and absf(b.roll_tell_time() - want) < 1e-4 and b.roll_tell_time() >= 0.45,
					"%s%s: Bell Roll's tell %.3f s (>= 0.45)" % [diff, " + Quick Wick" if not tw.is_empty() else "", b.roll_tell_time()])
			await _done(w)
	var w2 := await _rematch("tollgrave")
	var t: Node2D = _wake(w2)
	var rolls_p1 := 0
	var slams := 0
	var last := ""
	for i in int(40.0 / DT):
		_god(w2)
		_step(w2, 1)
		if t.state == "slam" and last != "slam":
			slams += 1
		last = t.state
	rolls_p1 = t.rolls
	_check(slams >= 4 and rolls_p1 == 0 and t.phase == 1, "P1: %d slams, no Bell Roll" % slams)
	t.phase = 2
	t._phase_slams = 0
	var slams2 := 0
	var rolls_at := []
	last = ""
	for i in int(90.0 / DT):
		_god(w2)
		_step(w2, 1)
		if t.state == "slam" and last != "slam":
			slams2 += 1
		if t.state == "roll_tell" and last != "roll_tell":
			rolls_at.append(slams2)
		last = t.state
		if rolls_at.size() >= 2:
			break
	_check(rolls_at.size() >= 2 and int(rolls_at[0]) == 3 and int(rolls_at[1]) == 6, "P2: a Bell Roll after the 3rd and the 6th slam (%s)" % [rolls_at])
	await _done(w2)


func _test_bell_out() -> void:
	## With his bell out: no slams, and no idling. After the opening he
	## throws the Skull Choir, then comes at Wick (closed: his touch hurts)
	## and catches it as it rolls back past him; he walks to one only if it
	## came to rest. Every frame tells the truth: dazed (hurt, stuck) exactly
	## while he's safe to touch and stomp, and empty-handed while it's out.
	var w := await _rematch("tollgrave")
	var b: Node2D = _wake(w)
	var pl: Node2D = w.player
	var lies := {}
	var drawn := {}
	var same := 0
	var last := ""
	var t_await := 0.0
	var t_out := 0.0
	var slams_out := 0
	var tosses_out := 0
	var caught := 0
	var t_catch := []
	var opened := -1.0
	var tt := 0.0
	for ph in [1, 2, 3]:
		b.phase = ph
		b.hp = b.max_hp * [0.9, 0.5, 0.2][ph - 1]
		b._phase_slams = 0
		for i in int([30.0, 70.0, 70.0][ph - 1] / DT):
			_god(w)
			# Wick stands off, on the floor (his own blows would stop windows short).
			var dx: float = b.position.x - pl.position.x
			var pd := {}
			if absf(dx) < 170.0:
				pd["left" if dx > 0.0 else "right"] = true
			var was: String = b.state
			var had: bool = not b._bell.is_empty()
			_step(w, 1, pd)
			tt += DT
			same = same + 1 if b.state == last else 0
			last = b.state
			var out: bool = not b._bell.is_empty()
			if had and not out and b.alive:
				caught += 1
				if opened >= 0.0:
					t_catch.append(tt - opened)
			if was == "bowled" and b.state != "bowled":
				opened = tt
			if out and b.state not in ["roll_tell", "bowled"]:
				t_out += DT
				if b.state == "await_bell":
					t_await += DT
				if b.state == "slam" and was != "slam":
					slams_out += 1
				if b.state == "toss" and was != "toss":
					tosses_out += 1
			if same < 2 or not b.alive or b.state == "sleep":
				continue
			var fr: String = b.shown_frame()
			var dazed: bool = b.DAZED_FRAMES.has(fr)
			if dazed and b.touch_damage():
				lies["%s: %s, touch %s" % [b.state, fr, b.touch_damage()]] = true
			if b.stompable == b.touch_damage():
				lies["%s: stompable %s, touch %s" % [b.state, b.stompable, b.touch_damage()]] = true
			if out and not (b.sprite.region_enabled or b.RUSH_FRAMES.has(fr)):
				drawn["%s: %s" % [b.state, fr]] = true
	_check(lies.is_empty(), "every frame tells the truth: dazed only while he's safe to touch and stomp (%s)" % [lies.keys()])
	_check(drawn.is_empty(), "with the bell out he's drawn empty-handed, whatever he does (%s)" % [drawn.keys()])
	_check(b.rolls >= 4 and b.catches >= b.rolls - 1 and slams_out == 0, "%d Bell Rolls, every bell caught (%d), no slam without it" % [b.rolls, b.catches])
	_check(tosses_out >= b.rolls - 1, "the Skull Choir after each opening (%d for %d rolls)" % [tosses_out, b.rolls])
	_check(t_await <= 0.10 * maxf(t_out, 1.0), "he never waits about for it: %.1f s of %.1f s with it out spent walking to it" % [t_await, t_out])
	print("  Bell Roll: %d rolls in 140 s of P2-P3; from the opening's end to the catch %s s, with %d Skull Choirs; %.1f s of %.1f s with it out walking to it" % [
			b.rolls, _fmt(t_catch), tosses_out, t_await, t_out])
	await _done(w)


func _test_tollgrave_rush() -> void:
	var w := await _rematch("tollgrave")
	var b: Node2D = _wake(w)
	b._attacks = 2
	b._next()
	_check(b.state == "toss", "the rush's P1: the Skull Choir every third move (%s)" % b.state)
	_until(w, func(): return b.state != "toss", 1.0)
	_check(w.hazards.filter(func(h): return h["kind"] == "skull").size() == 3, "three skulls")
	b.phase = 3
	w.hazards.clear()
	for k in 5:
		w.hazards.clear()
		b._rubble(w.player)
		var xs := []
		for h in w.hazards:
			if h["kind"] == "rubble":
				xs.append((h["rect"] as Rect2).get_center().x)
		var apart := true
		for i in xs.size():
			for j in range(i + 1, xs.size()):
				apart = apart and absf(float(xs[i]) - float(xs[j])) >= 64.0
		_check(xs.size() == 6 and apart and w.hazards.all(func(h): return h.get("shadow", false)), "the rush's Toll of Ruin: six chunks 64+ px apart, each with its shadow (%d)" % xs.size())
	# A retry puts the bell back and the count to nothing.
	b.phase = 2
	b._phase_slams = 3
	b.state = "stuck"
	b.timer = 0.0
	_step(w, 1)
	_until(w, func(): return b.state == "bowled", 1.0)
	b.reset_fight(false)
	_check(b._bell.is_empty() and b._phase_slams == 0 and b.state == "sleep" and b.phase == 1, "reset_fight: no bell out, slams uncounted")
	# He never leaves the arena after it, and the bell stays inside.
	b = _to_roll(w)
	var inside := true
	for i in int(8.0 / DT):
		_god(w)
		_step(w, 1)
		if not b._bell.is_empty():
			var r: Rect2 = b.bell_rect()
			inside = inside and r.position.x >= b.arena_left - 0.5 and r.end.x <= b.arena_right + 0.5
	_check(inside, "the bell never leaves the arena")
	# Killed with the bell out: it goes with him.
	b = _to_roll(w)
	_until(w, func(): return b.state == "bowled", 1.0)
	b.hp = 1.0
	b.phase = 3
	w.deal(b, 50.0, {"flat": 500.0})
	_step(w, 2)
	_check(not b.alive and b._bell.is_empty(), "his fall takes the bell with it")
	await _done(w)


# ---------------------------------------------------------------- Smother

func _to_smother(w: Node2D) -> Node2D:
	var s: Node2D = _wake(w)
	s._move_n = s.SMOTHER_EVERY - 2
	s._next(w.player)
	return s


func _test_smother() -> void:
	var w := await _rematch("snuffer")
	var s: Node2D = _to_smother(w)
	var pl: Node2D = w.player
	_check(s.state == "smother_rise" and s.smothers == 1, "the fourth move: Smother (%s)" % s.state)
	_until(w, func(): return s.state != "smother_rise", 1.0)
	_check(s.state == "smother_track" and absf(s.timer - (1.6 - DT)) < 0.02, "he's up over Wick; the ring follows him 1.6 s (%.2f)" % s.timer)
	# The ring follows at 60 px/s while he runs.
	_step(w, 20, {"right": true})
	var r0: float = s._ring_x
	_step(w, 60, {"right": true})
	var v: float = (s._ring_x - r0) / (60.0 * DT)
	_check(absf(v - 60.0) < 0.5, "the ring follows at 60 px/s (%.1f)" % v)
	_check(absf(s._cone_mouth().x - s._ring_x) < 6.0, "the snuffer's mouth hangs over the ring (%.1f off)" % absf(s._cone_mouth().x - s._ring_x))
	_until(w, func(): return s.state != "smother_track", 2.0, {})
	_check(s.state == "smother_lock" and absf(s.timer - (0.45 - DT)) < 0.02, "then it locks 0.45 s on Dusk (%.2f)" % s.timer)
	await _done(w)
	# Standing under it: 40 and a douse. Then the cone sticks 1.0 s, solid.
	w = await _rematch("snuffer")
	s = _to_smother(w)
	pl = w.player
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	var hp0: float = pl.hp
	_until(w, func(): return s.state == "stuck", 4.0, {})
	_check(pl.hp < hp0 and pl.has_status("douse"), "stood under it: hit (%.1f) and doused" % (hp0 - pl.hp))
	_check(absf(s.dmg("smother") / s.dmg_mult - 40.0) < 1e-4, "its base is 40")
	_check(absf(s.timer - (1.0 - DT)) < 0.02 and s.solid() and s.is_open() and absf(s._slam_x - s._ring_x) < 0.01, "the cone sticks 1.0 s where it fell: solid, open (%.2f)" % s.timer)
	await _done(w)
	# Clear of it (no hitstop): stuck 1.0 s by the clock.
	w = await _rematch("snuffer")
	s = _to_smother(w)
	_until(w, func(): return s.state == "smother_lock", 4.0, {})
	w.player.reset_at(Vector2(s._ring_x + (200.0 if s._ring_x < (s.arena_left + s.arena_right) * 0.5 else -200.0), w.player.position.y))
	_until(w, func(): return s.state == "stuck", 2.0, {})
	var t_stuck := 0.0
	while s.state == "stuck" and t_stuck < 2.0:
		_god(w)
		_step(w, 1)
		t_stuck += DT
	_check(absf(t_stuck - 1.0) < 0.03, "stuck 1.0 s (%.2f)" % t_stuck)
	await _done(w)
	# A runner at the lock's first tick, from the ring's middle, gets clear.
	for diff in ["dusk", "nightfall", "witching"]:
		w = await _rematch("snuffer", diff)
		s = _to_smother(w)
		pl = w.player
		_until(w, func(): return s.state == "smother_lock", 4.0, {})
		pl.reset_at(Vector2(s._ring_x, pl.position.y))
		pl.invuln = 0.0
		pl.hp = pl.max_hp
		hp0 = pl.hp
		var lock: float = s.timer + DT
		var away := "left" if s._ring_x > (s.arena_left + s.arena_right) * 0.5 else "right"
		_until(w, func(): return s.state == "stuck", 2.0, {away: true})
		_check(lock >= 0.40 - 1e-4 and pl.hp >= hp0 - 0.01, "%s: the lock is %.2f s (>= 0.40), and a runner from the ring's middle gets out" % [diff, lock])
		await _done(w)
	# Lights Out: solid while it's stuck, even out of his light.
	w = await _rematch("snuffer")
	s = _wake(w)
	s.phase = 3
	s._move_n = s.SMOTHER_EVERY - 2
	s._next(w.player)
	_until(w, func(): return s.state == "stuck", 4.0, {"left": true})
	w.player.reset_at(Vector2(s.arena_left + 40.0, w.player.position.y) if s._ring_x > s.arena_left + 400.0 else Vector2(s.arena_right - 40.0, w.player.position.y))
	_step(w, 1)
	_check(s.state == "stuck" and s.solid() and not s.lit_here(), "Lights Out: stuck, he's solid though out of Wick's light")
	await _done(w)


func _ledges(w: Node2D, b: Node2D) -> Array:
	## The top middle of each one-way ledge in the arena.
	var lv = w.level
	var out := []
	for ty in lv.height:
		var run := []
		for tx in lv.width + 1:
			var x: float = tx * TILE + TILE * 0.5
			if tx < lv.width and LevelData.is_ledge(lv.tile(tx, ty)) and x > b.arena_left and x < b.arena_right:
				run.append(tx)
			elif not run.is_empty():
				out.append(Vector2((float(run[0]) + float(run[run.size() - 1])) * 0.5 * TILE + TILE * 0.5, ty * TILE))
				run = []
	return out


func _smother_on(w: Node2D, spot: Vector2, pad := {}) -> Dictionary:
	## Wick at spot (settled), then a Smother: what came of it.
	var s: Node2D = w.boss
	var pl: Node2D = w.player
	pl.reset_at(spot)
	_step(w, 30)
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	var hp0: float = pl.hp
	var on_ground: bool = pl.on_floor and absf(pl.position.y - spot.y) < 1.0
	s._move_n = s.SMOTHER_EVERY - 2
	s._next(pl)
	var over := true
	var ring_y := -1.0
	var touch := false
	while s.state in s.SMOTHER_STATES:
		touch = touch or s.touch_damage()
		_step(w, 1, pad)
		if s.state == "smother_track":
			# (his bell's mouth over Wick's head, and the ring under his feet)
			over = over and s._cone_mouth().y < pl.position.y - pl.size.y
			ring_y = s._ring_y
	return {"hit": pl.hp < hp0 - 0.01, "doused": pl.has_status("douse"), "over": over, "ring_y": ring_y, "touch": touch,
			"ground": on_ground, "stuck_y": s.position.y, "state": s.state, "solid": s.solid(), "y": pl.position.y}


func _test_smother_ledges() -> void:
	## A ledge is no refuge: on each one the ring sits on the ledge under
	## him, the Snuffer hangs over him, and the cone comes down there (40 and
	## the douse) and sticks on the ledge, solid; then he floats down (no
	## jump in his place). Standing under a ledge it comes down through it.
	var w := await _rematch("snuffer")
	var s: Node2D = _wake(w)
	var ls := _ledges(w, s)
	await _done(w)
	_check(ls.size() >= 2, "the Snuffer's arena has its ledges (%d)" % ls.size())
	for i in ls.size():
		var l: Vector2 = ls[i]
		w = await _rematch("snuffer")
		s = _wake(w)
		var r := _smother_on(w, l)
		_check(r["ground"] and r["hit"] and r["doused"] and absf(float(r["ring_y"]) - l.y) < 0.5,
				"ledge %d: the ring on the ledge under him (%.0f), hit and doused" % [i + 1, float(r["ring_y"])])
		_check(r["over"] and not r["touch"], "ledge %d: the Snuffer's bell hangs over Wick's head (and he's no harm to touch beside him)" % (i + 1))
		_check(r["state"] == "stuck" and absf(float(r["stuck_y"]) - l.y) < 0.5 and r["solid"], "ledge %d: the cone sticks on the ledge, solid" % (i + 1))
		var y0: float = s.position.y
		var jump := 0.0
		while s.state == "stuck" or absf(s._lift) > 0.5:
			_god(w)
			_step(w, 1)
			jump = maxf(jump, absf(s.position.y - y0))
			y0 = s.position.y
			if s.state not in ["stuck", "drift"]:
				break
		_check(jump < 10.0, "ledge %d: then he floats down from it (at most %.1f px a tick: v2's own hop off the pole)" % [i + 1, jump])
		await _done(w)
		# Under the ledge, on the floor: the cone comes down through it.
		w = await _rematch("snuffer")
		s = _wake(w)
		var r2 := _smother_on(w, Vector2(l.x, s.floor_y))
		_check(r2["hit"] and absf(float(r2["ring_y"]) - s.floor_y) < 0.5, "under ledge %d: the ring on the floor, and the cone comes through the ledge" % (i + 1))
		await _done(w)
	# A jump at the drop doesn't clear it: the cone comes down through the air.
	w = await _rematch("snuffer")
	s = _to_smother(w)
	var pl: Node2D = w.player
	_until(w, func(): return s.state == "smother_lock", 4.0, {})
	pl.reset_at(Vector2(s._ring_x, s.floor_y))
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	var hp1: float = pl.hp
	var lock: float = s.timer
	var hold := 0.0
	var high := 0.0
	while s.state == "smother_lock":
		hold += DT
		# Pressed so he's near the top of his jump as it drops.
		_step(w, 1, {"jump": hold >= lock - 0.40})
		high = s.floor_y - pl.position.y
	_check(pl.hp < hp1 - 0.01 and high > 60.0, "a jump doesn't clear it (%.0f px up as it dropped)" % high)
	await _done(w)


func _test_smother_reaction() -> void:
	## The lock is signposted ahead: the ring's sweep fills through the track
	## and 0.5 s before the lock it flashes and warms. A Wick who stood in the
	## ring's middle and reacts 0.25 s after the warning (a human's reaction)
	## gets clear on every difficulty; one who keeps running is never under
	## it at the lock.
	var react := 0.25
	for diff in ["dusk", "nightfall", "witching"]:
		var w := await _rematch("snuffer", diff)
		var s: Node2D = _to_smother(w)
		var pl: Node2D = w.player
		_until(w, func(): return s.state == "smother_track", 2.0, {})
		pl.reset_at(Vector2(s._ring_x, s.floor_y))
		pl.invuln = 0.0
		pl.hp = pl.max_hp
		var hp0: float = pl.hp
		var sweeps := []
		var mono := true
		var prev := -1.0
		while float(s.smother_countdown()["warn"]) <= 0.0 and s.state == "smother_track":
			var sw: float = s.smother_countdown()["sweep"]
			mono = mono and sw >= prev
			prev = sw
			_step(w, 1)
		var ahead: float = s.timer
		_check(mono and prev > 0.5 and absf(ahead - s.SMOTHER_WARN) < 0.02,
				"%s: the sweep fills through the track (%.2f), and the warning comes %.2f s before the lock" % [diff, prev, ahead])
		var away := "left" if s._ring_x > (s.arena_left + s.arena_right) * 0.5 else "right"
		var tt := 0.0
		while s.state != "stuck" and tt < 3.0:
			_step(w, 1, {away: tt >= react})
			tt += DT
		_check(pl.hp >= hp0 - 0.01, "%s: stood in its middle, reacting %.2f s after the warning, he gets clear (lock %.2f s)" % [diff, react, s.smother_lock_time()])
		await _done(w)
		# How late a reaction still gets clear (reported).
		var latest := 0.0
		for r in [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70]:
			w = await _rematch("snuffer", diff)
			s = _to_smother(w)
			pl = w.player
			_until(w, func(): return s.state == "smother_track", 2.0, {})
			pl.reset_at(Vector2(s._ring_x, s.floor_y))
			pl.invuln = 0.0
			pl.hp = pl.max_hp
			hp0 = pl.hp
			_until(w, func(): return float(s.smother_countdown()["warn"]) > 0.0, 3.0, {})
			away = "left" if s._ring_x > (s.arena_left + s.arena_right) * 0.5 else "right"
			tt = 0.0
			while s.state != "stuck" and tt < 3.0:
				_step(w, 1, {away: tt >= r})
				tt += DT
			var hit: bool = pl.hp < hp0 - 0.01
			await _done(w)
			if hit:
				break
			latest = r
		print("  Smother on %s: from the ring's middle, the latest reaction that gets clear is %.2f s after the warning (%.2f s into the lock)" % [diff, maxf(latest, react), maxf(latest, react) - 0.5])
		# Running from the start: never under it at the lock.
		w = await _rematch("snuffer", diff)
		s = _wake(w)
		pl = w.player
		pl.reset_at(Vector2(s.arena_left + 200.0, s.floor_y))
		_step(w, 20)
		pl.invuln = 0.0
		pl.hp = pl.max_hp
		hp0 = pl.hp
		s._move_n = s.SMOTHER_EVERY - 2
		s._next(pl)
		var under := false
		while s.state in s.SMOTHER_STATES:
			_step(w, 1, {"right": true})
			if s.state == "smother_lock":
				under = under or (s.smother_zone() as Rect2).intersects(pl.rect())
		_check(not under, "%s: a Wick who keeps running is never under it at the lock" % diff)
		await _done(w)


func _to_lights_out(w: Node2D, s: Node2D) -> void:
	## A blow across the 25% line: he screams into Lights Out, and it's done.
	s.phase = 2
	s.hp = s.max_hp * 0.3
	s.state = "stuck"
	s.timer = 5.0
	w.deal(s, 1.0, {"flat": s.max_hp * 0.2})
	_until(w, func(): return s.state == "lights_out", 0.5)
	_until(w, func(): return s.state != "lights_out", 2.0)


func _test_snuffer_rush() -> void:
	var w := await _rematch("snuffer")
	var s: Node2D = _wake(w)
	s._summon()
	_check(s._wings.size() == 3, "the rush's Gutter Call: three moths")
	for m in s._wings:
		if is_instance_valid(m):
			m.alive = false
			m.gone = true
	s._wings.clear()
	# Lights Out: no story line in the rush (Mother Taper's warning).
	_to_lights_out(w, s)
	_check(s.phase == 3 and s.barks_skipped == 1, "Lights Out in the rush: no story line (%d skipped)" % s.barks_skipped)
	# Lights Out: two Lunges.
	s.phase = 3
	s._move_n = 0
	s._next(w.player)
	_check(s.state == "lunge_draw", "Lights Out: the Lunge (%s)" % s.state)
	var draws := 0
	var last := "lunge_draw"
	for i in int(5.0 / DT):
		_god(w)
		_step(w, 1)
		if s.state == "lunge_draw" and last != "lunge_draw":
			draws += 1
		last = s.state
		if s.state == "drift":
			break
	_check(draws == 1 and s._second_lunge, "then a second draw-back and Lunge at him (%d more)" % draws)
	# Every fourth move over a long fight is a Smother; his other moves still come.
	s.reset_fight()
	s = _wake(w)
	var moves := []
	last = ""
	for i in int(60.0 / DT):
		_god(w)
		_step(w, 1)
		if s.state != last and s.state in ["track", "snuff_tell", "sink", "choir", "lunge_draw", "smother_rise"]:
			moves.append(s.state)
		last = s.state
	var sm := moves.count("smother_rise")
	_check(sm >= 3 and moves.count("track") >= 3, "a minute of him: %d Smothers among %s" % [sm, moves])
	await _done(w)


# ---------------------------------------------------------------- the mods

func _test_warded() -> void:
	for boss in ["tollgrave", "snuffer"]:
		var w := await _rematch(boss, "dusk", ["warded"])
		var b: Node2D = _wake(w)
		var m = BossMods.of(b)
		_check(m != null and m.motes_up() == 3, "%s with Warded Wax: three motes" % boss)
		_check(b.lights().size() >= 3, "%s: the motes are lights" % boss)
		# Open him, then strike: each mote takes a blow, even in the window.
		b.state = "stuck"
		b.timer = 5.0
		var hp0: float = b.hp
		var landed := 0
		for i in 3:
			var r: Dictionary = w.deal(b, 1.0, {"flat": 5.0, "from_x": b.position.x - 30.0})
			if r["hit"]:
				landed += 1
		_check(landed == 0 and absf(b.hp - hp0) < 1e-4 and m.motes_up() == 0, "%s: three blows in the window, three motes gone, no damage" % boss)
		var r2: Dictionary = w.deal(b, 1.0, {"flat": 5.0, "from_x": b.position.x - 30.0})
		_check(r2["hit"] and b.hp < hp0, "%s: the fourth lands" % boss)
		# Back in 5 s (not the Omen's 4).
		_step(w, int(4.5 / DT))
		_check(m.motes_up() == 0, "%s: not back at 4.5 s" % boss)
		_step(w, int(0.6 / DT))
		_check(m.motes_up() == 3, "%s: back after 5 s" % boss)
		# A stomp breaks all three and lands.
		b.state = "stuck"
		b.timer = 5.0
		hp0 = b.hp
		var r3: Dictionary = w.deal(b, 1.0, {"flat": 5.0, "how": "stomp"})
		_check(r3["hit"] and b.hp < hp0 and m.motes_up() == 0, "%s: a stomp breaks all three and lands" % boss)
		b.reset_fight()
		_check(m.motes_up() == 3, "%s: a retry puts them back" % boss)
		await _done(w)


func _test_echoing() -> void:
	# Tollgrave: a wave's echo retraces it 0.8 s behind at 60%.
	var w := await _rematch("tollgrave", "dusk", ["echoing"])
	var b: Node2D = _wake(w)
	var m = BossMods.of(b)
	var pl: Node2D = w.player
	_check(m != null and m.has("echoing"), "Echoing Wax on Tollgrave")
	w.hazards.clear()
	b.phase = 1
	b._waves(1)
	var wave: Dictionary = {}
	for h in w.hazards:
		if float((h["vel"] as Vector2).x) > 0.0:
			wave = h
	_check(not wave.is_empty() and (m.echoes as Array).size() == 2, "each wave is watched (%d)" % (m.echoes as Array).size())
	var path := []
	for i in int(0.8 / DT):
		b.state = "stuck"
		b.timer = 5.0
		path.append((wave["rect"] as Rect2).position.x if float(wave["life"]) > 0.0 else NAN)
		_step(w, 1)
	var e: Dictionary = {}
	for x in m.echoes:
		if is_same(x["src"], wave):
			e = x
	var er: Rect2 = m.echo_rect(e)
	_check(not e.is_empty() and absf(er.position.x - float(path[0])) < 3.0, "0.8 s on, its echo sets off where the wave did (%.1f vs %.1f)" % [er.position.x, float(path[0])])
	# Stand where the wave went 0.9 s later: the echo, not the wave, hits, for 60%.
	await _done(w)
	w = await _rematch("tollgrave", "dusk", ["echoing"])
	b = _wake(w)
	m = BossMods.of(b)
	pl = w.player
	w.hazards.clear()
	var zone := Rect2(b.position.x + 200.0, b.position.y - 40.0, 30.0, 40.0)
	m.strike(zone, 50.0)
	_step(w, int(0.5 / DT))
	b.state = "stuck"
	b.timer = 5.0
	pl.reset_at(Vector2(zone.get_center().x, b.position.y))
	pl.invuln = 0.0
	pl.hp = pl.max_hp
	var hp0: float = pl.hp
	var waiting: Array = m.marks().filter(func(x): return bool(x["wait"]))
	_check((m.echoes as Array).size() == 1 and waiting.size() == 1 and (waiting[0]["r"] as Rect2) == zone,
			"a strike's echo waits, its box marked where it will strike (%d marks)" % waiting.size())
	var waited := 0.5
	while pl.hp >= hp0 and waited < 1.5:
		b.state = "stuck"
		b.timer = 5.0
		_step(w, 1)
		waited += DT
	var raw := 50.0 * BossMods.ECHO_SHARE
	_check(absf(waited - 0.8) < 0.03 and pl.hp < hp0 and m.echo_hits == 1, "the same box strikes again 0.8 s later (%.2f s, %.1f lost of a raw %.0f)" % [waited, hp0 - pl.hp, raw])
	await _done(w)
	# The Snuffer: the slam's echo, and the Lunge retraced.
	w = await _rematch("snuffer", "dusk", ["echoing"])
	var s: Node2D = _wake(w)
	m = BossMods.of(s)
	s._slam_x = s.position.x + 65.0
	s._slam(w.player)
	_check((m.echoes as Array).size() >= 1, "the Snuffer's slam leaves its echo")
	s.reset_fight()
	s = _wake(w)
	s.phase = 3
	s._move_n = 0
	s._next(w.player)
	_until(w, func(): return s.state == "lunge", 2.0)
	_until(w, func(): return s.state != "lunge", 3.0)
	var lunge_e := (m.echoes as Array).filter(func(x): return str(x["key"]) == "lunge")
	_check(lunge_e.size() >= 1 and (lunge_e[0]["samples"] as Array).size() > 20, "the Lunge is recorded tick by tick for its echo")
	await _done(w)
	# A falling one (the Toll of Ruin's rubble, the Drip Choir's drips) starts
	# over the view: its echo is marked on the floor where it will land, in
	# view, from when the first one falls until the echo lands, and lands there.
	# (in a phone-shaped view: headless the root view is square, and the view's
	# top is where a chunk starts)
	_phone = SubViewport.new()
	_phone.size = Vector2i(844, 390)
	root.add_child(_phone)
	w = await _rematch("tollgrave", "dusk", ["echoing"])
	b = _wake(w)
	m = BossMods.of(b)
	b.phase = 3
	b.hp = b.max_hp * 0.2
	w.hazards.clear()
	b.state = "windup"
	b.timer = 0.0
	_step(w, 1)
	var fy: float = b.position.y
	await _falling_echoes(w, m, "rubble", fy)
	await _done(w)
	w = await _rematch("snuffer", "dusk", ["echoing"])
	s = _wake(w)
	m = BossMods.of(s)
	w.hazards.clear()
	s._choir()
	await _falling_echoes(w, m, "drip", s.floor_y)
	await _done(w)
	_phone.queue_free()
	_phone = null


func _falling_echoes(w: Node2D, m: RefCounted, kind: String, fy: float) -> void:
	var ticks := 0
	var missing := 0
	var landed := {}
	var marked := {}
	var n := 0
	for i in int(3.0 / DT):
		_god(w)
		w.boss.set("timer", maxf(float(w.boss.get("timer")), 0.5))   # (he holds still)
		_step(w, 1)
		var vr: Rect2 = w.view_rect()
		var mk: Array = m.marks()
		for e in m.echoes:
			var src = e["src"]
			if not (src is Dictionary) or str(src.get("kind", "")) != kind:
				continue
			n = maxi(n, 1)
			var land: Dictionary = m._landing(e)
			var el: float = m.clock - float(e["start"]) - m.ECHO_DELAY
			if land.is_empty() or el >= float(land["t"]):
				continue
			ticks += 1
			var at: Vector2 = land["p"]
			var ok := false
			for x in mk:
				if x.has("floor") and bool(x["wait"]) and (x["floor"] as Vector2).distance_to(at) < 1.0:
					# on the floor, and in view (up and down: the view pans across)
					ok = at.y > vr.position.y and at.y < vr.end.y and absf(at.y - fy) < 4.0
			if not ok:
				missing += 1
			marked[str(e["start"]) + str(at.x)] = at
			if not bool(e["open"]):
				var r: Rect2 = (e["samples"] as Array)[(e["samples"] as Array).size() - 1]["r"]
				landed[str(e["start"]) + str(at.x)] = absf(r.get_center().x - at.x) < 1.0
	var all_there := true
	for k in landed:
		all_there = all_there and bool(landed[k])
	_check(ticks > 30 and missing == 0 and marked.size() >= 4 and all_there,
			"%s's echoes: marked on the floor in view where they land, %d ticks of %d (%d of them)" % [kind, ticks - missing, ticks, marked.size()])


# ---------------------------------------------------------------- the modes' wiring

func _test_waxworks_wiring() -> void:
	for boss in ["tollgrave", "snuffer"]:
		var w := await _rematch(boss)
		var b: Node2D = w.boss
		var ref := _boss_life(boss, int(w.area))
		_check(b.rush and absf(b.max_hp - ref * BossMods.RUSH_HP[boss]) < 1.0,
				"%s rematch: life = his own x%.2f, once (%.0f vs %.0f; no fallback on top)" % [boss, BossMods.RUSH_HP[boss], b.max_hp, ref * BossMods.RUSH_HP[boss]])
		_check((b.tint as Color).is_equal_approx(Color.WHITE.lerp(Mode.WAX_TINT, Mode.WAX_TINT_MIX)), "%s: the cast is cream wax" % boss)
		await _done(w)
		w = await _rematch(boss, "dusk", ["thicker"])
		_check(absf(w.boss.max_hp - ref * BossMods.RUSH_HP[boss] * 1.5) < 1.0, "%s + Thicker Wax: x1.5 more" % boss)
		# The fall: no drops (the seals pay), rush_boss in the result.
		var n0: int = w.pickups.size()
		w.boss.hp = 1.0
		w.boss.phase = 3
		w.deal(w.boss, 1.0, {"flat": 99999.0})
		_step(w, int(1.6 / DT))
		_check(w.pickups.filter(func(p): return p["kind"] == "item" or p["kind"] == "relic").is_empty(), "%s: a rush boss drops nothing" % boss)
		_check(str(w.result().get("rush_boss", "")) == boss, "%s: the result names the rush boss" % boss)
		await _done(w)
	# Warded and Echoing Wax are open Tweaks now.
	_check(Waxworks.tweak_open("warded") and Waxworks.tweak_open("echoing"), "the Waxworks offers Warded and Echoing Wax")
	# A Descent echo depth: rush on, x0.8 after the rush life.
	_fresh()
	var ew: Node2D = await _echo_depth()
	if ew != null:
		var eb: Node2D = ew.boss
		var ref2 := _boss_life(str(eb.boss_id), int(ew.area))
		_check(eb.rush and absf(eb.max_hp - ref2 * BossMods.RUSH_HP[str(eb.boss_id)] * 0.8) < 1.0,
				"a Descent echo: rush on, life x0.8 of the rush life (%.0f)" % eb.max_hp)
		await _done(ew)
	else:
		print("  skipped: no Descent echo depth to build")


func _echo_depth() -> Node2D:
	## Depth 5 of a Descent run: Old Tollgrave's dream (as test_modes builds it).
	var m = Descent.new()
	m.cls = "knight"
	m.headless = true
	m.setup(Descent.new_run("knight", "dusk", "normal", 5, 8))
	var lv: RefCounted = m.level_data()
	if lv == null or str(m.built.get("kind", "")) != "echo":
		return null
	var w := _mode_world(m, lv)
	await process_frame
	return w


# ---------------------------------------------------------------- the rush sim

func _sim_fight(boss: String, level: int, story := false, seed_n := 0, k := -1.0) -> Dictionary:
	## The reference knight at this level against the boss on Dusk: a rush
	## rematch (the rematch area, his rush life), or with story the boss's
	## own level (v2's fight, for the calibration). A clean fighter: never
	## hit (he dodges everything), SIM_REACT s to react to an opening, then
	## in and swinging as fast as the kit allows (basic swings, no stomps or
	## Specials) while it lasts, never pressing into a body that hurts to
	## touch; out of it he stands off (Tollgrave 80 px, out of the slam's
	## front; the Snuffer 110). Seconds from the wake to the fall.
	seed(9000 + level * 7 + seed_n)
	var w: Node2D = null
	if story:
		w = await _story(STORY_OF[boss], level)
	else:
		w = await _rematch(boss, "dusk", [], level)
	w.rng.seed = 77 + seed_n
	var b: Node2D = w.boss
	var pl: Node2D = w.player
	if k > 0.0 and not story:
		# (the derivation: this rush life instead of RUSH_HP's)
		b.max_hp = float(b.max_hp) / BossMods.rush_hp(boss) * k
		b.hp = b.max_hp
	var fy: float = float(b.floor_y) if b.get("floor_y") != null else b.position.y
	b.active = true
	pl.reset_at(Vector2(b.position.x - 200.0, fy))
	var stand := 80.0 if boss == "tollgrave" else 110.0
	var woke := -1.0
	var t := 0.0
	var since := -1.0
	var windows := 0
	var last_state := ""
	var log := []
	while t < SIM_LIMIT and b.alive:
		pl.hp = pl.max_hp
		pl.invuln = 1.0
		var open: bool = _sim_open(boss, b)
		if open and since < 0.0:
			since = t
			windows += 1
		elif not open:
			since = -1.0
		var dx: float = b.center().x - pl.position.x
		var toward := "right" if dx > 0.0 else "left"
		var away := "left" if dx > 0.0 else "right"
		if (away == "left" and pl.position.x < b.arena_left + 40.0) or (away == "right" and pl.position.x > b.arena_right - 40.0):
			away = toward
		var harm: bool = b.touch_damage() and (b.hurt_rect() as Rect2).grow(4.0).intersects(pl.rect())
		var pd := {}
		if woke < 0.0:
			pd[toward] = true
		elif open and t - since >= SIM_REACT:
			if harm:
				pd[away] = true
			elif not _can_hit(pl, b) or (signf(dx) != float(pl.facing) and absf(dx) > 4.0):
				pd[toward] = true
			# Up to him when he's on a ledge (he leaps onto them): a held jump.
			if b.rect().end.y < pl.position.y - 20.0 and absf(dx) < 140.0:
				pd["jump"] = true
			pd["attack"] = int(t / DT) % 2 == 0
		elif harm or absf(dx) < stand:
			pd[away] = true
		_step(w, 1, pd)
		t += DT
		if woke < 0.0 and b.state != "sleep":
			woke = t
		if _sim_log and b.state != last_state:
			last_state = b.state
			if b.state in ["stuck", "bowled", "hurt", "roar", "roll_tell", "toss", "leap", "recoil", "lights_out", "smother_rise"]:
				log.append("%.1f %s p%d %.0f%% y%.0f s%d" % [t, b.state, b.phase, 100.0 * b.hp / b.max_hp, b.position.y, int(b.get("_phase_slams")) if b.get("_phase_slams") != null else -1])
	if _sim_log:
		print("    %s L%d%s seed %d: %.1f s: %s" % [boss, level, " story" if story else "", seed_n, t - maxf(woke, 0.0), ", ".join(log)])
	var out := {"boss": boss, "level": level, "area": int(w.area), "time": t - maxf(woke, 0.0), "won": not b.alive,
			"hp": float(b.max_hp), "windows": windows, "phase": int(b.phase)}
	game.return_hero()
	await _done(w)
	return out


func _sim_open(boss: String, b: Node2D) -> bool:
	## When the fighter goes in: Tollgrave's bell stuck (or bowled), the
	## Snuffer solid (the pole stuck, or in light), any other boss's is_open().
	match boss:
		"tollgrave":
			return b.vulnerable()
		"snuffer":
			return b.solid()
	return b.has_method("is_open") and bool(b.is_open())


func _sim_ready(boss: String) -> bool:
	## A boss the sim can fight here: its script, its story level and its arena.
	var ek = load("res://scripts/enemy_kinds.gd")
	return (ek.KINDS as Dictionary).has(boss) and FileAccess.file_exists("res://levels/%s.txt" % STORY_OF[boss]) \
			and FileAccess.file_exists("res://levels/rush/%s.txt" % boss)


func _can_hit(pl: Node2D, b: Node2D) -> bool:
	var rv: Vector2 = pl.stats.get("reach", Vector2(38, 34))
	var x: float = pl.position.x + (pl.facing * (pl.size.x * 0.5 - 4.0))
	if pl.facing < 0:
		x -= rv.x
	var box := Rect2(x, pl.position.y - pl.size.y - 4.0, rv.x - 6.0, rv.y)
	return box.intersects(b.rect())


func _test_rush_sim() -> void:
	## spec §5.6: each rush fight lasts 60-80 s for the reference hero at the
	## rush area; BossMods.RUSH_HP is set from this.
	## The sim's fighter is clean (never hit), so it's quicker than a person:
	## it's calibrated on the one human number the design has, v2's first-win
	## lengths (spec §5.1: Tollgrave 40-60 s, the Snuffer about 50). Its story
	## fight at the reference knight's arrival, over SIM_SEEDS runs, gives the
	## boss's human factor H = the target's middle / the sim's time. Then the
	## rematches at the levels a rematch is fought at (with their rush moves
	## and rush life): H x the sim's time is the rush fight's length. Its
	## median must sit in 60-80 s, every level's mean within 15 s of it.
	var t0 := Time.get_ticks_msec()
	var seeds := 3
	for boss in SIM_LEVELS:
		var ours: bool = V2_BOSSES.has(boss)
		if not _sim_ready(boss):
			print("  rush sim: skipped %s (its script, %s or rush/%s.txt isn't in this build)" % [boss, STORY_OF[boss], boss])
			continue
		if not ours and not _sim_all:
			continue   # (BA's and BB's bosses: WAXBY_RUSH_SIM=1 derives theirs)
		var st := []
		for k in seeds:
			var r0 := await _sim_fight(boss, int(STORY_AT[boss]), true, k)
			_sim_check(ours, bool(r0["won"]), "the sim beats %s's story fight (seed %d)" % [boss, k])
			st.append(float(r0["time"]))
		var cal: Vector2 = STORY_TARGET[boss]
		var h: float = (cal.x + cal.y) * 0.5 / maxf(_mean(st), 1.0)
		print("  rush sim, %s's story fight at L%d: %s s, mean %.1f; v2's first win %.0f-%.0f s: human factor %.2f" % [boss, STORY_AT[boss], _fmt(st), _mean(st), cal.x, cal.y, h])
		var levels: Array = SIM_LEVELS[boss]
		var got := await _sim_rush(boss, levels, seeds, h, -1.0)
		var med: float = got["median"]
		print("  rush sim, %s's rematch at x%.2f (x H): %s; median %.1f s" % [boss, BossMods.RUSH_HP[boss], "; ".join(got["rows"]), med])
		_sim_check(ours, bool(got["won"]), "the sim beats every %s rematch" % boss)
		_sim_check(ours, med >= SIM_LO and med <= SIM_HI, "%s's rush fight: median %.1f s (want %.0f-%.0f)" % [boss, med, SIM_LO, SIM_HI])
		var means: Array = got["means"]
		for i in levels.size():
			_sim_check(ours, float(means[i]) >= SIM_LO and float(means[i]) <= SIM_HI,
					"%s's rush fight at L%d: mean %.1f s (want %.0f-%.0f at every level sampled)" % [boss, levels[i], float(means[i]), SIM_LO, SIM_HI])
		if _sim_all:
			# The derivation: the rush life that puts every level's mean in
			# 60-80 s with the most room at the worst level (else the one that
			# misses by least).
			var best := -1.0
			var best_d := INF
			var grid := []
			for i in 9:
				var kk: float = BossMods.RUSH_HP[boss] * (0.80 + 0.05 * i)
				var g := await _sim_rush(boss, levels, seeds, h, kk)
				var miss := 0.0
				for mu in g["means"]:
					miss = maxf(miss, maxf(SIM_LO - float(mu), float(mu) - SIM_HI))
				# (all in: the most room inside 60-80 at the worst level, so a
				# rematch at any level stays in it and clear of Waxley's Clock)
				var d: float = 100.0 + miss if miss > 0.0 else miss + 0.05 * absf(float(g["median"]) - SIM_AIM)
				grid.append("x%.2f median %.1f s, means %s" % [kk, g["median"], _fmt(g["means"])])
				if d < best_d:
					best_d = d
					best = kk
			print("  rush sim, %s's derivation: %s -> x%.2f" % [boss, "; ".join(grid), best])
	print("  (the rush sim took %d ms)" % (Time.get_ticks_msec() - t0))


func _sim_check(ours: bool, ok: bool, what: String) -> void:
	## BR's bosses are held to it; BA's and BB's are only reported.
	if ours:
		_check(ok, what)
	elif not ok:
		print("  note (BA/BB): ", what)


func _sim_rush(boss: String, levels: Array, seeds: int, h: float, k: float) -> Dictionary:
	## The rematches at these levels, SIM_SEEDS runs each, their times x H.
	var all := []
	var rows := []
	var means := []
	var won := true
	for lvl in levels:
		var ts := []
		var area := 0
		for sd in seeds:
			var r := await _sim_fight(boss, int(lvl), false, sd, k)
			won = won and bool(r["won"])
			ts.append(float(r["time"]) * h)
			area = int(r["area"])
		all.append_array(ts)
		means.append(_mean(ts))
		rows.append("L%d area %d %s s" % [lvl, area, _fmt(ts)])
	all.sort()
	var med: float = all[all.size() / 2] if all.size() % 2 == 1 else (float(all[all.size() / 2 - 1]) + float(all[all.size() / 2])) * 0.5
	return {"median": med, "rows": rows, "means": means, "won": won}


func _mean(xs: Array) -> float:
	var n := 0.0
	for x in xs:
		n += float(x)
	return n / maxf(xs.size(), 1)


func _fmt(xs: Array) -> String:
	return "/".join(xs.map(func(x): return "%.0f" % float(x)))


# ---------------------------------------------------------------- rules

func _test_code_rules() -> void:
	## New code draws with TriBatch (contract §1): no draw_circle,
	## draw_colored_polygon or draw_polyline in boss_mods.gd or in the rush's
	## sections of the two v2 bosses.
	var bad := []
	var src := FileAccess.get_file_as_string("res://scripts/boss_mods.gd")
	for fn in ["draw_circle(", "draw_colored_polygon(", "draw_polyline("]:
		if src.contains(fn):
			bad.append("boss_mods.gd: " + fn)
	for pair in [["boss.gd", "# ---------------------------------------------------------------- the rush"], ["snuffer_boss.gd", "# ---------------------------------------------------------------- the rush"]]:
		var s := FileAccess.get_file_as_string("res://scripts/" + pair[0])
		var at := s.find(pair[1])
		var part := s.substr(at) if at >= 0 else ""
		for fn in ["draw_circle(", "draw_colored_polygon(", "draw_polyline("]:
			if part.contains(fn):
				bad.append(pair[0] + ": " + fn)
		_check(at >= 0, "%s has its rush section" % pair[0])
	_check(bad.is_empty(), "the rush's drawing is TriBatch only (%s)" % [bad])


# ---------------------------------------------------------------- screenshots

func _shot(w: Node2D, dir: String, name: String, zoom_at := Vector2.INF) -> void:
	## The window as it is; with zoom_at (a world point), also a 2x close-up
	## round it (name_zoom).
	for i in 3:
		await process_frame
	var img := root.get_texture().get_image()
	var p := dir.path_join(name + ".png")
	img.save_png(p)
	print("saved ", p)
	if zoom_at != Vector2.INF:
		var vr: Rect2 = w.view_rect()
		var k := float(img.get_width()) / vr.size.x
		var c := (zoom_at - vr.position) * k
		var box := Rect2i(Rect2(c - Vector2(150, 120), Vector2(300, 200))).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		if box.size.x > 10 and box.size.y > 10:
			var z := img.get_region(box)
			z.resize(box.size.x * 2, box.size.y * 2, Image.INTERPOLATE_LANCZOS)
			z.save_png(dir.path_join(name + "_zoom.png"))


func _live(w: Node2D, seconds: float, pad := {}) -> void:
	## Real frames, the World's own loop (so the dark, the glow and the HUD draw).
	for i in int(seconds / DT):
		w.test_pad = pad
		await physics_frame


func _shot_world(boss: String, tweaks: Array = []) -> Node2D:
	_fresh()
	game.borrow_hero(_reference(20, Waxworks.rematch_area(boss, "dusk", 20)))
	for k in ["boss_card_tollgrave", "boss_card_snuffer"]:
		game.mark_seen(k)
	var m = Waxworks.new()
	m.headless = true
	m.setup(boss, "dusk", tweaks)
	var w: Node2D = WorldScript.new()
	w.setup(m.level_data())
	w.mode = m
	m.world = w
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	if OS.get_environment("WAXBY_RUSH_SHOTS_HALF") != "" and w.glow:
		w.glow.modulate.a = 0.5   # the tells at half alpha (a dim phone)
	return w


func _until_live(w: Node2D, done: Callable, seconds: float, pad := {}) -> void:
	for i in int(seconds / DT):
		if done.call():
			return
		w.test_pad = pad
		await physics_frame


func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# Bell Roll: the tell's lane, the bell out and his opening, then (the
	# bell still out, closed and empty-handed) the Skull Choir and his walk
	# at Wick, and the catch.
	var w := await _shot_world("tollgrave")
	var b: Node2D = w.boss
	b.active = true
	w.player.reset_at(Vector2(b.position.x - 150.0, b.position.y))
	w.player.invuln = 1000.0
	await _live(w, 2.0)
	b.phase = 2
	b.hp = b.max_hp * 0.5
	b._phase_slams = 3
	b.state = "stuck"
	b.timer = 0.0
	await _live(w, 0.35)
	await _shot(w, dir, "bell_roll_1_tell")
	await _live(w, 0.45)
	await _shot(w, dir, "bell_roll_2_bowled", b.center())
	await _live(w, 0.8)
	await _shot(w, dir, "bell_roll_3_rolling")
	await _until_live(w, func(): return b.state == "toss", 2.0)
	await _live(w, 0.3)
	await _shot(w, dir, "bell_roll_4_choir", b.center())
	await _until_live(w, func(): return b.state == "stalk", 2.0)
	await _live(w, 0.5)
	await _shot(w, dir, "bell_roll_5_stalk", b.center())
	await _until_live(w, func(): return b._bell.is_empty() or bool(b._bell["bounced"]), 6.0)
	await _live(w, 0.5)
	await _shot(w, dir, "bell_roll_6_back", b.center())
	await _until_live(w, func(): return b._bell.is_empty(), 6.0)
	await _live(w, 0.1)
	await _shot(w, dir, "bell_roll_7_caught", b.center())
	w.queue_free()
	await process_frame
	# Smother on the floor: rising, the sweep filling, the warning, the
	# lock, stuck.
	w = await _shot_world("snuffer")
	var s: Node2D = w.boss
	s.active = true
	w.player.reset_at(Vector2(s.position.x - 220.0, s.floor_y))
	w.player.invuln = 1000.0
	await _live(w, 2.0)
	s._move_n = s.SMOTHER_EVERY - 2
	s._next(w.player)
	await _live(w, 0.3)
	await _shot(w, dir, "smother_1_rise")
	await _until_live(w, func(): return s.state == "smother_track", 1.0)
	await _live(w, 0.5, {"left": true})
	await _shot(w, dir, "smother_2_track", Vector2(s._ring_x, s.floor_y - 30.0))
	await _until_live(w, func(): return float(s.smother_countdown()["warn"]) > 0.3, 2.0)
	await _shot(w, dir, "smother_3_warning", Vector2(s._ring_x, s.floor_y - 30.0))
	await _until_live(w, func(): return s.state == "smother_lock", 1.0)
	await _live(w, 0.25)
	await _shot(w, dir, "smother_4_lock", Vector2(s._ring_x, s.floor_y - 30.0))
	await _until_live(w, func(): return s.state == "stuck", 1.0)
	await _live(w, 0.1)
	await _shot(w, dir, "smother_5_stuck")
	w.queue_free()
	await process_frame
	# Smother on a ledge: he hangs over Wick, the ring on the ledge, the cone
	# stuck on it.
	w = await _shot_world("snuffer")
	s = w.boss
	s.active = true
	var ls := _ledges(w, s)
	w.player.reset_at(ls[0])
	w.player.invuln = 1000.0
	await _live(w, 2.0)
	w.player.reset_at(ls[0])
	await _live(w, 0.3)
	s._move_n = s.SMOTHER_EVERY - 2
	s._next(w.player)
	await _until_live(w, func(): return s.state == "smother_track", 1.0)
	await _live(w, 0.6)
	await _shot(w, dir, "ledge_smother_1_track", Vector2(s._ring_x, s._ring_y - 30.0))
	await _until_live(w, func(): return s.state == "smother_lock", 2.0)
	await _live(w, 0.2)
	await _shot(w, dir, "ledge_smother_2_lock", Vector2(s._ring_x, s._ring_y - 30.0))
	await _until_live(w, func(): return s.state == "stuck", 1.0)
	await _live(w, 0.2)
	await _shot(w, dir, "ledge_smother_3_stuck", Vector2(s._ring_x, s._ring_y - 30.0))
	w.queue_free()
	await process_frame
	# Smother in Lights Out (the darkest the fight gets).
	w = await _shot_world("snuffer")
	s = w.boss
	s.active = true
	w.player.reset_at(Vector2(s.position.x - 220.0, s.floor_y))
	w.player.invuln = 1000.0
	await _live(w, 2.0)
	s.phase = 2
	s.hp = s.max_hp * 0.3
	s.state = "stuck"
	s.timer = 5.0
	w.deal(s, 1.0, {"flat": s.max_hp * 0.2})
	await _until_live(w, func(): return s.state != "lights_out" and s.phase == 3, 3.0)
	s._move_n = s.SMOTHER_EVERY - 2
	s._next(w.player)
	await _until_live(w, func(): return s.state == "smother_track", 1.0)
	await _live(w, 0.5)
	await _shot(w, dir, "dark_smother_1_track", Vector2(s._ring_x, s.floor_y - 30.0))
	await _until_live(w, func(): return float(s.smother_countdown()["warn"]) > 0.3, 2.0)
	await _shot(w, dir, "dark_smother_2_warning", Vector2(s._ring_x, s.floor_y - 30.0))
	await _until_live(w, func(): return s.state == "smother_lock", 1.0)
	await _live(w, 0.25)
	await _shot(w, dir, "dark_smother_3_lock", Vector2(s._ring_x, s.floor_y - 30.0))
	w.queue_free()
	await process_frame
	# Echoing Wax on the Toll of Ruin: the chunks falling, landed with their
	# echoes marked on the floor, the echoes falling.
	w = await _shot_world("tollgrave", ["echoing"])
	b = w.boss
	b.active = true
	w.player.reset_at(Vector2(b.position.x - 170.0, b.position.y))
	w.player.invuln = 1000.0
	await _live(w, 2.0)
	b.phase = 3
	b.hp = b.max_hp * 0.2
	w.hazards.clear()
	b.state = "windup"
	b.timer = 0.0
	await _live(w, 0.8)
	await _shot(w, dir, "rubble_echo_1_falling")
	await _live(w, 0.45)
	await _shot(w, dir, "rubble_echo_2_waiting", Vector2(w.player.position.x, b.position.y - 40.0))
	await _live(w, 0.55)
	await _shot(w, dir, "rubble_echo_3_echoes")
	w.queue_free()
	await process_frame
	# The mods: Warded motes and Echoing's ring and echo boxes, on each boss.
	for boss in ["tollgrave", "snuffer"]:
		w = await _shot_world(boss, ["warded", "echoing"])
		var bb: Node2D = w.boss
		bb.active = true
		w.player.reset_at(Vector2(bb.position.x - 170.0, bb.position.y if boss == "tollgrave" else bb.floor_y))
		w.player.invuln = 1000.0
		await _live(w, 2.0)
		var m = BossMods.of(bb)
		for i in 400:
			await physics_frame
			if m != null and m.echo_marks > 0:
				break
		await _shot(w, dir, "mods_%s_echo" % boss)
		await _live(w, 0.5)
		await _shot(w, dir, "mods_%s_later" % boss)
		w.queue_free()
		await process_frame
	game.return_hero()
