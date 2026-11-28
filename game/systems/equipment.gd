class_name Equipment
extends RefCounted
## Equipment aggregation rules: what a body must be to wear a piece, what a
## piece refuses to sit beside, and how a candidate compares with the slot.
##
## Requirements, tags and conflicts live on the item *base* in `data/items.json`
## and are read by base id, so an instance carries no rules of its own and a
## save never has to store them. An item without a known base is unrestricted.

const SLOT_LABELS := {"weapon": "Weapon", "armor": "Armour", "ring": "Ring", "ring2": "Ring (second)", "necklace": "Necklace", "talisman": "Talisman", "artifact": "Artifact"}

## The keys a body's worn set is stored under. Item slots and worn
## keys are the same list but for one finger: a ring item resolves
## to "ring", then "ring2", so two rings can be worn at once.
const WORN_KEYS: Array[String] = Items.WORN_KEYS

const STAT_LABELS := {
	"weapon_damage": "damage",
	"armor": "armour",
	"physical_damage_pct": "physical damage",
	"attack_speed_pct": "attack speed",
	"qi_regen_flat": "Qi regeneration",
	"crit_chance": "critical chance",
	"physical_resist": "physical resistance",
	"move_speed_pct": "movement speed",
	"cult_speed_pct": "cultivation speed",
	"qi_max_pct": "maximum Qi",
	"qi_max_flat": "maximum Qi",
	"penetration": "armour penetration",
	"cooldown_reduction": "cooldown reduction",
	"crit_damage": "critical damage",
	"lightning_damage_pct": "lightning damage",
	"evasion": "evasion",
	"health_regen": "health regeneration",
	"lifespan": "lifespan",
	"str": "STR", "dex": "DEX", "agi": "AGI",
	"int": "INT", "wis": "WIS", "char": "CHA",
}

const STAT_UNITS := {
	"crit_chance": "%", "penetration": "%", "crit_damage": "%",
	"evasion": "%", "physical_resist": "%", "cooldown_reduction": "%",
	"health_regen": "/s", "lifespan": " years",
}

var db: Node


func _init(database: Node) -> void:
	db = database


func base_of(item: Dictionary) -> Dictionary:
	var base_id := String(item.get("base", ""))
	if base_id == "" or db == null:
		return {}
	var base: Dictionary = db.by_id("base", base_id)
	return base


func requirements(item: Dictionary) -> Dictionary:
	var req: Variant = base_of(item).get("requires", {})
	return req if typeof(req) == TYPE_DICTIONARY else {}


## Tags the piece carries. An instance may override its base (uniques will),
## otherwise the base's tags are the truth.
func tags(item: Dictionary) -> Array:
	var own: Variant = item.get("tags", null)
	if typeof(own) == TYPE_ARRAY:
		return own
	var tags_value: Variant = base_of(item).get("tags", [])
	return tags_value if typeof(tags_value) == TYPE_ARRAY else []


func conflicts(item: Dictionary) -> Array:
	var own: Variant = item.get("conflicts", null)
	if typeof(own) == TYPE_ARRAY:
		return own
	var conflicts_value: Variant = base_of(item).get("conflicts", [])
	return conflicts_value if typeof(conflicts_value) == TYPE_ARRAY else []


## Every requirement the body fails, as labels a player can read.
func missing_requirements(item: Dictionary, attrs: Attributes, realm: int) -> Array:
	var out: Array = []
	var req := requirements(item)
	for key in req.keys():
		var need := int(req[key])
		var name := String(key)
		if name == "realm":
			if realm < need:
				out.append("realm %d" % need)
			continue
		var have := 0 if attrs == null else attrs.get_attr(name)
		if have < need:
			out.append("%s %d" % [String(Attributes.LABELS.get(name, name)), need])
	return out


## The worn key this item would occupy: its own slot, except a
## ring, which takes the free finger before it replaces one.
func equip_key_for(item: Dictionary, equipment: Dictionary) -> String:
	var slot := String(item.get("slot", ""))
	if slot != "ring":
		return slot
	var first: Variant = equipment.get("ring", {})
	if typeof(first) != TYPE_DICTIONARY or (first as Dictionary).is_empty():
		return "ring"
	var second: Variant = equipment.get("ring2", {})
	if typeof(second) != TYPE_DICTIONARY or (second as Dictionary).is_empty():
		return "ring2"
	return "ring"


## The worn piece this one cannot coexist with, or an empty dictionary.
func conflict_with(item: Dictionary, equipment: Dictionary, target_key: String = "") -> Dictionary:
	var mine := tags(item)
	var mine_conflicts := conflicts(item)
	var slot := target_key if target_key != "" else String(item.get("slot", ""))
	for other_slot in equipment.keys():
		if String(other_slot) == slot:
			continue
		var other_value: Variant = equipment[other_slot]
		if typeof(other_value) != TYPE_DICTIONARY:
			continue
		var other: Dictionary = other_value
		if other.is_empty():
			continue
		var other_tags := tags(other)
		for tag in mine_conflicts:
			if other_tags.has(tag):
				return {"slot": String(other_slot), "name": String(other.get("name", other_slot)), "tag": String(tag)}
		for tag in conflicts(other):
			if mine.has(tag):
				return {"slot": String(other_slot), "name": String(other.get("name", other_slot)), "tag": String(tag)}
	return {}


## The single gate every equip route goes through, auto-equip included.
func can_equip(item: Dictionary, equipment: Dictionary, attrs: Attributes, realm: int, target_key: String = "") -> Dictionary:
	if not Items.is_equipment(String(item.get("slot", ""))):
		return {"ok": false, "reason": "not a piece of equipment"}
	var missing := missing_requirements(item, attrs, realm)
	if not missing.is_empty():
		return {"ok": false, "reason": "Requires " + ", ".join(missing)}
	var clash := conflict_with(item, equipment, target_key)
	if not clash.is_empty():
		return {"ok": false, "reason": "Conflicts with %s" % String(clash.get("name", "worn gear"))}
	return {"ok": true, "reason": ""}


static func label_for(stat: String) -> String:
	return String(STAT_LABELS.get(stat, stat.replace("_", " ")))


static func unit_for(stat: String) -> String:
	if stat.ends_with("_pct"):
		return "%"
	return String(STAT_UNITS.get(stat, ""))


## Flat contribution of one item: its base power plus every affix, summed per
## stat. This is the same shape StatBlock reads, so a comparison cannot claim a
## gain the pipeline will not deliver.
func stat_map(item: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if item.is_empty():
		return out
	if String(item.get("slot", "")) == "weapon" and float(item.get("base_damage", 0.0)) != 0.0:
		out["weapon_damage"] = float(item.get("base_damage", 0.0))
	if float(item.get("armor", 0.0)) != 0.0:
		out["armor"] = float(item.get("armor", 0.0))
	for mod in item.get("mods", []):
		if typeof(mod) != TYPE_DICTIONARY:
			continue
		var stat := String((mod as Dictionary).get("stat", ""))
		if stat == "":
			continue
		out[stat] = float(out.get(stat, 0.0)) + float((mod as Dictionary).get("value", 0.0))
	return out


## Candidate minus worn, stat by stat. Zero differences are dropped; an empty
## list means the two pieces are numerically identical to the pipeline.
func compare(item: Dictionary, equipped: Dictionary) -> Dictionary:
	var before := stat_map(equipped)
	var after := stat_map(item)
	var keys: Array = before.keys()
	for key in after.keys():
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	var deltas: Array = []
	for key in keys:
		var delta := float(after.get(key, 0.0)) - float(before.get(key, 0.0))
		if absf(delta) < 0.001:
			continue
		deltas.append({
			"stat": String(key),
			"label": label_for(String(key)),
			"delta": delta,
			"unit": unit_for(String(key)),
		})
	return {"deltas": deltas, "before": before, "after": after}
