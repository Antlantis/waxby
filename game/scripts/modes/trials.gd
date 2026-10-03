extends "res://scripts/modes/mode.gd"
## The Vigil Trials (spec §7.4): Mother Taper's lessons, one room for each
## thing a calling can do, timed by a candle. Hollin speaks for her while
## she rests (Story.REST_SUBS).
##
## - A trial plays a fixed loadout (a borrowed hero: Game.borrow_hero): the
##   trial's level, its ranks, a Blessed starter kit at that item level
##   seeded by the id, an empty belt, at area_abs = that level, always on Dusk
##   numbers and Normal strength, so times compare. Nothing it does is
##   saved to the hero: no XP, loot or embers from kills.
## - Trial candles (the room's `marks:`) gate the bell: t touch, s a hero
##   shot, w a hero wave or fire, * any of those or a swing, k the foe on
##   that cell put out. The bell (the room's E) rises once every candle burns.
## - The clock starts on the first press after the 0.8 s title card and
##   stops at the bell; death is an instant restart (0.6 s), Retry is in
##   pause, and there's no limit.
## - Medals: Bronze for any finish, Silver <= 2.0 x B, Gold <= 1.5 x B, Dawn
##   <= 1.15 x B (trial_data.gd); embers on each first medal; the totals pay
##   cosmetics (cosmetics.gd).
##
## --autoplay=trial:<id> plays a trial with the bot (it walks to the bell;
## the candles need the kit, so it stops there).

const TrialData := preload("res://scripts/modes/trial_data.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Progression := preload("res://scripts/progression.gd")
const SELF := "res://scripts/modes/trials.gd"
const TILE := 32
const TITLE_WAIT := 0.8          # the clock waits for the title card
const BOX := {"t": 14.0, "*": 18.0, "s": 24.0, "w": 24.0, "k": 16.0}   # a candle's half-size, by kind (a shot's last place before it hits counts)
const LIGHT_R := 70.0
const LIGHT_S := 0.7
const MAX_LIT_LIGHTS := 8
const INPUTS := ["left", "right", "jump", "attack", "special"]
const TAPER := Color("7a5aa8")

var tid := "k1"
var marks: Array = []            # [{cell, kind, p, lit, foe}]
var clock := 0.0
var started := false
var done := false
var bell_up := false
var tries := 0                   # unfinished tries (deaths, retries) since the last finish written
var finish := {}                 # {id, time, medal, best, prev_medal, next, embers, cosmetics, line}
var _title_t := 0.0
var _bell := {}
var _bell_rope := Rect2()
var _lit_n := 0


static func make() -> Object:
	return load(SELF).new()


static func loadout(id: String) -> Dictionary:
	## The trial's borrowed hero: its level, ranks, Blessed kit, empty belt.
	var t: Dictionary = TrialData.TRIALS.get(id, TrialData.TRIALS["k1"])
	var lvl := int(t["level"])
	var h := Hero.blank(str(t["cls"]), lvl)
	h["xp"] = Progression.total_to(lvl)
	h["skills"] = TrialData.skills(id)
	h["points"] = maxi(lvl - 1 - TrialData.points_used(id), 0)
	var r := RandomNumberGenerator.new()
	r.seed = hash("trial:" + id)
	h["equip"] = Items.starter(str(t["cls"]), lvl, "magic", r)
	h["belt"] = []
	h["trial"] = id
	return h


static func play_trial(main_node: Node, id: String, tries_so_far := 0) -> Object:
	var m = make()
	m.main = main_node
	m.setup(id)
	m.tries = tries_so_far
	m.begin()
	return m


static func autoplay(main_node: Node, arg: String) -> void:
	ModesSave.force_open = true
	play_trial(main_node, arg if TrialData.built(arg) else "k1")


func setup(id_: String) -> void:
	id = "trial"
	tid = id_
	mode_diff = "dusk"
	mode_strength = "normal"


func begin() -> void:
	clock = 0.0
	started = false
	done = false
	bell_up = false
	_title_t = 0.0
	_lit_n = 0
	finish = {}
	var g := game()
	if g != null:
		g.borrow_hero(loadout(tid))
	var data := level_data()
	if data != null:
		play(data)


func level_data() -> RefCounted:
	var p := TrialData.path(tid)
	if not FileAccess.file_exists(p):
		return null
	var text := FileAccess.get_file_as_string(p)
	var lv := parse_level(text, "trial-%s" % tid, 0)
	marks = []
	for part in str(lv.headers.get("marks", "")).split(";", false):
		var bits := part.split(",")
		if bits.size() < 3:
			continue
		var cell := Vector2i(int(bits[0]), int(bits[1]))
		marks.append({"cell": cell, "kind": bits[2].strip_edges(), "p": LevelData.cell_center(cell), "lit": false, "foe": null})
	return lv


static func assist_cells(lv: RefCounted) -> Array:
	## The bot's stand-in ledges (the room's `assist:`), for tests.
	var out: Array = []
	for part in str(lv.headers.get("assist", "")).split(";", false):
		out.append(Vector2i(int(part.get_slice(",", 0)), int(part.get_slice(",", 1))))
	return out


# ---------------------------------------------------------------- the World's hooks

func on_build(w: Node) -> void:
	super.on_build(w)
	# The kill candles' foes (the monster placed on each's cell).
	for m in marks:
		if m["kind"] != "k":
			continue
		for e in w.enemies:
			if e.spawn.get("cell", Vector2i(-1, -1)) == m["cell"]:
				m["foe"] = e
	# The bell waits for the candles.
	if not w.bells.is_empty() and not marks.is_empty():
		_bell = w.bells[0]
		_bell_rope = _bell["rope"]
		_bell["rope"] = Rect2(-99999, -99999, 1, 1)
		_show_bell(w, false)
	else:
		bell_up = true
	_pill()


func _show_bell(w: Node, on: bool) -> void:
	if _bell.is_empty():
		return
	(_bell["sprite"] as Node2D).visible = on
	# Its beam: the sprite add_bell put just above it.
	var top: Vector2 = _bell["top"]
	for c in w.get_node("Props").get_children():
		if c is Sprite2D and (c as Sprite2D).position.distance_to(top - Vector2(32, 10)) < 0.5:
			(c as Sprite2D).visible = on


func _raise_bell(w: Node) -> void:
	bell_up = true
	if _bell.is_empty():
		return
	_bell["rope"] = _bell_rope
	_show_bell(w, true)
	var gl = w.get("glow")
	if gl != null:
		gl.burst(_bell["top"] + Vector2(0, 40), 26, Color("ffd84a"), 180.0, 0.9, 40.0, 2.6)
	play_sfx("bell", 1.2)
	toast("The bell rises", "")


func on_tick(w: Node, dt: float) -> void:
	tick_look(w)
	_title_t += dt
	var p: Node2D = w.player
	if not started and _title_t >= TITLE_WAIT:
		for k in INPUTS:
			if bool(p.pad.get(k, false)):
				started = true
				play_sfx("trial_go")
				break
	if started and not done and w.state == "play":
		clock += dt
	if not done and w.state == "play":
		_light_candles(w)
		if not bell_up and marks.all(func(m): return m["lit"]):
			_raise_bell(w)
	if w.state == "clear" and not done:
		done = true
		_finish(w)
	_pill()


func _light_candles(w: Node) -> void:
	var p: Node2D = w.player
	var body: Rect2 = p.rect()
	var swing: Rect2 = p.attack_rect()
	for m in marks:
		if m["lit"]:
			continue
		var kind: String = m["kind"]
		var half := float(BOX.get(kind, 14.0))
		var box := Rect2(m["p"] - Vector2(half, half), Vector2(half, half) * 2.0)
		var lit := false
		match kind:
			"t":
				lit = body.intersects(box)
			"*":
				lit = body.intersects(box) or (swing.size.x > 0.0 and swing.intersects(box)) or _shot_in(w, box) or _wave_in(w, box)
			"s":
				lit = _shot_in(w, box)
			"w":
				lit = _wave_in(w, box)
			"k":
				var f = m["foe"]
				lit = f == null or not is_instance_valid(f) or not f.alive
		if lit:
			_light(w, m)


func _shot_in(w: Node, box: Rect2) -> bool:
	for s in w.shots:
		if s["owner"] == "player" and box.grow(float(s.get("radius", 6.0))).has_point(s["pos"]):
			return true
	return false


func _wave_in(w: Node, box: Rect2) -> bool:
	for h in w.hazards:
		if h.get("owner", "enemy") == "player" and float(h.get("delay", 0.0)) <= 0.0 and h.has("rect") and (h["rect"] as Rect2).intersects(box):
			return true
	return false


func _light(w: Node, m: Dictionary) -> void:
	m["lit"] = true
	_lit_n += 1
	var s := sfx()
	var pitch := 1.0
	if s != null and s.has_method("note"):
		pitch = float(s.note(_lit_n + 2))
	play_sfx("candle_lit", pitch)
	var gl = w.get("glow")
	if gl != null:
		gl.burst(m["p"], 14, Color("f7b64a"), 120.0, 0.6, -40.0, 2.2)


func lit_count() -> int:
	return marks.filter(func(m): return m["lit"]).size()


func lights() -> Array:
	var out: Array = []
	for m in marks:
		if m["lit"] and out.size() < MAX_LIT_LIGHTS:
			out.append({"p": m["p"], "r": LIGHT_R, "s": LIGHT_S, "gameplay": false, "tag": "deco"})
	return out


func draw_glow(glow: Node2D) -> void:
	## The candles, above the dark: an unlit violet taper in an iron cup, or
	## a lit one with the Tallow flame (the art's trial_candle_* when drawn).
	for m in marks:
		var p: Vector2 = m["p"]
		var base := p + Vector2(0, 6)
		glow.draw_rect(Rect2(base + Vector2(-5, 6), Vector2(10, 4)), Color("3a3148"))
		glow.draw_rect(Rect2(base + Vector2(-3, -8), Vector2(6, 14)), TAPER if not m["lit"] else TAPER.lightened(0.25))
		glow.draw_rect(Rect2(base + Vector2(-0.5, -11), Vector2(1, 3)), Color("1c1830"))
		if m["lit"]:
			glow.flame(base + Vector2(0, -10), 9.0, p.x * 0.1)
		elif m["kind"] == "k":
			glow.draw_rect(Rect2(base + Vector2(-6, -14), Vector2(12, 1.5)), Color(0.9, 0.3, 0.3, 0.6))


func on_snuffed(_w: Node) -> String:
	play_sfx("trial_fail")   # (A7's; its fallback until rendered)
	return "restart"


func allows(what: String) -> bool:
	return not ["xp", "loot", "embers", "record"].has(what)


func elite_rules() -> Dictionary:
	## No Anointed in a trial: every run meets the same room.
	return {"anoint": 0.0, "max_anoint": 0}


func result_extra() -> Dictionary:
	return {"trial": tid, "clock": clock}


func pause_items() -> Array:
	return [{"label": "Retry", "cb": restart, "confirm": false}, {"label": "Leave trial", "cb": quit, "confirm": false}]


func restart() -> void:
	## Retry (pause, the finish card) or a snuff's instant restart: a try
	## that didn't finish counts when the next finish is written.
	if not done:
		tries += 1
	begin()


func quit() -> void:
	var g := game()
	if g != null:
		g.return_hero()
	if world != null and is_instance_valid(world):
		world.paused = false
	to_screen("trials")


func next_trial() -> String:
	## The next trial built and open after this one ("" when none).
	var i := TrialData.ORDER.find(tid)
	for k in range(i + 1, TrialData.ORDER.size()):
		var nid: String = TrialData.ORDER[k]
		if TrialData.built(nid) and ModesSave.trial_open(game(), TrialData.number(nid)):
			return nid
	return ""


func finished(_res: Dictionary) -> void:
	pass


# ---------------------------------------------------------------- the finish

func _finish(w: Node) -> void:
	var g := game()
	var t := clock
	var medal := TrialData.medal_for(tid, t)
	finish = {"id": tid, "time": t, "medal": medal, "best": t, "prev_medal": 0, "embers": 0, "cosmetics": [],
			"next_medal": 0, "next_time": 0.0, "line": TrialData.LINES[medal], "new_best": true}
	if g != null:
		var rec: Dictionary = ModesSave.trial_rec(g, tid).duplicate(true)
		finish["prev_medal"] = int(rec.get("medal", 0))
		var best := float(rec.get("best", 0.0))
		finish["new_best"] = best <= 0.0 or t < best
		rec["best"] = t if finish["new_best"] else best
		finish["best"] = rec["best"]
		rec["medal"] = maxi(int(rec.get("medal", 0)), medal)
		rec["tries"] = int(rec.get("tries", 0)) + tries + 1   # this finish and the tries before it
		# Embers on each first medal of a kind.
		var paid := int(rec.get("paid", 0))
		var e := 0
		for k in range(paid + 1, int(rec["medal"]) + 1):
			e += int(TrialData.MEDAL_EMBERS[k])
		rec["paid"] = maxi(paid, int(rec["medal"]))
		ModesSave.set_trial_rec(g, tid, rec)
		if e > 0:
			g.add_embers(e)
			finish["embers"] = e
		finish["cosmetics"] = _grant_totals(g)
		g.save()
		_log(w)
	tries = 0
	var nm := int(finish["medal"]) + 1 if int(finish["medal"]) < 4 else 0
	if nm >= 2:
		finish["next_medal"] = nm
		finish["next_time"] = TrialData.target(tid, nm)
	finish["next"] = next_trial()
	finish["speaker"] = _host()
	# The medal's sound plays once, pitched, as it stamps down (mode_hud at 0.6 s):
	# roots and fifths only (A7: medal holds D and A): Bronze the C below
	# (note(4) x 0.5), Silver D, Gold G (note(2)), Dawn the Gold plus a glimmer.
	var ss := sfx()
	var hi := float(ss.note(2)) if ss != null and ss.has_method("note") else 1.335
	var lo := float(ss.note(4)) * 0.5 if ss != null and ss.has_method("note") else 0.891
	finish["medal_pitch"] = [1.0, lo, 1.0, hi, hi][medal]
	finish["medal_glimmer"] = medal >= 4
	if hud != null and hud.has_method("finish_card"):
		hud.finish_card(finish)


static func _host() -> String:
	## Mother Taper, or Hollin while she rests.
	var st = load("res://scripts/story.gd")
	if st != null and (st as Script).get_script_method_list().any(func(m): return m["name"] == "taper_resting"):
		if bool(st.taper_resting()):
			return "hollin"
	return "taper"


func _grant_totals(g: Node) -> Array:
	## The medal totals' cosmetics (5 any, 10 Silver+, 15 Gold+, 10 Golds,
	## all 20 Dawns), and a calling's four Golds (its trim pattern) and its
	## Master at Gold (its weapon glow).
	var out: Array = []
	var want: Array = []
	if ModesSave.medal_count(g, 1) >= 5:
		want += Cosmetics.ids_for("trials:medals5")
	if ModesSave.medal_count(g, 2) >= 10:
		want += Cosmetics.ids_for("trials:silvers10")
	if ModesSave.medal_count(g, 3) >= 15:
		want += Cosmetics.ids_for("trials:golds15")
	if ModesSave.medal_count(g, 3) >= 10:
		want += Cosmetics.ids_for("trials:golds10")
	if ModesSave.medal_count(g, 4) >= TrialData.ORDER.size():
		want += Cosmetics.ids_for("trials:dawns20")
	for cls in TrialData.BY_CLS:
		var ids: Array = TrialData.BY_CLS[cls]
		if ids.all(func(i): return int(ModesSave.trial_rec(g, i).get("medal", 0)) >= 3):
			want += Cosmetics.ids_for("trials:gold4:%s" % cls)
		if int(ModesSave.trial_rec(g, str(ids[3])).get("medal", 0)) >= 3:
			want += Cosmetics.ids_for("trials:master:%s" % cls)
	for nid in want:
		if g.grant_cosmetic(nid):
			out.append(nid)
	return out


func _log(w: Node) -> void:
	if bool(w.get("headless")):
		return
	var pl = load("res://scripts/playlog.gd")
	if pl != null:
		pl.write({"mode": "trial", "id": tid, "time": snappedf(clock, 0.01), "medal": TrialData.MEDALS[int(finish.get("medal", 1))],
				"tries": tries + 1, "at": Time.get_datetime_string_from_system()})


func _pill() -> void:
	pill({"mode": "trial", "text": _clock_text(clock), "time": clock, "lit": lit_count(), "total": marks.size(),
			"started": started})


static func _clock_text(t: float) -> String:
	var cs := int(round(t * 100.0))
	return "%d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]
