extends RefCounted
## The Endless Descent's numbers and tables (spec §7.2, decisions.md), all
## the knobs in one place (p_modes §17): the biomes, the ramp, the room tiers,
## the elites, the deepening dark, the Glimmers, the Hushings, the Spare
## Wicks, the milestones. Static only; descent.gd and rooms.gd read it.

const Combat := preload("res://scripts/combat.gd")

# The biomes in world order. A biome is AVAILABLE once its room bundle
# (game/levels/rooms/<id>.txt) exists and its boss level is in the build;
# its echo depths need its Waxworks arena (levels/rush/<boss>.txt) too, else
# they play as plain depths. So the Descent runs with only W1-W2, and each
# later world's biome switches on as its files land.
const BIOMES := [
	{"id": "cathedral", "world": 1, "name": "The Sunken Cathedral", "themes": ["nave", "crypt", "choir", "tower"], "music": "chapel",
		"boss": "tollgrave", "boss_level": "1-4",
		"wardens": ["Deacon Knucklebone", "Canon Cobweb", "Quiverling", "The Pew Warden"],
		"warden_kinds": {"floor": ["skeleton", "thornback", "bonebow", "hollow_helm"]}},
	{"id": "tallow", "world": 2, "name": "The Tallow Deep", "themes": ["waxfall", "chandlery", "garden", "undercandle"], "music": "tallow",
		"boss": "snuffer", "boss_level": "2-4",
		"wardens": ["Old Slump", "Gulpwick", "Sister Sip", "The Wax Bailiff"],
		"warden_kinds": {"floor": ["skeleton", "bonebow", "hollow_helm"]}},
	{"id": "orchard", "world": 3, "name": "The Bone Orchard", "themes": ["orchard", "rootvault", "sporewood", "rootheart"], "music": "orchard",
		"boss": "rootmother", "boss_level": "3-4",
		"wardens": ["Old Rootgnaw", "Burrowmaw", "Thistledown the Sour", "The Pale Gardener"],
		"warden_kinds": {"floor": ["rootling", "rattlehound", "weepcap"]}},
	{"id": "carillon", "world": 4, "name": "The Frozen Carillon", "themes": ["clockface", "gearworks", "icebells", "escapement"], "music": "carillon",
		"boss": "tinker", "boss_level": "4-4",
		"wardens": ["Tock", "Grand Ratchet", "Sir Pendulum", "The Chime Warden"],
		"warden_kinds": {"floor": ["tickwind", "frostbuckle", "spurwheel"]}},
	{"id": "sanctum", "world": 5, "name": "The Shattered Sanctum", "themes": ["choirglass", "rosewind", "voidnave", "prismheart"], "music": "sanctum",
		"boss": "saint", "boss_level": "5-4",
		"wardens": ["Shardling Prime", "Pane the Unmended", "Mosaic", "The Glazier"],
		"warden_kinds": {"floor": ["glassmite", "paneguard"]}},
	{"id": "hushdeep", "world": 6, "name": "The Hushdeep", "themes": ["stillshore", "drownbell", "hushquiet", "husheye"], "music": "hushdeep",
		"boss": "hush", "boss_level": "6-4",
		"wardens": ["Stillwater", "The Mute Abbot", "Hollowed Hem", "Nobody"],
		"warden_kinds": {"floor": ["hushling", "unwick"]}},
]

# The ramp (decisions.md): area_level(A_END, diff) - 5 + min(d, 10) + floor(max(d - 10, 0) / 2), at most 60.
const AREA_START := -5
const AREA_CAP := 60
const STEEP_TO := 10              # +1 an area a depth to here, then +1 per 2
# Challenge rooms per depth: 3 at 1-5, 4 at 6-15, 5 from 16.
const ROOMS_BY_DEPTH := [[5, 3], [15, 4], [99999, 5]]
# A depth's length (spec: 170-265 tiles, 1.5-3 minutes): the counts above
# are the least; a depth shorter than DEPTH_MIN takes another challenge room,
# one longer than DEPTH_MAX swaps its widest for a narrower one.
const DEPTH_MIN := 170
const DEPTH_MAX := 265
# Room tier weights (T1, T2, T3) by depth, on the first pass; cycle >= 1 is its own row.
const TIER_WEIGHTS := [[5, [70, 30, 0]], [10, [35, 55, 10]], [15, [10, 60, 30]], [20, [0, 50, 50]], [99999, [0, 30, 70]]]
const TIER_WEIGHTS_DEEPENED := [0, 20, 80]
const DEEP_EARLY := 6             # deep overlays switch on this many depths sooner from cycle 1
const NO_REST_FROM := 21          # Nightfall and Witching plain depths from here have no rest room
# Elites over the World's own rules.
const ANOINT_PER_DEPTH := 0.006
const ANOINT_CAP := 0.30
const MAX_PER_8 := 1              # one more Anointed allowed each 8 depths
const MAX_ANOINT_CAP := 6
const OMEN_FROM := 21             # +1 Omen each from here
const OMEN_CAP := 3
const WARDEN_OMENS := 2           # 3 on Witching or from OMEN_FROM
# The deepening dark (through world.dim; its floor holds).
const DARK_FROM := 10
const DARK_PER_DEPTH := 0.004
const DARK_FLOOR := 0.85
# Spare Wicks at the start of a run.
const SPARE := {"dusk": 2, "nightfall": 1, "witching": 0}
const SPARE_MAX := 3
const ECHO_HP := 0.8              # an echo boss's life (after the rush normalisation)
const WALK_ON := 20               # "Walk on" pays this x DIFF.embers
const HUSH_FROM := 11             # a Hushing at 11, 16, 21, ...
const HUSH_EVERY := 5
const DRY_HEAL := 0.75            # Dry Well: the flask and altars heal this share

const GLIMMERS := {
	"g_wax": {"name": "Thick Wax", "text": "+8% max life", "max": 5, "glyph": "heart"},
	"g_edge": {"name": "Whetted", "text": "+8% damage", "max": 5, "glyph": "blade"},
	"g_eye": {"name": "Sharp Eye", "text": "+3% crit chance", "max": 3, "glyph": "star"},
	"g_bright": {"name": "Brighter Wick", "text": "+8% light", "max": 3, "glyph": "sun"},
	"g_ward": {"name": "Warded Coat", "text": "+3% damage cut", "max": 3, "glyph": "shield"},
	"g_heels": {"name": "Iron Heels", "text": "+30% stomp damage", "max": 2, "glyph": "boots"},
	"g_well": {"name": "Deep Well", "text": "+15% resource regen", "max": 3, "glyph": "drop"},
	"g_flask": {"name": "Deep Flask", "text": "+1 flask charge", "max": 1, "glyph": "candle"},
	"g_mend": {"name": "Mending Wick", "text": "Each depth cleared heals 10%", "max": 2, "glyph": "flame"},
	"g_luck": {"name": "Moth-luck", "text": "Rares x1.15, Legendaries x1.25", "max": 3, "glyph": "charm"},
	"g_embers": {"name": "Ember-sense", "text": "+25% embers", "max": 2, "glyph": "bell"},
	"g_spare": {"name": "Spare Wick", "text": "+1 Spare Wick", "max": 1, "glyph": "plus"},
}
const GLIMMER_ORDER := ["g_wax", "g_edge", "g_eye", "g_bright", "g_ward", "g_heels", "g_well", "g_flask", "g_mend",
		"g_luck", "g_embers", "g_spare"]

# The Hushings (run-long curses; the Hush speaks in lowercase).
const HUSHINGS := {
	"thin": {"name": "Thin Wax", "text": "Your max life -8%", "says": "your wax is thin now."},
	"hungry": {"name": "Hungry Dark", "text": "Your light x0.90", "says": "i am so much deeper."},
	"quick": {"name": "Quickened", "text": "Tells and cooldowns x0.93", "says": "they hear you coming."},
	"sharp": {"name": "Sharp Teeth", "text": "Monster damage +10%", "says": "everything down here bites."},
	"stout": {"name": "Stout Bones", "text": "Monster life +10%", "says": "the old dead are stubborn."},
	"swollen": {"name": "Swollen Deep", "text": "Every deep overlay is on", "says": "more of them. always more."},
	"anointed": {"name": "Anointed Deep", "text": "Anointed +6%, one more allowed", "says": "some of them remember names."},
	"dry": {"name": "Dry Well", "text": "The flask and altars heal 25% less", "says": "drink, little light. it won't help."},
}
const HUSH_ORDER := ["thin", "hungry", "quick", "sharp", "stout", "swollen", "anointed", "dry"]

# Milestones: the first time any calling in the slot clears the depth, per
# difficulty (the cosmetic once in all: Cosmetics.ids_for("descent:<d>")).
const MILESTONES := {5: {"embers": 150}, 10: {"legend": 1}, 15: {"embers": 300}, 20: {"legend": 1},
		25: {"embers": 500}, 30: {"legend": 1}, 40: {"legend": 1}, 50: {"legend": 2, "plaque": true}}
const BARK_DEPTHS := [5, 10, 20, 30, 40, 50]   # Hollin's descent_<d> barks


static func area_at(d: int, a_end: int) -> int:
	## The depth's area level: a_end is area_level(A_END, diff) (31 / 40 / 45).
	var a := a_end + AREA_START + mini(d, STEEP_TO) + maxi(d - STEEP_TO, 0) / 2
	return clampi(a, 1, AREA_CAP)


static func rooms_at(d: int) -> int:
	for row in ROOMS_BY_DEPTH:
		if d <= int(row[0]):
			return int(row[1])
	return 5


static func kind_at(d: int) -> String:
	## plain (d mod 5 = 1, 2, 4), warden (3), echo (0).
	match d % 5:
		3:
			return "warden"
		0:
			return "echo"
	return "plain"


static func tier_weights(d: int, cycle: int) -> Array:
	if cycle >= 1:
		return TIER_WEIGHTS_DEEPENED
	for row in TIER_WEIGHTS:
		if d <= int(row[0]):
			return row[1]
	return TIER_WEIGHTS[TIER_WEIGHTS.size() - 1][1]


static func has_rest(d: int, n_rooms: int, diff_id: String) -> bool:
	## A plain depth's rest after its 2nd challenge room (when it has 4 or
	## more); never on Nightfall and Witching plain depths from 21.
	if kind_at(d) != "plain":
		return true
	if n_rooms < 4:
		return false
	return diff_id == "dusk" or d < NO_REST_FROM


static func elite_rules(base: Dictionary, d: int, anoint_hush := 0) -> Dictionary:
	## The World's rules (Combat.elite_rules for the biome's world) ramped by depth.
	var anoint := minf(float(base.get("anoint", 0.06)) + ANOINT_PER_DEPTH * d + 0.06 * anoint_hush, ANOINT_CAP + 0.06 * anoint_hush)
	var most := mini(int(base.get("max_anoint", 2)) + MAX_PER_8 * (d / 8) + anoint_hush, MAX_ANOINT_CAP + anoint_hush)
	var omens := mini(int(base.get("omens", 1)) + (1 if d >= OMEN_FROM else 0), OMEN_CAP)
	return {"anoint": anoint, "max_anoint": most, "omens": omens}


static func dark_at(d: int) -> float:
	## The deepening dark's light multiplier (1.0 through depth 10, 0.85 at 48+).
	return maxf(DARK_FLOOR, 1.0 - DARK_PER_DEPTH * maxi(d - DARK_FROM, 0))


static func hush_due(d: int) -> bool:
	return d >= HUSH_FROM and (d - HUSH_FROM) % HUSH_EVERY == 0


static func loot_at(d: int, luck := 0, embers := 0) -> Dictionary:
	## mode.loot(): drop chance x (1 + 0.02 min(d, 30)), Legendary weight x (1 +
	## 0.03 min(d, 50)), embers likewise; Moth-luck x1.15 Rares and x1.25
	## Legendaries a stack; Ember-sense +25% embers a stack.
	var k := 1.0 + 0.03 * mini(d, 50)
	return {"drop": 1.0 + 0.02 * mini(d, 30), "legend": k * pow(1.25, luck), "rare": pow(1.15, luck),
			"embers": k * (1.0 + 0.25 * embers)}


static func biome(id: String) -> Dictionary:
	for b in BIOMES:
		if b["id"] == id:
			return b
	return {}
