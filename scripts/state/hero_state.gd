class_name HeroState
extends RefCounted
## One hero's long-term progress (docs/ARCHITECTURE.md Section 4.2): level, XP,
## attributes, weapon mastery, banked loot, kept powers and a boss's power offer. ProfileState keeps one per
## player_id. Techniques join in M5. GiftSystem enforces the kept power rules.

const MIGHT: StringName = &"might"
const VIGOR: StringName = &"vigor"
const FOCUS: StringName = &"focus"
const ATTRIBUTES: Array[StringName] = [MIGHT, VIGOR, FOCUS]

var level: int = 1
## XP toward the next level (resets at each level-up).
var xp: int = 0
## Attribute points earned but not spent yet.
var attribute_points: int = 0
var attributes: Dictionary[StringName, int] = {MIGHT: 0, VIGOR: 0, FOCUS: 0}
## weapon_id -> total mastery XP.
var weapon_mastery: Dictionary[StringName, int] = {}
## Banked loot: coins, materials, Crystal and Power Shards, by Wallet currency.
var bank: Wallet = Wallet.new()
## Kept powers in slot order (at most BalanceData.kept_power_slots).
var kept_powers: Array[KeptPower] = []
## The region boss's power orbs not settled yet (PowerOffer): two or more to pick from,
## then the one taken until it is kept, merged or left behind. Empty most of the time.
var power_offer: Array[StringName] = []


func attribute(attribute_id: StringName) -> int:
	return attributes.get(attribute_id, 0)


func mastery_xp(weapon_id: StringName) -> int:
	return weapon_mastery.get(weapon_id, 0)


func to_dict() -> Dictionary:
	var attrs: Dictionary = {}
	for key: StringName in attributes:
		attrs[String(key)] = attributes[key]
	var mastery: Dictionary = {}
	for key: StringName in weapon_mastery:
		mastery[String(key)] = weapon_mastery[key]
	return {
		"level": level,
		"xp": xp,
		"attribute_points": attribute_points,
		"attributes": attrs,
		"weapon_mastery": mastery,
		"bank": bank.to_dict(),
		"kept_powers": kept_powers.map(func(kept: KeptPower) -> Dictionary: return kept.to_dict()),
		"power_offer": power_offer.map(func(id: StringName) -> String: return String(id)),
	}


static func from_dict(data: Dictionary) -> HeroState:
	var hero: HeroState = HeroState.new()
	hero.level = maxi(1, int(data.get("level", 1)))
	hero.xp = maxi(0, int(data.get("xp", 0)))
	hero.attribute_points = maxi(0, int(data.get("attribute_points", 0)))
	var attrs: Dictionary = data.get("attributes", {})
	for key: Variant in attrs:
		hero.attributes[StringName(str(key))] = int(attrs[key])
	var mastery: Dictionary = data.get("weapon_mastery", {})
	for key: Variant in mastery:
		hero.weapon_mastery[StringName(str(key))] = int(mastery[key])
	hero.bank = Wallet.from_dict(data.get("bank", {}))
	for entry: Variant in data.get("kept_powers", []):
		if entry is Dictionary:
			var kept: KeptPower = KeptPower.from_dict(entry)
			if kept.power_id != &"":
				hero.kept_powers.append(kept)
	for entry: Variant in data.get("power_offer", []):
		var power_id: StringName = StringName(str(entry))
		if power_id != &"" and not hero.power_offer.has(power_id):
			hero.power_offer.append(power_id)
	return hero
