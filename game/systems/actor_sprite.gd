class_name ActorSprite
extends Sprite2D
## Texture renderer for one actor, fed by the Art Studio sets under
## res://assets/art-studio/assets/.
##
## The pose Animator still owns the motion: this node only swaps frames and
## mirrors the pose transform (bob, lean, squash) the code-drawn body used,
## so a textured actor moves exactly like the primitive it replaces. Frames
## are never flipped — asymmetric designs ship all eight directions.
##
## Fallback chain, per the studio brief: a missing frame falls back to the
## set's idle frame for that direction, then to idle south; if a set has no
## idle south at all the component goes inactive and the entity keeps its
## code-drawn body. `art_studio/use_sprites` (default true) turns the whole
## layer off without touching entity code.

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const RATES := {"walk": 7.0, "run": 10.0, "sprint": 13.0}

var _base := ""
var _key := ""
var _cache := {}
var _stride: Array = ["left", "right"]
var _centre_anchored := false
var _scale_base := 1.0
var _active := false
var _warned := false
var _facing := Vector2.DOWN
var _hair_base := ""
var _skin_base := ""
var _hair_sprite: Sprite2D
var _skin_sprite: Sprite2D


static func sprites_enabled() -> bool:
	return bool(ProjectSettings.get_setting("art_studio/use_sprites", true))


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	_skin_sprite = Sprite2D.new()
	_skin_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skin_sprite.visible = false
	add_child(_skin_sprite)
	_hair_sprite = Sprite2D.new()
	_hair_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hair_sprite.visible = false
	add_child(_hair_sprite)


## Points the component at a frame set. `base_path` is the shared stem, e.g.
## ".../player_founder" for player_founder_idle_s.png. Reconfiguring with
## the same effective key is a no-op, so callers may refresh freely.
func configure(base_path: String, frame_size: float = 64.0, stride: Array = ["left", "right"],
		scale_factor: float = 1.0, tint: Color = Color.WHITE, centre_anchored: bool = false,
		hair_base: String = "", skin_base: String = "") -> void:
	var key := "%s|%f|%s|%f|%s|%s|%s|%s" % [base_path, frame_size, str(stride),
		scale_factor, tint.to_html(), str(centre_anchored), hair_base, skin_base]
	if key == _key:
		return
	_key = key
	_base = base_path
	_cache.clear()
	_stride = stride
	_centre_anchored = centre_anchored
	_scale_base = scale_factor
	self_modulate = tint
	_hair_base = hair_base
	_skin_base = skin_base
	offset = Vector2(0.0, 0.0) if centre_anchored else Vector2(0.0, -frame_size * 0.5)
	_hair_sprite.offset = offset
	_skin_sprite.offset = offset
	_hair_sprite.self_modulate = tint
	_skin_sprite.self_modulate = tint
	_active = sprites_enabled() and base_path != "" \
		and ResourceLoader.exists(base_path + "_idle_s.png")
	if base_path != "" and sprites_enabled() and not _active and not _warned:
		_warned = true
		push_warning("ActorSprite: no idle_s frame under %s - actor keeps its code-drawn body." % base_path)
	visible = _active
	if _active:
		_apply("idle", _dir_of(_facing), "")


func is_active() -> bool:
	return _active


## Called by the owning entity once per physics tick, right after its
## Animator update. A zero facing keeps the last real one.
func present(facing: Vector2, anim: Animator, speed_ratio: float) -> void:
	if not _active:
		return
	if facing.length() > 0.01:
		_facing = facing
	var dir := _dir_of(_facing)
	var pose := Animator.pose(anim.state, anim.time, speed_ratio)
	position = pose["bob"]
	rotation = float(pose["lean"]) * (1.0 if _facing.x >= 0.0 else -1.0)
	scale = (pose["squash"] as Vector2) * _scale_base
	match anim.state:
		"attack":
			_apply("attack", dir, "")
		"walk", "run", "sprint":
			var swing := sin(anim.time * float(RATES[anim.state]))
			if _stride[0] == "a":
				_apply("walk", dir, _stride[0] if swing >= 0.0 else _stride[1])
			elif swing > 0.5:
				_apply("walk", dir, "left")
			elif swing < -0.5:
				_apply("walk", dir, "right")
			else:
				_apply("idle", dir, "")
		_:
			_apply("idle", dir, "")


static func _dir_of(f: Vector2) -> String:
	var idx := int(floor(f.angle() / (PI * 0.25) + 0.5))
	return DIRS[posmod(idx, 8)]


func _apply(kind: String, dir: String, suffix: String) -> void:
	var key := kind + "_" + dir + ("_" + suffix if suffix != "" else "")
	if _cache.has(key):
		_show(String(_cache[key]))
		return
	var stem := key
	if _frame(_base, stem) == null and kind != "idle":
		stem = "idle_" + dir
	if _frame(_base, stem) == null:
		stem = "idle_s"
	_cache[key] = stem
	_show(stem)


## Shows one resolved frame stem on the body and on both overlays.
## An overlay without that frame simply hides for the frame.
func _show(stem: String) -> void:
	texture = _frame(_base, stem)
	_set_overlay(_skin_sprite, _skin_base, stem)
	_set_overlay(_hair_sprite, _hair_base, stem)


func _set_overlay(spr: Sprite2D, base: String, stem: String) -> void:
	if base == "":
		spr.visible = false
		return
	spr.texture = _frame(base, stem)
	spr.visible = spr.texture != null


func _frame(base: String, stem: String) -> Texture2D:
	var key := "f:" + base + "|" + stem
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	var path := base + "_" + stem + ".png"
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[key] = tex
	return tex
