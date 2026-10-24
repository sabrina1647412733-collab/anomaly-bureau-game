extends SceneTree
const Service := preload("res://scripts/update_service.gd")
const UpdateView :=  preload("res://scripts/update_panel.gd")
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)
func release_info() -> Dictionary:
	return {"tag_name":"v0.6.1", "draft":false, "prerelease":false, "published_at":"2026-10-24T10:00:00Z", "body":"更新内容\n[img]untrusted[/img]", "assets":[{
		"name":Service.ASSET_NAME, "digest":"sha256:" + "a".repeat(64), "size":2048,
		"browser_download_url":"https://github.com/%s/releases/download/v0.6.1/%s" % [Service.REPOSITORY, Service.ASSET_NAME]}]}
func wait_idle(service: Node, history := false) -> void:
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		if history and not service.history_busy: return
		if not history and service.state != "checking": return
		await process_frame
func run() -> void:
	check(Service.is_newer("v0.10.0", "0.9.9"), "numeric version comparison")
	check(not Service.is_newer("v0.6.0", "0.6.0"), "same version is current")
	check(not Service.is_newer("v0.3.2", "0.6.0"), "never downgrade")
	check(not Service.is_newer("v1.0.0-beta.1", "0.6.0"), "prerelease tag rejected")
	check(not Service.is_newer("garbage", "0.6.0"), "invalid tag rejected")
	check(Service.is_newer("v1.0.0+build.1", "0.6.0"), "build metadata supported")
	var service := Service.new(); root.add_child(service)
	# The fixture explicitly represents the installed 0.6.0 client, independently
	# of whichever newer version the current project is preparing to publish.
	service.current_version = "0.6.0"
	check(service._download.body_size_limit == Service.MAX_PACKAGE and Service.MAX_PACKAGE > 1000000000, "native HTTP size limit does not overflow")
	var data := release_info()
	check(not service.select_asset(data).is_empty(), "correct GitHub payload selected")
	data.assets[0].digest = ""
	check(service.select_asset(data).is_empty(), "missing GitHub digest rejected")
	data = release_info(); data.assets[0].browser_download_url = "https://attacker.invalid/update.zip"
	check(service.select_asset(data).is_empty(), "foreign download URL rejected")
	data = release_info(); data.assets[0].name = "AnomalyBureau-Setup.exe"
	check(service.select_asset(data).is_empty(), "legacy installer never used as update")
	data = release_info(); data.assets[0].size = 0
	check(service.select_asset(data).is_empty(), "empty package rejected")
	data = release_info()
	service._checked(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify(data).to_utf8_buffer())
	check(service.state == "available", "new release prompts update")
	data.prerelease = true
	service._checked(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify(data).to_utf8_buffer())
	check(service.state == "error", "preview release rejected")
	service._checked(HTTPRequest.RESULT_SUCCESS, 200, [], "bad json".to_utf8_buffer())
	check(service.state == "error", "malformed release does not crash")
	service._checked(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	check(service.state == "error", "offline check is recoverable")
	service._checked(HTTPRequest.RESULT_SUCCESS, 403, [], PackedByteArray())
	check("额度" in service.message, "GitHub rate limit explained")
	service._history_received(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify([release_info(), {"draft":true}, {"prerelease":true}]).to_utf8_buffer())
	check(service.releases.size() == 1 and service.history_page == 1, "history filters drafts and previews")
	check("v0.6.1" in UpdateView.release_text(service.releases[0]) and "2026-10-24" in UpdateView.release_text(service.releases[0]), "history has version date and notes")
	check("[img]" in UpdateView.release_text(service.releases[0]), "remote content remains plain text")
	var menu := preload("res://scripts/menu.gd").new(); root.add_child(menu)
	menu.setup(SystemFont.new())
	var view := UpdateView.new(); menu.add_child(view); view.setup(menu, service)
	view.show_update(); await process_frame
	check(view.modal.visible and view.primary.visible, "update modal and install button exist")
	service._set_state("available", "test"); view.close(); await process_frame
	check(not view.modal.visible, "later update suppresses automatic reopening")
	service._set_state("downloading", "test"); view.show_update(); service.progress.emit(1024,2048)
	check(view.bar.value == 1024 and "50%" in view.status.text, "download byte count and percent")
	view.close(); check(service.state == "available", "cancel download keeps existing game")
	service._set_state("verifying", "test"); view.show_update(); view.close()
	check(view.modal.visible and view.close_button.disabled, "cannot interrupt installer handshake via UI")
	service._set_state("available", "test"); view.close()
	service.asset.clear(); service._set_state("current", "test")
	view.mode = "history"; view._open()
	check(not view.text.bbcode_enabled and "v0.6.1" in view.text.text, "history view uses plain text")
	check(view.primary.focus_next == view.primary.get_path_to(view.secondary), "modal traps keyboard focus")
	view.close()
	if OS.get_cmdline_user_args().has("--github-live"):
		service.current_version = ProjectSettings.get_setting("application/config/version", "0.6.1")
		service.api_base = "https://api.github.com/repos/" + Service.REPOSITORY
		service.check_updates(); await wait_idle(service)
		check(service.state == "current", "LIVE real GitHub latest release read")
		service.fetch_history(); await wait_idle(service, true)
		check(not service.history_busy and service.releases.size() >= 2, "LIVE real GitHub release history read")
		print("LIVE history count=", service.releases.size(), " latest=", service.latest.get("tag_name", ""))
	menu.queue_free(); service.queue_free(); await process_frame
	print("RESULT ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)
