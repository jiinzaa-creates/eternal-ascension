class_name DebugReport
extends RefCounted
## A bug report produced from a running game.
##
## GDScript cannot read the engine's own stderr, so a report is assembled from what
## the game can see: `Log` (every system writes through it) and a snapshot of the
## live run. `write()` puts one self-contained text file under
## `user://debug-reports/` and keeps `latest.txt` beside it, so a player can hand
## over one file and an assistant can read it without the game running.
##
## `sink_url()` reads `EA_DEBUG_SINK` from the environment: a build can POST a
## report to any endpoint the player chooses without a URL or a key living in the
## repository.

const FORMAT := 1
const DIR := "user://debug-reports"
const LOG_LINES := 200


## A machine-readable picture of the run. Tolerant of a null host so it can be
## checked headlessly without a scene.
static func snapshot(main: Node) -> Dictionary:
	var out := {
		"format": FORMAT,
		"version": String(ProjectSettings.get_setting("application/config/version", "?")),
		"engine": String(Engine.get_version_info().get("string", "?")),
		"platform": OS.get_name(),
		"day": Clock.day,
		"hour": snappedf(Clock.hour, 0.01),
		"weekday": Clock.weekday_name(),
		"world_seed": Game.world_seed,
		"dead": Game.dead,
		"play_time_s": snappedf(Game.play_time, 0.1),
		"kills": Game.kills,
		"karma": Game.karma,
		"notoriety": Game.notoriety,
		"stones": Game.spirit_stones,
		"party": Game.party_ids.size(),
		"captives": Game.captives.size(),
		"discovered": Game.discovered.size(),
		"log": {
			"debug": Log.count(Log.Level.DEBUG),
			"info": Log.count(Log.Level.INFO),
			"warn": Log.count(Log.Level.WARN),
			"error": Log.count(Log.Level.ERROR),
		},
	}
	if main == null:
		return out
	out["phase"] = String(main.get("phase"))
	var npcs: Variant = main.get("npcs")
	if typeof(npcs) == TYPE_ARRAY:
		out["npcs"] = (npcs as Array).size()
	var chunks: Variant = main.get("chunks")
	if chunks != null:
		out["chunks"] = int(chunks.get("streamed_chunks"))
	var player: Variant = main.get("player")
	if player is Node:
		out["player"] = _player_snapshot(player as Node)
	return out


static func _player_snapshot(player: Node) -> Dictionary:
	var cultivation: Variant = player.get("cultivation")
	var out := {
		"name": String(player.get("display_name")),
		"physique": String(player.get("physique_id")),
		"hp": snappedf(float(player.get("hp")), 0.1),
		"hp_max": snappedf(float(player.get("hp_max")), 0.1),
		"position": (player.get("global_position") as Vector2).round(),
		"age_years": snappedf(Game.age_years(), 0.1),
	}
	if cultivation != null:
		out["realm"] = int(cultivation.get("realm"))
		out["sublevel"] = int(cultivation.get("sublevel"))
		out["qi"] = snappedf(float(cultivation.get("qi")), 0.1)
		out["techniques"] = (player.get("technique_ids") as Array).size()
	return out


## The report body: header, a JSON state block, the log tail, and the one thing
## the file cannot contain, so the reader knows to ask for it.
static func text(main: Node, note: String = "") -> String:
	var lines: Array[String] = []
	lines.append("Eternal Ascension — debug report")
	lines.append("format %d · %s · %s" % [
		FORMAT, String(ProjectSettings.get_setting("application/config/version", "?")),
		Time.get_datetime_string_from_system(),
	])
	var trimmed := note.strip_edges()
	if not trimmed.is_empty():
		lines.append("note: %s" % trimmed)
	lines.append("")
	lines.append("--- state (json) ---")
	lines.append(JSON.stringify(snapshot(main), "  ", true))
	lines.append("")
	lines.append("--- log (last %d) ---" % LOG_LINES)
	var recent: Array = Log.recent(LOG_LINES)
	if recent.is_empty():
		lines.append("(empty)")
	for value in recent:
		var entry: Dictionary = value
		lines.append("[%s] %s: %s" % [
			Log.LEVEL_NAMES[clampi(int(entry["level"]), 0, 3)],
			String(entry["category"]),
			String(entry["message"]),
		])
	lines.append("")
	lines.append("--- not in this file ---")
	lines.append("Engine-level failures (SCRIPT ERROR, leaked at exit, failed loads) are written")
	lines.append("to stderr, which GDScript cannot capture. Attach the console output, or a")
	lines.append("`.qa-logs/*.log` from tools/run_suite.sh, alongside this report.")
	return "\n".join(lines)


## Writes the report and returns its path, or "" when the file cannot be opened.
static func write(main: Node, note: String = "") -> String:
	var body := text(main, note)
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/report-%s.txt" % [DIR, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(body)
	file.close()
	# The newest report is also the one to attach when the player does not want to
	# hunt for a timestamp; a copy, not a link, so moving the directory still works.
	var latest := FileAccess.open("%s/latest.txt" % DIR, FileAccess.WRITE)
	if latest != null:
		latest.store_string(body)
		latest.close()
	return path


## The OS path of the report directory, for the panel to show.
static func report_dir() -> String:
	return ProjectSettings.globalize_path(DIR)


## Where a build posts reports, if it was told to. Empty means "write a file".
static func sink_url() -> String:
	return OS.get_environment("EA_DEBUG_SINK").strip_edges()
