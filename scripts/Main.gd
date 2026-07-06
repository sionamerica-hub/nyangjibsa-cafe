extends Node2D

## 부팅 시 캣 30종 로드, 균형 점수 초기화, 시간대 표시
const CATS_DIR := "res://data/cats/"
const CAT_SCRIPT := preload("res://scripts/CatData.gd")

var all_cats: Array = []  ## Resource[] — .tres에서 로드. 구체 타입은 CatData.

func _ready() -> void:
    print("🐾 Nyangjibsa Cafe 부팅 완료 (W2)")
    print("베이스: drone-tycoon-idle (MIT) + tycoon-template (MIT)")
    print("Godot 버전: ", Engine.get_version_info())
    print("오프라인 보너스 예상: ", SaveManager.offline_bonus(), " 코인")

    _load_all_cats()
    _init_balance_score()
    _report_time_period()

    if all_cats.size() > 0:
        print("🐱 캣 로드 완료 — %d종 (코리안숏헤어 %d + 외래 %d)" %
              [all_cats.size(),
               _count_by_breed("코리안숏헤어"),
               _count_non_korean_short_hair()])

func _load_all_cats() -> void:
    var dir := DirAccess.open(CATS_DIR)
    if dir == null:
        push_warning("캣 디렉토리 없음: %s" % CATS_DIR)
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.ends_with(".tres"):
            var path := CATS_DIR + name
            var res: Resource = load(path)
            if res != null and res.get_script() == CAT_SCRIPT:
                all_cats.append(res)
        name = dir.get_next()
    dir.list_dir_end()
    all_cats.sort_custom(func(a, b):
        return a.display_name < b.display_name)

func _init_balance_score() -> void:
    if BalanceMeter == null:
        return
    BalanceMeter.set_stats(60.0, 55.0, 70.0)
    var info := BalanceMeter.get_score_breakdown()
    print("⚖ 균형 점수 초기 — score=%d (%s) 행복지수=%.2f 코인×%.1f" %
          [info.score, info.label, info.happiness_mod, info.coin_mult])

func _report_time_period() -> void:
    if TimePeriodManager == null:
        return
    var info := TimePeriodManager.get_period_info()
    print("⏰ 현재 시간대: %s (KST %02d:%02d) 손님×%.1f 코인×%.1f jelly+%d" %
          [info.period, info.kst_hour, info.kst_minute,
           info.customer_mult, info.coin_mult, info.jelly_bonus])

func _count_by_breed(breed: String) -> int:
    var n := 0
    for c in all_cats:
        if c.breed == breed:
            n += 1
    return n

func _count_non_korean_short_hair() -> int:
    var n := 0
    for c in all_cats:
        if c.breed != "코리안숏헤어":
            n += 1
    return n