extends Node
## Typed signal hub. Systems communicate through these signals instead of holding
## references to each other, which is what keeps 20+ subsystems decoupled.

signal toast(text: String)

signal player_stats_changed
signal cultivation_changed
signal meditation_toggled(active: bool)
signal realm_advanced(realm: int, sublevel: int)
signal breakthrough_resolved(result: Dictionary)

signal tribulation_started(type_id: String)
signal tribulation_finished(result: Dictionary)

signal enlightenment_gained(id: String)

signal enemy_died(at: Vector2, ilvl: int)
signal damage_dealt(total: float, target: Node)
## A blow that actually connected. `tint` is the status it applied, "" if none.
## Every damage path reports this, so numbers and sound need no combat code.
signal hit_landed(target: Node, amount: float, critical: bool, tint: String)
## One damage-over-time tick. Numbers only: a burning body is not hit again.
signal status_ticked(target: Node, id: String, amount: float)
## A body committed to a swing. `heavy` distinguishes an art from a weapon.
signal swing_made(heavy: bool)
signal technique_cast(id: String, kind: String)
## The player's ward met a blow: "parry", "block" or "broken".
signal guard_met(kind: String)
signal item_dropped(item: Dictionary, at: Vector2)
signal item_picked(item: Dictionary)

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal help_toggled(visible: bool)
