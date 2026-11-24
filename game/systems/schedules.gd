class_name Schedules
extends RefCounted
## Daily routines as data: which hour puts a body where, what it is doing, and
## which days the entry applies to.
##
## A schedule is a list of hour ranges. An entry with `days` applies only on
## those weekdays; an entry without one applies every day. Ranges may wrap past
## midnight (22 → 6), which is how sleep works without a special case.
##
## Nothing here moves a node. `resolve()` answers what the routine says at an
## hour, `next_entry()` answers what comes after it, and `validate()` proves a
## schedule covers every hour of every day exactly once. Movement, memory and
## service refusal are the callers' business.

const WEEK_LENGTH := 7

## The verbs a schedule may use, in the form the HUD reads.
const ACTIVITY_LABELS := {
	"idle": "idle",
	"sleep": "asleep",
	"meditate": "meditating",
	"train": "training",
	"teach": "teaching",
	"sell": "selling",
	"shop": "trading",
	"patrol": "patrolling",
	"socialize": "socialising",
	"cultivate": "cultivating",
	"work": "working",
}

## One line of character per activity, so an NPC's greeting is a fact about its
## routine rather than a fixed sentence.
const SMALL_TALK := {
	"meditate": "The Qi is quiet today. Sit, if you have the patience.",
	"train": "Hold the stance. A blade that shakes is a blade that misses.",
	"teach": "Ask quickly; the hall keeps its hours.",
	"sell": "Fair prices, weighed honestly. Look, but do not touch the good rack.",
	"shop": "Everything has a price, including curiosity.",
	"patrol": "Move along. The gate keeps its own hours.",
	"socialize": "Have you eaten? There is always room at the long table.",
	"cultivate": "The sect's Qi is thin this hour. Even so, we sit.",
	"work": "Rain, sun, or tribulation — the field still wants tending.",
	"sleep": "…",
}


## Whether an entry is part of a given weekday's routine.
static func applies(entry: Dictionary, weekday: int) -> bool:
	var days: Variant = entry.get("days", null)
	if typeof(days) != TYPE_ARRAY or (days as Array).is_empty():
		return true
	for value in days:
		if int(value) == weekday:
			return true
	return false


## Whether an entry owns an hour. `from` is inclusive, `to` exclusive, and a
## range whose end is before its start wraps past midnight.
static func active_at(entry: Dictionary, hour: int) -> bool:
	var from := int(entry.get("from", 0))
	var to := int(entry.get("to", 24))
	if from <= to:
		return hour >= from and hour < to
	return hour >= from or hour < to


## The entry in force at an hour, or an empty dictionary if the routine has a
## gap. A later entry never wins over an earlier one: validation forbids
## overlaps, so array order cannot change the answer.
static func resolve(entries: Array, hour: int, weekday: int) -> Dictionary:
	for value in entries:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if not applies(entry, weekday):
			continue
		if active_at(entry, hour):
			return entry
	return {}


## What the routine does after the current entry ends. This is what lets the HUD
## say "until 17:00" and "next: socialising" without hard-coding any schedule.
static func next_entry(entries: Array, hour: int, weekday: int) -> Dictionary:
	var current := resolve(entries, hour, weekday)
	if current.is_empty():
		for step in range(1, WEEK_LENGTH * 24 + 1):
			var probe_day := (weekday + int(float(hour + step) / 24.0)) % WEEK_LENGTH
			var probe := resolve(entries, (hour + step) % 24, probe_day)
			if not probe.is_empty():
				return probe
		return {}
	var end_hour := int(current.get("to", 24))
	var next_day := weekday
	if end_hour >= 24 or end_hour <= hour:
		next_day = (weekday + 1) % WEEK_LENGTH
	return resolve(entries, posmod(end_hour, 24), next_day)


## Proves a schedule is complete: every hour of every day has exactly one owner,
## every location exists, and every day filter is a real weekday.
static func validate(entries: Array, name: String, locations: Array) -> Array:
	var problems: Array = []
	if entries.is_empty():
		problems.append("schedule %s is empty" % name)
		return problems
	var parsed: Array = []
	for value in entries:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("schedule %s has a non-object entry" % name)
			continue
		var entry: Dictionary = value
		var from := int(entry.get("from", -1))
		var to := int(entry.get("to", -1))
		if from < 0 or from > 24 or to < 0 or to > 24 or from == to:
			problems.append("schedule %s has an invalid hour range %d-%d" % [name, from, to])
			continue
		var location := String(entry.get("location", ""))
		if not locations.has(location):
			problems.append("schedule %s names unknown location %s" % [name, location])
		if String(entry.get("activity", "")) == "":
			problems.append("schedule %s has an entry without an activity" % name)
		var day_set: Array = []
		var days: Variant = entry.get("days", null)
		if typeof(days) == TYPE_ARRAY:
			for value_day in days:
				var day := int(value_day)
				if day < 0 or day >= WEEK_LENGTH:
					problems.append("schedule %s has an invalid weekday %d" % [name, day])
				elif day_set.has(day):
					problems.append("schedule %s repeats weekday %d" % [name, day])
				else:
					day_set.append(day)
		elif days != null:
			problems.append("schedule %s has a malformed day filter" % name)
		parsed.append({"entry": entry, "days": day_set})

	for weekday in WEEK_LENGTH:
		for hour in 24:
			var owners := 0
			for row in parsed:
				var day_set: Array = row["days"]
				if not day_set.is_empty() and not day_set.has(weekday):
					continue
				if active_at(row["entry"], hour):
					owners += 1
			if owners != 1:
				problems.append("schedule %s has %d owners on weekday %d at hour %02d" % [name, owners, weekday, hour])
	return problems


static func activity_label(activity: String) -> String:
	return String(ACTIVITY_LABELS.get(activity, activity))


## "Meditating at the shrine until 09:00"
static func describe(activity: String, location: String, until_hour: int) -> String:
	var label := activity_label(activity).capitalize()
	var place := location.replace("_", " ")
	if place == "":
		return label
	return "%s at the %s until %02d:00" % [label, place, posmod(until_hour, 24)]


static func small_talk(activity: String) -> String:
	return String(SMALL_TALK.get(activity, "The Qi is thin today."))


## A sleeping body cannot hold a conversation, buy, sell or teach.
static func awake(activity: String) -> bool:
	return activity != "sleep"


## The sword instructor teaches in the yard, in the morning training block, and
## nowhere else. Location and activity both come from the routine, not a flag.
static func can_teach(location: String, activity: String) -> bool:
	return activity == "train" and location == "training"
