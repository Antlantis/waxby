extends "res://scripts/features/feature.gd"
## World 4, the Frozen Carillon (WL4). Everything here keeps one clock: the
## level's tick (level.tick, 0.536 s on every difficulty, one beat of the
## carillon at 112 BPM), read from world.ftime (stop_time freezes it with
## everything else; the movers skip hitstop ticks as v2's did).
##
##   ice I, frosted ledge _   the grip is player.gd's (134 px to stop from a
##                            run; knockback on ice x0.5); here slick_at, the
##                            ice's reflections (reflectors), the scrape and
##                            the squeak, and the stand-in look
##   thin ice %               v2's crumble (world.gd), drawn as ice in W4 (and
##                            the Descent's carillon rooms); it cracks
##                            (ice_crack) as it starts to go
##   rime Z                   connected cells melt as one patch when his rect
##                            (grown RIME_GROW) touches it for
##                            0.4 + rime_k x (1 - f) s (f his life share: Dusk
##                            0.4 s full, 0.8 s near empty); progress holds
##                            rime_hold s between touches, then drains. Fire
##                            (a flare, a fire patch, a lit lamp or brazier
##                            within 2 tiles) melts it in FIRE_MELT. Melted, it
##                            is air for rime_refreeze s, then refreezes over a
##                            REFREEZE_TELL tell that starts on a beat, and
##                            never while a body overlaps it (it waits)
##   icicle V                 his centre within ICICLE_REACH px across under it,
##                            in line of sight: an icicle_tell tell (a crack,
##                            a shake, a glint r 24), then it falls (g 2000,
##                            900 px/s at most) and hits for icicle_dmg base
##                            (a shot kind; no douse); it shatters and grows
##                            back after icicle_regrow s. A swing (or a hero
##                            shot) knocks a hanging one down early, harmless
##   gear belt < >            the carry is actor.gd's (80 px/s); here the
##                            teeth's run, reverse_belts (a REVERSE_TELL tell)
##                            and belt_dir. Build 2's optional `belt_flip:
##                            x0-x1=N` header flips that run of belts (tile
##                            columns, inclusive) every N beats, landing on the
##                            beat (its tell starts REVERSE_TELL before), so
##                            with N = 8 every toll (twists.gd) lands on a flip
##   cog O Q                  four tooth ledges on a 96 px ring, 12 ticks a
##                            turn (movers.gd orbit); cog_phase: per hub
##   pendulum weight Y        a bob on a 96-192 px rod, +-50 deg, 6 ticks; hurts
##                            (r 18, weight_dmg base) and knocks along its
##                            swing (on Dusk never toward a pit edge within
##                            PIT_GUARD tiles: the other way, or straight up
##                            when both are); a frost lamp; weights in a row
##                            alternate half a swing (weight_phase: overrides)
##   swing ledge T            a ledge on a rod from the solid 3-6 rows above,
##                            +-40 deg, 6 ticks (movers.gd arc), staying level;
##                            swings in a row alternate half a swing too
##                            (weight_phase:, keyed by a swing's first column,
##                            overrides)
##   the boss's pivot         a Y inside the Tinker's arena is his own (the
##                            pendulum, still until his P2): it makes no weight
##                            here; boss_pivots lists it ({cell, anchor, rod})
##
## Every beat pulses the lamps and the gears' hubs (a muted phone's twin of
## the tick). The first-time barks (first_ice, first_rime, first_belt,
## first_gear, first_pendulum, first_swing) fire at the teaching sign (or
## BARK_LEAD tiles before the feature where none stands), or on the next
## landing on stone, never mid-jump, never in a mode, and at most one every
## BARK_GAP s (two due at once: the one whose spot he passed last).
## Props from art/props (gear_l, cog_tooth, swing_ledge, belt_teeth,
## pendulum_bob, pendulum_pivot, icicle_hang/_crack/_fall) when they exist,
## code-drawn stand-ins until then. The ice, rime and belt bodies are the
## theme's painter's once the theme has one (tile_view.gd); until then (and in
## v2's themes: the feel lab) they're drawn here.

const Movers := preload("res://scripts/movers.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const Themes := preload("res://scripts/themes/loader.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const DIFF_KNOBS := {
	"tick": {"dusk": 0.536, "nightfall": 0.536, "witching": 0.536},
	"cog_period": {"dusk": 6.432, "nightfall": 6.432, "witching": 6.432},
	"weight_period": {"dusk": 3.216, "nightfall": 3.216, "witching": 3.216},
	"swing_period": {"dusk": 3.216, "nightfall": 3.216, "witching": 3.216},
	"weight_dmg": {"dusk": 30.0, "nightfall": 30.0, "witching": 30.0},
	"rime_k": {"dusk": 0.4, "nightfall": 0.8, "witching": 0.8},
	"rime_hold": {"dusk": 3.0, "nightfall": 1.5, "witching": 1.5},
	"rime_refreeze": {"dusk": 12.0, "nightfall": 10.0, "witching": 8.0},
	"icicle_tell": {"dusk": 0.45, "nightfall": 0.40, "witching": 0.35},
	"icicle_dmg": {"dusk": 28.0, "nightfall": 28.0, "witching": 28.0},
	"icicle_regrow": {"dusk": 6.0, "nightfall": 6.0, "witching": 6.0},
}
const WEIGHT_AMP := deg_to_rad(50.0)
const WEIGHT_R := 18.0
const ROD_MIN := 96.0
const ROD_MAX := 192.0
const REVERSE_TELL := 0.6
const PIT_GUARD := 3             # tiles: on Dusk no weight knocks toward a pit edge this near
const RIME_BASE := 0.4           # s at full flame (every difficulty)
const RIME_GROW := 2.0           # px his rect is grown by to touch rime
const FIRE_MELT := 0.2           # s fire takes to melt rime
const LAMP_MELT := 64.0          # px: a lit lamp or brazier this near a rime cell melts it
const REFREEZE_TELL := 1.0
const ICICLE_REACH := 24.0       # px across from his centre
const ICICLE_ROWS := 7           # rows an icicle sees down
const ICICLE_G := 2000.0
const ICICLE_VMAX := 900.0
const ICICLE_W := 10.0           # its hurt box...
const ICICLE_DRAW_W := 14.0      # ...drawn a little bigger (30 px tall): it reads at phone size
const ICICLE_H := 26.0
const ICICLE_GROW := 0.5         # s it takes to grow back in (after icicle_regrow)
const SLIDE_V := 120.0           # px/s: faster than this on ice with no push is a slide
const SLIDE_EVERY := 0.4
const BELT_EVERY := 0.5
const HEAR := 300.0              # px: the belts' run and the weights' swing
const GEAR_HEAR := 260.0
const NO_Q := -1000000
const BARK_GAP := 8.0             # s between two barks (spec 3.1 rule 9)...
const SIGN_GAP := 3.0             # ...or this, for one said at its own sign
const BARKS := {"ice": "first_ice", "rime": "first_rime", "belt": "first_belt", "cog": "first_gear",
		"weight": "first_pendulum", "swing": "first_swing"}
const SIGN_BEFORE := 12          # tiles: a sign this far before a feature's first cell teaches it...
const BARK_LEAD := 6             # ...else its bark is said this far before it
const STORY := "res://scripts/story.gd"
const PIVOT_BOSSES := ["tinker"]  # a boss whose arena's Y is its own pendulum
const PULSE := 0.18              # s a beat's pulse lasts
const REFLECT_TINT := Color(0.749, 0.894, 0.957, 0.5)   # ice bfe4f4 at 0.5 (spec §11.2 F7)
const REFLECT_K := 0.45
const ICE_LIP := 0.22             # the ice tops' glow lip (a fair dark, spec 3.1 rule 8)
const ICE := Color("a8d4ec")
const ICE_DEEP := Color("6e9fbd")
const FROST := Color("e8fcff")   # the W4 tell accent (and the ice's lip)
const RIME := Color("d8ecf4")
const BRASS := Color("c8983a")
const BRASS_LIT := Color("f0d080")
const IRON := Color("4a4e5c")
const IRON_DARK := Color("2a2c36")
const OUTLINE := Color("141220")
const PROPS := ["gear_l", "gear_l_shine", "cog_tooth", "swing_ledge", "swing_ledge_2", "swing_ledge_3", "belt_teeth",
		"pendulum_bob", "pendulum_pivot", "icicle_hang", "icicle_crack", "icicle_fall"]

var tick := LevelData.TICK
var cogs: Array = []             # {hub, dir, phase, teeth: [Mover], last_q}
var weights: Array = []          # {cell, anchor, rod, phase, bob, prev, angle}
var boss_pivots: Array = []      # {cell, anchor, rod}: a Y in a boss arena (the boss's own)
var swings: Array = []           # [Mover]
var icicles: Array = []          # {cell, hang, tip, state, t, vy, safe}
var patches: Array = []          # rime: {cells, rect, state, p, last, t, fire, heard}
var belts_rev: Array = []        # {x0, x1, at: ftime when it flips, done}
var flips: Array = []            # belt_flip: {x0, x1, every (beats), next (the flip to come, from 1)}
var ice_runs: Array = []         # [{x0, x1, y}] px: the ice tops that reflect
var painted := false             # the theme's painter draws the ice, rime and belt bodies
var _ice: Array[Vector2i] = []
var _belt: Array[Vector2i] = []
var _thin: Array[Vector2i] = []  # crumbles, drawn as thin ice in W4
var _rime_of := {}               # Vector2i -> patch index
var _tex := {}
var _hit_cool := 0.0
var _slide_t := 0.0
var _belt_t := 0.0
var _squeak := false
var _beat := -1
var _on_beat := false
var _arena := {}
var _bark_at := {}               # feature -> {first: x, sign: x (its sign's, or BARK_LEAD before first), done: bool}
var _bark_t := -100.0
var _tb := TriBatch.new()
var _gb := TriBatch.new()
var vents: Array = []            # false stone just over a cog's apex (a secret's duct): {cell, p, hiss}
var _lit_altars := 0
var _rode_tooth := false
var _pal := {}                   # the theme's palette (brass, brass_sh, iron) for the rods and arms


func build(w: Node, lv: RefCounted) -> void:
	super.build(w, lv)
	tick = float(lv.tick) if float(lv.tick) > 0.0 else LevelData.TICK
	var th := str(lv.theme)
	painted = Themes.has_theme(th) and Themes.painter(th) != null
	_pal = Themes.palette(th) if Themes.has_theme(th) else {}
	for n in PROPS:
		var p := "res://art/props/%s.svg" % n
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	for e in lv.entities:
		if e["kind"] == "boss" and str(lv.boss) in PIVOT_BOSSES:
			_arena = Arena.find(lv, LevelData.cell_floor(e["cell"]))
	var first := {}
	for y in lv.height:
		for x in lv.width:
			var t: int = lv.tile(x, y)
			var c := Vector2i(x, y)
			if t == LevelData.ICE or t == LevelData.FROST_LEDGE:
				_ice.append(c)
				_first(first, "ice", x)
			elif LevelData.is_belt(t):
				_belt.append(c)
				_first(first, "belt", x)
			elif t == LevelData.RIME:
				_first(first, "rime", x)
				if not _rime_of.has(c):
					_flood_rime(c)
			elif t == LevelData.CRUMBLE:
				_thin.append(c)
	_find_ice_runs()
	flips = belt_flips(str(lv.headers.get("belt_flip", "")) if lv.get("headers") is Dictionary else "")
	var n_weight := 0
	var n_swing := 0
	for e in lv.entities:
		var cell: Vector2i = e["cell"]
		match e["kind"]:
			"cog":
				var hub := LevelData.cell_center(cell)
				var ph := float(lv.cog_phase.get(cell.x, 0.0))
				var teeth := Movers.cog(hub, int(e.get("dir", 1)), ph, 4, Movers.ORBIT_R, knob("cog_period"))
				for m in teeth:
					m.owner = self
					w.add_mover(m)
				cogs.append({"hub": hub, "dir": int(e.get("dir", 1)), "phase": ph, "teeth": teeth, "last_q": NO_Q})
				_first(first, "cog", cell.x - 3)
			"swing":
				var n := int(e.get("length", 1))
				var anchor := _anchor_above(cell, n)
				var sph := float(lv.weight_phase.get(cell.x, 0.5 * (n_swing % 2)))
				n_swing += 1
				var m := Movers.swing(anchor, Vector2(cell.x * TILE, cell.y * TILE), n, sph, Movers.SWING_AMP, knob("swing_period"))
				m.owner = self
				w.add_mover(m)
				swings.append(m)
				_first(first, "swing", cell.x - 3)
			"weight":
				var top := Vector2((cell.x + 0.5) * TILE, cell.y * TILE)
				var rod := _rod_of(cell)
				if _in_arena(top):
					boss_pivots.append({"cell": cell, "anchor": top, "rod": rod})
					continue
				var wph: float = float(lv.weight_phase.get(cell.x, 0.5 * (n_weight % 2)))
				n_weight += 1
				var bob := top + Vector2(0, rod)
				weights.append({"cell": cell, "anchor": top, "rod": rod, "phase": wph, "bob": bob, "prev": bob, "angle": 0.0})
				_first(first, "weight", cell.x - 2)
			"icicle":
				var hang := Vector2((cell.x + 0.5) * TILE, cell.y * TILE)
				icicles.append({"cell": cell, "hang": hang, "tip": hang, "state": "hang", "t": 0.0, "vy": 0.0, "safe": false})
	for wt in weights:
		_place_weight(wt)
		wt["prev"] = wt["bob"]
	# A vent: false stone over a cog's apex (a way up into the roof). Steam
	# puffs from it in his light, and it hisses near him.
	for c in cogs:
		var hub: Vector2 = c["hub"]
		var top_row := floori((hub.y - Movers.ORBIT_R - 6.0) / TILE)
		var hx := floori(hub.x / TILE)
		for x in range(hx - 1, hx + 2):
			for y in range(top_row - 4, top_row + 1):
				if lv.tile(x, y) == LevelData.FALSE_STONE and not LevelData.is_solid(lv.tile(x, y + 1)):
					vents.append({"cell": Vector2i(x, y), "p": Vector2((x + 0.5) * TILE, (y + 1) * TILE), "hiss": 0.0})
	# The first-time barks: at the teaching sign before each feature's first
	# cell, or BARK_LEAD tiles before it where no sign stands, else on the
	# next stone landing past that. A feature met again in a later level is
	# skipped by its bark heard already (_heard), not by a missing sign.
	var signs := []
	for e in lv.entities:
		if e["kind"] == "sign":
			signs.append(int(e["cell"].x))
	for f in first:
		var fx: int = first[f]
		var best := -1
		for sx in signs:
			if sx <= fx + 2 and sx >= fx - SIGN_BEFORE and sx > best:
				best = sx
		_bark_at[f] = {"first": fx, "sign": best if best >= 0 else maxi(fx - BARK_LEAD, 0), "done": false}


func _first(d: Dictionary, what: String, x: int) -> void:
	if not d.has(what) or x < int(d[what]):
		d[what] = maxi(x, 0)


func _flood_rime(start: Vector2i) -> void:
	## One patch: the rime cells joined to start (side by side or stacked).
	var idx := patches.size()
	var cells: Array[Vector2i] = []
	var todo: Array[Vector2i] = [start]
	_rime_of[start] = idx
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		cells.append(c)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + d
			if not _rime_of.has(nc) and level.tile(nc.x, nc.y) == LevelData.RIME:
				_rime_of[nc] = idx
				todo.append(nc)
	var r := Rect2(cells[0].x * TILE, cells[0].y * TILE, TILE, TILE)
	for c in cells:
		r = r.merge(Rect2(c.x * TILE, c.y * TILE, TILE, TILE))
	patches.append({"cells": cells, "rect": r, "state": "solid", "p": 0.0, "last": -100.0, "t": 0.0, "fire": -1.0, "heard": false})


func _find_ice_runs() -> void:
	## The ice tops (ice or frosted ledge with open air above) in runs: the
	## spans the ice reflects lights in.
	for y in level.height:
		var x := 0
		while x < level.width:
			if _ice_top(x, y):
				var x1 := x
				while _ice_top(x1 + 1, y):
					x1 += 1
				ice_runs.append({"x0": float(x * TILE), "x1": float((x1 + 1) * TILE), "y": float(y * TILE)})
				x = x1 + 1
			else:
				x += 1


func refresh_ice() -> void:
	## A boss changed the ice (level.set_tile): its reflections follow. (The
	## stand-in look reads the tiles each frame already.)
	ice_runs.clear()
	_find_ice_runs()


func _ice_top(x: int, y: int) -> bool:
	if x < 0 or x >= level.width:
		return false
	var t: int = level.tile(x, y)
	return (t == LevelData.ICE or t == LevelData.FROST_LEDGE) and not LevelData.is_solid(level.tile(x, y - 1))


func _in_arena(p: Vector2) -> bool:
	return not _arena.is_empty() and p.x >= float(_arena["left"]) and p.x < float(_arena["right"])


func _rod_of(cell: Vector2i) -> float:
	## From the top of the Y cell down to 20 px above the first floor below,
	## 96-192 px.
	var top := float(cell.y * TILE)
	var floor_y := float(level.height * TILE)
	for yy in range(cell.y + 1, level.height + 1):
		if LevelData.is_floor(level.tile(cell.x, yy)):
			floor_y = yy * TILE
			break
	return clampf(floor_y - 20.0 - top, ROD_MIN, ROD_MAX)


func _place_weight(wt: Dictionary) -> void:
	var a := weight_angle(wt)
	wt["angle"] = a
	wt["bob"] = (wt["anchor"] as Vector2) + Vector2(sin(a), cos(a)) * float(wt["rod"])


func _anchor_above(cell: Vector2i, n: int) -> Vector2:
	## A swing's anchor: the underside of the first solid cell 3-6 rows over
	## its middle (else 160 px up).
	var mx := cell.x + n / 2
	var mid := Vector2((cell.x + n * 0.5) * TILE, cell.y * TILE)
	for dy in range(1, 9):
		if LevelData.is_solid(level.tile(mx, cell.y - dy)):
			return Vector2(mid.x, (cell.y - dy + 1) * TILE)
	return mid - Vector2(0, 160.0)


# ---------------------------------------------------------------- queries

func slick_at(p: Vector2) -> bool:
	return LevelData.is_slick(level.tile(floori(p.x / TILE), floori(p.y / TILE)))


func reverse_belts(x0: int, x1: int, quiet := false) -> void:
	## A boss or a script flips a run of belts, after a REVERSE_TELL tell
	## (the teeth flash, a clunk; quiet: no clunk, for a belt_flip far off).
	belts_rev.append({"x0": mini(x0, x1), "x1": maxi(x0, x1), "at": ftime() + REVERSE_TELL, "done": false})
	if not quiet:
		world._sfx("belt_reverse")


static func belt_flips(value: String) -> Array:
	## The belt_flip header, "x0-x1=N, ...": [{x0, x1, every, next}] (a bad part is skipped).
	var out := []
	for part in value.split(","):
		var kv := part.strip_edges().split("=")
		if kv.size() != 2 or not kv[1].strip_edges().is_valid_int() or int(kv[1]) <= 0:
			continue
		var ab := kv[0].strip_edges().split("-")
		if ab.size() != 2 or not ab[0].strip_edges().is_valid_int() or not ab[1].strip_edges().is_valid_int():
			continue
		out.append({"x0": mini(int(ab[0]), int(ab[1])), "x1": maxi(int(ab[0]), int(ab[1])), "every": int(kv[1]), "next": 1})
	return out


func _step_flips() -> void:
	## Each belt_flip run flips on every N-th beat (its tell starting
	## REVERSE_TELL before it), the clunk heard only near him.
	for f in flips:
		var guard := 0
		while ftime() >= float(int(f["next"]) * int(f["every"])) * tick - REVERSE_TELL and guard < 4:
			guard += 1
			var mid := (int(f["x0"]) + int(f["x1"]) + 1) * 0.5 * TILE
			var pl := player()
			reverse_belts(int(f["x0"]), int(f["x1"]), pl == null or absf(pl.position.x - mid) > view().size.x)
			f["next"] = int(f["next"]) + 1


func belt_dir(cell: Vector2i, dir: int) -> int:
	var d := dir
	for r in belts_rev:
		if r["done"] and cell.x >= int(r["x0"]) and cell.x <= int(r["x1"]):
			d = -d
	return d


func beat() -> int:
	## The ticks so far.
	return floori(ftime() / tick)


func beat_phase() -> float:
	## Seconds into this beat.
	return fmod(ftime(), tick)


func pulse() -> float:
	## 1 on the beat, fading to 0 over PULSE (the lamps' and hubs' twin of the tick).
	return clampf(1.0 - beat_phase() / PULSE, 0.0, 1.0)


func weight_angle(wt: Dictionary) -> float:
	return WEIGHT_AMP * sin(TAU * (ftime() / knob("weight_period") + float(wt["phase"])))


func melt_time() -> float:
	## Rime's melt time now: 0.4 + rime_k x (1 - f), f his life share.
	var pl := player()
	var f := 1.0
	if pl != null and float(pl.max_hp) > 0.0:
		f = clampf(float(pl.hp) / float(pl.max_hp), 0.0, 1.0)
	return RIME_BASE + knob("rime_k") * (1.0 - f)


func rime_patch(cell: Vector2i) -> Dictionary:
	## The patch a rime cell belongs to ({} for none).
	var i = _rime_of.get(cell)
	return patches[i] if i != null else {}


# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	var b := beat()
	_on_beat = b != _beat
	_beat = b
	_hit_cool = maxf(_hit_cool - dt, 0.0)
	if not flips.is_empty():
		_step_flips()
	var cancel := false
	for r in belts_rev:
		if not r["done"] and ftime() >= float(r["at"]):
			r["done"] = true
			# Two flips of the same run cancel (a belt_flip's list stays short).
			for o in belts_rev:
				if not is_same(o, r) and o["done"] and not o.get("gone", false) and int(o["x0"]) == int(r["x0"]) and int(o["x1"]) == int(r["x1"]):
					o["gone"] = true
					r["gone"] = true
					cancel = true
					break
	if cancel:
		belts_rev = belts_rev.filter(func(r): return not r.get("gone", false))
	var pl := player()
	var near := Vector2(INF, INF)
	if pl != null:
		near = pl.center()
	for wt in weights:
		var was: float = wt["angle"]
		wt["prev"] = wt["bob"]
		_place_weight(wt)
		var a: float = wt["angle"]
		var d: float = (wt["bob"] as Vector2).distance_to(near)
		if signf(a) != signf(was) and d < HEAR:
			world._sfx("pendulum_swing", 1.0, 0.0, 1.0 - d / HEAR)
		elif absf(a) > WEIGHT_AMP * 0.985 and absf(was) <= WEIGHT_AMP * 0.985 and d < GEAR_HEAR:
			world._sfx("gear_clunk", 1.0, 0.0, 0.5 * (1.0 - d / GEAR_HEAR))
	_step_cogs(near)
	_step_icicles(dt)
	_step_rime(dt)
	if _w4():
		# The carillon's quarter chime as an altar lights.
		var lit := 0
		for a in world.altars:
			if bool(a["lit"]):
				lit += 1
		if lit > _lit_altars:
			world._sfx("clock_chime")
		_lit_altars = lit
	if pl != null:
		# A tooth catching him: the gear's clunk.
		var on_tooth: bool = pl.riding != null and str(pl.riding.tag) == "cog"
		if on_tooth and not _rode_tooth:
			world._sfx("gear_clunk", 1.0, 0.0, 0.7)
		_rode_tooth = on_tooth
		for v in vents:
			v["hiss"] = maxf(float(v["hiss"]) - dt, 0.0)
			var d: float = (v["p"] as Vector2).distance_to(near)
			if d < 200.0 and float(v["hiss"]) <= 0.0 and _on_beat and beat() % 4 == 0:
				v["hiss"] = 1.0
				world._sfx("rime_melt", 1.0, 0.0, 0.5 * (1.0 - d / 200.0))
	if pl != null:
		_step_sounds(dt, pl)
		_step_barks(pl)


func _step_cogs(near: Vector2) -> void:
	## A tooth passing the top: gear_tick near him.
	for c in cogs:
		var turns: float = float(c["phase"]) + float(c["dir"]) * ftime() / knob("cog_period")
		var q := floori(turns * 4.0)
		var d: float = (c["hub"] as Vector2).distance_to(near)
		if int(c["last_q"]) != q:
			if int(c["last_q"]) != NO_Q and d < GEAR_HEAR:
				world._sfx("gear_tick", 1.0, 0.0, 1.0 - d / GEAR_HEAR)
			c["last_q"] = q


func _step_sounds(dt: float, pl: Node2D) -> void:
	_slide_t = maxf(_slide_t - dt, 0.0)
	_belt_t = maxf(_belt_t - dt, 0.0)
	if pl.alive and bool(pl.get("on_ice")):
		var vx: float = pl.velocity.x
		var pad = pl.get("pad")
		var pd: Dictionary = pad if pad is Dictionary else {}
		var want := int(pd.get("right", false)) - int(pd.get("left", false))
		if absf(vx) > SLIDE_V and want != int(signf(vx)) and _slide_t <= 0.0:
			_slide_t = SLIDE_EVERY
			world._sfx("ice_slide")
		var turning := want != 0 and absf(vx) > 60.0 and want != int(signf(vx))
		if turning and not _squeak:
			world._sfx("ice_squeak")
		_squeak = turning
	else:
		_squeak = false
	if _belt_t <= 0.0 and not _belt.is_empty():
		var best := INF
		var v := view().grow(HEAR)
		var c0: Vector2 = pl.center()
		for c in _belt:
			var p := LevelData.cell_center(c)
			if v.has_point(p):
				best = minf(best, p.distance_to(c0))
		if best < HEAR:
			_belt_t = BELT_EVERY
			world._sfx("belt_run", 1.0, 0.0, 1.0 - best / HEAR)


func _step_barks(pl: Node2D) -> void:
	if world.get("mode") != null:
		return   # a mode's rooms teach nothing (as deep.gd's _bark)
	if _bark_at.is_empty() or not pl.alive or not pl.on_floor or pl.riding != null or bool(pl.get("climbing")):
		return
	var since := ftime() - _bark_t
	if since < SIGN_GAP:
		return
	var px: float = pl.position.x
	var under: int = level.tile(floori(px / TILE), floori((pl.position.y + 1.0) / TILE))
	var stone := LevelData.is_safe(under) and not LevelData.is_slick(under)
	var pick := ""
	for f in _bark_at:
		var b: Dictionary = _bark_at[f]
		if b["done"]:
			continue
		var key: String = BARKS[f]
		if _heard(key):
			b["done"] = true   # heard in an earlier level: nothing to wait for
			continue
		# At its sign (where he reads it) or its BARK_LEAD spot, or else
		# once the gap has passed.
		var at_sign: bool = absf(px - (int(b["sign"]) + 0.5) * TILE) < 44.0
		if not at_sign and since < BARK_GAP:
			continue
		# Passed the sign in the air: the next landing on stone past it.
		var past: bool = stone and px > (int(b["sign"]) + 0.5) * TILE and px < (int(b["first"]) + 40) * TILE
		# Two due on one landing: the one whose spot he passed last (what's
		# just ahead of him), not one he has already crossed.
		if (at_sign or past) and (pick == "" or int(b["sign"]) > int(_bark_at[pick]["sign"])):
			pick = f
	if pick != "":
		_bark_at[pick]["done"] = true
		_bark_t = ftime()
		world.bark(BARKS[pick])


func _heard(key: String) -> bool:
	var st = load(STORY) if ResourceLoader.exists(STORY) else null
	return st != null and st.has_method("bark_heard") and bool(st.bark_heard(key))


# ---------------------------------------------------------------- icicles

func _step_icicles(dt: float) -> void:
	var pl := player()
	for ic in icicles:
		match str(ic["state"]):
			"hang":
				if pl != null and pl.alive and _sees(ic, pl.center()):
					ic["state"] = "tell"
					ic["t"] = 0.0
					world._tell_sfx("icicle_tell", knob("icicle_tell"))
			"tell":
				ic["t"] = float(ic["t"]) + dt
				if float(ic["t"]) >= knob("icicle_tell"):
					_drop(ic, false)
			"fall":
				ic["vy"] = minf(float(ic["vy"]) + ICICLE_G * dt, ICICLE_VMAX)
				var tip: Vector2 = ic["tip"]
				tip.y += float(ic["vy"]) * dt
				ic["tip"] = tip
				var t: int = level.tile(floori(tip.x / TILE), floori(tip.y / TILE))
				if LevelData.is_floor(t) or tip.y > level.height * TILE + 40.0:
					_shatter(ic, Vector2(tip.x, floorf(tip.y / TILE) * TILE))
			"gone":
				ic["t"] = float(ic["t"]) - dt
				if float(ic["t"]) <= 0.0:
					ic["state"] = "grow"
					ic["t"] = 0.0
			"grow":
				ic["t"] = float(ic["t"]) + dt
				if float(ic["t"]) >= ICICLE_GROW:
					ic["state"] = "hang"
					ic["tip"] = ic["hang"]


func _sees(ic: Dictionary, c: Vector2) -> bool:
	## His centre under it, within ICICLE_REACH across and ICICLE_ROWS down,
	## with nothing solid between.
	var hang: Vector2 = ic["hang"]
	if absf(c.x - hang.x) > ICICLE_REACH or c.y <= hang.y or c.y > hang.y + (ICICLE_ROWS + 1) * TILE:
		return false
	var cx := floori(hang.x / TILE)
	for y in range(int(ic["cell"].y), floori(c.y / TILE)):
		if LevelData.is_solid(level.tile(cx, y)):
			return false
	return true


func _drop(ic: Dictionary, safe: bool) -> void:
	ic["state"] = "fall"
	ic["vy"] = 0.0
	ic["safe"] = safe
	ic["tip"] = (ic["hang"] as Vector2) + Vector2(0, ICICLE_H)
	world._sfx("icicle_fall")


func _shatter(ic: Dictionary, at: Vector2) -> void:
	ic["state"] = "gone"
	ic["t"] = knob("icicle_regrow")
	world._sfx("icicle_shatter")
	if world.glow:
		world.glow.burst(at, 10, FROST, 120.0, 0.4, 500.0, 2.0, 60.0)


func icicle_rect(ic: Dictionary) -> Rect2:
	## A falling icicle's hurt box (its tip at the bottom).
	var tip: Vector2 = ic["tip"]
	return Rect2(tip.x - ICICLE_W * 0.5, tip.y - ICICLE_H, ICICLE_W, ICICLE_H)


func _hang_rect(ic: Dictionary) -> Rect2:
	var hang: Vector2 = ic["hang"]
	return Rect2(hang.x - ICICLE_W * 0.5 - 2.0, hang.y, ICICLE_W + 4.0, ICICLE_H + 2.0)


# ---------------------------------------------------------------- rime

func _step_rime(dt: float) -> void:
	if patches.is_empty():
		return
	var hold := knob("rime_hold")
	var fires: Array = []
	for h in world.hazards:
		if str(h.get("kind", "")) == "fire" and float(h.get("delay", 0.0)) <= 0.0 and float(h.get("life", 0.0)) > 0.0:
			fires.append((h["rect"] as Rect2).grow(RIME_GROW))
	var lamps: Array = []
	var lf = world.get("features")
	if lf != null and "lanterns" in lf:
		for l in lf.lanterns:
			if bool(l.get("lit", false)):
				lamps.append(l["flame"])
	for i in patches.size():
		var pt: Dictionary = patches[i]
		match str(pt["state"]):
			"solid":
				if float(pt["fire"]) < 0.0 and (not fires.is_empty() or not lamps.is_empty()) and _fire_touches(pt, fires, lamps):
					pt["fire"] = FIRE_MELT
					world._sfx("rime_melt")
				if float(pt["fire"]) >= 0.0:
					pt["fire"] = float(pt["fire"]) - dt
					if float(pt["fire"]) <= 0.0:
						_melt(i)
						continue
				# Progress holds a while between touches, then drains.
				if float(pt["p"]) > 0.0 and ftime() - float(pt["last"]) > hold:
					pt["p"] = maxf(float(pt["p"]) - dt, 0.0)
					if float(pt["p"]) <= 0.0:
						pt["heard"] = false
			"gone":
				pt["t"] = float(pt["t"]) - dt
				if float(pt["t"]) <= 0.0 and _on_beat:
					# The refreeze tell starts on a beat.
					pt["state"] = "tell"
					pt["t"] = REFREEZE_TELL
					if view().grow(TILE * 4).intersects(pt["rect"]):
						world._sfx("rime_freeze")
			"tell":
				pt["t"] = float(pt["t"]) - dt
				if float(pt["t"]) <= 0.0 and not _body_in(pt):
					_freeze(i)


func _fire_touches(pt: Dictionary, fires: Array, lamps: Array) -> bool:
	for c in pt["cells"]:
		var cr := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
		for f in fires:
			if (f as Rect2).intersects(cr):
				return true
		for lp in lamps:
			var q := Vector2(clampf(lp.x, cr.position.x, cr.end.x), clampf(lp.y, cr.position.y, cr.end.y))
			if q.distance_to(lp) <= LAMP_MELT:
				return true
	return false


func _rime_touch(pl: Node2D) -> void:
	if patches.is_empty():
		return
	var r: Rect2 = (pl.rect() as Rect2).grow(RIME_GROW)
	var seen := {}
	for y in range(floori(r.position.y / TILE), floori(r.end.y / TILE) + 1):
		for x in range(floori(r.position.x / TILE), floori(r.end.x / TILE) + 1):
			var i = _rime_of.get(Vector2i(x, y))
			if i == null or seen.has(i):
				continue
			var pt: Dictionary = patches[i]
			if pt["state"] != "solid" or not Rect2(x * TILE, y * TILE, TILE, TILE).intersects(r):
				continue
			seen[i] = true
			if not bool(pt["heard"]):
				pt["heard"] = true
				world._sfx("rime_melt")
			pt["p"] = float(pt["p"]) + 1.0 / 120.0
			pt["last"] = ftime()
			if float(pt["p"]) >= melt_time() - 0.0001:
				_melt(i)


func _melt(i: int) -> void:
	var pt: Dictionary = patches[i]
	pt["state"] = "gone"
	pt["t"] = knob("rime_refreeze")
	pt["p"] = 0.0
	pt["fire"] = -1.0
	pt["heard"] = false
	for c in pt["cells"]:
		level.set_tile(c, LevelData.AIR)
	for c in pt["cells"]:
		world._redraw_at(c.x, c.y)
	if world.glow:
		var r: Rect2 = pt["rect"]
		world.glow.burst(r.get_center(), 8 + mini(int(r.size.x * r.size.y / 512.0), 16), FROST, 70.0, 0.6, -60.0, 2.2, 40.0)
	if world.has_method("note_feature"):
		world.note_feature("rime")


func _freeze(i: int) -> void:
	var pt: Dictionary = patches[i]
	pt["state"] = "solid"
	pt["p"] = 0.0
	for c in pt["cells"]:
		level.restore_tile(c)
	for c in pt["cells"]:
		world._redraw_at(c.x, c.y)


func _body_in(pt: Dictionary) -> bool:
	## Is any body in the patch's cells? (It never refreezes into one.)
	var rects: Array = []
	var pl := player()
	if pl != null and pl.alive:
		rects.append(pl.rect())
	for e in world.enemies:
		if e.alive:
			rects.append(e.rect())
	for c in pt["cells"]:
		var cr := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
		for r in rects:
			if (r as Rect2).intersects(cr):
				return true
	return false


# ---------------------------------------------------------------- touch, strike, shots

func safe_vetoed(feet: Vector2) -> bool:
	## A Waxby standing at feet is in some weight's reach over its whole
	## swing (its bob, r WEIGHT_R, over +-WEIGHT_AMP): the World won't
	## remember the spot as last_safe (player._track_safe).
	var r := Rect2(feet.x - 10.0, feet.y - 38.0, 20.0, 38.0).grow(WEIGHT_R + 4.0)
	for wt in weights:
		var anchor: Vector2 = wt["anchor"]
		var rod := float(wt["rod"])
		if absf(anchor.x - feet.x) > rod + 64.0:
			continue
		for i in 21:
			var a := lerpf(-WEIGHT_AMP, WEIGHT_AMP, i / 20.0)
			if r.has_point(anchor + Vector2(sin(a), cos(a)) * rod):
				return true
	return false


func touch(pl: Node2D) -> void:
	if not pl.alive:
		return
	_rime_touch(pl)
	var pr: Rect2 = pl.rect()
	for ic in icicles:
		if ic["state"] == "fall" and not bool(ic["safe"]) and icicle_rect(ic).intersects(pr):
			var dmg: float = Combat.enemy_hit(knob("icicle_dmg"), world.area, world.diff, world.strength)
			world.hurt_player(dmg, (ic["tip"] as Vector2).x, "icicle", null, {"feature": "icicle", "move": "icicle", "shot": true})
			_shatter(ic, ic["tip"])
	if _hit_cool > 0.0:
		return
	for wt in weights:
		var bob: Vector2 = wt["bob"]
		var near := Vector2(clampf(bob.x, pr.position.x, pr.end.x), clampf(bob.y, pr.position.y, pr.end.y))
		if near.distance_to(bob) > WEIGHT_R:
			continue
		# Knocked along its swing (the way it's moving), but on Dusk never
		# toward a pit edge close by (and no knock at all when both ways are).
		var dir := signf(bob.x - (wt["prev"] as Vector2).x)
		if dir == 0.0:
			dir = signf(pl.position.x - bob.x) if pl.position.x != bob.x else 1.0
		var opts := {"feature": "weight", "move": "weight"}
		if world.diff == "dusk" and _pit_near(pl, int(dir)):
			if _pit_near(pl, -int(dir)):
				opts["no_knock"] = true
			else:
				dir = -dir
		var dmg: float = Combat.enemy_hit(knob("weight_dmg"), world.area, world.diff, world.strength)
		if world.hurt_player(dmg, pl.position.x - dir * 20.0, "hit", null, opts):
			_hit_cool = 0.5
		return


func _pit_near(pl: Node2D, dir: int) -> bool:
	## Is there a floor edge within PIT_GUARD tiles that way on his row (and
	## no wall before it)?
	var ty := floori((pl.position.y + 1.0) / TILE)
	var tx := floori(pl.position.x / TILE)
	for k in range(1, PIT_GUARD + 1):
		if LevelData.is_solid(level.tile(tx + dir * k, ty - 1)):
			return false   # a wall that way first
		if not LevelData.is_floor(level.tile(tx + dir * k, ty)):
			return true
	return false


func strike(r: Rect2, _attack_id: int) -> void:
	## A swing knocks a hanging icicle down early (harmless).
	for ic in icicles:
		if (ic["state"] == "hang" or ic["state"] == "tell") and _hang_rect(ic).intersects(r):
			_drop(ic, true)


func shot_hit(shot: Dictionary) -> void:
	var p: Vector2 = shot["pos"]
	if str(shot.get("owner", "")) == "player":
		for ic in icicles:
			if (ic["state"] == "hang" or ic["state"] == "tell") and _hang_rect(ic).grow(4.0).has_point(p):
				_drop(ic, true)
				shot["life"] = 0.0
				return
	# Fire (a flare, or a shot that says so) melts rime it reaches.
	if patches.is_empty() or not (str(shot.get("kind", "")) == "flare" or bool(shot.get("fire", false))):
		return
	var r := Rect2(p - Vector2(8, 8), Vector2(16, 16))
	for y in range(floori(r.position.y / TILE), floori(r.end.y / TILE) + 1):
		for x in range(floori(r.position.x / TILE), floori(r.end.x / TILE) + 1):
			var i = _rime_of.get(Vector2i(x, y))
			if i != null and patches[i]["state"] == "solid" and float(patches[i]["fire"]) < 0.0:
				patches[i]["fire"] = FIRE_MELT
				world._sfx("rime_melt")


func _w4() -> bool:
	## A World 4 level, or a room of the Descent's carillon biome (a mode
	## sets world_n as it builds).
	var wn = world.get("world_n") if world != null else null
	return int(level.world) == 4 or (wn != null and int(wn) == 4)


func stood_on(who: Node2D, x: int, y: int) -> void:
	## Thin ice (a W4 crumble) cracks as it starts to go.
	if _thin.is_empty() or who != player() or level.tile(x, y) != LevelData.CRUMBLE or not _w4():
		return
	var cr = world.get("crumbles")
	if cr is Dictionary and (cr as Dictionary).has(Vector2i(x, y)) and str(cr[Vector2i(x, y)]["state"]) == "idle":
		world._sfx("ice_crack")


func on_respawn() -> void:
	## A snuff: the icicles that were coming down are back up; the rest of
	## the clockwork keeps its time.
	for ic in icicles:
		if ic["state"] == "tell" or ic["state"] == "fall":
			ic["state"] = "hang"
			ic["tip"] = ic["hang"]
	_hit_cool = 0.0


func on_boss_reset() -> void:
	## A retry: the belts run their own way again, the icicles hang, the rime
	## is back (a belt_flip run keeps its beat: flipped while its flips so far
	## are odd).
	belts_rev.clear()
	for f in flips:
		if (int(f["next"]) - 1) % 2 == 1:
			belts_rev.append({"x0": f["x0"], "x1": f["x1"], "at": ftime(), "done": true})
	on_respawn()
	for i in patches.size():
		if patches[i]["state"] != "solid" and not _body_in(patches[i]):
			_freeze(i)


# ---------------------------------------------------------------- lights

func lights() -> Array:
	var out := []
	var v := view().grow(120.0)
	var k := pulse()
	for wt in weights:
		if v.has_point(wt["bob"]):
			out.append({"p": wt["bob"], "r": 60.0 + 6.0 * k, "s": 0.5, "tag": "lamp", "gameplay": false})
	for ic in icicles:
		if ic["state"] == "tell" and v.has_point(ic["hang"]):
			out.append({"p": (ic["hang"] as Vector2) + Vector2(0, 16), "r": 24.0, "s": 0.8, "kind": "tell", "gameplay": false})
	return out


func reflectors() -> Array:
	var out := []
	var v := view().grow(64.0)
	for r in ice_runs:
		if float(r["x1"]) >= v.position.x and float(r["x0"]) <= v.end.x and float(r["y"]) >= v.position.y and float(r["y"]) <= v.end.y:
			out.append({"x0": r["x0"], "x1": r["x1"], "y": r["y"], "tint": REFLECT_TINT, "k": REFLECT_K})
	return out


# ---------------------------------------------------------------- drawing

func draw_under(ci: CanvasItem) -> void:
	var v := view().grow(TILE * 2)
	if not painted:
		_draw_ice_bodies(ci, v, _w4())
	_draw_rime(ci, v)
	_draw_belts(ci, v)
	# The rods and arms first (TriBatch), then the props over them (A1's
	# Preview in tests/test_world_art.gd: the order and sizes it was drawn to).
	for c in cogs:
		if v.grow(128).has_point(c["hub"]):
			_draw_cog_arms(c)
	for m in swings:
		if v.grow(200).intersects(m.rect()):
			_draw_swing_rod(m)
	for wt in weights:
		if v.grow(220).has_point(wt["anchor"]):
			_draw_weight_rod(wt)
	_tb.flush(ci)
	for c in cogs:
		if v.grow(128).has_point(c["hub"]):
			_draw_cog(ci, c)
	for m in swings:
		if v.grow(200).intersects(m.rect()):
			_draw_swing(ci, m)
	for wt in weights:
		if v.grow(220).has_point(wt["anchor"]):
			_draw_weight(ci, wt)
	for ic in icicles:
		if v.grow(TILE).has_point(ic["hang"]):
			_draw_icicle(ci, ic)
	for vt in vents:
		if v.has_point(vt["p"]):
			_draw_steam(ci, vt)
	_tb.flush(ci)


func _draw_steam(_ci: CanvasItem, vt: Dictionary) -> void:
	## Puffs of steam curling down out of the vent, on the tick.
	var base: Vector2 = vt["p"]
	for k in 4:
		var age := fmod(ftime() * 0.7 + k * 0.25, 1.0)
		var q := base + Vector2(sin(ftime() * 1.3 + k * 1.7) * 6.0, 6.0 + age * 34.0)
		_tb.circle(q, 4.0 + age * 7.0, Color(0.92, 0.95, 1.0, 0.32 * (1.0 - age)), 10)


func _draw_ice_bodies(ci: CanvasItem, v: Rect2, thin_ice := true) -> void:
	# The cells in view, read now (a boss may add ice as it fights: the
	# Tinker's Midnight grows his floor's patches).
	var cells: Array[Vector2i] = []
	for y in range(maxi(floori(v.position.y / TILE), 0), mini(floori(v.end.y / TILE) + 1, level.height)):
		for x in range(maxi(floori(v.position.x / TILE), 0), mini(floori(v.end.x / TILE) + 1, level.width)):
			if LevelData.is_slick(level.tile(x, y)):
				cells.append(Vector2i(x, y))
	for c in cells:
		var p := Vector2(c.x * TILE, c.y * TILE)
		var t: int = level.tile(c.x, c.y)
		if t == LevelData.ICE:
			var top := not LevelData.is_solid(level.tile(c.x, c.y - 1))
			ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), ICE.darkened(0.2) if top else ICE_DEEP)
			if top:
				ci.draw_rect(Rect2(p, Vector2(TILE, 5)), FROST)
				ci.draw_rect(Rect2(p + Vector2(0, 5), Vector2(TILE, 2)), ICE.lightened(0.2))
				ci.draw_rect(Rect2(p + Vector2(4 + (c.x * 7) % 12, 10), Vector2(10, 2)), Color(1, 1, 1, 0.45))
			else:
				ci.draw_rect(Rect2(p + Vector2(6 + (c.y * 5) % 14, 12), Vector2(8, 2)), Color(1, 1, 1, 0.18))
			if not LevelData.is_solid(level.tile(c.x - 1, c.y)):
				ci.draw_rect(Rect2(p, Vector2(2, TILE)), OUTLINE)
			if not LevelData.is_solid(level.tile(c.x + 1, c.y)):
				ci.draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), OUTLINE)
		elif t == LevelData.FROST_LEDGE:
			ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 12)), OUTLINE)
			ci.draw_rect(Rect2(p, Vector2(TILE, 10)), ICE.darkened(0.1))
			ci.draw_rect(Rect2(p, Vector2(TILE, 3)), FROST)
			# Little icicle teeth under it (a frosted ledge, not stone).
			for k in 3:
				var ix := p.x + 5.0 + k * 10.0
				_tb.tri(Vector2(ix, p.y + 10), Vector2(ix + 5, p.y + 10), Vector2(ix + 2.5, p.y + 16 + (k % 2) * 3), ICE)
	for c in (_thin if thin_ice else []):
		var p := Vector2(c.x * TILE, c.y * TILE)
		if not v.has_point(p):
			continue
		if world.has_method("ledge_present") and not world.ledge_present(c.x, c.y):
			continue
		var sh: Vector2 = world.ledge_shake(c.x, c.y) if world.has_method("ledge_shake") else Vector2.ZERO
		ci.draw_rect(Rect2(p + sh + Vector2(0, -1), Vector2(TILE, 10)), OUTLINE)
		ci.draw_rect(Rect2(p + sh, Vector2(TILE, 8)), Color(ICE, 0.85))
		ci.draw_rect(Rect2(p + sh, Vector2(TILE, 2)), FROST)
		# Its cracks (thin ice looks thin).
		ci.draw_rect(Rect2(p + sh + Vector2(9, 2), Vector2(1, 5)), OUTLINE)
		ci.draw_rect(Rect2(p + sh + Vector2(10, 4), Vector2(8, 1)), OUTLINE)
		ci.draw_rect(Rect2(p + sh + Vector2(22, 2), Vector2(1, 4)), OUTLINE)


func _draw_rime(ci: CanvasItem, v: Rect2) -> void:
	for pt in patches:
		var r: Rect2 = pt["rect"]
		if not v.intersects(r):
			continue
		match str(pt["state"]):
			"solid":
				var k := clampf(float(pt["p"]) / maxf(melt_time(), 0.01), 0.0, 1.0)
				for c in pt["cells"]:
					var p := Vector2(c.x * TILE, c.y * TILE)
					if not painted:
						ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(RIME, 0.82 - 0.4 * k))
						ci.draw_rect(Rect2(p + Vector2(3, 3), Vector2(TILE - 6, TILE - 6)), Color(1, 1, 1, 0.22))
						ci.draw_rect(Rect2(p + Vector2(7 + (c.x * 5) % 9, 6), Vector2(2, 14)), Color(1, 1, 1, 0.4))
						ci.draw_rect(Rect2(p + Vector2(15, 12 + (c.y * 3) % 8), Vector2(9, 2)), Color(1, 1, 1, 0.35))
					if k > 0.0:
						# Melting: it darkens and weeps from the top down, thinning.
						ci.draw_rect(Rect2(p, Vector2(TILE, TILE * k)), Color(0.35, 0.5, 0.62, 0.45 * k))
						for d in 3:
							var dx: float = 5.0 + d * 10.0 + (c.y % 2) * 3.0
							var run: float = fmod(ftime() * 1.7 + d * 0.37 + c.x * 0.13, 1.0)
							ci.draw_rect(Rect2(p + Vector2(dx, TILE * k - 2.0), Vector2(2, 4 + 8 * k)), Color(0.85, 0.95, 1.0, 0.85))
							ci.draw_rect(Rect2(p + Vector2(dx, TILE * k + 4.0 + run * (TILE - TILE * k)), Vector2(2, 3)), Color(0.85, 0.95, 1.0, 0.6 * k))
			"tell":
				# Frost creeping back across the gap.
				var k2 := 1.0 - clampf(float(pt["t"]) / REFREEZE_TELL, 0.0, 1.0)
				for c in pt["cells"]:
					var p := Vector2(c.x * TILE, c.y * TILE)
					ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(RIME, 0.15 + 0.35 * k2))
					ci.draw_rect(Rect2(p, Vector2(TILE * k2, 3)), Color(FROST, 0.9))
					ci.draw_rect(Rect2(p + Vector2(0, TILE - 3), Vector2(TILE * k2, 3)), Color(FROST, 0.9))


func _draw_belts(ci: CanvasItem, v: Rect2) -> void:
	var shift := fmod(ftime() * 80.0, 16.0)
	var teeth = _tex.get("belt_teeth")
	for c in _belt:
		var p := Vector2(c.x * TILE, c.y * TILE)
		if not v.has_point(p):
			continue
		var dir := belt_dir(c, 1 if level.tile(c.x, c.y) == LevelData.BELT_R else -1)
		var telling := false
		for r in belts_rev:
			if not r["done"] and c.x >= int(r["x0"]) and c.x <= int(r["x1"]):
				telling = true
		if not painted:
			ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), IRON)
			ci.draw_rect(Rect2(p + Vector2(0, TILE - 4), Vector2(TILE, 4)), IRON_DARK)
			# The arrow's way, in the face (a chevron of rects).
			for k in 3:
				ci.draw_rect(Rect2(p + Vector2(14 + dir * (k * 3 - 3), 13 + k * 2), Vector2(4, 2)), BRASS.darkened(0.15))
				ci.draw_rect(Rect2(p + Vector2(14 + dir * (k * 3 - 3), 23 - k * 2), Vector2(4, 2)), BRASS.darkened(0.15))
		var flash := telling and fmod(ftime(), 0.2) < 0.1
		# The painter paints the belt's top as a lit brass lip: only the
		# reversal's flash is drawn over it (the stand-in draws its own lip).
		if not painted or flash:
			ci.draw_rect(Rect2(p, Vector2(TILE, 7)), BRASS.lightened(0.45) if flash else BRASS)
		if teeth != null:
			# A1's belt_teeth: 192 x 32 texture px (96 x 16 units), repeating
			# every 64 texture px (16 world px): a 128 px window per 32 x 8 px
			# cell, the same offset both ways; a left-running belt only
			# mirrors the drawing (the teeth then run with its carry).
			var off := fposmod(16.0 - shift, 16.0) * 4.0
			if dir > 0:
				ci.draw_texture_rect_region(teeth, Rect2(p, Vector2(TILE, 8)), Rect2(off, 0, 128, 32))
			else:
				ci.draw_set_transform(p + Vector2(TILE, 0), 0.0, Vector2(-1, 1))
				ci.draw_texture_rect_region(teeth, Rect2(Vector2.ZERO, Vector2(TILE, 8)), Rect2(off, 0, 128, 32))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			for k in 2:
				var tx := fmod(k * 16.0 + shift * dir + 48.0, 32.0)
				ci.draw_rect(Rect2(p + Vector2(tx - 2.0, 1.0), Vector2(4, 4)), IRON_DARK)


func _brass(key: String, fallback: Color) -> Color:
	return _pal.get(key, fallback) if _pal.get(key) is Color else fallback


func _draw_cog_arms(c: Dictionary) -> void:
	## A1's brass arms, hub to each tooth's underside (behind the gear).
	if _tex.get("gear_l") == null:
		return
	var hub: Vector2 = c["hub"]
	for m in c["teeth"]:
		var r: Rect2 = m.rect()
		var tip := Vector2(r.get_center().x, r.end.y + 2.0)
		_tb.line(hub, tip, 7.0, Color("140e08"))
		_tb.line(hub, tip, 4.4, _brass("brass_sh", BRASS.darkened(0.3)))


func _draw_cog(ci: CanvasItem, c: Dictionary) -> void:
	var hub: Vector2 = c["hub"]
	var turn: float = float(c["phase"]) + float(c["dir"]) * ftime() / knob("cog_period")
	var gear = _tex.get("gear_l")
	var tooth = _tex.get("cog_tooth")
	if _pal.get("cog_art", true) == false:
		# A theme that drains the clockwork (6-4's Carillon memory, husheye):
		# the code-drawn wheel in its own colours, not A1's gold frames.
		gear = null
		tooth = null
	if gear != null:
		# gear_l 96 x 96 px on the hub, turned with tooth 0; its shine on
		# top, still; cog_tooth over each tooth's 64 x 16 ledge.
		var ang := turn * TAU
		if not (c["teeth"] as Array).is_empty():
			ang = ((c["teeth"][0].rect() as Rect2).get_center() - hub).angle() + PI * 0.5
		ci.draw_set_transform(hub, ang, Vector2.ONE)
		ci.draw_texture_rect(gear, Rect2(-48, -48, 96, 96), false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var shine = _tex.get("gear_l_shine")
		if shine != null:
			ci.draw_texture_rect(shine, Rect2(hub - Vector2(48, 48), Vector2(96, 96)), false)
		for m in c["teeth"]:
			var r0: Rect2 = m.rect()
			if tooth != null:
				ci.draw_texture_rect(tooth, Rect2(r0.position, Vector2(64, 16)), false)
			else:
				ci.draw_rect(r0, BRASS)
		return
	# The gear's wheel: a dark rim and four spokes that turn with it (the
	# theme's iron and brass when it has its own).
	var iron := _brass("iron", IRON)
	var brass := _brass("brass", BRASS)
	var brass_hi := _brass("brass_hi", BRASS_LIT)
	_tb.ring(hub, Movers.ORBIT_R - 26.0, 7.0, iron, 24)
	_tb.ring(hub, Movers.ORBIT_R - 29.0, 1.5, iron.lightened(0.3), 24)
	for k in 4:
		var a := TAU * (turn + k / 4.0)
		var d := Vector2(cos(a), sin(a))
		_tb.line(hub + d * 9.0, hub + d * (Movers.ORBIT_R - 28.0), 4.0, iron)
	_tb.circle(hub, 11.0, iron.lightened(0.15), 12)
	_tb.circle(hub, 5.0, brass, 8)
	for m in c["teeth"]:
		var r: Rect2 = m.rect()
		# The arm from the rim out to the tooth.
		var mid := r.get_center()
		var dd := (mid - hub).normalized()
		_tb.line(hub + dd * (Movers.ORBIT_R - 30.0), mid + Vector2(0, 4), 5.0, iron.lightened(0.05))
		if tooth != null:
			ci.draw_texture_rect(tooth, Rect2(r.position, Vector2(64, 16)), false)
		else:
			ci.draw_rect(r.grow(1.0), OUTLINE)
			ci.draw_rect(r, brass)
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), brass_hi)
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), brass.darkened(0.35))


func _swing_tex(r: Rect2):
	var n := clampi(int(round(r.size.x / TILE)), 1, 3)
	return _tex.get("swing_ledge" if n == 1 else "swing_ledge_%d" % n, null)


func _draw_swing_rod(m) -> void:
	## A1's brass rod, anchor to the ledge's top middle (behind the ledge).
	var r: Rect2 = m.rect()
	if _swing_tex(r) == null:
		return
	var top := Vector2(r.get_center().x, r.position.y + 1.0)
	_tb.line(m.anchor, top, 4.4, Color("140e08"))
	_tb.line(m.anchor, top, 2.4, _brass("brass", BRASS))


func _draw_swing(ci: CanvasItem, m) -> void:
	var r: Rect2 = m.rect()
	var anchor: Vector2 = m.anchor
	var tex = _swing_tex(r)
	var piv = _tex.get("pendulum_pivot")
	if tex != null:
		# swing_ledge / _2 / _3 by its length (32 / 64 / 96 x 16 px).
		if piv != null:
			ci.draw_texture_rect(piv, Rect2(anchor - Vector2(16, 0), Vector2(32, 32)), false)
		ci.draw_texture_rect(tex, Rect2(r.position, Vector2(TILE * clampi(int(round(r.size.x / TILE)), 1, 3), 16)), false)
		return
	# Two rods from the anchor to the ledge's ends (a brass cradle, no bob).
	var a := r.position + Vector2(6, 2)
	var b := Vector2(r.end.x - 6, r.position.y + 2)
	_tb.line(anchor, a, 2.5, BRASS.darkened(0.3))
	_tb.line(anchor, b, 2.5, BRASS.darkened(0.3))
	if piv != null:
		ci.draw_texture_rect(piv, Rect2(anchor - Vector2(16, 0), Vector2(32, 32)), false)
	else:
		ci.draw_rect(Rect2(anchor - Vector2(6, 0), Vector2(12, 5)), BRASS.darkened(0.2))
	ci.draw_rect(r.grow(1.0), OUTLINE)
	ci.draw_rect(r, BRASS.lightened(0.05))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), BRASS_LIT)
	for k in range(1, int(r.size.x / 16.0)):
		ci.draw_rect(Rect2(r.position + Vector2(k * 16.0 - 1.0, 4), Vector2(2, r.size.y - 5)), BRASS.darkened(0.3))


func _draw_weight_rod(wt: Dictionary) -> void:
	## A1's iron rod, pivot to the bob's ring (behind both).
	var bob: Vector2 = wt["bob"]
	var anchor: Vector2 = wt["anchor"]
	if _tex.get("pendulum_bob") == null:
		return
	var end := bob - (bob - anchor).normalized() * 16.0
	_tb.line(anchor + Vector2(0, 10), end, 5.0, Color("0c0c14"))
	_tb.line(anchor + Vector2(0, 10), end, 3.0, _brass("iron", IRON).lightened(0.15))


func _draw_weight(ci: CanvasItem, wt: Dictionary) -> void:
	var bob: Vector2 = wt["bob"]
	var anchor: Vector2 = wt["anchor"]
	var piv = _tex.get("pendulum_pivot")
	var tex = _tex.get("pendulum_bob")
	if tex != null:
		# The round bell-weight, 40 x 40 px on the bob (its body covers the
		# r 18 hurt circle), its ring turned toward the pivot with the rod.
		if piv != null:
			ci.draw_texture_rect(piv, Rect2(anchor - Vector2(16, 0), Vector2(32, 32)), false)
		ci.draw_set_transform(bob, (bob - anchor).angle() - PI * 0.5, Vector2.ONE)
		ci.draw_texture_rect(tex, Rect2(-20, -20, 40, 40), false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_tb.line(anchor, bob, 3.0, IRON.lightened(0.15))
	if piv != null:
		ci.draw_texture_rect(piv, Rect2(anchor - Vector2(16, 0), Vector2(32, 32)), false)
	else:
		ci.draw_rect(Rect2(anchor - Vector2(7, 0), Vector2(14, 6)), IRON)
	# An iron bell-weight: a dome, a lip, a knob on top.
	_tb.circle(bob + Vector2(0, -2), WEIGHT_R + 1.5, OUTLINE, 14)
	_tb.circle(bob + Vector2(0, -2), WEIGHT_R, IRON, 14)
	_tb.rect(Rect2(bob + Vector2(-WEIGHT_R - 2, WEIGHT_R * 0.35), Vector2(WEIGHT_R * 2 + 4, 6)), IRON_DARK)
	_tb.circle(bob + Vector2(-5, -9), 4.0, IRON.lightened(0.35), 8)
	_tb.rect(Rect2(bob + Vector2(-3, -WEIGHT_R - 6), Vector2(6, 5)), IRON.lightened(0.1))


func _draw_icicle(ci: CanvasItem, ic: Dictionary) -> void:
	var hang: Vector2 = ic["hang"]
	var st := str(ic["state"])
	if st == "gone":
		return
	var grow := 1.0
	var shake := 0.0
	if st == "grow":
		grow = clampf(float(ic["t"]) / ICICLE_GROW, 0.05, 1.0)
	elif st == "tell":
		shake = sin(float(ic["t"]) * 70.0) * 1.8
	elif st == "fall":
		hang = (ic["tip"] as Vector2) - Vector2(0, ICICLE_H)
	var key := "icicle_crack" if st == "tell" else ("icicle_fall" if st == "fall" else "icicle_hang")
	var tex = _tex.get(key, _tex.get("icicle_hang"))
	var h := ICICLE_H * grow
	if tex != null:
		# A1's frames: 32 x 32 px, the top on the ceiling, the tip at (16, 30)
		# (a falling one rides its tip; a growing one comes down from the top).
		var top := hang
		if st == "fall":
			top = (ic["tip"] as Vector2) - Vector2(0, 30)
		ci.draw_texture_rect(tex, Rect2(top + Vector2(-16 + shake, 0), Vector2(32, 32 * grow)), false)
	else:
		var a := hang + Vector2(-ICICLE_DRAW_W * 0.5 + shake, 0)
		var b := hang + Vector2(ICICLE_DRAW_W * 0.5 + shake, 0)
		var t2 := hang + Vector2(shake * 1.6, h + 4.0 * grow)
		_tb.tri(a + Vector2(-1, -1), b + Vector2(1, -1), t2 + Vector2(0, 2), OUTLINE)
		_tb.tri(a, b, t2, ICE)
		_tb.tri(a + Vector2(2, 0), hang + Vector2(shake, 0), hang + Vector2(shake * 1.3, h * 0.7), FROST)


func draw_glow(glow: Node2D) -> void:
	var v := view().grow(200)
	var k := pulse()
	# Wax-ice's lip, faint above the dark (the stand-in ice outside his light
	# reads as stone otherwise): every ice and frosted-ledge top in view.
	if _w4():
		for r in ice_runs:
			var x0: float = maxf(float(r["x0"]), v.position.x)
			var x1: float = minf(float(r["x1"]), v.end.x)
			var y: float = float(r["y"])
			if x1 > x0 and y >= v.position.y and y <= v.end.y:
				glow.draw_rect(Rect2(x0, y, x1 - x0, 2), Color(FROST, ICE_LIP))
	for wt in weights:
		var bob: Vector2 = wt["bob"]
		var anchor: Vector2 = wt["anchor"]
		if not v.has_point(anchor):
			continue
		# The swing's arc, dashed at alpha 0.20 (a weight's; a swing has none):
		# frost dashes laid along the arc, 7 px long, so it reads as the
		# swing's reach and not as the backdrop's drifting snow (4 x 2 white
		# specks, the int2 review).
		for i in 13:
			var a := lerpf(-WEIGHT_AMP, WEIGHT_AMP, i / 12.0)
			var q := anchor + Vector2(sin(a), cos(a)) * float(wt["rod"])
			var tang := Vector2(cos(a), -sin(a)) * 3.5
			_gb.line(q - tang, q + tang, 2.0, Color(FROST, 0.20))
		# Its frost lamp, above the dark: you always see where it is.
		_gb.circle(bob, 5.0 + 2.0 * k, Color(FROST, 0.55 + 0.3 * k), 10)
		_gb.ring(bob + Vector2(0, -2), WEIGHT_R + 1.0, 1.5, Color(FROST, 0.35), 16)
	for ic in icicles:
		var hang: Vector2 = ic["hang"]
		if not v.has_point(hang):
			continue
		match str(ic["state"]):
			"hang", "grow":
				glow.draw_rect(Rect2(hang + Vector2(-1, 4), Vector2(2, ICICLE_H * 0.6)), Color(FROST, 0.35))
			"tell":
				# The tell: a white crack at the root and a glint that grows.
				var kk := clampf(float(ic["t"]) / maxf(knob("icicle_tell"), 0.01), 0.0, 1.0)
				glow.draw_rect(Rect2(hang + Vector2(-8, 1), Vector2(16, 2)), Color(1, 1, 1, 0.95))
				glow.draw_rect(Rect2(hang + Vector2(-1, 2), Vector2(2, 8 + 12 * kk)), Color(1, 1, 1, 0.95))
				_gb.circle(hang + Vector2(0, ICICLE_H * 0.5), 4.0 + 5.0 * kk, Color(FROST, 0.85), 12)
				_gb.ring(hang + Vector2(0, ICICLE_H * 0.5), 9.0 + 6.0 * kk, 1.5, Color(FROST, 0.5 * (1.0 - kk)), 14)
			"fall":
				var r := icicle_rect(ic)
				glow.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.5 - 1.0, 0), Vector2(2, r.size.y)), Color(FROST, 0.8))
	# Rime: a shimmer as it melts, the frost's edge as it comes back.
	for pt in patches:
		var rr: Rect2 = pt["rect"]
		if not v.intersects(rr):
			continue
		if pt["state"] == "solid" and float(pt["p"]) > 0.0:
			var km := clampf(float(pt["p"]) / maxf(melt_time(), 0.01), 0.0, 1.0)
			glow.draw_rect(Rect2(rr.position, Vector2(rr.size.x, 2)), Color(FROST, 0.3 + 0.4 * km))
		elif pt["state"] == "tell":
			var kt := 1.0 - clampf(float(pt["t"]) / REFREEZE_TELL, 0.0, 1.0)
			for c in pt["cells"]:
				glow.draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE * kt, 2), Color(FROST, 0.45))
	# The teeth and swing ledges' top edges, faint (you ride them in the dark).
	for c in cogs:
		var hub: Vector2 = c["hub"]
		if not v.has_point(hub):
			continue
		for m in c["teeth"]:
			var r: Rect2 = m.rect()
			glow.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(1.0, 0.9, 0.6, 0.30))
		# The beat on the hub (the tick's twin for a muted phone).
		if k > 0.0:
			_gb.circle(hub, 5.0 + 4.0 * k, Color(BRASS_LIT, 0.55 * k), 10)
	for m in swings:
		var r: Rect2 = m.rect()
		if v.intersects(r):
			glow.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(1.0, 0.9, 0.6, 0.30))
	for r in belts_rev:
		if not r["done"]:
			for c in _belt:
				if c.x >= int(r["x0"]) and c.x <= int(r["x1"]) and v.has_point(Vector2(c.x * TILE, c.y * TILE)):
					glow.draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE, 3), Color(FROST, 0.8 if fmod(ftime(), 0.2) < 0.1 else 0.3))
	# The lamps pulse on the beat (World 4's; W1-W2 draw as they did).
	if k > 0.0 and _w4():
		var lf = world.get("features")
		if lf != null and "lanterns" in lf:
			for l in lf.lanterns:
				if bool(l.get("lit", false)) and v.has_point(l["flame"]):
					_gb.ring(l["flame"], 9.0 + 7.0 * (1.0 - k), 1.5, Color(BRASS_LIT, 0.45 * k), 14)
		for a in world.altars:
			if bool(a["lit"]) and v.has_point(a["flame"]):
				_gb.ring(a["flame"], 10.0 + 8.0 * (1.0 - k), 1.5, Color(BRASS_LIT, 0.4 * k), 14)
	_gb.flush(glow)
