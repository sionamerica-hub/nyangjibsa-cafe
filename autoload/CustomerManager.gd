extends Node
## 냥집사 카페 — 손님 매니저 (Autoload)
## 손님 도착 → 메뉴 매칭 → 결제 → 만족도/팁 → LeaveMessage
##
## 시그널:
##   customer_arrived(customer_data, payload_dict)
##   customer_served(satisfaction, coin, jelly)
##   customer_left_satisfied(customer_data, summary)
##   customer_left_angry(customer_data, summary)
##
## 의존성: SaveManager (코인/젤리 변경), TimePeriodManager (새벽 손님 차단), SignalBus

const SPAWN_MIN_SEC: float = 10.0
const SPAWN_MAX_SEC: float = 30.0
const PATIENCE_MULT_BY_PERIOD := {
	"새벽":   0.5,
	"아침":   1.2,
	"오전":   1.0,
	"점심피크": 0.7,
	"오후":   1.0,
	"저녁피크": 0.7,
	"심야":   0.9,
}

const MENU := ["아메리카노", "라떼", "밀크티", "바닐라라떼", "카푸치노", "딸기스무디"]

var spawn_timer: Timer = null
var patience_timer: Timer = null
var current_customer: Resource = null
var current_arrived_at: float = 0.0
var current_drink: String = ""
var current_drink_match: String = ""
var signal_bus: Node = null
var save_mgr: Node = null
var period_mgr: Node = null

signal customer_arrived(customer_data, payload: Dictionary)
signal customer_served(satisfaction: int, coin: int, jelly: int)
signal customer_left_satisfied(customer_data, summary: Dictionary)
signal customer_left_angry(customer_data, summary: Dictionary)

var CUSTOMER_POOL: Array = []
const CUSTOMER_DIR := "res://data/customers/"

func _ready() -> void:
	signal_bus = _try_get_singleton("SignalBus")
	save_mgr = _try_get_singleton("SaveManager")
	period_mgr = _try_get_singleton("TimePeriodManager")
	_load_customer_pool()
	_setup_spawn_timer()
	_setup_patience_timer()
	print("[CustomerManager] 시작 — 손님 풀 %d명" % CUSTOMER_POOL.size())

func _load_customer_pool() -> void:
	CUSTOMER_POOL.clear()
	var dir: DirAccess = DirAccess.open(CUSTOMER_DIR)
	if dir == null:
		push_error("[CustomerManager] 폴더 없음: " + CUSTOMER_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var path: String = CUSTOMER_DIR + fname
			var res: Resource = load(path)
			if res != null and res is CustomerData:
				CUSTOMER_POOL.append(res)
				print("  · 손님 로드: %s (%s)" % [res.display_name, res.preferred_drink])
		fname = dir.get_next()
	dir.list_dir_end()
	if CUSTOMER_POOL.is_empty():
		push_warning("[CustomerManager] 손님 풀 비어있음 — 기본 손님 fallback")
		_make_fallback_pool()

func _make_fallback_pool() -> void:
	const CustomerDataScript := preload("res://scripts/CustomerData.gd")
	CUSTOMER_POOL.append(CustomerDataScript.new(
		"fallback_01", "기본손님", "아메리카노",
		["아메리카노", "라떼"], [], "친절함",
		30.0, 0, 2, 50, "🙂", "기본 손님"
	))

func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(spawn_timer)
	_schedule_next_spawn()

func _schedule_next_spawn() -> void:
	if spawn_timer == null:
		return
	var wait := randf_range(SPAWN_MIN_SEC, SPAWN_MAX_SEC)
	spawn_timer.start(wait)

func _setup_patience_timer() -> void:
	patience_timer = Timer.new()
	patience_timer.wait_time = 0.5
	patience_timer.autostart = true
	patience_timer.timeout.connect(_on_patience_tick)
	add_child(patience_timer)

func _on_spawn_tick() -> void:
	_spawn_customer()
	_schedule_next_spawn()

func _on_patience_tick() -> void:
	if current_customer == null:
		return
	var elapsed := Time.get_ticks_msec() / 1000.0 - current_arrived_at
	var patience: float = float(current_customer.patience_sec)
	if period_mgr != null:
		var period: String = String(period_mgr.get_current_period())
		var mult: float = float(PATIENCE_MULT_BY_PERIOD.get(period, 1.0))
		patience *= mult
	if elapsed >= patience:
		_force_customer_leave("patience_timeout")

func _spawn_customer() -> void:
	if current_customer != null:
		print("[CustomerManager] 이미 손님 있음 — 스킵")
		return
	if period_mgr != null and String(period_mgr.get_current_period()) == "새벽":
		print("[CustomerManager] 🌙 새벽 — 손님 없음")
		return
	if period_mgr != null:
		var mult: float = float(period_mgr.get_customer_bonus())
		if mult <= 0.0:
			return
		if randf() > clampf(mult / 2.0, 0.0, 1.0):
			return

	var cd: Resource = _pick_customer_from_pool()
	if cd == null:
		return

	current_customer = cd
	current_arrived_at = Time.get_ticks_msec() / 1000.0
	current_drink = ""
	current_drink_match = ""

	var payload := {
		"customer": cd,
		"menu": MENU.duplicate(),
		"elapsed_sec": 0.0,
		"patience_sec": _effective_patience(cd),
	}
	customer_arrived.emit(cd, payload)
	if signal_bus != null and signal_bus.has_method("emit_cat_arrived"):
		signal_bus.emit_cat_arrived(cd.id)
	print("🔔 손님 도착: %s — %s 선호 (인내심 %.0f초)" %
		[cd.display_name, cd.preferred_drink, float(payload.patience_sec)])

func _effective_patience(cd) -> float:
	var p: float = float(cd.patience_sec)
	if period_mgr != null:
		var period: String = String(period_mgr.get_current_period())
		var mult: float = float(PATIENCE_MULT_BY_PERIOD.get(period, 1.0))
		p *= mult
	return p

func _make_customer_from_template(template: Dictionary) -> Resource:
	const CustomerDataScript := preload("res://scripts/CustomerData.gd")
	var cd = CustomerDataScript.new(
		String(template.id), String(template.name), String(template.drink),
		Array(template.acceptable), Array(template.rejected),
		String(template.personality), float(template.patience),
		int(template.tip_min), int(template.tip_max), int(template.coin),
		String(template.emoji), String(template.flavor)
	)
	return cd

func serve_drink(drink: String) -> Dictionary:
	if current_customer == null:
		return {"ok": false, "reason": "no_customer"}
	current_drink = drink
	var match: String = current_customer.match_drink(drink)
	current_drink_match = match

	var waited: float = _get_waited_ratio()
	const CustomerDataScript := preload("res://scripts/CustomerData.gd")
	var satisfaction: int = CustomerDataScript.compute_satisfaction(match, waited)
	var coin: int = _calc_coin_reward(current_customer, satisfaction)
	var jelly: int = current_customer.roll_tip_jelly(satisfaction)

	if save_mgr != null:
		save_mgr.add_coin(coin)
		save_mgr.add_jelly(jelly)

	customer_served.emit(satisfaction, coin, jelly)
	var summary := {
		"customer_id": current_customer.id,
		"customer_name": current_customer.display_name,
		"drink": drink,
		"match": match,
		"waited_ratio": waited,
		"satisfaction": satisfaction,
		"coin_earned": coin,
		"jelly_earned": jelly,
	}
	print("✅ 제공: %s — %s 만족도=%d 코인=%d 젤리=%d" %
		[current_customer.display_name, drink, satisfaction, coin, jelly])

	var left: bool = satisfaction >= 40
	if left:
		customer_left_satisfied.emit(current_customer, summary)
	else:
		customer_left_angry.emit(current_customer, summary)
	_clear_customer()
	return {"ok": true, "summary": summary, "satisfaction": satisfaction}

func _force_customer_leave(reason: String) -> void:
	if current_customer == null:
		return
	var summary := {
		"customer_id": current_customer.id,
		"customer_name": current_customer.display_name,
		"reason": reason,
		"satisfaction": 0,
		"coin_earned": 0,
		"jelly_earned": 0,
	}
	customer_left_angry.emit(current_customer, summary)
	print("⏰ 인내심 초과 — %s 강제 퇴장" % current_customer.display_name)
	_clear_customer()

func _clear_customer() -> void:
	current_customer = null
	current_drink = ""
	current_drink_match = ""

func _pick_customer_from_pool() -> Resource:
	if CUSTOMER_POOL.is_empty():
		return null
	var regulars: Array = CUSTOMER_POOL.filter(
		func(c): return c != null and c.is_regular
	)
	if not regulars.is_empty() and randf() < 0.3:
		return regulars[randi() % regulars.size()]
	return CUSTOMER_POOL[randi() % CUSTOMER_POOL.size()]

func _get_waited_ratio() -> float:
	if current_customer == null:
		return 0.0
	var elapsed := Time.get_ticks_msec() / 1000.0 - current_arrived_at
	var patience: float = _effective_patience(current_customer)
	return clampf(elapsed / patience, 0.0, 1.5)

func _calc_coin_reward(cd, satisfaction: int) -> int:
	var base: int = cd.base_coin_reward
	var mult: float
	if satisfaction >= 100: mult = 1.5
	elif satisfaction >= 80: mult = 1.3
	elif satisfaction >= 60: mult = 1.0
	elif satisfaction >= 40: mult = 0.7
	else: mult = 0.3
	return int(float(base) * mult)

func has_customer() -> bool:
	return current_customer != null

func get_current_customer() -> Resource:
	return current_customer

func get_current_drinks() -> Array:
	return MENU.duplicate()

func get_all_customers() -> Array:
	return CUSTOMER_POOL.duplicate()

func find_customer_by_id(id: String) -> Resource:
	for c in CUSTOMER_POOL:
		if c != null and c.id == id:
			return c
	return null

func get_regular_customers() -> Array:
	return CUSTOMER_POOL.filter(func(c): return c != null and c.is_regular)

func get_waited_ratio() -> float:
	return _get_waited_ratio()

func _try_get_singleton(singleton_name: String) -> Node:
	var root: Object = Engine.get_main_loop()
	if root == null: return null
	var tree: SceneTree = root as SceneTree
	if tree == null: return null
	if tree.root != null and tree.root.has_node(singleton_name):
		return tree.root.get_node(singleton_name)
	return null