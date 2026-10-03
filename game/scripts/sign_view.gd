extends Node2D
## A hint sign: a small wooden board on a post (its text shows in the HUD
## when Wick stands by it).

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
