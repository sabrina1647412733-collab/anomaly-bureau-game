class_name ArchiveStore
extends RefCounted
## 存档档案：跨槽位的长期记录（user://archive.json）
##
## - 三个槽位仍然只存「单局现场」（save_1..3.json）；档案单独保存每案的通关状态、
##   已见结局、最佳轮次/最佳时钟与游玩次数。删除槽位不会删除档案。
## - 档案按案子编号索引，后续案卷接入时只需把 CASES 里的 open 打开。
## - schema_version 用于以后迁移；读取时会补齐缺失字段，不会覆盖未知字段之外的内容。

const PATH := "user://archive.json"
const EXPORT_PATH := "user://archive_export.json"
const SCHEMA_VERSION := 1
const ENDING_KEYS := ["A", "B", "C"]
const CASE_TOTAL := 6   # 第一季正片六案：0017–0022（终章不计入分母）

## 案卷目录。no 为显示编号，title/sub 为档案里的案卷名与类型。
## open = 当前版本可否进入；其余案卷显示「尚未开启」。
const CASES := [
	{"id": "0017", "no": "0017", "title": "岚桥站 · 半秒", "sub": "甲 · 重复", "open": true},
	{"id": "0018", "no": "0018", "title": "0 号线", "sub": "乙 · 空缺", "open": false},
	{"id": "0019", "no": "0019", "title": "17 楼", "sub": "丙 · 错位", "open": false},
	{"id": "0020", "no": "0020", "title": "无声广播", "sub": "丁 · 替代", "open": false},
	{"id": "0021", "no": "0021", "title": "白事科", "sub": "戊 · 仪式", "open": false},
	{"id": "0022", "no": "0022", "title": "值班表 · 第 28 个名字", "sub": "元事件", "open": false},
	{"id": "finale", "no": "终章", "title": "017 · 第 17 版", "sub": "S · 修订", "open": false},
]


# ------------------------------------------------------------------ 数据结构

static func empty_case() -> Dictionary:
	return {
		"completed": false,
		"endings": [],
		"best_round": -1,
		"best_clock": -1.0,
		"plays": 0,
		"started": false,
		"last_played": "",
	}


static func empty_data() -> Dictionary:
	var cases := {}
	for c in CASES:
		cases[c["id"]] = empty_case()
	return {"schema_version": SCHEMA_VERSION, "cases": cases, "updated": ""}


static func _now() -> String:
	return Time.get_datetime_string_from_system(false, false)


static func _normalize_case(raw) -> Dictionary:
	var e := empty_case()
	if typeof(raw) != TYPE_DICTIONARY:
		return e
	e["completed"] = bool(raw.get("completed", false))
	var seen := []
	var raw_ends = raw.get("endings", [])
	if typeof(raw_ends) == TYPE_ARRAY:
		for k in raw_ends:
			var s := str(k).to_upper()
			if ENDING_KEYS.has(s) and not seen.has(s):
				seen.append(s)
	seen.sort()
	e["endings"] = seen
	e["best_round"] = int(raw.get("best_round", -1))
	e["best_clock"] = float(raw.get("best_clock", -1.0))
	e["plays"] = maxi(0, int(raw.get("plays", 0)))
	e["started"] = bool(raw.get("started", int(e["plays"]) > 0 or bool(e["completed"])))
	e["last_played"] = str(raw.get("last_played", ""))
	return e


# ------------------------------------------------------------------ 读写

static func load_data() -> Dictionary:
	var d := empty_data()
	if not FileAccess.file_exists(PATH):
		return d
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return d
	var txt := f.get_as_text()
	f.close()
	var raw = JSON.parse_string(txt)
	if typeof(raw) != TYPE_DICTIONARY:
		return d
	# schema_version 只记录版本；读取时统一补齐为当前结构，避免旧档缺字段时报错。
	d["schema_version"] = SCHEMA_VERSION
	d["updated"] = str(raw.get("updated", ""))
	var raw_cases = raw.get("cases", {})
	if typeof(raw_cases) == TYPE_DICTIONARY:
		for c in CASES:
			var id: String = c["id"]
			if raw_cases.has(id):
				d["cases"][id] = _normalize_case(raw_cases[id])
	return d


static func save_data(d: Dictionary) -> bool:
	d["schema_version"] = SCHEMA_VERSION
	d["updated"] = _now()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("ArchiveStore: 无法写入 %s" % PATH)
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return true


static func _entry(d: Dictionary, id: String) -> Dictionary:
	var cases: Dictionary = d.get("cases", {})
	if not cases.has(id):
		cases[id] = empty_case()
		d["cases"] = cases
	return cases[id]


# ------------------------------------------------------------------ 记录

## 新开一局：游玩次数 +1，状态变为「进行中」。
static func note_play(id := "0017") -> Dictionary:
	var d := load_data()
	var e := _entry(d, id)
	e["plays"] = int(e.get("plays", 0)) + 1
	e["started"] = true
	e["last_played"] = _now()
	d["cases"][id] = e
	save_data(d)
	return d


## 进行中的进度：只升不降，用于最佳轮次 / 最佳时钟。
static func note_progress(id: String, round_idx: int, clock: float) -> Dictionary:
	var d := load_data()
	var e := _entry(d, id)
	e["started"] = true
	e["best_round"] = maxi(int(e.get("best_round", -1)), round_idx)
	e["best_clock"] = maxf(float(e.get("best_clock", -1.0)), clock)
	e["last_played"] = _now()
	d["cases"][id] = e
	save_data(d)
	return d


## 抵达结局：结案，并登记 A/B/C（重复结局只记一次）。
static func note_ending(id: String, kind: String, round_idx := -1, clock := -1.0) -> Dictionary:
	var d := load_data()
	var e := _entry(d, id)
	e["completed"] = true
	e["started"] = true
	var ends: Array = e.get("endings", [])
	var k := kind.to_upper()
	if ENDING_KEYS.has(k) and not ends.has(k):
		ends.append(k)
	ends.sort()
	e["endings"] = ends
	e["best_round"] = maxi(int(e.get("best_round", -1)), round_idx)
	e["best_clock"] = maxf(float(e.get("best_clock", -1.0)), clock)
	e["plays"] = maxi(1, int(e.get("plays", 0)))   # 旧存档直接通关时也至少算一次
	e["last_played"] = _now()
	d["cases"][id] = e
	save_data(d)
	return d


# ------------------------------------------------------------------ 查询

static func status_of(e: Dictionary) -> String:
	if bool(e.get("completed", false)):
		return "已结案"
	if bool(e.get("started", false)) or int(e.get("plays", 0)) > 0:
		return "进行中"
	return "未开始"


static func endings_seen(e: Dictionary) -> int:
	var ends = e.get("endings", [])
	return ends.size() if typeof(ends) == TYPE_ARRAY else 0


static func totals(d: Dictionary) -> Dictionary:
	var completed := 0
	var cases: Dictionary = d.get("cases", {})
	for c in CASES:
		if c["id"] == "finale":
			continue
		if bool(cases.get(c["id"], {}).get("completed", false)):
			completed += 1
	var first: Dictionary = cases.get("0017", empty_case())
	return {
		"completed": completed,
		"case_total": CASE_TOTAL,
		"endings_seen": endings_seen(first),
		"ending_total": ENDING_KEYS.size(),
	}


static func summary_text(d: Dictionary) -> String:
	var t := totals(d)
	return "已结案 %d/%d · 结局 %d/%d" % [t["completed"], t["case_total"], t["endings_seen"], t["ending_total"]]


## 绝对分钟 → HH:MM；没有记录时返回 --:--
static func clock_text(clock: float) -> String:
	if clock < 0.0:
		return "--:--"
	var mm := ((int(clock) % 1440) + 1440) % 1440
	return "%02d:%02d" % [mm / 60, mm % 60]


# ------------------------------------------------------------------ 导出 / 导入

static func export_text() -> String:
	var d := load_data()
	d["exported_at"] = _now()
	d["game"] = "诡异事务局 · 第一季「补丁」"
	return JSON.stringify(d, "\t")


static func export_to_file(path := EXPORT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(export_text())
	f.close()
	return true


## 导入并合并（幂等）：结局取并集，轮次/时钟取更远，游玩次数取较大值。
## 返回 {ok, error, added_endings, data}
static func import_text(text: String) -> Dictionary:
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "error": "不是有效的 JSON 档案", "added_endings": 0}
	if not raw.has("cases") or typeof(raw.get("cases")) != TYPE_DICTIONARY:
		return {"ok": false, "error": "档案缺少 cases 字段", "added_endings": 0}
	if raw.has("schema_version") and int(raw.get("schema_version", SCHEMA_VERSION)) > SCHEMA_VERSION:
		return {"ok": false, "error": "档案版本高于当前游戏（v%d）" % SCHEMA_VERSION, "added_endings": 0}

	var cur := load_data()
	var incoming: Dictionary = raw["cases"]
	var added := 0
	for c in CASES:
		var id: String = c["id"]
		if not incoming.has(id):
			continue
		var a: Dictionary = _entry(cur, id)
		var b := _normalize_case(incoming[id])
		if not bool(a.get("started", false)):
			a = b.duplicate(true)
			added += endings_seen(b)
			cur["cases"][id] = a
			continue
		var before := endings_seen(a)
		var ends: Array = a.get("endings", []).duplicate()
		for k in b.get("endings", []):
			if not ends.has(k):
				ends.append(k)
		ends.sort()
		a["endings"] = ends
		added += endings_seen(a) - before
		a["completed"] = bool(a.get("completed", false)) or bool(b.get("completed", false))
		a["started"] = true
		a["best_round"] = maxi(int(a.get("best_round", -1)), int(b.get("best_round", -1)))
		a["best_clock"] = maxf(float(a.get("best_clock", -1.0)), float(b.get("best_clock", -1.0)))
		a["plays"] = maxi(int(a.get("plays", 0)), int(b.get("plays", 0)))
		if str(b.get("last_played", "")) > str(a.get("last_played", "")):
			a["last_played"] = b["last_played"]
		cur["cases"][id] = a
	save_data(cur)
	return {"ok": true, "error": "", "added_endings": added, "data": cur}
