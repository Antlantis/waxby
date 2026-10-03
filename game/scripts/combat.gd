extends RefCounted
## The numbers behind every hit: level scaling for heroes and monsters, the
## difficulty table, the damage roll, enemy damage, and damage reduction.
## Static only. Movement is never touched by any of this.
##
## v3 (spec §1, contract §7): areas run 1..31 on Dusk and are compressed on
## the harder difficulties (DIFF area0 / per: Nightfall 30..40, Witching
## 40..45). Enemies grow 1.12 an area up to the knee (area 32), then like
## hero damage (1.09); the Depth factor adds up to +20% life and +30% damage
## over areas 13..32. Areas 1..12 (Worlds 1 and 2 on Dusk) are exactly v2's.

const DIFFS := ["dusk", "nightfall", "witching"]
# "area0" and "per" replace v2's "offset" (0 / 10 / 20): area_level() below.
const DIFF := {
	"dusk": {"name": "Dusk", "area0": 1, "per": 1, "hp": 1.0, "dmg": 1.0, "tells": 1.0, "anoint": 0.06, "omens": 1,
			"max_anoint": 2, "xp": 1.0, "embers": 1, "drop": 1.0, "light": 1.0, "pit": 0.33, "altar": 0.50,
			"wax": 0.30, "flask": 0.40, "flask_charges": 1, "respawn": false, "invuln": 0.9, "douse_pct": 0.08},
	"nightfall": {"name": "Nightfall", "area0": 30, "per": 3, "hp": 1.4, "dmg": 1.25, "tells": 0.85, "anoint": 0.12, "omens": 2,
			"max_anoint": 3, "xp": 1.25, "embers": 2, "drop": 1.2, "light": 0.92, "pit": 0.38, "altar": 0.35,
			"wax": 0.25, "flask": 0.35, "flask_charges": 2, "respawn": true, "invuln": 0.85, "douse_pct": 0.10},
	"witching": {"name": "Witching Hour", "area0": 40, "per": 6, "hp": 1.8, "dmg": 1.5, "tells": 0.72, "anoint": 0.20, "omens": 2,
			"max_anoint": 4, "xp": 1.5, "embers": 3, "drop": 1.4, "light": 0.85, "pit": 0.45, "altar": 0.20,
			"wax": 0.20, "flask": 0.30, "flask_charges": 2, "respawn": true, "invuln": 0.8, "douse_pct": 0.12},
}
const CANDLE_STRENGTH := {"gentle": 0.75, "normal": 1.0, "fierce": 1.3}   # the settings dial: enemy damage
const DR_CAP := 0.35
const HP_PCT_CAP := 0.60
const CRIT_CAP := 0.60
const LIGHT_MIN := 56.0
const LIGHT_MAX := 230.0
const STOMP_BASE := 20.0
const LEVEL_CAP := 40

# Enemy scaling (spec §1.2).
const KNEE := 32                # past this area, enemies grow like hero damage
const LATE_GROWTH := 1.09
const DEPTH_HP := 0.010         # enemy life  +1.0% an area from 13 to 32 (at most +20%)
const DEPTH_DMG := 0.015        # enemy blows +1.5% an area from 13 to 32 (at most +30%)
const DEPTH_FROM := 12          # the last area with no Depth (World 2's boss)
const DEPTH_SPAN := 20          # areas of Depth (13..32)

# Harm and light (spec §1.4, §1.7; world.gd applies them).
const BLOW_CLAMP := {"dusk": 0.45, "nightfall": 0.60, "witching": 0.0}   # a single blow's most, of max life (0 = none)
const DIM_FLOOR := {"dusk": 0.50, "nightfall": 0.40, "witching": 0.30}   # every dim together, at the least
const DIM_RESIST_CAP := 0.50
# Effective-share caps on Dusk (after Depth, trim, elite multipliers and DR,
# against the reference knight where the monster appears): the table-scan
# test in test_progression.
const SHARE_CAPS := {"fodder": 0.30, "heavy": 0.36, "anointed": 0.40, "dread": 0.45, "warden": 0.45,
		"boss_big": 0.34, "boss_touch": 0.25}

# Elites on Dusk by world (spec §1.6): Anointed chance, most per level, Omens
# each, and the chance of one more Omen. Nightfall and Witching use DIFF.
# Build 1 (Dusk pushes back from World 3): W3-W6 about twice v3's chance, a
# second Omen from W3 and a fourth Anointed in W6. W1-W2 stay v2's (the
# Descent and v2 parity read them).
const DUSK_ELITES := {1: [0.06, 2, 1, 0.0], 2: [0.06, 2, 1, 0.0], 3: [0.12, 3, 1, 0.2],
		4: [0.14, 3, 1, 0.3], 5: [0.16, 3, 1, 0.5], 6: [0.18, 4, 1, 0.6]}

# Dusk with teeth (Build 1, the author's ruling after his playtest): from
# World 3 a Dusk altar heals DUSK_TEETH.altar, not the row's 0.50, and
# ordinary monsters come back on a snuff as on Nightfall (half XP and loot,
# no embers). Worlds 1-2 stay gentle; boss numbers are untouched. Story
# levels only: world.gd passes world 0 for a mode or a feel lab.
const DUSK_TEETH_FROM := 3
const DUSK_TEETH := {"altar": 0.40, "respawn": true}

# Embers are worth more deeper down (spec §8.2): DIFF.embers x (1 + (A-1)/6).
# From EMBER_DEPTH_FROM; below it an ember is worth v2's DIFF.embers, so
# Worlds 1 and 2 on Dusk stay as they were (the spec's formula alone would
# make World 2's embers worth 2). Set it to 1 for the formula everywhere.
const EMBER_DEPTH_FROM := 13

# The Hush's phase checkpoints (decisions: Dusk keeps P2 and P3, Nightfall
# keeps P3, Witching resets; modes never checkpoint, world.gd checks that).
const CHECKPOINTS := {"hush": {"dusk": 2, "nightfall": 3}}


static func p_hp(level: int) -> float:
	return pow(1.10, maxi(level, 1) - 1)


static func p_dmg(level: int) -> float:
	return pow(1.09, maxi(level, 1) - 1)


static func e_scale(area: int) -> float:
	## Enemy life, damage and XP at area level A, before Depth. XP uses this
	## alone, so Depth never changes the pacing. 1.12^(A-1) to the knee.
	var a := maxi(area, 1)
	if a <= KNEE:
		return pow(1.12, a - 1)
	return pow(1.12, KNEE - 1) * pow(LATE_GROWTH, a - KNEE)


static func depth(area: int, k: float) -> float:
	## The Depth factor: 1 through area 12, then +k an area to area 32.
	return 1.0 + k * clampi(area - DEPTH_FROM, 0, DEPTH_SPAN)


static func e_hp(area: int) -> float:
	## Enemy life multiplier (enemy.setup_stats).
	return e_scale(area) * depth(area, DEPTH_HP)


static func e_dmg(area: int) -> float:
	## Enemy damage multiplier (enemy.setup_stats, enemy_hit).
	return e_scale(area) * depth(area, DEPTH_DMG)


static func diff(id: String) -> Dictionary:
	return DIFF.get(id, DIFF["dusk"])


static func area_level(level_area: int, diff_id: String) -> int:
	## A level's area on a difficulty: area0 + (header - 1) / per. Dusk is the
	## header itself; Nightfall 30..40 and Witching 40..45 for headers 1..31.
	var d := diff(diff_id)
	return int(d["area0"]) + (maxi(level_area, 1) - 1) / maxi(int(d["per"]), 1)


static func level_area(level: RefCounted, diff_id: String) -> int:
	## The area a World plays a level at: its area_abs header when set (the
	## modes write it), else area_level(area, diff). Works on a level without
	## the v3 fields (area_abs missing reads as unset).
	if level == null:
		return area_level(1, diff_id)
	var abs_a = level.get("area_abs")
	if (abs_a is int or abs_a is float) and int(abs_a) >= 0:
		return maxi(int(abs_a), 1)
	var a = level.get("area")
	return area_level(int(a) if (a is int or a is float) else 1, diff_id)


static func elite_rules(diff_id: String, world: int) -> Dictionary:
	## {anoint (chance), max_anoint, omens (each Anointed's count), second_omen
	## (the chance of one more)}. Dusk by world (spec §1.6); Nightfall and
	## Witching as DIFF. world.gd merges a mode's own rules over this.
	var d := diff(diff_id)
	if diff_id == "dusk" or not DIFF.has(diff_id):
		var row: Array = DUSK_ELITES.get(clampi(world, 1, 6), DUSK_ELITES[1])
		return {"anoint": float(row[0]), "max_anoint": int(row[1]), "omens": int(row[2]), "second_omen": float(row[3])}
	return {"anoint": float(d["anoint"]), "max_anoint": int(d["max_anoint"]), "omens": int(d["omens"]), "second_omen": 0.0}


static func dusk_teeth(diff_id: String, world: int) -> bool:
	## Dusk from World 3 (DUSK_TEETH_FROM): altars heal less and ordinary
	## monsters come back on a snuff. world is 0 for a mode or a feel lab.
	return diff_id == "dusk" and world >= DUSK_TEETH_FROM


static func altar_heal(diff_id: String, world: int) -> float:
	## The share of max life lighting an altar heals (world.gd _light_altar):
	## DIFF.altar, or DUSK_TEETH.altar on Dusk from World 3.
	if dusk_teeth(diff_id, world):
		return float(DUSK_TEETH["altar"])
	return float(diff(diff_id)["altar"])


static func respawns(diff_id: String, world: int) -> bool:
	## Do ordinary monsters come back on a snuff (world.gd respawns_here)?
	## DIFF.respawn (Nightfall, Witching), or Dusk from World 3.
	return bool(diff(diff_id)["respawn"]) or (dusk_teeth(diff_id, world) and bool(DUSK_TEETH["respawn"]))


static func ember_worth(area: int, diff_id: String) -> int:
	## What one ember pickup is worth at this area (the count placed never
	## changes, so "N / M found" stays right).
	var base := int(diff(diff_id)["embers"])
	var a := maxi(area, 1)
	if a < EMBER_DEPTH_FROM:
		return base
	return base * (1 + (a - 1) / 6)


static func checkpoint_allowed(diff_id: String, boss_id: String, phase: int) -> bool:
	## Whether a snuff in this phase keeps the phase on the retry (the Hush
	## only). world.gd also needs the boss's checkpoint() and no mode.
	var at := int((CHECKPOINTS.get(boss_id, {}) as Dictionary).get(diff_id, 0))
	return at > 0 and phase >= at


static func blow_cap(diff_id: String, max_hp: float) -> float:
	## The most one blow may take on this difficulty (INF when unclamped).
	var k := float(BLOW_CLAMP.get(diff_id, 0.0))
	return max_hp * k if k > 0.0 else INF


static func dim_floor(diff_id: String) -> float:
	return float(DIM_FLOOR.get(diff_id, DIM_FLOOR["dusk"]))


static func dim_mult(entries: Array, dim_resist: float, diff_id: String) -> float:
	## The dim pipeline's product (spec §1.7): each entry m eased by the
	## hero's dim_resist to 1 - (1 - m)(1 - r), multiplied, floored per
	## difficulty. (world_lights.gd owns the pipeline; this is its rule.)
	var r := clampf(dim_resist, 0.0, DIM_RESIST_CAP)
	var k := 1.0
	for m in entries:
		k *= 1.0 - (1.0 - clampf(float(m), 0.0, 1.0)) * (1.0 - r)
	return maxf(k, dim_floor(diff_id))


static func roll(stats: Dictionary, coef: float, rng: RandomNumberGenerator, target: Object = null,
		force_crit := false, extra_pct := 0.0) -> Dictionary:
	## One hero hit: {amount: int, crit: bool}. coef is the ability's multiple
	## of the basic attack; extra_pct adds to the damage % (a skill's own bonus).
	var raw: float = float(stats.get("basic", 10.0)) * coef * (1.0 + float(stats.get("dmg_pct", 0.0)) + extra_pct)
	raw *= rng.randf_range(0.9, 1.1)
	var crit := force_crit or rng.randf() < minf(CRIT_CAP, float(stats.get("crit", 0.05)))
	if crit:
		raw *= float(stats.get("crit_mult", 1.5))
	if target != null:
		var st = target.get("status")
		if st is Dictionary:
			if st.get("sooted", 0.0) > 0.0:
				raw *= 1.0 + float(st.get("sooted_bonus", 0.25))
			if st.get("flipped", 0.0) > 0.0:
				raw *= 1.25
	return {"amount": maxi(1, roundi(raw)), "crit": crit}


static func stomp_damage(stats: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var raw: float = float(stats.get("stomp", STOMP_BASE))
	var crit := rng.randf() < minf(CRIT_CAP, float(stats.get("crit", 0.05)))
	if crit:
		raw *= float(stats.get("crit_mult", 1.5))
	return {"amount": maxi(1, roundi(raw)), "crit": crit}


static func enemy_hit(base: float, area: int, diff_id: String, strength := "normal") -> float:
	## What a monster's blow costs a hero before damage reduction (on e_dmg:
	## the same as v2's e_scale through area 12).
	return base * e_dmg(area) * float(diff(diff_id)["dmg"]) * float(CANDLE_STRENGTH.get(strength, 1.0))


static func mitigate(amount: float, dr: float) -> float:
	return amount * (1.0 - clampf(dr, 0.0, DR_CAP))


static func is_back_hit(e: Object, from_x: float) -> bool:
	## A blow from behind: it comes from the side the monster faces away from
	## (never on one that says it has no back: the Prism Saint).
	if e.get("no_back") == true:
		return false
	var facing: int = e.get("facing") if e.get("facing") != null else 1
	return (from_x - float(e.get("position").x)) * facing < 0.0


static func light_radius(f: float, stats: Dictionary, diff_id: String, mults := 1.0, extra := 0.0) -> float:
	## The candle's light from its health share f (0..1).
	var r := (60.0 + 130.0 * clampf(f, 0.0, 1.0)) * float(stats.get("light_mult", 1.0)) * (1.0 + float(stats.get("light_pct", 0.0)))
	r = r * float(diff(diff_id)["light"]) * mults + extra
	return clampf(r, LIGHT_MIN, LIGHT_MAX)


static func flame_height(f: float, stats: Dictionary) -> float:
	## At f = 1/3, 2/3 and 1 this gives v1's three flame sizes (9, 14, 19).
	return (4.0 + 15.0 * clampf(f, 0.0, 1.0)) * float(stats.get("flame_scale", 1.0))


static func short(n: float) -> String:
	## A number for a floater: "1.1k" past four digits.
	if n > 9999.0:
		return "%.1fk" % (n / 1000.0)
	return str(roundi(n))
