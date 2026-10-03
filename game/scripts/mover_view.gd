extends Node2D
## A moving ledge's look: a chained stone platform, `length` tiles long.
## v3 (A1's request): a theme's palette recolours it, World 3's a root lift
## (bark, its lit top, roots for chains) and World 4's a gear lift (brass,
## its bright top, iron chains); v2's themes keep the stone slab.

var length := 3
var look := {}                   # {face, top, shade, chain} (set_theme), {} for v2's stone


func set_theme(pal: Dictionary, world_n: int) -> void:
	## The lift in the theme's colours (World 3 and 4's painters' palettes).
	if world_n == 3 and pal.get("bark") is Color:
		look = {"face": pal["bark"], "top": pal.get("bark_lip", pal["bark"]), "shade": (pal["bark"] as Color).darkened(0.35),
				"chain": pal.get("root_hi", Color("6e4e36"))}
	elif world_n == 4 and pal.get("brass") is Color:
		look = {"face": pal.get("brass_sh", pal["brass"]), "top": pal.get("brass_hi", pal["brass"]), "shade": pal.get("brass_line", Color("3a2408")),
				"chain": pal.get("iron", Color("3a3a48")).lightened(0.25)}
	queue_redraw()


func _draw() -> void:
	var w := length * 32.0
	var outline := Color("17121f")
	var face: Color = look.get("face", Color("5a4e70"))
	var top: Color = look.get("top", Color("8a7ca6"))
	var shade: Color = look.get("shade", Color("3a3150"))
	var chain: Color = look.get("chain", Color("5a5a6a"))
	draw_rect(Rect2(-1, -1, w + 2, 14), outline)
	draw_rect(Rect2(0, 0, w, 12), face)
	draw_rect(Rect2(0, 0, w, 3.5), top)
	draw_rect(Rect2(0, 9, w, 3), shade)
	for i in length:
		draw_rect(Rect2(i * 32.0 + 15.0, 3.5, 2, 5.5), shade)
	# Chains up into the dark.
	for x in [8.0, w - 8.0]:
		var y := -6.0
		while y > -140.0:
			draw_arc(Vector2(x, y), 3.0, 0.0, TAU, 8, chain, 1.5)
			y -= 7.0
