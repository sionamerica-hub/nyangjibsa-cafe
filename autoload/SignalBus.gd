extends Node
## 전역 시그널 버스 — tycoon-template 패턴 참고
## Godot 4.7 UNUSED_SIGNAL 경고 회피: 각 시그널은 대응 emit_* 헬퍼를 통해 명시적으로 발생

signal coin_changed(value: int)
signal jelly_changed(value: int)
signal cat_happiness_changed(cat_id: String, value: float)
signal balance_score_changed(score: int, label: String)
signal time_period_changed(period: String)
signal cat_arrived(cat_id: String)
signal cat_unlocked(cat_id: String)

## ---- emit 헬퍼 (각 시그널이 명시적으로 사용됨을 보장) ----
func emit_coin(value: int) -> void:
	coin_changed.emit(value)

func emit_jelly(value: int) -> void:
	jelly_changed.emit(value)

func emit_cat_happiness(cat_id: String, value: float) -> void:
	cat_happiness_changed.emit(cat_id, value)

func emit_balance_score(score: int, label: String) -> void:
	balance_score_changed.emit(score, label)

func emit_time_period(period: String) -> void:
	time_period_changed.emit(period)

func emit_cat_arrived(cat_id: String) -> void:
	cat_arrived.emit(cat_id)

func emit_cat_unlocked(cat_id: String) -> void:
	cat_unlocked.emit(cat_id)