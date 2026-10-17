extends SceneTree
## test_boss_windows (the int2 review's boss oracle): every calling against
## the real 3-4 and 4-4, at the arrival level and four levels over it, each
## window used in full from the best spot with Wick untouchable (a lower
## bound on the fight: no misses, no dodging).
##
##     godot --headless --path game --script res://tests/test_boss_windows.gd
##
## Two styles: "basic" (the basic swing or shot, and the chips it lands
## between windows) and "best" (each calling's main play in the window: the
## Special held and let go, a knight's Perfect Guard lunge, a stomp dropped
## onto the target first by the three that stomp best). Before the review's
## fix every phase fell to one window plus a chip (a stagger left the boss
## 1 HP over its line): 3 windows and 35-42 s. Now each fight takes at least
## MIN_WINDOWS windows and MIN_SECONDS, and no add outlives its boss.
## The rev5 review's: the Prism Saint and the Hush on the real 5-4 and 6-4
## (V3), every calling at arrival and four over, through the boss's own
## bot_pad (it travels, reads mirrors and bells, dodges what it dodges;
## Wick untouchable), as it plays and with each window opened by a stomp:
## each wins, each phase takes the windows the cap allows at least (one
## window never takes a phase), the Hush's phases 70 s or less each (spec
## §5.1), the fight inside its cap.
## v1.0.1's (the author: the Tinker "the hardest, taking way too much to
## beat"): the Tinker on the real 4-4 with real travel, every calling at the
## arrival level, Wick untouchable: he runs and jumps to the lit bell, rings
## it once it's ready (after a person's reaction), and strikes the spring
## the whole window; he waits out the XII beam as a floor player does, and
## never walks into the Tinker's body while it hurts. The fight's length is
## pinned in TK_TRAVEL's band: v1.0.0's took 52-214 s here (mean 122), much
## of it waiting for his body to clear the floor (it hurt in every state,
## and no jump clears him). (The oracle above parks Wick mid-floor, where he
## stops short of him: there the Tinker only reaches his IX post, a window
## a lap whatever the rules, so it can't show this; parked up on the XII
## beam instead, out of his way, a teleporting Wick beat v1.0.0's in 19-38
## s: his clock never made the fight long.)

const LevelData := preload("res://scripts/level_data.gd")
const DT := 1.0 / 120.0
const TILE := 32
const AREA := {"3-4": 17, "4-4": 22}
const ARRIVE := {"3-4": 17, "4-4": 21}
const OVER := 4                     # the second hero: four levels over the arrival level
const MIN_WINDOWS := 5
const MIN_SECONDS := 45.0
const CAP := 400.0                  # s: a fight that isn't over by then fails
const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
# The v3 bosses built on their own scripts, fought through their bot_pad on
# the real levels: the windows a phase at least, the phase's most seconds
# (the Hush: spec §5.1), the whole fight's cap.
# (Under the window cap a phase of 35% takes two windows at least, one if
# the Heard hands' 50% chips finish it; the Saint's last 30% can fall in one.)
const V3 := {
	"5-4": {"area": 27, "arrive": 26, "min": 5, "per_phase": [2, 2, 1], "cap": 300.0},
	"6-4": {"area": 31, "arrive": 30, "min": 6, "per_phase": [1, 2, 1], "phase_max": 70.0, "cap": 360.0},
}
# The Tinker with real travel (v1.0.1): each calling's fight lo..hi s, their
# mean mean_lo..mean_hi s (the retune measured 37-72 s, means 39-67 s over
# five reactions; v1.0.0's mean here 122 s), at least min windows; the
# fighter waits react s once a bell is ready.
const TK_TRAVEL := {"lo": 30.0, "hi": 90.0, "mean_lo": 40.0, "mean_hi": 70.0, "min": 5, "react": 0.3, "cap": 240.0}

var game: Node
var World: GDScript
var Items: GDScript
var Classes: GDScript
var Progression: GDScript
var _passed := 0
var _failed := 0
var _tog := false


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + what)


func _initialize() -> void:
	game = root.get_node("Game")
	World = load("res://scripts/world.gd")
	Items = load("res://scripts/items.gd")
	Classes = load("res://scripts/classes.gd")
	Progression = load("res://scripts/progression.gd")
	game.save_path = "user://test_boss_windows.json"
	await process_frame
	var rows := []
	for lid in ["3-4", "4-4"]:
		if not FileAccess.file_exists("res://levels/%s.txt" % lid):
			print("  skipped: %s isn't built" % lid)
			continue
		for lvl in [int(ARRIVE[lid]), int(ARRIVE[lid]) + OVER]:
			for cls in CALLINGS:
				for style in ["basic", "best"]:
					var r: Dictionary = await _oracle(lid, cls, style, lvl)
					rows.append(r)
					print("  %s %-7s L%d %-5s %s in %5.1f s, %d windows%s" % [lid, cls, lvl, style, "dead" if r["dead"] else "ALIVE",
							r["t"], r["windows"], (", adds left %d" % r["adds"]) if r["adds"] > 0 else ""])
					_check(r["dead"] and int(r["windows"]) >= MIN_WINDOWS and float(r["t"]) >= MIN_SECONDS,
							"%s %s L%d %s: at least %d windows and %.0f s even played perfectly (%d windows, %.1f s)" % [lid, cls, lvl, style,
							MIN_WINDOWS, MIN_SECONDS, r["windows"], r["t"]])
					_check(int(r["adds"]) == 0, "%s %s L%d %s: no add of his outlives him (%d)" % [lid, cls, lvl, style, r["adds"]])
	# The rev5 review: the Saint and the Hush on the real 5-4 and 6-4, every
	# calling through the boss's own bot_pad (real travel, real swings, Wick
	# untouchable): "pad" as it plays, "best" with each window opened by a
	# stomp dropped onto the target (the three that stomp best). Before the
	# fix one drop took a phase (the bounce loop paid 3x every time) and one
	# window could too (no cap before the stagger).
	for lid in V3:
		if not FileAccess.file_exists("res://levels/%s.txt" % lid):
			print("  skipped: %s isn't built" % lid)
			continue
		var cfg: Dictionary = V3[lid]
		for lvl in [int(cfg["arrive"]), int(cfg["arrive"]) + OVER]:
			for cls in CALLINGS:
				for style in ["pad", "best"]:
					if style == "best" and not (cls in ["knight", "founder", "sexton"]):
						continue
					var r: Dictionary = await _pad_oracle(lid, cls, style, lvl)
					var wins: Array = r["wins"]
					var pt: Array = r["phase_t"]
					var total := int(wins[0]) + int(wins[1]) + int(wins[2])
					print("  %s %-7s L%d %-4s %s in %5.1f s, windows %s (%d), phases %.0f / %.0f / %.0f s" % [lid, cls, lvl, style, "won" if r["won"] else "NOT WON",
							r["t"], str(wins), total, pt[0], pt[1], pt[2]])
					var per: Array = cfg["per_phase"]
					_check(bool(r["won"]) and total >= int(cfg["min"]) and int(wins[0]) >= int(per[0]) and int(wins[1]) >= int(per[1]) and int(wins[2]) >= int(per[2]),
							"%s %s L%d %s: at least %d windows (%s a phase) even played well (%s)" % [lid, cls, lvl, style, cfg["min"], str(per), str(wins)])
					if cfg.has("phase_max"):
						_check(float(pt[0]) <= float(cfg["phase_max"]) and float(pt[1]) <= float(cfg["phase_max"]) and float(pt[2]) <= float(cfg["phase_max"]),
								"%s %s L%d %s: each phase in %.0f s or less (%.0f / %.0f / %.0f)" % [lid, cls, lvl, style, cfg["phase_max"], pt[0], pt[1], pt[2]])
					_check(float(r["t"]) <= float(cfg["cap"]), "%s %s L%d %s: the fight within %.0f s (%.0f)" % [lid, cls, lvl, style, cfg["cap"], r["t"]])
	if FileAccess.file_exists("res://levels/4-4.txt"):
		await _test_tk_travel()
	else:
		print("  skipped: 4-4 isn't built")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	print("test_boss_windows: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _make_hero(cls: String, lvl: int, area: int) -> void:
	## A hero at lvl: skill points spent root first, then round the tree;
	## the calling's Blessed kit at the boss's area; boots and a charm with
	## their signature affix where the worlds give them.
	game.reset()
	game.data["difficulty"] = "dusk"
	game.new_hero(cls)
	game.set_hero(cls)
	var h: Dictionary = game.hero()
	var need: int = Progression.total_to(lvl) - int(h["xp"])
	if need > 0:
		game.add_xp(need)
	var tree: Array = Classes.tree(cls)
	var guard := 0
	while int(h["points"]) > 0 and guard < 400:
		guard += 1
		var bought := false
		for n in tree:
			if int(n["branch"]) == -1 and game.buy_skill(n["id"]):
				bought = true
				break
		if bought:
			continue
		var cands := tree.filter(func(n): return int(n["branch"]) >= 0)
		cands.sort_custom(func(p, q):
			var rp := int(h["skills"].get(p["id"], 0))
			var rq := int(h["skills"].get(q["id"], 0))
			if rp != rq:
				return rp < rq
			return int(p["tier"]) * 10 + int(p["branch"]) < int(q["tier"]) * 10 + int(q["branch"]))
		for n in cands:
			if game.buy_skill(n["id"]):
				bought = true
				break
		if not bought:
			break
	h["equip"] = Items.starter(cls, area, "magic")
	for slot in ["boots", "charm"]:
		if area < (13 if slot == "boots" else 18):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(slot + str(area))
		var it: Dictionary = Items.make(slot, cls, area, "common", rng)
		var sig: String = Items.SIGNATURE[slot]
		it["rarity"] = "magic"
		it["affixes"] = [{"id": sig, "t": int(it["tier"]), "v": Items.median(sig, int(it["tier"]))}]
		h["equip"][slot] = it


func _world(lid: String) -> Node2D:
	var lv = LevelData.load_file("res://levels/%s.txt" % lid)
	for k in ["start", "boss"]:
		var s := str(lv.story.get(k, ""))
		if s != "":
			game.mark_seen(s)
	for bid in ["rootmother", "tinker", "saint", "hush"]:
		game.mark_seen("boss_card_" + bid)
	var w: Node2D = World.new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.set_physics_process(false)
	w.test_pad = {}
	return w


func _tick(w: Node2D, pad := {}) -> void:
	w.test_pad = pad
	w._read_pad()
	w.tick(DT)


func _hold(w: Node2D, feet: Vector2, face: int, vine_col := -1) -> void:
	var pl: Node2D = w.player
	if vine_col >= 0:
		if not pl.climbing or pl.climb_col != vine_col:
			pl.grab_vine(vine_col)
	elif pl.climbing:
		pl.release_vine()
	pl.position = feet
	pl.velocity = Vector2.ZERO
	pl.on_floor = vine_col < 0
	pl.facing = face


func _oracle(lid: String, cls: String, style: String, lvl: int) -> Dictionary:
	_make_hero(cls, lvl, int(AREA[lid]))
	var w: Node2D = await _world(lid)
	var b: Node2D = w.boss
	# From just left of the door's altar, run in until he wakes.
	var al := Vector2.ZERO
	for a in w.altars:
		var p: Vector2 = a["pos"]
		if p.x < b.arena_left and p.x > al.x:
			al = p
	w.player.reset_at(al + Vector2(-40, 0))
	var t := 0.0
	while t < 8.0 and b.state == "sleep":
		_tick(w, {"right": true})
		t += DT
	var el := 0.0
	var wins := 0
	var cur_open := false
	var stomped := false
	var spec_t := 0.0
	var park := Vector2(b.arena_left + 12.5 * TILE, b.floor_y)
	var tinker: bool = b.boss_id == "tinker"
	var n := 0
	while el < CAP and b.alive:
		var pl: Node2D = w.player
		pl.invuln = 99.0
		pl.hp = pl.max_hp
		var pad := {}
		_tog = not _tog
		var target := Rect2()
		var vine := -1
		var feet := Vector2.ZERO
		if b.is_open():
			target = b.rect()
			if not tinker and b.target >= 0:
				var s: Dictionary = b.sockets[b.target]
				feet = Vector2(target.position.x - 12.0, float(s["base"].y))
				if bool(s["vine"]):
					var sb: float = b.surface_below(target.get_center().x - 20.0, target.end.y - 1.0)
					if absf(sb - target.end.y) > 20.0:
						vine = int(s["lane_x"])
						feet = Vector2((vine + 0.5) * TILE, target.end.y + 2.0)
					else:
						feet.y = sb
			else:
				feet = Vector2(target.position.x - 12.0, b.floor_y)
		elif tinker:
			for i in [b.hand_i, b._prev_i]:
				if i >= 0 and b.bell_ready(i):
					var bx: Rect2 = b.bells[i]["box"]
					feet = Vector2(bx.position.x - 12.0, float(b.bells[i]["surf"]))
					target = bx
					break
		if target.size.x > 0.0:
			var face := 1 if target.get_center().x > feet.x else -1
			if style == "best" and b.is_open() and not stomped and cls in ["knight", "founder", "sexton"]:
				pl.position = Vector2(target.get_center().x, target.position.y - 30.0)
				pl.velocity = Vector2(0, 420.0)
				pl.on_floor = false
				stomped = true
			else:
				_hold(w, feet, face, vine)
			pad["attack"] = _tog
			if style == "best" and b.is_open():
				spec_t += DT
				pad["special"] = fmod(spec_t, 0.8) < 0.3
				if cls == "knight":
					pad["right" if face > 0 else "left"] = pad["special"]
		else:
			stomped = false
			_hold(w, park, 1)
		_tick(w, pad)
		el += DT
		if b.is_open() and not cur_open:
			wins += 1
		cur_open = b.is_open()
		n += 1
		if n % 2400 == 0:
			await process_frame
	var adds: int = b.adds_alive()
	var out := {"dead": not b.alive, "t": el, "windows": wins, "adds": adds}
	w.queue_free()
	await process_frame
	return out


func _pad_oracle(lid: String, cls: String, style: String, lvl: int) -> Dictionary:
	## The fight through the boss's bot_pad from the door's altar, Wick
	## untouchable; "best" drops a stomp onto each window's target first.
	var cfg: Dictionary = V3[lid]
	_make_hero(cls, lvl, int(cfg["area"]))
	var w: Node2D = await _world(lid)
	var b: Node2D = w.boss
	# In on the arena's entry footing (as test_integration: the pads fight in
	# the arena; the approach is the level's).
	var door := Vector2(float(b.arena_left) + 80.0, b.position.y)
	var dc := floori(float(b.arena_left) / TILE) + 1
	for ty in range(2, w.level.height):
		if LevelData.is_solid(w.level.tile(dc, ty)):
			door = Vector2(dc * TILE + 16.0, ty * TILE)
			break
	w.player.reset_at(door)
	w.cam = w._clamp_cam(w.player.position)
	var out := {"t": 0.0, "phase_t": [0.0, 0.0, 0.0], "wins": [0, 0, 0], "won": false}
	var w0 := 0
	var t := 0.0
	var n := 0
	var stomped := -1
	while t < float(cfg["cap"]) + 20.0:
		var pl: Node2D = w.player
		pl.invuln = 99.0
		pl.hp = pl.max_hp
		if not is_instance_valid(b) or not b.alive or str(b.state) in ["finale", "closing", "dead"] or b.get("defeated") == true or b.hp <= 0.0:
			out["won"] = true
			break
		var ph := clampi(int(b.phase), 1, 3)
		if not (str(b.state) in ["sleep", "wake"]):
			out["phase_t"][ph - 1] = float(out["phase_t"][ph - 1]) + DT
		if int(b.windows_opened) > w0:
			out["wins"][ph - 1] = int(out["wins"][ph - 1]) + int(b.windows_opened) - w0
			w0 = int(b.windows_opened)
		var pd: Dictionary = b.bot_pad(pl)
		if pd.is_empty() and str(b.state) == "sleep":
			pd = {"right": true}
		if style == "best" and b.is_open() and stomped != int(b.windows_opened):
			var tr: Rect2 = b.rect()
			if tr.has_area():
				stomped = int(b.windows_opened)
				pl.reset_at(Vector2(tr.get_center().x, tr.position.y - 30.0))
				pl.velocity = Vector2(0, 420.0)
				pl.on_floor = false
		_tick(w, pd)
		t += DT
		n += 1
		if n % 2400 == 0:
			await process_frame
	out["t"] = t
	w.queue_free()
	await process_frame
	return out

# ---------------------------------------------------------------- the Tinker with real travel (v1.0.1)

var _jump_hold := 0
var _jump_prev := false
var _drop_hold := 0


func _test_tk_travel() -> void:
	## Every calling against the real 4-4 at the arrival level, travelling:
	## the fight's length in TK_TRAVEL's band.
	var lvl := int(ARRIVE["4-4"])
	var times := []
	for cls in CALLINGS:
		var r: Dictionary = await _tk_travel(cls, lvl)
		times.append(float(r["t"]))
		print("  4-4 %-7s L%d travel %s in %5.1f s, %d windows, phases %.0f / %.0f / %.0f s" % [cls, lvl, "won" if r["won"] else "NOT WON",
				r["t"], r["windows"], r["phase_t"][0], r["phase_t"][1], r["phase_t"][2]])
		_check(bool(r["won"]) and float(r["t"]) >= float(TK_TRAVEL["lo"]) and float(r["t"]) <= float(TK_TRAVEL["hi"]) and int(r["windows"]) >= int(TK_TRAVEL["min"]),
				"4-4 %s L%d with real travel: won in %.0f-%.0f s, %d windows at least (%s, %.1f s, %d windows)" % [cls, lvl, TK_TRAVEL["lo"], TK_TRAVEL["hi"],
				TK_TRAVEL["min"], "won" if r["won"] else "not won", r["t"], r["windows"]])
	var mean := 0.0
	for x in times:
		mean += float(x)
	mean /= maxf(float(times.size()), 1.0)
	print("  4-4 with real travel: mean %.1f s" % mean)
	_check(mean >= float(TK_TRAVEL["mean_lo"]) and mean <= float(TK_TRAVEL["mean_hi"]),
			"the Tinker's fight with real travel averages %.0f-%.0f s over the callings (%.1f s)" % [TK_TRAVEL["mean_lo"], TK_TRAVEL["mean_hi"], mean])


func _tk_travel(cls: String, lvl: int) -> Dictionary:
	_make_hero(cls, lvl, int(AREA["4-4"]))
	game.data["run_counter"] = 1014
	var w: Node2D = await _world("4-4")
	var b: Node2D = w.boss
	var al := Vector2.ZERO
	for a in w.altars:
		var p: Vector2 = a["pos"]
		if p.x < b.arena_left and p.x > al.x:
			al = p
	w.player.reset_at(al + Vector2(-40, 0))
	_jump_hold = 0
	_jump_prev = false
	_drop_hold = 0
	var out := {"won": false, "t": 0.0, "windows": 0, "phase_t": [0.0, 0.0, 0.0]}
	var ready_t := 0.0
	var w0: int = b.windows_opened
	var el := 0.0
	var n := 0
	while el < float(TK_TRAVEL["cap"]):
		var pl: Node2D = w.player
		pl.invuln = 99.0
		pl.hp = pl.max_hp
		if not is_instance_valid(b) or not b.alive or str(b.state) == "dead":
			out["won"] = true
			break
		var r := _tk_pad(w, b, ready_t)
		ready_t = float(r[1])
		_tick(w, _tk_finish(r[0]))
		if not (str(b.state) in ["sleep", "wake"]):
			el += DT
			out["phase_t"][clampi(int(b.phase), 1, 3) - 1] = float(out["phase_t"][clampi(int(b.phase), 1, 3) - 1]) + DT
		n += 1
		if n % 2400 == 0:
			await process_frame
	out["t"] = el
	out["windows"] = int(b.windows_opened) - w0
	w.queue_free()
	await process_frame
	return out


func _tk_span(w: Node2D, x: float, surf: float) -> Vector2:
	## The run of floor under the surface at x (its ends, px).
	var row := floori((surf + 1.0) / TILE)
	var c := floori(x / TILE)
	var l := c
	var r := c
	while l > 0 and LevelData.is_floor(w.level.tile(l - 1, row)) and not LevelData.is_solid(w.level.tile(l - 1, row - 1)):
		l -= 1
	while LevelData.is_floor(w.level.tile(r + 1, row)) and not LevelData.is_solid(w.level.tile(r + 1, row - 1)) and r - c < 60:
		r += 1
	return Vector2(l * TILE, (r + 1) * TILE)


func _tk_jump() -> void:
	if _jump_hold <= 0 and not _jump_prev:
		_jump_hold = 34


func _tk_go(w: Node2D, tx: float, tsurf: float) -> Dictionary:
	## A pad toward feet at (tx, tsurf): run; up onto a ledge by jumping from
	## under it; down through a ledge, or off its end.
	var pl: Node2D = w.player
	var pd := {}
	var px: float = pl.position.x
	var py: float = pl.position.y
	var dir := 0
	if absf(tx - px) > 5.0:
		dir = 1 if tx > px else -1
	if _drop_hold > 0:
		_drop_hold -= 1
		pd["down"] = true
		return pd
	if pl.on_floor and absf(py - tsurf) < 6.0:
		if dir != 0:
			pd["right" if dir > 0 else "left"] = true
		return pd
	if tsurf < py - 20.0:
		var sp := _tk_span(w, tx, tsurf)
		if pl.on_floor:
			if px > sp.x + 12.0 and px < sp.y - 12.0:
				_tk_jump()
				if dir != 0:
					pd["right" if dir > 0 else "left"] = true
			else:
				pd["right" if clampf(tx, sp.x + 20.0, sp.y - 20.0) > px else "left"] = true
		elif pl.velocity.y < 0.0 or py < tsurf + 4.0:
			if dir != 0:
				pd["right" if dir > 0 else "left"] = true
		else:
			var gx := clampf(tx, sp.x + 20.0, sp.y - 20.0)
			if absf(gx - px) > 4.0:
				pd["right" if gx > px else "left"] = true
		return pd
	if tsurf > py + 20.0 and pl.on_floor:
		var sp3 := _tk_span(w, px, py)
		if tx > sp3.x - 4.0 and tx < sp3.y + 4.0:
			_drop_hold = 30
			pd["down"] = true
			return pd
	if dir != 0:
		pd["right" if dir > 0 else "left"] = true
	return pd


func _tk_finish(pd: Dictionary) -> Dictionary:
	if _jump_hold > 0:
		_jump_hold -= 1
		pd["jump"] = true
	_jump_prev = bool(pd.get("jump", false))
	return pd


func _tk_bell_spot(b: Node2D, i: int) -> Array:
	## Beside bell i on its floor, toward the middle (VI: away from him):
	## [feet, facing].
	var bx := float(b.bells[i]["cx"])
	var side := 1.0 if bx < (b.arena_left + b.arena_right) * 0.5 else -1.0
	if b.ORDER[i] == "VI":
		side = -1.0 if b.position.x > bx else 1.0
	return [Vector2(bx + side * 27.0, float(b.bells[i]["surf"])), -int(side)]


func _tk_pad(w: Node2D, b: Node2D, ready_t: float) -> Array:
	## [the pad, the seconds the bell it waits at has been ready].
	var pl: Node2D = w.player
	_tog = not _tog
	if b.state == "sleep" or b.state == "dead":
		return [{"right": true}, 0.0]
	if b.state == "wake" or b.state == "roar":
		var pw := {}
		_tk_wall(w, b, pw)
		return [pw, 0.0]
	var px: float = pl.position.x
	if b.is_open():
		# The window: to the spring, facing it, striking.
		var r: Rect2 = b.rect()
		var left := px < r.get_center().x
		var fx := r.position.x - 12.0 if left else r.end.x + 12.0
		var pd := _tk_go(w, fx, b.floor_y)
		if absf(px - fx) < 14.0 and absf(pl.position.y - b.floor_y) < 4.0:
			pd.erase("left")
			pd.erase("right")
			if pl.facing != (1 if left else -1):
				pd["right" if left else "left"] = true
		pd["attack"] = _tog and absf(px - fx) < 40.0 and absf(pl.position.y - b.floor_y) < 30.0
		return [pd, 0.0]
	# The bell: the hand's (or the one it just left) when it's ready, else
	# the next the hand will reach (never XII, up on the beam).
	var want := -1
	for i in [b.hand_i, b._prev_i]:
		if i >= 0 and b.bell_ready(i) and b.ORDER[i] != "XII":
			want = i
			break
	if want < 0:
		var h: int = b.hand_i
		if bool(b._rung[h]) or b.ORDER[h] == "XII":
			h = (h + b.hand_dir + 4) % 4
			if b.ORDER[h] == "XII":
				h = (h + b.hand_dir + 4) % 4
		want = h
	var spot := _tk_bell_spot(b, want)
	var feet: Vector2 = spot[0]
	var pd2 := _tk_go(w, feet.x, feet.y)
	if absf(px - feet.x) < 10.0 and absf(pl.position.y - feet.y) < 4.0 and pl.on_floor:
		pd2.erase("left")
		pd2.erase("right")
		var face := int(spot[1])
		if pl.facing != face:
			pd2["right" if face > 0 else "left"] = true
		ready_t = ready_t + DT if b.bell_ready(want) else 0.0
		if b.bell_ready(want) and pl.facing == face and ready_t >= float(TK_TRAVEL["react"]):
			pd2["attack"] = _tog
	else:
		ready_t = 0.0
	_tk_wall(w, b, pd2)
	return [pd2, ready_t]


func _tk_wall(w: Node2D, b: Node2D, pd: Dictionary) -> void:
	## Never into his body while it hurts to touch (the Minute Hand's cut
	## since v1.0.1; every state but down before): no walking, jumping or
	## dropping into him, and giving way when he comes.
	if not b.touch_damage():
		return
	var pl: Node2D = w.player
	var body: Rect2 = b.body_rect()
	var pr: Rect2 = pl.rect()
	var gap := 26.0
	var left_of := pr.get_center().x < body.get_center().x
	var d := body.position.x - pr.end.x if left_of else pr.position.x - body.end.x
	var toward := "right" if left_of else "left"
	var level_with: bool = pr.end.y > body.position.y and pr.position.y < body.end.y
	if pl.on_floor and pl.position.y < b.floor_y - 8.0:
		if pd.get("down", false) and pr.end.x > body.position.x - gap and pr.position.x < body.end.x + gap:
			pd.erase("down")
			_drop_hold = 0
		if level_with and d < gap + 20.0 and pd.get(toward, false):
			pd.erase(toward)
		return
	if not pl.on_floor:
		if level_with and d < gap + 40.0 and pd.get(toward, false):
			pd.erase(toward)
			pd["right" if not left_of else "left"] = d < gap
		return
	if absf(pl.position.y - b.floor_y) > 8.0:
		return
	if d < gap:
		var away := -1 if left_of else 1
		var room: float = (pr.position.x - b.arena_left) if away < 0 else (b.arena_right - pr.end.x)
		pd.erase("left")
		pd.erase("right")
		pd.erase("attack")
		if room > 8.0:
			pd["right" if away > 0 else "left"] = true
		return
	if pd.get(toward, false) and d < gap + 40.0:
		pd.erase(toward)
