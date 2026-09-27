class_name EventResolver
extends RefCounted
## Event room rules (docs/GDD.md Section 6.2):
## - A choice with a cost is only possible if the hero can pay all of it.
## - Costs (currencies and HP) are paid first. An HP cost never kills.
## - Then the choice succeeds with its chance and rolls its reward, or fails and the
##   cost is gone.


static func can_choose(choice: EventChoiceData, wallet: Wallet) -> bool:
	return wallet.can_afford_all(choice.cost)


## Pays the cost from `wallet` and rolls the result. Rewards are returned, not added,
## so the room can drop them as pickups.
static func resolve(choice: EventChoiceData, wallet: Wallet, hp: int, max_hp: int, rng: RandomNumberGenerator) -> EventOutcome:
	var outcome: EventOutcome = EventOutcome.new()
	outcome.hp = hp
	if not wallet.spend_all(choice.cost):
		return outcome
	outcome.paid = true
	var hp_loss: int = mini(roundi(max_hp * choice.hp_cost_fraction), maxi(hp - 1, 0))
	outcome.hp = hp - hp_loss
	# Always draw the roll so the reward roll does not depend on the chance.
	outcome.success = rng.randf() < choice.success_chance
	if outcome.success:
		outcome.gains = LootRoller.roll(choice.reward, rng)
		outcome.hp = mini(outcome.hp + roundi(max_hp * choice.heal_fraction), max_hp)
		outcome.text = choice.success_text
	else:
		outcome.text = choice.fail_text
	return outcome


## "Toss 25 coins" style caption: the label plus what it costs.
static func caption(choice: EventChoiceData) -> String:
	var parts: PackedStringArray = []
	for currency: StringName in choice.cost:
		parts.append("%d %s" % [choice.cost[currency], Wallet.currency_name(currency).to_lower()])
	if choice.hp_cost_fraction > 0.0:
		parts.append("%d%% HP" % roundi(choice.hp_cost_fraction * 100.0))
	if parts.is_empty():
		return choice.label
	return "%s\n(%s)" % [choice.label, ", ".join(parts)]
