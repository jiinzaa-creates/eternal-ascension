class_name Summon
extends Node2D
## A summoned spirit beast. It hunts the nearest enemy for its lifetime, closes to
## its reach and strikes on an interval, carrying a share of the technique's blow.
##
## It never owns combat rules of its own: the strike is `Damage` + `take_hit`, the
## same path the player uses. When its time runs out it simply fades away.

const RADIUS := 10.0
const SEEK_RANGE := 420.0

var amount := 0.0
var lightning := 0.0
var power := 1.0
var poise_damage := 0.0
var knock_force := 0.0
var penetration := 0.0
var speed := 140.0
var reach := 34.0
var interval := 1.0
var lifetime := 8.0
var lifetime_max := 8.0
var color := Color("#d0b060")
var label := "Spirit Beast"
var critical := false
var heavy := false
var status: Dictionary = {}

var _cooldown := 0.0
var _swing := 0.0
var _target: Node2D = null


func setup(spec: Dictionary, strike: Dictionary, tint: Color, title: String) -> void:
	var mult := maxf(0.0, float(spec.get("damage_mult", 0.4)))
	amount = float(strike.get("amount", 0.0)) * mult
	lightning = float(strike.get("lightning", 0.0)) * mult
	power = float(strike.get("power", 1.0))
	poise_damage = float(strike.get("poise", 0.0)) * mult
	knock_force = float(strike.get("knock", 0.0))
	penetration = float(strike.get("penetration", 0.0))
	critical = bool(strike.get("critical", false))
	heavy = bool(strike.get("heavy", false))
	var status_value: Variant = strike.get("status", {})
	status = status_value if typeof(status_value) == TYPE_DICTIONARY else {}
	speed = maxf(0.0, float(spec.get("speed", 140.0)))
	reach = maxf(1.0, float(spec.get("reach", 34.0)))
	interval = maxf(0.05, float(spec.get("interval", 1.0)))
	lifetime = maxf(0.1, float(spec.get("duration", 8.0)))
	lifetime_max = lifetime
	color = tint
	label = title
	z_index = 1
	add_to_group("summon")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Game.hitstop.is_frozen():
		return
	if lifetime <= 0.0:
		queue_free()
		return
	lifetime -= delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_swing = maxf(0.0, _swing - delta)
	_target = _nearest_enemy()
	if _target != null:
		var to := _target.global_position - global_position
		var dist := to.length()
		if dist > reach:
			if dist > 0.001 and speed > 0.0:
				global_position += to / dist * speed * delta
		elif _cooldown <= 0.0:
			_strike(to.normalized() if dist > 0.001 else Vector2.ZERO)
	queue_redraw()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := SEEK_RANGE
	for body in get_tree().get_nodes_in_group("enemy"):
		var enemy := body as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist := enemy.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _strike(dir: Vector2) -> void:
	_cooldown = interval
	_swing = 0.18
	if not is_instance_valid(_target):
		return
	var final := Damage.resolve(amount, 0.0, power)
	var push: Vector2 = dir.normalized() * knock_force if dir.length_squared() > 0.0001 else Vector2.ZERO
	var dealt := 0.0
	if _target.has_method("take_hit"):
		dealt = float(_target.take_hit(final, push, poise_damage, penetration, status))
		if lightning > 0.0:
			dealt += float(_target.take_hit(Damage.resolve(lightning, 0.0, power), Vector2.ZERO, 0.0, 0.9, {}))
	if dealt <= 0.0:
		return
	Bus.damage_dealt.emit(dealt, _target)
	Bus.hit_landed.emit(_target, dealt, critical, Status.id_of(status))
	Game.hitstop.punch(dealt, critical, heavy)


func _draw() -> void:
	var fade := clampf(lifetime / maxf(0.001, lifetime_max), 0.0, 1.0)
	var body := Color(color, 0.45 + 0.45 * fade)
	draw_circle(Vector2(0, 5), RADIUS * 0.9, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE + Vector2(0.15, 0.0) * sin(_swing * 20.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -RADIUS), Vector2(RADIUS * 0.9, RADIUS * 0.5),
		Vector2(0, RADIUS), Vector2(-RADIUS * 0.9, RADIUS * 0.5),
	]), body)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(Vector2.ZERO, RADIUS + 4.0, -PI * 0.5, -PI * 0.5 + TAU * fade, 20, Color(color, 0.5), 1.5)
	if _swing > 0.0:
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 20, Color(color, 0.5), 2.0)
