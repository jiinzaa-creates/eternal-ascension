class_name UiFrame
extends RefCounted
## The shared frame language for the code-drawn interface.
##
## The game's UI is drawn in code on purpose (see hud.gd); this class is
## that drawing's grammar, in one place so every panel speaks it: an ink
## fill, a bronze rule, a jade hairline inside, and bronze corner ticks —
## the Art Studio UI lock (ink panels, jade/bronze cloud trim, bronze
## plaque buttons, VISUAL_BIBLE §§15/20) expressed with draw calls rather
## than textures. Page panels keep their own accent colour as the main
## rule; the bronze corners are the brand mark that ties them together.

const BRONZE := Color("#b08b3d")
const BRONZE_DIM := Color("#6a5638")
const JADE := Color("#3d8a68")
const EDGE := Color("#2b343a")


## An ambient HUD panel: fill, bronze-dim rule, jade hairline, corners.
static func panel(ci: CanvasItem, rect: Rect2, bg: Color) -> void:
	ci.draw_rect(rect, bg)
	ci.draw_rect(rect, BRONZE_DIM, false, 1.0)
	if rect.size.x > 32.0 and rect.size.y > 32.0:
		ci.draw_rect(rect.grow(-4.0), Color(JADE, 0.25), false, 1.0)
	corners(ci, rect, BRONZE, 10.0, 2.0)


## A full page: the page's own accent stays the rule, bronze corners tie
## it to the family, and a bronze hairline sits just inside the rule.
static func page(ci: CanvasItem, rect: Rect2, bg: Color, accent: Color) -> void:
	ci.draw_rect(rect, bg)
	ci.draw_rect(rect, accent, false, 1.0)
	if rect.size.x > 48.0 and rect.size.y > 48.0:
		ci.draw_rect(rect.grow(-5.0), Color(BRONZE, 0.16), false, 1.0)
	corners(ci, rect, BRONZE, 14.0, 2.5)


## A card inside a page: quieter — fill and a warmed rule.
static func card(ci: CanvasItem, rect: Rect2, bg: Color, _border: Color) -> void:
	ci.draw_rect(rect, bg)
	ci.draw_rect(rect, Color(BRONZE_DIM, 0.65), false, 1.0)


## A small plaque: prompts, banners, menu rows, toasts.
static func plaque(ci: CanvasItem, rect: Rect2, bg: Color, border: Color, width: float = 1.0) -> void:
	ci.draw_rect(rect, bg)
	ci.draw_rect(rect, border, false, width)
	corners(ci, rect, BRONZE, 6.0, 1.5)


## Frame only, no fill (the world map's grid paints its own ground).
static func frame(ci: CanvasItem, rect: Rect2, accent: Color) -> void:
	ci.draw_rect(rect, accent, false, 1.0)
	corners(ci, rect, BRONZE, 14.0, 2.5)


## A section divider: a quiet rule with a bronze heart.
static func divider(ci: CanvasItem, x1: float, x2: float, y: float) -> void:
	ci.draw_line(Vector2(x1, y), Vector2(x2, y), Color(EDGE, 0.8), 1.0)
	var mid := (x1 + x2) * 0.5
	ci.draw_line(Vector2(mid - 12.0, y), Vector2(mid + 12.0, y), BRONZE_DIM, 1.0)


## The corner ticks: little L brackets, the abstracted cloud trim.
static func corners(ci: CanvasItem, rect: Rect2, colour: Color, len_: float, width: float) -> void:
	var p := rect.position
	var e := rect.end
	ci.draw_line(p, p + Vector2(len_, 0.0), colour, width)
	ci.draw_line(p, p + Vector2(0.0, len_), colour, width)
	ci.draw_line(Vector2(e.x, p.y), Vector2(e.x - len_, p.y), colour, width)
	ci.draw_line(Vector2(e.x, p.y), Vector2(e.x, p.y + len_), colour, width)
	ci.draw_line(Vector2(p.x, e.y), Vector2(p.x + len_, e.y), colour, width)
	ci.draw_line(Vector2(p.x, e.y), Vector2(p.x, e.y - len_), colour, width)
	ci.draw_line(e, e + Vector2(-len_, 0.0), colour, width)
	ci.draw_line(e, e + Vector2(0.0, -len_), colour, width)
