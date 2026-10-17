extends SceneTree
## Web 中文字体验收：内嵌 FontFile 必须覆盖 scripts/*.gd 里所有常用汉字/标点。
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(30):
		await process_frame
	var f: Font = game.font
	var is_embedded: bool = f != null and not (f is SystemFont)
	var chars := {}
	for fn in DirAccess.get_files_at("res://scripts"):
		if not String(fn).ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/" + String(fn))
		for i in range(src.length()):
			var c: int = src.unicode_at(i)
			if (c >= 0x4E00 and c <= 0x9FFF) or (c >= 0x3000 and c <= 0x303F) or (c >= 0xFF00 and c <= 0xFFEF):
				chars[c] = true
	var missing := []
	for c in chars:
		if not f.has_char(c):
			missing.append(char(c))
	print("[FONT] type=", f.get_class(), " current=", f.get_font_name(), " embedded=", is_embedded, " unique_cjk=", chars.size(), " missing=", missing.size())
	if missing.size() > 0:
		print("[FONT] missing_chars=", "".join(missing))
	print("[FONT] PASS=", is_embedded and missing.size() == 0)
	quit(0 if (is_embedded and missing.size() == 0) else 1)
