class_name SectPolitics
extends RefCounted
## The Azure Cloud's council: three blocs, their support, and the vote that can
## open the master's seat.
##
## Support is bought with contribution, not with a second currency: the same
## service points M58 pays for a quest or a donation are what a bloc wants. Every
## function is pure; the screen owns the contribution and the saved investment
## map, so a refused lobby can never spend anything.

const EXPECTED_BLOCS := 3
const DEFAULT_THRESHOLD := 150


# ------------------------------------------------------------------ data ----


static func data() -> Dictionary:
	return DB.politics_data


static func blocs() -> Array:
	var value: Variant = data().get("blocs", [])
	return value if typeof(value) == TYPE_ARRAY else []


## One council per house. Azure Cloud's is authored; every other sect's
## council carries the same three blocs and the same numbers — only the
## speakers and the grievance change, drawn from the house's own fault
## line, so the lobby and vote math never forks.
static func blocs_for(sect_id: String) -> Array:
	if sect_id == String(Sects.local_sect().get("id", "")):
		return blocs()
	var sect := Sects.sect(sect_id)
	if sect.is_empty():
		return []
	var speakers := {
		"bloc.traditionalists": String(sect.get("master", "")),
		"bloc.reformists": String(sect.get("deputy", "")),
		"bloc.militants": "The senior guardian",
	}
	var out: Array = []
	for value in blocs():
		var entry: Dictionary = (value as Dictionary).duplicate()
		entry["speaker"] = String(speakers.get(String(entry.get("id", "")), entry.get("speaker", "")))
		entry["agenda"] = String(sect.get("fault_line", ""))
		out.append(entry)
	return out


static func bloc(id: String) -> Dictionary:
	for value in blocs():
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == id:
			return value
	return {}


static func vote_rules() -> Dictionary:
	var value: Variant = data().get("vote", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func threshold() -> int:
	return maxi(1, int(vote_rules().get("threshold", DEFAULT_THRESHOLD)))


static func min_rank() -> String:
	return String(vote_rules().get("min_rank", "rank.deputy"))


# --------------------------------------------------------------- support ----


static func invested(invested_map: Dictionary, bloc_id: String) -> int:
	return maxi(0, int(invested_map.get(bloc_id, 0)))


## A bloc's support: its standing base plus every point the player has put into
## it, capped at the bloc's own ceiling. Investing past the cap is refused, so a
## saved map never carries wasted points.
static func support_for(bloc_id: String, invested_map: Dictionary) -> int:
	var entry := bloc(bloc_id)
	if entry.is_empty():
		return 0
	var base := maxi(0, int(entry.get("base", 0)))
	var ceiling := maxi(base, int(entry.get("max", base)))
	return clampi(base + invested(invested_map, bloc_id), 0, ceiling)


static func max_for(bloc_id: String) -> int:
	return maxi(0, int(bloc(bloc_id).get("max", 0)))


static func total_support(invested_map: Dictionary) -> int:
	var total := 0
	for value in blocs():
		if typeof(value) == TYPE_DICTIONARY:
			total += support_for(String((value as Dictionary).get("id", "")), invested_map)
	return total


static func max_support() -> int:
	var total := 0
	for value in blocs():
		if typeof(value) == TYPE_DICTIONARY:
			total += max_for(String((value as Dictionary).get("id", "")))
	return total


static func summary_line(invested_map: Dictionary) -> String:
	return "Council support %d / %d" % [total_support(invested_map), threshold()]


# --------------------------------------------------------------- actions ----


## Buying a bloc's favour. Contribution is spent only when the whole cost is
## there and the bloc still has room under its ceiling.
static func lobby(bloc_id: String, contribution: int, invested_map: Dictionary) -> Dictionary:
	var out := {
		"ok": false,
		"reason": "",
		"contribution": maxi(0, contribution),
		"invested": invested_map.duplicate(true),
		"gain": 0,
		"support": 0,
	}
	var entry := bloc(bloc_id)
	if entry.is_empty():
		out["reason"] = "unknown council bloc"
		return out
	var cost := maxi(0, int(entry.get("cost", 0)))
	if contribution < cost:
		out["reason"] = "not enough contribution"
		return out
	var current := invested(invested_map, bloc_id)
	var ceiling := maxi(0, max_for(bloc_id) - maxi(0, int(entry.get("base", 0))))
	if current >= ceiling:
		out["reason"] = "this bloc already stands with you"
		return out
	var gain := mini(maxi(1, int(entry.get("gain", 1))), ceiling - current)
	out["ok"] = true
	out["contribution"] = contribution - cost
	out["invested"] = invested_map.duplicate(true)
	out["invested"][bloc_id] = current + gain
	out["gain"] = gain
	out["support"] = support_for(bloc_id, out["invested"])
	return out


## Whether the council can be called at all. The seat must still be held, the
## player must stand at the minimum rank, and the blocs must already be with them;
## a vote that cannot pass is never put to the hall.
static func can_vote(invested_map: Dictionary, rank_id: String, seat_open: bool) -> Dictionary:
	var out := {"ok": false, "reason": "", "support": total_support(invested_map),
		"threshold": threshold()}
	if seat_open:
		out["reason"] = "the master's seat already stands open"
		return out
	if Hierarchy.level(rank_id) < Hierarchy.level(min_rank()):
		out["reason"] = "only a %s may call the vote" % Hierarchy.title(min_rank())
		return out
	if int(out["support"]) < threshold():
		out["reason"] = "the council stands at %d of %d" % [int(out["support"]), threshold()]
		return out
	out["ok"] = true
	return out


## The vote itself. A successful call opens the seat for good; the player still
## has to meet the top rung's own standing and realm gates to sit in it.
static func vote(invested_map: Dictionary, rank_id: String, seat_open: bool) -> Dictionary:
	var check := can_vote(invested_map, rank_id, seat_open)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": String(check.get("reason", "")), "support": int(check.get("support", 0)),
			"seat_open": seat_open}
	return {"ok": true, "reason": "", "support": total_support(invested_map), "seat_open": true}


## Loaded lobbies are cleaned against the current data: unknown blocs disappear,
## values clamp to what the bloc can accept, and junk is dropped rather than
## carried into a screen.
static func sanitize_lobby(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = value
	for bloc_value in blocs():
		if typeof(bloc_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = bloc_value
		var id := String(entry.get("id", ""))
		if id == "" or not source.has(id):
			continue
		var room := maxi(0, max_for(id) - maxi(0, int(entry.get("base", 0))))
		var amount := clampi(int(source.get(id, 0)), 0, room)
		if amount > 0:
			out[id] = amount
	return out


# ------------------------------------------------------------- validation ----


static func validate(data: Dictionary) -> Array:
	var problems: Array = []
	if data.is_empty():
		problems.append("no sect politics data defined")
		return problems

	var bloc_list: Variant = data.get("blocs", null)
	if typeof(bloc_list) != TYPE_ARRAY or (bloc_list as Array).is_empty():
		problems.append("sect council blocs are missing")
		return problems
	var rows: Array = bloc_list
	if rows.size() != EXPECTED_BLOCS:
		problems.append("expected %d council blocs, found %d" % [EXPECTED_BLOCS, rows.size()])
	var seen: Dictionary = {}
	var base_total := 0
	var max_total := 0
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			problems.append("council bloc is not an object")
			continue
		var entry: Dictionary = value
		var id := String(entry.get("id", ""))
		if id == "":
			problems.append("council bloc without id")
			continue
		if seen.has(id):
			problems.append("duplicate council bloc " + id)
		seen[id] = true
		if String(entry.get("name", "")).strip_edges() == "":
			problems.append("council bloc %s has no name" % id)
		if String(entry.get("speaker", "")).strip_edges() == "":
			problems.append("council bloc %s has no speaker" % id)
		if String(entry.get("agenda", "")).strip_edges() == "":
			problems.append("council bloc %s has no agenda" % id)
		var base := int(entry.get("base", -1))
		var ceiling := int(entry.get("max", -1))
		if base < 0:
			problems.append("council bloc %s has negative base support" % id)
		if ceiling <= base:
			problems.append("council bloc %s cannot gain support" % id)
		if ceiling > 100:
			problems.append("council bloc %s exceeds 100 support" % id)
		if base >= 0 and ceiling > base:
			base_total += base
			max_total += ceiling
		if int(entry.get("gain", 0)) < 1:
			problems.append("council bloc %s buys no support" % id)
		if int(entry.get("cost", 0)) < 1:
			problems.append("council bloc %s costs no contribution" % id)

	var vote_value: Variant = data.get("vote", null)
	if typeof(vote_value) != TYPE_DICTIONARY:
		problems.append("council vote rules are missing")
	else:
		var vote_table: Dictionary = vote_value
		var need := int(vote_table.get("threshold", 0))
		if need < 1:
			problems.append("council vote has no threshold")
		elif need > max_total:
			problems.append("council vote cannot be won with the blocs as written")
		elif need <= base_total:
			problems.append("council vote passes without any lobbying")
		var rank_id := String(vote_table.get("min_rank", ""))
		if Hierarchy.rank(rank_id).is_empty() or Hierarchy.level(rank_id) < 0:
			problems.append("council vote names unknown rank %s" % rank_id)

	return problems
