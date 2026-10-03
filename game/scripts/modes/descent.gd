extends "res://scripts/modes/mode.gd"
## The Endless Descent (spec §7.2): "The Hush dreams". A run is a stack of
## depths, each one level stitched in memory from a biome's rooms (rooms.gd):
## a landing, challenge rooms, then the bell (plain), a Deepwarden's sealed
## room (d mod 5 = 3) or the biome boss's arena ("A Dream of ...", d mod 5 =
## 0). Ringing the bell drops Waxby to the next depth after a short fade (no
## results between depths). Carried along: life %, resource, flask charges,
## Spare Wicks, Glimmers, Hushings, time and kills.
##
## - The ramp: area_abs = area_level(A_END, diff) - 5 + min(d, 10) +
##   floor(max(d - 10, 0) / 2), capped at 60 (descent_data.gd); room tiers,
##   deep overlays (from depth 8 / 14 / 20, six sooner once Deepened),
##   elites by depth, the deepening dark, a Hushing every five depths from 11.
## - The landing's altar, first lit, offers two Glimmers (or "Walk on" for
##   embers), and from depth 2 the landing has a gold reliquary: each pays
##   once a depth (run.offered, run.cache), however often its landing is
##   rebuilt. Death spends a Spare Wick (2 / 1 / 0) and relights at the last
##   altar; with none left the run ends ("The Deep keeps you"), keeping XP,
##   items, relics and banked embers.
## - A depth is 170-265 tiles: N challenge rooms (3 / 4 / 5) at the least,
##   and a short one takes another (_pick_rooms).
## - The flask is the hero's own (Game.flask_charges and flask_heal: the
##   Second Draught, Mother Taper's Match, the Rich Draught) and Deep Flask,
##   at most 3 charges.
## - Pause: "Rest here" in the landing (suspends free), "Leave the Descent"
##   past it (costs a Spare Wick; with none, it ends the run). An app kill
##   resumes free at the last landing: every landing saves the run. The
##   pause menu's own Restart / Leave (until it shows pause_items) ask twice
##   for anything that costs a Spare Wick or the run.
## - Records: the best depth cleared per calling and difficulty; milestones
##   (5, 10, 15, 20, 25, 30, 40, 50) pay the first time any calling in the
##   slot clears them on that difficulty, a cosmetic the first time on any.
##
## Opens once the Hush is beaten and homecoming seen (ModesSave.descent_open);
## --autoplay=descent:<d> starts a bot run at depth d.

const Data := preload("res://scripts/modes/descent_data.gd")
const Rooms := preload("res://scripts/modes/rooms.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const Progression := preload("res://scripts/progression.gd")
const Items := preload("res://scripts/items.gd")
const SELF := "res://scripts/modes/descent.gd"
const RESULTS := "res://scripts/modes/mode_results.gd"
const TILE := 32
const NEXT_AFTER := 1.2          # s after the bell before the next depth

var run := {}                    # the run (ModesSave.clean_run's shape)
var cls := "knight"
var built := {}                  # this depth: {text, spans, kind, biome, cycle, seal, landing_x1, warden_span, rooms}
var next_level: RefCounted = null   # the depth built next (kept when there's no main: tests)
var ended := ""                  # "" while it runs; else snuffed | ended | abandoned
var results := {}                # what mode_results.gd shows
var offers: Array = []           # the Glimmers on offer at the landing ([] = none)
var _offered := false
var _card_due := false           # the Glimmer cards wait for the depth's title card to go
var _card_wait := 0.0
var _warden_titled := false
var _sealed := false
var _warden_out := false
var _was_dead := false
var _cleared := false
var _clear_t := 0.0
var _echo_paid := false
var _paying := false
var _in_rooms := false           # past the landing (the first challenge room entered)
var _lit := []                   # altars lit at the last look
var _last_hp := -1.0
var _was_drinking := false
var _pill_t := 0.0
var _depth_t0 := 0.0             # run.time when this depth began
var _xp0 := 0
var _milestones_paid: Array = []
var _new_best := false


# ---------------------------------------------------------------- starting and resuming

static func depth_area(depth: int, diff_id: String) -> int:
	## A depth's area on a difficulty (the ramp, from area_level(A_END, diff)):
	## what test_progression's Descent XP-per-minute bound reads (PR's call).
	return Data.area_at(depth, a_end(diff_id))


static func make() -> Object:
	return load(SELF).new()


static func new_run(cls_id: String, diff_id: String, strength_id := "normal", start_depth := 1, seed_v := -1) -> Dictionary:
	## A fresh run's state (the suspended-run shape).
	# A fresh seed fits 31 bits (the save keeps any seed exactly; this keeps
	# it friendly to anything that reads it as a 32-bit int).
	var sd := seed_v if seed_v >= 0 else (hash(cls_id + diff_id + str(Time.get_unix_time_from_system()) + str(Time.get_ticks_usec())) & 0x7fffffff)
	return {"diff": diff_id, "seed": sd, "start": start_depth, "depth": start_depth, "strength": strength_id,
			"hp": 1.0, "res": -1.0, "flask": -1, "spare": int(Data.SPARE.get(diff_id, 0)), "glimmers": {}, "hushings": {},
			"time": 0.0, "kills": 0, "elites": 0, "items": 0, "embers": 0, "history": [], "level": 1, "spare_used": 0, "hp_at": [],
			"offered": 0, "cache": 0}


static func start(main_node: Node, cls_id: String, diff_id: String, strength_id := "normal", start_depth := 1, seed_v := -1) -> Object:
	## A new run for a calling, built and played (main.play_custom).
	var m = make()
	m.main = main_node
	m.cls = cls_id
	m.setup(new_run(cls_id, diff_id, strength_id, start_depth, seed_v))
	var g := game()
	if g != null:
		var d: Dictionary = ModesSave.block(g)["descent"]
		d["runs_total"] = int(d.get("runs_total", 0)) + 1
		d["diff"] = diff_id
		m.run["level"] = int(g.hero().get("level", 1))
	m.begin()
	return m


static func resume(main_node: Node, cls_id: String) -> Object:
	## A calling's suspended run, from its last landing (null when it has none).
	var g := game()
	if g == null:
		return null
	var runs: Dictionary = ModesSave.block(g)["descent"]["runs"]
	var r = ModesSave.clean_run(runs.get(cls_id, {}))
	if r.is_empty():
		runs.erase(cls_id)
		return null
	var m = make()
	m.main = main_node
	m.cls = cls_id
	m.setup(r)
	m.begin()
	return m


static func end_suspended(cls_id: String) -> bool:
	## The Descent screen's "End run": the suspended run is let go.
	var g := game()
	if g == null:
		return false
	var runs: Dictionary = ModesSave.block(g)["descent"]["runs"]
	if not runs.has(cls_id):
		return false
	runs.erase(cls_id)
	g.save()
	return true


static func autoplay(main_node: Node, arg: String) -> void:
	## --autoplay=descent:<d>: the bot plays from depth d (Dusk, the calling in the save).
	var g := game()
	ModesSave.force_open = true
	var d := maxi(int(arg), 1) if arg.is_valid_int() else 1
	var c := str(g.hero_id()) if g != null else "knight"
	start(main_node, c, "dusk", "normal", d, 1234)


func setup(r: Dictionary) -> void:
	id = "descent"
	run = r
	mode_diff = str(r.get("diff", "dusk"))
	mode_strength = str(r.get("strength", "normal"))


func begin() -> void:
	## Builds the run's current depth and plays it (every Hushing due by now
	## rolled in first: a deeper start's, P2's Landing Candles, get theirs).
	_roll_hushings_to(int(run["depth"]))
	var g := game()
	_xp0 = int(g.hero().get("xp", 0)) if g != null else 0
	var data := level_data()
	if main != null:
		play(data)
	else:
		next_level = data


# ---------------------------------------------------------------- the biomes

static func available() -> Array:
	## The biomes whose rooms are built and whose boss level is in the game.
	var g := game()
	var out: Array = []
	for b in Data.BIOMES:
		if not Rooms.exists(str(b["id"])):
			continue
		var lvl := str(b["boss_level"])
		var ok := FileAccess.file_exists("res://levels/%s.txt" % lvl)
		if g != null and g.has_method("index_of"):
			ok = ok and int(g.index_of(lvl)) >= 0
		if ok:
			out.append(str(b["id"]))
	return out


func biome_at(d: int) -> Dictionary:
	## {biome, cycle, stratum} for depth d (the biomes in world order, then Deepened).
	var av := available()
	if av.is_empty():
		av = ["cathedral"]
	var stratum := (d - 1) / 5
	return {"biome": str(av[stratum % av.size()]), "cycle": stratum / av.size(), "stratum": stratum}


func area_at(d: int) -> int:
	return Data.area_at(d, a_end(mode_diff))


# ---------------------------------------------------------------- building a depth

func _rng(d: int, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(run["seed"]), d, what])
	return r


func _recent() -> Array:
	## The rooms of the last two depths (the history's names).
	var out: Array = []
	for h in run.get("history", []):
		out.append(str(h).get_slice(":", 1).trim_suffix("~"))
	return out


func build_depth(d: int) -> Dictionary:
	## Depth d's level, deterministic for (run seed, d, the history before it,
	## and whether its landing's reliquary was opened already).
	var bi := biome_at(d)
	var bid: String = bi["biome"]
	var cycle: int = bi["cycle"]
	var bdef := Data.biome(bid)
	var rooms := Rooms.load_bundle(bid)
	var rng := _rng(d, "rooms")
	var kind := Data.kind_at(d)
	var rush_path := "res://levels/rush/%s.txt" % str(bdef.get("boss", ""))
	if kind == "echo" and not FileAccess.file_exists(rush_path):
		kind = "plain"
	var n := Data.rooms_at(d)
	var n_challenge := n
	if kind == "warden":
		n_challenge = n - 1
	elif kind == "echo":
		n_challenge = 2
	var deep_on := _hush_level("swollen") > 0
	var rtext := FileAccess.get_file_as_string(rush_path) if kind == "echo" else ""
	# What isn't a challenge room, for the depth's length (Data.DEPTH_MIN to
	# DEPTH_MAX tiles): a short depth takes another challenge room, a long
	# one swaps its widest for a narrower (_pick_rooms).
	var fixed := int(Rooms.of_kind(rooms, "landing")[0]["width"])
	match kind:
		"warden":
			for k in ["rest", "warden", "bell"]:
				fixed += int(Rooms.of_kind(rooms, k)[0]["width"])
		"echo":
			var rr0 := Rooms.rows_of_level(rtext)
			if not rr0.is_empty():
				fixed += maxi((rr0[0] as String).length() - int(header_value(rtext, "cut")), 0)
		_:
			fixed += int(Rooms.of_kind(rooms, "bell")[0]["width"])
	var rest_w := int(Rooms.of_kind(rooms, "rest")[0]["width"])
	var plain := kind == "plain"
	# The rest room goes by the depth's own count (N), not the rooms a
	# short depth takes on (they fill its length; they don't earn a rest).
	var has_rest := plain and Data.has_rest(d, n_challenge, mode_diff)
	var width_of := func(ps: Array) -> int:
		var w := fixed
		for rm in ps:
			w += int(rm["width"])
		if plain and ps.size() >= 2 and has_rest:
			w += rest_w
		return w
	var picks := _pick_rooms(rooms, n_challenge, Data.tier_weights(d, cycle), rng, width_of)
	var parts: Array = []
	var landing: Dictionary = Rooms.of_kind(rooms, "landing")[0]
	if d < 2:
		landing = Rooms.strip(landing, "R")
	elif int(run.get("cache", 0)) == d:
		# Its reliquary was opened before this landing was rebuilt (Rest here
		# and Resume, an app kill, a restart there): it stands spent.
		landing = Rooms.swap(landing, "R", "U")
	parts.append(landing)
	var names: Array = []
	for i in picks.size():
		var rm: Dictionary = picks[i]
		var at := int(rm["deep"]["at"]) - (Data.DEEP_EARLY if cycle >= 1 else 0)
		if deep_on or d >= at:
			rm = Rooms.with_deep(rm)
		parts.append(rm)
		names.append("%d:%s" % [d, rm["name"]])
		if plain and i == 1 and has_rest:
			parts.append(Rooms.of_kind(rooms, "rest")[0])
	var dread := ""
	var boss_id := ""
	var boss_music := ""
	match kind:
		"warden":
			parts.append(Rooms.of_kind(rooms, "rest")[0])
			parts.append(Rooms.of_kind(rooms, "warden")[0])
			parts.append(Rooms.of_kind(rooms, "bell")[0])
			dread = _warden_line(d, bdef, Rooms.of_kind(rooms, "warden")[0])
		"echo":
			pass
		_:
			parts.append(Rooms.of_kind(rooms, "bell")[0])
	var j := Rooms.join(parts)
	var rows: Array = j["rows"]
	var spans: Array = j["spans"]
	var overlay: String = j["overlay"]
	var cog_phase: Dictionary = j["cog_phase"]
	var weight_phase: Dictionary = j["weight_phase"]
	if kind == "echo":
		var rrows := Rooms.rows_of_level(rtext)
		var cut := int(header_value(rtext, "cut"))
		var x0 := (rows[0] as String).length()
		var arena := Rooms.cols(rrows, cut)
		rows = Rooms.append_cols(rows, arena)
		overlay = overlay.rpad(x0, ".")
		spans.append({"name": "arena", "kind": "arena", "x0": x0, "x1": x0 + (arena[0] as String).length() - 1, "tier": 0})
		boss_id = str(bdef["boss"])
		boss_music = header_value(rtext, "boss_music")
	# The signs' hints (by the sign's column), in reading order.
	var sign_text := {}
	for k in parts.size():
		var sp: Dictionary = spans[k]
		var rm2: Dictionary = parts[k]
		for y in Rooms.H:
			var r: String = rm2["rows"][y]
			for x in r.length():
				if r[x] == "@":
					sign_text[int(sp["x0"]) + x] = _sign_line(str(rm2.get("hint", "")), d)
	# The warden room's doors, absolute; the landing's cart.
	var seal := PackedStringArray()
	var warden_span := {}
	for sp in spans:
		if sp["kind"] == "warden":
			warden_span = sp
			for c in Rooms.of_kind(rooms, "warden")[0]["seal"]:
				seal.append("%d,%d" % [int(sp["x0"]) + (c as Vector2i).x, (c as Vector2i).y])
	var cart := landing["cart"] as Vector2i
	var room_list := PackedStringArray()
	for sp in spans:
		room_list.append("%s@%d-%d" % [sp["name"], sp["x0"], sp["x1"]])
	var theme: String = bdef["themes"][absi(hash([int(run["seed"]), d, "theme"])) % (bdef["themes"] as Array).size()]
	var subtitle := str(bdef["name"]) + (", Deepened" if cycle >= 1 else "")
	var title := "Depth %d" % d
	if kind == "echo":
		subtitle = "A Dream of %s" % _boss_name(boss_id)
	# The Descent's own stem set once A6's stems are in: the World's
	# play_music keeps a set already playing, so it runs on from depth to depth.
	var music := "descent" if stems_ready() else str(bdef["music"])
	var header := [["title", title], ["subtitle", subtitle], ["music", music], ["theme", theme],
			["area", str(area_at(d))], ["area_abs", str(area_at(d))], ["boss", boss_id], ["boss_music", boss_music],
			["dread", dread], ["depth", str(d)], ["kind", kind], ["biome", bid], ["cycle", str(cycle)],
			["rooms", ",".join(room_list)], ["seal", ";".join(seal)],
			["cart", "%d,%d" % [cart.x, cart.y] if cart.x >= 0 else ""],
			["gusts", Rooms.gusts_header(overlay)], ["hush", Rooms.hush_header(overlay)],
			["cog_phase", Rooms.phases_header(cog_phase)], ["weight_phase", Rooms.phases_header(weight_phase)],
			["hints", Rooms.hints_for(rows, sign_text)]]
	var text := Rooms.level_text(header, rows)
	return {"text": text, "spans": spans, "kind": kind, "biome": bid, "cycle": cycle, "world": int(bdef["world"]),
			"landing_x1": int(spans[0]["x1"]), "warden_span": warden_span, "rooms": names, "seal": seal}


func _pick_rooms(rooms: Array, n: int, weights: Array, rng: RandomNumberGenerator, width_of := Callable()) -> Array:
	## n challenge rooms by the tier weights: no repeats in the depth, none
	## from the last two depths while others are left, at least one tagged
	## combat and one platform, each flipped half the time when it may be.
	## width_of(picks) -> the depth's tiles: while it's under DEPTH_MIN
	## another room joins; while it's over DEPTH_MAX the widest is swapped
	## for the narrowest that keeps the tags.
	var recent := _recent()
	var used := {}
	var out: Array = []
	for i in n:
		var rm := _draw_room(rooms, weights, rng, used, recent)
		used[rm["name"]] = true
		out.append(rm)
	for tag in ["combat", "platform"]:
		if out.is_empty() or out.any(func(r): return (r["tags"] as Array).has(tag)):
			continue
		var pool := Rooms.of_kind(rooms, "challenge").filter(func(r): return (r["tags"] as Array).has(tag) and not used.has(r["name"]))
		if not pool.is_empty():
			var rm: Dictionary = pool[rng.randi() % pool.size()]
			var k := out.size() - 1
			used.erase(out[k]["name"])
			used[rm["name"]] = true
			out[k] = rm
	if width_of.is_valid():
		var guard := 0
		while int(width_of.call(out)) < Data.DEPTH_MIN and guard < 4:
			guard += 1
			if Rooms.of_kind(rooms, "challenge").all(func(r): return used.has(r["name"])):
				break
			var rm := _draw_room(rooms, weights, rng, used, recent)
			used[rm["name"]] = true
			out.append(rm)
		guard = 0
		while int(width_of.call(out)) > Data.DEPTH_MAX and guard < 6:
			guard += 1
			var wi := 0
			for i in out.size():
				if int(out[i]["width"]) > int(out[wi]["width"]):
					wi = i
			var others := out.duplicate()
			others.remove_at(wi)
			var keeps := func(r: Dictionary) -> bool:
				for tag in ["combat", "platform"]:
					if out.any(func(o): return (o["tags"] as Array).has(tag)) and not (r["tags"] as Array).has(tag) and not others.any(func(o): return (o["tags"] as Array).has(tag)):
						return false
				return true
			var pool := Rooms.of_kind(rooms, "challenge").filter(func(r): return not used.has(r["name"]) and int(r["width"]) < int(out[wi]["width"]) and keeps.call(r))
			if pool.is_empty():
				break
			pool.sort_custom(func(a, b): return int(a["width"]) < int(b["width"]) or (int(a["width"]) == int(b["width"]) and str(a["name"]) < str(b["name"])))
			var rm: Dictionary = pool[0]
			used.erase(out[wi]["name"])
			used[rm["name"]] = true
			out[wi] = rm
	var flipped: Array = []
	for rm in out:
		flipped.append(Rooms.mirrored(rm) if bool(rm["mirror"]) and rng.randf() < 0.5 else rm)
	return flipped


func _draw_room(rooms: Array, weights: Array, rng: RandomNumberGenerator, used: Dictionary, recent: Array) -> Dictionary:
	## One challenge room of a tier drawn by the weights, not used in this
	## depth (nor the last two while others are left).
	var tier := _draw_tier(weights, rng)
	var pool := Rooms.of_kind(rooms, "challenge", tier).filter(func(r): return not used.has(r["name"]) and not recent.has(r["name"]))
	if pool.is_empty():
		pool = Rooms.of_kind(rooms, "challenge").filter(func(r): return not used.has(r["name"]) and not recent.has(r["name"]))
	if pool.is_empty():
		pool = Rooms.of_kind(rooms, "challenge").filter(func(r): return not used.has(r["name"]))
	if pool.is_empty():
		pool = Rooms.of_kind(rooms, "challenge")
	return pool[rng.randi() % pool.size()]

static func _draw_tier(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var x := rng.randf() * total
	for i in weights.size():
		x -= float(weights[i])
		if x < 0.0 and float(weights[i]) > 0.0:
			return i + 1
	for i in range(weights.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return i + 1
	return 1


func _warden_line(d: int, bdef: Dictionary, wroom: Dictionary) -> String:
	## "Name|kind|Omen,Omen": a Deepwarden from the biome's pool (never the
	## same name twice in a run), a kind that stands where the room's D is,
	## 2 Omens (3 on Witching or from depth 21), NEVER_ON respected.
	var r := _rng(d, "warden")
	var names: Array = (bdef["wardens"] as Array).duplicate()
	var used: Array = run.get("wardens", [])
	var left := names.filter(func(n): return not used.has(n))
	if left.is_empty():
		left = names
	var name: String = left[r.randi() % left.size()]
	var kinds: Array = (bdef["warden_kinds"] as Dictionary).get(str(wroom.get("spawn", "floor")), ["skeleton"])
	var kind: String = kinds[r.randi() % kinds.size()]
	var n_omens := Data.WARDEN_OMENS + (1 if mode_diff == "witching" or d >= Data.OMEN_FROM else 0)
	var omens: Array = []
	var pool := _omens_for(kind)
	while omens.size() < n_omens and not pool.is_empty():
		var o: String = pool[r.randi() % pool.size()]
		pool.erase(o)
		omens.append(o)
	return "%s|%s|%s" % [name, kind, ",".join(omens)]


static func _omens_for(kind: String) -> Array:
	var sc = load("res://scripts/elites.gd")
	var cm: Dictionary = (sc as Script).get_script_constant_map() if sc != null else {}
	var all: Array = cm.get("OMENS", ["Swift", "Warded", "Burning", "Twinned", "Vengeful"])
	var never: Dictionary = cm.get("NEVER_ON", {})
	# The five v2 Omens only, until MA's four new ones land (their code, not just their names).
	var out: Array = []
	for o in all:
		if ["Swift", "Warded", "Burning", "Twinned", "Vengeful"].has(o) and not (never.get(o, []) as Array).has(kind):
			out.append(o)
	return out


func _sign_line(hint: String, d: int) -> String:
	var line := "Rest here from the pause menu."
	var hs: Array = run.get("hush_new", [])
	if Data.hush_due(d) and not hs.is_empty():
		var h: Dictionary = Data.HUSHINGS.get(str(hs[hs.size() - 1]), {})
		line = "A Hushing settles: %s." % str(h.get("name", ""))
	return hint.replace("{depth}", str(d)).replace("{line}", line)


static func _boss_name(b: String) -> String:
	return {"tollgrave": "Old Tollgrave", "snuffer": "the Snuffer", "rootmother": "Mother Gravebough",
			"tinker": "the Tinker of Hours", "saint": "the Prism Saint", "hush": "the Hush"}.get(b, b)


func level_data() -> RefCounted:
	var d := int(run["depth"])
	built = build_depth(d)
	var lv := parse_level(built["text"], "descent-%d" % d, int(built["world"]))
	boss_opts = {}
	if built["kind"] == "echo":
		boss_opts = {"rush": true, "mods": [], "hp_mult": Data.ECHO_HP, "area": area_at(d), "echo": true}
	return lv


# ---------------------------------------------------------------- the Glimmers and Hushings

func glimmer(gid: String) -> int:
	return int((run.get("glimmers", {}) as Dictionary).get(gid, 0))


func _hush_level(hid: String) -> int:
	return int((run.get("hushings", {}) as Dictionary).get(hid, 0))


func _hush_total() -> int:
	var n := 0
	for k in run.get("hushings", {}):
		n += int(run["hushings"][k])
	return n


func _hushings_due(d: int) -> int:
	return 0 if d < Data.HUSH_FROM else (d - Data.HUSH_FROM) / Data.HUSH_EVERY + 1


func _roll_hushings_to(d: int) -> void:
	while _hush_total() < _hushings_due(d):
		_add_hushing(Data.HUSH_FROM + _hush_total() * Data.HUSH_EVERY)


func _add_hushing(d: int) -> String:
	## The Hushing due at depth d: seeded, all eight before any repeats, then
	## each one deepens one of those already on.
	var r := _rng((d - 1) / 5, "hush")
	var hs: Dictionary = run["hushings"]
	var fresh := Data.HUSH_ORDER.filter(func(h): return not hs.has(h))
	var pick := ""
	if not fresh.is_empty():
		pick = fresh[r.randi() % fresh.size()]
	else:
		pick = Data.HUSH_ORDER[r.randi() % Data.HUSH_ORDER.size()]
	hs[pick] = int(hs.get(pick, 0)) + 1
	if not run.has("hush_new"):
		run["hush_new"] = []
	(run["hush_new"] as Array).append(pick)
	return pick


func glimmer_offers(d: int) -> Array:
	## Two Glimmers for depth d's landing (seeded), none at its cap; the
	## Spare Wick only while you have none, once a run.
	var r := _rng(d, "glimmer")
	var pool: Array = []
	for gid in Data.GLIMMER_ORDER:
		if glimmer(gid) >= int(Data.GLIMMERS[gid]["max"]):
			continue
		if gid == "g_spare" and (int(run["spare"]) > 0 or bool(run.get("spare_glimmer", false))):
			continue
		if gid == "g_flask" and _base_flask() >= FLASK_MAX:
			continue   # charges never exceed 3: a fourth would do nothing
		pool.append(gid)
	var out: Array = []
	while out.size() < 2 and not pool.is_empty():
		var gid: String = pool[r.randi() % pool.size()]
		pool.erase(gid)
		out.append(gid)
	return out


func choose_glimmer(i: int) -> void:
	## A Glimmer card tapped (i), or -1: "Walk on" (embers instead).
	if offers.is_empty():
		return
	if i >= 0 and i < offers.size():
		var gid: String = offers[i]
		run["glimmers"][gid] = glimmer(gid) + 1
		if gid == "g_spare":
			run["spare"] = mini(int(run["spare"]) + 1, Data.SPARE_MAX)
			run["spare_glimmer"] = true
		if gid == "g_flask" and world != null:
			world.flask_charges = _flask_cap()
		play_sfx("glimmer")
		toast(str(Data.GLIMMERS[gid]["name"]), str(Data.GLIMMERS[gid]["text"]))
	else:
		var g := game()
		var e := Data.WALK_ON * int(Combat.diff(mode_diff)["embers"])
		if g != null:
			g.add_embers(e)
			g.save()
		toast("Walk on", "+%d embers" % e)
	offers = []
	# Taken (or walked past) once: a rebuilt landing offers nothing more.
	run["offered"] = int(run["depth"])
	if world != null:
		world.paused = false
		world.apply_hero()
	if hud != null and hud.has_method("close_card"):
		hud.close_card()
	_snapshot()
	_pill()


# ---------------------------------------------------------------- the World's hooks

func on_build(w: Node) -> void:
	super.on_build(w)
	var d := int(run["depth"])
	var p: Node2D = w.player
	p.hp = clampf(float(run.get("hp", 1.0)), 0.05, 1.0) * p.max_hp
	if float(run.get("res", -1.0)) >= 0.0:
		p.res = clampf(float(run["res"]), 0.0, p.res_max)
	var fl := int(run.get("flask", -1))
	w.flask_charges = _flask_cap() if fl < 0 else mini(fl, _flask_cap())
	w.dim("descent:dark", Data.dark_at(d), 1.0e9)
	if _hush_level("hungry") > 0:
		w.dim("descent:hungry", pow(0.9, _hush_level("hungry")), 1.0e9)
	if not w.enemy_killed.is_connected(_on_kill):
		w.enemy_killed.connect(_on_kill)
	_lit = []
	for a in w.altars:
		_lit.append(bool(a["lit"]))
	_offered = int(run.get("offered", 0)) == d
	offers = []
	_card_due = false
	_card_wait = 0.0
	_warden_titled = false
	_sealed = false
	_warden_out = false
	_was_dead = false
	_cleared = false
	_clear_t = 0.0
	_echo_paid = false
	_in_rooms = false
	_last_hp = p.hp
	_depth_t0 = float(run["time"])
	_music(w, d)
	_snapshot()
	_pill()
	var hs: Array = run.get("hush_new", [])
	if Data.hush_due(d) and not hs.is_empty():
		var h: Dictionary = Data.HUSHINGS.get(str(hs[hs.size() - 1]), {})
		toast("A Hushing settles: %s" % str(h.get("name", "")), str(h.get("says", "")))
		play_sfx("hushing")
		run["hush_new"] = []


static func stems_ready() -> bool:
	## A6's three Descent stems are in the build.
	for stem in ["descent_floor", "descent_drive", "descent_deep"]:
		if not ResourceLoader.exists("res://audio/%s.wav" % stem):
			return false
	return true


func _music(w: Node, d: int) -> void:
	## The descent stems once A6's files are in (descent_floor always,
	## descent_drive from depth 10, descent_deep from 25; the depth's music:
	## header names the set, so the World's play_music keeps it running from
	## depth to depth and only the levels glide); until then the biome's own
	## music, which the World has started.
	var sx := sfx()
	if bool(w.get("headless")) or sx == null or not sx.has_method("play_stems") or not stems_ready():
		return
	var lv := stem_levels(d)
	var was := str(sx.music_playing()) if sx.has_method("music_playing") else ""
	sx.play_stems("descent", lv)
	if was == "descent" and sx.has_method("set_stem"):
		# Deeper in the same run: the new stage glides in over 3 s (A6).
		for stem in lv:
			sx.set_stem(stem, float(lv[stem]), 3.0)


static func stem_levels(d: int) -> Dictionary:
	## The stems' levels by depth (A6's stages, each within 0.8 dB of the other
	## cues on a phone): the floor alone (+2.5 dB) to depth 9, the drive in
	## from 10 (floor +1.5), the deep from 25 (all at 0), from 40 the drive
	## back to -6 and the deep up to +2.
	if d >= 40:
		return {"descent_floor": 0.0, "descent_drive": -6.0, "descent_deep": 2.0}
	if d >= 25:
		return {"descent_floor": 0.0, "descent_drive": 0.0, "descent_deep": 0.0}
	if d >= 10:
		return {"descent_floor": 1.5, "descent_drive": 0.0, "descent_deep": -80.0}
	return {"descent_floor": 2.5, "descent_drive": -80.0, "descent_deep": -80.0}


func _base_flask() -> int:
	## The hero's own charges on the run's difficulty (DIFF's, the Second
	## Draught, Mother Taper's Match: Game.flask_charges).
	return base_flask(mode_diff)


func _flask_cap() -> int:
	## The run's flask: the hero's charges and Deep Flask, never more than 3.
	return mini(_base_flask() + glimmer("g_flask"), FLASK_MAX)


func flask_max() -> int:
	## (W0's world.flask_max asks a mode for this once it's wired.)
	return _flask_cap()


func flask_heal() -> float:
	## A drink's share of life: the hero's own (the Rich Draught, flask_pct).
	return base_flask_heal(mode_diff)


func on_tick(w: Node, dt: float) -> void:
	tick_look(w)
	if ended != "":
		return
	if not offers.is_empty() and hud != null and hud.get("card") == "glimmer":
		# The pause menu let the World go under the Glimmer cards: hold it.
		w.paused = true
		return
	var p: Node2D = w.player
	if w.state == "play":
		run["time"] = float(run["time"]) + dt
	# Past the landing?
	if not _in_rooms and p.position.x > (int(built.get("landing_x1", 17)) + 1) * TILE:
		_in_rooms = true
	# An altar lit this tick: the flask to the run's cap (the hero's charges
	# and Deep Flask), Dry Well's cut, and the landing's first lighting
	# offers the Glimmers (once a depth: run.offered survives a rebuild).
	for i in w.altars.size():
		var a: Dictionary = w.altars[i]
		var was: bool = _lit[i] if i < _lit.size() else false
		if a["lit"] and not was:
			w.flask_charges = _flask_cap()
			if _hush_level("dry") > 0 and _last_hp >= 0.0 and p.hp > _last_hp:
				p.hp = _last_hp + (p.hp - _last_hp) * pow(Data.DRY_HEAL, _hush_level("dry"))
			if a["cell"].x <= int(built.get("landing_x1", 17)) and not _offered:
				_offered = true
				(run["hp_at"] as Array).append(roundi(p.life_frac() * 100.0))
				offers = glimmer_offers(int(run["depth"]))
				if not offers.is_empty():
					if w.autoplay or headless or bool(w.get("headless")):
						if w.autoplay:
							choose_glimmer(0)
					else:
						_card_due = true
						_card_wait = 0.0
		if i < _lit.size():
			_lit[i] = bool(a["lit"])
		else:
			_lit.append(bool(a["lit"]))
	if _card_due:
		_open_glimmers(w, dt)
	# The landing's gold reliquary, once opened, stays spent for this depth.
	if int(run.get("cache", 0)) != int(run["depth"]) and _cache_opened(w):
		run["cache"] = int(run["depth"])
		_snapshot()
	# Drinks: the hero's own draught (the Rich Draught, flask_pct), less
	# under Dry Well (its last sip lands as the drink ends).
	var drinking: bool = float(w.get("_flask_t")) >= 0.0
	var k := _drink_k(w)
	if absf(k - 1.0) > 0.0001 and (drinking or _was_drinking) and _last_hp >= 0.0 and p.hp > _last_hp:
		p.hp = minf(_last_hp + (p.hp - _last_hp) * k, p.max_hp)
	_was_drinking = drinking
	_last_hp = p.hp
	_tick_warden(w)
	_tick_echo(w)
	_retitle_warden(w)
	# The snuff's relight: the warden room opens, its warden back at full life.
	var dead: bool = w.state == "dead"
	if _was_dead and not dead:
		_after_relight(w)
	_was_dead = dead
	# The bell: the depth is cleared; after a moment, the next.
	if w.state == "clear":
		if not _cleared:
			_cleared = true
			_clear_t = 0.0
			_depth_cleared(w)
		_clear_t += dt
		if _clear_t >= NEXT_AFTER and _clear_t - dt < NEXT_AFTER:
			_next_depth(w)
	_pill_t -= dt
	if _pill_t <= 0.0:
		_pill_t = 0.25
		_pill()
		_soak_check()


func _drink_k(w: Node) -> float:
	## What a drink should heal over what the World's drink gives: the hero's
	## own draught (until W0's flask_heal asks the mode), x Dry Well's cut.
	var given := float(w.flask_heal()) if w.has_method("flask_heal") else float(Combat.diff(mode_diff)["flask"])
	var k := flask_heal() / maxf(given, 0.001)
	return k * pow(Data.DRY_HEAL, _hush_level("dry"))


func _open_glimmers(w: Node, dt: float) -> void:
	## The Glimmer cards, once the depth's title card is out of the way: it's
	## cut short (it would sit under the cards while the World is paused),
	## and the cards open as it goes (at most 0.5 s later).
	_card_wait += dt
	if hud_title_showing(w) and _card_wait < 0.5:
		cut_hud_title(w)
		return
	_card_due = false
	w.paused = true
	if hud != null and hud.has_method("glimmer_card"):
		hud.glimmer_card(offers)


func _cache_opened(w: Node) -> bool:
	## The landing's gold reliquary has been opened (spent) this depth.
	var x1 := int(built.get("landing_x1", 17))
	for cell in w.blocks:
		var b: Dictionary = w.blocks[cell]
		if (cell as Vector2i).x <= x1 and str(b.get("contents", "")) == "relic" and bool(b.get("spent", false)):
			return true
	return false


func dread_title() -> String:
	## The HUD's Dread card line (SC's hook): a warden room's Dread is a
	## Deepwarden; "" leaves it "Dread".
	return "Deepwarden" if built.get("kind", "") == "warden" else ""


func _retitle_warden(w: Node) -> void:
	## The HUD titles a Dread "Dread": in a warden room it's a Deepwarden.
	if _warden_titled or built.get("kind", "") != "warden":
		return
	var t := hud_title(w)
	if t.is_empty() or str(t.get("sub", "")) != "Dread":
		return
	t["sub"] = "Deepwarden"
	_warden_titled = true


func _tick_warden(w: Node) -> void:
	var sp: Dictionary = built.get("warden_span", {})
	if sp.is_empty() or _warden_out:
		return
	var dr := _dread(w)
	if not _sealed:
		if dr != null and dr.alive and w.player.position.x > (int(sp["x0"]) + 6) * TILE and w.state == "play":
			_sealed = true
			Arena.seal(w, w.level, _seal_cells())
	elif dr == null or not dr.alive:
		_sealed = false
		_warden_out = true
		Arena.unseal(w, w.level, _seal_cells())
		toast("Deepwarden put out", "")


func _dread(w: Node) -> Node2D:
	for e in w.enemies:
		if is_instance_valid(e) and str(e.tier) == "dread":
			return e
	return null


func _seal_cells() -> Array:
	var out: Array = []
	for s in built.get("seal", []):
		out.append(Vector2i(int(str(s).get_slice(",", 0)), int(str(s).get_slice(",", 1))))
	return out


func _after_relight(w: Node) -> void:
	if _sealed:
		_sealed = false
		Arena.unseal(w, w.level, _seal_cells())
	var dr := _dread(w)
	if dr != null and dr.alive:
		dr.hp = dr.max_hp
		var cell: Vector2i = dr.spawn.get("cell", Vector2i(-1, -1))
		if cell.x >= 0:
			var ek = load("res://scripts/enemy_kinds.gd")
			dr.position = ek.spawn_pos(str(dr.kind), cell)
			dr.velocity = Vector2.ZERO
		dr.active = false
	# The World refilled the flask to DIFF's count: the run's is the hero's
	# own and Deep Flask.
	w.flask_charges = _flask_cap()
	_last_hp = w.player.hp


func _tick_echo(w: Node) -> void:
	## An echo boss pays the usual boss drops (a rush boss's boss_defeated
	## pays none) the moment it falls.
	if built.get("kind", "") != "echo" or _echo_paid:
		return
	var b = w.get("boss")
	if b != null and is_instance_valid(b) and not b.alive:
		_echo_paid = true
		_paying = true
		var at: Vector2 = b.center()
		w.drop_item(at, "boss")
		w.drop_item(at + Vector2(-16, -10), "boss")
		w.drop_item(at + Vector2(16, -10), "boss")
		_paying = false


func _on_kill(e: Node2D, _how: String) -> void:
	run["kills"] = int(run["kills"]) + 1
	if str(e.get("tier")) != "":
		run["elites"] = int(run["elites"]) + 1


func on_spawn(e: Node2D) -> void:
	if is_boss(e):
		apply_boss_fallback(e, Data.ECHO_HP)
		return
	var sharp := _hush_level("sharp")
	if sharp > 0:
		e.dmg_mult = float(e.dmg_mult) * pow(1.1, sharp)
	var stout := _hush_level("stout")
	if stout > 0:
		e.max_hp = float(e.max_hp) * pow(1.1, stout)
		e.hp = e.max_hp


func on_snuffed(w: Node) -> String:
	(run["hp_at"] as Array).append(0)
	if int(run["spare"]) > 0:
		run["spare"] = int(run["spare"]) - 1
		run["spare_used"] = int(run.get("spare_used", 0)) + 1
		var left := int(run["spare"])
		toast("Spare Wick lit", "%d left" % left if left != 1 else "1 left")
		_snapshot()
		return ""
	ended = "snuffed"
	_log(w)
	return "end"


func allows(what: String) -> bool:
	match what:
		"record":
			return false
		"loot":
			if _paying:
				return true
			# An echo boss's own boss_defeated would read the save's level
			# record (and make one for "descent-5"): the drops are paid here.
			var b = world.get("boss") if world != null else null
			if b != null and is_instance_valid(b) and not b.alive:
				return false
	return true


func stats_filter(s: Dictionary) -> Dictionary:
	var o := s.duplicate()
	o["max_hp"] = float(o["max_hp"]) * (1.0 + 0.08 * glimmer("g_wax")) * pow(0.92, _hush_level("thin"))
	o["dmg_pct"] = float(o.get("dmg_pct", 0.0)) + 0.08 * glimmer("g_edge")
	o["crit"] = float(o.get("crit", 0.0)) + 0.03 * glimmer("g_eye")
	o["light_pct"] = float(o.get("light_pct", 0.0)) + 0.08 * glimmer("g_bright")
	o["dr"] = minf(float(o.get("dr", 0.0)) + 0.03 * glimmer("g_ward"), Combat.DR_CAP)
	# Iron Heels: Hero.stats has already made stomp_pct into the stomp that
	# Combat.stomp_damage reads, so the derived value is scaled too.
	var sp0 := float(o.get("stomp_pct", 0.0))
	var heels := 0.30 * glimmer("g_heels")
	o["stomp_pct"] = sp0 + heels
	if o.has("stomp"):
		o["stomp"] = float(o["stomp"]) * (1.0 + sp0 + heels) / maxf(1.0 + sp0, 0.01)
	o["res_regen"] = float(o.get("res_regen", 0.0)) * (1.0 + 0.15 * glimmer("g_well"))
	return o


func tells_mult() -> float:
	return pow(0.93, _hush_level("quick"))


func elite_rules() -> Dictionary:
	var wn := int(built.get("world", 1))
	var base: Dictionary = Combat.elite_rules(mode_diff, wn)
	return Data.elite_rules(base, int(run["depth"]), _hush_level("anointed"))


func loot() -> Dictionary:
	return Data.loot_at(int(run["depth"]), glimmer("g_luck"), glimmer("g_embers"))


func result_extra() -> Dictionary:
	return {"depth": int(run["depth"]), "descent": true}


func pause_items() -> Array:
	if not _in_rooms:
		return [{"label": "Rest here", "cb": rest_here, "confirm": false},
				{"label": "End run", "cb": end_run, "confirm": true}]
	var label := "Leave the Descent (costs a Spare Wick)" if int(run["spare"]) > 0 else "Leave: this ends your run"
	return [{"label": label, "cb": leave, "confirm": true}]


func quit() -> void:
	## The pause menu's Leave (while its owner doesn't show pause_items): in
	## the landing, Rest here (free); past it, what costs something asks
	## twice (Leave again within 4 s): a Spare Wick for a suspend at this
	## depth's landing, or, with none, the run.
	if not _in_rooms:
		rest_here()
		return
	if int(run["spare"]) > 0:
		if arm("leave", "Leaving costs a Spare Wick", "Tap Leave again to rest at this depth's landing"):
			leave()
	elif arm("leave", "Leaving ends your run", "Tap Leave again to end it"):
		end_run()


func restart() -> void:
	## The pause menu's Restart: this depth again from its landing, free
	## there; past it, it costs a Spare Wick and asks twice (Restart again
	## within 4 s), and with none left there's no restart.
	if not _in_rooms:
		begin()
		return
	if int(run["spare"]) <= 0:
		resume_world()
		toast("No Spare Wick to restart with", "Leave from the pause menu ends the run")
		return
	if not arm("restart", "Restarting costs a Spare Wick", "Tap Restart again to go back to the landing"):
		return
	run = _landing.duplicate(true)
	run["spare"] = maxi(int(run["spare"]) - 1, 0)
	run["spare_used"] = int(run.get("spare_used", 0)) + 1
	begin()


func finished(res: Dictionary) -> void:
	if bool(res.get("cleared", false)):
		# The bell's own finish (3.4 s): the next depth has usually begun by now.
		return
	if ended == "":
		ended = "snuffed"
	_end_run()


# ---------------------------------------------------------------- depths, suspends, the end

var _landing := {}               # the run as it stood at this depth's landing (what a suspend keeps)


func _snapshot() -> void:
	## The run as it is at the landing, saved (an app kill resumes here).
	_landing = run.duplicate(true)
	var g := game()
	if g == null:
		return
	var runs: Dictionary = ModesSave.block(g)["descent"]["runs"]
	var snap := run.duplicate(true)
	snap.erase("hush_new")
	runs[cls] = snap
	g.save()


func _depth_cleared(w: Node) -> void:
	var d := int(run["depth"])
	var g := game()
	var p: Node2D = w.player
	# XP: a cleared depth pays 20 x E(A) (the World's bell paid its clear already).
	var extra := Progression.event_xp("depth", w.area) - Progression.event_xp("clear", w.area)
	if extra > 0:
		w.gain_xp(extra, p.position)
	run["items"] = int(run["items"]) + (w.items_found as Array).size()
	if g == null:
		return
	var before := int(ModesSave.descent_best(g, cls, mode_diff).get("depth", 0))
	_new_best = ModesSave.note_descent_best(g, cls, mode_diff, d, float(run["time"]), int(g.hero()["level"]), mode_strength) and d > before
	_pay_milestone(g, d)
	if Data.BARK_DEPTHS.has(d):
		w.bark("descent_%d" % d)
	elif _new_best and before > 0:
		w.bark("descent_record")
		play_sfx("record")
	toast("Depth %d cleared" % d, _clock(float(run["time"]) - _depth_t0))
	g.save()


func _pay_milestone(g: Node, d: int) -> void:
	if not Data.MILESTONES.has(d):
		return
	var marks: Array = ModesSave.block(g)["descent"]["milestones"][mode_diff]
	if marks.has(d):
		return
	marks.append(d)
	marks.sort()
	var m: Dictionary = Data.MILESTONES[d]
	var paid := {"depth": d}
	if m.has("embers"):
		var e := int(m["embers"]) * int(Combat.diff(mode_diff)["embers"])
		g.add_embers(e)
		paid["embers"] = e
	for i in int(m.get("legend", 0)):
		var r := RandomNumberGenerator.new()
		r.seed = hash([int(run["seed"]), d, "milestone", i])
		var h: Dictionary = g.hero()
		var slot := Items.pick_slot(r)
		var lg := Items.pick_legend(slot, str(h["cls"]), r, area_at(d), g.legends_found() if g.has_method("legends_found") else [])
		var it := Items.make(slot, str(h["cls"]), area_at(d), "legendary", r, lg)
		satchel_add(it)
		paid["legend"] = int(paid.get("legend", 0)) + 1
	for nid in Cosmetics.ids_for("descent:%d" % d):
		if g.grant_cosmetic(nid):
			paid["cosmetic"] = nid
			play_sfx("cosmetic_unlock")
	_milestones_paid.append(paid)
	toast("Milestone: depth %d" % d, _milestone_text(paid))


static func _milestone_text(paid: Dictionary) -> String:
	var bits := PackedStringArray()
	if paid.has("embers"):
		bits.append("+%d embers" % int(paid["embers"]))
	if paid.has("legend"):
		bits.append("a Legendary" if int(paid["legend"]) == 1 else "%d Legendaries" % int(paid["legend"]))
	if paid.has("cosmetic"):
		bits.append(Cosmetics.reward_name(str(paid["cosmetic"])))
	return " · ".join(bits)


func _next_depth(w: Node) -> void:
	var p: Node2D = w.player
	var d := int(run["depth"])
	var mend := 0.10 * glimmer("g_mend")
	run["hp"] = clampf(p.life_frac() + mend, 0.05, 1.0)
	run["res"] = float(p.res)
	run["flask"] = int(w.flask_charges)
	# The history: this depth's rooms and the last one's.
	var hist: Array = []
	for h in run.get("history", []):
		if int(str(h).get_slice(":", 0)) >= d - 1:
			hist.append(h)
	hist.append_array(built.get("rooms", []))
	run["history"] = hist
	run["depth"] = d + 1
	if run.has("wardens") or built.get("kind", "") == "warden":
		var used: Array = run.get("wardens", [])
		var dl := str(header_value(built["text"], "dread")).get_slice("|", 0)
		if dl != "" and not used.has(dl):
			used.append(dl)
		run["wardens"] = used
	play_sfx("descend")
	if (d + 1) % 5 == 0:
		# Every fifth depth a mark rings, a step up the scale each time (A7).
		var s := sfx()
		play_sfx("depth_mark", float(s.note(((d + 1) / 5) % 5)) if s != null and s.has_method("note") else 1.0)
	begin()


func rest_here() -> void:
	## Suspends the run at this landing, free (it's already saved there).
	_snapshot_as(_landing if not _landing.is_empty() else run)
	ended = "suspended"
	_unpause()
	to_screen("descent")


func leave() -> void:
	## Past the landing: a Spare Wick for a suspend at this depth's landing;
	## with none left, the run ends.
	if int(run["spare"]) <= 0:
		end_run()
		return
	var snap := _landing.duplicate(true)
	snap["spare"] = maxi(int(run["spare"]) - 1, 0)
	snap["spare_used"] = int(run.get("spare_used", 0)) + 1
	snap["kills"] = int(run["kills"])
	snap["time"] = float(run["time"])
	_snapshot_as(snap)
	ended = "suspended"
	_unpause()
	to_screen("descent")


func end_run() -> void:
	## Ends the run now (the landing's End run, or Leave with no Spare Wick).
	ended = "ended"
	_unpause()
	if world != null:
		_log(world)
	_end_run()


func _unpause() -> void:
	if world != null and is_instance_valid(world):
		world.paused = false


func _snapshot_as(snap: Dictionary) -> void:
	var g := game()
	if g == null:
		return
	var s := snap.duplicate(true)
	s.erase("hush_new")
	ModesSave.block(g)["descent"]["runs"][cls] = s
	g.save()


func _end_run() -> void:
	## The run is over: the suspended run is let go, the results are shown.
	var g := game()
	var cleared_to := int(run["depth"]) - 1
	var xp_now := int(g.hero().get("xp", 0)) if g != null else 0
	results = {"cls": cls, "diff": mode_diff, "depth": cleared_to, "reached": int(run["depth"]), "start": int(run["start"]),
			"time": float(run["time"]), "kills": int(run["kills"]), "elites": int(run["elites"]), "items": int(run["items"]),
			"xp": maxi(xp_now - _xp0, 0), "milestones": _milestones_paid.duplicate(true), "ended": ended,
			"best": int(ModesSave.descent_best(g, cls, mode_diff).get("depth", 0)) if g != null else 0,
			"new_best": _new_best, "spare_used": int(run.get("spare_used", 0))}
	if g != null:
		(ModesSave.block(g)["descent"]["runs"] as Dictionary).erase(cls)
		g.save()
	if headless or main == null:
		return
	if _soak() > 0.0:
		# --soak: the bot goes straight down again.
		start(main, cls, mode_diff, mode_strength, 1, int(run["seed"]) + 1)
		return
	if ended == "snuffed" and hud != null and hud.has_method("deep_keeps"):
		hud.deep_keeps(func(): _show_results())
	else:
		_show_results()


func _show_results() -> void:
	if main == null or not ResourceLoader.exists(RESULTS):
		to_screen("descent")
		return
	var r: Node = load(RESULTS).new()
	r.set("results", results)
	r.set("main", main)
	if main.has_method("_swap"):
		main._swap(r)


func _log(w: Node) -> void:
	## The playlog's Descent line (for tuning on the owner's play).
	if w == null or bool(w.get("headless")):
		return
	var pl = load("res://scripts/playlog.gd")
	if pl == null:
		return
	pl.write({"mode": "descent", "calling": cls, "diff": mode_diff, "depth": int(run["depth"]), "start": int(run["start"]),
			"ended": ended, "cause": str(w.snuff_causes.get("_last", "")), "level": int(game().hero()["level"]) if game() != null else 0,
			"time": snappedf(float(run["time"]), 0.1), "hp_at_landings": run.get("hp_at", []), "glimmers": run.get("glimmers", {}),
			"hushings": run.get("hushings", {}), "spare_used": int(run.get("spare_used", 0)),
			"at": Time.get_datetime_string_from_system()})


static var _soak_t0 := -1


func _soak() -> float:
	## main's --soak=<seconds> (the phone's 10-minute Descent soak), or 0.
	if main == null:
		return 0.0
	var v = main.get("soak")
	return float(v) if v != null else 0.0


func _soak_check() -> void:
	if _soak() <= 0.0:
		return
	if _soak_t0 < 0:
		_soak_t0 = Time.get_ticks_msec()
	if Time.get_ticks_msec() - _soak_t0 >= int(_soak() * 1000.0):
		print("[perf] soak done: %.0f s, depth %d" % [_soak(), int(run["depth"])])
		(Engine.get_main_loop() as SceneTree).quit()


func _pill() -> void:
	pill({"mode": "descent", "text": "D%d" % int(run["depth"]), "spare": int(run["spare"]),
			"spare_max": maxi(int(Data.SPARE.get(mode_diff, 0)), int(run["spare"])),
			"hushings": _hush_total(), "time": float(run["time"])})


static func _clock(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]
