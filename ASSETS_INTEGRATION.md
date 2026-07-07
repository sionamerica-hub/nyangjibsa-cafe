## 냥집사 카페 — 에셋 통합 보고서 (W4 designer 마무리)
### 작업 디렉토리: /opt/data/work/nyangjibsa-cafe/assets/

## 출처 (전부 Kenney.nl — CC0, 상업 사용 무료)
| Pack | URL | 라이선스 | 파일 수 | 크기 |
|---|---|---|---|---|
| UI Pack (2.0) | https://kenney.nl/assets/ui-pack | CC0 | 870 PNG + 6 OGG + 434 SVG | 2.5MB |
| UI SFX Set | https://kenney.nl/assets/ui-audio | CC0 | 52 OGG | 472KB |
| Game Icons | https://kenney.nl/assets/game-icons | CC0 | 425 PNG (Black/White) | 420KB |
| Pixel Platformer | https://kenney.nl/assets/pixel-platformer | CC0 | 240 PNG | 112KB |
| Platformer Characters 1 | https://kenney.nl/assets/platformer-characters | CC0 | 172 PNG | 472KB |
| Tiny Town | https://kenney.nl/assets/tiny-town | CC0 | 136 PNG | 미사용 |
| RPG Base | https://kenney.nl/assets/rpg-base | CC0 | 233 PNG | 미사용 |

## 선정 (우리 톤 매칭)
- **ui/**: UI Pack Green/Yellow/Blue 86 PNG (파스텔 버튼, 패널, 슬라이더)
- **sfx/**: UI Pack 6 OGG + UI SFX Set 51 OGG = 57 OGG (캣 카페 분위기 효과음)
- **bg/**: Pixel Platformer Backgrounds + Tiny Town Tilemap 26 PNG (배경)
- **cats/**: Platformer Characters Player/Adventurer/Female 27 PNG (캐릭터 sprite)
- **items/**: Game Icons Black/1x 105 PNG (UI 아이콘)

## 톤 평가 (vision_analyze 기준)
- **cats/player_action1.png**: 모험가 캐릭터, cute + 파스텔 그린/블루 컬러 → 귀여운 편이지만 고양이는 아님
- **cats/female_tilesheet.png**: 여성 모험가, 파스텔 보라/분홍 → 캐릭터 다양성 좋음
- **ui/**: 파스텔 그린/옐로우 위주 → 우리 톤 매칭 우수
- **bg/**: 미니멀 픽셀 배경, 톤은 차분 → 캣 카페 인테리어로 활용

## 한계 & 다음 액션
- **cats/ 폴더에는 사람 캐릭터만 있음**: 진짜 고양이 sprite는 다음 단계에서 외주 or ComfyUI로 자체 제작
- **현재 placeholder 🐱 emoji 유지**: 비주얼은 동일하지만 추후 sprite 교체 가능
- **items/**: 음식 아이콘은 별도 작업 필요 (OpenGameArt 식음료 pack)
- **bg/**: 26장 중 4~5장만 사용, 나머지는 백업

## Godot 통합 방법
- Godot 4.7이 PNG/OGG 드롭 시 `.import` 자동 생성
- 헤드리스 컨테이너에선 `--editor --quit` 1회 실행 시 자동 (이미 1회 실행됨)
- 클론 시 자동 임포트됨