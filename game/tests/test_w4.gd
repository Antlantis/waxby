extends SceneTree
## World 4, the Frozen Carillon (WL4): features/clockwork.gd's numbers and
## the rules 4-1 to 4-4 are laid out to (workstreams.md 2.1 WL4).
##
## Features (in small levels built here): ice stops a run in 134 px (the
## owner's feel lab, round 2: player.gd's constants); rime melts in
## 0.4 + rime_k x (1 - f) s (Dusk 0.4 full, 0.8 near empty; Nightfall
## 0.4 + 0.8 x (1 - f)), its progress holds rime_hold s between touches,
## fire melts it in 0.2 s, it refreezes after rime_refreeze s over a 1.0 s
## tell that starts on a beat, never into a body; an icicle tells 0.45 s
## (0.40 / 0.35), falls and hurts, a swing knocks it down harmlessly, it grows
## back; a belt carries 80 px/s and reverses after its 0.6 s tell; a cog's
## tooth goes round in 6.43 s (12 ticks) and carries its rider round; weights
## swing +-50 deg in 3.21 s (6 ticks), in a row half a swing apart, hurt at
## the bottom and clear a standing Waxby at the ends; on Dusk no weight
## knocks him toward a pit edge within 3 tiles; swings +-40 deg in 3.21 s,
## staying level; everything keeps the tick (0.536 s on every difficulty,
## when the header is absent too) and stops with stop_time; a Y in a boss
## arena is the boss's own pivot.
##
## Levels (when 4-*.txt exist): the headers and registry; altars (3-5 in a
## regular level, an altar by every sealed room's door) and checkpoint gaps
## (<= 85); sigils, the Dread, the cast its roster: header declares and the
## threat its threat: header does, ramping 4-1 to 4-3 (tests/level_rules.gd,
## since Build 2: no fixed widths, counts or density); no Gutterwings; each level's
## inscription (one at most) on a sign; required ice landings >= 3
## tiles in 4-1 / 4-2 and >= 2 from 4-3 (lone ice blocks only on the star
## routes); rime never a required floor (the bot reaches every goal with rime
## as air, and with rime solid until he leans on it); no weight, swing or cog
## tooth passes through the level over its whole arc or turn; no weight knock
## on Dusk leaves him over a pit (played at every cell near an edge); every
## Spurwheel keeps to its own box (40 s rolling, away from altars, bells and
## the arena); each Dread's lair is off the main path (its floor as lava, the
## bot still gets past); each keeper nook only its quirk reaches (the others
## brute-forced, and the bot), and he gets back down; the first cogs, swings
## and the bridge weights over floors, not pits; stone every 14 tiles over a
## pit (the level checks shown to fail on a made-up level first); icicles
## hang <= 7 rows over a floor; per-screen caps (cogs <= 3, weights and
## swings <= 5); the star routes (sigil 3) tight and the
## only way; the golden routes: every cog, swing and weight crossing on the
## critical path is ridden in one, and no route stands still on ice within 5
## tiles of a pit's edge, and takes no hit (4-4's approach route is replayed
## here to the arena door, since its bell only comes with the Tinker); each
## feature's first-time bark plays once as it's taught, never mid-jump (and,
## in a small level, BARK_LEAD tiles before a feature no sign teaches, never
## in a mode); a choice card closing puts the carillon back on the tick.
##
##     godot --headless --path game --script res://tests/test_w4.gd

const LevelData := preload("res://scripts/level_data.gd")
const Rules := preload("res://tests/level_rules.gd")
const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
const Movers := preload("res://scripts/movers.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Route := preload("res://scripts/route.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const CLOCKWORK := "res://scripts/features/clockwork.gd"
const TILE := 32
const DT := 1.0 / 120.0
const IDS := ["4-1", "4-2", "4-3", "4-4"]
const WIDTHS := {"4-4": 170}     # (the regular levels' widths are their own since Build 2)
const THEMES := {"4-1": "clockface", "4-2": "gearworks", "4-3": "icebells", "4-4": "escapement"}
const AREAS := {"4-1": 18, "4-2": 19, "4-3": 21, "4-4": 22}
const ICE_STOP := 134.0          # px from a run (decisions.md, feel lab round 2)
const MAX_GAP := 85              # tiles between checkpoints (spec 3.1, World 4)
const APPROACH := "res://tests/routes/4-4-approach.json"
# Sigil 3's star route in each regular level: its tight landings (a lone
# ice block, a lone block, a one-tile frosted ledge; a cog's tooth is a
# mover) and a floor cell to start the bot from before them.
const STAR_ROUTES := {
	"4-1": {"route": [Vector2i(361, 7)], "from": Vector2i(345, 8), "what": "a run-up on the ice shelf to a lone ice block"},
	"4-2": {"route": [Vector2i(358, 5), Vector2i(362, 6)], "from": Vector2i(346, 12),
			"what": "a cog's top to a lone block, then a lone ice block"},
	"4-3": {"route": [Vector2i(356, 8), Vector2i(360, 7)], "from": Vector2i(345, 10),
			"what": "a swing's far end to a lone block, then a lone frosted ledge"},
}

var WorldScript: GDScript
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
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	if game != null:
		game.save_path = "user://test_w4_save.json"
		for suffix in [".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
		game.reset()
		game.new_hero("knight")
	if not ResourceLoader.exists(CLOCKWORK):
		print("  skipped: %s missing" % CLOCKWORK)
		print("test_w4: %d passed, %d failed" % [_passed, _failed])
		quit(0)
		return
	_test_knobs()
	await _test_ice()
	await _test_rime()
	await _test_icicles()
	await _test_belts()
	await _test_cogs()
	await _test_weights()
	await _test_swings()
	await _test_clock()
	await _test_boss_pivot()
	await _test_bark_lead()
	await _test_choice_sync()
	_test_level_checks()
	await _test_arc_check()
	var have := []
	for id in IDS:
		if FileAccess.file_exists("res://levels/%s.txt" % id):
			have.append(id)
	if have.is_empty():
		print("  skipped: the World 4 levels (res://levels/4-*.txt) missing")
	else:
		_test_headers(have)
		_test_rules(have)
		await _test_arcs(have)
		_test_ice_landings(have)
		await _test_weight_knocks(have)
		# (and every other level that places one: 4-S's MS_BELTS, 6-2's
		# belfry, 6-4's Carillon memory: the track B merge, wave 3's rule)
		await _test_wheels(have + ["4-S", "6-2", "6-4"].filter(func(v): return FileAccess.file_exists("res://levels/%s.txt" % v)))
		_test_lairs(have)
		await _test_nooks(have)
		_test_safe_first(have)
		_test_star_routes(have)
		_test_rime_required(have)
		await _test_routes(have)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_w4_save.json" + suffix))
	print("test_w4: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _level(lines: Array, header := "", id := "lab-w4", w := 40) -> RefCounted:
	## A level from rows (padded to w with air); rows past the given ones are
	## stone from row 13 down.
	var rows := []
	for y in 15:
		var r: String = lines[y] if y < lines.size() else ("#".repeat(w) if y >= 13 else "")
		rows.append(r.rpad(w, "."))
	var lv = LevelData.new()
	lv.id = id
	lv.parse("title: t\nsubtitle: t\narea: 18\n" + header + "---\n" + "\n".join(rows))
	return lv


func _world(lv: RefCounted, diff := "dusk") -> Node2D:
	game.reset()
	game.new_hero("knight")
	game.data["difficulty"] = diff
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = true
	w.paused = true
	root.add_child(w)
	return w


func _ticks(w: Node2D, n: int, pad := {}) -> void:
	for i in n:
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _done(w: Node2D) -> void:
	w.queue_free()
	await process_frame


func _cw(w: Node2D) -> Object:
	return w.features.module("clockwork")


func _stand(w: Node2D, cell: Vector2i) -> void:
	## Wick standing in cell, at rest.
	var pl: Node2D = w.player
	pl.reset_at(LevelData.cell_floor(cell))
	pl.velocity = Vector2.ZERO
	pl.on_floor = true
	pl.invuln = 0.0
	pl.hurt_time = 9.0   # (a fresh reset reads as just knocked: no steering for a beat)


# ---------------------------------------------------------------- the knobs

func _test_knobs() -> void:
	var K: Dictionary = (load(CLOCKWORK) as Script).get_script_constant_map()["DIFF_KNOBS"]
	var want := {"tick": [0.536, 0.536, 0.536], "cog_period": [6.432, 6.432, 6.432], "weight_period": [3.216, 3.216, 3.216],
			"swing_period": [3.216, 3.216, 3.216], "rime_k": [0.4, 0.8, 0.8], "rime_hold": [3.0, 1.5, 1.5],
			"rime_refreeze": [12.0, 10.0, 8.0], "icicle_tell": [0.45, 0.40, 0.35]}
	for k in want:
		var row: Dictionary = K.get(k, {})
		var got := [float(row.get("dusk", -1)), float(row.get("nightfall", -1)), float(row.get("witching", -1))]
		var ok := true
		for i in 3:
			ok = ok and absf(got[i] - float(want[k][i])) < 0.0005
		_check(ok, "clockwork knob %s is %s (Dusk / Nightfall / Witching), got %s" % [k, want[k], got])
	# The rhythm is the level, not the difficulty: 12 ticks a cog turn, 6 a swing.
	var tick := float(K["tick"]["dusk"])
	_check(absf(float(K["cog_period"]["dusk"]) - 12.0 * tick) < 0.001 and absf(float(K["weight_period"]["dusk"]) - 6.0 * tick) < 0.001
			and absf(float(K["swing_period"]["dusk"]) - 6.0 * tick) < 0.001, "a cog turns in 12 ticks, a weight and a swing in 6")
	_check(absf(float(LevelData.TICK) - tick) < 0.0005, "the tick with no header is the carillon's beat (%.3f s)" % LevelData.TICK)


# ---------------------------------------------------------------- ice

func _test_ice() -> void:
	# The number from player.gd's own constants, then played out.
	var decel: float = PlayerScript.GROUND_DECEL * PlayerScript.ICE_DECEL
	var analytic: float = PlayerScript.RUN_SPEED * PlayerScript.RUN_SPEED / (2.0 * decel)
	_check(absf(analytic - ICE_STOP) <= 3.0, "ice's grip stops a run in %.0f px (the owner's 134)" % analytic)
	var lv := _level(["", "", "", "", "", "", "", "", "", "", "", "", "",
			"#####" + "I".repeat(30) + "#####"], "", "lab-w4", 40)
	var w := _world(lv)
	await process_frame
	var pl: Node2D = w.player
	_stand(w, Vector2i(2, 12))
	_ticks(w, 10)
	_check(_cw(w).slick_at(Vector2(10 * TILE + 16, 13 * TILE + 4)) and not _cw(w).slick_at(Vector2(2 * TILE + 16, 13 * TILE + 4)),
			"slick_at: ice is slick, stone isn't")
	# Run to full speed on stone, onto the ice, let go at x 9.
	var released := -1.0
	for i in 600:
		var go: bool = pl.position.x < 9 * TILE
		if not go and released < 0.0:
			released = pl.position.x
		_ticks(w, 1, {"right": go})
		if released >= 0.0 and absf(pl.velocity.x) < 0.5:
			break
	var slid: float = pl.position.x - released
	_check(absf(slid - ICE_STOP) <= 6.0, "a run let go on ice slides %.0f px (134 +- 6)" % slid)
	_check(bool(pl.on_ice), "and he stood on ice (player.on_ice)")
	# Knockback on ice is halved (player.gd ICE_KNOCK).
	pl.invuln = 0.0
	pl.velocity = Vector2.ZERO
	w.hurt_player(1.0, pl.position.x - 20.0, "hit", null, {})
	var kb_ice: float = absf(pl.velocity.x)
	_check(kb_ice > 0.0 and kb_ice <= PlayerScript.KNOCKBACK.x * 0.5 + 1.0, "knockback on ice is halved (%.0f px/s)" % kb_ice)
	await _done(w)


# ---------------------------------------------------------------- rime

func _rime_level() -> RefCounted:
	return _level(["", "", "", "", "", "", "", "", "", "",
			"..........Z.............",
			"..........Z.............",
			"..........Z.............",
			"########################"], "", "lab-w4", 30)


func _lean(w: Node2D, seconds: float) -> void:
	## Wick pressed against the rime door (standing left of it).
	var pl: Node2D = w.player
	for i in int(round(seconds / DT)):
		pl.invuln = 1.0
		_ticks(w, 1, {"right": true})


func _melt_time(w: Node2D) -> float:
	## Seconds of leaning (pressed against it from the first tick) until the
	## door (x 10) is air.
	var pl: Node2D = w.player
	pl.position.x = 10 * TILE - pl.size.x * 0.5 - 1.0
	var t := 0.0
	while w.level.tile(10, 11) == LevelData.RIME and t < 3.0:
		_lean(w, DT)
		t += DT
	return t


func _test_rime() -> void:
	for diff in ["dusk", "nightfall"]:
		var w := _world(_rime_level(), diff)
		await process_frame
		var cw = _cw(w)
		var pl: Node2D = w.player
		var k := 0.4 if diff == "dusk" else 0.8
		_check(absf(cw.knob("rime_k") - k) < 0.001, "%s: rime_k %.1f" % [diff, k])
		# Full flame: 0.4 s.
		_stand(w, Vector2i(9, 12))
		pl.hp = pl.max_hp
		var t_full := _melt_time(w)
		_check(absf(t_full - 0.4) <= 0.02, "%s: rime melts in 0.4 s at full flame (%.3f)" % [diff, t_full])
		# Near empty: 0.4 + k (1 - f).
		for i in patches_of(cw).size():
			cw._freeze(i)
		_stand(w, Vector2i(9, 12))
		pl.hp = pl.max_hp * 0.01
		var t_low := _melt_time(w)
		var want := 0.4 + k * 0.99
		_check(absf(t_low - want) <= 0.02, "%s: and in %.2f s near empty (%.3f)" % [diff, want, t_low])
		pl.hp = pl.max_hp
		await _done(w)
	# The hold: progress stays rime_hold s between touches, then drains.
	var w2 := _world(_rime_level())
	await process_frame
	var cw2 = _cw(w2)
	var pl2: Node2D = w2.player
	_check(absf(cw2.knob("rime_hold") - 3.0) < 0.001, "Dusk: the melt holds 3 s between touches")
	_stand(w2, Vector2i(9, 12))
	pl2.position.x = 10 * TILE - pl2.size.x * 0.5 - 1.0
	_lean(w2, 0.3)
	_stand(w2, Vector2i(5, 12))
	_ticks(w2, int(2.5 / DT))
	_check(float(cw2.patches[0]["p"]) > 0.29, "leaning 0.3 s, then 2.5 s away: the progress held (%.2f)" % float(cw2.patches[0]["p"]))
	_stand(w2, Vector2i(9, 12))
	pl2.position.x = 10 * TILE - pl2.size.x * 0.5 - 1.0
	_lean(w2, 0.11)
	_check(w2.level.tile(10, 11) == LevelData.AIR, "and 0.1 s more melts it (0.4 s in all)")
	for i in cw2.patches.size():
		cw2._freeze(i)
	_stand(w2, Vector2i(9, 12))
	pl2.position.x = 10 * TILE - pl2.size.x * 0.5 - 1.0
	_lean(w2, 0.3)
	_stand(w2, Vector2i(5, 12))
	_ticks(w2, int(4.5 / DT))
	_check(float(cw2.patches[0]["p"]) < 0.01, "but 4.5 s away drains it (%.2f)" % float(cw2.patches[0]["p"]))
	await _done(w2)
	# Refreezing: air for 12 s, then a 1.0 s tell that starts on a beat;
	# never into a body.
	var w3 := _world(_rime_level())
	await process_frame
	var cw3 = _cw(w3)
	var pl3: Node2D = w3.player
	_stand(w3, Vector2i(9, 12))
	_melt_time(w3)
	var melted_at: float = w3.ftime
	_stand(w3, Vector2i(3, 12))
	var tell_at := -1.0
	var solid_at := -1.0
	for i in int(16.0 / DT):
		_ticks(w3, 1)
		if tell_at < 0.0 and cw3.patches[0]["state"] == "tell":
			tell_at = w3.ftime
		if solid_at < 0.0 and w3.level.tile(10, 11) == LevelData.RIME:
			solid_at = w3.ftime
			break
	var tick: float = cw3.tick
	var on_beat := fmod(tell_at + 0.0005, tick) < DT + 0.001
	_check(tell_at - melted_at >= 12.0 - 0.001 and tell_at - melted_at < 12.0 + tick + DT and on_beat,
			"melted rime is air for 12 s, then its tell starts on a beat (%.2f s after, phase %.3f)" % [tell_at - melted_at, fmod(tell_at, tick)])
	_check(absf(solid_at - tell_at - 1.0) <= DT + 0.001, "the refreeze tell lasts 1.0 s (%.3f)" % (solid_at - tell_at))
	# Melt it, stand in it, wait past the refreeze: it waits for him.
	_stand(w3, Vector2i(9, 12))
	_melt_time(w3)
	_stand(w3, Vector2i(10, 12))
	for i in int(15.0 / DT):
		pl3.invuln = 1.0
		_ticks(w3, 1)
	_check(w3.level.tile(10, 12) == LevelData.AIR and w3.level.tile(10, 11) == LevelData.AIR, "rime never refreezes into a body standing in it")
	_stand(w3, Vector2i(4, 12))
	_ticks(w3, int(1.5 / DT))
	_check(w3.level.tile(10, 11) == LevelData.RIME, "and closes once he's out")
	await _done(w3)
	# Fire melts it in 0.2 s: a fire patch, and a lit lamp within 2 tiles.
	var w4 := _world(_rime_level())
	await process_frame
	_stand(w4, Vector2i(3, 12))
	w4.add_hazard({"kind": "fire", "motion": "still", "owner": "player", "rect": Rect2(9 * TILE + 20, 12 * TILE + 16, 12, 16), "life": 1.0})
	var tf := 0.0
	while w4.level.tile(10, 11) == LevelData.RIME and tf < 1.0:
		_ticks(w4, 1)
		tf += DT
	_check(tf <= 0.2 + 2.0 * DT, "a fire patch melts rime in 0.2 s (%.3f)" % tf)
	await _done(w4)
	var lamp := _level(["", "", "", "", "", "", "", "", "", "",
			"..........Z.............",
			"..........Z.............",
			"........L.Z.............",
			"########################"], "", "lab-w4", 30)
	var w5 := _world(lamp)
	await process_frame
	_stand(w5, Vector2i(3, 12))
	_ticks(w5, 5)
	_check(w5.level.tile(10, 11) == LevelData.RIME, "rime by an unlit lamp stays")
	w5.features.light(w5.features.lanterns[0], true)
	var tl := 0.0
	while w5.level.tile(10, 11) == LevelData.RIME and tl < 1.0:
		_ticks(w5, 1)
		tl += DT
	_check(tl <= 0.2 + 2.0 * DT, "a lamp lit within 2 tiles melts it in 0.2 s (%.3f)" % tl)
	await _done(w5)


func patches_of(cw) -> Array:
	return cw.patches


# ---------------------------------------------------------------- icicles

func _test_icicles() -> void:
	for diff in ["dusk", "nightfall", "witching"]:
		var lv := _level(["#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40),
				".............V..........................",
				"", "", "", "", "", ""], "", "lab-w4", 40)
		var w := _world(lv, diff)
		await process_frame
		var cw = _cw(w)
		var pl: Node2D = w.player
		var tell: float = {"dusk": 0.45, "nightfall": 0.40, "witching": 0.35}[diff]
		_check(absf(cw.knob("icicle_tell") - tell) < 0.001, "%s: the icicle tell is %.2f s" % [diff, tell])
		_stand(w, Vector2i(5, 12))
		_ticks(w, 10)
		_check(cw.icicles[0]["state"] == "hang", "%s: an icicle hangs until he passes under" % diff)
		_stand(w, Vector2i(13, 12))
		var hp0: float = pl.hp
		var told := 0.0
		var fell_at := -1.0
		for i in int(2.0 / DT):
			_ticks(w, 1)
			if cw.icicles[0]["state"] == "tell":
				told += DT
			elif cw.icicles[0]["state"] == "fall" and fell_at < 0.0:
				fell_at = w.ftime
			if pl.hp < hp0:
				break
		_check(absf(told - tell) <= DT + 0.001, "%s: it cracks and shakes for %.2f s before it drops (%.3f)" % [diff, tell, told])
		_check(pl.hp < hp0, "%s: and it hurts him if he stays under it" % diff)
		_check(cw.icicles[0]["state"] == "gone", "%s: it shatters on him" % diff)
		pl.hp = pl.max_hp
		_stand(w, Vector2i(3, 12))
		_ticks(w, int(6.0 / DT) + 70)
		_check(cw.icicles[0]["state"] == "hang", "%s: and grows back in 6 s" % diff)
		await _done(w)
	# A swing knocks it down early, and a knocked icicle hurts nobody.
	var lv2 := _level(["#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40),
			"#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40),
			".............V..........................", "", ""], "", "lab-w4", 40)
	var w2 := _world(lv2)
	await process_frame
	var cw2 = _cw(w2)
	cw2.strike(Rect2(13 * TILE, 10 * TILE, 32, 32), 1)
	_check(cw2.icicles[0]["state"] == "fall" and bool(cw2.icicles[0]["safe"]), "a swing knocks a hanging icicle down")
	_stand(w2, Vector2i(13, 12))
	var hp2: float = w2.player.hp
	_ticks(w2, 60)
	_check(w2.player.hp >= hp2 and cw2.icicles[0]["state"] == "gone", "and a knocked icicle falls harmlessly")
	await _done(w2)


# ---------------------------------------------------------------- belts

func _test_belts() -> void:
	var lv := _level(["", "", "", "", "", "", "", "", "", "", "", "", "",
			"#####" + ">".repeat(20) + "###############"], "", "lab-w4", 40)
	var w := _world(lv)
	await process_frame
	var pl: Node2D = w.player
	_stand(w, Vector2i(8, 12))
	_ticks(w, 12)
	var x0: float = pl.position.x
	_ticks(w, 120)
	_check(absf((pl.position.x - x0) - 80.0) <= 2.0, "a belt carries him 80 px/s (%.1f in 1 s)" % (pl.position.x - x0))
	var cw = _cw(w)
	cw.reverse_belts(5, 24)
	_check(w.belt_dir(Vector2i(10, 13), 1) == 1, "a reversal waits for its tell")
	_ticks(w, int(0.6 / DT) + 2)
	_check(w.belt_dir(Vector2i(10, 13), 1) == -1, "and flips the belts after 0.6 s")
	var x1: float = pl.position.x
	_ticks(w, 60)
	_check(pl.position.x < x1 - 30.0, "then it carries him the other way")
	cw.on_boss_reset()
	_check(w.belt_dir(Vector2i(10, 13), 1) == 1, "a boss retry puts the belts back")
	await _done(w)


# ---------------------------------------------------------------- cogs

func _test_cogs() -> void:
	var lv := _level(["", "", "", "", "", "", "",
			"..........O.......Q.....................", "", "", "", "", "",
			"#####....................###############"], "", "lab-w4", 40)
	var w := _world(lv)
	await process_frame
	var cw = _cw(w)
	_check(cw.cogs.size() == 2 and int(cw.cogs[0]["dir"]) == 1 and int(cw.cogs[1]["dir"]) == -1, "O turns clockwise, Q the other way")
	var tooth = cw.cogs[0]["teeth"][0]
	var r0: Rect2 = tooth.rect()
	var hub: Vector2 = cw.cogs[0]["hub"]
	_check(absf(r0.get_center().distance_to(hub) - 96.0) < 0.5 and r0.size == Vector2(64, 12), "a tooth is a 2-tile ledge on a 96 px ring")
	# A rider at the top, carried round a whole turn.
	var pl: Node2D = w.player
	pl.reset_at(Vector2(r0.get_center().x, r0.position.y))
	pl.velocity = Vector2.ZERO
	var seen_side := false
	for i in roundi(cw.knob("cog_period") / DT):
		pl.invuln = 1.0
		_ticks(w, 1)
		if pl.riding == tooth and (pl.position.x - hub.x) > 90.0:
			seen_side = true
	var r1: Rect2 = tooth.rect()
	_check(r1.position.distance_to(r0.position) < 1.5, "a tooth is back where it started after 6.43 s (%.2f px off)" % r1.position.distance_to(r0.position))
	_check(seen_side and pl.riding == tooth and absf(pl.position.x - r1.get_center().x) < 36.0, "and carries its rider the whole way round")
	# Clockwise: the top moves right, the left side rises.
	var right_top: Array = []
	for c in cw.cogs:
		var t = c["teeth"][0]
		right_top.append(t.delta.x)
	_check(float(right_top[0]) > 0.0 and float(right_top[1]) < 0.0, "at the top a clockwise tooth moves right, a counter-clockwise one left")
	await _done(w)


# ---------------------------------------------------------------- weights

func _weight_level(extra_rows := {}) -> RefCounted:
	var rows := ["#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40),
			".........Y.........Y....................", "", "", "", "", "", "#".repeat(40), "#".repeat(40)]
	for y in extra_rows:
		rows[int(y)] = extra_rows[y]
	return _level(rows, "", "lab-w4", 40)


func _test_weights() -> void:
	var w := _world(_weight_level())
	await process_frame
	var cw = _cw(w)
	_check(cw.weights.size() == 2, "a Y is a weight")
	var a: Dictionary = cw.weights[0]
	var b: Dictionary = cw.weights[1]
	_check(absf(float(a["rod"]) - 172.0) < 0.5, "its rod runs to 20 px over the floor (172 px here)")
	_check(absf(float(a["phase"]) - float(b["phase"])) == 0.5, "weights in a row swing half a swing apart")
	# Its period and amplitude.
	var amax := 0.0
	var a0: float = cw.weight_angle(a)
	for i in roundi(cw.knob("weight_period") / DT):
		_ticks(w, 1)
		amax = maxf(amax, absf(cw.weight_angle(a)))
	_check(absf(amax - deg_to_rad(50.0)) < 0.01 and absf(cw.weight_angle(a) - a0) < 0.02, "it swings +-50 deg and is back in 3.21 s (6 ticks)")
	await _done(w)
	# At the bottom it hurts a standing Waxby; at the ends it clears his head.
	var w2 := _world(_weight_level())
	await process_frame
	var cw2 = _cw(w2)
	var pl: Node2D = w2.player
	var anchor: Vector2 = cw2.weights[0]["anchor"]
	var rod: float = cw2.weights[0]["rod"]
	var end_bob := anchor + Vector2(sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0))) * rod
	_stand(w2, Vector2i(floori(end_bob.x / TILE), 12))
	pl.position.x = end_bob.x
	var r: Rect2 = pl.rect()
	var near := Vector2(clampf(end_bob.x, r.position.x, r.end.x), clampf(end_bob.y, r.position.y, r.end.y))
	_check(near.distance_to(end_bob) > cw2.WEIGHT_R + 8.0, "at the end of its swing the bob clears a standing Waxby's head (%.0f px)" % (near.distance_to(end_bob) - cw2.WEIGHT_R))
	_stand(w2, Vector2i(9, 12))
	var hp0: float = pl.hp
	var hit := false
	for i in int(3.3 / DT):
		_ticks(w2, 1)
		if pl.hp < hp0:
			hit = true
			break
	_check(hit, "at the bottom it hits him")
	await _done(w2)
	# Dusk: never toward a pit edge within 3 tiles (the other way); Nightfall
	# knocks along the swing, pit or no pit.
	for diff in ["dusk", "nightfall"]:
		var lv := _weight_level({13: "##########.....##########################", 14: "##########.....##########################"})
		var w3 := _world(lv, diff)
		await process_frame
		var cw3 = _cw(w3)
		var pl3: Node2D = w3.player
		var toward := 0
		var away := 0
		for start in range(0, 40):
			# Stand just left of the pit (x 8-9) and let the weight come.
			_stand(w3, Vector2i(8, 12))
			pl3.hp = pl3.max_hp
			w3.ftime = start * 0.08
			var hp1: float = pl3.hp
			for i in int(1.8 / DT):
				_ticks(w3, 1)
				if pl3.hp < hp1:
					if pl3.velocity.x > 1.0:
						toward += 1
					elif pl3.velocity.x < -1.0:
						away += 1
					break
		if diff == "dusk":
			_check(toward == 0 and away > 0, "Dusk: a weight never knocks him toward the pit edge beside him (%d toward, %d away)" % [toward, away])
		else:
			_check(toward > 0, "Nightfall: it knocks along its swing, pit or no pit (%d toward)" % toward)
		await _done(w3)


# ---------------------------------------------------------------- swings

func _test_swings() -> void:
	var lv := _level(["#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40),
			"", "", "", "", "",
			"........TTT.......TTT...................", "", "", ""], "", "lab-w4", 40)
	var w := _world(lv)
	await process_frame
	var cw = _cw(w)
	_check(cw.swings.size() == 2 and int(cw.swings[0].length) == 3, "a run of T is one swing ledge")
	var m = cw.swings[0]
	var n = cw.swings[1]
	_check(absf(m.rod - 160.0) < 0.5 and m.rect().position.is_equal_approx(Vector2(8 * TILE, 10 * TILE)), "it rests where it's drawn, on a rod from the solid 5 rows up")
	_check(absf(float(m.phase) - float(n.phase)) == 0.5, "swings in a row swing half a swing apart")
	var amax := 0.0
	var ymin := INF
	var p0: Vector2 = m.rect().position
	for i in roundi(cw.knob("swing_period") / DT):
		_ticks(w, 1)
		amax = maxf(amax, absf(m.angle))
		ymin = minf(ymin, m.rect().position.y)
	_check(absf(amax - deg_to_rad(40.0)) < 0.01, "it swings +-40 deg (%.1f)" % rad_to_deg(amax))
	_check(m.rect().position.distance_to(p0) < 1.0, "and is back in 3.21 s")
	_check(absf((10 * TILE - ymin) - 160.0 * (1.0 - cos(deg_to_rad(40.0)))) < 1.0, "staying level, its far end %.0f px higher" % (10 * TILE - ymin))
	await _done(w)


# ---------------------------------------------------------------- the clock

func _test_clock() -> void:
	# No tick: header (a Descent room): the carillon's beat. stop_time
	# freezes the cogs and weights.
	var lv := _level(["#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40),
			"..........O...........Y.................", "", "", "", "", ""], "", "lab-w4", 40)
	var w := _world(lv)
	await process_frame
	var cw = _cw(w)
	_check(absf(cw.tick - 0.536) < 0.0005 and absf(float(lv.tick) - 0.536) < 0.0005, "with no tick: header the tick is 0.536 s")
	_ticks(w, 30)
	var tooth: Rect2 = cw.cogs[0]["teeth"][0].rect()
	var bob: Vector2 = cw.weights[0]["bob"]
	var f0: float = w.ftime
	w.stop_time(1.0)
	_ticks(w, 60)
	_check(w.ftime == f0 and cw.cogs[0]["teeth"][0].rect() == tooth and cw.weights[0]["bob"] == bob, "stop_time freezes the tick, the cogs and the weights")
	_ticks(w, 90)
	_check(w.ftime > f0 and cw.cogs[0]["teeth"][0].rect() != tooth, "and they go on after it")
	_check(cw.beat() == floori(w.ftime / 0.536), "beat() counts the ticks of ftime")
	await _done(w)
	# The same on every difficulty.
	for diff in ["nightfall", "witching"]:
		var w2 := _world(_level(["", "", "", "", "", "", "", "..........O.............", "", "", "", "", ""], "", "lab-w4", 30), diff)
		await process_frame
		_check(absf(_cw(w2).knob("cog_period") - 6.432) < 0.001 and absf(_cw(w2).tick - 0.536) < 0.001, "%s keeps the same clock" % diff)
		await _done(w2)


func _test_boss_pivot() -> void:
	## A Y inside a boss arena is the boss's own (the Tinker's pendulum): no
	## weight, listed in boss_pivots.
	var rows := ["#".repeat(40), "#".repeat(40),
			"##..................................##..",
			"##..................................##..",
			"##.............=====................##..",
			"##..............Y...................##..",
			"##..................................##..",
			"##..................................##..",
			"##..................................##..",
			"##..................................##..",
			"....................................##..",
			"....................................##..",
			"..........X.........................##..",
			"########################################"]
	var lv := _level(rows, "boss: tinker\n", "lab-w4", 40)
	var w := _world(lv)
	await process_frame
	var cw = _cw(w)
	_check(cw.weights.is_empty() and cw.boss_pivots.size() == 1, "a Y in a boss arena is the boss's own pivot, not a weight")
	await _done(w)


func _test_bark_lead() -> void:
	## A feature's first-time bark with no teaching sign before it is said
	## BARK_LEAD (6) tiles before its first cell, on stone; with a sign within
	## SIGN_BEFORE, at the sign as before. Never in a mode (a mode's rooms
	## teach nothing, as deep.gd's). Two due on one landing: the one whose
	## spot he passed last first.
	var CW: Dictionary = (load(CLOCKWORK) as Script).get_script_constant_map()
	var lead := int(CW.get("BARK_LEAD", -1))
	_check(lead == 6, "BARK_LEAD is 6 tiles (%d)" % lead)
	var ice_row := "#".repeat(30) + "I".repeat(10) + "#".repeat(20)
	for with_sign in [false, true]:
		var lines := []
		for y in 13:
			lines.append("")
		if with_sign:
			lines[12] = ".".repeat(20) + "@"
		lines.append(ice_row)
		var lv := _level(lines, "hints: Ice\n" if with_sign else "", "lab-w4", 60)
		var w := _world(lv)
		await process_frame
		var hud := _stub_hud()
		hud.world = w
		w.hud = hud
		var spot := 20 if with_sign else 30 - lead
		var plan: Dictionary = _cw(w)._bark_at.get("ice", {})
		_check(int(plan.get("first", -1)) == 30 and int(plan.get("sign", -1)) == spot,
				"%s: first_ice is planned at x %d (%s)" % ["a sign at 20" if with_sign else "no sign", spot, plan])
		_stand(w, Vector2i(10, 12))
		var said_x := -1.0
		var on_floor := false
		for i in int(4.0 / DT):
			_ticks(w, 1, {"right": true})
			for b in hud.said:
				if b[0] == "first_ice" and said_x < 0.0:
					said_x = float(b[2])
					on_floor = bool(b[1])
			if w.player.position.x > 32 * TILE:
				break
		var n: int = hud.said.filter(func(b): return b[0] == "first_ice").size()
		_check(n == 1 and on_floor and absf(said_x - (spot + 0.5) * TILE) < 44.0,
				"%s: first_ice said once, on the floor, at x %d (%d times, at %.0f px)" % ["a sign at 20" if with_sign else "no sign", spot, n, said_x])
		await _done(w)
	# In a mode: nothing, even standing on the spot; out of it, the bark.
	var lines2 := []
	for y in 13:
		lines2.append("")
	lines2.append(ice_row)
	var w2 := _world(_level(lines2, "", "lab-w4", 60))
	await process_frame
	var hud2 := _stub_hud()
	hud2.world = w2
	w2.hud = hud2
	_stand(w2, Vector2i(30 - lead, 12))
	w2.mode = RefCounted.new()
	_cw(w2)._step_barks(w2.player)
	_check(hud2.said.is_empty(), "in a mode no first-time bark is said (%s)" % [hud2.said])
	w2.mode = null
	_cw(w2)._step_barks(w2.player)
	_check(hud2.said.size() == 1 and hud2.said[0][0] == "first_ice", "out of one, on the same spot, it is (%s)" % [hud2.said])
	await _done(w2)
	# Two due on one landing (both spots passed in the air): the one just
	# ahead of him (its spot passed last) first, the other at the next gap.
	var lines3 := []
	for y in 13:
		lines3.append("")
	lines3.append("#".repeat(12) + "I".repeat(8) + "#".repeat(20) + ">".repeat(6) + "#".repeat(14))
	var w3 := _world(_level(lines3, "", "lab-w4", 60))
	await process_frame
	var hud3 := _stub_hud()
	hud3.world = w3
	w3.hud = hud3
	_stand(w3, Vector2i(36, 12))
	var cw3 = _cw(w3)
	_check(int(cw3._bark_at.get("ice", {}).get("sign", -1)) == 12 - lead and int(cw3._bark_at.get("belt", {}).get("sign", -1)) == 40 - lead,
			"(ice planned at %d, the belt at %d)" % [12 - lead, 40 - lead])
	cw3._step_barks(w3.player)
	cw3._bark_t = -100.0
	cw3._step_barks(w3.player)
	var keys: Array = hud3.said.map(func(b): return b[0])
	_check(keys == ["first_belt", "first_ice"], "both due at once: the belt just ahead first, then the ice behind him (%s)" % [keys])
	await _done(w3)


func _test_choice_sync() -> void:
	## A choice card (the Altar Rites, a boss's boon) holds the World, so the
	## feature clock stands still under it while the carillon plays on: as
	## it closes, the tick-locked track is put back on the clock
	## (sync_music: Sfx.seek_music(ftime)), as the pause menu's close does.
	var sfx = root.get_node_or_null("Sfx")
	if sfx == null or not FileAccess.file_exists("res://levels/4-1.txt"):
		print("  skipped: the choice card's music sync (no Sfx, or no 4-1)")
		return
	var w := _world(_load("4-1"))
	await process_frame
	w.headless = false
	var kept: String = sfx._music_track
	sfx._music_track = "carillon"
	w.ftime = 12.345
	sfx._anchor = []
	_check(w.offer_choice([{"name": "A"}, {"name": "B"}], {"heading": "t", "later": "Later"}) and w.paused, "a choice card holds the World")
	w.choice.choose(-1)
	var at: Array = sfx._anchor
	_check(not w.paused and at.size() == 3 and str(at[0]) == "carillon" and is_equal_approx(float(at[1]), 12.345),
			"as it closes the carillon is put back on the feature clock: seek_music(ftime) (%s)" % [at])
	sfx._music_track = kept
	sfx._anchor = []
	w.paused = true
	w.headless = true
	await _done(w)


# ---------------------------------------------------------------- the levels

func _load(id: String) -> RefCounted:
	return LevelData.load_file("res://levels/%s.txt" % id)


func _test_headers(ids: Array) -> void:
	var Story = load("res://scripts/story.gd")
	for id in ids:
		var lv := _load(id)
		_check(lv.errors.is_empty(), "%s parses: %s" % [id, lv.errors])
		_check(lv.width == int(WIDTHS.get(id, lv.width)) and lv.height == 15, "%s is %d x 15 (%d x %d)" % [id, WIDTHS.get(id, lv.width), lv.width, lv.height])
		_check(lv.theme == THEMES[id] and lv.music == "carillon" and lv.area == int(AREAS[id]) and absf(lv.tick - 0.536) < 0.0001,
				"%s: theme %s, carillon, area %d, tick 0.536" % [id, THEMES[id], AREAS[id]])
		_check(lv.world == 4 and str(lv.story.get("start", "")) == "beat_%s" % id.replace("-", "_"), "%s opens with beat_%s" % [id, id.replace("-", "_")])
		_check(lv.count("sigil") == 3, "%s has three sigils" % id)
		if id == "4-4":
			_check(lv.boss == "tinker" and lv.boss_music == "tinker" and str(lv.story.get("boss", "")) == "boss_4_before"
					and str(lv.story.get("end", "")) == "boss_4_after", "4-4: the Tinker, his music and scenes")
		else:
			_check(not lv.dread.is_empty(), "%s has its Dread" % id)
		if id == "4-2":
			# The bell, its loft and the vent come with 4-S (w4.py SECRET_4S).
			if FileAccess.file_exists("res://levels/4-S.txt"):
				_check(lv.secret == "4-S" and lv.count("silver_bell") == 1, "4-2's silver bell opens 4-S")
			else:
				var vent := 0
				for x in lv.width:
					for y in 4:
						if lv.tile(x, y) == LevelData.FALSE_STONE:
							vent += 1
				_check(lv.secret == "" and lv.count("silver_bell") == 0 and vent == 0,
						"4-2 without 4-S: no silver bell, no secret: header, no vent to a loft (%d, '%s', %d)" % [lv.count("silver_bell"), lv.secret, vent])
		# Its inscription (one at most since the sign cut; 4-2 has none) on a sign.
		var ins: Array = Story.INSCRIPTIONS.get(id, [])
		var at := []
		for t in ins:
			var x := -1
			for e in lv.entities:
				if e["kind"] == "sign" and str(e["text"]) == str(t):
					x = int(e["cell"].x)
			at.append(x)
		_check(Story.INSCRIPTIONS.has(id) and ins.size() <= 1 and not at.has(-1), "%s: its inscription on a sign (%s)" % [id, at])


func _test_rules(ids: Array) -> void:
	var regular := []
	for id in ids:
		var lv := _load(id)
		var boss: bool = lv.boss != ""
		# Checkpoints: start, altars, bell (or the arena door).
		var marks := [lv.start.x]
		var altars := []
		for e in lv.entities:
			if e["kind"] == "altar":
				altars.append(int(e["cell"].x))
			elif e["kind"] == "bell" or e["kind"] == "boss":
				marks.append(int(e["cell"].x))
		altars.sort()
		marks.append_array(altars)
		marks.sort()
		var worst := 0
		for i in range(1, marks.size()):
			worst = maxi(worst, int(marks[i]) - int(marks[i - 1]))
		if boss:
			_check(altars.size() == 2, "%s has 2 altars (%d)" % [id, altars.size()])
		else:
			var cp := Rules.checkpoint_problems(lv, MAX_GAP)
			_check(cp.is_empty(), "%s: 3-5 altars, an altar by every sealed door %s" % [id, cp])
		_check(worst <= MAX_GAP, "%s: checkpoints at most %d tiles apart (%s)" % [id, MAX_GAP, marks])
		if boss:
			var bx := 0
			for e in lv.entities:
				if e["kind"] == "boss":
					bx = int(e["cell"].x)
			var a := Arena.find(lv, LevelData.cell_floor(Vector2i(bx, 12)))
			_check(int(a["left"]) / TILE - int(altars[altars.size() - 1]) <= 8, "%s: an altar at the arena door" % id)
		# The cast and the threat (the Dread aside): what the level's roster:
		# and threat: headers declare (Build 2), checked below for 4-1 to 4-3.
		for e in lv.entities:
			var k: String = e["kind"]
			_check(k != "gutterwing" and k != "nest", "%s: no Gutterwings in World 4 (%s at %s)" % [id, k, e["cell"]])
		if not boss:
			regular.append(lv)
			var rp := Rules.roster_problems(lv)
			_check(not Rules.roster_of(lv).is_empty() and rp.is_empty(), "%s holds the cast its roster: declares %s" % [id, rp])
			_check(Rules.declared_threat(lv) > 0.0, "%s declares its threat (%.1f per 100 tiles)" % [id, Rules.threat_of(lv)])
		# Icicles hang from a ceiling at most 7 rows over a floor.
		for e in lv.of_kind("icicle"):
			var c: Vector2i = e["cell"]
			var fy := -1
			for y in range(c.y + 1, lv.height):
				if LevelData.is_floor(lv.tile(c.x, y)):
					fy = y
					break
			_check(LevelData.is_solid(lv.tile(c.x, c.y - 1)) and fy > 0 and fy - c.y <= 7, "%s: the icicle at %s hangs within 7 rows of a floor" % [id, c])
		# Per 27-tile screen: cogs <= 3, weights and swings <= 5.
		var cmax := 0
		var wmax := 0
		for x0 in range(0, lv.width - 26):
			var nc := 0
			var nw := 0
			for e in lv.entities:
				var ex: int = int(e["cell"].x)
				if ex < x0 or ex >= x0 + 27:
					continue
				if e["kind"] == "cog":
					nc += 1
				elif e["kind"] == "weight" or e["kind"] == "swing":
					nw += 1
			cmax = maxi(cmax, nc)
			wmax = maxi(wmax, nw)
		_check(cmax <= 3 and wmax <= 5, "%s: per screen at most 3 cogs (%d) and 5 weights and swings (%d)" % [id, cmax, wmax])
		# Stone every 14 tiles over a pit: between the firm tops either side of
		# every pit (a column open to the level's bottom), 14 tiles or less.
		var bad := _stone_gaps(lv)
		_check(bad.is_empty(), "%s: stone every 14 tiles over its pits %s" % [id, bad])
	if not regular.is_empty():
		# The world's rules across its regular levels (tests/level_rules.gd
		# world_problems): each threat as declared, ramping (flat today, +1 a
		# step once re-cut); once re-cut, roles on every level, no two with the
		# same landmarks or altars, fodder falling, the X-3 mixing, no crowding.
		var tp := Rules.world_problems(regular)
		_check(tp.is_empty(), "4-1 to 4-3: the world's rules (threat, ramp, roles, variety) %s" % [tp])


func _pit_col(lv: RefCounted, x: int) -> bool:
	## A pit: the column is open at the level's bottom (no floor in its last
	## two rows), so a fall there is lost. The roof rows never count.
	return not LevelData.is_floor(lv.tile(x, lv.height - 1)) and not LevelData.is_floor(lv.tile(x, lv.height - 2))


func _firm_col(lv: RefCounted, x: int) -> bool:
	## A top last_safe records (player.gd _track_safe), from the walking rows
	## (2 on) down: a safe floor with no solid over it, not ice's outer tile
	## at an edge, and no spikes or lava over it. Belts, frosted ledges, rime,
	## false stone and thin ice never count.
	for y in range(2, lv.height):
		var t: int = lv.tile(x, y)
		if not LevelData.is_safe(t) or LevelData.is_solid(lv.tile(x, y - 1)):
			continue
		if t == LevelData.ICE and not (LevelData.is_floor(lv.tile(x - 1, y)) and LevelData.is_floor(lv.tile(x + 1, y))):
			continue
		var spiked := false
		for dx in [-1, 0, 1]:
			var u: int = lv.tile(x + dx, y - 1)
			if u == LevelData.SPIKES_UP or u == LevelData.LAVA:
				spiked = true
		if not spiked:
			return true
	return false


func _stone_gaps(lv: RefCounted) -> Array:
	## Spec 0.3 rule 4: across every pit, the firm tops either side are 14
	## tiles apart or less. The spans that break it, as "from-to".
	var last_firm := -1
	var over_pit := false
	var bad := []
	for x in lv.width:
		if _pit_col(lv, x):
			over_pit = true
		if _firm_col(lv, x):
			if over_pit and last_firm >= 0 and x - last_firm > 14:
				bad.append("%d-%d" % [last_firm, x])
			over_pit = false
			last_firm = x
	return bad


func _test_level_checks() -> void:
	## The level checks can fail: a belt bridge 20 tiles over a pit breaks
	## the stone rule, a stone pillar in its middle mends it; _floor_under
	## tells a pit from a sunken floor under a stone roof.
	var roof := "#".repeat(40)
	var rows := [roof, roof, "", "", "", "", "", "", "",
			"#####>>>>>>>>>>>>>>>>>>>>###############",
			"#####....................###############", "", "",
			"#####....................###############", "#####....................###############"]
	var lv := _level(rows, "", "lab-w4", 40)
	_check(_pit_col(lv, 10) and not _pit_col(lv, 2) and not _firm_col(lv, 10) and _firm_col(lv, 4),
			"the level checks: a column open at the bottom is a pit, a belt is no stone, under a roof too")
	_check(_stone_gaps(lv) == ["4-25"], "the stone rule catches a 21-tile belt bridge over a pit (%s)" % [_stone_gaps(lv)])
	rows[9] = "#####>>>>>>>>>#>>>>>>>>>>###############"
	for y in range(10, 15):
		if (rows[y] as String) != "":
			rows[y] = (rows[y] as String).substr(0, 14) + "#" + (rows[y] as String).substr(15)
	var lv2 := _level(rows, "", "lab-w4", 40)
	_check(_stone_gaps(lv2).is_empty(), "and passes it with a stone pillar in the middle (%s)" % [_stone_gaps(lv2)])
	_check(not _floor_under(lv, 10) and _floor_under(lv, 2), "_floor_under: a pit under a stone roof has no floor, stone has")
	var sunk := _level([roof, roof, "", "", "", "", "", "", "", "", "", "", "", "#".repeat(40), "#".repeat(40)], "", "lab-w4", 40)
	_check(_floor_under(sunk, 10), "_floor_under: a sunken floor is a floor")


func _ice_runs(lv: RefCounted) -> Array:
	## [{x0, x1, y}] tiles: ice and frosted-ledge tops (air above) in runs.
	var out := []
	for y in lv.height:
		var x := 0
		while x < lv.width:
			var t: int = lv.tile(x, y)
			if LevelData.is_slick(t) and not LevelData.is_solid(lv.tile(x, y - 1)):
				var x1 := x
				while LevelData.is_slick(lv.tile(x1 + 1, y)) and not LevelData.is_solid(lv.tile(x1 + 1, y - 1)) and x1 + 1 < lv.width:
					x1 += 1
				out.append({"x0": x, "x1": x1, "y": y})
				x = x1 + 1
			else:
				x += 1
	return out


func _test_ice_landings(ids: Array) -> void:
	## Required ice landings are 3 tiles or more in 4-1 and 4-2, 2 from 4-3;
	## a lone ice block (or a one-tile frosted ledge) is a star route's.
	for id in ids:
		var lv := _load(id)
		var least := 3 if id in ["4-1", "4-2"] else 2
		var star: Array = STAR_ROUTES.get(id, {}).get("route", [])
		var short := []
		for r in _ice_runs(lv):
			var n: int = int(r["x1"]) - int(r["x0"]) + 1
			if n >= least:
				continue
			var ok := false
			for c in star:
				if c.y == int(r["y"]) and c.x >= int(r["x0"]) and c.x <= int(r["x1"]):
					ok = true
			if not ok:
				short.append("%d-%d,%d" % [r["x0"], r["x1"], r["y"]])
		_check(short.is_empty(), "%s: every ice landing is %d tiles or more, but the star route's %s" % [id, least, short])


func _edge_near(lv: RefCounted, x: int, fy: int, n: int) -> bool:
	## On the floor whose top row is fy: an edge over a pit within n tiles
	## of x, either way, before a wall.
	for dir in [-1, 1]:
		for k in range(1, n + 1):
			var xx: int = x + dir * k
			if LevelData.is_solid(lv.tile(xx, fy - 1)):
				break
			if not LevelData.is_floor(lv.tile(xx, fy)):
				if _pit_col(lv, xx):
					return true
				break
	return false


func _test_weight_knocks(ids: Array) -> void:
	## On Dusk no weight knocks him toward a pit edge within 3 tiles, played
	## for real: at every floor cell a weight's bob reaches that lies within
	## 4 tiles of an edge over a pit, he stands still and lets it swing into
	## him (clockwork's guard, the knockback and the ice as they are), and
	## after the knock he's still on that floor, never over the pit.
	for id in ids:
		var lv := _load(id)
		var w := _world(lv, "dusk")
		await process_frame
		var cw = _cw(w)
		var pl: Node2D = w.player
		var bad := []
		var hits := 0
		for wt in cw.weights:
			var c: Vector2i = wt["cell"]
			for dx in range(-5, 6):
				var x: int = c.x + dx
				var fy := -1
				for y in range(c.y + 1, lv.height):
					if LevelData.is_floor(lv.tile(x, y)):
						fy = y
						break
				if fy < 0 or not _edge_near(lv, x, fy, 4):
					continue
				_stand(w, Vector2i(x, fy - 1))
				pl.hp = pl.max_hp
				var hp0: float = pl.hp
				var hit := false
				for i in int(3.4 / DT):
					_ticks(w, 1)
					if pl.hp < hp0:
						hit = true
						break
				if not hit:
					continue
				hits += 1
				for i in int(1.2 / DT):
					_ticks(w, 1)
					if pl.on_floor and absf(pl.velocity.x) < 1.0 and pl.hurt_time > 0.4:
						break
				var tx := floori(pl.position.x / TILE)
				var ok: bool = w.snuffs == 0 and absf(pl.position.y - fy * TILE) < 1.0 and pl.on_floor and not _pit_col(lv, tx)
				if not ok:
					bad.append("%s at %d: ended at (%.1f, %.1f)" % [c, x, pl.position.x / TILE, pl.position.y / TILE])
		print("  %s: %d weight knocks near pit edges played" % [id, hits])
		_check(bad.is_empty(), "%s: on Dusk no weight knock leaves him over a pit %s" % [id, bad])
		await _done(w)


# ---------------------------------------------------------------- arcs

func _floor_cells(lv: RefCounted, r: Rect2, floors: bool) -> Array:
	## The solid (or, with floors, any floor) cells r cuts into (1 px in).
	var out := []
	var q := r.grow(-1.0)
	for y in range(floori(q.position.y / TILE), floori(q.end.y / TILE) + 1):
		for x in range(floori(q.position.x / TILE), floori(q.end.x / TILE) + 1):
			var t: int = lv.tile(x, y)
			if LevelData.is_solid(t) or (floors and LevelData.is_floor(t)):
				out.append(Vector2i(x, y))
	return out


func _circle_cells(lv: RefCounted, c: Vector2, r: float) -> Array:
	var out := []
	for y in range(floori((c.y - r) / TILE), floori((c.y + r) / TILE) + 1):
		for x in range(floori((c.x - r) / TILE), floori((c.x + r) / TILE) + 1):
			if LevelData.is_floor(lv.tile(x, y)):
				var q := Vector2(clampf(c.x, x * TILE, x * TILE + TILE), clampf(c.y, y * TILE, y * TILE + TILE))
				if q.distance_to(c) < r - 0.5:
					out.append(Vector2i(x, y))
	return out


func _segment_cells(lv: RefCounted, a: Vector2, b: Vector2, floors: bool) -> Array:
	## The cells a rod from a (its anchor, on the stone's underside) to b
	## passes through, past its first 6 px.
	var out := []
	var n := maxi(int(a.distance_to(b) / 4.0), 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if p.distance_to(a) < 6.0:
			continue
		var t: int = lv.tile(floori(p.x / TILE), floori(p.y / TILE))
		if LevelData.is_solid(t) or (floors and LevelData.is_floor(t)):
			out.append(Vector2i(floori(p.x / TILE), floori(p.y / TILE)))
	return out


func _arc_hits(lv: RefCounted, cw) -> Array:
	## What swings or turns through the level: every weight's bob (r 18) and
	## rod over its +-50 deg against any floor (stone, rime, ice, ledges);
	## every swing ledge and its rod over +-40 deg, and every cog tooth (a
	## 64 x 12 ledge on the 96 px ring: it reaches 128 px) over a full turn,
	## against solids. Each as "what at cell: [cells]".
	var bad := []
	for wt in cw.weights:
		var anchor: Vector2 = wt["anchor"]
		var rod: float = wt["rod"]
		var hits := {}
		for i in range(-100, 101):
			var a: float = cw.WEIGHT_AMP * i / 100.0
			var bob := anchor + Vector2(sin(a), cos(a)) * rod
			for c in _circle_cells(lv, bob, cw.WEIGHT_R) + _segment_cells(lv, anchor, bob, true):
				hits[c] = true
		if not hits.is_empty():
			bad.append("weight %s: %s" % [wt["cell"], hits.keys()])
	for m in cw.swings:
		var copy = Movers.swing(m.anchor, m.start, m.length, m.phase, m.amp, m.period)
		var hits := {}
		for i in 240:
			copy.update(m.period * i / 240.0, DT)
			var r: Rect2 = copy.rect()
			for c in _floor_cells(lv, r, false) + _segment_cells(lv, m.anchor, Vector2(r.get_center().x, r.position.y), false):
				hits[c] = true
		if not hits.is_empty():
			bad.append("swing %d: %s" % [floori(m.start.x / TILE), hits.keys()])
	for cg in cw.cogs:
		var t0 = cg["teeth"][0]
		var copy = Movers.cog(cg["hub"], int(cg["dir"]), float(cg["phase"]), 1, t0.radius, t0.period)[0]
		var hits := {}
		for i in 240:
			copy.update(t0.period * i / 240.0, DT)
			for c in _floor_cells(lv, copy.rect(), false):
				hits[c] = true
		if not hits.is_empty():
			bad.append("cog %d: %s" % [floori(cg["hub"].x / TILE), hits.keys()])
	return bad


func _test_arc_check() -> void:
	## The arc check can fail: a wall in a weight's swing, a stone in a cog's
	## ring, a stone in a swing's arc.
	var rows := ["#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "#".repeat(40), "", "", "",
			"..............#.........................", "", "..........TTT..............O...#........", "",
			"", "#".repeat(40), "#".repeat(40)]
	var lv := _level(rows, "", "lab-w4", 40)
	var w := _world(_weight_level({12: "............#..........................."}))
	await process_frame
	var bad := _arc_hits(w.level, _cw(w))
	_check(bad.size() == 1 and str(bad[0]).begins_with("weight (9, 7)"), "the arc check: a wall in a weight's swing (%s)" % [bad])
	await _done(w)
	var w2 := _world(lv)
	await process_frame
	var bad2 := _arc_hits(lv, _cw(w2))
	var kinds := bad2.map(func(b): return str(b).get_slice(" ", 0))
	_check(kinds.has("swing") and kinds.has("cog"), "and a stone in a swing's arc and in a cog's ring (%s)" % [bad2])
	await _done(w2)


func _test_arcs(ids: Array) -> void:
	for id in ids:
		var lv := _load(id)
		var w := _world(lv)
		await process_frame
		var cw = _cw(w)
		var bad := _arc_hits(lv, cw)
		_check(bad.is_empty(),
				"%s: no weight, swing or cog tooth passes through the level (%d weights, %d swings, %d cogs) %s"
				% [id, cw.weights.size(), cw.swings.size(), cw.cogs.size(), bad])
		await _done(w)


# ---------------------------------------------------------------- Spurwheels and Dreads

const WHEEL_ROAM := 10           # tiles: a Spurwheel's round stays this near its start
const WHEEL_SECS := 40.0
const COG_CLEAR := 9.0            # tiles past a cog's hub a jump off its leading tooth comes down (its 4-tile tooth and a jump)


func _test_wheels(ids: Array) -> void:
	## Every Spurwheel keeps to its own box or pillar (spurwheel.gd rolls
	## along the outline of the solid it's on, so one on the level's floor
	## would roll away down the level, through the altars): rolling 40 s with
	## Waxby near (unhurt), each stays within WHEEL_ROAM tiles of its start,
	## more than 4 tiles from any altar or bell, out of the boss arena, and
	## alive.
	for id in ids:
		var lv := _load(id)
		var marks := []
		for e in lv.entities:
			if e["kind"] in ["altar", "bell"]:
				marks.append(int(e["cell"].x))
		var arena := {}
		for e in lv.entities:
			if e["kind"] == "boss":
				arena = Arena.find(lv, LevelData.cell_floor(e["cell"]))
		var cells := []
		for e in lv.entities:
			if e["kind"] == "spurwheel" or (e["kind"] == "dread" and str(lv.dread).find("|spurwheel|") >= 0):
				cells.append(e["cell"])
		# (and off every cog's exit arc: the rev5 review found 6-4's box where
		# every jump off the right tooth came down, 5 tiles from the hub)
		var hubs := []
		for e in lv.entities:
			if e["kind"] == "cog":
				hubs.append(e["cell"])
		for c in cells:
			game.reset()
			game.new_hero("knight")
			game.data["difficulty"] = "dusk"
			var w: Node2D = WorldScript.new()
			w.setup(lv, true)
			w.paused = true
			root.add_child(w)
			await process_frame
			var wheel = null
			for e in w.enemies:
				if e.kind == "spurwheel" and (wheel == null or e.position.distance_to(LevelData.cell_floor(c)) < wheel.position.distance_to(LevelData.cell_floor(c))):
					wheel = e
			# Waxby on the nearest floor 6 or more tiles before it (not in a pit).
			var sx: int = c.x - 6
			var fy: int = -1
			while fy < 0 and sx > c.x - 20:
				for y in range(2, lv.height):
					if LevelData.is_floor(lv.tile(sx, y)) and not LevelData.is_floor(lv.tile(sx, y - 1)) and not LevelData.is_solid(lv.tile(sx, y - 2)):
						fy = y
						break
				if fy < 0:
					sx -= 1
			var pl: Node2D = w.player
			_stand(w, Vector2i(sx, fy - 1))
			var x0: float = wheel.position.x if wheel != null else 0.0
			var lo := x0
			var hi := x0
			var near := []
			for i in int(WHEEL_SECS / DT):
				pl.invuln = 99.0
				pl.hp = pl.max_hp
				_ticks(w, 1)
				if wheel == null or not is_instance_valid(wheel) or not wheel.alive:
					break
				var wx: float = wheel.position.x
				lo = minf(lo, wx)
				hi = maxf(hi, wx)
			var alive: bool = wheel != null and is_instance_valid(wheel) and wheel.alive
			for m in marks:
				if float(m) * TILE + TILE * 0.5 > lo - 4 * TILE and float(m) * TILE + TILE * 0.5 < hi + 4 * TILE:
					near.append(m)
			var in_arena: bool = not arena.is_empty() and hi > float(arena["left"]) and lo < float(arena["right"])
			var roam := maxf(x0 - lo, hi - x0) / TILE
			for hb in hubs:
				# The landing zone of a jump off the cog's leading (right) tooth:
				# 3 to COG_CLEAR tiles past the hub, from 2 rows over the hub to
				# 2 under it (the tooth's height: a box hung lower, like 4-2's
				# over its landing's floor, is walked under).
				var zone := Rect2((float(hb.x) + 3.0) * TILE, (float(hb.y) - 2.0) * TILE, (COG_CLEAR - 3.0) * TILE, 4.0 * TILE)
				var round_r := Rect2(lo - TILE * 0.5, float(c.y) * TILE, hi - lo + TILE, 2.0 * TILE)
				_check(not zone.intersects(round_r), "%s: the Spurwheel at %s rolls clear of the landing off the cog at %s (x %.1f to %.1f)" % [id, c, hb, lo / TILE, hi / TILE])
			_check(alive and roam <= WHEEL_ROAM and near.is_empty() and not in_arena,
					"%s: the Spurwheel at %s keeps to its own box (x %.1f to %.1f, %s; near altars or bells %s)"
					% [id, c, lo / TILE, hi / TILE, "alive" if alive else "lost", near])
			await _done(w)


# The Dread lairs (spec 3.1, 4.6: "a side lair ... off the main path"): the
# floor each Dread fights on, as cells (x0, x1, rows y0-y1), a cell before
# it and a column past it. With that floor made lava, the bot still gets past.
const LAIRS := {
	"4-1": {"cells": [274, 295, 10, 12], "from": Vector2i(270, 7), "past": 305},
	"4-2": {"cells": [322, 343, 10, 12], "from": Vector2i(314, 12), "past": 350},
	"4-3": {"cells": [289, 297, 4, 10], "from": Vector2i(280, 12), "past": 302},
}


func _test_lairs(ids: Array) -> void:
	for id in ids:
		if not LAIRS.has(id):
			continue
		var lv := _load(id)
		var lair: Dictionary = LAIRS[id]
		var cz: Array = lair["cells"]
		var dread := Vector2i(-1, -1)
		for e in lv.entities:
			if e["kind"] == "dread":
				dread = e["cell"]
		_check(dread.x >= int(cz[0]) - 1 and dread.x <= int(cz[1]) + 1 and dread.y >= int(cz[2]) - 1 and dread.y <= int(cz[3]) + 1,
				"%s: the Dread (%s) is in its lair" % [id, dread])
		var from: Vector2i = lair["from"]
		var x0 := from.x - 4
		var crop = _crop(lv, x0, int(lair["past"]) + 4, from)
		var copy = Reach.static_copy(crop)
		for y in range(int(cz[2]), int(cz[3]) + 1):
			for x in range(int(cz[0]), int(cz[1]) + 1):
				if copy.tile(x - x0, y) == LevelData.AIR:
					copy.set_tile(x - x0, y, LevelData.LAVA)
		var px: float = (int(lair["past"]) - x0) * TILE
		var goal := {"what": "past", "p": Vector2(px, 0), "rope": true, "rect": Rect2(px, 0, TILE, lv.height * TILE)}
		var s = ReachSearch.new()
		s.setup(copy, LevelData.cell_floor(copy.start), {"goals": [goal]})
		s.run()
		_check(s.found.has("past"), "%s: the Dread's lair is off the main path: with its floor as lava the bot still gets past (%d states)" % [id, s.seen.size()])
		s.free_player()
		# (The search can fail: lava the lair's columns from the roof down and
		# nothing gets past.)
		for y in range(2, lv.height - 2):
			for x in range(int(cz[0]), int(cz[1]) + 1):
				if copy.tile(x - x0, y) == LevelData.AIR:
					copy.set_tile(x - x0, y, LevelData.LAVA)
		var s2 = ReachSearch.new()
		s2.setup(copy, LevelData.cell_floor(copy.start), {"goals": [goal]})
		s2.run()
		_check(not s2.found.has("past"), "%s: and with the lair's columns lava from the roof down, it can't" % id)
		s2.free_player()


# ---------------------------------------------------------------- keeper nooks

# The keeper nooks (spec 3.1: one optional spot only a quirk reaches, an
# ember cache, never a sigil; spec 3.5.3 names each level's quirk): the cells
# a hero standing in it has his feet in (x0-x1, floor row), its embers, how
# its quirk gets in ("go": a lone hero's tries, or "world": a real World with
# the calling whose kit gives the quirk), and the tries that must all fail
# ("no": starts on cells x0-x1 of a row, or -1 for the floor under each
# column; held way before the jump, steer after, jump tick range, hold).
const NOOKS := {
	"4-1": {"quirk": "stampede", "x0": 230, "x1": 231, "floor": 7, "embers": 2,
			"what": "a shelf by altar 3, a row up and 6 tiles past the end of the vault's roof: a Bellfounder in her stride jumps it",
			"go": {"from": [Vector2i(213, 7)], "pre": [1], "dir": [1], "edge": [224, -30, 12], "hold": [40, 90]},
			"no": [{"cells": [213, 217, 7], "pre": [1], "dir": [1, 0], "edge": [224, -30, 30], "hold": [40, 90]},
				{"cells": [222, 236, -1], "pre": [-1, 1], "dir": [-1, 1], "k": [0, 48, 8], "hold": [40, 90]}]},
	"4-2": {"quirk": "grave_step", "calling": "sexton", "x0": 136, "x1": 137, "floor": 8, "embers": 2,
			"what": "a gear housing hung 5 rows over ES_GUARD's floor: the Sexton's bone ledge lifts him to it",
			"world": {"from": [Vector2i(134, 12), Vector2i(133, 12), Vector2i(139, 12), Vector2i(140, 12)]},
			"no": [{"cells": [128, 146, -1], "pre": [-1, 1], "dir": [-1, 1], "k": [0, 48, 8], "hold": [40, 90]}]},
	"4-3": {"quirk": "ledge_grab", "x0": 210, "x1": 211, "floor": 9, "embers": 2,
			"what": "WT_VAULT's shelf by the weight's slot: a jump from the step bonks the lip and stops 6 px short",
			"go": {"from": [Vector2i(209, 11)], "pre": [0, 1, -1], "dir": [1, -1], "k": [0, 24, 4], "hold": [20, 60]},
			"no": [{"cells": [204, 216, -1], "pre": [-1, 1], "dir": [-1, 1], "k": [0, 48, 6], "hold": [40, 90]},
				{"cells": [209, 209, 11], "pre": [-1, 1], "dir": [-1, 0, 1], "k": [0, 48, 4], "hold": [10, 40, 90]}]},
}


func _nook_sim(lv: RefCounted, quirk: String, feet: Vector2):
	## A lone hero in lv (the bot's stand-in World).
	var bw = Reach.BotWorld.new()
	bw.level = lv
	var p = PlayerScript.new()
	p.level = lv
	p.world = bw
	p.quirk = quirk
	p.reset_at(feet)
	p.on_floor = true
	return p


func _nook_in(p, nk: Dictionary) -> bool:
	return p.on_floor and absf(p.position.y - int(nk["floor"]) * TILE) < 0.5 and p.position.x > int(nk["x0"]) * TILE \
			and p.position.x < (int(nk["x1"]) + 1) * TILE


func _nook_embers(lv: RefCounted, nk: Dictionary) -> Array:
	var pts := []
	for e in lv.entities:
		var ec: Vector2i = e["cell"]
		if e["kind"] == "ember" and ec.x >= int(nk["x0"]) and ec.x <= int(nk["x1"]) and ec.y < int(nk["floor"]):
			pts.append(LevelData.cell_center(ec))
	return pts


func _nook_try(lv: RefCounted, nk: Dictionary, quirk: String, feet: Vector2, pre: int, dir: int, k: int, hold: int, jump_x := -1.0) -> bool:
	## Hold pre, then from tick k (or once past jump_x, running pre) jump
	## (held hold ticks) and steer dir: in, or near enough to take one of its
	## embers (world.gd: his rect grown 6 px over the ember's middle)?
	var p = _nook_sim(lv, quirk, feet)
	var pts := _nook_embers(lv, nk)
	var prev := false
	var inside := false
	var j0 := k if jump_x < 0.0 else 100000
	for i in (k + 200 if jump_x < 0.0 else 700):
		if jump_x >= 0.0 and j0 > i and (p.position.x - jump_x) * pre >= 0.0:
			j0 = i
		var held := i >= j0 and i < j0 + hold
		var d := pre if i < j0 else dir
		p.pad = {"right": d > 0, "left": d < 0, "jump": held, "jump_pressed": held and not prev}
		prev = held
		p.step(DT)
		p.world.ftime += DT
		if _nook_in(p, nk) or pts.any(func(q): return p.rect().grow(6.0).has_point(q)):
			inside = true
			break
	p.free()
	return inside


func _nook_ks(spec: Dictionary, pre: int) -> Array:
	## The jump timings: [tick, -1] for a jump at tick k, or [0, x px] for a
	## running jump from k px short of (or past) the edge tile's side.
	var out := []
	if spec.has("edge"):
		var e: Array = spec["edge"]
		for k in range(int(e[1]), int(e[2]) + 1, 2):
			out.append([0, float(int(e[0]) * TILE) - k * pre])
	else:
		for k in range(int(spec["k"][0]), int(spec["k"][1]), int(spec["k"][2])):
			out.append([k, -1.0])
	return out


func _nook_starts(lv: RefCounted, spec: Dictionary) -> Array:
	var c: Array = spec["cells"]
	var out := []
	for x in range(int(c[0]), int(c[1]) + 1):
		var row: int = c[2]
		if row < 0:
			for y in range(lv.height - 1, 1, -1):
				if LevelData.is_floor(lv.tile(x, y)) and not LevelData.is_floor(lv.tile(x, y - 1)):
					row = y - 1
					break
		if row >= 0 and not LevelData.is_solid(lv.tile(x, row)) and not LevelData.is_solid(lv.tile(x, row - 1)):
			out.append(LevelData.cell_floor(Vector2i(x, row)))
	return out


func _nook_world_in(lv: RefCounted, nk: Dictionary) -> bool:
	## The calling whose kit gives the quirk, in a real World: from each start
	## under it, jump toward it and jump again in the air (Grave Step).
	game.reset()
	game.new_hero(str(nk["calling"]))
	game.data["difficulty"] = "dusk"
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = true
	w.paused = true
	root.add_child(w)
	var pl: Node2D = w.player
	var got := false
	for st in nk["world"]["from"]:
		var dir := 1 if int(st.x) < int(nk["x0"]) else -1
		for k2 in range(16, 64, 4):
			for steer in [0, 12, 24]:
				if got:
					break
				_stand(w, st)
				pl.hurt_time = 9.0
				_ticks(w, 150)   # (a bone ledge from the last try crumbles)
				_stand(w, st)
				pl.hurt_time = 9.0
				var prev := false
				for i in 200:
					var held := i < 30 or (i >= k2 and i < k2 + 30)
					var pd := {"jump": held, "jump_pressed": held and not prev}
					prev = held
					if i >= steer:
						pd["right" if dir > 0 else "left"] = true
					_ticks(w, 1, pd)
					if _nook_in(pl, nk):
						got = true
						break
	w.queue_free()
	return got


func _test_nooks(ids: Array) -> void:
	for id in ids:
		if not NOOKS.has(id):
			continue
		var nk: Dictionary = NOOKS[id]
		var lv := _load(id)
		var x0: int = nk["x0"]
		var x1: int = nk["x1"]
		var fl: int = nk["floor"]
		var q: String = nk["quirk"]
		var sigils: Array = lv.entities.filter(func(e): return e["kind"] == "sigil" and absi(int(e["cell"].x) - x0) <= 4)
		_check(_nook_embers(lv, nk).size() == int(nk["embers"]) and sigils.is_empty() and LevelData.is_solid(lv.tile(x0, fl)),
				"%s: the keeper nook holds an ember cache (%d), no sigil" % [id, _nook_embers(lv, nk).size()])
		# Its quirk gets in.
		var got := false
		if nk.has("world"):
			got = _nook_world_in(lv, nk)
			await process_frame
		else:
			var go: Dictionary = nk["go"]
			for st in go["from"]:
				for pre in go["pre"]:
					for dir in go["dir"]:
						for kj in _nook_ks(go, pre):
							for hold in go["hold"]:
								if not got and _nook_try(lv, nk, q, LevelData.cell_floor(st), pre, dir, kj[0], hold, kj[1]):
									got = true
		_check(got, "%s: %s gets into the keeper nook (%s)" % [id, q, nk["what"]])
		# No other way in: from every start near it, every way held, every
		# jump timing, with no quirk and the other movement quirks.
		for oq in ["", "cling", "stampede", "drift", "ledge_grab"]:
			if oq == q:
				continue
			var n := 0
			var in_n := 0
			for spec in nk["no"]:
				for st in _nook_starts(lv, spec):
					for pre in spec["pre"]:
						for dir in spec["dir"]:
							for kj in _nook_ks(spec, pre):
								for hold in spec["hold"]:
									n += 1
									if _nook_try(lv, nk, oq, st, pre, dir, kj[0], hold, kj[1]):
										in_n += 1
			_check(in_n == 0 and n > 50, "%s: with %s, none of %d jumps near the nook gets in or takes its embers (%d did)" % [id, "no quirk" if oq == "" else oq, n, in_n])
		# The bot (no quirk, its whole action set).
		var cx0: int = x0 - 16
		var crop = _crop(Reach.static_copy(lv), cx0, x1 + 14, Vector2i(x0 - 6, 12))
		for yy in range(lv.height - 1, 0, -1):
			if LevelData.is_floor(lv.tile(x0 - 6, yy)) and not LevelData.is_floor(lv.tile(x0 - 6, yy - 1)):
				crop.start = Vector2i(x0 - 6 - cx0, yy - 1)
				break
		var goal := {"what": "nook", "p": Vector2.ZERO, "rope": true,
				"rect": Rect2((x0 - cx0) * TILE + 2, (fl - 1) * TILE, (x1 - x0 + 1) * TILE - 4, TILE - 4)}
		var s = ReachSearch.new()
		s.setup(crop, LevelData.cell_floor(crop.start), {"goals": [goal]})
		s.run()
		_check(not s.found.has("nook") and s.seen.size() > 20, "%s: the reachability bot never gets into the nook (%d states)" % [id, s.seen.size()])
		s.free_player()
		# And he gets back down: stood in it and walking out, he's on the floor.
		var w := _world(lv)
		await process_frame
		var pl: Node2D = w.player
		var out := false
		for dir in [1, -1]:
			_stand(w, Vector2i(x0 if dir > 0 else x1, fl - 1))
			pl.hurt_time = 9.0
			for i in int(3.0 / DT):
				_ticks(w, 1, {"right": dir > 0 and i < 60, "left": dir < 0 and i < 60})
				if pl.on_floor and pl.position.y > (fl + 2) * TILE:
					out = true
					break
		_check(out, "%s: and he walks off the nook back to the floor" % id)
		await _done(w)


func _by_x(list: Array) -> Array:
	var out := list.duplicate()
	out.sort_custom(func(a, b): return int(a["cell"].x) < int(b["cell"].x))
	return out


func _floor_under(lv: RefCounted, x: int) -> bool:
	## Something to land on under this column (a floor, or a thorn bed on
	## one), not a pit: the stone roof over it doesn't count.
	return not _pit_col(lv, x)


func _test_safe_first(ids: Array) -> void:
	## Safe first (decisions.md): the first cogs (4-2's first pair) over a
	## sunken floor, the first swings (4-3's first two) and the bridge
	## weights (4-3's second to fourth) over thorn beds: under every column
	## they sweep there's a floor, never a pit. (Each feature is taught by
	## Hollin's first-time bark, BARK_LEAD tiles before it, since the sign
	## cut: _test_bark_lead and the routes' bark checks.)
	if ids.has("4-2"):
		var lv := _load("4-2")
		var cogs: Array = _by_x(lv.of_kind("cog"))
		var pit := []
		for i in mini(2, cogs.size()):
			for x in range(cogs[i]["cell"].x - 4, cogs[i]["cell"].x + 5):
				if not _floor_under(lv, x):
					pit.append(x)
		_check(pit.is_empty() and cogs.size() >= 2, "4-2: the first cogs turn over a sunken floor, not a pit %s" % [pit])
	if ids.has("4-3"):
		var lv := _load("4-3")
		var swings: Array = _by_x(lv.of_kind("swing"))
		var weights: Array = _by_x(lv.of_kind("weight"))
		var pit := []
		for i in mini(2, swings.size()):
			for x in range(swings[i]["cell"].x - 3, swings[i]["cell"].x + int(swings[i]["length"]) + 3):
				if not _floor_under(lv, x):
					pit.append(x)
		for i in range(1, mini(4, weights.size())):
			for x in range(weights[i]["cell"].x - 4, weights[i]["cell"].x + 5):
				if not _floor_under(lv, x):
					pit.append(x)
		_check(pit.is_empty(), "4-3: the first swings and the bridge's weights over thorn beds, not pits %s" % [pit])
		var thorns := 0
		for x in range(swings[0]["cell"].x, swings[1]["cell"].x + 3):
			for y in lv.height:
				if lv.tile(x, y) == LevelData.SPIKES_UP:
					thorns += 1
		_check(thorns > 0, "4-3: and a thorn bed under the first swings")


# ---------------------------------------------------------------- star routes

func _crop(lv: RefCounted, x0: int, x1: int, from: Vector2i) -> RefCounted:
	var c = LevelData.new()
	c.width = x1 - x0
	c.height = lv.height
	c.tiles = PackedByteArray()
	c.tiles.resize(c.width * c.height)
	for y in c.height:
		for x in c.width:
			c.tiles[y * c.width + x] = lv.tile(x0 + x, y)
	c.entities = []
	for e in lv.entities:
		if e["cell"].x >= x0 and e["cell"].x < x1 and e["kind"] in ["sigil", "cog", "swing"]:
			var m: Dictionary = e.duplicate()
			m["cell"] = Vector2i(e["cell"].x - x0, e["cell"].y)
			c.entities.append(m)
	c.start = Vector2i(from.x - x0, from.y)
	c.id = lv.id
	return c


func _reach_goal(lv: RefCounted, goal: String) -> bool:
	var s = ReachSearch.new()
	var copy = Reach.static_copy(lv)
	s.setup(copy, LevelData.cell_floor(copy.start), {})
	s.run()
	var ok: bool = s.found.has(goal)
	s.free_player()
	return ok


func _test_star_routes(ids: Array) -> void:
	for id in ids:
		if not STAR_ROUTES.has(id):
			continue
		var sr: Dictionary = STAR_ROUTES[id]
		var lv := _load(id)
		var tight := true
		for c in sr["route"]:
			var t: int = lv.tile(c.x, c.y)
			var lone: bool = LevelData.is_floor(t) and not LevelData.is_floor(lv.tile(c.x - 1, c.y)) and not LevelData.is_floor(lv.tile(c.x + 1, c.y)) \
					and not LevelData.is_solid(lv.tile(c.x, c.y - 1))
			tight = tight and lone
		_check(tight, "%s: the star route's landings are tight: %s" % [id, sr["what"]])
		var from: Vector2i = sr["from"]
		var x0 := from.x
		var x1 := from.x
		for c in sr["route"]:
			x0 = mini(x0, c.x)
			x1 = maxi(x1, c.x)
		for e in lv.entities:
			if e["kind"] == "sigil" and int(e["index"]) == 2:
				x0 = mini(x0, e["cell"].x)
				x1 = maxi(x1, e["cell"].x)
		var crop := _crop(lv, maxi(x0 - 12, 0), mini(x1 + 6, lv.width), from)
		_check(_reach_goal(crop, "sigil 3"), "%s: the bot reaches sigil 3 by the star route" % id)
		for c in sr["route"]:
			crop.set_tile(c.x - maxi(x0 - 12, 0), c.y, LevelData.AIR)
		_check(not _reach_goal(crop, "sigil 3"), "%s: and without its landings it can't" % id)


# ---------------------------------------------------------------- rime is never a floor

func _test_rime_required(ids: Array) -> void:
	## Rime is never a required floor. With rime as air (the bot's static
	## copy, as test_core proves it) every goal is reached; and with rime
	## solid until he leans on it from firm ground (each patch the bot's
	## sims touch while it stands beside it melts; then search again), every
	## goal still is.
	for id in ids:
		var lv := _load(id)
		var has_rime := false
		for t in lv.tiles:
			if t == LevelData.RIME:
				has_rime = true
		if not has_rime:
			continue
		var t0 := Time.get_ticks_msec()
		var goals := Reach.goals_of(lv)
		var copy = Reach.static_copy(lv)
		# Rime back in, solid.
		var patches := {}   # name -> [cells]
		for y in lv.height:
			for x in lv.width:
				if lv.tile(x, y) == LevelData.RIME:
					copy.set_tile(x, y, LevelData.RIME)
		var cw = load(CLOCKWORK).new()
		cw.level = lv
		for y in lv.height:
			for x in lv.width:
				var c := Vector2i(x, y)
				if lv.tile(x, y) == LevelData.RIME and not cw._rime_of.has(c):
					cw._flood_rime(c)
		for i in cw.patches.size():
			var r: Rect2 = cw.patches[i]["rect"]
			patches["rime %d" % i] = cw.patches[i]["cells"]
		var found := {}
		var rounds := 0
		var melted := {}
		while rounds < 12:
			rounds += 1
			var touch := {}
			for name in patches:
				if melted.has(name):
					continue
				var r2 := Rect2()
				var first := true
				for c in patches[name]:
					var cr := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
					r2 = cr if first else r2.merge(cr)
					first = false
				touch[name] = r2.grow(cw.RIME_GROW)
			var s = ReachSearch.new()
			s.setup(copy, LevelData.cell_floor(copy.start), {"touch": touch})
			s.run()
			for g in goals:
				if s.found.has(g["what"]):
					found[g["what"]] = true
			var more := false
			for name in s.touched:
				if not melted.has(name):
					melted[name] = true
					more = true
					for c in patches[name]:
						copy.set_tile(c.x, c.y, LevelData.AIR)
			s.free_player()
			if not more:
				break
		var missing := []
		for g in goals:
			if not found.has(g["what"]):
				missing.append(g["what"])
		print("  %s, rime solid until leaned on: %d searches, %d of %d patches melted, %d ms" % [id, rounds, melted.size(), patches.size(), Time.get_ticks_msec() - t0])
		_check(missing.is_empty(), "%s: rime is never a required floor: with rime solid until he leans on it the bot still reaches everything %s" % [id, missing])
		cw = null


# ---------------------------------------------------------------- the golden routes

func _critical(id: String) -> Array:
	## The movers on 4-x's critical path the route must ride (by the first
	## cell of the cog hub or swing): measured with the bot (take one's ring
	## or arc away and the bell or the arena is out of reach).
	return {"4-1": [], "4-2": ["cog 73", "cog 104", "cog 116", "lift 276", "lift 286"],
			"4-3": ["swing 62", "swing 72", "swing 102", "swing 119", "cog 178", "swing 189"],
			"4-4": ["cog 18", "cog 90", "swing 101"]}.get(id, [])


const STUB_HUD := """extends CanvasLayer
var world: Node
var said := []
func bark(k: String) -> void:
	said.append([k, world.player.on_floor if world != null else false, world.player.position.x if world != null else 0.0])
func show_hint(_t = "") -> void:
	pass
func toast(_a = "", _b = "") -> void:
	pass
func bump_embers(_a = null) -> void:
	pass
func bump_flames(_a = null) -> void:
	pass
func title_card(_a = "", _b = "") -> void:
	pass
func sigil_found(_a = 0, _b = null) -> void:
	pass
func level_up(_n = 0) -> void:
	pass
func banner(_t = "") -> void:
	pass
func xp_tick(_a = null, _b = null) -> void:
	pass
func show_pickup(_a = null, _b = null, _c = null) -> void:
	pass
func relic_found(_a = null, _b = null) -> void:
	pass
func elite_seen(_a = null, _b = null) -> void:
	pass
func banked(_a = null, _b = null) -> void:
	pass
func boss_bar(_i = null) -> void:
	pass
func dim_ring(_on = false) -> void:
	pass
"""
# Each level's first-time barks (story.gd BARKS, contract 9.2), in the level
# where the feature first appears.
const FEATURE_BARKS := ["first_ice", "first_rime", "first_belt", "first_gear", "first_pendulum", "first_swing"]
const BARKS := {"4-1": ["first_ice", "first_rime"], "4-2": ["first_belt", "first_gear"],
		"4-3": ["first_pendulum", "first_swing"]}


func _stub_hud() -> CanvasLayer:
	var sc := GDScript.new()
	sc.source_code = STUB_HUD
	sc.reload()
	return sc.new()


func _test_routes(ids: Array) -> void:
	## Every critical cog, swing and lift is ridden in its level's golden
	## route (tests/test_routes.gd replays 4-1 to 4-3 to the bell; 4-4's
	## approach route is replayed here, to the arena door, with no snuff),
	## and no route stands still on ice within 5 tiles of a pit's edge.
	for id in ids:
		var path := "res://tests/routes/%s.json" % id if id != "4-4" else APPROACH
		if not FileAccess.file_exists(path):
			_check(false, "%s has a golden route (%s)" % [id, path])
			continue
		var route := Route.read(path)
		var lv := _load(id)
		Route.prepare(game, route, lv)
		var w: Node2D = WorldScript.new()
		w.setup(lv, true)
		w.no_monsters = true
		w.paused = true
		root.add_child(w)
		await process_frame
		var hud := _stub_hud()
		hud.world = w
		w.hud = hud
		var masks := Route.decode(route["runs"])
		var ridden := {}
		var still_t := 0.0
		var bad_stop := []
		var hp_was: float = w.player.hp
		var hurt := []
		for i in masks.size():
			w.test_pad = Route.pad_of(int(masks[i]))
			w._read_pad()
			w.tick(DT)
			var pl: Node2D = w.player
			if pl.riding != null:
				var m = pl.riding
				var key := ""
				if m.kind == "orbit":
					key = "cog %d" % floori(m.hub.x / TILE)
				elif m.kind == "arc":
					key = "swing %d" % floori(m.start.x / TILE)
				elif m.kind == "y" or m.kind == "x":
					key = "lift %d" % floori(m.start.x / TILE)
				ridden[key] = true
			if pl.on_floor and bool(pl.on_ice) and absf(pl.velocity.x) < 1.0 and w.state == "play":
				still_t += DT
				if still_t > 0.3 and _pit_within(lv, pl, 5):
					bad_stop.append(int(pl.position.x / TILE))
					still_t = -INF
			else:
				still_t = 0.0
			if pl.hp < hp_was - 0.01:
				hurt.append("%s at x %d" % [w.snuff_causes.get("_last", "?"), int(pl.position.x / TILE)])
			hp_was = pl.hp
		var missing := []
		for k in _critical(id):
			if not ridden.has(k):
				missing.append(k)
		_check(missing.is_empty(), "%s: the golden route rides every critical cog, swing and lift (missing %s; rode %s)" % [id, missing, ridden.keys()])
		_check(bad_stop.is_empty(), "%s: the route never waits on ice within 5 tiles of a pit's edge %s" % [id, bad_stop])
		_check(hurt.is_empty(), "%s: and takes no hit on the way: every weight, icicle and gap timed (%s)" % [id, hurt])
		# The first-time barks: each once, and never mid-jump.
		var heard := {}
		var airborne := []
		for b in hud.said:
			var k: String = b[0]
			heard[k] = int(heard.get(k, 0)) + 1
			if FEATURE_BARKS.has(k) and not bool(b[1]):
				airborne.append("%s at x %d" % [k, int(float(b[2]) / TILE)])
		for k in BARKS.get(id, []):
			_check(int(heard.get(k, 0)) == 1, "%s: %s is barked once as the feature is taught (%d)" % [id, k, int(heard.get(k, 0))])
		_check(airborne.is_empty(), "%s: no first-time bark lands mid-jump %s" % [id, airborne])
		print("  %s: barks %s" % [id, hud.said.map(func(b): return "%s@%d" % [b[0], int(float(b[2]) / TILE)])])
		if id == "4-4":
			var door := -1
			for e in lv.entities:
				if e["kind"] == "altar":
					door = maxi(door, int(e["cell"].x))
			var lit := false
			for a in w.altars:
				if int(a["cell"].x) == door and bool(a["lit"]):
					lit = true
			_check(lit and w.snuffs == 0, "4-4: the approach route lights the arena door's altar with no snuff (%d snuffs)" % w.snuffs)
		w.queue_free()
		await process_frame


func _pit_within(lv: RefCounted, pl: Node2D, tiles: int) -> bool:
	## A floor edge over a drop to a pit (or a hurt) within this many tiles on
	## his row, either way, before a wall.
	var ty := floori((pl.position.y + 1.0) / TILE)
	var tx := floori(pl.position.x / TILE)
	for dir in [-1, 1]:
		for k in range(1, tiles + 1):
			var x: int = tx + dir * k
			if LevelData.is_solid(lv.tile(x, ty - 1)):
				break
			if not LevelData.is_floor(lv.tile(x, ty)):
				# An edge: is it over a pit (open below) or a hurt?
				var y := ty
				var deep := true
				while y < lv.height:
					var t: int = lv.tile(x, y)
					if LevelData.is_floor(t):
						deep = false
						break
					y += 1
				if deep or lv.hurts_at(x, mini(y, lv.height - 1), Rect2(x * TILE, y * TILE - 8, TILE, 8)):
					return true
				break
	return false
