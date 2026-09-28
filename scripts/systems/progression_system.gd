class_name ProgressionSystem
extends RefCounted
## Hero growth rules (docs/GDD.md Section 4.1 and 4.2): the XP curve, level-ups,
## attribute points, what attributes do, and the weapon mastery curve.
## Numbers come from BalanceData.


## XP needed to go from level `level - 1` to `level`.
static func xp_for_level(level: int, balance: BalanceData) -> int:
	return roundi(balance.xp_curve_base * pow(float(level), balance.xp_curve_exponent))


## XP still needed for the hero's next level (0 at the level cap).
static func xp_to_next(hero: HeroState, balance: BalanceData) -> int:
	if hero.level >= balance.level_cap:
		return 0
	return xp_for_level(hero.level + 1, balance)


## Adds XP, levels up as often as it allows, and grants one attribute point per level.
## Returns the number of levels gained. XP past the cap is dropped.
static func add_xp(hero: HeroState, amount: int, balance: BalanceData) -> int:
	if amount <= 0 or hero.level >= balance.level_cap:
		return 0
	hero.xp += amount
	var gained: int = 0
	while hero.level < balance.level_cap and hero.xp >= xp_for_level(hero.level + 1, balance):
		hero.xp -= xp_for_level(hero.level + 1, balance)
		hero.level += 1
		gained += 1
	if hero.level >= balance.level_cap:
		hero.xp = 0
	hero.attribute_points += gained
	return gained


## XP for clearing a room of this type (0 for rooms without a fight).
static func room_xp(room_type: StringName, balance: BalanceData) -> int:
	match room_type:
		MapRoom.COMBAT:
			return balance.xp_combat_room
		MapRoom.ELITE:
			return balance.xp_elite_room
		MapRoom.MINI_BOSS:
			return balance.xp_mini_boss
		MapRoom.BOSS:
			return balance.xp_region_boss
	return 0


static func can_spend_point(hero: HeroState, attribute_id: StringName, balance: BalanceData) -> bool:
	return hero.attribute_points > 0 and HeroState.ATTRIBUTES.has(attribute_id) \
			and hero.attribute(attribute_id) < balance.attribute_cap


## Moves one unspent point into the attribute. Returns false if it cannot.
static func spend_point(hero: HeroState, attribute_id: StringName, balance: BalanceData) -> bool:
	if not can_spend_point(hero, attribute_id, balance):
		return false
	hero.attribute_points -= 1
	hero.attributes[attribute_id] = hero.attribute(attribute_id) + 1
	return true


## Coins to reset every attribute point at the Shrine (docs/GDD.md Section 4.1).
static func respec_cost(hero: HeroState, balance: BalanceData) -> int:
	return hero.level * balance.respec_cost_per_level


static func spent_points(hero: HeroState) -> int:
	var total: int = 0
	for attribute_id: StringName in HeroState.ATTRIBUTES:
		total += hero.attribute(attribute_id)
	return total


static func can_respec(hero: HeroState, balance: BalanceData) -> bool:
	return spent_points(hero) > 0 and hero.bank.can_afford(Wallet.COINS, respec_cost(hero, balance))


## Pays the coins and turns every spent attribute point back into an unspent one.
static func respec(hero: HeroState, balance: BalanceData) -> bool:
	if not can_respec(hero, balance):
		return false
	hero.bank.spend(Wallet.COINS, respec_cost(hero, balance))
	hero.attribute_points += spent_points(hero)
	for attribute_id: StringName in HeroState.ATTRIBUTES:
		hero.attributes[attribute_id] = 0
	return true


static func max_hp(hero: HeroState, balance: BalanceData) -> int:
	return balance.hero_max_hp + (hero.level - 1) * balance.level_max_hp \
			+ hero.attribute(HeroState.VIGOR) * balance.vigor_max_hp


static func max_stamina(hero: HeroState, balance: BalanceData) -> float:
	return balance.hero_max_stamina + hero.attribute(HeroState.VIGOR) * balance.vigor_max_stamina


## Additive weapon damage bonus from Might (0.09 means +9%).
static func weapon_damage_bonus(hero: HeroState, balance: BalanceData) -> float:
	return hero.attribute(HeroState.MIGHT) * balance.might_damage


## Mastery XP earned for `damage` dealt with a weapon.
static func mastery_xp_for_damage(damage: int, balance: BalanceData) -> int:
	return floori(float(maxi(damage, 0)) / maxi(balance.mastery_damage_per_xp, 1))


## Total mastery XP needed to reach mastery `level` (level 1 needs none).
static func mastery_xp_for_level(level: int, balance: BalanceData) -> int:
	if level <= 1:
		return 0
	return roundi(balance.mastery_curve_base * pow(float(level), balance.mastery_curve_exponent))


## Mastery level (1 to cap) for a total of mastery XP.
static func mastery_level(total_xp: int, balance: BalanceData) -> int:
	var level: int = 1
	while level < balance.mastery_cap and total_xp >= mastery_xp_for_level(level + 1, balance):
		level += 1
	return level
