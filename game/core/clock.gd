extends Node
## World calendar and day/night cycle.
##
## Default pace: 1 real second = 1 in-game minute, so a full day is 24 real
## minutes. Fast travel advances this clock directly, which is how travel time,
## NPC schedules and event windows stay consistent.

signal hour_changed(day: int, hour: int)
signal day_changed(day: int)

const HOURS_PER_DAY := 24.0
## One week of seven days, independent of the 30-day seasons. Day 1 is a
## Metalday; the last day is the market Restday, when most routines change.
const WEEK_DAYS: Array[String] = ["Metalday", "Woodday", "Waterday", "Fireday", "Earthday", "Lightday", "Restday"]
const REST_WEEKDAY := 6

var day: int = 1
var hour: float = 8.0
## Real seconds -> in-game minutes multiplier.
var time_scale: float = 60.0
var paused: bool = false

var _last_hour: int = 8


func _process(delta: float) -> void:
	if paused:
		return
	advance(delta * time_scale / 60.0)


## Advances the clock by a number of in-game hours.
func advance(hours: float) -> void:
	if hours <= 0.0:
		return
	hour += hours
	while hour >= HOURS_PER_DAY:
		hour -= HOURS_PER_DAY
		day += 1
		day_changed.emit(day)
	var whole := int(hour)
	if whole != _last_hour:
		_last_hour = whole
		hour_changed.emit(day, whole)


func is_night() -> bool:
	return hour < 6.0 or hour >= 19.0


## Weekday index 0–6 for the current day.
func weekday() -> int:
	return weekday_for(day)


func weekday_name() -> String:
	return WEEK_DAYS[weekday()]


## The Restday is the weekly market day: merchants keep a longer stall and the
## rest of the settlement changes its routine rather than repeating it.
func is_rest_day() -> bool:
	return weekday() == REST_WEEKDAY


## Pure weekday lookup, so a schedule can be resolved for any calendar day
## without moving the clock.
static func weekday_for(day_value: int) -> int:
	return posmod(day_value - 1, WEEK_DAYS.size())


## Light tint for the current hour: dawn, day, dusk, night.
func ambient_tint() -> Color:
	return ambient_for_hour(hour)


## Pure form of `ambient_tint`, so lighting can be tested at any hour.
static func ambient_for_hour(value: float) -> Color:
	var h := fposmod(value, 24.0)
	if h >= 6.0 and h < 8.0:
		return Color(1.0, 0.86, 0.72)
	if h >= 8.0 and h < 17.0:
		return Color(1.0, 1.0, 1.0)
	if h >= 17.0 and h < 20.0:
		return Color(1.0, 0.72, 0.62)
	return Color(0.55, 0.63, 0.86)


func label() -> String:
	return "Day %d · %s, %02d:%02d" % [day, weekday_name(), int(hour), int(fmod(hour, 1.0) * 60.0)]


func to_dict() -> Dictionary:
	return {"day": day, "hour": hour}


func from_dict(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	hour = float(data.get("hour", 8.0))
	_last_hour = int(hour)
