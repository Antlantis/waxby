extends RefCounted
## World 6, the Hushdeep (A2): the themes, tile palettes, motes and edge
## lines themes/loader.gd merges. Painter scripts/tiles/hush.gd, style
## scripts/backdrops/hushdeep.gd.
##   stillshore  6-1 The Black Shore           drowned spires hanging from the dark, bell frames, reeds
##   drownbell   6-2 The Drowned Bells         bell frames and broken bells half sunk
##   hushquiet   6-3 The Long Quiet            rings only: the darkest theme in the game
##   husheye     6-4 The Heart of the Hush     a vast iris of ripples round the arena
## Ink and silver: your candle is almost the only light, and the path always
## shows by a faint silver edge above the dark (EDGES, alpha 0.30: every
## walkable lip and spike tip; the lake's crest and the reeds' veins are drawn
## live, at 0.35). No decorative lights at all (the
## style has no windows): every light in W6 means something. The tell accent
## is the silver ripple e0e0ff, which decoration never uses (so no ambient
## ripples: a ripple here is a Hushgrasp's tell). The contrast rule holds
## (tests/test_world_art2.gd).
## Theme keys beside the usual: "water" / "water_deep" / "crest" (the lake:
## level_features.gd reads them when it can), "vine_vein" / "rot_vein" (the
## silver the orchard feature draws a reed's vein in, above the dark), "props" (the W6 props: altar,
## bell, the buoy lantern for the lantern post, the dead sconce, the eye
## seal), "sconce_light": false (W6's `c` gives no light, spec §3.2).

const PROPS := {"altar": "altar_hush", "altar_lit": "altar_hush_lit", "bell": "bell_hush", "bell_beam": "bell_hush_beam",
		"lantern_post_lit": "buoy_lantern_lit", "lantern_post_out": "buoy_lantern_out", "sconce": "sconce_dead",
		"door_open": "eye_seal_open", "door_closed": "eye_seal_closed"}

const THEMES := {
	"stillshore": {"style": "hushdeep", "painter": "hush", "variant": "shore",
			"sky": Color("040406"), "far": Color("09090e"), "mid": Color("0e0e14"), "near": Color("050507"),
			"glass": [Color("b0acd0"), Color("6a5a9a")], "banner": Color("2a2440"),
			"dark_color": Color(0.08, 0.08, 0.12), "world": 6, "props": PROPS, "sconce_light": false,
			"water": Color("0a0a12"), "water_deep": Color("06060c"), "crest": Color("8a88b0"), "vine_vein": Color("b0b0dc"), "rot_vein": Color("8e8ab4")},
	"drownbell": {"style": "hushdeep", "painter": "hush", "variant": "bell",
			"sky": Color("050407"), "far": Color("0b0a0f"), "mid": Color("101016"), "near": Color("060508"),
			"glass": [Color("b0acd0"), Color("b8862a")], "banner": Color("3a2a2a"),
			"dark_color": Color(0.08, 0.07, 0.11), "world": 6, "props": PROPS, "sconce_light": false,
			"water": Color("0a0a10"), "water_deep": Color("06050a"), "crest": Color("8a86a8"), "vine_vein": Color("b0acd8"), "rot_vein": Color("8e88b0")},
	"hushquiet": {"style": "hushdeep", "painter": "hush", "variant": "quiet",
			"sky": Color("030305"), "far": Color("08080c"), "mid": Color("0c0c11"), "near": Color("040406"),
			"glass": [Color("b0acd0")], "banner": Color("1a1830"),
			"dark_color": Color(0.06, 0.06, 0.09), "world": 6, "props": PROPS, "sconce_light": false,
			"water": Color("08080e"), "water_deep": Color("050508"), "crest": Color("8480ac"), "vine_vein": Color("b4b4e0"), "rot_vein": Color("908cb8")},
	"husheye": {"style": "hushdeep", "painter": "hush", "variant": "eye",
			"sky": Color("040308"), "far": Color("0a0812"), "mid": Color("100d18"), "near": Color("06050a"),
			"glass": [Color("b0acd0"), Color("6a5a9a")], "banner": Color("2a2440"),
			"dark_color": Color(0.07, 0.06, 0.12), "world": 6, "props": PROPS, "sconce_light": false,
			"water": Color("0a0812"), "water_deep": Color("06050c"), "crest": Color("8c86b4"), "vine_vein": Color("b4b0dc"), "rot_vein": Color("908ab8")},
}

# The painter keys beside v2's (hush.gd): silver, the Hush violets, the eye
# white, the tell accent; old black wood with silver nails for ledges; a
# rotten raft for crumbles; drowned wick-reeds for vines; and 6-4's memory
# rooms drawn from the other worlds drained to grey (ice, belts, glass,
# dawnglass).
const PALETTES := {
	"stillshore": {"stone": Color("3e3c52"), "shade": Color("302e40"), "lip": Color("7a789e"), "mortar": Color("34324a"),
			"buried": Color("1c1a26"), "buried_mortar": Color("181622"),
			"brick": Color("3a3444"), "brick_shade": Color("2a2634"), "brick_lip": Color("5a5470"),
			"slab": Color("5a5468"), "slab_lip": Color("7a7490"), "drip": Color("8a88b0"),
			"wood": Color("2a2634"), "wood_lip": Color("5a5470"), "wood_shade": Color("1a1822"), "nail": Color("c8c8f0"),
			"silver": Color("c8c8f0"), "violet": Color("4a3a7a"), "violet_hi": Color("6a5a9a"), "eye": Color("d8d4f0"),
			"accent": Color("e0e0ff"), "iron": Color("1e1c28"), "steel": Color("2a2836"), "steel_shade": Color("16141e"),
			"vine": Color("3a3a4c"), "vine_lit": Color("8a88b0"), "rot": Color("34303e"), "rot_lit": Color("6a6680"),
			"ice": Color("4a4a60"), "ice_lip": Color("a8a6c8"), "ice_shade": Color("34344a"), "rime": Color("8a88a8"),
			"belt": Color("24222e"), "belt_lip": Color("6a6680"), "belt_mark": Color("9a98b8"),
			"glass": Color(0.50, 0.50, 0.66, 0.45), "glass_lip": Color("d8d4f0"), "dawn": Color("f2d88a"), "dawn_hi": Color("fff4c8"),
			"still": Color("c8c8f0"), "panes": [Color("5a5a7c"), Color("6a5a9a"), Color("4c4c6a")], "came": Color("0e0c14"),
			"gold": Color("8a88b0"), "marble": Color("4a4860"), "marble_lip": Color("8a88b0"), "marble_shade": Color("302e40")},
	"drownbell": {"stone": Color("3c3846"), "shade": Color("2e2a38"), "lip": Color("807a96"), "mortar": Color("322e3e"),
			"buried": Color("1c1824"), "buried_mortar": Color("181420"),
			"brick": Color("3c3440"), "brick_shade": Color("2c2630"), "brick_lip": Color("5c5268"),
			"slab": Color("5c5464"), "slab_lip": Color("7c748a"), "drip": Color("8a86a8"),
			"wood": Color("2c2630"), "wood_lip": Color("5c5268"), "wood_shade": Color("1a161e"), "nail": Color("c8c4e8"),
			"silver": Color("c8c4e8"), "violet": Color("4a3a6a"), "violet_hi": Color("6a5a8a"), "eye": Color("d8d4f0"),
			"accent": Color("e0e0ff"), "iron": Color("1e1a24"), "steel": Color("2c2834"), "steel_shade": Color("16121c"),
			"vine": Color("3a3844"), "vine_lit": Color("8a86a8"), "rot": Color("34303a"), "rot_lit": Color("6a6478"),
			"ice": Color("4a4858"), "ice_lip": Color("a8a4c0"), "ice_shade": Color("343244"), "rime": Color("8a86a0"),
			"belt": Color("26222c"), "belt_lip": Color("6a6478"), "belt_mark": Color("b8862a"),
			"glass": Color(0.50, 0.48, 0.62, 0.45), "glass_lip": Color("d8d4f0"), "dawn": Color("f2d88a"), "dawn_hi": Color("fff4c8"),
			"still": Color("c8c4e8"), "panes": [Color("5c5874"), Color("6a5a8a"), Color("4e4a62")], "came": Color("0e0c12"),
			"gold": Color("b8862a"), "marble": Color("4a4658"), "marble_lip": Color("8a86a8"), "marble_shade": Color("302c3c")},
	"hushquiet": {"stone": Color("3a384e"), "shade": Color("2c2a3c"), "lip": Color("76749e"), "mortar": Color("302e44"),
			"buried": Color("1a1824"), "buried_mortar": Color("161420"),
			"brick": Color("36324a"), "brick_shade": Color("28243a"), "brick_lip": Color("56506e"),
			"slab": Color("565068"), "slab_lip": Color("76708e"), "drip": Color("8480ac"),
			"wood": Color("28243a"), "wood_lip": Color("56506e"), "wood_shade": Color("181624"), "nail": Color("c4c4ec"),
			"silver": Color("c4c4ec"), "violet": Color("46387a"), "violet_hi": Color("665896"), "eye": Color("d8d4f0"),
			"accent": Color("e0e0ff"), "iron": Color("1c1a28"), "steel": Color("28263a"), "steel_shade": Color("141220"),
			"vine": Color("38384c"), "vine_lit": Color("8480ac"), "rot": Color("322e40"), "rot_lit": Color("66627e"),
			"ice": Color("48485e"), "ice_lip": Color("a4a2c8"), "ice_shade": Color("323248"), "rime": Color("8684a8"),
			"belt": Color("22202e"), "belt_lip": Color("66627e"), "belt_mark": Color("9894b8"),
			"glass": Color(0.48, 0.48, 0.66, 0.45), "glass_lip": Color("d8d4f0"), "dawn": Color("f2d88a"), "dawn_hi": Color("fff4c8"),
			"still": Color("c4c4ec"), "panes": [Color("58587a"), Color("665896"), Color("4a4a68")], "came": Color("0c0c12"),
			"gold": Color("8480ac"), "marble": Color("48465e"), "marble_lip": Color("8480ac"), "marble_shade": Color("2e2c40")},
	"husheye": {"stone": Color("403a58"), "shade": Color("322c46"), "lip": Color("7e78a6"), "mortar": Color("36304c"),
			"buried": Color("1e1a2a"), "buried_mortar": Color("1a1624"),
			"brick": Color("3a3450"), "brick_shade": Color("2c2640"), "brick_lip": Color("5a5478"),
			"slab": Color("5a5470"), "slab_lip": Color("7a7496"), "drip": Color("8c86b4"),
			"wood": Color("2c2640"), "wood_lip": Color("5a5478"), "wood_shade": Color("1a1628"), "nail": Color("ccc8f0"),
			"silver": Color("ccc8f0"), "violet": Color("4a3a7a"), "violet_hi": Color("6a5a9a"), "eye": Color("d8d4f0"),
			"accent": Color("e0e0ff"), "iron": Color("201c2c"), "steel": Color("2c283c"), "steel_shade": Color("161222"),
			"vine": Color("3c3a50"), "vine_lit": Color("8c86b4"), "rot": Color("36304a"), "rot_lit": Color("6c6688"),
			"ice": Color("4c4a64"), "ice_lip": Color("aaa6cc"), "ice_shade": Color("36344c"), "rime": Color("8a86ac"),
			"belt": Color("262232"), "belt_lip": Color("6c6688"), "belt_mark": Color("9c98bc"),
			"glass": Color(0.50, 0.48, 0.68, 0.45), "glass_lip": Color("d8d4f0"), "dawn": Color("f2d88a"), "dawn_hi": Color("fff4c8"),
			"still": Color("ccc8f0"), "panes": [Color("5c5880"), Color("6a5a9a"), Color("4e4a6c")], "came": Color("0e0c16"),
			"gold": Color("8c86b4"), "marble": Color("4c4864"), "marble_lip": Color("8c86b4"), "marble_shade": Color("322e44"),
			# The Carillon memory's clockwork drained to grey with the rest
			# of the room (spec §3.7.2; the rev5 review: its cog was W4 gold).
			"brass": Color("8a869c"), "brass_sh": Color("5a566c"), "brass_hi": Color("c4c0d8"), "brass_line": Color("1e1a2a"),
			"cog_art": false},
}

# Hush dust: dark flecks seen only in your light (near_light); a few faint
# silver motes rising off the lake; in the Eye, pale motes drifting toward it.
const AMBIENT := {
	"stillshore": [
		{"kind": "mote", "count": 16, "size": 1.6, "color": Color("06060a"), "alpha": 0.6, "drift": Vector2(2, -3), "sway": 5.0, "parallax": 0.9, "near_light": true},
		{"kind": "mote", "count": 8, "size": 0.9, "color": Color("9a98c0"), "alpha": 0.26, "drift": Vector2(0, -9), "sway": 4.0, "parallax": 0.8, "near_light": false},
	],
	"drownbell": [
		{"kind": "mote", "count": 20, "size": 1.6, "color": Color("06060a"), "alpha": 0.6, "drift": Vector2(1, -3), "sway": 5.0, "parallax": 0.9, "near_light": true},
		{"kind": "mote", "count": 6, "size": 0.9, "color": Color("9a96b8"), "alpha": 0.22, "drift": Vector2(0, -8), "sway": 4.0, "parallax": 0.8, "near_light": false},
	],
	"hushquiet": [
		{"kind": "mote", "count": 24, "size": 1.7, "color": Color("050508"), "alpha": 0.65, "drift": Vector2(0, -2), "sway": 4.0, "parallax": 0.9, "near_light": true},
	],
	"husheye": [
		{"kind": "mote", "count": 32, "size": 1.6, "color": Color("06050a"), "alpha": 0.6, "drift": Vector2(3, -2), "sway": 5.0, "parallax": 0.9, "near_light": true},
		{"kind": "mote", "count": 12, "size": 1.0, "color": Color("b8b2dc"), "alpha": 0.26, "drift": Vector2(14, -2), "sway": 6.0, "parallax": 0.6, "near_light": false},
	],
}

# The path always shows (spec §3.7.1, decisions: W6 lips 0.30): every
# walkable lip and spike tip, faint silver above the dark. Not here: the lake's
# crest (level_features.gd draws it live at 0.35 on its real line, +8 deep and
# +13 in a wade, in the theme's "crest"; a static one would float over a
# wade's) and the reeds' veins (features/orchard.gd draws them live at 0.35
# in the theme's "vine_vein" / "rot_vein", so a snapped rotten reed goes dark
# the moment it goes: edge_lines' static vein would still show it).
const EDGES := {
	"stillshore": [{"what": "lip", "color": Color("b8b8e0"), "alpha": 0.30}, {"what": "spike", "color": Color("c8c8f0"), "alpha": 0.32}],
	"drownbell": [{"what": "lip", "color": Color("b8b4dc"), "alpha": 0.30}, {"what": "spike", "color": Color("c8c4ec"), "alpha": 0.32}],
	"hushquiet": [{"what": "lip", "color": Color("bcbce8"), "alpha": 0.32}, {"what": "spike", "color": Color("ccccf4"), "alpha": 0.34}],
	"husheye": [{"what": "lip", "color": Color("bcb8e4"), "alpha": 0.30}, {"what": "spike", "color": Color("ccc8f4"), "alpha": 0.32}],
}
