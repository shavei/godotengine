class_name GiftSystem
extends RefCounted
## The Choice rules (docs/GDD.md Section 3): keep a power in one of the 3 slots, or merge
## it into the same kept power for +1 level, or let a kept power go to make room. Kept powers also level up with banked Power
## Shards (GDD 4.3). Giving to villagers joins in M4.
## Callers emit the EventBus signals (power_kept, power_merged, power_leveled).


static func slot_count(balance: BalanceData) -> int:
	return maxi(balance.kept_power_slots, 0)


## The hero's kept copy of `power_id`, or null.
static func find(hero: HeroState, power_id: StringName) -> KeptPower:
	for kept: KeptPower in hero.kept_powers:
		if kept.power_id == power_id:
			return kept
	return null


static func has_free_slot(hero: HeroState, balance: BalanceData) -> bool:
	return hero.kept_powers.size() < slot_count(balance)


## A new power fits if the hero does not keep it yet (that is a merge) and a slot is free.
static func can_keep(hero: HeroState, power_id: StringName, balance: BalanceData) -> bool:
	return power_id != &"" and find(hero, power_id) == null and has_free_slot(hero, balance)


## Puts the power in the next free slot at level 1. Returns it, or null if it cannot.
static func keep(hero: HeroState, power_id: StringName, balance: BalanceData, run_number: int = 0) -> KeptPower:
	if not can_keep(hero, power_id, balance):
		return null
	var kept: KeptPower = KeptPower.create(power_id, 1, run_number)
	hero.kept_powers.append(kept)
	return kept


## Merging needs the same power kept below the level cap.
static func can_merge(hero: HeroState, power_id: StringName, balance: BalanceData) -> bool:
	var kept: KeptPower = find(hero, power_id)
	return kept != null and kept.level < balance.power_level_cap


## Raises the kept copy by one level. Returns the new level, or 0 if it cannot.
static func merge(hero: HeroState, power_id: StringName, balance: BalanceData, run_number: int = 0) -> int:
	if not can_merge(hero, power_id, balance):
		return 0
	var kept: KeptPower = find(hero, power_id)
	kept.level += 1
	kept.last_leveled_run = run_number
	return kept.level


## Shards the next level of a kept power costs; 0 if it is not kept or at the cap.
static func level_up_cost(hero: HeroState, power_id: StringName, balance: BalanceData) -> int:
	var kept: KeptPower = find(hero, power_id)
	return PowerRules.level_up_cost(kept.level, balance) if kept != null else 0


## A kept power below the cap whose next level the bank can pay for.
static func can_level_up(hero: HeroState, power_id: StringName, balance: BalanceData) -> bool:
	var kept: KeptPower = find(hero, power_id)
	return kept != null and kept.level < balance.power_level_cap \
			and hero.bank.can_afford(Wallet.SHARDS, PowerRules.level_up_cost(kept.level, balance))


## Spends banked shards for +1 level. Returns the new level, or 0 if it cannot.
static func level_up(hero: HeroState, power_id: StringName, balance: BalanceData, run_number: int = 0) -> int:
	if not can_level_up(hero, power_id, balance):
		return 0
	var kept: KeptPower = find(hero, power_id)
	hero.bank.spend(Wallet.SHARDS, PowerRules.level_up_cost(kept.level, balance))
	kept.level += 1
	kept.last_leveled_run = run_number
	return kept.level


## Every slot is full: `old_id` leaves its slot and `new_id` takes that same slot at
## level 1. Returns the power let go (the gift flow in M4 hands it on), or null.
static func replace(hero: HeroState, old_id: StringName, new_id: StringName, run_number: int = 0) -> KeptPower:
	var old: KeptPower = find(hero, old_id)
	if old == null or new_id == &"" or find(hero, new_id) != null:
		return null
	hero.kept_powers[hero.kept_powers.find(old)] = KeptPower.create(new_id, 1, run_number)
	return old


## Takes a power out of its slot (the gift flow in M4 hands it on). Later slots move up.
static func release(hero: HeroState, power_id: StringName) -> KeptPower:
	var kept: KeptPower = find(hero, power_id)
	if kept != null:
		hero.kept_powers.erase(kept)
	return kept
