extends "res://scripts/elites.gd"
## Refractor `y` (World 5, a flier; spec §4.5): a floating prism crystal with
## one calm eye and three orbiting glass petals. Like the Bonebow it shoots
## only wholly in view (elites.in_view), within `range` px, with a clear line
## to Wick (glass doesn't block it: light goes through glass).
##   track  a thin rainbow aim line follows his centre           (`track`)
##   lock   the line turns white and stops: the dodge window      (`lock`, never under 0.40 s)
##   fire   a beam hazard `width` px wide along the locked line   (`fire` s, `beam` damage)
## The beam stops at solid tiles. Where the locked line crosses glass it
## goes through and splits at +-`split_deg` past it: the split lines are
## worked out and drawn from the start of the lock, and those very segments
## are what fires (drawn_lines() == the hazards' segs). A hit during track
## resets the aim (it flinches); a hit during the lock doesn't stop it. The
## beam hazard carries reflect: true and source: self, so a Candleknight's
## Perfect Guard reflects it back along the segment (the knight kit's side,
## KT). Numbers: TUNE.
##
## Nightfall: track 0.75 s (the tell multiplier). Witching: a second beam
## 0.5 s after the first, with a fresh 0.40 s lock of its own. The 5-2 Dread
## is Glintwatch.

const HK := preload("res://scripts/hush_kind.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const TUNE := {
	"life": 24.0, "beam": 24.0, "touch": 18.0, "embers": 3, "item": 0.10,
	"range": 360.0,
	"track": 0.90, "track_floor": 0.40,
	"lock": 0.45, "lock_floor": 0.40,        # the dodge window: never under 0.40 s
	"fire": 0.25,
	"width": 6.0,
	"split_deg": 30.0,
	"again": 2.2,
	"beams": {"dusk": 1, "nightfall": 1, "witching": 2},
	"second_lock": 0.40,                     # Witching's second: its own lock, never less
	"second_gap": 0.5,                       # fire to fire
	"flinch": 0.5,                           # a hit during track: back to idle this long
	"lost": 0.6,                             # he left its sight during track: back to idle this long
	"eye_r": 20.0, "charge_r": 40.0, "beam_light_r": 60.0,
	"hover": 3.0,
	"step": 3.0,                             # px per step of the beam's trace
}
# Its blows at area 1 (TUNE's), for test_progression's share-cap scan (PR's ask).
const MOVES := {"beam": TUNE["beam"]}
const FRAMES := ["refractor_idle1", "refractor_idle2", "refractor_charge", "refractor_fire", "refractor_hit"]
const PRISM := Color("c8e8ff")
const SPECTRUM := [Color("ff6a6a"), Color("ffd84a"), Color("7ae0ff")]

var state := "idle"             # idle, track, lock, fire, cool
var timer := 0.0
var home := Vector2.ZERO
var aim := Vector2.RIGHT
var lines: Array = []           # the locked beam: [[a, b], ...], the main line first, then its splits
var lines2: Array = []          # Witching's second beam (its own fresh lock)
var beams: Array = []           # what is burning now
var move_id := ""
var fired := 0                  # beams fired (tests)
var _lock_t := 0.45
var _track_t := 0.9
var _wait2 := -1.0              # s until the second lock starts (-1: none)
var _lock2 := -1.0              # s left on the second lock
var _lock2_t := 0.4
var _beam_t := 0.0
var _tb := TriBatch.new()


func _init() -> void:
	kind = "refractor"
	size = Vector2(20, 30)
	base_hp = float(TUNE["life"])
	base_dmg = float(TUNE["touch"])
	embers = int(TUNE["embers"])
	item_chance = float(TUNE["item"])
	anchor = Vector2(64, 64)
	flier = true
	set("echo_by_body", false)     # MA's Echoing: its beams are logged (strike_logged)


func k(n: String) -> float:
	return HK.pick(TUNE, HK.diff_of(self), n)


func _ready() -> void:
	super()
	load_frames(FRAMES)
	show_frame("refractor_idle1")
	home = position


func moves() -> Dictionary:
	return {"touch": float(TUNE["touch"]), "beam": float(TUNE["beam"])}


func dmg(what := "touch") -> float:
	if what == "beam":
		return float(TUNE["beam"]) * dmg_mult
	return base_dmg * dmg_mult


func rect() -> Rect2:
	return Rect2(position - size * 0.5, size)


func center() -> Vector2:
	return position


func eye() -> Vector2:
	return position + Vector2(0, -3.0) * scale_mult


func lock_time() -> float:
	## The dodge window on this difficulty (Swift too): never under 0.40 s.
	return tell(float(TUNE["lock"]), float(TUNE["lock_floor"]))


func drawn_lines() -> Array:
	## Every segment drawn as a locked line now (the first beam's and a
	## second's): exactly what will fire.
	var out: Array = lines.duplicate()
	out.append_array(lines2)
	return out


# ---------------------------------------------------------------- sight and the trace

func _blocks(p: Vector2) -> bool:
	return solid_at(p)


func clear_line(to: Vector2) -> bool:
	## A clear line from the eye to `to` (glass lets light through).
	var a := eye()
	var d := to - a
	var n := int(d.length() / 6.0) + 1
	for i in range(1, n):
		var p := a + d * (float(i) / n)
		if solid_at(p) and level.tile(floori(p.x / TILE), floori(p.y / TILE)) != LevelData.GLASS:
			return false
	return true


func trace(from: Vector2, dir: Vector2, max_len: float) -> Array:
	## The beam's segments from `from` along `dir`: it stops at the first
	## solid tile; the first glass it meets it crosses, then splits into two
	## at +-split_deg from the glass's far side, each stopping at any solid
	## (glass included) or at the beam's length.
	var st := float(TUNE["step"])
	var p := from
	var went := 0.0
	while went < max_len:
		var q := p + dir * st
		var c := Vector2i(floori(q.x / TILE), floori(q.y / TILE))
		var tt: int = level.tile(c.x, c.y)
		if LevelData.is_solid(tt):
			if tt != LevelData.GLASS:
				break
			# Through the glass...
			while went < max_len and level.tile(floori(q.x / TILE), floori(q.y / TILE)) == LevelData.GLASS:
				q += dir * st
				went += st
			var out := [[from, q]]
			# ...and split past it.
			for sgn in [-1.0, 1.0]:
				var d2 := dir.rotated(sgn * deg_to_rad(float(TUNE["split_deg"])))
				out.append([q, _straight(q, d2, max_len - went)])
			return out
		p = q
		went += st
	return [[from, p]]


func _straight(from: Vector2, dir: Vector2, max_len: float) -> Vector2:
	var st := float(TUNE["step"])
	var p := from
	var went := 0.0
	while went < max_len:
		var q := p + dir * st
		if solid_at(q):
			break
		p = q
		went += st
	return p


func can_fire(player: Node2D) -> bool:
	if player == null or not player.alive or world == null:
		return false
	var c: Vector2 = player.center()
	if c.distance_to(eye()) > float(TUNE["range"]):
		return false
	return in_view() and clear_line(c)


# ---------------------------------------------------------------- the step

func think(dt: float, player: Node2D) -> void:
	timer -= dt
	position = Vector2(home.x, home.y + sin(t * 2.3) * float(TUNE["hover"]))
	match state:
		"idle":
			show_frame("refractor_idle1" if fmod(t, 0.6) < 0.3 else "refractor_idle2")
			if timer <= 0.0 and can_fire(player):
				state = "track"
				_track_t = tell(float(TUNE["track"]), float(TUNE["track_floor"]))
				timer = _track_t
				move_id = "refractor:beam"
				aim = (player.center() - eye()).normalized()
				tell_sfx("prism_hum", timer, "curdle")
		"track":
			show_frame("refractor_charge")
			if player != null and player.alive:
				aim = (player.center() - eye()).normalized()
				facing = 1 if aim.x >= 0.0 else -1
			if not can_fire(player):
				state = "idle"
				timer = float(TUNE["lost"])
				move_id = ""
			elif timer <= 0.0:
				_lock()
		"lock":
			show_frame("refractor_charge")
			if timer <= 0.0:
				_fire(lines)
				lines = []
				state = "fire"
				if int(k("beams")) > 1:
					_wait2 = maxf(float(TUNE["second_gap"]) - float(TUNE["second_lock"]), 0.0)
		"fire":
			show_frame("refractor_fire")
			_beam_t -= dt
			if _wait2 >= 0.0:
				_wait2 -= dt
				if _wait2 < 0.0 and can_fire(player):
					# A fresh lock where he is now (only if it could shoot him
					# now: wholly in view, in range, a clear line).
					var d2: Vector2 = (player.center() - eye()).normalized()
					if d2 != Vector2.ZERO:
						aim = d2
					lines2 = trace(eye(), aim, float(TUNE["range"]))
					_lock2_t = tell(float(TUNE["second_lock"]), float(TUNE["second_lock"]))
					_lock2 = _lock2_t
					tell_sfx("prism_lock", _lock2_t, "knell")
			if _lock2 >= 0.0:
				_lock2 -= dt
				if _lock2 < 0.0:
					_fire(lines2)
					lines2 = []
			if _beam_t <= 0.0 and _wait2 < 0.0 and _lock2 < 0.0:
				beams = []
				state = "cool"
				timer = cd(float(TUNE["again"]))
				move_id = ""
		"cool":
			show_frame("refractor_idle1")
			if timer <= 0.0:
				state = "idle"
				timer = 0.0


func _lock() -> void:
	state = "lock"
	_lock_t = lock_time()
	timer = _lock_t
	lines = trace(eye(), aim, float(TUNE["range"]))
	tell_sfx("prism_lock", timer, "knell")


func _fire(segs: Array) -> void:
	## The beam: one hazard per segment (the World's "beam" kind: segment vs
	## rect, the kit's guard, reflect).
	fired += 1
	beams = segs.duplicate()
	_beam_t = float(TUNE["fire"])
	if world == null:
		return
	for sg in segs:
		var h: Dictionary = world.add_hazard({"kind": "beam", "seg": [sg[0], sg[1]], "width": float(TUNE["width"]),
				"life": float(TUNE["fire"]), "dmg": dmg("beam"), "owner": "enemy", "reflect": true, "source": self,
				"move": "refractor:beam", "shot": true})
		strike_logged(h, dmg("beam"))
	sfx("beam_fire", "spark", 0.8)


func on_reflected(_beam: Dictionary) -> void:
	## A Candleknight's Perfect Guard sent its beam back (KT's knight.gd deals
	## the damage): it flashes, and a Witching second lock not yet begun is
	## spoiled.
	flash = 1.0
	show_frame("refractor_hit")
	_wait2 = -1.0
	if world != null and world.glow:
		world.glow.burst(eye(), 10, Color(1, 1, 1, 0.9), 140.0, 0.3, 0.0, 2.0)


func _hurt(h: Dictionary) -> void:
	flash = 1.0
	show_frame("refractor_hit")
	if state == "track":
		# The aim is knocked off: it starts over.
		state = "idle"
		timer = float(TUNE["flinch"])
		move_id = ""


func _kill(h: Dictionary) -> void:
	lines = []
	lines2 = []
	super(h)
	if world != null and world.glow:
		for i in 3:
			world.glow.burst(position, 6, SPECTRUM[i], 170.0, 0.5, 300.0, 2.2)


func _dying(dt: float) -> void:
	# The prism cracks and falls, fading.
	velocity.y += 900.0 * dt
	position += velocity * dt * 0.5
	fade = clampf(1.0 - death_time * 1.8, 0.0, 1.0)
	if death_time > 0.6:
		gone = true


func lights() -> Array:
	var out := super()
	if not alive:
		return out
	var charging := state in ["track", "lock"] or _lock2 >= 0.0
	out.append({"p": eye(), "r": float(TUNE["charge_r"]) if charging else float(TUNE["eye_r"]), "s": 0.6})
	if not beams.is_empty() and _beam_t > 0.0:
		var sg: Array = beams[0]
		out.append({"p": ((sg[0] as Vector2) + (sg[1] as Vector2)) * 0.5, "r": float(TUNE["beam_light_r"]), "s": 0.8})
	return out


func eye_points() -> Array:
	return [eye()] if tier != "" else []


# ---------------------------------------------------------------- the look

func draw_glow(glow: Node2D) -> void:
	super(glow)
	if not alive:
		return
	var tb := _tb
	var e := eye()
	# The calm eye glows over the dark.
	tb.circle(e, 3.2, Color(1, 1, 1, 0.9), 10)
	tb.circle(e, 6.0, Color(PRISM, 0.25), 12)
	match state:
		"track":
			# A thin rainbow line from the eye along the aim, to where it would stop.
			var end: Vector2 = trace(e, aim, float(TUNE["range"]))[0][1]
			var o := aim.orthogonal()
			for i in 3:
				tb.line(e + o * (i - 1) * 1.6, end + o * (i - 1) * 1.6, 1.1, Color(SPECTRUM[i], 0.5))
		"lock":
			_draw_locked(tb, lines, 1.0 - clampf(timer / maxf(_lock_t, 0.01), 0.0, 1.0))
	if _lock2 >= 0.0:
		_draw_locked(tb, lines2, 1.0 - clampf(_lock2 / maxf(_lock2_t, 0.01), 0.0, 1.0))
	if state == "fire" and _beam_t > 0.0:
		var w := float(TUNE["width"])
		for sg in beams:
			var a: Vector2 = sg[0]
			var b: Vector2 = sg[1]
			var o := (b - a).normalized().orthogonal()
			for i in 3:
				tb.line(a + o * (i - 1) * w * 0.8, b + o * (i - 1) * w * 0.8, w * 0.6, Color(SPECTRUM[i], 0.5))
			tb.line(a, b, w, Color(1, 1, 1, 0.55))
			tb.line(a, b, w * 0.45, Color(1, 1, 1, 1.0))
			tb.circle(b, w, Color(1, 1, 1, 0.7), 10)
	tb.flush(glow)


func _draw_locked(tb: RefCounted, segs: Array, kk: float) -> void:
	## The locked line(s), white, brightening to the fire; the split ones too.
	var pulse := 0.8 + 0.2 * sin(t * 40.0)
	for sg in segs:
		tb.line(sg[0], sg[1], 5.0 + kk * 2.0, Color(1, 1, 1, 0.14 + 0.12 * kk))
		tb.line(sg[0], sg[1], 2.2 + kk * 1.4, Color(1, 1, 1, (0.75 + 0.25 * kk) * pulse))


func _draw() -> void:
	if not frames.is_empty():
		return
	var s := scale_mult
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s * facing, s))
	var tb := _tb
	var a := clampf(fade, 0.0, 1.0)
	var glow_k := 0.0
	if state == "track":
		glow_k = 0.4
	elif state == "lock" or _lock2 >= 0.0:
		glow_k = 1.0
	# Three petals orbiting behind and in front.
	for i in 3:
		var ang := t * 1.6 + TAU * i / 3.0
		var pc0 := Vector2(cos(ang) * 14.0, sin(ang) * 5.0 - 2.0)
		var back := sin(ang) < 0.0
		if back:
			_petal(tb, pc0, ang, a * 0.7)
	# The crystal: a long hexagonal prism, facets in lighter and darker glass.
	var body := PackedVector2Array([Vector2(0, -15), Vector2(7, -8), Vector2(7, 7), Vector2(0, 15), Vector2(-7, 7), Vector2(-7, -8)])
	HK.o_poly(tb, body, _c(PRISM.darkened(0.25), a), 1.8)
	tb.convex(PackedVector2Array([Vector2(0, -15), Vector2(7, -8), Vector2(7, 7), Vector2(0, 15)]), _c(PRISM.lerp(Color.WHITE, 0.2 + 0.4 * glow_k), a))
	tb.line(Vector2(0, -15), Vector2(0, 15), 1.0, _c(Color(1, 1, 1, 0.6), a))
	# The eye: a calm iris in the core.
	HK.o_ellipse(tb, Vector2(0, -3), 3.6, 3.0, _c(Color("f8fbff"), a), 1.2)
	tb.circle(Vector2(1.0, -3), 1.5, _c(Color("3a5a8a"), a), 8)
	for i in 3:
		var ang := t * 1.6 + TAU * i / 3.0
		if sin(ang) >= 0.0:
			_petal(tb, Vector2(cos(ang) * 14.0, sin(ang) * 5.0 - 2.0), ang, a)
	tb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _petal(tb: RefCounted, c: Vector2, ang: float, a: float) -> void:
	var col: Color = SPECTRUM[int(fposmod(ang / (TAU / 3.0), 3.0)) % 3]
	var pts := PackedVector2Array([c + Vector2(0, -4), c + Vector2(2.5, 0), c + Vector2(0, 4), c + Vector2(-2.5, 0)])
	HK.o_poly(tb, pts, _c(col.lerp(Color.WHITE, 0.35), a), 1.0)


func _c(col: Color, a := 1.0) -> Color:
	return HK.shade(self, col, a)
