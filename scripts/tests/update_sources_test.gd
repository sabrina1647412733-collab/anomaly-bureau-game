extends SceneTree
const Service := preload("res://scripts/update_service.gd")
var failed := 0
var passed := 0
func check(value: bool, label: String) -> void:
	if value: passed += 1; print("PASS ", label)
	else: failed += 1; push_error(label)
func item(name: String, digest := true) -> Dictionary:
	return {"name":name, "size":100, "digest":("sha256:" + "a".repeat(64)) if digest else "", "browser_download_url":"https://github.com/%s/releases/download/v0.8.1/%s" % [Service.REPOSITORY, name]}
func _initialize() -> void:
	var service := Service.new()
	var v2 := item("AnomalyBureau-manifest-v2.json")
	var v3 := item("AnomalyBureau-manifest-v3.json")
	check(service._select_group_manifest({"tag_name":"v0.8.1", "assets":[v2, v3]}).get("name") == v3.name, "prefer cross-release manifest")
	check(service._select_group_manifest({"tag_name":"v0.8.1", "assets":[v2]}).get("name") == v2.name, "legacy manifest still supported")
	check(service._select_group_manifest({"tag_name":"v0.8.1", "assets":[item(v3.name, false)]}).is_empty(), "reject missing GitHub digest")
	v3.browser_download_url = "https://attacker.invalid/update.json"
	check(service._select_group_manifest({"tag_name":"v0.8.1", "assets":[v3]}).is_empty(), "reject foreign manifest source")
	check(service._select_group_manifest({"tag_name":"v0.8.2", "assets":[v2]}).is_empty(), "reject wrong release URL")
	service.free()
	print("RESULT ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)
