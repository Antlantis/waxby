extends Control
## After the bell: what the level gave, counted up one by one. On the left
## the embers, the sigils, the time and the XP bar filling (with a fanfare
## at each level gained); on the right the loot (items and relics in their
## rarity colours) and any sigil-milestone reward; along the bottom Mother
## Taper's line about the level (story.gd AFTER), then on to the next.
## main.gd sets result, index and rewards (record_result()'s "rewards").
##
## v3: a silver bell rung says "Secret found!" and names the secret level it
## opened (a silver pill); W6's Vigil candles count ("Candles relit 7 / 9");
## a secret level cleared gives its Lost Wick's words above the loot; past
## level 40 the XP fills toward the next Candlemark ("Level 40 ✦3"); a level
## holding a secret way out not found yet wears a silver spark by its name.
## Mother Yarrow's Second Draught shows as a pill.
## The "skill points to spend" line under the XP is a button: it opens the
## Altar Rites' choice card (rites.gd, choice_card.gd) over the screen, a
## skill learned with each pick until Later or the points run out.
## The buttons: Onward · Shop · Replay · Map. Shop opens Waxley's shop
## (chandler_screen.gd) over the results, its back button "Back" to them
## (the results wait meanwhile); it wears the map's mark (Game.shop_badge).

signal next
signal replay
signal to_map

const UI := preload("res://scripts/ui.gd")
const Relics := preload("res://scripts/relics.gd")
const Items := preload("res://scripts/items.gd")
const Progression := preload("res://scripts/progression.gd")
const Combat := preload("res://scripts/combat.gd")
const Rites := preload("res://scripts/rites.gd")
const ChoiceCard := preload("res://scripts/choice_card.gd")
const Chandler := preload("res://scripts/chandler_screen.gd")

const XP_START := 1.3             # when the XP bar starts filling
const XP_TIME := 1.6
const PILL_PAD := 10.0            # a reward pill's row stops this far inside its right edge

var result := {}
var index := 0
var rewards: Array = []           # from Game.record_result(result)["rewards"]
var first_clear := false          # record_result()["first_clear"]: the first bell rung here
var after := {}                   # Story.after_line(level, calling), set by main.gd ({} = look it up)
var pills: Array = []             # the reward pills last drawn: {panel, sub (its label's box), text}
var _t := 0.0
var _shown_embers := 0.0
var _tick := 0
var _btns: Array[Button] = []
var _xp_from := 0
var _xp_to := 0
var _xp_level_seen := 0
var _level_flash := 0.0
var _after := {}                  # {who, text, tex, col, name (the speaker's plate: the hero's own name for his)}
var _item_icons := {}
var _lost := {}                   # the Lost Wick's words: {name, text, tex, col} ({} off a secret level)
var _marks_from := 0              # Candlemarks before the level (v3)
var _mark_flash := 0.0
var _marks_seen := 0
var lost_rect := Rect2()          # where the Lost Wick's card drew (tests)
var spend_rect := Rect2()         # the "skill points to spend" pill when last drawn ({} while it isn't)
var choice: Control = null        # choice_card.gd: the Rites over the screen (made the first time)
var shop: Control = null          # chandler_screen.gd over the results while it's open
var shop_btn: Button
var _shop_badge := {}             # its mark (Game.shop_badge), asked as the screen opens and as the shop closes
var _spend: Button                # an invisible button over the pill
const LOST_WICKS := {1: "The Lamplighter", 2: "The Old Chandler", 3: "The Gardener's Boy", 4: "Brother Rook",
		5: "Sister Solder", 6: "The Iron Abbess"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.warm()
	var last := index >= Game.LEVELS.size() - 1
	var b1 := UI.make_button("Onward" if not last else "To the map", true, func(): next.emit(), "select", 18)
	shop_btn = UI.make_button("Shop", false, func(): open_shop(), "click", 18)
	shop_btn.name = "Shop"
	shop_btn.draw.connect(func(): Chandler.draw_badge(shop_btn, _shop_badge, _t))
	var b2 := UI.make_button("Replay", false, func(): replay.emit(), "click", 18)
	var b3 := UI.make_button("Map", false, func(): to_map.emit(), "click", 18)
	for b in [b1, shop_btn, b2, b3]:
		b.custom_minimum_size = Vector2(140, 44)
		b.modulate.a = 0.0
		add_child(b)
		_btns.append(b)
	_shop_badge = Game.shop_badge() if Game.hero_made() else {}
	_spend = Button.new()
	_spend.flat = true
	_spend.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		_spend.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_spend.visible = false
	_spend.pressed.connect(func(): open_rites())
	add_child(_spend)
	# The XP: from where the hero stood before the level to now.
	_xp_to = int(Game.hero().get("xp", 0))
	_xp_from = maxi(_xp_to - int(result.get("xp", 0)), 0)
	_xp_level_seen = Progression.level_of(_xp_from)
	_marks_from = Progression.marks_of(_xp_from)
	_marks_seen = _marks_from
	for it in result.get("items", []):
		if it is Dictionary:
			_item_icons[str(it.get("uid", ""))] = UI.item_icon(it)
	_after = _after_line()
	_lost = _lost_wick()


func _lost_wick() -> Dictionary:
	## The Lost Wick of a secret level cleared (result.lost_wick, its world):
	## their name and their words (story.gd's lost_wick_<w> bark, read
	## without spending its once-only gate), the echo's face.
	var w := int(result.get("lost_wick", 0))
	if w <= 0 or not result.get("cleared", false):
		return {}
	var name := str(LOST_WICKS.get(w, "A Lost Wick"))
	var text := ""
	var who := ""
	if ResourceLoader.exists("res://scripts/story.gd"):
		var st = load("res://scripts/story.gd")
		if st.has_method("bark_line"):
			var line = st.bark_line("lost_wick_%d" % w, str(Game.hero()["cls"]))
			if line is Dictionary:
				text = str(line.get("text", ""))
				who = str(line.get("who", ""))
		if who != "" and st.has_method("speaker"):
			var sp = st.speaker(who, str(Game.hero()["cls"]))
			if sp is Dictionary and str(sp.get("name", "")) != "":
				name = str(sp["name"])
	var p := UI.portrait_path(who, "normal", str(Game.hero()["cls"])) if who != "" else ""
	if p == "" and ResourceLoader.exists("res://art/story/portraits/echo_glow.svg"):
		p = "res://art/story/portraits/echo_glow.svg"
	return {"name": name, "text": text, "tex": UI.tex(UI.hud_face(p)) if p != "" else null, "col": Color("f0d890")}


func _after_line() -> Dictionary:
	## Mother Taper's line for this level: what main.gd handed over (after),
	## else story.gd's after_line / AFTER.
	if not result.get("cleared", false):
		return {}
	var e = after if not after.is_empty() else _story_after(str(result.get("level", "")))
	var who := "taper"
	var mood := "warm"
	var text := ""
	if e is Array and e.size() >= 2:
		var wm: PackedStringArray = str(e[0]).split(":")
		who = wm[0]
		mood = wm[1] if wm.size() > 1 else mood
		text = str(e[1])
	elif e is Dictionary:
		who = str(e.get("who", who))
		mood = str(e.get("mood", mood))
		text = str(e.get("text", ""))
	elif e is String:
		text = e
	if text == "" or text.begins_with("@"):
		return {}
	# story.gd's own face for the line when it gives one (after_line's portrait)
	var p := str(e.get("portrait", "")) if e is Dictionary else ""
	if p == "" or not ResourceLoader.exists(p):
		p = UI.portrait_path(who, mood, str(Game.hero()["cls"]))
	return {"who": who, "text": text, "tex": UI.tex(UI.hud_face(p)) if p != "" else null, "col": UI.speaker_color(who),
			"name": str(e.get("name", "")) if e is Dictionary else ""}


func _story_after(id: String):
	if not ResourceLoader.exists("res://scripts/story.gd"):
		return null
	var st = load("res://scripts/story.gd")
	if st.has_method("after_line"):
		return st.after_line(id, str(Game.hero()["cls"]))
	return st.get_script_constant_map().get("AFTER", {}).get(id)


func xp_shown() -> int:
	## The XP total the bar shows now (it eases from before to after).
	var k := clampf((_t - XP_START) / XP_TIME, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 2.0)
	return int(lerpf(_xp_from, _xp_to, k))


func _process(dt: float) -> void:
	if shop_open():
		return   # the count waits under the shop
	_t += dt
	var target: int = result.get("embers", 0)
	if _t > 0.6 and _shown_embers < target:
		_shown_embers = minf(_shown_embers + dt * maxf(target * 1.2, 12.0), target)
		if int(_shown_embers) > _tick:
			_tick = int(_shown_embers)
			if _tick % 2 == 0:
				_sfx("ember", _note(mini(_tick / 4, 9)))
	# A level gained as the bar fills: a flash and the fanfare (and past
	# level 40, a Candlemark).
	var lv := Progression.level_of(xp_shown())
	if lv > _xp_level_seen:
		_xp_level_seen = lv
		_level_flash = 1.0
		_sfx("level_up")
	var mk := Progression.marks_of(xp_shown())
	if mk > _marks_seen:
		_marks_seen = mk
		_mark_flash = 1.0
		_sfx("candlemark")
	_level_flash = maxf(_level_flash - dt * 0.7, 0.0)
	_mark_flash = maxf(_mark_flash - dt * 0.7, 0.0)
	var vs := get_size()
	var s := UI.safe_rect(get_viewport())
	var total_w := 0.0
	for b in _btns:
		b.reset_size()
		total_w += b.size.x + 12.0
	var x := vs.x * 0.5 - (total_w - 12.0) * 0.5
	for i in _btns.size():
		var b := _btns[i]
		b.position = Vector2(x, s.end.y - b.size.y - 2.0)
		x += b.size.x + 12.0
		b.modulate.a = clampf((_t - XP_START - XP_TIME * 0.5 - i * 0.1) * 4.0, 0.0, 1.0)
	# The points pill's button: a thumb tall over it while it shows.
	_spend.visible = spend_rect.has_area() and (choice == null or not choice.is_open())
	if _spend.visible:
		_spend.position = Vector2(spend_rect.position.x, spend_rect.get_center().y - UI.TAP_H * 0.5)
		_spend.size = Vector2(spend_rect.size.x, UI.TAP_H)
	if str(_shop_badge.get("kind", "")) == "new":
		shop_btn.queue_redraw()   # its dot breathes
	queue_redraw()


func open_shop() -> Control:
	## Waxley's shop over the results (opening on Sell with the satchel near
	## full, like the map's); its Back comes back here.
	if shop_open():
		return shop
	shop = Chandler.new()
	shop.back_text = "Back"
	shop.back.connect(close_shop)
	add_child(shop)
	return shop


func close_shop() -> void:
	if shop_open():
		shop.queue_free()
	shop = null
	_shop_badge = Game.shop_badge() if Game.hero_made() else {}
	shop_btn.queue_redraw()


func shop_open() -> bool:
	return shop != null and is_instance_valid(shop) and not shop.is_queued_for_deletion()


func open_rites() -> bool:
	## The Rites' cards over the screen: up to three skills Waxby can learn
	## now, or Later. Each pick learns one; while points and skills are left
	## the cards come again with the next three.
	var cards := Rites.offers(Game.hero())
	if cards.is_empty():
		return false
	if choice == null:
		choice = ChoiceCard.new()
		add_child(choice)
	choice.open(cards, {"heading": Rites.heading(Game.hero()), "later": "Later", "pick": func(i): _rite_picked(cards, i)})
	return true


func _rite_picked(cards: Array, i: int) -> void:
	choice.close()
	if i < 0 or i >= cards.size():
		return
	if Game.buy_skill(str(cards[i].get("id", ""))):
		_sfx("glimmer")
		if int(Game.hero().get("points", 0)) > 0:
			open_rites()


func _sfx(name: String, pitch := 1.0) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s:
		s.play(name, pitch)


func _note(i: int) -> float:
	var s := get_node_or_null("/root/Sfx")
	return s.note(i) if s else 1.0


func _draw() -> void:
	var vs := get_size()
	var s := UI.safe_rect(get_viewport())
	draw_rect(Rect2(Vector2.ZERO, vs), UI.BG)
	for i in 3:
		draw_circle(Vector2(vs.x * 0.5, vs.y * 0.42), 300.0 - i * 80.0, Color(1.0, 0.72, 0.32, 0.03 + 0.02 * i))
	var cleared: bool = result.get("cleared", false)
	var lid := str(result.get("level", Game.LEVELS[index]["id"] if index < Game.LEVELS.size() else ""))
	var secret := str(result.get("secret", ""))
	var head := head_text()
	var found := head == "Secret found!"
	UI.text(self, Vector2(0, s.position.y + 34.0), head, 34, UI.SILVER if head == "Secret found!" else UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 6)
	var d := str(Combat.diff(str(result.get("diff", Game.diff())))["name"])
	var sub := "%s · %s" % [lid, d]
	if secret != "" and cleared:
		# "1-3 · Dusk · The Roof of Evenbell is open", the last part in
		# silver; rung again once it's open, a quiet "by its secret way".
		var so := ("  ·  %s is open" % _secret_title(secret)) if found else "  ·  by its secret way"
		var sw0 := UI.text_width(sub, 13, "body", 700)
		var ow := UI.text_width(so, 13, "body", 800 if found else 700)
		var x1 := vs.x * 0.5 - (sw0 + ow) * 0.5
		UI.text(self, Vector2(x1, s.position.y + 56.0), sub, 13, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
		UI.text(self, Vector2(x1 + sw0, s.position.y + 56.0), so, 13, UI.SILVER if found else Color(UI.SILVER, 0.7), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800 if found else 700)
	elif cleared and first_clear:
		# "1-2 · Dusk · First clear", the last part in gold.
		var fc := "  ·  First clear"
		var sw := UI.text_width(sub, 13, "body", 700)
		var fw := UI.text_width(fc, 13, "body", 800)
		var x0 := vs.x * 0.5 - (sw + fw) * 0.5
		UI.text(self, Vector2(x0, s.position.y + 56.0), sub, 13, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
		UI.text(self, Vector2(x0 + sw, s.position.y + 56.0), fc, 13, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	else:
		UI.text(self, Vector2(0, s.position.y + 56.0), sub, 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "body", 700)
	if secret == "" and cleared and secret_here(lid):
		# A secret way out still to find here: a silver spark by the line.
		var tw := UI.text_width(sub + ("  ·  First clear" if first_clear else ""), 13, "body", 700)
		var tb := UI.batch()
		var k := 0.8 + 0.2 * sin(_t * 3.0)
		UI.sparkle(tb, Vector2(vs.x * 0.5 + tw * 0.5 + 14.0, s.position.y + 51.0), 6.0 * k, UI.SILVER)
		tb.flush(self)
	var colw := minf(s.size.x * 0.5 - 20.0, 330.0)
	var lx := s.get_center().x - colw - 14.0
	var rx := s.get_center().x + 14.0
	var candles := _candles()
	_draw_tally(lx, s.position.y + 96.0, colw, candles)
	_draw_xp(lx, s.position.y + (226.0 if candles.y > 0 else 214.0), colw)
	# The loot stops above Mother Taper's line (or the buttons); a Lost
	# Wick's words go first.
	var ly := s.position.y + 80.0
	lost_rect = Rect2()
	if not _lost.is_empty():
		ly = _draw_lost(rx, ly + 6.0, colw)
	_draw_loot(rx, ly, colw, s.end.y - (96.0 if not _after.is_empty() else 56.0))
	if not _after.is_empty():
		_draw_after(s)
	elif index >= Game.LEVELS.size() - 1 and cleared:
		var af := clampf((_t - 2.4) * 3.0, 0.0, 1.0)
		var w := int(Game.LEVELS[index]["world"]) if index < Game.LEVELS.size() else 1
		var place := str(Game.WORLD_NAMES.get(w, Game.WORLD_NAME))
		UI.text(self, Vector2(0, s.end.y - 62.0), "%s is at peace. The descent continues soon..." % place, 15, Color(UI.MUTED, af), HORIZONTAL_ALIGNMENT_CENTER, vs.x, "italic", 600)


func secret_new() -> bool:
	## This ring opened its secret level (the first time on this
	## difficulty): the World says so (result.secret_new), or record_result
	## gave the {kind: secret} reward.
	if bool(result.get("secret_new", false)):
		return true
	for r in rewards:
		if r is Dictionary and str(r.get("kind", "")) == "secret":
			return true
	return false


func head_text() -> String:
	## The big line (tests): "Secret found!", "The bell is rung" or "The flame goes on".
	var cleared: bool = result.get("cleared", false)
	if str(result.get("secret", "")) != "" and cleared and secret_new():
		return "Secret found!"
	return "The bell is rung" if cleared else "The flame goes on"


func _secret_title(id: String) -> String:
	return UI.secret_title(id)


func secret_here(lid: String) -> bool:
	## The level holds a secret way out (its secret: header) whose level is
	## in the build and whose bell hasn't rung on this difficulty.
	var info: Dictionary = Game.level_info(lid) if Game.has_method("level_info") else {}
	if info.is_empty() or bool(info.get("secret", false)):
		return false
	var id := ""
	for sl in UI.secret_levels():
		if sl is Dictionary and str(sl.get("from", "")) == lid:
			id = str(sl["id"])
			if not FileAccess.file_exists(str(sl.get("path", ""))):
				return false
	if id == "":
		return false
	return not (Game.has_method("secret_open") and Game.secret_open(id, str(result.get("diff", Game.diff()))))


func _candles() -> Vector2i:
	## W6's Vigil candles: (lit, total), total 0 where there are none.
	var c = result.get("candles", {})
	if c is Dictionary and int(c.get("total", 0)) > 0:
		return Vector2i(int(c.get("lit", 0)), int(c["total"]))
	return Vector2i.ZERO


func _draw_lost(x: float, y: float, w: float) -> float:
	## The Lost Wick of a secret level: their face, name and words. Returns
	## where the loot goes under it.
	var a := clampf((_t - 0.9) * 3.0, 0.0, 1.0)
	var col: Color = _lost["col"]
	var text := str(_lost.get("text", ""))
	var lines := UI.wrap(text, w - 62.0, 13, "italic", 600) if text != "" else []
	var h := 40.0 + mini(lines.size(), 2) * 16.0
	var r := Rect2(x - 6.0, y, w + 6.0, h)
	lost_rect = r
	UI.panel(self, r, Color(col, 0.6 * a), Color("221a2a", 0.92 * a), 10.0)
	var fc := Vector2(r.position.x + 26.0, r.position.y + h * 0.5)
	var tb := UI.batch()
	tb.circle(fc, 21.0, Color(col, 0.12 * a), 20)
	tb.flush(self)
	UI.portrait(self, fc, 16.0, _lost.get("tex"), col, a, Rect2(0, 0, 1, 1), str(_lost["name"]).substr(4, 1) if str(_lost["name"]).begins_with("The ") else str(_lost["name"]).substr(0, 1))
	var tx := r.position.x + 52.0
	UI.text(self, Vector2(tx, r.position.y + 17.0), ("Lost Wick · %s" % _lost["name"]).to_upper(), 10, Color(col, a), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 8.0, "body", 800)
	for i in mini(lines.size(), 2):
		var l := str(lines[i])
		if i == 1 and lines.size() > 2:
			l += "…"
		UI.text(self, Vector2(tx, r.position.y + 34.0 + i * 16.0), l, 13, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 8.0, "italic", 600)
	if lines.is_empty():
		UI.text(self, Vector2(tx, r.position.y + 33.0), "Their candle is lit again.", 13, Color(UI.CREAM, 0.85 * a), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 8.0, "italic", 600)
	return r.end.y + 6.0


func _row_label(x: float, y: float, label: String, a: float) -> void:
	UI.text(self, Vector2(x, y), label, 18, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)


func _draw_tally(x: float, y: float, w: float, candles := Vector2i.ZERO) -> void:
	# Embers.
	var a1 := clampf((_t - 0.3) * 4.0, 0.0, 1.0)
	UI.ember_icon(self, Vector2(x + 12.0, y - 6.0), 12.0 * a1 + 0.01)
	_row_label(x + 32.0, y, "Embers", a1)
	UI.text(self, Vector2(x, y), "%d" % int(_shown_embers), 20, Color(UI.GOLD, a1), HORIZONTAL_ALIGNMENT_RIGHT, w, "body", 700)
	# The level's own embers found (placed ones and reliquaries, in pieces,
	# not worth); kill drops and chains only swell the purse above.
	var own := int(result.get("embers_total", 0))
	if own > 0 and result.has("embers_placed"):
		var lw := UI.text_width("Embers", 18, "body", 700)
		UI.text(self, Vector2(x + 32.0 + lw + 10.0, y - 1.0), "%d / %d found" % [int(result["embers_placed"]), own], 13, Color(UI.MUTED, a1), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	var step := 33.0 if candles.y > 0 else 38.0
	# Sigils.
	y += step
	var a2 := clampf((_t - 0.7) * 4.0, 0.0, 1.0)
	var st := UI.tex("res://art/props/sigil.svg")
	if st:
		draw_texture_rect(st, Rect2(x + 1.0, y - 17.0, 22, 22), false, Color(1, 1, 1, a2))
	_row_label(x + 32.0, y, "Sigils", a2)
	var sig: Array = result.get("sigils", [false, false, false])
	var full := UI.tex("res://art/props/sigil.svg")
	var empty := UI.tex("res://art/ui/sigil_empty.svg")
	for k in 3:
		var got: bool = k < sig.size() and sig[k]
		var pop := clampf((_t - 0.8 - k * 0.15) * 5.0, 0.0, 1.0)
		var sz := 26.0 * (1.0 + (1.0 - pop) * 0.5 if got else 1.0)
		var tex: Texture2D = full if got else empty
		var r := Rect2(x + w - (3 - k) * 32.0 + (26.0 - sz) * 0.5, y - 20.0 + (26.0 - sz) * 0.5, sz, sz)
		if tex:
			draw_texture_rect(tex, r, false, Color(1, 1, 1, a2))
	# Time.
	y += step
	var a3 := clampf((_t - 1.0) * 4.0, 0.0, 1.0)
	UI.glyph(self, "candle", Vector2(x + 12.0, y - 5.0), 22.0, Color(UI.CREAM, a3))
	_row_label(x + 32.0, y, "Time", a3)
	UI.text(self, Vector2(x, y), UI.format_time(float(result.get("time", 0.0))), 20, Color(UI.GOLD, a3), HORIZONTAL_ALIGNMENT_RIGHT, w, "body", 700)
	# W6: the Vigil candles relit.
	if candles.y > 0:
		y += step
		var a4 := clampf((_t - 1.15) * 4.0, 0.0, 1.0)
		# A Vigil candle, lit.
		draw_rect(Rect2(x + 7.0, y - 13.0, 10.0, 15.0), Color(UI.CREAM, a4))
		draw_rect(Rect2(x + 7.0, y - 13.0, 3.0, 15.0), Color(1, 1, 1, 0.3 * a4))
		draw_rect(Rect2(x + 4.0, y + 1.0, 16.0, 3.0), Color("b08a3a", a4))
		UI.flame(self, Vector2(x + 12.0, y - 13.0), 12.0, _t, 1.0, false, a4, true)
		_row_label(x + 32.0, y, "Candles relit", a4)
		UI.text(self, Vector2(x, y), "%d / %d" % [candles.x, candles.y], 20, Color(UI.GOLD if candles.x >= candles.y else UI.CREAM, a4), HORIZONTAL_ALIGNMENT_RIGHT, w, "body", 700)


func _draw_xp(x: float, y: float, w: float) -> void:
	## "XP +123" and the bar filling, a flash at each level gained.
	var a := clampf((_t - XP_START + 0.3) * 4.0, 0.0, 1.0)
	var shown := xp_shown()
	var lv := Progression.level_of(shown)
	var base := Progression.total_to(lv)
	var need := Progression.xp_to_next(lv)
	var frac := 1.0 if need <= 0 else clampf(float(shown - base) / need, 0.0, 1.0)
	var marks := Progression.marks_of(shown)
	if lv >= Progression.CAP and marks < Progression.MARK_CAP:
		# Past the cap: the way to the next Candlemark.
		frac = Progression.mark_frac(shown)
	var pop := 1.0 + 0.25 * _level_flash * _level_flash
	var label := "Level %d" % lv
	draw_set_transform(Vector2(x, y - 6.0), 0.0, Vector2(pop, pop))
	UI.text(self, Vector2(0, 6.0), label, 20, Color(UI.CREAM.lerp(UI.GOLD, _level_flash), a), HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
	draw_set_transform(Vector2.ZERO)
	var lw := UI.text_width(label, 20, "title", 700) * pop
	if marks > 0:
		lw += UI.mark_badge(self, Vector2(x + lw + 8.0, y), marks, 14, a) + 8.0
	if _level_flash > 0.0:
		UI.text(self, Vector2(x + lw + 10.0, y - 1.0), "LEVEL UP", 13, Color(UI.GOLD, minf(_level_flash * 2.0, 1.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 4)
	elif _mark_flash > 0.0:
		UI.text(self, Vector2(x + lw + 10.0, y - 1.0), "CANDLEMARK", 13, Color(UI.GOLD, minf(_mark_flash * 2.0, 1.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 4)
	UI.text(self, Vector2(x, y), "XP +%d" % int(result.get("xp", 0)), 16, Color(UI.GOLD, a), HORIZONTAL_ALIGNMENT_RIGHT, w, "body", 800)
	var bar := Rect2(x, y + 10.0, w, 10.0)
	draw_rect(bar.grow(1.5), Color(UI.INK, a))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(UI.GOLD.lerp(Color.WHITE, _level_flash * 0.7), a))
	draw_rect(Rect2(bar.position + Vector2(0, 1), Vector2(bar.size.x * frac, 3.0)), Color(1, 1, 1, 0.35 * a))
	if _level_flash > 0.0:
		draw_rect(bar.grow(3.0 + 4.0 * (1.0 - _level_flash)), Color(1.0, 0.85, 0.4, 0.5 * _level_flash), false, 1.5)
	spend_rect = Rect2()
	if int(result.get("levels", 0)) > 0 and _t > XP_START + XP_TIME:
		var pts := int(Game.hero().get("points", 0))
		if pts > 0 and not Rites.picks(Game.hero()).is_empty():
			# A gold pill: "+ 2 skill points to spend  CHOOSE", a button
			# (_spend) that opens the Rites' cards.
			var ap := clampf((_t - XP_START - XP_TIME) * 3.0, 0.0, 1.0)
			var say := "%d skill point%s to spend" % [pts, "" if pts == 1 else "s"]
			var sw := UI.text_width(say, 13, "body", 700)
			var gw := UI.text_width("CHOOSE", 10, "body", 800)
			var r := Rect2(x, y + 28.0, minf(w, 22.0 + sw + 12.0 + gw + 12.0), 22.0)
			UI.panel(self, r, Color(UI.GOLD, 0.85 * ap), Color(UI.PANEL, 0.9 * ap), 11.0)
			UI.glyph(self, "plus", Vector2(r.position.x + 12.0, r.get_center().y), 12.0, Color(UI.GOLD, ap))
			UI.text(self, Vector2(r.position.x + 22.0, r.position.y + 16.0), say, 13, Color(UI.GOLD, ap), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 22.0, "body", 700)
			UI.text(self, Vector2(r.end.x - gw - 12.0, r.position.y + 15.0), "CHOOSE", 10, Color(UI.CREAM, ap), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
			spend_rect = r


func _draw_loot(x: float, y: float, w: float, bottom: float) -> void:
	## What was found: relics first, then items, then any milestone reward.
	pills = []
	var rows: Array = []
	for id in result.get("relics", []):
		var r: Dictionary = Relics.get_relic(id)
		rows.append({"tex": UI.relic_icon(id), "name": r["name"], "col": UI.rarity_color(r["rarity"]), "sub": Relics.RARITY_NAME[r["rarity"]] + " relic"})
	for it in result.get("items", []):
		if it is Dictionary:
			rows.append({"tex": _item_icons.get(str(it.get("uid", ""))), "glyph": UI.slot_glyph(str(it.get("slot", ""))), "name": str(it.get("name", "")),
					"col": UI.rarity_color(str(it.get("rarity", "common"))), "sub": "%s %s" % [Items.RARITY_NAME.get(str(it.get("rarity", "")), ""), UI.SLOT_NAME.get(str(it.get("slot", "")), "")]})
	var rew: Array = []
	for r in rewards:
		match str(r.get("kind", "")):
			"relic":
				var rr: Dictionary = Relics.get_relic(str(r["id"]))
				rew.append({"tex": UI.relic_icon(str(r["id"])), "name": rr["name"], "col": UI.rarity_color(rr["rarity"]), "sub": "Sigil milestone"})
			"embers":
				rew.append({"glyph": "sun", "name": "+%d embers" % int(r.get("n", 0)), "col": UI.EMBER, "sub": "Sigil milestone"})
			"item":
				var it: Dictionary = r["item"]
				rew.append({"tex": UI.item_icon(it), "glyph": UI.slot_glyph(str(it.get("slot", ""))), "name": str(it.get("name", "")), "col": UI.rarity_color(str(it.get("rarity", ""))), "sub": "Sigil milestone"})
			"difficulty":
				rew.append({"glyph": "bell", "name": "%s is open" % str(Combat.diff(str(r.get("id", "")))["name"]), "col": UI.GOLD, "sub": "A deeper dark"})
			"secret":
				rew.append({"glyph": "secret", "name": _secret_title(str(r.get("id", ""))), "col": UI.SILVER, "sub": "Secret level open"})
			"draught":
				rew.append({"glyph": "drop", "name": "The Second Draught", "col": UI.EMBER, "sub": "+1 flask charge"})
	var a := clampf((_t - 1.2) * 4.0, 0.0, 1.0)
	UI.text(self, Vector2(x, y + 12.0), "FOUND", 11, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	if rows.is_empty() and rew.is_empty():
		UI.text(self, Vector2(x, y + 40.0), "Nothing this time.", 14, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, w, "italic", 600)
		return
	var room := maxi(int((bottom - y - 24.0 - rew.size() * 36.0) / 30.0), 1)
	var yy := y + 24.0
	for i in rows.size():
		if rows.size() > room and i >= room - 1:
			UI.text(self, Vector2(x + 34.0, yy + 18.0), "and %d more" % (rows.size() - i), 12, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, w - 34.0)
			yy += 30.0
			break
		var ai := clampf((_t - 1.2 - i * 0.08) * 5.0, 0.0, 1.0)
		_loot_row(x, yy, w, rows[i], ai)
		yy += 30.0
	for r in rew:
		yy += 6.0
		var ar := clampf((_t - 1.8) * 3.0, 0.0, 1.0)
		# The row sits inside its pill, the sub-label clear of the right edge.
		var pill := Rect2(x - 6.0, yy - 2.0, w + 6.0, 32.0)
		UI.panel(self, pill, Color(r["col"], 0.7 * ar), Color("2a1f18", 0.9 * ar), 8.0)
		var sub_r := _loot_row(x, yy, w - PILL_PAD, r, ar)
		pills.append({"panel": pill, "sub": sub_r, "text": str(r.get("sub", ""))})
		yy += 30.0


func _loot_row(x: float, y: float, w: float, r: Dictionary, a: float) -> Rect2:
	## One found thing: its icon, name and (right-aligned) what it is.
	## Returns where that sub-label went.
	var c := Vector2(x + 13.0, y + 14.0)
	draw_circle(c, 13.0, Color(r["col"], 0.14 * a))
	var t: Texture2D = r.get("tex")
	if t:
		draw_texture_rect(t, Rect2(c - Vector2(12, 12), Vector2(24, 24)), false, Color(1, 1, 1, a))
	elif str(r.get("glyph", "")) == "secret":
		var tb := UI.batch()
		UI.sparkle(tb, c, 10.0, Color(r["col"], a))
		tb.flush(self)
	else:
		UI.glyph(self, str(r.get("glyph", "")), c, 18.0, Color(r["col"], a))
	var name := str(r["name"])
	var sub := str(r.get("sub", ""))
	var sw := UI.text_width(sub, 11) + 8.0
	UI.text(self, Vector2(x + 34.0, y + 19.0), name, UI.fit_size(name, w - 34.0 - sw, 15, 11, "body", 700), Color(r["col"], a), HORIZONTAL_ALIGNMENT_LEFT, w - 34.0 - sw, "body", 700)
	UI.text(self, Vector2(x, y + 19.0), sub, 11, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_RIGHT, w, "body", 600)
	var tw := UI.text_width(sub, 11, "body", 600)
	return Rect2(x + w - tw, y + 8.0, tw, 14.0)


func _draw_after(s: Rect2) -> void:
	## Mother Taper's line: a small face and one line in italics.
	var a := clampf((_t - 2.2) * 2.5, 0.0, 1.0)
	var text := str(_after["text"])
	var tw := UI.text_width(text, 16, "italic", 600)
	var size := UI.fit_size(text, s.size.x - 80.0, 16, 12, "italic", 600)
	tw = UI.text_width(text, size, "italic", 600)
	var w := tw + 58.0
	var r := Rect2(s.get_center().x - w * 0.5, s.end.y - 88.0, w, 36.0)
	var col: Color = _after["col"]
	var nm := str(_after.get("name", ""))
	UI.portrait(self, Vector2(r.position.x + 18.0, r.get_center().y), 18.0, _after.get("tex"), col, a, Rect2(0, 0, 1, 1), (nm if nm != "" else str(_after["who"])).substr(0, 1).to_upper())
	UI.text(self, Vector2(r.position.x + 46.0, r.position.y + 24.0), text, size, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "italic", 600, 3)
