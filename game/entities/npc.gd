class_name Npc
extends CharacterBody2D
## A simulated cultivator with a daily schedule.
##
## Schedules are data (res://data/npcs.json). Each entry maps an in-game hour
## range to a settlement location and an activity. The NPC actually walks there,
## so a town at 06:00 looks different from the same town at 20:00.

const RADIUS := 11.0
const ROLE_COLORS := {
	"Sect Master": "#d8c070",
	"Elder": "#c09ad8",
	"Inner Disciple": "#8fc0e0",
	"Outer Disciple": "#8fa0a8",
	"Merchant": "#d0a070",
	"Guard": "#b07070",
	"Farmer": "#9fb070",
}

var npc_id := ""
var display_name := ""
var role := ""
var sect_id := ""
var realm := 1
var root_tier := 3
var schedule: Array = []
var settlement: Settlement
var speed := 54.0

var current_activity := "idle"
var current_location := ""
var target := Vector2.ZERO
var animator := Animator.new()

## Off-screen simulation. A sleeping NPC costs nothing per frame and snaps to its
## schedule when the player returns: absence is free, but not amnesia.
var simulated := true

var _idle_timer := 0.0
var _wander := Vector2.ZERO
var _last_hour := -1


func setup(id_value: String, name_value: String, role_value: String, sect_value: String,
		realm_value: int, schedule_entries: Array, home: Settlement) -> void:
	npc_id = id_value
	display_name = name_value
	role = role_value
	sect_id = sect_value
	realm = realm_value
	schedule = schedule_entries
	settlement = home
	speed = 48.0 + float(realm) * 4.0
	add_to_group("npc")


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	if settlement != null:
		target = settlement.position_for("plaza")


func _physics_process(delta: float) -> void:
	_update_activity()
	var to_target := target - global_position
	if to_target.length() > 14.0:
		velocity = to_target.normalized() * speed
		_wander = Vector2.ZERO
	else:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_idle_timer = randf_range(1.5, 4.0)
			_wander = Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		velocity = _wander
	move_and_slide()
	animator.update(delta, velocity.length() / maxf(1.0, speed), false, false, false, false, false, false)
	queue_redraw()


func _update_activity() -> void:
	if settlement == null:
		return
	var hour := int(Clock.hour)
	if hour == _last_hour:
		return
	_last_hour = hour
	var entry := resolve_schedule(hour)
	if entry.is_empty():
		return
	var location := String(entry.get("location", "plaza"))
	current_location = location
	current_activity = String(entry.get("activity", "idle"))
	target = settlement.position_for(location)


func sleep() -> void:
	if not simulated:
		return
	simulated = false
	velocity = Vector2.ZERO
	set_physics_process(false)


func wake() -> void:
	if simulated:
		return
	simulated = true
	set_physics_process(true)
	snap_to_schedule()


## Places an NPC where its schedule says it should be right now, the way it would
## have walked there had anyone been watching.
func snap_to_schedule() -> void:
	if settlement == null:
		return
	var entry := resolve_schedule(int(Clock.hour))
	if entry.is_empty():
		return
	current_location = String(entry.get("location", "plaza"))
	current_activity = String(entry.get("activity", "idle"))
	target = settlement.position_for(current_location)
	global_position = target
	_last_hour = int(Clock.hour)


## Returns the schedule entry active at a given hour, handling ranges that wrap
## past midnight (for example 21:00 -> 05:00 sleep).
func resolve_schedule(hour: int) -> Dictionary:
	for entry in schedule:
		var from := float(entry.get("from", 0))
		var to := float(entry.get("to", 24))
		var active := false
		if from <= to:
			active = float(hour) >= from and float(hour) < to
		else:
			active = float(hour) >= from or float(hour) < to
		if active:
			return entry
	return {}


func _draw() -> void:
	var color := Color(ROLE_COLORS.get(role, "#9aa0a6"))
	draw_circle(Vector2(0, 6), RADIUS * 0.9, Color(0, 0, 0, 0.3))
	var pose := Animator.pose(animator.state, animator.time, 0.0)
	draw_set_transform(pose["bob"], float(pose["lean"]), pose["squash"])
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 20, Color("#22282c"), 1.5)

	# Activity marker: a small ring whose colour reads at a glance.
	var activity_color := Color("#6a7a72")
	match current_activity:
		"meditate":
			activity_color = Color("#8fd3c7")
		"train":
			activity_color = Color("#e0a070")
		"shop", "sell":
			activity_color = Color("#d8c070")
		"patrol":
			activity_color = Color("#c07070")
		"sleep":
			activity_color = Color("#5b6d8c")
		"socialize":
			activity_color = Color("#c09ad8")
	draw_arc(Vector2.ZERO, RADIUS + 4.0, -PI * 0.5, -PI * 0.5 + TAU * 0.99, 18, activity_color, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var player: Node2D = Game.player as Node2D
	if player != null and global_position.distance_to(player.global_position) < 300.0:
		var text := "%s  ·  %s" % [display_name, current_activity]
		draw_string(ThemeDB.fallback_font, Vector2(-46, -RADIUS - 9.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c8d4da"))
