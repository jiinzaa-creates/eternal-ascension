class_name SectSeats
extends RefCounted
## Where the twelve sects actually live.
##
## Every sect claims one region of the continent, chosen by the terrain
## affinity in its data: a frost palace looks for mountains, a beast plain
## for open grass. The two capital houses — Azure Cloud above the market and
## the Shadow Veil beneath it — seat in the capital region itself. Claims are
## a pure function of (continent, sect data), so the same world always seats
## the same houses in the same regions and nothing needs saving.
##
## A seat spec mirrors a town spec — centre, jittered location graph,
## buildings, services — plus a resident plan that fills the Directive's
## hierarchy: master, deputy, elders, instructors, guardians, core, inner
## and outer disciples, servants, sized by the sect's population tier.

const SCALES := {"small": 0.8, "standard": 0.95, "great": 1.1}

## role key -> [archetype, role label, realm, counts by tier small/standard/great]
const ROLE_PLANS := {
	"master": ["sect_master", "Sect Master", 7, [1, 1, 1]],
	"deputy": ["elder", "Deputy Sect Master", 6, [1, 1, 1]],
	"elder": ["elder", "Elder", 5, [2, 3, 4]],
	"instructor": ["elder", "Instructor", 4, [1, 1, 2]],
	"guardian": ["guard", "Guardian", 3, [2, 3, 4]],
	"core": ["inner_disciple", "Core Disciple", 3, [2, 3, 4]],
	"inner": ["inner_disciple", "Inner Disciple", 2, [3, 5, 7]],
	"outer": ["outer_disciple", "Outer Disciple", 1, [4, 6, 9]],
	"servant": ["farmer", "Servant", 1, [2, 3, 4]],
}
const TIER_INDEX := {"small": 0, "standard": 1, "great": 2}
const EXTRA_BUILDINGS := {
	"sect.heavenly_sword": ["forge"],
	"sect.golden_cauldron": ["forge"],
	"sect.eternal_medicine": ["fields"],
	"sect.thousand_beast": ["fields"],
}
const CAPITAL_OFFSETS := [Vector2(1500, -1000), Vector2(-1300, 800),
	Vector2(1700, 900), Vector2(-1600, -900)]


## sect id -> region dict for every sect, capital houses included.
static func assignments(continent: Dictionary) -> Dictionary:
	var regions: Array = continent.get("regions", [])
	var capital: Dictionary = {}
	var land: Array = []
	for region in regions:
		if bool((region as Dictionary).get("capital", false)):
			capital = region
		else:
			land.append(region)
	var out: Dictionary = {}
	var claimed: Dictionary = {}
	var capital_ordinal := 0
	for value in Sects.sects():
		var sect: Dictionary = value
		var id := String(sect.get("id", ""))
		var affinity: Array = sect.get("affinity", [])
		if not affinity.is_empty() and String(affinity[0]) == "capital":
			out[id] = capital
			capital_ordinal += 1
			continue
		var best: Dictionary = {}
		var best_rank := 99
		for region in land:
			var index := int((region as Dictionary).get("index", -1))
			if claimed.has(index):
				continue
			var rank := affinity.find(String((region as Dictionary).get("terrain", "")))
			if rank == -1:
				rank = 90
			if rank < best_rank or (rank == best_rank and index < int(best.get("index", 1 << 30))):
				best = region
				best_rank = rank
		if best.is_empty():
			# More sects than land: the latecomer keeps an embassy at the capital.
			out[id] = capital
		else:
			out[id] = best
			claimed[int(best.get("index", -1))] = true
	return out


static func specs(continent: Dictionary, seed_value: int, capital_anchor: Vector2) -> Array:
	var seats := assignments(continent)
	var out: Array = []
	var capital_ordinal := 0
	for value in Sects.sects():
		var sect: Dictionary = value
		var id := String(sect.get("id", ""))
		var region: Dictionary = seats.get(id, {})
		if region.is_empty():
			continue
		out.append(spec_for(sect, region, seed_value, capital_anchor, capital_ordinal))
		if bool(region.get("capital", false)):
			capital_ordinal += 1
	return out


static func spec_for(sect: Dictionary, region: Dictionary, seed_value: int,
		capital_anchor: Vector2, capital_ordinal: int) -> Dictionary:
	var id := String(sect.get("id", ""))
	var index := int(region.get("index", -1))
	var tier := String(sect.get("population", "standard"))
	var scale := float(SCALES.get(tier, 0.95))
	var centre := _anchor(sect, region, seed_value, capital_anchor, capital_ordinal)

	var locations: Dictionary = {}
	var r := Rng.stream_from(seed_value, "sect_seat_locations", index)
	for key in Settlement.LOCATIONS.keys():
		var base: Vector2 = Settlement.LOCATIONS[key]
		var jitter := Vector2(r.randf_range(-26.0, 26.0), r.randf_range(-26.0, 26.0))
		locations[key] = base * scale + (jitter if key != "plaza" else Vector2.ZERO)

	var wanted: Array = ["sect_hall", "dorms"]
	for extra in EXTRA_BUILDINGS.get(id, []):
		wanted.append(String(extra))
	var buildings: Array = []
	for building in Settlement.BUILDINGS:
		if not wanted.has(String(building["location"])):
			continue
		var copy: Dictionary = building.duplicate()
		copy["size"] = (building["size"] as Vector2) * scale
		buildings.append(copy)

	return {
		"sect_id": id,
		"region_index": index,
		"region_name": String(region.get("name", "")),
		"name": String(sect.get("seat", "")),
		"centre": centre,
		"locations": locations,
		"buildings": buildings,
		"residents": residents_for(sect),
	}


## The full resident plan for a sect: leaders named from the data, the rest
## rolled by the scene from the name pools, exactly as towns roll theirs.
static func residents_for(sect: Dictionary) -> Array:
	var id := String(sect.get("id", ""))
	var short := id.trim_prefix("sect.")
	var tier := String(sect.get("population", "standard"))
	var tier_index := int(TIER_INDEX.get(tier, 1))
	var out: Array = []
	for role_key in ROLE_PLANS.keys():
		var plan: Array = ROLE_PLANS[role_key]
		var count := int((plan[3] as Array)[tier_index])
		for i in count:
			var npc_id := "npc.sect.%s.%s" % [short, role_key]
			if count > 1:
				npc_id += ".%d" % i
			var display := ""
			if role_key == "master":
				display = String(sect.get("master", ""))
			elif role_key == "deputy":
				display = String(sect.get("deputy", ""))
			out.append({
				"npc_id": npc_id,
				"name": display,
				"role": String(plan[1]),
				"archetype": String(plan[0]),
				"realm": int(plan[2]),
			})
	return out


static func _anchor(sect: Dictionary, region: Dictionary, seed_value: int,
		capital_anchor: Vector2, capital_ordinal: int) -> Vector2:
	if bool(region.get("capital", false)):
		var base: Vector2 = capital_anchor + CAPITAL_OFFSETS[capital_ordinal % CAPITAL_OFFSETS.size()]
		# Step out of any water the offset lands in, on a fixed ring.
		for step in [Vector2.ZERO, Vector2(420, 0), Vector2(-420, 0), Vector2(0, 420),
				Vector2(0, -420), Vector2(840, 0), Vector2(-840, 0)]:
			var candidate: Vector2 = base + step
			var tile := Vector2i(int(candidate.x / 32.0), int(candidate.y / 32.0))
			if not ChunkGen.ground_water_at_tile(tile, seed_value):
				return candidate
		return base
	var index := int(region.get("index", -1))
	var coord: Vector2i = region["coord"]
	var origin := Continent.chunk_origin(coord)
	var r := Rng.stream_from(seed_value, "sect_seat", index)
	var local := Vector2i(8 + r.randi_range(-2, 2), 3 + r.randi_range(-1, 2))
	var town_centre := Vector2.INF
	var town_spec := Towns.spec_for(region, seed_value)
	if not town_spec.is_empty():
		town_centre = town_spec["centre"]
	var best := Vector2.INF
	var best_score := -1.0
	for step in [Vector2i.ZERO, Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3),
			Vector2i(0, -3), Vector2i(3, 3), Vector2i(-3, -3), Vector2i(2, -3), Vector2i(-2, 3)]:
		var candidate_local := Vector2i(
			clampi(local.x + step.x, 1, Continent.REGION_CHUNKS - 2),
			clampi(local.y + step.y, 1, Continent.REGION_CHUNKS - 2))
		var candidate := Vector2(origin + candidate_local) * Continent.CHUNK_PX + Vector2(512, 512)
		var centre_tile := Vector2i(int(candidate.x / 32.0), int(candidate.y / 32.0))
		if ChunkGen.ground_water_at_tile(centre_tile, seed_value):
			continue
		var score := candidate.distance_to(town_centre) if town_centre != Vector2.INF else 99999.0
		if score > best_score:
			best = candidate
			best_score = score
		if score >= 2600.0:
			return candidate
	if best != Vector2.INF:
		return best
	return Vector2(origin + local) * Continent.CHUNK_PX + Vector2(512, 512)


# ------------------------------------------------------------ mortality ----

## Which office a seat resident holds, from their stable id: leadership
## ids are offices (npc.sect.<short>.master / .deputy / .elder.0).
static func office_of(npc_id: String) -> String:
	if npc_id.ends_with(".master"):
		return "master"
	if npc_id.ends_with(".deputy"):
		return "deputy"
	if npc_id.ends_with(".elder.0"):
		return "elder"
	return ""


## The offices as a fresh spec fills them.
static func default_leadership(spec: Dictionary) -> Dictionary:
	var out := {"master_id": "", "deputy_id": "", "elder_id": "",
		"master_name": "", "deputy_name": ""}
	for entry in spec.get("residents", []):
		var office := office_of(String((entry as Dictionary).get("npc_id", "")))
		if office != "":
			out[office + "_id"] = String((entry as Dictionary).get("npc_id", ""))
	return out


## The office chain in succession order: master, deputy, then every
## elder by seniority.
static func office_chain(spec: Dictionary) -> Array:
	var chain: Array = []
	var elders: Array = []
	for entry in spec.get("residents", []):
		var id := String((entry as Dictionary).get("npc_id", ""))
		if office_of(id) == "master" or office_of(id) == "deputy":
			chain.append(id)
		elif id.contains(".elder."):
			elders.append(id)
	elders.sort()
	return chain + elders


## The offices belong to the living: rebuild them from the spec's chain
## with every recorded death removed, so two deaths on different days
## can never resurrect the first holder. Ids only — names are the
## caller's record.
static func advance_leadership(spec: Dictionary, leadership: Dictionary, deaths: Dictionary) -> Dictionary:
	var out := leadership.duplicate(true)
	var chain: Array = []
	for id in office_chain(spec):
		if not deaths.has(id):
			chain.append(id)
	out["master_id"] = String(chain[0]) if chain.size() > 0 else ""
	out["deputy_id"] = String(chain[1]) if chain.size() > 1 else ""
	out["elder_id"] = String(chain[2]) if chain.size() > 2 else ""
	return out


## The roster as the world presents it today: the dead do not spawn, and
## the current office holders carry their offices' titles and recorded
## names, whoever they were born as.
static func presented_residents(spec: Dictionary, deaths: Dictionary, leadership: Dictionary) -> Array:
	var lead: Dictionary = leadership if not leadership.is_empty() else default_leadership(spec)
	var out: Array = []
	for entry in spec.get("residents", []):
		var e: Dictionary = (entry as Dictionary).duplicate()
		var id := String(e.get("npc_id", ""))
		if deaths.has(id):
			continue
		if id == String(lead.get("master_id", "")):
			e["role"] = "Sect Master"
			if String(lead.get("master_name", "")) != "":
				e["name"] = String(lead["master_name"])
		elif id == String(lead.get("deputy_id", "")):
			e["role"] = "Deputy Sect Master"
			if String(lead.get("deputy_name", "")) != "":
				e["name"] = String(lead["deputy_name"])
		out.append(e)
	return out
