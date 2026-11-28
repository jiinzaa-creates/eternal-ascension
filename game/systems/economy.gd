class_name Economy
extends RefCounted
## Prices, as pure functions.
##
## An item already carries a `value` from generation (base value × rarity × ilvl),
## so the economy does not invent a second worth scale: merchants buy at value and
## pay a fraction of it. That keeps loot, rewards and shop prices on one curve.

const SELL_RATE := 0.4
const REST_COST := 14
## Selling is deliberately lossy; buying and selling the same item must never be a
## profit loop.
const MIN_SELL := 1


static func buy_price(item: Dictionary) -> int:
	return maxi(1, int(ceil(float(item.get("value", 1)))))


static func sell_price(item: Dictionary) -> int:
	return maxi(MIN_SELL, int(floor(float(item.get("value", 1)) * SELL_RATE)))


## What a merchant pays for a whole stack. One stack is sold as a stack, not one
## unit at a time, so the price has to scale with what is actually handed over.
static func sell_value(item: Dictionary) -> int:
	return sell_price(item) * maxi(1, int(item.get("count", 1)))


## Presence at the stall (R5): CHAR's social score, which nothing
## read before, now buys a discount - a quarter off at the very
## most. Buy side only, like the faction multiplier beside it:
## selling stays on the one value curve, so a silver tongue can
## never become a money loop.
static func social_multiplier(score: float) -> float:
	return 1.0 - clampf(score * 0.004, 0.0, 0.25)


## Where a market sits moves what it charges: a deterministic
## factor per region, 0.85-1.20, rolled from the region's index
## so the same town always prices the same way. Buy side only -
## selling stays on the one curve, per the doctrine above.
static func region_factor(region_index: int) -> float:
	if region_index < 0:
		return 1.0
	return 0.85 + float(abs(hash(region_index * 7919)) % 36) / 100.0


static func region_price_note(region_index: int) -> String:
	var factor := region_factor(region_index)
	if factor > 1.05:
		return "prices run high here"
	if factor < 0.95:
		return "prices run low here"
	return "prices are fair here"


static func rest_cost() -> int:
	return REST_COST


static func can_afford(stones: int, price: int) -> bool:
	return stones >= price


## Stones left after a purchase, or -1 when it cannot be afforded.
static func after_purchase(stones: int, price: int) -> int:
	if not can_afford(stones, price):
		return -1
	return stones - price
