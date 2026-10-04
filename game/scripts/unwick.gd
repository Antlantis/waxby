extends "res://scripts/elites.gd"
## Unwick `6` (World 6, a heavy; spec §4.5): your echo. It is drawn as the
## player's own rig (wick_rig.gd, his calling and gear) in black with a
## silver rim, a dark flame on its candle, two white slit eyes. While Wick is
## within `range` px it replays his path `delay` s behind him (a buffer of
## his {pos, facing, velocity, floor, swing, climb} every tick; it glides
## onto the path at `approach` px/s first, then its position at t is his at
## t - delay), and copies his basic attacks `delay` s later at the same
## place: a swing becomes a dark copy of his attack rect (`echo` damage), a
## basic shot (spark, knife) a dark copy along the same vector at
## `shot_speed` of its speed (`shot` damage). Specials are never copied: a
## harmless ghost flash. The tell: `outline` s before each copy, a faint
## white outline of its rect (or the shot's path) shows where it will be.
## If he stands still it walks into him (touch). It is solid only inside his
## own light (world.hero_light_radius about his flame, the Snuffer's Lights
## Out test): outside it, swings and shots pass through and it can't touch
## him. It never dodges; a hit cancels its next copy. Numbers: TUNE.
##
## Nightfall: 0.85 s behind. Witching: 0.7 s, in pairs (the second 1.4 s
## behind). At most 2 on screen (the levels' rule). The 6-3 Dread is the
## Long Shadow.

const HK := preload("res://scripts/hush_kind.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const RigScript := preload("res://scripts/wick_rig.gd")
const TUNE := {
	"life": 40.0, "echo": 34.0, "shot": 30.0, "touch": 28.0, "poise": 0.3,
	"embers": 6, "item": 0.16, "relic": 0.04,
	"range": 300.0,
	"delay": {"dusk": 1.0, "nightfall": 0.85, "witching": 0.7},
	"outline": 0.60,              # the tell before each copy (never shorter)
	"swing_time": 0.13,           # a copied swing is live this long (the player's ATTACK_ACTIVE)
	"shot_speed": 0.7,
	"approach": 260.0,            # px/s onto its path
	"lock_on": 6.0,               # px from the path where it starts replaying exactly
	"buffer": 1.5,                # s of him it remembers (>= the pair's delay)
	"pair": {"dusk": 1, "nightfall": 1, "witching": 2},
	"hit_flash": 0.2,
	"jump_px": 48.0,              # his position jumping this far in a tick breaks the path
	"pair_gap": 24.0,             # px behind it a Witching pair's second starts
	"stale": 0.25,                # s without a sample (asleep): its memory of his path is stale
	"eye_w": 2.6, "eye_h": 1.6,   # the slit eyes' half sizes (3.2 px tall: decisions' r >= 3 at >= 0.9)
	"eye_gap": 3.2,               # px from the head's middle to each eye
}
# Its blows at area 1 (TUNE's), for test_progression's share-cap scan (PR's ask).
const MOVES := {"echo": TUNE["echo"], "shot": TUNE["shot"]}
const SHOT_KINDS := ["spark", "knife"]
const INK := Color("0e0c14")
# The rim on the rig's own small picture (a SubViewport of VIEW units, _k
# texels a unit), not on the screen: no full-screen back buffer and no
# extra screen pass (the review's W6 finding: a CanvasGroup's took 20 MB and
# a pass a Unwick at 2868 x 1320).
const RIM_SHADER := """shader_type canvas_item;
render_mode unshaded;
uniform vec4 body : source_color = vec4(0.09, 0.08, 0.13, 1.0);
uniform vec4 rim : source_color = vec4(0.784, 0.784, 0.941, 1.0);
uniform float px = 2.0;
uniform float alpha = 1.0;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 d = TEXTURE_PIXEL_SIZE * px;
	float o = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		o = max(o, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * d).a);
	}
	float edge = clamp(o - a, 0.0, 1.0);
	vec4 c = vec4(body.rgb, a) * (1.0 - edge) + vec4(rim.rgb, 1.0) * edge;
	c.a = max(a, edge) * alpha;
	COLOR = c;
}
"""


class Puppet extends Node2D:
	## What the rig reads off a player, played back from the buffer. (The rig
	## wants a Node2D; this one is the Unwick's hidden child, so it goes with it.)
	const ATTACK_ACTIVE := 0.13
	var facing := 1
	var velocity := Vector2.ZERO
	var on_floor := true
	var attack_time := -1.0
	var hurt_time := 9.0
	var alive := true
	var invuln := 0.0
	var ledge_t := -1.0
	var climbing := false
	var climb_state := ""


static var _shader: Shader = null

var move_id := ""
var seen := HK.DARK_A
var delay := 1.0                # s behind him
var delay_mult := 1.0           # a Witching pair's second: 2
var following := false          # on his path, replaying exactly
var samples: Array = []         # {t, pos, facing, vel, floor, at, climb, cstate}
var pending: Array = []         # copies to come: {at, kind: swing | shot | ghost, rect, pos, vel, life, t0, cancelled}
var swings: Array = []          # copies striking now: {rect, until, hit}
var echo_shots: Array = []      # {pos, vel, life}
var copies := 0                 # copies made (tests)
var rig: Node2D = null
var puppet: Puppet = null
var cls := "knight"
var _group: Node2D = null       # the silhouette on screen: the view's picture through the rim shader
var _mat: ShaderMaterial = null
var _view: SubViewport = null    # the rig, drawn small and alone (VIEW units at _k texels a unit)
var _k := 2.0
const VIEW := Vector2(112, 128)  # the box the rig is drawn in, units (his reach with a weapon, and the rim)
const VIEW_FOOT := 20.0          # units of it under his feet (a lunge's dip, the rim)
var _last_swing := -1
var _paired := false
var pack_of := Vector2i(-1, -1) # a Witching pair's second: the cell of the one that brought it
var _last_tick := -1.0          # the World's clock at its last sample (asleep longer: its memory is stale)
var _tb := TriBatch.new()


func _init() -> void:
	kind = "unwick"
	size = Vector2(20, 30)
	base_hp = float(TUNE["life"])
	base_dmg = float(TUNE["touch"])
	poise = float(TUNE["poise"])
	embers = int(TUNE["embers"])
	item_chance = float(TUNE["item"])
	relic_chance = float(TUNE["relic"])
	belt_carry = false
	flier = true           # kinematic on his path: never the tile physics (a stun holds it where it is)
	set("echo_by_body", false)     # MA's Echoing: never on it (NEVER_ON), and its copies are logged
	set("lit_alpha_own", true)     # MA's Hushed Omen: its alpha is the W6 rule it already keeps (a no-op until elites.gd declares it)


func k(n: String) -> float:
	return HK.pick(TUNE, HK.behave_of(self), n)


func make_elite(t: String, o: Array) -> void:
	## Promoted after _ready (level_features.assign_elites): the delay is
	## picked again, by behave_diff (an Anointed one follows 0.85 s behind on
	## Dusk from World 3).
	super(t, o)
	delay = k("delay") * delay_mult


func _ready() -> void:
	super()
	delay = k("delay") * delay_mult
	var g := get_node_or_null("/root/Game")
	if g != null and g.has_method("hero"):
		cls = str((g.hero() as Dictionary).get("cls", "knight"))
	if world != null and world.get("player") != null:
		size = world.player.size
		var pk = world.player.get("kit")
		if pk != null and pk.get("cls") != null:
			cls = str(pk.cls)
	_make_rig()


func _make_rig() -> void:
	## His own rig in black with a silver rim: the rig drawn alone into a
	## small SubViewport, shown by a sprite whose shader keeps only its shape
	## (the body colour) and outlines it. The box is made at the screen's
	## scale, so the silhouette is as sharp as the level's own art.
	puppet = Puppet.new()
	puppet.name = "Puppet"
	puppet.visible = false
	puppet.facing = facing
	add_child(puppet)       # freed with the Unwick (a loose Node2D would leak)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = RIM_SHADER
	_k = _screen_k()
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("rim", HK.RIM)
	_mat.set_shader_parameter("body", HK.BODY.darkened(0.45))
	_mat.set_shader_parameter("px", HK.RIM_PX * _k)   # RIM_PX units, in the picture's texels
	var vp := SubViewport.new()
	vp.name = "View"
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.size = Vector2i(ceili(VIEW.x * _k), ceili(VIEW.y * _k))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(vp)
	_view = vp
	var holder := Node2D.new()
	holder.position = _foot()
	holder.scale = Vector2(_k, _k)
	vp.add_child(holder)
	rig = RigScript.new()
	rig.cls = cls
	rig.player = puppet
	rig.kit = null
	holder.add_child(rig)
	var spr := Sprite2D.new()
	spr.name = "Silhouette"
	spr.centered = false
	spr.texture = vp.get_texture()
	spr.position = -_foot() / _k
	spr.scale = Vector2.ONE / _k
	spr.material = _mat
	_group = spr
	add_child(spr)


func _foot() -> Vector2:
	## Where his feet stand in the view, in its texels.
	return Vector2(VIEW.x * 0.5, VIEW.y - VIEW_FOOT) * _k


func _screen_k() -> float:
	## Texels a unit for the view: the screen's px a unit here (the glass's
	## scale x the level's), in halves, 1 to 4.
	if not is_inside_tree():
		return 2.0
	var vp := get_viewport()
	var sk: float = vp.get_final_transform().get_scale().x * get_global_transform_with_canvas().get_scale().x
	return clampf(ceilf(sk * 2.0) / 2.0, 1.0, 4.0)


func moves() -> Dictionary:
	return {"touch": float(TUNE["touch"]), "echo": float(TUNE["echo"]), "shot": float(TUNE["shot"])}


func dmg(what := "touch") -> float:
	if what == "echo":
		return float(TUNE["echo"]) * dmg_mult
	if what == "shot":
		return float(TUNE["shot"]) * dmg_mult
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


# ---------------------------------------------------------------- solid only in his light

func solid() -> bool:
	if not alive or world == null or world.get("player") == null:
		return false
	var pl: Node2D = world.player
	if not pl.alive:
		return false
	return center().distance_to(pl.center() + Vector2(0, -8)) < float(world.hero_light_radius())


func rect() -> Rect2:
	if not solid():
		return NOWHERE
	return Rect2(position.x - size.x * 0.5, position.y - size.y, size.x, size.y)


func hurt_rect() -> Rect2:
	return rect().grow(-4.0) if solid() else NOWHERE


func center() -> Vector2:
	return position - Vector2(0, size.y * 0.5)


func hit(h: Dictionary) -> bool:
	if not solid():
		return false
	var ok := super(h)
	if ok:
		# It never dodges, but a hit spoils its next copy.
		for p in pending:
			if not p["cancelled"] and float(p["at"]) > t and p["kind"] != "ghost":
				p["cancelled"] = true
				break
	return ok


func touch_damage() -> bool:
	return solid()


func _hurt(h: Dictionary) -> void:
	flash = 1.0


func apply_status(name: String, seconds: float, data := {}) -> void:
	## Staggered (a Perfect Guard) or held: it loses his path (and glides back
	## onto it after, never snapping a second ahead), and the copies that come
	## due meanwhile are spoiled.
	super(name, seconds, data)
	if name in ["stun", "root", "flipped"]:
		following = false
		for p in pending:
			if float(p["at"]) <= t + seconds:
				p["cancelled"] = true


# ---------------------------------------------------------------- the buffer

func step(dt: float, player: Node2D) -> void:
	if alive and player != null:
		_record(player, dt)
	super(dt, player)
	seen = move_toward(seen, HK.lit_alpha(self) if alive else seen, dt * 6.0)
	if _mat:
		_mat.set_shader_parameter("alpha", clampf(fade, 0.0, 1.0) * maxf(seen, 0.15 if alive else 0.0))
	if _group:
		_group.modulate = Color(1, 1, 1).lerp(Color(3, 3, 3), clampf(flash, 0.0, 1.0) * 0.5)


func _record(pl: Node2D, dt: float) -> void:
	## One sample of him (after his step this tick), and what he struck with.
	## Stamped with this tick's time (t + dt: step() adds dt after it), so its
	## position at t is exactly his at t - delay. Woken after a sleep (out of
	## the World's reach), it forgets the old path and finds his anew.
	var wt = world.get("_t") if world != null else null
	if wt != null:
		if _last_tick >= 0.0 and float(wt) - _last_tick > float(TUNE["stale"]):
			samples.clear()
			pending.clear()
			following = false
		_last_tick = float(wt)
	var now := t + dt
	if not samples.is_empty() and (samples[-1]["pos"] as Vector2).distance_to(pl.position) > float(TUNE["jump_px"]):
		# He was put somewhere else (relit at an altar, a pit's return): that
		# isn't a path to walk. It lets go and finds him anew.
		samples.clear()
		pending.clear()
		following = false
	samples.append({"t": now, "pos": pl.position, "facing": int(pl.facing), "vel": pl.velocity, "floor": bool(pl.on_floor),
			"at": float(pl.attack_time), "climb": pl.get("climbing") == true, "cstate": str(pl.get("climb_state"))})
	var keep := float(TUNE["buffer"])
	while samples.size() > 2 and now - float(samples[0]["t"]) > keep:
		samples.pop_front()
	var d := delay
	# A swing: its rect as it began.
	var aid := int(pl.get("attack_id"))
	if float(pl.attack_time) >= 0.0 and float(pl.attack_time) <= pl.ATTACK_ACTIVE and aid != _last_swing:
		_last_swing = aid
		var r: Rect2 = pl.attack_rect()
		if r.size.x > 0.0:
			pending.append({"at": now + d, "kind": "swing", "rect": r, "t0": now, "cancelled": false})
	# His basic shots spawned this tick.
	if world != null:
		for s in world.shots:
			if str(s.get("owner", "")) != "player" or float(s.get("t", 1.0)) != 0.0:
				continue
			if not (str(s.get("kind", "")) in SHOT_KINDS) or s.get("special", false) or s.get("child", false):
				continue
			pending.append({"at": now + d, "kind": "shot", "pos": s["pos"], "vel": s["vel"], "life": float(s.get("life", 0.5)),
					"t0": now, "cancelled": false})
		# A Special: only a ghost flash.
		var pad = world.get("_pad")
		if pad is Dictionary and pad.get("special_pressed", false):
			pending.append({"at": now + d, "kind": "ghost", "pos": pl.center(), "t0": now, "cancelled": false})


func sample_at(when: float) -> Dictionary:
	## His sample at time `when` on its clock (the last one at or before it,
	## interpolated toward the next); {} with none that old yet.
	if samples.is_empty() or float(samples[0]["t"]) > when + 0.0001:
		return {}
	var n := samples.size()
	for i in range(n - 1, -1, -1):
		var s: Dictionary = samples[i]
		if float(s["t"]) <= when + 0.0001:
			if i == n - 1:
				return s
			var nx: Dictionary = samples[i + 1]
			var span := float(nx["t"]) - float(s["t"])
			var u := clampf((when - float(s["t"])) / maxf(span, 0.0001), 0.0, 1.0)
			var out := s.duplicate()
			out["pos"] = (s["pos"] as Vector2).lerp(nx["pos"], u)
			return out
	return samples[0]


# ---------------------------------------------------------------- the step

func think(dt: float, player: Node2D) -> void:
	if not _paired:
		_paired = true
		_bring_pair()
	var near: bool = player != null and player.alive and player.center().distance_to(center()) <= float(TUNE["range"])
	if not following and not near:
		_idle()
		move_id = ""
	else:
		var s := sample_at(t - delay)
		if s.is_empty():
			_idle()
		else:
			var to: Vector2 = s["pos"]
			if following or position.distance_to(to) <= float(TUNE["lock_on"]):
				following = true
				position = to
				_pose(s)
			else:
				# Onto his path first, gliding.
				var d := to - position
				position += d.normalized() * minf(float(TUNE["approach"]) * dt, d.length())
				facing = 1 if d.x >= 0.0 else -1
				_pose({"facing": facing, "vel": d.normalized() * float(TUNE["approach"]), "floor": true, "at": -1.0, "climb": false, "cstate": ""})
			move_id = "unwick:echo"
	_copies(dt, player)


func _idle() -> void:
	if puppet:
		puppet.velocity = Vector2.ZERO
		puppet.on_floor = true
		puppet.attack_time = -1.0
		puppet.climbing = false


func _pose(s: Dictionary) -> void:
	facing = int(s.get("facing", facing))
	if puppet == null:
		return
	puppet.position = position
	puppet.facing = facing
	puppet.velocity = s.get("vel", Vector2.ZERO)
	puppet.on_floor = bool(s.get("floor", true))
	puppet.attack_time = float(s.get("at", -1.0))
	puppet.climbing = bool(s.get("climb", false))
	puppet.climb_state = str(s.get("cstate", ""))


func _copies(dt: float, player: Node2D) -> void:
	## Its copies come due (only once it walks his path).
	for p in pending:
		if float(p["at"]) > t or p.get("done", false):
			continue
		p["done"] = true
		if p["cancelled"] or not following:
			continue
		copies += 1
		match p["kind"]:
			"swing":
				swings.append({"rect": p["rect"], "until": t + float(TUNE["swing_time"]), "hit": false})
				strike_logged(p["rect"], dmg("echo"))
				sfx("echo_whisper", "snuffer_whisper", 1.2)
			"shot":
				var v: Vector2 = (p["vel"] as Vector2) * float(TUNE["shot_speed"])
				echo_shots.append({"pos": p["pos"], "vel": v, "life": float(p["life"]) / float(TUNE["shot_speed"])})
				strike_logged({"kind": "shot", "pos": p["pos"], "vel": v}, dmg("shot"))
				sfx("echo_whisper", "snuffer_whisper", 1.4)
			"ghost":
				if world != null and world.glow:
					world.glow.burst(p["pos"], 10, Color(0.55, 0.5, 0.8, 0.6), 90.0, 0.4, 0.0, 2.6)
	pending = pending.filter(func(p): return not p.get("done", false))
	# Live copies.
	var pr: Rect2 = player.rect() if player != null else Rect2()
	for sw in swings:
		if not sw["hit"] and player != null and player.alive and (sw["rect"] as Rect2).intersects(pr.grow(-2.0)):
			sw["hit"] = true
			world.hurt_player(dmg("echo"), (sw["rect"] as Rect2).get_center().x, "hit", self, {"move": "unwick:echo"})
	swings = swings.filter(func(sw): return float(sw["until"]) > t)
	for es in echo_shots:
		es["life"] = float(es["life"]) - dt
		var nx: Vector2 = (es["pos"] as Vector2) + (es["vel"] as Vector2) * dt
		if solid_at(nx):
			es["life"] = 0.0
		es["pos"] = nx
		if float(es["life"]) > 0.0 and player != null and player.alive and pr.grow(-2.0).has_point(nx):
			es["life"] = 0.0
			world.hurt_player(dmg("shot"), nx.x - signf((es["vel"] as Vector2).x) * 20.0, "shot", self, {"move": "unwick:echo_shot", "shot": true})
	echo_shots = echo_shots.filter(func(es): return float(es["life"]) > 0.0)


func _bring_pair() -> void:
	## Witching's pairs: a placed Unwick brings a second, twice as far behind,
	## on its first think (never a third). A heavy: neither comes back after
	## a snuff (the World respawns only ordinary monsters).
	var cell: Vector2i = spawn.get("cell", Vector2i(-1, -1))
	if int(k("pair")) < 2 or copy or delay_mult != 1.0 or pack_of.x >= 0 or tier == "dread" or tier == "warden" or world == null or cell.x < 0:
		return
	if HK.pack_count(world, kind, cell) > 0:
		return
	var m: Node2D = world.spawn_enemy(kind, position + Vector2(-facing * float(TUNE["pair_gap"]), 0),
			{"facing": facing, "respawned": respawned or t > 0.1})
	if m:
		m.set("delay_mult", 2.0)
		m.set("delay", k("delay") * 2.0)
		m.set("_paired", true)
		m.set("pack_of", cell)
		m.active = active


# ---------------------------------------------------------------- death

func _kill(h: Dictionary) -> void:
	super(h)
	pending.clear()
	swings.clear()
	echo_shots.clear()
	velocity = Vector2.ZERO
	if puppet:
		puppet.alive = false       # the rig topples, as he does when snuffed
	sfx("unwick_fade", "douse")
	if world != null and world.glow:
		world.glow.burst(center(), 14, Color(0.55, 0.5, 0.8, 0.7), 110.0, 0.7, -80.0, 2.6)


func _dying(dt: float) -> void:
	fade = clampf(1.0 - death_time * 1.4, 0.0, 1.0)
	if death_time > 0.8:
		gone = true


func eye_points() -> Array:
	## What the World lights (8 a screen): an elite's only, as v2's kinds.
	return w6_eyes() if tier != "" else []


func w6_eyes() -> Array:
	## Two white slits under the helm (where the rig's head is).
	var f := float(facing)
	var c := position + Vector2(f * 3.0, -20.0)
	var g := float(TUNE["eye_gap"])
	return [c + Vector2(-g, 0), c + Vector2(g, 0)]


func outlines() -> Array:
	## The copies whose outline shows now (the tell): each pending swing or
	## shot with `outline` s or less to go, while it walks his path.
	var out := []
	for p in pending:
		if p["cancelled"] or p["kind"] == "ghost" or not following or p.get("done", false):
			continue
		if float(p["at"]) - t <= float(TUNE["outline"]):
			out.append(p)
	return out


func _draw_elite(glow: Node2D) -> void:
	# The elite's ring at its feet (its position), not under rect(): rect()
	# is nowhere outside his light, and it's a flier only for the physics.
	var was := flier
	flier = false
	super(glow)
	flier = was


func _draw() -> void:
	pass   # the rig is its body (no frames, no stand-in)


func flame_point() -> Vector2:
	## (the rig's flame is in its view's texels: back to the level's space)
	if rig != null and rig.has_method("flame_point") and rig.is_inside_tree():
		return to_global((rig.flame_point() - _foot()) / _k)
	return position + Vector2(0, -52)


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	var tb := _tb
	# The tells: a faint white outline of each copy to come, outline s ahead.
	var ahead := float(TUNE["outline"])
	for p in outlines():
		var left := float(p["at"]) - t
		var kk := 1.0 - clampf(left / ahead, 0.0, 1.0)
		var col := Color(1, 1, 1, 0.25 + 0.45 * kk)
		if p["kind"] == "swing":
			var r: Rect2 = p["rect"]
			tb.rect(Rect2(r.position, Vector2(r.size.x, 1.5)), col)
			tb.rect(Rect2(r.position + Vector2(0, r.size.y - 1.5), Vector2(r.size.x, 1.5)), col)
			tb.rect(Rect2(r.position, Vector2(1.5, r.size.y)), col)
			tb.rect(Rect2(r.position + Vector2(r.size.x - 1.5, 0), Vector2(1.5, r.size.y)), col)
		else:
			var a: Vector2 = p["pos"]
			var v: Vector2 = (p["vel"] as Vector2) * float(TUNE["shot_speed"])
			var b := _shot_end(a, v, float(p["life"]) / float(TUNE["shot_speed"]))
			HK.dashed(tb, PackedVector2Array([a, b]), 3.0, Color(HK.OUTLINE, 0.5), 6.0, 5.0)
			HK.dashed(tb, PackedVector2Array([a, b]), 1.4, col, 6.0, 5.0)
	# The copies striking now: dark shapes with a pale edge.
	for sw in swings:
		var r: Rect2 = sw["rect"]
		tb.rect(r, Color(0.08, 0.06, 0.12, 0.55))
		tb.rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(HK.RIM, 0.9))
		tb.rect(Rect2(r.position + Vector2(0, r.size.y - 2.0), Vector2(r.size.x, 2.0)), Color(HK.RIM, 0.9))
	for es in echo_shots:
		var p: Vector2 = es["pos"]
		tb.circle(p, 6.0, Color(HK.RIM, 0.3), 10)
		tb.circle(p, 3.5, Color(0.08, 0.06, 0.12, 0.95), 10)
		tb.ring(p, 3.5, 1.2, Color(HK.RIM, 0.9), 10)
	if alive:
		# Two white slit eyes, always.
		var ew := float(TUNE["eye_w"])
		var eh := float(TUNE["eye_h"])
		for e in w6_eyes():
			tb.ellipse(e, ew * 2.4, eh * 3.0, Color(1, 1, 1, 0.2), 12)
			tb.ellipse(e, ew, eh, Color(1, 1, 1, HK.EYE_A), 10)
		# A flame that burns dark: a violet-black teardrop, white-rimmed.
		var fp := flame_point()
		var h := 13.0 + sin(t * 9.0) * 1.2
		var sway := sin(t * 5.0) * 1.2
		var tear := PackedVector2Array()
		for i in 9:
			var a := PI * i / 8.0
			tear.append(fp + Vector2(cos(a) * 3.6, -3.6 + sin(a) * 3.6))
		tear.append(fp + Vector2(-2.9, -h * 0.55))
		tear.append(fp + Vector2(sway, -h))
		tear.append(fp + Vector2(2.9, -h * 0.55))
		tb.convex(HK.grow(tear, 1.4), Color(1, 1, 1, 0.8 * maxf(seen, 0.5)))
		tb.convex(tear, Color(0.12, 0.06, 0.2, 0.95))
	tb.flush(glow)


func _shot_end(a: Vector2, v: Vector2, life: float) -> Vector2:
	var p := a
	var n := int(life / 0.02)
	for i in n:
		var q := p + v * 0.02
		if solid_at(q):
			break
		p = q
	return p
