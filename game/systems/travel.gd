class_name Travel
extends RefCounted
## Travel and navigation maths, as pure functions.
##
## Fast travel crosses the province instantly and charges **time**, not spirit
## stones: NPC schedules, weather and regrowth all advance, so a shortcut is never
## free. Nothing here touches the scene; the host moves the player.

const HOURS_PER_THOUSAND := 0.35
const MIN_HOURS := 0.5
const MAX_HOURS := 4.0
const MAX_ROWS := 6
## Arriving this close to a waypoint counts as reaching it.
const ARRIVE_RADIUS := 80.0


static func hours_for(distance: float) -> float:
	return clampf(distance / 1000.0 * HOURS_PER_THOUSAND, MIN_HOURS, MAX_HOURS)


static func can_travel(has_target: bool, in_realm: bool, in_combat: bool) -> bool:
	return has_target and not in_realm and not in_combat


## Radians toward a target from a position. Godot's Y axis points down, so north
## is -PI/2 and east is 0.
static func bearing(from: Vector2, to: Vector2) -> float:
	if from.is_equal_approx(to):
		return 0.0
	return (to - from).angle()


static func distance_label(distance: float) -> String:
	return "%d m" % int(round(distance))


## Landmarks first, then discovered sites sorted by id, capped at `max_rows`.
## Pure so the list can be tested without a scene.
static func destinations(landmarks: Array, sites: Dictionary, max_rows: int = MAX_ROWS) -> Array:
	var out: Array = []
	for landmark in landmarks:
		out.append(landmark)
	var ids: Array = sites.keys()
	ids.sort()
	for id in ids:
		if out.size() >= max_rows:
			break
		var entry: Dictionary = sites[id]
		out.append({
			"id": String(id),
			"name": String(entry.get("name", "Site")),
			"position": Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
		})
	if out.size() > max_rows:
		out = out.slice(0, max_rows)
	return out


static func has_arrived(position: Vector2, waypoint: Vector2) -> bool:
	return waypoint != Vector2.ZERO and position.distance_to(waypoint) <= ARRIVE_RADIUS
