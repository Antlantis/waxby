extends Control
## The Chandler: Waxley's shop, headed "Waxley's Shop" (TITLE), the map's
## Shop button (and the results screen's, over the results: back_text
## "Back"). Three tabs (four once World 3 is reached); it opens on Sell while
## the satchel holds SELL_FROM pieces or more (unless the Shop's mark is a ▲:
## then on Buy, where it sent him), else on Buy:
##   Buy     items at the hero's level, by shop depth (Game.wares): five or six
##           in two rows of three compact cards (Blessed 30 + 8*ilvl, Rare
##           90 + 20*ilvl; the last two "For your <slot>", picked for the two
##           weakest slots), and from depth 23 Waxley's Reserve, a Legendary,
##           in a tall card on the right (300 + 40*ilvl; it restocks when a
##           boss at the hero's depth falls). A tap on a card (or the
##           Reserve's) opens its detail sheet: every line, the chips, what it
##           would sell back for, and its price button, moved there; a tap
##           outside it or Close shuts it. A bought upgrade is worn at once;
##           anything else goes to the satchel. The stock lives in the hero's
##           save and restocks after every bell, or at once with Fresh stock
##           (Game.buy_fresh: half a Rare's price, doubling until the next
##           bell; two taps). A full satchel shows "Satchel full · Sell ›",
##           a link to Sell, and a sale refused for it goes there. Shown,
##           a stock's ▲ on the Shop button is spent (Game.wares_seen). A
##           piece that isn't a Legendary is never worn over a worn one
##           (Game.worn_legend_kept): bought, it's stowed, and its sheet
##           names the Legendary that stays on.
##   Sell    the satchel as a grid of 4 x 4 squares (empty ones hollow), each
##           piece with what Waxley pays (Items.sell_value, a quarter of his
##           price) and a corner mark (Game.sell_look): a red ▼ no better than
##           what's worn, an amber ◆ a trade-off, a gold ★ a Legendary, a green
##           ▲ an upgrade (better numbers than a worn Legendary are a ◆: its
##           power would go, and the panel says so). Pieces adding up to
##           nothing start marked (an ember tag), never a Legendary; the key
##           lists all four marks. A tap shows a piece on the right against
##           what's worn, with Wear and "Sell +N"; a tap on the piece shown
##           marks or keeps it. "Sell N marked +total" sells them all at once.
##           No question asked: a piece sold leaves a ghost in its square,
##           "Buy back N", until the shop closes (Game.buy_back, at what it
##           fetched; Game.forget_sold as it opens and closes).
##   Relics  the cheapest relics not yet found (3, or 4 from shop depth 23;
##           only the worlds reached), at Relics.PRICE.
##   Draughts  (from World 3) Mother Yarrow's Second Draught (a gift, shown
##           as had or to come), the Rich Draught (after the Tinker, 1,600
##           embers) and, from World 5, Rekindle: a Legendary re-made at the
##           hero's level (200 + 30*ilvl), up to three held ones listed. Before
##           World 5 the right side shows the flask as it is, with Rekindle's
##           padlock note under it.
## (Unmaking skills is the Sheet's free Respec, on its Skills tab.)
## Buying takes two taps: the first turns the price button gold and asks
## "Buy?" for 3 s, the second buys. A sale that can't happen (too dear, the
## satchel full) is refused on the first tap. All buying and selling goes
## through Game (ware_verdict/buy_ware, relic_verdict/buy_relic, sell_item,
## sell_marked, buy_back, buy_fresh). Emits back when closed; the map (or
## the results) frees it.
##
##     var c := preload("res://scripts/chandler_screen.gd").new()
##     c.back.connect(func(): c.queue_free())
##     add_child(c)

signal back

const UI := preload("res://scripts/ui.gd")
const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const Relics := preload("res://scripts/relics.gd")
const Classes := preload("res://scripts/classes.gd")
const Combat := preload("res://scripts/combat.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const Story := preload("res://scripts/story.gd")

const TITLE := "Waxley's Shop"   # the header: the Shop button's own word
const TABS := ["buy", "sell", "relics", "draughts"]
const TAB_NAME := {"buy": "Buy", "sell": "Sell", "relics": "Relics", "draughts": "Draughts"}
const SELL_FROM := 12       # the shop opens on Sell while the satchel holds this many
const SQUARES := 16         # the Sell tab's 4 x 4 (Game.SATCHEL_MAX; an over-full satchel adds a row)
const SQ_COLS := 4
const SQ := 60.0            # a square, at most
const SQ_GAP := 6.0
const AMBER := Color("f0a040")   # a trade-off's mark
const LINK_H := 44.0        # the buttons in the row under the header (Fresh stock, the Sell link)
const GRID_COLS := 3        # the wares: two rows of three
const RESERVE_W := 184.0    # Waxley's Reserve, the tall card right of them
const REKINDLE_ROWS := 3    # the Legendaries Rekindle lists
const ROW_H := 52.0         # one of them
const SMALL_BTN_H := 44.0   # a compact card's price button
const UP := Color("9ae07a")
const DOWN := Color("ff6a6a")
const WOOD := Color("2a1c14")
const BTN_H := 46.0
const HEADER_H := 44.0
const GAP := 10.0
const CONFIRM_TIME := 3.0   # how long a price button waits for its second tap
const DETAIL_W := 470.0     # the detail sheet, at most
const LOCK_H := 66.0        # Rekindle's padlock strip, before World 5
# Waxley's line when the Reserve restocks: story.gd's reserve_stocked bark
# (spec §6.5), these words until story.gd has it.
const RESERVE_BARK := "Don't ask where I got it. Really. Don't."
const LINES := {
	"hello": ["A customer! A live one! Browse, browse.", "Fresh stock, straight up from the Deep. Mostly.",
			"Embers only, friend. No credit, no refunds.", "Everything here's been blessed. By someone."],
	"equipped": ["Looks better on you already.", "Wear it in good health!", "That'll hold a flame. Probably."],
	"satchel": ["Into the satchel it goes.", "Yours! Mind the drips."],
	"poor": ["Embers first, friend. No credit.", "Ah. Come back a little richer."],
	"full": ["Your satchel's stuffed! Sell me something first."],
	"sold": ["That one's gone. More after the next bell."],
	"belt": ["On your belt. Wear it well."],
	"stowed": ["Your belt's full, so it's in your codex. Swap it on in the Sheet."],
	"bare": ["You've bought me out! Not a relic left."],
	"ask_equipped": ["Tap again and you'll wear it out the door.", "Sure? One more tap and it's on you."],
	"ask_equipped_melt": ["Tap again: you wear it, and I buy the old one."],
	"equipped_melt": ["Worn! And I bought the old one:"],
	"ask_satchel": ["Tap again and it's in your satchel. No refunds!", "One more tap seals it. Into the satchel."],
	"ask_belt": ["Tap again and it's on your belt.", "One more tap and it's yours. Forever!"],
	"ask_stowed": ["Tap again: your belt's full, so it goes in your codex."],
	"ask_fresh": ["Tap again and I'll fetch fresh stock. For a fee."],
	"fresh": ["Fresh from the back room! Still warm.", "New stock! Don't ask from where."],
	"nohero": ["Choose your calling first, friend."],
	"tab_relics": ["Relics! Found once, kept forever.", "Saints' odds and ends. Genuine. Mostly."],
	"tab_buy": ["Gear for your level, fresh after every bell.", "Try before you buy? No. Buy, then try."],
	"tab_sell": ["I'll take what you don't wear. Fair prices! Mostly.", "A quarter of my price, paid on the spot. Generous!"],
	"tab_draughts": ["Draughts! For the flask, and for old favourites.", "Deeper down, a Wick needs a better flask."],
	"sold_one": ["Sold! Change your mind before you go, it's yours again.", "Into the back room it goes."],
	"sold_marked": ["A fine haul! That's"],
	"no_marks": ["Nothing marked, friend. Tap a piece twice to mark it."],
	"marked": ["Marked. It goes with the rest.", "That one? Gladly."],
	"kept": ["Kept. I won't touch it.", "Fine, keep it. Sentimental, are we?"],
	"bought_back": ["Back in your satchel. Same price, no hard feelings."],
	"back_full": ["No room to put it back. Sell me something else first."],
	"worn": ["Looks better on you already. The old one's in your satchel."],
	"empty": ["An empty satchel! Bring me what you don't wear."],
	"reserve_sold": ["The Reserve's gone. Another boss, another prize."],
	"ask_buy": ["Tap again and it's in your flask. For good.", "One more tap and it's yours, every difficulty."],
	"bought": ["Drink deep, friend. It's yours now."],
	"owned": ["You've already got that one, friend."],
	"locked": ["Not yet, friend. Some things come later."],
	"ask_rekindle": ["Tap again: I'll melt it and pour it new."],
	"rekindled": ["Good as new. Better, even."],
	"lower": ["That one's as good as you are already."],
	"none": ["I can only rekindle a Legendary you carry."],
}

var tab := ""               # the tab on show ("" until it opens: default_tab())
var back_text := "Map"      # the back button's word ("Back" over the results)
var safe_override := Rect2()
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _back_btn: Button
var _tab_btns := {}
var _buy_btns: Array[Button] = []
var _acts: Array = []       # what each price button buys: {kind: ware | relic | reserve | draught | rekindle, i, id, row}
var _stock: Array = []      # the wares (items or null) or the relic offers on show
var _chips: Array = []      # Hero.compare for each ware
var _reserve := {}          # Game.reserve() on show (Wares), {} when there's none
var _reserve_chips := {}
var _draughts: Array = []   # Game.draughts() on show (Draughts)
var _kindle: Array = []     # Game.rekindle_list() rows on show (Draughts, from World 5)
var _notes := {}            # ware index -> {text, name, rarity} of a sale just made
var _line := ""             # what Waxley says
var line_fits := true      # whether it fit its row when last drawn (tests)
var _line_t := 0.0
var _flash := {}            # card index -> glow left after a sale
var _deny := 0.0
var _deny_card := -1
var _purse_flash := 0.0
var _deny_why := ""         # why the last sale was refused (the purse goes red only for "poor")
var _sale := -1             # the price button waiting for its second tap
var _sale_t := 0.0          # and how long it waits yet
var _ember_tex: Texture2D
var _boxes := {}
var _glow_tex: GradientTexture2D
var _detail := -1           # the price button whose ware (or the Reserve) the detail sheet shows, else -1
var _close_btn: Button
var _fresh_btn: Button      # Buy: Fresh stock, in the row under the header
var _fresh_armed := 0.0     # its confirm window
var _full_btn: Button       # Buy: "Satchel full · Sell ›", while it is
# The Sell tab.
var _grid: Array = []       # its squares: {uid} a piece, {ghost: item, price, n} one sold this visit, {} empty
var _marked := {}           # uid -> marked to sell (set when a piece first shows: Game.sell_look's marked)
var _looks := {}            # uid -> Game.sell_look of each piece on show
var _pick := ""             # the piece shown on the right ("" for none)
var _ghosts := 0            # sales this visit (a ghost's n: the oldest gives its square up first)
var _sq_flash := {}         # square -> glow left after a sale or a buy-back
var _wear_btn: Button
var _sell_btn: Button       # "Sell +N", the piece shown
var _sell_all_btn: Button   # "Sell N marked  +total"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_ember_tex = UI.tex("res://art/ui/ember.svg")
	Game.forget_sold()   # a fresh visit: nothing to buy back yet
	# A soft round glow, for every candle's halo.
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.72, 0.36, 0.55))
	g.set_color(1, Color(1.0, 0.5, 0.18, 0.0))
	g.add_point(0.35, Color(1.0, 0.62, 0.26, 0.22))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 128
	_glow_tex.height = 128
	for r in Relics.ALL:
		UI.relic_icon(r["id"])
	_back_btn = _button(back_text, false, func(): _close())
	for id in TABS:
		var b := _button(TAB_NAME[id], false, func(): show_tab(id))
		_tab_btns[id] = b
	_tab_btns["draughts"].visible = Game.draughts_open()
	_fresh_btn = _button("", false, func(): _fresh_pressed())
	UI.small_button(_fresh_btn, 14)
	_fresh_btn.draw.connect(_draw_fresh)
	_full_btn = _button("Satchel full · Sell  ›", false, func(): show_tab("sell"))
	UI.small_button(_full_btn, 14)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		_full_btn.add_theme_color_override(st, DOWN)
	_close_btn = _button("Close", false, func(): close_detail())
	UI.small_button(_close_btn, 15)
	_close_btn.visible = false
	_wear_btn = _button("Wear", false, func(): wear_picked())
	UI.small_button(_wear_btn, 16)
	_sell_btn = _button("Sell", true, func(): sell_picked())
	UI.small_button(_sell_btn, 16)
	_sell_all_btn = _button("Sell marked", true, func(): sell_marked())
	_sell_all_btn.add_theme_font_size_override("font_size", 18)
	if tab == "":
		tab = default_tab()
	_say(("tab_sell" if tab == "sell" else "hello") if Game.hero_made() else "nohero")
	show_tab(tab)
	resized.connect(_layout)
	# The first visit: Waxley introduces himself (story beat meet_waxley).
	if not Game.seen("meet_waxley"):
		var cs = load("res://scripts/cutscene.gd")
		if cs != null and cs.has_method("play_overlay"):
			cs.play_overlay(self, "meet_waxley", func(): Game.mark_seen("meet_waxley"))


func _safe() -> Rect2:
	## The part of the screen clear of the notch and home bar (set
	## safe_override to lay out for another phone, as the screenshots do).
	return safe_override if safe_override.has_area() else UI.safe_rect(get_viewport())


func _button(text: String, accent: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	UI.style_button(b, accent)
	var off := StyleBoxFlat.new()
	off.bg_color = Color("1a1424")
	off.border_color = Color(UI.PANEL_EDGE, 0.4)
	off.set_border_width_all(2)
	off.set_corner_radius_all(10)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_disabled_color", Color(UI.MUTED, 0.6))
	b.pressed.connect(func():
		_sfx("click")
		cb.call())
	add_child(b)
	return b


func _sfx(id: String, pitch := 1.0) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(id, pitch)


func _say(key: String, extra := "") -> void:
	var opts: Array = LINES.get(key, [""]) if key != "reserve" else [reserve_line()]
	_line = opts[_rng.randi() % opts.size()] + extra
	_line_t = 0.0


func reserve_line() -> String:
	## What Waxley says as a fresh Reserve shows: the reserve_stocked bark.
	var b: Dictionary = Story.bark_line("reserve_stocked", Game.hero_id())
	return str(b.get("text", RESERVE_BARK)) if not b.is_empty() else RESERVE_BARK


func tabs_shown() -> Array:
	## The tabs on the bar: Buy, Sell and Relics, and Draughts once World 3 is
	## reached.
	return TABS.filter(func(t): return t != "draughts" or Game.draughts_open())


static func default_tab() -> String:
	## Where the shop opens: Sell while the satchel holds SELL_FROM pieces or
	## more, unless the Shop's mark is a ▲ (a stock not yet looked at with an
	## upgrade he can afford: the mark sent him to Buy); else Buy.
	if Game.hero_made() and (Game.hero()["satchel"] as Array).size() >= SELL_FROM \
			and str(Game.shop_badge().get("kind", "")) != "up":
		return "sell"
	return "buy"


func show_tab(id: String) -> void:
	if not tabs_shown().has(id):
		return
	if id != tab:
		_sale = -1
		_notes = {}
		_flash = {}
		_deny_card = -1
		_fresh_armed = 0.0
		_say("tab_" + id if Game.hero_made() or id == "relics" else "nohero")
	tab = id
	_refresh()


func _close() -> void:
	Game.forget_sold()   # what was sold stays sold
	back.emit()


func _exit_tree() -> void:
	Game.forget_sold()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _detail >= 0:
			close_detail()
		else:
			_close()


func _gui_input(event: InputEvent) -> void:
	## A tap no button took (a finger arrives as the mouse: UI.is_tap).
	if UI.is_tap(event):
		tap_at((event as InputEventMouseButton).position)
		accept_event()


func tap_at(p: Vector2) -> void:
	## A tap on the screen itself: outside the detail sheet it shuts it; on a
	## compact card or the Reserve's it opens that one's (a sold one says so).
	## On Sell, a tap on a piece shows it (on the one shown, marks or keeps
	## it), on a ghost buys it back.
	if _detail >= 0:
		if not detail_rect().has_point(p):
			close_detail()
		return
	if tab == "sell" and Game.hero_made():
		var sq := squares()
		for k in sq.size():
			if (sq[k] as Rect2).has_point(p):
				tap_square(k)
				return
		return
	if tab != "buy" or not grid() or not Game.hero_made():
		return
	var cards := _cards()
	for k in cards.size():
		if (cards[k] as Rect2).has_point(p):
			if _stock[k] is Dictionary:
				open_detail(k)
			else:
				_say("sold")
			return
	if reserve_rect().has_point(p):
		if _reserve.get("item") is Dictionary:
			open_detail(_act_index("reserve"))
		else:
			_say("reserve_sold")


func open_detail(i: int) -> void:
	## The detail sheet for price button i's ware (or the Reserve): every line,
	## the chips, and that price button, moved into it.
	var a := _act(i)
	if not ["ware", "reserve"].has(str(a.get("kind", ""))) or not _act_shown(i):
		return
	if _sale != i:
		_sale = -1
	_detail = i
	_sfx("select")
	_update_buttons()
	_layout()
	queue_redraw()


func close_detail() -> void:
	if _detail < 0:
		return
	if _sale == _detail:
		_sale = -1   # its question goes with it
		_say("tab_" + tab)
	_detail = -1
	_update_buttons()
	_layout()
	queue_redraw()


func detail_shown() -> int:
	## The price button whose sheet is open, or -1 (tests).
	return _detail


func detail_item():
	## The item the sheet shows (null when it's shut).
	var a := _act(_detail)
	match str(a.get("kind", "")):
		"ware":
			return _stock[int(a["i"])]
		"reserve":
			return _reserve.get("item")
	return null


func detail_rect() -> Rect2:
	## The sheet: over the cards, centred (Rect2() when it's shut).
	if _detail < 0:
		return Rect2()
	var s := _safe()
	var top := _cards_top()
	var w := minf(s.size.x - 24.0, DETAIL_W)
	return Rect2(roundf(s.get_center().x - w * 0.5), top, w, s.end.y - 2.0 - top)


func detail_btn_rect() -> Rect2:
	var d := detail_rect()
	return Rect2(d.end.x - 14.0 - 190.0, d.end.y - 10.0 - BTN_H, 190.0, BTN_H)


# ---------------------------------------------------------------- stock and buttons

func _refresh() -> void:
	var tight := tabs_shown().size() > 3
	for id in _tab_btns:
		var on: bool = id == tab
		var b: Button = _tab_btns[id]
		UI.style_button(b, on)
		if tight:
			UI.small_button(b, 16)   # four tabs: tighter, to fit beside the title
	for b in _buy_btns:
		b.queue_free()
	_buy_btns.clear()
	_acts = []
	_detail = -1   # a sale, a tab, a melt: the sheet shuts (its card shows what happened)
	_stock = []
	_chips = []
	_reserve = {}
	_reserve_chips = {}
	_draughts = []
	_kindle = []
	var made := Game.hero_made()
	_tab_btns["draughts"].visible = Game.draughts_open()
	_looks = {}
	match tab:
		"sell":
			if made:
				_sync_grid()
		"buy":
			if made:
				_stock = Game.wares().duplicate()
				Game.wares_seen()   # looked at: the Shop's ▲ for it is spent
				var h: Dictionary = Game.hero()
				for it in _stock:
					_chips.append(Hero.compare(h, it["slot"], it, h.get("belt", []), Game.diff()) if it is Dictionary else {})
					if it is Dictionary:
						UI.tex(Items.icon(it))
				_reserve = Game.reserve()
				if not _reserve.is_empty() and _reserve["item"] is Dictionary:
					var rit: Dictionary = _reserve["item"]
					_reserve_chips = Hero.compare(h, rit["slot"], rit, h.get("belt", []), Game.diff())
					UI.tex(Items.icon(rit))
					if bool(_reserve.get("new", false)):
						_say("reserve")
						Game.reserve_seen()
		"relics":
			_stock = Game.relic_offers()
		"draughts":
			if made:
				_draughts = Game.draughts()
				if Game.rekindle_open():
					# Those it can re-make first (worn, then carried), then the rest.
					var rows: Array = Game.rekindle_list()
					var can := func(r): return ["", "poor"].has(str(r["verdict"]))
					_kindle = (rows.filter(can) + rows.filter(func(r): return not can.call(r))).slice(0, REKINDLE_ROWS)
					for row in _kindle:
						UI.tex(Items.icon(row["item"]))
	for i in _stock.size():
		_acts.append({"kind": "ware" if tab == "buy" else "relic", "i": i})
	if not _reserve.is_empty():
		_acts.append({"kind": "reserve"})
	for d in _draughts:
		if d["state"] == "buy":
			_acts.append({"kind": "draught", "id": d["id"]})
	for k in _kindle.size():
		_acts.append({"kind": "rekindle", "row": k})
	for i in _acts.size():
		var idx := i
		var b := _button("", true, func(): _buy(idx))
		b.draw.connect(_draw_price.bind(b, idx))
		_buy_btns.append(b)
	_update_buttons()
	_layout()
	queue_redraw()


func _act(i: int) -> Dictionary:
	return _acts[i] if i >= 0 and i < _acts.size() else {}


func _price(i: int) -> int:
	var a := _act(i)
	match str(a.get("kind", "")):
		"ware", "relic":
			var it = _stock[int(a["i"])]
			if not (it is Dictionary):
				return 0
			return Relics.price(it["id"]) if tab == "relics" else Game.ware_price(it)
		"reserve":
			return int(_reserve.get("price", 0)) if _reserve.get("item") is Dictionary else 0
		"draught":
			for d in _draughts:
				if d["id"] == a["id"]:
					return int(d["price"])
		"rekindle":
			return Game.rekindle_price(_kindle[int(a["row"])]["item"])
	return 0


func _act_shown(i: int) -> bool:
	## Whether price button i has something to sell (a bought ware's is gone;
	## Rekindle's shows only for a Legendary below the hero's level). With the
	## detail sheet open only its own shows (in the sheet).
	if _detail >= 0 and i != _detail:
		return false
	var a := _act(i)
	match str(a.get("kind", "")):
		"ware", "relic":
			return _stock[int(a["i"])] is Dictionary
		"reserve":
			return _reserve.get("item") is Dictionary
		"rekindle":
			return ["", "poor"].has(Game.rekindle_verdict(_kindle[int(a["row"])]["item"]))
	return not a.is_empty()


func _verdict(i: int) -> String:
	## What buying through price button i would do, or why not (Game's words;
	## "buy" and "rekindle" are go-aheads too).
	var a := _act(i)
	match str(a.get("kind", "")):
		"ware":
			return Game.ware_verdict(int(a["i"]))
		"relic":
			return Game.relic_verdict(_stock[int(a["i"])]["id"])
		"reserve":
			return Game.reserve_verdict()
		"draught":
			return Game.draught_verdict(str(a["id"]))
		"rekindle":
			var why: String = Game.rekindle_verdict(_kindle[int(a["row"])]["item"])
			return "rekindle" if why == "" else why
	return "sold"


func _update_buttons() -> void:
	for i in _buy_btns.size():
		var b := _buy_btns[i]
		b.visible = _act_shown(i)
		if not b.visible:
			continue
		b.queue_redraw()
	if _close_btn != null:
		_close_btn.visible = _detail >= 0
	var made := Game.hero_made()
	# Buy: Fresh stock, and the way to Sell while the satchel's full.
	_fresh_btn.visible = tab == "buy" and made
	_fresh_btn.queue_redraw()
	_full_btn.visible = tab == "buy" and made and Game.satchel_full()
	# Sell: the piece shown (Wear, Sell +N) and everything marked.
	var it = picked()
	var selling := tab == "sell" and made
	_wear_btn.visible = selling and it is Dictionary
	_sell_btn.visible = selling and it is Dictionary
	_sell_all_btn.visible = selling
	if it is Dictionary:
		_sell_btn.text = "Sell  +%d" % Items.sell_value(it)
	var marked := marked_items()
	var total := 0
	for m in marked:
		total += Items.sell_value(m)
	_sell_all_btn.text = ("Sell %d marked  +%d" % [marked.size(), total]) if not marked.is_empty() else "Nothing marked"
	_sell_all_btn.disabled = marked.is_empty()


func _draw_fresh() -> void:
	## Fresh stock's face: its name and an ember and the price (red when
	## it's too dear); waiting for its second tap, "Tap again" and the price,
	## with a bar running out.
	var b := _fresh_btn
	if not b.visible:
		return
	var p: int = Game.fresh_price()
	var asking := _fresh_armed > 0.0
	var word := "Tap again:" if asking else "Fresh stock"
	var fs := 14
	var ww := UI.text_width(word, fs, "body", 700)
	var pw := UI.text_width(str(p), fs, "body", 800)
	var x := (b.size.x - (ww + 6.0 + 18.0 + pw)) * 0.5
	var y := b.size.y * 0.5 + fs * 0.36
	if asking:
		b.draw_rect(Rect2(8.0, b.size.y - 7.0, (b.size.x - 16.0) * clampf(_fresh_armed / CONFIRM_TIME, 0.0, 1.0), 3.0), Color(UI.GOLD, 0.6))
	UI.text(b, Vector2(x, y), word, fs, UI.GOLD if asking else UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700)
	if _ember_tex:
		b.draw_texture_rect(_ember_tex, Rect2(x + ww + 4.0, b.size.y * 0.5 - 9.0, 18, 18), false)
	UI.text(b, Vector2(x + ww + 6.0 + 18.0, y), str(p), fs, UI.GOLD if Game.embers() >= p else Color("d88070"), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)


func fresh_btn_w() -> float:
	## Fresh stock's width: room for its longer face.
	var p := str(Game.fresh_price())
	return maxf(UI.text_width("Fresh stock", 14, "body", 700), UI.text_width("Tap again:", 14, "body", 700)) + UI.text_width(p, 14, "body", 800) + 6.0 + 18.0 + 24.0


func _fresh_pressed() -> void:
	## Two taps: the first asks (or refuses at once, too dear), the second
	## restocks the wares (Game.buy_fresh).
	var why: String = Game.fresh_verdict()
	if why != "fresh":
		_fresh_armed = 0.0
		_refuse(-1, why)
		_fresh_btn.queue_redraw()
		return
	if _fresh_armed <= 0.0:
		_fresh_armed = CONFIRM_TIME
		_sale = -1
		_say("ask_fresh")
		_update_buttons()
		return
	_fresh_armed = 0.0
	if Game.buy_fresh() == "fresh":
		_sfx("relic_rare")
		_say("fresh")
		_purse_flash = 1.0
		_refresh()
		for k in _stock.size():
			_flash[k] = 1.0


func _draw_price(b: Button, i: int) -> void:
	## A buy button's face: an ember and the price, red when it's too dear.
	## Waiting for its second tap, it goes gold and asks "Buy?", with a bar
	## along the bottom running out.
	if not _act_shown(i):
		return
	var p := _price(i)
	var asking := i == _sale and _sale_t > 0.0
	var col: Color = UI.GOLD if Game.embers() >= p else Color("d88070")
	if tab == "buy" and col == UI.GOLD and Game.hero_made() and Game.satchel_full() and _verdict(i) == "full":
		# Nowhere to put it (it wouldn't be worn): the price goes quiet.
		col = UI.MUTED
	var f := UI.font("body", 800)
	var txt := str(p)
	var fs := 20
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ask := "Buy?"
	var aw := f.get_string_size(ask, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0 if asking else 0.0
	var icon_w := 30.0
	if aw + icon_w + tw > b.size.x - 10.0:
		# A narrow button (a compact card's): smaller, and no ember while it asks.
		if asking:
			icon_w = 0.0
		for size in [16, 14, 12]:
			fs = size
			tw = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			aw = f.get_string_size(ask, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0 if asking else 0.0
			if aw + icon_w + tw <= b.size.x - 14.0:
				break
	var x := (b.size.x - (aw + icon_w + tw)) * 0.5
	var y := b.size.y * 0.5
	if asking:
		var pulse := 0.5 + 0.5 * sin(_t * 10.0)
		var face := _box("ask", UI.GOLD, UI.CREAM, 10)
		face.bg_color = UI.GOLD.lerp(Color("ffe7a8"), 0.35 * pulse)
		# Its shadow, in gold, is the glow around it.
		face.shadow_color = Color(Color("ffc850"), 0.30 + 0.25 * pulse)
		face.shadow_size = 7 + int(round(4.0 * pulse))
		face.draw(b.get_canvas_item(), Rect2(Vector2.ZERO, b.size))
		b.draw_rect(Rect2(8.0, b.size.y - 8.0, (b.size.x - 16.0) * clampf(_sale_t / CONFIRM_TIME, 0.0, 1.0), 3.0), Color("9a5a18", 0.75))
		b.draw_string(f, Vector2(x, y + fs * 0.35), ask, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK)
		x += aw
	if _ember_tex and icon_w > 0.0:
		b.draw_texture_rect(_ember_tex, Rect2(x, y - 12.0, 24, 24), false)
	if asking:
		b.draw_string(f, Vector2(x + icon_w, y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK)
		return
	b.draw_string_outline(f, Vector2(x + icon_w, y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, UI.INK)
	b.draw_string(f, Vector2(x + icon_w, y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _buy(i: int) -> void:
	## A price button tapped. The first tap asks (or refuses at once if the
	## sale can't happen); a second tap on the same button, while it still
	## asks, buys.
	if i < 0 or i >= _acts.size() or not _act_shown(i):
		return
	var kind := str(_acts[i]["kind"])
	var res := _verdict(i)
	if not ["equipped", "satchel", "belt", "stowed", "buy", "rekindle"].has(res):
		_sale = -1
		_refuse(i, res)
		return
	if i != _sale or _sale_t <= 0.0:
		_ask(i, res)
		return
	_sale = -1
	if kind == "reserve" or kind == "draught" or kind == "rekindle":
		_buy_more(i, kind)
		return
	if tab == "relics":
		var r: Dictionary = _stock[i]
		res = Game.buy_relic(r["id"])
		match res:
			"belt", "stowed":
				_sfx("relic_" + str(r["rarity"]))
				_say(res)
				_purse_flash = 1.0
				_refresh()
				if Game.relic_offers().is_empty():
					_say("bare")
				return
	else:
		res = Game.buy_ware(i)
		match res:
			"equipped", "satchel":
				_sfx("relic_" + str(_stock[i]["rarity"]) if _stock[i]["rarity"] != "common" else "select")
				# A full satchel had no room for the old one: Waxley bought it.
				var melt: Dictionary = Game.last_melt if res == "equipped" and str(Game.last_melt.get("for", "-")) == str(_stock[i].get("uid", "")) else {}
				if melt.is_empty():
					_say(res)
				else:
					_say("equipped_melt", " +%d embers." % int(melt["embers"]))
				_purse_flash = 1.0
				var keep := _notes.duplicate()
				keep[i] = {"text": "Worn" if res == "equipped" else "In your satchel", "name": _stock[i]["name"], "rarity": _stock[i]["rarity"]}
				if not melt.is_empty():
					keep[i]["sub"] = ("Old one sold  +%d" if melt["old"] else (str(melt["item"].get("name", "")) + " sold  +%d")) % int(melt["embers"])
				_refresh()
				_notes = keep
				_flash[i] = 1.0
				return
	_refuse(i, res)


func _ask(i: int, what: String) -> void:
	## The first tap on a price: that button asks "Buy?" for a few seconds.
	var old := _sale
	_sale = i
	_sale_t = CONFIRM_TIME
	if what == "equipped" and tab == "buy":
		var a := _act(i)
		var it = _stock[int(a["i"])] if a.get("kind") == "ware" else _reserve.get("item")
		if it is Dictionary and not Game.melt_on_equip(it).is_empty():
			what = "equipped_melt"   # the satchel's full: say what wearing it costs
	_say("ask_" + what)
	for k in [old, i]:
		if k >= 0 and k < _buy_btns.size():
			_buy_btns[k].queue_redraw()


func _refuse(i: int, why: String) -> void:
	## No sale: the card shakes and Waxley says why (the purse flashes red
	## only when it's the embers). A ware refused for a full satchel goes to
	## Sell, to make the room.
	_sfx("back")
	_deny_why = why
	if why == "full" and tab == "buy" and Game.hero_made():
		show_tab("sell")
		_deny_why = why
		_say("full")
		return
	_say(why if LINES.has(why) else ("sold" if why == "owned" or why == "unknown" else "poor"))
	_deny = 1.0
	_deny_card = i
	for b in _buy_btns:
		b.queue_redraw()


func _buy_more(i: int, kind: String) -> void:
	## The second tap on the Reserve's, a draught's or Rekindle's price.
	var res := ""
	match kind:
		"reserve":
			var it: Dictionary = _reserve["item"]
			res = Game.buy_reserve()
			if res == "equipped" or res == "satchel":
				_sfx("relic_legendary")
				_say(res)
				_purse_flash = 1.0
				var keep := _notes.duplicate()
				keep[i] = {"text": "Worn" if res == "equipped" else "In your satchel", "name": it["name"], "rarity": "legendary"}
				_refresh()
				_notes = keep
				_flash[i] = 1.0
				return
		"draught":
			res = Game.buy_draught(str(_acts[i]["id"]))
			if res == "bought":
				_sfx("relic_rare")
				_say("bought")
				_purse_flash = 1.0
				_refresh()
				return
		"rekindle":
			var row: Dictionary = _kindle[int(_acts[i]["row"])]
			if Game.rekindle(row["item"]):
				_sfx("relight")
				_say("rekindled")
				_purse_flash = 1.0
				_refresh()
				_flash[i] = 1.0
				return
			res = Game.rekindle_verdict(row["item"])
	_refuse(i, res)


# ---------------------------------------------------------------- the Sell tab

func _sync_grid() -> void:
	## The squares against the satchel now: a piece keeps its square; one gone
	## without a sale here (worn) leaves it empty; one new takes the first
	## empty square, else the oldest ghost's (that sale can't be bought back
	## here any more). A piece seen for the first time is marked as
	## Game.sell_look says.
	var h: Dictionary = Game.hero()
	var sat: Array = (h["satchel"] as Array).filter(func(it): return it is Dictionary)
	var have := {}
	for it in sat:
		have[str(it.get("uid", ""))] = true
	while _grid.size() < maxi(SQUARES, sat.size()):
		_grid.append({})
	var on := {}
	for k in _grid.size():
		var sq: Dictionary = _grid[k]
		if sq.has("uid"):
			if not have.has(str(sq["uid"])) or on.has(str(sq["uid"])):
				_grid[k] = {}
			else:
				on[str(sq["uid"])] = true
		elif sq.has("ghost") and Game.sold_price(sq["ghost"]) <= 0:
			_grid[k] = {}   # (bought back, or forgotten)
	for it in sat:
		var uid := str(it.get("uid", ""))
		if on.has(uid):
			continue
		var at := _free_square()
		if at < 0:
			_grid.append({})
			at = _grid.size() - 1
		_grid[at] = {"uid": uid}
		on[uid] = true
	while _grid.size() > SQUARES and (_grid.back() as Dictionary).is_empty():
		_grid.pop_back()
	for it in sat:
		var uid := str(it.get("uid", ""))
		_looks[uid] = Game.sell_look(it, h)
		if not _marked.has(uid):
			_marked[uid] = bool(_looks[uid]["marked"])
		UI.tex(Items.icon(it))
	if not have.has(_pick):
		_pick = ""


func _free_square() -> int:
	## The first empty square, else the oldest ghost's, else -1.
	var oldest := -1
	for k in _grid.size():
		var sq: Dictionary = _grid[k]
		if sq.is_empty():
			return k
		if sq.has("ghost") and (oldest < 0 or int(sq["n"]) < int(_grid[oldest]["n"])):
			oldest = k
	return oldest


func _square_of(uid: String) -> int:
	for k in _grid.size():
		if str((_grid[k] as Dictionary).get("uid", "-")) == uid:
			return k
	return -1


func piece(uid: String):
	## A satchel piece by its uid, or null.
	if not Game.hero_made() or uid == "":
		return null
	for it in (Game.hero()["satchel"] as Array):
		if it is Dictionary and str(it.get("uid", "")) == uid:
			return it
	return null


func picked():
	## The piece the Sell tab shows on the right, or null.
	return piece(_pick) if tab == "sell" else null


func grid_square(k: int) -> Dictionary:
	## Square k as the Sell tab has it: {uid}, {ghost, price, n} or {} (tests).
	return _grid[k] if k >= 0 and k < _grid.size() else {}


func is_marked(it) -> bool:
	return it is Dictionary and bool(_marked.get(str(it.get("uid", "")), false))


func marked_items() -> Array:
	## The pieces marked to sell, in the squares' order.
	var out := []
	if tab != "sell":
		return out
	for sq in _grid:
		if (sq as Dictionary).has("uid") and bool(_marked.get(str(sq["uid"]), false)):
			var it = piece(str(sq["uid"]))
			if it is Dictionary:
				out.append(it)
	return out


func tap_square(k: int) -> void:
	## A square tapped: a piece shows on the right, and a tap on the piece
	## shown marks it to sell or keeps it; a ghost is bought back.
	if k < 0 or k >= _grid.size():
		return
	var sq: Dictionary = _grid[k]
	if sq.has("ghost"):
		buy_back(k)
		return
	if not sq.has("uid"):
		return
	var uid := str(sq["uid"])
	if uid == _pick:
		_marked[uid] = not bool(_marked.get(uid, false))
		_sfx("select", 1.3 if _marked[uid] else 0.8)
		_say("marked" if _marked[uid] else "kept")
	else:
		_pick = uid
		_sfx("select")
	_update_buttons()
	_layout()
	queue_redraw()


func _ghost(k: int, it: Dictionary, price: int) -> void:
	## A sold piece's square: its ghost, to buy it back from.
	if k < 0 or k >= _grid.size():
		return
	_grid[k] = {"ghost": it, "price": price, "n": _ghosts}
	_ghosts += 1
	_sq_flash[k] = 1.0
	_marked.erase(str(it.get("uid", "")))


func sell_picked() -> int:
	## "Sell +N": the piece shown, at once (its ghost buys it back).
	var it = picked()
	if not (it is Dictionary):
		return 0
	var k := _square_of(_pick)
	var v: int = Game.sell_item(it)
	if v <= 0:
		return 0
	_ghost(k, it, v)
	_pick = ""
	_sfx("bank")
	_say("sold_one")
	_purse_flash = 1.0
	_refresh()
	return v


func sell_marked() -> int:
	## "Sell N marked": every marked piece, at once, no question asked (each
	## leaves its ghost).
	var items := marked_items()
	if items.is_empty():
		_say("no_marks")
		return 0
	var at := {}
	for it in items:
		at[str(it["uid"])] = _square_of(str(it["uid"]))
	var total: int = Game.sell_marked(items)
	for it in items:
		var v: int = Game.sold_price(it)
		if v > 0:
			_ghost(int(at[str(it["uid"])]), it, v)
			if str(it["uid"]) == _pick:
				_pick = ""
	_sfx("bank")
	_say("sold_marked", " +%d embers." % total)
	_purse_flash = 1.0
	_refresh()
	return total


func wear_picked() -> void:
	## Wear: the piece shown goes on; the one it replaces takes its square,
	## and shows (marked as Game.sell_look says, against the new one).
	var it = picked()
	if not (it is Dictionary):
		return
	var k := _square_of(_pick)
	var old = Game.equip(it)
	_sfx("equip")
	_say("worn" if old is Dictionary else "equipped")
	_pick = ""
	if old is Dictionary and k >= 0:
		_grid[k] = {"uid": str(old["uid"])}
		_marked.erase(str(old["uid"]))
		_pick = str(old["uid"])
		_sq_flash[k] = 1.0
	_refresh()


func buy_back(k: int) -> String:
	## A ghost tapped: the piece back in the satchel for what it fetched
	## (Game.buy_back), in its own square. Returns Game's word.
	var sq: Dictionary = grid_square(k)
	if not sq.has("ghost"):
		return "gone"
	var it: Dictionary = sq["ghost"]
	var why: String = Game.buy_back(it)
	if why != "satchel":
		if why == "gone":
			_grid[k] = {}
			_refresh()
		_refuse(-1, "back_full" if why == "full" else why)
		return why
	var uid := str(it.get("uid", ""))
	_grid[k] = {"uid": uid}
	_marked[uid] = false   # bought back: he wants it
	_pick = uid
	_sq_flash[k] = 1.0
	_sfx("select")
	_say("bought_back")
	_purse_flash = 1.0
	_refresh()
	return why


func wares_note() -> Dictionary:
	## The small print right of Waxley's line on Buy: {text, col}. (A full
	## satchel shows the red Sell link instead: a sale into it is refused.)
	if Game.hero_made() and Game.satchel_full():
		return {"text": "", "col": UI.MUTED}
	for it in _stock:
		if it is Dictionary:
			return {"text": "Item level %d  ·  new stock every bell" % int(it["ilvl"]), "col": UI.MUTED}
	return {"text": "New stock every bell" if Game.hero_made() else "", "col": UI.MUTED}


func sell_note() -> Dictionary:
	## The small print on Sell: the satchel, in red once it's full.
	if not Game.hero_made():
		return {"text": "", "col": UI.MUTED}
	var n := (Game.hero()["satchel"] as Array).size()
	return {"text": UI.satchel_line(n, Game.SATCHEL_MAX, " / "), "col": DOWN if n >= Game.SATCHEL_MAX else UI.MUTED}


# ---------------------------------------------------------------- layout

func _line_row() -> Rect2:
	## The row under the header: Waxley's line, and the note on the right (on
	## Buy, left of the Sell link and Fresh stock).
	var s := _safe()
	return Rect2(s.position.x, s.position.y + HEADER_H + 4.0, s.size.x, LINK_H)


func _cards_top() -> float:
	## Under that row: past its buttons on Buy, closer on the other tabs.
	var s := _safe()
	if _fresh_btn != null and _fresh_btn.visible:
		return _line_row().end.y + 4.0
	return s.position.y + HEADER_H + 40.0


func _line_btns_x() -> float:
	## Where the row's buttons start (its right end without them).
	var x := _line_row().end.x
	for b in [_full_btn, _fresh_btn]:
		if b != null and b.visible:
			x = minf(x, b.position.x)
	return x


func _sq_side() -> float:
	## A Sell square's side: SQ, or less for an over-full satchel's fifth row.
	var s := _safe()
	var rows := maxi(4, ceili(float(maxi(_grid.size(), SQUARES)) / SQ_COLS))
	return minf(SQ, floorf((s.end.y - 2.0 - _cards_top() - SQ_GAP * (rows - 1)) / rows))


func squares() -> Array:
	## The Sell tab's squares, four across from the left (_grid's order).
	var s := _safe()
	var top := _cards_top()
	var side := _sq_side()
	var out := []
	for k in maxi(_grid.size(), SQUARES):
		out.append(Rect2(s.position.x + (k % SQ_COLS) * (side + SQ_GAP), top + (k / SQ_COLS) * (side + SQ_GAP), side, side))
	return out


func sell_panel_rect() -> Rect2:
	## The piece shown (or how selling works), right of the squares, over
	## Sell marked.
	var s := _safe()
	var top := _cards_top()
	var x := s.position.x + SQ_COLS * _sq_side() + (SQ_COLS - 1) * SQ_GAP + 14.0
	return Rect2(x, top, s.end.x - x, s.end.y - 2.0 - top - BTN_H - 8.0)


func sell_all_rect() -> Rect2:
	var p := sell_panel_rect()
	return Rect2(p.position.x, p.end.y + 8.0, p.size.x, BTN_H)


func _cards() -> Array:
	## The card rects for the tab on show: the wares (or relics) in a row, or
	## past four wares (or with the Reserve) in two rows of three.
	var s := _safe()
	var top := _cards_top()
	var bottom := s.end.y - 2.0
	var n := _stock.size()
	if n == 0:
		return []
	if grid():
		return _grid_cards(n, top, bottom)
	var w := minf((s.size.x - GAP * (n - 1)) / n, 200.0 if tab == "buy" else 214.0)
	var total := w * n + GAP * (n - 1)
	var x0 := s.get_center().x - total * 0.5
	var out := []
	for i in n:
		out.append(Rect2(x0 + i * (w + GAP), top, w, bottom - top))
	return out


func grid() -> bool:
	## The wares (five or six since Game.WEAK_PICKS's second pick): two rows
	## of three compact cards, beside the Reserve's tall card from depth 23.
	## (The relics stand in a row of tall cards.)
	return tab == "buy"


func _grid_cards(n: int, top: float, bottom: float) -> Array:
	var s := _safe()
	var area_w := s.size.x - ((RESERVE_W + GAP) if not _reserve.is_empty() else 0.0)
	var rows := ceili(float(n) / GRID_COLS)
	var w := (area_w - GAP * (GRID_COLS - 1)) / GRID_COLS
	var h := (bottom - top - GAP * (rows - 1)) / rows
	var out := []
	for i in n:
		var row := i / GRID_COLS
		var in_row := mini(GRID_COLS, n - row * GRID_COLS)
		var col := i % GRID_COLS
		# A short last row sits in the middle of the grid.
		var x0 := s.position.x + (GRID_COLS - in_row) * (w + GAP) * 0.5
		out.append(Rect2(x0 + col * (w + GAP), top + row * (h + GAP), w, h))
	return out


func reserve_rect() -> Rect2:
	## Waxley's Reserve: a tall card right of the wares ({} when there's none).
	if _reserve.is_empty():
		return Rect2()
	var s := _safe()
	var top := _cards_top()
	return Rect2(s.end.x - RESERVE_W, top, RESERVE_W, s.end.y - 2.0 - top)


func draught_cards() -> Array:
	## The Draughts tab: a card per draught, left of the Rekindle panel.
	var s := _safe()
	var top := _cards_top()
	var bottom := s.end.y - 2.0
	var n := _draughts.size()
	var kw := rekindle_rect().size.x
	var w := minf((s.size.x - kw - GAP * n) / maxf(n, 1.0), 214.0)
	var out := []
	for i in n:
		out.append(Rect2(s.position.x + i * (w + GAP), top, w, bottom - top))
	return out


func rekindle_rect() -> Rect2:
	## Rekindle's panel on the Draughts tab, right of the draughts: the full
	## height once World 5 is reached, else a padlock strip under the flask.
	if tab != "draughts":
		return Rect2()
	var s := _safe()
	var top := _cards_top()
	var w := roundf(s.size.x * 0.44)
	if not Game.rekindle_open():
		return Rect2(s.end.x - w, s.end.y - 2.0 - LOCK_H, w, LOCK_H)
	return Rect2(s.end.x - w, top, w, s.end.y - 2.0 - top)


func flask_rect() -> Rect2:
	## Before World 5: the flask as it is, above Rekindle's strip.
	if tab != "draughts" or Game.rekindle_open():
		return Rect2()
	var k := rekindle_rect()
	var top := _cards_top()
	return Rect2(k.position.x, top, k.size.x, k.position.y - GAP - top)


func kindle_rows() -> Array:
	## Rekindle's rows, one per Legendary listed, under its heading.
	var r := rekindle_rect()
	var out := []
	for k in _kindle.size():
		out.append(Rect2(r.position.x + 10.0, r.position.y + 62.0 + k * (ROW_H + 4.0), r.size.x - 20.0, ROW_H))
	return out


func _compact_btn_w(c: Rect2) -> float:
	return clampf(roundf(c.size.x * 0.44), 78.0, 112.0)


func _btn_rect(i: int, cards: Array) -> Rect2:
	## Where price button i sits (in the detail sheet while it shows there).
	if i == _detail:
		return detail_btn_rect()
	var a := _act(i)
	match str(a.get("kind", "")):
		"ware", "relic":
			var c: Rect2 = cards[int(a["i"])]
			if grid():
				var bw := _compact_btn_w(c)
				return Rect2(c.end.x - 8.0 - bw, c.end.y - 7.0 - SMALL_BTN_H, bw, SMALL_BTN_H)
			return Rect2(c.position.x + 8.0, c.end.y - BTN_H - 8.0, c.size.x - 16.0, BTN_H)
		"reserve":
			var r := reserve_rect()
			return Rect2(r.position.x + 8.0, r.end.y - BTN_H - 8.0, r.size.x - 16.0, BTN_H)
		"draught":
			var dc := draught_cards()
			for k in _draughts.size():
				if _draughts[k]["id"] == a["id"]:
					var c: Rect2 = dc[k]
					return Rect2(c.position.x + 8.0, c.end.y - BTN_H - 8.0, c.size.x - 16.0, BTN_H)
		"rekindle":
			var row: Rect2 = kindle_rows()[int(a["row"])]
			return Rect2(row.end.x - 112.0, row.position.y + (ROW_H - BTN_H) * 0.5, 112.0, BTN_H)
	return Rect2()


func _layout() -> void:
	if _back_btn == null:
		return
	var s := _safe()
	var y := s.position.y
	_back_btn.position = Vector2(s.position.x, y)
	_back_btn.size = Vector2(84, HEADER_H)
	# Tabs sit left of the purse (v2's three at 100 each; four share what's
	# left right of the title, in a tighter style).
	var shown := tabs_shown()
	var tw := 100.0
	if shown.size() > 3:
		var title_end := s.position.x + 96.0 + UI.text_width(TITLE, 26, "title", 700) + 12.0
		tw = clampf(floorf((s.end.x - 108.0 - title_end - 6.0 * (shown.size() - 1)) / shown.size()), 84.0, 100.0)
	var tx := s.end.x - 108.0 - (tw * shown.size() + 6.0 * (shown.size() - 1))
	for i in shown.size():
		var b: Button = _tab_btns[shown[i]]
		b.position = Vector2(tx + i * (tw + 6.0), y)
		b.size = Vector2(tw, HEADER_H)
	var cards := _cards()
	for i in _buy_btns.size():
		var r := _btn_rect(i, cards)
		_buy_btns[i].position = r.position
		_buy_btns[i].size = r.size
	# The row under the header (Buy): Fresh stock at its right end, the Sell
	# link left of it.
	var row := _line_row()
	if _fresh_btn != null:
		_fresh_btn.size = Vector2(fresh_btn_w(), LINK_H)
		_fresh_btn.position = Vector2(row.end.x - _fresh_btn.size.x, row.position.y)
		_full_btn.reset_size()
		_full_btn.size = Vector2(_full_btn.size.x, LINK_H)
		_full_btn.position = Vector2(_fresh_btn.position.x - 8.0 - _full_btn.size.x, row.position.y)
	if _close_btn != null and _detail >= 0:
		var d := detail_rect()
		_close_btn.size = Vector2(88.0, 44.0)
		_close_btn.position = Vector2(d.end.x - 8.0 - 88.0, d.position.y + 8.0)
	# Sell: Wear and Sell +N at the foot of the panel, Sell marked under it.
	if _sell_btn != null:
		var sp := sell_panel_rect()
		_sell_btn.reset_size()
		_sell_btn.size = Vector2(maxf(_sell_btn.size.x, 124.0), BTN_H)
		_sell_btn.position = Vector2(sp.end.x - 12.0 - _sell_btn.size.x, sp.end.y - 10.0 - BTN_H)
		_wear_btn.reset_size()
		_wear_btn.size = Vector2(maxf(_wear_btn.size.x, 92.0), BTN_H)
		_wear_btn.position = Vector2(_sell_btn.position.x - 8.0 - _wear_btn.size.x, _sell_btn.position.y)
		var sa := sell_all_rect()
		_sell_all_btn.position = sa.position
		_sell_all_btn.size = sa.size


func _process(dt: float) -> void:
	_t += dt
	_line_t += dt
	_deny = maxf(_deny - dt * 3.0, 0.0)
	_purse_flash = maxf(_purse_flash - dt * 1.5, 0.0)
	for k in _flash.keys():
		_flash[k] = maxf(float(_flash[k]) - dt * 1.2, 0.0)
	for k in _sq_flash.keys():
		_sq_flash[k] = maxf(float(_sq_flash[k]) - dt * 1.5, 0.0)
	if _fresh_armed > 0.0:
		_fresh_armed -= dt
		if _fresh_armed <= 0.0:
			_fresh_armed = 0.0
		_fresh_btn.queue_redraw()   # its running-out bar
	if _sale >= 0:
		_sale_t -= dt
		if _sale >= _buy_btns.size() or _sale_t <= 0.0:
			_sale_t = 0.0
			if _sale < _buy_btns.size():
				_buy_btns[_sale].queue_redraw()
			_sale = -1
		else:
			_buy_btns[_sale].queue_redraw()   # its pulse and running-out bar
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var vs := get_size()
	var s := _safe()
	draw_rect(Rect2(Vector2.ZERO, vs), Color("0e0a14"))
	for i in 7:
		_arch(i * vs.x / 6.0 - 60.0, 120.0, 70.0 + (i % 2) * 30.0, vs.y + 10.0, Color("161022"))
	# Lamplight pooled on the shelf, behind the wares.
	_glow(Vector2(vs.x * 0.5, s.end.y + 60.0), vs.x * 0.55, 0.22)
	# The shelf the wares stand on, a candle at each end.
	var shelf_y := s.end.y - 30.0
	draw_rect(Rect2(0, shelf_y, vs.x, vs.y - shelf_y), WOOD)
	draw_rect(Rect2(0, shelf_y, vs.x, 3.0), Color("5a3e2a"))
	for k in int(vs.x / 64.0) + 1:
		draw_circle(Vector2(18.0 + k * 64.0, shelf_y + 12.0), 1.6, Color("1a110c"))
	if s.position.x >= 40.0:
		_shelf_candle(Vector2(s.position.x * 0.5, shelf_y + 1.0), 38.0, 0.0)
	if vs.x - s.end.x >= 40.0:
		_shelf_candle(Vector2(vs.x - (vs.x - s.end.x) * 0.5, shelf_y + 1.0), 26.0, 1.3)
	# The header: title and the purse.
	UI.text(self, Vector2(s.position.x + 96.0, s.position.y + 31.0), TITLE, 26, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 5)
	_draw_purse(Rect2(s.end.x - 102.0, s.position.y, 102.0, HEADER_H))
	# Waxley's line, and a note (and on Buy the row's buttons) on the right.
	# The note gives way first, then the line shrinks to fit what's left.
	var ly := _line_row().get_center().y + 5.0
	var shake := sin(_t * 60.0) * 5.0 * _deny
	var note := _note()
	var ncol := UI.MUTED
	if tab == "buy" or tab == "sell":
		var wn := wares_note() if tab == "buy" else sell_note()
		note = str(wn["text"])
		ncol = wn["col"]
	var right := s.end.x - 4.0
	if _line_btns_x() < _line_row().end.x:
		right = _line_btns_x() - 12.0
	var nweight := 700 if ncol == DOWN else 600
	var nw := UI.text_width(note, 13, "body", nweight) if note != "" else 0.0
	var line_x := s.position.x + 4.0
	var room := right - line_x - (nw + 16.0 if nw > 0.0 else 0.0)
	var who := "Waxley: "
	var size := 15
	while size > 11 and UI.text_width(who, size, "body", 700) + UI.text_width(_line, size) > room:
		size -= 1
	if UI.text_width(who, size, "body", 700) + UI.text_width(_line, size) > room and ncol != DOWN:
		# Still too long: drop the small print (never the full-satchel warning).
		note = ""
		room = right - line_x
	var ww := UI.text_width(who, size, "body", 700)
	line_fits = ww + UI.text_width(_line, size) <= room + 0.5
	var a := clampf(_line_t * 5.0, 0.0, 1.0)
	UI.text(self, Vector2(line_x + shake, ly), who, size, Color(UI.EMBER, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700, 4)
	UI.text(self, Vector2(line_x + ww + shake, ly), _line, size, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, room - ww, "body", 600, 4)
	if note != "":
		UI.text(self, Vector2(s.position.x, ly), note, 13, ncol, HORIZONTAL_ALIGNMENT_RIGHT, right - s.position.x, "body", nweight, 3)
	match tab:
		"buy":
			_draw_wares()
			if _detail >= 0:
				_draw_detail()
		"sell":
			_draw_sell()
		"relics":
			_draw_relics()
		"draughts":
			_draw_draughts()


func _note() -> String:
	## The small print at the right of Waxley's line.
	match tab:
		"draughts":
			if not Game.hero_made():
				return ""
			var n: int = Game.flask_charges()
			return "Flask: %d draught%s, each heals %d%%" % [n, "" if n == 1 else "s", roundi(float(Game.flask_heal()) * 100.0)]
		"buy":
			return str(wares_note()["text"])
		"sell":
			return str(sell_note()["text"])
		"relics":
			return "Belt %d / %d" % [Game.belt().size(), Game.belt_slots()]
	return ""


func _draw_purse(r: Rect2) -> void:
	var col := UI.CREAM.lerp(UI.GOLD, _purse_flash)
	if _deny > 0.0 and _deny_why == "poor":
		col = col.lerp(DOWN, _deny)
	_box("purse", Color(0.07, 0.05, 0.09, 0.85), Color(UI.PANEL_EDGE, 0.8), 10).draw(get_canvas_item(), r)
	if _ember_tex:
		draw_texture_rect(_ember_tex, Rect2(r.position.x + 6.0, r.position.y + 7.0, 30, 30), false)
	UI.text(self, Vector2(r.position.x + 38.0, r.position.y + 30.0), str(Game.embers()), 20, col, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 42.0, "body", 800, 4)


func _card_frame(c: Rect2, col: Color, i: int, dim := false) -> Rect2:
	## A card's panel (shaken on a refused sale, glowing after a sale);
	## returns where it was drawn.
	var glow := float(_flash.get(i, 0.0))
	if i == _deny_card:
		c.position.x += sin(_t * 60.0) * 6.0 * _deny
	if glow > 0.0:
		var sb := _box("glow", Color(UI.GOLD, 0.3), Color(UI.GOLD, 0.0), 18)
		sb.bg_color = Color(UI.GOLD, 0.3 * glow)
		sb.draw(get_canvas_item(), c.grow(7.0 * glow))
	UI.panel(self, c, Color(col, 0.35 if dim else 0.85), Color("150f1e") if dim else UI.PANEL, 12.0)
	return c


func _draw_wares() -> void:
	var s := _safe()
	if not Game.hero_made():
		UI.text(self, Vector2(s.position.x, s.get_center().y + 20.0), "Waxley sells to Wicks with a calling.", 17, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x)
		return
	_draw_wares_grid()


func _draw_wares_grid() -> void:
	## Five or six wares in two rows of three compact cards (the icon left of
	## the name, the chips left of the price), and the Reserve's tall card.
	var cards := _cards()
	var rr := reserve_rect()
	var ri := _stock.size()   # the Reserve's price button and card index
	var frames := []
	for i in _stock.size():
		var it = _stock[i]
		var col: Color = UI.RARITY.get(it["rarity"], UI.CREAM) if it is Dictionary else UI.PANEL_EDGE
		frames.append(_card_frame(cards[i], col, i, not (it is Dictionary)))
	var rframe := Rect2()
	if rr.has_area():
		var has: bool = _reserve.get("item") is Dictionary
		rframe = _card_frame(rr, UI.RARITY["legendary"] if has else UI.PANEL_EDGE, ri, not has)
	# The icon discs, in one batch, under the icons.
	var tb := TriBatch.new()
	for i in _stock.size():
		var it = _stock[i]
		if it is Dictionary:
			var col: Color = UI.RARITY.get(it["rarity"], UI.CREAM)
			var ic := _compact_icon_at(frames[i])
			tb.circle(ic, 20.0, Color(col, 0.10), 20)
			tb.ring(ic, 20.0, 1.5, Color(col, 0.4), 24)
	if rframe.has_area() and _reserve.get("item") is Dictionary:
		var rc: Color = UI.RARITY["legendary"]
		var ric := _reserve_icon_at(rframe)
		tb.circle(ric, 25.0, Color(rc, 0.12), 24)
		tb.ring(ric, 25.0, 1.5, Color(rc, 0.5), 28)
	tb.flush(self)
	for i in _stock.size():
		if _stock[i] is Dictionary:
			_draw_ware_compact(frames[i], _stock[i], i)
		else:
			_draw_sold_compact(frames[i], i)
	if rframe.has_area():
		_draw_reserve(rframe, ri)


func _compact_icon_at(c: Rect2) -> Vector2:
	return Vector2(c.position.x + 30.0, c.position.y + 44.0)


func compact_name_w(c: Rect2) -> float:
	## The room for a compact card's name, right of its icon.
	return c.size.x - 62.0


static func compact_name(name: String, w: float) -> Dictionary:
	## A compact card's name in width w: {lines, size}. One line at 14-12 px
	## when it fits; else two, broken at a space, at 13-10 px (every ware
	## name does by 11 px in the narrowest card); else, as a last resort, the
	## "of the ..." suffix dropped (a Blessed item's: the sheet names it
	## whole), then an ellipsis after a whole word. Never cut mid-word.
	var one := UI.fit_size(name, w, 14, 12, "title", 700)
	if UI.text_width(name, one, "title", 700) <= w:
		return {"lines": [name], "size": one}
	var cut := name.find(" of ")
	if cut > 0:
		# Broken before its "of the ..." when both halves fit by 11 px...
		var halves: Array = [name.substr(0, cut), name.substr(cut + 1)]
		for sz in [13, 12, 11]:
			if halves.all(func(l): return UI.text_width(str(l), sz, "title", 700) <= w):
				return {"lines": halves, "size": sz}
	for sz in [13, 12, 11, 10]:
		# ...else at the last space that fits.
		var lines: Array = UI.wrap(name, w, sz, "title", 700)
		if lines.size() <= 2 and lines.all(func(l): return UI.text_width(str(l), sz, "title", 700) <= w):
			return {"lines": lines, "size": sz}
	if cut > 0:
		return compact_name(name.substr(0, cut), w)
	var words: Array = Array(name.split(" ", false))
	while words.size() > 1:
		words.pop_back()
		var short := " ".join(PackedStringArray(words)) + "..."
		var lines: Array = UI.wrap(short, w, 10, "title", 700)
		if lines.size() <= 2 and lines.all(func(l): return UI.text_width(str(l), 10, "title", 700) <= w):
			return {"lines": lines, "size": 10}
	return {"lines": [name], "size": 10}


func is_pick(i: int) -> bool:
	## Whether ware i is one of the "For your <slot>" picks (the last ones).
	return tab == "buy" and i >= _stock.size() - Game.WEAK_PICKS and i < _stock.size()


func _draw_ware_compact(c: Rect2, it: Dictionary, i: int) -> void:
	var col: Color = UI.RARITY.get(it["rarity"], UI.CREAM)
	var x := c.position.x
	var w := c.size.x
	var slot_name: String = Items.SLOT_NAME.get(it["slot"], "")
	if is_pick(i):
		UI.text(self, Vector2(x + 10.0, c.position.y + 16.0), "For your %s" % slot_name.to_lower(), 11, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, w * 0.62, "body", 700)
	else:
		UI.text(self, Vector2(x + 10.0, c.position.y + 16.0), slot_name, 11, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, "body", 700)
	UI.text(self, Vector2(x, c.position.y + 16.0), Items.RARITY_NAME[it["rarity"]], 11, col, HORIZONTAL_ALIGNMENT_RIGHT, w - 10.0, "body", 800)
	var ic := _compact_icon_at(c)
	var tex := UI.tex(Items.icon(it))
	if tex:
		draw_texture_rect(tex, Rect2(ic - Vector2(17, 17), Vector2(34, 34)), false)
	else:
		_icon(ic, 16.0, it, col)
	# The name right of the icon (one line, else two, broken at a space:
	# compact_name), then its best lines; a tap on the card shows them all.
	var nx := x + 54.0
	var nw := compact_name_w(c)
	var cn := compact_name(str(it["name"]), nw)
	var nfs := int(cn["size"])
	var nl: Array = cn["lines"]
	var ny := c.position.y + (38.0 if nl.size() == 1 else 31.0)
	for k in nl.size():
		UI.text(self, Vector2(nx, ny + (nfs + 1) * k), str(nl[k]), nfs, col, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 4)
	var btn_top := c.end.y - 7.0 - SMALL_BTN_H
	var ly := ny + (nfs + 1) * (nl.size() - 1) + 3.0
	var all: Array = Items.lines(it).filter(func(l): return l["kind"] != "implicit") + Items.lines(it).filter(func(l): return l["kind"] == "implicit")
	_draw_lines_left(all, Rect2(nx, ly, nw, btn_top - 4.0 - ly))
	# The chips, stacked left of the price.
	var ch: Dictionary = _chips[i] if i < _chips.size() else {}
	var cw := w - 16.0 - _compact_btn_w(c) - 6.0
	_chip(Rect2(x + 8.0, btn_top, cw, 21.0), "DMG", float(ch.get("dmg", 0.0)))
	_chip(Rect2(x + 8.0, btn_top + SMALL_BTN_H - 21.0, cw, 21.0), "LIFE", float(ch.get("life", 0.0)))


func _draw_sold_compact(c: Rect2, i: int) -> void:
	var note: Dictionary = _notes.get(i, {})
	var cy := c.get_center().y
	if note.is_empty():
		UI.text(self, Vector2(c.position.x, cy - 2.0), "Sold", 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "title", 700, 4)
	else:
		var col: Color = UI.RARITY.get(note["rarity"], UI.CREAM)
		UI.text(self, Vector2(c.position.x + 6.0, cy - 16.0), str(note["name"]), UI.fit_size(str(note["name"]), c.size.x - 12.0, 14, 10, "title", 700), Color(col, 0.75), HORIZONTAL_ALIGNMENT_CENTER, c.size.x - 12.0, "title", 700)
		UI.text(self, Vector2(c.position.x, cy + 6.0), note["text"], 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "title", 700, 4)
		if note.has("sub"):
			var sub := str(note["sub"])
			UI.text(self, Vector2(c.position.x + 6.0, cy + 24.0), sub, UI.fit_size(sub, c.size.x - 12.0, 11, 9), UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x - 12.0)
	UI.text(self, Vector2(c.position.x, c.end.y - 12.0), "More after the next bell", 11, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x)


func _draw_reserve(c: Rect2, i: int) -> void:
	## Waxley's Reserve: a Legendary for the depth, until a boss that deep falls.
	UI.text(self, Vector2(c.position.x, c.position.y + 18.0), "Waxley's Reserve", 13, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "body", 800)
	var it = _reserve.get("item")
	if not (it is Dictionary):
		var note: Dictionary = _notes.get(i, {})
		var cy := c.get_center().y
		if note.is_empty():
			UI.text(self, Vector2(c.position.x, cy - 6.0), "Sold", 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "title", 700, 4)
		else:
			UI.text(self, Vector2(c.position.x + 6.0, cy - 20.0), str(note["name"]), UI.fit_size(str(note["name"]), c.size.x - 12.0, 15, 10, "title", 700), Color(UI.RARITY["legendary"], 0.75), HORIZONTAL_ALIGNMENT_CENTER, c.size.x - 12.0, "title", 700)
			UI.text(self, Vector2(c.position.x, cy + 4.0), note["text"], 17, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "title", 700, 4)
		var lines: Array = UI.wrap("Another when you beat a boss this deep", c.size.x - 24.0, 12)
		for k in lines.size():
			UI.text(self, Vector2(c.position.x, c.end.y - 30.0 + 15.0 * k), lines[k], 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x)
		return
	var col: Color = UI.RARITY["legendary"]
	var ic := _reserve_icon_at(c)
	var tex := UI.tex(Items.icon(it))
	if tex:
		draw_texture_rect(tex, Rect2(ic - Vector2(20, 20), Vector2(40, 40)), false)
	else:
		_icon(ic, 18.0, it, col)
	# The name (two lines at most), its power in full, then the rest one row
	# each; a tap on the card opens the sheet with everything.
	var bw := c.size.x - 20.0
	var nl: Array = UI.wrap(str(it["name"]), bw, 15, "title", 700)
	var nfs := 15
	if nl.size() > 2 or nl.any(func(l): return UI.text_width(str(l), 15, "title", 700) > bw):
		nfs = 13
		nl = UI.wrap(str(it["name"]), bw, nfs, "title", 700)
	var ny := c.position.y + 92.0
	for k in mini(nl.size(), 2):
		UI.text(self, Vector2(c.position.x + 10.0, ny + (nfs + 2) * k), str(nl[k]), nfs, col, HORIZONTAL_ALIGNMENT_CENTER, bw, "title", 700, 4)
	var ly := ny + (nfs + 2) * (mini(nl.size(), 2) - 1) + 6.0
	var chips_y := c.end.y - 8.0 - BTN_H - 6.0 - 22.0
	var power: String = Items.LEGENDS.get(str(it.get("legend", "")), {}).get("text", "")
	var pfs := 12
	var pl: Array = UI.wrap(power, bw, pfs)
	while pl.size() > 3 and pfs > 10:
		pfs -= 1
		pl = UI.wrap(power, bw, pfs)
	for k in pl.size():
		UI.text(self, Vector2(c.position.x + 10.0, ly + 11.0 + (pfs + 2) * k), pl[k], pfs, Color("ffc080"), HORIZONTAL_ALIGNMENT_CENTER, bw)
	ly += (pfs + 2) * pl.size() + 3.0
	var rest: Array = Items.lines(it).filter(func(l): return l["kind"] == "affix") + Items.lines(it).filter(func(l): return l["kind"] == "implicit")
	_draw_lines_left(rest, Rect2(c.position.x + 10.0, ly, bw, chips_y - 3.0 - ly), true)
	var cw := (c.size.x - 24.0) * 0.5
	_chip(Rect2(c.position.x + 8.0, chips_y, cw, 22.0), "DMG", float(_reserve_chips.get("dmg", 0.0)))
	_chip(Rect2(c.position.x + 16.0 + cw, chips_y, cw, 22.0), "LIFE", float(_reserve_chips.get("life", 0.0)))


func _reserve_icon_at(c: Rect2) -> Vector2:
	return Vector2(c.get_center().x, c.position.y + 52.0)


func detail_rows() -> Array:
	## The sheet's text, laid out: [{text, pos (baseline left), w, size, col,
	## kind, weight}], top down: what it is, its name, its item level, its
	## power in full, then every other line in two columns. Drawn by
	## _draw_detail; the tests check each one fits.
	var it = detail_item()
	if not (it is Dictionary):
		return []
	var d := detail_rect()
	var x := d.position.x
	var w := d.size.x
	var y := d.position.y
	var out := []
	var a := _act(_detail)
	var is_res := str(a.get("kind", "")) == "reserve"
	var weak := not is_res and is_pick(int(a.get("i", -1)))
	var col: Color = UI.RARITY.get(it["rarity"], UI.CREAM)
	var slot_name: String = Items.SLOT_NAME.get(it["slot"], "")
	var head := "Waxley's Reserve" if is_res else ("For your %s" % slot_name.to_lower() if weak else slot_name)
	var head_w := UI.text_width(head, 13, "body", 800)
	out.append({"text": head, "pos": Vector2(x + 16.0, y + 28.0), "w": head_w + 1.0, "size": 13, "col": UI.GOLD if is_res or weak else UI.MUTED, "kind": "body", "weight": 800})
	var rar := "·  %s %s" % [Items.RARITY_NAME[it["rarity"]], slot_name.to_lower()] if is_res or weak else "·  %s" % Items.RARITY_NAME[it["rarity"]]
	out.append({"text": rar, "pos": Vector2(x + 24.0 + head_w, y + 28.0), "w": UI.text_width(rar, 13, "body", 800) + 1.0, "size": 13, "col": col, "kind": "body", "weight": 800})
	# The name right of the icon (Close sits above it, at the top right).
	var nx := x + 88.0
	var nw := w - 88.0 - 16.0
	var nfs := UI.fit_size(str(it["name"]), nw, 19, 14, "title", 700)
	var names: Array = [str(it["name"])]
	if UI.text_width(str(it["name"]), nfs, "title", 700) > nw:
		names = UI.wrap(str(it["name"]), nw, 14, "title", 700).slice(0, 2)
	var ny := y + (80.0 if names.size() == 1 else 72.0)
	for k in names.size():
		out.append({"text": names[k], "pos": Vector2(nx, ny + (nfs + 2) * k), "w": nw, "size": nfs, "col": col, "kind": "title", "weight": 700})
	# Its item level, and what Waxley would give for it back (Items.sell_value).
	var sub := "Item level %d  ·  sells back for %d" % [int(it["ilvl"]), Items.sell_value(it)]
	out.append({"text": sub, "pos": Vector2(nx, ny + (nfs + 2) * (names.size() - 1) + 20.0), "w": nw, "size": 12, "col": UI.MUTED, "kind": "body", "weight": 600})
	# The lines: the power in full (wrapped), then the rest in two columns.
	var ly := y + 128.0
	var lw := w - 32.0
	var power: String = Items.LEGENDS.get(str(it.get("legend", "")), {}).get("text", "") if str(it.get("legend", "")) != "" else ""
	if power != "":
		for pl in UI.wrap(power, lw, 14):
			out.append({"text": pl, "pos": Vector2(x + 16.0, ly), "w": lw, "size": 14, "col": Color("ffc080"), "kind": "body", "weight": 700})
			ly += 18.0
		ly += 4.0
	var rest: Array = Items.lines(it).filter(func(l): return l["kind"] == "affix") + Items.lines(it).filter(func(l): return l["kind"] == "implicit")
	var cw := (lw - 16.0) * 0.5
	for k in rest.size():
		var txt: String = rest[k]["text"]
		var fs := UI.fit_size(txt, cw, 14, 11)
		var px := x + 16.0 + (k % 2) * (cw + 16.0)
		out.append({"text": txt, "pos": Vector2(px, ly + 18.0 * (k / 2)), "w": cw, "size": fs,
				"col": UI.MUTED if rest[k]["kind"] == "implicit" else UI.CREAM, "kind": "body", "weight": 600})
	# Where a sale would put it, just over the band.
	var where := detail_where()
	var last := 0.0
	for r in out:
		last = maxf(last, (r["pos"] as Vector2).y)
	var wy := maxf(detail_band().position.y - 10.0, last + 20.0)
	if where != "" and wy <= detail_band().position.y - 4.0:
		var wfs := UI.fit_size(where, lw, 13, 10)
		out.append({"text": where, "pos": Vector2(x + 16.0, wy), "w": lw, "size": wfs,
				"col": DOWN if ["full", "poor"].has(_verdict(_detail)) else UI.MUTED, "kind": "body", "weight": 700})
	return out


func detail_where() -> String:
	## One line on the sheet: what buying it would do, or why it can't.
	match _verdict(_detail):
		"equipped":
			var it = detail_item()
			if it is Dictionary and not Game.melt_on_equip(it).is_empty():
				return "Better than what you wear: you'd put it on, and I'd buy one from your full satchel."
			return "Better than what you wear: you'd put it on at once."
		"satchel":
			var leg := Game.worn_legend_kept(detail_item())
			if not leg.is_empty():
				return "Your %s stays on (its power isn't in the numbers): this would go in your satchel." % str(leg["name"])
			return "Not better than what you wear: it would go in your satchel."
		"full":
			return "Your satchel is full: sell me something first."
		"poor":
			return "Not enough embers yet."
	return ""


func detail_band() -> Rect2:
	## The sheet's bottom band: the chips, and the price button on the right.
	var d := detail_rect()
	return Rect2(d.position.x + 14.0, d.end.y - 10.0 - BTN_H, d.size.x - 28.0, BTN_H)


func _draw_detail() -> void:
	## The detail sheet over the cards (the shop dimmed behind it): what the
	## item is, its name, every line, what wearing it would do; its price
	## button (moved here) and Close are buttons on top.
	var it = detail_item()
	if not (it is Dictionary):
		return
	var vs := get_size()
	var d := detail_rect()
	draw_rect(Rect2(0.0, d.position.y - 8.0, vs.x, vs.y - d.position.y + 8.0), Color(0.03, 0.02, 0.05, 0.66))
	var col: Color = UI.RARITY.get(it["rarity"], UI.CREAM)
	var dx := sin(_t * 60.0) * 6.0 * _deny if _deny_card == _detail else 0.0
	UI.panel(self, Rect2(d.position + Vector2(dx, 0.0), d.size), Color(col, 0.9), UI.PANEL, 14.0)
	var ic := Vector2(d.position.x + 48.0 + dx, d.position.y + 76.0)
	var tb := TriBatch.new()
	tb.circle(ic, 28.0, Color(col, 0.12), 26)
	tb.ring(ic, 28.0, 1.5, Color(col, 0.5), 30)
	tb.flush(self)
	var tex := UI.tex(Items.icon(it))
	if tex:
		draw_texture_rect(tex, Rect2(ic - Vector2(24, 24), Vector2(48, 48)), false)
	for r in detail_rows():
		UI.text(self, r["pos"] + Vector2(dx, 0.0), r["text"], int(r["size"]), r["col"], HORIZONTAL_ALIGNMENT_LEFT, -1, r["kind"], int(r["weight"]), 4 if r["kind"] == "title" else 0)
	var band := detail_band()
	var ch: Dictionary = _reserve_chips if str(_act(_detail).get("kind", "")) == "reserve" else (_chips[int(_act(_detail)["i"])] if int(_act(_detail).get("i", -1)) < _chips.size() else {})
	var chw := 112.0
	_chip(Rect2(band.position.x + dx, band.position.y + 11.0, chw, 24.0), "DMG", float(ch.get("dmg", 0.0)))
	_chip(Rect2(band.position.x + chw + 8.0 + dx, band.position.y + 11.0, chw, 24.0), "LIFE", float(ch.get("life", 0.0)))


func _draw_lines_left(all: Array, box: Rect2, centred := false) -> void:
	## An item's lines, one row each (shrunk to fit, else cut), top down,
	## left-aligned (or centred); "+N more · tap" when they run out of room
	## (the card's tap opens the sheet with every line).
	var y := box.position.y
	var align := HORIZONTAL_ALIGNMENT_CENTER if centred else HORIZONTAL_ALIGNMENT_LEFT
	for k in all.size():
		var ln: Dictionary = all[k]
		var txt: String = ln["text"]
		var lc: Color = UI.MUTED if ln["kind"] == "implicit" else (Color("ffc080") if ln["kind"] == "legend" else UI.CREAM)
		var need := 12.0 + (12.0 if k < all.size() - 1 else 0.0)
		if y + need > box.end.y + 1.0:
			if y + 11.0 <= box.end.y + 1.0:
				UI.text(self, Vector2(box.position.x, y + 10.0), "+%d more · tap" % (all.size() - k), 11, Color(UI.GOLD, 0.8), align, box.size.x, "body", 700)
			return
		var fs := UI.fit_size(txt, box.size.x, 11, 8)
		UI.text(self, Vector2(box.position.x, y + 10.0), txt, fs, lc, align, box.size.x)
		y += 12.0


func _draw_draughts() -> void:
	## The Draughts tab: the Second Draught (Mother Yarrow's gift) and the
	## Rich Draught as cards, Rekindle's panel on the right.
	var s := _safe()
	if not Game.hero_made():
		UI.text(self, Vector2(s.position.x, s.get_center().y + 20.0), "Waxley sells to Wicks with a calling.", 17, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x)
		return
	var dc := draught_cards()
	var frames := []
	for k in _draughts.size():
		var d: Dictionary = _draughts[k]
		var col: Color = UI.GOLD if d["state"] != "locked" else UI.PANEL_EDGE
		frames.append(_card_frame(dc[k], col, _act_index("draught", d["id"]), d["state"] == "locked"))
	var kr := rekindle_rect()
	var fr := flask_rect()
	UI.panel(self, kr, Color(UI.RARITY["legendary"], 0.55) if Game.rekindle_open() else Color(UI.PANEL_EDGE, 0.35),
			UI.PANEL if Game.rekindle_open() else Color("150f1e"), 12.0)
	if fr.has_area():
		UI.panel(self, fr, Color(UI.GOLD, 0.45), UI.PANEL, 12.0)
	# The flasks and the rows' discs in one batch.
	var tb := TriBatch.new()
	for k in _draughts.size():
		_flask(tb, Vector2(frames[k].get_center().x, frames[k].position.y + 64.0), str(_draughts[k]["id"]), _draughts[k]["state"] == "locked")
	var rows := kindle_rows()
	for k in rows.size():
		tb.circle(Vector2(rows[k].position.x + 22.0, rows[k].get_center().y), 18.0, Color(UI.RARITY["legendary"], 0.12), 20)
	var charges: int = Game.flask_charges()
	if fr.has_area():
		# His flask today: one flask per draught.
		var fx0 := fr.get_center().x - (charges - 1) * 29.0
		for k in charges:
			_flask(tb, Vector2(fx0 + k * 58.0, fr.position.y + 84.0), "rich" if bool(Game.data["flask"].get("rich", false)) else "second", false)
	if not Game.rekindle_open():
		_padlock(tb, Vector2(kr.position.x + 26.0, kr.get_center().y + 2.0))
	tb.flush(self)
	for k in _draughts.size():
		var d: Dictionary = _draughts[k]
		var c: Rect2 = frames[k]
		var dim: bool = d["state"] == "locked"
		UI.text(self, Vector2(c.position.x + 6.0, c.position.y + 24.0), d["name"], UI.fit_size(d["name"], c.size.x - 12.0, 16, 11, "title", 700),
				UI.MUTED if dim else UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, c.size.x - 12.0, "title", 700, 4)
		var lines: Array = UI.wrap(d["text"], c.size.x - 24.0, 13)
		for j in mini(lines.size(), 4):
			UI.text(self, Vector2(c.position.x, c.position.y + 118.0 + 16.0 * j), lines[j], 13, UI.MUTED if dim else UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, c.size.x)
		match str(d["state"]):
			"owned":
				UI.text(self, Vector2(c.position.x, c.end.y - 24.0), "Yours, on every difficulty", 13, UI.GOOD, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "body", 700)
			"locked":
				var why: Array = UI.wrap(str(d["why"]), c.size.x - 20.0, 12)
				for j in mini(why.size(), 2):
					UI.text(self, Vector2(c.position.x, c.end.y - 32.0 + 15.0 * j), why[j], 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x)
	# The flask, before World 5.
	if fr.has_area():
		UI.text(self, Vector2(fr.position.x + 14.0, fr.position.y + 26.0), "Your flask", 18, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 4)
		var heal := roundi(float(Game.flask_heal()) * 100.0)
		var fl: Array = UI.wrap("%d draught%s on %s, each healing %d%% of your life. Every altar fills it again." % [charges, "" if charges == 1 else "s",
				str(Combat.diff(Game.diff())["name"]), heal], fr.size.x - 28.0, 13)
		for j in mini(fl.size(), 3):
			UI.text(self, Vector2(fr.position.x, fr.position.y + 138.0 + 16.0 * j), fl[j], 13, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, fr.size.x)
	# Rekindle.
	if not Game.rekindle_open():
		var lx := kr.position.x + 48.0
		UI.text(self, Vector2(lx, kr.position.y + 26.0), "Rekindle", 16, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 4)
		var note := "Opens in the Shattered Sanctum: a Legendary made new at your level."
		var nl: Array = UI.wrap(note, kr.end.x - 12.0 - lx, 12)
		for j in mini(nl.size(), 2):
			UI.text(self, Vector2(lx, kr.position.y + 43.0 + 14.0 * j), nl[j], 12, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, kr.end.x - 12.0 - lx)
		return
	UI.text(self, Vector2(kr.position.x + 14.0, kr.position.y + 24.0), "Rekindle", 18, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 4)
	var sub := "A Legendary made new at your level (item level %d). Same power, fresh numbers." % Game.rekindle_level()
	var sl: Array = UI.wrap(sub, kr.size.x - 28.0, 12)
	for j in mini(sl.size(), 2):
		UI.text(self, Vector2(kr.position.x + 14.0, kr.position.y + 42.0 + 14.0 * j), sl[j], 12, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, kr.size.x - 28.0)
	if Game.rekindle_open() and _kindle.is_empty():
		UI.text(self, Vector2(kr.position.x, kr.get_center().y + 20.0), "Carry a Legendary and I'll pour it new.", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x)
	for k in rows.size():
		var r: Rect2 = rows[k]
		var row: Dictionary = _kindle[k]
		var it: Dictionary = row["item"]
		var ic := Vector2(r.position.x + 22.0, r.get_center().y)
		var tex := UI.tex(Items.icon(it))
		if tex:
			draw_texture_rect(tex, Rect2(ic - Vector2(15, 15), Vector2(30, 30)), false)
		var tx := r.position.x + 48.0
		var tw := r.size.x - 48.0 - 118.0
		UI.text(self, Vector2(tx, r.position.y + 20.0), it["name"], UI.fit_size(it["name"], tw, 14, 10, "title", 700), UI.RARITY["legendary"], HORIZONTAL_ALIGNMENT_LEFT, tw, "title", 700)
		var v: String = row.get("verdict", "")
		var what := "Item level %d to %d%s" % [int(it["ilvl"]), Game.rekindle_level(), "  ·  worn" if row["worn"] else ""]
		if v == "lower":
			what = "Item level %d: at your level" % int(it["ilvl"])
		UI.text(self, Vector2(tx, r.position.y + 38.0), what, UI.fit_size(what, tw, 11, 9), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, tw)


func _act_index(kind: String, id := "") -> int:
	for i in _acts.size():
		if _acts[i]["kind"] == kind and (id == "" or str(_acts[i].get("id", "")) == id):
			return i
	return -2   # (no button: never the card that shakes or glows)


func _padlock(tb: RefCounted, c: Vector2) -> void:
	## A small padlock: what's not open yet.
	var metal := Color(UI.MUTED, 0.85)
	tb.ring(c + Vector2(0, -8.0), 7.0, 2.5, metal, 16)
	tb.rect(Rect2(c.x - 10.0, c.y - 6.0, 20.0, 15.0), metal)
	tb.rect(Rect2(c.x - 1.5, c.y - 1.0, 3.0, 6.0), Color("150f1e"))


func _flask(tb: RefCounted, c: Vector2, id: String, dim: bool) -> void:
	## A small round flask: amber-green for Mother Yarrow's Second Draught,
	## ruby for the Rich Draught; greyed while it's still to come.
	var glass := Color("d8e4f0", 0.30 if dim else 0.55)
	var liquid := Color("9ec85a") if id == "second" else Color("d0463a")
	if dim:
		liquid = Color(liquid.lerp(Color("5a5068"), 0.7), 0.7)
	tb.rect(Rect2(c.x - 6.0, c.y - 30.0, 12.0, 16.0), glass)           # the neck
	tb.rect(Rect2(c.x - 8.0, c.y - 34.0, 16.0, 5.0), Color("8a6a4a", 0.5 if dim else 1.0))   # the cork
	tb.circle(c, 22.0, glass, 24)
	tb.circle(c + Vector2(0, 3.0), 18.0, liquid, 22)
	tb.ellipse(c + Vector2(0, -6.0), 14.0, 3.0, liquid.lightened(0.25), 14)   # its surface
	tb.circle(c + Vector2(-8.0, -9.0), 4.0, Color(1, 1, 1, 0.25 if dim else 0.5), 10)


func _chip(r: Rect2, label: String, v: float) -> void:
	## "DMG +12%": green up, red down, grey even.
	var col: Color = UP if v > 0.0 else (DOWN if v < 0.0 else UI.MUTED)
	var sb := _box("chip", Color.BLACK, Color.BLACK, 11)
	sb.bg_color = Color(col, 0.14)
	sb.border_color = Color(col, 0.7)
	sb.draw(get_canvas_item(), r)
	var n := roundi(v)
	var txt := "%s %s%d%%" % [label, "+" if n > 0 else "-", absi(n)] if n != 0 else "%s  =" % label
	var fs := UI.fit_size(txt, r.size.x - 8.0, 12, 9, "body", 800)   # a narrow chip (a compact card's) shrinks
	var ty := 16.0 if fs == 12 else r.size.y * 0.5 + fs * 0.36
	UI.text(self, Vector2(r.position.x, r.position.y + ty), txt, fs, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 800)


func shelf_bare_text() -> String:
	## The bare shelf's words: every relic found, or (the codex still has
	## some, in worlds not reached yet: the Belt tab shows them as shapes)
	## nothing more this deep.
	for id in Relics.ids():
		if not Game.has_relic(id):
			return "Nothing more this deep. The shelf is bare."
	return "Every relic is found. The shelf is bare."


func _draw_relics() -> void:
	var s := _safe()
	if _stock.is_empty():
		UI.text(self, Vector2(s.position.x, s.get_center().y + 20.0), shelf_bare_text(), 17, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x)
		return
	var cards := _cards()
	var room: bool = Game.belt().size() < Game.belt_slots()
	for i in _stock.size():
		var r: Dictionary = _stock[i]
		var col: Color = UI.RARITY[r["rarity"]]
		var c := _card_frame(cards[i], col, i)
		UI.text(self, Vector2(c.position.x, c.position.y + 18.0), Relics.RARITY_NAME[r["rarity"]], 12, col, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "body", 800)
		var ic := Vector2(c.get_center().x, c.position.y + 58.0)
		draw_circle(ic, 32.0, Color(col, 0.10))
		draw_arc(ic, 32.0, 0.0, TAU, 44, Color(col, 0.4), 1.5)
		var tex := UI.relic_icon(r["id"])
		if tex:
			draw_texture_rect(tex, Rect2(ic - Vector2(28, 28), Vector2(56, 56)), false)
		else:
			_gem(ic, 20.0, col)
		UI.text(self, Vector2(c.position.x, c.position.y + 118.0), r["name"], 19, col, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "title", 700, 4)
		draw_multiline_string(UI.font("body", 600), Vector2(c.position.x + 14.0, c.position.y + 142.0), r["text"], HORIZONTAL_ALIGNMENT_CENTER, c.size.x - 28.0, 14, 3, UI.CREAM)
		var where := "Straight onto your belt" if room else "Into your codex: belt full"
		UI.text(self, Vector2(c.position.x, c.end.y - BTN_H - 18.0), where, 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, "body", 600)


func _draw_sell() -> void:
	## The Sell tab: the squares on the left, the piece shown (or how selling
	## works) on the right, Sell marked under it (a button).
	var s := _safe()
	if not Game.hero_made():
		UI.text(self, Vector2(s.position.x, s.get_center().y + 20.0), "Waxley buys from Wicks with a calling.", 17, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x)
		return
	var sq := squares()
	var marks := TriBatch.new()
	for k in sq.size():
		var r: Rect2 = sq[k]
		var cell: Dictionary = grid_square(k)
		var glow := float(_sq_flash.get(k, 0.0))
		if glow > 0.0:
			var gb := _box("sq_glow", Color(UI.GOLD, 0.3), Color(UI.GOLD, 0.0), 12)
			gb.bg_color = Color(UI.GOLD, 0.35 * glow)
			gb.draw(get_canvas_item(), r.grow(5.0 * glow))
		if cell.has("uid"):
			var it = piece(str(cell["uid"]))
			if not (it is Dictionary):
				continue
			var col: Color = UI.RARITY.get(it["rarity"], UI.CREAM)
			var on := is_marked(it)
			var sb := _box("sq", UI.PANEL, col, 9)
			sb.bg_color = Color("2e2014") if on else UI.PANEL
			sb.border_color = Color(col, 0.75)
			sb.draw(get_canvas_item(), r)
			if on:
				# Marked: its price on a gold tag along the bottom.
				var tag := _box("sq_tag", UI.GOLD, UI.GOLD, 6)
				tag.set_border_width_all(0)
				tag.draw(get_canvas_item(), Rect2(r.position.x + 4.0, r.end.y - 19.0, r.size.x - 8.0, 15.0))
			if str(cell["uid"]) == _pick:
				var ring := _box("sq_pick", Color(0, 0, 0, 0), UI.CREAM, 11)
				ring.set_border_width_all(3)
				ring.draw(get_canvas_item(), r.grow(3.0))
			var look: Dictionary = _looks.get(str(cell["uid"]), {})
			mark_glyph(marks, Vector2(r.end.x - 9.0, r.position.y + 9.0), 5.5, str(look.get("mark", "")))
		elif cell.has("ghost"):
			var gb := _box("sq_ghost", Color("150f1e"), Color(UI.PANEL_EDGE, 0.45), 9)
			gb.draw(get_canvas_item(), r)
		else:
			# An empty place in the satchel: hollow.
			var eb := _box("sq_empty", Color(0.05, 0.04, 0.07, 0.55), Color(UI.PANEL_EDGE, 0.35), 9)
			eb.draw(get_canvas_item(), r)
	for k in sq.size():
		var r: Rect2 = sq[k]
		var cell: Dictionary = grid_square(k)
		if cell.has("uid"):
			var it = piece(str(cell["uid"]))
			if not (it is Dictionary):
				continue
			var on := is_marked(it)
			var tex := UI.tex(Items.icon(it))
			var side := minf(34.0, r.size.y - 26.0)
			if tex:
				draw_texture_rect(tex, Rect2(r.get_center().x - side * 0.5, r.position.y + 5.0, side, side), false)
			if on and _ember_tex:
				draw_texture_rect(_ember_tex, Rect2(r.position.x + 2.0, r.position.y + 2.0, 16, 16), false)
			var price := str(Items.sell_value(it))
			UI.text(self, Vector2(r.position.x, r.end.y - 7.0), price, UI.fit_size(price, r.size.x - 12.0, 13, 10, "body", 800),
					UI.INK if on else UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 800, 0 if on else 3)
		elif cell.has("ghost"):
			var it: Dictionary = cell["ghost"]
			var tex := UI.tex(Items.icon(it))
			if tex:
				draw_texture_rect(tex, Rect2(r.get_center().x - 13.0, r.position.y + 4.0, 26, 26), false, Color(1, 1, 1, 0.25))
			UI.text(self, Vector2(r.position.x, r.end.y - 18.0), "Buy back", UI.fit_size("Buy back", r.size.x - 4.0, 11, 9, "body", 700), UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 700)
			var p := str(int(cell["price"]))
			UI.text(self, Vector2(r.position.x, r.end.y - 5.0), p, 12, Color(UI.GOLD, 0.85), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 800)
	marks.flush(self)   # the corner marks over the icons
	var it = picked()
	if it is Dictionary:
		_draw_sell_piece(sell_panel_rect(), it)
	else:
		_draw_sell_help(sell_panel_rect())


func _draw_sell_piece(p: Rect2, it: Dictionary) -> void:
	## The piece shown, against what's worn: what it is, its chips and mark,
	## its lines; whether it's marked (Wear and Sell +N are buttons below).
	var col: Color = UI.RARITY.get(it["rarity"], UI.CREAM)
	UI.panel(self, p, Color(col, 0.8), UI.PANEL, 12.0)
	var look: Dictionary = _looks.get(str(it["uid"]), Game.sell_look(it))
	var x := p.position.x
	var y := p.position.y
	var ic := Vector2(x + 34.0, y + 38.0)
	var tb := TriBatch.new()
	tb.circle(ic, 24.0, Color(col, 0.12), 24)
	tb.ring(ic, 24.0, 1.5, Color(col, 0.5), 28)
	tb.flush(self)
	var tex := UI.tex(Items.icon(it))
	if tex:
		draw_texture_rect(tex, Rect2(ic - Vector2(20, 20), Vector2(40, 40)), false)
	var tx := x + 68.0
	var tw := p.end.x - 12.0 - tx
	var slot_name: String = Items.SLOT_NAME.get(it["slot"], "")
	var head := "%s  ·  %s  ·  item level %d" % [slot_name, Items.RARITY_NAME[it["rarity"]], int(it["ilvl"])]
	UI.text(self, Vector2(tx, y + 20.0), head, UI.fit_size(head, tw, 12, 10, "body", 800), col, HORIZONTAL_ALIGNMENT_LEFT, tw, "body", 800)
	var name := str(it["name"])
	UI.text(self, Vector2(tx, y + 42.0), name, UI.fit_size(name, tw, 18, 12, "title", 700), col, HORIZONTAL_ALIGNMENT_LEFT, tw, "title", 700, 4)
	var worn = Game.hero()["equip"].get(str(it["slot"]))
	var vs := ("Against your %s" % str(worn["name"])) if worn is Dictionary else "Nothing worn there: it would fill the slot"
	if look.has("legend"):
		vs = "Against your %s: Wear takes its power off" % str(look["legend"])
	UI.text(self, Vector2(tx, y + 59.0), vs, UI.fit_size(vs, tw, 12, 10), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, tw)
	# The chips, and the mark in words.
	var ch: Dictionary = look.get("chips", {})
	var cy := y + 70.0
	_chip(Rect2(x + 12.0, cy, 100.0, 24.0), "DMG", float(ch.get("dmg", 0.0)))
	_chip(Rect2(x + 120.0, cy, 100.0, 24.0), "LIFE", float(ch.get("life", 0.0)))
	var mark := str(look.get("mark", ""))
	# (short: the panel is narrow on the smaller phones; the key says more)
	var words := {"worse": "No better than worn", "trade": "A trade-off", "legendary": "Legendary",
			"better": "Better than worn", "open": "Fills an empty slot"}
	var mw := str(words.get(mark, ""))
	if look.has("legend"):
		mw = "Better numbers, no power"
	var gb := TriBatch.new()
	mark_glyph(gb, Vector2(x + 238.0, cy + 12.0), 6.0, mark)
	gb.flush(self)
	var mx := x + 250.0
	UI.text(self, Vector2(mx, cy + 17.0), mw, UI.fit_size(mw, p.end.x - 10.0 - mx, 12, 9, "body", 700), mark_color(mark), HORIZONTAL_ALIGNMENT_LEFT, p.end.x - 10.0 - mx, "body", 700)
	# Its lines: a Legendary's power first, then the rest in two columns.
	var ly := cy + 42.0
	var bottom := _wear_btn.position.y - 6.0
	var lw := p.size.x - 24.0
	var power: String = Items.LEGENDS.get(str(it.get("legend", "")), {}).get("text", "") if str(it.get("legend", "")) != "" else ""
	if power != "":
		var pl: Array = UI.wrap(power, lw, 12)
		for k in mini(pl.size(), 2):
			UI.text(self, Vector2(x + 12.0, ly), pl[k], 12, Color("ffc080"), HORIZONTAL_ALIGNMENT_LEFT, lw, "body", 700)
			ly += 15.0
	var rest: Array = Items.lines(it).filter(func(l): return l["kind"] == "affix") + Items.lines(it).filter(func(l): return l["kind"] == "implicit")
	var cw := (lw - 12.0) * 0.5
	for k in rest.size():
		var row_y := ly + 15.0 * (k / 2)
		if row_y > bottom - 18.0:
			break
		var txt: String = rest[k]["text"]
		UI.text(self, Vector2(x + 12.0 + (k % 2) * (cw + 12.0), row_y), txt, UI.fit_size(txt, cw, 12, 9), UI.MUTED if rest[k]["kind"] == "implicit" else UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, cw)
	# Marked or kept, left of the buttons.
	var on := is_marked(it)
	var hx := x + 14.0
	var hw := _wear_btn.position.x - 10.0 - hx
	var by := _wear_btn.position.y
	if on and _ember_tex:
		draw_texture_rect(_ember_tex, Rect2(hx - 2.0, by + 4.0, 18, 18), false)
	var top_line := "Marked to sell" if on else "Kept"
	var tip := "Tap it again to keep it" if on else "Tap it again to mark it"
	var off := 20.0 if on else 0.0
	UI.text(self, Vector2(hx + off, by + 18.0), top_line, 14, UI.GOLD if on else UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, hw - off, "body", 800)
	UI.text(self, Vector2(hx, by + 36.0), tip, UI.fit_size(tip, hw, 12, 9), UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, hw)


func _draw_sell_help(p: Rect2) -> void:
	## Nothing shown yet: how selling works, the marks' key.
	UI.panel(self, p, Color(UI.PANEL_EDGE, 0.7), UI.PANEL, 12.0)
	var x := p.position.x + 16.0
	var w := p.size.x - 32.0
	var y := p.position.y
	var n := (Game.hero()["satchel"] as Array).size()
	var title := "Sell to Waxley" if n > 0 else "Nothing to sell"
	UI.text(self, Vector2(x, y + 28.0), title, 19, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, w, "title", 700, 4)
	var sub := "A quarter of his price, paid at once." if n > 0 else "Bring him what you don't wear: a quarter of his price."
	UI.text(self, Vector2(x, y + 48.0), sub, UI.fit_size(sub, w, 13, 10), UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, w)
	var keys := [["better", "Better than what you wear"], ["worse", "No better than what you wear"],
			["trade", "A trade-off (or your Legendary's power lost)"], ["legendary", "Legendary: kept unless you mark it"]]
	var tb := TriBatch.new()
	for k in keys.size():
		mark_glyph(tb, Vector2(x + 6.0, y + 70.0 + 18.0 * k), 5.5, str(keys[k][0]))
	tb.flush(self)
	for k in keys.size():
		var t := str(keys[k][1])
		UI.text(self, Vector2(x + 20.0, y + 75.0 + 18.0 * k), t, UI.fit_size(t, w - 20.0, 12, 9), mark_color(str(keys[k][0])), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, "body", 700)
	var ky := y + 70.0 + 18.0 * keys.size()   # under the marks: the ember tag's line
	if _ember_tex:
		draw_texture_rect(_ember_tex, Rect2(x - 2.0, ky - 7.0, 16, 16), false)
	var m := "Marked: sells with the button below"
	UI.text(self, Vector2(x + 20.0, ky + 5.0), m, UI.fit_size(m, w - 20.0, 12, 9), UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, "body", 700)
	var help := "Tap a piece to see it against what you wear; tap it again to mark or keep it. Sold one by mistake? Tap its ghost to buy it back before you go."
	var hy := ky + 28.0
	var lines: Array = UI.wrap(help, w, 12)
	var fs := 12
	if hy + 15.0 * (lines.size() - 1) > p.end.y - 6.0:
		fs = 11
		lines = UI.wrap(help, w, fs)
	for k in lines.size():
		var ty := hy + (fs + 3) * k
		if ty > p.end.y - 6.0:
			break
		UI.text(self, Vector2(x, ty), lines[k], fs, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT, w)


static func mark_color(mark: String) -> Color:
	match mark:
		"worse":
			return DOWN
		"trade":
			return AMBER
		"legendary":
			return UI.RARITY["legendary"]
		"better":
			return UP
	return UI.MUTED


static func mark_glyph(tb: RefCounted, c: Vector2, r: float, mark: String) -> void:
	## A Sell square's corner mark, drawn (no font has them all), ink-edged:
	## ▼ no better than worn, ◆ a trade-off, ★ a Legendary, ▲ an upgrade.
	var pts := PackedVector2Array()
	match mark:
		"worse":
			pts = PackedVector2Array([c + Vector2(-r, -r * 0.7), c + Vector2(r, -r * 0.7), c + Vector2(0, r * 0.95)])
		"better":
			pts = PackedVector2Array([c + Vector2(0, -r * 0.95), c + Vector2(r, r * 0.7), c + Vector2(-r, r * 0.7)])
		"trade":
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
		"legendary":
			for k in 10:
				var a := -PI * 0.5 + PI * 0.2 * k
				pts.append(c + Vector2(cos(a), sin(a)) * (r * 1.15 if k % 2 == 0 else r * 0.5))
		_:
			return
	var edge := PackedVector2Array()
	for p in pts:
		edge.append(c + (p - c) * ((r + 2.0) / r))
	if mark == "legendary":
		tb.concave(edge, UI.INK)
		tb.concave(pts, mark_color(mark))
	else:
		tb.convex(edge, UI.INK)
		tb.convex(pts, mark_color(mark))


static func draw_badge(b: Control, badge: Dictionary, t: float) -> void:
	## The Shop button's corner mark (Game.shop_badge), on the map and the
	## results: a red "16/16" pill (the satchel full), a green ▲ (an upgrade
	## he can afford), a gold dot (a new Reserve).
	match str(badge.get("kind", "")):
		"full":
			var txt := str(badge.get("text", ""))
			var w := UI.text_width(txt, 11, "body", 800) + 12.0
			var r := Rect2(b.size.x - w + 6.0, -7.0, w, 17.0)
			var sb := UI.box()
			sb.bg_color = DOWN
			sb.border_color = UI.INK
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(8)
			sb.draw(b.get_canvas_item(), r)
			UI.text(b, Vector2(r.position.x, r.position.y + 12.5), txt, 11, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 800)
		"up":
			var tb := UI.batch()
			var c := Vector2(b.size.x - 6.0, 6.0)
			tb.circle(c, 9.0, UI.INK, 18)
			tb.circle(c, 7.5, UP, 18)
			tb.convex(PackedVector2Array([c + Vector2(0, -4.5), c + Vector2(4.5, 3.0), c + Vector2(-4.5, 3.0)]), UI.INK)
			tb.flush(b)
		"new":
			var tb := UI.batch()
			var k := 1.0 + 0.12 * sin(t * 4.0)
			var c := Vector2(b.size.x - 6.0, 6.0)
			tb.circle(c, 7.5 * k, UI.INK, 16)
			tb.circle(c, 6.0 * k, UI.GOLD, 16)
			tb.flush(b)


func _glow(c: Vector2, r: float, strength := 1.0) -> void:
	## Warm candlelight around a flame.
	draw_texture_rect(_glow_tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, strength))


func _flame(tip: Vector2, h: float, lean := 0.0) -> void:
	## A small candle flame standing on its wick at tip.
	var fl := 1.0 + 0.08 * sin(_t * 9.0 + lean * 3.0) + 0.04 * sin(_t * 23.0)
	var top := tip + Vector2(sin(_t * 3.0 + lean) * h * 0.08, -h * fl)
	_shape(PackedVector2Array([top, tip + Vector2(h * 0.3, -h * 0.25), tip + Vector2(0, h * 0.1), tip + Vector2(-h * 0.3, -h * 0.25)]), Color("ffb040"))
	_shape(PackedVector2Array([tip.lerp(top, 0.55), tip + Vector2(h * 0.13, -h * 0.18), tip + Vector2(0, h * 0.02), tip + Vector2(-h * 0.13, -h * 0.18)]), Color("fff0b0"), false)


func _shelf_candle(foot: Vector2, h: float, phase: float) -> void:
	var w := 14.0
	_glow(foot + Vector2(0, -h - 10.0), 46.0)
	_shape(_rect_pts(Rect2(foot.x - w * 0.5, foot.y - h, w, h)), Color("e9dcc0"))
	draw_rect(Rect2(foot.x + w * 0.5 - 4.0, foot.y - h + 1.0, 3.0, h - 2.0), Color("c9b894"))
	_shape(PackedVector2Array([Vector2(foot.x - w * 0.5, foot.y - h), Vector2(foot.x - 1.0, foot.y - h), Vector2(foot.x - 3.0, foot.y - h + 9.0), Vector2(foot.x - w * 0.5, foot.y - h + 6.0)]), Color("fff6e0"), false)
	draw_line(Vector2(foot.x, foot.y - h), Vector2(foot.x, foot.y - h - 4.0), UI.INK, 2.0)
	_flame(Vector2(foot.x, foot.y - h - 4.0), 13.0, phase)


# ---------------------------------------------------------------- icons (when the art isn't there)

func _icon(c: Vector2, r: float, it: Dictionary, col: Color) -> void:
	## A flat, ink-outlined picture of the item's slot, tinted by rarity.
	var metal := Color("c9ced8").lerp(col, 0.35)
	var dark := metal.darkened(0.35)
	match it["slot"]:
		"weapon":
			_weapon_icon(c, r, str(it.get("cls", "knight")), metal, dark, col)
		"candle":
			var body := Rect2(c.x - r * 0.34, c.y - r * 0.3, r * 0.68, r * 1.15)
			_glow(Vector2(c.x, body.position.y - r * 0.45), r * 0.9, 0.8)
			_shape(_rect_pts(body), Color("efe3c8").lerp(col, 0.2))
			draw_rect(Rect2(body.end.x - r * 0.2, body.position.y + 1.0, r * 0.14, body.size.y - 2.0), Color("c9b894").lerp(col, 0.2))
			_shape(PackedVector2Array([body.position, body.position + Vector2(r * 0.34, 0), body.position + Vector2(r * 0.24, r * 0.36), body.position + Vector2(0, r * 0.22)]), Color("fff6e0"), false)
			_shape(_rect_pts(Rect2(c.x - r * 0.62, body.end.y - r * 0.05, r * 1.24, r * 0.2)), dark)
			draw_line(Vector2(c.x, body.position.y), Vector2(c.x, body.position.y - r * 0.14), UI.INK, 2.0)
			_flame(Vector2(c.x, body.position.y - r * 0.14), r * 0.62)
		"coat":
			var pts := PackedVector2Array([
				c + Vector2(-0.3, -0.85) * r, c + Vector2(0.3, -0.85) * r, c + Vector2(0.9, -0.5) * r, c + Vector2(0.78, 0.05) * r,
				c + Vector2(0.5, -0.12) * r, c + Vector2(0.55, 0.9) * r, c + Vector2(-0.55, 0.9) * r, c + Vector2(-0.5, -0.12) * r,
				c + Vector2(-0.78, 0.05) * r, c + Vector2(-0.9, -0.5) * r])
			_shape(pts, metal)
			_shape(PackedVector2Array([c + Vector2(-0.3, -0.85) * r, c + Vector2(0.3, -0.85) * r, c + Vector2(0, -0.45) * r]), dark)
			draw_line(c + Vector2(0, -0.45) * r, c + Vector2(0, 0.9) * r, UI.INK, 2.0)
			for k in 3:
				draw_circle(c + Vector2(0.12, -0.2 + 0.32 * k) * r, 2.2, col)
		"boots":
			var pts := PackedVector2Array([c + Vector2(-0.45, -0.85) * r, c + Vector2(0.15, -0.85) * r, c + Vector2(0.15, 0.25) * r,
				c + Vector2(0.85, 0.45) * r, c + Vector2(0.9, 0.85) * r, c + Vector2(-0.5, 0.85) * r])
			_shape(pts, metal)
			_shape(_rect_pts(Rect2(c + Vector2(-0.5, 0.62) * r, Vector2(1.4, 0.23) * r)), dark)
			_shape(_rect_pts(Rect2(c + Vector2(-0.5, -0.85) * r, Vector2(0.7, 0.22) * r)), col.darkened(0.2))
		_:
			draw_arc(c + Vector2(0, -0.2) * r, r * 0.7, PI * 1.15, PI * 1.85, 16, UI.INK, 2.0)
			draw_circle(c + Vector2(0, 0.25) * r, r * 0.5 + 2.0, UI.INK)
			draw_circle(c + Vector2(0, 0.25) * r, r * 0.5, col.darkened(0.1))
			draw_circle(c + Vector2(-0.16, 0.1) * r, r * 0.16, Color(1, 1, 1, 0.55))


func _weapon_icon(c: Vector2, r: float, cls: String, metal: Color, dark: Color, col: Color) -> void:
	var xf := Transform2D(-PI * 0.25, c)   # drawn upright, shown on the diagonal
	var wood := Color("8a5a3a")
	match cls:
		"witch":
			_shape(xf * _rect_pts(Rect2(-0.08 * r, -0.6 * r, 0.16 * r, 1.65 * r)), wood)
			_shape(xf * PackedVector2Array([Vector2(-0.3, -0.62) * r, Vector2(0.3, -0.62) * r, Vector2(0.18, -0.8) * r, Vector2(-0.18, -0.8) * r]), dark)
			var tip: Vector2 = xf * (Vector2(0, -0.95) * r)
			draw_circle(tip, r * 0.42, Color(1.0, 0.7, 0.3, 0.18))
			_shape(PackedVector2Array([tip + Vector2(0, -0.34) * r, tip + Vector2(0.16, 0.02) * r, tip + Vector2(0, 0.14) * r, tip + Vector2(-0.16, 0.02) * r]), Color("ffb040"))
		"runner":
			_shape(xf * PackedVector2Array([Vector2(0, -0.95) * r, Vector2(0.22, -0.1) * r, Vector2(-0.18, -0.1) * r]), metal)
			_shape(xf * _rect_pts(Rect2(-0.34 * r, -0.12 * r, 0.68 * r, 0.14 * r)), dark)
			_shape(xf * _rect_pts(Rect2(-0.1 * r, 0.02 * r, 0.2 * r, 0.6 * r)), Color("3a2a2a"))
			draw_circle(xf * (Vector2(0, 0.7) * r), r * 0.12, col)
		"founder":
			_shape(xf * _rect_pts(Rect2(-0.08 * r, -0.4 * r, 0.16 * r, 1.4 * r)), wood)
			_shape(xf * _rect_pts(Rect2(-0.5 * r, -0.92 * r, 1.0 * r, 0.52 * r)), metal)
			_shape(xf * _rect_pts(Rect2(-0.5 * r, -0.52 * r, 1.0 * r, 0.12 * r)), dark)
		"sexton":
			_shape(xf * _rect_pts(Rect2(-0.07 * r, -0.2 * r, 0.14 * r, 1.25 * r)), wood)
			_shape(xf * _rect_pts(Rect2(-0.25 * r, 0.95 * r, 0.5 * r, 0.12 * r)), wood.darkened(0.2))
			_shape(xf * PackedVector2Array([Vector2(-0.34, -0.25) * r, Vector2(0.34, -0.25) * r, Vector2(0.3, -0.75) * r, Vector2(0, -1.0) * r, Vector2(-0.3, -0.75) * r]), metal)
		_:
			_shape(xf * PackedVector2Array([Vector2(0, -1.05) * r, Vector2(0.14, -0.88) * r, Vector2(0.14, 0.2) * r, Vector2(-0.14, 0.2) * r, Vector2(-0.14, -0.88) * r]), metal)
			draw_line(xf * (Vector2(0, -0.85) * r), xf * (Vector2(0, 0.15) * r), Color(1, 1, 1, 0.5), 1.5)
			_shape(xf * _rect_pts(Rect2(-0.45 * r, 0.18 * r, 0.9 * r, 0.14 * r)), dark)
			_shape(xf * _rect_pts(Rect2(-0.08 * r, 0.32 * r, 0.16 * r, 0.45 * r)), Color("5a3a2a"))
			draw_circle(xf * (Vector2(0, 0.85) * r), r * 0.12 + 1.5, UI.INK)
			draw_circle(xf * (Vector2(0, 0.85) * r), r * 0.12, col)


func _gem(c: Vector2, r: float, col: Color) -> void:
	_shape(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)]), col)
	_shape(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.05)]), col.lightened(0.35), false)


func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _shape(pts: PackedVector2Array, fill: Color, outline := true) -> void:
	draw_colored_polygon(pts, fill)
	if outline:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, UI.INK, 2.0, true)


func _box(key: String, fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	if not _boxes.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = edge
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(radius)
		_boxes[key] = sb
	return _boxes[key]


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
