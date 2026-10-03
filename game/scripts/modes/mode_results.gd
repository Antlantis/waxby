extends Control
## The Endless Descent's results (spec §7.6): the depth cleared (and the
## best), the run's time, kills, the XP and items it brought, its milestones,
## and Again / Challenges / Map. What the run keeps is kept already (XP,
## items and relics, banked embers); what it loses is gone with it.

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/modes/mode_art.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const Classes := preload("res://scripts/classes.gd")
const Cosmetics := preload("res://scripts/modes/cosmetics.gd")
const DESCENT := "res://scripts/modes/descent.gd"

var results := {}
var main: Node = null
var _t := 0.0
var _btns: Array = []
var _tb := TriBatch.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.warm()
	var again := UI.make_button("Again", true, func(): _again(), "", 20)
	again.custom_minimum_size = Vector2(150, 50)
	var hub := UI.make_button("Challenges", false, func(): _hub(), "click", 16)
	hub.custom_minimum_size = Vector2(140, 44)
	var map := UI.make_button("Map", false, func(): _map(), "back", 16)
	map.custom_minimum_size = Vector2(100, 44)
	for b in [again, hub, map]:
		add_child(b)
		_btns.append(b)
	var s := get_node_or_null("/root/Sfx")
	if s != null:
		s.play_music("story")
		if bool(results.get("new_best", false)):
			s.play("record")


func _again() -> void:
	var g := get_node_or_null("/root/Game")
	var strength := str(g.setting("candle_strength")) if g != null else "normal"
	load(DESCENT).start(main, str(results.get("cls", "knight")), str(results.get("diff", "dusk")), strength, 1)


func _hub() -> void:
	if main != null and main.has_method("show_modes"):
		main.show_modes("descent")


func _map() -> void:
	if main != null and main.has_method("show_map"):
		main.show_map()


func _process(dt: float) -> void:
	_t += dt
	var s := UI.safe_rect(get_viewport())
	var x := s.end.x
	for i in range(_btns.size() - 1, -1, -1):
		var b: Button = _btns[i]
		b.reset_size()
		x -= b.size.x
		b.position = Vector2(x, s.end.y - 54.0)
		x -= 12.0
	queue_redraw()


func _draw() -> void:
	UI.backdrop(self, get_size())
	var s := UI.safe_rect(get_viewport())
	var r := results
	var ended := str(r.get("ended", "snuffed"))
	var head := "The Deep keeps you" if ended == "snuffed" else "The run ends"
	UI.text(self, Vector2(s.position.x, s.position.y + 34.0), head, 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, "title", 700, 4)
	var cls := str(r.get("cls", "knight"))
	var sub := "%s · %s" % [str(Classes.info(cls)["name"]), {"dusk": "Dusk", "nightfall": "Nightfall", "witching": "the Witching Hour"}.get(str(r.get("diff", "dusk")), "")]
	UI.text(self, Vector2(s.position.x, s.position.y + 56.0), sub, 14, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, s.size.x)
	# The depth, big.
	var depth := int(r.get("depth", 0))
	var p := Rect2(s.position.x + 20.0, s.position.y + 76.0, 230.0, 190.0)
	UI.panel(self, p, UI.GOLD, Color("1d1529"), 14.0)
	UI.text(self, p.position + Vector2(0, 30), "Depth cleared", 14, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
	UI.text(self, p.position + Vector2(0, 104), str(depth), 64, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, p.size.x, "title", 700, 4)
	var best := int(r.get("best", 0))
	UI.text(self, p.position + Vector2(0, 138), "a new best" if bool(r.get("new_best", false)) else "best %d" % best, 15, UI.GOLD if bool(r.get("new_best", false)) else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, p.size.x, "body", 700)
	if int(r.get("start", 1)) > 1:
		UI.text(self, p.position + Vector2(0, 162), "from depth %d" % int(r["start"]), 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
	# The run.
	var q := Rect2(p.end.x + 16.0, p.position.y, s.end.x - p.end.x - 16.0, p.size.y)
	UI.panel(self, q, UI.PANEL_EDGE, Color(UI.PANEL, 0.92), 14.0)
	var t := float(r.get("time", 0.0))
	var rows := [
		["Time", "%d:%02d" % [int(t) / 60, int(t) % 60]],
		["Put out", "%d (%d elite)" % [int(r.get("kills", 0)), int(r.get("elites", 0))]],
		["XP", "+%d" % int(r.get("xp", 0))],
		["Items found", str(int(r.get("items", 0)))],
		["Spare Wicks spent", str(int(r.get("spare_used", 0)))],
	]
	for i in rows.size():
		var y := q.position.y + 30.0 + i * 24.0
		UI.text(self, Vector2(q.position.x + 16.0, y), str(rows[i][0]), 14, UI.MUTED)
		UI.text(self, Vector2(q.position.x, y), str(rows[i][1]), 15, UI.CREAM, HORIZONTAL_ALIGNMENT_RIGHT, q.size.x - 16.0, "body", 700)
	var ms: Array = r.get("milestones", [])
	if not ms.is_empty():
		var bits := PackedStringArray()
		for m in ms:
			var b := "Depth %d" % int(m.get("depth", 0))
			if m.has("cosmetic"):
				b += ": " + Cosmetics.reward_name(str(m["cosmetic"]))
			bits.append(b)
		UI.text(self, Vector2(q.position.x + 16.0, q.end.y - 18.0), "Milestones: " + ", ".join(bits), 13, UI.GOOD, HORIZONTAL_ALIGNMENT_LEFT, q.size.x - 32.0)
	UI.text(self, Vector2(s.position.x + 20.0, s.end.y - 24.0), "Kept: XP, items, relics, banked embers.", 12, UI.MUTED)
	_tb.flush(self)
