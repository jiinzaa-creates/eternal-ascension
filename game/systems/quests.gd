class_name QuestLog
extends RefCounted
## Quest state for the Azure Cloud initiation line.
##
## Steps are data (res://data/quests.json) and are strictly ordered. Progress is
## reported by gameplay events — talking to an NPC, killing a beast, picking up
## a herb, channelling at a shrine — not by a script watching the player.

const QUEST_ID := "quest.azure_cloud.initiation"

var quest: Dictionary
var step_index: int = 0
var counters: Dictionary = {}
var completed: bool = false
var rewarded: bool = false


func _init() -> void:
	quest = DB.quest(QUEST_ID)


func title() -> String:
	return String(quest.get("title", "Unknown Quest"))


func is_valid() -> bool:
	return not quest.is_empty()


func steps() -> Array:
	return quest.get("steps", [])


func current_step() -> Dictionary:
	var all := steps()
	if step_index < 0 or step_index >= all.size():
		return {}
	return all[step_index]


func current_kind() -> String:
	return String(current_step().get("kind", ""))


func current_target() -> String:
	return String(current_step().get("target", ""))


func required_count() -> int:
	return maxi(1, int(current_step().get("count", 1)))


func progress_key(kind: String, target: String) -> String:
	return "%s:%s" % [kind, target]


## Reports a gameplay event. Returns true when the step advanced.
func track(kind: String, target: String, amount: int = 1) -> bool:
	if completed or not is_valid():
		return false
	var step := current_step()
	if step.is_empty():
		return false
	if String(step.get("kind", "")) != kind or String(step.get("target", "")) != target:
		return false

	var key := progress_key(kind, target)
	counters[key] = int(counters.get(key, 0)) + amount
	if int(counters[key]) < required_count():
		return false

	step_index += 1
	if step_index >= steps().size():
		completed = true
		step_index = steps().size() - 1
	return true


func objective_text() -> String:
	if not is_valid():
		return ""
	if completed:
		return "The Azure Cloud has accepted you."
	var step := current_step()
	var text := String(step.get("text", ""))
	var need := required_count()
	if need > 1:
		var key := progress_key(current_kind(), current_target())
		text += "  (%d/%d)" % [mini(int(counters.get(key, 0)), need), need]
	return text


func tracker_text() -> String:
	if not is_valid():
		return ""
	return "%s\n  %s" % [title(), objective_text()]


func to_dict() -> Dictionary:
	return {
		"quest_id": QUEST_ID,
		"step_index": step_index,
		"counters": counters.duplicate(),
		"completed": completed,
		"rewarded": rewarded,
	}


func from_dict(data: Dictionary) -> void:
	step_index = clampi(int(data.get("step_index", 0)), 0, maxi(0, steps().size() - 1))
	counters = data.get("counters", {}).duplicate()
	completed = bool(data.get("completed", false))
	rewarded = bool(data.get("rewarded", false))
