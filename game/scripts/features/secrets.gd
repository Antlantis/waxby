extends "res://scripts/features/feature.gd"
## The secret levels' pieces (WLS, spec §3.8-§3.9, decisions "Secret-level
## ending"): the silver bell and its arch in a main level, and in a secret
## level the Warden's room, the shrine (the Lost Wick's grave candle), the
## prize and the silver bell that rises beside it.
##
## A main level's exit. An `S` whose level's `secret:` names an entry of
## Game.SECRET_LEVELS whose file is in the build becomes a silver bell inside
## its `secret_door` arch (world.add_bell(..., {silver: true}): ringing it
## clears the level by its other way out and sets result.secret; the World
## opens the secret level as it rings). Until then nothing is spawned: the
## cell stays air and the attic an empty nook. Its false stone (the seal) is
## every F bordering the attic the bell hangs in (else every F within
## SEAL_REACH of the bell, when it hangs in no closed attic). While it hangs
## unrung:
##   - the hum: `secret_hum` every HUM_EVERY s while Wick is within HUM_R of
##     the arch, at gain 1 - d / HUM_R (A7's play(sound, pitch, gain));
##   - its visual twin: the bell window and the false stone hiding it glint
##     with each hum, in any light (Wick's or a lamp's), and in the dark too
##     with the Owl's Eye; the window's full silver glow shows only inside
##     Wick's own light;
##   - the odd sight of its world (spec §3.9's hint ladder), at the seal:
##     moonlight through the crack (1), the guild's crest on the stone over
##     the third lamp (2), pale spores drifting up into the crack (3), steam
##     rising into the vent (4), a gilt glint on the stone over the lone lamp
##     (5), silver ripples round the one bell still chiming (6);
##   - the optional hint bark secret_hint_<w>, once, when Wick stands on the
##     floor within HINT_R of it (never mid-jump), while the secret is still
##     to find on this difficulty.
##
## A secret level (id "<w>-S"). Its last section is the Warden's room
## (header `warden_room: x0-x1`, the section's columns, walls included; else
## boss_arena.gd's find() from the bell's floor). Its `S` is where the silver
## bell rises; the shrine, the Lost Wick's grave candle, stands SHRINE_DX
## tiles from it on the same floor.
##   - Before the fight the Warden sleeps at its post: it is out of the
##     World's monster list (nothing hits it, nothing aims at it, it hurts no
##     one, it has no bar), drawn dim and still. A doorway is no place to
##     fight it from.
##   - The door seals (Arena.seal: every open cell of the room's two wall
##     columns at each end, "both doors") once Wick is inside, past the door,
##     and the Warden wakes as it does (a roar; the World wakes it, its bar).
##   - Awake, a Warden has poise: a kind that reels from a cut (REELS: the
##     Thornback) reels at most once every FLINCH_CD s, and a stagger
##     (status "stun": the maul, a Perfect Guard) that comes within STUN_CD s
##     of the last one is shaken off, so a stream of sparks, knives or blows
##     can't hold it off for good (MA's kit may take this over).
##   - A snuff in the sealed room unseals it and resets it, as a boss room:
##     a fresh Warden asleep at its post (world.warden is the new one), the
##     Hoarowl's calls and anything else it brought along gone; he relights
##     at the door altar (the World's checkpoint).
##   - When the Warden falls the door opens, the grave candle lights, the
##     Lost Wick speaks (first_lost_wick once, then Story.lost_wick_bark(w)),
##     the prize appears on the shrine (Game.secret_prize(id): the Legendary
##     on the first clear per difficulty, paid when picked up; a boss-weighted
##     item on later clears) and the silver bell rises beside it. Ringing it
##     ends the level (as a plain bell: the level has no secret: of its own).
##   - With no Warden at all (no monsters: the golden routes; its kind not in
##     the build; killed before an altar resume) the candle is lit and the
##     bell stands from the start.
##   - first_secret, once, on the first stone landing of a secret level.
##   - Header `anoint: x,y; x,y`: the monsters placed there are Anointed
##     every run (3-S's two wide knots, spec §3.9).
##   - A Warden whose kind lives in deep water (6-S's Lurecoil) keeps its D
##     cell water (level_data makes a D air; W0 may take this over).
##   - 1-S's crumbling slates carry a line of snow above the dark (so they
##     read against the gilt roofs behind them), gone while a slate is down.
##
## Every clock here reads world.ftime (it stops with stop_time).
##
## Art: art/props/secret_door, silver_bell (the World's), grave_candle_out /
## _lit and legend_shrine_out / _lit (A2's props_modes.py) when they exist,
## placed by A2's points_modes.json (the candle's "flame", the shrine's
## "prize"); else stand-ins drawn here in rects and one TriBatch per layer.

const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const UI := preload("res://scripts/ui.gd")
const STORY := "res://scripts/story.gd"
const ELITES := "res://scripts/elites.gd"
const POINTS := "res://art/props/points_modes.json"

const HUM_R := 320.0             # px: the hum reaches this far, falling off to nothing
const HUM_EVERY := 3.0           # s between hums
const HINT_R := 8.0 * TILE       # the hint bark fires this near the odd sight
const GLINT_LEN := 0.55          # s a glint lasts (it rises with each hum)
const WINDOW_UP := 58.0          # px over the arch's floor: the bell window's middle
const SEAL_REACH := 4            # tiles round the bell: the false stone that hides it (no attic)
const NOOK_REACH := 6            # the attic round a bell: at most this far from it...
const NOOK_MAX := 48             # ...and this many cells (else it's no attic)
const NOOK_WALL := Color(0.17, 0.14, 0.21)
const MOON := Color(0.78, 0.86, 1.0)
const CREST_UP := 104.0          # px over a lamp's floor: 2-2's guild crest on the wall above it
const SHRINE_DX := -2            # tiles from the risen bell to the grave candle
const SHRINE_R := 150.0          # the lit grave candle's light
const DOOR_PAST := 10.0          # px Wick must be past the door for it to seal
const PRIZE_AT := 0.9            # s after the Warden falls: the prize on the shrine
const RISE_AT := 1.5             # ...the silver bell starts to rise
const RISE_LEN := 1.2            # ...and hangs ready (its rope live) this long after
const RISE_FROM := 40.0          # px under its place it rises from
const START_BARK := 1.0          # s into a secret level before first_secret may fire
const FLINCH_CD := 1.2           # s: an awake Warden reels from a cut at most this often
const REELS := {"thornback": 0.3}   # kinds whose think() reels while flash > this
const STUN_CD := 2.5             # s: an awake Warden takes a stagger at most this often
const DORMANT := Color(0.46, 0.46, 0.58)   # the sleeping Warden, drawn dim
const CANDLE_BESIDE := 22.0      # px: A2's grave candle stands this far right of the shrine's foot (toward the bell)
const SILVER := Color("dfe8ff")
const GILT := Color("ffd84a")
const SNOW := Color(0.93, 0.96, 1.0)
const STONE_DARK := Color("2a2436")
const STONE_LIP := Color("4e4660")
const SHRINE_TINT := Color(1.0, 0.847, 0.29, 0.30)   # the art draft: r 150, ffd84a at 0.3
const WORLD_SIGHT := {1: "moon", 2: "crest", 3: "spores", 4: "steam", 5: "gilt", 6: "ripples"}
const PROPS := ["secret_door", "secret_door_glint", "grave_candle_out", "grave_candle_lit", "legend_shrine_out", "legend_shrine_lit"]
const GLINT_ANY := 0.22          # A2: the arch's glint sprite in any light (a lamp, a toll, the Owl's Eye)
const GLINT_HERO := 0.95         # ...and inside his own light
# A2's published anchors (frame units, 2 a pixel; points_modes.json wins when it's there).
const ANCHORS := {"grave_candle": {"foot": Vector2(32, 64), "flame": Vector2(43.8, 32)},
		"legend_shrine": {"foot": Vector2(32, 96), "prize": Vector2(32, 50)}}

var bells: Array = []            # the silver bells this module made (the World's bell dicts)
var exits: Array = []            # a main level's: {cell, floor, bell, seal: [Vector2i], t0}
var _hum_at := 0.0               # ftime of the next hum
var _hinted := false
var _tex := {}
var _pts := {}
var _tb := TriBatch.new()

# A secret level's.
var secret_level := false
var room := {}                   # {x0, x1 (columns, walls included), left, right (px, inside), door: [Vector2i]}
var sealed := false
var phase := ""                  # "" (no room) | wait | fight | won
var warden: Node2D = null
var warden_home := {}            # {kind, cell, name, omens}
var dormant := false             # the Warden sleeps at its post (out of world.enemies)
var shrine := {}                 # {floor, top, lit, light}
var bell := {}                   # the rising bell's dict (the World's), once made
var bell_cell := Vector2i(-1, -1)
var _won_at := -1.0              # ftime the Warden fell (or -1)
var _won_t := -1.0               # s since then (the tests read it)
var _prize_done := false
var _risen := false
var _start_barked := false
var _start_at := 0.0
var _reel_at := -99.0            # ftime of the Warden's last allowed reel
var _wflash := 0.0               # its flash after the last step
var _stun_at := -99.0            # ftime of the last stagger it took
var _was_stunned := false
var resets := 0                  # room resets so far (the tests read it)
var prize_item := {}             # the secret's Legendary placed on the shrine ({} none)
var prize_pickup := {}           # the World's pickup it is ({} none)
var _slates: Array = []          # 1-S: the crumbling slates' cells


func build(w: Node, lv: RefCounted) -> void:
	super.build(w, lv)
	for n in PROPS:
		var p := "res://art/props/%s.svg" % n
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	_read_points()
	_start_at = ftime()
	_hum_at = ftime()
	secret_level = str(lv.id).ends_with("-S")
	if secret_level:
		_build_secret_level()
		return
	if str(lv.secret) == "" or not _registered(str(lv.secret)):
		return
	for e in lv.entities:
		if e["kind"] == "silver_bell" and w.has_method("add_bell"):
			var cell: Vector2i = e["cell"]
			var b: Dictionary = w.add_bell(LevelData.cell_floor(cell), 0.0, {"silver": true})
			bells.append(b)
			var ex := {"cell": cell, "floor": LevelData.cell_floor(cell), "bell": b, "t0": -99.0}
			ex["nook"] = _nook_of(cell)
			ex["seal"] = seal_of(level, cell, ex["nook"])
			ex["sight"] = _sight_of(ex)
			ex["floor_y"] = _floor_below(Vector2(ex["sight"].x, ex["sight"].y + TILE * 0.5 + 2.0))
			ex["lamp"] = _lamp_under(ex["sight"])
			ex["crest"] = (LevelData.cell_floor(ex["lamp"]) - Vector2(0, CREST_UP)) if ex["lamp"].x >= 0 else (ex["sight"] as Vector2)
			exits.append(ex)


func _read_points() -> void:
	## A2's anchors for the shrine's props (frame units), else the published ones.
	_pts = ANCHORS.duplicate(true)
	if not FileAccess.file_exists(POINTS):
		return
	var j = JSON.parse_string(FileAccess.get_file_as_string(POINTS))
	if not (j is Dictionary):
		return
	for base in ["grave_candle", "legend_shrine"]:
		var row = j.get(base + "_lit", j.get(base + "_out"))
		if row is Dictionary:
			for k in row:
				var v = row[k]
				if v is Array and v.size() == 2:
					_pts[base][k] = Vector2(float(v[0]), float(v[1]))


func _registered(id: String) -> bool:
	## The registry holds the secret level and its file is in this build (the
	## W3/W4 integration's rule, kept at the track B merge: 4-2 before 4-S
	## "opened" a level the map can't show). The registry is the map's own
	## (UI.secret_levels(): Game.SECRET_LEVELS, or the tests' stand-in).
	var g = world.get_node_or_null("/root/Game") if world != null and world.is_inside_tree() else null
	if g == null:
		return false
	var reg = UI.secret_levels() if UI.secret_levels_override is Array \
			else (g.get_script() as Script).get_script_constant_map().get("SECRET_LEVELS", g.get("SECRET_LEVELS"))
	if not (reg is Array):
		return false
	for info in reg:
		if info is Dictionary and str(info.get("id", "")) == id:
			return FileAccess.file_exists(str(info.get("path", "res://levels/%s.txt" % id)))
	return false


func _sight_of(ex: Dictionary) -> Vector2:
	## Where the odd sight is: the middle of the false stone (else the window).
	var seal: Array = ex["seal"]
	if seal.is_empty():
		return _window(ex)
	var c := Vector2.ZERO
	for s in seal:
		c += LevelData.cell_center(s)
	return c / float(seal.size())


func _nook_of(cell: Vector2i) -> Array:
	## The attic (antechamber) the bell hangs in: the air round it when it's a
	## small closed room (else nothing), so its walls are drawn, not a void.
	return nook_of(level, cell)


static func nook_of(lv: RefCounted, cell: Vector2i) -> Array:
	var seen := {cell: true}
	var todo: Array = [cell]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			if lv.tile(n.x, n.y) != LevelData.AIR:
				continue
			if absi(n.x - cell.x) > NOOK_REACH or absi(n.y - cell.y) > NOOK_REACH or seen.size() >= NOOK_MAX:
				return []   # it opens onto the level: no attic
			seen[n] = true
			todo.append(n)
	return seen.keys()


static func seal_of(lv: RefCounted, cell: Vector2i, nook: Array) -> Array:
	## The false stone that hides a bell: every F bordering its attic (and the
	## F cells joined to those: a vent two deep), else, with no closed attic,
	## every F within SEAL_REACH of it.
	var out := []
	if not nook.is_empty():
		var todo: Array = []
		for c in nook:
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if lv.tile(n.x, n.y) == LevelData.FALSE_STONE and not out.has(n):
					out.append(n)
					todo.append(n)
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if lv.tile(n.x, n.y) == LevelData.FALSE_STONE and not out.has(n) and out.size() < 8:
					out.append(n)
					todo.append(n)
		return out
	for y in range(cell.y - SEAL_REACH, cell.y + SEAL_REACH + 1):
		for x in range(cell.x - SEAL_REACH, cell.x + SEAL_REACH + 1):
			if lv.tile(x, y) == LevelData.FALSE_STONE:
				out.append(Vector2i(x, y))
	return out


# ---------------------------------------------------------------- a secret level

func _build_secret_level() -> void:
	for e in level.entities:
		if e["kind"] == "silver_bell":
			bell_cell = e["cell"]
		elif e["kind"] == "dread" and not level.warden.is_empty():
			warden_home = {"kind": str(level.warden["kind"]), "cell": e["cell"], "name": str(level.warden["name"]),
					"omens": (level.warden.get("omens", []) as Array).duplicate()}
	_anoint()
	_water_warden()
	if int(level.world) == 1:
		for y in level.height:
			for x in level.width:
				if level.tile(x, y) == LevelData.CRUMBLE:
					_slates.append(Vector2i(x, y))
	if bell_cell.x < 0:
		return
	var f := LevelData.cell_floor(bell_cell)
	var sf := LevelData.cell_floor(Vector2i(bell_cell.x + SHRINE_DX, bell_cell.y))
	shrine = {"floor": sf, "top": sf - Vector2(0, 44), "lit": false, "light": -1}
	room = _find_room(f)
	warden = world.get("warden")
	if warden != null and is_instance_valid(warden) and warden.alive:
		phase = "wait"
		_sleep(warden)
	else:
		# No Warden to fight: the shrine is lit and the bell stands already.
		warden = null
		phase = "won"
		_won_at = ftime() - (RISE_AT + RISE_LEN)
		_won_t = RISE_AT + RISE_LEN
		_light_shrine(true)
		if not bool(world.get("no_monsters")):
			_place_prize()
		_prize_done = true
		_make_bell(true)


func _water_warden() -> void:
	## A deep-water Warden's D cell is water, as its lake is (level_data makes
	## every D air; a Lurecoil's cell at the lake's bottom showed as a notch).
	if warden_home.is_empty() or not (LevelData.WATER_KINDS as Array).has(str(warden_home["kind"])):
		return
	var c: Vector2i = warden_home["cell"]
	if level.tile(c.x, c.y) != LevelData.AIR:
		return
	var wet := 0
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if level.tile(c.x + d.x, c.y + d.y) == LevelData.WATER:
			wet += 1
	if wet >= 2:
		level.set_tile(c.x, c.y, LevelData.WATER)
		# The dispatcher drew its water cells before the modules were built.
		var fx = world.get("features")
		if fx != null and "water_cells" in fx and not (fx.water_cells as Array).has(c):
			fx.water_cells.append(c)
		if world.has_method("_redraw_at"):
			world._redraw_at(c.x)


func _find_room(bell_floor: Vector2) -> Dictionary:
	## The Warden's room: header warden_room (the section's columns, its two
	## wall columns at each end included), else boss_arena.gd's find().
	var hd = level.get("headers")
	var raw := str(hd.get("warden_room", "")) if hd is Dictionary else ""
	var ab := raw.split("-")
	if ab.size() == 2 and ab[0].strip_edges().is_valid_int() and ab[1].strip_edges().is_valid_int():
		var x0 := int(ab[0])
		var x1 := int(ab[1])
		var door: Array = []
		for x in [x0, x0 + 1, x1 - 1, x1]:
			for y in range(0, level.height - 1):
				if level.tile(x, y) == LevelData.AIR and not door.has(Vector2i(x, y)):
					door.append(Vector2i(x, y))
		return {"x0": x0, "x1": x1, "left": float((x0 + 2) * TILE), "right": float((x1 - 1) * TILE), "door": door}
	var a: Dictionary = Arena.find(level, bell_floor)
	var l := int(float(a["left"]) / TILE)
	var r := int(float(a["right"]) / TILE) - 1
	return {"x0": l - 2, "x1": r + 2, "left": float(a["left"]), "right": float(a["right"]), "door": (a["door"] as Array).duplicate()}


func anoint_cells() -> Array:
	## Header anoint: "x,y; x,y" as cells (the tests read it).
	var hd = level.get("headers")
	var cells: Array = []
	if not (hd is Dictionary) or str(hd.get("anoint", "")) == "":
		return cells
	for part in str(hd["anoint"]).split(";"):
		var xy := part.strip_edges().split(",")
		if xy.size() == 2 and xy[0].strip_edges().is_valid_int() and xy[1].strip_edges().is_valid_int():
			cells.append(Vector2i(int(xy[0]), int(xy[1])))
	return cells


func _anoint() -> void:
	## The monsters placed at the anoint: cells are Anointed every run (their
	## Omens rolled as the World's would be).
	var cells := anoint_cells()
	if cells.is_empty() or not ResourceLoader.exists(ELITES):
		return
	var El = load(ELITES)
	var r := RandomNumberGenerator.new()
	r.seed = hash("anoint|%s|%s" % [level.id, str(world.diff)])
	var rules: Dictionary = world.elite_rules() if world.has_method("elite_rules") else {}
	for en in world.enemies:
		if not is_instance_valid(en) or en.tier != "" or not en.has_method("make_elite"):
			continue
		var c = en.spawn.get("cell", Vector2i(-1, -1))
		if cells.has(c):
			en.make_elite("anointed", El.roll_omens(en.kind, str(world.diff), int(world.world_n), r, rules))
			var cc: Vector2i = c
			world.spawns = world.spawns.filter(func(sp): return sp["cell"] != cc)


func _sleep(en: Node2D) -> void:
	## The Warden asleep at its post till the door seals: out of the World's
	## monster list, so no hit, shot or aim finds it and it hurts no one;
	## still and dim.
	if en == null or not is_instance_valid(en):
		return
	world.enemies.erase(en)
	en.active = false
	if "velocity" in en:
		en.velocity = Vector2.ZERO
	en.modulate = DORMANT
	dormant = true


func _wake() -> void:
	## The door has sealed: the Warden wakes (its bar follows from the World).
	if not dormant or warden == null or not is_instance_valid(warden):
		dormant = false
		return
	dormant = false
	if not world.enemies.has(warden):
		world.enemies.append(warden)
	warden.modulate = Color.WHITE
	if not warden.active:
		# Awake now, wherever the camera is (the World's own wake would wait
		# for the view): its boss bar says who it is (world._update_warden_bar;
		# no elite plate as well, the rev5 review: the name twice, two bars).
		warden.active = true
	_reel_at = -99.0
	_stun_at = -99.0
	_was_stunned = false
	_wflash = float(warden.get("flash")) if warden.get("flash") != null else 0.0
	world._sfx("boss_roar", 1.25, 0.0, 0.7)
	if world.glow:
		world.glow.burst(warden.center(), 22, Color(0.86, 0.88, 1.0, 0.95), 150.0, 0.6, -40.0, 2.4)


func _step_room(dt: float) -> void:
	var pl := player()
	if phase == "wait" or phase == "fight":
		if warden == null or not is_instance_valid(warden) or not warden.alive:
			_warden_fell()
			return
	if phase == "wait":
		if pl != null and pl.alive and world.state == "play" and _past_door(pl):
			_seal()
	elif phase == "fight":
		_poise()
	elif phase == "won":
		_won_t = ftime() - _won_at
		if not _prize_done and _won_t >= PRIZE_AT:
			_place_prize()
		if bell.is_empty() and _won_t >= RISE_AT:
			_make_bell(false)
		if not bell.is_empty() and not _risen:
			var k := clampf((_won_t - RISE_AT) / RISE_LEN, 0.0, 1.0)
			_pose_bell(k)
			if k >= 1.0:
				_risen = true
				bell["rope"] = bell["rope_live"]


func _poise() -> void:
	## A Warden's poise. A kind that reels while its flash is up reels at
	## most once every FLINCH_CD s (a cut inside that is only a short blink),
	## and any Warden shakes off a stagger (status "stun") that comes within
	## STUN_CD s of the last one it took: a stream of sparks, knives or maul
	## blows can't hold it off for good.
	var st = warden.get("status")
	if st is Dictionary:
		var stunned := (st as Dictionary).has("stun")
		if stunned and not _was_stunned:
			if ftime() - _stun_at >= STUN_CD:
				_stun_at = ftime()
			else:
				(st as Dictionary).erase("stun")
				stunned = false
		_was_stunned = stunned
	var reel := float(REELS.get(str(warden.kind), -1.0))
	if reel < 0.0 or warden.get("flash") == null:
		return
	var f := float(warden.flash)
	if f > _wflash + 0.2:
		if ftime() - _reel_at >= FLINCH_CD:
			_reel_at = ftime()
		else:
			warden.flash = minf(f, reel)
	_wflash = float(warden.flash)


func _past_door(pl: Node2D) -> bool:
	var r: Rect2 = pl.rect()
	return r.position.x > float(room["left"]) + DOOR_PAST and r.end.x < float(room["right"])


func _seal() -> void:
	if sealed:
		return
	var bodies: Array = [player()]
	bodies.append_array(world.enemies)
	room["sealed_cells"] = Arena.seal_free(world, level, room["door"], bodies)
	sealed = true
	phase = "fight"
	_wake()


func _unseal() -> void:
	if not sealed:
		return
	Arena.unseal(world, level, room.get("sealed_cells", []))
	sealed = false


func _warden_fell() -> void:
	## The Warden is down: the door opens, the grave candle lights, the Lost
	## Wick speaks; the prize and the bell follow (_step_room).
	_unseal()
	if dormant and warden != null and is_instance_valid(warden):
		# Fallen in its sleep (a script's kill): back in the World's list so
		# its death plays out and it's freed.
		if not world.enemies.has(warden):
			world.enemies.append(warden)
		warden.modulate = Color.WHITE
		warden.active = true
	dormant = false
	phase = "won"
	_won_at = ftime()
	_won_t = 0.0
	_light_shrine(false)
	world.bark("first_lost_wick")
	var lw := "lost_wick_%d" % int(level.world)
	if ResourceLoader.exists(STORY):
		var S = load(STORY)
		if S != null and S.has_method("lost_wick_bark"):
			lw = str(S.lost_wick_bark(int(level.world)))
	if lw != "":
		world.bark(lw)


func _light_shrine(quiet: bool) -> void:
	if shrine.is_empty() or shrine["lit"]:
		return
	shrine["lit"] = true
	shrine["light"] = world.add_light(flame_at() + Vector2(0, -4), SHRINE_R, 0.85, -1.0, "grave,deco", SHRINE_TINT)
	if quiet:
		return
	world._sfx("candle_lit")
	if world.glow:
		world.glow.burst(flame_at(), 24, GILT, 160.0, 0.9, -60.0, 2.4)


func flame_at() -> Vector2:
	## The grave candle's flame: A2's candle "flame" anchor where the art is,
	## else the stand-in's wick.
	if shrine.is_empty():
		return Vector2.ZERO
	var key := "grave_candle_lit" if _tex.has("grave_candle_lit") else "grave_candle_out"
	if _tex.has(key):
		var a: Dictionary = _pts["grave_candle"]
		return _candle_foot() + ((a["flame"] as Vector2) - (a["foot"] as Vector2)) * 0.5
	return (shrine["floor"] as Vector2) + Vector2(0, -34.0 - 24.0)


func prize_at() -> Vector2:
	## Where the prize lies: on the shrine's mensa (A2's "prize"), else on the
	## stand-in grave's top.
	if shrine.is_empty():
		return Vector2.ZERO
	if _tex.has("legend_shrine_lit") or _tex.has("legend_shrine_out"):
		var a: Dictionary = _pts["legend_shrine"]
		return (shrine["floor"] as Vector2) + ((a["prize"] as Vector2) - (a["foot"] as Vector2)) * 0.5
	return (shrine["floor"] as Vector2) + Vector2(0, -39.0)


func _candle_foot() -> Vector2:
	## A2's candle stands on the floor beside its shrine (alone, where the shrine is).
	var f: Vector2 = shrine["floor"]
	if _tex.has("legend_shrine_lit") or _tex.has("legend_shrine_out"):
		return f + Vector2(CANDLE_BESIDE, 0)
	return f


func _place_prize() -> void:
	## The prize on the shrine: the secret's Legendary until it's taken on
	## this difficulty (Game.secret_prize: {} once paid), else one
	## boss-weighted item. None where the World keeps no loot.
	_prize_done = true
	if shrine.is_empty() or not world.allows("loot"):
		return
	var at := prize_at()
	var g = world.get_node_or_null("/root/Game") if world.is_inside_tree() else null
	var it := {}
	if g != null and g.has_method("secret_prize"):
		it = g.secret_prize(str(level.id))
	if not it.is_empty():
		prize_item = it
		var p: Dictionary = world.place_item(it, at, Vector2.ZERO)
		# It lies on the mensa (no fall to the floor in front of it).
		p["loose"] = false
		prize_pickup = p
	else:
		world.drop_item(at, "boss")
	if world.glow:
		world.glow.burst(at, 16, GILT, 110.0, 0.6, -30.0, 2.0)


func _make_bell(risen: bool) -> void:
	if bell_cell.x < 0 or not bell.is_empty():
		return
	var b: Dictionary = world.add_bell(LevelData.cell_floor(bell_cell), 0.0, {"silver": true, "plain": true})
	if not b.has("plain"):
		# The World rings a silver bell as a secret exit (its toast, its
		# sound): this one ends a level with no secret of its own, as the
		# great bell would. It keeps the silver look.
		b["silver"] = false
	b["rope_live"] = b["rope"]
	b["top_live"] = b["top"]
	bell = b
	bells.append(b)
	if risen:
		_risen = true
		_pose_bell(1.0)
	else:
		b["rope"] = Rect2(-1e6, -1e6, 0, 0)
		_pose_bell(0.0)
		world._sfx("silver_bell", 1.0, 0.0, 0.6)
		if world.glow:
			world.glow.burst(LevelData.cell_floor(bell_cell) + Vector2(0, -12), 20, SILVER, 120.0, 1.0, -120.0, 2.0)


func _pose_bell(k: float) -> void:
	var e := 1.0 - pow(1.0 - k, 3.0)
	var top: Vector2 = bell["top_live"] + Vector2(0, RISE_FROM * (1.0 - e))
	bell["top"] = top
	var s = bell.get("sprite")
	if s != null and is_instance_valid(s):
		(s as Node2D).position = top
		(s as CanvasItem).modulate.a = e


func on_respawn() -> void:
	## A snuff in the sealed room: it opens and starts over, as a boss room.
	if phase != "fight":
		return
	_unseal()
	_reset_warden()
	if phase == "fight":
		phase = "wait"
	resets += 1


func _reset_warden() -> void:
	var left := float(room["left"]) - 2.0 * TILE
	var right := float(room["right"]) + 2.0 * TILE
	for e in world.enemies:
		# The Warden and whatever it called up: gone (the room holds no one else).
		if is_instance_valid(e) and e.alive and e.position.x > left and e.position.x < right:
			e.gone = true
	if warden != null and is_instance_valid(warden) and not world.enemies.has(warden):
		warden.queue_free()
	warden = null
	world.warden = null
	dormant = false
	if warden_home.is_empty():
		phase = "won"
		_won_at = ftime()
		_won_t = 0.0
		return
	var k: String = warden_home["kind"]
	var cell: Vector2i = warden_home["cell"]
	var en: Node2D = world.spawn_enemy(k, EnemyKinds.spawn_pos(k, cell), {"tier": "warden", "name": warden_home["name"],
			"omens": (warden_home["omens"] as Array).duplicate(), "cell": cell})
	world.warden = en
	warden = en
	if en == null:
		phase = "won"
		_won_at = ftime()
		_won_t = 0.0
		return
	_sleep(en)


func bot_target(_pl: Node2D):
	## The --autoplay bot's foe in a shut room (autoplay_bot.gd's room pad
	## asks every module): the Warden awake in its sealed room, else null.
	if not secret_level or phase != "fight" or dormant or warden == null or not is_instance_valid(warden) or not warden.alive:
		return null
	return warden


# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	var pl := player()
	if pl == null:
		return
	if secret_level:
		if phase != "":
			_step_room(dt)
		if not _start_barked and ftime() - _start_at >= START_BARK and pl.alive and pl.on_floor and world.state == "play":
			_start_barked = true
			world.bark("first_secret")
		return
	if exits.is_empty():
		return
	var ex: Dictionary = exits[0]
	var b: Dictionary = ex["bell"]
	if b["rung"]:
		return
	# The hum, every HUM_EVERY s within HUM_R, softer with distance.
	var arch := _window(ex)
	var d: float = pl.center().distance_to(arch)
	if ftime() >= _hum_at:
		_hum_at = ftime() + HUM_EVERY
		ex["t0"] = ftime()
		if d < HUM_R:
			world._sfx("secret_hum", 1.0, 0.0, clampf(1.0 - d / HUM_R, 0.0, 1.0))
	# The hint bark, once, on the floor near the odd sight: within 10 rows of
	# the bell's own floor, or of the floor under the sight (the rev5 review:
	# 3-3's and 4-2's attics are 10 rows over the walking floor, so the bark
	# only fired once he'd climbed to the crack, and never from 4-2's floor).
	var near_y: bool = absf(pl.position.y - float(ex["floor"].y)) < 10.0 * TILE \
			or absf(pl.position.y - float(ex.get("floor_y", ex["floor"].y))) <= 10.0 * TILE
	if not _hinted and pl.on_floor and world.state == "play" and absf(pl.position.x - arch.x) < HINT_R \
			and near_y and not _found_here():
		_hinted = true
		world.bark("secret_hint_%d" % int(level.world))


func _found_here() -> bool:
	## The secret this exit opens is found already on this difficulty.
	var g = world.get_node_or_null("/root/Game") if world.is_inside_tree() else null
	return g != null and g.has_method("secret_open") and bool(g.secret_open(str(level.secret), str(world.diff)))


func _window(ex: Dictionary) -> Vector2:
	return (ex["floor"] as Vector2) - Vector2(0, WINDOW_UP)


func lights() -> Array:
	## 1-3's moonlight through the crack (a pale light where no light should
	## be: rung 1 of the hint ladder), while the bell hangs unrung.
	var out := []
	for ex in exits:
		if str(WORLD_SIGHT.get(int(level.world), "")) == "moon" and not ex["bell"]["rung"]:
			var c: Vector2 = ex["sight"]
			out.append({"p": Vector2(c.x, float(ex["floor_y"]) - 60.0), "r": 150.0, "s": 0.7,
					"tint": Color(MOON, 0.7), "tag": "deco", "gameplay": false})
	return out


func hum_gain(p: Vector2) -> float:
	## The hum's gain for Wick at p (the tests read it): 1 at the arch, 0 at HUM_R.
	if exits.is_empty():
		return 0.0
	return clampf(1.0 - p.distance_to(_window(exits[0])) / HUM_R, 0.0, 1.0)


# ---------------------------------------------------------------- drawing

func draw_under(ci: CanvasItem) -> void:
	var vr: Rect2 = view().grow(96.0)
	for ex in exits:
		var f: Vector2 = ex["floor"]
		if not vr.intersects(Rect2(f.x - 96.0, f.y - 160.0, 192.0, 224.0)):
			continue
		for c in ex["nook"]:
			ci.draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE, TILE), NOOK_WALL)
		if _tex.has("secret_door"):
			_prop(ci, _tex["secret_door"], f)
		else:
			_arch(f)
		if int(level.world) == 2 and not ex["bell"]["rung"]:
			_crest(ci, ex)
	if not bell.is_empty() and vr.has_point(LevelData.cell_floor(bell_cell)):
		_stand(ci, LevelData.cell_floor(bell_cell), bell["top"])
	if not shrine.is_empty() and vr.has_point(shrine["floor"]):
		var key := "grave_candle_lit" if shrine["lit"] else "grave_candle_out"
		var base := "legend_shrine_lit" if shrine["lit"] else "legend_shrine_out"
		if _tex.has(base):
			_prop(ci, _tex[base], shrine["floor"])
		if _tex.has(key):
			_prop(ci, _tex[key], _candle_foot())
		if not _tex.has(key) and not _tex.has(base):
			_grave(ci, shrine["floor"], shrine["lit"])
	_tb.flush(ci)


func _moonbeam(ex: Dictionary) -> void:
	## 1-3's odd sight: a pale shaft from the crack down to the floor, fading
	## as it falls (above the dark, like the light it is; lights() lights
	## the floor under it).
	var c: Vector2 = ex["sight"]
	var open := not (ex["seal"] as Array).any(func(s): return level.tile(s.x, s.y) == LevelData.FALSE_STONE)
	var top := c.y - TILE * 0.5 if open else c.y + TILE * 0.5
	var fy: float = ex["floor_y"]
	_shaft(Vector2(c.x, top), fy, 20.0, 44.0, Color(MOON, 0.13), Color(MOON, 0.02))
	_shaft(Vector2(c.x, top), fy, 8.0, 18.0, Color(MOON, 0.12), Color(MOON, 0.03))


func _shaft(top: Vector2, bottom_y: float, w0: float, w1: float, c0: Color, c1: Color) -> void:
	var a := top + Vector2(-w0, 0)
	var b := top + Vector2(w0, 0)
	var cc := Vector2(top.x + w1, bottom_y)
	var d := Vector2(top.x - w1, bottom_y)
	_tb.tri3(a, b, cc, c0, c0, c1)
	_tb.tri3(a, cc, d, c0, c1, c1)


func _stand(ci: CanvasItem, f: Vector2, top: Vector2) -> void:
	## The risen silver bell's stand: a slim post from the floor, a crossbar
	## it hangs from (it rises with the bell).
	var k := clampf((f.y - top.y) / 60.0, 0.0, 1.0)
	var bar_y := top.y - 6.0
	ci.draw_rect(Rect2(f.x - 17.0, f.y - 3.0, 34.0, 3.0), Color(0.55, 0.58, 0.66, k))
	ci.draw_rect(Rect2(f.x - 15.0, bar_y, 3.0, f.y - bar_y), Color(0.62, 0.66, 0.75, k))
	ci.draw_rect(Rect2(f.x + 12.0, bar_y, 3.0, f.y - bar_y), Color(0.62, 0.66, 0.75, k))
	ci.draw_rect(Rect2(f.x - 17.0, bar_y - 3.0, 34.0, 4.0), Color(0.78, 0.82, 0.9, k))


func _prop(ci: CanvasItem, tx: Texture2D, f: Vector2) -> void:
	var sz := tx.get_size() * 0.25
	ci.draw_texture_rect(tx, Rect2(f - Vector2(sz.x * 0.5, sz.y), sz), false)


func _arch(f: Vector2) -> void:
	## The secret door, drawn: a small pointed arch of dark stone, 56 x 92,
	## its bell-shaped window (lit in draw_glow).
	var w := 28.0
	var h := 92.0
	var outer := PackedVector2Array([f + Vector2(-w, 0), f + Vector2(-w, -h * 0.62), f + Vector2(-w * 0.62, -h * 0.9),
			f + Vector2(0, -h), f + Vector2(w * 0.62, -h * 0.9), f + Vector2(w, -h * 0.62), f + Vector2(w, 0)])
	_tb.convex(outer, STONE_LIP)
	var inner := PackedVector2Array()
	for p in outer:
		inner.append(f + (p - f) * Vector2(0.78, 0.93) + Vector2(0, -2))
	_tb.convex(inner, STONE_DARK)
	_bell_shape(_tb, f - Vector2(0, WINDOW_UP), 11.0, Color(0.10, 0.10, 0.16))


static func _bell_shape(tb: RefCounted, c: Vector2, s: float, col: Color) -> void:
	## A bell's outline (the window's shape), s its half width at the lip.
	var pts := PackedVector2Array([c + Vector2(-s, s * 0.9), c + Vector2(-s * 0.78, s * 0.3), c + Vector2(-s * 0.62, -s * 0.6),
			c + Vector2(-s * 0.3, -s * 1.05), c + Vector2(0, -s * 1.15), c + Vector2(s * 0.3, -s * 1.05),
			c + Vector2(s * 0.62, -s * 0.6), c + Vector2(s * 0.78, s * 0.3), c + Vector2(s, s * 0.9)])
	tb.convex(pts, col)


func _crest(ci: CanvasItem, ex: Dictionary) -> void:
	## 2-2's odd sight: the chandlers' guild crest on the wall over the
	## third lamp (a gilt shield, a taper on it), seen in the light it's in
	## (draw_glow adds its gilt edge once that lamp is lit); it's gone once
	## the false stone above is broken.
	var seal: Array = ex["seal"]
	if not seal.any(func(s): return level.tile(s.x, s.y) == LevelData.FALSE_STONE):
		return
	var c: Vector2 = ex["crest"]
	var sh := PackedVector2Array([c + Vector2(-11, -12), c + Vector2(11, -12), c + Vector2(11, 2), c + Vector2(0, 13), c + Vector2(-11, 2)])
	_tb.convex(sh, Color("8a6a2a"))
	var inner := PackedVector2Array()
	for p in sh:
		inner.append(c + (p - c) * 0.78)
	_tb.convex(inner, Color("c9a24a"))
	ci.draw_rect(Rect2(c + Vector2(-2, -6), Vector2(4, 11)), Color("f4ead6"))
	_tb.circle(c + Vector2(0, -8), 2.2, Color("ffcf6a"), 8)


func _grave(ci: CanvasItem, f: Vector2, lit: bool) -> void:
	## The Lost Wick's grave candle, drawn: a low gilt-edged stone with a
	## round head, a stub of candle on it (its flame is draw_glow's).
	var w := 15.0
	var h := 34.0
	var body := PackedVector2Array([f + Vector2(-w, 0), f + Vector2(-w, -h)])
	for i in 9:
		var a := PI + PI * i / 8.0
		body.append(f + Vector2(cos(a) * w, -h + sin(a) * 9.0))
	body.append_array(PackedVector2Array([f + Vector2(w, -h), f + Vector2(w, 0)]))
	_tb.convex(body, Color("6b6478") if lit else Color("4a4456"))
	var face := PackedVector2Array()
	for p in body:
		face.append(f + (p - f) * Vector2(0.8, 0.9))
	_tb.convex(face, Color("3a3446"))
	ci.draw_rect(Rect2(f + Vector2(-w - 3, -4), Vector2(2 * w + 6, 4)), GILT.darkened(0.35))
	ci.draw_rect(Rect2(f + Vector2(-4, -h - 22), Vector2(8, 14)), Color("efe4cc") if lit else Color("a89e8a"))


func draw_glow(glow: Node2D) -> void:
	var t := ftime()
	var vr: Rect2 = view().grow(96.0)
	var pl := player()
	var hero_r: float = world.hero_light_radius() if pl != null and pl.alive and world.has_method("hero_light_radius") else 0.0
	var owl := bool(world.get("owls_eye"))
	for ex in exits:
		var b: Dictionary = ex["bell"]
		var win := _window(ex)
		if b["rung"] or not vr.intersects(Rect2(win.x - 64.0, win.y - 64.0, 128.0, float(ex["floor_y"]) - win.y + 96.0)):
			continue
		var since := t - float(ex.get("t0", -99.0))
		var glint := clampf(1.0 - since / GLINT_LEN, 0.0, 1.0)
		# The window: its full glow only inside Wick's own light.
		var inside := 0.0
		if pl != null and hero_r > 0.0:
			inside = clampf((hero_r - win.distance_to(pl.center())) / 60.0, 0.0, 1.0)
		if _tex.has("secret_door_glint"):
			# A2's glint sprite over the arch: full inside his light, faint in
			# any other (the window reads in any light, spec §3.9).
			var ga := GLINT_HERO * inside
			if ga < GLINT_ANY and (owl or _lit(win)):
				ga = GLINT_ANY
			if ga > 0.0:
				var gt: Texture2D = _tex["secret_door_glint"]
				var gsz := gt.get_size() * 0.25
				var f: Vector2 = ex["floor"]
				glow.draw_texture_rect(gt, Rect2(f - Vector2(gsz.x * 0.5, gsz.y), gsz), false, Color(1, 1, 1, ga * (0.85 + 0.15 * sin(t * 2.6 + f.x))))
		elif inside > 0.0:
			_bell_shape(_tb, win, 11.0, Color(SILVER, 0.55 * inside))
			_tb.circle(win, 22.0, Color(SILVER, 0.10 * inside), 14)
		# The glint, with each hum, in any light (the Owl's Eye: the dark too).
		if glint > 0.0 and (owl or _lit(win)):
			_star(win + Vector2(6, -6), 5.0 + 5.0 * glint, Color(SILVER, 0.85 * glint))
		for s in ex["seal"]:
			if level.tile(s.x, s.y) != LevelData.FALSE_STONE:
				continue
			var m := LevelData.cell_center(s)
			var gk := clampf(1.0 - (since - 0.18) / GLINT_LEN, 0.0, 1.0) if since >= 0.18 else 0.0
			if gk > 0.0 and (owl or _lit(m)):
				_star(m + Vector2(-5 + 10 * fposmod(s.x * 0.37, 1.0), 6), 3.0 + 4.0 * gk, Color(SILVER, 0.8 * gk))
		_odd_sight(ex, t)
	if not _slates.is_empty():
		_snow_on_slates(vr, t)
	if not shrine.is_empty() and shrine["lit"] and vr.has_point(shrine["floor"]):
		var fp := flame_at()
		glow.flame(fp, 11.0, fp.x * 0.05)
	if not bell.is_empty() and vr.has_point(bell["top"]):
		var k := 1.0 if _risen else clampf((_won_t - RISE_AT) / RISE_LEN, 0.0, 1.0)
		if not _risen:
			var base: Vector2 = LevelData.cell_floor(bell_cell)
			_tb.rect(Rect2(base + Vector2(-12, -80), Vector2(24, 80)), Color(SILVER, 0.12 * (1.0 - absf(2.0 * k - 1.0))))
		elif not bell["rung"]:
			var ph := fmod(t, HUM_EVERY) / HUM_EVERY
			_tb.circle((bell["top"] as Vector2) + Vector2(0, 26), 16.0 + 4.0 * sin(ph * TAU), Color(SILVER, 0.08), 14)
	_tb.flush(glow)


func _snow_on_slates(vr: Rect2, t: float) -> void:
	## 1-S: a line of snow along each crumbling slate still up (it shivers as
	## the slate shakes, and is gone while it's down), above the dark.
	var cr = world.get("crumbles")
	for sc in _slates:
		var c: Vector2i = sc
		var r := Rect2(c.x * TILE, c.y * TILE, TILE, 6.0)
		if not vr.intersects(r):
			continue
		var st := "idle"
		if cr is Dictionary and (cr as Dictionary).has(c):
			st = str(cr[c]["state"])
		if st == "fallen":
			continue
		var dx := sin(t * 70.0 + c.x) * 1.2 if st == "shake" else 0.0
		var a := 0.78 if st == "idle" else 0.35 + 0.35 * absf(sin(t * 30.0))
		var y := float(c.y * TILE)
		# A dark seam under the snow (it parts the slate from a ridge behind), the snow on it.
		_tb.rect(Rect2(c.x * TILE + 1.0 + dx, y + 2.0, TILE - 2.0, 1.0), Color(0.05, 0.05, 0.1, a * 0.6))
		_tb.rect(Rect2(c.x * TILE + 1.0 + dx, y - 1.0, TILE - 2.0, 3.0), Color(SNOW, a))
		# A few lumps along it.
		for i in 3:
			var x := float(c.x * TILE) + 4.0 + i * 11.0 + fposmod(c.x * 5.3 + i * 3.1, 4.0) + dx
			_tb.rect(Rect2(x, y - 3.5, 6.0, 3.0), Color(SNOW, a * 0.85))


func _lit(p: Vector2) -> bool:
	## In any light: Wick's own or a lamp's (gameplay lights), nominal radii.
	if world.has_method("lit_at"):
		return bool(world.lit_at(p, 0.0, {}))
	var pl := player()
	return pl != null and pl.center().distance_to(p) < world.hero_light_radius()


func _star(c: Vector2, r: float, col: Color) -> void:
	## A four-point glint.
	_tb.quad(c + Vector2(-r, 0), c + Vector2(0, -r * 0.18), c + Vector2(r, 0), c + Vector2(0, r * 0.18), col)
	_tb.quad(c + Vector2(0, -r), c + Vector2(r * 0.18, 0), c + Vector2(0, r), c + Vector2(-r * 0.18, 0), col)
	_tb.circle(c, r * 0.28, Color(1, 1, 1, col.a), 8)


func _odd_sight(ex: Dictionary, t: float) -> void:
	## The place is odd on sight (spec §3.9, rung 1 of the hint ladder); 1-3's
	## moonlight shaft is draw_under's, its light lights()'.
	var c: Vector2 = ex["sight"]
	var bottom := c.y + TILE * 0.5
	var floor_y: float = ex["floor_y"]
	match str(WORLD_SIGHT.get(int(level.world), "")):
		"moon":
			_moonbeam(ex)
			# Motes turning in the moonlight.
			for i in 7:
				var k := fposmod(t * 0.07 + i * 0.143, 1.0)
				var y := lerpf(bottom + 6.0, floor_y - 6.0, k)
				var x := c.x + sin(t * 0.7 + i * 1.9) * (6.0 + 22.0 * k)
				_tb.circle(Vector2(x, y), 1.3, Color(MOON, 0.5 * sin(k * PI)), 6)
		"spores":
			# Pale spores drifting up into the crack.
			for i in 9:
				var k := fposmod(t * 0.16 + i * 0.111, 1.0)
				var y := lerpf(floor_y - 20.0, bottom, k)
				var x := c.x + sin(t * 1.3 + i * 2.3) * 14.0 * (1.0 - k)
				_tb.circle(Vector2(x, y), 1.8 + 0.8 * sin(i * 1.7), Color(0.92, 0.95, 0.80, 0.55 * sin(k * PI)), 6)
		"steam":
			# Steam rising into the vent (from the floor under it, or 5 rows down).
			var from := minf(floor_y - 8.0, bottom + 5.0 * TILE)
			for i in 5:
				var k := fposmod(t * 0.28 + i * 0.2, 1.0)
				var y := lerpf(from, bottom, k)
				var x := c.x + sin(t * 0.9 + i * 1.3) * 10.0 * (1.0 - 0.5 * k)
				_tb.circle(Vector2(x, y), 5.0 + 9.0 * k, Color(0.9, 0.93, 0.98, 0.12 * sin(k * PI)), 10)
		"crest":
			# 2-2: the guild's crest shows in the stone over the third lamp once
			# that lamp is lit (its own light, as the spec says), a gilt outline.
			if _lamp_below_lit(ex) and (ex["seal"] as Array).any(func(q): return level.tile(q.x, q.y) == LevelData.FALSE_STONE):
				var cc: Vector2 = ex["crest"]
				var k := 0.55 + 0.15 * sin(t * 2.1)
				_tb.polyline(PackedVector2Array([cc + Vector2(-11, -12), cc + Vector2(11, -12), cc + Vector2(11, 2), cc + Vector2(0, 13),
						cc + Vector2(-11, 2)]), 1.6, Color(GILT, k), true)
				_tb.circle(cc + Vector2(0, -8), 2.4, Color(1.0, 0.85, 0.5, k), 8)
		"gilt":
			# The stone over the lone lamp glints gold now and then.
			var k := fposmod(t / 4.0, 1.0)
			if k < 0.12:
				_star(c + Vector2(4, 8), 6.0 * sin(k / 0.12 * PI), Color(GILT, 0.8))
		"ripples":
			# The one drowned bell still chiming: silver rings round it, with the hum.
			var since := t - float(ex.get("t0", -99.0))
			for j in 2:
				var k := clampf((since - j * 0.35) / 1.6, 0.0, 1.0)
				if k > 0.0 and k < 1.0:
					_tb.ring(_window(ex) + Vector2(0, 30), 14.0 + 50.0 * k, 1.5, Color(SILVER, 0.35 * (1.0 - k)), 20)


func _lamp_under(c: Vector2) -> Vector2i:
	## The lantern post right under the odd sight (2-2's third lamp), if any.
	for e in level.entities:
		if e["kind"] == "lantern":
			var cell: Vector2i = e["cell"]
			if absf(LevelData.cell_center(cell).x - c.x) <= TILE and cell.y > floori(c.y / TILE) and cell.y - floori(c.y / TILE) <= 10:
				return cell
	return Vector2i(-1, -1)


func _lamp_below_lit(ex: Dictionary) -> bool:
	## That lamp, lit.
	var want: Vector2i = ex["lamp"]
	var fx = world.features.get("lanterns") if world.features != null else null
	if want.x < 0 or not (fx is Array):
		return false
	for l in fx:
		if l["cell"] == want and bool(l["lit"]):
			return true
	return false


func _floor_below(p: Vector2) -> float:
	## The first solid under p (px), at most 10 rows down (light and spores pass ledges).
	var x := floori(p.x / TILE)
	var y := floori(p.y / TILE)
	for yy in range(y, mini(y + 10, level.height)):
		var t: int = level.tile(x, yy)
		if LevelData.is_solid(t):
			return float(yy * TILE)
	return float(mini(y + 10, level.height) * TILE)
