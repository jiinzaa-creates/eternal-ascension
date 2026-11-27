class_name Daos
extends RefCounted
## The Dao paths (Roadmap M28): comprehension, walked far enough in one
## direction, becomes a road with stages. Insight points accrue per path
## from the channels that feed it (see route()); each stage's mods join
## the one stat pipeline beside enlightenments. A path is content plus
## mods, never code — the same discipline as physiques.

## Points at which stages 1..4 are reached.
const STAGE_POINTS: Array[float] = [60.0, 180.0, 420.0, 900.0]
const STAGE_NAMES: Array[String] = ["Glimpsed", "Walked", "Deepened", "Embodied"]

## Which road each method walks when no focus is chosen.
const METHOD_ROADS := {
	"method.traditional": "dao.weapon",
	"method.body": "dao.body",
	"method.sword": "dao.sword",
	"method.blood": "dao.body",
	"method.slaughter": "dao.blade",
	"method.dual": "dao.elemental",
	"method.heavenly": "dao.time",
	"method.beast": "dao.beast",
	"method.alchemy": "dao.alchemy",
	"method.elemental": "dao.elemental",
	"method.formation": "dao.formation",
	"method.forbidden": "dao.space",
}

## Biomes whose phenomena teach the Elemental road to a meditator.
const PHENOMENON_BIOMES: Array[String] = ["biome.volcanic", "biome.ashen", "biome.frost", "biome.snow", "biome.desert"]


static func all() -> Array:
	return DB.daos


static func find(id: String) -> Dictionary:
	return DB.dao(id)


static func name_of(id: String) -> String:
	return String(find(id).get("name", "Unwalked road"))


## Stages reached at a point total: 0 (unwalked) .. 4 (Embodied).
static func stage_for(points: float) -> int:
	var stage := 0
	for threshold in STAGE_POINTS:
		if points >= threshold:
			stage += 1
	return stage


static func stage_name(stage: int) -> String:
	if stage <= 0 or stage > STAGE_NAMES.size():
		return ""
	return STAGE_NAMES[stage - 1]


## Points still needed for the next stage; -1 when the road is embodied.
static func points_to_next(points: float) -> float:
	for threshold in STAGE_POINTS:
		if points < threshold:
			return threshold - points
	return -1.0


static func stage_map(progress: Dictionary) -> Dictionary:
	var out := {}
	for id in progress:
		out[id] = stage_for(float(progress[id]))
	return out


## Every walked path's stage mods, summed for the stat pipeline.
static func mods(progress: Dictionary) -> Array:
	var out: Array = []
	for entry in all():
		var id := String(entry.get("id", ""))
		var stage := stage_for(float(progress.get(id, 0.0)))
		if stage <= 0:
			continue
		var stages: Array = entry.get("stages", [])
		for i in mini(stage, stages.size()):
			out.append_array((stages[i] as Dictionary).get("mods", []))
	return out


## Where a comprehension gain walks. Channels: "meditation", "combat",
## "practice", "event", "teachers", "manuals", "observation". The state
## carries focus, method_id, weapon_school and biome from the caller.
static func route(channel: String, state: Dictionary) -> String:
	match channel:
		"combat":
			var school := String(state.get("weapon_school", ""))
			if school == "sword":
				return "dao.sword"
			if school == "saber" or school == "blade":
				return "dao.blade"
			return "dao.weapon"
		"practice":
			return "dao.space"
		"event":
			return "dao.time"
		"observation":
			return "dao.elemental"
		"meditation":
			var focus := String(state.get("focus", ""))
			if focus != "" and not find(focus).is_empty():
				return focus
			if PHENOMENON_BIOMES.has(String(state.get("biome", ""))):
				return "dao.elemental"
			return String(METHOD_ROADS.get(String(state.get("method_id", "")), "dao.weapon"))
		_:
			# Teachers and manuals deepen the road the method already walks.
			return String(METHOD_ROADS.get(String(state.get("method_id", "")), "dao.weapon"))
