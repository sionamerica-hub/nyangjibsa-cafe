# 🐾 냥집사 Cafe (Nyangjibsa Cafe)

모바일 캣 카페 방치형 타이쿤. 2026-11-29 Play Store 출시 목표.

## Stack
- Godot 4.7
- MIT 베이스: [drone-tycoon-idle](https://github.com/LuisPCFialho/drone-tycoon-idle) + [tycoon-template](https://github.com/naddicott-dtech/tycoon-template)
- MIT 플러그인: [godot-admob-plugin](https://github.com/poingstudios/godot-admob-plugin)
- 무료 에셋: [Kenney.nl](https://kenney.nl/) CC0 (UI/사운드/아이콘/배경)

## Setup
```bash
godot --path . --import
godot --path . --export-debug "Android" build/nyangjibsa-debug.apk
```

## Status

### ✅ W1 (2026-07-05) — 인프라 셋업
- Godot 4.7 + JDK 17 + Android SDK + NDK r28b + GitHub Actions CI

### ✅ W2 (2026-07-06) — 코어 메커니즘 3종
- BalanceMeter (균형 점수 — min/max 공식, 5구간 라벨)
- TimePeriodManager (시간대 7구간 — KST)
- OfflineReward (오프라인 복귀 3지 선택, 모두 케어)
- CatData Resource + 캣 30종 .tres (코리안숏헤어 12 + 외래 18)

### ✅ W3 (2026-07-06) — UI + 시설 Lv 1~4
- GodHub Actions CI (`godot-build.yml`)
- 캣 도감 UI (GridContainer 30종, 등급 색상)
- 신(god) 뷰 메인 화면 (HUD/슬롯 3개/캣 살랑살랑/탭바 5개/도감 모달)
- FacilityManager (Autoload, 시설 Lv 1~4 .tres 4개)
- FacilityManager 통합: get_total_coin_per_min() = Facility × BalanceMeter × TimePeriodManager

### ✅ W4 (2026-07-06) — 경제 시스템 + 자산 통합
- CustomerManager (Autoload, 손님 6명 풀 + 인내심 + 만족도)
- CatStateMachine (Autoload, hunger/activity/rest 1초 틱 변동)
- ShopManager 젤리 팩 6단계 (100/550/1200/3000/8500/22000)
- FacilityManager 업그레이드 실제 코인 차감 + 영속화
- SaveManager add_coin/spend_coin/add_jelly/spend_jelly API 확장
- MainScene에 캣 액션 3버튼 (먹이기/놀아주기/재우기) + 시설 업그레이드 버튼 + 손님 메뉴 6버튼 패널
- 자산 통합: Kenney CC0 7 pack (UI 86 PNG, SFX 57 OGG, BG 26 PNG, Cats 27 PNG, Items 105 PNG)
- 부팅 검증 0 SCRIPT ERROR

### W5 (예정)
- 진짜 고양이 sprite (외주 or ComfyUI)
- 손님 풀 확장 (다양 페르소나)
- 음식/캣 카페 소품 sprite (OpenGameArt 식음료)
- 도감 → 캣 상세 화면
- UI 인터랙션 (버튼 hover 효과)