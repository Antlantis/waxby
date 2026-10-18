extends RefCounted
## The Tinker's fighter with real travel (v1.0.1), shared by
## test_boss_windows (the story 4-4, TK_TRAVEL) and test_rush_bosses (the
## Waxworks rematch): a pad-driven Wick, untouchable, who runs and jumps to
## the lit bell (onto IX's and III's ledges, down through them; no
## teleports), rings it once it's ready after a person's reaction, then
## strikes the spring the whole window. He waits out the XII beam as a floor
## player does, and never walks, jumps or drops into the Tinker's body while
## it hurts to touch (the Minute Hand's cut since v1.0.1).
##
##     var f = TkTravel.new(0.3)
##     var r: Dictionary = await f.fight(self, world, 240.0)
##     # {won, t (s from his wake), windows, phase_t [p1, p2, p3]}

const LevelData := preload("res://scripts/level_data.gd")
const DT := 1.0 / 120.0
const TILE := 32

var react := 0.3                    # s a ready bell waits before he strikes it
var _tog := false
var _jump_hold := 0
var _jump_prev := false
var _drop_hold := 0
var _ready_t := 0.0


func _init(react_s := 0.3) -> void:
	react = react_s


func fight(tree: SceneTree, w: Node2D, cap: float) -> Dictionary:
	## From where Wick stands to the Tinker's fall (or cap s of fight), Wick
	## untouchable, the World ticked by the pad. The clock starts when he
	## wakes.
	var b: Node2D = w.boss
	var out := {"won": false, "t": 0.0, "windows": 0, "phase_t": [0.0, 0.0, 0.0]}
	var w0: int = b.windows_opened
	var el := 0.0
	var n := 0
	while el < cap:
		var pl: Node2D = w.player
		pl.invuln = 99.0
		pl.hp = pl.max_hp
		if not is_instance_valid(b) or not b.alive or str(b.state) == "dead":
			out["won"] = true
			break
		w.test_pad = pad(w, b)
		w._read_pad()
		w.tick(DT)
		if not (str(b.state) in ["sleep", "wake"]):
			el += DT
			var ph := clampi(int(b.phase), 1, 3) - 1
			out["phase_t"][ph] = float(out["phase_t"][ph]) + DT
		n += 1
		if n % 2400 == 0:
			await tree.process_frame
	out["t"] = el
	out["windows"] = int(b.windows_opened) - w0
	return out


func pad(w: Node2D, b: Node2D) -> Dictionary:
	## This tick's pad.
	var pd := _pad(w, b)
	if _jump_hold > 0:
		_jump_hold -= 1
		pd["jump"] = true
	_jump_prev = bool(pd.get("jump", false))
	return pd


func _span(w: Node2D, x: float, surf: float) -> Vector2:
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


func _jump() -> void:
	if _jump_hold <= 0 and not _jump_prev:
		_jump_hold = 34


func _go(w: Node2D, tx: float, tsurf: float) -> Dictionary:
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
		var sp := _span(w, tx, tsurf)
		if pl.on_floor:
			if px > sp.x + 12.0 and px < sp.y - 12.0:
				_jump()
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
		var sp3 := _span(w, px, py)
		if tx > sp3.x - 4.0 and tx < sp3.y + 4.0:
			_drop_hold = 30
			pd["down"] = true
			return pd
	if dir != 0:
		pd["right" if dir > 0 else "left"] = true
	return pd


func _bell_spot(b: Node2D, i: int) -> Array:
	## Beside bell i on its floor, toward the middle (VI: away from him):
	## [feet, facing].
	var bx := float(b.bells[i]["cx"])
	var side := 1.0 if bx < (b.arena_left + b.arena_right) * 0.5 else -1.0
	if b.ORDER[i] == "VI":
		side = -1.0 if b.position.x > bx else 1.0
	return [Vector2(bx + side * 27.0, float(b.bells[i]["surf"])), -int(side)]


func _pad(w: Node2D, b: Node2D) -> Dictionary:
	var pl: Node2D = w.player
	_tog = not _tog
	if b.state == "sleep" or b.state == "dead":
		_ready_t = 0.0
		return {"right": true}
	if b.state == "wake" or b.state == "roar":
		_ready_t = 0.0
		var pw := {}
		_wall(w, b, pw)
		return pw
	var px: float = pl.position.x
	if b.is_open():
		# The window: to the spring, facing it, striking.
		_ready_t = 0.0
		var r: Rect2 = b.rect()
		var left := px < r.get_center().x
		var fx := r.position.x - 12.0 if left else r.end.x + 12.0
		var pd := _go(w, fx, b.floor_y)
		if absf(px - fx) < 14.0 and absf(pl.position.y - b.floor_y) < 4.0:
			pd.erase("left")
			pd.erase("right")
			if pl.facing != (1 if left else -1):
				pd["right" if left else "left"] = true
		pd["attack"] = _tog and absf(px - fx) < 40.0 and absf(pl.position.y - b.floor_y) < 30.0
		return pd
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
	var spot := _bell_spot(b, want)
	var feet: Vector2 = spot[0]
	var pd2 := _go(w, feet.x, feet.y)
	if absf(px - feet.x) < 10.0 and absf(pl.position.y - feet.y) < 4.0 and pl.on_floor:
		pd2.erase("left")
		pd2.erase("right")
		var face := int(spot[1])
		if pl.facing != face:
			pd2["right" if face > 0 else "left"] = true
		_ready_t = _ready_t + DT if b.bell_ready(want) else 0.0
		if b.bell_ready(want) and pl.facing == face and _ready_t >= react:
			pd2["attack"] = _tog
	else:
		_ready_t = 0.0
	_wall(w, b, pd2)
	return pd2


func _wall(w: Node2D, b: Node2D, pd: Dictionary) -> void:
	## Never into his body while it hurts to touch: no walking, jumping or
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
