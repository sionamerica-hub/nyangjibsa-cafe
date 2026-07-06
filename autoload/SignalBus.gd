extends Node
## 전역 시그널 버스 — tycoon-template 패턴 참고
signal coin_changed(value: int)
signal jelly_changed(value: int)
signal cat_happiness_changed(cat_id: String, value: float)
signal balance_score_changed(score: int, label: String)
signal time_period_changed(period: String)
signal cat_arrived(cat_id: String)