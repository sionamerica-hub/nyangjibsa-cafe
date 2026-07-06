extends Node
class_name OfflineReward
## 냥집사 카페 — 오프라인 복귀 보상 (Autoload)
## 기획서 §13.4 — OfflineReward (오프라인 복귀 3지 선택)
##  - instant: 젤리 30 → 행복도 +50%
##  - slow:    시간 +30분 → 행복도 +30%
##  - none:    보너스 코인 그대로

const MIN_OFFLINE_SEC := 60
const MAX_OFFLINE_HOURS := 8.0
const BASE_COIN_PER_HOUR := 200

var last_summary: Dictionary = {}
var chosen: bool = false

func _ready() -> void:
    pass

func get_offline_hours() -> float:
    var save := _try_get_singleton("SaveManager")
    if save == null:
        return 0.0
    var now := int(Time.get_unix_time_from_system())
    var last := int(save.data.get("last_play", now))
    var elapsed := max(0, now - last)
    return min(float(elapsed) / 3600.0, MAX_OFFLINE_HOURS)

func get_offline_seconds() -> int:
    var save := _try_get_singleton("SaveManager")
    if save == null:
        return 0
    var now := int(Time.get_unix_time_from_system())
    var last := int(save.data.get("last_play", now))
    return max(0, now - last)

func get_bonus_coin() -> int:
    var hours := get_offline_hours()
    return int(hours * BASE_COIN_PER_HOUR)

func get_sad_cat_count() -> int:
    var save := _try_get_singleton("SaveManager")
    if save == null:
        return 0
    var cats: Array = save.data.get("cats", [])
    var sad := 0
    for c in cats:
        if c is Dictionary and float(c.get("happiness", 100.0)) < 40.0:
            sad += 1
    return sad

func get_offline_bonus_with_period() -> int:
    var base := get_bonus_coin()
    var tpm := _try_get_singleton("TimePeriodManager")
    if tpm != null:
        var info: Dictionary = tpm.get_period_info()
        if String(info.period) == "새벽":
            base = int(base * tpm.get_ovemight_bonus())
    return base

func get_offline_summary() -> Dictionary:
    var secs := get_offline_seconds()
    if secs < MIN_OFFLINE_SEC:
        return {"available": false, "hours": 0.0,
                "bonus_coin": 0, "jelly": 0, "sad_cat_count": 0}

    var hours := get_offline_hours()
    var coins := get_offline_bonus_with_period()
    var jelly := int(hours * 3)
    var sad := get_sad_cat_count()

    var summary := {
        "available": true,
        "hours": hours,
        "bonus_coin": coins,
        "jelly": jelly,
        "sad_cat_count": sad,
        "options": [
            {"id": "instant", "label": "💖 즉각 케어",
             "desc": "잠수 캣 %d마리 행복도 +50%%" % sad,
             "cost_jelly": 30, "happiness_boost": 0.50},
            {"id": "slow", "label": "⏳ 천천히 케어",
             "desc": "오프라인 시간 +30분, 행복도 +30%% (전체)",
             "cost_jelly": 0, "happiness_boost": 0.30},
            {"id": "none", "label": "🪙 코인 수령",
             "desc": "%d 코인 받기" % coins,
             "cost_jelly": 0, "happiness_boost": 0.0},
        ]
    }
    last_summary = summary
    return summary

func choose_reward(option: String) -> Dictionary:
    var summary := last_summary
    if summary.is_empty() or not bool(summary.get("available", false)):
        summary = get_offline_summary()
    if not summary.get("available", false):
        return {"ok": false, "reason": "no_offline_reward"}

    var save := _try_get_singleton("SaveManager")
    if save == null:
        return {"ok": false, "reason": "no_save"}

    var result := {"ok": true, "option": option, "applied": {}}

    match option:
        "instant":
            var need := int(summary.jelly)
            var has := int(save.data.get("jelly", 0))
            if has < need:
                result.ok = false
                result.reason = "not_enough_jelly"
                return result
            save.data["jelly"] = has - need
            _boost_sad_cats(0.50)
            result.applied = {"jelly_spent": need, "happiness_boost": 0.50}
            print("[OfflineReward] 💖 즉각 케어 — 젤리 %d 사용, 행복도 +50%%" % need)

        "slow":
            var extra := int(30 * 60)
            save.data["last_play"] = int(Time.get_unix_time_from_system()) - extra
            _boost_all_cats(0.30)
            result.applied = {"extra_minutes": 30, "happiness_boost": 0.30}
            print("[OfflineReward] ⏳ 천천히 케어 — 시간 +30분, 행복도 +30%%")

        "none":
            var coin := int(summary.bonus_coin)
            save.data["coin"] = int(save.data.get("coin", 0)) + coin
            result.applied = {"coin_gained": coin}
            print("[OfflineReward] 🪙 코인 수령 — %d 코인" % coin)

        _:
            result.ok = false
            result.reason = "invalid_option"
            return result

    chosen = true
    save.data["last_play"] = int(Time.get_unix_time_from_system())
    save.save_data()
    return result

func _boost_sad_cats(boost_pct: float) -> void:
    var save := _try_get_singleton("SaveManager")
    if save == null:
        return
    var cats: Array = save.data.get("cats", [])
    for c in cats:
        if c is Dictionary and float(c.get("happiness", 100.0)) < 40.0:
            var cur := float(c.happiness)
            c.happiness = clamp(cur + 100.0 * boost_pct, 0.0, 100.0)

func _boost_all_cats(boost_pct: float) -> void:
    var save := _try_get_singleton("SaveManager")
    if save == null:
        return
    var cats: Array = save.data.get("cats", [])
    for c in cats:
        if c is Dictionary:
            var cur := float(c.get("happiness", 100.0))
            c.happiness = clamp(cur + 100.0 * boost_pct, 0.0, 100.0)

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
