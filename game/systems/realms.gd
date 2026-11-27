class_name Realms
extends RefCounted
## Realm and sublevel rules: the ladder itself, what each rung unlocks, and the
## realm art that comes with it.
##
## Two layers on purpose, exactly as the design says:
##   * sublevels are incremental — every one raises Qi capacity (`sublevel_factor`),
##   * realms are qualitative — a multiplier plus declared unlocks.
##
## Unlocks are cumulative: a Nascent Soul keeps Foundation's dash cancel. Realm
## arts are not cumulative: the current realm's art is the one that applies, so
## twelve sets of mods never stack into nonsense.
##
## Flags that a system reads today: `dash_cancel` (Player), `technique_weaving`
## (Player), `elemental_conversion` (Damage/Player), `spirit_scan` (scene/HUD),
## `flight` (Player/scene), `space_folding` (travel), `physique_awakening`
## (Player, via the physique stages), `domain_projection` (Player),
## `immortal_body` (Player aging), `plane_manipulation` (travel) and
## `dao_comprehension` (Player). Two remain declared-only by design:
## `ascension_attempt` belongs to the endgame's Blank Page (M70), and
## hidden-realm creation is a content system of its own.

const SUBLEVELS := 10
const EARLY_MAX := 3
const MIDDLE_MAX := 6
const LATE_MAX := 9
## Qi capacity of sublevel ten relative to sublevel one: 1 + 0.35 * 9.
const SUBLEVEL_STEP := 0.35
## Technique weaving: Spirit Transformation trims cost and cooldown.
const WEAVING_MULT := 0.9


static func count() -> int:
	return DB.realms.size()


static func is_valid(number: int) -> bool:
	return number >= 1 and number <= count()


## The realm's data entry, or {} outside the ladder.
static func find(number: int) -> Dictionary:
	if not is_valid(number):
		return {}
	return DB.realm(number)


static func name_of(number: int) -> String:
	return String(find(number).get("name", "Unknown"))


static func sublevels(number: int) -> int:
	return maxi(1, int(find(number).get("sublevels", SUBLEVELS)))


## Years the realm allows before any longevity bonus. 0 means unbounded.
static func lifespan(number: int) -> int:
	if not is_valid(number):
		return 0
	return maxi(0, int(find(number).get("lifespan", 0)))


static func qi_mult(number: int) -> float:
	return maxf(0.0, float(find(number).get("qi_mult", 1.0)))


static func attr_mult(number: int) -> float:
	return maxf(0.0, float(find(number).get("attr_mult", 1.0)))


static func color(number: int) -> String:
	return String(find(number).get("color", "#ffffff"))


# --- sublevels ---------------------------------------------------------------

## Early 1–3, Middle 4–6, Late 7–9, Peak 10. Out-of-range values clamp, so a
## corrupted save still has a readable stage instead of an empty band.
static func sublevel_label(sublevel: int) -> String:
	var s := clampi(sublevel, 1, SUBLEVELS)
	if s <= EARLY_MAX:
		return "Early"
	if s <= MIDDLE_MAX:
		return "Middle"
	if s <= LATE_MAX:
		return "Late"
	return "Peak"


## Qi capacity growth inside one realm. Every realm shares the same curve, so a
## realm is a multiplier rather than a different rule.
static func sublevel_factor(sublevel: int) -> float:
	return 1.0 + SUBLEVEL_STEP * float(clampi(sublevel, 1, SUBLEVELS) - 1)


static func stage_label(number: int, sublevel: int) -> String:
	return "%s %d" % [name_of(number), clampi(sublevel, 1, SUBLEVELS)]


static func stage_title(number: int, sublevel: int) -> String:
	return "%s %d · %s" % [name_of(number), clampi(sublevel, 1, SUBLEVELS), sublevel_label(sublevel)]


## Rough power of one stage: capacity multiplier times attribute multiplier.
## Used for display and for tests that sublevels and realms both matter.
static func stage_power(number: int, sublevel: int) -> float:
	return qi_mult(number) * attr_mult(number) * sublevel_factor(sublevel)


# --- unlocks -----------------------------------------------------------------

## Unlocks introduced by this realm, as {id, name} dictionaries.
static func unlocks_at(number: int) -> Array:
	var out: Array = []
	for entry in find(number).get("unlocks", []):
		if typeof(entry) == TYPE_DICTIONARY:
			var id := String(entry.get("id", ""))
			if id != "":
				out.append({"id": id, "name": String(entry.get("name", id))})
		elif typeof(entry) == TYPE_STRING:
			var text := String(entry)
			if text != "":
				out.append({"id": text, "name": text})
	return out


## Everything a character of this realm has unlocked, oldest first.
static func cumulative_unlocks(number: int) -> Array:
	var out: Array = []
	for n in range(1, clampi(number, 0, count()) + 1):
		out.append_array(unlocks_at(n))
	return out


static func unlock_ids(number: int) -> Array:
	var out: Array = []
	for entry in cumulative_unlocks(number):
		out.append(String(entry["id"]))
	return out


static func has_unlock(number: int, id: String) -> bool:
	if not is_valid(number):
		return false
	return unlock_ids(number).has(id)


## Unlocks gained by breaking through from `from_realm` to `to_realm`. Only the
## new realm's entries are reported, which is what a breakthrough toast wants.
static func new_unlocks(from_realm: int, to_realm: int) -> Array:
	var out: Array = []
	if to_realm <= from_realm:
		return out
	for n in range(maxi(1, from_realm + 1), mini(to_realm, count()) + 1):
		out.append_array(unlocks_at(n))
	return out


# --- realm arts --------------------------------------------------------------

## The current realm's art. Only this one applies; its flags persist through
## the unlock list, so behaviour survives a realm change.
static func ability(number: int) -> Dictionary:
	return find(number).get("ability", {})


static func ability_name(number: int) -> String:
	return String(ability(number).get("name", ""))


static func ability_mods(number: int) -> Array:
	return ability(number).get("mods", [])


# --- behaviour gates ---------------------------------------------------------

## Dash cancel: dodge may abandon a swing. Foundation Establishment and above.
static func can_dash_cancel(number: int) -> bool:
	return has_unlock(number, "dash_cancel")


## Technique weaving: Qi cost and cooldown of every technique, multiplied.
static func technique_mult(number: int) -> float:
	return WEAVING_MULT if has_unlock(number, "technique_weaving") else 1.0


## Flight: Spirit Transformation and above. The sky costs qi by the second
## and pays back a quarter more speed; the water leash in the scene reads
## the player's flying state, not this gate.
const FLIGHT_SPEED_MULT := 1.25
const FLIGHT_QI_PER_SEC := 2.0

static func can_fly(number: int) -> bool:
	return has_unlock(number, "flight")


## Space folding: Void Refinement and above. The road costs a quarter
## of its hours, and the cultivator's anchor joins the travel list.
const FOLD_TRAVEL_MULT := 0.25

static func can_fold(number: int) -> bool:
	return has_unlock(number, "space_folding")


## Spirit scan: Nascent Soul and above — the spirit leaves the body and
## reads the region and the foe.
static func can_spirit_scan(number: int) -> bool:
	return has_unlock(number, "spirit_scan")


## Elemental conversion: Core Formation and above. A quarter of every
## strike's force leaves the physical road and travels as lightning,
## scaled by the lightning_damage_pct stat.
const CONVERSION_SHARE := 0.25

static func can_convert(number: int) -> bool:
	return has_unlock(number, "elemental_conversion")


## Domain projection: Mahayana and above. In combat the cultivator's
## domain presses on every foe within reach — burning and slowing
## through the ordinary status machinery — for a qi tithe per second.
const DOMAIN_RADIUS := 260.0
const DOMAIN_QI_PER_SEC := 1.0
const DOMAIN_TICK := 0.5

static func can_project_domain(number: int) -> bool:
	return has_unlock(number, "domain_projection")


## Burn pressure inside the domain, damage per second, growing with
## every realm above the unlock.
static func domain_dps(number: int) -> float:
	return 6.0 + 2.0 * float(maxi(0, number - 8))


static func domain_payloads(number: int) -> Array:
	return [
		{"id": "burn", "duration": 1.2, "magnitude": domain_dps(number)},
		{"id": "chill", "duration": 1.2, "magnitude": 0.25},
	]


static func travel_hours(distance: float, number: int) -> float:
	if can_manipulate_planes(number):
		return 0.0
	var hours := Travel.hours_for(distance)
	return hours * FOLD_TRAVEL_MULT if can_fold(number) else hours


## Immortal body: True Immortal and above — age stops costing the body
## anything (the R10/R11 lifespan caps still stand; only the Primordial
## Dao is unbounded).
static func is_immortal_body(number: int) -> bool:
	return has_unlock(number, "immortal_body")


## Plane manipulation: Mystic Sovereign and above — travel folds
## through the planes and costs no hours at all.
static func can_manipulate_planes(number: int) -> bool:
	return has_unlock(number, "plane_manipulation")


## Dao comprehension: at the Primordial Dao, understanding arrives
## twice as deep from every source.
static func dao_deepens(number: int) -> bool:
	return has_unlock(number, "dao_comprehension")
