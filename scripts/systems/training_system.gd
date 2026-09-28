class_name TrainingSystem
extends RefCounted
## Villager training (docs/GDD.md Section 5.2): Training Points set a powered villager's
## rank, Novice at 0, Adept at 3, Master at 7. Every villager holding a power gains 1 TP
## per run attempted (win or lose), at the training tick after the run's power is settled.
## A run leaves its tick waiting in `ProfileState.training_due`; the village applies it
## (`train_due`) once nothing waits at the Shrine, so a power given after a run trains
## with that run.

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


## Training Points the next rank needs, or 0 at Master (or with no power).
static func next_rank_points(villager: VillagerState, balance: BalanceData) -> int:
	match rank(villager, balance):
		NOVICE:
			return balance.adept_tp
		ADEPT:
			return balance.master_tp
	return 0


## "Novice 2/3", "Adept 5/7", "Master" (or "" with no power).
static func progress_text(villager: VillagerState, balance: BalanceData) -> String:
	var rank_value: int = rank(villager, balance)
	if rank_value == NONE:
		return ""
	var next: int = next_rank_points(villager, balance)
	if next == 0:
		return rank_name(rank_value)
	return "%s %d/%d" % [rank_name(rank_value), villager.training_points, next]


## One training tick: +1 TP for every villager holding a power. Returns the rank-ups, in
## village order.
static func tick(village: VillageState, balance: BalanceData) -> Array[RankUp]:
	var rank_ups: Array[RankUp] = []
	for villager: VillagerState in village.villagers:
		if not villager.has_power():
			continue
		var before: int = rank(villager, balance)
		villager.training_points += 1
		var after: int = rank(villager, balance)
		if after > before:
			rank_ups.append(RankUp.create(villager, before, after))
	return rank_ups


## Applies every tick the profile's runs left waiting. Returns the rank-ups in order.
static func train_due(profile: ProfileState, balance: BalanceData) -> Array[RankUp]:
	var rank_ups: Array[RankUp] = []
	while profile.training_due > 0:
		profile.training_due -= 1
		rank_ups.append_array(tick(profile.village, balance))
	return rank_ups


## What the waiting ticks will do, without changing the village (the results screen's
## training preview). One entry per powered villager, with the rank they will reach.
static func preview(village: VillageState, balance: BalanceData, ticks: int) -> Array[RankUp]:
	var result: Array[RankUp] = []
	for villager: VillagerState in village.villagers:
		if not villager.has_power():
			continue
		var before: int = rank(villager, balance)
		var entry: RankUp = RankUp.create(villager, before, rank_for_points(villager.training_points + ticks, balance))
		entry.training_points = villager.training_points + ticks
		result.append(entry)
	return result
