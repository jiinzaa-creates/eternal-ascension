extends Node
## Live weather state. Registered as the `Weather` autoload.
##
## `Climate` decides what the weather is; this node only remembers which day and
## block it last resolved, emits `changed` when the sky turns, and runs the
## cosmetic timers (storm flashes) that need a frame clock.
##
## Nothing here is saved: given the saved seed, day and hour, `Climate` will
## produce exactly the same weather again.

signal changed(weather: Dictionary)

var current: Dictionary = {
	"kind": "clear",
	"intensity": 0.0,
	"season": 0,
	"season_name": "Spring",
	"day": 1,
	"block": 0,
}
var elapsed := 0.0

var _day := -1
var _block := -1


func _ready() -> void:
	refresh(true)


func _process(delta: float) -> void:
	elapsed += delta
	refresh()


## Recomputes the weather when the day or the six-hour block changed.
func refresh(force: bool = false) -> void:
	var day := Clock.day
	var block := Climate.block_for_hour(Clock.hour)
	if not force and day == _day and block == _block:
		return
	_day = day
	_block = block
	var previous_kind := String(current.get("kind", ""))
	current = Climate.weather_for(day, Clock.hour)
	if force or String(current["kind"]) != previous_kind:
		changed.emit(current)


func kind() -> String:
	return String(current.get("kind", "clear"))


func season() -> int:
	return int(current.get("season", 0))


func season_name() -> String:
	return String(current.get("season_name", "Spring"))


func intensity() -> float:
	return float(current.get("intensity", 0.0))


## Lightning brightness right now; zero unless the weather is a storm.
func flash_strength() -> float:
	return Climate.flash_strength(kind(), elapsed)


## "Winter · Snow", shown by the HUD.
func label() -> String:
	return "%s · %s" % [season_name(), kind().capitalize()]
