extends Node
## 세이브 매니저 — JSON 저장 (8시간 오프라인 보너스)
const SAVE_PATH = "user://save.json"
var data := {"coin": 0, "jelly": 0, "last_play": 0, "cats": []}

func _ready() -> void:
    load_data()

func save_data() -> void:
    data["last_play"] = int(Time.get_unix_time_from_system())
    var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data))
        f.close()

func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f:
        var text = f.get_as_text()
        f.close()
    var parsed = JSON.parse_string(text)
    if parsed is Dictionary:
        data = parsed

func offline_bonus() -> int:
    ## 8시간 오프라인 보너스 계산
    var now = int(Time.get_unix_time_from_system())
    var elapsed = now - int(data.get("last_play", now))
    var hours = min(elapsed / 3600, 8)
    return int(hours * 200)  # 시간당 200코인