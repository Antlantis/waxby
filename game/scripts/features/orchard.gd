extends "res://scripts/features/feature.gd"
## World 3, the Bone Orchard (WL3; spec §3.2, contract.md §4). What the
## orchard's terrain does, and how it shows:
##
##   vine {        climbable (player.gd owns the climb itself); vine_at,
##                 vine_lane, vine_present answer for it
##   rotten vine } holds rotten_hold from the first catch (1.4 / 1.2 / 1.0 s),
##                 frays visibly from FRAY (fibres fly, the vein reddens and
##                 shakes; vine_creak timed to end as it snaps), snaps (the
##                 run is gone for GONE s: vine_present reads false), then
##                 regrows over a REGROW tell. A snuff grows every run back.
##   spore pod *   on a floor, a ceiling or a vine. It triggers when Wick's
##                 centre comes within POD_REACH, or when any attack or shot
##                 hits it: a pod_tell swell (0.40 / 0.34 / 0.30 s: it swells
##                 and quivers, its glint brightens chartreuse, spore_swell),
##                 then it bursts into a cloud (POD_CLOUD_R, POD_CLOUD_LIFE)
##                 that billows out to its full radius over POD_GROW s: its
##                 edge (183 px/s) is slower than a run (205), so a running
##                 Wick outruns a burst (spec: "keep moving"), while a walk,
##                 a stop or a climb (130) is caught. It regrows POD_REGROW s
##                 later, once Wick is POD_AWAY off.
##   spore cloud   one rule for everyone (pods, Weepcaps, the Sporebound
##                 Omen, Gravebough's Spore Breath: add_spores). It drifts up
##                 CLOUD_RISE px/s until a ceiling stops it. While Wick's
##                 centre is in one, and SPORE_AFTER s after, the dim
##                 "spores" x spore_dim (0.55 / 0.50 / 0.45) goes through the
##                 World's one pipeline (world.dim: Sporeward eases any key
##                 starting "spore"). No damage; monsters don't care. It is a
##                 Hush light of radius rule / CLOUD_SHADER_K (so the blot's
##                 half-strength edge is the rule's), with chartreuse motes
##                 orbiting its edge on the glow layer.
##   fire          burns a cloud at once (it fades over BURN_TIME, with a
##                 flash light of BURN_FLASH_R): a hero's spark, Flare or
##                 bolt, any fire patch (a Special's burning floor, the
##                 Burning Omen, the Cinderstep trail), a lit lantern or
##                 brazier, a glowfruit falling into it
##   glowfruit 8   hangs from a ceiling or a vine, lit (FRUIT_HANG_R). A
##                 slash, a hero's shot or a touch drops it: it falls (g
##                 FRUIT_G), bounces once (vy x -FRUIT_BOUNCE), then lies lit
##                 at FRUIT_LIT_R for FRUIT_LIFE s (guttering the last
##                 FRUIT_GUTTER), and keeps a FRUIT_EMBER_R glow for good.
##                 It is lamplight (a gameplay light: lit_at counts it).
##                 Falling onto a pod it bursts it and burns the cloud at
##                 once. In a boss arena it grows back ARENA_REGROW s after
##                 it fell (and at once on a retry); anywhere else a snuff
##                 hangs every fallen fruit again (a retry of a dark grove
##                 has its light back). A sigil within SIGIL_GLINT tiles of
##                 a fruit glints once any of those fruit is down (3-1's
##                 grove, spec §3.4.3).
##
## Barks (at a stone landing, never mid-jump): first_vine as he stands by
## his first vine, first_spore the first time a cloud dims him. The playlog
## hears vine_snap (world.note_feature). Sounds per A7's bank: vine_grab,
## vine_climb, vine_creak, vine_snap, spore_swell, spore_puff, spore_choke,
## spore_burn, glowfruit_drop (world._tell_sfx for the two tells).
##
## Drawing: pods and glowfruit from A1's props (art/props/spore_pod_*,
## glowfruit_*) when they exist, else code-drawn. Vines: in a theme with no
## painter of its own (the v2 themes the labs use; the fallback look) this
## module draws them all; under A1's orchard painter (tiles/orchard.gd,
## DRAW_ROTTEN false) the painter draws the sound vines once per chunk and
## this module draws the rotten runs each frame with the painter's own
## vine_cell() (they fray, snap and grow back); under a painter that draws
## rotten runs itself while world.vine_present (the plain painter) its
## cached chunk is redrawn (world._redraw_at) at each snap and regrowth.
## The glow layer's vine veins are this module's too: EdgeLines' static
## "vine" style (its World 3 default when a theme has no EDGES of its own)
## would keep a snapped run's vein for its 5 s, so the module takes that
## style over (drops it from EdgeLines, draws the sound veins in its colour)
## and draws each rotten run's vein with its state. Rects and one TriBatch
## per layer; no draw_circle.
##
## The 3-3 secret cue (spec §3.9): where the level has a silver bell whose
## secret level is built, pale spores drift up the vine nearest the false
## stone under it and slip into the crack.
##
## Stepping: every run, pod, fruit and cloud of the level each tick, not
## spec §13's view-chunk buckets (a deviation, on purpose): a W3 level has at
## most 6 rotten runs, 15 pods and 5 glowfruit, and the whole step measures
## 17-24 us a tick on the Mac, with the off-screen timers (a snapped run's
## 5 s, a pod's regrowth) exact wherever he is.

const Themes := preload("res://scripts/themes/loader.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")

const DIFF_KNOBS := {
	"rotten_hold": {"dusk": 1.4, "nightfall": 1.2, "witching": 1.0},
	"pod_tell": {"dusk": 0.40, "nightfall": 0.34, "witching": 0.30},
	"spore_dim": {"dusk": 0.55, "nightfall": 0.50, "witching": 0.45},
}
# Rotten vines.
const FRAY := 0.5                # s after the first catch a rotten run starts to fray
const GONE := 5.0                # s a snapped run is gone
const REGROW := 0.6              # its regrow tell (not climbable yet)
# Pods and clouds.
const POD_REACH := 48.0          # Wick's centre this near triggers a pod
const POD_HIT := 12.0            # a pod's body (attacks and shots)
const POD_CLOUD_R := 64.0
const POD_CLOUD_LIFE := 4.0
const POD_GROW := 0.35           # s a pod's cloud takes to billow out to its full radius (edge 183 px/s)
const POD_REGROW := 8.0
const POD_AWAY := 200.0          # ...once Wick is this far off
const POD_GLOW_R := 24.0
const POD_GLOW_S := 0.3
const CLOUD_RISE := 8.0          # px/s, until a ceiling
const CLOUD_SHADER_K := 0.58     # shader radius = rule radius / this
const CLOUD_HUSH := 0.5          # the blot's strength (a Hush light)
const SPORE_AFTER := 2.0         # s the dim lingers after leaving a cloud
const BURN_TIME := 0.3
const BURN_FLASH_R := 120.0
const FIRE_SHOTS := ["spark", "flare", "bolt"]
const FIRE_REACH := 16.0         # a lantern's flame burns a cloud this far past its edge
const CHOKE_EVERY := 1.0
# Glowfruit.
const FRUIT_HANG_R := 90.0
const FRUIT_HANG_S := 0.6
const FRUIT_LIT_R := 120.0
const FRUIT_LIT_S := 0.8
const FRUIT_LIFE := 30.0
const FRUIT_GUTTER := 3.0
const FRUIT_EMBER_R := 40.0
const FRUIT_G := 1400.0
const FRUIT_BOUNCE := 0.3
const FRUIT_MAX_FALL := 900.0
const ARENA_REGROW := 12.0
const FRUIT_HALF := Vector2(8, 10)   # the gourd's half size (touch, strike, landing)
const SIGIL_GLINT := 10          # tiles: a sigil this near a fallen glowfruit glints
# The glow-layer vein of a sound vine (EdgeLines' World 3 default, decisions.md: 0.35).
const VEIN := {"what": "vine", "color": Color("9ad07a"), "alpha": 0.35, "width": 1.5}
const UPDRAFT_MOTES := 14         # the 3-3 updraft's rising motes (the only W3 stream that rises)
const VEIN_X := 15.0             # the stem's centre in its cell (A1's painter: VINE_X)
# Colours.
const VINE := Color("4f7a3a")
const VINE_LIT := Color("7fae5a")
const ROTTEN := Color("7a6a52")
const ROTTEN_LIT := Color("a8987a")
const SPORE := Color("c8d46a")       # the World 3 tell accent (decoration never uses it)
const HAZE := Color("8a9a3a")
const AMBER := Color("f2b04a")
const BONE := Color("e8dcc0")
const OUTLINE := Color("17121f")
const PROPS := ["spore_pod_closed", "spore_pod_swell", "spore_pod_burst", "spore_pod_hang_closed", "spore_pod_hang_swell",
		"spore_pod_hang_burst", "glowfruit_hang", "glowfruit_lit", "glowfruit_dim"]

var runs: Array = []             # rotten runs: {x, y0, y1, state: idle|held|snapped|regrow, t, creaked}
var _run_of := {}                # Vector2i -> index into runs
var _cols := {}                  # x -> [y, ...] vine cells (drawing)
var pods: Array = []             # {cell, pos, mount: floor|ceiling|vine, state: closed|swell|burst, t, arena}
var fruit: Array = []            # {cell, home, pos, vel, state: hang|fall|lit|ember|gone, t, bounced, arena, regrow}
var clouds: Array = []           # {p, r, life, t, burn, source, ceil, grow}  (the Weepcap reads p, burn, source; r is the full radius, cloud_r() the live one)
var flashes: Array = []          # {p, t}
var _spored_t := 0.0
var _choke_t := 0.0
var _climb_acc := 0.0
var _last_climb_y := NAN
var _barked := {}
var _pending := ""               # a first-time bark waiting for a stone landing
var _draws_vines := false        # this module draws every vine (no v3 painter: the fallback look)
var _painter = null              # the theme's tile painter (a Script) when it has one
var _pal := {}                   # its palette
var _paint_rotten := false       # the painter leaves rotten runs to this module (DRAW_ROTTEN false): vine_cell each frame
var _veins := -1                 # 1 once the vein style is this module's (taken from EdgeLines); -1 not yet
var _vein := VEIN                # the sound veins' style (EdgeLines' own, when it had one)
# A theme's own vein colours (A2: W6's drowned reeds, "vine_vein" / "rot_vein":
# silver), else W3's (a rotten run's grey, its fray's amber start).
var _rot_idle := Color(0.78, 0.72, 0.6)
var _rot_vein := Color(0.95, 0.75, 0.5)
var _sigils: Array = []          # [{index, pos, fruit: [indices into fruit]}]: the sigils a fallen fruit makes glint
var _arena := {}                 # the boss arena {left, right} (glowfruit regrow there)
var _tex := {}
var _tb := TriBatch.new()
var _updraft := {}               # {x, y0, y1, crack: Vector2}: the 3-3 secret cue
var _connected := false


func build(w: Node, lv: RefCounted) -> void:
	super.build(w, lv)
	for x in lv.width:
		var y := 0
		while y < lv.height:
			var t: int = lv.tile(x, y)
			if LevelData.is_climb(t):
				if not _cols.has(x):
					_cols[x] = []
				_cols[x].append(y)
			if t == LevelData.ROTTEN_VINE:
				var y1 := y
				while lv.tile(x, y1 + 1) == LevelData.ROTTEN_VINE:
					y1 += 1
				var idx := runs.size()
				runs.append({"x": x, "y0": y, "y1": y1, "state": "idle", "t": 0.0, "creaked": false})
				for yy in range(y, y1 + 1):
					_run_of[Vector2i(x, yy)] = idx
				for yy in range(y + 1, y1 + 1):
					_cols[x].append(yy)
				y = y1 + 1
				continue
			y += 1
	for e in lv.entities:
		if e["kind"] == "boss":
			_arena = Arena.find(lv, LevelData.cell_floor(e["cell"]))
	for e in lv.entities:
		var cell: Vector2i = e["cell"]
		match str(e["kind"]):
			"pod":
				var mount := _mount_of(cell)
				pods.append({"cell": cell, "pos": _pod_pos(cell, mount), "mount": mount, "state": "closed", "t": -99.0,
						"arena": _in_arena(LevelData.cell_center(cell))})
			"glowfruit":
				var home := _fruit_home(cell)
				fruit.append({"cell": cell, "home": home, "pos": home, "vel": Vector2.ZERO, "state": "hang", "t": 0.0,
						"bounced": false, "arena": _in_arena(home), "regrow": -1.0})
	var th := str(lv.theme)
	_draws_vines = not Themes.has_theme(th)
	var thd: Dictionary = Themes.theme(th) if Themes.has_theme(th) else {}
	if thd.get("vine_vein") is Color:
		_vein = {"what": "vine", "color": thd["vine_vein"], "alpha": float(VEIN["alpha"]), "width": float(VEIN["width"])}
	if thd.get("rot_vein") is Color:
		_rot_idle = thd["rot_vein"]
		_rot_vein = thd["rot_vein"]
	if not _draws_vines:
		_painter = Themes.painter(th)
		_pal = Themes.palette(th)
		if _painter != null:
			var cm: Dictionary = _painter.get_script_constant_map()
			var has_cell := false
			for m in _painter.get_script_method_list():
				has_cell = has_cell or str(m["name"]) == "vine_cell"
			_paint_rotten = cm.has("DRAW_ROTTEN") and not bool(cm["DRAW_ROTTEN"]) and has_cell
	for n in PROPS:
		var p := "res://art/props/%s.svg" % n
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	for e in lv.entities:
		if e["kind"] != "sigil":
			continue
		var near := []
		for i in fruit.size():
			if absi((fruit[i]["cell"] as Vector2i).x - (e["cell"] as Vector2i).x) <= SIGIL_GLINT:
				near.append(i)
		if not near.is_empty():
			_sigils.append({"index": int(e["index"]), "pos": LevelData.cell_center(e["cell"]), "fruit": near})
	_find_updraft()
	_connect()


func _connect() -> void:
	if _connected or world == null:
		return
	var pl = world.get("player")
	if pl != null and pl.has_signal("vine"):
		pl.vine.connect(_on_vine)
		_connected = true


func _on_vine(event: String) -> void:
	if event == "catch":
		_snd("vine_grab")
		if not _barked.has("first_vine") and _pending == "":
			_pending = "first_vine"


func _mount_of(cell: Vector2i) -> String:
	if LevelData.is_climb(level.tile(cell.x, cell.y)):
		return "vine"
	var below: int = level.tile(cell.x, cell.y + 1)
	if LevelData.is_solid(below) or LevelData.is_ledge(below):
		return "floor"
	if LevelData.is_solid(level.tile(cell.x, cell.y - 1)):
		return "ceiling"
	return "floor"


static func _pod_pos(cell: Vector2i, mount: String) -> Vector2:
	var cx := (cell.x + 0.5) * TILE
	match mount:
		"ceiling":
			return Vector2(cx, cell.y * TILE + 11.0)
		"vine":
			return Vector2(cx, (cell.y + 0.5) * TILE)
	return Vector2(cx, (cell.y + 1) * TILE - 11.0)


func _fruit_home(cell: Vector2i) -> Vector2:
	## The gourd's centre as it hangs: under its stem from a ceiling, or on
	## its vine.
	var cx := (cell.x + 0.5) * TILE
	if LevelData.is_solid(level.tile(cell.x, cell.y - 1)) and not LevelData.is_climb(level.tile(cell.x, cell.y)):
		return Vector2(cx, cell.y * TILE + 16.0)
	return Vector2(cx, (cell.y + 0.5) * TILE)


func _in_arena(p: Vector2) -> bool:
	return not _arena.is_empty() and p.x > float(_arena["left"]) and p.x < float(_arena["right"])


# ---------------------------------------------------------------- queries

func vine_at(cell: Vector2i) -> bool:
	return vine_present(cell.x, cell.y)


func vine_lane(cell: Vector2i) -> Dictionary:
	## {x, y0, y1}: the climbable run through cell now (tile rows), or {}.
	if not vine_present(cell.x, cell.y):
		return {}
	var y0 := cell.y
	var y1 := cell.y
	while vine_present(cell.x, y0 - 1):
		y0 -= 1
	while vine_present(cell.x, y1 + 1):
		y1 += 1
	return {"x": cell.x, "y0": y0, "y1": y1}


func vine_present(x: int, y: int) -> bool:
	if not LevelData.is_climb(level.tile(x, y)):
		return false
	var i = _run_of.get(Vector2i(x, y))
	if i == null:
		return true
	var st: String = runs[i]["state"]
	return st == "idle" or st == "held"


func add_spores(p: Vector2, r: float, life: float, source: Object = null, grow := 0.0) -> void:
	## A spore cloud (pods, Weepcaps, the Sporebound Omen, Spore Breath): at
	## its full radius at once, or (grow > 0: a pod's burst) billowing out to
	## it over grow seconds.
	clouds.append({"p": p, "r": r, "life": life, "t": 0.0, "burn": -1.0, "source": source, "ceil": _ceiling_over(p),
			"grow": grow})


static func cloud_r(c: Dictionary) -> float:
	## A cloud's rule radius now (a pod's grows from nothing over its "grow").
	var g := float(c.get("grow", 0.0))
	if g <= 0.0:
		return float(c["r"])
	return float(c["r"]) * clampf(float(c["t"]) / g, 0.0, 1.0)


func spores_at(p: Vector2) -> bool:
	for c in clouds:
		if float(c["burn"]) < 0.0 and (c["p"] as Vector2).distance_to(p) <= cloud_r(c):
			return true
	return false


func burn_spores(p: Vector2, r: float) -> void:
	## Fire reached this circle: every live cloud it touches burns at once.
	for c in clouds:
		if float(c["burn"]) < 0.0 and (c["p"] as Vector2).distance_to(p) <= cloud_r(c) + r:
			_burn(c)


func _burn(c: Dictionary) -> void:
	c["burn"] = 0.0
	flashes.append({"p": c["p"], "t": 0.0})
	_snd("spore_burn")
	if world != null and world.get("glow") != null:
		world.glow.burst(c["p"], 18, Color(1.0, 0.62, 0.25, 0.95), 170.0, 0.4, -60.0, 3.0)


func live_clouds() -> int:
	var n := 0
	for c in clouds:
		if float(c["burn"]) < 0.0:
			n += 1
	return n


func _ceiling_over(p: Vector2) -> float:
	## How high a cloud from p may rise: 12 px under the first solid above it.
	var x := floori(p.x / TILE)
	var y := floori(p.y / TILE)
	while y > 0:
		y -= 1
		if LevelData.is_solid(level.tile(x, y)):
			return (y + 1) * TILE + 12.0
	return -INF


# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	_connect()
	if _veins < 0:
		_take_veins()
	var pl := player()
	var alive: bool = pl != null and pl.alive and str(world.get("state")) == "play"
	_step_runs(pl)
	_step_pods(pl, alive)
	_step_fruit(dt)
	_step_clouds(dt)
	for f in flashes:
		f["t"] = float(f["t"]) + dt
	flashes = flashes.filter(func(f): return float(f["t"]) < BURN_TIME)
	# The dim follows Wick's centre (through the one pipeline).
	_choke_t = maxf(_choke_t - dt, 0.0)
	if alive:
		if spores_at(pl.center()):
			_spored_t = SPORE_AFTER
			if _choke_t <= 0.0:
				_choke_t = CHOKE_EVERY
				_snd("spore_choke")
			if not _barked.has("first_spore") and _pending == "":
				_pending = "first_spore"
		else:
			_spored_t = maxf(_spored_t - dt, 0.0)
		if _spored_t > 0.0:
			world.dim("spores", knob("spore_dim"), 0.1)
		_step_barks(pl)
	else:
		_spored_t = 0.0


func _step_runs(pl: Node2D) -> void:
	# A rotten run starts rotting at the first catch (or as he climbs into it).
	if pl != null and bool(pl.get("climbing")):
		var c := Vector2i(int(pl.climb_col), floori(pl.center().y / TILE))
		var i = _run_of.get(c)
		if i != null and runs[i]["state"] == "idle":
			runs[i]["state"] = "held"
			runs[i]["t"] = ftime()
			runs[i]["creaked"] = false
		# The climb's rustle, every 16 px climbed.
		var y: float = pl.center().y
		if str(pl.get("climb_state")) == "climb" and not is_nan(_last_climb_y):
			_climb_acc += absf(y - _last_climb_y)
			if _climb_acc >= 16.0:
				_climb_acc = 0.0
				_snd("vine_climb")
		_last_climb_y = y
	else:
		_last_climb_y = NAN
		_climb_acc = 0.0
	var hold := knob("rotten_hold")
	for r in runs:
		var age := ftime() - float(r["t"])
		match r["state"]:
			"held":
				if not r["creaked"] and age >= FRAY:
					r["creaked"] = true
					_tell("vine_creak", maxf(hold - FRAY, 0.1))
				if age >= hold:
					r["state"] = "snapped"
					r["t"] = ftime()
					_snd("vine_snap")
					if world.has_method("note_feature"):
						world.note_feature("vine_snap")
					_redraw_run(r)
					if world.get("glow") != null:
						var cx := (int(r["x"]) + 0.5) * TILE
						world.glow.burst(Vector2(cx, (float(r["y0"]) + float(r["y1"]) + 1.0) * 0.5 * TILE), 14,
								Color(0.9, 0.82, 0.62, 0.9), 110.0, 0.7, 500.0, 2.5)
			"snapped":
				if age >= GONE:
					r["state"] = "regrow"
					r["t"] = ftime()
			"regrow":
				if age >= REGROW:
					r["state"] = "idle"
					_redraw_run(r)


func _redraw_run(r: Dictionary) -> void:
	## The painter caches vines (it asks vine_present): draw that column again.
	if world != null and world.has_method("_redraw_at"):
		world._redraw_at(int(r["x"]))


func _step_pods(pl: Node2D, alive: bool) -> void:
	var tell := knob("pod_tell")
	for p in pods:
		match p["state"]:
			"closed":
				if alive and (pl.center() as Vector2).distance_to(p["pos"]) <= POD_REACH:
					_swell(p)
			"swell":
				if ftime() - float(p["t"]) >= tell:
					_burst(p)
			"burst":
				if ftime() - float(p["t"]) >= POD_REGROW and (pl == null or (pl.center() as Vector2).distance_to(p["pos"]) >= POD_AWAY):
					p["state"] = "closed"


func _swell(p: Dictionary) -> void:
	if p["state"] != "closed":
		return
	p["state"] = "swell"
	p["t"] = ftime()
	_tell("spore_swell", knob("pod_tell"))


func _burst(p: Dictionary, burn := false) -> void:
	p["state"] = "burst"
	p["t"] = ftime()
	add_spores(p["pos"], POD_CLOUD_R, POD_CLOUD_LIFE, self, POD_GROW)
	_snd("spore_puff")
	if world.get("glow") != null:
		world.glow.burst(p["pos"], 16, Color(SPORE, 0.9), 90.0, 0.6, -40.0, 3.0)
	if burn:
		_burn(clouds[clouds.size() - 1])


func _step_fruit(dt: float) -> void:
	for f in fruit:
		match f["state"]:
			"fall":
				var v: Vector2 = f["vel"]
				v.y = minf(v.y + FRUIT_G * dt, FRUIT_MAX_FALL)
				var p: Vector2 = (f["pos"] as Vector2) + v * dt
				# Onto a pod: it bursts, and the fruit's fire takes the cloud.
				for pd in pods:
					if pd["state"] != "burst" and (pd["pos"] as Vector2).distance_to(p) <= POD_HIT + FRUIT_HALF.y:
						_burst(pd, true)
				# Through a cloud: it burns.
				for c in clouds:
					if float(c["burn"]) < 0.0 and (c["p"] as Vector2).distance_to(p) <= cloud_r(c):
						_burn(c)
				var floor_y := _floor_under(p, FRUIT_HALF.y)
				if v.y > 0.0 and p.y + FRUIT_HALF.y >= floor_y:
					p.y = floor_y - FRUIT_HALF.y
					if not f["bounced"]:
						f["bounced"] = true
						v.y = -v.y * FRUIT_BOUNCE
					else:
						f["state"] = "lit"
						f["t"] = ftime()
						v = Vector2.ZERO
				if p.y > level.height * TILE + 40.0 or _deep(p):
					f["state"] = "gone"
				f["pos"] = p
				f["vel"] = v
			"lit":
				if ftime() - float(f["t"]) >= FRUIT_LIFE:
					f["state"] = "ember"
		if f["arena"] and f["state"] != "hang" and float(f["regrow"]) >= 0.0 and ftime() >= float(f["regrow"]):
			_rehang(f)


func _floor_under(p: Vector2, half: float) -> float:
	## The top of the first floor (solid, or a ledge's top) under p's bottom.
	var x := floori(p.x / TILE)
	var y := maxi(floori((p.y + half - 1.0) / TILE), 0)
	while y < level.height:
		var t: int = level.tile(x, y)
		if LevelData.is_solid(t) or LevelData.is_ledge(t):
			return y * TILE
		y += 1
	return INF


func _deep(p: Vector2) -> bool:
	return level.tile(floori(p.x / TILE), floori(p.y / TILE)) == LevelData.WATER


func drop_fruit(f: Dictionary) -> void:
	## Knocked down (a slash, a shot, a touch, or a test).
	if f["state"] != "hang":
		return
	f["state"] = "fall"
	f["vel"] = Vector2.ZERO
	f["bounced"] = false
	f["pos"] = f["home"]
	f["t"] = ftime()
	if f["arena"]:
		f["regrow"] = ftime() + ARENA_REGROW
	_snd("glowfruit_drop")


func _rehang(f: Dictionary) -> void:
	f["state"] = "hang"
	f["pos"] = f["home"]
	f["vel"] = Vector2.ZERO
	f["regrow"] = -1.0


func _step_clouds(dt: float) -> void:
	var lanterns: Array = []
	var disp = world.get("features")
	if disp != null and disp.get("lanterns") != null:
		lanterns = (disp.lanterns as Array).filter(func(l): return l["lit"])
	for c in clouds:
		c["t"] = float(c["t"]) + dt
		var p: Vector2 = c["p"]
		if p.y - CLOUD_RISE * dt > float(c["ceil"]):
			p.y -= CLOUD_RISE * dt
		c["p"] = p
		if float(c["burn"]) >= 0.0:
			c["burn"] = float(c["burn"]) + dt
			continue
		if _fire_near(p, cloud_r(c), lanterns):
			_burn(c)
	clouds = clouds.filter(func(c): return float(c["t"]) < float(c["life"]) and float(c["burn"]) < BURN_TIME)


func _fire_near(p: Vector2, r: float, lanterns: Array) -> bool:
	## Fire inside a cloud's rule circle: a hero's fire shot, a fire patch
	## (anyone's), a lit lantern or brazier.
	for s in world.shots:
		if s["owner"] == "player" and (str(s["kind"]) in FIRE_SHOTS or s.get("fire", false)) \
				and float(s.get("life", 1.0)) > 0.0 and (s["pos"] as Vector2).distance_to(p) <= r:
			return true
	for h in world.hazards:
		if str(h.get("kind", "")) == "fire" and float(h.get("delay", 0.0)) <= 0.0 and float(h.get("life", 1.0)) > 0.0:
			if _circle_hits(p, r, h["rect"]):
				return true
	for l in lanterns:
		if (l["flame"] as Vector2).distance_to(p) <= r + FIRE_REACH:
			return true
	return false


static func _circle_hits(c: Vector2, r: float, rect: Rect2) -> bool:
	var q := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return q.distance_to(c) <= r


func _step_barks(pl: Node2D) -> void:
	## A first-time "how to" waits for a stone landing (never mid-jump).
	if not bool(pl.get("on_floor")) or bool(pl.get("climbing")):
		return
	var feet: Vector2 = pl.position
	var under: int = level.tile(floori(feet.x / TILE), floori((feet.y + 1.0) / TILE))
	if not LevelData.is_safe(under):
		return
	if _pending == "" and not _barked.has("first_vine"):
		# Standing by his first vine.
		var cx := floori(feet.x / TILE)
		var cy := floori((feet.y - 16.0) / TILE)
		for x in range(cx - 3, cx + 4):
			if _cols.has(x) and (_cols[x] as Array).has(cy):
				_pending = "first_vine"
				break
	if _pending != "":
		_barked[_pending] = true
		if world.has_method("bark"):
			world.bark(_pending)
		_pending = ""


func touch(pl: Node2D) -> void:
	var pr: Rect2 = pl.rect()
	for f in fruit:
		if f["state"] == "hang" and _fruit_rect(f).intersects(pr):
			drop_fruit(f)


func strike(r: Rect2, _attack_id: int) -> void:
	for p in pods:
		if p["state"] == "closed" and r.intersects(_pod_rect(p)):
			_swell(p)
	for f in fruit:
		if f["state"] == "hang" and r.intersects(_fruit_rect(f)):
			drop_fruit(f)


func shot_hit(shot: Dictionary) -> void:
	var sp: Vector2 = shot["pos"]
	var rad := float(shot.get("radius", 6.0))
	for p in pods:
		if p["state"] == "closed" and (p["pos"] as Vector2).distance_to(sp) <= POD_HIT + rad:
			_swell(p)
	if shot["owner"] == "player":
		for f in fruit:
			if f["state"] == "hang" and _fruit_rect(f).grow(rad).has_point(sp):
				drop_fruit(f)


static func _pod_rect(p: Dictionary) -> Rect2:
	return Rect2((p["pos"] as Vector2) - Vector2(POD_HIT, POD_HIT), Vector2(POD_HIT, POD_HIT) * 2.0)


static func _fruit_rect(f: Dictionary) -> Rect2:
	return Rect2((f["pos"] as Vector2) - FRUIT_HALF, FRUIT_HALF * 2.0)


func on_respawn() -> void:
	## A snuff: the air clears, the pods close, every rotten run grows back,
	## and every fallen glowfruit hangs again (a retry of a dark grove has its
	## light back; a boss arena's fruit keep their own rule, on_boss_reset).
	clouds.clear()
	flashes.clear()
	_spored_t = 0.0
	if world != null and world.has_method("undim"):
		world.undim("spores")
	for p in pods:
		p["state"] = "closed"
	for r in runs:
		if r["state"] != "idle":
			r["state"] = "idle"
			_redraw_run(r)
	for f in fruit:
		if not f["arena"] and f["state"] != "hang":
			_rehang(f)


func on_boss_reset() -> void:
	## A retry: the arena's fruit hangs again and its pods close.
	for f in fruit:
		if f["arena"]:
			_rehang(f)
	for p in pods:
		if p["arena"]:
			p["state"] = "closed"
	clouds = clouds.filter(func(c): return not _in_arena(c["p"]))


func fray(r: Dictionary) -> float:
	## 0..1: how frayed a held run is (for the look).
	if r["state"] != "held":
		return 0.0
	return clampf((ftime() - float(r["t"]) - FRAY) / maxf(knob("rotten_hold") - FRAY, 0.01), 0.0, 1.0)


func fruit_light(f: Dictionary) -> Dictionary:
	## {r, s, gameplay} of a glowfruit now ({} when it gives none).
	match f["state"]:
		"hang", "fall":
			return {"r": FRUIT_HANG_R, "s": FRUIT_HANG_S, "gameplay": true}
		"lit":
			var left := FRUIT_LIFE - (ftime() - float(f["t"]))
			var k := 1.0
			if left < FRUIT_GUTTER:
				k = 0.72 + 0.28 * absf(sin(ftime() * 9.0 + sin(ftime() * 23.0) * 2.0))
			return {"r": FRUIT_LIT_R * k, "s": FRUIT_LIT_S, "gameplay": true}
		"ember":
			return {"r": FRUIT_EMBER_R, "s": 0.35, "gameplay": false}
	return {}


# ---------------------------------------------------------------- lights

func lights() -> Array:
	var out := []
	var v := view().grow(160.0)
	for p in pods:
		if not v.has_point(p["pos"]):
			continue
		match p["state"]:
			"closed":
				out.append({"p": p["pos"], "r": POD_GLOW_R, "s": POD_GLOW_S, "kind": "eye", "tint": Color(SPORE, 0.5)})
			"swell":
				var k := clampf((ftime() - float(p["t"])) / maxf(knob("pod_tell"), 0.01), 0.0, 1.0)
				out.append({"p": p["pos"], "r": 28.0 + 18.0 * k, "s": 0.5 + 0.4 * k, "kind": "tell", "tint": Color(SPORE, 0.8)})
	for c in clouds:
		if float(c["burn"]) >= 0.0 or not v.grow(float(c["r"])).has_point(c["p"]):
			continue
		# In and out over a quarter second, so a blot never pops.
		var fade := clampf(float(c["t"]) / 0.25, 0.0, 1.0) * clampf((float(c["life"]) - float(c["t"])) / 0.4, 0.0, 1.0)
		var cr := maxf(cloud_r(c), 1.0)
		out.append({"p": c["p"], "r": cr / CLOUD_SHADER_K, "s": -CLOUD_HUSH * fade, "kind": "hush", "rule_r": cr})
	# Glowfruit is lamplight: lit_at asks for it anywhere, so it isn't culled
	# by the view (the packer culls what it draws).
	for f in fruit:
		if f["state"] == "gone":
			continue
		var fl := fruit_light(f)
		if fl.is_empty():
			continue
		if fl["gameplay"]:
			out.append({"p": f["pos"], "r": float(fl["r"]), "s": float(fl["s"]), "kind": "altar", "tag": "lamp",
					"gameplay": true, "rule_r": FRUIT_LIT_R if f["state"] == "lit" else FRUIT_HANG_R, "tint": Color(AMBER, 0.35)})
		else:
			out.append({"p": f["pos"], "r": float(fl["r"]), "s": float(fl["s"]), "kind": "deco", "tint": Color(AMBER, 0.5)})
	for fx in flashes:
		var k := float(fx["t"]) / BURN_TIME
		out.append({"p": fx["p"], "r": BURN_FLASH_R, "s": 0.9 * (1.0 - k), "kind": "tell", "tint": Color(1.0, 0.6, 0.25, 0.6)})
	return out


# ---------------------------------------------------------------- the secret cue

func _find_updraft() -> void:
	## 3-3's odd sight: the silver bell's attic sits over a crack of false
	## stone; the vine nearest the crack gets pale spores drifting up it.
	var bell := Vector2i(-1, -1)
	for e in level.entities:
		if e["kind"] == "silver_bell":
			bell = e["cell"]
	if bell.x < 0:
		return
	var sec := str(level.get("secret")) if level.get("secret") != null else ""
	if sec == "" or not FileAccess.file_exists("res://levels/%s.txt" % sec):
		return
	var crack := Vector2i(-1, -1)
	for y in range(bell.y + 1, mini(bell.y + 5, level.height)):
		for dx in range(-3, 4):
			if crack.x < 0 and level.tile(bell.x + dx, y) == LevelData.FALSE_STONE:
				crack = Vector2i(bell.x + dx, y)
	if crack.x < 0:
		return
	var best := -1
	for x in _cols:
		if best < 0 or absi(int(x) - crack.x) < absi(best - crack.x):
			best = int(x)
	if best < 0 or absi(best - crack.x) > 10:
		return
	var ys: Array = (_cols[best] as Array).duplicate()
	ys.sort()
	_updraft = {"x": best, "y0": int(ys[0]), "y1": int(ys[ys.size() - 1]), "crack": LevelData.cell_center(crack)}


# ---------------------------------------------------------------- drawing

func _cell_range() -> Vector2i:
	var v := view().grow(TILE * 2)
	return Vector2i(maxi(floori(v.position.x / TILE), 0), mini(floori(v.end.x / TILE), level.width - 1))


func draw_under(ci: CanvasItem) -> void:
	var cr := _cell_range()
	var v := view().grow(TILE * 2)
	_tb.clear()
	if _draws_vines:
		for x in range(cr.x, cr.y + 1):
			if _cols.has(x):
				for y in _cols[x]:
					_draw_vine_cell(x, y)
	elif _paint_rotten:
		# The painter leaves rotten runs to us: its own vine_cell, each frame,
		# swaying as the run frays, flickering as it grows back, gone while
		# it's snapped.
		for r in runs:
			var x := int(r["x"])
			if r["state"] == "snapped" or x < cr.x or x > cr.y:
				continue
			var a := 1.0
			var sway := 0.0
			if r["state"] == "regrow":
				a = 0.3 + 0.3 * absf(sin(ftime() * 20.0))
			elif r["state"] == "held":
				sway = sin(ftime() * 50.0) * 3.0 * fray(r)
			for y in range(int(r["y0"]), int(r["y1"]) + 1):
				_painter.vine_cell(_tb, level, x, y, true, _pal, sway, a)
	for c in clouds:
		if v.grow(float(c["r"])).has_point(c["p"]):
			_draw_haze(c)
	for p in pods:
		if v.has_point(p["pos"]) and not _pod_tex(ci, p):
			_draw_pod(p)
	for f in fruit:
		if f["state"] != "gone" and v.has_point(f["pos"]) and not _fruit_tex(ci, f):
			_draw_fruit(f)
	_tb.flush(ci)


func _draw_vine_cell(x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var i = _run_of.get(cell)
	var col := VINE
	var lit := VINE_LIT
	var a := 1.0
	var sway := 0.0
	if i != null:
		var r: Dictionary = runs[i]
		col = ROTTEN
		lit = ROTTEN_LIT
		match r["state"]:
			"snapped":
				return
			"regrow":
				a = 0.3 + 0.3 * absf(sin(ftime() * 20.0))
			"held":
				sway = sin(ftime() * 50.0) * 3.0 * fray(r)
	var px := x * TILE + 13.0 + sway
	var py := float(y) * TILE
	_tb.rect(Rect2(px - 1.5, py, 8.0, TILE), Color(OUTLINE, 0.8 * a))
	_tb.rect(Rect2(px, py, 5.0, TILE), Color(col, a))
	_tb.rect(Rect2(px + 1.0, py, 1.5, TILE), Color(lit, 0.6 * a))
	# Leaf pairs every 12 px, tilted in turn.
	for k in 3:
		var ly := py + 4.0 + k * 11.0
		var side := -1.0 if (y * 3 + k) % 2 == 0 else 1.0
		var base := Vector2(px + 2.5, ly)
		var tip := base + Vector2(side * 9.0, -3.0)
		_tb.tri(base, tip, base + Vector2(side * 4.0, 4.0), Color(col.lightened(0.12) if i == null else col, a))
	if i != null:
		# Grey bark flecks: a rotten run reads as rotten in any light.
		_tb.rect(Rect2(px - 1.0, py + 9.0, 3.0, 2.0), Color(BONE, 0.5 * a))
		_tb.rect(Rect2(px + 3.0, py + 22.0, 3.0, 2.0), Color(BONE, 0.5 * a))


func _draw_haze(c: Dictionary) -> void:
	## A cloud's body where it's lit (the dark's blot is its Hush light).
	var r := cloud_r(c)
	var p: Vector2 = c["p"]
	var fade := clampf(float(c["t"]) / 0.25, 0.0, 1.0) * clampf((float(c["life"]) - float(c["t"])) / 0.4, 0.0, 1.0)
	if float(c["burn"]) >= 0.0:
		fade *= 1.0 - float(c["burn"]) / BURN_TIME
	for k in 3:
		var q := r * (1.0 - k * 0.28)
		var off := Vector2(sin(ftime() * 0.9 + k * 2.1 + p.x) * 6.0, cos(ftime() * 0.7 + k) * 4.0)
		_tb.ellipse(p + off, q, q * 0.72, Color(HAZE, 0.10 * fade), 16)


func _pod_key(p: Dictionary) -> String:
	var hang := "hang_" if p["mount"] == "ceiling" else ""
	return "spore_pod_%s%s" % [hang, str(p["state"])]


func _pod_tex(ci: CanvasItem, p: Dictionary) -> bool:
	var key := _pod_key(p)
	if not _tex.has(key):
		return false
	var tx: Texture2D = _tex[key]
	var sz := tx.get_size() * 0.25
	var at: Vector2 = p["pos"]
	var r: Rect2
	match p["mount"]:
		"ceiling":
			r = Rect2(Vector2(at.x - sz.x * 0.5, at.y - 11.0), sz)
		"vine":
			r = Rect2(at - sz * 0.5, sz)
		_:
			r = Rect2(Vector2(at.x - sz.x * 0.5, at.y + 11.0 - sz.y), sz)
	if p["state"] == "swell":
		r.position.x += sin(ftime() * 60.0) * 1.5
	ci.draw_texture_rect(tx, r, false)
	return true


func _draw_pod(p: Dictionary) -> void:
	## The code-drawn puffball: a pale cap with dark gills and a moss collar.
	var at: Vector2 = p["pos"]
	var st: String = p["state"]
	var up := -1.0 if p["mount"] == "ceiling" else 1.0
	if st == "burst":
		# A torn husk.
		_tb.ellipse(at + Vector2(0, 5.0 * up), 8.0, 3.5, Color("5a5040"), 10)
		_tb.tri(at + Vector2(-7, 4.0 * up), at + Vector2(-3, -3.0 * up), at + Vector2(-1, 4.0 * up), Color("8a7e5a"))
		_tb.tri(at + Vector2(7, 4.0 * up), at + Vector2(3, -2.0 * up), at + Vector2(1, 4.0 * up), Color("8a7e5a"))
		return
	var k := 0.0
	var q := 0.0
	if st == "swell":
		k = clampf((ftime() - float(p["t"])) / maxf(knob("pod_tell"), 0.01), 0.0, 1.0)
		q = sin(ftime() * 60.0) * 1.5 * (0.4 + k)
	var rx := 10.0 * (1.0 + 0.25 * k)
	var ry := 9.0 * (1.0 + 0.3 * k)
	var c := at + Vector2(q, 0)
	_tb.ellipse(c, rx + 1.5, ry + 1.5, OUTLINE, 14)
	_tb.ellipse(c, rx, ry, Color("d8d4b0").lerp(SPORE, 0.3 + 0.5 * k), 14)
	_tb.ellipse(c + Vector2(-2.5, -2.5 * up), rx * 0.45, ry * 0.35, Color(1, 1, 0.9, 0.5), 10)
	# Gills round the lower half, and the moss collar where it's rooted.
	for g in 4:
		var gx := -6.0 + g * 4.0
		_tb.rect(Rect2(c + Vector2(gx, 2.0 * up - 1.0), Vector2(1.5, 4.0)), Color("4a4432"))
	_tb.ellipse(c + Vector2(0, (ry - 1.0) * up), rx * 0.8, 3.0, Color("6e8a44"), 10)


func _fruit_tex(ci: CanvasItem, f: Dictionary) -> bool:
	var key := "glowfruit_hang" if f["state"] in ["hang", "fall"] else "glowfruit_lit"
	var dim: bool = f["state"] == "ember" and _tex.has("glowfruit_dim")
	if dim:
		key = "glowfruit_dim"
	if not _tex.has(key):
		return false
	var tx: Texture2D = _tex[key]
	var sz := tx.get_size() * 0.25
	var at: Vector2 = f["pos"]
	var r := Rect2(at - sz * 0.5, sz)
	if f["state"] in ["lit", "ember"]:
		r.position.y = at.y + FRUIT_HALF.y - sz.y
	var m := Color(1, 1, 1) if f["state"] != "ember" or dim else Color(0.55, 0.5, 0.5)
	ci.draw_texture_rect(tx, r, false, m)
	return true


func _draw_fruit(f: Dictionary) -> void:
	## The code-drawn gourd: pale amber, ribbed, on a stem while it hangs.
	var at: Vector2 = f["pos"]
	var st: String = f["state"]
	var cell: Vector2i = f["cell"]
	if st == "hang" and LevelData.is_solid(level.tile(cell.x, cell.y - 1)):
		var top := float(cell.y * TILE)
		_tb.rect(Rect2(Vector2(at.x - 1.0, top), Vector2(2.0, at.y - FRUIT_HALF.y - top + 2.0)), Color("5a4a36"))
	var body := AMBER if st in ["hang", "fall", "lit"] else Color("7a5a3a")
	var ry := FRUIT_HALF.y if st in ["hang", "fall"] else FRUIT_HALF.y * 0.8
	var c := at if st in ["hang", "fall"] else at + Vector2(0, FRUIT_HALF.y - ry)
	_tb.ellipse(c, FRUIT_HALF.x + 1.5, ry + 1.5, OUTLINE, 14)
	_tb.ellipse(c, FRUIT_HALF.x, ry, body, 14)
	_tb.rect(Rect2(c + Vector2(-0.75, -ry + 1.0), Vector2(1.5, ry * 2.0 - 2.0)), Color(body.darkened(0.25), 0.8))
	_tb.ellipse(c + Vector2(-3.0, -3.0), 2.5, 3.5, Color(1.0, 0.95, 0.8, 0.6), 8)


func draw_glow(glow: Node2D) -> void:
	## Above the dark: every vine's vein (the style is this module's:
	## _take_veins), a rotten run's fray and regrow, pods' glints and tells,
	## the clouds' motes and burns, the glowfruit's cores, a sigil's glint
	## by fallen fruit, Wick's sputter in a cloud, the secret's updraft.
	if _veins < 0:
		_take_veins()
	var cr := _cell_range()
	var v := view().grow(TILE * 2)
	_tb.clear()
	var vc: Color = _vein.get("color", VEIN["color"])
	vc.a = float(_vein.get("alpha", VEIN["alpha"]))
	var vw := float(_vein.get("width", VEIN["width"]))
	for x in range(cr.x, cr.y + 1):
		if not _cols.has(x):
			continue
		for y in _cols[x]:
			var i = _run_of.get(Vector2i(x, y))
			if i == null:
				# A sound vine's vein, on its stem (EdgeLines' wavy line).
				var pts := PackedVector2Array()
				for k in 5:
					pts.append(Vector2(x * TILE + VEIN_X + sin((y * 4 + k) * 0.9 + x) * 2.0 * (0.0 if k == 0 or k == 4 else 1.0),
							float(y) * TILE + k * TILE / 4.0))
				_tb.polyline(pts, vw, vc)
				continue
			var r: Dictionary = runs[i]
			match r["state"]:
				"idle", "held":
					# A rotten run reads as rotten in the dark: a grey vein
					# with pale bark flecks, never a sound vine's green (it
					# shakes as it frays; _draw_fray reddens it).
					var sw := sin(ftime() * 50.0) * 3.0 * fray(r) if r["state"] == "held" else 0.0
					var cx := x * TILE + VEIN_X + sw
					_tb.rect(Rect2(cx - 1.5, float(y) * TILE, 3.0, TILE), Color(_rot_idle, 0.5))
					_tb.rect(Rect2(cx - 4.5, float(y) * TILE + 7.0 + (y % 2) * 4.0, 3.0, 2.0), Color(BONE, 0.6))
					_tb.rect(Rect2(cx + 2.5, float(y) * TILE + 20.0 - (y % 2) * 5.0, 3.0, 2.0), Color(BONE, 0.6))
				"regrow":
					# The tell it's coming back: a pale flicker where it was.
					var a := 0.2 + 0.35 * absf(sin(ftime() * 20.0))
					_tb.rect(Rect2(x * TILE + VEIN_X - 1.5, float(y) * TILE, 3.0, TILE), Color(0.9, 0.85, 0.7, a))
				# snapped: nothing (the run isn't there)
	for r in runs:
		_draw_fray(r, cr)
	for p in pods:
		if v.has_point(p["pos"]):
			_glow_pod(p)
	for c in clouds:
		if v.grow(float(c["r"])).has_point(c["p"]):
			_glow_cloud(c)
	for fx in flashes:
		var k := float(fx["t"]) / BURN_TIME
		_tb.ring(fx["p"], 20.0 + 70.0 * k, 5.0 * (1.0 - k) + 1.0, Color(1.0, 0.65, 0.3, 0.8 * (1.0 - k)), 20)
	for f in fruit:
		if f["state"] != "gone" and v.has_point(f["pos"]):
			_glow_fruit(f)
	_glow_sigils()
	_glow_sputter()
	_glow_updraft(v)
	_tb.flush(glow)


func _take_veins() -> void:
	## The vine veins are this module's. EdgeLines draws a "vine" style (its
	## World 3 default, where a theme has no EDGES of its own) statically on
	## every vine cell, rotten ones too, so a snapped run would keep its vein
	## for the 5 s it's gone. Take the style over: drop it from EdgeLines
	## (its chunks redrawn without it) and draw the sound veins here in its
	## colour, and each rotten run's with its state. A1's W3 themes have no
	## vine style (their EDGES leave the veins to this module): VEIN then.
	_veins = 1
	var e = world.get("edges") if world != null else null
	if e == null or e.get("styles") == null:
		return
	var keep := []
	for st in e.styles:
		if str(st.get("what", "")) == "vine":
			if str(_vein.get("color", "")) == str(VEIN["color"]):   # (a theme's vine_vein wins)
				_vein = st
		else:
			keep.append(st)
	if keep.size() == (e.styles as Array).size():
		return
	e.styles = keep
	if e.get("chunks") != null and e.has_method("redraw_chunk"):
		for i in (e.chunks as Array).size():
			e.redraw_chunk(i)


func _glow_sigils() -> void:
	## A sigil near glowfruit glints once any of that fruit is down (3-1's
	## grove: "glinting once any fruit is down"), until it's picked up.
	var got = world.get("sigils_got") if world != null else null
	for s in _sigils:
		var i := int(s["index"])
		if got is Array and i < (got as Array).size() and bool(got[i]):
			continue
		var down := false
		for fi in s["fruit"]:
			down = down or fruit[fi]["state"] != "hang"
		if not down:
			continue
		var p: Vector2 = s["pos"]
		var k := 0.5 + 0.5 * sin(ftime() * 4.0 + p.x * 0.01)
		var c := Color(1.0, 0.92, 0.62, 0.35 + 0.45 * k)
		var l := 7.0 + 5.0 * k
		_tb.quad(p + Vector2(0, -l), p + Vector2(1.6, 0), p + Vector2(0, l), p + Vector2(-1.6, 0), c)
		_tb.quad(p + Vector2(-l, 0), p + Vector2(0, -1.6), p + Vector2(l, 0), p + Vector2(0, 1.6), c)
		_tb.circle(p, 2.2 + k, Color(1.0, 0.97, 0.85, 0.5 + 0.4 * k), 8)


func _draw_fray(r: Dictionary, cr: Vector2i) -> void:
	## A fraying rotten run, above the dark and above Wick: its vein reddens,
	## thickens and shakes, fibres fall from every cell, and near the snap it
	## tears in the middle. The look of vine_creak (a muted phone sees it).
	var k := fray(r)
	if k <= 0.0 or int(r["x"]) < cr.x - 1 or int(r["x"]) > cr.y + 1:
		return
	var cx := float(int(r["x"]) * TILE) + 15.5
	var shake := sin(ftime() * 50.0) * 3.0 * k
	var vein := _rot_vein.lerp(Color(1.0, 0.42, 0.22), k)
	var y0 := float(int(r["y0"]) * TILE)
	var y1 := float((int(r["y1"]) + 1) * TILE)
	_tb.rect(Rect2(cx - 2.0 + shake, y0, 4.0, y1 - y0), Color(vein, 0.35 + 0.55 * k))
	for yy in range(int(r["y0"]), int(r["y1"]) + 1):
		for f in 3:
			var sd := float(yy * 7 + f * 13)
			var fall := fmod(ftime() * (55.0 + f * 15.0) + sd * 3.1, 44.0)
			var side := -1.0 if (f + yy) % 2 == 0 else 1.0
			var fx := cx + side * (5.0 + 3.0 * f + 4.0 * k) + shake * 0.5
			_tb.rect(Rect2(fx - 2.0, float(yy) * TILE + fall - 4.0, 4.0, 3.0), Color(1.0, 0.9, 0.7, 0.9 * k * (1.0 - fall / 44.0 * 0.5)))
	if k > 0.5 and fmod(ftime() * 8.0, 1.0) < 0.6:
		var mid := (y0 + y1) * 0.5
		_tb.rect(Rect2(cx - 7.0 + shake, mid - 1.0, 14.0, 3.0), Color(1.0, 0.95, 0.8, 0.8 * k))


func _glow_pod(p: Dictionary) -> void:
	var at: Vector2 = p["pos"]
	match p["state"]:
		"closed":
			# A faint chartreuse rim: a pod reads in the dark before it's near.
			var br := 0.3 + 0.08 * sin(ftime() * 2.0 + at.x)
			_tb.ring(at, 11.0, 1.5, Color(SPORE, br), 14)
		"swell":
			var k := clampf((ftime() - float(p["t"])) / maxf(knob("pod_tell"), 0.01), 0.0, 1.0)
			var q := sin(ftime() * 60.0) * 1.5 * (0.4 + k)
			_tb.circle(at + Vector2(q, 0), 12.0 + 8.0 * k, Color(SPORE, 0.18 + 0.3 * k), 16)
			_tb.ring(at + Vector2(q, 0), 12.0 + 4.0 * k, 2.0, Color(SPORE.lightened(0.3), 0.6 + 0.4 * k), 16)
			# "ffff": three puffs leaking from its top.
			for i in 3:
				var ph := fmod(ftime() * 3.0 + i / 3.0, 1.0)
				_tb.circle(at + Vector2(-6.0 + i * 6.0, -10.0 - ph * 12.0), 1.5 + ph * 1.5, Color(SPORE, 0.7 * (1.0 - ph)), 8)


func _glow_cloud(c: Dictionary) -> void:
	## 14 motes orbit the rule edge (alpha >= 0.35), a few drift inside.
	var p: Vector2 = c["p"]
	var r := cloud_r(c)
	var fade := clampf(float(c["t"]) / 0.25, 0.0, 1.0) * clampf((float(c["life"]) - float(c["t"])) / 0.4, 0.0, 1.0)
	if float(c["burn"]) >= 0.0:
		fade *= 1.0 - float(c["burn"]) / BURN_TIME
	var sd := fmod(p.x * 0.013 + float(c["life"]), TAU)
	for i in 14:
		var a := sd + i * TAU / 14.0 + ftime() * (0.5 if i % 2 == 0 else -0.35)
		var rr := r * (0.9 + 0.1 * sin(ftime() * 2.0 + i))
		var q := p + Vector2(cos(a), sin(a) * 0.8) * rr
		_tb.circle(q, 2.0 + (i % 3) * 0.6, Color(SPORE, (0.35 + 0.25 * absf(sin(ftime() * 1.7 + i))) * fade), 8)
	for i in 6:
		var a2 := sd * 2.0 + i * 1.7 + ftime() * 0.8
		var q2 := p + Vector2(cos(a2), sin(a2 * 1.3)) * r * 0.5
		_tb.circle(q2, 1.5, Color(SPORE, 0.3 * fade), 6)


func _glow_fruit(f: Dictionary) -> void:
	var at: Vector2 = f["pos"]
	match f["state"]:
		"hang", "fall":
			_tb.circle(at, 7.0, Color(1.0, 0.8, 0.45, 0.35), 12)
			_tb.circle(at + Vector2(0, 1), 3.0, Color(1.0, 0.92, 0.7, 0.7), 8)
		"lit":
			var left := FRUIT_LIFE - (ftime() - float(f["t"]))
			var k := 1.0
			if left < FRUIT_GUTTER:
				k = 0.45 + 0.55 * absf(sin(ftime() * 9.0 + sin(ftime() * 23.0) * 2.0))
			var c := at + Vector2(0, 2)
			_tb.circle(c, 9.0, Color(1.0, 0.78, 0.4, 0.4 * k), 12)
			_tb.circle(c, 3.5, Color(1.0, 0.95, 0.75, 0.85 * k), 8)
		"ember":
			_tb.circle(at + Vector2(0, 3), 2.5, Color(1.0, 0.6, 0.3, 0.55), 8)


func _glow_sputter() -> void:
	## Dimmed by spores, Wick's flame sputters sideways: grey puffs blown off
	## it (never the low-life flicker).
	if _spored_t <= 0.0:
		return
	var pl := player()
	var rig = world.get("rig")
	if pl == null or not pl.alive or rig == null or not rig.has_method("flame_point"):
		return
	var fp: Vector2 = rig.flame_point()
	var dir := -float(pl.facing) if absf(pl.velocity.x) > 20.0 else (1.0 if sin(ftime() * 1.3) > 0.0 else -1.0)
	for i in 4:
		var ph := fmod(ftime() * 2.6 + i * 0.25, 1.0)
		var q := fp + Vector2(dir * (4.0 + ph * 18.0), -4.0 - ph * 8.0 + sin(ftime() * 13.0 + i) * 1.5)
		_tb.circle(q, 1.5 + ph * 2.5, Color(0.7, 0.72, 0.62, 0.55 * (1.0 - ph)), 8)


func _glow_updraft(v: Rect2) -> void:
	if _updraft.is_empty():
		return
	var x := (int(_updraft["x"]) + 0.5) * TILE
	var y_top := float(int(_updraft["y0"]) * TILE)
	var y_bot := float((int(_updraft["y1"]) + 1) * TILE)
	var crack: Vector2 = _updraft["crack"]
	if not v.grow(64.0).intersects(Rect2(minf(x, crack.x) - 20.0, crack.y - 20.0, absf(x - crack.x) + 40.0, y_bot - crack.y + 40.0)):
		return
	# 14 pale motes (A1: against the theme's 56 settling ones, 9 read thin).
	for i in UPDRAFT_MOTES:
		var ph := fmod(ftime() * 0.22 + float(i) / UPDRAFT_MOTES, 1.0)
		# Up the vine, then over to the crack, then gone into it.
		var q: Vector2
		var up := 0.75
		if ph < up:
			q = Vector2(x + sin(ftime() * 1.4 + i * 1.9) * 7.0, lerpf(y_bot - 8.0, y_top + 4.0, ph / up))
		else:
			q = Vector2(x, y_top + 4.0).lerp(crack, (ph - up) / (1.0 - up))
		var a := 0.55 * clampf(ph * 6.0, 0.0, 1.0) * clampf((1.0 - ph) * 6.0, 0.0, 1.0)
		_tb.circle(q, 1.8, Color(0.92, 0.95, 0.8, a), 8)
	# The crack glints faintly silver where the spores slip in.
	_tb.rect(Rect2(crack - Vector2(9, 1), Vector2(18, 2)), Color(0.85, 0.9, 1.0, 0.25 + 0.15 * sin(ftime() * 3.0)))


# ---------------------------------------------------------------- sound

func _snd(name: String) -> void:
	if world != null and world.has_method("_sfx"):
		world._sfx(name)


func _tell(name: String, seconds: float) -> void:
	if world == null:
		return
	if world.has_method("_tell_sfx"):
		world._tell_sfx(name, seconds)
	elif world.has_method("_sfx"):
		world._sfx(name)
