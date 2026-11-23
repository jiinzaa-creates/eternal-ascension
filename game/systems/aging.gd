class_name Aging
extends RefCounted
## Lifespan and aging: a body has a calendar age, and past its prime it weakens
## physically while WIS, INT and CHA are spared. A lifespan of 0 means unbounded.
##
## Time is compressed for a playable pace: the world calendar runs on 30-day
## seasons, but the body ages one year every DAYS_PER_YEAR days rather than one
## full calendar year. A realm-1 mortal therefore lives out ~120 years across
## 2,880 world days.

const START_AGE := 16
const DAYS_PER_YEAR := 24.0
## Fraction of lifespan after which age begins to cost physical attributes.
const DECLINE_START := 0.6
## Fraction of physical attributes lost at exactly the lifespan.
const DECLINE_MAX := 0.35
## Attributes aging reduces; wisdom and the mental attributes only grow.
const AGING_KEYS: Array[String] = ["str", "dex", "agi"]


## Age in years on a given world day, given the day the body was born.
static func age_for(born_day: int, day: int, start_age: int = START_AGE) -> float:
	var days := maxi(0, day - born_day)
	return float(start_age) + float(days) / DAYS_PER_YEAR


## Fraction of the lifespan already lived; 0 for an unbounded lifespan.
static func ratio(age: float, lifespan: int) -> float:
	if lifespan <= 0:
		return 0.0
	return age / float(lifespan)


## Whole years left, floored at zero; -1 means unbounded.
static func remaining_years(age: float, lifespan: int) -> int:
	if lifespan <= 0:
		return -1
	return maxi(0, int(floor(float(lifespan) - age)))


static func stage(age: float, lifespan: int) -> String:
	if lifespan <= 0:
		return "ageless"
	var value := ratio(age, lifespan)
	if value >= 1.0:
		return "ended"
	if value >= 0.95:
		return "fading"
	if value >= 0.85:
		return "old"
	if value >= DECLINE_START:
		return "middle"
	return "prime"


## Warning ordering; "ageless" and "prime" share the bottom rank so a toast
## fires at most once per stage even if a lifespan changes.
static func stage_rank(name: String) -> int:
	match name:
		"middle":
			return 1
		"old":
			return 2
		"fading":
			return 3
		"ended":
			return 4
	return 0


## Fraction of STR/DEX/AGI lost to age: nothing until DECLINE_START, then a
## linear slide to DECLINE_MAX at the lifespan.
static func decline(age: float, lifespan: int) -> float:
	if lifespan <= 0:
		return 0.0
	var start := float(lifespan) * DECLINE_START
	if age <= start:
		return 0.0
	var span := maxf(1.0, float(lifespan) - start)
	return clampf((age - start) / span * DECLINE_MAX, 0.0, DECLINE_MAX)


static func is_dead(age: float, lifespan: int) -> bool:
	return lifespan > 0 and age >= float(lifespan)


static func phrase(name: String) -> String:
	match name:
		"middle":
			return "middle age"
		"old":
			return "old age"
		"fading":
			return "fading years"
		"ended":
			return "ended"
		"ageless":
			return "ageless"
	return "prime"


## One-line age for the HUD and the end screen.
static func age_text(age: float, lifespan: int) -> String:
	if lifespan <= 0:
		return "Age %d · ageless" % int(age)
	return "Age %d/%d · %s" % [int(age), lifespan, phrase(stage(age, lifespan))]


## Toast text when a declining stage is first entered; empty for other stages.
static func warning_for(name: String) -> String:
	match name:
		"middle":
			return "Years have begun to tell. Your stride is a little slower, your arm a little heavier."
		"old":
			return "Old age has set in: STR, DEX and AGI fade. A higher realm would lengthen your years."
		"fading":
			return "Your remaining years are almost spent. Break through, or the dao will release you."
	return ""
