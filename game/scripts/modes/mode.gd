extends RefCounted
## The mode controller (contract.md §10.1, spec §7.1): the Endless Descent,
## the Waxworks and the Vigil Trials each extend this, the way a calling's
## kit extends kits/kit.gd. Every hook is a no-op here. The World holds it in
## world.mode (null in a story level) and calls it at its fifteen or so
## places; main.play_custom(level_data, mode) plays the level a mode built in
## memory, and routes the World's finished / quit / restart to finished(),
## quit() and restart() (never Game.record_result).
##
## A mode's level is plain LevelData text (headers, ---, 15 rows) parsed in
## memory, with an id of its own ("descent-7", "rush-snuffer", "trial-k1")
## and area_abs set (spec §1.1). Its private header keys (cart, seal, rooms,
## depth, cut, src, marks, assist...) are the modes' own; LevelData keeps
## every header raw in `headers`.
##
## Everything else a mode needs it does by polling in on_tick: an altar lit,
## a room entered, a candle lit, the clock, a hit taken.
##
## Autoloads are reached through game() and sfx() (never by name), so the
## tests may preload any mode script.

const LevelData := preload("res://scripts/level_data.gd")
const Combat := preload("res://scripts/combat.gd")
const Cosmetics := preload("res://scripts/modes/cosmetics.gd")
const ModesSave := preload("res://scripts/modes/modes_save.gd")
const HUD_SCRIPT := "res://scripts/modes/mode_hud.gd"
# A rush boss's life, so a fight lasts 60-80 s for the reference hero at the
# rush area (spec §5.6's start values; BR's rush sim re-derives them). The
# boss's configure({rush: true, hp_mult}) applies its own; this table is the
# stand-in used while a boss has no configure() (apply_boss_fallback).
const RUSH_HP := {"tollgrave": 2.0, "snuffer": 1.8, "rootmother": 0.9, "tinker": 0.85, "saint": 0.70, "hush": 0.6}   # (boss_mods.gd RUSH_HP wins when it exists)
const WAX_TINT := Color("f4e6c8")   # the Waxworks' cream wax, at WAX_TINT_MIX (tells stay untinted)
const WAX_TINT_MIX := 0.3
const FLASK_MAX := 3                # flask charges never exceed 3 (spec §1.8)
const ARM_MS := 4000                # a costly pause choice's second tap comes within this

var id := ""                    # "descent" | "waxworks" | "trial"
var main: Node                  # main.gd (plays the next level, shows the screens)
var world: Node                 # the World playing now (set by play_custom and on_build)
var mode_diff := "dusk"         # the mode's own difficulty (never the story's)
var mode_strength := "normal"
var hud: Node = null            # mode_hud.gd over the level (not headless)
var headless := false           # tests: no HUD, nothing drawn, no screens after
var boss_opts := {}             # {rush, mods, hp_mult, area} for the boss this mode's level spawns
var _flame_id := ""             # the hero's flame (a cycling one is turned each tick)
var _armed := {}                # a costly pause choice tapped once: key -> ticks (ms)
var _drink_hp := -1.0           # tick_drink's life at the last look
var _drink_was := false


static func game() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).root.get_node_or_null("Game") if ml is SceneTree else null


static func sfx() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).root.get_node_or_null("Sfx") if ml is SceneTree else null


static func play_sfx(name: String, pitch := 1.0) -> void:
	var s := sfx()
	if s != null and s.has_method("play"):
		s.play(name, pitch)


static func parse_level(text: String, level_id: String, world_n := 0) -> RefCounted:
	## A mode's level from its text, with its id and (for the World's
	## world_n: monster trims, the edge lines) the world its rooms come from.
	var lv = LevelData.new()
	lv.id = level_id
	lv.world = world_n
	lv.parse(text)
	return lv


static func header_value(text: String, key: String) -> String:
	## One header line's value from a level's text ("" when it's not there).
	for line in text.split("\n"):
		if line.strip_edges() == "---":
			break
		var c := line.find(":")
		if c > 0 and line.substr(0, c).strip_edges() == key:
			return line.substr(c + 1).strip_edges()
	return ""


static func set_header(text: String, key: String, value: String) -> String:
	## The text with one header line set (replaced, or added before the rows).
	var lines := text.split("\n")
	var out := PackedStringArray()
	var done := false
	for i in lines.size():
		var line := lines[i]
		if not done:
			if line.strip_edges() == "---":
				out.append("%s: %s" % [key, value])
				done = true
			else:
				var c := line.find(":")
				if c > 0 and line.substr(0, c).strip_edges() == key:
					out.append("%s: %s" % [key, value])
					done = true
					continue
		out.append(line)
	return "\n".join(out)


static func base_flask(diff_id: String) -> int:
	## The hero's flask charges on a difficulty: Game.flask_charges (DIFF's,
	## the Second Draught, Mother Taper's Match), or DIFF's with no Game.
	var g := game()
	if g != null and g.has_method("flask_charges"):
		return mini(int(g.flask_charges(diff_id)), FLASK_MAX)
	return int(Combat.diff(diff_id)["flask_charges"])


static func base_flask_heal(diff_id: String) -> float:
	## What one draught heals (the Rich Draught, flask_pct): Game.flask_heal.
	var g := game()
	if g != null and g.has_method("flask_heal"):
		return float(g.flask_heal(diff_id))
	return float(Combat.diff(diff_id)["flask"])


static func a_end(diff_id: String) -> int:
	## The final story boss's area on a difficulty (31 / 40 / 45 with the
	## Hush's header), read at run time, never assumed.
	var g := game()
	var fin := "6-4"
	var area := 31
	if g != null:
		var f = (g.get_script() as Script).get_script_constant_map().get("FINALE", "6-4")
		fin = str(f)
		if g.has_method("area_of"):
			area = int(g.area_of(fin))
	return Combat.area_level(area, diff_id)


# ---------------------------------------------------------------- the World's hooks

func level_data() -> RefCounted:
	return null


func diff() -> String:
	return mode_diff


func strength() -> String:
	return mode_strength


func on_build(w: Node) -> void:
	## The World is built: the hero's flame palette, the mode's HUD layer.
	world = w
	var g := game()
	if g != null and g.has_method("look"):
		var lk := Cosmetics.look_of({"look": g.look()}, func(n): return g.has_cosmetic(n))
		_flame_id = str(lk["flame"])
		w.set("hero_flame", Cosmetics.hero_pal(lk))
	if not bool(w.get("headless")) and not headless and ResourceLoader.exists(HUD_SCRIPT):
		hud = load(HUD_SCRIPT).new()
		hud.set("mode", self)
		hud.set("world", w)
		w.add_child(hud)


func on_tick(w: Node, _dt: float) -> void:
	tick_look(w)


func tick_look(w: Node) -> void:
	## A cycling flame (Prismfire) turns through its colours as it plays.
	if _flame_id != "" and Cosmetics.animated(_flame_id):
		w.set("hero_flame", Cosmetics.palette(_flame_id, float(w.get("ftime"))))


func on_spawn(_e: Node2D) -> void:
	pass


func on_snuffed(_w: Node) -> String:
	return ""


func allows(_what: String) -> bool:
	return true


func stats_filter(s: Dictionary) -> Dictionary:
	return s


func tells_mult() -> float:
	return 1.0


func elite_rules() -> Dictionary:
	return {}


func loot() -> Dictionary:
	return {}


func lights() -> Array:
	return []


func draw_glow(_glow: Node2D) -> void:
	pass


func pause_items() -> Array:
	## [{label, cb, confirm}] for the pause menu, in place of Restart and Quit.
	return []


func flask_max() -> int:
	## The flask's charges in this mode (W0's world.flask_max asks, once wired).
	return int(Combat.diff(mode_diff)["flask_charges"])


func flask_heal() -> float:
	## What one draught heals in this mode.
	return float(Combat.diff(mode_diff)["flask"])


func result_extra() -> Dictionary:
	return {}


func finished(_res: Dictionary) -> void:
	pass


func quit() -> void:
	pass


func restart() -> void:
	pass


# ---------------------------------------------------------------- helpers

func arm(key: String, title: String, sub: String) -> bool:
	## A costly choice from the pause menu's own Restart / Leave (before
	## its owner shows pause_items, with their confirm): true on the second
	## tap within ARM_MS; the first resumes the level and says what it costs.
	var now := Time.get_ticks_msec()
	if _armed.has(key) and now - int(_armed[key]) <= ARM_MS:
		_armed.erase(key)
		return true
	_armed[key] = now
	resume_world()
	toast(title, sub)
	return false


func resume_world() -> void:
	## Back to the level from the pause menu (nothing else changes).
	if world != null and is_instance_valid(world):
		if world.has_method("close_pause"):
			world.close_pause()
		else:
			world.paused = false


func tick_drink(w: Node, k: float) -> void:
	## A drink heals k x what the World's drink gave (the hero's own draught,
	## until W0's flask_heal asks the mode): call once a tick.
	var p: Node2D = w.player
	var drinking: bool = float(w.get("_flask_t")) >= 0.0
	if absf(k - 1.0) > 0.0001 and (drinking or _drink_was) and _drink_hp >= 0.0 and p.hp > _drink_hp and p.alive:
		p.hp = minf(_drink_hp + (p.hp - _drink_hp) * k, p.max_hp)
	_drink_was = drinking
	_drink_hp = p.hp if w.state == "play" else -1.0


func drink_k(w: Node) -> float:
	## This mode's draught over the one the World pours.
	var given := float(w.flask_heal()) if w.has_method("flask_heal") else float(Combat.diff(mode_diff)["flask"])
	return flask_heal() / maxf(given, 0.001)


static func hud_title(w: Node) -> Dictionary:
	## The HUD's title card as it stands ({sub, title, t}, or {}): read, and
	## cut or retitled, until SC's hud.gd has a call for it.
	var h = w.get("hud") if w != null else null
	if h == null:
		return {}
	var t = h.get("_title")
	return t if t is Dictionary else {}


static func hud_title_showing(w: Node) -> bool:
	var h = w.get("hud") if w != null else null
	return h != null and h.has_method("title_showing") and bool(h.title_showing())


static func cut_hud_title(w: Node) -> void:
	## A title card cut short (its quick fade, as a level-up cuts one).
	var h = w.get("hud") if w != null else null
	if h == null:
		return
	if h.has_method("cut_title"):
		h.cut_title()
		return
	var t := hud_title(w)
	if t.is_empty():
		return
	var cm: Dictionary = (h.get_script() as Script).get_script_constant_map()
	var end := float(cm.get("TITLE_TIME", 2.8)) - float(cm.get("TITLE_CUT", 0.12))
	t["t"] = maxf(float(t.get("t", 0.0)), end)


func pill(state: Dictionary) -> void:
	## The mode pill (the HUD's sigils corner): SC's hud.mode_pill when the
	## HUD has it (in its own keys: hud_pill), else mode_hud.gd draws its own.
	if world == null:
		return
	var h = world.get("hud")
	if h != null and h.has_method("mode_pill"):
		h.mode_pill(hud_pill(state))
	elif hud != null:
		hud.set("pill", state)


static func hud_pill(state: Dictionary) -> Dictionary:
	## A mode's pill state ({mode, text, time, spare, hushings, lit, total,
	## started, drips, clock}) in the HUD pill's keys ({label, clock, lives,
	## lives_max, dots, count, col}: SC's hud.gd), the mode's own kept beside
	## them. (The two streams wrote the pill each to its own keys; the wave-1
	## merge translates here.)
	if state.is_empty():
		return {}
	var out := state.duplicate()
	var m := str(state.get("mode", ""))
	var spare := int(state.get("spare", -1))
	match m:
		"descent":
			out["label"] = str(state.get("text", ""))
			if spare >= 0:
				out["lives"] = spare
				out["lives_max"] = maxi(spare, int(state.get("spare_max", spare)))
			out["dots"] = int(state.get("hushings", 0))
		"trial":
			# The trial's clock counts up (m:ss.hh), its candles "lit/total".
			out["clock"] = float(state.get("time", 0.0))
			if int(state.get("total", 0)) > 0:
				out["count"] = "%d/%d" % [int(state.get("lit", 0)), int(state.get("total", 0))]
		"waxworks":
			out["label"] = str(state.get("text", ""))
			if not state.has("clock"):
				out.erase("clock")   # (only Waxley's Clock shows one: the seconds left)
			if spare >= 0:
				out["lives"] = spare
				out["lives_max"] = maxi(spare, int(state.get("spare_max", spare)))
	return out


func toast(title: String, sub := "") -> void:
	if world != null:
		var h = world.get("hud")
		if h != null and h.has_method("toast"):
			h.toast(title, sub)


func play(data: RefCounted) -> void:
	## Hands a level to main (play_custom), or, with no main (a test), keeps it.
	if main != null and main.has_method("play_custom"):
		main.play_custom(data, self)


func to_screen(screen: String) -> void:
	## Back to a mode screen (the Challenges hub's descent / waxworks / trials).
	if headless or main == null:
		return
	if main.has_method("show_modes"):
		main.show_modes(screen)


static func is_boss(e: Node2D) -> bool:
	return e != null and e.get("boss_id") != null


func apply_boss_fallback(e: Node2D, hp_mult: float) -> void:
	## A boss with no configure() yet (BR adds it to the v2 bosses): its rush
	## life set here (RUSH_HP x the mode's own multiplier), so a rematch still
	## lasts as long. A boss with configure() takes boss_opts instead.
	if e.has_method("configure"):
		return
	# BR's table (boss_mods.gd) when it's in the build: this one's stand-in.
	var table: Dictionary = RUSH_HP
	if ResourceLoader.exists("res://scripts/boss_mods.gd"):
		var t = (load("res://scripts/boss_mods.gd") as Script).get_script_constant_map().get("RUSH_HP")
		if t is Dictionary:
			table = t
	var k := float(table.get(str(e.get("boss_id")), 1.0)) * hp_mult
	e.max_hp = float(e.max_hp) * k
	e.hp = e.max_hp


func satchel_add(it: Dictionary) -> void:
	## A reward item into the satchel: never lost to a full one (as the
	## sigil milestones do in game_state.record_result).
	var g := game()
	if g == null:
		return
	if str(g.add_item(it)) == "full" and not g.borrowing():
		(g.hero()["satchel"] as Array).append(it)
		if g.has_method("note_legend"):
			g.note_legend(str(it.get("legend", "")))
		g.save()
