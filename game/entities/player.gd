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
## A raised ward is walked behind, not run behind.
const GUARD_MOVE_MULT := 0.45

var display_name := "Wanderer"
## Code-drawn looks: robe, hair and skin palettes plus a presentation line.
var appearance := Appearance.new()
## Innate body. Its mods enter the stat pipeline like equipment or a passive.
var physique_id := Physiques.DEFAULT_ID
var attrs: Attributes
var stats: StatBlock
var cultivation: Cultivation

var passives: Array = []
## Permanent insights. Each one adds its mods to the one pipeline.
var enlightenments: Array = []
var inventory: Array = []
var equipment: Dictionary = {}
var technique_ids: Array = []
var selected_technique: int = 0
## Technique id -> mastery xp. Everything else about mastery is derived.
var technique_xp: Dictionary = {}
## Technique id -> times watched for observation-based learning.
var observed: Dictionary = {}

var hp: float = 100.0
var hp_max: float = 100.0
var spawn_point := Vector2.ZERO

var animator := Animator.new()

var _attack_state := "idle"  # idle | startup | active | recovery
var _attack_timer := 0.0
var _attack_phase_total := 0.0
## The attack the frame machine is running. Techniques and weapon strikes produce
## the same payload shape, so phase timing, hitboxes and poise stay one path.
var _current_attack: Dictionary = {}
## Weapon chain cursor: -1 opens a fresh chain, and the timer measures how long
## ago the last strike began so a late press restarts the sequence.
var _combo_index := -1
var _combo_elapsed := 100.0
var _cooldown := 0.0
var _dodge_timer := 0.0
var _dodge_cooldown := 0.0
var _iframes := 0.0
## Guard stance: held means the ward is up, guard_time feeds the parry window,
## and guard_broken counts down the seconds before it can be raised again.
var _guard_held := false
var _guard_time := 0.0
var _guard_broken := 0.0
var _parry_flash := 0.0
var _meditating := false
## Seconds of "recent combat" left; the Sword Heart method feeds on it.
var _combat_timer := 0.0
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
## Last passive-condition state, so a threshold crossing rebuilds once rather
## than every frame.
var _was_wounded := false
var _last_karma := 0
## Guard meter shared with every enemy; a break staggers the body.
var poise := Poise.new(40.0)
var _knock := Vector2.ZERO


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


## Snapshot the passive rules read. Cheap on purpose: resolve() runs on every
## rebuild and on every condition threshold crossing.
func passive_state() -> Dictionary:
	return {
		"hp_ratio": hp / maxf(1.0, hp_max),
		"karma": Game.karma,
		"attrs": attrs,
		"realm": cultivation.realm,
		"physique_tier": Physiques.tier_of(physique_id),
		"affinities": cultivation.root_data().get("affinities", []),
	}


func active_passives() -> Array:
	return Passives.resolve(passives, passive_state())


func dormant_passives() -> Array:
	return Passives.issues(passives, passive_state())


func rebuild_stats() -> void:
	stats.rebuild(equipment, active_passives(), cultivation.realm, cultivation.attr_mult(), physique_id,
		Meridians.bonus_mods(cultivation.meridians), Realms.ability_mods(cultivation.realm),
		Enlightenments.mods(enlightenments), Aging.decline(Game.age_years(), _lifespan_years()))
	poise.set_maximum(Combat.poise_capacity(cultivation.realm, stats.get_attr("str")))
	_recalc_vitals()


## Lifespan this body will have once rebuilt. WIS is never reduced by aging, so
## the decline cannot feed back into its own lifespan.
func _lifespan_years() -> int:
	var base := Realms.lifespan(cultivation.realm)
	if base <= 0:
		return 0
	return base + stats.lifespan_bonus()


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


## Ownership, not activation: quests and inheritances can grant a passive the
## body cannot use yet. It is kept and wakes when requirements are met.
func add_passive(id: String) -> bool:
	if id == "" or DB.passive(id).is_empty() or passives.has(id):
		return false
	passives.append(id)
	rebuild_stats()
	return true


## Voluntary learning (manuals, teachers): refuses what the body cannot use yet.
func try_learn_passive(id: String) -> Dictionary:
	if id == "" or Passives.find(id).is_empty():
		return {"ok": false, "reason": "unknown passive"}
	if passives.has(id):
		return {"ok": false, "reason": "already known"}
	var requirement := Passives.meets_requirements(Passives.find(id), passive_state())
	if not bool(requirement["ok"]):
		return {"ok": false, "reason": String(requirement["reason"])}
	passives.append(id)
	rebuild_stats()
	Bus.player_stats_changed.emit()
	return {"ok": true, "reason": ""}


## What an epiphany roll reads: realm, practised method, attributes.
func enlightenment_state() -> Dictionary:
	return {"realm": cultivation.realm, "method": cultivation.method_id, "attrs": attrs}


## Every source of understanding funnels here so one place decides when an
## insight is due. Returns true only when an insight was actually learned.
func gain_comprehension(amount: float) -> bool:
	if not cultivation.add_comprehension(amount):
		return false
	if not cultivation.is_enlightenment_ready():
		return false
	var generator: RandomNumberGenerator = Rng.stream("enlightenment", cultivation.realm, cultivation.enlightenment_attempts)
	var id := Enlightenments.pick(generator, enlightenment_state(), enlightenments)
	if id == "":
		# Nothing is in reach yet; keep the full meter for when it is.
		return false
	cultivation.enlightenment_attempts += 1
	cultivation.take_enlightenment()
	return add_enlightenment(id)


func add_enlightenment(id: String) -> bool:
	if not Enlightenments.learn(enlightenments, id):
		return false
	rebuild_stats()
	var entry := Enlightenments.find(id)
	Bus.toast.emit("Enlightenment: %s. %s" % [String(entry.get("name", id)), String(entry.get("desc", ""))])
	Bus.enlightenment_gained.emit(id)
	Bus.player_stats_changed.emit()
	return true


## Grant path (starting kit, manuals, inheritances, quest rewards): no checks,
## because a reward must never be lost to a requirement.
func learn_technique(id: String) -> bool:
	if id == "" or DB.technique(id).is_empty() or technique_ids.has(id):
		return false
	technique_ids.append(id)
	return true


func technique_state() -> Dictionary:
	return {"realm": cultivation.realm, "attrs": attrs}


## Voluntary path (teachers, observation): refuses what the body cannot use yet.
func try_learn_technique(id: String) -> Dictionary:
	if id == "" or DB.technique(id).is_empty():
		return {"ok": false, "reason": "unknown technique"}
	if technique_ids.has(id):
		return {"ok": false, "reason": "already known"}
	var check := Techniques.can_learn(id, technique_state())
	if not bool(check["ok"]):
		return check
	technique_ids.append(id)
	Bus.cultivation_changed.emit()
	return {"ok": true, "reason": ""}


func mastery_xp(id: String) -> int:
	return int(technique_xp.get(id, 0))


func mastery_tier(id: String) -> int:
	return Mastery.tier_for(mastery_xp(id))


func mastery_label(id: String) -> String:
	return Mastery.label(mastery_tier(id))


func add_technique_xp(id: String, amount: int) -> void:
	if amount <= 0 or DB.technique(id).is_empty():
		return
	var before := mastery_tier(id)
	var after_xp := Mastery.clamp_xp(mastery_xp(id) + amount)
	if after_xp == mastery_xp(id):
		return
	technique_xp[id] = after_xp
	if mastery_tier(id) != before:
		var tech := DB.technique(id)
		Bus.toast.emit("%s — %s (%d)." % [String(tech.get("name", id)), mastery_label(id), mastery_tier(id)])


## Watch a technique being performed. Returns {ok, reason, progress, learned}.
## Progress persists, so watching across sessions still finishes the lesson.
func observe_technique(id: String) -> Dictionary:
	if id == "" or DB.technique(id).is_empty():
		return {"ok": false, "reason": "unknown technique", "progress": 0.0, "learned": false}
	if technique_ids.has(id):
		return {"ok": false, "reason": "already known", "progress": 1.0, "learned": false}
	var check := Techniques.can_learn(id, technique_state())
	if not bool(check["ok"]):
		return {"ok": false, "reason": String(check["reason"]), "progress": 0.0, "learned": false}
	var count := int(observed.get(id, 0)) + 1
	observed[id] = count
	if count < Techniques.OBSERVE_REQUIRED:
		return {"ok": true, "reason": "", "progress": Techniques.observation_progress(count), "learned": false}
	var learned := try_learn_technique(id)
	if bool(learned["ok"]):
		observed.erase(id)
		return {"ok": true, "reason": "", "progress": 1.0, "learned": true}
	return {"ok": false, "reason": String(learned["reason"]), "progress": 0.0, "learned": false}


func _process(delta: float) -> void:
	_arc_flash = maxf(0.0, _arc_flash - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if _iframes > 0.0 and int(Time.get_ticks_msec() / 60.0) % 2 == 0:
		modulate.a = 0.55
	else:
		modulate.a = 1.0
	regenerate(delta)
	_refresh_passive_conditions()
	_sync_animation(delta)
	queue_redraw()


## Situational passives (wounded, karma) only change at thresholds, so the stat
## pipeline is rebuilt on the crossing and not per frame.
func _refresh_passive_conditions() -> void:
	var wounded := hp / maxf(1.0, hp_max) < Passives.WOUNDED_RATIO
	if wounded != _was_wounded or Game.karma != _last_karma:
		_was_wounded = wounded
		_last_karma = Game.karma
		rebuild_stats()


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

	# A broken guard overrides input: the body is carried by the blow until it
	# recovers, which is what makes poise a real combat resource.
	if poise.is_staggered():
		_sprinting = false
		velocity = _knock
		move_and_slide()
		return

	if _meditating:
		velocity = Vector2.ZERO
		var gained := meditate_tick(delta)
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
	if Input.is_action_just_pressed("light_attack"):
		try_light_attack()
	# The ward is a hold, not a press: it rises on the first held frame and drops
	# the moment the key is released, so the stance never sticks.
	var wants_guard := Input.is_action_pressed("block")
	if wants_guard and not _guard_held and _attack_state == "idle":
		set_guard(true)
	elif not wants_guard:
		set_guard(false)
	if Input.is_action_just_pressed("dodge"):
		try_dodge(input_dir)
	if Input.is_action_just_pressed("meditate"):
		toggle_meditation()

	if _dodge_timer > 0.0:
		move_and_slide()
		return

	var speed := stats.move_speed()
	_sprinting = Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO \
		and _attack_state == "idle" and not is_guarding()
	speed = Motion.sprint_speed(speed, _sprinting)
	if _attack_state != "idle":
		speed *= 0.45
	if is_guarding():
		speed *= GUARD_MOVE_MULT
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
	_combat_timer = maxf(0.0, _combat_timer - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_guard_broken = maxf(0.0, _guard_broken - delta)
	_parry_flash = maxf(0.0, _parry_flash - delta)
	if _guard_held:
		_guard_time += delta
	poise.tick(delta)
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	_combo_elapsed += delta
	_tick_attack(delta)


func _tick_attack(delta: float) -> void:
	if _attack_state == "idle":
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	var frames: Dictionary = _current_attack.get("frames", {})
	var speed := _attack_speed()
	_attack_state = Combat.next_phase(_attack_state)
	match _attack_state:
		"active":
			_attack_timer = Combat.phase_seconds(frames, "active", speed)
			_attack_phase_total = _attack_timer
			_strike()
		"recovery":
			_attack_timer = Combat.phase_seconds(frames, "recovery", speed,
				stats.recovery_reduction())
			_attack_phase_total = _attack_timer
			if bool(_current_attack.get("light", false)):
				# A weapon chain is free, so its only gate is the short swing pause.
				_cooldown = float(_current_attack.get("cooldown", 0.06))
			else:
				var tech_id := String(_current_attack.get("id", ""))
				_cooldown = float(_current_attack.get("cooldown", 0.4)) * (1.0 - stats.cooldown_reduction()) \
					* Mastery.cooldown_mult(mastery_tier(tech_id)) * Realms.technique_mult(cultivation.realm)


## Phase speed for the running attack. A weapon category's own speed multiplier
## stacks with attack speed, so a saber winds up slower and a fist faster.
func _attack_speed() -> float:
	return stats.attack_speed() * maxf(0.1, float(_current_attack.get("speed_mult", 1.0)))


func current_technique() -> Dictionary:
	if technique_ids.is_empty():
		return {}
	var index := clampi(selected_technique, 0, technique_ids.size() - 1)
	return DB.technique(String(technique_ids[index]))


## The equipped weapon's category. Unarmed is a real moveset, not a fallback.
func weapon_type_id() -> String:
	return Weapons.type_id_for(equipment.get("weapon", {}))


func weapon_type() -> Dictionary:
	return Weapons.find(weapon_type_id())


func weapon_type_name() -> String:
	return String(weapon_type().get("name", "Unarmed"))


## The chain step the next light strike would take, for the HUD.
func next_combo_step() -> int:
	var type := weapon_type()
	var list: Array = type.get("moves", [])
	if list.is_empty():
		return 0
	var window := float(type.get("combo_window", 0.75))
	return Weapons.next_combo(_combo_index, _combo_elapsed, window, list.size())


## Name of the strike the next press would perform, including the live chain
## window, so the HUD never promises a step a late press would not take.
func next_move_name() -> String:
	var type := weapon_type()
	var list: Array = type.get("moves", [])
	if list.is_empty():
		return ""
	var index := next_combo_step()
	var entry: Variant = list[clampi(index, 0, list.size() - 1)]
	return String((entry as Dictionary).get("name", "")) if typeof(entry) == TYPE_DICTIONARY else ""


func try_attack() -> void:
	if _attack_state != "idle" or _cooldown > 0.0 or is_guarding():
		return
	if _meditating:
		toggle_meditation()
		return
	var tech := current_technique()
	if tech.is_empty():
		return
	var tech_id := String(tech.get("id", ""))
	var cost := float(tech.get("qi_cost", 0.0)) * Mastery.qi_mult(mastery_tier(tech_id)) \
		* Realms.technique_mult(cultivation.realm)
	if cultivation.qi < cost:
		Bus.toast.emit("Not enough Qi.")
		return
	cultivation.qi -= cost
	_current_attack = tech
	# A technique ends a weapon chain: the two attacks never blur together.
	_combo_index = -1
	_combo_elapsed = 100.0
	_attack_state = "startup"
	var frames: Dictionary = tech.get("frames", {})
	_attack_timer = Combat.phase_seconds(frames, "startup", stats.attack_speed())
	_attack_phase_total = _attack_timer
	_facing = _aim_dir()
	cultivation_changed()


## The equipped weapon's own strike: free, chained and available at any realm.
## Light strikes and techniques share the frame machine but never the same press,
## so a weapon is a real alternative to spending Qi.
func try_light_attack() -> bool:
	if _attack_state != "idle" or _cooldown > 0.0 or _dodge_timer > 0.0 or is_guarding():
		return false
	if _meditating:
		toggle_meditation()
		return false
	var type := weapon_type()
	var list: Array = type.get("moves", [])
	if list.is_empty():
		return false
	var window := float(type.get("combo_window", 0.75))
	_combo_index = Weapons.next_combo(_combo_index, _combo_elapsed, window, list.size())
	_combo_elapsed = 0.0
	_current_attack = Weapons.attack_payload(type, _combo_index)
	if _current_attack.is_empty():
		return false
	_attack_state = "startup"
	var frames: Dictionary = _current_attack.get("frames", {})
	_attack_timer = Combat.phase_seconds(frames, "startup", _attack_speed())
	_attack_phase_total = _attack_timer
	_facing = _aim_dir()
	return true


func _strike() -> void:
	var attack := _current_attack
	if attack.is_empty():
		return
	var box: Dictionary = attack.get("hitbox", {})
	var radius := float(box.get("radius", 70.0))
	var arc := deg_to_rad(float(box.get("angle", 120.0)))
	var is_light := bool(attack.get("light", false))

	_attack_counter += 1
	var crit_roll := float(Rng.roll_float("crit", Game.kills * 1000 + _attack_counter, cultivation.realm))
	var is_crit := crit_roll < stats.crit_chance()

	var tech_id := String(attack.get("id", ""))
	var raw := 0.0
	if is_light:
		raw = Damage.weapon_strike(attack, stats, stats.weapon_damage())
	else:
		raw = Damage.technique_damage(attack, stats, stats.weapon_damage(),
			Mastery.damage_mult(mastery_tier(tech_id)))
		add_technique_xp(tech_id, Mastery.XP_PER_HIT)
	if is_crit:
		raw *= stats.crit_multiplier()
	var poise_hit := Damage.poise_damage(attack, stats)
	var knock := Damage.knockback(attack, stats)
	var lifesteal := float(attack.get("lifesteal", 0.0)) + stats.lifesteal()

	_combat_timer = 6.0
	_arc_flash = 0.13
	_arc_radius = radius
	_arc_angle = arc

	for enemy in Combat.targets(global_position, _facing, box, get_tree().get_nodes_in_group("enemy"), RADIUS):
		var final := Damage.resolve(raw, 0.0, float(cultivation.realm))
		if enemy.has_method("take_hit"):
			enemy.take_hit(final, _facing.normalized() * knock, poise_hit, stats.penetration_fraction())
		Bus.damage_dealt.emit(final, enemy)
		if lifesteal > 0.0:
			heal(final * lifesteal)
			break


func weapon_damage() -> float:
	return stats.weapon_damage()


func armor() -> float:
	return stats.armor()


## `poise_damage` and `knock_force` come from the attacker's blow, so a heavy
## strike can stagger and throw the body while a light one cannot. `attacker` is
## optional and only used by a parry, which throws the blow back at its source.
func take_hit(amount: float, from: Vector2 = Vector2.ZERO, can_evade: bool = true,
		poise_damage: float = 0.0, knock_force: float = 0.0, attacker: Node = null) -> void:
	if _iframes > 0.0 or hp <= 0.0:
		return
	_combat_timer = 6.0
	_meditating = false
	if can_evade and stats.evasion_chance() > 0.0:
		_evade_counter += 1
		var roll := float(Rng.roll_float("evade", Game.kills * 977 + _evade_counter, cultivation.realm))
		if stats.evades(roll):
			Bus.toast.emit("You slip aside.")
			return

	# Guarding only meets real blows head-on: a hazard with no poise behind it, or
	# anything arriving from behind the ward, goes through untouched.
	var state := guard_state()
	# The ward is measured against where the blow comes FROM, not where it is
	# travelling: a player facing right is covered by an attacker on his right.
	var facing_blow := poise_damage > 0.0 and Defense.covers(_facing, global_position.direction_to(from))
	if facing_blow and state == "parry":
		_parry_flash = 0.25
		Bus.toast.emit("Parried.")
		if attacker != null and is_instance_valid(attacker) and attacker.has_method("stagger"):
			attacker.stagger(Defense.reflected_poise(stats))
		Bus.player_stats_changed.emit()
		return

	var absorbed := false
	var guard_broke := false
	var amount_mult := 1.0
	if facing_blow and state == "block":
		if Defense.can_pay(cultivation.qi, amount):
			absorbed = true
			cultivation.qi = maxf(0.0, cultivation.qi - Defense.qi_cost(amount, state))
			amount_mult = Defense.damage_multiplier("block")
			Bus.cultivation_changed.emit()
		else:
			# The ward cannot pay, so it fails. The blow lands with interest and
			# the body is staggered whatever poise it had left.
			guard_broke = true
			_guard_broken = Defense.BREAK_RECOVERY
			_guard_held = false
			_guard_time = 0.0
			cultivation.qi = 0.0
			amount_mult = Defense.damage_multiplier("broken")
			knock_force *= Defense.GUARD_BREAK_MULT
			Bus.toast.emit("Your guard breaks.")
			Bus.cultivation_changed.emit()
	elif facing_blow and state == "broken":
		amount_mult = Defense.damage_multiplier("broken")

	var raw := Damage.mitigate_armor(amount * amount_mult, stats.armor())
	var final := Damage.resolve(raw, stats.physical_resist() * 100.0, 1.0)
	hp = maxf(0.0, hp - final)
	_hurt_flash = 0.18
	if guard_broke:
		poise.break_guard(poise_damage * Defense.GUARD_BREAK_MULT)
		_knock += Combat.knock_impulse(from.direction_to(global_position), knock_force, true)
	elif not absorbed and poise_damage > 0.0:
		var broke := poise.apply(poise_damage)
		_knock += Combat.knock_impulse(from.direction_to(global_position), knock_force, broke)
		if broke and Combat.interrupts(_attack_state):
			_attack_state = "idle"
			_attack_timer = 0.0
			_attack_phase_total = 0.0
			_current_attack = {}
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
	poise.reset()
	_knock = Vector2.ZERO
	_attack_state = "idle"
	Bus.cultivation_changed.emit()
	Bus.player_stats_changed.emit()


## What the method rules read right now. Pure data, no side effects.
func method_state() -> Dictionary:
	var partner := false
	if is_inside_tree():
		for npc in get_tree().get_nodes_in_group("npc"):
			var node := npc as Node2D
			if node != null and node.global_position.distance_to(global_position) < 110.0:
				partner = true
				break
	return {
		"attrs": attrs,
		"realm": cultivation.realm,
		"kills": Game.kills,
		"physique_tier": Physiques.tier_of(physique_id),
		"recent_combat": _combat_timer > 0.0,
		"blood_charge": cultivation.blood_charge,
		"partner": partner,
		"night": Clock.is_night(),
	}


## One meditation step: Qi, method insight, and the blood method's fuel.
func meditate_tick(delta: float) -> float:
	var state := method_state()
	var factor := Methods.meditation_multiplier(cultivation.method_id, state)
	var gained := cultivation.cultivate(stats, delta, environment_bonus(), factor)
	cultivation.add_method_insight(cultivation.method_id, delta * clampf(factor, 0.0, 2.0))
	# Sitting with a method is the slow, reliable road to understanding.
	gain_comprehension(delta * clampf(factor, 0.0, 2.0))
	if cultivation.method_id == "method.blood":
		cultivation.consume_blood_charge(delta * 2.0)
		cultivation.add_contamination(delta * Meridians.BLOOD_CONTAMINATION_PER_SECOND)
	return gained


## Kills feed the blood method; other methods ignore them.
func on_kill(ilvl: int = 1) -> void:
	if cultivation.method_id == "method.blood":
		cultivation.add_blood_charge(3.0 + float(maxi(1, ilvl)) * 2.0)
	# Every death is a lesson, whether or not the character wanted it.
	gain_comprehension(2.0)


func toggle_meditation() -> void:
	if _attack_state != "idle" or is_guarding():
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
	# A roll abandons the ward: movement is not a shield.
	_guard_held = false
	_guard_time = 0.0
	# Dash cancel is a Foundation Establishment unlock: before it, a committed
	# swing cannot be abandoned. The spent Qi is never refunded either way.
	if _attack_state != "idle":
		if not Realms.can_dash_cancel(cultivation.realm):
			return
		_attack_state = "idle"
		_attack_timer = 0.0
		_current_attack = {}
	if _meditating:
		toggle_meditation()
	var dash_dir := dir.normalized()
	if dash_dir == Vector2.ZERO:
		dash_dir = _facing
	velocity = dash_dir * DODGE_SPEED
	_dodge_timer = 0.18
	_dodge_cooldown = 1.2
	_iframes = 0.16 + float(stats.dodge_bonus_frames()) / 60.0


## The live guard stance: none, parry, block or broken.
func guard_state() -> String:
	return Defense.state_for(_guard_held, _guard_time, _guard_broken)


func is_guarding() -> bool:
	return Defense.is_guarding(guard_state())


func is_guard_broken() -> bool:
	return _guard_broken > 0.0


## Raises or lowers the ward. A broken guard, a swing, a dodge, meditation, a
## stagger or an empty body all refuse to raise it. Returns whether it is held.
func set_guard(held: bool) -> bool:
	if not held:
		_guard_held = false
		_guard_time = 0.0
		return false
	if _guard_held:
		return true
	if _guard_broken > 0.0 or _meditating or _dodge_timer > 0.0 or poise.is_staggered() \
			or _attack_state != "idle" or hp <= 0.0:
		return false
	_guard_held = true
	_guard_time = 0.0
	return true


## Attempts the realm breakthrough. Returns the result dictionary for the HUD.
func attempt_breakthrough(composure: float = 0.0) -> Dictionary:
	var r: RandomNumberGenerator = Rng.stream("breakthrough", cultivation.realm, cultivation.breakthrough_attempts)
	var result := cultivation.attempt_breakthrough(stats, r, Game.kills, Game.karma, method_state(), composure)
	if result.get("reason", "") != "":
		var reason := String(result["reason"])
		if reason == "not_at_peak":
			Bus.toast.emit("You have not reached the peak of this realm.")
		elif reason == "qi_not_full":
			Bus.toast.emit("Your Qi is not full.")
		elif reason == "apex":
			Bus.toast.emit("The peak of the ladder. There is no realm above this one.")
		return result
	rebuild_stats()
	var prep_used := int(result.get("preparation", 0))
	var note := String(result.get("method_note", ""))
	if bool(result.get("success", false)):
		hp = maxf(1.0, hp - hp_max * float(result.get("hp_cost_ratio", 0.0)))
		Bus.toast.emit("Breakthrough! You are now %s." % cultivation.stage_label())
		var ability_name := String(result.get("ability", ""))
		if ability_name != "":
			Bus.toast.emit("Realm art awakened: %s." % ability_name)
		# A realm change is the largest single dose of understanding in the game.
		gain_comprehension(30.0)
	else:
		hp = maxf(1.0, hp - hp_max * float(result.get("hp_cost_ratio", 0.0)))
		Bus.toast.emit("The tribulation breaks you. Qi deviation. (%s)" % note)
	if prep_used > 0:
		Bus.toast.emit("%d preparation%s spent themselves in the attempt." % [prep_used, "" if prep_used == 1 else "s"])
	rebuild_stats()
	Bus.player_stats_changed.emit()
	return result


## The tribulation encounter was lost: real wounds, real corruption, no roll.
func fail_breakthrough() -> Dictionary:
	var r: RandomNumberGenerator = Rng.stream("tribulation_break", cultivation.realm, cultivation.failures)
	var result := cultivation.break_through_failure(r, Game.kills, Game.karma, method_state())
	hp = maxf(1.0, hp - hp_max * float(result.get("hp_cost_ratio", 0.0)))
	rebuild_stats()
	Bus.toast.emit("The tribulation breaks you. Qi deviation. (%s)" % String(result.get("method_note", "")))
	Bus.toast.emit("You crawl out of the circle. Prepare before you invite heaven again.")
	Bus.player_stats_changed.emit()
	return result


## Heaven's bolts are not physical attacks: no armour, no evasion and no death
## respawn. The arena owns the "broken" outcome, so this only reports it.
func take_tribulation_damage(amount: float, _from: Vector2 = Vector2.ZERO) -> bool:
	if hp <= 0.0:
		return true
	if _iframes > 0.0:
		return false
	hp = maxf(0.0, hp - maxf(0.0, amount))
	_hurt_flash = 0.18
	Bus.player_stats_changed.emit()
	return hp <= 0.0


## The chance the HUD shows at the peak. Zero below the peak, where no attempt
## is possible; otherwise the same formula the attempt will roll.
func breakthrough_chance_estimate() -> float:
	if not cultivation.is_peak() or cultivation.realm >= Realms.count():
		return 0.0
	return cultivation.estimated_chance(stats, Game.kills, Game.karma, method_state())


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
	# Weather and regional Qi density multiply: a storm in the ashen scrub is
	# still a poor place to sit.
	return Climate.cultivation_bonus(Weather.current) * maxf(0.0, Game.biome_density)


func pick_up(item: Dictionary) -> void:
	inventory.append(item)
	var slot := String(item.get("slot", ""))
	if slot == "weapon" or slot == "armor" or slot == "ring" or slot == "talisman":
		var current: Dictionary = equipment.get(slot, {})
		if current.is_empty() or int(item.get("ilvl", 1)) >= int(current.get("ilvl", 1)):
			equipment[slot] = item
			if slot == "weapon":
				# A new weapon opens its own chain; the old one's cursor is meaningless.
				_combo_index = -1
				_combo_elapsed = 100.0
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

	# The ward is drawn where it actually covers: a frontal arc, never a bubble.
	var stance := guard_state()
	if stance != "none":
		var guard_base := _facing.angle()
		var guard_half := deg_to_rad(Defense.GUARD_ARC) * 0.5
		var guard_color := Color("#9fd0ff", 0.55)
		if stance == "parry":
			guard_color = Color("#ffe08a", 0.85)
		elif stance == "broken":
			guard_color = Color("#e06060", 0.7)
		draw_arc(Vector2.ZERO, RADIUS + 15.0, guard_base - guard_half, guard_base + guard_half, 24, guard_color, 3.0)
	if _parry_flash > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 21.0, 0.0, TAU, 32, Color("#fff3c0", 0.8), 2.0)


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
		"enlightenments": enlightenments.duplicate(),
		"inventory": inventory,
		"equipment": equipped,
		"technique_ids": technique_ids,
		"selected_technique": selected_technique,
		"technique_xp": technique_xp.duplicate(),
		"observed": observed.duplicate(),
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
	# Saves only reference IDs; an unknown or duplicated insight is dropped rather
	# than allowed to add phantom mods.
	enlightenments = []
	for id_value in data.get("enlightenments", []):
		var insight_id := String(id_value)
		if not Enlightenments.find(insight_id).is_empty() and not enlightenments.has(insight_id):
			enlightenments.append(insight_id)
	inventory = data.get("inventory", []).duplicate(true)
	equipment = data.get("equipment", {}).duplicate(true)
	var ids: Array = data.get("technique_ids", [])
	if not ids.is_empty():
		technique_ids = ids.duplicate()
	selected_technique = int(data.get("selected_technique", 0))
	technique_xp = data.get("technique_xp", {}).duplicate()
	observed = data.get("observed", {}).duplicate()
	rebuild_stats()
	hp = float(data.get("hp", hp_max))
	spawn_point = global_position
	Bus.player_stats_changed.emit()
	Bus.cultivation_changed.emit()
