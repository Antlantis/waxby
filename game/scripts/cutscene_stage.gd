extends RefCounted
## The cutscene's stand-in stage, used wherever art/story/panels.json (or one
## of its textures) is missing: every panel's size, darkness, lights and
## anchors as spec §7.4 lays them out, with simple layered shapes to draw
## instead of the SVG layers; figures as flat silhouettes; portraits as
## little flat faces. Static; cutscene.gd calls it. Everything is drawn in the
## thing's own units (panel units, a figure's 256 frame, a portrait's 128
## frame): the caller sets the transform.
##
## v3: the story draft's ten new panels, fifteen figures and seventeen
## portraits (spec §6.6), with the anchors, lights and flames the script
## names, and the manifest-only additions (undercandle's grasp and
## under_warm, hush_eye's float and its figure's pupil). They draw through a
## TriBatch (a layer marked "tb", a figure or face in NEW_LOOKS / NEW_FACES):
## one draw call each, no draw_circle or draw_colored_polygon. v2's stand-ins
## are kept as they were. A light or flame marked "off" starts every shot
## dark until a cue lights it.

const TriBatch := preload("res://scripts/tri_batch.gd")
const INK := Color("120d1a")

# As panels.json has them, in the 256 frame: flames {name: [x, y, h]} (a
# flame's base and height), and light {name: {kind, color, pts, dot}} for the
# eye-lights (their two pupils, and how big).
const FIGURES := {
	"novice_back":    {"h": 120.0, "look": "novice", "flames": {}},
	"taper_stand":    {"h": 112.0, "look": "taper", "flames": {"head": [126, 58, 7], "lantern": [196, 112, 6]}},
	"taper_chair":    {"h": 128.0, "look": "taper_chair", "flames": {"head": [118, 62, 7]}},
	"tollgrave_boss": {"h": 340.0, "look": "tollgrave", "flames": {"eyes": [128, 96, 5]},
		"light": {"eyes": {"kind": "eyes", "color": "7ef0c8", "pts": [[115, 96], [141, 96]], "dot": 3.0}}},
	"tollgrave_sit":  {"h": 250.0, "look": "tollgrave_sit", "flames": {"eyes": [112, 128, 4]},
		"light": {"eyes": {"kind": "eyes", "color": "f7b64a", "pts": [[99, 128], [125, 128]], "dot": 2.5}}},
	"snuffer_stand":  {"h": 300.0, "look": "snuffer", "flames": {"eyes": [120, 92, 3]},
		"light": {"eyes": {"kind": "eyes", "color": "e8e4ff", "pts": [[112, 92], [128, 92]], "dot": 1.5}}},
	"snuffer_reach":  {"h": 300.0, "look": "snuffer_reach", "flames": {"eyes": [120, 92, 3]},
		"light": {"eyes": {"kind": "eyes", "color": "e8e4ff", "pts": [[112, 92], [128, 92]], "dot": 1.5}}},
	"cone_broken":    {"h": 200.0, "look": "cone_broken", "flames": {}},
	"hollin_cold":    {"h": 120.0, "look": "hollin_cold", "flames": {}},
	"hollin_warm":    {"h": 120.0, "look": "hollin_warm", "flames": {"head": [128, 44, 7]}},
	# The candles on his hat's brim (v3's finale lights them one by one).
	"waxley_pack":    {"h": 200.0, "look": "waxley", "flames": {"brim1": [66, 70, 8], "brim2": [93, 66, 8], "brim3": [120, 64, 8],
		"brim4": [147, 66, 8], "brim5": [174, 70, 8]}},
	# v3: the stolen flame glints in its pupil (dark until a cue lights it).
	"hush_eye":       {"h": 600.0, "look": "eye", "feet": [128, 128], "flames": {"pupil": [128, 128, 10]},
		"light": {"pupil": {"kind": "flame", "color": "ffd84a", "r": 80, "s": 0.6, "off": true}}},
	# ---- v3 (the story draft §4.3; boss figures after the fight art)
	"hush_grasp":     {"h": 560.0, "look": "hush_grasp", "flames": {"stolen": [128, 74, 22]},
		"light": {"stolen": {"kind": "flame", "color": "ffd070", "r": 300, "s": 1.0, "off": true}}},
	"rootmother_boss": {"h": 400.0, "look": "rootmother", "flames": {"eyes": [128, 70, 3], "ember": [128, 146, 22, "cold"]},
		"light": {"eyes": {"kind": "eyes", "color": "d8f0c0", "pts": [[117, 70], [139, 70]], "dot": 2.6, "r": 90, "s": 0.6},
			"ember": {"kind": "cold", "color": "a8d0ff", "r": 140, "s": 0.8}}},
	"rootmother_open": {"h": 400.0, "look": "rootmother_open", "flames": {"eyes": [128, 70, 3], "ember": [128, 120, 22]},
		"light": {"eyes": {"kind": "eyes", "color": "f7d88a", "pts": [[117, 70], [139, 70]], "dot": 2.6, "r": 90, "s": 0.6},
			"ember": {"kind": "flame", "r": 160, "s": 0.9}}},
	"yarrow_spirit":  {"h": 110.0, "look": "yarrow", "flames": {"head": [128, 40, 16], "aura": [128, 150, 0, "glow"]},
		"light": {"head": {"kind": "flame", "r": 110, "s": 0.9, "off": true}, "aura": {"kind": "glow", "color": "d8e8a0", "r": 120, "s": 0.5}}},
	"tinker_boss":    {"h": 400.0, "look": "tinker", "flames": {"eyes": [118, 74, 3], "heart": [182, 98, 14, "cold"]},
		"light": {"eyes": {"kind": "eyes", "color": "bfe8ff", "pts": [[106, 74], [130, 74]], "dot": 2.4, "r": 90, "s": 0.6},
			"heart": {"kind": "cold", "color": "bfe8ff", "r": 100, "s": 0.7}}},
	"tickwell":       {"h": 84.0, "look": "tickwell", "flames": {"watch": [156, 146, 12]},
		"light": {"watch": {"kind": "flame", "r": 100, "s": 0.85}}},
	"cone_bell":      {"h": 70.0, "look": "cone_bell", "flames": {"rim": [128, 196, 0, "glow"]},
		"light": {"rim": {"kind": "glow", "color": "ffd8a0", "r": 80, "s": 0.3}}},
	"saint_boss":     {"h": 400.0, "look": "saint", "flames": {"eyes": [128, 62, 3], "halo": [128, 52, 0, "glow"], "prism": [128, 138, 0, "glow"]},
		"light": {"eyes": {"kind": "eyes", "color": "f8f4ff", "pts": [[117, 62], [139, 62]], "dot": 2.2, "r": 80, "s": 0.5},
			"halo": {"kind": "glow", "color": "f0f4ff", "r": 260, "s": 0.6}, "prism": {"kind": "glow", "color": "e8f0ff", "r": 80, "s": 0.7}}},
	"tessel_lit":     {"h": 400.0, "look": "tessel", "flames": {"heart": [128, 128, 26], "eyes": [128, 62, 3]},
		"light": {"heart": {"kind": "flame", "r": 160, "s": 0.9, "off": true},
			"eyes": {"kind": "eyes", "color": "ffd8a0", "pts": [[117, 62], [139, 62]], "dot": 2.2, "r": 80, "s": 0.5}}},
	"stolen_wick":    {"h": 60.0, "look": "stolen_wick", "flames": {"wick": [128, 96, 60]},
		"light": {"wick": {"kind": "flame", "r": 900, "s": 1.0, "off": true}}},
	"hollin_carry":   {"h": 130.0, "look": "hollin_carry", "flames": {"hollin": [118, 52, 22], "taper": [178, 28, 8]},
		"light": {"hollin": {"kind": "flame", "r": 200, "s": 0.95}, "taper": {"kind": "flame", "r": 90, "s": 0.8}}},
	"tollgrave_stand": {"h": 200.0, "look": "tollgrave_stand", "flames": {"eyes": [118, 78, 3], "lantern": [200, 58, 14]},
		"light": {"eyes": {"kind": "eyes", "color": "f7b64a", "pts": [[108, 78], [128, 78]], "dot": 2.6, "r": 90, "s": 0.6},
			"lantern": {"kind": "flame", "r": 150, "s": 0.9}}},
	"townsfolk_line": {"h": 110.0, "look": "townsfolk", "flames": {"lamp1": [22, 150, 7], "lamp2": [52, 146, 7], "lamp3": [84, 150, 7],
		"lamp4": [114, 144, 7], "lamp5": [144, 150, 7], "lamp6": [174, 146, 7], "lamp7": [204, 150, 7], "lamp8": [234, 144, 7]}},
	"deep_candle":    {"h": 50.0, "look": "deep_candle", "flames": {"wick": [128, 112, 40]},
		"light": {"wick": {"kind": "flame", "r": 420, "s": 0.9, "off": true}}},
	"lost_wicks":     {"h": 80.0, "look": "lost_wicks", "flames": {"w1": [30, 118, 10], "w2": [70, 110, 10], "w3": [110, 118, 10],
		"w4": [150, 110, 10], "w5": [190, 118, 10], "w6": [230, 110, 10]},
		"light": {"w1": {"kind": "flame", "r": 70, "s": 0.8, "off": true}, "w2": {"kind": "flame", "r": 70, "s": 0.8, "off": true},
			"w3": {"kind": "flame", "r": 70, "s": 0.8, "off": true}, "w4": {"kind": "flame", "r": 70, "s": 0.8, "off": true},
			"w5": {"kind": "flame", "r": 70, "s": 0.8, "off": true}, "w6": {"kind": "flame", "r": 70, "s": 0.8, "off": true}}},
}
# The v3 looks (drawn through a TriBatch).
const NEW_LOOKS := ["hush_grasp", "rootmother", "rootmother_open", "yarrow", "tinker", "tickwell", "cone_bell", "saint", "tessel",
	"stolen_wick", "hollin_carry", "tollgrave_stand", "townsfolk", "deep_candle", "lost_wicks"]

# Portrait flames in the 128 frame (the face sits near (64, 62)).
const PORTRAIT_FLAMES := {"taper": [64, 14, 6]}
# v3: every stand-in face's live flame by speaker (and by mood, for Hollin's
# helm candle, lit once he's himself again). portrait_flame() reads them.
const FACE_FLAMES := {"taper": [64, 14, 6], "yarrow": [64, 12, 5], "echo": [64, 22, 5]}
const HOLLIN_LIT := ["relit", "worried", "grin"]
# The v3 faces (drawn through a TriBatch).
const NEW_FACES := ["rootmother", "yarrow", "tinker", "tickwell", "saint", "tessel", "hush", "echo"]

const LAMPS := [[110, 300, 90], [250, 236, 80], [390, 318, 100], [530, 250, 76], [680, 304, 96],
	[820, 222, 72], [960, 312, 100], [1100, 244, 84]]


static func _lamps() -> Dictionary:
	var out := {}
	for i in LAMPS.size():
		out["lamp%d" % (i + 1)] = {"p": [LAMPS[i][0], LAMPS[i][1]], "r": LAMPS[i][2], "s": 0.9, "kind": "flame", "h": 9}
	return out


static func _row(prefix: String, pts: Array, r: float, h: float, s := 0.85, kind := "flame") -> Dictionary:
	var out := {}
	for i in pts.size():
		out["%s%d" % [prefix, i + 1]] = {"p": pts[i], "r": r, "s": s, "kind": kind, "h": h}
	return out


static func panel(id: String) -> Dictionary:
	## The stand-in for one panel, in panels.json's shape (plus "shapes" per
	## layer). {} for an unknown id.
	match id:
		"glass_legend":
			return {"size": [2400, 460], "dark": null, "motes": "dust", "shimmer": true, "lights": {}, "anchors": {},
				"layers": [
					{"depth": 1.0, "lit": true, "shapes": [["rect", 0, 0, 2400, 460, "1a1026"], ["bricks", 0, 0, 2400, 460, "221633"],
						["lancet", 400, 426, 440, 356, "pit"], ["lancet", 1200, 426, 440, 356, "bells"], ["lancet", 2000, 426, 440, 356, "sunk"]]},
					{"depth": 1.12, "lit": true, "shapes": [["pillar", 0, 90], ["pillar", 800, 90], ["pillar", 1600, 90], ["pillar", 2400, 90]]},
				]}
		"lanternfold":
			var l := _lamps()
			l["moon"] = {"p": [930, 90], "r": 220, "s": 0.4, "kind": "glow"}
			return {"size": [1200, 460], "dark": [0.22, 0.24, 0.40], "motes": "snow", "lights": l, "anchors": {},
				"layers": [
					{"depth": 0.3, "lit": true, "shapes": [["grad", "141a2e", "2e2646", 0, 460], ["stars", 60, 300, 7],
						["circle", 930, 90, 40, "ece8ff"], ["circle", 918, 82, 9, "d4cff0"], ["circle", 944, 104, 6, "d4cff0"]]},
					{"depth": 0.65, "shapes": [["hills", 300, 40, "2a2646", 3], ["spire", 820, 262, "3a3456"],
						["roofs", 340, -60, 1260, "3a3052", 5, "f7b64a"]]},
					{"depth": 1.0, "shapes": [["rect", -40, 392, 1280, 80, "2a2236"], ["line", -40, 392, 1240, 392, "4a3e58", 4],
						["cobbles", 392, 460, "342a44"], ["posts", LAMPS, 392, "1e1828"], ["cat", 560, 330]]},
				]}
		"chapel":
			# The floor at 302 and Taper's dais at 279, where the art has them.
			var c := _row("lectern", [[274, 183], [292, 178], [310, 183]], 70, 7)
			c["hearth"] = {"p": [860, 272], "r": 190, "s": 1.0, "kind": "flame", "h": 22}
			c["window"] = {"p": [520, 120], "r": 130, "s": 0.45, "kind": "glow"}
			return {"size": [1000, 460], "dark": [0.30, 0.25, 0.42], "motes": "dust", "lights": c,
				"anchors": {"taper": {"p": [334, 279], "depth": 1.0}, "novice": {"p": [615, 302], "depth": 1.0, "h": 120},
					"actor": {"p": [615, 302], "depth": 1.0, "h": 120, "face": -1}, "hollin": {"p": [742, 302], "depth": 1.0}},
				"layers": [
					{"depth": 0.5, "shapes": [["grad", "3e3250", "2a2038", 0, 460], ["bricks", 0, 0, 1000, 302, "34294a"],
						["rosette", 520, 120, 56], ["banner", 150, 30, 74, 150], ["shelf", 640, 200, 150], ["shelf", 40, 230, 90],
						["hearth", 860, 302, 150, 130]]},
					{"depth": 1.0, "shapes": [["rect", -100, 302, 1200, 180, "3a2a2e"], ["line", -100, 302, 1100, 302, "5a4238", 4],
						["rect", 180, 279, 230, 23, "4a3438"], ["line", 180, 279, 410, 279, "5a4238", 3],
						["ellipse", 600, 330, 220, 22, "6a3444"], ["lectern", 292, 279]]},
				]}
		"callings":
			var xs := {"knight": 180, "founder": 340, "witch": 500, "runner": 660, "sexton": 820}
			var cl := {}
			for k in xs:
				cl["plinth_" + k] = {"p": [xs[k], 258], "r": 110, "s": 0.95, "kind": "flame", "h": 12}
			cl["sconce_l"] = {"p": [64, 196], "r": 90, "s": 0.7, "kind": "flame", "h": 10}
			cl["sconce_r"] = {"p": [936, 196], "r": 90, "s": 0.7, "kind": "flame", "h": 10}
			return {"size": [1000, 460], "dark": [0.26, 0.22, 0.38], "motes": "dust", "lights": cl, "anchors": {},
				"layers": [
					{"depth": 0.5, "shapes": [["grad", "32284a", "221a30", 0, 460], ["bricks", 0, 0, 1000, 420, "2c2342"],
						["arches", 180, 820, 5, 330, 112, 236, "1a1428"], ["crest", 500, 118], ["sconce", 64, 210], ["sconce", 936, 210]]},
					{"depth": 1.0, "shapes": [["rect", -100, 420, 1200, 60, "2a2030"], ["line", -100, 420, 1100, 420, "4a3e58", 4],
						["plinth", 180, 320, "helm"], ["plinth", 340, 320, "pot"], ["plinth", 500, 320, "hat"],
						["plinth", 660, 320, "hood"], ["plinth", 820, 320, "stovepipe"]]},
				]}
		"crypt_row":
			var pts := []
			for i in 8:
				var k := i / 7.0
				pts.append([lerpf(150, 540, k), lerpf(330, 250, k)])
			var cr := {}
			for i in 8:
				var k := i / 7.0
				cr["c%d" % (i + 1)] = {"p": pts[i], "r": lerpf(120, 40, k), "s": 0.9, "kind": "flame", "h": lerpf(14, 5, k)}
			return {"size": [1000, 460], "dark": [0.24, 0.30, 0.32], "motes": "dust", "lights": cr,
				"anchors": {"far": {"p": [600, 300], "depth": 1.0, "h": 110}},
				"layers": [
					{"depth": 0.6, "shapes": [["rect", 0, 0, 1000, 460, "141c1e"], ["ribs", 570, 230, 7, "2a3638"]]},
					{"depth": 1.0, "shapes": [["poly", [[-40, 470], [1040, 470], [640, 262], [520, 262]], "202a2c"],
						["poly", [[380, 470], [700, 470], [590, 262], [560, 262]], "283234"], ["stands", pts, 14]]},
				]}
		"belfry":
			var bl := _row("moon", [[250, 250], [500, 240], [750, 250]], 150, 0, 0.45, "glow")
			bl["bell_beam"] = {"p": [520, 118], "r": 200, "s": 0.8, "kind": "glow"}
			return {"size": [1000, 460], "dark": [0.26, 0.28, 0.46], "motes": "dust", "lights": bl,
				"anchors": {"boss": {"p": [520, 432], "depth": 1.0, "h": 340}, "sit": {"p": [570, 432], "depth": 1.0},
					"actor_after": {"p": [360, 432], "depth": 1.0, "h": 120},
					# In the far right window, against the moon (the Snuffer's taunt).
					"sill": {"p": [750, 386], "depth": 0.4, "h": 240, "flip": true}},
				"layers": [
					{"depth": 0.4, "shapes": [["grad", "2c2c48", "1e1e34", 0, 460], ["bricks", 0, 0, 1000, 460, "26263e"],
						["louver", 250, 390, 150, 280], ["louver", 500, 380, 160, 300], ["louver", 750, 390, 150, 280]]},
					{"depth": 0.4, "lit": true, "shapes": [["shaft", 250, 150, 330, 250, "c0c8f0"], ["shaft", 500, 150, 590, 270, "c0c8f0"],
						["shaft", 750, 150, 840, 250, "c0c8f0"]]},
					{"depth": 1.0, "shapes": [["beam", 280, 760, 62, 26, "4a3628"], ["rect", 516, 88, 8, 16, "3a2a20"], ["bell", 520, 100, 40, "8a6a3a"],
						["rect", -100, 432, 1200, 40, "4a3a30"], ["line", -100, 432, 1100, 432, "6a5444", 4], ["planks", 432, 460, "3a2c24"], ["rope", 150, 420]]},
					{"depth": 1.3, "shapes": [["rect", -150, -60, 1300, 96, "16121e"], ["rect", -150, 30, 1300, 8, "2a2230"],
						["rect", 60, 36, 26, 30, "16121e"], ["rect", 900, 36, 26, 30, "16121e"],
						["bat", 190, 38], ["bat", 430, 38], ["bat", 810, 38]]},
				]}
		"tallow_vista":
			var reeds := []
			for i in 12:
				reeds.append([150 + i * 100 + (i % 3) * 14, 300 + (i * 37) % 80])
			var tv := _row("reed", reeds, 60, 6)
			tv["under_far"] = {"p": [700, 380], "r": 80, "s": 0.8, "kind": "glow"}
			tv["moth"] = {"p": [1050, 206], "r": 120, "s": 0.35, "kind": "glow"}
			return {"size": [1400, 460], "dark": [0.32, 0.28, 0.26], "motes": "wax", "lights": tv,
				"anchors": {"edge": {"p": [200, 297], "depth": 1.0, "h": 120}, "actor": {"p": [200, 297], "depth": 1.0, "h": 120},
					"waxley": {"p": [320, 299], "depth": 1.0}},
				"layers": [
					{"depth": 0.3, "shapes": [["grad", "2e241e", "5a4636", 0, 460], ["waxfalls", 1400, 460],
						["rect", 694, 364, 12, 18, "efe6cc"]]},
					{"depth": 0.65, "shapes": [["terraces", 1400, "cdbf9c", "a89878"], ["reeds", reeds], ["moth", 1050, 206]]},
					{"depth": 1.0, "shapes": [["poly", [[-140, 470], [-140, 297], [390, 299], [430, 330], [470, 470]], "6a5a48"],
						["line", -140, 297, 390, 299, "8a7a62", 4],
						["poly", [[1200, 470], [1260, 400], [1540, 380], [1540, 470]], "5a4a3a"]]},
				]}
		"undercandle":
			# The ring floor at 500, where the art has it.
			var reeds := [[150, 440], [260, 458], [740, 458], [850, 440]]
			var ul := _row("reed", reeds, 70, 7)
			ul["under_flame"] = {"p": [500, 70], "r": 700, "s": 1.0, "kind": "cold", "h": 60}
			# v3 (the manifest-only additions): its warm self, dark until the_pull.
			ul["under_warm"] = {"p": [500, 58], "r": 700, "s": 1.0, "kind": "flame", "h": 60, "depth": 0.8, "color": "ffd070", "off": true}
			return {"size": [1000, 600], "dark": [0.20, 0.18, 0.30], "motes": "dust", "lights": ul,
				"anchors": {"boss": {"p": [650, 500], "depth": 1.0, "h": 330}, "cone": {"p": [640, 500], "depth": 1.0},
					"hollin": {"p": [575, 500], "depth": 1.0}, "actor_near": {"p": [430, 500], "depth": 1.0, "h": 120},
					# Drawn tall, so its grip reaches the wick with its roots still under the floor.
					"grasp": {"p": [500, 563], "depth": 0.85, "h": 760}},
				"layers": [
					{"depth": 0.4, "shapes": [["grad", "1a1628", "241e36", 0, 600], ["rings", 500, 600, "2e2846"]]},
					{"depth": 0.8, "shapes": [["bigcandle", 380, 620, 80, 500], ["swirl", 500, 490, 150, "4a3a7a"]]},
					{"depth": 1.0, "shapes": [["rect", -100, 500, 1200, 120, "2a2436"], ["line", -100, 500, 1100, 500, "443c58", 4],
						["bell", 190, 468, 30, "7a5a34"], ["bell", 840, 476, 24, "7a5a34"], ["reeds", reeds]]},
				]}
		"bells_all":
			var bp := [[330, 980], [670, 960], [330, 720], [670, 700], [330, 460], [670, 440], [330, 200], [670, 180]]
			var ba := _row("bell", bp, 140, 0, 0.9, "glow")
			ba["under_flame"] = {"p": [500, 1046], "r": 300, "s": 1.0, "kind": "flame", "h": 30}
			return {"size": [1000, 1100], "dark": [0.28, 0.24, 0.40], "motes": "embers", "lights": ba, "anchors": {},
				"layers": [
					{"depth": 1.0, "shapes": [["rect", 0, 0, 1000, 1100, "2a2238"], ["bricks", 90, 0, 820, 1100, "30283f"],
						["rect", 0, 0, 90, 1100, "3a3050"], ["rect", 910, 0, 90, 1100, "3a3050"],
						["rect", 90, 270, 820, 22, "4a3a30"], ["rect", 90, 530, 820, 22, "4a3a30"], ["rect", 90, 790, 820, 22, "4a3a30"],
						["bells", bp], ["choir", [[460, 270], [540, 270], [470, 530], [530, 530], [480, 790], [520, 790]]],
						["rect", 480, 1030, 40, 70, "efe6cc"]]},
					{"depth": 1.0, "lit": true, "shapes": [["shaft", 500, 60, 500, 360, "ffd84a"]]},
				]}
		"dawn_rise":
			var dl := _lamps()
			dl["sun"] = {"p": [600, 440], "r": 400, "s": 0.6, "kind": "glow"}
			return {"size": [1200, 460], "dark": [0.46, 0.36, 0.52], "motes": "embers", "lights": dl, "anchors": {},
				"layers": [
					{"depth": 0.25, "shapes": [["grad", "a8c4e4", "ffd9a0", 0, 280], ["grad", "ffd9a0", "f2a57a", 280, 460]]},
					{"depth": 0.55, "shapes": [["cathedral", 600, 380, "7a6a9a", "5a4a7a"], ["hills", 380, 26, "8a6a8a", 11]]},
					{"depth": 1.0, "shapes": [["roofs", 360, -60, 1260, "3a2e48", 9, "ffd98a"], ["rect", -40, 392, 1280, 80, "2e2438"],
						["posts", LAMPS, 392, "1e1828"], ["folk", [[300, 392], [340, 392], [700, 392], [742, 392], [880, 392]]]]},
				]}
		"hush_eye":
			return {"size": [1000, 460], "dark": null, "motes": "", "lights": {},
				"anchors": {"eye": {"p": [500, 230], "depth": 1.0}, "float": {"p": [660, 392], "depth": 1.0, "h": 50}},
				"layers": [{"depth": 1.0, "lit": true, "shapes": [["rect", -100, -100, 1200, 660, "06030a"], ["ripples", 500, 230, 7, "2a2440"]]}]}
	return panel_v3(id)


static func figure(id: String) -> Dictionary:
	## A figure's stand-in record, in panels.json's shape.
	var f: Dictionary = FIGURES.get(id, {"h": 150.0, "look": "", "flames": {}})
	var out := f.duplicate(true)
	out["frame"] = [256, 256]
	if not out.has("feet"):
		out["feet"] = [128, 244]
	return out


# ---------------------------------------------------------------- panel layers

static func draw_layer(ci: CanvasItem, layer: Dictionary) -> void:
	if bool(layer.get("tb", false)):
		_draw_tb(ci, layer)
		return
	for s in layer.get("shapes", []):
		_shape(ci, s)


static func _c(hex) -> Color:
	return Color(str(hex))


static func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _h(i: float, j: float) -> float:
	return fposmod(sin(i * 12.9898 + j * 78.233) * 43758.5453, 1.0)


static func arch_pts(cx: float, bottom: float, w: float, h: float, n := 8) -> PackedVector2Array:
	## A pointed (equilateral) arch standing on `bottom`, `h` tall; one too
	## squat for that is pressed flatter but stays pointed.
	var rise := minf(0.866 * w, h * 0.92)
	var k := rise / (0.866 * w)
	var spring := bottom - h + rise
	var pts := PackedVector2Array([Vector2(cx - w * 0.5, bottom)])
	for i in n + 1:
		var a := deg_to_rad(60.0) * i / n
		pts.append(Vector2(cx + w * 0.5 - w * cos(a), spring - w * sin(a) * k))
	for i in range(n - 1, -1, -1):
		var a := deg_to_rad(60.0) * i / n
		pts.append(Vector2(cx - w * 0.5 + w * cos(a), spring - w * sin(a) * k))
	pts.append(Vector2(cx + w * 0.5, bottom))
	return pts


static func _grad(ci: CanvasItem, top: Color, bot: Color, y0: float, y1: float, x0 := -200.0, x1 := 2800.0) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
			PackedColorArray([top, top, bot, bot]))


static func _shape(ci: CanvasItem, s: Array) -> void:
	match str(s[0]):
		"rect":
			ci.draw_rect(Rect2(s[1], s[2], s[3], s[4]), _c(s[5]))
		"line":
			ci.draw_line(Vector2(s[1], s[2]), Vector2(s[3], s[4]), _c(s[5]), float(s[6]))
		"grad":
			_grad(ci, _c(s[1]), _c(s[2]), float(s[3]), float(s[4]))
		"circle":
			ci.draw_circle(Vector2(s[1], s[2]), float(s[3]), _c(s[4]))
		"ellipse":
			ci.draw_colored_polygon(_ellipse(Vector2(s[1], s[2]), float(s[3]), float(s[4])), _c(s[5]))
		"poly":
			var pts := PackedVector2Array()
			for p in s[1]:
				pts.append(_v(p))
			ci.draw_colored_polygon(pts, _c(s[2]))
		"bricks":
			# Faint stone courses.
			var col := _c(s[5])
			var y: float = s[2] + 26.0
			var row := 0
			while y < float(s[2]) + float(s[4]):
				ci.draw_line(Vector2(s[1], y), Vector2(float(s[1]) + float(s[3]), y), col, 2.0)
				var x: float = float(s[1]) + (40.0 if row % 2 == 0 else 0.0)
				while x < float(s[1]) + float(s[3]):
					ci.draw_line(Vector2(x, y - 26.0), Vector2(x, y), col, 2.0)
					x += 80.0
				y += 26.0
				row += 1
		"stars":
			for i in int(s[1]):
				var p := Vector2(_h(i, s[3]) * 1200.0, _h(s[3], i) * float(s[2]))
				ci.draw_circle(p, 0.8 + _h(i, i) * 1.4, Color(1, 1, 1, 0.35 + _h(i + 3, 1) * 0.5))
		"hills":
			var base: float = s[1]
			var pts := PackedVector2Array([Vector2(-200, 470)])
			for i in 29:
				var x := -200.0 + i * 60.0
				pts.append(Vector2(x, base - sin(x * 0.006 + float(s[4])) * float(s[2]) - sin(x * 0.017) * float(s[2]) * 0.3))
			pts.append(Vector2(1520, 470))
			ci.draw_colored_polygon(pts, _c(s[3]))
		"spire":
			# Evenbell's tip, tilting out of the far hill.
			var b := Vector2(s[1], s[2])
			var up := Vector2(0, -1).rotated(deg_to_rad(12))
			var side := up.orthogonal()
			ci.draw_colored_polygon(PackedVector2Array([b + side * 16, b + side * 16 + up * 60, b + up * 110, b - side * 16 + up * 60, b - side * 16]), _c(s[3]))
			ci.draw_circle(b + up * 46, 5.0, Color("1a1428"))
		"roofs":
			var y0: float = s[1]
			var x: float = s[2]
			var i := 0
			var col := _c(s[4])
			var win := _c(s[6])
			while x < float(s[3]):
				var w := 90.0 + _h(i, s[5]) * 70.0
				var hh := 50.0 + _h(s[5], i) * 60.0
				var top := y0 - hh
				ci.draw_rect(Rect2(x, top, w, 470.0 - top), col)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, top), Vector2(x + w * 0.5, top - 34 - _h(i, 2) * 20), Vector2(x + w + 8, top)]), col.darkened(0.15))
				if _h(i, 9) > 0.3:
					ci.draw_rect(Rect2(x + w * 0.62, top - 40, 12, 26), col.darkened(0.2))
				if _h(i, 4) > 0.45:
					ci.draw_rect(Rect2(x + w * 0.3, top + 16, 12, 14), win)
				x += w + 6.0
				i += 1
		"cobbles":
			for i in 70:
				var p := Vector2(_h(i, 1) * 1200.0, lerpf(float(s[1]) + 8.0, float(s[2]), _h(1, i)))
				ci.draw_colored_polygon(_ellipse(p, 10.0, 4.0), _c(s[3]))
		"posts":
			for lp in s[1]:
				ci.draw_rect(Rect2(float(lp[0]) - 3.0, float(lp[1]) + 6.0, 6.0, float(s[2]) - float(lp[1]) - 6.0), _c(s[3]))
				ci.draw_rect(Rect2(float(lp[0]) - 9.0, float(lp[1]) - 2.0, 18.0, 10.0), _c(s[3]))
		"cat":
			var p := Vector2(s[1], s[2])
			ci.draw_rect(Rect2(p.x - 60, p.y, 140, 62), Color("2a2238"))
			ci.draw_colored_polygon(_ellipse(p + Vector2(0, -10), 16, 11), Color("140e1c"))
			ci.draw_circle(p + Vector2(12, -24), 8.0, Color("140e1c"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(6, -30), p + Vector2(9, -40), p + Vector2(13, -31)]), Color("140e1c"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(14, -31), p + Vector2(19, -40), p + Vector2(20, -29)]), Color("140e1c"))
			ci.draw_line(p + Vector2(-14, -6), p + Vector2(-26, -26), Color("140e1c"), 4.0)
		"rosette":
			var c := Vector2(s[1], s[2])
			var r: float = s[3]
			ci.draw_circle(c, r + 10.0, Color("4a3e5a"))
			ci.draw_circle(c, r, Color("243258"))
			for i in 8:
				ci.draw_line(c, c + Vector2(r, 0).rotated(TAU * i / 8.0), Color("4a3e5a"), 5.0)
			for i in 6:
				ci.draw_circle(c + Vector2(_h(i, 2) - 0.5, _h(2, i) - 0.5) * r * 1.2, 2.0, Color("fff2c8"))
		"banner":
			var r := Rect2(s[1], s[2], s[3], s[4])
			ci.draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
					Vector2(r.position.x + r.size.x * 0.5, r.end.y - 22), Vector2(r.position.x, r.end.y)]), Color("5a2e5a"))
			ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8), Color("d8b24a"))
			_crest(ci, r.get_center() + Vector2(0, -6), 0.8)
		"shelf":
			ci.draw_rect(Rect2(s[1], s[2], s[3], 8), Color("4a3428"))
			for i in int(float(s[3]) / 30.0):
				var x: float = float(s[1]) + 12.0 + i * 30.0
				ci.draw_rect(Rect2(x, float(s[2]) - 14.0 - (i % 2) * 6.0, 7, 14 + (i % 2) * 6), Color("d8ccb0"))
		"hearth":
			var cx: float = s[1]
			var fl: float = s[2]
			ci.draw_colored_polygon(arch_pts(cx, fl, float(s[3]) + 30.0, float(s[4]) + 20.0), Color("4a3a4c"))
			ci.draw_colored_polygon(arch_pts(cx, fl, s[3], s[4]), Color("140c14"))
			ci.draw_rect(Rect2(cx - 40, fl - 16, 80, 12), Color("3a2418"))
		"lectern":
			var p := Vector2(s[1], s[2])
			ci.draw_rect(Rect2(p.x - 7, p.y - 80, 14, 80), Color("4a3024"))
			ci.draw_rect(Rect2(p.x - 26, p.y - 8, 52, 8), Color("4a3024"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-40, -80), p + Vector2(40, -92), p + Vector2(40, -80), p + Vector2(-40, -70)]), Color("5a3a2a"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-32, -86), p + Vector2(0, -92), p + Vector2(32, -96), p + Vector2(32, -88), p + Vector2(0, -84), p + Vector2(-32, -78)]), Color("efe6cc"))
			for i in 3:
				ci.draw_rect(Rect2(p.x - 22 + i * 18, p.y - 101 + (4 if i != 1 else 0), 6, 12), Color("efe6cc"))
		"arches":
			var n: int = s[3]
			for i in n:
				var x := lerpf(float(s[1]), float(s[2]), i / maxf(n - 1.0, 1.0))
				ci.draw_colored_polygon(arch_pts(x, s[4], s[5], s[6]), _c(s[7]))
		"crest":
			_crest(ci, Vector2(s[1], s[2]), 1.4)
		"sconce":
			var p := Vector2(s[1], s[2])
			ci.draw_rect(Rect2(p.x - 10, p.y, 20, 8), Color("6a5a3a"))
			ci.draw_rect(Rect2(p.x - 4, p.y - 12, 8, 12), Color("efe6cc"))
		"plinth":
			_plinth(ci, float(s[1]), float(s[2]), str(s[3]))
		"ribs":
			var vp := Vector2(s[1], s[2])
			for i in int(s[3]):
				var k := 1.0 - i * 0.13
				var w := 900.0 * k
				var h := 520.0 * k
				var col := _c(s[4]).darkened(i * 0.08)
				var pts := arch_pts(vp.x, vp.y + h * 0.46, w, h, 10)
				ci.draw_polyline(pts, col, maxf(22.0 * k, 4.0))
				if i < int(s[3]) - 1:
					var nh := 60.0 * k
					ci.draw_rect(Rect2(vp.x - w * 0.5 + 20.0 * k, vp.y - nh * 0.2, 44.0 * k, nh), Color("0e1416"))
					ci.draw_rect(Rect2(vp.x + w * 0.5 - 64.0 * k, vp.y - nh * 0.2, 44.0 * k, nh), Color("0e1416"))
		"stands":
			for p in s[1]:
				var k: float = (float(p[1]) - 250.0) / 80.0
				var fl := lerpf(262.0, 440.0, k)
				ci.draw_line(Vector2(p[0], float(p[1]) + 12.0), Vector2(p[0], fl), Color("3a3a36"), lerpf(2.0, 6.0, k))
				ci.draw_rect(Rect2(float(p[0]) - lerpf(3, 6, k), float(p[1]), lerpf(6, 12, k), lerpf(6, 14, k)), Color("d8ccb0"))
				ci.draw_colored_polygon(_ellipse(Vector2(p[0], fl), lerpf(8, 22, k), lerpf(2, 5, k)), Color("3a3a36"))
		"louver":
			var cx: float = s[1]
			var b: float = s[2]
			ci.draw_colored_polygon(arch_pts(cx, b, float(s[3]) + 24.0, float(s[4]) + 16.0), Color("34344e"))
			ci.draw_colored_polygon(arch_pts(cx, b, s[3], s[4]), Color("3a4478"))
			var y := b - float(s[4]) + 0.5 * float(s[3])
			while y < b - 6.0:
				ci.draw_line(Vector2(cx - float(s[3]) * 0.5, y), Vector2(cx + float(s[3]) * 0.5, y + 8.0), Color("1c1c30"), 7.0)
				y += 22.0
		"shaft":
			var col := _c(s[5])
			var a := Color(col.r, col.g, col.b, 0.22)
			var z := Color(col.r, col.g, col.b, 0.0)
			ci.draw_polygon(PackedVector2Array([Vector2(float(s[1]) - 50, s[2]), Vector2(float(s[1]) + 50, s[2]),
					Vector2(float(s[3]) + 110, float(s[2]) + float(s[4])), Vector2(float(s[3]) - 70, float(s[2]) + float(s[4]))]),
					PackedColorArray([a, a, z, z]))
		"beam":
			ci.draw_rect(Rect2(s[1], s[3], float(s[2]) - float(s[1]), s[4]), _c(s[5]))
			ci.draw_rect(Rect2(s[1], float(s[3]) + float(s[4]) - 5.0, float(s[2]) - float(s[1]), 5), _c(s[5]).darkened(0.3))
		"bell":
			_bell(ci, Vector2(s[1], s[2]), float(s[3]), _c(s[4]))
		"bells":
			for p in s[1]:
				ci.draw_rect(Rect2(float(p[0]) - 3, float(p[1]) - 70, 6, 40), Color("4a3a30"))
				_bell(ci, Vector2(p[0], float(p[1]) - 30.0), 40.0, Color("b08a3a"))
		"choir":
			for p in s[1]:
				var q := _v(p)
				ci.draw_rect(Rect2(q.x - 8, q.y - 30, 16, 24), Color("d8d0bc"))
				ci.draw_circle(q + Vector2(0, -40), 11.0, Color("ece4d0"))
				ci.draw_circle(q + Vector2(-4, -41), 2.5, INK)
				ci.draw_circle(q + Vector2(4, -41), 2.5, INK)
		"planks":
			var x := -100.0
			while x < 1100.0:
				ci.draw_line(Vector2(x, s[1]), Vector2(x - 30.0, s[2]), _c(s[3]), 3.0)
				x += 90.0
		"rope":
			var p := Vector2(s[1], s[2])
			for i in 3:
				ci.draw_arc(p, 30.0 - i * 8.0, 0, TAU, 20, Color("9a8060"), 5.0)
		"bat":
			var p := Vector2(s[1], s[2])
			ci.draw_line(p, p + Vector2(0, 8), Color("0c0a12"), 2.0)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 10), p + Vector2(12, 10), p + Vector2(6, 30), p + Vector2(0, 34), p + Vector2(-6, 30)]), Color("0c0a12"))
		"waxfalls":
			for i in 9:
				var x := 60.0 + i * 160.0 + _h(i, 5) * 60.0
				var w := 26.0 + _h(5, i) * 30.0
				ci.draw_polygon(PackedVector2Array([Vector2(x, -10), Vector2(x + w, -10), Vector2(x + w * 0.8, 470), Vector2(x + w * 0.2, 470)]),
						PackedColorArray([Color(0.94, 0.9, 0.8, 0.5), Color(0.94, 0.9, 0.8, 0.5), Color(0.94, 0.9, 0.8, 0.08), Color(0.94, 0.9, 0.8, 0.08)]))
				var cx := x + 90.0
				ci.draw_rect(Rect2(cx, -10, 20, 90 + _h(i, 1) * 120.0), Color("8a7a60"))
		"terraces":
			var col_a := _c(s[2])
			var col_b := _c(s[3])
			for t in 3:
				var y := 300.0 + t * 55.0
				var pts := PackedVector2Array([Vector2(-200, 470)])
				for i in 17:
					var x := -200.0 + i * 110.0
					pts.append(Vector2(x, y + sin(i * 1.7 + t) * 18.0))
				pts.append(Vector2(1700, 470))
				ci.draw_colored_polygon(pts, col_a.lerp(col_b, t / 2.0).darkened(0.35 - t * 0.12))
		"reeds":
			for p in s[1]:
				ci.draw_line(Vector2(p[0], float(p[1]) + 6.0), Vector2(float(p[0]) + 4.0, float(p[1]) + 70.0), Color("3a2e22"), 3.0)
				ci.draw_rect(Rect2(float(p[0]) - 2.5, float(p[1]), 5, 7), Color("efe6cc"))
		"moth":
			var p := Vector2(s[1], s[2])
			var col := Color("a8e0d0")
			ci.draw_colored_polygon(_ellipse(p + Vector2(-26, 0), 30, 18), col.darkened(0.2))
			ci.draw_colored_polygon(_ellipse(p + Vector2(26, 0), 30, 18), col.darkened(0.2))
			ci.draw_colored_polygon(_ellipse(p, 8, 20), col.darkened(0.45))
		"rings":
			for i in 4:
				ci.draw_arc(Vector2(s[1], float(s[2]) * (0.15 + i * 0.22)), 560.0, PI * 0.08, PI * 0.92, 30, _c(s[3]), 10.0)
		"bigcandle":
			var x0: float = s[1]
			var x1: float = s[2]
			var y0: float = s[3]
			var y1: float = s[4]
			ci.draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), Color("d8ccb0"))
			ci.draw_rect(Rect2(x1 - 50, y0, 50, y1 - y0), Color("b8aa8c"))
			for i in 6:
				var dx := lerpf(x0 + 10, x1 - 30, i / 5.0)
				ci.draw_rect(Rect2(dx, y0 - 4, 22, 40 + _h(i, 3) * 120.0), Color("e8dcc0"))
				ci.draw_circle(Vector2(dx + 11, y0 + 36 + _h(i, 3) * 120.0), 11.0, Color("e8dcc0"))
			ci.draw_line(Vector2((x0 + x1) * 0.5, y0), Vector2((x0 + x1) * 0.5, y0 - 12), Color("2a2020"), 4.0)
		"swirl":
			var c := Vector2(s[1], s[2])
			var col := _c(s[4])
			for i in 3:
				var pts := PackedVector2Array()
				for k in 24:
					var a := k * 0.28 + i * 2.1
					pts.append(c + Vector2(cos(a), sin(a) * 0.3) * (float(s[3]) * (0.3 + k / 30.0)))
				ci.draw_polyline(pts, Color(col.r, col.g, col.b, 0.6), 8.0)
		"cathedral":
			var cx: float = s[1]
			var b: float = s[2]
			var col := _c(s[3])
			var dark := _c(s[4])
			ci.draw_rect(Rect2(cx - 150, b - 190, 300, 190), col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 160, b - 190), Vector2(cx, b - 290), Vector2(cx + 160, b - 190)]), col)
			for side in [-1, 1]:
				var tx: float = cx + side * 190.0
				ci.draw_rect(Rect2(tx - 36, b - 280, 72, 280), dark)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 42, b - 280), Vector2(tx, b - 370), Vector2(tx + 42, b - 280)]), dark)
			ci.draw_circle(Vector2(cx, b - 150), 38.0, Color("f7d9a0"))
			ci.draw_colored_polygon(arch_pts(cx, b, 70, 110), dark.darkened(0.3))
			for i in 7:
				ci.draw_rect(Rect2(cx - 180 + _h(i, 7) * 360.0, b - 60 + _h(7, i) * 50.0, 14, 12), dark)
		"folk":
			for p in s[1]:
				var q := _v(p)
				ci.draw_rect(Rect2(q.x - 7, q.y - 24, 14, 24), Color("2a2034"))
				ci.draw_circle(q + Vector2(0, -32), 8.0, Color("2a2034"))
				ci.draw_line(q + Vector2(-6, -20), q + Vector2(-14, -40), Color("2a2034"), 4.0)
				ci.draw_line(q + Vector2(6, -20), q + Vector2(14, -40), Color("2a2034"), 4.0)
		"ripples":
			var c := Vector2(s[1], s[2])
			for i in int(s[3]):
				var pts := _ellipse(c, 330.0 + i * 70.0, 120.0 + i * 26.0)
				pts.append(pts[0])
				ci.draw_polyline(pts, _c(s[4]).darkened(i * 0.1), 2.0)
		"lancet":
			_lancet(ci, float(s[1]), float(s[2]), float(s[3]), float(s[4]), str(s[5]))
		"pillar":
			var x: float = s[1]
			var w: float = s[2]
			ci.draw_rect(Rect2(x - w * 0.5, -60, w, 580), Color("1c1426"))
			ci.draw_rect(Rect2(x - w * 0.5, -60, 10, 580), Color("2a2036"))
			ci.draw_rect(Rect2(x - w * 0.5 - 12, 20, w + 24, 22), Color("2a2036"))
			ci.draw_rect(Rect2(x - w * 0.5 - 12, 430, w + 24, 22), Color("2a2036"))


static func _ellipse(c: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _crest(ci: CanvasItem, c: Vector2, k: float) -> void:
	## The Vigil's crest: a bell whose clapper is a flame.
	_bell(ci, c, 18.0 * k, Color("d8b24a"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 14) * k, c + Vector2(0, 2) * k, c + Vector2(4, 14) * k, c + Vector2(0, 18) * k]), Color("f07a2a"))


static func _bell(ci: CanvasItem, top: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(top + Vector2(cos(a) * r * 0.62, r * 0.55 + sin(a) * r * 0.55))
	pts.append(top + Vector2(r * 0.72, r * 1.3))
	pts.append(top + Vector2(r, r * 1.55))
	pts.append(top + Vector2(-r, r * 1.55))
	pts.append(top + Vector2(-r * 0.72, r * 1.3))
	ci.draw_colored_polygon(pts, col)
	ci.draw_rect(Rect2(top.x - r, top.y + r * 1.42, r * 2.0, r * 0.14), col.darkened(0.3))
	ci.draw_circle(top + Vector2(0, r * 1.6), r * 0.18, col.darkened(0.35))


static func _plinth(ci: CanvasItem, cx: float, top: float, gear: String) -> void:
	ci.draw_rect(Rect2(cx - 48, top, 96, 110), Color("4a3e5a"))
	ci.draw_rect(Rect2(cx - 56, top - 4, 112, 14), Color("5c4e6c"))
	ci.draw_rect(Rect2(cx + 28, top + 10, 20, 100), Color("3e3450"))
	ci.draw_colored_polygon(_ellipse(Vector2(cx, top - 8), 42, 11), Color("6a2a3a"))
	# The unlit candle on top: the plinth's light burns at its wick (y 262).
	ci.draw_rect(Rect2(cx - 5, 263, 10, 30), Color("efe6cc"))
	ci.draw_line(Vector2(cx, 263), Vector2(cx, 257), Color("2a2020"), 2.0)
	var b := Vector2(cx, top - 14)
	match gear:
		"helm":
			ci.draw_colored_polygon(_ellipse(b + Vector2(0, -16), 26, 20), Color("9aa4b8"))
			ci.draw_rect(Rect2(b.x - 34, b.y - 6, 68, 8), Color("7a8498"))
		"pot":
			ci.draw_rect(Rect2(b.x - 26, b.y - 32, 52, 32), Color("4a4a52"))
			ci.draw_rect(Rect2(b.x - 32, b.y - 36, 64, 8), Color("5a5a62"))
			ci.draw_colored_polygon(_ellipse(b + Vector2(0, -38), 18, 5), Color("c86a2a"))
		"hat":
			ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-38, -4), b + Vector2(38, -4), b + Vector2(10, -20), b + Vector2(-2, -36), b + Vector2(-12, -20)]), Color("6a3a7a"))
		"hood":
			ci.draw_colored_polygon(_ellipse(b + Vector2(0, -18), 28, 22), Color("5a5e6a"))
			ci.draw_line(b + Vector2(-8, -38), b + Vector2(-22, -58), Color("5a5e6a"), 3.0)
			ci.draw_line(b + Vector2(8, -38), b + Vector2(22, -58), Color("5a5e6a"), 3.0)
		"stovepipe":
			ci.draw_rect(Rect2(b.x - 20, b.y - 44, 40, 44), Color("24202c"))
			ci.draw_rect(Rect2(b.x - 32, b.y - 6, 64, 8), Color("24202c"))
			ci.draw_circle(b + Vector2(0, -30), 7.0, Color("d8d0bc"))


static func _lancet(ci: CanvasItem, cx: float, bottom: float, w: float, h: float, motif: String) -> void:
	## A stained-glass lancet: panes on a grid inside a pointed arch, the lead
	## showing through the gaps, a border of little squares.
	var outer := arch_pts(cx, bottom, w, h, 12)
	ci.draw_colored_polygon(arch_pts(cx, bottom + 14, w + 44, h + 32, 12), Color("2c2238"))
	ci.draw_colored_polygon(arch_pts(cx, bottom + 6, w + 18, h + 12, 12), Color("3a2e48"))
	ci.draw_colored_polygon(outer, Color("140e1c"))
	var inner := arch_pts(cx, bottom - 16, w - 32, h - 32, 12)
	var cell := 16.0
	var top := bottom - h
	var border := [Color("b8324e"), Color("3a6ab8"), Color("d8a830")]
	var j := 0
	var y := top
	while y < bottom:
		var i := 0
		var x := cx - w * 0.5
		while x < cx + w * 0.5:
			var c := Vector2(x + cell * 0.5, y + cell * 0.5)
			if Geometry2D.is_point_in_polygon(c, outer):
				var col: Color
				if not Geometry2D.is_point_in_polygon(c, inner):
					col = border[(i + j) % 3]
				else:
					col = _glass(motif, (c.x - (cx - w * 0.5)) / w, (c.y - top) / h, i, j)
				col = col.lightened(_h(i, j) * 0.14) if _h(j, i) > 0.5 else col.darkened(_h(i, j) * 0.14)
				ci.draw_rect(Rect2(x + 1.8, y + 1.8, cell - 3.6, cell - 3.6), col)
				if _h(i * 3, j) > 0.95:
					ci.draw_rect(Rect2(x + 3.5, y + 3.5, 2.5, cell - 8.0), Color(1, 1, 1, 0.4))
			x += cell
			i += 1
		y += cell
		j += 1


static func _glass(motif: String, u: float, v: float, i: int, j: int) -> Color:
	## A pane's colour in one of the three legend windows (u, v: 0..1 across
	## and down the lancet).
	var d := func(x: float, y: float) -> float: return Vector2((u - x) * 1.25, v - y).length()
	match motif:
		"pit":
			# The Undercandle over the Hush pit, keepers kneeling at its sides.
			if v > 0.8:
				if (i % 5 == 1 or i % 5 == 2) and j % 3 == 0 and v < 0.93:
					return Color("e8e070")
				return Color("4a3a7a") if v < 0.88 else Color("33285a")
			var fl: float = d.call(0.5, 0.3)
			if fl < 0.05:
				return Color("fff2c8")
			if fl < 0.09 and v > 0.24:
				return Color("f0b030")
			if absf(u - 0.5) < 0.075 and v > 0.4 and v < 0.8:
				return Color("fff2c8") if u < 0.51 else Color("e0d0a0")
			if fl < 0.17:
				return Color("d8a830") if (i + j) % 2 == 0 else Color("c8982a")
			for kx in [0.2, 0.8]:
				if d.call(kx, 0.56) < 0.055:
					return Color("f0c8a0")
				if absf(u - kx) < 0.085 - (0.62 - v) * 0.1 and v > 0.6 and v < 0.8:
					return Color("5aa860") if kx < 0.5 else Color("b8324e")
			return Color("3a6ab8").lerp(Color("24407a"), v)
		"bells":
			# Evenbell in cross-section: bells swinging, the breath flowing down.
			for b in [[0.3, 0.26], [0.7, 0.26], [0.5, 0.5]]:
				var bu: float = (u - float(b[0])) * 1.25
				var bv: float = v - float(b[1])
				if bv > -0.07 and bv < 0.07 and absf(bu) < 0.05 + (bv + 0.07) * 0.55:
					return Color("f0c040") if bu < 0.0 else Color("c8982a")
			for k in 3:
				if absf(v - (0.36 + k * 0.16) - sin(u * 9.0 + k) * 0.03) < 0.025:
					return Color("8ab0f0")
			if v > 0.8 and absf(u - 0.5) < 0.06:
				return Color("fff2c8")
			if v > 0.74 and v < 0.8 and absf(u - 0.5) < 0.05:
				return Color("f0b030")
			return Color("b8324e").lerp(Color("7a2040"), v)
		"sunk":
			# The cathedral half sunk, its bells cracked, under a crescent moon.
			if d.call(0.7, 0.16) < 0.08 and d.call(0.75, 0.13) > 0.075:
				return Color("fff2c8")
			var ground := 0.66 + sin(u * 5.0) * 0.03
			var tower := absf(u - 0.36) < 0.08 and v > 0.34 - maxf(0.0, 0.08 - absf(u - 0.36)) * 1.2
			if (tower or (absf(u - 0.56) < 0.14 and v > 0.46)) and v < ground:
				if absf(u - 0.36) < 0.03 and absf(v - 0.46) < 0.03:
					return Color("f0b030")
				return Color("5a4a7a")
			if v >= ground:
				return Color("4a3a7a") if (i + j) % 4 != 0 else Color("3a2a66")
			if _h(i, j) > 0.97:
				return Color("fff2c8")
			return Color("2a3a6a").lerp(Color("1a2448"), 1.0 - v)
	return Color("3a6ab8")


# ---------------------------------------------------------------- figures (256 frame, feet at (128, 244))

static func draw_figure(ci: CanvasItem, look: String, t: float) -> void:
	if NEW_LOOKS.has(look):
		_figure_tb(ci, look, t)
		return
	match look:
		"taper":
			_staff(ci, Vector2(190, 244), Vector2(196, 106))
			_robe(ci, 128, 244, 150, 44, 64, Color("5a2e5a"), Color("3e1e40"))
			ci.draw_rect(Rect2(90, 232, 76, 8), Color("d8b24a"))
			_hood_head(ci, Vector2(126, 124), 40.0, Color("5a2e5a"), Color("f0c8a8"), "taper")
			ci.draw_rect(Rect2(119, 64, 14, 22), Color("d8ccb0"))
			ci.draw_rect(Rect2(114, 82, 24, 6), Color("b8862a"))
		"taper_chair":
			ci.draw_rect(Rect2(70, 60, 116, 184), Color("4a3024"))
			ci.draw_rect(Rect2(78, 70, 100, 110), Color("5a3a2c"))
			_robe(ci, 124, 232, 150, 70, 80, Color("5a2e5a"), Color("3e1e40"))
			ci.draw_rect(Rect2(66, 176, 124, 40), Color("8a5a4a"))
			_hood_head(ci, Vector2(118, 126), 38.0, Color("5a2e5a"), Color("f0c8a8"), "taper")
			ci.draw_rect(Rect2(111, 68, 14, 20), Color("d8ccb0"))
		"novice":
			_robe(ci, 128, 244, 140, 50, 72, Color("c8b89a"), Color("a0907a"))
			ci.draw_rect(Rect2(88, 196, 80, 8), Color("8a6a3a"))
			ci.draw_circle(Vector2(128, 104), 52.0, Color("a0907a"))
			ci.draw_circle(Vector2(128, 100), 48.0, Color("c8b89a"))
			ci.draw_rect(Rect2(116, 36, 24, 20), Color("8a8a90"))
			ci.draw_rect(Rect2(122, 26, 12, 14), Color("d8ccb0"))
			_outline_circle(ci, Vector2(128, 102), 52.0)
		"tollgrave", "tollgrave_sit":
			var sit := look == "tollgrave_sit"
			var head := Vector2(112, 128) if sit else Vector2(128, 96)
			var robe := Color("2c3438")
			var shade := Color("1c2226")
			if sit:
				_bell(ci, Vector2(200, 142), 44.0, Color("8a6a3a"))
				ci.draw_colored_polygon(_ellipse(Vector2(120, 226), 90, 20), shade)
				_robe(ci, 112, 222, 166, 50, 74, robe, shade)
			else:
				_robe(ci, 128, 244, 140, 70, 104, robe, shade)
				# Bony hands at his sides.
				ci.draw_circle(Vector2(40, 214), 11.0, Color("ecd8b0"))
				ci.draw_circle(Vector2(216, 214), 11.0, Color("ecd8b0"))
			# The cowl (thrown back once he's himself again).
			var cowl := PackedVector2Array([head + Vector2(-58, 48), head + Vector2(-54, -8), head + Vector2(-30, -48),
					head + Vector2(0, -66), head + Vector2(30, -48), head + Vector2(54, -8), head + Vector2(58, 48)])
			if not sit:
				ci.draw_colored_polygon(cowl, shade)
			else:
				ci.draw_colored_polygon(_ellipse(head + Vector2(0, 30), 56, 18), shade)
			ci.draw_circle(head + Vector2(0, 4), 32.0, Color("ecd8b0"))
			ci.draw_colored_polygon(_ellipse(head + Vector2(0, 30), 20, 12), Color("ecd8b0"))
			ci.draw_circle(head + Vector2(-13, 0), 9.0, INK)
			ci.draw_circle(head + Vector2(13, 0), 9.0, INK)
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-3, 14), head + Vector2(3, 14), head + Vector2(0, 8)]), INK)
			for k in 4:
				ci.draw_line(head + Vector2(-10 + k * 7, 26), head + Vector2(-10 + k * 7, 34), Color("a89878"), 2.0)
			if sit:
				for k in 3:
					ci.draw_line(head + Vector2(-20 + k * 16, -26), head + Vector2(-26 + k * 18, -40), Color("f4f0e8"), 3.0)
				ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-8, 38), head + Vector2(8, 38), head + Vector2(0, 58)]), Color("f4f0e8"))
			else:
				cowl.append(cowl[0])
				ci.draw_polyline(cowl, INK, 4.0)
		"snuffer", "snuffer_reach":
			var reach := look == "snuffer_reach"
			if reach:
				ci.draw_line(Vector2(150, 190), Vector2(250, 20), Color("b8862a"), 7.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(238, 16), Vector2(262, 26), Vector2(256, 4)]), Color("b8862a"))
			else:
				ci.draw_line(Vector2(178, 244), Vector2(196, 12), Color("b8862a"), 7.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(184, 14), Vector2(208, 10), Vector2(196, -6)]), Color("b8862a"))
			_robe(ci, 124, 244, 150, 40, 84, Color("2a2436"), Color("1a1624"))
			for k in 5:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(82 + k * 18, 236), Vector2(92 + k * 18, 250), Vector2(100 + k * 18, 236)]), Color("1a1624"))
			ci.draw_circle(Vector2(176 if not reach else 150, 170 if not reach else 190), 8.0, Color("8a8698"))
			var cone := PackedVector2Array([Vector2(124, 20), Vector2(170, 150), Vector2(78, 150)])
			ci.draw_colored_polygon(cone, Color("1e1a28"))
			ci.draw_line(Vector2(124, 20), Vector2(146, 150), Color("4a4460"), 4.0)
			ci.draw_colored_polygon(_ellipse(Vector2(124, 150), 46, 9), Color("2a2436"))
			ci.draw_colored_polygon(_ellipse(Vector2(124, 132), 16, 9), Color("06030a"))
			cone.append(cone[0])
			ci.draw_polyline(cone, INK, 4.0)
			ci.draw_circle(Vector2(124, 14), 6.0, Color("2a2436"))
		"cone_broken":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(60, 244), Vector2(96, 150), Vector2(120, 244)]), Color("1e1a28"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(140, 244), Vector2(190, 170), Vector2(210, 244)]), Color("1e1a28"))
			for k in 4:
				ci.draw_circle(Vector2(128 + sin(t * 1.3 + k) * 8.0, 150 - k * 22.0), 8.0 + k * 3.0, Color(0.7, 0.68, 0.75, 0.25 - k * 0.05))
		"hollin_cold", "hollin_warm":
			var warm := look == "hollin_warm"
			var skin := Color("f0c8a8") if warm else Color("c8c4cc")
			if warm:
				_robe(ci, 128, 244, 160, 42, 60, Color("5a6a8a"), Color("3a4a6a"))
				ci.draw_circle(Vector2(128, 110), 44.0, skin)
				ci.draw_colored_polygon(_ellipse(Vector2(128, 80), 46, 22), Color("8a8a96"))
				ci.draw_rect(Rect2(121, 44, 14, 18), Color("d8ccb0"))
				ci.draw_circle(Vector2(112, 116), 5.0, INK)
				ci.draw_circle(Vector2(144, 116), 5.0, INK)
				ci.draw_circle(Vector2(104, 128), 6.0, Color(1.0, 0.5, 0.5, 0.4))
				ci.draw_circle(Vector2(152, 128), 6.0, Color(1.0, 0.5, 0.5, 0.4))
				ci.draw_arc(Vector2(128, 128), 9.0, 0.3, PI - 0.3, 8, INK, 3.0)
				_outline_circle(ci, Vector2(128, 110), 44.0)
			else:
				ci.draw_colored_polygon(_ellipse(Vector2(128, 214), 56, 32), Color("5a5e6e"))
				ci.draw_circle(Vector2(128, 160), 40.0, skin)
				ci.draw_colored_polygon(_ellipse(Vector2(128, 132), 44, 22), Color("3a3640"))
				ci.draw_circle(Vector2(114, 164), 7.0, Color("e8f0ff"))
				ci.draw_circle(Vector2(142, 164), 7.0, Color("e8f0ff"))
				ci.draw_circle(Vector2(114, 166), 3.5, INK)
				ci.draw_circle(Vector2(142, 166), 3.5, INK)
				ci.draw_colored_polygon(_ellipse(Vector2(128, 206), 50, 14), skin.darkened(0.1))
				_outline_circle(ci, Vector2(128, 160), 40.0)
		"waxley":
			ci.draw_rect(Rect2(150, 60, 70, 150), Color("6a4a2a"))
			_robe(ci, 120, 244, 140, 60, 70, Color("d8a830"), Color("b88a20"))
			ci.draw_circle(Vector2(120, 110), 40.0, Color("e8b890"))
			ci.draw_colored_polygon(_ellipse(Vector2(120, 76), 70, 12), Color("6a4a2a"))
			ci.draw_colored_polygon(_ellipse(Vector2(104, 126), 20, 8), Color("f4ecd8"))
			ci.draw_colored_polygon(_ellipse(Vector2(136, 126), 20, 8), Color("f4ecd8"))
		"eye":
			var open := PackedVector2Array()
			for k in 25:
				var a := PI * k / 24.0
				open.append(Vector2(128 - cos(a) * 128.0, 128 - sin(a) * 47.0))
			for k in range(23, 0, -1):
				var a := PI * k / 24.0
				open.append(Vector2(128 - cos(a) * 128.0, 128 + sin(a) * 47.0))
			ci.draw_colored_polygon(open, Color("d8d4f0"))
			ci.draw_circle(Vector2(128, 128), 40.0, Color("6a5a9a"))
			ci.draw_circle(Vector2(128, 128), 26.0, Color("3a2e5a"))
			ci.draw_circle(Vector2(128, 128), 8.0, Color("06030a"))
			ci.draw_circle(Vector2(136, 118), 4.0, Color(1, 1, 1, 0.9))
			open.append(open[0])
			ci.draw_polyline(open, Color("06030a"), 5.0)
		_:
			_robe(ci, 128, 244, 150, 44, 70, Color("4a3e5a"), Color("3a3050"))
			ci.draw_circle(Vector2(128, 110), 42.0, Color("6a5a7a"))


static func _robe(ci: CanvasItem, cx: float, feet: float, top: float, w_top: float, w_bot: float, col: Color, shade: Color) -> void:
	var pts := PackedVector2Array([Vector2(cx - w_bot, feet), Vector2(cx - w_top, top), Vector2(cx + w_top, top), Vector2(cx + w_bot, feet)])
	ci.draw_colored_polygon(pts, col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx + w_bot * 0.35, feet), Vector2(cx + w_top * 0.4, top), Vector2(cx + w_top, top), Vector2(cx + w_bot, feet)]), shade)
	pts.append(pts[0])
	ci.draw_polyline(pts, INK, 4.0)


static func _hood_head(ci: CanvasItem, c: Vector2, r: float, hood: Color, skin: Color, who: String) -> void:
	ci.draw_circle(c, r + 6.0, hood)
	ci.draw_circle(c + Vector2(0, 6), r * 0.72, skin)
	if who == "taper":
		ci.draw_arc(c + Vector2(-11, 6), 7.0, 0, TAU, 14, Color("d8b24a"), 2.5)
		ci.draw_arc(c + Vector2(11, 6), 7.0, 0, TAU, 14, Color("d8b24a"), 2.5)
		ci.draw_circle(c + Vector2(-11, 6), 2.5, INK)
		ci.draw_circle(c + Vector2(11, 6), 2.5, INK)
		ci.draw_circle(c + Vector2(-19, 16), 5.0, Color(1.0, 0.5, 0.5, 0.45))
		ci.draw_circle(c + Vector2(19, 16), 5.0, Color(1.0, 0.5, 0.5, 0.45))
		ci.draw_arc(c + Vector2(0, 18), 6.0, 0.4, PI - 0.4, 8, INK, 2.5)
	_outline_circle(ci, c, r + 6.0)


static func _staff(ci: CanvasItem, a: Vector2, b: Vector2) -> void:
	ci.draw_line(a, b, Color("6a4a2a"), 6.0)
	ci.draw_rect(Rect2(b.x - 10, b.y + 4, 20, 22), Color("3a2a1a"))
	ci.draw_rect(Rect2(b.x - 7, b.y + 7, 14, 16), Color("f7b64a"))


static func _outline_circle(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_arc(c, r, 0, TAU, 32, INK, 4.0)


# ---------------------------------------------------------------- portraits (128 frame, face near (64, 62))

static func draw_portrait(ci: CanvasItem, who: String, mood: String) -> void:
	## A flat little face for a speaker whose portrait isn't drawn yet.
	if NEW_FACES.has(who):
		_face_tb(ci, who, mood)
		return
	var c := Vector2(64, 66)
	match who:
		"taper":
			ci.draw_circle(Vector2(64, 60), 50.0, Color("5a2e5a"))
			ci.draw_circle(c + Vector2(0, 6), 32.0, Color("f0c8a8"))
			ci.draw_rect(Rect2(57, 14, 14, 18), Color("d8ccb0"))
			ci.draw_rect(Rect2(52, 28, 24, 6), Color("b8862a"))
			_face(ci, c + Vector2(0, 6), mood, true)
		"waxley":
			ci.draw_circle(c + Vector2(0, 8), 34.0, Color("e8b890"))
			ci.draw_colored_polygon(_ellipse(Vector2(64, 36), 58, 12), Color("6a4a2a"))
			ci.draw_rect(Rect2(38, 8, 52, 30), Color("6a4a2a"))
			var up := mood == "shock"
			ci.draw_colored_polygon(_ellipse(c + Vector2(-16, 22 - (6 if up else 0)), 18, 7), Color("f4ecd8"))
			ci.draw_colored_polygon(_ellipse(c + Vector2(16, 22 - (6 if up else 0)), 18, 7), Color("f4ecd8"))
			_face(ci, c + Vector2(0, 2), mood, false)
		"tollgrave":
			var kind := mood == "kind"
			ci.draw_circle(Vector2(64, 60), 50.0, Color("2c3438") if not kind else Color("e8e4dc"))
			ci.draw_circle(c + Vector2(0, 4), 34.0, Color("ecd8b0"))
			var eye := Color("f7b64a") if kind else Color("7ef0c8")
			for sx in [-13, 13]:
				ci.draw_circle(c + Vector2(sx, 0), 9.0, INK)
				ci.draw_circle(c + Vector2(sx, 0), 3.5, eye)
			ci.draw_rect(Rect2(50, 90, 28, 7), Color("c8b48c"))
		"snuffer":
			var wrath := mood == "wrath"
			ci.draw_colored_polygon(PackedVector2Array([Vector2(64, 4), Vector2(118, 112), Vector2(10, 112)]), Color("1e1a28"))
			ci.draw_line(Vector2(64, 4), Vector2(86, 112), Color("4a4460"), 3.0)
			ci.draw_colored_polygon(_ellipse(Vector2(64, 96), 20, 11), Color("06030a"))
			var eye := Color("e8e4ff")
			if wrath:
				ci.draw_line(Vector2(46, 66), Vector2(58, 70), eye, 3.0)
				ci.draw_line(Vector2(82, 66), Vector2(70, 70), eye, 3.0)
				ci.draw_line(Vector2(96, 60), Vector2(88, 84), Color("4a4460"), 2.0)
			else:
				ci.draw_circle(Vector2(52, 70), 2.5, eye)
				ci.draw_circle(Vector2(76, 70), 2.5, eye)
		"hollin":
			var relit := HOLLIN_LIT.has(mood)
			ci.draw_circle(c + Vector2(0, 6), 32.0, Color("f0c8a8") if relit else Color("c8c4cc"))
			ci.draw_colored_polygon(_ellipse(Vector2(64, 44), 38, 18), Color("3a3640"))
			_face(ci, c + Vector2(0, 6), {"relit": "warm", "worried": "worried", "grin": "grin"}.get(mood, "sad"), false)
		_:
			ci.draw_circle(c, 34.0, Color("6a5a7a"))


static func _face(ci: CanvasItem, c: Vector2, mood: String, specs: bool) -> void:
	var ey := c + Vector2(0, -4)
	for sx in [-11, 11]:
		ci.draw_circle(ey + Vector2(sx, 0), 3.2, INK)
		if specs:
			ci.draw_arc(ey + Vector2(sx, 0), 7.5, 0, TAU, 14, Color("d8b24a"), 2.2)
	match mood:
		"faint":
			# Mother Taper, tired: heavy half-closed eyes, a small brave smile.
			for sx in [-11, 11]:
				ci.draw_line(ey + Vector2(sx - 5, 1), ey + Vector2(sx + 5, 1), Color("b89a8a"), 3.0)
			ci.draw_arc(c + Vector2(0, 12), 5.0, 0.5, PI - 0.5, 8, INK, 2.2)
			return
		"worried", "sad", "lost", "shock":
			ci.draw_line(ey + Vector2(-17, -11), ey + Vector2(-6, -14), INK, 2.2)
			ci.draw_line(ey + Vector2(17, -11), ey + Vector2(6, -14), INK, 2.2)
			if mood == "shock":
				ci.draw_circle(c + Vector2(0, 14), 5.0, INK)
			else:
				ci.draw_arc(c + Vector2(0, 18), 6.0, PI + 0.5, TAU - 0.5, 8, INK, 2.2)
			if mood == "sad":
				ci.draw_circle(ey + Vector2(-12, 9), 2.4, Color("9ad0ff"))
		"stern", "shifty":
			ci.draw_line(ey + Vector2(-17, -14), ey + Vector2(-6, -10), INK, 2.4)
			ci.draw_line(ey + Vector2(17, -14), ey + Vector2(6, -10), INK, 2.4)
			ci.draw_line(c + Vector2(-6, 14), c + Vector2(6, 14), INK, 2.4)
		_:
			ci.draw_arc(c + Vector2(0, 11), 7.0, 0.35, PI - 0.35, 10, INK, 2.4)
			ci.draw_circle(c + Vector2(-19, 8), 4.5, Color(1.0, 0.5, 0.5, 0.4))
			ci.draw_circle(c + Vector2(19, 8), 4.5, Color(1.0, 0.5, 0.5, 0.4))


# ================================================================ v3 (drawn through a TriBatch)

const PANE_COLS := ["b8324e", "3a6ab8", "d8a830", "5aa860", "7a5ab8", "e07aa0"]   # ruby, cobalt, gold, green, violet, rose


static func _lit_row(prefix: String, pts: Array, r: float, s: float, kind: String, depth: float, cols = null, h := 0.0, off := false) -> Dictionary:
	## Lights prefix1..n at pts; cols is one colour, a list (cycled) or null.
	var out := {}
	for i in pts.size():
		var L := {"p": pts[i], "r": r, "s": s, "kind": kind, "depth": depth, "h": h}
		if cols is Array:
			L["color"] = cols[i % (cols as Array).size()]
		elif cols != null:
			L["color"] = str(cols)
		if off:
			L["off"] = true
		out["%s%d" % [prefix, i + 1]] = L
	return out


static func panel_v3(id: String) -> Dictionary:
	## The story draft's ten new panels (§4.2), with the anchors and lights
	## the script names. {} for an unknown id.
	match id:
		"orchard_vista":
			var sc := []
			for i in 6:
				var k := i / 5.0
				sc.append([lerpf(180, 1180, k), lerpf(40, 380, k)])
			var ov := {}
			for i in 6:
				ov["scorch%d" % (i + 1)] = {"p": sc[i], "r": 60.0 + (i % 3) * 15.0, "s": 0.5, "kind": "glow", "depth": 0.35, "color": "ff9a4a"}
			ov.merge(_lit_row("glowcap", [[420, 300], [700, 322], [980, 300], [1230, 318]], 50, 0.4, "glow", 0.7, "a8e0a0"))
			ov["lantern"] = {"p": [126, 236], "r": 110, "s": 0.85, "kind": "flame", "h": 12}
			return {"size": [1400, 460], "dark": [0.26, 0.30, 0.24], "motes": "spores", "lights": ov,
				"anchors": {"edge": {"p": [250, 330], "depth": 1.0, "h": 120}, "waxley": {"p": [380, 330], "depth": 1.0, "h": 160, "flip": true},
					"cone": {"p": [455, 330], "depth": 1.0, "h": 70}},
				"layers": [
					{"depth": 0.35, "tb": true, "shapes": [["grad", "161d16", "2a3624", 0, 460], ["roots_hang", 0, 1400, 34, "33301f"],
						["blob", 180, 22, 90, "c8783a44"], ["seam", sc, "c85a2a", "ff9a4a"], ["ellipse", 1215, 404, 80, 28, "0a0806"]]},
					{"depth": 0.7, "tb": true, "shapes": [["yews", [290, 520, 760, 950, 1130, 1310], 450, "cfc4a8", "9a8c70", "344628", "5a7a42"],
						["puffs", 10, 120, 1400, 170, 360, "8a9a7a44"], ["stones", [[370, 450], [630, 452], [860, 450], [1200, 452]], "8a8474"]]},
					{"depth": 1.0, "tb": true, "shapes": [["poly", [[-140, 520], [-140, 330], [520, 330], [560, 360], [586, 420], [600, 520]], "46402f"],
						["line", -140, 331, 522, 331, "6a6450", 4], ["root_lace", -100, 520, 330, "5a4a32"], ["tomb_tip", 175, 330, "8a8474"],
						["caps", [[318, 330], [334, 330], [348, 330]], "a8e0a0"], ["post", 120, 330, 242, "3a2e22"],
						["rect", -140, 400, 740, 120, "3a3526"]]},
				]}
		"heartwood":
			var cp := [[140, 180], [250, 260], [320, 150], [690, 160], [760, 260], [860, 190]]
			var hl := _lit_row("cage", cp, 70, 0.85, "cold", 0.8, "a8d0ff", 12.0)
			hl.merge(_lit_row("kept", cp, 90, 0.9, "flame", 0.8, null, 14.0, true))
			hl["trowel"] = {"p": [454, 456], "r": 60, "s": 0.3, "kind": "glow", "depth": 1.0, "color": "d8e8a0"}
			return {"size": [1000, 600], "dark": [0.22, 0.28, 0.22], "motes": "spores", "lights": hl,
				"anchors": {"boss": {"p": [620, 480], "depth": 1.0, "h": 360, "flip": true}, "spirit": {"p": [430, 470], "depth": 1.0, "h": 110, "flip": true},
					"actor": {"p": [260, 480], "depth": 1.0, "h": 120}},
				"layers": [
					{"depth": 0.4, "tb": true, "shapes": [["grad", "121a14", "1e2a1c", 0, 600], ["ribs", 500, 640, 5, 940, 700, "2a3624"],
						["skulls", 40, 960, [110, 160, 470], "6e6a58"]]},
					{"depth": 0.8, "tb": true, "shapes": [["trunk", 620, 520, 160, 250, "54462f", "3a3022"], ["roots_spread", 620, 480, "43372a"],
						["cages", cp, "4a3a28"]]},
					{"depth": 1.0, "tb": true, "shapes": [["rect", -100, 480, 1200, 180, "20261a"], ["line", -100, 480, 1100, 480, "465636", 4],
						["ellipse", 430, 482, 84, 20, "35362a"], ["moss", [[120, 484], [300, 488], [560, 486], [820, 488]], "3a5230"],
						["trowel", 454, 476], ["flowers", 360, 500, 476, "f4f0e8"], ["fruit", [[200, 486], [700, 488], [900, 484]], "d8d0b8"]]},
				]}
		"carillon_vista":
			var bells := [[500, 330], [500, 500], [500, 640], [500, 760]]
			var cl := _lit_row("bell", bells, 60, 0.35, "glow", 0.75, "bfe8ff")
			cl["clock"] = {"p": [620, 430], "r": 120, "s": 0.5, "kind": "glow", "depth": 0.75, "color": "bfe8ff"}
			cl["scorch"] = {"p": [360, 246], "r": 70, "s": 0.5, "kind": "glow", "depth": 1.0, "color": "ff9a4a"}
			cl.merge(_lit_row("ice", [[300, 300], [700, 560], [560, 720]], 30, 0.3, "glow", 0.75, "e8f6ff"))
			return {"size": [1000, 900], "dark": [0.22, 0.28, 0.40], "motes": "rime", "lights": cl,
				"anchors": {"edge": {"p": [420, 250], "depth": 1.0, "h": 120}, "waxley": {"p": [560, 250], "depth": 1.0, "h": 160, "flip": true}},
				"layers": [
					{"depth": 0.35, "tb": true, "shapes": [["grad", "1c2838", "0a0e18", 0, 900], ["mist", [260, 420, 600, 760], 1000, "8ab8d016"],
						["glitter", 40, 820, 900, 1000]]},
					{"depth": 0.75, "tb": true, "shapes": [["rock", 0, 1000, 130, "262a34"], ["tower_down", 500, 110, 860, 300, "7e8c9e", "58667a"],
						["belfries", bells, "141c28", "7a5a34", "cfe6f0"], ["clockface", 620, 430, 70], ["chains", [[560, 470], [680, 480]], 120, "5a6878"]]},
					{"depth": 1.0, "tb": true, "shapes": [["poly", [[-120, 250], [646, 250], [666, 266], [606, 286], [-120, 292]], "cfe6f0"],
						["poly", [[-120, 262], [640, 262], [604, 286], [-120, 292]], "8ab8d0"], ["root_lace", -100, 600, 250, "5a4a32"],
						["icicles", -80, 620, 288, "cfe6f0"]]},
				]}
		"escapement":
			var el := {}
			el["clock"] = {"p": [500, 90], "r": 140, "s": 0.5, "kind": "glow", "depth": 0.45, "color": "bfe8ff"}
			el["pend"] = {"p": [330, 262], "r": 40, "s": 0.4, "kind": "glow", "depth": 0.8, "color": "e8f6ff"}
			el["bench_lamp"] = {"p": [784, 300], "r": 90, "s": 0.9, "kind": "flame", "h": 10, "off": true}
			el["forge"] = {"p": [872, 316], "r": 120, "s": 0.9, "kind": "flame", "h": 16, "color": "f08a3a", "off": true}
			return {"size": [1000, 460], "dark": [0.22, 0.26, 0.38], "motes": "rime", "lights": el,
				"anchors": {"boss": {"p": [560, 350], "depth": 1.0, "h": 330}, "tickwell": {"p": [700, 350], "depth": 1.0, "h": 84, "flip": true},
					"bench": {"p": [820, 322], "depth": 1.0, "h": 70}, "actor": {"p": [300, 350], "depth": 1.0, "h": 120, "face": 1},
					"waxley": {"p": [220, 350], "depth": 1.0, "h": 160},
					# At the bench (boss_4_after's reforging): up close to Tickwell,
					# Waxby clear of Waxley's pack (int2 review: 95 apart, the pack
					# hid his staff).
					"actor_bench": {"p": [395, 350], "depth": 1.0, "h": 120, "face": 1}, "waxley_bench": {"p": [560, 350], "depth": 1.0, "h": 160}},
				"layers": [
					{"depth": 0.45, "tb": true, "shapes": [["grad", "182030", "262c3e", 0, 460], ["gear", 140, 170, 120, 16, "2e3444"],
						["gear", 860, 150, 140, 18, "2e3444"], ["gear", 700, 330, 80, 12, "343a4a"], ["gear", 260, 360, 70, 10, "343a4a"],
						["clocks", 6, 240, 760, 62, 17]]},
					{"depth": 0.8, "tb": true, "shapes": [["gear", 420, 200, 92, 15, "4a4e5e"], ["pallet", 420, 100, "5a5e6e"],
						["pendulum", 380, 10, 330, 262, 26], ["frost", [[420, 200], [330, 262]], "cfe6f044"]]},
					{"depth": 1.0, "tb": true, "shapes": [["rect", -100, 350, 1200, 170, "20222c"], ["grate", -100, 1100, 350, "343846"],
						["bench_top", 820, 350]]},
				]}
		"sanctum_vista":
			var sl := _lit_row("beam", [[420, 200], [640, 150], [860, 220], [1060, 160], [1260, 210]], 120, 0.4, "glow", 0.65, PANE_COLS)
			sl.merge(_lit_row("glint", [[320, 260], [760, 120], [1000, 300], [1320, 110]], 30, 0.35, "glow", 0.65, "f8f8ff"))
			return {"size": [1400, 460], "dark": [0.30, 0.26, 0.40], "motes": "shards", "lights": sl,
				"anchors": {"edge": {"p": [260, 330], "depth": 1.0, "h": 120}, "waxley": {"p": [140, 330], "depth": 1.0, "h": 160}},
				"layers": [
					{"depth": 0.3, "tb": true, "shapes": [["grad", "3a3450", "5a5070", 0, 460], ["bands", 1400, 460], ["specks", 60, 1400, 460, "c8c0e0"]]},
					{"depth": 0.65, "tb": true, "shapes": [["panes", [[480, 190, 170, 120, 0.3, 0], [700, 130, 140, 170, -0.2, 1],
						[900, 240, 200, 130, 0.15, 2], [1100, 150, 150, 150, -0.35, 3], [1300, 230, 170, 110, 0.25, 4], [620, 330, 120, 90, -0.1, 5]]],
						["strips", [[560, 120, 40], [800, 80, 60], [1180, 90, 50]], "140e1c"]]},
					{"depth": 0.65, "lit": true, "tb": true, "shapes": [["beams", [[420, 200], [640, 150], [860, 220], [1060, 160], [1260, 210]]]]},
					{"depth": 1.0, "tb": true, "shapes": [["poly", [[-140, 400], [-140, 330], [420, 330], [470, 352], [490, 380], [430, 400]], "8a9ab8"],
						["line", -140, 331, 422, 331, "c8d4e8", 3], ["cracks", [[80, 332], [260, 334], [380, 332]], "c8d4e8"],
						["ellipse", 960, 474, 280, 30, "05040a"], ["arc", 960, 474, 280, 30, "4a3a7a"]]},
				]}
		"glass_throne":
			var gl := {}
			gl["rose_center"] = {"p": [500, 170], "r": 380, "s": 0.6, "kind": "glow", "depth": 0.5, "color": "f0f4ff"}
			gl.merge(_lit_row("pane", [[360, 200], [390, 120], [460, 80], [540, 80], [610, 120], [640, 200]], 160, 0.55, "glow", 1.0, PANE_COLS, 0.0, true))
			gl.merge(_lit_row("step", [[440, 372], [500, 396], [560, 420], [620, 444]], 90, 0.4, "glow", 1.0, ["e07aa0", "d8a830", "3a6ab8", "5aa860"], 0.0, true))
			return {"size": [1000, 460], "dark": [0.26, 0.24, 0.40], "motes": "shards", "lights": gl,
				"anchors": {"saint": {"p": [500, 350], "depth": 1.0, "h": 300}, "actor": {"p": [280, 350], "depth": 0.96, "h": 120}},
				"layers": [
					{"depth": 0.5, "tb": true, "shapes": [["grad", "1c1830", "2a2442", 0, 460], ["rose_frame", 500, 170, 170, "4a4260", "120e1e"]]},
					{"depth": 0.5, "lit": true, "tb": true, "shapes": [["rays", 500, 170, 16, 560, "f0f4ff1c"]]},
					{"depth": 1.0, "tb": true, "shapes": [["rect", -100, 350, 1200, 170, "36304a"], ["rect", 330, 370, 340, 16, "443e58"],
						["rect", 380, 394, 300, 16, "4e4864"], ["rect", 430, 418, 260, 16, "443e58"], ["frame_arch", 500, 350, 150, 320, "241e32"],
						["bits", [[330, 352], [390, 360], [610, 356], [680, 352], [760, 364]], "c8d0e8"]]},
				]}
		"glass_truth":
			return {"size": [1000, 460], "dark": null, "motes": "", "shimmer": true, "lights": {}, "anchors": {},
				"layers": [
					{"depth": 1.0, "lit": true, "tb": true, "shapes": [["rect", -100, -100, 1200, 660, "1a1026"], ["truth", 500, 446, 900, 430]]},
					{"depth": 1.12, "lit": true, "tb": true, "rect": [-100, -46, 1200, 552], "shapes": [["pillar", 30, 90], ["pillar", 970, 90]]},
				]}
		"hushdeep_vista":
			var hv := {"far_flame": {"p": [1020, 250], "r": 50, "s": 0.5, "kind": "glow", "depth": 0.7, "color": "ffd84a"}}
			hv.merge(_lit_row("stair", [[70, 150], [130, 200], [185, 250], [235, 300]], 50, 0.3, "glow", 1.0, PANE_COLS))
			return {"size": [1400, 460], "dark": [0.10, 0.09, 0.16], "motes": "", "lights": hv,
				"anchors": {"edge": {"p": [320, 330], "depth": 1.0, "h": 120}},
				"layers": [
					{"depth": 0.3, "tb": true, "shapes": [["rect", -300, -100, 2000, 700, "05040a"], ["ripples", 700, 140, 8, 90, "1a142830"]]},
					{"depth": 0.7, "tb": true, "shapes": [["rect", -300, 230, 2000, 400, "07060e"], ["line", -300, 230, 1700, 230, "1a1428", 2],
						["arc", 1020, 254, 16, 3, "4a3a7a88"], ["circle", 1020, 252, 3, "ffd84a"]]},
					{"depth": 1.0, "tb": true, "shapes": [["poly", [[-140, 520], [-140, 330], [700, 334], [1540, 346], [1540, 520]], "0e0c14"],
						["treads", [[20, 122], [80, 162], [140, 202], [194, 242], [242, 282], [290, 322]], 90, "4a3a7a"], ["reed", 520, 334, 60, "2a2436"]]},
				]}
		"hushdeep_heart":
			var hh := _lit_row("stair", [[200, 130], [280, 200], [370, 270], [460, 340], [560, 410], [660, 480]], 130, 0.55, "glow", 0.85, PANE_COLS, 0.0, true)
			var sd := 0.85
			return {"size": [1800, 600], "dark": [0.08, 0.08, 0.14], "motes": "", "lights": hh,
				"anchors": {"eye": {"p": [1450, 330], "depth": 1.0, "h": 380}, "wick": {"p": [1060, 508], "depth": 1.0, "h": 60},
					"actor": {"p": [860, 500], "depth": 1.0, "h": 120}, "actor_give": {"p": [1000, 500], "depth": 1.0, "h": 120},
					"carry": {"p": [340, 270], "depth": sd, "h": 130}, "waxley": {"p": [262, 214], "depth": sd, "h": 120},
					"tollgrave": {"p": [450, 345], "depth": sd, "h": 170}, "tickwell": {"p": [540, 410], "depth": sd, "h": 70},
					"town": {"p": [150, 168], "depth": sd, "h": 110}, "lost": {"p": [640, 470], "depth": sd, "h": 80}},
				"layers": [
					{"depth": 0.3, "tb": true, "shapes": [["rect", -300, -100, 2400, 800, "05040a"], ["ripples", 1300, 200, 8, 110, "1a142828"]]},
					{"depth": 0.7, "tb": true, "shapes": [["rect", -300, 360, 2400, 400, "07060e"], ["line", -300, 360, 2100, 360, "1a1428", 2],
						["ripples", 1450, 420, 6, 70, "2a224040"]]},
					{"depth": 0.85, "tb": true, "shapes": [["treads", [[60, 120], [150, 168], [262, 214], [340, 270], [450, 345], [540, 410], [640, 470], [730, 520]], 130, "3a3058"]]},
					{"depth": 1.0, "tb": true, "shapes": [["poly", [[520, 640], [600, 500], [1100, 500], [1190, 640]], "0c0a12"],
						["line", 600, 501, 1100, 501, "2a2440", 3], ["ellipse", 1060, 512, 46, 9, "d8ccb070"]]},
				]}
		"homecoming":
			var hl := {}
			var lamps := []
			for i in 8:
				lamps.append([160 + i * 180, 236 + (i % 2) * 14])
			hl.merge(_lit_row("lamp", lamps, 90, 0.9, "flame", 1.0, null, 9.0))
			var bun := []
			for i in 10:
				var u := i / 9.0
				bun.append([lerpf(300, 1300, u), 130 + sin(u * PI) * 40.0])
			hl.merge(_lit_row("bunting", bun, 40, 0.6, "flame", 0.55, null, 6.0))
			hl["rose"] = {"p": [800, 110], "r": 220, "s": 0.6, "kind": "glow", "depth": 0.55, "color": "ffd8e8"}
			hl["sun"] = {"p": [1450, 110], "r": 400, "s": 0.6, "kind": "glow", "depth": 0.25}
			return {"size": [1600, 460], "dark": [0.45, 0.42, 0.55], "motes": "embers", "lights": hl,
				"anchors": {"tollgrave": {"p": [380, 316], "depth": 1.0, "h": 190}, "taper": {"p": [560, 316], "depth": 1.0},
					"actor": {"p": [670, 316], "depth": 1.0, "h": 120, "face": -1}, "hollin": {"p": [780, 316], "depth": 1.0, "h": 120, "flip": true},
					"waxley": {"p": [960, 316], "depth": 1.0, "h": 160, "flip": true}, "tickwell": {"p": [1070, 316], "depth": 1.0, "h": 84, "flip": true}},
				"layers": [
					{"depth": 0.25, "tb": true, "shapes": [["grad", "a8c4e4", "ffd9a0", 0, 280], ["grad", "ffd9a0", "f2a57a", 280, 460],
						["circle", 1450, 110, 52, "fff4d0"], ["clouds", [[300, 90], [620, 60], [1100, 100]], "f4b8c8"]]},
					{"depth": 0.55, "tb": true, "shapes": [["minster", 800, 330, "7a6a9a", "5a4a7a"], ["rose_glass", 800, 110, 34],
						["sapling", 686, 330], ["strings", bun, "3a2e48"]]},
					{"depth": 1.0, "tb": true, "shapes": [["rect", -100, 316, 1800, 200, "5e4e60"], ["line", -100, 316, 1700, 316, "7a6a7c", 4],
						["snow", [[120, 326], [520, 332], [900, 328], [1380, 332]], "f4f0f8"], ["posts_tb", lamps, 316, "2e2438"],
						["well", 230, 316], ["table", 1260, 316], ["folk_tb", [[70, 316], [120, 316], [1480, 316], [1530, 316]], "3a3248"],
						["cat_tb", 1500, 278]]},
				]}
	return {}


static func _cc(hex) -> Color:
	return Color(str(hex))


static func _pts(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in a:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


static func _draw_tb(ci: CanvasItem, layer: Dictionary) -> void:
	## A v3 stand-in layer: every shape into one TriBatch, flushed once.
	var tb := TriBatch.new()
	for s in layer.get("shapes", []):
		_shape_tb(tb, s)
	tb.flush(ci)


static func _shape_tb(tb, s: Array) -> void:
	match str(s[0]):
		"rect":
			tb.rect(Rect2(s[1], s[2], s[3], s[4]), _cc(s[5]))
		"grad":
			var a := _cc(s[1])
			var b := _cc(s[2])
			var y0 := float(s[3])
			var y1 := float(s[4])
			tb.tri3(Vector2(-400, y0), Vector2(3200, y0), Vector2(3200, y1), a, a, b)
			tb.tri3(Vector2(-400, y0), Vector2(3200, y1), Vector2(-400, y1), a, b, b)
		"circle":
			tb.circle(Vector2(s[1], s[2]), float(s[3]), _cc(s[4]), 20)
		"ellipse":
			tb.ellipse(Vector2(s[1], s[2]), float(s[3]), float(s[4]), _cc(s[5]), 24)
		"arc":
			# An ellipse's outline (a pale rim).
			var pts := PackedVector2Array()
			for k in 33:
				var a := TAU * k / 32.0
				pts.append(Vector2(float(s[1]) + cos(a) * float(s[3]), float(s[2]) + sin(a) * float(s[4])))
			tb.polyline(pts, 2.5, _cc(s[5]))
		"poly":
			tb.concave(_pts(s[1]), _cc(s[2]))
		"line":
			tb.line(Vector2(s[1], s[2]), Vector2(s[3], s[4]), float(s[6]), _cc(s[5]))
		"blob":
			for k in 3:
				tb.circle(Vector2(s[1], s[2]), float(s[3]) * (1.0 - k * 0.3), _cc(s[4]), 20)
		"roots_hang":
			# Braided roots hanging from a cavern roof.
			var col := _cc(s[4])
			var n := int(s[3])
			for i in n:
				var x := lerpf(float(s[1]), float(s[2]), (i + 0.5) / n) + (_h(i, 3) - 0.5) * 30.0
				var ln := 60.0 + _h(i, 7) * 150.0
				var pts := PackedVector2Array()
				for k in 7:
					var u := k / 6.0
					pts.append(Vector2(x + sin(u * 5.0 + i) * 9.0, -10.0 + u * ln))
				tb.polyline(pts, 10.0 - _h(i, 1) * 5.0, col)
			tb.rect(Rect2(-400, -20, 3600, 38), col.darkened(0.2))
		"seam":
			# The scorch: a glowing seam, charred at its rims.
			var pts := _pts(s[1])
			tb.polyline(pts, 20.0, _cc(s[2]))
			tb.polyline(pts, 8.0, _cc(s[3]))
		"yews":
			var bark := _cc(s[3])
			var shade := _cc(s[4])
			for i in (s[1] as Array).size():
				var x := float(s[1][i])
				var foot := float(s[2])
				var h := 170.0 + _h(i, 2) * 60.0
				tb.convex(_pts([[x - 26, foot], [x - 16, foot - h], [x + 16, foot - h], [x + 26, foot]]), bark)
				tb.convex(_pts([[x + 6, foot], [x + 8, foot - h], [x + 16, foot - h], [x + 26, foot]]), shade)
				for k in 5:
					var c := Vector2(x + (k - 2) * 34.0, foot - h - 10.0 + absf(k - 2) * 18.0)
					tb.circle(c, 44.0 - absf(k - 2) * 6.0, _cc(s[5]), 16)
				for k in 4:
					var c := Vector2(x - 44.0 + k * 30.0, foot - h + 26.0 + (k % 2) * 12.0)
					tb.circle(c, 30.0, _cc(s[6]), 16)
				# Bone fruit: small skulls hanging under the boughs.
				for k in 4:
					var c := Vector2(x - 48.0 + k * 32.0, foot - h + 52.0 + (k % 2) * 10.0)
					tb.line(c - Vector2(0, 14), c, 1.5, shade)
					tb.circle(c, 6.5, Color("e8e0c8"), 12)
					tb.circle(c + Vector2(-2.2, -0.5), 1.4, INK, 6)
					tb.circle(c + Vector2(2.2, -0.5), 1.4, INK, 6)
		"puffs":
			for i in int(s[1]):
				var c := Vector2(lerpf(float(s[2]), float(s[3]), _h(i, 5)), lerpf(float(s[4]), float(s[5]), _h(5, i)))
				tb.circle(c, 26.0 + _h(i, 9) * 20.0, _cc(s[6]), 16)
		"stones":
			for p in s[1]:
				tb.rect(Rect2(float(p[0]) - 12, float(p[1]) - 30, 24, 30), _cc(s[2]))
				tb.circle(Vector2(float(p[0]), float(p[1]) - 30), 12.0, _cc(s[2]), 12)
		"root_lace":
			var col := _cc(s[4])
			var y := float(s[3])
			var x := float(s[1])
			var i := 0
			while x < float(s[2]):
				tb.polyline(_pts([[x, y + 2], [x + 30, y - 6 - _h(i, 1) * 8.0], [x + 70, y + 3]]), 5.0, col)
				x += 60.0 + _h(i, 4) * 30.0
				i += 1
		"tomb_tip":
			var p := Vector2(s[1], s[2])
			tb.convex(PackedVector2Array([p + Vector2(-22, 0), p + Vector2(-6, -52), p + Vector2(18, -46), p + Vector2(24, 0)]), _cc(s[3]))
			tb.line(p + Vector2(-2, -34), p + Vector2(10, -32), 3.0, INK)
		"caps":
			for c in s[1]:
				var p := Vector2(float(c[0]), float(c[1]))
				tb.rect(Rect2(p.x - 1.5, p.y - 10, 3, 10), Color("d8d0b8"))
				tb.ellipse(p + Vector2(0, -11), 8.0, 5.0, _cc(s[2]), 12)
		"post":
			var x := float(s[1])
			tb.line(Vector2(x, float(s[2])), Vector2(x + 6, float(s[3])), 6.0, _cc(s[4]))
			tb.rect(Rect2(x - 4, float(s[3]) - 16, 20, 18), _cc(s[4]))
			tb.rect(Rect2(x + 1, float(s[3]) - 13, 10, 12), Color("f7b64a"))
		"ribs":
			var c := Vector2(s[1], s[2])
			for i in int(s[3]):
				var k := 1.0 - i * 0.14
				tb.polyline(arch_pts(c.x, c.y, float(s[4]) * k, float(s[5]) * k, 10), maxf(26.0 * k, 6.0), _cc(s[6]).darkened(i * 0.07))
		"skulls":
			for y in s[3]:
				var x := float(s[1])
				var i := 0
				while x < float(s[2]):
					tb.circle(Vector2(x, float(y)), 8.0, _cc(s[4]), 10)
					tb.circle(Vector2(x - 3, float(y) - 1), 1.8, INK, 6)
					tb.circle(Vector2(x + 3, float(y) - 1), 1.8, INK, 6)
					x += 26.0 + _h(i, float(y)) * 8.0
					i += 1
		"trunk":
			var x := float(s[1])
			var foot := float(s[2])
			tb.convex(_pts([[x - float(s[4]) * 0.5, foot], [x - float(s[3]) * 0.5, -40], [x + float(s[3]) * 0.5, -40], [x + float(s[4]) * 0.5, foot]]), _cc(s[5]))
			tb.convex(_pts([[x + float(s[4]) * 0.1, foot], [x + float(s[3]) * 0.15, -40], [x + float(s[3]) * 0.5, -40], [x + float(s[4]) * 0.5, foot]]), _cc(s[6]))
		"roots_spread":
			var o := Vector2(s[1], s[2])
			for i in 7:
				var a := lerpf(-2.9, -0.25, i / 6.0)
				var e := o + Vector2(cos(a), -sin(a) * 0.12) * (260.0 + _h(i, 2) * 200.0)
				tb.polyline(PackedVector2Array([o + Vector2((i - 3) * 20.0, -30), o.lerp(e, 0.5) + Vector2(0, -16), e]), 18.0 - i * 1.2, _cc(s[3]))
		"cages":
			for c in s[1]:
				var p := Vector2(float(c[0]), float(c[1]))
				tb.line(p + Vector2(0, -80), p + Vector2(0, -26), 5.0, _cc(s[2]))
				tb.ring(p, 24.0, 5.0, _cc(s[2]), 16)
				for k in 4:
					var x := -16.0 + k * 10.7
					tb.line(p + Vector2(x, -20), p + Vector2(x, 22), 3.0, _cc(s[2]))
		"moss":
			for p in s[1]:
				tb.ellipse(Vector2(float(p[0]), float(p[1])), 60.0, 8.0, _cc(s[2]), 16)
		"trowel":
			var p := Vector2(s[1], s[2])
			tb.line(p + Vector2(0, -30), p + Vector2(0, -8), 4.0, Color("6a4a2a"))
			tb.convex(PackedVector2Array([p + Vector2(-7, -8), p + Vector2(7, -8), p + Vector2(0, 8)]), Color("a8a8b0"))
		"flowers":
			for i in 14:
				var x := lerpf(float(s[1]), float(s[2]), _h(i, 11))
				var y := float(s[3]) - _h(11, i) * 10.0
				tb.line(Vector2(x, y), Vector2(x, y + 10), 1.5, Color("5a7a42"))
				tb.circle(Vector2(x, y), 3.2, _cc(s[4]), 8)
		"fruit":
			for p in s[1]:
				tb.circle(Vector2(float(p[0]), float(p[1]) - 6), 7.0, _cc(s[2]), 12)
		"mist":
			for y in s[1]:
				tb.rect(Rect2(-400, float(y), float(s[2]) + 800, 40), _cc(s[3]))
		"glitter":
			for i in int(s[1]):
				var p := Vector2(_h(i, 4) * float(s[4]), lerpf(float(s[2]), float(s[3]), _h(4, i)))
				tb.rect(Rect2(p, Vector2(4, 4)), _cc(PANE_COLS[i % PANE_COLS.size()]))
		"rock":
			var pts := [[-400, -100], [3200, -100], [3200, float(s[3]) - 30.0]]
			var x := float(s[2]) + 200.0
			var i := 0
			while x > float(s[1]) - 300.0:
				pts.append([x, float(s[3]) + (_h(i, 6) - 0.5) * 40.0])
				x -= 90.0
				i += 1
			pts.append([-400, float(s[3])])
			tb.concave(_pts(pts), _cc(s[4]))
		"tower_down":
			var cx := float(s[1])
			var top := float(s[2])
			var tip := float(s[3])
			var w := float(s[4])
			tb.convex(_pts([[cx - w * 0.5, top], [cx + w * 0.5, top], [cx + w * 0.34, tip - 190], [cx - w * 0.34, tip - 190]]), _cc(s[5]))
			tb.convex(_pts([[cx + w * 0.12, top], [cx + w * 0.5, top], [cx + w * 0.34, tip - 190], [cx + w * 0.08, tip - 190]]), _cc(s[6]))
			tb.convex(_pts([[cx - w * 0.34, tip - 190], [cx + w * 0.34, tip - 190], [cx, tip]]), _cc(s[6]))
			var y := top + 30.0
			while y < tip - 200.0:
				tb.line(Vector2(cx - w * 0.44, y), Vector2(cx + w * 0.44, y), 2.0, _cc(s[6]).darkened(0.2))
				y += 34.0
		"belfries":
			for b in s[1]:
				var p := Vector2(float(b[0]), float(b[1]))
				tb.concave(arch_pts(p.x, p.y + 50.0, 110.0, 100.0, 8), _cc(s[2]))
				# A bell hanging mouth-down: its crown up, its lip under.
				tb.convex(PackedVector2Array([p + Vector2(-16, -20), p + Vector2(16, -20), p + Vector2(30, 30), p + Vector2(-30, 30)]), _cc(s[3]))
				tb.ellipse(p + Vector2(0, -20), 16.0, 10.0, _cc(s[3]), 14)
				tb.rect(Rect2(p.x - 32, p.y + 26, 64, 8), _cc(s[3]).darkened(0.25))
				tb.rect(Rect2(p.x - 30, p.y - 26, 60, 6), Color(_cc(s[4]), 0.6))
				tb.convex(PackedVector2Array([p + Vector2(26, 30), p + Vector2(46, 34), p + Vector2(28, 36)]), Color(_cc(s[4]), 0.8))
		"clockface":
			var c := Vector2(s[1], s[2])
			var r := float(s[3])
			tb.circle(c, r + 8.0, Color("5a6878"), 32)
			tb.circle(c, r, Color("dde6ee"), 32)
			for k in 12:
				var d := Vector2(0, -1).rotated(TAU * k / 12.0)
				tb.line(c + d * r * 0.78, c + d * r * 0.92, 3.0, Color("3a4250"))
			# One minute to twelve, frozen.
			tb.line(c, c + Vector2(0, -1).rotated(-0.1) * r * 0.8, 4.0, INK)
			tb.line(c, c + Vector2(0, -1).rotated(-0.03) * r * 0.55, 6.0, INK)
			tb.ring(c, r, 3.0, Color("f4fbff"), 32)
		"chains":
			for p in s[1]:
				var a := Vector2(float(p[0]), float(p[1]))
				tb.line(a, a + Vector2(6, float(s[2])), 3.0, _cc(s[3]))
		"icicles":
			var x := float(s[1])
			var i := 0
			while x < float(s[2]):
				var ln := 16.0 + _h(i, 8) * 30.0
				tb.tri(Vector2(x - 5, float(s[3]) - 2), Vector2(x + 5, float(s[3]) - 2), Vector2(x, float(s[3]) + ln), _cc(s[4]))
				x += 26.0 + _h(8, i) * 20.0
				i += 1
		"gear":
			var c := Vector2(s[1], s[2])
			var r := float(s[3])
			var col := _cc(s[5])
			tb.circle(c, r, col, 28)
			for k in int(s[4]):
				var d := Vector2(1, 0).rotated(TAU * k / float(s[4]))
				tb.convex(PackedVector2Array([c + d * r * 0.95 + d.orthogonal() * 7.0, c + d * (r + 12.0) + d.orthogonal() * 5.0,
						c + d * (r + 12.0) - d.orthogonal() * 5.0, c + d * r * 0.95 - d.orthogonal() * 7.0]), col)
			tb.circle(c, r * 0.62, col.darkened(0.25), 24)
			tb.circle(c, r * 0.18, col.lightened(0.2), 12)
		"clocks":
			for k in int(s[1]):
				var c := Vector2(lerpf(float(s[2]), float(s[3]), k / maxf(float(s[1]) - 1.0, 1.0)), float(s[4]))
				var r := float(s[5])
				tb.circle(c, r + 3.0, Color("4a5060"), 20)
				tb.circle(c, r, Color("b8c4d0"), 20)
				tb.line(c, c + Vector2(0, -r * 0.8).rotated(-0.1), 2.0, INK)
				tb.line(c, c + Vector2(0, -r * 0.5), 3.0, INK)
		"pallet":
			var c := Vector2(s[1], s[2])
			tb.convex(PackedVector2Array([c + Vector2(-70, 30), c + Vector2(-10, -12), c + Vector2(10, -12), c + Vector2(70, 30), c + Vector2(52, 40), c + Vector2(0, 8), c + Vector2(-52, 40)]), _cc(s[3]))
		"pendulum":
			var a := Vector2(s[1], s[2])
			var b := Vector2(s[3], s[4])
			tb.line(a, b, 6.0, Color("6a5a3a"))
			tb.circle(b, float(s[5]), Color("b8862a"), 24)
			tb.circle(b, float(s[5]) * 0.6, Color("d8a850"), 18)
		"frost":
			for p in s[1]:
				tb.circle(Vector2(float(p[0]), float(p[1])), 60.0, _cc(s[2]), 20)
		"grate":
			var x := float(s[1])
			while x < float(s[2]):
				tb.line(Vector2(x, float(s[3])), Vector2(x, float(s[3]) + 40.0), 3.0, _cc(s[4]))
				x += 28.0
			tb.line(Vector2(float(s[1]), float(s[3]) + 1.0), Vector2(float(s[2]), float(s[3]) + 1.0), 4.0, _cc(s[4]).lightened(0.2))
		"bench_top":
			var p := Vector2(s[1], s[2])
			tb.rect(Rect2(p.x - 90, p.y - 30, 180, 10), Color("5a3e2a"))
			tb.rect(Rect2(p.x - 84, p.y - 20, 10, 20), Color("4a3222"))
			tb.rect(Rect2(p.x + 74, p.y - 20, 10, 20), Color("4a3222"))
			tb.rect(Rect2(p.x - 70, p.y - 44, 22, 14), Color("6a6e7a"))           # the vise
			tb.rect(Rect2(p.x + 24, p.y - 40, 44, 10), Color("2a2c34"))           # the anvil
			tb.rect(Rect2(p.x + 36, p.y - 30, 20, 8), Color("2a2c34"))
			tb.rect(Rect2(p.x - 42, p.y - 48, 10, 18), Color("3a2a1a"))           # the lamp
			tb.ellipse(Vector2(p.x + 52, p.y - 28), 18.0, 8.0, Color("3a2a22"), 14)   # the forge pot
		"bands":
			for k in 5:
				tb.rect(Rect2(-400, 60.0 + k * 70.0, float(s[1]) + 800.0, 18), Color(_cc(PANE_COLS[k]), 0.06))
		"specks":
			for i in int(s[1]):
				tb.rect(Rect2(_h(i, 2) * float(s[2]), _h(2, i) * float(s[3]), 3, 3), Color(_cc(s[4]), 0.5))
		"panes":
			for p in s[1]:
				var c := Vector2(float(p[0]), float(p[1]))
				var hw := float(p[2]) * 0.5
				var hh := float(p[3]) * 0.5
				var rot := float(p[4])
				var col := _cc(PANE_COLS[int(p[5]) % PANE_COLS.size()])
				var q := PackedVector2Array()
				for v in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
					q.append(c + (v as Vector2).rotated(rot))
				tb.convex(q, Color(col, 0.55))
				tb.polyline(q, 7.0, Color("140e1c"), true)
				tb.line(q[0].lerp(q[1], 0.5), q[3].lerp(q[2], 0.5), 5.0, Color("140e1c"))
		"strips":
			for p in s[1]:
				tb.polyline(_pts([[p[0], p[1]], [float(p[0]) + 10, float(p[1]) + float(p[2])], [float(p[0]) - 4, float(p[1]) + float(p[2]) * 1.8]]), 4.0, _cc(s[2]))
		"beams":
			var i := 0
			for p in s[1]:
				var c := Vector2(float(p[0]), float(p[1]))
				tb.convex(PackedVector2Array([c + Vector2(-30, -260), c + Vector2(30, -260), c + Vector2(110, 300), c + Vector2(40, 300)]),
						Color(_cc(PANE_COLS[i % PANE_COLS.size()]), 0.16))
				i += 1
		"cracks":
			for p in s[1]:
				var o := Vector2(float(p[0]), float(p[1]))
				tb.polyline(PackedVector2Array([o, o + Vector2(14, 12), o + Vector2(8, 26), o + Vector2(22, 40)]), 2.0, _cc(s[2]))
		"rose_frame":
			var c := Vector2(s[1], s[2])
			var r := float(s[3])
			tb.circle(c, r + 18.0, _cc(s[4]), 40)
			tb.circle(c, r, _cc(s[5]), 40)
			for k in 16:
				var d := Vector2(1, 0).rotated(TAU * k / 16.0)
				tb.line(c + d * r * 0.3, c + d * r, 7.0, _cc(s[4]))
				tb.ring(c + d * r * 0.66, r * 0.16, 5.0, _cc(s[4]), 12)
			tb.ring(c, r * 0.3, 8.0, _cc(s[4]), 24)
		"rays":
			var c := Vector2(s[1], s[2])
			for k in int(s[3]):
				var a := PI * 0.05 + PI * 0.9 * k / maxf(float(s[3]) - 1.0, 1.0)
				var d := Vector2(cos(a), sin(a))
				tb.tri(c, c + d.rotated(-0.04) * float(s[4]), c + d.rotated(0.04) * float(s[4]), _cc(s[5]))
		"frame_arch":
			tb.polyline(arch_pts(float(s[1]), float(s[2]), float(s[3]), float(s[4]), 10), 10.0, _cc(s[5]))
		"bits":
			for p in s[1]:
				var o := Vector2(float(p[0]), float(p[1]))
				tb.tri(o, o + Vector2(10, -4), o + Vector2(4, 6), _cc(s[2]))
		"truth":
			_truth(tb, float(s[1]), float(s[2]), float(s[3]), float(s[4]))
		"pillar":
			var x := float(s[1])
			var w := float(s[2])
			tb.rect(Rect2(x - w * 0.5, -60, w, 600), Color("2c2238"))
			tb.rect(Rect2(x - w * 0.5 + 10, -60, 8, 600), Color("3a2e48"))
			tb.rect(Rect2(x - w * 0.5 - 12, 20, w + 24, 22), Color("2a2036"))
			tb.rect(Rect2(x - w * 0.5 - 12, 430, w + 24, 22), Color("2a2036"))
		"ripples":
			var c := Vector2(s[1], s[2])
			for k in int(s[3]):
				var r := 40.0 + k * float(s[4])
				tb.ring(c, r, 2.0, _cc(s[5]), 48, PI * 0.05, PI * 0.95)
				tb.ring(c, r, 2.0, _cc(s[5]), 48, PI * 1.05, PI * 1.95)
		"treads":
			var i := 0
			for p in s[1]:
				var c := Vector2(float(p[0]), float(p[1]))
				var w := float(s[2])
				tb.convex(PackedVector2Array([c + Vector2(-w * 0.5, 0), c + Vector2(w * 0.5, 0), c + Vector2(w * 0.44, 12), c + Vector2(-w * 0.44, 12)]),
						Color(_cc(PANE_COLS[i % PANE_COLS.size()]), 0.5))
				tb.line(c + Vector2(-w * 0.5, 0), c + Vector2(w * 0.5, 0), 2.0, Color(_cc(s[3]), 0.9))
				i += 1
		"reed":
			var p := Vector2(s[1], s[2])
			tb.polyline(PackedVector2Array([p, p + Vector2(4, -float(s[3]) * 0.6), p + Vector2(14, -float(s[3]))]), 3.0, _cc(s[4]))
		"clouds":
			for p in s[1]:
				var c := Vector2(float(p[0]), float(p[1]))
				tb.ellipse(c, 70.0, 16.0, Color(_cc(s[2]), 0.8), 20)
				tb.ellipse(c + Vector2(30, -8), 40.0, 14.0, Color(_cc(s[2]), 0.8), 16)
		"minster":
			# Evenbell risen, in lilac stone: a nave, two towers, a belfry.
			var cx := float(s[1])
			var foot := float(s[2])
			var col := _cc(s[3])
			var sh := _cc(s[4])
			tb.rect(Rect2(cx - 220, foot - 170, 440, 170), col)
			tb.convex(_pts([[cx - 230, foot - 170], [cx, foot - 260], [cx + 230, foot - 170]]), sh)
			for sx in [-1.0, 1.0]:
				var tx: float = cx + sx * 190.0
				tb.rect(Rect2(tx - 34, foot - 290, 68, 290), col.lightened(0.05))
				tb.convex(_pts([[tx - 40, foot - 290], [tx, foot - 370], [tx + 40, foot - 290]]), sh)
			tb.rect(Rect2(cx - 30, foot - 340, 60, 90), col)
			tb.convex(_pts([[cx - 36, foot - 340], [cx, foot - 400], [cx + 36, foot - 340]]), sh)
			tb.concave(arch_pts(cx, foot, 70.0, 110.0, 8), Color("2a2238"))
		"rose_glass":
			var c := Vector2(s[1], s[2])
			var r := float(s[3])
			for k in 6:
				tb.fan(c, _arc_pts(c, r, TAU * k / 6.0, TAU * (k + 1) / 6.0, 6), _cc(PANE_COLS[k]))
			tb.ring(c, r, 4.0, Color("3a2e48"), 24)
			tb.circle(c, r * 0.25, Color("ffe8a0"), 12)
		"sapling":
			var p := Vector2(s[1], s[2])
			tb.line(p, p + Vector2(0, -70), 5.0, Color("5a4a36"))
			for k in 5:
				var c := p + Vector2((k - 2) * 14.0, -70.0 - absf(k - 2) * -8.0)
				tb.circle(c, 16.0, Color("6a8a4a"), 14)
				tb.rect(Rect2(c.x - 2, c.y - 12, 4, 8), Color("f4ecd8"))
		"strings":
			var pts := _pts(s[1])
			tb.polyline(pts, 2.0, _cc(s[2]))
		"snow":
			for p in s[1]:
				tb.ellipse(Vector2(float(p[0]), float(p[1])), 80.0, 5.0, Color(_cc(s[2]), 0.7), 16)
		"posts_tb":
			for lp in s[1]:
				tb.rect(Rect2(float(lp[0]) - 3.0, float(lp[1]) + 6.0, 6.0, float(s[2]) - float(lp[1]) - 6.0), _cc(s[3]))
				tb.rect(Rect2(float(lp[0]) - 9.0, float(lp[1]) - 2.0, 18.0, 10.0), _cc(s[3]))
		"well":
			var p := Vector2(s[1], s[2])
			tb.rect(Rect2(p.x - 36, p.y - 34, 72, 34), Color("6a5a6a"))
			tb.rect(Rect2(p.x - 40, p.y - 38, 80, 8), Color("7a6a7c"))
			tb.rect(Rect2(p.x - 32, p.y - 90, 6, 54), Color("4a3a2a"))
			tb.rect(Rect2(p.x + 26, p.y - 90, 6, 54), Color("4a3a2a"))
			tb.convex(_pts([[p.x - 46, p.y - 88], [p.x, p.y - 118], [p.x + 46, p.y - 88]]), Color("5a3a3a"))
		"table":
			var p := Vector2(s[1], s[2])
			tb.rect(Rect2(p.x - 150, p.y - 40, 300, 10), Color("7a5236"))
			tb.rect(Rect2(p.x - 140, p.y - 30, 8, 30), Color("5a3a26"))
			tb.rect(Rect2(p.x + 132, p.y - 30, 8, 30), Color("5a3a26"))
			tb.ellipse(Vector2(p.x - 100, p.y - 46), 20.0, 8.0, Color("d8a050"), 16)     # a pie
			tb.ellipse(Vector2(p.x - 40, p.y - 48), 22.0, 10.0, Color("c8904a"), 16)     # a loaf
			tb.convex(_pts([[p.x + 20, p.y - 40], [p.x + 60, p.y - 40], [p.x + 60, p.y - 64]]), Color("f0d060"))   # a whole cheese
			tb.ellipse(Vector2(p.x + 110, p.y - 46), 20.0, 8.0, Color("d8a050"), 16)
		"folk_tb":
			for p in s[1]:
				var o := Vector2(float(p[0]), float(p[1]))
				tb.convex(PackedVector2Array([o + Vector2(-18, 0), o + Vector2(-12, -44), o + Vector2(12, -44), o + Vector2(18, 0)]), _cc(s[2]))
				tb.circle(o + Vector2(0, -56), 13.0, _cc(s[2]), 14)
				tb.line(o + Vector2(10, -40), o + Vector2(26, -62), 4.0, _cc(s[2]))
		"cat_tb":
			var p := Vector2(s[1], s[2])
			tb.rect(Rect2(p.x - 60, p.y, 140, 40), Color("5a4a5c"))
			tb.ellipse(p + Vector2(0, -10), 16.0, 11.0, Color("140e1c"), 16)
			tb.circle(p + Vector2(12, -24), 8.0, Color("140e1c"), 12)
			tb.tri(p + Vector2(6, -30), p + Vector2(9, -40), p + Vector2(13, -31), Color("140e1c"))
			tb.tri(p + Vector2(14, -31), p + Vector2(19, -40), p + Vector2(20, -29), Color("140e1c"))


static func _arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n + 1:
		var a := lerpf(a0, a1, k / float(n))
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func _truth(tb, cx: float, bottom: float, w: float, h: float) -> void:
	## The window no one was shown ("The Girl Who Sang"): a pit of violet
	## panes with a huge closed eye, a small girl with a candle on her head
	## singing into it, a bell either side, and the first Undercandle at the
	## top, all as panes on a lead grid inside one pointed arch.
	var outer := arch_pts(cx, bottom, w, h, 14)
	tb.concave(arch_pts(cx, bottom + 12, w + 36, h + 26, 14), Color("2c2238"))
	tb.concave(outer, Color("140e1c"))
	var inner := arch_pts(cx, bottom - 16, w - 32, h - 32, 14)
	var cell := 20.0
	var top := bottom - h
	var y := top
	var j := 0
	while y < bottom:
		var x := cx - w * 0.5
		var i := 0
		while x < cx + w * 0.5:
			var c := Vector2(x + cell * 0.5, y + cell * 0.5)
			if Geometry2D.is_point_in_polygon(c, outer):
				var col: Color
				if not Geometry2D.is_point_in_polygon(c, inner):
					col = _cc(PANE_COLS[(i + j) % 3])
				else:
					col = _truth_pane((c.x - (cx - w * 0.5)) / w, (c.y - top) / h, i, j)
				col = col.lightened(_h(i, j) * 0.12) if _h(j, i) > 0.5 else col.darkened(_h(i, j) * 0.12)
				tb.rect(Rect2(x + 2.0, y + 2.0, cell - 4.0, cell - 4.0), col)
			x += cell
			i += 1
		y += cell
		j += 1


static func _truth_pane(u: float, v: float, i: int, j: int) -> Color:
	## The window's picture, kept to its upper two thirds (the dialogue box
	## covers the bottom of the frame): the first Undercandle up top, a bell
	## either side, the girl at the pit's edge singing down into it, and the
	## huge closed eye in the pit, a lead line under its lids for a smile.
	var d := func(x: float, y: float) -> float: return Vector2((u - x) * 2.0, v - y).length()
	if d.call(0.5, 0.1) < 0.06:
		return Color("fff2c8")
	if d.call(0.5, 0.12) < 0.1:
		return Color("f0b030")
	for bx in [0.16, 0.84]:
		if absf(u - bx) < 0.025 + (v - 0.2) * 0.3 and v > 0.2 and v < 0.32:
			return Color("d8a830")
	# The girl, a candle on her head, at the pit's left edge.
	if d.call(0.28, 0.36) < 0.035:
		return Color("f0c8a0")
	if absf(u - 0.28) < 0.028 and v > 0.39 and v < 0.5:
		return Color("b8324e")
	if absf(u - 0.28) < 0.008 and v > 0.28 and v < 0.33:
		return Color("f4ead6")
	if d.call(0.28, 0.26) < 0.02:
		return Color("ffd84a")
	# Her song, curling down into the pit.
	for k in 3:
		if absf(v - (0.38 + k * 0.05) - sin(u * 14.0 + k) * 0.02) < 0.012 and u > 0.32 and u < 0.56:
			return Color("3a6ab8")
	# The pit and the huge closed eye in it.
	if v > 0.4:
		var e: float = d.call(0.62, 0.56)
		if e < 0.22 and absf(v - 0.56 - (u - 0.62) * (u - 0.62) * 1.2) < 0.022:
			return Color("06030a")
		if e < 0.22 and absf(v - 0.6 - (u - 0.62) * (u - 0.62) * 0.8) < 0.012:
			return Color("140e1c")
		var ring := int(d.call(0.62, 0.58) * 12.0)
		return Color("4a3a7a") if ring % 2 == 0 else Color("33285a")
	if _h(i, j) > 0.97:
		return Color("fff2c8")
	return Color("2a3a6a").lerp(Color("1a2448"), 1.0 - v)


# ---------------------------------------------------------------- v3 figures (256 frame, feet at (128, 244))

static func _figure_tb(ci: CanvasItem, look: String, t: float) -> void:
	var tb := TriBatch.new()
	match look:
		"hush_grasp":
			# Smoke-black hands rising from below, their long fingers curling
			# closed round a flame at the top: black, a violet rim, pale tips.
			tb.ellipse(Vector2(128, 236), 110.0, 40.0, Color("0a0812"), 24)
			tb.convex(PackedVector2Array([Vector2(60, 250), Vector2(82, 150), Vector2(174, 150), Vector2(196, 250)]), Color("0a0812"))
			for k in 5:
				var u := (k - 2) / 2.0
				var base := Vector2(128 + u * 40.0, 156)
				var tip := Vector2(128 + u * 12.0, 58 + absf(u) * 14.0)
				var mid := Vector2(128 + u * 58.0, 100 + absf(u) * 6.0)
				var pts := PackedVector2Array()
				for j in 7:
					var q := j / 6.0
					pts.append(base.lerp(mid, q).lerp(mid.lerp(tip, q), q))
				tb.polyline(pts, 17.0 - absf(u) * 3.0, Color("4a3a7a"))
				tb.polyline(pts, 12.0 - absf(u) * 3.0, Color("0a0812"))
				tb.circle(tip, 5.0 - absf(u), Color("9a90c8"), 10)
			tb.ring(Vector2(128, 170), 60.0, 3.0, Color("4a3a7a"), 24, PI * 1.1, PI * 1.9)
		"rootmother", "rootmother_open":
			var open := look == "rootmother_open"
			var bark := Color("cfc4a8")
			var shade := Color("9a8c70")
			tb.convex(_pts([[72, 244], [88, 96], [168, 96], [184, 244]]), bark)
			tb.convex(_pts([[138, 244], [150, 96], [168, 96], [184, 244]]), shade)
			# Root arms to the floor.
			for sx in [-1.0, 1.0]:
				tb.polyline(PackedVector2Array([Vector2(128 + sx * 40, 110), Vector2(128 + sx * 92, 160), Vector2(128 + sx * 104, 244)]), 16.0, shade)
				for k in 3:
					tb.line(Vector2(128 + sx * 104, 240), Vector2(128 + sx * (92 + k * 14), 250), 5.0, shade)
			# The wimple of bark and moss round a kind carved face.
			tb.circle(Vector2(128, 70), 44.0, Color("6a8a4a"), 24)
			tb.circle(Vector2(128, 72), 32.0, Color("d8cbb0"), 24)
			var lid := 3.0 if not open else 5.0
			for sx in [-11.0, 11.0]:
				tb.ellipse(Vector2(128 + sx, 70), 6.0, lid, INK, 10)
			tb.line(Vector2(120, 88), Vector2(136, 88), 2.5, Color("6a5a40"))
			# A crown of branches with bone fruit.
			for k in 5:
				var a := lerpf(-2.4, -0.7, k / 4.0)
				var e := Vector2(128, 40) + Vector2(cos(a), sin(a)) * 56.0
				tb.line(Vector2(128, 40), e, 6.0, shade)
				if not open:
					tb.circle(e + Vector2(0, 8), 6.0, Color("e8e0c8"), 10)
			# The chest: roots caging a cold ember, or open with it warm and risen.
			tb.ellipse(Vector2(128, 150), 26.0, 32.0, Color("2a2418"), 20)
			if not open:
				for k in 4:
					tb.line(Vector2(110 + k * 12, 118), Vector2(110 + k * 12, 182), 4.0, shade)
			else:
				tb.polyline(PackedVector2Array([Vector2(104, 124), Vector2(96, 150), Vector2(104, 178)]), 5.0, shade)
				tb.polyline(PackedVector2Array([Vector2(152, 124), Vector2(160, 150), Vector2(152, 178)]), 5.0, shade)
		"yarrow":
			# Mother Yarrow's spirit: small and round like Taper, see-through green-gold.
			var g := Color(0.85, 0.92, 0.6, 0.7)
			var gd := Color(0.62, 0.72, 0.4, 0.7)
			tb.convex(_pts([[84, 244], [96, 150], [160, 150], [172, 244]]), g)
			tb.convex(_pts([[100, 240], [106, 170], [150, 170], [156, 240]]), Color(0.95, 0.95, 0.85, 0.7))   # the apron
			tb.circle(Vector2(128, 116), 40.0, gd, 24)
			tb.ellipse(Vector2(128, 82), 56.0, 12.0, Color(0.85, 0.75, 0.45, 0.8), 24)                      # the straw brim
			tb.circle(Vector2(128, 120), 28.0, Color(0.98, 0.9, 0.78, 0.75), 20)
			for k in 3:
				tb.circle(Vector2(96 + k * 8, 78), 4.0, Color(1, 1, 1, 0.9), 8)                              # yarrow in the hood
			for sx in [-9.0, 9.0]:
				tb.circle(Vector2(128 + sx, 118), 2.6, INK, 8)
			tb.ring(Vector2(128, 128), 7.0, 2.2, INK, 10, 0.4, PI - 0.4)
			tb.rect(Rect2(122, 44, 12, 22), Color(0.95, 0.9, 0.78, 0.9))                                  # the stub candle
			tb.line(Vector2(176, 196), Vector2(190, 168), 4.0, Color(0.5, 0.4, 0.3, 0.8))                  # a trowel
			tb.tri(Vector2(186, 168), Vector2(196, 170), Vector2(194, 156), Color(0.75, 0.75, 0.8, 0.8))
		"tinker":
			# A walking clockwork bell-body under wax-ice; Tickwell frozen in a
			# frosted case on its back, over the shoulder (spec §6.5.4).
			tb.rect(Rect2(150, 60, 70, 90), Color(0.81, 0.9, 0.94, 0.55))
			tb.circle(Vector2(184, 104), 12.0, Color("e0b870"), 14)
			tb.rect(Rect2(176, 116, 16, 22), Color("6a4a2a"))
			tb.convex(_pts([[78, 236], [96, 110], [160, 110], [178, 236]]), Color("b8862a"))
			tb.convex(_pts([[140, 236], [150, 110], [160, 110], [178, 236]]), Color("8a6420"))
			tb.rect(Rect2(74, 228, 108, 14), Color("8a6420"))
			for k in 3:
				tb.ring(Vector2(128, 170 + k * 18), 34.0, 3.0, Color("d8a850"), 20, PI, TAU)
			tb.circle(Vector2(118, 74), 40.0, Color("5a6878"), 28)
			tb.circle(Vector2(118, 74), 34.0, Color("dde6ee"), 28)
			for k in 12:
				var d := Vector2(0, -1).rotated(TAU * k / 12.0)
				tb.line(Vector2(118, 74) + d * 26.0, Vector2(118, 74) + d * 31.0, 2.0, Color("3a4250"))
			tb.line(Vector2(118, 74), Vector2(118, 74) + Vector2(0, -24).rotated(-0.1), 3.0, INK)
			tb.line(Vector2(118, 74), Vector2(118, 74) + Vector2(0, -16), 4.0, INK)
			for sx in [-1.0, 1.0]:
				tb.line(Vector2(128 + sx * 44, 130), Vector2(128 + sx * 70, 190), 10.0, Color("8a6420"))
				tb.ring(Vector2(128 + sx * 74, 200), 10.0, 5.0, Color("d8a850"), 12)
			tb.rect(Rect2(76, 108, 104, 10), Color(0.81, 0.9, 0.94, 0.4))
		"tickwell":
			# Tiny, bald, a white fringe, goggles up, a bristly moustache, an apron.
			tb.convex(_pts([[96, 244], [104, 150], [152, 150], [160, 244]]), Color("6a5a4a"))
			tb.convex(_pts([[106, 240], [110, 168], [146, 168], [150, 240]]), Color("8a5a36"))
			tb.circle(Vector2(128, 116), 36.0, Color("f0c8a8"), 24)
			tb.ellipse(Vector2(96, 118), 8.0, 14.0, Color("f4f0e8"), 12)
			tb.ellipse(Vector2(160, 118), 8.0, 14.0, Color("f4f0e8"), 12)
			for sx in [-12.0, 12.0]:
				tb.ring(Vector2(128 + sx, 92), 8.0, 3.0, Color("b8862a"), 14)
				tb.circle(Vector2(128 + sx, 116), 3.0, INK, 8)
			tb.ellipse(Vector2(128, 132), 16.0, 5.0, Color("f4f0e8"), 14)
			tb.circle(Vector2(156, 160), 13.0, Color("b8862a"), 16)              # the lantern-watch
			tb.circle(Vector2(156, 160), 9.0, Color("f4ead6"), 14)
			tb.ring(Vector2(112, 196), 8.0, 2.0, Color("b8b8c0"), 12)            # a ring of keys
		"cone_bell":
			# The two halves of the cone riveted along a brass band, mouth-down.
			tb.convex(_pts([[76, 214], [106, 70], [150, 70], [180, 214]]), Color("1e1a28"))
			tb.line(Vector2(128, 72), Vector2(128, 212), 8.0, Color("b8862a"))
			for k in 5:
				tb.circle(Vector2(128, 90 + k * 28), 3.0, Color("d8a850"), 8)
			tb.ellipse(Vector2(128, 214), 54.0, 10.0, Color("2a2436"), 20)
			tb.circle(Vector2(128, 224), 8.0, Color("5a5468"), 12)
			tb.rect(Rect2(96, 56, 64, 14), Color("6a4a2a"))                      # the yoke
		"saint", "tessel":
			var lit := look == "tessel"
			var cols := PANE_COLS if lit else ["e8ecf8", "c8c4e8", "b8c8e8", "dcd8f0", "c0b8e0", "e0e4f4"]
			# A gown of glass: panes on a lead grid inside her outline.
			var gown := PackedVector2Array([Vector2(70, 244), Vector2(98, 110), Vector2(158, 110), Vector2(186, 244)])
			tb.convex(gown, Color("140e1c"))
			var k := 0
			for row in 6:
				for col in 4:
					var y0 := 116.0 + row * 21.0
					var xl := lerpf(98, 70, (y0 - 110.0) / 134.0) + 4.0
					var xr := lerpf(158, 186, (y0 - 110.0) / 134.0) - 4.0
					var cw := (xr - xl) / 4.0
					tb.rect(Rect2(xl + col * cw + 2.0, y0 + 2.0, cw - 4.0, 17.0), _cc(cols[(row + col * 2) % cols.size()]))
					k += 1
			tb.circle(Vector2(128, 66), 30.0, Color("140e1c"), 24)
			tb.circle(Vector2(128, 66), 26.0, _cc("f8e8d8" if lit else "e8ecf8"), 24)
			if lit:
				for sx in [-10.0, 10.0]:
					tb.circle(Vector2(128 + sx, 64), 2.6, INK, 8)
				tb.rect(Rect2(116, 118, 24, 24), Color("f8f4e8"))                # her heart pane: the girl
				tb.circle(Vector2(128, 128), 5.0, Color("f0c8a0"), 10)
				tb.rect(Rect2(126, 118, 4, 6), Color("f4ead6"))
			else:
				for sx in [-10.0, 10.0]:
					tb.line(Vector2(128 + sx - 5, 64), Vector2(128 + sx + 5, 64), 2.0, INK)
				tb.convex(PackedVector2Array([Vector2(128, 124), Vector2(144, 150), Vector2(112, 150)]), Color("f4f8ff"))   # the prism
			# A halo of prism rays.
			for r in 9:
				var a := PI + PI * r / 8.0
				tb.line(Vector2(128, 60) + Vector2(cos(a), sin(a)) * 34.0, Vector2(128, 60) + Vector2(cos(a), sin(a)) * 54.0, 3.0,
						_cc(cols[r % cols.size()]) if lit else Color("f0f4ff"))
		"stolen_wick":
			tb.ellipse(Vector2(128, 232), 96.0, 16.0, Color("d8ccb0"), 28)          # the ring of set wax
			tb.ellipse(Vector2(128, 230), 70.0, 9.0, Color("b8ac90"), 24)
			tb.rect(Rect2(100, 130, 56, 100), Color("efe6cc"))                    # the ancient stub
			tb.rect(Rect2(140, 130, 16, 100), Color("d8ccb0"))
			tb.ellipse(Vector2(128, 130), 28.0, 6.0, Color("f8f0dc"), 18)
			tb.polyline(PackedVector2Array([Vector2(128, 130), Vector2(122, 116), Vector2(132, 104), Vector2(126, 96)]), 3.0, INK)
			tb.polyline(PackedVector2Array([Vector2(126, 94), Vector2(134, 76), Vector2(124, 58), Vector2(134, 40)]), 3.0, Color(0.7, 0.72, 0.8, 0.4))
		"hollin_carry":
			# Hollin, helm lit, with tiny Mother Taper on his back holding her ember up.
			tb.convex(_pts([[88, 244], [100, 150], [150, 150], [162, 244]]), Color("5a6a8a"))
			tb.circle(Vector2(118, 112), 36.0, Color("f0c8a8"), 24)
			tb.ellipse(Vector2(118, 86), 40.0, 18.0, Color("8a8a96"), 20)
			tb.rect(Rect2(112, 52, 12, 16), Color("d8ccb0"))
			for sx in [-10.0, 10.0]:
				tb.circle(Vector2(118 + sx, 116), 3.4, INK, 8)
			tb.ring(Vector2(118, 126), 7.0, 2.4, INK, 10, 0.4, PI - 0.4)
			tb.convex(_pts([[146, 170], [150, 110], [186, 110], [190, 170]]), Color("5a2e5a"))
			tb.circle(Vector2(168, 96), 20.0, Color("5a2e5a"), 18)
			tb.circle(Vector2(168, 100), 14.0, Color("f0c8a8"), 16)
			tb.line(Vector2(180, 110), Vector2(180, 40), 4.0, Color("5a2e5a"))      # her arm, up
			tb.circle(Vector2(178, 36), 5.0, Color("ffb05a"), 10)
			tb.convex(_pts([[134, 214], [140, 196], [150, 196], [156, 214]]), Color("2a2436"))   # his bell at his belt
		"tollgrave_stand":
			tb.convex(_pts([[70, 244], [88, 120], [152, 120], [170, 244]]), Color("2c3438"))
			tb.convex(_pts([[132, 244], [140, 120], [152, 120], [170, 244]]), Color("1c2226"))
			tb.ellipse(Vector2(118, 118), 44.0, 14.0, Color("1c2226"), 20)         # the hood, back
			tb.circle(Vector2(118, 82), 30.0, Color("ecd8b0"), 24)
			for sx in [-10.0, 10.0]:
				tb.circle(Vector2(118 + sx, 78), 7.0, INK, 12)
			tb.tri(Vector2(110, 104), Vector2(126, 104), Vector2(118, 126), Color("f4f0e8"))   # the beard tuft
			tb.line(Vector2(200, 244), Vector2(200, 70), 5.0, Color("6a4a2a"))      # the lantern's pole
			tb.rect(Rect2(190, 58, 20, 22), Color("3a2a1a"))
			tb.polyline(PackedVector2Array([Vector2(96, 120), Vector2(70, 160), Vector2(60, 230)]), 4.0, Color("a08a5a"))   # the bell rope
		"townsfolk":
			var greys := ["8a7a88", "7a6e80", "948490", "6e6478"]
			for i in 8:
				var x := 22.0 + i * 30.4
				var h := 60.0 + (i % 3) * 14.0
				var col := _cc(greys[i % greys.size()])
				tb.convex(_pts([[x - 12, 244], [x - 8, 244 - h], [x + 8, 244 - h], [x + 12, 244]]), col)
				tb.circle(Vector2(x, 244 - h - 10), 10.0, col.lightened(0.1), 12)
				tb.line(Vector2(x + 6, 244 - h + 10), Vector2(x + 2, 158 if i % 2 == 0 else 152), 3.0, col.darkened(0.2))
			tb.rect(Rect2(200, 150, 14, 10), Color("5a4a5c"))                      # a cat riding someone's hat
		"deep_candle":
			tb.ellipse(Vector2(128, 238), 78.0, 13.0, Color("b8ac90"), 24)          # the wax lily pad
			tb.ellipse(Vector2(128, 236), 62.0, 9.0, Color("d8ccb0"), 24)
			tb.tri(Vector2(128, 236), Vector2(196, 232), Vector2(190, 242), Color("8a7e68"))   # its notch
			tb.rect(Rect2(116, 124, 24, 110), Color("efe6cc"))
			tb.line(Vector2(128, 124), Vector2(128, 114), 2.0, INK)
		"lost_wicks":
			for i in 6:
				var c := Vector2(30.0 + i * 40.0, 150.0 - (i % 2) * 8.0)
				tb.circle(c, 22.0, Color(0.95, 0.85, 0.55, 0.25), 18)
				tb.ring(c + Vector2(0, -6), 14.0, 3.0, Color(0.95, 0.85, 0.55, 0.7), 16, PI, TAU)
				tb.line(c + Vector2(0, -20), c + Vector2(0, -30), 2.0, Color(0.95, 0.85, 0.55, 0.8))
	tb.flush(ci)


# ---------------------------------------------------------------- v3 faces (128 frame, face near (64, 62))

static func portrait_flame(who: String, mood: String) -> Array:
	## A stand-in face's live flame [x, y, h] in its 128 frame, or [] for none.
	if who == "hollin":
		return [58, 14, 5] if HOLLIN_LIT.has(mood) else []
	return FACE_FLAMES.get(who, [])


static func _face_tb(ci: CanvasItem, who: String, mood: String) -> void:
	var tb := TriBatch.new()
	var c := Vector2(64, 66)
	match who:
		"rootmother":
			var wrath := mood == "wrath"
			tb.circle(Vector2(64, 60), 52.0, Color("6a8a4a"), 28)
			tb.circle(c, 36.0, Color("d8cbb0"), 28)
			if wrath:
				for sx in [-1.0, 1.0]:
					tb.line(c + Vector2(sx * 20, -16), c + Vector2(sx * 6, -8), 3.0, INK)
					tb.circle(c + Vector2(sx * 12, -2), 4.0, Color("d8f0c0"), 10)
				tb.line(c + Vector2(-10, 18), c + Vector2(10, 18), 3.0, INK)
				tb.line(c + Vector2(0, -30), c + Vector2(4, -10), 2.0, Color("6a5a40"))
			else:
				for sx in [-1.0, 1.0]:
					tb.line(c + Vector2(sx * 17, -2), c + Vector2(sx * 7, -2), 2.5, INK)
				tb.ring(c + Vector2(0, 12), 7.0, 2.4, INK, 10, 0.5, PI - 0.5)
				tb.circle(c + Vector2(30, 20), 7.0, Color("e8e0c8"), 12)
		"yarrow":
			var merry := mood == "merry"
			tb.ellipse(Vector2(64, 30), 58.0, 12.0, Color("d8c080"), 24)
			tb.circle(c + Vector2(0, 6), 34.0, Color(0.98, 0.9, 0.78, 0.85), 24)
			for k in 3:
				tb.circle(Vector2(24 + k * 8, 26), 4.0, Color("f4f4ec"), 8)
			for sx in [-1.0, 1.0]:
				if merry:
					tb.ring(c + Vector2(sx * 11, 2), 5.0, 2.2, INK, 8, PI + 0.4, TAU - 0.4)
				else:
					tb.circle(c + Vector2(sx * 11, 2), 3.2, INK, 8)
				tb.circle(c + Vector2(sx * 19, 14), 5.0, Color(1.0, 0.5, 0.5, 0.35), 10)
			tb.ring(c + Vector2(0, 16), 8.0 if merry else 6.0, 2.4, INK, 10, 0.3, PI - 0.3)
		"tinker":
			var wrath := mood == "wrath"
			tb.circle(Vector2(64, 62), 52.0, Color("5a6878"), 28)
			tb.circle(Vector2(64, 62), 44.0, Color("dde6ee"), 28)
			for k in 12:
				var d := Vector2(0, -1).rotated(TAU * k / 12.0)
				tb.line(Vector2(64, 62) + d * 34.0, Vector2(64, 62) + d * 41.0, 2.0, Color("3a4250"))
			var a := -0.1 if not wrath else 1.9
			tb.line(Vector2(64, 62), Vector2(64, 62) + Vector2(0, -34).rotated(a), 3.0, INK)
			tb.line(Vector2(64, 62), Vector2(64, 62) + Vector2(0, -22).rotated(-0.03 if not wrath else -2.3), 4.0, INK)
			for sx in [-1.0, 1.0]:
				if wrath:
					tb.line(Vector2(64 + sx * 20, 70), Vector2(64 + sx * 10, 74), 3.0, Color("8cc8e8"))
				else:
					tb.circle(Vector2(64 + sx * 15, 72), 3.5, Color("8cc8e8"), 10)
			if wrath:
				tb.line(Vector2(80, 30), Vector2(94, 58), 2.0, Color("8a98a8"))
		"tickwell":
			var dazed := mood == "dazed"
			tb.circle(c + Vector2(0, 6), 34.0, Color("f0c8a8"), 24)
			tb.ellipse(c + Vector2(-34, 8), 7.0, 14.0, Color("f4f0e8"), 12)
			tb.ellipse(c + Vector2(34, 8), 7.0, 14.0, Color("f4f0e8"), 12)
			for sx in [-1.0, 1.0]:
				tb.ring(c + Vector2(sx * 12, -26 if not dazed else -18), 8.0, 3.0, Color("b8862a"), 14)
				tb.circle(c + Vector2(sx * 11, 2), 4.0 if dazed else 3.0, INK, 8)
			tb.ellipse(c + Vector2(0, 18 if not dazed else 22), 16.0, 5.0, Color("f4f0e8"), 14)
			if not dazed:
				tb.ring(c + Vector2(0, 26), 5.0, 2.0, INK, 8, 0.4, PI - 0.4)
		"saint", "tessel":
			var warm := who == "tessel"
			var wrath := mood == "wrath"
			var ring_cols := PANE_COLS if warm else ["e8ecf8", "c8c4e8", "b8c8e8", "dcd8f0", "c0b8e0", "e0e4f4"]
			for r in 12:
				var a := TAU * r / 12.0
				tb.line(Vector2(64, 62) + Vector2(cos(a), sin(a)) * 36.0, Vector2(64, 62) + Vector2(cos(a), sin(a)) * 52.0, 4.0, _cc(ring_cols[r % 6]))
			tb.circle(c, 34.0, Color("140e1c"), 24)
			tb.circle(c, 31.0, Color("f8e8d8") if warm else Color("e8ecf8"), 24)
			for sx in [-1.0, 1.0]:
				if warm:
					tb.circle(c + Vector2(sx * 11, -2), 3.2, INK, 8)
				elif wrath:
					tb.line(c + Vector2(sx * 17, -4), c + Vector2(sx * 5, -1), 3.0, Color("f8f8ff"))
				else:
					tb.line(c + Vector2(sx * 16, -1), c + Vector2(sx * 6, -1), 2.2, INK)
			if warm and mood == "sad":
				tb.rect(Rect2(c.x - 15, c.y + 4, 5, 9), Color("3a6ab8"))
			else:
				tb.ring(c + Vector2(0, 12), 6.0, 2.2, INK, 10, 0.5, PI - 0.5)
			if wrath:
				tb.line(Vector2(84, 40), Vector2(72, 70), 2.0, Color("8a86a8"))
		"hush":
			# The eye, cropped to the circle: a pale sclera, a dim violet ring, a pinprick pupil.
			tb.circle(Vector2(64, 62), 54.0, Color("06030a"), 32)
			tb.ellipse(Vector2(64, 62), 50.0, 24.0, Color("d8d4f0"), 32)
			tb.circle(Vector2(64, 62), 17.0, Color("6a5a9a"), 24)
			tb.circle(Vector2(64, 62), 10.0, Color("3a2e5a"), 20)
			tb.circle(Vector2(64, 62), 2.6, Color("06030a"), 8)
			tb.circle(Vector2(61, 58), 1.6, Color(1, 1, 1, 0.9), 6)
		"echo":
			# A Lost Wick: a soft gold glow in a helm's outline, no face.
			tb.circle(Vector2(64, 62), 44.0, Color(0.95, 0.85, 0.55, 0.22), 28)
			tb.circle(Vector2(64, 66), 28.0, Color(0.95, 0.85, 0.55, 0.3), 24)
			tb.ring(Vector2(64, 58), 30.0, 4.0, Color(0.95, 0.85, 0.55, 0.8), 24, PI, TAU)
			tb.line(Vector2(34, 58), Vector2(34, 84), 4.0, Color(0.95, 0.85, 0.55, 0.8))
			tb.line(Vector2(94, 58), Vector2(94, 84), 4.0, Color(0.95, 0.85, 0.55, 0.8))
			tb.rect(Rect2(60, 24, 8, 8), Color(0.95, 0.9, 0.7, 0.9))
	tb.flush(ci)
