class_name TribulationArena
extends Node2D
## Runs and draws one Tribulation.
##
## The rules live in the pure Tribulation instance; this node exists only to
## tick them, apply damage to the player and draw the circle. It frees itself
## when the trial resolves and announces the result on the bus, so the scene
## root owns the consequences.

var tribulation: Tribulation = null
var player: Player = null
var _running := false
var _flash := 0.0
var _flash_pos := Vector2.ZERO


func begin(player_node: Player, type_id: String, scale: float, arena_centre: Vector2, seed_value: int) -> void:
	player = player_node
	global_position = arena_centre
	z_index = -10
	tribulation = Tribulation.new()
	tribulation.setup(type_id, scale, arena_centre, Rng.stream("tribulation", seed_value, 0))
	_running = true
	add_to_group("tribulation")
	Bus.tribulation_started.emit(tribulation.type_id)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if not _running or tribulation == null or not is_instance_valid(player):
		queue_redraw()
		return
	var events := tribulation.tick(delta, player.global_position - global_position)
	for bolt in events["struck"]:
		if not bool(bolt["hit"]):
			continue
		_flash = 0.18
		_flash_pos = bolt["pos"]
		# Heaven's bolts ignore armour and evasion; iframes still matter, so a
		# well-timed dash can slip between strikes.
		if player.take_tribulation_damage(float(bolt["damage"]), global_position + (bolt["pos"] as Vector2)):
			tribulation.abort()
	if bool(events["finished"]):
		_finish()
	queue_redraw()


func _finish() -> void:
	if not _running:
		return
	_running = false
	var result := tribulation.result()
	Bus.tribulation_finished.emit(result)
	queue_free()


func _draw() -> void:
	if tribulation == null:
		return
	var color := Color(Tribulation.color_of(tribulation.type_id))
	draw_arc(Vector2.ZERO, Tribulation.ARENA_RADIUS, 0.0, TAU, 64, Color(color, 0.35), 2.0)
	draw_arc(Vector2.ZERO, Tribulation.ARENA_RADIUS - 6.0, 0.0, TAU, 64, Color(color, 0.12), 6.0)
	for strike in tribulation.strikes:
		if bool(strike["resolved"]):
			continue
		var left := float(strike["left"])
		var fill := clampf(1.0 - left / Tribulation.TELEGRAPH, 0.0, 1.0)
		var pos: Vector2 = strike["pos"]
		draw_circle(pos, Tribulation.BOLT_RADIUS, Color(color, 0.1 + 0.18 * fill))
		draw_arc(pos, Tribulation.BOLT_RADIUS, 0.0, TAU, 32, Color(color, 0.55), 2.0)
		draw_arc(pos, Tribulation.BOLT_RADIUS * fill, 0.0, TAU, 24, Color("#ffffff", 0.4), 1.0)
	if _flash > 0.0:
		draw_circle(_flash_pos, Tribulation.BOLT_RADIUS * 1.15, Color("#ffffff", 0.35 * (_flash / 0.18)))
		draw_line(Vector2.ZERO, _flash_pos, Color(color, 0.5), 2.0)
