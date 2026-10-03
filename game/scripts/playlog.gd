extends RefCounted
## One line per level attempt in user://playlog.json, for tuning with real
## play on the phone (pull it with devicectl copy from ... Documents/playlog.json).
##
## A line: level, diff, calling, hero_level, cleared, snuffs, causes (what
## snuffed him, by cause: a monster's kind, a boss's id, "pit", "spikes"...),
## time, flask, altar_hp, xp, and (v3) sections (the snuffs where they
## happened: [{x, cause, move, feature}], x in tiles), by_section (snuffs per
## 16-tile band, "0-15": n), moves (snuffs by move id, "rootmother:sweep_high":
## n), features (snuffs by terrain: "vine_snap", "glass", "gust", "tide",
## "float", "still", "dawnglass": n; any name a feature notes is kept), phase (the boss phase reached, 0 without a boss),
## and mode (a mode's id, "" for the story). Build 1's loot and embers:
## items_found (items taken this attempt), legendaries_worn (of those, the
## Legendaries he wears at the line), relics_found (relics taken),
## embers_earned (embers picked up, in worth, banked or not: world.embers_got)
## and embers_spent (paid at the Chandler since the last line: Game.embers_spent,
## which world.gd _log clears once the line is written).

const PATH := "user://playlog.json"
static var path := PATH           # a test points it into its own folder (test_slots)
const MAX := 400
const BAND := 16                  # tiles per by_section band


static func entry(w: Node, cleared: bool, causes: Dictionary) -> Dictionary:
	## The line for a World's attempt (world.gd _log).
	var sections: Array = w.snuff_sections.duplicate(true)
	var moves := {}
	var feats := {}
	var bands := {}
	for s in sections:
		var mv := str(s.get("move", ""))
		if mv != "":
			moves[mv] = int(moves.get(mv, 0)) + 1
		var f := str(s.get("feature", ""))
		if f == "" and str(s.get("cause", "")) in ["vine_snap", "glass", "gust", "tide", "float", "still"]:
			f = str(s["cause"])
		if f != "":
			feats[f] = int(feats.get(f, 0)) + 1
		var b0 := int(s.get("x", 0)) / BAND * BAND
		var key := "%d-%d" % [b0, b0 + BAND - 1]
		bands[key] = int(bands.get(key, 0)) + 1
	var g = w.get_node_or_null("/root/Game")
	return {"level": w.level_id, "diff": w.diff, "calling": str(g.hero()["cls"]) if g else "", "hero_level": w.level_start,
			"cleared": cleared, "snuffs": w.snuffs, "causes": causes, "time": roundf(w.time),
			"flask": w.flask_uses, "altar_hp": w._last_altar_hp.duplicate(), "xp": w.xp_gained,
			"sections": sections, "by_section": bands, "moves": moves, "features": feats,
			"phase": int(w.phase_reached), "mode": str(w.mode.id) if w.mode != null else "",
			"items_found": w.items_found.size(), "legendaries_worn": legends_worn(w.items_found, g.hero() if g else {}),
			"relics_found": w.relics_found.size(), "embers_earned": int(w.embers_got),
			"embers_spent": int(g.get("embers_spent")) if g and g.get("embers_spent") != null else 0}


static func legends_worn(found: Array, h: Dictionary) -> int:
	## How many of the items found are Legendaries the hero wears now (worn on
	## pickup, or from the card; not one taken off again).
	var worn := {}
	var eq = h.get("equip", {})
	if eq is Dictionary:
		for slot in eq:
			if eq[slot] is Dictionary:
				worn[str(eq[slot].get("uid", ""))] = true
	var n := 0
	for it in found:
		if it is Dictionary and str(it.get("legend", "")) != "" and worn.has(str(it.get("uid", "-"))):
			n += 1
	return n


static func write(entry: Dictionary) -> void:
	var all := []
	if FileAccess.file_exists(path):
		# (A file cut short, by an app killed mid-write or two processes at
		# once, starts the log over quietly instead of erroring every write.)
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Array:
			all = j.data
	all.append(entry)
	if all.size() > MAX:
		all = all.slice(all.size() - MAX)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all))
