extends RefCounted
## Every moving ledge (split out of world.gd for v3). One Mover class with a
## kind; the World keeps them in world.movers, steps them on world.ftime
## (skipping hitstop ticks, as v2 did) and actors ride them by `delta`.
##
##   x, y    v2's moving ledges: a run of tiles gliding to and fro on a sine
##           (reach 3 tiles, period 3.6 / 4.0 / 4.4 s in turn)
##   orbit   a cog's tooth: a 2-tile ledge riding a ring (hub, radius 96,
##           period 6.43 s = 12 ticks, 4 teeth a quarter turn apart, staying
##           level); dir 1 turns clockwise on screen (the ring's left side
##           rises), -1 the other way; tooth 0 is at the top at phase 0
##   arc     a swing ledge (or the Tinker's pivot): hanging from an anchor on
##           a rod, amplitude and period, staying level; at rest it lies
##           where its cells were drawn
##   float   a wax float on water: rests with its top 4 px over the water
##           line and bobs +-3 px at 0.5 Hz; with Wick on it it sinks
##           (sink px/s) and at `under` px down it's under (not there to land
##           on); unloaded it rises 30 px/s
##   temp    a still, temporary ledge (a kit's bone step) with a life
##
## Every mover has rect(), delta (this step's move), one_way (always true:
## they're ledges), rider_count (actors that landed on it last step) and
## hero_on (Wick among them).

const TILE := 32
const ORBIT_R := 96.0
const ORBIT_PERIOD := 6.432      # 12 ticks of 0.536 s
const SWING_PERIOD := 3.216      # 6 ticks
const SWING_AMP := deg_to_rad(40.0)
const FLOAT_TOP := 4.0           # px over the water line at rest
const FLOAT_BOB := 3.0
const FLOAT_HZ := 0.5
const FLOAT_RISE := 30.0
const FLOAT_UNDER := 24.0
const FLOAT_SINK := 18.5         # Dusk (deep.gd passes its own knob; owner feel lab 2026-09-26)
const LEDGE_H := 12.0


class Mover:
	var kind := "x"               # x | y | orbit | arc | float | temp
	var start := Vector2.ZERO     # top-left at rest
	var length := 1
	var reach := 96.0
	var period := 4.0
	var phase := 0.0              # x / y: radians (v2); orbit / arc: turns
	var pos := Vector2.ZERO       # top-left now
	var delta := Vector2.ZERO
	var node: Node2D
	var width := 0.0              # px (0 = length tiles)
	var life := -1.0              # a temporary ledge's seconds left; -1 = forever
	var forever := false          # a temporary ledge made with no life
	var one_way := true
	var rider_count := 0
	var hero_on := false
	var present := true           # there to land on (a float that's under isn't)
	var tag := ""                 # what made it: "", "cog", "swing", "float", "bone", ...
	# The feature or kit that made it, held weakly: a module keeps its movers
	# (a cog's teeth, a float) and a strong link back would be a reference
	# cycle that outlives the World (wave-1 merge: SC's lab-0 leak).
	var _owner_ref: WeakRef = null
	var owner: Object:
		get:
			return _owner_ref.get_ref() if _owner_ref != null else null
		set(v):
			_owner_ref = weakref(v) if v != null else null
	# orbit
	var hub := Vector2.ZERO
	var radius := ORBIT_R
	var dir := 1
	var tooth := 0.0               # this tooth's place on the ring, in turns
	# arc
	var anchor := Vector2.ZERO
	var rod := 160.0
	var amp := SWING_AMP
	var angle := 0.0
	# float
	var rest_y := 0.0
	var depth := 0.0              # px pushed under by a load
	var sink := FLOAT_SINK
	var rise := FLOAT_RISE
	var under := FLOAT_UNDER
	var _landed := 0
	var _hero_landed := false

	var axis: String:
		## v2's name for the kind.
		get:
			return kind
		set(v):
			kind = v

	func w() -> float:
		return width if width > 0.0 else length * float(TILE)

	func rect() -> Rect2:
		return Rect2(pos, Vector2(w(), LEDGE_H))

	func top() -> float:
		return pos.y

	func ride(who: Object, is_hero := false) -> void:
		## An actor landed on it this step (actor.gd calls this).
		_landed += 1
		if is_hero:
			_hero_landed = true

	func update(t: float, dt := 1.0 / 120.0) -> void:
		rider_count = _landed
		hero_on = _hero_landed
		_landed = 0
		_hero_landed = false
		var next := pos
		match kind:
			"temp":
				delta = Vector2.ZERO
				return
			"x", "y":
				if life >= 0.0:
					delta = Vector2.ZERO
					return
				var off := sin(t / period * TAU + phase) * reach
				next = start + (Vector2(off, 0) if kind == "x" else Vector2(0, off))
			"orbit":
				var a := TAU * (phase + dir * t / period + tooth) - PI * 0.5
				var p := hub + Vector2(cos(a), sin(a)) * radius
				next = Vector2(p.x - w() * 0.5, p.y - LEDGE_H * 0.5)
			"arc":
				angle = amp * sin(TAU * (t / period + phase))
				var p := anchor + Vector2(sin(angle), cos(angle)) * rod
				next = Vector2(p.x - w() * 0.5, p.y)
			"float":
				if hero_on:
					depth = minf(depth + sink * dt, under)
				else:
					depth = maxf(depth - rise * dt, 0.0)
				present = depth < under - 0.01
				var bob := sin(TAU * FLOAT_HZ * t + start.x * 0.01) * FLOAT_BOB * (1.0 - depth / under)
				next = Vector2(start.x, rest_y + depth + bob)
		delta = next - pos
		pos = next
		if node:
			node.position = pos


static func make(kind: String) -> Mover:
	var m := Mover.new()
	m.kind = kind
	return m


static func from_level(level: RefCounted) -> Array:
	## v2's moving ledges ('-' and '|'), exactly as world.gd built them.
	var out := []
	for m in level.movers:
		var mv := Mover.new()
		mv.kind = m["axis"]
		mv.length = m["length"]
		mv.start = Vector2(m["cell"].x * TILE, m["cell"].y * TILE)
		mv.pos = mv.start
		mv.reach = 3.0 * TILE
		mv.period = 3.6 + 0.4 * (out.size() % 3)
		mv.phase = 0.0
		out.append(mv)
	return out


static func temp(r: Rect2, life: float) -> Mover:
	## A still ledge that lasts a while (a kit's bone step).
	var mv := Mover.new()
	mv.kind = "temp"
	mv.pos = r.position
	mv.start = r.position
	mv.width = r.size.x
	mv.life = life
	mv.forever = life < 0.0
	mv.tag = "temp"
	return mv


static func cog(hub: Vector2, dir: int, phase_turns := 0.0, teeth := 4, radius := ORBIT_R, period := ORBIT_PERIOD) -> Array:
	## A cog's teeth: `teeth` 2-tile ledges a 1/teeth turn apart.
	var out := []
	for k in teeth:
		var mv := Mover.new()
		mv.kind = "orbit"
		mv.hub = hub
		mv.dir = 1 if dir >= 0 else -1
		mv.tooth = float(k) / maxf(teeth, 1.0)
		mv.phase = phase_turns
		mv.radius = radius
		mv.period = period
		mv.length = 2
		mv.tag = "cog"
		mv.update(0.0, 0.0)
		mv.delta = Vector2.ZERO
		out.append(mv)
	return out


static func swing(anchor: Vector2, rest_top_left: Vector2, length: int, phase_turns := 0.0, amp := SWING_AMP, period := SWING_PERIOD) -> Mover:
	## A swing ledge hanging from anchor; at rest its top-left is where it was drawn.
	var mv := Mover.new()
	mv.kind = "arc"
	mv.length = length
	mv.start = rest_top_left
	mv.anchor = anchor
	var mid := rest_top_left + Vector2(length * TILE * 0.5, 0)
	mv.rod = maxf(anchor.distance_to(mid), 16.0)
	mv.amp = amp
	mv.period = period
	mv.phase = phase_turns
	mv.tag = "swing"
	mv.update(0.0, 0.0)
	mv.delta = Vector2.ZERO
	return mv


static func float_on(cell: Vector2i, length: int, sink := FLOAT_SINK, water_line := 8.0) -> Mover:
	## A float on the water surface cell: its top FLOAT_TOP px over the line
	## (deep water's line sits 8 px into the cell).
	var mv := Mover.new()
	mv.kind = "float"
	mv.length = length
	mv.start = Vector2(cell.x * TILE, cell.y * TILE)
	mv.rest_y = cell.y * TILE + water_line - FLOAT_TOP
	mv.pos = Vector2(mv.start.x, mv.rest_y)
	mv.sink = sink
	mv.tag = "float"
	return mv


static func clone(m: Mover) -> Mover:
	## A copy that moves the same way (the autoplay bot times its jumps on it).
	var c := Mover.new()
	for k in ["kind", "start", "length", "reach", "period", "phase", "pos", "delta", "width", "life", "forever",
			"one_way", "present", "tag", "hub", "radius", "dir", "tooth", "anchor", "rod", "amp", "angle",
			"rest_y", "depth", "sink", "rise", "under"]:
		c.set(k, m.get(k))
	return c
