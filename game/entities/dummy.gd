class_name Dummy
extends CharacterBody2D
## A hostile cultivator: the game's enemy body.
##
## It is not "dumb" any more. `EnemyAI` decides, from pure rules, whether this
## body is patrolling, chasing, circling for a turn, winding up, backing off,
## fleeing or walking home; this node owns the timers, the node and the blow.
## A body that is not `aggressive` (the training dummy every test uses, and the
## sparring partners in the settlement) keeps the old behaviour: it stands still
## and only strikes when something calls `_release_attack`.
##
## The blow itself is unchanged from M30: wind up, then one `Combat` hitbox
## resolved against the player with the same poise, stagger and knockback rules
## the player lives by. A parry still spoils the wind-up.

const RADIUS := 13.0
## How far a body looks for allies already committed to a blow.
const GROUP_RADIUS := 320.0
## Seconds a patrolling body pauses at each leg's end.
const PATROL_PAUSE := 1.6

var hp := 70.0
var hp_max := 70.0
## Shared guard meter: the same rules the player lives by.
var poise := Poise.new(40.0)
## Poise this body's blow carries, and how hard it throws the target.
var strike_poise := 10.0
var knockback := 150.0
var ilvl := 1
var speed := 60.0
var attack_range := 48.0
var damage := 7.0
## Physical armour. Without it, penetration would have nothing to pierce.
var armor_value := 0.0
## False keeps a body inert: the training dummy, and every scenario test.
var aggressive := true
var display_name := "Cultivator Dummy"
var body_color := Color("#a85050")

## Behaviour archetype (`brawler`, `skirmisher`, `sentinel`, `archer`) and the
## complete profile derived from `data/enemy_archetypes.json`.
var archetype := "brawler"
var profile: Dictionary = {}
## Where this body belongs. Patrolling, returning and healing all use it.
var home := Vector2.ZERO
## The current state reported to the world, for the HUD and for tests.
var state := "idle"
## Seconds of pursuit left after the target was last seen.
var memory := 0.0
var flee_left := 0.0
## A body only runs once; after that it fights to the end.
var flee_used := false
var retreat_left := 0.0

var animator := Animator.new()

var _entry: Dictionary = {}
var _facing := Vector2.DOWN
var _last_seen := Vector2.ZERO
var _flash := 0.0
var _knock := Vector2.ZERO
var _windup := 0.0
var _cooldown := 0.8
var _dead := false
var _strikes := 0
var _alert := 0.0
var _provoked := false
var _strafe := 1.0
var _circle_time := 0.0
var _patrol_target := Vector2.ZERO
var _patrol_wait := 0.0
var _patrol_phase := 0.0


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 1
	collision_mask = 1
	home = global_position
	profile = EnemyAI.profile(DB.enemy_archetype(archetype))
	_recompute_stats()


## Every number this body fights with, derived once from `ilvl`, its biome entry
## and its archetype. Recomputed rather than multiplied, so setting an archetype
## twice cannot stack its multipliers.
func _recompute_stats() -> void:
	var hp_mult := float(_entry.get("hp_mult", 1.0))
	var dmg_mult := float(_entry.get("damage_mult", 1.0))
	var spawn_speed := float(_entry.get("speed", 60.0))
	hp_max = (70.0 + ilvl * 18.0) * hp_mult * float(profile.get("hp_mult", 1.0))
	hp = hp_max
	poise.set_maximum(
		(40.0 + ilvl * 6.0) * float(_entry.get("poise_mult", 1.0)) * float(profile.get("poise_mult", 1.0)),
		true)
	damage = (6.0 + ilvl * 2.0) * dmg_mult * float(profile.get("damage_mult", 1.0))
	strike_poise = (8.0 + float(ilvl) * 2.0) * dmg_mult * float(profile.get("poise_mult", 1.0))
	knockback = 140.0 + float(ilvl) * 10.0
	armor_value = 8.0 + float(ilvl) * 5.0
	speed = maxf(1.0, spawn_speed * float(profile.get("speed_mult", 1.0)))
	attack_range = EnemyAI.reach(profile)


## Applies a biome enemy definition. Called after `_ready`, because `_ready`
## derives the base stats from `ilvl` first.
func apply_biome_enemy(entry: Dictionary, realm: int) -> void:
	_entry = entry
	if entry.is_empty():
		_recompute_stats()
		return
	display_name = String(entry.get("name", display_name))
	ilvl = maxi(1, realm + int(entry.get("ilvl_bonus", 0)))
	body_color = Color(String(entry.get("color", "#a85050")))
	set_archetype(String(entry.get("archetype", "brawler")))


## Switches the behaviour profile and rebuilds every derived number.
func set_archetype(id: String) -> void:
	archetype = id if id != "" else "brawler"
	profile = EnemyAI.profile(DB.enemy_archetype(archetype))
	_recompute_stats()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_flash = maxf(0.0, _flash - delta)
	_alert = maxf(0.0, _alert - delta)
	poise.tick(delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	animator.update(delta, velocity.length() / maxf(1.0, speed), false,
		_windup > 0.0, false, poise.is_staggered(), false, false)

	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)

	# A stagger owns the body: the wind-up is cancelled in `stagger()` and
	# nothing else may act until the meter recovers.
	if poise.is_staggered():
		state = "recover"
		velocity = _knock
		move_and_slide()
		queue_redraw()
		return

	if not aggressive:
		velocity = _knock
		move_and_slide()
		queue_redraw()
		return

	var target := Game.player as Node2D
	if target == null:
		velocity = _knock
		move_and_slide()
		queue_redraw()
		return

	flee_left = maxf(0.0, flee_left - delta)
	retreat_left = maxf(0.0, retreat_left - delta)
	_patrol_wait = maxf(0.0, _patrol_wait - delta)
	_circle_time += delta
	_circle_time = minf(_circle_time, 999.0)

	# A blow that has started cannot be re-decided: the telegraph is committed.
	if _windup > 0.0:
		_windup = maxf(0.0, _windup - delta)
		state = "windup"
		if _windup <= 0.0:
			_release_attack(target)
			state = "recover"
		velocity = _knock
		move_and_slide()
		queue_redraw()
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var seen := _provoked or EnemyAI.perceives(dist, to_target, _facing, profile)
	_provoked = false
	if seen:
		if memory <= 0.0:
			_alert = 0.6
		memory = maxf(memory, float(profile.get("memory", 0.0)))
		_last_seen = target.global_position
	else:
		memory = maxf(0.0, memory - delta)

	# Chasing a memory means walking to where the target was, not to where it is.
	var focus := target.global_position if seen else _last_seen
	if not seen and memory > 0.0 and global_position.distance_to(_last_seen) < 10.0:
		memory = 0.0
	var to_focus := focus - global_position
	var home_dist := global_position.distance_to(home)
	var in_reach := seen and dist <= EnemyAI.reach(profile) + 16.0
	# Arriving is checked before the next decision: at home the brain would
	# choose `patrol`, and a body that flipped to patrol one step short would
	# never actually finish walking home or mend.
	if state == "return" and home_dist <= EnemyAI.AT_HOME:
		_arrive_home()
		velocity = _knock
		move_and_slide()
		queue_redraw()
		return
	var facts := {
		"dist": dist,
		"home_dist": home_dist,
		"memory": memory,
		"hp_ratio": hp / maxf(1.0, hp_max),
		"flee_left": flee_left,
		"retreat_left": retreat_left,
		"seen": seen,
		"at_home": home_dist <= EnemyAI.AT_HOME,
		"ready": _cooldown <= 0.0,
		"committed": EnemyAI.may_commit(_allies_committed(target.global_position), profile),
		"flee_used": flee_used,
		"in_reach": in_reach,
	}
	var next := EnemyAI.think(facts, profile)
	if next == "flee" and flee_left <= 0.0:
		flee_left = float(profile.get("flee_time", 0.0))
		flee_used = true
	if next == "retreat" and retreat_left <= 0.0:
		retreat_left = float(profile.get("retreat_time", 0.0))

	if next == "windup":
		state = "windup"
		_windup = EnemyAI.windup_time(profile)
		# Facing is locked at the start of the telegraph, so stepping out of the
		# arc really dodges the blow.
		if to_target.length_squared() > 0.0001:
			_facing = to_target.normalized()
		velocity = _knock
		move_and_slide()
		queue_redraw()
		return

	# A circling body changes direction now and then, so a patient player can
	# read the orbit instead of being pinned to one side forever.
	if next == "circle":
		if _circle_time >= 2.4:
			_strafe = -_strafe
			_circle_time = 0.0
	else:
		_circle_time = 0.0

	state = next
	var intent := EnemyAI.move_intent(state, to_focus, dist if seen else to_focus.length(),
		profile, _strafe, home - global_position)
	if state == "patrol":
		intent = _patrol_step()
	if intent.length_squared() > 0.0001 and state != "recover":
		if state == "circle":
			_facing = _facing.lerp(intent.normalized(), 0.2).normalized()
		else:
			_facing = intent.normalized()

	var steer := intent.normalized() * speed if intent.length_squared() > 0.0001 else Vector2.ZERO
	steer += EnemyAI.separation(global_position, _ally_positions(), EnemyAI.SEPARATION_RADIUS) * speed * 0.8
	velocity = steer + _knock
	if state == "circle" and is_on_wall() and _circle_time > 0.3:
		_strafe = -_strafe
		_circle_time = 0.0
	move_and_slide()
	queue_redraw()


## A patrolling body walks one leg of a deterministic circuit around its home.
func _patrol_step() -> Vector2:
	var radius := float(profile.get("patrol_radius", 0.0))
	if radius <= 0.0 or _patrol_wait > 0.0:
		return Vector2.ZERO
	if _patrol_target == Vector2.ZERO or global_position.distance_to(_patrol_target) < 8.0:
		_patrol_phase += 0.9
		var offset := float(absi(hash(home)) % 360) * 0.01745
		var angle := _patrol_phase + offset
		_patrol_target = home + Vector2(cos(angle), sin(angle)) * radius
		_patrol_wait = PATROL_PAUSE
		return Vector2.ZERO
	return global_position.direction_to(_patrol_target)


## Back at its post a body loses interest, forgets its courage and mends.
func _arrive_home() -> void:
	state = "idle"
	memory = 0.0
	flee_left = 0.0
	retreat_left = 0.0
	flee_used = false
	_patrol_target = Vector2.ZERO
	if hp < hp_max:
		hp = hp_max
	queue_redraw()


func _allies_committed(at: Vector2) -> int:
	var count := 0
	for body in get_tree().get_nodes_in_group("enemy"):
		if body == self or not is_instance_valid(body):
			continue
		var other := body as Node2D
		if other == null or other.global_position.distance_to(at) > GROUP_RADIUS:
			continue
		var other_state: Variant = other.get("state")
		if other_state is String and String(other_state) == "windup":
			count += 1
	return count


func _ally_positions() -> Array:
	var out: Array = []
	for body in get_tree().get_nodes_in_group("enemy"):
		if body == self or not is_instance_valid(body):
			continue
		var other := body as Node2D
		if other != null:
			out.append(other.global_position)
	return out


func _release_attack(target: Node2D) -> void:
	_cooldown = EnemyAI.cooldown_time(profile)
	_strikes += 1
	if target != null:
		if EnemyAI.is_ranged(profile):
			_fire_bolt(target)
		else:
			var box := EnemyAI.strike_hitbox(profile)
			if Combat.in_hitbox(global_position, _facing, box, target.global_position, 18.0):
				if target.has_method("take_hit"):
					target.take_hit(damage, global_position, true, strike_poise, knockback, self)
	var after := int(profile.get("retreat_after", 0))
	if after > 0 and _strikes >= after:
		retreat_left = float(profile.get("retreat_time", 0.0))
		_strikes = 0
	queue_redraw()


## A Qi bolt shares `Projectile` with the player's arts, but belongs to the other
## side: it scans the `player` group and lands through the player's own
## `take_hit`, so a raised guard or a parry meets it exactly like a melee blow.
func _fire_bolt(target: Node2D) -> void:
	var spec: Dictionary = (profile.get("projectile", {}) as Dictionary).duplicate(true)
	var dir := global_position.direction_to(target.global_position)
	if dir.length_squared() < 0.0001:
		dir = _facing
	var strike := {"amount": damage, "power": 1.0, "poise": strike_poise, "knock": knockback}
	var bolt := Projectile.new()
	bolt.faction = "enemy"
	bolt.origin = global_position
	bolt.setup(dir, spec, strike, EnemyAI.telegraph_color(profile))
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(bolt)
	bolt.global_position = global_position + dir * (RADIUS + 6.0)


## A parry turns the blow back on its source. The wind-up is spoiled and the
## guard meter takes the reflected force, so a parry is a real opening.
func stagger(poise_damage: float) -> void:
	if _dead:
		return
	poise.apply(maxf(0.0, poise_damage))
	_windup = 0.0
	state = "recover"
	_cooldown = maxf(_cooldown, 0.35)
	queue_redraw()


## `penetration` is the attacker's fraction of ignored armour (0..0.6).
func take_hit(amount: float, knock: Vector2, poise_damage: float, penetration: float = 0.0) -> void:
	if _dead:
		return
	var effective_armor := armor_value * (1.0 - clampf(penetration, 0.0, 0.9))
	hp -= Damage.mitigate_armor(amount, effective_armor)
	_knock += knock * 0.12
	_flash = 0.14
	# Being hit is its own alarm: a shot from behind turns the body around.
	_provoked = true
	memory = maxf(memory, float(profile.get("memory", 0.0)))
	_last_seen = Game.player.global_position if Game.player != null else _last_seen
	if poise.apply(poise_damage):
		_knock += knock * 0.2
		_windup = 0.0
		state = "recover"
	if hp <= 0.0:
		_die()
	queue_redraw()


func _die() -> void:
	if _dead:
		return
	_dead = true
	state = "dead"
	Game.register_kill()
	Bus.enemy_died.emit(global_position, ilvl)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, 6), RADIUS * 0.9, Color(0, 0, 0, 0.28))
	var body := body_color
	if _flash > 0.0:
		body = Color("#ffffff")
	if poise.is_staggered():
		body = Color("#c8a050")
	if _windup > 0.0:
		body = Color("#e07040")

	var pose := Animator.pose(animator.state, animator.time, 0.0)
	draw_set_transform(pose["bob"], float(pose["lean"]), pose["squash"])
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -RADIUS), Vector2(RADIUS, 0), Vector2(0, RADIUS), Vector2(-RADIUS, 0),
	]), body)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color("#2a1c1c"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _windup > 0.0:
		var tint := EnemyAI.telegraph_color(profile)
		var half := deg_to_rad(float(EnemyAI.strike_hitbox(profile).get("angle", 360.0))) * 0.5
		var reach := EnemyAI.reach(profile)
		if half >= PI - 0.001:
			draw_arc(Vector2.ZERO, reach, 0.0, TAU, 32, Color(tint, 0.5), 2.0)
		else:
			draw_arc(Vector2.ZERO, reach, _facing.angle() - half, _facing.angle() + half,
				20, Color(tint, 0.6), 2.5)
		if EnemyAI.is_ranged(profile):
			draw_line(Vector2.ZERO, _facing * reach, Color(tint, 0.25), 1.0)

	# A patrolling body is awake but unaware; a fresh aggro flashes a marker.
	if _alert > 0.0:
		draw_circle(Vector2(0, -RADIUS - 20), 2.5, Color("#ffd070"))

	var ratio := clampf(hp / hp_max, 0.0, 1.0)
	draw_rect(Rect2(-18, -RADIUS - 12, 36, 4), Color("#241a1a"))
	draw_rect(Rect2(-18, -RADIUS - 12, 36 * ratio, 4), Color("#d05050"))
