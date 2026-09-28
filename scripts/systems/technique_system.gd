class_name TechniqueSystem
extends RefCounted
## Techniques (docs/GDD.md Section 4.5): a villager who reaches Master with a power teaches
## the hero that combo's Technique, once, for good. Who still has a lesson to give is
## worked out from the village and the hero (a Master whose Technique the hero does not
## know), so nothing can drift, and in co-op every hero learns from every Master.
## Learned Technique ids live in HeroState.techniques; their modifiers join the hero's
## ModifierStack (ModifierStack.collect) and their behaviors ride along in runs.


static func knows(hero: HeroState, technique_id: StringName) -> bool:
	return hero != null and hero.techniques.has(technique_id)


## The combos whose Master can teach `hero` something new, in village order.
static func lessons(hero: HeroState, village: VillageState, balance: BalanceData, combos: Array[ComboData]) -> Array[ComboData]:
	var result: Array[ComboData] = []
	if hero == null or village == null:
		return result
	for villager: VillagerState in village.villagers:
		if TrainingSystem.rank(villager, balance) != TrainingSystem.MASTER:
			continue
		var combo: ComboData = ModifierStack.find_combo(combos, villager.villager_id, villager.power_id)
		if combo != null and combo.technique != null and not knows(hero, combo.technique.id):
			result.append(combo)
	return result


## Teaches `hero` a Technique. Returns false if they already know it.
static func learn(hero: HeroState, technique_id: StringName) -> bool:
	if hero == null or technique_id == &"" or knows(hero, technique_id):
		return false
	hero.techniques.append(technique_id)
	return true


## The Techniques `hero` knows, from `all` (ContentDB's list in the game), in learned order.
static func known(hero: HeroState, all: Array[TechniqueData]) -> Array[TechniqueData]:
	var result: Array[TechniqueData] = []
	if hero == null:
		return result
	for technique_id: StringName in hero.techniques:
		for technique: TechniqueData in all:
			if technique.id == technique_id:
				result.append(technique)
				break
	return result


## The villager combo that teaches `technique_id`, or null.
static func teacher(combos: Array[ComboData], technique_id: StringName) -> ComboData:
	for combo: ComboData in combos:
		if combo.technique != null and combo.technique.id == technique_id:
			return combo
	return null
