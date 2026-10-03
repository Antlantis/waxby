extends RefCounted
## The UI's shared look: fonts, colors, a panel, a button style, the safe
## area. System fonts only (Cochin for the gothic titles, Avenir Next for the
## rest), both on every iPhone and Mac. Also the small pieces every screen
## draws the same way: a candle flame, a portrait in a ring, the DMG / LIFE
## chips, rank pips, item icons, the menu backdrop and a few vector glyphs.

const Classes := preload("res://scripts/classes.gd")
const Relics := preload("res://scripts/relics.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")

const GOLD := Color("f2c75a")
const CREAM := Color("f4ead6")
const MUTED := Color("b8aacb")
const INK := Color("120d1a")
const PANEL := Color("1d1529")
const PANEL_EDGE := Color("6a5a86")
const EMBER := Color("f7b64a")
const RARITY := {
	"common": Color("e8e0d0"), "magic": Color("7aa8ff"),
	"rare": Color("ffd84a"), "legendary": Color("ff8a2a"),
}
const GOOD := Color("9ae07a")        # a chip that goes up, a heal
const BAD := Color("ff6a6a")         # a chip that goes down, harm
const ANOINTED := Color("7aa8ff")
const DREAD := Color("ffd84a")
const BG := Color("0e0a14")          # behind every screen
const ARCH := Color("171124")        # the far arches
const FLAME_OUT := Color("f07a2a")
const FLAME_MID := Color("f7b64a")
const FLAME_CORE := Color("fff4cf")
const SPEAKER := {"taper": Color("f2c75a"), "waxley": Color("f7b64a"), "tollgrave": Color("7ef0c8"),
		"snuffer": Color("c9c2f0"), "hollin": Color("a8b8d0"), "narrator": Color("f4ead6"),
		# v3's cast (story.gd CAST's colours)
		"rootmother": Color("9fc46a"), "yarrow": Color("d8e8a0"), "tinker": Color("8ccfe8"), "tickwell": Color("e0b870"),
		"saint": Color("eef0ff"), "tessel": Color("ff9ab8"), "hush": Color("9a90c8"),
		"lamplighter": Color("e8d8a0"), "oldchandler": Color("e8d8a0"), "gardenboy": Color("e8d8a0"),
		"rook": Color("e8d8a0"), "solder": Color("e8d8a0"), "abbess": Color("e8d8a0")}
const SLOT_NAME := {"weapon": "Weapon", "candle": "Candle", "coat": "Coat", "boots": "Boots", "charm": "Charm"}
# v3: the secrets' silver, and each world's accent (spec §10: the map's tabs).
const SILVER := Color("dfe3f4")
const SILVER_DEEP := Color("8d96bc")
const WORLD_ACCENT := {1: Color("d8b24a"), 2: Color("e8c86a"), 3: Color("c8d46a"), 4: Color("bfe4f4"),
		5: Color("c83a5a"), 6: Color("d8d4f0")}
const ITEM_TIERS := 5           # item art tiers the icons may have (art/items/*_4, *_5 from A8)
# The smallest a tappable control is drawn: 40 view units is 45 pt on the
# iPhone 17 Pro Max (390 units across its 440 pt), past Apple's 44 pt.
const TAP_H := 40.0

static var _fonts := {}
static var _tex := {}
static var safe_override := Rect2()  # tests and screenshots: pretend to be a phone
static var _panel_sb: StyleBoxFlat     # reused by panel() and chip(): drawn at once, so one will do


static func tex(path: String) -> Texture2D:
	## A texture, loaded once. Load them before drawing (see warm()): one first
	## loaded inside a draw call shows as a blank square.
	if not _tex.has(path):
		_tex[path] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _tex[path]


static func relic_icon(id: String) -> Texture2D:
	return tex("res://art/relics/%s.svg" % id)


const HERO_MOODS := ["normal", "happy", "fierce", "hurt"]


static func warm() -> void:
	## Every icon the menus and HUD draw, loaded ahead: the four faces of the
	## calling being played only (a screen that shows the others, the saves,
	## the Keeper, asks for them itself as it opens: UI.hero_face). The rest
	## are 8.7 MB a calling, and a level has no use for them.
	for id in Relics.ids():
		relic_icon(id)
	for n in ["flame_full", "flame_empty", "ember", "sigil_empty", "logo", "btn_flask", "btn_special_toll",
			"btn_left", "btn_right", "btn_jump", "btn_attack"]:
		tex("res://art/ui/%s.svg" % n)
	tex("res://art/props/sigil.svg")
	var playing := _playing_cls()
	for cls in Classes.ids():
		tex("res://art/ui/btn_special_%s.svg" % cls)
		tex(head_uv(cls)["path"])
		if cls == playing or playing == "":
			for mood in HERO_MOODS:
				tex("res://art/heroes/%s/portrait_%s.svg" % [cls, mood])
		for t in range(1, ITEM_TIERS + 1):
			tex("res://art/items/weapon_%s_%d.svg" % [cls, t])
	for slot in ["candle", "coat", "boots", "charm"]:
		for t in range(1, ITEM_TIERS + 1):
			tex("res://art/items/%s_%d.svg" % [slot, t])
	# v3: the worlds' icons and the Candlemark (A8; code stand-ins without them).
	for w in WORLD_ACCENT:
		world_icon(w)
	tex("res://art/ui/candlemark.svg")


static func _playing_cls() -> String:
	## The calling of the hero being played ("" with no Game or no hero yet).
	var ml = Engine.get_main_loop()
	var g = (ml as SceneTree).root.get_node_or_null("Game") if ml is SceneTree else null
	if g == null or not g.has_method("hero_id"):
		return ""
	return str(g.hero_id())


static func keep_faces(cls: String) -> void:
	## A level starts: the other callings' faces a menu loaded are let go
	## (only the one being played is drawn in a level), and so are the
	## scenes' 768 px story portraits (the HUD draws its own small copies).
	for path in _tex.keys():
		var p := str(path)
		if p.begins_with("res://art/story/portraits/"):
			_tex.erase(path)
		elif p.begins_with("res://art/heroes/") and p.get_file().begins_with("portrait_") and not p.begins_with("res://art/heroes/%s/" % cls):
			_tex.erase(path)


static func hud_face(path: String) -> String:
	## A story portrait's small copy for a face drawn small (the HUD's barks,
	## a result's line: art/story/portraits_hud, 128 px), else path itself.
	if path.begins_with("res://art/story/portraits/"):
		var small := path.replace("res://art/story/portraits/", "res://art/story/portraits_hud/")
		if ResourceLoader.exists(small):
			return small
	return path


static func font(kind := "body", weight := 600) -> Font:
	var key := "%s%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var f := SystemFont.new()
	if kind == "title" or kind == "italic":
		# "italic": Cochin's italic, for a storyteller's line.
		f.font_names = PackedStringArray(["Cochin", "Baskerville", "Georgia", "Times New Roman", "serif"])
		f.font_italic = kind == "italic"
	else:
		f.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Helvetica", "Arial", "sans-serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_fonts[key] = f
	return f


static func safe_rect(vp: Viewport) -> Rect2:
	## The part of the viewport clear of the notch/island and home bar, in
	## viewport coordinates.
	if safe_override.size.x > 0.0:
		return safe_override
	var size := vp.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return Rect2(Vector2.ZERO, size)
	if not OS.has_feature("mobile"):
		# A window on a Mac: the display's safe area (menu bar, notch) is the
		# screen's, not the window's. Just the margins.
		return Rect2(14.0, 10.0, size.x - 28.0, size.y - 18.0)
	var k := size / win
	var r := Rect2(Vector2(safe.position) * k, Vector2(safe.size) * k)
	# Some margin anyway, and never the whole bottom inset (the home bar only
	# needs a little).
	var left := maxf(r.position.x, 14.0)
	var top := maxf(r.position.y, 10.0)
	var right := maxf(size.x - r.end.x, 14.0)
	var bottom := clampf(size.y - r.end.y, 8.0, 18.0)
	return Rect2(left, top, size.x - left - right, size.y - top - bottom)


static func is_tap(event: InputEvent) -> bool:
	## A tap on a drawn screen: a left press. A finger makes one of these too
	## (touch emulates the mouse), and a click also arrives as a screen touch
	## (the mouse emulates touch), so a screen that took both would see every
	## tap twice. Take only this one.
	var mb := event as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT


static func phone_safe(size: Vector2) -> Rect2:
	## The safe area an iPhone 17 Pro Max gives in landscape, scaled to a
	## viewport of this size (the island's side inset, a little of the home
	## bar): for tests and screenshots on a Mac.
	var side := 55.0 * size.y / 390.0
	return Rect2(side, 10.0, size.x - side * 2.0, size.y - 10.0 - 17.7)


static func box() -> StyleBoxFlat:
	## A StyleBoxFlat to set up and draw straight away (the same one each
	## time: nothing keeps it between draws).
	if _panel_sb == null:
		_panel_sb = StyleBoxFlat.new()
	var sb := _panel_sb
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	return sb


static func panel(ci: CanvasItem, r: Rect2, edge := PANEL_EDGE, fill := PANEL, radius := 12.0) -> void:
	var sb := box()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(radius))
	sb.shadow_color = Color(0, 0, 0, 0.35 * fill.a)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.draw(ci.get_canvas_item(), r)


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, kind := "body", weight := 600, outline := 0) -> void:
	var f := font(kind, weight)
	if outline > 0:
		ci.draw_string_outline(f, pos, s, align, width, size, outline, Color(INK, col.a))
	ci.draw_string(f, pos, s, align, width, size, col)


# The glyph warm (the W3 hitch the int3 merge found: a font size nothing had
# drawn yet rasterizes its glyphs on the frame it first shows): the sizes the
# HUD first draws mid-play, drawn all but invisibly a chunk a frame, behind the
# title (title_screen.gd) or, when a level comes first (--autoplay), over its
# first HUD frames. [text, size, kind, weight, outline]; "*" is the alphabet.
# The cards' fit_size picks included (the rev5 review: the first item card in
# 5-1@2 still paid 28.8 ms): the item name 19-16, the relic name 21-20, a band
# card's 26 px title and 14 px line, their small lines.
const GLYPH_ABC := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+'·:,.-!?%"
const GLYPH_WARM := [
	[["Level up", 20, "body", 700, 6], ["Level 0123456789", 42, "title", 700, 8]],
	[["+0123456789 skill points Vigil ranks · a new belt slot", 14, "body", 700, 4],
			["Anointed Dread Warden Swift Burning Vengeful Warded Hushed Twinned Glassed Sporebound", 10, "body", 700, 0]],
	[["*", 17, "title", 700, 0]],     # an elite's plate
	[["*", 15, "body", 600, 0]],      # a bark
	[["*", 19, "title", 700, 0]],     # an item card's name
	[["*", 18, "title", 700, 0]],
	[["*", 17, "title", 700, 0], ["*", 16, "title", 700, 0]],
	[["*", 21, "title", 700, 0]],     # a relic's name
	[["*", 20, "title", 700, 0]],
	[["*", 26, "title", 700, 6]],     # a band card's title
	[["*", 14, "body", 600, 4]],      # its line
	[["*", 13, "body", 600, 0], ["*", 12, "body", 600, 0]],   # a bark's two lines, a card's small line
	[["*", 10, "body", 800, 0], ["*", 8, "body", 800, 0]],    # a card's head and affixes
]
static var glyph_step := 0


static func warm_glyphs(ci: CanvasItem) -> bool:
	## One chunk of GLYPH_WARM drawn at alpha 0.004 (under 1/255) on ci; false
	## once every chunk is done (once a session).
	if glyph_step >= GLYPH_WARM.size():
		return false
	var a := Color(1, 1, 1, 0.004)
	for row in GLYPH_WARM[glyph_step]:
		var t := GLYPH_ABC if str(row[0]) == "*" else str(row[0])
		text(ci, Vector2(4.0, 12.0), t, int(row[1]), a, HORIZONTAL_ALIGNMENT_LEFT, -1.0, str(row[2]), int(row[3]), int(row[4]))
	glyph_step += 1
	return glyph_step < GLYPH_WARM.size()


static func text_width(s: String, size: int, kind := "body", weight := 600) -> float:
	return font(kind, weight).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func satchel_line(n: int, cap: int, sep := " of ") -> String:
	## "Satchel 9 of 16", "Satchel full · 16 of 16", or past the cap (a
	## sigil milestone's Legendary always gets in) "Satchel over-full · 17 of 16".
	if n > cap:
		return "Satchel over-full · %d%s%d" % [n, sep, cap]
	if n == cap:
		return "Satchel full · %d%s%d" % [n, sep, cap]
	return "Satchel %d%s%d" % [n, sep, cap]


static func fit_size(s: String, width: float, size: int, min_size: int, kind := "body", weight := 600) -> int:
	## The biggest font size (down to min_size) at which s fits in width.
	var n := size
	while n > min_size and text_width(s, n, kind, weight) > width:
		n -= 1
	return n


static func wrap(s: String, width: float, size: int, kind := "body", weight := 600) -> Array:
	## s broken into lines no wider than width, at the spaces.
	return wrap_lines(s, width, size, kind, weight)


static func wrap_lines(s: String, width: float, size: int, kind := "body", weight := 600) -> Array:
	## wrap() under a name GDScript's own wrap() can't shadow (inside this file).
	var lines: Array = []
	var line := ""
	for word in s.split(" ", false):
		var trial: String = word if line == "" else line + " " + word
		if line != "" and text_width(trial, size, kind, weight) > width:
			lines.append(line)
			line = word
		else:
			line = trial
	if line != "":
		lines.append(line)
	return lines


static func style_button(b: Button, accent := false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("3a2a1a") if accent else Color("2a2038")
	normal.border_color = GOLD if accent else PANEL_EDGE
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.2)
	pressed.border_color = CREAM
	var disabled := normal.duplicate()
	disabled.bg_color = Color("1a1424")
	disabled.border_color = Color("3a3148")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", font("body", 700))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", GOLD if accent else CREAM)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_color_override("font_disabled_color", Color(MUTED, 0.5))


static func make_button(label: String, accent: bool, cb: Callable, sound := "click", size := 18) -> Button:
	## A styled button that clicks (when Sfx is there) and calls cb.
	var b := Button.new()
	b.text = label
	style_button(b, accent)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		var tree := b.get_tree()
		if sound != "" and tree != null and tree.root.get_node_or_null("Sfx") != null:
			tree.root.get_node("Sfx").play(sound)
		cb.call())
	return b


static func small_button(b: Button, font_size := 14) -> void:
	## Tighter margins, for rows of little buttons.
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_size_override("font_size", font_size)


static func format_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d.%d" % [s / 60, s % 60, int(fmod(t, 1.0) * 10.0)]


static func pct(v: float) -> String:
	## "+12%" from 0.12 (one decimal under 10% when it isn't whole).
	var p := v * 100.0
	if absf(p) < 10.0 and absf(p - roundf(p)) > 0.05:
		return "%+.1f%%" % p
	return "%+d%%" % roundi(p)


# ---------------------------------------------------------------- colors and names

static func class_color(cls: String) -> Color:
	return Color(str(Classes.info(cls)["color"]))


static func res_color(cls: String) -> Color:
	return Color(str(Classes.info(cls)["res_color"]))


static func speaker_color(who: String, cls := "knight") -> Color:
	if who == "wick":
		return class_color(cls)
	return SPEAKER.get(who, GOLD)


static func rarity_color(r: String) -> Color:
	return RARITY.get(r, RARITY["common"])


# ---------------------------------------------------------------- art lookups

static var _icon_paths := {}


static func item_icon_path(it) -> String:
	## art/items/weapon_<cls>_<tier>.svg or <slot>_<tier>.svg (W6a draws them).
	## v3 has five tiers: a tier's icon clamps to the highest tier whose art
	## exists (a T4 or T5 item shows its T3 icon until A8's art lands).
	if not (it is Dictionary) or it.is_empty():
		return ""
	var t := clampi(int(it.get("tier", 1)), 1, ITEM_TIERS)
	var stem := "res://art/items/%s_" % str(it.get("slot", ""))
	if it.get("slot", "") == "weapon":
		stem = "res://art/items/weapon_%s_" % str(it.get("cls", "knight"))
	var key := stem + str(t)
	if not _icon_paths.has(key):
		var k := t
		while k > 1 and not ResourceLoader.exists(stem + "%d.svg" % k):
			k -= 1
		_icon_paths[key] = stem + "%d.svg" % k
	return _icon_paths[key]


static func item_icon(it) -> Texture2D:
	return tex(item_icon_path(it))


static func empty_slot_icon_path(slot: String, cls := "knight") -> String:
	## The plainest art for a slot (its tier-1 item), for an empty slot's
	## silhouette.
	if slot == "weapon":
		return "res://art/items/weapon_%s_1.svg" % cls
	return "res://art/items/%s_1.svg" % slot


static func portrait_path(who: String, mood: String, cls := "knight") -> String:
	## A speaker's face: Waxby's is his calling's portrait, everyone else's is
	## in art/story/portraits. Falls back through the other moods; "" if none.
	var tries: Array = []
	if who == "wick":
		for m in [mood, "normal", "happy"]:
			tries.append("res://art/heroes/%s/portrait_%s.svg" % [cls, m])
	else:
		for m in [mood, "warm", "normal", "hushed", "wrath"]:
			tries.append("res://art/story/portraits/%s_%s.svg" % [who, m])
	for p in tries:
		if ResourceLoader.exists(p):
			return p
	return ""


static func head_uv(cls: String) -> Dictionary:
	## The rig's happy head and the part of it that shows the face: the
	## fallback when a calling has no portrait art yet.
	var dir := "res://art/heroes/%s/" % cls
	if not ResourceLoader.exists(dir + "head_happy.svg"):
		dir = "res://art/wick/"
	return {"path": dir + "head_happy.svg", "uv": Rect2(0.27, 0.27, 0.48, 0.48)}


static func hero_face(cls: String, mood := "happy") -> Dictionary:
	## {tex, uv} for a calling's face: its portrait, else its rig's head.
	var p := portrait_path("wick", mood, cls)
	if p != "":
		return {"tex": tex(p), "uv": Rect2(0, 0, 1, 1)}
	var h := head_uv(cls)
	return {"tex": tex(h["path"]), "uv": h["uv"]}


# ---------------------------------------------------------------- drawing pieces

static func disc(ci: CanvasItem, c: Vector2, r: float, t: Texture2D, uv := Rect2(0, 0, 1, 1), tint := Color.WHITE, n := 32) -> void:
	## A texture clipped to a circle.
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(uv.position + (d * 0.5 + Vector2(0.5, 0.5)) * uv.size)
	ci.draw_polygon(pts, PackedColorArray([tint]), uvs, t)


static func portrait(ci: CanvasItem, c: Vector2, r: float, t: Texture2D, ring: Color, a := 1.0, uv := Rect2(0, 0, 1, 1), letter := "") -> void:
	## A face in a ring: ink, then the speaker's colour. No art: a disc in the
	## speaker's colour with their initial.
	ci.draw_circle(c, r + 3.5, Color(INK, a))
	ci.draw_circle(c, r, Color(ring.darkened(0.6), a))
	if t != null:
		disc(ci, c, r - 1.0, t, uv, Color(1, 1, 1, a))
	elif letter != "":
		ci.draw_circle(c, r * 0.74, Color(ring.darkened(0.3), a))
		text(ci, Vector2(c.x - r, c.y + r * 0.34), letter, int(r * 0.95), Color(CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, "title", 700)
	ci.draw_arc(c, r + 0.5, 0, TAU, 40, Color(ring, a), 2.5, true)


static func flame(ci: CanvasItem, base: Vector2, h: float, t: float, seed := 0.0, guttering := false, a := 1.0, halo := true, pal := {}) -> void:
	## Glow's cel-shaded candle flame (three teardrops, flickering), for the
	## menus and the HUD, which draw above the dark anyway. pal (contract
	## §11, as glow.flame): {out, mid, core: Color; halo: Color (its alpha is
	## the flame's own); shift: hue turns a second; alpha: x every part}.
	## Empty is today's candle.
	if h <= 0.5:
		return
	var fl := 1.0 + 0.09 * sin(t * 17.0 + seed) + 0.05 * sin(t * 31.0 + seed * 2.0)
	if guttering:
		fl = 1.0 + 0.22 * sin(t * 23.0 + seed) + 0.12 * sin(t * 41.0)
	var sway := sin(t * 6.5 + seed) * h * 0.08
	var hh := h * fl
	var r := h * 0.32
	var c_out := Color(FLAME_OUT, a)
	var c_mid := Color(FLAME_MID, a)
	var c_core := Color(FLAME_CORE, a)
	var h1 := Color(1.0, 0.7, 0.3, 0.10 * a)
	var h2 := Color(1.0, 0.75, 0.35, 0.13 * a)
	if not pal.is_empty():
		c_out = Color(pal.get("out", FLAME_OUT), a)
		c_mid = Color(pal.get("mid", FLAME_MID), a)
		c_core = Color(pal.get("core", FLAME_CORE), a)
		if pal.has("halo"):
			var hc: Color = pal["halo"]
			h1 = Color(hc.r, hc.g, hc.b, h1.a)
			var hl := hc.lightened(0.1)
			h2 = Color(hl.r, hl.g, hl.b, h2.a)
		var shift: float = float(pal.get("shift", 0.0))
		if shift != 0.0:
			var dh := fposmod(t * shift, 1.0)
			c_out = Color.from_hsv(fposmod(c_out.h + dh, 1.0), c_out.s, c_out.v, c_out.a)
			c_mid = Color.from_hsv(fposmod(c_mid.h + dh, 1.0), c_mid.s, c_mid.v, c_mid.a)
			c_core = Color.from_hsv(fposmod(c_core.h + dh, 1.0), c_core.s, c_core.v, c_core.a)
		var al: float = float(pal.get("alpha", 1.0))
		if al != 1.0:
			c_out.a *= al
			c_mid.a *= al
			c_core.a *= al
			h1.a *= al
			h2.a *= al
	if halo:
		ci.draw_circle(base + Vector2(0, -hh * 0.4), hh * 1.2, h1)
		ci.draw_circle(base + Vector2(0, -hh * 0.4), hh * 0.8, h2)
	ci.draw_colored_polygon(_tear(base, r, hh, sway), c_out)
	ci.draw_colored_polygon(_tear(base + Vector2(0, -r * 0.1), r * 0.72, hh * 0.78, sway * 0.8), c_mid)
	ci.draw_colored_polygon(_tear(base + Vector2(0, -r * 0.2), r * 0.42, hh * 0.5, sway * 0.5), c_core)


static func _tear(base: Vector2, r: float, h: float, sway: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(0, 11):
		var ang := PI * k / 10.0
		pts.append(base + Vector2(r * cos(ang), -r + r * sin(ang)))
	var tip := base + Vector2(sway, -h)
	var left := base + Vector2(-r, -r)
	var ctrl_l := base + Vector2(-r * 0.95, -h * 0.55)
	for k in range(1, 7):
		var s := k / 6.0
		pts.append(left.lerp(ctrl_l, s).lerp(ctrl_l.lerp(tip, s), s))
	var right := base + Vector2(r, -r)
	var ctrl_r := base + Vector2(r * 0.95, -h * 0.55)
	for k in range(1, 6):
		var s := k / 6.0
		pts.append(tip.lerp(ctrl_r, s).lerp(ctrl_r.lerp(right, s), s))
	return pts


static func chip_width(label: String, v: float, size := 12) -> float:
	return text_width(_chip_text(label, v), size, "body", 700) + 12.0


static func _chip_text(label: String, v: float) -> String:
	if v > 0.0:
		return "%s ▲ +%d%%" % [label, roundi(v)]
	if v < 0.0:
		return "%s ▼ %d%%" % [label, roundi(v)]
	return "%s =" % label


static func chip(ci: CanvasItem, pos: Vector2, label: String, v: float, size := 12, a := 1.0) -> float:
	## A "DMG ▲ +12%" chip (v is a percent), green up, red down, grey even;
	## pos is its top-left. Returns its width.
	var col := GOOD if v > 0.0 else (BAD if v < 0.0 else MUTED)
	var s := _chip_text(label, v)
	var w := text_width(s, size, "body", 700) + 12.0
	var h := size + 7.0
	var sb := box()
	sb.bg_color = Color(col.darkened(0.75), 0.92 * a)
	sb.border_color = Color(col, 0.7 * a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(h * 0.5))
	sb.draw(ci.get_canvas_item(), Rect2(pos, Vector2(w, h)))
	text(ci, pos + Vector2(6.0, size + 1.5), s, size, Color(col.lightened(0.1), a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	return w


static func pips(ci: CanvasItem, left: Vector2, n: int, filled: int, r: float, col: Color, gap := 3.0, a := 1.0) -> void:
	## A row of n dots from left (the first dot's centre), filled ones lit.
	for i in n:
		var c := left + Vector2(i * (r * 2.0 + gap), 0)
		ci.draw_circle(c, r + 1.0, Color(INK, 0.8 * a))
		if i < filled:
			ci.draw_circle(c, r, Color(col, a))
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.45 * a))
		else:
			ci.draw_arc(c, r - 0.5, 0, TAU, 12, Color(col, 0.45 * a), 1.2)


static func ember_icon(ci: CanvasItem, c: Vector2, r: float) -> void:
	## The ember purse's mark (a coal with a little flame without the art).
	var e := tex("res://art/ui/ember.svg")
	if e != null:
		ci.draw_texture_rect(e, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		return
	ci.draw_circle(c, r, Color("2a1410"))
	ci.draw_circle(c, r * 0.82, Color("e0602a"))
	ci.draw_circle(c + Vector2(-1, -1), r * 0.5, FLAME_MID)


static func glyph(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	## Small vector marks for skills and slots: heart, star, blade, shield,
	## drop, swift, flame, sun, bell, candle, coat, boots, charm, skull, lock,
	## plus; anything else is a ring.
	var w := maxf(s * 0.1, 1.4)
	match kind:
		"heart":
			var pts := PackedVector2Array()
			for i in 28:
				var t := TAU * i / 28.0
				pts.append(c + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * s / 36.0)
			ci.draw_colored_polygon(pts, col)
		"star":
			var pts := PackedVector2Array()
			for i in 8:
				var rr := s * (0.5 if i % 2 == 0 else 0.19)
				var t := TAU * i / 8.0 - PI * 0.5
				pts.append(c + Vector2(cos(t), sin(t)) * rr)
			ci.draw_colored_polygon(pts, col)
		"blade":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.26, s * 0.18), c + Vector2(s * 0.34, -s * 0.42),
					c + Vector2(s * 0.44, -s * 0.44), c + Vector2(s * 0.42, -s * 0.34), c + Vector2(-s * 0.18, s * 0.26)]), col)
			ci.draw_line(c + Vector2(-s * 0.36, s * 0.08), c + Vector2(-s * 0.08, s * 0.36), col, w * 1.3)
			ci.draw_line(c + Vector2(-s * 0.22, s * 0.22), c + Vector2(-s * 0.42, s * 0.42), col, w * 1.5)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.4), c + Vector2(s * 0.36, -s * 0.4),
					c + Vector2(s * 0.34, s * 0.02), c + Vector2(0, s * 0.44), c + Vector2(-s * 0.34, s * 0.02)]), col)
			ci.draw_line(c + Vector2(0, -s * 0.32), c + Vector2(0, s * 0.34), Color(INK, 0.35), w)
		"drop":
			var pts := PackedVector2Array()
			for i in 13:
				var t := PI * i / 12.0
				pts.append(c + Vector2(cos(t) * s * 0.3, s * 0.12 + sin(t) * s * 0.3))
			pts.append(c + Vector2(0, -s * 0.46))
			ci.draw_colored_polygon(pts, col)
		"swift":
			for k in 2:
				var o := Vector2(k * s * 0.3 - s * 0.15, 0)
				ci.draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.16, -s * 0.32), c + o + Vector2(s * 0.14, 0), c + o + Vector2(-s * 0.16, s * 0.32)]), col, w * 1.4)
		"flame":
			flame(ci, c + Vector2(0, s * 0.44), s * 0.92, 0.0, 0.0, false, col.a, false)
		"sun":
			ci.draw_circle(c, s * 0.2, col)
			for i in 8:
				var t := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(t), sin(t)) * s * 0.29, c + Vector2(cos(t), sin(t)) * s * 0.46, col, w)
		"bell":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.17, -s * 0.34), c + Vector2(s * 0.17, -s * 0.34),
					c + Vector2(s * 0.25, s * 0.1), c + Vector2(s * 0.42, s * 0.28), c + Vector2(-s * 0.42, s * 0.28), c + Vector2(-s * 0.25, s * 0.1)]), col)
			ci.draw_circle(c + Vector2(0, -s * 0.34), s * 0.17, col)
			ci.draw_circle(c + Vector2(0, s * 0.36), s * 0.09, col)
		"candle":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.08), Vector2(s * 0.3, s * 0.5)), col)
			flame(ci, c + Vector2(0, -s * 0.1), s * 0.36, 0.0, 0.0, false, col.a, false)
		"coat":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.14, -s * 0.4), c + Vector2(s * 0.14, -s * 0.4),
					c + Vector2(s * 0.42, -s * 0.24), c + Vector2(s * 0.32, s * 0.02), c + Vector2(s * 0.22, -s * 0.06),
					c + Vector2(s * 0.24, s * 0.42), c + Vector2(-s * 0.24, s * 0.42), c + Vector2(-s * 0.22, -s * 0.06),
					c + Vector2(-s * 0.32, s * 0.02), c + Vector2(-s * 0.42, -s * 0.24)]), col)
		"boots":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(0.02 * s, -s * 0.4),
					c + Vector2(0.02 * s, s * 0.1), c + Vector2(s * 0.42, s * 0.18), c + Vector2(s * 0.42, s * 0.4), c + Vector2(-s * 0.3, s * 0.4)]), col)
		"charm":
			ci.draw_arc(c + Vector2(0, -s * 0.24), s * 0.15, PI, TAU, 10, col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.14), c + Vector2(s * 0.3, s * 0.14), c + Vector2(0, s * 0.44), c + Vector2(-s * 0.3, s * 0.14)]), col)
		"skull":
			ci.draw_circle(c + Vector2(0, -s * 0.06), s * 0.34, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.14), Vector2(s * 0.4, s * 0.24)), col)
			ci.draw_circle(c + Vector2(-s * 0.13, -s * 0.04), s * 0.1, Color(INK, 0.9))
			ci.draw_circle(c + Vector2(s * 0.13, -s * 0.04), s * 0.1, Color(INK, 0.9))
			ci.draw_line(c + Vector2(-s * 0.07, s * 0.26), c + Vector2(-s * 0.07, s * 0.38), Color(INK, 0.8), 1.2)
			ci.draw_line(c + Vector2(s * 0.07, s * 0.26), c + Vector2(s * 0.07, s * 0.38), Color(INK, 0.8), 1.2)
		"lock":
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.18, PI, TAU, 10, col, w * 1.1)
			ci.draw_line(c + Vector2(-s * 0.18, -s * 0.1), c + Vector2(-s * 0.18, 0), col, w * 1.1)
			ci.draw_line(c + Vector2(s * 0.18, -s * 0.1), c + Vector2(s * 0.18, 0), col, w * 1.1)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.28, -s * 0.02), Vector2(s * 0.56, s * 0.42)), col)
		"plus":
			ci.draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), col, maxf(s * 0.16, 2.0))
			ci.draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), col, maxf(s * 0.16, 2.0))
		_:
			ci.draw_arc(c, s * 0.3, 0, TAU, 16, col, w)
			ci.draw_circle(c, s * 0.1, col)


static func slot_glyph(slot: String) -> String:
	return {"weapon": "blade", "candle": "candle", "coat": "coat", "boots": "boots", "charm": "charm"}.get(slot, "")


static func arch(ci: CanvasItem, x: float, w: float, top: float, bottom: float, col: Color) -> void:
	## A pointed gothic arch, filled: x its left edge, w its width.
	ci.draw_colored_polygon(arch_points(x, w, top, bottom), col)


static func arch_points(x: float, w: float, top: float, bottom: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var spring := top + w * 0.866
	pts.append(Vector2(x, bottom))
	for k in range(0, 9):
		var th := deg_to_rad(180.0 - 60.0 * k / 8.0)
		pts.append(Vector2(x + w + w * cos(th), spring - w * sin(th)))
	for k in range(1, 9):
		var th := deg_to_rad(60.0 - 60.0 * k / 8.0)
		pts.append(Vector2(x + w * cos(th), spring - w * sin(th)))
	pts.append(Vector2(x + w, bottom))
	return pts


static func backdrop(ci: CanvasItem, vs: Vector2) -> void:
	## Every menu's background: the dark and a row of far arches.
	ci.draw_rect(Rect2(Vector2.ZERO, vs), BG)
	for i in 7:
		var x := i * vs.x / 6.0 - 60.0
		arch(ci, x, 120.0, 60.0 + (i % 2) * 30.0, vs.y + 10.0, ARCH)


# ---------------------------------------------------------------- v3: worlds, secrets, cards
# New drawing goes through a TriBatch (contract §1: no draw_circle,
# draw_colored_polygon or draw_polyline in new code): build the shapes into
# a batch, flush it once, then draw the text over it.

static func batch() -> RefCounted:
	return TriBatch.new()


static func world_accent(w: int) -> Color:
	## A world's accent (spec §10): its map tab, its name, its emblem.
	return WORLD_ACCENT.get(w, GOLD)


static func world_icon(w: int) -> Texture2D:
	## art/ui/world_<n>.svg (A8), or null: world_emblem draws a stand-in.
	return tex("res://art/ui/world_%d.svg" % w)


static func world_emblem(ci: CanvasItem, w: int, c: Vector2, s: float, col: Color) -> void:
	## A world's mark, s across: its icon when the art exists, else drawn in
	## code: W1 a bell, W2 a candle's drip, W3 a skull-fruit tree, W4 a gear
	## with an icicle, W5 a shard of glass, W6 an eye.
	var t := world_icon(w)
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, col.a))
		return
	var tb := TriBatch.new()
	var k := s / 2.0
	var ink := Color(INK, 0.85 * col.a)
	match w:
		1:
			tb.circle(c + Vector2(0, -k * 0.62), k * 0.16, col, 10)
			tb.convex(PackedVector2Array([c + Vector2(-k * 0.3, -k * 0.62), c + Vector2(k * 0.3, -k * 0.62),
					c + Vector2(k * 0.46, k * 0.18), c + Vector2(k * 0.78, k * 0.5), c + Vector2(-k * 0.78, k * 0.5),
					c + Vector2(-k * 0.46, k * 0.18)]), col)
			tb.circle(c + Vector2(0, k * 0.66), k * 0.16, col, 10)
		2:
			tb.rect(Rect2(c + Vector2(-k * 0.34, -k * 0.2), Vector2(k * 0.68, k * 0.9)), col)
			tb.circle(c + Vector2(k * 0.12, k * 0.02), k * 0.13, Color(col.lightened(0.35), col.a), 8)
			var drop := PackedVector2Array()
			for i in 9:
				var a := PI * i / 8.0
				drop.append(c + Vector2(k * 0.52 + cos(a) * k * 0.2, k * 0.52 + sin(a) * k * 0.2))
			drop.append(c + Vector2(k * 0.52, k * 0.04))
			tb.convex(drop, col)
			tb.convex(PackedVector2Array([c + Vector2(0, -k * 0.86), c + Vector2(k * 0.2, -k * 0.42),
					c + Vector2(0, -k * 0.28), c + Vector2(-k * 0.2, -k * 0.42)]), Color(EMBER, col.a))
		3:
			tb.rect(Rect2(c + Vector2(-k * 0.12, -k * 0.1), Vector2(k * 0.24, k * 0.95)), col)
			tb.line(c + Vector2(0, k * 0.1), c + Vector2(-k * 0.55, -k * 0.35), k * 0.16, col)
			tb.line(c + Vector2(0, k * 0.0), c + Vector2(k * 0.6, -k * 0.45), k * 0.16, col)
			tb.line(c + Vector2(0, -k * 0.1), c + Vector2(k * 0.05, -k * 0.8), k * 0.14, col)
			for p in [Vector2(-k * 0.6, -k * 0.2), Vector2(k * 0.64, -k * 0.3), Vector2(k * 0.08, -k * 0.82)]:
				tb.circle(c + p + Vector2(0, k * 0.14), k * 0.2, col, 10)
				tb.circle(c + p + Vector2(-k * 0.07, k * 0.12), k * 0.05, ink, 6)
				tb.circle(c + p + Vector2(k * 0.07, k * 0.12), k * 0.05, ink, 6)
		4:
			var gc := c + Vector2(0, -k * 0.16)
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				var q := Vector2(-d.y, d.x)
				tb.quad(gc + d * k * 0.46 - q * k * 0.13, gc + d * k * 0.74 - q * k * 0.1,
						gc + d * k * 0.74 + q * k * 0.1, gc + d * k * 0.46 + q * k * 0.13, col)
			tb.ring(gc, k * 0.38, k * 0.2, col, 16)
			tb.tri(c + Vector2(-k * 0.14, k * 0.3), c + Vector2(k * 0.14, k * 0.3), c + Vector2(0, k * 0.98), Color(col.lightened(0.3), col.a))
		5:
			tb.convex(PackedVector2Array([c + Vector2(-k * 0.08, -k * 0.95), c + Vector2(k * 0.5, -k * 0.2),
					c + Vector2(k * 0.2, k * 0.95), c + Vector2(-k * 0.5, k * 0.3)]), col)
			tb.tri(c + Vector2(-k * 0.08, -k * 0.95), c + Vector2(-k * 0.5, k * 0.3), c + Vector2(-k * 0.1, k * 0.1), Color(col.lightened(0.4), col.a))
		6:
			var eye := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				eye.append(c + Vector2(-cos(a) * k * 0.9, -sin(a) * k * 0.5))
			for i in range(1, 12):
				var a := PI * i / 12.0
				eye.append(c + Vector2(cos(a) * k * 0.9, sin(a) * k * 0.5))
			tb.convex(eye, col)
			tb.circle(c, k * 0.3, ink, 14)
			tb.circle(c + Vector2(-k * 0.1, -k * 0.1), k * 0.09, Color(col.lightened(0.4), col.a), 8)
		_:
			tb.ring(c, k * 0.6, k * 0.15, col, 16)
	tb.flush(ci)


static func sparkle(tb: RefCounted, c: Vector2, r: float, col: Color) -> void:
	## A four-pointed star into a batch: a silver spark (a secret's), a
	## Candlemark's glint.
	tb.convex(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.26, -r * 0.26), c + Vector2(r, 0),
			c + Vector2(r * 0.26, r * 0.26), c + Vector2(0, r), c + Vector2(-r * 0.26, r * 0.26),
			c + Vector2(-r, 0), c + Vector2(-r * 0.26, -r * 0.26)]), col)


static func mark_badge(ci: CanvasItem, pos: Vector2, n: int, size := 11, a := 1.0) -> float:
	## "✦3": the Candlemarks past level 40 (a gold four-point star and the
	## count; the star is A8's candlemark.svg when it exists). pos is the
	## left end of its baseline. Returns its width.
	if n <= 0:
		return 0.0
	var s := float(size)
	var c := pos + Vector2(s * 0.5, -s * 0.36)
	var t := tex("res://art/ui/candlemark.svg")
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.55, Vector2(s, s) * 1.1), false, Color(1, 1, 1, a))
	else:
		var tb := TriBatch.new()
		sparkle(tb, c, s * 0.62, Color(GOLD, a))
		tb.flush(ci)
	var num := str(n)
	text(ci, pos + Vector2(s + 1.0, 0), num, size, Color(GOLD, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3)
	return s + 1.0 + text_width(num, size, "body", 800)


static func card_rect(vs: Vector2, safe: Rect2, body: String) -> Rect2:
	## A one-time card's panel: centred, wide enough for its words.
	var w := minf(460.0, safe.size.x - 40.0)
	var lines := wrap_lines(body, w - 48.0, 15)
	var h := 96.0 + lines.size() * 20.0 + 52.0
	return Rect2(vs.x * 0.5 - w * 0.5, clampf(vs.y * 0.5 - h * 0.5, safe.position.y + 4.0, safe.end.y), w, minf(h, safe.size.y - 8.0))


static func draw_card(ci: CanvasItem, r: Rect2, title: String, body: String, col := GOLD, a := 1.0, emblem := -1) -> void:
	## A one-time card (the map's v3 news, the Nightfall warning, the HUD's
	## candle-strength card): a panel, an emblem (a world's, or a bell), the
	## title and the words. Its button (OK) is the host's own.
	panel(ci, r, Color(col, 0.85 * a), Color(PANEL, 0.97 * a), 14.0)
	var c := Vector2(r.get_center().x, r.position.y + 30.0)
	var tb := TriBatch.new()
	tb.circle(c, 19.0, Color(col, 0.16 * a), 20)
	tb.ring(c, 19.0, 1.5, Color(col, 0.6 * a), 24)
	tb.flush(ci)
	if emblem > 0:
		world_emblem(ci, emblem, c, 26.0, Color(col, a))
	else:
		glyph(ci, "bell", c, 24.0, Color(col, a))
	var tw := r.size.x - 40.0
	text(ci, Vector2(r.position.x + 20.0, r.position.y + 76.0), title, fit_size(title, tw, 24, 16, "title", 700), Color(col, a), HORIZONTAL_ALIGNMENT_CENTER, tw, "title", 700)
	var lines := wrap_lines(body, r.size.x - 48.0, 15)
	for i in lines.size():
		text(ci, Vector2(r.position.x + 24.0, r.position.y + 102.0 + i * 20.0), lines[i], 15, Color(CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 48.0)


static var secret_levels_override = null   # tests and screenshots: a stand-in for Game.SECRET_LEVELS


static func secret_levels() -> Array:
	## Game.SECRET_LEVELS ({id, path, world, from}), or the tests' stand-in.
	if secret_levels_override is Array:
		return secret_levels_override
	var g = Engine.get_main_loop().root.get_node_or_null("Game") if Engine.get_main_loop() is SceneTree else null
	if g == null:
		return []
	return (g.get_script() as Script).get_script_constant_map().get("SECRET_LEVELS", [])


static var _headers := {}         # path -> {key: value}: level files' headers, read once a run


static func level_headers(path: String) -> Dictionary:
	## A level file's headers (the lines before "---"), read once a run.
	if _headers.has(path):
		return _headers[path]
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
	while f != null and not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("---"):
			break
		var k := line.find(":")
		if k > 0:
			out[line.substr(0, k).strip_edges()] = line.substr(k + 1).strip_edges()
	_headers[path] = out
	return out


static func secret_title(id: String) -> String:
	## A secret level's name, from its file's title (or its id).
	for sl in secret_levels():
		if sl is Dictionary and str(sl.get("id", "")) == id:
			var t := str(level_headers(str(sl.get("path", ""))).get("title", ""))
			if t != "":
				return t
	return id
