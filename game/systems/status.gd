class_name Status
extends RefCounted
## Timed combat statuses: burning, bleeding, chilled and shocked.
##
## Every rule is pure. An entity owns an `Array` of entries and passes it here;
## `apply()` returns a new array, `advance()` returns the surviving entries plus
## the damage that came due this frame. Nothing here touches a node, a clock or
## the scene tree, so the whole system is testable headlessly.
##
## An entry is a plain dictionary:
##   id         one of IDS
##   remaining  seconds left
##   magnitude  damage per second (burn, bleed) or fraction (chill, shock)
##   stacks     1..MAX_STACKS; multiplies the effect, never the duration
##   accum      private tick accumulator for damage-over-time
##
## DoT ticks every TICK seconds and is deliberately unblockable: a guard, armour
## and evasion are for blows, not for fire already in the blood.

const IDS: Array[String] = ["burn", "bleed", "chill", "shock"]
const MAX_STACKS := 3
const TICK := 0.5
const SLOW_CAP := 0.6
const TAKEN_CAP := 0.5

const DEFS := {
	"burn": {"name": "Burning", "color": "#ff9a50", "dot": true},
	"bleed": {"name": "Bleeding", "color": "#d05060", "dot": true},
	"chill": {"name": "Chilled", "color": "#7fc8e8", "dot": false},
	"shock": {"name": "Shocked", "color": "#c0a0ff", "dot": false},
}


static func is_valid(id: String) -> bool:
	return IDS.has(id)


static func def(id: String) -> Dictionary:
	var entry: Variant = DEFS.get(id, {})
	return entry if typeof(entry) == TYPE_DICTIONARY else {}


static func name_of(id: String) -> String:
	return String(def(id).get("name", id.capitalize()))


static func color(id: String) -> Color:
	return Color(String(def(id).get("color", "#e6eef2")))


static func is_dot(id: String) -> bool:
	return bool(def(id).get("dot", false))


## Applies a payload (`id`, `duration`, `magnitude`, optional `stacks`). The same
## status refreshes its clock, keeps the stronger magnitude and gains a stack.
## Malformed or unknown payloads leave the array unchanged.
static func apply(active: Array, payload: Dictionary) -> Array:
	var id := String(payload.get("id", ""))
	var duration := float(payload.get("duration", 0.0))
	var magnitude := float(payload.get("magnitude", 0.0))
	var out := active.duplicate(true)
	if not is_valid(id) or duration <= 0.0 or magnitude <= 0.0:
		return out
	var stacks := clampi(int(payload.get("stacks", 1)), 1, MAX_STACKS)
	for i in out.size():
		var entry: Variant = out[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = entry
		if String(copy.get("id", "")) != id:
			continue
		copy["remaining"] = maxf(float(copy.get("remaining", 0.0)), duration)
		copy["magnitude"] = maxf(float(copy.get("magnitude", 0.0)), magnitude)
		copy["stacks"] = clampi(maxi(int(copy.get("stacks", 1)), stacks) + 1, 1, MAX_STACKS)
		out[i] = copy
		return out
	out.append({
		"id": id,
		"remaining": duration,
		"magnitude": magnitude,
		"stacks": stacks,
		"accum": 0.0,
	})
	return out


## Advances every status by `delta`. Returns the surviving entries and one hit
## per due damage tick: `{"active": Array, "hits": [{"id", "amount"}]}`.
static func advance(active: Array, delta: float) -> Dictionary:
	var step := maxf(0.0, delta)
	var living: Array = []
	var hits: Array = []
	for entry in active:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (entry as Dictionary).duplicate(true)
		var id := String(copy.get("id", ""))
		copy["remaining"] = float(copy.get("remaining", 0.0)) - step
		if float(copy["remaining"]) <= 0.0:
			continue
		if is_dot(id):
			var accum := float(copy.get("accum", 0.0)) + step
			var per_tick := float(copy.get("magnitude", 0.0)) * float(copy.get("stacks", 1)) * TICK
			while accum >= TICK:
				accum -= TICK
				hits.append({"id": id, "amount": per_tick})
			copy["accum"] = accum
		living.append(copy)
	return {"active": living, "hits": hits}


## The movement-speed fraction lost to chill, 0..SLOW_CAP.
static func slow(active: Array) -> float:
	var total := 0.0
	for entry in active:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = entry
		if String(copy.get("id", "")) != "chill":
			continue
		total += float(copy.get("magnitude", 0.0)) * float(copy.get("stacks", 1))
	return clampf(total, 0.0, SLOW_CAP)


## Multiplier on incoming damage from shock, 1..1+TAKEN_CAP.
static func taken_multiplier(active: Array) -> float:
	var total := 0.0
	for entry in active:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = entry
		if String(copy.get("id", "")) != "shock":
			continue
		total += float(copy.get("magnitude", 0.0)) * float(copy.get("stacks", 1))
	return 1.0 + clampf(total, 0.0, TAKEN_CAP)


## Multiplier for movement and other clocked actions, 1..(1-SLOW_CAP).
static func speed_multiplier(active: Array) -> float:
	return 1.0 - slow(active)


static func has(active: Array, id: String) -> bool:
	return remaining_of(active, id) > 0.0


static func remaining_of(active: Array, id: String) -> float:
	for entry in active:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = entry
		if String(copy.get("id", "")) == id:
			return maxf(0.0, float(copy.get("remaining", 0.0)))
	return 0.0


## The status id a payload names, or "" when there is no usable payload. Damage
## numbers and audio use this so a tint never lies about what was applied.
static func id_of(payload: Dictionary) -> String:
	var id := String(payload.get("id", ""))
	return id if is_valid(id) else ""


## Human labels for the HUD, e.g. "Burning 2s".
static func labels(active: Array) -> Array:
	var out: Array = []
	for entry in active:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = entry
		var id := String(copy.get("id", ""))
		if not is_valid(id):
			continue
		out.append("%s %ds" % [name_of(id), maxi(1, int(ceil(float(copy.get("remaining", 0.0)))))])
	return out


static func count(active: Array) -> int:
	return labels(active).size()
