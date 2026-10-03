extends Node2D
## A hint sign: a small wooden board on a post (its text shows in the HUD
## when Wick stands by it). Its painted flame glints until he has stood by
## it once in this visit (world.gd's _read_signs calls mark_read): a board
## not yet read reads as worth stopping for. Nothing is saved; a new visit
## builds new boards, glinting again.

const GLINT_EVERY := 1.6         # s from one glint to the next...
const GLINT_LEN := 0.45          # ...and how long one takes
const GLINT := Color("fff2c0")

var read := false                # he has stood by it this visit
var _t := 0.0
var _glint: Node2D = null        # the glint, drawn once; its modulate does the flashing (no redraw a frame)


func _ready() -> void:
	_glint = Node2D.new()
	_glint.draw.connect(_draw_glint)
	add_child(_glint)
	_glint.modulate.a = 0.0
	if read:
		_glint.visible = false
		set_process(false)


func _process(dt: float) -> void:
	_t += dt
	_glint.modulate.a = glint_at(_t)


static func glint_at(t: float) -> float:
	## The glint's strength t s in: a quick rise and fall every GLINT_EVERY s.
	var k := fmod(t, GLINT_EVERY) / GLINT_LEN
	return sin(PI * k) if k < 1.0 else 0.0


func mark_read() -> void:
	if read:
		return
	read = true
	if _glint != null:
		_glint.visible = false
	set_process(false)


func glinting() -> bool:
	return not read and _glint != null and _glint.visible


func _draw() -> void:
	var outline := Color("1a120c")
	draw_rect(Rect2(-3, -30, 6, 30), outline)
	draw_rect(Rect2(-1.5, -29, 3, 29), Color("5a3a26"))
	var board := Rect2(-17, -46, 34, 22)
	draw_rect(board.grow(2), outline)
	draw_rect(board, Color("8a6444"))
	draw_rect(Rect2(board.position, Vector2(board.size.x, 4)), Color("a88060"))
	draw_rect(Rect2(board.position + Vector2(0, 18), Vector2(board.size.x, 4)), Color("6a4a32"))
	# A little scrawled flame on it.
	var c := board.get_center()
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 2), c + Vector2(0, 6), c + Vector2(-5, 2)]), Color("f2b84b"))


func _draw_glint() -> void:
	## The painted flame lit up, and a four-point twinkle at its tip.
	var c := Vector2(0, -35)   # the board's centre (_draw's)
	_glint.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 2), c + Vector2(0, 6), c + Vector2(-5, 2)]), GLINT)
	var tip := c + Vector2(0, -7)
	_glint.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -6), tip + Vector2(1.2, -1.2), tip + Vector2(6, 0), tip + Vector2(1.2, 1.2),
			tip + Vector2(0, 6), tip + Vector2(-1.2, 1.2), tip + Vector2(-6, 0), tip + Vector2(-1.2, -1.2)]), Color(GLINT, 0.9))
