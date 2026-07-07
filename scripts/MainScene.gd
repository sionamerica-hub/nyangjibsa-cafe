extends Node2D
## 냥집사 카페 — 신(god) 뷰 메인 화면 (v3 — 손님 도감/상세 통합)

const SLOT_COUNT_MAX: int = 5
const SLOTS_CIRCLE_RADIUS: float = 280.0
const SLOT_SIZE: Vector2 = Vector2(180.0, 180.0)

@onready var hud: CanvasLayer = $HUD
@onready var facility_label: Label = $HUD/TopBar/FacilityLabel
@onready var coin_label: Label = $HUD/TopBar/CoinLabel
@onready var jelly_label: Label = $HUD/TopBar/JellyLabel
@onready var period_label: Label = $HUD/TopBar/PeriodLabel
@onready var balance_label: Label = $HUD/TopBar/BalanceLabel
@onready var slot_container: Node2D = $Slots
@onready var cat_sprite: Label = $CatSprite
@onready var customer_alert: Label = $HUD/CustomerAlert

var slot_nodes: Array = []
var placed_cats: Dictionary = {}
var facility_current: int = 1
var total_coin: int = 0
var total_jelly: int = 0
var balance_timer: Timer = null
var customer_timer: Timer = null
var cat_anim_time: float = 0.0
var album_instance: Control = null

var current_customer_payload: Dictionary = {}
var current_waited_ratio: float = 0.0
var cat_state_hud: Label = null
var cat_feed_btn: Button = null
var cat_play_btn: Button = null
var cat_nap_btn: Button = null
var facility_upgrade_btn: Button = null
var customer_action_btns: Array = []

var customer_list_panel: Control = null
var customer_list_buttons: Array = []
var customer_detail_instance: Control = null

func _ready() -> void:
	_setup_background()
	_build_action_layer()
	_build_customer_list_panel()
	_build_slots()
	_setup_hud()
	_connect_signals()
	_connect_w4_signals()
	_setup_timers()
	_spawn_demo_cat()
	_show_intro()
	print("🏠 MainScene 신(god)뷰 진입 — 슬롯 %d / 시설 Lv %d" %
		[_active_slot_count(), facility_current])

func _active_slot_count() -> int:
	if FacilityManager != null and FacilityManager.has_method("get_current"):
		var fac = FacilityManager.get_current()
		if fac != null: return fac.slot_count
	var lvl := facility_current
	match lvl:
		1: return 3
		2: return 4
		3: return 5
		4: return 6
		_: return 3

func _build_slots() -> void:
	if slot_container == null: return
	for child in slot_container.get_children():
		child.queue_free()
	slot_nodes.clear()
	var n := _active_slot_count()
	var center := Vector2(540, 900)
	if n == 1: _make_slot(0, center)
	elif n == 2:
		_make_slot(0, center + Vector2(-120, 0))
		_make_slot(1, center + Vector2(120, 0))
	elif n == 3:
		_make_slot(0, center + Vector2(0, -140))
		_make_slot(1, center + Vector2(-140, 80))
		_make_slot(2, center + Vector2(140, 80))
	elif n == 4:
		_make_slot(0, center + Vector2(0, -160))
		_make_slot(1, center + Vector2(-160, 0))
		_make_slot(2, center + Vector2(160, 0))
		_make_slot(3, center + Vector2(0, 160))
	elif n >= 5:
		for i in range(5):
			var angle := -PI/2 + i * (TAU/5)
			var pos := center + Vector2(cos(angle), sin(angle)) * SLOTS_CIRCLE_RADIUS
			_make_slot(i, pos)
		if n >= 6:
			_make_slot(5, center)
	print("🎰 슬롯 %d개 배치 완료" % slot_nodes.size())

func _make_slot(idx: int, pos: Vector2) -> void:
	var panel := Panel.new()
	panel.position = pos - SLOT_SIZE * 0.5
	panel.size = SLOT_SIZE
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

func _setup_hud() -> void:
	if facility_label != null: _update_facility_label()
	if coin_label != null: coin_label.text = "💰 코인: %d" % _get_coin()
	if jelly_label != null: jelly_label.text = "💎 젤리: %d" % _get_jelly()
	if period_label != null and TimePeriodManager != null:
		var info := TimePeriodManager.get_period_info()
		period_label.text = "⏰ %s (%02d:%02d)" % [info.period, info.kst_hour, info.kst_minute]
	if balance_label != null and BalanceMeter != null:
		var b := BalanceMeter.get_score_breakdown()
		balance_label.text = "⚖ %d %s" % [b.score, b.label]

func _update_facility_label() -> void:
	if FacilityManager != null and FacilityManager.has_method("describe_current"):
		var desc := FacilityManager.describe_current()
		facility_label.text = "🏠 " + desc
		var cur = FacilityManager.get_current()
		if cur != null: facility_current = int(cur.level)

func _get_coin() -> int:
	if SaveManager != null and SaveManager.has_method("get_coin"):
		return SaveManager.get_coin()
	return total_coin

func _get_jelly() -> int:
	if SaveManager != null and SaveManager.has_method("get_jelly"):
		return SaveManager.get_jelly()
	return total_jelly

func _connect_signals() -> void:
	var tab_album: Button = null
	var tab_cafe: Button = null
	var tab_cats: Button = null
	var tab_shop: Button = null
	var tab_settings: Button = null
	if has_node("HUD/TabBar"):
		var tb = $HUD/TabBar
		if tb.has_node("AlbumBtn"): tab_album = tb.get_node("AlbumBtn")
		if tb.has_node("CafeBtn"): tab_cafe = tb.get_node("CafeBtn")
		if tb.has_node("CatsBtn"): tab_cats = tb.get_node("CatsBtn")
		if tb.has_node("ShopBtn"): tab_shop = tb.get_node("ShopBtn")
		if tb.has_node("SettingsBtn"): tab_settings = tb.get_node("SettingsBtn")
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

func _connect_w4_signals() -> void:
	if CustomerManager != null:
		if CustomerManager.has_signal("customer_arrived") and not CustomerManager.customer_arrived.is_connected(_on_customer_arrived_w4):
			CustomerManager.customer_arrived.connect(_on_customer_arrived_w4)
		if CustomerManager.has_signal("customer_served") and not CustomerManager.customer_served.is_connected(_on_customer_served_w4):
			CustomerManager.customer_served.connect(_on_customer_served_w4)
		if CustomerManager.has_signal("customer_left_angry") and not CustomerManager.customer_left_angry.is_connected(_on_customer_left_angry_w4):
			CustomerManager.customer_left_angry.connect(_on_customer_left_angry_w4)
	if CatStateMachine != null and CatStateMachine.has_signal("cat_state_changed") and not CatStateMachine.cat_state_changed.is_connected(_on_cat_state_changed):
		CatStateMachine.cat_state_changed.connect(_on_cat_state_changed)
	if BalanceMeter != null and BalanceMeter.has_signal("balance_score_changed"):
		if not BalanceMeter.balance_score_changed.is_connected(_on_balance_label_update):
			BalanceMeter.balance_score_changed.connect(_on_balance_label_update)
	if FacilityManager != null:
		if FacilityManager.has_signal("facility_upgraded") and not FacilityManager.facility_upgraded.is_connected(_on_facility_upgraded):
			FacilityManager.facility_upgraded.connect(_on_facility_upgraded)

func _setup_timers() -> void:
	balance_timer = Timer.new()
	balance_timer.wait_time = 5.0
	balance_timer.autostart = true
	balance_timer.timeout.connect(_on_balance_tick)
	add_child(balance_timer)

	customer_timer = Timer.new()
	customer_timer.wait_time = 12.0
	customer_timer.autostart = true
	customer_timer.timeout.connect(_on_legacy_customer_alert)
	add_child(customer_timer)

func _spawn_demo_cat() -> void:
	if cat_sprite == null: return
	cat_sprite.text = "🐱"
	cat_sprite.add_theme_font_size_override("font_size", 120)
	cat_sprite.position = Vector2(540, 900)
	cat_sprite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placed_cats[0] = "demo_cat"
	if CatStateMachine != null:
		CatStateMachine.register_cat("demo_cat", 60.0, 50.0, 70.0)
	print("🐱 데모 캣 슬롯 0에 배치")

func _process(delta: float) -> void:
	if cat_sprite != null:
		cat_anim_time += delta
		var offset_y := sin(cat_anim_time * 2.5) * 12.0
		cat_sprite.position.y = 900.0 + offset_y
	if not current_customer_payload.is_empty() and CustomerManager != null:
		current_waited_ratio = CustomerManager.get_waited_ratio()
		_update_customer_alert()

func _build_action_layer() -> void:
	cat_state_hud = Label.new()
	cat_state_hud.name = "CatStateHUD"
	cat_state_hud.position = Vector2(340, 1080)
	cat_state_hud.size = Vector2(400, 100)
	cat_state_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_state_hud.add_theme_font_size_override("font_size", 22)
	cat_state_hud.text = "🐱 캣 상태: hunger 50 / activity 50 / rest 50"
	add_child(cat_state_hud)

	cat_feed_btn = Button.new()
	cat_feed_btn.text = "🍗 먹이기"
	cat_feed_btn.position = Vector2(140, 1180)
	cat_feed_btn.size = Vector2(220, 80)
	cat_feed_btn.pressed.connect(_on_feed_pressed)
	add_child(cat_feed_btn)

	cat_play_btn = Button.new()
	cat_play_btn.text = "🎾 놀아주기"
	cat_play_btn.position = Vector2(380, 1180)
	cat_play_btn.size = Vector2(220, 80)
	cat_play_btn.pressed.connect(_on_play_pressed)
	add_child(cat_play_btn)

	cat_nap_btn = Button.new()
	cat_nap_btn.text = "😴 재우기"
	cat_nap_btn.position = Vector2(620, 1180)
	cat_nap_btn.size = Vector2(220, 80)
	cat_nap_btn.pressed.connect(_on_nap_pressed)
	add_child(cat_nap_btn)

	facility_upgrade_btn = Button.new()
	facility_upgrade_btn.name = "FacilityUpgradeBtn"
	facility_upgrade_btn.text = "🏢 시설 업그레이드"
	facility_upgrade_btn.position = Vector2(140, 1280)
	facility_upgrade_btn.size = Vector2(700, 90)
	facility_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	add_child(facility_upgrade_btn)
	_refresh_upgrade_btn()

func _refresh_upgrade_btn() -> void:
	if facility_upgrade_btn == null or FacilityManager == null: return
	if FacilityManager.get_max_level() <= FacilityManager.current_level:
		facility_upgrade_btn.text = "🏢 최고 레벨 도달"
		facility_upgrade_btn.disabled = true
		return
	var cost: int = FacilityManager.get_upgrade_cost()
	facility_upgrade_btn.disabled = not FacilityManager.can_upgrade()
	var lv: int = FacilityManager.current_level
	facility_upgrade_btn.text = "🏢 Lv %d → Lv %d (💰 %d)" % [lv, lv + 1, cost]

func _on_feed_pressed() -> void:
	if CatStateMachine == null: return
	var r: Dictionary = CatStateMachine.feed("demo_cat")
	if r.get("ok", false):
		print("🍗 먹이기 결과: hunger %.0f → %.0f" % [r.before, r.after])

func _on_play_pressed() -> void:
	if CatStateMachine == null: return
	var r: Dictionary = CatStateMachine.play("demo_cat")
	if r.get("ok", false):
		print("🎾 놀아주기 결과: activity %.0f → %.0f" % [r.before, r.after])

func _on_nap_pressed() -> void:
	if CatStateMachine == null: return
	var r: Dictionary = CatStateMachine.nap("demo_cat")
	if r.get("ok", false):
		print("😴 재우기 결과: rest %.0f → %.0f" % [r.before, r.after])

func _on_upgrade_pressed() -> void:
	if FacilityManager == null: return
	var next_lv: int = FacilityManager.current_level + 1
	var result: Dictionary = FacilityManager.upgrade_to(next_lv)
	if result.get("ok", false):
		print("🏢 업그레이드 성공! → Lv %d (잔액 %d)" %
			[result.level, result.coin_remaining])
		_setup_hud()
		_build_slots()
		_refresh_upgrade_btn()
	else:
		print("🚫 업그레이드 실패: %s" % result.get("reason", "?"))

func _on_customer_arrived_w4(cd, payload: Dictionary) -> void:
	current_customer_payload = payload
	current_waited_ratio = 0.0
	_show_customer_panel(cd, payload)
	# 손님 상세화면 자동 팝업 (음식 sprite 포함)
	_on_customer_list_pressed(cd)

func _on_customer_served_w4(satisfaction: int, coin: int, jelly: int) -> void:
	if coin_label != null: coin_label.text = "💰 코인: %d" % _get_coin()
	if jelly_label != null: jelly_label.text = "💎 젤리: %d" % _get_jelly()
	print("💰 코인 갱신: %d | 젤리: %d" % [_get_coin(), _get_jelly()])

func _on_customer_left_angry_w4(cd, summary: Dictionary) -> void:
	current_customer_payload.clear()
	current_waited_ratio = 0.0
	_hide_customer_panel()
	print("🚶 %s 분노 퇴장 (이유=%s)" % [cd.display_name, summary.get("reason", "?")])

func _on_cat_state_changed(cat_id: String, st: Dictionary) -> void:
	if cat_state_hud == null: return
	cat_state_hud.text = "🐱 [%s] 🍗%.0f  🎾%.0f  😴%.0f  💖%.0f" % [
		cat_id, float(st.hunger), float(st.activity),
		float(st.rest), float(st.happiness)]

func _on_balance_label_update(_score: int, label: String) -> void:
	if balance_label == null: return
	balance_label.text = "⚖ " + label

func _on_facility_upgraded(level: int, before: int) -> void:
	_setup_hud()
	_build_slots()
	_refresh_upgrade_btn()
	print("🏢 시그널 받음: Lv %d → Lv %d" % [before, level])

func _build_customer_list_panel() -> void:
	customer_list_panel = Control.new()
	customer_list_panel.name = "CustomerListPanel"
	customer_list_panel.position = Vector2(40, 1380)
	customer_list_panel.size = Vector2(1000, 460)
	customer_list_panel.visible = false
	add_child(customer_list_panel)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.97, 0.94, 0.88, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	customer_list_panel.add_child(bg)

	var header: Label = Label.new()
	header.text = "👥 손님 도감 (12명) — 클릭하면 상세"
	header.position = Vector2(20, 10)
	header.custom_minimum_size = Vector2(960, 50)
	header.add_theme_font_size_override("font_size", 22)
	customer_list_panel.add_child(header)

	var grid: GridContainer = GridContainer.new()
	grid.name = "CustomerGrid"
	grid.columns = 3
	grid.position = Vector2(20, 70)
	grid.size = Vector2(960, 380)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	customer_list_panel.add_child(grid)

	_populate_customer_list(grid)

	var tabbar: Node = null
	if has_node("HUD/TabBar"):
		tabbar = $HUD/TabBar
	if tabbar != null:
		var btn := Button.new()
		btn.text = "👥 손님"
		btn.custom_minimum_size = Vector2(180, 90)
		btn.pressed.connect(_toggle_customer_list_panel)
		tabbar.add_child(btn)

func _populate_customer_list(grid: GridContainer) -> void:
	for b in customer_list_buttons:
		if is_instance_valid(b): b.queue_free()
	customer_list_buttons.clear()

	if CustomerManager == null:
		var lbl := Label.new()
		lbl.text = "CustomerManager autoload 로드 안 됨"
		grid.add_child(lbl)
		return

	var customers: Array = CustomerManager.get_all_customers()
	for cd in customers:
		if cd == null: continue
		var btn := Button.new()
		var regular_mark: String = "⭐" if bool(cd.is_regular) else "　"
		btn.text = "%s %s %s\n%s · %d코인" % [
			regular_mark, cd.avatar_emoji, cd.display_name,
			cd.preferred_drink, int(cd.base_coin_reward)
		]
		btn.custom_minimum_size = Vector2(310, 88)
		btn.pressed.connect(_on_customer_list_pressed.bind(cd))
		grid.add_child(btn)
		customer_list_buttons.append(btn)

func _toggle_customer_list_panel() -> void:
	if customer_list_panel == null: return
	customer_list_panel.visible = not customer_list_panel.visible

func _on_customer_list_pressed(cd) -> void:
	print("👤 손님 선택: %s (%s)" % [cd.display_name, cd.preferred_drink])
	if customer_detail_instance != null and is_instance_valid(customer_detail_instance):
		customer_detail_instance.queue_free()
	var DetailScene := load("res://scenes/CustomerDetail.tscn")
	if DetailScene == null:
		push_error("CustomerDetail.tscn 로드 실패")
		return
	customer_detail_instance = DetailScene.instantiate()
	customer_detail_instance.close_requested.connect(_on_customer_detail_closed)
	add_child(customer_detail_instance)
	customer_detail_instance.show_customer(cd)

func _on_customer_detail_closed() -> void:
	if customer_detail_instance != null and is_instance_valid(customer_detail_instance):
		customer_detail_instance.queue_free()
		customer_detail_instance = null

func _show_customer_panel(cd, payload: Dictionary) -> void:
	_clear_customer_panel_btns()
	customer_alert.text = "%s %s — \"%s 주세요!\" (인내심 %.0f초)" % [
		cd.avatar_emoji, cd.display_name, cd.preferred_drink,
		float(payload.patience_sec)]
	customer_alert.visible = true
	customer_alert.modulate.a = 1.0

	var menu: Array = Array(payload.get("menu", []))
	var y_start: float = 1320.0
	var x_start: float = 60.0
	var btn_w: float = 480.0
	var btn_h: float = 90.0
	for i in range(menu.size()):
		var drink: String = String(menu[i])
		var btn := Button.new()
		btn.text = "🥤 " + drink
		btn.position = Vector2(x_start + (i % 2) * (btn_w + 20),
				y_start + int(i / 2) * (btn_h + 8))
		btn.size = Vector2(btn_w, btn_h)
		btn.pressed.connect(_on_menu_pressed.bind(drink))
		add_child(btn)
		customer_action_btns.append(btn)

	var t := get_tree().create_timer(8.0)
	t.timeout.connect(_clear_customer_panel_btns)

func _on_menu_pressed(drink: String) -> void:
	if CustomerManager == null: return
	print("🍹 메뉴 선택: %s" % drink)
	var result: Dictionary = CustomerManager.serve_drink(drink)
	_clear_customer_panel_btns()
	current_customer_payload.clear()
	if customer_detail_instance != null and is_instance_valid(customer_detail_instance):
		customer_detail_instance.queue_free()
		customer_detail_instance = null

func _clear_customer_panel_btns() -> void:
	for b in customer_action_btns:
		if is_instance_valid(b): b.queue_free()
	customer_action_btns.clear()

func _hide_customer_panel() -> void:
	_clear_customer_panel_btns()

func _update_customer_alert() -> void:
	if current_customer_payload.is_empty() or customer_alert == null: return
	var w: float = current_waited_ratio
	var msg: String = customer_alert.text
	if "(" in msg:
		var prefix := msg.split("(")[0]
		customer_alert.text = prefix + "(기다림 %.0f%%)" % (w * 100.0)

func _on_balance_tick() -> void:
	var per_min: int = 100
	if FacilityManager != null and FacilityManager.has_method("get_current"):
		var fac = FacilityManager.get_current()
		if fac != null:
			per_min = int(fac.coin_per_min)
	var balance_mult: float = 1.0
	if BalanceMeter != null and BalanceMeter.has_method("get_score_breakdown"):
		var info := BalanceMeter.get_score_breakdown()
		balance_mult = float(info.coin_mult)
	var period_mult: float = 1.0
	if TimePeriodManager != null and TimePeriodManager.has_method("get_period_info"):
		var info := TimePeriodManager.get_period_info()
		period_mult = float(info.coin_mult)
	var earned: int = int(per_min / 12.0 * balance_mult * period_mult)
	if earned > 0 and SaveManager != null and SaveManager.has_method("add_coin"):
		SaveManager.add_coin(earned)
		coin_label.text = "💰 코인: %d" % _get_coin()
	if TimePeriodManager != null and TimePeriodManager.has_method("get_period_info"):
		var info := TimePeriodManager.get_period_info()
		if int(info.jelly_bonus) > 0 and randf() < 0.3:
			var add: int = int(info.jelly_bonus)
			if SaveManager != null and SaveManager.has_method("add_jelly"):
				SaveManager.add_jelly(add)
				jelly_label.text = "💎 젤리: %d" % _get_jelly()

func _on_legacy_customer_alert() -> void:
	if CustomerManager != null and CustomerManager.has_customer():
		return
	if customer_alert == null: return
	var cat_names: Array[String] = ["나비", "치즈", "흰둥이", "까망이", "고등어", "호두"]
	var pick: String = cat_names[randi() % cat_names.size()]
	customer_alert.text = "🐱 %s 손님 도착!" % pick
	customer_alert.visible = true
	customer_alert.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(customer_alert, "modulate:a", 0.0, 1.5).set_delay(1.5)
	t.tween_callback(func(): customer_alert.visible = false)

func _on_album_pressed() -> void:
	print("📖 [도감] 탭 클릭")
	if album_instance == null:
		var AlbumScript := load("res://scripts/CatAlbum.gd")
		if AlbumScript == null: return
		album_instance = Control.new()
		album_instance.set_script(AlbumScript)
		_album_build_inline(album_instance)
		add_child(album_instance)
	album_instance.visible = not album_instance.visible
	if album_instance.visible:
		if album_instance.has_method("_load_all_cats"):
			album_instance._load_all_cats()
		if album_instance.has_method("_init_unlock_state"):
			album_instance._init_unlock_state()
		if album_instance.has_method("_build_grid"):
			album_instance._build_grid()
		if album_instance.has_method("_update_title"):
			album_instance._update_title()

func _on_cafe_pressed() -> void:
	print("☕ [카페] 탭 클릭")
	_toggle_customer_list_panel()

func _on_cats_pressed() -> void:
	print("🐱 [캣] 탭 클릭")
	_on_album_pressed()

func _on_shop_pressed() -> void:
	print("🛒 [상점] 탭 클릭")

func _on_settings_pressed() -> void:
	print("⚙️ [설정] 탭 클릭")

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
	root.set_meta("built", true)

func _setup_background() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.97, 0.94, 0.88, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _show_intro() -> void:
	pass