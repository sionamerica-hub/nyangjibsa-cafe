class_name CatData extends Resource
## 냥집사 카페 — 캣 데이터 Resource 클래스
## 30종 캣의 시트 데이터를 Godot Resource로 표현 (Inspector 편집 가능)

## ===== 식별 =====
@export var id: String = ""
@export var display_name: String = ""

## 외형 (향후 스프라이트 채움)
@export var breed: String = ""           # 예: "코리안숏헤어", "샴"
@export var personality: String = ""     # 게으름이 / 폭식가 / 호기심이 / 수줍음이
@export var sprite_path: String = ""     # res://sprites/cats/xxx.png

## ===== 성향 수치 (0~100) =====
## 페르소나별로 다른 시작값을 가지며, 게임 중 변동
@export_range(0.0, 100.0) var base_hunger: float = 50.0   ## 포만감 (배고픔의 역수)
@export_range(0.0, 100.0) var base_activity: float = 50.0 ## 활동 욕구
@export_range(0.0, 100.0) var base_rest: float = 50.0     ## 휴식 욕구

## ===== 게임 경제 =====
@export var rarity: String = "N"         ## N / R / SR / SSR
@export var unlock_coin: int = 100

## ===== 텍스트 =====
@export var flavor_text: String = ""     ## 한글 한 줄 소개

## --------------------------------------------------
## 유틸 — 페르소나 시작 수치 일괄 적용 (런타임 헬퍼)
## --------------------------------------------------
static func apply_personality_defaults(personality: String) -> Dictionary:
    ## 기획서 §13 — 4종 페르소나 시작 수치
    match personality:
        "게으름이":
            return {"hunger": 60.0, "activity": 30.0, "rest": 80.0}
        "폭식가":
            return {"hunger": 80.0, "activity": 70.0, "rest": 30.0}
        "호기심이":
            return {"hunger": 40.0, "activity": 80.0, "rest": 30.0}
        "수줍음이":
            return {"hunger": 30.0, "activity": 20.0, "rest": 80.0}
        _:
            return {"hunger": 50.0, "activity": 50.0, "rest": 50.0}

## --------------------------------------------------
## 유틸 — 등급별 해금 코인
## --------------------------------------------------
static func get_rarity_unlock_coin(rarity: String) -> int:
    match rarity:
        "N": return 100
        "R": return 500
        "SR": return 2000
        "SSR": return 10000
        _: return 100

## --------------------------------------------------
## 동기화 — export 값이 비어있어도 항상 안전한 기본값을 보장
## --------------------------------------------------
func _init(p_id: String = "", p_name: String = "", p_breed: String = "",
           p_personality: String = "게으름이", p_rarity: String = "N",
           p_unlock: int = 100, p_flavor: String = "") -> void:
    id = p_id
    display_name = p_name
    breed = p_breed
    personality = p_personality
    rarity = p_rarity
    unlock_coin = p_unlock
    flavor_text = p_flavor
    var d := apply_personality_defaults(p_personality)
    base_hunger = d.hunger
    base_activity = d.activity
    base_rest = d.rest

## --------------------------------------------------
## 디버그 출력
## --------------------------------------------------
func describe() -> String:
    return "[%s] %s (%s, %s) hunger=%.0f activity=%.0f rest=%.0f unlock=%d" % \
        [rarity, display_name, breed, personality,
         base_hunger, base_activity, base_rest, unlock_coin]