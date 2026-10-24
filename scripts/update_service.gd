extends Node
## GitHub public Releases client. No credentials are stored in the game.
signal changed
signal history_changed
signal progress(bytes: int, total: int)
const REPOSITORY := "sabrina1647412733-collab/anomaly-bureau-game"
const ASSET_NAME := "AnomalyBureau-update-win64.zip"
const HEADERS := ["Accept: application/vnd.github+json", "User-Agent: AnomalyBureau", "X-GitHub-Api-Version: 2022-11-28"]
# HTTPRequest stores its size limit as signed 32-bit even though GDScript uses int64.
const MAX_PACKAGE := 2000000000
var api_base := "https://api.github.com/repos/" + REPOSITORY
var current_version: String = ProjectSettings.get_setting("application/config/version", "0.6.0")
var state := "idle"
var message := ""
var latest: Dictionary = {}
var asset: Dictionary = {}
var releases: Array = []
var history_message := ""
var history_busy := false
var history_has_more := false
var history_page := 0
var recovery_notice := false
var _check: HTTPRequest
var _history: HTTPRequest
var _download: HTTPRequest
var _hash_thread: Thread
var _handshake_pid := -1
var _token := ""
var _handshake_deadline := 0
var restart_args: PackedStringArray = []
var _manifest_request: HTTPRequest
var _group_asset: Dictionary = {}
var _group_manifest := ""
var _worker_pid := -1
var _worker_status := ""
var _worker_action := ""
var download_bytes := 0

static func decode_json(value: String):
	var parser := JSON.new()
	return parser.data if parser.parse(value) == OK else null

static func version_parts(value: String) -> PackedInt64Array:
	var regex := RegEx.new()
	regex.compile("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:\\+[0-9A-Za-z.-]+)?$")
	var found := regex.search(value)
	if found == null: return PackedInt64Array()
	return PackedInt64Array([int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3))])

static func is_newer(candidate: String, installed: String) -> bool:
	var a := version_parts(candidate)
	var b := version_parts(installed)
	if a.size() != 3 or b.size() != 3: return false
	for i in range(3):
		if a[i] != b[i]: return a[i] > b[i]
	return false

func cache_dir() -> String:
	# Update transactions belong to the installed runtime, independently of an
	# isolated --data-dir or developer review save directory.
	if OS.has_feature("windows") and not OS.has_feature("editor"):
		return OS.get_executable_path().get_base_dir().path_join("_更新缓存")
	return preload("res://scripts/storage_paths.gd").root_dir().get_base_dir().path_join("_更新缓存")

func _ready() -> void:
	_check = HTTPRequest.new(); add_child(_check)
	_history = HTTPRequest.new(); add_child(_history)
	_download = HTTPRequest.new(); add_child(_download)
	_manifest_request = HTTPRequest.new(); add_child(_manifest_request)
	_manifest_request.use_threads = true; _manifest_request.timeout = 60
	_manifest_request.body_size_limit = 16 * 1024 * 1024
	_manifest_request.request_completed.connect(_group_manifest_received)
	for request in [_check, _history]:
		request.timeout = 20; request.body_size_limit = 4 * 1024 * 1024; request.use_threads = true
	_download.timeout = 1800; _download.body_size_limit = MAX_PACKAGE
	_download.use_threads = true; _download.accept_gzip = false
	_check.request_completed.connect(_checked)
	_history.request_completed.connect(_history_received)
	_download.request_completed.connect(_downloaded)

func startup() -> void:
	# Receipts are only written after the real menu initialized, including isolated tests.
	if await _group_health_receipt(): return
	if OS.get_cmdline_user_args().has("--verify"): return
	var health := ""
	var token := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--update-health="): health = argument.trim_prefix("--update-health=").replace("\\", "/")
		if argument.begins_with("--update-token="): token = argument.trim_prefix("--update-token=")
	if not health.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		var expected := cache_dir().path_join("health.txt").replace("\\", "/")
		if health == expected and token.length() == 32:
			var receipt := FileAccess.open(health, FileAccess.WRITE)
			if receipt != null: receipt.store_string(token); receipt.close()
		return
	var result_path := cache_dir().path_join("result.json")
	if FileAccess.file_exists(result_path):
		var result = decode_json(FileAccess.get_file_as_string(result_path))
		if result is Dictionary and result.get("status") in ["failed", "rolled_back"]:
			recovery_notice = true
			_set_state("error", str(result.get("message", "上次更新失败，可重试。")))
			DirAccess.remove_absolute(result_path)
			return
	check_updates()

func _set_state(value: String, text: String) -> void:
	state = value; message = text; changed.emit()

func check_updates() -> void:
	if state in ["checking", "planning", "downloading", "verifying", "installing"]: return
	_set_state("checking", "正在检查最新版本…")
	var error := _check.request(api_base + "/releases/latest", HEADERS)
	if error != OK: _set_state("error", "无法开始检查更新，请重试。（%d）" % error)

func _http_error(code: int, _headers: PackedStringArray) -> String:
	if code in [403, 429]: return "GitHub 请求额度暂时用完，请稍后重试。"
	if code == 404: return "尚无公开正式版本，或仓库暂时不可访问。"
	return "无法连接 GitHub（HTTP %d），可继续游戏，稍后重试。" % code

func _checked(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_state("error", _http_error(code, headers)); return
	var data = decode_json(body.get_string_from_utf8())
	if not data is Dictionary or data.get("draft", true) or data.get("prerelease", true) or version_parts(str(data.get("tag_name", ""))).is_empty():
		_set_state("error", "GitHub 返回了无效版本信息，可稍后重试。"); return
	latest = data
	_group_asset = _select_group_manifest(latest)
	if _grouped_install() and not _group_asset.is_empty() and (is_newer(str(latest.tag_name), current_version) or version_parts(str(latest.tag_name)) == version_parts(current_version)):
		_prepare_group_manifest(); return
	if not is_newer(str(latest.tag_name), current_version):
		asset.clear(); _set_state("current", "当前版本 v%s，已是最新版本。" % current_version); return
	asset = select_asset(latest)
	if _grouped_install():
		asset.clear(); _set_state("unavailable", "该版本需要更新基础运行文件，请下载完整安装包覆盖安装。存档和设置会保留。"); return
	if asset.is_empty():
		_set_state("unavailable", "发现 %s，但发行者尚未上传通过校验的 Windows 自动更新包。" % latest.tag_name); return
	download_bytes = int(asset.get("size", 0))
	_set_state("available", "发现新版本 %s，本次下载 %.2f MiB。" % [latest.tag_name, download_bytes / 1048576.0])

func select_asset(release: Dictionary) -> Dictionary:
	var list = release.get("assets", [])
	if not list is Array: return {}
	var tag := str(release.get("tag_name", ""))
	for item in list:
		if not item is Dictionary or item.get("name", "") != ASSET_NAME: continue
		var digest := str(item.get("digest", ""))
		var rx := RegEx.new(); rx.compile("^sha256:[a-fA-F0-9]{64}$")
		var expected := "https://github.com/%s/releases/download/%s/%s" % [REPOSITORY, tag, ASSET_NAME]
		if rx.search(digest) == null or str(item.get("browser_download_url", "")) != expected: continue
		if int(item.get("size", 0)) <= 0 or int(item.get("size", 0)) > MAX_PACKAGE: continue
		return item
	return {}

func fetch_history(reset := true) -> void:
	if history_busy: return
	if reset: releases.clear(); history_page = 0
	history_busy = true; history_message = "正在读取 GitHub 更新日志…"; history_changed.emit()
	var error := _history.request(api_base + "/releases?per_page=20&page=%d" % (history_page + 1), HEADERS)
	if error != OK:
		history_busy = false; history_message = "日志请求失败，请重试。"; history_changed.emit()

func _history_received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	history_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		history_message = _http_error(code, headers); history_changed.emit(); return
	var data = decode_json(body.get_string_from_utf8())
	if not data is Array:
		history_message = "更新日志格式无效，请重试。"; history_changed.emit(); return
	history_page += 1; history_has_more = data.size() == 20
	for item in data:
		if item is Dictionary and not item.get("draft", true) and not item.get("prerelease", true): releases.append(item)
	history_message = "暂无已发布版本。" if releases.is_empty() else "发布日期按 GitHub UTC 时间显示。"
	history_changed.emit()

func download_update() -> void:
	if not _group_manifest.is_empty() and not _group_asset.is_empty():
		if state in ["available", "error"]: _start_group_worker("download")
		return
	if state in ["downloading", "verifying", "installing"] or asset.is_empty(): return
	if not OS.has_feature("windows") or OS.has_feature("editor"):
		_set_state("error", "请在导出的 Windows 游戏中安装更新；工程运行仅检查版本与日志。"); return
	var install_dir := OS.get_executable_path().get_base_dir()
	if not FileAccess.file_exists(install_dir.path_join("AnomalyBureau.exe")) or OS.get_executable_path().get_file() != "AnomalyBureau.Game.exe":
		_set_state("error", "缺少独立启动器，请使用完整 Windows 发行文件夹。"); return
	if DirAccess.make_dir_recursive_absolute(cache_dir()) != OK:
		_set_state("error", "游戏目录不可写，请将完整文件夹移到可写位置后重试。"); return
	_download.download_file = cache_dir().path_join("download.zip")
	_set_state("downloading", "正在下载更新，可取消后稍后重试…")
	var error := _download.request(str(asset.browser_download_url))
	if error != OK: _set_state("error", "无法开始下载，请重试。（%d）" % error)

func cancel_download() -> void:
	if state != "downloading": return
	if _worker_pid > 0 and _worker_action == "download":
		var cancel := FileAccess.open(_worker_status + ".cancel", FileAccess.WRITE)
		if cancel != null: cancel.close()
		_set_state("verifying", "正在取消下载，已校验的完整文件会保留…"); return
	_download.cancel_request(); _set_state("available", "已取消下载，当前版本可以继续游玩。")

func _downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if state != "downloading": return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_state("error", "下载失败（HTTP %d / %d），旧版本未改动，可重试。" % [code, result]); return
	var file := FileAccess.open(_download.download_file, FileAccess.READ)
	if file == null: _set_state("error", "下载文件无法打开，请重试。"); return
	var size := file.get_length(); file.close()
	if size != int(asset.size): _set_state("error", "更新包下载不完整，请重试。"); return
	_set_state("verifying", "下载完成，正在校验更新包…")
	_hash_thread = Thread.new()
	var error := _hash_thread.start(func(): return FileAccess.get_sha256(_download.download_file))
	if error != OK: _hash_thread = null; _set_state("error", "校验线程启动失败，请重试。")

func _process(_delta: float) -> void:
	if _worker_pid > 0:
		_poll_group_worker()
		return
	if state == "downloading": progress.emit(_download.get_downloaded_bytes(), int(asset.get("size", 0)))
	if _hash_thread != null and not _hash_thread.is_alive():
		var digest: String = str(_hash_thread.wait_to_finish()); _hash_thread = null
		if digest != str(asset.get("digest", "")).trim_prefix("sha256:").to_lower():
			_set_state("error", "更新包 SHA256 校验失败，旧版本未改动，请重试下载。")
		else: _launch_installer()
	if _handshake_pid > 0:
		var ready := cache_dir().path_join("ready-" + _token + ".txt")
		if FileAccess.file_exists(ready): _handshake_pid = -1; get_tree().quit()
		elif Time.get_ticks_msec() > _handshake_deadline or not OS.is_process_running(_handshake_pid):
			_handshake_pid = -1; _set_state("error", "独立更新器未就绪，当前游戏未退出，请重试。")

func _launch_installer() -> void:
	_token = Crypto.new().generate_random_bytes(16).hex_encode()
	var base := OS.get_executable_path().get_base_dir()
	var helper := cache_dir().path_join("Updater.exe")
	if DirAccess.copy_absolute(base.path_join("AnomalyBureau.exe"), helper) != OK:
		_set_state("error", "无法准备独立更新器，请关闭其他更新进程后重试。"); return
	var job := {"install_dir": base, "archive": _download.download_file, "sha256": str(asset.digest).trim_prefix("sha256:").to_lower(),
		"version": str(latest.tag_name).trim_prefix("v").split("+")[0], "token": _token, "parent_pid": OS.get_process_id(), "game_args": Array(restart_args)}
	var job_path := cache_dir().path_join("job.json")
	var output := FileAccess.open(job_path, FileAccess.WRITE)
	if output == null: _set_state("error", "无法保存更新任务，请重试。"); return
	output.store_string(JSON.stringify(job)); output.close()
	_handshake_pid = OS.create_process(helper, ["--apply", job_path])
	if _handshake_pid <= 0: _set_state("error", "独立更新器启动失败，请重试。"); return
	_handshake_deadline = Time.get_ticks_msec() + 10000
	_set_state("installing", "更新器就绪后游戏将关闭，安装完成后自动重新启动。")

func _exit_tree() -> void:
	if _worker_pid > 0 and _worker_action == "download":
		var cancel := FileAccess.open(_worker_status + ".cancel", FileAccess.WRITE)
		if cancel != null: cancel.close()
	if _hash_thread != null: _hash_thread.wait_to_finish()

func _grouped_install() -> bool:
	return FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("_运行文件/active.json"))

func _select_group_manifest(release: Dictionary) -> Dictionary:
	var rx := RegEx.new(); rx.compile("^sha256:[a-fA-F0-9]{64}$")
	# v3 is a transport extension; mounted runtime layout remains protocol 2.
	for name in ["AnomalyBureau-manifest-v3.json", "AnomalyBureau-manifest-v2.json"]:
		var expected := "https://github.com/%s/releases/download/%s/%s" % [REPOSITORY, str(release.get("tag_name", "")), name]
		for item in release.get("assets", []):
			if item is Dictionary and item.get("name") == name and str(item.get("browser_download_url", "")) == expected and rx.search(str(item.get("digest", ""))) != null and int(item.get("size", 0)) > 0 and int(item.get("size", 0)) <= 16 * 1024 * 1024:
				return item
	return {}

func _prepare_group_manifest() -> void:
	asset = _group_asset
	var folder := cache_dir().path_join("v2")
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_set_state("error", "游戏目录不可写，无法准备更新清单。"); return
	_group_manifest = folder.path_join("manifest-" + str(_group_asset.digest).trim_prefix("sha256:").to_lower() + ".json")
	if FileAccess.file_exists(_group_manifest) and FileAccess.get_sha256(_group_manifest) == str(_group_asset.digest).trim_prefix("sha256:").to_lower():
		_start_group_worker("plan"); return
	_manifest_request.download_file = _group_manifest + ".part"
	_set_state("planning", "正在读取资源清单，计算实际下载量…")
	var error := _manifest_request.request(str(_group_asset.browser_download_url))
	if error != OK: _set_state("error", "无法读取资源清单，请重新检查更新。（%d）" % error)

func _group_manifest_received(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_state("error", "资源清单下载失败（HTTP %d / %d），请重新检查更新。" % [code, result]); return
	var downloaded := FileAccess.open(_manifest_request.download_file, FileAccess.READ)
	if downloaded == null: _set_state("error", "资源清单无法打开。"); return
	var length := downloaded.get_length(); downloaded.close()
	if length != int(_group_asset.size) or FileAccess.get_sha256(_manifest_request.download_file) != str(_group_asset.digest).trim_prefix("sha256:").to_lower():
		_set_state("error", "资源清单大小或 SHA256 校验失败，请重新检查更新。"); return
	if DirAccess.rename_absolute(_manifest_request.download_file, _group_manifest) != OK:
		_set_state("error", "无法保存资源清单，请检查目录写入权限。"); return
	_start_group_worker("plan")

func _start_group_worker(action: String) -> void:
	if _worker_pid > 0: return
	if not FileAccess.file_exists(_group_manifest) or FileAccess.get_sha256(_group_manifest) != str(_group_asset.get("digest", "")).trim_prefix("sha256:").to_lower():
		_set_state("error", "资源清单未通过校验，请重新检查更新。"); return
	var manifest = decode_json(FileAccess.get_file_as_string(_group_manifest))
	if not manifest is Dictionary or str(manifest.get("version", "")) != str(latest.get("tag_name", "")).trim_prefix("v"):
		_set_state("error", "资源清单版本与发行版本不一致，请重新检查更新。"); return
	var base := OS.get_executable_path().get_base_dir()
	_token = Crypto.new().generate_random_bytes(16).hex_encode()
	if DirAccess.make_dir_recursive_absolute(cache_dir().path_join("v2")) != OK:
		_set_state("error", "游戏目录不可写，无法准备独立更新器。"); return
	# Windows may briefly retain an EXE image lock after a worker exits. Each
	# action gets a new filename, so plan -> download -> apply never overwrites it.
	var worker := cache_dir().path_join("v2/Worker-" + _token + ".exe")
	if DirAccess.copy_absolute(base.path_join("AnomalyBureau.exe"), worker) != OK:
		_set_state("error", "无法准备更新器，请稍后重试。"); return
	_worker_status = cache_dir().path_join("v2/status-" + _token + ".json")
	_worker_action = action
	var args := PackedStringArray(["--group-" + action, base, _group_manifest, _worker_status])
	if action == "download": args.append(str(_group_asset.browser_download_url).get_base_dir())
	if action == "apply":
		args.append(str(OS.get_process_id())); args.append(_token); args.append_array(restart_args)
	_worker_pid = OS.create_process(worker, args)
	if _worker_pid <= 0: _set_state("error", "无法启动独立更新器，请重试。"); return
	_set_state("planning" if action == "plan" else ("downloading" if action == "download" else "installing"), "正在校验本地资源并计算下载量…" if action == "plan" else ("正在下载所需资源…" if action == "download" else "准备重新启动并合并资源…"))

func _poll_group_worker() -> void:
	var status_data = decode_json(FileAccess.get_file_as_string(_worker_status)) if FileAccess.file_exists(_worker_status) else null
	if status_data is Dictionary and _worker_action == "apply" and status_data.get("state") == "ready":
		_worker_pid = -1; get_tree().quit(); return
	if status_data is Dictionary and status_data.get("state") == "downloading":
		progress.emit(int(status_data.get("bytes", 0)), int(status_data.get("total", 0)))
	if OS.is_process_running(_worker_pid): return
	_worker_pid = -1
	if not status_data is Dictionary:
		_set_state("error", "更新器意外退出，旧版本仍保留。请重试。"); return
	if status_data.get("state") == "error":
		_set_state("error", str(status_data.get("message", "更新未完成，请重试。"))); return
	if _worker_action == "plan":
		download_bytes = int(status_data.get("bytes", 0))
		var newer := is_newer(str(latest.get("tag_name", "")), current_version)
		_set_state("available" if newer or download_bytes > 0 else "current", "%s，本次实际下载 %.2f MiB（%d 字节），已校验的本地资源会复用。" % [("发现 " + str(latest.get("tag_name", ""))) if newer else ("当前版本需要修复" if download_bytes > 0 else "当前版本资源完整"), download_bytes / 1048576.0, download_bytes])
	elif _worker_action == "download" and status_data.get("state") == "downloaded": _start_group_worker("apply")
	else: _set_state("error", str(status_data.get("message", "更新未完成，请重试。")))

func _group_health_receipt() -> bool:
	for kind in ["group", "migration"]:
		var receipt := ""
		var token := ""
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--%s-health=" % kind): receipt = argument.trim_prefix("--%s-health=" % kind).replace("\\", "/")
			if argument.begins_with("--%s-token=" % kind): token = argument.trim_prefix("--%s-token=" % kind)
		if receipt.is_empty(): continue
		var folder := "v2" if kind == "group" else "migration"
		var expected := cache_dir().path_join(folder + "/health-" + token + ".txt").replace("\\", "/")
		var rx := RegEx.new(); rx.compile("^[a-f0-9]{32}$")
		if receipt != expected or rx.search(token) == null: return true
		await get_tree().process_frame
		await get_tree().process_frame
		var file := FileAccess.open(receipt, FileAccess.WRITE)
		if file != null: file.store_string(token); file.close()
		return true
	return false
