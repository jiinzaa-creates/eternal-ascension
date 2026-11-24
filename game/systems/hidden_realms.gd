class_name HiddenRealms
extends RefCounted
## The content registry for hidden-realm layouts.
##
## A template is a room grid and the rules for filling it: entry and altar
## corners, treasure rooms, loop count, hazard chance, enemy tier/roster and an
## optional warden. `HiddenRealm` owns the node and the drawing; this owns the
## data, corner arithmetic and boot validation, so later families can be added
## as data rather than another hardcoded generator.

const CORNERS := ["northwest", "northeast", "southwest", "southeast"]
const FAMILY_COUNT := 9
const PALETTE_KEYS := ["floor", "entry", "inheritance", "treasure", "border", "hazard", "hazard_edge", "accent"]


static func families() -> Array:
	var value: Variant = DB.hidden_realm_family_data.get("families", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func family(id: String) -> Dictionary:
	for value in families():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


static func default_family_id() -> String:
	return String(DB.hidden_realm_family_data.get("default", ""))


static func default_family() -> Dictionary:
	var entry := family(default_family_id())
	if not entry.is_empty():
		return entry
	var list := families()
	if list.is_empty() or typeof(list[0]) != TYPE_DICTIONARY:
		return {}
	return list[0]


static func family_index(id: String) -> int:
	var list := families()
	for i in list.size():
		if typeof(list[i]) == TYPE_DICTIONARY and String((list[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


static func data() -> Dictionary:
	return DB.hidden_realm_data


static func templates() -> Array:
	var value: Variant = data().get("templates", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func template(id: String) -> Dictionary:
	for value in templates():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


static func default_id() -> String:
	return String(data().get("default", ""))


static func default_template() -> Dictionary:
	var entry := template(default_id())
	if not entry.is_empty():
		return entry
	var list := templates()
	if list.is_empty() or typeof(list[0]) != TYPE_DICTIONARY:
		return {}
	return list[0]


static func index_of(id: String) -> int:
	var list := templates()
	for i in list.size():
		if typeof(list[i]) == TYPE_DICTIONARY and String((list[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


## The cell at a named corner. Unknown corners fall back to the northwest.
static func corner(name: String, cols: int, rows: int) -> Vector2i:
	var east := name.contains("east")
	var south := name.contains("south")
	return Vector2i(maxi(0, cols) - 1 if east else 0, maxi(0, rows) - 1 if south else 0)


static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no hidden realm templates defined")
		return problems
	var list_value: Variant = data.get("templates", null)
	if typeof(list_value) != TYPE_ARRAY or (list_value as Array).is_empty():
		problems.append("hidden realm templates are missing")
		return problems
	var list: Array = list_value
	var seen: Dictionary = {}
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("hidden realm template is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("hidden realm template without id")
			continue
		if seen.has(id):
			problems.append("duplicate hidden realm template " + id)
		seen[id] = true
		if String(entry.get("name", "")).strip_edges() == "":
			problems.append("hidden realm template %s has no name" % id)
		var cols := int(entry.get("cols", 0))
		var rows := int(entry.get("rows", 0))
		if cols < 3 or cols > 8:
			problems.append("hidden realm template %s has an invalid width" % id)
		if rows < 3 or rows > 8:
			problems.append("hidden realm template %s has an invalid height" % id)
		var entry_corner := String(entry.get("entry", ""))
		var altar_corner := String(entry.get("altar", ""))
		if not CORNERS.has(entry_corner):
			problems.append("hidden realm template %s has an unknown entry corner" % id)
		if not CORNERS.has(altar_corner):
			problems.append("hidden realm template %s has an unknown altar corner" % id)
		if entry_corner == altar_corner:
			problems.append("hidden realm template %s starts and ends in the same corner" % id)
		var rooms := maxi(0, cols) * maxi(0, rows)
		var treasures := int(entry.get("treasures", -1))
		if treasures < 1:
			problems.append("hidden realm template %s has no treasure room" % id)
		elif treasures > rooms - 2:
			problems.append("hidden realm template %s wants more treasures than rooms" % id)
		var loops := int(entry.get("loops", -1))
		if loops < 0 or loops > 20:
			problems.append("hidden realm template %s has an invalid loop count" % id)
		var chance := float(entry.get("hazard_chance", -1.0))
		if chance < 0.0 or chance > 1.0:
			problems.append("hidden realm template %s has an invalid hazard chance" % id)
		var ilvl := int(entry.get("enemy_ilvl", 0))
		if ilvl < 1 or ilvl > 12:
			problems.append("hidden realm template %s has an invalid enemy tier" % id)
		var per_room := int(entry.get("enemies_per_room", 0))
		if per_room < 1 or per_room > 6:
			problems.append("hidden realm template %s has an invalid room population" % id)
		var roster_value: Variant = entry.get("enemy_roster", null)
		if typeof(roster_value) != TYPE_ARRAY or (roster_value as Array).is_empty():
			problems.append("hidden realm template %s has no enemy roster" % id)
		else:
			for archetype in (roster_value as Array):
				if DB.enemy_archetype(String(archetype)).is_empty():
					problems.append("hidden realm template %s names unknown enemy %s" % [id, String(archetype)])
		var warden := String(entry.get("warden", ""))
		if warden != "" and DB.boss(warden).is_empty():
			problems.append("hidden realm template %s names unknown warden %s" % [id, warden])
	var default_value := String(data.get("default", ""))
	if default_value == "" or not seen.has(default_value):
		problems.append("hidden realm default template is missing or unknown")
	return problems


static func validate_families(data: Dictionary) -> Array:
	var problems: Array = []
	var list_value: Variant = data.get("families", null)
	if typeof(list_value) != TYPE_ARRAY:
		problems.append("hidden realm families are missing")
		return problems
	var list: Array = list_value
	if list.size() != FAMILY_COUNT:
		problems.append("expected %d hidden realm families, found %d" % [FAMILY_COUNT, list.size()])
	var seen: Dictionary = {}
	var templates: Dictionary = {}
	var inheritances := 0
	for value in list:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("a hidden realm family is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if not id.begins_with("family."):
			problems.append("hidden realm family without a family id")
			continue
		if seen.has(id):
			problems.append("duplicate hidden realm family " + id)
		seen[id] = true
		if String(entry.get("name", "")).strip_edges() == "":
			problems.append("hidden realm family %s has no name" % id)
		if String(entry.get("blurb", "")).strip_edges() == "":
			problems.append("hidden realm family %s has no blurb" % id)
		var layout := String(entry.get("template", ""))
		if template(layout).is_empty():
			problems.append("hidden realm family %s names unknown template %s" % [id, layout])
		elif templates.has(layout):
			problems.append("hidden realm family %s reuses layout %s" % [id, layout])
		templates[layout] = true
		if not DB.loot_table(String(entry.get("loot_table", ""))).is_empty():
			pass
		else:
			problems.append("hidden realm family %s names unknown loot table" % id)
		if bool(entry.get("inheritance", false)):
			inheritances += 1
		var dps := float(entry.get("hazard_dps", -1.0))
		if dps < 0.0 or dps > 50.0:
			problems.append("hidden realm family %s has an invalid hazard" % id)
		if int(entry.get("enemy_ilvl", 0)) < 1 or int(entry.get("enemy_ilvl", 0)) > 12:
			problems.append("hidden realm family %s has an invalid enemy tier" % id)
		if int(entry.get("enemies_per_room", 0)) < 1 or int(entry.get("enemies_per_room", 0)) > 6:
			problems.append("hidden realm family %s has an invalid room population" % id)
		var roster: Variant = entry.get("enemy_roster", null)
		if typeof(roster) != TYPE_ARRAY or (roster as Array).is_empty():
			problems.append("hidden realm family %s has no enemy roster" % id)
		else:
			for archetype in (roster as Array):
				if DB.enemy_archetype(String(archetype)).is_empty():
					problems.append("hidden realm family %s names unknown enemy %s" % [id, String(archetype)])
		var warden := String(entry.get("warden", ""))
		if warden != "" and DB.boss(warden).is_empty():
			problems.append("hidden realm family %s names unknown warden %s" % [id, warden])
		if not Color.html_is_valid(String(entry.get("light_color", ""))):
			problems.append("hidden realm family %s has an invalid light colour" % id)
		var palette_value: Variant = entry.get("palette", null)
		if typeof(palette_value) != TYPE_DICTIONARY:
			problems.append("hidden realm family %s has no palette" % id)
		else:
			for key in PALETTE_KEYS:
				if not Color.html_is_valid(String((palette_value as Dictionary).get(key, ""))):
					problems.append("hidden realm family %s has an invalid %s colour" % [id, key])
	if inheritances != 1:
		problems.append("expected exactly one inheritance family, found %d" % inheritances)
	var default_value := String(data.get("default", ""))
	if default_value == "" or not seen.has(default_value):
		problems.append("the default hidden realm family is missing or unknown")
	return problems
