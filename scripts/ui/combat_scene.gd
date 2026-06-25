extends Control

const PLAYER_ID := "player_star"
const ENEMY_ID := "enemy_corrupted_student"
const LEVEL_ID := "level_demo_trial"

const STATUS_ICE_ARMOR := "300001"
const STATUS_TRANSFORM := "300002"
const STATUS_STUN := "300003"
const TRIGGER_MAGIC_DEFENSE_BREAK := 90

const GameDatabaseScript = preload("res://scripts/data/game_database.gd")
const EnemyAIControllerScript = preload("res://scripts/enemy_ai/enemy_ai_controller.gd")
const CardZoneManagerScript = preload("res://scripts/combat/card_zone_manager.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")
const EffectResolverScript = preload("res://scripts/combat/effect_resolver.gd")
const DamageSystemScript = preload("res://scripts/combat/damage_system.gd")
const ResourceSystemScript = preload("res://scripts/combat/resource_system.gd")
const StatusSystemScript = preload("res://scripts/combat/status_system.gd")
const TargetResolverScript = preload("res://scripts/combat/target_resolver.gd")
const UnitStateFactoryScript = preload("res://scripts/combat/unit_state_factory.gd")
const CardViewScene := preload("res://scenes/ui/CardView.tscn")
const UnitViewScene := preload("res://scenes/ui/UnitView.tscn")

const DRAW_PILE_CARD_BACK_PATH := "res://assets/ui/card_back_draw_pile.png"
const DISCARD_PILE_CARD_BACK_PATH := "res://assets/ui/card_back_discard_pile.png"
const EXHAUST_PILE_CARD_BACK_PATH := "res://assets/ui/card_back_exhaust_pile.png"
const MAGIC_ICON_PATH := "res://assets/ui/energy_orb_full.png"
const CARD_SLOT_SIZE := Vector2(190, 318)
const CARD_VIEW_SIZE := Vector2(190, 274)
const CARD_HAND_MAX_WIDTH := 1260.0
const CARD_HAND_MAX_STEP := 136.0
const CARD_HAND_MIN_STEP := 68.0
const CARD_HAND_MAX_ROTATION := 10.0
const CARD_HAND_ARC_DROP := 34.0
const CARD_HAND_REST_Y := 28.0
const CARD_PENDING_LIFT := 42.0
const CARD_HAND_CENTER_OFFSET_X := -70.0
const HAND_DRAG_HIGHLIGHT_SCALE := Vector2(1.08, 1.08)

var database = GameDatabaseScript.new()
var enemy_ai_controller = EnemyAIControllerScript.new()
var card_zones = CardZoneManagerScript.new()
var combat_controller = CombatControllerScript.new()
var effect_resolver = EffectResolverScript.new()
var damage_system = DamageSystemScript.new()
var resource_system = ResourceSystemScript.new()
var status_system = StatusSystemScript.new()
var target_resolver = TargetResolverScript.new()
var unit_state_factory = UnitStateFactoryScript.new()

var player := {}
var enemy := {}
var current_level := {}
var pending_play_hand_index := -1
var enemy_action_cards: Array[String] = []
var enemy_intent_card_id := ""
var log_lines: Array[String] = []
var battle_log_expanded := false
var drag_play_hand_index := -1
var drag_arrow_start := Vector2.ZERO
var drag_has_left_hand_area := false
var player_magic_defense_bar_max := 1
var enemy_magic_defense_bar_max := 1
var player_unit_view: UnitView
var enemy_unit_view: UnitView

@onready var turn_state_label: Label = $TopBar/TurnStateLabel
@onready var player_info: Label = $StatusArea/PlayerPanel/PlayerInfo
@onready var magic_icon: TextureRect = $StatusArea/PlayerPanel/MagicIcon
@onready var magic_value_label: Label = $StatusArea/PlayerPanel/MagicValueLabel
@onready var enemy_info: Label = $StatusArea/EnemyPanel/EnemyInfo
@onready var pile_info: Label = $StatusArea/PilePanel/PileInfo
@onready var draw_pile_card_back: TextureRect = $StatusArea/PilePanel/DrawPileCardBack
@onready var draw_pile_count_label: Label = $StatusArea/PilePanel/DrawPileCountLabel
@onready var discard_pile_card_back: TextureRect = $StatusArea/PilePanel/DiscardPileCardBack
@onready var exhaust_pile_card_back: TextureRect = $StatusArea/PilePanel/ExhaustPileCardBack
@onready var battle_log_panel: PanelContainer = $CenterArea/BattleLogPanel
@onready var battle_log: Label = $CenterArea/BattleLogPanel/Margin/BattleLog
@onready var battle_log_toggle_button: Button = $CenterArea/BattleLogToggleButton
@onready var hand_panel: Control = $HandPanel
@onready var hand_list: Control = $HandPanel/Margin/HandList
@onready var background_texture: TextureRect = $BackgroundTexture
@onready var end_turn_button: Button = $StatusArea/ActionArea/EndTurnButton
@onready var player_unit_slot: Control = $BattleArea/PlayerUnitSlot
@onready var enemy_unit_slot: Control = $BattleArea/EnemyUnitSlot
@onready var target_arrow_layer: TargetArrowLayer = $TargetArrowLayer

func _ready() -> void:
	add_child(database)
	database.load_all()
	effect_resolver.setup(
		database,
		Callable(self, "_select_target"),
		Callable(self, "_apply_resource_effect"),
		Callable(self, "_apply_damage_effect"),
		Callable(self, "_apply_attach_effect"),
		Callable(self, "_is_combat_over"),
		Callable(self, "_log")
	)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	battle_log_toggle_button.pressed.connect(_on_battle_log_toggle_pressed)
	_start_combat()

func _start_combat() -> void:
	combat_controller.start_combat()
	card_zones.reset()
	pending_play_hand_index = -1
	enemy_action_cards.clear()
	log_lines.clear()
	player_magic_defense_bar_max = 1
	enemy_magic_defense_bar_max = 1
	current_level = database.find_level(LEVEL_ID)
	_load_level_background(current_level)

	var character: Dictionary = database.find_by_id(database.characters, "id", PLAYER_ID)
	var enemy_id := str(current_level.get("enemy_id", ENEMY_ID))
	if enemy_id == "":
		enemy_id = ENEMY_ID
	var enemy_row: Dictionary = database.find_by_id(database.enemies, "id", enemy_id)
	if character.is_empty() or enemy_row.is_empty():
		_log("缺少玩家或敌人配置，无法开始战斗。")
		_refresh_ui()
		return

	player = unit_state_factory.create_player(character)
	enemy = unit_state_factory.create_enemy(enemy_row)

	card_zones.build_player_deck(database, str(character.get("starter_deck_id", "")), player["id"])
	_build_enemy_actions(str(enemy_row.get("starter_deck_id", "")), enemy["id"], str(enemy_row.get("action_ids", "")))
	_setup_enemy_ai(enemy_row)
	player_magic_defense_bar_max = max(1, _unit_magic_defense_value(player))
	enemy_magic_defense_bar_max = max(1, _unit_magic_defense_value(enemy))

	_log("战斗开始：%s 对战 %s。" % [player["name"], enemy["name"]])
	_choose_enemy_intent()
	_create_unit_views()
	_start_player_turn()

func _create_unit_views() -> void:
	for child in player_unit_slot.get_children():
		child.queue_free()
	for child in enemy_unit_slot.get_children():
		child.queue_free()

	player_unit_view = UnitViewScene.instantiate() as UnitView
	enemy_unit_view = UnitViewScene.instantiate() as UnitView
	player_unit_slot.add_child(player_unit_view)
	enemy_unit_slot.add_child(enemy_unit_view)
	player_unit_view.setup(player, false, player_magic_defense_bar_max)
	enemy_unit_view.setup(enemy, true, enemy_magic_defense_bar_max)
	_refresh_unit_views()

func _build_enemy_actions(deck_id: String, unit_id: String, fallback_action_ids: String) -> void:
	for row in database.get_deck_rows(deck_id, unit_id):
		var card_id := str(row.get("card_id", ""))
		var card: Dictionary = database.find_card(card_id)
		if not card.is_empty() and str(card.get("owner_type", "")) == "enemy":
			enemy_action_cards.append(card_id)

	if enemy_action_cards.is_empty():
		for card_id in fallback_action_ids.split(";", false):
			var card: Dictionary = database.find_card(card_id)
			if not card.is_empty() and str(card.get("owner_type", "")) == "enemy":
				enemy_action_cards.append(card_id)

func _setup_enemy_ai(enemy_row: Dictionary) -> void:
	var script_path := str(enemy_row.get("ai_script_path", "")).strip_edges()
	if script_path == "":
		enemy_ai_controller.setup(null)
		return
	if not ResourceLoader.exists(script_path):
		_log("找不到敌人行为脚本：%s。" % script_path)
		enemy_ai_controller.setup(null)
		return
	var script := load(script_path)
	if script == null or not script.can_instantiate():
		_log("敌人行为脚本无法实例化：%s。" % script_path)
		enemy_ai_controller.setup(null)
		return
	enemy_ai_controller.setup(script.new())

func _start_player_turn() -> void:
	if _is_combat_over():
		return
	var current_turn := combat_controller.start_player_turn()
	pending_play_hand_index = -1
	_clear_magic_shield(player)
	player["magic"] = player["magic_max"]
	for message in card_zones.draw_cards(player["base_draw_count"], player["base_hand_limit"]):
		_log(message)
	_log("第 %s 回合开始。玩家恢复魔力并抽牌。" % current_turn)
	_refresh_ui()

func _start_card_targeting(hand_index: int, mouse_global_position: Vector2) -> void:
	if not combat_controller.is_player_phase() or not card_zones.is_valid_hand_index(hand_index):
		_cancel_card_targeting()
		return
	drag_play_hand_index = hand_index
	pending_play_hand_index = hand_index
	drag_has_left_hand_area = false
	drag_arrow_start = _hand_card_arrow_start(hand_index)
	_set_hand_card_highlight(hand_index, true)
	_update_card_targeting(hand_index, mouse_global_position)

func _update_card_targeting(hand_index: int, mouse_global_position: Vector2) -> void:
	if hand_index != drag_play_hand_index or not card_zones.is_valid_hand_index(drag_play_hand_index):
		return
	var card: Dictionary = database.find_card(card_zones.hand_card_id(drag_play_hand_index))
	var is_in_hand_area := _is_in_hand_area(mouse_global_position)
	if not drag_has_left_hand_area:
		if is_in_hand_area:
			target_arrow_layer.hide_arrow()
			return
		drag_has_left_hand_area = true
		drag_arrow_start = _hand_card_arrow_start(hand_index)
	if is_in_hand_area:
		target_arrow_layer.hide_arrow()
		return
	if target_resolver.is_self_target(card):
		target_arrow_layer.hide_arrow()
		return
	var target_side := _target_side_at_global_position(mouse_global_position)
	var is_valid_target := target_side != "" and _is_valid_target_for_card(card, target_side)
	target_arrow_layer.show_arrow(
		_to_arrow_layer_local(drag_arrow_start),
		_to_arrow_layer_local(mouse_global_position),
		is_valid_target
	)

func _finish_card_targeting(hand_index: int, mouse_global_position: Vector2) -> void:
	if hand_index != drag_play_hand_index or not card_zones.is_valid_hand_index(hand_index):
		_cancel_card_targeting()
		return
	var card: Dictionary = database.find_card(card_zones.hand_card_id(hand_index))
	if not drag_has_left_hand_area or _is_in_hand_area(mouse_global_position):
		_cancel_card_targeting()
		return
	if target_resolver.is_self_target(card):
		_cancel_card_targeting(false)
		_play_card(hand_index, "player")
		return
	var target_side := _target_side_at_global_position(mouse_global_position)
	if target_side == "" or not _is_valid_target_for_card(card, target_side):
		_cancel_card_targeting()
		return
	_cancel_card_targeting(false)
	_play_card(hand_index, target_side)

func _cancel_card_targeting(refresh_hand: bool = true) -> void:
	drag_play_hand_index = -1
	pending_play_hand_index = -1
	drag_has_left_hand_area = false
	target_arrow_layer.hide_arrow()
	if refresh_hand:
		_refresh_hand()

func _set_hand_card_highlight(hand_index: int, highlighted: bool) -> void:
	var slot := _hand_card_slot(hand_index)
	if slot != null:
		slot.scale = HAND_DRAG_HIGHLIGHT_SCALE if highlighted else Vector2.ONE
		slot.z_index = 260 if highlighted else slot.z_index
	var card_view := _hand_card_view(hand_index)
	if card_view != null and highlighted:
		card_view.modulate = Color(1.12, 1.08, 1.16, 1.0)

func _hand_card_slot(hand_index: int) -> Control:
	if hand_index < 0 or hand_index >= hand_list.get_child_count():
		return null
	return hand_list.get_child(hand_index) as Control

func _hand_card_view(hand_index: int) -> CardView:
	var slot := _hand_card_slot(hand_index)
	if slot == null or slot.get_child_count() == 0:
		return null
	return slot.get_child(0) as CardView

func _hand_card_arrow_start(hand_index: int) -> Vector2:
	var card_view := _hand_card_view(hand_index)
	if card_view != null:
		return card_view.get_global_rect().get_center()
	return drag_arrow_start

func _is_in_hand_area(mouse_global_position: Vector2) -> bool:
	return hand_panel.get_global_rect().has_point(mouse_global_position)

func _to_arrow_layer_local(canvas_position: Vector2) -> Vector2:
	return target_arrow_layer.get_global_transform().affine_inverse() * canvas_position

func _play_card(hand_index: int, target_side: String = "") -> void:
	if not combat_controller.is_player_phase() or not card_zones.is_valid_hand_index(hand_index):
		pending_play_hand_index = -1
		_refresh_hand()
		return

	var card: Dictionary = database.find_card(card_zones.hand_card_id(hand_index))
	if card.is_empty():
		pending_play_hand_index = -1
		_refresh_hand()
		return
	if str(card.get("owner_type", "player")) == "enemy":
		_log("这张牌不属于玩家。")
		pending_play_hand_index = -1
		_refresh_hand()
		return

	if target_side == "" or not _is_valid_target_for_card(card, target_side):
		pending_play_hand_index = -1
		_refresh_hand()
		return

	var cost := _to_int(card.get("cost", 0))
	if player["magic"] < cost:
		_log("魔力不足，无法使用 %s。" % str(card.get("name", "未知卡牌")))
		pending_play_hand_index = -1
		_refresh_hand()
		return

	pending_play_hand_index = -1
	player["magic"] -= cost
	var instance: Dictionary = card_zones.take_hand_card(hand_index)
	_log("玩家使用 %s。" % str(card.get("name", "未知卡牌")))
	_resolve_card(card, "player", target_side)
	_apply_arousal_card_use_feedback()

	card_zones.move_played_card_after_resolution(card, instance)

	_post_effect_checks()
	_refresh_ui()

func _resolve_card(card: Dictionary, source_side: String, target_side: String = "") -> void:
	effect_resolver.resolve_card(card, source_side, target_side)

func _select_target(card: Dictionary, source_side: String, target_side: String = "") -> Dictionary:
	return target_resolver.select_target(card, source_side, target_side, player, enemy)

func _target_side_at_global_position(mouse_global_position: Vector2) -> String:
	if enemy_unit_view != null and enemy_unit_view.get_global_rect().has_point(mouse_global_position):
		return "enemy"
	if player_unit_view != null and player_unit_view.get_global_rect().has_point(mouse_global_position):
		return "player"
	return ""

func _is_valid_target_for_card(card: Dictionary, target_side: String, source_side: String = "player") -> bool:
	return target_resolver.is_valid_target_for_card(card, target_side, source_side)

func _apply_resource_effect(effect: Dictionary, target: Dictionary) -> void:
	var result: Dictionary = resource_system.apply_resource_effect(effect, target, player)
	var player_defense_candidate := _to_int(result.get("player_magic_defense_bar_candidate", -1))
	if player_defense_candidate >= 0:
		player_magic_defense_bar_max = max(player_magic_defense_bar_max, player_defense_candidate)
	var enemy_defense_candidate := _to_int(result.get("enemy_magic_defense_bar_candidate", -1))
	if enemy_defense_candidate >= 0:
		enemy_magic_defense_bar_max = max(enemy_magic_defense_bar_max, enemy_defense_candidate)
	for message in result.get("logs", []):
		_log(str(message))

func _apply_damage_effect(effect: Dictionary, target: Dictionary, source_side: String) -> void:
	var result: Dictionary = damage_system.apply_damage_effect(effect, target, source_side, player, enemy)
	for message in result.get("logs", []):
		_log(str(message))
	if bool(result.get("animate_hit", false)):
		_animate_hit(target)

func _apply_attach_effect(effect: Dictionary, target: Dictionary) -> void:
	var parts := _parse_value(effect.get("value", ""))
	if parts.size() < 2:
		return
	var status_id := str(parts[0])
	var stack := parts[1]
	if status_id == STATUS_TRANSFORM:
		player["transformed"] = true
		player["form"] = "魔法少女形态"
		status_system.add_status(player, "变身状态", stack)
		_log("玩家进入魔法少女形态。")
	elif status_id == STATUS_ICE_ARMOR:
		status_system.add_status(target, "冰甲", stack)
		_log("%s 获得 %d 层冰甲。" % [target["name"], stack])
	elif status_id == STATUS_STUN:
		status_system.add_status(target, "眩晕", stack)
		target["stun_turns"] = max(_to_int(target.get("stun_turns", 0)), stack)
		_log("%s 陷入眩晕 %d 回合。" % [target["name"], stack])

func _on_end_turn_pressed() -> void:
	if not combat_controller.is_player_phase():
		return
	pending_play_hand_index = -1
	_log("玩家结束回合。")
	card_zones.discard_hand()
	combat_controller.start_enemy_turn()
	_refresh_ui()
	await get_tree().create_timer(0.35).timeout
	_run_enemy_turn()

func _run_enemy_turn() -> void:
	if _is_combat_over():
		return
	_clear_magic_shield(enemy)
	if _consume_enemy_stun_turn():
		_post_effect_checks()
		_choose_enemy_intent()
		_refresh_ui()
		await get_tree().create_timer(0.35).timeout
		_start_player_turn()
		return
	var card: Dictionary = database.find_card(enemy_intent_card_id)
	if card.is_empty():
		_log("敌人没有可用行动。")
	else:
		_log("%s 使用 %s。" % [enemy["name"], str(card.get("name", "未知行动"))])
		_resolve_card(card, "enemy")
	_post_effect_checks()
	_choose_enemy_intent()
	_refresh_ui()
	await get_tree().create_timer(0.35).timeout
	_start_player_turn()

func _choose_enemy_intent() -> void:
	enemy_intent_card_id = enemy_ai_controller.choose_action(player, enemy, enemy_action_cards)

func _clear_magic_shield(unit: Dictionary) -> void:
	var shield := _to_int(unit.get("magic_shield", 0))
	if shield <= 0:
		return
	unit["magic_shield"] = 0
	_log("%s 的魔力护盾清空。" % unit.get("name", "单位"))

func _apply_arousal_card_use_feedback() -> void:
	var threshold := database.get_game_config_int("arousal_card_use_threshold", 50)
	var gain := database.get_game_config_int("arousal_card_use_gain", 2)
	if gain <= 0 or _to_int(player.get("arousal", 0)) < threshold:
		return
	player["arousal"] = clampi(_to_int(player.get("arousal", 0)) + gain, 0, _to_int(player.get("arousal_max", 100)))
	_log("发情值过高，使用卡牌额外提升 %d 点发情值。" % gain)

func _consume_enemy_stun_turn() -> bool:
	var stun_turns := _to_int(enemy.get("stun_turns", 0))
	if stun_turns <= 0:
		return false
	enemy["stun_turns"] = stun_turns - 1
	_log("%s 魔力防御耗尽，眩晕中。" % enemy.get("name", "敌人"))
	if _to_int(enemy.get("stun_turns", 0)) <= 0:
		status_system.remove_status(enemy, "眩晕")
	return true

func _trigger_enemy_hidden_effects(trigger_timing: int) -> void:
	var hidden_effect_ids: Array = enemy.get("hidden_effect_ids", [])
	for effect_id in hidden_effect_ids:
		var effect: Dictionary = database.find_card_effect(str(effect_id))
		if effect.is_empty():
			_log("找不到敌人隐藏效果 %s。" % str(effect_id))
			continue
		if _to_int(effect.get("trigger_timing", 0)) != trigger_timing:
			continue
		effect_resolver.resolve_standalone_effect(effect, "enemy")

func _handle_enemy_magic_defense_break() -> void:
	if not bool(enemy.get("magic_defense_break_enabled", false)):
		return
	if bool(enemy.get("magic_defense_broken", false)):
		return
	if _to_int(enemy.get("magic_defense", 0)) > 0:
		return
	enemy["magic_defense_broken"] = true
	_log("%s 的魔力防御耗尽。" % enemy.get("name", "敌人"))
	_trigger_enemy_hidden_effects(TRIGGER_MAGIC_DEFENSE_BREAK)
	_log("选项待实现：净化瘴气 / 继续战斗。")

func _post_effect_checks() -> void:
	if player["transformed"] and player["magic_defense"] <= 0:
		player["transformed"] = false
		player["form"] = "人类形态"
		player["magic_max"] = player["human_base_magic_max"]
		player["magic"] = min(player["magic"], player["magic_max"])
		status_system.remove_status(player, "变身状态")
		card_zones.discard_held_transform_card()
		_log("魔力防御归零，玩家解除变身。")
	if player["arousal"] >= player["arousal_max"] and combat_controller.is_player_phase():
		_log("玩家发情值达到上限，强制结束回合。")
		_on_end_turn_pressed()
	if enemy["hp"] <= 0:
		combat_controller.set_victory()
		_log("战斗胜利。")
	elif player["hp"] <= 0:
		combat_controller.set_defeat()
		_log("战斗失败。")
	else:
		_handle_enemy_magic_defense_break()

func _is_combat_over() -> bool:
	return combat_controller.is_combat_over()

func _refresh_ui() -> void:
	turn_state_label.text = _phase_text()

	player_info.text = "形态 %s  发情值 %d/%d\n敏感 %d  堕落 %d  暴露 %d\n火力 %d  灵力 %d  状态 %s" % [
		player.get("form", "人类形态"),
		player.get("arousal", 0),
		player.get("arousal_max", 100),
		player.get("sensitivity", 0),
		player.get("corruption", 0),
		player.get("exposure_tendency", 0),
		player.get("firepower", 0),
		player.get("spirit", 0),
		status_system.status_text(player),
	]
	_refresh_magic_ui()
	_refresh_unit_views()
	enemy_info.text = "火力 %d  灵力 %d\n状态 %s" % [
		enemy.get("firepower", 0),
		enemy.get("spirit", 0),
		status_system.status_text(enemy),
	]
	pile_info.text = "手牌：%d  变身持有：%s" % [
		card_zones.hand_size(),
		"1" if card_zones.has_held_transform_card() else "0",
	]
	_refresh_pile_ui()
	battle_log.text = "\n".join(log_lines)
	_refresh_battle_log_visibility()
	end_turn_button.disabled = not combat_controller.is_player_phase()
	_refresh_hand()

func _refresh_unit_views() -> void:
	if player_unit_view != null:
		player_unit_view.refresh(player, player_magic_defense_bar_max)
	if enemy_unit_view != null:
		enemy_unit_view.refresh(enemy, enemy_magic_defense_bar_max)
		enemy_unit_view.set_intent(database.find_card(enemy_intent_card_id))

func _refresh_pile_ui() -> void:
	var draw_count: int = card_zones.draw_pile_size()
	var has_draw_cards: bool = draw_count > 0
	draw_pile_card_back.visible = has_draw_cards
	draw_pile_count_label.visible = draw_count > 0 and draw_count <= 5
	draw_pile_count_label.text = str(draw_count) if draw_pile_count_label.visible else ""

	if has_draw_cards and draw_pile_card_back.texture == null:
		_load_texture_from_path(draw_pile_card_back, DRAW_PILE_CARD_BACK_PATH)

	discard_pile_card_back.visible = true
	exhaust_pile_card_back.visible = true
	if discard_pile_card_back.texture == null:
		_load_texture_from_path(discard_pile_card_back, DISCARD_PILE_CARD_BACK_PATH)
	if exhaust_pile_card_back.texture == null:
		_load_texture_from_path(exhaust_pile_card_back, EXHAUST_PILE_CARD_BACK_PATH)

func _refresh_magic_ui() -> void:
	var magic_max: int = _to_int(player.get("magic_max", 0))
	magic_icon.visible = true
	magic_value_label.visible = true
	if magic_icon.texture == null and ResourceLoader.exists(MAGIC_ICON_PATH):
		magic_icon.texture = load(MAGIC_ICON_PATH)
	var magic: int = clampi(_to_int(player.get("magic", 0)), 0, max(0, magic_max))
	magic_value_label.text = "%d/%d" % [magic, magic_max]

func _refresh_battle_log_visibility() -> void:
	battle_log_panel.visible = battle_log_expanded
	battle_log_toggle_button.text = "收起日志" if battle_log_expanded else "展开日志"

func _on_battle_log_toggle_pressed() -> void:
	battle_log_expanded = not battle_log_expanded
	_refresh_battle_log_visibility()

func _refresh_hand() -> void:
	for child in hand_list.get_children():
		child.queue_free()
	var hand_count: int = card_zones.hand_size()
	if hand_count == 0:
		return
	var step: float = CARD_HAND_MAX_STEP
	if hand_count > 1:
		step = clampf(CARD_HAND_MAX_WIDTH / float(hand_count - 1), CARD_HAND_MIN_STEP, CARD_HAND_MAX_STEP)
	var total_width: float = step * float(hand_count - 1) + CARD_VIEW_SIZE.x
	var hand_area_width: float = hand_list.size.x
	if hand_area_width <= 0.0:
		hand_area_width = max(0.0, get_viewport_rect().size.x - 72.0)
	var start_x: float = max(0.0, (hand_area_width - total_width) * 0.5 + CARD_HAND_CENTER_OFFSET_X)
	var max_rotation: float = min(CARD_HAND_MAX_ROTATION, 3.0 + float(hand_count) * 1.15)
	var center_index: float = float(hand_count - 1) * 0.5
	for i in range(card_zones.hand_size()):
		var card: Dictionary = database.find_card(card_zones.hand_card_id(i))
		var card_view = CardViewScene.instantiate()
		var can_play: bool = combat_controller.is_player_phase() and player["magic"] >= _to_int(card.get("cost", 0))
		var is_pending := pending_play_hand_index == i
		card_view.play_drag_started.connect(_start_card_targeting)
		card_view.play_drag_updated.connect(_update_card_targeting)
		card_view.play_drag_released.connect(_finish_card_targeting)
		var card_slot := Control.new()
		card_slot.custom_minimum_size = CARD_SLOT_SIZE
		card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_slot.size = CARD_SLOT_SIZE
		var normalized: float = 0.0 if hand_count == 1 else (float(i) - center_index) / center_index
		var abs_normalized: float = absf(normalized)
		var card_rotation_degrees: float = normalized * max_rotation
		var arc_drop: float = abs_normalized * CARD_HAND_ARC_DROP
		var lift: float = CARD_PENDING_LIFT if is_pending else 0.0
		card_slot.position = Vector2(start_x + step * float(i), CARD_HAND_REST_Y + arc_drop - lift)
		card_slot.rotation_degrees = card_rotation_degrees
		card_slot.pivot_offset = Vector2(CARD_VIEW_SIZE.x * 0.5, CARD_VIEW_SIZE.y)
		card_slot.z_index = 200 if is_pending else 100 - int(abs_normalized * 20.0)
		card_view.position = Vector2.ZERO
		card_slot.add_child(card_view)
		hand_list.add_child(card_slot)
		card_view.setup(card, _card_display_data(card), i, can_play, is_pending)

func _card_display_data(card: Dictionary) -> Dictionary:
	var card_type_id := str(card.get("card_type", ""))
	return {
		"type_name": database.get_card_type_name(card_type_id),
		"art_path": str(card.get("art_path", "")),
		"frame_path": _default_path(str(card.get("frame_path", "")), "res://assets/ui/card_frame_player.png"),
		"cost_badge_path": "res://assets/ui/energy_orb_full.png",
		"type_badge_path": "res://assets/ui/card_type_label.png",
	}

func _target_text(target: int) -> String:
	return target_resolver.target_text(target)

func _phase_text() -> String:
	return combat_controller.phase_text()

func _unit_magic_defense_value(unit: Dictionary) -> int:
	return max(0, _to_int(unit.get("magic_defense", 0)))

func _load_level_background(level: Dictionary) -> void:
	var path := str(level.get("background_path", ""))
	if path != "" and ResourceLoader.exists(path):
		background_texture.texture = load(path)
		background_texture.visible = true
	else:
		background_texture.texture = null
		background_texture.visible = false

func _load_texture_from_path(texture_rect: TextureRect, path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		texture_rect.texture = load(path)
		texture_rect.visible = true
	else:
		texture_rect.texture = null
		texture_rect.visible = false

func _default_path(path: String, fallback_path: String) -> String:
	return path if path != "" else fallback_path

func _animate_hit(target: Dictionary) -> void:
	var node: Control = enemy_unit_view if target.get("unit_type", "") == "enemy" else player_unit_view
	if node == null:
		return
	var original := node.position
	var offset := Vector2(18, 0) if target.get("unit_type", "") == "enemy" else Vector2(-18, 0)
	var tween := create_tween()
	tween.tween_property(node, "position", original + offset, 0.07)
	tween.tween_property(node, "position", original, 0.10)

func _parse_value(value: Variant) -> Array[int]:
	var result: Array[int] = []
	for part in str(value).split(",", false):
		result.append(_to_int(part))
	return result

func _to_int(value: Variant) -> int:
	if value == null:
		return 0
	var text := str(value).strip_edges()
	if text == "" or text == "待定":
		return 0
	return int(text)

func _log(message: String) -> void:
	log_lines.append(message)
	while log_lines.size() > 12:
		log_lines.pop_front()
