class_name Defense
extends RefCounted
## Guarding, parrying and guard break: the defensive half of the combat layer.
##
## Guarding is a stance, not an ability. Holding the guard key raises a frontal
## ward: blows met at its edge are paid for in Qi, and the first moments of the
## stance are a parry window where a blow is turned aside for free and thrown
## back at the attacker. When the body cannot pay, the ward breaks instead —
## the blow lands harder than it would have unguarded, and the body staggers.
##
## Nothing here touches nodes. The entities own the timers and positions and
## pass plain values in, so every rule below runs headlessly and is tested.

## Seconds at the start of a guard where a blow is parried rather than blocked.
const PARRY_WINDOW := 0.22
## Physical damage a blocked blow still deals, before armour and resistances.
const BLOCK_DAMAGE_MULT := 0.35
## A broken guard lets the blow through with interest.
const GUARD_BREAK_MULT := 1.25
## The ward only covers the front: full angle in degrees, centred on facing.
const GUARD_ARC := 140.0
## Qi spent per point of raw incoming damage, plus a floor per blow.
const QI_PER_DAMAGE := 0.8
const QI_BASE_COST := 3.0
## Seconds a broken guard cannot be raised again.
const BREAK_RECOVERY := 1.6
## How much of the parry's reflected poise comes from strength.
const PARRY_REFLECT := 1.5


## The stance this body is in. A broken guard outranks whatever the hands are
## doing: the ward failed and cannot be trusted again until it recovers.
static func state_for(holding: bool, elapsed: float, broken: float) -> String:
	if broken > 0.0:
		return "broken"
	if not holding:
		return "none"
	return "parry" if elapsed <= PARRY_WINDOW else "block"


static func is_guarding(state: String) -> bool:
	return state == "parry" or state == "block"


## Whether a blow arriving from `from_dir` is inside the ward's arc. A body with
## no facing, or a blow with no origin (a hazard, a curse), is never covered.
static func covers(facing: Vector2, from_dir: Vector2, arc := GUARD_ARC) -> bool:
	if facing.length_squared() < 0.0001 or from_dir.length_squared() < 0.0001:
		return false
	return absf(facing.normalized().angle_to(from_dir.normalized())) <= deg_to_rad(arc) * 0.5


## Qi a blow costs when it is blocked. A parry is free, because the whole point
## of meeting a blow in the window is that it never reaches the ward.
static func qi_cost(raw: float, state: String) -> float:
	if state != "block":
		return 0.0
	return QI_BASE_COST + maxf(0.0, raw) * QI_PER_DAMAGE


## Whether a reserve can pay for this blow. Checked before the blow lands, so a
## guard never half-blocks: it either holds or breaks.
static func can_pay(qi: float, raw: float) -> bool:
	return qi >= QI_BASE_COST + maxf(0.0, raw) * QI_PER_DAMAGE


## Damage multiplier for the stance the blow meets.
static func damage_multiplier(state: String) -> float:
	match state:
		"parry":
			return 0.0
		"block":
			return BLOCK_DAMAGE_MULT
		"broken":
			return GUARD_BREAK_MULT
	return 1.0


## Poise the blow still spends. A held ward spends Qi, not poise; a broken one
## staggers harder than an open body would.
static func poise_multiplier(state: String) -> float:
	if is_guarding(state):
		return 0.0
	return GUARD_BREAK_MULT if state == "broken" else 1.0


## Poise a parry throws back at the attacker: the body's own strength turned
## against it, so a strong cultivator's riposte is heavier than a weak one's.
static func reflected_poise(stats: StatBlock) -> float:
	return (12.0 + Attributes.soft(float(stats.get_attr("str")), 24.0)) * PARRY_REFLECT


## A short line for the HUD; it never invents a stance the rules do not have.
static func label(state: String) -> String:
	match state:
		"parry":
			return "parry window"
		"block":
			return "raised"
		"broken":
			return "BROKEN"
	return "ready"
