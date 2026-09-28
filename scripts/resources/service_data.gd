class_name ServiceData
extends Resource
## What a villager does for the hero (docs/ARCHITECTURE.md Section 4.1): a base service
## with no power, or the Novice or Adept service of a villager+power combo. Its modifiers
## go into the ModifierStack for every run. A service with a price is bought once, per
## hero, at the villager's workplace (a Smith infusion); until then it does nothing.

@export_multiline var description: String = ""
@export var modifiers: Array[ModifierData] = []
## Coins to buy it once (0 = always on). An Adept upgrade needs the Novice one bought.
@export var price: int = 0
## The name it has in a shop ("Fire infusion").
@export var shop_name: String = ""
## The villager sells weapon tiers (the Smith's base service).
@export var sells_weapon_tiers: bool = false


## Every modifier works in raids only (a Guard's service before raids exist).
func only_in_raids() -> bool:
	if modifiers.is_empty():
		return false
	for modifier: ModifierData in modifiers:
		if not String(modifier.target).begins_with(ModifierStack.RAID_PREFIX):
			return false
	return true
