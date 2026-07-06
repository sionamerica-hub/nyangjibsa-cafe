extends Node
## 광고 매니저 — AdMob stub (poingstudios/godot-admob-plugin 사용 예정)
signal reward_ad_completed(reward: String)

func show_reward_ad(reward: String = "upgrade_speedup") -> void:
    # TODO: AdMob 플러그인 통합 (W3)
    reward_ad_completed.emit(reward)