extends Control
## The way down: a world's levels as medallions on a path of little flames.
## Each shows its recommended level ("Lv 3"), its name with its twist's name
## under it where it has one (Build 2: "On the Hour", twists.gd card_of, so
## two levels' rules read apart before either is played), this difficulty's
## three sigils and, where the level has one, its Dread's skull (lit once
## beaten). Along
## the top: back to the title, the difficulty bells (Dusk, Nightfall,
## Witching Hour, the deeper two with their "Lv 30+" / "Lv 40+" chips) and
## who's playing (his own name, then his calling and level, a gold "+" while
## skill points wait).
## Along the bottom: Callings · Sheet · Shop (· Challenges) and Play. The
## Shop (Waxley's, the Chandler) wears a corner mark (Game.shop_badge): a red
## "16/16" while the satchel is full, else a green ▲ while a stock he hasn't
## looked at yet has a ware he can afford that he'd wear at once (never a
## plain piece over a worn Legendary), else a gold dot for a Reserve not yet
## seen.
## World tabs appear once World 2 is open: one per world in the build (six
## in v3), each in its world's accent with its emblem (art/ui/world_<n>.svg),
## a world not reached yet dark behind a lock.
##
## Tap a medallion to pick it, tap it again (or Play) to go in. The buttons
## emit callings(), sheet(), chandler() and challenges(), and main.gd opens
## those screens (the Chandler's first visit meets Waxley there too; with
## nothing listening to challenges, the map opens the hub itself).
## world_opened(w) fires when a world's tab comes up: switched to, or open
## as the map opens (World 2 and on); main.gd plays that world's opening
## scene the first time.
##
## v3's secrets (spec §3.9, only for secret levels in the build): once the
## level holding a world's exit (1-3, 2-2, 3-3, 4-2, 5-3, 6-2) is cleared,
## its medallion wears a small silver spark and the world's tab and name say
## "1 secret"; once its silver bell has rung on this difficulty, a silver
## medallion branches off above it: tap it, then tap again (or Play) and
## play_secret(id) goes in. A secret shows only once opened.
##
## card(id, title, body) shows a one-time card over the map (main.gd's
## v3_update, new points, Nightfall news); closing it marks it seen
## (Game.notice). The first time into a level on Nightfall or the Witching
## Hour with the hero more than 5 levels under it, a card warns first.
## The Challenges button (once ModesSave.hub_open(), with the modes' hub in
## the build) wears a gold "!" for news and a pulsing ember while this
## calling has a Descent run waiting.
##
## Continue from the altar (spec §9.1, P1): with a level's resume snapshot in
## the save (Game.suspended()) and main.gd listening to resume_altar, the map
## offers it once per snapshot: Continue says resume_altar(snapshot).

signal play(index: int)
signal back
signal callings
signal sheet
signal chandler
signal world_opened(w: int)
signal challenges
signal settings
signal play_secret(id: String)
signal resume_altar(snapshot: Dictionary)

const UI := preload("res://scripts/ui.gd")
const Classes := preload("res://scripts/classes.gd")
const Combat := preload("res://scripts/combat.gd")
const Twists := preload("res://scripts/twists.gd")
const Chandler := preload("res://scripts/chandler_screen.gd")   # the Shop button's mark (draw_badge)
const MODES_SAVE := "res://scripts/modes/modes_save.gd"
const MODES_SCREEN := "res://scripts/modes/modes_screen.gd"
const HUB_FROM := "1-2"           # the Challenges show once this is cleared (without ModesSave to say)
const WARN_UNDER := 5             # levels under a deeper level's area that earn the warning card
const WARN_ID := "nightfall_warning"
const NOTE_TIME := 2.6            # a locked bell's or tab's note: long enough to read
const SECRET_R := 18.0            # a secret's medallion
const SECRET_AT := Vector2(64.0, -40.0)   # from its exit level's medallion
const PILL_GAP := 24.0            # the hero pill's least room from the last bell (its Lv chip sits in it)
const PILL_NAME_MIN := 12         # the pill's name never smaller beside his calling (else the calling goes)

var focus := 0                    # a global index into Game.LEVELS
var focus_secret := ""            # a secret level picked instead ("1-S"), or ""
var world_tab := 1
var _t := 0.0
var _info: Array = []             # per level: {id, sub, title, area, dread, boss, secret, twist (its name, or "")}
var _secrets := {}                # world -> {id, from, title, area, built}
var _play_btn: Button
var _back_btn: Button
var _settings_btn: Button
var _callings_btn: Button
var _sheet_btn: Button
var _chandler_btn: Button
var _challenges_btn: Button
var _overlay: Control = null      # the Sheet's Belt tab, opened for tools/shot.gd (_shelf)
var _cardv: Control = null        # a one-time card over the map (card())
var _card := {}                   # {id, title, body, then, emblem, t}
var _card_ok: Button = null
var _card_alt: Button = null
static var _resume_offered := ""   # the snapshot last offered (its "at"), once each
var _marks := {"news": false, "resume": false, "t": 0.0}   # the Challenges button's marks, asked twice a second
var shop_badge := {}              # the Shop button's mark (Game.shop_badge), asked on _refresh
var _deny := 0.0
var _deny_d := ""                 # the locked bell last tapped (it shakes)
var _note := ""                   # why a locked bell or world tab won't open: over the name line for NOTE_TIME
var _note_t := 0.0
var _modes_lib = null             # ModesSave's script, looked for once (false: not in this build)
static var modes_screen := MODES_SCREEN   # the hub (tests and screenshots may point it at a stand-in)
# tools/shot.gd's hooks from v1: the relic shelf lives in the Sheet's Belt
# tab now (setting _shelf opens it over the map), and the relic shop is the
# Chandler's (setting _shop asks main.gd for it, as the Chandler button does).
var _shop := false:
	set(v):
		_shop = false
		if v and is_inside_tree():
			_open("chandler")
var _shelf := false:
	set(v):
		_shelf = false
		if v and is_inside_tree():
			var h = load("res://scripts/hero_screen.gd").new()
			h.tab = "belt"
			h.back.connect(_close_overlay)
			_show_overlay(h)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	for info in Game.LEVELS:
		var h := level_headers(str(info["path"]))
		_info.append({"id": str(info["id"]), "sub": str(h.get("subtitle", info["id"])), "title": str(h.get("title", "")),
				"area": int(h.get("area", "1")) if str(h.get("area", "1")).is_valid_int() else 1,
				"dread": str(h.get("dread", "")) != "", "boss": str(h.get("boss", "")) != "", "secret": str(h.get("secret", "")),
				"twist": twist_name_of(h, int(info.get("world", 0)), str(info["id"]))})
	_read_secrets()
	focus = clampi(focus, 0, maxi(Game.LEVELS.size() - 1, 0))
	if Game.LEVELS.size() > 0:
		world_tab = int(Game.LEVELS[focus]["world"])
	if world_tab >= 2:
		# Opening straight onto a later world (say, just after 1-4): after
		# _ready, so main.gd may swap the map out without pulling it from
		# under itself.
		_world_opened.call_deferred(world_tab)
	_play_btn = UI.make_button("Play", true, func(): _play_pressed(), "", 22)
	_play_btn.custom_minimum_size = Vector2(150, 50)
	_back_btn = UI.make_button("Title", false, func(): back.emit(), "back", 15)
	UI.small_button(_back_btn, 15)
	_back_btn.custom_minimum_size = Vector2(70, UI.TAP_H)
	_settings_btn = UI.make_button("Settings", false, func(): settings.emit(), "click", 15)
	UI.small_button(_settings_btn, 15)
	_settings_btn.custom_minimum_size = Vector2(84, UI.TAP_H)
	_settings_btn.name = "Settings"
	_callings_btn = UI.make_button("Callings", false, func(): _open("callings"), "click", 15)
	_sheet_btn = UI.make_button("Sheet", false, func(): _open("sheet"), "click", 15)
	_chandler_btn = UI.make_button("Shop", false, func(): _open("chandler"), "click", 15)
	_chandler_btn.name = "Shop"
	_chandler_btn.draw.connect(func(): Chandler.draw_badge(_chandler_btn, shop_badge, _t))
	_challenges_btn = UI.make_button("Challenges", false, func(): _open("challenges"), "click", 15)
	_challenges_btn.name = "Challenges"
	_challenges_btn.draw.connect(_draw_challenges_marks)
	for b in [_callings_btn, _sheet_btn, _chandler_btn, _challenges_btn]:
		UI.small_button(b, 15)
		b.custom_minimum_size = Vector2(96, 44)
	for b in [_play_btn, _back_btn, _settings_btn, _callings_btn, _sheet_btn, _chandler_btn, _challenges_btn]:
		add_child(b)
	_challenges_btn.visible = challenges_shown()
	_refresh()
	_offer_resume.call_deferred()


static func twist_name_of(h: Dictionary, world_n: int, level_id: String) -> String:
	## A level's twist name from its headers (its card's name in its level or
	## world, twists.gd card_of), or "".
	var c := Twists.card_of(Twists.id_from(str(h.get("twist", ""))), world_n, level_id)
	return str(c[0]) if not c.is_empty() else ""


func twist_line_y(i: int) -> float:
	## The twist name's baseline under a medallion's name (from its centre),
	## and the sigils' row moves down past it: 0.0 for a level with none.
	return 36.0 if str((_info[i] as Dictionary).get("twist", "")) != "" else 0.0


static func level_headers(path: String) -> Dictionary:
	## A level file's headers (UI.level_headers: read once a run; the map
	## needs only names, areas, Dreads, bosses and secrets, not the levels).
	return UI.level_headers(path)


func _read_secrets() -> void:
	## Each world's secret level in this build ({} for none): its id, the
	## level holding its exit, its name and area.
	_secrets = {}
	var reg := UI.secret_levels()
	for s in reg:
		if not (s is Dictionary) or not FileAccess.file_exists(str(s.get("path", ""))):
			continue
		var h := level_headers(str(s["path"]))
		var area_s := str(h.get("area", ""))
		var area := int(Game.area_of(str(s["id"]))) if Game.has_method("area_of") else 1
		if area_s.is_valid_int():
			area = int(area_s)
		_secrets[int(s["world"])] = {"id": str(s["id"]), "from": str(s.get("from", "")), "title": str(h.get("title", s["id"])), "area": area}


func _refresh() -> void:
	var pts := int(Game.hero().get("points", 0))
	_sheet_btn.text = "Sheet  +%d" % pts if pts > 0 else "Sheet"
	_sheet_btn.add_theme_color_override("font_color", UI.GOLD if pts > 0 else UI.CREAM)
	shop_badge = Game.shop_badge() if Game.has_method("shop_badge") else {}
	_chandler_btn.queue_redraw()
	queue_redraw()


# ---------------------------------------------------------------- worlds and levels

func world_open(w: int) -> bool:
	## World 1 always; a later world once its levels exist and its first is open here.
	if w == 1:
		return true
	var ids: Array = Game.levels_in_world(w)
	if ids.is_empty():
		return false
	return Game.is_unlocked(Game.index_of(ids[0]["id"]))


func worlds_built() -> Array:
	## The worlds with levels in this build, in order.
	var out: Array = []
	for info in Game.LEVELS:
		var w := int(info["world"])
		if not out.has(w):
			out.append(w)
	out.sort()
	return out


func world_indices(w: int) -> Array:
	var out: Array = []
	for i in Game.LEVELS.size():
		if int(Game.LEVELS[i]["world"]) == w:
			out.append(i)
	return out


func set_world(w: int) -> void:
	if not world_open(w) or w == world_tab:
		return
	world_tab = w
	focus_secret = ""
	var idx := world_indices(w)
	var best: int = idx[0]
	for i in idx:
		if Game.is_unlocked(i):
			best = i
	focus = best
	var s := get_node_or_null("/root/Sfx")
	if s:
		s.play("select")
	queue_redraw()
	_world_opened(w)


func _world_opened(w: int) -> void:
	if is_inside_tree():
		world_opened.emit(w)


func rec_level(i: int) -> int:
	## The recommended hero level: the level's area on this difficulty.
	return Combat.area_level(int(_info[i]["area"]), Game.diff())


func nodes() -> Dictionary:
	## Medallion centres for the open world: {global index: Vector2}.
	var vs := get_size()
	var idx := world_indices(world_tab)
	var out := {}
	var n := idx.size()
	for k in n:
		var f := float(k) / maxf(n - 1, 1)
		out[idx[k]] = Vector2(lerpf(vs.x * 0.17, vs.x * 0.83, f), lerpf(vs.y * 0.49, vs.y * 0.55, f) + sin(f * PI * 2.0) * 14.0)
	return out


# ---------------------------------------------------------------- secrets

func secret_of(w: int) -> Dictionary:
	## The world's secret level in this build ({} for none).
	return _secrets.get(w, {})


func secret_known(w: int) -> bool:
	## Its exit's level has been cleared (any difficulty): the spark and the
	## tab's "1 secret" show.
	var s := secret_of(w)
	if s.is_empty() or str(s["from"]) == "":
		return false
	for d in Combat.DIFFS:
		if cleared_on(str(s["from"]), d):
			return true
	return false


static func cleared_on(id: String, d: String) -> bool:
	## A level's record says cleared on d (read without making a record).
	var lv = (Game.data.get("levels", {}) as Dictionary).get(d, {})
	return lv is Dictionary and lv.get(id) is Dictionary and bool(lv[id].get("cleared", false))


func secret_found(w: int) -> bool:
	## Its silver bell has rung on this difficulty: its medallion shows.
	var s := secret_of(w)
	return not s.is_empty() and Game.has_method("secret_open") and bool(Game.secret_open(str(s["id"]), Game.diff()))


func secret_nodes() -> Dictionary:
	## The open world's secret medallions: {id: Vector2}, above-right of the
	## level holding its exit, only once its bell has rung.
	var out := {}
	if not secret_found(world_tab):
		return out
	var s := secret_of(world_tab)
	var i := Game.index_of(str(s["from"]))
	var N := nodes()
	if i >= 0 and N.has(i):
		out[str(s["id"])] = (N[i] as Vector2) + SECRET_AT
	return out


func spark_at(i: int) -> bool:
	## Level i holds its world's secret exit, cleared once: a silver spark
	## (until its bell rings: then the secret's own medallion branches off).
	var w := int(Game.LEVELS[i]["world"])
	var s := secret_of(w)
	return not s.is_empty() and str(s["from"]) == str(Game.LEVELS[i]["id"]) and secret_known(w) and not secret_found(w)


# ---------------------------------------------------------------- layout

func bell_rects() -> Array:
	## The three difficulty bells at top centre.
	var s := UI.safe_rect(get_viewport())
	var out: Array = []
	for i in Combat.DIFFS.size():
		out.append(Rect2(s.get_center().x - 105.0 + i * 70.0, s.position.y, 70.0, 42.0))
	return out


func pill_rect() -> Rect2:
	## Who's playing, top right (tap: the Sheet).
	var s := UI.safe_rect(get_viewport())
	var w: float = pill_words()["w"]
	return Rect2(s.end.x - w, s.position.y + 2.0, w, UI.TAP_H)


func pill_words() -> Dictionary:
	## The hero pill's words: {name: his own, size, sub: "Candleknight Lv 9",
	## w: the pill's width}, kept clear of the difficulty bells and their
	## chips: the name from 15 down to 12 beside his calling; a longer one
	## (or a narrow screen) leaves just "Lv 9" (the Sheet says the rest), then
	## the name alone, down to 10, cut short ("Bartholo…") only if it still
	## doesn't fit.
	var s := UI.safe_rect(get_viewport())
	var h: Dictionary = Game.hero()
	var lv := "Lv %d" % int(h["level"])
	var pad := 44.0 + (26.0 if int(h.get("points", 0)) > 0 else 0.0)
	var room: float = s.end.x - (bell_rects()[-1].end.x + PILL_GAP) - pad
	var nm := Game.hero_name()
	var tries := [["%s %s" % [Classes.info(str(h["cls"]))["name"], lv], PILL_NAME_MIN], [lv, 10], ["", 10]]
	var sub := ""
	var size := 10
	var r := room
	for t in tries:
		sub = t[0]
		r = room - UI.text_width(sub, 13, "body", 800)
		size = UI.fit_size(nm, r, 15, t[1], "title", 700)
		if UI.text_width(nm, size, "title", 700) <= r:
			break
	if UI.text_width(nm, size, "title", 700) > r:
		while nm.length() > 1 and UI.text_width(nm + "…", size, "title", 700) > r:
			nm = nm.substr(0, nm.length() - 1)
		nm = nm.strip_edges() + "…"
	var w := pad + UI.text_width(nm, size, "title", 700) + UI.text_width(sub, 13, "body", 800)
	return {"name": nm, "size": size, "sub": sub, "w": w}


func purse_rect() -> Rect2:
	## The embers and sigils, under the name plate.
	var s := UI.safe_rect(get_viewport())
	var sw := UI.text_width(_sigil_text(), 15, "body", 800)
	var ew := UI.text_width(str(Game.embers()), 15, "body", 800)
	var w := sw + 38.0 + ew + 22.0
	return Rect2(s.end.x - w, s.position.y + 48.0, w, 22.0)


func tab_rects() -> Array:
	## The world tabs' rects, in world order (as v2: other streams' tests
	## read it; tabs_by_world() says which is which).
	var T := tabs_by_world()
	var out: Array = []
	for w in worlds_built():
		out.append(T[w])
	return out


func tabs_by_world() -> Dictionary:
	## One tab per world in the build (World 1 and 2 only in a W1-W2
	## build), centred under the bells, clear of the purse: {world: Rect2}.
	var s := UI.safe_rect(get_viewport())
	var ws := worlds_built()
	var out := {}
	var n := ws.size()
	if n == 0:
		return out
	var cx := s.get_center().x
	var gap := 6.0
	var half := minf(cx - s.position.x - 80.0, purse_rect().position.x - 10.0 - cx)
	var w := clampf((2.0 * half - gap * (n - 1)) / n, 44.0, 100.0 if n <= 2 else 62.0)
	var x0 := cx - (n * w + (n - 1) * gap) * 0.5
	for k in n:
		out[ws[k]] = Rect2(x0 + k * (w + gap), s.position.y + 46.0, w, UI.TAP_H)
	return out


func name_rect() -> Rect2:
	## Where the world's name (and its "1 secret", or a picked secret's line)
	## draws: tests keep it clear of the tabs and the medallions.
	var vs := get_size()
	var size := 25 if world_open(2) else 27
	var y := name_baseline()
	var name := str(Game.WORLD_NAMES.get(world_tab, Game.WORLD_NAME))
	var w := UI.text_width(name, UI.fit_size(name, vs.x * 0.5, size, 16, "title", 700), "title", 700)
	var extra := 0.0
	if focus_secret != "":
		var sec := secret_of(world_tab)
		var line := "%s  ·  Lv %d" % [str(sec.get("title", focus_secret)), Combat.area_level(int(sec.get("area", 1)), Game.diff())]
		w = UI.text_width(line, UI.fit_size(line, vs.x * 0.55, size, 16, "title", 700), "title", 700)
		extra = 12.0 + 3 * 19.0
	elif secret_known(world_tab):
		extra = 14.0 + 14.0 + UI.text_width("1 secret", 12, "body", 800)
	return Rect2(vs.x * 0.5 - w * 0.5, y - float(size) * 0.8, w + extra, float(size) * 1.05)


func name_baseline() -> float:
	var s := UI.safe_rect(get_viewport())
	return s.position.y + (114.0 if world_open(2) else 100.0)


func challenges_shown() -> bool:
	## The Challenges button: once the modes' hub is open (ModesSave says, or
	## 1-2 cleared without it) and the hub is in the build.
	if not ResourceLoader.exists(modes_screen):
		return false
	var lib = _modes()
	if lib != null and lib.has_method("hub_open"):
		return bool(lib.hub_open())
	for d in Combat.DIFFS:
		if cleared_on(HUB_FROM, d):
			return true
	return false


func _modes():
	if _modes_lib == null:
		_modes_lib = load(MODES_SAVE) if ResourceLoader.exists(MODES_SAVE) else false
	return _modes_lib if not (_modes_lib is bool) else null


func challenges_news() -> bool:
	var lib = _modes()
	return lib != null and lib.has_method("has_news") and bool(lib.has_news())


func challenges_resume() -> bool:
	## A Descent run waiting for this calling (ModesSave.has_suspended(cls),
	## else the modes' save block's runs[cls]).
	var cls := str(Game.hero().get("cls", ""))
	var lib = _modes()
	if lib != null and lib.has_method("has_suspended"):
		return bool(lib.has_suspended(cls))
	var md = Game.data.get("modes", {})
	if md is Dictionary and md.get("descent") is Dictionary:
		var runs = md["descent"].get("runs", {})
		return runs is Dictionary and runs.get(cls) is Dictionary and not (runs[cls] as Dictionary).is_empty()
	return false


# ---------------------------------------------------------------- going in

func _play_pressed() -> void:
	if focus_secret != "":
		_go_secret(focus_secret)
	else:
		_go(focus)


func _go(i: int) -> void:
	if not Game.is_unlocked(i):
		_sfx("back")
		return
	var warn := warning_for(i)
	if not warn.is_empty():
		card(WARN_ID, str(warn["title"]), str(warn["body"]), func(): _go(i))
		return
	_sfx("select")
	play.emit(i)


func _go_secret(id: String) -> void:
	var warn := warning_for_secret(id)
	if not warn.is_empty():
		card(WARN_ID, str(warn["title"]), str(warn["body"]), func(): _go_secret(id))
		return
	_sfx("select")
	play_secret.emit(id)


func warning_for(i: int) -> Dictionary:
	## The one-time card before a level on Nightfall or the Witching Hour the
	## hero is more than WARN_UNDER levels under ({title, body}, else {}).
	return _warning_under(rec_level(i))


func warning_for_secret(id: String) -> Dictionary:
	## The same card before a secret level (its header's area).
	for w in _secrets:
		if str(_secrets[w]["id"]) == id:
			return _warning_under(Combat.area_level(int(_secrets[w].get("area", 1)), Game.diff()))
	return {}


func _warning_under(rec: int) -> Dictionary:
	var d := Game.diff()
	if d == "dusk" or not Game.has_method("notice") or _noticed(WARN_ID):
		return {}
	if int(Game.hero()["level"]) >= rec - WARN_UNDER:
		return {}
	var need := int(Combat.diff(d).get("area0", 30))
	return {"title": str(Combat.diff(d)["name"]),
			"body": "The Vigil runs deeper now. This dark is for Wicks of level %d and more." % need}


func _noticed(id: String) -> bool:
	var n = Game.data.get("notices", [])
	return n is Array and (n as Array).has(id)


func _sfx(name: String, pitch := 1.0) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s:
		s.play(name, pitch)


func set_difficulty(d: String) -> void:
	if not Game.diff_open(d):
		_deny = 1.0
		_deny_d = d
		_show_note(bell_note(d))
		_sfx("back")
		return
	if d != Game.diff():
		Game.set_diff(d)
		_sfx("select")
		focus_secret = ""
		# Keep the focus on an open level.
		if not Game.is_unlocked(focus):
			focus = maxi(Game.unlocked_count() - 1, 0)
			focus = clampi(focus, 0, Game.LEVELS.size() - 1)
			var w := int(Game.LEVELS[focus]["world"])
			if w != world_tab:
				world_tab = w
				_world_opened(w)
	queue_redraw()


# ---------------------------------------------------------------- the buttons

func _open(what: String) -> void:
	## Callings, Sheet, Chandler or Challenges: main.gd opens it (it hooks
	## them all). The Challenges with nothing listening: the hub, here.
	var sig: Signal = {"callings": callings, "sheet": sheet, "chandler": chandler, "challenges": challenges}[what]
	if what == "challenges" and sig.get_connections().is_empty():
		if ResourceLoader.exists(modes_screen):
			var h = load(modes_screen).new()
			if h.has_signal("back"):
				h.back.connect(_close_overlay)
			_show_overlay(h)
		return
	sig.emit()


func _show_overlay(c: Control) -> void:
	_close_overlay()
	_overlay = c
	add_child(c)


func _close_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_refresh()


# ---------------------------------------------------------------- one-time cards

func card(id: String, title: String, body: String, then := Callable(), ok := "OK", alt := "", alt_then := Callable()) -> void:
	## A card over the map; OK closes it, marks it seen (Game.notice(id))
	## and runs then. With alt, a second button beside OK runs alt_then
	## instead. A tap off the card, after a moment, closes it too (marked
	## seen, running neither).
	_card = {"id": id, "title": title, "body": body, "then": then, "t": 0.0, "emblem": 3 if id == "v3_update" else 0,
			"alt": alt, "alt_then": alt_then}
	if _cardv == null:
		_cardv = Control.new()
		_cardv.name = "Card"
		_cardv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cardv.mouse_filter = Control.MOUSE_FILTER_STOP
		_cardv.draw.connect(_draw_card_layer)
		_cardv.gui_input.connect(_card_input)
		add_child(_cardv)
		_card_ok = UI.make_button("OK", true, func(): close_card(), "select", 18)
		_card_ok.custom_minimum_size = Vector2(140, 44)
		_cardv.add_child(_card_ok)
		_card_alt = UI.make_button("", false, func(): close_card(true), "back", 16)
		_card_alt.custom_minimum_size = Vector2(120, 44)
		_cardv.add_child(_card_alt)
	_card_ok.text = ok
	_card_alt.text = alt
	_card_alt.visible = alt != ""
	_cardv.visible = true
	_layout_card()


func card_showing() -> bool:
	return not _card.is_empty()


func _offer_resume() -> void:
	## A level left at an altar (its resume snapshot saved): offered once,
	## when main.gd can take it (it listens to resume_altar).
	if not is_inside_tree() or card_showing() or resume_altar.get_connections().is_empty() or not Game.has_method("suspended"):
		return
	var sus: Dictionary = Game.suspended()
	if sus.is_empty() or str(sus.get("level", "")) == "":
		return
	var key := "%s@%s" % [sus.get("level", ""), sus.get("at", "")]
	if key == _resume_offered:
		return
	_resume_offered = key
	var lid := str(sus["level"])
	var title := str(Game.level_title(lid)) if Game.has_method("level_title") else ""
	var d := str(sus.get("diff", Game.diff()))
	# The altar's number on the way: how many he'd lit (the file's index is
	# reading order, not the route's: a level played right to left, or one
	# whose later altars stand higher); an older snapshot's index.
	var n: int = (sus["lit"] as Array).size() if sus.get("lit") is Array and not (sus["lit"] as Array).is_empty() else int(sus.get("altar", 0)) + 1
	var body := "%s %s · altar %d · %s" % [lid, title, n, str(Combat.diff(d)["name"])]
	card("", "Continue from the altar", body, func(): resume_altar.emit(sus), "Continue", "Not now")


func card_panel() -> Rect2:
	var s := UI.safe_rect(get_viewport())
	return UI.card_rect(get_size(), s, str(_card.get("body", "")))


func close_card(alt := false) -> void:
	if _card.is_empty():
		return
	var id := str(_card["id"])
	var then: Callable = _card.get("alt_then" if alt else "then", Callable())
	_card = {}
	if _cardv != null:
		_cardv.visible = false
	if id != "" and Game.has_method("notice"):
		Game.notice(id)
	if then.is_valid():
		then.call()
	queue_redraw()


func _layout_card() -> void:
	if _card_ok == null or _card.is_empty():
		return
	var r := card_panel()
	_card_ok.reset_size()
	_card_ok.position = Vector2(r.get_center().x - _card_ok.size.x * 0.5, r.end.y - _card_ok.size.y - 12.0)
	if _card_alt.visible:
		_card_alt.reset_size()
		var w := _card_ok.size.x + 14.0 + _card_alt.size.x
		_card_alt.position = Vector2(r.get_center().x - w * 0.5, _card_ok.position.y)
		_card_ok.position.x = _card_alt.position.x + _card_alt.size.x + 14.0


func _card_input(event: InputEvent) -> void:
	# A tap outside the panel, once it's been up a moment, closes it too.
	if UI.is_tap(event) and float(_card.get("t", 0.0)) > 0.6 and not card_panel().has_point(event.position):
		close_card(true)   # seen, but not a choice: nothing goes in


func _draw_card_layer() -> void:
	if _card.is_empty():
		return
	var ci := _cardv
	var a := clampf(float(_card["t"]) * 5.0, 0.0, 1.0)
	ci.draw_rect(Rect2(Vector2.ZERO, ci.get_size()), Color(0.02, 0.01, 0.04, 0.7 * a))
	var r := card_panel()
	r.position.y += (1.0 - a) * 10.0
	var col := UI.GOLD
	var em := int(_card.get("emblem", 0))
	if em > 0:
		col = UI.world_accent(em)
	UI.draw_card(ci, r, str(_card["title"]), str(_card["body"]), col, a, em)


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if _overlay != null or not _card.is_empty():
		return
	var tapped := UI.is_tap(event)   # one tap, once (not its touch twin too)
	if not tapped:
		return
	var p: Vector2 = event.position
	var B := bell_rects()
	for i in B.size():
		if (B[i] as Rect2).has_point(p):
			set_difficulty(Combat.DIFFS[i])
			return
	if pill_rect().has_point(p):
		_open("sheet")
		return
	if world_open(2):
		var T := tabs_by_world()
		for w in T:
			if (T[w] as Rect2).has_point(p):
				if world_open(w):
					set_world(w)
				else:
					_deny = 1.0
					_deny_d = ""
					_show_note(tab_note(w))
					_sfx("back")
				return
	var S := secret_nodes()
	for id in S:
		if p.distance_to(S[id]) < SECRET_R + 12.0:
			if focus_secret == id:
				_go_secret(id)
			else:
				focus_secret = id
				_sfx("select", 1.5)
				queue_redraw()
			return
	var N := nodes()
	for i in N:
		if p.distance_to(N[i]) < 46.0:
			if i == focus and focus_secret == "":
				_go(i)
			elif Game.is_unlocked(i):
				focus = i
				focus_secret = ""
				_sfx("select", Sfx.note(i % 8))
				queue_redraw()
			else:
				_sfx("back")
			return


func _unhandled_input(event: InputEvent) -> void:
	if _overlay != null:
		return
	if not _card.is_empty():
		if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			close_card()
		return
	var idx := world_indices(world_tab)
	var k := idx.find(focus)
	if event.is_action_pressed("right") and k + 1 < idx.size() and Game.is_unlocked(idx[k + 1]):
		focus = idx[k + 1]
		focus_secret = ""
	elif event.is_action_pressed("left") and k > 0:
		focus = idx[k - 1]
		focus_secret = ""
	elif event.is_action_pressed("jump"):
		_play_pressed()


func _process(dt: float) -> void:
	_t += dt
	_deny = maxf(_deny - dt * 3.0, 0.0)
	_note_t = maxf(_note_t - dt, 0.0)
	var s := UI.safe_rect(get_viewport())
	_back_btn.position = s.position + Vector2(0, 2)
	_back_btn.reset_size()
	_settings_btn.reset_size()
	_settings_btn.position = _back_btn.position + Vector2(_back_btn.size.x + 8.0, 0.0)
	_play_btn.reset_size()
	_play_btn.position = Vector2(s.end.x - _play_btn.size.x, s.end.y - _play_btn.size.y - 2.0)
	var x := s.position.x
	for b in [_callings_btn, _sheet_btn, _chandler_btn, _challenges_btn]:
		if not b.visible:
			continue
		b.reset_size()
		b.position = Vector2(x, s.end.y - b.size.y - 4.0)
		x += b.size.x + 8.0
	# main.gd's Feel lab button (placed after the Chandler each frame, before
	# this runs) goes after the last of these.
	var lab := get_node_or_null("FeelLab")
	if lab is Control and _challenges_btn.visible:
		(lab as Control).position = Vector2(x + 4.0, (lab as Control).position.y)
	if not _card.is_empty():
		_card["t"] = float(_card["t"]) + dt
		_layout_card()
		_cardv.queue_redraw()
	if _challenges_btn.visible:
		_marks["t"] = float(_marks["t"]) - dt
		if float(_marks["t"]) <= 0.0:
			_marks = {"news": challenges_news(), "resume": challenges_resume(), "t": 0.5}
		_challenges_btn.queue_redraw()
	if str(shop_badge.get("kind", "")) == "new":
		_chandler_btn.queue_redraw()   # its dot breathes
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var vs := get_size()
	var s := UI.safe_rect(get_viewport())
	UI.backdrop(self, vs)
	_draw_bells()
	_draw_pill()
	_draw_purse(s)
	# The world: its tabs once World 2 is open, and its name.
	var accent := UI.world_accent(world_tab) if world_open(2) else UI.GOLD
	if world_open(2):
		_draw_tabs()
		_draw_name(vs, name_baseline(), 25, accent)
	else:
		UI.text(self, Vector2(0, s.position.y + 66.0), "World %d" % world_tab, 14, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "body", 700)
		_draw_name(vs, name_baseline(), 27, UI.GOLD)
	if _note_t > 0.0 and _note != "":
		_draw_note()
	var N := nodes()
	var keys: Array = N.keys()
	keys.sort()
	for k in keys.size() - 1:
		var a: Vector2 = N[keys[k]]
		var b: Vector2 = N[keys[k + 1]]
		var lit := Game.is_unlocked(keys[k + 1])
		for j in range(1, 9):
			var p := a.lerp(b, j / 9.0)
			if lit:
				draw_circle(p, 4.0, Color(1.0, 0.7, 0.3, 0.15))
			draw_circle(p, 2.6 if lit else 2.2, Color(UI.EMBER, 0.9) if lit else Color(0.4, 0.36, 0.5, 0.6))
	_draw_secret_branches(N)
	for i in keys:
		_medallion(i, N[i])
		if spark_at(i) and Game.is_unlocked(i):
			_draw_spark(N[i])
	var S := secret_nodes()
	for id in S:
		_secret_medallion(str(id), S[id])


func _draw_name(vs: Vector2, y: float, size: int, col: Color) -> void:
	## The world's name (or the picked secret's), with "1 secret" after it
	## once its exit's level is cleared.
	var name := str(Game.WORLD_NAMES.get(world_tab, Game.WORLD_NAME))
	if focus_secret != "":
		var sec := secret_of(world_tab)
		var lv := Combat.area_level(int(sec.get("area", 1)), Game.diff())
		var line := "%s  ·  Lv %d" % [str(sec.get("title", focus_secret)), lv]
		var lf := UI.fit_size(line, vs.x * 0.55, size, 16, "title", 700)
		var lw := UI.text_width(line, lf, "title", 700)
		UI.text(self, Vector2(0, y), line, lf, UI.SILVER, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 6)
		# Its sigils after it.
		var full := UI.tex("res://art/props/sigil.svg")
		var empty := UI.tex("res://art/ui/sigil_empty.svg")
		var srec: Dictionary = Game.level_record(focus_secret)
		for k in 3:
			var t: Texture2D = full if srec["sigils"][k] else empty
			if t:
				draw_texture_rect(t, Rect2(vs.x * 0.5 + lw * 0.5 + 12.0 + k * 19.0, y - 15.0, 17, 17), false)
		return
	var fs := UI.fit_size(name, vs.x * 0.5, size, 16, "title", 700)
	UI.text(self, Vector2(0, y), name, fs, col, HORIZONTAL_ALIGNMENT_CENTER, vs.x, "title", 700, 6)
	if secret_known(world_tab):
		var nw := UI.text_width(name, fs, "title", 700)
		var x := vs.x * 0.5 + nw * 0.5 + 14.0
		var tb := UI.batch()
		UI.sparkle(tb, Vector2(x + 5.0, y - 7.0), 6.0, UI.SILVER)
		tb.flush(self)
		UI.text(self, Vector2(x + 14.0, y - 2.0), "1 secret", 12, Color(UI.SILVER, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3)


func bell_note(d: String) -> String:
	## Why a locked bell won't ring: its difficulty waits for the Hush.
	if Game.has_method("diff_waits") and Game.diff_waits(d):
		return "Waits beneath the Hush. Your clears are kept."
	return "Opens when the Hush sleeps on %s" % str(Combat.diff(Combat.DIFFS[maxi(Combat.DIFFS.find(d) - 1, 0)])["name"])


func tab_note(w: int) -> String:
	## Why a locked world's tab won't open: the bell before its first level.
	var ids: Array = Game.levels_in_world(w)
	if ids.is_empty():
		return "World %d waits deeper down" % w
	var i := Game.index_of(ids[0]["id"])
	if i <= 0:
		return "World %d waits deeper down" % w
	return "Ring %s's bell to open World %d" % [str(Game.LEVELS[i - 1]["id"]), w]


func _show_note(text: String) -> void:
	_note = text
	_note_t = NOTE_TIME


func note_text() -> String:
	## The note showing now, else "" (tests).
	return _note if _note_t > 0.0 else ""


func note_rect() -> Rect2:
	## Over the world's name line (covering it, the name's own width or
	## more), clear of the tabs and the bells.
	var nr := name_rect()
	var w := maxf(UI.text_width(_note, 13, "body", 700) + 28.0, nr.size.x + 16.0)
	var top := nr.position.y - 4.0
	var T := tabs_by_world() if world_open(2) else {}
	for t in T.values():
		top = maxf(top, (t as Rect2).end.y + 2.0)
	return Rect2(get_size().x * 0.5 - w * 0.5, top, w, nr.end.y + 4.0 - top)


func _draw_note() -> void:
	var a := clampf(_note_t * 3.0, 0.0, 1.0) * clampf((NOTE_TIME - _note_t) * 8.0, 0.0, 1.0)
	var r := note_rect()
	UI.panel(self, r, Color(UI.PANEL_EDGE, 0.9 * a), Color(UI.PANEL, a), 10.0)
	UI.text(self, Vector2(r.position.x, r.get_center().y + 5.0), _note, 13, Color(UI.CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, "body", 700)


func _draw_bells() -> void:
	var B := bell_rects()
	var cur := Game.diff()
	for i in B.size():
		var d: String = Combat.DIFFS[i]
		var r: Rect2 = B[i]
		var open := Game.diff_open(d)
		var on := d == cur
		var c := Vector2(r.get_center().x, r.position.y + 14.0)
		var shake := sin(_t * 60.0) * 3.0 * _deny if not open and _deny_d == d else 0.0
		if on:
			draw_circle(c, 17.0, Color(1.0, 0.78, 0.35, 0.12 + 0.05 * sin(_t * 3.0)))
		var col := UI.GOLD if on else (UI.CREAM.darkened(0.25) if open else Color(UI.MUTED, 0.35))
		var sw := sin(_t * 2.4 + i) * 0.12 if on else 0.0
		draw_set_transform(c + Vector2(shake, -8.0), sw, Vector2.ONE)
		UI.glyph(self, "bell", Vector2(0, 8.0), 22.0, col)
		draw_set_transform(Vector2.ZERO)
		if not open:
			UI.glyph(self, "lock", c + Vector2(9.0, 7.0), 10.0, Color(UI.MUTED, 0.7))
		var name: String = str(Combat.diff(d)["name"]).to_upper()
		UI.text(self, Vector2(r.position.x - 10.0, r.end.y - 2.0), name, 9, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20.0, "body", 800)
		# The deeper dark's level: "Lv 30+" / "Lv 40+" at the bell's shoulder.
		var from := int(Combat.diff(d).get("area0", 1))
		if from > 1:
			var chip := "Lv %d+" % from
			var cw := UI.text_width(chip, 8, "body", 800) + 8.0
			var cr := Rect2(c.x + 11.0, c.y - 14.0, cw, 12.0)
			var ccol := UI.CREAM if open else Color(UI.MUTED, 0.6)
			if open and int(Game.hero()["level"]) < from - WARN_UNDER:
				ccol = UI.BAD
			var sb := UI.box()
			sb.bg_color = Color(UI.INK, 0.85)
			sb.border_color = Color(ccol, 0.55)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(6)
			sb.draw(get_canvas_item(), cr)
			UI.text(self, Vector2(cr.position.x, cr.position.y + 9.0), chip, 8, ccol, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, "body", 800)


func chip_rect(d: String) -> Rect2:
	## Where a deeper difficulty's "Lv 30+" chip draws (tests), or Rect2().
	var i := Combat.DIFFS.find(d)
	var from := int(Combat.diff(d).get("area0", 1)) if i >= 0 else 1
	if from <= 1:
		return Rect2()
	var r: Rect2 = bell_rects()[i]
	var c := Vector2(r.get_center().x, r.position.y + 14.0)
	return Rect2(c.x + 11.0, c.y - 14.0, UI.text_width("Lv %d+" % from, 8, "body", 800) + 8.0, 12.0)


func _draw_tabs() -> void:
	var T := tabs_by_world()
	var tb := UI.batch()
	var texts: Array = []
	for w in T:
		var r: Rect2 = T[w]
		var open := world_open(w)
		var on: bool = w == world_tab
		var acc := UI.world_accent(w)
		UI.panel(self, r, acc if on else (Color(acc, 0.45) if open else Color(UI.PANEL_EDGE, 0.4)),
				Color("3a2a1a") if on else (Color("1d1529") if open else Color("141019")), 9.0)
		var wide := r.size.x >= 90.0   # a W1-W2 build: "World 1"
		if wide:
			texts.append([Vector2(r.position.x, r.position.y + 26.0), "World %d" % w, 15, acc if on else UI.MUTED, r.size.x])
			continue
		var ec := Vector2(r.position.x + r.size.x * 0.5 - 7.0, r.get_center().y)
		if open:
			UI.world_emblem(self, w, ec, 22.0, Color(acc, 1.0 if on else 0.55))
		else:
			UI.glyph(self, "lock", ec, 16.0, Color(UI.MUTED, 0.45))
		texts.append([Vector2(ec.x + 12.0, r.get_center().y + 6.0), str(w), 16, acc if on else (UI.MUTED if open else Color(UI.MUTED, 0.4)), -1])
		if open and secret_known(w):
			UI.sparkle(tb, Vector2(r.end.x - 7.0, r.position.y + 7.0), 5.0 if not secret_found(w) else 6.5, UI.SILVER)
	tb.flush(self)
	for t in texts:
		UI.text(self, t[0], t[1], t[2], t[3], HORIZONTAL_ALIGNMENT_CENTER if float(t[4]) > 0.0 else HORIZONTAL_ALIGNMENT_LEFT, t[4], "body", 800)


func _draw_pill() -> void:
	var r := pill_rect()
	var h: Dictionary = Game.hero()
	var cls := str(h["cls"])
	var col := UI.class_color(cls)
	UI.panel(self, r, Color(col, 0.7), Color("241b30"), 20.0)
	var c := Vector2(r.position.x + 17.0, r.get_center().y)
	draw_circle(c, 8.0, UI.INK)
	draw_circle(c, 6.5, col)
	var pw := pill_words()
	UI.text(self, Vector2(r.position.x + 32.0, r.get_center().y + 6.0), pw["name"], pw["size"], UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "title", 700)
	var nx := r.position.x + 38.0 + UI.text_width(pw["name"], pw["size"], "title", 700)
	UI.text(self, Vector2(nx, r.get_center().y + 5.0), pw["sub"], 13, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800)
	if int(h.get("points", 0)) > 0:
		var p := Vector2(r.end.x - 15.0, r.get_center().y)
		var pulse := 1.0 + 0.1 * sin(_t * 5.0)
		draw_circle(p, 9.0 * pulse, UI.GOLD)
		UI.glyph(self, "plus", p, 11.0, UI.INK)


func _sigil_text() -> String:
	## "12 / 90": this difficulty's sigils of every level built (a secret
	## level holds three too).
	var n := Game.LEVELS.size() + _secrets.size()
	return "%d / %d" % [Game.sigil_count(), n * 3]


func _draw_purse(s: Rect2) -> void:
	## Embers and this difficulty's sigils, under the name plate.
	var y := s.position.y + 60.0
	var x := s.end.x
	var sig := _sigil_text()
	var sw := UI.text_width(sig, 15, "body", 800)
	UI.text(self, Vector2(x - sw, y + 5.0), sig, 15, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3)
	var st := UI.tex("res://art/props/sigil.svg")
	if st:
		draw_texture_rect(st, Rect2(x - sw - 24.0, y - 10.0, 20, 20), false)
	var em := str(Game.embers())
	var ew := UI.text_width(em, 15, "body", 800)
	var ex := x - sw - 38.0 - ew
	UI.text(self, Vector2(ex, y + 5.0), em, 15, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, "body", 800, 3)
	UI.ember_icon(self, Vector2(ex - 12.0, y), 9.0)


func _medallion(i: int, c: Vector2) -> void:
	var open := Game.is_unlocked(i)
	var rec: Dictionary = Game.level_record(Game.LEVELS[i]["id"]) if open else {}
	var cleared: bool = rec.get("cleared", false)
	var sel := i == focus and focus_secret == ""
	var r := 32.0 + (3.0 * sin(_t * 4.0) if sel else 0.0)
	if sel:
		draw_circle(c, r + 14.0, Color(1.0, 0.75, 0.35, 0.10))
		draw_circle(c, r + 8.0, Color(1.0, 0.75, 0.35, 0.14))
	draw_circle(c, r + 3.0, UI.INK)
	draw_circle(c, r, Color("3a2a1a") if open else Color("241d2e"))
	draw_arc(c, r - 3.0, 0, TAU, 40, UI.GOLD if cleared else (UI.PANEL_EDGE if open else Color("3a3148")), 3.0, true)
	var info: Dictionary = _info[i]
	UI.text(self, Vector2(c.x - 40, c.y + 9.0), info["sub"] if open else "?", 24, UI.GOLD if open else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 80, "title", 700)
	# The recommended level, above.
	var lv := rec_level(i)
	var hl := int(Game.hero()["level"])
	var tag := "Lv %d" % lv
	var tw := UI.text_width(tag, 11, "body", 800) + 14.0
	var tr := Rect2(c.x - tw * 0.5, c.y - r - 24.0, tw, 17.0)
	var tcol := UI.CREAM if hl >= lv else (UI.EMBER if hl >= lv - 2 else UI.BAD)
	if info["boss"] and open:
		# A little bell for the boss, beside the tag.
		UI.glyph(self, "bell", Vector2(c.x + r * 0.78, c.y - r * 0.78), 18.0, Color("c9a227"))
	UI.panel(self, tr, Color(tcol, 0.55 if open else 0.25), Color("1a1422", 0.95), 8.0)
	UI.text(self, Vector2(tr.position.x, tr.position.y + 13.0), tag, 11, Color(tcol, 1.0 if open else 0.5), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, "body", 800)
	var name_col := UI.CREAM if open else UI.MUTED
	UI.text(self, Vector2(c.x - 90, c.y + r + 22.0), info["title"] if open else "Locked", 15, name_col, HORIZONTAL_ALIGNMENT_CENTER, 180, "body", 700, 4)
	var dy := 0.0
	if open and twist_line_y(i) > 0.0:
		# Its twist, small and warm under the name: its rule, read on the map.
		var twn := str(info["twist"])
		UI.text(self, Vector2(c.x - 90, c.y + r + twist_line_y(i)), twn, UI.fit_size(twn, 180.0, 12, 10, "body", 700), Color(UI.EMBER, 0.95),
				HORIZONTAL_ALIGNMENT_CENTER, 180, "body", 700, 3)
		dy = 12.0
	if open:
		var n := 3 + (1 if info["dread"] else 0)
		var x0 := c.x - n * 10.0 + 1.0
		var full := UI.tex("res://art/props/sigil.svg")
		var empty := UI.tex("res://art/ui/sigil_empty.svg")
		for k in 3:
			var got: bool = rec["sigils"][k]
			var sr := Rect2(x0 + k * 20.0, c.y + r + 30.0 + dy, 18, 18)
			var tex: Texture2D = full if got else empty
			if tex:
				draw_texture_rect(tex, sr, false)
			else:
				draw_circle(sr.get_center(), 6.0, UI.GOLD if got else UI.MUTED)
		if info["dread"]:
			var beaten: bool = rec.get("dread", false)
			var sc := Vector2(x0 + 3 * 20.0 + 9.0, c.y + r + 39.0 + dy)
			if beaten:
				draw_circle(sc, 10.0, Color(1.0, 0.8, 0.3, 0.2))
			UI.glyph(self, "skull", sc, 17.0, UI.DREAD if beaten else Color(UI.MUTED, 0.45))


func _draw_spark(c: Vector2) -> void:
	## A small silver spark on the medallion of a level holding a secret way out.
	var tb := UI.batch()
	var p := c + Vector2(-26.0, -23.0)
	var k := 0.8 + 0.2 * sin(_t * 3.3)
	tb.circle(p, 11.0 * k, Color(UI.SILVER, 0.12), 16)
	tb.circle(p, 6.0, Color(UI.INK, 0.6), 12)
	UI.sparkle(tb, p, 8.5 * k, UI.SILVER)
	tb.flush(self)


func _draw_secret_branches(N: Dictionary) -> void:
	## A dotted silver branch from an exit's medallion up to its secret's.
	var S := secret_nodes()
	if S.is_empty():
		return
	var tb := UI.batch()
	for id in S:
		var sec := secret_of(world_tab)
		var i := Game.index_of(str(sec["from"]))
		if not N.has(i):
			continue
		var a: Vector2 = N[i]
		var b: Vector2 = S[id]
		var d := (b - a).normalized()
		var from := a + d * 36.0
		var to := b - d * (SECRET_R + 4.0)
		for j in range(0, 6):
			tb.circle(from.lerp(to, j / 5.0), 1.8, Color(UI.SILVER, 0.75), 8)
	tb.flush(self)


func _secret_medallion(id: String, c: Vector2) -> void:
	## A secret level: a silver disc with a bell-shaped window, ringed once
	## cleared, pulsing while picked.
	var sel := focus_secret == id
	var rec: Dictionary = Game.secret_record(id) if Game.has_method("secret_record") else {}
	var cleared := bool(rec.get("cleared", false)) or bool(Game.level_record(id)["cleared"])
	var r := SECRET_R + (2.0 * sin(_t * 4.0) if sel else 0.0)
	var tb := UI.batch()
	if sel:
		tb.circle(c, r + 11.0, Color(UI.SILVER, 0.10), 24)
		tb.circle(c, r + 6.0, Color(UI.SILVER, 0.14), 24)
	tb.circle(c, r + 3.0, UI.INK, 24)
	tb.circle(c, r, Color("2a2c40"), 24)
	tb.ring(c, r - 2.5, 2.5, UI.SILVER if cleared else UI.SILVER_DEEP, 28)
	# The bell-shaped window, glowing silver.
	var glow := 0.7 + 0.3 * sin(_t * 2.2)
	tb.circle(c + Vector2(0, -r * 0.3), r * 0.2, Color(UI.SILVER, glow), 12)
	tb.convex(PackedVector2Array([c + Vector2(-r * 0.2, -r * 0.3), c + Vector2(r * 0.2, -r * 0.3), c + Vector2(r * 0.3, r * 0.2),
			c + Vector2(r * 0.46, r * 0.42), c + Vector2(-r * 0.46, r * 0.42), c + Vector2(-r * 0.3, r * 0.2)]), Color(UI.SILVER, glow))
	tb.flush(self)


func _draw_challenges_marks() -> void:
	## On the Challenges button: a gold "!" for news, a pulsing ember while
	## this calling's Descent run waits.
	var b := _challenges_btn
	var tb := UI.batch()
	var news := bool(_marks["news"])
	var resume := bool(_marks["resume"])
	if news:
		tb.circle(Vector2(b.size.x - 6.0, 6.0), 8.0, UI.INK, 16)
		tb.circle(Vector2(b.size.x - 6.0, 6.0), 6.5, UI.GOLD, 16)
	if resume:
		var k := 1.0 + 0.15 * sin(_t * 5.0)
		var p := Vector2(8.0, 7.0)
		tb.circle(p, 6.0 * k, Color(UI.EMBER, 0.25), 12)
		tb.circle(p, 3.6 * k, UI.EMBER, 12)
	tb.flush(b)
	if news:
		UI.text(b, Vector2(b.size.x - 12.0, 10.5), "!", 11, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, 12.0, "body", 800)
