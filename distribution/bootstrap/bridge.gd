extends Node
## Protocol-1 migration payload. The old launcher only installs this EXE/PCK pair.
var health := ""
var token := ""
var base := ""
var helper := ""
var stage := ""
var restart := PackedStringArray()
var deadline := 0

func _ready() -> void:
	base = OS.get_executable_path().get_base_dir()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--update-health="): health = arg.trim_prefix("--update-health=").replace("\\", "/")
		if arg.begins_with("--update-token="): token = arg.trim_prefix("--update-token=")
	# Preserve silent/headless acceptance options and the player's chosen renderer.
	var engine := OS.get_cmdline_args()
	for i in range(engine.size()):
		if engine[i] in ["--headless"]: restart.append(engine[i])
		if engine[i] in ["--audio-driver", "--rendering-method", "--log-file", "--quit-after", "--max-fps"] and i + 1 < engine.size():
			restart.append(engine[i]); restart.append(engine[i + 1])
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify" or arg.begins_with("--data-dir=") or arg.begins_with("--distribution-test-exit-seconds="):
			if not restart.has("--"): restart.append("--")
			restart.append(arg)
	if FileAccess.get_sha256("res://payload.zip") != "@PAYLOAD_SHA@":
		push_error("迁移完整包校验失败，旧更新器将恢复原版。"); get_tree().quit(1); return
	stage = base.path_join("_更新缓存/migration/stage-" + Crypto.new().generate_random_bytes(8).hex_encode())
	var zip := ZIPReader.new()
	if zip.open("res://payload.zip") != OK:
		push_error("无法打开迁移完整包"); get_tree().quit(1); return
	for name in zip.get_files():
		if name.ends_with("/"): continue
		if name.is_absolute_path() or ".." in name.split("/") or "\\" in name or ":" in name:
			push_error("迁移包路径无效"); get_tree().quit(1); return
		var dest := stage.path_join(name)
		if DirAccess.make_dir_recursive_absolute(dest.get_base_dir()) != OK:
			push_error("无法创建迁移目录"); get_tree().quit(1); return
		var file := FileAccess.open(dest, FileAccess.WRITE)
		if file == null: push_error("无法写入迁移文件"); get_tree().quit(1); return
		file.store_buffer(zip.read_file(name)); file.close()
	zip.close()
	var layout = JSON.parse_string(FileAccess.get_file_as_string(stage.path_join("layout.json")))
	if not layout is Dictionary: get_tree().quit(1); return
	for item in layout.files:
		if FileAccess.get_sha256(stage.path_join(item.path)) != str(item.sha256):
			push_error("迁移文件校验失败：" + str(item.path)); get_tree().quit(1); return
	helper = base.path_join("_更新缓存/migration/Migrator.exe")
	if DirAccess.copy_absolute(stage.path_join("AnomalyBureau.exe"), helper) != OK: get_tree().quit(1); return
	# The legacy transaction must commit before the fixed launcher is replaced.
	if not health.is_empty():
		if health != base.path_join("_更新缓存/health.txt").replace("\\", "/") or token.length() != 32: get_tree().quit(1); return
		var receipt := FileAccess.open(health, FileAccess.WRITE)
		if receipt == null: get_tree().quit(1); return
		receipt.store_string(token); receipt.close()
	deadline = Time.get_ticks_msec() + 120000
	set_process(true)

func _process(_delta: float) -> void:
	if helper.is_empty(): return
	if not health.is_empty():
		var parser := JSON.new()
		var journal = null
		if parser.parse(FileAccess.get_file_as_string(base.path_join("_更新缓存/transaction.json"))) == OK: journal = parser.data
		if not journal is Dictionary or journal.get("state") != "committed":
			if Time.get_ticks_msec() > deadline: get_tree().quit(1)
			return
	var args := PackedStringArray(["--migrate-install", base, stage, base.path_join("_更新缓存/migration/result.json"), str(OS.get_process_id()), "--from-legacy"])
	args.append_array(restart)
	if OS.create_process(helper, args) <= 0: push_error("无法启动基础包迁移器"); get_tree().quit(1); return
	print("LEGACY_BRIDGE handoff=true")
	helper = ""; get_tree().quit()
