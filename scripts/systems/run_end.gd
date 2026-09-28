class_name RunEnd
extends RefCounted
## Closes a run (docs/GDD.md Section 2 and 6.4). Every hero in it keeps all XP and
## weapon mastery; loot is banked in full after a clear, or `death_keep_fraction` of it
## after a fall. A clear also rolls each hero's power orbs (PowerOffer). Returns one
## RunSummary per player_id for the results screen.


static func finish(run: RunState, profile: ProfileState, success: bool, balance: BalanceData) -> Dictionary[int, RunSummary]:
	var summaries: Dictionary[int, RunSummary] = {}
	var keep_fraction: float = 1.0 if success else balance.death_keep_fraction
	for player_id: int in run.player_ids():
		var hero: HeroState = profile.hero(player_id)
		var summary: RunSummary = RunSummary.new()
		summary.player_id = player_id
		summary.success = success
		summary.region_name = run.region.display_name
		summary.floor_reached = run.floor_index + 1
		summary.floor_count = run.region.floor_count
		summary.rooms_cleared = run.rooms_cleared
		summary.elapsed = run.elapsed
		summary.keep_fraction = keep_fraction
		# XP
		summary.level_before = hero.level
		summary.xp_gained = run.xp_earned(player_id)
		ProgressionSystem.add_xp(hero, summary.xp_gained, balance)
		summary.level_after = hero.level
		summary.xp_into_level = hero.xp
		summary.xp_for_next = ProgressionSystem.xp_to_next(hero, balance)
		# Weapon mastery (one weapon per run for now; the most used one is shown).
		var dealt: Dictionary = run.damage_by_weapon(player_id)
		var top_damage: int = -1
		for weapon_id: Variant in dealt:
			var before_xp: int = hero.mastery_xp(weapon_id)
			var gained: int = ProgressionSystem.mastery_xp_for_damage(int(dealt[weapon_id]), balance)
			hero.weapon_mastery[weapon_id] = before_xp + gained
			if int(dealt[weapon_id]) > top_damage:
				top_damage = int(dealt[weapon_id])
				summary.weapon_id = weapon_id
				summary.mastery_xp_gained = gained
				summary.mastery_before = ProgressionSystem.mastery_level(before_xp, balance)
				summary.mastery_after = ProgressionSystem.mastery_level(before_xp + gained, balance)
		# Loot
		var run_wallet: Wallet = run.wallet(player_id)
		for currency: StringName in run_wallet.amounts:
			summary.found[currency] = run_wallet.amount(currency)
		summary.kept = EconomySystem.bank_run_loot(run_wallet, hero.bank, keep_fraction)
		# Power orbs: only a clear earns them.
		if success:
			hero.power_offer = PowerOffer.roll(run.region.power_pool, hero, balance, PowerOffer.rng_for(run.run_seed))
			summary.power_offer = hero.power_offer.duplicate()
		summaries[player_id] = summary
	profile.run_count += 1
	if success:
		profile.runs_won += 1
	return summaries

