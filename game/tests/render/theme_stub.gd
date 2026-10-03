extends RefCounted
## The stub theme (tests/test_render.gd, tools/shot_render.gd --stub): the
## plain painter and the plain backdrop style, with motes and edge lines, so
## the v3 theme path renders end to end before any art stream lands. LAB is a
## small level in v2's glyphs; LAB_V3 overlays v3's tiles by glyph
## ({ } I _ Z < > G A, Q for lit dawnglass, & for still water), set by id so
## it runs on a v2 level_data.gd too.

const THEMES := {
	"stub": {"style": "plain", "painter": "plain", "sky": Color("121620"), "far": Color("1c2230"), "mid": Color("263044"),
			"near": Color("141a26"), "glass": [Color("6ab0d8"), Color("e0e8f8")], "banner": Color("2a3a5a"),
			"dark_color": Color(0.24, 0.26, 0.36)},
	"stub_missing": {"style": "no_such_style", "painter": "no_such_painter", "sky": Color("121620"), "far": Color("1c2230"),
			"mid": Color("263044"), "near": Color("141a26"), "glass": [Color("6ab0d8")], "banner": Color("2a3a5a"),
			"dark_color": Color(0.24, 0.26, 0.36)},
}
const PALETTES := {
	"stub": {"stone": Color("48506a"), "shade": Color("383f56"), "lip": Color("7c88a8"), "buried": Color("262c3c")},
}
const AMBIENT := {
	"stub": [{"kind": "mote", "count": 24, "size": 1.6, "color": Color("d8e4ff"), "alpha": 0.5, "drift": Vector2(4, -8),
			"sway": 6.0, "parallax": 0.8, "near_light": true, "floor": 0.35},
		{"kind": "ripple", "count": 2, "color": Color("e0e0ff"), "alpha": 0.4}],
}
const EDGES := {
	"stub": [{"what": "vine", "color": Color("9ad07a"), "alpha": 0.35}, {"what": "glass", "color": Color("d8e4f4"), "alpha": 0.30},
		{"what": "crest", "color": Color("a0a0d0"), "alpha": 0.30}],
}

const LAB := """title: The Render Lab
subtitle: Phase 0
music: chapel
theme: stub
area: 1
---
################################################################
#..............................................................#
#..............................................................#
#.....#####....................................................#
#..............................................................#
#.............................c................................#
#...................c.......................c..................#
#..............................................................#
#.........................========.............................#
#..............====............................................#
#..................................######......................#
#.......................................o......................#
#..P........o..........###.......................::::::.^^..E..#
#################################################::::::#########
################################################################
"""

const LAB_V3 := """................................................................
................................................................
................................................................
................................................................
........{.......................................................
........{.......................................................
........{.......................................................
........{.......................................................
........{..}....................................................
........{..}...____.............................................
........{..}.......................GGGGGG.AAAQQQ................
........{.......................................................
.......................ZZZ........................&&&...........
..............IIIIIIII.....<<<>>>...............................
................................................................
"""


static func stub_level() -> RefCounted:
	## LAB with LAB_V3's v3 tiles set by id (level_data.gd's set_tile, v2's
	## (x, y, t) or v3's (cell, t)).
	var LevelData = load("res://scripts/level_data.gd")
	var lv = LevelData.new()
	lv.parse(LAB)
	lv.id = "render-lab"
	lv.theme = "stub"
	var marks := {"{": 12, "}": 13, "I": 14, "_": 15, "Z": 16, "<": 17, ">": 18, "G": 19, "A": 20, "Q": 21, "&": 22}
	var n := 3
	for m in lv.get_method_list():
		if str(m["name"]) == "set_tile":
			n = (m["args"] as Array).size()
	var rows: PackedStringArray = LAB_V3.split("\n", false)
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			if marks.has(ch) and x < lv.width and y < lv.height:
				if n >= 3:
					lv.call("set_tile", x, y, int(marks[ch]))
				else:
					lv.call("set_tile", Vector2i(x, y), int(marks[ch]))
	return lv
