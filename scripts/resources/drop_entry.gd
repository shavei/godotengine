class_name DropEntry
extends Resource
## One line of a DropTable: `chance` to drop `min_amount` to `max_amount` of a currency.

## A Wallet currency (&"coins", &"wood", &"crystal", &"shards" ...).
@export var currency: StringName = Wallet.COINS
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1
