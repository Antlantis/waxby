extends RefCounted
## The base of every v3 feature module (scripts/features/*.gd, contract.md
## §4). level_features.gd (the dispatcher) builds one of each and calls
## these every tick or frame; every hook here is a safe no-op, so a module
## overrides only what it needs, and every module works when its glyphs and
## headers are absent (the modes build levels in memory).
##
## Each module declares its difficulty numbers as
##     const DIFF_KNOBS := {"knob": {"dusk": a, "nightfall": b, "witching": c}}
## and reads them with knob("knob"). (The table isn't declared here: GDScript
## won't let a script redeclare a constant its parent has, so knob() reads
## the module's own table. A module with no table has no knobs.)
##
## Timed things read world.ftime, never wall time or a random number. Draw
## rects with ci.draw_rect and everything else into a TriBatch (no
## draw_circle / draw_colored_polygon / draw_polyline: a test greps for it).

const LevelData := preload("res://scripts/level_data.gd")
const Combat := preload("res://scripts/combat.gd")
const TILE := 32
const DIFFS := ["dusk", "nightfall", "witching"]

var world: Node
var level: RefCounted


func build(w: Node, lv: RefCounted) -> void:
	world = w
	level = lv


func step(_dt: float) -> void:
	## Reads world.ftime.
	pass


func touch(_player: Node2D) -> void:
	## After the hero moved (what his body touches).
	pass


func strike(_r: Rect2, _attack_id: int) -> void:
	## The hero's attack rect this tick (glass ignores it).
	pass


func shot_hit(_shot: Dictionary) -> void:
	## A live shot (enemy or hero) this tick, after it moved: set shot.life to
	## 0 to stop it here.
	pass


func lights() -> Array:
	## [{p, r, s, tint?, tag?, gameplay: bool}] (gameplay lights count for lit_at).
	return []


func reflectors() -> Array:
	## [{x0, x1, y, tint, k}] (glass floors world_lights.gd mirrors lights in).
	return []


func draw_under(_ci: CanvasItem) -> void:
	## Over the tiles, under props and monsters (rects and a TriBatch only).
	pass


func draw_glow(_glow: Node2D) -> void:
	## Above the dark: tells and glints.
	pass


func on_respawn() -> void:
	## The hero relit at an altar after a snuff.
	pass


func on_boss_reset() -> void:
	## A boss fight reset (a retry): arena props restore.
	pass


func knob(name: String) -> float:
	## DIFF_KNOBS[name][world.diff] from this module's own table (Dusk's when
	## the difficulty has no entry; 0 when the knob doesn't exist).
	var table: Dictionary = (get_script() as Script).get_script_constant_map().get("DIFF_KNOBS", {})
	var row = table.get(name, {})
	if not (row is Dictionary):
		return float(row)
	var d := str(world.diff) if world != null and "diff" in world else "dusk"
	return float(row.get(d, row.get("dusk", 0.0)))


static func knobs_of(script: Script) -> Dictionary:
	## A module's DIFF_KNOBS (the tests read them).
	return script.get_script_constant_map().get("DIFF_KNOBS", {})


func ftime() -> float:
	return float(world.ftime) if world != null else 0.0


func player() -> Node2D:
	return world.player if world != null else null


func view() -> Rect2:
	return world.view_rect() if world != null and world.has_method("view_rect") else Rect2(-1e6, -1e6, 2e6, 2e6)
