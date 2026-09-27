class_name LootRoller
extends RefCounted
## Rolls DropTables with a seeded RNG, so co-op peers agree on loot
## (docs/ARCHITECTURE.md Section 9). Each entry rolls on its own chance.


## currency -> amount. Currencies that rolled nothing are left out.
static func roll(table: DropTable, rng: RandomNumberGenerator) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if table == null:
		return result
	for entry: DropEntry in table.entries:
		if entry == null or entry.max_amount <= 0:
			continue
		# Always draw the chance roll so one entry never shifts another's result.
		var hit: bool = rng.randf() < entry.chance
		var low: int = maxi(entry.min_amount, 0)
		var amount: int = rng.randi_range(low, maxi(low, entry.max_amount))
		if hit and amount > 0:
			result[entry.currency] = result.get(entry.currency, 0) + amount
	return result


## Splits `amount` into pickup piles of at most `pile_size`, using at most `max_piles`
## piles (the last piles grow instead). Coins pop out as a small shower this way.
static func split_piles(amount: int, pile_size: int, max_piles: int) -> Array[int]:
	var piles: Array[int] = []
	if amount <= 0:
		return piles
	var count: int = clampi(ceili(float(amount) / maxi(pile_size, 1)), 1, maxi(max_piles, 1))
	var base: int = floori(float(amount) / count)
	for i: int in count:
		piles.append(base + (1 if i < amount % count else 0))
	return piles


## The same seed for the same room and drop, so rerolls need a new `salt`.
static func rng_for(run_seed: int, floor_index: int, room_id: int, salt: Variant) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, floor_index, room_id, salt])
	return rng
