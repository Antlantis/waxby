extends SceneTree
## WLS: the secret exits, the secret levels and the two retrofits
## (workstreams.md §2.1 WLS; spec §3.8-§3.9; scripts/features/secrets.gd,
## tools/levels/secrets.py, w1.py's B_ROOF, w2.py's C2_LANTERNS).
##
## - The registry: every secret: header names a Game.SECRET_LEVELS entry and
##   every entry's "from" level (when built, and once its stream gave it the
##   header: until then "skipped") names it back, ids exact.
## - The retrofits: 1-3 keeps every x before B_ROOF (and B_BELL is v2's, 30
##   on); 2-2 keeps its width and all but C2_LANTERNS' columns 26-37 and the
##   new sign. Every built exit (1-3, 2-2 and whichever of 3-3, 4-2, 5-3, 6-2
##   carry their secret: header) hides one silver bell whose false stone
##   secrets.gd finds (the F bordering its attic), with its world's sign
##   within 12 tiles.
## - Every secret level: 250 x 15, the gilt theme, music secret, its area,
##   a Warden of a known kind with two Omens, a secret prize, three sigils,
##   no Dread and no Lidlurk, 5-10 monsters at the spec's threat per 100
##   tiles, three altars (about x 67, 141, 205) with the start, altars and
##   bell at most 75 tiles apart, the Warden room last with the D, the grave
##   candle's floor and the S in it, the old Wicks' sign first and the Lost
##   Wick's inscription; a Gustling Warden placed by gustling.gd's rule;
##   every anoint: cell holds a monster.
## - The bot's way to each silver bell: up to the Warden's door (past it is
##   the fight's arena) at most 4 jumps in a row without stone over a pit (a
##   ride on a mover counts as a jump), and along that way no more than 14
##   columns over a pit between stone footholds; and on the way to every
##   goal, no wait on timed footing longer than 60% of its Dusk life with the
##   feel lab's numbers (read from the feature modules' DIFF_KNOBS).
## - In the World: the silver bell and its arch spawn only once the registry
##   holds the secret level; ringing it clears the level with result.secret;
##   the hum's gain falls off to nothing at 320 px; the hint bark once, on
##   the floor. A secret level: the Warden asleep at its post (not in the
##   World's list: nothing reaches it from the doorway, every calling tries
##   with real inputs), the door sealed once Wick is in and the Warden awake,
##   a snuff resets the room (a fresh Warden asleep, the door open), the
##   Warden's fall lights the grave candle, the Lost Wick speaks, the prize
##   appears on the shrine, the bell rises (its rope dead until it's up) and
##   ringing it ends the level (lost_wick, no secret); the prize pays once
##   per difficulty; with no monsters the bell stands from the start;
##   anoint: (in 3-S itself too).
## - Standing still in each Warden room and fighting (every calling, a hero
##   at the area's level + 4, on every third standable spot in turn, every
##   spot with WAXBY_SLOW=1): Wick is hurt before the Warden falls, or it
##   doesn't fall in 60 s. No spot kills it for free.
##
##     godot --headless --path game --script res://tests/test_secrets.gd

const LevelData := preload("res://scripts/level_data.gd")
const Reach := preload("res://scripts/reach.gd")
const ReachSearch := preload("res://scripts/reach_search.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const TILE := 32
const DT := 1.0 / 120.0
const OLD_WICKS := "The old Wicks came this way. So can you"
# v2's 1-3 (sha256 of the rows, padded with air): its first 174 columns (to
# the end of B_ORGAN), and B_BELL's 32 (v2's 174-205, now 204-235).
const V2_13_BEFORE := "b84eb5601fec786673b76069d9b4aa5f451f47b9fff77e56b5f1fe715d7f29b4"
const V2_13_BELL := "8006a4e4b36b429217934ea0cc763e27ee5096fab0983fb737c28e1c95916143"
# v2's 2-2 with x 203 (the new sign) and 206-217 (C2_LANTERNS 26-37) masked.
const V2_22_MASKED := "ca7b16c077e3cf13bf4926469fdf05c435eec63102944b3f093fee0f08312b35"
# Spec §3.4.5-§3.7.5 and §3.8: each secret level's threat per 100 tiles (its
# monsters' EnemyKinds costs, the Warden aside).
const THREAT := {"1-S": 5.6, "2-S": 3.8, "3-S": 4.4, "4-S": 5.2, "5-S": 2.8, "6-S": 4.1}
# Spec §3.9: each world's exit sign.
const EXIT_SIGNS := {1: "Silver light, where no light should be", 2: "The guild counted lamps. Three, then up",
		3: "These spores rise. Where to?", 4: "The mainspring is wound from above", 5: "A lamp that lights nothing?",
		6: "One bell down here still rings"}
const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
const SecretsScript := preload("res://scripts/features/secrets.gd")
const ALTARS_AT := [67, 141, 205]
const STUB_HUD := """extends CanvasLayer
var said := []
func _say(k: String, a = null) -> void:
	said.append([k, a])
func bark(k: String) -> void:
	_say("bark", k)
func boss_bar(i = null) -> void:
	_say("boss_bar", i)
func toast(a = null, b = null, c = null) -> void:
	_say("toast", a)
func title_card(a = null, b = null, c = null) -> void:
	_say("title_card", a)
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
func elite_seen(a = null) -> void:
	pass
func dim_ring(a = null) -> void:
	pass
func banner(a = null) -> void:
	pass
func banked(a = null) -> void:
	pass
func layout() -> Dictionary:
	return {}
func barks() -> Array:
	return said.filter(func(x): return x[0] == "bark").map(func(x): return x[1])
"""

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
	game.save_path = "user://test_secrets_save.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.reset()
	_test_registry()
	_test_retrofits()
	_test_exits()
	for id in _secret_ids():
		_test_level_rules(LevelData.load_file(_path(id)))
	_test_paths()
	# Every built exit (the rev5 review: 3-3's and 4-2's, turned on at int3,
	# were never met here), each from the floor under its own odd sight.
	for row in [["1-3", "1-S", 1], ["2-2", "2-S", 2], ["3-3", "3-S", 3], ["4-2", "4-S", 4], ["5-3", "5-S", 5], ["6-2", "6-S", 6]]:
		await _test_exit_world(str(row[0]), str(row[1]), int(row[2]))
	await _test_gated()
	await _test_secret_clear_xp()
	for id in _secret_ids():
		await _test_warden_room(id)
	await _test_prize_once()
	await _test_no_warden()
	await _test_anoint()
	await _test_anoint_real()
	for id in _secret_ids():
		await _test_doorway(id)
	for id in _secret_ids():
		await _test_stand_still(id)
	for id in _secret_ids():
		await _test_warden_melee(id)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	print("test_secrets: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _registry() -> Array:
	return (game.get_script() as Script).get_script_constant_map().get("SECRET_LEVELS", [])


func _path(id: String) -> String:
	return "res://levels/%s.txt" % id


func _secret_ids() -> Array:
	## The secret levels built (their files in the build), in order.
	var out := []
	for info in _registry():
		if FileAccess.file_exists(str(info["path"])):
			out.append(str(info["id"]))
	return out


func _rows(path: String) -> Array:
	## The level file's rows, padded with air to its width.
	var t := FileAccess.get_file_as_string(path)
	var body := t.substr(t.find("---\n") + 4).strip_edges(false, true).split("\n")
	var w := 0
	for r in body:
		w = maxi(w, r.length())
	var out := []
	for r in body:
		out.append(r.rpad(w, "."))
	return out


func _sha_cols(rows: Array, x0: int, x1: int) -> String:
	var parts := PackedStringArray()
	for r in rows:
		parts.append(str(r).substr(x0, x1 - x0))
	return "\n".join(parts).sha256_text()


func _ents(lv: RefCounted, kind: String) -> Array:
	return lv.entities.filter(func(e): return e["kind"] == kind)


func _world(id: String, opts := {}) -> Node2D:
	var lv = LevelData.load_file(_path(id)) if not opts.has("level") else opts["level"]
	game.reset()
	var h: Dictionary = game.new_hero(str(opts.get("calling", "knight")))
	if opts.has("hero_level"):
		h["level"] = int(opts["hero_level"])
	game.data["difficulty"] = str(opts.get("diff", "dusk"))
	var w: Node2D = WorldScript.new()
	w.setup(lv, true)
	w.no_monsters = bool(opts.get("no_monsters", false))
	w.paused = true
	root.add_child(w)
	return w


func _test_warden_melee(id: String) -> void:
	## The rev5 review: nothing proved a melee calling can bring each Warden
	## down with real inputs (a sealed room whose Warden can't be reached would
	## soft-lock the level). The Candleknight at the secret's area + 4, never
	## hurt, a pad that chases, faces, swings, jumps and climbs toward it: from
	## the room's floor, or, for a Warden that lives on a vine lane (3-S's
	## Nell, a Creepbone over the void), from her lane, as a player must climb
	## to fight her.
	var areas: Dictionary = (game.get_script() as Script).get_script_constant_map().get("AREAS", {})
	var lvl := clampi(int(areas.get(id, 17)) + 4, 1, 40)
	var w := _world(id, {"hero_level": lvl})
	await process_frame
	w.hud = _stub_hud()
	var m = w.features.module("secrets")
	var pl: Node2D = w.player
	var altars: Array = w.altars.duplicate()
	altars.sort_custom(func(a, b): return a["pos"].x > b["pos"].x)
	pl.reset_at(altars[0]["pos"])
	var t := 0.0
	var i := 0
	var down := false
	var on_lane := false
	while t < 150.0:
		i += 1
		t += DT
		pl.invuln = 5.0
		pl.hp = pl.max_hp
		var pd := {}
		if m.phase == "wait":
			pd = {"right": true, "jump": (i / 40) % 4 == 0}
		elif m.phase == "fight":
			var wd = m.warden
			if wd == null or not is_instance_valid(wd):
				pass
			else:
				var ln = wd.get("lane")
				if not on_lane and ln is Dictionary and not (ln as Dictionary).is_empty() and bool(ln.get("vine", false)):
					# onto her lane, below her
					on_lane = true
					var col := floori(float(ln["x"]) / TILE)
					pl.reset_at(Vector2((col + 0.5) * TILE, minf(float(ln["bottom"]) - 8.0, wd.position.y + 70.0)))
					pl.grab_vine(col)
				var dx: float = wd.position.x - pl.position.x
				var dy: float = wd.position.y - pl.position.y
				pd["attack"] = (i / 18) % 2 == 0
				if on_lane and pl.climbing:
					pd["up"] = dy < -8.0
					pd["down"] = dy > 8.0
				else:
					if absf(dx) > 30.0:
						pd["right" if dx > 0.0 else "left"] = true
					elif (i / 60) % 2 == 0:
						pd["right" if dx > 0.0 else "left"] = true
					pd["jump"] = (dy < -40.0 and (i / 30) % 2 == 0) or (i / 70) % 5 == 0
					if dy < -40.0:
						pd["up"] = true
		elif m.phase == "won":
			down = true
			break
		w.test_pad = pd
		w._read_pad()
		w.tick(DT)
		if w.state != "play":
			break
		if i % 1200 == 0:
			await process_frame
	_check(down, "%s: a Candleknight (L%d) brings the Warden down with real inputs (%s in %.0f s)" % [id, lvl, "down" if down else "NOT down", t])
	await _done(w)


func _stub_hud() -> CanvasLayer:
	var g := GDScript.new()
	g.source_code = STUB_HUD
	g.reload()
	return g.new()


func _ticks(w: Node2D, seconds: float, pad := {}) -> void:
	for i in int(round(seconds / DT)):
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)


func _until(w: Node2D, cond: Callable, seconds: float) -> void:
	## Ticks until cond holds (a kill's hitstop and level-ups pause the feature clock).
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


# ---------------------------------------------------------------- the registry

func _test_registry() -> void:
	var reg := _registry()
	_check(reg.size() == 6, "six secret levels in Game.SECRET_LEVELS (%d)" % reg.size())
	var ids := {}
	for info in reg:
		ids[str(info["id"])] = info
	var files := {}
	for f in DirAccess.get_files_at("res://levels"):
		if f.ends_with(".txt"):
			files[f.get_basename()] = true
	var named := 0
	for name in files:
		var lv = LevelData.load_file(_path(name))
		if str(lv.secret) == "" or name.begins_with("lab-"):
			continue
		named += 1
		_check(ids.has(str(lv.secret)), "%s: secret: %s names a registry entry" % [name, lv.secret])
		if ids.has(str(lv.secret)):
			_check(str(ids[str(lv.secret)]["from"]) == name, "%s: the registry says %s is found from it" % [name, lv.secret])
		_check(_ents(lv, "silver_bell").size() == 1, "%s: one silver bell" % name)
	for id in ids:
		var info: Dictionary = ids[id]
		_check(id.length() == 3 and id.ends_with("-S") and id[0] == str(int(info["world"])), "%s: the id is exact (<w>-S, upper case)" % id)
		_check(str(info["path"]) == _path(id), "%s: its path is levels/%s.txt" % [id, id])
		var from := str(info["from"])
		if files.has(from):
			var lv = LevelData.load_file(_path(from))
			if str(lv.secret) == "":
				print("  skipped: %s is built but has no secret: header yet (its level stream's), so %s isn't found from it" % [from, id])
			else:
				_check(str(lv.secret) == id, "%s's exit level %s names it (secret: %s)" % [id, from, lv.secret])
		if files.has(id):
			_check(not files.has(id.to_lower()), "%s: no lower-case twin of its file" % id)
	_check(named >= 2, "the built levels hold their silver bells (%d)" % named)
	print("  the registry: %d secrets, %d exits built" % [ids.size(), named])


# ---------------------------------------------------------------- the retrofits

func _test_retrofits() -> void:
	var r13 := _rows(_path("1-3"))
	var l13 = LevelData.load_file(_path("1-3"))
	_check(l13.width == 236, "1-3 is 236 wide (v2's 206 and B_ROOF's 30): %d" % l13.width)
	_check(_sha_cols(r13, 0, 174) == V2_13_BEFORE, "1-3: every column before B_ROOF is v2's, byte for byte")
	var bell_ok := _sha_cols(r13, 204, 236) == V2_13_BELL
	if not bell_ok:
		print("  (1-3's B_BELL hash now: %s)" % _sha_cols(r13, 204, 236))
	_check(bell_ok, "1-3: B_BELL is v2's, 30 columns on")
	_check(l13.tile(69, 5) == LevelData.STONE, "1-3's star route post (69, 5) stands")
	_check(_ents(l13, "silver_bell").size() == 1 and l13.tile(_ents(l13, "silver_bell")[0]["cell"].x, _ents(l13, "silver_bell")[0]["cell"].y + 1) == LevelData.FALSE_STONE,
			"1-3: the silver bell hangs right over its false stone")
	var r22 := _rows(_path("2-2"))
	var l22 = LevelData.load_file(_path("2-2"))
	_check(l22.width == 304, "2-2 keeps its width (%d)" % l22.width)
	var masked := []
	for r in r22:
		var s := str(r)
		var chars := PackedStringArray()
		for x in s.length():
			chars.append("?" if x == 203 or (x >= 206 and x <= 217) else s[x])
		masked.append("".join(chars))
	_check("\n".join(masked).sha256_text() == V2_22_MASKED, "2-2: all but C2_LANTERNS' columns 26-37 and its new sign are v2's")
	_check(_ents(l22, "silver_bell").size() == 1 and l22.tile(_ents(l22, "silver_bell")[0]["cell"].x, _ents(l22, "silver_bell")[0]["cell"].y + 1) == LevelData.FALSE_STONE,
			"2-2: the silver bell hangs right over its false stone")
	# 2-2's bell hangs over the third lantern post of the dark passage.
	var bell: Vector2i = _ents(l22, "silver_bell")[0]["cell"] if not _ents(l22, "silver_bell").is_empty() else Vector2i(-1, -1)
	var posts := _ents(l22, "lantern").map(func(e): return e["cell"].x).filter(func(x): return x >= 180 and x < 222)
	posts.sort()
	_check(posts.size() >= 3 and posts[2] == bell.x, "2-2: the silver bell hangs over C2_LANTERNS' third post (%s, bell %d)" % [posts, bell.x])


func _exit_rules(lv: RefCounted, secret: String) -> void:
	## A built exit: one silver bell, the false stone secrets.gd finds for it
	## (the F bordering its attic, as in play), its world's sign within 12.
	_check(str(lv.secret) == secret, "%s: secret: %s" % [lv.id, secret])
	var bells := _ents(lv, "silver_bell")
	_check(bells.size() == 1, "%s: one silver bell" % lv.id)
	if bells.is_empty():
		return
	var c: Vector2i = bells[0]["cell"]
	var nook: Array = SecretsScript.nook_of(lv, c)
	var seal: Array = SecretsScript.seal_of(lv, c, nook)
	_check(not seal.is_empty(), "%s: the silver bell at %s has its false stone (%s; its attic %d cells)" % [lv.id, c, seal, nook.size()])
	var sign: String = EXIT_SIGNS.get(int(lv.world), "")
	var best := 999
	for e in _ents(lv, "sign"):
		if str(e["text"]) != sign:
			continue
		# Within 12 tiles of the bell or of the false stone that hides it.
		var d := absi(e["cell"].x - c.x)
		for q in seal:
			d = mini(d, absi(e["cell"].x - (q as Vector2i).x))
		best = mini(best, d)
	_check(best <= 12, "%s: its sign \"%s\" stands within 12 tiles of the bell or its false stone (%s)" % [lv.id, sign,
			"none" if best == 999 else "%d tiles" % best])


func _test_exits() -> void:
	## Every built level whose secret: header names a registry entry.
	var reg := {}
	for info in _registry():
		reg[str(info["id"])] = info
	var n := 0
	for f in DirAccess.get_files_at("res://levels"):
		if not f.ends_with(".txt") or f.begins_with("lab-"):
			continue
		var lv = LevelData.load_file(_path(f.get_basename()))
		if str(lv.secret) == "" or str(lv.id).ends_with("-S"):
			continue
		n += 1
		_check(reg.has(str(lv.secret)), "%s: its secret %s is registered" % [lv.id, lv.secret])
		_exit_rules(lv, str(lv.secret))
	print("  exits built: %d" % n)


# ---------------------------------------------------------------- a secret level's rules

func _test_level_rules(lv: RefCounted) -> void:
	var id: String = lv.id
	_check(lv.errors.is_empty(), "%s parses cleanly %s" % [id, lv.errors])
	_check(lv.width == 250 and lv.height == 15, "%s is 250 x 15 (%d x %d)" % [id, lv.width, lv.height])
	_check(lv.subtitle == id and lv.title != "", "%s: its title and subtitle" % id)
	_check(str(lv.theme).ends_with("_gilt") and lv.music == "secret", "%s: a gilt theme, music secret (%s, %s)" % [id, lv.theme, lv.music])
	var areas: Dictionary = (game.get_script() as Script).get_script_constant_map().get("AREAS", {})
	_check(int(lv.area) == int(areas.get(id, -1)), "%s: area %d (Game.AREAS %s)" % [id, lv.area, areas.get(id, "?")])
	_check(lv.dread.is_empty() and str(lv.secret) == "" and lv.boss == "", "%s: no Dread, no secret of its own, no boss" % id)
	var wd: Dictionary = lv.warden
	_check(not wd.is_empty() and EnemyKinds.known(str(wd.get("kind", ""))) and (wd.get("omens", []) as Array).size() == 2,
			"%s: a Warden of a known kind with two Omens (%s)" % [id, wd])
	var Items = load("res://scripts/items.gd")
	_check(Items.LEGENDS.has(str(lv.secret_prize)) and bool((Items.LEGENDS[str(lv.secret_prize)] as Dictionary).get("secret", false)),
			"%s: its prize %s is a secret Legendary" % [id, lv.secret_prize])
	_check(lv.count("sigil") == 3, "%s: three sigils" % id)
	_check(lv.count("silver_bell") == 1 and lv.count("dread") == 1 and lv.count("bell") == 0 and lv.count("boss") == 0,
			"%s: one silver bell, one Warden, no great bell" % id)
	_check(lv.count("lidlurk") == 0, "%s: no Lidlurk" % id)
	var monsters := 0
	for e in lv.entities:
		if EnemyKinds.known(str(e["kind"])) and e["kind"] != "dread":
			monsters += 1
	_check(monsters >= 5 and monsters <= 10, "%s: a sparse cast of 5-10 monsters (%d)" % [id, monsters])
	# Three altars at about 67, 141 and 205; start, altars, bell <= 75 apart.
	var altars := _ents(lv, "altar").map(func(e): return int(e["cell"].x))
	altars.sort()
	var bell: Vector2i = _ents(lv, "silver_bell")[0]["cell"] if lv.count("silver_bell") > 0 else Vector2i(-1, -1)
	_check(altars.size() == 3, "%s: three altars (%s)" % [id, altars])
	var near := altars.size() == 3
	for i in mini(3, altars.size()):
		if absi(int(altars[i]) - ALTARS_AT[i]) > 6:
			near = false
	_check(near, "%s: its altars at about x 67, 141, 205 (%s)" % [id, altars])
	var marks := [lv.start.x] + altars + [bell.x]
	var gaps := []
	for i in range(1, marks.size()):
		gaps.append(int(marks[i]) - int(marks[i - 1]))
	_check(gaps.all(func(g): return g > 0 and g <= 75), "%s: checkpoints at most 75 tiles apart (%s)" % [id, gaps])
	# The Warden's room: the last section, the D and the S in it, the grave's floor.
	var raw := str(lv.headers.get("warden_room", "")).split("-")
	var x0 := int(raw[0]) if raw.size() == 2 else -1
	var x1 := int(raw[1]) if raw.size() == 2 else -1
	_check(x0 == lv.width - 34 and x1 == lv.width - 1, "%s: the Warden's room is the last 34 columns (%d-%d)" % [id, x0, x1])
	var d: Vector2i = _ents(lv, "dread")[0]["cell"] if lv.count("dread") > 0 else Vector2i(-1, -1)
	_check(d.x > x0 + 1 and d.x < x1 - 1 and bell.x > x0 + 1 and bell.x < x1 - 1, "%s: the Warden and the bell are in the room" % id)
	var grave := Vector2i(bell.x - 2, bell.y)
	_check(lv.tile(grave.x, grave.y) == LevelData.AIR and (LevelData.is_solid(lv.tile(grave.x, grave.y + 1))),
			"%s: the grave candle has its floor two tiles left of the bell" % id)
	var door := 0
	var other := 0
	for x in [x0, x0 + 1, x1 - 1, x1]:
		for y in range(0, lv.height - 1):
			if lv.tile(x, y) == LevelData.AIR:
				if x <= x0 + 1:
					door += 1
				else:
					other += 1
	_check(door >= 3, "%s: the room's door is in its left wall (%d cells)" % [id, door])
	# Signs: the old Wicks' first, the Lost Wick's inscription.
	var signs := _ents(lv, "sign")
	signs.sort_custom(func(a, b): return a["cell"].x < b["cell"].x)
	_check(not signs.is_empty() and str(signs[0]["text"]) == OLD_WICKS, "%s: its first sign: \"%s\"" % [id, OLD_WICKS])
	var Story = load("res://scripts/story.gd")
	var ins: Array = (Story.INSCRIPTIONS as Dictionary).get(id, [])
	var has_ins := false
	for s in signs:
		if not ins.is_empty() and str(s["text"]) == str(ins[0]):
			has_ins = true
			_check(absi(s["cell"].x - grave.x) <= 4, "%s: the Lost Wick's inscription stands by the grave candle" % id)
	_check(has_ins, "%s: the Lost Wick's inscription (%s)" % [id, ins])
	# The spec's threat per 100 tiles (the kinds' costs, the Warden aside; the
	# Heat of its outline is a design rating no code reads).
	var cost := 0.0
	for e in lv.entities:
		if e["kind"] != "dread":
			cost += EnemyKinds.cost(str(e["kind"]))
	var threat := cost / float(lv.width) * 100.0
	_check(absf(threat - float(THREAT.get(id, -1.0))) <= 0.05, "%s: threat %.2f per 100 tiles (spec %.1f)" % [id, threat, THREAT.get(id, -1.0)])
	# Every anoint: cell holds a monster placed there.
	var mod = SecretsScript.new()
	mod.level = lv
	var cells: Array = mod.anoint_cells()
	for c in cells:
		var at: Array = lv.entities.filter(func(e): return e["cell"] == c and EnemyKinds.known(str(e["kind"])) and e["kind"] != "dread")
		_check(at.size() == 1, "%s: the anoint cell %s holds a monster (%s)" % [id, c, at.map(func(e): return e["kind"])])
	if id == "3-S":
		_check(cells.size() == 2, "3-S: two guaranteed Anointed (%s)" % [cells])
	# A Gustling Warden is placed by gustling.gd's rule (5 tiles of floor each way).
	if str(wd.get("kind", "")) == "gustling" and ResourceLoader.exists("res://scripts/gustling.gd"):
		var t := FileAccess.get_file_as_string(_path(id))
		var cut := t.find("---\n") + 4
		var head := t.substr(0, cut)
		var body := t.substr(cut).replace("D", "z")
		var lz = LevelData.new()
		lz.id = id
		lz.parse(head + body)
		var probs: Array = (load("res://scripts/gustling.gd") as Script).call("placement_problems", lz)
		probs = probs.filter(func(q): return str(q).begins_with("%d,%d:" % [d.x, d.y]))
		_check(probs.is_empty(), "%s: the Gustling Warden at %s keeps gustling.gd's placement rule %s" % [id, d, probs])
	if id == "2-S":
		_check(lv.count("sconce") == 0, "2-S: no sconces anywhere (%d)" % lv.count("sconce"))
	if id == "6-S":
		_check(lv.count("sconce") == 0 and lv.count("lantern") == 0 and lv.count("vigil") == 0, "6-S: no candles, sconces or lamps")
		var hushed := 0
		for h in lv.hush_cols:
			hushed += int(h["x1"]) - int(h["x0"]) + 1
		_check(hushed >= lv.width - 2, "6-S: the whole level is a Hush zone (%d columns)" % hushed)


# ---------------------------------------------------------------- the bot's ways

func _knob(path: String, name: String) -> float:
	if not ResourceLoader.exists(path):
		return -1.0
	var t: Dictionary = (load(path) as Script).get_script_constant_map().get("DIFF_KNOBS", {})
	return float((t.get(name, {}) as Dictionary).get("dusk", -1.0)) if t.get(name) is Dictionary else -1.0


func _lives() -> Dictionary:
	## The timed surfaces' Dusk lives with the owner's feel-lab numbers.
	var out := {}
	var rot := _knob("res://scripts/features/orchard.gd", "rotten_hold")
	out["rotten"] = rot if rot > 0.0 else Reach.LIFE["rotten"]
	var land := _knob("res://scripts/features/glass.gd", "glass_land")
	var stand := _knob("res://scripts/features/glass.gd", "glass_stand")
	out["glass"] = (1.0 - land) / stand if land > 0.0 and stand > 0.0 else Reach.LIFE["glass"]
	var sink := _knob("res://scripts/features/deep.gd", "float_sink")
	out["float"] = 24.0 / sink if sink > 0.0 else Reach.LIFE["float"]
	var still := _knob("res://scripts/features/deep.gd", "still_time")
	out["still"] = still if still > 0.0 else Reach.LIFE["still"]
	out["dawn"] = Reach.LIFE["dawn"]
	return out


func _test_paths() -> void:
	var lives := _lives()
	print("  timed lives (Dusk): %s" % [lives])
	var ids := _secret_ids()
	for f in ["1-3", "2-2"]:
		if FileAccess.file_exists(_path(f)):
			ids.append(f)
	for id in ids:
		var lv = LevelData.load_file(_path(id))
		var t0 := Time.get_ticks_msec()
		var timed := Reach.timed_cells(lv)
		var s = ReachSearch.new()
		var goals: Array = Reach.goals_of(lv) if id.ends_with("-S") else Reach.goals_of(lv).filter(func(g): return g["what"] == "silver bell")
		s.setup(Reach.static_copy(lv), LevelData.cell_floor(lv.start), {"timed": timed, "goals": goals})
		s.run()
		print("  %s: the bot, %d states, %d ms" % [id, s.seen.size(), Time.get_ticks_msec() - t0])
		_check(not s.capped, "%s: the bot finishes under the cap" % id)
		for g in goals:
			var ok: bool = s.found.has(g["what"])
			_check(ok, "%s: the bot reaches the %s" % [id, g["what"]])
			if not ok:
				continue
			var dm: Dictionary = s.found[g["what"]]["dmax"]
			for k in dm:
				var most: float = 0.6 * float(lives.get(k, 999.0))
				_check(float(dm[k]) <= most + 0.001, "%s: the way to the %s waits on %s %.2f s at most (%.2f: 60%% of the feel lab's %.2f s)" % [id, g["what"], k, dm[k], most, lives.get(k, 0.0)])
			if g["what"] == "silver bell" and id.ends_with("-S"):
				_path_rules(lv, s, int(s.found[g["what"]]["node"]))
		s.free_player()


func _path_rules(lv: RefCounted, s: RefCounted, end: int) -> void:
	## Spec §3.9 on the bot's own way to the bell, up to the Warden's door
	## (past it is the fight's arena: 3-S's rotten lanes round Nell):
	##   - at most 4 landings in a row off stone over a pit (stone: a SAFE
	##     tile of the level itself; a crumble, a float, glass, a vine, a cog
	##     tooth, a swing, a moving ledge are not; a ride on a mover counts as
	##     one jump however the bot hops along the arc the static copy lays),
	##     where a stone foothold the bot reaches within 1.5 tiles across and
	##     3 rows of a landing (a post the way passes over) ends the run;
	##   - never more than 14 columns in a row over a pit (the void, deep
	##     water) at the way's height with no stone foothold there: one the
	##     way stands on, or one the bot reaches within 4 rows of the way.
	var raw := str(lv.headers.get("warden_room", "")).split("-")
	var door_x: int = int(raw[0]) if raw.size() == 2 else int(lv.width)
	var path: Array = s.path_to(end)
	var stones := {}                 # column -> [y] of the stone footholds the bot reaches
	for n in s.nodes:
		if _on_stone(lv, n):
			var q: Vector2 = n["pos"]
			var qc := floori(q.x / TILE)
			if not stones.has(qc):
				stones[qc] = []
			stones[qc].append(q.y)
	var run := 0
	var worst := 0
	var at_worst := 0.0
	var ride := Vector2i(-1, -1)
	var way_y := {}                  # column -> the way's feet y there
	var prev := Vector2(-1, -1)
	for idx in path:
		var n: Dictionary = s.nodes[idx]
		var act: Dictionary = n["action"]
		var p: Vector2 = n["pos"]
		if prev.x >= 0.0:
			var a := mini(floori(prev.x / TILE), floori(p.x / TILE))
			var b := maxi(floori(prev.x / TILE), floori(p.x / TILE))
			for x in range(a, b + 1):
				var k := 0.0 if b == a else float(x - a) / float(b - a)
				way_y[x] = lerpf(prev.y, p.y, k if prev.x <= p.x else 1.0 - k)
		prev = p
		if floori(p.x / TILE) >= door_x:
			break
		var r := _ride_of(lv, s, p)
		if _on_stone(lv, n) or not _over_pit(lv, p) or _stone_near(stones, p):
			run = 0
			ride = Vector2i(-1, -1)
			continue
		if r.x >= 0 and r == ride:
			continue                 # the same ride, another hop along its arc
		ride = r
		if act.get("jump", false) or act.get("vine", false) or bool(n["climb"]) or r.x >= 0:
			run += 1
			if run > worst:
				worst = run
				at_worst = p.x / TILE
	_check(worst <= 4, "%s: at most 4 jumps without stone over a pit on the way to the Warden's door (%d, to x %.0f)" % [lv.id, worst, at_worst])
	# Stone within reach of the way, by column.
	var stone := {}
	for n in s.nodes:
		if not _on_stone(lv, n):
			continue
		var q: Vector2 = n["pos"]
		var cx := floori(q.x / TILE)
		if way_y.has(cx) and absf(q.y - float(way_y[cx])) <= 4.0 * TILE:
			stone[cx] = true
	var gap := 0
	var widest := 0
	var at := -1
	var start: int = int(lv.start.x)
	for x in range(start, door_x):
		if not way_y.has(x):
			continue
		var over := _over_pit(lv, Vector2((x + 0.5) * TILE, float(way_y[x])))
		if stone.has(x) or not over:
			gap = 0
			continue
		gap += 1
		if gap > widest:
			widest = gap
			at = x - gap + 1
	_check(widest <= 14, "%s: never more than 14 columns over a pit with no stone foothold by the way (widest %d, from x %d)" % [lv.id, widest, at])


static func _stone_near(stones: Dictionary, p: Vector2) -> bool:
	## A stone foothold the bot reaches within 1.5 tiles across and 3 rows of p.
	var cx := floori(p.x / TILE)
	for x in range(cx - 2, cx + 3):
		for y in stones.get(x, []):
			if absf((x + 0.5) * TILE - p.x) <= 1.5 * TILE + 16.0 and absf(float(y) - p.y) <= 3.0 * TILE:
				return true
	return false


static func _ride_of(lv: RefCounted, s: RefCounted, p: Vector2) -> Vector2i:
	## The mover ride under p: the laid run (row, leftmost column) of the
	## ledge the static copy laid for a mover, else (-1, -1).
	for dx in [-9.0, 0.0, 9.0]:
		var c := Vector2i(floori((p.x + dx) / TILE), floori((p.y + 1.0) / TILE))
		if s.lv.tile(c.x, c.y) == LevelData.LEDGE and lv.tile(c.x, c.y) == LevelData.AIR:
			var x0 := c.x
			while s.lv.tile(x0 - 1, c.y) == LevelData.LEDGE and lv.tile(x0 - 1, c.y) == LevelData.AIR:
				x0 -= 1
			return Vector2i(x0, c.y)
	return Vector2i(-1, -1)


static func _over_pit(lv: RefCounted, p: Vector2) -> bool:
	## Nothing solid under p to the level's bottom (a fall there is a pit's,
	## the void's or deep water's; a sunken floor is no pit).
	var x := floori(p.x / TILE)
	for y in range(floori((p.y + 1.0) / TILE), lv.height):
		var t: int = lv.tile(x, y)
		if LevelData.is_solid(t):
			return false
		if t == LevelData.WATER and lv.is_deep(x, y):
			return true
	return true


static func _on_stone(lv: RefCounted, n: Dictionary) -> bool:
	if bool(n["climb"]):
		return false
	var p: Vector2 = n["pos"]
	for dx in [-9.0, 0.0, 9.0]:
		var c := Vector2i(floori((p.x + dx) / TILE), floori((p.y + 1.0) / TILE))
		if LevelData.is_safe(lv.tile(c.x, c.y)) and absf(p.y - c.y * TILE) < 2.0:
			return true
	return false


# ---------------------------------------------------------------- a main level's exit

func _test_exit_world(id: String, secret: String, world_n: int) -> void:
	if not FileAccess.file_exists(_path(id)):
		print("  skipped: %s missing" % id)
		return
	var w := _world(id)
	await process_frame
	var hud := _stub_hud()
	w.hud = hud
	var m = w.features.module("secrets")
	_check(m != null and m.exits.size() == 1, "%s: the secrets module holds its exit" % id)
	if m == null or m.exits.is_empty():
		await _done(w)
		return
	var ex: Dictionary = m.exits[0]
	var b: Dictionary = ex["bell"]
	_check(w.bells.has(b) and bool(b["silver"]) and (b["rope"] as Rect2).size == Vector2(28, 44), "%s: its silver bell is spawned, with its own rope" % id)
	_check(not (ex["seal"] as Array).is_empty(), "%s: the exit knows the false stone that hides it" % id)
	# The hum's gain: 1 at the arch, a half at 160 px, nothing from 320 px.
	var win: Vector2 = ex["floor"] - Vector2(0, m.WINDOW_UP)
	_check(absf(m.hum_gain(win) - 1.0) < 0.01 and absf(m.hum_gain(win + Vector2(160, 0)) - 0.5) < 0.01 and m.hum_gain(win + Vector2(330, 0)) == 0.0,
			"%s: the hum falls off to nothing at 320 px" % id)
	# The hint bark: once, on the floor near it, while it's still to find
	# (from the floor under the odd sight: the walking floor, not the attic).
	var pl: Node2D = w.player
	var fl: Vector2 = ex["floor"]
	var below := Vector2(float(ex["sight"].x), float(ex["floor_y"]))
	if below.y >= INF or below.y <= 0.0:
		below = Vector2(fl.x - 2 * TILE, 0)
		for y in range(ex["cell"].y + 2, w.level.height):
			if LevelData.is_solid(w.level.tile(int(below.x / TILE), y)):
				below.y = y * TILE
				break
	pl.reset_at(below)
	_ticks(w, 0.5)
	_ticks(w, 0.5)
	var hints: Array = hud.barks().filter(func(k): return k == "secret_hint_%d" % world_n)
	_check(hints.size() == 1, "%s: the hint bark secret_hint_%d, once (%s)" % [id, world_n, hud.barks()])
	# Ringing it: the level clears by its secret way, result.secret.
	var rung := [""]
	w.secret_rung.connect(func(lid): rung[0] = lid)
	pl.reset_at(fl)
	pl.invuln = 10.0
	_ticks(w, 0.2)
	_check(bool(b["rung"]) and w.state == "clear" and str(w.result()["secret"]) == secret and rung[0] == secret,
			"%s: ringing the silver bell clears it with result.secret %s (%s, %s)" % [id, secret, w.state, w.result()["secret"]])
	_check(int(w.result()["lost_wick"]) == 0, "%s: a main level has no Lost Wick" % id)
	var out: Dictionary = game.record_result(w.result())
	_check(str(out.get("secret", "")) == secret and game.secret_open(secret, "dusk"), "%s: record_result opens %s" % [id, secret])
	await _done(w)


func _test_secret_clear_xp() -> void:
	## A secret level's first clear pays 45 x E(A) (spec §7, contract): the
	## rev5 review found it paying the normal first clear's 30. A repeat pays
	## a clear's 8.
	if not FileAccess.file_exists(_path("1-S")):
		return
	var Prog = load("res://scripts/progression.gd")
	var w := _world("1-S", {"no_monsters": true, "hero_level": 1})
	await process_frame
	var xp0 := int(game.hero()["xp"])
	var xg0 := int(w.xp_gained)
	w._ring(w.add_bell(w.player.position))
	var paid := int(w.xp_gained) - xg0
	_check(paid == int(Prog.event_xp("secret_clear", int(w.area))) and paid > int(Prog.event_xp("first_clear", int(w.area))),
			"1-S's first clear pays event_xp(secret_clear, %d) = %d (%d, hero xp +%d)" % [w.area, Prog.event_xp("secret_clear", int(w.area)), paid, int(game.hero()["xp"]) - xp0])
	game.record_result(w.result())
	await _done(w)
	var w2 := _world("1-S", {"no_monsters": true, "hero_level": 1})
	game.level_record("1-S")["cleared"] = true
	await process_frame
	var xg1 := int(w2.xp_gained)
	w2._ring(w2.add_bell(w2.player.position))
	_check(int(w2.xp_gained) - xg1 == int(Prog.event_xp("clear", int(w2.area))), "a repeat clear of 1-S pays a clear's (%d)" % (int(w2.xp_gained) - xg1))
	await _done(w2)


func _test_gated() -> void:
	## Until the registry holds the secret level (and its file is built),
	## the bell and its arch aren't spawned: the cell stays air.
	var rows := []
	for y in 15:
		rows.append("#".repeat(40) if y >= 13 else ".".repeat(40))
	rows[12] = "..P" + ".".repeat(12) + "S" + ".".repeat(24)
	var lv = LevelData.new()
	lv.id = "1-9"
	lv.parse("title: t\nsubtitle: 1-9\nsecret: 9-S\n---\n" + "\n".join(rows))
	var w := _world("", {"level": lv})
	await process_frame
	var m = w.features.module("secrets")
	_check(m != null and m.exits.is_empty() and w.bells.is_empty(), "a silver bell whose secret isn't registered isn't spawned")
	await _done(w)


# ---------------------------------------------------------------- a secret level's Warden room

func _room_mod(w: Node2D) -> Object:
	return w.features.module("secrets") if w.features != null else null


func _test_warden_room(id: String) -> void:
	var w := _world(id)
	await process_frame
	var hud := _stub_hud()
	w.hud = hud
	var m = _room_mod(w)
	_check(m != null and m.secret_level and m.phase == "wait", "%s: the room waits for its fight (%s)" % [id, m.phase if m else "?"])
	if m == null or m.phase != "wait":
		await _done(w)
		return
	var wd: Node2D = w.warden
	_check(wd != null and wd.tier == "warden" and m.warden == wd, "%s: the module keeps the World's Warden" % id)
	var room: Dictionary = m.room
	var door: Array = room["door"]
	_check(not door.is_empty() and door.all(func(c): return w.level.tile(c.x, c.y) == LevelData.AIR), "%s: the door is open (%d cells)" % [id, door.size()])
	# Asleep at its post: out of the World's list (nothing hits it, nothing
	# aims at it), still, no bar; it stays so however long Wick waits outside.
	var post: Vector2 = wd.position
	_check(m.dormant and not w.enemies.has(wd) and not wd.active, "%s: before the fight the Warden sleeps at its post, out of reach" % id)
	# The door altar, then into the room: the door seals.
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	var altars: Array = w.altars.duplicate()
	altars.sort_custom(func(a, b): return a["pos"].x > b["pos"].x)
	var door_altar: Dictionary = altars[0]
	pl.reset_at(door_altar["pos"])
	_ticks(w, 1.0)
	_check(bool(door_altar["lit"]) and not m.sealed, "%s: at the door altar, the door is still open" % id)
	_check(wd.position.distance_to(post) < 0.5 and m.dormant and not wd.active and not w.enemies.has(wd), "%s: and the Warden still sleeps at its post" % id)
	var inside := _inside_spot(w.level, room)
	pl.reset_at(inside)
	_ticks(w, 2 * DT)
	var sealed_cells: Array = room.get("sealed_cells", [])
	_check(m.sealed and m.phase == "fight" and not sealed_cells.is_empty() and sealed_cells.all(func(c): return w.level.tile(c.x, c.y) == LevelData.STONE),
			"%s: inside, the door seals (%d cells)" % [id, sealed_cells.size()])
	_ticks(w, 2 * DT)
	_check(not m.dormant and w.enemies.has(wd) and wd.active, "%s: and the Warden wakes" % id)
	# Hurt it, then a snuff: the room opens and starts over.
	w.warden.hp = w.warden.max_hp * 0.4
	pl.invuln = 0.0
	w.hurt_player(99999.0, pl.position.x + 20.0, "lava")
	_ticks(w, 2.0)
	_check(pl.alive and m.phase == "wait" and not m.sealed and m.resets == 1, "%s: a snuff in the room resets it (%s, sealed %s, resets %d)" % [id, m.phase, m.sealed, m.resets])
	_check(sealed_cells.all(func(c): return w.level.tile(c.x, c.y) == LevelData.AIR), "%s: and opens the door" % id)
	var fresh: Node2D = w.warden
	_check(fresh != null and fresh != wd and fresh.alive and absf(fresh.hp - fresh.max_hp) < 0.01 and fresh.tier == "warden" and m.warden == fresh,
			"%s: a fresh Warden at its post, at full life" % id)
	_check(fresh != null and m.dormant and not w.enemies.has(fresh) and not w.enemies.has(wd), "%s: asleep till the door seals again" % id)
	_check(absf(pl.position.x - float(door_altar["pos"].x)) < 40.0, "%s: Wick relights at the door altar" % id)
	# Again, and this time it falls.
	pl.invuln = 1000.0
	pl.reset_at(inside)
	_ticks(w, 2 * DT)
	_check(m.sealed, "%s: sealed again" % id)
	hud.said.clear()
	_kill(fresh)
	for i in 240:
		if m.phase == "won":
			break
		_ticks(w, DT)
	_check(m.phase == "won" and not m.sealed and bool(m.shrine["lit"]), "%s: the Warden falls: the door opens, the grave candle lights" % id)
	var barks: Array = hud.barks()
	var lw := "lost_wick_%s" % id.substr(0, 1)
	_check(barks.has("first_lost_wick") and barks.has(lw) and barks.find("first_lost_wick") < barks.find(lw), "%s: the Lost Wick speaks (%s)" % [id, barks])
	_check(m.bell.is_empty(), "%s: the bell hasn't risen yet" % id)
	_until(w, func(): return m._prize_done, 4.0)
	_check(m._prize_done and not m.prize_item.is_empty() and str(m.prize_item.get("legend", "")) == str(w.level.secret_prize),
			"%s: the prize appears on the shrine (%s)" % [id, m.prize_item.get("legend", "none")])
	_until(w, func(): return not m.bell.is_empty() and m._won_t >= m.RISE_AT + 0.1, 4.0)
	_check(not m.bell.is_empty() and not m._risen, "%s: the silver bell rises beside the shrine" % id)
	# While it rises its rope is dead.
	var rope: Rect2 = m.bell["rope_live"]
	pl.reset_at(Vector2(rope.get_center().x, rope.end.y))
	_ticks(w, 2 * DT)
	_check(not bool(m.bell["rung"]) and w.state == "play", "%s: a rising bell can't be rung" % id)
	_until(w, func(): return m._risen, 4.0)
	_check(m._risen and m.bell["rope"] == m.bell["rope_live"], "%s: risen, its rope is live" % id)
	pl.reset_at(Vector2(rope.get_center().x + 30.0, rope.end.y))
	_ticks(w, 0.3, {"left": true})
	var res: Dictionary = w.result()
	_check(bool(m.bell["rung"]) and w.state == "clear" and int(res["lost_wick"]) == int(id.substr(0, 1)) and str(res["secret"]) == "",
			"%s: ringing it ends the level (lost_wick %d, no secret: '%s')" % [id, res["lost_wick"], res["secret"]])
	_check(not hud.said.any(func(x): return x[0] == "toast" and str(x[1]) == "Secret found!"), "%s: its bell is no secret exit (no 'Secret found!')" % id)
	await _done(w)


static func _kill(e: Node2D) -> void:
	## A Warden down at once (its Omens' motes and shields aside).
	if e != null and is_instance_valid(e) and e.alive:
		e.hp = 0.0
		e._kill({"how": "slash", "from_x": e.position.x - 20.0})


static func _inside_spot(lv: RefCounted, room: Dictionary) -> Vector2:
	## A stone floor just inside the room, past its door (6-S's is an islet).
	var x0 := int(float(room["left"]) / TILE)
	for x in range(x0, x0 + 12):
		for y in range(2, lv.height):
			if LevelData.is_solid(lv.tile(x, y)) and not LevelData.is_solid(lv.tile(x, y - 1)):
				var p := Vector2((x + 0.5) * TILE, y * TILE)
				if p.x - 10.0 > float(room["left"]) + 12.0:
					return p
				break
	return Vector2(float(room["left"]) + 3.5 * TILE, _floor_at(lv, x0 + 3, 2))


static func _floor_at(lv: RefCounted, x: int, from_y: int) -> float:
	for y in range(from_y, lv.height):
		if LevelData.is_solid(lv.tile(x, y)) and not LevelData.is_solid(lv.tile(x, y - 1)):
			return float(y * TILE)
	return float(13 * TILE)


func _test_prize_once() -> void:
	## Paid when picked up, once per difficulty; later clears a boss-weighted item.
	var id := "1-S"
	if not FileAccess.file_exists(_path(id)):
		return
	var w := _world(id)
	await process_frame
	var m = _room_mod(w)
	var pl: Node2D = w.player
	pl.invuln = 1000.0
	_kill(w.warden)
	_until(w, func(): return m._prize_done, 4.0)
	_ticks(w, 0.6)
	var prize := {}
	for p in w.pickups:
		if p["kind"] == "item" and not p["taken"] and str(p["item"].get("legend", "")) == "hymnal":
			prize = p
	_check(not prize.is_empty(), "1-S: Tessel's Hymnal lies on the shrine")
	_check(not bool(game.secret_record(id, "dusk")["prize"]), "1-S: not paid until it's picked up")
	if not prize.is_empty():
		for i in 120:
			if prize["taken"]:
				break
			pl.reset_at(prize["pos"] + Vector2(0, 16))
			_ticks(w, DT)
		_check(bool(prize["taken"]) and bool(game.secret_record(id, "dusk")["prize"]), "1-S: picked up, it's paid on Dusk")
	var dusk_paid: bool = game.secret_record(id, "dusk")["prize"]
	var saved: Dictionary = game.data["secrets"].duplicate(true)
	await _done(w)
	# Again on Dusk: a boss-weighted item, not the Hymnal.
	var w2 := _world(id)
	game.data["secrets"] = saved.duplicate(true)
	await process_frame
	var m2 = _room_mod(w2)
	var n0: int = w2.pickups.filter(func(p): return p["kind"] == "item").size()
	w2.player.invuln = 1000.0
	_kill(w2.warden)
	_until(w2, func(): return m2._prize_done, 4.0)
	_ticks(w2, 0.3)
	var items: Array = w2.pickups.filter(func(p): return p["kind"] == "item")
	_check(dusk_paid and m2.prize_item.is_empty() and not items.any(func(p): return str(p["item"].get("legend", "")) == "hymnal"),
			"1-S again on Dusk: no Hymnal on the shrine")
	_check(items.size() > n0, "1-S again: the shrine gives an item still (%d)" % (items.size() - n0))
	_check(not game.secret_prize(id, "nightfall").is_empty(), "1-S on Nightfall: its own Hymnal still to win")
	await _done(w2)


func _test_no_warden() -> void:
	## No monsters (the golden routes): the grave candle lit, the bell up.
	for id in _secret_ids():
		var w := _world(id, {"no_monsters": true})
		await process_frame
		var m = _room_mod(w)
		_check(m.phase == "won" and bool(m.shrine["lit"]) and m._risen and not m.bell.is_empty() and m.bell["rope"] == m.bell["rope_live"],
				"%s with no monsters: the grave candle is lit and the bell stands" % id)
		_check(m.prize_item.is_empty() and not w.pickups.any(func(p): return p["kind"] == "item"), "%s with no monsters: nothing on the shrine" % id)
		await _done(w)


func _test_anoint() -> void:
	## anoint: "x,y": the monster placed there is Anointed every run.
	var rows := []
	for y in 15:
		rows.append("#".repeat(60) if y >= 13 else ".".repeat(60))
	rows[12] = "..P" + ".".repeat(20) + "s" + ".".repeat(10) + "s" + ".".repeat(17) + "D.S....."
	var lv = LevelData.new()
	lv.id = "1-S"
	lv.parse("title: t\nsubtitle: 1-S\narea: 6\nwarden: Test|skeleton|Warded,Burning\nanoint: 23,12\n---\n" + "\n".join(rows))
	var w := _world("", {"level": lv})
	await process_frame
	var at: Array = w.enemies.filter(func(e): return e.spawn.get("cell", Vector2i(-1, -1)) == Vector2i(23, 12))
	var other: Array = w.enemies.filter(func(e): return e.spawn.get("cell", Vector2i(-1, -1)) == Vector2i(34, 12))
	_check(at.size() == 1 and at[0].tier == "anointed" and not (at[0].omens as Array).is_empty(), "anoint: the monster at 23,12 is Anointed, with its Omens")
	_check(other.size() == 1 and other[0].tier == "", "and the one beside it isn't")
	await _done(w)


func _test_anoint_real() -> void:
	## Every real secret level's anoint: cells: the monster there spawns Anointed.
	for id in _secret_ids():
		var lv = LevelData.load_file(_path(id))
		var mod = SecretsScript.new()
		mod.level = lv
		var cells: Array = mod.anoint_cells()
		if cells.is_empty():
			continue
		for diff in ["dusk", "nightfall"]:
			var w := _world(id, {"diff": diff})
			await process_frame
			for c in cells:
				var at: Array = w.enemies.filter(func(e): return e.spawn.get("cell", Vector2i(-1, -1)) == c)
				_check(at.size() == 1 and at[0].tier == "anointed" and not (at[0].omens as Array).is_empty(),
						"%s on %s: the %s at %s is Anointed, with its Omens" % [id, diff, at[0].kind if at.size() > 0 else "monster", c])
			await _done(w)


func _hero_level(id: String) -> int:
	## A strong hero for the room: the secret level's area + 4 (1-S at L10).
	var areas: Dictionary = (game.get_script() as Script).get_script_constant_map().get("AREAS", {})
	return clampi(int(areas.get(id, 1)) + 4, 1, 40)


func _fight_pad(cls: String, t: float, toward: int) -> Dictionary:
	## Standing still and fighting: the basic attack, the Special now and then
	## (a Flare charged and let go, a Peal, a Knell), a tap to face the Warden.
	var pad := {"attack": fmod(t, 0.3) < 0.15}
	match cls:
		"founder":
			pad["special"] = fmod(t, 1.2) < 0.1
		"sexton":
			pad["special"] = fmod(t, 2.0) < 0.1
		"witch":
			pad["special"] = fmod(t, 2.4) < 0.7
	if toward != 0 and fmod(t, 1.0) < DT * 1.5:
		pad["right" if toward > 0 else "left"] = true
	return pad


func _fighter(id: String, cls: String) -> Node2D:
	return _world(id, {"calling": cls, "hero_level": _hero_level(id)})


func _to_door_altar(w: Node2D) -> void:
	var altars: Array = w.altars.duplicate()
	altars.sort_custom(func(a, b): return a["pos"].x > b["pos"].x)
	w.player.reset_at(altars[0]["pos"])
	_ticks(w, 0.5)


func _test_doorway(id: String) -> void:
	## From the open doorway every calling attacks in (real inputs) for 20 s:
	## the sleeping Warden takes nothing and the door stays open.
	for cls in CALLINGS:
		var w := _fighter(id, cls)
		await process_frame
		w.hud = _stub_hud()
		var m = _room_mod(w)
		if m == null or m.phase != "wait":
			await _done(w)
			continue
		_to_door_altar(w)
		var lowest := Vector2i(-1, -1)
		for c in m.room["door"]:
			if c.x <= int(m.room["x0"]) + 1 and c.y > lowest.y:
				lowest = c
		var stand := Vector2(float(m.room["left"]) - 6.0, (lowest.y + 1) * TILE)
		var pl: Node2D = w.player
		pl.reset_at(stand)
		pl.facing = 1
		var wd: Node2D = m.warden
		var hp0: float = wd.hp
		var t := 0.0
		for i in int(20.0 / DT):
			t += DT
			w.test_pad = _fight_pad(cls, t, 1)
			w._read_pad()
			w.tick(DT)
			if pl.position.x > stand.x:
				pl.position.x = stand.x
		_check(wd.alive and absf(wd.hp - hp0) < 0.01 and not m.sealed and m.dormant,
				"%s: a %s in the doorway can't touch the sleeping Warden (hp %.0f -> %.0f, sealed %s)" % [id, cls, hp0, wd.hp, m.sealed])
		await _done(w)


static func _stand_spots(lv: RefCounted, x0: int, x1: int) -> Array:
	## Every floor or ledge top in the room with two air cells over it.
	var out := []
	for x in range(x0, x1 + 1):
		for y in range(1, lv.height):
			var t: int = lv.tile(x, y)
			if (LevelData.is_solid(t) or LevelData.is_ledge(t)) and lv.tile(x, y - 1) == LevelData.AIR and (y < 2 or lv.tile(x, y - 2) == LevelData.AIR):
				out.append(Vector2i(x, y - 1))
	return out


func _test_stand_still(id: String) -> void:
	## Standing still in the sealed room and fighting: hurt before the Warden
	## falls, or it doesn't fall in 60 s (a spot where 30 s leave it unhurt is
	## out of reach, and ends there). Every calling takes every third spot
	## in turn (all of them with WAXBY_SLOW=1).
	var lv = LevelData.load_file(_path(id))
	var raw := str(lv.headers.get("warden_room", "")).split("-")
	if raw.size() != 2:
		return
	var spots := _stand_spots(lv, int(raw[0]) + 2, int(raw[1]) - 2)
	var every := 1 if OS.get_environment("WAXBY_SLOW") != "" else 3
	var runs := 0
	var hurt := 0
	var t0 := Time.get_ticks_msec()
	for ci in CALLINGS.size():
		var cls: String = CALLINGS[ci]
		for si in spots.size():
			if (si + ci) % every != 0:
				continue
			var spot: Vector2i = spots[si]
			var w := _fighter(id, cls)
			await process_frame
			w.hud = _stub_hud()
			var m = _room_mod(w)
			_to_door_altar(w)
			var pl: Node2D = w.player
			pl.reset_at(Vector2((spot.x + 0.5) * TILE, (spot.y + 1) * TILE))
			var took := 0.0
			var last: float = pl.hp
			var t := 0.0
			var killed := false
			var hp0: float = m.warden.hp if m.warden != null else 0.0
			for i in int(60.0 / DT):
				t += DT
				var wd = m.warden
				var toward := 0
				if wd != null and is_instance_valid(wd):
					toward = 1 if wd.position.x > pl.position.x else -1
				w.test_pad = _fight_pad(cls, t, toward)
				w._read_pad()
				w.tick(DT)
				if pl.hp < last:
					took += last - pl.hp
				last = pl.hp
				if took > 0.0 or not pl.alive or w.state != "play":
					break
				if m.phase == "won":
					killed = true
					break
				if t >= 30.0 and m.warden != null and is_instance_valid(m.warden) and absf(float(m.warden.hp) - hp0) < 0.01:
					break            # 30 s and not a scratch on it: out of his reach from here
			runs += 1
			hurt += 1 if took > 0.0 else 0
			_check(not (killed and took <= 0.0), "%s: a %s L%d standing at %s kills the Warden unhurt (%.1f s)" % [id, cls, _hero_level(id), spot, t])
			await _done(w)
	print("  %s standing still: %d fights, %d hurt first, the rest never won (%d ms)" % [id, runs, hurt, Time.get_ticks_msec() - t0])
