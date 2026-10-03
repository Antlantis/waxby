extends RefCounted
## The relics. Each is found once and kept for good in the account-wide
## codex; a hero feels one only while it's on their belt (2 / 3 / 4 slots at
## L1 / L5 / L10, and 5 at L24 in v3: Progression.belt_slots). Rarity sets
## how often it rolls, the color of its beam and name, its fanfare and the
## Chandler's price. The numbers some of them change live in hero.gd
## (RELIC_MODS, RELIC_FLAGS); the rest are rules the world checks with
## Game.equipped(id).
##
## v3: each relic has the world it belongs to; rolls and the shelf offer
## only worlds reached (max_world), and a gold reliquary or a boss can favor
## its own world (x2). v2's twelve are World 1's, so they stay in every pool
## as before. v3's eight (spec §8.3, DEEP) are known to the save at once
## (a save keeps them) but join the codex, rolls and the shelf only with
## DEEP_LIVE: belt_panel.gd's codex grid holds twelve until the screens
## stream lays out twenty (then flip it; see the PR report).

const RARITY_WEIGHT := {"common": 55.0, "magic": 30.0, "rare": 12.0, "legendary": 3.0}
const RARITY_ORDER := ["common", "magic", "rare", "legendary"]
const RARITY_NAME := {"common": "Common", "magic": "Blessed", "rare": "Rare", "legendary": "Legendary"}
const PRICE := {"common": 60, "magic": 110, "rare": 200, "legendary": 350}
const FAVOR := 2.0   # a favored world's relics roll twice as often

const ALL := [
	{"id": "tallow_heart", "name": "Tallow Heart", "rarity": "common",
		"text": "+15% max life.", "world": 1},
	{"id": "longsword", "name": "Longsword", "rarity": "common",
		"text": "Reach 40% further; shots fly 30% further.", "world": 1},
	{"id": "moth_charm", "name": "Moth Charm", "rarity": "common",
		"text": "Embers and loot flutter to you.", "world": 1},
	{"id": "owls_eye", "name": "Owl's Eye", "rarity": "common",
		"text": "Sigils, false stone and mimics glint in the dark.", "world": 1},
	{"id": "rook_feather", "name": "Rook Feather", "rarity": "magic",
		"text": "Jump again in midair.", "world": 1},
	{"id": "iron_boots", "name": "Iron Boots", "rarity": "magic",
		"text": "Stomps send a shockwave both ways.", "world": 1},
	{"id": "bellows", "name": "Great Bellows", "rarity": "magic",
		"text": "Your light burns 30% wider.", "world": 1},
	{"id": "wind_wick", "name": "Wind Wick", "rarity": "magic",
		"text": "Water can't douse you; moths drink half.", "world": 1},
	{"id": "bell_shard", "name": "Bell Shard", "rarity": "magic",
		"text": "Stomps stun foes close by.", "world": 1},
	{"id": "saints_knuckle", "name": "Saint's Knuckle", "rarity": "rare",
		"text": "Swings cast a bolt of flame; every 3rd shot pierces.", "world": 1},
	{"id": "choir_bone", "name": "Choir Bone", "rarity": "rare",
		"text": "Kills heal 2% life.", "world": 1},
	{"id": "phoenix_wick", "name": "Phoenix Wick", "rarity": "legendary",
		"text": "Once a level, rise again when snuffed.", "world": 1},
]
# v3's eight (spec §8.3; Clockheart was drafted as "Mainspring"). Their
# numbers: hero.gd RELIC_MODS (clockheart, leaded_pane, sanctum_glass,
# hush_pearl, taper_match) and RELIC_FLAGS (sporeward, bone_flute,
# hoarfrost_bell: numbers in stats.flags for the world and features).
const DEEP := [
	{"id": "sporeward", "name": "Sporeward", "rarity": "magic",
		"text": "Spore clouds dim you half as much; spore bursts cost half.", "world": 3},
	{"id": "bone_flute", "name": "Bone Flute", "rarity": "rare",
		"text": "Every 8th kill calls a bone moth that strikes the nearest foe for 150% basic.", "world": 3},
	{"id": "hoarfrost_bell", "name": "Hoarfrost Bell", "rarity": "magic",
		"text": "Stomps and bonks chill foes: 40% slower for 2 s.", "world": 4},
	{"id": "clockheart", "name": "Clockheart", "rarity": "rare",
		"text": "+10% attack speed and +15% resource regen.", "world": 4},
	{"id": "leaded_pane", "name": "Leaded Pane", "rarity": "magic",
		"text": "Shots and shards hit you for 20% less.", "world": 5},
	{"id": "sanctum_glass", "name": "Sanctum Glass", "rarity": "rare",
		"text": "+20% damage to elites and bosses.", "world": 5},
	{"id": "hush_pearl", "name": "Hush Pearl", "rarity": "rare",
		"text": "Dimming is halved, and your light burns 10% wider.", "world": 6},
	{"id": "taper_match", "name": "Mother Taper's Match", "rarity": "legendary",
		"text": "Your flask holds one more draught.", "world": 6},
]
const DEEP_LIVE := true    # v3's eight in the codex, rolls and shelf (belt_panel's grid first)
static var deep_live := DEEP_LIVE


static func every() -> Array:
	## The relics in play: v2's twelve, and v3's eight once they're live.
	return ALL + DEEP if deep_live else ALL


static func get_relic(id: String) -> Dictionary:
	for r in ALL + DEEP:
		if r["id"] == id:
			return r
	return {"id": id, "name": id, "rarity": "common", "text": ""}


static func ids() -> Array:
	## The codex, in order (what belt_panel.gd lays out).
	var out := []
	for r in every():
		out.append(r["id"])
	return out


static func known(id: String) -> bool:
	## A relic id this build knows, live or not: a save keeps it.
	for r in ALL + DEEP:
		if r["id"] == id:
			return true
	return false


static func price(id: String) -> int:
	return int(PRICE.get(get_relic(id)["rarity"], 60))


static func world_of(id: String) -> int:
	return int(get_relic(id).get("world", 1))


static func roll(rng: RandomNumberGenerator, owned: Array, min_rarity := "common", max_world := 99, favor := 0) -> String:
	## A random relic not yet owned, from the worlds up to max_world, weighted
	## by rarity, at least min_rarity when one that rare is left. favor (a
	## world) doubles that world's relics (a gold reliquary's, a boss's own):
	## with none of them in the pool it rolls as without. "" when none are left.
	var floor_i := RARITY_ORDER.find(min_rarity)
	var pool := []
	for r in every():
		if not owned.has(r["id"]) and int(r.get("world", 1)) <= max_world and RARITY_ORDER.find(r["rarity"]) >= floor_i:
			pool.append(r)
	if pool.is_empty():
		for r in every():
			if not owned.has(r["id"]) and int(r.get("world", 1)) <= max_world:
				pool.append(r)
	if pool.is_empty():
		return ""
	var total := 0.0
	for r in pool:
		total += _weight(r, favor)
	var pick := rng.randf() * total
	for r in pool:
		pick -= _weight(r, favor)
		if pick <= 0.0:
			return r["id"]
	return pool[pool.size() - 1]["id"]


static func _weight(r: Dictionary, favor: int) -> float:
	var w: float = RARITY_WEIGHT[r["rarity"]]
	if favor > 0 and int(r.get("world", 1)) == favor:
		w *= FAVOR
	return w


static func for_sale(owned: Array, n := 3, max_world := 99) -> Array:
	## What the Chandler has on his shelf, from the worlds up to max_world:
	## the cheapest relic not yet owned of each rarity, the cheapest rarities
	## first (in World 1 Tallow Heart, Rook Feather and Saint's Knuckle), so
	## there's always one worth saving for. With fewer rarities left than n,
	## the cheapest of the rest fill the shelf. Cheapest first on the shelf.
	var left := []
	for rar in RARITY_ORDER:
		for r in every():
			if r["rarity"] == rar and not owned.has(r["id"]) and int(r.get("world", 1)) <= max_world:
				left.append(r)
	var picks := []
	for rar in RARITY_ORDER:
		for r in left:
			if r["rarity"] == rar:
				picks.append(r["id"])
				break
	for r in left:
		if not picks.has(r["id"]):
			picks.append(r["id"])
	picks = picks.slice(0, maxi(n, 0))
	return left.filter(func(r): return picks.has(r["id"]))
