extends Node2D
## The hero's body: the paper-doll parts of a calling from art/heroes/<cls>/
## (falling back to art/wick/), one 128-unit frame each, feet at (64, 122),
## 2 units to the pixel, each turned about its joint every frame from what
## the Player is doing, with the kit's pose() overrides on top. The candle's
## flame is not drawn here: flame_point() tells the Glow layer where it
## burns. Set cls (and kit) before adding it to the tree.
##
## <dir>/rig.json (optional): {"flame_tip": [x, y], "offhand": bool,
##   "offhand_front": bool, "weapon_rest_deg": 80, "weapon_tip": [x, y]}
##
## Each part falls back on its own: art/heroes/<cls>/<part>.svg, then
## art/wick/<part>.svg. A calling's weapon (weapon.svg, or sword.svg) never
## falls back to the knight's sword: until its art exists a small stand-in
## (staff, knife, maul, spade) is drawn in code, and so is an offhand (the
## knight's lantern shield, the sexton's handbell). The offhand follows the
## back hand; it is drawn in front of the body when rig.json says
## offhand_front or a pose asks for it (a raised guard).
##
## kit.pose() keys read here, beyond kit.gd's list: offhand_front (in front
## of the body), offhand_top (over the weapon arm too), offhand_off (a
## Vector2 in px from the back hand, facing right), offhand_scale.
##
## Visible gear (decisions.md): the candle part grows with the candle's tier
## (x0.85 / 1.0 / 1.15, and v3's T4 x1.20 and T5 x1.25, about rig.json
## candle_base, so the flame rides it), the coat's rarity tints the cape, and
## a Legendary weapon glints. Read from the hero of this calling in Game
## (every half second, while there is a player), or set `gear` and
## `gear_auto = false`.
##
## The look (v3, the modes' cosmetics): set_look({trim, trim_color, ...})
## hems the cape with art/heroes/<cls>/cape_trim_<trim>.svg (white art
## tinted by modulate), riding the cape's joint over the cape itself, so the
## coat's tint never reaches it; no pattern, or no art yet, shows none. With
## gear_auto the look is read from the hero too. weapon_visible() says
## whether the weapon shows now (a weapon glow is skipped when it doesn't).

const Classes := preload("res://scripts/classes.gd")
const FRAME_FEET := Vector2(64, 122)
const TEX_SCALE := 0.25           # 256 px textures -> 64 px frames
const PIVOTS := {
	"cape": Vector2(58, 84), "leg_back": Vector2(60, 104), "arm_back": Vector2(54, 86),
	"body": Vector2(64, 108), "leg_front": Vector2(68, 104), "head": Vector2(64, 84),
	"candle": Vector2(60, 34), "arm_front": Vector2(74, 86), "sword": Vector2(64, 96),
	"weapon": Vector2(64, 96), "offhand": Vector2(52, 101),
}
const HAND := Vector2(76, 101)    # where the front fist grips the weapon
const HAND_BACK := Vector2(52, 101)   # where the back hand holds an offhand
const WICK_TIP := Vector2(60, 19) # the flame's base, on top of the candle (default)
const HEADS := ["head", "head_blink", "head_hurt", "head_happy", "head_fierce"]
const FALLBACK := "res://art/wick/"
const OFFHANDS := {"knight": true, "sexton": true}   # callings that carry one (when rig.json doesn't say)
# Where the weapon's business end is, in its own 128 frame (rig.json weapon_tip overrides).
# (W6a's measured points on the art; the stand-ins are drawn to about the same.)
const WEAPON_TIPS := {"knight": Vector2(64, 41.6), "witch": Vector2(63.4, 34.8), "runner": Vector2(64.6, 60.4),
		"founder": Vector2(78.6, 60.9), "sexton": Vector2(64, 38.2)}
const INK := Color("1c1830")
# How each calling carries its weapon at rest (rig.json weapon_rest_deg overrides):
# the sword held out, the staff and spade upright, the maul's head down by her feet.
const WEAPON_REST := {"knight": 80.0, "witch": 12.0, "runner": 100.0, "founder": 105.0, "sexton": 14.0}
const WEAPON_LEAN := 0.35         # in the air or a flinch the weapon points at least this far forward of up (rad)
const OFFHAND_LIFT := -0.8        # the back arm lifts a shield worn in front no higher than this (rad)
const CANDLE_TIER := [0.85, 1.0, 1.15, 1.20, 1.25]   # by the candle's tier, T1..T5
# The cape trims' colours (p_modes.md §8.2; "calling" is the calling's own colour).
const TRIM_COLORS := {"bronze": Color("b07a3a"), "silver": Color("c8d0e0"), "gold": Color("ffd84a"),
		"ember": Color("f07a2a"), "bone": Color("e8e0cc"), "rime": Color("a8e8ff"), "hush": Color("5a4a8a"),
		"moth": Color("d8e8c8")}
const TRIM_PATTERNS := ["band", "tongues", "stitch", "bells", "scallop"]
const CAPE_TINT := {"magic": Color("7aa8ff"), "rare": Color("ffd84a"), "legendary": Color("ff8a2a")}
const CAPE_TINT_MIX := 0.4        # how far the cape leans toward its coat's colour
const GLINT_EVERY := 2.4          # a Legendary weapon's glint runs up the blade this often...
const GLINT_RUN := 0.32           # ...taking this long

var player: Node2D
var cls := "knight"
var kit: Object = null
var dir := "res://art/wick/"
var rigdata := {}
var flame_tip := WICK_TIP
var weapon_rest := deg_to_rad(80)
var mood := ""                    # "happy" at the bell; "" follows play
var _joints := {}                 # part -> Node2D joint
var _sprites := {}                # part -> Sprite2D
var _heads := {}                  # head name -> Texture2D
var _squash: Node2D
var _t := 0.0
var _phase := 0.0
var _blink := 2.0
var _land_squash := 0.0
var _stretch := 0.0
var _cape_swing := 0.0
var _was_floor := true
var _down := 0.0
var has_art := false
var _offhand_layer := -1         # where the offhand is drawn now: 0 behind, 1 in front, 2 on top
var _weapon_tip := Vector2(64, 41.6)
var gear := {}                    # {candle_tier 0-3, coat_rarity, weapon_legend}; {} = none shown
var gear_auto := true             # read gear from Game (else keep what was set)
var _gear_t := 0.0
var _candle_base := Vector2(60, 34)
var _glint: Node2D
var look := {}                    # {flame, trim, trim_color, glow} (the modes' cosmetics); {} = none
var _trim: Sprite2D               # the cape's trim, when a pattern with art is worn
var _trim_path := ""


func _ready() -> void:
	_squash = Node2D.new()
	add_child(_squash)
	var d := "res://art/heroes/%s/" % cls
	dir = d if ResourceLoader.exists(d + "body.svg") else FALLBACK
	has_art = ResourceLoader.exists(dir + "body.svg") or ResourceLoader.exists(FALLBACK + "body.svg")
	var rj := dir + "rig.json"
	if FileAccess.file_exists(rj):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(rj))
		if parsed is Dictionary:
			rigdata = parsed
	if not rigdata.has("offhand") and dir == FALLBACK:
		rigdata["offhand"] = OFFHANDS.get(cls, false)
	if rigdata.has("flame_tip"):
		flame_tip = Vector2(rigdata["flame_tip"][0], rigdata["flame_tip"][1])
	weapon_rest = deg_to_rad(float(rigdata.get("weapon_rest_deg", WEAPON_REST.get(cls, 80.0))))
	_weapon_tip = WEAPON_TIPS.get(cls, WEAPON_TIPS["knight"])
	if rigdata.has("weapon_tip"):
		_weapon_tip = Vector2(rigdata["weapon_tip"][0], rigdata["weapon_tip"][1])
	_candle_base = PIVOTS["candle"]
	if rigdata.has("candle_base"):
		_candle_base = Vector2(rigdata["candle_base"][0], rigdata["candle_base"][1])
	for name in HEADS:
		var p := _part_path(name)
		if p != "":
			_heads[name] = load(p)
	# Back to front. The weapon hangs off the front arm's hand, behind the arm;
	# the offhand follows the back hand (its place in the order can change).
	_add_part("cape", _squash)
	_add_part("leg_back", _squash)
	_add_part("arm_back", _squash)
	if rigdata.get("offhand", false):
		var j := Node2D.new()
		j.name = "offhand"
		j.position = _joint_pos(HAND_BACK, Vector2.ZERO)
		j.set_meta("rest", j.position)
		_squash.add_child(j)
		_joints["offhand"] = j
		_add_sprite("offhand", j)
		if not _sprites.has("offhand"):
			_add_standin(j, "offhand")
	_add_part("body", _squash)
	_add_part("leg_front", _squash)
	var head: Node2D = _add_part("head", _squash)
	_add_part("candle", head, PIVOTS["head"])
	var arm: Node2D = _add_joint("arm_front", _squash, Vector2.ZERO)
	var sword: Node2D = _add_part("sword", arm, PIVOTS["arm_front"], HAND)
	sword.rotation = weapon_rest
	if not _sprites.has("sword"):
		_add_standin(sword, "weapon")
	_glint = Node2D.new()
	_glint.name = "glint"
	_glint.visible = false
	sword.add_child(_glint)
	_glint.draw.connect(_draw_glint)
	_add_sprite("arm_front", arm)
	_place_offhand(1 if rigdata.get("offhand_front", false) else 0)
	if not look.is_empty():
		set_look(look)   # a look set before the parts were built


func _part_path(part: String) -> String:
	## A part's SVG: the calling's own, else the shared one (never the knight's
	## sword for another calling's weapon).
	var names := [part]
	if part == "sword":
		names = ["weapon", "sword"]
	var own := "res://art/heroes/%s/" % cls
	for n in names:
		var p: String = own + n + ".svg"
		if ResourceLoader.exists(p):
			return p
	if (part == "sword" and cls != "knight") or part == "offhand":
		return ""   # another calling's weapon, or an offhand: drawn as a stand-in
	var fb: String = FALLBACK + part + ".svg"
	return fb if ResourceLoader.exists(fb) else ""


func _place_offhand(layer: int) -> void:
	## The offhand behind the body (0: just after the back arm), in front of
	## it (1: just before the front arm), or over everything (2: after the
	## front arm, so a raised shield or a rung bell covers the weapon arm).
	var j: Node2D = _joints.get("offhand")
	if j == null or layer == _offhand_layer:
		return
	_offhand_layer = layer
	var anchor: Node2D = _joints.get("arm_back") if layer == 0 else _joints.get("arm_front")
	if anchor == null:
		return
	var at := anchor.get_index() if layer == 1 else anchor.get_index() + 1
	if j.get_index() < at:
		at -= 1
	_squash.move_child(j, at)


func _joint_pos(pivot: Vector2, parent_pivot: Vector2) -> Vector2:
	## A joint's place, in pixels, from its pivot in frame units.
	if parent_pivot == Vector2.ZERO:
		return (pivot - FRAME_FEET) * 0.5
	return (pivot - parent_pivot) * 0.5


func _add_joint(part: String, parent: Node2D, parent_pivot: Vector2, at := Vector2.INF) -> Node2D:
	var j := Node2D.new()
	j.name = part
	var pivot: Vector2 = PIVOTS[part] if at == Vector2.INF else at
	j.position = _joint_pos(pivot, parent_pivot)
	j.set_meta("rest", j.position)
	parent.add_child(j)
	_joints[part] = j
	return j


func _add_sprite(part: String, joint: Node2D) -> void:
	var path := _part_path(part)
	if path == "":
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.scale = Vector2(TEX_SCALE, TEX_SCALE)
	s.offset = -PIVOTS[part] * 2.0     # the pivot, in texture pixels, on the joint
	joint.add_child(s)
	_sprites[part] = s


func _add_part(part: String, parent: Node2D, parent_pivot := Vector2.ZERO, at := Vector2.INF) -> Node2D:
	var j := _add_joint(part, parent, parent_pivot, at)
	_add_sprite(part, j)
	return j


func _add_standin(joint: Node2D, what: String) -> void:
	## Until a calling's own art exists: its weapon or offhand drawn in code,
	## pointing up from the hand like the weapon art does.
	var n := Node2D.new()
	n.name = "standin_" + what
	joint.add_child(n)
	n.draw.connect(func(): _draw_standin(n, what))
	n.queue_redraw()


func _draw_standin(n: Node2D, what: String) -> void:
	var wood := Color("7a4a2a")
	if what == "offhand":
		if cls == "sexton":
			# A small bronze handbell: a wooden grip, a round crown flaring to
			# a lipped mouth, the clapper just showing under it.
			n.draw_line(Vector2(0, 2), Vector2(0, -4), INK, 4.2)
			n.draw_line(Vector2(0, 2), Vector2(0, -4), wood, 2.2)
			n.draw_circle(Vector2(0, -4.6), 1.9, INK)
			n.draw_circle(Vector2(0, -4.6), 1.0, wood)
			var bell := PackedVector2Array()
			for k in 7:   # the crown
				var a := PI + PI * k / 6.0
				bell.append(Vector2(cos(a) * 2.8, 3.6 + sin(a) * 2.2))
			bell.append_array(PackedVector2Array([Vector2(3.4, 6.0), Vector2(5.4, 8.8), Vector2(-5.4, 8.8), Vector2(-3.4, 6.0)]))
			n.draw_colored_polygon(_grow(bell, 1.5), INK)
			n.draw_colored_polygon(bell, Color("c8893a"))
			n.draw_line(Vector2(-5.2, 8.4), Vector2(5.2, 8.4), Color("8e5a24"), 1.4)   # the lip
			n.draw_line(Vector2(-1.8, 2.4), Vector2(-3.4, 7.2), Color("f2c07a"), 1.1)  # a glint
			n.draw_circle(Vector2(0, 10.2), 1.5, INK)
			n.draw_circle(Vector2(0, 10.2), 0.8, Color("f2c07a"))
		else:
			# The lantern shield: a steel rim round a little rose window.
			n.draw_circle(Vector2.ZERO, 8.2, INK)
			n.draw_circle(Vector2.ZERO, 7.0, Color("c3c7d6"))
			n.draw_circle(Vector2.ZERO, 5.0, INK)
			var panes := [Color("d8b24a"), Color("b8342a"), Color("3e5eb0"), Color("d8b24a")]
			for i in 4:
				var a0 := TAU * i / 4.0 + 0.4
				var pts := PackedVector2Array([Vector2.ZERO])
				for k in 5:
					var a := a0 + (TAU / 4.0) * k / 4.0
					pts.append(Vector2(cos(a), sin(a)) * 4.2)
				n.draw_colored_polygon(pts, panes[i])
			n.draw_circle(Vector2.ZERO, 1.3, Color("fff4cf"))
			n.draw_circle(Vector2(-2.4, -2.6), 1.0, Color(1, 1, 1, 0.5))
		return
	match cls:
		"witch":
			# A crooked taper staff with a three-candle fork.
			var pts := PackedVector2Array([Vector2(0.5, 7), Vector2(-0.5, -6), Vector2(0.8, -16), Vector2(0, -26)])
			n.draw_polyline(pts, INK, 4.4)
			n.draw_polyline(pts, wood, 2.4)
			n.draw_line(Vector2(-4.5, -26), Vector2(4.5, -26), INK, 3.6)
			n.draw_line(Vector2(-4.5, -26), Vector2(4.5, -26), Color("c8893a"), 1.8)
			for x in [-4.0, 0.0, 4.0]:
				var h := 5.0 if x == 0.0 else 3.8
				n.draw_rect(Rect2(x - 1.6, -26.0 - h - 0.8, 3.2, h + 1.0), INK)
				n.draw_rect(Rect2(x - 0.9, -26.0 - h, 1.8, h), Color("f4ead6"))
		"runner":
			# A slim knife with a brass snuffer-bell pommel.
			n.draw_colored_polygon(PackedVector2Array([Vector2(-2.4, -1), Vector2(2.4, -1), Vector2(0, -15.5)]), INK)
			n.draw_colored_polygon(PackedVector2Array([Vector2(-1.2, -2), Vector2(1.2, -2), Vector2(0, -13.5)]), Color("e8ecf4"))
			n.draw_line(Vector2(-3, -1), Vector2(3, -1), INK, 2.6)
			n.draw_line(Vector2(0, -1), Vector2(0, 3), INK, 3.0)
			n.draw_circle(Vector2(0, 3.6), 1.8, Color("c8893a"))
		"founder":
			# The Founder's Maul: an ash haft with a sideways bell for a head.
			n.draw_line(Vector2(0, 8), Vector2(0, -22), INK, 4.6)
			n.draw_line(Vector2(0, 8), Vector2(0, -22), Color("b08a5a"), 2.6)
			var bell := PackedVector2Array([Vector2(-6, -21), Vector2(-4, -30), Vector2(4, -30), Vector2(7, -21)])
			n.draw_colored_polygon(_grow(bell, 1.6), INK)
			n.draw_colored_polygon(bell, Color("c8893a"))
			n.draw_line(Vector2(-3.5, -28.5), Vector2(-5, -22.5), Color("f2c07a"), 1.4)
			n.draw_circle(Vector2(7.6, -21), 1.6, Color("8e5a24"))
		"sexton":
			# A grave spade: wooden haft, iron blade.
			n.draw_line(Vector2(0, 7), Vector2(0, -21), INK, 4.4)
			n.draw_line(Vector2(0, 7), Vector2(0, -21), wood, 2.4)
			var blade := PackedVector2Array([Vector2(-4.5, -21), Vector2(4.5, -21), Vector2(4.2, -29), Vector2(0, -33), Vector2(-4.2, -29)])
			n.draw_colored_polygon(_grow(blade, 1.4), INK)
			n.draw_colored_polygon(blade, Color("8b90a8"))
			n.draw_line(Vector2(-2.6, -22.5), Vector2(-2.4, -28.5), Color("c3c7d6"), 1.2)
		_:
			n.draw_line(Vector2(0, 6), Vector2(0, -26), INK, 4.0)
			n.draw_line(Vector2(0, 6), Vector2(0, -26), Color("e8ecf4"), 2.0)


func _grow(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	## The polygon pushed out from its middle (a cheap outline).
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - c).normalized() * by)
	return out


func _read_gear() -> Dictionary:
	## What this calling's hero wears, from Game (none made: nothing shown).
	var g := get_node_or_null("/root/Game")
	if g == null or not g.has_method("heroes"):
		return {}
	var heroes: Dictionary = g.heroes()
	if not heroes.has(cls) or not (heroes[cls] is Dictionary):
		return {}
	var eq = heroes[cls].get("equip", {})
	if not (eq is Dictionary):
		return {}
	var out := {}
	var candle = eq.get("candle")
	if candle is Dictionary:
		out["candle_tier"] = int(candle.get("tier", 1))
	var coat = eq.get("coat")
	if coat is Dictionary:
		out["coat_rarity"] = str(coat.get("rarity", "common"))
	var weapon = eq.get("weapon")
	if weapon is Dictionary:
		out["weapon_legend"] = str(weapon.get("rarity", "")) == "legendary"
	return out


func _read_look() -> Dictionary:
	## The look this calling's hero wears, from Game ({} when none).
	var g := get_node_or_null("/root/Game")
	if g == null or not g.has_method("heroes"):
		return {}
	var heroes: Dictionary = g.heroes()
	if not heroes.has(cls) or not (heroes[cls] is Dictionary):
		return {}
	var lk = heroes[cls].get("look", {})
	return lk if lk is Dictionary else {}


static func _bare_id(id: String) -> String:
	## "trim:band" and "band" alike (the save keeps plain ids; the catalogue namespaces them).
	var i := id.find(":")
	return id.substr(i + 1) if i >= 0 else id


func trim_color(id: String) -> Color:
	## A trim colour id (or a hex string) as a Color; "calling" (or anything
	## unknown) is the calling's own colour.
	var k := _bare_id(id)
	if TRIM_COLORS.has(k):
		return TRIM_COLORS[k]
	if k != "calling" and k != "" and Color.html_is_valid(k):
		return Color.html(k)
	var info: Dictionary = Classes.info(cls)
	return Color(str(info.get("color", "ffffff")))


func trim_path(pattern: String) -> String:
	## The trim art for a pattern on this calling, or "" when it isn't drawn yet.
	var k := _bare_id(pattern)
	if k == "":
		return ""
	var p := "res://art/heroes/%s/cape_trim_%s.svg" % [cls, k]
	return p if ResourceLoader.exists(p) else ""


func set_look(lk: Dictionary, tex: Texture2D = null) -> void:
	## Wears a look: the cape trim (pattern and colour). tex stands in for the
	## pattern's art (tests; a preview before the art lands).
	look = lk.duplicate()
	var cape: Node2D = _joints.get("cape")
	var pattern := _bare_id(str(lk.get("trim", "")))
	var path := trim_path(pattern)
	if cape == null or pattern == "" or (path == "" and tex == null):
		if _trim != null:
			_trim.visible = false
		return
	if _trim == null:
		_trim = Sprite2D.new()
		_trim.name = "cape_trim"
		_trim.centered = false
		_trim.scale = Vector2(TEX_SCALE, TEX_SCALE)
		_trim.offset = -PIVOTS["cape"] * 2.0
		cape.add_child(_trim)   # after the cape's own sprite: over it, never under its tint
	if tex != null:
		_trim.texture = tex
		_trim_path = ""
	elif path != _trim_path:
		_trim.texture = load(path)
		_trim_path = path
	_trim.modulate = trim_color(str(lk.get("trim_color", "calling")))
	_trim.visible = true


func trim_visible() -> bool:
	return _trim != null and _trim.visible


func weapon_visible() -> bool:
	## Does the weapon show now? Not while he's snuffed, nor while a kit's
	## pose hides it (a thrown knife: the weapon's alpha under 0.5).
	if player != null and player.get("alive") == false:
		return false
	var wj: Node2D = _joints.get("sword")
	return wj != null and wj.visible and wj.modulate.a >= 0.5


func set_gear(gd: Dictionary) -> void:
	## Shows gear on the body: candle size, cape tint, the weapon's glint.
	gear = gd
	var candle: Node2D = _joints.get("candle")
	if candle:
		var tier := int(gd.get("candle_tier", 0))
		var k: float = CANDLE_TIER[clampi(tier, 1, CANDLE_TIER.size()) - 1] if tier > 0 else 1.0
		# Grown about its base on the head, not its pivot, so it stays seated.
		var rest: Vector2 = candle.get_meta("rest")
		candle.scale = Vector2(k, k)
		candle.position = rest + (_candle_base - PIVOTS["candle"]) * 0.5 * (1.0 - k)
	var cape: Sprite2D = _sprites.get("cape")
	if cape:
		var tint: Color = CAPE_TINT.get(str(gd.get("coat_rarity", "")), Color.WHITE)
		cape.modulate = Color.WHITE.lerp(tint, CAPE_TINT_MIX) if tint != Color.WHITE else Color.WHITE
	if _glint:
		_glint.visible = bool(gd.get("weapon_legend", false))


func _draw_glint() -> void:
	## A Legendary weapon: a bead of light runs up the blade to its point and
	## flashes there, every GLINT_EVERY seconds.
	var q := fmod(_t, GLINT_EVERY) / GLINT_RUN
	if q > 1.35:
		return
	var tip := (_weapon_tip - PIVOTS["weapon"]) * 0.5
	var from := tip * 0.3
	if q <= 1.0:
		var at := from.lerp(tip, q)
		var back := from.lerp(tip, maxf(q - 0.25, 0.0))
		_glint.draw_line(back, at, Color(1.0, 0.95, 0.8, 0.35), 3.0)
		_glint.draw_line(back.lerp(at, 0.5), at, Color(1, 1, 1, 0.95), 1.4)
	var star := clampf(1.0 - absf(q - 1.0) / 0.35, 0.0, 1.0)
	if star > 0.0:
		var r := 4.5 * star
		_glint.draw_line(tip + Vector2(-r, 0), tip + Vector2(r, 0), Color(1, 1, 1, 0.9 * star), 1.2)
		_glint.draw_line(tip + Vector2(0, -r), tip + Vector2(0, r), Color(1, 1, 1, 0.9 * star), 1.2)
		_glint.draw_circle(tip, 1.3 * star, Color(1.0, 0.95, 0.8, star))


func weapon_point() -> Vector2:
	## The weapon's business end in world space (a staff's tip, a maul's bell).
	var w: Node2D = _joints.get("sword")
	if w == null:
		return global_position + Vector2(0, -24)
	return w.to_global((_weapon_tip - PIVOTS["weapon"]) * 0.5)


func hand_point(back := false) -> Vector2:
	## The front (weapon) hand or the back (offhand) hand in world space.
	var j: Node2D = _joints.get("offhand" if back else "sword")
	if j != null:
		return j.global_position
	var arm: Node2D = _joints.get("arm_back" if back else "arm_front")
	if arm == null:
		return global_position + Vector2(0, -18)
	var hand := HAND_BACK if back else HAND
	return arm.to_global((hand - PIVOTS["arm_back" if back else "arm_front"]) * 0.5)


func flame_point() -> Vector2:
	## The flame's base in world space, following the head and candle.
	var candle: Node2D = _joints.get("candle")
	if candle == null:
		return global_position + Vector2(0, -52)
	return candle.to_global((flame_tip - PIVOTS["candle"]) * 0.5)


func _process(dt: float) -> void:
	if player == null:
		return
	_t += dt
	if gear_auto:
		_gear_t -= dt
		if _gear_t <= 0.0:
			_gear_t = 0.5
			set_gear(_read_gear())
			var lk := _read_look()
			if lk != look:
				set_look(lk)
	if _glint and _glint.visible:
		_glint.queue_redraw()
	scale.x = float(player.facing)
	var vx: float = player.velocity.x
	var vy: float = player.velocity.y
	var grounded: bool = player.on_floor
	var run := clampf(absf(vx) / 205.0, 0.0, 1.0) if grounded else 0.0
	_phase += absf(vx) * dt / 64.0 * TAU if grounded else 0.0

	if grounded and not _was_floor:
		_land_squash = 1.0
	if not grounded and _was_floor and vy < -200.0:
		_stretch = 1.0
	_was_floor = grounded
	_land_squash = move_toward(_land_squash, 0.0, dt * 7.0)
	_stretch = move_toward(_stretch, 0.0, dt * 5.0)

	var leg_b := 0.0
	var leg_f := 0.0
	var arm_b := 0.0
	var arm_f := 0.0
	var sword_rel := weapon_rest
	var bob := 0.0
	var lean := 0.0
	var head_tilt := 0.0
	if grounded:
		var s := sin(_phase)
		leg_b = s * 0.75 * run
		leg_f = -s * 0.75 * run
		arm_b = -s * 0.6 * run
		arm_f = s * 0.35 * run - 0.15 * run
		bob = -absf(sin(_phase)) * 2.2 * run + sin(_t * 2.6) * 0.6 * (1.0 - run)
		lean = 0.07 * run
		head_tilt = -0.03 * run + sin(_t * 1.3) * 0.02 * (1.0 - run)
	else:
		if vy < 0.0:
			leg_b = 0.55
			leg_f = -0.7
			arm_b = -2.0
			arm_f = -0.9
		else:
			leg_b = 0.25
			leg_f = -0.2
			arm_b = -2.5
			arm_f = -1.4
		lean = clampf(vx / 205.0, -1.0, 1.0) * float(player.facing) * 0.06
		head_tilt = clampf(vy / 600.0, -1.0, 1.0) * 0.08

	# The swing: wound up over the head, down through the front.
	var at: float = player.attack_time
	if at >= 0.0:
		var k := clampf(at / player.ATTACK_ACTIVE, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		if at > player.ATTACK_ACTIVE:
			var back := clampf((at - player.ATTACK_ACTIVE) / 0.12, 0.0, 1.0)
			arm_f = lerpf(-0.3, arm_f, back)
			sword_rel = lerpf(2.2, weapon_rest, back)
		else:
			arm_f = lerpf(-2.8, -0.3, k)
			sword_rel = 2.2
		lean += 0.08

	# Knocked back: thrown upright and leaning away.
	if player.hurt_time < 0.35:
		lean = -0.25
		arm_b = -1.8
		arm_f = -1.2
	# A weapon carried near upright at rest (a staff, a spade) would swing
	# back across the face as the arm lifts in a jump or a flinch, or as it
	# swings back on the run: keep it leaning WEAPON_LEAN forward of plumb in
	# the air, a flinch and at a run, easing back to its own rest angle as he
	# slows to a stand (a sword held out is already past all of it).
	if at < 0.0:
		var least := WEAPON_LEAN
		if grounded and player.hurt_time >= 0.35:
			least = lerpf(minf(weapon_rest, WEAPON_LEAN), WEAPON_LEAN, run)
		sword_rel = maxf(sword_rel, least - arm_f)
	# A shield carried in front of the body (the knight's) rides no higher
	# than his chest: the arms thrown up in a jump, a fall or a flinch would
	# lift it over his face. (A kit's own pose, a raised guard, still can.)
	if bool(rigdata.get("offhand_front", false)):
		arm_b = maxf(arm_b, OFFHAND_LIFT)

	var cape_target := -0.35 * run - (0.5 if vy < 0.0 and not grounded else (0.8 if vy > 150.0 else 0.0)) + sin(_t * 3.1) * 0.05
	# The kit's own poses (a guard, a thrown knife, a charging flare...).
	var o: Dictionary = kit.pose({"t": _t, "run": run, "grounded": grounded, "vy": vy, "attack_time": at}) if kit != null else {}
	leg_b = o.get("leg_b", leg_b)
	leg_f = o.get("leg_f", leg_f)
	arm_b = o.get("arm_b", arm_b)
	arm_f = o.get("arm_f", arm_f)
	sword_rel = o.get("weapon_rel", sword_rel)
	lean = o.get("lean", lean)
	cape_target = o.get("cape", cape_target)
	var hauling: bool = player.get("ledge_t") != null and float(player.ledge_t) >= 0.0
	if hauling:
		# Ledge Grab: both hands on the lip, hauling up (a shield on the back
		# arm goes up behind his head with it, not over his face).
		arm_b = -2.4
		arm_f = -2.4
		leg_b = 0.45
		leg_f = -0.35
		lean = 0.1
		sword_rel = 2.6
	var on_vine: bool = player.get("climbing") == true
	if on_vine and not hauling:
		# On a vine: both hands up the vine, hand over hand as he climbs (the
		# phase follows his height, so it stops when he hangs), knees drawn
		# up; the swing still shows on the weapon arm.
		var climb_ph: float = player.position.y * 0.11
		var moving := str(player.get("climb_state")) == "climb"
		var sw := sin(climb_ph) if moving else 0.0
		arm_b = -2.7 + 0.35 * sw
		if at < 0.0:
			arm_f = -2.5 - 0.35 * sw
			sword_rel = 2.4
		leg_b = 0.55 - 0.35 * sw
		leg_f = -0.15 + 0.35 * sw
		lean = 0.0
		cape_target = 0.25 + (0.3 if str(player.get("climb_state")) == "slide" else 0.0)
	# The wind (W5's gusts, from the tell on): a headwind throws the cape back,
	# a tailwind lifts it forward a little; it flutters meanwhile.
	var wf = player.get("world")
	if wf != null and wf.get("features") != null and wf.features.has_method("wind_at"):
		var wind: float = float(wf.features.wind_at(player.center()))
		if wind != 0.0:
			var toward := wind * float(player.facing)    # > 0: blowing the way he faces
			cape_target += (0.35 if toward > 0.0 else 0.9) * toward + sin(_t * 19.0) * 0.08 * absf(wind)
	_cape_swing = lerpf(_cape_swing, cape_target, 1.0 - exp(-dt * 10.0))
	var layer := 1 if bool(o.get("offhand_front", rigdata.get("offhand_front", false))) and not hauling else 0
	_place_offhand(2 if o.get("offhand_top", false) else layer)
	# Fade the weapon's joint, not just its sprite, so a code-drawn stand-in
	# hides too (a thrown knife leaves the hand empty).
	var wj: Node2D = _joints.get("sword")
	if wj:
		wj.modulate.a = float(o.get("weapon_alpha", 1.0))

	_set_rot("leg_back", leg_b)
	_set_rot("leg_front", leg_f)
	_set_rot("arm_back", arm_b)
	_set_rot("arm_front", arm_f)
	# The cape art shows as it turns POSITIVE (the hem flaring back); the
	# poses (and kits) speak of a flare as negative, so the joint turns the
	# other way. Negative on the joint would tuck it out of sight.
	_set_rot("cape", -_cape_swing)
	_set_rot("head", head_tilt)
	_set_rot("body", lean)
	var sword: Node2D = _joints.get("sword")
	if sword:
		sword.rotation = sword_rel
	for part in ["cape", "arm_back", "body", "head", "arm_front"]:
		var j: Node2D = _joints.get(part)
		if j:
			j.position = j.get_meta("rest") + Vector2(0, bob) + Vector2(lean * 10.0, 0) * (1.0 if part == "head" else 0.5)
	# The offhand rides in the back hand wherever the arm swings it.
	var off: Node2D = _joints.get("offhand")
	var armb: Node2D = _joints.get("arm_back")
	if off and armb:
		off.position = armb.position + ((HAND_BACK - PIVOTS["arm_back"]) * 0.5).rotated(arm_b) \
				+ (o.get("offhand_off", Vector2.ZERO) as Vector2)
		var spin: float = o.get("offhand_rot", 0.0)
		off.rotation = spin + (arm_b * 0.25 if _offhand_layer > 0 else arm_b)
		off.scale = Vector2.ONE * float(o.get("offhand_scale", 1.0))

	# Squash on landing, stretch on take-off, both about the feet.
	var sq := _land_squash * 0.22
	var st := _stretch * 0.16
	_squash.scale = Vector2(1.0 + sq - st * 0.6, 1.0 - sq + st) * (o.get("squash", Vector2.ONE) as Vector2)
	# Snuffed: he topples over backwards; relit: back on his feet.
	if not player.alive:
		_down = minf(_down + dt * 3.0, 1.0)
	else:
		_down = 0.0
	_squash.rotation = -1.35 * (1.0 - pow(1.0 - _down, 3.0))
	_squash.position = Vector2(-6.0 * _down, -4.0 * _down)

	# Face.
	_blink -= dt
	var face := "head"
	if not player.alive:
		face = "head_hurt"
	elif mood == "happy":
		face = "head_happy"
	elif player.hurt_time < 0.6:
		face = "head_hurt"
	elif at >= 0.0:
		face = "head_fierce"
	elif _blink < 0.12:
		face = "head_blink"
		if _blink < 0.0:
			_blink = randf_range(2.0, 4.5)
	var hs: Sprite2D = _sprites.get("head")
	if hs and _heads.has(face):
		hs.texture = _heads[face]

	# Blink while invulnerable.
	var inv: float = player.invuln
	modulate.a = (0.35 if inv > 0.0 and fmod(inv, 0.16) < 0.08 else 1.0) * float(o.get("alpha", 1.0))
	if not has_art:
		queue_redraw()


func _set_rot(part: String, r: float) -> void:
	var j: Node2D = _joints.get(part)
	if j:
		j.rotation = r


func _draw() -> void:
	## Stand-in until the art exists: a knight-ish capsule.
	if has_art:
		return
	draw_rect(Rect2(-10, -24, 20, 24), Color("3e4e8a"))
	draw_circle(Vector2(1, -32), 14.0, Color("c3c7d6"))
	draw_circle(Vector2(6, -33), 3.0, Color("1c1830"))
	draw_rect(Rect2(-3, -52, 6, 7), Color("efe6cc"))
