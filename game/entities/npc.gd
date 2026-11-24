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
## The weekday routine and, when the calendar says Restday, the routine that
## replaces it. Both come straight from `data/npcs.json`.
var schedule: Array = []
var rest_schedule: Array = []
var settlement: Settlement
var speed := 54.0
## Route through the plaza, so a body walks the paths instead of through walls.
var route: Array = []
var _route_index := 0
## The rest of the record. Generation lives in NpcDb; this node only carries the
## answer, so a sheet can be rebuilt from a seed and compared without the body.
var archetype_id := ""
var attrs := Attributes.new()
var root_id := ""
var physique_id := Physiques.DEFAULT_ID
var technique_ids: Array = []
var gear: Dictionary = {}
var goals: Array = []
var base_disposition := 0

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
var _last_weekday := -1


func setup(id_value: String, name_value: String, role_value: String, sect_value: String,
		realm_value: int, schedule_entries: Array, home: Settlement,
		sheet: Dictionary = {}) -> void:
	npc_id = id_value
	display_name = name_value
	role = role_value
	sect_id = sect_value
	realm = realm_value
	schedule = schedule_entries
	settlement = home
	speed = 48.0 + float(realm) * 4.0
	apply_sheet(sheet)
	add_to_group("npc")


## Copies a generated record onto the body. No rule lives here: NpcDb decided
## the person, and the node only reads what it was handed.
func apply_sheet(sheet: Dictionary) -> void:
	if sheet.is_empty():
		return
	archetype_id = String(sheet.get("archetype_id", archetype_id))
	realm = int(sheet.get("realm", realm))
	attrs.from_dict(sheet.get("attrs", {}))
	root_id = String(sheet.get("root_id", ""))
	root_tier = int(sheet.get("root_tier", root_tier))
	physique_id = String(sheet.get("physique_id", Physiques.DEFAULT_ID))
	var learned: Variant = sheet.get("techniques", [])
	technique_ids = (learned as Array).duplicate() if typeof(learned) == TYPE_ARRAY else []
	var worn: Variant = sheet.get("gear", {})
	gear = (worn as Dictionary).duplicate(true) if typeof(worn) == TYPE_DICTIONARY else {}
	var pursued: Variant = sheet.get("goals", [])
	goals = (pursued as Array).duplicate() if typeof(pursued) == TYPE_ARRAY else []
	base_disposition = int(sheet.get("disposition", 0))


## How the player has shifted this person's opinion, capped by the memory rule.
func regard() -> int:
	return int(NpcDb.memory_entry(Game.npc_memory, npc_id).get("regard", 0))


func standing() -> int:
	return base_disposition + regard()


func standing_label() -> String:
	return NpcDb.standing_label(standing())


func root_name() -> String:
	return String(DB.by_id("root", root_id).get("name", "Unknown Root"))


func physique_name() -> String:
	return Physiques.name_of(physique_id)


func technique_names() -> Array[String]:
	var out: Array[String] = []
	for id in technique_ids:
		out.append(String(DB.technique(String(id)).get("name", String(id))))
	return out


func goal_labels() -> Array[String]:
	var out: Array[String] = []
	for id in goals:
		out.append(NpcDb.goal_label(String(id)))
	return out


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	if settlement != null:
		_set_destination("plaza")


func _physics_process(delta: float) -> void:
	_update_activity()
	_advance_route()
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
	var weekday := Clock.weekday()
	if hour == _last_hour and weekday == _last_weekday:
		return
	_last_hour = hour
	_last_weekday = weekday
	var entry := resolve_schedule(hour)
	if entry.is_empty():
		return
	current_activity = String(entry.get("activity", "idle"))
	_set_destination(String(entry.get("location", "plaza")))


## A weekday routine, replaced whole on a Restday when data names one.
func active_schedule() -> Array:
	if Clock.is_rest_day() and not rest_schedule.is_empty():
		return rest_schedule
	return schedule


## Points the body at a location, routing through the plaza when the path graph
## says the two places are on different spokes.
func _set_destination(location: String) -> void:
	if settlement == null:
		current_location = location
		route = []
		target = Vector2.ZERO
		return
	var origin := current_location
	current_location = location
	route = settlement.route_from(origin, location)
	_route_index = 0
	if route.is_empty():
		route = [location]
	target = settlement.position_for(String(route[0]))


func _advance_route() -> void:
	if settlement == null or _route_index >= route.size() - 1:
		return
	if global_position.distance_to(target) > 14.0:
		return
	_route_index += 1
	target = settlement.position_for(String(route[_route_index]))


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
	route = []
	target = settlement.position_for(current_location)
	global_position = target
	_last_hour = int(Clock.hour)
	_last_weekday = Clock.weekday()


## Returns the schedule entry active now, handling ranges that wrap past
## midnight (21:00 -> 05:00 sleep) and day-filtered entries. The current day's
## routine decides whether the weekday or Restday table is read.
func resolve_schedule(hour: int) -> Dictionary:
	return Schedules.resolve(active_schedule(), hour, Clock.weekday())


func activity_entry() -> Dictionary:
	return resolve_schedule(int(Clock.hour))


## "Meditating at the shrine until 09:00" — the dossier's one-line routine.
func activity_line() -> String:
	var entry := activity_entry()
	if entry.is_empty():
		return "No routine this hour."
	return Schedules.describe(current_activity, current_location, int(entry.get("to", 24)))


func is_awake() -> bool:
	return Schedules.awake(current_activity)


func teaches_here() -> bool:
	return Schedules.can_teach(current_location, current_activity)


## Whether the body still has ground to cover. Sleeping bodies are at their
## destination, so a sleeping NPC never reads as walking.
func travelling() -> bool:
	return simulated and settlement != null and global_position.distance_to(target) > 24.0


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
		var gait := "  ·  walking" if travelling() else ""
		var text := "%s  ·  %s%s" % [display_name, current_activity, gait]
		draw_string(ThemeDB.fallback_font, Vector2(-46, -RADIUS - 9.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c8d4da"))
