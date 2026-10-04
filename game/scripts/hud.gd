extends CanvasLayer
## What's on the glass while playing, laid out inside UI.safe_rect() for a
## 844x390 phone screen:
##   top left    the level badge with the XP filling the gold ring round it,
##               the wax-candle life bar (it melts from the right and its
##               little flame shrinks with life), the calling's resource bar
##               (or pips) under it, and the carried embers (cream; they
##               flash gold when banked)
##   top right   the level's three sigils on a dark tray (the pause button is
##               the touch layer's); the left block sits on a soft dark wash,
##               so a sigil or a monster on a high ledge behind doesn't read
##               as part of the HUD
##   top centre  the boss bar, and under it ONE message slot, shown one at a
##               time for 2.5-5 s (longer lines longer: msg_time) by
##               priority: pickup > elite > bark > toast. A
##               sign's hint takes the slot when it's free. Messages wait
##               while a title card or the level-up card is up.
##   top band    title cards (a level, a Dread, a boss) and the level-up card,
##               one at a time, high over the hero's head and his flame as he
##               stands (play never pauses). The boss bar steps aside while
##               one is up (a boss's grows in after his card). The boss bar,
##               a card or a message he's behind at a jump's top goes
##               see-through (see); the camera keeps him from under the
##               corner blocks (world.gd head_top)
##   bottom      the pickup card between the thumbs: tap it within 3 s to undo
##               an auto-equip or to wear what went to the satchel (a
##               second tap when wearing it melts the worn piece for good);
##               a touch just off a thumb button stays the button's. A
##               Legendary's is a "New power" card held 5 s (power_card)
##   edges       a warm vignette that beats under 25% life
## Everything timed (the slot, the cards, a card's tap window) holds while
## the level is paused, by the pause menu or a story beat played over it.
## The World calls the functions under "World -> HUD"; the touch layer asks
## card_hit() and sends those taps to tap_card(); the equip key calls
## accept_pickup(). Barks come from story.gd (W4) through take_bark().
##
## v3 (contract §5.6, the World calls each only when the HUD has it):
##   mode_pill(state)    a mode's pill where the sigils sit (a mode level has
##                       none), widened to 150 x 26; {} takes it down. state:
##                       {label: "D7", clock: seconds (m:ss.hh), lives: n,
##                       lives_max: n (small candles: Spare Wicks), dots: n
##                       (Hushings), count: "3/5" (a candle beside it), col}
##   dim_ring(on)        a grey ring round the candle bar's flame while any dim
##                       is on, and the flame sputters sideways (never the
##                       low-life flicker: dimmed isn't dying)
##   card(id, t, body)   a card in the top band (queued, 4.5 s); one-time
##                       gating is the caller's (Game.notice), but for the
##                       HUD's own candle-strength card (after 6 snuffs in a
##                       level or 5 at a boss, on Dusk at Normal strength)
##   special_pill(text)  a pill over the Special button ("Hold to give your
##                       flame"); "" takes it down. Never faded.
##   fade_for_finale(on) the HUD fades away for the finale (the pill stays)
##   boss_bar(info)      info.segments ([0.65, 0.30]) splits the bar in three
## The level badge reads 40 with a gold "✦N" under it once Candlemarks land
## (its ring fills toward the next one), and the sigil row hides in a level
## with no sigils. The candle's flame takes the hero's palette (world.hero_flame).
## A gold "+" sits on the badge's shoulder while a skill point waits (the
## next altar offers its Rites; the Sheet opens on Skills). The level-up card
## says what the levels gained gave ("+9% damage · +10% life · +1 skill
## point") and, under it, what just opened or what the next unlock is
## (stats_panel.unlock_at).

const UI := preload("res://scripts/ui.gd")
const Relics := preload("res://scripts/relics.gd")
const Items := preload("res://scripts/items.gd")
const Classes := preload("res://scripts/classes.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const Progression := preload("res://scripts/progression.gd")
const Combat := preload("res://scripts/combat.gd")
const StatsPanel := preload("res://scripts/stats_panel.gd")

const MSG_TIME := 2.5            # a message's least time in the slot...
const MSG_MAX := 5.0             # ...and its most: 1 s and 0.05 s a character between (msg_time)
const PRI := {"pickup": 4, "elite": 3, "bark": 2, "toast": 1}
const STALE := {"pickup": 8.0, "elite": 4.0, "bark": 9.0, "toast": 6.0}   # a queued message older than this is dropped
const CARD_TAP := 3.0            # seconds a pickup card takes a tap
const CARD_POWER := 5.0          # seconds a Legendary's "New power" card holds (power_card)
# A touch this close to a thumb button's centre stays the button's, over the
# card too: within 2.0 x an arrow's radius (a thumb swinging in for "right"
# lands well past its ring), within 1.6 x attack's, jump's and the Special's.
const CARD_CLEAR_MOVE := 2.0
const CARD_CLEAR_BUTTON := 1.6
const LIFE_FONT := 13            # the life numbers' size, down to LIFE_FONT_MIN where the bar is tight
const LIFE_FONT_MIN := 10
const TITLE_TIME := 2.8
const CARD_TIME := 4.5           # a card() in the top band
const STRENGTH_SNUFFS := 6       # snuffs in one level on Dusk before the candle-strength card...
const STRENGTH_BOSS := 5         # ...or at one boss
const STRENGTH_CARD := ["candle_strength", "Candle strength", "The flame can burn gentler. Settings → Candle strength."]
const DIM_GREY := Color("a39cb4")
# The dim ring in W1-W2 too (a douse under a waxfall, a Gutterwing's latch:
# spec §1.7's one dimming pipeline). The one change it makes to the W1-W2
# identity shots (2-1 x 120, doused); false keeps v2's look there.
const DIM_RING_IN_V2 := true
const SEG_MARK := Vector2(4.5, 7.0)   # a segmented boss bar's phase mark: half its width and height (the bar's frame is 14 tall)
const TITLE_CUT := 0.12          # a title card a level-up cuts short fades out this fast, then the level-up comes in
const LEVEL_TIME := 2.2
const LEVEL_LINE_W := 380.0      # the level-up card's two small lines fit this wide (under the left block, clear of the sigils)
const CARD_TOP := 25.0           # a title card starts this far under the safe area's top (its wide name clears the life bar)...
const LEVEL_TOP := 17.0          # ...and the narrower level-up card this far: both end 101 px down, 6 over the flame of a hero on world.gd's feet line
const SEE_THROUGH := 0.3          # what the boss bar, a card or a message keeps of itself while he's behind it (see)
const BARK_GAP := 6.0            # the same bark key at most this often (low_flame asks every tick)
const BADGE_R := 15.0            # the level badge with its XP ring
const FULL_GAP := 6.0            # a "satchel full" card for the same item at most this often
const EVERY := ["tollgrave_angry", "snuffer_angry", "snuffer_dark", "level_up"]   # barks that repeat, if story.gd can't say
const KIND_NAME := {"skeleton": "Rattle", "bat": "Flit", "thornback": "Thornback", "bonebow": "Bonebow",
		"hollow_helm": "Hollow Helm", "helm": "Hollow Helm", "gutterwing": "Gutterwing", "wing": "Gutterwing",
		"dripkin": "Dripkin", "drip": "Dripkin", "brinejaw": "Brinejaw", "jaw": "Brinejaw", "lidlurk": "Lidlurk", "lurk": "Lidlurk"}

var world: Node
var story = null                  # story.gd (W4) or a stand-in; found on first use
var _story_checked := false
var _view: Control
var _t := 0.0
var _vignette: GradientTexture2D

# The left block.
var _life_shown := 1.0            # the wax length drawn (eases to life)
var _life_recent := 1.0           # the molten end still glowing after a hit
var _life_bump := 0.0
var _life_hold := 0.0             # the molten end waits this long before draining
var _res_shown := 0.0
var _xp_shown := 0.0
var _xp_level := 0
var _xp_glow := 0.0
var _ember_bump := 0.0
var _bank_flash := 0.0
var _bank_amount := 0
var _carried_seen := 0
var _sigil_bump := [0.0, 0.0, 0.0]

# The message slot.
var _hint := ""
var _hint_on := false
var _hint_alpha := 0.0
var _msgs: Array = []             # waiting: {kind, pri, key, age, ...}
var _msg := {}                    # showing: the same plus t
var _bark_last := {}              # key -> _t it last played
var _lab_heard := {}              # the feel lab's once-only barks heard this visit (never the save's)
var _full_seen := {}              # item uid -> _t its "satchel full" card last showed
var _elites := {}                 # instance id -> _t announced

# Cards.
var _title := {}                  # {sub, title, t}
var _lvl := {}                    # {n, t, points, from, line (the gains), next (opened or next)}
var _points := 0                  # skill points waiting (the badge's "+")
var _card := {}                   # {kind: item|relic, t, tap_left, ...}
var card_fits := true             # whether the item card's status line fit when last drawn (tests)
var card_line := ""               # the item card's status line when last drawn (tests)
var _cards: Array = []
var _last_relic := {}             # {name, t}: the relic toast world sends too is folded into the card

# The boss.
var _boss := {}
var _boss_in := 0.0
var _see := {"boss": 1.0, "card": 1.0, "msg": 1.0}   # see(): how much of each shows while he's behind it
var _boss_hide := 0.0             # 1 while a title or level-up card has the top band
var _boss_shown := 1.0
var _boss_recent := 1.0
var _boss_seen_t := -100.0        # _t the boss bar was last up (a snuff just after counts as the boss's)

# v3.
var _pill := {}                   # mode_pill(state)
var _dim_on := false
var _dim_k := 0.0                 # the dim ring, eased
var _special_text := ""
var _special_k := 0.0             # the Special's pill, eased
var _special_last := ""           # its words (kept while it fades out)
var _finale := false
var _finale_k := 1.0              # how much of the HUD shows (fade_for_finale)
var slot_drawn := {}               # the message slot's last draw (tests): {on: the layer, kind, a, frame}
var _cardq: Array = []            # card() calls waiting for the top band: {id, title, body}
var _top: Control                 # over the rest, never faded: the Special's pill
var _has_sigils := -1             # the level has sigil entities (-1: not read yet)
var _marks_seen := -1             # Candlemarks when last looked
var _snuffs_seen := 0
var _boss_snuffs := 0
var _strength_asked := false


func _ready() -> void:
	layer = 5
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_hud)
	add_child(_view)
	_top = Control.new()
	_top.name = "Top"
	_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(_draw_top)
	add_child(_top)
	UI.warm()
	# The low-life vignette: clear in the middle, a warm dark red at the rim.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.58, 0.82, 1.0])
	g.colors = PackedColorArray([Color(0.55, 0.1, 0.03, 0.0), Color(0.55, 0.1, 0.03, 0.0), Color(0.6, 0.14, 0.04, 0.45), Color(0.45, 0.06, 0.02, 0.9)])
	_vignette = GradientTexture2D.new()
	_vignette.gradient = g
	_vignette.width = 128
	_vignette.height = 128
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.02, 0.5)
	if world and world.get("player") != null:
		_life_shown = _life_frac()
		_life_recent = _life_shown
		_carried_seen = int(world.get("embers_carried"))
	var xp := _xp()
	_xp_level = int(xp["level"])
	_xp_shown = _ring_frac(xp)
	_marks_seen = int(xp.get("marks", 0))
	if world != null and world.get("snuffs") != null:
		_snuffs_seen = int(world.snuffs)


static func _ring_frac(xp: Dictionary) -> float:
	## What the badge's ring shows: the way to the next level, and at the cap
	## the way to the next Candlemark (full once the last one is in).
	if int(xp.get("level", 1)) >= Progression.CAP:
		if int(xp.get("marks", 0)) >= Progression.MARK_CAP:
			return 1.0
		return clampf(float(xp.get("mark_frac", xp.get("frac", 1.0))), 0.0, 1.0)
	return float(xp.get("frac", 0.0))


# ---------------------------------------------------------------- World -> HUD (v3)

func mode_pill(state: Dictionary) -> void:
	## A mode's pill in the sigils' place ({} takes it down): see the notes
	## at the top for its keys.
	_pill = state.duplicate() if not state.is_empty() and state.get("on", true) else {}


func dim_ring(on: bool) -> void:
	## Any dim on the hero's light (spores, a Hush zone, a douse...): a grey
	## ring round the candle's flame, which sputters sideways meanwhile.
	if on and not DIM_RING_IN_V2 and world != null and int(world.get("world_n") if world.get("world_n") != null else 0) in [1, 2]:
		return
	_dim_on = on


func card(id: String, title: String, body: String) -> void:
	## A card in the top band once it's free (after any title or level-up
	## card), for CARD_TIME. The id says which (the caller gates one-time
	## cards; the same id queued twice shows once).
	for c in _cardq:
		if id != "" and str(c["id"]) == id:
			return
	if id != "" and str(_title.get("id", "-")) == id:
		return
	_cardq.append({"id": id, "title": title, "body": body})


func special_pill(text: String) -> void:
	## The finale's "Hold to give your flame" over the Special button ("" hides).
	_special_text = text
	if text != "":
		_special_last = text


func fade_for_finale(on: bool) -> void:
	## The HUD goes away for the finale's climb and gift (the Special's pill
	## stays), and comes back when it's over.
	_finale = on


func special_pill_rect() -> Rect2:
	## Where the Special's pill draws: over the Special button, inside the
	## safe area, clear of the sigils' corner.
	var L := _touch_layout()
	var s := _safe()
	var t := _special_last if _special_last != "" else "Hold to give your flame"
	var w := UI.text_width(t, 15, "body", 700) + 30.0
	var c: Vector2 = L["special"]
	var h := 30.0
	var y := c.y - float(L["r_special"]) - 14.0 - h
	var x := clampf(c.x - w * 0.5, s.position.x, s.end.x - w)
	return Rect2(x, y, w, h)


func pill_rect() -> Rect2:
	## The mode pill: the sigils' rect widened to the left to 150 x 26.
	var r := _sigils_rect()
	return Rect2(r.end.x - 150.0, r.get_center().y - 13.0, 150.0, 26.0)


func pill_showing() -> bool:
	return not _pill.is_empty()


func finale_alpha() -> float:
	return _finale_k


func has_sigils() -> bool:
	## Whether the level has sigils to show (a mode level has none).
	if _has_sigils < 0:
		var lv = world.get("level") if world != null else null
		if lv != null and lv is Object and lv.has_method("count"):
			_has_sigils = 1 if int(lv.count("sigil")) > 0 else 0
		else:
			return true
	return _has_sigils == 1


# ---------------------------------------------------------------- World -> HUD

func title_card(sub: String, title: String) -> void:
	## A level's, a Dread's or a boss's name in the top band. The level-up
	## card uses the same place: while it's up, this one waits its turn.
	var wait := 0.0
	if not _lvl.is_empty():
		wait = maxf(LEVEL_TIME - float(_lvl["t"]), 0.0)
	if str(_title.get("kind", "")) == "card":
		# A card (v3) gives way to a name, and comes back after it.
		_cardq.push_front({"id": str(_title.get("id", "")), "title": str(_title["title"]), "body": str(_title.get("body", ""))})
	_title = {"sub": sub, "title": title, "t": -wait}


func cut_title() -> void:
	## A showing title card cut short (a mode's own card wants the band): it
	## fades out over TITLE_CUT, as a level-up cuts one. A card (v3) cut
	## before half its time comes back after, as it does for a level-up.
	if _title.is_empty() or float(_title["t"]) < 0.0:
		return
	var tt := _title_time()
	if str(_title.get("kind", "")) == "card" and float(_title["t"]) < tt * 0.5:
		_cardq.push_front({"id": str(_title.get("id", "")), "title": str(_title["title"]), "body": str(_title.get("body", ""))})
	_title["t"] = maxf(float(_title["t"]), tt - TITLE_CUT)


func show_hint(text: String) -> void:
	## The hint of the sign Wick stands by ("" when none): it takes the
	## message slot when nothing else wants it.
	_hint_on = text != ""
	if _hint_on:
		_hint = text


func toast(title: String, sub: String) -> void:
	# A relic's toast (where it goes on): the relic card already says so.
	if not _last_relic.is_empty() and title == _last_relic["name"] and _t - float(_last_relic["t"]) < 1.0:
		return
	_push({"kind": "toast", "key": "toast:" + title + sub, "title": title, "sub": sub})


func banner(text: String) -> void:
	_push({"kind": "toast", "key": "banner:" + text, "title": text, "sub": ""})


func bump_embers() -> void:
	_ember_bump = 1.0


func bump_flames() -> void:
	_life_bump = 1.0


func banked() -> void:
	## Carried embers made safe (an altar, the bell): the count flashes gold.
	_bank_amount = maxi(_carried_seen, 0)
	_bank_flash = 1.0
	_ember_bump = 1.0


func sigil_found(index: int, got: Array) -> void:
	if index >= 0 and index < 3:
		_sigil_bump[index] = 1.0
	var n := 0
	for v in got:
		if v:
			n += 1
	_push({"kind": "pickup", "key": "sigil%d" % index, "title": "Sigil found", "sub": "%d of 3" % n,
			"icon": UI.tex("res://art/props/sigil.svg"), "col": UI.GOLD})


func relic_found(id: String) -> void:
	var r: Dictionary = Relics.get_relic(id)
	_last_relic = {"name": r["name"], "t": _t}
	var on := _game_equipped(id)
	_cards.append({"kind": "relic", "id": id, "on": on, "altar": not on and _relic_ahead(), "t": 0.0, "tap_left": 0.0})


func _relic_ahead() -> bool:
	## A relic found with the belt full: whether a lit altar ahead will offer
	## it (world.relic_ahead); else it goes on from the map's Sheet.
	return world != null and world.has_method("relic_ahead") and bool(world.relic_ahead())


static func relic_status(card: Dictionary) -> String:
	## The relic card's line after its rarity: on the belt, offered at the
	## next altar (the swap card, world.open_relic), or for the map's Sheet.
	if bool(card.get("on", false)):
		return "on your belt"
	return "the next altar offers it" if bool(card.get("altar", false)) else "put it on from the map"


func show_pickup(it: Dictionary, chips: Dictionary, where: String) -> void:
	## An item picked up: worn (auto-equip), in the satchel, or melted into
	## embers: "salvaged" is a Common with auto-salvage on, or (the satchel
	## full) anything no better than what's worn, a Blessed or Rare too.
	## "full": the satchel had no room and it's better (or a Legendary). A
	## tap wears it (what it replaces melts: Game.melt_on_equip). If the
	## World left it on the floor, the tap needs the World to lift it
	## (claim_item), and without that the card only says it's still there;
	## if the World already took it up (world.gd today), the tap is its only
	## chance, as before. "equipped" with Game.last_melt for it: worn, and
	## the full satchel melted the old one, so there's nothing to undo.
	var uid := str(it.get("uid", ""))
	if where == "salvaged":
		var rarity := str(it.get("rarity", "common"))
		var g := _game()
		var auto: bool = rarity == "common" and (g == null or bool(g.setting("auto_salvage")))
		var sub := ("Salvaged  +%d embers" if auto else "Satchel full · salvaged  +%d embers") % Items.salvage_value(it)
		_push({"kind": "pickup", "key": "salv:" + uid, "title": str(it.get("name", "")),
				"sub": sub, "icon": UI.item_icon(it),
				"glyph": UI.slot_glyph(str(it.get("slot", ""))), "col": UI.rarity_color(rarity)})
		return
	var card := {"kind": "item", "item": it, "chips": chips, "where": where, "t": 0.0, "tap_left": CARD_TAP,
			"icon": UI.item_icon(it)}
	var g := _game()
	if where == "equipped" and g != null and str(g.last_melt.get("for", "-")) == uid:
		_melted(card, g.last_melt)
		card["end"] = 3.2
	elif where == "equipped" and g != null and not _can_undo(it):
		# Worn in an empty slot (a first pair of boots, a first charm): there's
		# nothing to swap back to, so it says just "Equipped" and takes no tap.
		card["tap_left"] = 0.0
		card["end"] = 3.2
	elif where == "full":
		# Walking back over it asks again: one card for it at a time.
		if _t - float(_full_seen.get(uid, -100.0)) < FULL_GAP:
			return
		for c in _cards + ([_card] if not _card.is_empty() else []):
			if c.get("kind") == "item" and str(c["item"].get("uid", "-")) == uid:
				return
		_full_seen[uid] = _t
		card["floor"] = _on_floor(it)
		card["melts"] = g != null and not g.melt_on_equip(it).is_empty()
		if card["floor"] and not _can_claim():
			card["tap_left"] = 0.0
			card["end"] = 2.8
	_cards.append(card)


func power_card(it: Dictionary, secs := CARD_POWER) -> void:
	## A Legendary just taken (world.gd _legend_moment): the card show_pickup
	## queued for it becomes a "New power" card, its power large and the
	## chips small, held secs (its tap window stays CARD_TAP), and it doesn't
	## give way early to the cards behind it.
	var uid := str(it.get("uid", "-"))
	for c in _cards + ([_card] if not _card.is_empty() else []):
		if c.get("kind") == "item" and str(c["item"].get("uid", "")) == uid:
			c["power"] = true
			c["hold"] = secs
			if c.has("end"):
				c["end"] = maxf(float(c["end"]), secs)
			return


func _melted(card: Dictionary, melt: Dictionary) -> void:
	## Worn with the satchel full: what melted to make the room, and no undo
	## (the old one is embers now).
	card["melt"] = {"embers": int(melt.get("embers", 0)), "old": bool(melt.get("old", false)),
			"name": str((melt.get("item", {}) as Dictionary).get("name", ""))}
	card["tap_left"] = 0.0


func _can_claim() -> bool:
	## The World can take an item left on the ground (satchel full) off the
	## floor once the card wears it.
	return world != null and world.has_method("claim_item")


func _on_floor(it: Dictionary) -> bool:
	## Whether the World still has this item lying on the floor (a pickup not
	## taken), rather than already taken up.
	var ps = world.get("pickups") if world != null else null
	if not (ps is Array):
		return false
	var uid := str(it.get("uid", "-"))
	for p in ps:
		if p is Dictionary and str(p.get("kind", "")) == "item" and not bool(p.get("taken", false)) \
				and p.get("item") is Dictionary and str(p["item"].get("uid", "")) == uid:
			return true
	return false


func boss_bar(info: Dictionary) -> void:
	## A boss's (or a Warden's) bar: {name, title, frac, phases (v2's ticks)
	## or segments (v3: [0.65, 0.30], the bar in three), awake}.
	if info.is_empty() or not info.get("awake", true):
		_boss = {}
		return
	_boss_seen_t = _t
	if _boss.is_empty():
		_boss_in = 0.0
		_boss_hide = 1.0 if top_card_showing() else 0.0
		_boss_shown = float(info.get("frac", 1.0))
		_boss_recent = _boss_shown
	_boss = info.duplicate()


func level_up(n: int) -> void:
	## "Level up / Level n", what the levels gained bring (their damage and
	## life, skill points, or Vigil ranks once the tree is full, a belt slot
	## when one opens) and under it what they opened (a tier, a root rank)
	## or else the next unlock and its level. Several levels at once (a
	## boss) say it once, for all of them.
	var pts := 0
	var g := _game()
	if g:
		pts = int(g.hero().get("points", 0))
	# The ring still shows the level before (it catches up in _process).
	var from := _xp_level if _xp_level > 0 and _xp_level < n else n - 1
	if not _lvl.is_empty():
		from = mini(int(_lvl.get("from", from)), from)
	var gained := maxi(n - from, 1)
	var line := gains_line(from, n)
	if pts > 0:
		line += " · +%d skill point%s" % [mini(gained, pts), "" if mini(gained, pts) == 1 else "s"]
	elif g:
		line += " · +%d Vigil rank%s" % [gained, "" if gained == 1 else "s"]
	if Progression.belt_slots(n) > Progression.belt_slots(from):
		line += " · a new belt slot"
	var nxt := unlock_line(_cls(), from, n)
	var start := 0.0
	if not _title.is_empty():
		if float(_title["t"]) < 0.0:
			_title["t"] = -LEVEL_TIME   # still waiting on a level-up: wait for this one
		else:
			# A level-up cuts a showing title card short: it fades out over
			# TITLE_CUT, and this card comes in once it has gone, so the two
			# are never drawn over each other. A card (v3, CARD_TIME long) cut
			# before it has had half its time comes back after the level-up.
			var tt := _title_time()
			if str(_title.get("kind", "")) == "card" and float(_title["t"]) < tt * 0.5:
				_cardq.push_front({"id": str(_title.get("id", "")), "title": str(_title["title"]), "body": str(_title.get("body", ""))})
			_title["t"] = maxf(_title["t"], tt - TITLE_CUT)
			start = -(tt - float(_title["t"]))
	_lvl = {"n": n, "t": start, "points": pts, "from": from, "line": line, "next": nxt}


static func gains_line(from: int, n: int) -> String:
	## What levels from+1..n add to every hero: "+9% damage · +10% life"
	## (Combat's 1.09 and 1.10 a level; "+19% damage · +21% life" for two).
	var d := roundi((Combat.p_dmg(n) / Combat.p_dmg(from) - 1.0) * 100.0)
	var l := roundi((Combat.p_hp(n) / Combat.p_hp(from) - 1.0) * 100.0)
	return "+%d%% damage · +%d%% life" % [d, l]


static func unlock_line(cls: String, from: int, n: int) -> Dictionary:
	## The level-up card's second line: {text, now}. What levels from+1..n
	## opened (a tier before a root rank; a belt slot is in the first line),
	## now true: "Now open: the capstones (Tier 3)"; else the next unlock,
	## "Next at level 10: a relic belt slot (4)" (stats_panel's).
	var opened := ""
	for l in range(from + 1, n + 1):
		var what := StatsPanel.unlock_at(cls, l, true)
		if what == "":
			continue
		if opened == "" or what.contains("Tier") or what.contains("capstone"):
			opened = what
	if opened != "":
		return {"text": "Now open: %s" % opened, "now": true}
	var at := StatsPanel.next_unlock_level(cls, n)
	if at > 0:
		return {"text": "Next at level %d: %s" % [at, StatsPanel.unlock_at(cls, at)], "now": false}
	if n >= Progression.CAP:
		return {"text": "Candlemarks from here: +1% damage and life each", "now": false}
	return {}


func xp_tick() -> void:
	_xp_glow = 1.0


func elite_seen(e: Node2D) -> void:
	## An Anointed or a Dread walks into the light: a plate in the message
	## slot with its name, omens and a live life bar. A Dread also gets a card.
	if e == null or str(e.get("tier")) == "":
		return
	if str(e.get("tier")) == "warden":
		return   # a Warden has a boss bar, not a plate (spec §4.6; its omens ride on the bar)
	var id := e.get_instance_id()
	if _elites.has(id) and _t - float(_elites[id]) < 20.0:
		return
	var first := not _elites.has(id)
	_elites[id] = _t
	var tier := str(e.get("tier"))
	var name := str(e.get("elite_name"))
	if name == "":
		name = "%s %s" % [tier.capitalize(), KIND_NAME.get(str(e.get("kind")), str(e.get("kind")).capitalize())]
	var omens: Array = []
	for o in (e.get("omens") if e.get("omens") is Array else []):
		omens.append(str(o).capitalize())
	_push({"kind": "elite", "key": "elite%d" % id, "title": name, "tier": tier, "omens": omens, "ref": weakref(e)})
	if first and tier == "dread":
		# The card's line: "Dread", or what a mode calls it (the Descent's
		# warden rooms: a Deepwarden) through world.mode.dread_title().
		var sub := "Dread"
		var md = world.get("mode") if world != null else null
		if md != null and md.has_method("dread_title"):
			var dt := str(md.dread_title())
			if dt != "":
				sub = dt
		title_card(sub, name)
	bark("first_dread" if tier == "dread" else "first_elite")


func bark(key: String) -> void:
	## A line from story.gd for this key, in the slot with its speaker's face.
	if _t - float(_bark_last.get(key, -100.0)) < BARK_GAP:
		return
	_bark_last[key] = _t
	var line := _bark_line(key)
	if line.is_empty() or str(line.get("text", "")) == "":
		return
	var who := str(line.get("who", "taper"))
	var mood := str(line.get("mood", ""))
	var cls := _cls()
	# story.gd's own face for the line (the CAST face alias: the six Lost
	# Wicks share echo_glow), else the speaker's by mood.
	var path := str(line.get("portrait", ""))
	if path == "" or not ResourceLoader.exists(path):
		path = UI.portrait_path(who, mood, cls)
	# (drawn at radius 17: the portrait's 128 px copy, never the scenes' 768)
	var face: Texture2D = UI.tex(UI.hud_face(path)) if path != "" else null
	var uv := Rect2(0, 0, 1, 1)
	if face == null and who == "wick":
		var f := UI.hero_face(cls, "happy" if mood == "" else mood)
		face = f["tex"]
		uv = f["uv"]
	# (with no face drawn, the speaker's initial: the hero's own name's for his)
	var nm := str(line.get("name", ""))
	_push({"kind": "bark", "key": "bark:" + key, "text": str(line["text"]), "who": who, "tex": face, "uv": uv,
			"col": UI.speaker_color(who, cls), "letter": (nm if nm != "" else who).substr(0, 1).to_upper()})


# ---------------------------------------------------------------- touch -> HUD

func card_rect() -> Rect2:
	## Where the pickup card is (empty when none is up): the touch layer
	## hit-tests it before the move / right-hand split.
	if _card.is_empty():
		return Rect2()
	return card_slot()


func card_hit(pos: Vector2) -> bool:
	## Whether a touch here is the card's: only an item card inside its tap
	## window claims one. A relic card, or one fading out, lets the thumb
	## through to the move zone and the buttons under it. The card sits
	## between the thumbs' buttons (on the phone its edge is a few px from
	## attack and the right arrow), so a press near a button (clear_of_thumbs)
	## is still that button's: a right thumb reaching for attack swings, a
	## left one running right runs, rather than tapping the card (a tap can
	## take off an item just worn).
	if _card.is_empty() or _card["kind"] != "item" or float(_card["tap_left"]) <= 0.0:
		return false
	if not card_rect().grow(4.0).has_point(pos):
		return false
	return clear_of_thumbs(pos, _touch_layout())


static func clear_of_thumbs(pos: Vector2, L: Dictionary) -> bool:
	## Whether a touch here is far enough from every thumb button to be the
	## card's: CARD_CLEAR_MOVE x the arrows' radius, CARD_CLEAR_BUTTON x
	## attack's, jump's and the Special's, from their centres.
	for b in ["left", "right", "attack", "jump", "special"]:
		var move: bool = b in ["left", "right"]
		var rad := float(L["r_move"] if move else L["r_" + b])
		if pos.distance_to(L[b]) < rad * (CARD_CLEAR_MOVE if move else CARD_CLEAR_BUTTON):
			return false
	return true


func tap_card(confirm_melt := false) -> bool:
	## A tap on the pickup card inside its window: undo an auto-equip, or wear
	## an item that went to the satchel. Tapping again flips it back.
	## confirm_melt (a touch, the equip key): when wearing it would melt the
	## worn piece for good (the satchel full), the first tap only asks ("tap
	## again") and renews the window; a second tap wears it.
	if _card.is_empty() or _card["kind"] != "item" or float(_card["tap_left"]) <= 0.0:
		return false
	var it: Dictionary = _card["item"]
	var g := _game()
	if confirm_melt and not bool(_card.get("armed", false)) and str(_card["where"]) in ["satchel", "full", "undone"] \
			and g != null and not g.melt_on_equip(it).is_empty():
		if str(_card["where"]) == "full" and bool(_card.get("floor", false)) and not _can_claim():
			return false
		_card["armed"] = true
		_card["tap_left"] = CARD_TAP
		_card["flash"] = 1.0
		_sfx("select")
		return true
	match str(_card["where"]):
		"equipped":
			if world and world.has_method("undo_equip"):
				world.undo_equip(it)
			if _worn(it):
				# Nothing to swap back to (the slot was empty): it stays on.
				_card["tap_left"] = 0.0
				_sfx("back")
				return false
			_card["where"] = "undone"
		"satchel", "full", "undone":
			if str(_card["where"]) == "full" and bool(_card.get("floor", false)):
				# Still on the ground: the World lifts it off the floor.
				if not _can_claim():
					return false
				world.claim_item(it)
			if g:
				g.equip(it)
			if world and world.has_method("apply_hero"):
				world.apply_hero()
			_card["where"] = "equipped"
			if g and str(g.last_melt.get("for", "-")) == str(it.get("uid", "")):
				# The satchel was full: the old one melted, so no flipping back.
				_melted(_card, g.last_melt)
				_card["end"] = float(_card["t"]) + 2.6
				_card["flash"] = 1.0
				_sfx("equip")
				return true
		_:
			return false
	_card["tap_left"] = CARD_TAP
	_card["flash"] = 1.0
	_sfx("equip")
	return true


func _can_undo(it: Dictionary) -> bool:
	## An auto-equip can be undone: the satchel holds another piece for that
	## slot (what world.gd undo_equip swaps back to).
	var g := _game()
	if g == null:
		return true
	for o in g.hero().get("satchel", []):
		if o is Dictionary and str(o.get("slot", "")) == str(it.get("slot", "")) and str(o.get("uid", "")) != str(it.get("uid", "-")):
			return true
	return false


func _worn(it: Dictionary) -> bool:
	var g := _game()
	if g == null:
		return false
	var on = g.hero().get("equip", {}).get(str(it.get("slot", "")))
	return on is Dictionary and str(on.get("uid", "")) == str(it.get("uid", "-"))


func accept_pickup() -> bool:
	## The equip key (R / Enter): the same as tapping the card.
	return tap_card(true)


# ---------------------------------------------------------------- layout

func _safe() -> Rect2:
	return UI.safe_rect(_view.get_viewport())


func _vs() -> Vector2:
	return _view.get_size()


func layout() -> Dictionary:
	## Every fixed rect the HUD draws (tests check they stay inside the safe
	## area and clear of each other and the touch buttons).
	var s := _safe()
	var x0 := s.position.x
	var y0 := s.position.y
	var life := Rect2(x0 + 36.0, y0 + 8.0, 150.0, 16.0)
	var badge := Rect2(x0, life.get_center().y - BADGE_R, BADGE_R * 2.0, BADGE_R * 2.0)
	var out := {
		"badge": badge,
		"life": Rect2(life.position.x, life.position.y - 5.0, life.size.x + 4.0, life.size.y + 5.0),   # with the flame rising over it
		"life_bar": life,
		"xp": badge,   # the XP is the ring round the level badge
		"marks": Rect2(x0, badge.end.y + 3.0, badge.size.x + 4.0, 15.0),   # "✦3" under the badge, past level 40
		"res": Rect2(life.position.x, life.end.y + 6.0, 110.0, 7.0),
		"embers": Rect2(life.position.x - 2.0, life.end.y + 16.0, 110.0, 18.0),
		"sigils": pill_rect() if pill_showing() else _sigils_rect(),   # the mode pill takes the sigils' place
		"boss": boss_rect(),
		"boss_label": Rect2(boss_rect().position.x, boss_rect().position.y - 20.0, boss_rect().size.x, 18.0),
		"msg": msg_rect(99999.0),
		"msg_boss": msg_rect(99999.0, true),
		"card": card_slot(),
	}
	return out


func points_pip_rect(L := {}) -> Rect2:
	## The badge's gold "+" while a skill point waits: on its upper right
	## shoulder, inside the safe area and the left block's wash.
	var b: Rect2 = (L if not L.is_empty() else layout())["badge"]
	return Rect2(b.get_center() + Vector2(11.0, -8.0) - Vector2(6.5, 6.5), Vector2(13.0, 13.0))


func points_waiting() -> int:
	## The skill points the badge's "+" stands for (0: none showing).
	return _points


func _sigils_rect() -> Rect2:
	var s := _safe()
	return Rect2(s.end.x - 50.0 - 3 * 25.0, s.position.y + 9.0, 3 * 25.0, 22.0)


func boss_rect() -> Rect2:
	## The boss bar, centred under the top band. With a mode pill up (a
	## Waxworks fight) it narrows so its name and title stay clear of the pill.
	var s := _safe()
	var w := _vs().x * 0.44
	if pill_showing():
		w = minf(w, 2.0 * (pill_rect().position.x - 10.0 - s.get_center().x))
	return Rect2(s.get_center().x - w * 0.5, s.position.y + 44.0, w, 10.0)


func msg_rect(content_w: float, boss_on := false) -> Rect2:
	## The message slot for a message this wide: centred under the boss bar,
	## never reaching over the left block. In the finale it sits low, between
	## the thumbs (the rev5 review: at the stair's top Waxby stands under the
	## top band, so the Hush's lines, the @give line and "quiet at last" drew
	## see-through, over the flame he was giving).
	var s := _safe()
	if _finale:
		var g := _thumb_gap()
		var room := maxf(float(g[1]) - float(g[0]), 150.0)
		var fw := clampf(content_w, 150.0, room)
		var fcx := clampf(_vs().x * 0.5, float(g[0]) + fw * 0.5, float(g[1]) - fw * 0.5)
		return Rect2(fcx - fw * 0.5, s.end.y - 88.0, fw, 44.0)
	var cx := s.get_center().x
	var y := s.position.y + (64.0 if boss_on else 40.0)
	var clear_left := s.position.x + 152.0
	var max_w := minf(2.0 * (cx - clear_left), _vs().x * 0.62)
	var w := clampf(content_w, 150.0, max_w)
	return Rect2(cx - w * 0.5, y, w, 44.0)


func _thumb_gap() -> Array:
	## [left, right]: the room between the thumbs' buttons (view px).
	var L := _touch_layout()
	var left_edge: float = maxf(L["left"].x, L["right"].x) + float(L["r_move"]) + 6.0
	var right_edge: float = minf(L["attack"].x - float(L["r_attack"]), L["jump"].x - float(L["r_jump"])) - 6.0
	return [left_edge, right_edge]


func card_slot() -> Rect2:
	## The pickup card's place: bottom centre, between the thumbs' buttons
	## (x 260-580 and y b-100..b-10 on an 844-wide screen), narrower if the
	## buttons are bigger.
	var s := _safe()
	var g := _thumb_gap()
	var left_edge: float = g[0]
	var right_edge: float = g[1]
	var w := minf(320.0, right_edge - left_edge)
	var cx := clampf(_vs().x * 0.5, left_edge + w * 0.5, right_edge - w * 0.5)
	return Rect2(cx - w * 0.5, s.end.y - 100.0, w, 90.0)


func title_showing() -> bool:
	## A title card on the glass (not one still waiting on the level-up card).
	return not _title.is_empty() and float(_title["t"]) >= 0.0


func top_card_showing() -> bool:
	## A title card or the level-up card has the top band.
	return title_showing() or not _lvl.is_empty()


func slot_blocked() -> bool:
	## The message slot draws nothing now: a title card (showing or waiting
	## its turn) or the level-up card is up (_draw_slot). A sign's linger
	## waits it out (world._read_signs).
	return not _title.is_empty() or not _lvl.is_empty()


func hint_held() -> bool:
	## A sign's hint can't draw now: the slot is blocked, a message has it,
	## or one waits to take it on the next step (_step_messages runs before a
	## title card goes, so a bark queued under the title shows a frame late:
	## the hint never flashes up for that frame). world._read_signs holds a
	## sign's linger while this is true, so its text reads after the bark.
	return slot_blocked() or not _msg.is_empty() or not _msgs.is_empty()


func hint_showing() -> bool:
	## The slot draws the sign's hint now (_draw_slot; tests).
	return _hint_alpha > 0.0 and _hint != "" and not hint_held()


func boss_alpha() -> float:
	## How much of the boss bar shows (tests): none while it steps aside,
	## see-through while he's behind it.
	return 0.0 if _boss.is_empty() else clampf(_boss_in * 2.0, 0.0, 1.0) * (1.0 - _boss_hide) * see("boss")


func title_alpha() -> float:
	if _title.is_empty():
		return 0.0
	var tt: float = _title["t"]
	return clampf(tt * 3.0, 0.0, 1.0) * clampf((_title_time() - tt) * 2.0, 0.0, 1.0) * see("card")


func _title_time() -> float:
	return CARD_TIME if str(_title.get("kind", "")) == "card" else TITLE_TIME


func level_alpha() -> float:
	## How much of the level-up card shows (tests): none while it waits.
	if _lvl.is_empty():
		return 0.0
	var tt: float = _lvl["t"]
	return clampf(tt * 5.0, 0.0, 1.0) * clampf((LEVEL_TIME - tt) * 2.5, 0.0, 1.0) * see("card")


func see(k: String) -> float:
	## How much of a piece of the top band shows: all of it, or SEE_THROUGH
	## while Waxby is behind it (a jump's top under the boss bar, a card or
	## a message), eased. "boss", "card" or "msg". The corner blocks never
	## need it: the camera keeps him out from under them (world.gd head_top).
	return float(_see.get(k, 1.0))


func see_areas() -> Dictionary:
	## Where each see-through piece draws (view px).
	var b := boss_rect()
	var t := title_rect(str(_title.get("title", ""))) if not _title.is_empty() else Rect2()
	if str(_title.get("kind", "")) == "card":
		t = band_card_rect(str(_title.get("title", "")), str(_title.get("body", "")))
	return {"boss": Rect2(b.position.x, b.position.y - 20.0, b.size.x, b.size.y + 20.0),
			"card": t.merge(level_rect()) if t.has_area() else level_rect(),
			"msg": msg_rect(99999.0, not _boss.is_empty())}


func _step_see(dt: float) -> void:
	var h := Rect2()
	if world != null and world.has_method("hero_view_rect") and world.get("player") != null and world.player.alive:
		# (Not the last 3 px of his flame's tip, a point: a boss fight's
		# message slot ends 1 px under it on the feet line.)
		h = (world.hero_view_rect() as Rect2).grow_individual(0.0, -3.0, 0.0, 0.0)
	var A := see_areas()
	for k in _see:
		var behind: bool = h.has_area() and h.intersects(A[k])
		if _finale and k == "msg":
			behind = false   # (the finale's lines are read whole)
		_see[k] = move_toward(float(_see[k]), SEE_THROUGH if behind else 1.0, dt * 6.0)


func title_rect(title := "The Drowned Chandlery") -> Rect2:
	## Where a title card draws (tests): its line, its 40 px name and the
	## rule under them, in the top band. Clear of the left block, the sigils
	## and pause at the corners, and high over the hero's flame.
	var vs := _vs()
	var y := _safe().position.y + CARD_TOP
	var w := maxf(UI.text_width(title, 40, "title", 700), 180.0) + 16.0
	return Rect2(vs.x * 0.5 - w * 0.5, y, w, 76.0)


func level_rect() -> Rect2:
	## Where the level-up card's words draw (tests): the same top band.
	var vs := _vs()
	return Rect2(vs.x * 0.5 - 150.0, _safe().position.y + LEVEL_TOP, 300.0, 84.0)


func _touch_layout() -> Dictionary:
	## The touch buttons' centres and radii (the World's touch layer, else
	## the default layout for this safe area).
	var t = world.get("touch") if world != null else null
	if t != null and t.has_method("layout") and t.is_inside_tree():
		return t.layout()
	return TouchScript.layout_for(_safe(), 1.0)


# ---------------------------------------------------------------- the step

func _process(dt: float) -> void:
	_t += dt
	var target := _life_frac()
	# The wax eases to life; the molten end lingers, then drains.
	if target < _life_shown - 0.0005:
		_life_recent = maxf(_life_recent, _life_shown)
		_life_shown = target
		_life_hold = 0.3
	else:
		_life_shown = move_toward(_life_shown, target, dt * 1.2)
	_life_hold = maxf(_life_hold - dt, 0.0)
	if _life_hold <= 0.0:
		_life_recent = move_toward(_life_recent, _life_shown, dt * 0.9)
	_life_recent = maxf(_life_recent, _life_shown)
	_life_bump = maxf(_life_bump - dt * 3.0, 0.0)
	_res_shown = lerpf(_res_shown, _res_frac(), 1.0 - exp(-dt * 12.0))
	var xp := _xp()
	var marks := int(xp.get("marks", 0))
	if _marks_seen < 0:
		_marks_seen = marks
	if int(xp["level"]) > _xp_level:
		_xp_shown = move_toward(_xp_shown, 1.0, dt * 2.5)
		if _xp_shown >= 1.0:
			_xp_shown = 0.0
			_xp_level = int(xp["level"])
	elif marks > _marks_seen:
		# A Candlemark: the ring fills, glints, and starts on the next one.
		_xp_shown = move_toward(_xp_shown, 1.0, dt * 2.5)
		if _xp_shown >= 1.0:
			_xp_shown = 0.0
			_marks_seen = marks
			_xp_glow = 1.0
			toast("Candlemark %d" % marks, "+1% damage and life")
			_sfx("candlemark")   # (A7's; level_up until it's rendered)
	else:
		_xp_level = int(xp["level"])
		_marks_seen = marks
		_xp_shown = move_toward(_xp_shown, _ring_frac(xp), dt * 1.5)
	_xp_glow = maxf(_xp_glow - dt * 2.0, 0.0)
	var g := _game()
	_points = int(g.hero().get("points", 0)) if g != null and not (g.has_method("borrowing") and g.borrowing()) else 0
	_ember_bump = maxf(_ember_bump - dt * 5.0, 0.0)
	_bank_flash = maxf(_bank_flash - dt * 0.8, 0.0)
	if world != null and world.get("embers_carried") != null:
		_carried_seen = int(world.embers_carried)
	for i in 3:
		_sigil_bump[i] = maxf(_sigil_bump[i] - dt * 2.0, 0.0)
	_hint_alpha = move_toward(_hint_alpha, 1.0 if _hint_on else 0.0, dt * 5.0)
	if _hint_alpha <= 0.0 and not _hint_on:
		_hint = ""
	# While the level is paused (the pause menu, a story beat over the level)
	# the timed things hold: a pickup card keeps its tap window, messages
	# keep their turn and cards their time. Only the looks above keep going.
	var paused: bool = world != null and world.get("paused") == true
	if not paused:
		_step_messages(dt)
		_step_cards(dt)
		if not _title.is_empty():
			_title["t"] += dt
			if _title["t"] > _title_time():
				_title = {}
		if not _lvl.is_empty():
			_lvl["t"] += dt
			if _lvl["t"] > LEVEL_TIME:
				_lvl = {}
		if _title.is_empty() and _lvl.is_empty() and not _cardq.is_empty():
			var c: Dictionary = _cardq.pop_front()
			_title = {"kind": "card", "id": c["id"], "sub": "", "title": c["title"], "body": c["body"], "t": 0.0}
		if InputMap.has_action("equip") and Input.is_action_just_pressed("equip"):
			accept_pickup()
		_step_strength()
	_step_boss(dt)
	_step_see(dt)
	_dim_k = move_toward(_dim_k, 1.0 if _dim_on else 0.0, dt * 4.0)
	_special_k = move_toward(_special_k, 1.0 if _special_text != "" else 0.0, dt * 4.0)
	_finale_k = move_toward(_finale_k, 0.0 if _finale else 1.0, dt / 1.2)
	_view.modulate.a = _finale_k
	_view.queue_redraw()
	_top.queue_redraw()


func _step_strength() -> void:
	## The candle-strength card (spec §10, once a save): after STRENGTH_SNUFFS
	## snuffs in one level, or STRENGTH_BOSS at one boss, on Dusk at Normal
	## strength, outside a mode.
	if world == null or _strength_asked or world.get("snuffs") == null or _in_lab():
		return   # (never in the feel lab: it writes nothing, and the card's notice would)
	var n := int(world.snuffs)
	if n <= _snuffs_seen:
		return
	var at_boss := not _boss.is_empty() or _t - _boss_seen_t < 2.0
	if at_boss:
		_boss_snuffs += n - _snuffs_seen
	_snuffs_seen = n
	if n < STRENGTH_SNUFFS and _boss_snuffs < STRENGTH_BOSS:
		return
	var g := _game()
	if g == null or not g.has_method("notice") or world.get("mode") != null:
		return
	if str(world.get("diff")) != "dusk" or str(g.setting("candle_strength")) != "normal":
		return
	_strength_asked = true
	if g.notice(STRENGTH_CARD[0]):
		card(STRENGTH_CARD[0], STRENGTH_CARD[1], STRENGTH_CARD[2])


func _push(m: Dictionary) -> void:
	m["pri"] = PRI.get(m["kind"], 1)
	m["age"] = 0.0
	m["t"] = 0.0
	m["dur"] = msg_time(m)
	var key: String = m.get("key", "")
	if key != "":
		if _msg.get("key", "-") == key:
			return
		for q in _msgs:
			if q.get("key", "") == key:
				return
	_msgs.append(m)
	if _msgs.size() > 8:
		_msgs.sort_custom(func(a, b): return a["pri"] > b["pri"] or (a["pri"] == b["pri"] and a["age"] > b["age"]))
		_msgs.resize(8)


static func msg_time(m: Dictionary) -> float:
	## How long a message holds the slot: a longer line longer (1 s and
	## 0.05 s a character, MSG_TIME to MSG_MAX), so a 70-character bark is
	## read to its end. A bark by its line, a note by its title and line, an
	## elite's plate by its name.
	var words := str(m.get("text", ""))
	if words == "":
		words = (str(m.get("title", "")) + " " + str(m.get("sub", ""))).strip_edges()
	return clampf(1.0 + 0.05 * words.length(), MSG_TIME, MSG_MAX)


func _msg_dur() -> float:
	## The showing message's time (one put in by hand, without _push: MSG_TIME).
	return float(_msg.get("dur", MSG_TIME))


func _next_msg() -> int:
	## The waiting message to show next: the highest priority, then the oldest.
	var best := -1
	for i in _msgs.size():
		var q: Dictionary = _msgs[i]
		if best < 0 or q["pri"] > _msgs[best]["pri"] or (q["pri"] == _msgs[best]["pri"] and q["age"] > _msgs[best]["age"]):
			best = i
	return best


func _step_messages(dt: float) -> void:
	for q in _msgs:
		q["age"] += dt
	_msgs = _msgs.filter(func(q): return q["age"] < float(STALE.get(q["kind"], 6.0)))
	if not _title.is_empty() or not _lvl.is_empty():
		return   # messages wait while a title card (or the level-up card) is up
	if not _msg.is_empty():
		_msg["t"] += dt
		# Something more important cuts this one short (once it's been read a bit).
		var nb := _next_msg()
		var dur := _msg_dur()
		if nb >= 0 and _msgs[nb]["pri"] > _msg["pri"] and _msg["t"] > 0.8 and _msg["t"] < dur - 0.3:
			_msg["t"] = dur - 0.3
		if _msg["t"] >= dur:
			_msg = {}
	if _msg.is_empty():
		var i := _next_msg()
		if i >= 0:
			_msg = _msgs[i]
			_msgs.remove_at(i)
			_msg["t"] = 0.0


func _step_cards(dt: float) -> void:
	if _card.is_empty() and not _cards.is_empty():
		_card = _cards.pop_front()
	if _card.is_empty():
		return
	_card["t"] += dt
	_card["flash"] = maxf(float(_card.get("flash", 0.0)) - dt * 3.0, 0.0)
	if _card["kind"] == "item":
		# Up while it takes a tap (a tap renews that), then it fades. Others
		# waiting: it gives way after 1.6 s, unless it's waiting on the
		# second tap that wears it (the first asked).
		_card["tap_left"] = maxf(float(_card["tap_left"]) - dt, 0.0)
		if not _cards.is_empty() and _card["t"] > 1.6 and not bool(_card.get("armed", false)):
			_card["tap_left"] = 0.0
		if float(_card["tap_left"]) <= 0.0 and not _card.has("end"):
			_card["end"] = maxf(_card["t"] + 0.4, float(_card.get("hold", 0.0)))   # (a "New power" holds)
	else:
		if not _card.has("end"):
			_card["end"] = 3.2
		if not _cards.is_empty():
			_card["end"] = minf(float(_card["end"]), maxf(_card["t"], 1.6) + 0.3)
	if _card.has("end") and _card["t"] >= float(_card["end"]):
		_card = {}


func _step_boss(dt: float) -> void:
	if _boss.is_empty():
		return
	var b = world.get("boss") if world != null else null
	if b != null and is_instance_valid(b) and b.has_method("boss_info"):
		var info: Dictionary = b.boss_info()
		_boss["frac"] = info.get("frac", _boss.get("frac", 1.0))
		if not info.get("awake", true):
			_boss = {}
			return
	# The bar steps aside while a title or level-up card is up (they're drawn
	# where it is), and grows in once the boss's own card, as he wakes, has gone.
	var aside := top_card_showing()
	_boss_hide = move_toward(_boss_hide, 1.0 if aside else 0.0, dt * 6.0)
	if not aside:
		_boss_in = minf(_boss_in + dt * 2.5, 1.0)
	var f := float(_boss.get("frac", 1.0))
	if f < _boss_shown:
		_boss_recent = maxf(_boss_recent, _boss_shown)
	_boss_shown = f
	_boss_recent = move_toward(_boss_recent, _boss_shown, dt * 0.5)


# ---------------------------------------------------------------- reading the world

func _game() -> Node:
	return get_node_or_null("/root/Game") if is_inside_tree() else null


func _game_equipped(id: String) -> bool:
	var g := _game()
	return g != null and g.equipped(id)


func _cls() -> String:
	var p = world.get("player") if world != null else null
	if p != null and p.get("stats") is Dictionary and p.stats.has("cls"):
		return str(p.stats["cls"])
	var g := _game()
	return str(g.hero()["cls"]) if g else "knight"


func _life_frac() -> float:
	var p = world.get("player") if world != null else null
	if p == null:
		return 1.0
	return clampf(float(p.hp) / maxf(float(p.max_hp), 1.0), 0.0, 1.0)


func _res_frac() -> float:
	var p = world.get("player") if world != null else null
	if p == null:
		return 0.0
	return clampf(float(p.res) / maxf(float(p.res_max), 0.001), 0.0, 1.0)


func _xp() -> Dictionary:
	var g := _game()
	if g == null:
		return {"level": 1, "into": 0, "need": 80, "frac": 0.0}
	return g.xp_progress()


func _story():
	if not _story_checked:
		_story_checked = true
		if story == null and ResourceLoader.exists("res://scripts/story.gd"):
			story = load("res://scripts/story.gd")
	return story


func _in_lab() -> bool:
	return world != null and world.has_method("is_lab") and bool(world.is_lab())


func _bark_line(key: String) -> Dictionary:
	## {who, mood, text} from story.gd, or {} for nothing to say. W4's
	## take_bark(key, cls) does it all (the line, and the once-only gate). An
	## older story.gd: its "every" barks skip the once gate, the rest pass
	## bark_once(key); then bark_line(key, cls), else its BARKS table
	## ["who:mood", "text"]. With neither gate, EVERY here says which repeat.
	var st = _story()
	if st == null:
		return {}
	var cls := _cls()
	if st.has_method("take_bark"):
		if _in_lab():
			# The feel lab writes nothing to the save (decisions.md): its
			# once-only lines play once a visit, marked here, not in the slot.
			if _lab_heard.has(key):
				return {}
			var tl = st.take_bark(key, cls, false)
			if tl is Dictionary and not (tl as Dictionary).is_empty() and not bool(st.bark_every(key)):
				_lab_heard[key] = true
			return tl if tl is Dictionary else {}
		var t = st.take_bark(key, cls)
		return t if t is Dictionary else {}
	var every: bool = bool(st.bark_every(key)) if st.has_method("bark_every") else EVERY.has(key)
	if not every:
		if st.has_method("bark_once"):
			if not st.bark_once(key):
				return {}
		else:
			var g := _game()
			if g:
				if g.seen("bark:" + key):
					return {}
				g.mark_seen("bark:" + key)
	if st.has_method("bark_line"):
		var d = st.bark_line(key, cls)
		return d if d is Dictionary else {}
	var consts: Dictionary = st.get_script_constant_map() if st is Script else {}
	var barks: Dictionary = consts.get("BARKS", {})
	if not barks.has(key):
		return {}
	var e: Array = barks[key]
	var text: String = str(e[1]) if e.size() > 1 else ""
	if text.begins_with("@"):
		return {}
	var wm: PackedStringArray = str(e[0]).split(":")
	return {"who": wm[0], "mood": wm[1] if wm.size() > 1 else "", "text": text}


func _sfx(name: String) -> void:
	var s := get_node_or_null("/root/Sfx") if is_inside_tree() else null
	if s:
		s.play(name)


# ---------------------------------------------------------------- drawing

func _warm_glyphs(ci: CanvasItem) -> void:
	## The text the HUD first draws mid-play (UI.GLYPH_WARM: the level-up card's
	## "Level N" at 42 px with its 8 px outline was a new glyph cache, ~12 MB,
	## 30 ms on the Mac, the first time a hero levelled; an elite's plate, a
	## Dread's card, the barks and the cards likewise), a chunk a frame. The
	## title warms it first; here only what's left (a level first, --autoplay).
	UI.warm_glyphs(ci)


func _draw_hud() -> void:
	if world == null or world.get("player") == null:
		return
	var ci := _view
	var vs := _vs()
	if UI.glyph_step < UI.GLYPH_WARM.size():
		_warm_glyphs(ci)
	var f := _life_frac()
	if f < 0.25 and f > 0.0:
		_draw_vignette(ci, vs, f)
	var L := layout()
	_draw_backing(ci)
	_draw_life(ci, L, f)
	_draw_resource(ci, L)
	_draw_embers(ci, L)
	if pill_showing():
		_draw_pill(ci, L["sigils"])
	elif has_sigils():
		_draw_sigils(ci, L)
	if not _boss.is_empty():
		_draw_boss(ci)
	if not _title.is_empty():
		_draw_title(ci, vs)
	if not _lvl.is_empty():
		_draw_level_up(ci, vs)
	if not _card.is_empty():
		_draw_card(ci)


func backing_rects() -> Dictionary:
	## {left, right}: the soft wash behind the left block and the sigils'
	## tray (tests: they cover their clusters and stay clear of the rest).
	var L := layout()
	var left: Rect2 = (L["badge"] as Rect2).merge(L["life"]).merge(L["res"]).merge(L["embers"])
	if _marks() > 0:
		left = left.merge(L["marks"])
	left = Rect2(left.position - Vector2(4, 3), left.size + Vector2(12, 5))
	var right: Rect2 = (L["sigils"] as Rect2).grow_individual(4.0, 2.0, 4.0, 2.0)
	return {"left": left, "right": right}


func _marks() -> int:
	return int(_xp().get("marks", 0))


func _draw_backing(ci: Control) -> void:
	## A soft dark wash under the left block (it fades out over ~20 px) and a
	## dark tray for the three sigil slots: world things on high ledges (a
	## real sigil, a Dread's gold ring) sink behind the HUD instead of
	## mixing with it.
	var B := backing_rects()
	var sb := UI.box()
	sb.bg_color = Color(UI.INK, 0.36)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(UI.INK, 0.36)
	sb.shadow_size = 20
	sb.draw(ci.get_canvas_item(), B["left"])
	if not pill_showing() and not has_sigils():
		return   # nothing in the corner: no tray
	sb = UI.box()
	sb.bg_color = Color(UI.INK, 0.7)
	sb.border_color = Color(UI.PANEL_EDGE, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(13)
	sb.shadow_color = Color(UI.INK, 0.3)
	sb.shadow_size = 5
	sb.draw(ci.get_canvas_item(), B["right"])


func _draw_vignette(ci: Control, vs: Vector2, f: float) -> void:
	## A heartbeat at the screen's edge: two quick beats every 1.1 s.
	var ph := fmod(_t, 1.1)
	var beat := exp(-ph * 9.0) + (0.7 * exp(-(ph - 0.2) * 9.0) if ph > 0.2 else 0.0)
	var k := clampf((0.25 - f) / 0.25, 0.0, 1.0)
	var a := (0.35 + 0.35 * k) * (0.55 + 0.45 * clampf(beat, 0.0, 1.0))
	ci.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, vs), false, Color(1, 1, 1, a))


func _draw_life(ci: Control, L: Dictionary, f: float) -> void:
	var r: Rect2 = L["life_bar"]
	var bump := _life_bump
	# The level badge, its XP filling the gold ring round it (clockwise from
	# the top; a spark rides the end when XP comes in).
	var bc: Vector2 = (L["badge"] as Rect2).get_center()
	var ring := BADGE_R - 2.5
	ci.draw_circle(bc, BADGE_R, UI.INK)
	ci.draw_arc(bc, ring, 0, TAU, 36, Color(UI.GOLD, 0.22), 3.2, true)
	if _xp_shown > 0.005:
		var end_a := -PI * 0.5 + TAU * _xp_shown
		ci.draw_arc(bc, ring, -PI * 0.5, end_a, maxi(6, int(36 * _xp_shown)), UI.GOLD.lerp(Color.WHITE, _xp_glow * 0.5), 3.2, true)
		if _xp_glow > 0.0:
			ci.draw_circle(bc + Vector2(cos(end_a), sin(end_a)) * ring, 2.2 + _xp_glow * 1.8, Color(1, 0.95, 0.7, _xp_glow))
	ci.draw_circle(bc, ring - 2.2, Color("2a1f38"))
	var lvl := str(_xp_level)
	UI.text(ci, Vector2(bc.x - 14.0, bc.y + 4.5), lvl, 13 if lvl.length() < 2 else 12, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 28.0, "body", 800)
	if _points > 0:
		# A skill point waiting: a gold "+" on the badge's shoulder.
		var pr := points_pip_rect(L)
		var k := 1.0 + 0.06 * sin(_t * 4.0)
		ci.draw_circle(pr.get_center(), pr.size.x * 0.5 * k, UI.INK)
		ci.draw_circle(pr.get_center(), (pr.size.x * 0.5 - 1.3) * k, UI.GOLD)
		UI.glyph(ci, "plus", pr.get_center(), 8.5, UI.INK)
	# Past level 40: "✦3", the Candlemarks, under the badge.
	var mk := mini(_marks_seen, _marks())
	if mk > 0:
		var mr: Rect2 = L["marks"]
		var mw := UI.text_width(str(mk), 11, "body", 800) + 12.0
		UI.mark_badge(ci, Vector2(mr.get_center().x - mw * 0.5, mr.position.y + 11.5), mk, 11)
	# The trough.
	var trough := UI.box()
	trough.bg_color = Color(UI.INK, 0.82)
	trough.border_color = Color(UI.PANEL_EDGE, 0.95)
	trough.set_border_width_all(1)
	trough.set_corner_radius_all(5)
	trough.draw(ci.get_canvas_item(), r.grow(1.5))
	# The molten end: wax just lost glows hot, then cools and drains away.
	var wx := r.position.x + r.size.x * _life_shown
	var rx := r.position.x + r.size.x * _life_recent
	if rx > wx + 0.5:
		ci.draw_rect(Rect2(wx, r.position.y + 2.0, rx - wx, r.size.y - 4.0), Color("b0462a", 0.75))
		ci.draw_rect(Rect2(wx, r.position.y + 2.0, rx - wx, 2.0), Color("e07040", 0.6))
	# The wax, cel-shaded: a lit top, a cool underside, and a soft melted lip
	# at the burning end, where the wick and its flame (sized by life) sit.
	if _life_shown > 0.0:
		var w := r.size.x * _life_shown
		var body := UI.box()
		body.bg_color = UI.CREAM.lerp(Color("fff6dc"), bump * 0.6)
		body.corner_radius_top_left = 5
		body.corner_radius_bottom_left = 5
		body.corner_radius_top_right = 2
		body.corner_radius_bottom_right = 2
		body.draw(ci.get_canvas_item(), Rect2(r.position, Vector2(w, r.size.y)))
		ci.draw_rect(Rect2(r.position.x + 3.0, r.end.y - 5.0, maxf(w - 5.0, 0.0), 3.0), Color("d8c7a6"))
		ci.draw_rect(Rect2(r.position.x + 4.0, r.position.y + 2.5, maxf(w - 12.0, 0.0), 2.0), Color(1, 1, 1, 0.7))
		if w > 8.0:
			var lip := UI.box()
			lip.bg_color = Color("fffaf0")
			lip.set_corner_radius_all(3)
			lip.draw(ci.get_canvas_item(), Rect2(wx - 7.0, r.position.y - 1.0, 7.0, r.size.y + 2.0))
			ci.draw_rect(Rect2(wx - 6.0, r.end.y - 3.0, 5.0, 2.0), Color("e6d6b8"))
	# The numbers, clear of the flame (see life_text): ink on the wax, or
	# cream on the dark past the burning end.
	var p = world.player
	var lt := life_text(r, _life_shown, float(p.hp), float(p.max_hp))
	if str(lt["text"]) != "":
		var strip: Rect2 = lt["rect"]
		var fs := int(lt["size"])
		var at := Vector2(strip.position.x, r.position.y + 12.5 - (LIFE_FONT - fs) * 0.35)
		if lt["on_wax"]:
			UI.text(ci, at, lt["text"], fs, Color("3a2c26"), HORIZONTAL_ALIGNMENT_CENTER, strip.size.x, "body", 800)
		else:
			UI.text(ci, at, lt["text"], fs, UI.CREAM if f > 0.25 else Color("ffd0c0"), HORIZONTAL_ALIGNMENT_CENTER, strip.size.x, "body", 800, 3)
	# The flame burns in the melted end itself and rises above the bar, in
	# the hero's palette. Dimmed, it sputters sideways (never the low-life
	# flicker) inside a grey ring.
	if _life_shown > 0.0:
		var base := Vector2(wx - 3.0, r.get_center().y + 2.5)
		ci.draw_line(base + Vector2(0, 1.0), base + Vector2(0.4, -3.5), Color("3a2a22"), 1.8)
		var h := (7.0 + 8.0 * f) * (1.0 + bump * 0.2)
		var pal = world.get("hero_flame")
		var sputter := Vector2(sin(_t * 13.0) * 1.6 + sin(_t * 29.0) * 0.8, 0.0) * _dim_k
		if _dim_k > 0.0:
			var dc := base + Vector2(0.4, -h * 0.45)
			var tb := UI.batch()
			tb.ring(dc, 8.0 + h * 0.2, 2.0, Color(DIM_GREY, (0.6 + 0.2 * sin(_t * 3.0)) * _dim_k), 24)
			tb.flush(ci)
		UI.flame(ci, base + Vector2(0.4, -1.0) + sputter, h * (1.0 - 0.12 * _dim_k), _t, 0.0, f < 0.25, 1.0, true,
				pal if pal is Dictionary else {})


func life_text(r: Rect2, frac: float, hp: float, max_hp: float) -> Dictionary:
	## {text, size, rect, on_wax}: the life numbers on the bar r with the wax
	## burnt down to frac, and the strip they're centred in, clear of the
	## flame at the burning end. "hp / max" in ink on the wax when it fits
	## there at full size, else in cream on the dark past the flame when it
	## fits there; else on the roomier side in type as small as LIFE_FONT_MIN,
	## then without the spaces ("1044/1999"), and past that only the life
	## left ("1044"). The strip is never narrower than the text: draw_string
	## would cut its last digits off ("163 / 30" for 163 / 302).
	var wx := r.position.x + r.size.x * clampf(frac, 0.0, 1.0)
	# On the wax the text keeps 6 px more clear of the melted lip.
	var wax := Rect2(r.position.x + 4.0, r.position.y, wx - r.position.x - 16.0, r.size.y)
	var wax_room := wax.size.x - 6.0
	var x0 := maxf(wx + 8.0, r.position.x + 4.0)
	var dark := Rect2(x0, r.position.y, r.end.x - x0 - 2.0, r.size.y)
	var full := "%d / %d" % [roundi(hp), roundi(max_hp)]
	var tw := UI.text_width(full, LIFE_FONT, "body", 800)
	if tw <= wax_room:
		return {"text": full, "size": LIFE_FONT, "rect": wax, "on_wax": true}
	if tw <= dark.size.x:
		return {"text": full, "size": LIFE_FONT, "rect": dark, "on_wax": false}
	var on_wax := wax_room > dark.size.x
	var room := wax_room if on_wax else dark.size.x
	for s in [full, "%d/%d" % [roundi(hp), roundi(max_hp)], str(roundi(hp))]:
		var fs := UI.fit_size(s, room, LIFE_FONT, LIFE_FONT_MIN, "body", 800)
		if UI.text_width(s, fs, "body", 800) <= room:
			return {"text": s, "size": fs, "rect": wax if on_wax else dark, "on_wax": on_wax}
	return {"text": "", "size": LIFE_FONT, "rect": Rect2(), "on_wax": false}


func _draw_resource(ci: Control, L: Dictionary) -> void:
	var r: Rect2 = L["res"]
	var cls := _cls()
	var info: Dictionary = Classes.info(cls)
	var col := UI.res_color(cls)
	var p = world.player
	var n := maxi(int(info.get("res_pips", 0)), 0)
	if n > 0:
		n = maxi(n, roundi(float(p.res_max)))
		var have := float(p.res)
		for i in n:
			var c := Vector2(r.position.x + 5.0 + i * 14.0, r.get_center().y)
			ci.draw_circle(c, 5.5, Color(UI.INK, 0.85))
			var k := clampf(have - i, 0.0, 1.0)
			if k >= 1.0:
				ci.draw_circle(c, 4.2, col)
				ci.draw_circle(c + Vector2(-1.2, -1.2), 1.4, Color(1, 1, 1, 0.6))
			elif k > 0.0:
				ci.draw_arc(c, 2.6, -PI * 0.5, -PI * 0.5 + TAU * k, 16, Color(col, 0.8), 3.0)
			else:
				ci.draw_arc(c, 4.0, 0, TAU, 14, Color(col, 0.35), 1.0)
		return
	var bg := UI.box()
	bg.bg_color = Color(UI.INK, 0.8)
	bg.border_color = Color(UI.PANEL_EDGE, 0.8)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	bg.draw(ci.get_canvas_item(), r.grow(1.0))
	if _res_shown > 0.005:
		var fr := Rect2(r.position, Vector2(r.size.x * _res_shown, r.size.y))
		ci.draw_rect(fr, col)
		ci.draw_rect(Rect2(fr.position + Vector2(1, 1), Vector2(maxf(fr.size.x - 2.0, 0.0), 2.0)), Color(col.lightened(0.45), 0.9))
	if _res_shown >= 0.999:
		ci.draw_rect(r.grow(1.5), Color(col, 0.25 + 0.2 * sin(_t * 5.0)), false, 1.0)


func _draw_embers(ci: Control, L: Dictionary) -> void:
	var r: Rect2 = L["embers"]
	var c := Vector2(r.position.x + 9.0, r.get_center().y)
	var s := 8.5 * (1.0 + _ember_bump * 0.3)
	UI.ember_icon(ci, c, s)
	var col := UI.CREAM.lerp(UI.GOLD, clampf(_bank_flash * 1.5, 0.0, 1.0))
	var n := str(_carried_seen)
	UI.text(ci, Vector2(c.x + 12.0, c.y + 5.5), n, 15, col, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 4)
	if _bank_flash > 0.0 and _bank_amount > 0:
		var a := clampf(_bank_flash * 2.0, 0.0, 1.0)
		var x := c.x + 20.0 + UI.text_width(n, 15, "body", 800) + (1.0 - _bank_flash) * 10.0
		UI.text(ci, Vector2(x, c.y + 4.5), "+%d banked" % _bank_amount, 12, Color(UI.GOLD, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 700, 3)


func _draw_sigils(ci: Control, L: Dictionary) -> void:
	var r: Rect2 = L["sigils"]
	var got: Array = world.get("sigils_got") if world.get("sigils_got") is Array else [false, false, false]
	var full := UI.tex("res://art/props/sigil.svg")
	var empty := UI.tex("res://art/ui/sigil_empty.svg")
	for i in 3:
		var have: bool = i < got.size() and got[i]
		var sc: float = 22.0 * (1.0 + _sigil_bump[i] * 0.5)
		var c := Vector2(r.position.x + 11.0 + i * 25.0, r.get_center().y)
		var t: Texture2D = full if have else empty
		if _sigil_bump[i] > 0.0:
			ci.draw_circle(c, 14.0 * _sigil_bump[i] + 6.0, Color(1.0, 0.85, 0.4, 0.25 * _sigil_bump[i]))
		if t:
			ci.draw_texture_rect(t, Rect2(c - Vector2(sc, sc) * 0.5, Vector2(sc, sc)), false, Color(1, 1, 1, 1.0 if have else 0.7))
		else:
			ci.draw_arc(c, 8.0, 0, TAU, 20, UI.GOLD if have else UI.MUTED, 2.0)


func _draw_pill(ci: Control, r: Rect2) -> void:
	## A mode's pill: its label ("D7"), a clock, small candles for its lives
	## (Spare Wicks), dots (Hushings) and a count ("3/5" by a candle), left
	## to right, each only when the state has it; smaller type when they
	## crowd it, and the last ones left out if they still don't fit.
	var col: Color = _pill.get("col", UI.GOLD)
	var parts := pill_parts(_pill)
	var room := r.size.x - 20.0
	var fs := 13
	var lfs := 15
	while fs > 10 and _parts_width(parts, fs, lfs) > room:
		fs -= 1
		lfs -= 1
	var tb := UI.batch()
	var texts: Array = []
	var x := r.position.x + 10.0
	var cy := r.get_center().y
	for p in parts:
		var w := _part_width(p, fs, lfs)
		if x + w > r.end.x - 8.0:
			break
		match str(p[0]):
			"label":
				texts.append([Vector2(x, cy + 5.5), str(p[1]), lfs, col])
			"text":
				texts.append([Vector2(x, cy + 5.0), str(p[1]), fs, UI.CREAM])
			"lives":
				for i in int(p[2]):
					_pill_candle(tb, Vector2(x + i * 10.0, cy), i < int(p[1]))
			"dots":
				for i in int(p[1]):
					tb.circle(Vector2(x + 3.5 + i * 10.0, cy + 1.0), 3.6, Color("b6a8e8"), 10)
			"count":
				_pill_candle(tb, Vector2(x, cy), true)
				texts.append([Vector2(x + 11.0, cy + 5.0), str(p[1]), fs, UI.CREAM])
		x += w + 7.0
	tb.flush(ci)
	for t in texts:
		UI.text(ci, t[0], t[1], t[2], t[3], HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3)


static func pill_parts(state: Dictionary) -> Array:
	## The pill's pieces in order: [kind, value, max].
	var parts: Array = []
	if str(state.get("label", "")) != "":
		parts.append(["label", str(state["label"])])
	if state.has("clock") and float(state["clock"]) >= 0.0:
		var c := float(state["clock"])
		parts.append(["text", "%d:%02d.%02d" % [int(c) / 60, int(c) % 60, int(fmod(c, 1.0) * 100.0)]])
	if int(state.get("lives_max", 0)) > 0:
		parts.append(["lives", int(state.get("lives", 0)), mini(int(state["lives_max"]), 5)])
	if int(state.get("dots", 0)) > 0:
		parts.append(["dots", mini(int(state["dots"]), 6)])
	if str(state.get("count", "")) != "":
		parts.append(["count", str(state["count"])])
	return parts


static func _part_width(p: Array, fs: int, lfs: int) -> float:
	match str(p[0]):
		"label":
			return UI.text_width(str(p[1]), lfs, "body", 800)
		"text":
			return UI.text_width(str(p[1]), fs, "body", 800)
		"lives":
			return int(p[2]) * 10.0 - 3.0
		"dots":
			return int(p[1]) * 10.0 - 3.0
		"count":
			return 11.0 + UI.text_width(str(p[1]), fs, "body", 800)
	return 0.0


static func _parts_width(parts: Array, fs: int, lfs: int) -> float:
	var w := 0.0
	for p in parts:
		w += _part_width(p, fs, lfs) + 7.0
	return w - 7.0


static func _pill_candle(tb: RefCounted, at: Vector2, lit: bool) -> void:
	## A small candle (a Spare Wick): cream and burning, or grey and out.
	tb.rect(Rect2(at.x, at.y - 3.0, 7.0, 11.0), UI.CREAM if lit else Color(UI.MUTED, 0.4))
	tb.rect(Rect2(at.x + 1.0, at.y - 2.0, 2.0, 9.0), Color(1, 1, 1, 0.35) if lit else Color(0, 0, 0, 0))
	if lit:
		tb.circle(Vector2(at.x + 3.5, at.y - 6.5), 3.0, UI.EMBER, 10)
		tb.circle(Vector2(at.x + 3.5, at.y - 6.2), 1.4, UI.FLAME_CORE, 8)


func _draw_boss(ci: Control) -> void:
	var full := boss_rect()
	var k := 1.0 - pow(1.0 - _boss_in, 3.0)
	var r := Rect2(full.get_center().x - full.size.x * 0.5 * k, full.position.y, full.size.x * k, full.size.y)
	var a := boss_alpha()
	if a <= 0.0:
		return
	# Name and title over the bar (shrunk to share the row).
	var lab := boss_label_layout()
	UI.glyph(ci, "bell", Vector2(full.position.x + 7.0, full.position.y - 10.0), 14.0, Color(UI.GOLD, a))
	UI.text(ci, Vector2(full.position.x + 17.0, full.position.y - 5.0), str(lab["name"]), int(lab["name_size"]), Color(UI.GOLD, a), HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700, 4)
	if int(lab["title_size"]) > 0:
		UI.text(ci, Vector2(full.position.x, full.position.y - 5.0), str(lab["title"]), int(lab["title_size"]), Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_RIGHT, full.size.x, "body", 700, 3)
	var sb := UI.box()
	sb.bg_color = Color(UI.INK, 0.88 * a)
	sb.border_color = Color(UI.GOLD, 0.9 * a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.draw(ci.get_canvas_item(), r.grow(2.0))
	var fx := r.position.x + r.size.x * clampf(_boss_shown, 0.0, 1.0)
	var rx := r.position.x + r.size.x * clampf(_boss_recent, 0.0, 1.0)
	if rx > fx:
		ci.draw_rect(Rect2(fx, r.position.y, rx - fx, r.size.y), Color(UI.CREAM, 0.85 * a))
	ci.draw_rect(Rect2(r.position, Vector2(fx - r.position.x, r.size.y)), Color(Color("c93a3a"), a))
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(maxf(fx - r.position.x - 1.0, 0.0), 3.0)), Color(Color("ff7a6a"), a))
	var segs: Array = _boss.get("segments", [])
	if not segs.is_empty():
		_draw_segments(ci, r, segs, a)
		return
	for ph in _boss.get("phases", []):
		var x := r.position.x + r.size.x * float(ph)
		var passed := _boss_shown <= float(ph)
		ci.draw_line(Vector2(x, r.position.y - 3.0), Vector2(x, r.end.y + 3.0), Color(UI.INK, a), 3.0)
		ci.draw_line(Vector2(x, r.position.y - 3.0), Vector2(x, r.end.y + 3.0), Color(UI.MUTED if passed else UI.GOLD, a), 1.2)


func boss_label_layout() -> Dictionary:
	## The boss's name (16, down to 13) and title (10, down to 8) sharing the
	## row over the bar, 10 apart; a title that still won't fit is dropped.
	## {name, title, name_size, title_size (0: dropped), name_rect, title_rect}.
	var full := boss_rect()
	var name := str(_boss.get("name", ""))
	var title := str(_boss.get("title", "")).to_upper()
	var room := full.size.x - 17.0
	var ns := UI.fit_size(name, room, 16, 13, "title", 700)
	var nw := UI.text_width(name, ns, "title", 700)
	var ts := 0
	var tw := 0.0
	if title != "":
		ts = UI.fit_size(title, room - nw - 10.0, 10, 8, "body", 700)
		tw = UI.text_width(title, ts, "body", 700)
		if nw + 10.0 + tw > room:
			ts = 0
			tw = 0.0
	return {"name": name, "title": title, "name_size": ns, "title_size": ts,
			"name_rect": Rect2(full.position.x + 17.0, full.position.y - 20.0, nw, 18.0),
			"title_rect": Rect2(full.end.x - tw, full.position.y - 15.0, tw, 13.0)}


func boss_marker_rects() -> Array:
	## Where the segmented bar's phase marks draw (the bar at full width):
	## set in the bar's own frame, never up in the name's row.
	var out: Array = []
	var r := boss_rect()
	for b in _seg_bounds(_boss.get("segments", [])):
		if float(b) > 0.0 and float(b) < 1.0:
			var x := r.position.x + r.size.x * float(b)
			out.append(Rect2(x - SEG_MARK.x, r.get_center().y - SEG_MARK.y, SEG_MARK.x * 2.0, SEG_MARK.y * 2.0))
	return out


static func _seg_bounds(segs: Array) -> Array:
	## 1.0, the segments' lines high to low, 0.0.
	var bounds: Array = [1.0]
	for s in segs:
		bounds.append(clampf(float(s), 0.0, 1.0))
	bounds.append(0.0)
	bounds.sort()
	bounds.reverse()
	return bounds


func _draw_segments(ci: Control, r: Rect2, segs: Array, a: float) -> void:
	## v3's bar in three (segments [0.65, 0.30]): at each phase line a
	## diamond set into the bar (an ink one that splits it, and in it gold
	## ahead, grey once passed), and the phase he's in lit along its top.
	## The marks stay in the bar's frame (SEG_MARK), clear of the name.
	var tb := UI.batch()
	var bounds := _seg_bounds(segs)
	var cy := r.get_center().y
	for i in range(1, bounds.size() - 1):
		var x := r.position.x + r.size.x * float(bounds[i])
		var passed := _boss_shown <= float(bounds[i])
		var c := Vector2(x, cy)
		var o := SEG_MARK
		var n := SEG_MARK - Vector2(1.9, 2.4)
		tb.convex(PackedVector2Array([c + Vector2(0, -o.y), c + Vector2(o.x, 0), c + Vector2(0, o.y), c + Vector2(-o.x, 0)]), Color(UI.INK, a))
		tb.convex(PackedVector2Array([c + Vector2(0, -n.y), c + Vector2(n.x, 0), c + Vector2(0, n.y), c + Vector2(-n.x, 0)]),
				Color(UI.MUTED if passed else UI.GOLD, a))
	# The phase he's in: a thin bright line along its top.
	for i in bounds.size() - 1:
		var hi := float(bounds[i])
		var lo := float(bounds[i + 1])
		if _boss_shown > lo and _boss_shown <= hi + 0.0001:
			var x0 := r.position.x + r.size.x * lo + (SEG_MARK.x if lo > 0.0 else 0.0)
			var x1 := r.position.x + r.size.x * minf(_boss_shown, hi) - (SEG_MARK.x if hi < 1.0 and _boss_shown >= hi else 0.0)
			if x1 > x0:
				tb.rect(Rect2(x0, r.position.y + 1.0, x1 - x0, 2.0), Color(1.0, 0.85, 0.75, 0.75 * a))
	tb.flush(ci)


func _draw_top() -> void:
	## Over the rest, never faded (the finale's barks and its pill show while
	## the HUD is away): the message slot, and the Special's pill.
	if world == null or world.get("player") == null:
		return
	var fb = world.get("finale_black")
	if fb != null and float(fb) > 0.0:
		# The finale's black, over the level (its line reads over it).
		_top.draw_rect(Rect2(Vector2(-8.0, -8.0), _vs() + Vector2(16.0, 16.0)), Color(0.0, 0.0, 0.0, clampf(float(fb), 0.0, 1.0)))
	_draw_slot(_top)
	if _special_k <= 0.0:
		return
	var a := _special_k * (1.0 - clampf(float(fb), 0.0, 1.0) if fb != null else 1.0)
	var r := special_pill_rect()
	r.position.y += (1.0 - a) * 8.0
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	UI.panel(_top, r, Color(UI.GOLD, (0.65 + 0.3 * pulse) * a), Color(UI.PANEL, 0.92 * a), 15.0)
	var tb := UI.batch()
	var tip := Vector2(r.get_center().x, r.end.y + 6.0)
	var L := _touch_layout()
	tip.x = clampf(float(L["special"].x), r.position.x + 14.0, r.end.x - 14.0)
	tb.tri(tip + Vector2(-7.0, -6.0), tip + Vector2(7.0, -6.0), tip, Color(UI.GOLD, (0.65 + 0.3 * pulse) * a))
	tb.flush(_top)
	var t := _special_last
	UI.text(_top, Vector2(r.position.x, r.position.y + 20.5), t, UI.fit_size(t, r.size.x - 20.0, 15, 11, "body", 700), Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 700)


func _draw_slot(ci: Control) -> void:
	## The one message slot: a message if there is one, else a sign's hint.
	if slot_blocked():
		return
	var boss_on := not _boss.is_empty()
	if not _msg.is_empty():
		var t := float(_msg["t"])
		var a := clampf(t * 5.0, 0.0, 1.0) * clampf((_msg_dur() - t) * 3.5, 0.0, 1.0) * see("msg")
		var slide := (1.0 - clampf(t * 5.0, 0.0, 1.0)) * -8.0
		slot_drawn = {"on": ci, "kind": str(_msg["kind"]), "a": a, "frame": Engine.get_process_frames()}
		match str(_msg["kind"]):
			"bark":
				_draw_bark(ci, _msg, a, slide, boss_on)
			"elite":
				_draw_elite(ci, _msg, a, slide, boss_on)
			_:
				_draw_note(ci, _msg, a, slide, boss_on)
		return
	if hint_showing():
		var ha := _hint_alpha * see("msg")
		var tw := UI.text_width(_hint, 15, "body", 600)
		var r := msg_rect(tw + 36.0, boss_on)
		r.size.y = 36.0
		r.position.y += (1.0 - _hint_alpha) * -8.0
		var size := UI.fit_size(_hint, r.size.x - 24.0, 15, 11)
		UI.panel(ci, r, Color(UI.GOLD, 0.6 * ha), Color(UI.PANEL, 0.88 * ha))
		UI.text(ci, Vector2(r.position.x, r.position.y + 23.0), _hint, size, Color(UI.CREAM, ha), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_note(ci: Control, m: Dictionary, a: float, slide: float, boss_on: bool) -> void:
	## A toast or a pickup note: a title and a line, maybe an icon.
	var title := str(m.get("title", ""))
	var sub := str(m.get("sub", ""))
	var icon: Texture2D = m.get("icon")
	var has_icon := icon != null or str(m.get("glyph", "")) != ""
	var tw := maxf(UI.text_width(title, 18, "title", 700), UI.text_width(sub, 13))
	var r := msg_rect(tw + 40.0 + (40.0 if has_icon else 0.0), boss_on)
	r.position.y += slide
	var col: Color = m.get("col", UI.GOLD)
	UI.panel(ci, r, Color(col, 0.85 * a), Color(UI.PANEL, 0.92 * a))
	var x := r.position.x + 14.0
	if has_icon:
		var c := Vector2(r.position.x + 26.0, r.get_center().y)
		ci.draw_circle(c, 16.0, Color(col, 0.16 * a))
		if icon:
			ci.draw_texture_rect(icon, Rect2(c - Vector2(15, 15), Vector2(30, 30)), false, Color(1, 1, 1, a))
		else:
			UI.glyph(ci, str(m["glyph"]), c, 20.0, Color(col, a))
		x = r.position.x + 48.0
	var w := r.end.x - x - 12.0
	var align := HORIZONTAL_ALIGNMENT_LEFT if has_icon else HORIZONTAL_ALIGNMENT_CENTER
	if sub == "":
		UI.text(ci, Vector2(x, r.position.y + 28.0), title, UI.fit_size(title, w, 19, 12, "title", 700), Color(col, a), align, w, "title", 700)
	else:
		UI.text(ci, Vector2(x, r.position.y + 20.0), title, UI.fit_size(title, w, 18, 12, "title", 700), Color(col, a), align, w, "title", 700)
		UI.text(ci, Vector2(x, r.position.y + 36.0), sub, UI.fit_size(sub, w, 13, 10), Color(UI.CREAM, a), align, w)


func _draw_bark(ci: Control, m: Dictionary, a: float, slide: float, boss_on: bool) -> void:
	## A speaker's face and their line (one line at 15 px, else two at 13).
	var text := str(m["text"])
	var one := UI.text_width(text, 15)
	var r := msg_rect(one + 66.0, boss_on)
	r.position.y += slide
	var col: Color = m.get("col", UI.GOLD)
	UI.panel(ci, r, Color(col, 0.8 * a), Color(UI.PANEL, 0.93 * a))
	var c := Vector2(r.position.x + 24.0, r.get_center().y)
	var letter := str(m.get("letter", str(m.get("who", "?")).substr(0, 1).to_upper()))
	UI.portrait(ci, c, 17.0, m.get("tex"), col, a, m.get("uv", Rect2(0, 0, 1, 1)), letter)
	var x := r.position.x + 50.0
	var w := r.end.x - x - 12.0
	if one <= w:
		UI.text(ci, Vector2(x, r.position.y + 27.5), text, 15, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, w)
	else:
		var lines := UI.wrap(text, w, 13)
		var size := 13
		if lines.size() > 2:
			size = 12
			lines = UI.wrap(text, w, 12)
		if lines.size() == 2:
			lines = balanced_two(text, w, size)
		for i in mini(lines.size(), 2):
			var s: String = lines[i]
			if i == 1 and lines.size() > 2:
				s += "…"
			UI.text(ci, Vector2(x, r.position.y + 19.0 + i * 16.0), s, size, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, w)


static func balanced_two(text: String, w: float, size: int) -> Array:
	## Two lines split at the space nearest the middle that fits both in w
	## (the rev5 review: "Stamp once for / me." left one word alone), else
	## UI.wrap's greedy lines.
	var words := text.split(" ", false)
	var best: Array = []
	var bd := INF
	for i in range(1, words.size()):
		var a := " ".join(words.slice(0, i))
		var b := " ".join(words.slice(i))
		var wa := UI.text_width(a, size)
		var wb := UI.text_width(b, size)
		if wa > w or wb > w:
			continue
		var d := absf(wa - wb)
		if d < bd:
			bd = d
			best = [a, b]
	return best if not best.is_empty() else UI.wrap(text, w, size)


func _draw_elite(ci: Control, m: Dictionary, a: float, slide: float, boss_on: bool) -> void:
	## An elite's plate: blue for the Anointed, gold for a Dread, its name,
	## its omens and a live life bar.
	var col := UI.DREAD if m["tier"] == "dread" else UI.ANOINTED
	var title := str(m["title"])
	var omens := " · ".join(m["omens"]).to_upper()
	var tw := maxf(UI.text_width(title, 17, "title", 700), UI.text_width(omens, 10, "body", 700))
	var r := msg_rect(tw + 50.0, boss_on)
	r.position.y += slide
	UI.panel(ci, r, Color(col, 0.9 * a), Color(col.darkened(0.82), 0.93 * a))
	UI.text(ci, Vector2(r.position.x, r.position.y + 19.0), title, 17, Color(col.lightened(0.2), a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "title", 700)
	if omens != "":
		UI.text(ci, Vector2(r.position.x, r.position.y + 31.0), omens, 10, Color(UI.CREAM, 0.85 * a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 700)
	var e = m["ref"].get_ref()
	var frac := 0.0
	if e != null and is_instance_valid(e):
		frac = clampf(float(e.hp) / maxf(float(e.max_hp), 1.0), 0.0, 1.0) if e.alive else 0.0
	var br := Rect2(r.get_center().x - r.size.x * 0.3, r.end.y - 9.0, r.size.x * 0.6, 4.0)
	ci.draw_rect(br.grow(1.0), Color(UI.INK, a))
	ci.draw_rect(Rect2(br.position, Vector2(br.size.x * frac, br.size.y)), Color(Color("e04a4a"), a))


func _draw_title(ci: Control, vs: Vector2) -> void:
	var tt: float = _title["t"]
	if tt < 0.0:
		return   # waiting on the level-up card
	var a := title_alpha()
	var cy := title_rect().position.y + 17.0   # the line's baseline
	if str(_title.get("kind", "")) == "card":
		_draw_band_card(ci, vs, cy, a)
		return
	UI.text(ci, Vector2(0, cy), str(_title["sub"]), 20, Color(UI.MUTED, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, "body", 700, 6)
	UI.text(ci, Vector2(0, cy + 44.0), str(_title["title"]), 40, Color(UI.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 8)
	var rule := clampf(tt * 1.6, 0.0, 1.0) * 90.0
	ci.draw_line(Vector2(vs.x * 0.5 - rule, cy + 58.0), Vector2(vs.x * 0.5 + rule, cy + 58.0), Color(UI.GOLD, 0.6 * a), 1.5)


func band_card_rect(title := "", body := "") -> Rect2:
	## Where a card() draws in the top band: its title and one line of words
	## on a soft plate, centred, clear of the left block and the sigils.
	var s := _safe()
	var cx := s.get_center().x
	var corner: Rect2 = pill_rect() if pill_showing() else _sigils_rect()
	var room := 2.0 * minf(cx - (s.position.x + 152.0), corner.position.x - 8.0 - cx)
	var w := maxf(UI.text_width(title, 26, "title", 700), UI.text_width(body, 14)) + 36.0
	w = clampf(w, 200.0, room)
	return Rect2(cx - w * 0.5, s.position.y + CARD_TOP + 2.0, w, 62.0)


func _draw_band_card(ci: Control, vs: Vector2, _cy: float, a: float) -> void:
	var title := str(_title.get("title", ""))
	var body := str(_title.get("body", ""))
	var r := band_card_rect(title, body)
	var sb := UI.box()
	sb.bg_color = Color(UI.INK, 0.62 * a)
	sb.border_color = Color(UI.GOLD, 0.5 * a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.draw(ci.get_canvas_item(), r)
	var w := r.size.x - 24.0
	UI.text(ci, Vector2(r.position.x + 12.0, r.position.y + 28.0), title, UI.fit_size(title, w, 26, 16, "title", 700), Color(UI.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, w, "title", 700, 6)
	if body != "":
		UI.text(ci, Vector2(r.position.x + 12.0, r.position.y + 50.0), body, UI.fit_size(body, w, 14, 10), Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, w, "body", 600, 4)


func _draw_level_up(ci: Control, vs: Vector2) -> void:
	## "Level up" / "Level 7": a gold ring bursts, the title pops in.
	var tt: float = _lvl["t"]
	if tt < 0.0:
		return   # waiting for a title card it cut short to fade
	var a := level_alpha()
	# In the top band, high over the hero and his flame.
	var c := Vector2(vs.x * 0.5, level_rect().position.y + 32.0)
	var ring := clampf(tt / 0.6, 0.0, 1.0)
	if ring < 1.0:
		var rr := 24.0 + 64.0 * (1.0 - pow(1.0 - ring, 3.0))
		ci.draw_arc(c + Vector2(0, 14), rr, 0, TAU, 48, Color(1.0, 0.85, 0.4, (1.0 - ring) * 0.6), 3.0 * (1.0 - ring) + 1.0)
		for i in 8:
			var ang := TAU * i / 8.0 + 0.3
			var d := Vector2(cos(ang), sin(ang))
			ci.draw_line(c + Vector2(0, 14) + d * rr * 0.8, c + Vector2(0, 14) + d * (rr * 0.8 + 10.0), Color(1.0, 0.9, 0.55, (1.0 - ring) * 0.8), 2.0)
	var pop := 1.0 + 0.35 * exp(-tt * 9.0) * cos(tt * 18.0)
	# Four lines in level_rect's 84 px: "Level up", "Level n", the gains, and
	# what opened (gold) or the next unlock.
	UI.text(ci, Vector2(0, c.y - 18.0), "Level up", 16, Color(UI.GOLD.lerp(UI.CREAM, 0.3), a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, "body", 700, 5)
	ci.draw_set_transform(c + Vector2(0, 17.0), 0.0, Vector2(pop, pop))
	UI.text(ci, Vector2(-vs.x * 0.5, 0.0), "Level %d" % int(_lvl["n"]), 36, Color(UI.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 7)
	ci.draw_set_transform(Vector2.ZERO)
	var w := LEVEL_LINE_W
	var line := str(_lvl.get("line", ""))
	if line != "":
		UI.text(ci, Vector2(vs.x * 0.5 - w * 0.5, c.y + 34.0), line, UI.fit_size(line, w, 13, 10, "body", 700), Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, w, "body", 700, 4)
	var nx: Dictionary = _lvl.get("next", {})
	var nt := str(nx.get("text", ""))
	if nt != "":
		var col: Color = UI.GOLD if bool(nx.get("now", false)) else UI.MUTED.lerp(UI.CREAM, 0.4)
		UI.text(ci, Vector2(vs.x * 0.5 - w * 0.5, c.y + 49.0), nt, UI.fit_size(nt, w, 12, 10, "body", 700), Color(col, a), HORIZONTAL_ALIGNMENT_CENTER, w, "body", 700, 4)


func _draw_card(ci: Control) -> void:
	var tt: float = _card["t"]
	var end: float = float(_card.get("end", 99.0))
	var a := clampf(tt * 6.0, 0.0, 1.0) * clampf((end - tt) * 4.0, 0.0, 1.0)
	var r := card_slot()
	r.position.y += (1.0 - clampf(tt * 6.0, 0.0, 1.0)) * 16.0
	if _card["kind"] == "relic":
		_draw_relic_card(ci, r, a)
		return
	var it: Dictionary = _card["item"]
	var col := UI.rarity_color(str(it.get("rarity", "common")))
	var where := str(_card["where"])
	var flash := float(_card.get("flash", 0.0))
	UI.panel(ci, r, Color(col.lerp(Color.WHITE, flash * 0.5), 0.95 * a), Color(UI.PANEL.lerp(col.darkened(0.6), flash * 0.4), 0.95 * a), 12.0)
	# The icon on a rarity-tinted disc.
	var ic := Vector2(r.position.x + 36.0, r.get_center().y)
	ci.draw_circle(ic, 27.0, Color(col, 0.14 * a))
	ci.draw_arc(ic, 27.0, 0, TAU, 32, Color(col, 0.35 * a), 1.5, true)
	var icon: Texture2D = _card.get("icon")
	if icon:
		ci.draw_texture_rect(icon, Rect2(ic - Vector2(24, 24), Vector2(48, 48)), false, Color(1, 1, 1, a))
	else:
		UI.glyph(ci, UI.slot_glyph(str(it.get("slot", ""))), ic, 34.0, Color(col, a))
	var x := r.position.x + 72.0
	var w := r.end.x - x - 10.0
	# What happened to it, and what a tap does.
	var tap := float(_card["tap_left"]) > 0.0
	# Longest first: the card takes the first that fits (a narrow phone
	# gets the short one).
	var opts: Array = []
	var scol := UI.MUTED
	match where:
		"equipped":
			opts = ["Equipped · tap to undo" if tap else "Equipped"]
			if _card.has("melt"):
				var m: Dictionary = _card["melt"]
				var n := int(m["embers"])
				if m["old"]:
					opts = ["Equipped · old one salvaged  +%d" % n, "Equipped · old one melted  +%d" % n, "Equipped · salvaged  +%d" % n]
				else:
					opts = ["Equipped · %s salvaged  +%d" % [m["name"], n], "Equipped · %s melted" % m["name"],
							"Equipped · satchel's weakest salvaged  +%d" % n, "Equipped · one salvaged  +%d" % n]
			scol = UI.GOLD
		"undone":
			opts = ["In your satchel · tap to wear" if tap else "In your satchel"]
		"full":
			if tap and _card.get("melts", false):
				opts = ["Satchel full · tap to wear, old one melts", "Full · tap to wear, old one melts", "Tap to wear · old one melts"]
			elif tap:
				opts = ["Satchel full · tap to wear it"]
			else:
				opts = ["Satchel full · left on the ground", "Full · left on the ground"] if _card.get("floor", false) else ["Satchel full"]
			scol = UI.BAD
		_:
			opts = ["In your satchel · tap to wear" if tap else "In your satchel"]
	# A Legendary's moment (power_card): "New power" heads it.
	var power: bool = bool(_card.get("power", false)) and where in ["equipped", "satchel"]
	if power:
		if where == "equipped":
			opts = opts.map(func(o): return str(o).replace("Equipped", "New power")) + ["New power"]
		else:
			opts = ["New power · tap to wear" if tap else "New power · in your satchel", "New power"]
		scol = UI.GOLD
	if tap and bool(_card.get("armed", false)) and where != "equipped":
		# The first tap asked: wearing it melts the worn piece for good.
		opts = ["Tap again to wear · old one melts", "Tap again · old one melts"]
		scol = UI.BAD
	var fit := _fit_status(opts, w)
	var status: String = fit[0]
	var fs: int = fit[1]
	card_fits = UI.text_width(status, fs, "body", 800) <= w + 0.5
	card_line = status
	# What it does: one line, or (a Legendary's power) two, the card's lines
	# closing up to make room.
	var kl := card_power_lines(Items.key_line(it), w) if power else card_key_lines(Items.key_line(it), w)
	var two: bool = (kl["lines"] as Array).size() > 1
	# Baselines: status, name, the key line(s); then the chips' top. A "New
	# power" gives the power the room (13 or 12 px, 14 apart), the chips the
	# least.
	var ys: Array = [16.0, 36.0, 50.0, 67.0] if two else [18.0, 39.0, 55.0, 62.0]
	if power:
		ys = [15.0, 33.0, 49.0, 69.0 if two else 56.0]
	UI.text(ci, Vector2(x, r.position.y + ys[0]), status, fs, Color(scol, a), HORIZONTAL_ALIGNMENT_LEFT, w, "body", 800)
	var name := str(it.get("name", ""))
	UI.text(ci, Vector2(x, r.position.y + ys[1]), name, UI.fit_size(name, w, 17 if power else 19, 13, "title", 700), Color(col, a), HORIZONTAL_ALIGNMENT_LEFT, w, "title", 700)
	var ksz := int(kl["size"])
	for i in (kl["lines"] as Array).size():
		UI.text(ci, Vector2(x, r.position.y + ys[2] + i * (14.0 if power else 12.0)), str(kl["lines"][i]), ksz,
				Color(UI.CREAM, (1.0 if power else 0.9) * a), HORIZONTAL_ALIGNMENT_LEFT, w)
	var chips: Dictionary = _card["chips"]
	var cx := x
	var chip_y: float = r.position.y + ys[3]
	var csz := 9 if power else (10 if two else 11)
	cx += UI.chip(ci, Vector2(cx, chip_y), "DMG", float(chips.get("dmg", 0.0)), csz, a) + 6.0
	UI.chip(ci, Vector2(cx, chip_y), "LIFE", float(chips.get("life", 0.0)), csz, a)
	# How long the tap still counts.
	if tap:
		var k := float(_card["tap_left"]) / CARD_TAP
		var y := r.end.y - 4.0
		ci.draw_line(Vector2(r.position.x + 14.0, y), Vector2(r.position.x + 14.0 + (r.size.x - 28.0) * k, y), Color(scol, 0.7 * a), 2.0)


static func card_power_lines(key: String, w: float) -> Dictionary:
	## {lines, size}: a "New power" card's power, large: one or two lines at
	## 13 or 12 px; longer than that, as card_key_lines.
	for sz in [13, 12]:
		var lines := UI.wrap(key, w, sz)
		var fits := true
		for l in lines:
			fits = fits and UI.text_width(str(l), sz) <= w
		if lines.size() <= 2 and fits:
			return {"lines": lines, "size": sz}
	return card_key_lines(key, w)


static func card_key_lines(key: String, w: float) -> Dictionary:
	## {lines, size}: the item card's "what it does" line in width w. One
	## line at 12 or 11 px when it fits; else (a Legendary's power) wrapped
	## to two lines at 11 or 10 px, as the relic card wraps; cut with an
	## ellipsis only past two lines at 10 px.
	var one := UI.fit_size(key, w, 12, 11)
	if UI.text_width(key, one) <= w:
		return {"lines": [key], "size": one}
	for sz in [11, 10]:
		var lines := UI.wrap(key, w, sz)
		var fits := true
		for l in lines:
			fits = fits and UI.text_width(str(l), sz) <= w
		if lines.size() <= 2 and fits:
			return {"lines": lines, "size": sz}
	var lines := UI.wrap(key, w, 10)
	var first := str(lines[0]) if not lines.is_empty() else ""
	while first.length() > 4 and UI.text_width(first, 10) > w:
		first = first.substr(0, first.length() - 1)
	var rest := key.substr(first.length()).strip_edges()
	while rest.length() > 4 and UI.text_width(rest + "...", 10) > w:
		rest = rest.substr(0, rest.length() - 1)
	return {"lines": [first, rest.strip_edges() + "..."], "size": 10}


func _fit_status(opts: Array, w: float) -> Array:
	## [text, size]: the first of opts (in capitals) that fits w at 9 px or
	## more; the last one at whatever size fits.
	for i in opts.size():
		var t := str(opts[i]).to_upper()
		var fs := UI.fit_size(t, w, 10, 8, "body", 800)
		if i == opts.size() - 1 or (fs >= 9 and UI.text_width(t, fs, "body", 800) <= w):
			return [t, fs]
	return ["", 10]


func _draw_relic_card(ci: Control, r: Rect2, a: float) -> void:
	var rel: Dictionary = Relics.get_relic(str(_card["id"]))
	var col := UI.rarity_color(str(rel["rarity"]))
	UI.panel(ci, r, Color(col, 0.95 * a), Color(UI.PANEL, 0.95 * a), 12.0)
	var ic := Vector2(r.position.x + 36.0, r.get_center().y)
	var pulse := 0.5 + 0.5 * sin(float(_card["t"]) * 5.0)
	ci.draw_circle(ic, 29.0, Color(col, (0.14 + 0.08 * pulse) * a))
	var icon := UI.relic_icon(str(rel["id"]))
	if icon:
		ci.draw_texture_rect(icon, Rect2(ic - Vector2(26, 26), Vector2(52, 52)), false, Color(1, 1, 1, a))
	var x := r.position.x + 72.0
	var w := r.end.x - x - 10.0
	var head := ("%s relic · %s" % [Relics.RARITY_NAME[rel["rarity"]], relic_status(_card)]).to_upper()
	UI.text(ci, Vector2(x, r.position.y + 18.0), head, UI.fit_size(head, w, 10, 8, "body", 800), Color(col if _card["on"] else UI.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, w, "body", 800)
	UI.text(ci, Vector2(x, r.position.y + 42.0), str(rel["name"]), UI.fit_size(str(rel["name"]), w, 21, 14, "title", 700), Color(col, a), HORIZONTAL_ALIGNMENT_LEFT, w, "title", 700)
	var lines := UI.wrap(str(rel["text"]), w, 12)
	for i in mini(lines.size(), 2):
		UI.text(ci, Vector2(x, r.position.y + 60.0 + i * 15.0), lines[i], 12, Color(UI.CREAM, 0.9 * a), HORIZONTAL_ALIGNMENT_LEFT, w)
