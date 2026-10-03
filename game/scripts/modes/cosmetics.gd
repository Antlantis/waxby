extends RefCounted
## The cosmetics catalogue (spec §7.5): the hero's flame colours, the cape
## trims (a pattern and a colour) and the weapon glows, each with the one
## thing that earns it. Owned per save slot (Game.has_cosmetic, namespaced
## ids "flame:…", "trim:…", "color:…", "glow:…"), worn per hero (hero.look,
## Game.look / Game.set_look). None of them changes a number, and the hero's
## LIGHT is never tinted: a flame palette recolours only the three teardrops
## glow.flame() and UI.flame() draw.
##
## Flames stay warm (decisions.md): every flame's middle colour has a hue in
## [330°, 60°], saturation >= 0.4 and value >= 0.7, all through its cycle
## (tests/test_modes.gd checks it with warm_ok). The cool colours live on cape
## trims and weapon glows, where they carry no meaning.
##
## Static only; no autoloads (Game builds its save defaults from modes_save.gd,
## which reads this).

const HUE_LO := 330.0             # the warm band, degrees (wrapping through 0)
const HUE_HI := 60.0
const SAT_MIN := 0.4
const VAL_MIN := 0.7

# id -> {name, out, mid, core (hex), src (where it's earned), and optionally
# cycle, pulse, halo}.
# cycle: {"h0", "h1" (outer hue, degrees), "period" (s), "mid_add" (degrees),
# "s", "v"}: a flame whose outer hue swings h0 -> h1 -> h0 (never round the
# wheel: glow's own "shift" turns it full circle, through blue).
# pulse: {"period" (s), "lo"}: a slow breath, the flame's alpha lo -> 1 -> lo.
# halo: hex, the flame's soft rings (their alpha stays the flame's own): a
# dark one is a soot rim.
const FLAMES := {
	"tallow": {"name": "Tallow", "out": "f07a2a", "mid": "f7b64a", "core": "fff4cf", "src": "default"},
	"emberheart": {"name": "Emberheart", "out": "b8200e", "mid": "f0502a", "core": "ffc890", "src": "descent:5"},
	"coalheart": {"name": "Coalheart", "out": "8a1a0e", "mid": "e0402a", "core": "ffb890", "src": "descent:10"},
	"rosewax": {"name": "Rosewax", "out": "e05a6a", "mid": "f79090", "core": "fff0e8", "src": "descent:25"},
	"marigold": {"name": "Marigold", "out": "d8701a", "mid": "ffb030", "core": "fff0c0", "src": "descent:30"},
	"gold_leaf": {"name": "Gold Leaf", "out": "c8901a", "mid": "ffd84a", "core": "fffae0", "src": "descent:40"},
	"rosefire": {"name": "Rosefire", "out": "d8407a", "mid": "ff8ab4", "core": "ffe6f0", "src": "trials:golds10"},
	"sunwick": {"name": "Sunwick", "out": "f09a2a", "mid": "ffe060", "core": "ffffff", "src": "trials:dawns20"},
	"bellbronze": {"name": "Bell-bronze", "out": "9a5a26", "mid": "d8a060", "core": "fff0d6", "src": "waxworks:tollgrave"},
	"smokewick": {"name": "Smokewick", "out": "c07a3a", "mid": "e0b070", "core": "f8ecd8", "src": "waxworks:snuffer",
			"halo": "2e2018"},
	"blossomwick": {"name": "Blossomwick", "out": "d8606a", "mid": "f09a8a", "core": "fff0ec", "src": "waxworks:rootmother"},
	"brasswick": {"name": "Brasswick", "out": "b87a2a", "mid": "e8b050", "core": "fff4d8", "src": "waxworks:tinker"},
	"prismfire": {"name": "Prismfire", "out": "f24066", "mid": "f2663d", "core": "fff8f0", "src": "waxworks:saint",
			"cycle": {"h0": 340.0, "h1": 40.0, "period": 6.0, "mid_add": 20.0, "s": 0.75, "v": 0.95}},
	"lullflame": {"name": "Lullflame", "out": "c86a3a", "mid": "f0a060", "core": "fff0e0", "src": "waxworks:hush",
			"pulse": {"period": 4.5, "lo": 0.72}},
	"dawnwick": {"name": "Dawnwick", "out": "f2a57a", "mid": "ffd090", "core": "fffaf0", "src": "story:homecoming"},
}
const FLAME_ORDER := ["tallow", "emberheart", "coalheart", "rosewax", "marigold", "gold_leaf", "rosefire", "sunwick",
		"bellbronze", "smokewick", "blossomwick", "brasswick", "prismfire", "lullflame", "dawnwick"]

# Cape trims (P2: the rig's cape_trim part and heroes.py's SVGs draw them).
const TRIMS := {
	"band": {"name": "Heraldic Band", "src": "trials:gold4:knight"},
	"tongues": {"name": "Flame Hem", "src": "trials:gold4:witch"},
	"stitch": {"name": "Soot Stitch", "src": "trials:gold4:runner"},
	"bells": {"name": "Bell Hem", "src": "trials:gold4:founder"},
	"scallop": {"name": "Shroud Scallop", "src": "trials:gold4:sexton"},
}
const TRIM_ORDER := ["band", "tongues", "stitch", "bells", "scallop"]
const COLORS := {
	"calling": {"name": "Calling", "hex": "", "src": "default"},
	"bronze": {"name": "Bronze", "hex": "b07a3a", "src": "trials:medals5"},
	"silver": {"name": "Silver", "hex": "c8d0e0", "src": "trials:silvers10"},
	"gold": {"name": "Gold", "hex": "ffd84a", "src": "trials:golds15"},
	"ember": {"name": "Ember", "hex": "f07a2a", "src": "gauntlet:any"},
	"bone": {"name": "Bone", "hex": "e8e0cc", "src": "waxworks:bronze6"},
	"rime": {"name": "Rime", "hex": "a8e8ff", "src": "gauntlet:nightfall"},
	"hush": {"name": "Hush", "hex": "5a4a8a", "src": "gauntlet:witching"},
	"moth": {"name": "Moth", "hex": "d8e8c8", "src": "descent:15"},
}
const COLOR_ORDER := ["calling", "bronze", "silver", "gold", "ember", "bone", "rime", "hush", "moth"]
# Weapon glows (P2: glow.gd's _weapon_glow draws them, lighting nothing).
const GLOWS := {
	"gild": {"name": "Gildglow", "col": "ffd84a", "core": "fff4cf", "src": "trials:master:knight"},
	"hex": {"name": "Hexglow", "col": "b48aff", "core": "f4ecff", "src": "trials:master:witch"},
	"moth": {"name": "Mothglow", "col": "d8e8c8", "core": "ffffff", "src": "trials:master:runner"},
	"ember": {"name": "Emberglow", "col": "f07a2a", "core": "ffd0a0", "src": "trials:master:founder"},
	"rime": {"name": "Rimeglow", "col": "a8e8ff", "core": "ffffff", "src": "trials:master:sexton"},
	"hush": {"name": "Hushglow", "col": "5a4a8a", "core": "eee8ff", "src": "descent:20"},
	"dawn": {"name": "Dawnglow", "col": "fff4cf", "core": "ffffff", "src": "gauntlet:drips12"},
}
const GLOW_ORDER := ["gild", "hex", "moth", "ember", "rime", "hush", "dawn"]
const FREE := ["flame:tallow", "color:calling"]   # owned by everyone (Game.COSMETIC_FREE)
# What a locked swatch says when its source isn't in this build (ModesSave.source_reachable).
const DEEPER := "Deeper down"
# What a locked swatch says it wants, by its source.
const SRC_TEXT := {
	"default": "Yours from the start",
	"descent:5": "Clear depth 5 of the Endless Descent", "descent:10": "Clear depth 10 of the Endless Descent",
	"descent:15": "Clear depth 15 of the Endless Descent", "descent:20": "Clear depth 20 of the Endless Descent",
	"descent:25": "Clear depth 25 of the Endless Descent", "descent:30": "Clear depth 30 of the Endless Descent",
	"descent:40": "Clear depth 40 of the Endless Descent",
	"trials:golds10": "Win 10 Gold medals in the Vigil Trials", "trials:dawns20": "Win every Dawn medal in the Vigil Trials",
	"trials:medals5": "Win 5 medals in the Vigil Trials", "trials:silvers10": "Win 10 Silver medals or better",
	"trials:golds15": "Win 15 Gold medals or better",
	"waxworks:tollgrave": "Beat Old Tollgrave's cast with a Silver seal", "waxworks:snuffer": "Beat the Snuffer's cast with a Silver seal",
	"waxworks:rootmother": "Beat Mother Gravebough's cast with a Silver seal", "waxworks:tinker": "Beat the Tinker's cast with a Silver seal",
	"waxworks:saint": "Beat the Prism Saint's cast with a Silver seal", "waxworks:hush": "Beat the Hush's cast with a Silver seal",
	"waxworks:bronze6": "Seal all six casts in Bronze or better",
	"gauntlet:any": "Clear the Waxworks' Gauntlet", "gauntlet:nightfall": "Clear the Gauntlet on Nightfall",
	"gauntlet:witching": "Clear the Gauntlet in the Witching Hour", "gauntlet:drips12": "Clear the Gauntlet at 12 drips",
	"story:homecoming": "See Waxby home",
	"trials:gold4:knight": "Win Gold in all four Candleknight trials", "trials:gold4:witch": "Win Gold in all four Taperwitch trials",
	"trials:gold4:runner": "Win Gold in all four Sootrunner trials", "trials:gold4:founder": "Win Gold in all four Bellfounder trials",
	"trials:gold4:sexton": "Win Gold in all four Sexton trials",
	"trials:master:knight": "Win Gold in the Candleknight's Master trial", "trials:master:witch": "Win Gold in the Taperwitch's Master trial",
	"trials:master:runner": "Win Gold in the Sootrunner's Master trial", "trials:master:founder": "Win Gold in the Bellfounder's Master trial",
	"trials:master:sexton": "Win Gold in the Sexton's Master trial",
}


static func all_ids() -> Array:
	## Every cosmetic, namespaced.
	var out: Array = []
	for f in FLAME_ORDER:
		out.append("flame:" + f)
	for t in TRIM_ORDER:
		out.append("trim:" + t)
	for c in COLOR_ORDER:
		out.append("color:" + c)
	for g in GLOW_ORDER:
		out.append("glow:" + g)
	return out


static func entry(nid: String) -> Dictionary:
	## The catalogue entry of a namespaced id, or {}.
	var kind := nid.get_slice(":", 0)
	var id := nid.get_slice(":", 1)
	match kind:
		"flame":
			return FLAMES.get(id, {})
		"trim":
			return TRIMS.get(id, {})
		"color":
			return COLORS.get(id, {})
		"glow":
			return GLOWS.get(id, {})
	return {}


# The kinds the Sheet's Look tab can show and put on today (look_panel.gd:
# only the Flame row; trims, trim colours and weapon glows are P2). A reward
# of another kind is still granted, and says it's for later on the cards.
const LOOK_ROWS := ["flame"]


static func reward_name(nid: String) -> String:
	## A reward's name on a card or a toast: "Ember trim colour (for later)"
	## for what the Look tab can't wear yet (the rev5 review: the Gauntlet's
	## card offered "Ember", and nothing showed it).
	var n := str(entry(nid).get("name", ""))
	var kind := nid.get_slice(":", 0)
	if LOOK_ROWS.has(kind) or n == "":
		return n
	var what: String = {"trim": "cape trim", "color": "trim colour", "glow": "weapon glow"}.get(kind, "")
	return "%s %s (for later)" % [n, what] if what != "" else n


static func source_of(nid: String) -> String:
	return str(entry(nid).get("src", ""))


static func source_text(nid: String) -> String:
	var s := source_of(nid)
	return str(SRC_TEXT.get(s, s))


static func ids_for(src: String) -> Array:
	## Every cosmetic a source pays ("descent:10" -> ["flame:coalheart"]).
	var out: Array = []
	for nid in all_ids():
		if source_of(nid) == src:
			out.append(nid)
	return out


# ---------------------------------------------------------------- flames

static func palette(id: String, t := 0.0) -> Dictionary:
	## glow.flame's / UI.flame's pal for a flame at time t: {out, mid, core,
	## halo}. Tallow (and an unknown id) is {} (the candle's own, exactly).
	if id == "" or id == "tallow" or not FLAMES.has(id):
		return {}
	var f: Dictionary = FLAMES[id]
	var out := Color(str(f["out"]))
	var mid := Color(str(f["mid"]))
	var core := Color(str(f["core"]))
	if f.has("cycle"):
		var c: Dictionary = f["cycle"]
		var k := 0.5 - 0.5 * cos(TAU * t / maxf(float(c["period"]), 0.01))
		var h := _wrap(float(c["h0"]) + _span(float(c["h0"]), float(c["h1"])) * k)
		out = Color.from_hsv(h / 360.0, float(c["s"]), float(c["v"]))
		mid = Color.from_hsv(_wrap(h + float(c["mid_add"])) / 360.0, float(c["s"]) * 0.85, 1.0)
	var pal := {"out": out, "mid": mid, "core": core, "halo": Color(str(f["halo"])) if f.has("halo") else mid}
	if f.has("pulse"):
		var pu: Dictionary = f["pulse"]
		var b := 0.5 + 0.5 * cos(TAU * t / maxf(float(pu["period"]), 0.01))
		pal["alpha"] = lerpf(float(pu["lo"]), 1.0, b)
	return pal


static func animated(id: String) -> bool:
	## A flame that changes as it plays (a hue cycle or a breathing pulse).
	return FLAMES.has(id) and ((FLAMES[id] as Dictionary).has("cycle") or (FLAMES[id] as Dictionary).has("pulse"))


static func period(id: String) -> float:
	var f: Dictionary = FLAMES.get(id, {})
	if f.has("cycle"):
		return float(f["cycle"]["period"])
	if f.has("pulse"):
		return float(f["pulse"]["period"])
	return 1.0


static func mid_at(id: String, t := 0.0) -> Color:
	var p := palette(id, t)
	if p.is_empty():
		return Color(str(FLAMES["tallow"]["mid"]))
	return p["mid"]


static func warm_ok(c: Color) -> bool:
	## The hue rule on one middle colour.
	var h := c.h * 360.0
	var hue_in := h >= HUE_LO - 0.01 or h <= HUE_HI + 0.01
	return hue_in and c.s >= SAT_MIN - 0.001 and c.v >= VAL_MIN - 0.001


static func flame_warm(id: String) -> bool:
	## The hue rule over a flame's whole cycle (60 samples for a cycling one).
	if not animated(id):
		return warm_ok(mid_at(id))
	var pd := period(id)
	for i in 60:
		if not warm_ok(mid_at(id, pd * i / 60.0)):
			return false
	return true


static func hero_pal(look: Dictionary, t := 0.0) -> Dictionary:
	## The World's hero_flame for a hero's look ({} = Tallow, the candle's own).
	return palette(str(look.get("flame", "tallow")), t)


static func _span(a: float, b: float) -> float:
	## The short way round from hue a to hue b (340 -> 40 is +60).
	var d := fposmod(b - a, 360.0)
	return d if d <= 180.0 else d - 360.0


static func _wrap(h: float) -> float:
	return fposmod(h, 360.0)


# ---------------------------------------------------------------- looks

static func look_of(h: Dictionary, owned: Callable) -> Dictionary:
	## A hero's look with anything not owned dropped back to the default.
	## owned: Callable(nid) -> bool (Game.has_cosmetic).
	var lk: Dictionary = h.get("look", {}) if h.get("look") is Dictionary else {}
	var out := {"flame": "tallow", "trim": "", "trim_color": "calling", "glow": ""}
	var f := str(lk.get("flame", "tallow"))
	if FLAMES.has(f) and (f == "tallow" or owned.call("flame:" + f)):
		out["flame"] = f
	var tr := str(lk.get("trim", ""))
	if TRIMS.has(tr) and owned.call("trim:" + tr):
		out["trim"] = tr
	var tc := str(lk.get("trim_color", "calling"))
	if COLORS.has(tc) and (tc == "calling" or owned.call("color:" + tc)):
		out["trim_color"] = tc
	var gl := str(lk.get("glow", ""))
	if GLOWS.has(gl) and owned.call("glow:" + gl):
		out["glow"] = gl
	return out


static func look_key(nid: String) -> String:
	## The hero.look key a cosmetic is worn in.
	return {"flame": "flame", "trim": "trim", "color": "trim_color", "glow": "glow"}.get(nid.get_slice(":", 0), "")
