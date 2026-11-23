class_name Projectile
extends Node2D
## A technique's travelling body: a sword-Qi bolt, a palm wind, a hurled needle.
##
## It owns only motion and the list of bodies it has already touched. Damage,
## poise and knockback are resolved exactly like a melee blow, so a projectile
## is a delivery — not a second combat system. One projectile touches each body
## at most once, stops after `pierce + 1` bodies, and dies at its range.

var direction := Vector2.RIGHT
var speed := 560.0
var radius := 9.0
var amount := 0.0
var power := 1.0
var poise_damage := 0.0
var knock_force := 0.0
var penetration := 0.0
var lifesteal := 0.0
var max_hits := 1
var color := Color("#7fd3e0")

var _life := 0.0
var _hits := 0
var _touched: Dictionary = {}


func setup(dir: Vector2, spec: Dictionary, strike: Dictionary, tint: Color) -> void:
	direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	speed = maxf(1.0, float(spec.get("speed", 560.0)))
	radius = maxf(1.0, float(spec.get("radius", 9.0)))
	var travel := maxf(0.0, float(spec.get("range", 440.0)))
	_life = travel / speed
	amount = float(strike.get("amount", 0.0))
	power = float(strike.get("power", 1.0))
	poise_damage = float(strike.get("poise", 0.0))
	knock_force = float(strike.get("knock", 0.0))
	penetration = float(strike.get("penetration", 0.0))
	lifesteal = float(strike.get("lifesteal", 0.0))
	max_hits = TechniqueCombat.max_hits(spec)
	color = tint
	z_index = 2
	add_to_group("projectile")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _life <= 0.0:
		queue_free()
		return
	var step := minf(_life, delta)
	_life -= delta
	global_position += direction * speed * step
	_scan()
	queue_redraw()


func _scan() -> void:
	var box := {"shape": "circle", "radius": radius, "angle": 360.0}
	for body in get_tree().get_nodes_in_group("enemy"):
		var enemy := body as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var id := enemy.get_instance_id()
		if _touched.has(id):
			continue
		if not Combat.in_hitbox(global_position, direction, box, enemy.global_position, 14.0):
			continue
		_touched[id] = true
		_hits += 1
		_land(enemy)
		if _hits >= max_hits:
			queue_free()
			return


func _land(enemy: Node2D) -> void:
	var final := Damage.resolve(amount, 0.0, power)
	if enemy.has_method("take_hit"):
		enemy.take_hit(final, direction * knock_force, poise_damage, penetration)
	Bus.damage_dealt.emit(final, enemy)
	if lifesteal > 0.0:
		var player := Game.player as Player
		if player != null and is_instance_valid(player):
			player.heal(final * lifesteal)


func _draw() -> void:
	# A narrow crescent along the flight path, with a soft halo.
	draw_circle(Vector2.ZERO, radius + 3.0, Color(color, 0.16))
	draw_arc(Vector2.ZERO, radius + 3.0, -0.7, 0.7, 12, color, 3.0)
	draw_line(-direction * (radius + 6.0), direction * radius, Color(color, 0.5), 2.0)
