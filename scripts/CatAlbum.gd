extends Control
## 냥집사 카페 — 캣 도감 UI
## 30종 캣을 그리드(6열 × 5행)로 표시
## 각 캣 버튼 클릭 → 정보 팝업

const CATS_DIR := "res://data/cats/"
const CAT_SCRIPT := preload("res://scripts/CatData.gd")
const GRID_COLUMNS: int = 6
const CELL_SIZE: Vector2 = Vector2(150.0, 200.0)

var all_cats: Array = []      ## CatData Resource 배열 (display_name 정렬)
var unlocked_ids: Dictionary = {}  ## id → true (해금된 캣)
var info_popup: AcceptDialog = null  ## 현재 떠있는 정보 팝업

@onready var grid: GridContainer = $VBox/Scroll/GridContainer
@onready var title_label: Label = $VBox/TitleLabel
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	_load_all_cats()
	_init_unlock_state()
	if grid != null:
		_build_grid()
		_update_title()
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	print("📖 CatAlbum 도감 열림 — %d종 표시 (해금 %d종)" %
		[all_cats.size(), _count_unlocked()])

## 30종 캣 .tres 로드
func _load_all_cats() -> void:
	var dir := DirAccess.open(CATS_DIR)
	if dir == null:
		push_warning("캣 디렉토리 없음: %s" % CATS_DIR)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".tres"):
			var path := CATS_DIR + name
			var res: Resource = load(path)
			if res != null and res.get_script() == CAT_SCRIPT:
				all_cats.append(res)
		name = dir.get_next()
	dir.list_dir_end()
	all_cats.sort_custom(func(a, b):
		if a.rarity != b.rarity:
			# 등급별 정렬: N → R → SR → SSR
			return _rarity_order(a.rarity) < _rarity_order(b.rarity)
		return a.display_name < b.display_name)

func _rarity_order(r: String) -> int:
	match r:
		"N": return 0
		"R": return 1
		"SR": return 2
		"SSR": return 3
		_: return 99

## 초기 해금 상태 — 일단 첫 1마리 (나비) 해금, 나머지 잠금
func _init_unlock_state() -> void:
	unlocked_ids.clear()
	for i in range(all_cats.size()):
		var cat = all_cats[i]
		if i < 1:
			unlocked_ids[cat.id] = true
		else:
			unlocked_ids[cat.id] = false

## GridContainer에 30셀 구성
func _build_grid() -> void:
	if grid == null:
		return
	grid.columns = GRID_COLUMNS
	# 기존 자식 제거
	for child in grid.get_children():
		child.queue_free()
	# 30개 셀 생성
	for cat in all_cats:
		var cell := _make_cat_cell(cat)
		grid.add_child(cell)

## 캣 1마리 셀 — Button(이미지 영역) + Label(이름) + Label(등급)
func _make_cat_cell(cat) -> Control:
	var container := VBoxContainer.new()
	container.custom_minimum_size = CELL_SIZE
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 140)
	btn.text = _emoji_for_rarity(cat.rarity) + "\n" + cat.display_name[0]
	btn.disabled = not unlocked_ids.get(cat.id, false)
	if btn.disabled:
		btn.modulate = Color(0.4, 0.4, 0.4, 1.0)
	btn.pressed.connect(_on_cat_pressed.bind(cat))
	container.add_child(btn)

	var name_label := Label.new()
	name_label.text = cat.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	if not unlocked_ids.get(cat.id, false):
		name_label.text = "???"
		name_label.modulate = Color(0.6, 0.6, 0.6, 1.0)
	container.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = "[" + cat.rarity + "]"
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.modulate = _color_for_rarity(cat.rarity)
	container.add_child(rarity_label)

	return container

func _emoji_for_rarity(r: String) -> String:
	match r:
		"SSR": return "✨"
		"SR": return "🌟"
		"R": return "⭐"
		_: return "🐱"

func _color_for_rarity(r: String) -> Color:
	match r:
		"SSR": return Color(1.0, 0.6, 0.9, 1.0)  # 핑크
		"SR": return Color(0.9, 0.7, 1.0, 1.0)   # 보라
		"R": return Color(0.6, 0.85, 1.0, 1.0)   # 파랑
		_: return Color(0.7, 0.7, 0.7, 1.0)      # 회색

## 타이틀 라벨 (해금 수 표시)
func _update_title() -> void:
	if title_label == null:
		return
	var total := all_cats.size()
	var unlocked := _count_unlocked()
	title_label.text = "📖 캣 도감 (%d/%d)" % [unlocked, total]

func _count_unlocked() -> int:
	var n := 0
	for v in unlocked_ids.values():
		if v:
			n += 1
	return n

## 캣 버튼 클릭 핸들러
func _on_cat_pressed(cat) -> void:
	if not unlocked_ids.get(cat.id, false):
		_show_locked_popup(cat)
		return
	_show_cat_popup(cat)
	# 시그널 발사 — 다른 시스템이 구독 가능
	SignalBus.cat_unlocked.emit(cat.id)

func _show_cat_popup(cat) -> void:
	if info_popup != null:
		info_popup.queue_free()
	info_popup = AcceptDialog.new()
	info_popup.title = "%s %s [%s]" % [_emoji_for_rarity(cat.rarity), cat.display_name, cat.rarity]
	info_popup.dialog_text = """이름: %s
품종: %s
성격: %s
등급: %s
해금 코인: %d
포만감: %.0f / 활동: %.0f / 휴식: %.0f

"%s"

— 클립하여 닫으세요 —""" % [
		cat.display_name, cat.breed, cat.personality, cat.rarity,
		cat.unlock_coin, cat.base_hunger, cat.base_activity, cat.base_rest,
		cat.flavor_text]
	info_popup.confirmed.connect(func(): info_popup.queue_free(); info_popup = null)
	info_popup.canceled.connect(func(): info_popup.queue_free(); info_popup = null)
	add_child(info_popup)
	info_popup.popup_centered()

func _show_locked_popup(cat) -> void:
	if info_popup != null:
		info_popup.queue_free()
	info_popup = AcceptDialog.new()
	info_popup.title = "🔒 잠김"
	info_popup.dialog_text = """아직 해금하지 않은 캣입니다.

[%s] %s
필요 코인: %d

해금 조건:
- 코인 %d개로 상점에서 해제 가능
- 특정 손님 이벤트 클리어 시 무료 해제""" % [
		cat.rarity, cat.display_name, cat.unlock_coin, cat.unlock_coin]
	info_popup.confirmed.connect(func(): info_popup.queue_free(); info_popup = null)
	info_popup.canceled.connect(func(): info_popup.queue_free(); info_popup = null)
	add_child(info_popup)
	info_popup.popup_centered()

func _on_close_pressed() -> void:
	# 도감 닫기 — 부모에서 처리
	visible = false
	print("📖 CatAlbum 도감 닫힘")

## 외부 API — 캣 해금 처리 (ShopManager 등에서 호출)
func unlock_cat(cat_id: String) -> void:
	unlocked_ids[cat_id] = true
	# 그리드 다시 그리기
	if grid != null:
		_build_grid()
	_update_title()
	print("🔓 캣 해금: %s" % cat_id)