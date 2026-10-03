extends Control
## The Tales: every story scene this save has seen, to watch again. Opened
## from the title and the saves screen (their `tales` signal; main's
## show_tales), and back() returns there. Tabs for the six worlds and
## "After" (the finale and the Challenges' hosts); a card for each tale seen
## in that tab, in story order (Story.TALES), with its title (Story.TITLES)
## and a small picture of its first panel (every layer of it, drawn small; a
## panel not drawn yet shows its stand-in; a scene with no panel its world's
## colour). Tap a card to replay it over this screen: a replay changes
## nothing (no calling chosen, no card or bark marked; the cutscene's
## `replay`), and Skip is one tap, the scene being seen. The screen opens on
## the furthest tab with a tale in it. Back (or Esc) says back().

signal back

const UI := preload("res://scripts/ui.gd")
const Story := preload("res://scripts/story.gd")
const Stage := preload("res://scripts/cutscene_stage.gd")
const CUTSCENE := "res://scripts/cutscene.gd"
const PANELS_PATH := "res://art/story/panels.json"
const BAKED := "res://art/story/thumbs/%s.png"   # tools/art/bake_tale_thumbs.gd's pictures, one a panel
const GUARD_SECS := 0.35          # taps ignored this long as the screen opens (a double tap on the title)
const TAB_H := 40.0
const CARD_GAP := 10.0
const THUMB_W := 112.0
const TITLE_MIN := 11               # a card title shrinks this far to keep to two lines
const THUMB_DENSITY := 3.0       # a picture's px per unit (the phone draws ~3)
const TAB_COLS := {1: Color("3a2c4e"), 2: Color("4a3826"), 3: Color("2c3c24"), 4: Color("223246"), 5: Color("3e3052"),
	6: Color("120e1c"), 7: Color("4a3a1e")}
# What each kind of tale is, under its title.
const KINDS := {"intro": "How it began", "oath": "The first flame", "meet_waxley": "Waxley's shop", "the_pull": "The turn",
	"homecoming": "The end", "lullaby": "After the end", "waxworks_open": "The Challenges", "trials_open": "The Challenges",
	"descent_open": "The Challenges"}

var main: Node = null             # main.gd sets it (not needed: the replay plays here)
var tab := 0                      # the tab showing (1..6, 7 for After)
var _t := 0.0
var _back_btn: Button
var _tab_btns := {}               # tab -> Button
var _cards: Array = []            # [{id, btn}]
var _playing: Node = null         # the tale being replayed
var _gone := false
static var _thumbs := {}          # panel id -> its small picture (kept for the session; ~0.4 MB each)
var _want: Array = []             # pictures still being made (thumb_job), one layer a frame


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	_back_btn = UI.make_button("Back", false, func(): _leave(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.name = "Back"
	add_child(_back_btn)
	for t in Story.TALE_TABS:
		var tt: int = t
		if not tab_built(tt):
			continue
		var b := UI.make_button(str(Story.TALE_TABS[t]), false, func(): show_tab(tt), "click", 14)
		UI.small_button(b, 14)
		b.name = "Tab%d" % tt
		add_child(b)
		_tab_btns[tt] = b
	show_tab(_first_tab())
	get_viewport().size_changed.connect(_layout)


# ---------------------------------------------------------------- what's there

func _game() -> Node:
	return get_node_or_null("/root/Game") if is_inside_tree() else Story._game()


func seen_tale(id: String) -> bool:
	## A tale this save has seen (a host's Hollin stand-in counts for it).
	var g := _game()
	if g == null:
		return false
	return g.seen(id) or (Story.REST_SUBS.has(id) and g.seen(str(Story.REST_SUBS[id])))


func tales_in(t: int) -> Array:
	## The tales seen in tab t, in story order.
	var out := []
	for e in Story.TALES:
		if int(e[0]) == t and seen_tale(str(e[1])):
			out.append(str(e[1]))
	return out


func tab_built(t: int) -> bool:
	## A world's tab where this build has its levels, or where this save saw
	## a tale (a save from a fuller build); After once it holds a tale. A
	## W1-W2 build shows World 1, World 2 and After, as the map shows its worlds.
	if not tales_in(t).is_empty():
		return true
	if t > 6:
		return false
	var g := _game()
	if g == null or g.get("LEVELS") == null:
		return true
	for l in g.LEVELS:
		if int(l.get("world", 0)) == t:
			return true
	return false


func empty() -> bool:
	for t in Story.TALE_TABS:
		if not tales_in(int(t)).is_empty():
			return false
	return true


func _first_tab() -> int:
	## The furthest world with a tale in it (where the player is now), else After.
	var best := 0
	for t in Story.TALE_TABS:
		if int(t) <= 6 and not tales_in(int(t)).is_empty():
			best = maxi(best, int(t))
	if best == 0 and not tales_in(7).is_empty():
		best = 7
	return maxi(best, 1)


# ---------------------------------------------------------------- the tabs and the cards

func show_tab(t: int) -> void:
	tab = t
	for c in _cards:
		(c["btn"] as Node).queue_free()
	_cards.clear()
	for id in tales_in(t):
		var tid: String = id
		var b := Button.new()
		UI.style_button(b)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_contents = true
		b.name = "Tale_" + tid
		b.pressed.connect(func(): _tap_card(tid))
		b.draw.connect(_draw_card.bind(b, tid))
		# Its picture, clipped to its frame.
		var pic := Control.new()
		pic.name = "Picture"
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.clip_contents = true
		pic.draw.connect(_draw_pic.bind(pic, tid))
		b.add_child(pic)
		add_child(b)
		_cards.append({"id": tid, "btn": b, "pic": pic})
		_ask_thumb(tid)
	for k in _tab_btns:
		var tb: Button = _tab_btns[k]
		tb.disabled = tales_in(int(k)).is_empty()
		UI.style_button(tb, int(k) == tab)
		UI.small_button(tb, 14)
	_layout()
	queue_redraw()


func _safe() -> Rect2:
	if not is_inside_tree():
		return Rect2(14, 10, 816, 362)
	return UI.safe_rect(get_viewport())


func _layout() -> void:
	var s := _safe()
	_back_btn.position = s.position
	_back_btn.size = Vector2(76, TAB_H)
	var n := _tab_btns.size()
	var gap := 6.0
	var tw := (s.size.x - gap * (n - 1)) / n
	var i := 0
	for k in _tab_btns:
		var b: Button = _tab_btns[k]
		b.position = Vector2(s.position.x + i * (tw + gap), s.position.y + TAB_H + 10.0)
		b.size = Vector2(tw, TAB_H)
		i += 1
	var rects := card_rects(_cards.size())
	for j in _cards.size():
		var b: Button = _cards[j]["btn"]
		b.position = rects[j].position
		b.size = rects[j].size
		var pic: Control = _cards[j]["pic"]
		pic.position = Vector2(8, 8)
		pic.size = Vector2(THUMB_W, rects[j].size.y - 16.0)


func card_rects(n: int) -> Array:
	## The cards' places: three to a row, two rows, under the tabs.
	var s := _safe()
	var top := s.position.y + TAB_H * 2.0 + 22.0
	var h := (s.end.y - top - CARD_GAP - 4.0) * 0.5
	var w := (s.size.x - CARD_GAP * 2.0) / 3.0
	var out := []
	for j in n:
		var col := j % 3
		var row := j / 3
		out.append(Rect2(s.position.x + col * (w + CARD_GAP), top + row * (h + CARD_GAP), w, h))
	return out


func tab_rects() -> Dictionary:
	var out := {}
	for k in _tab_btns:
		out[k] = (_tab_btns[k] as Button).get_rect()
	return out


func back_rect() -> Rect2:
	return _back_btn.get_rect()


func cards() -> Array:
	return _cards.map(func(c): return c["id"])


# ---------------------------------------------------------------- the thumbnails

static func manifest() -> Dictionary:
	var cs = load(CUTSCENE)
	return cs.manifest() if cs != null else {}


static func first_panel(id: String) -> String:
	## The panel a tale opens on (its first shot with a panel), or "".
	var cs = load(CUTSCENE)
	for shot in Story.scene(id).get("shots", []):
		if (shot as Dictionary).has("panel") and (cs == null or cs.shot_plays(shot)):
			return str(shot["panel"])
	return ""


func _layers_of(pid: String) -> Array:
	## [def, texture path or ""] for each of the panel's layers, far to near:
	## the art's where it's drawn, else the stand-in's.
	var m: Dictionary = manifest().get("panels", {})
	var out := []
	var defs: Array = []
	var art := false
	if m.has(pid):
		art = true
		defs = m[pid].get("layers", [])
		for l in defs:
			if not ResourceLoader.exists(str(l.get("tex", ""))):
				art = false
	if not art:
		defs = Stage.panel(pid).get("layers", [])
	var sorted := defs.duplicate()
	sorted.sort_custom(func(a, b): return float(a.get("depth", 1.0)) < float(b.get("depth", 1.0)))
	for l in sorted:
		out.append([l, str(l.get("tex", "")) if art else ""])
	return out


func _ask_thumb(id: String) -> void:
	## A tale's first panel's picture: the one baked at art build time
	## (tools/art/bake_tale_thumbs.gd), else queued to be made here, one
	## layer a frame, where the art has drawn it.
	var pid := first_panel(id)
	if pid == "" or _thumbs.has(pid) or _want.any(func(j): return j["pid"] == pid):
		return
	if ResourceLoader.exists(BAKED % pid):
		_thumbs[pid] = load(BAKED % pid)
		return
	var layers := _layers_of(pid)
	if layers.is_empty() or str(layers[0][1]) == "":
		return   # the stand-in's, drawn as it is (TriBatch)
	var frame := Vector2(THUMB_W, card_rects(1)[0].size.y - 16.0)
	_want.append(thumb_job(pid, layers, _psize(pid), frame, THUMB_DENSITY))


func _psize(pid: String) -> Vector2:
	var pd: Dictionary = manifest().get("panels", {}).get(pid, Stage.panel(pid))
	var sz: Array = pd.get("size", Stage.panel(pid).get("size", [1000, 460]))
	return Vector2(float(sz[0]), float(sz[1]))


static func thumb_job(pid: String, layers: Array, psize: Vector2, frame: Vector2, dens: float) -> Dictionary:
	## One panel's picture to make: its layers laid far to near into a small
	## image that covers `frame` (centred, where scenes look), `dens` px a unit.
	var w := maxi(8, int(ceil(frame.x * dens)))
	var h := maxi(8, int(ceil(frame.y * dens)))
	return {"pid": pid, "layers": layers, "i": 0, "any": false,
		"k": maxf(frame.y / psize.y, frame.x / psize.x) * dens, "psize": psize,
		"img": Image.create_empty(w, h, false, Image.FORMAT_RGBA8)}


static func thumb_step(job: Dictionary) -> bool:
	## Lay the job's next layer; true once the picture is done. A layer comes
	## from its imported texture (an export ships that, never the .svg) and
	## never at draw time: one layer a frame.
	var layers: Array = job["layers"]
	if int(job["i"]) < layers.size():
		var e: Array = layers[int(job["i"])]
		job["i"] = int(job["i"]) + 1
		var l: Dictionary = e[0]
		var psize: Vector2 = job["psize"]
		var k: float = job["k"]
		var out: Image = job["img"]
		var lr := Rect2(Vector2.ZERO, psize)
		if l.has("rect"):
			var rr: Array = l["rect"]
			lr = Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3]))
		var dst := Rect2((Vector2(out.get_size()) - psize * k) * 0.5 + lr.position * k, lr.size * k)
		var img := layer_image(str(e[1]), Vector2i(maxi(1, roundi(dst.size.x)), maxi(1, roundi(dst.size.y))))
		if img != null:
			out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(roundi(dst.position.x), roundi(dst.position.y)))
			job["any"] = true
	return int(job["i"]) >= layers.size()


static func layer_image(p: String, size: Vector2i) -> Image:
	## A layer's imported texture as an RGBA image of `size`, or null.
	var tex = load(p) if p != "" and ResourceLoader.exists(p) else null
	if not (tex is Texture2D):
		return null
	var img: Image = (tex as Texture2D).get_image()
	if img == null or img.is_empty():
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	# Halved with a box filter while it's twice too big (clean and quick),
	# then the rest of the way.
	while img.get_width() >= size.x * 2 and img.get_height() >= size.y * 2 and img.get_height() >= 4:
		img.shrink_x2()
	if img.get_size() != size:
		img.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	return img


static func thumb_done(job: Dictionary) -> Texture2D:
	return ImageTexture.create_from_image(job["img"]) if bool(job["any"]) else null


func thumbs_pending() -> int:
	return _want.size()


func _process(dt: float) -> void:
	_t += dt
	if not _want.is_empty():
		var job: Dictionary = _want[0]
		if thumb_step(job):
			_want.pop_front()
			_thumbs[job["pid"]] = thumb_done(job)
		for c in _cards:
			(c["pic"] as Control).queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var vs := get_size()
	UI.backdrop(self, vs)
	var s := _safe()
	UI.text(self, Vector2(s.position.x, s.position.y + 29.0), "Tales", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 5)
	if empty():
		UI.text(self, Vector2(s.position.x, s.get_center().y + 20.0), "No tales yet. Ring a few bells, and they'll be here.", 17,
				UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "body", 600, 4)


func _draw_pic(pic: Control, id: String) -> void:
	_draw_thumb(pic, id, Rect2(Vector2.ZERO, pic.size))


func _draw_card(b: Button, id: String) -> void:
	## Over the card: its picture's frame, the tale's title and its kind.
	var r := Rect2(Vector2.ZERO, b.size)
	var th := Rect2(r.position + Vector2(8, 8), Vector2(THUMB_W, r.size.y - 16.0))
	b.draw_rect(th.grow(1.0), Color(UI.PANEL_EDGE, 0.9), false, 1.5)
	var x0 := th.end.x + 12.0
	var w := r.size.x - x0 - 10.0
	var fit := title_fit(str(Story.TITLES.get(id, id)), w)
	var size := int(fit[0])
	var y := r.position.y + 30.0
	for ln in fit[1]:
		UI.text(b, Vector2(x0, y), str(ln), size, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, w, "title", 700)
		y += size + 4.0
	UI.text(b, Vector2(x0, r.end.y - 14.0), kind_of(id), 12, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, w, "body", 700)


static func title_fit(title: String, w: float) -> Array:
	## [size, lines]: a card's title at the biggest size (18 down to
	## TITLE_MIN) whose words fit w on at most two lines ("The Upside-Down
	## Tower" at the phone's 96 px); past that the second line is cut with
	## an ellipsis, never a word dropped silently.
	var size := UI.fit_size(title, w, 18, 13, "title", 700)
	var lines: Array = UI.wrap(title, w, size, "title", 700)
	while (lines.size() > 2 or _widest(lines, size) > w) and size > TITLE_MIN:
		size -= 1
		lines = UI.wrap(title, w, size, "title", 700)
	if lines.size() > 2:
		var last := " ".join(PackedStringArray(lines.slice(1)))
		while last.length() > 1 and UI.text_width(last + "…", size, "title", 700) > w:
			last = last.substr(0, last.length() - 1).strip_edges()
		lines = [lines[0], last + "…"]
	return [size, lines]


static func _widest(lines: Array, size: int) -> float:
	var m := 0.0
	for ln in lines:
		m = maxf(m, UI.text_width(str(ln), size, "title", 700))
	return m


func kind_of(id: String) -> String:
	## A tale's kind, under its title: "Into World 3", "A boss wakes", ...
	if KINDS.has(id):
		return KINDS[id]
	if id.begins_with("world_"):
		return "Into World %s" % id.get_slice("_", 1)
	if id.begins_with("boss_") and id.ends_with("_before"):
		return "A boss wakes"
	if id.begins_with("boss_") and id.ends_with("_after"):
		return "After the fight"
	return "A tale"


func _draw_thumb(b: Control, id: String, r: Rect2) -> void:
	var t := 7
	for e in Story.TALES:
		if str(e[1]) == id:
			t = int(e[0])
	var col: Color = TAB_COLS.get(t, UI.PANEL)
	b.draw_rect(r, col.darkened(0.35))
	var pid := first_panel(id)
	if pid == "":
		# No picture: its world's colour, and a small flame.
		b.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), col)
		UI.flame(b, r.get_center() + Vector2(0, 16), 22.0, _t, 1.0)
		return
	var layers := _layers_of(pid)
	if not layers.is_empty() and str(layers[0][1]) != "":
		# The art's: its picture, made off the draw loop (thumb_job), once made.
		var tex: Texture2D = _thumbs.get(pid, null)
		if tex != null:
			# Covering the frame, centred (a baked one is the phone's shape).
			var ts := Vector2(tex.get_size())
			var kk := minf(ts.x / maxf(r.size.x, 1.0), ts.y / maxf(r.size.y, 1.0))
			var src := Rect2((ts - r.size * kk) * 0.5, r.size * kk)
			b.draw_texture_rect_region(tex, r, src)
		return
	# The stand-in's: drawn as it is, covering the frame, centred (its
	# middle is where scenes look).
	var psize := _psize(pid)
	var k := maxf(r.size.y / psize.y, r.size.x / psize.x)
	var off := r.position + (r.size - psize * k) * 0.5
	for e in layers:
		b.draw_set_transform(off, 0.0, Vector2(k, k))
		Stage.draw_layer(b, e[0])
		b.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- playing a tale

func _tap_card(id: String) -> void:
	if _t < GUARD_SECS or _gone:
		return
	play(id)


func play(id: String) -> Node:
	## Replays a tale over this screen; back here when it's over.
	if _playing != null or not seen_tale(id):
		return null
	var cs = load(CUTSCENE)
	if cs == null:
		return null
	var said := id
	var g := _game()
	if g != null and not g.seen(id) and Story.REST_SUBS.has(id):
		said = str(Story.REST_SUBS[id])
	var sc: Node = cs.make(said, _replayed)
	sc.replay = true
	sc.follow_next = false
	sc.seen_before = true
	_playing = sc
	add_child(sc)
	return sc


func playing() -> Node:
	return _playing


func _replayed() -> void:
	_playing = null
	var s := get_node_or_null("/root/Sfx")
	if s != null:
		s.play_music("title")
	show_tab(tab)


# ---------------------------------------------------------------- input and leaving

func _unhandled_input(e: InputEvent) -> void:
	if _playing != null or _gone or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		_leave()
	elif e.is_action_pressed("left"):
		_step_tab(-1)
	elif e.is_action_pressed("right"):
		_step_tab(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _step_tab(d: int) -> void:
	var ks: Array = _tab_btns.keys()
	var i := ks.find(tab)
	for k in ks.size():
		i = wrapi(i + d, 0, ks.size())
		if not (_tab_btns[ks[i]] as Button).disabled:
			show_tab(int(ks[i]))
			return


func _leave() -> void:
	if _gone or _playing != null:
		return
	_gone = true
	back.emit()
