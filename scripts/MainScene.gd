extends Node2D

## 냥집사 카페 — 신(god) 뷰 메인 화면
## 캣 카페 전체를 내려다보는 시점 (방치형 타이쿤 표준)
## 슬롯 배치 / 손님 도착 알림 / HUD / 도감 모달 통합

const SLOT_POSITIONS := [
	Vector2(540, 760),   # 슬롯 0 (중앙 상단)
	Vector2(360, 950),   # 슬롯 1 (좌)
	Vector2(720, 950),   # 슬롯 2 (우)
]
const SLOT_RADIUS := 90

var balance_info: Dictionary = {}
var period_info: Dictionary = {}
var placed_cat: CatData = null
var placed_cat_slot: int = 0
var sine_t: float = 0.0

@onready var hud_level: Label = $HUD/Level
@onready var hud_coin: Label = $HUD/Coin
@onready var hud_jelly: Label = $HUD/Jelly
@onready var hud_period: Label = $HUD/Period
@onready var hud_balance: Label = $HUD/Balance
@onready var slots_root: Node2D = $Slots
@onready var cat_sprite: Label = $CatSprite
@onready var alert: Label = $Alert
@onready var tabbar: Node = $Tabbar
@onready var album_modal: ColorRect = $AlbumModal
@onready var album_grid: GridContainer = $AlbumModal/Panel/VBox/Grid
@onready var album_title: Label = $AlbumModal/Panel/VBox/Title
@onready var album_close_btn: Button = $AlbumModal/Panel/VBox/CloseBtn

func _ready() -> void:
	# W3-C: 5초 균형 타이머 시작
	var t := Timer.new()
	t.wait_time = 5.0
	t.autostart = true
	t.one_shot = false
	t.timeout.connect(_on_balance_timer)
	add_child(t)

	_album_modal.visible = false
	album_close_btn.pressed.connect(_close_album)
	_init_demo_cat()
	_refresh_hud()
	_alert.visible = false

	print("🏠 MainScene 신(god)뷰 진입 — 슬롯 %d / 시설 Lv %d" %
		[_get_active_slot_count(), FacilityManager.current_level])

func _process(delta: float) -> void:
	sine_t += delta
	if cat_sprite != null:
		cat_sprite.position.y = SLOT_POSITIONS[placed_cat_slot].y + sin(sine_t * 2.0) * 8.0

func _init_demo_cat() -> void:
	if not _has_cat_data():
		return
	var all: Array = Main.all_cats
	if all.is_empty():
		return
	placed_cat = all[0]
	place_cat_in_slot(0, placed_cat.id)

func _has_cat_data() -> bool:
	return Main != null and "all_cats" in Main and Main.all_cats != null

func place_cat_in_slot(slot_idx: int, cat_id: String) -> bool:
	if slot_idx < 0 or slot_idx >= _get_active_slot_count():
		push_warning("슬롯 범위 초과: %d" % slot_idx)
		return false
	if not _has_cat_data():
		return false
	for c in Main.all_cats:
		if c.id == cat_id:
			placed_cat = c
			placed_cat_slot = slot_idx
			cat_sprite.text = "🐱\n" + c.display_name
			cat_sprite.position = SLOT_POSITIONS[slot_idx]
			print("🐱 데모 캣 슬롯 %d에 배치: %s" % [slot_idx, c.display_name])
			_show_alert("🐱 %s 도착! 슬롯 %d에 배치" % [c.display_name, slot_idx])
			return true
	return false

func _get_active_slot_count() -> int:
	var fac: Resource = FacilityManager.get_current()
	if fac == null:
		return 3
	return int(fac.slot_count)

func _on_balance_timer() -> void:
	balance_info = BalanceMeter.get_score_breakdown()
	period_info = TimePeriodManager.get_period_info()
	_refresh_hud()

func _refresh_hud() -> void:
	var fac: Resource = FacilityManager.get_current()
	var level_txt := "Lv %d %s" % [FacilityManager.current_level,
		fac.display_name if fac != null else "?"]
	hud_level.text = level_txt
	hud_coin.text = "💰 %d 코인" % int(SaveManager.data.get("coin", 0))
	hud_jelly.text = "💎 %d 젤리" % int(SaveManager.data.get("jelly", 0))
	period_info = TimePeriodManager.get_period_info()
	hud_period.text = "⏰ %s (%02d:%02d) ×%.1f" % [
		period_info.period, period_info.kst_hour, period_info.kst_minute,
		period_info.coin_mult]
	if balance_info.is_empty():
		balance_info = BalanceMeter.get_score_breakdown()
	hud_balance.text = "⚖ %d (%s) ×%.1f" % [
		balance_info.score, balance_info.label, balance_info.coin_mult]

func _show_alert(msg: String) -> void:
	alert.text = msg
	alert.visible = true
	var t := get_tree().create_timer(2.5)
	t.timeout.connect(func(): if alert != null: alert.visible = false)

# ===== 슬롯 배치 의사결정 (3지: 자동추천 / 직접 / 패스) =====

func decide_slot_placement(slot_idx: int, option: String) -> Dictionary:
	match option:
		"auto":
			var cat_id: String = ""
			if placed_cat != null:
				cat_id = placed_cat.id
			if place_cat_in_slot(slot_idx, cat_id):
				return {"ok": true, "option": "auto", "balance_bonus": 5}
		"manual":
			return {"ok": true, "option": "manual",
					"hint": "캣 도감을 열어 직접 선택"}
		"pass":
			if not SaveManager.data.has("skip_count"):
				SaveManager.data["skip_count"] = 0
			SaveManager.data["skip_count"] += 1
			return {"ok": true, "option": "pass",
					"jelly_bonus": 3, "next_slot_in_sec": 30}
	return {"ok": false, "reason": "invalid_option"}

# ===== 도감 모달 =====

func open_album() -> void:
	if not _has_cat_data():
		push_warning("캣 데이터 없음")
		return
	_populate_album_grid()
	_album_modal.visible = true
	print("📖 CatAlbum 도감 열림 — %d종 표시" % Main.all_cats.size())

func _populate_album_grid() -> void:
	for child in album_grid.get_children():
		child.queue_free()
	if not _has_cat_data():
		return
	var cats: Array = Main.all_cats
	album_title.text = "📖 캣 콜렉트북 (%d/%d)" % [cats.size(), cats.size()]
	for c in cats:
		var cat: CatData = c
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(150, 160)
		var icon := Label.new()
		icon.text = "🐱"
		icon.add_theme_font_size_override("font_size", 64)
		icon.horizontal_alignment = 1
		var name_lbl := Label.new()
		name_lbl.text = cat.display_name
		name_lbl.horizontal_alignment = 1
		var rarity_lbl := Label.new()
		rarity_lbl.text = cat.rarity
		rarity_lbl.horizontal_alignment = 1
		match cat.rarity:
			"N": rarity_lbl.modulate = Color(0.6, 0.6, 0.6)
			"R": rarity_lbl.modulate = Color(0.3, 0.7, 0.3)
			"SR": rarity_lbl.modulate = Color(0.5, 0.3, 0.9)
			"SSR": rarity_lbl.modulate = Color(0.95, 0.7, 0.2)
		cell.add_child(icon)
		cell.add_child(name_lbl)
		cell.add_child(rarity_lbl)
		album_grid.add_child(cell)

func _close_album() -> void:
	_album_modal.visible = false

func _on_album_btn_pressed() -> void:
	open_album()

func _on_shop_btn_pressed() -> void:
	_show_alert("🛒 상점 (W4 예정)")

func _on_settings_btn_pressed() -> void:
	_show_alert("⚙️ 설정 (W4 예정)")

func _on_home_btn_pressed() -> void:
	_album_modal.visible = false
	_refresh_hud()