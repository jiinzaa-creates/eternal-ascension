class_name NpcAi
extends RefCounted
## The resident's mind: what a person notices, how hard their nerve is, and what
## they do about it.
##
## M48 gave every body a routine. A routine is a plan for an ordinary hour; this
## layer is what happens when the hour stops being ordinary. Nothing here moves a
## node or reads the scene tree: `nearest_threat()` answers what is in reach,
## `decide()` answers what the trade does about it, and the body carries out the
## order. That is what makes a panicking town testable headlessly.
##
## An archetype carries an `ai` block in `data/npcs.json`:
##
##   nerve       0..1, how steady the body is when something hostile arrives
##   alert_range how far the body notices a threat at all
##   response    `confront`, `flee` or `shelter`
##   refuge      a settlement location to run to, for flee and shelter
##   shout       whether the reaction raises the alarm for neighbours
##
## Nerve is not courage in the abstract: a body only holds its ground on a
## `confront` order if its nerve clears `CONFRONT_NERVE`. A frightened guard
## falls back to shelter, which is why the same archetype can behave differently
## when the data is tuned.

const RESPONSES: Array[String] = ["confront", "flee", "shelter"]

## How long one shout keeps a neighbourhood alarmed. Every reaction is refreshed
## by the threat itself, so this is only the tail after the danger is gone.
const ALARM_SECONDS := 12.0
## How far one voice carries through the market.
const SHOUT_RADIUS := 340.0
## A body below this nerve does not stand its ground, whatever its trade says.
const CONFRONT_NERVE := 0.55
## How close a confronting body closes before it holds the line.
const CONFRONT_GAP := 96.0
## Only threats this close to the market count as the settlement's problem. Wild
## bodies spawn at 420+ and are the player's business until they come in.
const WATCH_RADIUS := 360.0

const DEFAULTS := {
	"nerve": 0.5,
	"alert_range": 260.0,
	"response": "shelter",
	"refuge": "sect_hall",
	"shout": true,
}


## A complete, clamped AI block. A missing or malformed field takes its default,
## so an old archetype degrades to a cautious resident instead of crashing.
static func profile(entry: Dictionary) -> Dictionary:
	var out: Dictionary = (DEFAULTS as Dictionary).duplicate(true)
	for key in out.keys():
		if entry.has(key):
			out[key] = entry[key]
	out["nerve"] = clampf(float(out.get("nerve", 0.5)), 0.0, 1.0)
	out["alert_range"] = clampf(float(out.get("alert_range", 260.0)), 40.0, 900.0)
	var response := String(out.get("response", "shelter"))
	out["response"] = response if RESPONSES.has(response) else "shelter"
	out["refuge"] = String(out.get("refuge", "sect_hall"))
	out["shout"] = bool(out.get("shout", true))
	return out


## The closest hostile body inside the settlement's watch ring and the person's
## own alert range, or an empty dictionary. Entries are `{id, position}`.
static func nearest_threat(origin: Vector2, threats: Array, radius: float) -> Dictionary:
	if threats.is_empty() or radius <= 0.0:
		return {}
	var best: Dictionary = {}
	var best_distance := radius
	for value in threats:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var threat: Dictionary = value
		var where: Variant = threat.get("position", null)
		if typeof(where) != TYPE_VECTOR2:
			continue
		var distance := origin.distance_to(where)
		if distance <= best_distance:
			best_distance = distance
			best = {
				"id": String(threat.get("id", "")),
				"position": where,
				"distance": distance,
			}
	return best


## Filters a list of bodies down to the ones inside the market's watch ring.
## The scene feeds this to `nearest_threat`, so a beast in the wilds is nobody's
## alarm until it walks in.
static func watched(threats: Array, center: Vector2, radius: float = WATCH_RADIUS) -> Array:
	var out: Array = []
	for value in threats:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var where: Variant = (value as Dictionary).get("position", null)
		if typeof(where) != TYPE_VECTOR2:
			continue
		if center.distance_to(where) <= maxf(0.0, radius):
			out.append(value)
	return out


## The order a body follows. Seeing a threat beats merely hearing about one, and
## a faint-hearted body ordered to stand its ground takes shelter instead.
static func decide(visible: bool, alarmed: bool, profile_in: Dictionary) -> String:
	if not visible and not alarmed:
		return "routine"
	var response := String(profile_in.get("response", "shelter"))
	if response == "confront" and float(profile_in.get("nerve", 0.0)) < CONFRONT_NERVE:
		return "shelter"
	return response


## Whether a shout from one body reaches another.
static func hears(shouter: Vector2, listener: Vector2, radius: float = SHOUT_RADIUS) -> bool:
	return shouter.distance_to(listener) <= maxf(0.0, radius)


## Where a reaction sends the body. A confronting body closes to the hold gap on
## the line between itself and the threat; a fleeing or sheltering body runs to
## its refuge. A routine body has no reaction target and stays where it is.
static func target_for(reaction: String, origin: Vector2, threat_position: Vector2,
		refuge_position: Vector2, profile_in: Dictionary) -> Vector2:
	match reaction:
		"confront":
			return approach_point(origin, threat_position, hold_at(reaction, profile_in))
		"flee", "shelter":
			return refuge_position
	return origin


## A point `gap` away from the threat, on the threat's side of the body. A body
## already inside the gap holds where it stands rather than backing through it.
static func approach_point(origin: Vector2, threat_position: Vector2, gap: float) -> Vector2:
	var offset := origin - threat_position
	var distance := offset.length()
	if distance <= maxf(0.0, gap) or distance < 0.001:
		return origin
	return threat_position + offset / distance * maxf(0.0, gap)


## The distance a body keeps from the threat while reacting. Only a confronting
## body holds a line; everyone else is trying to leave.
static func hold_at(reaction: String, _profile_in: Dictionary) -> float:
	if reaction == "confront":
		return CONFRONT_GAP
	return 0.0


static func label(reaction: String) -> String:
	match reaction:
		"confront":
			return "Standing ground"
		"flee":
			return "Fleeing"
		"shelter":
			return "Taking shelter"
	return "About their business"


## A short tag for the nameplate, where there is no room for a sentence.
static func short_label(reaction: String) -> String:
	match reaction:
		"confront":
			return "alarmed"
		"flee":
			return "fleeing"
		"shelter":
			return "sheltering"
	return ""


## The dossier line while a reaction lasts. Distance is in world units, read as
## paces so the number is a fact about the body rather than a coordinate.
static func describe(reaction: String, threat_distance: float) -> String:
	if reaction == "routine":
		return ""
	var paces := int(maxf(0.0, threat_distance) / 10.0)
	match reaction:
		"confront":
			return "Standing ground — a threat %d paces off" % paces
		"flee":
			return "Fleeing — a threat %d paces off" % paces
		"shelter":
			return "Taking shelter — a threat %d paces off" % paces
	return ""


## What an alarmed body says instead of small talk. The line is the reaction, not
## the personality: a body taking shelter does not stop for a chat.
static func warning_line(reaction: String) -> String:
	match reaction:
		"confront":
			return "Get behind me. Whatever that is, it does not cross this ground."
		"flee":
			return "Run — do not stand there gawping!"
		"shelter":
			return "Inside, now. The door shuts behind us."
	return ""


## Nerves read as words in the dossier, so a resident's temperament is legible
## before anything hostile turns up.
static func nerve_label(nerve: float) -> String:
	if nerve >= 0.8:
		return "steady"
	if nerve >= 0.5:
		return "even"
	if nerve >= 0.3:
		return "uneasy"
	return "timid"
