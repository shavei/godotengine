class_name PowerOffer
extends RefCounted
## The region boss's reward (docs/GDD.md Section 3.1): orbs of different powers from the
## region's pool; the hero takes one and the others are lost. The offer waits in
## HeroState.power_offer (saved) until the hero takes an orb and then keeps, merges or
## leaves the power on the Choice screen.

## What the hero can do with a new power.
const KEEP: StringName = &"keep"
const MERGE: StringName = &"merge"
## Every slot is taken: let a kept power go to make room.
const REPLACE: StringName = &"replace"
## The same power is kept at the level cap: nothing to gain but a Leave.
const MAXED: StringName = &"maxed"


## The orbs' rng for a run, so co-op peers roll the same offer (docs/ARCHITECTURE.md 9).
static func rng_for(run_seed: int) -> RandomNumberGenerator:
	return LootRoller.rng_for(run_seed, -1, -1, &"power_orbs")


## `balance.boss_orb_count` different power ids from `pool`. A power the hero keeps at the
## level cap is only offered when the pool has too few others.
static func roll(pool: Array[PowerData], hero: HeroState, balance: BalanceData, rng: RandomNumberGenerator) -> Array[StringName]:
	var fresh: Array[StringName] = []
	var maxed: Array[StringName] = []
	for power: PowerData in pool:
		if power == null or power.id == &"" or fresh.has(power.id) or maxed.has(power.id):
			continue
		var kept: KeptPower = GiftSystem.find(hero, power.id)
		if kept != null and kept.level >= balance.power_level_cap:
			maxed.append(power.id)
		else:
			fresh.append(power.id)
	var count: int = maxi(balance.boss_orb_count, 0)
	var offer: Array[StringName] = _draw(fresh, count, rng)
	offer.append_array(_draw(maxed, count - offer.size(), rng))
	return offer


## Takes one orb: the offer becomes just that power. False if it was not offered.
static func take(hero: HeroState, power_id: StringName) -> bool:
	if not hero.power_offer.has(power_id):
		return false
	hero.power_offer = [power_id] as Array[StringName]
	return true


## True while the hero still has orbs to choose between.
static func is_picking(hero: HeroState) -> bool:
	return hero.power_offer.size() > 1


## The power taken and waiting for Keep, Merge or Leave, or &"".
static func waiting_power(hero: HeroState) -> StringName:
	return hero.power_offer[0] if hero.power_offer.size() == 1 else &""


## What the hero can do with `power_id`: KEEP, MERGE, REPLACE or MAXED.
static func choice_for(hero: HeroState, power_id: StringName, balance: BalanceData) -> StringName:
	if GiftSystem.can_merge(hero, power_id, balance):
		return MERGE
	if GiftSystem.find(hero, power_id) != null:
		return MAXED
	if GiftSystem.can_keep(hero, power_id, balance):
		return KEEP
	return REPLACE


## The offer is settled (kept, merged or left behind).
static func clear(hero: HeroState) -> void:
	hero.power_offer.clear()


## Up to `count` ids from `ids`, in a seeded random order.
static func _draw(ids: Array[StringName], count: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var left: Array[StringName] = ids.duplicate()
	var result: Array[StringName] = []
	while result.size() < count and not left.is_empty():
		result.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return result
