extends RefCounted
## The Descent's rooms: reading a biome's bundle (game/levels/rooms/<biome>.txt,
## written by tools/make_rooms.py), mirroring a room, turning its deep overlay
## on, and stitching rooms side by side into one level's text (spec §7.2,
## p_modes §5.4-5.5). Rooms meet at the T_OPEN seam, so nothing goes
## between them. Static only (the bundles are read once and kept).
##
## A room: {name, kind (landing | rest | bell | warden | challenge), tier,
## tags: [..], mirror: bool, width, src, deep: {at, cells: [{g, x, y}]},
## hint, cart: Vector2i (or (-1, -1)), seal: [Vector2i], spawn, rows: [15 str],
## overlay: str (the section's Z| row, "" when it has none), cog_phase and
## weight_phase: {x: turns} (room-relative)}.
##
## The features whose places live in headers (contract §2.3-2.5) travel with
## their room: the overlay row's gusts ( ) [ ] and Hush columns ;, and the cog
## and weight phases, are offset by the room's place when rooms are joined,
## mirrored with it, and written as the depth's gusts / hush / cog_phase /
## weight_phase headers, so a W4-W6 bundle stitches whole.

const H := 15
# The Descent's mirror map (contract §2.5): exactly these, and nothing else
# (a naive bracket swap would turn { vines into } rotten vines).
const MIRROR := {"<": ">", ">": "<", "O": "Q", "Q": "O"}
const MIRROR_OVERLAY := {"(": ")", ")": "(", "[": "]", "]": "["}
const GUST_KIND := {"(": ["L", "A"], ")": ["R", "A"], "[": ["L", "B"], "]": ["R", "B"]}
const STORY := "123@PKEXD"

static var _cache := {}


static func bundle_path(biome: String) -> String:
	return "res://levels/rooms/%s.txt" % biome


static func exists(biome: String) -> bool:
	return FileAccess.file_exists(bundle_path(biome))


static func load_bundle(biome: String) -> Array:
	## Every room of a biome ([] when its bundle isn't built).
	if _cache.has(biome):
		return _cache[biome]
	var out: Array = []
	if exists(biome):
		out = parse_bundle(FileAccess.get_file_as_string(bundle_path(biome)))
	_cache[biome] = out
	return out


static func parse_bundle(text: String) -> Array:
	var out: Array = []
	var cur := {}
	var in_rows := false
	for raw in text.replace("\r", "").split("\n"):
		var line: String = raw
		if line.begins_with("#") and not in_rows:
			continue
		if line.begins_with("=== "):
			if not cur.is_empty():
				out.append(_finish(cur))
			cur = {"name": line.substr(4).strip_edges(), "rows": [], "headers": {}}
			in_rows = false
			continue
		if cur.is_empty():
			continue
		if not in_rows:
			if line.strip_edges() == "---":
				in_rows = true
				continue
			var c := line.find(":")
			if c > 0:
				cur["headers"][line.substr(0, c).strip_edges()] = line.substr(c + 1).strip_edges()
			continue
		if (cur["rows"] as Array).size() < H and line != "":
			(cur["rows"] as Array).append(line)
		elif (cur["rows"] as Array).size() == H and line.begins_with("Z|"):
			cur["overlay"] = line.substr(2)
	if not cur.is_empty():
		out.append(_finish(cur))
	return out


static func _finish(cur: Dictionary) -> Dictionary:
	var h: Dictionary = cur["headers"]
	var rows: Array = cur["rows"]
	var w := int(h.get("width", 0))
	for r in rows:
		w = maxi(w, (r as String).length())
	for i in rows.size():
		rows[i] = (rows[i] as String).rpad(w, ".")
	var deep := {"at": 9999, "cells": []}
	var dv := str(h.get("deep", ""))
	if dv != "":
		deep["at"] = int(dv.get_slice("|", 0))
		for part in dv.get_slice("|", 1).split(";", false):
			var g := part.get_slice("@", 0)
			var xy := part.get_slice("@", 1)
			(deep["cells"] as Array).append({"g": g, "x": int(xy.get_slice(",", 0)), "y": int(xy.get_slice(",", 1))})
	var cart := Vector2i(-1, -1)
	if str(h.get("cart", "")) != "":
		var cv := str(h["cart"])
		cart = Vector2i(int(cv.get_slice(",", 0)), int(cv.get_slice(",", 1)))
	var seal: Array = []
	for part in str(h.get("seal", "")).split(";", false):
		seal.append(Vector2i(int(part.get_slice(",", 0)), int(part.get_slice(",", 1))))
	var tags: Array = []
	for t in str(h.get("tags", "")).split(",", false):
		tags.append(t.strip_edges())
	var over := str(cur.get("overlay", ""))
	if over.replace(".", "") == "":
		over = ""
	return {"name": cur["name"], "kind": str(h.get("kind", "challenge")), "tier": int(h.get("tier", 0)), "tags": tags,
			"mirror": str(h.get("mirror", "no")) == "yes", "width": w, "src": str(h.get("src", "")), "deep": deep,
			"hint": str(h.get("hint", "")), "cart": cart, "seal": seal, "spawn": str(h.get("spawn", "")), "rows": rows,
			"overlay": over.substr(0, w).rpad(w, ".") if over != "" else "",
			"cog_phase": _phases(str(h.get("cog_phase", ""))), "weight_phase": _phases(str(h.get("weight_phase", "")))}


static func _phases(v: String) -> Dictionary:
	## "4=0.25, 12=0.5" -> {4: 0.25, 12: 0.5} (room-relative x).
	var out := {}
	for part in v.split(",", false):
		var kv := part.strip_edges().split("=")
		if kv.size() == 2 and kv[0].strip_edges().is_valid_int():
			out[int(kv[0])] = float(kv[1])
	return out


static func of_kind(rooms: Array, kind: String, tier := -1) -> Array:
	return rooms.filter(func(r): return r["kind"] == kind and (tier < 0 or int(r["tier"]) == tier))


static func find(rooms: Array, name: String) -> Dictionary:
	for r in rooms:
		if r["name"] == name:
			return r
	return {}


static func mirrored(rm: Dictionary) -> Dictionary:
	## The room flipped left to right: rows reversed with exactly the MIRROR
	## swaps, and its deep cells, cart and seal moved with it.
	var out := rm.duplicate(true)
	var w := int(rm["width"])
	var rows: Array = []
	for r in rm["rows"]:
		var s := ""
		var src: String = r
		for i in range(src.length() - 1, -1, -1):
			var ch := src[i]
			s += str(MIRROR.get(ch, ch))
		rows.append(s)
	out["rows"] = rows
	for c in out["deep"]["cells"]:
		c["x"] = w - 1 - int(c["x"])
	if (rm["cart"] as Vector2i).x >= 0:
		out["cart"] = Vector2i(w - 1 - (rm["cart"] as Vector2i).x, (rm["cart"] as Vector2i).y)
	var seal: Array = []
	for c in rm["seal"]:
		seal.append(Vector2i(w - 1 - (c as Vector2i).x, (c as Vector2i).y))
	out["seal"] = seal
	var over := str(rm.get("overlay", ""))
	if over != "":
		var o := ""
		for i in range(over.length() - 1, -1, -1):
			o += str(MIRROR_OVERLAY.get(over[i], over[i]))
		out["overlay"] = o
	for key in ["cog_phase", "weight_phase"]:
		var ph := {}
		var src_ph: Dictionary = rm.get(key, {})
		for x in src_ph:
			ph[w - 1 - int(x)] = src_ph[x]
		out[key] = ph
	out["name"] = str(rm["name"]) + "~"
	out["mirrored"] = true
	return out


static func with_deep(rm: Dictionary) -> Dictionary:
	## The room with its deep overlay's monsters written in (air cells only).
	var out := rm.duplicate(true)
	var rows: Array = out["rows"]
	for c in rm["deep"]["cells"]:
		var x := int(c["x"])
		var y := int(c["y"])
		if y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length() and (rows[y] as String)[x] == ".":
			var r: String = rows[y]
			rows[y] = r.substr(0, x) + str(c["g"]) + r.substr(x + 1)
	return out


static func strip(rm: Dictionary, glyphs: String) -> Dictionary:
	## The room with these glyphs taken out (the cache's R before depth 2).
	var out := rm
	for ch in glyphs:
		out = swap(out, ch, ".")
	return out


static func swap(rm: Dictionary, from: String, to: String) -> Dictionary:
	## The room with one glyph put for another (a spent landing reliquary: R -> U).
	var out := rm.duplicate(true)
	var rows: Array = out["rows"]
	for i in rows.size():
		rows[i] = (rows[i] as String).replace(from, to)
	return out


static func join(parts: Array) -> Dictionary:
	## Rooms side by side: {rows: [15 str], spans: [{name, x0, x1, kind}],
	## overlay: the joined Z| row ("." where a room has none), cog_phase and
	## weight_phase: {absolute x: turns}}.
	var rows: Array = []
	for i in H:
		rows.append("")
	var spans: Array = []
	var overlay := ""
	var cogs := {}
	var weights := {}
	var x := 0
	for rm in parts:
		var rr: Array = rm["rows"]
		var w := int(rm["width"])
		for i in H:
			rows[i] = str(rows[i]) + (str(rr[i]) if i < rr.size() else "").rpad(w, ".")
		overlay += str(rm.get("overlay", "")).substr(0, w).rpad(w, ".")
		for px in (rm.get("cog_phase", {}) as Dictionary):
			cogs[x + int(px)] = rm["cog_phase"][px]
		for px in (rm.get("weight_phase", {}) as Dictionary):
			weights[x + int(px)] = rm["weight_phase"][px]
		spans.append({"name": str(rm["name"]), "kind": str(rm["kind"]), "x0": x, "x1": x + w - 1, "tier": int(rm.get("tier", 0))})
		x += w
	return {"rows": rows, "spans": spans, "overlay": overlay, "cog_phase": cogs, "weight_phase": weights}


static func _runs(line: String, chars: String) -> Array:
	## [[x0, x1, ch]]: runs of one glyph from chars (as common.py's overlay_runs).
	var out: Array = []
	var x := 0
	while x < line.length():
		var ch := line[x]
		if chars.contains(ch):
			var x1 := x
			while x1 + 1 < line.length() and line[x1 + 1] == ch:
				x1 += 1
			out.append([x, x1, ch])
			x = x1 + 1
		else:
			x += 1
	return out


static func gusts_header(overlay: String) -> String:
	## "120-131:R:A, 150-161:L:B" from a joined overlay ("" with no gusts).
	var out := PackedStringArray()
	for r in _runs(overlay, "()[]"):
		out.append("%d-%d:%s:%s" % [r[0], r[1], GUST_KIND[r[2]][0], GUST_KIND[r[2]][1]])
	return ", ".join(out)


static func hush_header(overlay: String) -> String:
	## "52-75, 200-227": the Hush-zone columns of a joined overlay.
	var out := PackedStringArray()
	for r in _runs(overlay, ";"):
		out.append("%d-%d" % [r[0], r[1]])
	return ", ".join(out)


static func phases_header(ph: Dictionary) -> String:
	## {x: turns} -> "212=0.25, 220=0.5" (x ascending), as common.py writes it.
	var xs := ph.keys()
	xs.sort()
	var out := PackedStringArray()
	for px in xs:
		out.append("%d=%s" % [int(px), str(snappedf(float(ph[px]), 0.0001)).trim_suffix(".0")])
	return ", ".join(out)


static func append_cols(rows: Array, extra: Array) -> Array:
	## Columns from another level glued on the right (an echo's arena).
	var out: Array = []
	var w := 0
	for r in rows:
		w = maxi(w, (r as String).length())
	for i in H:
		out.append(str(rows[i]).rpad(w, ".") + (str(extra[i]) if i < extra.size() else ""))
	return out


static func signs_in(rows: Array) -> Array:
	## Every sign's cell in reading order (row by row), as LevelData hands out hints.
	var out: Array = []
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if r[x] == "@":
				out.append(Vector2i(x, y))
	return out


static func hints_for(rows: Array, by_x: Dictionary) -> String:
	## The hints header: each sign's text (by_x: sign x -> text) in reading
	## order, as tools/levels/common.py's _order_hints does.
	var out := PackedStringArray()
	for c in signs_in(rows):
		out.append(str(by_x.get((c as Vector2i).x, "")))
	return "|".join(out)


static func level_text(header: Array, rows: Array) -> String:
	## A level file's text from [[key, value], ...] and its rows.
	var s := ""
	for kv in header:
		if str(kv[1]) != "":
			s += "%s: %s\n" % [kv[0], kv[1]]
	s += "---\n"
	for r in rows:
		s += str(r) + "\n"
	return s


static func rows_of_level(text: String) -> Array:
	## A level text's rows (after ---), padded to one width.
	var out: Array = []
	var in_rows := false
	for line in text.replace("\r", "").split("\n"):
		if not in_rows:
			if line.strip_edges() == "---":
				in_rows = true
			continue
		out.append(line)
	while out.size() > 0 and str(out[out.size() - 1]).strip_edges() == "":
		out.pop_back()
	var w := 0
	for r in out:
		w = maxi(w, (r as String).length())
	for i in out.size():
		out[i] = (out[i] as String).rpad(w, ".")
	return out


static func cols(rows: Array, x0: int, x1 := -1) -> Array:
	## Columns x0..x1 of rows (x1 -1: to the end).
	var out: Array = []
	for r in rows:
		var s: String = r
		var e := s.length() if x1 < 0 else mini(x1 + 1, s.length())
		out.append(s.substr(x0, maxi(e - x0, 0)))
	return out
