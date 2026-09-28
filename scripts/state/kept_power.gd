class_name KeptPower
extends RefCounted
## One power the hero keeps in a slot (docs/ARCHITECTURE.md Section 4.2).

var power_id: StringName
## 1 to BalanceData.power_level_cap.
var level: int = 1
## Run count when the power last gained a level (Fusion tie-break, docs/GDD.md Section 4.4).
var last_leveled_run: int = 0


static func create(id: StringName, start_level: int = 1, run_number: int = 0) -> KeptPower:
	var kept: KeptPower = KeptPower.new()
	kept.power_id = id
	kept.level = maxi(1, start_level)
	kept.last_leveled_run = run_number
	return kept


func to_dict() -> Dictionary:
	return {"power_id": String(power_id), "level": level, "last_leveled_run": last_leveled_run}


static func from_dict(data: Dictionary) -> KeptPower:
	return create(StringName(str(data.get("power_id", ""))), int(data.get("level", 1)), int(data.get("last_leveled_run", 0)))
