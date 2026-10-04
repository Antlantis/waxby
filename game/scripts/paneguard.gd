extends "res://scripts/elites.gd"
## Paneguard `l` (World 5, a heavy; spec §4.5): a tall stained-glass knight
## stepped out of a window. Face-on it is glass: every hit clangs (hit()
## returns false and a "Blocked" floater shows), shots break on it, a stomp
## bounces Wick off harmlessly; the Bellfounder's maul cracks 30% through. It
## gives off coloured light face-on. Edge-on it is lead: full damage, and a
## stomp 1.5x.
##   advance       face-on toward Wick at `advance` px/s
##   turn (tell)   within `lunge_range`: a glint runs up its lead, the halo flares
##   lunge         edge-first `lunge_dist` px at `lunge_speed`: an 8 px slicing box (jump it)
##   edge_recover  edge-on, still, wobbling: the window (`recover` s, never shorter)
##   face          turning back face-on (`face` s)
## Glass Cut instead within `cut_range`: a coloured arc drawn for its tell
## (`cut_tell`, floor `cut_floor`: the escape formula for a 60 px arc), then
## a `cut_w` x `cut_h` arc in front for `cut` damage, then `cut_recover` s
## still face-on. The cut breaks the panes it marks from the tell's start
## (glinting): the floor's glass under the arc, never the tile it stands on,
## none reaching more than `cut_spill` px past the arc, so a Wick out of the
## arc keeps his footing. The arc stops at walls, and it never turns or cuts
## at him through one (clear_to). A Perfect Guard on the lunge stalls it
## edge-on for `pg_edge` s. It stands on stone (the level's rule). Numbers: TUNE.
##
## Nightfall: the lunge runs 150 px. Witching: after the lunge it turns
## (0.35 s, floor 0.35) and lunges back. Three tints, by its cell. (5-3's
## Dread, Dame Vitrail, is a Rattle knight since WL5's round 3: a Dread
## Paneguard's lunge breaks the 45% cap there; its Paneguards stand plain.)

const HK := preload("res://scripts/hush_kind.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TUNE := {
	"life": 55.0, "lunge": 36.0, "cut": 34.0, "touch": 26.0, "poise": 0.5,
	"embers": 6, "item": 0.16, "relic": 0.04,
	"see": 240.0, "advance": 40.0,
	"see_dy": 56.0,                               # px: Wick this near its floor's height
	"sight_y": 20.0,                              # px over its feet: the line it sees him along (walls block it)
	"turn": 0.45, "turn_floor": 0.40,             # a jump tell
	"turn_back": 0.35, "turn_back_floor": 0.35,   # Witching's turn after the lunge
	"lunge_range": 140.0,
	"lunge_dist": {"dusk": 120.0, "nightfall": 150.0, "witching": 150.0},
	"lunge_speed": 360.0,
	"lunge_box": 8.0,                             # the slicing box's width (and its body edge-on)
	"recover": 1.0,                               # edge-on and still: the window
	"face": 0.3,
	"cut_range": 50.0,
	"cut_tell": 0.70, "cut_floor": 0.50,
	"cut_w": 60.0, "cut_h": 40.0, "cut_active": 0.12,
	"cut_recover": 0.6,
	"cut_spill": 10.0,                            # px a breaking tile may reach past the arc (half his width:
	                                              # out of the arc, he keeps his footing)
	"cut_again": 0.5,                             # x again after a cut
	"pg_edge": 1.5,                               # a Perfect Guard on the lunge
	"maul_through": 0.3,
	"stomp_edge": 1.5,
	"light_r": 60.0, "light_s": 0.5,
	"back_lunge": {"dusk": 0, "nightfall": 0, "witching": 1},
	"again": 1.0,                                 # before it can turn again
	"face_w": 30.0, "tall": 44.0,
	"knock": 40.0,                # px/s a landed hit rocks it back
}
# Its blows at area 1 (TUNE's), for test_progression's share-cap scan (PR's ask).
const MOVES := {"lunge": TUNE["lunge"], "cut": TUNE["cut"]}
const FRAMES := ["pane_face1", "pane_face2", "pane_turn", "pane_edge", "pane_cut", "pane_hit", "pane_shatter"]
const TINTS := [Color("d8584a"), Color("4a7ad8"), Color("e8c04a")]
const LEAD := Color("2a2436")

var state := "advance"          # advance, turn, lunge, edge_recover, face, cut, cut_strike, cut_recover, turn_back
var timer := 0.0
var glass_col := TINTS[0]
var move_id := ""
var edge_on := false
var lunges := 0                 # lunges so far (tests)
var cut_rect := Rect2()         # the Glass Cut's arc while it strikes
var cut_tiles: Array[Vector2i] = []   # the glass the cut will break, marked from the tell's start
var _lunge_left := 0.0
var _back := false              # Witching: this is the lunge back
var _turn_t := 0.45
var _cut_t := 0.7
var _cut_hit := false
var _cd := 0.0
var _walk := 0.0
var _clang_t := 0.0
var _tb := TriBatch.new()


func _init() -> void:
	kind = "paneguard"
	set("echo_by_body", false)     # MA's Echoing: its lunge and cut are logged (strike_logged)
	size = Vector2(float(TUNE["face_w"]), float(TUNE["tall"]))
	base_hp = float(TUNE["life"])
	base_dmg = float(TUNE["touch"])
	poise = float(TUNE["poise"])
	embers = int(TUNE["embers"])
	item_chance = float(TUNE["item"])
	relic_chance = float(TUNE["relic"])


func k(n: String) -> float:
	return HK.pick(TUNE, HK.behave_of(self), n)


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("pane_face1")
	var cell: Vector2i = spawn.get("cell", Vector2i(floori(position.x / TILE), floori(position.y / TILE)))
	glass_col = TINTS[posmod(hash(cell) + 1, TINTS.size())]
	if tier == "":
		tint = Color.WHITE.lerp(glass_col, 0.35)


func moves() -> Dictionary:
	return {"touch": float(TUNE["touch"]), "lunge": float(TUNE["lunge"]), "cut": float(TUNE["cut"])}


func dmg(what := "touch") -> float:
	if what == "lunge" or (what == "touch" and state == "lunge"):
		return float(TUNE["lunge"]) * dmg_mult
	if what == "cut":
		return float(TUNE["cut"]) * dmg_mult
	return base_dmg * dmg_mult


func face_on() -> bool:
	return not edge_on


func hurt_rect() -> Rect2:
	# Edge-on it is a thin slicing blade: the whole box counts.
	return rect() if edge_on else rect().grow(-4.0)


func _set_edge(on: bool) -> void:
	## Turning edge-on (8 px) or face-on (30 px) about its feet; widening
	## never pushes it into a wall.
	edge_on = on
	var w := float(TUNE["lunge_box"]) if on else float(TUNE["face_w"]) * scale_mult
	size.x = w
	if level == null or on:
		return
	var r := rect()
	for y in [r.position.y + 4.0, r.get_center().y, r.end.y - 4.0]:
		if solid_at(Vector2(r.position.x + 0.5, y)):
			position.x = (floori((r.position.x + 0.5) / TILE) + 1) * TILE + w * 0.5
			r = rect()
		if solid_at(Vector2(r.end.x - 0.5, y)):
			position.x = floori((r.end.x - 0.5) / TILE) * TILE - w * 0.5
			r = rect()


# ---------------------------------------------------------------- being hit

func hit(h: Dictionary) -> bool:
	if not alive:
		return false
	var how: String = h.get("how", "slash")
	if face_on():
		var maul: bool = world != null and world.get("kit") != null and world.kit.cls == "founder" and how == "slash"
		if maul:
			# The maul rings the pane: 30% gets through.
			h["amount"] = float(h.get("amount", max_hp)) * float(TUNE["maul_through"])
			h["chip"] = true
			return super(h)
		_clang(how)
		return false
	if how == "stomp":
		h["amount"] = float(h.get("amount", max_hp)) * float(TUNE["stomp_edge"])
	return super(h)


func _clang(how: String) -> void:
	flash = 0.3
	_clang_t = 0.2
	sfx("glass_clang", "clang", 1.2)
	if world != null:
		if how != "slash":
			world.number(center() + Vector2(0, -size.y * 0.4), 0.0, "blocked", 0)
		if world.glow:
			world.glow.burst(center() + Vector2(0, -6), 6, glass_col.lightened(0.4), 120.0, 0.25, 0.0, 1.8)


func apply_status(name: String, seconds: float, data := {}) -> void:
	# A Perfect Guard on the lunge (the knight staggers what it blocks) leaves
	# it edge-on and open for pg_edge; a plain block just stops the lunge.
	if name == "stun" and state == "lunge":
		velocity.x = 0.0
		state = "edge_recover"
		timer = float(TUNE["pg_edge"]) if seconds >= 0.5 else float(TUNE["recover"])
		move_id = ""
		return
	super(name, seconds, data)


func _hurt(h: Dictionary) -> void:
	# Heavy glass: it barely rocks.
	velocity.x = float(TUNE["knock"]) * (1.0 if position.x > float(h.get("from_x", position.x)) else -1.0)
	show_frame("pane_hit")


# ---------------------------------------------------------------- the step

func think(dt: float, player: Node2D) -> void:
	timer -= dt
	_cd = maxf(_cd - dt, 0.0)
	_clang_t = maxf(_clang_t - dt, 0.0)
	var dx: float = player.position.x - position.x if player != null else 999.0
	var near: bool = player != null and player.alive and absf(dx) < float(TUNE["see"]) and absf(player.position.y - position.y) < float(TUNE["see_dy"])
	match state:
		"advance":
			if near:
				facing = 1 if dx > 0.0 else -1
				var clear := clear_to(player)
				if absf(dx) <= float(TUNE["cut_range"]) + size.x * 0.5 and _cd <= 0.0 and clear:
					_start_cut()
				elif absf(dx) <= float(TUNE["lunge_range"]) and _cd <= 0.0 and clear:
					_start_turn(false)
				else:
					if ground_ahead(facing) and not wall_ahead(facing) and absf(dx) > float(TUNE["cut_range"]):
						velocity.x = facing * spd(float(TUNE["advance"]))
						_walk += dt
					else:
						velocity.x = 0.0
					_fall(dt)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * dt)
				_fall(dt)
			_frame_face()
		"turn", "turn_back":
			velocity.x = 0.0
			_fall(dt)
			show_frame("pane_turn")
			if timer <= 0.0:
				_start_lunge()
		"lunge":
			show_frame("pane_edge")
			var stp := float(TUNE["lunge_speed"]) * dt
			if _lunge_left > 0.0 and ground_ahead(facing) and not wall_ahead(facing):
				velocity.x = facing * float(TUNE["lunge_speed"])
				_lunge_left -= stp
				_fall(dt)
			else:
				velocity.x = 0.0
				_fall(dt)
				if int(k("back_lunge")) > 0 and not _back and player != null and player.alive:
					# Witching: it turns and comes back.
					_back = true
					facing = 1 if player.position.x > position.x else -1
					state = "turn_back"
					_turn_t = tell(float(TUNE["turn_back"]), float(TUNE["turn_back_floor"]))
					timer = _turn_t
					tell_sfx("glass_shing", timer, "parry")
				else:
					state = "edge_recover"
					timer = float(TUNE["recover"])
					move_id = ""
		"edge_recover":
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * dt)
			_fall(dt)
			show_frame("pane_edge")
			if sprite:
				sprite.position.x = sin(t * 30.0) * 1.0
			if timer <= 0.0:
				state = "face"
				timer = float(TUNE["face"])
				if sprite:
					sprite.position.x = 0.0
		"face":
			velocity.x = 0.0
			_fall(dt)
			show_frame("pane_turn")
			if timer <= 0.0:
				_set_edge(false)
				state = "advance"
				_cd = cd(float(TUNE["again"]))
		"cut":
			velocity.x = 0.0
			_fall(dt)
			show_frame("pane_cut")
			if timer <= 0.0:
				_strike_cut()
		"cut_strike":
			velocity.x = 0.0
			_fall(dt)
			show_frame("pane_cut")
			if not _cut_hit and player != null and player.alive and cut_rect.intersects((player.rect() as Rect2).grow(-2.0)):
				_cut_hit = true
				world.hurt_player(dmg("cut"), position.x, "hit", self, {"move": "paneguard:cut"})
			if timer <= 0.0:
				state = "cut_recover"
				timer = float(TUNE["cut_recover"])
				cut_rect = Rect2()
				move_id = ""
		"cut_recover":
			velocity.x = 0.0
			_fall(dt)
			_frame_face()
			if timer <= 0.0:
				state = "advance"
				_cd = cd(float(TUNE["again"])) * float(TUNE["cut_again"])


func _fall(dt: float) -> void:
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)


func _frame_face() -> void:
	show_frame("pane_face1" if fmod(_walk, 0.8) < 0.4 else "pane_face2")


func _start_turn(back: bool) -> void:
	state = "turn"
	_back = back
	_turn_t = tell(float(TUNE["turn"]), float(TUNE["turn_floor"]))
	timer = _turn_t
	velocity.x = 0.0
	move_id = "paneguard:lunge"
	tell_sfx("glass_shing", timer, "parry")


func _start_lunge() -> void:
	_set_edge(true)
	state = "lunge"
	_lunge_left = k("lunge_dist")
	lunges += 1
	move_id = "paneguard:lunge"
	strike_logged(rect(), dmg("lunge"))
	sfx("glass_slide", "whoosh")


func clear_to(player: Node2D) -> bool:
	## A clear line at sight_y over its feet from its front edge to his near
	## edge: it never turns or cuts at him through a wall or a pillar.
	var y := position.y - float(TUNE["sight_y"])
	var from := Vector2(position.x + facing * size.x * 0.5, y)
	var to := Vector2(player.position.x - facing * 9.0, y)
	if (to.x - from.x) * facing <= 0.0:
		return true
	return sees(to, from)


func _start_cut() -> void:
	state = "cut"
	_cut_t = tell(float(TUNE["cut_tell"]), float(TUNE["cut_floor"]))
	timer = _cut_t
	velocity.x = 0.0
	move_id = "paneguard:cut"
	cut_tiles = cut_cells(cut_area())
	tell_sfx("glass_shing", timer, "parry")


func cut_area() -> Rect2:
	## The Glass Cut's arc in front (cut_w x cut_h, from its front edge),
	## stopping at the first column with a solid tile in its height.
	var w := float(TUNE["cut_w"])
	var h := float(TUNE["cut_h"])
	var x0 := position.x + facing * size.x * 0.5
	if level != null:
		var y0 := floori((position.y - h) / TILE)
		var y1 := floori((position.y - 1.0) / TILE)
		var c0 := floori(x0 / TILE)
		for i in range(0, int(w / TILE) + 2):
			var c := c0 + facing * i
			var edge := float(c * TILE) if facing > 0 else float((c + 1) * TILE)
			var d := 0.0 if i == 0 else absf(edge - x0)
			if d >= w:
				break
			var wall := false
			for y in range(y0, y1 + 1):
				if LevelData.is_solid(level.tile(c, y)):
					wall = true
			if wall:
				w = d
				break
	return Rect2(x0 if facing > 0 else x0 - w, position.y - h, w, h)


func cut_cells(area: Rect2) -> Array[Vector2i]:
	## The glass it will break: the floor-row panes under the arc, never its
	## own tile, none reaching more than cut_spill px past the arc's end
	## (so a Wick whose body is out of the arc keeps his footing).
	var out: Array[Vector2i] = []
	if level == null or area.size.x <= 0.0:
		return out
	var fy := floori((position.y + 1.0) / TILE)
	var own := floori(position.x / TILE)
	var spill := float(TUNE["cut_spill"])
	for x in range(floori(area.position.x / TILE), floori((area.end.x - 0.01) / TILE) + 1):
		if x == own or level.tile(x, fy) != LevelData.GLASS:
			continue
		if facing > 0 and float((x + 1) * TILE) > area.end.x + spill:
			continue
		if facing < 0 and float(x * TILE) < area.position.x - spill:
			continue
		out.append(Vector2i(x, fy))
	return out


func _strike_cut() -> void:
	state = "cut_strike"
	timer = float(TUNE["cut_active"])
	cut_rect = cut_area()
	_cut_hit = false
	strike_logged(cut_rect, dmg("cut"))
	sfx("glass_shatter", "block_break", 1.2)
	# It breaks the glass it marked (his footing), never its own tile.
	if level != null and world != null and world.features != null and world.features.has_method("break_glass"):
		for c in cut_tiles:
			if level.tile(c.x, c.y) == LevelData.GLASS:
				world.features.break_glass(c)
	cut_tiles.clear()


func _kill(h: Dictionary) -> void:
	cut_tiles.clear()
	super(h)
	show_frame("pane_shatter")
	velocity = Vector2.ZERO
	if world != null and world.glow:
		world.glow.burst(center(), 18, glass_col.lightened(0.3), 200.0, 0.6, 600.0, 2.6)
		world.glow.burst(center(), 8, Color("f4f0ff"), 160.0, 0.4, 500.0, 2.0)
	sfx("glass_shatter", "block_break", 0.9)


func _dying(dt: float) -> void:
	show_frame("pane_shatter")
	_fall(dt)
	squash = maxf(0.1, 1.0 - death_time * 2.0)
	fade = clampf(1.0 - death_time * 1.6, 0.0, 1.0)
	if death_time > 0.7:
		gone = true


func lights() -> Array:
	var out := super()
	if alive and face_on():
		out.append({"p": center() + Vector2(0, -6), "r": float(TUNE["light_r"]), "s": float(TUNE["light_s"]),
				"tint": Color(glass_col, 0.45)})
	return out


func eye_points() -> Array:
	if tier == "":
		return []
	var eyes := HK.frame_eyes(frame_name)
	if not eyes.is_empty():
		var out := []
		for p in eyes:
			out.append(frame_point(p))
		return out
	return [position + Vector2(facing * 3.0, -35.0) * scale_mult]


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := _tb
	var hc := position + Vector2(0, -38.0 * scale_mult)
	match state:
		"turn", "turn_back":
			# A glint runs up the lead; the halo flares.
			var kk := 1.0 - clampf(timer / maxf(_turn_t, 0.01), 0.0, 1.0)
			var y := position.y - kk * size.y
			tb.line(Vector2(position.x, position.y), Vector2(position.x, y), 2.0 + kk, Color(1, 1, 1, 0.85))
			tb.circle(Vector2(position.x, y), 3.0 + 2.0 * kk, Color(1, 1, 1, 0.9), 10)
			tb.ring(hc, 7.0 + 5.0 * kk, 2.0, Color(glass_col.lightened(0.5), 0.5 + 0.5 * kk), 16)
		"cut":
			# The arc it will cut, drawn in its colour, filling as it comes,
			# and every pane that will break glinting along its top.
			var kk := 1.0 - clampf(timer / maxf(_cut_t, 0.01), 0.0, 1.0)
			_cut_arc(tb, cut_area(), Color(glass_col.lightened(0.35), 0.35 + 0.5 * kk), 2.0 + 2.0 * kk, kk)
			var flick := 0.6 + 0.4 * absf(sin(t * 22.0))
			for c in cut_tiles:
				if level.tile(c.x, c.y) != LevelData.GLASS:
					continue
				var at := Vector2(c.x * TILE, c.y * TILE)
				var a := 0.35 + 0.6 * kk
				tb.rect(Rect2(at + Vector2(1, 0), Vector2(TILE - 2, 3)), Color(0.1, 0.1, 0.16, 0.5))
				tb.rect(Rect2(at + Vector2(1, 0), Vector2(TILE - 2, 2)), Color(1, 1, 1, a * flick))
				tb.line(at + Vector2(8, 2), at + Vector2(14, 11 + 6 * kk), 1.6, Color(1, 1, 1, a))
				tb.line(at + Vector2(24, 2), at + Vector2(18, 9 + 8 * kk), 1.6, Color(1, 1, 1, a))
				tb.rect(Rect2(at, Vector2(TILE, TILE)), Color(glass_col.lightened(0.5), (0.08 + 0.14 * kk) * flick))
		"cut_strike":
			_cut_arc(tb, cut_rect, Color(1, 1, 1, 0.95), 5.0, 1.0)
		"edge_recover":
			# Wobbling, open: a pale shimmer down the lead.
			var pulse := 0.4 + 0.3 * sin(t * 12.0)
			tb.line(position + Vector2(0, -2), position + Vector2(0, -size.y + 2), 3.0, Color(1, 1, 1, pulse))
	tb.flush(glow)


func _cut_arc(tb: RefCounted, r: Rect2, col: Color, w: float, kk: float) -> void:
	## A quarter-ellipse sweep over the cut's box, from high behind to low in front.
	var f := float(facing)
	var o := Vector2(position.x, r.end.y)
	var pts := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var a := lerpf(-PI * 0.5, 0.0, float(i) / n)
		pts.append(o + Vector2(f * (size.x * 0.5 + cos(a) * r.size.x), sin(a) * r.size.y))
	tb.polyline(pts, w, col)
	if kk > 0.0:
		var fill := Color(col, col.a * 0.25 * kk)
		for i in n:
			tb.tri(o + Vector2(f * size.x * 0.5, 0), pts[i], pts[i + 1], fill)


func _draw() -> void:
	if not frames.is_empty():
		return
	var s := scale_mult
	var f := float(facing)
	var sq := squash
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s * f, s * sq))
	var tb := _tb
	var a := clampf(fade, 0.0, 1.0)
	var lead := _c(LEAD, a)
	var h := float(TUNE["tall"])
	var wob := sin(t * 30.0) * 1.0 if state == "edge_recover" else 0.0
	var turning := state in ["turn", "turn_back", "face"]
	var w := 13.0
	if edge_on:
		w = 3.0
	elif turning:
		var kk := 1.0 - clampf(timer / maxf(_turn_t if state != "face" else float(TUNE["face"]), 0.01), 0.0, 1.0)
		w = lerpf(13.0, 3.0, kk) if state != "face" else lerpf(3.0, 13.0, kk)
	# The body: a tall arched window, flat, in its colour and lead.
	var body := PackedVector2Array([Vector2(-w + wob, -2), Vector2(-w + wob, -h + 12), Vector2(wob, -h + 2), Vector2(w + wob, -h + 12), Vector2(w + wob, -2)])
	HK.o_poly(tb, body, lead, 2.0)
	if w > 4.0:
		var inner := PackedVector2Array([Vector2(-w + 3 + wob, -4), Vector2(-w + 3 + wob, -h + 13), Vector2(wob, -h + 5), Vector2(w - 3 + wob, -h + 13), Vector2(w - 3 + wob, -4)])
		tb.convex(inner, _c(glass_col.lerp(Color.WHITE, 0.25), a))
		# Lead cames: a cross and a diamond.
		tb.line(Vector2(wob, -h + 5), Vector2(wob, -4), 1.4, lead)
		tb.line(Vector2(-w + 3 + wob, -h * 0.55), Vector2(w - 3 + wob, -h * 0.55), 1.4, lead)
		tb.line(Vector2(-w + 3 + wob, -h * 0.3), Vector2(wob, -h * 0.45), 1.2, lead)
		tb.line(Vector2(w - 3 + wob, -h * 0.3), Vector2(wob, -h * 0.45), 1.2, lead)
		tb.convex(PackedVector2Array([Vector2(-w + 5 + wob, -h * 0.72), Vector2(-2 + wob, -h * 0.85), Vector2(-2 + wob, -h * 0.6)]), _c(Color(1, 1, 1, 0.35), a))
		# The halo: a small rose window over its head.
		HK.o_ellipse(tb, Vector2(wob, -h + 2), 6.0, 6.0, _c(glass_col.lerp(Color("fff4cf"), 0.5), a), 1.4, lead)
		# The glass sword, held down in front.
		var sw := 0.0 if state != "cut" else -0.9
		if state == "cut_strike":
			sw = 0.9
		var hand := Vector2(w - 2 + wob, -h * 0.45)
		var tip := hand + Vector2(cos(sw + 1.2), sin(sw + 1.2)) * 20.0
		tb.line(hand, tip, 4.0, lead)
		tb.line(hand, tip, 2.0, _c(Color("e8f4ff"), a))
	else:
		# Edge-on: a thin line of lead with a glint.
		tb.rect(Rect2(-1.0 + wob, -h + 4, 2.0, h - 6), _c(Color("6a6478"), a))
	if _clang_t > 0.0:
		tb.convex(body, Color(1, 1, 1, _clang_t * 2.0))
	tb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _c(col: Color, a := 1.0) -> Color:
	return HK.shade(self, col, a)
