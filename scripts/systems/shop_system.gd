class_name ShopSystem
extends RefCounted
## Buying from villagers (docs/GDD.md Sections 4.2 and 9), paid from the hero's banked
## coins: the next weapon tier from the Smith, and priced services bought once (a Smith's
## infusion). Each check returns why something cannot be bought ("" when it can).


static func tier_count(balance: BalanceData) -> int:
	return balance.weapon_tier_multipliers.size()


static func tier_name(tier: int, balance: BalanceData) -> String:
	return balance.weapon_tier_names[tier] if tier >= 0 and tier < balance.weapon_tier_names.size() else "Tier %d" % (tier + 1)


static func tier_multiplier(tier: int, balance: BalanceData) -> float:
	if balance.weapon_tier_multipliers.is_empty():
		return 1.0
	return balance.weapon_tier_multipliers[clampi(tier, 0, balance.weapon_tier_multipliers.size() - 1)]


static func tier_price(tier: int, balance: BalanceData) -> int:
	return balance.weapon_tier_prices[tier] if tier >= 0 and tier < balance.weapon_tier_prices.size() else 0


static func tier_crystal(tier: int, balance: BalanceData) -> int:
	return balance.weapon_tier_crystal[tier] if tier >= 0 and tier < balance.weapon_tier_crystal.size() else 0


## The tier the Smith would sell next for this weapon, or -1 at the best tier.
static func next_tier(hero: HeroState, weapon_id: StringName, balance: BalanceData) -> int:
	var tier: int = hero.weapon_tier(weapon_id) + 1
	return tier if tier < tier_count(balance) else -1


## The Forge level that decides which tiers are sold: the workplace plus service bonuses.
static func forge_level(village: VillageState, smith_id: StringName, services: ModifierStack) -> int:
	return village.workplace_level(smith_id) + (services.count(ModifierStack.FORGE_BONUS) if services != null else 0)


## Why the next tier cannot be bought now ("" if it can). `smith` is the seller.
static func tier_problem(hero: HeroState, weapon_id: StringName, smith: VillagerState, forge: int, balance: BalanceData) -> String:
	var tier: int = next_tier(hero, weapon_id, balance)
	if tier < 0:
		return "Your weapon is at its best tier."
	if tier < balance.weapon_tier_forge_levels.size() and forge < balance.weapon_tier_forge_levels[tier]:
		return "%s needs Forge level %d." % [tier_name(tier, balance), balance.weapon_tier_forge_levels[tier]]
	if tier >= balance.weapon_tier_master_from and TrainingSystem.rank(smith, balance) < TrainingSystem.MASTER:
		return "%s needs a Master Smith." % tier_name(tier, balance)
	if not hero.bank.can_afford(Wallet.COINS, tier_price(tier, balance)):
		return "Not enough coins."
	if not hero.bank.can_afford(Wallet.CRYSTAL, tier_crystal(tier, balance)):
		return "Not enough Crystal."
	return ""


## Buys the next tier. Returns the new tier, or -1 if it cannot be bought.
static func buy_tier(hero: HeroState, weapon_id: StringName, smith: VillagerState, forge: int, balance: BalanceData) -> int:
	if not tier_problem(hero, weapon_id, smith, forge, balance).is_empty():
		return -1
	var tier: int = next_tier(hero, weapon_id, balance)
	hero.bank.spend_all({Wallet.COINS: tier_price(tier, balance), Wallet.CRYSTAL: tier_crystal(tier, balance)})
	hero.weapon_tiers[weapon_id] = tier
	return tier


## Why the combo's priced service cannot be bought ("" if it can).
static func service_problem(hero: HeroState, combo: ComboData) -> String:
	if combo == null or combo.novice == null or combo.novice.price <= 0:
		return "Nothing to buy."
	if hero.has_bought(combo.id):
		return "You have it already."
	if not hero.bank.can_afford(Wallet.COINS, combo.novice.price):
		return "Not enough coins."
	return ""


static func buy_service(hero: HeroState, combo: ComboData) -> bool:
	if not service_problem(hero, combo).is_empty():
		return false
	hero.bank.spend(Wallet.COINS, combo.novice.price)
	hero.bought_services.append(combo.id)
	return true
