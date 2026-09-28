class_name GiftSystem
extends RefCounted
## The Choice rules (docs/GDD.md Section 3): keep a power in one of the 3 slots, or merge
## it into the same kept power for +1 level. Giving to villagers joins in M4.
## Callers emit the EventBus signals (power_kept, power_merged).


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


## Takes a power out of its slot (the gift flow in M4 hands it on). Later slots move up.
static func release(hero: HeroState, power_id: StringName) -> KeptPower:
	var kept: KeptPower = find(hero, power_id)
	if kept != null:
		hero.kept_powers.erase(kept)
	return kept
