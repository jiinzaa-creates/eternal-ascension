class_name Damage
extends RefCounted
## Damage resolution shared by player, NPCs and monsters.
##
## Resistance uses a diminishing formula that stays meaningful across 12 realms:
## a flat 40% resist does not mean the same thing against a Qi Condensation
## disciple and a Nascent Soul cultivator.

const MIN_HIT := 1.0


static func effective_resist(resist: float, attacker_power: float) -> float:
	return clampf(resist / maxf(resist + 100.0 + 4.0 * attacker_power, 1.0), 0.0, 0.9)


static func resolve(raw: float, resist: float = 0.0, attacker_power: float = 0.0) -> float:
	return maxf(MIN_HIT, raw * (1.0 - effective_resist(resist, attacker_power)))


## Attribute + technique scaling, before resistances. Matches the combat spec.
static func technique_damage(technique: Dictionary, stats: StatBlock, weapon_damage: float = 0.0) -> float:
	var base := float(technique.get("base_damage", 0.0))
	var scaling: Dictionary = technique.get("scaling", {})
	var scaled := 0.0
	for key in scaling.keys():
		scaled += float(stats.get_attr(String(key))) * float(scaling[key])
	var raw := (base + scaled + weapon_damage) * stats.physical_mult()
	return raw


static func poise_damage(technique: Dictionary, stats: StatBlock) -> float:
	var base := float(technique.get("poise_damage", 10.0))
	return base * (0.7 + Attributes.soft(float(stats.get_attr("str")), 22.0) / 30.0)


static func knockback(technique: Dictionary, stats: StatBlock) -> float:
	var base := float(technique.get("knockback", 160.0))
	return base * (0.75 + Attributes.soft(float(stats.get_attr("str")), 25.0) / 40.0)


## Armour reduces incoming physical damage before the resistance curve.
static func mitigate_armor(raw: float, armor: float) -> float:
	return raw * (1.0 - clampf(armor / maxf(armor + 60.0, 1.0), 0.0, 0.75))
