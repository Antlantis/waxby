extends RefCounted
## Every kind of monster the World can place: its script, where it stands
## relative to its cell (floor = feet on the cell's floor; center; ceiling =
## hanging from the cell's top), and whether it's ordinary fodder (fodder
## respawns on Nightfall+, and a stomp always kills it). A kind whose script
## isn't there yet is skipped with a warning, so a level can land before its
## monster (v3: every kind of contract.md §6.3 is listed; MA and MB add the
## scripts, BA and BB the bosses; MA owns this file after Phase 0).
## spawn: floor | center | ceiling | deep_water | vine.
##
## World 3 to 6's kinds (MA, MB) and the four v3 bosses (BA, BB) are in
## KINDS. PLANNED is empty now (has(), make() and spawn_pos() still read it,
## so a kind can be listed there before its script lands).

const KINDS := {
	"skeleton": {"script": "res://scripts/skeleton.gd", "spawn": "floor", "ordinary": true},
	"bat": {"script": "res://scripts/bat.gd", "spawn": "center", "ordinary": true},
	"thornback": {"script": "res://scripts/thornback.gd", "spawn": "floor", "ordinary": false},
	"bonebow": {"script": "res://scripts/bonebow.gd", "spawn": "floor", "ordinary": true},
	"hollow_helm": {"script": "res://scripts/hollow_helm.gd", "spawn": "floor", "ordinary": false},
	"gutterwing": {"script": "res://scripts/gutterwing.gd", "spawn": "center", "ordinary": true},
	"dripkin": {"script": "res://scripts/dripkin.gd", "spawn": "ceiling", "ordinary": true},
	"brinejaw": {"script": "res://scripts/brinejaw.gd", "spawn": "center", "ordinary": true},
	"lidlurk": {"script": "res://scripts/lidlurk.gd", "spawn": "floor", "ordinary": false},
	"tollgrave": {"script": "res://scripts/boss.gd", "spawn": "floor", "ordinary": false},
	"snuffer": {"script": "res://scripts/snuffer_boss.gd", "spawn": "floor", "ordinary": false},
	# World 3 and 4 (MA)
	"rootling": {"script": "res://scripts/rootling.gd", "spawn": "floor", "ordinary": true},
	"weepcap": {"script": "res://scripts/weepcap.gd", "spawn": "floor", "ordinary": false},
	"rattlehound": {"script": "res://scripts/rattlehound.gd", "spawn": "floor", "ordinary": false},
	"creepbone": {"script": "res://scripts/creepbone.gd", "spawn": "vine", "ordinary": true},
	"tickwind": {"script": "res://scripts/tickwind.gd", "spawn": "floor", "ordinary": true},
	"spurwheel": {"script": "res://scripts/spurwheel.gd", "spawn": "floor", "ordinary": false},
	"frostbuckle": {"script": "res://scripts/frostbuckle.gd", "spawn": "floor", "ordinary": false},
	"hoarowl": {"script": "res://scripts/hoarowl.gd", "spawn": "floor", "ordinary": false},
	# World 5 and 6 (MB; moved from PLANNED at the wave-1 merge)
	"glassmite": {"script": "res://scripts/glassmite.gd", "spawn": "floor", "ordinary": true},
	"gustling": {"script": "res://scripts/gustling.gd", "spawn": "center", "ordinary": true},
	"refractor": {"script": "res://scripts/refractor.gd", "spawn": "center", "ordinary": false},
	"paneguard": {"script": "res://scripts/paneguard.gd", "spawn": "floor", "ordinary": false},
	"hushling": {"script": "res://scripts/hushling.gd", "spawn": "floor", "ordinary": true},
	"stillmaw": {"script": "res://scripts/stillmaw.gd", "spawn": "center", "ordinary": false},
	"unwick": {"script": "res://scripts/unwick.gd", "spawn": "floor", "ordinary": false},
	"lurecoil": {"script": "res://scripts/lurecoil.gd", "spawn": "deep_water", "ordinary": false},
	# The World 3 and 4 bosses (BA; moved from PLANNED at the wave-2 merge)
	"rootmother": {"script": "res://scripts/rootmother_boss.gd", "spawn": "floor", "ordinary": false},
	"tinker": {"script": "res://scripts/tinker_boss.gd", "spawn": "floor", "ordinary": false},
	# The World 5 and 6 bosses (BB; moved from PLANNED at the track B merge)
	"saint": {"script": "res://scripts/saint_boss.gd", "spawn": "floor", "ordinary": false},
	"hush": {"script": "res://scripts/hush_boss.gd", "spawn": "floor", "ordinary": false},
}
# v3's kinds (contract.md §6.3), listed apart until their scripts land: has(),
# info(), make() and spawn_pos() read both tables, so a level can place one
# before its monster exists (it's skipped with a warning). Each line moves
# into KINDS as its script lands (tests/test_story's level-art check reads
# KINDS, whose scripts must all exist). Every kind has landed: none is left.
const PLANNED := {}
# The threat cost of each kind (spec §4.2, p_monsters §4.1; a Rattle is 1):
# the levels' density tests and the Descent's room budget read it, with a
# tier's multiple (TIER_COST: Anointed x2.5, Dread x5, Warden x8).
const COST := {"skeleton": 1.0, "bat": 1.0, "bonebow": 1.5, "dripkin": 1.0, "gutterwing": 1.0, "brinejaw": 1.0,
		"thornback": 2.5, "hollow_helm": 3.0, "lidlurk": 3.0,
		"rootling": 1.0, "weepcap": 2.0, "rattlehound": 3.0, "creepbone": 1.5,
		"tickwind": 1.5, "spurwheel": 2.5, "frostbuckle": 4.0, "hoarowl": 2.0,
		"glassmite": 1.0, "gustling": 1.5, "refractor": 2.0, "paneguard": 4.0,
		"hushling": 0.75, "stillmaw": 3.0, "unwick": 3.5, "lurecoil": 6.0}
const TIER_COST := {"": 1.0, "anointed": 2.5, "dread": 5.0, "warden": 8.0}
# Each kind's role (spec §4.2): fodder, heavy, brute (Frostbuckle and
# Lurecoil: W4 on, at most 3 a level) or sentinel. The Dusk share caps
# (Combat.SHARE_CAPS) are "fodder" for fodder and "heavy" for the rest.
const ROLE := {"skeleton": "fodder", "bat": "fodder", "bonebow": "fodder", "dripkin": "fodder", "gutterwing": "fodder",
		"brinejaw": "fodder", "thornback": "heavy", "hollow_helm": "heavy", "lidlurk": "heavy",
		"rootling": "fodder", "weepcap": "heavy", "rattlehound": "heavy", "creepbone": "fodder",
		"tickwind": "fodder", "spurwheel": "heavy", "frostbuckle": "brute", "hoarowl": "sentinel",
		"glassmite": "fodder", "gustling": "fodder", "refractor": "heavy", "paneguard": "heavy",
		"hushling": "fodder", "stillmaw": "heavy", "unwick": "heavy", "lurecoil": "brute"}
const TILE := 32
static var _warned := {}
static var _extra := {}           # kinds registered at run time (tests' stubs): kind -> {script, spawn, ordinary}


static func register(kind: String, script: String, spawn := "floor", ordinary := false) -> void:
	## A kind that isn't in KINDS (a test's stub boss).
	_extra[kind] = {"script": script, "spawn": spawn, "ordinary": ordinary}


static func info(kind: String) -> Dictionary:
	if KINDS.has(kind):
		return KINDS[kind]
	return PLANNED.get(kind, _extra.get(kind, {}))


static func known(kind: String) -> bool:
	## A kind the World may spawn (listed, whether its script exists yet or not).
	return KINDS.has(kind) or PLANNED.has(kind) or _extra.has(kind)


static func has(kind: String) -> bool:
	var i := info(kind)
	return not i.is_empty() and ResourceLoader.exists(i["script"])


static func make(kind: String) -> Node2D:
	if not has(kind):
		if not _warned.has(kind):
			_warned[kind] = true
			push_warning("enemy_kinds: no script for '%s' yet; skipped" % kind)
		return null
	var i := info(kind)
	var n: Node2D = load(i["script"]).new()
	n.ordinary = bool(i["ordinary"])
	return n


static func cost(kind: String, tier := "") -> float:
	## Its threat cost with its tier's multiple (a boss or an unknown kind: 0).
	return float(COST.get(kind, 0.0)) * float(TIER_COST.get(tier, 1.0))


static func share_cap_key(kind: String) -> String:
	## Which Combat.SHARE_CAPS row a kind's blows are held to on Dusk.
	return "fodder" if str(ROLE.get(kind, "heavy")) == "fodder" else "heavy"


static func spawn_pos(kind: String, cell: Vector2i) -> Vector2:
	match info(kind).get("spawn", "floor"):
		"center":
			return Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE)
		"ceiling":
			return Vector2((cell.x + 0.5) * TILE, cell.y * TILE)
		"deep_water":
			return Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE)
		"vine":
			return Vector2((cell.x + 0.5) * TILE, (cell.y + 1) * TILE)
	return Vector2((cell.x + 0.5) * TILE, (cell.y + 1) * TILE)
