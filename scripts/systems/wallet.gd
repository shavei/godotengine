class_name Wallet
extends RefCounted
## What one hero has picked up this run (docs/GDD.md Section 9): coins, region
## materials, Crystal and Power Shards. RunState keeps one per player_id. The run's
## end (M2 PR 4) banks it into the profile.

signal changed(currency: StringName, amount: int)

const COINS: StringName = &"coins"
const WOOD: StringName = &"wood"
const ORE: StringName = &"ore"
const CRYSTAL: StringName = &"crystal"
const SHARDS: StringName = &"shards"

## HUD and pickup order, names and colors. The letter keeps them readable without color.
const INFO: Dictionary = {
	COINS: {"name": "Coins", "letter": "c", "color": Color(1.0, 0.84, 0.3)},
	WOOD: {"name": "Wood", "letter": "w", "color": Color(0.72, 0.5, 0.3)},
	ORE: {"name": "Ore", "letter": "o", "color": Color(0.62, 0.66, 0.72)},
	CRYSTAL: {"name": "Crystal", "letter": "C", "color": Color(0.55, 0.9, 1.0)},
	SHARDS: {"name": "Power Shards", "letter": "S", "color": Color(0.85, 0.55, 1.0)},
}

## currency -> amount. Only currencies the hero has touched are present.
var amounts: Dictionary[StringName, int] = {}


func amount(currency: StringName) -> int:
	return amounts.get(currency, 0)


func add(currency: StringName, value: int) -> void:
	if value <= 0:
		return
	amounts[currency] = amount(currency) + value
	changed.emit(currency, amounts[currency])


func can_afford(currency: StringName, price: int) -> bool:
	return amount(currency) >= maxi(price, 0)


## Takes `price` if the hero has it. Returns false and takes nothing otherwise.
func spend(currency: StringName, price: int) -> bool:
	if not can_afford(currency, price):
		return false
	if price > 0:
		amounts[currency] = amount(currency) - price
		changed.emit(currency, amounts[currency])
	return true


## True if every entry of `costs` (currency -> amount) is affordable.
func can_afford_all(costs: Dictionary) -> bool:
	for currency: StringName in costs:
		if not can_afford(currency, costs[currency]):
			return false
	return true


## Pays every entry of `costs`, or nothing if any is short.
func spend_all(costs: Dictionary) -> bool:
	if not can_afford_all(costs):
		return false
	for currency: StringName in costs:
		spend(currency, costs[currency])
	return true


func add_all(gains: Dictionary) -> void:
	for currency: StringName in gains:
		add(currency, gains[currency])


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for currency: StringName in amounts:
		result[String(currency)] = amounts[currency]
	return result


static func from_dict(data: Dictionary) -> Wallet:
	var wallet: Wallet = Wallet.new()
	for key: Variant in data:
		wallet.amounts[StringName(str(key))] = int(data[key])
	return wallet


static func currency_name(currency: StringName) -> String:
	return INFO.get(currency, {}).get("name", String(currency).capitalize())


static func currency_letter(currency: StringName) -> String:
	return INFO.get(currency, {}).get("letter", "?")


static func currency_color(currency: StringName) -> Color:
	return INFO.get(currency, {}).get("color", Color.WHITE)
