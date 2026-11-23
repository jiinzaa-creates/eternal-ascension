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
## World units per second squared. The character reaches full speed in about a
## tenth of a second and stops in less, which keeps turns responsive without
## the instant velocity snap the first build shipped.
const ACCELERATION := 2400.0
const DECELERATION := 3000.0
const AIM_DEADZONE := 0.25

var display_name := "Wanderer"
## Code-drawn looks: robe, hair and skin palettes plus a presentation line.
var appearance := Appearance.new()
## Innate body. Its mods enter the stat pipeline like equipment or a passive.
var physique_id := Physiques.DEFAULT_ID
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

var animator := Animator.new()

var _attack_state := "idle"  # idle | startup | active | recovery
var _attack_timer := 0.0
var _attack_phase_total := 0.0
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
var _evade_counter := 0
var _sprinting := false


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
	stats.rebuild(equipment, passives, cultivation.realm, cultivation.attr_mult(), physique_id)
	_recalc_vitals()


## Replaces the body only with a strictly better one; ties keep what you have.
func inherit_physique(id: String) -> bool:
	if Physiques.find(id).is_empty():
		return false
	if Physiques.tier_of(id) <= Physiques.tier_of(physique_id):
		return false
	physique_id = id
	rebuild_stats()
	Bus.player_stats_changed.emit()
	return true


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
	regenerate(delta)
	_sync_animation(delta)
	queue_redraw()


## Out-of-combat health regeneration. Attacking or having just been hit stops it,
## so a fight is never a healing race against the player's own stats.
func regenerate(delta: float) -> void:
	if hp <= 0.0 or hp >= hp_max:
		return
	if _attack_state != "idle" or _hurt_flash > 0.0:
		return
	var amount := stats.health_regen() * delta
	if amount <= 0.0:
		return
	hp = minf(hp_max, hp + amount)
	Bus.player_stats_changed.emit()


func _move_ratio() -> float:
	return velocity.length() / maxf(1.0, stats.move_speed())


## Animation reads the same state the combat machine uses, so a strike pose
## cannot be shown on a frame that cannot hit.
func _sync_animation(delta: float) -> void:
	animator.update(delta, _move_ratio(), _sprinting, _attack_state != "idle",
		_dodge_timer > 0.0, _hurt_flash > 0.0, _meditating, false)


func _attack_swing() -> float:
	if _attack_state == "idle":
		return 0.0
	var ratio := 1.0 - clampf(_attack_timer / maxf(0.001, _attack_phase_total), 0.0, 1.0)
	return Animator.attack_swing(_attack_state, ratio)


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
	_sprinting = Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO and _attack_state == "idle"
	speed = Motion.sprint_speed(speed, _sprinting)
	if _attack_state != "idle":
		speed *= 0.45
	var desired := input_dir.normalized() * speed
	velocity = Motion.approach(velocity, desired, ACCELERATION, DECELERATION, delta)
	if input_dir != Vector2.ZERO:
		_facing = _aim_dir()
	move_and_slide()


## Aims with the right stick when one is pushed, otherwise with the mouse.
func _aim_dir() -> Vector2:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > AIM_DEADZONE:
		return stick.normalized()
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
			_attack_phase_total = _attack_timer
			_strike()
		"active":
			_attack_state = "recovery"
			var recovery := float(frames.get("recovery", 12)) / 60.0 / speed
			recovery *= (1.0 - stats.recovery_reduction())
			_attack_timer = maxf(0.02, recovery)
			_attack_phase_total = _attack_timer
			_cooldown = float(_current_technique.get("cooldown", 0.4)) * (1.0 - stats.cooldown_reduction())
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
	_attack_phase_total = _attack_timer
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
		raw *= stats.crit_multiplier()
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
			enemy.take_hit(final, _facing.normalized() * knock, poise, stats.penetration_fraction())
		Bus.damage_dealt.emit(final, enemy)
		if lifesteal > 0.0:
			heal(final * lifesteal)
			break


func weapon_damage() -> float:
	return stats.weapon_damage()


func armor() -> float:
	return stats.armor()


func take_hit(amount: float, _from: Vector2 = Vector2.ZERO, can_evade: bool = true) -> void:
	if _iframes > 0.0 or hp <= 0.0:
		return
	if can_evade and stats.evasion_chance() > 0.0:
		_evade_counter += 1
		var roll := float(Rng.roll_float("evade", Game.kills * 977 + _evade_counter, cultivation.realm))
		if stats.evades(roll):
			Bus.toast.emit("You slip aside.")
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


func is_sprinting() -> bool:
	return _sprinting


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
	# Weather is the environment's first real input: rain thins the Qi, storms
	# charge it, snow slows it. Regional spirit-density will join this later.
	return Climate.cultivation_bonus(Weather.current)


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
	# Ground shadow and rings stay in world space: animation must not tilt them.
	draw_circle(Vector2(0, 7), RADIUS * 0.95, Color(0, 0, 0, 0.3))

	var qi_ratio := clampf(cultivation.qi / maxf(1.0, cultivation.qi_max(stats)), 0.0, 1.0)
	if qi_ratio > 0.01:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, -PI * 0.5, -PI * 0.5 + TAU * qi_ratio, 32, Color("#7fd3e0", 0.85), 2.0)

	if _meditating:
		for i in 3:
			var alpha := 0.3 - float(i) * 0.08
			draw_arc(Vector2.ZERO, RADIUS + 10.0 + float(i) * 9.0, 0.0, TAU, 32, Color("#9fe0c0", alpha), 1.5)

	var body := appearance.robe_color()
	if _hurt_flash > 0.0:
		body = Color("#ff8080")
	elif _iframes > 0.0:
		body = Color("#9fd0ff")

	var pose := Animator.pose(animator.state, animator.time, _move_ratio())
	var bob: Vector2 = pose["bob"]
	var squash: Vector2 = pose["squash"]
	var swing := float(pose["swing"])
	var lean := float(pose["lean"]) * (1.0 if _facing.x >= 0.0 else -1.0)
	var attack := _attack_swing()

	# Limbs and torso share one transform so bob, lean and squash stay coherent.
	draw_set_transform(bob, lean, squash)
	var limb := Color("#3a454c")
	draw_line(Vector2(-5, 2), Vector2(-5.0 + swing * 5.0, 12.0), limb, 3.0)
	draw_line(Vector2(5, 2), Vector2(5.0 - swing * 5.0, 12.0), limb, 3.0)
	draw_line(Vector2(-4, -3), Vector2(-4.0 - swing * 3.0, -9.0), limb, 2.5)
	draw_line(Vector2(4, -3), Vector2(4.0 + swing * 3.0 + attack * 5.0, -9.0 - attack * 6.0), limb, 2.5)
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 28, Color("#232b31"), 2.0)
	# Head and hair sit inside the silhouette, so appearance reads from above.
	draw_circle(Vector2(0, -3), 6.0, appearance.skin_color())
	draw_arc(Vector2(0, -3), 6.5, PI, TAU, 16, appearance.hair_color(), 3.0)
	draw_line(Vector2.ZERO, _facing * (RADIUS + 7.0 + attack * 6.0), Color("#7fd3e0"), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
		"appearance": appearance.to_dict(),
		"physique": physique_id,
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
	appearance.from_dict(data.get("appearance", {}))
	physique_id = String(data.get("physique", Physiques.DEFAULT_ID))
	if Physiques.find(physique_id).is_empty():
		physique_id = Physiques.DEFAULT_ID
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
