class_name Relationships
extends RefCounted
## Who stands where with whom: a directed graph of bonds with thresholds.
##
## Every edge is asymmetric by construction. A thinks something of B, and B
## thinks something else of A — Elder Bai's regard for his student is not the
## same number as the student's regard for him, and neither is derived from the
## other.
##
## Two kinds of edge share one model:
##
##   warmth    a score in -100..100, read through the bands in
##             `data/bonds.json` (enemy, rival, stranger, acquaintance, friend,
##             sworn). The band is what a person calls the bond; the score is
##             what the simulation keeps.
##   tie       a structural relation authored in the same file (mentor/student,
##             kin). A tie is not a number the player can grind down: it is a
##             fact about two people, and it labels the edge even while the
##             warmth band still decides what the person will do.
##
## Relations between residents are derived, never saved: `base_score()` is a
## pure function of the world seed and the ordered pair of stable ids, so the
## town's social fabric regenerates exactly. The player's own standing is the
## exception, and it is already saved as memory (M47): `toward_player()` reads
## base temperament plus earned regard, which keeps one source of truth.

## Every generated edge comes from this stream, keyed by both ids in order.
const BOND_DOMAIN := "npc_bond"
const BASE_MIN := -8
const BASE_MAX := 8
const MIN_SCORE := -100
const MAX_SCORE := 100
## The node standing for the person holding the controller.
const PLAYER_ID := "player"
## Bands with behaviour attached. Data owns the thresholds; these names are the
## vocabulary the code reasons about.
const ENEMY_BAND := "bond.enemy"
const FRIEND_BAND := "bond.friend"
const SWORN_BAND := "bond.sworn"


# ---------------------------------------------------------------- warmth ----


## The band whose range contains this score. Out-of-range input is clamped, so a
## corrupt or extreme number still reads as the edge of the table.
static func band_for(score: int) -> Dictionary:
	var value := clampi(score, MIN_SCORE, MAX_SCORE)
	for entry in DB.bonds:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var band: Dictionary = entry
		if value >= int(band.get("min", 0)) and value <= int(band.get("max", 0)):
			return band
	return DB.bond("bond.stranger")


static func band_id(score: int) -> String:
	return String(band_for(score).get("id", ""))


static func label(score: int) -> String:
	return String(band_for(score).get("label", "Stranger"))


static func blurb(score: int) -> String:
	return String(band_for(score).get("blurb", ""))


## What a body does when the player walks up, in a band. The callers add a
## greeting only for a band that has one; an empty answer means no flourish.
static func greeting(band: String) -> String:
	return String(DB.bond(band).get("greeting", ""))


## "Friend (+32)" — the one-line form the dossier and tests read.
static func describe(score: int) -> String:
	return "%s (%+d)" % [label(score), clampi(score, MIN_SCORE, MAX_SCORE)]


## A resident this warm will call out a warning rather than watch the player
## walk into trouble.
static func warns(score: int) -> bool:
	var band := band_id(score)
	return band == FRIEND_BAND or band == SWORN_BAND


## A resident this cold will not hold a conversation at all.
static func refuses(score: int) -> bool:
	return band_id(score) == ENEMY_BAND


# ------------------------------------------------------------------ ties ----


static func tie(id: String) -> Dictionary:
	return DB.bond_tie(id)


static func reciprocal(tie_id: String) -> String:
	return String(tie(tie_id).get("reciprocal", ""))


## The authored pair edge from `from_id` to `to_id`, or {} when the two are not
## formally bound. A pair is directional: the file names both directions where
## the relation has two names.
static func pair(from_id: String, to_id: String) -> Dictionary:
	return DB.bond_pair(from_id, to_id)


## Every authored tie leaving this person, ready for the dossier.
static func ties_of(id: String) -> Array:
	var out: Array = []
	if id == "":
		return out
	for value in DB.bond_pairs:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var pair_entry: Dictionary = value
		if String(pair_entry.get("from", "")) != id:
			continue
		var link: Dictionary = tie(String(pair_entry.get("tie", "")))
		out.append({
			"to": String(pair_entry.get("to", "")),
			"tie": String(pair_entry.get("tie", "")),
			"tie_label": String(link.get("label", "")),
			"phrase": String(link.get("phrase", "%s of %s")),
			"score": clampi(int(pair_entry.get("score", 0)), MIN_SCORE, MAX_SCORE),
		})
	return out


# ----------------------------------------------------------------- edges ----


## A pair's baseline feeling, before anything the player did. The ordered pair
## is the seed key, so A→B and B→A are different draws, never two halves of one
## symmetric relationship.
static func base_score(from_id: String, to_id: String) -> int:
	if from_id == "" or to_id == "" or from_id == to_id:
		return 0
	var rng: RandomNumberGenerator = Rng.stream(BOND_DOMAIN, hash(from_id), hash(to_id))
	return rng.randi_range(BASE_MIN, BASE_MAX)


## The resident-to-resident score: an authored tie's own number if the file
## names one, otherwise the seeded baseline.
static func score_between(from_id: String, to_id: String) -> int:
	var pair_entry := pair(from_id, to_id)
	if pair_entry.is_empty():
		return base_score(from_id, to_id)
	return clampi(int(pair_entry.get("score", 0)), MIN_SCORE, MAX_SCORE)


## The complete directed edge. `band` stays the warmth band even when a tie
## gives the edge its name, so behaviour and description never disagree.
static func edge(from_id: String, to_id: String) -> Dictionary:
	var score := score_between(from_id, to_id)
	var band := band_for(score)
	var pair_entry := pair(from_id, to_id)
	var tie_id := String(pair_entry.get("tie", ""))
	var link: Dictionary = tie(tie_id)
	var name := String(band.get("label", ""))
	var text := String(band.get("blurb", ""))
	if not link.is_empty():
		name = String(link.get("label", name))
		text = String(link.get("blurb", text))
	return {
		"from": from_id,
		"to": to_id,
		"score": score,
		"band": String(band.get("id", "")),
		"label": name,
		"blurb": text,
		"tie": tie_id,
		"tie_label": String(link.get("label", "")),
		"greeting": String(band.get("greeting", "")),
	}


## What one person feels about the player. The saved half is memory; this only
## reads it, so the relationship layer cannot drift out of step with M47.
static func toward_player(disposition: int, regard: int) -> Dictionary:
	var score := clampi(disposition + regard, MIN_SCORE, MAX_SCORE)
	var band := band_for(score)
	return {
		"from": "",
		"to": PLAYER_ID,
		"score": score,
		"band": String(band.get("id", "")),
		"label": String(band.get("label", "Stranger")),
		"blurb": String(band.get("blurb", "")),
		"tie": "",
		"tie_label": "",
		"greeting": String(band.get("greeting", "")),
	}


## The whole fabric in one pass: from id → to id → edge. Built on demand from
## the seed, never stored.
static func graph(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for from_value in ids:
		var from_id := String(from_value)
		if from_id == "":
			continue
		var row: Dictionary = {}
		for to_value in ids:
			var to_id := String(to_value)
			if to_id == "" or to_id == from_id:
				continue
			row[to_id] = edge(from_id, to_id)
		out[from_id] = row
	return out


# ------------------------------------------------------------ validation ----


## Content checks for `data/bonds.json`. Bands must tile -100..100 with no gap
## and no overlap: a score with two names, or none, is a bug that would only
## surface as a person who cannot decide how they feel.
static func validate(bands: Array, ties: Array, pairs: Array) -> Array:
	var problems: Array = []
	if bands.is_empty():
		problems.append("no relationship bands defined")
		return problems

	var seen_bands: Dictionary = {}
	var ranges: Array = []
	for value in bands:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("relationship band is not an object")
			continue
		var band: Dictionary = value
		var id := String(band.get("id", ""))
		if id == "":
			problems.append("relationship band without id")
			continue
		if seen_bands.has(id):
			problems.append("duplicate relationship band id " + id)
		seen_bands[id] = true
		if String(band.get("label", "")) == "":
			problems.append("relationship band %s has no label" % id)
		if String(band.get("blurb", "")) == "":
			problems.append("relationship band %s has no blurb" % id)
		if String(band.get("greeting", "")) == "":
			problems.append("relationship band %s has no greeting" % id)
		var low := int(band.get("min", MAX_SCORE + 1))
		var high := int(band.get("max", MIN_SCORE - 1))
		if low > high or low < MIN_SCORE or high > MAX_SCORE:
			problems.append("relationship band %s has a range outside %d..%d" % [id, MIN_SCORE, MAX_SCORE])
			continue
		ranges.append({"id": id, "min": low, "max": high})

	ranges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("min", 0)) < int(b.get("min", 0)))
	var cursor := MIN_SCORE
	for value in ranges:
		var range_row: Dictionary = value
		var low := int(range_row.get("min", 0))
		if low > cursor:
			problems.append("relationship bands leave a gap at %d" % cursor)
		elif low < cursor:
			problems.append("relationship bands overlap at %d" % low)
		cursor = maxi(cursor, int(range_row.get("max", 0)) + 1)
	if cursor != MAX_SCORE + 1:
		problems.append("relationship bands stop at %d, not %d" % [cursor - 1, MAX_SCORE])

	var seen_ties: Dictionary = {}
	for value in ties:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("relationship tie is not an object")
			continue
		var link: Dictionary = value
		var id := String(link.get("id", ""))
		if id == "":
			problems.append("relationship tie without id")
			continue
		if seen_ties.has(id):
			problems.append("duplicate relationship tie id " + id)
		seen_ties[id] = link
		if String(link.get("label", "")) == "":
			problems.append("relationship tie %s has no label" % id)
		# A phrase names the other person, once: "Mentor of %s".
		if String(link.get("phrase", "")).count("%s") != 1:
			problems.append("relationship tie %s must name the other person once" % id)
		if String(link.get("reciprocal", "")) == "":
			problems.append("relationship tie %s names no reciprocal" % id)
	for tie_id in seen_ties.keys():
		var link: Dictionary = seen_ties[tie_id]
		var other := String(link.get("reciprocal", ""))
		if other == "":
			continue
		if not seen_ties.has(other):
			problems.append("relationship tie %s names unknown reciprocal %s" % [String(tie_id), other])
			continue
		if String((seen_ties[other] as Dictionary).get("reciprocal", "")) != String(tie_id):
			problems.append("relationship tie %s and %s do not agree on each other" % [String(tie_id), other])

	var seen_pairs: Dictionary = {}
	for value in pairs:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("relationship pair is not an object")
			continue
		var pair_entry: Dictionary = value
		var from_id := String(pair_entry.get("from", ""))
		var to_id := String(pair_entry.get("to", ""))
		if from_id == "" or to_id == "":
			problems.append("relationship pair without two names")
			continue
		if from_id == to_id:
			problems.append("relationship pair names %s twice" % from_id)
			continue
		var key := from_id + ">" + to_id
		if seen_pairs.has(key):
			problems.append("duplicate relationship pair " + key)
		seen_pairs[key] = true
		if not seen_ties.has(String(pair_entry.get("tie", ""))):
			problems.append("relationship pair %s names unknown tie %s" % [key, String(pair_entry.get("tie", ""))])
		var score := int(pair_entry.get("score", MAX_SCORE + 1))
		if score < MIN_SCORE or score > MAX_SCORE:
			problems.append("relationship pair %s has a score outside %d..%d" % [key, MIN_SCORE, MAX_SCORE])
	return problems
