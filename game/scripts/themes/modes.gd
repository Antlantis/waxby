extends RefCounted
## The secrets' and the modes' themes (A2), merged by themes/loader.gd.
##   trialhall   the Proving Hall of the Vigil Trials (style hall, painter
##               glass): black marble and gold inlay, the brightest level theme
##               (its dark_color over every other level theme's, v2's and the
##               secrets' included: tests/test_world_art2.gd)
##   *_gilt      a secret level's theme, derived from its world's by gilt()
## gilt(id): the gilt rule (spec §11.4, p_artaudio §5.1): gold glass and
## banner, dark_color lightened 0.05 and warmed 15% toward (0.40, 0.33,
## 0.20), the tile lip lightened 0.12 and a gold trim (pal "trim", a 1 px line
## under every lip: the painters that know it draw it), the near backdrop
## layer at half density ("near_density") and the motes at half
## ("mote_scale", or this file's own table). Two exceptions: 6-S keeps its
## dark (the trim only) and 1-S is outdoors in snow under Lanternfold's lamps
## (style hall's "roof", 40 flakes of snow). GILT_BASE names each secret's
## parent theme; an unknown "<id>_gilt" gilds "<id>". A parent no theme file
## has yet (A1's W3-W4 before they land) gives the plain look in gold.

const Loader := "res://scripts/themes/loader.gd"
const BACKDROP := "res://scripts/backdrop.gd"      # v2's themes (W1-W2 parents)
const TILE_VIEW := "res://scripts/tile_view.gd"    # v2's tile palettes

const GILT_BASE := {
	"nave_gilt": "nave",            # 1-S The Roof of Evenbell (outdoors, snow)
	"tallow_gilt": "chandlery",     # 2-S The Chandlers' Vault (chandlery, 2-2's, where it's found: WLS, the track B merge; waxfall drew 1013-1408 calls)
	"orchard_gilt": "orchard",      # 3-S The Rootcrown
	"carillon_gilt": "clockface",   # 4-S The Mainspring
	"sanctum_gilt": "rosewind",     # 5-S The Rose Window
	"hushdeep_gilt": "hushquiet",   # 6-S The Lightless Mile (keeps its dark)
}
const KEEP_DARK := ["hushdeep_gilt"]
const OUTDOORS := ["nave_gilt"]
const GOLD := Color("d8b24a")
const GOLD_GLASS := [Color("ffd84a"), Color("fff2c8")]
const WARM := Color(0.40, 0.33, 0.20)
# 1-S: a clear night over the roofs (the moon, Lanternfold's lamps).
const ROOF_SKY := {"sky": Color("0c0e22"), "far": Color("181a32"), "mid": Color("222446"), "near": Color("121228")}
const SNOW_LIP := Color("dfe4f4")

const THEMES := {
	"trialhall": {"style": "hall", "painter": "glass", "variant": "hall",
			"sky": Color("0c0a10"), "far": Color("16121c"), "mid": Color("1e1a26"), "near": Color("0e0b14"),
			"glass": [Color("ffd84a"), Color("fff2c8")], "banner": Color("d8b24a"),
			"dark_color": Color(0.40, 0.36, 0.44)},
}

const PALETTES := {
	"trialhall": {"stone": Color("423e50"), "shade": Color("322e3e"), "lip": Color("c8a860"), "mortar": Color("2e2a38"),
			"buried": Color("221e2a"), "buried_mortar": Color("1c1824"), "brick": Color("4a4050"), "brick_shade": Color("383040"),
			"brick_lip": Color("a08a5a"), "slab": Color("5a5468"), "slab_lip": Color("9a90b0"),
			"panes": [Color("e0a830"), Color("ffd84a"), Color("c8883a")], "came": Color("1a1420"), "gold": Color("c8a860"),
			"gold_hi": Color("ffe28a"), "accent": Color("f8f0ff"), "dawn": Color("f2d88a"), "dawn_hi": Color("fff4c8"),
			"marble": Color("56506a"), "marble_lip": Color("c8a860"), "marble_shade": Color("3a3448"),
			"lead": Color("2a2434"), "lead_hi": Color("6a5a40")},
}

# The motes of the secret themes this file draws itself (the rest are their
# parent's, at "mote_scale"): 1-S's snow, 2-S's gold dust, 5-S's glitter at
# half with gold in it; the Proving Hall's few gold motes.
const AMBIENT := {
	"trialhall": [{"kind": "mote", "count": 12, "size": 1.2, "color": Color("ffd84a"), "alpha": 0.35, "drift": Vector2(2, -6), "sway": 6.0, "parallax": 0.8, "near_light": false}],
	"nave_gilt": [{"kind": "flake", "count": 40, "size": 1.5, "color": Color("eef0ff"), "alpha": 0.7, "drift": Vector2(-8, 26), "sway": 12.0, "parallax": 0.9, "near_light": false}],
	"tallow_gilt": [{"kind": "mote", "count": 12, "size": 1.3, "color": Color("ffd84a"), "alpha": 0.45, "drift": Vector2(1, -5), "sway": 6.0, "parallax": 0.9, "near_light": true}],
	"sanctum_gilt": [
		{"kind": "star", "count": 4, "size": 1.3, "color": Color("e87890"), "alpha": 0.55, "drift": Vector2(8, -3), "sway": 10.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 4, "size": 1.3, "color": Color("f0b8c8"), "alpha": 0.5, "drift": Vector2(10, -2), "sway": 10.0, "parallax": 0.9, "near_light": true},
		{"kind": "star", "count": 6, "size": 1.4, "color": Color("ffd84a"), "alpha": 0.55, "drift": Vector2(7, -4), "sway": 9.0, "parallax": 0.9, "near_light": true},
		{"kind": "petal", "count": 5, "size": 2.4, "color": Color("d8a0b8"), "alpha": 0.24, "drift": Vector2(18, 3), "sway": 16.0, "parallax": 0.7, "near_light": false},
	],
}


static func _consts(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var sc = load(path)
	return (sc as Script).get_script_constant_map() if sc is Script else {}


static func base_of(theme_id: String) -> String:
	return str(GILT_BASE.get(theme_id, theme_id.trim_suffix("_gilt")))


static func gilt(theme_id: String) -> Dictionary:
	## The secret theme for theme_id (the full id, "carillon_gilt"): its
	## parent's theme gilded (above). Never {} for a *_gilt id.
	var base_id := base_of(theme_id)
	var loader = load(Loader)
	var t: Dictionary = {}
	var pal: Dictionary = {}
	var v2 := false
	var v2_themes: Dictionary = _consts(BACKDROP).get("THEMES", {})
	if v2_themes.has(base_id):
		# A W1-W2 parent: v2's colours and style, v2's stone (painter "v2")
		# with its own palette.
		v2 = true
		t = (v2_themes[base_id] as Dictionary).duplicate()
		t["painter"] = "v2"
		if t.has("dark"):
			t["dark_color"] = t["dark"]
		var v2_pals: Dictionary = _consts(TILE_VIEW).get("PALETTES", {})
		pal = (v2_pals.get(base_id, v2_pals.get("cathedral", {})) as Dictionary).duplicate()
	elif base_id != theme_id and loader != null and loader.has_theme(base_id) and not base_id.ends_with("_gilt"):
		t = (loader.theme(base_id) as Dictionary).duplicate()
		pal = (loader.palette(base_id) as Dictionary).duplicate()
	if t.is_empty():
		t = {"style": "plain", "painter": "plain", "sky": Color("100c16"), "far": Color("1c1624"), "mid": Color("281f32"),
				"near": Color("160f1c"), "glass": [GOLD], "banner": GOLD, "dark_color": Color(0.28, 0.24, 0.32)}
	t["base"] = base_id
	t["gilt"] = true
	t.erase("dark")
	if pal.is_empty():
		pal = {"stone": Color("4a4050"), "shade": Color("3a3240"), "lip": Color("8a7a90"), "buried": Color("261e2c")}
	pal["trim"] = GOLD
	if KEEP_DARK.has(theme_id):
		# 6-S: the trim, nothing else (it keeps its dark, its glass, its motes).
		t["palette"] = pal
		return t
	if pal.has("lip"):
		pal["lip"] = (pal["lip"] as Color).lightened(0.12)
	var glass: Array = GOLD_GLASS.duplicate()
	var old_glass = t.get("glass", [])
	if old_glass is Array and not old_glass.is_empty():
		glass.append(old_glass[0])
	t["glass"] = glass
	t["banner"] = GOLD
	var dark: Color = t.get("dark_color", Color(0.28, 0.24, 0.32))
	t["dark_color"] = dark.lightened(0.05).lerp(WARM, 0.15)
	t["near_density"] = 0.5
	if not AMBIENT.has(theme_id):
		t["mote_scale"] = 0.5
	if OUTDOORS.has(theme_id):
		t.merge(ROOF_SKY, true)
		t["style"] = "hall"
		t["variant"] = "roof"
		pal["lip"] = SNOW_LIP
	t["palette"] = pal
	if v2 and not t.has("style"):
		t["style"] = "cathedral"
	return t
