extends SceneTree
## Build 2's sealed fight rooms (scripts/features/sealed.gd and its header
## `room:`; tools/levels/common.py rooms_header and check_rooms; the lab,
## tools/levels/lab_rooms.py's lab-rooms):
## - the header reads (its kinds, columns, rows, a clock, a named foe; a part
##   that doesn't read is left out), and no level on the path or a secret one
##   has a room yet: their Worlds keep every monster in play and in spawns;
## - a duel: its Dread asleep at his post (out of the World's list), the
##   doors open at the altar; in, they grind SEAL_TELL s (out again in time
##   and they stay open), then shut at both ends; he wakes with his title
##   card and his bar (his name, Dread and his Omen, his life), and no plate;
##   a snuff opens the room and starts it over (a fresh Dread asleep at full
##   life, Wick at the door altar, the bar down); his fall opens the doors;
## - an ambush: hidden till the doors shut, then they drop in one by one, out
##   of reach till they have; 'Ambush · 5' counts down as they fall; a snuff
##   mid-fight brings them all back (one put out as a respawn, off the altar
##   snapshot's killed list); the last one's fall opens the doors with a
##   REWARD item (where loot is kept), and a snuff afterwards never refills
##   it (Dusk from World 3 respawns);
## - a hold: 'Hold · 0:20' runs down and the doors open at 20 s with foes
##   still up, or sooner once they're all down;
## - a foe knocked into the hold's pit is put out (a pit kill): the doors
##   never stay shut for good; a Twinned one's halves hold them till they fall;
## - the loft: walk under it and it never seals; climb in and only its gap
##   shuts;
## - no monsters (the golden routes): every room open for good; an altar
##   resume with a room's monsters killed: that room open for good;
## - the --autoplay bot clears every room it walks into on the lab and rings
##   its bell (walking under the loft); secrets.gd's Warden is its foe only
##   in its sealed fight;
## - every level file with rooms: a monster in each, a way in, and an altar
##   within ALTAR_REACH tiles before each door.
##
##     godot --headless --path game --script res://tests/test_rooms.gd

const LevelData := preload("res://scripts/level_data.gd")
const Sealed := preload("res://scripts/features/sealed.gd")
const AutoBot := preload("res://scripts/autoplay_bot.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const TILE := 32
const DT := 1.0 / 120.0
const LAB := "lab-rooms"
const STUB_HUD := """extends CanvasLayer
var said := []
func _say(k: String, a = null, b = null) -> void:
	said.append([k, a, b])
func bark(k: String) -> void:
	_say("bark", k)
func boss_bar(i = null) -> void:
	_say("boss_bar", i)
func toast(a = null, b = null, c = null) -> void:
	_say("toast", a, b)
func title_card(a = null, b = null, c = null) -> void:
	_say("title_card", a, b)
func elite_seen(e = null) -> void:
	_say("elite_seen", e)
func bump_embers(a = null) -> void:
	pass
func bump_flames(a = null) -> void:
	pass
func sigil_found(a = null, b = null) -> void:
	pass
func xp_tick(a = null, b = null, c = null) -> void:
	pass
func show_pickup(a = null, b = null, c = null) -> void:
	pass
func show_hint(a = null) -> void:
	pass
func relic_found(a = null) -> void:
	pass
func level_up(a = null, b = null, c = null) -> void:
	pass
func dim_ring(a = null) -> void:
	pass
func banner(a = null) -> void:
	pass
func banked(a = null) -> void:
	pass
func layout() -> Dictionary:
	return {}
func bars() -> Array:
	return said.filter(func(x): return x[0] == "boss_bar").map(func(x): return x[1])
"""

var WorldScript: GDScript
var game: Node
var _passed := 0
var _failed := 0
var _keep_alive := false         # _ticks keeps his life full (the foes knock him into the hold's pit)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WorldScript = load("res://scripts/world.gd")
	game = root.get_node_or_null("Game")
	game.save_path = "user://test_rooms_save.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	_test_parse()
	_test_rules()
	await _test_absent()
	await _test_duel()
	await _test_ambush()
	await _test_hold()
	await _test_hold_cleared()
	await _test_pit()
	await _test_twinned()
	await _test_loft()
	await _test_no_monsters()
	await _test_resume()
	await _test_bot()
	await _test_warden_target()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	print("test_rooms: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _world(id: String, opts := {}) -> Node2D:
	var lv = opts["level"] if opts.has("level") else LevelData.load_file("res://levels/%s.txt" % id)
	game.reset()
	var h: Dictionary = game.new_hero(str(opts.get("calling", "knight")))
	h["level"] = int(opts.get("hero_level", 8))
	game.data["difficulty"] = str(opts.get("diff", "dusk"))
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = bool(opts.get("no_monsters", false))
	if opts.has("resume"):
		w.resume = opts["resume"]
	w.paused = true
	root.add_child(w)
	return w


func _stub_hud() -> CanvasLayer:
	var g := GDScript.new()
	g.source_code = STUB_HUD
	g.reload()
	return g.new()


func _ticks(w: Node2D, seconds: float, pad := {}) -> void:
	for i in int(round(seconds / DT)):
		if _keep_alive and w.player.alive:
			w.player.hp = w.player.max_hp   # (a fall into the hold's pit takes a share, invulnerable or not)
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _until(w: Node2D, cond: Callable, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		if cond.call():
			return
		_ticks(w, DT)


func _done(w: Node2D) -> void:
	if w.hud != null and not w.hud.is_inside_tree():
		w.hud.free()
		w.hud = null
	w.queue_free()
	await process_frame


static func _kill(e: Node2D) -> void:
	if e != null and is_instance_valid(e) and e.alive:
		e.hp = 0.0
		e._kill({"how": "slash", "from_x": e.position.x - 20.0})


static func _clear(m: Object, r: Dictionary) -> void:
	## Every foe holding the room's doors down, at once (a Twinned one's
	## halves too: they split as it falls).
	for k in 4:
		for e in m.counted(r):
			_kill(e)


func _mod(w: Node2D) -> Object:
	return w.features.module("sealed") if w.features != null else null


func _altar_at(w: Node2D, x: int) -> Dictionary:
	for a in w.altars:
		if (a["cell"] as Vector2i).x == x:
			return a
	return {}


func _all(w: Node2D, cells: Array, t: int) -> bool:
	return not cells.is_empty() and cells.all(func(c): return w.level.tile(c.x, c.y) == t)


static func _floor(x: float, row := 13) -> Vector2:
	## Feet on the top of `row` at tile column x.
	return Vector2(x * TILE, row * TILE)


func _seal(w: Node2D, r: Dictionary, at: Vector2) -> void:
	## Into the room and through its tell: shut.
	w.player.reset_at(at)
	_until(w, func(): return r["phase"] == "fight", Sealed.SEAL_TELL + 0.3)


func _dropped(w: Node2D, r: Dictionary) -> void:
	## Every drop-in landed (in the World's list).
	_until(w, func(): return (r["drops"] as Array).is_empty(), 3.0)


# ---------------------------------------------------------------- the header

func _test_parse() -> void:
	var specs: Array = Sealed.parse("duel 98-109 rows 3-7; ambush 200-229 ; hold 300-327 @12.5; hold 400-430;"
			+ " duel 500-530 foe 515,12; brawl 1-20; ambush 60-50; duel 70-72; ambush x-y")
	_check(specs.size() == 5, "the header reads its five good rooms and leaves out the rest (%d)" % specs.size())
	if specs.size() != 5:
		return
	var a: Dictionary = specs[0]
	_check(a["kind"] == "duel" and a["x0"] == 98 and a["x1"] == 109 and a["rows"] == [3, 7] and float(a["secs"]) == 0.0,
			"a duel with rows: %s" % [a])
	_check(specs[1]["kind"] == "ambush" and specs[1]["x0"] == 200 and specs[1]["x1"] == 229 and (specs[1]["rows"] as Array).is_empty(),
			"a full-height ambush: %s" % [specs[1]])
	_check(specs[2]["kind"] == "hold" and absf(float(specs[2]["secs"]) - 12.5) < 0.001, "a hold's clock (@12.5): %s" % [specs[2]["secs"]])
	_check(absf(float(specs[3]["secs"]) - Sealed.HOLD_SECS) < 0.001, "a hold without one keeps %.0f s (5-3's)" % Sealed.HOLD_SECS)
	_check(specs[4]["foe"] == Vector2i(515, 12), "a duel's named foe by its cell: %s" % [specs[4]["foe"]])


func _test_rules() -> void:
	## Every level file with rooms: a monster in each, a way in at an end, an
	## altar within ALTAR_REACH tiles before its door. Only the lab has any yet.
	var with_rooms := []
	for f in DirAccess.get_files_at("res://levels"):
		if not f.ends_with(".txt"):
			continue
		var lv = LevelData.load_file("res://levels/" + f)
		var raw := str(lv.headers.get("room", ""))
		if raw == "":
			continue
		with_rooms.append(str(lv.id))
		var altars: Array = lv.entities.filter(func(e): return e["kind"] == "altar").map(func(e): return (e["cell"] as Vector2i).x)
		for spec in Sealed.parse(raw):
			var x0: int = spec["x0"]
			var x1: int = spec["x1"]
			var rows: Array = spec["rows"]
			var y0: int = 0 if rows.is_empty() else int(rows[0])
			var y1: int = lv.height - 1 if rows.is_empty() else int(rows[1])
			var monsters: Array = []
			for e in lv.entities:
				var c: Vector2i = e["cell"]
				if _is_monster(str(e["kind"])) and c.x >= x0 and c.x <= x1 and c.y >= y0 and c.y <= y1:
					monsters.append(e)
			_check(not monsters.is_empty(), "%s: the %s at %d-%d holds a monster" % [lv.id, spec["kind"], x0, x1])
			var door := 0
			for x in [x0, x1]:
				for y in (range(0, lv.height - 1) if rows.is_empty() else range(y0 + 1, y1)):
					if lv.tile(x, y) == LevelData.AIR:
						door += 1
			_check(door > 0, "%s: the %s at %d-%d has a way in" % [lv.id, spec["kind"], x0, x1])
			_check(altars.any(func(ax): return ax >= x0 - Sealed.ALTAR_REACH and ax < x0),
					"%s: an altar within %d tiles before the %s at %d (altars %s)" % [lv.id, Sealed.ALTAR_REACH, spec["kind"], x0, altars])
	_check(with_rooms == [LAB], "only the lab has rooms yet (the levels' come with their redesigns): %s" % [with_rooms])


static func _is_monster(kind: String) -> bool:
	return kind == "dread" or EnemyKinds.known(kind)


func _test_absent() -> void:
	## No header, nothing changes: a level's monsters stay in the World's
	## list, seen, and in its spawns.
	for id in ["1-3", "3-3", "4-3", "5-3", "6-3"]:
		var w := _world(id)
		await process_frame
		var n0: int = w.enemies.size()
		var s0: int = w.spawns.size()
		_ticks(w, 0.3)
		var m = _mod(w)
		_check(m != null and m.rooms.is_empty(), "%s: no rooms" % id)
		_check(n0 > 0 and w.enemies.size() == n0 and w.spawns.size() == s0 and w.enemies.all(func(e): return e.visible),
				"%s: every monster still in play (%d of %d), its spawns kept (%d of %d)" % [id, w.enemies.size(), n0, w.spawns.size(), s0])
		await _done(w)


# ---------------------------------------------------------------- the duel

func _test_duel() -> void:
	var w := _world(LAB)
	await process_frame
	var hud := _stub_hud()
	w.hud = hud
	var m = _mod(w)
	_check(m != null and m.rooms.size() == 4, "the lab's four rooms (%d)" % (m.rooms.size() if m else -1))
	if m == null or m.rooms.size() != 4:
		await _done(w)
		return
	var r: Dictionary = m.rooms[0]
	var foe: Node2D = r["named"]
	var foe_id := foe.get_instance_id() if foe != null else 0
	_check(r["kind"] == "duel" and r["phase"] == "wait" and foe != null and foe.tier == "dread" and foe.elite_name == "The Gaoler",
			"the duel waits, its named foe the Gaoler (%s)" % [r["phase"]])
	_check(foe != null and not w.enemies.has(foe) and not foe.active and foe.visible and foe.modulate.r < 0.6,
			"asleep at his post: out of the World's list, dim")
	var door: Array = r["door"]
	_check(door.size() == 6 and _all(w, door, LevelData.AIR), "both doorways open (%d cells)" % door.size())
	_check(not w.spawns.any(func(sp): return (sp["cell"] as Vector2i).x >= 24 and (sp["cell"] as Vector2i).x <= 49),
			"its cells out of the World's spawns")
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	var alt := _altar_at(w, 20)
	pl.reset_at(alt["pos"])
	_ticks(w, 1.0)
	_check(bool(alt["lit"]) and r["phase"] == "wait" and _all(w, door, LevelData.AIR), "at the door altar, the doors stay open")
	# In, then out again during the tell: they stay open.
	pl.reset_at(_floor(30.5))
	_ticks(w, 2 * DT)
	_check(r["phase"] == "closing" and _all(w, door, LevelData.AIR), "in: the doors start to grind (%s), still open" % r["phase"])
	_ticks(w, 0.2)
	pl.reset_at(alt["pos"])
	_ticks(w, Sealed.SEAL_TELL)
	_check(r["phase"] == "wait" and _all(w, door, LevelData.AIR) and not w.enemies.has(foe), "out again in time: they stay open, he sleeps on")
	# In for good: the tell, then stone at both ends.
	pl.reset_at(_floor(30.5))
	_ticks(w, 0.45)
	_check(r["phase"] == "closing" and _all(w, door, LevelData.AIR), "0.45 s in, the doors still grinding (the tell is %.1f s)" % Sealed.SEAL_TELL)
	_until(w, func(): return r["phase"] == "fight", 0.3)
	var sealed: Array = r["sealed"]
	_check(r["phase"] == "fight" and sealed.size() == 6 and _all(w, sealed, LevelData.STONE), "then shut at both ends (%d cells)" % sealed.size())
	_check(w.enemies.has(foe) and foe.active and foe.modulate == Color.WHITE, "and the Gaoler wakes")
	var cards: Array = hud.said.filter(func(x): return x[0] == "title_card")
	_check(not cards.is_empty() and str(cards[0][1]) == "Dread" and str(cards[0][2]) == "The Gaoler", "his title card: %s" % [cards])
	var bar = hud.bars().back() if not hud.bars().is_empty() else {}
	_check(bar is Dictionary and str(bar.get("name", "")) == "The Gaoler" and str(bar.get("title", "")) == "Dread · Swift"
			and absf(float(bar.get("frac", 0.0)) - 1.0) < 0.01, "his bar: name, tier and Omen, life (%s)" % [bar])
	_check(not hud.said.any(func(x): return x[0] == "elite_seen" and x[1] == foe), "no elite plate as well (the bar names him)")
	# Hurt him, then a snuff: the room opens and starts over.
	foe.hp = foe.max_hp * 0.4
	_ticks(w, 2 * DT)
	bar = hud.bars().back()
	_check(absf(float(bar.get("frac", 0.0)) - 0.4) < 0.02, "the bar follows his life (%.2f)" % float(bar.get("frac", 0.0)))
	pl.invuln = 0.0
	w.hurt_player(99999.0, pl.position.x + 20.0, "lava")
	_ticks(w, 2.0)
	var fresh: Node2D = r["named"]
	_check(pl.alive and r["phase"] == "wait" and int(r["resets"]) == 1 and (r["sealed"] as Array).is_empty() and _all(w, door, LevelData.AIR),
			"a snuff inside opens it and starts it over (%s, resets %d)" % [r["phase"], r["resets"]])
	_check(fresh != null and fresh.get_instance_id() != foe_id and fresh.alive and absf(fresh.hp - fresh.max_hp) < 0.01 and fresh.tier == "dread"
			and fresh.elite_name == "The Gaoler" and not fresh.respawned, "a fresh Gaoler at full life")
	_check(fresh != null and not w.enemies.has(fresh) and not fresh.active and not w.enemies.any(func(e): return e.get_instance_id() == foe_id and e.alive and not e.gone),
			"asleep at his post again (the old one gone)")
	_check(absf(pl.position.x - float(alt["pos"].x)) < 40.0, "Wick relights at the door altar")
	_check(hud.bars().back() is Dictionary and (hud.bars().back() as Dictionary).is_empty(), "the bar is down")
	# Again, and this time he falls.
	pl.invuln = 1000.0
	_seal(w, r, _floor(30.5))
	_check(r["phase"] == "fight" and w.enemies.has(fresh), "shut again, he wakes again")
	hud.said.clear()
	_kill(fresh)
	_until(w, func(): return r["phase"] == "won", 1.0)
	_check(r["phase"] == "won" and r["won"] == "clear" and _all(w, door, LevelData.AIR), "his fall opens the doors (%s)" % r["phase"])
	var toasts: Array = hud.said.filter(func(x): return x[0] == "toast")
	_check(not toasts.is_empty() and str(toasts[0][1]) == "Duel won" and str(toasts[0][2]) == "The Gaoler", "a toast: %s" % [toasts])
	_check(hud.bars().back() is Dictionary and (hud.bars().back() as Dictionary).is_empty(), "and the bar goes")
	# Won, it stays open.
	pl.reset_at(_floor(30.5))
	_ticks(w, 1.0)
	_check(r["phase"] == "won" and _all(w, door, LevelData.AIR), "back in a won room: it stays open")
	await _done(w)


# ---------------------------------------------------------------- the ambush

func _story_lab() -> RefCounted:
	## The lab as a World 3 story level (loot kept; Dusk respawns monsters
	## after a snuff from World 3).
	var lv = LevelData.load_file("res://levels/%s.txt" % LAB)
	lv.id = "3-9"
	lv.world = 3
	return lv


func _test_ambush() -> void:
	var w := _world("", {"level": _story_lab()})
	await process_frame
	var hud := _stub_hud()
	w.hud = hud
	var m = _mod(w)
	var r: Dictionary = m.rooms[1]
	var specs: Array = r["specs"]
	_check(r["kind"] == "ambush" and specs.size() == 5 and r["named"] == null, "the ambush's five (%d)" % specs.size())
	_check(specs.all(func(s): return not s["node"].visible and not w.enemies.has(s["node"])), "hidden till the doors shut, out of reach")
	_check(w.respawns_here(), "(Dusk from World 3: the World respawns its monsters after a snuff)")
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	var alt := _altar_at(w, 55)
	pl.reset_at(alt["pos"])
	_ticks(w, 0.5)
	_seal(w, r, _floor(70.5))
	_check(r["phase"] == "fight" and _all(w, r["sealed"], LevelData.STONE) and (r["sealed"] as Array).size() == 6, "in: shut")
	_check(m.foes_left(r) == 5 and specs.all(func(s): return not w.enemies.has(s["node"])), "none in reach the moment they shut")
	var bar: Dictionary = m.bar_info(r)
	_check(str(bar["name"]) == "Ambush · 5" and absf(float(bar["frac"]) - 1.0) < 0.01, "'Ambush · 5' (%s)" % [bar])
	_ticks(w, Sealed.DROP_FIRST + 0.05)
	var shown: Array = specs.filter(func(s): return s["node"].visible)
	_check(shown.size() == 1 and not w.enemies.has(shown[0]["node"]) and shown[0]["node"].modulate.a < 1.0,
			"they drop in one by one, each out of reach till it has (%d showing)" % shown.size())
	_dropped(w, r)
	_check(specs.all(func(s): return w.enemies.has(s["node"]) and s["node"].visible and s["node"].modulate.a >= 0.999), "all five dropped in")
	var first: Node2D = specs[0]["node"]
	var ent := int(specs[0]["ent"])
	_kill(first)
	_ticks(w, 2 * DT)
	_check(m.foes_left(r) == 4 and str(m.bar_info(r)["name"]) == "Ambush · 4", "one down: 'Ambush · 4' (%s)" % m.bar_info(r)["name"])
	_check(ent >= 0 and w._killed.has(ent), "(its kill on the altar snapshot's list)")
	# A snuff mid-fight: all of them back, hidden; the one put out as a respawn.
	pl.invuln = 0.0
	w.hurt_player(99999.0, pl.position.x + 20.0, "lava")
	_ticks(w, 2.0)
	_check(r["phase"] == "wait" and int(r["resets"]) == 1 and _all(w, r["door"], LevelData.AIR), "a snuff opens it and starts it over")
	_check(specs.all(func(s): return s["node"] != null and s["node"].alive and not s["node"].visible and not w.enemies.has(s["node"])),
			"all five back, hidden again")
	_check(bool(specs[0]["node"].respawned) and not specs.slice(1).any(func(s): return bool(s["node"].respawned)),
			"the one put out comes back as a respawn, the rest as they were")
	_check(not w._killed.has(ent), "and off the snapshot's killed list")
	# Again: every one down, the doors open, the reward.
	pl.invuln = 1000.0
	_seal(w, r, _floor(70.5))
	_dropped(w, r)
	hud.said.clear()
	_clear(m, r)
	var items0: int = w.pickups.filter(func(p): return p["kind"] == "item").size()   # (after their own drops)
	_until(w, func(): return r["phase"] == "won", 1.0)
	_check(r["phase"] == "won" and r["won"] == "clear" and _all(w, r["door"], LevelData.AIR), "the last one down opens the doors")
	var toasts: Array = hud.said.filter(func(x): return x[0] == "toast")
	_check(not toasts.is_empty() and str(toasts[0][1]) == "Ambush beaten", "a toast: %s" % [toasts])
	var items1: int = w.pickups.filter(func(p): return p["kind"] == "item").size()
	_check(items1 > items0, "and a reward item (%d -> %d)" % [items0, items1])
	# Snuffed after, beyond it: the World's respawns never refill it.
	pl.reset_at(_floor(92.5))
	_ticks(w, 0.3)
	pl.invuln = 0.0
	w.hurt_player(99999.0, pl.position.x + 20.0, "lava")
	_ticks(w, 2.0)
	var back: Array = w.enemies.filter(func(e): return e.alive and (r["cells"] as Dictionary).has(e.spawn.get("cell", Vector2i(-9, -9))))
	_check(pl.alive and back.is_empty() and r["phase"] == "won", "a snuff afterwards never refills it (%d back)" % back.size())
	await _done(w)


# ---------------------------------------------------------------- the hold

func _test_hold() -> void:
	var w := _world(LAB)
	await process_frame
	var hud := _stub_hud()
	w.hud = hud
	var m = _mod(w)
	var r: Dictionary = m.rooms[2]
	_keep_alive = true
	_check(r["kind"] == "hold" and absf(float(r["secs"]) - 20.0) < 0.01 and (r["specs"] as Array).size() == 4, "the hold: 20 s, four foes")
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	pl.reset_at(_altar_at(w, 95)["pos"])
	_ticks(w, 0.3)
	_seal(w, r, _floor(106.5))
	_check(r["phase"] == "fight", "in: shut")
	var bar: Dictionary = m.bar_info(r)
	_check(str(bar["name"]) == "Hold · 0:20" and str(bar["title"]) == "4 left" and float(bar["frac"]) > 0.99, "'Hold · 0:20', '4 left' (%s)" % [bar])
	_dropped(w, r)
	_ticks(w, 9.0)
	bar = m.bar_info(r)
	_check(r["phase"] == "fight" and str(bar["name"]).begins_with("Hold · 0:1") and float(bar["frac"]) < 0.55, "it runs down (%s)" % bar["name"])
	_until(w, func(): return r["phase"] != "fight", 12.0)
	var up: int = m.counted(r).size()
	_check(r["phase"] == "won" and r["won"] == "time" and _all(w, r["door"], LevelData.AIR) and up > 0,
			"at 20 s the doors open with foes still up (%d)" % up)
	_check(absf(float(r["won_at"]) - float(r["sealed_at"]) - 20.0) < 0.1, "at 20 s (%.2f)" % (float(r["won_at"]) - float(r["sealed_at"])))
	var toasts: Array = hud.said.filter(func(x): return x[0] == "toast")
	_check(not toasts.is_empty() and str(toasts.back()[1]) == "Held", "a toast: %s" % [toasts])
	_keep_alive = false
	await _done(w)


func _test_hold_cleared() -> void:
	var w := _world(LAB)
	await process_frame
	var m = _mod(w)
	var r: Dictionary = m.rooms[2]
	w.player.invuln = 1000.0
	_seal(w, r, _floor(106.5))
	_dropped(w, r)
	_clear(m, r)
	_until(w, func(): return r["phase"] == "won", 1.0)
	_check(r["phase"] == "won" and r["won"] == "clear" and float(r["won_at"]) - float(r["sealed_at"]) < 5.0,
			"all down sooner: the doors open then (%.1f s)" % (float(r["won_at"]) - float(r["sealed_at"])))
	await _done(w)


func _test_pit() -> void:
	## A foe knocked into the hold's pit falls out of the level, alive (v2's
	## walkers do): the room puts it out, a pit kill, and the doors open once
	## the rest are down.
	var w := _world(LAB)
	await process_frame
	var m = _mod(w)
	var r: Dictionary = m.rooms[2]
	var hows := []
	w.enemy_killed.connect(func(e, how): hows.append([e, how]))
	w.player.invuln = 1000.0
	_seal(w, r, _floor(106.5))
	_dropped(w, r)
	var rattle: Node2D = null
	for s in r["specs"]:
		if s["cell"] == Vector2i(114, 12):
			rattle = s["node"]
	_check(rattle != null and rattle.kind == "skeleton", "the Rattle by the pit")
	if rattle == null:
		await _done(w)
		return
	var left0: int = m.foes_left(r)
	rattle.position = Vector2(116.0 * TILE, 12.0 * TILE)
	rattle.velocity = Vector2(0, 200)
	rattle.active = true
	_until(w, func(): return not rattle.alive, 3.0)
	_check(not rattle.alive and hows.any(func(x): return x[0] == rattle and x[1] == "pit"), "knocked into the pit, it's put out (a pit kill)")
	_check(m.foes_left(r) == left0 - 1, "and stops holding the doors (%d -> %d)" % [left0, m.foes_left(r)])
	_clear(m, r)
	_until(w, func(): return r["phase"] == "won", 1.0)
	_check(r["phase"] == "won" and _all(w, r["door"], LevelData.AIR), "the rest down: open (no soft-lock)")
	await _done(w)


func _test_twinned() -> void:
	## A Twinned foe's halves hold the doors too, till they're down.
	var w := _world(LAB)
	await process_frame
	var m = _mod(w)
	var r: Dictionary = m.rooms[1]
	var twin: Node2D = r["specs"][0]["node"]
	twin.make_elite("anointed", ["Twinned"])
	w.player.invuln = 1000.0
	_seal(w, r, _floor(70.5))
	_dropped(w, r)
	var n0: int = m.foes_left(r)
	_kill(twin)
	_ticks(w, 2 * DT)
	_check(n0 == 5 and m.foes_left(r) == 6 and r["phase"] == "fight", "a Twinned one falls into two halves: 'Ambush · 6' (%d -> %d)" % [n0, m.foes_left(r)])
	for e in m.counted(r):
		if not bool(e.get("copy")):
			_kill(e)
	_ticks(w, 2 * DT)
	var halves: int = m.counted(r).filter(func(e): return bool(e.get("copy"))).size()
	_check(r["phase"] == "fight" and halves >= 2 and m.foes_left(r) == halves,
			"the rest down, the halves still hold the doors (%d of %d)" % [halves, m.foes_left(r)])
	_clear(m, r)
	_until(w, func(): return r["phase"] == "won", 1.0)
	_check(r["phase"] == "won", "and the halves down open them")
	await _done(w)


# ---------------------------------------------------------------- the loft

func _test_loft() -> void:
	var w := _world(LAB)
	await process_frame
	var m = _mod(w)
	var r: Dictionary = m.rooms[3]
	_check(r["kind"] == "duel" and not r["full"] and r["door"] == [Vector2i(140, 5), Vector2i(140, 6)],
			"the loft's only doorway is its gap (%s)" % [r["door"]])
	var foe: Node2D = r["named"]
	_check(foe != null and foe.kind == "thornback" and not w.enemies.has(foe), "its Thornback asleep up there")
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	pl.reset_at(_altar_at(w, 133)["pos"])
	_ticks(w, 0.3)
	# Under it, along the floor, right across: nothing.
	for x in [141.5, 145.5, 150.5]:
		pl.reset_at(_floor(x))
		_ticks(w, 0.5)
	_check(r["phase"] == "wait" and _all(w, r["door"], LevelData.AIR) and not w.enemies.has(foe), "walk under it: it never seals")
	# Climbed in: the gap shuts.
	_seal(w, r, _floor(146.5, 7))
	_check(r["phase"] == "fight" and (r["sealed"] as Array).size() == 2 and _all(w, r["sealed"], LevelData.STONE) and w.enemies.has(foe) and foe.active,
			"climb in: the gap shuts and it wakes (%s)" % r["phase"])
	_kill(foe)
	_until(w, func(): return r["phase"] == "won", 1.0)
	_check(r["phase"] == "won" and _all(w, r["door"], LevelData.AIR), "down: the gap opens")
	await _done(w)


# ---------------------------------------------------------------- no monsters, a resume

func _test_no_monsters() -> void:
	var w := _world(LAB, {"no_monsters": true})
	await process_frame
	var m = _mod(w)
	_check(m.rooms.all(func(r): return r["phase"] == "won" and r["won"] == "empty"), "no monsters: every room open for good")
	w.player.invuln = 1000.0
	for at in [_floor(30.5), _floor(70.5), _floor(106.5), _floor(146.5, 7)]:
		w.player.reset_at(at)
		_ticks(w, 1.0)
	_check(m.rooms.all(func(r): return r["phase"] == "won" and _all(w, r["door"], LevelData.AIR)), "walked into each: none seals")
	await _done(w)


func _test_resume() -> void:
	## Continue from the altar after the duel: the Gaoler stayed put out (the
	## snapshot's killed list), so his room is open for good.
	var lv = LevelData.load_file("res://levels/%s.txt" % LAB)
	var ei := -1
	for i in lv.entities.size():
		if lv.entities[i]["kind"] == "dread":
			ei = i
	var w := _world(LAB, {"level": lv, "resume": {"level": LAB, "diff": "dusk", "altar": 1, "killed": [ei], "taken": [], "sigils": [false, false, false]}})
	await process_frame
	var m = _mod(w)
	_check(ei >= 0 and m.rooms[0]["phase"] == "won" and m.rooms[0]["won"] == "empty" and m.rooms[1]["phase"] == "wait",
			"resumed past the duel: it stays open, the ambush waits (%s, %s)" % [m.rooms[0]["phase"], m.rooms[1]["phase"]])
	w.player.invuln = 1000.0
	w.player.reset_at(_floor(30.5))
	_ticks(w, 1.0)
	_check(_all(w, m.rooms[0]["door"], LevelData.AIR), "and never seals")
	await _done(w)


# ---------------------------------------------------------------- the bot

func _test_bot() -> void:
	## The --autoplay bot on the lab (a hero at level 8, never snuffed): every
	## room it walks into shut, won and opened, and the bell rung; it walks
	## under the loft.
	var w := _world(LAB)
	await process_frame
	var m = _mod(w)
	var bot = AutoBot.new()
	w.autoplay = true
	bot.setup(w)
	var pl: Node2D = w.player
	var shut := {}
	var t := 0.0
	var n := 0
	while t < 240.0 and w.state == "play":
		t += DT
		n += 1
		pl.invuln = 5.0
		pl.hp = pl.max_hp
		w.test_pad = bot.pad(DT)
		w._read_pad()
		w.tick(DT)
		for i in m.rooms.size():
			if m.rooms[i]["phase"] == "fight":
				shut[i] = true
		if n % 2400 == 0:
			await process_frame
	var ph: Array = m.rooms.map(func(r): return "%s/%s" % [r["phase"], r["won"]])
	_check(shut.has(0) and shut.has(1) and shut.has(2), "the bot walks into the duel, the ambush and the hold and they shut (%s)" % [shut.keys()])
	_check(m.rooms[0]["won"] == "clear" and m.rooms[1]["won"] == "clear" and m.rooms[2]["phase"] == "won", "and wins each (%s)" % [ph])
	_check(m.rooms[3]["phase"] == "wait", "it walks under the loft (%s)" % m.rooms[3]["phase"])
	_check(w.state == "clear", "and rings the bell (%s after %.0f s)" % [w.state, t])
	await _done(w)


func _test_warden_target() -> void:
	## secrets.gd's Warden is the bot's foe only while its room is shut.
	var w := _world("1-S")
	await process_frame
	var sm = w.features.module("secrets")
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	_check(sm.bot_target(pl) == null, "1-S: no foe before its Warden's fight")
	var room: Dictionary = sm.room
	var x0 := int(float(room["left"]) / TILE)
	var spot := Vector2.ZERO
	for x in range(x0 + 1, x0 + 12):
		for y in range(2, w.level.height):
			if LevelData.is_solid(w.level.tile(x, y)) and not LevelData.is_solid(w.level.tile(x, y - 1)):
				spot = Vector2((x + 0.5) * TILE, y * TILE)
				break
		if spot != Vector2.ZERO:
			break
	pl.reset_at(spot)
	_ticks(w, 4 * DT)
	_check(sm.phase == "fight" and sm.bot_target(pl) == sm.warden and sm.warden != null, "1-S: its Warden, once its room is shut (%s)" % sm.phase)
	await _done(w)
