class_name RealmAccess
extends RefCounted
## Discovery and access rules for hidden realms.
##
## The layout belongs to `HiddenRealms`; this owns the world site, its opening
## window and the pure decisions the scene asks for: is it known, is it open,
## what does the portal/map/travel list say. Opening windows are derived from the
## day, so a reload cannot extend an opening or reroll its schedule.

const MIN_RADIUS := 64
const MAX_RADIUS := 2000


static func data() -> Dictionary:
	return DB.realm_access_data


static func sites() -> Array:
	var value: Variant = data().get("sites", [])
	return value if typeof(value) == TYPE_ARRAY else []


static func site(id: String) -> Dictionary:
	for value in sites():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


static func default_id() -> String:
	return String(data().get("default", ""))


static func default_site() -> Dictionary:
	var entry := site(default_id())
	if not entry.is_empty():
		return entry
	var list := sites()
	if list.is_empty() or typeof(list[0]) != TYPE_DICTIONARY:
		return {}
	return list[0]


static func world_position(entry: Dictionary, spawn: Vector2) -> Vector2:
	return spawn + Vector2(float(entry.get("offset_x", 0.0)), float(entry.get("offset_y", 0.0)))


static func reveal_radius(entry: Dictionary) -> float:
	return float(entry.get("radius", 420.0))


## Every family gets its own deterministic layout from the world seed. Only the
## legacy tomb keeps a saved seed, so new families need no extra save key.
static func seed_for(entry: Dictionary, world_seed: int) -> int:
	var stream := Rng.stream_from(world_seed, "realm_site", hash(String(entry.get("id", ""))), 0)
	return 100000 + int(stream.randf() * 900000.0)


## The opening window for a day (1-based). An open window reports how many days
## remain including today; a sealed one reports the next opening day.
static func window_for(entry: Dictionary, day: int) -> Dictionary:
	var cycle := maxi(1, int(entry.get("cycle_days", 12)))
	var open_days := clampi(int(entry.get("open_days", 4)), 1, cycle)
	var offset := posmod(int(entry.get("offset_days", 0)), cycle)
	var phase := posmod(day - 1 - offset, cycle)
	var is_open := phase < open_days
	if is_open:
		var days_left := open_days - phase
		return {
			"open": true,
			"days": days_left,
			"closes_day": day + days_left - 1,
			"opens_day": day - phase,
			"cycle_days": cycle,
		}
	return {
		"open": false,
		"days": cycle - phase,
		"closes_day": -1,
		"opens_day": day + cycle - phase,
		"cycle_days": cycle,
	}


static func status_line(entry: Dictionary, day: int) -> String:
	var window := window_for(entry, day)
	var days := int(window["days"])
	var plural := "day" if days == 1 else "days"
	if bool(window["open"]):
		return "open · %d %s left (closes after day %d)" % [days, plural, int(window["closes_day"])]
	return "sealed · opens on day %d (%d %s)" % [int(window["opens_day"]), days, plural]


static func portal_label(entry: Dictionary, day: int) -> String:
	var base := "Rift — %s" % String(entry.get("name", "hidden realm"))
	if bool(window_for(entry, day)["open"]):
		return base
	return "Sealed %s" % base


static func travel_label(entry: Dictionary, day: int) -> String:
	return "%s (%s)" % [String(entry.get("name", "Hidden realm")), "open" if bool(window_for(entry, day)["open"]) else "sealed"]


static func rumor_line(entry: Dictionary) -> String:
	return String(entry.get("rumor", "A rift is said to open beyond the market."))


static func discovery_line(entry: Dictionary) -> String:
	return String(entry.get("discovery", "A hidden realm reveals itself."))


## The one gate shared by the portal and the tests. `known` comes from the save;
## everything else is derived from content and the day.
static func access(entry: Dictionary, day: int, known: bool) -> Dictionary:
	if entry.is_empty():
		return {"ok": false, "reason": "No hidden realm is charted."}
	if not known:
		return {"ok": false, "reason": "You have not found this realm."}
	var window := window_for(entry, day)
	if not bool(window["open"]):
		return {
			"ok": false,
			"reason": "The rift is sealed; it opens on day %d." % int(window["opens_day"]),
			"opens_day": int(window["opens_day"]),
		}
	return {"ok": true, "reason": "", "closes_day": int(window["closes_day"]), "days": int(window["days"])}


static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no realm access sites defined")
		return problems
	var list_value: Variant = data.get("sites", null)
	if typeof(list_value) != TYPE_ARRAY or (list_value as Array).is_empty():
		problems.append("realm access sites are missing")
		return problems
	var seen: Dictionary = {}
	for value in list_value:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("a realm access site is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if not id.begins_with("realm."):
			problems.append("realm access site without a realm id")
			continue
		if seen.has(id):
			problems.append("duplicate realm access site " + id)
		seen[id] = true
		if String(entry.get("name", "")).strip_edges() == "":
			problems.append("realm access site %s has no name" % id)
		if String(entry.get("rumor", "")).strip_edges() == "":
			problems.append("realm access site %s has no rumor" % id)
		if String(entry.get("discovery", "")).strip_edges() == "":
			problems.append("realm access site %s has no discovery line" % id)
		var template := String(entry.get("template", ""))
		if HiddenRealms.template(template).is_empty():
			problems.append("realm access site %s names unknown template %s" % [id, template])
		var family_id := String(entry.get("family", ""))
		var family := HiddenRealms.family(family_id)
		if family.is_empty():
			problems.append("realm access site %s names unknown family %s" % [id, family_id])
		elif String(family.get("template", "")) != template:
			problems.append("realm access site %s disagrees with its family layout" % id)
		var radius := int(entry.get("radius", 0))
		if radius < MIN_RADIUS or radius > MAX_RADIUS:
			problems.append("realm access site %s has an invalid reveal radius" % id)
		var cycle := int(entry.get("cycle_days", 0))
		if cycle < 2 or cycle > 60:
			problems.append("realm access site %s has an invalid opening cycle" % id)
			continue
		var open_days := int(entry.get("open_days", 0))
		if open_days < 1 or open_days > cycle:
			problems.append("realm access site %s is never open or opens too long" % id)
		var offset := int(entry.get("offset_days", -1))
		if offset < 0 or offset >= cycle:
			problems.append("realm access site %s has an invalid cycle offset" % id)
	var default_value := String(data.get("default", ""))
	if default_value == "" or not seen.has(default_value):
		problems.append("the default realm access site is missing or unknown")
	return problems
