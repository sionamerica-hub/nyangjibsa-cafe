# 🐾 냥집사 Cafe (Nyangjibsa Cafe)

모바일 캣 카페 방치형 타이쿤. 2026-11-29 Play Store 출시 목표.

## Stack
- Godot 4.7
- MIT 베이스: [drone-tycoon-idle](https://github.com/LuisPCFialho/drone-tycoon-idle) + [tycoon-template](https://github.com/naddicott-dtech/tycoon-template)
- MIT 플러그인: [godot-admob-plugin](https://github.com/poingstudios/godot-admob-plugin)

## Setup
```bash
godot --path . --import
godot --path . --export-debug "Android" build/nyangjibsa-debug.apk
```

## Status
- W1 (2026-07-05): Godot 4.7 + JDK 17 + Android SDK/NDK 셋업 완료 ✅
- W2 (2026-07-06): 코어 메커니즘 3종 + 캣 30종 시트 완료 ✅
  - `scripts/CatData.gd` Resource 클래스 + `data/cats/*.tres` 30종 (코리안숏헤어 12 + 외래 18)
  - `autoload/BalanceMeter.gd` — 5초 주기 (min/max)×100 점수, 5구간 라벨, 😾반란 시 -300코인 페널티
  - `autoload/TimePeriodManager.gd` — 60초 주기 KST 7구간 (새벽/아침/오전/점심피크/오후/저녁피크/심야), 피크 30분 전 경고
  - `autoload/OfflineReward.gd` — 오프라인 복귀 3지 선택 (instant/slow/none), 새벽 보너스 +30%
  - `scripts/Main.gd` — 부팅 시 캣 30종 로드 + 균형점수/시간대 표시
- W3 (예정): 캣 시스템 확장 또는 게임성 통합
