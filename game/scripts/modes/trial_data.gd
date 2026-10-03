extends RefCounted
## The Vigil Trials as data (spec §7.4, p_modes §7.3): twenty rooms, four a
## calling (ids k1-k4, w1-w4, r1-r4, f1-f4, x1-x4, the tree prefixes), each
## with its fixed loadout (the trial's hero level, skill ranks legal under
## Classes.can_buy in the order listed, a Blessed starter kit at that item
## level seeded by the id, an empty belt), its lesson (the room's first
## sign), and its base time B from the timing bot (tests/test_modes.gd walks
## the room's reach graph with Dijkstra, assist ledges in, and adds 1.5 s per
## required kill and 0.8 s per shot candle).
##
## Medals: Bronze for any finish, Silver <= 2.0 x B, Gold <= 1.5 x B, Dawn
## <= 1.15 x B (decisions.md). The room files are game/levels/trials/<id>.txt,
## written by tools/make_trials.py; a trial whose file isn't built yet shows
## as "coming" and never opens.

const MEDALS := ["", "bronze", "silver", "gold", "dawn"]
const MEDAL_NAME := ["None", "Bronze", "Silver", "Gold", "Dawn"]
const MEDAL_MULT := {"silver": 2.0, "gold": 1.5, "dawn": 1.15}   # x B: at most this for the medal
const MEDAL_EMBERS := [0, 25, 40, 80, 150]    # paid on the first medal of each kind, per trial
const KILL_SECONDS := 1.5                      # the timing bot's allowance per required kill
const SHOT_SECONDS := 0.8                      # ...and per shot candle
const ORDER := ["k1", "k2", "k3", "k4", "w1", "w2", "w3", "w4", "r1", "r2", "r3", "r4",
		"f1", "f2", "f3", "f4", "x1", "x2", "x3", "x4"]
const BY_CLS := {"knight": ["k1", "k2", "k3", "k4"], "witch": ["w1", "w2", "w3", "w4"], "runner": ["r1", "r2", "r3", "r4"],
		"founder": ["f1", "f2", "f3", "f4"], "sexton": ["x1", "x2", "x3", "x4"]}
# Mother Taper's medal lines (Hollin says them while she rests: Story.REST_SUBS).
const LINES := ["You got there. That's the first lesson.", "Well walked. Again?", "Better. Your flame knows the way now.",
		"Beautiful. I'd ring a bell for that.", "I've never seen it done faster. Not even by me."]

# base: B in seconds: the timing bot's route (WAXBY_TIMING=1 prints it; the
# test holds B at or over it, and within 1.6x + 6 s) plus what no route
# shows: a bow's draw, a flare's charge, a kick's hang, a mote's flight.
# Timing bot / B: k1 7.8 / 14, k2 15.8 / 19, w1 17.0 / 22, w2 13.8 / 16,
# r2 11.6 / 16, f2 21.4 / 24, x1 13.5 / 15.5, x2 23.8 / 28. 0 until the room
# is built. KIT_TIMED trials' B is the real kit's instead (the timing bot
# walks, and their quirk outruns a walk): f1 the kit's hold-right with
# Stampede 14.8 / 15 (the bot's walk 19.8), r1 the kit's run with the Smoke
# Step 12.0 / 12 (the walk 15.8); tests/test_modes.gd plays both, and a run
# that breaks stride (a half-second stop every three) takes Gold, not Dawn.
# Tune from the owner's first tries: slower than 3 x B means the route is
# too hard, not too slow.
const KIT_TIMED := ["f1", "r1"]
const TRIALS := {
	"k1": {"cls": "knight", "n": 1, "name": "Ping!", "level": 8,
		"ranks": [["k_aegis", 2], ["k_tempered", 2], ["k_devout", 1], ["k_mirror", 3]],
		"lesson": "Guard as the arrow lands. A perfect guard throws it home.", "base": 14.0},
	"k2": {"cls": "knight", "n": 2, "name": "Shield and Stair", "level": 12,
		"ranks": [["k_aegis", 4], ["k_tempered", 2], ["k_devout", 2], ["k_mirror", 3], ["k_keen", 1]],
		"lesson": "Hold a direction to rush. Missed a ledge? Reach for it.", "base": 19.0},
	"k3": {"cls": "knight", "n": 3, "name": "Three Cuts", "level": 16,
		"ranks": [["k_aegis", 4], ["k_keen", 2], ["k_honed", 2], ["k_crescent", 3], ["k_tempered", 2], ["k_devout", 2]],
		"lesson": "Cut, cut, cut: the third throws light.", "base": 0.0},
	"k4": {"cls": "knight", "n": 4, "name": "Dawnbringer", "level": 24, "master": true,
		"ranks": [["k_aegis", 5], ["k_keen", 2], ["k_honed", 2], ["k_crescent", 3], ["k_dawn", 1], ["k_tempered", 2], ["k_devout", 2], ["k_mirror", 3]],
		"lesson": "Rush once in the air. Leave fire where you've been.", "base": 0.0},
	"w1": {"cls": "witch", "n": 1, "name": "Lanterns of Wax", "level": 8,
		"ranks": [["w_flare", 3], ["w_hotter", 2], ["w_twin", 2], ["w_kindle", 1]],
		"lesson": "A flare leaves a light. Throw one before you jump.", "base": 22.0},
	"w2": {"cls": "witch", "n": 2, "name": "Drift", "level": 12,
		"ranks": [["w_flare", 3], ["w_reservoir", 2], ["w_waxskin", 2], ["w_seal", 3], ["w_hotter", 2]],
		"lesson": "Press jump again as you fall, and float.", "base": 16.0},
	"w3": {"cls": "witch", "n": 3, "name": "Sealing Wax", "level": 16,
		"ranks": [["w_flare", 4], ["w_reservoir", 2], ["w_waxskin", 2], ["w_seal", 3], ["w_hotter", 2], ["w_twin", 2]],
		"lesson": "Wax slows what it sticks to.", "base": 0.0},
	"w4": {"cls": "witch", "n": 4, "name": "Sunburst", "level": 24, "master": true,
		"ranks": [["w_flare", 5], ["w_hotter", 2], ["w_twin", 2], ["w_kindle", 3], ["w_sunburst", 1], ["w_reservoir", 2], ["w_waxskin", 2], ["w_seal", 3]],
		"lesson": "A full flare breaks four ways.", "base": 0.0},
	"r1": {"cls": "runner", "n": 1, "name": "Through the Smoke", "level": 8,
		"ranks": [["r_step", 3], ["r_deadly", 2], ["r_quick", 2], ["r_veil", 1]],
		"lesson": "Step through them. Arrows too.", "base": 12.0},
	"r2": {"cls": "runner", "n": 2, "name": "Moth Cling", "level": 12,
		"ranks": [["r_step", 4], ["r_keen", 2], ["r_bandolier", 2], ["r_ricochet", 1], ["r_quick", 2], ["r_deadly", 1]],
		"lesson": "Slide down a wall, kick off it. A cling gives your step back.", "base": 16.0},
	"r3": {"cls": "runner", "n": 3, "name": "From Behind", "level": 16,
		"ranks": [["r_step", 4], ["r_deadly", 2], ["r_quick", 2], ["r_veil", 3], ["r_keen", 2], ["r_bandolier", 2]],
		"lesson": "A shield only faces one way.", "base": 0.0},
	"r4": {"cls": "runner", "n": 4, "name": "Thousand Cuts", "level": 24, "master": true,
		"ranks": [["r_step", 5], ["r_keen", 2], ["r_bandolier", 2], ["r_ricochet", 3], ["r_cuts", 1], ["r_deadly", 2], ["r_quick", 2], ["r_veil", 3]],
		"lesson": "Knives find corners. Steps end in knives.", "base": 0.0},
	"f1": {"cls": "founder", "n": 1, "name": "Stampede", "level": 8,
		"ranks": [["f_peal", 3], ["f_hide", 2], ["f_heavy", 2], ["f_after", 1]],
		"lesson": "Keep running. Small things get out of the way.", "base": 15.0},
	"f2": {"cls": "founder", "n": 2, "name": "Anvil", "level": 12,
		"ranks": [["f_peal", 4], ["f_hide", 2], ["f_heavy", 2], ["f_after", 3], ["f_bellows", 1]],
		"lesson": "Peal in the air, and fall like an anvil.", "base": 24.0},
	"f3": {"cls": "founder", "n": 3, "name": "Molten Peal", "level": 16,
		"ranks": [["f_peal", 4], ["f_bellows", 2], ["f_stoked", 2], ["f_slag", 3], ["f_hide", 2], ["f_heavy", 2]],
		"lesson": "Fill the Heat. A full Peal runs twice as far.", "base": 0.0},
	"f4": {"cls": "founder", "n": 4, "name": "The Great Bell", "level": 24, "master": true,
		"ranks": [["f_peal", 5], ["f_hide", 2], ["f_heavy", 2], ["f_after", 3], ["f_greatbell", 1], ["f_bellows", 2], ["f_stoked", 2], ["f_slag", 3]],
		"lesson": "Count your blows. Every fifth one rings.", "base": 0.0},
	"x1": {"cls": "sexton", "n": 1, "name": "Grave Step", "level": 8,
		"ranks": [["x_knell", 3], ["x_digger", 2], ["x_gravedirt", 2], ["x_chill", 1]],
		"lesson": "Jump again in the air: the dead lend you a step.", "base": 15.5},
	"x2": {"cls": "sexton", "n": 2, "name": "The Knell", "level": 12,
		"ranks": [["x_knell", 4], ["x_bright", 2], ["x_ward", 2], ["x_harvest", 1], ["x_digger", 2], ["x_gravedirt", 1]],
		"lesson": "Wisps strike only just after you do.", "base": 28.0},
	"x3": {"cls": "sexton", "n": 3, "name": "Toll the Dead", "level": 16,
		"ranks": [["x_knell", 4], ["x_digger", 2], ["x_gravedirt", 2], ["x_chill", 3], ["x_bright", 2], ["x_ward", 2]],
		"lesson": "Hold the Knell. Send them all in.", "base": 0.0},
	"x4": {"cls": "sexton", "n": 4, "name": "Choir of the Lost", "level": 24, "master": true,
		"ranks": [["x_knell", 5], ["x_bright", 2], ["x_ward", 2], ["x_harvest", 3], ["x_choir", 1], ["x_digger", 2], ["x_gravedirt", 2], ["x_chill", 3]],
		"lesson": "More wisps. The toll leaps from foe to foe.", "base": 0.0},
}


static func path(id: String) -> String:
	return "res://levels/trials/%s.txt" % id


static func built(id: String) -> bool:
	return TRIALS.has(id) and FileAccess.file_exists(path(id))


static func number(id: String) -> int:
	return int(TRIALS.get(id, {}).get("n", 1))


static func base_time(id: String) -> float:
	return float(TRIALS.get(id, {}).get("base", 0.0))


static func target(id: String, medal: int) -> float:
	## The time a medal needs (medal 2 Silver .. 4 Dawn), 0 when it has none.
	var b := base_time(id)
	if b <= 0.0 or medal < 2 or medal > 4:
		return 0.0
	return b * float(MEDAL_MULT[MEDALS[medal]])


static func medal_for(id: String, t: float) -> int:
	## The medal a finish in t seconds earns: 1 Bronze (any finish) .. 4 Dawn.
	var m := 1
	for k in [2, 3, 4]:
		var need := target(id, k)
		if need > 0.0 and t <= need + 0.0005:
			m = k
	return m


static func skills(id: String) -> Dictionary:
	## The loadout's skill ranks as a hero's "skills" dictionary.
	var out := {}
	for pair in TRIALS.get(id, {}).get("ranks", []):
		out[str(pair[0])] = int(pair[1])
	return out


const ROOTS := ["k_aegis", "w_flare", "r_step", "f_peal", "x_knell"]


static func points_used(id: String) -> int:
	## Skill points the loadout spends (the root's first rank is free).
	var n := 0
	for pair in TRIALS.get(id, {}).get("ranks", []):
		n += int(pair[1]) - (1 if ROOTS.has(str(pair[0])) else 0)
	return n
