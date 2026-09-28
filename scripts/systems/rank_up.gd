class_name RankUp
extends RefCounted
## A villager reaching a new rank at a training tick (TrainingSystem.tick), for the
## village to present (docs/GDD.md Section 5.2).

var villager_id: StringName
var power_id: StringName
var rank_before: int = TrainingSystem.NONE
var rank_after: int = TrainingSystem.NONE
## The villager's Training Points after the tick.
var training_points: int = 0


static func create(villager: VillagerState, before: int, after: int) -> RankUp:
	var event: RankUp = RankUp.new()
	event.villager_id = villager.villager_id
	event.power_id = villager.power_id
	event.rank_before = before
	event.rank_after = after
	event.training_points = villager.training_points
	return event


func is_rank_up() -> bool:
	return rank_after > rank_before


func is_master() -> bool:
	return rank_after == TrainingSystem.MASTER and rank_before < TrainingSystem.MASTER
