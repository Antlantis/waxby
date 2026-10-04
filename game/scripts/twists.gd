extends RefCounted
## Level twists (Build 2): one named rule a level may carry, read from its
## optional `twist: <id>` header, and an X-1's lesson card (`lesson:
## Title|Line`), a card with no rule. A level without either plays exactly
## as before: nothing here is built, and every hook below returns what the
## World had. Story levels and the feel labs only: a mode (the Descent, the
## Waxworks, the Trials) never has a twist (world.twist_id).
##
## The title card's line reads "4-2 · On the Hour" over the level's name,
## then a card in the top band gives the twist's line (or the lesson's),
## once per level and difficulty (Game.seen; world.gd _twist_cards). The
## names and lines are per world (CARDS: a world's own, else the 0 row), 48
## characters at most, so a line fits the band at 14 px on the phone.
##
## The rules (TWISTS[id].rule; world.twist(rule) asks):
##   restless  a stomped ordinary monster's remains glow where it fell; after
##             RISE_WAIT s they twitch for RISE_TELL s (the tell, on the glow
##             layer so it reads in the dark), and it stands once more, unless
##             a swing, a hero shot, a hero's wave or a dash Special touches
##             the remains first. It rises only in plain view (world.gd
##             in_plain_view: never off the glass or behind a thumb button or
##             the HUD) and never within RISE_CLEAR px of Waxby (it waits,
##             still twitching). A risen one is "respawned" and pays nothing
##             (no embers, no XP, no loot: world.gd _on_enemy_died) and never
##             rises again. "restless" raises Rattles only (World 1's);
##             "restless_all" every ordinary floor kind but the pack bringers.
##             A snuff lays every waiting one to rest.
##   dark      Waxby's light x DARK (world.dim "twist:dark"), floored with
##             every other dim at Combat.DIM_FLOOR (Dusk's 0.5); dim_resist
##             softens it. Lanterns, glowfruit and Vigil candles are not dimmed.
##   omens     the random Anointed chance x OMEN_CHANCE (the max unchanged),
##             and a second Omen gets two rolls (world.elite_rules)
##   dry       altars and the flask heal x DRY_HEAL (Build 1's 0.40 Dusk
##             altars from World 3 heal 0.30, the 0.40 flask 0.30)
##   packs     the pack kinds use their biggest pack rule (Witching's), with
##             their Dusk tells: Hushlings 3-5, Glassmite trios, Tickwinds
##             within FILE_X wind and charge as a file, a Creepbone's lane
##             partner, an Unwick's pair (each kind asks Twists.on(e, "packs"))
##   toll      a great bell tolls every TOLL_EVERY beats of the level's tick
##             (level.tick, the W4 carillon's 0.536 s; world.ftime, so it
##             stops with stop_time); every monster in plain view runs x1.3
##             (elites.gd alert: speed only, never a tell) for TOLL_RUN beats.
##             The beat before, a ring closes on each of them and the clock
##             tocks (the warning, on the glow layer for a muted phone)
##   lamplit   a crumbling ledge cell within LAMP_R px of a lit lantern holds
##             firm when stood on (world.gd stood_on), with a warm glint on
##             its top; when the lantern gutters (its 3 s flicker is the tell)
##             and goes out, it is soft wax again and shakes its 0.55 s
##   duel      a card only: the sealed room is the rooms' feature
## The belts' flip on the beat is a header of its own (belt_flip: x0-x1=N),
## read by features/clockwork.gd beside the toll.

const LevelData := preload("res://scripts/level_data.gd")
const EnemyKinds := preload("res://scripts/enemy_kinds.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TILE := LevelData.TILE

# id -> {rule, cards: {world: [name, line]}} (the 0 row for every world
# without its own). "kinds" (restless): the kinds that rise, or "floor".
const TWISTS := {
	"restless": {"rule": "restless", "kinds": ["skeleton"],
			"cards": {0: ["Restless", "Stomped bones rise once. Strike them to rest."]}},
	"restless_all": {"rule": "restless", "kinds": "floor",
			"cards": {0: ["Restless", "The fallen rise once. Strike their remains."]}},
	"dark": {"rule": "dark", "cards": {0: ["Dark", "Your flame is dim here. Lanterns light the way."],
			6: ["The Drowned Dark", "Your light is small here. Ring the bells to see."]}},
	"omens": {"rule": "omens", "cards": {0: ["Omens", "The Hush runs thick here. More of them glow."],
			5: ["The Saint's Guard", "Her guard wears blue. Expect the Anointed."]}},
	"dry": {"rule": "dry", "cards": {0: ["Cold Altars", "Frozen altars mend less, but there are more."]}},
	"packs": {"rule": "packs", "cards": {0: ["Hunted", "They hunt in packs now. Keep to the light."],
			5: ["Swarming Glass", "Glassmites come in threes. The wind herds them."]}},
	"toll": {"rule": "toll", "cards": {0: ["On the Hour", "Each toll wakes them. Fight between the bells."]}},
	"lamplit": {"rule": "lamplit", "cards": {0: ["Lamplit", "Soft wax holds firm in lantern light."]}},
	"duel": {"rule": "", "cards": {0: ["Duel", "Climb into the loft and it seals till one falls."]}},
}
const LINE_MAX := 48             # characters in a card's line (the band's 14 px on the phone)
const DARK := 0.8                # dark: Waxby's light
const OMEN_CHANCE := 2.0         # omens: the random Anointed chance
const DRY_HEAL := 0.75           # dry: what an altar or a draught heals of its own
const RISE_WAIT := 3.0           # restless: s the remains lie still...
const RISE_TELL := 1.0           # ...then twitch (the tell) before it stands
const RISE_CLEAR := 96.0         # px: never rises this near Waxby (3 tiles)
const RESTLESS_NOT := ["hushling", "glassmite"]   # restless_all: a pack bringer's leader would bring a new pack
const REMAINS_W := 28.0          # the remains' rect a strike must touch (px, on the floor)
const REMAINS_H := 18.0
const TOLL_EVERY := 16           # toll: beats between tolls (on beat 16 of 16)
const TOLL_RUN := 4              # beats the tolled run x1.3 (elites.gd ALERT_SPEED)
const LAMP_R := 100.0            # lamplit: px from a lit lantern's flame to a ledge cell's middle (about 3 tiles)
const SOUL := Color("7ef0c8")    # the remains' wisp (the monsters' eye glow)
const RISEN_TINT := Color(0.78, 1.0, 0.9)   # a risen one's sprite (it pays nothing: it looks it)
const BELL := Color("f0d080")    # the toll's rings (clockwork's BRASS_LIT)
const WARM := Color("f7b64a")    # lamplit's glint (the altar flame's)

var world: Node
var id := ""
var rule := ""
var remains: Array = []          # restless: {kind, cell, pos, facing, tex, anchor, scale, squash, tint, t, tell, still}
var risen := 0                   # restless: rose this level
var laid := 0                    # restless: struck before they rose
var tolls := 0                   # toll: tolled this level
var _kinds = []                  # restless: the kinds that rise, or "floor"
var _tick := LevelData.TICK
var _beat := -1
var _warn := -1.0                # toll: s left of the warning beat (-1: none)
var _rang := -1.0                # toll: s since the last toll (its rings), -1: none
var _tolled: Array = []          # toll: who the last toll quickened (weakrefs, for their rings)
var _lamp_cells := {}            # lamplit: crumble cell -> [lantern indices within LAMP_R]
var _under: Node2D = null        # the remains, in the world under the monsters
var _over: Node2D = null         # the tells, on the glow layer
var _tb := TriBatch.new()
var _t := 0.0
var _drawn := 0                  # remains the under painter last drew (one more redraw clears the last)


# ---------------------------------------------------------------- the registry

static func id_in(level: RefCounted) -> String:
	## The level's twist id from its header ("" for none or one not in TWISTS).
	if level == null:
		return ""
	var h = level.get("headers")
	if not (h is Dictionary):
		return ""
	var v := str((h as Dictionary).get("twist", "")).strip_edges().to_lower()
	return v if TWISTS.has(v) else ""


static func rule_of(twist_id: String) -> String:
	return str((TWISTS.get(twist_id, {}) as Dictionary).get("rule", ""))


static func card_of(twist_id: String, world_n: int) -> Array:
	## [name, line] for the twist in this world (its own row, else row 0), or [].
	var cards: Dictionary = (TWISTS.get(twist_id, {}) as Dictionary).get("cards", {})
	if cards.is_empty():
		return []
	return (cards.get(world_n, cards.get(0, [])) as Array).duplicate()


static func lesson_in(level: RefCounted) -> Array:
	## An X-1's lesson card from `lesson: Title|Line`: [title, line], or [].
	if level == null or not (level.get("headers") is Dictionary):
		return []
	var v := str((level.headers as Dictionary).get("lesson", "")).strip_edges()
	if v == "":
		return []
	var parts := v.split("|", true, 1)
	return [parts[0].strip_edges(), parts[1].strip_edges() if parts.size() > 1 else ""]


static func heal_mult(twist_id: String) -> float:
	## dry: what an altar or the flask heals, of what it would.
	return DRY_HEAL if rule_of(twist_id) == "dry" else 1.0


static func elite_rules(twist_id: String, rules: Dictionary) -> Dictionary:
	## omens: the Anointed chance x OMEN_CHANCE, the max unchanged, and a
	## second Omen gets two rolls (1 - (1 - s)^2: World 3's 0.2 is 0.36,
	## World 5's 0.5 is 0.75). Changes rules in place, and returns it.
	if rule_of(twist_id) != "omens":
		return rules
	rules["anoint"] = minf(float(rules.get("anoint", 0.0)) * OMEN_CHANCE, 1.0)
	var s := clampf(float(rules.get("second_omen", 0.0)), 0.0, 1.0)
	rules["second_omen"] = 1.0 - (1.0 - s) * (1.0 - s)
	return rules


static func on(e: Object, what: String) -> bool:
	## Does e's World have this twist rule on? (A monster asks for "packs".)
	if e == null:
		return false
	var w = e.get("world")
	return w != null and is_instance_valid(w) and w.has_method("twist") and bool(w.twist(what))


static func is_risen(e: Object) -> bool:
	## A restless monster back on its feet (it pays nothing, and never rises again).
	var sp = e.get("spawn") if e != null else null
	return sp is Dictionary and bool((sp as Dictionary).get("risen", false))


static func make(w: Node) -> RefCounted:
	## The twist's runtime for this World, or null with no rule to run (no
	## header, a card-only twist, a mode).
	var tid: String = str(w.twist_id()) if w.has_method("twist_id") else ""
	if rule_of(tid) == "":
		return null
	var t = load("res://scripts/twists.gd").new()
	t.setup(w, tid)
	return t


# ---------------------------------------------------------------- the runtime

func setup(w: Node, twist_id: String) -> void:
	world = w
	id = twist_id
	rule = rule_of(twist_id)
	_kinds = (TWISTS[id] as Dictionary).get("kinds", [])
	_tick = float(w.level.tick) if float(w.level.tick) > 0.0 else LevelData.TICK
	match rule:
		"dark":
			w.dim("twist:dark", DARK, 1.0e9)
		"lamplit":
			_find_lamp_cells()
	# Two painters: the remains in the world (drawn under the monsters, in the
	# dark like them) and the tells above the dark (beside glow.gd).
	_under = Node2D.new()
	_under.name = "TwistUnder"
	_under.draw.connect(func(): _draw_under(_under))
	w.add_child(_under)
	var mons = w.get_node_or_null("Monsters")
	if mons != null:
		w.move_child(_under, mons.get_index())
	var glow = w.get("glow")
	if glow != null and glow.get_parent() != null:
		_over = Node2D.new()
		_over.name = "TwistGlow"
		_over.draw.connect(func(): _draw_over(_over))
		glow.get_parent().add_child(_over)


func step(dt: float) -> void:
	## The World's tick (never while time is stopped, nor in a hitstop).
	_t += dt
	match rule:
		"restless":
			_step_remains(dt)
		"toll":
			_step_toll(dt)
	if _under != null and (not remains.is_empty() or _drawn > 0):
		_under.queue_redraw()
		_drawn = remains.size()
	if _over != null and rule in ["restless", "toll", "lamplit"]:
		_over.queue_redraw()


func on_respawn() -> void:
	## A relight after a snuff: the remains that hadn't risen are at rest.
	remains.clear()
	_warn = -1.0
	if _under != null:
		_under.queue_redraw()


func log_extra() -> Dictionary:
	## The playlog line's twist fields (world.gd _log).
	var out := {"twist": id}
	if rule == "restless":
		out["risen"] = risen
		out["laid"] = laid
	elif rule == "toll":
		out["tolls"] = tolls
	return out


# ---------------------------------------------------------------- restless

func rises(e: Node2D) -> bool:
	## Would this monster's remains get up again (it was stomped)?
	if rule != "restless" or e == null or not bool(e.get("ordinary")) or str(e.get("tier")) != "" or bool(e.get("copy")):
		return false
	if e == world.get("boss") or is_risen(e):
		return false
	var cell = (e.get("spawn") as Dictionary).get("cell", Vector2i(-1, -1)) if e.get("spawn") is Dictionary else Vector2i(-1, -1)
	if not (cell is Vector2i) or (cell as Vector2i).x < 0:
		return false   # (a pack's extra, a lane partner: brought, never placed)
	var k := str(e.get("kind"))
	if _kinds is Array:
		return (_kinds as Array).has(k)
	return str(EnemyKinds.info(k).get("spawn", "")) == "floor" and not RESTLESS_NOT.has(k)


func on_enemy_died(e: Node2D, how: String) -> void:
	## A stomp kill of a restless kind leaves its remains where it fell.
	if how != "stomp" or not rises(e):
		return
	var feet := _floor_under(e.position)
	if feet == Vector2.INF:
		return   # (nothing under it to lie on)
	var k := str(e.kind)
	var tex: Texture2D = null
	var frames = e.get("frames")
	if k == "skeleton" and frames is Dictionary and (frames as Dictionary).has("skel_bones"):
		tex = frames["skel_bones"]
	elif e.get("sprite") != null and e.sprite.texture != null:
		tex = e.sprite.texture
	remains.append({"kind": k, "cell": e.spawn["cell"], "pos": feet, "facing": int(e.facing),
			"tex": tex, "anchor": e.anchor, "scale": 0.25 * float(e.scale_mult),
			"squash": 1.0 if k == "skeleton" else 0.45, "tint": e.tint, "t": 0.0, "tell": -1.0})


func _floor_under(p: Vector2) -> Vector2:
	## Where its remains lie: the floor at or just under p (within 2 tiles), or INF.
	var lv: RefCounted = world.level
	var cx := floori(p.x / TILE)
	for ty in range(floori((p.y - 1.0) / TILE) + 1, floori((p.y - 1.0) / TILE) + 3):
		if LevelData.is_floor(lv.tile(cx, ty)) and not LevelData.is_solid(lv.tile(cx, ty - 1)):
			return Vector2(p.x, ty * TILE)
	return Vector2.INF


func remains_rect(r: Dictionary) -> Rect2:
	var p: Vector2 = r["pos"]
	return Rect2(p.x - REMAINS_W * 0.5, p.y - REMAINS_H, REMAINS_W, REMAINS_H)


func remains_in(box: Rect2) -> bool:
	## Do any remains lie in box? (The autoplay bot swings at them.)
	for r in remains:
		if remains_rect(r).intersects(box):
			return true
	return false


func _step_remains(dt: float) -> void:
	var pl: Node2D = world.player
	if pl == null or remains.is_empty():
		return
	var playing: bool = str(world.state) == "play" and bool(pl.alive)
	var struck: Array = []
	for r in remains:
		var rr := remains_rect(r)
		if playing and _struck(rr, pl):
			struck.append(r)
			continue
		r["t"] = float(r["t"]) + dt
		var seen: bool = world.in_plain_view(rr.grow_individual(0, 24, 0, 0))
		if float(r["tell"]) < 0.0:
			if float(r["t"]) >= RISE_WAIT and seen and playing:
				r["tell"] = 0.0
				world._sfx("bones", 0.7, 0.0, 0.8)
			continue
		if not seen:
			continue   # (the tell waits on the glass)
		r["tell"] = float(r["tell"]) + dt
		if float(r["tell"]) >= RISE_TELL and playing and pl.center().distance_to(rr.get_center()) >= RISE_CLEAR:
			r["up"] = true
	if not struck.is_empty():
		remains = remains.filter(func(r): return not struck.any(func(s): return is_same(s, r)))
	for r in struck:
		laid += 1
		var c := remains_rect(r).get_center()
		world.dust_at(Vector2(c.x, r["pos"].y))
		if world.glow:
			world.glow.burst(c, 10, Color(SOUL, 0.8), 90.0, 0.4, -40.0, 2.0)
		world._sfx("bones", 1.25)
		world.floaters.add(c + Vector2(0, -18), 0.0, "text", 0, "At rest")
	var up: Array = remains.filter(func(r): return r.get("up", false))
	if not up.is_empty():
		remains = remains.filter(func(r): return not r.get("up", false))
		for r in up:
			_rise(r)


func _struck(rr: Rect2, pl: Node2D) -> bool:
	## A swing, a hero shot or wave, or a dash Special (the knight's rush, the
	## runner's Smoke Step) touching the remains.
	var ar: Rect2 = pl.attack_rect()
	if ar.has_area() and ar.intersects(rr):
		return true
	if float(pl.get("dash_time")) > 0.0 and pl.rect().intersects(rr):
		return true
	for s in world.shots:
		if str(s.get("owner", "")) == "player" and float(s.get("life", 0.0)) > 0.0 \
				and rr.grow(float(s.get("radius", 0.0))).has_point(s["pos"]):
			return true
	for h in world.hazards:
		if str(h.get("owner", "")) == "player" and h.get("rect") is Rect2 and (h["rect"] as Rect2).intersects(rr):
			return true
	return false


func _rise(r: Dictionary) -> void:
	## It stands again where it fell: back as a respawn (no embers), marked
	## risen (no XP or loot either, and it never rises again), facing him.
	var pl: Node2D = world.player
	var pos: Vector2 = r["pos"]
	var face := 1 if pl.position.x > pos.x else -1
	var en: Node2D = world.spawn_enemy(str(r["kind"]), pos, {"cell": r["cell"], "respawned": true, "facing": face})
	if en == null:
		return
	en.spawn["risen"] = true
	en.active = true
	en.tint = (en.tint as Color) * RISEN_TINT   # (a grave-green cast: it's been down once)
	risen += 1
	world.dust_at(pos)
	if world.glow:
		world.glow.burst(pos + Vector2(0, -12), 14, SOUL, 120.0, 0.5, -60.0, 2.2)
	world._sfx("bones", 1.1)


# ---------------------------------------------------------------- the toll

func beat() -> int:
	## The level's ticks so far (clockwork's beat(), on world.ftime).
	return floori(float(world.ftime) / _tick)


func _step_toll(dt: float) -> void:
	_warn = maxf(_warn - dt, -1.0) if _warn >= 0.0 else -1.0
	if _rang >= 0.0:
		_rang += dt
		if _rang > 0.6:
			_rang = -1.0
	var b := beat()
	if b == _beat:
		return
	_beat = b
	if b <= 0:
		return
	if posmod(b + 1, TOLL_EVERY) == 0:
		# The warning: a beat before the toll, the clock's hand jumps.
		_warn = _tick
		world._sfx("clock_tock", 1.0, 0.0, 0.8)
	elif posmod(b, TOLL_EVERY) == 0:
		toll()


func toll() -> void:
	## The great bell: every monster in plain view runs x1.3 for TOLL_RUN beats.
	tolls += 1
	_warn = -1.0
	_rang = 0.0
	_tolled.clear()
	for e in in_view():
		e.alert(TOLL_RUN * _tick)
		_tolled.append(weakref(e))
	world._sfx("chime_hour")
	world._haptic(30)
	world.shake = maxf(float(world.shake), 2.0)


func in_view() -> Array:
	## The monsters a toll quickens: alive, awake and in plain view (never the boss).
	var out := []
	if str(world.state) != "play":
		return out
	for e in world.enemies:
		if e.alive and e.active and e != world.get("boss") and e.has_method("alert") and world.in_plain_view(e.rect()):
			out.append(e)
	return out


func warning() -> bool:
	## The beat before a toll (its rings are up).
	return _warn >= 0.0


# ---------------------------------------------------------------- lamplit

func _find_lamp_cells() -> void:
	## Each crumbling ledge cell within LAMP_R of a lantern's flame (they don't move).
	var lf = world.get("features")
	if lf == null or not ("lanterns" in lf):
		return
	for cell in world.crumbles:
		var mid := LevelData.cell_center(cell)
		var near: Array = []
		for i in lf.lanterns.size():
			var l: Dictionary = lf.lanterns[i]
			if not bool(l.get("brazier", false)) and (l["flame"] as Vector2).distance_to(mid) <= LAMP_R:
				near.append(i)
		if not near.is_empty():
			_lamp_cells[cell] = near


func _lamp_of(cell: Vector2i) -> Dictionary:
	## The lit lantern that holds this cell ({}: none).
	var near = _lamp_cells.get(cell)
	if near == null:
		return {}
	var lf = world.get("features")
	for i in near:
		var l: Dictionary = lf.lanterns[i]
		if bool(l.get("lit", false)):
			return l
	return {}


func holds_crumble(cell: Vector2i) -> bool:
	## lamplit: a lit lantern keeps this crumbling ledge cell from shaking.
	return rule == "lamplit" and not _lamp_of(cell).is_empty()


# ---------------------------------------------------------------- drawing

func _draw_under(ci: Node2D) -> void:
	## The remains, where they fell: a Rattle's bones, another kind's last
	## frame squashed into a heap; they shiver through the tell.
	var v: Rect2 = world.view_rect().grow(64.0)
	for r in remains:
		var p: Vector2 = r["pos"]
		if not v.has_point(p):
			continue
		var tell := float(r["tell"])
		var a := clampf((float(r["t"]) - 0.5) / 0.5, 0.0, 1.0) if str(r["kind"]) == "skeleton" else clampf(float(r["t"]) * 3.0, 0.0, 1.0)
		var jit := Vector2.ZERO
		if tell >= 0.0:
			var k := clampf(tell / RISE_TELL, 0.0, 1.0)
			jit = Vector2(sin(_t * 61.0) * (1.0 + 2.0 * k), -absf(sin(_t * 23.0)) * 2.0 * k)
		var tex: Texture2D = r["tex"]
		var col: Color = (r["tint"] as Color) * Color(0.62, 0.62, 0.7)
		if tex != null:
			var sc := float(r["scale"])
			ci.draw_set_transform(p + jit, 0.0, Vector2(sc * (1.0 if int(r["facing"]) > 0 else -1.0), sc * float(r["squash"])))
			ci.draw_texture(tex, -(r["anchor"] as Vector2) * 2.0, Color(col, a))
			ci.draw_set_transform(Vector2.ZERO)
		else:
			for i in 3:
				ci.draw_rect(Rect2(p + jit + Vector2(-10 + i * 7, -4 - (i % 2) * 3), Vector2(8, 3)), Color(Color("d8d0bc"), a))


func _draw_over(ci: Node2D) -> void:
	var v: Rect2 = world.view_rect().grow(64.0)
	for r in remains:
		var p: Vector2 = (r["pos"] as Vector2) + Vector2(0, -7)
		if not v.has_point(p):
			continue
		var tell := float(r["tell"])
		if tell < 0.0:
			# Lying: a faint wisp breathing over them (they're restless).
			var b := 0.5 + 0.5 * sin(_t * 3.0 + p.x * 0.05)
			_tb.circle(p, 3.0 + 1.5 * b, Color(SOUL, (0.18 + 0.14 * b) * clampf(float(r["t"]) * 2.0, 0.0, 1.0)), 10)
		else:
			# The tell: a ring closing on the remains, the wisp swelling, eyes.
			var k := clampf(tell / RISE_TELL, 0.0, 1.0)
			_tb.ring(p, lerpf(30.0, 9.0, k), 2.0, Color(SOUL, 0.35 + 0.5 * k), 18)
			_tb.circle(p + Vector2(0, -4.0 * k), 4.0 + 4.0 * k, Color(SOUL, 0.45 + 0.4 * k), 12)
			for dx in [-3.5, 3.5]:
				_tb.circle(p + Vector2(dx, -9.0 * k), 1.6, Color(Color.WHITE, k), 6)
	if rule == "toll":
		if _warn >= 0.0:
			# The warning beat: a gold ring closes on everything the toll will
			# quicken, a fainter one following it in.
			var kw := 1.0 - clampf(_warn / _tick, 0.0, 1.0)
			for e in in_view():
				var c: Vector2 = e.center()
				_tb.ring(c, lerpf(44.0, 16.0, kw), 3.0, Color(BELL, 0.45 + 0.5 * kw), 20)
				_tb.ring(c, lerpf(64.0, 24.0, kw), 1.5, Color(BELL, 0.25 * kw), 20)
		if _rang >= 0.0:
			# The toll: the ring bursts outward off each one it quickened.
			var kr := clampf(_rang / 0.6, 0.0, 1.0)
			for wr in _tolled:
				var e = wr.get_ref()
				if e != null and is_instance_valid(e) and e.alive:
					_tb.ring(e.center(), lerpf(16.0, 52.0, kr), 3.5 * (1.0 - kr) + 0.5, Color(BELL, 0.9 * (1.0 - kr)), 20)
	if rule == "lamplit":
		# The set ledge cells' warm glint (it flickers with a guttering lantern).
		for cell in _lamp_cells:
			var top := Vector2(cell.x * TILE, cell.y * TILE)
			if not v.has_point(top):
				continue
			var l := _lamp_of(cell)
			if l.is_empty() or str((world.crumbles.get(cell, {}) as Dictionary).get("state", "idle")) == "fallen":
				continue
			var fl := 1.0
			if float(l.get("t", 99.0)) < 3.0:
				fl = 0.35 + 0.65 * absf(sin(_t * 9.0 + sin(_t * 23.0) * 2.0))
			ci.draw_rect(Rect2(top, Vector2(TILE, 3)), Color(WARM, 0.7 * fl))
	_tb.flush(ci)
