extends Node
## Structured logging.
##
## Two jobs:
##   1. Console verbosity by level, so a normal run is not drowned in noise but a
##      debugging session can see everything.
##   2. An in-memory ring buffer that ALWAYS records, so a bug report can be
##      produced from a running game with `Log.dump()` without a debugger.
##
## Systems never call print/push_error directly. That is what makes filtering,
## prefixing and later log-to-file possible without touching call sites.

enum Level { DEBUG, INFO, WARN, ERROR }

const LEVEL_NAMES: Array[String] = ["DEBUG", "INFO", "WARN", "ERROR"]
const MAX_ENTRIES := 500

var console_level: int = Level.INFO
var silent: bool = false
var entries: Array = []


func debug(category: String, message: String) -> void:
	_record(Level.DEBUG, category, message)


func info(category: String, message: String) -> void:
	_record(Level.INFO, category, message)


func warn(category: String, message: String) -> void:
	_record(Level.WARN, category, message)


func error(category: String, message: String) -> void:
	_record(Level.ERROR, category, message)


func _record(level: int, category: String, message: String) -> void:
	entries.append({
		"level": level,
		"category": category,
		"message": message,
		"t_ms": Time.get_ticks_msec(),
	})
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()

	if silent or level < console_level:
		return
	var line := "[%s] %s: %s" % [LEVEL_NAMES[clampi(level, 0, 3)], category, message]
	match level:
		Level.ERROR:
			push_error(line)
		Level.WARN:
			push_warning(line)
		_:
			print(line)


func set_console_level(level: int) -> void:
	console_level = clampi(level, Level.DEBUG, Level.ERROR)


## Number of recorded entries at a level (or above it when `at_least` is true).
func count(level: int = -1, at_least: bool = false) -> int:
	if level < 0:
		return entries.size()
	var total := 0
	for entry in entries:
		var entry_level := int(entry["level"])
		var matches := false
		if at_least:
			matches = entry_level >= level
		else:
			matches = entry_level == level
		if matches:
			total += 1
	return total


func count_for(level: int, category: String) -> int:
	var total := 0
	for entry in entries:
		if int(entry["level"]) == level and String(entry["category"]) == category:
			total += 1
	return total


func recent(n: int = 20) -> Array:
	if n <= 0:
		return []
	return entries.slice(maxi(0, entries.size() - n))


func dump() -> String:
	var lines: Array[String] = []
	for entry in entries:
		lines.append("[%s] %s: %s" % [
			LEVEL_NAMES[clampi(int(entry["level"]), 0, 3)],
			String(entry["category"]),
			String(entry["message"]),
		])
	return "\n".join(lines)


func clear() -> void:
	entries.clear()
