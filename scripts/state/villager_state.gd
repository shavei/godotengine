class_name VillagerState
extends RefCounted
## One villager living in the village (docs/ARCHITECTURE.md Section 4.2): their plot and
## the power they hold (for good) with its Training Points. Rank comes from the points
## (TrainingSystem.rank). GiftSystem.give sets the power.

var villager_id: StringName
## House plot index (0 to VillageState.plot_count - 1).
var plot: int = 0
## The power given to them, or &"" if none. Gifts are permanent.
var power_id: StringName = &""
var training_points: int = 0


static func create(id: StringName, plot_index: int) -> VillagerState:
	var villager: VillagerState = VillagerState.new()
	villager.villager_id = id
	villager.plot = plot_index
	return villager


func has_power() -> bool:
	return power_id != &""


func to_dict() -> Dictionary:
	return {
		"villager_id": String(villager_id),
		"plot": plot,
		"power_id": String(power_id),
		"training_points": training_points,
	}


static func from_dict(data: Dictionary) -> VillagerState:
	var villager: VillagerState = create(StringName(str(data.get("villager_id", ""))), int(data.get("plot", 0)))
	villager.power_id = StringName(str(data.get("power_id", "")))
	villager.training_points = maxi(0, int(data.get("training_points", 0)))
	return villager
