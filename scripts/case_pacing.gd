extends RefCounted
## Clock previews and playback share these ordered events. Later nights use
## their evidence/dialogue/operation beats instead of replaying the first shift.
const FIRST_SHIFT := [
	["bc1",21.0,"00:01 第一遍广播"],
	["bc2",40.0,"00:20 第二遍广播"],
	["oldlady",90.0,"01:10 来客"],
	["beat13",170.0,"02:30 停电"],
	["beat14",171.0,"02:31 擦拭"],
	["count",210.0,"03:10 清点衣物"],
	["ask",240.0,"03:40 核对与回应"],
]
const RETURN_SHIFT := [["oldlady",90.0,"01:10 周秀兰到店"]]
const EPILOGUE := [
	["handover",255.0,"03:55 交班"],
	["handover_items",256.0,"03:56 工资回执"],
	["recorded",258.0,"03:58 录名"],
	["dawn4",260.0,"04:00 天亮"],
	["aqi_line",261.0,"04:01 长椅"],
	["case_end",262.0,"04:02 归档"],
]

static func events_for(night: int, concluded: bool) -> Array[Dictionary]:
	var rows: Array = EPILOGUE if concluded else (FIRST_SHIFT if night==1 else RETURN_SHIFT)
	var events: Array[Dictionary] = []
	for row in rows:events.append({"id":String(row[0]),"at":float(row[1]),"label":String(row[2])})
	return events
