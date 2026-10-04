extends "res://scripts/elites.gd"
## Glassmite `x` (World 5 fodder, spec §4.5): a beetle of stained glass,
## tinted red, blue or gold by its cell. It skitters along glass and stone.
## When Wick stands on the same glass platform within `sense` px it stops
## and gnaws (the tell): a crack spreads from it toward his feet, glinting
## on every tile that will go; `crack_delay` later the glass tiles along the
## crack (up to `crack_tiles`, ending under his feet as the tell began) break
## through world.features.break_glass and reform on the glass rule (glass.gd's
## own timer). Only glass breaks: stone never does, and it never gnaws the
## tile under itself. It bites on touch; a stomp kills it. A Gustling's gust
## pushes it (actor push, braked at edges). Numbers: TUNE (provisional until
## the W3 playtest).
##
## Nightfall: a 0.50 s gnaw (the tell multiplier) and 4 tiles. Witching:
## trios (each placed one, an Anointed too, brings two more, and brings them
## back after every relight as the World respawns it). The 5-1 Dread Queen
## Crackle is one at x1.6. placement_problems() checks a level against the
## spec's rule: never glass over the void without solid footing in a jump.

const HK := preload("res://scripts/hush_kind.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TUNE := {
	"life": 14.0, "touch": 24.0, "embers": 2, "item": 0.07,
	"speed": 80.0,
	"sense": 160.0,               # px: Wick on its glass platform this close
	"same_floor": 4.0,            # px: his feet this near its own height (the same floor row)
	"gnaw": 0.60, "gnaw_floor": 0.40,   # the tell (x the difficulty's tell multiplier)
	"crack_delay": 0.40,          # then the crack's glass breaks
	"crack_tiles": {"dusk": 3, "nightfall": 4, "witching": 4},
	"again": 1.6,                 # s before it gnaws again
	"after_break": 0.3,           # s it rests once the crack gives
	"hit_again": 0.5,             # x again after a hit breaks off a gnaw
	"pack": {"dusk": 1, "nightfall": 1, "witching": 3},
	"dread_scale": 1.6,           # Queen Crackle
	"stun_hit": 0.25,             # a hit that doesn't kill it breaks off a gnaw
	"pack_gap": 14.0,             # px between a Witching trio's mites
	# placement (spec §4.5): glass it can crack must have a floor under it or
	# solid footing (not glass) within one jump
	"jump_tiles": 4,              # columns either way
	"jump_up": 2, "jump_down": 3, # rows up and down
}
const GLASS_COLS := [Color("d8584a"), Color("4a7ad8"), Color("e8c04a")]
const FRAMES := ["mite_walk1", "mite_walk2", "mite_gnaw", "mite_hit"]
const LEAD := Color("2a2436")

var state := "walk"             # walk, gnaw, crack, rest
var timer := 0.0
var glass_col := GLASS_COLS[0]
var crack: Array[Vector2i] = [] # the tiles that will break (glass or not; only glass does)
var crack_from := Vector2.ZERO  # the crack line, from the mite...
var crack_to := Vector2.ZERO    # ...to his feet as the tell began
var move_id := ""
var _cool := 0.0
var _walk := 0.0
var _gnaw_t := 0.0              # the tell's length (for its drawing)
var _packed := false
var pack_of := Vector2i(-1, -1) # a trio's extra: the cell of the mite that brought it
var _snuffs := -1
var _tb := TriBatch.new()


func _init() -> void:
	kind = "glassmite"
	size = Vector2(20, 20)          # drawn 20 x 14; SHOT_LINE keeps the box 20 tall
	base_hp = float(TUNE["life"])
	base_dmg = float(TUNE["touch"])
	embers = int(TUNE["embers"])
	item_chance = float(TUNE["item"])


func k(n: String) -> float:
	return HK.pick(TUNE, HK.behave_of(self), n)


func _ready() -> void:
	if tier == "dread":
		scale_mult *= float(TUNE["dread_scale"])
	super()
	load_frames(FRAMES)
	show_frame("mite_walk1")
	var cell: Vector2i = spawn.get("cell", Vector2i(floori(position.x / TILE), floori(position.y / TILE)))
	glass_col = GLASS_COLS[posmod(hash(cell), GLASS_COLS.size())]
	if tier == "":
		tint = Color.WHITE.lerp(glass_col, 0.55)


func moves() -> Dictionary:
	## Base damage per move (area 1, Dusk; the share-cap scan reads it).
	return {"touch": float(TUNE["touch"])}


func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_cool = maxf(_cool - dt, 0.0)
	if not _packed:
		_packed = true
		_snuffs = int(world.get("snuffs")) if world != null and world.get("snuffs") != null else -1
		_bring_pack()
	elif HK.relit(self):
		_bring_pack()
	match state:
		"walk", "rest":
			if state == "rest" and timer <= 0.0:
				state = "walk"
			walk(dt, spd(float(TUNE["speed"])))
			_walk += dt * spd(1.0)
			show_frame("mite_walk1" if fmod(_walk, 0.24) < 0.12 else "mite_walk2")
			if state == "walk" and _cool <= 0.0 and can_gnaw(player) and not crack_cells(player.position.x).is_empty():
				_start_gnaw(player)
		"gnaw":
			_stand(dt)
			show_frame("mite_gnaw")
			if timer <= 0.0:
				state = "crack"
				timer = float(TUNE["crack_delay"])
				sfx("glass_crack", "block_break", 1.3)
		"crack":
			_stand(dt)
			show_frame("mite_gnaw")
			if timer <= 0.0:
				_break()
	push = Vector2.ZERO
	if level != null and position.y > level.height * TILE + 64.0:
		# Down through a broken pane into the void.
		hp = 0.0
		_kill({"how": "pit", "from_x": position.x})


func _stand(dt: float) -> void:
	velocity.x = 0.0
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)


func _bring_pack() -> void:
	## Witching's trios: a placed Glassmite (an Anointed too; not a copy, a
	## Dread, a Warden or a trio's extra) brings two more, just behind it:
	## on its first think, and after each relight (HK.relit) back up to
	## size, counting the extras still alive (never more than a trio).
	var n := int(k("pack"))
	var cell: Vector2i = spawn.get("cell", Vector2i(-1, -1))
	if n <= 1 or copy or tier == "dread" or tier == "warden" or pack_of.x >= 0 or world == null or not world.has_method("spawn_enemy") or cell.x < 0:
		return
	var have := HK.pack_count(world, kind, cell)
	var again := have > 0 or respawned or t > 0.1
	for i in range(1 + have, n):
		var dx := (-1.0 if i % 2 == 1 else 1.0) * float(TUNE["pack_gap"]) * ceilf(i / 2.0)
		var at := Vector2(position.x + dx, position.y)
		if solid_at(at + Vector2(0, -8)) or not solid_at(at + Vector2(0, 4)):
			continue
		var m: Node2D = world.spawn_enemy(kind, at, {"facing": facing, "respawned": again})
		if m:
			m.set("_packed", true)
			m.set("pack_of", cell)
			m.active = active


func can_gnaw(player: Node2D) -> bool:
	## Wick standing on glass on the same platform (the same floor row, no
	## gap between them) within `sense`.
	if player == null or not player.alive or not player.on_floor or not on_floor or level == null:
		return false
	if absf(player.position.y - position.y) > float(TUNE["same_floor"]) or absf(player.position.x - position.x) > k("sense"):
		return false
	var fy := floori((position.y + 1.0) / TILE)
	var px := floori(player.position.x / TILE)
	if level.tile(px, fy) != LevelData.GLASS:
		return false
	var mx := floori(position.x / TILE)
	for x in range(mini(mx, px), maxi(mx, px) + 1):
		var t: int = level.tile(x, fy)
		if not (LevelData.is_solid(t) or LevelData.is_ledge(t)):
			return false
	return true


func crack_cells(player_x: float) -> Array[Vector2i]:
	## The tiles the crack runs through: up to crack_tiles of them, ending
	## under his feet and running back toward the mite (never its own tile).
	var out: Array[Vector2i] = []
	var fy := floori((position.y + 1.0) / TILE)
	var mx := floori(position.x / TILE)
	var tx := floori(player_x / TILE)
	if tx == mx:
		return out
	var dir := 1 if tx > mx else -1
	var n := int(k("crack_tiles"))
	var x := tx
	while out.size() < n and x != mx:
		out.append(Vector2i(x, fy))
		x -= dir
	return out


func _start_gnaw(player: Node2D) -> void:
	state = "gnaw"
	_gnaw_t = tell(float(TUNE["gnaw"]), float(TUNE["gnaw_floor"]))
	timer = _gnaw_t
	facing = 1 if player.position.x > position.x else -1
	velocity.x = 0.0
	crack = crack_cells(player.position.x)
	crack_from = Vector2(position.x + facing * size.x * 0.5, position.y)
	crack_to = Vector2(player.position.x, position.y)
	move_id = "glassmite:gnaw"
	tell_sfx("glass_tink", timer, "relic_common")


func _break() -> void:
	## The crack gives: every glass tile along it breaks (glass.gd: a flash,
	## air, a reform on its own timer). Stone stays.
	var feats = world.features if world != null else null
	for c in crack:
		if level.tile(c.x, c.y) == LevelData.GLASS and feats != null and feats.has_method("break_glass"):
			feats.break_glass(c)
	if world != null and world.glow:
		for c in crack:
			world.glow.burst(Vector2((c.x + 0.5) * TILE, c.y * TILE), 5, glass_col.lightened(0.3), 90.0, 0.35, 400.0, 2.0)
	sfx("glass_break", "block_break")
	crack.clear()
	state = "rest"
	timer = float(TUNE["after_break"])
	_cool = cd(float(TUNE["again"]))
	move_id = ""


func _hurt(h: Dictionary) -> void:
	super(h)
	if state == "gnaw" or state == "crack":
		# Knocked off its gnaw: the crack stops where it was.
		crack.clear()
		state = "rest"
		timer = float(TUNE["stun_hit"])
		_cool = cd(float(TUNE["again"])) * float(TUNE["hit_again"])
		move_id = ""
	show_frame("mite_hit")


func _kill(h: Dictionary) -> void:
	crack.clear()
	super(h)
	show_frame("mite_hit")
	if world != null and world.glow:
		world.glow.burst(center(), 12, glass_col.lightened(0.25), 160.0, 0.45, 500.0, 2.2)
	if str(h.get("how", "")) == "stomp":
		velocity = Vector2.ZERO


func _dying(dt: float) -> void:
	# It shatters where it stood, the pieces fading.
	if velocity == Vector2.ZERO:
		squash = maxf(0.2, 1.0 - death_time * 3.0)
		fade = clampf(1.0 - death_time * 2.2, 0.0, 1.0)
		if death_time > 0.5:
			gone = true
	else:
		super(dt)


func eye_points() -> Array:
	## An elite's glints (two prism eyes on the head).
	if tier == "":
		return []
	var fb := [position + Vector2(facing * 10.0, -8.0) * scale_mult, position + Vector2(facing * 8.0, -8.5) * scale_mult]
	var eyes := HK.frame_eyes(frame_name)
	if eyes.is_empty():
		return fb
	var out := []
	for p in eyes:
		out.append(frame_point(p))
	return out


# ---------------------------------------------------------------- placement

static func placement_problems(lv: RefCounted) -> Array:
	## Spec §4.5: a Glassmite is never on a platform that is the only way
	## forward over the void unless solid footing is within one jump. Checked
	## strictly: every glass tile of its platform within `sense` of it (what
	## its crack can reach) must have a floor somewhere under it (a fall onto
	## it, not the void, a pit, deep water, lava or spikes), or footing that
	## isn't glass (solid or a ledge, air over it) within jump_tiles columns
	## and jump_up / jump_down rows. ["x,y: ..."]; an empty list is a pass.
	var out := []
	var LD = LevelData
	var reach := int(ceilf(float(TUNE["sense"]) / 32.0))
	var jx := int(TUNE["jump_tiles"])
	for e in lv.entities:
		if e["kind"] != "glassmite":
			continue
		var c: Vector2i = e["cell"]
		var fy := c.y + 1
		for dir in [-1, 1]:
			for i in range(0, reach + 1):
				var x: int = c.x + dir * i
				var tt: int = lv.tile(x, fy)
				if not (LD.is_solid(tt) or LD.is_ledge(tt)):
					break   # the platform ends
				if tt != LD.GLASS or i == 0:
					continue   # stone never breaks, nor the tile under the mite
				if _floor_under(lv, x, fy):
					continue
				var safe := false
				for dy in range(-int(TUNE["jump_up"]), int(TUNE["jump_down"]) + 1):
					for dx in range(-jx, jx + 1):
						var ft: int = lv.tile(x + dx, fy + dy)
						if ft != LD.GLASS and (LD.is_solid(ft) or LD.is_ledge(ft)) and not LD.is_solid(lv.tile(x + dx, fy + dy - 1)):
							safe = true
							break
					if safe:
						break
				if not safe:
					out.append("%d,%d: the glass at column %d is over the void with no footing but glass within a jump" % [c.x, c.y, x])
	return out


static func _floor_under(lv: RefCounted, x: int, fy: int) -> bool:
	## Something to land on under a broken pane: a floor before the bottom,
	## a pit, deep water, lava or spikes.
	var LD = LevelData
	for y in range(fy + 1, lv.height):
		var t: int = lv.tile(x, y)
		if t == LD.LAVA or t == LD.SPIKES_UP:
			return false
		if t == LD.WATER:
			return not lv.is_deep(x, y)
		if LD.is_solid(t) or LD.is_ledge(t):
			return true
	return false


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := _tb
	# Two tiny prism eyes glint over the dark (so a mite is never unseen).
	var f := float(facing)
	var hc := position + Vector2(f * 10.5, -8.0 + (2.0 if state == "gnaw" else 0.0)) * scale_mult
	tb.circle(hc + Vector2(f * 1.2, -0.6), 1.6 * scale_mult, Color(0.85, 0.97, 1.0, 0.9), 8)
	tb.circle(hc + Vector2(-f * 1.0, -1.0), 1.3 * scale_mult, Color(glass_col.lightened(0.5), 0.85), 8)
	if crack.is_empty() and state != "gnaw":
		tb.flush(glow)
		return
	var total := _gnaw_t + float(TUNE["crack_delay"])
	var left := timer + (float(TUNE["crack_delay"]) if state == "gnaw" else 0.0)
	var kk := clampf(1.0 - left / maxf(total, 0.01), 0.0, 1.0)
	var y := crack_from.y + 1.0
	# The crack line: jagged, spreading from the mite to his feet over the tell.
	var reach := minf(kk / maxf(_gnaw_t / total, 0.01), 1.0)
	var end_x := lerpf(crack_from.x, crack_to.x, reach)
	var pts := PackedVector2Array()
	var n := maxi(int(absf(end_x - crack_from.x) / 5.0), 1)
	for i in n + 1:
		var x := lerpf(crack_from.x, end_x, float(i) / n)
		# A crack's zigzag, fixed by x (it doesn't crawl as it spreads).
		var j := fposmod(sin(floorf(x / 5.0) * 12.9898) * 43758.5453, 1.0)
		pts.append(Vector2(x, y + 1.0 + j * 5.0))
	var flick := 0.6 + 0.4 * absf(sin(t * 22.0))
	tb.polyline(pts, 3.2, Color(0.1, 0.1, 0.16, 0.5))
	tb.polyline(pts, 1.8, Color(1, 1, 1, 0.9 * flick))
	# Little branches off the crack.
	for i in range(2, pts.size() - 1, 3):
		var q: Vector2 = pts[i]
		tb.line(q, q + Vector2(3.0 * (1.0 if i % 2 == 0 else -1.0), 5.0 + fmod(i * 1.7, 3.0)), 1.2, Color(1, 1, 1, 0.7 * flick))
	# Every tile that will go glints along its top, brighter as it nears.
	for c in crack:
		if level.tile(c.x, c.y) != LevelData.GLASS:
			continue
		var at := Vector2(c.x * TILE, c.y * TILE)
		var a := 0.35 + 0.6 * kk
		tb.rect(Rect2(at + Vector2(1, 0), Vector2(TILE - 2, 3)), Color(1, 1, 1, a * flick))
		tb.line(at + Vector2(6, 2), at + Vector2(12, 12 + 6 * kk), 1.6, Color(1, 1, 1, a))
		tb.line(at + Vector2(22, 2), at + Vector2(17, 10 + 8 * kk), 1.6, Color(1, 1, 1, a))
		if state == "crack":
			tb.rect(Rect2(at, Vector2(TILE, TILE)), Color(glass_col.lightened(0.5), 0.18 + 0.2 * flick))
	# The tapping head: a bright tick at each tap.
	if state == "gnaw" and fmod(t, 0.16) < 0.06:
		tb.circle(crack_from + Vector2(0, -2), 3.0, Color(1, 1, 1, 0.9), 8)
	tb.flush(glow)


func _draw() -> void:
	if not frames.is_empty():
		return
	var s := scale_mult
	var f := float(facing)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s * f, s))
	var tb := _tb
	var a := clampf(fade, 0.0, 1.0)
	var lead := _c(LEAD, a)
	var sq := squash
	var bob := 0.0 if state != "walk" else -absf(sin(_walk * TAU / 0.24)) * 0.8
	var head_dip := 0.0
	if state == "gnaw":
		head_dip = 2.0 + (1.5 if fmod(t, 0.16) < 0.08 else 0.0)
	# Six needle legs (three a side, the far ones darker), splayed out
	# from under the shell to the glass.
	var ph := _walk * TAU / 0.24
	for i in 3:
		var x0 := -6.0 + i * 6.0
		var sw := sin(ph + i * 2.1) * 2.0 if state == "walk" else 0.0
		var knee := Vector2(x0 + (i - 1) * 3.0, -7.0 * sq + bob)
		tb.line(Vector2(x0, -4.0 * sq + bob), knee + Vector2(-2.0, -2.0), 1.4, _c(Color("7a7a98"), a * 0.8))
		tb.line(knee + Vector2(-2.0, -2.0), Vector2(x0 - 4.0 + (i - 1) * 3.0 + sw, 0), 1.4, _c(Color("7a7a98"), a * 0.8))
		tb.line(Vector2(x0 + 1.0, -4.0 * sq + bob), knee + Vector2(2.0, -2.5), 1.7, _c(Color("c8cce8"), a))
		tb.line(knee + Vector2(2.0, -2.5), Vector2(x0 + 4.0 + (i - 1) * 3.0 - sw, 0), 1.7, _c(Color("c8cce8"), a))
	# The head, down to the glass when it gnaws.
	var hc := Vector2(9.5, -7.0 * sq + bob + head_dip)
	HK.o_ellipse(tb, hc, 4.2, 3.6, _c(LEAD.lightened(0.2), a), 1.2, lead)
	tb.circle(hc + Vector2(1.8, -0.8), 1.3, _c(Color("e8fbff"), a), 8)
	tb.circle(hc + Vector2(-0.4, -1.4), 1.0, _c(Color("bfe8ff"), a), 8)
	# The shell: coloured panes held in lead.
	var sc := Vector2(-1.0, -10.0 * sq + bob)
	HK.o_ellipse(tb, sc, 10.5, 6.2 * sq, _c(Color(0.94, 0.94, 0.96), a), 1.8, lead)
	HK.o_ellipse(tb, sc + Vector2(0, 0.5), 9.0, 5.0 * sq, _c(Color(1.0, 1.0, 1.0, 0.9), a))
	tb.line(sc + Vector2(0, -6.5 * sq), sc + Vector2(0, 6.0 * sq), 1.6, lead)
	tb.line(sc + Vector2(-9, 1), sc + Vector2(9, -2), 1.4, lead)
	tb.line(sc + Vector2(-4, -5 * sq), sc + Vector2(-6, 5 * sq), 1.2, lead)
	tb.line(sc + Vector2(5, -5 * sq), sc + Vector2(6, 5 * sq), 1.2, lead)
	tb.ellipse(sc + Vector2(-4.5, -3.2 * sq), 3.0, 1.4, Color(1, 1, 1, 0.55 * a), 10)
	tb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _c(col: Color, a := 1.0) -> Color:
	return HK.shade(self, col, a)
