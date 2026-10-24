extends SceneTree
## Deterministic text manifest only. Generation must direct audio to files, never speakers.
func _initialize() -> void:
	var events := ["invitation","address","arrival","meter","meal","he_confirm","hospital_confirm","witness9","sun_first","four_times","memory","valve_warning","settle","joint","name"]
	var data = preload("res://scripts/case2/case2_dialogue_data.gd")
	var rows: Array = []
	for event_id in events:
		var sequence: Array = data.lines(event_id)
		for i in range(sequence.size()):
			rows.append({"id":"c2_%s_%02d" % [event_id,i],"event":event_id,"speaker":sequence[i][0],"text":sequence[i][1],"file":"c2_%s_%02d.wav" % [event_id,i]})
	DirAccess.make_dir_recursive_absolute("res://assets/audio/case2")
	var file := FileAccess.open("res://assets/audio/case2/dialogue_manifest.json",FileAccess.WRITE)
	if file == null:
		push_error("Cannot write case2 dialogue manifest")
		quit(1)
		return
	file.store_string(JSON.stringify({"version":1,"case_id":"00201","base":"res://assets/audio/case2/","lines":rows},"\t"))
	file.close()
	print("CASE2_DIALOGUE_LINES ",rows.size())
	quit()
