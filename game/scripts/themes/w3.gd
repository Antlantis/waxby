extends RefCounted
## World 3, the Bone Orchard (A1): its four themes, merged by themes/loader.gd.
##   orchard   3-1 The Bramble Gate      bone trees, an ossuary wall, hanging roots
##   rootvault 3-2 The Hanging Ossuary   root-choked vaults, coffins end-on, root pillars
##   sporewood 3-3 The Sporewood         the darkest: giant caps, stalks, hanging moss
##   rootheart 3-4 The Heartwood         the heart-knot round a buried bell, ribs of root
## Painter scripts/tiles/orchard.gd, style scripts/backdrops/orchard.gd. The
## palettes and the contrast figures are p_artaudio.md 4.1's (stone/mid,
## stone/near, lip/mid: 2.01 / 2.45 / 4.91, 1.81 / 2.15 / 4.38,
## 1.78 / 2.16 / 4.35, 1.87 / 2.24 / 4.28; test_world_art.gd checks them).
## The tell accent (spore chartreuse c8d46a) is in each palette as "spore"
## for the features' tells, and nowhere else: the draft's chartreuse moon
## tint, window glass and ambient spores are pale bone-gold or mint here.
## Keys past the contract (the World and the features read them once W0 and
## WL3 wire them; unwired, v2's look stands):
##   "props"  the themed props (art/props/<name>.svg) for the World's altar,
##            bell, sconce, lantern posts and the arena seal
##   "water", "water_deep"   the bog and the black sap (level_features.gd)

const THEMES := {
	"orchard": {"variant": "orchard", "style": "orchard", "painter": "orchard",
			"sky": Color("0e0d0a"), "far": Color("1a1914"), "mid": Color("26241c"), "near": Color("12110c"),
			"glass": [Color("d8d0a0"), Color("e8a0b0"), Color("f4e8c8")], "banner": Color("5a3a52"),
			"dark_color": Color(0.24, 0.25, 0.18), "moon": Color("e8dcb0"),
			"water": Color("24301c"), "water_deep": Color("1a2414"),
			"props": {"altar": "altar_orchard", "altar_lit": "altar_orchard_lit", "bell": "bell_orchard",
					"bell_beam": "bell_orchard_beam", "sconce": "sconce_bone", "lantern_lit": "skull_lantern_lit",
					"lantern_out": "skull_lantern_out", "seal_open": "root_seal_open", "seal_closed": "root_seal_closed"}},
	"rootvault": {"variant": "rootvault", "style": "orchard", "painter": "orchard",
			"sky": Color("0b0c0e"), "far": Color("16171c"), "mid": Color("202229"), "near": Color("101115"),
			"glass": [Color("d8c8a0"), Color("a8c0a0")], "banner": Color("3a3a44"),
			"dark_color": Color(0.20, 0.22, 0.22), "moon": Color("c8ccd8"),
			"water": Color("20281c"), "water_deep": Color("161c12"),
			"props": {"altar": "altar_orchard", "altar_lit": "altar_orchard_lit", "bell": "bell_orchard",
					"bell_beam": "bell_orchard_beam", "sconce": "sconce_bone", "lantern_lit": "skull_lantern_lit",
					"lantern_out": "skull_lantern_out", "seal_open": "root_seal_open", "seal_closed": "root_seal_closed"}},
	"sporewood": {"variant": "sporewood", "style": "orchard", "painter": "orchard",
			"sky": Color("0b0d08"), "far": Color("151a10"), "mid": Color("1f2618"), "near": Color("0e120a"),
			"glass": [Color("a8e0b0"), Color("e0d8a8"), Color("b8d8c0")], "banner": Color("3a4a2a"),
			"dark_color": Color(0.17, 0.20, 0.13), "moon": Color("c8dcc0"),
			"water": Color("1c2616"), "water_deep": Color("12180e"),
			"props": {"altar": "altar_orchard", "altar_lit": "altar_orchard_lit", "bell": "bell_orchard",
					"bell_beam": "bell_orchard_beam", "sconce": "sconce_bone", "lantern_lit": "skull_lantern_lit",
					"lantern_out": "skull_lantern_out", "seal_open": "root_seal_open", "seal_closed": "root_seal_closed"}},
	"rootheart": {"variant": "rootheart", "style": "orchard", "painter": "orchard",
			"sky": Color("120b0b"), "far": Color("20151a"), "mid": Color("2c1e24"), "near": Color("160d10"),
			"glass": [Color("f2b84b"), Color("e8a0b0")], "banner": Color("6a2e3a"),
			"dark_color": Color(0.28, 0.20, 0.20), "moon": Color("f0c8a0"),
			"water": Color("2a1a18"), "water_deep": Color("1c1010"),
			"props": {"altar": "altar_orchard", "altar_lit": "altar_orchard_lit", "bell": "bell_orchard",
					"bell_beam": "bell_orchard_beam", "sconce": "sconce_bone", "lantern_lit": "skull_lantern_lit",
					"lantern_out": "skull_lantern_out", "seal_open": "root_seal_open", "seal_closed": "root_seal_closed"}},
}

# The painter's keys: the contract's (stone, shade, lip, mortar, buried, brick,
# slab, drip) with brick = coffin wood [face, shade, lip] and slab = the bone
# trellis [bone, lit top], plus the orchard keys (p_artaudio 4.1): bone, root,
# leaf, vein, thorn, spore (the tell), bark (ledges), rot (rotten vines, grey).
const PALETTES := {
	"orchard": {"stone": Color("5a5242"), "shade": Color("463f32"), "lip": Color("9c9070"), "mortar": Color("3e382c"),
			"buried": Color("2a261c"), "buried_mortar": Color("221f17"),
			"brick": Color("6a4a36"), "brick_shade": Color("50362a"), "brick_lip": Color("8e6a4c"),
			"slab": Color("d8cca8"), "slab_lip": Color("f0e6c8"), "drip": Color("6e8a44"),
			"bone": Color("e6dcc0"), "bone_sh": Color("b8ab8a"), "root": Color("4a3526"), "root_hi": Color("6e4e36"),
			"leaf": Color("6e8a44"), "leaf_hi": Color("9ab86a"), "vein": Color("9ad07a"), "thorn": Color("5a3a2a"),
			"spore": Color("c8d46a"), "spore_hi": Color("e8f08a"), "bark": Color("5e4230"), "bark_lip": Color("9c8058"),
			"rot": Color("8a8478"), "rot_hi": Color("b0aa9c"), "wax": false},
	"rootvault": {"stone": Color("4e4a46"), "shade": Color("3c3936"), "lip": Color("8c8676"), "mortar": Color("363330"),
			"buried": Color("24221f"), "buried_mortar": Color("1d1b19"),
			"brick": Color("5a4636"), "brick_shade": Color("443428"), "brick_lip": Color("7e624a"),
			"slab": Color("ccc4a8"), "slab_lip": Color("e8e0c8"), "drip": Color("5e7a40"),
			"bone": Color("e6dcc0"), "bone_sh": Color("b8ab8a"), "root": Color("4a3526"), "root_hi": Color("6e4e36"),
			"leaf": Color("5e7a40"), "leaf_hi": Color("8aa860"), "vein": Color("9ad07a"), "thorn": Color("5a3a2a"),
			"spore": Color("c8d46a"), "spore_hi": Color("e8f08a"), "bark": Color("54402e"), "bark_lip": Color("8e7454"),
			"rot": Color("8a8478"), "rot_hi": Color("b0aa9c"), "wax": false},
	"sporewood": {"stone": Color("4c4c3a"), "shade": Color("3a3a2c"), "lip": Color("8a8a5c"), "mortar": Color("34342a"),
			"buried": Color("22221a"), "buried_mortar": Color("1b1b14"),
			"brick": Color("5a4a34"), "brick_shade": Color("443828"), "brick_lip": Color("806a4a"),
			"slab": Color("d8d8a0"), "slab_lip": Color("f0f0c8"), "drip": Color("8aa050"),
			"bone": Color("e2dcc0"), "bone_sh": Color("b4ac8a"), "root": Color("4a3a26"), "root_hi": Color("6e5636"),
			"leaf": Color("7a9448"), "leaf_hi": Color("a4c070"), "vein": Color("9ad07a"), "thorn": Color("54402a"),
			"spore": Color("c8d46a"), "spore_hi": Color("e8f08a"), "bark": Color("56462e"), "bark_lip": Color("908056"),
			"rot": Color("8a8a78"), "rot_hi": Color("b2b09c"), "wax": false},
	"rootheart": {"stone": Color("5c4842"), "shade": Color("483632"), "lip": Color("9e7e68"), "mortar": Color("3e302c"),
			"buried": Color("2a1e1c"), "buried_mortar": Color("221816"),
			"brick": Color("6a3e30"), "brick_shade": Color("502e24"), "brick_lip": Color("8e5a46"),
			"slab": Color("e0c8b8"), "slab_lip": Color("f4e4d8"), "drip": Color("7a8a4a"),
			"bone": Color("ecdcc8"), "bone_sh": Color("bea894"), "root": Color("5a2e2a"), "root_hi": Color("7e4a40"),
			"leaf": Color("7a8a4a"), "leaf_hi": Color("a0b070"), "vein": Color("9ad07a"), "thorn": Color("5a2e26"),
			"spore": Color("c8d46a"), "spore_hi": Color("e8f08a"), "bark": Color("5a3830"), "bark_lip": Color("9a7060"),
			"rot": Color("8e8078"), "rot_hi": Color("b4a69c"), "wax": false},
}

# Motes (ambient.gd). The "spores" drifting here are decoration: pale
# bone-gold, never the chartreuse of a real cloud; near the candle they turn
# gold (near_light). They hang and settle (a slow fall with a sway), never
# rise: in 3-3 the one stream of spores going UP is the secret's updraft
# (spec 3.9, "These spores rise. Where to?"; the orchard feature draws it),
# so it must be the only one. Counts share ambient's 64-mote cap.
const AMBIENT := {
	"orchard": [
		{"kind": "spore", "count": 36, "size": 1.1, "color": Color("e0d4a0"), "alpha": 0.40, "drift": Vector2(4, 4),
				"sway": 9.0, "parallax": 0.85, "near_light": true, "floor": 0.30},
		{"kind": "petal", "count": 12, "size": 2.0, "color": Color("e8a0b0"), "alpha": 0.55, "drift": Vector2(7, 16),
				"sway": 14.0, "parallax": 0.95, "near_light": true, "floor": 0.35},
	],
	"rootvault": [
		{"kind": "mote", "count": 24, "size": 1.0, "color": Color("c8c4b4"), "alpha": 0.32, "drift": Vector2(2, 5),
				"sway": 5.0, "parallax": 0.8, "near_light": true, "floor": 0.25},
		{"kind": "petal", "count": 8, "size": 2.0, "color": Color("e0a8b4"), "alpha": 0.5, "drift": Vector2(5, 14),
				"sway": 12.0, "parallax": 0.95, "near_light": true, "floor": 0.3},
	],
	"sporewood": [
		{"kind": "spore", "count": 56, "size": 1.1, "color": Color("d8d0a8"), "alpha": 0.36, "drift": Vector2(-3, 3),
				"sway": 11.0, "parallax": 0.85, "near_light": true, "floor": 0.28},
	],
	"rootheart": [
		{"kind": "petal", "count": 40, "size": 2.1, "color": Color("e8a0b0"), "alpha": 0.55, "drift": Vector2(6, 15),
				"sway": 14.0, "parallax": 0.95, "near_light": true, "floor": 0.32},
		{"kind": "spore", "count": 16, "size": 1.1, "color": Color("e8d0a8"), "alpha": 0.36, "drift": Vector2(3, 4),
				"sway": 9.0, "parallax": 0.85, "near_light": true, "floor": 0.28},
	],
}

# Readability lines above the dark (edge_lines.gd). The vines' veins are the
# orchard feature's (features/orchard.gd draws them each frame, so a snapped
# rotten run's vein goes with it); here the bramble tips, bone-white, so a
# thorn bed reads in the dark. edge_lines leaves a fallen crumble unlined
# (the wave-2 merge: W0-render's ledge_present check), so the Sporewood, the
# darkest theme, takes a lip line on every walkable top and the Hanging
# Ossuary a shelf line on its one-way ledges (A1's values).
const EDGES := {
	"orchard": [{"what": "spike", "color": Color("efe6cc"), "alpha": 0.32}],
	"rootvault": [{"what": "spike", "color": Color("efe6cc"), "alpha": 0.32},
			{"what": "ledge", "color": Color("c8b890"), "alpha": 0.16}],
	"sporewood": [{"what": "spike", "color": Color("efe6cc"), "alpha": 0.34},
			{"what": "lip", "color": Color("b4c490"), "alpha": 0.22}],
	"rootheart": [{"what": "spike", "color": Color("f4e0cc"), "alpha": 0.32}],
}
