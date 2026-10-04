extends "res://scripts/features/feature.gd"
## Sealed fight rooms (Build 2, build plan step 12; the author's call: the
## big rooms LOCK until won). A level's header names them, one or more:
##
##     room: duel 98-109 rows 3-7; ambush 200-229; hold 300-327 @20
##
## Each is `<kind> <x0>-<x1>`, the room's columns with its end walls
## included (as secrets.gd's warden_room), and may add
##   rows <y0>-<y1>  its rows, ceiling and floor included: a room up off the
##                   path that seals only once Wick climbs in (1-3's loft);
##                   walk under it and it never does
##   @<s>            the doors open after s seconds, whatever is left (a hold;
##                   a hold without it keeps HOLD_SECS, 5-3's 20)
##   foe <x>,<y>     a duel's named foe, by its cell (else the room's Dread,
##                   else its Anointed, else its toughest)
## With no header nothing here runs, and a level plays exactly as before.
## tools/levels/common.py writes the header (rooms_header) and checks every
## room for a monster, a way in and an altar within ALTAR_REACH tiles before
## its door (check_rooms): a snuff inside relights by it. Its doorways are
## open air or stone that never opens (every end-column cell between ceiling
## and floor: no water, vine, ledge, crumble, dawnglass, brick, rime or glass
## that a body could pass or break while the slab is down), and no monster of
## it stands within DOOR_CLEAR columns of either end (tests/level_rules.gd
## room_problems holds every level file to the same).
##
## The room's monsters are the level's own glyphs inside it (every file test
## counts them). Once the World has anointed (the modules are built first,
## and a forced anoint may name a room's cell) they leave its list, so no
## hit, shot, aim or alarm reaches them, and their cells leave world.spawns,
## so the World's respawns (Nightfall, Dusk from World 3) never refill it:
##   duel    they sleep at their posts, dim and still (as a Warden does)
##   ambush  hidden till the doors shut; then they drop in at their posts,
##           farthest from him first, DROP_STAGGER s apart, each fading in
##           over DROP_LEN s with dust (out of reach till it has). One never
##           drops while he stands within DROP_CLEAR px of its post (it waits,
##           so no drop lands on him: twists.gd RISE_CLEAR's rule), nor off
##           the glass (world.in_plain_view) but for DROP_WAIT s at most; in
##           a taller level one on another deck (its post more than DECK_ROWS
##           rows over or under his feet: the camera holds his deck, never
##           both) waits for him there, however long, and DROP_WAIT more for
##           the glass once he's come: each wave is fought on his own deck
##           (5-3's Hold the Glass), and the bot goes to it
##   hold    as an ambush, against the clock
## Wick wholly inside (DOOR_PAST past the door at either end, and between a
## rows room's ceiling and floor) and the doors grind shut: SEAL_TELL s of
## rumble, shake and dust while a slab comes down each doorway under its
## iron lintel (out again in time and they stay open), then stone at both
## ends (boss_arena.gd seal_free: every open door cell no body stands in,
## his, the World's monsters' or the room's own, asleep or hidden).
## The fight's bar takes the boss bar's place (never over a boss's or a
## Warden's): a duel's foe by name, its tier and Omens, its life, with a
## title card as it wakes (and no elite plate: the bar names it); an
## ambush's "Ambush · 5", its foes left; with a clock "Hold · 0:14", the
## time left (the foes left under it), drawn as a clock (hud.gd: gold, no
## damage trail; a level-up card waits till the doors open). A foe holds the
## doors while it's alive in the room: one of the room's own, a Twinned half,
## or one risen on a room
## cell (in a restless level, twists.gd, the remains of one of its own too,
## till they stand again or a swing lays them to rest; the bot goes for
## them); a nest's wings and other strays don't. One that falls out of it
## (below the level, into deep water or lava) is put out, a pit kill, so a
## foe knocked into a pit never leaves the doors shut for good.
## Won (none left, or the clock out): the doors open with dust, a chime and a
## gold burst at each, a toast, and for an ambush or a hold a REWARD item
## where loot is kept. A snuff while it's shut opens it and starts it over,
## as a boss room: everything alive in it gone, its monsters back at their
## posts (one already put out comes back as a respawn: less XP, no embers,
## a Dread's or an Anointed's tier drops paid once, world.gd _on_enemy_died,
## and off the altar snapshot's killed list), and Wick relights at the altar
## by the door (the World's checkpoint).
## A room with none of its monsters in the World (no_monsters: the golden
## routes and their replays; all killed before an altar resume; none drawn)
## is open from the start and never seals. The --autoplay bot fights in a
## shut room through bot_target() (autoplay_bot.gd's room pad).
##
## Every clock here reads world.ftime. Drawn in rects and one TriBatch.

const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const ELITES := "res://scripts/elites.gd"

const KINDS := ["duel", "ambush", "hold"]
const WORD := {"duel": "Duel", "ambush": "Ambush", "hold": "Hold"}
const DOOR_PAST := 10.0          # px Wick must be past a door (and inside a rows room) for it to seal
const SEAL_TELL := 0.6           # s the doors grind before they're stone (the phone's tell: 0.5 at least)
const DROP_STAGGER := 0.15       # s between an ambush's drop-ins...
const DROP_FIRST := 0.1          # ...the first this long after the doors shut
const DROP_LEN := 0.45           # s each takes to fade in (out of reach till it has)
const DROP_CLEAR := 96.0         # px: none drops this near him (3 tiles; twists.gd RISE_CLEAR)
const DROP_WAIT := 2.0           # s one waits past its turn for its post to be on the glass
const DECK_ROWS := 6             # a taller level: a post this many rows off his feet is another deck's (it waits for him)
const DOOR_CLEAR := 3            # columns inside each end no room monster stands in (common.py check_rooms)
const HOLD_SECS := 20.0          # a hold's clock when its header gives none (5-3's)
const WON_FX := 1.0              # s the open doors glow after a win
const ALTAR_REACH := 8           # tiles: an altar this near before each door (common.py check_rooms)
const SLACK_UP := 4              # rows over a full-height room's top a flier still counts as in it
# The win's item (world.drop_item's source; "" none: a duel's Dread pays its own).
const REWARD := {"duel": "", "ambush": "kill", "hold": "kill"}
const DORMANT := Color(0.46, 0.46, 0.58)   # a duel's monsters asleep at their posts, dim
const SLAB := Color("3a3346")
const SLAB_LIP := Color("5e5672")
const IRON := Color("2a2530")
const EMBER := Color(1.0, 0.55, 0.25)
const GILT := Color("ffd84a")

var rooms: Array = []            # one per header room (_room_of)
var _rostered := false           # each room has taken its monsters
var _bar_up := false             # the room's bar is up (the HUD's boss bar)
var _tb := TriBatch.new()


func build(w: Node, lv: RefCounted) -> void:
	super.build(w, lv)
	var hd = lv.get("headers")
	var raw := str(hd.get("room", "")) if hd is Dictionary else ""
	if raw.strip_edges() == "":
		return
	for spec in parse(raw):
		rooms.append(_room_of(spec))
	if rooms.is_empty():
		return
	# The World anoints after the modules are built (assign_elites, then a
	# header's forced anoint, whose cells may be a room's): the rooms take
	# their monsters once that's done, before the first tick (a resume at the
	# door altar would wake them in view), else on the first step.
	Callable(self, "_take_roster").call_deferred()


static func parse(raw: String) -> Array:
	## The header's rooms: [{kind, x0, x1, rows: [] | [y0, y1], secs, foe}]
	## (a part that doesn't read is left out; the tests read it).
	var out: Array = []
	for part in raw.split(";"):
		var bits: Array = []
		for b in part.strip_edges().split(" ", false):
			bits.append(str(b).strip_edges())
		if bits.size() < 2 or not KINDS.has(bits[0]):
			continue
		var xr := _pair(bits[1], "-")
		if xr.is_empty() or int(xr[1]) - int(xr[0]) < 4:
			continue
		var spec := {"kind": str(bits[0]), "x0": int(xr[0]), "x1": int(xr[1]), "rows": [], "secs": 0.0, "foe": Vector2i(-1, -1)}
		var i := 2
		while i < bits.size():
			var b: String = bits[i]
			if b == "rows" and i + 1 < bits.size():
				var yr := _pair(bits[i + 1], "-")
				if not yr.is_empty() and int(yr[1]) - int(yr[0]) >= 2:
					spec["rows"] = yr
				i += 1
			elif b == "foe" and i + 1 < bits.size():
				var c := _pair(bits[i + 1], ",")
				if not c.is_empty():
					spec["foe"] = Vector2i(int(c[0]), int(c[1]))
				i += 1
			elif b.begins_with("@") and b.substr(1).is_valid_float():
				spec["secs"] = maxf(float(b.substr(1)), 0.0)
			i += 1
		if spec["kind"] == "hold" and float(spec["secs"]) <= 0.0:
			spec["secs"] = HOLD_SECS
		out.append(spec)
	return out


static func _pair(s: String, sep: String) -> Array:
	## "a-b" (b not under a) or "a,b" as [a, b], else [].
	var ab := s.split(sep)
	if ab.size() != 2 or not ab[0].strip_edges().is_valid_int() or not ab[1].strip_edges().is_valid_int():
		return []
	var a := int(ab[0])
	var b := int(ab[1])
	if sep == "-" and b < a:
		return []
	return [a, b]


func _room_of(spec: Dictionary) -> Dictionary:
	## A room's geometry and state. Its doorways are the open cells of its
	## two end columns between its ceiling and its floor (a full-height room:
	## every row but the bottom one, as a Warden room's).
	var x0: int = spec["x0"]
	var x1: int = spec["x1"]
	var full: bool = (spec["rows"] as Array).is_empty()
	var y0: int = 0 if full else int(spec["rows"][0])
	var y1: int = level.height - 1 if full else int(spec["rows"][1])
	var door: Array = []
	var ry: Array = range(0, level.height - 1) if full else range(y0 + 1, y1)
	for x in [x0, x1]:
		for y in ry:
			if level.tile(x, y) == LevelData.AIR:
				door.append(Vector2i(x, y))
	var r: Dictionary = spec.duplicate(true)
	r.merge({"y0": y0, "y1": y1, "full": full, "door": door, "runs": _runs(door),
			"left": float((x0 + 1) * TILE), "right": float(x1 * TILE),
			"top": -INF if full else float((y0 + 1) * TILE),
			"bottom": float(level.height * TILE) if full else float(y1 * TILE),
			"phase": "wait",             # wait | closing | fight | won
			"t0": -99.0,                 # ftime the doors began to grind
			"sealed": [],                # the cells seal_free shut
			"sealed_at": -99.0,
			"specs": [],                 # its monsters: {kind, cell, tier, name, omens, ent, paid, node}
			"cells": {},                 # their cells (a foe risen on one is the room's too)
			"away": [],                  # out of the World's list: asleep or hidden
			"drops": [],                 # an ambush's drop-ins: {en, at, on}
			"named": null,               # a duel's foe (its bar)
			"named_i": -1,
			"most": 0,                   # the most foes left at once (the count bar's full)
			"resets": 0,
			"won": "",                   # clear | time | empty
			"won_at": -99.0})
	return r


static func _runs(door: Array) -> Array:
	## The doorways as runs of cells down a column: [{x, y0, y1}].
	var out: Array = []
	var cells := door.duplicate()
	cells.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for c in cells:
		var last: Dictionary = out[out.size() - 1] if not out.is_empty() else {}
		if not last.is_empty() and int(last["x"]) == c.x and int(last["y1"]) == c.y - 1:
			last["y1"] = c.y
		else:
			out.append({"x": c.x, "y0": c.y, "y1": c.y})
	return out


# ---------------------------------------------------------------- the monsters

func _take_roster() -> void:
	## Each room's monsters, once the World has anointed: out of its list
	## (asleep at their posts, or hidden), their cells out of world.spawns.
	if _rostered or world == null or not is_instance_valid(world):
		return
	_rostered = true
	var boss = world.get("boss")
	for r in rooms:
		var mine: Array = []
		for en in world.enemies:
			if not is_instance_valid(en) or not en.alive or en == boss:
				continue
			var c: Vector2i = en.spawn.get("cell", Vector2i(-1, -1))
			if c.x >= int(r["x0"]) and c.x <= int(r["x1"]) and c.y >= int(r["y0"]) and c.y <= int(r["y1"]):
				mine.append(en)
		if mine.is_empty():
			# Nothing to fight (no_monsters, all put out before an altar
			# resume, none drawn): open for good.
			r["phase"] = "won"
			r["won"] = "empty"
			continue
		mine.sort_custom(func(a, b): return a.spawn["cell"].x < b.spawn["cell"].x)
		for en in mine:
			var c: Vector2i = en.spawn["cell"]
			r["cells"][c] = true
			r["specs"].append({"kind": str(en.kind), "cell": c, "tier": str(en.tier), "name": str(en.elite_name),
					"omens": (en.omens as Array).duplicate(), "ent": int(en.spawn.get("ent", -1)),
					"paid": bool(en.respawned), "node": en})
		var cells: Dictionary = r["cells"]
		world.spawns = world.spawns.filter(func(sp): return not cells.has(sp["cell"]))
		r["named_i"] = _named_of(r)
		r["named"] = r["specs"][r["named_i"]]["node"] if int(r["named_i"]) >= 0 else null
		for en in mine:
			_put_away(r, en)


func _named_of(r: Dictionary) -> int:
	## A duel's named foe (its spec's index): the header's foe cell, else the
	## room's Dread (or a Warden), else its Anointed, else its toughest. -1
	## for an ambush or a hold.
	if str(r["kind"]) != "duel":
		return -1
	var specs: Array = r["specs"]
	var best := -1
	var best_score := -1.0
	for i in specs.size():
		var s: Dictionary = specs[i]
		if s["cell"] == r["foe"]:
			return i
		var en = s["node"]
		var score := float({"dread": 3, "warden": 3, "anointed": 2}.get(str(s["tier"]), 0)) * 1e6
		if en != null and is_instance_valid(en):
			score += float(en.max_hp)
		if score > best_score:
			best_score = score
			best = i
	return best


func _put_away(r: Dictionary, en: Node2D) -> void:
	## Out of the World's list till the doors shut: a duel's asleep at its
	## post, dim and still; an ambush's or a hold's hidden.
	if en == null or not is_instance_valid(en):
		return
	world.enemies.erase(en)
	en.active = false
	if "velocity" in en:
		en.velocity = Vector2.ZERO
	if str(r["kind"]) == "duel":
		en.modulate = DORMANT
	else:
		en.visible = false
	if not (r["away"] as Array).has(en):
		r["away"].append(en)


func _theirs(r: Dictionary, e: Node2D) -> bool:
	## One of the room's own (or risen on a room cell), or a Twinned half.
	return (r["cells"] as Dictionary).has(e.spawn.get("cell", Vector2i(-9, -9))) or bool(e.get("copy"))


func _in_room(r: Dictionary, p: Vector2) -> bool:
	if p.x < float(int(r["x0"]) * TILE) or p.x >= float((int(r["x1"]) + 1) * TILE):
		return false
	if r["full"]:
		return p.y >= -float(SLACK_UP * TILE) and p.y <= float(level.height * TILE)
	return p.y >= float(int(r["y0"]) * TILE) and p.y <= float((int(r["y1"]) + 1) * TILE)


func counted(r: Dictionary) -> Array:
	## The foes holding the doors: alive in the room, its own (_theirs).
	var out: Array = []
	var boss = world.get("boss")
	for e in world.enemies:
		if is_instance_valid(e) and e.alive and not e.gone and e != boss and _theirs(r, e) and _in_room(r, e.center()):
			out.append(e)
	return out


func foes_left(r: Dictionary) -> int:
	## Those, any still dropping in, and a restless level's remains of its own
	## still to stand (the bar's count; the tests read it).
	return counted(r).size() + (r["drops"] as Array).size() + remains_in(r).size()


func remains_in(r: Dictionary) -> Array:
	## A restless level's remains (twists.gd) of the room's own lying in it:
	## each stands again as the room's foe unless struck first, so the doors
	## wait for them. [] with no twist (or no remains).
	var tw = world.get("twists")
	var lying = tw.get("remains") if tw != null else null
	if not (lying is Array) or (lying as Array).is_empty():
		return []
	var cells: Dictionary = r["cells"]
	return (lying as Array).filter(func(rm): return cells.has(rm["cell"]) and _in_room(r, (rm["pos"] as Vector2) + Vector2(0, -4.0)))


# ---------------------------------------------------------------- the step

func step(_dt: float) -> void:
	if rooms.is_empty():
		return
	if not _rostered:
		_take_roster()
	var pl := player()
	for r in rooms:
		match str(r["phase"]):
			"wait":
				_step_wait(r, pl)
			"closing":
				_step_closing(r, pl)
			"fight":
				_step_fight(r)
	_bar()


func _step_wait(r: Dictionary, pl: Node2D) -> void:
	# One put out in its sleep (a script's kill): back in the World's list so
	# its death plays out and it's freed. None left: open for good.
	var keep: Array = []
	for en in r["away"]:
		if not is_instance_valid(en):
			continue
		if en.alive:
			keep.append(en)
		elif not world.enemies.has(en):
			en.visible = true
			en.modulate = Color.WHITE
			world.enemies.append(en)
	r["away"] = keep
	if keep.is_empty():
		r["phase"] = "won"
		r["won"] = "empty"
		return
	if pl != null and pl.alive and world.state == "play" and _inside(r, pl):
		# The doors start to grind: a rumble, a shake, dust off each lintel.
		r["phase"] = "closing"
		r["t0"] = ftime()
		world._sfx("boss_slam", 0.55, 0.0, 0.6)
		world.shake = maxf(float(world.shake), 3.0)
		world._haptic(30)
		for run in r["runs"]:
			world.dust_at(Vector2((int(run["x"]) + 0.5) * TILE, int(run["y0"]) * TILE + 4.0))


func _inside(r: Dictionary, pl: Node2D) -> bool:
	## Wick wholly inside: DOOR_PAST past the door at either end, and between
	## a rows room's ceiling and floor.
	var b: Rect2 = pl.rect()
	if b.position.x <= float(r["left"]) + DOOR_PAST or b.end.x >= float(r["right"]) - DOOR_PAST:
		return false
	return b.position.y >= float(r["top"]) - 1.0 and b.end.y <= float(r["bottom"]) + 1.0


func _step_closing(r: Dictionary, pl: Node2D) -> void:
	if ftime() - float(r["t0"]) < SEAL_TELL:
		return
	if pl == null or not pl.alive or world.state != "play" or not _inside(r, pl):
		r["phase"] = "wait"   # out again before they shut: they stay open
		return
	# Never stone round a body: his, the World's monsters', and the room's own
	# still asleep or hidden (out of world.enemies till they wake).
	var bodies: Array = [pl]
	bodies.append_array(world.enemies)
	bodies.append_array(r["away"])
	r["sealed"] = Arena.seal_free(world, level, r["door"], bodies)
	r["sealed_at"] = ftime()
	r["phase"] = "fight"
	r["most"] = (r["away"] as Array).size()
	world.shake = maxf(float(world.shake), 5.0)
	_wake(r, pl)


func _wake(r: Dictionary, pl: Node2D) -> void:
	## The doors are shut: a duel's monsters wake at their posts (the named
	## foe roars, its title card); an ambush's or a hold's drop in.
	var away: Array = r["away"]
	r["away"] = []
	if str(r["kind"]) == "duel":
		for en in away:
			if not is_instance_valid(en):
				continue
			if not world.enemies.has(en):
				world.enemies.append(en)
			en.modulate = Color.WHITE
			# Awake now, wherever the camera is; no elite plate (the bar names it).
			en.active = true
		var nf = r["named"]
		if nf != null and is_instance_valid(nf) and nf.alive:
			world._sfx("boss_roar", 1.25, 0.0, 0.7)
			if world.glow:
				world.glow.burst(nf.center(), 22, Color(1.0, 0.86, 0.7, 0.95), 150.0, 0.6, -40.0, 2.4)
			world.hud_call("title_card", [_tier_word(nf), _name_of(nf)])
			if str(nf.tier) != "":
				world.bark("first_dread" if str(nf.tier) == "dread" else "first_elite")
		return
	# Farthest from him first, one after another (each waits its post's
	# turn: _drop_ready).
	var px: float = pl.position.x if pl != null else 0.0
	away.sort_custom(func(a, b): return absf(a.position.x - px) > absf(b.position.x - px))
	var at := ftime() + DROP_FIRST
	for en in away:
		if is_instance_valid(en):
			r["drops"].append({"en": en, "at": at, "on": false})
			at += DROP_STAGGER


func _step_fight(r: Dictionary) -> void:
	_step_drops(r)
	_put_out_lost(r)
	var left := foes_left(r)
	r["most"] = maxi(int(r["most"]), left)
	if left == 0:
		_win(r, "clear")
	elif float(r["secs"]) > 0.0 and ftime() - float(r["sealed_at"]) >= float(r["secs"]):
		_win(r, "time")


func _step_drops(r: Dictionary) -> void:
	## An ambush's drop-ins: each shows with dust once its turn has come and
	## its post is clear of him and on the glass (_drop_ready), and fades in
	## over DROP_LEN (out of reach meanwhile), then joins the World's list
	## asleep: the World wakes it in view, with an Anointed's plate.
	var keep: Array = []
	var pl := player()
	for d in r["drops"]:
		var en = d["en"]
		if en == null or not is_instance_valid(en):
			continue
		if not d["on"]:
			if not _drop_ready(d, pl):
				keep.append(d)
				continue
			d["on"] = true
			d["at"] = ftime()
			en.visible = true
			en.modulate = Color(1, 1, 1, 0)
			world.dust_at(en.position + Vector2(0, -4))
			world._sfx("land", 0.7, 0.0, 0.7)
			if world.glow:
				world.glow.burst(en.center(), 10, Color(0.9, 0.86, 1.0, 0.9), 90.0, 0.5, -30.0, 2.2)
		var k := (ftime() - float(d["at"])) / DROP_LEN
		if k < 1.0:
			en.modulate = Color(1, 1, 1, clampf(k, 0.0, 1.0))
			keep.append(d)
			continue
		en.modulate = Color.WHITE
		if not world.enemies.has(en):
			world.enemies.append(en)
	r["drops"] = keep


func _drop_ready(d: Dictionary, pl: Node2D) -> bool:
	## Its turn has come, he's DROP_CLEAR px or more from its post (else it
	## waits: never a drop onto him, every retry), and its post is on the
	## glass (or it has waited DROP_WAIT s past its turn for that).
	if ftime() < float(d["at"]):
		return false
	var en: Node2D = d["en"]
	if pl != null and pl.alive and pl.center().distance_to(en.center()) < DROP_CLEAR:
		return false
	if world.in_plain_view(en.rect()):
		return true
	if _off_deck(en, pl):
		# Its turn comes again once he's on its deck: DROP_WAIT from then
		# for the camera to show its post.
		d["at"] = ftime()
		return false
	return ftime() - float(d["at"]) >= DROP_WAIT


func _off_deck(en: Node2D, pl: Node2D) -> bool:
	## A taller level's drop-in on another deck than his: its post more than
	## DECK_ROWS rows over or under his feet (a strip's never is).
	return pl != null and level.tall() and absf(en.position.y - pl.position.y) > DECK_ROWS * TILE


func _deck_post(r: Dictionary, pl: Node2D):
	## A taller level: where the bot goes while drop-ins are still due: the
	## nearest one's post while it's off the glass (on another deck, or on
	## his but not yet in view: it drops in once he's there and it shows);
	## null when it shows (the bot waits clear of it: _wait_spot) or in a strip.
	if not level.tall():
		return null
	var best: Node2D = null
	for d in r["drops"]:
		var en = d["en"]
		if d["on"] or en == null or not is_instance_valid(en):
			continue
		if best == null or (en as Node2D).position.distance_to(pl.position) < best.position.distance_to(pl.position):
			best = en
	if best == null or world.in_plain_view(best.rect()):
		return null
	return best.position


func _put_out_lost(r: Dictionary) -> void:
	## A room's foe fallen out of it (below the level; a walker's middle in
	## deep water or lava) is put out, a pit kill: nothing leaves the doors
	## shut for good. (v2's walkers fall forever in a pit, alive.)
	var x0 := float(int(r["x0"]) * TILE)
	var x1 := float((int(r["x1"]) + 1) * TILE)
	for e in world.enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or e.gone or not _theirs(r, e):
			continue
		if e.position.x < x0 or e.position.x >= x1:
			continue
		var out: bool = e.position.y > level.height * TILE + 32.0
		if not out and not bool(e.get("flier")) and not (LevelData.WATER_KINDS as Array).has(str(e.kind)) and e.has_method("lost_in_pit"):
			out = bool(e.lost_in_pit())
		if out:
			e.hp = 0.0
			e._kill({"how": "pit", "from_x": e.position.x})


func _win(r: Dictionary, how: String) -> void:
	## Won: the doors open (dust, a chime, a gold burst at each), a toast, and
	## an ambush's or a hold's REWARD.
	_unseal(r)
	# A clock out before every drop-in landed: one fading in lands now; one
	# still hidden (he kept by its post, or it waited for the glass) never
	# comes, so nothing drops onto him as the doors open.
	for d in r["drops"]:
		var en = d["en"]
		if en == null or not is_instance_valid(en):
			continue
		if d["on"]:
			en.visible = true
			en.modulate = Color.WHITE
			if not world.enemies.has(en):
				world.enemies.append(en)
		elif not world.enemies.has(en):
			en.queue_free()
	r["drops"] = []
	r["phase"] = "won"
	r["won"] = how
	r["won_at"] = ftime()
	world._sfx("bell", 1.3, 0.0, 0.7)
	world._haptic(40)
	if world.glow:
		for run in r["runs"]:
			var p := Vector2((int(run["x"]) + 0.5) * TILE, (int(run["y0"]) + int(run["y1"]) + 1) * 0.5 * TILE)
			world.glow.burst(p, 16, GILT, 120.0, 0.7, -40.0, 2.4)
	# "Duel won" (and whom), "Ambush beaten", or "Held" (a hold, or a clock run out).
	var line: Array = ["Held", "The doors open"]
	if how == "clear" and str(r["kind"]) == "duel":
		line[0] = "Duel won"
		if int(r["named_i"]) >= 0:
			var s: Dictionary = r["specs"][int(r["named_i"])]
			line[1] = str(s["name"]) if str(s["name"]) != "" else _kind_name(str(s["kind"]))
	elif how == "clear" and str(r["kind"]) == "ambush":
		line[0] = "Ambush beaten"
	world.hud_call("toast", line)
	var src := str(REWARD.get(r["kind"], ""))
	var pl := player()
	if src != "" and pl != null and world.allows("loot"):
		world.drop_item(pl.center() + Vector2(pl.facing * 24.0, -30.0), src)


func _unseal(r: Dictionary) -> void:
	var cells: Array = r["sealed"]
	if cells.is_empty():
		return
	Arena.unseal(world, level, cells)
	for c in cells:
		world.dust_at(LevelData.cell_center(c))
	world._sfx("block_break", 0.8)
	r["sealed"] = []


func on_respawn() -> void:
	## A snuff while a room is shut: it opens and starts over, as a boss room
	## (Wick relights at the altar by its door: the World's checkpoint).
	for r in rooms:
		if r["phase"] == "closing":
			r["phase"] = "wait"
		elif r["phase"] == "fight":
			_reset(r)
	_bar()


func _reset(r: Dictionary) -> void:
	_unseal(r)
	var boss = world.get("boss")
	# Everything alive in it goes (its monsters, their halves, the risen; a
	# stray with them), and any still dropping in.
	for e in world.enemies:
		if is_instance_valid(e) and e.alive and not e.gone and e != boss and _in_room(r, e.center()):
			e.gone = true
	for d in r["drops"]:
		var en = d["en"]
		if en != null and is_instance_valid(en) and not world.enemies.has(en):
			en.queue_free()
	r["drops"] = []
	for en in r["away"]:
		if is_instance_valid(en) and not world.enemies.has(en):
			en.queue_free()
	r["away"] = []
	# Its monsters back at their posts: one put out this time (or before)
	# comes back as a respawn, and off the altar snapshot's killed list.
	var killed = world.get("_killed")
	var fresh: Array = []
	for s in r["specs"]:
		var old = s.get("node")
		if old == null or not is_instance_valid(old) or not old.alive:
			s["paid"] = true
		var k: String = s["kind"]
		var c: Vector2i = s["cell"]
		var en: Node2D = world.spawn_enemy(k, EnemyKinds.spawn_pos(k, c), {"tier": s["tier"], "name": s["name"],
				"omens": (s["omens"] as Array).duplicate(), "cell": c, "respawned": bool(s["paid"])})
		s["node"] = en
		if en == null:
			continue
		if str(s["tier"]) != "":
			en.ordinary = false
		if int(s["ent"]) >= 0:
			en.spawn["ent"] = int(s["ent"])
			if killed is Array:
				while (killed as Array).has(int(s["ent"])):
					(killed as Array).erase(int(s["ent"]))
		fresh.append(en)
	for en in fresh:
		_put_away(r, en)
	r["named"] = r["specs"][int(r["named_i"])]["node"] if int(r["named_i"]) >= 0 else null
	r["phase"] = "wait" if not fresh.is_empty() else "won"
	if fresh.is_empty():
		r["won"] = "empty"
	r["resets"] = int(r["resets"]) + 1


# ---------------------------------------------------------------- the bar

func _bar() -> void:
	## The shut room's bar in the boss bar's place (never over a boss's or a
	## Warden's); {} once no room is shut.
	var b = world.get("boss")
	var wd = world.get("warden")
	if (b != null and is_instance_valid(b)) or (wd != null and is_instance_valid(wd)):
		return
	var info := {}
	for r in rooms:
		if r["phase"] == "fight":
			info = bar_info(r)
			break
	if info.is_empty():
		if _bar_up:
			_bar_up = false
			world.hud_call("boss_bar", [{}])
		return
	_bar_up = true
	world.hud_call("boss_bar", [info])


func bar_info(r: Dictionary) -> Dictionary:
	## The bar: {id, name, title, frac, awake[, clock]} (the tests read it).
	## A duel's named foe while it stands; a clock's time left (clock: the
	## HUD draws it gold, no trail); else the foes left.
	var left := foes_left(r)
	var nf = r["named"]
	if str(r["kind"]) == "duel" and nf != null and is_instance_valid(nf) and nf.alive:
		return {"id": "room", "name": _name_of(nf), "title": _title_of(nf),
				"frac": float(nf.hp) / maxf(float(nf.max_hp), 1.0), "awake": true}
	var secs := float(r["secs"])
	if secs > 0.0:
		var t_left := maxf(secs - (ftime() - float(r["sealed_at"])), 0.0)
		var s := ceili(t_left)
		return {"id": "room", "name": "%s · %d:%02d" % [WORD[r["kind"]], floori(s / 60.0), s % 60],
				"title": "%d left" % left, "frac": t_left / secs, "awake": true, "clock": true}
	return {"id": "room", "name": "%s · %d" % [WORD[r["kind"]], left], "title": "",
			"frac": float(left) / maxf(float(r["most"]), 1.0), "awake": true}


func _name_of(e: Node2D) -> String:
	return str(e.elite_name) if str(e.elite_name) != "" else _kind_name(str(e.kind))


static func _kind_name(kind: String) -> String:
	var names: Dictionary = (load(ELITES) as Script).get_script_constant_map().get("NAMES", {}) if ResourceLoader.exists(ELITES) else {}
	return str(names.get(kind, kind.capitalize()))


func _tier_word(e: Node2D) -> String:
	## A duel's card line and its bar's title: "Dread", "Warden", "Anointed",
	## else "Duel".
	var t := str(e.tier)
	return t.capitalize() if t != "" else "Duel"


func _title_of(e: Node2D) -> String:
	var out := _tier_word(e)
	for o in (e.omens if e.omens is Array else []):
		out += " · " + str(o).capitalize()
	return out


# ---------------------------------------------------------------- the bot

func bot_target(pl: Node2D):
	## The --autoplay bot's foe in a shut room (autoplay_bot.gd's room pad):
	## the nearest that holds the doors; a restless level's remains still to
	## stand (it swings over them); while they drop in, a spot clear of every
	## post still to drop (_wait_spot: a drop waits while he's near it; in a
	## taller level on that post's deck), or, in a taller level with the
	## nearest one off the glass, its post (_deck_post: autoplay_bot.gd plans
	## its way there); null while no room is shut.
	for r in rooms:
		if r["phase"] != "fight":
			continue
		var best: Node2D = null
		for e in counted(r):
			if best == null or e.center().distance_to(pl.center()) < best.center().distance_to(pl.center()):
				best = e
		if best != null:
			return best
		for rm in remains_in(r):
			return Vector2((rm["pos"] as Vector2).x, pl.position.y)
		var deck = _deck_post(r, pl)
		if deck != null:
			return deck
		return Vector2(_wait_spot(r, pl), _wait_y(r, pl))
	return null


func _wait_y(r: Dictionary, pl: Node2D) -> float:
	## The floor to wait on: his (a strip's, as ever); a taller level's the
	## nearest post still to drop's (its deck: not the floor under him).
	if not level.tall():
		return pl.position.y
	var y := pl.position.y
	var bd := INF
	for d in r["drops"]:
		var en = d["en"]
		if not d["on"] and en != null and is_instance_valid(en) and (en as Node2D).position.distance_to(pl.position) < bd:
			bd = (en as Node2D).position.distance_to(pl.position)
			y = (en as Node2D).position.y
	return y


func _wait_spot(r: Dictionary, pl: Node2D) -> float:
	## Where to wait while drop-ins are due: the nearest x in the room at
	## least DROP_CLEAR + 48 px from every post still to drop (the bot's pad
	## stops 36 px short; beside one, so it's on the glass too), else the
	## room's middle.
	var posts: Array = []
	for d in r["drops"]:
		if not d["on"] and d["en"] != null and is_instance_valid(d["en"]):
			posts.append((d["en"] as Node2D).center().x)
	var mid := (float(r["left"]) + float(r["right"])) * 0.5
	if posts.is_empty():
		return mid
	var gap := DROP_CLEAR + 48.0
	var lo := float(r["left"]) + 20.0
	var hi := float(r["right"]) - 20.0
	var best := mid
	var best_d := INF
	for p in posts:
		for x in [float(p) - gap, float(p) + gap]:
			if x < lo or x > hi or posts.any(func(q): return absf(float(q) - x) < gap - 1.0):
				continue
			if absf(x - pl.position.x) < best_d:
				best_d = absf(x - pl.position.x)
				best = x
	return best


# ---------------------------------------------------------------- drawing

func draw_under(ci: CanvasItem) -> void:
	## A doorway that can shut wears an iron lintel with its teeth; shutting,
	## a slab comes down it, gathering speed.
	if rooms.is_empty():
		return
	var vr: Rect2 = view().grow(64.0)
	for r in rooms:
		var ph := str(r["phase"])
		if ph != "wait" and ph != "closing":
			continue
		for run in r["runs"]:
			var x := float(int(run["x"]) * TILE)
			var top := float(int(run["y0"]) * TILE)
			var bot := float((int(run["y1"]) + 1) * TILE)
			if not vr.intersects(Rect2(x, top, TILE, bot - top)):
				continue
			if ph == "closing":
				var k := clampf((ftime() - float(r["t0"])) / SEAL_TELL, 0.0, 1.0)
				var y := top + (bot - top) * k * k
				ci.draw_rect(Rect2(x + 2.0, top, TILE - 4.0, y - top), SLAB)
				ci.draw_rect(Rect2(x + 2.0, maxf(y - 4.0, top), TILE - 4.0, minf(4.0, y - top)), SLAB_LIP)
			if int(run["y0"]) > 0 and LevelData.is_solid(level.tile(int(run["x"]), int(run["y0"]) - 1)):
				ci.draw_rect(Rect2(x, top, TILE, 5.0), IRON)
				for i in 3:
					var cx := x + 6.0 + i * 10.0
					_tb.tri(Vector2(cx - 3.0, top + 5.0), Vector2(cx + 3.0, top + 5.0), Vector2(cx, top + 10.0), IRON)
	_tb.flush(ci)


func draw_glow(glow: Node2D) -> void:
	## Above the dark (a door is often past his light): a shutting slab's
	## shape and its glowing edge; the shut doors' ember seams, beating till
	## it's won; the open doors' gold after a win.
	if rooms.is_empty():
		return
	var vr: Rect2 = view().grow(64.0)
	var t := ftime()
	for r in rooms:
		var ph := str(r["phase"])
		if ph == "closing":
			var k := clampf((t - float(r["t0"])) / SEAL_TELL, 0.0, 1.0)
			for run in r["runs"]:
				var x := float(int(run["x"]) * TILE)
				var top := float(int(run["y0"]) * TILE)
				var y := top + float(int(run["y1"]) + 1 - int(run["y0"])) * TILE * k * k
				if not vr.intersects(Rect2(x, top, TILE, y - top + 8.0)):
					continue
				_tb.rect(Rect2(x + 2.0, top, TILE - 4.0, y - top), Color(SLAB_LIP, 0.35))
				_tb.rect(Rect2(x, y - 3.0, TILE, 3.0), Color(EMBER, 0.9))
				for i in 3:
					var sx := x + 4.0 + fposmod(t * 97.0 + i * 11.0, TILE - 8.0)
					_tb.rect(Rect2(sx, y - 1.0 + fposmod(t * 53.0 + i * 7.0, 6.0), 2.0, 2.0), Color(GILT, 0.8))
		elif ph == "fight":
			var a := 0.6 + 0.3 * sin(t * 4.0)
			for c in r["sealed"]:
				var p := Vector2(c.x * TILE, c.y * TILE)
				if vr.has_point(p):
					_tb.rect(Rect2(p.x + TILE * 0.5 - 1.5, p.y, 3.0, TILE), Color(EMBER, a))
					_tb.rect(Rect2(p.x + 3.0, p.y + TILE - 2.0, TILE - 6.0, 2.0), Color(EMBER, a * 0.6))
		elif ph == "won" and str(r["won"]) != "empty":
			var k := 1.0 - (t - float(r["won_at"])) / WON_FX
			if k <= 0.0:
				continue
			for c in r["door"]:
				var p := Vector2(c.x * TILE, c.y * TILE)
				if vr.has_point(p):
					_tb.rect(Rect2(p.x + 4.0, p.y + 4.0, TILE - 8.0, TILE - 8.0), Color(GILT, 0.25 * k))
	_tb.flush(glow)
