class_name WorldLighting
extends CanvasModulate
## Day/night lighting.
##
## `CanvasModulate` tints the whole canvas from the world clock, and point lights
## mark the settlements' landmarks at night: the shrine, the rift, the realm
## altar. Light energy is a pure function of the hour, so night is not merely a
## colour change — sources actually switch on.
##
## The math lives in static functions; the node only applies it.

const DAY_START := 7.0
const DAY_END := 17.0
const DUSK_END := 20.0

var lights: Array = []
var _texture: GradientTexture2D


func _ready() -> void:
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Re-applies the ambient tint and light energy for the current hour.
func refresh() -> void:
	var ambient := Climate.lighting_modulate(Clock.ambient_for_hour(Clock.hour), Weather.current)
	var flash := Weather.flash_strength()
	if flash > 0.0:
		ambient = ambient.lightened(flash * 0.35)
	color = ambient
	var energy := light_energy_for_hour(Clock.hour)
	var live: Array = []
	for light in lights:
		if is_instance_valid(light):
			light.energy = energy * float(light.get_meta("base_energy", 1.0))
			live.append(light)
	lights = live


## Adds a point light under `parent`, returning it.
func add_light(parent: Node, world_position: Vector2, light_color: Color, radius: float,
		base_energy: float = 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = radial_texture()
	light.color = light_color
	light.texture_scale = maxf(0.05, radius / 128.0)
	light.energy = base_energy
	light.set_meta("base_energy", base_energy)
	parent.add_child(light)
	light.global_position = world_position
	lights.append(light)
	refresh()
	return light


## How strongly point lights burn at a given hour: off through the day, ramping
## through dusk, full from late evening until dawn, fading out at sunrise.
static func light_energy_for_hour(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= DAY_START and h < DAY_END:
		return 0.0
	if h >= DAY_END and h < DUSK_END:
		return clampf((h - DAY_END) / (DUSK_END - DAY_END), 0.0, 1.0)
	if h >= DUSK_END or h < 5.0:
		return 1.0
	return clampf(1.0 - (h - 5.0) / (DAY_START - 5.0), 0.0, 1.0)


## Radial falloff shared by every point light; generated because the project
## ships no art assets.
static func radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture
