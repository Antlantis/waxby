extends SceneTree
## A quick sim, not a test: the Candleknight at L1 on Dusk holds his guard,
## standing still, while a steady line of Rattles walks into it. How long
## does the guard last, and where does Grace go? Run headless:
##   godot --headless --path game --script res://../tools/shot_kits_grace.gd -- [regen_share] [rattles] [start_grace] [gap_px] [area] [level] [diff] [block_mult]
## regen_share: the share of Grace's 4/s that also flows while guarding
## (added here by hand on top of the kit, so the kit's own knob can be
## anything); rattles: how many in the line; start_grace: Grace at the start;
## gap_px: the spacing of the line (34: shoulder to shoulder); area: the
## level's area (1-1 is 1, 1-3 is 5, 2-4 is 12); level: the hero's level;
## diff: dusk / nightfall / witching; block_mult: the kit's block_mult (a
## block's Grace cost scaled, 1.0 as shipped).
## The time that matters is "under pressure": from the first Rattle meeting
## the shield to the guard breaking (the line takes a while to walk up).

const LevelData := preload("res://scripts/level_data.gd")
const DT := 1.0 / 120.0
const GROUND := 13 * 32


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var share := float(args[0]) if args.size() > 0 else 0.0
	var n := int(args[1]) if args.size() > 1 else 6
	var start := float(args[2]) if args.size() > 2 else 50.0
	var gap := float(args[3]) if args.size() > 3 else 34.0
	var area := int(args[4]) if args.size() > 4 else 1
	var hero_level := int(args[5]) if args.size() > 5 else 1
	var diff: String = args[6] if args.size() > 6 else "dusk"
	var bmult := float(args[7]) if args.size() > 7 else 1.0
	var game: Node = root.get_node("Game")
	game.save_path = "user://sim_grace_save.json"
	game.reset()
	game.new_hero("knight")
	game.data["unlocked"][diff] = 1
	game.data["difficulty"] = diff
	var h: Dictionary = game.hero()
	h["level"] = hero_level
	h["xp"] = load("res://scripts/progression.gd").total_to(hero_level)
	game.save()   # (the Game autoload reads its save back on its first frame)
	var rows := []
	for y in 15:
		rows.append("#".repeat(120) if y >= 13 else ".".repeat(120))
	rows[12] = "..P" + ".".repeat(117)
	var lv = LevelData.new()
	lv.parse("title: t\nsubtitle: t\narea: %d\n---\n" % area + "\n".join(rows))
	var w: Node2D = load("res://scripts/world.gd").new()
	w.setup(lv, true)
	root.add_child(w)
	await process_frame
	w.test_pad = {}
	for i in 30:
		w.tick(DT)
	var pl: Node2D = w.player
	var kit: Object = w.kit
	pl.reset_at(Vector2(600, GROUND))
	pl.facing = 1
	_tick(w, {}, 10)
	pl.res = start
	var guard_kit_regen: bool = kit.REGEN_WHILE_GUARDING if typeof(kit.get("REGEN_WHILE_GUARDING")) == TYPE_BOOL else false
	for i in n:
		var e: Node2D = w.spawn_enemy("skeleton", Vector2(600 + 60 + gap * i, GROUND), {})
		e.active = true
		e.facing = -1
	w.apply_hero()
	pl.hp = pl.max_hp
	kit.block_mult = bmult
	print("sim: %d Rattles %.0f px apart, touch %.0f (%s, area %d), L%d knight %.0f HP, Grace %.0f, a Rattle's block costs %.1f, extra regen %.0f%% (kit knob %s)" % [
			n, gap, w.enemies[0].dmg("touch"), w.diff, w.area, hero_level, pl.max_hp, pl.res, kit.block_cost(w.enemies[0].dmg("touch")), share * 100.0,
			str(kit.get("REGEN_WHILE_GUARDING"))])
	# Raise the guard and hold it.
	var t := 0.0
	var broke := -1.0
	var hp0: float = pl.hp
	var trace := []
	var first := -1.0
	var nb := 0
	var events := []
	for i in int(12.0 / DT):
		var r0: float = pl.res
		_tick(w, {"special": true})
		if kit.blocks + kit.perfect_guards != nb:
			nb = kit.blocks + kit.perfect_guards
			var who := -1
			for k in kit._block_cd.keys():
				for j in w.enemies.size():
					if w.enemies[j].get_instance_id() == k and kit._block_cd[k] > kit.CONTACT_CD - 0.02:
						who = j
			events.append("%.2f(-%.0f #%d)" % [t, r0 - pl.res, who])
			if first < 0.0:
				first = t
		if kit.guarding and share > 0.0:
			kit.regen(DT * share)
		t += DT
		if i % 60 == 0:
			trace.append("%.1fs:%.0f" % [t, pl.res])
		if broke < 0.0 and kit._stagger > 0.0:
			broke = t
			break
	print("  blocks %d, perfect %d, grace trace %s" % [kit.blocks, kit.perfect_guards, " ".join(trace)])
	print("  block times %s; first contact %.2f s" % [" ".join(events), first])
	if first < 0.0:
		first = broke   # it broke on the very first blow
	if broke >= 0.0:
		print("  GUARD BROKE %.2f s after the first Rattle met it (%.2f s after raising it; hp %.0f -> %.0f)" % [broke - first, broke, hp0, pl.hp])
	else:
		print("  guard held 12 s (Grace %.0f, hp %.0f/%.0f)" % [pl.res, pl.hp, pl.max_hp])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sim_grace_save.json"))
	quit()


func _tick(w: Node2D, pad: Dictionary, k := 1) -> void:
	for i in k:
		w.test_pad = pad
		w._read_pad()
		w.tick(DT)
