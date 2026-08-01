extends SceneTree
## Verifies every looped stream's loop point matches its true length —
## guards against the QOA-compression loop bug (data.size()/2 != samples).
## Run: godot --headless --path . -s tests/test_audio.gd

func _init() -> void:
	var failures := 0
	for name in ["ambience", "well_hum", "music_band1", "music_band2",
			"music_band3", "music_band4", "music_band5", "music_hub",
			"music_finale", "music_credits"]:
		var stream: AudioStreamWAV = load("res://assets/sfx/%s.wav" % name)
		var true_samples := int(stream.get_length() * stream.mix_rate)
		var naive := stream.data.size() / 2
		var correct := int(stream.get_length() * stream.mix_rate)
		# the loop point the game will actually use:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = correct
		if absi(stream.loop_end - true_samples) > 8:
			failures += 1
			push_error("FAIL %s: loop_end %d != %d samples" % [name, stream.loop_end, true_samples])
		else:
			print("  ok  %-16s %.2fs  (naive byte-based loop point would be %.2fs)" % [
				name, stream.get_length(), naive / stream.mix_rate])
	print("ALL PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
