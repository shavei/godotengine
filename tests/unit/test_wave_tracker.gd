extends GutTest
## Room clear rules (WaveTracker).


func test_three_waves_clear_in_order() -> void:
	var tracker: WaveTracker = WaveTracker.new(3)
	assert_eq(tracker.start_next_wave(), 0)
	tracker.add_alive(2)
	assert_eq(tracker.remove_alive(), WaveTracker.Event.NONE)
	assert_eq(tracker.remove_alive(), WaveTracker.Event.WAVE_CLEARED)
	assert_eq(tracker.start_next_wave(), 1)
	tracker.add_alive(1)
	assert_eq(tracker.remove_alive(), WaveTracker.Event.WAVE_CLEARED)
	assert_false(tracker.is_room_cleared())
	assert_eq(tracker.start_next_wave(), 2)
	tracker.add_alive(1)
	assert_eq(tracker.remove_alive(), WaveTracker.Event.ROOM_CLEARED)
	assert_true(tracker.is_room_cleared())
	assert_eq(tracker.start_next_wave(), -1, "no wave after the last")


func test_splits_added_before_death_keep_the_wave_going() -> void:
	var tracker: WaveTracker = WaveTracker.new(1)
	tracker.start_next_wave()
	tracker.add_alive(1)
	# A Sproutling dies and splits into 2 seedlings.
	tracker.add_alive(2)
	assert_eq(tracker.remove_alive(), WaveTracker.Event.NONE)
	assert_eq(tracker.remove_alive(), WaveTracker.Event.NONE)
	assert_eq(tracker.remove_alive(), WaveTracker.Event.ROOM_CLEARED)


func test_extra_deaths_are_ignored() -> void:
	var tracker: WaveTracker = WaveTracker.new(1)
	tracker.start_next_wave()
	assert_eq(tracker.remove_alive(), WaveTracker.Event.NONE)
	assert_eq(tracker.alive, 0)


func test_empty_encounter_counts_as_cleared() -> void:
	assert_true(WaveTracker.new(0).is_room_cleared())
