extends RefCounted
## Damage numbers: pop, rise, fade; a hit on the same target within 0.2 s
## adds into the live number. Drawn by Glow above the dark. At most 8.

const UI := preload("res://scripts/ui.gd")
const Combat := preload("res://scripts/combat.gd")
const MAX := 8
const STYLE := {
	"hit": {"size": 16, "fill": Color("f4ead6"), "line": Color("1c1830")},
	"crit": {"size": 22, "fill": Color("ffffff"), "line": Color("b8862a")},
	"hurt": {"size": 18, "fill": Color("ff6a6a"), "line": Color("2a0c10")},
	"heal": {"size": 15, "fill": Color("9ae07a"), "line": Color("10240c")},
	"blocked": {"size": 12, "fill": Color("8b90a8"), "line": Color("141420")},
	"chip": {"size": 12, "fill": Color("8b90a8"), "line": Color("141420")},
	"text": {"size": 14, "fill": Color("f2c75a"), "line": Color("1c1830")},
}

var items: Array = []   # {pos, value, text, kind, t, key, jitter}
var mode := "on"        # on / crits / off


func add(pos: Vector2, value: float, kind := "hit", key := 0, text := "") -> void:
	if mode == "off" and kind != "text":
		return
	if mode == "crits" and kind == "hit":
		return
	if key != 0 and text == "":
		for it in items:
			if it["key"] == key and it["kind"] == kind and it["t"] < 0.2:
				it["value"] += value
				it["t"] = 0.0
				return
	items.append({"pos": pos, "value": value, "text": text, "kind": kind, "t": 0.0, "key": key, "jitter": randf_range(-8.0, 8.0)})
	if items.size() > MAX:
		items.pop_front()


func step(dt: float) -> void:
	for it in items:
		it["t"] += dt
	items = items.filter(func(it): return it["t"] < 0.7)


func draw(ci: CanvasItem) -> void:
	for it in items:
		var st: Dictionary = STYLE.get(it["kind"], STYLE["hit"])
		var t: float = it["t"]
		var pop := 0.6 + 0.65 * clampf(t / 0.06, 0.0, 1.0) if t < 0.06 else lerpf(1.25, 1.0, clampf((t - 0.06) / 0.06, 0.0, 1.0))
		var rise := 28.0 * (1.0 - pow(1.0 - clampf(t / 0.7, 0.0, 1.0), 3.0))
		var a := clampf((0.7 - t) / 0.25, 0.0, 1.0)
		# Drawn at the style's own size and scaled for the pop: a font size
		# per pop step made a glyph cache per size (about 4 MB each under the
		# phone's stretch, kept for the session: +37 MB in 40 s of 3-1).
		var size := int(st["size"])
		var s: String = it["text"] if it["text"] != "" else Combat.short(it["value"])
		var star: bool = it["kind"] == "crit" and it["text"] == ""
		var f := UI.font("body", 800)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var sr := size * 0.40                  # a crit's star, after the number
		var full := w + (sr * 2.0 + 2.0 if star else 0.0)
		var k := float(int(float(size) * pop)) / float(size)   # the pop's steps as before
		var p: Vector2 = it["pos"] + Vector2(float(it["jitter"]) - full * k * 0.5, -rise)
		var o := p
		if absf(k - 1.0) > 0.001:
			ci.draw_set_transform(p, 0.0, Vector2(k, k))
			o = Vector2.ZERO
		ci.draw_string_outline(f, o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(st["line"], a))
		ci.draw_string(f, o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(st["fill"], a))
		if star:
			_star(ci, o + Vector2(w + 2.0 + sr, -size * 0.36), sr, t, a)
		if o != p:
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _star(ci: CanvasItem, c: Vector2, r: float, t: float, a: float) -> void:
	## A five-point gold star with a dark rim, turning a little as it pops.
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var spin := -0.3 + t * 1.2
	for i in 10:
		var ang := spin - PI * 0.5 + PI * i / 5.0
		var k := 1.0 if i % 2 == 0 else 0.45
		outer.append(c + Vector2(cos(ang), sin(ang)) * (r + 1.8) * k)
		inner.append(c + Vector2(cos(ang), sin(ang)) * r * k)
	ci.draw_colored_polygon(outer, Color(0.22, 0.14, 0.05, a))
	ci.draw_colored_polygon(inner, Color(1.0, 0.84, 0.29, a))
