extends GutTest
## The forced first gift (FirstGift), the ceremony's timeline (CeremonyTimeline) and the
## profile fields that remember both.

var balance: BalanceData
var profile: ProfileState


func before_each() -> void:
	balance = BalanceData.new()
	profile = ProfileState.new()
	profile.hero(0)
	var roster: Array[VillagerData] = []
	for item: Resource in ContentDB.get_all(&"villagers"):
		roster.append(item as VillagerData)
	profile.village.admit(roster, GameState.RENOWN_LEVEL_UNTIL_M5)


func test_a_new_profile_must_give_its_first_power_to_the_farmer() -> void:
	assert_eq(balance.first_gift_villager, &"farmer")
	var farmer: int = profile.village.index_of(&"farmer")
	assert_true(FirstGift.is_active(profile, balance))
	assert_eq(FirstGift.villager_index(profile, balance), farmer)
	assert_true(FirstGift.allows(profile, balance, farmer))
	assert_false(FirstGift.allows(profile, balance, profile.village.index_of(&"smith")))


func test_any_gift_ends_it() -> void:
	FirstGift.complete(profile)
	assert_false(FirstGift.is_active(profile, balance))
	assert_true(FirstGift.allows(profile, balance, profile.village.index_of(&"smith")), "later gifts go to anyone")


func test_nothing_is_forced_without_a_free_first_gift_villager() -> void:
	profile.village.find(&"farmer").power_id = &"stone"
	assert_false(FirstGift.is_active(profile, balance), "the Farmer holds a power already")
	profile.village.find(&"farmer").power_id = &""
	balance.first_gift_villager = &""
	assert_false(FirstGift.is_active(profile, balance), "no villager named")
	balance.first_gift_villager = &"baker"
	assert_false(FirstGift.is_active(profile, balance), "a villager who has not arrived")


func test_saves_from_before_the_tutorial_skip_it_once_a_power_was_settled() -> void:
	var fresh: Dictionary = profile.to_dict()
	fresh.erase("first_gift_done")
	assert_false(ProfileState.from_dict(fresh).first_gift_done, "nothing settled yet: the tutorial waits")
	profile.village.find(&"guard").power_id = &"frost"
	var gifted: Dictionary = profile.to_dict()
	gifted.erase("first_gift_done")
	assert_true(ProfileState.from_dict(gifted).first_gift_done, "a villager holds a power")
	profile.village.find(&"guard").power_id = &""
	profile.hero(0).kept_powers.append(KeptPower.create(&"fire", 2))
	var kept: Dictionary = profile.to_dict()
	kept.erase("first_gift_done")
	assert_true(ProfileState.from_dict(kept).first_gift_done, "the hero keeps a power")


func test_the_profile_saves_the_tutorial_and_ceremonies_seen() -> void:
	profile.first_gift_done = true
	profile.ceremonies_seen = 3
	var loaded: ProfileState = ProfileState.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_true(loaded.first_gift_done)
	assert_eq(loaded.ceremonies_seen, 3)


# --- CeremonyTimeline ----------------------------------------------------------------

func test_the_ceremony_lasts_five_to_eight_seconds() -> void:
	assert_between(CeremonyTimeline.DURATION, 5.0, 8.0)
	assert_false(CeremonyTimeline.is_over(CeremonyTimeline.DURATION - 0.01))
	assert_true(CeremonyTimeline.is_over(CeremonyTimeline.DURATION))


func test_its_beats_come_in_order() -> void:
	assert_lt(CeremonyTimeline.RISE_AT, CeremonyTimeline.FLY_AT)
	assert_lt(CeremonyTimeline.FLY_AT, CeremonyTimeline.BURST_AT)
	assert_lt(CeremonyTimeline.BURST_AT, CeremonyTimeline.LINE_AT)
	assert_lt(CeremonyTimeline.LINE_AT + CeremonyTimeline.FIRST_READ_TIME, CeremonyTimeline.DURATION)
	assert_eq(CeremonyTimeline.flight(0.0), 0.0)
	assert_eq(CeremonyTimeline.flight(CeremonyTimeline.BURST_AT), 1.0)
	assert_eq(CeremonyTimeline.swap(CeremonyTimeline.BURST_AT - 0.1), 0.0)
	assert_almost_eq(CeremonyTimeline.swap(CeremonyTimeline.BURST_AT + CeremonyTimeline.SWAP_TIME), 1.0, 0.0001)
	assert_false(CeremonyTimeline.shows_line(CeremonyTimeline.BURST_AT))
	assert_true(CeremonyTimeline.shows_line(CeremonyTimeline.LINE_AT))


func test_only_the_first_ceremony_must_be_watched() -> void:
	assert_false(CeremonyTimeline.can_skip(0, 0.0))
	assert_false(CeremonyTimeline.can_skip(0, CeremonyTimeline.LINE_AT))
	assert_true(CeremonyTimeline.can_skip(0, CeremonyTimeline.LINE_AT + CeremonyTimeline.FIRST_READ_TIME))
	assert_true(CeremonyTimeline.can_skip(1, 0.0), "skippable after the first time")
