extends RefCounted
## XP and levels: the curve, what things are worth, the level milestones.
## Static. The numbers are tuned against tests/test_progression.gd, which
## plays a first Dusk run of every level file and checks where the hero
## comes out (spec §1.5: about L2.8 after 1-1, L13.5 after the Snuffer,
## L32.1 after the Hush).
##
##   xp_to_next(L) = round(80 * 1.12^(L-1) * (1 + 0.19*(L-1)) * 1.30^max(0, L-32))   cap L40
##   kill          = BASE_XP[kind] * E(A) * elite * gap * DIFF.xp  (x0.5 respawned)
##   gap (d = L-A) = d > 3: max(0.1, 1 - 0.15*(d-3)) ; d < 0: 1 + min(1, 0.25*-d)
##   events        = sigil 15*E(A), first clear 30*E(A), clear 8*E(A),
##                   secret clear 45*E(A), candle 2*E(A), depth 20*E(A),
##                   altar 5, reliquary 2
##   Candlemarks   = every 150,000 XP past L40, up to 25 (derived, never stored)
##
## Levels 1-32 cost exactly v2's curve; E(A) is Combat.e_scale (no Depth).

const Combat := preload("res://scripts/combat.gd")
const CAP := 40
const CURVE_BASE := 80.0      # XP from L1 to L2
const CURVE_GROWTH := 1.12    # per level, compounding
const CURVE_RAMP := 0.19      # plus this share per level, linear
const LATE_FROM := 32         # the levels after this cost another x1.30 each
const LATE_MULT := 1.30
const MARK_XP := 150000       # a Candlemark every this much XP past the cap
const MARK_CAP := 25
# v2's kinds, then v3's (spec §4.2's starting values: the XP-budget walk
# tunes them, never the curve) and the new bosses. A kind with no entry pays 5.
const BASE_XP := {"skeleton": 5, "bat": 5, "thornback": 12, "bonebow": 7, "hollow_helm": 14, "gutterwing": 6,
		"dripkin": 6, "brinejaw": 7, "lidlurk": 40, "boss": 150, "tollgrave": 150, "snuffer": 250,
		"rootling": 6, "weepcap": 10, "rattlehound": 12, "creepbone": 8,
		"tickwind": 7, "spurwheel": 10, "frostbuckle": 20, "hoarowl": 9,
		"glassmite": 6, "gustling": 7, "refractor": 9, "paneguard": 15,
		"hushling": 6, "stillmaw": 14, "unwick": 14, "lurecoil": 24,
		"rootmother": 300, "tinker": 350, "saint": 400, "hush": 600}
const ELITE_MULT := {"": 1.0, "anointed": 3.0, "dread": 6.0, "warden": 8.0}
const EVENT_XP := {"sigil": 15.0, "first_clear": 30.0, "clear": 8.0,       # times E(A)
		"secret_clear": 45.0, "candle": 2.0, "depth": 30.0}
# (depth: decisions' 20 x E(A), raised to 30 at the track B merge, provisional
# with the W5-W6 numbers: against the real 5-x / 6-x Nightfall replays, which
# are denser than the model, a stratum of cathedral depths paid 0.96-1.05x at
# 20; at 30 it pays 1.01-1.10x, inside the 1-1.5x bound, kills still x1.0.)
const FLAT_XP := {"altar": 5, "reliquary": 2}
# The relic belt: 2 slots at L1, 3 at L5, 4 at L10, and a fifth at L24
# (FIFTH_BELT_AT; 0 would keep v2's four). On since the wave-1 merge:
# belt_panel.gd lays out the fifth slot and pause lists five relics.
const BELT_AT := [1, 5, 10]
const FIFTH_BELT := 24
const FIFTH_BELT_AT := FIFTH_BELT

static var _totals: PackedInt32Array = PackedInt32Array()


static func xp_to_next(level: int) -> int:
	if level >= CAP:
		return 0
	var l := maxi(level, 1)
	var x := CURVE_BASE * pow(CURVE_GROWTH, l - 1) * (1.0 + CURVE_RAMP * (l - 1))
	return roundi(x * pow(LATE_MULT, maxi(l - LATE_FROM, 0)))


static func total_to(level: int) -> int:
	## Total XP needed to reach a level from level 1 (0 for L1).
	if _totals.size() != CAP + 1:
		_totals.resize(CAP + 1)
		_totals[0] = 0
		_totals[1] = 0
		for l in range(2, CAP + 1):
			_totals[l] = _totals[l - 1] + xp_to_next(l - 1)
	return _totals[clampi(level, 1, CAP)]


static func level_of(total_xp: int) -> int:
	var l := 1
	while l < CAP and total_xp >= total_to(l + 1):
		l += 1
	return l


static func level_frac(total_xp: int) -> float:
	## The level plus the share of the way to the next: 2.5 is halfway
	## from L2 to L3. For the pacing test and the XP bar.
	var l := level_of(total_xp)
	if l >= CAP:
		return float(CAP)
	return l + float(total_xp - total_to(l)) / float(xp_to_next(l))


static func marks_of(xp: int) -> int:
	## Candlemarks: one every MARK_XP past the cap, up to MARK_CAP. Derived
	## from XP, never stored (+1% damage and life each, hero.gd).
	return clampi((xp - total_to(CAP)) / MARK_XP, 0, MARK_CAP) if xp > total_to(CAP) else 0


static func mark_frac(xp: int) -> float:
	## The way to the next Candlemark (0..1), for the bar at the cap; 1 once
	## every mark is in.
	if xp < total_to(CAP):
		return 0.0
	if marks_of(xp) >= MARK_CAP:
		return 1.0
	return float((xp - total_to(CAP)) % MARK_XP) / float(MARK_XP)


static func gap_mult(hero_level: int, area: int) -> float:
	## Over-leveled heroes earn less (to a floor of 10%); under-leveled
	## ones earn up to double, so a new calling catches up.
	var d := hero_level - area
	if d > 3:
		return maxf(0.1, 1.0 - 0.15 * (d - 3))
	if d < 0:
		return 1.0 + minf(1.0, 0.25 * -d)
	return 1.0


static func kill_xp(kind: String, area: int, hero_level: int, diff_id: String, tier := "", respawned := false) -> int:
	var base := float(BASE_XP.get(kind, 5))
	var x := base * Combat.e_scale(area) * float(ELITE_MULT.get(tier, 1.0)) * gap_mult(hero_level, area)
	x *= float(Combat.diff(diff_id)["xp"])
	if respawned:
		x *= 0.5
	return maxi(1, roundi(x))


static func event_xp(what: String, area: int) -> int:
	if EVENT_XP.has(what):
		return roundi(float(EVENT_XP[what]) * Combat.e_scale(area))
	return int(FLAT_XP.get(what, 0))


static func belt_levels() -> Array:
	## The levels that open each belt slot, first to last.
	var out: Array = BELT_AT.duplicate()
	if FIFTH_BELT_AT > 0:
		out.append(FIFTH_BELT_AT)
	return out


static func belt_slots(level: int) -> int:
	## Relic belt: 2 slots at L1, 3 at L5, 4 at L10 (5 at L24 when the fifth is on).
	var n := 2
	var at := belt_levels()
	for i in range(1, at.size()):
		if level >= int(at[i]):
			n += 1
	return n


static func belt_next(level: int) -> int:
	## The level that opens the next belt slot (0 once the belt is whole).
	var at := belt_levels()
	for i in range(1, at.size()):
		if level < int(at[i]):
			return int(at[i])
	return 0
