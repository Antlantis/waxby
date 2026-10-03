extends RefCounted
## The five callings: base stats at level 1 (before level scaling), their
## resource, Special and quirk names, the kit script that plays them, and
## their skill trees. Static data; hero.gd turns it into live numbers.
##
## Skill tree shape (every calling): a root node (5 ranks, rank 1 free) and
## two branches, each with two Tier-1 nodes (2 ranks), one Tier-2 node
## (3 ranks) and one Tier-3 capstone (1 rank; a hero may take only ONE
## capstone of the two). Gates: Tier 2 needs 3 points in its branch; Tier 3
## needs hero level 8 and 5 points in its branch. Root rank n needs level
## 3*(n-1). A node's "stat" feeds hero.gd directly; nodes without one are
## read by the kit through stats.ranks[id].
##
## The v3 tree (spec §2, the "deep" tree, on when `deep` is true): the root
## goes to 7 ranks (rank 6 at L18, 7 at L26; its per arrays hold 8, the
## eighth for of the Keeper), each branch gains a Tier-4 "Deep" node (3 ranks,
## L16 + 7 points in the branch) and a Tier-5 "Mastery" node (2 ranks, L24 +
## 10 points), and the other capstone opens at L30: 32 points in all. It
## stays off (v2's 19-point tree, exactly) until skills_panel.gd draws Tiers 4
## and 5; a save's Vigil ranks turn back into points on the first load after
## (Game._settle_points runs on every load).

const ALL := {
	"knight": {"name": "Candleknight", "enabled": true, "role": "Sword and shield", "ease": 5,
		"hp": 100.0, "basic": 10.0, "cooldown": 0.28, "crit": 0.05, "crit_mult": 1.5, "dr": 0.0,
		"light_mult": 1.0, "flame_scale": 1.0, "flame_tip": [60, 19],
		"res_name": "Grace", "res_color": "f2c75a", "res_max": 100.0, "res_start": 50.0, "res_regen": 4.0, "res_pips": 0,
		"special": "Aegis", "special_text": "Hold still to guard. Hold a direction to shield-rush.",
		"sign_tip": "Hold the shield to guard. Tap it on the run to rush",
		"quirk": "Ledge Grab", "quirk_id": "ledge_grab", "quirk_text": "Catch ledges you just missed.",
		"color": "7aa8ff", "voice": 1.2, "kit": "res://scripts/kits/knight.gd",
		"melee": true, "reach": Vector2(38, 34)},
	"witch": {"name": "Taperwitch", "enabled": true, "role": "Fire caster", "ease": 2,
		"hp": 75.0, "basic": 7.0, "cooldown": 0.30, "crit": 0.08, "crit_mult": 1.5, "dr": 0.0,
		"light_mult": 1.0, "flame_scale": 0.95, "flame_tip": [84, 6],
		"res_name": "Melt", "res_color": "7ec8ff", "res_max": 100.0, "res_start": 100.0, "res_regen": 14.0, "res_pips": 0,
		"special": "Flare", "special_text": "Hold to charge a flare, let go to throw it. It leaves a light.",
		"sign_tip": "Hold the fireball to charge a flare. Let go to throw it",
		"quirk": "Drift", "quirk_id": "drift", "quirk_text": "Press jump again while falling to float.",
		"color": "c78aff", "voice": 1.45, "kit": "res://scripts/kits/witch.gd",
		"melee": false, "reach": Vector2(38, 34)},
	"runner": {"name": "Sootrunner", "enabled": true, "role": "Knife rogue", "ease": 2,
		"hp": 85.0, "basic": 7.0, "cooldown": 0.24, "crit": 0.15, "crit_mult": 1.75, "dr": 0.0,
		"light_mult": 0.9, "flame_scale": 0.85, "flame_tip": [78, 26],
		"res_name": "Smoke", "res_color": "d0d4e0", "res_max": 3.0, "res_start": 3.0, "res_regen": 1.0 / 2.2, "res_pips": 3,
		"special": "Smoke Step", "special_text": "Dash through anything. Hits from behind always crit.",
		"sign_tip": "Tap the smoke to dash through foes and shots",
		"quirk": "Moth Cling", "quirk_id": "cling", "quirk_text": "Slide down walls and kick off them.",
		"color": "a8b0c0", "voice": 1.3, "kit": "res://scripts/kits/runner.gd",
		"melee": false, "reach": Vector2(38, 34)},
	"founder": {"name": "Bellfounder", "enabled": true, "role": "Maul bruiser", "ease": 4,
		"hp": 125.0, "basic": 20.0, "cooldown": 0.48, "crit": 0.05, "crit_mult": 1.5, "dr": 0.0,
		"light_mult": 1.0, "flame_scale": 1.25, "flame_tip": [62, 22],
		"res_name": "Heat", "res_color": "ff6a2a", "res_max": 100.0, "res_start": 0.0, "res_regen": 0.0, "res_pips": 0,
		"special": "Peal", "special_text": "Slam the ground: shockwaves run both ways.",
		"sign_tip": "Hit foes to build Heat, then tap the bell to slam",
		"quirk": "Stampede", "quirk_id": "stampede", "quirk_text": "Keep running to charge through small foes.",
		"color": "ff8a4a", "voice": 0.95, "kit": "res://scripts/kits/founder.gd",
		"melee": true, "reach": Vector2(50, 46)},
	"sexton": {"name": "Sexton", "enabled": true, "role": "Wisp summoner", "ease": 3,
		"hp": 90.0, "basic": 8.0, "cooldown": 0.30, "crit": 0.05, "crit_mult": 1.5, "dr": 0.0,
		"light_mult": 1.0, "flame_scale": 1.0, "flame_tip": [62, 6],
		"res_name": "Dirge", "res_color": "b49cff", "res_max": 100.0, "res_start": 50.0, "res_regen": 3.0, "res_pips": 0,
		"special": "Knell", "special_text": "Call a mourning wisp. Hold to send them all in.",
		"sign_tip": "Tap the wisp to call one. Wisps shoot when you hit",
		"quirk": "Grave Step", "quirk_id": "grave_step", "quirk_text": "Jump again in midair off a bone ledge.",
		"color": "b49cff", "voice": 1.05, "kit": "res://scripts/kits/sexton.gd",
		"melee": true, "reach": Vector2(42, 32)},
}

const ORDER := ["knight", "witch", "runner", "founder", "sexton"]
const CHILL_THAW := 1.5          # Grave Chill: seconds a rooted foe is left free before the next root (kits/sexton.gd, and its card)

# The gates (contract §7). ROOT_GATE[have] is the level root rank have+1 needs
# (v2's 3*(n-1) for ranks 2-5); GATES[tier] the level and branch points.
const ROOT_GATE := [0, 3, 6, 9, 12, 18, 26]
const GATES := {2: {"level": 0, "branch": 3}, 3: {"level": 8, "branch": 5},
		4: {"level": 16, "branch": 7}, 5: {"level": 24, "branch": 10}}
const SECOND_CAPSTONE := 30
const ROOT_MAX := 5              # v2's root ranks
const DEEP_ROOT_MAX := 7         # v3's
const DEEP_TREE := true          # the v3 tree in play (see the note above; tests flip `deep`)
static var deep := DEEP_TREE
# Root ranks 6 and 7 (spec §2.2), and an 8th for of the Keeper over a full
# root: the card numbers. The kits keep their own tables (kits/*.gd).
const DEEP_ROOT_PER := {"k_aegis": [1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.4, 2.5],
		"w_flare": [4.0, 4.4, 4.8, 5.2, 5.6, 6.0, 6.4, 6.6],
		"r_step": [112, 120, 128, 136, 144, 144, 144, 144],
		"f_peal": [1.2, 1.35, 1.5, 1.65, 1.8, 1.95, 2.1, 2.1],
		"x_knell": [45, 53, 61, 69, 77, 85, 93, 93]}
const AEGIS_BLOCK := [50, 45, 40, 35, 30]              # the knight root's {b}: block share by rank
const DEEP_AEGIS_BLOCK := [50, 45, 40, 35, 30, 27, 25, 25]


static func node(id: String, branch: int, tier: int, max_rank: int, name: String, text: String, per: Array, stat := "", flag := "") -> Dictionary:
	return {"id": id, "branch": branch, "tier": tier, "max": max_rank, "name": name, "text": text, "per": per, "stat": stat, "flag": flag}


static var _trees := {}
static var _trees_deep := false


static func tree(cls: String) -> Array:
	if _trees.is_empty() or _trees_deep != deep:
		_trees = _build_trees()
		_trees_deep = deep
		if deep:
			_add_deep(_trees)
	return _trees.get(cls, [])


static func set_deep(on: bool) -> void:
	## Turns the v3 tree on or off (tests; the game reads DEEP_TREE).
	deep = on
	_trees = {}


static func root_max() -> int:
	return DEEP_ROOT_MAX if deep else ROOT_MAX


static func _add_deep(trees: Dictionary) -> void:
	## The v3 tree over v2's: the root to 7 ranks, and Tiers 4 and 5 in both
	## branches (spec §2.3). "stat" nodes feed hero.gd; the others are read by
	## the kits through stats.ranks[id].
	var extra := {
		"knight": [
			node("k_bastion", 0, 4, 3, "Bastion", "Blocks cost {v}% less Grace.", [15, 25, 35]),
			node("k_sanctuary", 0, 5, 2, "Sanctuary", "A Perfect Guard rings out: foes within 90 px are stunned for {v}s.", [0.6, 1.0]),
			node("k_vigilant", 1, 4, 3, "Vigilant Edge", "+{v}% damage.", [8, 16, 24], "dmg_pct"),
			node("k_judgment", 1, 5, 2, "Judgment", "Finishers always crit and deal +{v}% more.", [30, 60]),
		],
		"witch": [
			node("w_pyre", 0, 4, 3, "Pyre", "+{v}% Special damage.", [15, 30, 45], "special_pct"),
			node("w_wildfire", 0, 5, 2, "Wildfire", "A burning foe that dies bursts into 3 sparks for {v}% basic.", [60, 100]),
			node("w_molten", 1, 4, 3, "Molten Reserve", "+{v}% Melt regeneration.", [15, 30, 45], "res_regen_pct"),
			node("w_candlemold", 1, 5, 2, "Candlemold", "Waxed foes take +{v}% damage from you.", [15, 25]),
		],
		"runner": [
			node("r_nightstalk", 0, 4, 3, "Nightstalker", "+{v}% crit chance.", [4, 7, 10], "crit"),
			node("r_phantom", 0, 5, 2, "Phantom Step", "A Step through a foe refunds {v}% of a pip (once per Step).", [25, 50]),
			node("r_whetted", 1, 4, 3, "Whetted", "+{v}% damage.", [8, 16, 24], "dmg_pct"),
			node("r_fan", 1, 5, 2, "Fan of Knives", "Every 6th throw fans out {v} extra knives.", [2, 3]),
		],
		"founder": [
			node("f_temper", 0, 4, 3, "Tempering", "+{v}% Special damage.", [15, 30, 45], "special_pct"),
			node("f_moltencore", 0, 5, 2, "Molten Core", "White-hot or Molten, harm taken is cut {v}%.", [15, 25]),
			node("f_resonance", 1, 4, 3, "Resonance", "+{v}% damage.", [8, 16, 24], "dmg_pct"),
			node("f_carillon", 1, 5, 2, "Carillon", "Peal waves run {v}% further.", [20, 35]),
		],
		"sexton": [
			node("x_host", 0, 4, 3, "Host of Mourners", "+{v}% Special damage.", [15, 30, 45], "special_pct"),
			node("x_requiem", 0, 5, 2, "Requiem", "Wisps keep firing {v}% longer after a hit.", [30, 60]),
			node("x_warden", 1, 4, 3, "Gravewarden", "+{v}% damage.", [8, 16, 24], "dmg_pct"),
			node("x_barrow", 1, 5, 2, "Barrow Bind", "Rooted foes take +{v}% damage from you.", [20, 35]),
		],
	}
	for cls in trees:
		for n in trees[cls]:
			if n["branch"] == -1 and DEEP_ROOT_PER.has(n["id"]):
				n["max"] = DEEP_ROOT_MAX
				n["per"] = (DEEP_ROOT_PER[n["id"]] as Array).duplicate()
		(trees[cls] as Array).append_array(extra.get(cls, []))


static func _build_trees() -> Dictionary:
	return {
		"knight": [
			node("k_aegis", -1, 0, 5, "Aegis", "Rush {v}x basic. Guard blocks cost {b}% of the hit.", [1.2, 1.4, 1.6, 1.8, 2.0]),
			node("k_tempered", 0, 1, 2, "Tempered Steel", "+{v}% max life.", [16, 32], "max_hp_pct"),
			node("k_devout", 0, 1, 2, "Devout Guard", "A Perfect Guard heals {v}% life.", [5, 10]),
			node("k_mirror", 0, 2, 3, "Mirrored Glass", "Perfect Guard throws shots back for {v}% basic.", [100, 150, 200]),
			node("k_unbroken", 0, 3, 1, "Unbroken Vigil", "Guard from every side, walk faster while guarding.", [1], "", "unbroken"),
			node("k_keen", 1, 1, 2, "Keen Edge", "+{v}% crit chance.", [10, 20], "crit"),
			node("k_honed", 1, 1, 2, "Honed Blade", "+{v}% basic damage.", [20, 40], "basic_pct"),
			node("k_crescent", 1, 2, 3, "Radiant Crescent", "Finishers throw a crescent for {v}% basic.", [70, 85, 100]),
			node("k_dawn", 1, 3, 1, "Dawnbringer", "Rush leaves holy fire and works once in midair.", [1], "", "dawn"),
		],
		"witch": [
			node("w_flare", -1, 0, 5, "Flare", "A full flare deals {v}x basic.", [4.0, 4.4, 4.8, 5.2, 5.6]),
			node("w_hotter", 0, 1, 2, "Hotter Wick", "+{v}% damage.", [20, 40], "dmg_pct"),
			node("w_twin", 0, 1, 2, "Twin Spark", "{v}% chance a spark flies as a pair.", [35, 60]),
			node("w_kindle", 0, 2, 3, "Kindle", "Sparks burn for {v}% basic a tick.", [15, 22, 30]),
			node("w_sunburst", 0, 3, 1, "Sunburst", "A full flare splits into four.", [1], "", "sunburst"),
			node("w_reservoir", 1, 1, 2, "Deep Reservoir", "+{v} max Melt.", [30, 60], "res_max_add"),
			node("w_waxskin", 1, 1, 2, "Candlewax Skin", "{v}% of harm is paid from Melt.", [20, 35]),
			node("w_seal", 1, 2, 3, "Sealing Wax", "Flares slow foes for {v}s.", [1.5, 2.0, 2.5]),
			node("w_effigy", 1, 3, 1, "Wax Effigy", "When snuffed, a wax double bursts and you relight.", [1], "", "effigy"),
		],
		"runner": [
			node("r_step", -1, 0, 5, "Smoke Step", "Dash {v} px. Sooted foes take more harm.", [112, 120, 128, 136, 144]),
			node("r_deadly", 0, 1, 2, "Deadly Aim", "+{v}% crit damage.", [30, 60], "crit_mult_add"),
			node("r_quick", 0, 1, 2, "Quick Hands", "{v}% faster throws.", [16, 30], "cooldown_pct"),
			node("r_veil", 0, 2, 3, "Smoke Veil", "Steps leave a cloud that eats shots for {v}s.", [1.0, 1.5, 2.0]),
			node("r_mercy", 0, 3, 1, "Mercy Stroke", "Backstabs finish off wounded foes.", [1], "", "mercy"),
			node("r_keen", 1, 1, 2, "Keen Knives", "+{v}% knife damage.", [20, 40], "basic_pct"),
			node("r_bandolier", 1, 1, 2, "Bandolier", "{v}% chance of a second knife.", [30, 55]),
			node("r_ricochet", 1, 2, 3, "Ricochet", "Knives bounce off walls {v} times.", [1, 1, 2]),
			node("r_cuts", 1, 3, 1, "Thousand Cuts", "A Step ends with a knife at every foe near.", [1], "", "cuts"),
		],
		"founder": [
			node("f_peal", -1, 0, 5, "Peal", "Waves deal {v}x basic.", [1.2, 1.35, 1.5, 1.65, 1.8]),
			node("f_bellows", 0, 1, 2, "Deep Bellows", "Heat cools {v}% slower.", [50, 90]),
			node("f_stoked", 0, 1, 2, "Stoked", "+{v} Heat per hit.", [6, 12]),
			node("f_slag", 0, 2, 3, "Slag", "Hits smolder for {v}% basic a tick.", [12, 18, 24]),
			node("f_crucible", 0, 3, 1, "Crucible", "At full Heat, become Molten for 6s.", [1], "", "crucible"),
			node("f_hide", 1, 1, 2, "Thick Hide", "+{v}% damage reduction.", [6, 12], "dr"),
			node("f_heavy", 1, 1, 2, "Heavy Hand", "+{v}% basic damage.", [20, 40], "basic_pct"),
			node("f_after", 1, 2, 3, "Aftershock", "Peals and stomps stun for {v}s.", [0.6, 0.9, 1.2]),
			node("f_greatbell", 1, 3, 1, "The Great Bell", "Every 5th hit rings a great peal.", [1], "", "greatbell"),
		],
		"sexton": [
			node("x_knell", -1, 0, 5, "Knell", "Wisp motes deal {v}% basic.", [45, 53, 61, 69, 77]),
			node("x_bright", 0, 1, 2, "Brighter Souls", "Wisps +{v}% damage and brighter.", [30, 60]),
			node("x_ward", 0, 1, 2, "Faithful Dead", "A popping wisp soaks {v}% of a hit.", [50, 70]),
			node("x_harvest", 0, 2, 3, "Soul Harvest", "{v}% chance a kill leaves a free wisp.", [20, 35, 50]),
			node("x_choir", 0, 3, 1, "Choir of the Lost", "+2 wisps; the toll chains.", [1], "", "choir"),
			node("x_digger", 1, 1, 2, "Deep Digger", "+{v}% spade damage.", [20, 40], "basic_pct"),
			node("x_gravedirt", 1, 1, 2, "Gravedirt", "+{v}% max life.", [16, 32], "max_hp_pct"),
			node("x_chill", 1, 2, 3, "Grave Chill", "Spade hits root a foe for {v}s, then it thaws for %ss." % str(CHILL_THAW), [0.6, 0.8, 1.0]),
			node("x_lastbell", 1, 3, 1, "The Last Bell", "Wisps give themselves up to relight you.", [1], "", "lastbell"),
		],
	}


static func ids() -> Array:
	return ORDER.duplicate()


static func enabled_ids() -> Array:
	return ORDER.filter(func(c): return ALL[c]["enabled"])


static func info(cls: String) -> Dictionary:
	return ALL.get(cls, ALL["knight"])


static func find_node(cls: String, id: String) -> Dictionary:
	for n in tree(cls):
		if n["id"] == id:
			return n
	return {}


static func at_rank(table: Array, rank: int):
	## A per-rank table's value at a rank (1-based). Past the table's end the
	## last step goes on: the root is 5 ranks, and gear's "of the Keeper"
	## (+1 rank each, on a weapon and a charm) lifts it to 6 or 7, which must
	## still be worth something. (Ints stay ints: [2, 2, 3, 3, 3] stays 3.)
	var n := table.size()
	if n == 0:
		return 0
	if rank <= n:
		return table[clampi(rank - 1, 0, n - 1)]
	var last = table[n - 1]
	var step = (last - table[n - 2]) if n >= 2 else 0
	return last + step * (rank - n)


static func node_text(n: Dictionary, rank: int) -> String:
	## A node's card line at a rank (1-based), from its per-rank numbers.
	var v = at_rank(n["per"], rank)
	var s: String = n["text"]
	return s.replace("{v}", str(v)).replace("{b}", str(at_rank(DEEP_AEGIS_BLOCK if deep else AEGIS_BLOCK, rank)))


static func can_buy(cls: String, id: String, ranks: Dictionary, hero_level: int, points: int) -> String:
	## "" when the next rank can be bought, else why not.
	var n := find_node(cls, id)
	if n.is_empty():
		return "unknown"
	var have: int = int(ranks.get(id, 1 if n["branch"] == -1 else 0))
	if have >= int(n["max"]):
		return "maxed"
	if points <= 0:
		return "no points"
	if n["branch"] == -1:
		# Rank have+1 needs ROOT_GATE[have]: v2's 3*have up to rank 5, then
		# L18 and L26 (the deep tree's ranks 6 and 7).
		var need: int = ROOT_GATE[have] if have < ROOT_GATE.size() else ROOT_GATE[ROOT_GATE.size() - 1]
		return "" if hero_level >= need else "level %d" % need
	var in_branch := 0
	var capstones := 0
	for m in tree(cls):
		if m["branch"] == n["branch"]:
			in_branch += int(ranks.get(m["id"], 0))
		if m["tier"] == 3 and int(ranks.get(m["id"], 0)) > 0:
			capstones += 1
	var tier := int(n["tier"])
	if tier == 3 and capstones > 0:
		# The other capstone: never in v2's tree; at L30 in the deep tree.
		if not deep:
			return "one capstone only"
		if hero_level < SECOND_CAPSTONE:
			return "level %d" % SECOND_CAPSTONE
	if GATES.has(tier):
		var g: Dictionary = GATES[tier]
		if hero_level < int(g["level"]):
			return "level %d" % int(g["level"])
		if in_branch < int(g["branch"]):
			return "%d points in branch" % int(g["branch"])
	return ""


static func tree_points(cls: String) -> int:
	## Points the whole tree can take (root rank 1 is free): 19 in v2's tree,
	## 32 in the deep one (where both capstones can be had, the second at L30).
	var n := 0
	for m in tree(cls):
		n += int(m["max"]) - (1 if m["branch"] == -1 else 0)
	# v2: only one capstone of the two.
	return n if deep else n - 1
