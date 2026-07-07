extends Node2D
## 냥집사 카페 — 신(god) 뷰 메인 화면
## 5개 슬롯(원형 배치) + HUD + 캣 1마리 + 손님 알림 + 하단 탭바

const SLOT_COUNT_MAX: int = 5  ## 최대 슬롯 (Lv 4 시설은 6이지만 UI는 5 슬롯 표시)
const SLOTS_CIRCLE_RADIUS: float = 280.0
const SLOT_SIZE: Vector2 = Vector2(180.0, 180.0)

@onready var hud: CanvasLayer = $HUD
@onready var facility_label: Label = $HUD/TopBar/FacilityLabel
@onready var coin_label: Label = $HUD/TopBar/CoinLabel
@onready var jelly_label: Label = $HUD/TopBar/JellyLabel
@onready var period_label: Label = $HUD/TopBar/PeriodLabel
@onready var slot_container: Node2D = $Slots
@onready var cat_sprite: Label = $CatSprite
@onready var customer_alert: Label = $HUD/CustomerAlert
@onready var tab_album: Button = $HUD/TabBar/AlbumBtn
@onready var tab_cafe: Button = $HUD/TabBar/CafeBtn
@onready var tab_cats: Button = $HUD/TabBar/CatsBtn
@onready var tab_shop: Button = $HUD/TabBar/ShopBtn
@onready var tab_settings: Button = $HUD/TabBar/SettingsBtn

var slot_nodes: Array = []  ## 슬롯 Control 노드들
var placed_cats: Dictionary = {}  ## slot_idx → cat_id
var facility_current: int = 1
var total_coin: int = 0
var total_jelly: int = 0
var balance_timer: Timer = null
var customer_timer: Timer = null
var cat_anim_time: float = 0.0
var album_instance: Control = null

func _ready() -> void:
	_setup_background()
	_build_slots()
	_setup_hud()
	_connect_signals()
	_setup_timers()
	_spawn_demo_cat()
	_show_intro()
	print("🏠 MainScene 신(god)뷰 진입 — 슬롯 %d / 시설 Lv %d" %
		[_active_slot_count(), facility_current])

## ----- 슬롯 시스템 -----
func _active_slot_count() -> int:
	# FacilityManager가 없을 때 폴백
	if Engine.has_singleton("FacilityManager"):
		var fm = Engine.get_singleton("FacilityManager")
		if fm and fm.has_method("get_current"):
			return fm.get_current().slot_count
	# 폴백: Lv 1 = 3 슬롯
	var lvl := facility_current
	match lvl:
		1: return 3
		2: return 4
		3: return 5
		4: return 6
		_: return 3

func _build_slots() -> void:
	if slot_container == null:
		return
	for child in slot_container.get_children():
		child.queue_free()
	slot_nodes.clear()
	var n := _active_slot_count()
	var center := Vector2(540, 900)  # 화면 중앙 (1080/2, 1920/2 약간 아래)
	if n == 1:
		_make_slot(0, center)
	elif n == 2:
		_make_slot(0, center + Vector2(-120, 0))
		_make_slot(1, center + Vector2(120, 0))
	elif n == 3:
		# 삼각 배치
		_make_slot(0, center + Vector2(0, -140))
		_make_slot(1, center + Vector2(-140, 80))
		_make_slot(2, center + Vector2(140, 80))
	elif n == 4:
		# 다이아몬드 배치
		_make_slot(0, center + Vector2(0, -160))
		_make_slot(1, center + Vector2(-160, 0))
		_make_slot(2, center + Vector2(160, 0))
		_make_slot(3, center + Vector2(0, 160))
	elif n >= 5:
		# 5각형 배치 (Lv 3) — 5 또는 6 슬롯 모두 5각+1 중심
		for i in range(5):
			var angle := -PI/2 + i * (TAU/5)
			var pos := center + Vector2(cos(angle), sin(angle)) * SLOTS_CIRCLE_RADIUS
			_make_slot(i, pos)
		if n >= 6:
			_make_slot(5, center)  # 중앙 추가 (Lv 4)
	print("🎰 슬롯 %d개 배치 완료" % slot_nodes.size())

func _make_slot(idx: int, pos: Vector2) -> void:
	var panel := Panel.new()
	panel.position = pos - SLOT_SIZE * 0.5
	panel.size = SLOT_SIZE
	# 색상 (placeholder)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.9, 0.85, 0.9)
	sb.border_color = Color(0.85, 0.7, 0.6, 1.0)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", sb)
	slot_container.add_child(panel)

	var label := Label.new()
	label.text = "슬롯 %d" % (idx + 1)
	label.position = Vector2(0, SLOT_SIZE.y * 0.5 + 8)
	label.size = Vector2(SLOT_SIZE.x, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	panel.add_child(label)
	slot_nodes.append(panel)

## ----- HUD -----
func _setup_hud() -> void:
	if facility_label != null:
		facility_label.text = "🏠 Lv %d 골목 캣 카페" % facility_current
	if coin_label != null:
		coin_label.text = "💰 코인: %d" % total_coin
	if jelly_label != null:
		jelly_label.text = "💎 젤리: %d" % total_jelly
	if period_label != null and TimePeriodManager != null:
		var info := TimePeriodManager.get_period_info()
		period_label.text = "⏰ %s (%02d:%02d)" % [info.period, info.kst_hour, info.kst_minute]

## ----- 시그널 연결 -----
func _connect_signals() -> void:
	if tab_album != null and not tab_album.pressed.is_connected(_on_album_pressed):
		tab_album.pressed.connect(_on_album_pressed)
	if tab_cafe != null and not tab_cafe.pressed.is_connected(_on_cafe_pressed):
		tab_cafe.pressed.connect(_on_cafe_pressed)
	if tab_cats != null and not tab_cats.pressed.is_connected(_on_cats_pressed):
		tab_cats.pressed.connect(_on_cats_pressed)
	if tab_shop != null and not tab_shop.pressed.is_connected(_on_shop_pressed):
		tab_shop.pressed.connect(_on_shop_pressed)
	if tab_settings != null and not tab_settings.pressed.is_connected(_on_settings_pressed):
		tab_settings.pressed.connect(_on_settings_pressed)

## ----- 타이머 -----
func _setup_timers() -> void:
	balance_timer = Timer.new()
	balance_timer.wait_time = 5.0
	balance_timer.autostart = true
	balance_timer.timeout.connect(_on_balance_tick)
	add_child(balance_timer)

	customer_timer = Timer.new()
	customer_timer.wait_time = 12.0
	customer_timer.autostart = true
	customer_timer.timeout.connect(_on_customer_arrived)
	add_child(customer_timer)

## ----- 캣 배치 -----
func _spawn_demo_cat() -> void:
	if cat_sprite == null:
		return
	cat_sprite.text = "🐱"
	cat_sprite.add_theme_font_size_override("font_size", 120)
	cat_sprite.position = Vector2(540, 900)
	cat_sprite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placed_cats[0] = "demo_cat"  # 가상 캣 1마리 슬롯0에 배치
	print("🐱 데모 캣 슬롯 0에 배치")

## ----- 메인 루프 -----
func _process(delta: float) -> void:
	# 캣 스프라이트 살랑살랑 애니메이션
	if cat_sprite != null:
		cat_anim_time += delta
		var offset_y := sin(cat_anim_time * 2.5) * 12.0
		cat_sprite.position.y = 900.0 + offset_y

## ----- 5초 균형 틱 -----
func _on_balance_tick() -> void:
	# 균형 점수 → 코인 획득 (분당 환산)
	var per_min: int = 100
	if Engine.has_singleton("FacilityManager"):
		var fm = Engine.get_singleton("FacilityManager")
		if fm and fm.has_method("get_current"):
			per_min = fm.get_current().coin_per_min
	var balance_mult := 1.0
	if BalanceMeter != null and BalanceMeter.has_method("get_score_breakdown"):
		var info := BalanceMeter.get_score_breakdown()
		balance_mult = info.coin_mult
	var period_mult := 1.0
	if TimePeriodManager != null and TimePeriodManager.has_method("get_period_info"):
		var info := TimePeriodManager.get_period_info()
		period_mult = info.coin_mult
	# 5초마다: per_min / 12 × multiplier
	var earned := int(per_min / 12.0 * balance_mult * period_mult)
	total_coin += earned
	if coin_label != null:
		coin_label.text = "💰 코인: %d" % total_coin
	# jelly는 period의 보너스 적용
	if TimePeriodManager != null and TimePeriodManager.has_method("get_period_info"):
		var info := TimePeriodManager.get_period_info()
		if info.jelly_bonus > 0 and randf() < 0.3:
			total_jelly += info.jelly_bonus
			if jelly_label != null:
				jelly_label.text = "💎 젤리: %d" % total_jelly

## ----- 손님 도착 -----
func _on_customer_arrived() -> void:
	if customer_alert == null:
		return
	var cat_names: Array[String] = ["나비", "치즈", "흰둥이", "까망이", "고등어", "호두", "콩이", "보리", "미오", "루나"]
	var pick: String = cat_names[randi() % cat_names.size()]
	customer_alert.text = "🐱 %s 손님 도착!" % pick
	customer_alert.visible = true
	customer_alert.modulate.a = 1.0
	# 3초 후 페이드아웃
	var t := create_tween()
	t.tween_property(customer_alert, "modulate:a", 0.0, 1.5).set_delay(1.5)
	t.tween_callback(func(): customer_alert.visible = false)

## ----- 탭바 핸들러 -----
func _on_album_pressed() -> void:
	print("📖 [도감] 탭 클릭")
	if album_instance == null:
		var AlbumScript := load("res://scripts/CatAlbum.gd")
		if AlbumScript == null:
			push_warning("CatAlbum 스크립트 로드 실패")
			return
		album_instance = Control.new()
		album_instance.set_script(AlbumScript)
		# CatAlbum의 UI를 동적 구성 (간이)
		_album_build_inline(album_instance)
		add_child(album_instance)
	# 화면 토글
	album_instance.visible = not album_instance.visible
	if album_instance.visible:
		# 열릴 때 그리드 다시 그리기
		if album_instance.has_method("_load_all_cats"):
			album_instance._load_all_cats()
		if album_instance.has_method("_init_unlock_state"):
			album_instance._init_unlock_state()
		if album_instance.has_method("_build_grid"):
			album_instance._build_grid()
		if album_instance.has_method("_update_title"):
			album_instance._update_title()

## 도감을 인라인으로 구성 (CatAlbum.tscn 의존성 회피)
func _album_build_inline(root: Control) -> void:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size = Vector2(1080, 1920)
	root.z_index = 100
	var bg := ColorRect.new()
	bg.color = Color(0.97, 0.94, 0.88, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(40, 40)
	vbox.size = Vector2(1000, 1840)
	root.add_child(vbox)
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "📖 캣 도감"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(1000, 80)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(1000, 1620)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "GridContainer"
	grid.columns = 6
	grid.custom_minimum_size = Vector2(1000, 1600)
	scroll.add_child(grid)
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(1000, 100)
	vbox.add_child(close_btn)
	close_btn.pressed.connect(func(): root.visible = false)
	# 스크립트의 @onready가 다시 평가되도록 tree_entered 시그널 후처리
	root.set_meta("built", true)

func _on_cafe_pressed() -> void:
	print("🏠 [카페] 탭 클릭 — 신(god)뷰 새로고침")
	_build_slots()

func _on_cats_pressed() -> void:
	print("🐱 [캣] 탭 클릭 — 캣 목록 (W4 예정)")

func _on_shop_pressed() -> void:
	print("🛒 [상점] 탭 클릭 — ShopManager 호출 (W4 예정)")

func _on_settings_pressed() -> void:
	print("⚙️ [설정] 탭 클릭 — 설정 다이얼로그 (W4 예정)")

## ----- 배경 -----
func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.93, 0.88, 0.82, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1080, 1920)
	add_child(bg)
	bg.owner = self

func _show_intro() -> void:
	# 인트로 알림 (1회성)
	customer_alert.text = "🐾 냥집사 카페에 오신 걸 환영합니다!"
	customer_alert.visible = true
	customer_alert.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(customer_alert, "modulate:a", 0.0, 1.5).set_delay(2.0)
	t.tween_callback(func(): customer_alert.visible = false)

## ----- 슬롯 배치 의사결정 API -----
## option: "auto" | "manual" | "skip"
func place_cat_in_slot(slot_idx: int, cat_id: String) -> void:
	if slot_idx < 0 or slot_idx >= slot_nodes.size():
		push_warning("슬롯 인덱스 범위 초과: %d" % slot_idx)
		return
	placed_cats[slot_idx] = cat_id
	# 슬롯 위에 캣 표시 (간이 — 라벨 이모지)
	var slot: Panel = slot_nodes[slot_idx]
	var existing: Node = slot.get_node_or_null("PlacedCat")
	if existing != null:
		existing.queue_free()
	var lbl := Label.new()
	lbl.name = "PlacedCat"
	lbl.text = "🐱"
	lbl.add_theme_font_size_override("font_size", 80)
	lbl.position = Vector2(40, 20)
	lbl.size = Vector2(100, 120)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(lbl)
	print("🎯 슬롯 %d ← 캣 %s 배치" % [slot_idx, cat_id])

func _on_slot_decision(option: String) -> void:
	# 자동 추천: 가장 비어있는 슬롯에 데모 캣 배치
	match option:
		"auto":
			for i in range(slot_nodes.size()):
				if not placed_cats.has(i):
					place_cat_in_slot(i, "auto_cat_%d" % i)
					break
		"manual":
			print("✋ 수동 배치 — 캣 선택 UI (W4 예정)")
		"skip":
			print("⏭ 패스 — 다음 손님 대기")
		_:
			push_warning("알 수 없는 슬롯 옵션: %s" % option)