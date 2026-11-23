class_name Player
extends CharacterBody2D
## The player character.
##
## Combat is frame-based (60 Hz) and data-driven: every attack reads startup,
## active and recovery frames from its technique, so animation timing and combat
## timing are the same data. Stats never bypass the frame windows — they scale
## damage, speed and recovery, not the rules.
##
## Every derived number comes from StatBlock, which aggregates attributes,
## equipment affixes, passives and the realm multiplier in a fixed order.

const RADIUS := 14.0
const BASE_HP := 80.0
const DODGE_SPEED := 520.0
const CRIT_MULTIPLIER := 1.8

var display_name := "Wanderer"
var attrs: Attributes
var stats: StatBlock
var cultivation: Cultivation

var passives: Array = []
var inventory: Array = []
var equipment: Dictionary = {}
var technique_ids: Array = []
var selected_technique: int = 0

var hp: float = 100.0
var hp_max: float = 100.0
var spawn_point := Vector2.ZERO

var _attack_state := "idle"  # idle | startup | active | recovery
var _attack_timer := 0.0
var _current_technique: Dictionary = {}
var _cooldown := 0.0
var _dodge_timer := 0.0
var _dodge_cooldown := 0.0
var _iframes := 0.0
var _meditating := false
var _facing := Vector2.RIGHT
var _arc_flash := 0.0
var _arc_radius := 70.0
var _arc_angle := TAU
var _hurt_flash := 0.0
var _hud_timer := 0.0
var _peak_notified := false
var _attack_counter := 0


func _ready() -> void:
	attrs = Attributes.new()
	stats = StatBlock.new(attrs)
	cultivation = Cultivation.new()
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	Game.player = self
	for tech in DB.techniques:
		if not bool(tech.get("hidden", false)):
			technique_ids.append(String(tech.get("id", "")))
	spawn_point = global_position
	rebuild_stats()
	hp = hp_max


func rebuild_stats() -> void:
	stats.rebuild(equipment, passives, cultivation.realm, cultivation.attr_mult())
	_recalc_vitals()


func add_passive(id: String) -> bool:
	if id == "" or DB.passive(id).is_empty() or passives.has(id):
		return false
	passives.append(id)
	rebuild_stats()
	return true


func learn_technique(id: String) -> bool:
	if id == "" or DB.technique(id).is_empty() or technique_ids.has(id):
		return false
	technique_ids.append(id)
	return true


func _process(delta: float) -> void:
	_arc_flash = maxf(0.0, _arc_flash - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if _iframes > 0.0 and int(Time.get_ticks_msec() / 60.0) % 2 == 0:
		modulate.a = 0.55
	else:
		modulate.a = 1.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if _meditating:
		velocity = Vector2.ZERO
		var gained := cultivation.cultivate(stats, delta, environment_bonus())
		if gained > 0.0:
			cultivation_changed()
			if cultivation.is_full(stats):
				if cultivation.is_peak():
					if not _peak_notified:
						_peak_notified = true
						Bus.toast.emit("Peak of %s. Press G to face your tribulation." % cultivation.realm_name())
				else:
					cultivation.advance_sublevel(stats)
					_peak_notified = false
					Bus.toast.emit("Advanced to %s." % cultivation.stage_label())
		move_and_slide()
		return

	# Passive Qi regeneration: slow recovery between fights.
	if cultivation.regenerate(stats, delta) > 0.0:
		cultivation_changed()

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("attack"):
		try_attack()
	if Input.is_action_just_pressed("dodge"):
		try_dodge(input_dir)
	if Input.is_action_just_pressed("meditate"):
		toggle_meditation()

	if _dodge_timer > 0.0:
		move_and_slide()
		return

	var speed := stats.move_speed()
	if _attack_state != "idle":
		speed *= 0.45
	velocity = input_dir.normalized() * speed
	if input_dir != Vector2.ZERO:
		_facing = _aim_dir()
	move_and_slide()


func _aim_dir() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() < 4.0:
		return _facing
	return to_mouse.normalized()


func _tick_timers(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_tick_attack(delta)


func _tick_attack(delta: float) -> void:
	if _attack_state == "idle":
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	var frames: Dictionary = _current_technique.get("frames", {})
	var speed := stats.attack_speed()
	match _attack_state:
		"startup":
			_attack_state = "active"
			_attack_timer = maxf(0.016, float(frames.get("active", 4)) / 60.0 / speed)
			_strike()
		"active":
			_attack_state = "recovery"
			var recovery := float(frames.get("recovery", 12)) / 60.0 / speed
			recovery *= (1.0 - stats.recovery_reduction())
			_attack_timer = maxf(0.02, recovery)
			_cooldown = float(_current_technique.get("cooldown", 0.4))
		"recovery":
			_attack_state = "idle"


func current_technique() -> Dictionary:
	if technique_ids.is_empty():
		return {}
	var index := clampi(selected_technique, 0, technique_ids.size() - 1)
	return DB.technique(String(technique_ids[index]))


func try_attack() -> void:
	if _attack_state != "idle" or _cooldown > 0.0:
		return
	if _meditating:
		toggle_meditation()
		return
	var tech := current_technique()
	if tech.is_empty():
		return
	var cost := float(tech.get("qi_cost", 0.0))
	if cultivation.qi < cost:
		Bus.toast.emit("Not enough Qi.")
		return
	cultivation.qi -= cost
	_current_technique = tech
	_attack_state = "startup"
	var frames: Dictionary = tech.get("frames", {})
	_attack_timer = maxf(0.02, float(frames.get("startup", 9)) / 60.0 / stats.attack_speed())
	_facing = _aim_dir()
	cultivation_changed()


func _strike() -> void:
	var tech := _current_technique
	if tech.is_empty():
		return
	var box: Dictionary = tech.get("hitbox", {})
	var radius := float(box.get("radius", 70.0))
	var arc := deg_to_rad(float(box.get("angle", 120.0)))

	_attack_counter += 1
	var crit_roll := float(Rng.roll_float("crit", Game.kills * 1000 + _attack_counter, cultivation.realm))
	var is_crit := crit_roll < stats.crit_chance()

	var raw := Damage.technique_damage(tech, stats, stats.weapon_damage())
	if is_crit:
		raw *= CRIT_MULTIPLIER
	var poise := Damage.poise_damage(tech, stats)
	var knock := Damage.knockback(tech, stats)
	var lifesteal := float(tech.get("lifesteal", 0.0)) + stats.lifesteal()

	_arc_flash = 0.13
	_arc_radius = radius
	_arc_angle = arc

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var to_enemy := enemy.global_position - global_position
		if to_enemy.length() > radius + 14.0:
			continue
		if arc < TAU - 0.01 and absf(_facing.angle_to(to_enemy)) > arc * 0.5:
			continue
		var final := Damage.resolve(raw, 0.0, float(cultivation.realm))
		if enemy.has_method("take_hit"):
			enemy.take_hit(final, _facing.normalized() * knock, poise)
		Bus.damage_dealt.emit(final, enemy)
		if lifesteal > 0.0:
			heal(final * lifesteal)
			break


func weapon_damage() -> float:
	return stats.weapon_damage()


func armor() -> float:
	return stats.armor()


func take_hit(amount: float, _from: Vector2 = Vector2.ZERO) -> void:
	if _iframes > 0.0 or hp <= 0.0:
		return
	var raw := Damage.mitigate_armor(amount, stats.armor())
	var final := Damage.resolve(raw, stats.physical_resist() * 100.0, 1.0)
	hp = maxf(0.0, hp - final)
	_hurt_flash = 0.18
	Bus.player_stats_changed.emit()
	if hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	hp = minf(hp_max, hp + amount)
	Bus.player_stats_changed.emit()


func _die() -> void:
	Bus.toast.emit("Your body fails. You wake at the edge of the clearing, weaker.")
	cultivation.qi = 0.0
	hp = hp_max * 0.5
	global_position = spawn_point
	_iframes = 2.0
	Bus.cultivation_changed.emit()
	Bus.player_stats_changed.emit()


func toggle_meditation() -> void:
	if _attack_state != "idle":
		return
	_meditating = not _meditating
	if _meditating:
		_peak_notified = false
	Bus.meditation_toggled.emit(_meditating)


func is_meditating() -> bool:
	return _meditating


func try_dodge(dir: Vector2) -> void:
	if _dodge_cooldown > 0.0 or _dodge_timer > 0.0:
		return
	if _meditating:
		toggle_meditation()
	var dash_dir := dir.normalized()
	if dash_dir == Vector2.ZERO:
		dash_dir = _facing
	velocity = dash_dir * DODGE_SPEED
	_dodge_timer = 0.18
	_dodge_cooldown = 1.2
	_iframes = 0.16 + float(stats.dodge_bonus_frames()) / 60.0


## Attempts the realm breakthrough. Returns the result dictionary for the HUD.
func attempt_breakthrough() -> Dictionary:
	var r: RandomNumberGenerator = Rng.stream("breakthrough", cultivation.realm, cultivation.breakthrough_attempts)
	var result := cultivation.attempt_breakthrough(stats, r, Game.kills, Game.karma)
	if result.get("reason", "") != "":
		var reason := String(result["reason"])
		if reason == "not_at_peak":
			Bus.toast.emit("You have not reached the peak of this realm.")
		elif reason == "qi_not_full":
			Bus.toast.emit("Your Qi is not full.")
		return result
	rebuild_stats()
	if bool(result.get("success", false)):
		hp = maxf(1.0, hp - hp_max * float(result.get("hp_cost_ratio", 0.0)))
		Bus.toast.emit("Breakthrough! You are now %s." % cultivation.stage_label())
	else:
		hp = maxf(1.0, hp - hp_max * float(result.get("hp_cost_ratio", 0.0)))
		Bus.toast.emit("The tribulation breaks you. Qi deviation.")
	rebuild_stats()
	Bus.player_stats_changed.emit()
	return result


func _recalc_vitals() -> void:
	hp_max = BASE_HP + float(cultivation.realm) * 20.0 \
		+ Attributes.soft(float(stats.get_attr("str")), 20.0) \
		+ Attributes.soft(cultivation.attr_mult() * 10.0, 12.0)
	hp = minf(hp, hp_max)


func cultivation_changed() -> void:
	_hud_timer += get_physics_process_delta_time()
	if _hud_timer >= 0.2:
		_hud_timer = 0.0
		Bus.cultivation_changed.emit()


func environment_bonus() -> float:
	# Spirit-qi density will come from the region the player stands in.
	return 1.0


func pick_up(item: Dictionary) -> void:
	inventory.append(item)
	var slot := String(item.get("slot", ""))
	if slot == "weapon" or slot == "armor" or slot == "ring" or slot == "talisman":
		var current: Dictionary = equipment.get(slot, {})
		if current.is_empty() or int(item.get("ilvl", 1)) >= int(current.get("ilvl", 1)):
			equipment[slot] = item
			rebuild_stats()
	Bus.item_picked.emit(item)
	Bus.player_stats_changed.emit()


func _draw() -> void:
	draw_circle(Vector2(0, 7), RADIUS * 0.95, Color(0, 0, 0, 0.3))
	var body := Color("#dbe4ea")
	if _hurt_flash > 0.0:
		body = Color("#ff8080")
	elif _iframes > 0.0:
		body = Color("#9fd0ff")
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 28, Color("#232b31"), 2.0)
	draw_line(Vector2.ZERO, _facing * (RADIUS + 7.0), Color("#7fd3e0"), 3.0)

	var qi_ratio := clampf(cultivation.qi / maxf(1.0, cultivation.qi_max(stats)), 0.0, 1.0)
	if qi_ratio > 0.01:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, -PI * 0.5, -PI * 0.5 + TAU * qi_ratio, 32, Color("#7fd3e0", 0.85), 2.0)

	if _meditating:
		for i in 3:
			var alpha := 0.3 - float(i) * 0.08
			draw_arc(Vector2.ZERO, RADIUS + 10.0 + float(i) * 9.0, 0.0, TAU, 32, Color("#9fe0c0", alpha), 1.5)

	if _arc_flash > 0.0:
		var base := _facing.angle()
		var half := _arc_angle * 0.5
		draw_arc(Vector2.ZERO, _arc_radius, base - half, base + half, 28, Color("#ffffff", 0.8), 6.0)


func to_dict() -> Dictionary:
	var equipped := {}
	for slot in equipment.keys():
		equipped[slot] = equipment[slot]
	return {
		"display_name": display_name,
		"position": [global_position.x, global_position.y],
		"hp": hp,
		"hp_max": hp_max,
		"attrs": attrs.to_dict(),
		"cultivation": cultivation.to_dict(),
		"passives": passives.duplicate(),
		"inventory": inventory,
		"equipment": equipped,
		"technique_ids": technique_ids,
		"selected_technique": selected_technique,
	}


func from_dict(data: Dictionary) -> void:
	display_name = String(data.get("display_name", display_name))
	var pos: Array = data.get("position", [global_position.x, global_position.y])
	global_position = Vector2(float(pos[0]), float(pos[1]))
	attrs.from_dict(data.get("attrs", {}))
	cultivation.from_dict(data.get("cultivation", {}))
	passives = data.get("passives", []).duplicate()
	inventory = data.get("inventory", []).duplicate(true)
	equipment = data.get("equipment", {}).duplicate(true)
	var ids: Array = data.get("technique_ids", [])
	if not ids.is_empty():
		technique_ids = ids.duplicate()
	selected_technique = int(data.get("selected_technique", 0))
	rebuild_stats()
	hp = float(data.get("hp", hp_max))
	spawn_point = global_position
	Bus.player_stats_changed.emit()
	Bus.cultivation_changed.emit()
