extends Node
## Save storage.
##
## Reliability rules, in order of importance:
##   1. Atomic write  (temp file -> checksum -> rename), so a crash cannot leave
##      a half-written save in place of a good one.
##   2. Verification  (sha256 of the body) before a file is trusted.
##   3. Rotation      (3 backups), with automatic fallback when the newest save
##      is missing or corrupt.
##   4. Versioning    (schema number + migration chain), so old saves keep loading.

const SAVE_DIR := "user://saves/"
## Schema 2 introduced canonical item records: stacks carry a count and weapons
## and armour carry durability. Older saves are normalised on load.
const CURRENT_SCHEMA := 2
const BACKUP_COUNT := 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func path_for(slot: int) -> String:
	return SAVE_DIR + "slot_%d.sav" % slot


func backup_path(slot: int, index: int) -> String:
	return path_for(slot) + ".bak%d" % index


func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(path_for(slot))


func save_game(slot: int, data: Dictionary) -> bool:
	data["schema"] = CURRENT_SCHEMA
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var body := JSON.stringify(data, "\t")
	var payload := {"checksum": body.sha256_text(), "body": body}

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var tmp := path_for(slot) + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		Log.error("save", "cannot open temp file: %s" % tmp)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	_rotate(slot)

	var err := DirAccess.rename_absolute(tmp, path_for(slot))
	if err != OK:
		Log.error("save", "rename failed (%d) for %s" % [err, path_for(slot)])
		return false

	Log.info("save", "wrote slot %d (%d bytes)" % [slot, body.length()])
	Bus.game_saved.emit(slot)
	return true


func _rotate(slot: int) -> void:
	# Drop the oldest backup, then shift the chain up by one.
	if FileAccess.file_exists(backup_path(slot, BACKUP_COUNT)):
		DirAccess.remove_absolute(backup_path(slot, BACKUP_COUNT))
	for i in range(BACKUP_COUNT - 1, 0, -1):
		var src := backup_path(slot, i)
		if FileAccess.file_exists(src):
			DirAccess.rename_absolute(src, backup_path(slot, i + 1))
	if FileAccess.file_exists(path_for(slot)):
		DirAccess.rename_absolute(path_for(slot), backup_path(slot, 1))


## Loads a slot, falling back through backups when the newest file is unreadable.
## Returns {} when nothing usable exists.
func load_game(slot: int = 1) -> Dictionary:
	var candidates: Array[String] = [path_for(slot)]
	for i in range(1, BACKUP_COUNT + 1):
		candidates.append(backup_path(slot, i))

	for path in candidates:
		var data := _read_verified(path)
		if data.is_empty():
			continue
		var schema := int(data.get("schema", 0))
		if schema > CURRENT_SCHEMA:
			Log.warn("save", "%s was written by a newer build (schema %d)" % [path, schema])
			continue
		if schema < CURRENT_SCHEMA:
			Log.info("save", "migrating slot %d from schema %d" % [slot, schema])
			data = _migrate(data, schema)
		if path != path_for(slot):
			Log.warn("save", "recovered slot %d from backup %s" % [slot, path])
		Bus.game_loaded.emit(slot)
		return data

	Log.warn("save", "no usable save in slot %d" % slot)
	return {}


func _read_verified(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return {}
	var payload: Variant = JSON.parse_string(text)
	if typeof(payload) != TYPE_DICTIONARY:
		Log.warn("save", "unparseable file: %s" % path)
		return {}
	if String(payload.get("body", "")).sha256_text() != String(payload.get("checksum", "")):
		Log.warn("save", "checksum mismatch: %s" % path)
		return {}
	var data: Variant = JSON.parse_string(String(payload.get("body", "")))
	if typeof(data) != TYPE_DICTIONARY:
		Log.warn("save", "corrupt body: %s" % path)
		return {}
	return data


## Migration chain. Each step upgrades one schema version.
## Never delete a step: old saves in the wild depend on the whole chain.
func _migrate(data: Dictionary, from_schema: int) -> Dictionary:
	var version := from_schema
	if version < 1:
		version = 1
	if version < 2:
		# Items written before schema 2 have neither a count nor durability.
		# Normalising them here means the player loader only ever sees the
		# current shape, whichever release wrote the file.
		var player_value: Variant = data.get("player", {})
		if typeof(player_value) == TYPE_DICTIONARY:
			var player_data: Dictionary = player_value
			player_data["inventory"] = Items.normalize_inventory(player_data.get("inventory", []))
			player_data["equipment"] = Items.normalize_equipment(player_data.get("equipment", {}))
		version = 2
	data["schema"] = CURRENT_SCHEMA
	data["migrated_from"] = from_schema
	return data


func list_slots() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.begins_with("slot_") and file.ends_with(".sav"):
			var slot := int(file.trim_prefix("slot_").trim_suffix(".sav"))
			out.append(slot)
	out.sort()
	return out


func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(path_for(slot)):
		DirAccess.remove_absolute(path_for(slot))
	for i in range(1, BACKUP_COUNT + 1):
		if FileAccess.file_exists(backup_path(slot, i)):
			DirAccess.remove_absolute(backup_path(slot, i))
