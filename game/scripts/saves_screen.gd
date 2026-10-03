extends Control
## The saves: three slots side by side, each a whole game of its own. A
## filled card shows the calling being played (its portrait in a candlelit
## niche, "Candleknight · Lv 9"), the furthest level open ("2-3 The Moth
## Garden"), bells rung, sigils and embers, the difficulties open and when it
## was last played; the slot played last is lit. An empty card is a New Game.
## Tap a filled card to play on (play(n)), an empty one to start a new game
## there (new_game(n)). A card whose file can't be read says so (Game kept a
## copy); tapping it begins anew there, as a broken save always has.
##
## Each filled card has its own "..." button (top right, apart from the
## card) that opens its menu: Start over (erase it and begin again from the
## intro: new_game(n)) or Erase (leave the slot empty). Either one then asks
## for a hold-to-confirm (HOLD_SECS, filling as it's held, draining if let
## go) under a line naming what goes, with Cancel. After an erase, an Undo
## shows in the emptied card for UNDO_SECS (while a menu is open it waits,
## hidden); the emptied card takes no tap meanwhile, and a screen left before
## the Undo ran out offers it again on the next one. Back (or Esc) says
## back(). No tap is taken for GUARD_SECS as the screen opens (a double tap
## on the title would land here too), nor for CALM_SECS after a hold goes
## off and the finger lifts.
##
## v3: a card shows the furthest world in its colour (its emblem by the
## furthest level), and a Tales button (top right, once ST's tales_screen.gd
## is in the build) says tales() (main opens the Tales).

signal play(slot: int)
signal new_game(slot: int)
signal back
signal tales

const UI := preload("res://scripts/ui.gd")
const Classes := preload("res://scripts/classes.gd")
const Combat := preload("res://scripts/combat.gd")
const HOLD_SECS := 1.2
const UNDO_SECS := 5.0
const GUARD_SECS := 0.35
const CALM_SECS := 0.35
const DAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const WHAT_GOES := ["Its callings, gear, embers, relics and story go with it.", "Settings are kept, and it can be undone for a few seconds."]
const TALES_SCREEN := "res://scripts/tales_screen.gd"
static var tales_path := TALES_SCREEN   # ST's Tales (tests may point it at a stand-in)


class HoldButton extends Button:
	## A button that fires only once held down for secs without a break:
	## it fills as it's held and drains back when let go. confirmed() once.
	const U := preload("res://scripts/ui.gd")
	signal confirmed
	var secs := 1.2
	var fill := 0.0
	var label := ""
	var col := Color("ff6a6a")
	var held := false        # a finger (or a held key, or a test) is on it
	var done := false

	func holding() -> bool:
		var m := get_draw_mode()
		return held or m == DRAW_PRESSED or m == DRAW_HOVER_PRESSED

	func reset_hold() -> void:
		fill = 0.0
		done = false
		held = false
		queue_redraw()

	func step(dt: float) -> void:
		if done or not is_visible_in_tree():
			return
		if holding():
			fill = minf(fill + dt / secs, 1.0)
			if fill >= 1.0:
				done = true
				confirmed.emit()
		else:
			fill = maxf(fill - dt * 2.5, 0.0)
		queue_redraw()

	func _process(dt: float) -> void:
		step(dt)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if fill > 0.0:
			var sb := U.box()
			sb.bg_color = Color(col.darkened(0.35), 0.85)
			sb.set_corner_radius_all(10)
			sb.draw(get_canvas_item(), Rect2(r.position + Vector2(2, 2), Vector2(maxf((r.size.x - 4.0) * fill, 4.0), r.size.y - 4.0)))
		var fs := 17
		var w := U.text_width(label, fs, "body", 800)
		U.text(self, Vector2((r.size.x - w) * 0.5, r.size.y * 0.5 + fs * 0.36), label, fs, U.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3 if fill > 0.0 else 0)


var focus := 0                    # the card the keys are on
var menu_slot := 0                # the slot whose menu is open (0: none)
var confirm := ""                 # the menu's second step: "", "start_over" or "erase"
var undo_slot := 0                # the slot an Undo is showing for (0: none)
var undo_left := 0.0
var _sums: Array = []             # Game.slot_summary(n) for slots 1..3
var _last := 1                    # the slot played last
var _faces := {}                  # cls -> {tex, uv}
var _flame_at := {}               # cls -> {uv, h} where its portrait's candle burns
var _dots: Array[Button] = []
var _back_btn: Button
var _tales_btn: Button
var _menu: Control                # the dim and the menu's panel, over the cards
var _start_btn: Button
var _erase_btn: Button
var _cancel_btn: Button
var _hold: HoldButton
var _toast: Control
var _undo_btn: Button
var _t := 0.0
var _keys := false                # the keys were used: show where they are
var _key_hold := false            # the hold is being held by a key (Space / Enter)
var _gone := false                # a card was chosen: main is swapping the screen
var _calm := 0.0                  # after a hold went off: no taps until this runs out
var _lift := 0.0                  # (which waits, up to this long, for the finger to lift)
static var _owed := 0             # the slot whose Undo was still showing when a saves screen was left


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	_back_btn = UI.make_button("Back", false, func(): _leave(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	add_child(_back_btn)
	_tales_btn = UI.make_button("Tales", false, func(): _open_tales(), "click", 15)
	UI.small_button(_tales_btn, 15)
	_tales_btn.custom_minimum_size = Vector2(76, UI.TAP_H)
	_tales_btn.name = "Tales"
	_tales_btn.visible = ResourceLoader.exists(tales_path)
	add_child(_tales_btn)
	for i in Game.slot_count():
		var n := i + 1
		var b := UI.make_button("", false, func(): open_menu(n), "click", 15)
		UI.small_button(b, 15)
		b.custom_minimum_size = Vector2(46, UI.TAP_H)
		b.name = "Menu%d" % n
		b.draw.connect(_draw_dots.bind(b))
		add_child(b)
		_dots.append(b)
	# The Undo sits in the card just erased (under the menu, if one opens).
	_toast = Control.new()
	_toast.name = "Toast"
	_toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast.draw.connect(_draw_toast)
	add_child(_toast)
	_undo_btn = UI.make_button("Undo", true, func(): undo(), "", 16)
	UI.small_button(_undo_btn, 16)
	_undo_btn.custom_minimum_size = Vector2(88, UI.TAP_H)
	_toast.add_child(_undo_btn)
	_menu = Control.new()
	_menu.name = "Menu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.visible = false
	_menu.draw.connect(_draw_menu)
	add_child(_menu)
	_start_btn = UI.make_button("Start over", false, func(): ask("start_over"), "click", 17)
	_erase_btn = UI.make_button("Erase", false, func(): ask("erase"), "click", 17)
	for b in [_start_btn, _erase_btn]:
		b.custom_minimum_size = Vector2(170, 44)
		_danger(b)
		_menu.add_child(b)
	_cancel_btn = UI.make_button("Cancel", false, func(): close_menu(), "back", 15)
	UI.small_button(_cancel_btn, 15)
	_cancel_btn.custom_minimum_size = Vector2(110, UI.TAP_H)
	_menu.add_child(_cancel_btn)
	_hold = HoldButton.new()
	UI.style_button(_hold)
	_danger(_hold)
	_hold.focus_mode = Control.FOCUS_NONE
	_hold.secs = HOLD_SECS
	_hold.col = UI.BAD
	_hold.custom_minimum_size = Vector2(300, 52)
	_hold.confirmed.connect(_confirmed)
	_menu.add_child(_hold)
	refresh()
	focus = _last - 1
	# An Undo still owed from the last saves screen, left before it ran out.
	if _owed > 0 and Game.can_restore(_owed):
		undo_slot = _owed
		undo_left = UNDO_SECS
	_owed = 0
	_layout()


func _exit_tree() -> void:
	if not _gone:
		_owed = undo_slot if undo_slot > 0 and undo_left > 0.0 else 0


func _going() -> void:
	## A card or Back was chosen: main swaps this screen out now. An Undo
	## still showing is owed to the next saves screen.
	_gone = true
	_owed = undo_slot if undo_slot > 0 and undo_left > 0.0 else 0


func refresh() -> void:
	## Reads every slot's card again (after an erase or an undo).
	_sums.clear()
	for n in range(1, Game.slot_count() + 1):
		var sm: Dictionary = Game.slot_summary(n)
		_sums.append(sm)
		var cls := str(sm.get("cls", ""))
		if cls != "" and not _faces.has(cls):
			_faces[cls] = UI.hero_face(cls, "happy")
	_last = Game.last_slot()
	queue_redraw()


func summary(n: int) -> Dictionary:
	return _sums[n - 1] if n >= 1 and n <= _sums.size() else {}


# ---------------------------------------------------------------- layout

func card_rects() -> Array:
	## One card per slot, left to right, inside the safe area.
	var s := UI.safe_rect(get_viewport())
	var n := Game.slot_count()
	var gap := 14.0
	var top := s.position.y + 72.0
	var bottom := s.end.y - 6.0
	var h := minf(bottom - top, 300.0)
	var w := minf((s.size.x - gap * (n - 1)) / n, 262.0)
	var x0 := s.get_center().x - (n * w + (n - 1) * gap) * 0.5
	var y0 := top + (bottom - top - h) * 0.5
	var out: Array = []
	for i in n:
		out.append(Rect2(x0 + i * (w + gap), y0, w, h))
	return out


func dots_rect(n: int) -> Rect2:
	## A card's "..." button: its top right corner, inside the card.
	var c: Rect2 = card_rects()[n - 1]
	return Rect2(c.end.x - 52.0, c.position.y + 6.0, 46.0, UI.TAP_H)


func menu_rect() -> Rect2:
	var s := UI.safe_rect(get_viewport())
	var w := minf(460.0, s.size.x - 24.0)
	var h := minf(270.0, s.size.y - 20.0)
	return Rect2(s.get_center().x - w * 0.5, s.get_center().y - h * 0.5, w, h)


func toast_rect() -> Rect2:
	## The Undo: in the card just emptied, where its footer would be.
	var c: Rect2 = card_rects()[clampi(undo_slot, 1, Game.slot_count()) - 1]
	return Rect2(c.position.x + 8.0, c.end.y - 60.0, c.size.x - 16.0, 52.0)


func _layout() -> void:
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)
	_back_btn.visible = menu_slot == 0
	_tales_btn.reset_size()
	_tales_btn.position = Vector2(s.end.x - _tales_btn.size.x, s.position.y + 2.0)
	_tales_btn.visible = menu_slot == 0 and ResourceLoader.exists(tales_path)
	for i in _dots.size():
		var r := dots_rect(i + 1)
		_dots[i].visible = menu_slot == 0 and not summary(i + 1).is_empty()
		_dots[i].position = r.position
		_dots[i].size = r.size
	_menu.visible = menu_slot > 0
	if menu_slot > 0:
		var P := menu_rect()
		var asking := confirm != ""
		_start_btn.visible = not asking
		_erase_btn.visible = not asking
		_hold.visible = asking
		for b in [_start_btn, _erase_btn, _cancel_btn, _hold]:
			b.reset_size()
		_start_btn.position = Vector2(P.position.x + 20.0, P.position.y + 100.0)
		_erase_btn.position = Vector2(P.position.x + 20.0, P.position.y + 156.0)
		_hold.position = Vector2(P.get_center().x - _hold.size.x * 0.5, P.position.y + (150.0 if owes_note() != "" else 138.0))
		if asking:
			_cancel_btn.position = Vector2(P.get_center().x - _cancel_btn.size.x * 0.5, P.end.y - _cancel_btn.size.y - 14.0)
		else:
			_cancel_btn.position = Vector2(P.end.x - _cancel_btn.size.x - 18.0, P.end.y - _cancel_btn.size.y - 14.0)
	_toast.visible = undo_slot > 0 and menu_slot == 0   # under a menu, it waits
	if _toast.visible:
		var T := toast_rect()
		_undo_btn.reset_size()
		_undo_btn.position = Vector2(T.end.x - _undo_btn.size.x - 6.0, T.position.y + (T.size.y - _undo_btn.size.y) * 0.5)


func _danger(b: Button) -> void:
	## A button that takes something away: the harm colour at its edge.
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.border_color = Color(UI.BAD, 0.75) if st != "pressed" else UI.CREAM
		sb.bg_color = Color("2e1a24") if st == "normal" else (Color("3a2230") if st == "hover" else Color("24141c"))
		b.add_theme_stylebox_override(st, sb)


# ---------------------------------------------------------------- what the taps do

func _open_tales() -> void:
	if _gone:
		return
	_going()
	tales.emit()


func tap_card(n: int) -> void:
	## Play a filled slot on; start a new game in an empty one.
	if _gone or n < 1 or n > _sums.size():
		return
	focus = n - 1
	_going()
	_sfx("select")
	if summary(n).is_empty():
		new_game.emit(n)
	else:
		play.emit(n)


func open_menu(n: int) -> void:
	if _gone or summary(n).is_empty():
		return
	menu_slot = n
	confirm = ""
	_hold.reset_hold()
	_layout()
	_menu.queue_redraw()


func ask(kind: String) -> void:
	## The menu's second step: what goes, and the hold that does it.
	if menu_slot == 0:
		return
	confirm = kind
	_hold.reset_hold()
	_hold.label = "Hold to start over" if kind == "start_over" else "Hold to erase"
	_layout()
	_menu.queue_redraw()


func close_menu() -> void:
	menu_slot = 0
	confirm = ""
	_hold.reset_hold()
	_layout()
	queue_redraw()


func _confirmed() -> void:
	var n := menu_slot
	var kind := confirm
	if n == 0:
		return
	_sfx("snuff")
	_calm = CALM_SECS   # the finger is still on the glass, over a card
	_lift = 2.0
	if kind == "start_over":
		close_menu()
		_going()
		new_game.emit(n)   # main: Game.new_game(n) erases it and the intro plays
		return
	if Game.erase_slot(n):
		undo_slot = n
		undo_left = UNDO_SECS
	close_menu()
	refresh()


func undo() -> void:
	if undo_slot > 0 and Game.restore_slot(undo_slot):
		_sfx("relight")
	undo_slot = 0
	refresh()
	_layout()


func _leave() -> void:
	if not _gone:
		_going()
		back.emit()


func loss_line(n: int) -> String:
	## "Erases Save 2: Candleknight Lv 9, 2-3": what a Start over or an Erase
	## takes away.
	var sm := summary(n)
	if sm.get("bad", false):
		return "Erases Save %d (it couldn't be read)" % n
	var parts: Array = []
	if int(sm.get("veteran", 0)) > 0:
		parts.append("veteran")
	if str(sm.get("cls", "")) != "":
		var who := "%s Lv %d" % [sm["name"], int(sm["level"])]
		var more := int(sm.get("callings", 1)) - 1
		if more > 0:
			who += " (+%d calling%s)" % [more, "" if more == 1 else "s"]
		parts.append(who)
		parts.append(str(sm.get("furthest", "1-1")))
	else:
		# No calling to name: what it has instead.
		parts.append("no calling yet")
		parts.append(str(sm.get("furthest", "1-1")))
		if int(sm.get("embers", 0)) > 0:
			parts.append("%d embers" % int(sm["embers"]))
	return "Erases Save %d: %s" % [n, ", ".join(parts)]


func owes_note() -> String:
	## The hold's warning when another save's Undo is waiting: this erase
	## (or start over) lets that one go for good.
	if confirm == "" or undo_slot == 0 or undo_slot == menu_slot or not Game.can_restore(undo_slot):
		return ""
	return "Save %d's erase can't be undone after this." % undo_slot


static func played_text(unix: int, now: int = -1, bias_min: int = -100000) -> String:
	## "Played today, 14:05", "Played yesterday, 9:12", "Played Tuesday" (this
	## week), "Played 12 Sep", "Played 12 Sep 2025" (another year); "" for
	## never. Local time (bias_min: minutes from UTC).
	if unix <= 0:
		return ""
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	if bias_min == -100000:
		bias_min = int(Time.get_time_zone_from_system().get("bias", 0))
	var lt := unix + bias_min * 60
	var ln := now + bias_min * 60
	var days := floori(ln / 86400.0) - floori(lt / 86400.0)
	var d := Time.get_datetime_dict_from_unix_time(lt)
	var hm := "%d:%02d" % [int(d["hour"]), int(d["minute"])]
	if days <= 0:
		return "Played today, " + hm
	if days == 1:
		return "Played yesterday, " + hm
	if days < 7:
		return "Played " + str(DAYS[int(d["weekday"])])
	var s := "Played %d %s" % [int(d["day"]), str(MONTHS[int(d["month"]) - 1])]
	if int(Time.get_datetime_dict_from_unix_time(ln)["year"]) != int(d["year"]):
		s += " %d" % int(d["year"])
	return s


static func diffs_text(diffs: Array) -> String:
	## "Dusk · Nightfall": the difficulties open.
	var names: Array = []
	for dd in diffs:
		names.append(str(Combat.diff(str(dd))["name"]))
	return " · ".join(names)


# ---------------------------------------------------------------- input

func taking_taps() -> bool:
	## Not as the screen opens (a quick second tap on the title lands here),
	## nor just after a hold went off (the finger that held it still down).
	return _t > GUARD_SECS and _calm <= 0.0


func _input(event: InputEvent) -> void:
	# Meanwhile every press is kept from the screen and its buttons (a
	# release alone presses nothing, so those go by).
	if taking_taps() or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not UI.is_tap(event) or _gone:
		return
	var p: Vector2 = event.position
	if menu_slot > 0:
		if not menu_rect().has_point(p):
			close_menu()
		return
	var R0 := card_rects()
	if undo_slot > 0 and (R0[undo_slot - 1] as Rect2).has_point(p):
		return   # the card just erased: only its Undo, until that goes
	var R := card_rects()
	for i in R.size():
		if (R[i] as Rect2).has_point(p):
			tap_card(i + 1)
			return


func _unhandled_input(event: InputEvent) -> void:
	if _gone or not taking_taps():
		return
	if event.is_action_pressed("pause"):
		if confirm != "":
			confirm = ""
			_hold.reset_hold()
			_layout()
		elif menu_slot > 0:
			close_menu()
		else:
			_leave()
		get_viewport().set_input_as_handled()
		return
	if menu_slot > 0:
		if confirm != "" and (event.is_action_pressed("jump") or event.is_action_pressed("equip")):
			_key_hold = true     # held until the key comes up (see _process)
			_hold.held = true
		return
	if event.is_action_pressed("right"):
		focus = mini(focus + 1, _sums.size() - 1)
		_keys = true
	elif event.is_action_pressed("left"):
		focus = maxi(focus - 1, 0)
		_keys = true
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("equip"):
		if undo_slot != focus + 1:   # the card just erased waits for its Undo
			tap_card(focus + 1)


func _process(dt: float) -> void:
	_t += dt
	if _lift > 0.0:
		_lift = 0.0 if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else _lift - dt
	elif _calm > 0.0:
		_calm -= dt
	if _key_hold and not (Input.is_action_pressed("jump") or Input.is_action_pressed("equip")):
		_key_hold = false
		_hold.held = false
	if undo_slot > 0 and menu_slot == 0:
		undo_left -= dt
		if undo_left <= 0.0:
			undo_slot = 0
	_layout()
	queue_redraw()
	if _menu.visible:
		_menu.queue_redraw()
	if _toast.visible:
		_toast.queue_redraw()


func _sfx(name: String) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s and name != "":
		s.play(name)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var vs := get_size()
	var s := UI.safe_rect(get_viewport())
	UI.backdrop(self, vs)
	UI.text(self, Vector2(0, s.position.y + 34.0), "Saves", 30, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 6)
	var sub := "Each save is its own journey: callings, gear, embers and story. Settings are shared."
	UI.text(self, Vector2(0, s.position.y + 56.0), sub, UI.fit_size(sub, s.size.x - 190.0, 13, 10), UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var R := card_rects()
	for i in R.size():
		_card(R[i], i + 1)


func _card(c: Rect2, n: int) -> void:
	var sm := summary(n)
	var empty := sm.is_empty()
	var bad: bool = sm.get("bad", false)
	var cls := str(sm.get("cls", ""))
	var last := n == _last and not empty
	var col := UI.class_color(cls) if cls != "" else (UI.BAD if bad else UI.PANEL_EDGE)
	# The slot played last glows gold, softly.
	if last:
		var pulse := 0.5 + 0.5 * sin(_t * 2.2)
		for k in 3:
			var g := c.grow(3.0 + k * 3.0)
			var sb := UI.box()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(UI.GOLD, (0.16 - k * 0.045) * (0.75 + 0.25 * pulse))
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(int(14.0 + 3.0 + k * 3.0))
			sb.draw(get_canvas_item(), g)
	var edge := UI.GOLD if last else (Color(UI.BAD, 0.7) if bad else (Color(UI.PANEL_EDGE, 0.55) if empty else Color(col, 0.6)))
	UI.panel(self, c, edge, Color("1a1326") if empty else UI.PANEL, 14.0)
	if _keys and focus == n - 1 and menu_slot == 0:
		draw_rect(c.grow(-4.0), Color(UI.CREAM, 0.35), false, 1.5)
	# The header: which save, and whether it's the one played last.
	var hx := c.position.x + 14.0
	UI.text(self, Vector2(hx, c.position.y + 29.0), "SAVE %d" % n, 12, UI.GOLD if last else (UI.MUTED if empty else UI.CREAM), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	if last:
		var lx := hx + UI.text_width("SAVE %d" % n, 12, "body", 800) + 8.0
		var tag := "LAST PLAYED"
		var tw := UI.text_width(tag, 9, "body", 800) + 12.0
		UI.panel(self, Rect2(lx, c.position.y + 17.0, tw, 16.0), Color(UI.GOLD, 0.6), Color("3a2a1a"), 8.0)
		UI.text(self, Vector2(lx + 6.0, c.position.y + 28.5), tag, 9, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	# The niche: an arch in the card, candlelit in the calling's colour.
	var nw := minf(c.size.x - 110.0, 100.0)   # the arch's point stays above its sill (UI.arch)
	var ntop := c.position.y + 48.0
	var nbot := c.position.y + 152.0
	var nx := c.get_center().x - nw * 0.5
	UI.arch(self, nx - 6.0, nw + 12.0, ntop - 6.0, nbot + 2.0, Color("2a2138") if not empty else Color("211a2d"))
	UI.arch(self, nx, nw, ntop, nbot, Color("0b0811"))
	var fc := Vector2(c.get_center().x, c.position.y + 118.0)
	if not empty and not bad:
		var lit := col.lerp(Color(1.0, 0.72, 0.35), 0.6)
		var fl := 1.0 + 0.04 * sin(_t * 11.0 + n)
		for j in 3:
			draw_circle(fc, (nw * 0.5 - j * 10.0) * fl, Color(lit, (0.04 + 0.03 * j) * (1.5 if last else 1.0)))
	# The sill under the niche.
	draw_rect(Rect2(nx - 10.0, nbot, nw + 20.0, 6.0), Color("3a2e4a") if not empty else Color("2a2236"))
	draw_rect(Rect2(nx - 10.0, nbot, nw + 20.0, 1.5), Color(1, 1, 1, 0.12))
	if empty:
		_empty_card(c, fc, n)
	elif bad:
		_bad_card(c, fc)
	else:
		_filled_card(c, fc, sm, cls, col)


func _filled_card(c: Rect2, fc: Vector2, sm: Dictionary, cls: String, col: Color) -> void:
	var x := c.position.x
	var w := c.size.x
	if cls != "":
		var f: Dictionary = _faces.get(cls, {})
		UI.portrait(self, fc, 33.0, f.get("tex"), col, 1.0, f.get("uv", Rect2(0, 0, 1, 1)), str(sm["name"]).substr(0, 1))
		var pf := _portrait_flame(cls)
		if not pf.is_empty() and f.get("tex") != null and f.get("uv", Rect2(0, 0, 1, 1)) == Rect2(0, 0, 1, 1):
			UI.flame(self, fc + (pf["uv"] - Vector2(0.5, 0.5)) * 2.0 * 32.0, float(pf["h"]) * 32.0 / 46.0, _t, float(sm["slot"]), false, 1.0)
	else:
		_candle(fc, true)    # sworn to nothing yet: a candle waits in the niche
	var who := "%s · Lv %d" % [sm["name"], int(sm["level"])] if cls != "" else "No calling yet"
	UI.text(self, Vector2(x + 8.0, c.position.y + 180.0), who, UI.fit_size(who, w - 16.0, 19, 13, "title", 700), UI.GOLD if cls != "" else UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, w - 16.0, "title", 700, 4)
	var far := "%s %s" % [sm.get("furthest", ""), sm.get("furthest_title", "")]
	if cls == "" and int(sm.get("veteran", 0)) <= 0 and str(sm.get("furthest", "")) in ["", "1-1"]:
		far = "The oath is still to swear"
	far = far.strip_edges()
	var wn := int(sm.get("world", 1))
	if cls != "" and str(sm.get("furthest", "")) != "" and wn >= 1:
		# The furthest world: its emblem, and the level in its colour.
		var fs0 := UI.fit_size(far, w - 36.0, 13, 10, "body", 700)
		var fw := UI.text_width(far, fs0, "body", 700)
		var fx := c.get_center().x - (fw + 20.0) * 0.5
		UI.world_emblem(self, wn, Vector2(fx + 7.0, c.position.y + 195.5), 15.0, UI.world_accent(wn))
		UI.text(self, Vector2(fx + 20.0, c.position.y + 200.0), far, fs0, UI.world_accent(wn).lerp(UI.CREAM, 0.45), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	else:
		UI.text(self, Vector2(x + 8.0, c.position.y + 200.0), far, UI.fit_size(far, w - 16.0, 13, 10, "body", 700), UI.CREAM if cls != "" else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w - 16.0, "body", 700)
	# Bells rung, sigils, embers.
	var bells := str(int(sm["bells"]))
	var sigs := str(int(sm["sigils"]))
	var ems := str(int(sm["embers"]))
	var fs := 14
	var bw := UI.text_width(bells, fs, "body", 800)
	var sw := UI.text_width(sigs, fs, "body", 800)
	var ew := UI.text_width(ems, fs, "body", 800)
	var total := 18.0 + 4.0 + bw + 16.0 + 18.0 + 4.0 + sw + 16.0 + 18.0 + 4.0 + ew
	var px := c.get_center().x - total * 0.5
	var y := c.position.y + 226.0
	UI.glyph(self, "bell", Vector2(px + 9.0, y - 5.0), 17.0, Color("c9a227"))
	px += 22.0
	UI.text(self, Vector2(px, y), bells, fs, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3)
	px += bw + 16.0
	var st := UI.tex("res://art/props/sigil.svg")
	if st:
		draw_texture_rect(st, Rect2(px, y - 14.0, 18, 18), false)
	px += 22.0
	UI.text(self, Vector2(px, y), sigs, fs, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3)
	px += sw + 16.0
	UI.ember_icon(self, Vector2(px + 9.0, y - 5.0), 8.0)
	px += 22.0
	UI.text(self, Vector2(px, y), ems, fs, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3)
	# The difficulties open, and how many callings.
	var line := diffs_text(sm.get("diffs", ["dusk"]))
	var nc := int(sm.get("callings", 0))
	if nc > 1:
		line += "  ·  %d callings" % nc
	if int(sm.get("veteran", 0)) > 0:
		line += "  ·  Veteran"
	UI.text(self, Vector2(x + 8.0, c.position.y + 246.0), line, UI.fit_size(line, w - 16.0, 11, 9, "body", 700), UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w - 16.0, "body", 700)
	_footer(c, played_text(int(sm.get("played", 0))), UI.MUTED)


func _empty_card(c: Rect2, fc: Vector2, n: int) -> void:
	_candle(fc, false)   # unlit, waiting
	var erased := undo_slot == n   # just erased: it takes no tap until its Undo goes
	UI.text(self, Vector2(c.position.x, c.position.y + 186.0), "Erased" if erased else "New Game", 24, UI.MUTED if erased else UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "title", 700, 4)
	var sub := "Undo brings it all back" if erased else "A new keeper, from the first bell"
	UI.text(self, Vector2(c.position.x + 8.0, c.position.y + 208.0), sub, UI.fit_size(sub, c.size.x - 16.0, 12, 9), UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x - 16.0)
	if undo_slot != n:   # else the Undo sits there
		_footer(c, "Tap to begin", Color(UI.CREAM, 0.7))


func _bad_card(c: Rect2, fc: Vector2) -> void:
	# Sealed with wax, like a sealed alcove: nothing here can be read.
	draw_circle(fc, 24.0, Color("4a1414"))
	draw_circle(fc, 20.0, Color("8a2020"))
	draw_arc(fc, 14.0, 0, TAU, 24, Color("5a1616"), 2.0)
	UI.glyph(self, "flame", fc + Vector2(0, 2), 16.0, Color("e0a080"))
	UI.text(self, Vector2(c.position.x, c.position.y + 184.0), "Couldn't be read", UI.fit_size("Couldn't be read", c.size.x - 16.0, 19, 13, "title", 700), UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "title", 700, 4)
	var lines := UI.wrap("This save is damaged. A copy was kept beside it.", c.size.x - 28.0, 12)
	for i in mini(lines.size(), 2):
		UI.text(self, Vector2(c.position.x, c.position.y + 206.0 + i * 16.0), lines[i], 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x)
	_footer(c, "Tap to begin anew here", Color(UI.CREAM, 0.7))


func _candle(fc: Vector2, lit: bool) -> void:
	## A wax candle on a brass dish on the niche's sill (34 below fc):
	## burning, or unlit with a thread of smoke from its wick still warm.
	var sill := fc.y + 34.0
	var wax := Color("e8dcc0") if lit else Color("8a7f9c")
	var body := Rect2(fc.x - 10.0, sill - 42.0, 20.0, 34.0)
	var dish := Rect2(fc.x - 20.0, sill - 8.0, 40.0, 6.0)
	draw_rect(dish.grow(1.5), UI.INK)
	draw_rect(dish, Color("b08a3a") if lit else Color("6e5a3a"))
	draw_rect(Rect2(dish.position, Vector2(dish.size.x, 2.0)), Color(1, 1, 1, 0.2))
	draw_rect(body.grow(1.5), UI.INK)
	draw_rect(body, wax)
	# Cel bands: a lit edge and a shaded one, and a drip down the front.
	draw_rect(Rect2(body.position, Vector2(5.0, body.size.y)), Color(1, 1, 1, 0.16 if lit else 0.08))
	draw_rect(Rect2(body.end.x - 5.0, body.position.y, 5.0, body.size.y), Color(0, 0, 0, 0.14))
	var drip := wax.lightened(0.18)
	draw_rect(Rect2(body.position.x + 11.0, body.position.y, 4.0, 12.0), drip)
	draw_circle(Vector2(body.position.x + 13.0, body.position.y + 12.0), 2.4, drip)
	draw_line(Vector2(fc.x, body.position.y), Vector2(fc.x, body.position.y - 6.0), UI.INK, 2.0)
	if lit:
		UI.flame(self, Vector2(fc.x, body.position.y - 4.0), 22.0, _t, 2.0, false, 1.0)
		return
	draw_circle(Vector2(fc.x, body.position.y - 6.0), 2.2, Color(UI.EMBER, 0.35 + 0.25 * sin(_t * 2.0)))
	for k in 4:
		var ph := fmod(_t * 0.45 + k * 0.25, 1.0)
		var at := Vector2(fc.x + sin(_t * 1.6 + k * 1.9) * 5.0 * ph, body.position.y - 9.0 - ph * 30.0)
		draw_circle(at, 1.5 + ph * 2.5, Color(UI.MUTED, 0.26 * (1.0 - ph)))


func _footer(c: Rect2, s: String, col: Color) -> void:
	if s == "":
		return
	var y := c.end.y - 30.0
	draw_line(Vector2(c.position.x + 16.0, y), Vector2(c.end.x - 16.0, y), Color(UI.PANEL_EDGE, 0.35), 1.0)
	UI.text(self, Vector2(c.position.x + 8.0, c.end.y - 11.0), s, UI.fit_size(s, c.size.x - 16.0, 11, 9, "body", 700), col, HORIZONTAL_ALIGNMENT_CENTER, c.size.x - 16.0, "body", 700)


func _draw_dots(b: Button) -> void:
	var c := b.size * 0.5
	for k in 3:
		b.draw_circle(c + Vector2((k - 1) * 8.0, 0), 2.6, Color(UI.CREAM, 0.9))


func _draw_menu() -> void:
	if menu_slot == 0:
		return
	var m := _menu
	var vs := m.get_size()
	m.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.04, 0.74))
	var sm := summary(menu_slot)
	var cls := str(sm.get("cls", ""))
	var col := UI.class_color(cls) if cls != "" else Color(UI.PANEL_EDGE, 0.9)
	var P := menu_rect()
	UI.panel(m, P, Color(col, 0.85), Color(UI.PANEL, 0.97), 14.0)
	if confirm == "":
		var fc := P.position + Vector2(46.0, 48.0)
		if cls != "":
			var f: Dictionary = _faces.get(cls, {})
			UI.portrait(m, fc, 25.0, f.get("tex"), col, 1.0, f.get("uv", Rect2(0, 0, 1, 1)), str(sm["name"]).substr(0, 1))
		else:
			m.draw_circle(fc, 28.0, UI.INK)
			m.draw_circle(fc, 25.0, Color("241b30"))
			UI.glyph(m, "candle", fc + Vector2(0, 6.0), 30.0, Color(UI.CREAM, 0.8))
		UI.text(m, Vector2(P.position.x + 84.0, P.position.y + 46.0), "Save %d" % menu_slot, 26, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 4)
		var what := "Couldn't be read"
		if not sm.get("bad", false):
			what = ("%s · Lv %d" % [sm["name"], int(sm["level"])] if cls != "" else "No calling yet") + "  ·  %s %s" % [sm.get("furthest", ""), sm.get("furthest_title", "")]
		var ww := P.size.x - 104.0
		UI.text(m, Vector2(P.position.x + 84.0, P.position.y + 68.0), what.strip_edges(), UI.fit_size(what.strip_edges(), ww, 13, 10, "body", 700), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, ww, "body", 700)
		m.draw_line(Vector2(P.position.x + 18.0, P.position.y + 86.0), Vector2(P.end.x - 18.0, P.position.y + 86.0), Color(UI.PANEL_EDGE, 0.4), 1.0)
		var nx := _start_btn.position.x + _start_btn.size.x + 16.0
		var nw := P.end.x - nx - 18.0
		_note(m, Vector2(nx, _start_btn.position.y), nw, "Erase this save and begin again from the intro.")
		_note(m, Vector2(nx, _erase_btn.position.y), nw, "Leave Save %d empty. You can undo it for a few seconds." % menu_slot)
		return
	var title := "Start Save %d over?" % menu_slot if confirm == "start_over" else "Erase Save %d?" % menu_slot
	UI.text(m, Vector2(P.position.x, P.position.y + 44.0), title, 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, P.size.x, "title", 700, 4)
	var loss := loss_line(menu_slot)
	UI.text(m, Vector2(P.position.x + 16.0, P.position.y + 76.0), loss, UI.fit_size(loss, P.size.x - 32.0, 16, 11, "body", 700), UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, P.size.x - 32.0, "body", 700)
	# Two lines, a sentence each, so neither leaves a word hanging.
	var lines: Array = WHAT_GOES.duplicate()
	if confirm == "start_over":
		lines = ["Its callings, gear, embers, relics and story go with it,", "and it begins again from the intro. Settings are kept."]
	var owed := owes_note()
	if owed != "":
		lines.append(owed)
	for i in lines.size():
		var ln := str(lines[i])
		var warn := owed != "" and i == lines.size() - 1
		UI.text(m, Vector2(P.position.x + 20.0, P.position.y + 100.0 + i * 16.0), ln, UI.fit_size(ln, P.size.x - 40.0, 12, 10, "body", 700 if warn else 600), UI.BAD if warn else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, P.size.x - 40.0, "body", 700 if warn else 600)


func _note(m: Control, at: Vector2, w: float, s: String) -> void:
	var lines := UI.wrap(s, w, 12)
	var n := mini(lines.size(), 2)
	var y0 := at.y + 22.0 - (n - 1) * 8.0 + 4.0
	for i in n:
		UI.text(m, Vector2(at.x, y0 + i * 16.0), lines[i], 12, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, w)


func _draw_toast() -> void:
	if undo_slot == 0:
		return
	var m := _toast
	var T := toast_rect()
	UI.panel(m, T, Color(UI.GOLD, 0.6), Color("241b30"), 12.0)
	var s := "Save %d erased" % undo_slot
	var bar_w := _undo_btn.position.x - T.position.x - 26.0
	UI.text(m, Vector2(T.position.x + 14.0, T.position.y + 30.0), s, UI.fit_size(s, bar_w, 15, 11, "body", 700), UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	# How long the Undo stays.
	var f := clampf(undo_left / UNDO_SECS, 0.0, 1.0)
	m.draw_rect(Rect2(T.position.x + 14.0, T.end.y - 11.0, bar_w, 2.0), Color(UI.PANEL_EDGE, 0.4))
	m.draw_rect(Rect2(T.position.x + 14.0, T.end.y - 11.0, bar_w * f, 2.0), Color(UI.GOLD, 0.8))


func _portrait_flame(cls: String) -> Dictionary:
	## Where a calling's candle burns in its portrait (rig.json, as the
	## Keeper's card reads it): {uv, h at a portrait radius of 46}, or {}.
	if not _flame_at.has(cls):
		var out := {}
		var p := "res://art/heroes/%s/rig.json" % cls
		var rd = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		if rd is Dictionary:
			var uv = rd.get("portrait_flame_uv", null)
			var vb = rd.get("portrait_viewbox", null)
			var pf = rd.get("portrait_flame", null)
			if uv is Array and uv.size() >= 2:
				out["uv"] = Vector2(float(uv[0]), float(uv[1]))
			elif pf is Array and pf.size() >= 2 and vb is Array and vb.size() >= 4 and float(vb[2]) > 0.0:
				out["uv"] = Vector2(float(pf[0]) / float(vb[2]), float(pf[1]) / float(vb[3]))
			if out.has("uv"):
				out["h"] = 15.0 * float(rd.get("flame_scale", 1.0))
				if pf is Array and pf.size() > 2 and vb is Array and vb.size() >= 4 and float(vb[2]) > 0.0:
					out["h"] = float(pf[2]) * 92.0 / float(vb[2])
		_flame_at[cls] = out
	return _flame_at[cls]
