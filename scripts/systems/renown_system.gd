class_name RenownSystem
extends RefCounted
## Renown (docs/GDD.md Section 5.5): how far the village has grown. Points come from what
## the village holds, so they can never drift from it: +1 for every gift (every villager
## holding a power) and +2 for every Master. Raids won and building levels join in M6.
## Levels 1 to 10 follow `BalanceData.renown_levels`; a level moves in the villagers who
## arrive at it (VillageState.admit).


## Renown points the village has earned.
static func points(village: VillageState, balance: BalanceData) -> int:
	var total: int = 0
	for villager: VillagerState in village.villagers:
		if not villager.has_power():
			continue
		total += balance.renown_per_gift
		if TrainingSystem.rank(villager, balance) == TrainingSystem.MASTER:
			total += balance.renown_per_master
	return total


## The Renown level for `renown_points` (1 at 0 points).
static func level_for(renown_points: int, balance: BalanceData) -> int:
	var result: int = 1
	for i: int in balance.renown_levels.size():
		if renown_points >= balance.renown_levels[i]:
			result = i + 1
	return result


static func level(village: VillageState, balance: BalanceData) -> int:
	return level_for(points(village, balance), balance)


## Points the next level needs, or -1 at the top level.
static func next_level_points(renown_level: int, balance: BalanceData) -> int:
	if renown_level >= balance.renown_levels.size():
		return -1
	return balance.renown_levels[renown_level]


## "Renown 1 (2/4)" or "Renown 10" at the top.
static func text(village: VillageState, balance: BalanceData) -> String:
	var renown_points: int = points(village, balance)
	var renown_level: int = level_for(renown_points, balance)
	var next: int = next_level_points(renown_level, balance)
	if next < 0:
		return "Renown %d" % renown_level
	return "Renown %d (%d/%d)" % [renown_level, renown_points, next]


## The villagers who move in at exactly this Renown level.
static func arrivals_at(renown_level: int, roster: Array[VillagerData]) -> Array[VillagerData]:
	var result: Array[VillagerData] = []
	for data: VillagerData in roster:
		if data.arrives_at_renown == renown_level:
			result.append(data)
	return result
