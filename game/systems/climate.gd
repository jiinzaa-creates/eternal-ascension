class_name Climate
extends RefCounted
## Seasons and weather, as pure functions of the world clock and seed.
##
## Weather is not simulated frame by frame. The day is cut into six-hour blocks,
## and a block's weather is a pure function of (world_seed, day, block) through
## `Rng.stream`. Two sessions on the same seed therefore see the same weather at
## the same hour, and a save never has to store a weather state — which is why
## this milestone needed no save migration.
##
## Effects are intentionally small and legible: 天気 changes cultivation rate and
## the light, not the rules of combat.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASON_DAYS := 30
const BLOCK_HOURS := 6.0
const KINDS := ["clear", "cloudy", "rain", "storm", "mist", "snow"]

## Weight tables per season, aligned with KINDS. Storm cannot occur in winter or
## spring, snow cannot occur in summer or autumn.
const TABLE := [
	{"clear": 40, "cloudy": 20, "rain": 25, "storm": 0, "mist": 15, "snow": 0},
	{"clear": 45, "cloudy": 10, "rain": 15, "storm": 30, "mist": 0, "snow": 0},
	{"clear": 30, "cloudy": 25, "rain": 20, "storm": 0, "mist": 25, "snow": 0},
	{"clear": 20, "cloudy": 25, "rain": 0, "storm": 0, "mist": 15, "snow": 40},
]

## Cultivation multiplier per weather kind at full intensity.
const CULTIVATION := {
	"clear": 1.0,
	"cloudy": 1.0,
	"rain": 0.9,
	"storm": 1.15,
	"mist": 0.95,
	"snow": 0.85,
}

const TINTS := {
	"cloudy": Color(0.86, 0.88, 0.92),
	"rain": Color(0.64, 0.72, 0.82),
	"storm": Color(0.46, 0.52, 0.66),
	"mist": Color(0.80, 0.84, 0.86),
	"snow": Color(0.90, 0.94, 1.0),
}

const FLASH_PERIOD := 7.0
const FLASH_LENGTH := 0.12


static func season_for_day(day: int) -> int:
	var index := maxi(1, day) - 1
	return floori(float(index) / float(SEASON_DAYS)) % 4


static func season_name(season: int) -> String:
	match season:
		Season.SPRING:
			return "Spring"
		Season.SUMMER:
			return "Summer"
		Season.AUTUMN:
			return "Autumn"
		Season.WINTER:
			return "Winter"
	return "Spring"


static func block_for_hour(hour: float) -> int:
	return int(floor(fposmod(hour, 24.0) / BLOCK_HOURS))


## The weather for a day and hour. Deterministic through the world seed.
static func weather_for(day: int, hour: float) -> Dictionary:
	var season := season_for_day(day)
	var block := block_for_hour(hour)
	var r: RandomNumberGenerator = Rng.stream("weather", day * 10 + block, 0)
	var weights: Array = []
	for kind in KINDS:
		weights.append(int(TABLE[season].get(kind, 0)))
	var index: int = int(Rng.pick_weighted(weights, r))
	if index < 0:
		index = 0
	var kind := String(KINDS[index])
	var intensity := 0.0
	if kind != "clear":
		intensity = r.randf_range(0.35, 1.0)
	return {
		"kind": kind,
		"intensity": intensity,
		"season": season,
		"season_name": season_name(season),
		"day": day,
		"block": block,
	}


## How fast the weather lets a cultivator gather Qi. Intensity scales the effect,
## so light rain barely matters and a full storm matters a lot.
static func cultivation_bonus(weather: Dictionary) -> float:
	var kind := String(weather.get("kind", "clear"))
	var base := float(CULTIVATION.get(kind, 1.0))
	var intensity := clampf(float(weather.get("intensity", 0.0)), 0.0, 1.0)
	return lerpf(1.0, base, intensity)


## Ambient light for a base tint, pulled toward the weather's colour.
static func lighting_modulate(base: Color, weather: Dictionary) -> Color:
	var kind := String(weather.get("kind", "clear"))
	if kind == "clear":
		return base
	var target: Color = TINTS.get(kind, Color.WHITE)
	var amount := clampf(float(weather.get("intensity", 0.0)), 0.0, 1.0) * 0.75
	var mixed := base.lerp(target, amount)
	return Color(mixed.r, mixed.g, mixed.b, base.a)


## A short lightning flash during storms; zero the rest of the time.
static func flash_strength(kind: String, seconds: float) -> float:
	if kind != "storm":
		return 0.0
	var phase := fposmod(seconds, FLASH_PERIOD)
	if phase < FLASH_LENGTH:
		return 1.0 - phase / FLASH_LENGTH
	return 0.0
