# The retune's difficulty probe (Build 2, step 14): the --autoplay bot
# (autoplay_bot.gd) plays level files on Dusk with the hero a first run
# brings there (the level given after the @: its arrival level, a few XP
# short of the next, a Blessed starter kit at the level's area, no points
# spent), one run a calling and seed (the seed is the run counter: the
# random Anointed differ), and logs what each run cost: the bell, the time,
# the snuffs and where (cause, x, y), and the life lost, in lives (damage
# over max life; a snuff counts what was left), by the cause of each blow
# (world.gd snuff_causes: a monster's kind, a boss's id, or a hazard: pit,
# lava, water, tide, spikes, hit (a weight)...) and by altar stretch (how
# many altars were lit). A level file may be anywhere (an old cut's copy, a
# variant): its name gives its id. It is a debug bot: it can't time World
# 4's weights, stalls on some climbs and loops on a death it can't learn
# from, so read a level's cost against its own world's and its old cut's,
# monsters apart from hazards, never as a human's snuffs.
#   godot --headless --path game --script res://../tools/difficulty_probe.gd -- \
#       <path>@<arrival>[,...] [callings|all] [seconds] [seeds] [out.json]
#   e.g. -- res://levels/5-3.txt@24 all 480 3 /tmp/5-3.json
extends SceneTree

const DT := 1.0 / 120.0
const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
const HAZARDS := ["pit", "lava", "water", "void", "tide", "spikes", "icicle", "hit"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var game: Node = root.get_node("Game")
	game.save_path = "user://difficulty_probe_save.json"
	var Progression = load("res://scripts/progression.gd")
	var LevelData = load("res://scripts/level_data.gd")
	var Items = load("res://scripts/items.gd")
	var World = load("res://scripts/world.gd")
	var specs: Array = Array(args[0].split(",")) if args.size() > 0 else []
	var callings: Array = CALLINGS if args.size() < 2 or args[1] == "all" else Array(args[1].split(","))
	var secs := float(args[2]) if args.size() > 2 else 480.0
	var seeds := int(args[3]) if args.size() > 3 else 3
	var out_path := str(args[4]) if args.size() > 4 else ""
	var rows: Array = []
	for spec in specs:
		var parts: PackedStringArray = str(spec).split("@")
		var path := parts[0]
		var want := int(parts[1]) if parts.size() > 1 else 1
		var mine: Array = []
		for cls in callings:
			for s in seeds:
				game.reset()
				for k in ["intro", "oath"]:
					game.mark_seen(k)
				game.new_hero(cls)
				var target: int = Progression.total_to(want + 1) - 3
				if int(game.hero()["xp"]) < target:
					game.add_xp(target - int(game.hero()["xp"]))
				var lv = LevelData.load_file(path)
				game.hero()["equip"] = Items.starter(cls, maxi(int(lv.area), 1), "magic")
				for k in ["start", "boss"]:
					var sid := str(lv.story.get(k, ""))
					if sid != "":
						game.mark_seen(sid)
				game.data["run_counter"] = 1000 + s * 7
				var w: Node2D = World.new()
				w.setup(lv, true)
				w.autoplay = true
				root.add_child(w)
				w.set_physics_process(false)
				await process_frame
				var pl: Node2D = w.player
				var prev_hp: float = pl.hp
				var prev_sn: int = w.snuffs
				var by := {}       # altars lit -> lives lost
				var causes := {}   # the blow's cause -> lives lost
				var t := 0.0
				for i in int(secs / DT):
					if w.get("_bot") == null:
						break
					w.test_pad = w._bot.pad(DT)
					w._read_pad()
					w.tick(DT)
					var lit: int = w.altars.filter(func(a): return a.get("lit", false)).size()
					var lost := 0.0
					if w.snuffs != prev_sn:
						lost = prev_hp
						prev_sn = w.snuffs
					elif prev_hp > float(pl.hp):
						lost = prev_hp - float(pl.hp)
					if lost > 0.0:
						var q := lost / maxf(float(pl.max_hp), 1.0)
						var cz := str(w.snuff_causes.get("_last", "hit"))
						by[lit] = float(by.get(lit, 0.0)) + q
						causes[cz] = float(causes.get(cz, 0.0)) + q
					prev_hp = pl.hp
					if i % 600 == 0:
						await process_frame
					t = (i + 1) * DT
					if w.state == "clear":
						break
				var mon := 0.0
				for k in causes:
					if not HAZARDS.has(k):
						mon += float(causes[k])
				var r := {"path": path, "id": str(lv.id), "cls": cls, "seed": s, "arrival": want, "bell": w.state == "clear",
						"t": snappedf(t, 0.1), "snuffs": int(w.snuffs), "monster_lives": snappedf(mon, 0.01), "by_stretch": by, "by_cause": causes,
						"where": w.snuff_sections.map(func(q): return [str(q["cause"]), int(q["x"]), int(q["y"])])}
				rows.append(r)
				mine.append(r)
				print("[probe] %-6s %-7s s%d L%d %s %5.1f s, snuffs %2d, monster lives %5.2f, by cause %s" % [str(lv.id), cls, s, want,
						"BELL" if r["bell"] else "----", t, r["snuffs"], mon, _short(causes)])
				w.queue_free()
				await process_frame
		if not mine.is_empty():
			var n := float(mine.size())
			print("[probe] %s (%s) at L%d: %d runs, %.0f%% rang the bell, %.2f snuffs, %.2f monster lives a run" % [mine[0]["id"], path, want,
					mine.size(), 100.0 * mine.filter(func(q): return q["bell"]).size() / n,
					mine.reduce(func(a, q): return a + int(q["snuffs"]), 0) / n, mine.reduce(func(a, q): return a + float(q["monster_lives"]), 0.0) / n])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(rows, " "))
	for f in [game.save_path, game.save_path + ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	quit(0)


func _short(d: Dictionary) -> String:
	var ks := d.keys()
	ks.sort_custom(func(a, b): return float(d[a]) > float(d[b]))
	return ", ".join(ks.slice(0, 4).map(func(k): return "%s %.2f" % [k, float(d[k])]))
