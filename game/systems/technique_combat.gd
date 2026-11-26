class_name TechniqueCombat
extends RefCounted
## Technique kinds: what a technique *does* once its active frame opens.
##
## A technique's frames, Qi cost, cooldown, scaling, mastery and poise are shared
## by every kind, so a spell or a summon costs and times exactly like a sword cut.
## Only the delivery differs:
##
##   melee       — an arc or circle hitbox resolved on the active frame (the old path)
##   projectile  — a body that travels its own reach and strikes what it passes
##   spell       — a delayed area opened at a point ahead of the caster
##   summon      — allies that hunt enemies for a while, each carrying a share
##   buff        — timed mods fed into the one stat pipeline
##   movement    — a step along the aim with its own brief i-frames
##   heal        — restoration for the caster (and party in its radius)
##   transformation — a timed form: buff-strength mods plus a visible tint
##   ward        — a shield pool that drinks damage before the body does
##   passive     — always-on mods while the art is known; never cast
##   cultivation — a meditation factor while the art is known; never cast
##
## Everything here is pure: no nodes, no scene tree, no time. The entities own
## the nodes and the clocks, and ask these functions for the numbers. `kind`
## defaults to `melee`, so every technique written before this milestone — and
## every save that references one — keeps its old behaviour with no migration.

const KINDS: Array[String] = ["melee", "projectile", "spell", "summon", "buff", "movement",
	"heal", "transformation", "ward", "passive", "cultivation"]
const DEFAULT_KIND := "melee"

const PROJECTILE_DEFAULTS := {"speed": 560.0, "radius": 9.0, "range": 440.0, "pierce": 0}
const SPELL_DEFAULTS := {"range": 300.0, "radius": 90.0, "delay": 0.35}
const SUMMON_DEFAULTS := {
	"count": 2, "duration": 8.0, "speed": 140.0, "reach": 34.0,
	"interval": 1.0, "damage_mult": 0.4,
}
const BUFF_DEFAULTS := {"duration": 8.0, "mods": []}
const HEAL_DEFAULTS := {"amount": 10.0, "ticks": 0, "interval": 1.0, "cleanse": false, "radius": 0.0}
const FORM_DEFAULTS := {"duration": 12.0, "mods": [], "tint": "#ffffff"}
const WARD_DEFAULTS := {"shield": 25.0, "duration": 10.0}
const MOVEMENT_DEFAULTS := {"distance": 150.0, "iframes": 0.18}
## Where summons appear around their caller, in world units.
const SUMMON_SPREAD := 30.0


static func is_valid_kind(kind: String) -> bool:
	return KINDS.has(kind)


## The delivery a technique uses. An unknown explicit kind falls back to melee
## so bad data can never remove a technique from the game entirely; `DB.validate`
## reports it instead.
static func kind_of(tech: Dictionary) -> String:
	var kind := String(tech.get("kind", DEFAULT_KIND))
	return kind if KINDS.has(kind) else DEFAULT_KIND


static func kind_label(kind: String) -> String:
	match kind:
		"projectile":
			return "Projectile"
		"spell":
			return "Spell"
		"summon":
			return "Summon"
		"buff":
			return "Buff"
		"movement":
			return "Movement"
		"heal":
			return "Heal"
		"transformation":
			return "Transformation"
		"ward":
			return "Ward"
		"passive":
			return "Passive"
		"cultivation":
			return "Cultivation"
	return "Melee"


## Passive and cultivation arts are always on; they have no cast, no frames
## and no slot behaviour, so the cast path and the skill bar both refuse them.
static func is_castable(kind: String) -> bool:
	return kind != "passive" and kind != "cultivation"


## A kind that strikes something at a distance. Melee is the only delivery that
## resolves inside the same physics frame as its active window.
static func is_ranged(kind: String) -> bool:
	return kind == "projectile" or kind == "spell" or kind == "summon"


## Only a melee technique reads `hitbox`; the others own their own geometry, so
## deleting a stray hitbox from a spell can never change what it hits.
static func uses_hitbox(kind: String) -> bool:
	return kind == "melee"


# --- projectile --------------------------------------------------------------

static func projectile_of(tech: Dictionary) -> Dictionary:
	var spec: Dictionary = (PROJECTILE_DEFAULTS as Dictionary).duplicate(true)
	_merge(spec, tech, "projectile")
	spec["speed"] = maxf(1.0, float(spec.get("speed", 1.0)))
	spec["radius"] = maxf(1.0, float(spec.get("radius", 1.0)))
	spec["range"] = maxf(0.0, float(spec.get("range", 0.0)))
	spec["pierce"] = maxi(0, int(spec.get("pierce", 0)))
	return spec


## Seconds a projectile needs to cross `distance`. Past its range it simply does
## not arrive: a projectile is not a homing effect with infinite reach.
static func flight_time(spec: Dictionary, distance: float) -> float:
	var speed := maxf(1.0, float(spec.get("speed", 1.0)))
	return maxf(0.0, minf(distance, float(spec.get("range", 0.0)))) / speed


static func projectile_reaches(spec: Dictionary, distance: float) -> bool:
	return distance >= 0.0 and distance <= float(spec.get("range", 0.0))


## Bodies one projectile can touch. `pierce` counts the extra bodies after the
## first, so a plain bolt stops at one target.
static func max_hits(spec: Dictionary) -> int:
	return maxi(0, int(spec.get("pierce", 0))) + 1


# --- spell -------------------------------------------------------------------

static func spell_of(tech: Dictionary) -> Dictionary:
	var spec: Dictionary = (SPELL_DEFAULTS as Dictionary).duplicate(true)
	_merge(spec, tech, "spell")
	spec["range"] = maxf(0.0, float(spec.get("range", 0.0)))
	spec["radius"] = maxf(1.0, float(spec.get("radius", 1.0)))
	spec["delay"] = maxf(0.0, float(spec.get("delay", 0.0)))
	return spec


## Where the area opens: straight along the caster's aim at the spell's range.
static func spell_center(origin: Vector2, facing: Vector2, spec: Dictionary) -> Vector2:
	var dir := facing.normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	return origin + dir * float(spec.get("range", 0.0))


static func spell_area(spec: Dictionary) -> Dictionary:
	return {
		"shape": "circle",
		"radius": maxf(1.0, float(spec.get("radius", 1.0))),
		"angle": 360.0,
	}


# --- summon ------------------------------------------------------------------

static func summon_of(tech: Dictionary) -> Dictionary:
	var spec: Dictionary = (SUMMON_DEFAULTS as Dictionary).duplicate(true)
	_merge(spec, tech, "summon")
	spec["count"] = maxi(1, int(spec.get("count", 1)))
	spec["duration"] = maxf(0.1, float(spec.get("duration", 0.1)))
	spec["speed"] = maxf(0.0, float(spec.get("speed", 0.0)))
	spec["reach"] = maxf(1.0, float(spec.get("reach", 1.0)))
	spec["interval"] = maxf(0.05, float(spec.get("interval", 0.05)))
	spec["damage_mult"] = maxf(0.0, float(spec.get("damage_mult", 0.0)))
	return spec


## Each summon carries a share of the technique's blow, so a pack of three does
## not deal three full techniques' worth of damage.
static func summon_damage(amount: float, spec: Dictionary) -> float:
	return maxf(0.0, amount) * maxf(0.0, float(spec.get("damage_mult", 0.0)))


## Where the pack appears, evenly around the caster so they do not stack.
static func summon_offsets(count: int) -> Array:
	var out: Array = []
	var total := maxi(1, count)
	for i in total:
		var angle := TAU * float(i) / float(total)
		out.append(Vector2(cos(angle), sin(angle)) * SUMMON_SPREAD)
	return out


# --- buff --------------------------------------------------------------------

static func buff_of(tech: Dictionary) -> Dictionary:
	var spec: Dictionary = (BUFF_DEFAULTS as Dictionary).duplicate(true)
	_merge(spec, tech, "buff")
	spec["duration"] = maxf(0.1, float(spec.get("duration", 0.1)))
	var mods: Variant = spec.get("mods", [])
	spec["mods"] = (mods as Array).duplicate(true) if typeof(mods) == TYPE_ARRAY else []
	return spec


## A live buff entry, or an empty dictionary when the technique has nothing to
## apply (a buff with no mods is a mistake, not a free action).
static func buff_entry(tech: Dictionary) -> Dictionary:
	if kind_of(tech) != "buff":
		return {}
	var spec := buff_of(tech)
	var mods: Array = spec.get("mods", [])
	if mods.is_empty():
		return {}
	return {
		"id": String(tech.get("id", "")),
		"name": String(tech.get("name", "Art")),
		"duration": float(spec["duration"]),
		"remaining": float(spec["duration"]),
		"mods": mods,
	}


## Recasting the same art refreshes its clock rather than stacking its mods, so
## a buff can never be spammed into a permanent stat.
static func apply_buff(buffs: Array, tech: Dictionary) -> Array:
	var entry := buff_entry(tech)
	if entry.is_empty():
		return buffs.duplicate(true)
	var id := String(entry["id"])
	var out: Array = []
	var replaced := false
	for existing in buffs:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (existing as Dictionary).duplicate(true)
		if String(copy.get("id", "")) == id:
			out.append(entry)
			replaced = true
		else:
			out.append(copy)
	if not replaced:
		out.append(entry)
	return out


static func tick_buffs(buffs: Array, delta: float) -> Array:
	var out: Array = []
	var step := maxf(0.0, delta)
	for existing in buffs:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (existing as Dictionary).duplicate(true)
		copy["remaining"] = float(copy.get("remaining", 0.0)) - step
		if float(copy["remaining"]) > 0.0:
			out.append(copy)
	return out


## Every mod from every live buff, flattened for `StatBlock.rebuild`.
static func buff_mods(buffs: Array) -> Array:
	var out: Array = []
	for existing in buffs:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		for mod in (existing as Dictionary).get("mods", []):
			out.append(mod)
	return out


static func buff_labels(buffs: Array) -> Array:
	var out: Array = []
	for existing in buffs:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		out.append("%s %ds" % [
			String(existing.get("name", "Art")), maxi(1, int(ceil(float(existing.get("remaining", 0.0))))),
		])
	return out


# --- heal --------------------------------------------------------------------

static func heal_of(tech: Dictionary) -> Dictionary:
	var spec: Dictionary = (HEAL_DEFAULTS as Dictionary).duplicate(true)
	_merge(spec, tech, "heal")
	spec["amount"] = maxf(0.0, float(spec.get("amount", 0.0)))
	spec["ticks"] = maxi(0, int(spec.get("ticks", 0)))
	spec["interval"] = maxf(0.1, float(spec.get("interval", 1.0)))
	spec["radius"] = maxf(0.0, float(spec.get("radius", 0.0)))
	return spec


## What one application restores: the art's base plus its attribute scaling,
## grown by mastery — the shape of technique_damage without weapon or the
## physical multiplier, because mending is not a blow.
static func heal_amount(tech: Dictionary, stats: StatBlock, mastery_mult: float = 1.0) -> float:
	var spec := heal_of(tech)
	var scaled := 0.0
	var scaling: Dictionary = tech.get("scaling", {})
	for key in scaling.keys():
		scaled += float(stats.get_attr(String(key))) * float(scaling[key])
	return (float(spec["amount"]) + scaled) * maxf(0.0, mastery_mult)


## A live heal-over-time entry, or empty when the art resolves in one burst.
## The first tick lands at cast time; the entry carries the rest.
static func heal_entry(tech: Dictionary, per_tick: float) -> Dictionary:
	var spec := heal_of(tech)
	var ticks := int(spec["ticks"])
	if ticks <= 1:
		return {}
	return {"id": String(tech.get("id", "")), "name": String(tech.get("name", "Art")),
		"amount": per_tick, "ticks": ticks - 1, "interval": float(spec["interval"]),
		"timer": float(spec["interval"])}


static func tick_heals(entries: Array, delta: float) -> Dictionary:
	var out: Array = []
	var pulses: Array = []
	var step := maxf(0.0, delta)
	for existing in entries:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (existing as Dictionary).duplicate(true)
		copy["timer"] = float(copy.get("timer", 0.0)) - step
		if float(copy["timer"]) <= 0.0 and int(copy.get("ticks", 0)) > 0:
			pulses.append(float(copy.get("amount", 0.0)))
			copy["ticks"] = int(copy["ticks"]) - 1
			copy["timer"] = float(copy.get("timer", 0.0)) + float(copy.get("interval", 1.0))
		if int(copy.get("ticks", 0)) > 0:
			out.append(copy)
	return {"entries": out, "pulses": pulses}


# --- transformation ------------------------------------------------------------

static func form_of(tech: Dictionary) -> Dictionary:
	var spec: Dictionary = (FORM_DEFAULTS as Dictionary).duplicate(true)
	_merge(spec, tech, "transformation")
	spec["duration"] = maxf(0.1, float(spec.get("duration", 0.1)))
	var mods: Variant = spec.get("mods", [])
	spec["mods"] = (mods as Array).duplicate(true) if typeof(mods) == TYPE_ARRAY else []
	return spec


## A form rides the buff pipeline (its mods rebuild stats like any body art)
## and carries its tint alongside, so the body can show what it became.
static func form_entry(tech: Dictionary) -> Dictionary:
	if kind_of(tech) != "transformation":
		return {}
	var spec := form_of(tech)
	var mods: Array = spec.get("mods", [])
	if mods.is_empty():
		return {}
	return {"id": String(tech.get("id", "")), "name": String(tech.get("name", "Art")),
		"duration": float(spec["duration"]), "remaining": float(spec["duration"]),
		"mods": mods, "form": {"tint": String(spec.get("tint", "#ffffff"))}}


## One form at a time: taking a new form ends the old one, and recasting the
## same form refreshes it instead of stacking it.
static func apply_form(buffs: Array, tech: Dictionary) -> Array:
	var entry := form_entry(tech)
	if entry.is_empty():
		return buffs.duplicate(true)
	var out: Array = []
	for existing in buffs:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (existing as Dictionary).duplicate(true)
		if copy.has("form") or String(copy.get("id", "")) == String(entry["id"]):
			continue
		out.append(copy)
	out.append(entry)
	return out


# --- ward ----------------------------------------------------------------------

static func ward_of(tech: Dictionary) -> Dictionary:
	var spec: Dictionary = (WARD_DEFAULTS as Dictionary).duplicate(true)
	_merge(spec, tech, "ward")
	spec["shield"] = maxf(0.0, float(spec.get("shield", 0.0)))
	spec["duration"] = maxf(0.1, float(spec.get("duration", 0.1)))
	return spec


# --- passive & cultivation -----------------------------------------------------

## Mods from every known passive art, flattened for the stat pipeline.
static func passive_mods(techs: Array) -> Array:
	var out: Array = []
	for tech in techs:
		if typeof(tech) != TYPE_DICTIONARY or kind_of(tech) != "passive":
			continue
		var payload: Dictionary = (tech as Dictionary).get("passive", {})
		for mod in payload.get("mods", []):
			out.append(mod)
	return out


## The meditation factor of every known cultivation art, night-aware and
## capped, so stacking arts can never make sitting the only road.
static func cultivation_factor(techs: Array, night: bool) -> float:
	var factor := 1.0
	for tech in techs:
		if typeof(tech) != TYPE_DICTIONARY or kind_of(tech) != "cultivation":
			continue
		var payload: Dictionary = (tech as Dictionary).get("cultivation", {})
		factor *= float(payload.get("meditation_mult", 1.0))
		if night:
			factor *= float(payload.get("night_mult", 1.0))
	return clampf(factor, 1.0, 1.6)


# --- movement ----------------------------------------------------------------

static func movement_of(tech: Dictionary) -> Dictionary:
	var spec: Dictionary = (MOVEMENT_DEFAULTS as Dictionary).duplicate(true)
	_merge(spec, tech, "movement")
	spec["distance"] = maxf(0.0, float(spec.get("distance", 0.0)))
	spec["iframes"] = maxf(0.0, float(spec.get("iframes", 0.0)))
	return spec


## The point a movement art carries the body to. A caster with no facing steps
## right rather than standing still, which keeps the technique's cost meaningful.
static func step_destination(origin: Vector2, facing: Vector2, spec: Dictionary) -> Vector2:
	var dir := facing.normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	return origin + dir * float(spec.get("distance", 0.0))


# --- shared ------------------------------------------------------------------

## Merge a kind's data over its defaults. Only a matching dictionary contributes,
## so a malformed payload leaves the defaults intact and validation reports it.
static func _merge(spec: Dictionary, tech: Dictionary, key: String) -> void:
	var data: Variant = tech.get(key, {})
	if typeof(data) == TYPE_DICTIONARY:
		spec.merge(data as Dictionary, true)
