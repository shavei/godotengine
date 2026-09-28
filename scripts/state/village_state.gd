class_name VillageState
extends RefCounted
## The village (docs/ARCHITECTURE.md Section 4.2): who lives there, on which plot, and
## the powers they hold. Shared by every hero in a co-op party. Renown points come from
## the villagers (RenownSystem); buildings and raids join in later milestones.

## House plots the village starts with (docs/GDD.md Section 5.4).
const START_PLOTS: int = 6
## Buildings arrive in M6. Until then every workplace counts as level 2, so the Smith
## sells Steel (it needs Forge level 2). Only weapon tiers read it for now.
const WORKPLACE_LEVEL_UNTIL_M6: int = 2

var villagers: Array[VillagerState] = []
var plot_count: int = START_PLOTS
## The highest Renown level the village has shown (its level-up moment plays once).
## -1 in saves from before Renown: the village takes the current level without a moment.
var renown_seen: int = 1
## Renown points added by the debug console (add_renown). 0 in real play.
var bonus_renown: int = 0


## The villager with this job, or null if they have not arrived.
func find(villager_id: StringName) -> VillagerState:
	for villager: VillagerState in villagers:
		if villager.villager_id == villager_id:
			return villager
	return null


## The level of a villager's workplace (the Smith's Forge).
func workplace_level(_villager_id: StringName) -> int:
	return WORKPLACE_LEVEL_UNTIL_M6


func index_of(villager_id: StringName) -> int:
	return villagers.find(find(villager_id))


## The villager on this plot, or null if it is empty.
func on_plot(plot: int) -> VillagerState:
	for villager: VillagerState in villagers:
		if villager.plot == plot:
			return villager
	return null


## Moves in every villager whose Renown level is reached and who is not here yet, on
## their home plot if free, else the first free one. Returns the new arrivals.
func admit(roster: Array[VillagerData], renown_level: int) -> Array[VillagerState]:
	var sorted: Array[VillagerData] = roster.duplicate()
	sorted.sort_custom(func(a: VillagerData, b: VillagerData) -> bool: return a.home_plot < b.home_plot)
	var arrived: Array[VillagerState] = []
	for data: VillagerData in sorted:
		if data.arrives_at_renown > renown_level or find(data.id) != null:
			continue
		var plot: int = data.home_plot if on_plot(data.home_plot) == null else _free_plot()
		if plot < 0 or plot >= plot_count:
			continue
		var villager: VillagerState = VillagerState.create(data.id, plot)
		villagers.append(villager)
		arrived.append(villager)
	return arrived


func _free_plot() -> int:
	for plot: int in plot_count:
		if on_plot(plot) == null:
			return plot
	return -1


func to_dict() -> Dictionary:
	return {
		"plot_count": plot_count,
		"renown_seen": renown_seen,
		"bonus_renown": bonus_renown,
		"villagers": villagers.map(func(villager: VillagerState) -> Dictionary: return villager.to_dict()),
	}


static func from_dict(data: Dictionary) -> VillageState:
	var village: VillageState = VillageState.new()
	village.plot_count = maxi(START_PLOTS, int(data.get("plot_count", START_PLOTS)))
	village.renown_seen = int(data.get("renown_seen", -1))
	village.bonus_renown = int(data.get("bonus_renown", 0))
	for entry: Variant in data.get("villagers", []):
		if entry is Dictionary:
			var villager: VillagerState = VillagerState.from_dict(entry)
			if villager.villager_id != &"" and village.find(villager.villager_id) == null:
				village.villagers.append(villager)
	return village
