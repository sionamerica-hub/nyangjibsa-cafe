extends Node2D

func _ready() -> void:
    print("🐾 Nyangjibsa Cafe 부팅 완료")
    print("베이스: drone-tycoon-idle (MIT) + tycoon-template (MIT)")
    print("Godot 버전: ", Engine.get_version_info())
    print("오프라인 보너스 예상: ", SaveManager.offline_bonus(), " 코인")