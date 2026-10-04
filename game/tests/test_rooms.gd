extends SceneTree
## Build 2's sealed fight rooms (scripts/features/sealed.gd and its header
## `room:`; tools/levels/common.py rooms_header and check_rooms; the lab,
## tools/levels/lab_rooms.py's lab-rooms):
## - the header reads (its kinds, columns, rows, a clock, a named foe; a part
##   that doesn't read is left out), and no level on the path or a secret one
##   has a room but the re-cut levels' (ROOM_LEVELS: 1-3's loft, played in
##   _test_loft_13; the X-3s' big fight rooms, played in their test_wN.gd):
##   the others' Worlds keep every monster in play and in spawns;
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
## - the drop-ins: farthest from him first, never one within DROP_CLEAR px
##   of him (it waits while he stands by its post, and drops once he steps
##   off), the bot waiting clear of every post still to drop;
## - a room's tiered foe put out and brought back by a snuff's reset pays
##   its tier's drops once: the Anointed's item, the Dread's two, the first
##   kill only (no farm);
## - a hold: 'Hold · 0:20' runs down (a clock: gold, no trail) and the doors
##   open at 20 s with foes still up, or sooner once they're all down;
## - a foe knocked into the hold's pit is put out (a pit kill): the doors
##   never stay shut for good; a Twinned one's halves hold them till they fall;
## - the loft: walk under it and it never seals; climb in and only its gap
##   shuts;
## - no monsters (the golden routes): every room open for good; an altar
##   resume with a room's monsters killed: that room open for good;
## - the --autoplay bot clears every room it walks into on the lab and rings
##   its bell (walking under the loft); secrets.gd's Warden is its foe only
##   in its sealed fight;
## - every level file with rooms (tests/level_rules.gd room_problems): a
##   monster in each, a way in, doorways of air or stone that never opens
##   (water, a vine, a ledge or brick there is caught), no monster within
##   DOOR_CLEAR columns of a door, and an altar within ALTAR_REACH tiles
##   before each door;
## - with the other Build 2 streams: a forced Anointed (anoint:) on a room's
##   cell keeps its tier, Omens and name asleep or hidden, is the loft's
##   named foe, and comes back as it was after a snuff's reset; in a restless
##   level (twist: restless_all) a stomped foe's remains hold the doors till
##   they stand again (the room's foe once more) or a swing lays them to
##   rest, and the bot still clears every room.
##
##     godot --headless --path game --script res://tests/test_rooms.gd

const LevelData := preload("res://scripts/level_data.gd")
const Sealed := preload("res://scripts/features/sealed.gd")
const AutoBot := preload("res://scripts/autoplay_bot.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const Twists := preload("res://scripts/twists.gd")
const Rules := preload("res://tests/level_rules.gd")
const TILE := 32
const DT := 1.0 / 120.0
const LAB := "lab-rooms"
# The levels on the path that have rooms since their redesigns (they declare
# their roles:): 1-3's Barbs' Loft, 3-3's Clearing ambush, 4-3's Grindstone
# duel (test_w4.gd plays it), 5-3's Hold the Glass, 6-3's drowned nave.
const ROOM_LEVELS := ["1-3", "3-3", "4-3", "5-3", "6-3"]
const AMBUSH_AT := 66.0          # where he seals the ambush (62-89): clear of its posts (69, 75, 80, 83)
const HOLD_AT := 104.5           # and the hold (102-127): its posts 108, 111, 114, 122
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
	await _test_drops()
	await _test_tier_loot()
	await _test_hold()
	await _test_hold_cleared()
	await _test_pit()
	await _test_twinned()
	await _test_loft()
	await _test_loft_13()
	await _test_no_monsters()
	await _test_resume()
	await _test_bot()
	await _test_forced_anoint()
	await _test_restless()
	await _test_bot("restless_all")
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
	## Every drop-in landed (in the World's list): one off the glass waits
	## DROP_WAIT past its turn at most.
	_until(w, func(): return (r["drops"] as Array).is_empty(), Sealed.DROP_WAIT + 2.0)


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
	## Every level file with rooms keeps the rooms' rules (level_rules.gd
	## room_problems, common.py check_rooms as it writes): a monster in each,
	## a way in at an end, doorways of air or stone that never opens, no
	## monster within DOOR_CLEAR columns of a door, an altar within
	## ALTAR_REACH tiles before its door. Labs have them (this one;
	## lab-shapes and lab-mirror's, each met by its right door, and
	## lab-shape-mirror's and lab-shape-decks', test_shaped.gd's: Build 2's
	## shapes), and the levels re-cut by Build 2's redesign (they declare
	## their roles:): 1-3's Barbs' Loft, the X-3s' fight rooms.
	var with_rooms := []
	var stray := []
	for f in DirAccess.get_files_at("res://levels"):
		if not f.ends_with(".txt"):
			continue
		var lv = LevelData.load_file("res://levels/" + f)
		if str(lv.headers.get("room", "")) == "":
			continue
		with_rooms.append(str(lv.id))
		if not str(lv.id).begins_with("lab-") and not lv.headers.has("roles"):
			stray.append(str(lv.id))
		var rp := Rules.room_problems(lv)
		_check(rp.is_empty(), "%s: its rooms keep their rules %s" % [lv.id, rp])
	var mine := with_rooms.filter(func(id): return not str(id).begins_with("lab-"))
	mine.sort()
	_check(with_rooms.has(LAB) and stray.is_empty() and mine == ROOM_LEVELS,
			"only labs and the re-cut levels (they declare their roles:) have rooms, ROOM_LEVELS' exactly: %s (not: %s)" % [with_rooms, stray])
	# What the rules catch, on the lab's ambush (62-89, its doorways rows
	# 10-12 at each end): water, a vine or a ledge in a doorway (a body passes
	# under the slab), brick (it breaks), a monster by the door.
	var cases := {"water": [Vector2i(62, 11), LevelData.WATER], "vine": [Vector2i(89, 10), LevelData.VINE],
			"ledge": [Vector2i(62, 10), LevelData.LEDGE], "brick": [Vector2i(89, 5), LevelData.BRICK]}
	for what in cases:
		var lv = LevelData.load_file("res://levels/%s.txt" % LAB)
		var c: Vector2i = cases[what][0]
		lv.set_tile(c.x, c.y, int(cases[what][1]))
		_check(Rules.room_problems(lv).any(func(p): return str(p).contains("doorway cell %d,%d" % [c.x, c.y])),
				"a doorway of %s is caught (%s)" % [what, Rules.room_problems(lv)])
	var near = LevelData.load_file("res://levels/%s.txt" % LAB)
	near.entities.append({"kind": "skeleton", "cell": Vector2i(64, 12)})
	_check(Rules.room_problems(near).any(func(p): return str(p).contains("within %d columns" % Sealed.DOOR_CLEAR)),
			"a monster within %d columns of a door is caught" % Sealed.DOOR_CLEAR)


func _test_absent() -> void:
	## No header, nothing changes: a level's monsters stay in the World's
	## list, seen, and in its spawns: the X-3s and 1-3 without a room:
	## header, then the X-1s (a re-cut level's room is the rooms' own:
	## _test_loft_13 and the X-3s' fight rooms).
	var ids := ["1-3", "3-3", "4-3", "5-3", "6-3", "3-1", "4-1", "5-1", "6-1"].filter(func(id):
			return str(LevelData.load_file("res://levels/%s.txt" % id).headers.get("room", "")) == "")
	for id in ids.slice(0, 5):
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
	_seal(w, r, _floor(AMBUSH_AT))
	_check(r["phase"] == "fight" and _all(w, r["sealed"], LevelData.STONE) and (r["sealed"] as Array).size() == 6, "in: shut")
	_check(m.foes_left(r) == 5 and specs.all(func(s): return not w.enemies.has(s["node"])), "none in reach the moment they shut")
	var bar: Dictionary = m.bar_info(r)
	_check(str(bar["name"]) == "Ambush · 5" and absf(float(bar["frac"]) - 1.0) < 0.01, "'Ambush · 5' (%s)" % [bar])
	_until(w, func(): return specs.any(func(s): return s["node"].visible), Sealed.DROP_WAIT + 1.0)
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
	_seal(w, r, _floor(AMBUSH_AT))
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


# ---------------------------------------------------------------- the drop-ins

func _test_drops() -> void:
	## The ambush's drop-ins: farthest from him first; none within
	## DROP_CLEAR px of him as it shows (it waits while he stands by its
	## post, the others coming on); stepping off lets it drop; the bot waits
	## clear of every post still to drop.
	var w := _world(LAB)
	await process_frame
	var m = _mod(w)
	var r: Dictionary = m.rooms[1]
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	_keep_alive = true
	_seal(w, r, _floor(AMBUSH_AT))
	var order: Array = (r["drops"] as Array).map(func(d): return absf((d["en"] as Node2D).position.x - pl.position.x))
	var falls := true
	for i in range(1, order.size()):
		falls = falls and float(order[i]) <= float(order[i - 1]) + 0.01
	_check(order.size() == 5 and falls, "they drop farthest from him first (%s)" % [order])
	# He steps onto the near Rattle's post (69) before its turn: it waits.
	var near: Node2D = null
	for s in r["specs"]:
		if s["cell"] == Vector2i(69, 12):
			near = s["node"]
	pl.reset_at(_floor(69.5))
	var close := []
	for i in int((Sealed.DROP_WAIT + 2.0) / DT):
		var was: Array = (r["drops"] as Array).filter(func(d): return d["on"]).map(func(d): return d["en"])
		_ticks(w, DT)
		for d in r["drops"]:
			if d["on"] and not was.has(d["en"]) and pl.center().distance_to((d["en"] as Node2D).center()) < Sealed.DROP_CLEAR:
				close.append(d["en"].kind)
	_check(close.is_empty(), "none shows within %d px of him (%s)" % [int(Sealed.DROP_CLEAR), close])
	var waiting: Array = (r["drops"] as Array).filter(func(d): return not d["on"]).map(func(d): return d["en"])
	_check(near != null and waiting.has(near) and not near.visible and not w.enemies.has(near),
			"standing by its post, the Rattle there waits, hidden (%d waiting)" % waiting.size())
	_check(waiting.size() < 5, "while the rest come on (%d of 5 still to drop)" % waiting.size())
	var tgt = m.bot_target(pl)
	var clear := tgt is Vector2 and waiting.all(func(e): return absf((e as Node2D).center().x - (tgt as Vector2).x) >= Sealed.DROP_CLEAR + 40.0)
	_check(m.counted(r).is_empty() or clear or tgt is Node2D, "(the bot fights what's down, or waits clear of the posts)")
	for e in m.counted(r):
		_kill(e)
	_ticks(w, 2 * DT)
	tgt = m.bot_target(pl)
	_check(tgt is Vector2 and waiting.all(func(e): return absf((e as Node2D).center().x - (tgt as Vector2).x) >= Sealed.DROP_CLEAR + 40.0),
			"with only waiting drop-ins, the bot waits clear of their posts (%s)" % [tgt])
	# Off the post: it drops.
	pl.reset_at(_floor(AMBUSH_AT))
	_dropped(w, r)
	_check(near != null and near.visible and w.enemies.has(near), "stepped off, it drops in")
	_keep_alive = false
	await _done(w)


func _test_tier_loot() -> void:
	## A room's tiered foe put out, then brought back by a snuff's reset (a
	## respawn at its post, its tier and name kept), pays its tier's drops
	## the first time only: the second kill rolls as any respawn (no farm).
	## On Dusk's story levels (world.trophies()) an Anointed's are its embers
	## x5 (no item), a Dread's one Trophy.
	var lv := _story_lab()
	var amb_c := _cell_of(lv, "thornback", 62, 89)
	lv.headers["anoint"] = "%d,%d:Swift:Sister Snare" % [amb_c.x, amb_c.y]   # (Swift: no halves to drop their own)
	var w := _world("", {"level": lv})
	await process_frame
	var m = _mod(w)
	var r: Dictionary = m.rooms[1]
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	_keep_alive = true
	_seal(w, r, _floor(AMBUSH_AT))
	_dropped(w, r)
	var snare: Node2D = _spec_at(r, amb_c).get("node")
	var items := func(): return w.pickups.filter(func(p): return p["kind"] == "item").size()
	var embers := func() -> int:
		var n := 0
		for p in w.pickups:
			if p["kind"] == "ember" and not p["taken"]:
				n += int(p.get("worth", w.ember_worth()))
		return n
	snare.item_chance = 0.0   # (only the tier's drop can show)
	var n0: int = items.call()
	var e0: int = embers.call()
	_kill(snare)
	_ticks(w, 2 * DT)
	var paid: int = embers.call() - e0
	_check(w.trophies() and items.call() == n0 and paid == int(snare.embers) * w.ANOINTED_EMBERS * w.ember_worth(),
			"her first kill pays the Anointed's embers x%d (+%d) and no item (%d -> %d)" % [w.ANOINTED_EMBERS, paid, n0, items.call()])
	_keep_alive = false
	pl.invuln = 0.0
	w.hurt_player(99999.0, pl.position.x + 20.0, "lava")
	_ticks(w, 2.0)
	var back: Node2D = _spec_at(r, amb_c).get("node")
	_check(back != null and back.tier == "anointed" and bool(back.respawned), "the reset brings her back Anointed, a respawn")
	pl.invuln = 1000.0
	_keep_alive = true
	_seal(w, r, _floor(AMBUSH_AT))
	_dropped(w, r)
	back.item_chance = 0.0
	var n1: int = items.call()
	var e1: int = embers.call()
	_kill(back)
	_ticks(w, 2 * DT)
	_check(not back.alive and items.call() == n1 and embers.call() == e1, "killed again, she pays nothing a second time (%d -> %d items, +%d embers)" % [n1, items.call(), embers.call() - e1])
	# A Dread brought back the same way: not his Trophy again.
	var d: Node2D = w.spawn_enemy("thornback", Vector2(70 * TILE, 13 * TILE), {"tier": "dread", "name": "The Gaoler", "respawned": true})
	d.item_chance = 0.0
	d.relic_chance = 0.0
	var n2: int = items.call()
	_kill(d)
	_ticks(w, 2 * DT)
	_check(items.call() == n2, "a Dread back as a respawn drops no Trophy again (%d -> %d)" % [n2, items.call()])
	var fresh: Node2D = w.spawn_enemy("thornback", Vector2(72 * TILE, 13 * TILE), {"tier": "dread", "name": "The Gaoler"})
	fresh.item_chance = 0.0
	fresh.relic_chance = 0.0
	var n3: int = items.call()
	_kill(fresh)
	_ticks(w, 2 * DT)
	_check(items.call() == n3 + 1, "(a fresh Dread still drops his Trophy: %d -> %d)" % [n3, items.call()])
	_keep_alive = false
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
	_seal(w, r, _floor(HOLD_AT))
	_check(r["phase"] == "fight", "in: shut")
	var bar: Dictionary = m.bar_info(r)
	_check(str(bar["name"]) == "Hold · 0:20" and str(bar["title"]) == "4 left" and float(bar["frac"]) > 0.99, "'Hold · 0:20', '4 left' (%s)" % [bar])
	_check(bool(bar.get("clock", false)) and not bool(m.bar_info(m.rooms[1]).get("clock", false)),
			"a hold's bar is a clock (the HUD draws it gold, no trail); a count's isn't")
	_dropped(w, r)
	_until(w, func(): return float(w.ftime) - float(r["sealed_at"]) >= 9.5, 12.0)
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
	_seal(w, r, _floor(HOLD_AT))
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
	_seal(w, r, _floor(HOLD_AT))
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
	_seal(w, r, _floor(AMBUSH_AT))
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


func _test_loft_13() -> void:
	## 1-3's Barbs' Loft (Build 2): a storey over the crossfire, sealed only
	## if he climbs in by its gap; Brother Barbs (the Dread) its named foe,
	## asleep up there; walk the floor under it and nothing happens.
	var lv = LevelData.load_file("res://levels/1-3.txt")
	if str(lv.headers.get("room", "")) == "":
		return
	var w := _world("1-3")
	await process_frame
	var m = _mod(w)
	_check(m != null and m.rooms.size() == 1, "1-3 has one room, the loft")
	if m == null or m.rooms.is_empty():
		await _done(w)
		return
	var r: Dictionary = m.rooms[0]
	var foe: Node2D = r["named"]
	_check(r["kind"] == "duel" and not r["full"] and not (r["door"] as Array).is_empty() and (r["door"] as Array).all(func(c): return c.x == int(r["x0"])),
			"1-3's loft: a duel up off the path, its only doorway the gap on the left (%s)" % [r["door"]])
	_check(foe != null and foe.tier == "dread" and foe.elite_name == "Brother Barbs" and not w.enemies.has(foe),
			"Brother Barbs asleep up there, the loft's foe")
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	pl.reset_at(_altar_at(w, 93)["pos"])
	_ticks(w, 0.3)
	var floor_row := int(r["y1"]) + 6
	for x in [99.5, 104.5, 108.5]:
		pl.reset_at(_floor(x, floor_row))
		_ticks(w, 0.5)
	_check(r["phase"] == "wait" and _all(w, r["door"], LevelData.AIR), "walk the crossfire under it: it never seals")
	_seal(w, r, _floor(104.5, int(r["y1"])))
	_check(r["phase"] == "fight" and _all(w, r["sealed"], LevelData.STONE) and w.enemies.has(foe) and foe.active,
			"climb in: the gap shuts and Barbs wakes (%s)" % r["phase"])
	_kill(foe)
	_until(w, func(): return r["phase"] == "won", 1.0)
	_check(r["phase"] == "won" and _all(w, r["door"], LevelData.AIR), "Barbs down: the gap opens")
	await _done(w)


# ---------------------------------------------------------------- no monsters, a resume

func _test_no_monsters() -> void:
	var w := _world(LAB, {"no_monsters": true})
	await process_frame
	var m = _mod(w)
	_check(m.rooms.all(func(r): return r["phase"] == "won" and r["won"] == "empty"), "no monsters: every room open for good")
	w.player.invuln = 1000.0
	for at in [_floor(30.5), _floor(AMBUSH_AT), _floor(HOLD_AT), _floor(146.5, 7)]:
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

func _test_bot(twist := "") -> void:
	## The --autoplay bot on the lab (a hero at level 8, never snuffed): every
	## room it walks into shut, won and opened, and the bell rung; it walks
	## under the loft. With a twist (restless_all: what it stomps may stand
	## again, its remains holding a room's doors), the same.
	var lv = LevelData.load_file("res://levels/%s.txt" % LAB)
	if twist != "":
		lv.headers["twist"] = twist
	var w := _world(LAB, {"level": lv})
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
	var tag := "" if twist == "" else " (%s)" % twist
	_check(shut.has(0) and shut.has(1) and shut.has(2), "the bot walks into the duel, the ambush and the hold and they shut%s (%s)" % [tag, shut.keys()])
	_check(m.rooms[0]["won"] == "clear" and m.rooms[1]["won"] == "clear" and m.rooms[2]["phase"] == "won", "and wins each%s (%s)" % [tag, ph])
	_check(m.rooms[3]["phase"] == "wait", "it walks under the loft%s (%s)" % [tag, m.rooms[3]["phase"]])
	_check(w.state == "clear", "and rings the bell%s (%s after %.0f s)" % [tag, w.state, t])
	await _done(w)


# ---------------------------------------------------------------- with the other streams

static func _cell_of(lv: RefCounted, kind: String, x0: int, x1: int) -> Vector2i:
	## The first placed monster of a kind between two columns.
	for e in lv.entities:
		var c: Vector2i = e["cell"]
		if str(e["kind"]) == kind and c.x >= x0 and c.x <= x1:
			return c
	return Vector2i(-1, -1)


static func _spec_at(r: Dictionary, c: Vector2i) -> Dictionary:
	for s in r["specs"]:
		if s["cell"] == c:
			return s
	return {}


func _test_forced_anoint() -> void:
	## A forced Anointed (an anoint: header: level_features.assign_elites, the
	## elites stream's) on a room's cell: anointed before the room takes its
	## monsters, so it keeps its tier, Omens and name asleep or hidden, out
	## of world.spawns; the loft (no Dread) names it its foe; a snuff's reset
	## brings it back as it was (a respawn, if it was put out).
	var lv := _story_lab()
	var loft_c := _cell_of(lv, "thornback", 128, 161)
	var amb_c := _cell_of(lv, "thornback", 62, 89)
	lv.headers["anoint"] = "%d,%d:Swift:Old Latch; %d,%d::Sister Snare" % [loft_c.x, loft_c.y, amb_c.x, amb_c.y]
	var w := _world("", {"level": lv})
	await process_frame
	var m = _mod(w)
	var amb: Dictionary = m.rooms[1]
	var loft: Dictionary = m.rooms[3]
	var ls := _spec_at(loft, loft_c)
	var as_ := _spec_at(amb, amb_c)
	_check(not ls.is_empty() and ls["tier"] == "anointed" and ls["name"] == "Old Latch" and (ls["omens"] as Array).has("Swift"),
			"the loft's Thornback is the header's Anointed, Swift and named, as the room takes it (%s)" % [ls])
	var nf = loft["named"]
	_check(nf != null and nf == ls.get("node") and not w.enemies.has(nf) and str(m.bar_info(loft)["name"]) == "Old Latch"
			and str(m.bar_info(loft)["title"]).begins_with("Anointed · Swift"), "and the loft's named foe, asleep: its bar 'Old Latch', 'Anointed · Swift...'")
	_check(not as_.is_empty() and as_["tier"] == "anointed" and as_["name"] == "Sister Snare" and not (as_["omens"] as Array).is_empty()
			and not as_["node"].visible, "the ambush's Thornback: Anointed, named, its Omens rolled, hidden (%s)" % [as_])
	_check(not w.spawns.any(func(sp): return sp["cell"] == loft_c or sp["cell"] == amb_c), "(neither in world.spawns)")
	var omens: Array = (as_["omens"] as Array).duplicate()
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	_keep_alive = true
	pl.reset_at(_altar_at(w, 55)["pos"])
	_ticks(w, 0.5)
	_seal(w, amb, _floor(AMBUSH_AT))
	_dropped(w, amb)
	var snare: Node2D = as_["node"]
	_check(w.enemies.has(snare) and snare.tier == "anointed" and snare.elite_name == "Sister Snare", "it drops in Anointed, named")
	_kill(snare)
	_ticks(w, 2 * DT)
	_keep_alive = false
	pl.invuln = 0.0
	w.hurt_player(99999.0, pl.position.x + 20.0, "lava")
	_ticks(w, 2.0)
	var back: Node2D = _spec_at(amb, amb_c).get("node")
	_check(amb["phase"] == "wait" and back != null and back != snare and back.alive and back.tier == "anointed"
			and back.elite_name == "Sister Snare" and back.omens == omens and bool(back.respawned),
			"a snuff's reset brings her back Anointed, named, her Omens kept, as a respawn (%s)" % [back.omens if back != null else []])
	await _done(w)


func _test_restless() -> void:
	## A restless level's rooms (twists.gd's restless_all on the lab): a foe
	## of the room's stomped in the fight leaves remains that hold the doors
	## (the bar counts them; the bot goes for them) till they stand again,
	## the room's foe once more, or a swing lays them to rest. Only then do
	## the doors open.
	var lv := _story_lab()
	lv.headers["twist"] = "restless_all"
	var w := _world("", {"level": lv})
	await process_frame
	var m = _mod(w)
	var tw = w.twists
	_check(tw != null and str(tw.rule) == "restless", "(the restless runtime)")
	if tw == null:
		await _done(w)
		return
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	_keep_alive = true
	# The ambush: every foe put out but a Rattle, then it's stomped.
	var r: Dictionary = m.rooms[1]
	pl.reset_at(_altar_at(w, 55)["pos"])
	_ticks(w, 0.5)
	_seal(w, r, _floor(AMBUSH_AT))
	_dropped(w, r)
	var rattles: Array = m.counted(r).filter(func(e): return str(e.kind) == "skeleton")
	rattles.sort_custom(func(a, b): return a.position.x < b.position.x)
	for e in m.counted(r):
		if e != rattles[0]:
			_kill(e)
	_ticks(w, 2 * DT)
	w.deal(rattles[0], 1.0, {"how": "stomp", "flat": 99999.0, "no_hitstop": true})
	_ticks(w, 2 * DT)
	_check(tw.remains.size() == 1 and m.counted(r).is_empty() and m.foes_left(r) == 1 and r["phase"] == "fight",
			"a stomped Rattle's remains hold the doors (%d left, %s)" % [m.foes_left(r), r["phase"]])
	_check(str(m.bar_info(r)["name"]) == "Ambush · 1", "the bar counts them (%s)" % m.bar_info(r)["name"])
	if tw.remains.size() == 1:
		var at: Vector2 = tw.remains[0]["pos"]
		var tgt = m.bot_target(pl)
		_check(tgt is Vector2 and absf((tgt as Vector2).x - at.x) < 1.0, "the bot goes for them (%s, they lie at %s)" % [tgt, at])
		var tx := at.x / TILE
		pl.reset_at(_floor(tx + 5.0 if tx < 76.0 else tx - 5.0))
		_until(w, func(): return int(tw.risen) == 1, Twists.RISE_WAIT + Twists.RISE_TELL + 2.0)
		var up: Array = m.counted(r)
		_check(int(tw.risen) == 1 and up.size() == 1 and Twists.is_risen(up[0]) and r["phase"] == "fight",
				"it stands again, the room's foe, the doors still shut (%d up, %s)" % [up.size(), r["phase"]])
		for e in up:
			_kill(e)
	_until(w, func(): return r["phase"] == "won", 1.0)
	_check(r["phase"] == "won" and r["won"] == "clear" and tw.remains.is_empty(), "put out again (it never rises twice), the doors open (%s/%s)" % [r["phase"], r["won"]])
	# The hold: its last Rattle stomped, a swing on the remains, before the clock.
	var h: Dictionary = m.rooms[2]
	pl.reset_at(_altar_at(w, 95)["pos"])
	_ticks(w, 0.3)
	_seal(w, h, _floor(HOLD_AT))
	_dropped(w, h)
	var hr: Array = m.counted(h).filter(func(e): return str(e.kind) == "skeleton")
	hr.sort_custom(func(a, b): return a.position.x < b.position.x)
	for e in m.counted(h):
		if e != hr[0]:
			_kill(e)
	_ticks(w, 2 * DT)
	w.deal(hr[0], 1.0, {"how": "stomp", "flat": 99999.0, "no_hitstop": true})
	_ticks(w, 2 * DT)
	_check(tw.remains.size() == 1 and m.foes_left(h) == 1 and h["phase"] == "fight", "the hold's last Rattle stomped: its remains hold the doors")
	if tw.remains.size() == 1:
		var rp: Vector2 = tw.remains[0]["pos"]
		pl.reset_at(Vector2(rp.x - 30.0, rp.y))
		pl.facing = 1
		_ticks(w, 3 * DT, {"attack": true})
		_ticks(w, 30 * DT)
	_until(w, func(): return h["phase"] == "won", 1.0)
	_check(int(tw.laid) == 1 and h["phase"] == "won" and h["won"] == "clear" and float(h["won_at"]) - float(h["sealed_at"]) < 19.0,
			"a swing lays them to rest and the doors open, before the clock (%s/%s)" % [h["phase"], h["won"]])
	_keep_alive = false
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
