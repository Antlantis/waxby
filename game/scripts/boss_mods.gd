extends RefCounted
## The boss rush's boss side, for every boss (spec §5.6 and §7.3, contract
## §6.4): the rush life, and the two boss-side Tweaks of the Waxworks.
##
##   BossMods.configure(boss, opts)  the shared part of a boss's configure(opts)
##       ({rush, mods, hp_mult, area, echo}, called before _ready): sets the
##       boss's `rush` (when it has one), multiplies its life by its own rush
##       normalisation RUSH_HP[boss_id] (only with rush) times the mode's
##       hp_mult (Thicker Wax x1.5, the Gauntlet x0.85, a Descent echo x0.8),
##       and applies the mods. opts is kept as the boss's meta "rush_opts".
##   BossMods.apply(boss, mods)      "warded" and "echoing" on any boss; the
##       runtime lives on the boss as meta "boss_mods" (null with no mods)
##   BossMods.of(boss)               that runtime, or null
##
## Warded Wax (the Warded Omen's rules, elites.gd): 3 candle motes orbit the
## boss; each takes one blow, even inside a window, and regrows after
## MOTE_REGROW s (5 s: the Tweak's, a monster's Omen regrows in 4); a stomp
## breaks all that are up and lands. Echoing Wax (the Echoing Omen's): each
## attack strikes again ECHO_DELAY (0.8 s) later at the same place as a pale
## echo for ECHO_SHARE (60%) of its damage. A moving attack (a floor wave, a
## rolling bell, a lunge) is recorded tick by tick and its echo retraces the
## same path 0.8 s behind; a strike's box is outlined from the strike until
## its echo fires, and a clock-hand ring ticks round the boss's feet. A
## falling one (a hazard with a "shadow": rubble, a drip) starts over the
## view, so its echo is marked on the floor where it will land instead: a
## dark spot under a pale ring closing in, from the moment the first one
## starts to fall until its echo lands. marks() is what's drawn (the tests
## read it headless).
##
## A boss wires the runtime in at five places (the v2 bosses do; BA's and
## BB's bosses call the same, or keep "source": self in their hazards and
## the runtime watches those by itself):
##   hit(h):      if m and m.blocks(h): return false   (after its own "can a
##                blow land at all" checks: asleep, hollow, shock and bump)
##   an attack:   m.strike(rect, dmg[, life]) for a box that strikes at once;
##                m.watch(hazard) for a world hazard it lays; m.follow(key,
##                rect, dmg[, live]) every tick of a moving strike it moves
##                itself, then m.end(key); m.shot(d) for a shot it fires
##   step(dt, player): m.step(dt, player)   (also while stunned or dying)
##   draw_glow(glow):  m.draw_glow(glow)
##   lights():         out + m.lights()
## and m.reset() in reset_fight(), m.clear() when it dies.

const TriBatch := preload("res://scripts/tri_batch.gd")
const LevelData := preload("res://scripts/level_data.gd")
const META := "boss_mods"
const OPTS_META := "rush_opts"
const MODS := ["warded", "echoing"]
# Each boss's rush normalisation: its life in the Waxworks and in Descent
# boss depths, so a fight lasts 60-80 s for the reference hero at the rush
# area (spec §5.6), at every level a rematch is sampled at. Tollgrave and
# the Snuffer come from the rush sim in tests/test_rush_bosses.gd
# (WAXBY_RUSH_SIM=1 prints the derivation: the life with the most room
# inside 60-80 s at the worst level sampled); the
# four new bosses keep spec §5.6's start values until the sim is run on them
# (mode.gd's RUSH_HP is the modes' stand-in for a boss with no configure()),
# but the Saint's and the Hush's, measured by the rev5 review on their real
# rush arenas (the boss's bot_pad, life topped up): the Saint at 0.85 took
# 89.7 s at L26 (0.70: about 74 s), the Hush at 0.6 53.8 s at L30 before its
# BASE_HP went 680 -> 800 (about 63 s now). Provisional, for the rush sim.
# The Tinker's (v1.0.1) comes from test_rush_bosses' Tinker rush: the
# reference knight fights each rematch with real travel (the sim's fighter
# can't ring his bells), 60-80 s at every level sampled; it is his RUSH_K.
const RUSH_HP := {"tollgrave": 2.0, "snuffer": 1.8, "rootmother": 0.9, "tinker": 1.42, "saint": 0.70, "hush": 0.6}
# The Omens' numbers (elites.gd), the Tweak's regrow.
const MOTE_COUNT := 3
const MOTE_REGROW := 5.0
const MOTE_R := 30.0              # each mote's light
const ECHO_DELAY := 0.8
const ECHO_SHARE := 0.6
const ECHO_COL := Color(0.85, 0.92, 1.0)
const MOTE_WAX := Color("efe6d2")

var boss: Node2D = null
var mods: Array = []
var motes: Array = []             # Warded: seconds until each mote is back (0 = up)
var spin := 0.0
var flashes: Array = []           # {p, t}: a mote just broken
var echoes: Array = []            # Echoing: every strike being recorded or replayed
var clock := 0.0                  # the runtime's own clock (it steps with the boss)
var echo_marks := 0               # the waiting echoes the last draw outlined (tests)
var echo_hits := 0                # echoes that hurt the hero (tests)
var blocked := 0                  # blows the motes took (tests)
var _tb := TriBatch.new()


# ---------------------------------------------------------------- the static side

static func rush_hp(boss_id: String) -> float:
	return float(RUSH_HP.get(boss_id, 1.0))


static func life_mult(boss_id: String, opts: Dictionary) -> float:
	## What configure() multiplies a boss's life by: its rush normalisation
	## (with rush) times the mode's own share.
	var k := float(opts.get("hp_mult", 1.0))
	if bool(opts.get("rush", false)):
		k *= rush_hp(boss_id)
	return k


static func configure(b: Node2D, opts: Dictionary) -> void:
	b.set_meta(OPTS_META, opts.duplicate(true))
	var rush := bool(opts.get("rush", false))
	if "rush" in b:
		b.set("rush", rush)
	var k := life_mult(str(b.get("boss_id")), opts)
	if k > 0.0 and not is_equal_approx(k, 1.0):
		b.max_hp = float(b.max_hp) * k
		b.hp = b.max_hp
	var m = opts.get("mods", [])
	apply(b, m if m is Array else [])


static func apply(b: Node2D, want: Array) -> RefCounted:
	## Warded and Echoing Wax on this boss (unknown ids are ignored). Returns
	## the runtime (also the boss's meta "boss_mods"), or null with none.
	var got: Array = []
	for x in want:
		var id := str(x).to_lower()
		if MODS.has(id) and not got.has(id):
			got.append(id)
	if got.is_empty():
		if b.has_meta(META):
			b.remove_meta(META)
		return null
	var rt = (load("res://scripts/boss_mods.gd") as GDScript).new()
	rt.boss = b
	rt.mods = got
	rt.reset()
	b.set_meta(META, rt)
	return rt


static func of(b: Object) -> RefCounted:
	if b != null and is_instance_valid(b) and b.has_meta(META):
		return b.get_meta(META)
	return null


static func opts_of(b: Object) -> Dictionary:
	if b != null and is_instance_valid(b) and b.has_meta(OPTS_META):
		return b.get_meta(OPTS_META)
	return {}


# ---------------------------------------------------------------- the runtime

func has(id: String) -> bool:
	return mods.has(id)


func reset() -> void:
	## A retry: the motes up, no echo waiting.
	motes = []
	if has("warded"):
		for i in MOTE_COUNT:
			motes.append(0.0)
	flashes.clear()
	echoes.clear()


func clear() -> void:
	## The boss fell: what it struck goes with it (the World clears its hazards).
	echoes.clear()
	flashes.clear()


func _world() -> Object:
	if boss == null or not is_instance_valid(boss):
		return null
	return boss.get("world")


func step(dt: float, player: Node2D) -> void:
	clock += dt
	spin += dt * 2.4
	for i in motes.size():
		motes[i] = maxf(float(motes[i]) - dt, 0.0)
	for f in flashes:
		f["t"] += dt
	flashes = flashes.filter(func(f): return f["t"] < 0.35)
	if not has("echoing"):
		return
	var w = _world()
	if w == null:
		return
	if bool(boss.get("alive")):
		_watch_sources(w)
	for e in echoes:
		if bool(e["open"]):
			_record(e, w)
		_replay(e, w, player)
	echoes = echoes.filter(func(e): return not bool(e["done"]))


# ---------------------------------------------------------------- Warded Wax

func motes_up() -> int:
	var n := 0
	for m in motes:
		if float(m) <= 0.0:
			n += 1
	return n


func mote_pos(i: int) -> Vector2:
	var c: Vector2 = boss.center()
	var a := spin + TAU * i / float(MOTE_COUNT)
	var r := float(boss.size.x) * 0.5 + 14.0
	return c + Vector2(cos(a) * r, sin(a) * r * 0.55 - 4.0)


func blocks(h: Dictionary) -> bool:
	## A mote takes the blow (true: it doesn't land). A stomp breaks every mote
	## that's up and still lands (false).
	if not has("warded") or motes_up() == 0:
		return false
	var how := str(h.get("how", "slash"))
	if how == "shock" or how == "bump":
		return false
	var w = _world()
	if how == "stomp":
		for i in motes.size():
			if float(motes[i]) <= 0.0:
				flashes.append({"p": mote_pos(i), "t": 0.0})
			motes[i] = MOTE_REGROW
		_sfx(w, "clang", 1.3)
		return false
	var from_x := float(h.get("from_x", boss.position.x))
	var best := -1
	var bd := INF
	for i in motes.size():
		if float(motes[i]) > 0.0:
			continue
		var d: float = absf(mote_pos(i).x - from_x)
		if d < bd:
			bd = d
			best = i
	motes[best] = MOTE_REGROW
	flashes.append({"p": mote_pos(best), "t": 0.0})
	blocked += 1
	boss.set("flash", 0.4)
	_sfx(w, "clang", 1.4)
	if w != null and how != "slash":
		w.number(boss.center() + Vector2(0, -float(boss.size.y) * 0.5), 0.0, "blocked", 0)
	return true


# ---------------------------------------------------------------- Echoing Wax

func _new_echo(dmg: float, key := "") -> Dictionary:
	var e := {"start": clock, "samples": [], "open": true, "dmg": dmg * ECHO_SHARE, "hit": false,
			"fired": false, "done": false, "key": key, "src": null, "shot": {}}
	echoes.append(e)
	return e


func strike(r: Rect2, dmg: float, life := 0.15) -> void:
	## A box that strikes at once (a slam's zone): the same box again 0.8 s later.
	if not has("echoing"):
		return
	var e := _new_echo(dmg)
	e["samples"] = [{"t": 0.0, "r": r, "live": true}, {"t": maxf(life, 0.05), "r": r, "live": true}]
	e["open"] = false


func watch(h: Dictionary) -> void:
	## A world hazard it laid (a wave, a skull, rubble, a smoke tide, a drip):
	## recorded every tick while it lasts, and retraced 0.8 s behind.
	if not has("echoing") or h.is_empty() or h.get("echo", false):
		return
	h["_bm"] = true
	var e := _new_echo(float(h.get("dmg", 0.0)))
	e["src"] = h
	if h.get("shadow", false):
		e["shadow"] = true   # a falling one: its echo is marked on the floor (marks())


func follow(key: String, r: Rect2, dmg: float, live := true) -> void:
	## One tick of a moving strike the boss moves itself (a rolling bell, a
	## lunge): call it every tick, then end(key).
	if not has("echoing"):
		return
	var e: Dictionary = {}
	for x in echoes:
		if str(x["key"]) == key and bool(x["open"]):
			e = x
	if e.is_empty():
		e = _new_echo(dmg, key)
	(e["samples"] as Array).append({"t": clock - float(e["start"]), "r": r, "live": live})


func end(key: String) -> void:
	for x in echoes:
		if str(x["key"]) == key:
			x["open"] = false


func shot(d: Dictionary) -> void:
	## A shot it fired: fired again from the same place 0.8 s later.
	if not has("echoing") or not d.has("pos") or not d.has("vel"):
		return
	var e := _new_echo(float(d.get("dmg", 0.0)))
	var sh := d.duplicate(true)
	sh["hit_ids"] = []
	sh["t"] = 0.0
	e["shot"] = sh
	e["open"] = false
	e["samples"] = [{"t": 0.0, "r": Rect2(sh["pos"] - Vector2(4, 4), Vector2(8, 8)), "live": false}]


func _watch_sources(w: Object) -> void:
	## A hazard that names this boss as its source is watched by itself (BA's
	## and BB's bosses may lay theirs so, with no watch() call).
	for h in w.hazards:
		if h.has("_bm") or h.get("echo", false) or str(h.get("owner", "enemy")) != "enemy":
			continue
		if h.get("source") == boss:
			watch(h)
		else:
			h["_bm"] = false


func _record(e: Dictionary, w: Object) -> void:
	var h = e["src"]
	if not (h is Dictionary):
		return   # a follow()ed strike records itself
	var live_in := false
	for x in w.hazards:
		if is_same(x, h):
			live_in = true
			break
	if not live_in or float(h.get("life", 0.0)) <= 0.0:
		e["open"] = false
		return
	var s := {"t": clock - float(e["start"]), "r": h.get("rect", Rect2()), "live": float(h.get("delay", 0.0)) <= 0.0}
	if str(h.get("kind", "")) == "beam":
		s["seg"] = (h.get("seg", []) as Array).duplicate()
		s["w"] = float(h.get("width", 8.0))
	(e["samples"] as Array).append(s)


func _sample_at(e: Dictionary, t: float) -> Dictionary:
	## The recorded sample at t s after the strike began ({} before it).
	var out := {}
	for s in e["samples"]:
		if float(s["t"]) <= t + 1e-6:
			out = s
		else:
			break
	return out


func _replay(e: Dictionary, w: Object, player: Node2D) -> void:
	var el := clock - float(e["start"]) - ECHO_DELAY
	if el < 0.0:
		return
	var samples: Array = e["samples"]
	if not bool(e["fired"]):
		e["fired"] = true
		_sfx(w, "omen_tick")   # (a v3 sound: at pitch 1.0, its own take)
		if not (e["shot"] as Dictionary).is_empty() and w.has_method("spawn_shot"):
			var sh: Dictionary = e["shot"]
			sh["dmg"] = float(e["dmg"])
			sh["echo"] = true
			w.spawn_shot(sh)
	var last_t := float(samples[samples.size() - 1]["t"]) if not samples.is_empty() else 0.0
	if not bool(e["open"]) and el > last_t + 0.05:
		e["done"] = true
		return
	if bool(e["hit"]) or player == null or not player.alive:
		return
	var s := _sample_at(e, el)
	if s.is_empty() or not bool(s["live"]):
		return
	var pr: Rect2 = player.rect()
	var touch := false
	var at_x := 0.0
	if s.has("seg") and (s["seg"] as Array).size() == 2:
		var seg: Array = s["seg"]
		touch = w.seg_hits_rect(seg[0], seg[1], float(s["w"]), pr.grow(-3.0))
		at_x = (seg[0] as Vector2).x
	else:
		var r: Rect2 = s["r"]
		touch = r.grow(-3.0).intersects(pr)
		at_x = r.get_center().x
	if touch and w.hurt_player(float(e["dmg"]), at_x, "hit", boss, {"move": "echo"}):
		e["hit"] = true
		echo_hits += 1


func echo_rect(e: Dictionary) -> Rect2:
	## Where an echo is now (while it retraces), or where it will first strike
	## (while it waits); an empty rect when neither.
	var el := clock - float(e["start"]) - ECHO_DELAY
	if el < 0.0:
		for s in e["samples"]:
			if bool(s["live"]):
				return s["r"]
		return Rect2()
	var s := _sample_at(e, el)
	return s["r"] if not s.is_empty() else Rect2()


func marks() -> Array:
	## What draw_glow draws for the echoes, one entry each: {wait, k, live}
	## and either "r" (a box: where a waiting echo will first strike, or where
	## a retracing one is), "seg" (a beam's line) or "floor" + "half" (where a
	## falling one's echo will land). wait: it hasn't struck yet (a waiting
	## mark); k: 0..1 as it nears.
	var out := []
	if not has("echoing"):
		return out
	for e in echoes:
		var el := clock - float(e["start"]) - ECHO_DELAY
		var k := 1.0 - clampf(-el / ECHO_DELAY, 0.0, 1.0) if el < 0.0 else 1.0
		var sg := _sample_at(e, maxf(el, 0.0))
		if sg.has("seg") and (sg["seg"] as Array).size() == 2:
			out.append({"seg": sg["seg"], "wait": el < 0.0, "k": k, "live": el >= 0.0})
			continue
		if bool(e.get("shadow", false)):
			var land := _landing(e)
			if not land.is_empty():
				# Until its echo lands: marked on the floor under it.
				var left: float = float(land["t"]) - el
				if left > 0.0:
					var kf := 1.0 - clampf(left / (float(land["t"]) + ECHO_DELAY), 0.0, 1.0)
					out.append({"floor": land["p"], "half": land["half"], "wait": true, "k": kf, "live": false})
			if el < 0.0:
				continue   # (its waiting box is over the view: the floor mark stands for it)
		var er := echo_rect(e)
		if er.size.x <= 0.0:
			continue
		var live := false
		if el >= 0.0:
			var s := _sample_at(e, el)
			live = not s.is_empty() and bool(s["live"])
		out.append({"r": er, "wait": el < 0.0, "k": k, "live": live})
	return out


func _landing(e: Dictionary) -> Dictionary:
	## A falling strike's landing: {p (on the floor), half, t (s after the
	## strike it lands; its echo 0.8 s later)}, once the first one has begun
	## to fall; {} before. While it falls, t is how far it has come so far.
	var samples: Array = e["samples"]
	var last := {}
	for s in samples:
		if bool(s["live"]):
			last = s
	if last.is_empty():
		return {}
	var r: Rect2 = last["r"]
	var x := r.get_center().x
	if not e.has("fy") or absf(float(e.get("fx", x)) - x) > 4.0:
		e["fx"] = x
		e["fy"] = _floor_below(x, r.position.y)
	return {"p": Vector2(x, float(e["fy"]) - 2.0), "half": maxf(r.size.x * 0.5, 8.0), "t": float(last["t"])}


func _floor_below(x: float, y0: float) -> float:
	## The top of the floor a falling thing lands on under x: the first solid
	## tile below y0 (out of a ceiling first, when y0 is in one; from the view's
	## top when y0 is over it).
	var lv = boss.get("level") if boss != null and is_instance_valid(boss) else null
	if lv == null:
		return y0
	var w = _world()
	if w != null and w.has_method("view_rect"):
		y0 = maxf(y0, (w.view_rect() as Rect2).position.y)
	var tile := float(LevelData.TILE)
	var tx := floori(x / tile)
	var ty := floori(y0 / tile)
	var n := 0
	while n < 40 and LevelData.is_solid(lv.tile(tx, ty)):
		ty += 1
		n += 1
	while n < 80 and not LevelData.is_solid(lv.tile(tx, ty)):
		ty += 1
		n += 1
	return ty * tile


# ---------------------------------------------------------------- the look

func lights() -> Array:
	var out := []
	for i in motes.size():
		if float(motes[i]) <= 0.0:
			out.append({"p": mote_pos(i), "r": MOTE_R, "s": 0.7})
	return out


func draw_glow(glow: Node2D) -> void:
	## Above the dark: the motes (and a faint ember where one regrows), and
	## the echoes: each waiting echo's box outlined, brightening as it nears;
	## a retracing echo pale and filled; the clock-hand ring at its feet.
	var tb := _tb
	if has("warded") and bool(boss.get("alive")):
		for i in motes.size():
			var p := mote_pos(i)
			if float(motes[i]) > 0.0:
				var k := 1.0 - float(motes[i]) / MOTE_REGROW
				tb.circle(p, 1.5 + 2.0 * k, Color(0.9, 0.85, 0.7, 0.25 * k), 8)
				continue
			tb.circle(p, 7.0, Color(1.0, 0.8, 0.45, 0.16), 12)
			tb.circle(p + Vector2(0, 3), 2.6, MOTE_WAX, 8)
		for f in flashes:
			var k2: float = f["t"] / 0.35
			tb.ring(f["p"], 4.0 + k2 * 14.0, 2.0, Color(1.0, 0.9, 0.6, 1.0 - k2), 16)
	echo_marks = 0
	if has("echoing"):
		if bool(boss.get("alive")):
			var feet := Vector2(boss.position.x, boss.position.y)
			var rx := maxf(float(boss.size.x), 40.0) * 0.6 + 6.0
			var ring := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				ring.append(feet + Vector2(cos(a) * rx, sin(a) * rx * 0.3))
			tb.polyline(ring, 1.5, Color(ECHO_COL, 0.55), true)
			var ha := floorf(clock * 4.0) * TAU / 12.0 - PI * 0.5
			tb.line(feet, feet + Vector2(cos(ha) * rx * 0.9, sin(ha) * rx * 0.27), 2.0, Color(0.95, 0.97, 1.0, 0.85))
		for mk in marks():
			var k3: float = mk["k"]
			if bool(mk["wait"]):
				echo_marks += 1
			if mk.has("seg"):
				# A beam's echo: its line, dashed while it waits, pale as it strikes.
				_dash(tb, mk["seg"][0], mk["seg"][1], 2.0, Color(ECHO_COL, 0.3 + 0.55 * k3))
			elif mk.has("floor"):
				# A falling one's echo: where it will land, a dark spot swelling
				# under a pale ring that closes in on it (the World's shadow, cold).
				var at: Vector2 = mk["floor"]
				var half: float = mk["half"]
				tb.ellipse(at, half * (0.7 + 0.6 * k3), 3.0 + 1.5 * k3, Color(0.0, 0.0, 0.04, 0.40 + 0.3 * k3), 14)
				var rr := half * (2.8 - 1.6 * k3)
				var pts := PackedVector2Array()
				for i in 18:
					var a2 := TAU * i / 18.0
					pts.append(at + Vector2(cos(a2) * rr, sin(a2) * maxf(rr * 0.3, 3.0)))
				tb.polyline(pts, 2.5 + k3, Color(ECHO_COL, 0.65 + 0.35 * k3), true)
				tb.ellipse(at, half * 0.35, 1.6, Color(ECHO_COL, 0.45 + 0.5 * k3), 10)
				# A short dashed fall line over it: something comes down here.
				for j in 3:
					var y0 := at.y - 44.0 + j * 12.0
					tb.line(Vector2(at.x, y0), Vector2(at.x, y0 + 6.0), 2.0, Color(ECHO_COL, (0.30 + 0.45 * k3) * (0.5 + 0.25 * j)))
			elif bool(mk["wait"]):
				glow.draw_rect(mk["r"], Color(ECHO_COL, 0.06 + 0.12 * k3))
				glow.draw_rect(mk["r"], Color(ECHO_COL, 0.45 + 0.5 * k3), false, 2.0)
			else:
				var live := bool(mk["live"])
				glow.draw_rect(mk["r"], Color(ECHO_COL, 0.28 if live else 0.10))
				glow.draw_rect(mk["r"], Color(0.95, 0.97, 1.0, 0.75 if live else 0.3), false, 1.5)
	tb.flush(glow)
	if has("warded") and bool(boss.get("alive")) and glow.has_method("flame"):
		for i in motes.size():
			if float(motes[i]) <= 0.0:
				var p2 := mote_pos(i)
				glow.flame(p2 + Vector2(0, 2), 7.0, p2.x + i)


static func _dash(tb: RefCounted, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	## A dashed line (8 px on, 6 off), as the Omen draws a beam's echo.
	var len := a.distance_to(b)
	if len < 0.5:
		return
	var d := (b - a) / len
	var x := 0.0
	while x < len:
		tb.line(a + d * x, a + d * minf(x + 8.0, len), w, col)
		x += 14.0


func _sfx(w: Object, name: String, pitch := 1.0) -> void:
	if w != null and w.has_method("_sfx"):
		w._sfx(name, pitch)
