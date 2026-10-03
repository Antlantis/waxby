extends "res://scripts/elites.gd"
## Hushling `n` (World 6 fodder, in packs; spec §4.5): a small blob of living
## dark that drips upward like smoke, two round pale eyes, a mouth that is
## only a curved line. The W6 rules (hush_kind.gd): seen only in light, eyes
## always drawn, a silver rim, silent until within 90 px.
##   idle     blinks and sways
##   creep    Wick within `sense`: toward him at `creep` px/s along its floor
##   crouch   within `crouch_range` (the tell): eyes widen, pupils pinprick,
##            the body stretches tall
##   lunge    a hop onto where he stood as the tell began (vy `lunge_vy`, g
##            `lunge_g`: 0.4 s in the air, its vx whatever lands it there, at
##            most `lunge_vx`; a pale mark shows the spot through the crouch):
##            `lunge` damage and the hushed status (hush_kind.hush_player).
##            Stepping off the marked spot is the escape
##   blink    `blink` s after, eyes shut: harmless and open to hits
## Light-shy: a Hushling never steps into a haven (hush_kind.haven_at:
## lanterns, braziers, Beacons, buoy tolls, lit altars, relit Vigil candles)
## and never lunges at a spot inside one; one caught in a light that comes on
## slinks out. Wick's own candle draws them in. Numbers: TUNE.
##
## Packs: 2-3 on Dusk (Build 1: Dusk pushes back from World 3), 3-5 on
## Nightfall and Witching (the first of each placed pack brings the rest,
## and brings them back up to size after every relight where the World
## respawns the placed ones; an Anointed first brings them too). A
## challenge mode's Dusk keeps v3's: none (MODE_PACKS).
## Witching: they lunge twice. The 6-1 Dread is the Hush-a-Bye, one at x1.8.

const HK := preload("res://scripts/hush_kind.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TUNE := {
	"life": 14.0, "lunge": 30.0, "touch": 26.0, "embers": 2, "item": 0.07,
	"sense": 180.0, "creep": 70.0,
	"same_floor": 40.0,           # px: Wick this near its feet's height is on its floor
	"stop_short": 12.0,           # px: it creeps no closer than this
	"crouch_range": 90.0,
	"crouch": 0.45, "crouch_floor": 0.30,
	"lunge_vx": 300.0, "lunge_vy": -250.0, "lunge_g": 1250.0,
	"blink": 0.6,
	"again": 0.4,                 # after the blink, before it can crouch again
	"pack_min": {"dusk": 2, "nightfall": 3, "witching": 3},
	"pack_max": {"dusk": 3, "nightfall": 5, "witching": 5},
	"pack_tiles": 4,              # Hushlings this close (in tiles, on one floor) are a pack
	"lunges": {"dusk": 1, "nightfall": 1, "witching": 2},
	"again_reach": 1.5,           # x crouch_range: how far Witching's second lunge reaches for him
	"hit_blink": 0.5,             # x blink: a hit mid-crouch
	"pack_gap": 16.0,             # px between the pack's members
	"flee": 90.0,                 # px/s out of a light that came on round it
	"dread_scale": 1.8,           # the Hush-a-Bye
}
# A challenge mode (world.mode) keeps Dusk as it was before Build 1, whose
# Dusk packs were for the story levels: no packs. Nightfall and Witching
# keep TUNE's.
const MODE_PACKS := {"pack_min": {"dusk": 0}, "pack_max": {"dusk": 0}}
# Its blows at area 1 (TUNE's), for test_progression's share-cap scan (PR's ask).
const MOVES := {"lunge": TUNE["lunge"]}
const FRAMES := ["hushling_idle1", "hushling_idle2", "hushling_crouch", "hushling_lunge", "hushling_blink", "hushling_pop"]
const DARK := Color("16121e")

var state := "idle"             # idle, creep, crouch, lunge, blink
var timer := 0.0
var target := Vector2.ZERO      # where he stood as the crouch began
var move_id := ""
var seen := HK.DARK_A           # its alpha (W6 rule 1), eased
var lunges_done := 0
var _crouch_t := 0.45
var _cd := 0.0
var _packed := false
var pack_of := Vector2i(-1, -1) # an extra: the cell of the leader that brought it
var _snuffs := -1
var _hit_this_lunge := false
var _sway := 0.0
var _tb := TriBatch.new()


func _init() -> void:
	kind = "hushling"
	set("echo_by_body", false)     # MA's Echoing: its lunge is logged (strike_logged)
	set("lit_alpha_own", true)     # MA's Hushed Omen: its alpha is the W6 rule it already keeps (a no-op until elites.gd declares it)
	size = Vector2(18, 20)
	base_hp = float(TUNE["life"])
	base_dmg = float(TUNE["touch"])
	embers = int(TUNE["embers"])
	item_chance = float(TUNE["item"])


func k(n: String) -> float:
	return HK.pick(TUNE, HK.diff_of(self), n)


func pack_rule(n: String) -> int:
	## TUNE's pack_min / pack_max on this World's difficulty; in a mode, its
	## Dusk (or a difficulty that reads Dusk's) is MODE_PACKS' instead.
	var m = world.get("mode") if world != null else null
	if m != null and MODE_PACKS.has(n):
		var d := HK.diff_of(self)
		var key := d if (TUNE[n] as Dictionary).has(d) else "dusk"
		if (MODE_PACKS[n] as Dictionary).has(key):
			return int(MODE_PACKS[n][key])
	return int(k(n))


func _ready() -> void:
	if tier == "dread":
		scale_mult *= float(TUNE["dread_scale"])
	super()
	load_frames(FRAMES)
	show_frame("hushling_idle1")
	_sway = fposmod(position.x * 0.013, TAU)


func moves() -> Dictionary:
	return {"touch": float(TUNE["touch"]), "lunge": float(TUNE["lunge"])}


func dmg(what := "touch") -> float:
	if what == "lunge":
		return float(TUNE["lunge"]) * dmg_mult
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


func touch_damage() -> bool:
	## The lunge hurts through its own check (and hushes); blinking it's harmless.
	return state != "lunge" and state != "blink"


# ---------------------------------------------------------------- the step

func step(dt: float, player: Node2D) -> void:
	super(dt, player)
	seen = move_toward(seen, HK.lit_alpha(self) if alive else seen, dt * 6.0)
	HK.own_alpha(self, seen)


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_cd = maxf(_cd - dt, 0.0)
	if not _packed:
		_packed = true
		_snuffs = int(world.get("snuffs")) if world != null and world.get("snuffs") != null else -1
		_bring_pack()
	elif HK.relit(self):
		_bring_pack()
	var dx: float = player.position.x - position.x
	var same_floor: bool = absf(player.position.y - position.y) < float(TUNE["same_floor"])
	var near: bool = player.alive and absf(dx) < k("sense") and same_floor
	match state:
		"idle", "creep":
			if _in_haven():
				_slink(dt)
			elif near:
				facing = 1 if dx > 0.0 else -1
				if absf(dx) <= float(TUNE["crouch_range"]) and _cd <= 0.0 and player.on_floor and not HK.haven_at(world, player.position, size.x * 0.5):
					_start_crouch(player)
				else:
					state = "creep"
					var ahead := Vector2(position.x + facing * (size.x * 0.5 + 4.0), position.y - size.y * 0.5)
					if ground_ahead(facing) and not wall_ahead(facing) and not HK.haven_at(world, ahead, 0.0) and absf(dx) > float(TUNE["stop_short"]):
						velocity.x = facing * spd(float(TUNE["creep"]))
					else:
						velocity.x = 0.0
					_fall(dt)
			else:
				state = "idle"
				velocity.x = move_toward(velocity.x, 0.0, 400.0 * dt)
				_fall(dt)
			var bob := fmod(t + _sway, 0.9) < 0.45
			show_frame("hushling_idle1" if bob else "hushling_idle2")
		"crouch":
			velocity.x = 0.0
			_fall(dt)
			show_frame("hushling_crouch")
			if timer <= 0.0:
				_start_lunge()
		"lunge":
			show_frame("hushling_lunge")
			velocity.y = minf(velocity.y + float(TUNE["lunge_g"]) * dt, 600.0)
			move(dt)
			if not _hit_this_lunge and player.alive and hurt_rect().intersects(player.rect()):
				_hit_this_lunge = true
				if world.hurt_player(dmg("lunge"), position.x, "hit", self, {"move": "hushling:lunge"}):
					HK.hush_player(world)
			if on_floor and velocity.y >= 0.0 and timer <= 0.0:
				velocity.x = 0.0
				if lunges_done < int(k("lunges")) and player.alive and player.on_floor and not HK.haven_at(world, player.position, size.x * 0.5) \
						and absf(player.position.x - position.x) <= float(TUNE["crouch_range"]) * float(TUNE["again_reach"]):
					# Witching: straight into another crouch at where he is now.
					_start_crouch(player)
				else:
					state = "blink"
					timer = float(TUNE["blink"])
					move_id = ""
		"blink":
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * dt)
			_fall(dt)
			show_frame("hushling_blink")
			if timer <= 0.0:
				state = "idle"
				lunges_done = 0
				_cd = cd(float(TUNE["again"]))


func _fall(dt: float) -> void:
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)


func _in_haven() -> bool:
	return HK.haven_at(world, center(), -size.x * 0.25)


func _slink(dt: float) -> void:
	## A light came on round it: out of it, away from the nearest haven light.
	state = "idle"
	var best := Vector2.INF
	for l in world.gameplay_lights(true):
		var d := (l["p"] as Vector2).distance_to(center())
		if d < float(l.get("r", 0.0)) and (best == Vector2.INF or d < best.distance_to(center())):
			best = l["p"]
	var dir := 1.0 if best == Vector2.INF or center().x >= best.x else -1.0
	facing = int(dir)
	velocity.x = dir * float(TUNE["flee"]) if ground_ahead(facing) and not wall_ahead(facing) else 0.0
	_fall(dt)


func _start_crouch(player: Node2D) -> void:
	state = "crouch"
	_crouch_t = tell(float(TUNE["crouch"]), float(TUNE["crouch_floor"]))
	timer = _crouch_t
	target = player.position
	facing = 1 if target.x > position.x else -1
	velocity.x = 0.0
	move_id = "hushling:lunge"


func lunge_time() -> float:
	## The hop's time in the air, floor to floor.
	return 2.0 * absf(float(TUNE["lunge_vy"])) / maxf(float(TUNE["lunge_g"]), 1.0)


func _start_lunge() -> void:
	state = "lunge"
	lunges_done += 1
	_hit_this_lunge = false
	if absf(target.x - position.x) > 0.5:
		facing = 1 if target.x > position.x else -1
	# Onto the spot: the vx that lands it there, capped at lunge_vx.
	var cap := float(TUNE["lunge_vx"])
	var vx := clampf((target.x - position.x) / lunge_time(), -cap, cap)
	velocity = Vector2(vx, float(TUNE["lunge_vy"]))
	on_floor = false
	timer = 0.05
	strike_logged(Rect2(target - Vector2(size.x * 0.5, size.y), size), dmg("lunge"))
	sfx("hush_pop", "wisp_pop", 1.6)


func _bring_pack() -> void:
	## The first Hushling of each placed pack (the leftmost within
	## pack_tiles on its floor) brings the pack up to pack_min-pack_max (2-3
	## on Dusk, 3-5 deeper; none on a mode's Dusk: pack_rule): on its first
	## think, and again after each relight (HK.relit), counting the extras it
	## brought that still live, so a pack is never bigger than the rule. A
	## Dread or a Warden (a one-off) brings none.
	var lo := pack_rule("pack_min")
	if lo <= 0 or copy or tier == "dread" or tier == "warden" or world == null or pack_of.x >= 0:
		return
	var cell: Vector2i = spawn.get("cell", Vector2i(-1, -1))
	if cell.x < 0 or level == null:
		return
	var pack := 1
	for e in level.entities:
		if e["kind"] != "hushling" or e["cell"] == cell:
			continue
		var c: Vector2i = e["cell"]
		if absi(c.y - cell.y) <= 1 and absi(c.x - cell.x) <= int(TUNE["pack_tiles"]):
			if c.x < cell.x:
				return   # not the pack's first
			pack += 1
	var hi := pack_rule("pack_max")
	var want := lo + posmod(hash(cell), hi - lo + 1)
	var have := HK.pack_count(world, kind, cell)
	var again := have > 0 or respawned or t > 0.1   # topping up after a snuff: they come back as respawns do
	for i in range(pack + have, want):
		var dx := (i - pack + 1) * -float(TUNE["pack_gap"]) * float(facing if facing != 0 else 1)
		var at := Vector2(position.x + dx, position.y)
		if solid_at(at + Vector2(0, -8)) or not (solid_at(at + Vector2(0, 4)) or _ledge_at(at + Vector2(0, 4))):
			at = Vector2(position.x - dx, position.y)
			if solid_at(at + Vector2(0, -8)) or not (solid_at(at + Vector2(0, 4)) or _ledge_at(at + Vector2(0, 4))):
				continue
		var m: Node2D = world.spawn_enemy(kind, at, {"facing": facing, "respawned": again})
		if m:
			m.set("_packed", true)
			m.set("pack_of", cell)
			m.active = active


func _ledge_at(p: Vector2) -> bool:
	return LevelData.is_ledge(level.tile(floori(p.x / TILE), floori(p.y / TILE)))


func _hurt(h: Dictionary) -> void:
	super(h)
	if state == "crouch":
		state = "blink"
		timer = float(TUNE["blink"]) * float(TUNE["hit_blink"])
		move_id = ""


func _kill(h: Dictionary) -> void:
	super(h)
	show_frame("hushling_pop")
	velocity = Vector2.ZERO
	if world != null and world.glow:
		world.glow.burst(center(), 10, Color(0.55, 0.5, 0.75, 0.8), 90.0, 0.5, -60.0, 2.6)
	sfx("hush_pop", "wisp_pop")


func _dying(dt: float) -> void:
	# It pops out of existence: a puff of dark rising.
	show_frame("hushling_pop")
	squash = 1.0 + death_time * 1.5
	fade = clampf(1.0 - death_time * 3.0, 0.0, 1.0)
	if death_time > 0.4:
		gone = true


func eye_points() -> Array:
	## What the World lights (8 a screen): an elite's only, as v2's kinds.
	return w6_eyes() if tier != "" else []


func w6_eyes() -> Array:
	## Two round pale eyes, always (W6 rule 1): wide during the crouch.
	var eyes := HK.frame_eyes(frame_name)
	if not frames.is_empty() and not eyes.is_empty():
		var out := []
		for p in eyes:
			out.append(frame_point(p))
		return out
	var s := scale_mult
	var tall := 1.0
	if state == "crouch":
		tall = 1.25
	var c := position + Vector2(facing * 2.0, -12.0 * tall) * s
	return [c + Vector2(-3.5, 0) * s, c + Vector2(3.5, 0) * s]


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := _tb
	var shut := state == "blink"
	var wide := state == "crouch"
	if shut:
		# Eyes shut: two pale slits, still there.
		for p in w6_eyes():
			tb.line(p + Vector2(-2.5, 0), p + Vector2(2.5, 0), 1.6, Color(HK.EYE, 0.9))
	else:
		HK.draw_eyes(self, glow, tb, HK.EYE_R + (1.2 if wide else 0.0))
		if wide:
			# Pupils shrink to pinpricks: the tell.
			for p in w6_eyes():
				tb.circle(p, 0.9, Color("16121e"), 6)
			var kk := 1.0 - clampf(timer / maxf(_crouch_t, 0.01), 0.0, 1.0)
			tb.ring(center() + Vector2(0, -2), (size.x * 0.7) * (1.3 - 0.3 * kk), 1.4 + 1.2 * kk, Color(HK.RIM, 0.35 + 0.5 * kk), 16)
			# Where it will land: a pale ring on the floor at the spot he stood.
			var mark := HK.ellipse_pts(target + Vector2(0, -1.5), size.x * 0.5 * scale_mult + 3.0, 3.5, 16)
			tb.polyline(mark, 3.0, Color(HK.OUTLINE, 0.5), true)
			tb.polyline(mark, 1.6, Color(HK.RIM, 0.35 + 0.5 * kk), true)
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var s := scale_mult
	var tall := squash
	var sway := sin(t * 3.0 + _sway) * 1.2
	if state == "crouch":
		var kk := 1.0 - clampf(timer / maxf(_crouch_t, 0.01), 0.0, 1.0)
		tall *= 1.0 + 0.3 * kk
	elif state == "lunge":
		tall *= 0.85
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s * facing, s))
	var tb := _tb
	var a := clampf(fade, 0.0, 1.0) * seen
	var rim := Color(HK.RIM, a)
	var body := _c(HK.BODY, a)
	# A blob that drips upward: a round base and a wisp of smoke above it,
	# rimmed in silver (W6 rule: 2 px).
	var base_c := Vector2(0, -6.0 * tall)
	var puff := Vector2(-1.5 + sway, -12.5 * tall)
	var wisp := PackedVector2Array([Vector2(-5, -12 * tall), Vector2(1 + sway * 1.5, -22 * tall), Vector2(5, -12 * tall)])
	# The rim first (every shape grown by 2 px), then the body over it.
	tb.ellipse(base_c, 9.0 + HK.RIM_PX, 6.5 * tall + HK.RIM_PX, rim, 16)
	tb.ellipse(puff, 5.5 + HK.RIM_PX, 5.0 * tall + HK.RIM_PX, rim, 12)
	tb.convex(HK.grow(wisp, HK.RIM_PX), rim)
	tb.ellipse(base_c, 9.0, 6.5 * tall, body, 16)
	tb.ellipse(puff, 5.5, 5.0 * tall, body, 12)
	tb.convex(wisp, body)
	# The mouth: only a curved line.
	if state != "blink":
		var mc := Vector2(2.0, -6.5 * tall)
		var m := PackedVector2Array()
		for i in 5:
			var u := float(i) / 4.0
			m.append(mc + Vector2(lerpf(-3.0, 3.0, u), sin(u * PI) * (1.2 if state != "crouch" else -0.8)))
		tb.polyline(m, 1.0, Color(HK.EYE, 0.5 * a))
	tb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _c(col: Color, a := 1.0) -> Color:
	return HK.shade(self, col, a)
