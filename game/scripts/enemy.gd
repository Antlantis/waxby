extends "res://scripts/actor.gd"
## What every monster shares: life scaled by area and difficulty, how it can
## be hurt, its statuses, elite tiers and omens, touching it hurts, a death
## that plays out before it's removed, and its frames from art/enemies/.
## Each kind extends this with its own think() and numbers.
##
## A hit is one Dictionary (frozen): hit(h) -> bool where
##   h = {how, from_x, amount, crit, source, attack_id}
##   how: "stomp" "slash" "bump" "shock" "bolt" "shot" "wave" "skill"
##   amount: final damage (float); a missing amount means "enough to kill".
##   safe_stomp (optional): a Thornsole stomp, which lands on spikes too.
## _hurt(h) and _kill(h) take the same Dictionary.
##
## v3 (MA): the statuses gain "dazed" (it can't act and takes +50%: an
## alias of stun with the bonus) and "alerted" (elites.gd: speed x1.3, and a
## sleeping monster wakes); a kind with footing of its own (a vine, a wall,
## a rolling rim) overrides _stunned(dt), where v2's stun falls and slides.
## A v3 kind declares its own `var move_id` (the blow on its way: the World
## reads source.move_id for the playlog's snuffs by move; declared per kind,
## never here, so a boss script can declare its own) and lists its base
## blows in a MOVES const ({move: base damage at area 1, Dusk}) for dmg().

signal died(enemy: Node2D, how: String)

const Combat := preload("res://scripts/combat.gd")
const TEX_SCALE := 0.25
const ELITES := "res://scripts/elites.gd"
# A secret level's Warden: its base life (x e_hp), by secret level (spec §4.6).
const WARDEN_LIFE := {"1-S": 143.0, "2-S": 165.0, "3-S": 198.0, "4-S": 220.0, "5-S": 220.0, "6-S": 286.0}
const WARDEN_DMG := 1.25

var kind := "enemy"
var base_hp := 18.0             # at area 1, Dusk
var base_dmg := 26.0            # touch damage at area 1, Dusk
var poise := 0.0                # share of max life a hit needs to make it flinch
var xp_kind := ""               # progression.gd BASE_XP key ("" = kind)
var hp := 1.0
var max_hp := 1.0
var dmg_mult := 1.0             # area x difficulty x candle strength, set by setup_stats
var alive := true
var gone := false               # the World frees it once true
var stompable := true           # a stomp hurts it (false: spikes on top)
var ordinary := true            # fodder: respawns (Nightfall+), stomps always kill it
var embers := 2                 # dropped on death
var item_chance := 0.08
var relic_chance := 0.02
var facing := -1
var flash := 0.0                # white flash after a hit
var death_time := 0.0
var last_swing := -1            # the player's attack_id that last hit it
var frames := {}                # frame name -> Texture2D
var sprite: Sprite2D
var anchor := Vector2(64, 122)  # the frame point on position (feet; a bat's is its middle)
var t := 0.0
var active := false             # wakes when the camera is near
var status := {}                # burn slow stun root sooted flipped waxed -> seconds; sooted_bonus
var tier := ""                  # "", "anointed", "dread", "warden"
var omens: Array = []
var elite_name := ""
var respawned := false
var spawn := {}                 # {kind, cell} to respawn from
var scale_mult := 1.0           # multiplies the sprite scale (Twinned copies are 0.6)
var tint := Color(1, 1, 1)      # multiplies the sprite colour (elite, sooted, waxed)
var hp_bar := 0.0               # seconds the life bar stays shown
var recent := 0.0               # the bar's white "just lost" share
var area := 1
var flier := false              # flies (no tile physics while stunned)
var last_damage := 0.0          # what the last hit actually took off


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.scale = Vector2(TEX_SCALE, TEX_SCALE)
	sprite.offset = -anchor * 2.0
	add_child(sprite)


func setup_stats(a: int, diff_id: String, strength := "normal", world_n := 0) -> void:
	## Life and damage for this area and difficulty (and elite tier), and the
	## level's world: max_hp = base_hp x e_hp(area) x DIFF.hp; dmg_mult =
	## e_dmg(area) x DIFF.dmg x strength x DMG_WORLD_TRIM[world] (bosses skip
	## the trim). Before Combat has e_hp / e_dmg, both are e_scale (the same in
	## W1-W2, where Depth adds nothing).
	area = a
	var d := Combat.diff(diff_id)
	var hp_k := _scale("e_hp", a)
	var dmg_k := _scale("e_dmg", a)
	max_hp = base_hp * hp_k * float(d["hp"])
	dmg_mult = dmg_k * float(d["dmg"]) * float(Combat.CANDLE_STRENGTH.get(strength, 1.0))
	if get("boss_id") == null:
		dmg_mult *= world_trim(world_n)
	match tier:
		"anointed":
			max_hp *= 2.5
			dmg_mult *= 1.2
		"dread":
			max_hp *= 4.0
			dmg_mult *= 1.4
		"warden":
			var sid: String = str(level.id) if level != null else ""
			max_hp = float(WARDEN_LIFE.get(sid, base_hp * 5.0)) * hp_k * float(d["hp"])
			dmg_mult *= WARDEN_DMG
	hp = max_hp


static func _scale(fn: String, a: int) -> float:
	## Combat's e_hp / e_dmg when it has them (the Depth factor), else e_scale.
	for m in (Combat as Script).get_script_method_list():
		if m["name"] == fn:
			return float((Combat as Script).call(fn, a))
	return Combat.e_scale(a)


static func world_trim(world_n: int) -> float:
	## elites.gd DMG_WORLD_TRIM[world] (W5 0.9, W6 0.8), 1.0 until it's there.
	if not ResourceLoader.exists(ELITES):
		return 1.0
	var t = (load(ELITES) as Script).get_script_constant_map().get("DMG_WORLD_TRIM", {})
	return float(t.get(world_n, 1.0)) if t is Dictionary else 1.0


func dmg(what := "touch") -> float:
	## What one of its blows costs before damage reduction.
	return base_dmg * dmg_mult


func load_frames(names: Array) -> void:
	for n in names:
		var p := "res://art/enemies/%s.svg" % n
		if ResourceLoader.exists(p):
			frames[n] = load(p)


func show_frame(n: String) -> void:
	if sprite and frames.has(n):
		sprite.texture = frames[n]


func step(dt: float, player: Node2D) -> void:
	t += dt
	flash = maxf(flash - dt * 6.0, 0.0)
	hp_bar = maxf(hp_bar - dt, 0.0)
	recent = maxf(recent - dt * 2.5, 0.0)
	for k in status.keys():
		if k == "sooted_bonus":
			continue
		status[k] = float(status[k]) - dt
		if status[k] <= 0.0:
			status.erase(k)
	if not alive:
		death_time += dt
		_dying(dt)
	elif stunned():
		_stunned(dt)
	else:
		think(dt * (0.6 if status.has("slow") else 1.0), player)
	if sprite:
		var sm := TEX_SCALE * scale_mult
		sprite.scale = Vector2(sm * (1.0 if facing > 0 else -1.0), sm)
		sprite.offset.x = -anchor.x * 2.0
		var c := tint
		if status.has("sooted"):
			c = c * Color(0.55, 0.55, 0.6)
		if status.has("waxed"):
			c = c * Color(1.1, 1.05, 0.8)
		sprite.modulate = c.lerp(Color(3, 3, 3), flash) if flash > 0.0 else c
	queue_redraw()


func stunned() -> bool:
	return status.has("stun") or status.has("root") or status.has("flipped") or status.has("dazed")


func _stunned(dt: float) -> void:
	## A stunned step: it slides to a stop and falls (fliers hang where they are).
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * dt)
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	if not flier:
		move(dt)


func apply_status(name: String, seconds: float, data := {}) -> void:
	status[name] = maxf(float(status.get(name, 0.0)), seconds)
	if name == "sooted":
		status["sooted_bonus"] = float(data.get("bonus", 0.25))


func think(_dt: float, _player: Node2D) -> void:
	pass


func _dying(dt: float) -> void:
	# Default: pop up, fall off the screen.
	velocity.y += 1600.0 * dt
	position += velocity * dt
	rotation += dt * 6.0 * facing
	if death_time > 1.6:
		gone = true


func hurt_rect() -> Rect2:
	## Touching this hurts Wick.
	var r := rect()
	return r.grow(-4.0)


func hits_to_kill_estimate(dmg_per_hit: float) -> int:
	return ceili(max_hp / maxf(dmg_per_hit, 0.01))


func hit(h: Dictionary) -> bool:
	## True when it hurt the monster. See the file header for h.
	if not alive:
		return false
	var how: String = h.get("how", "slash")
	# Spikes on top turn a stomp away, unless it's flipped on its back or the
	# boots are made for it (Thornsole: the world sets h.safe_stomp).
	if how == "stomp" and not stompable and not status.has("flipped") and not h.get("safe_stomp", false):
		return false
	var amount: float = float(h.get("amount", max_hp))
	if status.has("dazed") and h.has("amount"):
		amount *= 1.5   # dazed: +50% (a stun with the bonus)
	var before := hp
	hp = maxf(hp - amount, 0.0)
	last_damage = before - hp
	flash = 1.0
	if max_hp >= 0.0 and (show_bar() or tier != ""):
		hp_bar = 2.5
		recent = minf(1.0, recent + (before - hp) / maxf(max_hp, 1.0))
	if hp <= 0.0:
		_kill(h)
	elif amount >= poise * max_hp or h.get("crit", false):
		_hurt(h)
	return true


func show_bar() -> bool:
	## Only what takes a few hits shows a life bar.
	return not ordinary or kind in ["thornback", "hollow_helm", "lidlurk"] or tier != ""


func _hurt(h: Dictionary) -> void:
	velocity.x = 160.0 * (1.0 if position.x > float(h.get("from_x", position.x)) else -1.0)


func _kill(h: Dictionary) -> void:
	alive = false
	death_time = 0.0
	var away := 1.0 if position.x >= float(h.get("from_x", position.x)) else -1.0
	velocity = Vector2(away * 90.0, -320.0)
	died.emit(self, h.get("how", "slash"))


func eye_points() -> Array:
	## Where its eyes glow (world space), for the dark.
	return []


func draw_glow(_glow: Node2D) -> void:
	## Tells and effects drawn above the dark (in world space).
	pass


func lights() -> Array:
	## [{p, r, s}] lights it gives off (a tell's glint).
	return []


func _draw() -> void:
	if frames.is_empty():
		var r := rect()
		r.position -= position
		draw_rect(r, Color("efe6d2") if kind == "skeleton" else Color("6a4a8a"))
		draw_circle(Vector2(facing * 4.0, r.position.y + 8.0), 3.0, Color("7ef0c8"))


func walk(dt: float, speed: float) -> void:
	## Pace along, turning at walls and at the edges of floors.
	velocity.x = facing * speed
	velocity.y = minf(velocity.y + 1800.0 * dt, 600.0)
	move(dt)
	if on_floor and (on_wall != 0 or not ground_ahead(facing)):
		facing = -facing
	elif on_wall != 0:
		facing = -facing
