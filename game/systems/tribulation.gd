class_name Tribulation
extends RefCounted
## A playable heavenly trial: telegraph, strike, repeat.
##
## Pure rules, no nodes. `tick(delta, player_offset)` advances the schedule and
## reports the bolts that just landed, whether a wave closed and whether the
## trial is over. The arena node only draws and applies damage, so the whole
## encounter is deterministic and testable without a display.
##
## Positions are relative to the arena centre. Every bolt is telegraphed long
## enough to walk out of, and bolts are staggered inside a wave, so the trial is
## a movement test rather than a damage check.

const FALLBACK_ID := "meridian"
const TELEGRAPH := 0.9
const ARENA_RADIUS := 210.0
const TARGET_SCATTER := 70.0
const BOLT_RADIUS := 44.0
const COMPOSURE_PER_WAVE := 0.04
const MAX_COMPOSURE := 0.12

var type_id := FALLBACK_ID
var data: Dictionary = {}
var scale := 1.0
var centre := Vector2.ZERO
var waves_total := 3
var wave := 1
var wave_hits := 0
var hits := 0
var waves_survived := 0
var perfect_waves := 0
var finished := false
var broken := false
## Pending bolts: {pos: Vector2, left: float, resolved: bool}.
var strikes: Array = []
var _rng: RandomNumberGenerator


func setup(id: String, scale_value: float, arena_centre: Vector2, generator: RandomNumberGenerator) -> void:
	type_id = id if not Tribulation.find(id).is_empty() else FALLBACK_ID
	data = Tribulation.find(type_id)
	scale = maxf(0.0, scale_value)
	centre = arena_centre
	waves_total = maxi(1, int(data.get("waves", 3)))
	_rng = generator
	wave = 1
	_spawn_wave()


static func find(id: String) -> Dictionary:
	var entry := DB.tribulation(id)
	if entry.is_empty():
		return DB.tribulation(FALLBACK_ID)
	return entry


static func exists(id: String) -> bool:
	return not DB.tribulation(id).is_empty()


static func name_of(id: String) -> String:
	return String(find(id).get("name", "Tribulation"))


static func color_of(id: String) -> String:
	return String(find(id).get("color", "#e0d090"))


## What a realm's cultivator faces to leave it. Falls back to the meridian trial
## rather than letting bad data produce an empty encounter.
static func for_realm(realm: int) -> String:
	var declared := String(DB.realm(realm).get("tribulation", FALLBACK_ID))
	return declared if exists(declared) else FALLBACK_ID


## Perfect waves buy at most a fourth of the gap a method can open.
static func composure(perfect: int) -> float:
	return clampf(float(maxi(0, perfect)) * COMPOSURE_PER_WAVE, 0.0, MAX_COMPOSURE)


func damage_per_bolt() -> float:
	var base := 10.0 + 10.0 * clampf(scale, 0.0, 3.0)
	return base * maxf(0.1, float(data.get("damage_mult", 1.0)))


func bolts_per_wave() -> int:
	return maxi(1, int(data.get("bolts", 3)))


func interval() -> float:
	return maxf(0.15, float(data.get("interval", 0.7)))


## Places one wave's telegraphs around the cultivator. The scatter radius comes
## from data so heavy tribulations cover more ground.
func _spawn_wave() -> void:
	strikes.clear()
	wave_hits = 0
	var radius := maxf(20.0, float(data.get("radius", TARGET_SCATTER)))
	for i in bolts_per_wave():
		var angle := _rng.randf() * TAU
		var distance := _rng.randf() * radius
		var offset := Vector2(cos(angle), sin(angle)) * distance
		# Staggered telegraphs: a wave is a sequence to read, not one volley.
		strikes.append({"pos": offset, "left": TELEGRAPH + float(i) * interval(), "resolved": false})


## Advances the trial. `player_offset` is the player relative to the arena
## centre, which is the same space the strike positions use.
func tick(delta: float, player_offset: Vector2) -> Dictionary:
	var struck: Array = []
	var wave_finished := false
	if finished:
		return {"struck": struck, "wave_finished": false, "finished": true, "broken": broken}
	for strike in strikes:
		if bool(strike["resolved"]):
			continue
		strike["left"] = float(strike["left"]) - delta
		if float(strike["left"]) > 0.0:
			continue
		strike["resolved"] = true
		var hit := player_offset.distance_to(strike["pos"]) <= BOLT_RADIUS
		if hit:
			hits += 1
			wave_hits += 1
		struck.append({"pos": strike["pos"], "radius": BOLT_RADIUS, "hit": hit, "damage": damage_per_bolt()})
	var pending := false
	for strike in strikes:
		if not bool(strike["resolved"]):
			pending = true
			break
	if not pending:
		wave_finished = true
		waves_survived += 1
		if wave_hits == 0:
			perfect_waves += 1
		if wave >= waves_total:
			finished = true
		else:
			wave += 1
			_spawn_wave()
	return {"struck": struck, "wave_finished": wave_finished, "finished": finished, "broken": broken}


## The player fell inside the circle. No roll: heaven already answered.
func abort() -> void:
	if finished:
		return
	broken = true
	finished = true


func result() -> Dictionary:
	return {
		"type": type_id,
		"name": name_of(type_id),
		"outcome": "broken" if broken else ("survived" if finished else "unfinished"),
		"waves_total": waves_total,
		"waves_survived": waves_survived,
		"perfect_waves": perfect_waves,
		"hits": hits,
		"composure": 0.0 if broken else composure(perfect_waves),
		"damage_per_bolt": damage_per_bolt(),
	}
