class_name Appearance
extends RefCounted
## How a cultivator looks, as palette indices.
##
## The art is code-drawn, so appearance is a handful of palette choices rather than
## textures: robe, hair and skin colours plus a presentation/pronoun line. Indices
## are what get saved, so reordering a palette would change an existing character —
## append to them instead.

const ROBES := ["#3f6fa8", "#7d4a9c", "#3d8a68", "#a8563f", "#4c5560", "#b08b3d"]
const HAIRS := ["#1d1f22", "#3a2a1e", "#6b4a2c", "#c9b48a", "#8b1f1f", "#dcdcdc"]
const SKINS := ["#e6c9a8", "#d6ab84", "#b9865e", "#8d5a3b", "#6a452e"]
const PRESENTATIONS := ["she/her", "he/him", "they/them"]

var robe := 0
var hair := 0
var skin := 0
var presentation := 0


func cycle(field: String, direction: int = 1) -> void:
	match field:
		"robe":
			robe = wrapi(robe + direction, 0, ROBES.size())
		"hair":
			hair = wrapi(hair + direction, 0, HAIRS.size())
		"skin":
			skin = wrapi(skin + direction, 0, SKINS.size())
		"presentation":
			presentation = wrapi(presentation + direction, 0, PRESENTATIONS.size())


func robe_color() -> Color:
	return Color(ROBES[clampi(robe, 0, ROBES.size() - 1)])


func hair_color() -> Color:
	return Color(HAIRS[clampi(hair, 0, HAIRS.size() - 1)])


func skin_color() -> Color:
	return Color(SKINS[clampi(skin, 0, SKINS.size() - 1)])


func pronouns() -> String:
	return String(PRESENTATIONS[clampi(presentation, 0, PRESENTATIONS.size() - 1)])


func label() -> String:
	return "%s · %s · %s · %s" % [
		ROBES[clampi(robe, 0, ROBES.size() - 1)],
		HAIRS[clampi(hair, 0, HAIRS.size() - 1)],
		SKINS[clampi(skin, 0, SKINS.size() - 1)],
		pronouns(),
	]


func to_dict() -> Dictionary:
	return {"robe": robe, "hair": hair, "skin": skin, "presentation": presentation}


## Out-of-range indices are clamped rather than trusted: a hand-edited save should
## never crash a draw call.
func from_dict(data: Dictionary) -> void:
	robe = clampi(int(data.get("robe", 0)), 0, ROBES.size() - 1)
	hair = clampi(int(data.get("hair", 0)), 0, HAIRS.size() - 1)
	skin = clampi(int(data.get("skin", 0)), 0, SKINS.size() - 1)
	presentation = clampi(int(data.get("presentation", 0)), 0, PRESENTATIONS.size() - 1)
