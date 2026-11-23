class_name Dummy
extends CharacterBody2D
## A hostile cultivator dummy: the first real combat opponent.
##
## It telegraphs, then strikes. It is intentionally simple, but it uses the same
## poise, stagger and damage rules as everything else, so those rules are already
## exercised in gameplay rather than existing only in a design document.

const RADIUS := 13.0

var hp := 70.0
var hp_max := 70.0
## Shared guard meter: the same rules the player lives by.
var poise := Poise.new(40.0)
## Poise this body's blow carries, and how hard it throws the target.
var strike_poise := 10.0
var knockback := 150.0
var ilvl := 1
var speed := 60.0
var attack_range := 48.0
var damage := 7.0
## Physical armour. Without it, penetration would have nothing to pierce.
var armor_value := 0.0
var aggressive := true
var display_name := "Cultivator Dummy"
var body_color := Color("#a85050")

var animator := Animator.new()

var _flash := 0.0
var _knock := Vector2.ZERO
var _windup := 0.0
var _cooldown := 0.8
var _dead := false


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 1
	collision_mask = 1
	hp_max = 70.0 + ilvl * 18.0
	hp = hp_max
	poise.set_maximum(40.0 + ilvl * 6.0, true)
	damage = 6.0 + ilvl * 2.0
	strike_poise = 8.0 + float(ilvl) * 2.0
	knockback = 140.0 + float(ilvl) * 10.0
	armor_value = _armor_for_level()


func _armor_for_level() -> float:
	return 8.0 + float(ilvl) * 5.0


## Applies a biome enemy definition. Called after `_ready`, because `_ready`
## derives the base stats from `ilvl` first.
func apply_biome_enemy(entry: Dictionary, realm: int) -> void:
	if entry.is_empty():
		return
	display_name = String(entry.get("name", display_name))
	ilvl = maxi(1, realm + int(entry.get("ilvl_bonus", 0)))
	hp_max = (70.0 + ilvl * 18.0) * float(entry.get("hp_mult", 1.0))
	hp = hp_max
	poise.set_maximum((40.0 + ilvl * 6.0) * float(entry.get("poise_mult", 1.0)), true)
	damage = (6.0 + ilvl * 2.0) * float(entry.get("damage_mult", 1.0))
	strike_poise = (8.0 + float(ilvl) * 2.0) * float(entry.get("damage_mult", 1.0))
	knockback = 140.0 + float(ilvl) * 10.0
	armor_value = _armor_for_level()
	speed = float(entry.get("speed", speed))
	body_color = Color(String(entry.get("color", "#a85050")))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_flash = maxf(0.0, _flash - delta)
	poise.tick(delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	animator.update(delta, velocity.length() / maxf(1.0, speed), false,
		_windup > 0.0, false, poise.is_staggered(), false, _dead)

	var knock_step := 900.0 * delta
	_knock = _knock.move_toward(Vector2.ZERO, knock_step)

	var target := Game.player as Node2D
	if poise.is_staggered() or target == null:
		velocity = _knock
		move_and_slide()
		queue_redraw()
		return

	if _windup > 0.0:
		_windup -= delta
		velocity = _knock
		if _windup <= 0.0:
			_release_attack(target)
		move_and_slide()
		queue_redraw()
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if aggressive and dist < 300.0:
		if dist > attack_range and _cooldown <= 0.0:
			velocity = to_target.normalized() * speed + _knock
		elif dist <= attack_range and _cooldown <= 0.0:
			_windup = 0.45
			velocity = _knock
		else:
			velocity = _knock
	else:
		velocity = _knock
	move_and_slide()
	queue_redraw()


func _release_attack(target: Node2D) -> void:
	_cooldown = 1.4
	if target == null:
		return
	var reach := {"shape": "circle", "radius": attack_range, "angle": 360.0}
	if not Combat.in_hitbox(global_position, Vector2.RIGHT, reach, target.global_position, 18.0):
		return
	if target.has_method("take_hit"):
		target.take_hit(damage, global_position, true, strike_poise, knockback, self)


## A parry turns the blow back on its source. The wind-up is spoiled and the
## guard meter takes the reflected force, so a parry is a real opening.
func stagger(poise_damage: float) -> void:
	if _dead:
		return
	poise.apply(maxf(0.0, poise_damage))
	_windup = 0.0
	_cooldown = maxf(_cooldown, 0.35)
	queue_redraw()


## `penetration` is the attacker's fraction of ignored armour (0..0.6).
func take_hit(amount: float, knock: Vector2, poise_damage: float, penetration: float = 0.0) -> void:
	if _dead:
		return
	var effective_armor := armor_value * (1.0 - clampf(penetration, 0.0, 0.9))
	hp -= Damage.mitigate_armor(amount, effective_armor)
	_knock += knock * 0.12
	_flash = 0.14
	if poise.apply(poise_damage):
		_knock += knock * 0.2
		_windup = 0.0
	if hp <= 0.0:
		_die()
	queue_redraw()


func _die() -> void:
	if _dead:
		return
	_dead = true
	Game.register_kill()
	Bus.enemy_died.emit(global_position, ilvl)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, 6), RADIUS * 0.9, Color(0, 0, 0, 0.28))
	var body := body_color
	if _flash > 0.0:
		body = Color("#ffffff")
	if poise.is_staggered():
		body = Color("#c8a050")
	if _windup > 0.0:
		body = Color("#e07040")

	var pose := Animator.pose(animator.state, animator.time, 0.0)
	draw_set_transform(pose["bob"], float(pose["lean"]), pose["squash"])
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -RADIUS), Vector2(RADIUS, 0), Vector2(0, RADIUS), Vector2(-RADIUS, 0),
	]), body)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color("#2a1c1c"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _windup > 0.0:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 32, Color("#ff9060", 0.5), 2.0)

	var ratio := clampf(hp / hp_max, 0.0, 1.0)
	draw_rect(Rect2(-18, -RADIUS - 12, 36, 4), Color("#241a1a"))
	draw_rect(Rect2(-18, -RADIUS - 12, 36 * ratio, 4), Color("#d05050"))
