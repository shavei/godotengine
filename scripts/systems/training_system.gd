class_name TrainingSystem
extends RefCounted
## Villager training (docs/GDD.md Section 5.2): Training Points set a powered villager's
## rank, Novice at 0, Adept at 3, Master at 7. The per-run tick joins in M5; for now
## only a gift's starting points (GiftSystem.give) move a villager along.

const NONE: int = 0
const NOVICE: int = 1
const ADEPT: int = 2
const MASTER: int = 3
const RANK_NAMES: Array[String] = ["No power", "Novice", "Adept", "Master"]


## NONE for a villager with no power, else the rank their Training Points reach.
static func rank(villager: VillagerState, balance: BalanceData) -> int:
	if villager == null or not villager.has_power():
		return NONE
	return rank_for_points(villager.training_points, balance)


static func rank_for_points(points: int, balance: BalanceData) -> int:
	if points >= balance.master_tp:
		return MASTER
	if points >= balance.adept_tp:
		return ADEPT
	return NOVICE


static func rank_name(rank_value: int) -> String:
	return RANK_NAMES[clampi(rank_value, NONE, MASTER)]
