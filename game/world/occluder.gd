class_name Occluder
extends RefCounted
## Roof occlusion for top-down buildings.
##
## A building in a top-down game hides whatever walks behind its roof. Rather
## than cutting a hole in the art, the building fades while the player is inside
## its footprint or under the sloped roof, and fades back as the player steps
## away. The rule is a pure function so it can be tested without rendering.

const MIN_ALPHA := 0.22
const FADE_MARGIN := 32.0


## The rectangle a building covers, including the roof slope above its base.
static func occlusion_region(footprint: Rect2, roof_height: float) -> Rect2:
	var height := maxf(0.0, roof_height)
	return Rect2(footprint.position - Vector2(0.0, height), footprint.size + Vector2(0.0, height))


## Alpha the building should use for a player at `player_pos`.
##
## Full opacity outside the region plus a margin, `min_alpha` inside it, and a
## linear ramp across the margin so the change is not a hard pop.
static func alpha_for(player_pos: Vector2, footprint: Rect2, roof_height: float,
		min_alpha: float = MIN_ALPHA, margin: float = FADE_MARGIN) -> float:
	var region := occlusion_region(footprint, roof_height)
	if not region.grow(margin).has_point(player_pos):
		return 1.0
	if region.has_point(player_pos):
		return min_alpha
	var distance := _distance_to_rect(region, player_pos)
	return lerpf(min_alpha, 1.0, clampf(distance / maxf(0.001, margin), 0.0, 1.0))


static func _distance_to_rect(rect: Rect2, point: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dy).length()
