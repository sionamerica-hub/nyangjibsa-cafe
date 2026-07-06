extends Node
## 오디오 매니저 — BGM/효과음
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

func _ready() -> void:
    bgm_player = AudioStreamPlayer.new()
    sfx_player = AudioStreamPlayer.new()
    add_child(bgm_player)
    add_child(sfx_player)