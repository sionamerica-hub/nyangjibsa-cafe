extends Node
class_name TimePeriodManager
## 냥집사 카페 — 시간대 7구간 (KST 매핑)
## 기획서 §13.3 — TimePeriodManager

const SIGNAL_PERIOD := 60.0

const PERIODS := {
    "새벽":     {"coin_mult": 1.0, "customer_mult": 0.0, "jelly_bonus": 0, "is_peak": false, "is_closed": true},
    "아침":     {"coin_mult": 1.1, "customer_mult": 1.0, "jelly_bonus": 0, "is_peak": false, "is_closed": false},
    "오전":     {"coin_mult": 1.0, "customer_mult": 1.0, "jelly_bonus": 0, "is_peak": false, "is_closed": false},
    "점심피크": {"coin_mult": 1.5, "customer_mult": 2.0, "jelly_bonus": 5, "is_peak": true,  "is_closed": false},
    "오후":     {"coin_mult": 1.0, "customer_mult": 1.0, "jelly_bonus": 0, "is_peak": false, "is_closed": false},
    "저녁피크": {"coin_mult": 1.5, "customer_mult": 2.0, "jelly_bonus": 5, "is_peak": true,  "is_closed": false},
    "심야":     {"coin_mult": 1.2, "customer_mult": 1.0, "jelly_bonus": 0, "is_peak": false, "is_closed": false},
}

var current_period: String = "오전"
var signal_bus: Node = null
var _peak_warned_today: Dictionary = {}

func _ready() -> void:
    signal_bus = _try_get_singleton("SignalBus")
    var t := Timer.new()
    t.wait_time = SIGNAL_PERIOD
    t.autostart = true
    t.one_shot = false
    t.timeout.connect(_on_tick)
    add_child(t)
    _recompute(true)
    print("[TimePeriodManager] 시작 — 7구간, KST 매핑")

static func get_kst_datetime_dict() -> Dictionary:
    var utc := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()))
    var hour := (int(utc.hour) + 9) % 24
    return {"hour": hour, "minute": int(utc.minute)}

static func kst_hour() -> int:
    return get_kst_datetime_dict().hour

static func kst_minute() -> int:
    return get_kst_datetime_dict().minute

func _resolve_period(hour: int) -> String:
    if hour >= 0 and hour < 6:  return "새벽"
    if hour >= 6 and hour < 10: return "아침"
    if hour >= 10 and hour < 12: return "오전"
    if hour >= 12 and hour < 14: return "점심피크"
    if hour >= 14 and hour < 17: return "오후"
    if hour >= 17 and hour < 21: return "저녁피크"
    if hour >= 21 and hour < 24: return "심야"
    return "심야"

func _on_tick() -> void:
    _recompute(false)

func _recompute(force_emit: bool) -> void:
    var h := kst_hour()
    var prev := current_period
    current_period = _resolve_period(h)
    if force_emit or prev != current_period:
        print("[TimePeriodManager] KST=%02d → %s" % [h, current_period])
        if signal_bus != null and signal_bus.has_signal("time_period_changed"):
            signal_bus.emit_signal("time_period_changed", current_period)
        _maybe_peak_warning()

func _maybe_peak_warning() -> void:
    var d := get_kst_datetime_dict()
    var m := d.hour * 60 + d.minute
    var targets := [
        {"name": "점심피크", "fire_at": 11 * 60 + 30},
        {"name": "저녁피크", "fire_at": 16 * 60 + 30},
    ]
    for t in targets:
        var key := "%02d:%02d-%s" % [d.hour, d.minute, t.name]
        var fired := _peak_warned_today.get(key, false)
        if not fired and m >= t.fire_at and m < t.fire_at + 2:
            _peak_warned_today[key] = true
            print("[TimePeriodManager] ⚠ 피크 경고: %s 30분 전" % t.name)
            if signal_bus != null and signal_bus.has_signal("peak_warning"):
                signal_bus.emit_signal("peak_warning", t.name)

func get_current_period() -> String:
    return current_period

func get_multiplier() -> float:
    return float(PERIODS[current_period].coin_mult)

func get_customer_bonus() -> float:
    return float(PERIODS[current_period].customer_mult)

func get_jelly_bonus() -> int:
    return int(PERIODS[current_period].jelly_bonus)

func is_closed() -> bool:
    return bool(PERIODS[current_period].is_closed)

func is_peak() -> bool:
    return bool(PERIODS[current_period].is_peak)

func get_period_info() -> Dictionary:
    return {
        "period": current_period,
        "kst_hour": kst_hour(),
        "kst_minute": kst_minute(),
        "coin_mult": get_multiplier(),
        "customer_mult": get_customer_bonus(),
        "jelly_bonus": get_jelly_bonus(),
        "is_closed": is_closed(),
        "is_peak": is_peak(),
    }

func get_ovemight_bonus() -> float:
    return 1.30

func _try_get_singleton(name: String) -> Node:
    var root := Engine.get_main_loop()
    if root == null:
        return null
    var tree := root as SceneTree
    if tree == null:
        return null
    if tree.root != null and tree.root.has_node(name):
        return tree.root.get_node(name)
    return null
