extends RefCounted
## Gear: the five slots, rarities, the affix table, rolling a new item, its
## name, its stat changes, what it costs and what Waxley pays for it. Static.
## Items are plain Dictionaries so they save as JSON:
##
##   {uid, slot, base, cls, ilvl, tier, rarity, name, implicit: {id, v, ...},
##    affixes: [{id, t, v}], legend: ""}
##
## "v" values are percents (12 = +12%), except root_rank, which is a count.
## Tiers come from item level: T1 = ilvl 1-9, T2 = 10-19, T3 = 20-29, and in
## v3 T4 = 30-39, T5 = 40+ (item level at most ILVL_CAP). An item never has
## the same affix twice, nor more than 2 prefixes or 2 suffixes. Weapons are
## bound to a calling (cls); so are the class charms.
##
## v3's data is all here (spec §8, contract §7). Phase 1 turns on what Phase
## 0 kept off, now that its readers exist: tiers 4 and 5 roll (MAX_TIER 5:
## world.gd's _item_icon clamps through Items.icon, UI.item_icon and the rig
## clamp to T3), and "of the Lantern" can roll (LANTERN_LIVE: world_lights.gd's
## dim pipeline reads stats.dim_resist). Game sets lantern_live for the
## build: on only once a world whose dims go through world.dim is in it
## (Game.LANTERN_FROM_WORLD, World 3's spores), since W1-W2's douse and
## latch still bypass dim_resist. Neither reaches Worlds 1-2 on Dusk (their
## drops stop at item level 14); the Chandler's stock, at the hero's level,
## reaches T3 at L20 and T4 at L30, as spec §8.1 means.
##
## The 14 Legendaries of v3 (spec §8.4): 8 world pairs (min_area: they drop
## only that deep; a boss's first kill drops one of its world's pair) and 6
## secret prizes (secret: never rolled until found once, Game.legends_found;
## then from their world down). Their powers are fx numbers for world.gd and
## the kits (stats.flags), or stats hero.gd applies itself.
##
## Dusk kills roll richer with depth (kill_weights: areas 13-22, then 23+),
## and never a Common in a story level (build 1; a mode keeps v3's).

const SLOTS := ["weapon", "candle", "coat", "boots", "charm"]
# The slots in play: what drops (kills, bosses, sigil rewards) and what the
# Chandler sells. All five, from 1-1: boots and charms (P1) came with World
# 2 and the P1 callings, and seven Legendaries live only in them.
const LIVE_SLOTS := ["weapon", "candle", "coat", "boots", "charm"]
# v3: spec §8.1 opens boots at area 13 and charms at 18. It was drafted
# against a v2 in which only weapons, candles and coats dropped; this v2
# already drops all five from 1-1, so live_slots() keeps all five unless
# slots_by_area is set (the owner's call: see the PR report).
const BOOTS_FROM := 13
const CHARM_FROM := 18
static var slots_by_area := false
const TIERS := 5              # tiers the tables hold
const MAX_TIER := 5           # tiers that roll (tier_of): every icon user clamps to the art drawn
static var max_tier := MAX_TIER
const LANTERN_LIVE := true    # of the Lantern may roll (the dims read dim_resist)
static var lantern_live := LANTERN_LIVE   # Game narrows it to builds with a dim world (lantern_live)
const ILVL_CAP := 50
const RARITIES := ["common", "magic", "rare", "legendary"]
const RARITY_NAME := {"common": "Common", "magic": "Blessed", "rare": "Rare", "legendary": "Legendary"}
const AFFIX_COUNT := {"common": [0, 0], "magic": [1, 2], "rare": [3, 4], "legendary": [2, 2]}
const SLOT_NAME := {"weapon": "Weapon", "candle": "Candle", "coat": "Coat", "boots": "Boots", "charm": "Charm"}

const BASES := {
	"weapon": {
		"knight": ["Arming Sword", "Vigil Blade", "Dawnsteel", "Carillon Blade", "Lastlight"],
		"witch": ["Taper Staff", "Candelabra Staff", "Chandelier Staff", "Lanternspire", "Sunwick Staff"],
		"runner": ["Wick Knife", "Moth Knife", "Soot Fang", "Glasswing Knife", "Nightneedle"],
		"founder": ["Foundry Maul", "Belfry Maul", "Tenor Maul", "Bourdon Maul", "Tollking"],
		"sexton": ["Grave Spade", "Sexton's Spade", "Ossuary Spade", "Barrow Spade", "Requiem Spade"],
	},
	"candle": ["Tallow Stub", "Chapel Candle", "Pillar Candle", "Paschal Candle", "Beacon Candle"],
	"coat": ["Padded Coat", "Chain Coat", "Choir Plate", "Rime Mail", "Sanctum Plate"],
	"boots": ["Worn Boots", "Pilgrim Boots", "Sabatons", "Rimed Greaves", "Deepwalkers"],
	"charm": ["Bead", "Knot", "Locket", "Reliquary", "Halo"],
}

# id: {kind, stat, word (prefix word or suffix phrase), t: [lo, hi] per tier, slots}.
# Every slot can roll two prefixes and two suffixes, so a Rare always has
# its 3-4 affixes. of the Keeper rolls only on T2+ Rares and better; of the
# Lantern only on T3+ (and only once lantern_live). T4 and T5 are spec §8.1's
# (p_progression.md §9.4); T1-T3 are v2's.
const AFFIXES := {
	"keen": {"kind": "prefix", "stat": "dmg_pct", "word": "Keen", "t": [[6, 10], [12, 18], [20, 30], [32, 42], [45, 60]],
			"slots": ["weapon", "charm"]},
	"waxen": {"kind": "prefix", "stat": "max_hp_pct", "word": "Waxen", "t": [[5, 8], [10, 14], [16, 22], [23, 28], [29, 35]],
			"slots": ["candle", "coat", "boots", "charm"]},
	"warded": {"kind": "prefix", "stat": "dr", "word": "Warded", "t": [[2, 3], [3, 4], [4, 5], [5, 6], [6, 7]],
			"slots": ["coat", "boots"]},
	"bright": {"kind": "prefix", "stat": "light_pct", "word": "Bright", "t": [[5, 8], [9, 12], [13, 18], [18, 22], [22, 26]],
			"slots": ["candle", "coat"]},
	"hallowed": {"kind": "prefix", "stat": "elite_pct", "word": "Hallowed", "t": [[8, 12], [15, 22], [25, 35], [36, 46], [48, 60]],
			"slots": ["weapon", "boots", "charm"]},
	"precision": {"kind": "suffix", "stat": "crit", "word": "of Precision", "t": [[2, 3], [4, 5], [6, 8], [8, 10], [10, 12]],
			"slots": ["weapon", "candle", "charm"]},
	"ruin": {"kind": "suffix", "stat": "crit_mult_add", "word": "of Ruin", "t": [[10, 20], [25, 35], [40, 60], [60, 75], [75, 90]],
			"slots": ["weapon", "charm"]},
	"swift": {"kind": "suffix", "stat": "attack_speed_pct", "word": "of the Swift", "t": [[4, 6], [7, 10], [11, 15], [14, 18], [17, 21]],
			"slots": ["weapon", "charm"]},
	"moth": {"kind": "suffix", "stat": "on_kill_heal", "word": "of the Moth", "t": [[0.5, 1.0], [1.0, 1.5], [1.5, 2.5], [2.0, 2.5], [2.5, 3.0]],
			"slots": ["weapon", "candle", "coat", "boots", "charm"]},
	"bell": {"kind": "suffix", "stat": "special_pct", "word": "of the Bell", "t": [[8, 12], [15, 22], [25, 35], [36, 46], [48, 60]],
			"slots": ["weapon", "candle", "coat", "boots", "charm"]},
	"keeper": {"kind": "suffix", "stat": "root_rank", "word": "of the Keeper", "t": [[1, 1], [1, 1], [1, 1], [1, 1], [1, 1]],
			"slots": ["weapon", "charm"], "min_tier": 2, "min_rarity": "rare"},
	"lantern": {"kind": "suffix", "stat": "dim_resist", "word": "of the Lantern", "t": [[0, 0], [0, 0], [10, 15], [16, 22], [23, 30]],
			"slots": ["candle", "coat", "charm"], "min_tier": 3, "live": "lantern"},
}
# The affix a Blessed starter piece carries (a new calling's kit).
const SIGNATURE := {"weapon": "keen", "candle": "waxen", "coat": "warded", "boots": "warded", "charm": "keen"}
const RARE_FIRST := ["Grim", "Ashen", "Hollow", "Sable", "Guttering", "Pale", "Tolling", "Molten", "Weeping", "Sallow", "Cinder", "Mute"]
# v3's words, one per new world: added to the first-word pool for T4 and T5
# Rares only, so a T1-T3 Rare is named as in v2.
const RARE_FIRST_DEEP := ["Rooted", "Rimed", "Shattered", "Hushed"]
const RARE_SECOND := {"weapon": ["Edge", "Fang", "Bite"], "candle": ["Taper", "Wick", "Vigil"], "coat": ["Shroud", "Hauberk"],
		"boots": ["Treads", "Stompers"], "charm": ["Token", "Knot"]}
const TIER_MULT := [1.0, 1.12, 1.25, 1.36, 1.46]
const COAT_DR_MAX := 12.0   # the coat's own damage reduction, per item

# Legendaries: a fixed power plus 2 random affixes. "cls" binds a class
# charm. "fx" is the machine-readable power: hero.stats() copies it into
# stats.flags (and sets stats.legends[id] = true) for the world and kits to
# act on. "stats" are powers hero.gd applies itself.
const LEGENDS := {
	"dawnsliver": {"name": "Dawnsliver", "slot": "weapon",
		"text": "Every 3rd basic also looses a piercing crescent of light.",
		"fx": {"dawnsliver_every": 3, "dawnsliver_coef": 0.6, "dawnsliver_range": 190.0}},
	"tollbreaker": {"name": "Tollbreaker", "slot": "weapon",
		"text": "+100% damage to stuck or staggered bosses; their openings last longer.",
		"fx": {"tollbreaker_pct": 1.0, "tollbreaker_window": 0.4}},
	"gutterlight": {"name": "Gutterlight", "slot": "candle",
		"text": "Below 35% life: +40% damage and 20% faster attacks.",
		"fx": {"gutterlight_below": 0.35, "gutterlight_dmg": 0.40, "gutterlight_speed": 0.20}},
	"twin_wick": {"name": "The Twin Wick", "slot": "candle",
		"text": "A second flame takes one hit for you. It relights at altars.",
		"fx": {}},   # one ward per altar (world.gd _twin_ready)
	"ossuary_coat": {"name": "Ossuary Coat", "slot": "coat",
		"text": "Each kill adds a bone ward (up to 3). A ward halves one hit.",
		"fx": {"ossuary_max": 3, "ossuary_cut": 0.5}},
	"thornsole": {"name": "Thornsole Greaves", "slot": "boots",
		"text": "Stomp spikes and shields safely. Stomps deal double.",
		# The world doubles the stomp itself (so stats.stomp leaves it out):
		# thornsole_stomp is that multiplier, in one place only.
		"fx": {"thornsole_stomp": 2.0}},
	"cinderstep": {"name": "Cinderstep", "slot": "boots",
		"text": "Lava and deep water cost half. You leave a trail of fire.",
		"fx": {"cinderstep_hazard": 0.5, "cinderstep_trail_pct": 0.30}},
	"first_dawn": {"name": "Glass of the First Dawn", "slot": "charm", "cls": "knight",
		"text": "Your Perfect Guard window is much wider.",
		"fx": {"first_dawn_guard": 0.30}},
	"cracked_tenor": {"name": "Cracked Tenor", "slot": "charm", "cls": "founder",
		"text": "Peal waves split in two at the end of their run.",
		"fx": {"cracked_tenor_split": 2}},
	"everburning": {"name": "Everburning Taper", "slot": "charm", "cls": "witch",
		"text": "Your beacons burn foes inside them.",
		"fx": {"everburning_coef": 0.10, "everburning_tick": 0.5}},
	"moth_queen": {"name": "Moth-Queen's Scale", "slot": "charm", "cls": "runner",
		"text": "A fourth Smoke pip.",
		"fx": {"moth_queen_pips": 4}, "stats": {"res_max_add": 1.0}},
	"unrung_bell": {"name": "The Unrung Bell", "slot": "charm", "cls": "sexton",
		"text": "Toll the Dead keeps your wisps (8 s cooldown).",
		"fx": {"unrung_bell_cd": 8.0}},
	# ---- v3 (spec §8.4). "min_area": drops only at area >= it; "secret": never
	# rolls until found once. The world's pairs, a boss's first-kill prize:
	"rootbound": {"name": "Rootbound Treads", "slot": "boots", "min_area": 13, "world": 3,
		"text": "Stomps burst into roots: foes within 90 px are rooted 1.2 s.",
		"fx": {"rootbound_r": 90.0, "rootbound_s": 1.2}},
	"marrow_lantern": {"name": "Marrow Lantern", "slot": "candle", "min_area": 13, "world": 3,
		"text": "Dimming is halved, and kills heal 1% life.",
		"fx": {}, "stats": {"dim_resist": 0.5, "on_kill_heal": 0.01}},
	"escapement": {"name": "The Escapement", "slot": "weapon", "min_area": 18, "world": 4,
		"text": "Every 4th basic ticks twice: a second strike for 60%.",
		"fx": {"escapement_every": 4, "escapement_coef": 0.6}},
	"hoarfrost": {"name": "Hoarfrost Mantle", "slot": "coat", "min_area": 18, "world": 4,
		"text": "A foe that hurts you is frozen 1.5 s (bosses 0.3 s), once every 4 s.",
		"fx": {"hoarfrost_stun": 1.5, "hoarfrost_boss": 0.3, "hoarfrost_cd": 4.0}},
	"prismglass": {"name": "Prismglass", "slot": "charm", "min_area": 23, "world": 5,
		"text": "Crits throw a shard of light at the nearest other foe for 50%.",
		"fx": {"prism_coef": 0.5, "prism_range": 200.0}},
	"leadlight": {"name": "Leadlight Hauberk", "slot": "coat", "min_area": 23, "world": 5,
		"text": "Shots, shards and falling glass hit you for 40% less.",
		"fx": {}, "stats": {"shot_dr": 0.40}},
	"hushbane": {"name": "Hushbane", "slot": "weapon", "min_area": 28, "world": 6,
		"text": "Every 5th hit on the same foe deals +150% and stuns it 0.5 s.",
		"fx": {"hushbane_every": 5, "hushbane_bonus": 1.5, "hushbane_stun": 0.5}},
	"last_candle": {"name": "The Last Candle", "slot": "candle", "min_area": 28, "world": 6,
		"text": "Below 30% life: foes in your light stunned 1 s, you untouchable 1.5 s. Once per altar.",
		"fx": {"lastcandle_below": 0.30, "lastcandle_stun": 1.0, "lastcandle_invuln": 1.5}},
	# The secret prizes (a secret level's first clear per difficulty, at area
	# + 2); once found, they join the random pool from their world down.
	"hymnal": {"name": "Tessel's Hymnal", "slot": "charm", "secret": true, "min_area": 1, "world": 1,
		"text": "+15% XP and +25% embers.",
		"fx": {}, "stats": {"xp_pct": 0.15, "ember_pct": 0.25}},
	"deep_chalice": {"name": "The Deep Chalice", "slot": "candle", "secret": true, "min_area": 8, "world": 2,
		"text": "Your flask heals 25% more, and drinking makes you untouchable for 0.6 s.",
		"fx": {"chalice_invuln": 0.6}, "stats": {"flask_pct": 0.25}},
	"gravebloom": {"name": "Gravebloom Treads", "slot": "boots", "secret": true, "min_area": 13, "world": 3,
		"text": "Stomps always crit; a stomp kill restores 15% of your resource.",
		"fx": {"gravebloom_crit": 1.0, "gravebloom_res": 0.15}},
	"hour_hand": {"name": "The Hour-Hand", "slot": "weapon", "secret": true, "min_area": 18, "world": 4,
		"text": "Each hit on the same foe adds +8% damage for 3 s, up to +40%.",
		"fx": {"hourhand_step": 0.08, "hourhand_max": 0.40, "hourhand_t": 3.0}},
	"saints_lens": {"name": "The Saint's Lens", "slot": "candle", "secret": true, "min_area": 23, "world": 5,
		"text": "Your light burns 15% wider, and foes inside it take 15% more from you.",
		"fx": {"lens_bonus": 0.15}, "stats": {"light_relic": 0.15}},
	"hollins_ember": {"name": "Hollin's Ember", "slot": "charm", "secret": true, "min_area": 28, "world": 6,
		"text": "Once per altar, a snuffing blow leaves you at 1 life, burning white, untouchable 2 s.",
		"fx": {"hollin_invuln": 2.0}},
}
# The bosses' pairs and the secret prizes. Tollgrave and the Snuffer give
# their signature piece (build 1: one each, Tollbreaker for the bell's boss,
# the Twin Wick for the flame's thief).
const WORLD_LEGENDS := {1: ["tollbreaker"], 2: ["twin_wick"], 3: ["rootbound", "marrow_lantern"], 4: ["escapement", "hoarfrost"],
		5: ["prismglass", "leadlight"], 6: ["hushbane", "last_candle"]}
# A boss's boon (his first kill, chosen on the choice card: boon_legends):
# his signature then others, this many at most.
const BOON_MAX := 3
const SECRET_PRIZES := {"1-S": "hymnal", "2-S": "deep_chalice", "3-S": "gravebloom", "4-S": "hour_hand",
		"5-S": "saints_lens", "6-S": "hollins_ember"}
# What a Dusk kill rolls (spec §8.1), richer from area 13 and 23. Build 1:
# no Commons on Dusk (they only melted on touch), the rest in v2's proportion
# (80 / 19 / 1, 76 / 22 / 2, 70 / 27 / 3), and half as many drops
# (Combat.DIFF.dusk.drop 0.5). With the Trophies a story level's kill drops
# nothing (DIFF.dusk.drop 0): Dusk's row is what a "kill" drop that does
# come there rolls. Nightfall and Witching (and every other source:
# Anointed, Dread, boss, Lidlurk, gold, trophy) keep their tables in world.gd.
const KILL_WEIGHTS := {
	"dusk": {"common": 0.0, "magic": 80.0, "rare": 19.0, "legendary": 1.0},
	"nightfall": {"common": 45.0, "magic": 40.0, "rare": 13.0, "legendary": 2.0},
	"witching": {"common": 30.0, "magic": 45.0, "rare": 21.0, "legendary": 4.0},
}
const DUSK_DEEP_WEIGHTS := [[13, {"common": 0.0, "magic": 76.0, "rare": 22.0, "legendary": 2.0}],
		[23, {"common": 0.0, "magic": 70.0, "rare": 27.0, "legendary": 3.0}]]
# A challenge mode's Dusk kill keeps v3's weights (Build 1's Dusk loot was
# for the story levels; Combat.MODE_DUSK_DROP keeps its drop rate): v2's to
# area 12, richer from 13 and 23, Commons and all.
const MODE_DUSK_KILL := {"common": 60.0, "magic": 32.0, "rare": 7.5, "legendary": 0.5}
const MODE_DUSK_DEEP := [[13, {"common": 55.0, "magic": 34.0, "rare": 10.0, "legendary": 1.0}],
		[23, {"common": 50.0, "magic": 35.0, "rare": 13.5, "legendary": 1.5}]]


static func tier_of(ilvl: int) -> int:
	## 40+ is T5, 30+ T4, 20+ T3, 10+ T2 (at most max_tier).
	var t := 1
	if ilvl >= 40:
		t = 5
	elif ilvl >= 30:
		t = 4
	elif ilvl >= 20:
		t = 3
	elif ilvl >= 10:
		t = 2
	return mini(t, clampi(max_tier, 1, TIERS))


static func live_slots(area: int) -> Array:
	## The slots that drop and are sold at this area. All five (v2's) unless
	## slots_by_area: then boots from BOOTS_FROM, charms from CHARM_FROM
	## (every slot from area 30, Nightfall's and Witching's).
	if not slots_by_area or area >= 30:
		return LIVE_SLOTS.duplicate()
	var s := ["weapon", "candle", "coat"]
	if area >= BOOTS_FROM:
		s.append("boots")
	if area >= CHARM_FROM:
		s.append("charm")
	return s


static func base_name(slot: String, cls: String, tier: int) -> String:
	var b = BASES.get(slot, BASES["charm"])
	var names: Array = b.get(cls, b["knight"]) if b is Dictionary else b
	return names[clampi(tier - 1, 0, names.size() - 1)]


static func implicit(slot: String, ilvl: int, tier: int) -> Dictionary:
	## The base's own stat, growing with item level (charms have none).
	var m: float = TIER_MULT[clampi(tier, 1, TIERS) - 1]
	match slot:
		"weapon":
			return {"id": "dmg_pct", "v": roundf((10.0 + 1.5 * ilvl) * m)}
		"candle":
			return {"id": "max_hp_pct", "v": roundf((5.0 + 0.5 * ilvl) * m), "light": roundf((4.0 + 0.2 * ilvl) * m)}
		"coat":
			return {"id": "dr", "v": minf(roundf((3.0 + 0.4 * ilvl) * m), COAT_DR_MAX)}
		"boots":
			return {"id": "stomp_pct", "v": roundf((25.0 + 3.0 * ilvl) * m), "dr": roundf((1.0 + 0.1 * ilvl) * m)}
	return {}


static func affix_pool(slot: String, tier: int, rarity: String) -> Array:
	## The affixes this slot, tier and rarity can roll.
	var pool := []
	for id in AFFIXES:
		var a: Dictionary = AFFIXES[id]
		if not a["slots"].has(slot):
			continue
		if tier < int(a.get("min_tier", 1)):
			continue
		if a.has("min_rarity") and RARITIES.find(rarity) < RARITIES.find(a["min_rarity"]):
			continue
		if str(a.get("live", "")) == "lantern" and not lantern_live:
			continue
		pool.append(id)
	return pool


static func roll_value(id: String, tier: int, rng: RandomNumberGenerator) -> float:
	## A uniform roll inside the tier's range; narrow ranges keep a decimal.
	var rg: Array = AFFIXES[id]["t"][clampi(tier, 1, TIERS) - 1]
	var lo := float(rg[0])
	var hi := float(rg[1])
	var v := rng.randf_range(lo, hi)
	v = roundf(v * 10.0) / 10.0 if hi - lo < 3.0 else roundf(v)
	return clampf(v, lo, hi)


static func make(slot: String, cls: String, ilvl: int, rarity: String, rng: RandomNumberGenerator, legend := "") -> Dictionary:
	## A new item. rng decides the affixes; pass a seeded one for tests.
	ilvl = clampi(ilvl, 1, ILVL_CAP)
	if not RARITIES.has(rarity):
		rarity = "common"
	if rarity == "legendary" and not LEGENDS.has(legend):
		legend = pick_legend(slot, cls, rng, ilvl)   # one legal at this item level (min_area)
		if legend == "":
			rarity = "rare"
	if rarity != "legendary":
		legend = ""
	var tier := tier_of(ilvl)
	var bound: bool = slot == "weapon" or LEGENDS.get(legend, {}).has("cls")
	var owner: String = LEGENDS[legend].get("cls", cls) if legend != "" else cls
	var it := {"uid": "i%08x" % (rng.randi() & 0x7fffffff), "slot": slot, "base": base_name(slot, owner, tier),
			"cls": owner if bound else "", "ilvl": ilvl, "tier": tier, "rarity": rarity, "name": "",
			"implicit": implicit(slot, ilvl, tier), "affixes": [], "legend": legend}
	var counts: Array = AFFIX_COUNT[rarity]
	var n := rng.randi_range(counts[0], counts[1])
	if slot == "charm":
		n += 1
	var pool := affix_pool(slot, tier, rarity)
	var kinds := {"prefix": 0, "suffix": 0}
	for i in n:
		var choices := pool.filter(func(id): return kinds[AFFIXES[id]["kind"]] < 2)
		if choices.is_empty():
			break
		var id: String = choices[rng.randi() % choices.size()]
		pool.erase(id)
		kinds[AFFIXES[id]["kind"]] += 1
		it["affixes"].append({"id": id, "t": tier, "v": roll_value(id, tier, rng)})
	it["name"] = name_for(it, rng)
	return it


static func name_for(it: Dictionary, rng: RandomNumberGenerator) -> String:
	match it["rarity"]:
		"legendary":
			return LEGENDS.get(it["legend"], {}).get("name", it["base"])
		"rare":
			var seconds: Array = RARE_SECOND.get(it["slot"], ["Token"])
			var firsts: Array = RARE_FIRST + RARE_FIRST_DEEP if int(it.get("tier", 1)) >= 4 else RARE_FIRST
			return "%s %s" % [firsts[rng.randi() % firsts.size()], seconds[rng.randi() % seconds.size()]]
		"magic":
			var pre := ""
			var suf := ""
			for a in it["affixes"]:
				var d: Dictionary = AFFIXES.get(a["id"], {})
				if d.is_empty():
					continue
				if d["kind"] == "prefix" and pre == "":
					pre = d["word"] + " "
				elif d["kind"] == "suffix" and suf == "":
					suf = " " + d["word"]
			return pre + it["base"] + suf
	return it["base"]


static func median(id: String, tier: int) -> float:
	var rg: Array = AFFIXES[id]["t"][clampi(tier, 1, TIERS) - 1]
	var v := (float(rg[0]) + float(rg[1])) * 0.5
	return roundf(v * 10.0) / 10.0


static func starter(cls: String, ilvl := 1, rarity := "common", rng: RandomNumberGenerator = null) -> Dictionary:
	## The kit a hero walks down with: weapon, candle, coat. A Blessed kit
	## (a later calling's) carries each piece's signature affix at a median
	## roll: a Keen weapon, a Waxen candle, a Warded coat.
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.seed = hash(cls + str(ilvl))
	var out := {"weapon": null, "candle": null, "coat": null, "boots": null, "charm": null}
	for slot in ["weapon", "candle", "coat"]:
		var it := make(slot, cls, ilvl, "common", r)
		if rarity != "common":
			it["rarity"] = "magic"
			it["affixes"] = [{"id": SIGNATURE[slot], "t": int(it["tier"]), "v": median(SIGNATURE[slot], int(it["tier"]))}]
			it["name"] = name_for(it, r)
		out[slot] = it
	return out


static func mods(it) -> Dictionary:
	## The stat changes an item gives, as fractions (0.12 = +12%), plus
	## "legend_<id>": 1 for a Legendary's power.
	var out := {}
	if not (it is Dictionary) or it.is_empty():
		return out
	var imp: Dictionary = it.get("implicit", {})
	if imp.has("id"):
		_add(out, imp["id"], float(imp["v"]))
	if imp.has("light"):
		_add(out, "light_pct", float(imp["light"]))
	if imp.has("dr") and imp.get("id", "") != "dr":
		_add(out, "dr", float(imp["dr"]))
	for a in it.get("affixes", []):
		var d: Dictionary = AFFIXES.get(a["id"], {})
		if not d.is_empty():
			_add(out, d["stat"], float(a["v"]))
	if str(it.get("legend", "")) != "":
		out["legend_" + str(it["legend"])] = 1.0
	return out


static func _add(out: Dictionary, stat: String, v: float) -> void:
	# root_rank is a count, the rest are percents.
	var val := v if stat == "root_rank" else v / 100.0
	out[stat] = float(out.get(stat, 0.0)) + val


static func power(it) -> int:
	## One number to sort by (not to judge by: the pickup chips do that).
	##   3 * ilvl * tier_mult + sum(10 * v / T3max) + 25 for a Legendary
	if not (it is Dictionary) or it.is_empty():
		return 0
	var p := 3.0 * float(it["ilvl"]) * float(TIER_MULT[clampi(int(it["tier"]), 1, TIERS) - 1])
	for a in it.get("affixes", []):
		var d: Dictionary = AFFIXES.get(a["id"], {})
		if d.is_empty():
			continue
		var top: float = float(d["t"][2][1])
		p += 10.0 * float(a["v"]) / maxf(top, 0.01)
	if str(it.get("legend", "")) != "":
		p += 25.0
	return roundi(p)


static func sell_value(it) -> int:
	## What Waxley pays for it: a quarter of his own price (price), so a Rare
	## at ilvl 20 sells for 123 (Blessed 48, Legendary 275). The Sell tab, a
	## find sold on touch and a melt for room all pay this.
	if not (it is Dictionary) or it.is_empty():
		return 0
	return roundi(float(price(it)) / 4.0)


static func salvage_value(it) -> int:
	## The old name for sell_value: an item melted for room (a full satchel,
	## an upgrade worn into one) pays what a sale would.
	return sell_value(it)


static func price(it) -> int:
	## What the Chandler asks: Blessed 30 + 8*ilvl, Rare 90 + 20*ilvl.
	if not (it is Dictionary) or it.is_empty():
		return 0
	var l := float(it["ilvl"])
	match it["rarity"]:
		"magic":
			return roundi(30.0 + 8.0 * l)
		"rare":
			return roundi(90.0 + 20.0 * l)
		"legendary":
			return roundi(300.0 + 40.0 * l)
	return roundi(10.0 + 4.0 * l)


static func icon(it: Dictionary) -> String:
	## Its picture: art/items/weapon_<cls>_<tier>.svg or <slot>_<tier>.svg,
	## at the highest tier drawn so far (a T4 or T5 without its icon yet shows
	## the T3 one).
	var t := clampi(int(it.get("tier", 1)), 1, TIERS)
	var path := ""
	while t >= 1:
		path = _icon_path(it, t)
		if t <= 3 or ResourceLoader.exists(path):
			return path
		t -= 1
	return path


static func _icon_path(it: Dictionary, t: int) -> String:
	if it.get("slot", "") == "weapon":
		return "res://art/items/weapon_%s_%d.svg" % [str(it.get("cls", "knight")) if str(it.get("cls", "")) != "" else "knight", t]
	return "res://art/items/%s_%d.svg" % [str(it.get("slot", "charm")), t]


static func key_line(it: Dictionary) -> String:
	## The one line a card shows: a Legendary's power, else the strongest
	## affix (highest v / T3max), else the implicit.
	if str(it.get("legend", "")) != "":
		return LEGENDS.get(it["legend"], {}).get("text", "")
	var best := ""
	var best_score := -1.0
	for a in it.get("affixes", []):
		var d: Dictionary = AFFIXES.get(a["id"], {})
		if d.is_empty():
			continue
		var score: float = float(a["v"]) / maxf(float(d["t"][2][1]), 0.01)
		if score > best_score:
			best_score = score
			best = describe(a["id"], float(a["v"]))
	if best != "":
		return best
	var imp: Dictionary = it.get("implicit", {})
	return describe(str(imp.get("id", "")), float(imp.get("v", 0.0)))


static func lines(it: Dictionary) -> Array:
	## Every line of an item, for a detail view: [{text, kind}], kind is
	## "implicit", "affix" or "legend".
	var out := []
	var imp: Dictionary = it.get("implicit", {})
	if imp.has("id"):
		out.append({"text": describe(str(imp["id"]), float(imp["v"])), "kind": "implicit"})
	if imp.has("light"):
		out.append({"text": describe("light_pct", float(imp["light"])), "kind": "implicit"})
	if imp.has("dr") and imp.get("id", "") != "dr":
		out.append({"text": describe("dr", float(imp["dr"])), "kind": "implicit"})
	if str(it.get("legend", "")) != "":
		out.append({"text": LEGENDS.get(it["legend"], {}).get("text", ""), "kind": "legend"})
	for a in it.get("affixes", []):
		if AFFIXES.has(a["id"]):
			out.append({"text": describe(a["id"], float(a["v"])), "kind": "affix"})
	return out


static func describe(stat_or_affix: String, v: float) -> String:
	var stat: String = AFFIXES[stat_or_affix]["stat"] if AFFIXES.has(stat_or_affix) else stat_or_affix
	var n := ("%.1f" % v).trim_suffix(".0")
	match stat:
		"dmg_pct":
			return "+%s%% damage" % n
		"max_hp_pct":
			return "+%s%% life" % n
		"dr":
			return "+%s%% damage reduction" % n
		"light_pct":
			return "+%s%% light" % n
		"elite_pct":
			return "+%s%% vs elites and bosses" % n
		"crit":
			return "+%s%% crit chance" % n
		"crit_mult_add":
			return "+%s%% crit damage" % n
		"attack_speed_pct":
			return "+%s%% attack speed" % n
		"on_kill_heal":
			return "Kills heal %s%% life" % n
		"special_pct":
			return "+%s%% Special damage" % n
		"root_rank":
			return "+1 rank to your Special"
		"stomp_pct":
			return "+%s%% stomp damage" % n
		"dim_resist":
			return "Dimming is %s%% weaker" % n
	return stat


static func kill_weights(area: int, diff_id: String, story := true) -> Dictionary:
	## The rarity weights of an ordinary kill's drop at this area (spec §8.1):
	## Dusk rolls no Commons and gets richer with depth (80 / 19 / 1 Blessed /
	## Rare / Legendary to area 12, 76 / 22 / 2 from 13, 70 / 27 / 3 from 23);
	## a mode's Dusk (story false) keeps v3's (MODE_DUSK_KILL, MODE_DUSK_DEEP);
	## Nightfall and Witching are v2's.
	var w: Dictionary = KILL_WEIGHTS.get(diff_id, KILL_WEIGHTS["dusk"])
	if diff_id == "dusk" or not KILL_WEIGHTS.has(diff_id):
		if not story:
			w = MODE_DUSK_KILL
		for row in (DUSK_DEEP_WEIGHTS if story else MODE_DUSK_DEEP):
			if area >= int(row[0]):
				w = row[1]
	return w.duplicate()


static func legend_world(id: String) -> int:
	## The world a Legendary belongs to (v2's are 1; 0 for an unknown id).
	if not LEGENDS.has(id):
		return 0
	return int((LEGENDS[id] as Dictionary).get("world", 1))


static func pick_rarity(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for r in RARITIES:
		total += float(weights.get(r, 0.0))
	var x := rng.randf() * total
	for r in RARITIES:
		var w := float(weights.get(r, 0.0))
		if w <= 0.0:
			continue
		x -= w
		if x <= 0.0:
			return r
	for i in range(RARITIES.size() - 1, -1, -1):
		if float(weights.get(RARITIES[i], 0.0)) > 0.0:
			return RARITIES[i]
	return "common"


static func pick_slot(rng: RandomNumberGenerator, slots: Array = LIVE_SLOTS) -> String:
	## Weapons are 35% of drops; the rest share evenly.
	if slots.has("weapon") and rng.randf() < 0.35:
		return "weapon"
	var others: Array = slots.filter(func(s): return s != "weapon")
	return others[rng.randi() % others.size()] if not others.is_empty() else "weapon"


static func pick_legend(slot: String, cls: String, rng: RandomNumberGenerator, area := 99, found: Array = [], owned: Array = [], max_world := 0) -> String:
	## A Legendary power for this slot; class charms only for the calling.
	## v3: only those whose min_area this area has reached, a secret one only
	## once found (Game.legends_found), none of a world past max_world (0: any;
	## Game passes the worlds reached, so a W1-W2 build picks v2's), and one
	## the hero doesn't own three times as likely. With owned empty the pick
	## is v2's (one randi).
	var pool := []
	for id in LEGENDS:
		var l: Dictionary = LEGENDS[id]
		if l["slot"] != slot or (l.has("cls") and l["cls"] != cls):
			continue
		if area < int(l.get("min_area", 1)):
			continue
		if bool(l.get("secret", false)) and not found.has(id):
			continue
		if max_world > 0 and int(l.get("world", 1)) > max_world:
			continue
		pool.append(id)
	if pool.is_empty():
		return ""
	if owned.is_empty():
		return pool[rng.randi() % pool.size()]
	var total := 0.0
	for id in pool:
		total += 1.0 if owned.has(id) else 3.0
	var x := rng.randf() * total
	for id in pool:
		x -= 1.0 if owned.has(id) else 3.0
		if x <= 0.0:
			return id
	return pool[pool.size() - 1]


static func legal_legends(cls: String, area: int, found: Array = [], slots: Array = LIVE_SLOTS, max_world := 0) -> Array:
	## Every Legendary that may roll here: in one of these slots, the calling's
	## charms only, min_area reached, a secret one only once found, none of a
	## world past max_world (0: any) (Waxley's Reserve picks from these).
	var out := []
	for id in LEGENDS:
		var l: Dictionary = LEGENDS[id]
		if not slots.has(l["slot"]) or (l.has("cls") and l["cls"] != cls):
			continue
		if area < int(l.get("min_area", 1)) or (bool(l.get("secret", false)) and not found.has(id)):
			continue
		if max_world > 0 and int(l.get("world", 1)) > max_world:
			continue
		out.append(id)
	return out


static func world_legends(world: int) -> Array:
	## A world's boss pair (its boss's first kill per difficulty drops one;
	## Worlds 1-2 have one signature piece), those in LEGENDS so far.
	var out: Array = []
	for id in WORLD_LEGENDS.get(world, []):
		if LEGENDS.has(id):
			out.append(id)
	return out


static func boon_legends(world: int, cls: String, area: int, owned: Array, found: Array, rng: RandomNumberGenerator, n := BOON_MAX) -> Array:
	## A boss's boon (his first kill on a difficulty, a player at the
	## controls: world.gd open_boon): the Legendaries offered on the choice
	## card, n at most. His signature first (world_legends: W1-W2's one,
	## W3-W6's pair; a calling's charm only its own), then others the hero
	## doesn't hold (owned: worn or carried) that may roll here
	## (legal_legends: the live slots, min_area reached, a secret one once
	## found), never another boss's signature, drawn at random. Fewer than
	## two is no choice: the boss drops his prize as before.
	var out: Array = []
	for id in world_legends(world):
		if not (LEGENDS[id] as Dictionary).has("cls") or LEGENDS[id]["cls"] == cls:
			out.append(id)
	var signed := {}
	for w in WORLD_LEGENDS:
		for id in WORLD_LEGENDS[w]:
			signed[id] = true
	var rest: Array = legal_legends(cls, area, found, live_slots(area)).filter(func(id): return not signed.has(id) and not owned.has(id))
	while out.size() < n and not rest.is_empty():
		var k := rng.randi() % rest.size()
		out.append(rest[k])
		rest.remove_at(k)
	return out.slice(0, n)
