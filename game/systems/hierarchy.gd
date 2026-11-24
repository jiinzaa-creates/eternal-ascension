class_name Hierarchy
extends RefCounted
## The Azure Cloud's ladder from Servant to Sect Master, plus the specialist
## offices of instructor and guardian.
##
## A rank is not a second reputation: the player's station is derived from the
## same effective Azure Cloud standing M55 already tracks and from their realm.
## That keeps one source of truth — acting for the sect raises its standing, and
## the ladder reads the result — with no rank key in the save. The master's seat
## is held by an NPC until M59 politics opens it; the model already accepts a
## vacant seat, so leadership is a data change, not a rewrite.

const EXPECTED_LADDER := 7
const EXPECTED_OFFICES := 2
const FACTION := "faction.azure_cloud"


# ------------------------------------------------------------------ data ----


static func ladder() -> Array:
	return DB.hierarchy_ladder()


static func offices() -> Array:
	return DB.hierarchy_offices()


static func rank(id: String) -> Dictionary:
	return DB.hierarchy_rank(id)


static func assignments() -> Dictionary:
	return DB.hierarchy_assignments()


static func seat_available() -> bool:
	return not bool(DB.hierarchy_data.get("seat_held", true))


static func title(id: String) -> String:
	return String(rank(id).get("name", ""))


static func authority(id: String) -> int:
	return clampi(int(rank(id).get("authority", 0)), 0, 100)


## The rung's numeric level; −1 for an office or an unknown id.
static func level(id: String) -> int:
	return int(rank(id).get("level", -1))


static func duty(id: String) -> String:
	return String(rank(id).get("duty", ""))


static func privilege(id: String) -> String:
	return String(rank(id).get("privilege", ""))


static func requires(id: String) -> Dictionary:
	var value: Variant = rank(id).get("requires", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


# ------------------------------------------------------------- membership ----


## Which seat a resident holds: an authored person first, then the archetype's
## template. Unaligned trades hold no seat.
static func for_archetype(archetype_id: String) -> String:
	if archetype_id == "":
		return ""
	var table: Dictionary = _table(assignments().get("archetypes", {}))
	var id := String(table.get(archetype_id, ""))
	return id if not rank(id).is_empty() else ""


static func for_npc(npc_id: String, archetype_id: String) -> String:
	var people: Dictionary = _table(assignments().get("people", {}))
	if people.has(npc_id):
		var authored := String(people[npc_id])
		if not rank(authored).is_empty():
			return authored
	return for_archetype(archetype_id)


## "Station: Elder · authority 65" — the dossier's one line. Empty for a body
## that holds no seat in the sect.
static func station_line(npc_id: String, archetype_id: String) -> String:
	var id := for_npc(npc_id, archetype_id)
	if id == "":
		return ""
	return "Station: %s · authority %d" % [title(id), authority(id)]


# ------------------------------------------------------------ player rank ----


## The highest rung the player currently holds. Effective standing is used, so
## notoriety costs a place in the hall just as it costs a welcome at the gate.
static func player_rank(realm: int, standing: Dictionary, notoriety: int = 0,
		seat_open: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var effective := Factions.effective_standing(FACTION, standing, notoriety)
	var level := maxi(1, realm)
	for value in ladder():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if bool(entry.get("seat", false)) and not seat_open:
			continue
		var need: Dictionary = entry.get("requires", {})
		if effective >= int(need.get("standing", -100)) and level >= int(need.get("realm", 1)):
			best = entry
	if best.is_empty():
		return rank("rank.servant")
	return best


## The next rung above the one held, occupied seat or not. Structural: whether
## the player can take it is `missing_for`'s answer.
static func next_rank(current_id: String) -> Dictionary:
	var current := rank(current_id)
	if current.is_empty():
		return {}
	var next_level := int(current.get("level", 0)) + 1
	for value in ladder():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		if int((value as Dictionary).get("level", -1)) == next_level:
			return value
	return {}


## Everything still between the player and a rung, in words the screen can show.
static func missing_for(rank_id: String, realm: int, standing: Dictionary, notoriety: int = 0,
		seat_open: bool = false) -> Array:
	var entry := rank(rank_id)
	if entry.is_empty():
		return ["an unknown rank"]
	var reasons: Array = []
	var effective := Factions.effective_standing(FACTION, standing, notoriety)
	var need: Dictionary = entry.get("requires", {})
	var need_standing := int(need.get("standing", -100))
	if effective < need_standing:
		reasons.append("%d standing (have %d)" % [need_standing, effective])
	var need_realm := int(need.get("realm", 1))
	if maxi(1, realm) < need_realm:
		reasons.append("realm %d (have %d)" % [need_realm, maxi(1, realm)])
	if bool(entry.get("seat", false)) and not seat_open:
		reasons.append("the master's seat is held")
	return reasons


## "Station: Outer Disciple · authority 15 · Inner Disciple needs 20 standing (have 0), realm 2 (have 1)"
static func station_progress(realm: int, standing: Dictionary, notoriety: int = 0,
		seat_open: bool = false) -> String:
	var current := player_rank(realm, standing, notoriety, seat_open)
	if current.is_empty():
		return ""
	var line := "Station: %s · authority %d" % [String(current.get("name", "")), authority(String(current.get("id", "")))]
	var next := next_rank(String(current.get("id", "")))
	if next.is_empty():
		return line + " · the ladder ends at the seat."
	var missing := missing_for(String(next.get("id", "")), realm, standing, notoriety, seat_open)
	if missing.is_empty():
		return line + " · %s is ready." % String(next.get("name", ""))
	return line + " · %s needs %s" % [String(next.get("name", "")), ", ".join(missing)]


## A shorter line for the vitals panel: current station and the first unmet rung.
static func hud_line(realm: int, standing: Dictionary, notoriety: int = 0,
		seat_open: bool = false) -> String:
	var current := player_rank(realm, standing, notoriety, seat_open)
	if current.is_empty():
		return ""
	var line := "Station: %s" % String(current.get("name", ""))
	var next := next_rank(String(current.get("id", "")))
	if next.is_empty():
		return line
	var missing := missing_for(String(next.get("id", "")), realm, standing, notoriety, seat_open)
	if missing.is_empty():
		return line + " · %s ready" % String(next.get("name", ""))
	return line + " · %s: %s" % [String(next.get("name", "")), String(missing[0])]


# ------------------------------------------------------------- validation ----


static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no hierarchy data defined")
		return problems
	if typeof(data.get("seat_held", true)) != TYPE_BOOL:
		problems.append("hierarchy seat_held must be a boolean")

	var ladder_list: Variant = data.get("ladder", null)
	if typeof(ladder_list) != TYPE_ARRAY:
		problems.append("hierarchy ladder is not an array")
		ladder_list = []
	var ladder_rows: Array = ladder_list
	if ladder_rows.size() != EXPECTED_LADDER:
		problems.append("expected %d ranks, found %d" % [EXPECTED_LADDER, ladder_rows.size()])

	var seen: Dictionary = {}
	var levels: Dictionary = {}
	var seats := 0
	var last_authority := -1
	for value in ladder_rows:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("rank is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("rank without id")
			continue
		if seen.has(id):
			problems.append("duplicate rank id " + id)
		seen[id] = true
		if String(entry.get("name", "")).strip_edges() == "":
			problems.append("rank %s has no name" % id)
		if String(entry.get("duty", "")).strip_edges() == "" or String(entry.get("privilege", "")).strip_edges() == "":
			problems.append("rank %s has no duty or privilege" % id)
		var level := int(entry.get("level", -1))
		if level < 0 or level >= EXPECTED_LADDER:
			problems.append("rank %s has an out-of-range level" % id)
		elif levels.has(level):
			problems.append("two ranks share level %d" % level)
		levels[level] = true
		var power := int(entry.get("authority", -1))
		if power < 0 or power > 100:
			problems.append("rank %s has an out-of-range authority" % id)
		if power < last_authority:
			problems.append("rank %s is below the authority of the rung beneath it" % id)
		last_authority = maxi(last_authority, power)
		var need: Variant = entry.get("requires", null)
		if typeof(need) != TYPE_DICTIONARY:
			problems.append("rank %s has no requirements" % id)
		else:
			var standing := int((need as Dictionary).get("standing", -101))
			if standing < -100 or standing > 100:
				problems.append("rank %s requires an out-of-range standing" % id)
			var realm := int((need as Dictionary).get("realm", 0))
			if realm < 1 or realm > 12:
				problems.append("rank %s requires an out-of-range realm" % id)
		if bool(entry.get("seat", false)):
			seats += 1
			if level != EXPECTED_LADDER - 1:
				problems.append("the seated rank is not the top of the ladder")
	if seats != 1:
		problems.append("expected exactly one seated rank, found %d" % seats)
	if levels.size() != EXPECTED_LADDER:
		problems.append("the ladder does not cover every level")

	var office_list: Variant = data.get("offices", null)
	if typeof(office_list) != TYPE_ARRAY:
		problems.append("hierarchy offices are not an array")
		office_list = []
	var office_rows: Array = office_list
	if office_rows.size() != EXPECTED_OFFICES:
		problems.append("expected %d offices, found %d" % [EXPECTED_OFFICES, office_rows.size()])
	for value in office_rows:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("office is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("office without id")
			continue
		if seen.has(id):
			problems.append("duplicate rank or office id " + id)
		seen[id] = true
		if String(entry.get("name", "")).strip_edges() == "":
			problems.append("office %s has no name" % id)
		if String(entry.get("duty", "")).strip_edges() == "" or String(entry.get("privilege", "")).strip_edges() == "":
			problems.append("office %s has no duty or privilege" % id)
		var power := int(entry.get("authority", -1))
		if power < 0 or power > 100:
			problems.append("office %s has an out-of-range authority" % id)

	var assignment_value: Variant = data.get("assignments", null)
	if typeof(assignment_value) != TYPE_DICTIONARY:
		problems.append("hierarchy assignments are missing")
	else:
		var table: Dictionary = assignment_value
		var archetypes: Dictionary = _table(table.get("archetypes", {}))
		var known_archetypes: Dictionary = {}
		for value in DB.archetypes():
			if typeof(value) == TYPE_DICTIONARY:
				known_archetypes[String((value as Dictionary).get("id", ""))] = true
		for key in archetypes.keys():
			if not known_archetypes.has(String(key)):
				problems.append("hierarchy assigns unknown archetype %s" % String(key))
			if not seen.has(String(archetypes[key])):
				problems.append("hierarchy assigns %s to unknown rank %s" % [String(key), String(archetypes[key])])
		var people: Dictionary = _table(table.get("people", {}))
		for key in people.keys():
			if String(key).strip_edges() == "":
				problems.append("hierarchy assigns a nameless resident")
			if not seen.has(String(people[key])):
				problems.append("hierarchy assigns %s to unknown rank %s" % [String(key), String(people[key])])

	return problems


static func _table(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
