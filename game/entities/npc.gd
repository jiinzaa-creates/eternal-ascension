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

## The archetype's brain, from `NpcAi.profile`. A reaction is live state and is
## never saved: a threat does not survive a load, so neither does the alarm.
var ai: Dictionary = {}
## `routine`, `confront`, `flee` or `shelter`.
var reaction := "routine"
## Seconds of alarm left. The reaction lasts exactly as long as this does.
var alarm_left := 0.0
var threat_position := Vector2.ZERO
var threat_distance := 0.0

## Party state. A companion is live only: the roster is saved as ids, and the
## body rebuilds its own fight from its generated sheet when it joins.
var in_party := false
var hp := 0.0
var hp_max := 0.0
var party_stats: StatBlock = null
var _party_cooldown := 0.0
var _party_swing := 0.0
var _party_flash := 0.0
var _party_facing := Vector2.DOWN
var _party_target: Node2D = null
## Every blow gets its own evade roll, so a body cannot be permanently unhittable
## because one seeded roll happened to fall under its evasion.
var _party_evade_counter := 0

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


## What this body feels about the player, read through the relationship bands.
## Directional on purpose: it says nothing about how the player feels back.
func bond_to_player() -> Dictionary:
	return Relationships.toward_player(base_disposition, regard())


func bond_label() -> String:
	return String(bond_to_player().get("label", "Stranger"))


## "Friend (+28)" — the dossier's one-line bond.
func bond_line() -> String:
	return Relationships.describe(int(bond_to_player().get("score", 0)))


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
	if ai.is_empty():
		ai = NpcAi.profile({})
	if settlement != null:
		_set_destination("plaza")


func _physics_process(delta: float) -> void:
	# A companion's physics is its own: follow, fight, and nothing about whether
	# the market is alarmed.
	if in_party:
		_party_process(delta)
		return
	_tick_reaction(delta)
	_update_activity()
	_advance_route()
	var goal := goal_position()
	var gap := NpcAi.hold_at(reaction, ai) if reacting() else 0.0
	var to_goal := goal - global_position
	if to_goal.length() > maxf(14.0, gap):
		velocity = to_goal.normalized() * speed
		_wander = Vector2.ZERO
	elif reacting():
		# A body holding a line stands still; it does not pace about a threat.
		velocity = Vector2.ZERO
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


## The archetype's temperament and standing orders, clamped by NpcAi.
func apply_ai(entry: Dictionary) -> void:
	ai = NpcAi.profile(entry)


## Whether an alarm is in force. A reaction whose clock has run out is over, even
## if the fields have not been cleared yet.
func reacting() -> bool:
	return reaction != "routine" and alarm_left > 0.0


## Raises or refreshes a reaction. The clock is always pushed forward while the
## danger lasts, so a sighting keeps the town alarmed instead of lapsing under
## it, but only a *new* order reports true: that is what lets the scene shout
## once instead of every frame.
func react(kind: String, at: Vector2, seconds: float, distance: float) -> bool:
	if kind == "" or kind == "routine":
		return false
	threat_position = at
	threat_distance = maxf(0.0, distance)
	var fresh := kind != reaction or alarm_left <= 0.0
	reaction = kind
	alarm_left = maxf(alarm_left, maxf(0.0, seconds))
	return fresh


## Ends a reaction and walks back into the routine from where the body stands. No
## teleport: a person who ran to the hall walks back out of it.
func stand_down() -> void:
	if reaction == "routine" and alarm_left <= 0.0:
		return
	reaction = "routine"
	alarm_left = 0.0
	threat_position = Vector2.ZERO
	threat_distance = 0.0
	var entry := resolve_schedule(int(Clock.hour))
	if entry.is_empty():
		return
	current_activity = String(entry.get("activity", "idle"))
	_set_destination(String(entry.get("location", "plaza")))


func _tick_reaction(delta: float) -> void:
	if reaction == "routine":
		return
	alarm_left = maxf(0.0, alarm_left - delta)
	if alarm_left <= 0.0:
		stand_down()


## Where the body is actually walking: the reaction's target while alarmed, the
## routine's target otherwise.
func goal_position() -> Vector2:
	if not reacting() or settlement == null:
		return target
	var refuge := settlement.position_for(String(ai.get("refuge", "sect_hall")))
	return NpcAi.target_for(reaction, global_position, threat_position, refuge, ai)


## One line for the dossier while alarmed; empty in an ordinary hour.
func reaction_line() -> String:
	if not reacting():
		return ""
	return NpcAi.describe(reaction, threat_distance)


## What the body says instead of small talk while alarmed.
func warning_line() -> String:
	if not reacting():
		return ""
	return NpcAi.warning_line(reaction)


func nerve_label() -> String:
	return NpcAi.nerve_label(float(ai.get("nerve", 0.5)))


# ----------------------------------------------------------------- party ----


## Joins the player's roster. The build is the person's own: attributes, gear
## and realm go through the one stat pipeline, so a companion's blow is their
## real one rather than a scripted escort number.
func join_party() -> void:
	if in_party:
		return
	in_party = true
	add_to_group("party_member")
	build_party_stats()
	hp = hp_max
	reaction = "routine"
	alarm_left = 0.0
	threat_position = Vector2.ZERO
	threat_distance = 0.0
	_party_facing = Vector2.DOWN
	simulated = true
	set_physics_process(true)
	queue_redraw()


## Leaves the roster and walks back into whatever the schedule says now. No
## teleport: a dismissed companion walks home from where they stand.
func leave_party() -> void:
	if not in_party:
		return
	in_party = false
	remove_from_group("party_member")
	velocity = Vector2.ZERO
	_party_target = null
	_party_cooldown = 0.0
	_party_swing = 0.0
	var entry := resolve_schedule(int(Clock.hour))
	if not entry.is_empty():
		current_activity = String(entry.get("activity", "idle"))
		_set_destination(String(entry.get("location", "plaza")))
	queue_redraw()


## The body's own fight: the generated attributes and worn gear through the one
## stat pipeline. Rebuilt on joining, never saved.
func build_party_stats() -> void:
	party_stats = StatBlock.new(attrs)
	party_stats.rebuild(gear, [], maxi(1, realm), Realms.attr_mult(maxi(1, realm)))
	var armor := party_stats.armor()
	hp_max = maxf(20.0, 40.0 + float(maxi(1, realm)) * 30.0 + float(party_stats.get_attr("str")) * 2.0 + armor * 0.5)


func party_damage() -> float:
	if party_stats == null:
		build_party_stats()
	var weapon := party_stats.weapon_damage()
	var raw := (weapon + 6.0 + float(maxi(1, realm)) * 2.0) * party_stats.physical_mult() * 0.55
	return maxf(3.0, raw)


func party_poise() -> float:
	return 8.0 + float(maxi(1, realm)) * 2.0


func party_penetration() -> float:
	return 0.0 if party_stats == null else party_stats.penetration_fraction()


func party_interval() -> float:
	if party_stats == null:
		return 1.0
	return clampf(1.15 / maxf(0.2, party_stats.attack_speed()), 0.5, 1.6)


## A companion follows the player in formation and fights what is close enough
## to matter. It does not run the town's routine and it does not sleep.
func _party_process(delta: float) -> void:
	if party_stats == null:
		build_party_stats()
	_party_cooldown = maxf(0.0, _party_cooldown - delta)
	_party_swing = maxf(0.0, _party_swing - delta)
	_party_flash = maxf(0.0, _party_flash - delta)
	_party_target = _nearest_foe()
	var speed := maxf(24.0, party_stats.move_speed() * 0.92)
	if _party_target != null:
		var to_target := _party_target.global_position - global_position
		if to_target.length() > Party.STRIKE_REACH:
			velocity = to_target.normalized() * speed
			_party_facing = velocity.normalized()
		else:
			velocity = Vector2.ZERO
			if to_target.length_squared() > 0.0001:
				_party_facing = to_target.normalized()
			if _party_cooldown <= 0.0:
				_party_strike(_party_target)
	else:
		var player_node: Node2D = Game.player as Node2D
		if player_node == null:
			velocity = Vector2.ZERO
		else:
			var facing: Vector2 = player_node.global_position.direction_to(global_position)
			if player_node.has_method("facing_direction"):
				facing = player_node.facing_direction()
			var index := maxi(0, Party.index_of(Game.party_ids, npc_id))
			var goal := player_node.global_position + Party.follow_offset(index, facing)
			var to_goal := goal - global_position
			if to_goal.length() > 20.0:
				velocity = to_goal.normalized() * speed
				_party_facing = velocity.normalized()
			else:
				velocity = Vector2.ZERO
	move_and_slide()
	animator.update(delta, velocity.length() / maxf(1.0, speed), false,
		_party_swing > 0.0, false, false, false, false)
	queue_redraw()


func _nearest_foe() -> Node2D:
	if not is_inside_tree():
		return null
	var best: Node2D = null
	var best_dist := Party.ENGAGE_RANGE
	for value in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(value):
			continue
		var body := value as Dummy
		if body == null or body.state == "dead":
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist < best_dist:
			best_dist = dist
			best = body
	return best


func _party_strike(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	_party_cooldown = party_interval()
	_party_swing = 0.2
	var dir := global_position.direction_to(target.global_position)
	var final := Damage.resolve(party_damage(), 0.0, float(maxi(1, realm)))
	var dealt := float(target.take_hit(final, dir * Party.STRIKE_KNOCK, party_poise(),
		party_penetration(), {}))
	if dealt <= 0.0:
		return
	Bus.damage_dealt.emit(dealt, target)
	Bus.hit_landed.emit(target, dealt, false, "")
	Game.hitstop.punch(dealt, false, dealt >= 20.0)


## Companions take blows through the same rules as everyone else. Only a party
## member can be hit: a resident going about their day is not a target.
func take_hit(amount: float, _from: Vector2 = Vector2.ZERO, can_evade: bool = true,
		_poise_damage: float = 0.0, _knock_force: float = 0.0, _attacker: Node = null,
		_status_payload: Dictionary = {}) -> float:
	if not in_party or hp <= 0.0:
		return 0.0
	if party_stats == null:
		build_party_stats()
	if can_evade:
		_party_evade_counter += 1
		var roll := float(Rng.roll_float("party_evade", hash(npc_id), _party_evade_counter))
		if party_stats.evades(roll):
			return 0.0
	var final := Damage.mitigate_armor(maxf(0.0, amount), party_stats.armor())
	hp = maxf(0.0, hp - final)
	_party_flash = 0.14
	queue_redraw()
	if hp <= 0.0:
		_fall_out()
	return final


## Going down is a consequence, not a death: the companion leaves the roster,
## comes to at a fraction of health and walks back to the routine.
func _fall_out() -> void:
	Game.party_ids.erase(npc_id)
	leave_party()
	hp = maxf(1.0, hp_max * 0.4)
	Bus.toast.emit("%s is down and falls back to the %s." % [
		display_name, current_location.replace("_", " ")])


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
	# Distance ends a reaction: a body that leaves the simulation is not still
	# staring at a threat nobody is rendering.
	reaction = "routine"
	alarm_left = 0.0
	threat_position = Vector2.ZERO
	threat_distance = 0.0
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
	if in_party:
		return velocity.length() > 8.0
	return simulated and settlement != null and global_position.distance_to(goal_position()) > 24.0


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
	# A companion wears a green ring, so a fight reads as "these two are mine".
	if in_party:
		draw_arc(Vector2.ZERO, RADIUS + 5.5, 0.0, TAU, 22, Color("#79d0a0"), 2.0)
		var ratio := clampf(hp / maxf(1.0, hp_max), 0.0, 1.0)
		draw_rect(Rect2(-20.0, -RADIUS - 17.0, 40.0, 3.0), Color("#12201a"))
		draw_rect(Rect2(-20.0, -RADIUS - 17.0, 40.0 * ratio, 3.0), Color("#79d0a0"))
	# A second, wider ring is the alarm: warm for a body holding ground, cold for
	# one leaving. It is drawn outside the routine ring so both stay readable.
	if reacting():
		var reaction_color := Color("#ff9a70") if reaction == "confront" else Color("#a8c8ff")
		draw_arc(Vector2.ZERO, RADIUS + 7.5, -PI * 0.5, -PI * 0.5 + TAU * 0.75, 18, reaction_color, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var player: Node2D = Game.player as Node2D
	if player != null and global_position.distance_to(player.global_position) < 300.0:
		var gait := "  ·  walking" if travelling() else ""
		var alarm := ""
		if reacting():
			alarm = "  ·  " + NpcAi.short_label(reaction)
		var ally := "  ·  with you" if in_party else ""
		var activity := "following" if in_party else current_activity
		var text := "%s  ·  %s%s%s%s" % [display_name, activity, gait, alarm, ally]
		draw_string(ThemeDB.fallback_font, Vector2(-46, -RADIUS - 9.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c8d4da"))
