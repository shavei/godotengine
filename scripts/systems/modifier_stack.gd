class_name ModifierStack
extends RefCounted
## One place for all stat math from outside the hero's own progress (docs/ARCHITECTURE.md
## Section 5). collect() gathers the village's services for one hero; total() adds up a
## target: (base + every "add") * every "mul". Techniques, Neighbor bonuses, meals and
## trinkets join the same stack later.
##
## Services: every villager's base service always counts. A villager holding a power adds
## the combo's Novice service, and from Adept on its Adept service too (Adept adds to
## Novice). A priced service counts only once the hero has bought it.

# Hero
const MAX_HP: StringName = &"hero.max_hp"
## Share of max HP added (0.15 = +15%), after the flat bonus.
const MAX_HP_SHARE: StringName = &"hero.max_hp_share"
## Added to damage taken (-0.1 = 10% less).
const DAMAGE_TAKEN: StringName = &"hero.damage_taken"
## Chance a weapon hit applies the status.
const WEAPON_BURN_CHANCE: StringName = &"hero.weapon_burn_chance"
const WEAPON_CHILL_CHANCE: StringName = &"hero.weapon_chill_chance"
## Extra share of a weapon hit's stagger (0.25 = +25%).
const WEAPON_STAGGER: StringName = &"hero.weapon_stagger"
## Weapon damage per fight room cleared without being hit, and the most it can reach.
const MENDING_STEP: StringName = &"hero.mending_step"
const MENDING_CAP: StringName = &"hero.mending_cap"
## HP healed for every fight room cleared.
const HEAL_PER_ROOM: StringName = &"hero.heal_per_room"
## Share added to a flask's heal (0.25 = +25%).
const FLASK_HEAL: StringName = &"hero.flask_heal"
## Share of max HP a flask also heals over BalanceData.flask_regen_time.
const FLASK_REGEN: StringName = &"hero.flask_regen"
## Share of max HP added to a revive (on top of BalanceData.revive_hp_fraction).
const REVIVE_HP: StringName = &"hero.revive_hp"
## Damage of the fire burst a revive sets off (0 = none).
const REVIVE_BLAST: StringName = &"hero.revive_blast"
# Run
const FLASK_CHARGES: StringName = &"run.flask_charges"
const REVIVES: StringName = &"run.revives"
## "income.<currency>": banked after every run, won or lost (never halved).
const INCOME_PREFIX: String = "income."
# Village
## Levels added to the Forge when it decides which weapon tiers are sold.
const FORGE_BONUS: StringName = &"smith.forge_bonus"
## "raid.<effect>": collected for raids (M6), unused until then.
const RAID_PREFIX: String = "raid."

## Conditions a room can switch on.
const BOSS_ROOM: StringName = &"boss_room"

var modifiers: Array[ModifierData] = []


func add(modifier: ModifierData) -> void:
	if modifier != null:
		modifiers.append(modifier)


func add_all(list: Array[ModifierData]) -> void:
	for modifier: ModifierData in list:
		add(modifier)


## (base + every "add") * every "mul" for `target`, counting only modifiers with no
## condition or one of `conditions`.
func total(target: StringName, base: float = 0.0, conditions: Array[StringName] = []) -> float:
	var added: float = 0.0
	var factor: float = 1.0
	for modifier: ModifierData in modifiers:
		if modifier.target != target:
			continue
		if modifier.condition != &"" and not conditions.has(modifier.condition):
			continue
		if modifier.op == ModifierData.MUL:
			factor *= modifier.value
		else:
			added += modifier.value
	return (base + added) * factor


## The whole-number total (flask charges, revives, coins).
func count(target: StringName, base: int = 0) -> int:
	return roundi(total(target, base))


func has(target: StringName) -> bool:
	for modifier: ModifierData in modifiers:
		if modifier.target == target:
			return true
	return false


## currency -> amount banked after every run.
func income() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for modifier: ModifierData in modifiers:
		var target: String = String(modifier.target)
		if not target.begins_with(INCOME_PREFIX):
			continue
		var currency: StringName = StringName(target.trim_prefix(INCOME_PREFIX))
		if not result.has(currency):
			result[currency] = count(modifier.target)
	return result


## Everything the village does for `hero`. `villagers` and `combos` are the content
## (ContentDB lists in the game).
static func collect(hero: HeroState, village: VillageState, balance: BalanceData,
		villagers: Array[VillagerData], combos: Array[ComboData]) -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	if village == null:
		return stack
	for villager: VillagerState in village.villagers:
		for service: ServiceData in active_services(villager, hero, balance, _find_villager(villagers, villager.villager_id), combos):
			stack.add_all(service.modifiers)
	return stack


## The services of one villager that count for `hero` right now: the base service, then
## the combo's Novice and (from Adept) Adept services once bought, if priced.
static func active_services(villager: VillagerState, hero: HeroState, balance: BalanceData,
		data: VillagerData, combos: Array[ComboData]) -> Array[ServiceData]:
	var services: Array[ServiceData] = []
	if data != null and data.base_service != null:
		services.append(data.base_service)
	var combo: ComboData = find_combo(combos, villager.villager_id, villager.power_id) if villager.has_power() else null
	if combo == null or not is_unlocked(combo, hero):
		return services
	var rank: int = TrainingSystem.rank(villager, balance)
	if combo.novice != null:
		services.append(combo.novice)
	if rank >= TrainingSystem.ADEPT and combo.adept != null:
		services.append(combo.adept)
	return services


## A combo's services work for `hero`: free, or bought already.
static func is_unlocked(combo: ComboData, hero: HeroState) -> bool:
	if combo.novice == null or combo.novice.price <= 0:
		return true
	return hero != null and hero.has_bought(combo.id)


static func find_combo(combos: Array[ComboData], villager_id: StringName, power_id: StringName) -> ComboData:
	var combo_id: StringName = ComboData.id_for(villager_id, power_id)
	for combo: ComboData in combos:
		if combo.id == combo_id:
			return combo
	return null


static func _find_villager(villagers: Array[VillagerData], villager_id: StringName) -> VillagerData:
	for data: VillagerData in villagers:
		if data.id == villager_id:
			return data
	return null
