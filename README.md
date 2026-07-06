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
- W2: 빈 프로젝트 + autoload 5종 통합 (진행 중)