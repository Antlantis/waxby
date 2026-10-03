extends RefCounted
## The Altar Rites: a skill point spent the moment it's earned. With one
## waiting, a lit altar in a story level stops play and offers up to three
## skills on the choice card (world.open_rites, choice_card.gd), with Later
## (the point keeps: the next altar asks again, and the Sheet has it); a pick
## with points left brings the next three. The results screen's "skill
## points to spend" line opens the same card.
##
## What's offered, of the nodes Classes.can_buy allows now (no numbers
## change: these are the tree's own nodes, at the tree's own gates):
##   1. a tier just opened, deepest first (no node of it owned yet: the
##      capstones at L8, the Deep nodes at L16, Mastery at L24)
##   2. a node that adds a behaviour, not owned yet
##   3. more ranks of an owned behaviour node, then the Special's next rank
##   4. a plain +x% node (a "stat" node): at most one card of these
## Ties go to the deeper tier, then the tree's order. Static.

const UI := preload("res://scripts/ui.gd")
const Classes := preload("res://scripts/classes.gd")
const SkillsPanel := preload("res://scripts/skills_panel.gd")

const MAX := 3
const STAT_MAX := 1               # +x% cards in one offer


static func picks(h: Dictionary, n := MAX) -> Array:
	## The ids of the nodes to offer hero h (its cls, skills, level,
	## points), best first: [] with no point waiting or nothing to buy.
	var cls := str(h.get("cls", "knight"))
	var ranks: Dictionary = h.get("skills", {})
	var level := int(h.get("level", 1))
	var points := int(h.get("points", 0))
	if points <= 0:
		return []
	var tree := Classes.tree(cls)
	var owned_tier := {}
	for m in tree:
		if int(ranks.get(m["id"], 0)) > 0 and int(m["branch"]) >= 0:
			owned_tier[int(m["tier"])] = true
	var scored: Array = []
	for i in tree.size():
		var m: Dictionary = tree[i]
		if Classes.can_buy(cls, m["id"], ranks, level, points) != "":
			continue
		scored.append([score(m, rank_of(m, ranks), owned_tier), int(m["tier"]), i, m])
	scored.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] > b[0]
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[2] < b[2])
	var out: Array = []
	var stats := 0
	for s in scored:
		var m: Dictionary = s[3]
		if str(m["stat"]) != "":
			if stats >= STAT_MAX:
				continue
			stats += 1
		out.append(str(m["id"]))
		if out.size() >= n:
			break
	return out


static func score(m: Dictionary, rank: int, owned_tier: Dictionary) -> int:
	## A node's place in the offer (higher first): see the notes at the top.
	var tier := int(m["tier"])
	if tier >= 3 and rank == 0 and not owned_tier.has(tier):
		return 100 + tier   # a tier just opened
	if int(m["branch"]) == -1:
		return 30           # the Special's next rank
	if str(m["stat"]) != "":
		return 10           # +x%
	return 60 if rank == 0 else 40


static func rank_of(m: Dictionary, ranks: Dictionary) -> int:
	return int(ranks.get(m["id"], 1 if int(m["branch"]) == -1 else 0))


static func is_new(m: Dictionary, rank: int, owned_tier: Dictionary) -> bool:
	## The card's NEW tag: a behaviour not owned yet, or a tier just opened.
	return rank == 0 and (str(m["stat"]) == "" or (int(m["tier"]) >= 3 and not owned_tier.has(int(m["tier"]))))


static func offers(h: Dictionary, n := MAX) -> Array:
	## picks() as choice cards: {id, name, text (what its next rank does),
	## glyph (the Skills tab's), col (the calling's), sub ("Capstone ·
	## rank 1 of 1"), new}.
	var cls := str(h.get("cls", "knight"))
	var ranks: Dictionary = h.get("skills", {})
	var owned_tier := {}
	for m in Classes.tree(cls):
		if int(ranks.get(m["id"], 0)) > 0 and int(m["branch"]) >= 0:
			owned_tier[int(m["tier"])] = true
	var col := UI.class_color(cls).lightened(0.25)
	var out: Array = []
	for id in picks(h, n):
		var m := Classes.find_node(cls, id)
		var r := rank_of(m, ranks)
		var tier := "Special" if int(m["branch"]) == -1 else str(SkillsPanel.TIER_NAME.get(int(m["tier"]), "Tier %d" % int(m["tier"])))
		out.append({"id": id, "name": str(m["name"]), "text": Classes.node_text(m, r + 1), "glyph": glyph(m), "col": col,
				"sub": "%s · rank %d of %d" % [tier, r + 1, int(m["max"])], "new": is_new(m, r, owned_tier)})
	return out


static func glyph(m: Dictionary) -> String:
	## The node's mark, as the Skills tab draws it: the flame for the
	## Special, the sun for a capstone, else by id or by stat.
	if int(m["branch"]) == -1:
		return "flame"
	if int(m["tier"]) == 3:
		return "sun"
	return str(SkillsPanel.GLYPH_BY_ID.get(m["id"], SkillsPanel.GLYPH_BY_STAT.get(m["stat"], "star")))


static func heading(h: Dictionary) -> String:
	var pts := int(h.get("points", 0))
	return "Choose a skill" if pts <= 1 else "Choose a skill · %d points" % pts


static func learned(h: Dictionary, id: String) -> String:
	## The toast's line under a skill just learned: "Learned", or its rank.
	var m := Classes.find_node(str(h.get("cls", "knight")), id)
	if m.is_empty():
		return ""
	var r := rank_of(m, h.get("skills", {}))
	if int(m["max"]) <= 1 or (r <= 1 and int(m["branch"]) != -1):
		return "Learned"
	return "Rank %d of %d" % [r, int(m["max"])]
