class_name Merchant
extends RefCounted
## A settlement merchant with a daily stock.
##
## Stock is generated from (world seed, merchant id, day) through `ItemGen`, so a
## reload on the same day shows the same goods. What the player bought is the only
## state worth saving: it is kept as item ids and filtered out when the stock is
## rebuilt, which keeps the save small and the shop honest.

const STOCK_SIZE := 6

var id := "merchant.market"
var day := -1
var stock: Array = []
var sold: Array = []


## Rebuilds stock for a new day, or fills an empty one (after a load).
func refresh(db: Node, rng: Node, today: int, min_rarity: int = 0, ilvl_bonus: int = 0) -> void:
	if today == day and not stock.is_empty():
		return
	if today != day:
		# A new day means new goods and a clean purchase record.
		sold.clear()
		stock.clear()
	day = today
	if not stock.is_empty():
		return

	var generator := ItemGen.new(db, rng)
	var ilvl := maxi(1, 2 + int(float(today) / 10.0)) + ilvl_bonus
	for i in STOCK_SIZE:
		var item := generator.generate(ilvl, hash(id) + i, today * 31 + i)
		if not item.is_empty() and min_rarity > 0 and int(item.get("rarity", 0)) < min_rarity:
			item = generator.generate(ilvl, hash(id) + i, today * 31 + i, min_rarity)
		if item.is_empty():
			continue
		if sold.has(String(item.get("id", ""))):
			continue
		stock.append(item)


## Removes a stock entry and remembers it as sold. Returns the item, or {} when
## the index is out of range.
func take(index: int) -> Dictionary:
	if index < 0 or index >= stock.size():
		return {}
	var item: Dictionary = stock[index]
	stock.remove_at(index)
	sold.append(String(item.get("id", "")))
	return item


func to_dict() -> Dictionary:
	return {"day": day, "sold": sold.duplicate()}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", -1))
	sold = (data.get("sold", []) as Array).duplicate()
	stock.clear()
