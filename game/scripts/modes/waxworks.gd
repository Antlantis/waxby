extends "res://scripts/modes/mode.gd"
## The Waxworks (spec §7.3): Waxley casts every boss you beat in wax, "for
## practice", and keeps them in his cellar. Each boss's arena is cut from its
## story level by tools/make_modes.py (game/levels/rush/<boss>.txt).
##
## - Rematch: one boss on any open difficulty, at area_abs = max(area_level(
##   boss_area, diff), hero_level - 1), so an old boss is always a fair fight.
##   Retries at the arena's door altar, unlimited. Pays the boss's XP x0.25
##   and embers; no item drops (the seals pay).
## - The Gauntlet (once all six are beaten): every boss in story order at
##   area_level(A_END, diff), life x0.85, life, resource and flask carried
##   between fights, Spare Wicks 2 / 1 / 0 (a snuff restarts the current boss),
##   a clock from the first boss waking to the last bell. No restart from the
##   pause menu (it would dodge the Spare Wicks); leaving asks twice.
## - The flask is the hero's own (Game.flask_charges / flask_heal), none
##   under Dry Flask.
## - Tweaks add drips (Candle strength: Gentle -2, Fierce +2); the drips seal
##   the win: Bronze 4, Silver 8, Gold 12. Each seal pays once per boss per
##   difficulty (a Rare, a Rare and the boss's flame, a Legendary); a clear
##   pays 60 embers x DIFF.embers once.
## - Rush-only moves (Bell Roll, Smother) are always on: the boss's
##   configure({rush: true}) turns them on (BR). Warded and Echoing Wax need
##   boss_mods.gd (BR); until it's in the build those two chips stay shut.
##
## --autoplay=rush:<boss id> starts a Dusk rematch with the bot.

const Progression := preload("res://scripts/progression.gd")
const Items := preload("res://scripts/items.gd")
const Rooms := preload("res://scripts/modes/rooms.gd")
const SELF := "res://scripts/modes/waxworks.gd"
const BOSS_MODS := "res://scripts/boss_mods.gd"
const TWEAKS := {
	"hotter": {"name": "Hotter Wax", "text": "Boss damage x1.4", "drips": 2, "line": "Hotter wax? Bold. I'll fetch the tongs."},
	"thicker": {"name": "Thicker Wax", "text": "Boss life x1.5", "drips": 2, "line": "I used the good tallow. Lots of it."},
	"quick": {"name": "Quick Wick", "text": "Boss tells x0.85", "drips": 3, "line": "I wound him up a little tighter."},
	"dim": {"name": "Dim Cellar", "text": "Your light x0.75", "drips": 2, "line": "Candles are dear. We'll manage."},
	"dry": {"name": "Dry Flask", "text": "No flask", "drips": 1, "line": "The flask is... being cleaned."},
	"unlit": {"name": "Unlit Hands", "text": "No Special", "drips": 3, "line": "Just you and your swing. Brave."},
	"clock": {"name": "Waxley's Clock", "text": "Beat the clock", "drips": 2, "line": "I'll time you. I'll time you loudly."},
	"glass": {"name": "Glass Candle", "text": "One hit snuffs", "drips": 5, "line": "One drip and you're out. I'll have a mop."},
	"warded": {"name": "Warded Wax", "text": "Three warding motes", "drips": 2, "line": "Three little candles. They're very protective.", "needs": BOSS_MODS},
	"echoing": {"name": "Echoing Wax", "text": "Every blow twice", "drips": 3, "line": "He says everything twice now. Like my uncle.", "needs": BOSS_MODS},
}
const TWEAK_ORDER := ["hotter", "thicker", "quick", "dim", "dry", "unlit", "clock", "glass", "warded", "echoing"]
const SEALS := [4, 8, 12]
const SEAL_NAME := ["", "Bronze", "Silver", "Gold"]
const STRENGTH_DRIPS := {"gentle": -2, "normal": 0, "fierce": 2}
const HOTTER := 1.4
const THICKER := 1.5
const QUICK := 0.85
const DIM := 0.75
const GAUNTLET_HP := 0.85
const XP_MULT := 0.25
const REMATCH_RATE := 45.0       # a rematch pays at most this x E(A) (x the difficulty's XP) a minute: about a replay's
const CLEAR_EMBERS := 60
const WAX_EMBERS := 12           # a clear's embers: this x one ember's worth at the fight's area
const CLOCK := {"tollgrave": 90.0, "snuffer": 120.0, "rootmother": 120.0, "tinker": 120.0, "saint": 130.0, "hush": 150.0}
const NEXT_AFTER := 1.2
# The casts whose blows Echoing Wax records (boss_mods.gd watches their
# strikes, follows, shots and hazards with a source): until BA / BB record the
# v3 bosses' blows (wave 4) the Tweak is shut for the others, so it pays no
# free drips (the rev5 review: Gravebough and the Tinker echoed nothing, the
# Hush only its P3 Gaze). Open a cast here as its blows are recorded.
const ECHOES := ["tollgrave", "snuffer", "saint"]
const LINE_IDLE := "Pick a cast. Mind the drips."

var boss := "tollgrave"
var tweaks: Array = []
var gauntlet := false
var order: Array = []            # the Gauntlet's bosses in story order
var index := 0                   # the Gauntlet's fight
var spare := 0
var carry := {}                  # the Gauntlet's life %, resource and flask between fights
var fight_t := 0.0               # this fight, from the boss waking
var total_t := 0.0               # the Gauntlet's clock
var snuffs := 0
var woke := false
var won := false
var over := ""                   # "" | "won" | "lost" | "left"
var outcome := {}                # the last clear's: {boss, time, drips, seal, rewards, new_best}
var _clear_t := 0.0
var _last_hp := -1.0
var _lit: Array = []             # the altars lit at the last look (a lighting refills the flask)
var _was_dead := false


static func make() -> Object:
	return load(SELF).new()


static func tweak_open(tid: String, cast := "") -> bool:
	## A Tweak that works in this build (Warded and Echoing need boss_mods.gd),
	## and on this cast when one is named ("gauntlet": on every cast; Echoing
	## Wax only where ECHOES says it echoes).
	var t: Dictionary = TWEAKS.get(tid, {})
	if t.is_empty() or (t.has("needs") and not ResourceLoader.exists(str(t["needs"]))):
		return false
	if tid == "echoing" and cast != "":
		if cast == "gauntlet":
			for b in ModesSave.BOSSES:
				if not ECHOES.has(str(b)):
					return false
		elif not ECHOES.has(cast):
			return false
	return true


static func drips_of(tw: Array, strength_id := "normal", cast := "") -> int:
	var n := 0
	for t in tw:
		if tweak_open(str(t), cast):
			n += int(TWEAKS[t]["drips"])
	return maxi(n + int(STRENGTH_DRIPS.get(strength_id, 0)), 0)


static func rematch_xp(b: String, area: int, diff_id: String, secs: float) -> int:
	## A win's XP: the boss's own x0.25 at the fight's area, as a hero of that
	## area earns it (the rematch area already follows him: no under-level
	## bonus), and never more than REMATCH_RATE x E(A) a minute of the fight.
	## The rev5 review: the Hush's Nightfall rematch
	## paid 25,073 XP an 88 s win to an L34 hero (gap_mult 2), up to 16,000
	## a minute against the Descent's 4,200-4,500: farming one cast out-earned
	## the endgame loop. Provisional (W5-W6), read against the playlog.
	var full := float(Progression.kill_xp(b, area, area, diff_id)) * XP_MULT
	var cap := REMATCH_RATE * Combat.e_scale(area) * float(Combat.diff(diff_id)["xp"]) * maxf(secs / 60.0, 0.25)
	return roundi(minf(full, cap))


static func seal_of(drips: int) -> int:
	## 0 none, 1 Bronze, 2 Silver, 3 Gold.
	var s := 0
	for i in SEALS.size():
		if drips >= int(SEALS[i]):
			s = i + 1
	return s


static func rush_path(b: String) -> String:
	return "res://levels/rush/%s.txt" % b


static func boss_area(b: String) -> int:
	## The boss level's Dusk area (its rush file's header, from the story level).
	var p := rush_path(b)
	if not FileAccess.file_exists(p):
		return 1
	return maxi(int(header_value(FileAccess.get_file_as_string(p), "area")), 1)


static func rematch_area(b: String, diff_id: String, hero_level: int) -> int:
	return maxi(Combat.area_level(boss_area(b), diff_id), hero_level - 1)


static func rematch(main_node: Node, b: String, diff_id: String, tw: Array, strength_id := "normal") -> Object:
	var m = make()
	m.main = main_node
	m.setup(b, diff_id, tw, strength_id)
	m.begin()
	return m


static func start_gauntlet(main_node: Node, diff_id: String, tw: Array, strength_id := "normal", bosses: Array = []) -> Object:
	var m = make()
	m.main = main_node
	m.setup("", diff_id, tw, strength_id)
	m.gauntlet = true
	m.order = bosses if not bosses.is_empty() else ModesSave.open_casts()
	m.boss = str(m.order[0]) if not m.order.is_empty() else "tollgrave"
	m.spare = int({"dusk": 2, "nightfall": 1, "witching": 0}.get(diff_id, 0))
	m.begin()
	return m


static func autoplay(main_node: Node, arg: String) -> void:
	ModesSave.force_open = true
	var b := arg if FileAccess.file_exists(rush_path(arg)) else "tollgrave"
	rematch(main_node, b, "dusk", [])


func setup(b: String, diff_id: String, tw: Array, strength_id := "normal") -> void:
	id = "waxworks"
	boss = b
	mode_diff = diff_id
	mode_strength = strength_id
	var cast := b if b != "" else "gauntlet"
	tweaks = tw.filter(func(t): return tweak_open(str(t), cast))


func has(tid: String) -> bool:
	return tweaks.has(tid)


func drips() -> int:
	return drips_of(tweaks, mode_strength)


func area() -> int:
	var g := game()
	var lvl := int(g.hero().get("level", 1)) if g != null else 1
	if gauntlet:
		return a_end(mode_diff)
	return rematch_area(boss, mode_diff, lvl)


func hp_mult() -> float:
	## The mode's share of the boss's life (the rush normalisation is the
	## boss's own: RUSH_HP, or its configure()).
	var k := 1.0
	if has("thicker"):
		k *= THICKER
	if gauntlet:
		k *= GAUNTLET_HP
	return k


func mods() -> Array:
	var out: Array = []
	for t in ["warded", "echoing"]:
		if has(t):
			out.append(t)
	return out


func begin() -> void:
	woke = false
	won = false
	fight_t = 0.0
	_clear_t = 0.0
	_last_hp = -1.0
	var data := level_data()
	if data != null:
		play(data)


func level_data() -> RefCounted:
	var p := rush_path(boss)
	if not FileAccess.file_exists(p):
		return null
	var text := FileAccess.get_file_as_string(p)
	var a := area()
	text = set_header(text, "area_abs", str(a))
	var src := header_value(text, "src")
	boss_opts = {"rush": true, "mods": mods(), "hp_mult": hp_mult(), "area": a}
	return parse_level(text, "rush-%s" % boss, LevelData.world_of(src))


# ---------------------------------------------------------------- the World's hooks

func on_build(w: Node) -> void:
	super.on_build(w)
	var p: Node2D = w.player
	# The hero's own flask (the Second Draught, Mother Taper's Match), not
	# just DIFF's: the World fills it to DIFF's count.
	w.flask_charges = flask_max()
	if gauntlet and not carry.is_empty():
		p.hp = clampf(float(carry.get("hp", 1.0)), 0.05, 1.0) * p.max_hp
		p.res = clampf(float(carry.get("res", p.res)), 0.0, p.res_max)
		w.flask_charges = mini(int(carry.get("flask", w.flask_charges)), flask_max())
	_lit = []
	for a in w.altars:
		_lit.append(bool(a["lit"]))
	_was_dead = false
	if has("dim"):
		w.dim("waxworks:dim", DIM, 1.0e9)
	if has("dry"):
		w.flask_charges = 0
	var b = w.get("boss")
	if b != null and b.has_signal("woke") and not b.woke.is_connected(_on_woke):
		b.woke.connect(_on_woke)
	_last_hp = p.hp
	play_sfx("wax_cast")
	_pill()


func _on_woke() -> void:
	if not woke:
		woke = true
		fight_t = 0.0
		play_sfx("rush_bell")


func on_tick(w: Node, dt: float) -> void:
	tick_look(w)
	if over != "":
		return
	var p: Node2D = w.player
	# Once the boss is down the fight's over: its clock stops at the kill, and
	# neither Waxley's Clock nor Glass Candle can snuff him on the walk to the
	# bell (the rev5 review: the Hush's closing and the Saint's dawn counted,
	# and a clock run out there snuffed a hero who had won).
	var down := boss_down(w)
	if w.state == "play" and woke:
		if not down:
			fight_t += dt
		if gauntlet:
			total_t += dt
	if has("dry"):
		w.flask_charges = 0
	else:
		# An altar lit, or a snuff's relight: the World refilled the flask to
		# DIFF's count; it's the hero's own. A drink pours the hero's draught.
		var refill := false
		for i in w.altars.size():
			var on: bool = bool(w.altars[i]["lit"])
			if on and not (_lit[i] if i < _lit.size() else false):
				refill = true
			if i < _lit.size():
				_lit[i] = on
			else:
				_lit.append(on)
		var dead: bool = w.state == "dead"
		if _was_dead and not dead:
			refill = true
		_was_dead = dead
		if refill:
			w.flask_charges = flask_max()
		tick_drink(w, drink_k(w))
	# Glass Candle: any harm at all snuffs him.
	if has("glass") and not down and w.state == "play" and p.alive and _last_hp >= 0.0 and p.hp < _last_hp - 0.01:
		_snuff(w, "glass")
	# Waxley's Clock.
	if has("clock") and woke and not down and w.state == "play" and p.alive and fight_t > float(CLOCK.get(boss, 120.0)):
		_snuff(w, "clock")
	_last_hp = p.hp
	if w.state == "dead":
		_last_hp = -1.0
	elif _last_hp < 0.0:
		_last_hp = p.hp
	if w.state == "clear":
		if not won:
			won = true
			_clear_t = 0.0
			_won(w)
		_clear_t += dt
		if _clear_t >= NEXT_AFTER and _clear_t - dt < NEXT_AFTER:
			_after_win(w)
	_pill()


static func boss_down(w: Node) -> bool:
	## The cast is beaten: dead, or past its fight (the Hush closing its eye,
	## the Saint's dawn, a finale), and nothing left to strike.
	var b = w.get("boss") if w != null else null
	if b == null or not is_instance_valid(b):
		return false
	if not bool(b.get("alive")) or b.get("defeated") == true:
		return true
	return str(b.get("state")) in ["dead", "closing", "finale", "dying", "dawn"]


func _snuff(w: Node, why: String) -> void:
	var p: Node2D = w.player
	w.hurt_player(1.0, p.position.x, why, null, {"pct": true, "ignore_invuln": true, "no_knock": true})
	if p.alive:
		p.die()


func on_spawn(e: Node2D) -> void:
	if not is_boss(e):
		return
	apply_boss_fallback(e, hp_mult())
	if has("hotter"):
		e.dmg_mult = float(e.dmg_mult) * HOTTER
	if "tint" in e:
		# Cream wax at 30% (spec §7.3); BR keeps the tells' flashes off the tint.
		e.tint = Color.WHITE.lerp(WAX_TINT, WAX_TINT_MIX)


func on_snuffed(_w: Node) -> String:
	snuffs += 1
	woke = false
	if not gauntlet:
		return ""   # a rematch retries at the door altar, unlimited
	if spare > 0:
		spare -= 1
		toast("Spare Wick lit", "%d left" % spare if spare != 1 else "1 left")
		return ""
	over = "lost"
	return "end"


func allows(what: String) -> bool:
	match what:
		"xp", "loot", "record":
			return false   # XP x0.25 is paid at the bell; the seals pay, not drops
		"special":
			return not has("unlit")
		"flask":
			return not has("dry")
	return true


func tells_mult() -> float:
	return QUICK if has("quick") else 1.0


func elite_rules() -> Dictionary:
	return {"anoint": 0.0, "max_anoint": 0}


func result_extra() -> Dictionary:
	return {"rush": boss, "drips": drips(), "gauntlet": gauntlet}


func pause_items() -> Array:
	if gauntlet:
		return [{"label": "Leave the Gauntlet", "cb": leave, "confirm": true}]
	return [{"label": "Retry", "cb": restart, "confirm": false}, {"label": "Leave", "cb": leave, "confirm": false}]


func flask_max() -> int:
	return 0 if has("dry") else base_flask(mode_diff)


func flask_heal() -> float:
	return base_flask_heal(mode_diff)


func quit() -> void:
	## The pause menu's own Leave (before its owner shows pause_items): a
	## rematch leaves at once; the Gauntlet asks twice (it ends the run).
	if gauntlet and over == "" and not arm("leave", "Leaving ends the Gauntlet", "Tap Leave again to go"):
		return
	leave()


func leave() -> void:
	over = "left"
	resume_world()
	to_screen("waxworks")


func restart() -> void:
	## The pause menu's Restart (and a rematch card's Retry): a rematch
	## starts over at the door, free. The Gauntlet has no restarts (a snuff
	## spends a Spare Wick; a free restart would dodge that).
	if gauntlet:
		resume_world()
		toast("No restarts in the Gauntlet", "A snuff spends a Spare Wick")
		return
	over = ""
	begin()


func finished(res: Dictionary) -> void:
	if bool(res.get("cleared", false)):
		return
	# The Gauntlet with no Spare Wick left.
	_gauntlet_over(false)


# ---------------------------------------------------------------- wins and rewards

func _won(w: Node) -> void:
	var g := game()
	var d := drips()
	var seal := seal_of(d)
	outcome = {"boss": boss, "time": fight_t, "drips": d, "seal": seal, "rewards": [], "new_best": false}
	if g == null:
		return
	# XP: the boss's own, x0.25 (capped: rematch_xp); embers: a clear's worth.
	var xp := rematch_xp(boss, int(w.area), mode_diff, fight_t)
	if xp > 0:
		g.add_xp(xp)
		outcome["xp"] = xp
	var e := WAX_EMBERS * maxi(int(w.ember_worth()), 1)
	g.add_embers(e)
	outcome["embers"] = e
	if gauntlet:
		g.save()
		return
	# The records and the seals, once each per boss per difficulty.
	var rec: Dictionary = ModesSave.boss_rec(g, boss, mode_diff).duplicate(true)
	var paid: Array = rec.get("paid", [])
	if d > int(rec.get("drips", 0)) or float(rec.get("time_at_best", 0.0)) <= 0.0 or (d == int(rec.get("drips", 0)) and fight_t < float(rec.get("time_at_best", 1.0e9))):
		rec["time_at_best"] = fight_t
		outcome["new_best"] = d > int(rec.get("drips", 0)) or float(rec.get("time", 0.0)) <= 0.0
	rec["drips"] = maxi(int(rec.get("drips", 0)), d)
	if float(rec.get("time", 0.0)) <= 0.0 or fight_t < float(rec["time"]):
		rec["time"] = fight_t
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([boss, mode_diff, Time.get_ticks_usec()])
	var cls := str(g.hero()["cls"])
	if not paid.has("clear"):
		paid.append("clear")
		var ce := CLEAR_EMBERS * int(Combat.diff(mode_diff)["embers"])
		g.add_embers(ce)
		(outcome["rewards"] as Array).append({"kind": "embers", "n": ce})
	for k in range(1, seal + 1):
		var key: String = ["", "bronze", "silver", "gold"][k]
		if paid.has(key):
			continue
		paid.append(key)
		var rarity := "legendary" if k == 3 else "rare"
		var slot := Items.pick_slot(rng)
		var lg := Items.pick_legend(slot, cls, rng, w.area, g.legends_found() if g.has_method("legends_found") else []) if rarity == "legendary" else ""
		var it := Items.make(slot, cls, w.area, rarity if (rarity != "legendary" or lg != "") else "rare", rng, lg)
		satchel_add(it)
		(outcome["rewards"] as Array).append({"kind": "item", "item": it})
		if k == 2:
			for nid in Cosmetics.ids_for("waxworks:%s" % boss):
				if g.grant_cosmetic(nid):
					(outcome["rewards"] as Array).append({"kind": "cosmetic", "id": nid})
	rec["paid"] = paid
	ModesSave.set_boss_rec(g, boss, mode_diff, rec)
	# All six cast in Bronze or better: the Bone trim colour.
	var all_bronze := true
	for b in ModesSave.BOSSES:
		if ModesSave.best_seal(g, b) < 1:
			all_bronze = false
	if all_bronze:
		for nid in Cosmetics.ids_for("waxworks:bronze6"):
			if g.grant_cosmetic(nid):
				(outcome["rewards"] as Array).append({"kind": "cosmetic", "id": nid})
	if seal > 0:
		play_sfx("seal_stamp")
	w.bark("waxworks_won")
	g.save()


func _after_win(w: Node) -> void:
	if not gauntlet:
		over = "won"
		if hud != null and hud.has_method("rematch_card"):
			hud.rematch_card(outcome)
		return
	# The Gauntlet: on to the next cast, life carried.
	var p: Node2D = w.player
	carry = {"hp": p.life_frac(), "res": float(p.res), "flask": int(w.flask_charges)}
	index += 1
	if index >= order.size():
		_gauntlet_over(true)
		return
	boss = str(order[index])
	begin()


func _gauntlet_over(cleared: bool) -> void:
	over = "won" if cleared else "lost"
	var g := game()
	# (cleared: _after_win has already stepped index past the last cast)
	var out := {"gauntlet": true, "cleared": cleared, "reached": order.size() if cleared else mini(index, order.size()), "of": order.size(),
			"time": total_t, "drips": drips(), "rewards": []}
	if g != null and cleared and order.size() >= ModesSave.BOSSES.size():
		var rec: Dictionary = (ModesSave.block(g)["waxworks"]["gauntlet"] as Dictionary).get(mode_diff, {"cleared": false, "time": 0.0, "drips": 0, "paid": []}).duplicate(true)
		var paid: Array = rec.get("paid", [])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["gauntlet", mode_diff, Time.get_ticks_usec()])
		var cls := str(g.hero()["cls"])
		var owed: Array = []
		if not paid.has("clear"):
			owed.append("clear")
		if drips() >= 6 and not paid.has("six"):
			owed.append("six")
		if drips() >= 12 and not paid.has("twelve"):
			owed.append("twelve")
		for key in owed:
			paid.append(key)
			var slot := Items.pick_slot(rng)
			var lg := Items.pick_legend(slot, cls, rng, a_end(mode_diff), g.legends_found() if g.has_method("legends_found") else [])
			var it := Items.make(slot, cls, a_end(mode_diff), "legendary" if lg != "" else "rare", rng, lg)
			satchel_add(it)
			(out["rewards"] as Array).append({"kind": "item", "item": it})
		var src := {"dusk": "gauntlet:any", "nightfall": "gauntlet:nightfall", "witching": "gauntlet:witching"}
		var cos: Array = Cosmetics.ids_for("gauntlet:any")
		if mode_diff != "dusk":
			cos += Cosmetics.ids_for(str(src[mode_diff]))
		if drips() >= 12:
			cos += Cosmetics.ids_for("gauntlet:drips12")
		for nid in cos:
			if g.grant_cosmetic(nid):
				(out["rewards"] as Array).append({"kind": "cosmetic", "id": nid})
		rec["cleared"] = true
		rec["drips"] = maxi(int(rec.get("drips", 0)), drips())
		if float(rec.get("time", 0.0)) <= 0.0 or total_t < float(rec["time"]):
			rec["time"] = total_t
		rec["paid"] = paid
		ModesSave.block(g)["waxworks"]["gauntlet"][mode_diff] = rec
		g.save()
	outcome = out
	if world != null and not cleared:
		world.bark("waxworks_lost")
	if hud != null and hud.has_method("rematch_card"):
		hud.rematch_card(out)
	elif not headless:
		to_screen("waxworks")


func _pill() -> void:
	var st := {"mode": "waxworks", "text": "%d drips" % drips(), "drips": drips(), "time": total_t if gauntlet else fight_t}
	if has("clock"):
		st["clock"] = maxf(float(CLOCK.get(boss, 120.0)) - fight_t, 0.0)
	if gauntlet:
		st["spare"] = spare
		st["text"] = "%d/%d" % [mini(index + 1, order.size()), order.size()]
	pill(st)


static func waxley_line(tw: Array) -> String:
	## Waxley's word on the Tweaks chosen (the last one picked speaks).
	for i in range(tw.size() - 1, -1, -1):
		var t: Dictionary = TWEAKS.get(str(tw[i]), {})
		if not t.is_empty():
			return str(t["line"])
	return LINE_IDLE
