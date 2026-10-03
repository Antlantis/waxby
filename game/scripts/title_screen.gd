extends Control
## The title: the WAXBY logo over the cathedral's dark, Waxby standing under
## it in his current calling with his candle breathing, embers drifting up.
## Tap anywhere to begin: main opens the saves. The hero shown is the one in
## the slot played last (Game opens it at launch), named at the bottom left.
## v3: a Tales button at the bottom right (once ST's tales_screen.gd is in the
## build) says tales(); main opens the Tales.

signal start
signal tales

const UI := preload("res://scripts/ui.gd")
const GlowScript := preload("res://scripts/glow.gd")
const Classes := preload("res://scripts/classes.gd")

var _t := 0.0
var _logo: Texture2D
var _icon: Texture2D
var _motes: Array = []
var _glow: Node2D
var _started := false
var _cls := "knight"
var _who := ""                    # "Save 2 · Candleknight · Level 7" when a hero exists
var _tales_btn: Button
const TALES_SCREEN := "res://scripts/tales_screen.gd"
static var tales_path := TALES_SCREEN   # ST's Tales (tests may point it at a stand-in)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://art/ui/logo.svg"):
		_logo = load("res://art/ui/logo.svg")
	for i in 40:
		_motes.append({"p": Vector2(randf() * 1000.0, randf() * 500.0), "v": randf_range(12.0, 40.0), "s": randf_range(1.0, 2.6), "ph": randf() * TAU})
	# The rig, to have Waxby himself stand under the logo, in the calling
	# being played.
	var g := get_node_or_null("/root/Game")
	if g and g.has_hero(g.hero_id()):
		_cls = g.hero_id()
		_who = "%s · Level %d" % [Classes.info(_cls)["name"], int(g.hero()["level"])]
		if g.current_slot() > 0:
			_who = "Save %d · %s" % [g.current_slot(), _who]
	var holder := Node2D.new()
	holder.name = "Wick"
	add_child(holder)
	var rig := preload("res://scripts/wick_rig.gd").new()
	rig.cls = _cls
	var fake := preload("res://scripts/player.gd").new()
	fake.on_floor = true
	fake.hurt_time = 10.0
	rig.player = fake
	holder.add_child(fake)
	holder.add_child(rig)
	holder.scale = Vector2(1.8, 1.8)
	holder.set_meta("rig", rig)
	_glow = GlowScript.new()
	add_child(_glow)
	_tales_btn = UI.make_button("Tales", false, func():
		if not _started:
			_started = true
			tales.emit(), "click", 15)
	UI.small_button(_tales_btn, 15)
	_tales_btn.custom_minimum_size = Vector2(84, UI.TAP_H)
	_tales_btn.name = "Tales"
	_tales_btn.visible = ResourceLoader.exists(tales_path)
	add_child(_tales_btn)


func _gui_input(event: InputEvent) -> void:
	if _started:
		return
	var tapped := UI.is_tap(event)
	if tapped and _t > 0.4:
		_started = true
		Sfx.play("select")
		start.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _started and _t > 0.4 and (event.is_action_pressed("jump") or event.is_action_pressed("attack")):
		_started = true
		Sfx.play("select")
		start.emit()


func _process(dt: float) -> void:
	_t += dt
	var vs := get_size()
	for m in _motes:
		m["p"].y -= m["v"] * dt
		m["p"].x += sin(_t + m["ph"]) * 8.0 * dt
		if m["p"].y < -10.0:
			m["p"] = Vector2(randf() * vs.x, vs.y + 10.0)
	var holder: Node2D = get_node("Wick")
	holder.position = Vector2(vs.x * 0.5, vs.y * 0.95)
	var s := UI.safe_rect(get_viewport())
	_tales_btn.reset_size()
	_tales_btn.position = s.end - _tales_btn.size - Vector2(0, 2)
	var rig: Node2D = holder.get_meta("rig")
	_glow.extra_flames = [{"p": rig.flame_point(), "h": 19.0 * float(Classes.info(_cls)["flame_scale"]) * holder.scale.x}]
	queue_redraw()


func _draw() -> void:
	var vs := get_size()
	draw_rect(Rect2(Vector2.ZERO, vs), Color("0e0a14"))
	# The HUD's glyph warm, a chunk a frame, behind the title (no play frame
	# pays it: the rev5 review).
	UI.warm_glyphs(self)
	# Candlelight pooled where Wick stands, in cel bands.
	var c := Vector2(vs.x * 0.5, vs.y * 0.85)
	var fl := 1.0 + 0.03 * sin(_t * 11.0)
	for i in 3:
		draw_circle(c, (330.0 - i * 90.0) * fl, Color(1.0, 0.7, 0.35, 0.05 + 0.03 * i))
	# Arches behind.
	var col := Color("1f1730")
	for i in 5:
		var w := 150.0
		var x := vs.x * 0.5 + (i - 2) * 190.0 - w * 0.5
		_arch(x, w, 40.0 + absf(i - 2) * 30.0, vs.y + 10, col)
	for m in _motes:
		var a := 0.4 + 0.4 * sin(_t * 2.0 + m["ph"])
		draw_circle(m["p"], m["s"], Color(1.0, 0.72, 0.32, a))
	if _logo:
		var lw := minf(vs.x * 0.5, vs.y * 1.05)
		var lh := lw * 400.0 / 1024.0
		var bob := sin(_t * 1.4) * 3.0
		draw_texture_rect(_logo, Rect2(vs.x * 0.5 - lw * 0.5, vs.y * 0.03 + bob, lw, lh), false)
	else:
		UI.text(self, Vector2(0, vs.y * 0.34), "WAXBY", 96, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 10)
	var a := 0.55 + 0.45 * sin(_t * 3.0)
	UI.text(self, Vector2(0, vs.y * 0.56), "Tap to begin", 20, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, "body", 600, 5)
	if _who != "":
		var s := UI.safe_rect(get_viewport())
		UI.text(self, Vector2(s.position.x, s.end.y - 6.0), _who, 13, Color(UI.MUTED, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700, 4)


func _arch(x: float, w: float, top: float, bottom: float, col: Color) -> void:
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
	draw_colored_polygon(pts, col)
