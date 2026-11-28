class_name Weapons
extends RefCounted
## Weapon framework: every weapon category owns a light-attack moveset.
##
## A weapon item declares `weapon_type`. Saves written before that key existed
## are still read: the category falls back to the base id (`base.sword.iron_jian`
## -> sword) and finally to unarmed, so no migration is needed and an old item
## never becomes a phantom weapon.
##
## A moveset is plain frame data fed to `Combat`, exactly like a technique's, so
## reach, arcs, phase timing, poise and knockback stay on the one shared path.
## Nothing here touches nodes or the scene tree; everything is pure and testable.

const DEFAULT_TYPE := "fist"
## Base ids carry their category, which is how legacy items are classified.
const BASE_PREFIXES := {
	"base.sword.": "sword",
	"base.saber.": "saber",
	"base.staff.": "staff",
	"base.whip.": "whip",
}


static func all() -> Array:
	return DB.weapon_types


static func find(type_id: String) -> Dictionary:
	if type_id == "":
		return {}
	return DB.weapon_type(type_id)


## The category an item fights as. Explicit data first, then the id conventions
## of older items, then bare hands.
static func type_id_for(item: Dictionary) -> String:
	if item.is_empty():
		return DEFAULT_TYPE
	var explicit := String(item.get("weapon_type", ""))
	if explicit != "" and not find(explicit).is_empty():
		return explicit
	for candidate in [String(item.get("base", "")), String(item.get("id", ""))]:
		for prefix in BASE_PREFIXES.keys():
			if candidate.begins_with(String(prefix)):
				var derived := String(BASE_PREFIXES[prefix])
				if not find(derived).is_empty():
					return derived
	return DEFAULT_TYPE


static func type_for_item(item: Dictionary) -> Dictionary:
	return find(type_id_for(item))


static func moves(type_id: String) -> Array:
	return find(type_id).get("moves", [])


static func move_in(type: Dictionary, index: int) -> Dictionary:
	var list: Array = type.get("moves", [])
	if list.is_empty():
		return {}
	var entry: Variant = list[clampi(index, 0, list.size() - 1)]
	return entry if typeof(entry) == TYPE_DICTIONARY else {}


static func move(type_id: String, index: int) -> Dictionary:
	return move_in(find(type_id), index)


## The chain step a fresh press opens. Starting from -1, or after the window has
## lapsed, the sequence begins at its first strike again.
static func next_combo(index: int, since_last: float, window: float, length: int) -> int:
	if length <= 0:
		return 0
	if index < 0 or since_last > maxf(0.0, window):
		return 0
	return (index + 1) % length


## The category's reach applied to a move's own arc. Radius is the only thing it
## changes: a whip is long, not wide.
static func scaled_hitbox(move_data: Dictionary, type: Dictionary) -> Dictionary:
	var box: Dictionary = (move_data.get("hitbox", {}) as Dictionary).duplicate(true)
	box["radius"] = maxf(1.0, float(box.get("radius", 70.0)) * maxf(0.1, float(type.get("reach_mult", 1.0))))
	return box


## The payload the player's frame machine runs. Shaped like a technique on
## purpose, so a light strike shares phase timing, crits, poise and hitboxes
## instead of growing a parallel combat path.
static func attack_payload(type: Dictionary, index: int) -> Dictionary:
	var move_data := move_in(type, index)
	if move_data.is_empty():
		return {}
	var type_id := String(type.get("id", DEFAULT_TYPE))
	return {
		"id": "light:%s:%d" % [type_id, index],
		"name": String(move_data.get("name", "Strike")),
		"light": true,
		"frames": move_data.get("frames", {}),
		"hitbox": scaled_hitbox(move_data, type),
		"base_damage": float(move_data.get("base_damage", 0.0)),
		"damage_mult": float(move_data.get("damage_mult", 1.0)),
		# The category's weight is baked in here, so the shared Damage helpers
		# (*.poise_damage, *.knockback) need no weapon-specific branch.
		"poise_damage": float(move_data.get("poise_damage", 6.0)) * maxf(0.0, float(type.get("poise_mult", 1.0))),
		"knockback": float(move_data.get("knockback", 100.0)) * maxf(0.0, float(type.get("knock_mult", 1.0))),
		"speed_mult": maxf(0.1, float(type.get("speed_mult", 1.0))),
		"cooldown": maxf(0.0, float(type.get("recovery_cooldown", 0.06))),
		"combo_window": maxf(0.0, float(type.get("combo_window", 0.75))),
		"lifesteal": 0.0,
		"tags": move_data.get("tags", []),
		# A ranged category delivers its resolved strike by arrow, not
		# by arc: the payload carries the type's own projectile spec.
		"delivery": String(type.get("delivery", "")),
		"projectile": (type.get("projectile", {}) as Dictionary).duplicate(true),
	}
