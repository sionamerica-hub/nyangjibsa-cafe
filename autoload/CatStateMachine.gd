extends Node
## 냥집사 카페 — 캣 상태 머신 (Autoload)
## 캣 군집(placed_cats)의 hunger/activity/rest 실시간 변동
## TimePeriodManager 연동 (아침=활동↑, 새벽=휴식↑, 점심피크=만복↑)
## BalanceMeter 자동 계산 (캣 군집 평균 → 점수 → 코인/행복도 보정)
##
## 데이터 모델:
##   cats_state: Dictionary
##     cat_id -> {hunger:float, activity:float, rest:float,
##                happiness:float, last_fed_at:int, last_play_at:int, last_rest_at:int}
##
## 시그널:
##   cat_state_changed(cat_id, state_dict)
##   cat_happiness_low(cat_id, value)  # value < 30
##   balance_avg_changed(avg_dict)

const TICK_SEC: float = 1.0

# 변동률 (단위: /초)
const HUNGER_DECAY_PER_SEC: float = 0.5     # 포만감은 시간이지남 → 감소
const ACTIVITY_DECAY_PER_SEC: float = 0.3   # 활동 욕구 시간이지남 → 감소
const REST_DECAY_PER_SEC: float = 0.2       # 휴식 욕구 시간이지남 → 감소

# 시간대별 변동 계수
const PERIOD_HUNGER_MULT := {"새벽":0.3,"아침":1.0,"오전":1.2,"점심피크":1.5,
	"오후":1.0,"저녁피크":1.3,"심야":0.7}
const PERIOD_ACTIVITY_MULT := {"새벽":0.1,"아침":1.2,"오전":1.5,"점심피크":0.8,
	"오후":1.2,"저녁피크":1.0,"심야":0.4}
const PERIOD_REST_MULT := {"새벽":1.8,"아침":0.6,"오전":0.5,"점심피크":0.4,
	"오후":0.7,"저녁피크":1.0,"심야":1.4}

# 0~100 안전 범위
const MIN_V: float = 0.0
const MAX_V: float = 100.0

# Action delta (외부 호출 시 한 번에 변경량)
const FEED_HUNGER_DELTA: float = 25.0
const PLAY_ACTIVITY_DELTA: float = 20.0
const NAP_REST_DELTA: float = 30.0

var cats_state: Dictionary = {}    # cat_id -> state
var tick_timer: Timer = null
var signal_bus: Node = null
var period_mgr: Node = null
var balance_meter: Node = null
var _last_period: String = ""

signal cat_state_changed(cat_id: String, state: Dictionary)
signal cat_happiness_low(cat_id: String, value: float)
signal balance_avg_changed(avg: Dictionary)

func _ready() -> void:
	signal_bus = _try_get_singleton("SignalBus")
	period_mgr = _try_get_singleton("TimePeriodManager")
	balance_meter = _try_get_singleton("BalanceMeter")
	if period_mgr != null and period_mgr.has_signal("time_period_changed"):
		period_mgr.connect("time_period_changed", _on_period_changed)
	_setup_tick()
	# 초기 1마리 자동 배치 (데모)
	_register_cat("demo_cat")
	print("[CatStateMachine] 시작 — %d초 틱" % int(TICK_SEC))

func _on_period_changed(new_period: String) -> void:
	if new_period != _last_period:
		print("[CatStateMachine] ⏰ 시간대 변경 → %s" % new_period)
		_last_period = new_period

func _setup_tick() -> void:
	tick_timer = Timer.new()
	tick_timer.wait_time = TICK_SEC
	tick_timer.autostart = true
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)

## 캣 등록 (이미 있으면 리셋하지 않음)
func _register_cat(cat_id: String, base_hunger: float = 50.0,
		base_activity: float = 50.0, base_rest: float = 50.0) -> bool:
	if cats_state.has(cat_id):
		return false
	var now: int = int(Time.get_ticks_msec())
	cats_state[cat_id] = {
		"hunger": base_hunger, "activity": base_activity, "rest": base_rest,
		"happiness": 100.0,
		"last_fed_at": now, "last_play_at": now, "last_rest_at": now,
		"last_satisfaction": 100,
	}
	_on_cat_state_internal(cat_id, cats_state[cat_id])
	print("[CatStateMachine] 등록: %s (hunger=%.0f activity=%.0f rest=%.0f)" %
		[cat_id, base_hunger, base_activity, base_rest])
	return true

func unregister_cat(cat_id: String) -> void:
	if cats_state.has(cat_id):
		cats_state.erase(cat_id)
		_refresh_balance_average()

## 매 초 변동
func _on_tick() -> void:
	if cats_state.is_empty():
		return
	var period: String = "오전"
	if period_mgr != null:
		period = String(period_mgr.get_current_period())
	var hunger_mult: float = float(PERIOD_HUNGER_MULT.get(period, 1.0))
	var activity_mult: float = float(PERIOD_ACTIVITY_MULT.get(period, 1.0))
	var rest_mult: float = float(PERIOD_REST_MULT.get(period, 1.0))

	var keys: Array = cats_state.keys()
	for k in keys:
		var cat_id: String = String(k)
		var st: Dictionary = cats_state[cat_id]
		var h: float = float(st.get("hunger", 50.0))
		var a: float = float(st.get("activity", 50.0))
		var r: float = float(st.get("rest", 50.0))
		# hunger: 시간 지날수록 감소 (배고파짐)
		h = clampf(h - HUNGER_DECAY_PER_SEC * hunger_mult, MIN_V, MAX_V)
		# activity: 시간 지날수록 감소 (흥미로움 → 지루함)
		a = clampf(a - ACTIVITY_DECAY_PER_SEC * activity_mult, MIN_V, MAX_V)
		# rest: 새벽이면 늘어남, 낮이면 줄어듦
		var rest_delta: float = REST_DECAY_PER_SEC * rest_mult
		if period == "새벽":
			rest_delta = -rest_delta * 1.5
		r = clampf(r - rest_delta, MIN_V, MAX_V)
		# 행복도 재계산
		var lo: float = min(h, min(a, r))
		var hi: float = max(h, max(a, r))
		var happy: float = 0.0
		if hi > 0.001:
			happy = clampf((lo / hi) * 100.0, 0.0, 100.0)

		st["hunger"] = h
		st["activity"] = a
		st["rest"] = r
		st["happiness"] = happy

		cats_state[cat_id] = st
		_on_cat_state_internal(cat_id, st)
		# 행복도 경고
		if happy < 30.0:
			cat_happiness_low.emit(cat_id, happy)

	_refresh_balance_average()

func _on_cat_state_internal(cat_id: String, st: Dictionary) -> void:
	cat_state_changed.emit(cat_id, st)
	# SignalBus로 전달 (다른 시스템 구독)
	if signal_bus != null and signal_bus.has_method("emit_cat_happiness"):
		signal_bus.emit_cat_happiness(cat_id, float(st.happiness))
	_refresh_balance_average()

## 캣 군집 평균 → BalanceMeter에 주입
func _refresh_balance_average() -> void:
	if cats_state.is_empty():
		return
	var sum_h: float = 0.0
	var sum_a: float = 0.0
	var sum_r: float = 0.0
	var n: float = 0.0
	for cat_id in cats_state.keys():
		var st: Dictionary = cats_state[cat_id]
		sum_h += float(st.hunger)
		sum_a += float(st.activity)
		sum_r += float(st.rest)
		n += 1.0
	if n < 1.0:
		return
	var avg_h := sum_h / n
	var avg_a := sum_a / n
	var avg_r := sum_r / n
	# BalanceMeter가 있으면 set_stats 호출
	if balance_meter != null and balance_meter.has_method("set_stats"):
		balance_meter.set_stats(avg_h, avg_a, avg_r)
	balance_avg_changed.emit({
		"hunger": avg_h, "activity": avg_a, "rest": avg_r,
		"cat_count": int(n),
		"score": int(balance_meter.get_balance_score()) if balance_meter != null and balance_meter.has_method("get_balance_score") else 0,
	})

## ==================================================
## 외부 API — 먹이기/놀아주기/재우기
## ==================================================
func feed(cat_id: String, amount: float = FEED_HUNGER_DELTA) -> Dictionary:
	if not cats_state.has(cat_id):
		return {"ok": false, "reason": "unknown_cat"}
	var st: Dictionary = cats_state[cat_id]
	var before: float = float(st.hunger)
	st["hunger"] = clampf(before + amount, MIN_V, MAX_V)
	st["last_fed_at"] = int(Time.get_ticks_msec())
	cats_state[cat_id] = st
	_on_cat_state_internal(cat_id, st)
	return {"ok": true, "before": before, "after": float(st.hunger), "delta": float(st.hunger) - before}

func play(cat_id: String, amount: float = PLAY_ACTIVITY_DELTA) -> Dictionary:
	if not cats_state.has(cat_id):
		return {"ok": false, "reason": "unknown_cat"}
	var st: Dictionary = cats_state[cat_id]
	var before: float = float(st.activity)
	st["activity"] = clampf(before + amount, MIN_V, MAX_V)
	st["last_play_at"] = int(Time.get_ticks_msec())
	cats_state[cat_id] = st
	_on_cat_state_internal(cat_id, st)
	return {"ok": true, "before": before, "after": float(st.activity), "delta": float(st.activity) - before}

func nap(cat_id: String, amount: float = NAP_REST_DELTA) -> Dictionary:
	if not cats_state.has(cat_id):
		return {"ok": false, "reason": "unknown_cat"}
	var st: Dictionary = cats_state[cat_id]
	var before: float = float(st.rest)
	st["rest"] = clampf(before + amount, MIN_V, MAX_V)
	st["last_rest_at"] = int(Time.get_ticks_msec())
	cats_state[cat_id] = st
	_on_cat_state_internal(cat_id, st)
	return {"ok": true, "before": before, "after": float(st.rest), "delta": float(st.rest) - before}

func get_state(cat_id: String) -> Dictionary:
	return cats_state.get(cat_id, {})

func get_all_states() -> Dictionary:
	return cats_state.duplicate(true)

func get_cat_count() -> int:
	return cats_state.size()

## 공개 등록 (외부에서 호출 가능)
func register_cat(cat_id: String, hunger: float = 50.0,
		activity: float = 50.0, rest: float = 50.0) -> bool:
	return _register_cat(cat_id, hunger, activity, rest)

## 유틸
func _try_get_singleton(singleton_name: String) -> Node:
	var root: Object = Engine.get_main_loop()
	if root == null: return null
	var tree: SceneTree = root as SceneTree
	if tree == null: return null
	if tree.root != null and tree.root.has_node(singleton_name):
		return tree.root.get_node(singleton_name)
	return null