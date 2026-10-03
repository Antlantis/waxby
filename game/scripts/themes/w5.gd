extends RefCounted
## World 5, the Shattered Sanctum (A2): the themes, tile palettes, motes and
## edge lines themes/loader.gd merges. Painter scripts/tiles/glass.gd, style
## scripts/backdrops/sanctum.gd.
##   choirglass  5-1 The Floating Aisle      choir stalls, rose windows of floating shards
##   rosewind    5-2 The Gale Gallery        the rose's shards streaming away in the wind
##   voidnave    5-3 The Dawnglass Bridges   darker and quiet, so the lamps matter
##   prismheart  5-4 The Lightwell           the Saint's empty window at the arena's back
## The most colourful world against the darkest sky. Pane colours (ruby,
## cobalt, amber, emerald) are picked per run and never carry meaning; the
## tell accent is prism white f8f0ff, which decoration never uses (spec §11.1):
## no theme glass, window tint or mote comes within 0.06 of it in any channel
## (tests/test_world_art2.gd), so the pale glass is lavender or ice blue.
## Every palette passes the contrast rule (stone/mid >= 1.45, stone/near >=
## 1.75, lip/mid >= 3.0: tests/test_world_art2.gd).
## "props" names the World 5 versions of the shared props (world.gd /
## level_features.gd look them up when they can; the v2 prop otherwise): each
## keeps its v2 frame and anchor points (tools/art/props_w5.py).

const PANES := [Color("c83a5a"), Color("3a6ac8"), Color("e0a830"), Color("4aa86a")]
const PROPS := {"altar": "altar_glass", "altar_lit": "altar_glass_lit", "bell": "bell_glass", "bell_beam": "bell_glass_beam",
		"lantern_post_lit": "prism_lamp_lit", "lantern_post_out": "prism_lamp_out", "sconce": "sconce_glass",
		"door_open": "window_seal_open", "door_closed": "window_seal_closed"}

const THEMES := {
	"choirglass": {"style": "sanctum", "painter": "glass", "variant": "choir",
			"sky": Color("08060e"), "far": Color("120e1e"), "mid": Color("1c1630"), "near": Color("0d0a17"),
			"glass": [Color("c83a5a"), Color("3a6ac8"), Color("e0a830"), Color("4aa86a")], "banner": Color("5a2e5a"),
			"dark_color": Color(0.16, 0.13, 0.26), "world": 5, "props": PROPS},
	"rosewind": {"style": "sanctum", "painter": "glass", "variant": "rose",
			"sky": Color("0a060c"), "far": Color("16101c"), "mid": Color("22182a"), "near": Color("100a14"),
			"glass": [Color("c83a5a"), Color("e8a0b0"), Color("e0a830")], "banner": Color("6a2e3a"),
			"dark_color": Color(0.20, 0.13, 0.22), "world": 5, "props": PROPS},
	"voidnave": {"style": "sanctum", "painter": "glass", "variant": "void",
			"sky": Color("050409"), "far": Color("0e0c18"), "mid": Color("181428"), "near": Color("0a0812"),
			"glass": [Color("3a6ac8"), Color("8a6ae0"), Color("b8c8f0")], "banner": Color("2a2a5a"),
			"dark_color": Color(0.12, 0.11, 0.22), "world": 5, "props": PROPS},
	"prismheart": {"style": "sanctum", "painter": "glass", "variant": "prism",
			"sky": Color("0a0812"), "far": Color("16122a"), "mid": Color("20183a"), "near": Color("0e0a1c"),
			"glass": [Color("d8c8f0"), Color("c83a5a"), Color("3a6ac8"), Color("e0a830"), Color("4aa86a")], "banner": Color("4a3a7a"),
			"dark_color": Color(0.18, 0.15, 0.30), "world": 5, "props": PROPS},
}

# The painter keys beside v2's (glass.gd): the panes, the lead came, gold
# leaf, the accent, dawnglass; ledges and crumbles are marble with a gold
# edge (never glass: glass is what breaks underfoot).
const PALETTES := {
	"choirglass": {"stone": Color("5a5070"), "shade": Color("463e5a"), "lip": Color("9c8ec4"), "mortar": Color("3e3654"),
			"buried": Color("2a2440"), "buried_mortar": Color("241f38"), "brick": Color("5a4a66"), "brick_shade": Color("443852"),
			"brick_lip": Color("8a78a0"), "slab": Color("7a7094"), "slab_lip": Color("b0a6cc"),
			"panes": PANES, "came": Color("1a1420"), "gold": Color("d8b24a"), "gold_hi": Color("ffe28a"),
			"accent": Color("f8f0ff"), "dawn": Color("f2d88a"), "dawn_hi": Color("fff4c8"),
			"marble": Color("8c84a4"), "marble_lip": Color("c8c0e0"), "marble_shade": Color("5e5876"),
			"lead": Color("2a2434"), "lead_hi": Color("5a5270")},
	"rosewind": {"stone": Color("5e5068"), "shade": Color("4a3e54"), "lip": Color("a490b8"), "mortar": Color("42384c"),
			"buried": Color("2c2436"), "buried_mortar": Color("251e2e"), "brick": Color("5e4858"), "brick_shade": Color("483644"),
			"brick_lip": Color("927890"), "slab": Color("80708c"), "slab_lip": Color("b8a4c4"),
			"panes": [Color("c83a5a"), Color("e8a0b0"), Color("e0a830"), Color("3a6ac8")], "came": Color("1a1420"),
			"gold": Color("d8b24a"), "gold_hi": Color("ffe28a"), "accent": Color("f8f0ff"), "dawn": Color("f2d88a"),
			"dawn_hi": Color("fff4c8"), "marble": Color("8e8098"), "marble_lip": Color("ccbcd8"), "marble_shade": Color("60546c"),
			"lead": Color("2c2230"), "lead_hi": Color("5c4e64")},
	"voidnave": {"gust_tell_min": 0.34,   # (the darkest W5: its gust tell's streaks and wisps at 0.30 or more)
			"stone": Color("524c6c"), "shade": Color("403a56"), "lip": Color("948abc"), "mortar": Color("3a344e"),
			"buried": Color("26223a"), "buried_mortar": Color("201c32"), "brick": Color("524868"), "brick_shade": Color("3e3652"),
			"brick_lip": Color("82769c"), "slab": Color("726a90"), "slab_lip": Color("aaa0c8"),
			"panes": [Color("3a6ac8"), Color("8a6ae0"), Color("5a8ae0"), Color("4aa86a")], "came": Color("16121e"),
			"gold": Color("c8a84a"), "gold_hi": Color("f0d890"), "accent": Color("f8f0ff"), "dawn": Color("f2d88a"),
			"dawn_hi": Color("fff4c8"), "marble": Color("8680a4"), "marble_lip": Color("c4bee4"), "marble_shade": Color("5a5478"),
			"lead": Color("262232"), "lead_hi": Color("56506c")},
	"prismheart": {"stone": Color("5a5274"), "shade": Color("463e5e"), "lip": Color("a898d0"), "mortar": Color("3e3858"),
			"buried": Color("2a2444"), "buried_mortar": Color("241f3c"), "brick": Color("5a4a6e"), "brick_shade": Color("443858"),
			"brick_lip": Color("8a7aa8"), "slab": Color("7a7298"), "slab_lip": Color("b4aad4"),
			"panes": PANES, "came": Color("1a1420"), "gold": Color("d8b24a"), "gold_hi": Color("ffe28a"),
			"accent": Color("f8f0ff"), "dawn": Color("f2d88a"), "dawn_hi": Color("fff4c8"),
			"marble": Color("908aac"), "marble_lip": Color("ccc6e8"), "marble_shade": Color("605a7c"),
			"lead": Color("2a2438"), "lead_hi": Color("5a5474")},
}

# The motes (ambient.gd). Glitter: 4-point stars in the pane colours, seen near
# the hero's light; a few slow shards (petals); voidnave's far falling stars.
# No "streak" entry: the wind is drawn by the gust zones themselves
# (glass.gd's draw_gust_glow), never across the whole screen.
const AMBIENT := {
	"choirglass": [
		{"kind": "star", "count": 8, "size": 1.3, "color": Color("e87890"), "alpha": 0.55, "drift": Vector2(3, -5), "sway": 8.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 8, "size": 1.3, "color": Color("7aa0f0"), "alpha": 0.55, "drift": Vector2(-3, -4), "sway": 8.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 8, "size": 1.3, "color": Color("f0c860"), "alpha": 0.55, "drift": Vector2(2, -6), "sway": 7.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 8, "size": 1.3, "color": Color("7ad09a"), "alpha": 0.55, "drift": Vector2(-2, -5), "sway": 7.0, "parallax": 0.9, "near_light": true},
		{"kind": "petal", "count": 8, "size": 2.2, "color": Color("b8b0e0"), "alpha": 0.22, "drift": Vector2(6, 4), "sway": 14.0, "parallax": 0.7, "near_light": false},
	],
	"rosewind": [
		{"kind": "star", "count": 8, "size": 1.3, "color": Color("e87890"), "alpha": 0.55, "drift": Vector2(8, -3), "sway": 10.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 8, "size": 1.3, "color": Color("f0b8c8"), "alpha": 0.5, "drift": Vector2(10, -2), "sway": 10.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 8, "size": 1.3, "color": Color("f0c860"), "alpha": 0.5, "drift": Vector2(7, -4), "sway": 9.0, "parallax": 0.9, "near_light": true},
		{"kind": "petal", "count": 10, "size": 2.4, "color": Color("d8a0b8"), "alpha": 0.24, "drift": Vector2(18, 3), "sway": 16.0, "parallax": 0.7, "near_light": false},
	],
	"voidnave": [
		{"kind": "star", "count": 8, "size": 1.2, "color": Color("8ab0f8"), "alpha": 0.5, "drift": Vector2(2, -4), "sway": 6.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 8, "size": 1.2, "color": Color("b8a0f8"), "alpha": 0.5, "drift": Vector2(-2, -4), "sway": 6.0, "parallax": 0.9, "near_light": true},
		{"kind": "mote", "count": 24, "size": 0.9, "color": Color("c8c4f0"), "alpha": 0.32, "drift": Vector2(-3, 22), "sway": 2.0, "parallax": 0.2, "near_light": false},
	],
	"prismheart": [
		{"kind": "star", "count": 10, "size": 1.4, "color": Color("e87890"), "alpha": 0.55, "drift": Vector2(2, -6), "sway": 8.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 10, "size": 1.4, "color": Color("7aa0f0"), "alpha": 0.55, "drift": Vector2(-2, -6), "sway": 8.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 10, "size": 1.4, "color": Color("f0c860"), "alpha": 0.55, "drift": Vector2(3, -7), "sway": 8.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 10, "size": 1.4, "color": Color("7ad09a"), "alpha": 0.55, "drift": Vector2(-3, -7), "sway": 8.0, "parallax": 0.9, "near_light": true},
	],
}

# Readability lines above the dark (edge_lines.gd): every glass top (the
# spec's 0.30), a faint lip on the floating masonry so the void's edges read
# at a glance, and the glass teeth's tips.
const EDGES := {
	"choirglass": [{"what": "glass", "color": Color("e4dcf8"), "alpha": 0.30}, {"what": "lip", "color": Color("b8aee0"), "alpha": 0.12},
		{"what": "spike", "color": Color("ece4ff"), "alpha": 0.26}],
	"rosewind": [{"what": "glass", "color": Color("f0dce8"), "alpha": 0.30}, {"what": "lip", "color": Color("c0acd4"), "alpha": 0.12},
		{"what": "spike", "color": Color("f0e4f0"), "alpha": 0.26}],
	"voidnave": [{"what": "glass", "color": Color("dce0fc"), "alpha": 0.32}, {"what": "lip", "color": Color("b0a8dc"), "alpha": 0.16},
		{"what": "spike", "color": Color("e4e4ff"), "alpha": 0.28}],
	"prismheart": [{"what": "glass", "color": Color("ece4ff"), "alpha": 0.30}, {"what": "lip", "color": Color("c0b4e8"), "alpha": 0.12},
		{"what": "spike", "color": Color("ece4ff"), "alpha": 0.26}],
}
