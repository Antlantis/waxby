extends RefCounted
## World 4, the Frozen Carillon (A1): its four themes, merged by themes/loader.gd.
##   clockface  4-1 The Rime Stair      the great clock face from behind, louvres, icicle curtains
##   gearworks  4-2 The Escapement      still gear silhouettes, girders and belts, chains and hooks
##   icebells   4-3 The Hall of Weights frozen bells in rows, ice-sheathed beams, dense icicles
##   escapement 4-4 The Hour Chamber    the escapement wheel and a still pendulum, stopped clocks
## Painter scripts/tiles/frost.gd, style scripts/backdrops/clockwork.gd. The
## palettes and contrast figures are p_artaudio.md 4.2's (2.06 / 2.62 / 8.23,
## 1.82 / 2.16 / 5.60, 2.53 / 3.26 / 10.14, 1.86 / 2.27 / 5.73; test_world_art.gd
## checks them). The most readable world: cold blue dark, warm pools.
## The tell accent (frost e8fcff) is each palette's "frost", for the features'
## tells (the icicle's glint); decoration keeps at least 0.10 off it in RGB
## (the draft's f0fcff glass, ice gloss, lips and frost specks are d4ecf8,
## d2e8f6 or d8e8f8 here, the drips and rime greyer, snow and glints
## grey-blue; test_world_art.gd holds 0.08 for every palette key, literal
## and prop colour but the tells').
## Keys past the contract (read once W0 and WL4 wire them):
##   "props"  the themed props (art/props/<name>.svg) for the World's altar,
##            bell, sconce, lantern posts (frost lamps) and the arena seal
##   "water", "water_deep"

const _PROPS := {"altar": "altar_frost", "altar_lit": "altar_frost_lit", "bell": "bell_frost", "bell_beam": "bell_frost_beam",
		"sconce": "sconce_brass", "lantern_lit": "brass_lamp_lit", "lantern_out": "brass_lamp_out",
		"seal_open": "clock_door_open", "seal_closed": "clock_door_closed"}

const THEMES := {
	"clockface": {"variant": "clockface", "style": "clockwork", "painter": "frost",
			"sky": Color("0a0e1a"), "far": Color("141c30"), "mid": Color("1e2a44"), "near": Color("0e1528"),
			"glass": [Color("f4f0e0"), Color("bfe4f4"), Color("f0d080")], "banner": Color("3a4a7a"),
			"dark_color": Color(0.20, 0.25, 0.40), "water": Color("2a4a66"), "water_deep": Color("1a3048"), "props": _PROPS},
	"gearworks": {"variant": "gearworks", "style": "clockwork", "painter": "frost",
			"sky": Color("0c0c14"), "far": Color("17172a"), "mid": Color("212138"), "near": Color("111120"),
			"glass": [Color("f0d080"), Color("c8983a")], "banner": Color("4a3a2a"),
			"dark_color": Color(0.24, 0.24, 0.36), "water": Color("283a58"), "water_deep": Color("18263e"), "props": _PROPS},
	"icebells": {"variant": "icebells", "style": "clockwork", "painter": "frost",
			"sky": Color("0a1020"), "far": Color("132038"), "mid": Color("1c2c4a"), "near": Color("0d162c"),
			"glass": [Color("bfe4f4"), Color("8aa0e0"), Color("d8e8f8")], "banner": Color("2a3a6a"),
			"dark_color": Color(0.18, 0.26, 0.44), "water": Color("2a4a6a"), "water_deep": Color("1a304c"), "props": _PROPS},
	"escapement": {"variant": "escapement", "style": "clockwork", "painter": "frost",
			"sky": Color("100c14"), "far": Color("1c1726"), "mid": Color("282036"), "near": Color("130e1a"),
			"glass": [Color("f0d080"), Color("f4f0e0"), Color("bfe4f4")], "banner": Color("5a3a2a"),
			"dark_color": Color(0.28, 0.24, 0.36), "water": Color("2c3a58"), "water_deep": Color("1c263e"), "props": _PROPS},
}

# The painter's keys: the contract's with brick = the ice block with a gear
# frozen in it [face, shade, lip], slab = thin ice [ice, lit top], drip = the
# icicle teeth, plus the carillon's (p_artaudio 4.2): ice, brass, iron, frost
# (the tell), rime, belt.
const PALETTES := {
	"clockface": {"stone": Color("4a5a78"), "shade": Color("3a4862"), "lip": Color("a8c8e8"), "mortar": Color("34425c"),
			"buried": Color("222c40"), "buried_mortar": Color("1c2436"),
			"brick": Color("8ab0cc"), "brick_shade": Color("6a90b0"), "brick_lip": Color("d0ecfa"),
			"slab": Color("bfe4f4"), "slab_lip": Color("d4ecf8"), "drip": Color("c8e2f2"),
			"ice": Color("bfe4f4"), "ice_sh": Color("7ab0d0"), "ice_hi": Color("d4ecf8"), "ice_line": Color("1c3a52"),
			"brass": Color("c8983a"), "brass_sh": Color("8a6424"), "brass_hi": Color("f0d080"), "brass_line": Color("3a2408"),
			"iron": Color("3a3a48"), "frost": Color("e8fcff"), "rime": Color("d4e6f2"), "belt": Color("2e2e3a"), "wax": false},
	"gearworks": {"stone": Color("4a4a5e"), "shade": Color("3a3a4a"), "lip": Color("a89a6c"), "mortar": Color("34344a"),
			"buried": Color("22222e"), "buried_mortar": Color("1b1b26"),
			"brick": Color("7a90a8"), "brick_shade": Color("5a7088"), "brick_lip": Color("b8d0e4"),
			"slab": Color("bcd8ec"), "slab_lip": Color("d2e8f6"), "drip": Color("b8d8ec"),
			"ice": Color("bcd8ec"), "ice_sh": Color("78a4c4"), "ice_hi": Color("d2e8f6"), "ice_line": Color("1c3448"),
			"brass": Color("c8983a"), "brass_sh": Color("8a6424"), "brass_hi": Color("f0d080"), "brass_line": Color("3a2408"),
			"iron": Color("3a3a48"), "frost": Color("e8fcff"), "rime": Color("d8e6f0"), "belt": Color("2c2a34"), "wax": false},
	"icebells": {"stone": Color("566a88"), "shade": Color("44566e"), "lip": Color("c4e0f2"), "mortar": Color("3c4c66"),
			"buried": Color("26324a"), "buried_mortar": Color("1f293e"),
			"brick": Color("9ac0da"), "brick_shade": Color("7aa0bc"), "brick_lip": Color("cce6f6"),
			"slab": Color("c8ecf8"), "slab_lip": Color("d4ecfa"), "drip": Color("cce6f4"),
			"ice": Color("c4e8f6"), "ice_sh": Color("80b4d4"), "ice_hi": Color("d4ecfa"), "ice_line": Color("1c3a56"),
			"brass": Color("c8983a"), "brass_sh": Color("8a6424"), "brass_hi": Color("f0d080"), "brass_line": Color("3a2408"),
			"iron": Color("3a3e4c"), "frost": Color("e8fcff"), "rime": Color("d4e4ee"), "belt": Color("2e3240"), "wax": false},
	"escapement": {"stone": Color("524a62"), "shade": Color("403a4e"), "lip": Color("b09a78"), "mortar": Color("3a3448"),
			"buried": Color("26222e"), "buried_mortar": Color("1e1b26"),
			"brick": Color("8aa0b8"), "brick_shade": Color("6a8098"), "brick_lip": Color("c8dcec"),
			"slab": Color("c0dcec"), "slab_lip": Color("d2e8f6"), "drip": Color("c8e0f0"),
			"ice": Color("c0dcec"), "ice_sh": Color("7ca4c0"), "ice_hi": Color("d2e8f6"), "ice_line": Color("1e3248"),
			"brass": Color("c8983a"), "brass_sh": Color("8a6424"), "brass_hi": Color("f0d080"), "brass_line": Color("3a2408"),
			"iron": Color("3c3848"), "frost": Color("e8fcff"), "rime": Color("dce8f2"), "belt": Color("2e2a36"), "wax": false},
}

# Motes (ambient.gd), and in every W4 theme the frost breath (a puff from
# Waxby's mouth). Snow and glints are grey-blue, off the tell's frost white.
const AMBIENT := {
	"clockface": [
		{"kind": "flake", "count": 40, "size": 1.3, "color": Color("c8d4e4"), "alpha": 0.5, "drift": Vector2(-6, 22),
				"sway": 10.0, "parallax": 0.9, "near_light": false},
		{"kind": "star", "count": 12, "size": 1.2, "color": Color("cfe0ee"), "alpha": 0.55, "drift": Vector2(0, 2),
				"sway": 2.0, "parallax": 0.95, "near_light": true},
		{"kind": "breath", "color": Color("dce6f0"), "alpha": 0.35},
	],
	"gearworks": [
		{"kind": "mote", "count": 20, "size": 1.1, "color": Color("d8b060"), "alpha": 0.38, "drift": Vector2(3, 4),
				"sway": 5.0, "parallax": 0.85, "near_light": true, "floor": 0.2},
		{"kind": "star", "count": 12, "size": 1.2, "color": Color("cfe0ee"), "alpha": 0.5, "drift": Vector2(0, 2),
				"sway": 2.0, "parallax": 0.95, "near_light": true},
		{"kind": "breath", "color": Color("dce6f0"), "alpha": 0.35},
	],
	"icebells": [
		{"kind": "flake", "count": 56, "size": 1.3, "color": Color("c8d4e4"), "alpha": 0.5, "drift": Vector2(-8, 26),
				"sway": 12.0, "parallax": 0.9, "near_light": false},
		{"kind": "breath", "color": Color("dce6f0"), "alpha": 0.35},
	],
	"escapement": [
		{"kind": "flake", "count": 24, "size": 1.3, "color": Color("c8d4e4"), "alpha": 0.45, "drift": Vector2(-5, 20),
				"sway": 10.0, "parallax": 0.9, "near_light": false},
		{"kind": "star", "count": 16, "size": 1.2, "color": Color("d8d0b0"), "alpha": 0.5, "drift": Vector2(0, 2),
				"sway": 2.0, "parallax": 0.95, "near_light": true},
		{"kind": "breath", "color": Color("dce6f0"), "alpha": 0.35},
	],
}

# Readability lines above the dark (edge_lines.gd): the ice's tops (where the
# slide starts shows in the dark), at the phone's 0.30 (decisions.md's W6
# lips), and the icicle spikes' tips.
const EDGES := {
	"clockface": [{"what": "ice", "color": Color("bfe4f4"), "alpha": 0.30, "width": 1.5},
			{"what": "spike", "color": Color("c8e4f4"), "alpha": 0.32}],
	"gearworks": [{"what": "ice", "color": Color("bcd8ec"), "alpha": 0.30, "width": 1.5},
			{"what": "spike", "color": Color("c8e4f4"), "alpha": 0.32}],
	"icebells": [{"what": "ice", "color": Color("c4e8f6"), "alpha": 0.30, "width": 1.5},
			{"what": "spike", "color": Color("c8e4f4"), "alpha": 0.32}],
	"escapement": [{"what": "ice", "color": Color("c0dcec"), "alpha": 0.30, "width": 1.5},
			{"what": "spike", "color": Color("c8e4f4"), "alpha": 0.32}],
}
