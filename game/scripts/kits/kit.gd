extends RefCounted
## A calling's kit: its basic attack (when not the plain swing), its Special,
## its resource, its quirk, and how it looks. The World calls these hooks;
## every one has a do-nothing default here. Signatures are frozen.
##
## The World calls, each physics tick (while playing): step(dt, pad) before
## the player moves; special_pressed/held/released from the pad's
## "special" edges; draw(glow) and lights() each frame. The player calls
## basic() on an attack press, air_jump() on a jump press in midair with no
## double jump left, filter_damage() and on_snuffed() inside take_damage.
##
## pad keys: left right down jump jump_pressed attack attack_pressed
##           special special_pressed special_released flask_pressed

const Classes := preload("res://scripts/classes.gd")
const Combat := preload("res://scripts/combat.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")   # new drawing goes through it (contract §1)

var player: Node2D
var world: Node
var cls := ""
var special_hold := 0.0          # seconds the Special has been held


func setup(p: Node2D, w: Node) -> void:
	player = p
	world = w


func stats() -> Dictionary:
	return player.stats if player != null else {}


func rank(id: String) -> int:
	## A node's rank; the root node also counts the gear's "+1 rank" rolls.
	var r := int(stats().get("ranks", {}).get(id, 0))
	var n := Classes.find_node(cls, id)
	if not n.is_empty() and n["branch"] == -1:
		r += int(stats().get("root_rank", 0))
	return r


func per(id: String, table: Array, fallback = 0.0):
	## The value for this node's current rank from its per-rank table. A root
	## lifted past its 5 ranks by "of the Keeper" carries the table's last
	## step on (Classes.at_rank), so the gear's +1 is never a dead roll.
	var r := rank(id)
	if r <= 0:
		return fallback
	if r > table.size() and int(Classes.find_node(cls, id).get("branch", 0)) != -1:
		r = table.size()   # only the root goes past its ranks (gear's +1); the rest stop at their max
	return Classes.at_rank(table, r)


func step(_dt: float, _pad: Dictionary) -> void:
	pass


func special_pressed() -> void:
	pass


func special_held(_dt: float) -> void:
	pass


func special_released(_held: float) -> void:
	pass


func basic() -> bool:
	## True when the kit made its own attack (so no default swing).
	return false


func melee_coef() -> float:
	## Damage multiple of the swing now landing (a finisher can raise it).
	return 1.0


func air_jump() -> bool:
	## A quirk's extra jump in midair; true if one was used.
	return false


func filter_damage(amount: float, _h: Dictionary) -> float:
	## Guards and wards: return what gets through (0 blocks it).
	return amount


func on_hit_landed(_e: Node2D, _res: Dictionary) -> void:
	pass


func on_kill(_e: Node2D) -> void:
	pass


func on_hurt(_amount: float) -> void:
	pass


func on_snuffed() -> bool:
	## True to cheat death (the player stays alive).
	return false


func on_respawn() -> void:
	pass


func on_reset() -> void:
	## The player was put back somewhere (player.reset_at: out of a pit, lava
	## or water, or at a checkpoint): a move in flight (a dash, a drop) ends
	## there rather than going on from the new spot.
	pass


func on_level_start() -> void:
	pass


func draw(_glow: Node2D) -> void:
	pass


func lights() -> Array:
	## [{p: Vector2, r: float, s: float}] extra lights (flares, wisps...).
	return []


func button_state() -> Dictionary:
	## For the Special button: fill (resource 0..1), ready, grey, pips,
	## pips_max, ring (charge/hold 0..1), icon (art/ui/btn_special_<icon>.svg).
	var p := player
	if p == null:
		return {}
	return {"fill": p.res / maxf(p.res_max, 0.001), "ready": true, "grey": false, "pips": 0, "pips_max": 0,
			"ring": 0.0, "icon": cls}


func pose(_k: Dictionary) -> Dictionary:
	## Rig overrides for this frame. Keys (all optional): arm_f, arm_b,
	## weapon_rel, weapon_alpha, leg_f, leg_b, lean, cape, squash (Vector2),
	## offhand_rot, alpha. _k carries {t, run, grounded, vy, attack_time}.
	return {}


func regen(dt: float) -> void:
	## The usual resource refill, per second from stats.
	var p := player
	p.res = minf(p.res + float(stats().get("res_regen", 0.0)) * dt, p.res_max)


func spend(n: float) -> bool:
	if player.res < n:
		return false
	player.res -= n
	return true


# ---------------------------------------------------------------- additions (W1)
# Optional hooks and shared helpers for the five kits; nothing above changed.

var hitting := ""                # what the kit is dealing right now ("dot", "skill"...); "" = the World's own
var _dots: Array = []            # {e, amount, every, t, left, tag}
var _pulses: Array = []          # {h, every, t}: player hazards that hit again every so often
var _sounds := {}                # the sound names the audio knows (filled on first use)


func attack_box(r: Rect2) -> Rect2:
	## The melee box for the swing now live, from the player's usual one (a
	## finisher reaches further, a spade scoops low). Default: unchanged.
	return r


func frontal(from_x: float) -> bool:
	## A blow from the side he faces (a hair behind the middle still counts).
	return (from_x - player.position.x) * float(player.facing) >= -3.0


func is_enemy(o) -> bool:
	return o != null and is_instance_valid(o) and world != null and world.enemies.has(o)


func is_boss(e) -> bool:
	return world != null and e != null and e == world.boss


func basic_flat(coef: float) -> float:
	## A basic-attack multiple as a flat amount (damage over time: no roll, no crit).
	var s := stats()
	return maxf(1.0, float(s.get("basic", 10.0)) * coef * (1.0 + float(s.get("dmg_pct", 0.0))))


func deal_as(what: String, e: Node2D, coef: float, opts := {}) -> Dictionary:
	## world.deal with `hitting` set, so on_hit_landed can tell a kit's own
	## blows (a rush, a burst, a burn tick) from the World's swing and shots.
	## The kit's own bonus against this foe (bonus_vs: Candlemold, Barrow
	## Bind) rides on it at one rate, spec §2.3's "kit extra_pct": added to
	## a rolled blow's damage %, and a flat one (a burn, basic_flat: basic x
	## coef x (1 + dmg_pct)) paid as if it had been rolled with it.
	var b := bonus_vs(e)
	if b != 0.0:
		opts = opts.duplicate()
		if opts.has("flat"):
			opts["flat"] = float(opts["flat"]) * flat_bonus(b)
		else:
			opts["extra_pct"] = float(opts.get("extra_pct", 0.0)) + b
	var before := hitting
	hitting = what
	var res: Dictionary = world.deal(e, coef, opts)
	hitting = before
	return res


# ---------------------------------------------------------------- v3 additions (KT)
# Optional hooks, all no-ops here (a kit without them plays as in v2).

var _swing_opts := [-1, -1]      # [foe id, attack_id] melee_opts was last asked for (the World wired it)


func bonus_vs(_e) -> float:
	## The kit's own extra damage share against this foe (a Mastery node's
	## "+v% damage from you" on waxed or rooted foes). 0 = none.
	return 0.0


func flat_bonus(b: float) -> float:
	## A flat amount's multiple for an extra_pct of b: what b adds to the
	## damage % a flat amount (basic x coef x (1 + dmg_pct)) already holds.
	return 1.0 + b / maxf(1.0 + float(stats().get("dmg_pct", 0.0)), 0.01)


func holding_special() -> bool:
	## A Special held and still playing (a raised guard, a charging flare, a
	## Knell that may yet Toll): player.gd catches no vine meanwhile, as when
	## down is held (spec §2.4: a Special lets go and plays as in the air).
	return false


func melee_opts(e) -> Dictionary:
	## Extra opts for the World's swing about to land on e, merged into its
	## deal opts (force_crit, extra_pct): KT's request to W0. A kit that
	## answers notes that it was asked, so its fallback (a top-up in
	## on_hit_landed, while the World doesn't ask) never pays twice.
	if e != null and is_instance_valid(e) and player != null:
		_swing_opts = [e.get_instance_id(), int(player.attack_id)]
	return _melee_opts(e)


func _melee_opts(_e) -> Dictionary:
	return {}


func swing_opts_applied(e) -> bool:
	## Did the World ask melee_opts for this foe and this swing (so its opts
	## are already in the blow that just landed)?
	return e != null and is_instance_valid(e) and player != null \
			and int(_swing_opts[0]) == e.get_instance_id() and int(_swing_opts[1]) == int(player.attack_id)


func top_up(e: Node2D, res: Dictionary, share: float, crit := false) -> void:
	## The fallback for a swing whose opts the World didn't apply: the
	## missing share of the blow that just landed, as a flat follow-up (no
	## hitstop, no second bonus). Nothing on a foe it already felled.
	if share <= 0.0 or e == null or not is_instance_valid(e) or not e.alive or world == null:
		return
	var amt := float(res.get("amount", 0.0)) * share
	if amt < 0.5:
		return
	# Dealt as the swing's own kind of number (a crit's top-up as a crit),
	# so the two fold into one (floaters merge a key and kind within 0.2 s).
	var was_crit := bool(res.get("crit", false))
	var before := hitting
	hitting = "top_up"
	var got: Dictionary = world.deal(e, 1.0, {"how": "slash", "flat": amt, "no_hitstop": true, "force_crit": was_crit})
	hitting = before
	if crit and not was_crit and bool(got.get("hit", false)):
		_promote_crit(e, float(res.get("amount", 0.0)) + float(got.get("amount", 0.0)))


func _promote_crit(e: Node2D, total: float) -> void:
	## The swing and its top-up, just folded into one plain number, shown
	## as the crit they add up to (Judgment's fallback: one number with the
	## crit's star, not a plain one under a smaller crit).
	var fl = world.get("floaters")
	var items = fl.get("items") if fl != null else null
	var key := e.get_instance_id()
	var found := false
	if items is Array:
		for it in items:
			if it is Dictionary and it.get("key") == key and it.get("kind") == "hit" and float(it.get("t", 1.0)) < 0.05:
				it["kind"] = "crit"
				found = true
	if not found and fl != null and fl.has_method("add"):
		# (Plain numbers hidden, as the "crits" setting does: the crit shows alone.)
		fl.add(e.center() + Vector2(0, -e.size.y * 0.4), total, "crit", key)
	sfx("crit", 1.0, "")


func decoy(_kind: String, _at: Vector2) -> Dictionary:
	## A monster that would take something of his (a Stillmaw's Gulp) asks
	## first: the kit may give it something else instead and return
	## {p: where it was, kind}, or {} to let the move go on (the Sexton's
	## wisps are gulped before he is).
	return {}


func on_vine() -> bool:
	## On a vine now (player.gd's climb state): both hands are on it.
	return player != null and player.get("climbing") == true


func shot_bonus(s: Dictionary, dt: float, base := 0.0) -> void:
	## A shot in flight: its extra_pct for the foe it's about to meet
	## (shot_target), so bonus_vs rides on the World's shot deal.
	if world == null:
		return
	var e: Node2D = shot_target(s, dt)
	s["extra_pct"] = base + (bonus_vs(e) if e != null else 0.0)


func shot_target(s: Dictionary, dt: float) -> Node2D:
	## The foe a shot meets this tick, by the World's own test (the first
	## live foe it hasn't hit whose rect grown by the shot's radius holds
	## its next point), so a boss's big body counts from its edge, not its
	## middle. The kit steps before the foes do: a hair of slack for their
	## own step, and the exact test wins over the slack.
	if world == null or not s.has("pos"):
		return null
	var v: Vector2 = s.get("vel", Vector2.ZERO)
	v.y += float(s.get("g", 0.0)) * dt
	var p: Vector2 = s["pos"]
	var next: Vector2 = p + v * dt
	var rad := float(s.get("radius", 6.0))
	var hit_ids: Array = s.get("hit_ids", [])
	var near: Node2D = null
	for e in world.enemies:
		if not e.alive or not e.active or hit_ids.has(e.get_instance_id()):
			continue
		var r: Rect2 = e.rect()
		if r.grow(rad).has_point(next):
			return e
		if near == null and (r.grow(rad + 4.0).has_point(next) or r.grow(rad + 4.0).has_point(p)):
			near = e
	return near


func melee_hit(e: Node2D, res: Dictionary) -> bool:
	## For on_hit_landed: was this the player's own swing (not a shot, a wave
	## or one of the kit's skills)? Uses res.how when the World passes it.
	if hitting != "":
		return false
	if res.has("how"):
		return res["how"] == "slash"
	return player.attack_time >= 0.0 and player.attack_time <= player.ATTACK_ACTIVE + 0.02 \
			and int(e.get("last_swing")) == player.attack_id


func add_dot(e: Node2D, coef: float, seconds: float, tag := "burn", every := 0.5) -> void:
	## A burn or smolder: coef x basic every `every` s for `seconds`, never a
	## crit and never hitstop. The same tag on the same foe refreshes it.
	if e == null or not is_instance_valid(e) or not e.alive:
		return
	if e.has_method("apply_status"):
		e.apply_status("burn", seconds)
	for d in _dots:
		if d["e"] == e and d["tag"] == tag:
			d["left"] = maxf(d["left"], seconds)
			d["amount"] = maxf(d["amount"], basic_flat(coef))
			return
	_dots.append({"e": e, "amount": basic_flat(coef), "every": every, "t": every, "left": seconds, "tag": tag})


func burning(e: Node2D) -> bool:
	for d in _dots:
		if d["e"] == e and d["left"] > 0.0:
			return true
	return false


func tick_dots(dt: float) -> void:
	for d in _dots:
		d["left"] -= dt
		d["t"] -= dt
		var e = d["e"]
		if d["t"] <= 0.0 and is_instance_valid(e) and e.alive:
			d["t"] += d["every"]
			deal_as("dot", e, 1.0, {"how": "burn", "flat": d["amount"], "no_hitstop": true})
	_dots = _dots.filter(func(d): return d["left"] > 0.0 and is_instance_valid(d["e"]) and d["e"].alive)


func pulse(h: Dictionary, every := 0.5) -> Dictionary:
	## A player hazard (a fire floor) that hits each foe again every `every` s.
	_pulses.append({"h": h, "every": every, "t": every})
	return h


func tick_pulses(dt: float) -> void:
	for p in _pulses:
		p["t"] -= dt
		if p["t"] <= 0.0:
			p["t"] += p["every"]
			(p["h"]["hit_ids"] as Array).clear()
	_pulses = _pulses.filter(func(p): return p["h"]["life"] > 0.0)


func enemies_near(p: Vector2, r: float) -> Array:
	## Live foes whose body comes within r of p.
	if world == null:
		return []
	var out := []
	for e in world.enemies_in(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)):
		var er: Rect2 = e.rect()
		var q := Vector2(clampf(p.x, er.position.x, er.end.x), clampf(p.y, er.position.y, er.end.y))
		if q.distance_to(p) <= r:
			out.append(e)
	return out


func soft_aim(origin: Vector2, dir: Vector2, reach: float, cone_deg: float) -> Vector2:
	## A ranged basic's aim: at the nearest foe inside a forward cone, else straight on.
	if world == null:
		return dir
	var cone := deg_to_rad(cone_deg)
	var e: Node2D = world.nearest_enemy(origin, reach, func(o): return absf(dir.angle_to(o.center() - origin)) <= cone)
	if e == null:
		return dir
	return (e.center() - origin).normalized()


func floor_below(p: Vector2, max_drop := 64.0) -> float:
	## The y of the first floor (stone or a ledge's top) under p within max_drop, else INF.
	if world == null:
		return INF
	var lv = world.level
	var tx := floori(p.x / 32.0)
	var ty := floori(p.y / 32.0)
	while ty * 32.0 <= p.y + max_drop and ty < int(lv.height) + 2:
		var t: int = lv.tile(tx, ty)
		if (lv.is_solid(t) or lv.is_ledge(t)) and ty * 32.0 >= p.y - 1.0:
			return ty * 32.0
		ty += 1
	return INF


func break_ahead(dir: int, dist: float) -> void:
	## Breaks the cracked bricks the body is about to run into (a rush, a stampede).
	if world == null:
		return
	var r: Rect2 = player.rect()
	var x := r.end.x + dist if dir > 0 else r.position.x - dist
	var tx := floori(x / 32.0)
	for ty in range(floori(r.position.y / 32.0), floori((r.end.y - 0.5) / 32.0) + 1):
		if world.level.is_breakable(world.level.tile(tx, ty)):
			world.break_tile(Vector2i(tx, ty))


func sfx(name: String, pitch := 1.0, fallback := "") -> Object:
	## A sound by name; until the audio has that one, the fallback (or nothing).
	## Returns the voice playing it (an AudioStreamPlayer), or null: keep it to
	## let go of a held sound with release_sfx().
	var s := _sfx_node()
	if s == null:
		return null
	if _sounds.is_empty():
		for n in s.get_script().get_script_constant_map().get("NAMES", []):
			_sounds[n] = true
	if _sounds.has(name):
		return s.play(name, pitch)
	elif fallback != "" and _sounds.has(fallback):
		return s.play(fallback, pitch)
	return null


func release_sfx(voice: Object) -> void:
	## Lets go of a held sound sfx() returned (a charge hum): Sfx.release
	## fades it out. (Audio without release() has no held sounds to let go.)
	if voice == null or not is_instance_valid(voice):
		return
	var s := _sfx_node()
	if s != null and s.has_method("release"):
		s.release(voice)


func _sfx_node() -> Node:
	if world == null or not world.has_method("_has_sfx") or not world._has_sfx():
		return null
	return world.get_node_or_null("/root/Sfx")


func haptic(ms: int) -> void:
	if world != null and world.has_method("_haptic"):
		world._haptic(ms)


func burst(p: Vector2, n: int, col: Color, speed := 140.0, life := 0.5, g := 300.0, size := 2.5, up := 0.0) -> void:
	## Bright particles on the glow layer.
	if world != null and world.glow != null:
		world.glow.burst(p, n, col, speed, life, g, size, up)


func say(p: Vector2, text: String) -> void:
	## A word over the action ("Perfect!", "Backstab!") in the numbers' style.
	if world != null:
		world.floaters.add(p, 0.0, "text", 0, text)


func shake(amount: float) -> void:
	if world != null:
		world.shake = maxf(world.shake, amount)


func teardrop(ci: CanvasItem, base: Vector2, r: float, h: float, sway: float, col: Color) -> void:
	## A flame-shaped drop standing on base (wisps, beacons), in one polygon.
	## A Sexton wisp is born at size 0 and grows in 0.25 s while its sway
	## stays full: the tip swung wider than the drop crosses its own sides,
	## and a sub-pixel drop's points are too close for the engine: either way
	## it can't triangulate ("triangulation failed"). So nothing under half a
	## pixel, and the sway at most half the drop's width (full-size drops
	## sway less than that, and look as they did).
	if r < 0.5 or h < 0.5:
		return
	sway = clampf(sway, -r * 0.5, r * 0.5)
	var pts := PackedVector2Array()
	for k in 11:
		var a := PI * k / 10.0
		pts.append(base + Vector2(r * cos(a), -r + r * sin(a)))
	var tip := base + Vector2(sway, -h)
	var lft := base + Vector2(-r, -r)
	var cl := base + Vector2(-r * 0.95, -h * 0.55)
	for k in range(1, 7):
		var s := k / 6.0
		pts.append(lft.lerp(cl, s).lerp(cl.lerp(tip, s), s))
	var rgt := base + Vector2(r, -r)
	var cr := base + Vector2(r * 0.95, -h * 0.55)
	for k in range(1, 6):
		var s := k / 6.0
		pts.append(tip.lerp(cr, s).lerp(cr.lerp(rgt, s), s))
	ci.draw_colored_polygon(pts, col)
