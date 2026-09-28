class_name EconomySystem
extends RefCounted
## Money rules at the end of a run (docs/GDD.md Section 6.4 and 9): a hero who clears the
## region banks all their run loot; a hero who falls keeps only a share of it.


## How much of `amount` is kept at `keep_fraction` (rounded down, never negative).
static func kept_amount(amount: int, keep_fraction: float) -> int:
	return maxi(0, floori(amount * clampf(keep_fraction, 0.0, 1.0)))


## Moves the run's loot into the hero's bank, keeping `keep_fraction` of each currency.
## Returns what was banked (currency -> amount).
static func bank_run_loot(run_wallet: Wallet, bank: Wallet, keep_fraction: float) -> Dictionary[StringName, int]:
	var kept: Dictionary[StringName, int] = {}
	for currency: StringName in run_wallet.amounts:
		var amount: int = kept_amount(run_wallet.amount(currency), keep_fraction)
		kept[currency] = amount
		bank.add(currency, amount)
	return kept
