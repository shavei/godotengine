class_name FirstGift
extends RefCounted
## The forced first gift (docs/GDD.md Section 16, step 3): the first power a player earns
## must be given, to the villager BalanceData.first_gift_villager names (the Farmer). It
## teaches that giving is the heart of the game; every later Choice is free. If that
## villager is missing or already holds a power, nothing is forced.


## The index of the villager the waiting power must go to, or -1 when nothing is forced.
static func villager_index(profile: ProfileState, balance: BalanceData) -> int:
	if profile.first_gift_done or balance.first_gift_villager == &"":
		return -1
	var index: int = profile.village.index_of(balance.first_gift_villager)
	return index if GiftSystem.can_give(profile.village, index) else -1


## True while the first power must still be given.
static func is_active(profile: ProfileState, balance: BalanceData) -> bool:
	return villager_index(profile, balance) >= 0


## Only the forced villager can take the first gift; later gifts go to anyone free.
static func allows(profile: ProfileState, balance: BalanceData, villager_index_to_give: int) -> bool:
	var forced: int = villager_index(profile, balance)
	return forced < 0 or forced == villager_index_to_give


## Any gift ends the tutorial.
static func complete(profile: ProfileState) -> void:
	profile.first_gift_done = true


## A save from before the tutorial existed: a villager holds a power or a hero keeps one.
static func settled_before(profile: ProfileState) -> bool:
	for villager: VillagerState in profile.village.villagers:
		if villager.has_power():
			return true
	for player_id: int in profile.heroes:
		if not profile.heroes[player_id].kept_powers.is_empty():
			return true
	return false
