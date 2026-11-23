class_name Roots
extends RefCounted
## Spiritual-root rules: appraisal, hidden purity, marrow and evolution.
##
## A root is rolled at creation, but its **purity bonus** is hidden until the
## pavilion reads it. The bonus is pure upside — the base purity still applies
## while unread — so appraisal is discovery without a trap.
##
## Evolution is paid in marrow found at overworld sites plus spirit stones, and
## raises the tier by exactly one. Nothing here mutates state: the host applies.

const MAX_TIER := 12
const IDENTIFY_COST := 40
const PURITY_BONUS_MAX := 0.25
const MARROW_CHANCE := 0.35


## Stones for the step out of `tier`. Rising from a high root costs more.
static func evolve_cost(tier: int) -> int:
	return 90 + clampi(tier, 1, MAX_TIER) * 60


## Whether evolution is possible right now, and why not if it is not.
static func can_evolve(tier: int, marrow: int, stones: int) -> Dictionary:
	if tier >= MAX_TIER:
		return {"ok": false, "reason": "max_tier", "cost": 0}
	if marrow <= 0:
		return {"ok": false, "reason": "no_marrow", "cost": evolve_cost(tier)}
	var cost := evolve_cost(tier)
	if stones < cost:
		return {"ok": false, "reason": "no_stones", "cost": cost}
	return {"ok": true, "reason": "", "cost": cost}


## Hidden purity bonus for a roll. `key` is the roll counter, so rerolling the
## root rerolls this too and saving the number is all that persistence needs.
static func roll_purity_bonus(key: int) -> float:
	return float(Rng.stream("root_purity", key, 0).randf_range(0.0, PURITY_BONUS_MAX))


## Deterministic marrow find per site: the same mine always either has it or not.
static func marrow_found(coord: Vector2i, site: String) -> bool:
	var key := coord.x * 73856 + coord.y * 19349 + hash(site)
	return float(Rng.stream("root_marrow", key, 0).randf()) < MARROW_CHANCE


static func purity_label(purity: float) -> String:
	var value := clampf(purity, 0.0, 1.0)
	if value >= 0.95:
		return "flawless"
	if value >= 0.85:
		return "pure"
	if value >= 0.7:
		return "clear"
	if value >= 0.55:
		return "clouded"
	return "muddy"


static func affinity_text(root: Dictionary) -> String:
	var affinities: Array = root.get("affinities", [])
	if affinities.is_empty():
		return "none"
	return ", ".join(affinities)


## "Ordinary Root (clouded) — metal, wood"
static func describe(root: Dictionary, purity: float) -> String:
	return "%s (%s) — %s" % [
		String(root.get("name", "Unknown Root")), purity_label(purity), affinity_text(root),
	]
