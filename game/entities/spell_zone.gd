class_name SpellZone
extends Node2D
## A spell's ground area: it opens at a point ahead of the caster, waits its
## `delay` (a real telegraph the target can walk out of), then resolves once
## against everything inside its radius and fades.
##
## Timing and geometry come from `TechniqueCombat`; the damage is resolved with
## the same `Damage` helpers a melee blow uses.

var radius := 90.0
var amount := 0.0
var power := 1.0
var poise_damage := 0.0
var knock_force := 0.0
var penetration := 0.0
var lifesteal := 0.0
var color := Color("#c0a0ff")

var _delay := 0.35
var _delay_total := 0.35
var _burst := 0.0
var _armed := true


func setup(spec: Dictionary, strike: Dictionary, tint: Color) -> void:
	radius = maxf(1.0, float(spec.get("radius", 90.0)))
	_delay = maxf(0.0, float(spec.get("delay", 0.35)))
	_delay_total = maxf(0.01, _delay)
	amount = float(strike.get("amount", 0.0))
	power = float(strike.get("power", 1.0))
	poise_damage = float(strike.get("poise", 0.0))
	knock_force = float(strike.get("knock", 0.0))
	penetration = float(strike.get("penetration", 0.0))
	lifesteal = float(strike.get("lifesteal", 0.0))
	color = tint
	z_index = 1
	add_to_group("spell_zone")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _armed:
		_burst -= delta
		if _burst <= 0.0:
			queue_free()
		queue_redraw()
		return
	_delay -= delta
	if _delay <= 0.0:
		_explode()
	queue_redraw()


func _explode() -> void:
	_armed = false
	_burst = 0.3
	var area := TechniqueCombat.spell_area({"radius": radius})
	var leeched := false
	for body in get_tree().get_nodes_in_group("enemy"):
		var enemy := body as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not Combat.in_hitbox(global_position, Vector2.RIGHT, area, enemy.global_position, 14.0):
			continue
		var final := Damage.resolve(amount, 0.0, power)
		if enemy.has_method("take_hit"):
			var push := global_position.direction_to(enemy.global_position) * knock_force
			enemy.take_hit(final, push, poise_damage, penetration)
		Bus.damage_dealt.emit(final, enemy)
		if lifesteal > 0.0 and not leeched:
			leeched = true
			var player := Game.player as Player
			if player != null and is_instance_valid(player):
				player.heal(final * lifesteal)


func _draw() -> void:
	if _armed:
		# A closing ring that reads as the telegraph, not as the damage.
		var progress := clampf(1.0 - _delay / _delay_total, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.08 + 0.10 * progress))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.55), 2.0)
		draw_arc(Vector2.ZERO, radius * (1.0 - progress * 0.85), 0.0, TAU, 40, Color(color, 0.7), 2.0)
		return
	var fade := clampf(_burst / 0.3, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.22 * fade))
	draw_arc(Vector2.ZERO, radius * (1.0 + (1.0 - fade) * 0.15), 0.0, TAU, 48, Color(color, 0.8 * fade), 3.0)
