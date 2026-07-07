class_name FacilityData extends Resource
## 냥집사 카페 — 시설 데이터 Resource 클래스
## 시설 Lv 1~4의 데이터를 Godot Resource로 표현 (Inspector 편집 가능)

## ===== 식별 =====
@export var id: String = ""             ## "facility_lv1" 등
@export var display_name: String = ""   ## "골목 캣 카페"
@export var level: int = 1              ## 1~4

## ===== 설명 =====
@export var description: String = ""    ## "작지만 따뜻한 골목의 캣 카페"

## ===== 게임 경제 =====
@export var required_coin: int = 0      ## 해금에 필요한 코인
@export var coin_per_min: int = 100     ## 기본 분당 수익 (BalanceMeter/TimePeriodManager 곱 전)
@export var slot_count: int = 3         ## 슬롯 수
@export var max_cats: int = 3           ## 최대 수용 캣 수

## ===== 비주얼 =====
@export var theme_color: String = "#FFB5C8"  ## hex 색상 (테마)
@export_multiline var upgrade_hours_note: String = ""  ## 업그레이드 시간(설명)

## ===== 업그레이드 메타 =====
@export var upgrade_hours: int = 0      ## 업그레이드에 걸리는 시간(시간, 0=즉시)

func _init(p_id: String = "", p_name: String = "", p_level: int = 1,
		p_required: int = 0, p_coin: int = 100, p_slots: int = 3,
		p_cats: int = 3, p_color: String = "#FFB5C8", p_desc: String = "",
		p_hours: int = 0) -> void:
	id = p_id
	display_name = p_name
	level = p_level
	required_coin = p_required
	coin_per_min = p_coin
	slot_count = p_slots
	max_cats = p_cats
	theme_color = p_color
	description = p_desc
	upgrade_hours = p_hours

func describe() -> String:
	return "[Lv%d %s] 코인 %d/분 · 슬롯 %d · 캣 %d · 해금 %d · %s" % [
		level, display_name, coin_per_min, slot_count, max_cats,
		required_coin, theme_color]

## 테마 hex → Color 변환 헬퍼
func get_theme_color() -> Color:
	var c := Color(1.0, 0.7, 0.8, 1.0)
	if theme_color.length() == 7 and theme_color[0] == "#":
		var r_str := theme_color.substr(1, 2)
		var g_str := theme_color.substr(3, 2)
		var b_str := theme_color.substr(5, 2)
		c.r = int("0x" + r_str) / 255.0
		c.g = int("0x" + g_str) / 255.0
		c.b = int("0x" + b_str) / 255.0
	return c