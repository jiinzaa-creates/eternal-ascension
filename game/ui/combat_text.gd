class_name CombatText
extends RefCounted
## Floating damage text, as pure data.
##
## `DamageNumbers` owns the node and the font; this class owns what a number
## looks like and how it moves. That split is why the formatting rules, the
## colours and the fade can all be checked headlessly.

const RISE := 44.0
const LIFE := 0.9
const CRIT_SIZE := 21
const HIT_SIZE := 14
## A plain hit is bright ink; a critical or a status overrides the tint.
const COLORS := {
	"": "#f2f6f8",
	"crit": "#ffd070",
	"burn": "#ff9a50",
	"bleed": "#d05060",
	"chill": "#7fc8e8",
	"shock": "#c0a0ff",
}


## Rounded damage for display. Nothing is shown for a blow below half a point,
## and very large numbers shorten to thousands so the text stays legible.
static func format_amount(amount: float) -> String:
	if amount <= 0.0:
		return ""
	var rounded := roundi(amount)
	if rounded <= 0:
		return ""
	if rounded >= 10000:
		return "%dk" % int(rounded / 1000.0)
	return str(rounded)


## One live entry, or an empty dictionary when there is nothing worth showing.
## `tint` is a status id; an unknown tint falls back to plain ink. `drift` is the
## horizontal offset a caller assigns so two numbers on one spot do not overlap.
static func entry(amount: float, critical := false, tint := "", drift := 0.0) -> Dictionary:
	var text := format_amount(amount)
	if text == "":
		return {}
	var kind := "crit" if critical else tint
	if not COLORS.has(kind):
		kind = ""
	return {
		"text": text + ("!" if critical else ""),
		"color": String(COLORS[kind]),
		"size": CRIT_SIZE if critical else HIT_SIZE,
		"critical": critical,
		"age": 0.0,
		"life": LIFE,
		"drift": drift,
	}


## Ages every entry and drops the finished ones. Never mutates its input.
static func advance(entries: Array, delta: float) -> Array:
	var step := maxf(0.0, delta)
	var out: Array = []
	for raw in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry_copy: Dictionary = (raw as Dictionary).duplicate(true)
		entry_copy["age"] = float(entry_copy.get("age", 0.0)) + step
		if float(entry_copy["age"]) < float(entry_copy.get("life", LIFE)):
			out.append(entry_copy)
	return out


## How far above its anchor an entry floats, in world units.
static func offset(entry_data: Dictionary) -> Vector2:
	var life := maxf(0.001, float(entry_data.get("life", LIFE)))
	var t := clampf(float(entry_data.get("age", 0.0)) / life, 0.0, 1.0)
	# Ease out: a number jumps up and then settles as it fades.
	var rise := 1.0 - pow(1.0 - t, 2.0)
	return Vector2(float(entry_data.get("drift", 0.0)), -RISE * rise)


## 1 while fresh, fading over the last 35% of the entry's life.
static func alpha(entry_data: Dictionary) -> float:
	var life := maxf(0.001, float(entry_data.get("life", LIFE)))
	var t := clampf(float(entry_data.get("age", 0.0)) / life, 0.0, 1.0)
	return 1.0 if t < 0.65 else clampf((1.0 - t) / 0.35, 0.0, 1.0)


static func text(entry_data: Dictionary) -> String:
	return String(entry_data.get("text", ""))


static func color(entry_data: Dictionary) -> Color:
	return Color(String(entry_data.get("color", COLORS[""])))


static func font_size(entry_data: Dictionary) -> int:
	return int(entry_data.get("size", HIT_SIZE))


static func expired(entry_data: Dictionary) -> bool:
	return float(entry_data.get("age", 0.0)) >= float(entry_data.get("life", LIFE))
