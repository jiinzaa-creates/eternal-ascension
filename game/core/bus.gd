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

signal enemy_died(at: Vector2, ilvl: int)
signal damage_dealt(total: float, target: Node)
signal item_dropped(item: Dictionary, at: Vector2)
signal item_picked(item: Dictionary)

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal help_toggled(visible: bool)
