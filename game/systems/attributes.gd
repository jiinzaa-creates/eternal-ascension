class_name Attributes
extends RefCounted
## Raw attribute values only.
##
## Derived stats live in StatBlock so every formula has exactly one
## implementation. Attributes are uncapped; effects saturate, costs do not.

const KEYS: Array[String] = ["str", "dex", "agi", "int", "wis", "char"]
const LABELS := {
	"str": "STR", "dex": "DEX", "agi": "AGI",
	"int": "INT", "wis": "WIS", "char": "CHA",
}

var values: Dictionary = {
	"str": 10, "dex": 10, "agi": 10,
	"int": 10, "wis": 10, "char": 10,
}


## Unbounded input, asymptotic output. k is the point where further gains halve.
static func soft(x: float, k: float) -> float:
	return k * log(1.0 + maxf(x, 0.0) / k)


## Exponential acquisition cost: uncapped never means free.
static func attr_cost(next_level: int, base_cost: int = 3) -> int:
	return int(ceil(base_cost * pow(1.055, maxf(next_level - 1, 0))))


func get_attr(key: String) -> int:
	return int(values.get(key, 0))


func add(key: String, amount: int) -> void:
	values[key] = get_attr(key) + amount


func total() -> int:
	var sum := 0
	for key in KEYS:
		sum += get_attr(key)
	return sum


func to_dict() -> Dictionary:
	return values.duplicate()


func from_dict(data: Dictionary) -> void:
	for key in KEYS:
		values[key] = int(data.get(key, values[key]))


func summary() -> String:
	var parts: Array[String] = []
	for key in KEYS:
		parts.append("%s %d" % [LABELS[key], get_attr(key)])
	return "  ".join(parts)
