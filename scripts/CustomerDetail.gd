extends Control
## 냥집사 카페 — 손님 상세 화면
## 손님 클릭 시 호출되어 1명 상세 정보(이름/페르소나/주문/인내심/좋아캣) 표시
##
## 시그널:
##   close_requested() — 상세 화면 닫기 요청
##
## 사용:
##   var dlg = preload("res://scenes/CustomerDetail.tscn").instantiate()
##   dlg.show_customer(customer_data)
##   add_child(dlg)

signal close_requested()

var current_customer: Resource = null
var _close_button: Button = null
var _avatar_label: Label = null
var _name_label: Label = null
var _personality_label: Label = null
var _drink_label: Label = null
var _patience_label: Label = null
var _coin_label: Label = null
var _flavor_label: Label = null
var _acceptable_container: VBoxContainer = null
var _rejected_container: VBoxContainer = null
var _regular_label: Label = null

func _ready() -> void:
	_build_ui()
	_hide()

func _build_ui() -> void:
	# 배경 패널 (어두운 반투명)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 메인 카드
	var card: PanelContainer = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(420, 540)
	card.position = Vector2(-210, -270)
	card.size = Vector2(420, 540)
	add_child(card)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	# 헤더 (X 닫기)
	var hb: HBoxContainer = HBoxContainer.new()
	vb.add_child(hb)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.custom_minimum_size = Vector2(40, 40)
	_close_button.pressed.connect(_on_close_pressed)
	hb.add_child(_close_button)

	# 아바타
	_avatar_label = Label.new()
	_avatar_label.text = "😊"
	_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_label.add_theme_font_size_override("font_size", 56)
	vb.add_child(_avatar_label)

	# 이름
	_name_label = Label.new()
	_name_label.text = "이름"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 28)
	vb.add_child(_name_label)

	# 단골 배지
	_regular_label = Label.new()
	_regular_label.text = ""
	_regular_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_regular_label.add_theme_font_size_override("font_size", 16)
	vb.add_child(_regular_label)

	# 페르소나
	_personality_label = Label.new()
	_personality_label.text = "페르소나: -"
	_personality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_personality_label)

	# 구분선
	var sep1: HSeparator = HSeparator.new()
	vb.add_child(sep1)

	# 주문
	_drink_label = Label.new()
	_drink_label.text = "☕ 선호 음료: -"
	vb.add_child(_drink_label)

	# 인내심
	_patience_label = Label.new()
	_patience_label.text = "⏰ 인내심: -"
	vb.add_child(_patience_label)

	# 코인 보상
	_coin_label = Label.new()
	_coin_label.text = "💰 기본 보상: -"
	vb.add_child(_coin_label)

	# 구분선
	var sep2: HSeparator = HSeparator.new()
	vb.add_child(sep2)

	# 허용 음료
	var acceptable_title: Label = Label.new()
	acceptable_title.text = "✅ 좋아하는 음료"
	vb.add_child(acceptable_title)
	_acceptable_container = VBoxContainer.new()
	vb.add_child(_acceptable_container)

	# 거부 음료
	var rejected_title: Label = Label.new()
	rejected_title.text = "❌ 거부 음료"
	vb.add_child(rejected_title)
	_rejected_container = VBoxContainer.new()
	vb.add_child(_rejected_container)

	# 구분선
	var sep3: HSeparator = HSeparator.new()
	vb.add_child(sep3)

	# flavor
	_flavor_label = Label.new()
	_flavor_label.text = ""
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_flavor_label)

## 손님 정보 표시
func show_customer(cd: Resource) -> void:
	if cd == null:
		_hide()
		return
	current_customer = cd

	# CustomerData Resource 의 필드 사용
	_avatar_label.text = String(cd.avatar_emoji)
	_name_label.text = String(cd.display_name)
	_personality_label.text = "🎭 " + String(cd.personality)
	_drink_label.text = "☕ 선호 음료: " + String(cd.preferred_drink)
	_patience_label.text = "⏰ 인내심: %.0f초" % float(cd.patience_sec)
	_coin_label.text = "💰 기본 보상: %d코인 (팁 젤리 %d~%d)" % [
		int(cd.base_coin_reward), int(cd.tip_jelly_min), int(cd.tip_jelly_max)
	]
	_flavor_label.text = "💬 " + String(cd.flavor_text)

	if bool(cd.is_regular):
		_regular_label.text = "⭐ 단골 손님"
		_regular_label.modulate = Color(1, 0.85, 0.3)
	else:
		_regular_label.text = ""

	_populate_drink_list(_acceptable_container, cd.acceptable_drinks, "✅")
	_populate_drink_list(_rejected_container, cd.rejected_drinks, "❌")

	show()

func _populate_drink_list(container: VBoxContainer, drinks: Array, prefix: String) -> void:
	# 기존 비우기
	for child in container.get_children():
		child.queue_free()
	if drinks == null or drinks.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "  (없음)"
		lbl.modulate = Color(0.7, 0.7, 0.7)
		container.add_child(lbl)
		return
	for d in drinks:
		var lbl: Label = Label.new()
		lbl.text = "  " + prefix + " " + String(d)
		container.add_child(lbl)

func _on_close_pressed() -> void:
	close_requested.emit()
	_hide()

func _hide() -> void:
	hide()