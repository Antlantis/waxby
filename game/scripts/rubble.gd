extends Node2D
## Unlit particles in the world: broken stone, falling slab bits, dust puffs.

var bits: Array = []   # {p, v, life, max, size, rot, spin, col, dust}


func burst(at: Vector2, n: int, small := false) -> void:
	for i in n:
		var a := randf_range(-PI, 0.0)
		var v := Vector2(cos(a), sin(a)) * randf_range(80.0, 220.0)
		bits.append({"p": at + Vector2(randf_range(-8, 8), randf_range(-8, 8)), "v": v, "life": 1.2, "max": 1.2,
				"size": randf_range(3.0, 6.0) * (0.6 if small else 1.0), "rot": randf() * TAU, "spin": randf_range(-10, 10),
				"col": Color("62505e") if randf() < 0.5 else Color("4a3f5e"), "dust": false})


func dust(at: Vector2, n: int) -> void:
	for i in n:
		var dir := -1.0 if i % 2 == 0 else 1.0
		bits.append({"p": at + Vector2(dir * randf_range(2, 8), -2), "v": Vector2(dir * randf_range(30, 70), randf_range(-30, -10)),
				"life": 0.4, "max": 0.4, "size": randf_range(3.0, 5.0), "rot": 0.0, "spin": 0.0, "col": Color(0.7, 0.66, 0.78, 0.5), "dust": true})


func _process(dt: float) -> void:
	for b in bits:
		b["life"] -= dt
		if b["dust"]:
			b["v"] *= exp(-dt * 5.0)
			b["size"] += dt * 8.0
		else:
			b["v"].y += 900.0 * dt
			b["rot"] += b["spin"] * dt
		b["p"] += b["v"] * dt
	bits = bits.filter(func(b): return b["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	for b in bits:
		var k: float = b["life"] / b["max"]
		if b["dust"]:
			var c: Color = b["col"]
			c.a *= k
			draw_circle(b["p"], b["size"], c)
		else:
			var s: float = b["size"]
			draw_set_transform(b["p"], b["rot"])
			draw_rect(Rect2(-s * 0.5 - 1, -s * 0.5 - 1, s + 2, s + 2), Color("17121f"))
			draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), b["col"])
			draw_set_transform(Vector2.ZERO)
