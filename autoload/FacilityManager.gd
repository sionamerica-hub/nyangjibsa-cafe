extends Node
## 냥집사 카페 — 시설 매니저 (Autoload)
## 4단계 시설(Lv1~Lv4) 관리 + 업그레이드 의사결정
## res://data/facilities/*.tres 자동 로드

const FACILITIES_DIR := "res://data/facilities/"
const FACILITY_SCRIPT := preload("res://scripts/FacilityData.gd")

var facilities: Dictionary = {}  ## id → FacilityData
var facilities_by_level: Dictionary = {}  ## level(int) → FacilityData
var current_level: int = 1
var upgrade_started_at: int = 0  ## unix timestamp ms
var upgrade_in_progress: bool = false

func _ready() -> void:
	_load_all_facilities()
	print("🏢 FacilityManager 시작 — 시설 %d개 등록 (현재 Lv %d)" %
		[facilities.size(), current_level])

func _load_all_facilities() -> void:
	facilities.clear()
	facilities_by_level.clear()
	var dir := DirAccess.open(FACILITIES_DIR)
	if dir == null:
		push_error("시설 디렉토리 없음: %s" % FACILITIES_DIR)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".tres"):
			var path := FACILITIES_DIR + name
			var res: Resource = load(path)
			if res != null and res.get_script() == FACILITY_SCRIPT:
				facilities[res.id] = res
				facilities_by_level[res.level] = res
		name = dir.get_next()
	dir.list_dir_end()

func get_current() -> Resource:
	var fac: Resource = facilities_by_level.get(current_level, null)
	if fac == null and facilities_by_level.size() > 0:
		var keys := facilities_by_level.keys()
		keys.sort()
		fac = facilities_by_level[keys[0]]
	return fac

func get_by_level(lv: int) -> Resource:
	return facilities_by_level.get(lv, null)

func can_upgrade() -> bool:
	var next_lv := current_level + 1
	if next_lv > 4:
		return false
	var next_fac: Resource = facilities_by_level.get(next_lv, null)
	if next_fac == null:
		return false
	return true

func get_upgrade_cost() -> int:
	var next_lv := current_level + 1
	if next_lv > 4:
		return -1
	var next_fac: Resource = facilities_by_level.get(next_lv, null)
	if next_fac == null:
		return -1
	return next_fac.required_coin

func upgrade_to(level: int) -> bool:
	if level < 1 or level > 4:
		push_warning("잘못된 시설 레벨: %d" % level)
		return false
	if not facilities_by_level.has(level):
		push_warning("시설 데이터 없음: Lv %d" % level)
		return false
	var target: Resource = facilities_by_level[level]
	if target.required_coin > 0:
		print("💰 업그레이드 Lv %d: 코인 %d 필요" % [level, target.required_coin])
	current_level = level
	upgrade_in_progress = false
	print("🏢 시설 업그레이드 완료 → Lv %d %s (코인 %d/분 · 슬롯 %d)" %
		[level, target.display_name, target.coin_per_min, target.slot_count])
	SignalBus.balance_score_changed.emit(-1, "facility_lv%d" % level)
	return true

func get_total_coin_per_min() -> int:
	var fac: Resource = get_current()
	if fac == null:
		return 0
	var base := float(fac.coin_per_min)
	if BalanceMeter != null and BalanceMeter.has_method("get_score_breakdown"):
		var info := BalanceMeter.get_score_breakdown()
		base *= info.coin_mult
	if TimePeriodManager != null and TimePeriodManager.has_method("get_period_info"):
		var info := TimePeriodManager.get_period_info()
		base *= info.coin_mult
	return int(base)

func describe_current() -> String:
	var fac: Resource = get_current()
	if fac == null:
		return "(시설 없음)"
	return fac.describe()