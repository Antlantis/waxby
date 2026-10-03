extends RefCounted
## A hero's live numbers from everything that feeds them: the calling's base,
## the level, skill ranks, gear and the relics on the belt. Static.
##
## The returned keys are frozen (the kits, world and screens read them):
##   level, cls, max_hp, basic, cooldown, crit, crit_mult, dr, res_max, res_regen,
##   dmg_pct, basic_pct, special_pct, elite_pct, stomp, stomp_pct,
##   light_pct, light_mult, flame_scale, knock_mult, invuln, on_kill_heal,
##   reach (Vector2), attack_speed, root_rank, ranks {node: rank}, flags {},
##   vigil (overflow ranks), legends {id: true}
## and v3's (contract §7; none reaches movement): dim_resist (dimming eased,
##   cap 50%), shot_dr (shots, shards and falling glass, cap 50%), xp_pct
##   (cap 50%), ember_pct (cap 100%), flask_pct (flask heal, cap 50%),
##   flask_add (flask charges, a count), marks (Candlemarks, 0..25, from the
##   hero's XP), light_relic (the relics' light, also inside light_pct)
##
## flags holds the capstones' flags (true), and the numbers behind worn
## Legendaries (Items.LEGENDS[id].fx, e.g. "gutterlight_below": 0.35) and
## a few relics ("range_mult", "beacon_mult", and v3's RELIC_FLAGS), for
## the world and kits.
##
## The caps (decisions.md): damage reduction 35%, max life +60%, on-kill
## healing 3%, gear light +40% (the Great Bellows adds its 30% on top),
## crit chance 60%, attack speed +30%. Level scaling: life 1.10^(L-1),
## damage 1.09^(L-1). Stats never reach the hero's movement.
##
## Candlemarks (past L40) add +1% damage and +1% life each, the life as its
## own multiplier outside the +60% cap. Vigil ranks do too with the v3 tree
## (Classes.deep); with v2's tree they stay inside the cap, as in v2.

const Combat := preload("res://scripts/combat.gd")
const Classes := preload("res://scripts/classes.gd")
const Items := preload("res://scripts/items.gd")
const Progression := preload("res://scripts/progression.gd")

const GEAR_LIGHT_CAP := 0.40
const ATTACK_SPEED_CAP := 0.30
const COOLDOWN_CUT_CAP := 0.50
const ON_KILL_HEAL_CAP := 0.03
const VIGIL_EACH := 0.02          # damage and max life per Vigil rank
const MARK_EACH := 0.01           # damage and max life per Candlemark
const SHOT_DR_CAP := 0.50
const XP_PCT_CAP := 0.50
const EMBER_PCT_CAP := 1.00
const FLASK_PCT_CAP := 0.50
const FLASK_ADD_CAP := 2          # Game.flask_charges holds the total to 3
# The flame grows with the tree: x(1 + this) for each of its big tiers (a
# capstone, a Deep node, a Mastery node) the hero owns any of, +24% at most.
# Only its look: the flame is drawn from flame_scale (glow.gd), and its height
# is also the life gauge, so it stays modest; the light is light_radius's.
const FLAME_TIER := 0.08
const FLAME_TIERS := [3, 4, 5]
# A hero's look (the modes' cosmetics; cosmetics.gd reads it with these defaults).
const LOOK_DEFAULT := {"flame": "tallow", "trim": "", "trim_color": "calling", "glow": ""}
# Relics that change numbers (the rest are rules the world checks with
# Game.equipped). reach_mult is melee reach; range_mult is for shots.
const RELIC_MODS := {
	"tallow_heart": {"max_hp_pct": 0.15},
	"longsword": {"reach_mult": 1.4, "range_mult": 1.3},
	"bellows": {"light_relic": 0.30, "beacon_mult": 1.3},
	"choir_bone": {"on_kill_heal": 0.02},
	# v3's (spec §8.3; within the caps: attack speed +30%, dim_resist 50%,
	# shot_dr 50%, flask charges 3 in all through Game.flask_charges)
	"clockheart": {"attack_speed_pct": 0.10, "res_regen_pct": 0.15},
	"leaded_pane": {"shot_dr": 0.20},
	"sanctum_glass": {"elite_pct": 0.20},
	"hush_pearl": {"dim_resist": 0.50, "light_relic": 0.10},
	"taper_match": {"flask_add": 1.0},
}
# v3 relics whose rules the world or a feature plays: their numbers, copied
# into stats.flags while worn (as a Legendary's fx is). sporeward: a spore
# dim entry eased by spore_resist (on top of dim_resist) and spore bursts
# x spore_burst; bone_flute: every Nth kill a bone moth for coef x basic;
# hoarfrost_bell: stomps and bonks slow foes by chill_slow for chill_t s.
const RELIC_FLAGS := {
	"sporeward": {"spore_resist": 0.5, "spore_burst": 0.5},
	"bone_flute": {"bone_flute_every": 8, "bone_flute_coef": 1.5},
	"hoarfrost_bell": {"chill_slow": 0.40, "chill_t": 2.0},
}
# How much of a hero's damage the DMG chip counts as coming from Specials,
# and from elite and boss fights (so "of the Bell" and Hallowed show up).
const SPECIAL_SHARE := 0.25
const ELITE_SHARE := 0.15


static func blank(cls := "knight", level := 1) -> Dictionary:
	## A hero record as saved.
	return {"cls": cls, "level": level, "xp": 0, "points": 0, "skills": {}, "vigil": 0,
			"equip": {"weapon": null, "candle": null, "coat": null, "boots": null, "charm": null},
			"satchel": [], "belt": [], "wares": [], "wares_seed": 0,
			"deepest": 0, "look": LOOK_DEFAULT.duplicate()}


static func spent(hero: Dictionary) -> int:
	## Skill points in the tree (the root's free first rank doesn't count).
	var cls: String = hero.get("cls", "knight")
	var n := 0
	var skills: Dictionary = hero.get("skills", {})
	for id in skills:
		var node := Classes.find_node(cls, id)
		if node.is_empty():
			continue
		n += maxi(int(skills[id]) - (1 if node["branch"] == -1 else 0), 0)
	return n


static func room(hero: Dictionary) -> int:
	## Points the tree can still take (after this, points become Vigil ranks).
	return maxi(Classes.tree_points(hero.get("cls", "knight")) - spent(hero) - int(hero.get("points", 0)), 0)


static func stats(hero: Dictionary, relics_on: Array = [], diff_id := "dusk") -> Dictionary:
	var cls: String = hero.get("cls", "knight")
	var base: Dictionary = Classes.info(cls)
	var level: int = clampi(int(hero.get("level", 1)), 1, Combat.LEVEL_CAP)
	var s := {
		"level": level, "cls": cls,
		"max_hp": float(base["hp"]), "basic": float(base["basic"]), "cooldown": float(base["cooldown"]),
		"crit": float(base["crit"]), "crit_mult": float(base["crit_mult"]), "dr": float(base["dr"]),
		"res_max": float(base["res_max"]), "res_regen": float(base["res_regen"]),
		"dmg_pct": 0.0, "basic_pct": 0.0, "special_pct": 0.0, "elite_pct": 0.0,
		"stomp": Combat.STOMP_BASE, "stomp_pct": 0.0, "light_pct": 0.0, "light_mult": float(base["light_mult"]),
		"flame_scale": float(base["flame_scale"]), "knock_mult": float(base.get("knock_mult", 0.5 if cls == "founder" else 1.0)),
		"invuln": float(Combat.diff(diff_id)["invuln"]), "on_kill_heal": 0.0,
		"reach": base["reach"], "attack_speed": 1.0, "root_rank": 0, "ranks": {}, "flags": {}, "legends": {},
		"vigil": maxi(int(hero.get("vigil", 0)), 0),
		"dim_resist": 0.0, "shot_dr": 0.0, "xp_pct": 0.0, "ember_pct": 0.0, "flask_pct": 0.0, "flask_add": 0.0,
		"marks": Progression.marks_of(int(hero.get("xp", 0))), "light_relic": 0.0,
	}
	var acc := {"max_hp_pct": 0.0, "crit_mult_add": 0.0, "cooldown_pct": 0.0, "attack_speed_pct": 0.0,
			"res_max_add": 0.0, "res_regen_pct": 0.0, "light_gear": 0.0, "light_relic": 0.0, "reach_mult": 1.0}
	# Skills: every node's rank, and the stat it feeds.
	var skills: Dictionary = hero.get("skills", {})
	var ranks := {}
	var big := {}                     # the big tiers owned (FLAME_TIERS)
	for n in Classes.tree(cls):
		var r: int = int(skills.get(n["id"], 1 if n["branch"] == -1 else 0))
		ranks[n["id"]] = r
		if r <= 0:
			continue
		if FLAME_TIERS.has(int(n["tier"])):
			big[int(n["tier"])] = true
		if str(n["flag"]) != "":
			s["flags"][n["flag"]] = true
		if str(n["stat"]) != "":
			var per: Array = n["per"]
			var v := float(per[clampi(r - 1, 0, per.size() - 1)])
			if n["stat"] != "res_max_add":
				v /= 100.0   # the tree's numbers are percents; extra resource is a count
			_apply(s, acc, n["stat"], v)
	s["ranks"] = ranks
	s["flame_scale"] = float(s["flame_scale"]) * (1.0 + FLAME_TIER * big.size())
	# Gear: implicits, affixes, Legendary powers.
	var equip: Dictionary = hero.get("equip", {})
	for slot in Items.SLOTS:
		var it = equip.get(slot)
		if not (it is Dictionary):
			continue
		var m := Items.mods(it)
		for k in m:
			if k.begins_with("legend_"):
				continue
			if k == "light_pct":
				acc["light_gear"] += float(m[k])
			else:
				_apply(s, acc, k, float(m[k]))
		var lid := str(it.get("legend", ""))
		if Items.LEGENDS.has(lid):
			var leg: Dictionary = Items.LEGENDS[lid]
			if leg.has("cls") and leg["cls"] != cls:
				continue   # another calling's charm does nothing
			s["legends"][lid] = true
			for k in leg.get("fx", {}):
				s["flags"][k] = leg["fx"][k]
			for k in leg.get("stats", {}):
				_apply(s, acc, k, float(leg["stats"][k]))
	# Relics on the belt.
	for id in relics_on:
		var rf: Dictionary = RELIC_FLAGS.get(id, {})
		for k in rf:
			s["flags"][k] = rf[k]
		var rm: Dictionary = RELIC_MODS.get(id, {})
		for k in rm:
			match k:
				"reach_mult":
					acc["reach_mult"] *= float(rm[k])
				"range_mult", "beacon_mult":
					s["flags"][k] = float(s["flags"].get(k, 1.0)) * float(rm[k])
				_:
					_apply(s, acc, k, float(rm[k]))
	# Vigil ranks (skill points past a full tree): +2% damage and life each;
	# Candlemarks +1% each. Their life is its own multiplier, outside the cap
	# (v2's tree keeps Vigil life inside it, as v2 did).
	var vig := float(s["vigil"])
	var marks := float(s["marks"])
	var life_mult := 1.0 + MARK_EACH * marks
	if Classes.deep:
		life_mult *= 1.0 + VIGIL_EACH * vig
	else:
		acc["max_hp_pct"] += VIGIL_EACH * vig
	s["dmg_pct"] += VIGIL_EACH * vig + MARK_EACH * marks
	# Level scaling, then the caps.
	var hp_pct: float = minf(acc["max_hp_pct"], Combat.HP_PCT_CAP)
	s["max_hp"] = roundf(float(base["hp"]) * Combat.p_hp(level) * (1.0 + hp_pct) * life_mult)
	s["basic"] = float(base["basic"]) * Combat.p_dmg(level) * (1.0 + s["basic_pct"])
	s["stomp"] = Combat.STOMP_BASE * Combat.p_dmg(level) * (1.0 + s["stomp_pct"]) * (1.25 if cls == "founder" else 1.0)
	s["crit"] = clampf(s["crit"], 0.0, Combat.CRIT_CAP)
	s["crit_mult"] = float(base["crit_mult"]) + acc["crit_mult_add"]
	s["dr"] = clampf(s["dr"], 0.0, Combat.DR_CAP)
	s["attack_speed"] = 1.0 + clampf(acc["attack_speed_pct"], 0.0, ATTACK_SPEED_CAP)
	s["cooldown"] = float(base["cooldown"]) * (1.0 - clampf(acc["cooldown_pct"], 0.0, COOLDOWN_CUT_CAP)) / s["attack_speed"]
	s["res_max"] = float(base["res_max"]) + acc["res_max_add"]
	s["res_regen"] = float(base["res_regen"]) * (1.0 + acc["res_regen_pct"])
	s["on_kill_heal"] = clampf(s["on_kill_heal"], 0.0, ON_KILL_HEAL_CAP)
	s["reach"] = (base["reach"] as Vector2) * acc["reach_mult"]
	s["light_pct"] = minf(acc["light_gear"] + s["light_pct"], GEAR_LIGHT_CAP) + acc["light_relic"]
	s["light_relic"] = acc["light_relic"]
	s["root_rank"] = int(s["root_rank"])
	s["dim_resist"] = clampf(s["dim_resist"], 0.0, Combat.DIM_RESIST_CAP)
	s["shot_dr"] = clampf(s["shot_dr"], 0.0, SHOT_DR_CAP)
	s["xp_pct"] = clampf(s["xp_pct"], 0.0, XP_PCT_CAP)
	s["ember_pct"] = clampf(s["ember_pct"], 0.0, EMBER_PCT_CAP)
	s["flask_pct"] = clampf(s["flask_pct"], 0.0, FLASK_PCT_CAP)
	s["flask_add"] = clampi(roundi(float(s["flask_add"])), 0, FLASK_ADD_CAP)
	return s


static func _apply(s: Dictionary, acc: Dictionary, stat: String, v: float) -> void:
	## One stat bonus: into the sums that are capped or scaled at the end,
	## else straight onto the stat. v is a fraction (a count for ranks).
	if acc.has(stat):
		acc[stat] = float(acc[stat]) + v
	elif stat == "root_rank":
		s["root_rank"] = int(s["root_rank"]) + int(v)
	elif s.has(stat) and (s[stat] is float or s[stat] is int):
		s[stat] = float(s[stat]) + v


static func dps_estimate(s: Dictionary) -> float:
	## Rough damage per second, for comparing gear: the basic attack with
	## crits, plus a share for Specials and for elites and bosses.
	var crit := minf(float(s["crit"]), Combat.CRIT_CAP)
	var per_hit: float = float(s["basic"]) * (1.0 + float(s["dmg_pct"])) * (1.0 + crit * (float(s["crit_mult"]) - 1.0))
	# A Sootrunner's Special (Smoke Step) only does damage through Thousand
	# Cuts, so without it "of the Bell" and root ranks add nothing to her DMG.
	var share := SPECIAL_SHARE
	if str(s.get("cls", "")) == "runner" and not (s.get("flags", {}) as Dictionary).has("cuts"):
		share = 0.0
	var extra := share * (float(s.get("special_pct", 0.0)) + 0.1 * float(s.get("root_rank", 0))) \
			+ ELITE_SHARE * float(s.get("elite_pct", 0.0))
	return per_hit * (1.0 + extra) / maxf(float(s["cooldown"]), 0.05)


static func ehp_estimate(s: Dictionary) -> float:
	## Effective life: how much harm the hero can take.
	return float(s["max_hp"]) / (1.0 - clampf(float(s["dr"]), 0.0, Combat.DR_CAP))


static func compare(hero: Dictionary, slot: String, item, relics_on: Array = [], diff_id := "dusk") -> Dictionary:
	## The pickup card's two chips: {dmg: %, life: %} if the item replaced
	## what's in that slot now.
	var before := stats(hero, relics_on, diff_id)
	var h2: Dictionary = hero.duplicate(false)
	var eq: Dictionary = (hero.get("equip", {}) as Dictionary).duplicate(false)
	eq[slot] = item
	h2["equip"] = eq
	var after := stats(h2, relics_on, diff_id)
	var d0 := dps_estimate(before)
	var e0 := ehp_estimate(before)
	return {"dmg": roundf((dps_estimate(after) / maxf(d0, 0.01) - 1.0) * 100.0),
			"life": roundf((ehp_estimate(after) / maxf(e0, 0.01) - 1.0) * 100.0)}


static func is_upgrade(chips: Dictionary) -> bool:
	## The auto-equip rule: nothing worse and something better.
	var d := float(chips.get("dmg", 0.0))
	var l := float(chips.get("life", 0.0))
	return d >= 0.0 and l >= 0.0 and (d > 0.0 or l > 0.0)
