class_name Mastery
extends RefCounted
## Technique mastery: one number (xp) per technique, everything else derived.
##
## Mastery is a pure function of accumulated xp so it can be tested without a
## player, and so saves only have to store the small integer. Tiers improve
## damage, cut Qi cost and shorten cooldowns; they never change frame data,
## because timing is the technique's identity, not its power level.

const MAX_TIER := 5
const XP_PER_HIT := 1
const LABELS := ["Untrained", "Novice", "Adept", "Proficient", "Master", "Perfected"]


static func xp_to_next(tier: int) -> int:
	var t := clampi(tier, 0, MAX_TIER)
	return 15 + 10 * t


## Cumulative xp needed to reach `tier`.
static func total_xp(tier: int) -> int:
	var total := 0
	for t in clampi(tier, 0, MAX_TIER):
		total += xp_to_next(t)
	return total


static func tier_for(xp: int) -> int:
	var remaining := maxi(0, xp)
	for tier in MAX_TIER:
		var need := xp_to_next(tier)
		if remaining < need:
			return tier
		remaining -= need
	return MAX_TIER


static func clamp_xp(xp: int) -> int:
	return clampi(xp, 0, total_xp(MAX_TIER))


static func label(tier: int) -> String:
	return String(LABELS[clampi(tier, 0, MAX_TIER)])


static func damage_mult(tier: int) -> float:
	return 1.0 + 0.05 * float(clampi(tier, 0, MAX_TIER))


static func cooldown_mult(tier: int) -> float:
	return 1.0 - 0.04 * float(clampi(tier, 0, MAX_TIER))


static func qi_mult(tier: int) -> float:
	return 1.0 - 0.04 * float(clampi(tier, 0, MAX_TIER))


## 0.0–1.0 progress toward the next tier; 1.0 at max tier.
static func progress(xp: int) -> float:
	var tier := tier_for(xp)
	if tier >= MAX_TIER:
		return 1.0
	var into := maxi(0, xp) - total_xp(tier)
	return clampf(float(into) / float(xp_to_next(tier)), 0.0, 1.0)
