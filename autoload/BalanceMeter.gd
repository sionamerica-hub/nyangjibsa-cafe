extends Node
class_name BalanceMeter
## 냥집사 카페 — 균형 점수 시스템 (Autoload)
## 매 5초마다 (min / max) × 100 점수 산출, 5구간 라벨 발급
## 기획서: BalanceMeter(균형 점수 — min/max 공식, 5구간 라벨)

## ----- 의존성 -----
const SIGNAL_PERIOD := 5.0
var signal_bus: Node = null

## ----- 현재 상태 -----
var hunger: float = 50.0
var activity: float = 50.0
var rest: float = 50.0

## ----- 통계 -----
var _score_cache: int = 0
var _label_cache: String = "😊 좋음"

func _ready() -> void:
    signal_bus = _try_get_singleton("SignalBus")
    var t := Timer.new()
    t.wait_time = SIGNAL_PERIOD
    t.autostart = true
    t.one_shot = false
    t.timeout.connect(_on_tick)
    add_child(t)
    _recompute()
    print("[BalanceMeter] 시작 — 주기 %.0f초, 5구간 라벨" % SIGNAL_PERIOD)

func set_stats(p_hunger: float, p_activity: float, p_rest: float) -> void:
    hunger = clamp(p_hunger, 0.0, 100.0)
    activity = clamp(p_activity, 0.0, 100.0)
    rest = clamp(p_rest, 0.0, 100.0)

func _recompute() -> int:
    var lo := min(hunger, min(activity, rest))
    var hi := max(hunger, max(activity, rest))
    var score: int
    if hi <= 0.0001:
        score = 0
    else:
        score = int(round((lo / hi) * 100.0))
    _score_cache = clamp(score, 0, 100)
    _label_cache = _label_for(_score_cache)
    return _score_cache

func _label_for(score: int) -> String:
    if score >= 80: return "🏆 완벽"
    if score >= 60: return "😊 좋음"
    if score >= 40: return "😐 보통"
    if score >= 20: return "😿 불만"
    return "😾 반란"

func get_happiness_modifier() -> float:
    var s := _score_cache
    if s >= 80: return 1.30
    if s >= 60: return 1.00
    if s >= 40: return 0.90
    if s >= 20: return 0.70
    return 0.30

func get_multiplier() -> float:
    var s := _score_cache
    if s >= 80: return 1.3
    if s >= 60: return 1.0
    if s >= 40: return 1.0
    if s >= 20: return 0.7
    return 0.0

func get_balance_score() -> int:
    return _recompute()

func get_label() -> String:
    return _label_cache

func get_score_breakdown() -> Dictionary:
    return {
        "hunger": hunger,
        "activity": activity,
        "rest": rest,
        "score": _score_cache,
        "label": _label_cache,
        "happiness_mod": get_happiness_modifier(),
        "coin_mult": get_multiplier(),
    }

func _on_tick() -> void:
    var score := _recompute()
    var label := _label_cache
    print("[BalanceMeter] score=%d (%s)" % [score, label])
    if signal_bus != null and signal_bus.has_signal("balance_score_changed"):
        signal_bus.emit_signal("balance_score_changed", score, label)
    if _label_cache == "😾 반란":
        _apply_rebellion_penalty()

func _apply_rebellion_penalty() -> void:
    var save := _try_get_singleton("SaveManager")
    if save == null:
        return
    if int(save.data.get("rebellion_lock_until", 0)) > int(Time.get_unix_time_from_system()):
        return
    var cur: int = int(save.data.get("coin", 0))
    save.data["coin"] = max(0, cur - 300)
    save.data["rebellion_lock_until"] = int(Time.get_unix_time_from_system()) + 3600
    save.save_data()
    print("[BalanceMeter] 😾 반란 페널티 — 300 코인 차감, 1시간 회복")

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
