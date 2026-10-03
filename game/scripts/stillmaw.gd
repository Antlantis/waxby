extends "res://scripts/elites.gd"
## Stillmaw `5` (World 6, a flying heavy; spec §4.5): a floating grey
## porcelain death-mask with its lips stitched shut. The W6 rules (hush_kind):
## seen only in light, eyes always drawn, a silver rim, silent until close.
##   hush aura   within `aura_r`: his light x`aura_dim` (world.dim "stillmaw")
##               and the sound muffled (Sfx.hush_pulse); a faint ring and motes
##   drift       at `drift` px/s toward the nearest fixed light within `seek`
##               (a lit lantern post or brazier, a relit Vigil candle, a
##               Beacon: features.lamps() and the "beacon" lights), never an
##               altar, never a lamp tagged "anchor" (it feeds required
##               dawnglass); with none, toward Wick
##   swallow     beside the light (the tell, `swallow`): the stitches snap one
##               by one, the light's flame leans toward it; then the light goes
##               out (features.put_out) and it grows x`grow`, +`grow_hp` life
##               (at most `swallows_max`)
##   gulp        no light to eat and Wick near (the tell, `gulp_tell`): a
##               suction cone `gulp_cone` px deep pulls him at `gulp_pull`
##               px/s for `gulp_time` s (world.push_player; never started while
##               he's airborne over a pit), his light x`gulp_dim` inside;
##               touching the mouth: `gulp` damage and hushed. The Sexton's
##               wisp is gulped first (the kit's decoy("gulp", at)): one
##               goes into the mouth and he isn't pulled.
##   choke       a hit during either tell spits the light back (a lantern
##               burns `relight_extra` s longer; or Wick gets "Snatched back!",
##               light x1.3 for 3 s), stunning it `choke_stun` s at +25% damage
##   death       relights every light it swallowed.
## Numbers: TUNE. Nightfall: aura r 170. Witching: Swallow 0.8 s, Gulp
## 0.65 s (the floors). The 6-2 Dread is the Stitched Choir.

const HK := preload("res://scripts/hush_kind.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TUNE := {
	"life": 48.0, "gulp": 36.0, "touch": 22.0, "poise": 0.3, "embers": 6, "item": 0.14, "relic": 0.03,
	"aura_r": {"dusk": 150.0, "nightfall": 170.0, "witching": 170.0},
	"aura_dim": 0.75,
	"drift": 40.0, "seek": 400.0, "hunt": 320.0,
	"swallow_reach": 40.0,
	"swallow": 1.0, "swallow_floor": 0.8,
	"grow": 1.15, "grow_hp": 0.20, "swallows_max": 3,
	"gulp_range": 100.0,          # it gulps once he's within its cone's reach
	"gulp_dy": 60.0,              # ...and this near its height
	"decoy_t": 0.25,              # s its mouth stays open on a Sexton's wisp
	"bite_reach": 4.0,            # px round its mask the Gulp's mouth bites
	"gulp_tell": 0.8, "gulp_floor": 0.65,
	"gulp_pull": 90.0, "gulp_time": 1.0, "gulp_cone": 100.0, "gulp_half": 40.0, "gulp_dim": 0.6,
	"gulp_wait": 1.5,             # a gulp held back (he's airborne over a pit) gives up after this
	"again": 2.5,
	"sated": 1.5,                 # after a swallow
	"choke_stun": 1.5, "choke_bonus": 0.25, "relight_extra": 10.0,
	"choke_hold": 0.2,            # s in the choked pose once the stun lets go
	"snatch_mult": 1.3, "snatch_time": 3.0,
	"standoff": 80.0,             # px it keeps from Wick while it hunts him
	"hunt_dy": 12.0,              # px over his middle it hunts at
	"push_hold": 1.5,             # each tick's pull lasts this many ticks (no gap between ticks)
	"hover": 4.0,
	"aura_hush": 0.45,            # how far Sfx.hush_pulse muffles the sound in its aura
}
# Its blows at area 1 (TUNE's), for test_progression's share-cap scan (PR's ask).
const MOVES := {"gulp": TUNE["gulp"]}
const FRAMES := ["maw_idle", "maw_strain", "maw_open", "maw_choke", "maw_hit"]
const PORCELAIN := Color("d8d4e0")
const STITCH := Color("5a4a5a")

var state := "drift"            # drift, swallow_tell, sated, gulp_tell, gulp_hold, gulp, choked
var timer := 0.0
var move_id := ""
var seen := HK.DARK_A
var swallows := 0
var swallowed: Array = []       # {ref, kind}: what it ate (death gives them back)
var target := {}                # {p, ref, kind}: the light it wants
var gulped := false             # this gulp has bitten
var _tell_t := 1.0
var _cd := 0.0
var _choke_t := 0.0
var _home_y := 0.0
var _wait := 0.0
var _tb := TriBatch.new()


func _init() -> void:
	kind = "stillmaw"
	size = Vector2(30, 30)
	base_hp = float(TUNE["life"])
	base_dmg = float(TUNE["touch"])
	poise = float(TUNE["poise"])
	embers = int(TUNE["embers"])
	item_chance = float(TUNE["item"])
	relic_chance = float(TUNE["relic"])
	anchor = Vector2(64, 64)
	flier = true
	set("echo_by_body", false)     # MA's Echoing: its Gulp's bite is logged (strike_logged)
	set("lit_alpha_own", true)     # MA's Hushed Omen: its alpha is the W6 rule it already keeps (a no-op until elites.gd declares it)


func k(n: String) -> float:
	return HK.pick(TUNE, HK.diff_of(self), n)


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("maw_idle")
	_home_y = position.y


func moves() -> Dictionary:
	return {"touch": float(TUNE["touch"]), "gulp": float(TUNE["gulp"])}


func dmg(what := "touch") -> float:
	if what == "gulp":
		return float(TUNE["gulp"]) * dmg_mult
	return base_dmg * dmg_mult


func sfx(name: String, fallback := "", pitch := 1.0, gain := 1.0) -> void:
	if HK.quiet(self):
		return
	super(name, fallback, pitch, gain)


func tell_sfx(name: String, seconds: float, fallback := "") -> void:
	## (silent beyond 90 px, as every W6 sound: hush_kind.quiet)
	if HK.quiet(self):
		return
	super(name, seconds, fallback)


func rect() -> Rect2:
	return Rect2(position - size * 0.5, size)


func center() -> Vector2:
	return position


func mouth() -> Vector2:
	return position + Vector2(facing * size.x * 0.1, size.y * 0.22)


func cone() -> Rect2:
	## The Gulp's pull: gulp_cone px deep in its facing, gulp_half up and down.
	var m := mouth()
	var d := float(TUNE["gulp_cone"])
	var h := float(TUNE["gulp_half"])
	return Rect2(m.x if facing > 0 else m.x - d, m.y - h, d, h * 2.0)


# ---------------------------------------------------------------- lights

static func lamp_point(l: Dictionary) -> Vector2:
	## Where a lamp's flame is: a v2 post's "flame", else 30 px over its "pos".
	if l.has("flame"):
		return l["flame"]
	if l.has("p"):
		return l["p"]
	return (l.get("pos", Vector2.ZERO) as Vector2) - Vector2(0, 30)


func is_anchor(l: Dictionary) -> bool:
	## A lamp that feeds required dawnglass: never swallowed (by its tag, a
	## flag, or its World light's tag).
	if str(l.get("tag", "")).contains("anchor") or bool(l.get("anchor", false)):
		return true
	var id := int(l.get("id", -1))
	if id >= 0 and world != null and world.has_method("light_by_id"):
		return str((world.light_by_id(id) as Dictionary).get("tag", "")).contains("anchor")
	return false


func fixed_lights() -> Array:
	## [{p, ref, kind}]: the lit fixed lights it may eat (never altars or anchors).
	var out := []
	if world == null:
		return out
	var f = world.features
	if f != null and f.has_method("lamps"):
		for l in f.lamps():
			if bool(l.get("lit", false)) and not is_anchor(l):
				out.append({"p": lamp_point(l), "ref": l, "kind": "lamp"})
	if world.has_method("lights_tagged"):
		for l in world.lights_tagged("beacon"):
			if not str(l.get("tag", "")).contains("anchor"):
				out.append({"p": l["p"], "ref": l, "kind": "beacon"})
	return out


func _lit(tg: Dictionary) -> bool:
	if tg.is_empty():
		return false
	if tg["kind"] == "beacon":
		for id in world.dyn_lights():
			if is_same(world.dyn_lights()[id], tg["ref"]):
				return true
		return false
	return bool((tg["ref"] as Dictionary).get("lit", false))


func _nearest_light() -> Dictionary:
	var best := {}
	var bd := float(TUNE["seek"])
	for l in fixed_lights():
		var d := (l["p"] as Vector2).distance_to(position)
		if d < bd:
			bd = d
			best = l
	return best


func _put_out(tg: Dictionary) -> void:
	var f = world.features
	if tg["kind"] == "beacon":
		for id in world.dyn_lights().keys():
			if is_same(world.dyn_lights()[id], tg["ref"]):
				world.remove_light(id)
				var kt = world.get("kit")
				if kt != null and kt.has_method("put_out_beacon"):
					kt.put_out_beacon()
				elif kt != null and "beacon_t" in kt and int(kt.get("beacon")) == int(id):
					kt.set("beacon_t", 0.0)
					kt.set("beacon", -1)
				break
		return
	var l: Dictionary = tg["ref"]
	if f != null and f.has_method("put_out"):
		f.put_out(l)
	# A v2 lantern post, with a dispatcher that doesn't put them out itself
	# (since the wave-1 merge it does, refusing an anchor, so this is only
	# the old one's fallback).
	if bool(l.get("lit", false)) and l.has("brazier") and f != null and f.has_method("_put_out") and not f.has_method("_is_lantern"):
		f._put_out(l)


func _relight(tg: Dictionary, extra_t := 0.0) -> void:
	if tg["kind"] == "beacon":
		return   # the Beacon was the witch's and its time is hers
	var f = world.features
	var l: Dictionary = tg["ref"]
	if l.has("brazier"):
		# A v2 lantern post: lit again, and longer.
		if f != null and f.has_method("light"):
			f.light(l)
		if l.has("t"):
			l["t"] = float(l["t"]) + extra_t
	elif f != null and f.has_method("relight"):
		f.relight(l, extra_t)


# ---------------------------------------------------------------- the step

func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	seen = move_toward(seen, HK.lit_alpha(self) if alive else seen, dt * 6.0)
	HK.own_alpha(self, seen)
	_choke_t = maxf(_choke_t - dt, 0.0)
	if alive and active and player != null and player.alive:
		# The hush aura (stunned or not).
		var r := k("aura_r")
		if player.center().distance_to(position) <= r:
			world.dim("stillmaw", float(TUNE["aura_dim"]), 0.2)
			if not world.headless and world.has_method("_has_sfx") and world._has_sfx():
				var s = world.get_node_or_null("/root/Sfx")
				if s != null and s.has_method("hush_pulse"):
					s.hush_pulse(0.3, float(TUNE["aura_hush"]))


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_cd = maxf(_cd - dt, 0.0)
	match state:
		"drift":
			show_frame("maw_idle")
			var tg := _nearest_light()
			if not tg.is_empty() and swallows < int(TUNE["swallows_max"]):
				target = tg
				var want: Vector2 = (tg["p"] as Vector2) + Vector2(0, -6)
				facing = 1 if want.x > position.x else -1
				if position.distance_to(want) <= float(TUNE["swallow_reach"]):
					_start_swallow()
				else:
					_fly_to(want, spd(float(TUNE["drift"])), dt)
			else:
				target = {}
				_hunt(dt, player)
		"swallow_tell":
			show_frame("maw_strain" if timer > _tell_t * 0.3 else "maw_open")
			if not _lit(target):
				state = "drift"
				move_id = ""
			elif timer <= 0.0:
				_swallow()
		"sated":
			show_frame("maw_idle")
			_bob(dt)
			if timer <= 0.0:
				state = "drift"
		"gulp_tell":
			show_frame("maw_strain" if timer > _tell_t * 0.3 else "maw_open")
			if timer <= 0.0:
				if HK.over_pit(world, player):
					state = "gulp_hold"
					_wait = 0.0
				else:
					_start_gulp(player)
		"gulp_hold":
			show_frame("maw_open")
			_wait += dt
			if not HK.over_pit(world, player):
				_start_gulp(player)
			elif _wait >= float(TUNE["gulp_wait"]):
				_end_gulp()
		"gulp":
			show_frame("maw_open")
			_gulp_tick(dt, player)
			if timer <= 0.0:
				_end_gulp()
		"choked":
			show_frame("maw_choke")
			if timer <= 0.0:
				state = "drift"


func _bob(dt: float) -> void:
	position.y += sin(t * 2.0) * float(TUNE["hover"]) * dt


func _fly_to(p: Vector2, speed: float, dt: float) -> void:
	## Drift toward p, sliding round walls rather than through them.
	var d := p - position
	if d.length() < 1.0:
		return
	var v := d.normalized() * minf(speed * dt, d.length())
	var nx := position + Vector2(v.x, 0)
	if not _blocked(nx):
		position = nx
	var ny := position + Vector2(0, v.y)
	if not _blocked(ny):
		position = ny


func _blocked(p: Vector2) -> bool:
	var r := Rect2(p - size * 0.4, size * 0.8)
	for q in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		if solid_at(q):
			return true
	return false


func _hunt(dt: float, player: Node2D) -> void:
	## No light to eat: it comes for his flame, and gulps once it's close.
	if player == null or not player.alive or player.center().distance_to(position) > float(TUNE["hunt"]):
		_bob(dt)
		return
	var pc0: Vector2 = player.center()
	facing = 1 if pc0.x > position.x else -1
	var dx := absf(pc0.x - position.x)
	if dx <= float(TUNE["gulp_range"]) and absf(pc0.y - position.y) < float(TUNE["gulp_dy"]) and _cd <= 0.0:
		_start_gulp_tell()
		return
	var want := Vector2(pc0.x - facing * float(TUNE["standoff"]), pc0.y - float(TUNE["hunt_dy"]))
	_fly_to(want, spd(float(TUNE["drift"])), dt)


func _start_swallow() -> void:
	state = "swallow_tell"
	_tell_t = tell(float(TUNE["swallow"]), float(TUNE["swallow_floor"]))
	timer = _tell_t
	move_id = "stillmaw:swallow"
	tell_sfx("stitch_snap", timer, "bones")


func _swallow() -> void:
	## The light goes out, and it grows.
	_put_out(target)
	swallowed.append(target)
	swallows += 1
	var old := max_hp
	scale_mult *= float(TUNE["grow"])
	size = Vector2(30, 30) * scale_mult
	max_hp *= 1.0 + float(TUNE["grow_hp"])
	hp += max_hp - old
	if world != null and world.glow:
		world.glow.burst(target["p"], 10, Color(0.6, 0.58, 0.66, 0.7), 60.0, 0.8, -40.0, 3.0)
	target = {}
	state = "sated"
	timer = float(TUNE["sated"])
	move_id = ""
	sfx("gulp_inhale", "mimic_snore", 0.6)


func _start_gulp_tell() -> void:
	state = "gulp_tell"
	_tell_t = tell(float(TUNE["gulp_tell"]), float(TUNE["gulp_floor"]))
	timer = _tell_t
	move_id = "stillmaw:gulp"
	tell_sfx("gulp_inhale", timer, "mimic_snore")


func _start_gulp(player: Node2D) -> void:
	state = "gulp"
	timer = float(TUNE["gulp_time"])
	gulped = false
	sfx("gulp_inhale", "mimic_snore")
	# The Sexton's wisp is gulped first (his dead are a decoy): the kit's
	# decoy("gulp", at) (KT's kit.gd / sexton.gd) gives one up and returns
	# {p, kind}, or {} to let the Gulp go on; a kit without it, a Sexton's
	# wisp is popped here.
	var kt = world.get("kit")
	if kt != null and player != null and cone().has_point(player.center()):
		var took := false
		if kt.has_method("decoy"):
			var got = kt.decoy("gulp", mouth())
			took = got is Dictionary and not (got as Dictionary).is_empty()
		elif str(kt.get("cls")) == "sexton" and kt.get("wisps") is Array and not (kt.get("wisps") as Array).is_empty():
			(kt.wisps as Array).pop_back()
			took = true
		if took:
			gulped = true
			if world.glow:
				world.glow.burst(mouth(), 10, Color("c0c8f0"), 80.0, 0.4, 0.0, 2.2)
			timer = float(TUNE["decoy_t"])


func _gulp_tick(dt: float, player: Node2D) -> void:
	if player == null or not player.alive or gulped:
		return
	var inside := cone().has_point(player.center())
	if inside:
		# Pulled toward the mouth (a displacement the World caps and brakes).
		world.push_player(Vector2(-facing * float(TUNE["gulp_pull"]), 0.0), dt * float(TUNE["push_hold"]), "stillmaw:%d" % get_instance_id())
		world.dim("gulp", float(TUNE["gulp_dim"]), 0.1)
	var bite := rect().grow(float(TUNE["bite_reach"]))
	if bite.intersects(player.rect()):
		gulped = true
		if world.hurt_player(dmg("gulp"), position.x, "hit", self, {"move": "stillmaw:gulp"}):
			HK.hush_player(world)
		strike_logged(bite, dmg("gulp"))


func _end_gulp() -> void:
	state = "drift"
	_cd = cd(float(TUNE["again"]))
	move_id = ""
	if world != null:
		world.push_player(Vector2.ZERO, 0.0, "stillmaw:%d" % get_instance_id())


func touch_damage() -> bool:
	# The gulp's bite is its own; otherwise its touch.
	return state != "gulp"


# ---------------------------------------------------------------- being hit

func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	if _choke_t > 0.0 and h.has("amount"):
		h["amount"] = float(h["amount"]) * (1.0 + float(TUNE["choke_bonus"]))
	var was := state
	var ok := super(h)
	if ok and alive and (was == "swallow_tell" or was == "gulp_tell" or was == "gulp_hold"):
		_choke(was)
	return ok


func _choke(was: String) -> void:
	## Hit mid-tell: it spits the light back and reels.
	if was == "swallow_tell" and not target.is_empty():
		_relight(target, float(TUNE["relight_extra"]))
		if world.glow:
			world.glow.burst(target["p"], 14, Color("f7b64a"), 110.0, 0.5, -80.0, 2.3)
	else:
		if world.floaters:
			world.floaters.add(position + Vector2(0, -24), 0.0, "text", 0, "Snatched back!")
		if world.features and world.features.has_method("boost"):
			world.features.boost(float(TUNE["snatch_mult"]), float(TUNE["snatch_time"]))
	target = {}
	state = "choked"
	timer = float(TUNE["choke_hold"])   # the stun holds it (think doesn't run while stunned)
	_choke_t = float(TUNE["choke_stun"])
	apply_status("stun", float(TUNE["choke_stun"]))
	_cd = cd(float(TUNE["again"]))
	move_id = ""
	sfx("choke_spit", "dripkin_splat")


func _hurt(h: Dictionary) -> void:
	show_frame("maw_hit")


func _kill(h: Dictionary) -> void:
	# Every light it swallowed comes back.
	for tg in swallowed:
		_relight(tg, 0.0)
	swallowed.clear()
	if world != null:
		world.push_player(Vector2.ZERO, 0.0, "stillmaw:%d" % get_instance_id())
	super(h)
	show_frame("maw_hit")
	velocity = Vector2(0, 40)
	if world != null and world.glow:
		world.glow.burst(position, 14, PORCELAIN, 150.0, 0.6, 500.0, 2.4)


func _dying(dt: float) -> void:
	# The mask cracks and sinks away.
	position += velocity * dt
	velocity.y += 300.0 * dt
	fade = clampf(1.0 - death_time * 1.5, 0.0, 1.0)
	if death_time > 0.8:
		gone = true


func eye_points() -> Array:
	## What the World lights (8 a screen): an elite's only, as v2's kinds.
	return w6_eyes() if tier != "" else []


func w6_eyes() -> Array:
	var eyes := HK.frame_eyes(frame_name)
	if not frames.is_empty() and not eyes.is_empty():
		var out := []
		for p in eyes:
			out.append(frame_point(p))
		return out
	var s := scale_mult
	return [position + Vector2(-5.0, -4.0) * s, position + Vector2(5.0, -4.0) * s]


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := _tb
	# The aura: a faint ring with grey motes drifting in it.
	var r := k("aura_r")
	tb.ring(position, r, 1.5, Color(0.8, 0.8, 0.9, 0.12), 48)
	for i in 6:
		var a := t * 0.4 + TAU * i / 6.0
		var rr := r * (0.55 + 0.35 * fmod(i * 0.37 + t * 0.1, 1.0))
		tb.circle(position + Vector2(cos(a), sin(a) * 0.6) * rr, 1.8, Color(0.75, 0.74, 0.82, 0.35), 6)
	HK.draw_eyes(self, glow, tb, HK.EYE_R, Color("f0eeff"))
	var telling := state in ["swallow_tell", "gulp_tell", "gulp_hold"]
	if telling:
		var kk := 1.0 - clampf(timer / maxf(_tell_t, 0.01), 0.0, 1.0) if state != "gulp_hold" else 1.0
		# The stitches snapping, one by one: bright ticks across the lips.
		var m := mouth()
		var n := 5
		var gone_n := int(kk * n + 0.001)
		for i in n:
			var x := m.x + (i - 2) * 4.0 * scale_mult
			var col := Color(1, 1, 1, 0.95) if i < gone_n else Color(0.9, 0.85, 0.95, 0.45)
			tb.line(Vector2(x, m.y - 3.0), Vector2(x, m.y + 3.0), 1.6, col)
		tb.ring(position, size.x * (0.9 - 0.2 * kk), 1.5 + 1.5 * kk, Color(HK.RIM, 0.35 + 0.5 * kk), 20)
		if state == "swallow_tell" and not target.is_empty():
			# The light's flame leans toward it, drawn out in a thread.
			var lp: Vector2 = target["p"]
			var o := (m - lp).normalized().orthogonal()
			for j in 6:
				var u := float(j) / 5.0
				var q := lp.lerp(m, u * kk) + o * sin(u * PI + t * 12.0) * 3.0
				tb.circle(q, 2.4 * (1.0 - u * 0.6), Color(1.0, 0.75, 0.35, 0.8 * (1.0 - u * 0.5)), 8)
		elif state != "swallow_tell":
			# The cone it will pull in.
			var c := cone()
			var tip := m
			var far := Vector2(c.end.x if facing > 0 else c.position.x, m.y)
			tb.tri(tip, far + Vector2(0, -c.size.y * 0.5), far + Vector2(0, c.size.y * 0.5), Color(0.8, 0.8, 0.95, 0.08 + 0.12 * kk))
			for j in 4:
				var ph := fmod(t * 1.5 + j * 0.25, 1.0)
				var x := lerpf(far.x, tip.x, ph)
				var hh := c.size.y * 0.5 * (1.0 - ph)
				tb.line(Vector2(x, m.y - hh), Vector2(x, m.y + hh), 1.2, Color(1, 1, 1, 0.3 + 0.4 * kk))
	elif state == "gulp":
		var c := cone()
		var m := mouth()
		var far := Vector2(c.end.x if facing > 0 else c.position.x, m.y)
		tb.tri(m, far + Vector2(0, -c.size.y * 0.5), far + Vector2(0, c.size.y * 0.5), Color(0.1, 0.08, 0.16, 0.35))
		for j in 6:
			var ph := fmod(t * 3.0 + j / 6.0, 1.0)
			var x := lerpf(far.x, m.x, ph)
			var hh := c.size.y * 0.5 * (1.0 - ph)
			tb.line(Vector2(x, m.y - hh), Vector2(x - facing * 10.0, m.y - hh * 0.8), 1.4, Color(1, 1, 1, 0.5))
			tb.line(Vector2(x, m.y + hh), Vector2(x - facing * 10.0, m.y + hh * 0.8), 1.4, Color(1, 1, 1, 0.5))
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var s := scale_mult
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s * facing, s))
	var tb := _tb
	var a := clampf(fade, 0.0, 1.0) * seen
	var open := state in ["gulp", "gulp_hold"] or (state in ["swallow_tell", "gulp_tell"] and timer < _tell_t * 0.3)
	# The mask: an oval face, silver-rimmed (W6), porcelain grey.
	tb.ellipse(Vector2(0, 0), 13.0 + HK.RIM_PX, 15.0 + HK.RIM_PX, Color(HK.RIM, a), 20)
	tb.ellipse(Vector2(0, 0), 13.0, 15.0, _c(PORCELAIN, a), 20)
	tb.ellipse(Vector2(-3, -5), 7.0, 5.0, _c(PORCELAIN.lightened(0.25), a * 0.8), 14)
	# Empty eye holes and a crack.
	tb.ellipse(Vector2(-5, -4), 3.0, 2.2, _c(Color("1c1830"), a), 10)
	tb.ellipse(Vector2(5, -4), 3.0, 2.2, _c(Color("1c1830"), a), 10)
	tb.line(Vector2(6, -13), Vector2(3, -7), 0.9, _c(STITCH, a))
	# The mouth: stitched lips, or torn open on the dark inside.
	if open:
		tb.ellipse(Vector2(0, 6.5), 6.0, 5.0, _c(Color("0a0810"), a), 14)
		tb.ring(Vector2(0, 6.5), 6.0, 1.0, _c(STITCH, a), 14)
	else:
		tb.line(Vector2(-6, 6.5), Vector2(6, 6.5), 1.4, _c(STITCH, a))
		for i in 5:
			var x := -4.0 + i * 2.0
			tb.line(Vector2(x, 4.5), Vector2(x, 8.5), 1.0, _c(STITCH, a))
	tb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _c(col: Color, a := 1.0) -> Color:
	return HK.shade(self, col, a)
